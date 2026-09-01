import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'gateway.dart' show gatewayCloseMessage;
import '../l10n/runtime_l10n.dart';
import 'ws_connect.dart';

class TerminalGatewayEvent {
  final String type;
  final Map<String, dynamic> data;
  const TerminalGatewayEvent(this.type, this.data);
}

class TerminalGatewayClient {
  final String serverBaseUrl;
  final String apiKey;
  final Map<String, String> extraHeaders;
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Future<void>? _connecting;
  int _nextId = 1;
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final _events = StreamController<TerminalGatewayEvent>.broadcast();
  final _disconnects = StreamController<String>.broadcast();

  TerminalGatewayClient({
    required this.serverBaseUrl,
    required this.apiKey,
    this.extraHeaders = const {},
  });

  Stream<TerminalGatewayEvent> get events => _events.stream;
  Stream<String> get disconnects => _disconnects.stream;
  bool get isConnected => _channel != null;

  Uri get _uri {
    final base = serverBaseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceAll(RegExp(r'/+$'), '');
    return Uri.parse(
      '$base/api/v1/terminal/ws?token=${Uri.encodeQueryComponent(apiKey)}',
    );
  }

  Future<void> connect() async {
    final flight = _connecting;
    if (flight != null) return flight;
    if (_channel != null) return;
    final next = _connectOnce();
    _connecting = next;
    try {
      await next;
    } finally {
      if (identical(_connecting, next)) _connecting = null;
    }
  }

  Future<void> _connectOnce() async {
    final channel = connectWs(_uri, headers: extraHeaders);
    try {
      await channel.ready;
      _channel = channel;
      _subscription = channel.stream.listen(
        _onFrame,
        onError: (Object error) => _closed(error.toString()),
        onDone: () => _closed(
          gatewayCloseMessage(channel.closeCode, channel.closeReason),
        ),
        cancelOnError: true,
      );
    } catch (_) {
      await channel.sink.close();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> request(
    String op, [
    Map<String, dynamic> params = const {},
  ]) async {
    await connect();
    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    final channel = _channel;
    if (channel == null) {
      _pending.remove(id);
      throw StateError(runtimeL10n.terminalConnectionClosed);
    }
    try {
      channel.sink.add(jsonEncode({'op': op, 'request_id': id, ...params}));
    } catch (error) {
      _pending.remove(id);
      throw StateError(runtimeL10n.terminalRequestFailed('$error'));
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } finally {
      _pending.remove(id);
    }
  }

  /// Returns false (without throwing) when there's no live channel to send
  /// on — callers should treat that as dropped input, not a silent success.
  bool write(String id, String data) {
    if (_channel == null) return false;
    _channel!.sink.add(jsonEncode({'op': 'write', 'id': id, 'data': data}));
    return true;
  }

  bool resize(String id, int cols, int rows) {
    if (_channel == null) return false;
    _channel!.sink.add(
      jsonEncode({'op': 'resize', 'id': id, 'cols': cols, 'rows': rows}),
    );
    return true;
  }

  Future<void> disposeSession(String id) async {
    if (_channel == null) return;
    try {
      await request('dispose', {'id': id});
    } catch (_) {}
  }

  Future<void> close() async {
    final channel = _channel;
    _channel = null;
    await _subscription?.cancel();
    _subscription = null;
    await channel?.sink.close();
    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.completeError(StateError(runtimeL10n.terminalConnectionClosed));
      }
    }
    _pending.clear();
  }

  void _onFrame(dynamic raw) {
    try {
      final frame = jsonDecode(raw.toString()) as Map<String, dynamic>;
      final requestId = frame['request_id'];
      if (requestId is int && _pending.containsKey(requestId)) {
        final completer = _pending[requestId]!;
        if (frame['event'] == 'error') {
          completer.completeError(
            StateError(
              frame['message']?.toString() ?? runtimeL10n.terminalGenericError,
            ),
          );
        } else {
          completer.complete(frame);
        }
        return;
      }
      _events.add(
        TerminalGatewayEvent(frame['event']?.toString() ?? '', frame),
      );
    } catch (_) {}
  }

  void _closed(String reason) {
    if (_channel == null) return;
    _channel = null;
    _subscription = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted) pending.completeError(StateError(reason));
    }
    _pending.clear();
    _disconnects.add(reason);
  }
}
