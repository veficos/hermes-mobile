import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/kanban/api.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';
import 'package:hermes_mobile/l10n/runtime_l10n.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

ApiClient _client(
  Future<http.Response> Function(http.Request request) handler, {
  Future<Map<String, dynamic>> Function(
    String method,
    Map<String, dynamic> params, {
    Duration? timeout,
  })?
  gatewayRequest,
}) => ApiClient(
  baseUrl: 'https://agent.example',
  apiKey: 'secret',
  directGateway: true,
  gatewayRequest: gatewayRequest,
  client: MockClient(handler),
);

void main() {
  setUp(() => RuntimeL10n.use(AppLocalizationsEn()));

  test(
    'direct sessions use dashboard paging, bulk delete and patch pin',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.url.path == '/api/sessions') {
          return _json({'sessions': [], 'total': 0, 'offset': 5});
        }
        return _json({'ok': true, 'deleted': 2});
      });
      addTearDown(client.close);

      await client.listSessionsPage(
        limit: 20,
        offset: 5,
        includeArchived: true,
      );
      await client.pinSession('session 1', true);
      await client.deleteSessions(['a', 'b']);

      expect(requests[0].method, 'GET');
      expect(requests[0].url.path, '/api/sessions');
      expect(requests[0].url.queryParameters['archived'], 'include');
      expect(
        requests[0].url.queryParameters,
        isNot(contains('include_archived')),
      );
      expect(requests[1].method, 'PATCH');
      expect(requests[1].url.path, '/api/sessions/session%201');
      expect(jsonDecode(requests[1].body), {'pinned': true});
      expect(requests[2].url.path, '/api/sessions/bulk-delete');
      expect(jsonDecode(requests[2].body), {
        'ids': ['a', 'b'],
      });
    },
  );

  test(
    'direct config preserves replace semantics through raw YAML endpoint',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/config') {
          return _json({
            'model': {'provider': 'nous', 'name': 'model-a'},
          });
        }
        if (request.method == 'GET') {
          return _json({'yaml': 'model:\n  provider: nous\n  name: model-b\n'});
        }
        return _json({'ok': true});
      });
      addTearDown(client.close);

      final config = await client.getConfig();
      await client.replaceConfig({
        'model': {'provider': 'nous', 'name': 'model-b'},
      });
      final raw = await client.getRawConfig();

      expect((config['model'] as Map)['name'], 'model-a');
      expect(requests[1].method, 'PUT');
      expect(requests[1].url.path, '/api/config/raw');
      final replaceBody = jsonDecode(requests[1].body) as Map;
      expect(jsonDecode(replaceBody['yaml_text'] as String), {
        'model': {'provider': 'nous', 'name': 'model-b'},
      });
      expect((raw['model'] as Map)['name'], 'model-b');
    },
  );

  test(
    'direct profiles use active, rename, description and model contracts',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/profiles':
            return _json({
              'profiles': [
                {'name': 'work'},
              ],
            });
          case 'GET /api/profiles/active':
            return _json({'active': 'work', 'current': 'default'});
          case 'PATCH /api/profiles/work':
            return _json({'ok': true, 'name': 'renamed'});
          default:
            return _json({'ok': true, 'active': 'renamed'});
        }
      });
      addTearDown(client.close);

      final profiles = await client.listProfiles();
      final updated = await client.updateProfile('work', {
        'name': 'renamed',
        'description': 'Build profile',
        'provider': 'nous',
        'model': 'model-a',
      });
      await client.activateProfile('renamed');

      expect(profiles.active, 'work');
      expect(profiles.current, 'default');
      expect(updated.name, 'renamed');
      expect(requests[3].url.path, '/api/profiles/renamed/description');
      expect(requests[4].url.path, '/api/profiles/renamed/model');
      expect(requests[5].url.path, '/api/profiles/active');
      expect(jsonDecode(requests[5].body), {'name': 'renamed'});
    },
  );

  test(
    'direct profile artifacts bridge mobile bytes and canonical APIs',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/profiles/work/soul':
            return _json({'content': '# Work', 'exists': true});
          case 'GET /api/profiles/work/setup-command':
            return _json({'command': 'hermes --profile work'});
          case 'GET /api/files':
            return _json({'root': '/srv/workspace'});
          case 'POST /api/profiles/work/export':
            final body = jsonDecode(request.body) as Map;
            return _json({'ok': true, 'archive': body['output']});
          case 'GET /api/files/download':
            return http.Response.bytes(
              [31, 139, 8, 0],
              200,
              headers: {
                'content-type': 'application/gzip',
                'content-disposition': 'attachment; filename="work.tar.gz"',
              },
            );
          case 'POST /api/profiles/import':
            return _json({'ok': true, 'name': 'imported-work'});
          default:
            return _json({'ok': true});
        }
      });
      addTearDown(client.close);

      final soul = await client.getProfileSoul('work');
      await client.updateProfileSoul('work', '# Updated');
      final command = await client.getProfileSetupCommand('work');
      final exported = await client.exportProfileArchive('work');
      final imported = await client.importProfileArchive(
        Uint8List.fromList([31, 139, 8, 0]),
        'shared.tar.gz',
      );

      expect(soul.content, '# Work');
      expect(soul.exists, isTrue);
      expect(command, 'hermes --profile work');
      expect(exported.bytes, [31, 139, 8, 0]);
      expect(exported.filename, 'work.tar.gz');
      expect(imported['name'], 'imported-work');

      final exportRequest = requests.firstWhere(
        (request) => request.url.path == '/api/profiles/work/export',
      );
      final exportBody = jsonDecode(exportRequest.body) as Map;
      expect(exportBody['output'], startsWith('/srv/workspace/work-'));
      final upload = requests.firstWhere(
        (request) =>
            request.method == 'POST' && request.url.path == '/api/files/upload',
      );
      final uploadBody = jsonDecode(upload.body) as Map;
      expect(uploadBody['path'], startsWith('/srv/workspace/.hermes-import-'));
      expect(
        uploadBody['data_url'],
        startsWith('data:application/gzip;base64,'),
      );
      final importRequest = requests.firstWhere(
        (request) => request.url.path == '/api/profiles/import',
      );
      expect(
        (jsonDecode(importRequest.body) as Map)['archive'],
        uploadBody['path'],
      );
      expect(
        requests
            .where(
              (request) =>
                  request.method == 'DELETE' &&
                  request.url.path == '/api/files',
            )
            .length,
        2,
      );
    },
  );

  test('direct cron routes jobs and wraps update payload', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      if (request.method == 'GET') return _json([]);
      return _json({'id': 'job-1'});
    });
    addTearDown(client.close);

    await client.cronJobs();
    await client.cronUpdate('job-1', {'name': 'Nightly'});
    await client.cronTrigger('job-1');

    expect(requests[0].url.path, '/api/cron/jobs');
    expect(requests[1].url.path, '/api/cron/jobs/job-1');
    expect(jsonDecode(requests[1].body), {
      'updates': {'name': 'Nightly'},
    });
    expect(requests[2].url.path, '/api/cron/jobs/job-1/trigger');
  });

  test(
    'direct managed files adapt root, data URLs, writes and deletes',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/files/read') {
          return _json({
            'data_url':
                'data:text/plain;base64,${base64Encode(utf8.encode('hello'))}',
          });
        }
        if (request.method == 'GET') {
          return _json({
            'root': '/workspace',
            'path': '/workspace',
            'entries': [],
          });
        }
        return _json({'ok': true});
      });
      addTearDown(client.close);

      expect(await client.fsDefaultCwd(), '/workspace');
      await client.fsEntries('/workspace/src', root: '/workspace');
      expect(await client.fsReadText('/workspace/readme.txt'), 'hello');
      await client.fsWriteText('/workspace/readme.txt', 'updated');
      await client.fsDelete('/workspace/old', recursive: true);

      expect(requests[1].url.path, '/api/files');
      expect(requests[1].url.queryParameters, {'path': '/workspace/src'});
      expect(requests[3].url.path, '/api/files/upload');
      final upload = jsonDecode(requests[3].body) as Map;
      expect(upload['overwrite'], true);
      expect(
        utf8.decode(
          base64Decode((upload['data_url'] as String).split(',').last),
        ),
        'updated',
      );
      expect(requests[4].method, 'DELETE');
      expect(requests[4].url.path, '/api/files');
    },
  );

  test(
    'direct model, skill, toolset and MCP mutations use gateway routes',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        return _json({'ok': true});
      });
      addTearDown(client.close);

      await client.setModel('nous', 'model-a');
      await client.toggleSkill('git', true);
      await client.toggleToolset('browser', false);
      await client.computerUseStatus(profile: 'work');
      await client.grantComputerUsePermissions(profile: 'work');
      await client.mcpTest('github');
      await client.mcpCancelAuthFlow('flow-1', profile: 'work');

      expect(requests[0].url.path, '/api/model/set');
      expect(jsonDecode(requests[0].body), {
        'scope': 'main',
        'provider': 'nous',
        'model': 'model-a',
      });
      expect(requests[1].url.path, '/api/skills/toggle');
      expect(jsonDecode(requests[1].body), {'name': 'git', 'enabled': true});
      expect(requests[2].url.path, '/api/tools/toolsets/browser');
      expect(requests[3].url.path, '/api/tools/computer-use/status');
      expect(requests[3].url.queryParameters['profile'], 'work');
      expect(requests[4].url.path, '/api/tools/computer-use/permissions/grant');
      expect(requests[4].url.queryParameters['profile'], 'work');
      expect(requests[5].method, 'POST');
      expect(requests[5].url.path, '/api/mcp/servers/github/test');
      expect(requests[6].method, 'DELETE');
      expect(requests[6].url.path, '/api/mcp/oauth/flows/flow-1');
      expect(requests[6].url.queryParameters['profile'], 'work');
    },
  );

  test('direct advanced model settings preserve gateway contracts', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      return _json({'ok': true});
    });
    addTearDown(client.close);

    await client.recommendedDefaultModel('openrouter', profile: 'work');
    await client.auxiliaryModels(profile: 'work');
    await client.moaModels(profile: 'work');
    await client.saveMoaModels({
      'default_preset': 'balanced',
      'presets': {
        'balanced': {
          'enabled': true,
          'reference_models': [
            {'provider': 'nous', 'model': 'hermes-4'},
          ],
          'aggregator': {'provider': 'openrouter', 'model': 'sonnet'},
        },
      },
    }, profile: 'work');
    await client.setModelAssignment({
      'scope': 'auxiliary',
      'task': 'vision',
      'provider': 'openrouter',
      'model': 'vision-model',
    }, profile: 'work');

    expect(requests.map((request) => request.url.path), [
      '/api/model/recommended-default',
      '/api/model/auxiliary',
      '/api/model/moa',
      '/api/model/moa',
      '/api/model/set',
    ]);
    expect(
      requests.map((request) => request.url.queryParameters['profile']),
      everyElement('work'),
    );
    expect(requests[0].url.queryParameters['provider'], 'openrouter');
    expect(requests[3].method, 'PUT');
    expect((jsonDecode(requests[3].body) as Map)['default_preset'], 'balanced');
    expect(requests[4].method, 'POST');
    expect(jsonDecode(requests[4].body), {
      'scope': 'auxiliary',
      'task': 'vision',
      'provider': 'openrouter',
      'model': 'vision-model',
    });
  });

  test('direct tasks and canonical kanban use the plugin namespace', () async {
    final requests = <http.Request>[];
    var status = 'todo';
    Map<String, dynamic> task() => {
      'id': 'task/1',
      'title': 'Ship mobile',
      'body': 'Close the parity gap',
      'priority': 2,
      'status': status,
      'created_at': 1700000000,
    };
    final client = _client((request) async {
      requests.add(request);
      if (request.url.path == '/api/plugins/kanban/board') {
        return _json({
          'columns': [
            {
              'name': status,
              'tasks': [task()],
            },
          ],
        });
      }
      if (request.method == 'POST' &&
          request.url.path == '/api/plugins/kanban/tasks') {
        return _json({'task': task()});
      }
      if (request.method == 'PATCH') {
        final body = jsonDecode(request.body) as Map;
        status = body['status']?.toString() ?? status;
        return _json({'task': task()});
      }
      if (request.url.path == '/api/plugins/kanban/dispatch') {
        return _json({
          'spawned': ['task/1'],
        });
      }
      if (request.method == 'DELETE') return _json({'deleted': true});
      if (request.url.path == '/api/plugins/kanban/tasks/task%2F1') {
        return _json({'task': task()});
      }
      return _json({'boards': [], 'current': 'default'});
    });
    addTearDown(client.close);

    final listed = await client.taskList();
    final created = await client.taskCreate(
      title: 'Ship mobile',
      prompt: 'Close the parity gap',
      priority: 'urgent',
    );
    final fetched = await client.taskGet('task/1');
    await client.taskUpdate('task/1', prompt: 'Updated', priority: 'high');
    final run = await client.taskRun('task/1');
    await client.taskDelete('task/1');
    await KanbanApi(client).boards();

    expect(listed.single.prompt, 'Close the parity gap');
    expect(listed.single.priority, 'urgent');
    expect(created.id, 'task/1');
    expect(fetched.createdAt, isNotNull);
    final createBody = jsonDecode(requests[1].body) as Map;
    expect(createBody['body'], 'Close the parity gap');
    expect(createBody['priority'], 2);
    final updateBody = jsonDecode(requests[3].body) as Map;
    expect(updateBody['body'], 'Updated');
    expect(updateBody['priority'], 1);
    expect((run['dispatch'] as Map)['spawned'], ['task/1']);
    expect(
      requests.map((request) => request.url.path),
      everyElement(startsWith('/api/plugins/kanban/')),
    );
  });

  test('direct messaging uses platform and pairing contracts', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      if (request.url.path == '/api/messaging/platforms') {
        return _json({
          'platforms': [
            {
              'id': 'telegram',
              'name': 'Telegram',
              'enabled': true,
              'configured': true,
              'env_vars': [
                {'key': 'TELEGRAM_BOT_TOKEN', 'is_set': true},
              ],
            },
          ],
        });
      }
      if (request.url.path == '/api/pairing') {
        return _json({
          'pending': [
            {
              'platform': 'telegram',
              'request_id': 'request-1',
              'user_id': 'user-1',
            },
            {'platform': 'discord', 'request_id': 'request-2'},
          ],
        });
      }
      return _json({'ok': true});
    });
    addTearDown(client.close);

    final platforms = await client.messagingPlatforms();
    final config = await client.messagingConfig('telegram', profile: 'work');
    await client.messagingSetEnv(
      'telegram',
      'TELEGRAM_BOT_TOKEN',
      'secret',
      profile: 'work',
    );
    await client.messagingSetEnv(
      'telegram',
      'TELEGRAM_PROXY',
      '',
      profile: 'work',
    );
    final pending = await client.messagingPending('telegram', profile: 'work');
    await client.messagingApprovePairing('telegram', 'request-1');

    expect(platforms.single.name, 'telegram');
    expect(config['id'], 'telegram');
    expect(pending.single.id, 'request-1');
    expect(requests[2].method, 'PUT');
    expect(requests[2].url.path, '/api/messaging/platforms/telegram');
    for (final request in requests.skip(1).take(4)) {
      expect(request.url.queryParameters['profile'], 'work');
    }
    expect(jsonDecode(requests[2].body), {
      'env': {'TELEGRAM_BOT_TOKEN': 'secret'},
    });
    expect(jsonDecode(requests[3].body), {
      'clear_env': ['TELEGRAM_PROXY'],
    });
    expect(requests[4].url.path, '/api/pairing');
    expect(requests[5].url.path, '/api/pairing/approve');
    expect(jsonDecode(requests[5].body), {
      'platform': 'telegram',
      'request_id': 'request-1',
    });
  });

  test(
    'direct messaging preserves profile, secret and admin contracts',
    () async {
      final requests = <http.Request>[];
      final client = _client((request) async {
        requests.add(request);
        if (request.url.path == '/api/messaging/platforms') {
          return _json({
            'platforms': [
              {
                'id': 'telegram',
                'name': 'Telegram',
                'description': 'Telegram bot',
                'docs_url': 'https://example.test/telegram',
                'env_vars': [
                  {
                    'key': 'TELEGRAM_BOT_TOKEN',
                    'prompt': 'Bot token',
                    'required': true,
                    'is_password': true,
                    'is_set': true,
                    'redacted_value': '***1234',
                  },
                ],
              },
            ],
          });
        }
        if (request.url.path == '/api/pairing') {
          return _json({
            'pending': [
              {
                'platform': 'telegram',
                'request_id': 'request-1',
                'user_id': 'user-1',
                'age_minutes': 2.5,
              },
            ],
            'approved': [
              {'platform': 'telegram', 'user_id': 'user-2', 'user_name': 'Ada'},
            ],
          });
        }
        return _json({'ok': true});
      });
      addTearDown(client.close);

      final platforms = await client.messagingPlatforms(profile: 'work');
      await client.updateMessagingPlatform(
        'telegram',
        enabled: true,
        env: {'TELEGRAM_PROXY': 'http://localhost:8080'},
        clearEnv: ['TELEGRAM_BOT_TOKEN'],
        profile: 'work',
      );
      await client.testMessagingPlatform('telegram', profile: 'work');
      final pairings = await client.messagingPairings(profile: 'work');
      await client.messagingApprovePairing(
        'telegram',
        'request-1',
        profile: 'work',
      );
      await client.messagingRevokePairing(
        'telegram',
        'user-2',
        profile: 'work',
      );
      await client.restartGateway();

      expect(platforms.single.displayName, 'Telegram');
      expect(platforms.single.envVars.single.isPassword, isTrue);
      expect(platforms.single.envVars.single.redactedValue, '***1234');
      expect(pairings.pending.single.ageMinutes, 2.5);
      expect(pairings.approved.single.userName, 'Ada');
      expect(requests[0].url.queryParameters['profile'], 'work');
      expect(requests[1].url.path, '/api/messaging/platforms/telegram');
      expect(requests[1].url.queryParameters['profile'], 'work');
      expect(jsonDecode(requests[1].body), {
        'enabled': true,
        'env': {'TELEGRAM_PROXY': 'http://localhost:8080'},
        'clear_env': ['TELEGRAM_BOT_TOKEN'],
      });
      expect(requests[2].url.path, '/api/messaging/platforms/telegram/test');
      expect(requests[3].url.path, '/api/pairing');
      expect(jsonDecode(requests[4].body), {
        'platform': 'telegram',
        'request_id': 'request-1',
        'profile': 'work',
      });
      expect(jsonDecode(requests[5].body), {
        'platform': 'telegram',
        'user_id': 'user-2',
        'profile': 'work',
      });
      expect(requests[6].url.path, '/api/gateway/restart');
    },
  );

  test('default messaging profile uses the ambient Hermes root', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      if (request.url.path == '/api/messaging/platforms') {
        return _json({
          'platforms': [
            {
              'id': 'weixin',
              'name': 'Weixin / WeChat',
              'enabled': true,
              'configured': true,
              'state': 'connected',
            },
          ],
        });
      }
      if (request.url.path == '/api/pairing') {
        return _json({'pending': <dynamic>[], 'approved': <dynamic>[]});
      }
      return _json({'ok': true});
    });
    addTearDown(client.close);

    final platforms = await client.messagingPlatforms(profile: 'default');
    await client.updateMessagingPlatform(
      'weixin',
      enabled: true,
      profile: 'default',
    );
    await client.testMessagingPlatform('weixin', profile: 'current');
    await client.messagingPairings(profile: 'default');
    await client.messagingApprovePairing(
      'weixin',
      'request-1',
      profile: 'default',
    );
    await client.messagingRevokePairing('weixin', 'user-1', profile: 'current');

    expect(platforms.single.enabled, isTrue);
    expect(platforms.single.canHandoff, isTrue);
    expect(
      requests.take(4),
      everyElement(
        predicate<http.Request>(
          (request) => !request.url.queryParameters.containsKey('profile'),
        ),
      ),
    );
    expect(jsonDecode(requests[4].body), {
      'platform': 'weixin',
      'request_id': 'request-1',
    });
    expect(jsonDecode(requests[5].body), {
      'platform': 'weixin',
      'user_id': 'user-1',
    });
  });

  test(
    'direct project and stored-session operations use gateway RPC',
    () async {
      final calls = <(String, Map<String, dynamic>)>[];
      final client = _client(
        (request) async => _json({
          'id': 'branch-1',
          'title': 'Branched',
          'parent_session_id': 'stored-1',
        }),
        gatewayRequest: (method, params, {timeout}) async {
          calls.add((method, params));
          return switch (method) {
            'projects.tree' => {
              'projects': [
                {
                  'id': 'project-1',
                  'label': 'Project',
                  'path': '/srv/project',
                  'repos': <dynamic>[],
                },
              ],
              'active_id': 'project-1',
              'scoped_session_ids': ['stored-1'],
            },
            'projects.project_sessions' => {
              'project': {
                'id': 'project-1',
                'label': 'Project',
                'path': '/srv/project',
                'repos': <dynamic>[],
              },
            },
            'projects.list' => {
              'projects': [
                {'id': 'project-1', 'path': '/srv/project'},
              ],
            },
            'session.resume' => {'session_id': 'runtime-1'},
            'session.branch' => {
              'stored_session_id': 'branch-1',
              'title': 'Branched',
            },
            _ => {'ok': true},
          };
        },
      );
      addTearDown(client.close);

      final tree = await client.projectTree(previewLimit: 4);
      final project = await client.projectSessions('project-1');
      final projects = await client.listProjects();
      await client.moveSession('stored-1', 'project-1');
      await client.setSessionWorkspace('stored-1', '/srv/other');
      final branch = await client.branchStoredSession('stored-1', keepCount: 6);
      await client.stopSessionStream('stored-1', 'stream-ignored');

      expect(tree.activeId, 'project-1');
      expect(project?.path, '/srv/project');
      expect(projects.single['id'], 'project-1');
      expect(branch.id, 'branch-1');
      expect(
        calls
            .firstWhere(
              (call) =>
                  call.$1 == 'projects.tree' && call.$2['preview_limit'] == 4,
            )
            .$2,
        {'preview_limit': 4},
      );
      final workspaceCalls = calls
          .where((call) => call.$1 == 'session.workspace.move')
          .map((call) => call.$2)
          .toList();
      expect(
        workspaceCalls.map((params) => params['session_key']),
        everyElement('stored-1'),
      );
      expect(
        workspaceCalls.map((params) => params['cwd']),
        containsAll(['/srv/project', '/srv/other']),
      );
      final branchParams = calls
          .firstWhere((call) => call.$1 == 'session.branch')
          .$2;
      expect(branchParams['session_id'], 'runtime-1');
      expect(branchParams['count'], 6);
      final interruptParams = calls
          .firstWhere((call) => call.$1 == 'session.interrupt')
          .$2;
      expect(interruptParams['session_id'], 'runtime-1');
    },
  );

  test(
    'direct duplicate imports history and title regeneration uses RPC',
    () async {
      final requests = <http.Request>[];
      final calls = <(String, Map<String, dynamic>)>[];
      String? duplicateId;
      final client = _client(
        (request) async {
          requests.add(request);
          if (request.url.path.endsWith('/messages')) {
            return _json({
              'messages': [
                {'role': 'user', 'content': 'Plan the release'},
                {'role': 'assistant', 'content': 'I will prepare it.'},
              ],
            });
          }
          if (request.url.path == '/api/sessions/import') {
            final body = jsonDecode(request.body) as Map;
            final imported = ((body['sessions'] as List).single as Map);
            duplicateId = imported['id']?.toString();
            return _json({'imported': 1});
          }
          final id = request.url.pathSegments.last;
          return _json({
            'id': id,
            'title': id == 'stored-1' ? 'Release plan' : 'Release plan (copy)',
            'source': 'mobile',
            'cwd': '/srv/project',
          });
        },
        gatewayRequest: (method, params, {timeout}) async {
          calls.add((method, params));
          return switch (method) {
            'llm.oneshot' => {'text': '  Release readiness  '},
            'session.resume' => {'session_id': 'runtime-1'},
            _ => {'ok': true},
          };
        },
      );
      addTearDown(client.close);

      final duplicate = await client.duplicateSession('stored-1');
      final title = await client.regenerateSessionTitle(
        'stored-1',
        preferLatest: true,
      );

      expect(duplicate.id, duplicateId);
      expect(duplicate.title, 'Release plan (copy)');
      expect(title, 'Release readiness');
      final importRequest = requests.firstWhere(
        (request) => request.url.path == '/api/sessions/import',
      );
      final imported =
          ((jsonDecode(importRequest.body) as Map)['sessions'] as List).single
              as Map;
      expect(imported['parent_session_id'], isNull);
      expect(imported['end_reason'], 'duplicated');
      expect(imported['messages'], hasLength(2));
      final oneShot = calls.firstWhere((call) => call.$1 == 'llm.oneshot').$2;
      expect(oneShot['input'], contains('Plan the release'));
      final titleCall = calls
          .firstWhere((call) => call.$1 == 'session.title')
          .$2;
      expect(titleCall['session_id'], 'runtime-1');
      expect(titleCall['title'], 'Release readiness');
    },
  );

  test('direct pet RPC uses Gateway methods and camelCase responses', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final client = _client(
      (_) async => _json({'ok': true}),
      gatewayRequest: (method, params, {timeout}) async {
        calls.add((method, params));
        return switch (method) {
          'pet.info' => {
            'enabled': true,
            'slug': 'moxie',
            'displayName': 'Moxie',
            'spritesheetBase64': 'cG5n',
            'frameW': 32,
            'frameH': 32,
            'framesByState': {'idle': 4},
            'loopMs': 800,
          },
          'pet.gallery' => {
            'pets': [
              {'slug': 'moxie', 'displayName': 'Moxie'},
            ],
          },
          _ => {'ok': true},
        };
      },
    );
    addTearDown(client.close);

    final info = await client.petInfo();
    final gallery = await client.petGallery();
    await client.petSelect('moxie');
    await client.petRename('moxie', 'Nova');
    await client.petDisable();

    expect(info.displayName, 'Moxie');
    expect(info.framesByState, {'idle': 4});
    expect(gallery.single.displayName, 'Moxie');
    expect(calls.firstWhere((call) => call.$1 == 'pet.select').$2, {
      'slug': 'moxie',
    });
    expect(calls.firstWhere((call) => call.$1 == 'pet.rename').$2, {
      'slug': 'moxie',
      'name': 'Nova',
    });
    expect(calls.firstWhere((call) => call.$1 == 'pet.disable').$2, isEmpty);
  });

  test('direct billing RPC canonicalizes mutation parameters', () async {
    final calls = <(String, Map<String, dynamic>)>[];
    final client = _client(
      (_) async => _json({'ok': true}),
      gatewayRequest: (method, params, {timeout}) async {
        calls.add((method, params));
        return switch (method) {
          'billing.state' => {'ok': true, 'balance_usd': '19.75'},
          'billing.charge_status' => {'ok': true, 'status': 'succeeded'},
          'usage.bars' => {
            'ok': true,
            'plan_bar': {'spent_display': r'$4.00', 'total_display': r'$20.00'},
          },
          'subscription.state' => {
            'ok': true,
            'current': {'tier_id': 'pro', 'tier_name': 'Pro'},
          },
          _ => {'ok': true},
        };
      },
    );
    addTearDown(client.close);

    expect((await client.billingState()).balance, 19.75);
    expect((await client.subscriptionState()).typeId, 'pro');
    await client.billingCharge(25);
    await client.billingChargeStatus('charge-1');
    await client.billingStepUp(sessionId: 'sess-1');
    await client.updateAutoReload(true, 10, 50);
    await client.subscriptionPreview({'target_plan': 'team'});
    await client.subscriptionChange({'cancel_at_period_end': true});

    expect(calls.firstWhere((call) => call.$1 == 'billing.charge').$2, {
      'amount_usd': '25.0',
    });
    expect(calls.firstWhere((call) => call.$1 == 'billing.charge_status').$2, {
      'charge_id': 'charge-1',
    });
    expect(calls.firstWhere((call) => call.$1 == 'billing.step_up').$2, {
      'session_id': 'sess-1',
    });
    expect(calls.firstWhere((call) => call.$1 == 'billing.auto_reload').$2, {
      'enabled': true,
      'threshold': 10.0,
      'top_up_amount': 50.0,
    });
    expect(calls.firstWhere((call) => call.$1 == 'subscription.preview').$2, {
      'subscription_type_id': 'team',
    });
    expect(calls.firstWhere((call) => call.$1 == 'subscription.change').$2, {
      'cancel': true,
    });
  });

  test('direct structured RPC failures become ApiException', () async {
    final client = _client(
      (_) async => _json({'ok': true}),
      gatewayRequest: (_, _, {timeout}) async => {
        'ok': false,
        'error': 'insufficient_scope',
        'message': 'Billing permission required',
      },
    );
    addTearDown(client.close);

    await expectLater(
      client.billingCharge(10),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Billing permission required'),
        ),
      ),
    );
  });

  test('direct memory provider and curator contracts preserve scope', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      return _json({
        'ok': true,
        if (request.url.path.endsWith('/config')) 'fields': <Object>[],
        if (request.url.path.endsWith('/oauth/status')) 'state': 'idle',
      });
    });
    addTearDown(client.close);

    await client.memoryStatus(profile: 'work');
    await client.memorySetProvider('honcho', profile: 'work');
    await client.memoryReset(target: 'user', profile: 'work');
    await client.memoryProviderConfig('honcho', profile: 'work');
    await client.saveMemoryProviderConfig('honcho', {
      'apiKey': 'secret',
    }, profile: 'work');
    await client.startMemoryProviderOAuth('honcho', profile: 'work');
    await client.memoryProviderOAuthStatus('honcho', profile: 'work');
    await client.curatorStatus();
    await client.setCuratorPaused(true);
    await client.runCurator();

    expect(requests.map((request) => '${request.method} ${request.url.path}'), [
      'GET /api/memory',
      'PUT /api/memory/provider',
      'POST /api/memory/reset',
      'GET /api/memory/providers/honcho/config',
      'PUT /api/memory/providers/honcho/config',
      'POST /api/memory/providers/honcho/oauth/start',
      'GET /api/memory/providers/honcho/oauth/status',
      'GET /api/curator',
      'PUT /api/curator/paused',
      'POST /api/curator/run',
    ]);
    for (final request in requests.take(7)) {
      expect(request.url.queryParameters['profile'], 'work');
    }
    expect(jsonDecode(requests[2].body), {'target': 'user'});
    expect(jsonDecode(requests[4].body), {
      'values': {'apiKey': 'secret'},
    });
    expect(jsonDecode(requests[8].body), {'paused': true});
  });

  test('direct Git review uses canonical ship and PR routes', () async {
    final requests = <http.Request>[];
    final client = _client((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/review/list')) {
        return _json({'files': <Object>[]});
      }
      if (request.url.path.endsWith('/review/diff')) {
        return _json({'diff': '@@ changed'});
      }
      if (request.url.path.endsWith('/review/ship-info')) {
        return _json({
          'ghReady': true,
          'pr': {'number': 7, 'url': 'https://example.test/pr/7'},
        });
      }
      if (request.url.path.endsWith('/review/pr-list')) {
        return _json({
          'prs': [
            {'number': 7, 'branch': 'feature'},
          ],
        });
      }
      return _json({'url': 'https://example.test/pr/7'});
    });
    addTearDown(client.close);

    await client.gitReviewList('/repo', base: 'main');
    expect(
      await client.gitReviewDiff('/repo', 'lib/a.dart', staged: true),
      '@@ changed',
    );
    expect((await client.gitShipInfo('/repo'))['ghReady'], isTrue);
    expect(
      (await client.gitPullRequests(
        '/repo',
        branches: ['feature'],
      )).single['number'],
      7,
    );
    expect((await client.gitPrCreate('/repo')).url, contains('/pr/7'));

    expect(requests.map((request) => request.url.path), [
      '/api/git/review/list',
      '/api/git/review/diff',
      '/api/git/review/ship-info',
      '/api/git/review/pr-list',
      '/api/git/review/create-pr',
    ]);
    expect(requests[0].url.queryParameters['base'], 'main');
    expect(requests[1].url.queryParameters['staged'], 'true');
    expect(jsonDecode(requests[3].body), {
      'path': '/repo',
      'branches': ['feature'],
      'numbers': <int>[],
    });
  });

  test(
    'direct Git commit suggestion uses commit context and oneshot RPC',
    () async {
      final rpcCalls = <(String, Map<String, dynamic>)>[];
      final client = _client(
        (request) async => _json({
          'diff': '+new line',
          'recent': ['previous commit'],
        }),
        gatewayRequest: (method, params, {timeout}) async {
          rpcCalls.add((method, params));
          return {'text': 'feat: add new line'};
        },
      );
      addTearDown(client.close);

      final suggestion = await client.gitCommitMessage('/repo');

      expect(suggestion.message, 'feat: add new line');
      expect(rpcCalls.single.$1, 'llm.oneshot');
      expect(rpcCalls.single.$2['template'], 'commit_message');
      expect((rpcCalls.single.$2['variables'] as Map)['diff'], '+new line');
    },
  );

  test('transport capabilities expose only implemented operations', () {
    final direct = _client((_) async => _json({'ok': true}));
    final companion = ApiClient(
      baseUrl: 'https://companion.example',
      apiKey: 'secret',
      client: MockClient((_) async => _json({'ok': true})),
    );
    addTearDown(direct.close);
    addTearDown(companion.close);

    expect(direct.capabilities.methodDiscovery, isFalse);
    expect(direct.capabilities.backendRestart, isFalse);
    expect(direct.capabilities.serverLogs, isFalse);
    expect(direct.capabilities.sessionSharing, isFalse);
    expect(direct.capabilities.fileMove, isFalse);
    expect(direct.capabilities.fileCopy, isFalse);
    expect(direct.capabilities.fileReveal, isFalse);
    expect(direct.capabilities.terminalExecute, isFalse);

    expect(companion.capabilities.methodDiscovery, isTrue);
    expect(companion.capabilities.backendRestart, isTrue);
    expect(companion.capabilities.serverLogs, isTrue);
    expect(companion.capabilities.sessionSharing, isTrue);
    expect(companion.capabilities.fileMove, isTrue);
    expect(companion.capabilities.fileCopy, isTrue);
    expect(companion.capabilities.fileReveal, isTrue);
    expect(companion.capabilities.terminalExecute, isTrue);
  });

  test(
    'direct petGenerate forwards the 300s budget past the gateway default',
    () async {
      Duration? seenTimeout;
      final client = _client(
        (_) async => _json({'ok': true}),
        gatewayRequest: (method, params, {timeout}) async {
          expect(method, 'pet.generate');
          seenTimeout = timeout;
          return {'ok': true, 'slug': 'nova'};
        },
      );
      addTearDown(client.close);

      final result = await client.petGenerate({'slug': 'nova'});

      expect(result['slug'], 'nova');
      // The server allows this operation up to 300s — must not fall back to
      // `HermesPolicy.gatewayTimeout` (120s), which would abort client-side
      // while the server is still legitimately working.
      expect(seenTimeout, const Duration(seconds: 300));
    },
  );

  test(
    'Kanban event URI follows transport path and refreshes OAuth token',
    () async {
      var tokenGeneration = 0;
      final direct = ApiClient(
        baseUrl: 'https://gateway.example',
        apiKey: 'stale-key',
        directGateway: true,
        accessTokenProvider: () async => 'fresh-${++tokenGeneration}',
        client: MockClient((_) async => _json({'ok': true})),
      );
      final companion = ApiClient(
        baseUrl: 'http://mobile.example',
        apiKey: 'mobile-key',
        client: MockClient((_) async => _json({'ok': true})),
      );
      addTearDown(direct.close);
      addTearDown(companion.close);

      final first = await direct.kanbanEventsUri(board: 'team', since: 4);
      final second = await direct.kanbanEventsUri(board: 'team', since: 5);
      final proxied = await companion.kanbanEventsUri(board: 'team', since: 6);

      expect(first.scheme, 'wss');
      expect(first.path, '/api/plugins/kanban/events');
      expect(first.queryParameters['token'], 'fresh-1');
      expect(second.queryParameters['token'], 'fresh-2');
      expect(second.queryParameters['since'], '5');
      expect(proxied.scheme, 'ws');
      expect(proxied.path, '/api/v1/kanban/events');
      expect(proxied.queryParameters['token'], 'mobile-key');
    },
  );
}
