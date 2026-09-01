import 'dart:async';
import 'dart:io';

import '../l10n/runtime_l10n.dart';
import 'gateway_oauth.dart';

Future<GatewayOAuthTokens> runNativeGatewayLogin({
  required String baseUrl,
  required GatewayOAuthClient client,
  required Future<bool> Function(Uri uri) openUrl,
  required String provider,
  required Duration timeout,
}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final pkce = generateGatewayPkce();
  final state = generateGatewayOAuthState();
  final redirectUri = 'http://127.0.0.1:${server.port}/callback';
  final authorize = gatewayNativeAuthorizeUri(
    baseUrl,
    challenge: pkce.challenge,
    redirectUri: redirectUri,
    state: state,
    provider: provider,
  );
  try {
    if (!await openUrl(authorize)) {
      throw const GatewayOAuthException(
        'Could not open the system browser for gateway sign-in',
      );
    }
    final callback = Completer<Uri>();
    final subscription = server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write(
          '<!doctype html><meta charset="utf-8"><title>Signed in</title>'
          '<body style="font:15px system-ui;text-align:center;margin:3rem">'
          '<h2>Signed in to Hermes</h2><p>You can return to the app.</p>',
        );
      await request.response.close();
      if (!callback.isCompleted &&
          (request.uri.queryParameters.containsKey('code') ||
              request.uri.queryParameters.containsKey('error'))) {
        callback.complete(request.uri);
      }
    });
    final callbackUri = await callback.future.timeout(timeout);
    await subscription.cancel();
    final code = parseGatewayOAuthCallback(callbackUri, state);
    return await client.exchangeCode(code: code, verifier: pkce.verifier);
  } on TimeoutException {
    throw GatewayOAuthException(runtimeL10n.gatewayOauthTimedOut);
  } finally {
    await server.close(force: true);
  }
}
