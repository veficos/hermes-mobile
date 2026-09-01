/// Pure rules for turning a local folder into uploadable file entries.
library;

/// Directory names skipped while walking a folder attachment.
const Set<String> kSkippedFolderNames = {
  'node_modules',
  'dist',
  'build',
  '.venv',
  '__pycache__',
  'target',
  '.dart_tool',
};

class FolderFile {
  final String path;
  final String name;
  final int size;

  const FolderFile({
    required this.path,
    required this.name,
    required this.size,
  });
}

class FolderScanResult {
  final List<FolderFile> files;
  final int skipped;
  final String? warning;

  const FolderScanResult({required this.files, this.skipped = 0, this.warning});
}

/// Skip hidden directories and well-known bulky trees.
bool shouldSkipDirName(String name) {
  if (name.isEmpty || name == '.' || name == '..') return true;
  if (name.startsWith('.')) return true;
  return kSkippedFolderNames.contains(name);
}

/// Keep files under [maxFileBytes] up to [maxFiles]; count the rest as skipped.
FolderScanResult takeUploadableFiles(
  Iterable<FolderFile> files, {
  required int maxFileBytes,
  int maxFiles = 50,
}) {
  final kept = <FolderFile>[];
  var skipped = 0;
  for (final file in files) {
    if (kept.length >= maxFiles || file.size > maxFileBytes || file.size < 0) {
      skipped++;
      continue;
    }
    kept.add(file);
  }
  return FolderScanResult(files: kept, skipped: skipped);
}
