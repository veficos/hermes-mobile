/// Extracted from lib/screens/chat_screen.dart (pure structural move,
/// no behavior change).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/connection_reload_mixin.dart';
import '../../core/model_catalog.dart';
import '../../core/stores/connection_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/h/hermes_toast.dart';
import '../../widgets/h/hermes_states.dart';
import '../../widgets/mobile/mobile_page_scaffold.dart';
import '../../widgets/model_picker_sheet.dart';

Future<void> showChatModelPicker(BuildContext context) async {
  final session = context.read<SessionStore>();
  final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
  if (api == null) return;
  final runtimeId = session.runtimeId;
  ModelCatalog catalog;
  try {
    catalog = await api.modelCatalog();
  } catch (e) {
    if (context.mounted && identical(api, session.api)) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatModelsLoadFailed('$e'),
      );
    }
    return;
  }
  if (!context.mounted ||
      !identical(api, session.api) ||
      runtimeId != session.runtimeId) {
    return;
  }
  final info = session.info;
  final currentProvider = info?.provider?.trim() ?? '';
  final currentModel = info?.model?.trim() ?? '';
  if (currentProvider.isNotEmpty && currentModel.isNotEmpty) {
    catalog = catalog.copyWithCurrent(
      currentProvider: currentProvider,
      currentModel: currentModel,
    );
  }
  final preferences = await SharedPreferences.getInstance();
  if (!context.mounted ||
      !identical(api, session.api) ||
      runtimeId != session.runtimeId) {
    return;
  }
  final selected = await showMobileSheet<String>(
    context,
    (_) => ModelPickerSheet(
      api: api,
      initialCatalog: catalog,
      visibilityStore: ModelVisibilityStore(preferences),
    ),
  );
  if (selected == null) return;
  if (!context.mounted ||
      !identical(api, session.api) ||
      runtimeId != session.runtimeId) {
    return;
  }
  final idx = selected.indexOf('|');
  final provider = idx < 0 ? selected : selected.substring(0, idx);
  final model = idx < 0 ? selected : selected.substring(idx + 1);
  try {
    final result = await session.switchCurrentModel(provider, model);
    if (!context.mounted ||
        !identical(api, session.api) ||
        runtimeId != session.runtimeId) {
      return;
    }
    final applied = result['applied']?.toString() ?? 'now';
    if (applied == 'deferred') {
      showHermesToast(context, message: context.l10n.chatModelSwitchDeferred);
    }
  } catch (e) {
    if (context.mounted &&
        identical(api, session.api) &&
        runtimeId == session.runtimeId) {
      showHermesErrorSnackBar(
        context,
        e,
        fallback: context.l10n.chatModelSwitchFailed('$e'),
      );
    }
  }
}
