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
