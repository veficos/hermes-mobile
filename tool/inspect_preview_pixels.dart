import 'dart:io';
import 'package:image/image.dart' as img;

// Read-only PNG inspection, independent of the conversation image viewer.
void main(List<String> paths) {
  if (paths.length == 3 && paths.first == '--compare') {
    final a = img.decodePng(File(paths[1]).readAsBytesSync())!;
    final b = img.decodePng(File(paths[2]).readAsBytesSync())!;
    if (a.width != b.width || a.height != b.height) {
      throw StateError('Comparison requires equal dimensions');
    }
    var count = 0, strong = 0, maximum = 0;
    var left = a.width, top = a.height, right = -1, bottom = -1;
    final bands = <int, int>{};
    for (var y = 0; y < a.height; y++) {
      for (var x = 0; x < a.width; x++) {
        final p = a.getPixel(x, y), q = b.getPixel(x, y);
        final deltas = [
          (p.r - q.r).abs(),
          (p.g - q.g).abs(),
          (p.b - q.b).abs(),
          (p.a - q.a).abs(),
        ];
        final delta = deltas.reduce((a, b) => a > b ? a : b).toInt();
        if (delta == 0) continue;
        count++;
        if (delta > 10) strong++;
        if (delta > maximum) maximum = delta;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
        bands.update(y ~/ 20, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    stdout.writeln(
      'changed=$count total=${a.width * a.height} strong(>10)=$strong max=$maximum',
    );
    stdout.writeln('bounds=$left,$top to $right,$bottom; 20px bands=$bands');
    return;
  }
  for (final path in paths) {
    final image = img.decodePng(File(path).readAsBytesSync());
    if (image == null) throw FormatException('Not a PNG: $path');
    final colors = <String, int>{};
    for (var y = 0; y < 60 && y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final key = '${pixel.r},${pixel.g},${pixel.b},${pixel.a}';
        colors.update(key, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    final ranked = colors.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    stdout.writeln('$path: ${image.width}x${image.height}');
    stdout.writeln('Top 60 rows: ${ranked.take(4).join('; ')}');
    if (image.height > 200 && image.width >= 100) {
      stdout.writeln(
        'Row 200, x80–99: ${[for (var x = 80; x < 100; x++) '${image.getPixel(x, 200).r}/${image.getPixel(x, 200).g}/${image.getPixel(x, 200).b}'].join(', ')}',
      );
    }
  }
}
