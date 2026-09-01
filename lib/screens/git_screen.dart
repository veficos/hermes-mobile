/// Git (spec §67–75): repo status, changed files, diff view, stage/unstage,
/// commit (with optional push) and branch switching — all over the server's
/// `/api/v1/git/*` domain endpoints.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/connection_reload_mixin.dart';
import '../core/external_links.dart';
import '../core/stores/connection_store.dart';
import '../core/stores/pull_request_store.dart';
import '../core/stores/session_store.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';
import '../widgets/h/hermes_glass.dart';
import '../widgets/h/hermes_states.dart';

class GitScreen extends StatefulWidget {
  /// Optional repo root to open directly (e.g. from a Project detail);
  /// falls back to the active session's cwd, then the default cwd.
  final String? initialPath;

  const GitScreen({super.key, this.initialPath});

  @override
  State<GitScreen> createState() => _GitScreenState();
}

class _GitScreenState extends State<GitScreen>
    with SingleTickerProviderStateMixin, ConnectionReloadMixin<GitScreen> {
  String _path = '';
  Map<String, dynamic>? _status;
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _remotes = [];
  List<Map<String, dynamic>> _stashes = [];
  List<Map<String, dynamic>> _worktrees = [];
  Map<String, dynamic> _shipInfo = const {'ghReady': false, 'pr': null};
  bool _worktreeBusy = false;
  List<String> _recentRepos = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;
  // Tablet (spec §178): inline diff for the selected file.
  Map<String, dynamic>? _selectedFile;
  String _selectedDiff = '';
  bool _diffLoading = false;
  // Git Log
  late final TabController _tabController;
  List<Map<String, dynamic>> _logCommits = [];
  int _logTotal = 0;
  bool _logLoading = false;
  String _logSearch = '';
  String _logAuthor = '';
  final _logSearchCtrl = TextEditingController();
  final _logAuthorCtrl = TextEditingController();
  int _initGeneration = 0;
  int _loadGeneration = 0;
  int _logGeneration = 0;
  int _worktreeGeneration = 0;
  int _mutationGeneration = 0;

  ApiClient? get _api => context.read<ConnectionStore>().api;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadRecentRepos();
    _init();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _init);
  }

  void _onTabChanged() {
    // The commit page is intentionally lazy so opening a repository only
    // fetches its status.  It still must load as soon as the user selects the
    // tab; without this listener the log view remains permanently empty.
    if (!_tabController.indexIsChanging &&
        _tabController.index == 1 &&
        _logCommits.isEmpty &&
        !_logLoading) {
      _loadLog();
    }
  }

  Future<void> _loadRecentRepos() async {
    final prefs = await SharedPreferences.getInstance();
    final values =
        prefs.getStringList('hm_git_recent_repositories') ?? const [];
    if (mounted) setState(() => _recentRepos = values);
  }

  Future<void> _rememberRepo(String path) async {
    final normalized = path.trim();
    if (normalized.isEmpty) return;
    final next = <String>[normalized];
    next.addAll(_recentRepos.where((item) => item != normalized));
    final trimmed = next.take(8).toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('hm_git_recent_repositories', trimmed);
    if (mounted) setState(() => _recentRepos = trimmed);
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _logSearchCtrl.dispose();
    _logAuthorCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final generation = ++_initGeneration;
    _mutationGeneration++;
    _worktreeGeneration++;
    _loadGeneration++;
    _logGeneration++;
    final api = _api;
    if (mounted) setState(() => _busy = false);
    if (api == null) {
      if (!mounted || generation != _initGeneration) return;
      setState(() {
        _worktreeBusy = false;
        _loading = false;
        _error = connectionOfflineErrorCode;
        _status = null;
        _files = [];
        _branches = [];
        _logCommits = [];
      });
      return;
    }
    // Prefer the requested path, then the active session's workspace, then
    // the default cwd.
    var path =
        widget.initialPath ?? context.read<SessionStore>().info?.cwd ?? '';
    try {
      if (path.isEmpty) {
        path = await api.fsDefaultCwd();
      }
      if (!mounted || generation != _initGeneration || !identical(api, _api)) {
        return;
      }
      setState(() => _path = path);
      await _load();
    } catch (e) {
      if (mounted && generation == _initGeneration && identical(api, _api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    final api = _api;
    if (api == null || _path.isEmpty) return;
    final path = _path;
    setState(() {
      _loading = true;
      _error = null;
      _selectedFile = null;
      _selectedDiff = '';
    });
    try {
      final status = await api.gitStatus(path);
      final files = await api.gitReviewList(path);
      final branches = await api.gitBranches(path);
      List<Map<String, dynamic>> remotes = const [];
      List<Map<String, dynamic>> stashes = const [];
      List<Map<String, dynamic>> worktrees = const [];
      Map<String, dynamic> shipInfo = const {'ghReady': false, 'pr': null};
      try {
        remotes = await api.gitRemotes(path);
        stashes = await api.gitStashes(path);
      } catch (_) {
        // Older Agent backends omit these read-only WebUI endpoints.
      }
      try {
        worktrees = await api.gitWorktrees(path);
      } catch (_) {
        // Not a git repo, or the backend has no worktree support yet.
      }
      try {
        shipInfo = await api.gitShipInfo(path);
      } catch (_) {
        // An older backend may not expose GitHub ship state yet.
      }
      if (status['branch'] != null) await _rememberRepo(path);
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, _api) &&
          path == _path) {
        setState(() {
          _status = status;
          _files = files;
          _branches = branches;
          _remotes = remotes;
          _stashes = stashes;
          _worktrees = worktrees;
          _shipInfo = shipInfo;
          _loading = false;
        });
        if (_tabController.index == 1) await _loadLog();
      }
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, _api) &&
          path == _path) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadLog({int offset = 0, bool append = false}) async {
    final generation = ++_logGeneration;
    final api = _api;
    if (api == null || _path.isEmpty) return;
    final path = _path;
    setState(() => _logLoading = true);
    try {
      final data = await api.gitLog(
        path,
        limit: HermesPolicy.pageSize,
        offset: offset,
        search: _logSearch.isEmpty ? null : _logSearch,
        author: _logAuthor.isEmpty ? null : _logAuthor,
      );
      final commits = (data['commits'] as List? ?? [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      final total = (data['total'] as num?)?.toInt() ?? commits.length;
      if (!mounted ||
          generation != _logGeneration ||
          !identical(api, _api) ||
          path != _path) {
        return;
      }
      setState(() {
        if (append) {
          _logCommits.addAll(commits);
        } else {
          _logCommits = commits;
        }
        _logTotal = total;
        _logLoading = false;
      });
    } catch (e) {
      if (mounted &&
          generation == _logGeneration &&
          identical(api, _api) &&
          path == _path) {
        setState(() {
          _logLoading = false;
          _logCommits = [];
          _logTotal = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitLogLoadFailed('$e'))),
        );
      }
    }
  }

  Future<void> _changePath() async {
    final ownerApi = _api;
    final ownerPath = _path;
    final ctrl = TextEditingController(text: _path);
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.gitRepositoryDirectory),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: InputDecoration(
                labelText: context.l10n.gitServerRepositoryPath,
              ),
            ),
            if (_recentRepos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.gitRecentRepositories,
                  style: Theme.of(ctx).textTheme.labelLarge,
                ),
              ),
              SizedBox(
                height: 132,
                child: ListView(
                  children: [
                    for (final path in _recentRepos)
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.history, size: 18),
                        title: Text(
                          path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => Navigator.of(ctx).pop(path),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: Text(context.l10n.commonOpen),
          ),
        ],
      ),
    );
    // Deferred: the dialog's exit transition can still be rebuilding this
    // TextField for a frame or two after showDialog's Future resolves —
    // disposing synchronously here races that and throws "used after being
    // disposed".
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (picked != null &&
        picked.isNotEmpty &&
        picked != _path &&
        mounted &&
        identical(ownerApi, _api) &&
        ownerPath == _path) {
      _mutationGeneration++;
      _worktreeGeneration++;
      setState(() => _path = picked);
      await _load();
    }
  }

  bool _ownsMutation(ApiClient api, String path, int generation) =>
      mounted &&
      generation == _mutationGeneration &&
      identical(api, _api) &&
      path == _path;

  Future<void> _switchBranch() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.gitSwitchBranch,
                style: HermesType.onSurface(
                  HermesType.headline,
                  Theme.of(context),
                ),
              ),
            ),
            for (final b in _branches)
              ListTile(
                leading: Icon(
                  b['checkedOut'] == true
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: b['checkedOut'] == true
                      ? HermesSemantic.green
                      : HermesSemantic.gray,
                ),
                title: Text((b['name'] ?? '').toString()),
                onTap: () =>
                    Navigator.of(ctx).pop((b['name'] ?? '').toString()),
              ),
          ],
        ),
      ),
    );
    if (!mounted ||
        selected == null ||
        selected.isEmpty ||
        selected == _branchName) {
      return;
    }
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final path = _path;
    final generation = ++_mutationGeneration;
    setState(() => _busy = true);
    try {
      await api.gitBranchSwitch(path, selected);
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      await _load();
    } catch (e) {
      if (mounted && _ownsMutation(api, path, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitSwitchBranchFailed('$e'))),
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, path, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _stage(Map<String, dynamic> f, bool staged) async {
    final file = (f['path'] ?? '').toString();
    if (file.isEmpty) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final path = _path;
    final generation = ++_mutationGeneration;
    try {
      if (staged) {
        await api.gitUnstage(path, file);
      } else {
        await api.gitStage(path, file);
      }
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      await _load();
    } catch (e) {
      if (mounted && _ownsMutation(api, path, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitStageFailed('$e'))),
        );
      }
    }
  }

  /// Discard working-tree changes — one file, or every changed file when
  /// [f] is null. Destructive with no undo, so always confirms first.
  Future<void> _revert(Map<String, dynamic>? f) async {
    final file = f == null ? null : (f['path'] ?? '').toString();
    if (f != null && (file == null || file.isEmpty)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          file == null
              ? context.l10n.gitRevertAllQuestion
              : context.l10n.gitRevertFileQuestion,
        ),
        content: Text(
          file == null
              ? context.l10n.gitRevertAllDescription
              : context.l10n.gitRevertFileDescription(file),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: HermesSemantic.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.gitRevert),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final path = _path;
    final generation = ++_mutationGeneration;
    setState(() => _busy = true);
    try {
      await api.gitRevert(path, file);
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      if (_selectedFile != null &&
          (file == null || _selectedFile!['path'] == file)) {
        setState(() {
          _selectedFile = null;
          _selectedDiff = '';
        });
      }
      await _load();
    } catch (e) {
      if (mounted && _ownsMutation(api, path, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitRevertFailed('$e'))),
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, path, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showDiff(Map<String, dynamic> f) async {
    final file = (f['path'] ?? '').toString();
    if (file.isEmpty) return;
    final api = _api;
    if (api == null) return;
    final path = _path;
    final generation = _loadGeneration;
    final staged = f['staged'] == true;

    final isTablet = MediaQuery.of(context).size.width >= 840;
    if (isTablet) {
      // Tablet (spec §178): load diff inline for the right panel.
      setState(() {
        _selectedFile = f;
        _selectedDiff = '';
        _diffLoading = true;
      });
      try {
        final diff = await _readDiff(api, path, file, staged: staged);
        if (mounted &&
            generation == _loadGeneration &&
            identical(api, _api) &&
            path == _path) {
          setState(() {
            _selectedDiff = diff;
            _diffLoading = false;
          });
        }
      } catch (e) {
        if (mounted &&
            generation == _loadGeneration &&
            identical(api, _api) &&
            path == _path) {
          setState(() {
            _selectedDiff = context.l10n.gitDiffLoadFailed('$e');
            _diffLoading = false;
          });
        }
      }
      return;
    }

    // Phone: bottom sheet diff viewer.
    String diff = '';
    try {
      diff = await _readDiff(api, path, file, staged: staged);
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, _api) &&
          path == _path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitDiffLoadFailed('$e'))),
        );
      }
      return;
    }
    if (!mounted ||
        generation != _loadGeneration ||
        !identical(api, _api) ||
        path != _path) {
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesRadius.sheet),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      file,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: HermesType.onSurface(
                        HermesType.headline,
                        Theme.of(context),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _stage(f, !staged),
                    icon: Icon(
                      staged ? Icons.undo : Icons.add_box_outlined,
                      size: 16,
                    ),
                    label: Text(
                      staged ? context.l10n.gitUnstage : context.l10n.gitStage,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: diff.isEmpty
                  ? HermesEmptyState(
                      icon: Icons.difference_outlined,
                      title: context.l10n.gitNoDiff,
                      description: context.l10n.gitNoDiffDescription,
                    )
                  : SingleChildScrollView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        diff,
                        style: HermesType.code.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _readDiff(
    ApiClient api,
    String path,
    String file, {
    required bool staged,
  }) async {
    try {
      final review = await api.gitReviewDiff(path, file, staged: staged);
      if (review.isNotEmpty) return review;
      final data = await api.gitDiff(path, file);
      final plain = data['diff']?.toString() ?? data['patch']?.toString();
      if (plain != null && plain.isNotEmpty) return plain;
      final buffer = StringBuffer();
      for (final hunk in data['hunks'] as List? ?? const []) {
        if (hunk is! Map) continue;
        buffer.writeln(hunk['header'] ?? '@@');
        for (final line in hunk['lines'] as List? ?? const []) {
          if (line is! Map) continue;
          final prefix = switch (line['type']) {
            'add' => '+',
            'del' => '-',
            _ => ' ',
          };
          buffer.writeln('$prefix${line['text'] ?? ''}');
        }
      }
      return buffer.toString();
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
      return api.gitFileDiff(_path, file);
    }
  }

  void _showRepositoryInfo() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: [
            Text(
              context.l10n.gitRemotes,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            if (_remotes.isEmpty)
              ListTile(title: Text(context.l10n.gitNoVisibleRemotes)),
            for (final remote in _remotes)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text((remote['name'] ?? 'remote').toString()),
                subtitle: SelectableText((remote['url'] ?? '').toString()),
              ),
            const Divider(),
            Text(
              context.l10n.gitStashes,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            if (_stashes.isEmpty)
              ListTile(title: Text(context.l10n.gitNoStashes)),
            for (final stash in _stashes)
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: Text(
                  (stash['message'] ?? stash['name'] ?? stash['ref'] ?? 'stash')
                      .toString(),
                ),
                subtitle: Text(
                  (stash['oid'] ?? stash['index'] ?? '').toString(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _commit() async {
    final l10n = context.l10n;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    final path = _path;
    if (api == null || path.isEmpty) return;
    final messageCtrl = TextEditingController();
    var push = false;
    var generating = false;
    final messenger = ScaffoldMessenger.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(context.l10n.gitCommitChanges),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageCtrl,
                autofocus: true,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.l10n.gitCommitMessage,
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: push,
                onChanged: (v) => setDlg(() => push = v ?? false),
                title: Text(context.l10n.gitPushAfterCommit),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: generating
                  ? null
                  : () async {
                      if (!identical(api, _api) || path != _path) return;
                      setDlg(() => generating = true);
                      try {
                        final suggestion = await api.gitCommitMessage(path);
                        if (suggestion.message.isNotEmpty &&
                            ctx.mounted &&
                            identical(api, _api) &&
                            path == _path) {
                          messageCtrl.text = suggestion.message;
                          messageCtrl.selection = TextSelection.collapsed(
                            offset: messageCtrl.text.length,
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted &&
                            identical(api, _api) &&
                            path == _path) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.gitGenerateMessageFailed('$e'),
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDlg(() => generating = false);
                      }
                    },
              icon: generating
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high, size: 16),
              label: Text(context.l10n.gitGenerateCommitMessage),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(messageCtrl.text.trim()),
              child: Text(context.l10n.gitCommit),
            ),
          ],
        ),
      ),
    ).then((msg) async {
      // Deferred: the dialog's exit transition can still be rebuilding this
      // TextField for a frame or two after showDialog's Future resolves —
      // disposing synchronously here races that and throws "used after being
      // disposed".
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => messageCtrl.dispose(),
      );
      if (msg == null ||
          (msg as String).isEmpty ||
          !mounted ||
          !identical(api, _api) ||
          path != _path) {
        return;
      }
      final generation = ++_mutationGeneration;
      setState(() => _busy = true);
      try {
        requireActiveApi(context, context.read<ConnectionStore>(), api);
        if (path != _path) throw StateError(context.l10n.backendDisconnected);
        await api.gitCommit(path, msg, push: push);
        if (!mounted || !_ownsMutation(api, path, generation)) return;
        await _load();
      } catch (e) {
        if (mounted && _ownsMutation(api, path, generation)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.gitCommitFailed('$e'))),
          );
        }
      } finally {
        if (mounted && _ownsMutation(api, path, generation)) {
          setState(() => _busy = false);
        }
      }
    });
  }

  Future<void> _push() async {
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null || _busy) return;
    final path = _path;
    final generation = ++_mutationGeneration;
    setState(() => _busy = true);
    try {
      await api.gitPush(path);
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      await _load();
      if (mounted && _ownsMutation(api, path, generation)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.gitPushSucceeded)));
      }
    } catch (e) {
      if (mounted && _ownsMutation(api, path, generation)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitPushFailed('$e'))),
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, path, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  // Batch 4.2: PR creation + Agent Ship actions.
  Future<void> _createPr() async {
    if (_path.isEmpty) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final path = _path;
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionStore>();
    final pullRequests = context.read<PullRequestStore>();
    final currentPr = _shipInfo['pr'];
    if (currentPr is Map) {
      final url = currentPr['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        await launchExternalOrNotify(
          context,
          Uri.parse(url),
          failureMessage: context.l10n.gitOpenPrFailed,
        );
        return;
      }
    }
    if (_shipInfo['ghReady'] != true) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.gitGithubCliUnavailable)),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.gitCreatePr),
        content: Text(context.l10n.gitCreatePrQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !identical(api, _api) ||
        path != _path) {
      return;
    }
    final generation = ++_mutationGeneration;
    setState(() => _busy = true);
    try {
      final pr = await api.gitPrCreate(path);
      final refreshed = await api.gitShipInfo(path);
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      final durableId = session.durableId;
      final branch = pr.branch?.trim() ?? '';
      if (durableId != null && branch.isNotEmpty) {
        await pullRequests.stampSessionPrBranch(
          sessionId: durableId,
          repoRoot: path,
          branch: branch,
          profile: session.profile,
        );
        await pullRequests.refreshForSessions(
          session.sessions ?? const [],
          force: true,
        );
      }
      if (!mounted || !_ownsMutation(api, path, generation)) return;
      setState(() => _shipInfo = refreshed);
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(context.l10n.gitPrCreated),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                'URL: ${pr.url}',
                style: HermesType.code.copyWith(
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
              ),
              if (pr.number != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.l10n.gitPrNumber(pr.number!),
                    style: HermesType.onSurfaceVariant(
                      HermesType.caption,
                      Theme.of(ctx),
                    ),
                  ),
                ),
              if (pr.branch != null && pr.branch!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    context.l10n.gitBranchMeta(pr.branch!),
                    style: HermesType.onSurfaceVariant(
                      HermesType.caption,
                      Theme.of(ctx),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            if (pr.url.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await launchExternalOrNotify(
                    context,
                    Uri.parse(pr.url),
                    failureMessage: context.l10n.gitOpenPrFailed,
                  );
                },
                child: Text(context.l10n.commonOpen),
              ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonClose),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted && _ownsMutation(api, path, generation)) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.gitCreatePrFailed('$e'))),
        );
      }
    } finally {
      if (mounted && _ownsMutation(api, path, generation)) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _agentShip() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_path.isEmpty) return;
    final session = context.read<SessionStore>();
    final api = _api;
    final path = _path;
    final sessionId = session.durableId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.gitAgentShipTitle),
        content: Text(context.l10n.gitAgentShipQuestion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonRun),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        !identical(api, _api) ||
        path != _path ||
        sessionId != session.durableId) {
      return;
    }
    try {
      await session.sendMessage(context.l10n.gitAgentShipPrompt);
      if (!mounted ||
          !identical(api, _api) ||
          path != _path ||
          sessionId != session.durableId) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.gitAgentShipSent)),
      );
    } catch (e) {
      if (mounted &&
          identical(api, _api) &&
          path == _path &&
          sessionId == session.durableId) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.gitAgentShipFailed('$e'))),
        );
      }
    }
  }

  String get _branchName => (_status?['branch'] ?? '—').toString();

  String get _pullRequestLabel {
    final pr = _shipInfo['pr'];
    if (pr is Map && pr['number'] != null) {
      return context.l10n.gitOpenPr(pr['number']);
    }
    return context.l10n.gitCreatePr;
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final isTablet = MediaQuery.of(context).size.width >= 840;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.featureGit),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.gitChangesTab),
            Tab(text: context.l10n.gitCommitsTab),
            Tab(text: context.l10n.gitBranchesTab),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.commonRefresh,
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.commonMore,
            enabled: !_busy && _path.isNotEmpty,
            onSelected: (v) {
              switch (v) {
                case 'pr':
                  _createPr();
                case 'ship':
                  _agentShip();
                case 'repoInfo':
                  _showRepositoryInfo();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'repoInfo',
                child: Text(context.l10n.gitRemotesAndStashes),
              ),
              PopupMenuItem(value: 'pr', child: Text(_pullRequestLabel)),
              PopupMenuItem(
                value: 'ship',
                child: Text(context.l10n.gitAgentShipTitle),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: (_files.isNotEmpty || (status?['staged'] ?? 0) > 0)
          ? FloatingActionButton.extended(
              heroTag: 'git-commit',
              onPressed: _busy ? null : _commit,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              icon: const Icon(Icons.commit),
              label: Text(
                _busy
                    ? context.l10n.commonProcessing
                    : context.l10n.gitCommitChanges,
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          isTablet
              ? Row(
                  children: [
                    SizedBox(width: 360, child: _buildBody(context, status)),
                    const VerticalDivider(width: 1),
                    Expanded(child: _buildDiffPanel(context)),
                  ],
                )
              : _buildBody(context, status),
          _buildLogTab(),
          _buildBranchesTab(),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Branches tab
  Widget _buildBranchesTab() {
    if (_loading) {
      return HermesLoadingState(label: context.l10n.gitLoadingBranches);
    }
    if (_error != null) {
      return HermesErrorState(description: _error, onRetry: _load);
    }
    if (_branches.isEmpty && _remotes.isEmpty && _worktrees.isEmpty) {
      return HermesEmptyState(
        icon: Icons.account_tree_outlined,
        title: context.l10n.gitNoBranches,
        description: context.l10n.gitNoBranchesDescription,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            context.l10n.gitLocalBranches,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          for (final branch in _branches)
            Card(
              child: ListTile(
                leading: Icon(
                  branch['checkedOut'] == true
                      ? Icons.radio_button_checked
                      : Icons.account_tree_outlined,
                  color: branch['checkedOut'] == true
                      ? HermesSemantic.green
                      : null,
                ),
                title: Text(
                  (branch['name'] ?? branch['branch'] ?? '').toString(),
                ),
                subtitle: (branch['upstream'] ?? '').toString().isEmpty
                    ? null
                    : Text((branch['upstream'] ?? '').toString()),
                trailing: branch['checkedOut'] == true
                    ? Chip(label: Text(context.l10n.gitCurrent))
                    : TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final selected =
                                    (branch['name'] ?? branch['branch'] ?? '')
                                        .toString();
                                if (selected.isEmpty) return;
                                final api = connectedApiOrNotify(
                                  context,
                                  context.read<ConnectionStore>(),
                                );
                                if (api == null) return;
                                final path = _path;
                                final generation = ++_mutationGeneration;
                                setState(() => _busy = true);
                                try {
                                  await api.gitBranchSwitch(path, selected);
                                  if (!mounted ||
                                      !_ownsMutation(api, path, generation)) {
                                    return;
                                  }
                                  await _load();
                                } catch (error) {
                                  if (mounted &&
                                      _ownsMutation(api, path, generation)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.gitSwitchBranchFailed(
                                            '$error',
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted &&
                                      _ownsMutation(api, path, generation)) {
                                    setState(() => _busy = false);
                                  }
                                }
                              },
                        child: Text(context.l10n.gitSwitch),
                      ),
              ),
            ),
          if (_remotes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.gitRemotes,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            for (final remote in _remotes)
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(
                  (remote['name'] ?? remote['remote'] ?? 'origin').toString(),
                ),
                subtitle: Text(
                  (remote['url'] ?? remote['fetch'] ?? remote['push'] ?? '')
                      .toString(),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.l10n.gitWorktrees,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _worktreeBusy ? null : _createWorktree,
                icon: const Icon(Icons.call_split, size: 18),
                label: Text(context.l10n.commonNew),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_worktrees.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.l10n.gitNoAdditionalWorktrees),
            )
          else
            for (final wt in _worktrees) _worktreeTile(wt),
        ],
      ),
    );
  }

  Widget _worktreeTile(Map<String, dynamic> wt) {
    final path = (wt['path'] ?? '').toString();
    final branch = (wt['branch'] ?? '').toString();
    final isMain = wt['isMain'] == true;
    final locked = wt['locked'] == true;
    final detached = wt['detached'] == true;
    return Card(
      child: ListTile(
        leading: Icon(
          isMain ? Icons.home_outlined : Icons.call_split,
          color: isMain ? HermesSemantic.blue : null,
        ),
        title: Text(
          detached ? context.l10n.gitDetachedHead : branch,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (isMain) Chip(label: Text(context.l10n.gitMainWorktree)),
            if (locked) const Icon(Icons.lock_outline, size: 18),
            IconButton(
              tooltip: context.l10n.gitOpenInNewSession,
              icon: const Icon(Icons.open_in_new, size: 20),
              onPressed: _worktreeBusy ? null : () => _openWorktree(path),
            ),
            if (!isMain)
              IconButton(
                tooltip: context.l10n.commonDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: HermesSemantic.red,
                ),
                onPressed: _worktreeBusy ? null : () => _removeWorktree(wt),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openWorktree(String path) async {
    if (path.isEmpty) return;
    final connection = context.read<ConnectionStore>();
    final api = _api;
    final repoPath = _path;
    final generation = _worktreeGeneration;
    if (api == null || repoPath.isEmpty) return;
    try {
      requireActiveApi(context, connection, api);
      await context.read<SessionStore>().openNewSession(cwd: path);
      if (mounted &&
          generation == _worktreeGeneration &&
          identical(api, _api) &&
          repoPath == _path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitOpenedInNewSession(path))),
        );
      }
    } catch (e) {
      if (mounted &&
          generation == _worktreeGeneration &&
          identical(api, _api) &&
          repoPath == _path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.previewOpenSessionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _removeWorktree(Map<String, dynamic> wt) async {
    final path = (wt['path'] ?? '').toString();
    if (path.isEmpty) return;
    final api = _api;
    final repoPath = _path;
    final generation = _worktreeGeneration;
    if (api == null || repoPath.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.gitDeleteWorktreeQuestion),
        content: Text(context.l10n.gitDeleteWorktreeDescription(path)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    if (generation != _worktreeGeneration ||
        !identical(api, _api) ||
        repoPath != _path) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
      return;
    }
    await _doRemoveWorktree(
      path,
      force: false,
      api: api,
      repoPath: repoPath,
      generation: generation,
    );
  }

  Future<void> _doRemoveWorktree(
    String path, {
    required bool force,
    required ApiClient api,
    required String repoPath,
    required int generation,
  }) async {
    if (generation != _worktreeGeneration ||
        !identical(api, _api) ||
        repoPath != _path) {
      return;
    }
    setState(() => _worktreeBusy = true);
    try {
      await api.gitWorktreeRemove(repoPath, path, force: force);
      if (!mounted ||
          generation != _worktreeGeneration ||
          !identical(api, _api) ||
          repoPath != _path) {
        return;
      }
      await _load();
    } catch (e) {
      if (!mounted ||
          generation != _worktreeGeneration ||
          !identical(api, _api) ||
          repoPath != _path) {
        return;
      }
      final message = '$e';
      // git refuses to remove a worktree with uncommitted changes unless
      // forced — offer that as a follow-up instead of a dead-end error. The
      // user already confirmed the deletion itself above, so this skips
      // straight to force, rather than re-asking the same question twice.
      if (!force && message.toLowerCase().contains('modified or untracked')) {
        setState(() => _worktreeBusy = false);
        final forceConfirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.gitWorktreeHasChanges),
            content: Text(context.l10n.gitForceDeleteWorktreeQuestion),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(context.l10n.gitForceDelete),
              ),
            ],
          ),
        );
        if (forceConfirmed == true &&
            mounted &&
            generation == _worktreeGeneration &&
            identical(api, _api) &&
            repoPath == _path) {
          await _doRemoveWorktree(
            path,
            force: true,
            api: api,
            repoPath: repoPath,
            generation: generation,
          );
        }
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.gitDeleteWorktreeFailed('$e'))),
      );
    } finally {
      if (mounted &&
          generation == _worktreeGeneration &&
          identical(api, _api) &&
          repoPath == _path) {
        setState(() => _worktreeBusy = false);
      }
    }
  }

  /// Desktop parity: `base-branch-picker.tsx` — a searchable branch combobox
  /// distinguishing local/remote and flagging the default, instead of a
  /// bare `DropdownButtonFormField` listing raw names in server order.
  Future<String?> _pickBaseBranch(
    BuildContext context,
    List<Map<String, dynamic>> branches,
    String? current,
  ) async {
    final currentBranch = _branchName;
    final sorted = [...branches]
      ..sort((a, b) {
        final aLocal = a['isRemote'] != true;
        final bLocal = b['isRemote'] != true;
        if (aLocal != bLocal) return aLocal ? -1 : 1;
        final aCurrent = a['name']?.toString() == currentBranch;
        final bCurrent = b['name']?.toString() == currentBranch;
        if (aCurrent != bCurrent) return aCurrent ? -1 : 1;
        final aDefault = a['isDefault'] == true;
        final bDefault = b['isDefault'] == true;
        if (aDefault != bDefault) return aDefault ? -1 : 1;
        return (a['name']?.toString() ?? '').compareTo(
          b['name']?.toString() ?? '',
        );
      });
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => _BaseBranchPickerSheet(
        branches: sorted,
        current: current,
        currentBranch: currentBranch,
      ),
    );
  }

  Future<void> _createWorktree() async {
    if (_path.isEmpty) return;
    final api = connectedApiOrNotify(context, context.read<ConnectionStore>());
    if (api == null) return;
    final path = _path;
    final generation = _worktreeGeneration;
    List<Map<String, dynamic>> baseBranches = const [];
    try {
      baseBranches = await api.gitBaseBranches(path);
    } catch (_) {
      // Older Agent backends omit this read-only endpoint — the dialog still
      // works without a base-branch picker (falls back to HEAD).
    }
    final nameCtrl = TextEditingController();
    String? base = baseBranches
        .cast<Map<String, dynamic>?>()
        .firstWhere((b) => b?['isDefault'] == true, orElse: () => null)?['name']
        ?.toString();
    if (!mounted ||
        generation != _worktreeGeneration ||
        !identical(api, _api) ||
        path != _path) {
      return;
    }
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.l10n.gitNewWorktree),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: context.l10n.commonName,
                  hintText: context.l10n.gitWorktreeNameHint,
                ),
              ),
              if (baseBranches.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () async {
                    final picked = await _pickBaseBranch(
                      ctx,
                      baseBranches,
                      base,
                    );
                    if (picked != null) setDialogState(() => base = picked);
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: context.l10n.gitBaseBranch,
                      suffixIcon: const Icon(Icons.arrow_drop_down),
                    ),
                    child: Text(base ?? context.l10n.commonDefault),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(ctx).pop((nameCtrl.text.trim(), base)),
              child: Text(context.l10n.commonCreate),
            ),
          ],
        ),
      ),
    );
    // Deferred: the dialog's exit transition can still be rebuilding this
    // TextField for a frame or two after showDialog's Future resolves —
    // disposing synchronously here races that and throws "used after being
    // disposed" when the surrounding work resolves fast enough (e.g. tests,
    // or a low-latency backend) to catch the transition mid-flight.
    WidgetsBinding.instance.addPostFrameCallback((_) => nameCtrl.dispose());
    if (result == null ||
        result.$1.isEmpty ||
        !mounted ||
        generation != _worktreeGeneration ||
        !identical(api, _api) ||
        path != _path) {
      return;
    }
    setState(() => _worktreeBusy = true);
    try {
      requireActiveApi(context, context.read<ConnectionStore>(), api);
      if (path != _path) throw StateError(context.l10n.backendDisconnected);
      final created = await api.gitWorktreeAdd(
        path,
        name: result.$1,
        base: result.$2,
      );
      if (generation != _worktreeGeneration ||
          !identical(api, _api) ||
          path != _path) {
        return;
      }
      await _load();
      final newPath = created['path']?.toString();
      if (newPath != null && newPath.isNotEmpty && mounted) {
        await _openWorktree(newPath);
      }
    } catch (e) {
      if (mounted &&
          generation == _worktreeGeneration &&
          identical(api, _api) &&
          path == _path) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitCreateWorktreeFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _worktreeGeneration &&
          identical(api, _api) &&
          path == _path) {
        setState(() => _worktreeBusy = false);
      }
    }
  }

  // ---------------------------------------------------------------- Git Log tab
  Widget _buildLogTab() {
    return Column(
      children: [
        _buildLogFilters(),
        Expanded(
          child: _logLoading && _logCommits.isEmpty
              ? HermesLoadingState(label: context.l10n.gitLoadingLog)
              : _logCommits.isEmpty
              ? HermesEmptyState(
                  icon: Icons.history,
                  title: context.l10n.gitNoCommits,
                  description: context.l10n.gitNoCommitsDescription,
                )
              : _buildLogList(),
        ),
      ],
    );
  }

  Widget _buildLogFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _logSearchCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.gitSearchCommits,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    _logSearch = v.trim();
                    _loadLog();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _logAuthorCtrl,
                  decoration: InputDecoration(
                    labelText: context.l10n.gitAuthor,
                    prefixIcon: const Icon(Icons.person, size: 20),
                    isDense: true,
                  ),
                  onSubmitted: (v) {
                    _logAuthor = v.trim();
                    _loadLog();
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _loadLog,
                icon: const Icon(Icons.search, size: 18),
                label: Text(context.l10n.commonSearch),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    return RefreshIndicator(
      onRefresh: () => _loadLog(),
      child: ListView.builder(
        itemCount: _logCommits.length + 1,
        itemBuilder: (context, i) {
          if (i == _logCommits.length) {
            final hasMore = _logCommits.length < _logTotal;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: _logLoading
                    ? const CircularProgressIndicator()
                    : (hasMore
                          ? TextButton(
                              onPressed: () => _loadLog(
                                offset: _logCommits.length,
                                append: true,
                              ),
                              child: Text(
                                context.l10n.gitLoadMore(
                                  _logCommits.length,
                                  _logTotal,
                                ),
                              ),
                            )
                          : Text(
                              context.l10n.gitEndOfLog,
                              style: const TextStyle(color: Colors.grey),
                            )),
              ),
            );
          }
          final commit = _logCommits[i];
          return _logCommitTile(commit);
        },
      ),
    );
  }

  Widget _logCommitTile(Map<String, dynamic> commit) {
    final sha = (commit['sha'] ?? commit['id'] ?? '').toString();
    final shortSha = sha.length > 8 ? sha.substring(0, 8) : sha;
    final author = (commit['author'] ?? commit['author_name'] ?? '').toString();
    final message = (commit['message'] ?? commit['subject'] ?? '').toString();
    final timestamp = commit['timestamp'] ?? commit['date'];
    final parents = (commit['parents'] as List? ?? const []).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _showCommitDetail(commit),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HermesSemantic.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.commit,
                      size: 20,
                      color: HermesSemantic.purple,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: HermesSemantic.gray.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                shortSha,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                author.isNotEmpty
                                    ? author
                                    : context.l10n.gitUnknownAuthor,
                                style: Theme.of(context).textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                _fmtCommitTime(timestamp),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                        if (parents > 0) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (var j = 0; j < parents; j++)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: HermesSemantic.blue.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    context.l10n.gitParent,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: HermesSemantic.blue,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtCommitTime(dynamic ts) {
    DateTime dt;
    if (ts is int) {
      dt = DateTime.fromMillisecondsSinceEpoch(ts > 1e12 ? ts : ts * 1000);
    } else if (ts is String) {
      dt = DateTime.tryParse(ts) ?? DateTime.now();
    } else {
      dt = DateTime.now();
    }
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inSeconds < 60) return context.l10n.gitJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.gitMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) return context.l10n.gitHoursAgo(diff.inHours);
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showCommitDetail(Map<String, dynamic> commit) async {
    final sha = (commit['sha'] ?? commit['id'] ?? '').toString();
    if (sha.isEmpty) return;
    final api = _api;
    if (api == null) return;
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>>(
        future: api.gitLogCommit(_path, sha),
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: Center(child: CircularProgressIndicator()),
            );
          }
          final detail = snapshot.data ?? const <String, dynamic>{};
          final message = (detail['message'] ?? commit['message'] ?? '')
              .toString();
          final body = (detail['body'] ?? '').toString();
          final diff = (detail['diff'] ?? '').toString();
          final author = (detail['author'] ?? commit['author'] ?? '')
              .toString();
          final email = (detail['email'] ?? commit['email'] ?? '').toString();
          final files = detail['files'] as List? ?? const [];

          return AlertDialog(
            title: Text(context.l10n.gitCommitDetails),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: HermesSemantic.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      sha,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.gitAuthorMeta(
                            '$author${email.isNotEmpty ? " <$email>" : ""}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (files.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.gitChangedFilesLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    for (final f in files)
                      if (f is Map)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '  • ${f['path'] ?? f['filename'] ?? ''}',
                            style: TextStyle(
                              color:
                                  (f['status'] == 'added' || f['status'] == 'A')
                                  ? HermesSemantic.green
                                  : (f['status'] == 'deleted' ||
                                        f['status'] == 'D')
                                  ? HermesSemantic.red
                                  : HermesSemantic.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                  ],
                  if (diff.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        diff,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        maxLines: 15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(context.l10n.commonClose),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Tablet right-side diff panel (spec §178).
  Widget _buildDiffPanel(BuildContext context) {
    final file = _selectedFile;
    if (file == null) {
      return HermesEmptyState(
        icon: Icons.difference_outlined,
        title: context.l10n.gitSelectFileForDiff,
        description: context.l10n.gitSelectFileForDiffDescription,
      );
    }
    final path = (file['path'] ?? '').toString();
    final staged = file['staged'] == true;
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HermesType.onSurface(
                      HermesType.headline,
                      Theme.of(context),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _stage(file, !staged),
                  icon: Icon(
                    staged ? Icons.undo : Icons.add_box_outlined,
                    size: 16,
                  ),
                  label: Text(
                    staged ? context.l10n.gitUnstage : context.l10n.gitStage,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _diffLoading
              ? const Center(child: CircularProgressIndicator())
              : _selectedDiff.isEmpty
              ? HermesEmptyState(
                  icon: Icons.difference_outlined,
                  title: context.l10n.gitNoDiff,
                  description: context.l10n.gitNoDiffDescription,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _selectedDiff,
                    style: HermesType.code.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? status) {
    if (_loading) {
      return HermesLoadingState(label: context.l10n.gitLoadingStatus);
    }
    if (_error != null) {
      return HermesErrorState(description: _error, onRetry: _load);
    }
    final isRepo = status != null && (status['branch'] != null);
    if (!isRepo) {
      return HermesEmptyState(
        icon: Icons.commit,
        title: context.l10n.gitNotRepository,
        description: context.l10n.gitNotRepositoryDescription(_path),
        onPrimary: _changePath,
        primaryLabel: context.l10n.gitChangeDirectory,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          // ── Repo summary ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(HermesSpacing.md),
            child: HermesGlassCard(
              radius: HermesRadius.largeCard,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_tree_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      IconButton(
                        tooltip: context.l10n.gitChangeDirectory,
                        iconSize: 18,
                        onPressed: _changePath,
                        icon: const Icon(Icons.drive_file_move_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      InkWell(
                        onTap: _branches.isEmpty ? null : _switchBranch,
                        borderRadius: BorderRadius.circular(
                          HermesRadius.capsule,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: HermesSemantic.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              HermesRadius.capsule,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.account_tree_outlined,
                                size: 14,
                                color: HermesSemantic.green,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _branchName,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: HermesSemantic.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if ((status['ahead'] ?? 0) > 0 ||
                          (status['behind'] ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        if ((status['ahead'] ?? 0) > 0)
                          InkWell(
                            onTap: _busy ? null : () => _push(),
                            borderRadius: BorderRadius.circular(
                              HermesRadius.capsule,
                            ),
                            child: Tooltip(
                              message: context.l10n.gitPushAction(
                                '${status['ahead']}',
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '↑${status['ahead']} ↓${status['behind']}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelSmall,
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 14,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          Text(
                            '↑${status['ahead']} ↓${status['behind']}',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                      ],
                      const Spacer(),
                      _countChip(context, Icons.playlist_add, 'staged', status),
                      const SizedBox(width: 6),
                      _countChip(
                        context,
                        Icons.edit_outlined,
                        'unstaged',
                        status,
                      ),
                      const SizedBox(width: 6),
                      _countChip(
                        context,
                        Icons.help_outline,
                        'untracked',
                        status,
                      ),
                    ],
                  ),
                  if (_shipInfo['pr'] case final Map pr) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _createPr,
                      child: Row(
                        children: [
                          const Icon(Icons.call_merge, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'PR #${pr['number'] ?? ''} · ${(pr['state'] ?? 'open').toString().toLowerCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 16),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          HermesSectionHeader(
            title: context.l10n.gitChangedFiles,
            trailing: _files.isEmpty
                ? null
                : TextButton.icon(
                    onPressed: _busy ? null : () => _revert(null),
                    icon: const Icon(
                      Icons.undo,
                      size: 16,
                      color: HermesSemantic.red,
                    ),
                    label: Text(
                      context.l10n.gitRevertAll,
                      style: const TextStyle(color: HermesSemantic.red),
                    ),
                  ),
          ),
          if (_files.isEmpty)
            Padding(
              padding: const EdgeInsets.all(HermesSpacing.lg),
              child: Center(child: Text(context.l10n.gitWorkingTreeClean)),
            )
          else
            for (final f in _files) _fileRow(context, f),
        ],
      ),
    );
  }

  Widget _countChip(
    BuildContext context,
    IconData icon,
    String key,
    Map<String, dynamic> status,
  ) {
    final count = status[key] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: HermesSemantic.gray),
        const SizedBox(width: 3),
        Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: HermesSemantic.gray),
        ),
      ],
    );
  }

  Widget _fileRow(BuildContext context, Map<String, dynamic> f) {
    final path = (f['path'] ?? '').toString();
    final status = (f['status'] ?? '?').toString();
    final staged = f['staged'] == true;
    final added = (f['added'] ?? 0) as num;
    final removed = (f['removed'] ?? 0) as num;
    final isSelected = _selectedFile?['path'] == f['path'];
    final (color, label) = switch (status) {
      'M' => (HermesSemantic.orange, 'M'),
      'A' => (HermesSemantic.green, 'A'),
      'D' => (HermesSemantic.red, 'D'),
      'R' => (HermesSemantic.blue, 'R'),
      _ => (HermesSemantic.gray, '?'),
    };
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      leading: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        staged
            ? context.l10n.gitStagedChanges(added, removed)
            : '+$added −$removed',
        style: Theme.of(context).textTheme.labelSmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.l10n.gitRevertFile,
            icon: const Icon(Icons.undo, color: HermesSemantic.red, size: 20),
            onPressed: _busy ? null : () => _revert(f),
          ),
          IconButton(
            tooltip: staged ? context.l10n.gitUnstage : context.l10n.gitStage,
            icon: Icon(
              staged ? Icons.check_box : Icons.check_box_outline_blank,
              color: staged ? HermesSemantic.green : HermesSemantic.gray,
            ),
            onPressed: () => _stage(f, staged),
          ),
        ],
      ),
      onTap: () => _showDiff(f),
    );
  }
}

class _BaseBranchPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> branches;
  final String? current;
  final String currentBranch;

  const _BaseBranchPickerSheet({
    required this.branches,
    required this.current,
    required this.currentBranch,
  });

  @override
  State<_BaseBranchPickerSheet> createState() => _BaseBranchPickerSheetState();
}

class _BaseBranchPickerSheetState extends State<_BaseBranchPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.branches
        : widget.branches
              .where(
                (b) =>
                    (b['name']?.toString() ?? '').toLowerCase().contains(query),
              )
              .toList();
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.gitSearchBranches,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(child: Text(context.l10n.gitNoMatchingBranches))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final b = filtered[i];
                        final name = b['name']?.toString() ?? '';
                        final isRemote = b['isRemote'] == true;
                        final isDefault = b['isDefault'] == true;
                        final isCurrent = name == widget.currentBranch;
                        final selected = name == widget.current;
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isRemote ? Icons.cloud_outlined : Icons.merge_type,
                            size: 18,
                            color: selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isCurrent)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Text(
                                    context.l10n.gitCurrent,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              if (isDefault)
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              if (selected)
                                Icon(
                                  Icons.check,
                                  size: 18,
                                  color: theme.colorScheme.primary,
                                ),
                            ],
                          ),
                          onTap: () => Navigator.of(context).pop(name),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
