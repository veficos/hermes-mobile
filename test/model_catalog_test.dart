import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/model_catalog.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingApi extends ApiClient {
  _RecordingApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  String? path;
  Map<String, String>? query;

  @override
  Future<dynamic> get(String path, {Map<String, String>? query, Duration? timeout}) async {
    this.path = path;
    this.query = query;
    return {
      'current': {'provider': 'zeta', 'model': 'hidden-current'},
      'providers': [
        {
          'slug': 'zeta',
          'name': 'Alpha display',
          'models': ['hidden-current', 'visible'],
        },
      ],
    };
  }
}

const _providers = [
  ModelInfo(
    slug: 'zeta',
    name: 'Alpha display',
    isCurrent: true,
    models: ['hidden-current', 'visible'],
  ),
  ModelInfo(
    slug: 'beta',
    name: 'Zulu display',
    isCurrent: false,
    models: ['beta-model'],
  ),
  ModelInfo(
    slug: 'MoA',
    name: 'Mixture of Agents',
    isCurrent: false,
    models: ['fast', 'deep'],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('modelCatalog refresh requests the refresh query once', () async {
    final api = _RecordingApi();

    final catalog = await api.modelCatalog(refresh: true);

    expect(api.path, '/api/v1/model');
    expect(api.query, {'refresh': 'true'});
    expect(catalog.currentProvider, 'zeta');
    expect(catalog.currentModel, 'hidden-current');
    expect(catalog.providers, hasLength(1));
  });

  test(
    'projection separates MoA and sorts normal providers by display name',
    () {
      const catalog = ModelCatalog(
        currentProvider: 'zeta',
        currentModel: 'hidden-current',
        providers: _providers,
      );

      final projection = catalog.project(visibleModelKeys: {'zeta::visible'});

      expect(projection.providers.map((provider) => provider.slug), [
        'zeta',
        'beta',
      ]);
      expect(projection.providers.first.models, ['hidden-current', 'visible']);
      expect(projection.moaProviders, hasLength(1));
      expect(projection.moaProviders.single.models, isEmpty);
    },
  );

  test(
    'visibility defaults to all and persists provider::model keys',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final store = ModelVisibilityStore(preferences);

      expect(store.visibleKeys(_providers), {
        'zeta::hidden-current',
        'zeta::visible',
        'beta::beta-model',
        'MoA::fast',
        'MoA::deep',
      });

      await store.save({'beta::beta-model', 'MoA::deep'});

      final reloaded = ModelVisibilityStore(preferences);
      expect(reloaded.visibleKeys(_providers), {
        'beta::beta-model',
        'MoA::deep',
      });
    },
  );
}
