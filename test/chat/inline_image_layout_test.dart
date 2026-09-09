import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/zoomable_markdown_image.dart';

void main() {
  testWidgets('successful image decode keeps the reserved footprint', (tester) async {
    const png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, child: hermesMarkdownImageBuilder(
        MarkdownImageConfig(uri: Uri.parse('data:image/png;base64,$png')),
      )),
    ))));
    final before = tester.getSize(find.byType(Image));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Image)), before);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final dimensions in [false, true]) {
    testWidgets('image footprint survives decoding failure, dimensions=$dimensions', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 300, child: hermesMarkdownImageBuilder(
          MarkdownImageConfig(
            uri: Uri.parse('data:image/png;base64,AAAA'),
            width: dimensions ? 600 : null,
            height: dimensions ? 300 : null,
          ),
        )),
      ))));
      final image = find.byType(Image);
      final before = tester.getSize(image);
      expect(before.width, 300);
      expect(before.height, dimensions ? 150 : 240);
      await tester.pumpAndSettle();
      expect(tester.getSize(image), before);
      expect(tester.takeException(), isNull);
    });
  }
}
