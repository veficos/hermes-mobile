import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../core/bot_avatar.dart';
import '../l10n/l10n.dart';

/// Shared bot-avatar renderer: procedural face (shape/color derived from the
/// bot's name, matching desktop bit-for-bit — see `core/bot_avatar.dart`) by
/// default, or an uploaded/generated image when `metadata['image']` is set.
/// Used for roster rows, chat headers, and group-member chips so all three
/// stay visually consistent instead of each hand-rolling a color dot.
///
/// When [working] is true and there's no image, the face animates (blink,
/// lean/sway, pulsing thinking-dots) at a throttled ~15fps, mirroring
/// desktop's `paintMathFace`/`facePose('work', t)`. Idle faces stay static —
/// only actively-working bots pay for a ticker.
class BotAvatar extends StatefulWidget {
  final String name;
  final Map<String, dynamic>? metadata;
  final double size;
  final bool working;

  const BotAvatar({
    super.key,
    required this.name,
    this.metadata,
    this.size = 36,
    this.working = false,
  });

  @override
  State<BotAvatar> createState() => _BotAvatarState();
}

class _BotAvatarState extends State<BotAvatar>
    with SingleTickerProviderStateMixin {
  static const _frameInterval = Duration(milliseconds: 66);

  Ticker? _ticker;
  Duration _lastPaint = Duration.zero;
  double _t = 0;
  bool _reduceMotion = false;
  String? _imageSource;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _syncImage();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations == true ||
        MediaQuery.maybeOf(context)?.accessibleNavigation == true;
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant BotAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncImage();
    _syncTicker();
  }

  void _syncImage() {
    final source = botAppearance(widget.name, widget.metadata).image;
    if (_imageSource == source) return;
    _imageSource = source;
    _imageBytes = _decodeImage(source);
  }

  void _syncTicker() {
    final shouldAnimate =
        widget.working && _imageBytes == null && !_reduceMotion;
    if (shouldAnimate) {
      _ticker ??= createTicker(_onTick);
      if (!_ticker!.isActive) {
        _lastPaint = Duration.zero;
        _ticker!.start();
      }
    } else {
      _ticker?.stop();
      _t = 0;
    }
  }

  void _onTick(Duration elapsed) {
    if (elapsed - _lastPaint < _frameInterval) return;
    _lastPaint = elapsed;
    setState(() => _t = elapsed.inMilliseconds / 1000.0);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appearance = botAppearance(widget.name, widget.metadata);
    final image = _imageBytes;
    Widget fallback({bool still = false}) => CustomPaint(
      key: const ValueKey('bot-avatar-fallback'),
      size: Size(widget.size, widget.size),
      painter: _BotFacePainter(
        shape: appearance.shape,
        color: appearance.color,
        working: widget.working && !_reduceMotion && !still,
        t: still ? 0 : _t,
      ),
    );
    return Semantics(
      label: context.l10n.avatarNamed(widget.name),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: ClipOval(
          child: image != null
              ? Image.memory(
                  image,
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) =>
                      frame == null ? fallback(still: true) : child,
                  errorBuilder: (context, error, stackTrace) =>
                      fallback(still: true),
                )
              : fallback(),
        ),
      ),
    );
  }
}

Uint8List? _decodeImage(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final comma = dataUrl.indexOf(',');
  if (!dataUrl.startsWith('data:') || comma == -1) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

class _BotFacePainter extends CustomPainter {
  final String shape;
  final Color color;
  final bool working;
  final double t;

  const _BotFacePainter({
    required this.shape,
    required this.color,
    required this.working,
    this.t = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Desktop's viewBox is 0..40 wide, 0..44 tall (the extra 4px hosts the
    // "working" thinking-dots row below the body).
    final scale = size.width / 40;
    canvas.save();
    canvas.scale(scale, scale);

    final pose = working ? facePose('work', t) : facePose('idle', 0);

    // Mirrors `svg.style.transform = rotate(pose.tilt)` around `50% 70%`.
    canvas.save();
    canvas.translate(20, 30.8);
    canvas.rotate(pose.tilt * 3.1415926535 / 180);
    canvas.translate(-20, -30.8);

    final body = shape == 'cloud'
        ? cloudBodyPath()
        : ringToPath(
            sampleFaceRing(shape)
                .map(
                  (p) => projectFacePoint(
                    p.dx,
                    p.dy,
                    pose.turn,
                    pose.tilt,
                    pose.roll,
                  ),
                )
                .toList(),
          );
    canvas.drawPath(body, Paint()..color = color);

    final dark = isDarkColor(color);
    final eyeFill = dark ? const Color(0xF0E8DCC3) : const Color(0xD9000000);
    final hlFill = dark ? const Color(0x99000000) : const Color(0xD9FFFFFF);
    final eyeY = (shape == 'cloud' ? 22.0 : 17.2) + pose.gazeY;
    final eyeL = 15.4 + pose.gazeX;
    final eyeR = 24.6 + pose.gazeX;
    final eyeRy = working ? 2.6 : 2.3;

    if (!pose.blink) {
      final eyePaint = Paint()..color = eyeFill;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(eyeL, eyeY),
          width: 4.4,
          height: eyeRy * 2,
        ),
        eyePaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(eyeR, eyeY),
          width: 4.4,
          height: eyeRy * 2,
        ),
        eyePaint,
      );

      final hlPaint = Paint()..color = hlFill;
      canvas.drawCircle(Offset(eyeL - 0.6, eyeY - 0.7), 0.65, hlPaint);
      canvas.drawCircle(Offset(eyeR - 0.6, eyeY - 0.7), 0.65, hlPaint);
    } else {
      final shutPaint = Paint()
        ..color = eyeFill
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(eyeL - 2.6, eyeY),
        Offset(eyeL + 2.6, eyeY),
        shutPaint,
      );
      canvas.drawLine(
        Offset(eyeR - 2.6, eyeY),
        Offset(eyeR + 2.6, eyeY),
        shutPaint,
      );
    }

    if (working) {
      canvas.drawCircle(
        const Offset(16.4, 41.2),
        1.15,
        Paint()..color = color.withValues(alpha: pose.d0),
      );
      canvas.drawCircle(
        const Offset(20, 41.2),
        1.15,
        Paint()..color = color.withValues(alpha: pose.d1),
      );
      canvas.drawCircle(
        const Offset(23.6, 41.2),
        1.15,
        Paint()..color = color.withValues(alpha: pose.d2),
      );
    }

    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BotFacePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.color != color ||
      oldDelegate.working != working ||
      oldDelegate.t != t;
}
