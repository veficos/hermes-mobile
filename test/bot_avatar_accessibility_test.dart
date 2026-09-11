import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/widgets/bot_avatar.dart';

Widget host({bool reduce = false, bool accessible = false, String? image}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(
          disableAnimations: reduce,
          accessibleNavigation: accessible,
        ),
        child: Center(
          child: BotAvatar(
            name: 'Worker',
            working: true,
            size: 44,
            metadata: image == null ? null : {'image': image},
          ),
        ),
      ),
    );

void main() {
  testWidgets(
    'avatar recovers from invalid image and restores procedural animation',
    (tester) async {
      late String portrait;
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 20, 80),
          Paint()..color = Colors.blue,
        );
        final picture = recorder.endRecording();
        final decoded = await picture.toImage(20, 80);
        final data = (await decoded.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        portrait =
            'data:image/png;base64,${base64Encode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes))}';
        decoded.dispose();
        picture.dispose();
      });
      await tester.pumpWidget(host(image: 'data:image/png;base64,AQID'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bot-avatar-fallback')), findsOneWidget);
      await tester.pumpWidget(host(image: portrait));
      // Let both the real codec and fake-clock frame scheduler advance.
      // Awaiting precache alone can deadlock a pending web image frame.
      for (var frame = 0; frame < 100; frame++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        });
        await tester.pump(const Duration(milliseconds: 16));
        final images = tester.widgetList<RawImage>(find.byType(RawImage));
        if (images.any((image) => image.image != null)) break;
      }
      expect(
        find.byType(RawImage),
        findsOneWidget,
        reason:
            'the replacement portrait must decode within the bounded frame loop',
      );
      final raw = tester.widget<RawImage>(find.byType(RawImage));
      expect(raw.image, isNotNull);
      expect(raw.image!.width, 20);
      expect(raw.image!.height, 80);
      expect(raw.fit, BoxFit.cover);
      expect(find.byKey(const ValueKey('bot-avatar-fallback')), findsNothing);
      expect(tester.getSize(find.byType(BotAvatar)), const Size(44, 44));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('bot-avatar-fallback')), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(tester.getSize(find.byType(BotAvatar)), const Size(44, 44));
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
  for (final accessible in [false, true]) {
    testWidgets('avatar stops and resumes with accessibility $accessible', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(
        host(reduce: !accessible, accessible: accessible),
      );
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      // A second cycle catches SingleTickerProvider lifecycle mistakes.
      await tester.pumpWidget(host(reduce: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(host());
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  }

  testWidgets('undecodable image keeps a fixed-size fallback', (tester) async {
    await tester.pumpWidget(host(image: 'data:image/png;base64,AQID'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bot-avatar-fallback')), findsOneWidget);
    expect(tester.getSize(find.byType(BotAvatar)), const Size(44, 44));
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });
}
