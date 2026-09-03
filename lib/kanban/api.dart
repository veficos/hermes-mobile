library;

import 'dart:typed_data';
import '../core/api_client.dart';
import 'models.dart';

class KanbanApi {
  final ApiClient client;
  String boardSlug;
  KanbanApi(this.client, {this.boardSlug = ''});
  Map<String, String> _q([Map<String, String>? extra]) => {
    if (boardSlug.isNotEmpty) 'board': boardSlug,
    ...?extra,
  };
  Future<KanbanBoard> board({bool archived = false}) async =>
      KanbanBoard.fromJson(
        (await client.get(
                  '/api/v1/kanban/board',
                  query: _q({if (archived) 'include_archived': 'true'}),
                )
                as Map)
            .cast(),
      );
  Future<({List<KanbanBoardMeta> boards, String current})> boards() async {
    final j = (await client.get('/api/v1/kanban/boards') as Map)
        .cast<String, dynamic>();
    return (
      boards: _mapsLocal(j['boards']).map(KanbanBoardMeta.fromJson).toList(),
      current: '${j['current'] ?? ''}',
    );
  }

  Future<KanbanTaskDetail> task(String id) async => KanbanTaskDetail.fromJson(
    (await client.get(
              '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}',
              query: _q(),
            )
            as Map)
        .cast(),
  );
  Future<dynamic> createTask(Map<String, dynamic> body) =>
      client.post('/api/v1/kanban/tasks', query: _q(), body: body);
  Future<dynamic> patchTask(String id, Map<String, dynamic> patch) =>
      client.patch(
        '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}',
        query: _q(),
        body: patch,
      );
  Future<dynamic> deleteTask(String id) => client.delete(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}',
    query: _q(),
  );
  Future<dynamic> bulk(List<String> ids, Map<String, dynamic> patch) =>
      client.post(
        '/api/v1/kanban/tasks/bulk',
        query: _q(),
        body: {'ids': ids, ...patch},
      );
  Future<dynamic> comment(String id, String body) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/comments',
    query: _q(),
    body: {'author': 'mobile', 'body': body},
  );
  Future<dynamic> reassign(String id, String profile) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/reassign',
    query: _q(),
    body: {'profile': profile, 'reclaim_first': true},
  );
  Future<dynamic> reclaim(String id) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/reclaim',
    query: _q(),
    body: const {},
  );
  Future<dynamic> specify(String id, {String? author}) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/specify',
    query: _q(),
    body: {if (author != null && author.isNotEmpty) 'author': author},
  );
  Future<dynamic> estimate(String id) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/estimate',
    query: _q(),
    body: const {},
  );
  Future<dynamic> dispatch() =>
      client.post('/api/v1/kanban/dispatch', query: _q(), body: const {});
  Future<dynamic> createBoard(String slug, String name, {String? projectId}) =>
      client.post(
        '/api/v1/kanban/boards',
        body: {'slug': slug, 'name': name, 'project_id': ?projectId},
      );
  Future<dynamic> updateBoard(String slug, Map<String, dynamic> patch) => client
      .patch('/api/v1/kanban/boards/${Uri.encodeComponent(slug)}', body: patch);
  Future<dynamic> deleteBoard(String slug) =>
      client.delete('/api/v1/kanban/boards/${Uri.encodeComponent(slug)}');
  Future<dynamic> switchBoard(String slug) => client.post(
    '/api/v1/kanban/boards/${Uri.encodeComponent(slug)}/switch',
    body: const {},
  );
  Future<Map<String, dynamic>> profiles() async =>
      (await client.get('/api/v1/kanban/profiles') as Map).cast();
  Future<Map<String, dynamic>> projects() async =>
      (await client.get('/api/v1/kanban/projects') as Map).cast();
  Future<Map<String, dynamic>> orchestration() async =>
      (await client.get('/api/v1/kanban/orchestration') as Map).cast();
  Future<dynamic> saveOrchestration(Map<String, dynamic> patch) =>
      client.put('/api/v1/kanban/orchestration', body: patch);
  Future<Map<String, dynamic>> log(String id) async =>
      (await client.get(
                '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/log',
                query: _q({'tail': '16384'}),
              )
              as Map)
          .cast();
  Future<dynamic> addLink(String parent, String child) => client.post(
    '/api/v1/kanban/links',
    query: _q(),
    body: {'parent': parent, 'child': child},
  );
  Future<dynamic> removeLink(String parent, String child) => client.delete(
    '/api/v1/kanban/links',
    query: _q(),
    body: {'parent': parent, 'child': child},
  );
  Future<dynamic> uploadAttachment(
    String id,
    String filename,
    Uint8List bytes,
  ) => client.postMultipart(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/attachments',
    query: _q(),
    fields: const {},
    field: 'file',
    filename: filename,
    bytes: bytes,
    // Attachments can be sizeable; the default request timeout (30s) is
    // tuned for small JSON calls, not an upload over a slow connection.
    timeout: const Duration(minutes: 2),
  );
  Future<dynamic> deleteAttachment(Object id) => client.delete(
    '/api/v1/kanban/attachments/${Uri.encodeComponent('$id')}',
    query: _q(),
  );
  Future<({Uint8List bytes, String filename})> downloadAttachment(Object id) =>
      client.downloadBytes(
        '/api/v1/kanban/attachments/${Uri.encodeComponent('$id')}',
        query: _q(),
      );
  Future<Map<String, dynamic>> diagnostics() async =>
      (await client.get('/api/v1/kanban/diagnostics', query: _q()) as Map)
          .cast();
  Future<Map<String, dynamic>> stats() async =>
      (await client.get('/api/v1/kanban/stats', query: _q()) as Map).cast();
  Future<Map<String, dynamic>> activeWorkers() async =>
      (await client.get('/api/v1/kanban/workers/active', query: _q()) as Map)
          .cast();
  Future<Map<String, dynamic>> run(Object id) async =>
      (await client.get(
                '/api/v1/kanban/runs/${Uri.encodeComponent('$id')}',
                query: _q(),
              )
              as Map)
          .cast();
  Future<Map<String, dynamic>> inspectRun(Object id) async =>
      (await client.get(
                '/api/v1/kanban/runs/${Uri.encodeComponent('$id')}/inspect',
                query: _q(),
              )
              as Map)
          .cast();
  Future<dynamic> terminateRun(Object id) => client.post(
    '/api/v1/kanban/runs/${Uri.encodeComponent('$id')}/terminate',
    query: _q(),
    body: const {},
  );
  Future<dynamic> decompose(String id) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/decompose',
    query: _q(),
    body: const {},
  );
  Future<Map<String, dynamic>> modelOptions() async =>
      (await client.get('/api/v1/kanban/model-options', query: _q()) as Map)
          .cast();
  Future<Map<String, dynamic>> config() async =>
      (await client.get('/api/v1/kanban/config', query: _q()) as Map).cast();
  Future<Map<String, dynamic>> homeChannels({String? taskId}) async =>
      (await client.get(
                '/api/v1/kanban/home-channels',
                query: _q({'task_id': ?taskId}),
              )
              as Map)
          .cast();
  Future<dynamic> subscribeHome(String id, String platform) => client.post(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/home-subscribe/${Uri.encodeComponent(platform)}',
    query: _q(),
    body: const {},
  );
  Future<dynamic> unsubscribeHome(String id, String platform) => client.delete(
    '/api/v1/kanban/tasks/${Uri.encodeComponent(id)}/home-subscribe/${Uri.encodeComponent(platform)}',
    query: _q(),
  );
  Future<dynamic> saveProfileDescription(String name, String description) =>
      client.patch(
        '/api/v1/kanban/profiles/${Uri.encodeComponent(name)}',
        body: {'description': description},
      );
  Future<dynamic> autoDescribeProfile(String name) => client.post(
    '/api/v1/kanban/profiles/${Uri.encodeComponent(name)}/describe-auto',
    body: const {'overwrite': true},
  );
}

List<Map<String, dynamic>> _mapsLocal(Object? v) => v is List
    ? v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];
