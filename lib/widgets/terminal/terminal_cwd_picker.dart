/// Shared directory picker sheet for "open terminal in folder".
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/connection_reload_mixin.dart';
import '../../core/models.dart';
import '../../core/server_path.dart';
import '../../core/stores/session_store.dart';
import '../../core/stores/connection_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_states.dart';

Future<String?> showTerminalCwdPicker(
  BuildContext context, {
  required String startPath,
}) async {
  final api = context.read<SessionStore>().api;
  if (api == null) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
    return null;
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(HermesRadius.sheet),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => _TerminalCwdPicker(
        startPath: startPath,
        scrollController: scrollCtrl,
        api: api,
      ),
    ),
  );
}

class _TerminalCwdPicker extends StatefulWidget {
  final String startPath;
  final ScrollController scrollController;
  final ApiClient api;

  const _TerminalCwdPicker({
    required this.startPath,
    required this.scrollController,
    required this.api,
  });

  @override
  State<_TerminalCwdPicker> createState() => _TerminalCwdPickerState();
}

class _TerminalCwdPickerState extends State<_TerminalCwdPicker>
    with ConnectionReloadMixin<_TerminalCwdPicker> {
  String _path = '';
  List<FsEntry> _entries = [];
  bool _loading = true;
  String? _error;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _path = widget.startPath;
    _load(_path);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _connectionChanged);
  }

  void _connectionChanged() {
    if (!mounted || identical(widget.api, context.read<SessionStore>().api)) {
      return;
    }
    ++_loadGeneration;
    setState(() {
      _entries = const [];
      _loading = false;
      _error = context.l10n.backendDisconnected;
    });
  }

  @override
  void dispose() {
    ++_loadGeneration;
    disposeConnectionObserver();
    super.dispose();
  }

  Future<void> _load(String path) async {
    final generation = ++_loadGeneration;
    final api = widget.api;
    setState(() {
      _path = path;
      _loading = true;
      _error = null;
    });
    try {
      final entries = await api.fsList(path);
      if (mounted &&
          generation == _loadGeneration &&
          path == _path &&
          identical(api, context.read<SessionStore>().api)) {
        setState(() {
          _entries = entries;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          path == _path &&
          identical(api, context.read<SessionStore>().api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _path.isEmpty ? '/' : _path,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: context.l10n.newSessionParentDirectory,
                icon: const Icon(Icons.arrow_upward),
                onPressed: _path.isEmpty || ServerPath.isPosixRoot(_path)
                    ? null
                    : () {
                        final up = ServerPath.parent(_path);
                        _load(up.isEmpty ? '/' : up);
                      },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loading
              ? HermesLoadingState(label: context.l10n.filesLoadingDirectory)
              : _error != null
              ? HermesErrorState(
                  description: _error == connectionOfflineErrorCode
                      ? context.l10n.backendDisconnected
                      : _error,
                  onRetry: () => _load(_path),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: _entries.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == 0) {
                      return ListTile(
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(context.l10n.terminalOpenDirectory),
                        onTap: () {
                          if (!identical(
                            widget.api,
                            context.read<SessionStore>().api,
                          )) {
                            setState(() => _error = connectionOfflineErrorCode);
                            return;
                          }
                          Navigator.of(context).pop(_path);
                        },
                      );
                    }
                    final e = _entries[i - 1];
                    if (!e.isDirectory) return const SizedBox.shrink();
                    return ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(e.name),
                      subtitle: Text(
                        e.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _load(e.path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
