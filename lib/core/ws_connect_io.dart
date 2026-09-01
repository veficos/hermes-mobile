import 'package:web_socket_channel/io.dart';

import '../theme/hermes_tokens.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWs(Uri uri, {Map<String, String> headers = const {}}) {
  return IOWebSocketChannel.connect(
    uri,
    headers: headers,
    connectTimeout: HermesPolicy.socketConnectTimeout,
    pingInterval: const Duration(seconds: 25),
  );
}
