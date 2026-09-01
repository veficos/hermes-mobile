import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/starmap_loadout.dart';

void main() {
  group('BitWriter/BitReader', () {
    test('uint round-trips at various widths', () {
      final w = BitWriter();
      w.uint(5, 3);
      w.uint(200, 8);
      w.uint(0, 1);
      w.uint(1, 1);
      final r = BitReader(w.bytes());
      expect(r.uint(3), 5);
      expect(r.uint(8), 200);
      expect(r.uint(1), 0);
      expect(r.uint(1), 1);
    });

    test('varint round-trips small and large values', () {
      final w = BitWriter();
      for (final v in [0, 1, 127, 128, 300, 16384, 999999]) {
        w.varint(v);
      }
      final r = BitReader(w.bytes());
      for (final v in [0, 1, 127, 128, 300, 16384, 999999]) {
        expect(r.varint(), v);
      }
    });

    test('str round-trips UTF-8 text including multi-byte chars', () {
      final w = BitWriter();
      w.str('hello');
      w.str('技能测试');
      w.str('');
      final r = BitReader(w.bytes());
      expect(r.str(), 'hello');
      expect(r.str(), '技能测试');
      expect(r.str(), '');
    });

    test('bit() throws once the buffer is exhausted', () {
      final w = BitWriter();
      w.uint(1, 1);
      // bytes() rounds up to a whole byte, so 1 written bit still yields an
      // 8-bit buffer — read past all 8 to actually exhaust it.
      final r = BitReader(w.bytes());
      for (var i = 0; i < 8; i++) {
        r.bit();
      }
      expect(() => r.bit(), throwsA(isA<FormatException>()));
    });
  });

  group('Dict', () {
    test('interns repeated strings to the same id', () {
      final dict = Dict();
      final a = dict.id('foo');
      final b = dict.id('bar');
      final c = dict.id('foo');
      expect(a, c);
      expect(a, isNot(b));
      expect(dict.list, ['foo', 'bar']);
    });
  });

  test('idxOf clamps unknown values to 0', () {
    expect(idxOf(['a', 'b', 'c'], 'b'), 1);
    expect(idxOf(['a', 'b', 'c'], 'nope'), 0);
  });

  test('indexBits addresses n items positionally', () {
    expect(indexBits(1), 1);
    expect(indexBits(2), 1);
    expect(indexBits(3), 2);
    expect(indexBits(4), 2);
    expect(indexBits(5), 3);
    expect(indexBits(256), 8);
  });

  group('Loadout', () {
    final codec = Loadout<String>(
      prefix: 'TST',
      version: 1,
      write: (w, value) => w.str(value),
      read: (r) => r.str(),
      noun: 'test code',
    );

    test('encode/decode round-trips a value through DEFLATE + base64url', () {
      const value = 'hello world, this repeats repeats repeats repeats';
      final code = codec.encode(value);
      expect(code, startsWith('TST'));
      expect(codec.decode(code), value);
    });

    test('rejects a code with a mismatched prefix content as garbage', () {
      expect(() => codec.decode('not a real code'), throwsA(isA<LoadoutError>()));
    });

    test('tolerates pasted whitespace/newlines in the code', () {
      final code = codec.encode('x');
      final withWhitespace = '${code.substring(0, 4)}\n  ${code.substring(4)}\n';
      expect(codec.decode(withWhitespace), 'x');
    });

    test('rejects a corrupted payload via the checksum', () {
      final code = codec.encode('some value that is long enough to survive a single flipped char');
      // Flip one base64url char in the middle of the payload body (well past
      // the prefix + head) to a different, still-valid base64url char.
      final mid = code.length ~/ 2;
      final flipped = code[mid] == 'A' ? 'B' : 'A';
      final corrupted = code.substring(0, mid) + flipped + code.substring(mid + 1);
      expect(() => codec.decode(corrupted), throwsA(isA<LoadoutError>()));
    });

    test('rejects a code from an incompatible version', () {
      final v2 = Loadout<String>(
        prefix: 'TST',
        version: 2,
        write: (w, value) => w.str(value),
        read: (r) => r.str(),
      );
      final code = codec.encode('x');
      expect(() => v2.decode(code), throwsA(isA<LoadoutError>()));
    });
  });
}
