import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/deep_link_service.dart';

String _config(Map<String, dynamic> value) =>
    base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');

void main() {
  test('parses Hermes URI and blueprint composer command', () {
    final link = HermesDeepLink.parse(
      Uri.parse(
        'hermes://blueprint/morning-brief?time=08%3A00&topic=mobile%20release',
      ),
    );
    expect(link?.kind, 'blueprint');
    expect(link?.name, 'morning-brief');

    final action = resolveDeepLink(link!) as BlueprintDeepLinkAction;
    expect(
      action.command,
      '/blueprint morning-brief time=08:00 topic="mobile release"',
    );
  });

  test('routes plugin install flags and legacy aliases', () {
    final action =
        resolveDeepLink(
              HermesDeepLink.parse(
                Uri.parse(
                  'hermes://plugin/install?repo=owner%2Frepo&enable=0&force=yes',
                ),
              )!,
            )
            as PluginInstallDeepLinkAction;
    expect(action.identifier, 'owner/repo');
    expect(action.enable, isFalse);
    expect(action.force, isTrue);

    final legacy =
        resolveDeepLink(
              HermesDeepLink.parse(
                Uri.parse('hermes://plugin-agent/owner%2Frepo'),
              )!,
            )
            as PluginInstallDeepLinkAction;
    expect(legacy.identifier, 'owner/repo');
    expect(legacy.legacyKind, 'plugin-agent');
  });

  test('routes session with profile and connection scope', () {
    final action =
        resolveDeepLink(
              HermesDeepLink.parse(
                Uri.parse(
                  'hermes://session/session-1?profile=expert&connection=saved%3Awork',
                ),
              )!,
            )
            as SessionDeepLinkAction;
    expect(action.sessionId, 'session-1');
    expect(action.profile, 'expert');
    expect(action.connectionId, 'saved:work');
  });

  test('accepts reviewed HTTP and stdio MCP configurations', () {
    final http =
        resolveDeepLink(
              HermesDeepLink(
                kind: 'mcp',
                name: 'install',
                params: {
                  'name': 'docs',
                  'config': _config({'url': 'https://mcp.example.test/api'}),
                },
              ),
            )
            as McpInstallDeepLinkAction;
    expect(http.request.transport, 'http');

    final stdio =
        resolveDeepLink(
              HermesDeepLink(
                kind: 'mcp',
                name: 'install',
                params: {
                  'name': 'local_tools',
                  'config': _config({
                    'command': 'npx',
                    'args': ['-y', '@example/mcp'],
                  }),
                },
              ),
            )
            as McpInstallDeepLinkAction;
    expect(stdio.request.transport, 'stdio');
    expect(stdio.request.config['command'], 'npx');
  });

  test('rejects ambiguous unsafe malformed and oversized MCP payloads', () {
    DeepLinkAction parse(String name, String config) => resolveDeepLink(
      HermesDeepLink(
        kind: 'mcp',
        name: 'install',
        params: {'name': name, 'config': config},
      ),
    );

    expect(
      parse('both', _config({'url': 'https://example.test', 'command': 'npx'})),
      isA<RejectedDeepLinkAction>(),
    );
    expect(
      parse('unsafe', _config({'url': 'file:///etc/passwd'})),
      isA<RejectedDeepLinkAction>(),
    );
    expect(parse('bad name', '!!!'), isA<RejectedDeepLinkAction>());
    expect(parse('valid', '!!!'), isA<RejectedDeepLinkAction>());
    expect(
      parse('valid', List.filled(45 * 1024, 'A').join()),
      isA<RejectedDeepLinkAction>(),
    );
  });

  test('ignores foreign schemes and rejects unknown Hermes kinds', () {
    expect(HermesDeepLink.parse(Uri.parse('https://example.test')), isNull);
    expect(
      resolveDeepLink(const HermesDeepLink(kind: 'unknown', name: 'thing')),
      isA<RejectedDeepLinkAction>(),
    );
  });
}
