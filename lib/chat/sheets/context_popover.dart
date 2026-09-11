/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../widgets/glass/glass_menu_entry.dart';

Future<void> showChatContextPopover(
  BuildContext context,
  BuildContext anchorContext, {
  required void Function(double?) onUsage,
}) async {
  final session = context.read<SessionStore>();
  final usage = await loadContextUsage(session);
  if (!context.mounted) return;
  if (!anchorContext.mounted) return;
  if (usage != null) {
    onUsage(usage.percent);
  }

  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final overlayState = Overlay.of(anchorContext);
  if (!overlayState.mounted) return;
  final overlay = overlayState.context.findRenderObject()! as RenderBox;
  final anchorRect = Rect.fromPoints(
    anchor.localToGlobal(Offset.zero, ancestor: overlay),
    anchor.localToGlobal(
      anchor.size.bottomRight(Offset.zero),
      ancestor: overlay,
    ),
  );
  final entries = <PopupMenuEntry<String>>[
    PopupMenuItem<String>(
      enabled: false,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: 280,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.chatContextUsage,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Text(
                usage == null
                    ? context.l10n.chatNoContextData
                    : '${usage.percent.round()}% of ${formatContextLimit(usage.max)}',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (usage != null && usage.categories.isEmpty) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: (usage.percent / 100).clamp(0, 1),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
              if (usage != null && usage.categories.isNotEmpty) ...[
                const SizedBox(height: 10),
                ContextUsageBreakdown(categories: usage.categories),
              ],
            ],
          ),
        ),
      ),
    ),
    PopupMenuItem<String>(
      value: 'compress',
      enabled: !session.readOnly,
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Row(
          children: [
            const Icon(Icons.compress, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.chatCompressContext,
                style: TextStyle(
                  color: session.readOnly
                      ? Theme.of(context).disabledColor
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ];
  final liquid = HermesGlassTheme.of(context).enabled;
  final selected = await showMenu<String>(
    context: anchorContext,
    position: RelativeRect.fromRect(anchorRect, Offset.zero & overlay.size),
    color: liquid ? Colors.transparent : null,
    elevation: liquid ? 0 : null,
    surfaceTintColor: liquid ? Colors.transparent : null,
    shape: liquid ? const RoundedRectangleBorder() : null,
    menuPadding: liquid ? EdgeInsets.zero : null,
    items: liquid
        ? [
            GlassMenuEntry<String>(
              entries: entries,
              maxHeight: GlassMenuEntry.availableHeight(anchorContext),
            ),
          ]
        : entries,
  );
  if (selected != 'compress' || !context.mounted) return;

  try {
    await session.compress();
    await session.refreshTranscript();
    final refreshed = await loadContextUsage(session);
    if (!context.mounted) return;
    onUsage(refreshed?.percent);
    showHermesToast(
      context,
      message: context.l10n.chatCompressionRequested,
      kind: HermesToastKind.success,
    );
  } catch (error) {
    if (!context.mounted) return;
    showHermesErrorSnackBar(
      context,
      error,
      fallback: context.l10n.chatCompressionFailed('$error'),
    );
  }
}

Future<ContextUsageSnapshot?> loadContextUsage(SessionStore session) async {
  final breakdown = _contextUsageValues(await session.contextBreakdown());
  if (breakdown != null) return breakdown;
  return _contextUsageValues(await session.usage());
}

ContextUsageSnapshot? _contextUsageValues(Map<String, dynamic> payload) {
  Map<String, dynamic> values = payload;
  for (final key in const ['usage', 'context', 'data', 'result']) {
    final nested = values[key];
    if (nested is Map) values = nested.cast<String, dynamic>();
    if (values.containsKey('context_max')) break;
  }
  double? number(String key) {
    final value = values[key];
    return value is num ? value.toDouble() : double.tryParse('$value');
  }

  final used = number('context_used');
  final max = number('context_max');
  var percent = number('context_percent');
  if (used == null || max == null || max <= 0) return null;
  percent ??= used / max * 100;
  final rawCategories = values['categories'];
  final categories = rawCategories is List
      ? rawCategories
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .where((e) => ((e['tokens'] as num?) ?? 0) > 0)
            .toList(growable: false)
      : const <Map<String, dynamic>>[];
  return ContextUsageSnapshot(
    used: used,
    max: max,
    percent: percent,
    categories: categories,
  );
}

String formatContextLimit(double tokens) {
  if (tokens >= 1000000) return '${tokens / 1000000}M';
  if (tokens >= 1000) {
    final value = tokens / 1000;
    return '${value == value.roundToDouble() ? value.round() : value.toStringAsFixed(1)}K';
  }
  return tokens.round().toString();
}

/// Parsed `session.context_breakdown` result: total usage plus the optional
/// per-source token categories (system prompt / tools / history / files —
/// desktop parity), used by the context-usage popover.
class ContextUsageSnapshot {
  final double used;
  final double max;
  final double percent;
  final List<Map<String, dynamic>> categories;

  const ContextUsageSnapshot({
    required this.used,
    required this.max,
    required this.percent,
    required this.categories,
  });
}

Color? _parseHexColor(dynamic value) {
  final hex = value?.toString().trim();
  if (hex == null || hex.isEmpty) return null;
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// A slim colored segment bar plus a scrollable legend list — the mobile
/// take on desktop's `ContextUsagePanel`, which shows the same categories as
/// hover-labeled bar segments; here they're tappable-height rows instead.
class ContextUsageBreakdown extends StatelessWidget {
  final List<Map<String, dynamic>> categories;

  const ContextUsageBreakdown({super.key, required this.categories});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
      theme.colorScheme.outline,
    ];
    final total = categories.fold<double>(
      0,
      (sum, c) => sum + (((c['tokens'] as num?) ?? 0).toDouble()),
    );
    Color colorFor(int index, Map<String, dynamic> category) =>
        _parseHexColor(category['color']) ??
        fallbackColors[index % fallbackColors.length];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 5,
            child: Row(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Expanded(
                    flex: (((categories[i]['tokens'] as num?) ?? 0) * 1000)
                        .round()
                        .clamp(1, 1 << 30),
                    child: Container(color: colorFor(i, categories[i])),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 180),
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var i = 0; i < categories.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorFor(i, categories[i]),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            categories[i]['label']?.toString() ??
                                categories[i]['id']?.toString() ??
                                '',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatContextLimit(
                            (((categories[i]['tokens'] as num?) ?? 0))
                                .toDouble(),
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (total <= 0) const SizedBox.shrink(),
      ],
    );
  }
}
