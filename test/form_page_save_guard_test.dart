import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_adaptive_ui.dart';

void main() {
  testWidgets('throwing save preserves draft and allows retry', (tester) async {
    var attempts = 0;
    final gate = Completer<bool>();
    await tester.pumpWidget(
      MaterialApp(
        home: HermesFormPage(
          title: 'Editor',
          dirty: true,
          saveLabel: 'Save',
          onSave: () {
            attempts++;
            return attempts == 1 ? gate.future : Future.value(false);
          },
          child: const Text('Unsaved draft'),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    gate.completeError(StateError('private server details'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved draft'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('private server details'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
  for (final success in [false, true]) {
    testWidgets('form blocks back while saving success=$success', (
      tester,
    ) async {
      final completion = Completer<bool>();
      var saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HermesFormPage(
                      title: 'Editor',
                      dirty: true,
                      saveLabel: 'Save',
                      onSave: () {
                        saves++;
                        return completion.future;
                      },
                      child: const Text('Draft content'),
                    ),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      final navigator = Navigator.of(
        tester.element(find.byType(HermesFormPage)),
      );
      await navigator.maybePop();
      await tester.pump();
      expect(find.byType(HermesFormPage), findsOneWidget);
      expect(saves, 1);
      completion.complete(success);
      await tester.pumpAndSettle();
      expect(
        find.byType(HermesFormPage),
        success ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
