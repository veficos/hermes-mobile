/// Validation shared by URL attachments and typed URL references.
/// Network fetching remains a server responsibility; this only rejects
/// ambiguous or obviously unsafe values before they enter a composer draft.
String? validateComposerUrl(String raw) {
  final value = raw.trim();
  if (value.isEmpty || value.length > 8192) return null;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !const {'http', 'https'}.contains(uri.scheme.toLowerCase())) {
    return null;
  }
  if (uri.host.isEmpty || uri.userInfo.isNotEmpty || uri.port < 0) return null;
  final host = uri.host.toLowerCase();
  final octets = host.split('.');
  final second = octets.length > 1 ? int.tryParse(octets[1]) : null;
  if (host == 'localhost' ||
      host == '0.0.0.0' ||
      host == '::1' ||
      host.startsWith('127.') ||
      host.startsWith('10.') ||
      host.startsWith('192.168.') ||
      (host.startsWith('172.') &&
          second != null &&
          second >= 16 &&
          second <= 31)) {
    return null;
  }
  return uri.toString();
}
