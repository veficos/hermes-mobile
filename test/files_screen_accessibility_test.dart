import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/file_tree_store.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/files_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';
import 'package:hermes_mobile/widgets/right_sidebar/file_tree_panel.dart';
import 'package:hermes_mobile/widgets/glass/glass_search_field.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

class _AccessibleFilesApi extends ApiClient {
  _AccessibleFilesApi()
    : super(baseUrl: 'http://files.invalid', apiKey: 'test');

  @override
  Future<String> fsDefaultCwd() async => '/workspace';

  @override
  Future<Map<String, dynamic>> fsEntries(String path, {String? root}) async => {
    'entries': [
      {
        'name': 'long-file-name-for-selection-testing.md',
        'path': '/workspace/long-file-name-for-selection-testing.md',
        'is_directory': false,
        'size': 42,
      },
    ],
  };
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sidebar search expands for large text and clears', (
    tester,
  ) async {
    final connection = ConnectionStore()..api = _AccessibleFilesApi();
    addTearDown(connection.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.dark,
            visualStyle: HermesVisualStyle.liquid,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox(width: 360, child: FileTreePanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fileLabel = find.text('long-file-name-for-selection-testing.md');
    final fileContext = tester.element(fileLabel);
    final fileStore = fileContext.read<FileTreeStore>();
    fileStore.selectPreview(fileStore.currentEntries!.single);
    await tester.pumpAndSettle();
    final selectedMaterial = tester.widget<Material>(
      find.ancestor(of: fileLabel, matching: find.byType(Material)).first,
    );
    expect(
      selectedMaterial.color,
      Theme.of(tester.element(fileLabel)).colorScheme.surfaceContainerHighest,
    );
    expect(selectedMaterial.color!.a, 1);
    final refresh = find.descendant(
      of: find.byType(GlassButton),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(refresh).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'query');
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(GlassSearchField)).height,
      greaterThan(44),
    );
    final clear = find.descendant(
      of: find.byType(GlassSearchField),
      matching: find.byType(IconButton),
    );
    expect(tester.getSize(clear).shortestSide, greaterThanOrEqualTo(44));
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    final l10n = AppLocalizations.of(
      tester.element(find.byType(FileTreePanel)),
    );
    tester.widget<EditableText>(find.byType(EditableText)).focusNode.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(l10n.commonMore).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(l10n.filesNewFolder));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.create_new_folder_outlined).last);
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text(l10n.commonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(GlassAlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final folder in [false, true]) {
    testWidgets('Liquid file creation dialog keyboard safe folder=$folder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final connection = ConnectionStore()..api = _AccessibleFilesApi();
      addTearDown(connection.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionStore>.value(
          value: connection,
          child: MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const FilesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(
        tester.element(find.byType(FilesScreen)),
      );
      await tester.tap(find.byTooltip(l10n.commonMore).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commonNew));
      await tester.pumpAndSettle();
      // A short viewport with an active keyboard must scroll the chooser,
      // not overflow its rounded material.
      tester.view.physicalSize = const Size(390, 400);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text(folder ? l10n.filesNewFolder : l10n.filesNewFile),
      );
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(folder ? l10n.filesNewFolder : l10n.filesNewFile),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(find.byType(GlassAlertDialog), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final cancel = find.text(l10n.commonCancel);
      expect(cancel.hitTestable(), findsOneWidget);
      expect(tester.getRect(cancel).bottom, lessThan(544));
      await tester.enterText(find.byType(TextField).last, 'draft-name');
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.byType(GlassAlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selection actions fit narrow Arabic layout at 2x text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final connection = ConnectionStore()..api = _AccessibleFilesApi();
    addTearDown(connection.dispose);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: const [
            ...AppLocalizations.localizationsDelegates,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const FilesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(
      find.text('long-file-name-for-selection-testing.md'),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.download_outlined), findsWidgets);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(
      find.bySemanticsLabel(
        RegExp(
          RegExp.escape(
            AppLocalizations.of(
              tester.element(find.byType(FilesScreen)),
            ).filesDownload,
          ),
        ),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });
}
