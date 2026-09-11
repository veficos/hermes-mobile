import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  for (final style in HermesVisualStyle.values) {
    testWidgets(
      'large title drag keeps refresh without viewport stretch $style',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var refreshes = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildHermesTheme(
              brightness: Brightness.light,
              visualStyle: style,
            ).copyWith(platform: TargetPlatform.android),
            home: HermesPageScaffold(
              title: 'Tasks',
              titleMode: HermesPageTitleMode.large,
              body: RefreshIndicator(
                onRefresh: () async {
                  refreshes++;
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 100, child: Text('Task content')),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        expect(find.byType(GlowingOverscrollIndicator), findsNothing);
        await tester.drag(find.byType(ListView), const Offset(0, 450));
        await tester.pumpAndSettle();
        expect(refreshes, 1);
        expect(find.text('Task content').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
