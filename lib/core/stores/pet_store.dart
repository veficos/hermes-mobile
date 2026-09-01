/// PetStore: desktop pet system adapted for mobile (in-app floating widget).
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../gateway.dart';
import '../models.dart';
import '../../l10n/runtime_l10n.dart';
import 'connection_store.dart';

enum PetState { idle, wave, run, failed, jump, waiting, celebrate }

class PetStore extends ChangeNotifier {
  final ConnectionStore connection;
  PetStore({required this.connection}) {
    _sub = connection.events.listen(_onEvent);
    _api = connection.api;
    connection.addListener(_onConnectionChanged);
  }

  PetInfo? _info;
  List<PetGalleryEntry> _gallery = [];
  bool _loading = false;
  PetState _state = PetState.idle;
  String? _error;

  PetInfo? get info => _info;
  List<PetGalleryEntry> get gallery => _gallery;
  bool get loading => _loading;
  PetState get state => _state;
  String? get error => _error;
  bool get enabled => _info?.enabled == true;

  StreamSubscription? _sub;
  ApiClient? _api;
  int _generation = 0;
  int _stateEpoch = 0;

  ApiClient requireApi([ApiClient? expected]) {
    final api = connection.api;
    if (api != null && (expected == null || identical(api, expected))) {
      return api;
    }
    throw StateError(runtimeL10n.backendDisconnected);
  }

  ApiClient? get activeApi => connection.api;

  void _onConnectionChanged() {
    final api = connection.api;
    if (identical(api, _api)) return;
    _api = api;
    _generation++;
    _info = null;
    _gallery = const [];
    _loading = false;
    _error = null;
    _state = PetState.idle;
    _stateEpoch++;
    notifyListeners();
    if (api != null) unawaited(refresh());
  }

  void _onEvent(GatewayEvent e) {
    if (e.type == 'pet.changed') {
      refresh();
    } else if (e.type == 'message.start' || e.type == 'message.delta') {
      _updateState(busy: true);
    } else if (e.type == 'message.complete') {
      final generation = _generation;
      final status = e.payload['status'];
      if (status == 'error') {
        _updateState(error: true);
      } else {
        _updateState(justCompleted: true);
      }
      final stateEpoch = _stateEpoch;
      Future.delayed(const Duration(seconds: 3), () {
        if (generation == _generation && stateEpoch == _stateEpoch) {
          _updateState(busy: false);
        }
      });
    } else if (e.type == 'error') {
      final generation = _generation;
      _updateState(error: true);
      final stateEpoch = _stateEpoch;
      Future.delayed(const Duration(seconds: 3), () {
        if (generation == _generation && stateEpoch == _stateEpoch) {
          _updateState(busy: false);
        }
      });
    } else if (e.type == 'interactive.expire' ||
        e.type == 'interactive.expired') {
      _updateState(busy: false);
    } else if (e.type == 'approval.request' ||
        e.type == 'clarify.request' ||
        e.type == 'sudo.request' ||
        e.type == 'secret.request') {
      _updateState(awaitingInput: true);
    }
  }

  void _updateState({
    bool? busy,
    bool? awaitingInput,
    bool? error,
    bool? justCompleted,
  }) {
    _stateEpoch++;
    if (error == true) {
      _state = PetState.failed;
    } else if (justCompleted == true) {
      _state = PetState.celebrate;
    } else if (awaitingInput == true) {
      _state = PetState.waiting;
    } else if (busy == true) {
      _state = PetState.run;
    } else {
      _state = PetState.idle;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    final api = connection.api;
    if (api == null) return;
    final generation = ++_generation;
    _loading = true;
    notifyListeners();
    try {
      final info = await api.petInfo();
      if (generation != _generation || !identical(api, connection.api)) return;
      _info = info;
      _error = null;
    } catch (e) {
      if (generation != _generation || !identical(api, connection.api)) return;
      _error = e.toString();
    } finally {
      if (generation == _generation && identical(api, connection.api)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadGallery() async {
    final api = connection.api;
    if (api == null) return;
    final generation = _generation;
    try {
      final gallery = await api.petGallery();
      if (generation != _generation || !identical(api, connection.api)) return;
      _gallery = gallery;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> select(String slug, {ApiClient? expectedApi}) async {
    final api = requireApi(expectedApi);
    await api.petSelect(slug);
    requireApi(api);
    await refresh();
  }

  Future<void> disable({ApiClient? expectedApi}) async {
    final api = requireApi(expectedApi);
    await api.petDisable();
    requireApi(api);
    _info = null;
    notifyListeners();
  }

  Future<void> rename(String name, {ApiClient? expectedApi}) async {
    final slug = _info?.slug;
    if (slug == null) return;
    final api = requireApi(expectedApi);
    await api.petRename(slug, name);
    requireApi(api);
    await refresh();
  }

  Future<Map<String, dynamic>> generate(
    Map<String, dynamic> args, {
    ApiClient? expectedApi,
  }) async {
    return requireApi(expectedApi).petGenerate(args);
  }

  Future<Map<String, dynamic>> generateStatus({ApiClient? expectedApi}) async {
    return requireApi(expectedApi).petGenerateStatus();
  }

  Future<Map<String, dynamic>> hatch(
    Map<String, dynamic> args, {
    ApiClient? expectedApi,
  }) async {
    return requireApi(expectedApi).petHatch(args);
  }

  Future<void> cancelJob(String token, {ApiClient? expectedApi}) async {
    await requireApi(expectedApi).petCancel(token);
  }

  Future<void> remove(String slug, {ApiClient? expectedApi}) async {
    await requireApi(expectedApi).petRemove(slug);
  }

  /// Briefly show the celebrate state, then return to idle.
  void celebrate() {
    final generation = _generation;
    _updateState(justCompleted: true);
    Future.delayed(const Duration(seconds: 2), () {
      if (generation == _generation) _updateState(busy: false);
    });
  }

  @override
  void dispose() {
    connection.removeListener(_onConnectionChanged);
    _sub?.cancel();
    super.dispose();
  }
}
