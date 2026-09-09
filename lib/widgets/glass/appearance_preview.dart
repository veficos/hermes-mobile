import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/hermes_glass_theme.dart';
import '../../theme/hermes_tokens.dart';
import 'glass_action_group.dart';
import 'glass_button.dart';
import 'glass_surface.dart';

/// Live material sample in Appearance settings. Uses the active theme, including
/// contrast and transparency preferences, with real keyboard-accessible controls.
class AppearancePreview extends StatefulWidget {
  const AppearancePreview({super.key});

  @override
  State<AppearancePreview> createState() => _AppearancePreviewState();
}

class _AppearancePreviewState extends State<AppearancePreview> {
  bool _chatSelected = false;

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final l10n = context.l10n;
    final liquid = HermesGlassTheme.of(context).enabled;
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette.accentBg, palette.bg, palette.elevated],
          ),
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                liquid ? l10n.appearanceLiquid : l10n.appearanceClassic,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              GlassSurface(
                thick: true,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: liquid
                      ? null
                      : BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                  child: Row(
                    children: [
                      Icon(
                        _chatSelected
                            ? Icons.chat_bubble_outline
                            : Icons.home_outlined,
                        color: palette.accent,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _chatSelected ? l10n.navSessions : l10n.navHome,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: GlassActionGroup(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GlassButton(
                        tooltip: l10n.navHome,
                        selected: !_chatSelected,
                        onPressed: () => setState(() => _chatSelected = false),
                        child: const Icon(Icons.home_outlined),
                      ),
                      GlassButton(
                        tooltip: l10n.navSessions,
                        selected: _chatSelected,
                        onPressed: () => setState(() => _chatSelected = true),
                        child: const Icon(Icons.chat_bubble_outline),
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
  }
}
