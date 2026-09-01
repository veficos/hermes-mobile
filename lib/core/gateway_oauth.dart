/// RFC 8252 authentication primitives for direct Hermes gateway connections.
library;

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../l10n/runtime_l10n.dart';
import 'settings_store.dart';

class GatewayOAuthException implements Exception {
  final String message;
  final int? statusCode;

  const GatewayOAuthException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class GatewayOAuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresAt;
  final String provider;
  final String userId;

  const GatewayOAuthTokens({
    required this.accessToken,
    this.refreshToken = '',
    this.expiresAt = 0,
    this.provider = '',
    this.userId = '',
  });

  bool needsRefresh({int? nowSeconds, int skewSeconds = 60}) =>
      expiresAt <= 0 ||
      (nowSeconds ?? DateTime.now().millisecondsSinceEpoch ~/ 1000) >=
          expiresAt - skewSeconds;

  factory GatewayOAuthTokens.fromJson(Map<String, dynamic> json) {
    final accessToken = (json['access_token'] ?? json['accessToken'] ?? '')
        .toString();
    if (accessToken.isEmpty) {
      throw GatewayOAuthException(runtimeL10n.gatewayOauthAccessTokenMissing);
    }
    final rawExpiresAt = json['expires_at'] ?? json['expiresAt'];
    return GatewayOAuthTokens(
      accessToken: accessToken,
      refreshToken: (json['refresh_token'] ?? json['refreshToken'] ?? '')
          .toString(),
      expiresAt: rawExpiresAt is num
          ? rawExpiresAt.toInt()
          : int.tryParse((rawExpiresAt ?? '').toString()) ?? 0,
      provider: (json['provider'] ?? '').toString(),
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
    );
  }

  ConnectionSettings applyTo(ConnectionSettings settings) => settings.copyWith(
    apiKey: accessToken,
    refreshToken: refreshToken,
    oauthExpiresAt: expiresAt,
    oauthProvider: provider,
    oauthUserId: userId,
    authMode: ConnectionAuthMode.oauth,
    transport: ConnectionTransport.directGateway,
  );
}

class GatewayPkcePair {
  final String verifier;
  final String challenge;
  const GatewayPkcePair(this.verifier, this.challenge);
}

String _base64UrlNoPadding(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

GatewayPkcePair generateGatewayPkce([Random? random]) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => source.nextInt(256));
  final verifier = _base64UrlNoPadding(bytes);
  final challenge = _base64UrlNoPadding(
    sha256.convert(ascii.encode(verifier)).bytes,
  );
  return GatewayPkcePair(verifier, challenge);
}

String generateGatewayOAuthState([Random? random]) {
  final source = random ?? Random.secure();
  return _base64UrlNoPadding(
    List<int>.generate(24, (_) => source.nextInt(256)),
  );
}

Uri gatewayNativeAuthorizeUri(
  String baseUrl, {
  required String challenge,
  required String redirectUri,
  required String state,
  String provider = '',
}) {
  final base = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), ''));
  return base.replace(
    path: '${base.path.replaceAll(RegExp(r'/+$'), '')}/auth/native/authorize',
    queryParameters: {
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'redirect_uri': redirectUri,
      'state': state,
      if (provider.trim().isNotEmpty) 'provider': provider.trim(),
    },
  );
}

String parseGatewayOAuthCallback(Uri callback, String expectedState) {
  final error = callback.queryParameters['error'];
  if (error?.isNotEmpty == true) {
    final description = callback.queryParameters['error_description'];
    final detail = description?.isNotEmpty == true
        ? '$error ($description)'
        : error!;
    throw GatewayOAuthException(runtimeL10n.gatewayOauthRejected(detail));
  }
  final code = callback.queryParameters['code'] ?? '';
  final state = callback.queryParameters['state'] ?? '';
  if (code.isEmpty) {
    throw GatewayOAuthException(runtimeL10n.gatewayOauthCodeMissing);
  }
  if (expectedState.isEmpty || state != expectedState) {
    throw GatewayOAuthException(runtimeL10n.gatewayOauthStateMismatch);
  }
  return code;
}

class GatewayOAuthClient {
  final String baseUrl;
  final Map<String, String> extraHeaders;
  final http.Client _client;

  GatewayOAuthClient({
    required this.baseUrl,
    this.extraHeaders = const {},
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Map<String, String> _headers({String? bearer}) => {
    ...extraHeaders,
    'Content-Type': 'application/json',
    if (bearer != null && bearer.isNotEmpty) 'Authorization': 'Bearer $bearer',
  };

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final response = await _client
        .post(
          _uri(path),
          headers: _headers(bearer: bearer),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> decoded = {};
    try {
      decoded = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode >= 400) {
      throw GatewayOAuthException(
        (decoded['detail'] ?? decoded['error'] ?? response.body).toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> status() async {
    final response = await _client
        .get(_uri('/api/status'), headers: {...extraHeaders})
        .timeout(const Duration(seconds: 15));
    Map<String, dynamic> decoded = {};
    try {
      decoded = (jsonDecode(response.body) as Map).cast<String, dynamic>();
    } catch (_) {}
    if (response.statusCode >= 400) {
      throw GatewayOAuthException(
        (decoded['detail'] ?? decoded['error'] ?? response.body).toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Future<GatewayOAuthTokens> exchangeCode({
    required String code,
    required String verifier,
  }) async => GatewayOAuthTokens.fromJson(
    await _post('/auth/native/token', {
      'code': code,
      'code_verifier': verifier,
    }),
  );

  Future<GatewayOAuthTokens> refresh(GatewayOAuthTokens current) async {
    if (current.refreshToken.isEmpty) {
      throw GatewayOAuthException(runtimeL10n.gatewayOauthRefreshTokenMissing);
    }
    return GatewayOAuthTokens.fromJson(
      await _post('/auth/native/refresh', {
        'refresh_token': current.refreshToken,
        if (current.provider.isNotEmpty) 'provider': current.provider,
      }),
    );
  }

  Future<String> mintWebSocketTicket(String accessToken) async {
    final body = await _post(
      '/api/auth/ws-ticket',
      const {},
      bearer: accessToken,
    );
    final ticket = body['ticket']?.toString() ?? '';
    if (ticket.isEmpty) {
      throw GatewayOAuthException(runtimeL10n.gatewayOauthTicketMissing);
    }
    return ticket;
  }

  void close() => _client.close();
}

class GatewayOAuthSession {
  final GatewayOAuthClient client;
  final Future<void> Function(GatewayOAuthTokens tokens)? onTokensChanged;
  GatewayOAuthTokens _tokens;
  Future<GatewayOAuthTokens>? _refreshing;

  GatewayOAuthSession(
    this._tokens, {
    required this.client,
    this.onTokensChanged,
  });

  GatewayOAuthTokens get tokens => _tokens;

  Future<String> accessToken() async {
    if (!_tokens.needsRefresh()) return _tokens.accessToken;
    final active = _refreshing;
    if (active != null) return (await active).accessToken;
    final next = client.refresh(_tokens);
    _refreshing = next;
    try {
      _tokens = await next;
      await onTokensChanged?.call(_tokens);
      return _tokens.accessToken;
    } finally {
      _refreshing = null;
    }
  }

  Future<Uri> webSocketUri() async {
    final token = await accessToken();
    final ticket = await client.mintWebSocketTicket(token);
    final base = client.baseUrl
        .replaceFirst(RegExp(r'^http'), 'ws')
        .replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/ws?ticket=${Uri.encodeQueryComponent(ticket)}');
  }
}
