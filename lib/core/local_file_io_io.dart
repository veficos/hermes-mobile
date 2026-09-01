import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'folder_attachments.dart';
import '../l10n/runtime_l10n.dart';

String _safeFileName(String filename) {
  final base = filename.trim().isEmpty ? 'download.bin' : filename.trim();
  return base.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
}

Future<Directory> _downloadDirectory() async {
  Directory? preferred;
  try {
    preferred = await getDownloadsDirectory();
  } catch (_) {
    preferred = null;
  }
  preferred ??= await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(preferred.path, 'Hermes Downloads'));
  await dir.create(recursive: true);
  return dir;
}

Future<String> writeDownloadBytes(String filename, Uint8List bytes) async {
  final dir = await _downloadDirectory();
  final safe = _safeFileName(filename);
  var target = File(p.join(dir.path, safe));
  if (await target.exists()) {
    final stem = p.basenameWithoutExtension(safe);
    final ext = p.extension(safe);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    target = File(p.join(dir.path, '$stem-$stamp$ext'));
  }
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

Future<String?> pickDownloadSavePath(String suggestedName) async {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.fuchsia:
      return null;
    default:
      break;
  }
  final location = await getSaveLocation(
    suggestedName: _safeFileName(suggestedName),
  );
  return location?.path;
}

Future<void> writeBytesAtPath(String filePath, Uint8List bytes) async {
  final file = File(filePath);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
}

Future<FolderScanResult> listFolderFiles(
  String dirPath, {
  required int maxFileBytes,
  int maxFiles = 50,
}) async {
  final root = Directory(dirPath);
  if (!await root.exists()) {
    return FolderScanResult(
      files: const [],
      skipped: 0,
      warning: runtimeL10n.filesDirectoryMissing,
    );
  }
  final collected = <FolderFile>[];
  var skipped = 0;
  Future<void> walk(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is Directory) {
        if (shouldSkipDirName(p.basename(entity.path))) {
          skipped++;
          continue;
        }
        await walk(entity);
      } else if (entity is File) {
        var size = 0;
        try {
          size = await entity.length();
        } catch (_) {
          skipped++;
          continue;
        }
        if (collected.length >= maxFiles || size > maxFileBytes) {
          skipped++;
          continue;
        }
        collected.add(
          FolderFile(
            path: entity.path,
            name: p.basename(entity.path),
            size: size,
          ),
        );
      }
    }
  }

  await walk(root);
  return FolderScanResult(files: collected, skipped: skipped);
}
