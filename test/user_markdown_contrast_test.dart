import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/h/hermes_markdown.dart';

void main() {
  for (final width in [390.0, 900.0, 1280.0]) {
    for (final accent in HermesAccents.all) {
      for (final brightness in Brightness.values) {
        testWidgets('user rich text contrast ${accent.id} $brightness $width', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: brightness,
                accent: accent,
                visualStyle: HermesVisualStyle.liquid,
              ),
              home: Builder(
                builder: (context) {
                  final palette = HermesPalette.of(context);
                  final style = hermesUserMarkdownStyle(context);
                  final quote = style.blockquoteDecoration! as BoxDecoration;
                  final quoteBackground = Color.alphaBlend(
                    quote.color ?? Colors.transparent,
                    palette.bubbleUser,
                  );
                  for (final entry in [
                    (style.p!, palette.bubbleUser),
                    (style.h1!, palette.bubbleUser),
                    (style.strong!, palette.bubbleUser),
                    (style.em!, palette.bubbleUser),
                    (style.a!, palette.bubbleUser),
                    (style.listBullet!, palette.bubbleUser),
                    (style.blockquote!, quoteBackground),
                  ]) {
                    final foreground = Color.alphaBlend(
                      entry.$1.color!,
                      entry.$2,
                    );
                    final a = foreground.computeLuminance();
                    final b = entry.$2.computeLuminance();
                    expect(
                      ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
                      greaterThanOrEqualTo(4.5),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          );
        });
      }
    }
  }
}
