library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Deterministic procedural avatar geometry, ported line-for-line from
/// desktop's `hermes-bots/plugin.js` (`sigilRng`/`hashString`/`defaultShapeFor`
/// /`profileColor`/`botAppearance`/`sampleFaceRing`) so the same bot name
/// produces the exact same shape + color + face outline on both platforms,
/// not merely something visually similar.

const List<String> kAvatarShapes = [
  'circle',
  'squircle',
  'pill',
  'triangle',
  'hexagon',
  'cloud',
  'drop',
];

/// Curated palette offered by the avatar editor (`AVATAR_COLORS` in
/// `plugin.js`).
const List<Color> kAvatarColors = [
  Color(0xFFF5F5F4), // white
  Color(0xFF8D6748), // brown
  Color(0xFFEF4444), // red
  Color(0xFFF97316), // orange
  Color(0xFF14B8A6), // teal
  Color(0xFF38BDF8), // cyan
  Color(0xFF3B40C8), // royal blue
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // magenta
  Color(0xFF9CA3AF), // silver
];

const Color _kPrimaryColor = Color(0xFF8B5CF6);
const Color _kFallbackColor = Color(0xFF9CA3AF);

/// Same 32-bit FNV-ish multiply hash used by both `hashString`
/// (`profile-color.ts`) and `defaultShapeFor` (`plugin.js`) — `(hash*31 +
/// charCode) >>> 0` per character, replicated here via a mask instead of
/// JS's unsigned-shift coercion.
int hashProfileName(String value) {
  var hash = 0;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  return hash;
}

/// Deterministic per-name hue, or null for the untagged default profile —
/// mirrors `profileColor()` in `profile-color.ts`.
Color? profileColor(String? name) {
  final key = (name ?? '').trim();
  if (key.isEmpty || key == 'default') return null;
  final hue = (hashProfileName(key) % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.68, 0.58).toColor();
}

/// Mirrors `defaultShapeFor()` in `plugin.js`.
String defaultShapeFor(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0xFFFFFFFF;
  }
  return kAvatarShapes[hash % kAvatarShapes.length];
}

/// Perceptual luminance test — mirrors `isDarkColor()` in `plugin.js`, used
/// to flip eye/catchlight tint on dark bodies (ink, oxblood, etc).
bool isDarkColor(Color color) {
  final r = color.r * 255;
  final g = color.g * 255;
  final b = color.b * 255;
  return 0.2126 * r + 0.7152 * g + 0.0722 * b < 110;
}

class BotAppearance {
  final String shape;
  final Color color;
  final String? image;

  const BotAppearance({required this.shape, required this.color, this.image});
}

/// Mirrors `botAppearance(name, meta)` in `plugin.js`: the primary "default"
/// profile gets a fixed friendly violet squircle unless the user explicitly
/// customized it (`meta.custom === true`); everything else falls back to the
/// deterministic shape/color derived from its name.
BotAppearance botAppearance(String name, Map<String, dynamic>? meta) {
  final rawImage = meta?['image']?.toString();
  final image = (rawImage != null && rawImage.isNotEmpty) ? rawImage : null;
  final isPrimary = name.trim().toLowerCase() == 'default';
  final userCustomized = meta?['custom'] == true;

  if (isPrimary && !userCustomized) {
    return BotAppearance(shape: 'squircle', color: _kPrimaryColor, image: image);
  }

  final metaShape = meta?['shape']?.toString();
  final metaColorHex = meta?['color']?.toString();
  final shape = (metaShape != null && metaShape.isNotEmpty)
      ? metaShape
      : defaultShapeFor(name);
  final color = (metaColorHex != null && metaColorHex.isNotEmpty
          ? _parseHexColor(metaColorHex)
          : null) ??
      profileColor(name) ??
      _kFallbackColor;

  return BotAppearance(shape: shape, color: color, image: image);
}

Color? _parseHexColor(String hex) {
  final cleaned = hex.startsWith('#') ? hex.substring(1) : hex;
  final normalized = cleaned.length == 6 ? 'FF$cleaned' : cleaned;
  final parsed = int.tryParse(normalized, radix: 16);
  return parsed == null ? null : Color(parsed);
}

Offset _cubicAt(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
  final u = 1 - t;
  return Offset(
    u * u * u * p0.dx + 3 * u * u * t * p1.dx + 3 * u * t * t * p2.dx + t * t * t * p3.dx,
    u * u * u * p0.dy + 3 * u * u * t * p1.dy + 3 * u * t * t * p2.dy + t * t * t * p3.dy,
  );
}

class _Arc {
  final double cx, cy, rx, ry, theta1, dtheta;
  const _Arc(this.cx, this.cy, this.rx, this.ry, this.theta1, this.dtheta);
}

_Arc _svgArc(double x1, double y1, double rx, double ry, bool fa, bool fs, double x2, double y2) {
  final dx = (x1 - x2) / 2;
  final dy = (y1 - y2) / 2;
  var rx2 = rx * rx;
  var ry2 = ry * ry;
  final lam = (dx * dx) / rx2 + (dy * dy) / ry2;
  if (lam > 1) {
    final s = math.sqrt(lam);
    rx *= s;
    ry *= s;
    rx2 = rx * rx;
    ry2 = ry * ry;
  }
  final num = rx2 * ry2 - rx2 * dy * dy - ry2 * dx * dx;
  final den = rx2 * dy * dy + ry2 * dx * dx;
  var sq = math.sqrt(math.max(0, num / den));
  if (fa == fs) sq = -sq;
  final cx = sq * (rx * dy / ry) + (x1 + x2) / 2;
  final cy = sq * (-ry * dx / rx) + (y1 + y2) / 2;
  double ang(double ux, double uy, double vx, double vy) {
    final n = math.sqrt(ux * ux + uy * uy) * math.sqrt(vx * vx + vy * vy);
    final cosAngle = (n == 0 ? 0.0 : (ux * vx + uy * vy) / n).clamp(-1.0, 1.0);
    var a = math.acos(cosAngle);
    if (ux * vy - uy * vx < 0) a = -a;
    return a;
  }

  final theta1 = ang(1, 0, (x1 - cx) / rx, (y1 - cy) / ry);
  var dtheta = ang((x1 - cx) / rx, (y1 - cy) / ry, (x2 - cx) / rx, (y2 - cy) / ry);
  if (!fs && dtheta > 0) dtheta -= math.pi * 2;
  if (fs && dtheta < 0) dtheta += math.pi * 2;
  return _Arc(cx, cy, rx, ry, theta1, dtheta);
}

List<Offset> _sampleArc(_Arc arc, int n) {
  final pts = <Offset>[];
  for (var i = 0; i < n; i++) {
    final th = arc.theta1 + arc.dtheta * (i / n);
    pts.add(Offset(arc.cx + arc.rx * math.cos(th), arc.cy + arc.ry * math.sin(th)));
  }
  return pts;
}

List<Offset> _sampleDropRing(int steps) {
  final pts = <Offset>[];
  final n = math.max(8, (steps / 3).floor());
  for (var i = 0; i < n; i++) {
    pts.add(_cubicAt(
      const Offset(20, 3),
      const Offset(20, 3),
      const Offset(6, 20),
      const Offset(6, 27),
      i / n,
    ));
  }
  for (var i = 0; i <= n; i++) {
    final t = (i / n) * math.pi;
    pts.add(Offset(20 - 14 * math.cos(t), 27 + 13.5 * math.sin(t)));
  }
  for (var i = 1; i <= n; i++) {
    pts.add(_cubicAt(
      const Offset(34, 27),
      const Offset(34, 20),
      const Offset(20, 3),
      const Offset(20, 3),
      i / n,
    ));
  }
  return pts;
}

List<Offset> _sampleCloudRing(int steps) {
  final a1 = _svgArc(11, 32, 7.5, 7.5, false, true, 10, 17.1);
  final a2 = _svgArc(10, 17.1, 9.5, 9.5, false, true, 29, 12.5);
  final a3 = _svgArc(29, 12.5, 7, 7, false, true, 30, 32);
  final len1 = a1.dtheta.abs() * a1.rx;
  final len2 = a2.dtheta.abs() * a2.rx;
  final len3 = a3.dtheta.abs() * a3.rx;
  const len4 = 19.0;
  final total = len1 + len2 + len3 + len4;
  final n = math.max(64, steps);
  final n1 = math.max(8, (n * len1 / total).round());
  final n2 = math.max(10, (n * len2 / total).round());
  final n3 = math.max(10, (n * len3 / total).round());
  final n4 = math.max(4, n - n1 - n2 - n3);
  final pts = <Offset>[];
  pts.addAll(_sampleArc(a1, n1));
  pts.addAll(_sampleArc(a2, n2));
  pts.addAll(_sampleArc(a3, n3));
  for (var i = 0; i < n4; i++) {
    pts.add(Offset(30 + (11 - 30) * (i / n4), 32));
  }
  return pts;
}

/// Outline of a face in a 40x40 box — mirrors `sampleFaceRing()` in
/// `plugin.js`. `shape` is one of [kAvatarShapes]; unrecognized values (and
/// legacy `sigil-*` picks) fall back to a plain circle.
List<Offset> sampleFaceRing(String shape, {int steps = 52}) {
  final kind = shape.startsWith('sigil-') ? 'circle' : shape;
  if (kind == 'drop' || kind == 'teardrop') return _sampleDropRing(steps);
  if (kind == 'cloud') return _sampleCloudRing(steps);

  final pts = <Offset>[];
  for (var i = 0; i < steps; i++) {
    final a = (i / steps) * math.pi * 2 - math.pi / 2;
    final c = math.cos(a);
    final s = math.sin(a);
    double rx = 16, ry = 16;
    switch (kind) {
      case 'circle':
        rx = ry = 16.2;
        break;
      case 'blob':
        rx = ry = 16 + 1.7 * math.sin(3 * a) + 0.7 * math.cos(5 * a);
        break;
      case 'squircle':
        {
          const p = 5.0;
          final d = math.pow(c.abs(), p) + math.pow(s.abs(), p);
          rx = ry = 16.2 / (d == 0 ? 1 : math.pow(d, 1 / p));
        }
        break;
      case 'pill':
        {
          final d = math.pow(c.abs(), 8) + math.pow((s / 0.72).abs(), 8);
          rx = ry = 16 / (d == 0 ? 1 : math.pow(d, 1 / 8));
        }
        break;
      case 'triangle':
      case 'tetrahedron':
      case 'wedge':
        {
          final u = (a + math.pi / 2 + math.pi * 2) % (math.pi * 2);
          final sector = (u / (math.pi * 2 / 3)) % 1;
          rx = ry = 13.5 / math.max(0.42, math.cos((sector - 0.5) * 1.9));
        }
        break;
      case 'hexagon':
      case 'hex':
      case 'icosahedron':
      case 'dodecahedron':
        {
          final seg = math.pi / 3;
          final hex = math.cos(seg / 2) / math.cos(a - seg * (a / seg).round());
          rx = ry = 16.2 * hex;
        }
        break;
      case 'cube':
      case 'octahedron':
        {
          const p = 3.1;
          final d = math.pow(c.abs(), p) + math.pow(s.abs(), p);
          rx = ry = 16 / (d == 0 ? 1 : math.pow(d, 1 / p));
        }
        break;
      case 'pebble':
        rx = 16.4 * (1.04 - 0.14 * math.cos(2 * a));
        ry = 15.2 * (1.06 + 0.08 * math.sin(2 * a));
        break;
      default:
        rx = ry = 16.2;
    }
    pts.add(Offset(20 + rx * c, 20 + ry * s));
  }
  return pts;
}

class FacePose {
  final double turn, tilt, roll, gazeX, gazeY, d0, d1, d2;
  final bool blink;

  const FacePose({
    required this.turn,
    required this.tilt,
    required this.roll,
    required this.gazeX,
    required this.gazeY,
    required this.blink,
    required this.d0,
    required this.d1,
    required this.d2,
  });
}

/// Mirrors `facePose(mood, t)` in `plugin.js`: 'work' leans/sways/gazes with
/// pulsing thinking-dots, 'idle' just breathes with an occasional blink.
FacePose facePose(String mood, double t) {
  if (mood == 'work') {
    return FacePose(
      turn: -11 + math.sin(t * 0.48) * 8,
      tilt: math.sin(t * 0.42) * 8 + math.sin(t * 1.1) * 1.6,
      roll: math.sin(t * 0.75) * 4.2,
      gazeX: math.sin(t * 0.55) * 3.6,
      gazeY: -1.6 + math.sin(t * 0.38) * 2,
      blink: t % 1.45 > 1.26,
      d0: 0.2 + 0.8 * math.max(0.0, math.sin(t * 2.6)),
      d1: 0.2 + 0.8 * math.max(0.0, math.sin(t * 2.6 - 0.7)),
      d2: 0.2 + 0.8 * math.max(0.0, math.sin(t * 2.6 - 1.4)),
    );
  }
  return FacePose(
    turn: math.sin(t * 0.5) * 1.5,
    tilt: math.sin(t * 0.27),
    roll: math.sin(t * 0.85) * 1.2,
    gazeX: 0,
    gazeY: 0,
    blink: t % 3.2 > 3.02,
    d0: 0,
    d1: 0,
    d2: 0,
  );
}

/// Mirrors the squash-projection in `paintMathFace()` that fakes a 3D
/// turn/tilt/roll of the face body.
Offset projectFacePoint(double x, double y, double turn, double tilt, double roll) {
  final dx = x - 20;
  final dy = y - 20;
  final r = roll * math.pi / 180;
  final xr = dx * math.cos(r) - dy * math.sin(r);
  final yr = dx * math.sin(r) + dy * math.cos(r);
  final sx = 0.74 + 0.26 * (math.cos(turn * math.pi / 180)).abs();
  final sy = 0.8 + 0.2 * (math.cos(tilt * math.pi / 180)).abs();
  return Offset(20 + xr * sx, 20 + yr * sy);
}

Path ringToPath(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  path.moveTo(pts.first.dx, pts.first.dy);
  for (final p in pts.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  path.close();
  return path;
}

/// Static cloud-body path (three puffs + flat floor) — mirrors the literal
/// `M11 32 a7.5...Z` path desktop draws directly instead of sampling a ring.
Path cloudBodyPath() {
  return Path()
    ..moveTo(11, 32)
    ..arcToPoint(const Offset(10, 17.1), radius: const Radius.circular(7.5))
    ..arcToPoint(const Offset(29, 12.5), radius: const Radius.circular(9.5))
    ..arcToPoint(const Offset(30, 32), radius: const Radius.circular(7))
    ..close();
}

/// Center-crops [bytes] to a square and downscales to [edge]x[edge] PNG
/// bytes, mirroring desktop's `normalizeAvatarImage` canvas crop so uploaded
/// photos stay small enough for `profiles.set_asset`.
Future<Uint8List> normalizeAvatarImage(Uint8List bytes, {int edge = 256}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final side = math.min(image.width, image.height).toDouble();
  final srcRect = Rect.fromLTWH(
    (image.width - side) / 2,
    (image.height - side) / 2,
    side,
    side,
  );
  final dstRect = Rect.fromLTWH(0, 0, edge.toDouble(), edge.toDouble());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, dstRect);
  canvas.drawImageRect(image, srcRect, dstRect, Paint());
  final picture = recorder.endRecording();
  final output = await picture.toImage(edge, edge);
  final pngData = await output.toByteData(format: ui.ImageByteFormat.png);
  return pngData!.buffer.asUint8List();
}

/// True if [dataUrl] is a 160x160 PNG — the size desktop rasterizes the
/// live procedural face to when it needs a static image for inter-agent
/// notices. Uploads are 256x256, pet icons are 96x104, so any 160x160 PNG
/// is unambiguously that synthetic raster, never a real photo. Mirrors
/// desktop's `isBackfilledFacePng`, which exists so a synced snapshot of
/// that raster never clobbers a device's own live procedural rendering.
bool isBackfilledFacePng(String? dataUrl) {
  const prefix = 'data:image/png;base64,';
  if (dataUrl == null || !dataUrl.startsWith(prefix)) return false;
  try {
    final bytes = base64Decode(dataUrl.substring(prefix.length));
    if (bytes.length < 24) return false;
    final width = ByteData.sublistView(bytes, 16, 20).getUint32(0);
    final height = ByteData.sublistView(bytes, 20, 24).getUint32(0);
    return width == 160 && height == 160;
  } catch (_) {
    return false;
  }
}
