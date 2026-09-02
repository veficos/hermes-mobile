import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/mcp_import.dart';

void main() {
  group('parseMcpImport', () {
    test('parses a bare URL', () {
      final result = parseMcpImport('https://mcp.linear.app/sse');
      expect(result, hasLength(1));
      expect(result!.first.name, 'linear');
      expect(result.first.config, {'url': 'https://mcp.linear.app/sse'});
    });

    test('parses an npx command line', () {
      final result = parseMcpImport(
        'npx -y @modelcontextprotocol/server-filesystem /tmp',
      );
      expect(result, hasLength(1));
      expect(result!.first.name, 'filesystem');
      expect(result.first.config['command'], 'npx');
      expect(result.first.config['args'], [
        '-y',
        '@modelcontextprotocol/server-filesystem',
        '/tmp',
      ]);
    });

    test('parses a docker command line', () {
      final result = parseMcpImport('docker run -e API_KEY=x my/server:latest');
      expect(result, hasLength(1));
      expect(result!.first.name, 'server');
      expect(result.first.config['command'], 'docker');
    });

    test('parses claude mcp add with a stdio command', () {
      final result = parseMcpImport(
        'claude mcp add linear -e API_KEY=xxx -- npx -y linear-mcp',
      );
      expect(result, hasLength(1));
      final entry = result!.first;
      expect(entry.name, 'linear');
      expect(entry.config['command'], 'npx');
      expect(entry.config['args'], ['-y', 'linear-mcp']);
      expect(entry.config['env'], {'API_KEY': 'xxx'});
    });

    test('parses claude mcp add with a URL', () {
      final result = parseMcpImport(
        'claude mcp add --transport sse linear https://mcp.linear.app/sse',
      );
      expect(result, hasLength(1));
      final entry = result!.first;
      expect(entry.name, 'linear');
      expect(entry.config['url'], 'https://mcp.linear.app/sse');
      expect(entry.config['transport'], 'sse');
    });

    test('parses a single JSON server object', () {
      final result = parseMcpImport(
        '{"command": "npx", "args": ["-y", "some-server"]}',
      );
      expect(result, hasLength(1));
      // cleanupName strips a trailing "-server" suffix (desktop parity).
      expect(result!.first.name, 'some');
    });

    test('parses an mcpServers JSON wrapper with multiple entries', () {
      final result = parseMcpImport('''
      {"mcpServers": {
        "linear": {"url": "https://mcp.linear.app/sse"},
        "fs": {"command": "npx", "args": ["-y", "server-filesystem"]}
      }}
      ''');
      expect(result, hasLength(2));
      expect(result!.map((e) => e.name), containsAll(['linear', 'fs']));
    });

    test('normalizes the ecosystem type alias to Hermes transport', () {
      final result = parseMcpImport('''
      {"mcpServers": {
        "remote": {"type": "http", "url": "https://mcp.example.test"}
      }}
      ''');

      expect(result, hasLength(1));
      expect(result!.single.config['transport'], 'http');
      expect(result.single.config, isNot(contains('type')));
    });

    test('parses Cursor MCP install deeplinks without losing fields', () {
      final config = base64Encode(
        utf8.encode(
          jsonEncode({
            'type': 'sse',
            'url': 'https://mcp.example.test/sse',
            'headers': {'Authorization': 'Bearer secret'},
            'enabled': false,
          }),
        ),
      );
      final link = Uri(
        scheme: 'cursor',
        host: 'anysphere.cursor-deeplink',
        path: '/mcp/install',
        queryParameters: {'name': 'remote', 'config': config},
      ).toString();

      final result = parseMcpImport(link);

      expect(result, hasLength(1));
      expect(result!.single.name, 'remote');
      expect(result.single.config, {
        'transport': 'sse',
        'url': 'https://mcp.example.test/sse',
        'headers': {'Authorization': 'Bearer secret'},
        'enabled': false,
      });
    });

    test('preserves header auth and tool filters from mcp.json', () {
      final result = parseMcpImport('''
      {"mcpServers": {
        "remote": {
          "url": "https://mcp.example.test",
          "headers": {"Authorization": "Bearer secret"},
          "tools": {"exclude": ["dangerous"]},
          "enabled": false
        }
      }}
      ''');

      expect(result, hasLength(1));
      final config = result!.single.config;
      expect(config['headers'], {'Authorization': 'Bearer secret'});
      expect(config['tools'], {
        'exclude': ['dangerous'],
      });
      expect(config['enabled'], isFalse);
    });

    test('returns null for unrecognizable text', () {
      expect(parseMcpImport('just some prose about a server'), isNull);
    });

    test('returns null for blank input', () {
      expect(parseMcpImport('   '), isNull);
    });
  });
}
