import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';
import '../../theme/hermes_glass_theme.dart';
import '../glass/glass_surface.dart';
import '../glass/glass_button.dart';
import '../glass/glass_environment.dart';
import '../glass/scroll_edge_scrim.dart';

enum HermesPageTitleMode { compact, large }

/// Modern adaptive page shell used by all feature screens.  It owns the
/// platform safe areas, content width, optional large-title collapse and the
/// keyboard-safe bottom action region.
class HermesPageScaffold extends StatelessWidget {
  const HermesPageScaffold({
    super.key,
    required this.title,
    this.titleSemanticsLabel,
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
    this.extendBehindNavigation = false,
    this.scrollBodyBehindHeader = false,
  });

  final String title;
  final String? titleSemanticsLabel;
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

  /// Opt-in for scrollables which include MediaQuery's bottom padding in
  /// their scroll extent. Other pages keep the safe, non-overlapping layout.
  final bool extendBehindNavigation;

  /// For an existing primary scrollable body (not a box to wrap in a scroll view).
  /// Liquid coordinates its scroll with the pinned glass header.
  final bool scrollBodyBehindHeader;

  Widget _constrain(Widget child) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth ?? double.infinity),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final liquid = HermesGlassTheme.of(context).enabled;
    final route = ModalRoute.of(context);
    final resolvedLeading =
        leading ??
        (liquid && route?.impliesAppBarDismissal == true
            ? GlassButton(
                tooltip: route is PageRoute && route.fullscreenDialog
                    ? MaterialLocalizations.of(context).closeButtonTooltip
                    : MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.of(context).maybePop(),
                child: route is PageRoute && route.fullscreenDialog
                    ? const Icon(Icons.close)
                    : const BackButtonIcon(),
              )
            : null);
    final glassHeader = liquid
        ? const ScrollEdgeScrim(
            child: GlassSurface(
              radius: 0,
              role: HermesGlassRole.navigation,
              child: SizedBox.expand(),
            ),
          )
        : null;
    final useLargeTitle =
        showAppBar &&
        titleMode == HermesPageTitleMode.large &&
        MediaQuery.sizeOf(context).width < HermesBreakpoints.navigation;
    // A scroll-owned header lets content actually pass behind the material.
    // Keep non-scrollable bodies out of this path: their constraints and
    // keyboard layout must remain owned by Scaffold.
    final useScrollingHeader = liquid && showAppBar && scrollable;
    final useNestedHeader = liquid && showAppBar && scrollBodyBehindHeader;

    Widget content;
    if ((useLargeTitle && !scrollable) || useNestedHeader) {
      content = NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          if (useLargeTitle)
            SliverAppBar.large(
              leading: resolvedLeading,
              title: Text(title, semanticsLabel: titleSemanticsLabel),
              actions: actions,
              pinned: true,
              forceElevated: innerBoxIsScrolled,
              backgroundColor: liquid
                  ? Colors.transparent
                  : backgroundColor ?? palette.bg,
              flexibleSpace: glassHeader,
              surfaceTintColor: Colors.transparent,
            ),
          if (!useLargeTitle)
            SliverAppBar(
              leading: resolvedLeading,
              title: Text(title, semanticsLabel: titleSemanticsLabel),
              actions: actions,
              pinned: true,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: glassHeader,
              elevation: 0,
              scrolledUnderElevation: 0,
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
            leading: resolvedLeading,
            title: Text(title, semanticsLabel: titleSemanticsLabel),
            actions: actions,
            pinned: true,
            backgroundColor: liquid
                ? Colors.transparent
                : backgroundColor ?? palette.bg,
            flexibleSpace: glassHeader,
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
    } else if (useScrollingHeader) {
      content = CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            leading: resolvedLeading,
            titleSpacing: 16,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  semanticsLabel: titleSemanticsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
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
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            flexibleSpace: glassHeader,
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

    final useEnvironment = liquid && backgroundColor == null;
    final page = Scaffold(
      backgroundColor:
          backgroundColor ?? (useEnvironment ? Colors.transparent : palette.bg),
      appBar:
          !showAppBar || useLargeTitle || useScrollingHeader || useNestedHeader
          ? null
          : AppBar(
              backgroundColor: HermesGlassTheme.of(context).enabled
                  ? Colors.transparent
                  : null,
              flexibleSpace: HermesGlassTheme.of(context).enabled
                  ? const GlassSurface(
                      radius: 0,
                      role: HermesGlassRole.navigation,
                      child: SizedBox.expand(),
                    )
                  : null,
              leading: resolvedLeading,
              titleSpacing: 16,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    semanticsLabel: titleSemanticsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
      body: SafeArea(
        top: !(useLargeTitle || useScrollingHeader || useNestedHeader),
        bottom: !(liquid && extendBehindNavigation),
        // StretchingOverscrollIndicator transforms the complete viewport,
        // including pinned backdrop filters. Keep those layers in stable
        // coordinates while still delivering overscroll notifications to
        // RefreshIndicator (do not replace the scroll physics).
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            overscroll:
                !(useLargeTitle || useNestedHeader || useScrollingHeader),
          ),
          child: content,
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom,
    );
    // Standalone routes own a base; embedded pages reuse the shell's field.
    // Explicit content backgrounds (previews/editors) remain authoritative.
    return useEnvironment ? GlassEnvironment(child: page) : page;
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
          duration: HermesGlassMotion.resolve(context, HermesMotion.fast),
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
  final liquid =
      HermesGlassTheme.of(context).enabled && backgroundColor == null;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: liquid ? false : showDragHandle,
    backgroundColor: liquid ? Colors.transparent : backgroundColor,
    // GlassSurface owns the outline. The route must not paint a second
    // theme border around the sheet (including its keyboard padding).
    shape: liquid ? const RoundedRectangleBorder() : null,
    elevation: liquid ? 0 : null,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
        liquid ? 12 : 0,
        liquid ? 12 : 0,
        liquid ? 12 : 0,
        (avoidViewInsets ? MediaQuery.viewInsetsOf(ctx).bottom : 0) +
            (liquid
                ? 12 + (useSafeArea ? MediaQuery.paddingOf(ctx).bottom : 0)
                : 0),
      ),
      child: liquid
          ? GlassSurface(
              radius: 30,
              role: HermesGlassRole.overlay,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showDragHandle)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: HermesPalette.of(ctx).borderStrong,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  Flexible(
                    child: MediaQuery.removePadding(
                      context: ctx,
                      removeBottom: useSafeArea,
                      child: Builder(builder: builder),
                    ),
                  ),
                ],
              ),
            )
          : builder(ctx),
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
