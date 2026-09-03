import 'dart:convert';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/clarify_choice.dart';
import '../core/stores/bot_store.dart';
import '../core/stores/request_store.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_toast.dart';

/// Full-screen Bot Group chat. Replaces the old height-capped modal dialog
/// so there's room for a real message list, an @mention autocomplete strip
/// and legible cap/hold banners instead of squeezing everything into a
/// ~58%-height AlertDialog.
class BotGroupChatScreen extends StatefulWidget {
  const BotGroupChatScreen({super.key, required this.group, this.onEdit});

  final BotGroup group;
  final VoidCallback? onEdit;

  @override
  State<BotGroupChatScreen> createState() => _BotGroupChatScreenState();
}

class _BotGroupChatScreenState extends State<BotGroupChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _attachments = <BotGroupAttachment>[];
  String? _replyThreadId;
  String? _mentionQuery;

  static final _mentionPattern = RegExp(r'(?:^|\s)@([A-Za-z0-9._-]*)$');

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onComposerChanged(String text) {
    final match = _mentionPattern.firstMatch(text);
    final query = match?.group(1);
    if (query != _mentionQuery) setState(() => _mentionQuery = query);
  }

  void _insertMention(String handle) {
    final text = _controller.text;
    final match = _mentionPattern.firstMatch(text);
    if (match == null) return;
    final prefixEnd = match.start + (match.group(0)!.startsWith(' ') ? 1 : 0);
    final newText = '${text.substring(0, prefixEnd)}@$handle ${text.substring(match.end)}';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
    setState(() => _mentionQuery = null);
  }

  Future<void> _pickAttachments() async {
    final l10n = context.l10n;
    try {
      final picked = await fs.openFiles();
      for (final file in picked) {
        final length = await file.length();
        if (length > 20 * 1024 * 1024) {
          throw StateError(l10n.agentAttachmentTooLarge(file.name));
        }
        final bytes = await file.readAsBytes();
        final ext = file.name.split('.').last.toLowerCase();
        final image = const {
          'png',
          'jpg',
          'jpeg',
          'gif',
          'webp',
          'bmp',
        }.contains(ext);
        final mime = image
            ? 'image/${ext == 'jpg' ? 'jpeg' : ext}'
            : 'application/octet-stream';
        _attachments.add(
          BotGroupAttachment(
            name: file.name,
            dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
            image: image,
          ),
        );
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentAttachFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  Future<void> _send(BotStore store) async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;
    _controller.clear();
    final sentAttachments = List.of(_attachments);
    final threadId = _replyThreadId;
    setState(() {
      _attachments.clear();
      _replyThreadId = null;
      _mentionQuery = null;
    });
    try {
      await store.sendGroupPrompt(
        widget.group,
        text,
        attachments: sentAttachments,
        threadId: threadId,
      );
    } catch (e) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentGroupSendFailed('$e'),
          kind: HermesToastKind.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BotStore>(
      builder: (context, store, _) {
        final members = widget.group.memberKeys
            .map((key) => store.bots.where((b) => b.key == key).firstOrNull)
            .whereType<BotIdentity>()
            .toList();
        final messages = store.messagesFor(widget.group.id);
        final speaker = store.groupSpeaker(widget.group.id);
        final busy = store.isGroupBusy(widget.group.id);
        final pending = store.pendingRequestsFor(widget.group.id);
        final held = widget.group.memberKeys
            .where((key) => store.isMemberHeld(widget.group.id, key))
            .map(
              (key) => store.bots.where((b) => b.key == key).firstOrNull?.displayName,
            )
            .whereType<String>()
            .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(widget.group.name),
            actions: [
              if (busy)
                IconButton(
                  tooltip: context.l10n.commonStop,
                  onPressed: () => store.stopGroup(widget.group),
                  icon: const Icon(Icons.stop_circle_outlined),
                ),
              if (widget.onEdit != null)
                IconButton(
                  tooltip: context.l10n.agentEditGroup,
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
          body: Column(
            children: [
              if (speaker != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.l10n.agentBotThinking(speaker))),
                    ],
                  ),
                ),
              if (held.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final name in held)
                        Chip(
                          avatar: const Icon(Icons.pause_circle_outline, size: 16),
                          label: Text(context.l10n.agentBotPaused(name)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              for (final request in pending)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _groupRequestCard(store, request),
                ),
              Expanded(
                child: messages.isEmpty
                    ? Center(child: Text(context.l10n.agentStartGroupChat))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        itemCount: messages.length,
                        itemBuilder: (_, index) =>
                            _messageBubble(context, store, messages[index]),
                      ),
              ),
              if (_replyThreadId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InputChip(
                      avatar: const Icon(Icons.reply, size: 16),
                      label: Text(
                        context.l10n.agentReplyTo(_shortThread(_replyThreadId!)),
                      ),
                      onDeleted: () => setState(() => _replyThreadId = null),
                    ),
                  ),
                ),
              if (_mentionQuery != null)
                _mentionSuggestions(context, members, _mentionQuery!),
              _composer(context, store),
            ],
          ),
        );
      },
    );
  }

  String _shortThread(String threadId) =>
      threadId.length > 8 ? threadId.substring(threadId.length - 8) : threadId;

  Widget _mentionSuggestions(
    BuildContext context,
    List<BotIdentity> members,
    String query,
  ) {
    final lower = query.toLowerCase();
    final matches = [
      if ('all'.startsWith(lower))
        (handle: 'all', label: context.l10n.agentMentionAll),
      for (final bot in members)
        if (bot.profile.toLowerCase().contains(lower) ||
            bot.displayName.toLowerCase().contains(lower))
          (handle: bot.profile, label: bot.displayName),
    ];
    if (matches.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final match in matches)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: ActionChip(
                avatar: const Icon(Icons.alternate_email, size: 14),
                label: Text(match.label),
                onPressed: () => _insertMention(match.handle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _messageBubble(
    BuildContext context,
    BotStore store,
    BotRoomMessage message,
  ) {
    final theme = Theme.of(context);
    if (message.author == 'System') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    final mine = message.author == 'You';
    final displayName = mine
        ? context.l10n.botAuthorYou
        : message.author == 'Bot'
        ? context.l10n.botAuthorFallback
        : message.author;
    final bot = mine
        ? null
        : store.bots.where((b) => b.displayName == message.author).firstOrNull;
    final bubbleColor = mine
        ? theme.colorScheme.primaryContainer
        : (bot != null ? botAvatarColor(bot.metadata) : null)?.withValues(
              alpha: 0.16,
            ) ??
          theme.colorScheme.surfaceContainerHigh;
    final selected = _replyThreadId == message.threadId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!mine) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  (bot != null ? botAvatarColor(bot.metadata) : null) ??
                  theme.colorScheme.secondaryContainer,
              child: Text(
                displayName.isEmpty ? '?' : displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onTap: () => setState(() => _replyThreadId = message.threadId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(color: theme.colorScheme.primary, width: 1.5)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!mine)
                      Text(
                        displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(message.text),
                  ],
                ),
              ),
            ),
          ),
          if (mine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context, BotStore store) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 0; i < _attachments.length; i++)
                      InputChip(
                        label: Text(_attachments[i].name),
                        onDeleted: () => setState(() => _attachments.removeAt(i)),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: context.l10n.chatAttachFiles,
                  onPressed: _pickAttachments,
                  icon: const Icon(Icons.attach_file),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: _onComposerChanged,
                    decoration: InputDecoration(
                      hintText: context.l10n.agentMentionHint,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  onPressed: () => _send(store),
                  icon: Icon(
                    store.isGroupBusy(widget.group.id)
                        ? Icons.add_comment_outlined
                        : Icons.send,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupRequestCard(BotStore store, BotGroupPendingRequest pending) {
    final request = pending.request;
    final approval = request.kind == RequestKind.approval;
    final title = approval
        ? context.l10n.agentAwaitingApproval
        : context.l10n.agentNeedsInformation;
    final detail = request.questions.isNotEmpty
        ? request.questions.map((question) => question.question).join('\n')
        : request.question ?? request.command ?? '';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(approval ? Icons.shield_outlined : Icons.help_outline, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.agentRequestSummary(title, pending.memberName)),
                  if (detail.isNotEmpty)
                    Text(
                      detail,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _answerGroupRequest(store, pending),
              child: Text(context.l10n.agentRespond),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _answerGroupRequest(
    BotStore store,
    BotGroupPendingRequest pending,
  ) async {
    final request = pending.request;
    final controllers = <String, TextEditingController>{};
    final selected = <String, Set<String>>{};
    for (final question in request.questions) {
      controllers[question.id] = TextEditingController();
      selected[question.id] = <String>{};
    }
    final single = TextEditingController();
    selected[''] = <String>{};
    final answer = await showDialog<_GroupRequestAnswer>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final approval = request.kind == RequestKind.approval;
          final approvalChoices = request.choices.isEmpty
              ? const ['once', 'always', 'deny']
              : request.choices;

          bool hasAnswer(String key, TextEditingController controller) =>
              selected[key]!.isNotEmpty || controller.text.trim().isNotEmpty;
          final canSubmit = request.questions.isNotEmpty
              ? request.questions.every(
                  (question) => hasAnswer(question.id, controllers[question.id]!),
                )
              : hasAnswer('', single);

          Widget choicesFor(String key, List<String> choices, bool multiSelect) =>
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final choice in orderChoices(choices))
                    FilterChip(
                      label: Text(bareChoice(choice)),
                      selected: selected[key]!.contains(choice),
                      onSelected: (on) => setDialogState(() {
                        if (!multiSelect) selected[key]!.clear();
                        if (on) {
                          selected[key]!.add(choice);
                        } else {
                          selected[key]!.remove(choice);
                        }
                      }),
                    ),
                ],
              );

          return AlertDialog(
            title: Text(context.l10n.agentMemberRequest(pending.memberName)),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (approval) ...[
                      Text(
                        request.command ??
                            request.question ??
                            context.l10n.agentAllowOperationQuestion,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final choice in approvalChoices)
                            choice == 'deny'
                                ? OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      _GroupRequestAnswer(choice: choice),
                                    ),
                                    icon: const Icon(Icons.close),
                                    label: Text(context.l10n.agentDeny),
                                  )
                                : FilledButton(
                                    onPressed: () => Navigator.pop(
                                      dialogContext,
                                      _GroupRequestAnswer(choice: choice),
                                    ),
                                    child: Text(
                                      choice == 'always'
                                          ? context.l10n.agentAlwaysAllow
                                          : context.l10n.agentAllow,
                                    ),
                                  ),
                        ],
                      ),
                    ] else if (request.questions.isNotEmpty) ...[
                      for (var index = 0; index < request.questions.length; index++) ...[
                        Text('${index + 1}. ${request.questions[index].question}'),
                        if (request.questions[index].choices.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          choicesFor(
                            request.questions[index].id,
                            request.questions[index].choices,
                            request.questions[index].multiSelect,
                          ),
                        ],
                        const SizedBox(height: 6),
                        TextField(
                          controller: controllers[request.questions[index].id],
                          decoration: InputDecoration(
                            hintText: context.l10n.agentCustomAnswer,
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ] else ...[
                      Text(request.question ?? context.l10n.agentEnterAnswer),
                      if (request.choices.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        choicesFor('', request.choices, request.multiSelect),
                      ],
                      const SizedBox(height: 8),
                      TextField(
                        controller: single,
                        decoration: InputDecoration(
                          hintText: context.l10n.agentCustomAnswer,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(dialogContext.l10n.commonCancel),
              ),
              if (!approval)
                FilledButton(
                  onPressed: canSubmit
                      ? () {
                          if (request.questions.isNotEmpty) {
                            Navigator.pop(
                              dialogContext,
                              _GroupRequestAnswer(
                                answers: {
                                  for (final question in request.questions)
                                    question.id:
                                        selected[question.id]!.isNotEmpty
                                        ? encodeClarifyAnswer(
                                            selected[question.id]!,
                                            multiSelect: question.multiSelect,
                                          )
                                        : controllers[question.id]!.text.trim(),
                                },
                              ),
                            );
                          } else {
                            Navigator.pop(
                              dialogContext,
                              _GroupRequestAnswer(
                                answer: selected['']!.isNotEmpty
                                    ? encodeClarifyAnswer(
                                        selected['']!,
                                        multiSelect: request.multiSelect,
                                      )
                                    : single.text.trim(),
                              ),
                            );
                          }
                        }
                      : null,
                  child: Text(context.l10n.commonSubmit),
                ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final controller in controllers.values) {
        controller.dispose();
      }
      single.dispose();
    });
    if (answer == null || !mounted) return;
    try {
      await store.respondToGroupRequest(
        pending,
        choice: answer.choice,
        answer: answer.answer,
        answers: answer.answers,
      );
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.agentRespondFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    }
  }
}

class _GroupRequestAnswer {
  final String? choice;
  final String? answer;
  final Map<String, String> answers;

  const _GroupRequestAnswer({this.choice, this.answer, this.answers = const {}});
}
