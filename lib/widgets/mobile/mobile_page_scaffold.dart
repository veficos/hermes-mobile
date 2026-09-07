import 'package:flutter/material.dart';

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
    final content = scrollable
        ? SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: body,
          )
        : body;
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: showAppBar
          ? AppBar(
              leading: leading,
              titleSpacing: 14,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
              actions: actions,
            )
          : null,
      body: SafeArea(child: content),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
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
