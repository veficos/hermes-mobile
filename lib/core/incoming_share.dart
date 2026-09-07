library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class IncomingSharePayload {
  final String text;
  final List<String> files;

  const IncomingSharePayload({this.text = '', this.files = const []});

  bool get isEmpty => text.trim().isEmpty && files.isEmpty;

  factory IncomingSharePayload.fromMap(Map<Object?, Object?> value) =>
      IncomingSharePayload(
        text: value['text']?.toString() ?? '',
        files: (value['files'] as List? ?? const [])
            .map((item) => item.toString())
            .where((item) => item.isNotEmpty)
            .toList(growable: false),
      );
}

/// Receives OS shares as draft material and never sends automatically.
class IncomingShareService extends ChangeNotifier {
  static const _channel = MethodChannel('hermes.share');
  final List<IncomingSharePayload> _pending = [];
  final Set<String> _seenPayloads = <String>{};

  IncomingShareService() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is Map) {
        _accept(IncomingSharePayload.fromMap(call.arguments as Map));
      }
    });
    unawaited(_loadInitial());
  }

  bool get hasPending => _pending.isNotEmpty;

  Future<void> _loadInitial() async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'getInitialShare',
      );
      if (raw != null) _accept(IncomingSharePayload.fromMap(raw));
    } on MissingPluginException {
      // Desktop/web/test platforms do not install the receiver.
    } on PlatformException {
      // An unreadable external file must not prevent normal startup.
    }
  }

  void _accept(IncomingSharePayload payload) {
    if (payload.isEmpty) return;
    // Android may deliver the same intent through both initial and resumed
    // channels; iOS extensions can likewise retry writes. De-dupe by stable
    // text/path content while retaining distinct user shares.
    final fingerprint =
        '${payload.text.trim()}\u0000${payload.files.join('\u0000')}';
    if (!_seenPayloads.add(fingerprint)) return;
    if (_seenPayloads.length > 128) {
      _seenPayloads.remove(_seenPayloads.first);
    }
    _pending.add(payload);
    notifyListeners();
  }

  List<IncomingSharePayload> takeAll() {
    if (_pending.isEmpty) return const [];
    final result = List<IncomingSharePayload>.unmodifiable(_pending);
    _pending.clear();
    notifyListeners();
    return result;
  }
}
