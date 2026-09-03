library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../l10n/runtime_l10n.dart';
import '../core/ws_connect.dart';
import 'api.dart';
import 'models.dart';

class KanbanStore extends ChangeNotifier {
  KanbanApi? _api;
  KanbanBoard? boardData;
  List<KanbanBoardMeta> boardList = const [];
  String? error;
  bool loading = false;
  Timer? _poll;
  WebSocketChannel? _socket;
  StreamSubscription? _events;
  Timer? _reconnect;
  int _loadGeneration = 0;
  int _eventGeneration = 0;
  void Function(String board, Map<String, dynamic> event)? onEvent;
  final Map<String, int> _boardCursors = {};
  final Map<String, KanbanTaskDetail> _details = {};
  final Set<String> selectedIds = <String>{};
  String search = '';
  String assigneeFilter = '';
  String tenantFilter = '';
  bool includeArchived = false;
  bool _foreground = true;

  /// Weak-network: lets the owner (see `AppShell`) plug in a live
  /// connectivity signal so the poll timer can skip a tick when there is
  /// provably no network, instead of firing on schedule into a request
  /// that can only time out. `null` (unwired, or genuinely unknown) means
  /// "assume available" — this must never be the thing that silently stops
  /// polling.
  bool Function()? hasNetwork;
  KanbanStore([KanbanApi? api]) : _api = api;
  KanbanApi get api => requireApi();
  bool get ready => _api != null;

  KanbanApi requireApi([KanbanApi? expected]) {
    final current = _api;
    if (current == null ||
        (expected != null && !identical(current, expected))) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    return current;
  }

  void bindApi(KanbanApi? api) {
    if (identical(_api, api) ||
        (_api != null && api != null && identical(_api!.client, api.client))) {
      return;
    }
    _poll?.cancel();
    _loadGeneration++;
    _eventGeneration++;
    _events?.cancel();
    _socket?.sink.close();
    _api = api;
    boardData = null;
    boardList = const [];
    _boardCursors.clear();
    _details.clear();
    selectedIds.clear();
    error = null;
    if (api != null && _foreground) {
      unawaited(start());
      unawaited(_connectEvents(api));
    }
    notifyListeners();
  }

  Future<void> _connectEvents(KanbanApi expectedApi) async {
    final generation = ++_eventGeneration;
    _reconnect?.cancel();
    _socket?.sink.close();
    await _events?.cancel();
    final board = expectedApi.boardSlug;
    Uri uri;
    try {
      uri = await expectedApi.client.kanbanEventsUri(
        board: board,
        since: _boardCursors[board] ?? 0,
      );
    } catch (_) {
      if (generation == _eventGeneration && identical(expectedApi, _api)) {
        _scheduleReconnect();
      }
      return;
    }
    if (generation != _eventGeneration ||
        !identical(expectedApi, _api) ||
        board != expectedApi.boardSlug) {
      return;
    }
    _openEvents(uri, generation);
  }

  Future<void> load({KanbanApi? expectedApi}) async {
    final api = _api;
    if (expectedApi != null && !identical(api, expectedApi)) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    if (api == null) return;
    final generation = ++_loadGeneration;
    final boardSlug = api.boardSlug;
    final archived = includeArchived;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final board = await api.board(archived: archived);
      if (!identical(api, _api) ||
          generation != _loadGeneration ||
          boardSlug != api.boardSlug ||
          archived != includeArchived) {
        return;
      }
      boardData = board;
    } catch (e) {
      if (!identical(api, _api) ||
          generation != _loadGeneration ||
          boardSlug != api.boardSlug ||
          archived != includeArchived) {
        return;
      }
      error = '$e';
    } finally {
      if (identical(api, _api) && generation == _loadGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> start() async {
    if (_api == null || !_foreground) return;
    await load();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) {
      if (_foreground && (hasNetwork?.call() ?? true)) unawaited(load());
    });
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    if (!value) {
      _poll?.cancel();
      _poll = null;
      _reconnect?.cancel();
      _reconnect = null;
      _eventGeneration++;
      _events?.cancel();
      _events = null;
      _socket?.sink.close();
      _socket = null;
      return;
    }
    final api = _api;
    if (api != null) {
      unawaited(start());
      unawaited(_connectEvents(api));
    }
  }

  void connectEvents(Uri uri) {
    final generation = ++_eventGeneration;
    _reconnect?.cancel();
    _socket?.sink.close();
    _events?.cancel();
    _openEvents(uri, generation);
  }

  void _openEvents(Uri uri, int generation) {
    final channel = connectWs(uri);
    _socket = channel;
    _events = channel.stream.listen(
      (raw) {
        if (generation != _eventGeneration) return;
        if (raw is! String) return;
        try {
          final frame = KanbanEventFrame.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>(),
          );
          final board = api.boardSlug;
          if (frame.cursor > (_boardCursors[board] ?? 0)) {
            _boardCursors[board] = frame.cursor;
            for (final event in frame.events) {
              onEvent?.call(board, event);
            }
            load();
          }
        } catch (_) {}
      },
      onError: (_) {
        if (generation == _eventGeneration) _scheduleReconnect();
      },
      onDone: () {
        if (generation == _eventGeneration) _scheduleReconnect();
      },
    );
  }

  void _scheduleReconnect() {
    final api = _api;
    if (!_foreground || api == null || _reconnect?.isActive == true) {
      return;
    }
    _reconnect = Timer(
      const Duration(seconds: 3),
      () => unawaited(_connectEvents(api)),
    );
  }

  Future<void> loadBoards({KanbanApi? expectedApi}) async {
    final api = _api;
    if (expectedApi != null && !identical(api, expectedApi)) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    if (api == null) return;
    try {
      final result = await api.boards();
      if (!identical(api, _api)) return;
      boardList = result.boards;
      error = null;
      notifyListeners();
    } catch (e) {
      if (!identical(api, _api)) return;
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> selectBoard(String slug, {KanbanApi? expectedApi}) async {
    final api = requireApi(expectedApi);
    final previous = api.boardSlug;
    api.boardSlug = slug;
    notifyListeners();
    await _connectEvents(api);
    await load(expectedApi: api);
    if (!identical(api, _api)) return;
    if (error != null) {
      api.boardSlug = previous;
      notifyListeners();
      await _connectEvents(api);
      return;
    }
    _details.clear();
    selectedIds.clear();
    await loadBoards(expectedApi: api);
  }

  List<KanbanTask> get filteredTasks =>
      boardData?.tasks.where((t) {
        final q = search.trim().toLowerCase();
        return (q.isEmpty ||
                t.title.toLowerCase().contains(q) ||
                (t.body ?? '').toLowerCase().contains(q)) &&
            (assigneeFilter.isEmpty || t.assignee == assigneeFilter) &&
            (tenantFilter.isEmpty || t.tenant == tenantFilter);
      }).toList() ??
      const [];

  void setFilters({
    String? search,
    String? assignee,
    String? tenant,
    bool? archived,
  }) {
    if (search != null) this.search = search;
    if (assignee != null) assigneeFilter = assignee;
    if (tenant != null) tenantFilter = tenant;
    if (archived != null && archived != includeArchived) {
      includeArchived = archived;
      unawaited(load());
    }
    notifyListeners();
  }

  void toggleSelected(String id) {
    selectedIds.contains(id) ? selectedIds.remove(id) : selectedIds.add(id);
    notifyListeners();
  }

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  Future<KanbanTaskDetail?> loadDetail(
    String id, {
    bool force = false,
    KanbanApi? expectedApi,
    String? expectedBoardSlug,
  }) async {
    final api = requireApi(expectedApi);
    final boardSlug = api.boardSlug;
    if (expectedBoardSlug != null && boardSlug != expectedBoardSlug) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    final cacheKey = '$boardSlug\u0000$id';
    if (!force && _details[cacheKey] != null) return _details[cacheKey];
    try {
      final detail = await api.task(id);
      if (!identical(api, _api) || boardSlug != api.boardSlug) return null;
      _details[cacheKey] = detail;
      notifyListeners();
      return detail;
    } catch (e) {
      if (!identical(api, _api)) return null;
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<void> moveTask(
    String id,
    String status, {
    KanbanApi? expectedApi,
    String? expectedBoardSlug,
  }) async {
    final ownerApi = requireApi(expectedApi);
    final boardSlug = ownerApi.boardSlug;
    if (expectedBoardSlug != null && boardSlug != expectedBoardSlug) {
      throw StateError(runtimeL10n.backendDisconnected);
    }
    final old = boardData;
    if (old != null) {
      boardData = KanbanBoard(
        columns: [
          for (final c in old.columns)
            KanbanColumn(c.name, [
              for (final t in c.tasks)
                t.id == id ? t.copyWith(status: status) : t,
            ]),
        ],
        tenants: old.tenants,
        assignees: old.assignees,
        latestEventId: old.latestEventId,
      );
      notifyListeners();
    }
    try {
      await ownerApi.patchTask(id, {'status': status});
      if (!identical(ownerApi, _api) || boardSlug != ownerApi.boardSlug) return;
    } catch (e) {
      if (!identical(ownerApi, _api) || boardSlug != ownerApi.boardSlug) {
        return;
      }
      boardData = old;
      error = '$e';
      notifyListeners();
      rethrow;
    }
  }

  Future<Set<String>> bulkPatch(
    Set<String> ids,
    Map<String, dynamic> patch,
  ) async {
    if (ids.isEmpty) return <String>{};
    final ownerApi = requireApi();
    final boardSlug = ownerApi.boardSlug;
    try {
      final raw = await ownerApi.bulk(ids.toList(), patch);
      if (!identical(ownerApi, _api) || boardSlug != ownerApi.boardSlug) {
        return ids;
      }
      final failed = <String>{};
      if (raw is Map && raw['failed'] is List) {
        failed.addAll(
          (raw['failed'] as List)
              .map((e) => e is Map ? '${e['id'] ?? ''}' : '$e')
              .where((e) => e.isNotEmpty),
        );
      }
      selectedIds.removeWhere((id) => !failed.contains(id));
      await load(expectedApi: ownerApi);
      notifyListeners();
      return failed;
    } catch (_) {
      return ids;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reconnect?.cancel();
    _events?.cancel();
    _socket?.sink.close();
    super.dispose();
  }
}
