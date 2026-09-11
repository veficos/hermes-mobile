import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Opt-in review artifact, never a golden or an automatic visual acceptance.
Future<void> captureReview(
  WidgetTester tester,
  Finder boundary,
  String path,
) async {
  final render = tester.renderObject<RenderRepaintBoundary>(boundary);
  await tester.runAsync(() async {
    final picture = await render.toImage(pixelRatio: 1);
    try {
      final bytes = (await picture.toByteData(format: ui.ImageByteFormat.png))!;
      await File(path).writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      picture.dispose();
    }
  });
}
