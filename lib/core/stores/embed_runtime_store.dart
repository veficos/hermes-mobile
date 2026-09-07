library;

import 'package:flutter/foundation.dart';

/// Bounds expensive live rich-media players across the transcript.
class EmbedRuntimeStore extends ChangeNotifier {
  EmbedRuntimeStore({this.maxActive = 2});

  final int maxActive;
  final List<String> _active = [];

  bool isActive(String id) => _active.contains(id);

  bool acquire(String id) {
    if (_active.remove(id)) {
      _active.add(id);
      return true;
    }
    if (_active.length >= maxActive) return false;
    _active.add(id);
    notifyListeners();
    return true;
  }

  void release(String id) {
    if (_active.remove(id)) notifyListeners();
  }

  void releaseAll() {
    if (_active.isEmpty) return;
    _active.clear();
    notifyListeners();
  }

  int get activeCount => _active.length;
}
