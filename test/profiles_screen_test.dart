import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/profiles_screen.dart';
import 'package:provider/provider.dart';

/// Contract fake: profiles come from the real `/api/v1/profiles` surface,
/// never from hardcoded sample data.
class _FakeProfilesApi extends ApiClient {
  _FakeProfilesApi({required this.payload})
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  ProfilesPayload payload;
  String? activated;
  String? deleted;
  Map<String, dynamic>? saved;

  @override
  Future<ProfilesPayload> listProfiles() async => payload;

  @override
  Future<List<ModelInfo>> modelOptions() async => const [
    ModelInfo(
      slug: 'nous',
      name: 'Nous',
      isCurrent: true,
      models: ['hermes-4'],
    ),
  ];

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => [
    ToolsetInfo(name: 'fs', enabled: true, toolCount: 4),
  ];

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => {
    'profile': profile,
  };

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async =>
      const SessionPage(sessions: [], total: 0, offset: 0, hasMore: false);

  @override
  Future<Map<String, dynamic>> activateProfile(String name) async {
    activated = name;
    payload = ProfilesPayload(
      profiles: [
        for (final p in payload.profiles) p.copyWith(isActive: p.name == name),
      ],
      active: name,
      source: payload.source,
    );
    return {'ok': true, 'active': name};
  }

  @override
  Future<void> deleteProfile(String name) async {
    deleted = name;
  }

  @override
  Future<ProfileInfo> saveProfile(Map<String, dynamic> profile) async {
    saved = profile;
    return ProfileInfo.fromJson(profile);
  }
}

class _DelayedProfilesApi extends _FakeProfilesApi {
  _DelayedProfilesApi({required super.payload});

  final response = Completer<ProfilesPayload>();

  @override
  Future<ProfilesPayload> listProfiles() => response.future;
}

ProfileInfo _profile(String name, {bool active = false}) => ProfileInfo(
  name: name,
  model: 'hermes-4',
  provider: 'nous',
  temperature: 0.4,
  maxTokens: 8192,
  isActive: active,
  description: '真实后端配置',
);

Widget _app(ConnectionStore connection) {
  final session = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: connection),
      ChangeNotifierProvider.value(value: session),
    ],
    child: const MaterialApp(home: ProfilesScreen()),
  );
}

void main() {
  testWidgets('Profiles screen renders real API data, no mock profiles', (
    tester,
  ) async {
    final api = _FakeProfilesApi(
      payload: ProfilesPayload(
        profiles: [_profile('调研助手', active: true), _profile('写作搭档')],
        active: '调研助手',
        source: 'upstream',
      ),
    );
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_app(connection));
    await tester.pumpAndSettle();

    // Real backend rows render.
    expect(find.text('调研助手'), findsOneWidget);
    expect(find.text('写作搭档'), findsOneWidget);
    expect(find.text('nous · hermes-4'), findsNWidgets(2));
    // One "激活" status chip (调研助手, active) + one "激活" button on the
    // inactive row (写作搭档) — direct-tap activation, prototype parity.
    expect(find.text('激活'), findsNWidgets(2));

    // The old hardcoded samples are gone.
    expect(find.text('默认助手'), findsNothing);
    expect(find.text('代码专家'), findsNothing);
    expect(find.text('创意写作'), findsNothing);
    expect(find.text('OpenAI · gpt-4o'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });

  testWidgets('Profiles screen shows a real empty state', (tester) async {
    final api = _FakeProfilesApi(
      payload: const ProfilesPayload(profiles: [], source: 'local'),
    );
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_app(connection));
    await tester.pumpAndSettle();

    expect(find.text('暂无配置'), findsOneWidget);
    expect(find.text('调研助手'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });

  testWidgets('Activating a profile calls the real activate endpoint', (
    tester,
  ) async {
    final api = _FakeProfilesApi(
      payload: ProfilesPayload(
        profiles: [_profile('调研助手', active: true), _profile('写作搭档')],
        active: '调研助手',
        source: 'local',
      ),
    );
    final connection = ConnectionStore()..api = api;

    await tester.pumpWidget(_app(connection));
    await tester.pumpAndSettle();

    // Activation is a direct-tap button on the inactive row (prototype
    // parity), not buried behind the overflow menu.
    await tester.tap(find.widgetWithText(TextButton, '激活'));
    await tester.pumpAndSettle();

    expect(api.activated, '写作搭档');
    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });

  testWidgets('an old connection response cannot overwrite new profiles', (
    tester,
  ) async {
    final oldApi = _DelayedProfilesApi(
      payload: ProfilesPayload(profiles: [_profile('旧连接配置')], source: 'old'),
    );
    final newApi = _FakeProfilesApi(
      payload: ProfilesPayload(profiles: [_profile('新连接配置')], source: 'new'),
    );
    final connection = ConnectionStore()..api = oldApi;

    await tester.pumpWidget(_app(connection));
    await tester.pump();
    connection.api = newApi;
    connection.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('新连接配置'), findsOneWidget);
    oldApi.response.complete(oldApi.payload);
    await tester.pumpAndSettle();

    expect(find.text('新连接配置'), findsOneWidget);
    expect(find.text('旧连接配置'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    connection.dispose();
  });
}
