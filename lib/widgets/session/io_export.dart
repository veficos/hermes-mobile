import 'io_export_stub.dart' if (dart.library.io) 'io_export_io.dart' as impl;

Future<String> writeExportFile(
  String directoryPath,
  String filename,
  String content,
) {
  return impl.writeExportFile(directoryPath, filename, content);
}
