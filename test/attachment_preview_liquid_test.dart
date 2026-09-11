import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/h/hermes_composer.dart';
import 'package:hermes_mobile/widgets/glass/glass_button.dart';

void main() {
  for (final accessible in [false, true]) {
    for (final kind in [
      ComposerAttachmentKind.image,
      ComposerAttachmentKind.file,
    ]) {
      testWidgets('unknown upload static accessible=$accessible kind=$kind', (
        tester,
      ) async {
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: HermesVisualStyle.liquid,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: !accessible,
                accessibleNavigation: accessible,
              ),
              child: child!,
            ),
            home: Scaffold(
              body: HermesComposer(
                controller: controller,
                onSend: (_) {},
                attachments: [
                  ComposerAttachment(
                    kind: kind,
                    label: 'upload',
                    uploading: true,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
        expect(
          tester
              .widget<Icon>(find.byIcon(Icons.cloud_upload_outlined))
              .semanticLabel,
          isNotEmpty,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final sent in [-10, 50, 150]) {
    testWidgets('image upload displays bounded progress $sent', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: Brightness.light,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: Scaffold(
            body: HermesComposer(
              controller: controller,
              onSend: (_) {},
              attachments: [
                ComposerAttachment(
                  kind: ComposerAttachmentKind.image,
                  label: 'upload.png',
                  uploading: true,
                  uploadSent: sent,
                  uploadTotal: 100,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        (sent / 100).clamp(0.0, 1.0),
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('upload overlay leaves image removal reachable', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    List<ComposerAttachment>? remaining;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildHermesTheme(
          brightness: Brightness.dark,
          visualStyle: HermesVisualStyle.liquid,
        ),
        home: Scaffold(
          body: HermesComposer(
            controller: controller,
            onSend: (_) {},
            onAttachmentsChanged: (value) => remaining = value,
            attachments: const [
              ComposerAttachment(
                kind: ComposerAttachmentKind.image,
                label: 'upload.png',
                uploading: true,
              ),
            ],
          ),
        ),
      ),
    );
    final card = find.byKey(const ValueKey('composer-attachment-0'));
    final remove = find.descendant(
      of: card,
      matching: find.byType(GlassButton),
    );
    expect(remove.hitTestable(), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(remove);
    await tester.pump();
    expect(remaining, isEmpty);
    expect(find.byType(Dialog), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final reduced in [false, true]) {
    for (final isImage in [false, true]) {
      testWidgets('attachment preview glass toolbar ($reduced, image=$isImage)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final controller = TextEditingController();
        List<ComposerAttachment>? remaining;
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: HermesVisualStyle.liquid,
              reduceTransparency: reduced,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: HermesComposer(
                controller: controller,
                onSend: (_) {},
                onAttachmentsChanged: (value) => remaining = value,
                onModelTap: () {},
                modelLabel: 'model',
                attachments: [
                  ComposerAttachment(
                    label: isImage ? 'image.png' : 'report.txt',
                    kind: isImage
                        ? ComposerAttachmentKind.image
                        : ComposerAttachmentKind.file,
                    bytes: isImage
                        ? base64Decode(
                            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
                          )
                        : null,
                    path: List.filled(40, 'long-directory').join('/'),
                  ),
                ],
              ),
            ),
          ),
        );
        final attachment = find.byKey(const ValueKey('composer-attachment-0'));
        expect(
          tester.widget<InkWell>(attachment).customBorder,
          isA<RoundedSuperellipseBorder>(),
        );
        final contours = tester
            .widgetList<Container>(
              find.descendant(of: attachment, matching: find.byType(Container)),
            )
            .map((widget) => widget.decoration)
            .whereType<ShapeDecoration>();
        final contour = contours.singleWhere(
          (decoration) => decoration.shape is RoundedSuperellipseBorder,
        );
        expect(contour.color!.a, reduced ? 1 : closeTo(.78, .01));
        expect(
          find.descendant(
            of: attachment,
            matching: find.byType(BackdropFilter),
          ),
          findsNothing,
        );
        await tester.tap(attachment);
        await tester.pumpAndSettle();
        final toolbar = find.byKey(
          const ValueKey('attachment-preview-toolbar'),
        );
        expect(toolbar, findsOneWidget);
        final dialog = find.byType(Dialog);
        expect(
          tester.widget<Dialog>(dialog).shape,
          isA<RoundedSuperellipseBorder>(),
        );
        // The entire preview owns a single sampled material. Its nested
        // toolbar shares that plane instead of adding another blur pass.
        expect(
          find.descendant(of: toolbar, matching: find.byType(BackdropFilter)),
          findsNothing,
        );
        expect(
          find.descendant(of: dialog, matching: find.byType(BackdropFilter)),
          reduced ? findsNothing : findsOneWidget,
        );
        final close = find.descendant(
          of: toolbar,
          matching: find.byType(IconButton),
        );
        expect(close.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (isImage) {
          final viewer = find.byType(InteractiveViewer);
          expect(viewer, findsOneWidget);
          expect(tester.widget<InteractiveViewer>(viewer).maxScale, 5);
          expect(
            find.descendant(of: viewer, matching: find.byType(BackdropFilter)),
            findsNothing,
          );
        } else {
          final scroll = find.descendant(
            of: find.byType(Dialog),
            matching: find.byType(SingleChildScrollView),
          );
          await tester.drag(scroll, const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(close.hitTestable(), findsOneWidget);
        await tester.tap(close);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(
          find.byKey(const ValueKey('composer-attachment-0')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        {
          final remove = find.descendant(
            of: attachment,
            matching: find.byType(GlassButton),
          );
          expect(tester.getSize(remove).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(remove).height, greaterThanOrEqualTo(44));
          await tester.tap(remove);
          await tester.pumpAndSettle();
          expect(remaining, isEmpty);
          expect(find.byType(Dialog), findsNothing);
        }
      });
    }
  }
}
