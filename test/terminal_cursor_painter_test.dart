import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/terminal/terminal_visuals.dart';
import 'package:xterm/src/ui/painter.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('line cursors preserve the terminal row offset', () async {
    for (final type in [
      TerminalCursorType.verticalBar,
      TerminalCursorType.underline,
    ]) {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final painter = TerminalPainter(
        theme: HermesTerminalVisuals.terminalTheme(
          Brightness.dark,
          Colors.blue,
        ),
        textStyle: const TerminalStyle(fontSize: 15, height: 1.42),
        textScaler: TextScaler.noScaling,
      );

      painter.paintCursor(canvas, const Offset(10, 24), cursorType: type);
      final image = await recorder.endRecording().toImage(80, 80);
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);

      int alphaAt(int x, int y) => bytes!.getUint8((y * 80 + x) * 4 + 3);
      expect(alphaAt(10, 0), 0, reason: '$type must not paint on row zero');
      final paintedAtTargetRow = Iterable<int>.generate(
        30,
        (i) => 24 + i,
      ).where((y) => y < 80).any((y) => alphaAt(10, y) > 0);
      expect(paintedAtTargetRow, isTrue, reason: '$type must use offset.dy');
    }
  });
}
