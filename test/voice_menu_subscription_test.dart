import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/voice_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/widgets/h/hermes_voice_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Voice extends VoiceStore {
  _Voice(ConnectionStore connection) : super(connection: connection);
  double level = 0;
  @override
  double get inputLevel => level;
  void setLevel(double value) {
    level = value;
    notifyListeners();
  }
}

void main() {
  testWidgets('voice level updates without rebuilding its parent', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final connection = ConnectionStore();
    final voice = _Voice(connection);
    addTearDown(voice.dispose);
    addTearDown(connection.dispose);
    var builds = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (_) {
              builds++;
              return HermesVoiceMenu(
                voice: voice,
                onDictate: () {},
                onToggleContinuous: () {},
                onToggleAutoSpeak: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final before = builds;
    voice.setLevel(.7);
    await tester.pump();
    expect(builds, before);
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      .7,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
