import 'package:flutter/material.dart';

import '../../core/tool_card_models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_tool.dart';
import 'tool_payload.dart';

/// Rich card listing the files touched by `changed_files` / `git_diff` /
/// `apply_patch` tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_ChangedFilesToolCard`); behavior unchanged.
class ChangedFilesToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const ChangedFilesToolCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final files = parseChangedFiles(data);
    final palette = HermesPalette.of(context);
    final good = hermesSemantic(
      context,
      HermesSemantic.green,
      HermesSemanticDark.green,
    );
    final bad = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    return ToolCardShell(
      icon: Icons.difference_outlined,
      title: context.l10n.toolChangedFiles(files.length),
      children: files.isEmpty
          ? [SelectableText(toolResultText(data))]
          : [
              for (final file in files)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 15,
                        color: palette.text3,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: HermesType.code.copyWith(
                            color: palette.text,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '+${file.additions}',
                        style: TextStyle(
                          color: good,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '−${file.deletions}',
                        style: TextStyle(
                          color: bad,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
    );
  }
}
