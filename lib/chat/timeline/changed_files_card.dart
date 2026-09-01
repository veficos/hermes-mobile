import 'package:flutter/material.dart';

import '../../core/tool_card_models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_tool.dart';

/// "本回合文件变更" summary — prototype parity with `toolCard()`'s own
/// changed-files card (scenarioA): the same [ToolCardShell] chrome and
/// per-file +/− row treatment as every other tool card, instead of a bare
/// default Material `Card`/`ExpansionTile`.
class ChangedFilesCard extends StatelessWidget {
  final List<ChangedFileModel> files;
  const ChangedFilesCard({super.key, required this.files});

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    final additions = files.fold<int>(0, (sum, file) => sum + file.additions);
    final deletions = files.fold<int>(0, (sum, file) => sum + file.deletions);
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
      key: const ValueKey('timeline-changed-files-card'),
      icon: Icons.difference_outlined,
      title: context.l10n.toolChangedFiles(files.length),
      subtitle: Text(
        '+$additions −$deletions',
        style: TextStyle(fontSize: 10.5, color: palette.text3),
      ),
      children: [
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
                if (file.additions != 0 || file.deletions != 0) ...[
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
              ],
            ),
          ),
      ],
    );
  }
}
