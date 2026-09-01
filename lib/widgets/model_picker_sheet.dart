import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/model_catalog.dart';
import '../core/models.dart';
import '../l10n/l10n.dart';
import 'h/hermes_toast.dart';

class ModelPickerSheet extends StatefulWidget {
  final ApiClient api;
  final ModelCatalog initialCatalog;
  final ModelVisibilityStore visibilityStore;

  const ModelPickerSheet({
    super.key,
    required this.api,
    required this.initialCatalog,
    required this.visibilityStore,
  });

  @override
  State<ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends State<ModelPickerSheet> {
  late ModelCatalog _catalog = widget.initialCatalog;
  late Set<String> _visibleKeys = widget.visibilityStore.visibleKeys(
    widget.initialCatalog.providers,
  );
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final catalog = await widget.api.modelCatalog(refresh: true);
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _visibleKeys = widget.visibilityStore.visibleKeys(catalog.providers);
      });
    } catch (error) {
      if (mounted) {
        showHermesToast(
          context,
          message: context.l10n.modelPickerRefreshFailed('$error'),
          kind: HermesToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _editVisibility() async {
    final edited = Set<String>.from(_visibleKeys);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setEditor) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                ListTile(title: Text(context.l10n.modelPickerEdit)),
                Expanded(
                  child: ListView(
                    children: [
                      for (final provider in _catalog.providers)
                        _VisibilityProvider(
                          provider: provider,
                          selected: edited,
                          onChanged: () => setEditor(() {}),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.l10n.commonSave),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    try {
      await widget.visibilityStore.save(edited);
      if (mounted) setState(() => _visibleKeys = edited);
    } catch (error) {
      if (!mounted) return;
      showHermesToast(
        context,
        message: context.l10n.modelPickerVisibilitySaveFailed('$error'),
        kind: HermesToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final projection = _catalog.project(visibleModelKeys: _visibleKeys);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.modelChoose,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                children: [
                  for (final provider in projection.providers)
                    _ProviderModels(
                      provider: provider,
                      currentProvider: _catalog.currentProvider,
                      currentModel: _catalog.currentModel,
                    ),
                  if (projection.providers.every((p) => p.models.isEmpty) &&
                      projection.moaProviders.every((p) => p.models.isEmpty))
                    ListTile(title: Text(context.l10n.modelNoAvailable)),
                  if (projection.moaProviders.any(
                    (p) => p.models.isNotEmpty,
                  )) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                      child: Text(
                        context.l10n.modelPickerMoaPresets,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    for (final provider in projection.moaProviders)
                      for (final model in provider.models)
                        ListTile(
                          title: Text(context.l10n.modelPickerMoaModel(model)),
                          trailing:
                              provider.slug == _catalog.currentProvider &&
                                  model == _catalog.currentModel
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () =>
                              Navigator.pop(context, '${provider.slug}|$model'),
                        ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: context.l10n.modelPickerRefresh,
                  onPressed: _refreshing ? null : _refresh,
                  icon: _refreshing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: context.l10n.modelPickerEdit,
                  onPressed: _refreshing ? null : _editVisibility,
                  icon: const Icon(Icons.edit_outlined),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderModels extends StatelessWidget {
  final ModelInfo provider;
  final String? currentProvider;
  final String? currentModel;

  const _ProviderModels({
    required this.provider,
    required this.currentProvider,
    required this.currentModel,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.models.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text(provider.name),
      initiallyExpanded: provider.slug == currentProvider,
      children: [
        for (final model in provider.models)
          ListTile(
            title: Text(model),
            subtitle: _ModelPriceLabel(price: provider.pricing[model]),
            trailing: provider.slug == currentProvider && model == currentModel
                ? const Icon(Icons.check)
                : provider.pricing[model]?.free == true
                ? const Icon(Icons.star, color: Colors.amber)
                : null,
            onTap: () => Navigator.pop(context, '${provider.slug}|$model'),
          ),
      ],
    );
  }
}

class _ModelPriceLabel extends StatelessWidget {
  final ModelPricing? price;
  const _ModelPriceLabel({required this.price});

  @override
  Widget build(BuildContext context) {
    final value = price;
    if (value == null) return const SizedBox.shrink();
    if (value.free) {
      return Text(
        value.discountPercent == null
            ? context.l10n.modelPickerFree
            : context.l10n.modelPickerFreeDiscount(value.discountPercent!),
        style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
      );
    }
    if (value.input.isEmpty && value.output.isEmpty) {
      return const SizedBox.shrink();
    }
    final discount = value.discountPercent == null
        ? ''
        : ' · -${value.discountPercent}%';
    return Text(
      context.l10n.modelPickerPricing(
        value.input.isEmpty ? '?' : value.input,
        value.output.isEmpty ? '?' : value.output,
        discount,
      ),
    );
  }
}

class _VisibilityProvider extends StatelessWidget {
  final ModelInfo provider;
  final Set<String> selected;
  final VoidCallback onChanged;

  const _VisibilityProvider({
    required this.provider,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final keys = provider.models
        .map((model) => ModelCatalog.modelKey(provider.slug, model))
        .toSet();
    final allSelected = keys.isNotEmpty && selected.containsAll(keys);
    return ExpansionTile(
      title: Text(provider.name),
      trailing: TextButton(
        onPressed: () {
          if (allSelected) {
            selected.removeAll(keys);
          } else {
            selected.addAll(keys);
          }
          onChanged();
        },
        child: Text(
          allSelected
              ? context.l10n.modelPickerSelectNone
              : context.l10n.modelPickerSelectAll,
        ),
      ),
      children: [
        for (final model in provider.models)
          CheckboxListTile(
            title: Text(model),
            value: selected.contains(
              ModelCatalog.modelKey(provider.slug, model),
            ),
            onChanged: (value) {
              final key = ModelCatalog.modelKey(provider.slug, model);
              value == true ? selected.add(key) : selected.remove(key);
              onChanged();
            },
          ),
      ],
    );
  }
}
