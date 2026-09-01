/// In-app URL/HTML preview. Uses WebView on Android/iOS/macOS; otherwise
/// falls back to url_launcher plus a readable HTML pane.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/external_links.dart';
import '../core/preview_bridge.dart';
import '../core/stores/preview_store.dart';
import '../core/stores/session_store.dart';
import '../core/session_refs.dart';
import '../l10n/l10n.dart';
import '../theme/hermes_tokens.dart';

/// XL rail breakpoint used when deciding in-rail vs full-screen preview.
const double kPreviewRailBreakpoint = 840;

bool get webViewSupported {
  if (kIsWeb) return false;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

/// Open an http(s) or other URI: XL rail via [PreviewStore], phone via a page.
Future<void> openChatLink(BuildContext context, String href) async {
  final sessionId = sessionIdFromHref(href);
  if (sessionId != null && sessionId.isNotEmpty) {
    try {
      await context.read<SessionStore>().openSessionReference(sessionId);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.previewOpenSessionFailed('$error')),
          ),
        );
      }
    }
    return;
  }
  final uri = Uri.tryParse(href);
  if (uri == null) return;
  PreviewStore? preview;
  try {
    preview = context.read<PreviewStore>();
  } catch (_) {
    preview = null;
  }
  preview?.openUrl(href);
  final wide = MediaQuery.sizeOf(context).width >= kPreviewRailBreakpoint;
  if (wide && preview != null) return;
  if (!context.mounted) return;
  await Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => WebPreviewPage(url: href)));
}

class WebPreviewPage extends StatelessWidget {
  final String? url;
  final String? html;
  final String? title;

  const WebPreviewPage({super.key, this.url, this.html, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? context.l10n.previewTitle)),
      body: WebPreviewPane(url: url, html: html),
    );
  }
}

class WebPreviewPane extends StatefulWidget {
  final String? url;
  final String? html;
  final bool showHtmlTools;
  final String? previewTabId;
  final ValueChanged<double>? onContentHeightChanged;
  final Future<void> Function(String prompt)? onIntent;

  const WebPreviewPane({
    super.key,
    this.url,
    this.html,
    this.showHtmlTools = true,
    this.previewTabId,
    this.onContentHeightChanged,
    this.onIntent,
  });

  @override
  State<WebPreviewPane> createState() => _WebPreviewPaneState();
}

class _WebPreviewPaneState extends State<WebPreviewPane>
    implements PreviewDriver {
  static const _inputChannel = MethodChannel('hermes.preview/input');
  WebViewController? _controller;
  late String _bridgeToken;
  String? _error;
  bool _loading = false;
  final _address = TextEditingController();
  final _script = TextEditingController();
  bool _canGoBack = false;
  bool _canGoForward = false;
  bool _consoleOpen = false;
  bool _scriptRunning = false;
  DateTime? _lastIntentAt;
  final List<_PreviewConsoleEntry> _console = [];

  @override
  void initState() {
    super.initState();
    _bridgeToken = createPreviewBridgeToken();
    try {
      context.read<PreviewStore>().attachDriver(
        this,
        tabId: widget.previewTabId,
      );
    } catch (_) {}
    _rebuild();
  }

  @override
  void dispose() {
    try {
      context.read<PreviewStore>().detachDriver(
        this,
        tabId: widget.previewTabId,
      );
    } catch (_) {}
    _address.dispose();
    _script.dispose();
    super.dispose();
  }

  void _onBridgeMessage(JavaScriptMessage message) {
    final event = parsePreviewBridgeMessage(message.message, _bridgeToken);
    if (event == null || !mounted) return;
    switch (event.kind) {
      case PreviewBridgeEventKind.size:
        widget.onContentHeightChanged?.call(event.height!);
      case PreviewBridgeEventKind.intent:
        unawaited(_submitIntent(event.prompt!));
      case PreviewBridgeEventKind.console:
        _appendConsole(event.level!, event.message!);
    }
  }

  Future<void> _submitIntent(String prompt) async {
    final now = DateTime.now();
    final l10n = context.l10n;
    final previous = _lastIntentAt;
    if (previous != null &&
        now.difference(previous) < const Duration(seconds: 1)) {
      return;
    }
    _lastIntentAt = now;
    try {
      final callback = widget.onIntent;
      if (callback != null) {
        await callback(prompt);
      } else {
        await context.read<SessionStore>().sendHiddenMessage(prompt);
      }
      if (mounted && widget.showHtmlTools) {
        _appendConsole('info', l10n.previewActionSent(prompt));
      }
    } catch (error) {
      _appendConsole('error', l10n.previewActionSendFailed('$error'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.previewActionSendFailed('$error'))),
        );
      }
    }
  }

  void _appendConsole(String level, String message) {
    if (!mounted) return;
    setState(() {
      _console.add(
        _PreviewConsoleEntry(
          level: level,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
      if (_console.length > 200) _console.removeRange(0, _console.length - 200);
    });
  }

  Future<void> _runScript() async {
    final controller = _controller;
    final source = _script.text.trim();
    if (controller == null || source.isEmpty || widget.html == null) return;
    setState(() => _scriptRunning = true);
    try {
      final encoded = jsonEncode(source);
      final result = await controller.runJavaScriptReturningResult('''(() => {
        try {
          const value=(0,eval)($encoded);
          return JSON.stringify({success:true,value:value===undefined?'undefined':String(value)});
        } catch(error) {
          return JSON.stringify({success:false,error:String(error&&error.stack||error)});
        }
      })()''');
      final decoded = _decodeResult(result);
      _appendConsole(
        decoded['success'] == false ? 'error' : 'info',
        (decoded['error'] ?? decoded['value'] ?? '').toString(),
      );
    } catch (error) {
      _appendConsole('error', '$error');
    } finally {
      if (mounted) setState(() => _scriptRunning = false);
    }
  }

  Future<void> _syncNavigation() async {
    final controller = _controller;
    if (controller == null) return;
    final url = await controller.currentUrl();
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (!mounted) return;
    setState(() {
      if (url != null) _address.text = url;
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  Future<void> _navigateAddress(String value) async {
    var target = value.trim();
    if (target.isEmpty || _controller == null) return;
    if (!target.contains('://')) target = 'https://$target';
    final uri = Uri.tryParse(target);
    if (uri != null) await _controller!.loadRequest(uri);
  }

  @override
  Future<Map<String, dynamic>> read({int? start, int? count}) async {
    final controller = _controller;
    if (controller == null) {
      return {'success': false, 'error': 'No live page is open.'};
    }
    final result = await controller.runJavaScriptReturningResult(
      "JSON.stringify({title:document.title,url:location.href,text:(document.body?.innerText||'').trim()})",
    );
    final decoded = _decodeResult(result);
    final text = decoded['text']?.toString() ?? '';
    final from = (start ?? 0).clamp(0, text.length);
    final to = count == null
        ? text.length
        : (from + count).clamp(from, text.length);
    return {...decoded, 'text': text.substring(from, to), 'success': true};
  }

  @override
  Future<Map<String, dynamic>> act(Map<String, dynamic> action) async {
    final controller = _controller;
    if (controller == null) {
      return {'success': false, 'error': 'No live page is open.'};
    }
    final kind = (action['action'] ?? action['kind'] ?? '').toString();
    if (kind == 'back') {
      await controller.goBack();
      return {'success': true, 'acted': kind};
    }
    if (kind == 'forward') {
      await controller.goForward();
      return {'success': true, 'acted': kind};
    }
    if (kind == 'reload') {
      await controller.reload();
      return {'success': true, 'acted': kind};
    }
    if (defaultTargetPlatform == TargetPlatform.android &&
        const {'click', 'hover', 'type', 'press', 'scroll'}.contains(kind)) {
      try {
        final native = await _actNative(controller, action, kind);
        if (native != null) return native;
      } on PlatformException {
        // Older builds do not expose the native input bridge; retain the DOM
        // compatibility ladder below.
      }
    }
    final payload = jsonEncode(action);
    final result = await controller.runJavaScriptReturningResult('''(() => {
      const a=$payload, kind=String(a.action||a.kind||'');
      const shown=e=>!!(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
      const els=[...document.querySelectorAll('a,button,input,textarea,select,[contenteditable="true"],[role="button"],[tabindex]')].filter(shown);
      const inventory=()=>els.slice(0,Number(a.max||80)).map((e,i)=>({ref:String(i+1),tag:e.tagName.toLowerCase(),type:e.getAttribute('type'),name:e.getAttribute('name'),text:String(e.innerText||e.value||e.getAttribute('aria-label')||e.getAttribute('placeholder')||'').trim().slice(0,160),disabled:!!e.disabled}));
      if(kind==='elements') return JSON.stringify({success:true,title:document.title,url:location.href,elements:inventory()});
      if(kind==='scroll'){window.scrollBy({top:Number(a.amount||500),behavior:'smooth'});return JSON.stringify({success:true,acted:kind});}
      const el=a.selector?document.querySelector(a.selector):els[Number(a.ref)-1];
      if(!el)return JSON.stringify({success:false,error:'Element not found; call elements again.'});
      el.scrollIntoView({block:'center'}); el.focus();
      if(kind==='click')el.click();
      else if(kind==='hover')el.dispatchEvent(new MouseEvent('mouseover',{bubbles:true}));
      else if(kind==='type'){
        const value=String(a.text||'');
        if(el.isContentEditable){el.textContent=value;}
        else {const proto=el instanceof HTMLTextAreaElement?HTMLTextAreaElement.prototype:HTMLInputElement.prototype;const setter=Object.getOwnPropertyDescriptor(proto,'value')?.set;setter?setter.call(el,value):el.value=value;}
        try{el.dispatchEvent(new InputEvent('beforeinput',{bubbles:true,inputType:'insertText',data:value}));}catch(_){}
        el.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:value}));
        el.dispatchEvent(new Event('change',{bubbles:true}));
        if(a.submit){const form=el.closest('form');form?.requestSubmit?form.requestSubmit():el.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',bubbles:true}));}
      }
      else if(kind==='press')el.dispatchEvent(new KeyboardEvent('keydown',{key:String(a.key||'Enter'),bubbles:true}));
      else return JSON.stringify({success:false,error:'Unsupported preview action: '+kind});
      return JSON.stringify({success:true,acted:kind,elements:inventory()});
    })()''');
    return _decodeResult(result);
  }

  @override
  Future<Map<String, dynamic>> tour(Map<String, dynamic> action) async {
    final controller = _controller;
    if (controller == null) {
      return {'success': false, 'error': 'No live page is open.'};
    }
    final result = await controller.runJavaScriptReturningResult(
      previewTourScript(
        action,
        backLabel: context.l10n.previewTourBack,
        doneLabel: context.l10n.previewTourDone,
        nextLabel: context.l10n.previewTourNext,
      ),
    );
    return _decodeResult(result);
  }

  Future<Map<String, dynamic>?> _actNative(
    WebViewController controller,
    Map<String, dynamic> action,
    String kind,
  ) async {
    if (kind == 'scroll') {
      final ok = await _inputChannel.invokeMethod<bool>('scroll', {
        'dx': 0.0,
        'dy': (action['amount'] as num?)?.toDouble() ?? 500.0,
      });
      return ok == true
          ? {'success': true, 'acted': kind, 'native': true}
          : null;
    }
    final selector = jsonEncode(action['selector']?.toString());
    final ref =
        (action['ref'] as num?)?.toInt() ??
        int.tryParse('${action['ref']}') ??
        0;
    final raw = await controller.runJavaScriptReturningResult('''(() => {
      const shown=e=>!!(e.offsetWidth||e.offsetHeight||e.getClientRects().length);
      const els=[...document.querySelectorAll('a,button,input,textarea,select,[contenteditable="true"],[role="button"],[tabindex]')].filter(shown);
      const el=$selector?document.querySelector($selector):els[${ref - 1}];
      if(!el)return JSON.stringify({});
      el.scrollIntoView({block:'center'});const r=el.getBoundingClientRect();
      return JSON.stringify({x:(r.left+r.width/2)*devicePixelRatio,y:(r.top+r.height/2)*devicePixelRatio});
    })()''');
    final point = _decodeResult(raw);
    if (point['x'] is! num || point['y'] is! num) return null;
    final args = {'x': point['x'], 'y': point['y']};
    if (kind == 'hover') args['hover'] = true;
    final focused = await _inputChannel.invokeMethod<bool>('pointer', args);
    if (focused != true) return null;
    if (kind == 'type') {
      await _inputChannel.invokeMethod<bool>('text', {
        'text': '${action['text'] ?? ''}',
      });
      if (action['submit'] == true) {
        await _inputChannel.invokeMethod<bool>('key', {'key': 'ENTER'});
      }
    } else if (kind == 'press') {
      await _inputChannel.invokeMethod<bool>('key', {
        'key': '${action['key'] ?? 'ENTER'}',
      });
    }
    return {'success': true, 'acted': kind, 'native': true};
  }

  Map<String, dynamic> _decodeResult(Object result) {
    dynamic value = result;
    for (var i = 0; i < 2 && value is String; i++) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        break;
      }
    }
    return value is Map
        ? value.cast<String, dynamic>()
        : {'success': true, 'value': '$value'};
  }

  @override
  void didUpdateWidget(covariant WebPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.html != widget.html) {
      _bridgeToken = createPreviewBridgeToken();
      _console.clear();
      _lastIntentAt = null;
      _rebuild();
    }
  }

  NavigationDecision _navigationDecision(NavigationRequest request) {
    if (widget.html == null) return NavigationDecision.navigate;
    final uri = Uri.tryParse(request.url);
    if (uri == null || const {'about', 'data'}.contains(uri.scheme)) {
      return NavigationDecision.navigate;
    }
    unawaited(launchExternalOrNotify(context, uri));
    return NavigationDecision.prevent;
  }

  void _rebuild() {
    _error = null;
    _controller = null;
    final url = widget.url?.trim() ?? '';
    final html = widget.html;
    if ((url.isEmpty) && (html == null || html.isEmpty)) {
      setState(() {});
      return;
    }
    if (!webViewSupported) {
      setState(() {});
      return;
    }
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: _navigationDecision,
            onPageStarted: (_) {
              if (mounted) setState(() => _loading = true);
            },
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
              unawaited(_syncNavigation());
            },
            onWebResourceError: (error) {
              if (error.isForMainFrame == false || !mounted) return;
              setState(() {
                _loading = false;
                _error = error.description;
              });
            },
          ),
        );
      if (html != null && html.isNotEmpty) {
        controller
          ..addJavaScriptChannel(
            'HermesPreviewBridge',
            onMessageReceived: _onBridgeMessage,
          )
          ..loadHtmlString(
            withPreviewBridge(
              html,
              _bridgeToken,
              scriptErrorLabel: context.l10n.previewScriptError,
              unhandledPromiseRejectionLabel:
                  context.l10n.previewUnhandledPromiseRejection,
            ),
          );
      } else {
        _address.text = url;
        controller.loadRequest(Uri.parse(url));
      }
      _controller = controller;
      _loading = true;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() {});
  }

  Future<void> _openExternal() async {
    final url = widget.url?.trim() ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchExternalOrNotify(context, uri);
  }

  @override
  Widget build(BuildContext context) {
    final palette = HermesPalette.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final url = widget.url?.trim() ?? '';
    final html = widget.html ?? '';
    if (url.isEmpty && html.isEmpty) {
      return Center(
        child: Text(
          context.l10n.previewEmpty,
          style: TextStyle(color: palette.text3),
        ),
      );
    }

    final fallback = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (url.isNotEmpty)
          ListTile(
            dense: true,
            title: Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: TextButton(
              onPressed: _openExternal,
              child: Text(context.l10n.previewOpenBrowser),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              context.l10n.previewFailed('$_error'),
              style: TextStyle(color: errorColor),
            ),
          ),
        if (html.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SelectableText(html, style: HermesType.code),
            ),
          )
        else if (!webViewSupported)
          Expanded(
            child: Center(child: Text(context.l10n.previewUnsupportedWebView)),
          ),
      ],
    );

    if (_controller == null || _error != null) {
      return fallback;
    }

    return Column(
      children: [
        if (url.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            child: Row(
              children: [
                IconButton(
                  tooltip: context.l10n.previewBack,
                  onPressed: _canGoBack ? () => _controller!.goBack() : null,
                  icon: const Icon(Icons.arrow_back, size: 18),
                ),
                IconButton(
                  tooltip: context.l10n.previewForward,
                  onPressed: _canGoForward
                      ? () => _controller!.goForward()
                      : null,
                  icon: const Icon(Icons.arrow_forward, size: 18),
                ),
                IconButton(
                  tooltip: context.l10n.commonRefresh,
                  onPressed: () => _controller!.reload(),
                  icon: const Icon(Icons.refresh, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: _address,
                    decoration: const InputDecoration(isDense: true),
                    maxLines: 1,
                    textInputAction: TextInputAction.go,
                    onSubmitted: _navigateAddress,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.previewOpenBrowser,
                  onPressed: _openExternal,
                  icon: const Icon(Icons.open_in_new, size: 18),
                ),
              ],
            ),
          ),
        if (html.isNotEmpty && widget.showHtmlTools)
          _HtmlPreviewToolbar(
            consoleOpen: _consoleOpen,
            logCount: _console.length,
            onReload: () => _controller!.reload(),
            onToggleConsole: () {
              setState(() => _consoleOpen = !_consoleOpen);
            },
          ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: WebViewWidget(controller: _controller!)),
        if (html.isNotEmpty && widget.showHtmlTools && _consoleOpen)
          _PreviewConsole(
            entries: _console,
            scriptController: _script,
            scriptRunning: _scriptRunning,
            onClear: () => setState(_console.clear),
            onRunScript: _runScript,
          ),
      ],
    );
  }
}

class _PreviewConsoleEntry {
  const _PreviewConsoleEntry({
    required this.level,
    required this.message,
    required this.timestamp,
  });

  final String level;
  final String message;
  final DateTime timestamp;
}

class _HtmlPreviewToolbar extends StatelessWidget {
  const _HtmlPreviewToolbar({
    required this.consoleOpen,
    required this.logCount,
    required this.onReload,
    required this.onToggleConsole,
  });

  final bool consoleOpen;
  final int logCount;
  final VoidCallback onReload;
  final VoidCallback onToggleConsole;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          IconButton(
            tooltip: context.l10n.previewRefresh,
            onPressed: onReload,
            icon: const Icon(Icons.refresh, size: 18),
          ),
          const Spacer(),
          if (logCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text(
                '$logCount',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          IconButton(
            tooltip: consoleOpen
                ? context.l10n.previewCloseConsole
                : context.l10n.previewOpenConsole,
            onPressed: onToggleConsole,
            icon: Icon(
              consoleOpen ? Icons.terminal : Icons.terminal_outlined,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewConsole extends StatelessWidget {
  const _PreviewConsole({
    required this.entries,
    required this.scriptController,
    required this.scriptRunning,
    required this.onClear,
    required this.onRunScript,
  });

  final List<_PreviewConsoleEntry> entries;
  final TextEditingController scriptController;
  final bool scriptRunning;
  final VoidCallback onClear;
  final VoidCallback onRunScript;

  Color _levelColor(BuildContext context, String level) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      'error' => scheme.error,
      'warn' => Colors.orange.shade700,
      'info' => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Column(
        children: [
          const Divider(height: 1),
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.terminal, size: 16),
                const SizedBox(width: 6),
                Text(
                  context.l10n.previewConsoleTitle,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.previewClearConsole,
                  onPressed: entries.isEmpty ? null : onClear,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                ),
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(context.l10n.previewNoLogs))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final time = entry.timestamp.toIso8601String().substring(
                        11,
                        19,
                      );
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: SelectableText(
                          '$time [${entry.level}] ${entry.message}',
                          style: HermesType.code.copyWith(
                            color: _levelColor(context, entry.level),
                            fontSize: 11,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Text('>'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: scriptController,
                    decoration: InputDecoration(
                      hintText: context.l10n.previewRunJavascript,
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: HermesType.code,
                    maxLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: scriptRunning ? null : (_) => onRunScript(),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.previewRunScript,
                  onPressed: scriptRunning ? null : onRunScript,
                  icon: scriptRunning
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 19),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
