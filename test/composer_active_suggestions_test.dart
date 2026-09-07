import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/composer_suggestions.dart';

void main() {
  test('skill matching is completed-word and workspace guarded', () {
    expect(composerSkillHit('please use pr ready ', 'pr-ready'), isTrue);
    expect(composerSkillHit('already done ', 'read'), isFalse);
    expect(composerSkillHit('use deploy', 'deploy'), isFalse);
    expect(
      composerSkillCollidesWithWorkspace(
        'hermes-agent',
        '/src/hermes-agent-worktree',
      ),
      isTrue,
    );
  });

  test('github only matches a real host or completed word', () {
    expect(composerGithubHit('check https://github.com/a/b'), isTrue);
    expect(composerGithubHit('github '), isTrue);
    expect(composerGithubHit('notgithub.com '), isFalse);
    expect(composerGithubHit('github'), isFalse);
  });

  test('MCP catalog matcher honors host boundary and cap', () {
    final catalog = <Map<String, dynamic>>[
      {
        'name': 'linear',
        'suggest': {
          'keywords': ['linear'],
          'hosts': ['linear.app'],
        },
      },
      {
        'name': 'figma',
        'suggest': {
          'keywords': ['figma'],
          'hosts': ['figma.com'],
        },
      },
    ];
    expect(
      composerMcpMatches(
        'open https://acme.linear.app/x',
        catalog,
      ).single.server,
      'linear',
    );
    expect(composerMcpMatches('notlinear.app ', catalog), isEmpty);
  });

  test('MCP repair matcher is narrow and extracts server', () {
    expect(composerMcpServerFromTool('mcp__linear__issues'), 'linear');
    expect(composerMcpRepairError.hasMatch('401 Unauthorized'), isTrue);
    expect(composerMcpRepairError.hasMatch('issue not found'), isFalse);
  });
}
