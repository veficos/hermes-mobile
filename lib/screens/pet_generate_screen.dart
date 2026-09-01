/// PetGenerateScreen: AI宠物生成 — desktop `pet-generate` overlay parity.
///
/// Desktop flow (Cmd-K → Pets → Generate): describe (+ optional reference
/// photo) → 4 draft looks stream in live → pick one → hatch (full animated
/// pet, installed but not yet active) → name + adopt. The backend contract
/// (`pet.generate` / `pet.generate.progress` / `pet.hatch` /
/// `pet.hatch.progress` / `pet.cancel` / `pet.remove`) was already wired
/// into [ApiClient]/[PetStore] — only this screen was missing, so mobile's
/// "generate" button just fired a fixed prompt with no way to describe,
/// preview drafts, or watch hatching progress.
///
/// Scoped down from desktop for mobile: no background-resumable run (leaving
/// mid-flow cancels the in-flight job rather than continuing headless and
/// pinging an OS notification later) — simpler to reason about, and this
/// screen is reached from a single entry point rather than a global overlay.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/gateway.dart';
import '../core/models.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/pet_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';

enum _Phase { intro, generating, ready, hatching, preview }

const _eggGlyph = '🥚';
const _pawGlyph = '🐾';

class _Draft {
  final int index;
  final String dataUri;
  // Decoded once at construction instead of on every grid rebuild — the
  // draft grid's itemBuilder used to re-run base64Decode on all 4 drafts
  // each time any single one was selected (setState re-runs the whole
  // GridView.builder).
  final Uint8List? bytes;

  _Draft({required this.index, required this.dataUri})
    : bytes = _tryDecode(dataUri);

  static Uint8List? _tryDecode(String dataUri) {
    try {
      return base64Decode(dataUri.split(',').last);
    } catch (_) {
      return null;
    }
  }
}

class _HatchStage {
  final String phase; // row | compose | save
  final String? state;
  final int? done;
  final int? total;
  const _HatchStage({required this.phase, this.state, this.done, this.total});
}

const _kNameStopwords = {
  'a', 'an', 'and', 'at', 'by', 'cute', 'for', 'from', 'in', 'of', 'on', //
  'style', 'the', 'to', 'with', '一个', '一只', '风格', '的',
};

/// Derive a short default name from a free-text prompt (desktop's
/// `cleanPetName`) — the concept text ("2d dragon in the style of ragnarok
/// online") makes a poor label verbatim, so keep a few meaningful words.
String _cleanPetName(String prompt, {required String fallback}) {
  final words = prompt
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s-]', unicode: true), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final meaningful = words
      .where((w) => !_kNameStopwords.contains(w.toLowerCase()))
      .toList();
  final picked = (meaningful.isNotEmpty ? meaningful : words).take(3).toList();
  final name = picked
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  final trimmed = name.length > 28 ? name.substring(0, 28) : name;
  return trimmed.trim().isEmpty ? fallback : trimmed.trim();
}

class PetGenerateScreen extends StatefulWidget {
  const PetGenerateScreen({super.key});

  @override
  State<PetGenerateScreen> createState() => _PetGenerateScreenState();
}

class _PetGenerateScreenState extends State<PetGenerateScreen>
    with ConnectionReloadMixin<PetGenerateScreen> {
  final _promptCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _picker = ImagePicker();

  _Phase _phase = _Phase.intro;
  String? _referenceDataUri;
  String? _error;
  String? _token;
  List<_Draft> _drafts = [];
  int? _selectedIndex;
  _HatchStage? _hatchStage;
  PetInfo? _previewPet;
  bool _busy = false;
  bool _adopted = false;
  List<Map<String, dynamic>> _providers = [];
  String? _selectedProvider;
  StreamSubscription<GatewayEvent>? _eventSub;
  ApiClient? _jobApi;
  ApiClient? _previewApi;
  int _operationGeneration = 0;

  PetStore get _store => context.read<PetStore>();

  @override
  void initState() {
    super.initState();
    final connection = context.read<ConnectionStore>();
    observeConnection(connection, _onConnectionChanged);
    _eventSub = connection.events.listen(_onEvent);
    _checkAvailable();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    disposeConnectionObserver();
    _promptCtrl.dispose();
    _nameCtrl.dispose();
    if (!_adopted && _previewPet?.slug != null && _previewApi != null) {
      // Best-effort: don't let an abandoned preview accumulate server-side.
      unawaited(
        _store
            .remove(_previewPet!.slug!, expectedApi: _previewApi)
            .catchError((_) {}),
      );
    }
    super.dispose();
  }

  void _onConnectionChanged() {
    _operationGeneration++;
    _jobApi = null;
    _previewApi = null;
    if (!mounted) return;
    setState(() {
      _phase = _Phase.intro;
      _providers = const [];
      _selectedProvider = null;
      _drafts = const [];
      _selectedIndex = null;
      _hatchStage = null;
      _previewPet = null;
      _token = null;
      _busy = false;
      _error = context.l10n.backendDisconnected;
    });
    _checkAvailable();
  }

  Future<void> _checkAvailable() async {
    final api = _store.activeApi;
    if (api == null) return;
    try {
      final status = await _store.generateStatus(expectedApi: api);
      if (!mounted || !identical(api, _store.activeApi)) return;
      final providers = (status['providers'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      setState(() => _providers = providers);
    } catch (_) {
      // Probe is best-effort — an old backend just won't offer a provider
      // picker, generation itself still gets attempted.
    }
  }

  void _onEvent(GatewayEvent e) {
    if (_jobApi == null || !identical(_jobApi, _store.activeApi)) return;
    if (e.type == 'pet.generate.progress' && _phase == _Phase.generating) {
      final token = e.payload['token']?.toString();
      if (_token != null && token != null && token != _token) return;
      if (token != null && token.isNotEmpty) _token = token;
      final index = e.payload['index'];
      final dataUri = e.payload['dataUri']?.toString();
      if (index is num && dataUri != null && dataUri.isNotEmpty) {
        final i = index.toInt();
        if (!_drafts.any((d) => d.index == i)) {
          setState(() {
            _drafts = [..._drafts, _Draft(index: i, dataUri: dataUri)]
              ..sort((a, b) => a.index.compareTo(b.index));
          });
        }
      }
    } else if (e.type == 'pet.hatch.progress' && _phase == _Phase.hatching) {
      final event = e.payload['event']?.toString();
      if (event == 'row') {
        setState(
          () => _hatchStage = _HatchStage(
            phase: 'row',
            state: e.payload['state']?.toString(),
            done: int.tryParse('${e.payload['done']}'),
            total: int.tryParse('${e.payload['total']}'),
          ),
        );
      } else if (event == 'compose') {
        setState(() => _hatchStage = const _HatchStage(phase: 'compose'));
      } else if (event == 'save') {
        setState(() => _hatchStage = const _HatchStage(phase: 'save'));
      }
    }
  }

  Future<void> _pickReferenceImage() async {
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mime = file.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      if (!mounted) return;
      setState(
        () => _referenceDataUri = 'data:$mime;base64,${base64Encode(bytes)}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.petGenerateReferenceFailed('$error')),
          ),
        );
      }
    }
  }

  Future<void> _generate() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty && _referenceDataUri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.petGenerateInputRequired)),
      );
      return;
    }
    final api = _store.activeApi;
    if (api == null) {
      connectedApiOrNotify(context, context.read<ConnectionStore>());
      return;
    }
    final generation = ++_operationGeneration;
    _jobApi = api;
    setState(() {
      _phase = _Phase.generating;
      _drafts = [];
      _selectedIndex = null;
      _error = null;
      _token = null;
    });
    try {
      final result = await _store.generate({
        'prompt': prompt,
        'style': 'auto',
        'count': 4,
        if (_referenceDataUri != null) 'referenceImage': _referenceDataUri,
        if ((_selectedProvider ?? '').isNotEmpty) 'provider': _selectedProvider,
      }, expectedApi: api);
      if (!mounted ||
          generation != _operationGeneration ||
          !identical(api, _store.activeApi)) {
        return;
      }
      if (result['ok'] != true) {
        throw StateError(
          result['error']?.toString() ?? context.l10n.petGenerateEmptyResult,
        );
      }
      final token = result['token']?.toString();
      final drafts =
          (result['drafts'] as List? ?? const [])
              .whereType<Map>()
              .map(
                (d) => _Draft(
                  index: ((d['index'] as num?) ?? 0).toInt(),
                  dataUri: d['dataUri']?.toString() ?? '',
                ),
              )
              .where((d) => d.dataUri.isNotEmpty)
              .toList()
            ..sort((a, b) => a.index.compareTo(b.index));
      if (drafts.isEmpty) throw StateError(context.l10n.petGenerateEmptyResult);
      setState(() {
        _token = token;
        _drafts = drafts;
        _selectedIndex = drafts.first.index;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted || generation != _operationGeneration) return;
      setState(() {
        _phase = _drafts.isNotEmpty ? _Phase.ready : _Phase.intro;
        _error = '$e';
      });
    }
  }

  Future<void> _cancelGenerate() async {
    final token = _token;
    final api = _jobApi;
    _operationGeneration++;
    setState(() => _phase = _drafts.isNotEmpty ? _Phase.ready : _Phase.intro);
    if (token != null && api != null) {
      try {
        await _store.cancelJob(token, expectedApi: api);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.petCleanupFailed('$error'))),
          );
        }
      }
    }
  }

  void _discardDrafts() {
    _operationGeneration++;
    _jobApi = null;
    setState(() {
      _drafts = [];
      _selectedIndex = null;
      _token = null;
      _error = null;
      _phase = _Phase.intro;
    });
  }

  Future<void> _hatch() async {
    final token = _token;
    final index = _selectedIndex;
    final api = _jobApi;
    if (token == null || index == null || api == null) return;
    final generation = ++_operationGeneration;
    final defaultName = _cleanPetName(
      _promptCtrl.text.trim(),
      fallback: context.l10n.petUntitled,
    );
    _nameCtrl.text = defaultName;
    setState(() {
      _phase = _Phase.hatching;
      _hatchStage = null;
      _error = null;
    });
    try {
      final result = await _store.hatch({
        'token': token,
        'cancelToken': token,
        'index': index,
        'name': defaultName,
        'prompt': _promptCtrl.text.trim(),
        'style': 'auto',
        if ((_selectedProvider ?? '').isNotEmpty) 'provider': _selectedProvider,
      }, expectedApi: api);
      if (!mounted ||
          generation != _operationGeneration ||
          !identical(api, _store.activeApi)) {
        return;
      }
      final petJson = result['pet'];
      if (result['ok'] != true || petJson is! Map) {
        throw StateError(
          result['error']?.toString() ?? context.l10n.commonOperationFailed,
        );
      }
      final pet = PetInfo.fromJson(petJson.cast<String, dynamic>());
      setState(() {
        _previewPet = pet;
        _previewApi = api;
        _phase = _Phase.preview;
      });
    } catch (e) {
      if (!mounted || generation != _operationGeneration) return;
      setState(() => _phase = _Phase.ready);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.petGenerateHatchFailed('$e'))),
      );
    }
  }

  Future<void> _adopt() async {
    final pet = _previewPet;
    final slug = pet?.slug;
    final api = _previewApi;
    if (slug == null || api == null) return;
    setState(() => _busy = true);
    try {
      var finalSlug = slug;
      final name = _nameCtrl.text.trim();
      if (name.isNotEmpty && name != pet!.displayName) {
        _store.requireApi(api);
        finalSlug = await api.petRename(slug, name);
      }
      await _store.select(finalSlug, expectedApi: api);
      _store.requireApi(api);
      await _store.loadGallery();
      _adopted = true;
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.petGenerateAdoptFailed('$e'))),
      );
    }
  }

  Future<void> _discardPreview() async {
    final slug = _previewPet?.slug;
    final api = _previewApi;
    _operationGeneration++;
    setState(() {
      _previewPet = null;
      _previewApi = null;
      _phase = _drafts.isNotEmpty ? _Phase.ready : _Phase.intro;
    });
    if (slug != null && api != null) {
      try {
        await _store.remove(slug, expectedApi: api);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.petCleanupFailed('$error'))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.petGenerateTitle)),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.intro => _buildIntro(context),
          _Phase.generating => _buildGenerating(context),
          _Phase.ready => _buildReady(context),
          _Phase.hatching => _buildHatching(context),
          _Phase.preview => _buildPreview(context),
        },
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) ...[
          HermesGlassCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: HermesSemantic.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          context.l10n.petGenerateDescribe,
          style: HermesType.onSurface(HermesType.headline, theme),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _promptCtrl,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.l10n.petGeneratePromptHint,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (_referenceDataUri == null)
          OutlinedButton.icon(
            onPressed: _pickReferenceImage,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(context.l10n.petGenerateAddReference),
          )
        else
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                child: Image.memory(
                  base64Decode(_referenceDataUri!.split(',').last),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.petGenerateReferenceHelp,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonRemove,
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _referenceDataUri = null),
              ),
            ],
          ),
        if (_providers.length > 1) ...[
          const SizedBox(height: 16),
          Text(
            context.l10n.petGenerateModel,
            style: HermesType.onSurface(HermesType.callout, theme),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedProvider,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(context.l10n.petGenerateAutoSelect),
              ),
              for (final p in _providers)
                DropdownMenuItem(
                  value: p['name']?.toString(),
                  child: Text(
                    p['label']?.toString() ?? p['name']?.toString() ?? '',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _selectedProvider = v),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          key: const ValueKey('pet-generate-action'),
          onPressed: _generate,
          icon: const Icon(Icons.auto_awesome),
          label: Text(context.l10n.petGenerateDraftsAction),
        ),
      ],
    );
  }

  Widget _buildDraftGrid({required bool interactive}) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemCount: 4,
      itemBuilder: (context, i) {
        final draft = _drafts.where((d) => d.index == i).firstOrNull;
        final selected = interactive && _selectedIndex == i;
        final onTap = draft == null || !interactive
            ? null
            : () => setState(() => _selectedIndex = i);
        return Semantics(
          label: context.l10n.petGenerateDraftLabel(i + 1),
          image: true,
          button: onTap != null,
          selected: selected,
          enabled: draft != null,
          child: GestureDetector(
            excludeFromSemantics: true,
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(HermesRadius.card),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                  width: selected ? 3 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: draft == null
                  ? Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : draft.bytes == null
                  ? const Icon(Icons.broken_image_outlined)
                  : Image.memory(
                      draft.bytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGenerating(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            context.l10n.petGenerateProgress(_drafts.length, 4),
            style: HermesType.onSurface(HermesType.headline, Theme.of(context)),
          ),
        ),
        _buildDraftGrid(interactive: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton(
            onPressed: _cancelGenerate,
            child: Text(context.l10n.commonCancel),
          ),
        ),
      ],
    );
  }

  Widget _buildReady(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            context.l10n.petGenerateChooseDraft,
            style: HermesType.onSurface(HermesType.headline, Theme.of(context)),
          ),
        ),
        _buildDraftGrid(interactive: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _discardDrafts,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.petGenerateAgain),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _selectedIndex == null ? null : _hatch,
                  icon: const Icon(Icons.egg_outlined),
                  label: Text(context.l10n.petGenerateHatch),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _hatchStageLabel(BuildContext context) {
    final stage = _hatchStage;
    if (stage == null) return context.l10n.petGeneratePreparing;
    return switch (stage.phase) {
      'row' when stage.total != null => context.l10n.petGenerateDrawingProgress(
        stage.state ?? '',
        stage.done ?? 0,
        stage.total!,
      ),
      'row' => context.l10n.petGenerateDrawing(stage.state ?? ''),
      'compose' => context.l10n.petGenerateComposing,
      'save' => context.l10n.petGenerateSaving,
      _ => context.l10n.petGenerateHatching,
    };
  }

  Widget _buildHatching(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(_eggGlyph, style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(_hatchStageLabel(context), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () async {
                setState(() => _phase = _Phase.ready);
                final token = _token;
                if (token != null) {
                  try {
                    await _store.cancelJob(token);
                  } catch (error) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.l10n.petCleanupFailed('$error'),
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              child: Text(context.l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final theme = Theme.of(context);
    final pet = _previewPet;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.l10n.petGenerateReady,
          style: HermesType.onSurface(HermesType.headline, theme),
        ),
        const SizedBox(height: 16),
        Center(child: _HatchPreviewSprite(info: pet, size: 160)),
        const SizedBox(height: 24),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: context.l10n.petGenerateNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : _discardPreview,
                child: Text(context.l10n.petGenerateDiscard),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _adopt,
                icon: _busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.favorite_outline),
                label: Text(context.l10n.petGenerateAdopt),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Cycles through the hatched pet's idle-state frames for a lively reveal,
/// instead of the static first-frame thumbnail the pet center's gallery
/// uses — this is the one moment worth animating (desktop plays every frame
/// on the reveal screen too).
class _HatchPreviewSprite extends StatefulWidget {
  final PetInfo? info;
  final double size;
  const _HatchPreviewSprite({required this.info, required this.size});

  @override
  State<_HatchPreviewSprite> createState() => _HatchPreviewSpriteState();
}

class _HatchPreviewSpriteState extends State<_HatchPreviewSprite> {
  Timer? _timer;
  int _frame = 0;
  // Decoded once per `widget.info` and reused across every animation tick —
  // this widget used to re-run base64Decode on the whole spritesheet inside
  // build(), which the periodic timer (every 80-2000ms) turned into up to
  // ~12 redundant full decodes a second for as long as the reveal screen
  // was on screen.
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = _decode(widget.info?.spritesheetBase64);
    _startTimer();
  }

  @override
  void didUpdateWidget(_HatchPreviewSprite oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.info == widget.info) return;
    _bytes = _decode(widget.info?.spritesheetBase64);
    _frame = 0;
    _timer?.cancel();
    _startTimer();
  }

  void _startTimer() {
    final frameCount = widget.info?.framesByState['idle'] ?? 1;
    if (frameCount <= 1) return;
    final loopMs = widget.info?.loopMs ?? 600;
    final perFrame = (loopMs / frameCount).clamp(80, 2000).round();
    _timer = Timer.periodic(Duration(milliseconds: perFrame), (_) {
      if (!mounted) return;
      setState(() => _frame = (_frame + 1) % frameCount);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static Uint8List? _decode(String? b64) {
    if (b64 == null || b64.isEmpty) return null;
    try {
      final raw = b64.contains(',') ? b64.split(',').last : b64;
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    final bytes = _bytes;
    final frameW = info?.frameW;
    final frameH = info?.frameH;
    if (bytes == null ||
        frameW == null ||
        frameH == null ||
        frameW <= 0 ||
        frameH <= 0) {
      return Text(_pawGlyph, style: TextStyle(fontSize: widget.size * 0.5));
    }
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: frameW.toDouble(),
          height: frameH.toDouble(),
          child: ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: Offset(-(_frame * frameW).toDouble(), 0),
                child: Image.memory(
                  bytes,
                  gaplessPlayback: true,
                  errorBuilder: (context, error, stackTrace) => Text(
                    _pawGlyph,
                    style: TextStyle(fontSize: widget.size * 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
