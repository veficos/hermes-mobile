import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_appearance_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_zh.dart';
import 'package:hermes_mobile/widgets/session/session_row_actions.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingSessionStore extends SessionStore {
  _RecordingSessionStore()
    : super(
        connection: ConnectionStore(),
        chat: ChatStore(),
        requests: RequestStore(),
      );

  String? pinnedId;
  bool? pinnedValue;
  String? renamedTitle;
  String? duplicatedId;
  String? sharedId;
  SessionRow duplicatedRow = SessionRow(id: 'session-copy');
  String shareUrl = 'https://hermes.example/share/token-123';

  @override
  Future<void> setPinned(String id, bool pinned) async {
    pinnedId = id;
    pinnedValue = pinned;
  }

  @override
  Future<void> renameStoredSession(String id, String title) async {
    renamedTitle = title;
  }

  @override
  Future<SessionRow> duplicateStoredSession(String id) async {
    duplicatedId = id;
    return duplicatedRow;
  }

  @override
  Future<String> createStoredSessionShare(String id) async {
    sharedId = id;
    return shareUrl;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('session color override persists and clears', () async {
    SharedPreferences.setMockInitialValues({});
    final first = SessionAppearanceStore();
    final color = SessionAppearanceStore.swatches[3];
    await first.setColor('session-color', color);

    final restored = SessionAppearanceStore();
    await restored.load();
    expect(restored.colorFor('session-color')?.toARGB32(), color.toARGB32());

    await restored.setColor('session-color', null);
    final cleared = SessionAppearanceStore();
    await cleared.load();
    expect(cleared.colorFor('session-color'), isNull);
  });

  testWidgets('session action remains valid after the sheet is dismissed', (
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

    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              pageContext = context;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    unawaited(
      SessionRowActions.show(
        pageContext,
        session: SessionRow(
          id: 'session-1',
          title: 'Diagnostic session',
          messageCount: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('重新生成标题'), findsNothing);
    expect(find.text('交接到其他端'), findsNothing);
    expect(
      find.text(AppLocalizationsZh().chatBranchInNewSession),
      findsOneWidget,
    );
    expect(find.text('复制会话'), findsOneWidget);
    expect(find.text('分享会话'), findsOneWidget);
    await tester.tap(find.text(AppLocalizationsZh().chatCopySessionId));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(clipboardText, 'session-1');
    expect(find.text(AppLocalizationsZh().chatSessionIdCopied), findsOneWidget);
  });

  testWidgets('store-backed action remains valid after sheet dismissal', (
    tester,
  ) async {
    final store = _RecordingSessionStore();
    addTearDown(store.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    unawaited(
      SessionRowActions.show(
        pageContext,
        session: SessionRow(id: 'session-2', title: 'Store action'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('置顶'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(store.pinnedId, 'session-2');
    expect(store.pinnedValue, isTrue);
  });

  testWidgets('rename permits clearing a stored title like desktop', (
    tester,
  ) async {
    final store = _RecordingSessionStore();
    addTearDown(store.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    unawaited(
      SessionRowActions.show(
        pageContext,
        session: SessionRow(id: 'session-3', title: 'Old title'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('重命名'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(store.renamedTitle, '');
  });

  testWidgets(
    'duplicate menu item calls the store and offers to open the copy',
    (tester) async {
      final store = _RecordingSessionStore();
      addTearDown(store.dispose);
      var refreshed = false;
      String? openedCopyId;
      late BuildContext pageContext;
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionStore>.value(
          value: store,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  pageContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      unawaited(
        SessionRowActions.show(
          pageContext,
          session: SessionRow(id: 'session-4', title: 'Source session'),
          onRefreshed: () async {
            refreshed = true;
          },
          onOpenCopy: (copy) async {
            openedCopyId = copy.id;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('复制会话'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(store.duplicatedId, 'session-4');
      expect(refreshed, isTrue);
      expect(
        find.text(AppLocalizationsZh().sessionActionCopyCreated),
        findsOneWidget,
      );

      await tester.tap(find.text(AppLocalizationsZh().commonOpen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(openedCopyId, 'session-copy');
    },
  );

  testWidgets('share menu item shows the link dialog and copies the link', (
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

    final store = _RecordingSessionStore();
    addTearDown(store.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionStore>.value(
        value: store,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    unawaited(
      SessionRowActions.show(
        pageContext,
        session: SessionRow(id: 'session-5', title: 'Shared session'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享会话'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(store.sharedId, 'session-5');
    expect(
      find.text(AppLocalizationsZh().sessionActionShareCreated),
      findsOneWidget,
    );
    expect(find.text(store.shareUrl), findsOneWidget);

    await tester.tap(find.text(AppLocalizationsZh().chatCopySessionLink));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(clipboardText, store.shareUrl);
    expect(
      find.text(AppLocalizationsZh().chatSessionShareLinkCopied),
      findsOneWidget,
    );
  });

  testWidgets('appearance swatch updates the durable session override', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = _RecordingSessionStore();
    final appearance = SessionAppearanceStore();
    addTearDown(store.dispose);
    addTearDown(appearance.dispose);
    late BuildContext pageContext;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionStore>.value(value: store),
          ChangeNotifierProvider<SessionAppearanceStore>.value(
            value: appearance,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                pageContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    unawaited(
      SessionRowActions.show(
        pageContext,
        session: SessionRow(id: 'session-appearance', title: 'Styled'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('外观'));
    await tester.pumpAndSettle();
    final color = SessionAppearanceStore.swatches[5];
    await tester.tap(find.byKey(ValueKey('session-color-${color.toARGB32()}')));
    await tester.pumpAndSettle();

    expect(
      appearance.colorFor('session-appearance')?.toARGB32(),
      color.toARGB32(),
    );
  });
}
