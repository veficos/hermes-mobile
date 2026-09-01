/// Shared download-to-device flow for FilesScreen / FileTreePanel.
library;

import 'dart:typed_data';

import 'api_client.dart';
import 'local_file_io.dart';

/// Download [remotePath] (file or folder ZIP) and save it on this device.
/// Desktop may show a save dialog; mobile writes under Hermes Downloads.
Future<String> downloadServerFileToDevice({
  required ApiClient api,
  required String remotePath,
  String? fileName,
}) async {
  final result = await api.fsDownload(remotePath);
  final name = (fileName != null && fileName.isNotEmpty)
      ? fileName
      : result.filename;
  final data = Uint8List.fromList(result.bytes);
  final picked = await pickDownloadSavePath(name);
  if (picked != null && picked.isNotEmpty) {
    await writeBytesAtPath(picked, data);
    return picked;
  }
  return writeDownloadBytes(name, data);
}
