/// Shared session-list row metadata: location line, status, lightweight badges.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models.dart';
import '../../core/stores/pull_request_store.dart';
import '../../core/server_path.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';

/// Basename of a server path for compact list display.
String sessionPathBasename(String? path) {
  final trimmed = path?.trim() ?? '';
  if (trimmed.isEmpty) return '';
  return ServerPath.basename(trimmed);
}

/// `folder · branch` (or either alone) for distinguishing same-titled sessions.
String? sessionLocationLabel(SessionRow row) {
  final parts = <String>[];
  final base = sessionPathBasename(row.cwd);
  if (base.isNotEmpty) parts.add(base);
  final branch = row.gitBranch?.trim() ?? '';
  if (branch.isNotEmpty) parts.add(branch);
  if (parts.isEmpty) return null;
  return parts.join(' · ');
}

/// Prefer last activity over create time.
DateTime? sessionActivityTime(SessionRow row) {
  final ms = row.lastMessageAt;
  if (ms != null) {
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return row.startedAt;
}

/// Whether a persisted context-compression failure still needs attention.
/// Hermes keeps the last failure text in older session rows after its retry
/// cooldown expires, so the text alone must not be treated as a live error.
bool hasActiveCompressionFailure(SessionRow row, {DateTime? now}) {
  if (row.compressionFailureError?.trim().isNotEmpty != true) return false;
  final until = row.compressionFailureCooldownUntil;
  if (until == null) return true;
  return until.isAfter(now ?? DateTime.now());
}

/// Compact CLI / draft / share badges for a session title row.
class SessionMetaBadges extends StatelessWidget {
  final SessionRow row;
  final double iconSize;

  const SessionMetaBadges({super.key, required this.row, this.iconSize = 13});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final children = <Widget>[];
    final pullRequests = Provider.of<PullRequestStore?>(context);
    final pr = pullRequests?.forSession(row);
    if (pr != null) {
      final color = switch (pr.bucket) {
        PullRequestBucket.open => hermesSemantic(
          context,
          HermesSemantic.green,
          HermesSemanticDark.green,
        ),
        PullRequestBucket.draft => hermesSemantic(
          context,
          HermesSemantic.gray,
          HermesSemanticDark.gray,
        ),
        PullRequestBucket.merged => hermesSemantic(
          context,
          HermesSemantic.purple,
          HermesSemanticDark.purple,
        ),
        PullRequestBucket.closed => hermesSemantic(
          context,
          HermesSemantic.red,
          HermesSemanticDark.red,
        ),
        PullRequestBucket.none => muted,
      };
      children.add(
        Tooltip(
          message: context.l10n.sessionPrBadge(
            pr.number,
            _prBucketLabel(context, pr.bucket),
          ),
          child: InkResponse(
            radius: iconSize + 6,
            onTap: pr.url.isEmpty
                ? null
                : () async {
                    final launched = await launchUrl(
                      Uri.parse(pr.url),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!launched && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.l10n.sessionPrOpenFailed),
                        ),
                      );
                    }
                  },
            child: Icon(Icons.call_made, size: iconSize, color: color),
          ),
        ),
      );
    }
    if (row.isCliSession) {
      children.add(
        Tooltip(
          message: context.l10n.sessionCliBadge,
          child: Icon(Icons.terminal, size: iconSize, color: muted),
        ),
      );
    }
    if (row.composerDraft.hasPayload) {
      children.add(
        Tooltip(
          message: context.l10n.sessionDraftBadge,
          child: Icon(Icons.edit_note, size: iconSize, color: muted),
        ),
      );
    }
    if (row.shareToken != null && row.shareToken!.isNotEmpty) {
      children.add(
        Tooltip(
          message: context.l10n.sessionSharedBadge,
          child: Icon(Icons.link, size: iconSize, color: HermesSemantic.blue),
        ),
      );
    }
    if (row.handoffState?.isNotEmpty == true) {
      children.add(
        Tooltip(
          message: row.handoffPlatform?.isNotEmpty == true
              ? context.l10n.sessionHandedOffTo(row.handoffPlatform!)
              : context.l10n.sessionHandedOff,
          child: Icon(
            Icons.swap_horiz,
            size: iconSize,
            color: HermesSemantic.blue,
          ),
        ),
      );
    }
    final handoffError = row.handoffError?.trim();
    final activeCompressionFailure = hasActiveCompressionFailure(row);
    if (handoffError?.isNotEmpty == true || activeCompressionFailure) {
      children.add(
        Tooltip(
          message: handoffError?.isNotEmpty == true
              ? context.l10n.sessionHandoffErrorBadge(handoffError!)
              : context.l10n.sessionCompressionErrorBadge(
                  row.compressionFailureError!.trim(),
                ),
          child: Icon(
            Icons.error_outline,
            size: iconSize,
            color: HermesSemantic.red,
          ),
        ),
      );
    } else if (row.endedAt != null) {
      children.add(
        Tooltip(
          message: row.endReason?.isNotEmpty == true
              ? context.l10n.sessionEndedWithReason(row.endReason!)
              : context.l10n.sessionEnded,
          child: Icon(Icons.check_circle_outline, size: iconSize, color: muted),
        ),
      );
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          children[i],
        ],
      ],
    );
  }
}

/// Trailing status: attention badge vs working spinner (filter-bucket parity).
class SessionStatusIndicator extends StatelessWidget {
  final bool attention;
  final bool working;
  final double size;

  const SessionStatusIndicator({
    super.key,
    required this.attention,
    required this.working,
    this.size = 16,
  });

  @override
  Widget build(BuildContext context) {
    if (attention) {
      return Tooltip(
        message: context.l10n.sessionStatusAttention,
        child: Icon(
          Icons.notification_important_outlined,
          size: size,
          color: HermesSemantic.orange,
        ),
      );
    }
    if (working) {
      return SizedBox(
        width: size,
        height: size,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return const SizedBox.shrink();
  }
}

String _prBucketLabel(BuildContext context, PullRequestBucket bucket) =>
    switch (bucket) {
      PullRequestBucket.open => context.l10n.sessionPrOpen,
      PullRequestBucket.draft => context.l10n.sessionPrDraft,
      PullRequestBucket.merged => context.l10n.sessionPrMerged,
      PullRequestBucket.closed => context.l10n.sessionPrClosed,
      PullRequestBucket.none => context.l10n.sessionPrNone,
    };
