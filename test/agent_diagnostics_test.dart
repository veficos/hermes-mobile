import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/agent_screen.dart';
import 'package:hermes_mobile/widgets/bot_avatar.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_glass.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_mobile_surfaces.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'support/review_capture.dart';

class _Api extends ApiClient {
  _Api() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');
  @override
  Future<Map<String, dynamic>> status() async => {
    'backend': {
      'running': true,
      'hermes_version': 'test-engine-version',
      'gateway': {'state': 'connected', 'active_agents': 2},
      'model': {'model': 'test-model'},
    },
    'runtime': {'kind': 'test-runtime'},
  };
}

class _Bots extends BotStore {
  _Bots(super.connection);
  @override
  Future<void> refresh() async {}
  @override
  Future<void> refreshBotAttention(List<BotIdentity> targets) async {}
}

class _DelayedStatus extends _Api {
  final pending = Completer<Map<String, dynamic>>();
  bool retry = false;
  @override
  Future<Map<String, dynamic>> status() =>
      retry ? super.status() : pending.future;
}

void main() {
  testWidgets(
    'Bot directory survives pending and failed diagnostics then recovers',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = _DelayedStatus();
      final connection = ConnectionStore()..api = api;
      final chat = ChatStore();
      final requests = RequestStore();
      final session = SessionStore(
        connection: connection,
        chat: chat,
        requests: requests,
      );
      final bots = _Bots(connection)
        ..bots = [
          BotIdentity(
            route: OwnerRoute(
              connectionId: ConnectionStore.primaryConnectionId,
            ),
            profile: 'review',
            displayName: 'Available Bot',
            description: 'Independent directory',
          ),
        ];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: connection),
            ChangeNotifierProvider.value(value: session),
            ChangeNotifierProvider<BotStore>.value(value: bots),
          ],
          child: MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AgentScreen(),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Available Bot'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        find.byKey(const PageStorageKey('agent-service-diagnostics')),
        findsNothing,
      );
      api.pending.completeError(StateError('Diagnostics unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Available Bot'), findsOneWidget);
      expect(find.textContaining('Diagnostics unavailable'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        find.byKey(const PageStorageKey('agent-service-diagnostics')),
        findsNothing,
      );
      await tester.ensureVisible(find.byTooltip('More').first);
      await tester.tap(find.byTooltip('More').first);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      api.retry = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Available Bot'), findsOneWidget);
      expect(find.textContaining('Diagnostics unavailable'), findsNothing);
      expect(
        find.byKey(const PageStorageKey('agent-service-diagnostics')),
        findsOneWidget,
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(AgentScreen)),
      );
      expect(find.text(l10n.agentBackendRunning), findsOneWidget);
      // A later failure must not leave an old healthy status on screen.
      api.retry = false;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text('Available Bot'), findsOneWidget);
      expect(find.textContaining('Diagnostics unavailable'), findsOneWidget);
      expect(find.text(l10n.agentBackendRunning), findsNothing);
      expect(find.text(l10n.agentBackendStopped), findsNothing);
      expect(
        find.byKey(const PageStorageKey('agent-service-diagnostics')),
        findsNothing,
      );
      api.retry = true;
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.agentBackendRunning), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      bots.dispose();
      session.dispose();
      requests.dispose();
      chat.dispose();
      connection.dispose();
    },
  );

  Future<void> reveal(WidgetTester tester, Finder target) async {
    for (
      var attempt = 0;
      attempt < 20 && target.hitTestable().evaluate().isEmpty;
      attempt++
    ) {
      final y = tester.getCenter(target).dy;
      await tester.drag(
        find.byType(ListView).first,
        Offset(0, y > 600 ? -200 : 200),
      );
      await tester.pumpAndSettle();
    }
    expect(target.hitTestable(), findsOneWidget);
  }

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 430.0, 768.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
          'bot overview diagnostics $brightness scale=$scale width=$width',
          (tester) async {
            SharedPreferences.setMockInitialValues({});
            tester.view.physicalSize = Size(width, 844);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(tester.view.resetViewInsets);
            final connection = ConnectionStore()..api = _Api();
            final chat = ChatStore();
            final requests = RequestStore();
            final session = SessionStore(
              connection: connection,
              chat: chat,
              requests: requests,
            );
            late String portrait;
            await tester.runAsync(() async {
              final recorder = ui.PictureRecorder();
              final canvas = Canvas(recorder);
              canvas.drawRect(
                const Rect.fromLTWH(0, 0, 20, 80),
                Paint()..color = Colors.blue,
              );
              final picture = recorder.endRecording();
              final image = await picture.toImage(20, 80);
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              portrait =
                  'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes))}';
              image.dispose();
              picture.dispose();
            });
            final bots = _Bots(connection)
              ..bots = [
                BotIdentity(
                  route: OwnerRoute(
                    connectionId: ConnectionStore.primaryConnectionId,
                  ),
                  profile: 'review',
                  displayName: '代码审查助手',
                  metadata: {'image': portrait},
                  description: '检查实现细节、测试覆盖与潜在风险，提供可操作的修改建议。',
                ),
                BotIdentity(
                  route: OwnerRoute(
                    connectionId: ConnectionStore.primaryConnectionId,
                  ),
                  profile: 'design',
                  displayName: '界面设计与无障碍体验协作助手',
                  description: '统一页面布局和交互反馈。',
                ),
              ];
            await tester.pumpWidget(
              MultiProvider(
                providers: [
                  ChangeNotifierProvider.value(value: connection),
                  ChangeNotifierProvider.value(value: session),
                  ChangeNotifierProvider<BotStore>.value(value: bots),
                ],
                child: MaterialApp(
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  locale: const Locale('zh'),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  theme: buildHermesTheme(
                    brightness: brightness,
                    visualStyle: HermesVisualStyle.liquid,
                  ),
                  home: const RepaintBoundary(
                    key: ValueKey('bots-review'),
                    child: AgentScreen(),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final portraitAvatar = find.byWidgetPredicate(
              (widget) => widget is BotAvatar && widget.name == 'review',
            );
            await Scrollable.ensureVisible(
              tester.element(portraitAvatar),
              alignment: .4,
            );
            for (var frame = 0; frame < 100; frame++) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 20)),
              );
              await tester.pump(const Duration(milliseconds: 16));
              final images = tester.widgetList<RawImage>(
                find.descendant(
                  of: portraitAvatar,
                  matching: find.byType(RawImage),
                ),
              );
              if (images.any((image) => image.image != null)) break;
            }
            final raw = tester.widget<RawImage>(
              find.descendant(
                of: portraitAvatar,
                matching: find.byType(RawImage),
              ),
            );
            expect(raw.image, isNotNull);
            expect(raw.image!.width, 20);
            expect(raw.image!.height, 80);
            expect(raw.fit, BoxFit.cover);
            final portraitRow = find
                .ancestor(
                  of: portraitAvatar,
                  matching: find.byType(HermesMobileRow),
                )
                .first;
            final title = find.descendant(
              of: portraitRow,
              matching: find.text('代码审查助手'),
            );
            expect(
              tester.getTopLeft(portraitAvatar).dy,
              tester.getTopLeft(title).dy,
            );
            expect(tester.getSize(portraitAvatar), const Size(44, 44));
            await Scrollable.ensureVisible(
              tester.element(
                find.byKey(const ValueKey('bot-directory-overview')),
              ),
              alignment: 0,
            );
            await tester.pumpAndSettle();
            expect(find.text('后台运行中'), findsOneWidget);
            final overview = find.byKey(
              const ValueKey('bot-directory-overview'),
            );
            expect(
              find.descendant(of: overview, matching: find.byType(FittedBox)),
              findsNothing,
            );
            final statusText = find.text('后台运行中');
            final statusBox = tester.getRect(statusText);
            final overviewBox = tester.getRect(overview);
            expect(statusBox.left, greaterThanOrEqualTo(overviewBox.left));
            expect(statusBox.right, lessThanOrEqualTo(overviewBox.right));
            expect(statusBox.bottom, lessThanOrEqualTo(overviewBox.bottom));
            expect(find.text('Hermes Agent'), findsNothing);
            expect(find.text('test-engine-version'), findsNothing);
            const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
            if (reviewDir.isNotEmpty) {
              await captureReview(
                tester,
                find.byKey(const ValueKey('bots-review')),
                '$reviewDir/bots-${brightness.name}-$scale${width == 320 ? '' : '-${width.toInt()}'}.png',
              );
            }
            final diagnostics = find.text('服务状态与诊断');
            final directoryL10n = AppLocalizations.of(tester.element(overview));
            expect(find.text(directoryL10n.agentNewGroup), findsNothing);
            final manage = find.byKey(const ValueKey('bot-directory-manage'));
            await Scrollable.ensureVisible(
              tester.element(manage),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(manage.hitTestable(), findsOneWidget);
            expect(tester.getSize(manage).height, greaterThanOrEqualTo(44));
            final manageFocus = Focus.of(
              tester.element(
                find.descendant(
                  of: manage,
                  matching: find.text(directoryL10n.agentManageBots),
                ),
              ),
            );
            FocusManager.instance.primaryFocus?.unfocus();
            await tester.pumpAndSettle();
            for (var step = 0; step < 30 && !manageFocus.hasFocus; step++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
            }
            expect(
              manageFocus.hasFocus,
              isTrue,
              reason: 'Tab reaches management',
            );
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.text(directoryL10n.agentNewGroup), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.text(directoryL10n.agentNewGroup), findsNothing);
            expect(manageFocus.hasFocus, isTrue);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            final newGroup = find.text(directoryL10n.agentNewGroup);
            final groupFocus = Focus.of(tester.element(newGroup));
            for (var step = 0; step < 12 && !groupFocus.hasFocus; step++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.tab);
              await tester.pumpAndSettle();
            }
            expect(
              groupFocus.hasFocus,
              isTrue,
              reason: 'Tab reaches group action',
            );
            expect(newGroup.hitTestable(), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            expect(find.text(directoryL10n.agentGroupName), findsOneWidget);
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
            expect(find.text(directoryL10n.agentGroupName), findsNothing);
            expect(manageFocus.hasFocus, isTrue);
            expect(
              find.byKey(const ValueKey('bot-directory-create')),
              findsOneWidget,
            );
            final hidden = BotIdentity(
              route: bots.bots.first.route,
              profile: 'hidden-review',
              displayName: '已隐藏的长期协作助手',
              metadata: const {'hidden': true},
            );
            bots.bots = [...bots.bots, hidden];
            bots.notifyListeners();
            await tester.pumpAndSettle();
            final toggle = find.byKey(const ValueKey('hidden-bots-toggle'));
            final hiddenRow = find.byKey(ValueKey('bot-hidden-${hidden.key}'));
            expect(hiddenRow, findsNothing);
            await Scrollable.ensureVisible(
              tester.element(toggle),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            expect(tester.getSize(toggle).width, greaterThanOrEqualTo(44));
            expect(tester.getSize(toggle).height, greaterThanOrEqualTo(44));
            expect(tester.widget<IconButton>(toggle).tooltip, isNotEmpty);
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(hiddenRow, findsOneWidget);
            final hiddenActions = find.descendant(
              of: hiddenRow,
              matching: find.byType(IconButton),
            );
            await Scrollable.ensureVisible(
              tester.element(hiddenActions),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await tester.tap(hiddenActions);
            await tester.pumpAndSettle();
            final hiddenL10n = AppLocalizations.of(tester.element(hiddenRow));
            expect(find.text(hiddenL10n.agentUnhideBot), findsOneWidget);
            Navigator.of(tester.element(hiddenRow)).pop();
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              toggle,
              200,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await Scrollable.ensureVisible(
              tester.element(toggle),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            for (
              var attempt = 0;
              attempt < 15 && toggle.hitTestable().evaluate().isEmpty;
              attempt++
            ) {
              final y = tester.getCenter(toggle).dy;
              await tester.drag(
                find.byType(ListView).first,
                Offset(0, y > 600 ? -200 : 200),
              );
              await tester.pumpAndSettle();
            }
            expect(toggle.hitTestable(), findsOneWidget);
            await tester.tap(toggle);
            await tester.pumpAndSettle();
            expect(hiddenRow, findsNothing);
            bots.bots = bots.bots
                .where((bot) => bot.key != hidden.key)
                .toList();
            bots.notifyListeners();
            await tester.pumpAndSettle();
            bots.groups = [
              BotGroup(
                id: 'review-group',
                updatedAt: DateTime.utc(2026, 9, 10),
                name: '跨团队协作群组：设计评审、实现检查与无障碍测试的长期讨论空间' * 3,
                memberKeys: bots.bots.map((bot) => bot.key).toList(),
              ),
            ];
            bots.notifyListeners();
            await tester.pumpAndSettle();
            final groupRow = find.byKey(
              const ValueKey('bot-group-review-group'),
            );
            final groupActions = find.descendant(
              of: groupRow,
              matching: find.byType(IconButton),
            );
            await Scrollable.ensureVisible(
              tester.element(groupActions),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await reveal(tester, groupActions);
            await tester.tap(groupActions);
            await tester.pumpAndSettle();
            // Simulate a keyboard appearing while a long-title sheet is open.
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            final groupL10n = AppLocalizations.of(tester.element(groupRow));
            final sheetTitle = tester
                .widgetList<Text>(find.text(bots.groups.single.name))
                .last;
            expect(sheetTitle.maxLines, isNull);
            expect(sheetTitle.overflow, isNot(TextOverflow.ellipsis));
            final deleteGroup = find.text(groupL10n.agentDeleteGroup);
            await tester.ensureVisible(deleteGroup);
            await tester.pumpAndSettle();
            expect(deleteGroup.hitTestable(), findsOneWidget);
            expect(
              tester.getBottomRight(deleteGroup).dy,
              lessThanOrEqualTo(544),
            );
            expect(tester.takeException(), isNull);
            Navigator.of(tester.element(groupRow)).pop();
            tester.view.resetViewInsets();
            await tester.pumpAndSettle();
            bots.groups = [];
            bots.notifyListeners();
            await tester.pumpAndSettle();
            bots.unreachableConnections.add(
              ConnectionStore.primaryConnectionId,
            );
            bots.notifyListeners();
            await tester.pumpAndSettle();
            final offlineRow = find.byKey(
              ValueKey('bot-${bots.bots.first.key}'),
            );
            await tester.ensureVisible(offlineRow);
            await tester.pumpAndSettle();
            final row = tester.widget<HermesMobileRow>(offlineRow);
            final l10n = AppLocalizations.of(tester.element(offlineRow));
            expect(row.subtitle, contains(l10n.agentBotUnreachable));
            expect(row.onTap, isNotNull);
            expect(
              find.ancestor(
                of: offlineRow,
                matching: find.byWidgetPredicate(
                  (widget) => widget is Opacity && widget.opacity < 1,
                ),
              ),
              findsNothing,
            );
            final actions = find.descendant(
              of: offlineRow,
              matching: find.byType(IconButton),
            );
            expect(tester.widget<IconButton>(actions).onPressed, isNotNull);
            await Scrollable.ensureVisible(
              tester.element(actions),
              alignment: .5,
            );
            await tester.pumpAndSettle();
            await reveal(tester, actions);
            await tester.tap(actions);
            await tester.pumpAndSettle();
            expect(find.text(l10n.agentBotRoutinesMenuItem), findsOneWidget);
            final deleteAction = find.text(l10n.agentDeleteBot);
            await tester.ensureVisible(deleteAction);
            await tester.pumpAndSettle();
            expect(deleteAction.hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            Navigator.of(tester.element(offlineRow)).pop();
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              diagnostics,
              250,
              scrollable: find
                  .descendant(
                    of: find.byType(ListView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
            await Scrollable.ensureVisible(
              tester.element(diagnostics),
              alignment: .3,
            );
            await tester.pumpAndSettle();
            await tester.tap(diagnostics);
            await tester.pumpAndSettle();
            expect(find.text('test-engine-version'), findsOneWidget);
            expect(find.text('test-model'), findsOneWidget);
            expect(find.text('test-runtime'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byKey(
                  const PageStorageKey('agent-service-diagnostics'),
                ),
                matching: find.byType(HermesGlassCard),
              ),
              findsNothing,
            );
            expect(
              find.widgetWithText(SelectableText, 'test-model'),
              findsOneWidget,
            );
            await Scrollable.ensureVisible(
              tester.element(diagnostics),
              alignment: .3,
            );
            await tester.pumpAndSettle();
            await tester.tap(diagnostics);
            await tester.pumpAndSettle();
            expect(find.text('test-engine-version'), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            bots.dispose();
            session.dispose();
            requests.dispose();
            chat.dispose();
            connection.dispose();
          },
        );
      }
    }
  }
}
