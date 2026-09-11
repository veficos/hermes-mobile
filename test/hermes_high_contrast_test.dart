import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_tokens.dart';
import 'package:hermes_mobile/widgets/h/hermes_badge.dart';
import 'package:hermes_mobile/widgets/h/hermes_progress.dart';
import 'package:hermes_mobile/widgets/h/hermes_states.dart';
import 'package:hermes_mobile/widgets/h/hermes_status.dart';

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  bool highContrast = false,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildHermesTheme(
      brightness: brightness,
      highContrast: highContrast,
    ),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  group('HermesA11y theme extension', () {
    test('registered with flag by buildHermesTheme', () {
      final normal = buildHermesTheme(brightness: Brightness.light);
      final hc = buildHermesTheme(
        brightness: Brightness.light,
        highContrast: true,
      );
      expect(normal.extension<HermesA11y>()?.highContrast, isFalse);
      expect(hc.extension<HermesA11y>()?.highContrast, isTrue);
    });

    test('high contrast keeps existing text/border treatment', () {
      final hc = buildHermesTheme(
        brightness: Brightness.light,
        highContrast: true,
      );
      expect(hc.colorScheme.onSurface, const Color(0xFF000000));
      expect(hc.cardTheme.shape, isA<RoundedRectangleBorder>());
      final side =
          (hc.cardTheme.shape! as RoundedRectangleBorder).side;
      expect(side.width, 1.5);
    });
  });

  group('hermesTintAlpha', () {
    testWidgets('identity without high contrast', (tester) async {
      late double resolved;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              resolved = hermesTintAlpha(context, 0.10);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, 0.10);
    });

    testWidgets('boosts 1.8x and caps at 0.6 under high contrast', (
      tester,
    ) async {
      late double low;
      late double high;
      await tester.pumpWidget(
        _wrap(
          highContrast: true,
          Builder(
            builder: (context) {
              low = hermesTintAlpha(context, 0.10);
              high = hermesTintAlpha(context, 0.36);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(low, closeTo(0.18, 1e-9));
      expect(high, closeTo(0.6, 1e-9));
    });
  });

  group('hermesContrastForeground', () {
    test('picks the higher-contrast black/white foreground', () {
      // 深色语义红：白字仅 ~2.9:1，黑字 ~7.2:1。
      expect(
        hermesContrastForeground(HermesSemanticDark.red),
        Colors.black,
      );
      // 浅色语义蓝：白字对比度更高。
      expect(hermesContrastForeground(HermesSemantic.blue), Colors.white);
      expect(hermesContrastForeground(Colors.white), Colors.black);
    });
  });

  group('HermesSkeletonBlock high contrast', () {
    Future<BoxDecoration> outerDecoration(
      WidgetTester tester, {
      bool highContrast = false,
    }) async {
      await tester.pumpWidget(
        _wrap(
          const HermesSkeletonBlock(width: 100, height: 14),
          highContrast: highContrast,
          disableAnimations: true,
        ),
      );
      // MaterialApp 主题切换有 200ms 动画，推进到 lerp 结束再读值。
      await tester.pump(const Duration(milliseconds: 300));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HermesSkeletonBlock),
              matching: find.byType(Container),
            )
            .first,
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('normal mode keeps 1px border', (tester) async {
      final deco = await outerDecoration(tester);
      final side = (deco.border! as Border).top;
      expect(side.color, HermesAccents.graphite.lightPalette.border);
      expect(side.width, 1);
    });

    testWidgets('high contrast upgrades border to borderStrong 1.5px', (
      tester,
    ) async {
      final deco = await outerDecoration(tester, highContrast: true);
      final side = (deco.border! as Border).top;
      expect(side.color, HermesAccents.graphite.lightPalette.borderStrong);
      expect(side.width, 1.5);
    });

    testWidgets('high contrast raises breathing overlay alpha', (tester) async {
      Future<double> overlayAlpha(bool highContrast) async {
        await tester.pumpWidget(
          _wrap(
            const HermesSkeletonBlock(width: 100, height: 14),
            highContrast: highContrast,
            disableAnimations: true, // t = 1.0，alpha = baseAlpha
          ),
        );
        // MaterialApp 主题切换有 200ms 动画，推进到 lerp 结束再读值。
        await tester.pump(const Duration(milliseconds: 300));
        final inner = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(HermesSkeletonBlock),
                matching: find.byType(Container),
              )
              .last,
        );
        return (inner.decoration! as BoxDecoration).color!.a;
      }

      final normal = await overlayAlpha(false);
      final hc = await overlayAlpha(true);
      expect(normal, closeTo(0.06, 1e-6));
      expect(hc, greaterThan(normal));
      expect(hc, closeTo(0.108, 1e-6));
    });
  });

  group('HermesProgressBar high contrast', () {
    Future<Color> trackColor(WidgetTester tester, bool highContrast) async {
      await tester.pumpWidget(
        _wrap(const HermesProgressBar(value: 0.5), highContrast: highContrast),
      );
      // MaterialApp 主题切换有 200ms 动画，推进到 lerp 结束再读值。
      await tester.pump(const Duration(milliseconds: 300));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HermesProgressBar),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color!;
    }

    testWidgets('track uses border normally, borderStrong in high contrast', (
      tester,
    ) async {
      expect(
        await trackColor(tester, false),
        HermesAccents.graphite.lightPalette.border,
      );
      expect(
        await trackColor(tester, true),
        HermesAccents.graphite.lightPalette.borderStrong,
      );
    });
  });

  group('HermesBadge high contrast', () {
    Future<Color> badgeTextColor(
      WidgetTester tester, {
      required Brightness brightness,
      required bool highContrast,
    }) async {
      await tester.pumpWidget(
        _wrap(
          const HermesBadge(count: 3),
          brightness: brightness,
          highContrast: highContrast,
        ),
      );
      final text = tester.widget<Text>(find.text('3'));
      return text.style!.color!;
    }

    testWidgets('normal mode badge text meets reading contrast', (tester) async {
      final foreground = await badgeTextColor(
        tester,
        brightness: Brightness.light,
        highContrast: false,
      );
      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(HermesBadge),
          matching: find.byType(Container),
        ),
      );
      final background = (container.decoration! as BoxDecoration).color!;
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      expect(
        ((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
        greaterThanOrEqualTo(4.5),
      );
    });

    testWidgets('dark-mode semantic red gets black text in high contrast', (
      tester,
    ) async {
      // 深色红 #F26D6D 上白字不足 3:1；高对比切换到黑字（~7:1）。
      expect(
        await badgeTextColor(
          tester,
          brightness: Brightness.dark,
          highContrast: true,
        ),
        Colors.black,
      );
    });
  });

  group('HermesStatusChip high contrast', () {
    Future<double> chipBgAlpha(WidgetTester tester, bool highContrast) async {
      await tester.pumpWidget(
        _wrap(
          const HermesStatusChip(color: HermesSemantic.green, label: '运行中'),
          highContrast: highContrast,
        ),
      );
      // MaterialApp 主题切换有 200ms 动画，推进到 lerp 结束再读值。
      await tester.pump(const Duration(milliseconds: 300));
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HermesStatusChip),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).color!.a;
    }

    testWidgets('semantic tint bg is boosted under high contrast', (
      tester,
    ) async {
      expect(await chipBgAlpha(tester, false), closeTo(0.10, 1e-6));
      expect(await chipBgAlpha(tester, true), closeTo(0.18, 1e-6));
    });
  });

  group('HermesEmptyState API', () {
    testWidgets('defaults to 64px text4 icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const HermesEmptyState(icon: Icons.inbox, title: '空')),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.inbox));
      expect(icon.size, 64);
      expect(icon.color, HermesAccents.graphite.lightPalette.text4);
    });

    testWidgets('supports custom iconSize / iconColor / actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const HermesEmptyState(
            icon: Icons.psychology_alt_outlined,
            title: '开始对话',
            iconSize: 56,
            iconColor: HermesSemantic.purple,
            actions: Text('starter-chips'),
          ),
        ),
      );
      final icon = tester.widget<Icon>(
        find.byIcon(Icons.psychology_alt_outlined),
      );
      expect(icon.size, 56);
      expect(icon.color, HermesSemantic.purple);
      expect(find.text('starter-chips'), findsOneWidget);
    });

    testWidgets('primary and secondary actions still render', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        _wrap(
          HermesEmptyState(
            icon: Icons.inbox,
            title: '空',
            primaryLabel: '刷新',
            onPrimary: () => tapped++,
            secondaryLabel: '返回',
            onSecondary: () => tapped += 10,
          ),
        ),
      );
      await tester.tap(find.text('刷新'));
      await tester.tap(find.text('返回'));
      expect(tapped, 11);
    });
  });
}
