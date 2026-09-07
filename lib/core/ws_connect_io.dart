import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../theme/hermes_tokens.dart';
import 'ws_connect.dart' show WsHandshakeRejected;

WebSocketChannel connectWs(Uri uri, {Map<String, String> headers = const {}}) {
  final socketFuture = WebSocket.connect(uri.toString(), headers: headers)
      .catchError((Object e) {
        // dart:io tags a pre-upgrade HTTP rejection (401/403 for a bad API
        // key) with the response status code. Normalize it to a
        // platform-agnostic type so `gateway.dart` can tell "wrong
        // credentials" apart from a transient network failure and stop
        // retrying instead of reconnecting forever.
        if (e is WebSocketException && e.httpStatusCode != null) {
          throw WsHandshakeRejected(e.httpStatusCode!, e.message);
        }
        throw e;
      })
      .then((socket) => socket..pingInterval = const Duration(seconds: 25))
      .timeout(HermesPolicy.socketConnectTimeout);
  return IOWebSocketChannel(socketFuture);
}
