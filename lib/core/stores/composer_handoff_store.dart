library;

import 'package:flutter/foundation.dart';

import '../connections/connection_registry.dart';

@immutable
class ComposerSnippetHandoff {
  const ComposerSnippetHandoff({
    required this.owner,
    required this.path,
    required this.startLine,
    required this.endLine,
    required this.text,
    this.repositoryRoot,
    this.revision,
  });

  final OwnerRoute owner;
  final String path;
  final String? repositoryRoot;
  final int startLine;
  final int endLine;
  final String? revision;
  final String text;
}

@immutable
class ComposerTextHandoff {
  const ComposerTextHandoff({
    required this.owner,
    required this.text,
    required this.kind,
    this.metadata = const {},
  });

  final OwnerRoute owner;
  final String text;
  final String kind;
  final Map<String, dynamic> metadata;
}

/// Small in-memory bridge between the workspace source viewer and the active
/// chat composer. It intentionally carries structured line metadata instead
/// of flattening the selection into an untraceable string.
class ComposerHandoffStore extends ChangeNotifier {
  final List<ComposerSnippetHandoff> _pending = [];
  final List<ComposerTextHandoff> _pendingText = [];

  void addSnippet(ComposerSnippetHandoff snippet) {
    _pending.add(snippet);
    notifyListeners();
  }

  void addText(ComposerTextHandoff handoff) {
    if (handoff.text.trim().isEmpty) return;
    _pendingText.add(handoff);
    notifyListeners();
  }

  List<ComposerSnippetHandoff> takeFor(OwnerRoute? owner) {
    if (owner == null) return const [];
    final matches = _pending
        .where((item) => item.owner == owner)
        .toList(growable: false);
    if (matches.isEmpty) return const [];
    _pending.removeWhere((item) => item.owner == owner);
    return matches;
  }

  List<ComposerTextHandoff> takeTextFor(OwnerRoute? owner) {
    if (owner == null) return const [];
    final matches = _pendingText
        .where((item) => item.owner == owner)
        .toList(growable: false);
    if (matches.isEmpty) return const [];
    _pendingText.removeWhere((item) => item.owner == owner);
    return matches;
  }
}
