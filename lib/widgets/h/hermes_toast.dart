/// HermesToast — design-system toast (design-system.md §6.10): elevated 底 +
/// 语义色左竖条 3px + callout 文案，r-md；底部居中（手机）/ 右下（桌面，
/// 宽度 ≥840），2400ms 自动消失。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../theme/hermes_tokens.dart';

enum HermesToastKind { success, error, info }

void showHermesToast(
  BuildContext context, {
  required String message,
  HermesToastKind kind = HermesToastKind.info,
}) {
  HermesHaptics.fire(switch (kind) {
    HermesToastKind.error => HermesHapticIntent.error,
    HermesToastKind.success => HermesHapticIntent.success,
    HermesToastKind.info => HermesHapticIntent.selection,
  });
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _HermesToastView(
      message: message,
      kind: kind,
      onDone: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );
  overlay.insert(entry);
}

class _HermesToastView extends StatefulWidget {
  final String message;
  final HermesToastKind kind;
  final VoidCallback onDone;

  const _HermesToastView({
    required this.message,
    required this.kind,
    required this.onDone,
  });

  @override
  State<_HermesToastView> createState() => _HermesToastViewState();
}

class _HermesToastViewState extends State<_HermesToastView>
    with SingleTickerProviderStateMixin {
  Timer? _dismissTimer;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // §5.4：组件显隐 160–200ms
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<Offset> _slide =
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _controller, curve: const Cubic(0.2, 0, 0, 1)),
      );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _controller.reverse().then((_) => widget.onDone());
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final (icon, color) = switch (widget.kind) {
      HermesToastKind.success => (
        Icons.check_circle_outline,
        hermesSemantic(context, HermesSemantic.green, HermesSemanticDark.green),
      ),
      HermesToastKind.error => (
        Icons.error_outline,
        hermesSemantic(context, HermesSemantic.red, HermesSemanticDark.red),
      ),
      HermesToastKind.info => (
        Icons.info_outline,
        hermesSemantic(context, HermesSemantic.blue, HermesSemanticDark.blue),
      ),
    };
    // §6.10：底部居中（手机）/ 右下（桌面，宽度 ≥840）。
    final isDesktop = MediaQuery.of(context).size.width >= 840;
    return Positioned(
      left: isDesktop ? null : 24,
      right: 24,
      bottom: isDesktop ? 24 : 90,
      child: IgnorePointer(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _controller,
            child: Align(
              alignment: isDesktop ? Alignment.centerRight : Alignment.center,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 360 : double.infinity,
                ),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.elevated,
                    borderRadius: BorderRadius.circular(HermesRadius.card),
                    border: Border.all(color: palette.border),
                    boxShadow: hermesShadow(context, HermesShadowTier.md),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 语义色左竖条 3px
                        Container(width: 3, color: color),
                        const SizedBox(width: 11),
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Text(
                              widget.message,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: HermesType.callout.copyWith(
                                color: palette.text2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
