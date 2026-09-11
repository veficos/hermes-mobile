import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';

void main() {
  for (final accent in HermesAccents.all) {
    for (final brightness in Brightness.values) {
      for (final highContrast in [false, true]) {
        test(
          'segmented selected contrast ${accent.id} $brightness high=$highContrast',
          () {
            final theme = buildHermesTheme(
              brightness: brightness,
              accent: accent,
              highContrast: highContrast,
              visualStyle: HermesVisualStyle.liquid,
            );
            final style = theme.segmentedButtonTheme.style!;
            for (final interaction in <WidgetState?>[
              null,
              WidgetState.hovered,
              WidgetState.focused,
              WidgetState.pressed,
            ]) {
              final states = {
                WidgetState.selected,
                ?interaction,
              };
              final base = style.backgroundColor!.resolve(states)!;
              final background = Color.alphaBlend(
                style.overlayColor!.resolve(states)!,
                base,
              );
              final foreground = Color.alphaBlend(
                style.foregroundColor!.resolve(states)!,
                background,
              );
              final a = background.computeLuminance(),
                  b = foreground.computeLuminance();
              final ratio = a > b
                  ? (a + .05) / (b + .05)
                  : (b + .05) / (a + .05);
              expect(
                ratio,
                greaterThanOrEqualTo(4.5),
                reason: 'interaction=$interaction',
              );
            }
          },
        );
      }
    }
  }
}
