import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

enum HermesPageTitleMode { compact, large }

/// Modern adaptive page shell used by all feature screens.  It owns the
/// platform safe areas, content width, optional large-title collapse and the
/// keyboard-safe bottom action region.
class HermesPageScaffold extends StatelessWidget {
  const HermesPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.titleMode = HermesPageTitleMode.compact,
    this.maxContentWidth,
    this.bodyPadding = EdgeInsets.zero,
    this.scrollable = false,
    this.bottomAction,
    this.header,
    this.showAppBar = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final HermesPageTitleMode titleMode;
  final double? maxContentWidth;
  final EdgeInsetsGeometry bodyPadding;
  final bool scrollable;
  final Widget? bottomAction;
  final Widget? header;
  final bool showAppBar;

  Widget _constrain(Widget child) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth ?? double.infinity),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final useLargeTitle =
        showAppBar &&
        titleMode == HermesPageTitleMode.large &&
        MediaQuery.sizeOf(context).width < HermesBreakpoints.navigation;

    Widget content;
    if (useLargeTitle && !scrollable) {
      content = NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar.large(
            leading: leading,
            title: Text(title),
            actions: actions,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: backgroundColor ?? palette.bg,
            surfaceTintColor: Colors.transparent,
          ),
          if (subtitle?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _constrain(
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.text3),
                  ),
                ),
              ),
            ),
          if (header != null) SliverToBoxAdapter(child: _constrain(header!)),
        ],
        body: _constrain(Padding(padding: bodyPadding, child: body)),
      );
    } else if (useLargeTitle) {
      content = CustomScrollView(
        slivers: [
          SliverAppBar.large(
            leading: leading,
            title: Text(title),
            actions: actions,
            pinned: true,
            backgroundColor: backgroundColor ?? palette.bg,
            surfaceTintColor: Colors.transparent,
          ),
          if (subtitle?.isNotEmpty == true)
            SliverToBoxAdapter(
              child: _constrain(
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                  child: Text(
                    subtitle!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.text3),
                  ),
                ),
              ),
            ),
          if (header != null) SliverToBoxAdapter(child: _constrain(header!)),
          SliverPadding(
            padding: bodyPadding,
            sliver: SliverToBoxAdapter(child: _constrain(body)),
          ),
        ],
      );
    } else {
      final padded = Padding(padding: bodyPadding, child: body);
      content = scrollable
          ? SingleChildScrollView(child: _constrain(padded))
          : _constrain(padded);
      if (header != null) {
        content = Column(
          children: [
            header!,
            Expanded(child: content),
          ],
        );
      }
    }

    final bottom = bottomAction == null
        ? bottomNavigationBar
        : _HermesBottomAction(below: bottomNavigationBar, child: bottomAction!);

    return Scaffold(
      backgroundColor: backgroundColor ?? palette.bg,
      appBar: !showAppBar || useLargeTitle
          ? null
          : AppBar(
              leading: leading,
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (subtitle?.isNotEmpty == true)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: palette.text3),
                    ),
                ],
              ),
              actions: actions,
            ),
      body: SafeArea(top: !useLargeTitle, child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom,
    );
  }
}

class _HermesBottomAction extends StatelessWidget {
  const _HermesBottomAction({required this.child, required this.below});

  final Widget child;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedPadding(
          duration: HermesMotion.fast,
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: child,
              ),
            ),
          ),
        ),
        ?below,
      ],
    );
  }
}

/// Shared phone page shell: safe areas, consistent title bar and scrolling.
class MobilePageScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? leading;
  final Color? backgroundColor;
  final bool showAppBar;
  final bool scrollable;

  const MobilePageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.leading,
    this.backgroundColor,
    this.showAppBar = true,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    return HermesPageScaffold(
      title: title,
      subtitle: subtitle,
      actions: actions,
      leading: leading,
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      backgroundColor: backgroundColor,
      showAppBar: showAppBar,
      scrollable: scrollable,
      bodyPadding: scrollable
          ? const EdgeInsets.fromLTRB(16, 8, 16, 24)
          : EdgeInsets.zero,
    );
  }
}

/// Shared mobile bottom sheet: drag handle, SafeArea and keyboard avoidance
/// are on by default and can be turned off per call site.
///
/// - [showDragHandle]: Material drag handle at the top (default true).
/// - [useSafeArea]: keep the sheet inside system safe areas (default true).
/// - [avoidViewInsets]: pad the bottom by the keyboard height (default true);
///   turn off for sheets without text input.
/// - [isScrollControlled]: let the sheet grow past half screen (default
///   true); pass false for compact, intrinsic-height pickers.
/// - [backgroundColor]: sheet background; pass `Colors.transparent` when the
///   content draws its own surface (e.g. floating-card action sheets).
Future<T?> showMobileSheet<T>(
  BuildContext context,
  WidgetBuilder builder, {
  bool showDragHandle = true,
  bool useSafeArea = true,
  bool avoidViewInsets = true,
  bool isScrollControlled = true,
  Color? backgroundColor,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    builder: (ctx) => Padding(
      padding: avoidViewInsets
          ? EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom)
          : EdgeInsets.zero,
      child: builder(ctx),
    ),
  );
}

/// Adds phone-safe insets without disturbing a screen's stateful AppBar,
/// drawer, selection mode or other existing Scaffold behavior.
class MobileSafeBody extends StatelessWidget {
  final Widget child;
  final bool top;
  final bool bottom;

  const MobileSafeBody({
    super.key,
    required this.child,
    this.top = false,
    this.bottom = true,
  });

  @override
  Widget build(BuildContext context) =>
      SafeArea(top: top, bottom: bottom, child: child);
}
