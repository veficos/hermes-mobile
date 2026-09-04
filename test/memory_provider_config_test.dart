import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/profile_scope_store.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations.dart';
import 'package:hermes_mobile/screens/memory_screen.dart';
import 'package:provider/provider.dart';

class _MemoryApi extends ApiClient {
  _MemoryApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  Map<String, Object?>? savedValues;

  @override
  Future<Map<String, dynamic>> memoryStatus({String? profile}) async => {
    'active': 'honcho',
    'providers': <Object>[
      {
        'name': 'honcho',
        'description': 'Memory provider',
        'available': true,
        'configured': true,
        'status': 'ready',
        'setup': {
          'pip_dependencies': <Object>[],
          'external_dependencies': <Object>[],
          'required_env': <Object>[],
          'dependencies_installed': true,
        },
      },
    ],
    'builtin_files': <String, Object>{},
  };

  @override
  Future<Map<String, dynamic>> curatorStatus() async => {'enabled': false};

  @override
  Future<Map<String, dynamic>> memoryProviderConfig(
    String provider, {
    String? profile,
  }) async => {
    'name': 'honcho',
    'label': 'Honcho',
    'fields': <Object>[
      {
        'key': 'environment',
        'label': 'Environment',
        'kind': 'select',
        'value': 'production',
        'options': <Object>[
          {'value': 'production', 'label': 'Cloud'},
          {'value': 'local', 'label': 'Local'},
        ],
      },
      {
        'key': 'baseUrl',
        'label': 'Local base URL',
        'kind': 'text',
        'value': 'http://localhost:8000',
        'when': {'environment': 'local'},
      },
      {'key': 'enabled', 'label': 'Enabled', 'kind': 'bool', 'value': true},
      {'key': 'limit', 'label': 'Limit', 'kind': 'integer', 'value': 12},
      {
        'key': 'aliases',
        'label': 'Aliases',
        'kind': 'json',
        'value': '{"mobile":"user"}',
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> memoryProviderOAuthStatus(
    String provider, {
    String? profile,
  }) => throw ApiException(404, 'OAuth unsupported');

  @override
  Future<Map<String, dynamic>> saveMemoryProviderConfig(
    String provider,
    Map<String, Object?> values, {
    String? profile,
    String? surface,
  }) async {
    savedValues = values;
    return {'ok': true};
  }
}

class _Connection extends ConnectionStore {
  _Connection(ApiClient client) {
    api = client;
  }
}

void main() {
  testWidgets('memory config supports local mode and native field values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final api = _MemoryApi();
    final connection = _Connection(api);
    final scope = ProfileScopeStore();
    addTearDown(connection.dispose);
    addTearDown(scope.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider.value(value: scope),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MemoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Configure honcho').first);
    await tester.pumpAndSettle();
    expect(find.text('Local base URL'), findsNothing);
    expect(find.text('Connect provider account'), findsNothing);

    await tester.tap(find.text('Cloud').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Local').last);
    await tester.pumpAndSettle();
    expect(find.text('Local base URL'), findsOneWidget);

    final save = find.widgetWithText(FilledButton, 'Save configuration');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(api.savedValues, {
      'environment': 'local',
      'baseUrl': 'http://localhost:8000',
      'enabled': true,
      'limit': 12,
      'aliases': {'mobile': 'user'},
    });
  });
}
