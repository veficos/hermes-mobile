import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/about_screen.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/glass/glass_alert_dialog.dart';
import 'package:hermes_mobile/core/performance_metrics.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final locale in [
      const Locale('en'),
      const Locale('zh'),
      const Locale('ar'),
    ]) {
      testWidgets('performance snapshot scroll and close $style $locale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            theme: buildHermesTheme(
              brightness: Brightness.dark,
              visualStyle: style,
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const AboutScreen(),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(SliverAppBar),
          style == HermesVisualStyle.liquid ? findsOneWidget : findsNothing,
        );
        expect(find.byType(ListView), findsNothing);
        final title = AppLocalizations.of(
          tester.element(find.byType(AboutScreen)),
        ).clientPerformanceTitle;
        await tester.scrollUntilVisible(
          find.text(title),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsOneWidget);
        expect(
          find.byType(AlertDialog),
          style == HermesVisualStyle.classic ? findsOneWidget : findsNothing,
        );
        final l10n = AppLocalizations.of(
          tester.element(find.byType(GlassAlertDialog)),
        );
        expect(find.text(l10n.commonClose).hitTestable(), findsOneWidget);
        expect(find.text(l10n.commonCopy).hitTestable(), findsOneWidget);
        expect(find.byType(SelectableText), findsOneWidget);
        String? copied;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final shown = tester
            .widget<SelectableText>(find.byType(SelectableText))
            .data!;
        final framesBeforeCopy = ClientPerformanceMetrics.instance.frames;
        await tester.tap(find.text(l10n.commonCopy));
        await tester.pumpAndSettle();
        expect(copied, shown);
        final render = (jsonDecode(copied!) as Map)['render'] as Map;
        expect(render['frame_samples_available'], isA<bool>());
        expect(render, contains('interval_slow_frame_ratio'));
        expect(ClientPerformanceMetrics.instance.frames, framesBeforeCopy);
        expect(find.byType(GlassAlertDialog), findsOneWidget);
        await tester.tap(find.text(l10n.commonClose));
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsNothing);
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
        final metrics = ClientPerformanceMetrics.instance;
        metrics.recordFrame(
          buildMicros: 20000,
          rasterMicros: 1000,
          refreshRate: 60,
        );
        final lifetime = metrics.frames;
        final reset = find.byKey(const ValueKey('performance-reset-frames'));
        expect(reset.hitTestable(), findsOneWidget);
        await tester.tap(reset);
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlertDialog), findsNothing);
        expect(metrics.frames, lifetime);
        expect(metrics.buildDurations.length, 0);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
