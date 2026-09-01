library;

import 'gateway_oauth.dart';
import 'native_gateway_login_stub.dart'
    if (dart.library.io) 'native_gateway_login_io.dart'
    as impl;

typedef OpenGatewayLoginUrl = Future<bool> Function(Uri uri);

Future<GatewayOAuthTokens> runNativeGatewayLogin({
  required String baseUrl,
  required GatewayOAuthClient client,
  required OpenGatewayLoginUrl openUrl,
  String provider = '',
  Duration timeout = const Duration(minutes: 5),
}) => impl.runNativeGatewayLogin(
  baseUrl: baseUrl,
  client: client,
  openUrl: openUrl,
  provider: provider,
  timeout: timeout,
);
