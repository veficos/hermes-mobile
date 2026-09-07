/// Desktop parity: `app/settings/keybind-settings.tsx` — a settings page for
/// rebinding hardware-keyboard shortcuts. Scoped to the handful of shortcuts
/// mobile actually has (see `core/stores/keybind_store.dart`); desktop-only,
/// since touch platforms have no physical keyboard to bind.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/stores/keybind_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';

class KeybindSettingsScreen extends StatelessWidget {
  final bool embedded;

  const KeybindSettingsScreen({super.key, this.embedded = false});

  String _actionLabel(BuildContext context, String actionId) {
    final l10n = context.l10n;
    return switch (actionId) {
      'chat.undo' => l10n.keybindActionChatUndo,
      'chat.find' => l10n.keybindActionChatFind,
      _ => actionId,
    };
  }

  IconData _actionIcon(String actionId) {
    return switch (actionId) {
      'chat.undo' => Icons.undo_outlined,
      'chat.find' => Icons.search_outlined,
      _ => Icons.keyboard_outlined,
    };
  }

  Future<void> _capture(BuildContext context, KeybindStore store, String actionId) async {
    final activator = await showDialog<SingleActivator>(
      context: context,
      builder: (_) => _CaptureDialog(store: store, actionId: actionId),
    );
    if (activator != null) {
      await store.setBinding(actionId, activator);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<KeybindStore>();
    final l10n = context.l10n;
    final content = ListView(
      padding: const EdgeInsets.all(HermesSpacing.md),
      children: [
        Text(
          l10n.settingsKeybindsDesc,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: HermesPalette.of(context).text2,
          ),
        ),
        const SizedBox(height: HermesSpacing.sm),
        Text(
          l10n.keybindNoHardwareKeyboardHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: HermesPalette.of(context).text3,
          ),
        ),
        const SizedBox(height: HermesSpacing.md),
        HermesMobileGroup(
          children: [
            for (final action in KeybindStore.actions)
              HermesMobileRow(
                icon: _actionIcon(action.id),
                title: _actionLabel(context, action.id),
                subtitle: _describeActivators(store.bindingsFor(action.id)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (store.isCustomized(action.id))
                      IconButton(
                        tooltip: l10n.keybindReset,
                        icon: const Icon(Icons.restart_alt_outlined),
                        onPressed: () => store.resetBinding(action.id),
                      ),
                    TextButton(
                      onPressed: () => _capture(context, store, action.id),
                      child: Text(l10n.keybindChange),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: HermesSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: KeybindStore.actions.any((a) => store.isCustomized(a.id))
                ? () => store.resetAll()
                : null,
            icon: const Icon(Icons.settings_backup_restore_outlined),
            label: Text(l10n.keybindResetAll),
          ),
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.keybindsTitle)),
      body: content,
    );
  }
}

class _CaptureDialog extends StatefulWidget {
  final KeybindStore store;
  final String actionId;

  const _CaptureDialog({required this.store, required this.actionId});

  @override
  State<_CaptureDialog> createState() => _CaptureDialogState();
}

class _CaptureDialogState extends State<_CaptureDialog> {
  final FocusNode _focusNode = FocusNode();
  SingleActivator? _pending;
  String? _conflictAction;
  String? _warning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.handled;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    final modifierKeys = {
      LogicalKeyboardKey.control,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.meta,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.metaRight,
      LogicalKeyboardKey.alt,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.altRight,
      LogicalKeyboardKey.shift,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
    };
    if (modifierKeys.contains(key)) return KeyEventResult.handled;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final control = pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    final meta = pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    final alt = pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    final shift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);

    if (!control && !meta && !alt && !shift) {
      setState(() {
        _pending = null;
        _conflictAction = null;
        _warning = context.l10n.keybindCaptureModifierRequired;
      });
      return KeyEventResult.handled;
    }

    final activator = SingleActivator(
      key,
      control: control,
      meta: meta,
      alt: alt,
      shift: shift,
    );
    final conflict = widget.store.conflictFor(widget.actionId, activator);
    setState(() {
      _pending = activator;
      _conflictAction = conflict;
      _warning = null;
    });
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    return AlertDialog(
      title: Text(l10n.keybindChange),
      content: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: HermesSpacing.md,
                  horizontal: HermesSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: palette.elevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.border),
                ),
                alignment: Alignment.center,
                child: Text(
                  _pending != null
                      ? _describeActivators([_pending!])
                      : l10n.keybindCapturePrompt,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              if (_warning != null) ...[
                const SizedBox(height: HermesSpacing.sm),
                Text(
                  _warning!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HermesSemantic.red),
                ),
              ],
              if (_conflictAction != null) ...[
                const SizedBox(height: HermesSpacing.sm),
                Text(
                  l10n.keybindConflictWith(_actionLabelFor(_conflictAction!, l10n)),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: HermesSemantic.orange),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _pending == null
              ? null
              : () => Navigator.of(context).pop(_pending),
          child: Text(l10n.keybindChange),
        ),
      ],
    );
  }

  String _actionLabelFor(String actionId, AppLocalizations l10n) {
    return switch (actionId) {
      'chat.undo' => l10n.keybindActionChatUndo,
      'chat.find' => l10n.keybindActionChatFind,
      _ => actionId,
    };
  }
}

String _describeActivators(List<SingleActivator> activators) {
  if (activators.isEmpty) return '';
  return activators.map(_describeActivator).join(' / ');
}

String _describeActivator(SingleActivator activator) {
  final isMac = defaultTargetPlatform == TargetPlatform.macOS;
  final parts = <String>[];
  if (activator.control) parts.add(isMac ? '⌃' : 'Ctrl');
  if (activator.alt) parts.add(isMac ? '⌥' : 'Alt');
  if (activator.shift) parts.add(isMac ? '⇧' : 'Shift');
  if (activator.meta) parts.add(isMac ? '⌘' : 'Meta');
  final label = activator.trigger.keyLabel;
  parts.add(label.length == 1 ? label.toUpperCase() : label);
  return isMac ? parts.join('') : parts.join('+');
}
