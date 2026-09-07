/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../chat/transcript/transcript_search_index.dart';
import '../../core/chat_message.dart';
import '../../core/stores/chat_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';

void showChatTopicPreview(
  BuildContext context,
  ChatMessage topic, {
  required void Function(ChatMessage) onJump,
}) {
  HapticFeedback.selectionClick();
  final preview = topic.plainText.trim();
  final index =
      context
          .read<ChatStore>()
          .messages
          .where((m) => m.role == 'user')
          .toList()
          .indexOf(topic) +
      1;
  showMobileSheet<void>(
    context,
    (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.chatTopicNumber(index),
              style: Theme.of(sheetCtx).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(
                  preview.isEmpty ? context.l10n.chatNoText : preview,
                  style: Theme.of(sheetCtx).textTheme.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  onJump(topic);
                },
                icon: const Icon(Icons.my_location, size: 16),
                label: Text(context.l10n.chatJumpToTopic),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void showChatHistoryLocator(
  BuildContext context,
  ChatStore chat, {
  required TranscriptSearchIndex search,
  required Set<String> markedMessageIds,
  required String Function(ChatMessage) markerId,
  required Future<void> Function(ChatMessage) onToggleMarker,
  required void Function(ChatMessage) onLocate,
}) {
  // Messages trimmed out of the live list for render-weight (still fully
  // fetched, just not currently materialized) don't cost anything to put
  // back — do that unconditionally so the locator never silently misses
  // them. Older pages genuinely not fetched yet (chat.hasMoreHistory) are
  // a real network cost, so those stay opt-in via the button below.
  if (chat.hasNewerTranscriptWindow) chat.restoreNewerTranscriptWindow();
  final searchCtrl = TextEditingController();
  var role = 'all';
  var rangeDays = 0;
  var markedOnly = false;
  var loadingAllHistory = false;
  Future<void> loadAllHistory(void Function(void Function()) setSheet) async {
    if (loadingAllHistory || !context.mounted) return;
    setSheet(() => loadingAllHistory = true);
    final session = context.read<SessionStore>();
    // hasMoreHistory deliberately stays true after a failed page fetch (so
    // the normal scroll-triggered retry keeps working) — historyError is
    // the actual stop signal here, otherwise a persistent failure would
    // spin this loop forever.
    var guard = 0;
    while (chat.hasMoreHistory && chat.historyError == null && guard < 500) {
      await session.loadOlderMessages();
      guard++;
    }
    if (!context.mounted) return;
    final failure = chat.historyError;
    setSheet(() => loadingAllHistory = false);
    if (failure != null && context.mounted) {
      showHermesToast(
        context,
        message: context.l10n.chatLoadAllHistoryFailed(failure),
        kind: HermesToastKind.error,
      );
    }
  }

  showMobileSheet(
    context,
    (sheetCtx) => StatefulBuilder(
      builder: (sheetCtx, setSheet) {
        final now = DateTime.now();
        final keyword = searchCtrl.text.trim();
        search.synchronize(chat.messages, chat.transcriptRevision);
        final messages = search
            .query(keyword)
            .where((hit) {
              final message = hit.message;
              if (role != 'all' && message.role != role) {
                return false;
              }
              if (markedOnly && !markedMessageIds.contains(markerId(message))) {
                return false;
              }
              if (rangeDays > 0 &&
                  message.timestamp != null &&
                  now.difference(message.timestamp!).inDays >= rangeDays) {
                return false;
              }
              if (rangeDays > 0 && message.timestamp == null) {
                return false;
              }
              return hit.preview.isNotEmpty || message.parts.isNotEmpty;
            })
            .toList(growable: false);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetCtx).size.height * .78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    onChanged: (_) => setSheet(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: context.l10n.chatSearchLoadedHistory,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      for (final item in [
                        ('all', context.l10n.commonAll),
                        ('user', context.l10n.chatMyMessages),
                        ('assistant', context.l10n.chatAssistant),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(item.$2),
                            selected: role == item.$1,
                            onSelected: (_) => setSheet(() => role = item.$1),
                          ),
                        ),
                      for (final item in [
                        (0, context.l10n.chatAllDates),
                        (1, context.l10n.chatLast24Hours),
                        (7, context.l10n.chatLast7Days),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(item.$2),
                            selected: rangeDays == item.$1,
                            onSelected: (_) =>
                                setSheet(() => rangeDays = item.$1),
                          ),
                        ),
                      FilterChip(
                        label: Text(context.l10n.chatMarkedOnly),
                        selected: markedOnly,
                        onSelected: (v) => setSheet(() => markedOnly = v),
                      ),
                    ],
                  ),
                ),
                if (chat.hasMoreHistory)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: HermesPalette.of(sheetCtx).text3,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            context.l10n.chatHistoryLocatorPartial,
                            style: TextStyle(
                              fontSize: 12,
                              color: HermesPalette.of(sheetCtx).text3,
                            ),
                          ),
                        ),
                        if (loadingAllHistory)
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.chatLoadingAllHistory,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: HermesPalette.of(sheetCtx).text3,
                                ),
                              ),
                            ],
                          )
                        else
                          TextButton(
                            onPressed: () => loadAllHistory(setSheet),
                            child: Text(context.l10n.chatLoadAllHistory),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                Expanded(
                  child: messages.isEmpty
                      ? Center(child: Text(context.l10n.chatNoMatchingMessages))
                      : ListView.builder(
                          itemCount: messages.length,
                          itemBuilder: (_, index) {
                            final hit = messages[index];
                            final message = hit.message;
                            final marked = markedMessageIds.contains(
                              markerId(message),
                            );
                            final preview = hit.preview
                                .replaceAll(RegExp(r'\s+'), ' ')
                                .trim();
                            return ListTile(
                              leading: Icon(
                                message.role == 'user'
                                    ? Icons.person_outline
                                    : Icons.smart_toy_outlined,
                              ),
                              title: Text(
                                preview.isEmpty
                                    ? context.l10n.chatToolStatusMessage
                                    : preview,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                message.timestamp?.toLocal().toString() ??
                                    context.l10n.chatUnknownTime,
                              ),
                              trailing: IconButton(
                                tooltip: marked
                                    ? context.l10n.chatUnmarkMessage
                                    : context.l10n.chatMarkMessage,
                                onPressed: () async {
                                  await onToggleMarker(message);
                                  setSheet(() {});
                                },
                                icon: Icon(
                                  marked
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                ),
                              ),
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                onLocate(message);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  ).whenComplete(searchCtrl.dispose);
}
