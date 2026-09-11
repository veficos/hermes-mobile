import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/l10n/l10n.dart';
import 'package:hermes_mobile/screens/feature_registry.dart';

void main() {
  for (final language in ['en', 'zh', 'ar']) {
    test(
      'feature aliases preserve cross-language discovery: $language',
      () async {
        final l10n = await AppLocalizations.delegate.load(Locale(language));
        for (final entry in {
          'agent': [' BOT ', '机器人', '機器人', 'bot agent'],
          'workspace': ['工作区', '工作區', ' PANES ', '工作区 workspace'],
          'git': ['版本控制', 'VERSION CONTROL'],
          'projects': ['项目', '專案'],
          'settings': ['外观', 'appearance'],
        }.entries) {
          final feature = hermesFeaturesById[entry.key]!;
          for (final query in entry.value) {
            expect(feature.matchesSearch(query, l10n), isTrue, reason: query);
          }
        }
        for (final feature in hermesFeatureEntries) {
          expect(feature.matchesSearch('   ', l10n), isTrue);
          expect(feature.matchesSearch('unmapped-feature-xyz', l10n), isFalse);
          expect(
            feature.matchesSearch('bot unmapped-feature-xyz', l10n),
            isFalse,
          );
        }
        expect(hermesFeaturesById['git']!.matchesSearch('工作区', l10n), isFalse);
      },
    );
  }
}
