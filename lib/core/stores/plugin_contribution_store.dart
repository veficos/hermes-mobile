library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../connections/connection_registry.dart';
import '../api_client.dart';
import '../plugin_contributions.dart';
import '../ws_connect.dart';
import 'notification_store.dart';
import 'connection_store.dart';
import '../../l10n/runtime_l10n.dart';

enum MobileContributionArea {
  navigation,
  command,
  settings,
  composer,
  detail,
  transcript,
  pane,
}

@visibleForTesting
Uri pluginContributionSocketUri(
  ApiClient api, {
  required String pluginId,
  required String socketPath,
}) {
  final base = Uri.parse(api.baseUrl);
  final pathSegments = <String>[
    if (!api.directGateway) 'api',
    if (!api.directGateway) 'v1' else 'api',
    'plugins',
    pluginId,
    ...socketPath.split('/').where((segment) => segment.isNotEmpty),
  ];
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    pathSegments: pathSegments,
    queryParameters: {'token': api.apiKey},
  );
}

class PluginResultField {
  final String label;
  final String value;

  const PluginResultField(this.label, this.value);
}

/// Bounded, host-rendered representation of an action response. Plugins return
/// data only; the mobile host decides how it is displayed and which links are
/// safe to open.
class PluginActionResult {
  static const _maxTitleLength = 160;
  static const _maxValueLength = 20000;
  static const _maxFields = 64;
  static const _maxItems = 100;

  final String? title;
  final String? message;
  final List<PluginResultField> fields;
  final List<Object?> items;
  final Uri? url;
  final Map<String, dynamic> raw;
  final bool hasStructuredContent;
  final bool acknowledgementOnly;

  const PluginActionResult._({
    required this.title,
    required this.message,
    required this.fields,
    required this.items,
    required this.url,
    required this.raw,
    required this.hasStructuredContent,
    required this.acknowledgementOnly,
  });

  factory PluginActionResult.fromJson(Map<String, dynamic> json) {
    String? text(Object? value, int maxLength) {
      if (value == null) return null;
      final normalized = value.toString().trim();
      if (normalized.isEmpty) return null;
      return normalized.length <= maxLength
          ? normalized
          : '${normalized.substring(0, maxLength)}...';
    }

    final fields = <PluginResultField>[];
    final rawFields = json['fields'];
    if (rawFields is Map) {
      for (final entry in rawFields.entries.take(_maxFields)) {
        final label = text(entry.key, _maxTitleLength);
        final value = text(entry.value, _maxValueLength);
        if (label != null && value != null) {
          fields.add(PluginResultField(label, value));
        }
      }
    } else if (rawFields is List) {
      for (final rawField in rawFields.take(_maxFields)) {
        if (rawField is! Map) continue;
        final label = text(
          rawField['label'] ?? rawField['name'] ?? rawField['key'],
          _maxTitleLength,
        );
        final value = text(
          rawField['value'] ?? rawField['text'],
          _maxValueLength,
        );
        if (label != null && value != null) {
          fields.add(PluginResultField(label, value));
        }
      }
    }

    final rawItems = json['items'];
    final items = rawItems is List
        ? List<Object?>.unmodifiable(rawItems.take(_maxItems))
        : const <Object?>[];
    final rawUrl = text(json['url'], 2048);
    final parsedUrl = rawUrl == null ? null : Uri.tryParse(rawUrl);
    final url =
        parsedUrl != null &&
            parsedUrl.host.isNotEmpty &&
            {'http', 'https'}.contains(parsedUrl.scheme.toLowerCase())
        ? parsedUrl
        : parsedUrl != null &&
              parsedUrl.scheme.toLowerCase() == 'mailto' &&
              parsedUrl.path.isNotEmpty
        ? parsedUrl
        : null;
    final title = text(json['title'], _maxTitleLength);
    final message = text(json['message'], _maxValueLength);
    final structured =
        title != null ||
        message != null ||
        fields.isNotEmpty ||
        items.isNotEmpty ||
        url != null;
    final acknowledgementOnly =
        !structured &&
        json.isNotEmpty &&
        json.entries.every(
          (entry) =>
              const {'ok', 'success'}.contains(entry.key) &&
              entry.value == true,
        );
    return PluginActionResult._(
      title: title,
      message: message,
      fields: List.unmodifiable(fields),
      items: items,
      url: url,
      raw: Map.unmodifiable(json),
      hasStructuredContent: structured,
      acknowledgementOnly: acknowledgementOnly,
    );
  }

  bool get shouldPresent => raw.isNotEmpty && !acknowledgementOnly;
  bool get usesRawFallback => shouldPresent && !hasStructuredContent;
}

class MobilePluginContribution {
  final String id, pluginId, title, description, icon;
  final String? titleKey, descriptionKey;
  final MobileContributionArea area;
  final int order;
  final Map<String, dynamic> action;
  final Set<String> platforms;
  final OwnerRoute owner;

  /// One of HermesSemantic's named tones (green/orange/red/blue/gray/purple)
  /// — lets a contribution signal category/severity without a raw color.
  final String? color;

  /// Optional action evaluated automatically (on load and on refresh) to
  /// compute a live badge — mirrors desktop's status-bar "count" pills
  /// (e.g. kanban's open-task count) for a server-executed plugin.
  final Map<String, dynamic>? badgeAction;
  final MobilePluginView view;
  final PluginLocaleBundle locales;

  const MobilePluginContribution({
    required this.id,
    required this.pluginId,
    required this.area,
    required this.title,
    this.titleKey,
    this.description = '',
    this.descriptionKey,
    this.icon = 'extension',
    this.order = 0,
    this.action = const {},
    this.platforms = const {},
    required this.owner,
    this.color,
    this.badgeAction,
    this.view = const MobilePluginView(),
    this.locales = const PluginLocaleBundle({}),
  });

  String get namespacedId => '$pluginId:$id';

  String localizedTitle(Locale locale) =>
      locales.resolve(locale, titleKey, title);

  String localizedDescription(Locale locale) =>
      locales.resolve(locale, descriptionKey, description);

  String localize(Locale locale, String? key, String fallback) =>
      locales.resolve(locale, key, fallback);

  factory MobilePluginContribution.fromJson(
    String pluginId,
    Map<String, dynamic> json,
    OwnerRoute owner,
    PluginLocaleBundle pluginLocales,
  ) {
    final rawArea = json['area']?.toString() ?? 'detail';
    return MobilePluginContribution(
      id: json['id']?.toString() ?? '',
      pluginId: pluginId,
      area: MobileContributionArea.values.firstWhere(
        (value) => value.name == rawArea,
        orElse: () => MobileContributionArea.detail,
      ),
      title: json['title']?.toString() ?? '',
      titleKey: json['title_key']?.toString(),
      description: json['description']?.toString() ?? '',
      descriptionKey: json['description_key']?.toString(),
      icon: json['icon']?.toString() ?? 'extension',
      order: (json['order'] as num?)?.toInt() ?? 0,
      action: (json['action'] as Map?)?.cast<String, dynamic>() ?? const {},
      platforms: (json['platforms'] as List? ?? const [])
          .map((e) => '$e')
          .toSet(),
      owner: owner,
      color: json['color']?.toString(),
      badgeAction: (json['badge_action'] as Map?)?.cast<String, dynamic>(),
      view: MobilePluginView.fromJson(json['view']),
      locales: _mergeLocales(
        pluginLocales,
        PluginLocaleBundle.fromJson(json['locales']),
      ),
    );
  }

  static PluginLocaleBundle _mergeLocales(
    PluginLocaleBundle base,
    PluginLocaleBundle override,
  ) {
    if (override.values.isEmpty) return base;
    if (base.values.isEmpty) return override;
    final merged = <String, Map<String, String>>{
      for (final entry in base.values.entries) entry.key: {...entry.value},
    };
    for (final entry in override.values.entries) {
      merged[entry.key] = {...?merged[entry.key], ...entry.value};
    }
    return PluginLocaleBundle(
      Map.unmodifiable({
        for (final entry in merged.entries)
          entry.key: Map.unmodifiable(entry.value),
      }),
    );
  }
}

/// Safe declarative adapter: plugins contribute metadata and host-mediated
/// actions, never executable Flutter or JavaScript payloads.
class PluginContributionStore extends ChangeNotifier {
  final ConnectionStore connection;
  final NotificationStore? notifications;
  List<MobilePluginContribution> contributions = const [];

  /// Last invoke() result per contribution (namespacedId), so a surface can
  /// render more than a fire-and-forget action — e.g. a returned message or
  /// count. Cleared per inventory refresh only when the contribution itself
  /// disappears.
  Map<String, Map<String, dynamic>> results = const {};

  /// Live badge text per contribution, refreshed alongside the inventory
  /// from each contribution's optional `badgeAction`.
  Map<String, String> badges = const {};

  /// Latest host-rendered view payload per contribution. Polling updates this
  /// map without reopening the active sheet.
  Map<String, Map<String, dynamic>> viewData = const {};

  bool _loading = false;
  ConnectionId? _loadedConnection;
  final Map<String, Timer> _pollers = {};
  final Map<String, WebSocketChannel> _sockets = {};
  final Map<String, StreamSubscription<dynamic>> _socketSubscriptions = {};
  final Map<String, Timer> _socketReconnects = {};
  final Map<String, int> _socketAttempts = {};
  Future<void> _storageTail = Future.value();

  PluginContributionStore(this.connection, {this.notifications}) {
    connection.addListener(_onConnectionChanged);
    _onConnectionChanged();
  }

  void _onConnectionChanged() {
    if (!connection.isConnected || _loading) return;
    final id = connection.activeConnectionId;
    if (_loadedConnection == id) return;
    _loading = true;
    connection
        .listPlugins()
        .then((plugins) {
          _loadedConnection = id;
          adaptPluginInventory(plugins);
        })
        .catchError((_) {})
        .whenComplete(() => _loading = false);
  }

  List<MobilePluginContribution> forArea(MobileContributionArea area) =>
      contributions
          .where(
            (item) =>
                item.area == area &&
                (item.platforms.isEmpty ||
                    item.platforms.contains(defaultTargetPlatform.name) ||
                    item.platforms.contains('mobile')),
          )
          .toList(growable: false);

  void adaptPluginInventory(
    List<Map<String, dynamic>> plugins, {
    OwnerRoute? owner,
  }) {
    owner ??= OwnerRoute(connectionId: connection.activeConnectionId);
    final next = <MobilePluginContribution>[];
    for (final plugin in plugins) {
      if (plugin['enabled'] != true) continue;
      final pluginId = (plugin['id'] ?? plugin['name'] ?? plugin['key'] ?? '')
          .toString();
      final pluginLocales = PluginLocaleBundle.fromJson(
        plugin['mobile_locales'] ?? plugin['locales'],
      );
      final raw = plugin['mobile_contributions'] ?? plugin['contributions'];
      if (pluginId.isEmpty || raw is! List) continue;
      for (final item in raw) {
        if (item is! Map) continue;
        final contribution = MobilePluginContribution.fromJson(
          pluginId,
          item.cast<String, dynamic>(),
          owner,
          pluginLocales,
        );
        if (contribution.id.isEmpty ||
            (contribution.title.isEmpty && contribution.titleKey == null)) {
          continue;
        }
        next.removeWhere(
          (old) => old.namespacedId == contribution.namespacedId,
        );
        next.add(contribution);
      }
    }
    next.sort(
      (a, b) => a.order != b.order
          ? a.order.compareTo(b.order)
          : a.namespacedId.compareTo(b.namespacedId),
    );
    contributions = List.unmodifiable(next);
    final retainedIds = next.map((item) => item.namespacedId).toSet();
    results = Map.unmodifiable(
      Map.fromEntries(
        results.entries.where((entry) => retainedIds.contains(entry.key)),
      ),
    );
    badges = Map.unmodifiable(
      Map.fromEntries(
        badges.entries.where((entry) => retainedIds.contains(entry.key)),
      ),
    );
    viewData = Map.unmodifiable(
      Map.fromEntries(
        viewData.entries.where((entry) => retainedIds.contains(entry.key)),
      ),
    );
    _syncPollers();
    _syncSockets();
    notifyListeners();
    unawaited(_loadBadges());
  }

  void _syncSockets() {
    final wanted = <String, MobilePluginContribution>{
      for (final item in contributions)
        if (item.view.socketPath != null) item.namespacedId: item,
    };
    for (final id in _sockets.keys.toList()) {
      if (!wanted.containsKey(id)) _closeSocket(id);
    }
    for (final id in _socketReconnects.keys.toList()) {
      if (!wanted.containsKey(id)) _socketReconnects.remove(id)?.cancel();
    }
    for (final entry in wanted.entries) {
      if (_sockets.containsKey(entry.key) ||
          _socketReconnects.containsKey(entry.key)) {
        continue;
      }
      _connectSocket(entry.value);
    }
  }

  void _connectSocket(MobilePluginContribution item) {
    final id = item.namespacedId;
    try {
      final api = connection.runtimeFor(item.owner).api;
      // OAuth WebSocket tickets are single-use and gateway-managed. Keep the
      // polling fallback rather than attempting to reuse an access token.
      if (api.accessTokenProvider != null) return;
      final uri = pluginContributionSocketUri(
        api,
        pluginId: item.pluginId,
        socketPath: item.view.socketPath!,
      );
      final socket = connectWs(uri, headers: api.extraHeaders);
      _sockets[id] = socket;
      _socketSubscriptions[id] = socket.stream.listen(
        (raw) => _onSocketFrame(item, raw),
        onError: (_) => _scheduleSocketReconnect(item),
        onDone: () => _scheduleSocketReconnect(item),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleSocketReconnect(item);
    }
  }

  void _onSocketFrame(MobilePluginContribution item, Object? raw) {
    _socketAttempts[item.namespacedId] = 0;
    try {
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is Map) {
        final data = decoded.cast<String, dynamic>();
        final payload = data['data'];
        final candidate = payload is Map
            ? payload.cast<String, dynamic>()
            : data;
        if (candidate.containsKey(item.view.itemsKey) ||
            candidate.containsKey('values') ||
            candidate.containsKey('inputs')) {
          viewData = {...viewData, item.namespacedId: candidate};
          notifyListeners();
          return;
        }
      }
    } catch (_) {
      return;
    }
    unawaited(loadView(item, silent: true));
  }

  void _scheduleSocketReconnect(MobilePluginContribution item) {
    final id = item.namespacedId;
    _closeSocket(id, keepReconnect: true);
    if (!contributions.any((entry) => entry.namespacedId == id) ||
        _socketReconnects[id]?.isActive == true) {
      return;
    }
    final attempt = _socketAttempts[id] ?? 0;
    _socketAttempts[id] = attempt + 1;
    final seconds = (1 << attempt.clamp(0, 5)).clamp(1, 30);
    _socketReconnects[id] = Timer(Duration(seconds: seconds), () {
      _socketReconnects.remove(id);
      if (contributions.any((entry) => entry.namespacedId == id)) {
        _connectSocket(item);
      }
    });
  }

  void _closeSocket(String id, {bool keepReconnect = false}) {
    _socketSubscriptions.remove(id)?.cancel();
    _sockets.remove(id)?.sink.close();
    if (!keepReconnect) {
      _socketReconnects.remove(id)?.cancel();
      _socketAttempts.remove(id);
    }
  }

  void _syncPollers() {
    final wanted = <String, MobilePluginContribution>{
      for (final item in contributions)
        if (item.view.pollSeconds != null &&
            item.view.loadAction != null &&
            _safeAutomaticAction(item.view.loadAction!))
          item.namespacedId: item,
    };
    for (final id in _pollers.keys.toList()) {
      if (!wanted.containsKey(id)) _pollers.remove(id)?.cancel();
    }
    for (final entry in wanted.entries) {
      if (_pollers.containsKey(entry.key)) continue;
      final item = entry.value;
      _pollers[entry.key] = Timer.periodic(
        Duration(seconds: item.view.pollSeconds!),
        (_) => unawaited(loadView(item, silent: true)),
      );
    }
  }

  Future<void> _loadBadges() async {
    final withBadge = contributions.where((item) => item.badgeAction != null);
    for (final item in withBadge) {
      if (!_safeAutomaticAction(item.badgeAction!)) continue;
      try {
        final result = await _dispatch(item.badgeAction!, item);
        final value = result['badge'] ?? result['count'];
        if (value == null) continue;
        badges = {...badges, item.namespacedId: value.toString()};
        notifyListeners();
      } catch (_) {
        // Cosmetic — a failed badge fetch just leaves the previous value.
      }
    }
  }

  bool _safeAutomaticAction(Map<String, dynamic> action) {
    final kind = action['kind']?.toString().trim().toLowerCase();
    if (kind == 'rest') {
      return (action['method'] ?? 'GET').toString().toUpperCase() == 'GET';
    }
    if (kind != 'gateway') return false;
    final method = action['method']?.toString().trim().toLowerCase() ?? '';
    final verb = method.split('.').lastOrNull ?? '';
    final params = (action['params'] as Map?)?.cast<String, dynamic>();
    final requested = params?['action']?.toString().trim().toLowerCase();
    const reads = {'get', 'list', 'show', 'status'};
    return reads.contains(verb) ||
        (verb == 'manage' && reads.contains(requested));
  }

  /// Run one contribution's `action` and remember the result for surfaces
  /// that want to render more than fire-and-forget (a badge, a message).
  Future<Map<String, dynamic>> invoke(MobilePluginContribution item) async {
    return invokeAction(item, item.action);
  }

  Future<Map<String, dynamic>> invokeAction(
    MobilePluginContribution item,
    Map<String, dynamic> action, {
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? itemData,
    bool rememberResult = true,
  }) async {
    final result = await _dispatch(
      action,
      item,
      inputs: inputs,
      itemData: itemData,
    );
    if (!rememberResult) return result;
    results = {...results, item.namespacedId: result};
    notifyListeners();
    return result;
  }

  Future<Map<String, dynamic>> loadView(
    MobilePluginContribution item, {
    bool silent = false,
  }) async {
    final action = item.view.loadAction;
    if (action == null || !_safeAutomaticAction(action)) {
      if (silent) return viewData[item.namespacedId] ?? const {};
      throw StateError(runtimeL10n.pluginLoadActionReadOnly);
    }
    try {
      final result = await _dispatch(action, item);
      viewData = {...viewData, item.namespacedId: result};
      notifyListeners();
      return result;
    } catch (_) {
      if (silent) return viewData[item.namespacedId] ?? const {};
      rethrow;
    }
  }

  String _storageKey(MobilePluginContribution item, String key) {
    final safeKey = key.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    return 'hm_plugin_v1.${item.owner.connectionId.value}.'
        '${item.owner.profile ?? '_'}.${item.pluginId}.$safeKey';
  }

  Future<Map<String, dynamic>> readStorage(
    MobilePluginContribution item,
    String key,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey(item, key));
      final decoded = raw == null ? null : jsonDecode(raw);
      return decoded is Map
          ? decoded.cast<String, dynamic>()
          : const <String, dynamic>{};
    } catch (_) {
      return const {};
    }
  }

  Future<void> writeStorage(
    MobilePluginContribution item,
    String key,
    Map<String, dynamic> value,
  ) {
    final encoded = jsonEncode(value);
    final write = _storageTail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey(item, key), encoded);
    });
    _storageTail = write;
    return write;
  }

  Future<void> removeStorage(MobilePluginContribution item, String key) {
    final write = _storageTail.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey(item, key));
    });
    _storageTail = write;
    return write;
  }

  Future<void> flushStorage() => _storageTail;

  Future<Map<String, dynamic>> _dispatch(
    Map<String, dynamic> action,
    MobilePluginContribution contribution, {
    Map<String, dynamic>? inputs,
    Map<String, dynamic>? itemData,
  }) async {
    final kind = action['kind']?.toString() ?? '';
    if (kind == 'gateway') {
      final method = action['method']?.toString() ?? '';
      if (method.isEmpty) throw StateError(runtimeL10n.pluginMethodMissing);
      final params = <String, dynamic>{
        ...(action['params'] as Map?)?.cast<String, dynamic>() ?? const {},
        'inputs': ?inputs,
        'item': ?itemData,
      };
      return connection.requestForOwner(contribution.owner, method, params);
    }
    if (kind == 'rest') {
      final path =
          action['path']?.toString().replaceFirst(RegExp(r'^/+'), '') ?? '';
      final segments = path.split('/');
      if (path.isEmpty ||
          segments.any((segment) => segment.isEmpty || segment == '..')) {
        throw StateError(runtimeL10n.pluginPathInvalid);
      }
      final api = connection.runtimeFor(contribution.owner).api;
      final encodedPath = segments.map(Uri.encodeComponent).join('/');
      final route =
          '/api/v1/plugins/${Uri.encodeComponent(contribution.pluginId)}/$encodedPath';
      final query = (action['query'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
      final baseBody = (action['body'] as Map?)?.cast<String, dynamic>();
      final body = inputs == null && itemData == null
          ? baseBody
          : <String, dynamic>{
              ...?baseBody,
              'inputs': ?inputs,
              'item': ?itemData,
            };
      final method = (action['method'] ?? 'POST').toString().toUpperCase();
      final result = switch (method) {
        'GET' => await api.get(route, query: query),
        'POST' => await api.post(route, query: query, body: body),
        'PUT' => await api.put(route, query: query, body: body),
        'PATCH' => await api.patch(route, query: query, body: body),
        'DELETE' => await api.delete(route, query: query, body: body),
        _ => throw StateError(runtimeL10n.pluginMethodUnsupported(method)),
      };
      return result is Map
          ? result.cast<String, dynamic>()
          : {'result': result};
    }
    // Device-local conveniences (desktop's `ctx.os`) — handled entirely on
    // the client, no plugin code runs here, just a fixed, safe verb.
    if (kind == 'open-external') {
      final url = action['url']?.toString() ?? '';
      final uri = Uri.tryParse(url);
      if (uri == null || url.isEmpty) {
        throw StateError(runtimeL10n.pluginUrlInvalid);
      }
      if (!{'http', 'https', 'mailto'}.contains(uri.scheme.toLowerCase())) {
        throw StateError(runtimeL10n.pluginUrlSchemeUnsupported);
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw StateError(runtimeL10n.pluginLinkOpenFailed);
      return {'ok': true};
    }
    if (kind == 'clipboard') {
      final text = action['text']?.toString() ?? '';
      await Clipboard.setData(ClipboardData(text: text));
      return {'ok': true};
    }
    if (kind == 'notify') {
      final title = action['title']?.toString().trim() ?? '';
      final message = action['message']?.toString().trim() ?? '';
      if (title.isEmpty || message.isEmpty) {
        throw StateError(runtimeL10n.pluginNotificationFieldsMissing);
      }
      final notificationStore = notifications;
      if (notificationStore == null) {
        throw StateError(runtimeL10n.pluginNotificationUnavailable);
      }
      final rawKind = action['level']?.toString().trim().toLowerCase();
      final notificationKind = NotificationKind.values.firstWhere(
        (value) => value.name == rawKind,
        orElse: () => NotificationKind.info,
      );
      final key = action['key']?.toString().trim();
      notificationStore.addExternal(
        key: key?.isNotEmpty == true
            ? 'plugin:${contribution.pluginId}:$key'
            : 'plugin:${contribution.namespacedId}:${DateTime.now().millisecondsSinceEpoch}',
        kind: notificationKind,
        title: title,
        message: message,
        connectionId: contribution.owner.connectionId.value,
        profile: contribution.owner.profile,
      );
      return {'ok': true};
    }
    throw StateError(runtimeL10n.pluginActionUnsupported(kind));
  }

  @override
  void dispose() {
    for (final timer in _pollers.values) {
      timer.cancel();
    }
    _pollers.clear();
    for (final id in _sockets.keys.toList()) {
      _closeSocket(id);
    }
    for (final timer in _socketReconnects.values) {
      timer.cancel();
    }
    _socketReconnects.clear();
    connection.removeListener(_onConnectionChanged);
    super.dispose();
  }
}
