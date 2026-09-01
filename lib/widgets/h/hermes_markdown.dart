/// Hermes Markdown stylesheet — matches the design system's Markdown spec:
/// blockquote = accent left bar, inline code = accent text on code bg,
/// pre = code bg + border, tables = bordered with uppercase headers.
library;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../theme/hermes_tokens.dart';

MarkdownStyleSheet hermesMarkdownStyle(
  BuildContext context, {
  bool compact = false,
}) {
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
      fontSize: compact ? 14 : 15,
      height: 1.65,
      color: compact ? primaryText : secondaryText,
    ),
    h1: TextStyle(
      fontSize: compact ? 17 : 22,
      fontWeight: FontWeight.w700,
      height: 1.3,
      color: primaryText,
    ),
    h2: TextStyle(
      fontSize: compact ? 15 : 18,
      fontWeight: FontWeight.w700,
      height: 1.35,
      color: primaryText,
    ),
    h3: TextStyle(
      fontSize: compact ? 14 : 15,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: primaryText,
    ),
    h4: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.4,
      color: primaryText,
    ),
    listBullet: TextStyle(fontSize: 14, color: tertiaryText),
    strong: TextStyle(
      fontSize: compact ? 14 : 15,
      fontWeight: FontWeight.w700,
      color: primaryText,
    ),
    em: TextStyle(
      fontSize: compact ? 14 : 15,
      fontStyle: FontStyle.italic,
      color: secondaryText,
    ),
    blockquote: TextStyle(
      fontSize: compact ? 13 : 14,
      fontStyle: FontStyle.italic,
      height: 1.6,
      color: secondaryText,
    ),
    blockquoteDecoration: BoxDecoration(
      border: Border(left: BorderSide(color: accent, width: 3)),
      color: accent.withValues(alpha: 0.04),
      borderRadius: const BorderRadius.only(
        topRight: Radius.circular(10),
        bottomRight: Radius.circular(10),
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
