/// Lenient provider accessors shared by chat widgets — extracted from
/// lib/screens/chat_screen.dart (pure move, no behavior change).
library;

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

extension ProviderMaybe on BuildContext {
  /// Reads a provider if it exists in the tree, otherwise returns null.
  /// Keeps the screen usable in test harnesses that don't wire every store.
  T? maybeRead<T>() {
    try {
      return read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  /// Watches a provider when installed, while allowing lightweight embedded
  /// surfaces to retain their built-in defaults.
  T? maybeWatch<T>() {
    try {
      return watch<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
