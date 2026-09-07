import 'dart:typed_data';
import 'upload_cancellation.dart';

Future<Map<String, dynamic>> uploadMultipartWithProgress({
  required String url,
  required Map<String, String> headers,
  required String path,
  required String filename,
  required Uint8List bytes,
  required void Function(int sent, int total) onProgress,
  UploadCancellation? cancellation,
}) => throw UnsupportedError('web upload progress is unavailable');
