import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

import '../../widgets/h/hermes_markdown.dart';
import '../../widgets/web_preview.dart' show openChatLink;
import 'ansi_text.dart';

/// Compact markdown for tool-detail / result bodies: clickable links, inline
/// code, emphasis — but no headings blow-up, and ANSI-coloured output is
/// routed through [AnsiText] instead. Desktop parity: `chat/compact-markdown`.
class CompactMarkdown extends StatelessWidget {
  final String text;
  final bool selectable;

  const CompactMarkdown({
    super.key,
    required this.text,
    this.selectable = true,
  });

  @override
  Widget build(BuildContext context) {
    if (AnsiText.contains(text)) {
      return AnsiText(
        text: text,
        selectable: selectable,
        style: const TextStyle(fontSize: 12),
      );
    }
    return MarkdownBody(
      data: text,
      selectable: selectable,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      onTapLink: (_, href, _) {
        if (href != null && href.isNotEmpty) openChatLink(context, href);
      },
      styleSheet: hermesMarkdownStyle(context, compact: true).copyWith(
        p: hermesMarkdownStyle(
          context,
          compact: true,
        ).p?.copyWith(fontSize: 12, height: 1.5),
        blockSpacing: 6,
      ),
    );
  }
}
