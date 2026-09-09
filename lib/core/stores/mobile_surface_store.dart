library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../connections/connection_registry.dart';
import '../pane_tree.dart';
import 'connection_store.dart';
import 'pane_workspace_store.dart';
import 'session_store.dart';

enum MobileSurface {
  home,
  chat,
  files,
  terminal,
  review,
  preview,
  sessions,
  tasks,
  more,
  workspace,
}

@immutable
class MobileTourStep {
  const MobileTourStep({
    required this.selector,
    required this.title,
    required this.text,
  });
  final String selector;
  final String title;
  final String text;
}

typedef MobileSurfaceReveal = FutureOr<void> Function(MobileSurface surface);

/// Semantic bridge between agent-facing desktop pane names and native mobile
/// destinations. It deliberately contains no Navigator state: the app shell
/// supplies the presentation callback, while this store owns session routing
/// and workspace identity. Background sessions can never move foreground UI.
class MobileSurfaceStore extends ChangeNotifier {
  MobileSurfaceStore(ConnectionStore connection, this._session, this._panes)
    : _connection = connection {
    _events = connection.routedEvents.listen(_onEvent);
  }

  ConnectionStore _connection;
  SessionStore _session;
  PaneWorkspaceStore _panes;
  StreamSubscription<RoutedGatewayEvent>? _events;
  MobileSurfaceReveal? _reveal;
  List<MobileTourStep> _tourSteps = const [];
  int _tourIndex = 0;
  bool _disposed = false;
  MobileTourStep? get activeTourStep =>
      _tourSteps.isEmpty ? null : _tourSteps[_tourIndex];
  int get activeTourIndex => _tourIndex;
  int get activeTourCount => _tourSteps.length;
  final Map<String, GlobalKey> _targetKeys = {};

  static const Map<String, MobileSurface> tourTargets = {
    'nav.home': MobileSurface.home,
    'nav.sessions': MobileSurface.sessions,
    'nav.tasks': MobileSurface.tasks,
    'nav.more': MobileSurface.more,
    'chat.composer': MobileSurface.chat,
    'chat.attachments': MobileSurface.chat,
    'chat.model': MobileSurface.chat,
    'chat.sessionTray': MobileSurface.chat,
    'chat.requests': MobileSurface.chat,
    'workspace.files': MobileSurface.files,
    'workspace.terminal': MobileSurface.terminal,
    'workspace.review': MobileSurface.review,
    'workspace.preview': MobileSurface.preview,
    'workspace.tabs': MobileSurface.workspace,
  };

  GlobalKey targetKey(String selector) =>
      _targetKeys.putIfAbsent(selector, GlobalKey.new);

  Rect? targetRect(String selector) {
    final context = _targetKeys[selector]?.currentContext;
    final box = context?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void bindStores({
    required ConnectionStore connection,
    required SessionStore session,
    required PaneWorkspaceStore panes,
  }) {
    if (!identical(_connection, connection)) {
      unawaited(_events?.cancel());
      _connection = connection;
      _events = connection.routedEvents.listen(_onEvent);
    }
    _session = session;
    _panes = panes;
  }

  void bindReveal(MobileSurfaceReveal? reveal) => _reveal = reveal;

  bool _isVisible(RoutedGatewayEvent routed) {
    final owner = _session.owner;
    if (owner == null ||
        owner.route.connectionId != routed.route.connectionId) {
      return false;
    }
    final eventProfile =
        routed.event.profile ??
        routed.event.payload['profile']?.toString() ??
        routed.route.profile;
    if (eventProfile != null && eventProfile != owner.route.profile) {
      return false;
    }
    final eventSession = routed.event.sessionId;
    return eventSession == null ||
        eventSession == _session.runtimeId ||
        eventSession == _session.durableId;
  }

  Future<void> _onEvent(RoutedGatewayEvent routed) async {
    if (!_isVisible(routed)) return;
    if (routed.event.type == 'tour.request' &&
        routed.event.payload['surface']?.toString() != 'preview') {
      await _handleAppTour(routed);
      return;
    }
    if (routed.event.type == 'layout.apply') {
      final requested = routed.event.payload['preset']
          ?.toString()
          .trim()
          .toLowerCase();
      final preset = switch (requested) {
        'default' => WorkspaceLayoutPreset.defaultLayout,
        'focus' => WorkspaceLayoutPreset.focus,
        'balanced' || '1:1' => WorkspaceLayoutPreset.balanced,
        'main-wide' || '2:1' => WorkspaceLayoutPreset.mainWide,
        'tools-wide' || '1:2' => WorkspaceLayoutPreset.toolsWide,
        'terminal-deck' => WorkspaceLayoutPreset.terminalDeck,
        'quad' => WorkspaceLayoutPreset.quad,
        _ => null,
      };
      if (preset == null) return;
      _panes.applyLayoutPreset(preset);
      await _reveal?.call(MobileSurface.workspace);
      return;
    }
    if (routed.event.type != 'pane.reveal') return;
    final owner = _session.owner;
    if (owner == null) return;
    final name = routed.event.payload['pane']?.toString().trim().toLowerCase();
    final surface = switch (name) {
      'chat' => MobileSurface.chat,
      'files' => MobileSurface.files,
      'terminal' => MobileSurface.terminal,
      'review' => MobileSurface.review,
      'preview' => MobileSurface.preview,
      'sessions' => MobileSurface.sessions,
      _ => null,
    };
    if (surface == null) return;

    await _ensureCorePane(surface);
    await _reveal?.call(surface);
  }

  Future<void> _ensureCorePane(MobileSurface surface) async {
    final owner = _session.owner;
    if (owner == null) return;
    final paneKind = switch (surface) {
      MobileSurface.files => WorkspacePaneKind.files,
      MobileSurface.terminal => WorkspacePaneKind.terminal,
      MobileSurface.review => WorkspacePaneKind.review,
      MobileSurface.preview => WorkspacePaneKind.preview,
      MobileSurface.home ||
      MobileSurface.chat ||
      MobileSurface.sessions ||
      MobileSurface.tasks ||
      MobileSurface.more ||
      MobileSurface.workspace => null,
    };
    if (paneKind != null) {
      await _panes.openCorePane(
        kind: paneKind,
        title: paneKind.name,
        owner: owner.route,
        referenceId: _session.durableId ?? 'default',
        position: paneKind == WorkspacePaneKind.terminal
            ? PaneDropPosition.bottom
            : PaneDropPosition.right,
      );
    }
  }

  Future<void> _handleAppTour(RoutedGatewayEvent routed) async {
    final payload = routed.event.payload;
    final action = payload['action']?.toString().trim().toLowerCase() ?? '';
    Map<String, dynamic> result;
    try {
      switch (action) {
        case 'targets':
          result = {
            'success': true,
            'targets': [
              for (final selector in tourTargets.keys)
                {'selector': selector, 'stable': true},
            ],
          };
        case 'show':
          final step = _stepFrom(payload);
          if (step == null) throw StateError('Unknown mobile tour target');
          _tourSteps = [step];
          _tourIndex = 0;
          await _revealTarget(step.selector);
          if (!_disposed) notifyListeners();
          result = {'success': true, 'selector': step.selector};
        case 'start':
          final raw = payload['steps'];
          final steps = raw is List
              ? raw.whereType<Map>().map(_stepFrom).nonNulls.toList()
              : const <MobileTourStep>[];
          if (steps.isEmpty) throw StateError('No valid mobile tour steps');
          _tourSteps = List.unmodifiable(steps);
          _tourIndex = ((payload['step_index'] as num?)?.toInt() ?? 0).clamp(
            0,
            steps.length - 1,
          );
          await _revealTarget(_tourSteps[_tourIndex].selector);
          if (!_disposed) notifyListeners();
          result = {'success': true, 'step_index': _tourIndex};
        case 'next':
          await advanceTour(1);
          result = {'success': true, 'step_index': _tourIndex};
        case 'prev':
          await advanceTour(-1);
          result = {'success': true, 'step_index': _tourIndex};
        case 'stop':
          stopTour();
          result = {'success': true};
        default:
          throw StateError('Unsupported mobile tour action');
      }
    } catch (error) {
      result = {'success': false, 'error': '$error'};
    }
    final requestId = payload['request_id']?.toString();
    if (requestId?.isNotEmpty != true) return;
    await _connection.requestForOwner(routed.route, 'tour.respond', {
      'request_id': requestId,
      'text': jsonEncode(result),
    });
  }

  MobileTourStep? _stepFrom(Map raw) {
    final selector = raw['selector']?.toString().trim() ?? '';
    if (!tourTargets.containsKey(selector)) return null;
    return MobileTourStep(
      selector: selector,
      title: raw['title']?.toString().trim() ?? '',
      text: raw['text']?.toString().trim() ?? '',
    );
  }

  Future<void> _revealTarget(String selector) async {
    final target = tourTargets[selector];
    if (target == null) return;
    await _ensureCorePane(target);
    await _reveal?.call(target);
  }

  Future<void> advanceTour(int delta) async {
    if (_tourSteps.isEmpty) return;
    _tourIndex = (_tourIndex + delta).clamp(0, _tourSteps.length - 1);
    await _revealTarget(_tourSteps[_tourIndex].selector);
    if (!_disposed) notifyListeners();
  }

  void stopTour() {
    if (_tourSteps.isEmpty) return;
    _tourSteps = const [];
    _tourIndex = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_events?.cancel());
    super.dispose();
  }
}
