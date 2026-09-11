import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes_mobile/widgets/bot_avatar.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/bot_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/connections/connection_registry.dart';
import 'package:hermes_mobile/screens/bot_avatar_editor_screen.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'support/review_capture.dart';

class _Bots extends BotStore {
  _Bots(super.connection);
  Completer<void>? pendingSave;
  int saves = 0;
  Color? savedColor;
  @override
  Future<void> updateBotAppearance(
    BotIdentity bot, {
    String? shape,
    Color? color,
  }) async {
    saves++;
    await pendingSave?.future;
    savedColor = color;
  }

  @override
  Future<bool> probeImageGeneration(BotIdentity bot) async => true;
}

class _Picker extends ImagePickerPlatform {
  final result = Completer<XFile?>();
  int calls = 0;
  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) {
    calls++;
    return result.future;
  }
}

class _LargeFile extends XFile {
  _LargeFile() : super('blob:avatar-test');
  @override
  Future<int> length() async => 15000001;
}

void main() {
  for (final brightness in Brightness.values) {
    for (final outcome in ['cancel', 'oversize', 'failure', 'save', 'retry']) {
      testWidgets(
        'avatar picker restores controls after $outcome $brightness',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final original = ImagePickerPlatform.instance;
          final picker = _Picker();
          ImagePickerPlatform.instance = picker;
          addTearDown(() => ImagePickerPlatform.instance = original);
          final connection = ConnectionStore();
          final bots = _Bots(connection);
          addTearDown(bots.dispose);
          addTearDown(connection.dispose);
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(
            ChangeNotifierProvider<BotStore>.value(
              value: bots,
              child: MaterialApp(
                theme: buildHermesTheme(
                  brightness: brightness,
                  visualStyle: HermesVisualStyle.liquid,
                ),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(2)),
                  child: RepaintBoundary(
                    key: const ValueKey('avatar-review'),
                    child: child!,
                  ),
                ),
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Builder(
                  builder: (context) => Scaffold(
                    body: TextButton(
                      child: const Text('Open editor'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => BotAvatarEditorScreen(
                            bot: BotIdentity(
                              route: OwnerRoute(
                                connectionId:
                                    ConnectionStore.primaryConnectionId,
                              ),
                              profile: 'review',
                              displayName: 'Review',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Open editor'));
          await tester.pumpAndSettle();
          expect(
            find.widgetWithText(FilledButton, 'Save').hitTestable(),
            findsOneWidget,
          );
          final prompt = find.byType(TextField);
          await tester.ensureVisible(prompt);
          await tester.tap(prompt);
          await tester.enterText(prompt, 'A calm blue assistant');
          tester.view.viewInsets = const FakeViewPadding(bottom: 300);
          await tester.pumpAndSettle();
          await tester.ensureVisible(prompt);
          await tester.pumpAndSettle();
          final saveRect = tester.getRect(
            find.widgetWithText(FilledButton, 'Save'),
          );
          expect(saveRect.bottom, lessThanOrEqualTo(544));
          expect(
            find.widgetWithText(FilledButton, 'Save').hitTestable(),
            findsOneWidget,
          );
          expect(
            tester.getRect(prompt).bottom,
            lessThanOrEqualTo(saveRect.top),
          );
          tester.view.resetViewInsets();
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final optionsScroll = find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first;
          tester.state<ScrollableState>(optionsScroll).position.jumpTo(0);
          await tester.pumpAndSettle();
          const reviewDir = String.fromEnvironment('UI_REVIEW_DIR');
          if (reviewDir.isNotEmpty && outcome == 'cancel') {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await captureReview(
              tester,
              find.byKey(const ValueKey('avatar-review')),
              '$reviewDir/avatar-editor-${brightness.name}-320-2x.png',
            );
          }
          final upload = find.widgetWithIcon(
            TextButton,
            Icons.photo_camera_outlined,
          );
          await tester.ensureVisible(upload);
          await tester.pumpAndSettle();
          await tester.tap(upload);
          await tester.pump();
          expect(tester.widget<TextButton>(upload).onPressed, isNull);
          expect(picker.calls, 1);
          await tester.tap(find.byTooltip('Back'));
          await tester.pump();
          expect(find.byType(BotAvatarEditorScreen), findsOneWidget);
          expect(find.text('Discard unsaved changes?'), findsNothing);
          if (outcome == 'failure') {
            picker.result.completeError(StateError('picker unavailable'));
          } else {
            picker.result.complete(outcome == 'oversize' ? _LargeFile() : null);
          }
          await tester.pumpAndSettle();
          expect(tester.widget<TextButton>(upload).onPressed, isNotNull);
          final colors = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ColorSwatch',
          );
          final colorButton = find.descendant(
            of: colors.at(2),
            matching: find.byType(TextButton),
          );
          await tester.ensureVisible(colorButton);
          await tester.pumpAndSettle();
          expect(
            tester.getSize(colorButton).shortestSide,
            greaterThanOrEqualTo(44),
          );
          final content = find
              .descendant(of: colorButton, matching: find.byType(Container))
              .first;
          Focus.of(tester.element(content)).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          final selectedColor = find.descendant(
            of: colors.at(2),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.selected == true,
            ),
          );
          expect(selectedColor, findsOneWidget);
          tester.state<ScrollableState>(optionsScroll).position.jumpTo(0);
          await tester.pumpAndSettle();
          final preview = tester
              .widgetList<BotAvatar>(find.byType(BotAvatar))
              .firstWhere((avatar) => avatar.size == 96);
          expect(preview.metadata!['color'], '#ef4444');
          expect(
            find.widgetWithText(FilledButton, 'Save').hitTestable(),
            findsOneWidget,
          );
          if (outcome == 'save' || outcome == 'retry') {
            bots.pendingSave = Completer<void>();
            final save = find.widgetWithText(FilledButton, 'Save');
            await tester.ensureVisible(save);
            await tester.tap(save);
            await tester.pump();
            await tester.tap(find.byTooltip('Back'));
            await tester.pump();
            expect(find.byType(BotAvatarEditorScreen), findsOneWidget);
            expect(bots.saves, 1);
            expect(
              tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
              isNull,
            );
            if (outcome == 'retry') {
              bots.pendingSave!.completeError(StateError('write failed'));
              await tester.pumpAndSettle();
              expect(find.byType(BotAvatarEditorScreen), findsOneWidget);
              expect(bots.savedColor, isNull);
              expect(
                tester
                    .widgetList<BotAvatar>(find.byType(BotAvatar))
                    .firstWhere((a) => a.size == 96)
                    .metadata!['color'],
                '#ef4444',
              );
              bots.pendingSave = Completer<void>();
              await tester.ensureVisible(save);
              await tester.tap(save);
              await tester.pump();
            }
            bots.pendingSave!.complete();
            await tester.pumpAndSettle();
            expect(bots.saves, outcome == 'retry' ? 2 : 1);
            expect(bots.savedColor, const Color(0xFFEF4444));
            expect(find.byType(BotAvatarEditorScreen), findsNothing);
            expect(tester.takeException(), isNull);
            return;
          }
          // Select a different shape deterministically; randomize may choose
          // the current appearance again.
          final shapes = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_ShapeSwatch',
          );
          await tester.ensureVisible(shapes.first);
          await tester.tap(shapes.first);
          await tester.pump();
          await tester.ensureVisible(shapes.at(1));
          await tester.tap(shapes.at(1));
          await tester.pump();
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();
          expect(find.byType(BotAvatarEditorScreen), findsOneWidget);
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Discard'));
          await tester.pumpAndSettle();
          expect(find.byType(BotAvatarEditorScreen), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
