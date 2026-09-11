import 'dart:ui';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';

/// Bounded glass for navigation and controls; content stays on solid surfaces.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    double? radius,
    this.thick = false,
    this.role,
    // Keep the public radius argument while resolving role defaults lazily.
    // ignore: prefer_initializing_formals
  }) : _radius = radius;
  final Widget child;
  final double? _radius;
  final HermesGlassRole? role;
  double get radius =>
      _radius ??
      (role == null
          ? HermesGlassTokens.controlRadius
          : HermesGlassRecipe.forRole(role!).radius);

  /// Legacy density used only when [role] is absent.
  final bool thick;

  @override
  Widget build(BuildContext context) {
    final glass = HermesGlassTheme.of(context);
    if (!glass.enabled) return child;
    final palette = HermesPalette.of(context);
    final opaque = !glass.allowsTransparency(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final recipe = role == null ? null : HermesGlassRecipe.forRole(role!);
    final bottomAlpha =
        recipe?.bottomAlpha ??
        (thick
            ? HermesGlassTokens.thickBottomAlpha
            : HermesGlassTokens.regularBottomAlpha);
    final shape = BorderRadius.circular(radius);
    Element? ancestor;
    context.visitAncestorElements((element) {
      if (element.widget is GlassSurface) {
        ancestor = element;
        return false;
      }
      return true;
    });
    final parentGlass = ancestor == null
        ? null
        : HermesGlassTheme.of(ancestor!);
    final nested = parentGlass?.enabled == true;
    // One material plane owns the tint, lighting and shadow as well as blur.
    // Reapplying those layers inside it progressively hides the backdrop.
    final parentOpaque = nested && !parentGlass!.allowsTransparency(ancestor!);
    if (nested && (!opaque || parentOpaque)) {
      return ClipRSuperellipse(borderRadius: shape, child: child);
    }
    Widget content = DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: shape,
          side: opaque
              ? BorderSide(color: palette.borderStrong, width: 1.5)
              : BorderSide.none,
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.elevated.withValues(
              alpha: opaque
                  ? 1
                  : recipe?.topAlpha ??
                        (thick
                            ? HermesGlassTokens.thickTopAlpha
                            : HermesGlassTokens.regularTopAlpha),
            ),
            palette.surface.withValues(
              alpha: opaque
                  ? 1
                  // Bright content behind dark glass must not wash out
                  // secondary labels at the less-dense lower edge.
                  : dark
                  ? bottomAlpha.clamp(
                      HermesGlassTokens.darkMinimumBottomAlpha,
                      1.0,
                    )
                  : bottomAlpha,
            ),
          ],
        ),
      ),
      child: opaque ? child : null,
    );
    // A restrained specular wash gives the material a directional highlight
    // without tinting or blurring the foreground content. Keep it disabled
    // for opaque accessibility fallbacks where contrast must be predictable.
    if (!opaque) {
      content = Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: content),
          Positioned.fill(
            child: IgnorePointer(
              key: const ValueKey('glass-specular-layer'),
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: RoundedSuperellipseBorder(borderRadius: shape),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.centerRight,
                    stops: const [0, .28, .58],
                    colors: [
                      // Keep the wash visible enough to read as a material
                      // highlight while remaining restrained over bright
                      // content (the iOS dock treatment is never a flat
                      // white overlay).
                      Colors.white.withValues(alpha: dark ? .07 : .18),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('glass-edge-highlight'),
                painter: _GlassEdgePainter(radius: radius, dark: dark),
              ),
            ),
          ),
          if (nested)
            child
          else
            _GlassInteractionLight(dark: dark, child: child),
        ],
      );
    }
    // Nested controls share their parent's sampled backdrop. This prevents
    // tool groups and nested sheets from stacking expensive blur passes.
    if (!opaque && !nested) {
      content = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: recipe?.blurSigma ?? HermesGlassTokens.blurSigma,
          sigmaY: recipe?.blurSigma ?? HermesGlassTokens.blurSigma,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: shape),
        shadows: opaque || dark
            ? const []
            : const [
                BoxShadow(
                  color: HermesGlassTokens.lightShadow,
                  blurRadius: HermesGlassTokens.shadowBlur,
                  offset: HermesGlassTokens.shadowOffset,
                ),
              ],
      ),
      child: ClipRSuperellipse(borderRadius: shape, child: content),
    );
  }
}

/// Pointer light lives below content and never owns a gesture recognizer.
/// Only this small overlay rebuilds on movement, not the backdrop filter.
class _GlassInteractionLight extends StatefulWidget {
  const _GlassInteractionLight({required this.dark, required this.child});
  final bool dark;
  final Widget child;

  @override
  State<_GlassInteractionLight> createState() => _GlassInteractionLightState();
}

class _GlassInteractionLightState extends State<_GlassInteractionLight> {
  final _position = ValueNotifier<Offset?>(null);
  int? _activePointer;
  Offset? _pressOrigin;
  ScrollPosition? _scrollPosition;

  void _clearLight() {
    _position.value = null;
  }

  void _onScrollState() {
    if (_scrollPosition?.isScrollingNotifier.value ?? false) _clearLight();
  }

  void _release(int pointer) {
    if (_activePointer != pointer) return;
    _activePointer = null;
    _pressOrigin = null;
    _position.value = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final position = Scrollable.maybeOf(context)?.position;
    if (position != _scrollPosition) {
      _scrollPosition?.isScrollingNotifier.removeListener(_onScrollState);
      _scrollPosition = position;
      position?.isScrollingNotifier.addListener(_onScrollState);
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _activePointer = null;
      _position.value = null;
    }
  }

  @override
  void dispose() {
    _scrollPosition?.isScrollingNotifier.removeListener(_onScrollState);
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_activePointer != null) return;
        _activePointer = event.pointer;
        _pressOrigin = event.position;
        _position.value = event.localPosition;
      },
      onPointerMove: (event) {
        if (_activePointer == event.pointer) {
          // A drag is scrolling, not a held press. Keep it cleared until
          // release so moving beyond the surface cannot leave a light trail.
          if (_pressOrigin == null ||
              (event.position - _pressOrigin!).distance > 18) {
            _pressOrigin = null;
            _clearLight();
          } else {
            _position.value = event.localPosition;
          }
        }
      },
      onPointerUp: (event) => _release(event.pointer),
      onPointerCancel: (event) => _release(event.pointer),
      child: MouseRegion(
        opaque: false,
        onHover: (event) {
          if (_activePointer == null &&
              !(_scrollPosition?.isScrollingNotifier.value ?? false)) {
            _position.value = event.localPosition;
          }
        },
        onExit: (_) {
          _clearLight();
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<Offset?>(
                    valueListenable: _position,
                    builder: (context, position, _) => CustomPaint(
                      key: const ValueKey('glass-interaction-light'),
                      painter: _GlassInteractionPainter(position, widget.dark),
                    ),
                  ),
                ),
              ),
            ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _GlassInteractionPainter extends CustomPainter {
  const _GlassInteractionPainter(this.position, this.dark);
  final Offset? position;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = position;
    if (center == null || size.isEmpty) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(center, 96, [
          // Dark secondary text must retain contrast while the light moves
          // over a bright backdrop; stronger white wash exceeded that budget.
          Colors.white.withValues(alpha: dark ? .03 : .14),
          Colors.transparent,
        ]),
    );
  }

  @override
  bool shouldRepaint(_GlassInteractionPainter oldDelegate) =>
      position != oldDelegate.position || dark != oldDelegate.dark;
}

/// Directional surface lighting, not backdrop refraction. Paint an inset
/// ring only, below foreground content, without a saveLayer or extra filter.
class _GlassEdgePainter extends CustomPainter {
  const _GlassEdgePainter({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.shortestSide <= 1) return;
    final bounds = Offset.zero & size;
    final border = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(radius),
      side: const BorderSide(width: 1),
    );
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(border.getOuterPath(bounds), Offset.zero)
      ..addPath(border.getInnerPath(bounds), Offset.zero);
    final highlight = dark
        ? HermesGlassTokens.darkHighlight
        : HermesGlassTokens.lightHighlight;
    canvas.drawPath(
      ring,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0, .35, .65, 1],
          colors: [
            highlight,
            highlight.withValues(alpha: highlight.a * .35),
            highlight.withValues(alpha: highlight.a * .15),
            highlight.withValues(alpha: highlight.a * .65),
          ],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_GlassEdgePainter oldDelegate) =>
      radius != oldDelegate.radius || dark != oldDelegate.dark;
}
