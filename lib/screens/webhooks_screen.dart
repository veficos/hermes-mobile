/// Webhooks (spec §集成): list + create + per-webhook detail (enable/disable /
/// delete). Backed by `/api/v1/webhooks/*`, which has no update/test/delivery-
/// log endpoints (desktop's own REST client has the same gap — see
/// `webhooks-rest.test.ts` — so editing a webhook is delete-and-recreate on
/// every client, not a mobile-specific omission).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/connection_reload_mixin.dart';
import '../core/stores/connection_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';
import '../widgets/h/hermes_status.dart';
import '../widgets/h/hermes_toast.dart';

class WebhooksScreen extends StatefulWidget {
  final bool embedded;

  const WebhooksScreen({super.key, this.embedded = false});

  @override
  State<WebhooksScreen> createState() => _WebhooksScreenState();
}

class _WebhooksScreenState extends State<WebhooksScreen>
    with ConnectionReloadMixin<WebhooksScreen> {
  List<Webhook>? _webhooks;
  bool _platformEnabled = false;
  String _baseUrl = '';
  String? _error;
  bool _busy = false;
  int _loadGeneration = 0;
  int _mutationGeneration = 0;
  ApiClient? _loadedApi;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForTarget);
  }

  void _reloadForTarget() {
    if (!mounted) return;
    _mutationGeneration++;
    setState(() {
      _busy = false;
      _webhooks = null;
      _loadedApi = null;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<ConnectionStore>().api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) setState(() => _error = connectionOfflineErrorCode);
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await api.webhooks();
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() {
        _loadedApi = api;
        _webhooks = result.items;
        _platformEnabled = result.enabled;
        _baseUrl = result.baseUrl;
        _error = null;
      });
    } catch (e) {
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, context.read<ConnectionStore>().api)) {
        return;
      }
      setState(() => _error = '$e');
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _create() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    if (!_platformEnabled) {
      showHermesToast(context, message: context.l10n.webhookEnableFirst);
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(HermesRadius.sheet),
        ),
      ),
      builder: (_) => _WebhookEditorSheet(api: api),
    );
    if (saved == true && mounted && identical(api, connection.api)) {
      _load();
    }
  }

  Future<void> _enablePlatform() async {
    final connection = context.read<ConnectionStore>();
    final api = connectedApiOrNotify(context, connection);
    if (api == null) return;
    final generation = ++_mutationGeneration;
    setState(() => _busy = true);
    try {
      final result = await api.enableWebhooks();
      if (!mounted ||
          generation != _mutationGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      showHermesToast(
        context,
        message: result['needs_restart'] == true
            ? context.l10n.webhookEnabledRestart
            : context.l10n.webhookEnabled,
        kind: HermesToastKind.success,
      );
      await _load();
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          identical(api, connection.api)) {
        showHermesToast(
          context,
          message: context.l10n.webhookEnableFailed('$e'),
        );
      }
    } finally {
      if (mounted && generation == _mutationGeneration) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: Text(context.l10n.featureWebhooks),
              actions: [
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'new-webhook',
        onPressed: _create,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_webhooks == null && _error == null) {
      return HermesLoadingState(label: context.l10n.webhookLoading);
    }
    if (_error != null && _webhooks == null) {
      return HermesErrorState(
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error,
        onRetry: _load,
      );
    }
    if (_webhooks == null || _webhooks!.isEmpty) {
      return Column(
        children: [
          if (!_platformEnabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.md,
                HermesSpacing.md,
                HermesSpacing.md,
                0,
              ),
              child: HermesNoticeBar(
                message: context.l10n.webhookPlatformDisabled,
                color: HermesSemantic.orange,
                icon: Icons.power_settings_new,
                onTap: _busy ? null : _enablePlatform,
              ),
            ),
          Expanded(
            child: HermesEmptyState(
              icon: Icons.webhook_outlined,
              title: context.l10n.webhookEmptyTitle,
              description: context.l10n.webhookEmptyDescription,
            ),
          ),
        ],
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.only(
              left: HermesSpacing.md,
              right: HermesSpacing.md,
              bottom: 88,
            ),
            children: [
              if (_error != null) ...[
                HermesNoticeBar(
                  message: _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error!,
                  color: HermesSemantic.red,
                  icon: Icons.error_outline,
                  onTap: _load,
                ),
                const SizedBox(height: HermesSpacing.sm),
              ],
              if (!_platformEnabled)
                HermesNoticeBar(
                  message: context.l10n.webhookPlatformDisabled,
                  color: HermesSemantic.orange,
                  icon: Icons.power_settings_new,
                  onTap: _busy ? null : _enablePlatform,
                ),
              if (_baseUrl.isNotEmpty) ...[
                const SizedBox(height: HermesSpacing.sm),
                SelectableText(
                  context.l10n.webhookBaseUrl(_baseUrl),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              HermesSectionHeader(title: context.l10n.webhookConfigured),
              for (final w in _webhooks!) _webhookRow(context, w),
            ],
          ),
        ),
      ),
    );
  }

  Widget _webhookRow(BuildContext context, Webhook w) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: HermesGlassCard(
        radius: HermesRadius.card,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                WebhookDetailScreen(webhook: w, ownerApi: _loadedApi),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.webhook_outlined,
            color: w.enabled ? theme.colorScheme.primary : HermesSemantic.gray,
          ),
          title: Text(
            w.name,
            style: HermesType.onSurface(HermesType.headline, theme),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
              if (w.events.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final e in w.events.take(4))
                        HermesStatusChip(color: HermesSemantic.blue, label: e),
                      if (w.events.length > 4)
                        HermesStatusChip(
                          color: HermesSemantic.gray,
                          label: '+${w.events.length - 4}',
                        ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, size: 20),
        ),
      ),
    );
  }
}

/// Webhook detail: edit / delete / test / deliveries.
class WebhookDetailScreen extends StatefulWidget {
  final Webhook webhook;
  final ApiClient? ownerApi;
  const WebhookDetailScreen({super.key, required this.webhook, this.ownerApi});

  @override
  State<WebhookDetailScreen> createState() => _WebhookDetailScreenState();
}

class _WebhookDetailScreenState extends State<WebhookDetailScreen> {
  bool _busy = false;
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.webhook.enabled;
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi ?? connectedApiOrNotify(context, connection);
    if (api == null) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await api.setWebhookEnabled(widget.webhook.id, enabled);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      setState(() => _enabled = enabled);
      showHermesToast(
        context,
        message: enabled
            ? context.l10n.webhookEnabled
            : context.l10n.webhookStopped,
        kind: HermesToastKind.success,
      );
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(
          context,
          message: context.l10n.webhookOperationFailed('$e'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (_busy) return;
    final connection = context.read<ConnectionStore>();
    final api = widget.ownerApi ?? connectedApiOrNotify(context, connection);
    if (api == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.webhookDeleteTitle),
        content: Text(ctx.l10n.webhookDeletePrompt(widget.webhook.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      requireActiveApi(context, connection, api);
      await api.webhookDelete(widget.webhook.id);
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      showHermesToast(
        context,
        message: context.l10n.webhookDeleted,
        kind: HermesToastKind.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        setState(() => _busy = false);
        showHermesToast(
          context,
          message: context.l10n.webhookDeleteFailed('$e'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = widget.webhook;
    return Scaffold(
      appBar: AppBar(
        title: Text(w.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(HermesSpacing.md),
        children: [
          // ── Overview card ───────────────────────────────────────
          HermesGlassCard(
            radius: HermesRadius.largeCard,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        w.name,
                        style: HermesType.onSurface(HermesType.title, theme),
                      ),
                    ),
                    HermesStatusChip(
                      color: _enabled
                          ? HermesSemantic.green
                          : HermesSemantic.gray,
                      label: _enabled
                          ? context.l10n.webhookEnabledLabel
                          : context.l10n.webhookDisabledLabel,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.webhookUrl,
                  style: theme.textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                SelectableText(
                  w.url,
                  style: HermesType.onSurface(HermesType.code, theme),
                ),
                if (w.secret != null && w.secret!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.l10n.webhookSecret,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    w.secret!,
                    style: HermesType.onSurface(HermesType.code, theme),
                  ),
                ],
                if (w.events.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.webhookEvents,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in w.events)
                        HermesStatusChip(color: HermesSemantic.blue, label: e),
                    ],
                  ),
                ],
                if (w.description != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.webhookDescription,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(w.description!),
                ],
                if (w.deliver != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.webhookDeliverTo,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(w.deliver!),
                ],
                if (w.skills.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.webhookSkills,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final s in w.skills)
                        HermesStatusChip(
                          color: HermesSemantic.purple,
                          label: s,
                        ),
                    ],
                  ),
                ],
                if (w.prompt != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.webhookPrompt,
                    style: theme.textTheme.labelSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    w.prompt!,
                    style: HermesType.onSurface(HermesType.code, theme),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: HermesSpacing.md),
          SwitchListTile(
            value: _enabled,
            onChanged: _busy ? null : _toggleEnabled,
            title: Text(context.l10n.webhookEnableThis),
            subtitle: Text(context.l10n.webhookHotReloadDescription),
          ),
          const SizedBox(height: HermesSpacing.md),
          // ── Actions ─────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  foregroundColor: HermesSemantic.red,
                ),
                onPressed: _busy ? null : _delete,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline),
                label: Text(context.l10n.commonDelete),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Webhook create dialog (modal sheet).
class _WebhookEditorSheet extends StatelessWidget {
  final ApiClient api;
  const _WebhookEditorSheet({required this.api});

  @override
  Widget build(BuildContext context) {
    return _WebhookEditorScreen(api: api);
  }
}

class _WebhookEditorScreen extends StatefulWidget {
  final ApiClient api;
  const _WebhookEditorScreen({required this.api});

  @override
  State<_WebhookEditorScreen> createState() => _WebhookEditorScreenState();
}

class _WebhookEditorScreenState extends State<_WebhookEditorScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _eventsCtrl;
  late final TextEditingController _promptCtrl;
  late final TextEditingController _skillsCtrl;
  String _deliver = 'log';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descriptionCtrl = TextEditingController();
    _eventsCtrl = TextEditingController();
    _promptCtrl = TextEditingController();
    _skillsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _eventsCtrl.dispose();
    _promptCtrl.dispose();
    _skillsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final connection = context.read<ConnectionStore>();
    final api = widget.api;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      showHermesToast(context, message: context.l10n.webhookNameRequired);
      return;
    }
    final events = _eventsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final skills = _skillsCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() => _saving = true);
    try {
      requireActiveApi(context, connection, api);
      final created = await api.webhookCreate({
        'name': name,
        'description': _descriptionCtrl.text.trim(),
        'events': events,
        'prompt': _promptCtrl.text.trim(),
        'skills': skills,
        'deliver': _deliver,
      });
      if (!mounted) return;
      requireActiveApi(context, connection, api);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(dialogContext.l10n.webhookCreated),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dialogContext.l10n.webhookSecretOnce),
              const SizedBox(height: 12),
              Text(dialogContext.l10n.webhookUrl),
              SelectableText(created.url),
              const SizedBox(height: 12),
              Text(dialogContext.l10n.webhookSecret),
              SelectableText(created.secret ?? ''),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.webhookSecretSaved),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted && identical(api, connection.api)) {
        showHermesToast(context, message: context.l10n.webhookSaveFailed('$e'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: HermesSpacing.md,
        right: HermesSpacing.md,
        top: HermesSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + HermesSpacing.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.webhookNew,
              style: HermesType.onSurface(HermesType.headline, theme),
            ),
            const SizedBox(height: HermesSpacing.md),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: context.l10n.webhookName),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _descriptionCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.webhookDescriptionOptional,
                prefixIcon: const Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _eventsCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.webhookEventsComma,
                hintText: 'session.completed, task.done',
                prefixIcon: const Icon(Icons.notifications_active_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _promptCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.l10n.webhookPromptOptional,
                prefixIcon: const Icon(Icons.chat_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            TextField(
              controller: _skillsCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.webhookSkillsComma,
                prefixIcon: const Icon(Icons.extension_outlined),
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _deliver,
              decoration: InputDecoration(
                labelText: context.l10n.webhookDeliveryTarget,
              ),
              items: [
                DropdownMenuItem(
                  value: 'log',
                  child: Text(context.l10n.webhookLogOnly),
                ),
                const DropdownMenuItem(
                  value: 'telegram',
                  child: Text('Telegram'),
                ),
                const DropdownMenuItem(
                  value: 'discord',
                  child: Text('Discord'),
                ),
                const DropdownMenuItem(value: 'slack', child: Text('Slack')),
              ],
              onChanged: (value) => setState(() => _deliver = value ?? 'log'),
            ),
            const SizedBox(height: HermesSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving
                      ? context.l10n.webhookSaving
                      : context.l10n.commonSave,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
