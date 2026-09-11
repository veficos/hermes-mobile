/// Unified empty / error / loading states (design-system.md §6.9):
/// 空态 64px（可调）线性图标 text-4 + title + callout 描述 + 可选
/// Primary/Secondary/自定义 actions；加载优先骨架屏（surface 上 6% 底
/// 呼吸块，高对比提升透明度并加粗边框）；错误 error 图标 + 描述 +
/// 重试 Secondary。
library;

import 'dart:async';
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
  final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
  final message = hermesErrorMessage(context, error, fallback: fallback);
  var retryInvoked = false;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: largeText && onRetry != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(message),
                const SizedBox(height: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(
                          context,
                        ).snackBarTheme.contentTextStyle?.color ??
                        Theme.of(context).colorScheme.onInverseSurface,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: () {
                    if (retryInvoked) return;
                    retryInvoked = true;
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onRetry();
                  },
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            )
          : Text(message),
      action: onRetry == null || largeText
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

  /// 图标尺寸，默认 64（§6.9）；紧凑面板可传更小值。
  final double iconSize;

  /// 图标颜色，默认 text-4；品牌向空态（如 chat 欢迎页）可覆写。
  final Color? iconColor;

  /// 追加在内置 Primary/Secondary 按钮之后的自定义行动区
  /// （如 starter prompt chips）。
  final Widget? actions;

  const HermesEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.iconSize = 64,
    this.iconColor,
    this.actions,
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
            Icon(icon, size: iconSize, color: iconColor ?? palette.text4),
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
            if (actions != null) ...[
              const SizedBox(height: HermesSpacing.lg),
              actions!,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
  );
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = HermesA11y.highContrastOf(context);
    // 6% 底呼吸块：浅色叠黑 6%，深色叠白 6%；高对比下底色透明度
    // 提升（§3.7），边框升级 borderStrong + 1.5px 与主题边框一致。
    final overlay = isDark ? Colors.white : Colors.black;
    final baseAlpha = hermesTintAlpha(context, 0.06);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _reduceMotion ? 1.0 : (0.55 + 0.45 * _controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(
              color: highContrast ? palette.borderStrong : palette.border,
              width: highContrast ? 1.5 : 1,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: overlay.withValues(alpha: baseAlpha * t),
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
        border: Border.all(
          color: palette.accent.withValues(
            // 高对比：0.25 的 accent 描边过淡，提升至 0.45。
            alpha: hermesTintAlpha(context, 0.25),
          ),
        ),
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
  );
  Timer? _startTimer;
  bool _reduceMotion = false;
  late final Animation<double> _scale = _controller
      .drive(CurveTween(curve: Curves.easeInOut))
      .drive(Tween(begin: 0.5, end: 1.0));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) {
      _startTimer?.cancel();
      _startTimer = null;
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating && _startTimer == null) {
      _startTimer = Timer(Duration(milliseconds: widget.delay), () {
        _startTimer = null;
        if (mounted && !_reduceMotion) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduce Motion (spec §162): static dots when the OS disables animations.
    if (_reduceMotion) {
      return Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      );
    }
    return ScaleTransition(
      scale: _scale,
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
