/// Shared profile-scope picker widgets bound to [ProfileScopeStore] —
/// desktop parity for `SettingsProfileScope`'s chip row (settings-style
/// screens) and the Capabilities tab's "Configuring: …" dropdown (MCP/
/// Skills/Toolsets-style screens). Both read/write the same store, so
/// picking a profile in one screen carries over to every other scope-aware
/// screen without switching the app's globally active profile.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/stores/profile_scope_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';

/// Chip row + caption, for ordinary settings screens (Model/对话, Providers).
/// Hidden when there's nothing to choose between (0 or 1 profiles known).
class ProfileScopeChips extends StatelessWidget {
  const ProfileScopeChips({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProfileScopeStore>();
    if (store.profiles.length < 2) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    final selected = store.override ?? store.activeProfile;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.profileScopeApplyTo,
            style: TextStyle(
              fontSize: 11.5,
              color: palette.text3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final profile in store.profiles)
                ChoiceChip(
                  label: Text(profile.name),
                  selected: profile.name == selected,
                  onSelected: (_) => store.setOverride(
                    profile.name == store.activeProfile ? null : profile.name,
                  ),
                ),
            ],
          ),
          if (store.override != null) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.profileScopeChangesApplyTo(store.override!),
              style: TextStyle(fontSize: 11.5, color: palette.text3),
            ),
          ],
        ],
      ),
    );
  }
}

/// "配置对象: [dropdown]" selector, for capabilities screens (MCP/Skills/
/// Toolsets). Hidden when there's nothing to choose between.
class ProfileScopeDropdown extends StatelessWidget {
  const ProfileScopeDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ProfileScopeStore>();
    if (store.profiles.length < 2) return const SizedBox.shrink();
    final palette = HermesPalette.of(context);
    final selected = store.override ?? store.activeProfile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.profileScopeConfiguring,
            style: TextStyle(
              fontSize: 11.5,
              color: palette.text3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isDense: true,
                isExpanded: true,
                value: selected,
                items: [
                  for (final profile in store.profiles)
                    DropdownMenuItem(
                      value: profile.name,
                      child: Text(
                        profile.name == store.activeProfile
                            ? context.l10n.profileScopeCurrent(profile.name)
                            : profile.name,
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  store.setOverride(
                    value == store.activeProfile ? null : value,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
