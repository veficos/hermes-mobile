import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/notifications_service.dart';
import '../core/remote_push.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

class PushSettingsScreen extends StatefulWidget {
  final bool embedded;

  const PushSettingsScreen({super.key, this.embedded = false});

  @override
  State<PushSettingsScreen> createState() => _PushSettingsScreenState();
}

class _PushSettingsScreenState extends State<PushSettingsScreen> {
  bool _testing = false;
  // Real OS-level permission state: null = unknown/not-applicable platform,
  // true/false = actually granted/denied at the OS level. This is distinct
  // from `service.enabled` (a local preference) and `service.registered`
  // (server-side registration ack) — neither reflects OS permission.
  bool? _osEnabled;

  @override
  void initState() {
    super.initState();
    _refreshOsPermission();
  }

  Future<void> _refreshOsPermission() async {
    final result = await context
        .read<NotificationsService>()
        .osNotificationsEnabled();
    if (mounted) setState(() => _osEnabled = result);
  }

  Future<void> _sendTest(RemotePushService service) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _testing = true);
    try {
      final result = await service.sendTest();
      final delivered = (result['delivered'] as num?)?.toInt() ?? 0;
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              delivered > 0
                  ? l10n.pushTestDelivered
                  : l10n.pushTestNotDelivered,
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.pushTestFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<RemotePushService>();
    final content = ListView(
      padding: const EdgeInsets.all(HermesSpacing.md),
      children: [
        Text(
          context.l10n.pushSettingsDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: HermesPalette.of(context).text2,
          ),
        ),
        const SizedBox(height: HermesSpacing.md),
        HermesMobileGroup(
          children: [
            HermesMobileRow(
              icon: Icons.notifications_active_outlined,
              title: context.l10n.pushEnabled,
              subtitle: context.l10n.pushEnabledDescription,
              trailing: Switch(
                value: service.enabled,
                onChanged: (value) {
                  service.setEnabled(value);
                  _refreshOsPermission();
                },
              ),
            ),
            HermesMobileRow(
              icon: service.registered
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              title: context.l10n.pushRegistration,
              subtitle: service.registered
                  ? context.l10n.pushRegistered
                  : context.l10n.pushNotRegistered,
              trailing: HermesMobileStatusChip(
                label: service.registered
                    ? context.l10n.commonConnected
                    : context.l10n.commonDisconnected,
                color: service.registered
                    ? HermesSemantic.green
                    : HermesSemantic.orange,
              ),
            ),
            HermesMobileRow(
              icon: Icons.hub_outlined,
              title: context.l10n.pushProviders,
              subtitle: service.configuredPlatforms.isEmpty
                  ? context.l10n.pushNoProviders
                  : service.configuredPlatforms
                        .map((value) => value.toUpperCase())
                        .join(' · '),
              trailing: IconButton(
                tooltip: context.l10n.pushRefresh,
                onPressed: service.refreshStatus,
                icon: const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        if (service.enabled && _osEnabled == false) ...[
          const SizedBox(height: HermesSpacing.sm),
          HermesMobileGroup(
            children: [
              HermesMobileRow(
                icon: Icons.notifications_off_outlined,
                tone: Theme.of(context).colorScheme.error,
                title: context.l10n.pushOsPermissionDenied,
                subtitle: context.l10n.pushOsPermissionDeniedDescription,
              ),
            ],
          ),
        ],
        if (service.lastError?.isNotEmpty == true) ...[
          const SizedBox(height: HermesSpacing.sm),
          Text(
            service.lastError!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: HermesSpacing.md),
        FilledButton.icon(
          key: const ValueKey('push-send-test'),
          onPressed: service.enabled && service.registered && !_testing
              ? () => _sendTest(service)
              : null,
          icon: _testing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_outlined),
          label: Text(context.l10n.pushSendTest),
        ),
      ],
    );

    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text(
              context.l10n.pushSettingsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(child: content),
        ],
      );
    }
    return MobilePageScaffold(
      title: context.l10n.pushSettingsTitle,
      body: content,
    );
  }
}
