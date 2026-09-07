import 'package:flutter/material.dart';

import '../../core/tool_card_models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_tool.dart';
import '../web_preview.dart';
import 'tool_payload.dart';

/// Rich card for `web_search` / `browser_navigate` / `web_fetch` tool calls.
/// Extracted verbatim from `lib/widgets/message_bubble.dart` (formerly the
/// private `_WebToolCard`); behavior unchanged.
class WebToolCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const WebToolCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final results = parseWebResults(data);
    final args = data['args'];
    final url = (data['url'] ?? (args is Map ? args['url'] : null))?.toString();
    final query =
        (data['query'] ??
                (args is Map ? args['query'] ?? args['search_term'] : null))
            ?.toString();
    final palette = HermesPalette.of(context);
    if (results.isNotEmpty) {
      return ToolCardShell(
        key: ValueKey('tool-card-${data['tool_id'] ?? data['id'] ?? 'web'}'),
        icon: Icons.travel_explore,
        title: 'web_search',
        subtitle: Text(
          context.l10n.toolSearchResults(results.length),
          style: TextStyle(fontSize: 10.5, color: palette.text3),
        ),
        children: [
          if (query?.isNotEmpty == true) ...[
            Text(
              context.l10n.toolSearchQuery,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 5),
            Text(
              query!,
              style: HermesType.code.copyWith(
                fontSize: 12,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (final result in results)
            InkWell(
              onTap: result.url.isEmpty
                  ? null
                  : () => openChatLink(context, result.url),
              borderRadius: BorderRadius.circular(HermesRadius.smallCard),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: toolCodeBoxDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    if (result.url.isNotEmpty)
                      Text(
                        result.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: hermesSemantic(
                            context,
                            HermesSemantic.blue,
                            HermesSemanticDark.blue,
                          ),
                        ),
                      ),
                    if (result.snippet.isNotEmpty)
                      Text(
                        result.snippet,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: palette.text3),
                      ),
                  ],
                ),
              ),
            ),
        ],
      );
    }
    final title = query?.isNotEmpty == true
        ? query!
        : url?.isNotEmpty == true
        ? url!
        : context.l10n.messageWebFallback;
    return ToolCardShell(
      icon: Icons.travel_explore,
      title: title,
      trailing: url?.isNotEmpty == true
          ? IconButton(
              tooltip: context.l10n.messageOpenLink,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => openChatLink(context, url!),
              icon: const Icon(Icons.open_in_new),
            )
          : null,
      initiallyExpanded: false,
      children: [
        Text(
          toolResultText(data),
          style: HermesType.code.copyWith(color: palette.text, fontSize: 12),
        ),
      ],
    );
  }
}
