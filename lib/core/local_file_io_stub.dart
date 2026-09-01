import 'dart:typed_data';

import '../l10n/runtime_l10n.dart';
import 'folder_attachments.dart';

Future<String> writeDownloadBytes(String filename, Uint8List bytes) {
  throw UnsupportedError(runtimeL10n.filesDownloadPlatformUnsupported);
}

Future<String?> pickDownloadSavePath(String suggestedName) async => null;

Future<void> writeBytesAtPath(String filePath, Uint8List bytes) {
  throw UnsupportedError(runtimeL10n.filesDownloadPlatformUnsupported);
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
