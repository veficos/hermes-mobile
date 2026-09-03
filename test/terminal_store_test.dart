import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:hermes_mobile/core/terminal_interactions.dart';
import 'package:hermes_mobile/core/stores/connection_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('parses Desktop-compatible OSC 7 paths', () {
    expect(
      parseOscCwd(7, 'file://desktop/C:/Users/Test%20User/work'),
      r'C:/Users/Test User/work',
    );
    expect(parseOscCwd(7, 'file://host/home/hermes'), '/home/hermes');
    expect(parseOscCwd(7, 'https://host/path'), isNull);
  });

  test('parses Desktop-compatible OSC 9;9 paths', () {
    expect(parseOscCwd(9, r'9;"C:\work tree"'), r'C:\work tree');
    expect(parseOscCwd(9, '8;ignored'), isNull);
  });

  test('tracks OSC cwd when a PTY sequence is split across frames', () {
    final tracker = OscCwdTracker();
    expect(tracker.add('\x1b]7;file://host/C:/Users/'), isNull);
    expect(tracker.add('veficos/work\x07prompt'), 'C:/Users/veficos/work');

    expect(tracker.add('\x1b]9;9;"D:\\repo"\x1b\\'), r'D:\repo');
  });

  test('quotes dropped paths for PowerShell, cmd and POSIX shells', () {
    expect(
      quoteTerminalPath(r"C:\it's here\file.txt", 'powershell.exe'),
      r"'C:\it''s here\file.txt'",
    );
    expect(
      quoteTerminalPath(r'C:\say "hi".txt', 'cmd.exe'),
      r'"C:\say ""hi"".txt"',
    );
    expect(quoteTerminalPath("/tmp/it's here", 'zsh'), r"'/tmp/it'\''s here'");
    expect(
      quoteTerminalPaths([' /tmp/a ', '/tmp/a', '/tmp/b'], 'bash'),
      "'/tmp/a' '/tmp/b' ",
    );
  });

  test('finds a web link only when the tapped column is inside it', () {
    const line = 'Open https://example.com/path?q=1, then continue';
    expect(terminalWebLinkAt(line, 12), 'https://example.com/path?q=1');
    expect(terminalWebLinkAt(line, 4), isNull);
    expect(terminalWebLinkAt(line, 35), isNull);
  });

  test('does not classify ordinary commands as sensitive history', () {
    expect(isSensitiveTerminalCommand('git status'), isFalse);
    expect(isSensitiveTerminalCommand('flutter test'), isFalse);
    expect(isSensitiveTerminalCommand('export MODE=debug'), isFalse);
  });

  test('filters credentials and tokens from persisted command history', () {
    expect(isSensitiveTerminalCommand('export API_KEY=abc123'), isTrue);
    expect(isSensitiveTerminalCommand(r'$env:GITHUB_TOKEN="secret"'), isTrue);
    expect(isSensitiveTerminalCommand('password: hunter2'), isTrue);
    expect(isSensitiveTerminalCommand('Authorization=Bearer token'), isTrue);
  });

  test('previews multiline paste and can normalize it to one line', () {
    const text = 'git status\r\ngit diff\necho done';
    expect(terminalPasteLineCount(text), 3);
    expect(terminalPasteAsSingleLine(text), 'git status git diff echo done');
  });

  test(
    'terminal display preferences are clamped and persisted locally',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = TerminalStore(connection: ConnectionStore());

      await store.setDisplayPreferences(
        fontSize: 99,
        lineHeight: .5,
        colorPreset: TerminalColorPreset.highContrastDark,
        cursorPreset: TerminalCursorPreset.block,
        contentPadding: false,
      );

      expect(store.terminalFontSize, 22);
      expect(store.terminalLineHeight, 1.2);
      expect(store.terminalColorPreset, TerminalColorPreset.highContrastDark);
      expect(store.terminalCursorPreset, TerminalCursorPreset.block);
      expect(store.terminalContentPadding, isFalse);
      store.dispose();
    },
  );

  test('terminal font save rolls back while disconnected', () async {
    final connection = ConnectionStore();
    final store = TerminalStore(connection: connection);
    addTearDown(store.dispose);
    addTearDown(connection.dispose);

    expect(store.configuredFontFamily, isEmpty);
    await expectLater(store.setFontFamily('Fira Code'), throwsStateError);
    expect(store.configuredFontFamily, isEmpty);
  });

  test(
    'notifyConnectivityRegained is a safe no-op with no recovery in flight',
    () {
      // Weak-network: `AppShell` calls this unconditionally on every
      // regained-connectivity event, whether or not this store happens to
      // be mid-reconnect at that moment — it must never throw or leave
      // state inconsistent for the common case where it isn't.
      final connection = ConnectionStore();
      final store = TerminalStore(connection: connection);
      addTearDown(store.dispose);
      addTearDown(connection.dispose);

      expect(store.notifyConnectivityRegained, returnsNormally);
      expect(store.notifyConnectivityRegained, returnsNormally);
    },
  );

  test(
    'notifyConnectivityRegained after dispose does not throw',
    () {
      final connection = ConnectionStore();
      final store = TerminalStore(connection: connection);
      addTearDown(connection.dispose);

      store.dispose();

      expect(store.notifyConnectivityRegained, returnsNormally);
    },
  );
}
