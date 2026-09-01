library;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};
List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : const [];

class KanbanTask {
  final String id, title, status;
  final String? body, assignee, tenant, latestSummary;
  final int priority, commentCount;
  final Map<String, dynamic> raw;
  const KanbanTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.commentCount,
    required this.raw,
    this.body,
    this.assignee,
    this.tenant,
    this.latestSummary,
  });
  factory KanbanTask.fromJson(Map<String, dynamic> j) => KanbanTask(
    id: '${j['id'] ?? ''}',
    title: '${j['title'] ?? ''}',
    status: '${j['status'] ?? 'triage'}',
    priority: (j['priority'] as num?)?.toInt() ?? 0,
    commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
    raw: j,
    body: j['body']?.toString(),
    assignee: j['assignee']?.toString(),
    tenant: j['tenant']?.toString(),
    latestSummary: j['latest_summary']?.toString(),
  );
  KanbanTask copyWith({String? status}) => KanbanTask(
    id: id,
    title: title,
    status: status ?? this.status,
    priority: priority,
    commentCount: commentCount,
    raw: {...raw, 'status': ?status},
    body: body,
    assignee: assignee,
    tenant: tenant,
    latestSummary: latestSummary,
  );
  bool get running => status == 'running';
  int? get createdAt => (raw['created_at'] as num?)?.toInt();
  int? get startedAt => (raw['started_at'] as num?)?.toInt();
  int? get lastHeartbeatAt => (raw['last_heartbeat_at'] as num?)?.toInt();
  int? get workerPid => (raw['worker_pid'] as num?)?.toInt();
  Map<String, dynamic>? get progress =>
      raw['progress'] is Map ? _map(raw['progress']) : null;
  Map<String, dynamic>? get warnings =>
      raw['warnings'] is Map ? _map(raw['warnings']) : null;
}

class KanbanComment {
  final String id, author, body;
  final int createdAt;
  const KanbanComment(this.id, this.author, this.body, this.createdAt);
  factory KanbanComment.fromJson(Map<String, dynamic> j) => KanbanComment(
    '${j['id'] ?? ''}',
    '${j['author'] ?? ''}',
    '${j['body'] ?? ''}',
    (j['created_at'] as num?)?.toInt() ?? 0,
  );
}

class KanbanEvent {
  final int id, createdAt;
  final String kind;
  final Object? payload;
  const KanbanEvent(this.id, this.kind, this.payload, this.createdAt);
  factory KanbanEvent.fromJson(Map<String, dynamic> j) => KanbanEvent(
    (j['id'] as num?)?.toInt() ?? 0,
    '${j['kind'] ?? ''}',
    j['payload'],
    (j['created_at'] as num?)?.toInt() ?? 0,
  );
}

class KanbanAttachment {
  final String id, filename;
  final int? size;
  const KanbanAttachment(this.id, this.filename, this.size);
  factory KanbanAttachment.fromJson(Map<String, dynamic> j) => KanbanAttachment(
    '${j['id'] ?? ''}',
    '${j['filename'] ?? ''}',
    (j['size'] as num?)?.toInt(),
  );
}

class KanbanRun {
  final String id, status;
  final String? profile, outcome, summary, error;
  final int? startedAt, endedAt, workerPid;
  final Map<String, dynamic> raw;
  const KanbanRun({
    required this.id,
    required this.status,
    required this.raw,
    this.profile,
    this.outcome,
    this.summary,
    this.error,
    this.startedAt,
    this.endedAt,
    this.workerPid,
  });
  factory KanbanRun.fromJson(Map<String, dynamic> j) => KanbanRun(
    id: '${j['id'] ?? ''}',
    status: '${j['status'] ?? ''}',
    raw: j,
    profile: j['profile']?.toString(),
    outcome: j['outcome']?.toString(),
    summary: j['summary']?.toString(),
    error: j['error']?.toString(),
    startedAt: (j['started_at'] as num?)?.toInt(),
    endedAt: (j['ended_at'] as num?)?.toInt(),
    workerPid: (j['worker_pid'] as num?)?.toInt(),
  );
}

class KanbanDiagnosticAction {
  final String kind, label;
  final bool suggested;
  final Map<String, dynamic> payload;
  const KanbanDiagnosticAction(
    this.kind,
    this.label,
    this.suggested,
    this.payload,
  );
  factory KanbanDiagnosticAction.fromJson(Map<String, dynamic> j) =>
      KanbanDiagnosticAction(
        '${j['kind'] ?? ''}',
        '${j['label'] ?? ''}',
        j['suggested'] == true,
        _map(j['payload']),
      );
}

class KanbanDiagnostic {
  final String kind, severity, title, detail;
  final int count, lastSeenAt;
  final List<KanbanDiagnosticAction> actions;
  final Map<String, dynamic> data;
  const KanbanDiagnostic({
    required this.kind,
    required this.severity,
    required this.title,
    required this.detail,
    required this.count,
    required this.lastSeenAt,
    required this.actions,
    required this.data,
  });
  factory KanbanDiagnostic.fromJson(Map<String, dynamic> j) => KanbanDiagnostic(
    kind: '${j['kind'] ?? ''}',
    severity: '${j['severity'] ?? 'warning'}',
    title: '${j['title'] ?? ''}',
    detail: '${j['detail'] ?? ''}',
    count: (j['count'] as num?)?.toInt() ?? 0,
    lastSeenAt: (j['last_seen_at'] as num?)?.toInt() ?? 0,
    actions: _maps(j['actions']).map(KanbanDiagnosticAction.fromJson).toList(),
    data: _map(j['data']),
  );
}

class KanbanColumn {
  final String name;
  final List<KanbanTask> tasks;
  const KanbanColumn(this.name, this.tasks);
  factory KanbanColumn.fromJson(Map<String, dynamic> j) => KanbanColumn(
    '${j['name'] ?? ''}',
    _maps(j['tasks']).map(KanbanTask.fromJson).toList(),
  );
}

class KanbanBoard {
  final List<KanbanColumn> columns;
  final List<String> tenants, assignees;
  final int latestEventId;
  const KanbanBoard({
    required this.columns,
    required this.tenants,
    required this.assignees,
    required this.latestEventId,
  });
  factory KanbanBoard.fromJson(Map<String, dynamic> j) => KanbanBoard(
    columns: _maps(j['columns']).map(KanbanColumn.fromJson).toList(),
    tenants: (j['tenants'] as List? ?? const []).map((e) => '$e').toList(),
    assignees: (j['assignees'] as List? ?? const []).map((e) => '$e').toList(),
    latestEventId: (j['latest_event_id'] as num?)?.toInt() ?? 0,
  );
  List<KanbanTask> get tasks => [for (final c in columns) ...c.tasks];
}

class KanbanBoardMeta {
  final String slug;
  final String? name, description, projectId, projectName, defaultWorkdir;
  final int? total;
  final bool current;
  const KanbanBoardMeta({
    required this.slug,
    this.name,
    this.description,
    this.projectId,
    this.projectName,
    this.defaultWorkdir,
    this.total,
    this.current = false,
  });
  factory KanbanBoardMeta.fromJson(Map<String, dynamic> j) => KanbanBoardMeta(
    slug: '${j['slug'] ?? ''}',
    name: j['name']?.toString(),
    description: j['description']?.toString(),
    projectId: j['project_id']?.toString(),
    projectName: j['project_name']?.toString(),
    defaultWorkdir: j['default_workdir']?.toString(),
    total: (j['total'] as num?)?.toInt(),
    current: j['is_current'] == true,
  );
  String get label => name?.isNotEmpty == true ? name! : slug;
}

class KanbanTaskDetail {
  final KanbanTask task;
  final List<KanbanComment> comments;
  final List<KanbanEvent> events;
  final List<KanbanAttachment> attachments;
  final List<KanbanRun> runs;
  final List<KanbanDiagnostic> diagnostics;
  final List<String> parents, children;
  const KanbanTaskDetail({
    required this.task,
    required this.comments,
    required this.events,
    required this.attachments,
    required this.runs,
    required this.diagnostics,
    required this.parents,
    required this.children,
  });
  factory KanbanTaskDetail.fromJson(Map<String, dynamic> j) {
    final task = _map(j['task']);
    final links = _map(j['links']);
    return KanbanTaskDetail(
      task: KanbanTask.fromJson(task),
      comments: _maps(j['comments']).map(KanbanComment.fromJson).toList(),
      events: _maps(j['events']).map(KanbanEvent.fromJson).toList(),
      attachments: _maps(
        j['attachments'],
      ).map(KanbanAttachment.fromJson).toList(),
      runs: _maps(j['runs']).map(KanbanRun.fromJson).toList(),
      diagnostics: _maps(
        task['diagnostics'],
      ).map(KanbanDiagnostic.fromJson).toList(),
      parents: (links['parents'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
      children: (links['children'] as List? ?? const [])
          .map((e) => '$e')
          .toList(),
    );
  }
}

class KanbanProject {
  final String id, slug, name;
  final String? primaryPath, icon, color;
  const KanbanProject({
    required this.id,
    required this.slug,
    required this.name,
    this.primaryPath,
    this.icon,
    this.color,
  });
  factory KanbanProject.fromJson(Map<String, dynamic> j) => KanbanProject(
    id: '${j['id'] ?? ''}',
    slug: '${j['slug'] ?? ''}',
    name: '${j['name'] ?? ''}',
    primaryPath: j['primary_path']?.toString(),
    icon: j['icon']?.toString(),
    color: j['color']?.toString(),
  );
}

class KanbanProfile {
  final String name, description;
  final bool isDefault, descriptionAuto;
  const KanbanProfile({
    required this.name,
    required this.description,
    required this.isDefault,
    required this.descriptionAuto,
  });
  factory KanbanProfile.fromJson(Map<String, dynamic> j) => KanbanProfile(
    name: '${j['name'] ?? ''}',
    description: '${j['description'] ?? ''}',
    isDefault: j['is_default'] == true,
    descriptionAuto: j['description_auto'] == true,
  );
}

class KanbanOrchestration {
  final String orchestratorProfile,
      defaultAssignee,
      resolvedOrchestratorProfile,
      resolvedDefaultAssignee;
  final bool autoDecompose;
  const KanbanOrchestration({
    required this.orchestratorProfile,
    required this.defaultAssignee,
    required this.resolvedOrchestratorProfile,
    required this.resolvedDefaultAssignee,
    required this.autoDecompose,
  });
  factory KanbanOrchestration.fromJson(Map<String, dynamic> j) =>
      KanbanOrchestration(
        orchestratorProfile: '${j['orchestrator_profile'] ?? ''}',
        defaultAssignee: '${j['default_assignee'] ?? ''}',
        resolvedOrchestratorProfile:
            '${j['resolved_orchestrator_profile'] ?? ''}',
        resolvedDefaultAssignee: '${j['resolved_default_assignee'] ?? ''}',
        autoDecompose: j['auto_decompose'] == true,
      );
}

class KanbanEventFrame {
  final List<Map<String, dynamic>> events;
  final int cursor;
  const KanbanEventFrame(this.events, this.cursor);
  factory KanbanEventFrame.fromJson(Map<String, dynamic> j) {
    final events = _maps(j['events']);
    var cursor = (j['cursor'] as num?)?.toInt() ?? 0;
    for (final e in events) {
      final id = (e['id'] as num?)?.toInt() ?? 0;
      if (id > cursor) cursor = id;
    }
    return KanbanEventFrame(events, cursor);
  }
}
