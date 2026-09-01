/// Platform-conditional helpers for writing bytes to the device filesystem.
library;

import 'dart:typed_data';

import 'folder_attachments.dart';
import 'local_file_io_stub.dart'
    if (dart.library.io) 'local_file_io_io.dart'
    as impl;

/// Write [bytes] under a Hermes Downloads folder. Returns the absolute path.
Future<String> writeDownloadBytes(String filename, Uint8List bytes) {
  return impl.writeDownloadBytes(filename, bytes);
}

/// Optional save-as dialog on desktop. Returns null when cancelled / unsupported.
Future<String?> pickDownloadSavePath(String suggestedName) {
  return impl.pickDownloadSavePath(suggestedName);
}

/// Write [bytes] to an absolute [filePath].
Future<void> writeBytesAtPath(String filePath, Uint8List bytes) {
  return impl.writeBytesAtPath(filePath, bytes);
}

/// Recursively list uploadable files under [dirPath].
Future<FolderScanResult> listFolderFiles(
  String dirPath, {
  required int maxFileBytes,
  int maxFiles = 50,
}) {
  return impl.listFolderFiles(
    dirPath,
    maxFileBytes: maxFileBytes,
    maxFiles: maxFiles,
  );
}
