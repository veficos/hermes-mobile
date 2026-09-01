import 'package:flutter/widgets.dart';

class EmbedContext {
  final Uri uri;
  const EmbedContext(this.uri);
}

typedef EmbedBuilder =
    Widget Function(BuildContext context, EmbedContext embed);

class EmbedProvider {
  final String id;
  final bool Function(Uri uri) matches;
  final EmbedBuilder builder;
  const EmbedProvider({
    required this.id,
    required this.matches,
    required this.builder,
  });
}

class EmbedRegistry {
  final List<EmbedProvider> _providers = <EmbedProvider>[];
  void register(EmbedProvider provider) => _providers.insert(0, provider);
  EmbedProvider? resolve(Uri uri) {
    for (final provider in _providers) {
      if (provider.matches(uri)) return provider;
    }
    return null;
  }

  List<EmbedProvider> get providers => List.unmodifiable(_providers);
}
