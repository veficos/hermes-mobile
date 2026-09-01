/// Widget tests for the WebUI-parity composer work:
/// - busy primary-action state machine (idle send / busy steer / busy stop),
///   mirroring WebUI `getComposerPrimaryAction` (ui.js:7831)
/// - attachment tray: real picker callbacks instead of placeholder chips
/// - steer failure falls back to the send queue (WebUI `_trySteer`), with the
///   queue strip above the composer showing per-item management.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

class _FakeGateway extends GatewayClient {
  _FakeGateway()
    : super(serverBaseUrl: 'http://contract.invalid', apiKey: 'test');

  final List<(String, Map<String, dynamic>)> calls = [];
  bool steerFails = false;
  final List<Completer<Map<String, dynamic>>> promptGates = [];

  @override
  bool get isConnected => true;

  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) {
    calls.add((method, params));
    switch (method) {
      case 'session.create':
        return Future.value({
          'session_id': 'rt-1',
          'stored_session_id': 'sid-1',
        });
      case 'session.steer':
        if (steerFails) return Future.error(StateError('steer rejected'));
        return Future.value({'accepted': true});
      case 'prompt.submit':
        // Block until the test releases the gate so the turn stays in flight
        // and the busy composer state machine can be exercised.
        final gate = Completer<Map<String, dynamic>>();
        promptGates.add(gate);
        return gate.future;
      default:
        return Future.value(<String, dynamic>{});
    }
  }

  List<String> textsFor(String method) => calls
      .where((c) => c.$1 == method)
      .map((c) => c.$2['text']?.toString() ?? '')
      .toList();
}

class _FakeConnection extends ConnectionStore {
  _FakeConnection(_FakeGateway gw, ApiClient apiClient) {
    gateway = gw;
    api = apiClient;
  }

  @override
  Future<void> ensureConnected() async {}
}

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => const {};

  @override
  Future<ProfilesPayload> listProfiles() async =>
      const ProfilesPayload(profiles: [], active: null, source: 'local');

  @override
  Future<List<ToolsetInfo>> toolsets({String? profile}) async => const [];

  @override
  Future<String> fsDefaultCwd() async => 'D:/work/repo';

  @override
  Future<List<Map<String, dynamic>>> listProjects() async => const [];

  @override
  Future<ComposerDraft> getDraft(String sessionId) async =>
      const ComposerDraft();

  @override
  Future<ComposerDraft> saveDraft(
    String sessionId, {
    String? text,
    List<dynamic>? files,
  }) async => const ComposerDraft();
}

// ---------------------------------------------------------------- helpers

Future<void> _pumpBareComposer(
  WidgetTester tester, {
  bool busy = false,
  TextEditingController? controller,
  ValueChanged<String>? onSend,
  ValueChanged<String>? onSteer,
  VoidCallback? onStop,
  List<ComposerAttachment> attachments = const [],
  ValueChanged<List<ComposerAttachment>>? onAttachmentsChanged,
}) async {
  controller ??= TextEditingController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HermesComposer(
          controller: controller,
          busy: busy,
          onSend: onSend ?? (_) {},
          onSteer: onSteer,
          onStop: onStop,
          attachments: attachments,
          onAttachmentsChanged: onAttachmentsChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ChatRig {
  _ChatRig() : gateway = _FakeGateway(), api = _FakeApi() {
    connection = _FakeConnection(gateway, api);
    chat = ChatStore();
    session = SessionStore(
      connection: connection,
      chat: chat,
      requests: RequestStore(),
    );
  }

  final _FakeGateway gateway;
  final _FakeApi api;
  late final ConnectionStore connection;
  late final ChatStore chat;
  late final SessionStore session;

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectionStore>.value(value: connection),
      ChangeNotifierProvider.value(value: session),
      ChangeNotifierProvider.value(value: chat),
      ChangeNotifierProvider.value(value: VoiceStore(connection: connection)),
      ChangeNotifierProvider.value(value: CommandStore(connection: connection)),
    ],
    child: const MaterialApp(home: ChatScreen()),
  );

  void releasePrompts() {
    for (final gate in gateway.promptGates) {
      if (!gate.isCompleted) gate.complete(<String, dynamic>{});
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group(
    'busy primary action state machine (WebUI getComposerPrimaryAction)',
    () {
      testWidgets('composer does not restore the previous global input', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({
          'hm_composer_draft_v1': 'stale global input',
        });
        final first = TextEditingController();
        await _pumpBareComposer(tester, controller: first);
        await tester.enterText(find.byType(TextField), 'latest input');
        await tester.pump();

        await tester.pumpWidget(const SizedBox.shrink());
        final second = TextEditingController();
        await _pumpBareComposer(tester, controller: second);

        expect(second.text, isEmpty);
        expect(find.text('stale global input'), findsNothing);
        expect(find.text('latest input'), findsNothing);
        first.dispose();
        second.dispose();
      });

      testWidgets('idle + text → send', (tester) async {
        final sent = <String>[];
        final controller = TextEditingController();
        await _pumpBareComposer(
          tester,
          controller: controller,
          onSend: sent.add,
        );
        expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();

        expect(sent, ['hello']);
        expect(controller.text, isEmpty);
        controller.dispose();
      });

      testWidgets('busy + no text → stop', (tester) async {
        var stops = 0;
        final steered = <String>[];
        await _pumpBareComposer(
          tester,
          busy: true,
          onStop: () => stops++,
          onSteer: steered.add,
        );
        expect(find.byIcon(Icons.stop), findsOneWidget);

        await tester.tap(find.byIcon(Icons.stop));
        await tester.pump();

        expect(stops, 1);
        expect(steered, isEmpty);
      });

      testWidgets('busy + text → steer, not stop', (tester) async {
        var stops = 0;
        final steered = <String>[];
        final controller = TextEditingController();
        await _pumpBareComposer(
          tester,
          busy: true,
          controller: controller,
          onStop: () => stops++,
          onSteer: steered.add,
        );

        await tester.enterText(find.byType(TextField), 'guide the turn');
        await tester.pump();
        // Busy + draft → compass (steer) icon, accent instead of red stop.
        expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsNothing);

        await tester.tap(find.byIcon(Icons.explore_outlined));
        await tester.pump();

        expect(steered, ['guide the turn']);
        expect(stops, 0);
        expect(controller.text, isEmpty);
        controller.dispose();
      });
    },
  );

  group('attachment tray (no placeholder chips)', () {
    testWidgets('empty tray renders no add entry; only staged chips show', (
      tester,
    ) async {
      await _pumpBareComposer(tester, onAttachmentsChanged: (_) {});

      // The tray's old "附加" add menu is gone — adding happens through the
      // composer footer icon buttons wired by the chat screen.
      expect(find.text('附加'), findsNothing);
      expect(
        find.byType(PopupMenuButton<ComposerAttachmentKind>),
        findsNothing,
      );
    });

    testWidgets('staged chip shows pending-upload marker and can be removed', (
      tester,
    ) async {
      final attachments = [
        const ComposerAttachment(
          kind: ComposerAttachmentKind.file,
          label: 'report.pdf',
          localPath: '/tmp/report.pdf',
        ),
      ];
      final changed = <List<ComposerAttachment>>[];
      await _pumpBareComposer(
        tester,
        attachments: attachments,
        onAttachmentsChanged: changed.add,
      );

      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(changed, hasLength(1));
      expect(changed.single, isEmpty);
    });
  });

  group('chat screen integration (fake gateway, no mocks of UI)', () {
    testWidgets('busy send steers the running turn via session.steer', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      // First turn: real prompt.submit that stays in flight (busy).
      await tester.enterText(find.byType(TextField).first, 'first turn');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump();
      expect(rig.gateway.textsFor('prompt.submit'), ['first turn']);
      expect(rig.chat.busy, isTrue);

      // Busy + draft → primary button is steer.
      await tester.enterText(find.byType(TextField).first, 'guide it');
      await tester.pump();
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.explore_outlined));
      await tester.pump();
      await tester.pump();

      expect(rig.gateway.textsFor('session.steer'), ['guide it']);
      expect(find.text('引导消息已注入当前回合'), findsOneWidget);
      // Queue fallback must NOT have fired.
      expect(find.textContaining('队列'), findsNothing);

      rig.releasePrompts();
      rig.connection.dispose();
    });

    testWidgets('queue/voice/tts/more live in the composer card; no settings '
        'or new-chat buttons', (tester) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      // The default widget-test viewport uses the compact composer. Its
      // secondary actions remain inside the composer card behind the + row.
      if (find.byTooltip('发送队列').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('展开工具'));
        await tester.pumpAndSettle();
      }

      // Migrated into the composer footer. Voice dictation + auto-TTS are
      // consolidated into one HermesVoiceMenu (tooltip 语音菜单).
      expect(find.byTooltip('发送队列'), findsOneWidget);
      expect(find.byTooltip('语音菜单'), findsOneWidget);
      expect(find.byTooltip('更多'), findsWidgets);
      // Removed per request.
      expect(find.byTooltip('设置'), findsNothing);
      expect(find.byTooltip('新建会话'), findsNothing);

      // The attach entry is a single merged menu in the composer footer.
      expect(find.byTooltip('添加文件'), findsOneWidget);
      await tester.tap(find.byTooltip('添加文件'));
      await tester.pumpAndSettle();
      expect(find.text('文件'), findsOneWidget);
      expect(find.text('文件夹'), findsOneWidget);
      expect(find.text('文本片段'), findsOneWidget);

      rig.connection.dispose();
    });

    testWidgets(
      'steer failure falls back to the queue; strip shows count, expands and '
      'deletes per item',
      (tester) async {
        final rig = _ChatRig()..gateway.steerFails = true;
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();

        // Turn 1 in flight.
        await tester.enterText(find.byType(TextField).first, 'turn one');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.arrow_upward));
        await tester.pump();
        await tester.pump();
        expect(rig.chat.busy, isTrue);

        // Busy submit #2: steer fails → queued → drained into a second
        // in-flight submit (gate 2), so nothing lingers in the queue yet.
        await tester.enterText(find.byType(TextField).first, 'second');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.explore_outlined));
        await tester.pump();
        await tester.pump();
        expect(rig.gateway.textsFor('session.steer'), ['second']);
        expect(rig.gateway.textsFor('prompt.submit'), ['turn one', 'second']);

        // Busy submit #3: queue drain is busy, so this one stays queued and
        // the strip above the composer appears.
        await tester.enterText(find.byType(TextField).first, 'third');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.explore_outlined));
        await tester.pump();
        await tester.pump();

        expect(
          find.byKey(const ValueKey('composer-status-bar')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('展开详情'));
        await tester.pump();
        expect(find.text('队列 1 条 · 点击展开'), findsOneWidget);

        // Expand → per-item management.
        await tester.tap(find.text('队列 1 条 · 点击展开'));
        await tester.pump();
        expect(find.text('队列 1 条 · 点击收起'), findsOneWidget);
        expect(find.text('third'), findsOneWidget);
        expect(find.text('全部取消'), findsOneWidget);

        // Delete the single queued item → strip disappears (the snackbar
        // copy mentions 队列, so assert on the strip-specific label).
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        await tester.pump();
        expect(find.text('队列 1 条 · 点击展开'), findsNothing);
        expect(find.text('队列 1 条 · 点击收起'), findsNothing);
        expect(rig.session.queueCount, 0);

        rig.releasePrompts();
        rig.connection.dispose();
      },
    );
  });
}
