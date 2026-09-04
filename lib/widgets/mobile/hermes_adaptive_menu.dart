import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

/// A project-wide menu button that uses a thumb-friendly action sheet on
/// phones and an anchored popup menu on larger displays.
///
/// The API intentionally mirrors [PopupMenuButton], so existing menu entries
/// keep their semantics, custom children, checked state and callbacks.
class HermesAdaptiveMenuButton<T> extends StatelessWidget {
  const HermesAdaptiveMenuButton({
    super.key,
    required this.itemBuilder,
    this.initialValue,
    this.onOpened,
    this.onSelected,
    this.onCanceled,
    this.tooltip,
    this.padding = const EdgeInsets.all(8),
    this.menuPadding,
    this.child,
    this.icon,
    this.iconSize,
    this.iconColor,
    this.enabled = true,
    this.constraints,
    this.offset = Offset.zero,
    this.position,
    this.useRootNavigator = false,
  }) : assert(child == null || icon == null);

  final PopupMenuItemBuilder<T> itemBuilder;
  final T? initialValue;
  final VoidCallback? onOpened;
  final PopupMenuItemSelected<T>? onSelected;
  final PopupMenuCanceled? onCanceled;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? menuPadding;
  final Widget? child;
  final Widget? icon;
  final double? iconSize;
  final Color? iconColor;
  final bool enabled;
  final BoxConstraints? constraints;
  final Offset offset;
  final PopupMenuPosition? position;
  final bool useRootNavigator;

  Future<void> _openPhoneMenu(BuildContext context) async {
    if (!enabled) return;
    onOpened?.call();
    final entries = itemBuilder(context);
    final selected = await showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .38),
      builder: (sheetContext) => _HermesPhoneMenuSheet<T>(
        entries: entries,
        initialValue: initialValue,
        title: tooltip,
      ),
    );
    if (selected != null) {
      onSelected?.call(selected);
    } else {
      onCanceled?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).width < HermesBreakpoints.phone;
    if (!isPhone) {
      return PopupMenuButton<T>(
        initialValue: initialValue,
        onOpened: onOpened,
        onSelected: onSelected,
        onCanceled: onCanceled,
        tooltip: tooltip,
        padding: padding,
        menuPadding: menuPadding,
        icon: icon,
        iconSize: iconSize,
        iconColor: iconColor,
        enabled: enabled,
        constraints: constraints,
        offset: offset,
        position: position,
        useRootNavigator: useRootNavigator,
        itemBuilder: itemBuilder,
        child: child,
      );
    }

    if (child != null) {
      final button = InkWell(
        onTap: enabled ? () => _openPhoneMenu(context) : null,
        child: child,
      );
      return tooltip == null
          ? button
          : Tooltip(message: tooltip!, child: button);
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? () => _openPhoneMenu(context) : null,
      padding: padding,
      constraints: constraints,
      iconSize: iconSize,
      color: iconColor,
      icon: icon ?? const Icon(Icons.more_vert),
    );
  }
}

class _HermesPhoneMenuSheet<T> extends StatelessWidget {
  const _HermesPhoneMenuSheet({
    required this.entries,
    required this.initialValue,
    required this.title,
  });

  final List<PopupMenuEntry<T>> entries;
  final T? initialValue;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.sizeOf(context).height * .78,
        ),
        child: Material(
          color: palette.elevated,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            side: BorderSide(color: palette.border),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: keyboard),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.borderStrong,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                if (title != null && title!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 13, 12, 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Flexible(
                  child: Semantics(
                    role: SemanticsRole.menu,
                    explicitChildNodes: true,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in entries)
                            _phoneEntry(context, entry),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _phoneEntry(BuildContext context, PopupMenuEntry<T> entry) {
    if (entry is PopupMenuDivider) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Divider(height: entry.height),
      );
    }
    final selected = initialValue != null && entry.represents(initialValue);
    final value = entry is PopupMenuItem<T> ? entry.value : null;
    final destructive =
        value is String &&
        const {'delete', 'disconnect', 'remove'}.contains(value.toLowerCase());
    final foreground = destructive
        ? Theme.of(context).colorScheme.error
        : selected
        ? Theme.of(context).colorScheme.primary
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? HermesPalette.of(context).accentBg
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: IconTheme.merge(
            data: IconThemeData(size: 21, color: foreground),
            child: DefaultTextStyle.merge(
              style: TextStyle(color: foreground),
              child: entry,
            ),
          ),
        ),
      ),
    );
  }
}
