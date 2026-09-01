library;

final _sessionRef = RegExp(
  r'''(?<![\w/])@session:(`[^`\n]+`|"[^"\n]+"|'[^'\n]+'|[^\s)\],;.!?]+)''',
);

String linkifySessionRefs(String text, {String? Function(String id)? titleOf}) {
  return text.replaceAllMapped(_sessionRef, (match) {
    final raw = match.group(1)!;
    final id = raw.replaceAll(RegExp(r'''^[`"']|[`"']$'''), '');
    if (id.isEmpty) return match.group(0)!;
    final title = titleOf?.call(id)?.trim();
    final label = title == null || title.isEmpty ? id : title;
    return '[$label](hermes-session:${Uri.encodeComponent(id)})';
  });
}

String? sessionIdFromHref(String href) {
  final uri = Uri.tryParse(href);
  if (uri?.scheme != 'hermes-session') return null;
  final encoded = href.substring('hermes-session:'.length);
  return Uri.decodeComponent(encoded);
}

({String? profile, String sessionId}) parseSessionReference(String value) {
  final slash = value.indexOf('/');
  if (slash <= 0 || slash == value.length - 1) {
    return (profile: null, sessionId: value);
  }
  return (
    profile: value.substring(0, slash),
    sessionId: value.substring(slash + 1),
  );
}

String formatSessionReference(String sessionId, {String? profile}) =>
    profile == null || profile.isEmpty ? sessionId : '$profile/$sessionId';

class SessionRefSuggestion {
  final String sessionId;
  final String? profile;
  final String title;

  const SessionRefSuggestion({
    required this.sessionId,
    required this.title,
    this.profile,
  });

  String get value => formatSessionReference(sessionId, profile: profile);
}
