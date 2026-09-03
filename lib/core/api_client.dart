/// Thin REST client for the Hermes Mobile Server **domain API**.
///
/// All requests go to ``<server>/api/v1/*`` resources (see server/DESIGN.md).
/// The client only ever deals with durable session ids.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import 'model_catalog.dart';
import 'models.dart';
import 'composer_draft_store.dart';
import 'performance_metrics.dart';
import '../theme/hermes_tokens.dart';
import '../l10n/runtime_l10n.dart';

class ApiCapabilities {
  final bool methodDiscovery;
  final bool backendRestart;
  final bool serverLogs;
  final bool sessionSharing;
  final bool fileMove;
  final bool fileCopy;
  final bool fileReveal;
  final bool terminalExecute;

  const ApiCapabilities({
    required this.methodDiscovery,
    required this.backendRestart,
    required this.serverLogs,
    required this.sessionSharing,
    required this.fileMove,
    required this.fileCopy,
    required this.fileReveal,
    required this.terminalExecute,
  });

  factory ApiCapabilities.forTransport({required bool directGateway}) =>
      ApiCapabilities(
        methodDiscovery: !directGateway,
        backendRestart: !directGateway,
        serverLogs: !directGateway,
        sessionSharing: !directGateway,
        fileMove: !directGateway,
        fileCopy: !directGateway,
        fileReveal: !directGateway,
        terminalExecute: !directGateway,
      );
}

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final Map<String, dynamic>? details;

  ApiException(this.statusCode, this.message, [this.details]);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thrown by [ApiClient.fsReadText] when the requested file's bytes do not
/// look like text (null bytes present, or the bytes are not valid UTF-8).
/// The spot editor must never open — let alone save — a binary file: doing
/// so would round-trip it through a lossy UTF-8 decode and silently corrupt
/// it on save.
class BinaryFileException implements Exception {
  final String path;

  const BinaryFileException(this.path);

  @override
  String toString() => 'BinaryFileException: $path';
}

/// Best-effort binary sniff over a byte sample: a NUL byte is a strong
/// binary signal, and bytes that fail strict (non-lenient) UTF-8 decoding
/// are not valid text either.
bool looksLikeBinary(List<int> bytes) {
  final sample = bytes.length > 8192 ? bytes.sublist(0, 8192) : bytes;
  if (sample.contains(0)) return true;
  try {
    utf8.decode(sample, allowMalformed: false);
    return false;
  } on FormatException {
    return true;
  }
}

class ApiClient {
  final String baseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  final Future<String> Function()? accessTokenProvider;
  final Future<Map<String, dynamic>> Function(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
  })?
  gatewayRequest;
  final bool directGateway;
  final void Function()? onClose;
  final http.Client _client;
  final Duration requestTimeout;
  final int readRetryAttempts;
  final Future<void> Function(Duration delay) _retryDelay;
  final Map<String, Future<dynamic>> _inflightReads = {};
  late final ComposerDraftStore _draftStore = ComposerDraftStore(baseUrl);

  ApiClient({
    required this.baseUrl,
    required this.apiKey,
    this.extraHeaders = const {},
    this.accessTokenProvider,
    this.gatewayRequest,
    this.directGateway = false,
    this.onClose,
    this.requestTimeout = HermesPolicy.httpTimeout,
    this.readRetryAttempts = 1,
    Future<void> Function(Duration delay)? retryDelay,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _retryDelay = retryDelay ?? Future<void>.delayed;

  void close() {
    _client.close();
    onClose?.call();
  }

  late final ApiCapabilities capabilities = ApiCapabilities.forTransport(
    directGateway: directGateway,
  );

  bool get supportsSessionSharing => capabilities.sessionSharing;

  Future<http.Response> _bounded(
    Future<http.Response> request, {
    Duration? timeout,
  }) => request.timeout(timeout ?? requestTimeout);

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{};
    for (final entry in extraHeaders.entries) {
      final lower = entry.key.trim().toLowerCase();
      if (lower == 'authorization' || lower == 'content-type') continue;
      if (entry.key.trim().isNotEmpty && entry.value.trim().isNotEmpty) {
        headers[entry.key.trim()] = entry.value.trim();
      }
    }
    return {
      ...headers,
      'Authorization':
          'Bearer ${accessTokenProvider == null ? apiKey : await accessTokenProvider!()}',
      'Content-Type': 'application/json',
    };
  }

  String _seg(Object value) => Uri.encodeComponent(value.toString());

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    throw ApiException(0, runtimeL10n.errorExpectedObjectResponse);
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final resolvedPath = directGateway ? _directGatewayPath(path) : path;
    var uri = Uri.parse('$baseUrl$resolvedPath');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
    }
    return uri;
  }

  String _directGatewayPath(String path) {
    const exact = {
      '/api/v1/sessions/batch-delete': '/api/sessions/bulk-delete',
      '/api/v1/cron': '/api/cron/jobs',
      '/api/v1/cron/delivery-targets': '/api/cron/delivery-targets',
      '/api/v1/cron/blueprints': '/api/cron/blueprints',
      '/api/v1/tools': '/api/tools/toolsets',
      '/api/v1/files/entries': '/api/files',
      '/api/v1/files/read-data-url': '/api/files/read',
      '/api/v1/config/replace': '/api/config/raw',
      '/api/v1/profiles/active': '/api/profiles/active',
      '/api/v1/tools/computer-use/status': '/api/tools/computer-use/status',
      '/api/v1/tools/computer-use/permissions/grant':
          '/api/tools/computer-use/permissions/grant',
    };
    final mapped = exact[path];
    if (mapped != null) return mapped;
    if (path.startsWith('/api/v1/cron/')) {
      final suffix = path.substring('/api/v1/cron/'.length);
      if (suffix.startsWith('delivery-targets') ||
          suffix.startsWith('blueprints')) {
        return '/api/cron/$suffix';
      }
      return '/api/cron/jobs/$suffix';
    }
    if (path.startsWith('/api/v1/tools/')) {
      return '/api/tools/toolsets/${path.substring('/api/v1/tools/'.length)}';
    }
    if (path.startsWith('/api/v1/starmap/')) {
      return '/api/learning/${path.substring('/api/v1/starmap/'.length)}';
    }
    if (path.startsWith('/api/v1/kanban/')) {
      return '/api/plugins/kanban/${path.substring('/api/v1/kanban/'.length)}';
    }
    return path.replaceFirst('/api/v1/', '/api/');
  }

  /// Build the Kanban event endpoint using the same transport mapping and
  /// credential source as REST. OAuth tokens are refreshed on every reconnect.
  Future<Uri> kanbanEventsUri({
    required String board,
    required int since,
  }) async {
    final base = Uri.parse(baseUrl);
    final token = accessTokenProvider == null
        ? apiKey
        : await accessTokenProvider!();
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: directGateway
          ? '/api/plugins/kanban/events'
          : '/api/v1/kanban/events',
      queryParameters: {
        'token': token,
        if (board.isNotEmpty) 'board': board,
        'since': '$since',
      },
    );
  }

  Never _unsupportedDirectGateway(String feature) =>
      throw ApiException(501, runtimeL10n.errorDirectGatewayFeatureUnavailable);

  Future<Map<String, dynamic>> _directRpc(
    String method,
    Map<String, dynamic> params,
    String feature, {
    Duration? timeout,
  }) async {
    final request = gatewayRequest;
    if (request == null) _unsupportedDirectGateway(feature);
    return _asMap(await request(method, params, timeout: timeout));
  }

  Map<String, dynamic> _requireOk(Map<String, dynamic> result, String feature) {
    if (result['ok'] != false) return result;
    final error = result['error'];
    final message = error is Map
        ? error['message'] ?? error['error']
        : result['message'] ?? error;
    throw ApiException(
      422,
      message == null
          ? runtimeL10n.commonOperationFailed
          : runtimeL10n.errorOperationFailedWithDetail('$message'),
      result,
    );
  }

  String? _envelopeErrorMessage(Map<dynamic, dynamic> body) {
    final error = body['error'];
    if (error is Map) {
      final nested = error['message'] ?? error['error'];
      if (nested != null) return nested.toString();
    } else if (error != null) {
      return error.toString();
    }
    final message = body['message'];
    if (message != null) return message.toString();
    final detail = body['detail'];
    if (detail is Map) {
      return (detail['message'] ?? detail['error'] ?? detail).toString();
    }
    if (detail != null && detail is! List) return detail.toString();
    return null;
  }

  dynamic _decode(http.Response resp, {bool rejectExplicitFailure = false}) {
    if (resp.statusCode >= 400) {
      String detail = resp.body;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map) {
          final envelopeMessage = _envelopeErrorMessage(body);
          if (envelopeMessage != null) {
            detail = envelopeMessage;
          } else if (body['detail'] is List) {
            detail = (body['detail'] as List)
                .map((item) {
                  if (item is! Map) return item.toString();
                  final loc = (item['loc'] as List? ?? const [])
                      .map((part) => part.toString())
                      .join('.');
                  final message = (item['msg'] ?? item['message'] ?? item)
                      .toString();
                  return loc.isEmpty ? message : '$loc: $message';
                })
                .join('; ');
          }
        }
      } catch (_) {}
      Map<String, dynamic>? details;
      try {
        final body = jsonDecode(resp.body);
        if (body is Map) details = body.cast<String, dynamic>();
      } catch (_) {}
      throw ApiException(resp.statusCode, detail, details);
    }
    if (resp.body.isEmpty) return null;
    final started = DateTime.now();
    final decoded = jsonDecode(resp.body);
    ClientPerformanceMetrics.instance.recordJsonDecode(
      resp.bodyBytes.length,
      DateTime.now().difference(started),
    );
    if (rejectExplicitFailure && decoded is Map && decoded['ok'] == false) {
      final result = decoded.cast<String, dynamic>();
      throw ApiException(
        422,
        _envelopeErrorMessage(result) ?? runtimeL10n.commonOperationFailed,
        result,
      );
    }
    return decoded;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) {
    final uri = _uri(path, query);
    final key = '${uri.toString()}\u0000${timeout?.inMicroseconds ?? -1}';
    final existing = _inflightReads[key];
    if (existing != null) return existing;
    final request = _getWithRetry(uri, timeout: timeout);
    _inflightReads[key] = request;
    return request.whenComplete(() {
      if (identical(_inflightReads[key], request)) _inflightReads.remove(key);
    });
  }

  Future<dynamic> _getWithRetry(Uri uri, {Duration? timeout}) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt <= readRetryAttempts; attempt++) {
      try {
        final resp = await _bounded(
          _client.get(uri, headers: await _headers()),
          timeout: timeout,
        );
        final metrics = ClientPerformanceMetrics.instance;
        metrics.httpResponseBytes += resp.bodyBytes.length;
        if (uri.path.endsWith('/sessions')) {
          metrics.sessionResponseBytes += resp.bodyBytes.length;
        }
        if (_isTransientReadStatus(resp.statusCode) &&
            attempt < readRetryAttempts) {
          await _retryDelay(_readRetryDelay(attempt));
          continue;
        }
        return _decode(resp);
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
      if (attempt < readRetryAttempts) {
        await _retryDelay(_readRetryDelay(attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static bool _isTransientReadStatus(int status) =>
      status == 408 || status == 429 || status >= 500;

  static Duration _readRetryDelay(int attempt) =>
      Duration(milliseconds: attempt == 0 ? 250 : 750);

  Future<dynamic> post(
    String path, {
    Object? body,
    Duration? timeout,
    Map<String, String>? query,
    bool allowExplicitFailure = false,
  }) async {
    final resp = await _bounded(
      _client.post(
        _uri(path, query),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
      timeout: timeout,
    );
    return _decode(resp, rejectExplicitFailure: !allowExplicitFailure);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final resp = await _bounded(
      _client.put(
        _uri(path, query),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(resp, rejectExplicitFailure: true);
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final resp = await _bounded(
      _client.patch(
        _uri(path, query),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(resp, rejectExplicitFailure: true);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final resp = await _bounded(
      _client.delete(
        _uri(path, query),
        headers: await _headers(),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(resp, rejectExplicitFailure: true);
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String field,
    required String filename,
    required Uint8List bytes,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    // Retries only a transport-level failure (the request never reached a
    // server response) — the same policy as `_getWithRetry`, and safe for
    // the same reason: a response the server DID send (even an error one)
    // means it may have already processed the upload, so only a case where
    // we know nothing was received is worth resending. A fresh
    // `MultipartRequest` per attempt: the request body stream is single-use.
    final effectiveTimeout = timeout ?? requestTimeout;
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt <= readRetryAttempts; attempt++) {
      try {
        final request = http.MultipartRequest('POST', _uri(path, query));
        final headers = (await _headers())..remove('Content-Type');
        request.headers.addAll(headers);
        request.fields.addAll(fields);
        request.files.add(
          http.MultipartFile.fromBytes(field, bytes, filename: filename),
        );
        // NOT `request.send()`: per the `http` package's own docs, that
        // spins up a brand-new default `Client()` per call, silently
        // bypassing whatever `_client` this `ApiClient` was actually
        // configured with.
        final streamed = await _client.send(request).timeout(effectiveTimeout);
        return _decode(
          await http.Response.fromStream(streamed),
          rejectExplicitFailure: true,
        );
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
      if (attempt < readRetryAttempts) {
        await _retryDelay(_readRetryDelay(attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  Future<({Uint8List bytes, String filename})> downloadBytes(
    String path, {
    Map<String, String>? query,
  }) async {
    final resp = await _bounded(
      _client.get(_uri(path, query), headers: await _headers()),
    );
    if (resp.statusCode >= 400) {
      _decode(resp);
    }
    final disposition = resp.headers['content-disposition'] ?? '';
    final match = RegExp(
      r'''filename\*?=(?:UTF-8''|["'])?([^"';]+)''',
      caseSensitive: false,
    ).firstMatch(disposition);
    return (
      bytes: resp.bodyBytes,
      filename: Uri.decodeComponent(match?.group(1) ?? 'download'),
    );
  }

  // ------------------------------------------------------------------ mgmt
  Future<Map<String, dynamic>> status() async {
    final data = await get('/api/v1/status');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> methods() async {
    if (!capabilities.methodDiscovery) {
      return const {
        'source': 'client-known-direct-gateway',
        'rest': {'resources': <String>[]},
      };
    }
    final data = await get('/api/v1/methods');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> health() async {
    // Health is unauthenticated on purpose.
    final resp = await _bounded(
      _client.get(_uri('/api/v1/health'), headers: await _headers()),
    );
    if (resp.statusCode != 200) {
      throw ApiException(resp.statusCode, resp.body);
    }
    return (jsonDecode(resp.body) as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> restartBackend() async {
    if (!capabilities.backendRestart) {
      _unsupportedDirectGateway('Restart the managed backend');
    }
    final data = await post('/api/v1/backend/restart');
    return _asMap(data);
  }

  // Maintenance ops (Command Center's Maintenance tab) — doctor/security-audit
  // /backup spawn a background action polled via [actionStatus]; debug-share
  // is synchronous.
  Future<Map<String, dynamic>> runDoctor() async =>
      _asMap(await post('/api/v1/ops/doctor'));

  Future<Map<String, dynamic>> runSecurityAudit() async =>
      _asMap(await post('/api/v1/ops/security-audit'));

  Future<Map<String, dynamic>> runBackup() async =>
      _asMap(await post('/api/v1/ops/backup'));

  Future<Map<String, dynamic>> runDebugShare() async => _asMap(
    await post('/api/v1/ops/debug-share', timeout: const Duration(minutes: 2)),
  );

  Future<dynamic> getLogs({
    String file = 'agent',
    int lines = 200,
    String? level,
    String? component,
    String? search,
  }) {
    if (!capabilities.serverLogs) {
      _unsupportedDirectGateway('Read managed server logs');
    }
    return get(
      '/api/v1/logs',
      query: {
        'file': file,
        'lines': '$lines',
        'level': ?level,
        'component': ?component,
        'search': ?search,
      },
    );
  }

  // ------------------------------------------------------------------ misc
  Future<Uint8List> audioSpeak(String text) async {
    final data = await post(
      '/api/v1/audio/speak',
      body: {'text': text},
      timeout: const Duration(minutes: 2),
    );
    final dataUrl = (data as Map)['data_url'] as String?;
    if (dataUrl == null) {
      throw ApiException(0, runtimeL10n.errorTtsNoAudio);
    }
    final comma = dataUrl.indexOf(',');
    if (comma < 0) throw ApiException(0, runtimeL10n.errorInvalidDataUrl);
    return base64Decode(dataUrl.substring(comma + 1));
  }

  Future<String> audioTranscribe(String dataUrl, String mimeType) async {
    final data = await post(
      '/api/v1/audio/transcribe',
      body: {'data_url': dataUrl, 'mime_type': mimeType},
      timeout: const Duration(minutes: 2),
    );
    if (data is Map) {
      final text = data['text'] ?? data['transcript'];
      if (text != null) return text.toString();
    }
    return data?.toString() ?? '';
  }

  // -------------------------------------------------------------- sessions
  Future<List<SessionRow>> listSessions({
    int limit = 50,
    bool includeArchived = false,
  }) async {
    final page = await listSessionsPage(
      limit: limit,
      includeArchived: includeArchived,
    );
    return page.sessions;
  }

  /// Paged session listing (desktop sidebar parity: offset window + total).
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/sessions',
      query: {
        'limit': '$limit',
        'offset': '$offset',
        if (includeArchived)
          directGateway ? 'archived' : 'include_archived': directGateway
              ? 'include'
              : 'true',
        'profile': ?profile,
      },
    );
    final map = _asMap(data);
    final sessions = (map['sessions'] as List? ?? [])
        .map((e) => SessionRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    ClientPerformanceMetrics.instance.sessionRowsReceived += sessions.length;
    return SessionPage(
      sessions: sessions,
      total: (map['total'] as num?)?.toInt(),
      offset: (map['offset'] as num?)?.toInt() ?? offset,
      hasMore: map['has_more'] == true,
    );
  }

  /// Raw message maps for the transcript builder (ChatStore expects the
  /// native hermes structure, not the parsed model). Supports pagination for
  /// incremental transcript loading.
  Future<SessionMessagesPage> sessionMessagesPage(
    String id, {
    int limit = 500,
    int offset = 0,
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/sessions/${_seg(id)}/messages',
      query: {'limit': '$limit', 'offset': '$offset', 'profile': ?profile},
    );
    final map = _asMap(data);
    return SessionMessagesPage(
      messages: map['messages'] as List? ?? const [],
      total: (map['total'] as num?)?.toInt(),
    );
  }

  Future<List<dynamic>> sessionMessagesRaw(
    String id, {
    int limit = 500,
    int offset = 0,
    String? profile,
  }) async {
    final page = await sessionMessagesPage(
      id,
      limit: limit,
      offset: offset,
      profile: profile,
    );
    return page.messages;
  }

  Future<Map<String, dynamic>> sessionInfo(String id, {String? profile}) async {
    final data = await get(
      '/api/v1/sessions/${_seg(id)}',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<void> deleteSession(String id, {String? profile}) async {
    await delete('/api/v1/sessions/${_seg(id)}', query: {'profile': ?profile});
  }

  /// Batch delete multiple sessions at once.
  /// Mirrors WebUI bulk-delete sidebar action.
  Future<Map<String, dynamic>> deleteSessions(
    List<String> ids, {
    String? profile,
  }) async {
    if (ids.isEmpty) return {'deleted': <String>[], 'failed': <dynamic>[]};
    final data = await post(
      '/api/v1/sessions/batch-delete',
      query: {'profile': ?profile},
      body: {'ids': ids},
    );
    return _asMap(data);
  }

  Future<void> setSessionTitle(
    String id,
    String title, {
    String? profile,
  }) async {
    await patch(
      '/api/v1/sessions/${_seg(id)}',
      body: {'title': title},
      query: {'profile': ?profile},
    );
  }

  Future<void> setSessionArchived(
    String id,
    bool archived, {
    String? profile,
  }) async {
    await patch(
      '/api/v1/sessions/${_seg(id)}',
      body: {'archived': archived},
      query: {'profile': ?profile},
    );
  }

  /// Pin/unpin a session to the sidebar top group (WebUI parity).
  Future<void> pinSession(String id, bool pinned, {String? profile}) async {
    final path = '/api/v1/sessions/${_seg(id)}';
    if (directGateway) {
      await patch(path, body: {'pinned': pinned}, query: {'profile': ?profile});
    } else {
      await put(
        '$path/pin',
        body: {'pinned': pinned},
        query: {'profile': ?profile},
      );
    }
  }

  Future<SessionRow> branchStoredSession(
    String id, {
    int? keepCount,
    String? title,
    String? profile,
  }) async {
    final normalizedTitle = title?.trim();
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Branch sessions');
      final resumed = await request('session.resume', {
        'session_id': id,
        'cols': 48,
        'source': 'mobile',
        'omit_messages': true,
        'profile': ?profile,
      });
      final runtimeId = resumed['session_id']?.toString() ?? '';
      if (runtimeId.isEmpty) {
        throw ApiException(502, runtimeL10n.sessionRuntimeIdMissing);
      }
      final result = await request('session.branch', {
        'session_id': runtimeId,
        'count': ?keepCount,
        if (normalizedTitle?.isNotEmpty == true) 'name': normalizedTitle,
      });
      final newId =
          (result['stored_session_id'] ?? result['session_id'])?.toString() ??
          '';
      if (newId.isEmpty) {
        throw ApiException(502, runtimeL10n.errorSessionBranchIdMissing);
      }
      Map<String, dynamic> detail = const {};
      try {
        detail = await sessionInfo(newId, profile: profile);
      } catch (_) {}
      return SessionRow.fromJson({
        'id': newId,
        'session_id': newId,
        'title': result['title'],
        'parent_session_id': id,
        ...detail,
      });
    }
    final data = await post(
      '/api/v1/sessions/${_seg(id)}/branch',
      query: {'profile': ?profile},
      body: {
        'keep_count': ?keepCount,
        'title': ?(normalizedTitle?.isNotEmpty == true
            ? normalizedTitle
            : null),
      },
    );
    final raw = (data as Map)['session'] ?? data;
    return SessionRow.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<SessionRow> duplicateSession(String id, {String? profile}) async {
    if (directGateway) {
      final source = await sessionInfo(id, profile: profile);
      final messages = <dynamic>[];
      var offset = 0;
      while (true) {
        final page = await sessionMessagesPage(
          id,
          limit: 500,
          offset: offset,
          profile: profile,
        );
        messages.addAll(page.messages);
        offset += page.messages.length;
        if (page.messages.length < 500 ||
            (page.total != null && offset >= page.total!)) {
          break;
        }
      }
      final duplicateId =
          'mobile_copy_${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}';
      const resetFields = {
        'id',
        'session_id',
        'parent_id',
        'parent_session_id',
        'pinned',
        'archived',
        'share_token',
        'share_created_at',
        'created_at',
        'updated_at',
        'started_at',
        'ended_at',
        'end_reason',
        'active_stream_id',
        'is_streaming',
      };
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      final copied = <String, dynamic>{
        for (final entry in source.entries)
          if (!resetFields.contains(entry.key)) entry.key: entry.value,
        'id': duplicateId,
        'session_id': duplicateId,
        'title': runtimeL10n.sessionCopyTitle(
          (source['title'] ?? runtimeL10n.sessionUntitled).toString().trim(),
        ),
        'source': source['source'] ?? 'mobile',
        'started_at': now,
        'ended_at': now,
        'end_reason': 'duplicated',
        'pinned': false,
        'archived': false,
        'messages': messages,
      };
      final imported = _asMap(
        await post(
          '/api/v1/sessions/import',
          body: {
            'sessions': [copied],
          },
        ),
      );
      if ((imported['imported'] as num?)?.toInt() != 1) {
        throw ApiException(502, runtimeL10n.errorDuplicateImportFailed);
      }
      return SessionRow.fromJson(
        await sessionInfo(duplicateId, profile: profile),
      );
    }
    final data = await post(
      '/api/v1/sessions/${_seg(id)}/duplicate',
      query: {'profile': ?profile},
      body: const {},
    );
    final raw = (data as Map)['session'] ?? data;
    return SessionRow.fromJson((raw as Map).cast<String, dynamic>());
  }

  Future<String> regenerateSessionTitle(
    String id, {
    bool preferLatest = false,
    String? profile,
  }) async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Regenerate titles');
      final messages = <dynamic>[];
      var offset = 0;
      while (true) {
        final page = await sessionMessagesPage(
          id,
          limit: 500,
          offset: offset,
          profile: profile,
        );
        messages.addAll(page.messages);
        offset += page.messages.length;
        if (page.messages.length < 500 ||
            (page.total != null && offset >= page.total!)) {
          break;
        }
      }
      final transcript = <String>[];
      for (final raw in messages) {
        if (raw is! Map) continue;
        final role = raw['role']?.toString() ?? '';
        final content = raw['content'];
        if ((role == 'user' || role == 'assistant') &&
            content is String &&
            content.trim().isNotEmpty) {
          transcript.add('$role: ${content.trim()}');
        }
      }
      if (transcript.isEmpty) {
        throw ApiException(422, runtimeL10n.errorSessionNoTitleableMessages);
      }
      final excerpt = preferLatest && transcript.length > 12
          ? transcript.sublist(transcript.length - 12)
          : transcript.take(12).toList();
      var input = excerpt.join('\n');
      if (input.length > 12000) input = input.substring(0, 12000);
      final generated = await request('llm.oneshot', {
        'task': 'title_generation',
        'instructions':
            'Generate one concise conversation title in the same language as the conversation. Return only the title, without quotes, markdown, punctuation wrappers, or explanation. Maximum 60 characters.',
        'input': input,
        'max_tokens': 80,
        'temperature': 0.2,
      });
      var title = (generated['text'] ?? '').toString().trim();
      title = title.replaceAll(RegExp(r'''^["'`# ]+|["'`# ]+$'''), '');
      title = title.split(RegExp(r'[\r\n]+')).join(' ').trim();
      if (title.length > 80) title = title.substring(0, 80);
      if (title.isEmpty) {
        throw ApiException(502, runtimeL10n.errorTitleGeneratorEmpty);
      }
      final resumed = await request('session.resume', {
        'session_id': id,
        'cols': 48,
        'source': 'mobile',
        'omit_messages': true,
        'profile': ?profile,
      });
      final runtimeId = resumed['session_id']?.toString() ?? '';
      if (runtimeId.isEmpty) {
        throw ApiException(502, runtimeL10n.sessionRuntimeIdMissing);
      }
      await request('session.title', {'session_id': runtimeId, 'title': title});
      return title;
    }
    final data = await post(
      '/api/v1/sessions/${_seg(id)}/title/regenerate',
      query: {'profile': ?profile},
      body: {'prefer_latest': preferLatest},
    );
    final map = _asMap(data);
    return (map['title'] ?? (map['session'] as Map?)?['title'] ?? '')
        .toString();
  }

  Future<Map<String, dynamic>> createSessionShare(
    String id, {
    String? profile,
  }) async {
    if (directGateway) {
      _unsupportedDirectGateway('Public session sharing');
    }
    final data = await post(
      '/api/v1/sessions/${_seg(id)}/share',
      query: {'profile': ?profile},
      body: const {},
    );
    final result = _asMap(data);
    final share = (result['share'] as Map?)?.cast<String, dynamic>();
    if (share != null && share['url'] != null) {
      share['url'] = Uri.parse(
        baseUrl,
      ).resolve(share['url'].toString()).toString();
    }
    return result;
  }

  Future<void> revokeSessionShare(String id, {String? profile}) async {
    if (directGateway) {
      _unsupportedDirectGateway('Public session sharing');
    }
    await delete(
      '/api/v1/sessions/${_seg(id)}/share',
      query: {'profile': ?profile},
    );
  }

  String sessionShareUrl(String token) => Uri.parse(
    baseUrl,
  ).resolve('/share/${Uri.encodeComponent(token)}').toString();

  Future<void> moveSession(
    String id,
    String? projectId, {
    String? profile,
  }) async {
    if (directGateway) {
      if (projectId == null || projectId.trim().isEmpty) {
        throw ApiException(422, runtimeL10n.errorProjectIdRequired);
      }
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Move sessions');
      final tree = await projectTree();
      final project = tree.projects
          .where((item) => item.id == projectId)
          .firstOrNull;
      final cwd = project?.path?.trim().isNotEmpty == true
          ? project!.path!.trim()
          : project?.repos
                .map((repo) => repo.path?.trim() ?? '')
                .firstWhere((path) => path.isNotEmpty, orElse: () => '');
      if (cwd == null || cwd.isEmpty) {
        throw ApiException(422, runtimeL10n.errorProjectWorkingFolderMissing);
      }
      await request('session.workspace.move', {
        'session_key': id,
        'cwd': cwd,
        'profile': ?profile,
      });
      return;
    }
    await post(
      '/api/v1/sessions/${_seg(id)}/move',
      query: {'profile': ?profile},
      body: {'project_id': projectId},
    );
  }

  /// Desktop sidebar parity: authoritative project → repo → lane tree via
  /// the `projects.tree` gateway RPC (overview; lane sessions stay empty but
  /// counts are preserved, previews carry the latest N rows).
  Future<ProjectTreePayload> projectTree({int previewLimit = 3}) async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Project tree');
      final data = await request('projects.tree', {
        'preview_limit': previewLimit,
      });
      return ProjectTreePayload.fromJson(data);
    }
    final data = await get(
      '/api/v1/projects/tree',
      query: {'preview_limit': '$previewLimit'},
    );
    return ProjectTreePayload.fromJson(_asMap(data));
  }

  /// Hydrate one project's lanes with full session rows (drill-in).
  /// Mirrors the desktop `projects.project_sessions` gateway RPC.
  Future<ProjectTreeNode?> projectSessions(String projectId) async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Project sessions');
      final data = await request('projects.project_sessions', {
        'project_id': projectId,
      });
      final project = (data['project'] as Map?)?.cast<String, dynamic>();
      return project == null ? null : ProjectTreeNode.fromJson(project);
    }
    final data = await get('/api/v1/projects/${_seg(projectId)}/sessions');
    final project = ((data as Map)['project'] as Map?)?.cast<String, dynamic>();
    if (project == null) return null;
    return ProjectTreeNode.fromJson(project);
  }

  Future<Map<String, dynamic>> exportSession(
    String id, {
    String format = 'json',
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/sessions/${_seg(id)}/export',
      query: {'format': format, 'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<void> stopSessionStream(
    String id,
    String streamId, {
    String? profile,
  }) async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Stop sessions');
      final resumed = await request('session.resume', {
        'session_id': id,
        'cols': 48,
        'source': 'mobile',
        'omit_messages': true,
        'profile': ?profile,
      });
      final runtimeId = resumed['session_id']?.toString() ?? '';
      if (runtimeId.isEmpty) {
        throw ApiException(502, runtimeL10n.sessionRuntimeIdMissing);
      }
      await request('session.interrupt', {'session_id': runtimeId});
      return;
    }
    await post(
      '/api/v1/sessions/${_seg(id)}/stop',
      query: {'profile': ?profile},
      body: {'stream_id': streamId},
    );
  }

  // ── Composer draft persistence (WebUI `_saveComposerDraft` parity) ──

  /// Fetch the current persisted draft for a session.
  Future<ComposerDraft> getDraft(String sessionId, {String? profile}) async {
    final scopedId = '${profile ?? ''}\u0000$sessionId';
    if (directGateway) {
      return ComposerDraft.fromJson(await _draftStore.load(scopedId));
    }
    final data = await get(
      '/api/v1/sessions/${_seg(sessionId)}/draft',
      query: {'profile': ?profile},
    );
    final draft = (data as Map)['draft'] as Map? ?? const {};
    return ComposerDraft.fromJson(draft.cast<String, dynamic>());
  }

  /// Save (partial) composer draft. Omit `text` or `files` to keep existing.
  /// Caps: 50 KB text, 50 file entries (enforced server-side).
  Future<ComposerDraft> saveDraft(
    String sessionId, {
    String? text,
    List<dynamic>? files,
    String? profile,
  }) async {
    final scopedId = '${profile ?? ''}\u0000$sessionId';
    if (directGateway) {
      return ComposerDraft.fromJson(
        await _draftStore.save(scopedId, text: text, files: files),
      );
    }
    final body = <String, dynamic>{};
    if (text != null) body['text'] = text;
    if (files != null) body['files'] = files;
    final data = await post(
      '/api/v1/sessions/${_seg(sessionId)}/draft',
      query: {'profile': ?profile},
      body: body,
    );
    final draft = (data as Map)['draft'] as Map? ?? const {};
    return ComposerDraft.fromJson(draft.cast<String, dynamic>());
  }

  /// Server-side FTS search over durable sessions (`GET /sessions?q=`).
  Future<List<SessionRow>> searchSessions(
    String q, {
    int limit = 20,
    bool includeArchived = false,
  }) async {
    final data = await get(
      directGateway ? '/api/v1/sessions/search' : '/api/v1/sessions',
      query: {
        'q': q,
        'limit': '$limit',
        if (includeArchived)
          directGateway ? 'archived' : 'include_archived': directGateway
              ? 'include'
              : 'true',
      },
    );
    final sessions = (data as Map)['sessions'] as List? ?? [];
    return sessions
        .map((e) => SessionRow.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // --------------------------------------------------------------- models
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async {
    if (directGateway) {
      final results = await Future.wait([
        get('/api/v1/model/info'),
        get(
          '/api/v1/model/options',
          query: {'include_unconfigured': '1', if (refresh) 'refresh': '1'},
        ),
      ]);
      final info = _asMap(results[0]);
      final options = _asMap(results[1]);
      return ModelCatalog.fromJson({
        'current': info,
        'providers': options['providers'] ?? options['options'] ?? const [],
      });
    }
    final data = await get(
      '/api/v1/model',
      query: {if (refresh) 'refresh': 'true'},
    );
    return ModelCatalog.fromJson(_asMap(data));
  }

  Future<List<ModelInfo>> modelOptions() async =>
      (await modelCatalog()).providers;

  Future<Map<String, dynamic>> currentModel() async {
    final catalog = await modelCatalog();
    return {'provider': catalog.currentProvider, 'model': catalog.currentModel};
  }

  /// Returns the switch result so the UI can surface `applied: now|deferred`.
  Future<Map<String, dynamic>> setModel(String provider, String model) async {
    final data = await post(
      directGateway ? '/api/v1/model/set' : '/api/v1/model/switch',
      body: {
        if (directGateway) 'scope': 'main',
        'provider': provider,
        'model': model,
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> recommendedDefaultModel(
    String provider, {
    String? profile,
  }) async => _asMap(
    await get(
      '/api/v1/model/recommended-default',
      query: {'provider': provider, 'profile': ?profile},
    ),
  );

  Future<Map<String, dynamic>> auxiliaryModels({String? profile}) async =>
      _asMap(
        await get('/api/v1/model/auxiliary', query: {'profile': ?profile}),
      );

  Future<Map<String, dynamic>> moaModels({String? profile}) async =>
      _asMap(await get('/api/v1/model/moa', query: {'profile': ?profile}));

  Future<Map<String, dynamic>> saveMoaModels(
    Map<String, dynamic> config, {
    String? profile,
  }) async => _asMap(
    await put('/api/v1/model/moa', query: {'profile': ?profile}, body: config),
  );

  Future<Map<String, dynamic>> setModelAssignment(
    Map<String, dynamic> assignment, {
    String? profile,
  }) async => _asMap(
    await post(
      '/api/v1/model/set',
      query: {'profile': ?profile},
      body: assignment,
    ),
  );

  // -------------------------------------------------------------- profiles
  /// List profiles + active name. The server resolves upstream
  /// `/api/profiles`, the `/api/config` profiles field, or its own durable
  /// local store — in that order.
  Future<ProfilesPayload> listProfiles() async {
    final data = await get('/api/v1/profiles');
    final profiles = _asMap(data);
    if (!directGateway) return ProfilesPayload.fromJson(profiles);
    final active = _asMap(await get('/api/v1/profiles/active'));
    return ProfilesPayload.fromJson({...profiles, ...active});
  }

  /// Create (or upsert) a profile. Body keys follow the wire contract:
  /// name/model/provider/temperature/max_tokens/top_p/system_prompt/tools.
  Future<ProfileInfo> saveProfile(Map<String, dynamic> profile) async {
    final data = await post('/api/v1/profiles', body: profile);
    if (directGateway) {
      return ProfileInfo.fromJson({...profile, ..._asMap(data)});
    }
    final raw = ((data as Map)['profile'] ?? data) as Map;
    return ProfileInfo.fromJson(raw.cast<String, dynamic>());
  }

  /// Replace the profile named [name] (path name wins over body name).
  Future<ProfileInfo> updateProfile(
    String name,
    Map<String, dynamic> profile,
  ) async {
    if (directGateway) {
      var effectiveName = name;
      final requestedName = profile['name']?.toString().trim() ?? '';
      if (requestedName.isNotEmpty && requestedName != name) {
        final renamed = _asMap(
          await patch(
            '/api/v1/profiles/${Uri.encodeComponent(name)}',
            body: {'new_name': requestedName},
          ),
        );
        effectiveName = (renamed['name'] ?? requestedName).toString();
      }
      final description = profile['description']?.toString();
      if (description != null) {
        await put(
          '/api/v1/profiles/${Uri.encodeComponent(effectiveName)}/description',
          body: {'description': description},
        );
      }
      final provider = profile['provider']?.toString().trim() ?? '';
      final model = profile['model']?.toString().trim() ?? '';
      if (provider.isNotEmpty && model.isNotEmpty) {
        await put(
          '/api/v1/profiles/${Uri.encodeComponent(effectiveName)}/model',
          body: {'provider': provider, 'model': model},
        );
      }
      return ProfileInfo.fromJson({...profile, 'name': effectiveName});
    }
    final data = await put(
      '/api/v1/profiles/${Uri.encodeComponent(name)}',
      body: profile,
    );
    final raw = ((data as Map)['profile'] ?? data) as Map;
    return ProfileInfo.fromJson(raw.cast<String, dynamic>());
  }

  /// Switch the backend's active profile.
  Future<Map<String, dynamic>> activateProfile(String name) async {
    if (directGateway) {
      return _asMap(
        await post('/api/v1/profiles/active', body: {'name': name}),
      );
    }
    final data = await post(
      '/api/v1/profiles/${Uri.encodeComponent(name)}/activate',
    );
    return _asMap(data);
  }

  Future<void> deleteProfile(String name) async {
    await delete('/api/v1/profiles/${Uri.encodeComponent(name)}');
  }

  Future<({String content, bool exists})> getProfileSoul(String name) async {
    final data = _asMap(await get('/api/v1/profiles/${_seg(name)}/soul'));
    return (
      content: (data['content'] ?? '').toString(),
      exists: data['exists'] == true,
    );
  }

  Future<void> updateProfileSoul(String name, String content) async {
    await put(
      '/api/v1/profiles/${_seg(name)}/soul',
      body: {'content': content},
    );
  }

  Future<String> getProfileSetupCommand(String name) async {
    final data = _asMap(
      await get('/api/v1/profiles/${_seg(name)}/setup-command'),
    );
    return (data['command'] ?? '').toString();
  }

  Future<({Uint8List bytes, String filename})> exportProfileArchive(
    String name, {
    Map<String, String> extraFiles = const {},
  }) async {
    final cwd = await fsDefaultCwd();
    if (cwd.trim().isEmpty) {
      throw ApiException(0, runtimeL10n.errorExportDirectoryMissing);
    }
    final safeName = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final filename =
        '$safeName-${DateTime.now().millisecondsSinceEpoch}.tar.gz';
    final separator = cwd.endsWith('/') || cwd.endsWith('\\')
        ? ''
        : (cwd.contains('\\') ? '\\' : '/');
    final output = '$cwd$separator$filename';
    final result = _asMap(
      await post(
        '/api/v1/profiles/${_seg(name)}/export',
        body: {'extra_files': extraFiles, 'output': output},
        timeout: const Duration(minutes: 2),
      ),
    );
    final archive = (result['archive'] ?? output).toString();
    try {
      return await fsDownload(archive);
    } finally {
      try {
        await fsDelete(archive);
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> importProfileArchive(
    Uint8List bytes,
    String filename, {
    String? name,
  }) async {
    final cwd = await fsDefaultCwd();
    if (cwd.trim().isEmpty) {
      throw ApiException(0, runtimeL10n.errorImportDirectoryMissing);
    }
    final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final separator = cwd.endsWith('/') || cwd.endsWith('\\')
        ? ''
        : (cwd.contains('\\') ? '\\' : '/');
    final archive =
        '$cwd$separator.hermes-import-${DateTime.now().millisecondsSinceEpoch}-$safeName';
    final dataUrl = 'data:application/gzip;base64,${base64Encode(bytes)}';
    await post(
      '/api/v1/files/upload',
      body: {'path': archive, 'data_url': dataUrl, 'overwrite': false},
      timeout: const Duration(minutes: 2),
    );
    try {
      return _asMap(
        await post(
          '/api/v1/profiles/import',
          body: {'archive': archive, 'name': ?name},
          timeout: const Duration(minutes: 2),
        ),
      );
    } finally {
      try {
        await fsDelete(archive);
      } catch (_) {}
    }
  }

  // --------------------------------------------------------------- config
  /// The mobile-relevant subset of the backend config (model, personality,
  /// toolsets, reasoning, yolo, …).
  Future<Map<String, dynamic>> getConfig({String? profile}) async {
    final data = await get('/api/v1/config', query: {'profile': ?profile});
    final map = _asMap(data);
    return (map['config'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  Future<Map<String, dynamic>> getConfigSchema({String? profile}) async {
    final data = await get(
      '/api/v1/config/schema',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> getConfigDefaults({String? profile}) async {
    final data = await get(
      '/api/v1/config/defaults',
      query: {'profile': ?profile},
    );
    final map = _asMap(data);
    return (map['config'] as Map?)?.cast<String, dynamic>() ?? map;
  }

  /// Deep-merge write of config fields (e.g. `{'reasoning': {'effort': …}}`).
  Future<void> putConfig(Map<String, dynamic> config, {String? profile}) async {
    await put(
      '/api/v1/config',
      query: {'profile': ?profile},
      body: {'config': config},
    );
  }

  Future<void> replaceConfig(
    Map<String, dynamic> config, {
    String? profile,
  }) async {
    await put(
      '/api/v1/config/replace',
      query: {'profile': ?profile},
      body: directGateway
          ? {'yaml_text': jsonEncode(config)}
          : {'config': config},
    );
  }

  Future<Map<String, dynamic>> getRawConfig({String? profile}) async {
    final data = await get('/api/v1/config/raw', query: {'profile': ?profile});
    final map = _asMap(data);
    final wrapped = (map['config'] as Map?)?.cast<String, dynamic>();
    if (wrapped != null) return wrapped;
    final yamlText = map['yaml']?.toString();
    if (yamlText == null || yamlText.trim().isEmpty) return {};
    final parsed = loadYaml(yamlText);
    if (parsed is! Map) {
      throw ApiException(0, runtimeL10n.errorRawConfigInvalid);
    }
    return jsonDecode(jsonEncode(parsed)).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> providerEnvVars({String? profile}) async =>
      ((await get('/api/v1/env', query: {'profile': ?profile})) as Map)
          .cast<String, dynamic>();

  /// Desktop parity: `getElevenLabsVoices` — the account's real voice
  /// catalog for the `tts.elevenlabs.voice_id` picker. The direct Gateway
  /// path mapper converts the mobile route to Hermes' older unversioned
  /// route. Empty/`available: false` when no
  /// ElevenLabs key is configured; never throws for that case.
  Future<List<Map<String, dynamic>>> elevenLabsVoices({String? profile}) async {
    final data =
        ((await get(
                  '/api/v1/audio/elevenlabs/voices',
                  query: {'profile': ?profile},
                ))
                as Map)
            .cast<String, dynamic>();
    return (data['voices'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Future<void> setProviderEnvVar(
    String key,
    String value, {
    String? profile,
  }) async => put(
    '/api/v1/env',
    query: {'profile': ?profile},
    body: {'key': key, 'value': value},
  );
  Future<void> deleteProviderEnvVar(String key, {String? profile}) async =>
      delete('/api/v1/env', query: {'profile': ?profile}, body: {'key': key});
  Future<String?> revealProviderEnvVar(String key, {String? profile}) async {
    final data =
        ((await post(
                  '/api/v1/env/reveal',
                  query: {'profile': ?profile},
                  body: {'key': key},
                ))
                as Map)
            .cast<String, dynamic>();
    return data['value']?.toString();
  }

  Future<Map<String, dynamic>> customEndpoints({String? profile}) async =>
      ((await get(
                '/api/v1/providers/custom-endpoints',
                query: {'profile': ?profile},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> saveCustomEndpoint(
    Map<String, dynamic> value, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/providers/custom-endpoints',
                query: {'profile': ?profile},
                body: value,
              ))
              as Map)
          .cast<String, dynamic>();
  Future<void> deleteCustomEndpoint(String id, {String? profile}) async =>
      delete(
        '/api/v1/providers/custom-endpoints/${Uri.encodeComponent(id)}',
        query: {'profile': ?profile},
      );
  Future<Map<String, dynamic>> activateCustomEndpoint(
    String id, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/providers/custom-endpoints/${Uri.encodeComponent(id)}/activate',
                query: {'profile': ?profile},
                body: const {},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> validateCustomEndpoint(
    Map<String, dynamic> value, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/providers/custom-endpoints/validate',
                query: {'profile': ?profile},
                body: value,
                allowExplicitFailure: true,
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> oauthProviders({String? profile}) async =>
      ((await get('/api/v1/providers/oauth', query: {'profile': ?profile}))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> submitProviderOAuth(
    String provider,
    Map<String, dynamic> value, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/providers/oauth/${Uri.encodeComponent(provider)}/submit',
                query: {'profile': ?profile},
                body: value,
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> pollProviderOAuth(
    String provider,
    String sessionId, {
    String? profile,
  }) async =>
      ((await get(
                '/api/v1/providers/oauth/${Uri.encodeComponent(provider)}/poll/${Uri.encodeComponent(sessionId)}',
                query: {'profile': ?profile},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<void> disconnectProviderOAuth(
    String provider, {
    String? profile,
  }) async => delete(
    '/api/v1/providers/oauth/${Uri.encodeComponent(provider)}',
    query: {'profile': ?profile},
  );
  Future<void> cancelProviderOAuthSession(
    String sessionId, {
    String? profile,
  }) async => delete(
    '/api/v1/providers/oauth/sessions/${Uri.encodeComponent(sessionId)}',
    query: {'profile': ?profile},
  );
  Future<Map<String, dynamic>> startProviderOAuth(
    String provider, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/providers/oauth/${Uri.encodeComponent(provider)}/start',
                query: {'profile': ?profile},
                body: {},
              ))
              as Map)
          .cast<String, dynamic>();

  Future<Map<String, dynamic>> toolsetConfig(
    String name, {
    String? profile,
  }) async =>
      ((await get(
                '/api/v1/tools/${Uri.encodeComponent(name)}/config',
                query: {'profile': ?profile},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> toolsetModels(
    String name, {
    String? provider,
    String? profile,
  }) async =>
      ((await get(
                '/api/v1/tools/${Uri.encodeComponent(name)}/models',
                query: {'profile': ?profile, 'provider': ?provider},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> selectToolsetProvider(
    String name,
    String provider, {
    String? profile,
    String? capability,
  }) async =>
      ((await put(
                '/api/v1/tools/${Uri.encodeComponent(name)}/provider',
                query: {'profile': ?profile},
                body: {'provider': provider, 'capability': ?capability},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> selectToolsetModel(
    String name,
    String model, {
    String? profile,
    String? provider,
  }) async =>
      ((await put(
                '/api/v1/tools/${Uri.encodeComponent(name)}/model',
                query: {'profile': ?profile},
                body: {'model': model, 'provider': ?provider},
              ))
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> runToolsetPostSetup(
    String name,
    String key, {
    String? profile,
  }) async =>
      ((await post(
                '/api/v1/tools/${Uri.encodeComponent(name)}/post-setup',
                query: {'profile': ?profile},
                body: {'key': key},
              ))
              as Map)
          .cast<String, dynamic>();

  // ------------------------------------------------------------ workspace
  /// Move a session's working directory (gateway `session.workspace.move`).
  Future<void> setSessionWorkspace(
    String id,
    String cwd, {
    String? profile,
  }) async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('Change workspace');
      await request('session.workspace.move', {
        'session_key': id,
        'cwd': cwd,
        'profile': ?profile,
      });
      return;
    }
    await post(
      '/api/v1/sessions/${_seg(id)}/workspace',
      body: {'cwd': cwd},
      query: {'profile': ?profile},
    );
  }

  /// Raw project rows from the gateway `projects.list` RPC.
  Future<List<Map<String, dynamic>>> listProjects() async {
    if (directGateway) {
      final request = gatewayRequest;
      if (request == null) _unsupportedDirectGateway('List projects');
      final data = await request('projects.list', const {});
      final list = data['projects'] as List? ?? const [];
      return list
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    final data = await get('/api/v1/projects');
    final list = (data as Map)['projects'] as List? ?? [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  // ------------------------------------------------------------ skills/tools
  Future<List<SkillInfo>> skills({String? profile}) async {
    final data = await get('/api/v1/skills', query: {'profile': ?profile});
    final list = data is List ? data : ((data as Map)['skills'] as List? ?? []);
    return list
        .map((e) => SkillInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> toggleSkill(String name, bool enabled, {String? profile}) async {
    if (directGateway) {
      await put(
        '/api/v1/skills/toggle',
        body: {'name': name, 'enabled': enabled},
        query: {'profile': ?profile},
      );
      return;
    }
    await put(
      '/api/v1/skills/${_seg(name)}/enabled',
      body: {'enabled': enabled},
      query: {'profile': ?profile},
    );
  }

  Future<List<ToolsetInfo>> toolsets({String? profile}) async {
    final data = await get('/api/v1/tools', query: {'profile': ?profile});
    final list = data is List
        ? data
        : ((data as Map)['toolsets'] as List? ?? []);
    return list
        .map((e) => ToolsetInfo.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Desktop parity: `terminal-backend-panel.tsx` — the Capabilities-tab
  /// picker for the `terminal.backend` config enum (local/Docker/SSH host/
  /// Modal/Daytona sandbox), each row carrying a live readiness probe. REST
  /// only, mirroring [toolsets] — the backend never registered a gateway
  /// RPC for this.
  Future<Map<String, dynamic>> terminalBackends({String? profile}) async {
    final data = await get(
      '/api/v1/tools/terminal/backends',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<void> selectTerminalBackend(String backend, {String? profile}) async {
    await put(
      '/api/v1/tools/terminal/backend',
      body: {'backend': backend},
      query: {'profile': ?profile},
    );
  }

  Future<void> toggleToolset(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    if (directGateway) {
      await put(
        '/api/v1/tools/${_seg(name)}',
        body: {'enabled': enabled},
        query: {'profile': ?profile},
      );
      return;
    }
    await put(
      '/api/v1/tools/${_seg(name)}/enabled',
      body: {'enabled': enabled},
      query: {'profile': ?profile},
    );
  }

  Future<Map<String, dynamic>> computerUseStatus({String? profile}) async {
    final data = await get(
      '/api/v1/tools/computer-use/status',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> grantComputerUsePermissions({
    String? profile,
  }) async {
    final data = await post(
      '/api/v1/tools/computer-use/permissions/grant',
      query: {'profile': ?profile},
      body: const {},
    );
    return _asMap(data);
  }

  /// Raw SKILL.md content for a bundled/hub skill (learned skills use
  /// [knowledgeNode] instead — see [SkillInfo.isLearned]).
  Future<String> skillContent(String name) async {
    final data = await get('/api/v1/skills/content', query: {'name': name});
    if (data is Map) {
      return (data['content'] ?? data['skill_md'] ?? '').toString();
    }
    return data?.toString() ?? '';
  }

  // Matches desktop's HUB_REQUEST_TIMEOUT_MS — hub browse calls can fan out
  // to slow external sources, so they get a longer budget than the default.
  static const Duration _hubBrowseTimeout = Duration(seconds: 45);

  Future<SkillHubSources> skillHubSources() async {
    final data = await get(
      '/api/v1/skills/hub/sources',
      timeout: _hubBrowseTimeout,
    );
    return SkillHubSources.fromJson(_asMap(data));
  }

  Future<SkillHubSearchResult> searchSkillsHub(
    String query, {
    String? source,
    int? limit,
  }) async {
    final q = <String, String>{'q': query};
    if (source != null) q['source'] = source;
    if (limit != null) q['limit'] = '$limit';
    final data = await get(
      '/api/v1/skills/hub/search',
      query: q,
      timeout: _hubBrowseTimeout,
    );
    return SkillHubSearchResult.fromJson(_asMap(data));
  }

  Future<SkillHubPreview> previewSkillHub(String identifier) async {
    final data = await get(
      '/api/v1/skills/hub/preview',
      query: {'identifier': identifier},
      timeout: _hubBrowseTimeout,
    );
    return SkillHubPreview.fromJson(_asMap(data));
  }

  Future<SkillHubScanResult> scanSkillHub(String identifier) async {
    final data = await get(
      '/api/v1/skills/hub/scan',
      query: {'identifier': identifier},
      timeout: _hubBrowseTimeout,
    );
    return SkillHubScanResult.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> installSkillFromHub(String identifier) async {
    final data = await post(
      '/api/v1/skills/hub/install',
      body: {'identifier': identifier},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> uninstallSkillFromHub(String name) async {
    final data = await post(
      '/api/v1/skills/hub/uninstall',
      body: {'name': name},
    );
    return _asMap(data);
  }

  /// Updates ALL installed hub skills — the backend has no per-skill target
  /// for this endpoint (matches desktop's `updateSkillsFromHub`).
  Future<Map<String, dynamic>> updateSkillsFromHub() async {
    final data = await post('/api/v1/skills/hub/update', body: const {});
    return _asMap(data);
  }

  // -------------------------------------------------------- saved prompts
  /// Saved prompt snippets (WebUI `/api/prompts` parity; the server shares
  /// the desktop WebUI's on-disk store).
  Future<List<SavedPrompt>> savedPrompts() async {
    final data = await get('/api/v1/prompts');
    final list = (data as Map)['prompts'] as List? ?? [];
    return list
        .map((e) => SavedPrompt.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<SavedPrompt> savePrompt(String text, {String? label}) async {
    final data = await post(
      '/api/v1/prompts',
      body: {
        'text': text,
        if (label != null && label.isNotEmpty) 'label': label,
      },
    );
    final raw = ((data as Map)['prompt'] ?? data) as Map;
    return SavedPrompt.fromJson(raw.cast<String, dynamic>());
  }

  Future<void> deletePrompt(String id) async {
    await delete('/api/v1/prompts/${Uri.encodeComponent(id)}');
  }

  /// Ambient provider quota/usage status (WebUI `/api/provider/quota`
  /// parity). Throws [ApiException] when the backend has no such route —
  /// callers treat that as "no quota chip".
  Future<Map<String, dynamic>> providerQuota({
    String? provider,
    bool refresh = false,
  }) async {
    final data = await get(
      '/api/v1/provider/quota',
      query: {
        if (provider != null && provider.isNotEmpty) 'provider': provider,
        if (refresh) 'refresh': 'true',
      },
    );
    return _asMap(data);
  }

  // ----------------------------------------------------------------- cron
  Future<List<CronJob>> cronJobs() async {
    final data = await get('/api/v1/cron');
    final list = data is List ? data : ((data as Map)['jobs'] as List? ?? []);
    return list
        .map((e) => CronJob.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> setCronEnabled(String id, bool enabled) async {
    await post('/api/v1/cron/${_seg(id)}/${enabled ? 'resume' : 'pause'}');
  }

  Future<void> cronTrigger(String id) async {
    await post('/api/v1/cron/${_seg(id)}/trigger');
  }

  /// Create a scheduled job (CronJobCreate fields: prompt/schedule/name/
  /// deliver/workdir/model/…).
  Future<Map<String, dynamic>> cronCreate(Map<String, dynamic> job) async {
    final data = await post('/api/v1/cron', body: job);
    return _asMap(data);
  }

  /// Partial update of a scheduled job (body is a field map).
  Future<Map<String, dynamic>> cronUpdate(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final data = await put(
      '/api/v1/cron/${_seg(id)}',
      body: directGateway ? {'updates': updates} : updates,
    );
    return _asMap(data);
  }

  Future<void> cronDelete(String id) async {
    await delete('/api/v1/cron/${_seg(id)}');
  }

  Future<List<Map<String, dynamic>>> cronRuns(
    String id, {
    int limit = 20,
  }) async {
    final data = await get(
      '/api/v1/cron/${_seg(id)}/runs',
      query: {'limit': '$limit'},
    );
    final runs = (data as Map)['runs'] as List? ?? [];
    return runs.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<CronDeliveryTarget>> cronDeliveryTargets() async {
    final data = await get('/api/v1/cron/delivery-targets');
    final targets = (data as Map)['targets'] as List? ?? [];
    return targets
        .map(
          (e) =>
              CronDeliveryTarget.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<List<CronBlueprint>> cronBlueprints() async {
    final data = await get('/api/v1/cron/blueprints');
    final items = (data as Map)['blueprints'] as List? ?? [];
    return items
        .map((e) => CronBlueprint.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> instantiateCronBlueprint(
    Map<String, dynamic> payload,
  ) async {
    final data = await post(
      '/api/v1/cron/blueprints/instantiate',
      body: payload,
    );
    return _asMap(data);
  }

  // ---------------------------------------------------------------- memory
  Future<Map<String, dynamic>> memoryStatus({String? profile}) async {
    final data = await get('/api/v1/memory', query: {'profile': ?profile});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> memorySetProvider(
    String provider, {
    String? profile,
  }) async {
    final data = await put(
      '/api/v1/memory/provider',
      body: {'provider': provider},
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> memoryReset({
    String target = 'all',
    String? profile,
  }) async {
    final data = await post(
      '/api/v1/memory/reset',
      body: {'target': target},
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> memoryProviderConfig(
    String provider, {
    String? profile,
  }) async => _asMap(
    await get(
      '/api/v1/memory/providers/${_seg(provider)}/config',
      query: {'profile': ?profile},
    ),
  );

  Future<Map<String, dynamic>> saveMemoryProviderConfig(
    String provider,
    Map<String, String> values, {
    String? profile,
  }) async => _asMap(
    await put(
      '/api/v1/memory/providers/${_seg(provider)}/config',
      body: {'values': values},
      query: {'profile': ?profile},
    ),
  );

  Future<Map<String, dynamic>> startMemoryProviderOAuth(
    String provider, {
    String? profile,
  }) async => _asMap(
    await post(
      '/api/v1/memory/providers/${_seg(provider)}/oauth/start',
      query: {'profile': ?profile},
    ),
  );

  Future<Map<String, dynamic>> memoryProviderOAuthStatus(
    String provider, {
    String? profile,
  }) async => _asMap(
    await get(
      '/api/v1/memory/providers/${_seg(provider)}/oauth/status',
      query: {'profile': ?profile},
    ),
  );

  Future<Map<String, dynamic>> curatorStatus() async =>
      _asMap(await get('/api/v1/curator'));

  Future<Map<String, dynamic>> setCuratorPaused(bool paused) async =>
      _asMap(await put('/api/v1/curator/paused', body: {'paused': paused}));

  Future<Map<String, dynamic>> runCurator() async =>
      _asMap(await post('/api/v1/curator/run'));

  // ------------------------------------------------------------- knowledge
  // Named `knowledge*` for historical reasons but calls `/api/v1/starmap/*`
  // — the mobile server's OWN naming treats `/knowledge/*` as a deprecated
  // alias of `/starmap/*` (see domain_api.py's `knowledge_graph`/etc.
  // docstrings), and no client here ever calls `/knowledge/*`. This is the
  // canonical implementation; the `starmap*` methods below delegate to it
  // rather than re-issuing the request, so there is one call site for what
  // used to be two independently-maintained copies of the same call.
  Future<Map<String, dynamic>> knowledgeGraph() async {
    final data = await get('/api/v1/starmap/graph');
    return _asMap(data);
  }

  Future<Map<String, dynamic>> knowledgeNode(String id) async {
    final data = await get('/api/v1/starmap/node', query: {'id': id});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> knowledgeNodeUpdate(
    String id,
    String content,
  ) async {
    final data = await put(
      '/api/v1/starmap/node',
      body: {'id': id, 'content': content},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> knowledgeNodeDelete(String id) async {
    final data = await delete('/api/v1/starmap/node', query: {'id': id});
    return (data as Map?)?.cast<String, dynamic>() ?? {};
  }

  // ------------------------------------------------------------------- mcp
  Future<List<Map<String, dynamic>>> mcpServers({String? profile}) async {
    final data = await get('/api/v1/mcp/servers', query: {'profile': ?profile});
    final list = data is List
        ? data
        : ((data as Map)['servers'] as List? ?? []);
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> mcpSetEnabled(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    await put(
      '/api/v1/mcp/servers/${_seg(name)}/enabled',
      body: {'enabled': enabled},
      query: {'profile': ?profile},
    );
  }

  Future<Map<String, dynamic>> mcpCreate(
    Map<String, dynamic> server, {
    String? profile,
  }) async {
    final data = await post(
      '/api/v1/mcp/servers',
      body: server,
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<void> mcpReplaceServers(
    Map<String, Map<String, dynamic>> servers, {
    String? profile,
  }) async {
    await put(
      '/api/v1/mcp/servers',
      body: {'servers': servers},
      query: {'profile': ?profile},
    );
  }

  Future<void> mcpDelete(String name, {String? profile}) async {
    await delete(
      '/api/v1/mcp/servers/${_seg(name)}',
      query: {'profile': ?profile},
    );
  }

  Future<Map<String, dynamic>> mcpTest(String name, {String? profile}) async {
    final path = '/api/v1/mcp/servers/${_seg(name)}/test';
    final data = directGateway
        ? await post(path, query: {'profile': ?profile})
        : await get(path, query: {'profile': ?profile});
    return _asMap(data);
  }

  Future<Map<String, dynamic>> mcpStartAuth(
    String name, {
    String? profile,
  }) async {
    final data = await post(
      '/api/v1/mcp/servers/${_seg(name)}/auth',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> mcpAuthFlow(
    String flowId, {
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/mcp/oauth/flows/${_seg(flowId)}',
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  Future<void> mcpCancelAuthFlow(String flowId, {String? profile}) async {
    await delete(
      '/api/v1/mcp/oauth/flows/${_seg(flowId)}',
      query: {'profile': ?profile},
    );
  }

  Future<List<Map<String, dynamic>>> mcpCatalog({String? profile}) async {
    final data = await get('/api/v1/mcp/catalog', query: {'profile': ?profile});
    final list = (data as Map)['entries'] as List? ?? [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> mcpInstallCatalog(
    String name, {
    Map<String, String> env = const {},
    String? profile,
  }) async {
    final data = await post(
      '/api/v1/mcp/catalog/install',
      body: {'name': name, 'env': env, 'enable': true},
      query: {'profile': ?profile},
    );
    return _asMap(data);
  }

  /// Raw `/api/analytics/usage` payload (totals, by_model, daily, tools, …).
  Future<Map<String, dynamic>> analyticsUsage({
    int days = 30,
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/analytics/usage',
      query: {'days': '$days', 'profile': ?profile},
    );
    return _asMap(data);
  }

  /// Typed wrapper for the Command Center's Usage tab (daily chart, top
  /// models, top skills, period totals).
  Future<AnalyticsUsage> analyticsUsageTyped({int days = 30}) async =>
      AnalyticsUsage.fromJson(await analyticsUsage(days: days));

  /// Per-tool 30-day call counts (`analyticsUsage`'s `tools` list flattened to
  /// a `{registry_name: count}` map) — feeds the MCP cost/usage overlay.
  Future<Map<String, int>> toolCallCounts30d({String? profile}) async {
    final data = await analyticsUsage(days: 30, profile: profile);
    final tools = (data['tools'] as List?) ?? const [];
    return {
      for (final entry in tools)
        if (entry is Map && entry['tool'] != null)
          entry['tool'].toString(): (entry['count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<Map<String, dynamic>> actionStatus(
    String name, {
    int lines = 200,
    String? profile,
  }) async {
    final data = await get(
      '/api/v1/actions/${_seg(name)}/status',
      query: {'lines': '$lines', 'profile': ?profile},
    );
    return _asMap(data);
  }

  // --------------------------------------------------------------- plugins
  Future<List<Map<String, dynamic>>> plugins({String? profile}) async {
    final data = await get('/api/v1/plugins', query: {'profile': ?profile});
    final list = (data as Map)['plugins'] as List? ?? [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> setPluginEnabled(
    String name,
    bool enabled, {
    String? profile,
  }) async {
    await put(
      '/api/v1/plugins/${_seg(name)}/enabled',
      body: {'enabled': enabled},
      query: {'profile': ?profile},
    );
  }

  Future<Map<String, dynamic>> installPlugin(
    String identifier, {
    bool force = false,
    bool enable = true,
    String? profile,
  }) async {
    return _asMap(
      await post(
        '/api/v1/plugins/install',
        body: {'identifier': identifier, 'force': force, 'enable': enable},
        query: {'profile': ?profile},
        timeout: const Duration(minutes: 5),
      ),
    );
  }

  // ------------------------------------------------------------------- fs
  Future<List<FsEntry>> fsList(String path) async {
    final data = await get('/api/v1/files', query: {'path': path});
    final entries = (data as Map)['entries'] as List? ?? [];
    return entries
        .map((e) => FsEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async {
    final data = await get(
      directGateway ? '/api/v1/files' : '/api/v1/files/entries',
      query: {
        'path': path,
        if (!directGateway && root != null && root.isNotEmpty) 'root': root,
      },
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> fsDrives() async {
    if (directGateway) {
      final data = _asMap(await get('/api/v1/files'));
      final root = (data['root'] ?? data['path'])?.toString();
      if (root == null || root.isEmpty) return const [];
      return [
        {'name': root, 'label': root, 'path': root, 'root': root},
      ];
    }
    final data = await get('/api/v1/files/drives');
    final drives = (data as Map)['drives'] as List? ?? const [];
    return drives.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Reads a file as text. Throws [BinaryFileException] if the file's bytes
  /// don't look like text — callers must not silently edit/save in that case,
  /// since doing so would corrupt the original file on write-back.
  Future<String> fsReadText(String path) async {
    final data = await get('/api/v1/files/read', query: {'path': path});
    final map = _asMap(data);
    final text = map['text'];
    if (text != null) return text.toString();
    final dataUrl = map['data_url']?.toString() ?? '';
    final comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.substring(0, comma).contains(';base64')) {
      return '';
    }
    final bytes = base64Decode(dataUrl.substring(comma + 1));
    if (looksLikeBinary(bytes)) {
      throw BinaryFileException(path);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// Overwrite (or create) a UTF-8 text file on the server (spot editor).
  Future<Map<String, dynamic>> fsWriteText(String path, String content) async {
    if (directGateway) {
      final dataUrl =
          'data:text/plain;charset=utf-8;base64,${base64Encode(utf8.encode(content))}';
      return _asMap(
        await post(
          '/api/v1/files/upload',
          body: {'path': path, 'data_url': dataUrl, 'overwrite': true},
        ),
      );
    }
    final data = await post(
      '/api/v1/files/write',
      body: {'path': path, 'content': content},
    );
    return _asMap(data);
  }

  Future<String> fsDefaultCwd() async {
    if (directGateway) {
      final data = _asMap(await get('/api/v1/files'));
      return (data['root'] ?? data['path'] ?? '').toString();
    }
    final data = await get('/api/v1/files/default-cwd');
    return (data as Map)['cwd']?.toString() ?? '';
  }

  /// Read a file as a base64 data URL (artifact images).
  Future<String> fsReadDataUrl(String path) async {
    final data = await get(
      directGateway ? '/api/v1/files/read' : '/api/v1/files/read-data-url',
      query: {'path': path},
    );
    return (data as Map)['data_url']?.toString() ?? '';
  }

  /// Download a server workspace file or zipped directory.
  /// Returns raw bytes plus the server-suggested filename (e.g. `folder.zip`).
  Future<({Uint8List bytes, String filename})> fsDownload(String path) async {
    final resp = await _bounded(
      _client.get(
        _uri('/api/v1/files/download', {'path': path}),
        headers: await _headers(),
      ),
      timeout: const Duration(minutes: 2),
    );
    if (resp.statusCode >= 400) {
      _decode(resp);
      throw ApiException(resp.statusCode, runtimeL10n.errorDownloadFailed);
    }
    final suggested =
        filenameFromContentDisposition(resp.headers['content-disposition']) ??
        path.split(RegExp(r'[\\/]')).last;
    return (bytes: resp.bodyBytes, filename: suggested);
  }

  /// Parse a Content-Disposition header for the download filename.
  static String? filenameFromContentDisposition(String? header) {
    if (header == null || header.isEmpty) return null;
    // filename*=UTF-8''name.zip  or  filename="name.zip"
    final star = RegExp(
      r"filename\*\s*=\s*UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(header);
    if (star != null) {
      return Uri.decodeComponent(star.group(1)!.trim());
    }
    final plain = RegExp(
      r'filename\s*=\s*"?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(header);
    return plain?.group(1)?.trim();
  }

  /// Upload a file to the server working directory (attachment flow, D6).
  /// `path` is the server-side target path; `dataUrl` is base64-encoded data.
  Future<Map<String, dynamic>> uploadFile(String path, String dataUrl) async {
    final body = {'path': path, 'data_url': dataUrl, 'overwrite': false};
    const timeout = Duration(minutes: 2);
    // Retries only a transport-level failure, same policy (and reasoning)
    // as `postMultipart` — `overwrite: false` also means a retry that
    // lands after an actually-successful-but-unacknowledged first attempt
    // surfaces as a clear "already exists" error rather than silently
    // duplicating anything.
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 0; attempt <= readRetryAttempts; attempt++) {
      try {
        final data = await post(
          '/api/v1/files/upload',
          body: body,
          timeout: timeout,
        );
        return _asMap(data);
      } on TimeoutException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      } on http.ClientException catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
      }
      if (attempt < readRetryAttempts) {
        await _retryDelay(_readRetryDelay(attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  // ------------------------------------------------------------------ git
  Future<Map<String, dynamic>> gitStatus(String path) async {
    final data = await get('/api/v1/git/status', query: {'path': path});
    if (data == null) return <String, dynamic>{};
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> gitBranches(String path) async {
    final data = await get('/api/v1/git/branches', query: {'path': path});
    if (data == null) return [];
    final branches = (data as Map)['branches'] as List? ?? [];
    return branches.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> gitWorktrees(String path) async {
    final data = await get('/api/v1/git/worktrees', query: {'path': path});
    final list = (data as Map?)?['worktrees'] as List? ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> gitBaseBranches(String path) async {
    final data = await get('/api/v1/git/base-branches', query: {'path': path});
    final list = (data as Map?)?['branches'] as List? ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> gitWorktreeAdd(
    String path, {
    String? name,
    String? branch,
    String? base,
    String? existingBranch,
  }) async {
    final data = await post(
      '/api/v1/git/worktree/add',
      body: {
        'path': path,
        if (name != null && name.isNotEmpty) 'name': name,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
        if (base != null && base.isNotEmpty) 'base': base,
        if (existingBranch != null && existingBranch.isNotEmpty)
          'existingBranch': existingBranch,
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> gitWorktreeRemove(
    String path,
    String worktreePath, {
    bool force = false,
  }) async {
    final data = await post(
      '/api/v1/git/worktree/remove',
      body: {'path': path, 'worktreePath': worktreePath, 'force': force},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> gitLog(
    String path, {
    int limit = 50,
    int offset = 0,
    String? search,
    String? author,
    String? branch,
  }) async {
    final query = <String, String>{
      'path': path,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (author != null && author.isNotEmpty) query['author'] = author;
    if (branch != null && branch.isNotEmpty) query['branch'] = branch;
    final data = await get('/api/v1/git/log', query: query);
    if (data == null) return <String, dynamic>{'commits': const [], 'total': 0};
    return _asMap(data);
  }

  Future<Map<String, dynamic>> gitLogCommit(String path, String sha) async {
    final data = await get(
      '/api/v1/git/log/commit',
      query: {'path': path, 'sha': sha},
    );
    if (data == null) return <String, dynamic>{};
    return _asMap(data);
  }

  Future<Map<String, dynamic>> gitDiff(
    String path,
    String file, {
    String mode = 'worktree',
    String? oid,
  }) async {
    final data = await get(
      '/api/v1/git/diff',
      query: {'path': path, 'file': file, 'mode': mode, 'oid': ?oid},
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> gitRemotes(String path) async {
    final data = await get('/api/v1/git/remotes', query: {'path': path});
    final list = (data as Map)['remotes'] as List? ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> gitStashes(String path) async {
    final data = await get('/api/v1/git/stashes', query: {'path': path});
    final list = (data as Map)['stashes'] as List? ?? const [];
    return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  /// Changed files for the working tree (scope: uncommitted/branch/lastTurn).
  Future<List<Map<String, dynamic>>> gitReviewList(
    String path, {
    String scope = 'uncommitted',
    String? base,
  }) async {
    final data = await get(
      '/api/v1/git/review/list',
      query: {'path': path, 'scope': scope, 'base': ?base},
    );
    if (data == null) return [];
    final files = (data as Map)['files'] as List? ?? [];
    return files.map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<String> gitFileDiff(String path, String file) async {
    final data = await get(
      '/api/v1/git/file-diff',
      query: {'path': path, 'file': file},
    );
    if (data == null) return '';
    return (data as Map)['diff']?.toString() ?? '';
  }

  Future<String> gitReviewDiff(
    String path,
    String file, {
    String scope = 'uncommitted',
    String? base,
    bool staged = false,
  }) async {
    final data = await get(
      '/api/v1/git/review/diff',
      query: {
        'path': path,
        'file': file,
        'scope': scope,
        'base': ?base,
        'staged': '$staged',
      },
    );
    return (data as Map?)?['diff']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> gitCommitContext(String path) async {
    final data = await get(
      '/api/v1/git/review/commit-context',
      query: {'path': path},
    );
    return _asMap(data);
  }

  Future<String?> gitRevParse(String path, {String? ref}) async {
    final data = await get(
      '/api/v1/git/review/rev-parse',
      query: {'path': path, 'ref': ?ref},
    );
    final sha = (data as Map?)?['sha']?.toString().trim() ?? '';
    return sha.isEmpty ? null : sha;
  }

  Future<Map<String, dynamic>> gitShipInfo(String path) async {
    final data = await get(
      '/api/v1/git/review/ship-info',
      query: {'path': path},
    );
    return _asMap(data);
  }

  Future<List<Map<String, dynamic>>> gitPullRequests(
    String path, {
    List<String> branches = const [],
    List<int> numbers = const [],
  }) async {
    final data = await post(
      '/api/v1/git/review/pr-list',
      body: {'path': path, 'branches': branches, 'numbers': numbers},
    );
    final rows = (_asMap(data)['prs'] as List?) ?? const [];
    return rows
        .whereType<Map>()
        .map((row) => row.cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Recover PR numbers that were printed by `gh pr create` in stored
  /// transcripts. The backend persists which sessions were scanned so a
  /// transcript without a PR is not downloaded repeatedly.
  Future<Map<String, dynamic>> scanSessionPullRequests(
    List<String> sessionIds,
  ) async {
    if (sessionIds.isEmpty) {
      return const {
        'pull_requests': <String, dynamic>{},
        'scanned': <String>[],
      };
    }
    final data = await post(
      '/api/v1/profiles/sessions/pull-requests',
      body: {'ids': sessionIds},
    );
    return _asMap(data);
  }

  Future<void> gitStage(String path, String file) async {
    await post('/api/v1/git/review/stage', body: {'path': path, 'file': file});
  }

  Future<void> gitUnstage(String path, String file) async {
    await post(
      '/api/v1/git/review/unstage',
      body: {'path': path, 'file': file},
    );
  }

  Future<Map<String, dynamic>> gitCommit(
    String path,
    String message, {
    bool push = false,
  }) async {
    final data = await post(
      '/api/v1/git/review/commit',
      body: {'path': path, 'message': message, 'push': push},
    );
    if (data == null) return <String, dynamic>{};
    return _asMap(data);
  }

  Future<Map<String, dynamic>> gitPush(String path) async {
    final data = await post('/api/v1/git/review/push', body: {'path': path});
    return data == null ? <String, dynamic>{} : _asMap(data);
  }

  /// Revert one file to HEAD (discard working-tree changes), or every
  /// changed file when [file] is null — the backend's `review_revert`
  /// treats a missing `file` as `git checkout HEAD -- . && git clean -fd .`.
  Future<void> gitRevert(String path, String? file) async {
    await post(
      '/api/v1/git/review/revert',
      body: {'path': path, 'file': ?file},
    );
  }

  Future<Map<String, dynamic>> gitBranchSwitch(
    String path,
    String branch,
  ) async {
    final data = await post(
      '/api/v1/git/branch/switch',
      body: {'path': path, 'branch': branch},
    );
    return _asMap(data);
  }

  // ----------------------------------------------------------------- tasks
  Future<List<TaskItem>> taskList({String? status}) async {
    if (directGateway) {
      final data = _asMap(
        await get(
          '/api/v1/kanban/board',
          query: const {'include_archived': 'true'},
        ),
      );
      final tasks = <TaskItem>[];
      for (final rawColumn in data['columns'] as List? ?? const []) {
        if (rawColumn is! Map) continue;
        for (final rawTask in rawColumn['tasks'] as List? ?? const []) {
          if (rawTask is! Map) continue;
          final task = TaskItem.fromJson(
            _directTaskJson(rawTask.cast<String, dynamic>()),
          );
          if (status == null || task.status == status) tasks.add(task);
        }
      }
      return tasks;
    }
    final data = await get('/api/v1/tasks', query: {'status': ?status});
    final tasks = (data as Map)['tasks'] as List? ?? [];
    return tasks
        .map((e) => TaskItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<TaskItem> taskCreate({
    required String title,
    String prompt = '',
    String priority = 'normal',
  }) async {
    if (directGateway) {
      final data = _asMap(
        await post(
          '/api/v1/kanban/tasks',
          body: {
            'title': title,
            'body': prompt,
            'priority': _directTaskPriority(priority),
            'triage': true,
          },
        ),
      );
      return TaskItem.fromJson(_directTaskJson(_asMap(data['task'])));
    }
    final data = await post(
      '/api/v1/tasks',
      body: {'title': title, 'prompt': prompt, 'priority': priority},
    );
    return TaskItem.fromJson(_asMap(data));
  }

  Future<TaskItem> taskGet(String id) async {
    final data = await get(
      directGateway
          ? '/api/v1/kanban/tasks/${_seg(id)}'
          : '/api/v1/tasks/${_seg(id)}',
    );
    if (directGateway) {
      final map = _asMap(data);
      return TaskItem.fromJson(_directTaskJson(_asMap(map['task'])));
    }
    return TaskItem.fromJson(_asMap(data));
  }

  Future<TaskItem> taskUpdate(
    String id, {
    String? title,
    String? prompt,
    String? priority,
    String? status,
    String? profile,
  }) async {
    if (directGateway) {
      final data = await patch(
        '/api/v1/kanban/tasks/${_seg(id)}',
        body: {
          'title': ?title,
          'body': ?prompt,
          if (priority != null) 'priority': _directTaskPriority(priority),
          'status': ?status,
        },
      );
      final map = _asMap(data);
      return TaskItem.fromJson(_directTaskJson(_asMap(map['task'])));
    }
    final data = await patch(
      '/api/v1/tasks/${_seg(id)}',
      body: {
        'title': ?title,
        'prompt': ?prompt,
        'priority': ?priority,
        'status': ?status,
      },
      query: {'profile': ?profile},
    );
    return TaskItem.fromJson(_asMap(data));
  }

  Future<void> taskDelete(String id) async {
    final data = await delete(
      directGateway
          ? '/api/v1/kanban/tasks/${_seg(id)}'
          : '/api/v1/tasks/${_seg(id)}',
    );
    final result = data is Map ? data : const {};
    if (result['ok'] == false || (directGateway && result['deleted'] != true)) {
      throw ApiException(200, runtimeL10n.commonOperationFailed);
    }
  }

  /// Execute a Task (ADR 0003): the kanban dispatcher owns execution and
  /// returns `{task, dispatch}` (no session id).
  Future<Map<String, dynamic>> taskRun(String id) async {
    if (directGateway) {
      var task = await taskGet(id);
      if (task.status == 'running') {
        throw ApiException(409, runtimeL10n.kanbanTaskAlreadyRunning);
      }
      if (task.status != 'ready') {
        task = await taskUpdate(id, status: 'ready');
      }
      final dispatch = _asMap(
        await post('/api/v1/kanban/dispatch', body: const {}),
      );
      return {'task': task, 'dispatch': dispatch};
    }
    final data = await post('/api/v1/tasks/${_seg(id)}/run');
    return _asMap(data);
  }

  static int _directTaskPriority(String value) => switch (value) {
    'low' => -1,
    'high' => 1,
    'urgent' => 2,
    _ => int.tryParse(value) ?? 0,
  };

  static Map<String, dynamic> _directTaskJson(Map<String, dynamic> task) {
    String? timestamp(Object? value) {
      if (value == null) return null;
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(
          value.toInt() * 1000,
          isUtc: true,
        ).toIso8601String();
      }
      return value.toString();
    }

    final priority = _directTaskPriority('${task['priority'] ?? 0}');
    return {
      'id': '${task['id'] ?? ''}',
      'title': '${task['title'] ?? ''}',
      'prompt': '${task['body'] ?? ''}',
      'priority': priority >= 2
          ? 'urgent'
          : priority == 1
          ? 'high'
          : priority < 0
          ? 'low'
          : 'normal',
      'status': '${task['status'] ?? 'triage'}',
      'session_id': task['session_id'],
      'created_at': timestamp(task['created_at']),
      'updated_at':
          timestamp(task['started_at']) ??
          timestamp(task['completed_at']) ??
          timestamp(task['created_at']),
      'completed_at': timestamp(task['completed_at']),
    };
  }

  // ----------------------------------------------------- files (extended)
  Future<Map<String, dynamic>> fsMove(
    String path,
    String dest, {
    bool overwrite = false,
  }) async {
    if (!capabilities.fileMove) _unsupportedDirectGateway('Move files');
    final data = await post(
      '/api/v1/files/move',
      body: {'path': path, 'dest': dest, 'overwrite': overwrite},
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> fsCopy(
    List<String> sources,
    String destination, {
    bool overwrite = false,
  }) async {
    if (!capabilities.fileCopy) _unsupportedDirectGateway('Copy files');
    final data = await post(
      '/api/v1/files/copy',
      body: {
        'sources': sources,
        'dest_path': destination,
        'overwrite': overwrite,
      },
    );
    return _asMap(data);
  }

  Future<Map<String, dynamic>> fsMkdir(String path) async {
    final data = await post('/api/v1/files/mkdir', body: {'path': path});
    return _asMap(data);
  }

  Future<void> fsReveal(String path) async {
    if (!capabilities.fileReveal) {
      _unsupportedDirectGateway('Reveal files on host');
    }
    await post('/api/v1/files/reveal', body: {'path': path});
  }

  Future<void> fsDelete(String path, {bool recursive = false}) async {
    if (directGateway) {
      await delete(
        '/api/v1/files',
        body: {'path': path, 'recursive': recursive},
      );
      return;
    }
    await post(
      '/api/v1/files/delete',
      body: {'path': path, 'recursive': recursive},
    );
  }

  // ------------------------------------------------------------ artifacts
  Future<List<ArtifactItem>> artifacts({
    String? sessionId,
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};
    if (sessionId != null) query['session_id'] = sessionId;
    final data = await get('/api/v1/artifacts', query: query);
    final list = (data as Map)['artifacts'] as List? ?? [];
    return list
        .map((e) => ArtifactItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  // -------------------------------------------------------------- starmap
  // `starmap_screen.dart`'s radial graph view and `knowledge_screen.dart`'s
  // flat list view are two presentations of the SAME backend data — both hit
  // `/api/v1/starmap/{graph,node}` (confirmed: not "two endpoint families",
  // the literal same paths). These delegate to the `knowledge*` methods below
  // rather than re-issuing the request, so there is exactly one place that
  // calls the wire — a future path/shape change can't update one and miss
  // the other the way `knowledgeGraph`/`starmapGraph` previously could.
  Future<StarmapGraph> starmapGraph() async =>
      StarmapGraph.fromJson(await knowledgeGraph());

  Future<Map<String, dynamic>> starmapNode(String id) => knowledgeNode(id);

  // ----------------------------------------------------------- subagents
  Future<SubagentProjection> subagentProjection() async {
    developer.log('request projection', name: 'hermes.subagent.api');
    final data = await get('/api/v1/subagents/projection');
    final projection = SubagentProjection.fromJson(_asMap(data));
    developer.log(
      'response projection sessions=${projection.sessions.length} '
      'groups=${projection.bySession.length} total=${projection.total}',
      name: 'hermes.subagent.api',
    );
    return projection;
  }

  Future<List<SubagentNode>> subagents(String sessionId) async {
    final data = await get(
      '/api/v1/subagents',
      query: {'session_id': sessionId},
    );
    final entries =
        (data as Map)['subagents'] as List? ??
        (data['entries'] as List?) ??
        (data['processes'] as List?) ??
        [];
    return entries
        .map((e) => SubagentNode.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<Map<String, List<SubagentNode>>> subagentsForSessions(
    Iterable<String> sessionIds,
  ) async {
    final ids = sessionIds.toList();
    developer.log(
      'request batch parents=${ids.length} ids=$ids',
      name: 'hermes.subagent.api',
    );
    final data = await post(
      '/api/v1/subagents/query',
      body: {'session_ids': ids},
    );
    final grouped = ((data as Map)['by_session'] as Map?) ?? const {};
    developer.log(
      'response batch groups=${grouped.length} rawCounts=${{for (final entry in grouped.entries) entry.key.toString(): (entry.value as List?)?.length ?? 0}}',
      name: 'hermes.subagent.api',
    );
    final parsed = grouped.map((key, value) {
      final nodes = (value as List? ?? const [])
          .map((e) => SubagentNode.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      return MapEntry(key.toString(), nodes);
    });
    developer.log(
      'parsed batch counts=${{for (final entry in parsed.entries) entry.key: entry.value.length}}',
      name: 'hermes.subagent.api',
    );
    return parsed;
  }

  Future<List<ActiveProcess>> activeProcesses() async {
    final data = await get('/api/v1/subagents/active');
    final list =
        (data as Map)['processes'] as List? ?? (data['agents'] as List?) ?? [];
    return list
        .map((e) => ActiveProcess.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> interruptSubagent(String id, {String? profile}) async {
    await post(
      '/api/v1/subagents/${_seg(id)}/interrupt',
      query: {if (profile != null && profile.isNotEmpty) 'profile': profile},
    );
  }

  // ----------------------------------------------------------------- pet
  Future<PetInfo> petInfo() async {
    final data = directGateway
        ? await _directRpc('pet.info', const {}, 'Pet information')
        : await get('/api/v1/pet');
    return PetInfo.fromJson(_asMap(data));
  }

  Future<List<PetGalleryEntry>> petGallery() async {
    final data = directGateway
        ? await _directRpc('pet.gallery', const {}, 'Pet gallery')
        : await get('/api/v1/pet/gallery');
    final list =
        (data as Map)['entries'] as List? ??
        (data['gallery'] as List?) ??
        (data['pets'] as List?) ??
        [];
    return list
        .map(
          (e) => PetGalleryEntry.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> petSelect(String slug) async {
    final result = directGateway
        ? await _directRpc('pet.select', {'slug': slug}, 'Select pet')
        : _asMap(await post('/api/v1/pet/select', body: {'slug': slug}));
    _requireOk(result, 'Select pet');
  }

  Future<Map<String, dynamic>> petHatch(Map<String, dynamic> args) async {
    final data = directGateway
        ? await _directRpc('pet.hatch', args, 'Hatch pet')
        : _asMap(await post('/api/v1/pet/hatch', body: args));
    return _requireOk(data, 'Hatch pet');
  }

  Future<Map<String, dynamic>> petGenerate(Map<String, dynamic> args) async {
    // The server's own gateway RPC budget for `pet.generate` is up to 300s
    // (image generation) — both the REST default (30s) and the direct-
    // gateway default (`HermesPolicy.gatewayTimeout`, 120s) would abort the
    // client side of a call the server is still legitimately working on.
    const timeout = Duration(seconds: 300);
    final data = directGateway
        ? await _directRpc(
            'pet.generate',
            args,
            'Generate pet',
            timeout: timeout,
          )
        : _asMap(
            await post('/api/v1/pet/generate', body: args, timeout: timeout),
          );
    return _requireOk(data, 'Generate pet');
  }

  Future<Map<String, dynamic>> petGenerateStatus() async {
    return directGateway
        ? _directRpc('pet.generate.status', const {}, 'Pet generation status')
        : _asMap(await get('/api/v1/pet/generate/status'));
  }

  Future<void> petCancel(String token) async {
    directGateway
        ? await _directRpc('pet.cancel', {'token': token}, 'Cancel pet job')
        : await post('/api/v1/pet/cancel', body: {'token': token});
  }

  Future<void> petRemove(String slug) async {
    directGateway
        ? await _directRpc('pet.remove', {'slug': slug}, 'Remove pet')
        : await post('/api/v1/pet/remove', body: {'slug': slug});
  }

  Future<void> petDisable() async {
    final data = directGateway
        ? await _directRpc('pet.disable', const {}, 'Disable pet')
        : _asMap(await post('/api/v1/pet/disable'));
    _requireOk(data, 'Disable pet');
  }

  /// Renames an installed pet and returns its (possibly realigned) slug.
  /// The backend keys this by `slug`, not "whichever pet is active" — a
  /// caller renaming the active pet must pass its current slug explicitly.
  Future<String> petRename(String slug, String name) async {
    final data = directGateway
        ? await _directRpc('pet.rename', {
            'slug': slug,
            'name': name,
          }, 'Rename pet')
        : _asMap(
            await post(
              '/api/v1/pet/rename',
              body: {'slug': slug, 'name': name},
            ),
          );
    _requireOk(data, 'Rename pet');
    return data['slug']?.toString() ?? slug;
  }

  // ------------------------------------------------------------- billing
  Future<BillingState> billingState() async {
    final data = directGateway
        ? await _directRpc('billing.state', const {}, 'Billing state')
        : await get('/api/v1/billing');
    return BillingState.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> billingCharge(
    double amount, {
    String? idempotencyKey,
  }) async {
    final body = {
      'amount_usd': amount.toString(),
      'idempotency_key': ?idempotencyKey,
    };
    final data = directGateway
        ? await _directRpc('billing.charge', body, 'Billing charge')
        : _asMap(await post('/api/v1/billing/charge', body: body));
    return _requireOk(data, 'Billing charge');
  }

  Future<Map<String, dynamic>> charge(double amount) async {
    return billingCharge(amount);
  }

  Future<Map<String, dynamic>> billingChargeStatus(String chargeId) async {
    final data = directGateway
        ? await _directRpc('billing.charge_status', {
            'charge_id': chargeId,
          }, 'Billing charge status')
        : _asMap(
            await get(
              '/api/v1/billing/charge/status',
              query: {'charge_id': chargeId},
            ),
          );
    return _requireOk(data, 'Billing charge status');
  }

  /// Desktop parity: `use-step-up.ts` — the remote-spending step-up flow
  /// unblocking a `billing:manage`-scoped action after an
  /// `insufficient_scope` refusal. The device-code itself streams over the
  /// `billing.step_up.verification` gateway event while this call is
  /// in-flight (both transports still carry gateway events); this method
  /// only returns the terminal `{ok, granted}` result.
  Future<Map<String, dynamic>> billingStepUp({String? sessionId}) async {
    final body = {'session_id': ?sessionId};
    final data = directGateway
        ? await _directRpc('billing.step_up', body, 'Billing step-up')
        : _asMap(await post('/api/v1/billing/step-up', body: body));
    return _requireOk(data, 'Billing step-up');
  }

  Future<Map<String, dynamic>> updateAutoReload(
    bool autoReload,
    double threshold,
    double reloadTo,
  ) async {
    final body = {
      'enabled': autoReload,
      'threshold': threshold,
      'top_up_amount': reloadTo,
    };
    final data = directGateway
        ? await _directRpc('billing.auto_reload', body, 'Auto reload')
        : _asMap(await post('/api/v1/billing/auto-reload', body: body));
    return _requireOk(data, 'Auto reload');
  }

  Future<UsageBars> usageBars() async {
    final data = directGateway
        ? await _directRpc('usage.bars', const {}, 'Usage bars')
        : await get('/api/v1/billing/usage-bars');
    return UsageBars.fromJson(_asMap(data));
  }

  Future<SubscriptionState> subscriptionState() async {
    final data = directGateway
        ? await _directRpc('subscription.state', const {}, 'Subscription state')
        : await get('/api/v1/subscription');
    return SubscriptionState.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> subscriptionPreview(
    Map<String, dynamic> body,
  ) async {
    final params = _subscriptionParams(body);
    final data = directGateway
        ? await _directRpc(
            'subscription.preview',
            params,
            'Subscription preview',
          )
        : _asMap(await post('/api/v1/subscription/preview', body: params));
    return _requireOk(data, 'Subscription preview');
  }

  Future<Map<String, dynamic>> subscriptionChange(
    Map<String, dynamic> body,
  ) async {
    final params = _subscriptionParams(body);
    final data = directGateway
        ? await _directRpc('subscription.change', params, 'Subscription change')
        : _asMap(await post('/api/v1/subscription/change', body: params));
    return _requireOk(data, 'Subscription change');
  }

  Future<Map<String, dynamic>> subscriptionResume() async {
    final data = directGateway
        ? await _directRpc(
            'subscription.resume',
            const {},
            'Resume subscription',
          )
        : _asMap(await post('/api/v1/subscription/resume'));
    return _requireOk(data, 'Resume subscription');
  }

  Future<Map<String, dynamic>> subscriptionUpgrade(
    Map<String, dynamic> body,
  ) async {
    final params = _subscriptionParams(body);
    final data = directGateway
        ? await _directRpc(
            'subscription.upgrade',
            params,
            'Upgrade subscription',
          )
        : _asMap(await post('/api/v1/subscription/upgrade', body: params));
    return _requireOk(data, 'Upgrade subscription');
  }

  Map<String, dynamic> _subscriptionParams(Map<String, dynamic> body) {
    final tier =
        body['subscription_type_id'] ?? body['target_plan'] ?? body['plan_id'];
    return {
      if (tier != null && tier.toString().trim().isNotEmpty)
        'subscription_type_id': tier.toString(),
      if (body['cancel'] == true || body['cancel_at_period_end'] == true)
        'cancel': true,
      if (body['idempotency_key'] != null)
        'idempotency_key': body['idempotency_key'],
    };
  }

  // --------------------------------------------------------- credentials
  Future<List<CredentialProvider>> credentialProviders() async {
    final data = await get('/api/v1/credentials/providers');
    final list = (data as Map)['providers'] as List? ?? [];
    return list
        .map(
          (e) =>
              CredentialProvider.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<Map<String, dynamic>> saveCredentialKey(
    String slug,
    String apiKey,
  ) async {
    final data = await post(
      '/api/v1/credentials/save-key',
      body: {'slug': slug, 'api_key': apiKey},
    );
    return _asMap(data);
  }

  Future<void> disconnectCredential(String slug) async {
    await post('/api/v1/credentials/disconnect', body: {'slug': slug});
  }

  // ----------------------------------------------------------- messaging
  Map<String, String>? _messagingProfileQuery(String? profile) {
    final value = profile?.trim();
    if (value == null ||
        value.isEmpty ||
        value.toLowerCase() == 'default' ||
        value.toLowerCase() == 'current') {
      return null;
    }
    return {'profile': value};
  }

  String? _messagingProfileValue(String? profile) =>
      _messagingProfileQuery(profile)?['profile'];

  Future<List<MessagingPlatform>> messagingPlatforms({String? profile}) async {
    final data = await get(
      '/api/v1/messaging/platforms',
      query: _messagingProfileQuery(profile),
    );
    final list = (data as Map)['platforms'] as List? ?? [];
    return list
        .map(
          (e) => MessagingPlatform.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<Map<String, dynamic>> updateMessagingPlatform(
    String platform, {
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
    String? profile,
  }) async {
    final body = <String, dynamic>{
      'enabled': ?enabled,
      if (env != null && env.isNotEmpty) 'env': env,
      if (clearEnv != null && clearEnv.isNotEmpty) 'clear_env': clearEnv,
    };
    return _asMap(
      await put(
        '/api/v1/messaging/platforms/${_seg(platform)}',
        query: _messagingProfileQuery(profile),
        body: body,
      ),
    );
  }

  Future<Map<String, dynamic>> testMessagingPlatform(
    String platform, {
    String? profile,
  }) async {
    return _asMap(
      await post(
        '/api/v1/messaging/platforms/${_seg(platform)}/test',
        query: _messagingProfileQuery(profile),
        allowExplicitFailure: true,
      ),
    );
  }

  Future<MessagingPairings> messagingPairings({String? profile}) async {
    final data = _asMap(
      await get('/api/v1/pairing', query: _messagingProfileQuery(profile)),
    );
    return MessagingPairings.fromJson(data);
  }

  Future<Map<String, dynamic>> messagingConfig(
    String platform, {
    String? profile,
  }) async {
    if (directGateway) {
      final data = _asMap(
        await get(
          '/api/v1/messaging/platforms',
          query: _messagingProfileQuery(profile),
        ),
      );
      for (final raw in data['platforms'] as List? ?? const []) {
        if (raw is! Map) continue;
        final row = raw.cast<String, dynamic>();
        final id = (row['id'] ?? row['name'] ?? '').toString();
        if (id.toLowerCase() == platform.toLowerCase()) return row;
      }
      throw ApiException(404, runtimeL10n.errorMessagingPlatformNotFound);
    }
    final data = await get(
      '/api/v1/messaging/${_seg(platform)}/config',
      query: _messagingProfileQuery(profile),
    );
    return _asMap(data);
  }

  Future<void> messagingSetEnv(
    String platform,
    String key,
    String value, {
    String? profile,
  }) async {
    await updateMessagingPlatform(
      platform,
      env: value.trim().isEmpty ? null : {key: value},
      clearEnv: value.trim().isEmpty ? [key] : null,
      profile: profile,
    );
  }

  Future<List<MessagingPairing>> messagingPending(
    String platform, {
    String? profile,
  }) async {
    final data = await get(
      directGateway
          ? '/api/v1/pairing'
          : '/api/v1/messaging/${_seg(platform)}/pending',
      query: _messagingProfileQuery(profile),
    );
    final list =
        (data as Map)['pending'] as List? ?? (data['pairings'] as List?) ?? [];
    return list
        .where(
          (item) =>
              !directGateway ||
              item is Map &&
                  (item['platform'] ?? '').toString().toLowerCase() ==
                      platform.toLowerCase(),
        )
        .map(
          (e) => MessagingPairing.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  Future<void> messagingApprovePairing(
    String platform,
    String pairingId, {
    String? profile,
  }) async {
    await post(
      '/api/v1/pairing/approve',
      body: {
        'platform': platform,
        'request_id': pairingId,
        'profile': ?_messagingProfileValue(profile),
      },
    );
  }

  Future<void> messagingRevokePairing(
    String platform,
    String userId, {
    String? profile,
  }) async {
    await post(
      '/api/v1/pairing/revoke',
      body: {
        'platform': platform,
        'user_id': userId,
        'profile': ?_messagingProfileValue(profile),
      },
    );
  }

  Future<Map<String, dynamic>> restartGateway() async =>
      _asMap(await post('/api/v1/gateway/restart'));

  // ---------------------------------------------------------- remote push
  Future<Map<String, dynamic>> registerPushDevice(
    Map<String, dynamic> registration,
  ) async {
    if (directGateway) _unsupportedDirectGateway('Remote push registration');
    return _asMap(await post('/api/v1/push/devices', body: registration));
  }

  Future<void> unregisterPushDevice(
    String deviceId, {
    String? connectionId,
  }) async {
    if (directGateway) _unsupportedDirectGateway('Remote push registration');
    await delete(
      '/api/v1/push/devices/${_seg(deviceId)}',
      query: {'connection_id': ?connectionId},
    );
  }

  Future<Map<String, dynamic>> pushStatus() async {
    if (directGateway) _unsupportedDirectGateway('Remote push status');
    return _asMap(await get('/api/v1/push/status'));
  }

  Future<Map<String, dynamic>> testPushDevice(String deviceId) async {
    if (directGateway) _unsupportedDirectGateway('Remote push test');
    return _asMap(
      await post('/api/v1/push/test', body: {'device_id': deviceId}),
    );
  }

  // ------------------------------------------------------------ webhooks
  Future<({List<Webhook> items, bool enabled, String baseUrl})>
  webhooks() async {
    final data = await get('/api/v1/webhooks');
    final list = (data as Map)['webhooks'] as List? ?? [];
    final items = list
        .map((e) => Webhook.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return (
      items: items,
      enabled: data['enabled'] == true,
      baseUrl: (data['base_url'] ?? '').toString(),
    );
  }

  Future<Webhook> webhookCreate(Map<String, dynamic> body) async {
    final data = await post('/api/v1/webhooks', body: body);
    return Webhook.fromJson(_asMap(data));
  }

  Future<Map<String, dynamic>> enableWebhooks() async {
    final data = await post('/api/v1/webhooks/enable');
    return _asMap(data);
  }

  Future<void> setWebhookEnabled(String id, bool enabled) async {
    await put(
      '/api/v1/webhooks/${_seg(id)}/enabled',
      body: {'enabled': enabled},
    );
  }

  Future<void> webhookDelete(String id) async {
    await delete('/api/v1/webhooks/${_seg(id)}');
  }

  // ------------------------------------------------------- git (extended)
  Future<CommitMessageSuggestion> gitCommitMessage(
    String path, {
    String? scope,
  }) async {
    if (directGateway) {
      final context = await gitCommitContext(path);
      final diff = context['diff']?.toString() ?? '';
      if (diff.trim().isEmpty) {
        return CommitMessageSuggestion(message: '');
      }
      final result = await _directRpc('llm.oneshot', {
        'template': 'commit_message',
        'temperature': 0.8,
        'variables': {
          'diff': diff,
          'recent_commits': context['recent'] ?? const [],
        },
      }, 'Commit message generation');
      return CommitMessageSuggestion(
        message: result['text']?.toString().trim() ?? '',
      );
    }
    final data = await post(
      '/api/v1/git/commit-message',
      body: {'path': path, 'scope': ?scope},
    );
    return CommitMessageSuggestion.fromJson(_asMap(data));
  }

  Future<PrCreateResult> gitPrCreate(String path) async {
    final data = await post(
      '/api/v1/git/review/create-pr',
      body: {'path': path},
    );
    return PrCreateResult.fromJson(_asMap(data));
  }

  // ---------------------------------------------------- terminal (extended)
  Future<Map<String, dynamic>> terminalExecute(
    String command, {
    String? cwd,
  }) async {
    if (!capabilities.terminalExecute) {
      _unsupportedDirectGateway('One-shot terminal execution');
    }
    final data = await post(
      '/api/v1/terminal/execute',
      body: {'command': command, if (cwd != null && cwd.isNotEmpty) 'cwd': cwd},
      // The server allows this command up to 35s (`shell.exec` gateway RPC)
      // — stay above that so a legitimately slow-but-finishing command
      // isn't aborted client-side before the server's own timeout would
      // even fire.
      timeout: const Duration(seconds: 40),
    );
    return _asMap(data);
  }
}
