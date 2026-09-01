/// PetOverlay: in-app floating pet widget (adapted from desktop transparent window).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/stores/pet_store.dart';
import '../l10n/l10n.dart';
import '../screens/pet_generate_screen.dart';
import '../theme/hermes_tokens.dart';
import 'h/hermes_glass.dart';
import 'h/hermes_toast.dart';

/// Decodes a pet image field that may be a raw base64 string or a full
/// `data:image/...;base64,...` URI (both appear across this API surface).
Uint8List? _decodePetImage(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final commaIdx = raw.indexOf(',');
    final b64 = raw.startsWith('data:image/') && commaIdx != -1
        ? raw.substring(commaIdx + 1)
        : raw;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

/// The selected pet's real appearance (`PetInfo.spritesheetBase64`, cropped
/// to its first frame) — falls back to [fallbackEmoji] only when the
/// backend hasn't sent sprite data yet.
class _PetSpriteAvatar extends StatelessWidget {
  final PetInfo? info;
  final double size;
  final String fallbackEmoji;

  const _PetSpriteAvatar({
    required this.info,
    required this.size,
    required this.fallbackEmoji,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodePetImage(info?.spritesheetBase64);
    final frameW = info?.frameW;
    final frameH = info?.frameH;
    if (bytes == null ||
        frameW == null ||
        frameH == null ||
        frameW <= 0 ||
        frameH <= 0) {
      return Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.5));
    }
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: frameW.toDouble(),
            height: frameH.toDouble(),
            child: ClipRect(
              child: Image.memory(
                bytes,
                alignment: Alignment.topLeft,
                fit: BoxFit.none,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    Text(fallbackEmoji, style: TextStyle(fontSize: size * 0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PetOverlay extends StatefulWidget {
  final Widget child;
  const PetOverlay({super.key, required this.child});

  @override
  State<PetOverlay> createState() => _PetOverlayState();
}

class _PetOverlayState extends State<PetOverlay> {
  Offset _position = const Offset(0, 0);
  bool _initialized = false;
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final petStore = context.watch<PetStore>();
    if (!petStore.enabled || petStore.info == null) {
      return widget.child;
    }

    final size = MediaQuery.of(context).size;
    if (!_initialized) {
      _position = Offset(size.width - 90, size.height - 200);
      _initialized = true;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: _buildPet(petStore),
        ),
        if (_menuOpen) _buildMenu(context, petStore),
      ],
    );
  }

  Widget _buildPet(PetStore store) {
    final emoji = _emojiForState(store.state);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _position += details.delta;
          _position = Offset(
            _position.dx.clamp(0.0, MediaQuery.of(context).size.width - 60),
            _position.dy.clamp(0.0, MediaQuery.of(context).size.height - 100),
          );
        });
      },
      onLongPress: () {
        setState(() => _menuOpen = true);
      },
      onTap: () {
        if (store.state == PetState.idle) {
          store.celebrate();
        }
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
      ),
    );
  }

  String _emojiForState(PetState state) {
    return switch (state) {
      PetState.idle => '🐱',
      PetState.wave => '😺',
      PetState.run => '🏃',
      PetState.failed => '😿',
      PetState.jump => '🐰',
      PetState.waiting => '🤔',
      PetState.celebrate => '🎉',
    };
  }

  Widget _buildMenu(BuildContext context, PetStore store) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _menuOpen = false),
      child: Container(
        color: Colors.black54,
        child: Center(
          child: HermesGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  store.info?.displayName ?? 'Hermes Pet',
                  style: HermesType.onSurface(HermesType.headline, theme),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(Icons.pets, color: theme.colorScheme.primary),
                  title: Text(
                    context.l10n.petCenterTitle,
                    style: HermesType.onSurface(HermesType.callout, theme),
                  ),
                  onTap: () {
                    setState(() => _menuOpen = false);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const _PetCenterRoute(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(Icons.edit, color: theme.colorScheme.primary),
                  title: Text(
                    context.l10n.petRename,
                    style: HermesType.onSurface(HermesType.callout, theme),
                  ),
                  onTap: () async {
                    setState(() => _menuOpen = false);
                    final name = await _showRenameDialog(context);
                    if (name == null) return;
                    try {
                      await store.rename(name);
                    } catch (e) {
                      if (context.mounted) {
                        showHermesToast(
                          context,
                          message: context.l10n.petRenameFailed('$e'),
                          kind: HermesToastKind.error,
                        );
                      }
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.power_settings_new,
                    color: HermesSemantic.red,
                  ),
                  title: Text(
                    context.l10n.petDisable,
                    style: TextStyle(fontSize: 14, color: HermesSemantic.red),
                  ),
                  onTap: () async {
                    setState(() => _menuOpen = false);
                    try {
                      await store.disable();
                    } catch (e) {
                      if (context.mounted) {
                        showHermesToast(
                          context,
                          message: context.l10n.petDisableFailed('$e'),
                          kind: HermesToastKind.error,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A gallery entry's own `thumbDataUrl` preview — falls back to a generic
/// cat emoji only when the backend sent no thumbnail for that entry.
class _PetGalleryThumb extends StatelessWidget {
  final PetGalleryEntry entry;
  final double size;

  const _PetGalleryThumb({required this.entry, required this.size});

  @override
  Widget build(BuildContext context) {
    final bytes = _decodePetImage(entry.thumbDataUrl);
    if (bytes == null) {
      return Text('🐱', style: TextStyle(fontSize: size));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(HermesRadius.smallCard),
      child: Image.memory(
        bytes,
        width: size * 1.4,
        height: size * 1.4,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            Text('🐱', style: TextStyle(fontSize: size)),
      ),
    );
  }
}

Future<String?> _showRenameDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        context.l10n.petRenameTitle,
        style: HermesType.onSurface(HermesType.headline, Theme.of(ctx)),
      ),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface),
        decoration: InputDecoration(
          hintText: context.l10n.petRenameHint,
          hintStyle: TextStyle(
            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
          child: Text(context.l10n.commonConfirm),
        ),
      ],
    ),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
  return result;
}

class _PetCenterRoute extends StatelessWidget {
  const _PetCenterRoute();

  @override
  Widget build(BuildContext context) {
    return const PetCenterScreen();
  }
}

/// Pet Center screen — gallery, generate, disable.
class PetCenterScreen extends StatefulWidget {
  const PetCenterScreen({super.key});

  @override
  State<PetCenterScreen> createState() => _PetCenterScreenState();
}

class _PetCenterScreenState extends State<PetCenterScreen> {
  @override
  void initState() {
    super.initState();
    final store = context.read<PetStore>();
    store.refresh();
    store.loadGallery();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = context.watch<PetStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.petCenterTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.petRename,
            onPressed: store.info == null
                ? null
                : () async {
                    final name = await _showRenameDialog(context);
                    if (name != null && name.isNotEmpty) {
                      try {
                        await store.rename(name);
                      } catch (error) {
                        if (context.mounted) {
                          showHermesToast(
                            context,
                            message: context.l10n.petRenameFailed('$error'),
                            kind: HermesToastKind.error,
                          );
                        }
                      }
                    }
                  },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: store.loading && store.info == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current pet card
                  HermesGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.15,
                            ),
                          ),
                          child: Center(
                            child: _PetSpriteAvatar(
                              info: store.info,
                              size: 64,
                              fallbackEmoji: '🐱',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                store.info?.displayName ??
                                    context.l10n.petUntitled,
                                style: HermesType.onSurface(
                                  HermesType.title,
                                  theme,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.petStatus(
                                  _stateLabel(context, store.state),
                                ),
                                style: HermesType.onSurfaceVariant(
                                  HermesType.footnote,
                                  theme,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Gallery
                  Text(
                    context.l10n.petGallery,
                    style: HermesType.onSurface(HermesType.headline, theme),
                  ),
                  const SizedBox(height: 12),
                  if (store.gallery.isEmpty)
                    Text(
                      context.l10n.petGalleryEmpty,
                      style: HermesType.onSurfaceVariant(
                        HermesType.callout,
                        theme,
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1,
                          ),
                      itemCount: store.gallery.length,
                      itemBuilder: (ctx, i) {
                        final entry = store.gallery[i];
                        final isSelected = entry.slug == store.info?.slug;
                        return GestureDetector(
                          onTap: () async {
                            try {
                              await store.select(entry.slug);
                            } catch (error) {
                              if (context.mounted) {
                                showHermesToast(
                                  context,
                                  message: context.l10n.petSelectFailed(
                                    '$error',
                                  ),
                                  kind: HermesToastKind.error,
                                );
                              }
                            }
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                HermesRadius.card,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outline.withValues(
                                        alpha: 0.3,
                                      ),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PetGalleryThumb(entry: entry, size: 28),
                                const SizedBox(height: 4),
                                Text(
                                  entry.displayName ?? entry.slug,
                                  style: HermesType.onSurfaceVariant(
                                    HermesType.caption,
                                    theme,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: 24),
                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PetGenerateScreen(),
                          ),
                        );
                        if (context.mounted) await store.loadGallery();
                      },
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(context.l10n.petGenerateNew),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await store.disable();
                        } catch (error) {
                          if (context.mounted) {
                            showHermesToast(
                              context,
                              message: context.l10n.petDisableFailed('$error'),
                              kind: HermesToastKind.error,
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: HermesSemantic.red,
                      ),
                      icon: const Icon(Icons.power_settings_new),
                      label: Text(context.l10n.petDisable),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _stateLabel(BuildContext context, PetState state) {
    return switch (state) {
      PetState.idle => context.l10n.statusIdle,
      PetState.wave => context.l10n.petStateWave,
      PetState.run => context.l10n.statusRunning,
      PetState.failed => context.l10n.statusFailed,
      PetState.jump => context.l10n.petStateJump,
      PetState.waiting => context.l10n.statusWaiting,
      PetState.celebrate => context.l10n.petStateCelebrate,
    };
  }
}
