import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Touch/mouse-resizable GFM table. Drag the handle at a header's right edge.
class ResizableMarkdownTableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final rows = <List<String>>[];
    for (final child in element.children ?? const <md.Node?>[]) {
      if (child is! md.Element) continue;
      if (child.tag != 'thead' && child.tag != 'tbody' && child.tag != 'tr') {
        continue;
      }
      final rowElements = <md.Element>[];
      if (child.tag == 'tr') {
        rowElements.add(child);
      } else {
        for (final nested in child.children ?? const <md.Node?>[]) {
          if (nested is md.Element && nested.tag == 'tr') {
            rowElements.add(nested);
          }
        }
      }
      for (final tr in rowElements) {
        rows.add(
          (tr.children ?? const [])
              .whereType<md.Element>()
              .where((cell) => cell.tag == 'th' || cell.tag == 'td')
              .map((cell) => cell.textContent.trim())
              .toList(growable: false),
        );
      }
    }
    return rows.isEmpty ? null : _ResizableTable(rows: rows);
  }
}

class _ResizableTable extends StatefulWidget {
  final List<List<String>> rows;
  const _ResizableTable({required this.rows});

  @override
  State<_ResizableTable> createState() => _ResizableTableState();
}

class _ResizableTableState extends State<_ResizableTable> {
  late final List<double> _widths = List.filled(
    widget.rows.fold<int>(
      0,
      (count, row) => row.length > count ? row.length : count,
    ),
    140,
  );

  @override
  Widget build(BuildContext context) {
    final border = Theme.of(context).dividerColor;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder.all(color: border),
        columnWidths: {
          for (var i = 0; i < _widths.length; i++)
            i: FixedColumnWidth(_widths[i]),
        },
        children: [
          for (var rowIndex = 0; rowIndex < widget.rows.length; rowIndex++)
            TableRow(
              decoration: rowIndex == 0
                  ? BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    )
                  : null,
              children: [
                for (var column = 0; column < _widths.length; column++)
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: SelectableText(
                          column < widget.rows[rowIndex].length
                              ? widget.rows[rowIndex][column]
                              : '',
                          style: rowIndex == 0
                              ? const TextStyle(fontWeight: FontWeight.w700)
                              : null,
                        ),
                      ),
                      if (rowIndex == 0 && column < _widths.length - 1)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragUpdate: (details) => setState(
                              () => _widths[column] =
                                  (_widths[column] + details.delta.dx).clamp(
                                    72,
                                    420,
                                  ),
                            ),
                            child: const SizedBox(
                              width: 12,
                              child: Center(
                                child: VerticalDivider(width: 1, thickness: 2),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
