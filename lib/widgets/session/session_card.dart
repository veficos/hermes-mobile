/// Full-detail session card — the single source of truth for every field a
/// session row can show (avatar, pin, status chip, preview, stats row,
/// source badge, model/branch/location/handoff tags, expand/more actions).
///
/// Shared by [SessionListScreen] (the full list) and the home screen's
/// "最近工作" recent-sessions section, so the two never drift apart on
/// which fields a session shows.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_glass.dart';
import '../mobile/hermes_mobile_surfaces.dart';
import 'session_list_meta.dart';

/// `123456` → `123.5K`, matching desktop's compact token-count formatting.
String compactSessionTokenCount(int value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
  return '$value';
}

String formatSessionDurationLocalized(BuildContext context, Duration value) {
  if (value.inDays > 0) {
    return context.l10n.sessionDurationDaysHours(
      value.inDays,
      value.inHours % 24,
    );
  }
  if (value.inHours > 0) {
    return context.l10n.sessionDurationHoursMinutes(
      value.inHours,
      value.inMinutes % 60,
    );
  }
  return context.l10n.sessionDurationMinutes(value.inMinutes);
}

class SessionCard extends StatelessWidget {
  final SessionRow session;
  final bool attention;
  final bool working;
  final bool unread;
  final Color? sessionColor;

  /// Number of descendant (sub-)sessions; 0 hides the expand/collapse
  /// control entirely.
  final int childrenCount;
  final bool expanded;
  final VoidCallback? onToggleExpand;

  /// Key for the expand/collapse button, for callers that need to find it
  /// directly in tests.
  final Key? expandButtonKey;

  /// Trailing "···" row-actions button; hidden when null.
  final VoidCallback? onMore;

  /// Extra icon badges rendered next to the status chip (e.g.
  /// `SessionMetaBadges` for CLI/draft/share/handoff/error signals) —
  /// optional, for callers that want more than this card's own fields.
  final Widget? extraBadges;

  const SessionCard({
    super.key,
    required this.session,
    required this.attention,
    required this.working,
    required this.unread,
    this.sessionColor,
    this.childrenCount = 0,
    this.expanded = false,
    this.onToggleExpand,
    this.expandButtonKey,
    this.onMore,
    this.extraBadges,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Prototype parity (`sessionCard()`'s status chip: running/completed=good,
    // needs_approval=warn, archived=gray): archived must not share the same
    // green as an active/completed session — it's a distinct, neutral state.
    final statusColor = attention
        ? (dark ? HermesSemanticDark.orange : HermesSemantic.orange)
        : working
        ? (dark ? HermesSemanticDark.green : HermesSemantic.green)
        : session.archived
        ? (dark ? HermesSemanticDark.gray : HermesSemantic.gray)
        : (dark ? HermesSemanticDark.green : HermesSemantic.green);
    final statusLabel = attention
        ? context.l10n.sessionFilterApproval
        : working
        ? context.l10n.sessionGroupRunning
        : session.archived
        ? context.l10n.sessionGroupArchived
        : context.l10n.sessionFilterCompleted;
    final title = session.title?.trim().isNotEmpty == true
        ? session.title!.trim()
        : context.l10n.sessionUntitled;
    final preview = session.preview?.trim() ?? '';
    final location = sessionLocationLabel(session);

    // Prototype parity (`.tag`): plain codeBg pill by default; a `color`
    // tints the background too UNLESS `tintBackground` is false, in which
    // case only the text recolors (matches the prototype's handoff tag,
    // which is a plain `.tag` with just `color:var(--accent)` — not its own
    // tinted-background treatment).
    Widget tag(String label, {Color? color, bool tintBackground = true}) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color != null && tintBackground
                ? color.withValues(alpha: .16)
                : palette.codeBg,
            borderRadius: BorderRadius.circular(HermesRadius.capsule),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color ?? palette.text3,
              fontSize: 10.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        );

    // Prototype parity (`sourceBadge()`/`.srcbadge`): the session's origin
    // channel gets a SOLID brand-colored capsule with white text — visually
    // distinct from the light-tinted `tag()` pills above, so a scanning list
    // can spot the channel (微信/飞书/Telegram/…) at a glance. Reuses the
    // app's own brand color tokens where the channel already has one.
    (String, Color) sourceBadgeInfo() {
      final raw = (session.source ?? session.sessionSource ?? '')
          .trim()
          .toLowerCase();
      return switch (raw) {
        'cli' => ('CLI', const Color(0xFF333333)),
        'weixin' || 'wechat' => (
          context.l10n.messageSourceWechat,
          HermesProviderBrand.wechat,
        ),
        'feishu' => (
          context.l10n.messageSourceFeishu,
          HermesProviderBrand.feishu,
        ),
        'telegram' => ('Telegram', HermesProviderBrand.telegram),
        'discord' => ('Discord', HermesProviderBrand.discord),
        'whatsapp' => ('WhatsApp', HermesProviderBrand.whatsapp),
        'imessage' ||
        'bluebubbles' => ('iMessage', HermesProviderBrand.imessage),
        'signal' => ('Signal', HermesProviderBrand.signal),
        'dingtalk' => (
          context.l10n.messageSourceDingtalk,
          HermesProviderBrand.dingtalk,
        ),
        'slack' => ('Slack', HermesProviderBrand.slack),
        'webui' ||
        'mobile' ||
        '' => (session.displaySource, HermesBrand.signalBlue),
        'server' => (
          'Server',
          dark ? HermesSemanticDark.gray : HermesSemantic.gray,
        ),
        _ => (
          session.displaySource,
          dark ? HermesSemanticDark.gray : HermesSemantic.gray,
        ),
      };
    }

    Widget sourceBadge() {
      final (label, color) = sourceBadgeInfo();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(HermesRadius.capsule),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    Widget stat(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: palette.text4),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: palette.text3, fontSize: 11)),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Prototype parity (`sessionRow()`'s `.avatar`): a gradient
        // rounded-square "logo" badge with the session's first-letter
        // initial, reusing `HermesAvatar`'s gradient mode. A customized
        // per-session color (if set) becomes the badge's own base color
        // instead of a separate redundant dot next to the title.
        HermesAvatar(
          label: title,
          size: 37,
          color: sessionColor,
          gradient: true,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (session.pinned) ...[
                    Icon(Icons.push_pin, size: 13, color: palette.accent),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 14.5,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (extraBadges != null) ...[
                    const SizedBox(width: 6),
                    extraBadges!,
                  ],
                  const SizedBox(width: 8),
                  HermesMobileStatusChip(
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text3,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  stat(
                    Icons.chat_bubble_outline,
                    context.l10n.sessionMessageCount(session.messageCount ?? 0),
                  ),
                  stat(
                    Icons.build_outlined,
                    context.l10n.sessionToolCount(session.toolCallCount),
                  ),
                  stat(Icons.bolt_outlined, '${session.apiCallCount} API'),
                  stat(
                    Icons.data_usage_outlined,
                    '${compactSessionTokenCount(session.totalTokens)} tok',
                  ),
                  if ((session.actualCostUsd ?? session.estimatedCostUsd) > 0)
                    stat(
                      Icons.attach_money,
                      (session.actualCostUsd ?? session.estimatedCostUsd)
                          .toStringAsFixed(2),
                    ),
                  if (session.duration != null)
                    stat(
                      Icons.schedule_outlined,
                      formatSessionDurationLocalized(
                        context,
                        session.duration!,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        sourceBadge(),
                        if (session.model?.isNotEmpty == true)
                          tag(session.model!),
                        if (session.gitBranch?.isNotEmpty == true)
                          tag(session.gitBranch!),
                        if (location?.isNotEmpty == true) tag(location!),
                        if (session.handoffState?.isNotEmpty == true)
                          tag(
                            context.l10n.sessionHandoff(session.handoffState!),
                            color: palette.accent,
                            tintBackground: false,
                          ),
                      ],
                    ),
                  ),
                  if (childrenCount > 0)
                    IconButton(
                      key: expandButtonKey,
                      tooltip: expanded
                          ? context.l10n.sessionCollapseChildren
                          : context.l10n.sessionExpandChildren,
                      visualDensity: VisualDensity.compact,
                      onPressed: onToggleExpand,
                      icon: AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: HermesMotion.standard,
                        child: const Icon(Icons.expand_more, size: 18),
                      ),
                    ),
                  if (onMore != null)
                    IconButton(
                      tooltip: context.l10n.sessionActions,
                      visualDensity: VisualDensity.compact,
                      onPressed: onMore,
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: palette.text3,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
