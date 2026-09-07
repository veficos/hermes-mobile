library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/bot_avatar.dart';
import '../core/pet_gallery.dart';
import '../core/stores/bot_store.dart';
import '../l10n/l10n.dart';
import '../widgets/bot_avatar.dart';
import '../widgets/h/hermes_toast.dart';
import '../widgets/mobile/mobile_page_scaffold.dart';

Uint8List? _decodeDataUrl(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final comma = dataUrl.indexOf(',');
  if (!dataUrl.startsWith('data:') || comma == -1) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}

const _maxAvatarUploadBytes = 15 * 1000 * 1000;

class BotAvatarEditorScreen extends StatefulWidget {
  final BotIdentity bot;

  const BotAvatarEditorScreen({super.key, required this.bot});

  @override
  State<BotAvatarEditorScreen> createState() => _BotAvatarEditorScreenState();
}

class _BotAvatarEditorScreenState extends State<BotAvatarEditorScreen> {
  late String _shape;
  late Color _color;
  String? _imageDataUrl;
  String? _originalImageDataUrl;
  bool _saving = false;
  bool _uploading = false;
  bool _generating = false;
  bool? _imagenAvailable;
  final _picker = ImagePicker();
  final _generateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final appearance = botAppearance(widget.bot.profile, widget.bot.metadata);
    _shape = appearance.shape;
    _color = appearance.color;
    _imageDataUrl = appearance.image;
    _originalImageDataUrl = appearance.image;
    unawaited(_probeImagen());
  }

  @override
  void dispose() {
    _generateController.dispose();
    super.dispose();
  }

  Future<void> _probeImagen() async {
    final available = await context.read<BotStore>().probeImageGeneration(
      widget.bot,
    );
    if (mounted) setState(() => _imagenAvailable = available);
  }

  Future<void> _generateImage() async {
    setState(() => _generating = true);
    try {
      final store = context.read<BotStore>();
      final bytes = await store.generateBotAvatarImage(
        widget.bot,
        _generateController.text.trim(),
      );
      if (!mounted) return;
      setState(
        () => _imageDataUrl = 'data:image/png;base64,${base64Encode(bytes)}',
      );
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.avatarEditorGenerateFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _choosePet() async {
    final store = context.read<BotStore>();
    final dataUrl = await showMobileSheet<String>(
      context,
      (context) => _PetGallerySheet(
        bot: widget.bot,
        fetchPets: () => store.fetchPetGallery(widget.bot),
      ),
    );
    if (dataUrl != null && mounted) {
      setState(() => _imageDataUrl = dataUrl);
    }
  }

  void _randomize() {
    final random = math.Random();
    setState(() {
      _shape = kAvatarShapes[random.nextInt(kAvatarShapes.length)];
      _color = kAvatarColors[random.nextInt(kAvatarColors.length)];
    });
  }

  /// Picking/generating/pet-selecting all only update this dialog's local
  /// state — nothing is persisted until [_save] commits it, matching
  /// desktop's `AvatarPicker` (a direct write here would get clobbered by
  /// Save's own image state).
  Future<void> _pickAndUploadImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    final size = await File(picked.path).length();
    if (size > _maxAvatarUploadBytes) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.avatarEditorImageTooLarge,
          kind: HermesToastKind.error,
        );
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      final raw = await picked.readAsBytes();
      final normalized = await normalizeAvatarImage(raw);
      if (!mounted) return;
      setState(
        () => _imageDataUrl =
            'data:image/png;base64,${base64Encode(normalized)}',
      );
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.avatarEditorSaveFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _removeImage() {
    setState(() => _imageDataUrl = null);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final store = context.read<BotStore>();
      await store.updateBotAppearance(widget.bot, shape: _shape, color: _color);
      if (_imageDataUrl != _originalImageDataUrl) {
        if (_imageDataUrl == null) {
          await store.clearBotAvatarImage(widget.bot);
        } else {
          final bytes = _decodeDataUrl(_imageDataUrl);
          if (bytes != null) {
            await store.uploadBotAvatarImage(widget.bot, bytes);
          }
        }
      }
      if (!mounted) return;
      showHermesToast(context, message: context.l10n.avatarEditorSaved);
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.avatarEditorSaveFailed('$error'),
        kind: HermesToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final metadata = {
      ...widget.bot.metadata,
      'custom': true,
      'shape': _shape,
      'image': _imageDataUrl,
    };
    final busy = _saving || _uploading || _generating;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.agentEditAvatarMenuItem),
        actions: [
          IconButton(
            icon: const Icon(Icons.shuffle),
            tooltip: context.l10n.avatarEditorRandomize,
            onPressed: busy ? null : _randomize,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: BotAvatar(name: widget.bot.profile, metadata: metadata, size: 96),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: busy ? null : _pickAndUploadImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(context.l10n.avatarEditorUploadPhoto),
              ),
              TextButton.icon(
                onPressed: busy ? null : _choosePet,
                icon: const Icon(Icons.pets_outlined),
                label: Text(context.l10n.avatarEditorChoosePet),
              ),
              if (_imageDataUrl != null)
                TextButton.icon(
                  onPressed: busy ? null : _removeImage,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(context.l10n.avatarEditorRemovePhoto),
                ),
            ],
          ),
          if (_imagenAvailable == true) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _generateController,
              enabled: !busy,
              decoration: InputDecoration(
                hintText: context.l10n.avatarEditorGenerateHint,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: busy ? null : _generateImage,
              icon: _generating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(context.l10n.avatarEditorGenerate),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context.l10n.avatarEditorShapeLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kAvatarShapes.map((shape) {
              final selected = shape == _shape;
              return _ShapeSwatch(
                shape: shape,
                color: _color,
                selected: selected,
                onTap: () => setState(() => _shape = shape),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),
          Text(
            context.l10n.avatarEditorColorLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: kAvatarColors.map((color) {
              final selected = color.toARGB32() == _color.toARGB32();
              return _ColorSwatch(
                color: color,
                selected: selected,
                onTap: () => setState(() => _color = color),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
  }
}

class _ShapeSwatch extends StatelessWidget {
  final String shape;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ShapeSwatch({
    required this.shape,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: BotAvatar(
          name: 'shape-preview',
          metadata: {'custom': true, 'shape': shape, 'color': _hexOf(color)},
          size: 44,
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: isDarkColor(color) ? Colors.white : Colors.black87,
                size: 20,
              )
            : null,
      ),
    );
  }
}

String _hexOf(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Searchable/windowed petdex grid — mirrors desktop's `PetTab`: installed
/// pets first, then curated, then the rest; a tap crops frame 0 of the
/// spritesheet and pops it back to the caller to stage (not persisted here).
class _PetGallerySheet extends StatefulWidget {
  final BotIdentity bot;
  final Future<List<PetGalleryEntry>> Function() fetchPets;

  const _PetGallerySheet({required this.bot, required this.fetchPets});

  @override
  State<_PetGallerySheet> createState() => _PetGallerySheetState();
}

class _PetGallerySheetState extends State<_PetGallerySheet> {
  late final Future<List<PetGalleryEntry>> _future = widget.fetchPets();
  final _scrollController = ScrollController();
  String _query = '';
  int _limit = 24;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      setState(() => _limit += 24);
    }
  }

  List<PetGalleryEntry> _filterAndRank(List<PetGalleryEntry> pets) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? pets
        : pets
              .where(
                (pet) =>
                    pet.displayName.toLowerCase().contains(query) ||
                    pet.slug.toLowerCase().contains(query),
              )
              .toList();
    filtered.sort((a, b) {
      if (a.installed != b.installed) return a.installed ? -1 : 1;
      if (a.curated != b.curated) return a.curated ? -1 : 1;
      return a.displayName.compareTo(b.displayName);
    });
    return filtered;
  }

  Future<void> _selectPet(PetGalleryEntry pet) async {
    final icon = await petFrameIcon(pet.spritesheetUrl);
    if (icon != null && mounted) Navigator.of(context).pop(icon);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: context.l10n.avatarEditorPetSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<PetGalleryEntry>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(context.l10n.avatarEditorPetLoadFailed),
                      );
                    }
                    final pets = _filterAndRank(snapshot.data ?? const []);
                    final visible = pets.take(_limit).toList();
                    return GridView.builder(
                      controller: _scrollController,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.92,
                          ),
                      itemCount: visible.length,
                      itemBuilder: (context, index) => _PetTile(
                        pet: visible[index],
                        onTap: () => _selectPet(visible[index]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PetTile extends StatefulWidget {
  final PetGalleryEntry pet;
  final VoidCallback onTap;

  const _PetTile({required this.pet, required this.onTap});

  @override
  State<_PetTile> createState() => _PetTileState();
}

class _PetTileState extends State<_PetTile> {
  late final Future<String?> _iconFuture = petFrameIcon(
    widget.pet.spritesheetUrl,
  );

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: FutureBuilder<String?>(
              future: _iconFuture,
              builder: (context, snapshot) {
                final bytes = _decodeDataUrl(snapshot.data);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : Container(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.pet.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
