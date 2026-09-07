import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/stores/terminal_store.dart';
import 'package:xterm/xterm.dart';

void main() {
  test('terminal read uses absolute paging and trims display lines', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 3);
    terminal.write('one   \r\ntwo\r\nthree\r\nfour');

    final first = serializeTerminalBuffer(terminal, start: 0, count: 2);
    expect(first['start'], 0);
    expect(first['end'], 2);
    expect(first['viewport_rows'], 3);
    expect(first['text'], 'one\ntwo');

    final visible = serializeTerminalBuffer(terminal);
    expect(visible['start'], greaterThanOrEqualTo(1));
    expect(visible['cursor_row'], lessThan(visible['total_lines'] as int));
    expect((visible['text'] as String), contains('four'));
  });

  test('terminal read recomputes end after trimming trailing blank lines', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 5);
    terminal.write('one\r\ntwo');

    final result = serializeTerminalBuffer(terminal, start: 0, count: 5);
    expect(result['text'], 'one\ntwo');
    // `end` must reflect the actual (trimmed) number of lines returned, not
    // the originally requested/clamped range that included blank padding.
    expect(result['end'], 2);
    expect(
      result['end'],
      (result['start'] as int) +
          (result['text'] as String).split('\n').length,
    );
  });

  test('terminal read clamps hostile paging values', () {
    final terminal = Terminal(maxLines: 100)..resize(20, 2);
    terminal.write('alpha\r\nbeta');

    final result = serializeTerminalBuffer(terminal, start: -200, count: 50000);
    expect(result['start'], 0);
    expect(result['end'], result['total_lines']);
    expect(result['text'], startsWith('alpha'));
  });
}
