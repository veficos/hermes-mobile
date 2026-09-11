import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/chat/transcript/chat_message_list.dart';
import 'package:hermes_mobile/l10n/l10n.dart';

void main() {
  testWidgets('history retry delegates to the viewport-preserving owner', (
    tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HistoryHeader(
            loadingHistory: false,
            hasMoreHistory: true,
            historyError: 'offline',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('history-retry')));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
