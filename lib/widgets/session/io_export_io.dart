import 'dart:io';

import 'package:path/path.dart' as p;

Future<String> writeExportFile(
  String directoryPath,
  String filename,
  String content,
) async {
  final exportDirectory = Directory(directoryPath);
  await exportDirectory.create(recursive: true);
  final safeName = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final file = File(p.join(exportDirectory.path, safeName));
  await file.writeAsString(content, flush: true);
  return file.path;
}
