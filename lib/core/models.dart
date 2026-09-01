/// Data models mirroring the Hermes gateway / backend JSON contracts.
library;

import '../l10n/runtime_l10n.dart';

import 'time_parsing.dart';

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

class ServerStatus {
  final String? hermesVersion;
  final String? runtimeKind;
  final String? sourceRoot;
  final String? hermesHome;
  final bool backendRunning;
  final String? model;
  final String? provider;
  final int? contextLength;
  final String? readyError;

  ServerStatus({
    this.hermesVersion,
    this.runtimeKind,
    this.sourceRoot,
    this.hermesHome,
    required this.backendRunning,
    this.model,
    this.provider,
    this.contextLength,
    this.readyError,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) {
    final backend = json['backend'] as Map? ?? const {};
    final model = backend['model'] as Map?;
    final runtime = json['runtime'] as Map?;
    return ServerStatus(
      hermesVersion: backend['hermes_version']?.toString(),
      runtimeKind: runtime?['kind']?.toString(),
      sourceRoot: runtime?['source_root']?.toString(),
      hermesHome: runtime?['hermes_home']?.toString(),
      backendRunning: backend['running'] == true,
      model: model?['model']?.toString(),
      provider: model?['provider']?.toString(),
      contextLength: (model?['context_length'] as num?)?.toInt(),
      readyError: json['ready_error']?.toString(),
    );
  }
}

/// Persisted composer draft (WebUI parity: `_saveComposerDraft`).
class ComposerDraft {
  final String text;
  final List<dynamic> files;

  const ComposerDraft({this.text = '', this.files = const []});

  factory ComposerDraft.fromJson(Map<String, dynamic>? json) => ComposerDraft(
    text: json?['text']?.toString() ?? '',
    files: (json?['files'] as List?) ?? const [],
  );

  bool get hasPayload => text.isNotEmpty || files.isNotEmpty;

  Map<String, dynamic> toJson() => {'text': text, 'files': files};
}

/// A paged session-list response (desktop sidebar parity: offset + total +
/// has_more so the client can render a "load more" row).
class SessionPage {
  final List<SessionRow> sessions;
  final int? total;
  final int offset;
  final bool hasMore;

  const SessionPage({
    required this.sessions,
    this.total,
    required this.offset,
    required this.hasMore,
  });
}

/// A transcript page. [total] uses the same raw-history row address space as
/// the messages endpoint's offset.
class SessionMessagesPage {
  final List<dynamic> messages;
  final int? total;

  const SessionMessagesPage({required this.messages, this.total});
}

// ---------------------------------------------------------------------------
// Desktop parity: projects.tree RPC models (authoritative project → repo →
// lane hierarchy built server-side by hermes' tui_gateway/project_tree.py).
// ---------------------------------------------------------------------------

/// A lane inside a repo — a branch/worktree grouping of sessions.
class SessionGroupNode {
  final String id;
  final String label;
  final String? path;
  final List<SessionRow> sessions;
  final bool isMain;
  final bool isKanban;
  final bool isHome;

  const SessionGroupNode({
    required this.id,
    required this.label,
    this.path,
    this.sessions = const [],
    this.isMain = false,
    this.isKanban = false,
    this.isHome = false,
  });

  factory SessionGroupNode.fromJson(Map<String, dynamic> json) {
    return SessionGroupNode(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      path: json['path']?.toString(),
      sessions: ((json['sessions'] as List?) ?? const [])
          .map((e) => SessionRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      isMain: json['isMain'] == true,
      isKanban: json['isKanban'] == true,
      isHome: json['isHome'] == true,
    );
  }
}

/// A repository inside a project (common git root, linked worktrees folded).
class WorkspaceTreeNode {
  final String id;
  final String label;
  final String? path;
  final List<SessionGroupNode> groups;
  final int sessionCount;

  const WorkspaceTreeNode({
    required this.id,
    required this.label,
    this.path,
    this.groups = const [],
    this.sessionCount = 0,
  });

  factory WorkspaceTreeNode.fromJson(Map<String, dynamic> json) {
    return WorkspaceTreeNode(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      path: json['path']?.toString(),
      groups: ((json['groups'] as List?) ?? const [])
          .map(
            (e) =>
                SessionGroupNode.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A project node — explicit (projects.db row), auto (repo-root promotion)
/// or the synthetic Home bucket (id `__no_project__`).
class ProjectTreeNode {
  final String id;
  final String label;
  final String? path;
  final String? color;
  final String? icon;
  final bool isAuto;
  final bool isNoProject;
  final int sessionCount;
  final double? lastActive;
  final int totalTokens;
  final double totalCostUsd;
  final List<WorkspaceTreeNode> repos;
  final List<SessionRow> previewSessions;

  const ProjectTreeNode({
    required this.id,
    required this.label,
    this.path,
    this.color,
    this.icon,
    this.isAuto = false,
    this.isNoProject = false,
    this.sessionCount = 0,
    this.lastActive,
    this.totalTokens = 0,
    this.totalCostUsd = 0,
    this.repos = const [],
    this.previewSessions = const [],
  });

  static const noProjectId = '__no_project__';

  factory ProjectTreeNode.fromJson(Map<String, dynamic> json) {
    return ProjectTreeNode(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      path: json['path']?.toString(),
      color: json['color']?.toString(),
      icon: json['icon']?.toString(),
      isAuto: json['isAuto'] == true,
      isNoProject: json['isNoProject'] == true,
      sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
      lastActive: (json['lastActive'] as num?)?.toDouble(),
      totalTokens: (json['totalTokens'] as num?)?.toInt() ?? 0,
      totalCostUsd: (json['totalCostUsd'] as num?)?.toDouble() ?? 0,
      repos: ((json['repos'] as List?) ?? const [])
          .map(
            (e) =>
                WorkspaceTreeNode.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      previewSessions: ((json['previewSessions'] as List?) ?? const [])
          .map((e) => SessionRow.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Response payload of `projects.tree` (desktop ProjectTreePayload parity).
class ProjectTreePayload {
  final List<ProjectTreeNode> projects;
  final String? activeId;
  final Set<String> scopedSessionIds;

  const ProjectTreePayload({
    required this.projects,
    this.activeId,
    this.scopedSessionIds = const {},
  });

  factory ProjectTreePayload.fromJson(Map<String, dynamic> json) {
    return ProjectTreePayload(
      projects: ((json['projects'] as List?) ?? const [])
          .map(
            (e) => ProjectTreeNode.fromJson((e as Map).cast<String, dynamic>()),
          )
          .toList(),
      activeId: json['active_id']?.toString(),
      scopedSessionIds: ((json['scoped_session_ids'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet(),
    );
  }
}

class SubagentProjection {
  final List<SessionRow> sessions;
  final Map<String, List<SubagentNode>> bySession;
  final int total;

  const SubagentProjection({
    required this.sessions,
    required this.bySession,
    required this.total,
  });

  factory SubagentProjection.fromJson(Map<String, dynamic> json) {
    final grouped = (json['by_session'] as Map?) ?? const {};
    return SubagentProjection(
      sessions: (json['sessions'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => SessionRow.fromJson(row.cast<String, dynamic>()))
          .toList(growable: false),
      bySession: grouped.map(
        (key, value) => MapEntry(
          key.toString(),
          (value as List? ?? const [])
              .whereType<Map>()
              .map(
                (node) => SubagentNode.fromJson(node.cast<String, dynamic>()),
              )
              .toList(growable: false),
        ),
      ),
      total: (json['total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// A stored session row from `GET /api/v1/sessions`.
///
/// WebUI agent-session parity fields: streaming flags, pinned/archived state,
/// composer draft, profile, last_message_at — used by the sidebar for unread
/// dots, streaming spinners, grouping and draft restoration.
class SessionRow {
  final String id;
  final String? title;
  final String? preview;
  final int? messageCount;
  final String? source;
  final String? cwd;
  final String? gitRepoRoot;
  final String? gitBranch;
  final String? parentSessionId;
  final String? projectId;
  final String? model;
  final String? provider;
  final String? sessionSource;
  final String? sourceLabel;
  final bool isSubagent;
  final bool readOnly;
  final bool isCliSession;
  final String? shareToken;
  final DateTime? shareCreatedAt;
  final String? worktreePath;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? endReason;
  final DateTime? lastActivityAt;
  final String? lastActivityDescription;
  final int toolCallCount;
  final int apiCallCount;
  final int inputTokens;
  final int outputTokens;
  final int cacheReadTokens;
  final int cacheWriteTokens;
  final int reasoningTokens;
  final double estimatedCostUsd;
  final double? actualCostUsd;
  final String? costStatus;
  final String? costSource;
  final String? billingProvider;
  final String? billingMode;
  final String? userId;
  final String? sessionKey;
  final String? chatId;
  final String? chatType;
  final String? displayName;
  final String? threadId;
  final String? originJson;
  final bool expiryFinalized;
  final String? billingBaseUrl;
  final String? pricingVersion;
  final String? titleSource;
  final String? lastActivityProvenance;
  final bool unread;
  final bool isActive;
  final bool isDefaultProfile;
  final bool hidden;
  final DateTime? lastReadAt;
  final String? handoffState;
  final String? handoffPlatform;
  final String? handoffError;
  final int rewindCount;
  final DateTime? compressionFailureCooldownUntil;
  final String? compressionFailureError;
  final int compressionFallbackStreak;
  final int compressionIneffectiveCount;
  // ── Desktop parity: durable lineage root (compression lineage anchor).
  // Keys client-side persistent state (pin order, colors) so rotated ids
  // keep their identity — desktop: `_lineage_root_id ?? id`.
  final String? lineageRootId;
  // ── WebUI parity: live sidebar state ──
  final bool isStreaming;
  final bool cronRunning;
  final bool pendingUserMessage;
  final bool hasPendingUserMessage;
  final String? activeStreamId;
  final int? lastMessageAt;
  final bool archived;
  final bool pinned;

  /// WebUI sidebar metadata. Search responses include tags, a text excerpt and
  /// (when available) the precise message that produced the hit.
  final List<String> tags;
  final String? contentSnippet;
  final String? matchMessageId;
  final ComposerDraft composerDraft;
  final String? profile;

  SessionRow({
    required this.id,
    this.title,
    this.preview,
    this.messageCount,
    this.source,
    this.cwd,
    this.gitRepoRoot,
    this.gitBranch,
    this.parentSessionId,
    this.projectId,
    this.model,
    this.provider,
    this.sessionSource,
    this.sourceLabel,
    this.isSubagent = false,
    this.readOnly = false,
    this.isCliSession = false,
    this.shareToken,
    this.shareCreatedAt,
    this.worktreePath,
    this.lineageRootId,
    this.startedAt,
    this.endedAt,
    this.endReason,
    this.lastActivityAt,
    this.lastActivityDescription,
    this.toolCallCount = 0,
    this.apiCallCount = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cacheReadTokens = 0,
    this.cacheWriteTokens = 0,
    this.reasoningTokens = 0,
    this.estimatedCostUsd = 0,
    this.actualCostUsd,
    this.costStatus,
    this.costSource,
    this.billingProvider,
    this.billingMode,
    this.userId,
    this.sessionKey,
    this.chatId,
    this.chatType,
    this.displayName,
    this.threadId,
    this.originJson,
    this.expiryFinalized = false,
    this.billingBaseUrl,
    this.pricingVersion,
    this.titleSource,
    this.lastActivityProvenance,
    this.unread = false,
    this.isActive = false,
    this.isDefaultProfile = false,
    this.hidden = false,
    this.lastReadAt,
    this.handoffState,
    this.handoffPlatform,
    this.handoffError,
    this.rewindCount = 0,
    this.compressionFailureCooldownUntil,
    this.compressionFailureError,
    this.compressionFallbackStreak = 0,
    this.compressionIneffectiveCount = 0,
    this.isStreaming = false,
    this.cronRunning = false,
    this.pendingUserMessage = false,
    this.hasPendingUserMessage = false,
    this.activeStreamId,
    this.lastMessageAt,
    this.archived = false,
    this.pinned = false,
    this.tags = const [],
    this.contentSnippet,
    this.matchMessageId,
    this.composerDraft = const ComposerDraft(),
    this.profile,
  });

  factory SessionRow.fromJson(Map<String, dynamic> json) {
    final started = json['started_at'];
    // Tree projections (projects.tree lanes) expose `last_active` instead of
    // `last_message_at`; accept both so lane rows reuse the sidebar row model.
    final lastMsgAt = json['last_message_at'] ?? json['last_active'];
    List<String> parseTags(dynamic value) {
      if (value is List) {
        return value
            .map((tag) => tag.toString().trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
      if (value is String) {
        return value
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
      return const [];
    }

    final rawSource = (json['source'] ?? json['session_source'])?.toString();
    final hasParent =
        (json['parent_session_id'] ?? json['parent_id'])
            ?.toString()
            .trim()
            .isNotEmpty ==
        true;
    final isSubagent = rawSource?.toLowerCase() == 'subagent' && hasParent;
    return SessionRow(
      id: (json['id'] ?? json['session_id'] ?? '').toString(),
      title: json['title']?.toString(),
      preview: json['preview']?.toString(),
      messageCount: _parseInt(json['message_count']),
      source: json['source']?.toString(),
      cwd: json['cwd']?.toString(),
      gitRepoRoot: json['git_repo_root']?.toString(),
      gitBranch: json['git_branch']?.toString(),
      parentSessionId: (json['parent_session_id'] ?? json['parent_id'])
          ?.toString(),
      projectId: json['project_id']?.toString(),
      model: json['model']?.toString(),
      provider: (json['provider'] ?? json['model_provider'])?.toString(),
      sessionSource: json['session_source']?.toString(),
      sourceLabel: json['source_label']?.toString(),
      isSubagent: isSubagent,
      readOnly:
          isSubagent ||
          json['read_only'] == true ||
          json['is_read_only'] == true,
      isCliSession: !isSubagent && json['is_cli_session'] == true,
      shareToken: json['share_token']?.toString(),
      shareCreatedAt: parseHermesTime(json['share_created_at']),
      worktreePath: json['worktree_path']?.toString(),
      lineageRootId: (json['_lineage_root_id'] ?? json['lineage_root_id'])
          ?.toString(),
      startedAt: parseHermesTime(started ?? json['created_at']),
      endedAt: parseHermesTime(json['ended_at']),
      endReason: json['end_reason']?.toString(),
      lastActivityAt: parseHermesTime(json['last_activity_at'] ?? lastMsgAt),
      lastActivityDescription: json['last_activity_description']?.toString(),
      toolCallCount: (json['tool_call_count'] as num?)?.toInt() ?? 0,
      apiCallCount: (json['api_call_count'] as num?)?.toInt() ?? 0,
      inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
      cacheReadTokens: (json['cache_read_tokens'] as num?)?.toInt() ?? 0,
      cacheWriteTokens: (json['cache_write_tokens'] as num?)?.toInt() ?? 0,
      reasoningTokens: (json['reasoning_tokens'] as num?)?.toInt() ?? 0,
      estimatedCostUsd: (json['estimated_cost_usd'] as num?)?.toDouble() ?? 0,
      actualCostUsd: (json['actual_cost_usd'] as num?)?.toDouble(),
      costStatus: json['cost_status']?.toString(),
      costSource: json['cost_source']?.toString(),
      billingProvider: json['billing_provider']?.toString(),
      billingMode: json['billing_mode']?.toString(),
      userId: json['user_id']?.toString(),
      sessionKey: json['session_key']?.toString(),
      chatId: json['chat_id']?.toString(),
      chatType: json['chat_type']?.toString(),
      displayName: json['display_name']?.toString(),
      threadId: json['thread_id']?.toString(),
      originJson: json['origin_json']?.toString(),
      expiryFinalized:
          json['expiry_finalized'] == true || json['expiry_finalized'] == 1,
      billingBaseUrl: json['billing_base_url']?.toString(),
      pricingVersion: json['pricing_version']?.toString(),
      titleSource: json['title_source']?.toString(),
      lastActivityProvenance: json['last_activity_provenance']?.toString(),
      unread: json['unread'] == true,
      isActive:
          json['is_active'] == true ||
          json['active'] == true ||
          json['isActive'] == true,
      isDefaultProfile: json['is_default_profile'] == true,
      hidden: json['hidden'] == true || json['hidden'] == 1,
      lastReadAt: parseHermesTime(json['last_read_at']),
      handoffState: json['handoff_state']?.toString(),
      handoffPlatform: json['handoff_platform']?.toString(),
      handoffError: json['handoff_error']?.toString(),
      rewindCount: (json['rewind_count'] as num?)?.toInt() ?? 0,
      compressionFailureCooldownUntil: parseHermesTime(
        json['compression_failure_cooldown_until'],
      ),
      compressionFailureError: json['compression_failure_error']?.toString(),
      compressionFallbackStreak:
          (json['compression_fallback_streak'] as num?)?.toInt() ?? 0,
      compressionIneffectiveCount:
          (json['compression_ineffective_count'] as num?)?.toInt() ?? 0,
      isStreaming: json['is_streaming'] == true,
      cronRunning: json['cron_running'] == true,
      pendingUserMessage: json['pending_user_message'] == true,
      hasPendingUserMessage: json['has_pending_user_message'] == true,
      activeStreamId: json['active_stream_id']?.toString(),
      lastMessageAt: parseHermesEpochMillis(lastMsgAt ?? json['updated_at']),
      archived: json['archived'] == true,
      pinned: json['pinned'] == true,
      tags: parseTags(json['tags']),
      contentSnippet:
          (json['content_snippet'] ?? json['snippet'] ?? json['summary'])
              ?.toString(),
      matchMessageId: (json['match_message_id'] ?? json['message_id'])
          ?.toString(),
      composerDraft: ComposerDraft.fromJson(
        (json['composer_draft'] as Map?)?.cast<String, dynamic>(),
      ),
      profile: json['profile']?.toString(),
    );
  }

  SessionRow copyWith({String? profile}) => SessionRow(
    id: id,
    title: title,
    preview: preview,
    messageCount: messageCount,
    source: source,
    cwd: cwd,
    gitRepoRoot: gitRepoRoot,
    gitBranch: gitBranch,
    parentSessionId: parentSessionId,
    projectId: projectId,
    model: model,
    provider: provider,
    sessionSource: sessionSource,
    sourceLabel: sourceLabel,
    isSubagent: isSubagent,
    readOnly: readOnly,
    isCliSession: isCliSession,
    shareToken: shareToken,
    shareCreatedAt: shareCreatedAt,
    worktreePath: worktreePath,
    lineageRootId: lineageRootId,
    startedAt: startedAt,
    endedAt: endedAt,
    endReason: endReason,
    lastActivityAt: lastActivityAt,
    lastActivityDescription: lastActivityDescription,
    toolCallCount: toolCallCount,
    apiCallCount: apiCallCount,
    inputTokens: inputTokens,
    outputTokens: outputTokens,
    cacheReadTokens: cacheReadTokens,
    cacheWriteTokens: cacheWriteTokens,
    reasoningTokens: reasoningTokens,
    estimatedCostUsd: estimatedCostUsd,
    actualCostUsd: actualCostUsd,
    costStatus: costStatus,
    costSource: costSource,
    billingProvider: billingProvider,
    billingMode: billingMode,
    userId: userId,
    sessionKey: sessionKey,
    chatId: chatId,
    chatType: chatType,
    displayName: displayName,
    threadId: threadId,
    originJson: originJson,
    expiryFinalized: expiryFinalized,
    billingBaseUrl: billingBaseUrl,
    pricingVersion: pricingVersion,
    titleSource: titleSource,
    lastActivityProvenance: lastActivityProvenance,
    unread: unread,
    isActive: isActive,
    isDefaultProfile: isDefaultProfile,
    hidden: hidden,
    lastReadAt: lastReadAt,
    handoffState: handoffState,
    handoffPlatform: handoffPlatform,
    handoffError: handoffError,
    rewindCount: rewindCount,
    compressionFailureCooldownUntil: compressionFailureCooldownUntil,
    compressionFailureError: compressionFailureError,
    compressionFallbackStreak: compressionFallbackStreak,
    compressionIneffectiveCount: compressionIneffectiveCount,
    isStreaming: isStreaming,
    cronRunning: cronRunning,
    pendingUserMessage: pendingUserMessage,
    hasPendingUserMessage: hasPendingUserMessage,
    activeStreamId: activeStreamId,
    lastMessageAt: lastMessageAt,
    archived: archived,
    pinned: pinned,
    tags: tags,
    contentSnippet: contentSnippet,
    matchMessageId: matchMessageId,
    composerDraft: composerDraft,
    profile: profile ?? this.profile,
  );

  bool get isDelegatedChild {
    final raw = (source ?? sessionSource ?? '').trim().toLowerCase();
    return raw == 'subagent' && parentSessionId?.trim().isNotEmpty == true;
  }

  /// WebUI child-session parity: any non-continuation row with a parent,
  /// regardless of source (subagent, desktop delegates, weixin, …).
  /// The server projection already collapses compression continuations, so a
  /// row reaching the client with a parent id is a genuine child session.
  bool get isChildSession => parentSessionId?.trim().isNotEmpty == true;

  /// True when the row represents an in-flight / background-running turn.
  /// Mirrors WebUI `_isSessionEffectivelyStreaming` (minus the local
  /// `S.busy` flag which is known only for the currently open chat).
  bool get effectivelyStreaming =>
      isStreaming || cronRunning || pendingUserMessage || hasPendingUserMessage;

  /// Filter-bucket `attention`: pending user input / approval style waits.
  bool get needsAttention => pendingUserMessage || hasPendingUserMessage;

  /// Filter-bucket `working` without folding pending into the spinner.
  bool get isActivelyWorking => isStreaming || cronRunning;

  int get totalTokens =>
      inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens;

  Duration? get duration {
    final start = startedAt;
    final end = endedAt ?? lastActivityAt;
    if (start == null || end == null || end.isBefore(start)) return null;
    return end.difference(start);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'preview': preview,
    'message_count': messageCount,
    'source': source,
    'cwd': cwd,
    'git_repo_root': gitRepoRoot,
    'git_branch': gitBranch,
    'parent_session_id': parentSessionId,
    'project_id': projectId,
    'model': model,
    'provider': provider,
    'session_source': sessionSource,
    'source_label': sourceLabel,
    'is_subagent': isSubagent,
    'read_only': readOnly,
    'is_cli_session': isCliSession,
    'share_token': shareToken,
    'share_created_at': shareCreatedAt?.toIso8601String(),
    'worktree_path': worktreePath,
    '_lineage_root_id': lineageRootId,
    'started_at': startedAt?.toIso8601String(),
    'ended_at': endedAt?.toIso8601String(),
    'end_reason': endReason,
    'last_activity_at': lastActivityAt?.toIso8601String(),
    'last_activity_description': lastActivityDescription,
    'tool_call_count': toolCallCount,
    'api_call_count': apiCallCount,
    'input_tokens': inputTokens,
    'output_tokens': outputTokens,
    'cache_read_tokens': cacheReadTokens,
    'cache_write_tokens': cacheWriteTokens,
    'reasoning_tokens': reasoningTokens,
    'estimated_cost_usd': estimatedCostUsd,
    'actual_cost_usd': actualCostUsd,
    'cost_status': costStatus,
    'cost_source': costSource,
    'billing_provider': billingProvider,
    'billing_mode': billingMode,
    'user_id': userId,
    'session_key': sessionKey,
    'chat_id': chatId,
    'chat_type': chatType,
    'display_name': displayName,
    'thread_id': threadId,
    'origin_json': originJson,
    'expiry_finalized': expiryFinalized,
    'billing_base_url': billingBaseUrl,
    'pricing_version': pricingVersion,
    'title_source': titleSource,
    'last_activity_provenance': lastActivityProvenance,
    'unread': unread,
    'is_active': isActive,
    'is_default_profile': isDefaultProfile,
    'hidden': hidden,
    'last_read_at': lastReadAt?.toIso8601String(),
    'handoff_state': handoffState,
    'handoff_platform': handoffPlatform,
    'handoff_error': handoffError,
    'rewind_count': rewindCount,
    'compression_failure_cooldown_until': compressionFailureCooldownUntil
        ?.toIso8601String(),
    'compression_failure_error': compressionFailureError,
    'compression_fallback_streak': compressionFallbackStreak,
    'compression_ineffective_count': compressionIneffectiveCount,
    'is_streaming': isStreaming,
    'cron_running': cronRunning,
    'pending_user_message': pendingUserMessage,
    'has_pending_user_message': hasPendingUserMessage,
    'active_stream_id': activeStreamId,
    'last_message_at': lastMessageAt,
    'archived': archived,
    'pinned': pinned,
    'tags': tags,
    'content_snippet': contentSnippet,
    'match_message_id': matchMessageId,
    'composer_draft': composerDraft.toJson(),
    'profile': profile,
  };

  /// Stable display label for WebUI, CLI and messaging-origin sessions.
  String get displaySource {
    final explicit = sourceLabel?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final raw = (source ?? sessionSource ?? '').trim();
    if (raw.isEmpty || raw == 'webui' || raw == 'mobile') return 'Hermes';
    return raw;
  }
}

/// A message from `session.resume` / `GET .../sessions/{id}/messages`.
class SessionMessage {
  final String role; // user | assistant | tool | system
  final dynamic content;
  final String? text;
  final String? context;
  final String? name;
  final String? toolName;
  final int? rowId;
  final dynamic reasoning;
  final String? reasoningContent;
  final String? displayKind;
  final Map<String, dynamic>? displayMetadata;
  final int? timestamp;
  // ── 桌面版同构元数据：渠道来源、使用模型、供应商 ──
  final String?
  source; // webui | weixin | feishu | cli | telegram | discord | server …
  final String? model;
  final String? provider;

  SessionMessage({
    required this.role,
    this.content,
    this.text,
    this.context,
    this.name,
    this.toolName,
    this.rowId,
    this.reasoning,
    this.reasoningContent,
    this.displayKind,
    this.displayMetadata,
    this.timestamp,
    this.source,
    this.model,
    this.provider,
  });

  String get bodyText {
    if (text != null && text!.isNotEmpty) return text!;
    if (content is String) return content as String;
    return '';
  }

  factory SessionMessage.fromJson(Map<String, dynamic> json) {
    return SessionMessage(
      role: (json['role'] ?? 'user').toString(),
      content: json['content'],
      text: json['text']?.toString(),
      context: json['context']?.toString(),
      name: json['name']?.toString(),
      toolName: json['tool_name']?.toString(),
      rowId: _parseInt(json['row_id']),
      reasoning: json['reasoning'],
      reasoningContent: json['reasoning_content']?.toString(),
      displayKind: json['display_kind']?.toString(),
      displayMetadata: (json['display_metadata'] as Map?)
          ?.cast<String, dynamic>(),
      timestamp: _parseInt(json['timestamp']),
      source:
          json['source']?.toString() ??
          json['channel']?.toString() ??
          (json['metadata'] is Map
                  ? ((json['metadata'] as Map)['source'] ??
                        (json['metadata'] as Map)['channel'])
                  : null)
              ?.toString(),
      model:
          json['model']?.toString() ??
          (json['metadata'] is Map
              ? (json['metadata'] as Map)['model']?.toString()
              : null),
      provider:
          json['provider']?.toString() ??
          (json['metadata'] is Map
              ? (json['metadata'] as Map)['provider']?.toString()
              : null),
    );
  }
}

/// Runtime info returned by session.create/resume.
class SessionInfo {
  final String? model;
  final String? provider;
  final String? cwd;
  final String? branch;
  final String? title;
  final bool running;
  final Map<String, dynamic>? raw;

  /// Desktop parity — conversation-scoped selector state.
  final String? personality;
  final String? workspace;
  final String? difficulty;
  final String? toolsConfig;

  SessionInfo({
    this.model,
    this.provider,
    this.cwd,
    this.branch,
    this.title,
    this.running = false,
    this.raw,
    this.personality,
    this.workspace,
    this.difficulty,
    this.toolsConfig,
  });

  factory SessionInfo.fromJson(Map<String, dynamic> json) {
    return SessionInfo(
      model: json['model']?.toString(),
      provider: json['provider']?.toString(),
      cwd: json['cwd']?.toString(),
      branch: json['branch']?.toString(),
      title: json['title']?.toString(),
      running: json['running'] == true,
      raw: json,
      personality: json['personality']?.toString(),
      workspace: json['workspace']?.toString(),
      difficulty: json['difficulty']?.toString(),
      toolsConfig: (json['tools_config'] ?? json['toolsConfig'])?.toString(),
    );
  }

  SessionInfo copyWith({
    String? model,
    String? provider,
    String? cwd,
    String? branch,
    String? title,
    bool? running,
    String? personality,
    String? workspace,
    String? difficulty,
    String? toolsConfig,
    Map<String, dynamic>? raw,
  }) {
    return SessionInfo(
      model: model ?? this.model,
      provider: provider ?? this.provider,
      cwd: cwd ?? this.cwd,
      branch: branch ?? this.branch,
      title: title ?? this.title,
      running: running ?? this.running,
      raw: raw ?? this.raw,
      personality: personality ?? this.personality,
      workspace: workspace ?? this.workspace,
      difficulty: difficulty ?? this.difficulty,
      toolsConfig: toolsConfig ?? this.toolsConfig,
    );
  }
}

/// Model option entry from `model.options`.
class ModelInfo {
  final String slug;
  final String name;
  final bool isCurrent;
  final List<String> models;
  final Map<String, ModelPricing> pricing;

  const ModelInfo({
    required this.slug,
    required this.name,
    required this.isCurrent,
    required this.models,
    this.pricing = const {},
  });

  String get provider => slug;

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? json['slug'] ?? '').toString(),
      isCurrent: json['is_current'] == true,
      models:
          (json['models'] as List?)?.map((e) => e.toString()).toList() ?? [],
      pricing: (json['pricing'] as Map? ?? const {}).map(
        (key, value) => MapEntry(
          '$key',
          ModelPricing.fromJson((value as Map).cast<String, dynamic>()),
        ),
      ),
    );
  }
}

class ModelPricing {
  final String input;
  final String output;
  final bool free;
  final int? discountPercent;
  final String? wasInput;
  final String? wasOutput;

  const ModelPricing({
    this.input = '',
    this.output = '',
    this.free = false,
    this.discountPercent,
    this.wasInput,
    this.wasOutput,
  });

  factory ModelPricing.fromJson(Map<String, dynamic> json) => ModelPricing(
    input: json['input']?.toString() ?? '',
    output: json['output']?.toString() ?? '',
    free: json['free'] == true,
    discountPercent: (json['discount_percent'] as num?)?.round(),
    wasInput: json['was_input']?.toString(),
    wasOutput: json['was_output']?.toString(),
  );
}

/// A Hermes profile from `GET /api/v1/profiles`.
///
/// The server normalizes upstream (`/api/profiles`), config-field and local
/// store shapes; unknown fields are preserved in [raw] for forward compat.
class ProfileInfo {
  final String name;
  final String? model;
  final String? provider;
  final double temperature;
  final int maxTokens;
  final double topP;
  final String systemPrompt;
  final List<String> tools;
  final bool isActive;
  final String? description;
  final Map<String, dynamic> raw;

  const ProfileInfo({
    required this.name,
    this.model,
    this.provider,
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.topP = 0.9,
    this.systemPrompt = '',
    this.tools = const [],
    this.isActive = false,
    this.description,
    this.raw = const {},
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> json) {
    return ProfileInfo(
      name: (json['name'] ?? json['id'] ?? '').toString(),
      model: json['model']?.toString(),
      provider: json['provider']?.toString(),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens:
          ((json['max_tokens'] ?? json['maxTokens']) as num?)?.toInt() ?? 4096,
      topP: ((json['top_p'] ?? json['topP']) as num?)?.toDouble() ?? 0.9,
      systemPrompt: (json['system_prompt'] ?? json['systemPrompt'] ?? '')
          .toString(),
      tools:
          (json['tools'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      isActive:
          json['is_active'] == true ||
          json['active'] == true ||
          json['isActive'] == true,
      description: json['description']?.toString(),
      raw: json,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    if (model != null) 'model': model,
    if (provider != null) 'provider': provider,
    'temperature': temperature,
    'max_tokens': maxTokens,
    'top_p': topP,
    'system_prompt': systemPrompt,
    'tools': tools,
    'is_active': isActive,
    if (description != null && description!.isNotEmpty)
      'description': description,
  };

  ProfileInfo copyWith({
    String? name,
    String? model,
    String? provider,
    double? temperature,
    int? maxTokens,
    double? topP,
    String? systemPrompt,
    List<String>? tools,
    bool? isActive,
    String? description,
  }) {
    return ProfileInfo(
      name: name ?? this.name,
      model: model ?? this.model,
      provider: provider ?? this.provider,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      tools: tools ?? this.tools,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      raw: raw,
    );
  }
}

/// Payload of `GET /api/v1/profiles`: the list plus the active profile name.
class ProfilesPayload {
  final List<ProfileInfo> profiles;
  final String? active;
  final String? current;

  /// Which backend surface served the data: upstream | config | local.
  final String source;

  const ProfilesPayload({
    required this.profiles,
    this.active,
    this.current,
    this.source = 'local',
  });

  factory ProfilesPayload.fromJson(Map<String, dynamic> json) {
    String? profileName(dynamic value) {
      if (value is String) {
        final name = value.trim();
        return name.isEmpty ? null : name;
      }
      if (value is Map) {
        final name = (value['name'] ?? value['id'])?.toString().trim();
        return name == null || name.isEmpty ? null : name;
      }
      return null;
    }

    final container = json['data'] is Map
        ? (json['data'] as Map).cast<String, dynamic>()
        : json;
    final profiles = (container['profiles'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ProfileInfo.fromJson(item.cast<String, dynamic>()))
        .where((profile) => profile.name.isNotEmpty)
        .toList();
    var active =
        profileName(container['active']) ??
        profileName(container['active_profile']) ??
        profileName(json['active']) ??
        profileName(json['active_profile']);
    if (active == null) {
      final activeProfiles = profiles.where((profile) => profile.isActive);
      if (activeProfiles.length == 1) active = activeProfiles.single.name;
    }
    final current =
        profileName(container['current']) ??
        profileName(container['current_profile']) ??
        profileName(json['current']) ??
        profileName(json['current_profile']);
    return ProfilesPayload(
      profiles: profiles,
      active: active,
      current: current,
      source: json['source']?.toString() ?? 'local',
    );
  }
}

/// A toolset from `toolsets.list` / `tools.list`.
class ToolsetInfo {
  final String name;
  final String? description;
  final bool enabled;
  final int toolCount;

  ToolsetInfo({
    required this.name,
    this.description,
    required this.enabled,
    this.toolCount = 0,
  });

  factory ToolsetInfo.fromJson(Map<String, dynamic> json) {
    return ToolsetInfo(
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      enabled: json['enabled'] == true,
      toolCount:
          (json['tool_count'] as num?)?.toInt() ??
          (json['tools'] as List?)?.length ??
          0,
    );
  }
}

/// A skill from `GET /api/v1/skills`.
/// `provenance` distinguishes where a skill came from — only `agent`
/// (learned/promoted into the knowledge graph) skills can be edited or
/// archived from the client; `bundled` and `hub` skills are read-only here
/// (a `hub` skill is managed through uninstall/update instead).
class SkillInfo {
  final String name;
  final String? description;
  final bool enabled;
  final String? category;
  final String? provenance;
  final int? usage;

  SkillInfo({
    required this.name,
    this.description,
    required this.enabled,
    this.category,
    this.provenance,
    this.usage,
  });

  bool get isLearned => provenance == 'agent';

  factory SkillInfo.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'];
    return SkillInfo(
      name: (json['name'] ?? json['slug'] ?? '').toString(),
      description: json['description']?.toString(),
      enabled: json['enabled'] == true,
      category: json['category']?.toString(),
      provenance: json['provenance']?.toString(),
      usage: usage is num ? usage.toInt() : int.tryParse('$usage'),
    );
  }

  SkillInfo copyWith({bool? enabled}) => SkillInfo(
    name: name,
    description: description,
    enabled: enabled ?? this.enabled,
    category: category,
    provenance: provenance,
    usage: usage,
  );
}

/// One skill-hub source (official index, GitHub, skills.sh, …) from
/// `GET /api/v1/skills/hub/sources`.
class SkillHubSource {
  final String id;
  final String label;
  final bool available;
  final bool rateLimited;
  final bool searchable;

  SkillHubSource({
    required this.id,
    required this.label,
    this.available = true,
    this.rateLimited = false,
    this.searchable = true,
  });

  factory SkillHubSource.fromJson(Map<String, dynamic> json) => SkillHubSource(
    id: (json['id'] ?? '').toString(),
    label: (json['label'] ?? json['id'] ?? '').toString(),
    available: json['available'] != false,
    rateLimited: json['rate_limited'] == true,
    searchable: json['searchable'] != false,
  );
}

/// A searchable/installable hub skill from `GET /api/v1/skills/hub/search`
/// (also used for the `featured` list in the sources response).
class SkillHubResult {
  final String name;
  final String description;
  final String source;
  final String identifier;
  final String trustLevel;
  final String? repo;
  final List<String> tags;

  SkillHubResult({
    required this.name,
    required this.description,
    required this.source,
    required this.identifier,
    required this.trustLevel,
    this.repo,
    this.tags = const [],
  });

  factory SkillHubResult.fromJson(Map<String, dynamic> json) => SkillHubResult(
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    source: (json['source'] ?? '').toString(),
    identifier: (json['identifier'] ?? '').toString(),
    trustLevel: (json['trust_level'] ?? '').toString(),
    repo: json['repo']?.toString(),
    tags:
        (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// Install-state entry from the `installed` map on the sources/search
/// responses, keyed by skill identifier.
class SkillHubInstalledEntry {
  final String? name;
  final String? trustLevel;
  final String? scanVerdict;

  SkillHubInstalledEntry({this.name, this.trustLevel, this.scanVerdict});

  factory SkillHubInstalledEntry.fromJson(Map<String, dynamic> json) =>
      SkillHubInstalledEntry(
        name: json['name']?.toString(),
        trustLevel: json['trust_level']?.toString(),
        scanVerdict: json['scan_verdict']?.toString(),
      );
}

Map<String, SkillHubInstalledEntry> _parseInstalledMap(dynamic raw) {
  if (raw is! Map) return const {};
  return raw.map(
    (key, value) => MapEntry(
      key.toString(),
      SkillHubInstalledEntry.fromJson(
        value is Map ? value.cast<String, dynamic>() : const {},
      ),
    ),
  );
}

/// `GET /api/v1/skills/hub/sources` response.
class SkillHubSources {
  final List<SkillHubSource> sources;
  final bool indexAvailable;
  final List<SkillHubResult> featured;
  final Map<String, SkillHubInstalledEntry> installed;

  SkillHubSources({
    required this.sources,
    required this.indexAvailable,
    required this.featured,
    required this.installed,
  });

  factory SkillHubSources.fromJson(Map<String, dynamic> json) =>
      SkillHubSources(
        sources:
            (json['sources'] as List?)
                ?.map((e) => SkillHubSource.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        indexAvailable: json['index_available'] == true,
        featured:
            (json['featured'] as List?)
                ?.map((e) => SkillHubResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        installed: _parseInstalledMap(json['installed']),
      );
}

/// `GET /api/v1/skills/hub/search` response.
class SkillHubSearchResult {
  final List<SkillHubResult> results;
  final Map<String, int> sourceCounts;
  final List<String> timedOut;
  final Map<String, SkillHubInstalledEntry> installed;

  SkillHubSearchResult({
    required this.results,
    required this.sourceCounts,
    required this.timedOut,
    required this.installed,
  });

  factory SkillHubSearchResult.fromJson(Map<String, dynamic> json) =>
      SkillHubSearchResult(
        results:
            (json['results'] as List?)
                ?.map((e) => SkillHubResult.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        sourceCounts:
            (json['source_counts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
            ) ??
            const {},
        timedOut:
            (json['timed_out'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        installed: _parseInstalledMap(json['installed']),
      );
}

/// `GET /api/v1/skills/hub/preview` — SKILL.md + manifest without installing.
class SkillHubPreview {
  final String name;
  final String description;
  final String source;
  final String identifier;
  final String trustLevel;
  final String? repo;
  final List<String> tags;
  final String skillMd;
  final List<String> files;

  SkillHubPreview({
    required this.name,
    required this.description,
    required this.source,
    required this.identifier,
    required this.trustLevel,
    this.repo,
    this.tags = const [],
    required this.skillMd,
    this.files = const [],
  });

  factory SkillHubPreview.fromJson(
    Map<String, dynamic> json,
  ) => SkillHubPreview(
    name: (json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    source: (json['source'] ?? '').toString(),
    identifier: (json['identifier'] ?? '').toString(),
    trustLevel: (json['trust_level'] ?? '').toString(),
    repo: json['repo']?.toString(),
    tags:
        (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    skillMd: (json['skill_md'] ?? '').toString(),
    files:
        (json['files'] as List?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

/// One finding from `GET /api/v1/skills/hub/scan`.
class SkillHubScanFinding {
  final String severity;
  final String category;
  final String file;
  final int? line;
  final String description;

  SkillHubScanFinding({
    required this.severity,
    required this.category,
    required this.file,
    this.line,
    required this.description,
  });

  factory SkillHubScanFinding.fromJson(Map<String, dynamic> json) =>
      SkillHubScanFinding(
        severity: (json['severity'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        file: (json['file'] ?? '').toString(),
        line: (json['line'] as num?)?.toInt(),
        description: (json['description'] ?? '').toString(),
      );
}

/// `GET /api/v1/skills/hub/scan` — install-time security scan verdict.
class SkillHubScanResult {
  final String name;
  final String identifier;
  final String source;
  final String trustLevel;
  final String verdict;
  final String summary;
  final String policy; // 'allow' | 'ask' | 'block'
  final String? policyReason;
  final List<SkillHubScanFinding> findings;
  final Map<String, int> severityCounts;

  SkillHubScanResult({
    required this.name,
    required this.identifier,
    required this.source,
    required this.trustLevel,
    required this.verdict,
    required this.summary,
    required this.policy,
    this.policyReason,
    this.findings = const [],
    this.severityCounts = const {},
  });

  factory SkillHubScanResult.fromJson(Map<String, dynamic> json) =>
      SkillHubScanResult(
        name: (json['name'] ?? '').toString(),
        identifier: (json['identifier'] ?? '').toString(),
        source: (json['source'] ?? '').toString(),
        trustLevel: (json['trust_level'] ?? '').toString(),
        verdict: (json['verdict'] ?? '').toString(),
        summary: (json['summary'] ?? '').toString(),
        policy: (json['policy'] ?? 'ask').toString(),
        policyReason: json['policy_reason']?.toString(),
        findings:
            (json['findings'] as List?)
                ?.map(
                  (e) =>
                      SkillHubScanFinding.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
        severityCounts:
            (json['severity_counts'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
            ) ??
            const {},
      );
}

/// A cron job from `GET /api/v1/cron`.
class CronJob {
  final String id;
  final String? name;
  final String? schedule;
  final String? prompt;
  final bool enabled;
  final String? scheduleDisplay;
  final String? deliver;
  final String? state;
  final String? nextRunAt;
  final String? lastRunAt;
  final String? lastError;
  final String? model;
  final String? provider;
  final bool noAgent;
  final String? script;

  CronJob({
    required this.id,
    this.name,
    this.schedule,
    this.prompt,
    required this.enabled,
    this.scheduleDisplay,
    this.deliver,
    this.state,
    this.nextRunAt,
    this.lastRunAt,
    this.lastError,
    this.model,
    this.provider,
    this.noAgent = false,
    this.script,
  });

  factory CronJob.fromJson(Map<String, dynamic> json) {
    final scheduleValue = json['schedule'];
    final schedule = scheduleValue is Map
        ? (scheduleValue['expr'] ?? scheduleValue['display'])?.toString()
        : scheduleValue?.toString();
    return CronJob(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: json['name']?.toString(),
      schedule: schedule,
      scheduleDisplay:
          (json['schedule_display'] ??
                  (scheduleValue is Map ? scheduleValue['display'] : null))
              ?.toString(),
      prompt: json['prompt']?.toString(),
      enabled: json['enabled'] != false,
      deliver: json['deliver']?.toString(),
      state: json['state']?.toString(),
      nextRunAt: json['next_run_at']?.toString(),
      lastRunAt: json['last_run_at']?.toString(),
      lastError: json['last_error']?.toString(),
      model: json['model']?.toString(),
      provider: json['provider']?.toString(),
      noAgent: json['no_agent'] == true,
      script: json['script']?.toString(),
    );
  }

  bool get isScriptOnly => noAgent && script?.trim().isNotEmpty == true;

  /// Effective status — mirrors desktop's `jobState()` (app/cron/job-state.ts):
  /// the backend's explicit `state` wins when present, else inferred from
  /// `enabled`. One of: completed/disabled/enabled/error/paused/running/
  /// scheduled.
  String get effectiveState {
    final trimmed = state?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    return enabled ? 'scheduled' : 'disabled';
  }
}

class CronDeliveryTarget {
  final String id;
  final String name;
  final bool homeTargetSet;
  final String? homeEnvVar;

  const CronDeliveryTarget({
    required this.id,
    required this.name,
    required this.homeTargetSet,
    this.homeEnvVar,
  });

  factory CronDeliveryTarget.fromJson(Map<String, dynamic> json) {
    return CronDeliveryTarget(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? json['id'] ?? '').toString(),
      homeTargetSet: json['home_target_set'] != false,
      homeEnvVar: json['home_env_var']?.toString(),
    );
  }
}

/// A typed slot exposed by Hermes' automation-blueprint catalog.
class CronBlueprintField {
  final String name;
  final String type;
  final String label;
  final String? defaultValue;
  final List<String> options;
  final bool optional;
  final bool strict;
  final String? help;

  const CronBlueprintField({
    required this.name,
    required this.type,
    required this.label,
    this.defaultValue,
    this.options = const [],
    this.optional = false,
    this.strict = true,
    this.help,
  });

  factory CronBlueprintField.fromJson(Map<String, dynamic> json) {
    return CronBlueprintField(
      name: (json['name'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      label: (json['label'] ?? json['name'] ?? '').toString(),
      defaultValue: json['default']?.toString(),
      options: ((json['options'] as List?) ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      optional: json['optional'] == true,
      strict: json['strict'] != false,
      help: json['help']?.toString(),
    );
  }
}

class CronBlueprint {
  final String key;
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final List<CronBlueprintField> fields;
  final String? schedule;
  final String? scheduleHuman;

  const CronBlueprint({
    required this.key,
    required this.title,
    required this.description,
    required this.category,
    required this.tags,
    required this.fields,
    this.schedule,
    this.scheduleHuman,
  });

  factory CronBlueprint.fromJson(Map<String, dynamic> json) {
    return CronBlueprint(
      key: (json['key'] ?? '').toString(),
      title: (json['title'] ?? json['key'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      tags: ((json['tags'] as List?) ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
      fields: ((json['fields'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                CronBlueprintField.fromJson(value.cast<String, dynamic>()),
          )
          .toList(growable: false),
      schedule: json['schedule']?.toString(),
      scheduleHuman: json['scheduleHuman']?.toString(),
    );
  }

  Map<String, String> initialValues() => {
    for (final field in fields)
      field.name:
          field.name == 'deliver' &&
              (field.defaultValue == null ||
                  field.defaultValue!.isEmpty ||
                  field.defaultValue == 'origin')
          ? 'local'
          : field.defaultValue ?? '',
  };
}

/// A file-system entry from `GET /api/v1/files`.
class FsEntry {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isLink;
  final int? size;
  final DateTime? modifiedAt;
  final bool? readable;
  final bool? writable;

  FsEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isLink = false,
    this.size,
    this.modifiedAt,
    this.readable,
    this.writable,
  });

  factory FsEntry.fromJson(Map<String, dynamic> json) {
    return FsEntry(
      name: (json['name'] ?? '').toString(),
      path: (json['path'] ?? '').toString(),
      isDirectory:
          json['isDirectory'] == true ||
          json['is_directory'] == true ||
          json['type'] == 'directory',
      isLink: json['is_link'] == true || json['type'] == 'link',
      size: (json['size'] as num?)?.toInt(),
      modifiedAt: parseHermesTime(
        json['modified_at'] ?? json['mtime'] ?? json['modified'],
      ),
      readable: json['readable'] as bool?,
      writable: json['writable'] as bool?,
    );
  }
}

/// An artifact discovered in a session transcript.
class ArtifactRecord {
  final String kind; // image | file | link | code
  final String value;
  final String? label;
  final String sessionId;
  final String? sessionTitle;

  ArtifactRecord({
    required this.kind,
    required this.value,
    this.label,
    required this.sessionId,
    this.sessionTitle,
  });
}

/// A task on Hermes' canonical Kanban board.
class TaskItem {
  final String id;
  final String title;
  final String prompt;
  final String priority; // low | normal | high | urgent
  final String
  status; // triage | todo | scheduled | ready | running | blocked | review | done | archived
  final String? sessionId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  TaskItem({
    required this.id,
    required this.title,
    required this.prompt,
    required this.priority,
    required this.status,
    this.sessionId,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    DateTime? dt(Object? v) =>
        v is String ? DateTime.tryParse(v)?.toLocal() : null;
    return TaskItem(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      status: (json['status'] ?? 'triage').toString(),
      sessionId: json['session_id']?.toString(),
      createdAt: dt(json['created_at']),
      updatedAt: dt(json['updated_at']),
      completedAt: dt(json['completed_at']),
    );
  }

  TaskItem copyWith({
    String? title,
    String? prompt,
    String? priority,
    String? status,
    String? sessionId,
    DateTime? completedAt,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  bool get isRunning => status == 'running';
  bool get isDone => status == 'done';
}

// ============================================================
// D5-extended models (2026-08 migration)
// ============================================================

/// A subagent node in a spawn tree.
/// One line of a subagent's live activity feed — a port of desktop's
/// `SubagentStreamEntry` (store/subagents.ts). `kind` is one of
/// progress/summary/thinking/tool.
class SubagentStreamEntry {
  final int at;
  final bool isError;
  final String kind;
  final String text;

  const SubagentStreamEntry({
    required this.at,
    this.isError = false,
    required this.kind,
    required this.text,
  });
}

class SubagentNode {
  final String id;
  final String? parentId;
  final String goal;
  final String? sessionId;
  final String? model;
  final String status; // running|queued|completed|failed|interrupted
  final int? taskCount;
  final int? taskIndex;
  final DateTime? startedAt;
  final DateTime? updatedAt;
  final String? summary;
  final String? currentTool;
  final List<SubagentNode> children;
  final double? costUsd;
  final int? inputTokens;
  final int? outputTokens;
  final int? toolCount;
  final List<String> filesRead;
  final List<String> filesWritten;
  final List<SubagentStreamEntry> stream;

  SubagentNode({
    required this.id,
    this.parentId,
    required this.goal,
    this.sessionId,
    this.model,
    required this.status,
    this.taskCount,
    this.taskIndex,
    this.startedAt,
    this.updatedAt,
    this.summary,
    this.currentTool,
    this.children = const [],
    this.costUsd,
    this.inputTokens,
    this.outputTokens,
    this.toolCount,
    this.filesRead = const [],
    this.filesWritten = const [],
    this.stream = const [],
  });

  factory SubagentNode.fromJson(Map<String, dynamic> json) {
    return SubagentNode(
      id: (json['id'] ?? json['subagent_id'] ?? '').toString(),
      parentId: (json['parent_subagent_id'] ?? json['parent_id'])?.toString(),
      goal: (json['goal'] ?? json['label'] ?? '').toString(),
      sessionId: json['child_session_id']?.toString(),
      model: json['model']?.toString(),
      status: (json['status'] ?? 'running').toString(),
      taskCount: (json['task_count'] as num?)?.toInt(),
      taskIndex: (json['task_index'] as num?)?.toInt(),
      startedAt: parseHermesTime(json['started_at']),
      updatedAt: parseHermesTime(json['updated_at'] ?? json['finished_at']),
      summary: json['summary']?.toString(),
      currentTool: json['current_tool']?.toString(),
      children:
          (json['children'] as List?)
              ?.map(
                (e) =>
                    SubagentNode.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
      costUsd: (json['cost_usd'] as num?)?.toDouble(),
      inputTokens: (json['input_tokens'] as num?)?.toInt(),
      outputTokens: (json['output_tokens'] as num?)?.toInt(),
      toolCount: (json['tool_count'] as num?)?.toInt(),
      filesRead:
          (json['files_read'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      filesWritten:
          (json['files_written'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// An active background process.
class ActiveProcess {
  final String processId;
  final String command;
  final String status;
  final int uptimeSeconds;

  ActiveProcess({
    required this.processId,
    required this.command,
    required this.status,
    this.uptimeSeconds = 0,
  });

  factory ActiveProcess.fromJson(Map<String, dynamic> json) {
    return ActiveProcess(
      processId: (json['process_id'] ?? json['id'] ?? '').toString(),
      command: (json['command'] ?? '').toString(),
      status: (json['status'] ?? 'running').toString(),
      uptimeSeconds: (json['uptime'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Pet info from `pet.info`.
class PetInfo {
  final bool enabled;
  final String? slug;
  final String? displayName;
  final String? spritesheetBase64;
  final int? frameW;
  final int? frameH;
  final Map<String, int> framesByState;
  final int? loopMs;
  final double? scale;

  PetInfo({
    this.enabled = false,
    this.slug,
    this.displayName,
    this.spritesheetBase64,
    this.frameW,
    this.frameH,
    this.framesByState = const {},
    this.loopMs,
    this.scale,
  });

  factory PetInfo.fromJson(Map<String, dynamic> json) {
    final spritesheet = json['spritesheet'] is Map
        ? (json['spritesheet'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final rawFrames = json['framesByState'] ?? spritesheet['frames_by_state'];
    return PetInfo(
      enabled: json['enabled'] == true,
      slug: json['slug']?.toString(),
      displayName: (json['displayName'] ?? json['display_name'])?.toString(),
      spritesheetBase64: (json['spritesheetBase64'] ?? spritesheet['data'])
          ?.toString(),
      frameW: _asInt(json['frameW'] ?? spritesheet['frame_w']),
      frameH: _asInt(json['frameH'] ?? spritesheet['frame_h']),
      framesByState: rawFrames is Map
          ? rawFrames.map(
              (key, value) => MapEntry(key.toString(), _asInt(value) ?? 0),
            )
          : const {},
      loopMs: _asInt(json['loopMs'] ?? spritesheet['loop_ms']),
      scale: _asDouble(json['scale']),
    );
  }
}

/// Pet gallery entry.
class PetGalleryEntry {
  final String slug;
  final String? displayName;
  final String? thumbDataUrl;

  PetGalleryEntry({required this.slug, this.displayName, this.thumbDataUrl});

  factory PetGalleryEntry.fromJson(Map<String, dynamic> json) {
    return PetGalleryEntry(
      slug: (json['slug'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['display_name'])?.toString(),
      thumbDataUrl: json['thumb']?.toString(),
    );
  }
}

class BillingUsageBar {
  final String kind;
  final String remainingDisplay;
  final String totalDisplay;
  final String spentDisplay;
  final double? percentUsed;
  final double fillFraction;

  const BillingUsageBar({
    required this.kind,
    this.remainingDisplay = '',
    this.totalDisplay = '',
    this.spentDisplay = '',
    this.percentUsed,
    this.fillFraction = 0,
  });

  factory BillingUsageBar.fromJson(Map<String, dynamic> json) =>
      BillingUsageBar(
        kind: (json['kind'] ?? '').toString(),
        remainingDisplay: (json['remaining_display'] ?? '').toString(),
        totalDisplay: (json['total_display'] ?? '').toString(),
        spentDisplay: (json['spent_display'] ?? '').toString(),
        percentUsed: _asDouble(json['pct_used']),
        fillFraction: (_asDouble(json['fill_fraction']) ?? 0).clamp(0, 1),
      );
}

class BillingUsage {
  final bool available;
  final String? status;
  final String? planName;
  final DateTime? renewsAt;
  final String? renewsDisplay;
  final String? subscriptionRemainingDisplay;
  final String? topupRemainingDisplay;
  final String? totalSpendableDisplay;
  final bool hasTopup;
  final BillingUsageBar? planBar;
  final BillingUsageBar? topupBar;

  const BillingUsage({
    this.available = false,
    this.status,
    this.planName,
    this.renewsAt,
    this.renewsDisplay,
    this.subscriptionRemainingDisplay,
    this.topupRemainingDisplay,
    this.totalSpendableDisplay,
    this.hasTopup = false,
    this.planBar,
    this.topupBar,
  });

  factory BillingUsage.fromJson(Map<String, dynamic> json) => BillingUsage(
    available: json['available'] == true,
    status: json['status']?.toString(),
    planName: json['plan_name']?.toString(),
    renewsAt: DateTime.tryParse(json['renews_at']?.toString() ?? ''),
    renewsDisplay: json['renews_display']?.toString(),
    subscriptionRemainingDisplay: json['subscription_remaining_display']
        ?.toString(),
    topupRemainingDisplay: json['topup_remaining_display']?.toString(),
    totalSpendableDisplay: json['total_spendable_display']?.toString(),
    hasTopup: json['has_topup'] == true,
    planBar: json['plan_bar'] is Map
        ? BillingUsageBar.fromJson(
            (json['plan_bar'] as Map).cast<String, dynamic>(),
          )
        : null,
    topupBar: json['topup_bar'] is Map
        ? BillingUsageBar.fromJson(
            (json['topup_bar'] as Map).cast<String, dynamic>(),
          )
        : null,
  );
}

class BillingPaymentMethod {
  final String kind;
  final String? brand;
  final String? last4;
  final String? wallet;
  final String? email;
  final String? rawKind;
  final String? resolvedVia;

  const BillingPaymentMethod({
    required this.kind,
    this.brand,
    this.last4,
    this.wallet,
    this.email,
    this.rawKind,
    this.resolvedVia,
  });

  factory BillingPaymentMethod.fromJson(Map<String, dynamic> json) =>
      BillingPaymentMethod(
        kind: (json['kind'] ?? 'unknown').toString(),
        brand: json['brand']?.toString(),
        last4: json['last4']?.toString(),
        wallet: json['wallet']?.toString(),
        email: json['email']?.toString(),
        rawKind: json['raw_kind']?.toString(),
        resolvedVia: json['resolved_via']?.toString(),
      );

  String get display => switch (kind) {
    'card' => '${brand ?? 'Card'} •••• ${last4 ?? ''}'.trim(),
    'link' => email == null ? 'Link' : 'Link · $email',
    _ =>
      rawKind == null
          ? runtimeL10n.billingSavedPaymentMethod
          : runtimeL10n.billingPaymentMethodKind(rawKind!),
  };
}

class BillingMonthlyCap {
  final bool isDefaultCeiling;
  final double? limit;
  final double? spent;
  final String limitDisplay;
  final String spentDisplay;

  const BillingMonthlyCap({
    this.isDefaultCeiling = false,
    this.limit,
    this.spent,
    this.limitDisplay = '',
    this.spentDisplay = '',
  });

  factory BillingMonthlyCap.fromJson(Map<String, dynamic> json) =>
      BillingMonthlyCap(
        isDefaultCeiling: json['is_default_ceiling'] == true,
        limit: _asDouble(json['limit_usd']),
        spent: _asDouble(json['spent_this_month_usd']),
        limitDisplay: (json['limit_display'] ?? '').toString(),
        spentDisplay: (json['spent_display'] ?? '').toString(),
      );
}

class BillingAutoReload {
  final bool enabled;
  final double? threshold;
  final double? reloadTo;
  final String thresholdDisplay;
  final String reloadToDisplay;
  final Map<String, dynamic>? card;

  const BillingAutoReload({
    this.enabled = false,
    this.threshold,
    this.reloadTo,
    this.thresholdDisplay = '',
    this.reloadToDisplay = '',
    this.card,
  });

  factory BillingAutoReload.fromJson(Map<String, dynamic> json) =>
      BillingAutoReload(
        enabled: json['enabled'] == true,
        threshold: _asDouble(json['threshold_usd']),
        reloadTo: _asDouble(json['reload_to_usd']),
        thresholdDisplay: (json['threshold_display'] ?? '').toString(),
        reloadToDisplay: (json['reload_to_display'] ?? '').toString(),
        card: json['card'] is Map
            ? (json['card'] as Map).cast<String, dynamic>()
            : null,
      );
}

/// Authoritative Remote Spending account state.
class BillingState {
  final double balance;
  final String balanceDisplay;
  final bool loggedIn;
  final bool isAdmin;
  final bool canCharge;
  final bool canChangePlan;
  final bool cliBillingEnabled;
  final String? orgName;
  final String? role;
  final Uri? portalUrl;
  final BillingPaymentMethod? paymentMethod;
  final List<double> chargePresets;
  final List<String> chargePresetsDisplay;
  final double? minimumCharge;
  final double? maximumCharge;
  final BillingMonthlyCap? monthlyCap;
  final BillingAutoReload? autoReloadConfig;
  final BillingUsage? usage;
  final String? error;
  final String? planId;

  BillingState({
    this.balance = 0,
    this.balanceDisplay = '',
    this.loggedIn = true,
    this.isAdmin = false,
    this.canCharge = false,
    this.canChangePlan = false,
    this.cliBillingEnabled = true,
    this.orgName,
    this.role,
    this.portalUrl,
    this.paymentMethod,
    this.chargePresets = const [],
    this.chargePresetsDisplay = const [],
    this.minimumCharge,
    this.maximumCharge,
    this.monthlyCap,
    this.autoReloadConfig,
    this.usage,
    this.error,
    this.planId,
    double? creditLimit,
    bool autoReload = false,
    double? autoReloadThreshold,
    double? autoReloadAmount,
  }) : _legacyCreditLimit = creditLimit,
       _legacyAutoReload = autoReload,
       _legacyAutoReloadThreshold = autoReloadThreshold,
       _legacyAutoReloadAmount = autoReloadAmount;

  final double? _legacyCreditLimit;
  final bool _legacyAutoReload;
  final double? _legacyAutoReloadThreshold;
  final double? _legacyAutoReloadAmount;

  double? get creditLimit => monthlyCap?.limit ?? _legacyCreditLimit;
  bool get autoReload => autoReloadConfig?.enabled ?? _legacyAutoReload;
  double? get autoReloadThreshold =>
      autoReloadConfig?.threshold ?? _legacyAutoReloadThreshold;
  double? get autoReloadAmount =>
      autoReloadConfig?.reloadTo ?? _legacyAutoReloadAmount;

  factory BillingState.fromJson(Map<String, dynamic> json) {
    final monthlyCap = json['monthly_cap'] is Map
        ? BillingMonthlyCap.fromJson(
            (json['monthly_cap'] as Map).cast<String, dynamic>(),
          )
        : null;
    final autoReload = json['auto_reload'] is Map
        ? BillingAutoReload.fromJson(
            (json['auto_reload'] as Map).cast<String, dynamic>(),
          )
        : null;
    BillingPaymentMethod? paymentMethod;
    if (json['payment_method'] is Map) {
      paymentMethod = BillingPaymentMethod.fromJson(
        (json['payment_method'] as Map).cast<String, dynamic>(),
      );
    } else if (json['card'] is Map) {
      final card = (json['card'] as Map).cast<String, dynamic>();
      paymentMethod = BillingPaymentMethod(
        kind: 'card',
        brand: card['brand']?.toString(),
        last4: card['last4']?.toString(),
        resolvedVia: card['resolved_via']?.toString(),
      );
    }
    final usage = json['usage'] is Map
        ? BillingUsage.fromJson((json['usage'] as Map).cast<String, dynamic>())
        : null;
    return BillingState(
      balance: _asDouble(json['balance_usd'] ?? json['balance']) ?? 0,
      balanceDisplay: (json['balance_display'] ?? '').toString(),
      loggedIn: json['logged_in'] != false,
      isAdmin: json['is_admin'] == true,
      canCharge: json['can_charge'] == true,
      canChangePlan: json['can_change_plan'] == true,
      cliBillingEnabled: json['cli_billing_enabled'] != false,
      orgName: json['org_name']?.toString(),
      role: json['role']?.toString(),
      portalUrl: _asUri(json['portal_url']),
      paymentMethod: paymentMethod,
      chargePresets: (json['charge_presets'] as List? ?? const [])
          .map(_asDouble)
          .whereType<double>()
          .toList(),
      chargePresetsDisplay:
          (json['charge_presets_display'] as List? ?? const [])
              .map((value) => value.toString())
              .toList(),
      minimumCharge: _asDouble(json['min_usd']),
      maximumCharge: _asDouble(json['max_usd']),
      monthlyCap: monthlyCap,
      autoReloadConfig: autoReload,
      usage: usage,
      error: json['error']?.toString(),
      planId: json['plan_id']?.toString() ?? usage?.planName,
    );
  }
}

class SubscriptionTier {
  final String id;
  final String name;
  final int order;
  final String priceDisplay;
  final double? monthlyCredits;
  final bool isCurrent;
  final bool isEnabled;

  const SubscriptionTier({
    required this.id,
    required this.name,
    this.order = 0,
    this.priceDisplay = '',
    this.monthlyCredits,
    this.isCurrent = false,
    this.isEnabled = true,
  });

  factory SubscriptionTier.fromJson(Map<String, dynamic> json) =>
      SubscriptionTier(
        id: (json['tier_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        order: _asInt(json['tier_order']) ?? 0,
        priceDisplay: (json['dollars_per_month_display'] ?? '').toString(),
        monthlyCredits: _asDouble(json['monthly_credits']),
        isCurrent: json['is_current'] == true,
        isEnabled: json['is_enabled'] != false,
      );
}

/// Subscription state and dynamic tier catalog.
class SubscriptionState {
  final String? typeId;
  final String? name;
  final String status;
  final DateTime? currentPeriodEnd;
  final bool canceledAtPeriodEnd;
  final bool loggedIn;
  final bool isAdmin;
  final bool canChangePlan;
  final String context;
  final String? orgId;
  final String? orgName;
  final String? role;
  final Uri? portalUrl;
  final List<SubscriptionTier> tiers;
  final double? monthlyCredits;
  final double? creditsRemaining;
  final String? pendingDowngradeTierName;
  final DateTime? pendingDowngradeAt;
  final String? pendingDowngradeDisplay;
  final DateTime? cancellationEffectiveAt;
  final String? cancellationEffectiveDisplay;
  final BillingUsage? usage;
  final String? error;

  SubscriptionState({
    this.typeId,
    this.name,
    this.status = 'active',
    this.currentPeriodEnd,
    this.canceledAtPeriodEnd = false,
    this.loggedIn = true,
    this.isAdmin = false,
    this.canChangePlan = false,
    this.context = 'personal',
    this.orgId,
    this.orgName,
    this.role,
    this.portalUrl,
    this.tiers = const [],
    this.monthlyCredits,
    this.creditsRemaining,
    this.pendingDowngradeTierName,
    this.pendingDowngradeAt,
    this.pendingDowngradeDisplay,
    this.cancellationEffectiveAt,
    this.cancellationEffectiveDisplay,
    this.usage,
    this.error,
  });

  SubscriptionTier? get currentTier {
    for (final tier in tiers) {
      if (tier.isCurrent || tier.id == typeId) return tier;
    }
    return null;
  }

  bool get hasPendingChange =>
      pendingDowngradeTierName != null || canceledAtPeriodEnd;

  factory SubscriptionState.fromJson(Map<String, dynamic> json) {
    final current = json['current'] is Map
        ? (json['current'] as Map).cast<String, dynamic>()
        : json;
    final canceledAtPeriodEnd =
        current['cancel_at_period_end'] == true ||
        current['canceled_at_period_end'] == true;
    final end = current['cycle_ends_at'] ?? current['current_period_end'];
    final tiers =
        (json['tiers'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (value) =>
                  SubscriptionTier.fromJson(value.cast<String, dynamic>()),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    final usage = json['usage'] is Map
        ? BillingUsage.fromJson((json['usage'] as Map).cast<String, dynamic>())
        : null;
    return SubscriptionState(
      typeId: (current['tier_id'] ?? current['type_id'])?.toString(),
      name: (current['tier_name'] ?? current['name'])?.toString(),
      status:
          (usage?.status ??
                  json['status'] ??
                  (canceledAtPeriodEnd ? 'canceling' : 'active'))
              .toString(),
      currentPeriodEnd: DateTime.tryParse(end?.toString() ?? ''),
      canceledAtPeriodEnd: canceledAtPeriodEnd,
      loggedIn: json['logged_in'] != false,
      isAdmin: json['is_admin'] == true,
      canChangePlan: json['can_change_plan'] == true,
      context: (json['context'] ?? 'personal').toString(),
      orgId: json['org_id']?.toString(),
      orgName: json['org_name']?.toString(),
      role: json['role']?.toString(),
      portalUrl: _asUri(json['portal_url']),
      tiers: tiers,
      monthlyCredits: _asDouble(current['monthly_credits']),
      creditsRemaining: _asDouble(current['credits_remaining']),
      pendingDowngradeTierName: current['pending_downgrade_tier_name']
          ?.toString(),
      pendingDowngradeAt: DateTime.tryParse(
        current['pending_downgrade_at']?.toString() ?? '',
      ),
      pendingDowngradeDisplay: current['pending_downgrade_display']?.toString(),
      cancellationEffectiveAt: DateTime.tryParse(
        current['cancellation_effective_at']?.toString() ?? '',
      ),
      cancellationEffectiveDisplay: current['cancellation_effective_display']
          ?.toString(),
      usage: usage,
      error: json['error']?.toString(),
    );
  }
}

/// Compatibility projection for callers that still consume numeric usage bars.
class UsageBars {
  final BillingUsage? usage;

  UsageBars({this.usage});

  factory UsageBars.fromJson(Map<String, dynamic> json) {
    final payload = json['usage'] is Map
        ? (json['usage'] as Map).cast<String, dynamic>()
        : json;
    return UsageBars(usage: BillingUsage.fromJson(payload));
  }
}

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  final normalized = value
      .toString()
      .replaceAll(RegExp(r'[^0-9.+-]'), '')
      .trim();
  return double.tryParse(normalized);
}

Uri? _asUri(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  return uri != null && uri.hasScheme ? uri : null;
}

/// Credential provider (model provider with auth status).
class CredentialProvider {
  final String slug;
  final String name;
  final String authType;
  final bool isCurrent;
  final bool authenticated;
  final List<String> models;

  CredentialProvider({
    required this.slug,
    required this.name,
    this.authType = 'api_key',
    this.isCurrent = false,
    this.authenticated = false,
    this.models = const [],
  });

  factory CredentialProvider.fromJson(Map<String, dynamic> json) {
    return CredentialProvider(
      slug: (json['slug'] ?? '').toString(),
      name: (json['name'] ?? json['slug'] ?? '').toString(),
      authType: (json['auth_type'] ?? 'api_key').toString(),
      isCurrent: json['is_current'] == true,
      authenticated:
          json['authenticated'] == true || json['api_key_configured'] == true,
      models:
          (json['models'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// One server-described environment field for a messaging platform.
class MessagingEnvVar {
  final String key;
  final String prompt;
  final String description;
  final bool required;
  final bool advanced;
  final bool isPassword;
  final bool isSet;
  final String? redactedValue;
  final Uri? url;

  const MessagingEnvVar({
    required this.key,
    this.prompt = '',
    this.description = '',
    this.required = false,
    this.advanced = false,
    this.isPassword = false,
    this.isSet = false,
    this.redactedValue,
    this.url,
  });

  factory MessagingEnvVar.fromJson(Map<String, dynamic> json) {
    final rawUrl = json['url']?.toString();
    return MessagingEnvVar(
      key: (json['key'] ?? '').toString(),
      prompt: (json['prompt'] ?? json['key'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      required: json['required'] == true,
      advanced: json['advanced'] == true,
      isPassword: json['is_password'] == true,
      isSet: json['is_set'] == true,
      redactedValue: json['redacted_value']?.toString(),
      url: rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
    );
  }
}

/// One row from `GET /api/env`: a provider/tool credential or arbitrary
/// custom env var stored server-side in `.env`. Mirrors desktop's Keys tab.
class ProviderEnvVar {
  final String key;
  final bool isSet;
  final String? redactedValue;
  final String description;
  final Uri? url;
  final String category;
  final bool isPassword;
  final List<String> tools;
  final bool advanced;
  final bool channelManaged;
  final String provider;
  final String providerLabel;
  final bool custom;

  const ProviderEnvVar({
    required this.key,
    this.isSet = false,
    this.redactedValue,
    this.description = '',
    this.url,
    this.category = '',
    this.isPassword = false,
    this.tools = const [],
    this.advanced = false,
    this.channelManaged = false,
    this.provider = '',
    this.providerLabel = '',
    this.custom = false,
  });

  factory ProviderEnvVar.fromJson(String key, Map<String, dynamic> json) {
    final rawUrl = json['url']?.toString();
    return ProviderEnvVar(
      key: key,
      isSet: json['is_set'] == true,
      redactedValue: json['redacted_value']?.toString(),
      description: (json['description'] ?? '').toString(),
      url: rawUrl == null || rawUrl.isEmpty ? null : Uri.tryParse(rawUrl),
      category: (json['category'] ?? '').toString(),
      isPassword: json['is_password'] == true,
      tools:
          (json['tools'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      advanced: json['advanced'] == true,
      channelManaged: json['channel_managed'] == true,
      provider: (json['provider'] ?? '').toString(),
      providerLabel: (json['provider_label'] ?? '').toString(),
      custom: json['custom'] == true,
    );
  }
}

/// Messaging platform (Telegram/Discord/BlueBubbles).
class MessagingPlatform {
  /// Stable platform id. Kept as `name` for compatibility with older mobile
  /// call sites where `name` was the canonical id.
  final String name;
  final String displayName;
  final String kind;
  final String description;
  final Uri? docsUrl;
  final bool enabled;
  final bool configured;
  final bool gatewayRunning;
  final bool paired;
  final String state;
  final DateTime? updatedAt;
  final String? errorCode;
  final String? errorMessage;
  final Map<String, dynamic>? homeChannel;
  final String? homeChannelName;
  final List<MessagingEnvVar> envVars;

  MessagingPlatform({
    required this.name,
    String? displayName,
    this.kind = '',
    this.description = '',
    this.docsUrl,
    this.enabled = false,
    this.configured = false,
    this.gatewayRunning = false,
    this.paired = false,
    this.state = '',
    this.updatedAt,
    this.errorCode,
    this.errorMessage,
    this.homeChannel,
    this.homeChannelName,
    this.envVars = const [],
  }) : displayName = displayName ?? name;

  String get id => name;

  factory MessagingPlatform.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['slug'] ?? json['name'] ?? '').toString();
    final rawDocsUrl = json['docs_url']?.toString();
    final rawHomeChannel = json['home_channel'];
    final homeChannel = rawHomeChannel is Map
        ? rawHomeChannel.cast<String, dynamic>()
        : null;
    return MessagingPlatform(
      name: id,
      displayName: (json['name'] ?? json['id'] ?? json['slug'] ?? '')
          .toString(),
      kind: (json['id'] ?? json['kind'] ?? json['type'] ?? id).toString(),
      description: (json['description'] ?? '').toString(),
      docsUrl: rawDocsUrl == null || rawDocsUrl.isEmpty
          ? null
          : Uri.tryParse(rawDocsUrl),
      enabled: json['enabled'] == true,
      configured: json['configured'] == true,
      gatewayRunning: json['gateway_running'] == true,
      paired:
          json['paired'] == true ||
          json['connected'] == true ||
          json['state'] == 'connected',
      state: (json['state'] ?? '').toString(),
      updatedAt: json['updated_at'] is String
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      errorCode: json['error_code']?.toString(),
      errorMessage: json['error_message']?.toString(),
      homeChannel: homeChannel,
      homeChannelName: homeChannel != null
          ? (homeChannel['name'] ?? homeChannel['chat_id'])?.toString()
          : null,
      envVars: (json['env_vars'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MessagingEnvVar.fromJson(item.cast<String, dynamic>()))
          .toList(growable: false),
    );
  }

  /// Same eligibility used by desktop `/handoff` completions.
  bool get canHandoff => enabled && configured;
}

/// Messaging pairing request.
class MessagingPairing {
  final String id;
  final String platform;
  final String? deviceInfo;
  final String userId;
  final String? userName;
  final double? ageMinutes;
  final String status;
  final DateTime? requestedAt;

  MessagingPairing({
    required this.id,
    required this.platform,
    this.deviceInfo,
    this.userId = '',
    this.userName,
    this.ageMinutes,
    this.status = 'pending',
    this.requestedAt,
  });

  factory MessagingPairing.fromJson(Map<String, dynamic> json) {
    final userId = (json['user_id'] ?? '').toString();
    final userName = json['user_name']?.toString();
    final rawAge = json['age_minutes'];
    return MessagingPairing(
      id: (json['request_id'] ?? json['id'] ?? json['pairing_id'] ?? '')
          .toString(),
      platform: (json['platform'] ?? '').toString(),
      deviceInfo: (userName ?? (userId.isEmpty ? json['device_info'] : userId))
          ?.toString(),
      userId: userId,
      userName: userName,
      ageMinutes: rawAge is num
          ? rawAge.toDouble()
          : double.tryParse('$rawAge'),
      status: (json['status'] ?? 'pending').toString(),
      requestedAt: json['requested_at'] is String
          ? DateTime.tryParse(json['requested_at'])
          : null,
    );
  }
}

class MessagingPairings {
  final List<MessagingPairing> pending;
  final List<MessagingPairing> approved;

  const MessagingPairings({this.pending = const [], this.approved = const []});

  factory MessagingPairings.fromJson(Map<String, dynamic> json) {
    List<MessagingPairing> parse(String key, String status) =>
        (json[key] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => MessagingPairing.fromJson({
                ...item.cast<String, dynamic>(),
                'status': status,
              }),
            )
            .toList(growable: false);
    return MessagingPairings(
      pending: parse('pending', 'pending'),
      approved: parse('approved', 'approved'),
    );
  }
}

/// Webhook configuration.
class Webhook {
  final String id;
  final String name;
  final String url;
  final List<String> events;
  final bool enabled;
  final String? secret;
  final DateTime? createdAt;
  final String? description;
  final String? prompt;
  final List<String> skills;
  final String? deliver;

  Webhook({
    required this.id,
    required this.name,
    required this.url,
    this.events = const [],
    this.enabled = false,
    this.secret,
    this.createdAt,
    this.description,
    this.prompt,
    this.skills = const [],
    this.deliver,
  });

  factory Webhook.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return Webhook(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      events:
          (json['events'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      enabled: json['enabled'] != false,
      secret: json['secret']?.toString(),
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? (json['description'] as String).trim()
          : null,
      prompt: (json['prompt'] as String?)?.trim().isNotEmpty == true
          ? (json['prompt'] as String).trim()
          : null,
      skills:
          (json['skills'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      deliver: (json['deliver'] as String?)?.trim().isNotEmpty == true
          ? (json['deliver'] as String).trim()
          : null,
    );
  }
}

/// Starmap graph node — mirrors backend `agent/learning_graph.py`'s
/// `graph_nodes` entries exactly (both `skill` and `memory` kinds share this
/// shape; a memory node's rich prose lives separately in [StarmapGraph.memory],
/// looked up by [id]).
class StarmapNode {
  final String id;
  final String label;
  final String kind;
  final String category;
  final String? content;

  /// Epoch seconds this was last learned/used (skills) or the source file's
  /// mtime (memory) — null when undated. Backend field: `timestamp`.
  final int? timestamp;
  final int useCount;
  final String state;
  final String? createdBy;
  final bool pinned;
  final String? memorySource;

  StarmapNode({
    required this.id,
    this.label = '',
    this.kind = '',
    this.category = '',
    this.content,
    this.timestamp,
    this.useCount = 0,
    this.state = 'active',
    this.createdBy,
    this.pinned = false,
    this.memorySource,
  });

  factory StarmapNode.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    return StarmapNode(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? json['title'] ?? '').toString(),
      kind: (json['kind'] ?? json['type'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      content: json['content']?.toString(),
      timestamp: ts is num ? ts.round() : null,
      useCount: (json['useCount'] as num?)?.toInt() ?? 0,
      state: (json['state'] ?? 'active').toString(),
      createdBy: json['createdBy']?.toString(),
      pinned: json['pinned'] == true,
      memorySource: json['memorySource']?.toString(),
    );
  }
}

/// Starmap graph edge.
class StarmapEdge {
  final String source;
  final String target;
  final String? label;

  StarmapEdge({required this.source, required this.target, this.label});

  factory StarmapEdge.fromJson(Map<String, dynamic> json) {
    return StarmapEdge(
      source: (json['source'] ?? '').toString(),
      target: (json['target'] ?? '').toString(),
      label: json['label']?.toString(),
    );
  }
}

/// One freeform-memory card (`MEMORY.md`/`USER.md` chunk) — the rich-content
/// counterpart of a `kind: 'memory'` [StarmapNode], keyed by the same
/// `memory:<source>:<index>` id scheme the backend synthesizes.
class StarmapMemoryCard {
  final String source;
  final int? timestamp;
  final String title;
  final String body;

  StarmapMemoryCard({
    required this.source,
    this.timestamp,
    this.title = '',
    this.body = '',
  });

  factory StarmapMemoryCard.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'];
    return StarmapMemoryCard(
      source: (json['source'] ?? '').toString(),
      timestamp: ts is num ? ts.round() : null,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
    );
  }
}

/// Starmap graph container.
class StarmapGraph {
  final List<StarmapNode> nodes;
  final List<StarmapEdge> edges;
  final List<Map<String, dynamic>> clusters;
  final List<StarmapMemoryCard> memory;
  final Map<String, dynamic> stats;

  StarmapGraph({
    this.nodes = const [],
    this.edges = const [],
    this.clusters = const [],
    this.memory = const [],
    this.stats = const {},
  });

  factory StarmapGraph.fromJson(Map<String, dynamic> json) {
    return StarmapGraph(
      nodes:
          (json['nodes'] as List?)
              ?.map(
                (e) => StarmapNode.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
      edges:
          (json['edges'] as List?)
              ?.map(
                (e) => StarmapEdge.fromJson((e as Map).cast<String, dynamic>()),
              )
              .toList() ??
          const [],
      clusters:
          (json['clusters'] as List?)
              ?.map((e) => (e as Map).cast<String, dynamic>())
              .toList() ??
          const [],
      memory:
          (json['memory'] as List?)
              ?.map(
                (e) => StarmapMemoryCard.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      stats: (json['stats'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }
}

/// One day's row from `GET /api/v1/analytics/usage`'s `daily` list — feeds
/// the Command Center's usage bar chart.
class AnalyticsDailyEntry {
  final String day;
  final int apiCalls;
  final int inputTokens;
  final int outputTokens;
  final int sessions;

  const AnalyticsDailyEntry({
    required this.day,
    this.apiCalls = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.sessions = 0,
  });

  factory AnalyticsDailyEntry.fromJson(Map<String, dynamic> json) {
    return AnalyticsDailyEntry(
      day: (json['day'] ?? '').toString(),
      apiCalls: (json['api_calls'] as num?)?.toInt() ?? 0,
      inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One model's row from `by_model`.
class AnalyticsModelEntry {
  final String model;
  final int apiCalls;
  final int inputTokens;
  final int outputTokens;
  final int sessions;

  const AnalyticsModelEntry({
    required this.model,
    this.apiCalls = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.sessions = 0,
  });

  factory AnalyticsModelEntry.fromJson(Map<String, dynamic> json) {
    return AnalyticsModelEntry(
      model: (json['model'] ?? '').toString(),
      apiCalls: (json['api_calls'] as num?)?.toInt() ?? 0,
      inputTokens: (json['input_tokens'] as num?)?.toInt() ?? 0,
      outputTokens: (json['output_tokens'] as num?)?.toInt() ?? 0,
      sessions: (json['sessions'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One skill's row from `skills.top_skills`.
class AnalyticsSkillEntry {
  final String skill;
  final int totalCount;

  const AnalyticsSkillEntry({required this.skill, this.totalCount = 0});

  factory AnalyticsSkillEntry.fromJson(Map<String, dynamic> json) {
    return AnalyticsSkillEntry(
      skill: (json['skill'] ?? '').toString(),
      totalCount: (json['total_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// `totals` — period-wide rollups.
class AnalyticsTotals {
  final int totalSessions;
  final int? totalApiCalls;
  final int? totalInput;
  final int? totalOutput;

  const AnalyticsTotals({
    this.totalSessions = 0,
    this.totalApiCalls,
    this.totalInput,
    this.totalOutput,
  });

  factory AnalyticsTotals.fromJson(Map<String, dynamic> json) {
    return AnalyticsTotals(
      totalSessions: (json['total_sessions'] as num?)?.toInt() ?? 0,
      totalApiCalls: (json['total_api_calls'] as num?)?.toInt(),
      totalInput: (json['total_input'] as num?)?.toInt(),
      totalOutput: (json['total_output'] as num?)?.toInt(),
    );
  }
}

/// `GET /api/v1/analytics/usage` response — Command Center's Usage tab.
class AnalyticsUsage {
  final List<AnalyticsDailyEntry> daily;
  final List<AnalyticsModelEntry> byModel;
  final List<AnalyticsSkillEntry> topSkills;
  final AnalyticsTotals? totals;

  const AnalyticsUsage({
    this.daily = const [],
    this.byModel = const [],
    this.topSkills = const [],
    this.totals,
  });

  factory AnalyticsUsage.fromJson(Map<String, dynamic> json) {
    final skills = (json['skills'] as Map?)?.cast<String, dynamic>();
    return AnalyticsUsage(
      daily:
          (json['daily'] as List?)
              ?.map(
                (e) => AnalyticsDailyEntry.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      byModel:
          (json['by_model'] as List?)
              ?.map(
                (e) => AnalyticsModelEntry.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      topSkills:
          (skills?['top_skills'] as List?)
              ?.map(
                (e) => AnalyticsSkillEntry.fromJson(
                  (e as Map).cast<String, dynamic>(),
                ),
              )
              .toList() ??
          const [],
      totals: (json['totals'] as Map?) != null
          ? AnalyticsTotals.fromJson(
              (json['totals'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}

/// Structured artifact from server.
class ArtifactItem {
  final String id;
  final String kind;
  final String value;
  final String? label;
  final String sessionId;
  final String? sessionTitle;
  final int? rowId;

  ArtifactItem({
    required this.id,
    required this.kind,
    required this.value,
    this.label,
    required this.sessionId,
    this.sessionTitle,
    this.rowId,
  });

  factory ArtifactItem.fromJson(Map<String, dynamic> json) {
    return ArtifactItem(
      id: (json['id'] ?? '${json['session_id']}:${json['row_id'] ?? 0}')
          .toString(),
      kind: (json['kind'] ?? 'file').toString(),
      value: (json['value'] ?? '').toString(),
      label: json['label']?.toString(),
      sessionId: (json['session_id'] ?? '').toString(),
      sessionTitle: json['session_title']?.toString(),
      rowId: (json['row_id'] as num?)?.toInt(),
    );
  }
}

/// Commit message suggestion.
class CommitMessageSuggestion {
  final String message;
  final List<String> alternatives;

  CommitMessageSuggestion({
    required this.message,
    this.alternatives = const [],
  });

  factory CommitMessageSuggestion.fromJson(Map<String, dynamic> json) {
    return CommitMessageSuggestion(
      message: (json['message'] ?? json['commit_message'] ?? '').toString(),
      alternatives:
          (json['alternatives'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
    );
  }
}

/// PR creation result.
class PrCreateResult {
  final String url;
  final int? number;
  final String? branch;

  PrCreateResult({required this.url, this.number, this.branch});

  factory PrCreateResult.fromJson(Map<String, dynamic> json) {
    return PrCreateResult(
      url: (json['url'] ?? json['pr_url'] ?? '').toString(),
      number: (json['number'] as num?)?.toInt(),
      branch: json['branch']?.toString(),
    );
  }
}

/// Terminal session (local tab).
class TerminalSession {
  final String id;
  final String? runtimeSessionId;
  final String title;
  final String cwd;
  final DateTime createdAt;
  final bool exited;
  final int? exitCode;

  TerminalSession({
    required this.id,
    this.runtimeSessionId,
    String? title,
    this.cwd = '',
    required this.createdAt,
    this.exited = false,
    this.exitCode,
  }) : title = title ?? runtimeL10n.terminalNew;

  bool get isAlive => runtimeSessionId != null && !exited;

  TerminalSession copyWith({
    String? cwd,
    String? title,
    String? runtimeSessionId,
    bool clearRuntime = false,
    bool? exited,
    int? exitCode,
    bool clearExitCode = false,
  }) => TerminalSession(
    id: id,
    runtimeSessionId: clearRuntime
        ? null
        : (runtimeSessionId ?? this.runtimeSessionId),
    title: title ?? this.title,
    cwd: cwd ?? this.cwd,
    createdAt: createdAt,
    exited: exited ?? this.exited,
    exitCode: clearExitCode ? null : (exitCode ?? this.exitCode),
  );
}

/// Slash command catalog entry.
class SlashCommand {
  final String name;
  final String? description;
  final String? category;

  SlashCommand({required this.name, this.description, this.category});

  factory SlashCommand.fromJson(Map<String, dynamic> json) {
    return SlashCommand(
      name: (json['name'] ?? json['command'] ?? '').toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
    );
  }
}

/// Slash completion suggestion.
class SlashSuggestion {
  final String text;
  final String display;
  final String? meta;
  final String? group;
  final String? action;

  SlashSuggestion({
    String? text,
    String? display,
    String? meta,
    this.group,
    this.action,
    String? name,
    String? description,
  }) : text = text ?? name ?? '',
       display = display ?? text ?? name ?? '',
       meta = meta ?? description;

  String get name => text;
  String? get description => meta;

  factory SlashSuggestion.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] ?? json['name'] ?? json['value'] ?? '')
        .toString();
    return SlashSuggestion(
      text: text,
      display: (json['display'] ?? text).toString(),
      meta: (json['meta'] ?? json['description'])?.toString(),
      group: json['group']?.toString(),
      action: json['action']?.toString(),
    );
  }
}

/// One completion response. [replaceFrom] is a character offset in the full
/// slash invocation; argument completions replace only the suffix from there.
class SlashCompletionResult {
  final List<SlashSuggestion> items;
  final int replaceFrom;

  const SlashCompletionResult({required this.items, this.replaceFrom = 1});
}

/// A saved prompt snippet (WebUI `/api/prompts` parity).
class SavedPrompt {
  final String id;
  final String label;
  final String text;

  SavedPrompt({required this.id, required this.label, required this.text});

  factory SavedPrompt.fromJson(Map<String, dynamic> json) {
    final text = (json['text'] ?? '').toString();
    return SavedPrompt(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString().isNotEmpty
          ? (json['label'] ?? '').toString()
          : (text.length > 60 ? text.substring(0, 60) : text),
      text: text,
    );
  }
}

/// Path completion suggestion (for @mentions).
class PathSuggestion {
  final String path;
  final String name;
  final bool isDirectory;

  PathSuggestion({
    required this.path,
    required this.name,
    this.isDirectory = false,
  });

  factory PathSuggestion.fromJson(Map<String, dynamic> json) {
    return PathSuggestion(
      path: (json['path'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isDirectory: json['is_directory'] == true || json['isDirectory'] == true,
    );
  }
}
