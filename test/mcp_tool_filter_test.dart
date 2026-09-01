import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/mcp_tool_filter.dart';

void main() {
  group('isToolEnabled', () {
    test('no filter enables every tool', () {
      expect(isToolEnabled(const {}, 'read_file'), isTrue);
      expect(isToolEnabled(null, 'read_file'), isTrue);
    });

    test('an include list only enables listed tools', () {
      final server = {
        'tools': {
          'include': ['read_file'],
        },
      };
      expect(isToolEnabled(server, 'read_file'), isTrue);
      expect(isToolEnabled(server, 'write_file'), isFalse);
    });

    test('an exclude list disables only listed tools', () {
      final server = {
        'tools': {
          'exclude': ['write_file'],
        },
      };
      expect(isToolEnabled(server, 'read_file'), isTrue);
      expect(isToolEnabled(server, 'write_file'), isFalse);
    });

    test('include wins when both are present', () {
      final server = {
        'tools': {
          'include': ['read_file'],
          'exclude': ['read_file'],
        },
      };
      expect(isToolEnabled(server, 'read_file'), isTrue);
    });
  });

  group('toggleToolInServer', () {
    test('starts an exclude denylist when no filter exists', () {
      final next = toggleToolInServer(const {'command': 'npx'}, 'write_file');
      expect(next['tools'], {
        'exclude': ['write_file'],
      });
      expect(next['command'], 'npx', reason: 'other fields must survive');
    });

    test('toggling twice removes the entry and drops an emptied tools map', () {
      final once = toggleToolInServer(const {}, 'write_file');
      final twice = toggleToolInServer(once, 'write_file');
      expect(twice.containsKey('tools'), isFalse);
    });

    test('preserves include mode when one is already set', () {
      final server = {
        'tools': {
          'include': ['read_file'],
        },
      };
      final next = toggleToolInServer(server, 'write_file');
      expect((next['tools'] as Map)['include'], ['read_file', 'write_file']);
      expect((next['tools'] as Map).containsKey('exclude'), isFalse);
    });
  });

  group('countEnabledTools', () {
    test('counts only tools not excluded', () {
      final server = {
        'tools': {
          'exclude': ['b'],
        },
      };
      expect(countEnabledTools(server, ['a', 'b', 'c']), 2);
    });
  });

  group('estimateServerTokens', () {
    test('sums ceil(schema_chars/4) for enabled tools only', () {
      final server = {
        'tools': {
          'exclude': ['b'],
        },
      };
      final tools = [
        {'name': 'a', 'schema_chars': 40},
        {'name': 'b', 'schema_chars': 400},
        {'name': 'c', 'schema_chars': 10},
      ];
      // a: ceil(40/4)=10, c: ceil(10/4)=3 → 13. b excluded.
      expect(estimateServerTokens(server, tools), 13);
    });

    test('returns null when no enabled tool carries schema_chars', () {
      final tools = [
        {'name': 'a'},
        {'name': 'b', 'schema_chars': 0},
      ];
      expect(estimateServerTokens(const {}, tools), isNull);
    });
  });

  group('serverUsageCount', () {
    test('sums prefixed registry-name call counts for the server', () {
      final counts = {
        'mcp__filesystem__read_file': 5,
        'mcp__filesystem__write_file': 2,
        'mcp__other__read_file': 100,
      };
      expect(serverUsageCount('filesystem', counts), 7);
    });

    test('sanitizes hyphens in the server name to underscores', () {
      final counts = {'mcp__my_server__tool': 3};
      expect(serverUsageCount('my-server', counts), 3);
    });
  });
}
