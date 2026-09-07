/// Platform-appropriate WebSocket connector.
///
/// `WebSocketChannel.connect` / `IOWebSocketChannel` can resolve to `dart:io`
/// stubs on Flutter web and throw `Unsupported operation: Platform._version`.
/// Explicit conditional imports keep browser and VM paths separate.
library;

import 'package:web_socket_channel/web_socket_channel.dart';

import 'ws_connect_stub.dart'
    if (dart.library.js_interop) 'ws_connect_web.dart'
    if (dart.library.html) 'ws_connect_web.dart'
    if (dart.library.io) 'ws_connect_io.dart'
    as impl;

/// Open a WebSocket to [uri] using the browser API on web and dart:io elsewhere.
WebSocketChannel connectWs(Uri uri, {Map<String, String> headers = const {}}) =>
    impl.connectWs(uri, headers: headers);

/// The server rejected the WebSocket handshake before completing the
/// protocol upgrade, carrying the HTTP status code from that rejection (e.g.
/// 401/403 for an invalid API key). Only ever thrown on IO platforms —
/// browsers' native WebSocket API does not expose pre-upgrade HTTP status
/// codes to JS, so on web an invalid key still surfaces as a generic close.
class WsHandshakeRejected implements Exception {
  final int statusCode;
  final String message;

  WsHandshakeRejected(this.statusCode, this.message);

  @override
  String toString() => 'WsHandshakeRejected($statusCode): $message';
}
