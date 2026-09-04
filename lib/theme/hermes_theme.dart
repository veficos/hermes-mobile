/// Hermes 主题构建 —— 应用设计系统规范 v2.0 的 token（design-system.md）。
///
/// 由 `Brightness` + `HermesAccent`（4 套主题：graphite/indigo/moss/dune）
/// 构建。主题携带的 [HermesPalette] 同时注入 ColorScheme 与
/// ThemeExtension（`HermesPalette.of(context)`），组件全部从调色板取色，
/// 随主题切换自动换肤（lerp 支持交叉淡化）。
///
/// 约定：
/// - 文本/边框/背景不要硬编码 `Colors.white/black` 或 HermesText/
///   HermesBackground 常量，优先 `HermesPalette.of(context)` 或
///   `ColorScheme.onSurface` 系，保证四主题 × 明暗 × 高对比都成立。
library;

import 'package:flutter/material.dart';

import 'hermes_tokens.dart';

ThemeData buildHermesTheme({
  required Brightness brightness,
  HermesAccent accent = HermesAccents.graphite,
  bool highContrast = false,
}) {
  final isDark = brightness == Brightness.dark;
  final palette = accent.paletteOf(brightness);
  final accentColor = palette.accent;

  // 高对比模式（design-system.md §3.7）：文字拉满纯黑/纯白，边框升级为
  // border-strong 且加粗至 1.5px；accent 不变。
  final textPrimary = highContrast
      ? (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
      : palette.text;
  final textSecondary = highContrast
      ? (isDark ? const Color(0xFFEFF2F6) : const Color(0xFF1F232B))
      : palette.text2;
  final border = highContrast ? palette.borderStrong : palette.border;
  final borderWidth = highContrast ? 1.5 : 1.0;

  final onAccentColor = accentColor.computeLuminance() > 0.5
      ? Colors.black
      : Colors.white;
  final onAccentContainerColor = accentColor.computeLuminance() > 0.5
      ? Colors.black87
      : Colors.white70;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: accentColor,
        brightness: brightness,
        primary: accentColor,
        secondary: accentColor,
        surface: palette.surface,
        error: isDark ? HermesSemanticDark.red : HermesSemantic.red,
      ).copyWith(
        // 手工计算 onPrimary 系——fromSeed 对深色模式下的浅 accent 会误判。
        onPrimary: onAccentColor,
        onPrimaryContainer: onAccentColor,
        onSecondary: onAccentColor,
        onSecondaryContainer: onAccentColor,
        onSurface: textPrimary,
        onSurfaceVariant: textSecondary,
        onPrimaryFixed: onAccentColor,
        onPrimaryFixedVariant: onAccentContainerColor,
        onSecondaryFixed: onAccentColor,
        onSecondaryFixedVariant: onAccentContainerColor,
        surfaceContainerHighest: palette.elevated,
        outlineVariant: palette.border,
      );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    extensions: [palette],
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: palette.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 52,
      shape: Border(
        bottom: BorderSide(color: border, width: borderWidth),
      ),
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: textSecondary, size: 20),
      actionsIconTheme: IconThemeData(color: textSecondary, size: 20),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: border, width: borderWidth),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.bg,
      selectedItemColor: accentColor,
      unselectedItemColor: highContrast ? textSecondary : palette.text3,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 66,
      elevation: 0,
      backgroundColor: palette.surface,
      indicatorColor: palette.accentBg,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 20,
          color: states.contains(WidgetState.selected)
              ? palette.accent
              : palette.text3,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? palette.text
              : palette.text3,
        ),
      ),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.codeBg,
      hintStyle: TextStyle(color: palette.text3),
      // §6.2：r-md 10，1px border；聚焦 accent + 光晕由 focusColor 承担。
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.error, width: borderWidth),
      ),
      focusColor: accentColor,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: palette.elevated,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.dialog),
        side: BorderSide(color: border, width: borderWidth),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.elevated,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.elevated,
      modalBarrierColor: Colors.black.withValues(alpha: .38),
      elevation: 0,
      modalElevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: border, width: borderWidth),
      ),
      showDragHandle: false,
    ),
    // 弹出菜单（PopupMenuButton/showMenu）：默认 Material3 会用一套跟随
    // seed color 走的浅色调 tonal surface，跟卡片/对话框实际用的 palette
    // 背景不是同一套色，边角也偏小（4dp）——在四套主题下都会显得脱节。
    // 统一成跟 dialogTheme 一样的 elevated 底 + 1px border + r-xl 圆角。
    popupMenuTheme: PopupMenuThemeData(
      color: palette.elevated,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.dialog),
        side: BorderSide(color: border, width: borderWidth),
      ),
      textStyle: TextStyle(color: textPrimary, fontSize: 14),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          color: states.contains(WidgetState.disabled)
              ? palette.text4
              : textPrimary,
          fontSize: 14,
        ),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.elevated),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(vertical: 6),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesRadius.dialog),
            side: BorderSide(color: border, width: borderWidth),
          ),
        ),
      ),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: TextStyle(color: textPrimary, fontSize: 14),
      menuStyle: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(palette.elevated),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(8),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HermesRadius.dialog),
            side: BorderSide(color: border, width: borderWidth),
          ),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? palette.elevated : const Color(0xFF16181D),
      // Snackbar 底恒为深色，前景用 Graphite 深色主题一级文字色。
      contentTextStyle: const TextStyle(
        color: HermesText.darkPrimary,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.card),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accentColor,
        foregroundColor: scheme.onPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: BorderSide(color: border, width: borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accentColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        ),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: accentColor),
    dividerTheme: DividerThemeData(color: border, thickness: borderWidth),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.selected) ? accentColor : palette.text3,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accentColor.withValues(alpha: highContrast ? 0.7 : 0.4)
            : border,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? accentColor
            : palette.borderStrong,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: palette.text3,
      textColor: textPrimary,
    ),
    textTheme: base.textTheme
        .copyWith(
          // HermesType 裸样式无色——在此合并 onSurface/onSurfaceVariant。
          displayLarge: HermesType.display.copyWith(color: textPrimary),
          headlineLarge: HermesType.largeTitle.copyWith(color: textPrimary),
          titleLarge: HermesType.title.copyWith(color: textPrimary),
          titleMedium: HermesType.headline.copyWith(color: textPrimary),
          bodyLarge: HermesType.body.copyWith(color: textPrimary),
          bodyMedium: HermesType.callout.copyWith(color: textSecondary),
          bodySmall: HermesType.subheadline.copyWith(color: textSecondary),
          labelMedium: HermesType.footnote.copyWith(color: textSecondary),
          labelSmall: HermesType.caption.copyWith(color: textPrimary),
        )
        .apply(fontFamilyFallback: HermesFonts.ui),
  );
}
