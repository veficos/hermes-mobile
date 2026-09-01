/// TerminalPanel: right-rail terminal chrome.
///
/// Reuses [TerminalWorkspace] / [TerminalStore] for parity with the full-screen
/// terminal (cwd bar, copy, links, drag-drop, send-to-chat).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/stores/terminal_store.dart';
import '../../l10n/l10n.dart';
import '../terminal/terminal_workspace.dart';

class TerminalPanel extends StatefulWidget {
  const TerminalPanel({super.key});

  @override
  State<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends State<TerminalPanel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final terminal = context.read<TerminalStore>();
      final messenger = ScaffoldMessenger.of(context);
      try {
        await terminal.init();
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
    return const TerminalWorkspace(
      compact: true,
      autofocusCommand: false,
      // Side rail stays on chat; write draft and snackbar instead of navigating.
      navigateOnSendToChat: false,
    );
  }
}
