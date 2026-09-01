import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/code_block.dart';
import 'package:hermes_mobile/chat/content/inline_content_renderer.dart';
import 'package:hermes_mobile/chat/content/mermaid_view.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('inline Mermaid preview never creates a platform WebView', (
    tester,
  ) async {
    const source = 'flowchart TD\nA[Start] --> B[Done]';
    await tester.pumpWidget(_app(codeBlockOrArtifact(source, 'mermaid')));
    await tester.pump();

    expect(find.byType(MermaidStaticDiagramView), findsOneWidget);
    expect(find.byType(MermaidDiagramView), findsNothing);
  });

  testWidgets('very long markdown builds a bounded prefix until expanded', (
    tester,
  ) async {
    final source = 'start ${'x' * 13000} unique-tail-marker';
    await tester.pumpWidget(
      _app(SingleChildScrollView(child: InlineContentRenderer(text: source))),
    );
    await tester.pump();

    expect(find.textContaining('start'), findsWidgets);
    expect(find.textContaining('unique-tail-marker'), findsNothing);
    final scrollable = find.byType(Scrollable);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.expand_more),
      500,
      scrollable: scrollable.first,
    );
    await tester.tap(find.byIcon(Icons.expand_more));
    await tester.pump();
    expect(find.textContaining('unique-tail-marker'), findsWidgets);
  });
}
