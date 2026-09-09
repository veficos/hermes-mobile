import 'package:flutter/material.dart';

/// Shared reading column for the transcript and composer, including in panes.
class ChatContentColumn extends StatelessWidget {
  const ChatContentColumn({
    super.key,
    required this.child,
    this.includeGutter = true,
  });

  static const double maxWidth = 820;
  static const double gutter = 12;
  final Widget child;
  final bool includeGutter;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: maxWidth),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: includeGutter ? gutter : 0),
          child: child,
        ),
      ),
    ),
  );
}
