import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';

void main() {
  group('SkillInfo', () {
    test('parses provenance/usage and isLearned reflects agent provenance', () {
      final learned = SkillInfo.fromJson({
        'name': 'my-skill',
        'description': 'desc',
        'enabled': true,
        'category': 'productivity',
        'provenance': 'agent',
        'usage': 7,
      });
      expect(learned.provenance, 'agent');
      expect(learned.usage, 7);
      expect(learned.isLearned, isTrue);

      final bundled = SkillInfo.fromJson({
        'name': 'bundled-skill',
        'enabled': false,
        'provenance': 'bundled',
      });
      expect(bundled.isLearned, isFalse);
    });

    test('copyWith preserves provenance/usage/category while flipping enabled', () {
      final original = SkillInfo(
        name: 'x',
        description: 'd',
        enabled: false,
        category: 'cat',
        provenance: 'hub',
        usage: 42,
      );
      final toggled = original.copyWith(enabled: true);
      expect(toggled.enabled, isTrue);
      expect(toggled.name, 'x');
      expect(toggled.description, 'd');
      expect(toggled.category, 'cat');
      expect(toggled.provenance, 'hub');
      expect(toggled.usage, 42);
    });
  });

  group('SkillHubSources', () {
    test('parses sources, featured, and the installed map', () {
      final sources = SkillHubSources.fromJson({
        'sources': [
          {'id': 'github', 'label': 'GitHub', 'available': true, 'rate_limited': false},
          {'id': 'skillsdotsh', 'label': 'skills.sh', 'available': false},
        ],
        'index_available': true,
        'featured': [
          {
            'name': 'Web Research',
            'description': 'desc',
            'source': 'github',
            'identifier': 'github:foo/bar',
            'trust_level': 'community',
            'repo': 'https://github.com/foo/bar',
            'tags': ['research', 'web'],
          },
        ],
        'installed': {
          'github:foo/bar': {
            'name': 'web-research',
            'trust_level': 'community',
            'scan_verdict': 'clean',
          },
        },
      });

      expect(sources.sources, hasLength(2));
      expect(sources.sources.first.id, 'github');
      expect(sources.sources.last.available, isFalse);
      expect(sources.indexAvailable, isTrue);
      expect(sources.featured, hasLength(1));
      expect(sources.featured.first.tags, ['research', 'web']);
      expect(sources.installed['github:foo/bar']?.name, 'web-research');
    });

    test('defaults gracefully on a minimal payload', () {
      final sources = SkillHubSources.fromJson(const {});
      expect(sources.sources, isEmpty);
      expect(sources.indexAvailable, isFalse);
      expect(sources.featured, isEmpty);
      expect(sources.installed, isEmpty);
    });
  });

  group('SkillHubSearchResult', () {
    test('parses results, source counts, and timed-out sources', () {
      final result = SkillHubSearchResult.fromJson({
        'results': [
          {
            'name': 'A',
            'description': '',
            'source': 'github',
            'identifier': 'github:a/a',
            'trust_level': 'official',
            'repo': null,
            'tags': <String>[],
          },
        ],
        'source_counts': {'github': 1, 'skillsdotsh': 0},
        'timed_out': ['skillsdotsh'],
        'installed': {},
      });
      expect(result.results, hasLength(1));
      expect(result.sourceCounts['github'], 1);
      expect(result.timedOut, ['skillsdotsh']);
    });
  });

  group('SkillHubPreview', () {
    test('parses skill_md content and files list', () {
      final preview = SkillHubPreview.fromJson({
        'name': 'A',
        'description': 'd',
        'source': 'github',
        'identifier': 'github:a/a',
        'trust_level': 'community',
        'repo': null,
        'tags': ['x'],
        'skill_md': '# A\n\nSome content.',
        'files': ['SKILL.md', 'scripts/run.py'],
      });
      expect(preview.skillMd, contains('Some content.'));
      expect(preview.files, hasLength(2));
    });
  });

  group('SkillHubScanResult', () {
    test('parses findings, policy, and severity counts', () {
      final scan = SkillHubScanResult.fromJson({
        'name': 'A',
        'identifier': 'github:a/a',
        'source': 'github',
        'trust_level': 'community',
        'verdict': 'warnings',
        'summary': '1 medium finding',
        'policy': 'ask',
        'policy_reason': 'unverified network call',
        'findings': [
          {
            'severity': 'medium',
            'category': 'network',
            'file': 'scripts/run.py',
            'line': 12,
            'description': 'outbound request to unknown host',
          },
        ],
        'severity_counts': {'medium': 1},
      });
      expect(scan.policy, 'ask');
      expect(scan.findings, hasLength(1));
      expect(scan.findings.first.line, 12);
      expect(scan.severityCounts['medium'], 1);
    });
  });
}
