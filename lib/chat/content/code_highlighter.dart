import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

/// Proper highlight.js-grammar code highlighting (desktop Shiki parity, minus
/// the multi-MB grammar bundle — a curated ~20-language set covering nearly
/// all LLM code output). Unknown languages fall through to [highlightCode]'s
/// null return so the caller can render plain text.
class CodeHighlighter {
  CodeHighlighter._();
  static final CodeHighlighter instance = CodeHighlighter._();

  final Highlight _hl = Highlight()
    ..registerLanguages({
      'bash': langBash,
      'c': langC,
      'cpp': langCpp,
      'csharp': langCsharp,
      'css': langCss,
      'dart': langDart,
      'go': langGo,
      'java': langJava,
      'javascript': langJavascript,
      'json': langJson,
      'kotlin': langKotlin,
      'markdown': langMarkdown,
      'php': langPhp,
      'python': langPython,
      'ruby': langRuby,
      'rust': langRust,
      'sql': langSql,
      'swift': langSwift,
      'typescript': langTypescript,
      'xml': langXml,
      'yaml': langYaml,
    });

  static const int _maxCacheEntries = 64;
  static const int _maxCachedSourceChars = 1000000;
  final LinkedHashMap<_HighlightCacheKey, _HighlightCacheValue> _cache =
      LinkedHashMap<_HighlightCacheKey, _HighlightCacheValue>();
  int _cachedSourceChars = 0;

  /// Exposed for performance regression tests and diagnostics.
  int get cacheEntryCount => _cache.length;
  int get cachedSourceChars => _cachedSourceChars;

  void clearCache() {
    _cache.clear();
    _cachedSourceChars = 0;
  }

  static const _aliases = <String, String>{
    'sh': 'bash',
    'shell': 'bash',
    'zsh': 'bash',
    'console': 'bash',
    'js': 'javascript',
    'jsx': 'javascript',
    'mjs': 'javascript',
    'cjs': 'javascript',
    'ts': 'typescript',
    'tsx': 'typescript',
    'py': 'python',
    'py3': 'python',
    'rb': 'ruby',
    'rs': 'rust',
    'kt': 'kotlin',
    'kts': 'kotlin',
    'cc': 'cpp',
    'cxx': 'cpp',
    'h': 'cpp',
    'hpp': 'cpp',
    'c++': 'cpp',
    'cs': 'csharp',
    'golang': 'go',
    'yml': 'yaml',
    'html': 'xml',
    'svg': 'xml',
    'xhtml': 'xml',
    'md': 'markdown',
    'markdown': 'markdown',
    'json5': 'json',
    'jsonc': 'json',
  };

  bool supports(String language) => _resolve(language) != null;

  String? _resolve(String language) {
    final key = language.trim().toLowerCase();
    if (key.isEmpty) return null;
    final resolved = _aliases[key] ?? key;
    return _hl.listLanguages().contains(resolved) ? resolved : null;
  }

  /// Highlighted spans for [code], or null when [language] isn't supported
  /// (caller renders plain text). Background colour is dropped so the block
  /// blends with the app's own code surface.
  TextSpan? highlight(String code, String language, bool isDark) {
    final resolved = _resolve(language);
    if (resolved == null) return null;
    final key = _HighlightCacheKey(code, resolved, isDark);
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached;
      return cached.span;
    }
    try {
      final result = _hl.highlight(code: code, language: resolved);
      final theme = Map<String, TextStyle>.from(
        isDark ? atomOneDarkTheme : atomOneLightTheme,
      )..['root'] = const TextStyle();
      final renderer = TextSpanRenderer(const TextStyle(), theme);
      result.render(renderer);
      final span = renderer.span;
      if (span == null) return null;
      // A single pathological response must not evict the useful working set.
      if (code.length <= _maxCachedSourceChars ~/ 2) {
        _cache[key] = _HighlightCacheValue(span, code.length);
        _cachedSourceChars += code.length;
        while (_cache.length > _maxCacheEntries ||
            _cachedSourceChars > _maxCachedSourceChars) {
          final oldest = _cache.keys.first;
          _cachedSourceChars -= _cache.remove(oldest)!.sourceChars;
        }
      }
      return span;
    } catch (_) {
      return null;
    }
  }
}

class _HighlightCacheKey {
  const _HighlightCacheKey(this.code, this.language, this.isDark);
  final String code;
  final String language;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      other is _HighlightCacheKey &&
      other.code == code &&
      other.language == language &&
      other.isDark == isDark;

  @override
  int get hashCode => Object.hash(code, language, isDark);
}

class _HighlightCacheValue {
  const _HighlightCacheValue(this.span, this.sourceChars);
  final TextSpan span;
  final int sourceChars;
}

/// Lightweight regex tokenizer — the fallback for languages outside
/// [CodeHighlighter]'s curated set. Covers keywords / strings / numbers /
/// comments / builtins / types for C-like / Python / JS / Dart / Go / Rust /
/// shell / yaml; unknown languages degrade to plain text.
class HermesSyntaxHighlighter {
  HermesSyntaxHighlighter._();

  static const int _maxCacheEntries = 64;
  static const int _maxSourceChars = 500000;
  static final LinkedHashMap<_FallbackCacheKey, _HighlightCacheValue> _cache =
      LinkedHashMap<_FallbackCacheKey, _HighlightCacheValue>();
  static int _sourceChars = 0;

  static void clearCache() {
    _cache.clear();
    _sourceChars = 0;
  }

  static TextSpan highlight(String source, String language, bool isDark) {
    final cacheKey = _FallbackCacheKey(source, language, isDark);
    final cached = _cache.remove(cacheKey);
    if (cached != null) {
      _cache[cacheKey] = cached;
      return cached.span;
    }
    final kwColor = isDark ? const Color(0xFFC084FC) : const Color(0xFFA855F7);
    final strColor = isDark ? const Color(0xFF86EFAC) : const Color(0xFF16A34A);
    final numColor = isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
    final commentColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final builtinColor = isDark
        ? const Color(0xFF7DD3FC)
        : const Color(0xFF0284C7);
    final baseColor = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);
    final typeColor = isDark
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFDC2626);

    const tripleQ = '"""';
    const tripleSq = "'''";
    final patterns = <_RegexTok, RegExp>{
      _RegexTok.blockComment: language == 'python'
          ? RegExp('$tripleSq[\\s\\S]*?$tripleSq|$tripleQ[\\s\\S]*?$tripleQ')
          : RegExp(r'/\*[\s\S]*?\*/'),
      _RegexTok.lineComment: language == 'python' || language == 'yaml'
          ? RegExp(r'#[^\n]*')
          : RegExp(r'//[^\n]*'),
      _RegexTok.string: RegExp(
        r"""(?:'(?:[^'\\]|\\.)*'|"(?:[^"\\]|\\.)*"|`(?:[^`\\]|\\.)*`|r'[^']*'|r"[^"]*")""",
      ),
      _RegexTok.number: RegExp(
        r'\b(?:0x[0-9a-fA-F]+|0b[01]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?[uUlLfFdD]*)\b',
      ),
      _RegexTok.keyword: RegExp(
        r'\b(?:abstract|as|assert|async|await|break|case|catch|class|const|continue|def|default|defer|del|do|elif|else|enum|except|export|extends|extern|false|final|finally|fn|for|from|fun|function|get|global|if|implements|import|in|interface|is|let|lambda|match|mut|namespace|new|nil|null|of|open|package|pass|private|protected|public|raise|readonly|ref|return|self|set|static|struct|super|switch|this|throw|throws|trait|true|try|type|typedef|typeof|use|var|void|volatile|while|with|yield)\b',
      ),
      _RegexTok.builtin: RegExp(
        r'\b(?:print|println|echo|console|require|include|len|range|min|max|abs|sum|any|all|sorted|reversed|list|dict|tuple|set|map|filter|reduce|enumerate|zip|input|open|Promise|fetch|Math|Object|Array|String|Number|Boolean|Symbol|JSON|parseInt|parseFloat|isNaN|isFinite|Vec|Box|Option|Some|None|Ok|Err|Result|fmt|eprintln|dbg)\b',
      ),
      _RegexTok.type: RegExp(
        r'\b(?:int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float|float32|float64|double|long|short|byte|char|bool|boolean|string|str|void|never|any|unknown|u8|u16|u32|u64|u128|i8|i16|i32|i64|i128|f32|f64|isize|usize|dyn|impl)\b',
      ),
    };

    final children = <TextSpan>[];
    var i = 0;
    while (i < source.length) {
      _RegexTok? matchedTok;
      String? matchedText;
      for (final entry in patterns.entries) {
        final m = entry.value.matchAsPrefix(source, i);
        if (m != null) {
          matchedTok = entry.key;
          matchedText = m.group(0)!;
          break;
        }
      }
      if (matchedTok != null && matchedText != null) {
        final color = switch (matchedTok) {
          _RegexTok.blockComment || _RegexTok.lineComment => commentColor,
          _RegexTok.string => strColor,
          _RegexTok.number => numColor,
          _RegexTok.keyword => kwColor,
          _RegexTok.builtin => builtinColor,
          _RegexTok.type => typeColor,
        };
        children.add(
          TextSpan(
            text: matchedText,
            style: TextStyle(color: color),
          ),
        );
        i += matchedText.length;
        continue;
      }
      final next = _nextMatch(source, i, patterns.values);
      final end = next == -1 ? source.length : next;
      children.add(
        TextSpan(
          text: source.substring(i, end),
          style: TextStyle(color: baseColor),
        ),
      );
      i = end;
    }
    final span = TextSpan(children: children);
    if (source.length <= _maxSourceChars ~/ 2) {
      _cache[cacheKey] = _HighlightCacheValue(span, source.length);
      _sourceChars += source.length;
      while (_cache.length > _maxCacheEntries ||
          _sourceChars > _maxSourceChars) {
        final oldest = _cache.keys.first;
        _sourceChars -= _cache.remove(oldest)!.sourceChars;
      }
    }
    return span;
  }

  static int _nextMatch(String s, int start, Iterable<RegExp> patterns) {
    int? best;
    for (final p in patterns) {
      final m = p.firstMatch(s.substring(start));
      if (m != null) {
        final pos = start + m.start;
        best ??= pos;
        if (pos < best) best = pos;
      }
    }
    return best ?? -1;
  }
}

class _FallbackCacheKey {
  const _FallbackCacheKey(this.source, this.language, this.isDark);
  final String source;
  final String language;
  final bool isDark;

  @override
  bool operator ==(Object other) =>
      other is _FallbackCacheKey &&
      other.source == source &&
      other.language == language &&
      other.isDark == isDark;

  @override
  int get hashCode => Object.hash(source, language, isDark);
}

enum _RegexTok {
  blockComment,
  lineComment,
  string,
  number,
  keyword,
  builtin,
  type,
}
