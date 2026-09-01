import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class ModelCatalog {
  final String? currentProvider;
  final String? currentModel;
  final List<ModelInfo> providers;

  const ModelCatalog({
    required this.currentProvider,
    required this.currentModel,
    required this.providers,
  });

  factory ModelCatalog.fromJson(Map<String, dynamic> json) {
    final current = (json['current'] as Map?)?.cast<String, dynamic>();
    return ModelCatalog(
      currentProvider: current?['provider']?.toString(),
      currentModel: current?['model']?.toString(),
      providers: (json['providers'] as List? ?? const [])
          .map(
            (value) =>
                ModelInfo.fromJson((value as Map).cast<String, dynamic>()),
          )
          .toList(growable: false),
    );
  }

  ModelCatalog copyWithCurrent({
    required String currentProvider,
    required String currentModel,
  }) {
    return ModelCatalog(
      currentProvider: currentProvider,
      currentModel: currentModel,
      providers: providers,
    );
  }

  ModelCatalogProjection project({Set<String>? visibleModelKeys}) {
    List<ModelInfo> filter(Iterable<ModelInfo> source) => source
        .map(
          (provider) => ModelInfo(
            slug: provider.slug,
            name: provider.name,
            isCurrent: provider.isCurrent,
            models: provider.models
                .where((model) {
                  return visibleModelKeys == null ||
                      visibleModelKeys.contains(
                        modelKey(provider.slug, model),
                      ) ||
                      (provider.slug == currentProvider &&
                          model == currentModel);
                })
                .toList(growable: false),
            pricing: provider.pricing,
          ),
        )
        .toList(growable: false);

    final normal =
        filter(
          providers.where((provider) => provider.slug.toLowerCase() != 'moa'),
        )..sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return byName != 0 ? byName : a.slug.compareTo(b.slug);
        });
    final moa = filter(
      providers.where((provider) => provider.slug.toLowerCase() == 'moa'),
    );
    return ModelCatalogProjection(providers: normal, moaProviders: moa);
  }

  static String modelKey(String provider, String model) => '$provider::$model';
}

class ModelCatalogProjection {
  final List<ModelInfo> providers;
  final List<ModelInfo> moaProviders;

  const ModelCatalogProjection({
    required this.providers,
    required this.moaProviders,
  });
}

class ModelVisibilityStore {
  static const preferenceKey = 'hermes.mobile.visible-models';

  final SharedPreferences preferences;

  ModelVisibilityStore(this.preferences);

  Set<String> visibleKeys(List<ModelInfo> providers) {
    final saved = preferences.getStringList(preferenceKey);
    if (saved != null) return saved.toSet();
    return {
      for (final provider in providers)
        for (final model in provider.models)
          ModelCatalog.modelKey(provider.slug, model),
    };
  }

  Future<void> save(Set<String> keys) async {
    final sorted = keys.toList()..sort();
    await preferences.setStringList(preferenceKey, sorted);
  }
}
