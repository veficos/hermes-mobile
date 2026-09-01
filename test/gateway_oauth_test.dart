import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/gateway_oauth.dart';
import 'package:hermes_mobile/core/settings_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('PKCE is S256 and authorize URL carries the loopback contract', () {
    final pair = generateGatewayPkce(Random(42));
    final expected = base64Url
        .encode(sha256.convert(ascii.encode(pair.verifier)).bytes)
        .replaceAll('=', '');
    expect(pair.verifier.length, 43);
    expect(pair.challenge, expected);

    final uri = gatewayNativeAuthorizeUri(
      'https://gateway.example/prefix/',
      challenge: pair.challenge,
      redirectUri: 'http://127.0.0.1:54321/callback',
      state: 'csrf-state',
      provider: 'nous',
    );
    expect(uri.path, '/prefix/auth/native/authorize');
    expect(uri.queryParameters['code_challenge_method'], 'S256');
    expect(
      uri.queryParameters['redirect_uri'],
      'http://127.0.0.1:54321/callback',
    );
    expect(uri.queryParameters['state'], 'csrf-state');
    expect(uri.queryParameters['provider'], 'nous');
  });

  test('callback rejects missing code, gateway errors, and CSRF mismatch', () {
    expect(
      parseGatewayOAuthCallback(
        Uri.parse('http://127.0.0.1/callback?code=ok&state=expected'),
        'expected',
      ),
      'ok',
    );
    expect(
      () => parseGatewayOAuthCallback(
        Uri.parse('http://127.0.0.1/callback?code=ok&state=wrong'),
        'expected',
      ),
      throwsA(isA<GatewayOAuthException>()),
    );
    expect(
      () => parseGatewayOAuthCallback(
        Uri.parse('http://127.0.0.1/callback?error=access_denied'),
        'expected',
      ),
      throwsA(isA<GatewayOAuthException>()),
    );
  });

  test(
    'token exchange, refresh, and ticket mint use the native gateway API',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/native/token')) {
          return http.Response(
            jsonEncode({
              'access_token': 'access-1',
              'refresh_token': 'refresh-1',
              'expires_at': 1234,
              'provider': 'nous',
              'user_id': 'user-1',
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/auth/native/refresh')) {
          return http.Response(
            jsonEncode({
              'access_token': 'access-2',
              'refresh_token': 'refresh-2',
              'expires_at': 9999999999,
              'provider': 'nous',
              'user_id': 'user-1',
            }),
            200,
          );
        }
        expect(request.headers['authorization'], 'Bearer access-2');
        return http.Response(jsonEncode({'ticket': 'single-use'}), 200);
      });
      final oauth = GatewayOAuthClient(
        baseUrl: 'https://gateway.example',
        extraHeaders: const {'CF-Access-Client-Id': 'id'},
        client: client,
      );

      final first = await oauth.exchangeCode(
        code: 'code',
        verifier: 'verifier',
      );
      expect(first.accessToken, 'access-1');
      final refreshed = await oauth.refresh(first);
      expect(refreshed.refreshToken, 'refresh-2');
      expect(
        await oauth.mintWebSocketTicket(refreshed.accessToken),
        'single-use',
      );
      expect(requests, hasLength(3));
      expect(
        requests.every((r) => r.headers['cf-access-client-id'] == 'id'),
        isTrue,
      );
    },
  );

  test('OAuth settings keep refresh credentials out of metadata', () {
    const settings = ConnectionSettings(
      serverUrl: 'https://cloud.example',
      kind: ConnectionKind.cloud,
      transport: ConnectionTransport.directGateway,
      authMode: ConnectionAuthMode.oauth,
      apiKey: 'access-secret',
      refreshToken: 'refresh-secret',
      oauthProvider: 'nous',
      oauthUserId: 'user-1',
      oauthExpiresAt: 123,
      org: 'research',
    );
    final metadata = jsonEncode(settings.toMetadataJson());
    expect(metadata, isNot(contains('access-secret')));
    expect(metadata, isNot(contains('refresh-secret')));
    final restored = ConnectionSettings.fromJson(settings.toJson());
    expect(restored.kind, ConnectionKind.cloud);
    expect(restored.transport, ConnectionTransport.directGateway);
    expect(restored.authMode, ConnectionAuthMode.oauth);
    expect(restored.refreshToken, 'refresh-secret');
  });
}
