import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hermes_mobile/core/stores/appearance_store.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('hermes.accessibility');
  testWidgets(
    'native updates rebuild the visible material and preserve local override',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      final store = AppearanceStore();
      Future<void> system(bool value) async {
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            MethodCall('reduceTransparencyChanged', value),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      try {
        await tester.pumpWidget(
          ListenableBuilder(
            listenable: store,
            builder: (context, _) => MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.light,
                visualStyle: HermesVisualStyle.liquid,
                reduceTransparency: store.effectiveReduceTransparency,
              ),
              home: const Scaffold(
                body: Center(
                  child: GlassSurface(
                    child: SizedBox(
                      width: 160,
                      height: 100,
                      child: Text('Readable content'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(BackdropFilter), findsOneWidget);
        await system(true);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('Readable content'), findsOneWidget);
        await system(false);
        expect(find.byType(BackdropFilter), findsOneWidget);
        await store.setReduceTransparency(true);
        await tester.pumpAndSettle();
        await system(true);
        await system(false);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(store.reduceTransparency, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        store.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
  testWidgets('new system event wins over delayed startup snapshot', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final snapshot = Completer<bool>();
    messenger.setMockMethodCallHandler(channel, (_) => snapshot.future);
    final store = AppearanceStore();
    try {
      await tester.pump();
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('reduceTransparencyChanged', true),
        ),
        (_) {},
      );
      snapshot.complete(false);
      await tester.pump();
      expect(store.effectiveReduceTransparency, isTrue);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('reduceTransparencyChanged', null),
        ),
        (_) {},
      );
      expect(store.effectiveReduceTransparency, isTrue);
    } finally {
      store.dispose();
      messenger.setMockMethodCallHandler(channel, null);
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets(
    'system transparency overrides without persisting user preference',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      SharedPreferences.setMockInitialValues({});
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => true);
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        messenger.setMockMethodCallHandler(channel, null);
      });
      final store = AppearanceStore();
      await store.load();
      await tester.pump();
      expect(store.effectiveReduceTransparency, isTrue);
      expect(store.reduceTransparency, isFalse);
      await store.setReduceTransparency(false);
      expect(store.effectiveReduceTransparency, isTrue);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('reduceTransparencyChanged', false),
        ),
        (_) {},
      );
      expect(store.effectiveReduceTransparency, isFalse);
      await store.setReduceTransparency(true);
      expect(store.effectiveReduceTransparency, isTrue);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'hm_reduce_transparency',
        ),
        isTrue,
      );
      store.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
