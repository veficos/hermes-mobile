import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/widgets/mobile/hermes_mobile_surfaces.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('bot avatar and text align at narrow width scale=$scale', (
      tester,
    ) async {
      const avatar = ValueKey('avatar');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: SizedBox(
                  width: 320,
                  child: HermesMobileRow(
                    title: 'Bot name',
                    subtitle:
                        'A longer description that wraps onto multiple lines.',
                    icon: Icons.smart_toy,
                    alignLeadingToTop: true,
                    leadingSize: 44,
                    iconWidget: const SizedBox(
                      key: avatar,
                      width: 44,
                      height: 44,
                    ),
                    trailing: IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.more_horiz),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(avatar)).dy,
        tester.getTopLeft(find.text('Bot name')).dy,
      );
      expect(tester.getSize(find.byKey(avatar)), const Size(44, 44));
      expect(tester.takeException(), isNull);
    });
  }
}
