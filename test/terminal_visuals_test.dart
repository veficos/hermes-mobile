import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/terminal/terminal_visuals.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';

void main() {
  test('terminal palettes adapt to app brightness and retain contrast', () {
    const accent = Color(0xff4f7cff);
    final dark = HermesTerminalVisuals.terminalTheme(Brightness.dark, accent);
    final light = HermesTerminalVisuals.terminalTheme(Brightness.light, accent);

    expect(dark.background, HermesTerminalVisuals.darkBackground);
    expect(light.background, HermesTerminalVisuals.lightSurface);
    expect(dark.cursor, accent);
    expect(light.cursor, accent);
    expect(dark.foreground.computeLuminance(), greaterThan(.5));
    expect(light.foreground.computeLuminance(), lessThan(.1));
    expect(dark.selection.a, lessThan(1));
    expect(light.selection.a, lessThan(1));
  });

  test('explicit terminal presets override app brightness', () {
    const accent = Color(0xff4f7cff);
    final contrast = HermesTerminalVisuals.terminalTheme(
      Brightness.light,
      accent,
      preset: TerminalColorPreset.highContrastDark,
    );
    final softLight = HermesTerminalVisuals.terminalTheme(
      Brightness.dark,
      accent,
      preset: TerminalColorPreset.softLight,
    );

    expect(contrast.background, const Color(0xff050709));
    expect(contrast.foreground.computeLuminance(), greaterThan(.8));
    expect(softLight.background, HermesTerminalVisuals.lightSurface);
  });
}
