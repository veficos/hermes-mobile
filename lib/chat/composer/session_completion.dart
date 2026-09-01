library;

import '../../core/models.dart';
import '../../core/session_refs.dart';

class SessionComposerCompletion {
  static final RegExp _queryPattern = RegExp(r'@session:([^\s]*)$');
  static String? queryFor(String text) =>
      _queryPattern.firstMatch(text)?.group(1)?.toLowerCase();
  static List<SessionRefSuggestion> suggestions({
    required String text,
    required Iterable<SessionRow> sessions,
    String? activeProfile,
    int limit = 12,
  }) {
    final query = queryFor(text);
    if (query == null) return const [];
    return sessions
        .where((row) {
          final haystack = [
            row.id,
            row.title ?? '',
            row.profile ?? '',
          ].join(' ').toLowerCase();
          return query.isEmpty || haystack.contains(query);
        })
        .take(limit)
        .map((row) {
          final title = row.title?.trim();
          return SessionRefSuggestion(
            sessionId: row.id,
            profile: row.profile ?? activeProfile,
            title: title == null || title.isEmpty ? row.id : title,
          );
        })
        .toList(growable: false);
  }
}
