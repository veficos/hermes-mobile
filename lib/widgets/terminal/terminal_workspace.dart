/// Shared terminal chrome used by TerminalScreen and the right-rail panel.
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xterm/xterm.dart';

import '../../core/models.dart';
import '../../core/clipboard.dart';
import '../../core/terminal_interactions.dart';
import '../../core/stores/terminal_store.dart';
import '../../screens/chat_screen.dart';
import '../../theme/hermes_tokens.dart';
import 'terminal_cwd_picker.dart';
import 'terminal_visuals.dart';

const String kTerminalChatDraftKey = 'hm_chat_draft';

enum TerminalInputMode { command, interactive }

class TerminalWorkspace extends StatefulWidget {
  final bool compact;
  final bool autofocusCommand;
  final bool navigateOnSendToChat;

  const TerminalWorkspace({
    super.key,
    this.compact = false,
    this.autofocusCommand = false,
    this.navigateOnSendToChat = true,
  });

  @override
  State<TerminalWorkspace> createState() => _TerminalWorkspaceState();
}

class _TerminalWorkspaceState extends State<TerminalWorkspace> {
  final Map<String, TerminalController> _controllers = {};
  final TextEditingController _cmdController = TextEditingController();
  final FocusNode _cmdFocusNode = FocusNode();
  final FocusNode _historyKeyFocusNode = FocusNode(skipTraversal: true);
  final Map<String, int> _historyIndex = {};
  final Map<String, TextEditingValue> _commandDrafts = {};
  bool _draggingPaths = false;
  TerminalInputMode _inputMode = TerminalInputMode.command;

  TerminalController _controller(String id) =>
      _controllers.putIfAbsent(id, TerminalController.new);

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _cmdController.dispose();
    _cmdFocusNode.dispose();
    _historyKeyFocusNode.dispose();
    super.dispose();
  }

  void _ensureCmdFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cmdFocusNode.requestFocus();
    });
  }

  Future<void> _newSession({String? cwd}) async {
    final store = context.read<TerminalStore>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await store.newSession(cwd: cwd);
      _ensureCmdFocus();
    } catch (error) {
      if (mounted) {
        if (store.sessions.length >= store.maxSessions) {
          await _showSessionManager(store, createAfterClose: true, cwd: cwd);
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(context.l10n.terminalStartFailed('$error'))),
          );
        }
      }
    }
  }

  Future<void> _newSshSession() async {
    final host = TextEditingController();
    final user = TextEditingController();
    final port = TextEditingController();
    final key = TextEditingController();
    final cwd = TextEditingController();
    final target = await showDialog<SshTerminalTarget>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.terminalNewSsh),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: host,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.l10n.terminalSshHost,
                  ),
                ),
                TextField(
                  controller: user,
                  decoration: InputDecoration(
                    labelText: context.l10n.terminalSshUserOptional,
                  ),
                ),
                TextField(
                  controller: port,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.l10n.terminalSshPort,
                  ),
                ),
                TextField(
                  controller: key,
                  decoration: InputDecoration(
                    labelText: context.l10n.terminalSshIdentityFile,
                  ),
                ),
                TextField(
                  controller: cwd,
                  decoration: InputDecoration(
                    labelText: context.l10n.terminalSshRemoteCwd,
                  ),
                ),
                const SizedBox(height: 8),
                Text(context.l10n.terminalSshAuthenticationNote),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              if (host.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                SshTerminalTarget(
                  host: host.text.trim(),
                  user: user.text.trim(),
                  port: int.tryParse(port.text.trim()),
                  identityFile: key.text.trim(),
                  cwd: cwd.text.trim(),
                ),
              );
            },
            child: Text(context.l10n.memoryConnect),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      host.dispose();
      user.dispose();
      port.dispose();
      key.dispose();
      cwd.dispose();
    });
    if (target == null || !mounted) return;
    try {
      await context.read<TerminalStore>().newSshSession(target);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.terminalSshFailed('$e'))),
        );
      }
    }
  }

  void _selectSession(TerminalStore store, String id) {
    final previous = store.activeId;
    if (previous != null) _commandDrafts[previous] = _cmdController.value;
    store.select(id);
    _cmdController.value = _commandDrafts[id] ?? TextEditingValue.empty;
    if (_inputMode == TerminalInputMode.command) _ensureCmdFocus();
  }

  Future<bool> _confirmCloseSession(
    TerminalStore store,
    TerminalSession s,
  ) async {
    if (!s.isAlive) return true;
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.terminalCloseRunningQuestion),
            content: Text(context.l10n.terminalCloseRunningWarning(s.title)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.terminalClose),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _closeSession(TerminalStore store, TerminalSession s) async {
    if (!await _confirmCloseSession(store, s) || !mounted) return;
    _controllers.remove(s.id)?.dispose();
    _commandDrafts.remove(s.id);
    await store.closeSession(s.id);
    if (!mounted) return;
    if (store.sessions.isEmpty) {
      await _newSession();
    } else {
      final activeId = store.activeId;
      _cmdController.value = activeId == null
          ? TextEditingValue.empty
          : (_commandDrafts[activeId] ?? TextEditingValue.empty);
    }
  }

  Future<void> _showSessionManager(
    TerminalStore store, {
    bool createAfterClose = false,
    String? cwd,
  }) async {
    final closed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              title: Text(context.l10n.terminalSessions),
              subtitle: Text(
                context.l10n.terminalSessionLimit(store.maxSessions),
              ),
            ),
            for (final session in store.sessions)
              ListTile(
                leading: Icon(
                  session.exited ? Icons.stop_circle_outlined : Icons.circle,
                  color: session.exited
                      ? Theme.of(ctx).colorScheme.outline
                      : HermesSemantic.green,
                  size: 16,
                ),
                title: Text(session.title),
                subtitle: Text(
                  session.cwd,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  tooltip: context.l10n.terminalCloseNamed(session.title),
                  icon: const Icon(Icons.close),
                  onPressed: () async {
                    if (!await _confirmCloseSession(store, session) ||
                        !ctx.mounted) {
                      return;
                    }
                    _controllers.remove(session.id)?.dispose();
                    _commandDrafts.remove(session.id);
                    await store.closeSession(session.id);
                    if (!ctx.mounted) return;
                    final activeId = store.activeId;
                    _cmdController.value = activeId == null
                        ? TextEditingValue.empty
                        : (_commandDrafts[activeId] ?? TextEditingValue.empty);
                    Navigator.of(ctx).pop(true);
                  },
                ),
                onTap: () {
                  Navigator.of(ctx).pop(false);
                  _selectSession(store, session.id);
                },
              ),
          ],
        ),
      ),
    );
    if (closed == true && createAfterClose && mounted) {
      await _newSession(cwd: cwd);
    }
  }

  Future<void> _openInDirectory() async {
    final store = context.read<TerminalStore>();
    final start = store.activeSession?.cwd.isNotEmpty == true
        ? store.activeSession!.cwd
        : (store.preferredLaunchCwd ?? '/');
    final picked = await showTerminalCwdPicker(context, startPath: start);
    if (picked == null || !mounted) return;
    await _newSession(cwd: picked);
  }

  Future<void> _copySelection(TerminalStore store, String id) async {
    final controller = _controller(id);
    final text = store.selectedText(id, controller);
    if (text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.terminalSelectTextFirst)),
        );
      }
      return;
    }
    final copied = await copyTextOrNotify(
      context,
      text,
      successMessage: context.l10n.commonCopied,
    );
    if (copied) controller.clearSelection();
  }

  Future<void> _paste(TerminalStore store) async {
    final text = await readClipboardTextOrNotify(context);
    if (text?.isNotEmpty != true || !mounted) return;
    final lineCount = terminalPasteLineCount(text!);
    if (lineCount > 1) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.terminalPasteLinesQuestion(lineCount)),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: SelectableText(text, maxLines: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('single'),
              child: Text(context.l10n.terminalMergeSingleLine),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('paste'),
              child: Text(context.l10n.terminalConfirmPaste),
            ),
          ],
        ),
      );
      if (action == null) return;
      final value = action == 'single' ? terminalPasteAsSingleLine(text) : text;
      store.activeTerminal?.paste(value);
      return;
    }
    store.activeTerminal?.paste(text);
  }

  Future<void> _sendSelectionToChat(TerminalStore store, String id) async {
    final text = store.selectedText(id, _controller(id)).trim();
    if (text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.terminalSelectTerminalTextFirst)),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTerminalChatDraftKey, text);
    _controller(id).clearSelection();
    if (!mounted) return;
    if (widget.navigateOnSendToChat) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const ChatScreen()));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.terminalSentToChat)));
    }
  }

  Future<void> _activateLink(
    Terminal terminal,
    TapUpDetails details,
    CellOffset offset,
  ) async {
    final touch =
        details.kind == PointerDeviceKind.touch ||
        details.kind == PointerDeviceKind.stylus;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? keys.contains(LogicalKeyboardKey.metaLeft) ||
              keys.contains(LogicalKeyboardKey.metaRight)
        : keys.contains(LogicalKeyboardKey.controlLeft) ||
              keys.contains(LogicalKeyboardKey.controlRight);
    if (!touch && !modifier) return;
    if (offset.y < 0 || offset.y >= terminal.buffer.lines.length) return;
    final line = terminal.buffer.lines[offset.y].toString();
    final link = terminalWebLinkAt(line, offset.x);
    if (link == null) return;
    final opened = await launchUrl(
      Uri.parse(link),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.terminalOpenLinkFailed(link))),
      );
    }
  }

  void _submitCommand(TerminalStore store) {
    final text = _cmdController.text.trim();
    if (text.isEmpty) return;
    final activeId = store.activeId;
    if (activeId == null) return;
    store.recordCommand(text);
    _historyIndex[activeId] = store.commandHistory.length;
    store.activeTerminal?.textInput('$text\r');
    _cmdController.clear();
    _cmdFocusNode.requestFocus();
  }

  void _historyPrev(String activeId) {
    final hist = context.read<TerminalStore>().commandHistory;
    if (hist.isEmpty) return;
    var idx = _historyIndex[activeId] ?? hist.length;
    if (idx > 0) {
      idx -= 1;
      _historyIndex[activeId] = idx;
      _cmdController.text = hist[idx];
      _cmdController.selection = TextSelection.fromPosition(
        TextPosition(offset: _cmdController.text.length),
      );
    }
  }

  void _historyNext(String activeId) {
    final hist = context.read<TerminalStore>().commandHistory;
    if (hist.isEmpty) return;
    var idx = _historyIndex[activeId] ?? hist.length;
    if (idx < hist.length - 1) {
      idx += 1;
      _historyIndex[activeId] = idx;
      _cmdController.text = hist[idx];
    } else {
      _historyIndex[activeId] = hist.length;
      _cmdController.clear();
    }
    _cmdController.selection = TextSelection.fromPosition(
      TextPosition(offset: _cmdController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final phone = media.size.width < 600;
    final keyboardVisible = media.viewInsets.bottom > 0;
    final focused = phone && keyboardVisible;
    return Column(
      children: [
        Selector<TerminalStore, String?>(
          selector: (_, store) => store.reconnectNotice,
          builder: (context, notice, _) {
            if (notice == null) return const SizedBox.shrink();
            return Material(
              color: HermesSemantic.orange.withValues(alpha: 0.16),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.wifi_tethering_error, size: 18),
                title: Text(notice, style: theme.textTheme.bodySmall),
                trailing: IconButton(
                  tooltip: context.l10n.terminalDismissNotice,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      context.read<TerminalStore>().clearReconnectNotice(),
                ),
              ),
            );
          },
        ),
        if (!focused) ...[
          Selector<TerminalStore, (List<TerminalSession>, String?)>(
            selector: (_, store) => (store.sessions, store.activeId),
            builder: (context, selected, _) {
              final store = context.read<TerminalStore>();
              return _buildTabBar(store);
            },
          ),
          Selector<TerminalStore, (String?, String, bool)>(
            selector: (_, store) {
              final s = store.activeSession;
              return (s?.id, s?.cwd ?? '', s?.exited ?? false);
            },
            builder: (context, selected, _) {
              final store = context.read<TerminalStore>();
              final session = store.activeSession;
              if (session == null) return const SizedBox.shrink();
              return _buildCwdBar(store, session);
            },
          ),
        ],
        Expanded(
          child: Selector<TerminalStore, Object>(
            selector: (_, store) => (
              store.activeId,
              store.activeTerminal,
              store.fontFamily,
              store.terminalFontSize,
              store.terminalLineHeight,
              store.terminalColorPreset,
              store.terminalCursorPreset,
              store.terminalContentPadding,
            ),
            builder: (context, selected, _) {
              final store = context.read<TerminalStore>();
              return _buildBody(store);
            },
          ),
        ),
        Selector<TerminalStore, (String?, bool)>(
          selector: (_, store) => (
            store.activeId,
            store.activeId == null ? false : store.isRunning(store.activeId!),
          ),
          builder: (context, selected, _) {
            final activeId = selected.$1;
            if (activeId == null) return const SizedBox.shrink();
            return _buildShortcutChips(context.read<TerminalStore>(), activeId);
          },
        ),
        Selector<TerminalStore, String?>(
          selector: (_, store) => store.activeId,
          builder: (context, activeId, _) {
            if (activeId == null) return const SizedBox.shrink();
            return _inputMode == TerminalInputMode.command
                ? _buildCommandBar(
                    context.read<TerminalStore>(),
                    activeId,
                    phone: phone,
                  )
                : _buildInteractiveStatusBar(
                    context.read<TerminalStore>(),
                    activeId,
                  );
          },
        ),
      ],
    );
  }

  Widget _buildTabBar(TerminalStore store) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final height = widget.compact ? 40.0 : 48.0;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: HermesTerminalVisuals.surface(brightness),
        border: Border(
          bottom: BorderSide(color: HermesTerminalVisuals.border(brightness)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: store.sessions.length,
              itemBuilder: (context, index) {
                final s = store.sessions[index];
                final isActive = s.id == store.activeId;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _selectSession(store, s.id);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isActive
                              ? HermesTerminalVisuals.elevated(brightness)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isActive
                              ? Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: .5,
                                  ),
                                )
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: store.isRecovering(s.id)
                                    ? HermesSemantic.orange
                                    : store.recoveryFailed(s.id) || s.exited
                                    ? theme.colorScheme.error
                                    : HermesSemantic.green,
                                boxShadow: isActive && !s.exited
                                    ? [
                                        BoxShadow(
                                          color: HermesSemantic.green
                                              .withValues(alpha: .35),
                                          blurRadius: 5,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              s.title,
                              style: TextStyle(
                                fontSize: widget.compact ? 11 : 12,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                letterSpacing: .1,
                              ),
                            ),
                            if (!widget.compact) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: context.l10n.terminalCloseNamed(
                                  s.title,
                                ),
                                onPressed: () => _closeSession(store, s),
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                ),
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.close,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            tooltip: context.l10n.terminalNew,
            icon: Icon(Icons.add, size: widget.compact ? 16 : 18),
            onPressed: () => _newSession(),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            tooltip: context.l10n.terminalNewSsh,
            icon: Icon(Icons.lan_outlined, size: widget.compact ? 16 : 18),
            onPressed: _newSshSession,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            tooltip: context.l10n.terminalOpenDirectory,
            icon: Icon(Icons.folder_open, size: widget.compact ? 16 : 18),
            onPressed: _openInDirectory,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
          IconButton(
            tooltip: context.l10n.terminalDisplaySettings,
            icon: Icon(Icons.text_format, size: widget.compact ? 17 : 19),
            onPressed: () => _showDisplaySettings(store),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ],
      ),
    );
  }

  Widget _buildCwdBar(TerminalStore store, TerminalSession session) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Material(
      color: HermesTerminalVisuals.surface(brightness),
      child: InkWell(
        onTap: () => store.refreshCwd(session.id),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : HermesSpacing.md,
            vertical: widget.compact ? 4 : 5,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  Icons.folder_outlined,
                  size: 13,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Tooltip(
                  message: session.cwd,
                  child: Text(
                    session.cwd.isEmpty
                        ? context.l10n.terminalNoWorkingDirectory
                        : _mobileCwdLabel(session.cwd),
                    style: HermesType.onSurfaceVariant(
                      HermesType.code.copyWith(
                        fontSize: widget.compact ? 11 : 12,
                      ),
                      theme,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (session.exited)
                TextButton(
                  onPressed: () => store.restartSession(session.id),
                  child: Text(context.l10n.commonRestart),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(TerminalStore store) {
    final activeId = store.activeId;
    final terminal = store.activeTerminal;
    if (activeId == null || terminal == null) {
      return Center(
        child: Text(
          context.l10n.terminalNoActive,
          style: const TextStyle(fontSize: 12),
        ),
      );
    }
    final dropEnabled =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);
    final appTheme = Theme.of(context);
    final brightness = appTheme.brightness;
    final terminalTheme = HermesTerminalVisuals.terminalTheme(
      brightness,
      appTheme.colorScheme.primary,
      preset: store.terminalColorPreset,
    );
    final effectiveBrightness = HermesTerminalVisuals.effectiveBrightness(
      brightness,
      store.terminalColorPreset,
    );
    final contentPadding = store.terminalContentPadding;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final fontSize = widget.compact
        ? (store.terminalFontSize - 1.5).clamp(12, 20).toDouble()
        : store.terminalFontSize;
    final view = TerminalView(
      terminal,
      key: ValueKey(
        '$activeId-${_inputMode.name}-$fontSize-'
        '${store.terminalLineHeight}-${store.fontFamily}',
      ),
      controller: _controller(activeId),
      autofocus: _inputMode == TerminalInputMode.interactive,
      readOnly: _inputMode == TerminalInputMode.command,
      keyboardType: TextInputType.visiblePassword,
      backgroundOpacity: 1,
      theme: terminalTheme,
      keyboardAppearance: effectiveBrightness,
      cursorType: switch (store.terminalCursorPreset) {
        TerminalCursorPreset.block => TerminalCursorType.block,
        TerminalCursorPreset.underline => TerminalCursorType.underline,
        TerminalCursorPreset.bar => TerminalCursorType.verticalBar,
      },
      alwaysShowCursor: _inputMode == TerminalInputMode.interactive,
      padding: EdgeInsets.fromLTRB(
        contentPadding
            ? (widget.compact
                  ? 8
                  : phone
                  ? 12
                  : 14)
            : 0,
        contentPadding ? (widget.compact ? 8 : 10) : 0,
        contentPadding
            ? (widget.compact
                  ? 6
                  : phone
                  ? 12
                  : 12)
            : 0,
        contentPadding ? (widget.compact ? 8 : 10) : 0,
      ),
      textStyle: TerminalStyle(
        fontSize: fontSize,
        height: store.terminalLineHeight,
        fontFamily: store.fontFamily,
        fontFamilyFallback: store.fontFamilyFallback,
      ),
      onTapUp: (details, offset) {
        if (_inputMode == TerminalInputMode.command) {
          _cmdFocusNode.requestFocus();
        }
        _activateLink(terminal, details, offset);
      },
      onSecondaryTapDown: (details, offset) async {
        final selected = store.selectedText(activeId, _controller(activeId));
        if (selected.isNotEmpty) {
          await _copySelection(store, activeId);
        } else {
          await _paste(store);
        }
        if (_inputMode == TerminalInputMode.command) {
          _cmdFocusNode.requestFocus();
        }
      },
    );
    return ColoredBox(
      color: HermesTerminalVisuals.background(
        brightness,
        store.terminalColorPreset,
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 0 : 10),
        child: DropTarget(
          enable: dropEnabled,
          onDragEntered: (_) => setState(() => _draggingPaths = true),
          onDragExited: (_) => setState(() => _draggingPaths = false),
          onDragDone: (details) {
            setState(() => _draggingPaths = false);
            store.sendPaths(activeId, details.files.map((file) => file.path));
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: terminalTheme.background,
              border: Border.all(
                color: _draggingPaths
                    ? Theme.of(context).colorScheme.primary
                    : HermesTerminalVisuals.border(brightness),
                width: _draggingPaths ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(widget.compact ? 0 : 12),
              boxShadow: widget.compact
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: brightness == Brightness.dark ? .24 : .08,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: view,
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutChips(TerminalStore store, String activeId) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final chips = <(String, VoidCallback)>[
      (context.l10n.profilesCopy, () => _copyVisibleOutput(store, activeId)),
      ('Esc', () => store.sendRaw(activeId, '\x1b')),
      ('Tab', () => store.sendRaw(activeId, '\t')),
      ('↑', () => store.sendRaw(activeId, '\x1b[A')),
      ('↓', () => store.sendRaw(activeId, '\x1b[B')),
      ('←', () => store.sendRaw(activeId, '\x1b[D')),
      ('→', () => store.sendRaw(activeId, '\x1b[C')),
    ];
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: HermesTerminalVisuals.surface(brightness),
        border: Border(
          top: BorderSide(color: HermesTerminalVisuals.border(brightness)),
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: SegmentedButton<TerminalInputMode>(
              segments: [
                ButtonSegment(
                  value: TerminalInputMode.command,
                  icon: const Icon(Icons.terminal, size: 16),
                  tooltip: context.l10n.terminalCommandMode,
                ),
                ButtonSegment(
                  value: TerminalInputMode.interactive,
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 16),
                  tooltip: context.l10n.terminalInteractiveMode,
                ),
              ],
              selected: {_inputMode},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                setState(() => _inputMode = value.first);
                if (value.first == TerminalInputMode.command) _ensureCmdFocus();
              },
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ),
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
                _terminalShortcutButton(
                  label: 'Ctrl',
                  onPressed: () => _showControlKeys(store, activeId),
                ),
                for (final chip in chips)
                  _terminalShortcutButton(
                    label: chip.$1,
                    onPressed: store.isRunning(activeId) ? chip.$2 : null,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _terminalShortcutButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: ActionChip(
          backgroundColor: HermesTerminalVisuals.elevated(
            Theme.of(context).brightness,
          ),
          side: BorderSide(
            color: HermesTerminalVisuals.border(Theme.of(context).brightness),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
          label: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontFamily: context.read<TerminalStore>().fontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  Future<void> _showControlKeys(TerminalStore store, String activeId) async {
    final keys = <(String, String)>[
      (context.l10n.terminalControlInterrupt, '\x03'),
      ('Ctrl+D EOF', '\x04'),
      (context.l10n.terminalControlSuspend, '\x1a'),
      (context.l10n.terminalControlClear, '\x0c'),
      (context.l10n.terminalControlBackWord, '\x1bb'),
      (context.l10n.terminalControlForwardWord, '\x1bf'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(title: Text(context.l10n.terminalControlKeys)),
            for (final key in keys)
              ListTile(
                title: Text(key.$1),
                onTap: () {
                  store.sendRaw(activeId, key.$2);
                  Navigator.of(ctx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  String _mobileCwdLabel(String path) {
    if (MediaQuery.sizeOf(context).width >= 600) return path;
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length <= 2) return path;
    return '…/${parts.sublist(parts.length - 2).join('/')}';
  }

  Future<void> _copyVisibleOutput(TerminalStore store, String activeId) async {
    final terminal = store.terminal(activeId);
    if (terminal == null || terminal.buffer.lines.length == 0) return;
    final end = terminal.buffer.lines.length;
    final visibleRows = terminal.viewHeight > 0 ? terminal.viewHeight : 24;
    final start = end > visibleRows ? end - visibleRows : 0;
    final output = Iterable<int>.generate(end - start, (index) => start + index)
        .map((index) => terminal.buffer.lines[index].toString().trimRight())
        .join('\n')
        .trimRight();
    if (output.isEmpty) return;
    await copyTextOrNotify(
      context,
      output,
      successMessage: context.l10n.terminalVisibleOutputCopied,
    );
  }

  Future<void> _showDisplaySettings(TerminalStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> update({
              double? fontSize,
              double? lineHeight,
              TerminalColorPreset? colorPreset,
              TerminalCursorPreset? cursorPreset,
              bool? contentPadding,
            }) async {
              await store.setDisplayPreferences(
                fontSize: fontSize,
                lineHeight: lineHeight,
                colorPreset: colorPreset,
                cursorPreset: cursorPreset,
                contentPadding: contentPadding,
              );
              if (context.mounted) setSheetState(() {});
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.terminalDisplay,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.terminalDisplayDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: HermesTerminalVisuals.darkBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      r'~/project  git:main  ❯ flutter test'
                      '\n'
                      '\n${context.l10n.terminalPreviewOutput}',
                      style: TextStyle(
                        color: HermesTerminalVisuals.darkForeground,
                        fontFamily: store.fontFamily,
                        fontFamilyFallback: store.fontFamilyFallback,
                        fontSize: store.terminalFontSize,
                        height: store.terminalLineHeight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.terminalFontSize(
                      store.terminalFontSize.toStringAsFixed(0),
                    ),
                  ),
                  Slider(
                    min: 12,
                    max: 22,
                    divisions: 10,
                    value: store.terminalFontSize,
                    label: store.terminalFontSize.toStringAsFixed(0),
                    onChanged: (value) => update(fontSize: value),
                  ),
                  Text(
                    context.l10n.terminalLineHeight(
                      store.terminalLineHeight.toStringAsFixed(2),
                    ),
                  ),
                  Slider(
                    min: 1.2,
                    max: 1.7,
                    divisions: 10,
                    value: store.terminalLineHeight,
                    label: store.terminalLineHeight.toStringAsFixed(2),
                    onChanged: (value) => update(lineHeight: value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<TerminalColorPreset>(
                    initialValue: store.terminalColorPreset,
                    decoration: InputDecoration(
                      labelText: context.l10n.terminalColorTheme,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: TerminalColorPreset.system,
                        child: Text(context.l10n.terminalThemeSystem),
                      ),
                      DropdownMenuItem(
                        value: TerminalColorPreset.professionalDark,
                        child: Text(context.l10n.terminalThemeProfessionalDark),
                      ),
                      DropdownMenuItem(
                        value: TerminalColorPreset.highContrastDark,
                        child: Text(context.l10n.terminalThemeHighContrastDark),
                      ),
                      DropdownMenuItem(
                        value: TerminalColorPreset.softLight,
                        child: Text(context.l10n.terminalThemeSoftLight),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) update(colorPreset: value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TerminalCursorPreset>(
                    initialValue: store.terminalCursorPreset,
                    decoration: InputDecoration(
                      labelText: context.l10n.terminalCursorStyle,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: TerminalCursorPreset.bar,
                        child: Text(context.l10n.terminalCursorBar),
                      ),
                      DropdownMenuItem(
                        value: TerminalCursorPreset.block,
                        child: Text(context.l10n.terminalCursorBlock),
                      ),
                      DropdownMenuItem(
                        value: TerminalCursorPreset.underline,
                        child: Text(context.l10n.terminalCursorUnderline),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) update(cursorPreset: value);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.terminalContentPadding),
                    subtitle: Text(context.l10n.terminalContentPaddingHint),
                    value: store.terminalContentPadding,
                    onChanged: (value) => update(contentPadding: value),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await store.resetDisplayPreferences();
                      if (context.mounted) setSheetState(() {});
                    },
                    icon: const Icon(Icons.restart_alt),
                    label: Text(context.l10n.terminalResetDisplay),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCommandBar(
    TerminalStore store,
    String activeId, {
    required bool phone,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return SafeArea(
      top: false,
      child: Material(
        color: HermesTerminalVisuals.surface(brightness),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            widget.compact ? 8 : 12,
            widget.compact ? 6 : 8,
            widget.compact ? 8 : 12,
            widget.compact ? 4 : 6,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: widget.compact ? 32 : 40,
                child: KeyboardListener(
                  focusNode: _historyKeyFocusNode,
                  onKeyEvent: (event) {
                    if (event is! KeyDownEvent) return;
                    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                      _historyPrev(activeId);
                    } else if (event.logicalKey ==
                        LogicalKeyboardKey.arrowDown) {
                      _historyNext(activeId);
                    }
                  },
                  child: TextField(
                    controller: _cmdController,
                    focusNode: _cmdFocusNode,
                    autofocus: widget.autofocusCommand,
                    style: TextStyle(
                      fontSize: widget.compact
                          ? (store.terminalFontSize - 1.5)
                                .clamp(12, 20)
                                .toDouble()
                          : store.terminalFontSize,
                      height: store.terminalLineHeight,
                      fontFamily: store.fontFamily,
                      fontFamilyFallback: store.fontFamilyFallback,
                      color: brightness == Brightness.dark
                          ? HermesTerminalVisuals.darkForeground
                          : HermesTerminalVisuals.lightForeground,
                    ),
                    decoration: InputDecoration(
                      hintText: context.l10n.terminalCommandHint,
                      prefixIcon: Padding(
                        padding: const EdgeInsets.only(left: 12, right: 8),
                        child: Text(
                          r'❯',
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontFamily: store.fontFamily,
                            fontSize: widget.compact ? 14 : 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints(),
                      filled: true,
                      fillColor: HermesTerminalVisuals.elevated(brightness),
                      hintStyle: TextStyle(
                        fontSize: widget.compact ? 12 : 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          widget.compact ? 8 : 10,
                        ),
                        borderSide: BorderSide(
                          color: HermesTerminalVisuals.border(brightness),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          widget.compact ? 8 : 10,
                        ),
                        borderSide: BorderSide(
                          color: theme.colorScheme.primary,
                          width: 1.4,
                        ),
                      ),
                      suffixIcon: IconButton(
                        tooltip: context.l10n.terminalRunCommand,
                        icon: Icon(
                          Icons.arrow_upward_rounded,
                          color: theme.colorScheme.onPrimary,
                          size: widget.compact ? 16 : 22,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          minimumSize: const Size(30, 30),
                        ),
                        onPressed: () => _submitCommand(store),
                      ),
                    ),
                    onSubmitted: (_) => _submitCommand(store),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              if (phone)
                Row(
                  children: [
                    _actionBtn(
                      icon: Icons.content_paste,
                      label: context.l10n.terminalPaste,
                      onPressed: () => _paste(store),
                    ),
                    const Spacer(),
                    _actionBtn(
                      icon: Icons.more_horiz,
                      label: context.l10n.commonMore,
                      onPressed: () => _showTerminalActions(store, activeId),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    _actionBtn(
                      icon: Icons.stop_circle_outlined,
                      label: 'Ctrl+C',
                      onPressed: () => store.sendControlC(activeId),
                    ),
                    _actionBtn(
                      icon: Icons.content_paste,
                      label: context.l10n.terminalPaste,
                      onPressed: () => _paste(store),
                    ),
                    _actionBtn(
                      icon: Icons.content_copy,
                      label: context.l10n.profilesCopy,
                      onPressed: () => _copySelection(store, activeId),
                    ),
                    _actionBtn(
                      icon: Icons.cleaning_services_outlined,
                      label: context.l10n.terminalClear,
                      onPressed: () => store.clear(activeId),
                    ),
                    const Spacer(),
                    _actionBtn(
                      icon: Icons.send_outlined,
                      label: context.l10n.terminalSendToChat,
                      onPressed: () => _sendSelectionToChat(store, activeId),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveStatusBar(TerminalStore store, String activeId) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: SizedBox(
          height: 48,
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(
                Icons.keyboard_alt_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(context.l10n.terminalInteractiveHint)),
              IconButton(
                tooltip: context.l10n.terminalPaste,
                onPressed: () => _paste(store),
                icon: const Icon(Icons.content_paste),
              ),
              IconButton(
                tooltip: context.l10n.terminalMoreActions,
                onPressed: () => _showTerminalActions(store, activeId),
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTerminalActions(
    TerminalStore store,
    String activeId,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: Text(context.l10n.terminalCopySelection),
              onTap: () {
                Navigator.of(ctx).pop();
                _copySelection(store, activeId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services_outlined),
              title: Text(context.l10n.terminalClear),
              onTap: () {
                store.clear(activeId);
                Navigator.of(ctx).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_outlined),
              title: Text(context.l10n.terminalSendSelectionToChat),
              onTap: () {
                Navigator.of(ctx).pop();
                _sendSelectionToChat(store, activeId);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(context.l10n.terminalOpenOtherDirectory),
              onTap: () {
                Navigator.of(ctx).pop();
                _openInDirectory();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tab),
              title: Text(context.l10n.terminalManageSessions),
              onTap: () {
                Navigator.of(ctx).pop();
                _showSessionManager(store);
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(context.l10n.terminalPrivacyHistory),
              onTap: () {
                Navigator.of(ctx).pop();
                _showPrivacySheet(store);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrivacySheet(TerminalStore store) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) => Wrap(
            children: [
              ListTile(
                title: Text(context.l10n.terminalPrivacyHistory),
                subtitle: Text(context.l10n.terminalPrivacyDescription),
              ),
              SwitchListTile(
                title: Text(context.l10n.terminalSaveCommandHistory),
                value: store.persistHistory,
                onChanged: (value) async {
                  await store.setPersistHistory(value);
                  setSheetState(() {});
                },
              ),
              SwitchListTile(
                title: Text(context.l10n.terminalSaveOutputSnapshots),
                value: store.persistSnapshots,
                onChanged: (value) async {
                  await store.setPersistSnapshots(value);
                  setSheetState(() {});
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.terminalClearSavedData),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: Text(context.l10n.terminalClearDataQuestion),
                      content: Text(context.l10n.terminalClearDataWarning),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                          child: Text(context.l10n.commonCancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                          child: Text(context.l10n.terminalClear),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                  await store.clearPrivateData();
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 6 : 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: widget.compact ? 13 : 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: widget.compact ? 10 : 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
