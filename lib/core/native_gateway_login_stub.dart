import 'gateway_oauth.dart';

Future<GatewayOAuthTokens> runNativeGatewayLogin({
  required String baseUrl,
  required GatewayOAuthClient client,
  required Future<bool> Function(Uri uri) openUrl,
  required String provider,
  required Duration timeout,
}) => throw UnsupportedError(
  'Native gateway OAuth requires a platform loopback listener',
);
