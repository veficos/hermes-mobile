library;

import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import '../l10n/runtime_l10n.dart';

class HermesDeepLink {
  final String kind;
  final String name;
  final Map<String, String> params;

  const HermesDeepLink({
    required this.kind,
    required this.name,
    this.params = const {},
  });

  static HermesDeepLink? parse(Uri uri) {
    if (uri.scheme != 'hermes' && uri.scheme != 'hermes-dev') return null;
    final kind = uri.host.trim().toLowerCase();
    if (kind.isEmpty) return null;
    final name = uri.pathSegments.join('/').trim();
    return HermesDeepLink(
      kind: kind,
      name: name,
      params: Map.unmodifiable(uri.queryParameters),
    );
  }
}

sealed class DeepLinkAction {
  const DeepLinkAction();
}

class BlueprintDeepLinkAction extends DeepLinkAction {
  final String name;
  final Map<String, String> values;

  const BlueprintDeepLinkAction(this.name, this.values);

  String get command {
    String quote(String value) => RegExp(r'\s').hasMatch(value)
        ? '"${value.replaceAll('"', r'\"')}"'
        : value;
    final slots = values.entries
        .map((entry) => '${entry.key}=${quote(entry.value)}')
        .join(' ');
    return '/blueprint $name${slots.isEmpty ? '' : ' $slots'}';
  }
}

class PluginInstallDeepLinkAction extends DeepLinkAction {
  final String identifier;
  final bool enable;
  final bool force;
  final String? legacyKind;

  const PluginInstallDeepLinkAction({
    required this.identifier,
    required this.enable,
    required this.force,
    this.legacyKind,
  });
}

class McpInstallDeepLinkAction extends DeepLinkAction {
  final McpInstallRequest request;

  const McpInstallDeepLinkAction(this.request);
}

class SessionDeepLinkAction extends DeepLinkAction {
  final String sessionId;
  final String? profile;
  final String? connectionId;

  const SessionDeepLinkAction({
    required this.sessionId,
    this.profile,
    this.connectionId,
  });
}

class RejectedDeepLinkAction extends DeepLinkAction {
  final String reason;

  const RejectedDeepLinkAction(this.reason);
}

class McpInstallRequest {
  final String name;
  final Map<String, dynamic> config;
  final String transport;

  const McpInstallRequest({
    required this.name,
    required this.config,
    required this.transport,
  });
}

const _maxMcpConfigBytes = 32 * 1024;
final _mcpNamePattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');

bool _truthy(String? value, {bool fallback = false}) {
  if (value == null || value.isEmpty) return fallback;
  return const {'1', 'true', 'yes'}.contains(value.trim().toLowerCase());
}

DeepLinkAction resolveDeepLink(HermesDeepLink link) {
  if (link.kind == 'blueprint' && link.name.isNotEmpty) {
    return BlueprintDeepLinkAction(link.name, link.params);
  }
  if (link.kind == 'session' && link.name.isNotEmpty) {
    return SessionDeepLinkAction(
      sessionId: link.name,
      profile: link.params['profile'],
      connectionId: link.params['connection'],
    );
  }
  if (link.kind == 'mcp' && link.name == 'install') {
    return _parseMcp(link.params);
  }

  final identifier =
      (link.params['repo'] ?? link.params['identifier'] ?? link.name).trim();
  if (link.kind == 'plugin' &&
      link.name == 'install' &&
      identifier.isNotEmpty) {
    return PluginInstallDeepLinkAction(
      identifier: identifier,
      enable: _truthy(link.params['enable'], fallback: true),
      force: _truthy(link.params['force']),
    );
  }
  if ((link.kind == 'plugin-agent' || link.kind == 'plugin-desktop') &&
      identifier.isNotEmpty) {
    return PluginInstallDeepLinkAction(
      identifier: identifier,
      enable: _truthy(link.params['enable'], fallback: true),
      force: _truthy(link.params['force']),
      legacyKind: link.kind,
    );
  }
  return RejectedDeepLinkAction(runtimeL10n.deepLinkUnsupported);
}

DeepLinkAction _parseMcp(Map<String, String> params) {
  final name = params['name'] ?? '';
  if (!_mcpNamePattern.hasMatch(name)) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpNameInvalid);
  }
  final encoded = params['config'] ?? '';
  if (encoded.isEmpty) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpConfigMissing);
  }
  final maxEncoded = ((_maxMcpConfigBytes * 4) / 3).ceil() + 4;
  if (encoded.length > maxEncoded) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpConfigTooLarge);
  }

  late final Uint8List bytes;
  try {
    final normalized = base64Url.normalize(
      encoded.replaceAll(RegExp(r'\s'), ''),
    );
    bytes = base64Url.decode(normalized);
  } catch (_) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpEncodingInvalid);
  }
  if (bytes.length > _maxMcpConfigBytes) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpConfigTooLarge);
  }

  dynamic decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
  } catch (_) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpJsonInvalid);
  }
  if (decoded is! Map) {
    return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpObjectRequired);
  }
  final config = decoded.cast<String, dynamic>();
  final urlValue = config['url'];
  final commandValue = config['command'];
  if (urlValue is String) {
    if (config.containsKey('command')) {
      return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpUrlCommandConflict);
    }
    final uri = Uri.tryParse(urlValue);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpHttpOnly);
    }
    return McpInstallDeepLinkAction(
      McpInstallRequest(name: name, config: config, transport: 'http'),
    );
  }
  if (commandValue is String && commandValue.trim().isNotEmpty) {
    return McpInstallDeepLinkAction(
      McpInstallRequest(name: name, config: config, transport: 'stdio'),
    );
  }
  return RejectedDeepLinkAction(runtimeL10n.deepLinkMcpEndpointMissing);
}

class DeepLinkService {
  DeepLinkService({AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks() {
    initialized = _start();
  }

  final AppLinks _appLinks;
  StreamSubscription<Uri>? _subscription;
  HermesDeepLink? _pending;
  ValueChanged<HermesDeepLink>? _handler;
  late final Future<void> initialized;

  set handler(ValueChanged<HermesDeepLink>? value) {
    _handler = value;
    final pending = _pending;
    if (value != null && pending != null) {
      _pending = null;
      value(pending);
    }
  }

  Future<void> _start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _accept(initial);
      _subscription = _appLinks.uriLinkStream.listen(_accept, onError: (_) {});
    } catch (_) {
      // Unsupported test/desktop platforms keep the rest of the app usable.
    }
  }

  void _accept(Uri uri) {
    final parsed = HermesDeepLink.parse(uri);
    if (parsed == null) return;
    final callback = _handler;
    if (callback == null) {
      _pending = parsed;
    } else {
      callback(parsed);
    }
  }

  void dispose() {
    _handler = null;
    _subscription?.cancel();
  }
}
