import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_markdown.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('quote rule follows reading direction $direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Directionality(
            textDirection: direction,
            child: Builder(
              builder: (context) {
                for (final sheet in [
                  hermesUserMarkdownStyle(context),
                  hermesMarkdownStyle(context, conversation: true),
                ]) {
                  final decoration =
                      sheet.blockquoteDecoration! as BoxDecoration;
                  final border = decoration.border! as BorderDirectional;
                  final insets = border.dimensions.resolve(direction);
                  expect(insets.left, direction == TextDirection.ltr ? 3 : 0);
                  expect(insets.right, direction == TextDirection.rtl ? 3 : 0);
                }
                return MarkdownBody(
                  data: '> اقتباس للتأكد من اتجاه القراءة',
                  styleSheet: hermesUserMarkdownStyle(context),
                );
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final user in [false, true]) {
    testWidgets('emphasis inherits rendered heading size user=$user', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => MarkdownBody(
                data:
                    '# Heading **boldhead** *italichead*\n\nBody **boldbody** *italicbody*',
                styleSheet: user
                    ? hermesUserMarkdownStyle(context)
                    : hermesMarkdownStyle(
                        context,
                        compact: true,
                        conversation: true,
                      ),
              ),
            ),
          ),
        ),
      );
      final sizes = <String, double?>{};
      void inspect(InlineSpan span, TextStyle parent) {
        if (span is! TextSpan) return;
        final effective = parent.merge(span.style);
        for (final word in [
          'boldhead',
          'italichead',
          'boldbody',
          'italicbody',
        ]) {
          if (span.text?.contains(word) ?? false) {
            sizes[word] = effective.fontSize;
          }
        }
        for (final child in span.children ?? <InlineSpan>[]) {
          inspect(child, effective);
        }
      }

      for (final text in tester.widgetList<RichText>(find.byType(RichText))) {
        inspect(text.text, const TextStyle());
      }
      expect(sizes, {
        'boldhead': 22,
        'italichead': 22,
        'boldbody': 17,
        'italicbody': 17,
      });
      expect(tester.takeException(), isNull);
    });
  }
  for (final style in HermesVisualStyle.values) {
    for (final width in [320.0, 390.0, 600.0, 1280.0]) {
      testWidgets('conversation typography $style $width', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
            ),
            home: Builder(
              builder: (context) {
                final phone = style == HermesVisualStyle.liquid && width < 600;
                final markdown = hermesMarkdownStyle(
                  context,
                  compact: true,
                  conversation: true,
                );
                final ordinary = hermesMarkdownStyle(context, compact: true);
                final user = HermesLiquidTypography.messageBody(context);
                expect(user.fontSize, phone ? 17 : 14);
                expect(user.height, phone ? 1.6 : 1.75);
                expect(markdown.p!.fontSize, phone ? 17 : 14);
                expect(markdown.p!.height, phone ? 1.6 : 1.65);
                expect(
                  markdown.strong!.fontSize,
                  phone ? null : markdown.p!.fontSize,
                );
                expect(
                  markdown.em!.fontSize,
                  phone ? null : markdown.p!.fontSize,
                );
                expect(
                  markdown.h1!.fontSize!,
                  greaterThan(markdown.p!.fontSize!),
                );
                expect(markdown.code!.fontSize, ordinary.code!.fontSize);
                expect(ordinary.p!.fontSize, 14);
                final userMarkdown = hermesUserMarkdownStyle(context);
                expect(userMarkdown.p!.fontSize, user.fontSize);
                expect(userMarkdown.code!.fontSize, 13);
                if (phone) {
                  expect(userMarkdown.h1!.fontSize, markdown.h1!.fontSize);
                  expect(userMarkdown.h2!.fontSize, markdown.h2!.fontSize);
                  for (final text in [
                    userMarkdown.h1,
                    userMarkdown.h2,
                    userMarkdown.h3,
                    userMarkdown.h4,
                    userMarkdown.h5,
                    userMarkdown.h6,
                    userMarkdown.em,
                    userMarkdown.blockquote,
                    userMarkdown.a,
                    userMarkdown.listBullet,
                  ]) {
                    expect(text!.color, userMarkdown.p!.color);
                  }
                  expect(userMarkdown.a!.decoration, TextDecoration.underline);
                }
                return const SizedBox();
              },
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
