import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/code_block.dart';
import 'package:hermes_mobile/chat/content/diff_view.dart';
import 'package:hermes_mobile/chat/content/inline_content_renderer.dart';
import 'package:hermes_mobile/chat/content/mermaid_view.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

Widget _app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  for (final opaque in [false, true]) {
    testWidgets(
      'Liquid streaming keeps material count bounded opaque=$opaque',
      (tester) async {
        final text = ValueNotifier('First words');
        addTearDown(text.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: opaque,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      child: ValueListenableBuilder<String>(
                        valueListenable: text,
                        builder: (_, value, _) =>
                            StreamingInlineContentRenderer(text: value),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: GlassSurface(child: SizedBox(height: 60)),
                  ),
                ],
              ),
            ),
          ),
        );
        final expected = opaque ? findsNothing : findsOneWidget;
        expect(find.byType(BackdropFilter), expected);
        text.value = '${'word ' * 1000}liquid-final-marker';
        for (var tick = 0; tick < 14; tick++) {
          await tester.pump(const Duration(milliseconds: 42));
          expect(find.byType(BackdropFilter), expected);
        }
        expect(
          tester
              .widgetList<InlineContentRenderer>(
                find.byType(InlineContentRenderer),
              )
              .map((w) => w.text)
              .join(),
          text.value,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('nested content does not attach to the transcript controller', (
    tester,
  ) async {
    final transcript = ScrollController();
    for (final content in <Widget>[
      FileDiffView(diff: '+added line\n' * 200),
      InlineContentRenderer(text: 'A paragraph with **formatting**.\n\n' * 500),
    ]) {
      await tester.pumpWidget(
        _app(
          PrimaryScrollController(
            controller: transcript,
            child: SingleChildScrollView(primary: true, child: content),
          ),
        ),
      );
      if (content is InlineContentRenderer) {
        await tester.scrollUntilVisible(
          find.byIcon(Icons.expand_more),
          1000,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pumpAndSettle();
      }
      expect(transcript.positions, hasLength(1));
      final outerOffset = transcript.offset;
      final inner = find.byType(Scrollable).at(1);
      tester.state<ScrollableState>(inner).position.jumpTo(100);
      await tester.pump();
      expect(transcript.offset, outerOffset);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    transcript.dispose();
  });

  testWidgets(
    'streamed burst reaches its exact tail within the cadence budget',
    (tester) async {
      final source = '${'word ' * 1000}burst-final-marker';
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            child: StreamingInlineContentRenderer(text: source),
          ),
        ),
      );
      for (var tick = 0; tick < 14; tick++) {
        await tester.pump(const Duration(milliseconds: 42));
      }
      final rendered = tester.widgetList<InlineContentRenderer>(
        find.byType(InlineContentRenderer),
      );
      expect(rendered.map((widget) => widget.text).join(), source);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'expanded long markdown lays out a viewport and reaches final paragraph',
    (tester) async {
      final source =
          '${'Paragraph with **formatting** and several words.\n\n' * 400}last-expanded-paragraph';
      await tester.pumpWidget(
        _app(SingleChildScrollView(child: InlineContentRenderer(text: source))),
      );
      await tester.scrollUntilVisible(
        find.byIcon(Icons.expand_more),
        1000,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();
      final viewport = find.byKey(const ValueKey('expanded-markdown-viewport'));
      expect(tester.getSize(viewport).height, 480);
      expect(find.textContaining('last-expanded-paragraph'), findsNothing);
      await tester.ensureVisible(viewport);
      await tester.scrollUntilVisible(
        find.textContaining('last-expanded-paragraph'),
        1200,
        scrollable: find
            .descendant(of: viewport, matching: find.byType(Scrollable))
            .first,
        maxScrolls: 100,
      );
      expect(find.textContaining('last-expanded-paragraph'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large code builds bounded chunks and can reach its tail', (
    tester,
  ) async {
    final source = '${'line of code;\n' * 10000}unique-code-tail';
    await tester.pumpWidget(
      _app(HermesCodeBlock(code: source, language: 'text')),
    );
    expect(find.textContaining('unique-code-tail'), findsNothing);
    final visible = tester.widgetList<SelectableText>(
      find.byType(SelectableText),
    );
    expect(visible.length, lessThan(10));
    expect(visible.every((text) => (text.data?.length ?? 0) <= 2000), isTrue);
    await tester.scrollUntilVisible(
      find.textContaining('unique-code-tail'),
      1500,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('large-code-viewport')),
            matching: find.byType(Scrollable),
          )
          .first,
      maxScrolls: 250,
    );
    expect(find.textContaining('unique-code-tail'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'completed streaming blocks retain their widget on tail updates',
    (tester) async {
      final prefix = '@session:abc completed paragraph\n\n' * 400;
      var title = 'original title';
      Widget render(String text) => _app(
        SingleChildScrollView(
          child: StreamingInlineContentRenderer(
            text: text,
            sessionTitleOf: (_) => title,
          ),
        ),
      );
      await tester.pumpWidget(render('${prefix}tail'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 42));
      }
      final stable = find.byKey(const ValueKey('stream-block-0'));
      expect(stable, findsOneWidget);
      final before = tester.widget(stable);
      await tester.pumpWidget(render('${prefix}tail continues'));
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 42));
      }
      expect(tester.widget(stable), same(before));
      title = 'updated title';
      await tester.pumpWidget(render('${prefix}tail continues'));
      expect(
        tester.widget<InlineContentRenderer>(stable).text,
        contains('updated title'),
      );
      expect(tester.widget(stable), isNot(same(before)));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

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
