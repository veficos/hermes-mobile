import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:provider/provider.dart';

import '../../core/stores/chat_store.dart';
import '../../core/clipboard.dart';
import '../../l10n/l10n.dart';
import '../../theme/hermes_tokens.dart';
import '../../widgets/web_preview.dart';
import 'code_highlighter.dart';
import 'mermaid_view.dart';

/// A fenced code block promotes to an [HermesArtifactCard] when it is an
/// html/svg/mermaid document OR a substantial plain-code block (desktop
/// `detectArtifact` — big code opens in the right rail). Otherwise it renders
/// as a highlighted [HermesCodeBlock].
const _artifactLineThreshold = 40;
const _artifactCharThreshold = 1600;

bool _promotesToArtifact(String language, String code) {
  final lang = language.toLowerCase();
  if (lang == 'html' || lang == 'svg' || lang == 'mermaid') return true;
  final lines = '\n'.allMatches(code).length + 1;
  return lines >= _artifactLineThreshold ||
      code.length >= _artifactCharThreshold;
}

Widget codeBlockOrArtifact(
  String code,
  String language, {
  bool enableHighlight = true,
}) {
  return _promotesToArtifact(language, code)
      ? HermesArtifactCard(code: code, language: language)
      : HermesCodeBlock(
          code: code,
          language: language,
          enableHighlight: enableHighlight,
        );
}

/// `<pre>` → highlighted code block / artifact card. Pass to
/// `MarkdownBody(builders: {'code': HermesCodeBlockBuilder()})`.
class HermesCodeBlockBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final language = (element.attributes['class'] ?? '').replaceFirst(
      'language-',
      '',
    );
    if (language.isEmpty) {
      return HermesCodeBlock(code: element.textContent, language: '');
    }
    return codeBlockOrArtifact(element.textContent, language);
  }
}

class HermesArtifactCard extends StatelessWidget {
  final String code;
  final String language;
  const HermesArtifactCard({
    super.key,
    required this.code,
    required this.language,
  });

  bool get _isMermaid => language.toLowerCase() == 'mermaid';
  bool get _isWeb {
    final l = language.toLowerCase();
    return l == 'html' || l == 'svg';
  }

  String get _html => language.toLowerCase() == 'svg'
      ? '<!doctype html><html><body>$code</body></html>'
      : code;

  String _title(BuildContext context) {
    if (_isMermaid) return context.l10n.chatMermaidDiagram;
    if (_isWeb) return context.l10n.chatArtifactTitle(language.toUpperCase());
    return context.l10n.chatCodeArtifactTitle(
      language.toUpperCase(),
      '\n'.allMatches(code).length + 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    int version = 0;
    int total = 0;
    try {
      final chat = context.read<ChatStore>();
      version = chat.registerArtifact(language, code);
      total = chat.artifactVersionCount(language);
    } catch (_) {
      // No ChatStore (test harness) — version badge simply hidden.
    }
    if (_isMermaid) {
      return _MermaidArtifactCard(
        code: code,
        title: _title(context),
        version: version,
        total: total,
      );
    }
    return Card(
      child: ListTile(
        leading: Icon(_isWeb ? Icons.widgets_outlined : Icons.code),
        title: Row(
          children: [
            Flexible(child: Text(_title(context))),
            if (total > 1) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: HermesPalette.of(context).accentBg,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'v$version/$total',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: HermesPalette.of(context).accent,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(code, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.open_in_full),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _isWeb
                ? WebPreviewPage(
                    html: _html,
                    title: context.l10n.chatArtifactPreview,
                  )
                : _CodeFullScreen(code: code, language: language),
          ),
        ),
      ),
    );
  }
}

/// Lightweight transcript representation. The platform WebView is created
/// only after the user opens the full-screen preview; merely scrolling past a
/// diagram must not start an HTML/JavaScript runtime.
class _MermaidArtifactCard extends StatelessWidget {
  final String code;
  final String title;
  final int version;
  final int total;

  const _MermaidArtifactCard({
    required this.code,
    required this.title,
    required this.version,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => MermaidPreview(source: code)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
              child: Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (total > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: palette.accentBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'v$version/$total',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: palette.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.open_in_full, size: 15, color: palette.text3),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140, maxHeight: 360),
              decoration: BoxDecoration(
                color: palette.codeBg,
                borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                border: Border.all(color: palette.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(HermesRadius.smallCard),
                child: IgnorePointer(
                  child: MermaidStaticDiagramView(source: code),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeFullScreen extends StatelessWidget {
  final String code;
  final String language;
  const _CodeFullScreen({required this.code, required this.language});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.l10n.chatCodeTitle(language.toUpperCase())),
      actions: [
        IconButton(
          tooltip: context.l10n.commonCopy,
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: () => copyTextOrNotify(
            context,
            code,
            successMessage: context.l10n.chatCodeCopied,
          ),
        ),
      ],
    ),
    body: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: HermesCodeBlock(code: code, language: language, framed: false),
      ),
    ),
  );
}

class HermesCodeBlock extends StatefulWidget {
  final String code;
  final String language;

  /// When false, drops the card chrome (used inside a full-screen viewer).
  final bool framed;
  final bool enableHighlight;

  const HermesCodeBlock({
    super.key,
    required this.code,
    required this.language,
    this.framed = true,
    this.enableHighlight = true,
  });

  @override
  State<HermesCodeBlock> createState() => _HermesCodeBlockState();
}

class _HermesCodeBlockState extends State<HermesCodeBlock> {
  bool _justCopied = false;
  TextSpan? _highlighted;
  bool? _highlightDark;
  String? _highlightCode;
  String? _highlightLanguage;

  TextSpan _highlight(bool isDark) {
    if (!widget.enableHighlight) {
      return TextSpan(text: widget.code);
    }
    if (_highlighted != null &&
        _highlightDark == isDark &&
        _highlightCode == widget.code &&
        _highlightLanguage == widget.language) {
      return _highlighted!;
    }
    _highlightDark = isDark;
    _highlightCode = widget.code;
    _highlightLanguage = widget.language;
    return _highlighted =
        CodeHighlighter.instance.highlight(
          widget.code,
          widget.language,
          isDark,
        ) ??
        HermesSyntaxHighlighter.highlight(widget.code, widget.language, isDark);
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlighted = _highlight(isDark);

    final body = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: SelectableText.rich(highlighted, style: HermesType.code),
    );
    if (!widget.framed) return body;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: palette.codeBg,
        borderRadius: BorderRadius.circular(HermesRadius.smallCard),
        border: Border.all(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(
              left: 12,
              right: 4,
              top: 4,
              bottom: 4,
            ),
            decoration: BoxDecoration(color: palette.surface),
            child: Row(
              children: [
                if (widget.language.isNotEmpty)
                  Text(
                    widget.language.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.04,
                      fontWeight: FontWeight.w600,
                      color: palette.text3,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: _justCopied
                      ? context.l10n.commonCopied
                      : context.l10n.commonCopy,
                  icon: Icon(
                    _justCopied ? Icons.check : Icons.copy_all_outlined,
                    size: 16,
                    color: palette.text3,
                  ),
                  onPressed: () async {
                    final copiedMessage = context.l10n.chatCodeCopied;
                    final copied = await copyTextOrNotify(
                      context,
                      widget.code,
                      successMessage: copiedMessage,
                    );
                    if (!mounted || !copied) return;
                    setState(() => _justCopied = true);
                    await Future<void>.delayed(
                      const Duration(milliseconds: 1400),
                    );
                    if (mounted) setState(() => _justCopied = false);
                  },
                ),
              ],
            ),
          ),
          body,
        ],
      ),
    );
  }
}
