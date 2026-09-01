import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

WebSocketChannel connectWs(Uri uri, {Map<String, String> headers = const {}}) =>
    HtmlWebSocketChannel.connect(uri);
