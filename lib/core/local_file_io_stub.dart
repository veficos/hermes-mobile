import 'dart:typed_data';

import 'folder_attachments.dart';
import '../l10n/runtime_l10n.dart';

Future<String> writeDownloadBytes(String filename, Uint8List bytes) {
  throw UnsupportedError(
    'Local file download is not available on this platform',
  );
}

Future<String?> pickDownloadSavePath(String suggestedName) async => null;

Future<void> writeBytesAtPath(String filePath, Uint8List bytes) {
  throw UnsupportedError(
    'Local file download is not available on this platform',
  );
}

Future<FolderScanResult> listFolderFiles(
  String dirPath, {
  required int maxFileBytes,
  int maxFiles = 50,
}) async {
  return FolderScanResult(
    files: const [],
    skipped: 0,
    warning: runtimeL10n.filesFolderFallback,
  );
}
