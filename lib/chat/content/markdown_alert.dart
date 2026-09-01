import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_markdown.dart';
import 'zoomable_markdown_image.dart';

/// GitHub-flavored alert block (`> [!NOTE]` …). Desktop parity:
/// `apps/desktop/src/components/assistant-ui/embeds/alert.tsx`.
class MarkdownAlertBox extends StatelessWidget {
  final String type; // note | tip | important | warning | caution
  final String body; // markdown source, quote markers already stripped
  final bool selectable;

  const MarkdownAlertBox({
    super.key,
    required this.type,
    required this.body,
    this.selectable = true,
  });

  static ({String label, IconData icon, Color Function(bool dark) color})
  _style(BuildContext context, String type) {
    switch (type) {
      case 'tip':
        return (
          label: context.l10n.markdownAlertTip,
          icon: Icons.bolt_outlined,
          color: (dark) =>
              dark ? const Color(0xFF34D399) : const Color(0xFF059669),
        );
      case 'important':
        return (
          label: context.l10n.markdownAlertImportant,
          icon: Icons.error_outline,
          color: (dark) =>
              dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
        );
      case 'warning':
        return (
          label: context.l10n.markdownAlertWarning,
          icon: Icons.warning_amber_outlined,
          color: (dark) =>
              dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
        );
      case 'caution':
        return (
          label: context.l10n.markdownAlertCaution,
          icon: Icons.report_gmailerrorred_outlined,
          color: (dark) =>
              dark ? const Color(0xFFFB7185) : const Color(0xFFE11D48),
        );
      case 'note':
      default:
        return (
          label: context.l10n.markdownAlertNote,
          icon: Icons.info_outline,
          color: (dark) =>
              dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final style = _style(context, type);
    final accent = style.color(isDark);
    return Container(
      key: ValueKey('markdown-alert-$type'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.10 : 0.06),
        border: Border(left: BorderSide(color: accent, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(style.icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                style.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            MarkdownBody(
              data: body,
              selectable: selectable,
              extensionSet: md.ExtensionSet.gitHubFlavored,
              sizedImageBuilder: hermesMarkdownImageBuilder,
              styleSheet: hermesMarkdownStyle(context, compact: true).copyWith(
                p: hermesMarkdownStyle(
                  context,
                  compact: true,
                ).p?.copyWith(color: palette.text2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
