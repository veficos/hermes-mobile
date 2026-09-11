import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/theme/hermes_theme.dart';
import 'package:hermes_mobile/theme/hermes_glass_theme.dart';
import 'package:hermes_mobile/widgets/mobile/mobile_page_scaffold.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('separate glass header clips scrolling body $brightness', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildHermesTheme(
            brightness: brightness,
            visualStyle: HermesVisualStyle.liquid,
          ),
          home: HermesPageScaffold(
            title: 'Header',
            titleMode: HermesPageTitleMode.large,
            scrollBodyBehindHeader: true,
            separateHeader: true,
            body: ListView.builder(
              itemCount: 60,
              itemBuilder: (_, i) =>
                  SizedBox(height: 64, child: Text('row $i')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = tester.getRect(find.byType(AppBar));
      final list = find.byType(ListView);
      expect(tester.getRect(list).top, greaterThanOrEqualTo(header.bottom));
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(tester.getRect(list).top, greaterThanOrEqualTo(header.bottom));
      expect(find.byType(NestedScrollView), findsNothing);
      expect(find.byType(StretchingOverscrollIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
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
