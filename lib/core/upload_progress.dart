import 'dart:typed_data';
import 'upload_cancellation.dart';
export 'upload_cancellation.dart';
export 'upload_http_exception.dart';

import 'upload_progress_stub.dart'
    if (dart.library.js_interop) 'upload_progress_web.dart'
    as impl;

Future<Map<String, dynamic>> uploadMultipartWithProgress({
  required String url,
  required Map<String, String> headers,
  required String path,
  required String filename,
  required Uint8List bytes,
  required void Function(int sent, int total) onProgress,
  UploadCancellation? cancellation,
}) => impl.uploadMultipartWithProgress(
  url: url,
  headers: headers,
  path: path,
  filename: filename,
  bytes: bytes,
  onProgress: onProgress,
  cancellation: cancellation,
);
