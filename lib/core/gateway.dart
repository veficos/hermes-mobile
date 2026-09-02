/// WebSocket JSON-RPC client for the Hermes gateway.
///
/// Speaks the same protocol as the desktop renderer: newline-free JSON-RPC
/// 2.0 frames over a single WebSocket to ``<server>/api/v1/ws?token=<key>``.
/// Requests are matched by id; server pushes arrive as ``event`` frames.
///
/// Design fixes (APP_DESIGN.md D11): concurrent-connect guard, safe channel
/// handling in `request()`, and a client-initiated disconnect that does not
/// emit `onDisconnect`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import '../l10n/runtime_l10n.dart';

import '../theme/hermes_tokens.dart';

import 'ws_connect.dart';

/// A gateway event (server push).
class GatewayEvent {
  final String type;
  final Map<String, dynamic> payload;
  final String? sessionId;
  final String? profile;

  GatewayEvent({
    required this.type,
    required this.payload,
    this.sessionId,
    this.profile,
  });

  factory GatewayEvent.fromFrame(Map<String, dynamic> frame) {
    final rawParams = frame['params'];
    final params = rawParams is Map<String, dynamic>
        ? rawParams
        : rawParams is Map
        ? rawParams.cast<String, dynamic>()
        : <String, dynamic>{};
    final nested = (params['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    // Envelope fields are authoritative routing metadata. Nested payloads are
    // provider data and must not overwrite an outer status/session id.
    final payload = <String, dynamic>{...nested, ...params}..remove('payload');
    return GatewayEvent(
      type: (params['type'] ?? frame['type'] ?? '').toString(),
      payload: payload,
      sessionId: (params['session_id'] ?? nested['session_id'])?.toString(),
      profile: (params['profile'] ?? nested['profile'])?.toString(),
    );
  }
}

class GatewayException implements Exception {
  final int? code;
  final String message;
  final bool requestMayHaveBeenSent;
  final String? reason;

  GatewayException(
    this.code,
    this.message, {
    this.requestMayHaveBeenSent = false,
    this.reason,
  });

  @override
  String toString() => 'GatewayException($code): $message';
}

const gatewayAuthenticationFailedCode = -3;

String gatewayCloseMessage(int? code, String? reason) => switch (code) {
  4401 => runtimeL10n.commonAuthenticationFailed,
  1011 => runtimeL10n.gatewayUnavailable,
  _ => reason?.trim().isNotEmpty == true ? reason!.trim() : 'connection closed',
};

class GatewayClient {
  final String serverBaseUrl; // e.g. http://192.168.1.5:8877
  final String apiKey;
  final Map<String, String> extraHeaders;
  final Future<Uri> Function()? webSocketUriProvider;
  final bool directGateway;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Completer<void>? _connecting; // F12: dedupe/cancel concurrent handshakes
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final StreamController<GatewayEvent> _events = StreamController.broadcast();

  /// Fired with the error message when the socket drops unexpectedly.
  /// Not fired when the client calls [disconnect].
  final StreamController<String> _onDisconnect = StreamController.broadcast();

  GatewayClient({
    required this.serverBaseUrl,
    required this.apiKey,
    this.extraHeaders = const {},
    this.webSocketUriProvider,
    this.directGateway = false,
  });

  Stream<GatewayEvent> get events => _events.stream;
  Stream<String> get onDisconnect => _onDisconnect.stream;
  bool get isConnected => _channel != null;

  Uri get _wsUri {
    final base = serverBaseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceAll(RegExp(r'/+$'), '');
    final path = directGateway ? '/api/ws' : '/api/v1/ws';
    return Uri.parse('$base$path?token=${Uri.encodeQueryComponent(apiKey)}');
  }

  /// Connect and wait for the gateway handshake. Safe to call concurrently.
  Future<void> connect() async {
    final existing = _connecting;
    if (existing != null) {
      return existing.future;
    }
    if (_channel != null) return;

    final connecting = Completer<void>();
    _connecting = connecting;
    try {
      // Explicit platform connector — avoids dart:io Platform._version on web.
      final uri = webSocketUriProvider == null
          ? _wsUri
          : await webSocketUriProvider!();
      if (connecting.isCompleted) {
        // disconnect() may have cancelled this attempt while OAuth, DNS, or
        // another asynchronous URI lookup was still in progress.
        return await connecting.future;
      }
      final channel = connectWs(uri, headers: extraHeaders);
      // Swallow the channel's handshake-failure future: without a listener it
      // surfaces as an unhandled zone error. The stream onError below reports
      // the same failure through onDisconnect and fails connect() promptly.
      unawaited(channel.ready.catchError((_) {}));
      _channel = channel;

      _sub = channel.stream.listen(
        (raw) {
          if (identical(_channel, channel)) _onFrame(raw);
        },
        onError: (Object e) {
          _handleSocketClosed('$e', byClient: false, socket: channel);
          if (!connecting.isCompleted) {
            connecting.completeError(
              GatewayException(-1, 'connection failed: $e'),
            );
          }
        },
        onDone: () {
          final code = channel.closeCode;
          final message = gatewayCloseMessage(code, channel.closeReason);
          _handleSocketClosed(message, byClient: false, socket: channel);
          if (!connecting.isCompleted) {
            connecting.completeError(
              GatewayException(
                code == 4401 ? gatewayAuthenticationFailedCode : -1,
                message,
              ),
            );
          }
        },
        cancelOnError: true,
      );
      // Mark connected once the gateway handshake (gateway.ready) arrives.
      unawaited(
        _events.stream.firstWhere((e) => e.type == 'gateway.ready').then((_) {
          if (!connecting.isCompleted) connecting.complete();
        }),
      );
      await connecting.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      // F12: a timed-out connect must not leave a half-open channel behind.
      _handleSocketClosed(
        'connect timed out',
        byClient: true,
        socket: _channel,
      );
      rethrow;
    } finally {
      if (identical(_connecting, connecting)) _connecting = null;
    }
  }

  void _onFrame(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> frame;
    try {
      frame = (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      return;
    }
    final method = frame['method'];
    if (method == 'event') {
      _events.add(GatewayEvent.fromFrame(frame));
      return;
    }
    final id = frame['id'];
    if (id is int) {
      final completer = _pending.remove(id);
      if (completer != null) {
        if (frame.containsKey('error')) {
          final err = (frame['error'] as Map?)?.cast<String, dynamic>() ?? {};
          completer.completeError(
            GatewayException(
              (err['code'] as num?)?.toInt(),
              (err['message'] ?? 'unknown error').toString(),
              reason: (err['data'] as Map?)?['reason']?.toString(),
            ),
          );
        } else {
          completer.complete(
            (frame['result'] as Map?)?.cast<String, dynamic>() ?? {},
          );
        }
      }
    }
  }

  void _handleSocketClosed(
    String reason, {
    required bool byClient,
    WebSocketChannel? socket,
  }) {
    // onDone/onError from an old socket can arrive after a replacement has
    // already connected. Never let that stale callback tear down the current
    // iOS network-path generation.
    if (socket != null && !identical(_channel, socket)) return;
    _channel = null;
    final sub = _sub;
    _sub = null;
    sub?.cancel();
    // Fail all in-flight requests so callers never hang forever.
    final pending = _pending.values.toList();
    _pending.clear();
    for (final completer in pending) {
      if (!completer.isCompleted) {
        completer.completeError(
          GatewayException(
            -1,
            'gateway disconnected: $reason',
            requestMayHaveBeenSent: true,
          ),
        );
      }
    }
    if (!byClient) {
      _onDisconnect.add(reason);
    }
  }

  /// Send a JSON-RPC request and await its result.
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = HermesPolicy.gatewayTimeout,
  }) async {
    if (_channel == null) {
      await connect();
    }
    // C2: capture the channel locally; it may die between connect() and add.
    final channel = _channel;
    if (channel == null) {
      throw GatewayException(-1, 'gateway disconnected');
    }
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    final frame = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': params,
    });
    try {
      channel.sink.add(frame);
    } catch (e) {
      _pending.remove(id);
      _invalidateSocket(channel, 'send failed: $e');
      throw GatewayException(-1, 'send failed: $e');
    }
    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(id);
      _invalidateSocket(channel, 'request timed out');
      throw GatewayException(
        -2,
        'timeout waiting for "$method" response',
        requestMayHaveBeenSent: true,
      );
    }
  }

  void _invalidateSocket(WebSocketChannel socket, String reason) {
    if (!identical(_channel, socket)) return;
    _handleSocketClosed(reason, byClient: false, socket: socket);
    // Closing is best-effort: the important part is making the stale channel
    // unavailable synchronously so the runtime can begin reconnecting.
    unawaited(socket.sink.close().catchError((_) {}));
  }

  Future<void> disconnect() async {
    // F13: a client-initiated disconnect must not emit onDisconnect.
    final channel = _channel;
    final connecting = _connecting;
    if (connecting != null && !connecting.isCompleted) {
      connecting.completeError(
        GatewayException(-1, 'connection attempt cancelled'),
      );
    }
    _handleSocketClosed('disconnected by client', byClient: true);
    await _sub?.cancel();
    await channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    await _onDisconnect.close();
  }
}
