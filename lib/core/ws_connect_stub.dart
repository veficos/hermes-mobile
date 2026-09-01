import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWs(Uri uri, {Map<String, String> headers = const {}}) {
  throw UnsupportedError(
    'WebSocket is unavailable on this platform (need dart:js_interop or dart:io).',
  );
}
