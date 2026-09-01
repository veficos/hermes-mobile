import 'dart:convert';
import 'dart:io';

const _baselinePath = 'tool/l10n_hardcoding_baseline.json';

final _literalPatterns = <RegExp>[
  RegExp(r'''\b(?:const\s+)?(?:Text|SelectableText)\(\s*r?['"]'''),
  RegExp(
    r'''\b(?:tooltip|labelText|hintText|helperText|errorText|semanticLabel)\s*:\s*r?['"]''',
  ),
  RegExp(r'''\b(?:title|subtitle|message)\s*:\s*(?:const\s+)?r?['"]'''),
];

final _nonCopyLiteralPatterns = <RegExp>[
  RegExp(r'''\btitle:\s*['"]\$\{j\[['"]title['"]\]\s*\?\?\s*['"]['"]\}['"]'''),
  RegExp(r'''\btitle:\s*['"]/\$\{c\.name\}['"]'''),
  RegExp(r'''\bmessage:\s*['"]['"]'''),
  RegExp(r'''\?\s*message\s*:\s*['"]'''),
];

final _hanLiteralPatterns = <RegExp>[
  RegExp(r"r?'[^'\n]*[\u3400-\u9fff][^'\n]*'"),
  RegExp(r'r?"[^"\n]*[\u3400-\u9fff][^"\n]*"'),
];

// Linguistic data used to derive a pet name, never rendered as UI copy.
const _allowedHanDataLiterals = {
  '一个',
  '一只',
  '风格',
  '的',
  r'\s*\((?:recommended|推荐)\)\s*$',
  r'每(?:天(?:早上|晚上|中午)?|日|周[一二三四五六日天]?|星期[一二三四五六日天]?|月|年|小时|分钟|次)',
  '停止对话',
  '结束对话',
};

void main(List<String> args) {
  final update = args.length == 1 && args.single == '--update';
  if (args.isNotEmpty && !update) {
    stderr.writeln(
      'Usage: dart run tool/check_l10n_hardcoding.dart [--update]',
    );
    exitCode = 64;
    return;
  }

  final current = _scan();
  final hanLiterals = _scanHanLiterals();
  final total = current.values.fold<int>(0, (sum, count) => sum + count);
  if (update) {
    File(_baselinePath).writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({'total': total, 'files': current})}\n',
    );
    stdout.writeln('Updated l10n hardcoding baseline: $total literals');
    return;
  }

  final baselineFile = File(_baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('Missing $_baselinePath; run with --update intentionally.');
    exitCode = 1;
    return;
  }
  final decoded = jsonDecode(baselineFile.readAsStringSync()) as Map;
  final baseline = (decoded['files'] as Map).cast<String, dynamic>();
  final regressions = <String>[];
  for (final entry in current.entries) {
    final allowed = (baseline[entry.key] as num?)?.toInt() ?? 0;
    if (entry.value > allowed) {
      regressions.add('${entry.key}: ${entry.value} (allowed $allowed)');
    }
  }
  if (hanLiterals.isNotEmpty) {
    stderr.writeln('Hardcoded Han-script strings detected in production UI:');
    for (final finding in hanLiterals) {
      stderr.writeln('  $finding');
    }
    stderr.writeln('Use context.l10n; only non-UI linguistic data is exempt.');
    exitCode = 1;
    return;
  }
  if (regressions.isNotEmpty) {
    stderr.writeln('New hardcoded UI literals detected:');
    for (final regression in regressions) {
      stderr.writeln('  $regression');
    }
    stderr.writeln('Use context.l10n; do not raise the baseline for new UI.');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    'No l10n regression: $total existing literal candidates across '
    '${current.length} files (baseline ${(decoded['total'] as num).toInt()}).',
  );
}

List<String> _scanHanLiterals() {
  final findings = <String>[];
  for (final file in _productionFiles()) {
    final lines = file.readAsLinesSync();
    for (var index = 0; index < lines.length; index++) {
      final code = lines[index].split('//').first;
      for (final pattern in _hanLiteralPatterns) {
        for (final match in pattern.allMatches(code)) {
          final literal = match.group(0)!;
          final quoteOffset = literal.startsWith('r') ? 2 : 1;
          final value = literal.substring(quoteOffset, literal.length - 1);
          if (_allowedHanDataLiterals.contains(value)) continue;
          findings.add('${file.path}:${index + 1}: $literal');
        }
      }
    }
  }
  return findings;
}

Map<String, int> _scan() {
  final files = _productionFiles();
  final counts = <String, int>{};
  for (final file in files) {
    var count = 0;
    for (final line in file.readAsLinesSync()) {
      final code = line.split('//').first;
      if (_nonCopyLiteralPatterns.any((pattern) => pattern.hasMatch(code))) {
        continue;
      }
      for (final pattern in _literalPatterns) {
        count += pattern.allMatches(code).length;
      }
    }
    if (count > 0) counts[file.path] = count;
  }
  return counts;
}

List<File> _productionFiles() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('.dart') &&
            !file.path.contains('/l10n/generated/'),
      )
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}
