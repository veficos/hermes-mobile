import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../h/hermes_progress.dart';
import 'mobile_page_scaffold.dart';

/// Canonical building blocks for Hermes' phone-first interface.  These
/// widgets deliberately contain layout and interaction policy so feature
/// screens do not each invent a slightly different card, row or picker.
class HermesSection extends StatelessWidget {
  const HermesSection({
    super.key,
    required this.title,
    required this.child,
    this.description,
    this.trailing,
    this.padding = const EdgeInsets.only(top: HermesSpacing.lg),
  });

  final String title;
  final String? description;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: palette.text2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (description?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: palette.text3),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class HermesGroupedList extends StatelessWidget {
  const HermesGroupedList({
    super.key,
    required this.children,
    this.margin = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(HermesRadius.card),
        border: Border.all(
          color: HermesA11y.highContrastOf(context)
              ? palette.borderStrong
              : palette.border,
          width: HermesA11y.highContrastOf(context) ? 1.5 : 1,
        ),
        boxShadow: hermesShadow(context),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 58,
                color: palette.border.withValues(alpha: .82),
              ),
          ],
        ],
      ),
    );
  }
}

class HermesListRow extends StatelessWidget {
  const HermesListRow({
    super.key,
    required this.title,
    this.icon,
    this.leading,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.titleTrailing,
    this.tone,
    this.onTap,
    this.onLongPress,
    this.destructive = false,
    this.showDisclosure = true,
  });

  final String title;
  final IconData? icon;
  final Widget? leading;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final Widget? titleTrailing;
  final Color? tone;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool destructive;
  final bool showDisclosure;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final foreground = destructive
        ? Theme.of(context).colorScheme.error
        : palette.text;
    final resolvedTone =
        tone ??
        (destructive ? Theme.of(context).colorScheme.error : palette.accent);
    final leadingWidget =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: resolvedTone.withValues(
                    alpha: hermesTintAlpha(context, .12),
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: resolvedTone),
              ));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 54),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 12, 10),
            child: Row(
              children: [
                if (leadingWidget != null) ...[
                  leadingWidget,
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: foreground,
                                    height: 1.25,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 6),
                            titleTrailing!,
                          ],
                        ],
                      ),
                      if (subtitleWidget != null ||
                          subtitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        subtitleWidget ??
                            Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: palette.text3, height: 1.3),
                            ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (trailing != null)
                  trailing!
                else if (onTap != null && showDisclosure)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: palette.text4,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HermesSummaryCard extends StatelessWidget {
  const HermesSummaryCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.tone,
    this.onTap,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final Widget? trailing;
  final Color? tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final resolvedTone = tone ?? palette.accent;
    final content = Padding(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: resolvedTone.withValues(
                      alpha: hermesTintAlpha(context, .12),
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: resolvedTone, size: 19),
                ),
                const SizedBox(width: 11),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: HermesSpacing.sm),
          child,
        ],
      ),
    );
    return Container(
      decoration: hermesCardDecoration(context, radius: HermesRadius.largeCard),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap, child: content),
            ),
    );
  }
}

class HermesFilterBar extends StatelessWidget {
  const HermesFilterBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.filters = const [],
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                ),
        ),
      ),
      if (filters.isNotEmpty) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: filters),
        ),
      ],
    ],
  );
}

class HermesAction<T> {
  const HermesAction({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
    this.destructive = false,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final IconData icon;
  final bool destructive;
  final bool enabled;
}

Future<T?> showHermesActionSheet<T>(
  BuildContext context, {
  required List<HermesAction<T>> actions,
  String? title,
  String? message,
}) => showMobileSheet<T>(
  context,
  (sheetContext) =>
      _HermesActionSheet<T>(actions: actions, title: title, message: message),
  avoidViewInsets: false,
  backgroundColor: Colors.transparent,
);

class _HermesActionSheet<T> extends StatelessWidget {
  const _HermesActionSheet({
    required this.actions,
    required this.title,
    required this.message,
  });

  final List<HermesAction<T>> actions;
  final String? title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title?.isNotEmpty == true || message?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
              child: Column(
                children: [
                  if (title?.isNotEmpty == true)
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  if (message?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.text3),
                    ),
                  ],
                ],
              ),
            ),
          HermesGroupedList(
            children: [
              for (final action in actions)
                HermesListRow(
                  icon: action.icon,
                  title: action.label,
                  subtitle: action.description,
                  destructive: action.destructive,
                  showDisclosure: false,
                  onTap: action.enabled
                      ? () => Navigator.of(context).pop(action.value)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class HermesPickerOption<T> {
  const HermesPickerOption({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final bool enabled;
}

Future<T?> showHermesPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<HermesPickerOption<T>> options,
  T? selected,
  String? searchHint,
}) => showMobileSheet<T>(
  context,
  (sheetContext) => _HermesPickerSheet<T>(
    title: title,
    options: options,
    selected: selected,
    searchHint: searchHint,
  ),
  avoidViewInsets: true,
);

class _HermesPickerSheet<T> extends StatefulWidget {
  const _HermesPickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.searchHint,
  });

  final String title;
  final List<HermesPickerOption<T>> options;
  final T? selected;
  final String? searchHint;

  @override
  State<_HermesPickerSheet<T>> createState() => _HermesPickerSheetState<T>();
}

class _HermesPickerSheetState<T> extends State<_HermesPickerSheet<T>> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final query = _query.trim().toLowerCase();
    final visible = widget.options
        .where(
          (option) =>
              query.isEmpty ||
              option.label.toLowerCase().contains(query) ||
              (option.description?.toLowerCase().contains(query) ?? false),
        )
        .toList(growable: false);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            if (widget.options.length > 8) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.searchHint ?? widget.title,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Flexible(
              child: SingleChildScrollView(
                child: HermesGroupedList(
                  children: [
                    for (final option in visible)
                      HermesListRow(
                        icon: option.icon,
                        title: option.label,
                        subtitle: option.description,
                        showDisclosure: false,
                        onTap: option.enabled
                            ? () => Navigator.of(context).pop(option.value)
                            : null,
                        trailing: option.value == widget.selected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: palette.accent,
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum HermesActivityState { processing, waiting, success, failed }

class HermesActivityItem {
  const HermesActivityItem({
    required this.label,
    required this.state,
    this.detail,
    this.progress,
  });

  final String label;
  final String? detail;
  final HermesActivityState state;
  final double? progress;
}

class HermesActivityPill extends StatelessWidget {
  const HermesActivityPill({
    super.key,
    required this.label,
    required this.state,
    this.progress,
    this.onTap,
  });

  final String label;
  final HermesActivityState state;
  final double? progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      HermesActivityState.processing => hermesSemantic(
        context,
        HermesSemantic.blue,
        HermesSemanticDark.blue,
      ),
      HermesActivityState.waiting => hermesSemantic(
        context,
        HermesSemantic.orange,
        HermesSemanticDark.orange,
      ),
      HermesActivityState.success => hermesSemantic(
        context,
        HermesSemantic.green,
        HermesSemanticDark.green,
      ),
      HermesActivityState.failed => Theme.of(context).colorScheme.error,
    };
    final icon = switch (state) {
      HermesActivityState.processing => Icons.sync_rounded,
      HermesActivityState.waiting => Icons.schedule_rounded,
      HermesActivityState.success => Icons.check_circle_rounded,
      HermesActivityState.failed => Icons.error_rounded,
    };
    return Material(
      color: color.withValues(alpha: hermesTintAlpha(context, .10)),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: .28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (progress != null) ...[
                const SizedBox(width: 9),
                SizedBox(width: 42, child: HermesProgressBar(value: progress!)),
              ],
              if (onTap != null) ...[
                const SizedBox(width: 3),
                Icon(Icons.expand_more_rounded, size: 17, color: color),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-page editor shell for settings that are too complex for a dialog.
/// Saving is deliberately represented as an async operation so the primary
/// action cannot be double-submitted.
class HermesFormPage extends StatefulWidget {
  const HermesFormPage({
    super.key,
    required this.title,
    required this.child,
    required this.saveLabel,
    required this.onSave,
    this.subtitle,
    this.canSave = true,
    this.dirty = false,
    this.discardMessage,
    this.discardLabel,
    this.maxContentWidth = HermesLayout.contentNarrow,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final String saveLabel;
  final Future<bool> Function() onSave;
  final bool canSave;
  final bool dirty;
  final String? discardMessage;
  final String? discardLabel;
  final double maxContentWidth;

  @override
  State<HermesFormPage> createState() => _HermesFormPageState();
}

class _HermesFormPageState extends State<HermesFormPage> {
  bool _saving = false;

  Future<bool> _confirmDiscard() async {
    if (!widget.dirty || _saving) return true;
    final discard = await showHermesActionSheet<bool>(
      context,
      title: widget.title,
      message: widget.discardMessage,
      actions: [
        HermesAction(
          value: true,
          label:
              widget.discardLabel ??
              MaterialLocalizations.of(context).deleteButtonTooltip,
          icon: Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    return discard == true;
  }

  Future<void> _save() async {
    if (_saving || !widget.canSave) return;
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final saved = await widget.onSave();
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      final navigator = Navigator.of(context);
      if (didPop || !await _confirmDiscard() || !mounted) return;
      navigator.pop(result);
    },
    child: HermesPageScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      titleMode: HermesPageTitleMode.large,
      maxContentWidth: widget.maxContentWidth,
      bodyPadding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      body: widget.child,
      bottomAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: widget.canSave && !_saving ? _save : null,
          child: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.saveLabel),
        ),
      ),
    ),
  );
}

/// One navigation contract for phone push-style screens, tablet split views
/// and desktop workspaces.  Feature screens provide the panes; this widget
/// owns when they can safely coexist.
class HermesResponsiveSplitView extends StatelessWidget {
  const HermesResponsiveSplitView({
    super.key,
    required this.primary,
    required this.secondary,
    this.tertiary,
    this.primaryWidth = 320,
    this.tertiaryWidth = 300,
  });

  final Widget primary;
  final Widget secondary;
  final Widget? tertiary;
  final double primaryWidth;
  final double tertiaryWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < HermesBreakpoints.navigation) return primary;
    final showTertiary =
        tertiary != null &&
        width >= primaryWidth + tertiaryWidth + HermesLayout.preview;
    return Row(
      children: [
        SizedBox(width: primaryWidth, child: primary),
        const VerticalDivider(width: 1),
        Expanded(child: secondary),
        if (showTertiary) ...[
          const VerticalDivider(width: 1),
          SizedBox(width: tertiaryWidth, child: tertiary),
        ],
      ],
    );
  }
}
