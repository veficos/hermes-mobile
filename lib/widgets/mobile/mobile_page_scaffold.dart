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

Future<T?> showMobileSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
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
