/// Helpers for paths that live on the *Hermes server* filesystem.
///
/// The Flutter client may run on Windows, Linux, macOS, or Web, while the
/// server path style is independent of the client OS. Always infer separators
/// from the path string itself (drive letter / UNC ⇒ Windows, otherwise POSIX).
library;

class ServerPath {
  ServerPath._();

  /// True when [path] looks like a Windows path (drive letter or UNC).
  static bool isWindowsStyle(String path) {
    final value = path.trim();
    if (value.startsWith(r'\\')) return true;
    return RegExp(r'^[a-zA-Z]:[\\/]?').hasMatch(value);
  }

  static String separatorFor(String path) => isWindowsStyle(path) ? r'\' : '/';

  /// Normalize separators to match the path's own style.
  static String normalize(String path) {
    final value = path.trim();
    if (value.isEmpty) return value;
    if (isWindowsStyle(value)) {
      return value.replaceAll('/', r'\');
    }
    return value.replaceAll(r'\', '/');
  }

  /// True when [path] is a Windows drive root such as `C:` or `C:\`.
  static bool isWindowsDriveRoot(String path) {
    final normalized = normalize(path).replaceFirst(RegExp(r'[\\/]+$'), '');
    return RegExp(r'^[a-zA-Z]:$').hasMatch(normalized);
  }

  /// True when [path] is the POSIX root `/`.
  static bool isPosixRoot(String path) {
    final normalized = normalize(path);
    return normalized == '/' || normalized.isEmpty;
  }

  /// Parent directory of a server path, or `''` when already at a volume root
  /// (caller should then show the drive / volume picker).
  static String parent(String path) {
    final normalized = normalize(path).replaceFirst(RegExp(r'[\\/]+$'), '');
    if (normalized.isEmpty) return '';

    if (isWindowsStyle(normalized)) {
      if (isWindowsDriveRoot(normalized)) return '';
      final separator = normalized.lastIndexOf(r'\');
      if (separator < 0) return '';
      if (separator <= 2) {
        return '${normalized.substring(0, 2)}\\';
      }
      return normalized.substring(0, separator);
    }

    if (normalized == '/') return '';
    final separator = normalized.lastIndexOf('/');
    if (separator < 0) return '';
    if (separator == 0) return '/';
    return normalized.substring(0, separator);
  }

  /// Join a server directory with a child name using the directory's separator.
  static String join(String dir, String name) {
    if (dir.isEmpty) return name;
    if (name.isEmpty) return normalize(dir);
    final left = normalize(dir);
    final sep = separatorFor(left);
    if (left.endsWith('/') || left.endsWith(r'\')) {
      return '$left$name';
    }
    return '$left$sep$name';
  }

  /// Final path segment (file or directory name), style-aware.
  static String basename(String path) {
    final normalized = normalize(path).replaceFirst(RegExp(r'[\\/]+$'), '');
    if (normalized.isEmpty) return path;
    if (isWindowsStyle(normalized)) {
      if (isWindowsDriveRoot(normalized)) {
        return '${normalized.substring(0, 2)}\\';
      }
      final separator = normalized.lastIndexOf(r'\');
      return separator < 0 ? normalized : normalized.substring(separator + 1);
    }
    if (normalized == '/') return '/';
    final separator = normalized.lastIndexOf('/');
    return separator < 0 ? normalized : normalized.substring(separator + 1);
  }

  /// File extension including the leading `.`, or `''` when none.
  static String extension(String path) {
    final name = basename(path);
    final dot = name.lastIndexOf('.');
    if (dot <= 0) return '';
    return name.substring(dot);
  }
}
