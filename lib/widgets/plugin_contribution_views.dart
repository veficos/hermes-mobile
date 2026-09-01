library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/plugin_contributions.dart';
import '../core/stores/plugin_contribution_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import 'plugin_contribution_surface.dart';

Future<void> showPluginContributionView(
  BuildContext context,
  PluginContributionStore store,
  MobilePluginContribution contribution,
) async {
  switch (contribution.view.type) {
    case MobileContributionViewType.action:
      final raw = await store.invoke(contribution);
      if (!context.mounted) return;
      await showPluginActionResult(context, contribution, raw);
    case MobileContributionViewType.form:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) =>
            _PluginFormSheet(store: store, contribution: contribution),
      );
    case MobileContributionViewType.list:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) =>
            _PluginListSheet(store: store, contribution: contribution),
      );
  }
}

/// Persistent workspace form of a declarative plugin contribution. The host
/// owns every widget and action dispatch; plugins only supply bounded data.
class PluginContributionPane extends StatelessWidget {
  const PluginContributionPane({
    super.key,
    required this.store,
    required this.contribution,
  });

  final PluginContributionStore store;
  final MobilePluginContribution contribution;

  @override
  Widget build(BuildContext context) => switch (contribution.view.type) {
    MobileContributionViewType.action => _PluginActionPane(
      store: store,
      contribution: contribution,
    ),
    MobileContributionViewType.form => _PluginFormSheet(
      store: store,
      contribution: contribution,
      embedded: true,
    ),
    MobileContributionViewType.list => _PluginListSheet(
      store: store,
      contribution: contribution,
      embedded: true,
    ),
  };
}

class _PluginActionPane extends StatefulWidget {
  const _PluginActionPane({required this.store, required this.contribution});

  final PluginContributionStore store;
  final MobilePluginContribution contribution;

  @override
  State<_PluginActionPane> createState() => _PluginActionPaneState();
}

class _PluginActionPaneState extends State<_PluginActionPane> {
  bool _running = false;
  String? _error;
  PluginActionResult? _result;

  Future<void> _run() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final raw = await widget.store.invoke(widget.contribution);
      if (mounted) setState(() => _result = PluginActionResult.fromJson(raw));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contribution = widget.contribution;
    final locale = Localizations.localeOf(context);
    final result = _result;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SheetHeader(title: contribution.localizedTitle(locale)),
        if (contribution.localizedDescription(locale).isNotEmpty) ...[
          Text(contribution.localizedDescription(locale)),
          const SizedBox(height: 20),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: _running
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow, size: 18),
            label: Text(
              _running
                  ? context.l10n.commonRunning
                  : contribution.localizedTitle(locale),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: _error!),
        ],
        if (result?.shouldPresent == true) ...[
          const SizedBox(height: 20),
          if (result!.title case final title?)
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (result.message case final message?) ...[
            const SizedBox(height: 8),
            SelectableText(message),
          ],
          for (final field in result.fields)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(field.label),
              subtitle: SelectableText(field.value),
            ),
          if (result.items.isNotEmpty) SelectableText(result.items.join('\n')),
        ],
      ],
    );
  }
}

String _localized(
  BuildContext context,
  MobilePluginContribution contribution,
  String? key,
  String fallback,
) => contribution.localize(Localizations.localeOf(context), key, fallback);

Object? _path(Object? value, String path) {
  Object? current = value;
  for (final segment in path.split('.')) {
    if (current is! Map) return null;
    current = current[segment];
  }
  return current;
}

class _PluginFormSheet extends StatefulWidget {
  final PluginContributionStore store;
  final MobilePluginContribution contribution;
  final bool embedded;

  const _PluginFormSheet({
    required this.store,
    required this.contribution,
    this.embedded = false,
  });

  @override
  State<_PluginFormSheet> createState() => _PluginFormSheetState();
}

class _PluginFormSheetState extends State<_PluginFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Object?> _values = {};
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  MobilePluginContribution get contribution => widget.contribution;
  MobilePluginView get view => contribution.view;

  @override
  void initState() {
    super.initState();
    for (final field in view.fields) {
      _values[field.id] = field.defaultValue;
      if (field.type != MobilePluginFieldType.boolean &&
          field.type != MobilePluginFieldType.select) {
        _controllers[field.id] = TextEditingController(
          text: field.defaultValue?.toString() ?? '',
        );
      }
    }
    unawaited(_load());
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final persisted = view.persistInputs
          ? await widget.store.readStorage(contribution, 'form-inputs')
          : const <String, dynamic>{};
      Map<String, dynamic> loaded = const {};
      if (view.loadAction != null) {
        final result = await widget.store.loadView(contribution);
        final candidate = result['values'] ?? result['inputs'];
        if (candidate is Map) loaded = candidate.cast<String, dynamic>();
      }
      if (!mounted) return;
      _applyValues({...persisted, ...loaded});
    } catch (error) {
      if (mounted) _error = '$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyValues(Map<String, dynamic> values) {
    for (final field in view.fields) {
      if (!values.containsKey(field.id)) continue;
      final value = values[field.id];
      _values[field.id] = value;
      _controllers[field.id]?.text = value?.toString() ?? '';
    }
  }

  Map<String, dynamic> _collect() {
    final result = <String, dynamic>{};
    for (final field in view.fields) {
      Object? value;
      switch (field.type) {
        case MobilePluginFieldType.boolean || MobilePluginFieldType.select:
          value = _values[field.id];
        case MobilePluginFieldType.number:
          value = num.tryParse(_controllers[field.id]?.text.trim() ?? '');
        case MobilePluginFieldType.text ||
            MobilePluginFieldType.multiline ||
            MobilePluginFieldType.secret:
          value = _controllers[field.id]?.text.trim() ?? '';
      }
      result[field.id] = value;
    }
    return result;
  }

  String? _validateText(MobilePluginField field, String? raw) {
    final text = raw?.trim() ?? '';
    if (field.required && text.isEmpty) return context.l10n.pluginFieldRequired;
    if (field.type != MobilePluginFieldType.number || text.isEmpty) return null;
    final value = num.tryParse(text);
    if (value == null) return context.l10n.pluginFieldInvalidNumber;
    if (field.min != null && value < field.min!) {
      return context.l10n.pluginFieldMinimum(field.min!);
    }
    if (field.max != null && value > field.max!) {
      return context.l10n.pluginFieldMaximum(field.max!);
    }
    return null;
  }

  Future<bool> _confirm(MobilePluginViewAction action) async {
    final message = _localized(
      context,
      contribution,
      action.confirmMessageKey,
      action.confirmMessage ?? '',
    );
    if (message.isEmpty) return true;
    final title = _localized(
      context,
      contribution,
      action.confirmTitleKey,
      action.confirmTitle ?? action.title,
    );
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.commonConfirm),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _run(
    Map<String, dynamic> action, {
    MobilePluginViewAction? descriptor,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    if (descriptor != null && !await _confirm(descriptor)) return;
    if (!mounted) return;
    final inputs = _collect();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await widget.store.invokeAction(
        contribution,
        action,
        inputs: inputs,
      );
      if (view.persistInputs) {
        await widget.store.writeStorage(contribution, 'form-inputs', inputs);
      }
      if (!mounted) return;
      await showPluginActionResult(context, contribution, result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final title = contribution.localizedTitle(locale);
    Widget content(ScrollController? scrollController) => Form(
      key: _formKey,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(16, widget.embedded ? 16 : 0, 16, 24),
        children: [
          _SheetHeader(title: title),
          if (contribution.localizedDescription(locale).isNotEmpty) ...[
            Text(contribution.localizedDescription(locale)),
            const SizedBox(height: 16),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            for (final field in view.fields) ...[
              _field(field),
              const SizedBox(height: 14),
            ],
            if (_error != null) ...[
              _InlineError(message: _error!),
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                for (final action in view.actions)
                  _ActionButton(
                    action: action,
                    contribution: contribution,
                    busy: _submitting,
                    onPressed: () => _run(action.action, descriptor: action),
                  ),
                if (view.submitAction != null)
                  FilledButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => _run(view.submitAction!),
                    icon: _submitting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(context.l10n.pluginSubmit),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
    if (widget.embedded) return content(null);
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => content(scrollController),
    );
  }

  Widget _field(MobilePluginField field) {
    final label = _localized(
      context,
      contribution,
      field.labelKey,
      field.label,
    );
    final description = _localized(
      context,
      contribution,
      field.descriptionKey,
      field.description,
    );
    switch (field.type) {
      case MobilePluginFieldType.boolean:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: description.isEmpty ? null : Text(description),
          value: _values[field.id] == true,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _values[field.id] = value),
        );
      case MobilePluginFieldType.select:
        final current =
            field.options.any((option) => option.value == _values[field.id])
            ? _values[field.id]
            : null;
        return DropdownButtonFormField<Object?>(
          initialValue: current,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            helperText: description.isEmpty ? null : description,
          ),
          items: [
            for (final option in field.options)
              DropdownMenuItem<Object?>(
                value: option.value,
                child: Text(
                  _localized(
                    context,
                    contribution,
                    option.labelKey,
                    option.label,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          validator: (value) => field.required && value == null
              ? context.l10n.pluginFieldRequired
              : null,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _values[field.id] = value),
        );
      case MobilePluginFieldType.text ||
          MobilePluginFieldType.multiline ||
          MobilePluginFieldType.number ||
          MobilePluginFieldType.secret:
        return TextFormField(
          controller: _controllers[field.id],
          obscureText: field.type == MobilePluginFieldType.secret,
          maxLines: field.type == MobilePluginFieldType.multiline ? 5 : 1,
          minLines: field.type == MobilePluginFieldType.multiline ? 3 : 1,
          keyboardType: field.type == MobilePluginFieldType.number
              ? const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                )
              : field.type == MobilePluginFieldType.multiline
              ? TextInputType.multiline
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            helperText: description.isEmpty ? null : description,
            alignLabelWithHint: field.type == MobilePluginFieldType.multiline,
          ),
          validator: (value) => _validateText(field, value),
        );
    }
  }
}

class _PluginListSheet extends StatefulWidget {
  final PluginContributionStore store;
  final MobilePluginContribution contribution;
  final bool embedded;

  const _PluginListSheet({
    required this.store,
    required this.contribution,
    this.embedded = false,
  });

  @override
  State<_PluginListSheet> createState() => _PluginListSheetState();
}

class _PluginListSheetState extends State<_PluginListSheet> {
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.store.loadView(widget.contribution);
    } catch (error) {
      if (mounted) _error = '$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _items() {
    final data = widget.store.viewData[widget.contribution.namespacedId];
    final raw = _path(data, widget.contribution.view.itemsKey);
    return raw is List
        ? raw
              .take(500)
              .whereType<Map>()
              .map((item) => item.cast<String, dynamic>())
              .toList(growable: false)
        : const [];
  }

  @override
  Widget build(BuildContext context) {
    final contribution = widget.contribution;
    final locale = Localizations.localeOf(context);
    Widget content(ScrollController? scrollController) => AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final items = _items();
        return CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _SheetHeader(
                        title: contribution.localizedTitle(locale),
                      ),
                    ),
                    IconButton(
                      tooltip: context.l10n.commonRefresh,
                      onPressed: _loading ? null : _refresh,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading && items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _InlineError(message: _error!),
                ),
              )
            else if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _localized(
                      context,
                      contribution,
                      contribution.view.emptyMessageKey,
                      contribution.view.emptyMessage.isEmpty
                          ? context.l10n.pluginNoItems
                          : contribution.view.emptyMessage,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final title =
                        _path(
                          item,
                          contribution.view.itemTitleKey,
                        )?.toString() ??
                        context.l10n.pluginItemFallback(index + 1);
                    final subtitle = _path(
                      item,
                      contribution.view.itemSubtitleKey,
                    )?.toString();
                    return ListTile(
                      title: Text(title),
                      subtitle: subtitle?.isNotEmpty == true
                          ? Text(
                              subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showItem(item, title),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
    if (widget.embedded) return content(null);
    return DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => content(scrollController),
    );
  }

  Future<void> _showItem(Map<String, dynamic> item, String title) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PluginItemSheet(
        store: widget.store,
        contribution: widget.contribution,
        item: item,
        title: title,
        onChanged: _refresh,
      ),
    );
  }
}

class _PluginItemSheet extends StatefulWidget {
  final PluginContributionStore store;
  final MobilePluginContribution contribution;
  final Map<String, dynamic> item;
  final String title;
  final Future<void> Function() onChanged;

  const _PluginItemSheet({
    required this.store,
    required this.contribution,
    required this.item,
    required this.title,
    required this.onChanged,
  });

  @override
  State<_PluginItemSheet> createState() => _PluginItemSheetState();
}

class _PluginItemSheetState extends State<_PluginItemSheet> {
  bool _running = false;
  String? _error;

  Future<void> _run(MobilePluginViewAction descriptor) async {
    final message = _localized(
      context,
      widget.contribution,
      descriptor.confirmMessageKey,
      descriptor.confirmMessage ?? '',
    );
    if (message.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _localized(
              context,
              widget.contribution,
              descriptor.confirmTitleKey,
              descriptor.confirmTitle ?? descriptor.title,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.commonConfirm),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await widget.store.invokeAction(
        widget.contribution,
        descriptor.action,
        itemData: widget.item,
      );
      await widget.onChanged();
      if (!mounted) return;
      await showPluginActionResult(context, widget.contribution, result);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.38,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          _SheetHeader(title: widget.title),
          for (final entry in widget.item.entries) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: palette.text3),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(entry.value?.toString() ?? ''),
                ],
              ),
            ),
            Divider(color: palette.border, height: 1),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _InlineError(message: _error!),
          ],
          if (widget.contribution.view.actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final action in widget.contribution.view.actions)
                  _ActionButton(
                    action: action,
                    contribution: widget.contribution,
                    busy: _running,
                    onPressed: () => _run(action),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final MobilePluginViewAction action;
  final MobilePluginContribution contribution;
  final bool busy;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.action,
    required this.contribution,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final title = _localized(
      context,
      contribution,
      action.titleKey,
      action.title,
    );
    if (action.primary) {
      return FilledButton(
        onPressed: busy ? null : onPressed,
        child: Text(title),
      );
    }
    return action.tone == 'danger'
        ? OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: busy ? null : onPressed,
            child: Text(title),
          )
        : OutlinedButton(
            onPressed: busy ? null : onPressed,
            child: Text(title),
          );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;

  const _SheetHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
    ),
  );
}
