/// Hermes 设计系统规范 v2.0 —— design tokens 唯一来源。
///
/// 对应 docs/ui-redesign/design-system.md。全部视觉值（色彩/字体/间距/
/// 圆角/阴影）以 token 定义，页面禁止硬编码。
///
/// ── CSS variable ↔ Dart token map（design-system.md §3.1）────────────────
/// --bg/--surface/--elevated/--border/--border-strong → HermesPalette
/// --text…--text-4          → HermesPalette.text/text2/text3/text4
/// --accent 四态            → HermesPalette.accent/accentHover/accentBg/accentStrong
/// --code-bg / --bubble-user → HermesPalette.codeBg/bubbleUser/bubbleUserText
/// --success…--purple       → HermesSemantic（light 值）+ HermesSemanticDark
/// 主题集合                 → HermesAccents（4 套：graphite/indigo/moss/dune）
/// --radius-sm…full         → HermesRadius
/// --shadow-sm/md/lg        → hermesShadow()（dark 不使用投影，用边框分层）
library;

import 'package:flutter/material.dart';

/// ── Brand（design-system.md §2：品牌视觉重塑）─────────────────────────────
abstract final class HermesBrand {
  /// 品牌主色 Signal Blue（Graphite 浅色 accent 派生）。
  static const Color signalBlue = Color(0xFF2F6BFF);

  /// 品牌主色（深色底上）。
  static const Color signalBlueDark = Color(0xFF6E97FF);
}

/// ── Font stacks（design-system.md §4.1）───────────────────────────────────
abstract final class HermesFonts {
  /// --font-ui: Segoe UI, Inter, -apple-system, PingFang SC,
  /// Hiragino Sans GB, Microsoft YaHei, Noto Sans CJK SC, sans-serif
  static const List<String> ui = [
    'Segoe UI',
    'Inter',
    'PingFang SC',
    'Hiragino Sans GB',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'sans-serif',
  ];

  /// --font-conv: 会话消息流专用（继承 --font-ui）。
  static const List<String> conversation = ui;

  /// --font-mono: Consolas, JetBrains Mono, Fira Code, Cascadia Code,
  /// DejaVu Sans Mono, Liberation Mono, SF Mono, Menlo
  static const List<String> mono = [
    'Consolas',
    'JetBrains Mono',
    'Fira Code',
    'Cascadia Code',
    'DejaVu Sans Mono',
    'Liberation Mono',
    'SF Mono',
    'Menlo',
    'monospace',
  ];
}

/// Responsive layout boundaries and shared content widths.
abstract final class HermesBreakpoints {
  static const double compact = 430;
  static const double phone = 600;

  /// Keep phone-style navigation and compact app bars until there is enough
  /// room for a rail without squeezing the primary content.
  static const double navigation = 840;

  /// 600-959 is the medium window class: rail or two-pane layouts only.
  static const double tablet = 960;
  static const double desktop = 1200;
}

enum HermesWindowClass { compact, medium, expanded }

HermesWindowClass hermesWindowClass(double width) {
  if (width < HermesBreakpoints.phone) return HermesWindowClass.compact;
  if (width < HermesBreakpoints.tablet) return HermesWindowClass.medium;
  return HermesWindowClass.expanded;
}

/// Dock both chat side panes only if the conversation keeps a useful width.
bool hermesCanUseThreePaneChat(
  double width, {
  double sessionRailWidth = 220,
  double contextRailWidth = 280,
  double minimumConversationWidth = 480,
}) =>
    width >= HermesBreakpoints.tablet &&
    width - sessionRailWidth - contextRailWidth - 2 >= minimumConversationWidth;

abstract final class HermesLayout {
  static const double contentNarrow = 720;
  static const double content = 760;
  static const double contentWide = 960;
  static const double workspace = 1120;
  static const double workspaceWide = 1200;
  static const double dialog = 520;
  static const double preview = 640;
}

abstract final class HermesMotion {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 180);
  static const Duration deliberate = Duration(milliseconds: 220);
  static const Duration toast = Duration(milliseconds: 2400);
}

/// Product behavior defaults. Security ceilings remain server-owned.
abstract final class HermesPolicy {
  static const Duration httpTimeout = Duration(seconds: 30);
  static const Duration gatewayTimeout = Duration(seconds: 120);
  static const Duration socketConnectTimeout = Duration(seconds: 15);
  static const Duration sessionPollInterval = Duration(seconds: 5);
  static const Duration taskPollInterval = Duration(seconds: 15);
  static const int pageSize = 50;
  static const int bulkSessionLimit = 500;
  static const int folderAttachmentLimit = 50;
  static const int terminalSessionLimit = 5;
  static const int terminalHistoryLimit = 200;
  static const int terminalScrollbackLines = 1000;
}

/// Canonical third-party brand colors shared by credentials and messaging UI.
abstract final class HermesProviderBrand {
  static const aws = Color(0xFFFF9900);
  static const gcp = Color(0xFF4285F4);
  static const azure = Color(0xFF0078D4);
  static const openAi = Color(0xFF10A37F);
  static const anthropic = Color(0xFFD97757);
  static const github = Color(0xFF333333);
  static const jira = Color(0xFF0052CC);
  static const slack = Color(0xFF4A154B);
  static const telegram = Color(0xFF229ED9);
  static const discord = Color(0xFF5865F2);
  static const whatsapp = Color(0xFF25D366);
  static const wechat = Color(0xFF07C160);
  static const imessage = Color(0xFF007AFF);
  static const imessageBubble = Color(0xFF34C759);
  static const signal = Color(0xFF2592E9);
  static const feishu = Color(0xFF2B6AFF);
  static const feishuSettings = Color(0xFF00B96B);
  static const dingtalk = Color(0xFF1677FF);
}

/// ── Semantic colors（design-system.md §3.6，四主题共享）────────────────────
/// 常量为浅色值；深色值见 [HermesSemanticDark]，用 `hermesSemantic()` 解析。
abstract final class HermesSemantic {
  static const Color green = Color(0xFF1F9254); // --success
  static const Color orange = Color(0xFFC77700); // --warning
  static const Color red = Color(0xFFD64545); // --error
  static const Color blue = Color(0xFF2B6CB0); // --info
  static const Color gray = Color(0xFF64748B); // --neutral
  static const Color purple = Color(0xFF7C3AED); // --purple
}

/// 语义色深色变体（design-system.md §3.6 Dark 列）。
abstract final class HermesSemanticDark {
  static const Color green = Color(0xFF4CC38A);
  static const Color orange = Color(0xFFF5A623);
  static const Color red = Color(0xFFF26D6D);
  static const Color blue = Color(0xFF63A6E8);
  static const Color gray = Color(0xFF94A3B8);
  static const Color purple = Color(0xFFA78BFA);
}

/// 按当前亮度解析语义色。
Color hermesSemantic(BuildContext context, Color light, Color dark) =>
    Theme.of(context).brightness == Brightness.dark ? dark : light;

/// ── 主题调色板（design-system.md §3.1，一套主题 × 一种亮度的完整色板）──────
///
/// 作为 [ThemeExtension] 注册到 ThemeData，组件通过 `HermesPalette.of(context)`
/// 读取当前主题的真实色板；lerp 实现支持主题切换时的交叉淡化。
class HermesPalette extends ThemeExtension<HermesPalette> {
  final Color bg;
  final Color surface;
  final Color elevated;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color text4;
  final Color accent;
  final Color accentHover;
  final Color accentBg;
  final Color accentStrong;
  final Color codeBg;
  final Color bubbleUser;
  final Color bubbleUserText;

  const HermesPalette({
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.text4,
    required this.accent,
    required this.accentHover,
    required this.accentBg,
    required this.accentStrong,
    required this.codeBg,
    required this.bubbleUser,
    required this.bubbleUserText,
  });

  /// 读取当前主题色板；未注册时回退 Graphite。
  static HermesPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HermesPalette>() ??
        (theme.brightness == Brightness.dark
            ? HermesAccents.graphite.darkPalette
            : HermesAccents.graphite.lightPalette);
  }

  @override
  HermesPalette copyWith() => this;

  @override
  HermesPalette lerp(HermesPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return HermesPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      elevated: l(elevated, other.elevated),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      text4: l(text4, other.text4),
      accent: l(accent, other.accent),
      accentHover: l(accentHover, other.accentHover),
      accentBg: l(accentBg, other.accentBg),
      accentStrong: l(accentStrong, other.accentStrong),
      codeBg: l(codeBg, other.codeBg),
      bubbleUser: l(bubbleUser, other.bubbleUser),
      bubbleUserText: l(bubbleUserText, other.bubbleUserText),
    );
  }
}

/// ── Text scale ─────────────────────────────────────────────────────────────
/// 常量值 = 默认主题 Graphite（design-system.md §3.2）。直接引用这些常量的
/// 旧代码保持可编译；新代码应使用 `HermesPalette.of(context)` 跟随主题。
abstract final class HermesText {
  // Light（Graphite）
  static const Color lightPrimary = Color(0xFF16181D);
  static const Color lightSecondary = Color(0xFF3E4450);
  static const Color lightTertiary = Color(0xFF6B7280);
  static const Color lightQuaternary = Color(0xFF9CA3AF);
  // Dark（Graphite）
  static const Color darkPrimary = Color(0xFFF2F4F8);
  static const Color darkSecondary = Color(0xFFC6CBD4);
  static const Color darkTertiary = Color(0xFF8B929E);
  static const Color darkQuaternary = Color(0xFF5C6470);
}

/// ── Backgrounds ────────────────────────────────────────────────────────────
/// 常量值 = 默认主题 Graphite；主题感知代码应使用 HermesPalette。
abstract final class HermesBackground {
  // Light（Graphite）
  static const Color lightPage = Color(0xFFF6F7F9); // --bg
  static const Color lightBackground = Color(0xFFF6F7F9); // --bg
  static const Color lightSecondary = Color(0xFFFFFFFF); // --surface
  static const Color lightElevated = Color(0xFFFFFFFF); // --elevated
  static const Color lightTertiary = Color(0xFFF0F1F4); // --code-bg
  static const Color lightBorder = Color(0xFFE2E5EA); // --border
  static const Color lightBorderStrong = Color(0xFFC9CED6); // --border-strong
  // Dark（Graphite）
  static const Color darkPage = Color(0xFF0E1013);
  static const Color darkBackground = Color(0xFF0E1013);
  static const Color darkSecondary = Color(0xFF16191E);
  static const Color darkElevated = Color(0xFF1D2127);
  static const Color darkTertiary = Color(0xFF0A0C0F);
  static const Color darkBorder = Color(0xFF292E36);
  static const Color darkBorderStrong = Color(0xFF3A414B);
}

/// ── 主题集合（design-system.md §3：4 套精选主题）───────────────────────────
/// 每套主题携带明/暗两套完整 [HermesPalette]；accent 四态即调色板内字段，
/// `light/dark/lightHover/darkHover` 保留以兼容旧调用点。
class HermesAccent {
  final String id;
  final String label;
  final HermesPalette lightPalette;
  final HermesPalette darkPalette;

  const HermesAccent({
    required this.id,
    required this.label,
    required this.lightPalette,
    required this.darkPalette,
  });

  Color get light => lightPalette.accent;
  Color get dark => darkPalette.accent;
  Color get lightHover => lightPalette.accentHover;
  Color get darkHover => darkPalette.accentHover;

  /// Base color for the current brightness.
  Color of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// Hover color for the current brightness.
  Color hoverOf(Brightness brightness) =>
      brightness == Brightness.dark ? darkHover : lightHover;

  HermesPalette paletteOf(Brightness brightness) =>
      brightness == Brightness.dark ? darkPalette : lightPalette;
}

abstract final class HermesAccents {
  /// 主题一：Graphite 石墨（默认）——中性灰 + 信号蓝（§3.2）。
  static const graphite = HermesAccent(
    id: 'graphite',
    label: 'Graphite',
    lightPalette: HermesPalette(
      bg: Color(0xFFF6F7F9),
      surface: Color(0xFFFFFFFF),
      elevated: Color(0xFFFFFFFF),
      border: Color(0xFFE2E5EA),
      borderStrong: Color(0xFFC9CED6),
      text: Color(0xFF16181D),
      text2: Color(0xFF3E4450),
      text3: Color(0xFF6B7280),
      text4: Color(0xFF9CA3AF),
      accent: Color(0xFF2F6BFF),
      accentHover: Color(0xFF2057DB),
      accentBg: Color(0xFFEBF0FF),
      accentStrong: Color(0xFFD6E1FF),
      codeBg: Color(0xFFF0F1F4),
      bubbleUser: Color(0xFF2F6BFF),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
    darkPalette: HermesPalette(
      bg: Color(0xFF0E1013),
      surface: Color(0xFF16191E),
      elevated: Color(0xFF1D2127),
      border: Color(0xFF292E36),
      borderStrong: Color(0xFF3A414B),
      text: Color(0xFFF2F4F8),
      text2: Color(0xFFC6CBD4),
      text3: Color(0xFF8B929E),
      text4: Color(0xFF5C6470),
      accent: Color(0xFF6E97FF),
      accentHover: Color(0xFF8AABFF),
      accentBg: Color(0xFF1B2A52),
      accentStrong: Color(0xFF24386B),
      codeBg: Color(0xFF0A0C0F),
      bubbleUser: Color(0xFF2F6BFF),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
  );

  /// 主题二：Indigo 靛蓝（§3.3）。
  static const indigo = HermesAccent(
    id: 'indigo',
    label: 'Indigo',
    lightPalette: HermesPalette(
      bg: Color(0xFFF5F5FA),
      surface: Color(0xFFFFFFFF),
      elevated: Color(0xFFFFFFFF),
      border: Color(0xFFE4E4EE),
      borderStrong: Color(0xFFCBCBDC),
      text: Color(0xFF17161F),
      text2: Color(0xFF413F52),
      text3: Color(0xFF6E6C84),
      text4: Color(0xFF9D9BAF),
      accent: Color(0xFF5B54E6),
      accentHover: Color(0xFF4841D1),
      accentBg: Color(0xFFEEEDFC),
      accentStrong: Color(0xFFDDDBFA),
      codeBg: Color(0xFFEFEFF6),
      bubbleUser: Color(0xFF5B54E6),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
    darkPalette: HermesPalette(
      bg: Color(0xFF0F0F16),
      surface: Color(0xFF17171F),
      elevated: Color(0xFF1E1E28),
      border: Color(0xFF2B2B38),
      borderStrong: Color(0xFF3D3D4E),
      text: Color(0xFFF3F2FA),
      text2: Color(0xFFC9C7D9),
      text3: Color(0xFF8E8CA3),
      text4: Color(0xFF5F5D72),
      accent: Color(0xFF9B94FF),
      accentHover: Color(0xFFB0A9FF),
      accentBg: Color(0xFF232046),
      accentStrong: Color(0xFF2E2A5C),
      codeBg: Color(0xFF0B0B11),
      bubbleUser: Color(0xFF5B54E6),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
  );

  /// 主题三：Moss 苔绿（§3.4）。
  static const moss = HermesAccent(
    id: 'moss',
    label: 'Moss',
    lightPalette: HermesPalette(
      bg: Color(0xFFF7F8F5),
      surface: Color(0xFFFFFFFF),
      elevated: Color(0xFFFFFFFF),
      border: Color(0xFFE3E6E0),
      borderStrong: Color(0xFFCBD1C7),
      text: Color(0xFF171B18),
      text2: Color(0xFF3F4741),
      text3: Color(0xFF69736C),
      text4: Color(0xFF98A09A),
      accent: Color(0xFF2E7D52),
      accentHover: Color(0xFF246442),
      accentBg: Color(0xFFE9F3ED),
      accentStrong: Color(0xFFD4E8DC),
      codeBg: Color(0xFFEFF1ED),
      bubbleUser: Color(0xFF2E7D52),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
    darkPalette: HermesPalette(
      bg: Color(0xFF101312),
      surface: Color(0xFF171B19),
      elevated: Color(0xFF1E2320),
      border: Color(0xFF2B312D),
      borderStrong: Color(0xFF3C443E),
      text: Color(0xFFF1F5F2),
      text2: Color(0xFFC4CCC6),
      text3: Color(0xFF88938B),
      text4: Color(0xFF5A635C),
      accent: Color(0xFF5FA87F),
      accentHover: Color(0xFF79BD94),
      accentBg: Color(0xFF1B2E24),
      accentStrong: Color(0xFF24402F),
      codeBg: Color(0xFF0B0E0C),
      bubbleUser: Color(0xFF2E7D52),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
  );

  /// 主题四：Dune 暖沙（§3.5，WebUI 奶油金皮肤的正式继任者）。
  static const dune = HermesAccent(
    id: 'dune',
    label: 'Dune',
    lightPalette: HermesPalette(
      bg: Color(0xFFFAF6EE),
      surface: Color(0xFFFFFDF8),
      elevated: Color(0xFFFFFDF8),
      border: Color(0xFFEAE1D0),
      borderStrong: Color(0xFFD8CBB4),
      text: Color(0xFF1E1A13),
      text2: Color(0xFF4A4336),
      text3: Color(0xFF776D5B),
      text4: Color(0xFFA39884),
      accent: Color(0xFFC05621),
      accentHover: Color(0xFF9C4419),
      accentBg: Color(0xFFF9EBE0),
      accentStrong: Color(0xFFF3D9C4),
      codeBg: Color(0xFFF3ECDD),
      bubbleUser: Color(0xFFC05621),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
    darkPalette: HermesPalette(
      bg: Color(0xFF14110C),
      surface: Color(0xFF1C1812),
      elevated: Color(0xFF241F17),
      border: Color(0xFF332C21),
      borderStrong: Color(0xFF463D2D),
      text: Color(0xFFF5F0E6),
      text2: Color(0xFFCFC6B4),
      text3: Color(0xFF968B76),
      text4: Color(0xFF615748),
      accent: Color(0xFFE8935A),
      accentHover: Color(0xFFF0A878),
      accentBg: Color(0xFF38220F),
      accentStrong: Color(0xFF4A2D16),
      codeBg: Color(0xFF0E0C08),
      bubbleUser: Color(0xFFC05621),
      bubbleUserText: Color(0xFFFFFFFF),
    ),
  );

  static const all = [graphite, indigo, moss, dune];

  /// 旧 8 accent id → 新 themeId 的一次性迁移映射（design-system.md §8.2）。
  static const _legacyIdMap = {
    'webui': 'dune',
    'ocean': 'graphite',
    'sky': 'graphite',
    'violet': 'indigo',
    'forest': 'moss',
    'sunset': 'dune',
    'cream': 'dune',
    'ink': 'graphite',
  };

  static HermesAccent byId(String? id) {
    final resolved = _legacyIdMap[id] ?? id;
    return all.firstWhere((a) => a.id == resolved, orElse: () => graphite);
  }
}

/// ── Spacing（design-system.md §5.1：8 基准栅格）────────────────────────────
abstract final class HermesSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double xxxxl = 48;
}

/// ── Radius（design-system.md §5.2）─────────────────────────────────────────
abstract final class HermesRadius {
  static const double smallCard = 6; // r-sm
  static const double card = 15; // Prototype mobile card/group radius.
  static const double largeCard = 15; // Standalone mobile surface radius.
  static const double sheet = 20; // r-sheet：底部弹层顶角
  static const double dialog = 16; // r-xl：Dialog
  static const double bubble = 14; // r-bubble：消息气泡（用户气泡右下 4px）
  static const double composerCard = 16; // r-xl：Composer 容器/大卡片
  static const double composer = 24; // 旧输入 pill，保留兼容
  static const double capsule = 999; // r-pill
}

/// ── Typography（design-system.md §4.2）────────────────────────────────────
/// 裸 TextStyle 只含字号/字重/行高——不含颜色。优先用
/// `Theme.of(context).textTheme.xxx`（主题已注入 onSurface 色）；直接用裸
/// token 必须 `.copyWith(color: ...)`。
abstract final class HermesType {
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
  );
  static const TextStyle largeTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );
  static const TextStyle title = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );
  static const TextStyle headline = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );
  static const TextStyle body = TextStyle(fontSize: 15, height: 1.6);
  static const TextStyle callout = TextStyle(fontSize: 14, height: 1.55);
  static const TextStyle subheadline = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.45,
  );
  static const TextStyle footnote = TextStyle(fontSize: 12, height: 1.4);
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
  );

  /// 消息正文：message-body 14px / 1.75，对话字体栈。
  static const TextStyle messageBody = TextStyle(
    fontSize: 14,
    height: 1.75,
    fontFamilyFallback: HermesFonts.conversation,
  );

  /// 统一等宽样式：code 13px / 1.6，--font-mono 栈。代码块/行内代码基于
  /// 此 `copyWith` 改字号，不要写 `'monospace'` 字面量。
  static const TextStyle code = TextStyle(
    fontSize: 13,
    height: 1.6,
    fontFamilyFallback: HermesFonts.mono,
  );

  /// Convenience: style with `ColorScheme.onSurface`.
  static TextStyle onSurface(TextStyle base, ThemeData theme) =>
      base.copyWith(color: theme.colorScheme.onSurface);

  /// Convenience: style with `ColorScheme.onSurfaceVariant`.
  static TextStyle onSurfaceVariant(TextStyle base, ThemeData theme) =>
      base.copyWith(color: theme.colorScheme.onSurfaceVariant);
}

/// ── Shadows（design-system.md §5.3）────────────────────────────────────────
/// 浅色主题用柔和扩散阴影；深色主题**不使用投影**（返回空列表），层级用
/// 1px 边框表达。
enum HermesShadowTier { sm, md, lg }

List<BoxShadow> hermesShadow(
  BuildContext context, [
  HermesShadowTier tier = HermesShadowTier.sm,
]) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) return const [];
  switch (tier) {
    case HermesShadowTier.sm:
      return const [
        BoxShadow(
          color: Color(0x0F10141A), // rgba(16,20,26,.06)
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
      ];
    case HermesShadowTier.md:
      return const [
        BoxShadow(
          color: Color(0x1410141A), // rgba(16,20,26,.08)
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
    case HermesShadowTier.lg:
      return const [
        BoxShadow(
          color: Color(0x1F10141A), // rgba(16,20,26,.12)
          blurRadius: 32,
          offset: Offset(0, 12),
        ),
      ];
  }
}

/// ── Card decoration（design-system.md §6.3）────────────────────────────────
/// surface 底 + 1px border + shadow-sm（dark 仅 border）。`tint` 覆盖底色；
/// `strong` 使用 --border-strong。全部颜色读当前主题调色板，随主题切换。
BoxDecoration hermesCardDecoration(
  BuildContext context, {
  double radius = HermesRadius.card,
  Color? tint,
  HermesShadowTier shadow = HermesShadowTier.sm,
  bool strong = false,
}) {
  final palette = HermesPalette.of(context);
  return BoxDecoration(
    color: tint ?? palette.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: strong ? palette.borderStrong : palette.border,
      width: 1,
    ),
    boxShadow: hermesShadow(context, shadow),
  );
}

// Backwards-compatible alias used by older call sites (same solid style).
BoxDecoration hermesGlassDecoration(
  BuildContext context, {
  double radius = HermesRadius.card,
  Color? tint,
}) => hermesCardDecoration(context, radius: radius, tint: tint);

/// ── Agent status（状态语义色：等待审批并入 --warning）───────────────────────
enum HermesAgentStatus {
  idle,
  thinking,
  planning,
  running,
  waiting,
  approval,
  paused,
  completed,
  failed,
  stopped;

  Color color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case idle:
      case stopped:
        return isDark ? HermesSemanticDark.gray : HermesSemantic.gray;
      case thinking:
      case planning:
      case running:
      case completed:
        return isDark ? HermesSemanticDark.green : HermesSemantic.green;
      case waiting:
      case paused:
      case approval:
        return isDark ? HermesSemanticDark.orange : HermesSemantic.orange;
      case failed:
        return isDark ? HermesSemanticDark.red : HermesSemantic.red;
    }
  }

  IconData get icon {
    switch (this) {
      case idle:
        return Icons.circle_outlined;
      case thinking:
      case planning:
        return Icons.psychology_outlined;
      case running:
        return Icons.bolt;
      case waiting:
        return Icons.hourglass_bottom;
      case approval:
        return Icons.rule;
      case paused:
        return Icons.pause_circle_outline;
      case completed:
        return Icons.check_circle_outline;
      case failed:
        return Icons.error_outline;
      case stopped:
        return Icons.stop_circle_outlined;
    }
  }
}

/// ── Tool status ─────────────────────────────────────────────────────────────
enum HermesToolStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
  approval;

  Color color(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case pending:
      case cancelled:
        return isDark ? HermesSemanticDark.gray : HermesSemantic.gray;
      case running:
      case completed:
        return isDark ? HermesSemanticDark.green : HermesSemantic.green;
      case failed:
        return isDark ? HermesSemanticDark.red : HermesSemantic.red;
      case approval:
        return isDark ? HermesSemanticDark.orange : HermesSemantic.orange;
    }
  }
}

/// ── Global page states (spec §8, §205) ───────────────────────────────────
enum HermesUiState {
  initial,
  loading,
  loaded,
  empty,
  processing,
  success,
  error,
  offline,
  disabled,
}
