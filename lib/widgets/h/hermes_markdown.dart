/// Hermes Markdown stylesheet — matches the design system's Markdown spec:
/// blockquote = accent left bar, inline code = accent text on code bg,
/// pre = code bg + border, tables = bordered with uppercase headers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';

/// User messages retain bubble contrast while sharing phone reading hierarchy.
MarkdownStyleSheet hermesUserMarkdownStyle(BuildContext context) {
  final color = HermesPalette.of(context).bubbleUserText;
  final phone = HermesLiquidTypography.usesPhoneRows(context);
  final liquid = HermesGlassTheme.of(context).enabled;
  final base = MarkdownStyleSheet.fromTheme(Theme.of(context));
  final reading = hermesMarkdownStyle(
    context,
    compact: true,
    conversation: true,
  );
  TextStyle? foreground(TextStyle? style) => style?.copyWith(color: color);
  return base.copyWith(
    p: HermesLiquidTypography.messageBody(context).copyWith(color: color),
    h1: liquid ? foreground(phone ? reading.h1 : base.h1) : null,
    h2: liquid ? foreground(phone ? reading.h2 : base.h2) : null,
    h3: liquid ? foreground(phone ? reading.h3 : base.h3) : null,
    h4: liquid ? foreground(phone ? reading.h4 : base.h4) : null,
    h5: liquid ? foreground(phone ? reading.h4 : base.h5) : null,
    h6: liquid ? foreground(phone ? reading.h4 : base.h6) : null,
    strong: TextStyle(color: color, fontWeight: FontWeight.w700),
    em: liquid ? foreground(phone ? reading.em : base.em) : null,
    blockquote: liquid
        ? foreground(phone ? reading.blockquote : base.blockquote)
        : null,
    // The package default is pale blue, which cannot carry bubble-white text.
    // Keep the quote on its bubble reading plane and distinguish it by a rule.
    blockquoteDecoration: liquid
        ? BoxDecoration(
            border: BorderDirectional(
              start: BorderSide(color: color, width: 3),
            ),
          )
        : null,
    a: liquid
        ? TextStyle(color: color, decoration: TextDecoration.underline)
        : null,
    code: HermesType.code.copyWith(color: color),
    listBullet: TextStyle(
      fontSize: phone ? HermesLiquidTypography.messageSize : null,
      color: color.withValues(alpha: liquid ? 1 : .7),
    ),
  );
}

MarkdownStyleSheet hermesMarkdownStyle(
  BuildContext context, {
  bool compact = false,
  bool conversation = false,
}) {
  final phoneConversation =
      conversation && HermesLiquidTypography.usesPhoneRows(context);
  final bodySize = phoneConversation
      ? HermesLiquidTypography.messageSize
      : compact
      ? 14.0
      : 15.0;
  final theme = Theme.of(context);
  final palette = HermesPalette.of(context);
  final accent = palette.accent;
  final primaryText = palette.text;
  final secondaryText = palette.text2;
  final tertiaryText = palette.text3;
  final codeBg = palette.codeBg;
  final border = palette.border;

  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: TextStyle(
      fontSize: bodySize,
      height: phoneConversation ? HermesLiquidTypography.messageHeight : 1.65,
      color: compact ? primaryText : secondaryText,
    ),
    h1: TextStyle(
      fontSize: phoneConversation
          ? 22
          : compact
          ? 17
          : 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: primaryText,
    ),
    h2: TextStyle(
      fontSize: phoneConversation
          ? 20
          : compact
          ? 15
          : 18,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: primaryText,
    ),
    h3: TextStyle(
      fontSize: phoneConversation
          ? 18
          : compact
          ? 14
          : 15,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: primaryText,
    ),
    h4: TextStyle(
      fontSize: phoneConversation ? 17 : 14,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: primaryText,
    ),
    listBullet: TextStyle(
      fontSize: phoneConversation ? bodySize : 14,
      color: tertiaryText,
    ),
    strong: TextStyle(
      fontSize: phoneConversation ? null : bodySize,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
    em: TextStyle(
      fontSize: phoneConversation ? null : bodySize,
      fontStyle: FontStyle.italic,
      color: secondaryText,
    ),
    blockquote: TextStyle(
      fontSize: phoneConversation
          ? 16
          : compact
          ? 13
          : 14,
      fontStyle: FontStyle.italic,
      height: 1.6,
      color: secondaryText,
    ),
    blockquoteDecoration: BoxDecoration(
      border: BorderDirectional(start: BorderSide(color: accent, width: 3)),
      // 高对比：4% accent 底近乎不可见，提升至 ~7%。
      color: accent.withValues(alpha: hermesTintAlpha(context, 0.04)),
      borderRadius: const BorderRadiusDirectional.only(
        topEnd: Radius.circular(10),
        bottomEnd: Radius.circular(10),
      ),
    ),
    code: HermesType.code.copyWith(
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w600,
      color: accent,
      backgroundColor: codeBg,
    ),
    // §6.5：消息内代码块 code-bg + r-sm + mono 13px。
    codeblockDecoration: BoxDecoration(
      color: codeBg,
      borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      border: Border.all(color: border),
    ),
    codeblockPadding: const EdgeInsets.all(14),
    tableHead: TextStyle(
      fontSize: 10,
      letterSpacing: 0.03,
      fontWeight: FontWeight.w600,
      color: tertiaryText,
    ),
    tableBody: TextStyle(fontSize: 13, color: secondaryText),
    tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    tableCellsDecoration: BoxDecoration(color: palette.surface),
    tableBorder: TableBorder.all(color: border),
    horizontalRuleDecoration: BoxDecoration(
      border: Border(top: BorderSide(color: border)),
    ),
    a: TextStyle(
      color: accent,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.none,
    ),
  );
}
