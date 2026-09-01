library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clipboard.dart';
import '../core/external_links.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import 'plugin_contribution_views.dart';

Color? pluginToneColor(String? name) => switch (name) {
  'green' => HermesSemantic.green,
  'orange' => HermesSemantic.orange,
  'red' => HermesSemantic.red,
  'blue' => HermesSemantic.blue,
  'purple' => HermesSemantic.purple,
  'gray' => HermesSemantic.gray,
  _ => null,
};

class PluginContributionSurface extends StatelessWidget {
  final MobileContributionArea area;
  final Axis direction;
  const PluginContributionSurface({
    super.key,
    required this.area,
    this.direction = Axis.horizontal,
  });

  @override
  Widget build(BuildContext context) {
    PluginContributionStore store;
    try {
      store = context.watch<PluginContributionStore>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final items = store.forArea(area);
    if (items.isEmpty) return const SizedBox.shrink();
    final children = [
      for (final item in items)
        Builder(
          builder: (context) {
            final locale = Localizations.localeOf(context);
            final title = item.localizedTitle(locale);
            return ActionChip(
              avatar: Icon(
                Icons.extension_outlined,
                size: 16,
                color: pluginToneColor(item.color),
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title),
                  if (store.badges[item.namespacedId] != null) ...[
                    const SizedBox(width: 4),
                    _Badge(text: store.badges[item.namespacedId]!),
                  ],
                ],
              ),
              tooltip: item.localizedDescription(locale),
              onPressed: () async {
                try {
                  await showPluginContributionView(context, store, item);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.pluginActionFailed(title, '$e'),
                        ),
                      ),
                    );
                  }
                }
              },
            );
          },
        ),
    ];
    return direction == Axis.horizontal
        ? Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(spacing: 8, runSpacing: 6, children: children),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
  }
}

Future<void> showPluginActionResult(
  BuildContext context,
  MobilePluginContribution contribution,
  Map<String, dynamic> raw,
) async {
  final result = PluginActionResult.fromJson(raw);
  if (!result.shouldPresent) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) => _PluginResultSheet(
        contribution: contribution,
        result: result,
        scrollController: scrollController,
      ),
    ),
  );
}

class _PluginResultSheet extends StatelessWidget {
  final MobilePluginContribution contribution;
  final PluginActionResult result;
  final ScrollController scrollController;

  const _PluginResultSheet({
    required this.contribution,
    required this.result,
    required this.scrollController,
  });

  String _pretty(Object? value) {
    try {
      final text = const JsonEncoder.withIndent('  ').convert(value);
      return text.length <= 100000 ? text : '${text.substring(0, 100000)}\n...';
    } catch (_) {
      return value.toString();
    }
  }

  String _copyText() {
    if (result.usesRawFallback) return _pretty(result.raw);
    final buffer = StringBuffer();
    if (result.title case final title?) buffer.writeln(title);
    if (result.message case final message?) buffer.writeln(message);
    for (final field in result.fields) {
      buffer.writeln('${field.label}: ${field.value}');
    }
    for (final item in result.items) {
      buffer.writeln(_pretty(item));
    }
    if (result.url case final url?) buffer.writeln(url);
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Icon(
                  Icons.extension_outlined,
                  color: pluginToneColor(contribution.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    result.title ?? contribution.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.pluginResultCopy,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () => copyTextOrNotify(
                    context,
                    _copyText(),
                    successMessage: context.l10n.pluginResultCopied,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.commonClose,
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
        if (result.message case final message?)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(child: SelectableText(message)),
          ),
        if (result.fields.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: result.fields.length,
              separatorBuilder: (_, _) => Divider(color: palette.border),
              itemBuilder: (context, index) {
                final field = result.fields[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          field.label,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: SelectableText(field.value)),
                    ],
                  ),
                );
              },
            ),
          ),
        if (result.items.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList.separated(
              itemCount: result.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) => _PluginResultItem(
                value: result.items[index],
                pretty: _pretty,
              ),
            ),
          ),
        if (result.url case final url?)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.l10n.pluginResultOpenLink),
                  onPressed: () => launchExternalOrNotify(context, url),
                ),
              ),
            ),
          ),
        if (result.usesRawFallback)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.codeBg,
                  border: Border.all(color: palette.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SelectableText(
                  _pretty(result.raw),
                  style: HermesType.code.copyWith(color: palette.text2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PluginResultItem extends StatelessWidget {
  final Object? value;
  final String Function(Object?) pretty;

  const _PluginResultItem({required this.value, required this.pretty});

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final map = value is Map ? (value as Map).cast<Object?, Object?>() : null;
    final title = map == null
        ? null
        : (map['title'] ?? map['name'] ?? map['label'] ?? map['id'])
              ?.toString();
    final subtitle = map == null
        ? null
        : (map['message'] ??
                  map['description'] ??
                  map['subtitle'] ??
                  map['status'])
              ?.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: title == null && subtitle == null
          ? SelectableText(map == null ? value.toString() : pretty(map))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (subtitle != null) ...[
                  if (title != null) const SizedBox(height: 4),
                  SelectableText(subtitle),
                ],
              ],
            ),
    );
  }
}

/// Small live count/status pill — mirrors desktop's status-bar badges (e.g.
/// kanban's open-task count) for a contribution's `badgeAction` result.
class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
