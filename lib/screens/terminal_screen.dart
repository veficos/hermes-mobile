import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/terminal_store.dart';
import '../l10n/l10n.dart';
import '../widgets/terminal/terminal_workspace.dart';
import '../widgets/terminal/terminal_visuals.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

export '../widgets/terminal/terminal_workspace.dart' show kTerminalChatDraftKey;

/// Full-screen interactive terminal (PTY + xterm).
class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final store = context.read<TerminalStore>();
      final messenger = ScaffoldMessenger.of(context);
      try {
        await store.init();
      } catch (error) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.terminalStartFailed('$error'))),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TerminalStore>();
    final theme = Theme.of(context);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return MobilePageScaffold(
      title: store.activeSession?.title ?? context.l10n.featureTerminal,
      subtitle: store.activeSession?.cwd,
      showAppBar: !keyboardVisible,
      body: ColoredBox(
        color: HermesTerminalVisuals.background(theme.brightness),
        child: const TerminalWorkspace(
          compact: true,
          autofocusCommand: true,
          navigateOnSendToChat: true,
        ),
      ),
    );
  }
}

/// Backward-compatible draft key used by chat_screen restore.
const String kChatDraftKey = kTerminalChatDraftKey;
