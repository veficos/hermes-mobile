/// RequestStore: the unified interactive-request queue (D9).
///
/// approval / clarify / secret / sudo / terminal.read requests arrive as
/// gateway events and are queued FIFO — a new request never overwrites an
/// unanswered one (F6). The UI shows a global badge + sheet (E9); responses
/// go back by `request_id` (F10).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gateway.dart';
import '../connections/connection_registry.dart';

enum RequestKind { approval, clarify, mcpSetup, secret, sudo, terminalRead }

class ClarifyQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final bool multiSelect;

  const ClarifyQuestion({
    required this.id,
    required this.question,
    this.choices = const [],
    this.multiSelect = false,
  });
}

class PendingRequest {
  final RequestKind kind;
  final String requestId;

  /// Runtime session id the request belongs to; responses must target this
  /// session (it may be a background session, not the currently open one).
  /// Null for legacy events that carried no session_id.
  final String? sessionId;
  final OwnerRoute? ownerRoute;
  final String? durableSessionId;
  final String? question;
  final String? command;
  final List<String> choices;
  final bool multiSelect;
  final List<ClarifyQuestion> questions;
  final Map<String, dynamic> payload;

  PendingRequest({
    required this.kind,
    required this.requestId,
    this.sessionId,
    this.ownerRoute,
    this.durableSessionId,
    this.question,
    this.command,
    this.choices = const [],
    this.multiSelect = false,
    this.questions = const [],
    this.payload = const {},
  });

  PendingRequest withScope({
    OwnerRoute? ownerRoute,
    String? durableSessionId,
  }) => PendingRequest(
    kind: kind,
    requestId: requestId,
    sessionId: sessionId,
    ownerRoute: ownerRoute ?? this.ownerRoute,
    durableSessionId: durableSessionId ?? this.durableSessionId,
    question: question,
    command: command,
    choices: choices,
    multiSelect: multiSelect,
    questions: questions,
    payload: payload,
  );

  PendingRequest withPayload(Map<String, dynamic> nextPayload) =>
      PendingRequest(
        kind: kind,
        requestId: requestId,
        sessionId: sessionId,
        ownerRoute: ownerRoute,
        durableSessionId: durableSessionId,
        question: question,
        command: command,
        choices: choices,
        multiSelect: multiSelect,
        questions: questions,
        payload: Map.unmodifiable(nextPayload),
      );

  factory PendingRequest.fromEvent(GatewayEvent e) {
    return PendingRequest._fromEvent(e);
  }

  factory PendingRequest.fromRoutedEvent(RoutedGatewayEvent routed) {
    final profile = routed.event.profile ?? routed.route.profile;
    return PendingRequest._fromEvent(
      routed.event,
      ownerRoute: OwnerRoute(
        connectionId: routed.route.connectionId,
        profile: profile,
      ),
    );
  }

  factory PendingRequest._fromEvent(GatewayEvent e, {OwnerRoute? ownerRoute}) {
    final payload = e.payload;
    final requestId = (payload['request_id'] ?? '').toString();
    RequestKind kind;
    switch (e.type) {
      case 'clarify.request':
        kind = RequestKind.clarify;
        break;
      case 'secret.request':
        kind = RequestKind.secret;
        break;
      case 'sudo.request':
        kind = RequestKind.sudo;
        break;
      case 'terminal.read.request':
        kind = RequestKind.terminalRead;
        break;
      case 'mcp.setup.request':
        kind = RequestKind.mcpSetup;
        break;
      default:
        kind = RequestKind.approval;
    }
    final questions = <ClarifyQuestion>[];
    final rawQuestions = payload['questions'];
    if (rawQuestions is List) {
      for (var index = 0; index < rawQuestions.length; index++) {
        final raw = rawQuestions[index];
        if (raw is! Map) continue;
        final text = (raw['question'] ?? '').toString().trim();
        if (text.isEmpty) continue;
        questions.add(
          ClarifyQuestion(
            id: (raw['id'] ?? raw['qid'] ?? index).toString(),
            question: text,
            choices: (raw['choices'] as List? ?? const [])
                .map((value) => value.toString())
                .toList(growable: false),
            multiSelect: raw['multi_select'] == true,
          ),
        );
      }
    }
    return PendingRequest(
      kind: kind,
      requestId: requestId,
      sessionId: e.sessionId,
      ownerRoute: ownerRoute,
      question: payload['question']?.toString(),
      command: payload['command']?.toString(),
      choices:
          (payload['choices'] as List?)?.map((c) => c.toString()).toList() ??
          const [],
      multiSelect: payload['multi_select'] == true,
      questions: questions,
      payload: Map.unmodifiable(payload),
    );
  }
}

class RequestResolution {
  final String requestId;
  final String scopeKey;
  final String status;
  final Map<String, dynamic> result;
  final DateTime resolvedAt;

  const RequestResolution({
    required this.requestId,
    required this.scopeKey,
    required this.status,
    required this.result,
    required this.resolvedAt,
  });
}

class RequestStore extends ChangeNotifier {
  static const _storageKey = 'hm_pending_interactive_requests_v1';
  final List<PendingRequest> _queue = [];
  final Map<String, RequestResolution> _resolved = {};
  ({OwnerRoute? route, String? durableId}) Function(String? runtimeId)?
  _scopeResolver;
  StreamSubscription? _sub;

  /// The request currently shown in the sheet (head of queue).
  PendingRequest? get current => _queue.isEmpty ? null : _queue.first;
  PendingRequest? byId(String? requestId) {
    if (requestId == null || requestId.isEmpty) return current;
    for (final request in _queue) {
      if (request.requestId == requestId) return request;
    }
    return null;
  }

  int get pendingCount => _queue.length;
  RequestResolution? resolution(String? requestId) =>
      requestId == null ? null : _resolved[requestId];

  void bindScopeResolver(
    ({OwnerRoute? route, String? durableId}) Function(String? runtimeId)
    resolver,
  ) {
    _scopeResolver = resolver;
  }

  String _scopeKey(PendingRequest request) => [
    request.ownerRoute?.connectionId.value ?? 'legacy',
    request.ownerRoute?.profile ?? '',
    request.durableSessionId ?? request.sessionId ?? 'unscoped',
  ].join('\u0000');

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      final rows = decoded is Map ? decoded['pending'] : decoded;
      if (rows is! List) return;
      for (final row in rows.whereType<Map>()) {
        final data = row.cast<String, dynamic>();
        final type = data['event_type']?.toString() ?? '';
        final payload = (data['payload'] as Map?)?.cast<String, dynamic>();
        if (type.isEmpty || payload == null) continue;
        final connectionId = data['connection_id']?.toString();
        final profile = data['profile']?.toString();
        final event = GatewayEvent(
          type: type,
          payload: payload,
          sessionId: data['session_id']?.toString(),
          profile: profile,
        );
        var request = connectionId == null
            ? PendingRequest.fromEvent(event)
            : PendingRequest.fromRoutedEvent(
                RoutedGatewayEvent(
                  route: OwnerRoute(
                    connectionId: ConnectionId(connectionId),
                    profile: profile,
                  ),
                  socketGeneration: 0,
                  event: event,
                ),
              );
        request = request.withScope(
          durableSessionId: data['durable_session_id']?.toString(),
        );
        enqueue(request);
      }
      if (decoded is Map && decoded['resolved'] is List) {
        for (final row in (decoded['resolved'] as List).whereType<Map>()) {
          final data = row.cast<String, dynamic>();
          final id = data['request_id']?.toString() ?? '';
          if (id.isEmpty) continue;
          _resolved[id] = RequestResolution(
            requestId: id,
            scopeKey: data['scope_key']?.toString() ?? '',
            status: data['status']?.toString() ?? 'completed',
            result:
                (data['result'] as Map?)?.cast<String, dynamic>() ?? const {},
            resolvedAt:
                DateTime.tryParse(data['resolved_at']?.toString() ?? '') ??
                DateTime.now(),
          );
        }
      }
    } catch (_) {}
  }

  String _eventType(RequestKind kind) => switch (kind) {
    RequestKind.approval => 'approval.request',
    RequestKind.clarify => 'clarify.request',
    RequestKind.mcpSetup => 'mcp.setup.request',
    RequestKind.secret => 'secret.request',
    RequestKind.sudo => 'sudo.request',
    RequestKind.terminalRead => 'terminal.read.request',
  };

  void _persist() {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _storageKey,
          jsonEncode({
            'version': 2,
            'pending': [
              for (final request in _queue)
                {
                  'scope_key': _scopeKey(request),
                  'event_type': _eventType(request.kind),
                  'payload': request.payload,
                  'session_id': request.sessionId,
                  'durable_session_id': request.durableSessionId,
                  'connection_id': request.ownerRoute?.connectionId.value,
                  'profile': request.ownerRoute?.profile,
                },
            ],
            'resolved': [
              for (final resolution in _resolved.values)
                {
                  'request_id': resolution.requestId,
                  'scope_key': resolution.scopeKey,
                  'status': resolution.status,
                  'result': resolution.result,
                  'resolved_at': resolution.resolvedAt.toIso8601String(),
                },
            ],
          }),
        );
      } catch (_) {
        // Persistence is recovery assistance; an unavailable platform plugin
        // must never break the live approval/clarify path.
      }
    }());
  }

  void attachEvents(Stream<GatewayEvent> events) {
    _sub?.cancel();
    _sub = events.listen((e) {
      switch (e.type) {
        case 'approval.request':
        case 'clarify.request':
        case 'sudo.request':
        case 'terminal.read.request':
        case 'mcp.setup.request':
          enqueue(PendingRequest.fromEvent(e));
        default:
          break;
      }
    });
  }

  void attachRoutedEvents(Stream<RoutedGatewayEvent> events) {
    _sub?.cancel();
    _sub = events.listen((routed) {
      switch (routed.event.type) {
        case 'approval.request':
        case 'clarify.request':
        case 'secret.request':
        case 'sudo.request':
        case 'terminal.read.request':
        case 'mcp.setup.request':
          enqueue(PendingRequest.fromRoutedEvent(routed));
        default:
          break;
      }
    });
  }

  /// Enqueue a request. A re-emitted event (e.g. after a WS reconnect-resume)
  /// carries the same request_id — refresh the existing entry instead of
  /// queueing a duplicate that could be answered twice.
  void enqueue(PendingRequest req) {
    final scope = _scopeResolver?.call(req.sessionId);
    req = req.withScope(
      ownerRoute: req.ownerRoute ?? scope?.route,
      durableSessionId: req.durableSessionId ?? scope?.durableId,
    );
    if (req.requestId.isNotEmpty) {
      final existing = _queue.indexWhere(
        (r) =>
            r.requestId == req.requestId &&
            r.kind == req.kind &&
            _scopeKey(r) == _scopeKey(req),
      );
      if (existing >= 0) {
        _queue[existing] = req;
        _persist();
        notifyListeners();
        return;
      }
    }
    _queue.add(req);
    _persist();
    notifyListeners();
  }

  void clear() {
    _queue.clear();
    _persist();
    notifyListeners();
  }

  /// Respond to the current request. Returns true when a response was sent;
  /// on failure the request is re-queued at the head (F10).
  Future<bool> respond(
    Future<Map<String, dynamic>> Function(PendingRequest req) send,
  ) async {
    if (_queue.isEmpty) return false;
    final req = _queue.removeAt(0);
    _persist();
    notifyListeners();
    try {
      final result = await send(req);
      _recordResolution(req, result);
      return true;
    } catch (_) {
      _queue.insert(0, req);
      _persist();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> respondById(
    String? requestId,
    Future<Map<String, dynamic>> Function(PendingRequest req) send, {
    Map<String, dynamic> resolution = const {},
  }) async {
    if (requestId == null || requestId.isEmpty) return respond(send);
    final index = _queue.indexWhere(
      (request) => request.requestId == requestId,
    );
    if (index < 0) return false;
    final req = _queue.removeAt(index);
    _persist();
    notifyListeners();
    try {
      final rpcResult = await send(req);
      _recordResolution(req, {...rpcResult, ...resolution});
      return true;
    } catch (_) {
      _queue.insert(index.clamp(0, _queue.length), req);
      _persist();
      notifyListeners();
      rethrow;
    }
  }

  void _recordResolution(PendingRequest request, Map<String, dynamic> result) {
    _resolved[request.requestId] = RequestResolution(
      requestId: request.requestId,
      scopeKey: _scopeKey(request),
      status: (result['status'] ?? result['choice'] ?? 'completed').toString(),
      result: Map.unmodifiable(result),
      resolvedAt: DateTime.now(),
    );
    // Retain a bounded recovery history.
    while (_resolved.length > 200) {
      _resolved.remove(_resolved.keys.first);
    }
    _persist();
  }

  void rotateDurableScope(String previous, String next, OwnerRoute route) {
    var changed = false;
    for (var index = 0; index < _queue.length; index++) {
      final request = _queue[index];
      if (request.durableSessionId == previous && request.ownerRoute == route) {
        _queue[index] = request.withScope(durableSessionId: next);
        changed = true;
      }
    }
    if (changed) _persist();
  }

  void updatePayload(String requestId, Map<String, dynamic> patch) {
    final index = _queue.indexWhere(
      (request) => request.requestId == requestId,
    );
    if (index < 0) return;
    final request = _queue[index];
    _queue[index] = request.withPayload({...request.payload, ...patch});
    _persist();
    notifyListeners();
  }

  /// Dismiss (deny-style) the current request without responding.
  void dismissCurrent() {
    if (_queue.isEmpty) return;
    _queue.removeAt(0);
    _persist();
    notifyListeners();
  }

  void dismissById(String? requestId) {
    if (requestId == null || requestId.isEmpty) return dismissCurrent();
    final before = _queue.length;
    _queue.removeWhere((request) => request.requestId == requestId);
    if (_queue.length != before) {
      _persist();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
