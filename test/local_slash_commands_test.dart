import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/local_slash_commands.dart';
import 'package:hermes_mobile/l10n/generated/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();
  test('matchLocalSlashInvocation resolves aliases and args', () {
    final clear = matchLocalSlashInvocation('/cls');
    expect(clear?.name, 'clear');

    final steer = matchLocalSlashInvocation('/steer follow up');
    expect(steer?.handler, LocalSlashHandler.steer);
    expect(localSlashArg('/steer follow up', steer!), 'follow up');

    expect(matchLocalSlashInvocation('/unknown'), isNull);
    expect(matchLocalSlashInvocation('retry'), isNull);
  });

  test('localSlashCommandPairs includes aliases', () {
    final pairs = localSlashCommandPairs(l10n);
    expect(pairs.any((p) => p.$1 == 'cls'), isTrue);
    expect(pairs.any((p) => p.$1 == 'steer'), isTrue);
  });

  test('desktop parity verbs resolve to local handlers', () {
    expect(
      matchLocalSlashInvocation('/new')?.handler,
      LocalSlashHandler.newChat,
    );
    expect(
      matchLocalSlashInvocation('/reset')?.handler,
      LocalSlashHandler.newChat,
    );
    expect(matchLocalSlashInvocation('/yolo')?.handler, LocalSlashHandler.yolo);
    expect(matchLocalSlashInvocation('/help')?.handler, LocalSlashHandler.help);
    expect(
      matchLocalSlashInvocation('/commands')?.handler,
      LocalSlashHandler.help,
    );
    expect(
      matchLocalSlashInvocation('/background')?.handler,
      LocalSlashHandler.background,
    );
    expect(
      matchLocalSlashInvocation('/bg')?.handler,
      LocalSlashHandler.background,
    );
    expect(
      matchLocalSlashInvocation('/compress')?.handler,
      LocalSlashHandler.compress,
    );
    expect(
      matchLocalSlashInvocation('/queue hello')?.handler,
      LocalSlashHandler.queue,
    );
    expect(
      matchLocalSlashInvocation('/usage')?.handler,
      LocalSlashHandler.usage,
    );
    expect(
      matchLocalSlashInvocation('/version')?.handler,
      LocalSlashHandler.version,
    );
    expect(matchLocalSlashInvocation('/stop')?.handler, LocalSlashHandler.stop);
    expect(
      matchLocalSlashInvocation('/tools')?.handler,
      LocalSlashHandler.tools,
    );
    expect(
      matchLocalSlashInvocation('/approvals off')?.handler,
      LocalSlashHandler.approvals,
    );
    expect(
      matchLocalSlashInvocation('/model')?.handler,
      LocalSlashHandler.model,
    );
    expect(
      matchLocalSlashInvocation('/handoff')?.handler,
      LocalSlashHandler.handoff,
    );
    expect(
      matchLocalSlashInvocation('/profile')?.handler,
      LocalSlashHandler.profile,
    );
  });

  test('unavailable desktop verbs are matched but not suggested', () {
    final wake = matchLocalSlashInvocation('/wake');
    expect(wake?.handler, LocalSlashHandler.wake);
    expect(localSlashDescription(wake!, l10n), contains('on'));
    expect(
      matchLocalSlashInvocation('/skin')?.handler,
      LocalSlashHandler.unavailable,
    );
    expect(
      matchLocalSlashInvocation('/reload-config')?.handler,
      LocalSlashHandler.unavailable,
    );
    final suggestions = localSlashCommandPairs(l10n).map((pair) => pair.$1);
    expect(suggestions, isNot(contains('skin')));
    expect(suggestions, isNot(contains('browser')));
    expect(suggestions, isNot(contains('reload-config')));
  });

  test('mobile feature verbs use navigation handlers', () {
    expect(
      matchLocalSlashInvocation('/journey')?.handler,
      LocalSlashHandler.journey,
    );
    expect(matchLocalSlashInvocation('/pet')?.handler, LocalSlashHandler.pet);
    expect(
      matchLocalSlashInvocation('/hatch')?.handler,
      LocalSlashHandler.hatch,
    );
  });

  test('server-backed desktop verbs are not intercepted as unavailable', () {
    for (final command in const [
      'debug',
      'goal',
      'loop',
      'rollback',
      'reload-mcp',
      'reload-skills',
    ]) {
      expect(matchLocalSlashInvocation('/$command'), isNull, reason: command);
    }
    expect(matchLocalSlashInvocation('/save')?.handler, LocalSlashHandler.save);
  });

  test('mobile-only suggestion filter normalizes slash names', () {
    expect(isMobileSlashSuggestionHidden('/skin'), isTrue);
    expect(isMobileSlashSuggestionHidden('BROWSER'), isTrue);
    expect(isMobileSlashSuggestionHidden('/reload-config'), isTrue);
    expect(isMobileSlashSuggestionHidden('/reload-mcp'), isFalse);
    expect(isMobileSlashSuggestionHidden('/reload-skills'), isFalse);
  });
}
