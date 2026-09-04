/// Widget / logic tests for the WebUI minor-parity batch:
/// - B4: inline message editing (`.msg-edit-area`) instead of a dialog,
///   still re-sent through the real rewind/edit gateway chain.
/// - Emoji picker: composer toggle button opens an emoji grid that inserts
///   plain-text emoji at the cursor.
/// - A12: phone layouts expose the workspace file panel via an end drawer.
/// - C11: AppBar menu "重新生成标题" → POST /sessions/{id}/title/regenerate.
/// - C12: AppBar menu "复制会话链接" → `{base}/session/{id}` on clipboard.
/// - A17: composer ambient context-usage indicator from real accumulated
///   per-turn usage (nothing rendered when no usage data exists).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------- fakes

class _FakeGateway extends GatewayClient {
  _FakeGateway()
    : super(serverBaseUrl: 'http://contract.invalid', apiKey: 'test');

  final List<(String, Map<String, dynamic>)> calls = [];

  /// When true, the next `prompt.submit` with `confirm_truncate` throws.
  bool failNextTruncateSubmit = false;

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
      case 'session.usage':
        return Future.value({
          'input_tokens': 87040,
          'output_tokens': 4096,
          'total_tokens': 91136,
        });
      case 'session.context_breakdown':
        return Future.value({
          'categories': {'messages': 70000, 'system': 17040},
          'context_used': 87040,
          'context_max': 128000,
          'context_percent': 68,
          'estimated_total': 87040,
          'model': 'test/model',
        });
      case 'session.compress':
        return Future.value({'ok': true});
      case 'prompt.submit':
        if (failNextTruncateSubmit && params['confirm_truncate'] == true) {
          failNextTruncateSubmit = false;
          return Future.error(GatewayException(-32000, 'edit failed'));
        }
        return Future.value(<String, dynamic>{});
      default:
        return Future.value(<String, dynamic>{});
    }
  }
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

  final List<(String, bool)> titleRegenCalls = [];
  final List<String> shareCalls = [];

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
  Future<ComposerDraft> getDraft(String sessionId, {String? profile}) async =>
      const ComposerDraft();

  @override
  Future<ComposerDraft> saveDraft(
    String sessionId, {
    String? text,
    List<dynamic>? files,
    String? profile,
  }) async => const ComposerDraft();

  @override
  Future<SessionPage> listSessionsPage({
    int limit = 50,
    int offset = 0,
    bool includeArchived = false,
    String? profile,
  }) async => const SessionPage(sessions: [], offset: 0, hasMore: false);

  @override
  Future<String> regenerateSessionTitle(
    String id, {
    bool preferLatest = false,
    String? profile,
  }) async {
    titleRegenCalls.add((id, preferLatest));
    return '自动标题';
  }

  @override
  Future<Map<String, dynamic>> createSessionShare(
    String id, {
    String? profile,
  }) async {
    shareCalls.add(id);
    return {
      'share': {'url': 'http://contract.invalid/share/token-1'},
    };
  }
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

  /// Send one turn through the real composer and wait for it to settle, so
  /// the session gains a durable id and a user bubble exists.
  Future<void> sendFirstTurn(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    await tester.pump();
    expect(session.durableId, 'sid-1');
  }
}

/// Long-press the message bubble's padding area (right of the text). The
/// bubble text is selectable, so pressing directly on it starts text
/// selection instead of opening the message menu.
Future<void> _longPressBubble(WidgetTester tester, String text) async {
  final rect = tester.getRect(find.text(text));
  await tester.longPressAt(Offset(rect.right + 4, rect.center.dy));
}

Future<void> _pumpBareComposer(
  WidgetTester tester, {
  TextEditingController? controller,
  String? ctxUsageLabel,
}) async {
  controller ??= TextEditingController();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HermesComposer(
          controller: controller,
          onSend: (_) {},
          ctxUsageLabel: ctxUsageLabel,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('B4 inline message editing (WebUI .msg-edit-area)', () {
    Finder cancelButton() {
      // Desktop (Linux/macOS/Windows in tests) keeps the Esc hint; touch
      // platforms drop it. Match whichever label is currently rendered.
      final withEsc = find.text('取消 (Esc)');
      if (withEsc.evaluate().isNotEmpty) return withEsc;
      return find.text('取消');
    }

    /// Rewind/edit schedules a 400ms inflight-persist timer; drain it so the
    /// binding does not assert on pending timers at test end.
    Future<void> drainEditSideEffects(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 450));
      await tester.pump();
    }

    testWidgets('menu 编辑 swaps the bubble for an in-place editor; confirm '
        're-sends through the rewind/edit gateway chain', (tester) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');

      // Long-press the user bubble → message menu → 编辑. The text itself is
      // selectable, so aim at the bubble padding right of the text where the
      // list-level GestureDetector wins the gesture arena.
      await _longPressBubble(tester, 'first turn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // The bubble is replaced by the inline editor (no dialog).
      expect(find.text('发送编辑'), findsOneWidget);
      expect(cancelButton(), findsOneWidget);
      final editor = find.widgetWithText(TextField, 'first turn');
      expect(editor, findsOneWidget);

      // Edit in place and confirm (sole user turn → no truncate dialog).
      await tester.enterText(editor, 'edited turn');
      await tester.pump();
      await tester.tap(find.text('发送编辑'));
      await tester.pump();
      await tester.pump();
      await drainEditSideEffects(tester);

      // Real rewind chain: prompt.submit with truncate confirmation and the
      // edited text; the transcript rewinds to the edited user message.
      final submits = rig.gateway.calls
          .where((c) => c.$1 == 'prompt.submit')
          .map((c) => c.$2)
          .toList();
      expect(submits, hasLength(2));
      expect(submits.last['text'], 'edited turn');
      expect(submits.last['confirm_truncate'], isTrue);
      expect(submits.last['truncate_before_user_ordinal'], 0);
      // Editor is gone after submit.
      expect(find.text('发送编辑'), findsNothing);
      expect(find.text('edited turn'), findsOneWidget);

      rig.connection.dispose();
    });

    testWidgets('cancel restores the bubble without any gateway call', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');

      await _longPressBubble(tester, 'first turn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      expect(find.text('发送编辑'), findsOneWidget);

      await tester.tap(cancelButton());
      await tester.pumpAndSettle();

      expect(find.text('发送编辑'), findsNothing);
      expect(find.text('first turn'), findsOneWidget);
      // Only the original send reached the gateway.
      expect(
        rig.gateway.calls.where((c) => c.$1 == 'prompt.submit'),
        hasLength(1),
      );

      rig.connection.dispose();
    });

    testWidgets('subsequent turns require truncate confirmation before edit', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');

      final user = rig.chat.messages.firstWhere((m) => m.role == 'user');
      rig.chat.loadHistory([
        user,
        ChatMessage(
          id: 'a1',
          role: 'assistant',
          parts: [ChatPart.text('assistant reply')],
        ),
      ], hasMore: false);
      await tester.pumpAndSettle();

      await _longPressBubble(tester, 'first turn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      final editor = find.widgetWithText(TextField, 'first turn');
      await tester.enterText(editor, 'edited with later turns');
      await tester.pump();
      await tester.tap(find.text('发送编辑'));
      await tester.pumpAndSettle();

      expect(find.text('发送编辑？'), findsOneWidget);
      expect(find.text('发送编辑并重新运行'), findsOneWidget);

      // Dismiss via the confirm dialog's cancel (not the editor button).
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('取消'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        rig.gateway.calls.where((c) => c.$1 == 'prompt.submit'),
        hasLength(1),
      );
      expect(find.text('发送编辑'), findsOneWidget);

      // Confirm → rewind chain runs.
      await tester.tap(find.text('发送编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('发送编辑并重新运行'));
      await tester.pump();
      await tester.pump();
      await drainEditSideEffects(tester);

      final submits = rig.gateway.calls
          .where((c) => c.$1 == 'prompt.submit')
          .map((c) => c.$2)
          .toList();
      expect(submits, hasLength(2));
      expect(submits.last['text'], 'edited with later turns');
      expect(submits.last['confirm_truncate'], isTrue);
      expect(find.text('发送编辑'), findsNothing);

      rig.connection.dispose();
    });

    testWidgets('failed edit keeps the draft in the inline editor', (
      tester,
    ) async {
      final rig = _ChatRig();
      rig.gateway.failNextTruncateSubmit = true;
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');

      await _longPressBubble(tester, 'first turn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      final editor = find.widgetWithText(TextField, 'first turn');
      await tester.enterText(editor, 'draft that must survive');
      await tester.pump();
      await tester.tap(find.text('发送编辑'));
      await tester.pump();
      await tester.pump();
      await drainEditSideEffects(tester);
      await tester.pumpAndSettle();

      expect(find.text('发送编辑'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'draft that must survive'),
        findsOneWidget,
      );
      expect(find.textContaining('编辑失败'), findsOneWidget);
      // Original bubble text restored in the transcript under the still-open
      // editor (optimistic rewind rolled back); draft stays in the TextField.
      expect(rig.chat.messages.single.fullText, 'first turn');

      rig.connection.dispose();
    });

    testWidgets('touch platforms omit Esc / Enter shortcut hints', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'first turn');

      await _longPressBubble(tester, 'first turn');
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      expect(find.text('取消'), findsOneWidget);
      expect(find.text('取消 (Esc)'), findsNothing);

      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'first turn'),
      );
      expect(field.decoration?.hintText, '编辑消息…');

      debugDefaultTargetPlatformOverride = null;
      rig.connection.dispose();
    });
  });

  group('emoji picker', () {
    testWidgets('toggle opens a grid; tapping inserts emoji at the cursor', (
      tester,
    ) async {
      final controller = TextEditingController();
      await _pumpBareComposer(tester, controller: controller);

      expect(find.byIcon(Icons.emoji_emotions_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
      await tester.pumpAndSettle();
      expect(find.text('表情'), findsOneWidget);
      expect(find.text('😀'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      // Move the cursor into the middle, then insert.
      controller.selection = const TextSelection.collapsed(offset: 2);
      await tester.tap(find.text('😀'));
      await tester.pump();

      expect(controller.text, 'he😀llo');
      expect(controller.selection.baseOffset, 2 + '😀'.length);

      // Panel stays open for multiple inserts; close via the close icon.
      await tester.tap(find.text('😂'));
      await tester.pump();
      expect(controller.text, 'he😀😂llo');
      await tester.tap(find.byTooltip('关闭表情面板').last);
      await tester.pumpAndSettle();
      expect(find.text('😀'), findsNothing);

      controller.dispose();
    });
  });

  group('A17 composer context-usage indicator', () {
    test(
      'cumulativeUsageTokens sums real per-turn usage, null without data',
      () {
        final chat = ChatStore();
        expect(chat.cumulativeUsageTokens, isNull);

        chat.loadHistory([
          ChatMessage(id: 'u1', role: 'user', parts: [ChatPart.text('q1')]),
          ChatMessage(
            id: 'a1',
            role: 'assistant',
            parts: [ChatPart.text('a1')],
            usage: const {'input_tokens': 12000, 'output_tokens': 300},
          ),
          ChatMessage(
            id: 'a2',
            role: 'assistant',
            parts: [ChatPart.text('a2')],
            usage: const {'total_tokens': 500},
          ),
          // A usage map without token fields contributes nothing.
          ChatMessage(
            id: 'a3',
            role: 'assistant',
            parts: [ChatPart.text('a3')],
            usage: const {'tps': 42},
          ),
        ], hasMore: false);

        expect(chat.cumulativeUsageTokens, 12800);
      },
    );

    test('formatCtxUsageLabel renders compact k/M forms', () {
      expect(formatCtxUsageLabel(999), '999 ctx');
      expect(formatCtxUsageLabel(12300), '12.3k ctx');
      expect(formatCtxUsageLabel(2500000), '2.5M ctx');
    });

    testWidgets('indicator renders only with a real label', (tester) async {
      await _pumpBareComposer(tester, ctxUsageLabel: '12.3k ctx');
      expect(find.textContaining('12.3k ctx'), findsOneWidget);

      await _pumpBareComposer(tester);
      expect(find.textContaining('ctx'), findsNothing);
      expect(find.byIcon(Icons.data_usage), findsNothing);
    });
  });

  group('context usage toolbar action', () {
    testWidgets(
      'shows usage, compresses through the session RPC, and is absent from more',
      (tester) async {
        final rig = _ChatRig();
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();
        await rig.sendFirstTurn(tester, 'context please');

        final contextButton = find.byTooltip('上下文使用率');
        expect(contextButton, findsOneWidget);
        final anchorRect = tester.getRect(contextButton);
        await tester.tap(contextButton);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(PopupMenuItem<String>), findsNWidgets(2));
        expect(find.text('上下文使用率'), findsOneWidget);
        expect(find.text('68% of 128K'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.text('压缩'), findsOneWidget);
        expect(
          (tester.getRect(find.text('上下文使用率')).center.dx - anchorRect.center.dx)
              .abs(),
          lessThan(260),
        );

        await tester.tap(find.text('压缩'));
        await tester.pumpAndSettle();
        expect(
          rig.gateway.calls.where((call) => call.$1 == 'session.compress'),
          hasLength(1),
        );
        final breakdownCalls = rig.gateway.calls.where(
          (call) => call.$1 == 'session.context_breakdown',
        );
        expect(breakdownCalls.length, greaterThanOrEqualTo(2));
        expect(
          breakdownCalls.every((call) => call.$2['session_id'] == 'rt-1'),
          isTrue,
        );
        expect(
          rig.gateway.calls.where((call) => call.$1 == 'session.usage'),
          isEmpty,
        );
        expect(find.text('上下文已压缩'), findsOneWidget);
        expect(find.byTooltip('上下文使用率：68%'), findsOneWidget);

        // Disambiguate from the assistant reply's own per-message "更多"
        // button (also tooltip '更多' by design) by scoping to the
        // composer's PopupMenuButton specifically.
        final composerMore = find.ancestor(
          of: find.byTooltip('更多'),
          matching: find.byType(PopupMenuButton<String>),
        );
        await tester.tap(composerMore);
        await tester.pumpAndSettle();
        expect(find.text('上下文'), findsNothing);
        rig.connection.dispose();
      },
    );
  });

  group('A12 phone workspace file panel entry', () {
    testWidgets('phone width: folder icon opens the file panel end drawer', (
      tester,
    ) async {
      final rig = _ChatRig();
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(() => tester.view.padding = FakeViewPadding.zero);
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      final folderBtn = find.byTooltip('工作区文件');
      expect(folderBtn, findsOneWidget);
      await tester.tap(folderBtn);
      await tester.pumpAndSettle();

      // The RightSidebar files tab is now visible inside the drawer.
      expect(find.text('文件'), findsWidgets);
      expect(find.text('终端'), findsWidgets);
      final drawer = find.byType(Drawer);
      final sidebar = find.descendant(
        of: drawer,
        matching: find.byKey(const ValueKey('right-sidebar-expanded')),
      );
      final logicalTopInset =
          tester.view.padding.top / tester.view.devicePixelRatio;
      expect(
        tester.getTopLeft(sidebar).dy,
        greaterThanOrEqualTo(logicalTopInset),
      );
      expect(find.byTooltip('收起'), findsNothing);

      rig.connection.dispose();
    });

    testWidgets('tablet width: no drawer entry, sidebar stays docked', (
      tester,
    ) async {
      final rig = _ChatRig();
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      expect(find.byTooltip('工作区文件'), findsNothing);
      // Third column is docked.
      expect(find.text('文件'), findsWidgets);

      final sidebarSlot = find.byKey(
        const ValueKey('chat-workspace-sidebar-slot'),
      );
      expect(tester.getSize(sidebarSlot).width, 280);

      await tester.tap(find.byTooltip('收起'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('right-sidebar-collapsed')),
        findsOneWidget,
      );
      expect(tester.getSize(sidebarSlot).width, 56);

      await tester.tap(find.byTooltip('展开'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('right-sidebar-expanded')),
        findsOneWidget,
      );
      expect(tester.getSize(sidebarSlot).width, 280);

      rig.connection.dispose();
    });

    for (final width in [800.0, 840.0, 900.0]) {
      testWidgets('$width medium width keeps a usable chat content width', (
        tester,
      ) async {
        final rig = _ChatRig();
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(rig.app());
        await tester.pumpAndSettle();

        expect(
          find.byType(TabletSessionRail),
          width >= HermesBreakpoints.navigation ? findsOneWidget : findsNothing,
        );
        expect(find.byTooltip('工作区文件'), findsOneWidget);
        expect(tester.takeException(), isNull);
        rig.connection.dispose();
      });
    }

    testWidgets('900 medium layout supports 1.6x text without overflow', (
      tester,
    ) async {
      final rig = _ChatRig();
      tester.view.physicalSize = const Size(900, 800);
      tester.view.devicePixelRatio = 1.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      expect(find.byType(TabletSessionRail), findsOneWidget);
      expect(find.byTooltip('工作区文件'), findsOneWidget);
      expect(tester.takeException(), isNull);
      rig.connection.dispose();
    });
  });

  group('C11/C12 AppBar session menu', () {
    testWidgets('重新生成标题 calls the real endpoint and refreshes the header', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'name this chat');

      await tester.tap(find.byTooltip('会话菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('重新生成标题'));
      await tester.pumpAndSettle();

      expect(rig.api.titleRegenCalls, [('sid-1', true)]);
      expect(rig.session.info?.title, '自动标题');
      expect(find.text('自动标题'), findsOneWidget); // AppBar refreshed

      rig.connection.dispose();
    });

    testWidgets('复制会话链接 creates and copies a reachable share URL', (
      tester,
    ) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text']?.toString();
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.sendFirstTurn(tester, 'link me');

      await tester.tap(find.byTooltip('会话菜单'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制会话链接'));
      await tester.pumpAndSettle();

      expect(rig.api.shareCalls, ['sid-1']);
      expect(clipboardText, 'http://contract.invalid/share/token-1');
      expect(find.text('会话分享链接已复制'), findsOneWidget);

      rig.connection.dispose();
    });

    testWidgets('menu entries are disabled before the session is durable', (
      tester,
    ) async {
      final rig = _ChatRig();
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('会话菜单'));
      await tester.pumpAndSettle();

      final menuFinder = find.byWidgetPredicate(
        (w) => w is PopupMenuButton<String> && w.tooltip == '会话菜单',
      );
      final menu = tester.widget<PopupMenuButton<String>>(menuFinder);
      final items = menu
          .itemBuilder(tester.element(menuFinder))
          .whereType<PopupMenuItem<String>>()
          .toList();
      expect(items, hasLength(4));
      expect(items.first.child, isA<ListTile>());
      for (final item in items) {
        expect(item.enabled, isFalse);
      }
      // Close the menu.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      rig.connection.dispose();
    });
  });

  group('structured billing status', () {
    testWidgets('is visible while details are collapsed and can be dismissed', (
      tester,
    ) async {
      final rig = _ChatRig();
      final events = StreamController<GatewayEvent>();
      rig.chat.attachEvents(events.stream);
      addTearDown(events.close);
      await tester.pumpWidget(rig.app());
      await tester.pumpAndSettle();
      await rig.session.openNewSession();

      events.add(
        GatewayEvent(
          type: 'message.complete',
          payload: const {
            'status': 'error',
            'billing': {
              'provider': 'nous',
              'provider_label': 'Nous',
              'message': 'Add credits to continue.',
            },
          },
          sessionId: rig.session.runtimeId,
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('chat-billing-block')), findsOneWidget);
      expect(find.textContaining('Nous'), findsOneWidget);
      expect(find.text('Add credits to continue.'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('chat-billing-block')),
          matching: find.byTooltip('关闭'),
        ),
      );
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-billing-block')), findsNothing);

      rig.connection.dispose();
    });
  });

  testWidgets('standalone vibe reaction paints a non-interactive heart burst', (
    tester,
  ) async {
    final rig = _ChatRig();
    final events = StreamController<GatewayEvent>();
    rig.chat.attachEvents(events.stream);
    addTearDown(events.close);
    await tester.pumpWidget(rig.app());
    await tester.pumpAndSettle();
    await rig.session.openNewSession();

    events.add(
      GatewayEvent(
        type: 'reaction',
        payload: const {'kind': 'vibe'},
        sessionId: rig.session.runtimeId,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('❤️'), findsWidgets);
    expect(
      find.ancestor(
        of: find.text('❤️').first,
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );

    rig.connection.dispose();
  });
}
