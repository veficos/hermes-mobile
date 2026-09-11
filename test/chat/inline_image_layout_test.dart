import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/content/zoomable_markdown_image.dart';
import 'package:hermes_mobile/chat/transcript/anchored_history_list.dart';

class _ControlledImageStream extends ImageStreamCompleter {
  void complete(ui.Image image) => setImage(ImageInfo(image: image));
}

void main() {
  for (final fails in [false, true]) {
    testWidgets('delayed image $fails preserves following history row', (
      tester,
    ) async {
      final uri = Uri.parse('https://image.invalid/delayed-$fails.png');
      final provider = ResizeImage.resizeIfNeeded(
        1600,
        1600,
        NetworkImage(uri.toString()),
      );
      final key = await provider.obtainKey(ImageConfiguration.empty);
      final completer = _ControlledImageStream();
      PaintingBinding.instance.imageCache.putIfAbsent(key, () => completer);
      final controller = ScrollController();
      var imageHeight = 240.0;
      late StateSetter updateMetadata;
      addTearDown(() {
        controller.dispose();
        PaintingBinding.instance.imageCache.evict(key);
      });
      final keys = <Key>[
        const ValueKey('header'),
        const ValueKey('image'),
        for (var i = 0; i < 30; i++) ValueKey('row-$i'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: StatefulBuilder(
                builder: (context, setState) {
                  updateMetadata = setState;
                  return AnchoredHistoryList(
                    controller: controller,
                    keys: keys,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (_, index) => KeyedSubtree(
                      key: keys[index],
                      child: index == 0
                          ? const SizedBox(height: 32, child: Text('History'))
                          : index == 1
                          ? hermesMarkdownImageBuilder(
                              MarkdownImageConfig(
                                uri: uri,
                                width: 304,
                                height: imageHeight,
                              ),
                            )
                          : SizedBox(
                              height: 80,
                              child: Text('Reading row ${index - 2}'),
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final anchor = find.text('Reading row 0');
      await Scrollable.ensureVisible(tester.element(anchor));
      await tester.pumpAndSettle();
      controller.jumpTo(controller.offset + tester.getTopLeft(anchor).dy - 8);
      await tester.pumpAndSettle();
      final top = tester.getTopLeft(anchor).dy;
      expect(top, closeTo(8, .1));
      expect(controller.position.extentBefore, greaterThan(100));
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNull);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.getTopLeft(anchor).dy, top);
      if (fails) {
        completer.reportError(exception: StateError('delayed decode failure'));
      } else {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final decoded = await tester.runAsync(() => picture.toImage(40, 300));
        picture.dispose();
        completer.complete(decoded!);
      }
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.getTopLeft(anchor).dy, closeTo(top, .1));
      }
      if (!fails) {
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      }
      // Late dimensions genuinely resize the mounted image above the reader;
      // decoding alone deliberately preserves its reserved footprint.
      for (final height in [360.0, 120.0]) {
        updateMetadata(() => imageHeight = height);
        for (var frame = 0; frame < 6; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getSize(find.byType(Image)).height, height);
          expect(tester.getTopLeft(anchor).dy, closeTo(top, 2));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('successful image decode keeps the reserved footprint', (
    tester,
  ) async {
    const png =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
    late Size before;
    // Start and await real decoding in the same async zone. Waiting outside
    // the zone that initiated the image stream can strand its callbacks.
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 300,
                child: hermesMarkdownImageBuilder(
                  MarkdownImageConfig(
                    uri: Uri.parse('data:image/png;base64,$png'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      before = tester.getSize(find.byType(Image));
      await precacheImage(
        tester.widget<Image>(find.byType(Image)).image,
        tester.element(find.byType(Image)),
      ).timeout(const Duration(seconds: 10));
    });
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(Image)), before);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
    expect(tester.takeException(), isNull);
  });

  for (final dimensions in [false, true]) {
    testWidgets(
      'image footprint survives decoding failure, dimensions=$dimensions',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 300,
                  child: hermesMarkdownImageBuilder(
                    MarkdownImageConfig(
                      uri: Uri.parse('data:image/png;base64,AAAA'),
                      width: dimensions ? 600 : null,
                      height: dimensions ? 300 : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final image = find.byType(Image);
        final before = tester.getSize(image);
        expect(before.width, 300);
        expect(before.height, dimensions ? 150 : 240);
        await tester.pumpAndSettle();
        expect(tester.getSize(image), before);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
