/// SettingsHubScreen —— 统一设置中心（IA 重设计 §3.4）。
///
/// S/M 使用分组目录进入子页；L/XL 使用固定分组导航和右侧内容区。
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/appearance_store.dart';
import '../core/stores/locale_store.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/mobile/hermes_mobile_surfaces.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';
import 'about_screen.dart';
import 'billing_screen.dart';
import 'config_screen.dart';
import 'credentials_screen.dart';
import 'messaging_screen.dart';
import 'profiles_screen.dart';
import 'provider_config_screen.dart';
import 'push_settings_screen.dart';
import 'settings_screen.dart';
import 'webhooks_screen.dart';

class SettingsHubScreen extends StatefulWidget {
  const SettingsHubScreen({super.key});

  @override
  State<SettingsHubScreen> createState() => _SettingsHubScreenState();
}

class _SettingsHubScreenState extends State<SettingsHubScreen> {
  String _selectedId = 'appearance';

  List<_SettingsSection> _sections(BuildContext context) {
    final l10n = context.l10n;
    return [
      _SettingsSection(
        title: l10n.settingsGroupPersonalization,
        entries: [
          _SettingsEntry(
            id: 'appearance',
            icon: Icons.palette_outlined,
            title: l10n.appearanceTitle,
            subtitle: l10n.settingsAppearanceDesc,
            compactPage: const _AppearancePage(),
            widePage: const _AppearanceEmbeddedPage(),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.settingsGroupModels,
        entries: [
          _SettingsEntry(
            id: 'model',
            icon: Icons.tune_outlined,
            title: l10n.settingsModelTitle,
            subtitle: l10n.settingsModelDesc,
            compactPage: const ConfigScreen(),
            widePage: const ConfigScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'providers',
            icon: Icons.cloud_outlined,
            title: l10n.settingsProvidersTitle,
            subtitle: l10n.settingsProvidersDesc,
            compactPage: const ProviderConfigScreen(),
            widePage: const ProviderConfigScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'profiles',
            icon: Icons.layers_outlined,
            title: l10n.featureProfiles,
            subtitle: l10n.featureProfilesDesc,
            compactPage: const ProfilesScreen(),
            widePage: const ProfilesScreen(embedded: true),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.groupIntegrations,
        entries: [
          _SettingsEntry(
            id: 'messaging',
            icon: Icons.chat_outlined,
            title: l10n.featureMessaging,
            subtitle: l10n.featureMessagingDesc,
            compactPage: const MessagingScreen(),
            widePage: const MessagingScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'webhooks',
            icon: Icons.webhook_outlined,
            title: l10n.featureWebhooks,
            subtitle: l10n.featureWebhooksDesc,
            compactPage: const WebhooksScreen(),
            widePage: const WebhooksScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'credentials',
            icon: Icons.key_outlined,
            title: l10n.featureCredentials,
            subtitle: l10n.featureCredentialsDesc,
            compactPage: const CredentialsScreen(),
            widePage: const CredentialsScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'billing',
            icon: Icons.receipt_long_outlined,
            title: l10n.featureBilling,
            subtitle: l10n.featureBillingDesc,
            compactPage: const BillingScreen(),
            widePage: const BillingScreen(embedded: true),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.groupSystem,
        entries: [
          _SettingsEntry(
            id: 'push',
            icon: Icons.notifications_active_outlined,
            title: l10n.pushSettingsTitle,
            subtitle: l10n.pushSettingsDescription,
            compactPage: const PushSettingsScreen(),
            widePage: const PushSettingsScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'system',
            icon: Icons.settings_outlined,
            title: l10n.settingsSystemConnectionTitle,
            subtitle: l10n.settingsSystemConnectionDesc,
            compactPage: const SettingsScreen(),
            widePage: const SettingsScreen(embedded: true),
          ),
          _SettingsEntry(
            id: 'about',
            icon: Icons.info_outline,
            title: l10n.aboutTitle,
            subtitle: l10n.featureAboutDesc,
            compactPage: const AboutScreen(),
            widePage: const AboutScreen(embedded: true),
          ),
        ],
      ),
    ];
  }

  _SettingsEntry _selectedEntry(BuildContext context) => _sections(context)
      .expand((section) => section.entries)
      .firstWhere((entry) => entry.id == _selectedId);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) return _buildCompact(context);
        return _buildWide(context);
      },
    );
  }

  Widget _buildCompact(BuildContext context) {
    final sections = _sections(context);
    return MobilePageScaffold(
      title: context.l10n.featureSettings,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
            children: [
              _pluginSettings(context),
              for (final section in sections) ...[
                _SectionHeader(title: section.title),
                _EntryGroup(
                  entries: section.entries,
                  onTap: (entry) => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => entry.compactPage)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    final palette = HermesPalette.of(context);
    final l10n = context.l10n;
    final sections = _sections(context);
    final selectedEntry = _selectedEntry(context);
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 300,
            child: Material(
              color: palette.surface,
              shape: Border(right: BorderSide(color: palette.border)),
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        HermesSpacing.sm,
                        HermesSpacing.lg,
                        HermesSpacing.lg,
                        HermesSpacing.md,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            key: const ValueKey('settings-home-back'),
                            tooltip: l10n.settingsBackHome,
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back),
                          ),
                          const SizedBox(width: HermesSpacing.xs),
                          Text(
                            l10n.featureSettings,
                            style: HermesType.onSurface(
                              HermesType.title,
                              Theme.of(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          HermesSpacing.sm,
                          0,
                          HermesSpacing.sm,
                          HermesSpacing.lg,
                        ),
                        children: [
                          _pluginSettings(context),
                          for (final section in sections) ...[
                            _SectionHeader(title: section.title),
                            for (final entry in section.entries)
                              _NavigationEntry(
                                entry: entry,
                                selected: entry.id == _selectedId,
                                onTap: () =>
                                    setState(() => _selectedId = entry.id),
                              ),
                            const SizedBox(height: HermesSpacing.md),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: ValueKey(selectedEntry.id),
              child: selectedEntry.widePage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pluginSettings(BuildContext context) {
    PluginContributionStore store;
    try {
      store = context.watch<PluginContributionStore>();
    } on ProviderNotFoundException {
      return const SizedBox.shrink();
    }
    final items = store.forArea(MobileContributionArea.settings);
    if (items.isEmpty) return const SizedBox.shrink();
    return HermesMobileGroup(
      margin: const EdgeInsets.only(top: 14),
      children: [
        for (final item in items)
          HermesMobileRow(
            icon: Icons.extension_outlined,
            title: item.title,
            subtitle: item.description.isEmpty ? null : item.description,
            onTap: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await store.invoke(item);
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        context.l10n.pluginActionFailed(item.title, '$e'),
                      ),
                    ),
                  );
                }
              }
            },
          ),
      ],
    );
  }
}

class _SettingsSection {
  final String title;
  final List<_SettingsEntry> entries;

  const _SettingsSection({required this.title, required this.entries});
}

class _SettingsEntry {
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget compactPage;
  final Widget? embeddedPage;

  const _SettingsEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.compactPage,
    Widget? widePage,
  }) : embeddedPage = widePage;

  Widget get widePage => embeddedPage ?? compactPage;
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return HermesMobileSectionLabel(title: title, top: 18);
  }
}

class _EntryGroup extends StatelessWidget {
  final List<_SettingsEntry> entries;
  final ValueChanged<_SettingsEntry> onTap;

  const _EntryGroup({required this.entries, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HermesMobileGroup(
      children: [
        for (final entry in entries)
          HermesMobileRow(
            icon: entry.icon,
            title: entry.title,
            subtitle: entry.subtitle,
            onTap: () => onTap(entry),
          ),
      ],
    );
  }
}

class _NavigationEntry extends StatelessWidget {
  final _SettingsEntry entry;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationEntry({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return ListTile(
      selected: selected,
      selectedTileColor: palette.accent.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      ),
      leading: Icon(entry.icon, size: 20),
      title: Text(entry.title),
      subtitle: Text(
        entry.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

class _AppearancePage extends StatelessWidget {
  const _AppearancePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.appearanceTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: const SingleChildScrollView(
            padding: EdgeInsets.all(HermesSpacing.lg),
            child: _AppearanceContent(),
          ),
        ),
      ),
    );
  }
}

class _AppearanceEmbeddedPage extends StatelessWidget {
  const _AppearanceEmbeddedPage();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(HermesSpacing.lg),
          child: _AppearanceContent(),
        ),
      ),
    );
  }
}

class _AppearanceContent extends StatelessWidget {
  const _AppearanceContent();

  String _nativeLanguageLabel(BuildContext context, String tag) {
    return switch (tag) {
      'en' => 'English',
      'zh' => '简体中文',
      'zh_Hant' => '繁體中文',
      'ja' => '日本語',
      'ar' => 'العربية',
      _ => context.l10n.languageSystem,
    };
  }

  Future<void> _chooseLanguage(BuildContext context, LocaleStore locale) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final options =
            <
              ({
                String tag,
                String? badge,
                IconData? badgeIcon,
                String native,
                String localized,
              })
            >[
              (
                tag: 'system',
                badge: null,
                badgeIcon: Icons.smartphone_outlined,
                native: l10n.languageSystem,
                localized: '',
              ),
              (
                tag: 'en',
                badge: 'EN',
                badgeIcon: null,
                native: 'English',
                localized: l10n.languageEnglish,
              ),
              (
                tag: 'zh',
                badge: '简',
                badgeIcon: null,
                native: '简体中文',
                localized: l10n.languageSimplifiedChinese,
              ),
              (
                tag: 'zh_Hant',
                badge: '繁',
                badgeIcon: null,
                native: '繁體中文',
                localized: l10n.languageTraditionalChinese,
              ),
              (
                tag: 'ja',
                badge: '日',
                badgeIcon: null,
                native: '日本語',
                localized: l10n.languageJapanese,
              ),
              (
                tag: 'ar',
                badge: 'ع',
                badgeIcon: null,
                native: 'العربية',
                localized: l10n.languageArabic,
              ),
            ];
        final palette = HermesPalette.of(sheetContext);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: palette.accentBg,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.translate_rounded,
                          color: palette.accent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.languageTitle,
                              style: Theme.of(sheetContext).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.languageDescription,
                              style: Theme.of(sheetContext).textTheme.bodySmall
                                  ?.copyWith(color: palette.text3),
                            ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        tooltip: l10n.commonClose,
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: HermesMobileGroup(
                        children: [
                          for (final option in options)
                            _LanguageOptionTile(
                              key: ValueKey('language-option-${option.tag}'),
                              badge: option.badge,
                              badgeIcon: option.badgeIcon,
                              title: option.native,
                              subtitle:
                                  option.localized.isNotEmpty &&
                                      option.localized != option.native
                                  ? option.localized
                                  : null,
                              selected: option.tag == locale.tag,
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(option.tag),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (selected == null || !context.mounted || selected == locale.tag) return;
    await locale.setLocale(LocaleStore.localeFromTag(selected));
  }

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppearanceStore>();
    final locale = context.watch<LocaleStore>();
    final l10n = context.l10n;
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HermesMobileGroup(
          children: [
            HermesMobileRow(
              key: const ValueKey('appearance-language-picker'),
              icon: Icons.translate_rounded,
              title: l10n.languageTitle,
              subtitle: l10n.languageDescription,
              onTap: () => _chooseLanguage(context, locale),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: _CurrentLanguagePill(
                  label: _nativeLanguageLabel(context, locale.tag),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: HermesSpacing.lg),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.appearanceModeSystem),
            ),
            ButtonSegment(
              value: ThemeMode.light,
              label: Text(l10n.appearanceModeLight),
            ),
            ButtonSegment(
              value: ThemeMode.dark,
              label: Text(l10n.appearanceModeDark),
            ),
          ],
          selected: {appearance.themeMode},
          onSelectionChanged: (selection) =>
              appearance.setThemeMode(selection.first),
          showSelectedIcon: false,
        ),
        const SizedBox(height: HermesSpacing.lg),
        Text(
          l10n.appearanceThemeColor,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: HermesSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth < 420 ? 2 : 4;
            return GridView.count(
              crossAxisCount: columns,
              crossAxisSpacing: HermesSpacing.sm,
              mainAxisSpacing: HermesSpacing.sm,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: columns == 2 ? 1.45 : 1.1,
              children: [
                for (final accent in HermesAccents.all)
                  _ThemePreviewCard(
                    theme: accent,
                    dark: isDark,
                    selected: appearance.accent.id == accent.id,
                    onTap: () => appearance.setAccentId(accent.id),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: HermesSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.appearanceHighContrast),
          subtitle: Text(
            l10n.appearanceHighContrastDesc,
            style: TextStyle(color: palette.text3),
          ),
          value: appearance.highContrast,
          onChanged: appearance.setHighContrast,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.appearanceHaptics),
          subtitle: Text(
            l10n.appearanceHapticsDesc,
            style: TextStyle(color: palette.text3),
          ),
          value: appearance.hapticsEnabled,
          onChanged: appearance.setHapticsEnabled,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.appearanceKeepAwake),
          subtitle: Text(
            l10n.appearanceKeepAwakeDesc,
            style: TextStyle(color: palette.text3),
          ),
          value: appearance.keepAwake,
          onChanged: appearance.setKeepAwake,
        ),
      ],
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  const _LanguageBadge({this.label, this.icon, required this.selected});

  /// Script/region letter (EN, 简, 繁, 日, ع) for a real language. Mutually
  /// exclusive with [icon] — the "follow system" option isn't a language
  /// and reads as one more confusingly than any other single letter would,
  /// so it gets an actual icon instead of a badge that looks like a stray
  /// abbreviation among the others.
  final String? label;
  final IconData? icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    // Fixed square regardless of label length — HermesMobileRow's own
    // leading icon badge is 31px, and without a fixed size here 'EN' (2
    // Latin letters) rendered a visibly wider box than '简'/'繁'/'日'/'ع'
    // (1 wide CJK/Arabic glyph), breaking the list's column alignment.
    return SizedBox.square(
      dimension: 31,
      child: AnimatedContainer(
        duration: HermesMotion.fast,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.accentBg,
          borderRadius: BorderRadius.circular(HermesMobileMetrics.iconRadius),
        ),
        child: icon != null
            ? Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : palette.accent,
              )
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    label ?? '',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: selected ? Colors.white : palette.accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _CurrentLanguagePill extends StatelessWidget {
  const _CurrentLanguagePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 7, 6),
      decoration: BoxDecoration(
        color: palette.accentBg,
        borderRadius: BorderRadius.circular(HermesRadius.capsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: palette.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Icon(Icons.expand_more_rounded, size: 17, color: palette.accent),
        ],
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    super.key,
    this.badge,
    this.badgeIcon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String? badge;
  final IconData? badgeIcon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primaryContainer.withValues(alpha: .42)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 11, 12, 11),
          child: Row(
            children: [
              _LanguageBadge(label: badge, icon: badgeIcon, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.text3),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? colors.primary : palette.text4,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final HermesAccent theme;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  const _ThemePreviewCard({
    required this.theme,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = theme.paletteOf(dark ? Brightness.dark : Brightness.light);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(HermesRadius.card),
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 72,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(HermesRadius.card),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.border),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: 14,
                      width: 36,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: palette.accent,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            switch (theme.id) {
              'graphite' => context.l10n.themeGraphite,
              'indigo' => context.l10n.themeIndigo,
              'moss' => context.l10n.themeMoss,
              'dune' => context.l10n.themeDune,
              _ => theme.label,
            },
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? palette.accent : null,
            ),
          ),
        ],
      ),
    );
  }
}
