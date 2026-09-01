import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/preview_bridge.dart';
import '../../core/stores/connection_store.dart';
import '../../l10n/l10n.dart';
import '../../widgets/web_preview.dart';

/// Card stand-in for a `::preview{file="…"}` directive. Desktop renders the
/// workspace file as a live sandboxed iframe inline; mobile opens it in the
/// WebView preview page on tap (HTML/SVG) or shows its text.
class PreviewFileCard extends StatefulWidget {
  final String file;
  final double? initialHeight;
  const PreviewFileCard({super.key, required this.file, this.initialHeight});

  @override
  State<PreviewFileCard> createState() => _PreviewFileCardState();
}

class _PreviewFileCardState extends State<PreviewFileCard> {
  bool _loading = false;
  bool _expanded = false;
  String? _content;
  late double _height;

  @override
  void initState() {
    super.initState();
    _height = widget.initialHeight ?? kPreviewDefaultHeight;
  }

  @override
  void didUpdateWidget(covariant PreviewFileCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHeight != widget.initialHeight && _content == null) {
      _height = widget.initialHeight ?? kPreviewDefaultHeight;
    }
  }

  bool get _isWeb {
    final lower = widget.file.toLowerCase();
    return lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.xhtml') ||
        lower.endsWith('.svg');
  }

  Future<void> _open() async {
    final api = context.read<ConnectionStore>().api;
    final messenger = ScaffoldMessenger.of(context);
    if (api == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.l10n.backendDisconnected)),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final text = await api.fsReadText(widget.file);
      if (!mounted) return;
      final lower = widget.file.toLowerCase();
      final html = lower.endsWith('.svg')
          ? '<!doctype html><html><body style="margin:0">$text</body></html>'
          : text;
      setState(() {
        _content = html;
        _expanded = true;
      });
    } catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.l10n.previewFailed('$error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('preview-file-${widget.file}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          ListTile(
            leading: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isWeb ? Icons.web_outlined : Icons.description_outlined,
                  ),
            title: Text(
              widget.file,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _expanded
                  ? context.l10n.chatLivePreview
                  : context.l10n.chatExpandPreview,
            ),
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: _loading
                ? null
                : _expanded
                ? () => setState(() => _expanded = false)
                : _open,
          ),
          if (_expanded && _content != null)
            SizedBox(
              height: _height,
              child: _isWeb
                  ? WebPreviewPane(
                      html: _content,
                      showHtmlTools: false,
                      onContentHeightChanged: (height) {
                        if (!mounted || (height - _height).abs() <= 4) return;
                        setState(() => _height = height);
                      },
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(_content!),
                    ),
            ),
        ],
      ),
    );
  }
}
