import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../screens/mcp_screen.dart';
import '../h/hermes_glass.dart';

/// Rich card for `setup_mcp` / `mcp_setup` tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_McpSetupToolCard`); behavior unchanged.
class McpSetupToolCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const McpSetupToolCard({super.key, required this.data});

  String get _server {
    final args = data['args'];
    if (args is Map) {
      final s = (args['server'] ?? args['name'] ?? args['id'] ?? '').toString();
      if (s.isNotEmpty) return s;
    }
    return (data['server'] ?? data['name'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    final failed = data['is_error'] == true || data['error'] != null;
    final running = data['running'] == true;
    final server = _server;
    return HermesGlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(
              failed ? Icons.extension_off_outlined : Icons.extension_outlined,
            ),
            title: Text(
              server.isEmpty
                  ? context.l10n.messageMcpSetup
                  : context.l10n.messageMcpServer(server),
            ),
            subtitle: Text(
              failed
                  ? context.l10n.messageMcpSetupFailed
                  : running
                  ? context.l10n.messageMcpSetupWaiting
                  : context.l10n.messageMcpSetupComplete,
            ),
            trailing: running
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    failed ? Icons.error_outline : Icons.check_circle_outline,
                  ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 4),
              child: TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 15),
                label: Text(context.l10n.messageOpenMcpSettings),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const McpScreen()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
