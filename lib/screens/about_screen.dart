import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../core/diagnostics.dart';
import '../core/external_links.dart';
import '../core/clipboard.dart';
import '../core/performance_metrics.dart';
import '../core/stores/update_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';

/// The single About surface used by every navigation layout.
class AboutScreen extends StatelessWidget {
  final bool embedded;

  const AboutScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = const _AboutContent();
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.aboutTitle)),
      body: content,
    );
  }
}

class _AboutContent extends StatelessWidget {
  const _AboutContent();

  @override
  Widget build(BuildContext context) {
    final updates = Provider.of<UpdateStore?>(context);
    final l10n = context.l10n;
    final version = updates?.currentVersion ?? '1.0.0';
    final build = updates?.currentBuild ?? '1';
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
      children: [
        HermesMobileCard(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: HermesPalette.of(context).accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'H',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hermes Mobile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                l10n.updateVersionBuild(version, build),
                style: TextStyle(
                  color: HermesPalette.of(context).text3,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.aboutProductDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        HermesMobileSectionLabel(title: l10n.updateSectionTitle),
        HermesMobileGroup(
          children: [
            if (updates?.requiresUpdate == true)
              ListTile(
                leading: const Icon(
                  Icons.warning_amber_outlined,
                  color: HermesSemantic.red,
                ),
                title: Text(l10n.updateUnsupportedTitle),
                subtitle: Text(
                  l10n.updateMinimumVersion(
                    updates!.manifest!.minimumSupportedVersion,
                  ),
                ),
              )
            else if (updates?.updateAvailable == true)
              ListTile(
                leading: const Icon(
                  Icons.system_update_outlined,
                  color: HermesSemantic.green,
                ),
                title: Text(
                  l10n.updateAvailableTitle(updates!.manifest!.latestVersion),
                ),
                subtitle: Text(
                  updates.manifest?.message ?? l10n.updateNewVersionPublished,
                ),
              )
            else
              ListTile(
                leading: const Icon(Icons.verified_outlined),
                title: Text(l10n.updateAppVersion),
                subtitle: Text(l10n.updateVersionBuild(version, build)),
              ),
            ListTile(
              leading: updates?.checking == true
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              title: Text(l10n.updateCheck),
              subtitle: updates?.error == null
                  ? Text(l10n.updateCheckDescription)
                  : Text(l10n.updateCheckUnavailable(updates!.error!)),
              enabled: updates != null && !updates.checking,
              onTap: updates == null || updates.checking
                  ? null
                  : () async {
                      final ok = await updates.check(force: true);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? updates.updateAvailable
                                      ? l10n.updateFound(
                                          updates.manifest!.latestVersion,
                                        )
                                      : l10n.updateCurrent
                                : l10n.updateCheckFailed,
                          ),
                        ),
                      );
                    },
            ),
            if (updates?.updateAvailable == true ||
                updates?.requiresUpdate == true)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text(l10n.updateGoToUpdate),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () =>
                    launchExternalOrNotify(context, updates!.updateUri),
              ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(l10n.updateReleaseNotes),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => launchExternalOrNotify(
                context,
                updates?.releaseNotesUri ??
                    Uri.parse(
                      'https://github.com/NousResearch/hermes-agent/releases',
                    ),
              ),
            ),
          ],
        ),
        HermesMobileSectionLabel(title: l10n.helpAndFeedbackTitle),
        HermesMobileGroup(
          children: [
            HermesMobileRow(
              icon: Icons.bug_report_outlined,
              title: l10n.sendDiagnosticsTitle,
              subtitle: l10n.sendDiagnosticsSubtitle,
              onTap: () => showSendDiagnosticsDialog(context),
            ),
            HermesMobileRow(
              icon: Icons.speed_outlined,
              title: 'Client performance',
              subtitle: 'View and copy metrics from this app run',
              onTap: () => _showPerformanceSnapshot(context),
            ),
            HermesMobileRow(
              icon: Icons.forum_outlined,
              title: l10n.reportIssueTitle,
              onTap: () => launchExternalOrNotify(
                context,
                Uri.parse(
                  'https://github.com/NousResearch/hermes-agent/issues',
                ),
              ),
            ),
            HermesMobileRow(
              icon: Icons.chat_bubble_outline,
              title: l10n.discordCommunityTitle,
              onTap: () => launchExternalOrNotify(
                context,
                Uri.parse('https://discord.gg/NousResearch'),
              ),
            ),
          ],
        ),
        HermesMobileSectionLabel(title: l10n.legalTitle),
        HermesMobileGroup(
          children: [
            HermesMobileRow(
              icon: Icons.code,
              title: l10n.aboutLicenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Hermes Mobile',
                applicationVersion: version,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showPerformanceSnapshot(BuildContext context) async {
    final encoder = const JsonEncoder.withIndent('  ');
    final snapshot = encoder.convert(
      ClientPerformanceMetrics.instance.snapshot(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Client performance'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              snapshot,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.commonClose),
          ),
          FilledButton.icon(
            onPressed: () => copyTextOrNotify(
              dialogContext,
              snapshot,
              successMessage: context.l10n.commonCopied,
            ),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(context.l10n.commonCopy),
          ),
        ],
      ),
    );
  }
}
