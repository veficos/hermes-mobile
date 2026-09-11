import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/gateway.dart';
import 'package:hermes_mobile/core/chat_message.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/command_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/core/stores/session_tab_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/chat/tools/tool_dismiss_store.dart';
import 'package:hermes_mobile/chat/tools/tool_group_card.dart';
import 'package:hermes_mobile/screens/chat_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression coverage: opening a chat with a long, variable-height history
/// (rich text + tool-call groups) used to land the initial "scroll to
/// bottom" short of the true end — Flutter's sliver list only discovers an
/// item's real extent once it's actually laid out, so a single
/// `jumpTo(maxScrollExtent)` right on entry jumps to an ESTIMATE, not the
/// true bottom. The reported symptom: the transcript looks blank/short
/// until the user manually drags the screen, which forces a relayout that
/// corrects the estimate. `_settleInitialScrollToBottom` re-checks across a
/// few more frames and jumps again while the estimate is still growing, so
/// entry alone should settle it — no manual drag needed.
///
/// Caveat: `pumpAndSettle` keeps pumping frames until nothing is scheduled,
/// which already drives even a single unguarded `jumpTo` to the right spot
/// in this synchronous test harness — this test does NOT actually fail
/// without `_settleInitialScrollToBottom` (verified), so it locks in the
/// end-state invariant (entry lands on the true bottom) rather than proving
/// the fix's specific mechanism. The real bug is a real-device frame-
/// scheduling gap this harness can't reproduce: nothing else requests a
/// follow-up frame once the first, estimate-based `jumpTo` completes, so a
/// single miss just stays missed until a user gesture requests one.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => const {};

  @override
  Future<List<SavedPrompt>> savedPrompts() async => const [];

  @override
  Future<Map<String, dynamic>> providerQuota({
    String? provider,
    bool refresh = false,
  }) async => const {};

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
}

List<ChatMessage> _longHistory() {
  final messages = <ChatMessage>[];
  for (var turn = 0; turn < 25; turn++) {
    messages.add(
      ChatMessage(
        id: 'u$turn',
        role: 'user',
        parts: [ChatPart.text('第 $turn 轮的问题内容，稍微长一点，用来撑开消息高度。')],
      ),
    );
    messages.add(
      ChatMessage(
        id: 'a$turn',
        role: 'assistant',
        parts: [
          ChatPart.text(
            '第 $turn 轮的回答。' * 6, // varied, non-trivial text height
          ),
          ChatPart.toolCall({
            'tool_id': 't$turn-1',
            'name': 'terminal',
            'running': false,
            'result_text': 'output for turn $turn',
          }),
          ChatPart.toolCall({
            'tool_id': 't$turn-2',
            'name': 'read_file',
            'running': false,
            'args': {'path': 'lib/file_$turn.dart'},
            'result_text': 'file contents $turn',
          }),
          ChatPart.text('已完成第 $turn 轮。'),
        ],
      ),
    );
  }
  return messages;
}

class _PagedApi extends _FakeApi {
  Completer<void>? gate;
  bool failPage = false;
  final offsets = <int>[];

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    if (path == '/api/v1/sessions/history') {
      return {'id': 'history', 'message_count': 550};
    }
    if (path == '/api/v1/sessions/history/messages') {
      final offset = int.parse(query!['offset']!);
      offsets.add(offset);
      if (offset < 500) await gate!.future;
      if (failPage) throw StateError('History temporarily unavailable');
      return {
        'messages': List.generate(
          50,
          (i) => {
            'id': offset + i + 1,
            'role': (offset + i).isEven ? 'user' : 'assistant',
            'content':
                'History row ${offset + i}: ${'variable text ' * (i % 7 + 1)}',
          },
        ),
      };
    }
    throw StateError('Unexpected GET $path');
  }
}

class _HistoryGateway extends GatewayClient {
  _HistoryGateway()
    : super(serverBaseUrl: 'http://contract.invalid', apiKey: 'test');
  @override
  bool get isConnected => true;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    Map<String, dynamic> params, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (method == 'session.resume') return {'session_id': 'history-runtime'};
    throw StateError('Unexpected RPC $method');
  }
}

class _HistoryConnection extends ConnectionStore {
  @override
  Future<void> ensureConnected() async {}
}

class _DelayedHistorySession extends SessionStore {
  _DelayedHistorySession({
    required super.connection,
    required super.chat,
    required super.requests,
  });
  Completer<void>? pageGate;
  int pages = 0;
  String _testSessionId = 'history';
  int _testGeneration = 0;

  @override
  String? get durableId => _testSessionId;

  void replaceSession(String id, List<ChatMessage> messages) {
    _testGeneration++;
    _testSessionId = id;
    chat.loadHistory(messages, hasMore: false);
    notifyListeners();
  }

  @override
  Future<void> loadOlderMessages({
    bool deferTrim = false,
    void Function()? beforeApply,
  }) async {
    if (chat.loadingHistory || !chat.hasMoreHistory) return;
    pages++;
    final generation = _testGeneration;
    chat.startLoadingHistory();
    pageGate = Completer<void>();
    await pageGate!.future;
    // Model the store's stale-response rejection; the screen's future still
    // completes and must not restore the old session's viewport.
    if (generation != _testGeneration) return;
    beforeApply?.call();
    chat.appendOlderHistory(
      List.generate(
        50,
        (i) => ChatMessage(
          id: 'older-$i',
          role: i.isEven ? 'user' : 'assistant',
          parts: [
            ChatPart.text('Older message $i ${'long text ' * (i % 8 + 1)}'),
          ],
        ),
      ),
      hasMore: false,
      deferTrim: deferTrim,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'real SessionStore and ChatScreen preserve anchors across ten API pages',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _PagedApi();
      final connection = _HistoryConnection()
        ..api = api
        ..gateway = _HistoryGateway();
      final chat = ChatStore();
      final requests = RequestStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final voice = VoiceStore(connection: connection);
      final commands = CommandStore(connection: connection);
      addTearDown(() {
        voice.dispose();
        commands.dispose();
        session.dispose();
        requests.dispose();
        chat.dispose();
        connection.dispose();
      });
      await session.resumeSession('history');
      final streamEvents = StreamController<GatewayEvent>();
      chat.attachEvents(streamEvents.stream);
      addTearDown(streamEvents.close);
      expect(chat.loadedCount, 50);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ConnectionStore>.value(value: connection),
            ChangeNotifierProvider<SessionStore>.value(value: session),
            ChangeNotifierProvider<ChatStore>.value(value: chat),
            ChangeNotifierProvider<VoiceStore>.value(value: voice),
            ChangeNotifierProvider<CommandStore>.value(value: commands),
            ChangeNotifierProvider(create: (_) => SessionTabStore()),
            ChangeNotifierProvider(create: (_) => ToolDismissStore()),
          ],
          child: MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
            ),
            home: const ChatScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.byType(Scrollable).first;
      final position = tester.state<ScrollableState>(scrollable).position;
      for (var page = 1; page <= 10; page++) {
        api.gate = Completer<void>();
        position.jumpTo(position.minScrollExtent + 100);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));
        expect(chat.loadingHistory, isTrue, reason: 'page $page');
        expect(api.offsets.last, 500 - page * 50);
        if (page == 5) {
          final count = chat.loadedCount;
          api.failPage = true;
          api.gate!.complete();
          await tester.pumpAndSettle();
          expect(chat.loadingHistory, isFalse);
          expect(chat.loadedCount, count);
          api.failPage = false;
          api.gate = Completer<void>();
          final retry = find.byKey(const ValueKey('history-retry'));
          position.jumpTo(position.minScrollExtent);
          await tester.pump();
          expect(retry.hitTestable(), findsOneWidget);
          await tester.tap(retry);
          await tester.pump();
          expect(chat.loadingHistory, isTrue);
          expect(api.offsets.where((offset) => offset == 250).length, 2);
        }
        expect(
          find.byKey(const ValueKey('history-loading-overlay')),
          findsOneWidget,
        );
        await tester.drag(scrollable, const Offset(0, 40));
        await tester.pump(const Duration(milliseconds: 300));
        // The fixed-position assertion starts only after user motion ends.
        // Loading feedback animates indefinitely, so pumpAndSettle is unsuitable.
        for (
          var frame = 0;
          position.isScrollingNotifier.value && frame < 120;
          frame++
        ) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(position.isScrollingNotifier.value, isFalse);
        TestGesture? heldDrag;
        if (page == 7) {
          heldDrag = await tester.startGesture(tester.getCenter(scrollable));
          await heldDrag.moveBy(const Offset(0, -30));
          await tester.pump();
          expect(position.isScrollingNotifier.value, isTrue);
        }
        final viewport = tester.getRect(scrollable);
        final visible = find.textContaining('History row').evaluate().where((
          element,
        ) {
          final rect = tester.getRect(find.byWidget(element.widget));
          return rect.bottom > viewport.top + 100 &&
              rect.top < viewport.bottom - 100;
        }).toList();
        expect(visible, isNotEmpty);
        final widget = visible.first.widget;
        final label = widget is EditableText
            ? widget.controller.text
            : (widget as Text).data!;
        final anchor = find.text(label);
        final top = tester.getTopLeft(anchor).dy;
        if (page == 7) {
          streamEvents.add(
            GatewayEvent(
              type: 'message.start',
              sessionId: 'history-runtime',
              payload: const {},
            ),
          );
        }
        api.gate!.complete();
        var dragDisplacement = 0.0;
        for (var frame = 0; frame < 30; frame++) {
          if (heldDrag != null) {
            await heldDrag.moveBy(const Offset(0, -2));
            dragDisplacement -= 2;
            streamEvents.add(
              GatewayEvent(
                type: 'message.delta',
                sessionId: 'history-runtime',
                payload: {'text': 'stream-$frame '},
              ),
            );
          }
          await tester.pump(const Duration(milliseconds: 16));
          expect(anchor, findsOneWidget, reason: 'page $page frame $frame');
          expect(
            tester.getTopLeft(anchor).dy,
            closeTo(top + dragDisplacement, 2),
            reason: 'page $page frame $frame',
          );
        }
        expect(chat.loadingHistory, isFalse);
        if (heldDrag != null) {
          expect(
            chat.messages.last.fullText,
            List.generate(30, (i) => 'stream-$i ').join(),
          );
          streamEvents.add(
            GatewayEvent(
              type: 'message.complete',
              sessionId: 'history-runtime',
              payload: const {},
            ),
          );
          final beforeMove = tester.getTopLeft(anchor).dy;
          await heldDrag.moveBy(const Offset(0, -24));
          await tester.pump();
          expect(
            tester.getTopLeft(anchor).dy,
            closeTo(beforeMove - 24, 2),
            reason: 'page merge must not cancel the active drag',
          );
          await heldDrag.up();
          await tester.pumpAndSettle();
        }
        expect(position.pixels, lessThan(position.maxScrollExtent - 100));
        expect(chat.messages.map((m) => m.id).toSet().length, chat.loadedCount);
        expect(tester.takeException(), isNull);
      }
      expect(api.offsets, [
        500,
        450,
        400,
        350,
        300,
        250,
        250,
        200,
        150,
        100,
        50,
        0,
      ]);
      expect(chat.hasMoreHistory, isFalse);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final shortHistory in [false, true]) {
    for (final (liquid, brightness, width, textScale) in [
      (false, Brightness.light, 390.0, 1.0),
      (true, Brightness.light, 390.0, 1.0),
      (true, Brightness.dark, 390.0, 1.0),
      (true, Brightness.light, 320.0, 2.0),
      (true, Brightness.dark, 320.0, 2.0),
    ]) {
      testWidgets(
        'entering a long chat settles the scroll on the true bottom message '
        'without a manual drag (short=$shortHistory, liquid=$liquid, brightness=$brightness, width=$width, textScale=$textScale)',
        (tester) async {
          if (liquid) {
            await tester.binding.setSurfaceSize(Size(width, 844));
            addTearDown(() => tester.binding.setSurfaceSize(null));
          }
          final connection = ConnectionStore()..api = _FakeApi();
          final chat = ChatStore();
          final session = _DelayedHistorySession(
            connection: connection,
            chat: chat,
            requests: RequestStore(),
          );
          addTearDown(() {
            session.dispose();
            connection.dispose();
          });

          // Mirrors the real entry path: history is fully loaded into the
          // store BEFORE the screen ever mounts (session_list_screen._open
          // awaits resumeSession before pushing ChatScreen).
          chat.loadHistory(
            shortHistory ? _longHistory().take(1).toList() : _longHistory(),
            hasMore: false,
          );
          final keyboard = ValueNotifier<double>(0);
          addTearDown(keyboard.dispose);

          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<ConnectionStore>.value(
                  value: connection,
                ),
                ChangeNotifierProxyProvider<ConnectionStore, SessionTabStore>(
                  create: (_) => SessionTabStore(),
                  update: (_, connection, tabs) => (tabs ?? SessionTabStore())
                    ..attachRoutedEvents(
                      connection.routedEvents,
                      owners: connection.sessionOwners,
                    ),
                ),
                ChangeNotifierProvider<SessionStore>.value(value: session),
                ChangeNotifierProvider<ChatStore>.value(value: chat),
                ChangeNotifierProvider.value(
                  value: VoiceStore(connection: connection),
                ),
                ChangeNotifierProvider.value(
                  value: CommandStore(connection: connection),
                ),
                ChangeNotifierProvider(create: (_) => ToolDismissStore()),
              ],
              child: MaterialApp(
                builder: (context, child) => ValueListenableBuilder<double>(
                  valueListenable: keyboard,
                  builder: (_, inset, _) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      viewInsets: EdgeInsets.only(bottom: inset),
                      textScaler: TextScaler.linear(textScale),
                    ),
                    child: child!,
                  ),
                ),
                theme: liquid
                    ? buildHermesTheme(
                        brightness: brightness,
                        visualStyle: HermesVisualStyle.liquid,
                      )
                    : null,
                home: const ChatScreen(),
              ),
            ),
          );

          // Give the settle loop's chained postFrameCallbacks room to run —
          // this is exactly what happens on a real device with no user
          // interaction at all (no simulated drag/scroll gesture below).
          await tester.pumpAndSettle();
          if (shortHistory) {
            final message = tester.getRect(find.textContaining('第 0 轮的问题内容'));
            final header = tester.getRect(find.byType(AppBar));
            final composer = tester.getRect(find.byType(HermesComposer));
            expect(message.top, greaterThanOrEqualTo(header.bottom));
            expect(message.bottom, lessThanOrEqualTo(composer.top));
            expect(tester.takeException(), isNull);
            return;
          }
          if (liquid) {
            expect(
              tester
                  .widget<Scaffold>(find.byType(Scaffold).first)
                  .extendBodyBehindAppBar,
              isFalse,
            );
          }

          final scrollable = find.byType(Scrollable).first;
          final position = tester.state<ScrollableState>(scrollable).position;
          final beforeLoading = position.pixels;
          chat.startLoadingHistory();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          final loading = find.byKey(const ValueKey('history-loading-overlay'));
          expect(loading, findsOneWidget);
          final loadingRect = tester.getRect(loading);
          expect(loadingRect.top, greaterThanOrEqualTo(0));
          expect(
            loadingRect.bottom,
            lessThan(tester.getRect(find.byType(HermesComposer)).top),
          );
          expect(position.pixels, closeTo(beforeLoading, 1));
          chat.appendOlderHistory(const [], hasMore: false);
          await tester.pumpAndSettle();
          expect(loading, findsNothing);
          expect(
            position.pixels,
            closeTo(position.maxScrollExtent, 1),
            reason:
                'the transcript must land on its own true bottom on entry — '
                'stopping short here is exactly the reported "blank until a '
                'manual drag" symptom',
          );
          expect(
            find.textContaining('已完成第 24 轮'),
            findsOneWidget,
            reason:
                'the last turn must actually be built/visible, not just '
                'numerically close in scroll-extent terms',
          );
          if (liquid) {
            // The answer's introductory paragraph precedes tool cards and may
            // legitimately scroll offscreen. Check the actual trailing text.
            final answer = tester.getRect(find.textContaining('已完成第 24 轮'));
            final header = tester.getRect(find.byType(AppBar));
            final composer = tester.getRect(find.byType(HermesComposer));
            final viewport = tester.getRect(scrollable);
            expect(
              viewport.bottom,
              lessThanOrEqualTo(composer.top),
              reason: 'Reading text must not pass behind the glass composer',
            );
            expect(viewport.top, greaterThanOrEqualTo(header.bottom));
            for (final key in [
              'user-message-bubble',
              'assistant-message-bubble',
            ]) {
              for (final bubble in tester.widgetList<Container>(
                find.byKey(ValueKey(key)),
              )) {
                expect((bubble.decoration! as BoxDecoration).color!.a, 1);
              }
            }
            if (answer.height <= composer.top - header.bottom) {
              expect(answer.top, greaterThanOrEqualTo(header.bottom));
            }
            expect(answer.bottom, greaterThan(header.bottom));
            expect(answer.bottom, lessThanOrEqualTo(composer.top));
            keyboard.value = 300;
            await tester.pumpAndSettle();
            expect(
              tester.getRect(find.byType(HermesComposer)).bottom,
              lessThanOrEqualTo(544),
            );
            expect(
              position.pixels,
              closeTo(position.maxScrollExtent, 1),
              reason: 'keyboard opening preserves bottom following',
            );
            keyboard.value = 0;
            await tester.pumpAndSettle();
            await tester.tap(find.byIcon(Icons.emoji_emotions_outlined));
            await tester.pumpAndSettle();
            expect(find.text('😀').hitTestable(), findsOneWidget);
            expect(
              find.byKey(const ValueKey('composer-send')).hitTestable(),
              findsOneWidget,
            );
            expect(
              position.pixels,
              closeTo(position.maxScrollExtent, 1),
              reason: 'expanded emoji dock follows the latest message',
            );
            await tester.tap(find.text('😀'));
            await tester.pumpAndSettle();
            final emojiEditor = tester.widget<EditableText>(
              find
                  .descendant(
                    of: find.byType(HermesComposer),
                    matching: find.byType(EditableText),
                  )
                  .first,
            );
            expect(emojiEditor.controller.text, '😀');
            await tester.tap(find.byIcon(Icons.emoji_emotions));
            await tester.pumpAndSettle();
            expect(
              find.descendant(
                of: find.byType(HermesComposer),
                matching: find.byType(GridView),
              ),
              findsNothing,
            );
            expect(emojiEditor.controller.text, '😀');
            expect(position.pixels, closeTo(position.maxScrollExtent, 1));
            final input = find
                .descendant(
                  of: find.byType(HermesComposer),
                  matching: find.byType(TextField),
                )
                .first;
            await tester.enterText(input, 'Line 1\nLine 2\nLine 3\nLine 4');
            await tester.pumpAndSettle();
            expect(
              position.pixels,
              closeTo(position.maxScrollExtent, 1),
              reason: 'growing the Liquid dock must retain bottom following',
            );
            expect(
              tester.getSize(find.byType(HermesComposer)).height,
              greaterThan(composer.height),
              reason: 'the fixture must actually grow the input surface',
            );
            await tester.enterText(input, '');
            await tester.pumpAndSettle();
            await tester.drag(scrollable, const Offset(0, 220));
            await tester.pumpAndSettle();
            final historyOffset = position.pixels;
            expect(historyOffset, lessThan(position.maxScrollExtent - 40));
            final groups = find.byType(ToolGroupCard);
            final groupId = tester.widget<ToolGroupCard>(groups.last).groupId;
            final group = find.byWidgetPredicate(
              (widget) => widget is ToolGroupCard && widget.groupId == groupId,
            );
            await Scrollable.ensureVisible(
              tester.element(group),
              alignment: .25,
            );
            await tester.pumpAndSettle();
            final toggle = find.descendant(
              of: group,
              matching: find.byIcon(Icons.expand_more),
            );
            expect(toggle.hitTestable(), findsOneWidget);
            final groupTop = tester.getTopLeft(group).dy;
            final originalHeight = tester.getSize(group).height;
            final expandedSemantics = find.descendant(
              of: group,
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is Semantics && widget.properties.expanded != null,
              ),
            );
            final wasExpanded = tester
                .widget<Semantics>(expandedSemantics)
                .properties
                .expanded;
            Focus.of(tester.element(toggle)).requestFocus();
            await tester.pump();
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(
              tester.widget<Semantics>(expandedSemantics).properties.expanded,
              !wasExpanded!,
            );
            expect(tester.getSize(group).height, isNot(originalHeight));
            expect(tester.getTopLeft(group).dy, closeTo(groupTop, 2));
            expect(position.pixels, lessThan(position.maxScrollExtent - 40));
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(tester.getSize(group).height, closeTo(originalHeight, 1));
            expect(tester.getTopLeft(group).dy, closeTo(groupTop, 2));
            final afterToolToggleOffset = position.pixels;
            await tester.enterText(input, 'Line 1\nLine 2\nLine 3\nLine 4');
            await tester.pumpAndSettle();
            expect(
              position.pixels,
              closeTo(afterToolToggleOffset, 1),
              reason:
                  'resizing the dock must not pull history readers to bottom',
            );
            await tester.enterText(input, '');
            await tester.pumpAndSettle();
            final search = find.ancestor(
              of: find.byIcon(Icons.search),
              matching: find.byType(GlassButton),
            );
            expect(search, findsOneWidget);
            await tester.tap(search);
            await tester.pumpAndSettle();
            final activeSearch = find.ancestor(
              of: find.byIcon(Icons.search_off),
              matching: find.byType(GlassButton),
            );
            expect(tester.widget<GlassButton>(activeSearch).selected, isTrue);
            for (final icon in [
              Icons.keyboard_arrow_up,
              Icons.keyboard_arrow_down,
            ]) {
              final control = find.ancestor(
                of: find.byIcon(icon),
                matching: find.byType(GlassButton),
              );
              expect(control, findsOneWidget);
              expect(tester.getSize(control).height, greaterThanOrEqualTo(44));
              expect(tester.widget<GlassButton>(control).onPressed, isNull);
            }
            final field = find.byWidgetPredicate(
              (widget) =>
                  widget is TextField && widget.focusNode?.hasFocus == true,
            );
            await tester.enterText(field, '轮的回答');
            await tester.pump(const Duration(milliseconds: 150));
            await tester.pumpAndSettle();
            expect(find.text('1/25'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
            await tester.pumpAndSettle();
            expect(find.text('2/25'), findsOneWidget);
            await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
            await tester.pumpAndSettle();
            expect(find.text('1/25'), findsOneWidget);
            final activeIcon = find.byIcon(Icons.search_off);
            final activeContext = tester.element(activeIcon);
            expect(
              IconTheme.of(activeContext).color,
              Theme.of(activeContext).colorScheme.onPrimaryContainer,
            );
            await tester.tap(activeSearch);
            await tester.pumpAndSettle();
            expect(tester.widget<GlassButton>(search).selected, isFalse);
          }
          // Exercise ChatScreen's actual on-scroll pagination and restoration,
          // with a controlled delayed session boundary (not a real transport).
          chat.loadHistory(_longHistory(), hasMore: true);
          await tester.pumpAndSettle();
          final pagePosition = tester
              .state<ScrollableState>(scrollable)
              .position;
          pagePosition.jumpTo(pagePosition.minScrollExtent + 100);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          expect(session.pages, 1);
          expect(chat.loadingHistory, isTrue);
          expect(
            find.byKey(const ValueKey('history-loading-overlay')),
            findsOneWidget,
          );
          // Continue reading while the page is in flight.
          await tester.drag(scrollable, const Offset(0, 40));
          await tester.pump(const Duration(milliseconds: 300));
          final visibleQuestions = find
              .textContaining('轮的问题内容')
              .evaluate()
              .where((element) {
                final rect = tester.getRect(find.byWidget(element.widget));
                final viewport = tester.getRect(scrollable);
                return rect.bottom > viewport.top && rect.top < viewport.bottom;
              })
              .toList();
          expect(visibleQuestions, isNotEmpty);
          final anchorWidget = visibleQuestions.first.widget;
          final anchor = find.text(
            anchorWidget is EditableText
                ? anchorWidget.controller.text
                : (anchorWidget as Text).data!,
          );
          expect(anchor, findsOneWidget);
          final beforePageTop = tester.getTopLeft(anchor).dy;
          session.pageGate!.complete();
          final recoveryFrames = <double?>[];
          for (var frame = 0; frame < 30; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            recoveryFrames.add(
              anchor.evaluate().isEmpty ? null : tester.getTopLeft(anchor).dy,
            );
            if (!tester.binding.hasScheduledFrame) break;
          }
          await tester.pumpAndSettle();
          expect(chat.loadedCount, 100);
          expect(
            chat.messages.take(50).map((m) => m.id),
            List.generate(50, (i) => 'older-$i'),
          );
          expect(chat.messages[50].id, 'u0');
          expect(
            chat.hasNewerTranscriptWindow,
            isFalse,
            reason: 'this reproduction must not remove the anchor by trimming',
          );
          expect(tester.getTopLeft(anchor).dy, closeTo(beforePageTop, 2));
          expect(
            recoveryFrames,
            everyElement(isNotNull),
            reason:
                'pagination must not temporarily discard the visible anchor',
          );
          expect(
            recoveryFrames.whereType<double>(),
            everyElement(closeTo(beforePageTop, 2)),
            reason:
                'correct final position must not conceal intermediate jumps',
          );
          expect(
            pagePosition.pixels,
            lessThan(pagePosition.maxScrollExtent - 100),
          );
          expect(
            find.byKey(const ValueKey('history-loading-overlay')),
            findsNothing,
          );
          expect(tester.takeException(), isNull);

          // Leave while a second page is pending, then read away from the
          // new session's tail before the old operation's finalizer runs.
          chat.loadHistory(_longHistory(), hasMore: true);
          await tester.pumpAndSettle();
          pagePosition.jumpTo(pagePosition.minScrollExtent + 100);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 16));
          expect(session.pages, 2);
          final oldGate = session.pageGate!;
          session.replaceSession('replacement', _longHistory());
          await tester.pumpAndSettle();
          final replacementPosition = tester
              .state<ScrollableState>(scrollable)
              .position;
          replacementPosition.jumpTo(replacementPosition.maxScrollExtent - 600);
          await tester.pumpAndSettle();
          final readingOffset = replacementPosition.pixels;
          expect(replacementPosition.extentAfter, greaterThan(400));
          expect(
            find.byKey(const ValueKey('history-loading-overlay')),
            findsNothing,
          );
          oldGate.complete();
          for (var frame = 0; frame < 12; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            expect(replacementPosition.pixels, closeTo(readingOffset, 2));
          }
          expect(chat.loadedCount, 50);
          expect(chat.messages.first.id, 'u0');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
