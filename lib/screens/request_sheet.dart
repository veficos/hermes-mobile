/// Global interactive-request sheet (D9).
///
/// Renders the head of the RequestStore queue with kind-appropriate input:
/// choices → buttons (approval/clarify), secret/sudo → password field,
/// terminal.read → text field. Reachable from any tab (E9).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/clarify_choice.dart';
import '../core/connections/connection_registry.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/request_store.dart';
import '../core/stores/session_store.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_states.dart';

Future<void> showRequestSheet(
  BuildContext context, {
  String? requestId,
  OwnerRoute? ownerRoute,
  String? sessionId,
}) async {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1200) {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Dialog(
          child: SizedBox(
            width: 560,
            child: RequestSheet(
              requestId: requestId,
              ownerRoute: ownerRoute,
              sessionId: sessionId,
            ),
          ),
        ),
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: width >= 840 ? 640 : double.infinity,
        ),
        child: RequestSheet(
          requestId: requestId,
          ownerRoute: ownerRoute,
          sessionId: sessionId,
        ),
      ),
    ),
  );
}

class RequestSheet extends StatefulWidget {
  final bool embedded;
  final String? requestId;
  final OwnerRoute? ownerRoute;
  final String? sessionId;

  const RequestSheet({
    super.key,
    this.embedded = false,
    this.requestId,
    this.ownerRoute,
    this.sessionId,
  });

  @override
  State<RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<RequestSheet> {
  final _textCtrl = TextEditingController();
  final Map<String, String> _batchAnswers = {};
  final Map<String, Set<String>> _batchChoices = {};
  // Single-question clarify: staged multi-select choices + the "other" text.
  final Set<String> _clarifySelected = {};
  final _clarifyOtherCtrl = TextEditingController();
  bool _busy = false;

  OwnerRoute? get _effectiveOwnerRoute =>
      widget.ownerRoute ??
      (widget.embedded ? context.read<SessionStore>().owner?.route : null);

  String? get _effectiveSessionId =>
      widget.sessionId ??
      (widget.embedded ? context.read<SessionStore>().durableId : null);

  PendingRequest? _selected(RequestStore store) => store.byId(
    widget.requestId,
    ownerRoute: _effectiveOwnerRoute,
    sessionId: _effectiveSessionId,
  );

  @override
  void dispose() {
    _clarifyOtherCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  String get _kindLabel {
    switch (_selected(context.read<RequestStore>())?.kind) {
      case RequestKind.approval:
        return context.l10n.chatRequestApproval;
      case RequestKind.clarify:
        return context.l10n.requestHermesQuestion;
      case RequestKind.mcpSetup:
        return context.l10n.chatRequestMcpConfig;
      case RequestKind.secret:
        return context.l10n.chatRequestSecret;
      case RequestKind.sudo:
        return context.l10n.chatRequestPassword;
      case RequestKind.terminalRead:
        return context.l10n.chatRequestTerminalInput;
      default:
        return context.l10n.requestPending;
    }
  }

  Future<void> _confirmAlwaysAllow(PendingRequest req, String choice) async {
    final detail = req.command ?? req.question ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.requestAlwaysAllowQuestion),
        content: Text(
          detail.isEmpty
              ? context.l10n.requestAlwaysAllowDescription
              : context.l10n.requestAlwaysAllowDetail(detail),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.agentAlwaysAllow),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _respond(choice: choice);
  }

  Future<void> _respond({String? choice, String? text}) async {
    final requests = context.read<RequestStore>();
    final target = _selected(requests);
    final session = context.read<SessionStore>();
    final connection = context.read<ConnectionStore>();
    final runtimeId = session.runtimeId;
    if (runtimeId == null && _selected(requests)?.sessionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.requestNoActiveSession)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await requests.respondById(
        widget.requestId,
        (req) async {
          // Respond against the request's own session — it may belong to a
          // background session, not the one currently open. Legacy events
          // without a session_id fall back to the current runtime id.
          final sessionId = req.sessionId ?? runtimeId!;
          final route = req.ownerRoute;
          Future<Map<String, dynamic>> send(
            String method,
            Map<String, dynamic> params,
          ) {
            if (route != null) {
              return connection.requestForOwner(route, method, params);
            }
            final gateway = connection.gateway;
            if (gateway == null) {
              throw StateError(context.l10n.requestConnectionUnavailable);
            }
            return gateway.request(method, params);
          }

          switch (req.kind) {
            case RequestKind.approval:
              return send('approval.respond', {
                'session_id': sessionId,
                'request_id': req.requestId,
                'choice': choice ?? 'deny',
              });
            case RequestKind.clarify:
              return send('clarify.respond', {
                'session_id': sessionId,
                'request_id': req.requestId,
                'answer': choice ?? text ?? '',
              });
            case RequestKind.mcpSetup:
              final server = req.payload['server']?.toString() ?? '';
              return send('mcp.setup.respond', {
                'request_id': req.requestId,
                'result':
                    '{"server":${_jsonString(server)},"status":${_jsonString(choice ?? 'declined')}}',
              });
            case RequestKind.secret:
              return send('secret.respond', {
                'session_id': sessionId,
                'request_id': req.requestId,
                'value': text ?? '',
              });
            case RequestKind.sudo:
              return send('sudo.respond', {
                'session_id': sessionId,
                'request_id': req.requestId,
                'password': text ?? '',
              });
            case RequestKind.terminalRead:
              return send('terminal.read.respond', {
                'session_id': sessionId,
                'request_id': req.requestId,
                'text': text ?? '',
              });
          }
        },
        ownerRoute: _effectiveOwnerRoute,
        sessionId: _effectiveSessionId,
        kind: target?.kind,
        resolution: {
          'choice': ?choice,
          if (text != null && text.isNotEmpty) 'answer': text,
          'status': choice == 'deny' || choice == 'declined'
              ? 'declined'
              : 'completed',
        },
      );
      _textCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.requestRespondFailed('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _respondBatch(PendingRequest request) async {
    setState(() => _busy = true);
    final requests = context.read<RequestStore>();
    final connection = context.read<ConnectionStore>();
    try {
      await requests.respondById(
        widget.requestId,
        (req) async {
          final route = req.ownerRoute;
          final gateway = connection.gateway;
          for (final question in req.questions) {
            final selected = _batchChoices[question.id] ?? const <String>{};
            final answer = selected.isNotEmpty
                ? encodeClarifyAnswer(
                    selected,
                    multiSelect: question.multiSelect,
                  )
                : (_batchAnswers[question.id] ?? '').trim();
            final params = {
              'request_id': req.requestId,
              'question_id': question.id,
              'answer': answer,
            };
            if (route != null) {
              await connection.requestForOwner(
                route,
                'clarify.respond',
                params,
              );
            } else {
              if (gateway == null) {
                throw StateError(context.l10n.requestConnectionUnavailable);
              }
              await gateway.request('clarify.respond', params);
            }
          }
          return const {};
        },
        ownerRoute: _effectiveOwnerRoute,
        sessionId: _effectiveSessionId,
        kind: request.kind,
        resolution: {
          'status': 'completed',
          'answers': {
            for (final question in request.questions)
              question.id: (_batchChoices[question.id]?.isNotEmpty == true)
                  ? encodeClarifyAnswer(
                      _batchChoices[question.id]!,
                      multiSelect: question.multiSelect,
                    )
                  : (_batchAnswers[question.id] ?? '').trim(),
          },
        },
      );
      _batchAnswers.clear();
      _batchChoices.clear();
    } catch (error) {
      if (mounted) {
        showHermesErrorSnackBar(
          context,
          error,
          fallback: context.l10n.requestAnswerFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setupMcp(PendingRequest request) async {
    final l10n = context.l10n;
    final connection = context.read<ConnectionStore>();
    final session = context.read<SessionStore>();
    final requests = context.read<RequestStore>();
    final route = request.ownerRoute;
    final api = route == null
        ? connection.api
        : connection.runtimeFor(route).api;
    if (api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.requestConnectionUnavailable)),
      );
      return;
    }
    void requireOwnerApi() {
      final current = route == null
          ? connection.api
          : connection.runtimeFor(route).api;
      if (!identical(current, api)) {
        throw StateError(l10n.requestConnectionUnavailable);
      }
    }

    final gateway = route == null ? connection.gateway : null;
    final profile = route?.profile;
    final name = (request.payload['server'] ?? request.payload['name'] ?? '')
        .toString();
    if (name.isEmpty) {
      showHermesErrorSnackBar(
        context,
        StateError(context.l10n.requestMcpNameMissing),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final servers = await api.mcpServers(profile: profile);
      requireOwnerApi();
      var installed = servers.any((server) => server['name'] == name);
      if (!installed) {
        final catalog = await api.mcpCatalog(profile: profile);
        final entry = catalog.cast<Map<String, dynamic>?>().firstWhere(
          (item) => item?['name'] == name,
          orElse: () => null,
        );
        final env = await _collectRequiredEnv(entry);
        if (env == null) return;
        requireOwnerApi();
        await api.mcpInstallCatalog(name, env: env, profile: profile);
        installed = true;
      }
      if (installed) await api.mcpSetEnabled(name, true, profile: profile);
      requireOwnerApi();

      Map<String, dynamic> test = await api.mcpTest(name, profile: profile);
      if (test['auth_required'] == true || test['needs_auth'] == true) {
        var flowId = (request.payload['oauth_flow_id'] ?? '').toString();
        var url = (request.payload['authorization_url'] ?? '').toString();
        if (flowId.isEmpty) {
          final started = await api.mcpStartAuth(name, profile: profile);
          flowId = (started['flow_id'] ?? '').toString();
          url = (started['authorization_url'] ?? '').toString();
          requests.updatePayload(
            request.requestId,
            {'oauth_flow_id': flowId, 'authorization_url': url},
            ownerRoute: request.ownerRoute,
            sessionId: request.sessionId,
            kind: request.kind,
          );
        }
        if (flowId.isEmpty || url.isEmpty) {
          throw StateError(l10n.mcpOAuthMissingUrl);
        }
        if (!await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        )) {
          throw StateError(l10n.mcpBrowserOpenFailed);
        }
        requireOwnerApi();
        Map<String, dynamic>? approved;
        for (var attempt = 0; attempt < 180 && mounted; attempt++) {
          final flow = await api.mcpAuthFlow(flowId, profile: profile);
          requireOwnerApi();
          final status = flow['status']?.toString();
          if (status == 'approved') {
            approved = flow;
            break;
          }
          if (status == 'error' || status == 'denied') {
            throw StateError(
              (flow['error'] ?? l10n.mcpOAuthAuthorizationFailed).toString(),
            );
          }
          await Future<void>.delayed(const Duration(seconds: 1));
        }
        if (approved == null) {
          throw TimeoutException(l10n.requestOAuthTimeout);
        }
        requests.updatePayload(
          request.requestId,
          {'oauth_flow_id': null, 'authorization_url': null},
          ownerRoute: request.ownerRoute,
          sessionId: request.sessionId,
          kind: request.kind,
        );
        test = await api.mcpTest(name, profile: profile);
      }
      if (test['ok'] != true && test['reachable'] != true) {
        throw StateError(
          (test['error'] ?? l10n.requestMcpTestFailed).toString(),
        );
      }
      final runtimeId = request.sessionId ?? session.runtimeId;
      final params = {'confirm': true, 'session_id': ?runtimeId};
      if (request.ownerRoute != null) {
        await connection.requestForOwner(
          request.ownerRoute!,
          'reload.mcp',
          params,
        );
      } else {
        if (gateway == null || !identical(connection.gateway, gateway)) {
          throw StateError(l10n.requestConnectionUnavailable);
        }
        await gateway.request('reload.mcp', params);
      }
      await _respond(choice: 'installed');
    } catch (error) {
      if (mounted) {
        showHermesErrorSnackBar(
          context,
          error,
          fallback: context.l10n.requestMcpSetupFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, String>?> _collectRequiredEnv(
    Map<String, dynamic>? entry,
  ) async {
    final specs = (entry?['required_env'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList(growable: false);
    if (specs.isEmpty) return const {};
    final controllers = {
      for (final spec in specs)
        spec['name'].toString(): TextEditingController(),
    };
    try {
      return await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            context.l10n.requestConfigureMcp(
              (entry?['name'] ?? 'MCP').toString(),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final spec in specs)
                TextField(
                  controller: controllers[spec['name'].toString()],
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: (spec['prompt'] ?? spec['name']).toString(),
                    suffixText: spec['required'] == true
                        ? context.l10n.mcpRequired
                        : context.l10n.mcpOptional,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final values = {
                  for (final item in controllers.entries)
                    item.key: item.value.text.trim(),
                };
                final missing = specs.any(
                  (spec) =>
                      spec['required'] == true &&
                      (values[spec['name'].toString()] ?? '').isEmpty,
                );
                if (!missing) Navigator.of(dialogContext).pop(values);
              },
              child: Text(context.l10n.commonContinue),
            ),
          ],
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in controllers.values) {
          controller.dispose();
        }
      });
    }
  }

  /// "关闭" must not silently drop the request: approvals get an explicit
  /// deny so the agent unblocks server-side; other kinds have no deny
  /// semantics, so discarding needs a confirmation first.
  Future<void> _closeCurrent() async {
    final requests = context.read<RequestStore>();
    final req = _selected(requests);
    if (req == null) return;
    if (req.kind == RequestKind.approval) {
      await _respond(choice: 'deny');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.requestCloseQuestion),
        content: Text(context.l10n.requestCloseDescription),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(context.l10n.commonClose),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      requests.dismissById(
        widget.requestId,
        ownerRoute: _effectiveOwnerRoute,
        sessionId: _effectiveSessionId,
        kind: req.kind,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requests = context.watch<RequestStore>();
    final req = _selected(requests);
    if (req == null) {
      if (widget.embedded && widget.requestId != null) {
        final resolved = requests.resolution(
          widget.requestId,
          ownerRoute: _effectiveOwnerRoute,
          sessionId: _effectiveSessionId,
        );
        final detail =
            resolved?.result['choice'] ??
            resolved?.result['answer'] ??
            resolved?.status ??
            context.l10n.requestProcessed;
        return Card(
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline),
            title: Text(context.l10n.requestInteractionProcessed),
            subtitle: Text(detail.toString()),
          ),
        );
      }
      // Queue drained while the sheet was open.
      if (!widget.embedded) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final palette = HermesPalette.of(context);
    final warning = theme.brightness == Brightness.dark
        ? HermesSemanticDark.orange
        : HermesSemantic.orange;
    // Prototype parity (`.reqcard` variants in scenarioB): each request kind
    // gets a distinct tint — approval/secret/sudo/terminal-read stay warning
    // orange, clarify uses the accent color, mcp-setup uses purple — instead
    // of every kind rendering identically.
    final kindTone = switch (req.kind) {
      RequestKind.clarify => palette.accent,
      RequestKind.mcpSetup =>
        theme.brightness == Brightness.dark
            ? HermesSemanticDark.purple
            : HermesSemantic.purple,
      RequestKind.approval ||
      RequestKind.secret ||
      RequestKind.sudo ||
      RequestKind.terminalRead => warning,
    };
    final needsText =
        req.kind == RequestKind.secret ||
        req.kind == RequestKind.sudo ||
        req.kind == RequestKind.terminalRead;
    final isSecret =
        req.kind == RequestKind.secret || req.kind == RequestKind.sudo;

    final content = Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_kindLabel, style: theme.textTheme.titleMedium),
              ),
              if (req.kind == RequestKind.approval)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: warning.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(HermesRadius.capsule),
                  ),
                  child: Text(
                    context.l10n.agentAwaitingApproval,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (req.command != null && req.command!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: palette.codeBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                req.command!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (req.question != null && req.question!.isNotEmpty)
            Text(req.question!),
          if (req.kind == RequestKind.mcpSetup) ...[
            Text(
              context.l10n.requestServer(
                (req.payload['server'] ?? context.l10n.commonUnknownError)
                    .toString(),
              ),
            ),
            if ((req.payload['reason'] ?? '').toString().isNotEmpty)
              Text((req.payload['reason'] ?? '').toString()),
          ],
          if (req.questions.isNotEmpty) ...[
            for (var index = 0; index < req.questions.length; index++)
              _buildBatchQuestion(req.questions[index], index),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _respondBatch(req),
              child: Text(context.l10n.requestSubmitAllAnswers),
            ),
          ],
          const SizedBox(height: 12),
          if (req.questions.isNotEmpty)
            const SizedBox.shrink()
          else if (req.kind == RequestKind.clarify &&
              req.choices.isNotEmpty &&
              !needsText)
            _buildClarifyChoices(req)
          else if (req.choices.isNotEmpty && !needsText)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in req.choices)
                  if (req.kind == RequestKind.approval && choice == 'deny')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _respond(choice: choice),
                      icon: const Icon(Icons.close),
                      label: Text(_choiceLabel(req.kind, choice)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HermesSemantic.red,
                      ),
                    )
                  else if (req.kind == RequestKind.approval &&
                      choice == 'always')
                    // Prototype parity (`.btn.outline`): "总是允许" is the most
                    // permanent choice, so it gets an outline treatment
                    // distinct from "本次会话允许"'s filled/ghost look below.
                    // Desktop parity: this one writes a permanent rule to
                    // config.yaml, so it goes through a confirm step rather
                    // than firing straight from a single tap.
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _confirmAlwaysAllow(req, choice),
                      child: Text(_choiceLabel(req.kind, choice)),
                    )
                  else
                    FilledButton(
                      onPressed: _busy ? null : () => _respond(choice: choice),
                      style:
                          req.kind == RequestKind.approval && choice == 'once'
                          ? FilledButton.styleFrom(backgroundColor: warning)
                          : null,
                      child: Text(_choiceLabel(req.kind, choice)),
                    ),
              ],
            )
          else if (req.kind == RequestKind.mcpSetup) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _respond(choice: 'declined'),
                    child: Text(context.l10n.requestConfigureLater),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _setupMcp(req),
                    child: Text(
                      _busy
                          ? context.l10n.requestConfiguring
                          : context.l10n.requestInstallEnable,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (needsText) ...[
            TextField(
              controller: _textCtrl,
              obscureText: isSecret,
              autofocus: true,
              decoration: InputDecoration(
                hintText: isSecret
                    ? context.l10n.requestEnterContent
                    : context.l10n.requestEnterText,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) => _respond(text: v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : () => _respond(text: _textCtrl.text),
              child: Text(context.l10n.commonSend),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (requests.pendingCount > 1)
                Text(
                  context.l10n.requestMorePending(requests.pendingCount - 1),
                  style: theme.textTheme.labelSmall,
                ),
              TextButton(
                onPressed: _busy ? null : _closeCurrent,
                child: Text(context.l10n.commonClose),
              ),
            ],
          ),
        ],
      ),
    );
    if (!widget.embedded) return content;
    return Container(
      key: const ValueKey('inline-request-card'),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          kindTone.withValues(alpha: .05),
          palette.surface,
        ),
        borderRadius: BorderRadius.circular(HermesRadius.card),
        border: Border.all(color: kindTone.withValues(alpha: .45)),
      ),
      child: content,
    );
  }

  String _choiceLabel(RequestKind kind, String choice) {
    if (kind == RequestKind.approval) {
      switch (choice) {
        case 'once':
          return context.l10n.requestAllowOnce;
        case 'session':
          return context.l10n.requestAllowSession;
        case 'always':
          return context.l10n.agentAlwaysAllow;
        case 'deny':
          return context.l10n.agentDeny;
      }
    }
    return choice;
  }

  /// Single-question clarify with choices — recommended-first ordering, A/B/C
  /// key badges, multi-select staging, and an "other" free-text row (desktop
  /// `ClarifyToolSinglePending` parity).
  Widget _buildClarifyChoices(PendingRequest req) {
    final ordered = orderChoices(req.choices);
    final palette = HermesPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < ordered.length; i++)
              _clarifyChoiceChip(req, ordered[i], i),
          ],
        ),
        if (req.multiSelect) ...[
          const SizedBox(height: 10),
          FilledButton(
            onPressed: (_busy || _clarifySelected.isEmpty)
                ? null
                : () => _respond(
                    text: encodeClarifyAnswer(
                      _clarifySelected,
                      multiSelect: true,
                    ),
                  ),
            child: Text(
              context.l10n.requestSubmitSelected(_clarifySelected.length),
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: _clarifyOtherCtrl,
          decoration: InputDecoration(
            isDense: true,
            hintText: context.l10n.requestCustomAnswer,
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send, size: 18),
              onPressed: _busy
                  ? null
                  : () {
                      final value = _clarifyOtherCtrl.text.trim();
                      if (value.isNotEmpty) _respond(text: value);
                    },
            ),
          ),
          style: TextStyle(fontSize: 13, color: palette.text),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) _respond(text: v.trim());
          },
        ),
      ],
    );
  }

  Widget _clarifyChoiceChip(PendingRequest req, String choice, int index) {
    final recommended = isRecommendedChoice(choice);
    final palette = HermesPalette.of(context);
    final label = _choiceChipLabel(choice, index, recommended: recommended);
    if (req.multiSelect) {
      return Tooltip(
        message: bareChoice(choice),
        child: FilterChip(
          label: label,
          selected: _clarifySelected.contains(choice),
          showCheckmark: true,
          side: recommended
              ? BorderSide(color: palette.accent, width: 1.4)
              : null,
          onSelected: _busy
              ? null
              : (on) => setState(() {
                  if (on) {
                    _clarifySelected.add(choice);
                  } else {
                    _clarifySelected.remove(choice);
                  }
                }),
        ),
      );
    }
    return Tooltip(
      message: bareChoice(choice),
      child: ActionChip(
        label: label,
        side: recommended
            ? BorderSide(color: palette.accent, width: 1.4)
            : null,
        onPressed: _busy ? null : () => _respond(choice: bareChoice(choice)),
      ),
    );
  }

  Widget _choiceChipLabel(
    String choice,
    int index, {
    required bool recommended,
  }) {
    final palette = HermesPalette.of(context);
    final maxWidth = (MediaQuery.sizeOf(context).width - 96).clamp(96.0, 360.0);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 6),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: palette.text3.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              choiceKeyBadge(index),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: bareChoice(choice)),
                  if (recommended) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: context.l10n.requestRecommended,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.accent,
                      ),
                    ),
                  ],
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchQuestion(ClarifyQuestion question, int index) {
    final selected = _batchChoices[question.id] ?? const <String>{};
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${index + 1}. ${question.question}'),
          if (question.choices.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in orderChoices(
                  question.choices,
                ).asMap().entries)
                  FilterChip(
                    label: _choiceChipLabel(
                      entry.value,
                      entry.key,
                      recommended: isRecommendedChoice(entry.value),
                    ),
                    selected: selected.contains(entry.value),
                    side: isRecommendedChoice(entry.value)
                        ? BorderSide(
                            color: HermesPalette.of(context).accent,
                            width: 1.4,
                          )
                        : null,
                    onSelected: _busy
                        ? null
                        : (enabled) {
                            setState(() {
                              final values = _batchChoices.putIfAbsent(
                                question.id,
                                () => <String>{},
                              );
                              if (!question.multiSelect) values.clear();
                              enabled
                                  ? values.add(entry.value)
                                  : values.remove(entry.value);
                            });
                          },
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            TextFormField(
              initialValue: _batchAnswers[question.id],
              maxLines: 3,
              decoration: InputDecoration(
                hintText: context.l10n.agentEnterAnswer,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => _batchAnswers[question.id] = value,
            ),
          ],
        ],
      ),
    );
  }

  String _jsonString(String value) =>
      '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
}
