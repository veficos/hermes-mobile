import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/document_editor_screen.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'support/review_capture.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final brightness in Brightness.values) {
      testWidgets('document editor keep done discard $style $brightness', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
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
        String? result;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            theme: buildHermesTheme(brightness: brightness, visualStyle: style),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () async {
                    result = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const RepaintBoundary(
                          key: ValueKey('document-review'),
                          child: DocumentEditorScreen(
                            title: 'Document',
                            initialValue: '{}',
                            json: true,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        final l10n = AppLocalizations.of(
          tester.element(find.byType(DocumentEditorScreen)),
        );
        await tester.enterText(find.byType(TextField), '{"a":1}');
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.fileEditorKeepEditing));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '{"a":1}',
        );
        await tester.tap(find.byTooltip(l10n.configFullJson));
        await tester.pump();
        final formatted = tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text;
        expect(formatted, isNot('{"a":1}'));
        await tester.tap(find.byTooltip(l10n.commonCopy));
        await tester.pump();
        expect(copied, formatted);
        const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
        if (reviewDir.isNotEmpty) {
          await captureReview(
            tester,
            find.byKey(const ValueKey('document-review')),
            '$reviewDir/document-${style.name}-${brightness.name}-2.0.png',
          );
        }
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(find.byType(TextField)).bottom,
          lessThanOrEqualTo(544),
        );
        expect(find.text(l10n.commonDone).hitTestable(), findsOneWidget);
        if (reviewDir.isNotEmpty) {
          await captureReview(
            tester,
            find.byKey(const ValueKey('document-review')),
            '$reviewDir/document-keyboard-${style.name}-${brightness.name}-2.0.png',
          );
        }
        await tester.tap(find.text(l10n.commonDone));
        await tester.pumpAndSettle();
        expect(result, formatted);
        tester.view.resetViewInsets();
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'discard');
        await tester.pump();
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.fileEditorDiscard));
        await tester.pumpAndSettle();
        expect(result, isNull);
        expect(find.byType(DocumentEditorScreen), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
