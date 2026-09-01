import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/models.dart';
import 'package:hermes_mobile/screens/artifacts_screen.dart';

/// Desktop can download a gateway media artifact to disk
/// (`downloadGatewayMediaFile`); mobile's detail screen previously only had
/// copy/open-link. `resolveArtifactFile` is the value-shape sniffing (data
/// URI / plain base64 / http URL / local file / plain text) that backs the
/// new "保存到设备" action.
ArtifactItem _artifact({
  required String kind,
  required String value,
  String? label,
}) => ArtifactItem(
  id: 'a1',
  kind: kind,
  value: value,
  label: label,
  sessionId: 's1',
);

void main() {
  group('sanitizedArtifactFileStem', () {
    test('prefers the label, sanitizing filesystem-unsafe characters', () {
      final a = _artifact(kind: 'file', value: 'ignored', label: 'a/b:c?.txt');
      expect(sanitizedArtifactFileStem(a), 'a_b_c_.txt');
    });

    test('falls back to the first line of value when there is no label', () {
      final a = _artifact(kind: 'file', value: 'first line\nsecond line');
      expect(sanitizedArtifactFileStem(a), 'first line');
    });

    test('falls back to the kind when both label and value are unusable', () {
      final a = _artifact(kind: 'image', value: '');
      expect(sanitizedArtifactFileStem(a), 'image');
    });
  });

  group('resolveArtifactFile — image kind', () {
    test('decodes a data:image URI and infers the extension from its mime type', () async {
      final pngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final dataUri = 'data:image/png;base64,${base64Encode(pngBytes)}';
      final a = _artifact(kind: 'image', value: dataUri, label: 'screenshot');

      final file = await resolveArtifactFile(a);
      expect(file.bytes, pngBytes);
      expect(file.name, 'screenshot.png');
      expect(file.mimeType, 'image/png');
    });

    test('decodes a data:image/jpeg URI with the jpeg extension', () async {
      final bytes = base64Decode('/9j/4AAQSkZJRg==');
      final a = _artifact(
        kind: 'image',
        value: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        label: 'photo',
      );

      final file = await resolveArtifactFile(a);
      expect(file.name, 'photo.jpeg');
      expect(file.mimeType, 'image/jpeg');
    });

    test('falls back to plain-base64 decoding with a .png default', () async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final a = _artifact(kind: 'image', value: base64Encode(bytes), label: 'raw');

      final file = await resolveArtifactFile(a);
      expect(file.bytes, bytes);
      expect(file.name, 'raw.png');
    });

    test('does not double-append the extension when the label already has it', () async {
      final bytes = base64Decode('/9j/4AAQSkZJRg==');
      final a = _artifact(
        kind: 'image',
        value: 'data:image/jpeg;base64,${base64Encode(bytes)}',
        label: 'photo.jpeg',
      );

      final file = await resolveArtifactFile(a);
      expect(file.name, 'photo.jpeg');
    });
  });

  group('resolveArtifactFile — non-image kinds', () {
    test('encodes plain text as UTF-8 bytes with a .txt name', () async {
      final a = _artifact(kind: 'file', value: '# hello\nworld', label: 'notes');
      final file = await resolveArtifactFile(a);
      expect(utf8.decode(file.bytes), '# hello\nworld');
      expect(file.name, 'notes.txt');
      expect(file.mimeType, 'text/plain');
    });

    test('a link artifact is saved as its URL text', () async {
      final a = _artifact(kind: 'link', value: 'https://example.com/page');
      final file = await resolveArtifactFile(a);
      expect(utf8.decode(file.bytes), 'https://example.com/page');
      expect(file.name.endsWith('.txt'), isTrue);
    });
  });
}
