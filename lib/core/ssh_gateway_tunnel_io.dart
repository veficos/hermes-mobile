import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:http/http.dart' as http;

import '../l10n/runtime_l10n.dart';
import 'settings_store.dart';
import 'ssh_gateway_tunnel.dart';

const _connectTimeout = Duration(seconds: 15);
const _readyTimeout = Duration(seconds: 45);
const _lockSchemaVersion = 2;
const _protocolVersion = 1;

String _quote(String value) => "'${value.replaceAll("'", "'\\''")}'";

String _remotePath(String value) {
  if (value.startsWith('~/')) {
    return '"\$HOME"/${_quote(value.substring(2))}';
  }
  return _quote(value);
}

String _randomHex(int bytes) {
  final random = Random.secure();
  return List<int>.generate(
    bytes,
    (_) => random.nextInt(256),
  ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}

String _knownHostKey(ConnectionSettings settings) {
  final identity = '${settings.sshHost.trim()}:${settings.sshPort}';
  final encoded = base64Url.encode(utf8.encode(identity)).replaceAll('=', '');
  return 'hermes.ssh.known-host.$encoded.v1';
}

class _ExecResult {
  final int? exitCode;
  final String stdout;
  final String stderr;

  const _ExecResult(this.exitCode, this.stdout, this.stderr);
}

class _IoSshGatewayTunnel implements SshGatewayTunnel {
  final SSHClient _client;
  final ServerSocket _server;
  final int _remotePort;
  final List<Socket> _localSockets = [];
  final List<SSHForwardChannel> _forwardChannels = [];
  StreamSubscription<Socket>? _acceptSub;
  bool _closed = false;

  _IoSshGatewayTunnel(this._client, this._server, this._remotePort) {
    // No per-connection Socket is available on an accept-loop error (it
    // happens before one is produced), so there is nothing to clean up
    // beyond letting the loop keep listening for the next connection.
    _acceptSub = _server.listen(_forward, onError: (_) {});
  }

  @override
  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  @override
  late final String apiKey;

  Future<void> _forward(Socket socket) async {
    if (_closed) {
      await socket.close();
      return;
    }
    _localSockets.add(socket);
    try {
      final channel = await _client.forwardLocal(
        '127.0.0.1',
        _remotePort,
        localHost: '127.0.0.1',
        localPort: socket.port,
      );
      if (_closed) {
        channel.close();
        await socket.close();
        return;
      }
      _forwardChannels.add(channel);
      channel.stream.listen(
        socket.add,
        onError: (_) => socket.destroy(),
        onDone: () {
          _forwardChannels.remove(channel);
          _localSockets.remove(socket);
          channel.close();
          socket.destroy();
        },
      );
      socket.listen(
        (bytes) => channel.sink.add(Uint8List.fromList(bytes)),
        onError: (_) => channel.close(),
        onDone: channel.sink.close,
      );
    } catch (_) {
      _localSockets.remove(socket);
      socket.destroy();
    }
  }

  @override
  Future<void> close() => _close(closeClient: true);

  Future<void> _close({required bool closeClient}) async {
    if (_closed) return;
    _closed = true;
    await _acceptSub?.cancel();
    await _server.close();
    for (final socket in _localSockets.toList()) {
      socket.destroy();
    }
    for (final channel in _forwardChannels.toList()) {
      channel.close();
    }
    if (!closeClient) return;
    // The ownership-scoped backend intentionally survives a tunnel close so a
    // later app launch can authenticate and reuse it. Stale cleanup happens at
    // the next connection only after complete process-identity verification.
    _client.close();
    try {
      await _client.done.timeout(const Duration(seconds: 3));
    } catch (_) {}
  }
}

class _RemoteLock {
  final String ownershipId;
  final String spawnNonce;
  final int pid;
  final int port;
  final String profile;
  final String hermesPath;
  final String hermesHome;
  final String logPath;
  final String tokenFingerprint;
  final String startedAt;

  const _RemoteLock({
    required this.ownershipId,
    required this.spawnNonce,
    required this.pid,
    required this.port,
    required this.profile,
    required this.hermesPath,
    required this.hermesHome,
    required this.logPath,
    required this.tokenFingerprint,
    required this.startedAt,
  });

  static _RemoteLock? fromJson(
    Map<String, dynamic> json,
    String expectedOwnershipId,
  ) {
    final nonce = json['spawnNonce']?.toString() ?? '';
    final pid = json['pid'];
    final port = json['port'];
    final fingerprint = json['tokenFingerprint']?.toString() ?? '';
    final expectedLog = _spawnLogPath(expectedOwnershipId, nonce);
    if (json['schemaVersion'] != _lockSchemaVersion ||
        json['protocolVersion'] != _protocolVersion ||
        json['ownershipId'] != expectedOwnershipId ||
        !RegExp(r'^[0-9a-f]{16}$').hasMatch(nonce) ||
        pid is! int ||
        pid <= 0 ||
        pid > 4194304 ||
        port is! int ||
        port < 0 ||
        port > 65535 ||
        !RegExp(r'^[0-9a-f]{32}$').hasMatch(fingerprint) ||
        json['logPath'] != expectedLog) {
      return null;
    }
    for (final field in ['profile', 'hermesPath', 'hermesHome', 'startedAt']) {
      if (json[field] is! String || (json[field] as String).length > 1024) {
        return null;
      }
    }
    return _RemoteLock(
      ownershipId: expectedOwnershipId,
      spawnNonce: nonce,
      pid: pid,
      port: port,
      profile: json['profile'],
      hermesPath: json['hermesPath'],
      hermesHome: json['hermesHome'],
      logPath: expectedLog,
      tokenFingerprint: fingerprint,
      startedAt: json['startedAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    'schemaVersion': _lockSchemaVersion,
    'protocolVersion': _protocolVersion,
    'ownershipId': ownershipId,
    'spawnNonce': spawnNonce,
    'pid': pid,
    'port': port,
    'profile': profile,
    'hermesPath': hermesPath,
    'hermesHome': hermesHome,
    'logPath': logPath,
    'tokenFingerprint': tokenFingerprint,
    'startedAt': startedAt,
  };

  _RemoteLock withPort(int value) => _RemoteLock(
    ownershipId: ownershipId,
    spawnNonce: spawnNonce,
    pid: pid,
    port: value,
    profile: profile,
    hermesPath: hermesPath,
    hermesHome: hermesHome,
    logPath: logPath,
    tokenFingerprint: tokenFingerprint,
    startedAt: startedAt,
  );
}

String _ownershipDirectory(String ownershipId) =>
    '~/.hermes/desktop-ssh/$ownershipId';

String _lockPath(String ownershipId) =>
    '${_ownershipDirectory(ownershipId)}/backend.lock.json';

String _spawnLogPath(String ownershipId, String nonce) =>
    '${_ownershipDirectory(ownershipId)}/$nonce.log';

String _spawnTokenPath(String ownershipId, String nonce) =>
    '${_ownershipDirectory(ownershipId)}/$nonce.token';

String _fingerprintToken(String token) =>
    sha256.convert(utf8.encode(token)).toString().substring(0, 32);

String _sshIdentityKey(ConnectionSettings settings) {
  final target =
      '${settings.sshUser.trim()}@${settings.sshHost.trim().toLowerCase()}:'
      '${settings.sshPort}:${settings.sshRemoteProfile.trim()}';
  return sha256.convert(utf8.encode(target)).toString().substring(0, 24);
}

Future<String> _ownershipId(
  ConnectionSettings settings,
  ConnectionSecretStore secrets,
) async {
  final key = 'hermes.ssh.ownership.${_sshIdentityKey(settings)}.v1';
  final existing = await secrets.read(key);
  if (existing != null && RegExp(r'^[0-9a-f]{32}$').hasMatch(existing)) {
    return existing;
  }
  final created = _randomHex(16);
  await secrets.write(key, created);
  return created;
}

String _reuseTokenKey(ConnectionSettings settings) =>
    'hermes.ssh.reuse-token.${_sshIdentityKey(settings)}.v1';

// Pure contract hooks for lifecycle security tests. Network/process behavior
// remains private and is exercised through integration builds.
String sshOwnershipDirectoryForTesting(String ownershipId) =>
    _ownershipDirectory(ownershipId);

String sshSpawnTokenPathForTesting(String ownershipId, String nonce) =>
    _spawnTokenPath(ownershipId, nonce);

String sshFingerprintTokenForTesting(String token) => _fingerprintToken(token);

Map<String, dynamic>? sshParseRemoteLockForTesting(
  Map<String, dynamic> json,
  String ownershipId,
) => _RemoteLock.fromJson(json, ownershipId)?.toJson();

String sshPowerShellCommandForTesting(String script) =>
    _powerShellCommand(script);

Future<_ExecResult> _exec(
  SSHClient client,
  String command, {
  String? stdin,
  Duration timeout = const Duration(seconds: 20),
  bool allowFailure = false,
}) async {
  final session = await client.execute(command).timeout(timeout);
  final stdoutFuture = session.stdout
      .expand((bytes) => bytes)
      .toList()
      .then((bytes) => utf8.decode(bytes, allowMalformed: true));
  final stderrFuture = session.stderr
      .expand((bytes) => bytes)
      .toList()
      .then((bytes) => utf8.decode(bytes, allowMalformed: true));
  if (stdin != null) session.stdin.add(Uint8List.fromList(utf8.encode(stdin)));
  await session.stdin.close();
  await session.done.timeout(
    timeout,
    onTimeout: () {
      session.close();
      throw TimeoutException(runtimeL10n.sshCommandTimedOut, timeout);
    },
  );
  final result = _ExecResult(
    session.exitCode,
    await stdoutFuture,
    await stderrFuture,
  );
  if (!allowFailure && result.exitCode != 0) {
    throw StateError(
      result.stderr.trim().isEmpty
          ? runtimeL10n.sshRemoteCommandFailed('${result.exitCode}')
          : result.stderr.trim(),
    );
  }
  return result;
}

Future<bool> _isPosixPlatform(SSHClient client) async {
  final result = await _exec(client, 'uname -s; uname -m', allowFailure: true);
  final lines = result.stdout.trim().split(RegExp(r'\r?\n'));
  final os = lines.firstOrNull?.trim() ?? '';
  return result.exitCode == 0 && (os == 'Linux' || os == 'Darwin');
}

Future<String> _probeHermesHome(SSHClient client) async {
  final result = await _exec(
    client,
    'printf "%s" "\${HERMES_HOME:-\$HOME/.hermes}"',
  );
  final home = result.stdout.trim();
  if (home.isEmpty ||
      home.contains('..') ||
      !RegExp(r'^(?:/|~/)[A-Za-z0-9._/+\-]+$').hasMatch(home)) {
    throw StateError(runtimeL10n.sshRemoteHomeUnsafe);
  }
  return home.replaceFirst(RegExp(r'/+$'), '');
}

Future<bool> _supportsOwnership(SSHClient client, String hermesPath) async {
  final result = await _exec(
    client,
    'help="\$(${_remotePath(hermesPath)} serve --help 2>&1)"; '
    'printf "%s" "\$help" | grep -q ssh-session-token-file && '
    'printf "%s" "\$help" | grep -q ssh-owner-nonce && echo YES || echo NO',
    allowFailure: true,
  );
  return result.stdout.trim().endsWith('YES');
}

Future<({String raw, _RemoteLock? lock})> _readLock(
  SSHClient client,
  String ownershipId,
) async {
  final result = await _exec(
    client,
    'if [ -f ${_remotePath(_lockPath(ownershipId))} ]; then '
    'cat ${_remotePath(_lockPath(ownershipId))}; fi',
  );
  final raw = result.stdout.trim();
  if (raw.isEmpty) return (raw: raw, lock: null);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return (raw: raw, lock: null);
    return (
      raw: raw,
      lock: _RemoteLock.fromJson(decoded.cast<String, dynamic>(), ownershipId),
    );
  } catch (_) {
    return (raw: raw, lock: null);
  }
}

Future<void> _writeLock(
  SSHClient client,
  String ownershipId,
  _RemoteLock lock,
) async {
  final directory = _ownershipDirectory(ownershipId);
  final temporary = '$directory/.${_randomHex(8)}.lock.tmp';
  await _exec(
    client,
    'umask 077; mkdir -p ${_remotePath(directory)}; '
    'printf %s ${_quote(jsonEncode(lock.toJson()))} '
    '> ${_remotePath(temporary)}; '
    'mv -f ${_remotePath(temporary)} ${_remotePath(_lockPath(ownershipId))}',
  );
}

Future<void> _removeLock(SSHClient client, String ownershipId) => _exec(
  client,
  'rm -f ${_remotePath(_lockPath(ownershipId))}',
  allowFailure: true,
).then((_) {});

Future<bool> _pidAlive(SSHClient client, int pid) async {
  final result = await _exec(
    client,
    'kill -0 $pid 2>/dev/null && echo ALIVE || echo DEAD',
    allowFailure: true,
  );
  return result.stdout.trim() == 'ALIVE';
}

Future<bool> _pidIsOwned(
  SSHClient client,
  _RemoteLock lock,
  String ownershipId,
) async {
  final tokenPath = _spawnTokenPath(ownershipId, lock.spawnNonce);
  final script =
      '''import os,shlex,subprocess,sys
pid=${lock.pid}
expected=os.path.expanduser(${_quote(lock.hermesPath)})
expected_token=os.path.expanduser(${_quote(tokenPath)})
expected_profile=${_quote(lock.profile)}
nonce=${_quote(lock.spawnNonce)}
try:
 raw=open(f"/proc/{pid}/cmdline","rb").read()
 args=[x.decode("utf-8","surrogateescape") for x in raw.split(b"\\0") if x]
except OSError:
 try:
  line=subprocess.check_output(["ps","-ww","-o","command=","-p",str(pid)],text=True).strip()
 except subprocess.CalledProcessError:
  print("FOREIGN");sys.exit(0)
 args=shlex.split(line)
ok=False
try:
 serve=args.index("serve")
 owner=args.index("--ssh-owner-nonce",serve+1)
 token=args.index("--ssh-session-token-file",serve+1)
 isolated=args.index("--isolated",serve+1)
 profile_count=args.count("--profile")
 profile_ok=(profile_count==1 and args[args.index("--profile")+1]==expected_profile) if expected_profile else profile_count==0
 executable_ok=args[0]==expected or (len(args)>1 and args[1]==expected and os.path.basename(args[0]).startswith("python"))
 spawn_ok=args[token+1]==expected_token and args[owner+1]==nonce
 ok=(executable_ok or spawn_ok) and args.count("serve")==1 and isolated>serve and args.count("--isolated")==1 and args.count("--ssh-owner-nonce")==1 and args.count("--ssh-session-token-file")==1 and spawn_ok and profile_ok
except (ValueError,IndexError):pass
print("OWNED" if ok else "FOREIGN")''';
  final result = await _exec(
    client,
    'python3 -c ${_quote(script)}',
    allowFailure: true,
  );
  if (result.exitCode != 0) {
    throw StateError(runtimeL10n.sshOwnershipVerificationFailed);
  }
  return result.stdout.trim() == 'OWNED';
}

Future<void> _cleanupLock(
  SSHClient client,
  String ownershipId,
  _RemoteLock lock, {
  required bool alive,
}) async {
  var mayRemoveArtifacts = !alive;
  if (alive) {
    final owned = await _pidIsOwned(client, lock, ownershipId);
    if (owned) {
      await _exec(
        client,
        'kill ${lock.pid} && i=0; '
        'while kill -0 ${lock.pid} 2>/dev/null; do '
        'i=\$((i+1)); [ "\$i" -ge 50 ] && exit 1; sleep 0.1; done',
      );
      mayRemoveArtifacts = true;
    }
  }
  if (mayRemoveArtifacts) {
    await _exec(
      client,
      'rm -f ${_remotePath(lock.logPath)} '
      '${_remotePath(_spawnTokenPath(ownershipId, lock.spawnNonce))}',
      allowFailure: true,
    );
  }
  await _removeLock(client, ownershipId);
}

Future<void> _uploadToken(
  SSHClient client,
  String ownershipId,
  String nonce,
  String token,
) async {
  final tokenPath = _spawnTokenPath(ownershipId, nonce);
  final script =
      '''import os,stat,sys
p=os.path.expanduser(${_quote(tokenPath)})
d=os.path.dirname(p)
n=os.path.basename(p)
os.makedirs(d,mode=0o700,exist_ok=True)
df=os.O_RDONLY|getattr(os,"O_DIRECTORY",0)|getattr(os,"O_NOFOLLOW",0)
dd=os.open(d,df)
try:
 s=os.fstat(dd)
 if not stat.S_ISDIR(s.st_mode):raise SystemExit("unsafe token directory")
 if hasattr(os,"getuid") and s.st_uid!=os.getuid():raise SystemExit("token directory owner mismatch")
 if (s.st_mode&0o777)!=0o700:os.fchmod(dd,0o700)
 fl=os.O_WRONLY|os.O_CREAT|os.O_EXCL|getattr(os,"O_NOFOLLOW",0)
 fd=os.open(n,fl,0o600,dir_fd=dd)
 try:os.write(fd,sys.stdin.buffer.read())
 except BaseException:
  try:os.unlink(n,dir_fd=dd)
  except OSError:pass
  raise
 finally:os.close(fd)
finally:os.close(dd)''';
  await _exec(client, 'python3 -c ${_quote(script)}', stdin: token);
}

Future<bool> _probeOwnership(String baseUrl, String token, String nonce) async {
  final response = await http
      .get(
        Uri.parse('$baseUrl/api/ssh/ownership'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 8));
  if (response.statusCode == 401 ||
      response.statusCode == 403 ||
      response.statusCode == 404) {
    return false;
  }
  if (response.statusCode != 200) {
    throw StateError(
      runtimeL10n.sshOwnershipProbeFailed('${response.statusCode}'),
    );
  }
  final body = jsonDecode(response.body);
  return body is Map &&
      body['ok'] == true &&
      body['sshOwnerNonce'] == nonce &&
      body['protocolVersion'] == _protocolVersion;
}

String _psLiteral(String value) => "'${value.replaceAll("'", "''")}'";

String _powerShellCommand(String script) {
  final bytes = <int>[];
  for (final unit in script.codeUnits) {
    bytes
      ..add(unit & 0xff)
      ..add((unit >> 8) & 0xff);
  }
  return 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass '
      '-EncodedCommand ${base64.encode(bytes)}';
}

class _WindowsRuntime {
  final String arch;
  final String hermesHome;
  final String hermesPath;
  final String pythonPath;

  const _WindowsRuntime({
    required this.arch,
    required this.hermesHome,
    required this.hermesPath,
    required this.pythonPath,
  });
}

Future<Map<String, dynamic>> _execJson(
  SSHClient client,
  String command, {
  String? stdin,
}) async {
  final result = await _exec(client, command, stdin: stdin);
  final lines = result.stdout
      .replaceFirst('\ufeff', '')
      .trim()
      .split(RegExp(r'\r?\n'))
      .where((line) => line.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return {};
  final decoded = jsonDecode(lines.last);
  if (decoded == null) return {};
  if (decoded is! Map) throw StateError(runtimeL10n.sshHelperInvalidJson);
  final map = decoded.cast<String, dynamic>();
  if (map['error'] != null) throw StateError(map['error'].toString());
  return map;
}

Future<_WindowsRuntime> _probeWindowsRuntime(
  SSHClient client,
  String configuredPath,
) async {
  final script = [
    r'$ErrorActionPreference="Stop"',
    '\$explicit=${_psLiteral(configuredPath)}',
    r'$hermesHome=$env:HERMES_HOME',
    r'if(-not $hermesHome){$hermesHome=Join-Path $env:LOCALAPPDATA "hermes"}',
    r'$candidates=@()',
    r'if($explicit){$candidates+=$explicit}',
    r'$cmd=Get-Command hermes.exe -ErrorAction SilentlyContinue',
    r'if($cmd){$candidates+=$cmd.Source}',
    r'$candidates+=(Join-Path $hermesHome "hermes-agent\venv\Scripts\hermes.exe")',
    r'$candidates+=(Join-Path $HOME "hermes-agent\.venv\Scripts\hermes.exe")',
    r'$hermes=$candidates|Where-Object{Test-Path -LiteralPath $_ -PathType Leaf}|Select-Object -First 1',
    r'if(-not $hermes){throw "Hermes is not installed on the remote Windows host."}',
    r'if($explicit -and $hermes -ne $explicit){throw "The configured Hermes path is not executable."}',
    r'$python=Join-Path (Split-Path $hermes) "python.exe"',
    r'if(-not (Test-Path -LiteralPath $python -PathType Leaf)){throw "The remote Hermes Python runtime was not found."}',
    r'[ordered]@{arch=$env:PROCESSOR_ARCHITECTURE;hermesHome=$hermesHome;hermesPath=$hermes;python=$python}|ConvertTo-Json -Compress',
  ].join(';');
  try {
    final data = await _execJson(client, _powerShellCommand(script));
    return _WindowsRuntime(
      arch: data['arch']?.toString() ?? '',
      hermesHome: data['hermesHome']?.toString() ?? '',
      hermesPath: data['hermesPath']?.toString() ?? '',
      pythonPath: data['python']?.toString() ?? '',
    );
  } catch (error) {
    throw UnsupportedError(runtimeL10n.sshRemotePlatformUnsupported('$error'));
  }
}

String _windowsHelperCommand(
  _WindowsRuntime runtime,
  String operation, [
  List<String> args = const [],
]) {
  final argv = [
    runtime.pythonPath,
    '-m',
    'hermes_cli.windows_ssh_runtime',
    operation,
    ...args,
  ];
  final script = [
    r'$ErrorActionPreference="Stop"',
    '& ${argv.map(_psLiteral).join(' ')}',
    r'if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}',
  ].join(';');
  return _powerShellCommand(script);
}

Future<Map<String, dynamic>> _windowsHelper(
  SSHClient client,
  _WindowsRuntime runtime,
  String operation, {
  List<String> args = const [],
  String? stdin,
}) => _execJson(
  client,
  _windowsHelperCommand(runtime, operation, args),
  stdin: stdin,
);

bool _validWindowsLock(Map<String, dynamic> lock, String ownershipId) {
  final pid = lock['pid'];
  final port = lock['port'];
  return lock['schemaVersion'] == _lockSchemaVersion &&
      lock['protocolVersion'] == _protocolVersion &&
      lock['ownershipId'] == ownershipId &&
      RegExp(
        r'^[0-9a-f]{16}$',
      ).hasMatch(lock['spawnNonce']?.toString() ?? '') &&
      pid is int &&
      pid > 0 &&
      RegExp(
        r'^[0-9]{10,20}$',
      ).hasMatch(lock['creationTimeNs']?.toString() ?? '') &&
      port is int &&
      port >= 0 &&
      port <= 65535 &&
      RegExp(
        r'^[0-9a-f]{32}$',
      ).hasMatch(lock['tokenFingerprint']?.toString() ?? '') &&
      lock['hermesPath'] is String &&
      lock['hermesHome'] is String &&
      lock['profile'] is String;
}

Future<Map<String, dynamic>> _windowsProcessState(
  SSHClient client,
  _WindowsRuntime runtime,
  Map<String, dynamic> lock,
) => _windowsHelper(
  client,
  runtime,
  'process-state',
  args: [
    '${lock['pid']}',
    '${lock['creationTimeNs']}',
    '${lock['hermesPath']}',
    '${lock['spawnNonce']}',
  ],
);

Future<void> _cleanupWindowsLock(
  SSHClient client,
  _WindowsRuntime runtime,
  String ownershipId,
  Map<String, dynamic> lock,
) async {
  final state = await _windowsProcessState(client, runtime, lock);
  if (state['indeterminate'] == true) {
    throw StateError(runtimeL10n.sshWindowsOwnershipVerificationFailed);
  }
  final owned = state['alive'] == true && state['owned'] == true;
  if (owned) {
    await _windowsHelper(
      client,
      runtime,
      'terminate',
      args: [
        '${lock['pid']}',
        '${lock['creationTimeNs']}',
        '${lock['hermesPath']}',
        '${lock['spawnNonce']}',
      ],
    );
  }
  if (owned || state['alive'] != true) {
    await _windowsHelper(
      client,
      runtime,
      'remove-token',
      args: [ownershipId, '${lock['spawnNonce']}'],
    );
    await _windowsHelper(
      client,
      runtime,
      'remove-log',
      args: [ownershipId, '${lock['spawnNonce']}'],
    );
  }
  await _windowsHelper(client, runtime, 'remove-lock', args: [ownershipId]);
}

Future<String> _locateHermes(SSHClient client, String configuredPath) async {
  final configured = configuredPath.trim();
  if (configured.isNotEmpty) {
    if (!(configured.startsWith('/') || configured.startsWith('~/')) ||
        configured.contains(RegExp(r'[\x00\r\n]'))) {
      throw ArgumentError(runtimeL10n.sshRemotePathInvalid);
    }
    final probe = await _exec(
      client,
      'test -x ${_remotePath(configured)} && echo OK',
      allowFailure: true,
    );
    if (probe.stdout.trim() != 'OK') {
      throw StateError(runtimeL10n.sshExecutableNotFound);
    }
    return configured;
  }
  final result = await _exec(
    client,
    "bash -lc 'command -v hermes' 2>/dev/null || "
    'for p in "\$HOME/.local/bin/hermes" /usr/local/bin/hermes '
    '"\$HOME/.hermes/hermes-agent/venv/bin/hermes"; do '
    'test -x "\$p" && echo "\$p" && break; done',
    allowFailure: true,
  );
  final path = result.stdout.trim().split('\n').lastOrNull?.trim() ?? '';
  if (path.isEmpty || !path.startsWith('/')) {
    throw StateError(runtimeL10n.sshHermesNotInstalled);
  }
  return path;
}

Future<SshGatewayTunnel> _openWindowsTunnel(
  SSHClient client,
  ConnectionSettings settings,
  ConnectionSecretStore secrets,
  String profile,
) async {
  final runtime = await _probeWindowsRuntime(
    client,
    settings.sshRemoteHermesPath.trim(),
  );
  final inspection = await _windowsHelper(
    client,
    runtime,
    'inspect',
    args: [runtime.hermesPath],
  );
  if (inspection['supported'] != true) {
    throw StateError(runtimeL10n.sshBootstrapFlagsUnsupported);
  }
  final resolvedRuntime = _WindowsRuntime(
    arch: runtime.arch,
    hermesHome: runtime.hermesHome,
    hermesPath: inspection['path']?.toString() ?? runtime.hermesPath,
    pythonPath: runtime.pythonPath,
  );
  final ownershipId = await _ownershipId(settings, secrets);
  final reuseKey = _reuseTokenKey(settings);
  final reuseToken = await secrets.read(reuseKey) ?? '';
  final existing = await _windowsHelper(
    client,
    resolvedRuntime,
    'read-lock',
    args: [ownershipId],
  );

  if (existing.isNotEmpty && !_validWindowsLock(existing, ownershipId)) {
    await _windowsHelper(
      client,
      resolvedRuntime,
      'remove-lock',
      args: [ownershipId],
    );
  } else if (existing.isNotEmpty) {
    final state = await _windowsProcessState(client, resolvedRuntime, existing);
    if (state['indeterminate'] == true) {
      throw StateError(runtimeL10n.sshWindowsOwnershipVerificationFailed);
    }
    final reusable =
        state['alive'] == true &&
        state['owned'] == true &&
        (existing['port'] as int) > 0 &&
        existing['profile'] == profile &&
        reuseToken.isNotEmpty &&
        existing['tokenFingerprint'] == _fingerprintToken(reuseToken) &&
        existing['hermesPath'] == resolvedRuntime.hermesPath &&
        existing['hermesHome'] == resolvedRuntime.hermesHome;
    if (reusable) {
      final remotePort = existing['port'] as int;
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final tunnel = _IoSshGatewayTunnel(client, server, remotePort);
      tunnel.apiKey = reuseToken;
      try {
        if (await _probeOwnership(
          tunnel.baseUrl,
          reuseToken,
          existing['spawnNonce'].toString(),
        )) {
          return tunnel;
        }
        await tunnel._close(closeClient: false);
        await _cleanupWindowsLock(
          client,
          resolvedRuntime,
          ownershipId,
          existing,
        );
      } catch (_) {
        await tunnel._close(closeClient: false);
        rethrow;
      }
    } else {
      await _cleanupWindowsLock(client, resolvedRuntime, ownershipId, existing);
    }
  }

  final token = _randomHex(32);
  final nonce = _randomHex(8);
  await _windowsHelper(
    client,
    resolvedRuntime,
    'upload-token',
    args: [ownershipId, nonce],
    stdin: token,
  );
  Map<String, dynamic> spawned;
  try {
    spawned = await _windowsHelper(
      client,
      resolvedRuntime,
      'spawn',
      stdin: jsonEncode({
        'ownershipId': ownershipId,
        'spawnNonce': nonce,
        'profile': profile,
        'hermesPath': resolvedRuntime.hermesPath,
      }),
    );
  } catch (_) {
    await _windowsHelper(
      client,
      resolvedRuntime,
      'remove-token',
      args: [ownershipId, nonce],
    );
    rethrow;
  }

  final lock = <String, dynamic>{
    'schemaVersion': _lockSchemaVersion,
    'protocolVersion': _protocolVersion,
    'ownershipId': ownershipId,
    'spawnNonce': nonce,
    'pid': spawned['pid'],
    'creationTimeNs': spawned['creationTimeNs']?.toString(),
    'port': 0,
    'profile': profile,
    'hermesPath': resolvedRuntime.hermesPath,
    'hermesHome': resolvedRuntime.hermesHome,
    'tokenFingerprint': _fingerprintToken(token),
    'startedAt': DateTime.now().toUtc().toIso8601String(),
  };
  if (!_validWindowsLock(lock, ownershipId)) {
    await _windowsHelper(
      client,
      resolvedRuntime,
      'remove-token',
      args: [ownershipId, nonce],
    );
    throw StateError(runtimeL10n.sshWindowsIdentityInvalid);
  }
  try {
    await _windowsHelper(
      client,
      resolvedRuntime,
      'write-lock',
      args: [ownershipId],
      stdin: jsonEncode(lock),
    );
    final deadline = DateTime.now().add(_readyTimeout);
    int? remotePort;
    String lastLog = '';
    while (DateTime.now().isBefore(deadline)) {
      final state = await _windowsProcessState(client, resolvedRuntime, lock);
      if (state['indeterminate'] != true &&
          (state['alive'] != true || state['owned'] != true)) {
        throw StateError(runtimeL10n.sshWindowsExitedBeforeReady);
      }
      final log = await _windowsHelper(
        client,
        resolvedRuntime,
        'read-log',
        args: [ownershipId, nonce],
      );
      lastLog = log['content']?.toString() ?? '';
      final matches = RegExp(
        r'^HERMES_(?:BACKEND|DASHBOARD)_READY port=(\d+)',
        multiLine: true,
      ).allMatches(lastLog);
      if (matches.isNotEmpty) {
        remotePort = int.tryParse(matches.last.group(1) ?? '');
        if (remotePort != null) break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
    if (remotePort == null) {
      final tail = lastLog.length > 600
          ? lastLog.substring(lastLog.length - 600)
          : lastLog;
      throw TimeoutException(
        'Remote Windows backend did not become ready: ${tail.trim()}',
      );
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final tunnel = _IoSshGatewayTunnel(client, server, remotePort);
    tunnel.apiKey = token;
    try {
      if (!await _probeOwnership(tunnel.baseUrl, token, nonce)) {
        throw StateError(runtimeL10n.sshWindowsOwnershipProofFailed);
      }
      lock['port'] = remotePort;
      await _windowsHelper(
        client,
        resolvedRuntime,
        'write-lock',
        args: [ownershipId],
        stdin: jsonEncode(lock),
      );
      await secrets.write(reuseKey, token);
      return tunnel;
    } catch (_) {
      await tunnel._close(closeClient: false);
      rethrow;
    }
  } catch (_) {
    await _cleanupWindowsLock(client, resolvedRuntime, ownershipId, lock);
    rethrow;
  }
}

Future<SshGatewayTunnel> openSshGatewayTunnel(
  ConnectionSettings settings, {
  required ConnectionSecretStore secrets,
}) async {
  final host = settings.sshHost.trim();
  final user = settings.sshUser.trim();
  if (host.isEmpty || user.isEmpty) {
    throw ArgumentError(runtimeL10n.sshHostAndUserRequired);
  }
  if (settings.sshPort < 1 || settings.sshPort > 65535) {
    throw ArgumentError(runtimeL10n.sshPortInvalid);
  }

  final identities = settings.sshPrivateKey.trim().isEmpty
      ? null
      : SSHKeyPair.fromPem(
          settings.sshPrivateKey,
          settings.sshPrivateKeyPassphrase.isEmpty
              ? null
              : settings.sshPrivateKeyPassphrase,
        );
  final knownHostKey = _knownHostKey(settings);
  final knownFingerprint = await secrets.read(knownHostKey);
  String? observedFingerprint;
  var hostKeyChanged = false;
  final socket = await SSHSocket.connect(
    host,
    settings.sshPort,
  ).timeout(_connectTimeout);
  final client = SSHClient(
    socket,
    username: user,
    identities: identities,
    onPasswordRequest: settings.sshPassword.isEmpty
        ? null
        : () => settings.sshPassword,
    onVerifyHostKey: (type, fingerprint) {
      observedFingerprint = utf8.decode(fingerprint);
      if (knownFingerprint == null || knownFingerprint.isEmpty) return true;
      hostKeyChanged = knownFingerprint != observedFingerprint;
      return !hostKeyChanged;
    },
    handshakeTimeout: _connectTimeout,
    authTimeout: _connectTimeout,
  );
  try {
    await client.authenticated.timeout(_connectTimeout);
  } catch (error) {
    client.close();
    if (hostKeyChanged) {
      throw StateError(
        runtimeL10n.sshHostKeyChanged(
          host,
          '$knownFingerprint',
          '$observedFingerprint',
        ),
      );
    }
    rethrow;
  }
  if (knownFingerprint == null && observedFingerprint != null) {
    await secrets.write(knownHostKey, observedFingerprint!);
  }

  final profile = settings.sshRemoteProfile.trim();
  if (profile.isNotEmpty &&
      !RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$').hasMatch(profile)) {
    client.close();
    throw ArgumentError(runtimeL10n.sshProfileInvalid);
  }
  try {
    if (!await _isPosixPlatform(client)) {
      return await _openWindowsTunnel(client, settings, secrets, profile);
    }
    final hermesPath = await _locateHermes(
      client,
      settings.sshRemoteHermesPath,
    );
    final hermesHome = await _probeHermesHome(client);
    if (!await _supportsOwnership(client, hermesPath)) {
      throw StateError(
        'Remote Hermes must support --ssh-session-token-file and --ssh-owner-nonce',
      );
    }

    final ownershipId = await _ownershipId(settings, secrets);
    final reuseKey = _reuseTokenKey(settings);
    final reuseToken = await secrets.read(reuseKey) ?? '';
    final lockResult = await _readLock(client, ownershipId);
    final existing = lockResult.lock;
    if (existing == null && lockResult.raw.isNotEmpty) {
      // Malformed data cannot prove ownership. Remove only the record and
      // never infer a process to terminate from it.
      await _removeLock(client, ownershipId);
    } else if (existing != null) {
      final alive = await _pidAlive(client, existing.pid);
      final owned = alive && await _pidIsOwned(client, existing, ownershipId);
      final reusable =
          owned &&
          existing.port > 0 &&
          existing.profile == profile &&
          reuseToken.isNotEmpty &&
          existing.tokenFingerprint == _fingerprintToken(reuseToken) &&
          existing.hermesPath == hermesPath &&
          existing.hermesHome == hermesHome;
      if (reusable) {
        final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
        final tunnel = _IoSshGatewayTunnel(client, server, existing.port);
        tunnel.apiKey = reuseToken;
        try {
          if (await _probeOwnership(
            tunnel.baseUrl,
            reuseToken,
            existing.spawnNonce,
          )) {
            return tunnel;
          }
          await tunnel._close(closeClient: false);
          await _cleanupLock(client, ownershipId, existing, alive: alive);
        } catch (_) {
          await tunnel._close(closeClient: false);
          rethrow;
        }
      } else {
        await _cleanupLock(client, ownershipId, existing, alive: alive);
      }
    }

    final token = _randomHex(32);
    final nonce = _randomHex(8);
    final tokenPath = _spawnTokenPath(ownershipId, nonce);
    final logPath = _spawnLogPath(ownershipId, nonce);
    await _uploadToken(client, ownershipId, nonce, token);

    final profileArgs = profile.isEmpty ? '' : '--profile ${_quote(profile)} ';
    final serve =
        'ulimit -n 65536 2>/dev/null || true; '
        'exec env HERMES_DESKTOP=1 ${_remotePath(hermesPath)} '
        '${profileArgs}serve --isolated --host 127.0.0.1 --port 0 '
        '--ssh-session-token-file ${_remotePath(tokenPath)} '
        '--ssh-owner-nonce $nonce';
    final spawn = await _exec(
      client,
      'nohup sh -c ${_quote(serve)} </dev/null '
      '>> ${_remotePath(logPath)} 2>&1 & echo \$!',
    );
    final pid = int.tryParse(spawn.stdout.trim().split('\n').last);
    if (pid == null || pid <= 0) {
      await _exec(
        client,
        'rm -f ${_remotePath(tokenPath)}',
        allowFailure: true,
      );
      throw StateError(runtimeL10n.sshProcessIdMissing);
    }

    var lock = _RemoteLock(
      ownershipId: ownershipId,
      spawnNonce: nonce,
      pid: pid,
      port: 0,
      profile: profile,
      hermesPath: hermesPath,
      hermesHome: hermesHome,
      logPath: logPath,
      tokenFingerprint: _fingerprintToken(token),
      startedAt: DateTime.now().toUtc().toIso8601String(),
    );
    try {
      // Persist port=0 immediately so an interrupted bootstrap remains safely
      // reclaimable on the next launch.
      await _writeLock(client, ownershipId, lock);
      final deadline = DateTime.now().add(_readyTimeout);
      int? remotePort;
      String lastLog = '';
      while (DateTime.now().isBefore(deadline)) {
        if (!await _pidAlive(client, pid)) {
          throw StateError(runtimeL10n.sshExitedBeforeReady);
        }
        final probe = await _exec(
          client,
          'cat ${_remotePath(logPath)} 2>/dev/null || true',
          allowFailure: true,
        );
        lastLog = probe.stdout;
        final match = RegExp(
          r'^HERMES_(?:BACKEND|DASHBOARD)_READY port=(\d+)',
          multiLine: true,
        ).firstMatch(lastLog);
        remotePort = int.tryParse(match?.group(1) ?? '');
        if (remotePort != null) break;
        await Future<void>.delayed(const Duration(milliseconds: 750));
      }
      if (remotePort == null) {
        final tail = lastLog.length > 600
            ? lastLog.substring(lastLog.length - 600)
            : lastLog;
        throw TimeoutException(
          'Remote Hermes did not become ready: ${tail.trim()}',
        );
      }

      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final tunnel = _IoSshGatewayTunnel(client, server, remotePort);
      tunnel.apiKey = token;
      try {
        if (!await _probeOwnership(tunnel.baseUrl, token, nonce)) {
          throw StateError(runtimeL10n.sshOwnershipProofFailed);
        }
        lock = lock.withPort(remotePort);
        await _writeLock(client, ownershipId, lock);
        await secrets.write(reuseKey, token);
        return tunnel;
      } catch (_) {
        await tunnel._close(closeClient: false);
        rethrow;
      }
    } catch (_) {
      await _cleanupLock(client, ownershipId, lock, alive: true);
      rethrow;
    }
  } catch (_) {
    client.close();
    rethrow;
  }
}
