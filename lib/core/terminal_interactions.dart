String quoteTerminalPath(String path, String shellName) {
  final shell = shellName.toLowerCase();
  if (shell.contains('powershell') || shell.contains('pwsh')) {
    return "'${path.replaceAll("'", "''")}'";
  }
  if (shell.contains('cmd')) {
    return '"${path.replaceAll('"', '""')}"';
  }
  return "'${path.replaceAll("'", "'\\''")}'";
}

String quoteTerminalPaths(Iterable<String> paths, String shellName) {
  final unique = <String>{};
  for (final path in paths) {
    final normalized = path.trim();
    if (normalized.isNotEmpty) unique.add(normalized);
  }
  if (unique.isEmpty) return '';
  return '${unique.map((path) => quoteTerminalPath(path, shellName)).join(' ')} ';
}

final _webLinkPattern = RegExp(r'''https?://[^\s<>"']+''');

int terminalPasteLineCount(String text) => '\n'.allMatches(text).length + 1;

String terminalPasteAsSingleLine(String text) =>
    text.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

String? terminalWebLinkAt(String line, int column) {
  for (final match in _webLinkPattern.allMatches(line)) {
    var value = match.group(0)!;
    while (value.isNotEmpty && '.,;:!?)]}'.contains(value[value.length - 1])) {
      value = value.substring(0, value.length - 1);
    }
    final end = match.start + value.length;
    if (column >= match.start && column < end) return value;
  }
  return null;
}
