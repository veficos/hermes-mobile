library;

import 'package:flutter/widgets.dart';

enum MobileContributionViewType { action, form, list }

enum MobilePluginFieldType { text, multiline, number, boolean, select, secret }

class MobilePluginOption {
  final Object? value;
  final String label;
  final String? labelKey;

  const MobilePluginOption({
    required this.value,
    required this.label,
    this.labelKey,
  });

  factory MobilePluginOption.fromJson(Object? raw) {
    if (raw is Map) {
      final json = raw.cast<Object?, Object?>();
      return MobilePluginOption(
        value: json['value'],
        label: (json['label'] ?? json['value'] ?? '').toString(),
        labelKey: json['label_key']?.toString(),
      );
    }
    return MobilePluginOption(value: raw, label: raw?.toString() ?? '');
  }
}

class MobilePluginField {
  final String id;
  final String label;
  final String? labelKey;
  final String description;
  final String? descriptionKey;
  final MobilePluginFieldType type;
  final bool required;
  final Object? defaultValue;
  final List<MobilePluginOption> options;
  final num? min;
  final num? max;

  const MobilePluginField({
    required this.id,
    required this.label,
    this.labelKey,
    this.description = '',
    this.descriptionKey,
    this.type = MobilePluginFieldType.text,
    this.required = false,
    this.defaultValue,
    this.options = const [],
    this.min,
    this.max,
  });

  factory MobilePluginField.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().trim().toLowerCase() ?? 'text';
    final type = MobilePluginFieldType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => MobilePluginFieldType.text,
    );
    final options = (json['options'] as List? ?? const [])
        .take(100)
        .map(MobilePluginOption.fromJson)
        .where((option) => option.label.trim().isNotEmpty)
        .toList(growable: false);
    return MobilePluginField(
      id: json['id']?.toString().trim() ?? '',
      label: json['label']?.toString().trim() ?? '',
      labelKey: json['label_key']?.toString().trim(),
      description: json['description']?.toString().trim() ?? '',
      descriptionKey: json['description_key']?.toString().trim(),
      type: type,
      required: json['required'] == true,
      defaultValue: json['default'],
      options: options,
      min: json['min'] as num?,
      max: json['max'] as num?,
    );
  }

  bool get valid =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$').hasMatch(id) &&
      (label.isNotEmpty || labelKey?.isNotEmpty == true) &&
      (type != MobilePluginFieldType.select || options.isNotEmpty);
}

class MobilePluginViewAction {
  final String id;
  final String title;
  final String? titleKey;
  final String description;
  final String? descriptionKey;
  final String? confirmTitle;
  final String? confirmTitleKey;
  final String? confirmMessage;
  final String? confirmMessageKey;
  final String? tone;
  final bool primary;
  final Map<String, dynamic> action;

  const MobilePluginViewAction({
    required this.id,
    required this.title,
    this.titleKey,
    this.description = '',
    this.descriptionKey,
    this.confirmTitle,
    this.confirmTitleKey,
    this.confirmMessage,
    this.confirmMessageKey,
    this.tone,
    this.primary = false,
    required this.action,
  });

  factory MobilePluginViewAction.fromJson(Map<String, dynamic> json) =>
      MobilePluginViewAction(
        id: json['id']?.toString().trim() ?? '',
        title: json['title']?.toString().trim() ?? '',
        titleKey: json['title_key']?.toString().trim(),
        description: json['description']?.toString().trim() ?? '',
        descriptionKey: json['description_key']?.toString().trim(),
        confirmTitle: json['confirm_title']?.toString().trim(),
        confirmTitleKey: json['confirm_title_key']?.toString().trim(),
        confirmMessage: json['confirm_message']?.toString().trim(),
        confirmMessageKey: json['confirm_message_key']?.toString().trim(),
        tone: json['tone']?.toString().trim().toLowerCase(),
        primary: json['primary'] == true,
        action: (json['action'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  bool get valid =>
      RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$').hasMatch(id) &&
      (title.isNotEmpty || titleKey?.isNotEmpty == true) &&
      action.isNotEmpty;
}

class MobilePluginView {
  final MobileContributionViewType type;
  final List<MobilePluginField> fields;
  final Map<String, dynamic>? loadAction;
  final Map<String, dynamic>? submitAction;
  final List<MobilePluginViewAction> actions;
  final int? pollSeconds;
  final String? socketPath;
  final bool persistInputs;
  final String itemsKey;
  final String itemTitleKey;
  final String itemSubtitleKey;
  final String emptyMessage;
  final String? emptyMessageKey;

  const MobilePluginView({
    this.type = MobileContributionViewType.action,
    this.fields = const [],
    this.loadAction,
    this.submitAction,
    this.actions = const [],
    this.pollSeconds,
    this.socketPath,
    this.persistInputs = false,
    this.itemsKey = 'items',
    this.itemTitleKey = 'title',
    this.itemSubtitleKey = 'subtitle',
    this.emptyMessage = '',
    this.emptyMessageKey,
  });

  factory MobilePluginView.fromJson(Object? raw) {
    if (raw is! Map) return const MobilePluginView();
    final json = raw.cast<String, dynamic>();
    final rawType = json['type']?.toString().trim().toLowerCase() ?? 'action';
    final type = MobileContributionViewType.values.firstWhere(
      (value) => value.name == rawType,
      orElse: () => MobileContributionViewType.action,
    );
    final fields = (json['fields'] as List? ?? const [])
        .take(64)
        .whereType<Map>()
        .map((item) => MobilePluginField.fromJson(item.cast<String, dynamic>()))
        .where((field) => field.valid)
        .toList(growable: false);
    final actions = (json['actions'] as List? ?? const [])
        .take(32)
        .whereType<Map>()
        .map(
          (item) =>
              MobilePluginViewAction.fromJson(item.cast<String, dynamic>()),
        )
        .where((action) => action.valid)
        .toList(growable: false);
    final rawPoll = (json['poll_seconds'] as num?)?.toInt();
    return MobilePluginView(
      type: type,
      fields: fields,
      loadAction: (json['load_action'] as Map?)?.cast<String, dynamic>(),
      submitAction: (json['submit_action'] as Map?)?.cast<String, dynamic>(),
      actions: actions,
      pollSeconds: rawPoll?.clamp(5, 3600),
      socketPath: _safePath(json['socket_path']),
      persistInputs: json['persist_inputs'] == true,
      itemsKey: _safeKey(json['items_key'], 'items'),
      itemTitleKey: _safeKey(json['item_title_key'], 'title'),
      itemSubtitleKey: _safeKey(json['item_subtitle_key'], 'subtitle'),
      emptyMessage: json['empty_message']?.toString().trim() ?? '',
      emptyMessageKey: json['empty_message_key']?.toString().trim(),
    );
  }

  static String _safeKey(Object? raw, String fallback) {
    final value = raw?.toString().trim() ?? '';
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$').hasMatch(value)
        ? value
        : fallback;
  }

  static String? _safePath(Object? raw) {
    final value = raw?.toString().trim().replaceFirst(RegExp(r'^/+'), '') ?? '';
    if (value.isEmpty || value.length > 512) return null;
    final segments = value.split('/');
    return segments.every(
          (segment) =>
              RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,159}$').hasMatch(segment),
        )
        ? value
        : null;
  }
}

class PluginLocaleBundle {
  final Map<String, Map<String, String>> values;

  const PluginLocaleBundle(this.values);

  factory PluginLocaleBundle.fromJson(Object? raw) {
    if (raw is! Map) return const PluginLocaleBundle({});
    final bundles = <String, Map<String, String>>{};
    for (final localeEntry in raw.entries.take(16)) {
      final tag = _normalizeTag(localeEntry.key.toString());
      final messages = localeEntry.value;
      if (tag.isEmpty || messages is! Map) continue;
      final normalized = <String, String>{};
      for (final message in messages.entries.take(512)) {
        final key = message.key.toString().trim();
        final value = message.value?.toString() ?? '';
        if (RegExp(r'^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$').hasMatch(key) &&
            value.isNotEmpty &&
            value.length <= 4000) {
          normalized[key] = value;
        }
      }
      if (normalized.isNotEmpty) bundles[tag] = Map.unmodifiable(normalized);
    }
    return PluginLocaleBundle(Map.unmodifiable(bundles));
  }

  String resolve(Locale locale, String? key, String fallback) {
    if (key == null || key.isEmpty) return fallback;
    final exact = _normalizeTag(locale.toLanguageTag());
    final language = _normalizeTag(locale.languageCode);
    return values[exact]?[key] ??
        values[language]?[key] ??
        values['en']?[key] ??
        fallback;
  }

  static String _normalizeTag(String raw) =>
      raw.trim().replaceAll('_', '-').toLowerCase();
}
