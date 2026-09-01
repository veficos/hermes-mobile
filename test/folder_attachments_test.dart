import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_mobile/core/folder_attachments.dart';

void main() {
  test('shouldSkipDirName skips hidden and bulky trees', () {
    expect(shouldSkipDirName('node_modules'), isTrue);
    expect(shouldSkipDirName('.git'), isTrue);
    expect(shouldSkipDirName('src'), isFalse);
  });

  test('takeUploadableFiles respects size and count caps', () {
    final result = takeUploadableFiles(
      const [
        FolderFile(path: '/a.txt', name: 'a.txt', size: 10),
        FolderFile(path: '/big.bin', name: 'big.bin', size: 999),
        FolderFile(path: '/b.txt', name: 'b.txt', size: 10),
        FolderFile(path: '/c.txt', name: 'c.txt', size: 10),
      ],
      maxFileBytes: 100,
      maxFiles: 2,
    );
    expect(result.files.map((f) => f.name), ['a.txt', 'b.txt']);
    expect(result.skipped, 2);
  });
}
