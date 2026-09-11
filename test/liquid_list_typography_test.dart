import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_adaptive_ui.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    for (final width in [320.0, 390.0, 600.0, 1280.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('directory typography $style $width $scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          var taps = 0;
          const title = '机器人与自动化工作流程配置管理';
          const subtitle = 'Configure agents and automated workflows';
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHermesTheme(
                brightness: Brightness.light,
                visualStyle: style,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: HermesListRow(
                    icon: Icons.settings,
                    title: title,
                    subtitle: subtitle,
                    onTap: () => taps++,
                  ),
                ),
              ),
            ),
          );
          final phone = style == HermesVisualStyle.liquid && width < 600;
          final titleWidget = tester.widget<Text>(find.text(title));
          expect(titleWidget.style!.fontSize, phone ? 17 : 15);
          expect(
            tester.widget<Text>(find.text(subtitle)).style!.fontSize,
            phone ? 14 : 13,
          );
          expect(titleWidget.maxLines, phone || scale == 2 ? null : 1);
          expect(
            tester.getSize(find.byType(HermesListRow)).height,
            greaterThanOrEqualTo(54),
          );
          await tester.tap(find.text(title));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
