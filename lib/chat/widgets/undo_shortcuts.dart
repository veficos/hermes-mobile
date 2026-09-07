/// WithUndoShortcuts — extracted from lib/screens/chat_screen.dart (pure
/// move, no behavior change): desktop-parity Ctrl+Z / Cmd+Z undo and
/// chat-find keyboard shortcuts wrapper.
library;

import 'package:flutter/material.dart';

import '../../core/stores/keybind_store.dart';
import 'provider_maybe.dart';

/// Desktop-parity Ctrl+Z / Cmd+Z undo wrapper (see use-composer-undo.ts).
///
/// Listens for the platform undo intent and fires [onUndo]. Intentionally a
/// lightweight wrapper so the Shortcuts/Action layer doesn't double-trigger
/// on editable TextFields inside (composer already handles its own undo).
class WithUndoShortcuts extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onUndo;
  final VoidCallback onFind;

  const WithUndoShortcuts({
    super.key,
    required this.child,
    required this.onUndo,
    required this.onFind,
  });

  @override
  Widget build(BuildContext context) {
    // Ctrl+Z / Cmd+Z undo is a hardware-keyboard affordance; touch platforms
    // get the plain child without a Shortcuts layer intercepting key events.
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia) {
      return child;
    }
    // Desktop parity: `store/keybinds.ts` — bindings are user-customizable
    // via Settings → Keyboard shortcuts (keybind_settings_screen.dart).
    // ChatScreen is also embedded by lightweight routes and widget harnesses
    // that intentionally do not install the app-wide KeybindStore. Keep the
    // hardware shortcuts available there with their canonical defaults while
    // the full app still rebuilds from the user-customizable store.
    final keybinds = context.maybeWatch<KeybindStore>();
    final shortcuts = <ShortcutActivator, Intent>{
      for (final activator
          in keybinds?.bindingsFor('chat.undo') ??
              KeybindStore.actions
                  .firstWhere((action) => action.id == 'chat.undo')
                  .defaults)
        activator: const ChatUndoIntent(),
      for (final activator
          in keybinds?.bindingsFor('chat.find') ??
              KeybindStore.actions
                  .firstWhere((action) => action.id == 'chat.find')
                  .defaults)
        activator: const ChatFindIntent(),
    };
    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          ChatUndoIntent: CallbackAction<ChatUndoIntent>(
            onInvoke: (_) async {
              await onUndo();
              return null;
            },
          ),
          ChatFindIntent: CallbackAction<ChatFindIntent>(
            onInvoke: (_) {
              onFind();
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class ChatUndoIntent extends Intent {
  const ChatUndoIntent();
}

class ChatFindIntent extends Intent {
  const ChatFindIntent();
}
