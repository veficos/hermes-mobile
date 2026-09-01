/// HermesLogo —— 品牌重塑后的新 logo（design-system.md §2.2 方向 A「翼标」）。
///
/// 大写 H 的两竖顶端向外延伸出两片极简羽翼（三道渐短斜线），传达
/// "信使之翼"。纯矢量 CustomPainter 绘制，无位图依赖；默认取当前主题
/// accent 着色，单色场景可传入 color（如纯白负形）。
library;

import 'package:flutter/material.dart';

import '../../theme/hermes_tokens.dart';

class HermesLogo extends StatelessWidget {
  final double size;

  /// 着色；null 时取当前主题 accent。
  final Color? color;

  const HermesLogo({super.key, this.size = 32, this.color});

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? HermesPalette.of(context).accent;
    return CustomPaint(
      size: Size.square(size),
      painter: _WingHPainter(resolved),
    );
  }
}

class _WingHPainter extends CustomPainter {
  final Color color;
  const _WingHPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round;

    // H 主干：两竖 + 横梁
    final leftX = w * 0.34;
    final rightX = w * 0.66;
    final topY = h * 0.30;
    final bottomY = h * 0.82;
    canvas
      ..drawLine(Offset(leftX, topY), Offset(leftX, bottomY), paint)
      ..drawLine(Offset(rightX, topY), Offset(rightX, bottomY), paint)
      ..drawLine(Offset(leftX, h * 0.56), Offset(rightX, h * 0.56), paint);

    // 羽翼：每侧三道渐短斜线，从竖杆顶端向外上方展开
    final wingPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final t = i / 2; // 0, 0.5, 1
      wingPaint.strokeWidth = w * (0.075 - 0.015 * i);
      final reach = w * (0.16 - 0.045 * i);
      final lift = h * (0.16 - 0.045 * i);
      final rootY = topY + h * 0.02 * i;
      // 左翼（向左上）
      canvas.drawLine(
        Offset(leftX, rootY),
        Offset(leftX - reach, rootY - lift - h * 0.02 * t),
        wingPaint,
      );
      // 右翼（向右上）
      canvas.drawLine(
        Offset(rightX, rootY),
        Offset(rightX + reach, rootY - lift - h * 0.02 * t),
        wingPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_WingHPainter oldDelegate) => oldDelegate.color != color;
}
