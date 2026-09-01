import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../chat/content/media_embed.dart';
import '../chat/content/rich_link_embed.dart';
import '../chat/message_parts/preview_targets.dart';
import '../core/models.dart';
import '../core/session_refs.dart';
import '../core/stores/session_store.dart';
import 'web_preview.dart';

class MessagePreviewAttachments extends StatelessWidget {
  final String text;
  const MessagePreviewAttachments({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final targets = extractMessagePreviewTargets(text);
    if (targets.isEmpty) return const SizedBox.shrink();
    SessionStore? sessions;
    try {
      sessions = context.read<SessionStore>();
    } catch (_) {}
    // A URL matching a known media provider gets a full-width rich card;
    // the rest stay compact chips in a wrap.
    final richCards = <Widget>[];
    final chips = <Widget>[];
    for (final target in targets) {
      if (target.kind == MessagePreviewKind.url ||
          target.kind == MessagePreviewKind.file) {
        final rich = target.kind == MessagePreviewKind.url
            ? detectRichLink(target.value)
            : null;
        if (rich != null) {
          richCards.add(RichLinkEmbed(info: rich));
          continue;
        }
        final media = mediaKindForUrl(target.value);
        if (media == MediaKind.audio) {
          richCards.add(InlineAudioPlayer(url: target.value));
          continue;
        }
        if (media == MediaKind.video) {
          richCards.add(MediaLinkCard(url: target.value, kind: media));
          continue;
        }
        if (isFileUrl(target.value)) {
          richCards.add(MediaLinkCard(url: target.value, kind: MediaKind.file));
          continue;
        }
      }
      chips.add(_PreviewChip(target: target, sessions: sessions));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...richCards,
          if (chips.isNotEmpty)
            Wrap(spacing: 8, runSpacing: 8, children: chips),
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final MessagePreviewTarget target;
  final SessionStore? sessions;
  const _PreviewChip({required this.target, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final sessionRef = target.kind == MessagePreviewKind.session
        ? parseSessionReference(target.value)
        : null;
    SessionRow? row;
    if (sessionRef != null) {
      for (final item in sessions?.sessions ?? const <SessionRow>[]) {
        if (item.id == sessionRef.sessionId) {
          row = item;
          break;
        }
      }
    }
    final title = row?.title?.trim();
    final label = target.kind == MessagePreviewKind.session
        ? (title?.isNotEmpty == true ? title! : sessionRef!.sessionId)
        : Uri.tryParse(target.value)?.pathSegments.lastOrNull ?? target.value;
    final icon = switch (target.kind) {
      MessagePreviewKind.session => Icons.forum_outlined,
      MessagePreviewKind.file => Icons.insert_drive_file_outlined,
      MessagePreviewKind.url => Icons.link,
    };
    return ActionChip(
      key: ValueKey('message-preview-${target.kind.name}-${target.value}'),
      avatar: Icon(icon, size: 17),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(label, overflow: TextOverflow.ellipsis),
      ),
      tooltip: target.value,
      onPressed: () {
        if (target.kind == MessagePreviewKind.session) {
          openChatLink(
            context,
            'hermes-session:${Uri.encodeComponent(target.value)}',
          );
        } else {
          openChatLink(context, target.value);
        }
      },
    );
  }
}
