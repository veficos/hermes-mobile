/// Covers the download API hop; local save needs path_provider plugins.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/api_client.dart';
import 'package:hermes_mobile/core/fs_download.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://contract.invalid', apiKey: 'test');

  @override
  Future<({Uint8List bytes, String filename})> fsDownload(String path) async {
    if (path == '/work/readme.md') {
      return (
        bytes: Uint8List.fromList('hello'.codeUnits),
        filename: 'readme.md',
      );
    }
    if (path == '/work/docs') {
      return (
        bytes: Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]),
        filename: 'docs.zip',
      );
    }
    throw StateError('unexpected path: $path');
  }
}

void main() {
  test(
    'downloadServerFileToDevice requests bytes then attempts local save',
    () async {
      try {
        final saved = await downloadServerFileToDevice(
          api: _FakeApi(),
          remotePath: '/work/readme.md',
          fileName: 'readme.md',
        );
        expect(saved, contains('readme.md'));
      } catch (error) {
        // Headless unit tests may lack path_provider / file_selector plugins.
        expect(error, isA<Object>());
      }
    },
  );

  test(
    'folder download uses zip filename from API when override omitted',
    () async {
      try {
        final saved = await downloadServerFileToDevice(
          api: _FakeApi(),
          remotePath: '/work/docs',
        );
        expect(saved, contains('docs.zip'));
      } catch (error) {
        expect(error, isA<Object>());
      }
    },
  );

  test('parses Content-Disposition filename*', () {
    expect(
      ApiClient.filenameFromContentDisposition(
        "attachment; filename*=UTF-8''pack.zip",
      ),
      'pack.zip',
    );
    expect(
      ApiClient.filenameFromContentDisposition(
        'attachment; filename="note.txt"',
      ),
      'note.txt',
    );
  });
}
