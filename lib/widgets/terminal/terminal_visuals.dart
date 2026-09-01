import 'package:flutter/material.dart';
import 'package:xterm/xterm.dart';

import '../../core/stores/terminal_store.dart';

/// Visual-only terminal palette. Kept separate from terminal behavior so the
/// PTY, keyboard and session lifecycle remain unaffected by theme changes.
class HermesTerminalVisuals {
  const HermesTerminalVisuals._();

  static const darkBackground = Color(0xff0b0f14);
  static const darkSurface = Color(0xff111821);
  static const darkElevated = Color(0xff17212c);
  static const darkBorder = Color(0xff263341);
  static const darkForeground = Color(0xffd8dee9);

  static const lightBackground = Color(0xfff7f8fa);
  static const lightSurface = Color(0xffffffff);
  static const lightElevated = Color(0xffeef1f5);
  static const lightBorder = Color(0xffd8dde5);
  static const lightForeground = Color(0xff202733);

  static Brightness effectiveBrightness(
    Brightness appBrightness, [
    TerminalColorPreset preset = TerminalColorPreset.system,
  ]) => switch (preset) {
    TerminalColorPreset.professionalDark ||
    TerminalColorPreset.highContrastDark => Brightness.dark,
    TerminalColorPreset.softLight => Brightness.light,
    TerminalColorPreset.system => appBrightness,
  };

  static Color background(
    Brightness brightness, [
    TerminalColorPreset preset = TerminalColorPreset.system,
  ]) {
    if (preset == TerminalColorPreset.highContrastDark) {
      return const Color(0xff050709);
    }
    return effectiveBrightness(brightness, preset) == Brightness.dark
        ? darkBackground
        : lightBackground;
  }

  static Color surface(Brightness brightness) =>
      brightness == Brightness.dark ? darkSurface : lightSurface;

  static Color elevated(Brightness brightness) =>
      brightness == Brightness.dark ? darkElevated : lightElevated;

  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;

  static TerminalTheme terminalTheme(
    Brightness brightness,
    Color accent, {
    TerminalColorPreset preset = TerminalColorPreset.system,
  }) {
    final effective = effectiveBrightness(brightness, preset);
    final dark = effective == Brightness.dark;
    final highContrast = preset == TerminalColorPreset.highContrastDark;
    return TerminalTheme(
      cursor: accent,
      selection: accent.withValues(alpha: dark ? .34 : .22),
      foreground: highContrast
          ? const Color(0xfff5f7fa)
          : dark
          ? darkForeground
          : lightForeground,
      background: highContrast
          ? const Color(0xff050709)
          : dark
          ? darkBackground
          : lightSurface,
      black: dark ? const Color(0xff202832) : const Color(0xff303741),
      red: dark ? const Color(0xffff6b7a) : const Color(0xffc43d4b),
      green: dark ? const Color(0xff78dba9) : const Color(0xff1f8655),
      yellow: dark ? const Color(0xffffcb6b) : const Color(0xff9b6a00),
      blue: dark ? const Color(0xff91b4ff) : const Color(0xff1d58a5),
      magenta: dark ? const Color(0xffc792ea) : const Color(0xff8e44ad),
      cyan: dark ? const Color(0xff66d9d0) : const Color(0xff147d85),
      white: dark ? const Color(0xffd8dee9) : const Color(0xffe7e9ed),
      brightBlack: dark ? const Color(0xff8794a3) : const Color(0xff626c78),
      brightRed: dark ? const Color(0xffff8b96) : const Color(0xffe05260),
      brightGreen: dark ? const Color(0xff96e6bd) : const Color(0xff2da66c),
      brightYellow: dark ? const Color(0xffffd98a) : const Color(0xffbc8400),
      brightBlue: dark ? const Color(0xffa4bdff) : const Color(0xff347ad8),
      brightMagenta: dark ? const Color(0xffd8a7ef) : const Color(0xffa85fc5),
      brightCyan: dark ? const Color(0xff8be3dc) : const Color(0xff1998a2),
      brightWhite: dark ? const Color(0xffffffff) : const Color(0xff303741),
      searchHitBackground: const Color(0xffffd166),
      searchHitBackgroundCurrent: accent,
      searchHitForeground: const Color(0xff101317),
    );
  }
}
