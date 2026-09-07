library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../api_client.dart';
import '../connections/connection_registry.dart';
import '../gateway.dart';
import '../preview_document.dart';
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
    this.document,
  });

  final String id;
  final String title;
  final String? url;
  final String? html;
  final String? sessionId;
  final OwnerRoute? owner;
  final PreviewDocument? document;
}

enum PreviewRestartPhase { idle, starting, running, completed, failed }

@immutable
class PreviewRestartStatus {
  const PreviewRestartStatus({
    this.taskId,
    this.phase = PreviewRestartPhase.idle,
    this.text = '',
  });

  final String? taskId;
  final PreviewRestartPhase phase;
  final String text;

  bool get busy =>
      phase == PreviewRestartPhase.starting ||
      phase == PreviewRestartPhase.running;
}

typedef PreviewApiResolver = ApiClient? Function(OwnerRoute? owner);

class PreviewStore extends ChangeNotifier {
  static const int textPreviewMaxBytes = 512 * 1024;
  // A base64 PDF occupies ~1.33x its bytes and is decoded again by WebView.
  // Keep automatic opens below a phone-friendly ceiling; explicit force still
  // permits larger documents when the user accepts the memory cost.
  static const int automaticPdfMaxBytes = 8 * 1024 * 1024;
  final ConnectionStore connection;
  final PreviewApiResolver? apiResolver;
  StreamSubscription<RoutedGatewayEvent>? _events;
  PreviewDriver? _driver;
  final Map<String, PreviewDriver> _tabDrivers = {};
  String? _url, _html, _sessionId;
  String _title = runtimeL10n.previewTitle;
  OwnerRoute? _owner;
  final List<PreviewTab> _tabs = <PreviewTab>[];
  final Map<String, int> _fileLoadGenerations = <String, int>{};
  final Map<String, Timer> _fileReloadTimers = <String, Timer>{};
  final Map<String, String> _fileRevisions = <String, String>{};
  final Map<String, PreviewRestartStatus> _restartByTab =
      <String, PreviewRestartStatus>{};
  final Map<String, String> _restartTabByTask = <String, String>{};
  String? _activeTabId;
  late ConnectionId _activeConnectionId;
  OwnerRoute? Function()? _visibleOwnerOf;
  String? Function()? _visibleRuntimeIdOf;
  String? Function()? _visibleDurableIdOf;

  PreviewStore(this.connection, {this.apiResolver}) {
    _activeConnectionId = connection.activeConnectionId;
    connection.addListener(_onConnectionChanged);
    _events = connection.routedEvents.listen(_onGatewayEvent);
  }

  void bindVisibleSession({
    required OwnerRoute? Function() owner,
    required String? Function() runtimeId,
    required String? Function() durableId,
  }) {
    _visibleOwnerOf = owner;
    _visibleRuntimeIdOf = runtimeId;
    _visibleDurableIdOf = durableId;
  }

  String? get url => _url;
  String? get html => _html;
  String get title => _title;
  bool get hasContent =>
      (_url?.isNotEmpty ?? false) || (_html?.isNotEmpty ?? false);
  List<PreviewTab> get tabs => List.unmodifiable(
    _tabs.where(
      (tab) =>
          tab.owner == null ||
          tab.owner!.connectionId == connection.activeConnectionId,
    ),
  );
  PreviewTab? get activeTab {
    final id = _activeTabId;
    if (id == null) return null;
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return null;
    final tab = _tabs[index];
    return tab.owner == null ||
            tab.owner!.connectionId == connection.activeConnectionId
        ? tab
        : null;
  }

  PreviewRestartStatus restartStatus(String? tabId) => tabId == null
      ? const PreviewRestartStatus()
      : _restartByTab[tabId] ?? const PreviewRestartStatus();

  Future<String> restartServer(
    String tabId, {
    String? cwd,
    String? context,
  }) async {
    final tab = _tabs.where((candidate) => candidate.id == tabId).firstOrNull;
    if (tab == null) throw StateError('Preview tab is no longer open.');
    final sessionId = tab.sessionId?.trim() ?? '';
    final target = tab.url?.trim() ?? '';
    if (sessionId.isEmpty) {
      throw StateError('This preview is not attached to an active session.');
    }
    if (target.isEmpty) throw StateError('This preview has no server URL.');
    final existing = _restartByTab[tabId];
    if (existing != null && existing.busy && existing.taskId == null) {
      // The previous tap's request has not even returned a task id yet, so
      // there is nothing to disambiguate it from a second one; ignore the
      // duplicate tap instead of firing a redundant concurrent request.
      throw StateError('A preview restart request is already in progress.');
    }
    final route =
        tab.owner ?? OwnerRoute(connectionId: connection.activeConnectionId);
    // A new restart supersedes any restart already tracked for this tab.
    // Drop the superseded task's bookkeeping now so a late completion/error
    // event from it cannot be mistaken for the one we are about to start;
    // _handlePreviewRestart also guards on taskId for the same reason.
    final previousTaskId = _restartByTab[tabId]?.taskId;
    if (previousTaskId != null) _restartTabByTask.remove(previousTaskId);
    _restartByTab[tabId] = const PreviewRestartStatus(
      phase: PreviewRestartPhase.starting,
    );
    notifyListeners();
    try {
      final result = await connection
          .requestForOwner(route, 'preview.restart', {
            'session_id': sessionId,
            'url': target,
            if (cwd?.trim().isNotEmpty == true) 'cwd': cwd!.trim(),
            if (context?.trim().isNotEmpty == true) 'context': context!.trim(),
          });
      final taskId = result['task_id']?.toString().trim() ?? '';
      if (taskId.isEmpty) {
        throw StateError('Preview restart did not return a task id.');
      }
      _restartTabByTask[taskId] = tabId;
      _restartByTab[tabId] = PreviewRestartStatus(
        taskId: taskId,
        phase: PreviewRestartPhase.running,
      );
      notifyListeners();
      return taskId;
    } catch (error) {
      _restartByTab[tabId] = PreviewRestartStatus(
        phase: PreviewRestartPhase.failed,
        text: '$error',
      );
      notifyListeners();
      rethrow;
    }
  }

  String _ownerKey(OwnerRoute? owner) => owner?.key ?? 'legacy';

  void attachDriver(PreviewDriver driver, {String? tabId}) {
    if (tabId == null) {
      _driver = driver;
    } else {
      _tabDrivers[tabId] = driver;
    }
  }

  Future<void> reloadTab(String tabId) async {
    final tab = _tabs.where((candidate) => candidate.id == tabId).firstOrNull;
    if (tab == null) return;
    final document = tab.document;
    if (document?.path != null) {
      await openFile(
        document!.path!,
        title: document.title,
        sessionId: tab.sessionId,
        owner: tab.owner,
        repositoryRoot: document.repositoryRoot,
        byteSize: document.byteSize,
        mimeType: document.mimeType,
        force: document.source != null || document.url != null,
      );
      return;
    }
    final driver =
        _tabDrivers[tabId] ?? (tabId == _activeTabId ? _driver : null);
    await driver?.act(const {'action': 'reload'});
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
      id: 'url:${_ownerKey(owner)}:$url',
      title: resolvedTitle,
      url: url,
      sessionId: sessionId,
      owner: owner,
      document: PreviewDocument(
        id: 'url:${_ownerKey(owner)}:$url',
        title: resolvedTitle,
        kind: PreviewDocumentKind.web,
        url: url,
      ),
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
      id: 'html:${_ownerKey(owner)}:${sessionId ?? ''}:${html.hashCode}',
      title: resolvedTitle,
      html: html,
      sessionId: sessionId,
      owner: owner,
      document: PreviewDocument(
        id: 'html:${_ownerKey(owner)}:${sessionId ?? ''}:${html.hashCode}',
        title: resolvedTitle,
        kind: PreviewDocumentKind.html,
        source: html,
      ),
    );
    _upsertTab(tab);
    _html = html;
    _url = null;
    _title = resolvedTitle;
    _sessionId = sessionId;
    _owner = owner;
    notifyListeners();
  }

  /// Loads a workspace file into the same tab model used by web previews.
  /// Binary media is read as a data URL, while editable formats retain their
  /// source and an optional working-tree diff.
  Future<PreviewTab> openFile(
    String path, {
    String? title,
    String? sessionId,
    OwnerRoute? owner,
    String? repositoryRoot,
    int? byteSize,
    String? mimeType,
    bool force = false,
  }) async {
    final api = _resolveApi(owner);
    if (api == null) throw StateError(runtimeL10n.backendDisconnected);
    final id = 'file:${_ownerKey(owner)}:$path';
    final generation = (_fileLoadGenerations[id] ?? 0) + 1;
    _fileLoadGenerations[id] = generation;
    final resolvedTitle = title?.trim().isNotEmpty == true
        ? title!.trim()
        : path.split(RegExp(r'[\\/]')).last;
    final kind = PreviewDocument.infer(path: path, mimeType: mimeType);
    final binaryMedia = {
      PreviewDocumentKind.image,
      PreviewDocumentKind.pdf,
    }.contains(kind);
    final large = kind == PreviewDocumentKind.pdf
        ? (byteSize ?? 0) > PreviewStore.automaticPdfMaxBytes
        : !binaryMedia && (byteSize ?? 0) > PreviewStore.textPreviewMaxBytes;
    String? source;
    String? dataUrl;
    var binary = kind == PreviewDocumentKind.binary;
    if (!large || force) {
      if ({PreviewDocumentKind.image, PreviewDocumentKind.pdf}.contains(kind)) {
        dataUrl = await api.fsReadDataUrl(path);
      } else {
        try {
          source = await api.fsReadText(path, profile: owner?.profile);
        } on BinaryFileException {
          binary = true;
          if (force) dataUrl = await api.fsReadDataUrl(path);
        }
      }
    }
    String? diff;
    final root = repositoryRoot?.trim() ?? '';
    if (!binary && root.isNotEmpty) {
      try {
        diff = await api.gitFileDiff(root, path);
      } catch (_) {
        // A file outside a repository is still fully previewable.
      }
    }
    final document = PreviewDocument(
      id: id,
      title: resolvedTitle,
      kind: binary ? PreviewDocumentKind.binary : kind,
      path: path,
      url: dataUrl,
      mimeType: mimeType,
      byteSize: byteSize,
      repositoryRoot: repositoryRoot,
      revision: _fileRevisions[id],
      source: source,
      diff: diff,
      large: large,
      binary: binary,
      editable: !binary && source != null,
    );
    final tab = PreviewTab(
      id: id,
      title: resolvedTitle,
      url: dataUrl,
      html: kind == PreviewDocumentKind.html ? source : null,
      sessionId: sessionId,
      owner: owner,
      document: document,
    );
    // Never let an older read of the same file, or a response from an API
    // instance replaced during reconnect, overwrite the current preview.
    if (_fileLoadGenerations[id] != generation ||
        !identical(_resolveApi(owner), api)) {
      return tab;
    }
    _upsertTab(tab);
    _url = tab.url;
    _html = tab.html;
    _title = tab.title;
    _sessionId = sessionId;
    _owner = owner;
    notifyListeners();
    return tab;
  }

  ApiClient? _resolveApi(OwnerRoute? owner) {
    final custom = apiResolver;
    if (custom != null) return custom(owner);
    if (owner == null || owner.connectionId == connection.activeConnectionId) {
      return connection.api;
    }
    try {
      return connection.runtimeFor(owner).api;
    } catch (_) {
      return null;
    }
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
    if (tab.owner != null &&
        tab.owner!.connectionId != connection.activeConnectionId) {
      return;
    }
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
    _fileLoadGenerations.remove(id);
    _fileReloadTimers.remove(id)?.cancel();
    _fileRevisions.remove(id);
    final restart = _restartByTab.remove(id);
    if (restart?.taskId != null) _restartTabByTask.remove(restart!.taskId);
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
    _fileLoadGenerations.clear();
    for (final timer in _fileReloadTimers.values) {
      timer.cancel();
    }
    _fileReloadTimers.clear();
    _fileRevisions.clear();
    _restartByTab.clear();
    _restartTabByTask.clear();
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

  void _onConnectionChanged() {
    final next = connection.activeConnectionId;
    if (next == _activeConnectionId) return;
    _activeConnectionId = next;
    final matching = _tabs
        .where((tab) => tab.owner == null || tab.owner!.connectionId == next)
        .lastOrNull;
    if (matching == null) {
      _clearActive();
    } else {
      activate(matching.id);
      return;
    }
    notifyListeners();
  }

  Future<void> _onGatewayEvent(RoutedGatewayEvent routed) async {
    final event = routed.event;
    if (!event.type.startsWith('preview.') &&
        event.type != 'tour.request' &&
        event.type != 'workspace.changed') {
      return;
    }
    final p = event.payload;
    // Native-app tours are owned by MobileSurfaceStore. Keeping the handlers
    // disjoint guarantees exactly one tour.respond for each request.
    if (event.type == 'tour.request' && p['surface']?.toString() != 'preview') {
      return;
    }
    final route = OwnerRoute(
      connectionId: routed.route.connectionId,
      profile:
          p['profile']?.toString() ?? event.profile ?? routed.route.profile,
    );
    if (event.type == 'workspace.changed') {
      _handleWorkspaceChanged(route, p);
      return;
    }
    if (event.type.startsWith('preview.restart.')) {
      await _handlePreviewRestart(route, event);
      return;
    }
    if (event.type == 'preview.open' || event.type == 'preview.close') {
      // These fire-and-forget events come from open_preview/close_preview. A
      // background turn may update its own state but must never replace the
      // preview the user is currently looking at.
      if (!_isVisibleEvent(route, event.sessionId)) return;
      if (event.type == 'preview.open') {
        final target = p['url']?.toString().trim() ?? '';
        if (target.isNotEmpty) {
          openUrl(
            target,
            title: (p['label']?.toString().trim().isNotEmpty ?? false)
                ? p['label'].toString().trim()
                : runtimeL10n.previewTitle,
            sessionId: event.sessionId,
            owner: route,
          );
        }
      } else {
        final target = p['url']?.toString().trim() ?? '';
        if (target.isEmpty) {
          _closeScope(route, event.sessionId);
        } else {
          final match = _tabs.where(
            (tab) =>
                tab.owner == route &&
                tab.url == target &&
                (event.sessionId == null || tab.sessionId == event.sessionId),
          );
          if (match.isNotEmpty) closeTab(match.first.id);
        }
      }
      return;
    }
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

  Future<void> _handlePreviewRestart(
    OwnerRoute route,
    GatewayEvent event,
  ) async {
    final taskId = event.payload['task_id']?.toString().trim() ?? '';
    if (taskId.isEmpty) return;
    var tabId = _restartTabByTask[taskId];
    tabId ??= _tabs
        .where(
          (tab) =>
              tab.owner?.connectionId == route.connectionId &&
              (route.profile == null || tab.owner?.profile == route.profile) &&
              (event.sessionId == null || tab.sessionId == event.sessionId),
        )
        .lastOrNull
        ?.id;
    if (tabId == null || !_tabs.any((tab) => tab.id == tabId)) return;
    final tracked = _restartByTab[tabId];
    if (tracked?.taskId != null && tracked!.taskId != taskId) {
      // This tab is already tracking a newer restart task; a late
      // completion/error event from a superseded task must not clobber it.
      return;
    }
    _restartTabByTask[taskId] = tabId;
    final text = event.payload['text']?.toString() ?? '';
    final explicitError = event.type == 'preview.restart.error';
    final completed = event.type == 'preview.restart.complete';
    final failed =
        explicitError ||
        (completed && text.trimLeft().toLowerCase().startsWith('error:'));
    _restartByTab[tabId] = PreviewRestartStatus(
      taskId: taskId,
      phase: failed
          ? PreviewRestartPhase.failed
          : completed
          ? PreviewRestartPhase.completed
          : PreviewRestartPhase.running,
      text: text,
    );
    notifyListeners();
    if (!completed || failed) return;
    final driver =
        _tabDrivers[tabId] ?? (tabId == _activeTabId ? _driver : null);
    try {
      await driver?.act(const {'action': 'reload'});
    } catch (_) {
      // Restart completion remains successful even if the pane was disposed
      // before its best-effort refresh could run.
    }
  }

  void _handleWorkspaceChanged(OwnerRoute route, Map<String, dynamic> payload) {
    final changedPath = payload['path']?.toString().trim() ?? '';
    final cwd = payload['cwd']?.toString().trim() ?? '';
    final full = payload['full'] == true || changedPath.isEmpty;
    final revision = payload['revision']?.toString().trim() ?? '';
    final matching = _tabs
        .where((tab) {
          final document = tab.document;
          final path = document?.path;
          if (path == null || path.isEmpty) return false;
          final owner = tab.owner;
          if (owner != null && owner.connectionId != route.connectionId) {
            return false;
          }
          if (route.profile != null &&
              owner?.profile != null &&
              route.profile != owner!.profile) {
            return false;
          }
          if (!full) return _samePath(path, changedPath);
          final scope = cwd.isNotEmpty ? cwd : document?.repositoryRoot ?? '';
          return scope.isEmpty || _within(path, scope);
        })
        .toList(growable: false);

    var changed = false;
    for (final tab in matching) {
      if (revision.isNotEmpty && !_acceptRevision(tab.id, revision)) continue;
      final index = _tabs.indexWhere((candidate) => candidate.id == tab.id);
      if (index < 0 || tab.document == null) continue;
      _tabs[index] = PreviewTab(
        id: tab.id,
        title: tab.title,
        url: tab.url,
        html: tab.html,
        sessionId: tab.sessionId,
        owner: tab.owner,
        document: tab.document!.copyWith(
          revision: revision.isEmpty ? null : revision,
          byteSize: (payload['byte_size'] as num?)?.toInt(),
          mimeType: payload['mime_type']?.toString(),
          stale: true,
        ),
      );
      changed = true;
      if (tab.id == _activeTabId) {
        _scheduleFileReload(_tabs[index]);
      }
    }
    if (changed) notifyListeners();
  }

  bool _acceptRevision(String id, String next) {
    final previous = _fileRevisions[id];
    if (previous != null) {
      final a = BigInt.tryParse(previous);
      final b = BigInt.tryParse(next);
      if (a != null && b != null && b <= a) return false;
      if (a == null && b == null && next == previous) return false;
    }
    _fileRevisions[id] = next;
    return true;
  }

  void _scheduleFileReload(PreviewTab tab) {
    final document = tab.document;
    if (document?.path == null) return;
    _fileReloadTimers.remove(tab.id)?.cancel();
    _fileReloadTimers[tab.id] = Timer(const Duration(milliseconds: 200), () {
      _fileReloadTimers.remove(tab.id);
      unawaited(
        openFile(
          document!.path!,
          title: document.title,
          sessionId: tab.sessionId,
          owner: tab.owner,
          repositoryRoot: document.repositoryRoot,
          byteSize: document.byteSize,
          mimeType: document.mimeType,
          force: document.source != null || document.url != null,
        ).catchError((_) => tab),
      );
    });
  }

  static bool _samePath(String first, String second) =>
      first.replaceAll('\\', '/') == second.replaceAll('\\', '/');

  static bool _within(String path, String root) {
    final normalizedPath = path.replaceAll('\\', '/');
    final normalizedRoot = root
        .replaceAll('\\', '/')
        .replaceAll(RegExp(r'/+$'), '');
    return normalizedPath == normalizedRoot ||
        normalizedPath.startsWith('$normalizedRoot/');
  }

  bool _isVisibleEvent(OwnerRoute route, String? sessionId) {
    final visibleOwner = _visibleOwnerOf?.call();
    // Standalone store users (including previews opened outside ChatScreen)
    // have no session binding; preserve the legacy permissive behavior.
    if (_visibleOwnerOf == null) return true;
    if (visibleOwner == null ||
        visibleOwner.connectionId != route.connectionId) {
      return false;
    }
    if (route.profile != null && route.profile != visibleOwner.profile) {
      return false;
    }
    return sessionId == null ||
        sessionId == _visibleRuntimeIdOf?.call() ||
        sessionId == _visibleDurableIdOf?.call();
  }

  void _closeScope(OwnerRoute route, String? sessionId) {
    final ids = _tabs
        .where(
          (tab) =>
              tab.owner == route &&
              (sessionId == null || tab.sessionId == sessionId),
        )
        .map((tab) => tab.id)
        .toList(growable: false);
    for (final id in ids) {
      closeTab(id);
    }
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
    for (final timer in _fileReloadTimers.values) {
      timer.cancel();
    }
    connection.removeListener(_onConnectionChanged);
    _events?.cancel();
    super.dispose();
  }
}
