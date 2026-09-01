/// Unified empty / error / loading states (design-system.md §6.9):
/// 空态 64px 线性图标 text-4 + title + callout 描述 + 可选 Primary；
/// 加载优先骨架屏（surface 上 6% 底呼吸块）；错误 error 图标 + 描述 +
/// 重试 Secondary。
library;

import 'package:flutter/material.dart';

import '../../core/haptics.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import 'hermes_progress.dart';

String hermesErrorMessage(
  BuildContext context,
  Object error, {
  String? fallback,
}) {
  final text = error.toString();
  if (text.contains('401') || text.contains('403')) {
    return context.l10n.commonAuthenticationFailed;
  }
  if (text.contains('SocketException') ||
      text.contains('WebSocket') ||
      text.contains('Timeout')) {
    return context.l10n.commonNetworkFailed;
  }
  return fallback ?? context.l10n.commonOperationFailed;
}

void showHermesErrorSnackBar(
  BuildContext context,
  Object error, {
  String? fallback,
  VoidCallback? onRetry,
}) {
  HermesHaptics.fire(HermesHapticIntent.error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(hermesErrorMessage(context, error, fallback: fallback)),
      action: onRetry == null
          ? null
          : SnackBarAction(label: context.l10n.commonRetry, onPressed: onRetry),
    ),
  );
}

/// Icon + Title + Description + Primary/Secondary actions (design-system.md
/// §6.9 空态：64px 线性图标 text-4 + title 标题 + callout 描述 + 可选
/// Primary 按钮，垂直居中).
class HermesEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const HermesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: palette.text4),
            const SizedBox(height: HermesSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: HermesType.title.copyWith(color: palette.text),
            ),
            if (description != null) ...[
              const SizedBox(height: HermesSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: HermesType.callout.copyWith(color: palette.text3),
              ),
            ],
            if (primaryLabel != null) ...[
              const SizedBox(height: HermesSpacing.lg),
              FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
            ],
            if (secondaryLabel != null) ...[
              const SizedBox(height: HermesSpacing.xs),
              TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error icon + title + description + Retry (Secondary) + alternative action
/// (design-system.md §6.9 错误态).
class HermesErrorState extends StatelessWidget {
  final String? title;
  final String? description;
  final VoidCallback? onRetry;
  final String? alternativeLabel;
  final VoidCallback? onAlternative;

  const HermesErrorState({
    super.key,
    this.title,
    this.description,
    this.onRetry,
    this.alternativeLabel,
    this.onAlternative,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final error = hermesSemantic(
      context,
      HermesSemantic.red,
      HermesSemanticDark.red,
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: error),
            const SizedBox(height: HermesSpacing.md),
            Text(
              title ?? context.l10n.commonErrorTitle,
              textAlign: TextAlign.center,
              style: HermesType.title.copyWith(color: palette.text),
            ),
            if (description != null) ...[
              const SizedBox(height: HermesSpacing.xs),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: HermesType.callout.copyWith(color: palette.text3),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: HermesSpacing.lg),
              OutlinedButton(
                onPressed: onRetry,
                child: Text(context.l10n.commonRetry),
              ),
            ],
            if (alternativeLabel != null) ...[
              const SizedBox(height: HermesSpacing.xs),
              TextButton(
                onPressed: onAlternative,
                child: Text(alternativeLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton-first loading state (design-system.md §6.9 加载态：骨架屏优先
/// 于 spinner —— surface 上叠加 6% 底呼吸块；确定性进度走 3px accent 细条)。
class HermesLoadingState extends StatelessWidget {
  final String? label;
  final String? stepLabel;
  final double? progress;
  final bool showDots;

  const HermesLoadingState({
    super.key,
    this.label,
    this.stepLabel,
    this.progress,
    this.showDots = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showDots)
              const HermesTypingDots()
            else
              const SizedBox(
                width: 200,
                child: Column(
                  children: [
                    HermesSkeletonBlock(width: 200, height: 14),
                    SizedBox(height: HermesSpacing.xs),
                    HermesSkeletonBlock(width: 160, height: 14),
                    SizedBox(height: HermesSpacing.xs),
                    HermesSkeletonBlock(width: 120, height: 14),
                  ],
                ),
              ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              label ?? context.l10n.commonLoading,
              style: theme.textTheme.bodyMedium?.copyWith(color: palette.text3),
            ),
            if (stepLabel != null) ...[
              const SizedBox(height: 4),
              Text(
                stepLabel!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.text4,
                ),
              ),
            ],
            if (progress != null) ...[
              const SizedBox(height: HermesSpacing.md),
              SizedBox(width: 200, child: HermesProgressBar(value: progress!)),
              const SizedBox(height: 4),
              Text(
                '${(progress! * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.text3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton breathing block (design-system.md §6.9 加载态)：surface 底上
/// 叠加 6% 呼吸块；系统"减弱动态效果"开启时静态呈现（§9）。
class HermesSkeletonBlock extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const HermesSkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.radius = HermesRadius.smallCard,
  });

  @override
  State<HermesSkeletonBlock> createState() => _HermesSkeletonBlockState();
}

class _HermesSkeletonBlockState extends State<HermesSkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 6% 底呼吸块：浅色叠黑 6%，深色叠白 6%。
    final overlay = isDark ? Colors.white : Colors.black;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 1.0 : (0.55 + 0.45 * _controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: palette.border),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: overlay.withValues(alpha: 0.06 * t),
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// A compact inline loading pill (for chat input / list tiles).
class HermesLoadingPill extends StatelessWidget {
  final String? label;
  const HermesLoadingPill({super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.accentBg,
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
        border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label ?? context.l10n.commonLoading,
            style: theme.textTheme.labelMedium?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-dot typing/loading indicator (design system loading-dots / chat-typing).
class HermesTypingDots extends StatelessWidget {
  final Color? color;
  const HermesTypingDots({super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? HermesPalette.of(context).accent;
    return SizedBox(
      width: 40,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _Dot(color: dotColor, delay: i * 160),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final Color color;
  final int delay;
  const _Dot({required this.color, required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion (spec §162): static dots when the OS disables animations.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return ScaleTransition(
      scale: Tween(
        begin: 0.5,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Unified page state machine (spec §8): a single enum every screen maps its
/// data-fetch lifecycle to, rendered through [HermesStateView] so all pages
/// share one look. Screens may keep their bespoke loading/error/empty widgets;
/// this is the canonical mapping for simple list/detail fetches.
enum HermesViewState {
  initializing,
  loading,
  ready,
  empty,
  processing,
  error,
  offline,
  disabled,
  success;

  bool get isBusy =>
      this == initializing || this == loading || this == processing;
}

/// Renders a [HermesViewState] with the shared empty/error/loading widgets.
class HermesStateView extends StatelessWidget {
  final HermesViewState state;
  final String? loadingLabel;
  final String? emptyTitle;
  final String? emptyDescription;
  final IconData emptyIcon;
  final String? errorTitle;
  final String? errorDescription;
  final VoidCallback? onRetry;
  final Widget? child; // shown for ready / success

  const HermesStateView({
    super.key,
    required this.state,
    this.loadingLabel,
    this.emptyTitle,
    this.emptyDescription,
    this.emptyIcon = Icons.inbox_outlined,
    this.errorTitle,
    this.errorDescription,
    this.onRetry,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case HermesViewState.initializing:
      case HermesViewState.loading:
      case HermesViewState.processing:
        return HermesLoadingState(
          label: loadingLabel ?? context.l10n.commonLoading,
        );
      case HermesViewState.empty:
        return HermesEmptyState(
          icon: emptyIcon,
          title: emptyTitle ?? context.l10n.commonNoData,
          description: emptyDescription,
          primaryLabel: onRetry == null ? null : context.l10n.commonRefresh,
          onPrimary: onRetry,
        );
      case HermesViewState.error:
      case HermesViewState.offline:
      case HermesViewState.disabled:
        return HermesErrorState(
          title: state == HermesViewState.offline
              ? context.l10n.backendDisconnected
              : state == HermesViewState.disabled
              ? context.l10n.commonFeatureDisabled
              : errorTitle,
          description: state == HermesViewState.offline
              ? context.l10n.commonNetworkFailed
              : errorDescription,
          onRetry: onRetry,
        );
      case HermesViewState.ready:
      case HermesViewState.success:
        return child ?? const SizedBox.shrink();
    }
  }
}
