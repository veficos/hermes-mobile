library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/bot_store.dart';
import '../l10n/l10n.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

class BotCreateScreen extends StatefulWidget {
  const BotCreateScreen({super.key});

  @override
  State<BotCreateScreen> createState() => _BotCreateScreenState();
}

class _BotCreateScreenState extends State<BotCreateScreen> {
  final _nameCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _soulCtrl = TextEditingController();
  String _cloneFrom = 'default';
  bool _customSoul = false;
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _soulCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim().toLowerCase();
    if (!BotStore.botNameRe.hasMatch(name)) {
      showHermesToast(
        context,
        message: context.l10n.botProfileNameInvalid,
        kind: HermesToastKind.error,
      );
      return;
    }
    final store = context.read<BotStore>();
    final targetConnectionId = store.connection.activeConnectionId;
    final nameTaken = store.bots.any(
      (item) =>
          item.route.connectionId == targetConnectionId &&
          item.profile.toLowerCase() == name,
    );
    if (nameTaken) {
      showHermesToast(
        context,
        message: context.l10n.botCreateNameTaken(name),
        kind: HermesToastKind.error,
      );
      return;
    }
    setState(() => _creating = true);
    try {
      await store.createBot(
        name: name,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        cloneFrom: _cloneFrom,
        customSoul: _customSoul && _soulCtrl.text.trim().isNotEmpty
            ? _soulCtrl.text.trim()
            : null,
      );
      if (!mounted) return;
      showHermesToast(context, message: context.l10n.botCreateSuccess);
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.errorOperationFailedWithDetail('$error'),
        kind: HermesToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bots = context.watch<BotStore>();
    final cloneOptions = bots.bots.map((b) => b.profile).toSet().toList()
      ..sort();
    if (!cloneOptions.contains('default')) cloneOptions.insert(0, 'default');
    if (!cloneOptions.contains(_cloneFrom) && cloneOptions.isNotEmpty) {
      _cloneFrom = cloneOptions.first;
    }
    return MobilePageScaffold(
      title: context.l10n.botCreateTitle,
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _nameCtrl,
            enabled: !_creating,
            decoration: InputDecoration(
              labelText: context.l10n.commonName,
              helperText: context.l10n.botCreateNameHelper,
              prefixIcon: const Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            enabled: !_creating,
            decoration: InputDecoration(
              labelText: context.l10n.botCreateRoleLabel,
              prefixIcon: const Icon(Icons.work_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionCtrl,
            enabled: !_creating,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: context.l10n.botCreateMissionLabel,
              prefixIcon: const Icon(Icons.flag_outlined),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: cloneOptions.contains(_cloneFrom)
                ? _cloneFrom
                : null,
            items: cloneOptions
                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                .toList(),
            onChanged: _creating
                ? null
                : (value) {
                    if (value != null) setState(() => _cloneFrom = value);
                  },
            decoration: InputDecoration(
              labelText: context.l10n.botCreateCloneFromLabel,
              prefixIcon: const Icon(Icons.copy_all_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _customSoul,
            onChanged: _creating
                ? null
                : (value) => setState(() => _customSoul = value),
            title: Text(context.l10n.botCreateCustomSoulLabel),
          ),
          if (_customSoul) ...[
            const SizedBox(height: 4),
            TextField(
              controller: _soulCtrl,
              enabled: !_creating,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: context.l10n.botCreateCustomSoulHint,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
  }
}
