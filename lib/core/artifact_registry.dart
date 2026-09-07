library;

import 'package:flutter/foundation.dart';

@immutable
class ArtifactVersion {
  const ArtifactVersion({
    required this.content,
    required this.hash,
    required this.createdAt,
    this.ephemeral = false,
  });
  final String content;
  final String hash;
  final DateTime createdAt;
  final bool ephemeral;
}

@immutable
class VersionedArtifact {
  const VersionedArtifact({
    required this.id,
    required this.sessionId,
    required this.slug,
    required this.kind,
    required this.language,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.versions,
  });
  final String id;
  final String sessionId;
  final String slug;
  final String kind;
  final String language;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ArtifactVersion> versions;

  VersionedArtifact copyWith({
    String? title,
    DateTime? updatedAt,
    List<ArtifactVersion>? versions,
  }) => VersionedArtifact(
    id: id,
    sessionId: sessionId,
    slug: slug,
    kind: kind,
    language: language,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    versions: versions ?? this.versions,
  );
}

String artifactSlug({required String kind, String? language, String? title}) {
  final identity = [kind, language ?? '', title ?? '']
      .map((part) => part.trim().toLowerCase())
      .where((part) => part.isNotEmpty)
      .join('-');
  return identity
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Stable non-cryptographic content identity. Collision is verified by content
/// equality before dedupe, so this stays cheap on streaming rebuilds.
String artifactContentHash(String content) {
  var hash = 0x811c9dc5;
  for (final unit in content.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

class ArtifactRegistry {
  static const maxSessions = 32;
  static const maxArtifactsPerSession = 24;
  static const maxVersionsPerArtifact = 20;
  final Map<String, List<VersionedArtifact>> _bySession = {};

  List<VersionedArtifact> forSession(String sessionId) =>
      List.unmodifiable(_bySession[sessionId] ?? const []);

  VersionedArtifact upsert({
    required String sessionId,
    required String kind,
    required String content,
    String language = '',
    String title = '',
    // Slug identity input, kept separate from [title] so a display title that
    // changes on every streaming tick (e.g. a live line count) doesn't churn
    // the artifact's identity. Defaults to [title] when omitted, matching the
    // historical behavior for callers whose title is already stable.
    String? identity,
    bool settled = false,
  }) {
    final normalized = content.trim();
    final slug = artifactSlug(
      kind: kind,
      language: language,
      title: identity ?? title,
    );
    final records = _bySession.putIfAbsent(sessionId, () {
      if (_bySession.length >= maxSessions) {
        _bySession.remove(_bySession.keys.first);
      }
      return [];
    });
    final index = records.indexWhere((item) => item.slug == slug);
    final now = DateTime.now();
    final hash = artifactContentHash(normalized);
    final version = ArtifactVersion(
      content: normalized,
      hash: hash,
      createdAt: now,
      ephemeral: !settled,
    );
    if (index < 0) {
      final record = VersionedArtifact(
        id: '$sessionId:$slug',
        sessionId: sessionId,
        slug: slug,
        kind: kind,
        language: language,
        title: title.isEmpty ? kind : title,
        createdAt: now,
        updatedAt: now,
        versions: [version],
      );
      records.add(record);
      if (records.length > maxArtifactsPerSession) records.removeAt(0);
      return record;
    }
    final current = records[index];
    final known = current.versions
        .where((item) => item.hash == hash && item.content == normalized)
        .firstOrNull;
    if (known != null && (known.ephemeral == !settled || !settled)) {
      return current;
    }

    var versions = [...current.versions];
    if (versions.isNotEmpty && versions.last.ephemeral) {
      // Streaming ticks update one draft slot. Settling promotes that slot; it
      // never manufactures dozens of versions for one generated block.
      versions[versions.length - 1] = version;
    } else {
      versions.add(version);
    }
    if (versions.length > maxVersionsPerArtifact) {
      versions = versions.sublist(versions.length - maxVersionsPerArtifact);
    }
    final next = current.copyWith(
      title: title.isEmpty ? current.title : title,
      updatedAt: now,
      versions: List.unmodifiable(versions),
    );
    records[index] = next;
    return next;
  }

  void clearSession(String sessionId) => _bySession.remove(sessionId);
  void clear() => _bySession.clear();
}
