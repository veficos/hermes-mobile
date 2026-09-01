import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/insights_screen.dart';
import 'package:provider/provider.dart';

class _InsightsApi extends ApiClient {
  _InsightsApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String?>? query,
    Duration? timeout,
  }) async => {
    'totals': <String, dynamic>{
      'total_input': 1200,
      'total_output': 500,
      'total_cache_read': 200,
      'total_sessions': 12,
      'total_api_calls': 36,
      'total_estimated_cost': 1.25,
    },
    'daily': <dynamic>[
      {'day': '2026-08-30', 'input_tokens': 100, 'output_tokens': 50},
      {'day': '2026-08-31', 'input_tokens': 200, 'output_tokens': 75},
    ],
    'by_model': <dynamic>[
      {
        'model': 'a-very-long-model-name-for-narrow-layout',
        'billing_provider': 'provider-with-a-long-name',
        'input_tokens': 1200,
        'output_tokens': 500,
        'estimated_cost': 1.25,
        'sessions': 12,
      },
    ],
    'tools': <dynamic>[
      {'tool': 'a_very_long_tool_name', 'count': 42},
    ],
  };
}

void main() {
  testWidgets('non-empty insights render at 320px Arabic RTL and 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final connection = ConnectionStore()..api = _InsightsApi();
    addTearDown(connection.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider<ConnectionStore>.value(
        value: connection,
        child: MaterialApp(
          locale: const Locale('ar'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const InsightsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final model = find.text('a-very-long-model-name-for-narrow-layout');
    await tester.scrollUntilVisible(model, 200);
    expect(model, findsOneWidget);
    expect(tester.takeException(), isNull);

    final tool = find.text('a_very_long_tool_name');
    await tester.scrollUntilVisible(tool, 200);
    expect(tool, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
