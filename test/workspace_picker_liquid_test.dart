import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/sheets/workspace_picker_sheet.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';

void main() {
  testWidgets('workspace selection uses shared Liquid rows and returns path', (
    tester,
  ) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                picked = await showChatWorkspacePickerSheet(
                  context,
                  current: '/one',
                  defaultCwd: '/one',
                  sessionCwd: '/two',
                  projects: const [
                    {'path': '/one'},
                  ],
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('/one'), findsOneWidget);
    final selected = find.ancestor(
      of: find.text('/one'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(selected).selected, isTrue);
    expect(tester.getSize(selected).height, greaterThanOrEqualTo(56));
    expect(find.byType(BackdropFilter), findsOneWidget);
    await tester.tap(find.text('/two'));
    await tester.pumpAndSettle();
    expect(picked, '/two');
    expect(tester.takeException(), isNull);
  });
}
