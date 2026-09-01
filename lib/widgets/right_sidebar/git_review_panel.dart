/// GitReviewPanel: 右侧栏 Git 审查面板
///
/// 对应 Desktop 版 right-sidebar/review/index.tsx。
/// 显示变更文件列表、Diff 查看、Stage/Unstage、提交等功能。
library;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/stores/connection_store.dart';
import '../../core/connection_reload_mixin.dart';
import '../../core/external_links.dart';
import '../../core/stores/pull_request_store.dart';
import '../../core/stores/session_store.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../h/hermes_states.dart';
import '../../screens/file_editor_screen.dart';

class GitReviewPanel extends StatefulWidget {
  const GitReviewPanel({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<GitReviewPanel> createState() => _GitReviewPanelState();
}

class _GitReviewPanelState extends State<GitReviewPanel>
    with ConnectionReloadMixin<GitReviewPanel> {
  String? _cwd;
  Map<String, dynamic>? _status;
  List<dynamic>? _files;
  String? _selectedFile;
  bool _selectedFileStaged = false;
  String? _diffContent;
  String? _diffError;
  bool _loading = true;
  String? _error;
  bool _treeMode = true;
  final TextEditingController _commitMsgCtrl = TextEditingController();
  bool _pushAfterCommit = false;
  bool _generatingMessage = false;
  bool _shipBusy = false;
  bool _stageBusy = false;
  bool _committing = false;
  Map<String, dynamic>? _shipInfo;
  ApiClient? _loadedApi;
  int _loadGeneration = 0;
  int _diffGeneration = 0;
  int _mutationGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observeConnection(context.read<ConnectionStore>(), _reloadForConnection);
  }

  void _reloadForConnection() {
    if (!mounted) return;
    _diffGeneration++;
    _mutationGeneration++;
    setState(() {
      _cwd = null;
      _loadedApi = null;
      _status = null;
      _files = null;
      _shipInfo = null;
      _selectedFile = null;
      _diffContent = null;
      _diffError = null;
      _generatingMessage = false;
      _shipBusy = false;
      _stageBusy = false;
      _committing = false;
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  void dispose() {
    disposeConnectionObserver();
    _commitMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final connection = context.read<ConnectionStore>();
    final api = connection.api;
    final generation = ++_loadGeneration;
    if (api == null) {
      if (mounted) {
        setState(() {
          _cwd = null;
          _loadedApi = null;
          _status = null;
          _files = null;
          _shipInfo = null;
          _error = connectionOfflineErrorCode;
          _loading = false;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requested = widget.initialPath?.trim() ?? '';
      final cwd = requested.isEmpty ? await api.fsDefaultCwd() : requested;
      final status = await api.gitStatus(cwd);
      final files = (status['files'] as List?) ?? [];
      Map<String, dynamic>? shipInfo;
      try {
        shipInfo = await api.gitShipInfo(cwd);
      } catch (_) {
        // Older backends may not expose ship-info (PR/GH CLI status) — the
        // panel still works for stage/commit without it.
      }
      if (!mounted ||
          generation != _loadGeneration ||
          !identical(api, connection.api)) {
        return;
      }
      setState(() {
        _cwd = cwd;
        _loadedApi = api;
        _status = status;
        _files = files;
        _shipInfo = shipInfo;
        _loading = false;
      });
    } catch (e) {
      if (mounted &&
          generation == _loadGeneration &&
          identical(api, connection.api)) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadDiff(String file, {bool staged = false}) async {
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTarget(api, cwd)) return;
    final generation = ++_diffGeneration;
    setState(() {
      _selectedFile = file;
      _selectedFileStaged = staged;
      _diffContent = null;
      _diffError = null;
    });
    try {
      final diff = await api.gitFileDiff(cwd, file);
      if (mounted &&
          generation == _diffGeneration &&
          _ownsTarget(api, cwd) &&
          _selectedFile == file &&
          _selectedFileStaged == staged) {
        setState(() => _diffContent = diff);
      }
    } catch (e) {
      if (mounted &&
          generation == _diffGeneration &&
          _ownsTarget(api, cwd) &&
          _selectedFile == file &&
          _selectedFileStaged == staged) {
        setState(() => _diffError = '$e');
      }
    }
  }

  Future<void> _openSelectedFile() async {
    final cwd = _cwd, file = _selectedFile;
    final api = _loadedApi;
    if (cwd == null || file == null || api == null || !_ownsTarget(api, cwd)) {
      return;
    }
    final path = p.isAbsolute(file) ? file : p.normalize(p.join(cwd, file));
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FileEditorScreen(path: path, name: p.basename(path)),
      ),
    );
    if (mounted && _ownsTarget(api, cwd)) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.commonLoading,
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return HermesErrorState(
        title: context.l10n.commonErrorTitle,
        description: _error == connectionOfflineErrorCode
            ? context.l10n.backendDisconnected
            : _error!,
        onRetry: _load,
      );
    }

    return Column(
      children: [
        _buildHeader(context),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: _selectedFile != null
              ? _buildDiffView(context)
              : _buildFileList(context),
        ),
        if (_selectedFile == null) _buildCommitBar(context),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final current = _status?['current'] ?? _status?['branch'] ?? '';
    final ahead = _status?['ahead'] ?? 0;
    final behind = _status?['behind'] ?? 0;
    final stagedCount =
        _files
            ?.where(
              (f) => f['index_status'] != null && f['index_status'] != ' ',
            )
            .length ??
        0;
    final unstagedCount =
        _files
            ?.where(
              (f) => f['working_status'] != null && f['working_status'] != ' ',
            )
            .length ??
        0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                context.l10n.featureGit,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: _treeMode
                    ? context.l10n.gitListView
                    : context.l10n.gitTreeView,
                icon: Icon(
                  _treeMode ? Icons.view_list : Icons.account_tree_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _treeMode = !_treeMode),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: _shipInfo?['pr'] is Map
                    ? context.l10n.gitViewPr
                    : context.l10n.gitCreatePr,
                icon: _shipBusy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.call_merge, size: 18),
                onPressed: _shipBusy ? null : _createOrOpenPr,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: context.l10n.commonRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _load,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.merge_outlined,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              Text(
                current,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              if (ahead > 0) ...[
                Text(
                  '↑$ahead',
                  style: TextStyle(fontSize: 11, color: HermesSemantic.green),
                ),
              ],
              if (behind > 0) ...[
                Text(
                  '↓$behind',
                  style: TextStyle(fontSize: 11, color: HermesSemantic.orange),
                ),
              ],
              Text(
                context.l10n.gitChangeCounts(stagedCount, unstagedCount),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context) {
    final files = _files ?? [];
    if (files.isEmpty) {
      return HermesEmptyState(
        icon: Icons.check_circle_outline,
        title: context.l10n.gitWorkingTreeClean,
        description: context.l10n.gitWorkingTreeCleanDescription,
      );
    }

    // 分组：暂存区 + 未暂存
    final staged = files
        .where((f) => f['index_status'] != null && f['index_status'] != ' ')
        .toList();
    final unstaged = files
        .where((f) => f['working_status'] != null && f['working_status'] != ' ')
        .toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        if (staged.isNotEmpty) ...[
          _buildSectionHeader(context.l10n.gitStagedSection, staged.length),
          ...staged.map((f) => _buildFileRow(context, f, true)),
        ],
        if (unstaged.isNotEmpty) ...[
          _buildSectionHeader(context.l10n.gitUnstagedSection, unstaged.length),
          ...unstaged.map((f) => _buildFileRow(context, f, false)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildFileRow(BuildContext context, dynamic file, bool staged) {
    final path = file['path']?.toString() ?? '';
    final status = staged
        ? (file['index_status']?.toString() ?? 'M')
        : (file['working_status']?.toString() ?? 'M');
    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _loadDiff(path, staged: staged),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiffView(BuildContext context) {
    return Column(
      children: [
        // Diff 头部
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: context.l10n.commonBack,
                icon: const Icon(Icons.arrow_back, size: 16),
                onPressed: () => setState(() => _selectedFile = null),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _selectedFile ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _stageBusy
                    ? null
                    : () => _selectedFileStaged
                          ? _unstageFile(_selectedFile!)
                          : _stageFile(_selectedFile!),
                child: Text(
                  _selectedFileStaged
                      ? context.l10n.gitUnstage
                      : context.l10n.gitStage,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonOpen,
                onPressed: _openSelectedFile,
                icon: const Icon(Icons.open_in_new, size: 16),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        // Diff 内容
        Expanded(
          child: _diffError != null
              ? HermesErrorState(
                  description: _diffError,
                  onRetry: () =>
                      _loadDiff(_selectedFile!, staged: _selectedFileStaged),
                )
              : _diffContent != null
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _diffContent!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              : const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommitBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commitMsgCtrl,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: context.l10n.gitCommitMessage,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: context.l10n.gitGenerateCommitMessage,
                icon: _generatingMessage
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_fix_high, size: 18),
                onPressed: _generatingMessage ? null : _generateCommitMessage,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                tooltip: context.l10n.gitCommit,
                onPressed: _committing ? null : _commit,
                icon: _committing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.commit, size: 18),
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
              ),
            ],
          ),
          Row(
            children: [
              SizedBox(
                height: 28,
                width: 28,
                child: Checkbox(
                  value: _pushAfterCommit,
                  onChanged: (v) =>
                      setState(() => _pushAfterCommit = v ?? false),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _pushAfterCommit = !_pushAfterCommit),
                  child: Text(
                    context.l10n.gitPushAfterCommit,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _generateCommitMessage() async {
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTargetOrNotify(api, cwd)) return;
    final generation = _mutationGeneration;
    setState(() => _generatingMessage = true);
    try {
      final suggestion = await api.gitCommitMessage(cwd);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      if (suggestion.message.isNotEmpty) {
        _commitMsgCtrl.text = suggestion.message;
        _commitMsgCtrl.selection = TextSelection.collapsed(
          offset: _commitMsgCtrl.text.length,
        );
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitGenerateMessageFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _generatingMessage = false);
      }
    }
  }

  Future<void> _createOrOpenPr() async {
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTargetOrNotify(api, cwd)) return;
    final generation = _mutationGeneration;
    final currentPr = _shipInfo?['pr'];
    if (currentPr is Map) {
      final url = currentPr['url']?.toString() ?? '';
      if (url.isNotEmpty) {
        final launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
        if (mounted &&
            generation == _mutationGeneration &&
            _ownsTarget(api, cwd)) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.gitOpenPrFailed)));
        }
        return;
      }
    }
    if (_shipInfo != null && _shipInfo!['ghReady'] != true) {
      if (mounted && _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitGithubCliUnavailable)),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.gitCreatePr),
        content: Text(ctx.l10n.gitCreatePrQuestion),
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
    if (confirmed != true || !mounted) return;
    if (generation != _mutationGeneration || !_ownsTarget(api, cwd)) {
      _ownsTargetOrNotify(api, cwd);
      return;
    }
    setState(() => _shipBusy = true);
    try {
      final pr = await api.gitPrCreate(cwd);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      final refreshed = await api.gitShipInfo(cwd);
      // Best-effort: stamp the branch onto the active session's PR badge
      // when this panel is embedded alongside one. Neither store is
      // guaranteed present (the panel is also used from a bare workspace
      // view), so a missing provider must not break PR creation itself.
      try {
        if (!mounted ||
            generation != _mutationGeneration ||
            !_ownsTarget(api, cwd)) {
          throw StateError('stale target');
        }
        final session = context.read<SessionStore>();
        final pullRequests = context.read<PullRequestStore>();
        final durableId = session.durableId;
        final branch = pr.branch?.trim() ?? '';
        if (durableId != null && branch.isNotEmpty) {
          await pullRequests.stampSessionPrBranch(
            sessionId: durableId,
            repoRoot: cwd,
            branch: branch,
            profile: session.profile,
          );
          await pullRequests.refreshForSessions(
            session.sessions ?? const [],
            force: true,
          );
        }
      } catch (_) {
        // No session/PR store in this context — fine, PR is already created.
      }
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      setState(() => _shipInfo = refreshed);
      if (pr.url.isNotEmpty) {
        await launchExternalOrNotify(
          context,
          Uri.parse(pr.url),
          failureMessage: context.l10n.gitOpenPrFailed,
        );
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitCreatePrFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _shipBusy = false);
      }
    }
  }

  Future<void> _stageFile(String file) async {
    if (_stageBusy) return;
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTargetOrNotify(api, cwd)) return;
    final generation = _mutationGeneration;
    setState(() => _stageBusy = true);
    try {
      await api.gitStage(cwd, file);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      await _load();
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _selectedFileStaged = true);
      }
      await _loadDiff(file, staged: true);
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitStageFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _stageBusy = false);
      }
    }
  }

  Future<void> _unstageFile(String file) async {
    if (_stageBusy) return;
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTargetOrNotify(api, cwd)) return;
    final generation = _mutationGeneration;
    setState(() => _stageBusy = true);
    try {
      await api.gitUnstage(cwd, file);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      await _load();
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _selectedFileStaged = false);
      }
      await _loadDiff(file, staged: false);
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitUnstageFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _stageBusy = false);
      }
    }
  }

  Future<void> _commit() async {
    if (_committing) return;
    final api = _loadedApi;
    final cwd = _cwd;
    if (api == null || cwd == null || !_ownsTargetOrNotify(api, cwd)) return;
    final generation = _mutationGeneration;
    final msg = _commitMsgCtrl.text.trim();
    if (msg.isEmpty) return;
    setState(() => _committing = true);
    try {
      await api.gitCommit(cwd, msg, push: _pushAfterCommit);
      if (!mounted ||
          generation != _mutationGeneration ||
          !_ownsTarget(api, cwd)) {
        return;
      }
      _commitMsgCtrl.clear();
      await _load();
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _pushAfterCommit
                  ? context.l10n.gitCommitAndPushSucceeded
                  : context.l10n.gitCommitSucceeded,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.gitCommitFailed('$e'))),
        );
      }
    } finally {
      if (mounted &&
          generation == _mutationGeneration &&
          _ownsTarget(api, cwd)) {
        setState(() => _committing = false);
      }
    }
  }

  bool _ownsTarget(ApiClient api, String cwd) =>
      identical(context.read<ConnectionStore>().api, api) &&
      identical(_loadedApi, api) &&
      _cwd == cwd;

  bool _ownsTargetOrNotify(ApiClient api, String cwd) {
    if (_ownsTarget(api, cwd)) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.backendDisconnected)));
    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'A':
      case '?':
        return HermesSemantic.green;
      case 'M':
        return HermesSemantic.orange;
      case 'D':
        return HermesSemantic.red;
      case 'R':
        return HermesSemantic.blue;
      case 'U':
        return HermesSemantic.orange;
      default:
        return HermesSemantic.gray;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'A':
        return context.l10n.gitStatusAdded;
      case 'M':
        return context.l10n.gitStatusModified;
      case 'D':
        return context.l10n.gitStatusDeleted;
      case 'R':
        return context.l10n.gitStatusRenamed;
      case 'U':
        return context.l10n.gitStatusConflict;
      case '?':
        return '?';
      default:
        return status;
    }
  }
}
