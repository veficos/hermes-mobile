import '../l10n/runtime_l10n.dart';
import 'gateway_oauth.dart';

Future<GatewayOAuthTokens> runNativeGatewayLogin({
  required String baseUrl,
  required GatewayOAuthClient client,
  required Future<bool> Function(Uri uri) openUrl,
  required String provider,
  required Duration timeout,
}) => throw UnsupportedError(runtimeL10n.gatewayOauthNativeUnsupported);
