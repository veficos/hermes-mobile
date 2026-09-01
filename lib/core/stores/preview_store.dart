library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../connections/connection_registry.dart';
import '../../l10n/runtime_l10n.dart';
import 'connection_store.dart';

abstract interface class PreviewDriver {
  Future<Map<String, dynamic>> read({int? start, int? count});
  Future<Map<String, dynamic>> act(Map<String, dynamic> action);
  Future<Map<String, dynamic>> tour(Map<String, dynamic> action);
}

@immutable
class PreviewTab {
  const PreviewTab({
    required this.id,
    required this.title,
    this.url,
    this.html,
    this.sessionId,
    this.owner,
  });

  final String id;
  final String title;
  final String? url;
  final String? html;
  final String? sessionId;
  final OwnerRoute? owner;
}

class PreviewStore extends ChangeNotifier {
  final ConnectionStore connection;
  StreamSubscription<RoutedGatewayEvent>? _events;
  PreviewDriver? _driver;
  final Map<String, PreviewDriver> _tabDrivers = {};
  String? _url, _html, _sessionId;
  String _title = runtimeL10n.previewTitle;
  OwnerRoute? _owner;
  final List<PreviewTab> _tabs = <PreviewTab>[];
  String? _activeTabId;

  PreviewStore(this.connection) {
    _events = connection.routedEvents.listen(_onGatewayEvent);
  }
  String? get url => _url;
  String? get html => _html;
  String get title => _title;
  bool get hasContent =>
      (_url?.isNotEmpty ?? false) || (_html?.isNotEmpty ?? false);
  List<PreviewTab> get tabs => List.unmodifiable(_tabs);
  PreviewTab? get activeTab {
    final id = _activeTabId;
    if (id == null) return null;
    final index = _tabs.indexWhere((tab) => tab.id == id);
    return index < 0 ? null : _tabs[index];
  }

  void attachDriver(PreviewDriver driver, {String? tabId}) {
    if (tabId == null) {
      _driver = driver;
    } else {
      _tabDrivers[tabId] = driver;
    }
  }

  void detachDriver(PreviewDriver driver, {String? tabId}) {
    if (tabId == null) {
      if (identical(_driver, driver)) _driver = null;
    } else if (identical(_tabDrivers[tabId], driver)) {
      _tabDrivers.remove(tabId);
    }
  }

  void openUrl(
    String url, {
    String? title,
    String? sessionId,
    OwnerRoute? owner,
  }) {
    final resolvedTitle = title ?? runtimeL10n.previewTitle;
    final tab = PreviewTab(
      id: 'url:$url',
      title: resolvedTitle,
      url: url,
      sessionId: sessionId,
      owner: owner,
    );
    _upsertTab(tab);
    _url = url;
    _html = null;
    _title = resolvedTitle;
    _sessionId = sessionId;
    _owner = owner;
    notifyListeners();
  }

  void openHtml(
    String html, {
    String? title,
    String? sessionId,
    OwnerRoute? owner,
  }) {
    final resolvedTitle = title ?? runtimeL10n.previewTitle;
    final tab = PreviewTab(
      id: 'html:${sessionId ?? ''}:${html.hashCode}',
      title: resolvedTitle,
      html: html,
      sessionId: sessionId,
      owner: owner,
    );
    _upsertTab(tab);
    _html = html;
    _url = null;
    _title = resolvedTitle;
    _sessionId = sessionId;
    _owner = owner;
    notifyListeners();
  }

  void _upsertTab(PreviewTab tab) {
    final index = _tabs.indexWhere((item) => item.id == tab.id);
    if (index < 0) {
      _tabs.add(tab);
    } else {
      _tabs[index] = tab;
    }
    _activeTabId = tab.id;
  }

  void activate(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs[index];
    _activeTabId = id;
    _url = tab.url;
    _html = tab.html;
    _title = tab.title;
    _sessionId = tab.sessionId;
    _owner = tab.owner;
    notifyListeners();
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final wasActive = _activeTabId == id;
    _tabs.removeAt(index);
    _tabDrivers.remove(id);
    if (wasActive) {
      if (_tabs.isEmpty) {
        _clearActive();
      } else {
        activate(_tabs[index.clamp(0, _tabs.length - 1)].id);
        return;
      }
    }
    notifyListeners();
  }

  void clear() {
    _tabs.clear();
    _tabDrivers.clear();
    _clearActive();
    notifyListeners();
  }

  void _clearActive() {
    _url = null;
    _html = null;
    _sessionId = null;
    _owner = null;
    _title = runtimeL10n.previewTitle;
    _activeTabId = null;
  }

  Future<void> _onGatewayEvent(RoutedGatewayEvent routed) async {
    final event = routed.event;
    if (!event.type.startsWith('preview.') && event.type != 'tour.request') {
      return;
    }
    final p = event.payload;
    final route = OwnerRoute(
      connectionId: routed.route.connectionId,
      profile: p['profile']?.toString(),
    );
    if (event.type == 'preview.open.request') {
      final url = p['url']?.toString() ?? '',
          html = p['html']?.toString() ?? '';
      if (url.isNotEmpty) {
        openUrl(
          url,
          title: p['title']?.toString() ?? runtimeL10n.previewTitle,
          sessionId: event.sessionId,
          owner: route,
        );
      }
      if (url.isEmpty && html.isNotEmpty) {
        openHtml(
          html,
          title: p['title']?.toString() ?? runtimeL10n.previewTitle,
          sessionId: event.sessionId,
          owner: route,
        );
      }
      await _respond(route, 'preview.open.respond', p, {
        'success': url.isNotEmpty || html.isNotEmpty,
      });
      return;
    }
    final routeMatchesActive =
        (_owner == null || _owner!.connectionId == route.connectionId) &&
        (_sessionId == null ||
            event.sessionId == null ||
            _sessionId == event.sessionId);
    final routedTab = _tabs.where((tab) {
      final ownerMatches =
          tab.owner == null || tab.owner!.connectionId == route.connectionId;
      final sessionMatches = event.sessionId == null
          ? tab.sessionId == null
          : tab.sessionId == event.sessionId;
      return ownerMatches && sessionMatches;
    }).lastOrNull;
    final driver = routedTab == null
        ? (routeMatchesActive ? _driver : null)
        : _tabDrivers[routedTab.id] ??
              (routedTab.id == _activeTabId ? _driver : null);
    Map<String, dynamic> result;
    if (driver == null) {
      result = {
        'success': false,
        'error': event.type == 'tour.request'
            ? 'Tours only run in the session the user is looking at.'
            : 'The in-app browser only serves the session the user is looking at.',
      };
    } else {
      try {
        if (event.type == 'tour.request') {
          result = p['surface']?.toString() == 'preview'
              ? await driver.tour(p)
              : {
                  'success': false,
                  'error':
                      'Hermes Mobile tours currently target the live preview surface, not the native app surface.',
                };
        } else {
          result = event.type == 'preview.read.request'
              ? await driver.read(
                  start: (p['start'] as num?)?.toInt(),
                  count: (p['count'] as num?)?.toInt(),
                )
              : await driver.act(p);
        }
      } catch (e) {
        result = {'success': false, 'error': '$e'};
      }
    }
    final responseMethod = event.type == 'tour.request'
        ? 'tour.respond'
        : event.type.replaceFirst('.request', '.respond');
    await _respond(route, responseMethod, p, result);
  }

  Future<void> _respond(
    OwnerRoute route,
    String method,
    Map<String, dynamic> p,
    Map<String, dynamic> result,
  ) async {
    final id = p['request_id']?.toString() ?? '';
    if (id.isEmpty) return;
    await connection.requestForOwner(route, method, {
      'request_id': id,
      'text': jsonEncode(result),
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }
}
