import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/clipboard.dart';
import 'package:hermes_mobile/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final channel = SystemChannels.platform;

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('clipboard failure never reports a false success', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'clipboard-denied');
          }
          return null;
        });

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => copyTextOrNotify(
                context,
                'content',
                successMessage: 'Copied',
              ),
              child: const Text('Copy'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(find.text('Could not copy to the clipboard'), findsOneWidget);
    expect(find.text('Copied'), findsNothing);
  });
}
