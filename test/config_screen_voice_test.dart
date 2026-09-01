import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/core/stores/chat_store.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:hermes_mobile/core/stores/request_store.dart';
import 'package:hermes_mobile/core/stores/session_store.dart';
import 'package:hermes_mobile/screens/config_screen.dart';
import 'package:provider/provider.dart';

/// Desktop dynamically renders the selected TTS/STT provider's own fields
/// (voice-provider-fields.tsx) — e.g. picking "elevenlabs" reveals a voice
/// ID + model ID field. Mobile's Voice tab previously stopped at the
/// provider dropdown itself; this covers the per-provider fields now shown
/// underneath it.
class _VoiceConfigApi extends ApiClient {
  _VoiceConfigApi({required this.config})
    : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  Map<String, dynamic> config;
  Map<String, dynamic>? lastPatch;

  @override
  Future<ModelCatalog> modelCatalog({bool refresh = false}) async =>
      const ModelCatalog(
        currentProvider: 'nous',
        currentModel: 'hermes-4',
        providers: [
          ModelInfo(
            slug: 'nous',
            name: 'Nous',
            isCurrent: true,
            models: ['hermes-4'],
          ),
        ],
      );

  @override
  Future<Map<String, dynamic>> getConfig({String? profile}) async => config;

  @override
  Future<Map<String, dynamic>> auxiliaryModels({String? profile}) async => {
    'main': {'provider': 'nous', 'model': 'hermes-4'},
    'tasks': <dynamic>[],
  };

  @override
  Future<Map<String, dynamic>> moaModels({String? profile}) async => {
    'default_preset': 'default',
    'active_preset': 'default',
    'presets': <String, dynamic>{},
  };

  @override
  Future<Map<String, dynamic>> recommendedDefaultModel(
    String provider, {
    String? profile,
  }) async => {'provider': provider, 'model': 'hermes-4'};

  @override
  Future<void> putConfig(Map<String, dynamic> patch, {String? profile}) async {
    lastPatch = patch;
  }

  // The Tools & Keys tab (also inside the same eagerly-built TabBarView)
  // fetches this independently of which tab is showing.
  @override
  Future<List<CredentialProvider>> credentialProviders() async => const [];
}

class _DeferredVoiceConfigApi extends _VoiceConfigApi {
  _DeferredVoiceConfigApi({required super.config});

  final save = Completer<void>();

  @override
  Future<void> putConfig(Map<String, dynamic> patch, {String? profile}) async {
    lastPatch = patch;
    await save.future;
  }
}

class _NotifyingConnection extends ConnectionStore {
  void expose(ApiClient api) {
    this.api = api;
    notifyListeners();
  }
}

Future<_VoiceConfigApi> _pumpVoiceTab(
  WidgetTester tester,
  Map<String, dynamic> config,
) async {
  final api = _VoiceConfigApi(config: config);
  final connection = ConnectionStore()..api = api;
  final session = SessionStore(
    connection: connection,
    chat: ChatStore(),
    requests: RequestStore(),
  );
  addTearDown(() {
    session.dispose();
    connection.dispose();
  });
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionStore>.value(value: connection),
        ChangeNotifierProvider<SessionStore>.value(value: session),
      ],
      child: const MaterialApp(home: ConfigScreen()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('语音'));
  await tester.pumpAndSettle();
  return api;
}

void main() {
  testWidgets('shows only the selected TTS provider\'s own fields', (
    tester,
  ) async {
    await _pumpVoiceTab(tester, {
      'tts': {
        'provider': 'elevenlabs',
        'elevenlabs': {'voice_id': 'abc123', 'model_id': 'eleven_v3'},
        'openai': {'model': 'tts-1', 'voice': 'alloy'},
      },
      'stt': {'provider': 'local'},
    });

    expect(find.text('音色 ID'), findsOneWidget);
    expect(find.text('模型 ID'), findsOneWidget);
    // openai is configured in the backend response too, but it isn't the
    // selected provider, so its fields must not appear. ("模型" alone would
    // also match the Model tab's own label, so match the field precisely.)
    expect(find.widgetWithText(TextFormField, '模型'), findsNothing);
  });

  testWidgets('switching the provider swaps which sub-fields are shown', (
    tester,
  ) async {
    await _pumpVoiceTab(tester, {
      'tts': {
        'provider': 'elevenlabs',
        'elevenlabs': {'voice_id': 'abc123', 'model_id': 'eleven_v3'},
        'edge': {'voice': 'en-US-JennyNeural'},
      },
      'stt': {'provider': 'local'},
    });

    expect(find.text('音色 ID'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String>, 'TTS 提供商'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('edge').last);
    await tester.pumpAndSettle();

    expect(find.text('音色 ID'), findsNothing);
    expect(find.text('音色'), findsOneWidget);

    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets('editing a provider sub-field saves the right nested patch', (
    tester,
  ) async {
    final api = await _pumpVoiceTab(tester, {
      'tts': {
        'provider': 'elevenlabs',
        'elevenlabs': {'voice_id': 'abc123', 'model_id': 'eleven_v3'},
      },
      'stt': {'provider': 'local'},
    });

    await tester.enterText(
      find.widgetWithText(TextFormField, '音色 ID'),
      'new-voice',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      api.lastPatch?['tts'],
      containsPair('elevenlabs', containsPair('voice_id', 'new-voice')),
    );

    // Let the success toast's auto-dismiss timer fire before teardown.
    await tester.pump(const Duration(milliseconds: 2500));
  });

  testWidgets(
    'a provider with no field spec (or no matching backend keys) shows nothing extra',
    (tester) async {
      await _pumpVoiceTab(tester, {
        'tts': {'provider': 'openai'}, // no nested openai.* keys reported
        'stt': {'provider': 'local'},
      });

      expect(find.widgetWithText(TextFormField, '模型'), findsNothing);
      expect(find.widgetWithText(TextFormField, '音色'), findsNothing);
    },
  );

  testWidgets('late nested config save cannot overwrite a reconnected server', (
    tester,
  ) async {
    final stale = _DeferredVoiceConfigApi(
      config: {
        'tts': {
          'provider': 'elevenlabs',
          'elevenlabs': {'voice_id': 'old-voice', 'model_id': 'eleven_v3'},
        },
        'stt': {'provider': 'local'},
      },
    );
    final current = _VoiceConfigApi(
      config: {
        'tts': {
          'provider': 'elevenlabs',
          'elevenlabs': {'voice_id': 'current-voice', 'model_id': 'eleven_v3'},
        },
        'stt': {'provider': 'local'},
      },
    );
    final connection = _NotifyingConnection()..expose(stale);
    final session = SessionStore(
      connection: connection,
      chat: ChatStore(),
      requests: RequestStore(),
    );
    addTearDown(() {
      session.dispose();
      connection.dispose();
    });
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ConnectionStore>.value(value: connection),
          ChangeNotifierProvider<SessionStore>.value(value: session),
        ],
        child: const MaterialApp(home: ConfigScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('语音'));
    await tester.pumpAndSettle();

    final field = find.widgetWithText(TextFormField, '音色 ID');
    await tester.enterText(field, 'stale-write');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(stale.lastPatch, isNotNull);

    connection.expose(current);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).initialValue, 'current-voice');

    stale.save.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(field).initialValue, 'current-voice');
  });
}
