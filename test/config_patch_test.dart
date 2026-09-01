import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/config_patch.dart';

void main() {
  test('configHasPath and configValueAt walk nested maps', () {
    final config = {
      'memory': {'memory_enabled': true, 'memory_char_limit': 4000},
      'yolo': false,
    };
    expect(configHasPath(config, 'yolo'), isTrue);
    expect(configHasPath(config, 'memory.memory_enabled'), isTrue);
    expect(configHasPath(config, 'memory.missing'), isFalse);
    expect(configValueAt(config, 'memory.memory_char_limit'), 4000);
  });

  test('configPatchAt keeps sibling nested fields', () {
    final current = {
      'memory': {'memory_enabled': true, 'provider': 'local'},
    };
    final patch = configPatchAt(current, 'memory.memory_enabled', false);
    expect(patch['memory'], {'memory_enabled': false, 'provider': 'local'});
  });

  test(
    'configWithoutPath deletes a leaf, prunes empty parents, and does not mutate input',
    () {
      final current = <String, dynamic>{
        'agent': {'reasoning_effort': 'high', 'service_tier': 'priority'},
        'voice': {
          'tts': {'provider': 'openai'},
        },
      };
      final next = configWithoutPath(current, 'agent.reasoning_effort');
      expect(next, {
        'agent': {'service_tier': 'priority'},
        'voice': {
          'tts': {'provider': 'openai'},
        },
      });
      expect((current['agent'] as Map)['reasoning_effort'], 'high');
      expect(
        configWithoutPath(current, 'voice.tts.provider').containsKey('voice'),
        isFalse,
      );
    },
  );
}
