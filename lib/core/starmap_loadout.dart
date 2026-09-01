/// Generic "loadout" binary share codec — a direct port of hermes-agent
/// desktop's `lib/loadout.ts`. Pack bits/indices (not JSON), DEFLATE the
/// body, frame it with a version + checksum, and emit a short, opaque,
/// clipboard-safe base64url string under a namespacing prefix. Domain code
/// supplies only the body schema (write/read over [BitWriter]/[BitReader]);
/// everything else — compression, integrity, framing, whitespace tolerance,
/// typed errors — lives here, matching the desktop codec byte-for-byte so a
/// code copied from one app pastes into the other.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Little-endian bit writer (WoW's WriteBits, low bit first).
class BitWriter {
  final List<int> _bits = [];

  void bit(bool v) => _bits.add(v ? 1 : 0);

  void uint(int value, int width) {
    var v = value;
    for (var i = 0; i < width; i++) {
      _bits.add(v & 1);
      v >>= 1;
    }
  }

  /// LEB128-style varint: 7 payload bits per group, high "continue" bit set
  /// while more groups follow.
  void varint(int value) {
    var v = value < 0 ? 0 : value;
    do {
      final group = v & 0x7f;
      v = v >> 7;
      bit(v > 0);
      uint(group, 7);
    } while (v > 0);
  }

  void str(String s) {
    final bytes = utf8.encode(s);
    varint(bytes.length);
    for (final b in bytes) {
      uint(b, 8);
    }
  }

  Uint8List bytes() {
    final out = Uint8List((_bits.length / 8).ceil());
    for (var i = 0; i < _bits.length; i++) {
      if (_bits[i] != 0) {
        out[i >> 3] |= 1 << (i & 7);
      }
    }
    return out;
  }
}

class BitReader {
  final Uint8List _buf;
  int _pos = 0;

  BitReader(this._buf);

  int bit() {
    if (_pos >= _buf.length * 8) {
      throw const FormatException('loadout truncated');
    }
    final i = _pos++;
    return (_buf[i >> 3] >> (i & 7)) & 1;
  }

  int uint(int width) {
    var v = 0;
    for (var i = 0; i < width; i++) {
      v |= bit() << i;
    }
    return v;
  }

  int varint() {
    var v = 0;
    var shift = 0;
    for (;;) {
      final cont = bit();
      v += uint(7) << shift;
      shift += 7;
      if (cont == 0) return v;
    }
  }

  String str() {
    final len = varint();
    final bytes = Uint8List(len);
    for (var i = 0; i < len; i++) {
      bytes[i] = uint(8);
    }
    return utf8.decode(bytes);
  }
}

/// Interns repeated strings (labels, categories, …) so each record spends one
/// varint id instead of the full string; DEFLATE then squeezes the dictionary.
class Dict {
  final Map<String, int> _index = {};
  final List<String> list = [];

  int id(String s) {
    final hit = _index[s];
    if (hit != null) return hit;
    final next = list.length;
    _index[s] = next;
    list.add(s);
    return next;
  }
}

/// Index of [value] in a fixed enum table, clamped to 0 so an unknown value
/// decodes to the table's first (default) member instead of throwing.
int idxOf(List<String> table, String value) {
  final i = table.indexOf(value);
  return i < 0 ? 0 : i;
}

/// Bits needed to address `n` items positionally (fixed-width back-references).
int indexBits(int n) => n <= 1 ? 1 : (math.log(n) / math.ln2).ceil();

// ── base64url over the raw bytes (URL- and clipboard-safe, no padding) ─────
String _toBase64Url(Uint8List buf) =>
    base64Url.encode(buf).replaceAll('=', '');

Uint8List _fromBase64Url(String s) {
  final padded = s + '=' * ((4 - s.length % 4) % 4);
  return base64Url.decode(padded);
}

/// FNV-1a over the body bytes, low 16 bits — a tamper/corruption gate, not
/// crypto.
int _checksum16(Uint8List buf) {
  var h = 0x811c9dc5;
  for (final b in buf) {
    h ^= b;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h & 0xffff;
}

class LoadoutError implements Exception {
  final String message;
  const LoadoutError(this.message);

  @override
  String toString() => message;
}

typedef LoadoutErrorFactory = LoadoutError Function(String message);

class Loadout<T> {
  final String prefix;
  final int version;
  final void Function(BitWriter w, T value) write;
  final T Function(BitReader r) read;
  final String noun;
  final LoadoutErrorFactory errorFactory;

  const Loadout({
    required this.prefix,
    required this.version,
    required this.write,
    required this.read,
    this.noun = 'code',
    this.errorFactory = LoadoutError.new,
  });

  static const _headBytes = 3; // 8-bit version + 16-bit checksum

  String encode(T value) {
    final body = BitWriter();
    write(body, value);
    final payload = Uint8List.fromList(
      Deflate(body.bytes(), level: DeflateLevel.bestCompression).getBytes(),
    );

    final head = BitWriter();
    head.uint(version, 8);
    head.uint(_checksum16(payload), 16);
    final headBytes = head.bytes();

    final framed = Uint8List(headBytes.length + payload.length);
    framed.setRange(0, headBytes.length, headBytes);
    framed.setRange(headBytes.length, framed.length, payload);

    return prefix + _toBase64Url(framed);
  }

  T decode(String code) {
    // Strip ALL whitespace, not just the ends — a pasted code often picks up
    // soft wraps / newlines, and base64 decoding chokes on any of it.
    final cleaned = code.replaceAll(RegExp(r'\s+'), '');
    final raw = cleaned.startsWith(prefix)
        ? cleaned.substring(prefix.length)
        : cleaned;

    if (raw.isEmpty) {
      throw errorFactory("That doesn't look like a $noun.");
    }

    Uint8List framed;
    try {
      framed = _fromBase64Url(raw);
    } catch (_) {
      throw errorFactory("That doesn't look like a $noun.");
    }

    if (framed.length <= _headBytes) {
      throw errorFactory('${_capitalize(noun)} is too short to be valid.');
    }

    final head = BitReader(framed.sublist(0, _headBytes));
    final codeVersion = head.uint(8);
    final storedSum = head.uint(16);

    if (codeVersion != version) {
      throw errorFactory(
        '${_capitalize(noun)} is version $codeVersion; this build reads version $version.',
      );
    }

    final payload = framed.sublist(_headBytes);
    if (_checksum16(payload) != storedSum) {
      throw errorFactory('${_capitalize(noun)} looks corrupted (checksum mismatch).');
    }

    try {
      final inflated = Uint8List.fromList(Inflate(payload).getBytes());
      return read(BitReader(inflated));
    } catch (err) {
      throw errorFactory('${_capitalize(noun)} is malformed: $err');
    }
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
