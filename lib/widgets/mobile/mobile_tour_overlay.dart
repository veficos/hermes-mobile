import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/mobile_surface_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

class MobileTourOverlay extends StatelessWidget {
  const MobileTourOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.dependOnInheritedWidgetOfExactType<_MobileTourScope>() !=
        null) {
      return child;
    }
    final store = Provider.of<MobileSurfaceStore?>(context, listen: false);
    if (store == null) return child;
    return _MobileTourScope(
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final step = store.activeTourStep;
          if (step == null) return child;
          final size = MediaQuery.sizeOf(context);
          final rawTarget = store.targetRect(step.selector);
          final target = rawTarget == null
              ? null
              : Rect.fromLTRB(
                  (rawTarget.left - 6).clamp(8, size.width - 8),
                  (rawTarget.top - 6).clamp(8, size.height - 8),
                  (rawTarget.right + 6).clamp(8, size.width - 8),
                  (rawTarget.bottom + 6).clamp(8, size.height - 8),
                );
          return Stack(
            children: [
              child,
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _SpotlightPainter(target),
                          ),
                        ),
                      ),
                      SafeArea(
                        child: Align(
                          alignment:
                              target != null &&
                                  target.center.dy > size.height / 2
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          child: _TourCard(store: store, step: step),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MobileTourScope extends InheritedWidget {
  const _MobileTourScope({required super.child});

  @override
  bool updateShouldNotify(_MobileTourScope oldWidget) => false;
}

class _TourCard extends StatelessWidget {
  const _TourCard({required this.store, required this.step});

  final MobileSurfaceStore store;
  final MobileTourStep step;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(HermesRadius.sheet),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18)],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          step.title.isEmpty ? step.selector : step.title,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (step.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(step.text),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Text('${store.activeTourIndex + 1}/${store.activeTourCount}'),
            const Spacer(),
            TextButton(
              onPressed: store.stopTour,
              child: Text(context.l10n.commonClose),
            ),
            IconButton(
              onPressed: store.activeTourIndex == 0
                  ? null
                  : () => store.advanceTour(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              onPressed: store.activeTourIndex + 1 >= store.activeTourCount
                  ? null
                  : () => store.advanceTour(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SpotlightPainter extends CustomPainter {
  const _SpotlightPainter(this.target);
  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    if (target != null && target!.width > 0 && target!.height > 0) {
      path.addRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(14)),
      );
      path.fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = Colors.black54);
    if (target != null && target!.width > 0 && target!.height > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(target!, const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      oldDelegate.target != target;
}
