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
  Uri? _eventsUri;
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
    _details.clear();
    selectedIds.clear();
    error = null;
    if (api != null) {
      unawaited(start());
      connectEvents(_eventUri(api));
    }
    notifyListeners();
  }

  Uri _eventUri(KanbanApi api) {
    final base = Uri.parse(api.client.baseUrl);
    return base.replace(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      path: '/api/v1/kanban/events',
      queryParameters: {
        'token': api.client.apiKey,
        if (api.boardSlug.isNotEmpty) 'board': api.boardSlug,
        'since': '${_boardCursors[api.boardSlug] ?? 0}',
      },
    );
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
    if (_api == null) return;
    await load();
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => load());
  }

  void connectEvents(Uri uri) {
    final generation = ++_eventGeneration;
    _eventsUri = uri;
    _reconnect?.cancel();
    _socket?.sink.close();
    _events?.cancel();
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
    if (_eventsUri == null || _api == null || _reconnect?.isActive == true) {
      return;
    }
    _reconnect = Timer(
      const Duration(seconds: 3),
      () => connectEvents(_eventsUri!),
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
    connectEvents(_eventUri(api));
    await load(expectedApi: api);
    if (!identical(api, _api)) return;
    if (error != null) {
      api.boardSlug = previous;
      connectEvents(_eventUri(api));
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
  }) async {
    if (!force && _details[id] != null) return _details[id];
    final api = requireApi(expectedApi);
    final boardSlug = api.boardSlug;
    try {
      final detail = await api.task(id);
      if (!identical(api, _api) || boardSlug != api.boardSlug) return null;
      _details[id] = detail;
      notifyListeners();
      return detail;
    } catch (e) {
      if (!identical(api, _api)) return null;
      error = '$e';
      notifyListeners();
      return null;
    }
  }

  Future<void> moveTask(String id, String status) async {
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
      await api.patchTask(id, {'status': status});
    } catch (e) {
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
    try {
      final raw = await api.bulk(ids.toList(), patch);
      final failed = <String>{};
      if (raw is Map && raw['failed'] is List) {
        failed.addAll(
          (raw['failed'] as List)
              .map((e) => e is Map ? '${e['id'] ?? ''}' : '$e')
              .where((e) => e.isNotEmpty),
        );
      }
      selectedIds.removeWhere((id) => !failed.contains(id));
      await load();
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
