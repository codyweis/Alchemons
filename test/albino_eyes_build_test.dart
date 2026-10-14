@Tags(['preview'])
library;

// Builds the red eyes an albino of a polished species (Lets, Pips, Horns,
// Wings) is baked with, one overlay per species, written beside its sheet:
//
//   ALBINO_EYES=all flutter test test/albino_eyes_build_test.dart
//   ALBINO_EYES=LET01,PIP02 ALBINO_EYES_REVIEW=/tmp/eyes.png flutter test …
//
// Each eye is found where the sunglasses sit on it (their fitted place and
// eye-to-eye spacing in costume_fits.dart, frame by frame), grown out over
// the iris's own color, its pupil and glints filled in, and recolored on a
// crimson-to-pink ramp by its own light and shade. A white glint in a
// colored eye is left out, so it stays white. The overlay is written at the
// size an albino sheet is baked at (mutation_sheets.dart). A species whose
// eyes are drawn closed or as bare rings gets none: see [_tunes].
//
// ALBINO_EYES_REVIEW also writes a sheet of every species built, albino with
// its eyes, whole and close up, to check them by.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/alchemical_sunglasses.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

/// How one species' eyes are found, where the defaults miss.
class _Tune {
  const _Tune({
    this.nudge = const [],
    this.tolerance,
    this.reach = 0.5,
    this.outlined = false,
    this.carry = false,
    this.lit = false,
    this.ovals,
    this.skip = false,
  });

  /// Moves each eye's seed off its fitted place, as fractions of the frame
  /// (far eye first, as the sunglasses order them).
  final List<(double, double)> nudge;

  /// How far (CIELAB ΔE) a pixel's color may stray from the iris's and
  /// still be eye. Unset, the first of [_tolerances] that keeps the eye
  /// inside its reach.
  final double? tolerance;

  /// The farthest an eye reaches from its seed, in eye-to-eye spacings.
  final double reach;

  /// Found by its outline, not its color: an eye drawn in the skin's own
  /// color.
  final bool outlined;

  /// Found in frame 0 only and carried along with the head: an eye that
  /// pulses or flashes from frame to frame.
  final bool carry;

  /// The iris's color read from its lit pixels only, past a dark lid or
  /// pupil the seed also covers.
  final bool lit;

  /// Each eye as an oval (half width, half height as fractions of the frame's
  /// width, and its turn in radians) about its seed: everything inside of
  /// the eye's color ([tolerance], or all of it unset) is eye. For a dark
  /// eye whose fill runs on into a dark outline, or a ring.
  final List<(double, double, double)>? ovals;

  /// No eyes to color: drawn closed, or as bare rings on the skin.
  final bool skip;
}

const _tunes = <String, _Tune>{
  // Seeds moved off a lid, a glint or a pupil onto the iris.
  'HOR08': _Tune(nudge: [(-0.010, 0.005), (0.012, 0.001)]),
  'LET11': _Tune(nudge: [(0.019, 0.007), (-0.024, 0.001)]),
  'LET12': _Tune(nudge: [(0.033, -0.002), (-0.034, -0.002)]),
  'LET13': _Tune(nudge: [(-0.010, -0.002), (0.012, 0.002)]),
  'LET17': _Tune(nudge: [(-0.006, 0.0), (0.006, 0.001)], tolerance: 10),
  'PIP11': _Tune(nudge: [(-0.006, 0.005), (0.024, 0.011)]),
  'WNG07': _Tune(nudge: [(0.017, -0.006)]),
  'WNG10': _Tune(nudge: [(0.012, 0.005)]),
  // Small or dark eyes beside skin of nearly their own color.
  // An eye wider than half the glasses' spacing.
  'PIP14': _Tune(reach: 1.0),
  // Rings, and red eyes in red skin: inside their outline.
  'LET16': _Tune(nudge: [(-0.014, -0.001), (0.014, -0.001)], outlined: true),
  // Black eyes running on into black outlines, and bare rings: ovals.
  'HOR15': _Tune(
    nudge: [(0.0015, 0.0134), (-0.0055, 0.0197)],
    ovals: [(0.014, 0.027, 0.0), (0.028, 0.023, 0.0)],
    tolerance: 8,
  ),
  'PIP15': _Tune(
    ovals: [(0.022, 0.033, 0.0), (0.056, 0.037, -0.35)],
    tolerance: 8,
  ),
  'WNG15': _Tune(
    nudge: [(0.0043, 0.002), (-0.005, -0.0025)],
    ovals: [(0.0065, 0.024, 0.0), (0.018, 0.017, 0.0)],
    tolerance: 15,
    carry: true,
  ),
  'PIP03': _Tune(
    ovals: [(0.014, 0.011, 0.0), (0.014, 0.011, 0.0)],
    tolerance: 12,
  ),
  'PIP17': _Tune(
    ovals: [(0.017, 0.025, 0.0), (0.06, 0.04, -0.3)],
    tolerance: 30,
  ),
  'WNG03': _Tune(
    nudge: [(0.0088, -0.0015), (-0.0128, -0.0015)],
    ovals: [(0.012, 0.007, 0.0), (0.0146, 0.007, 0.0)],
  ),
  'LET09': _Tune(
    nudge: [(0.0176, -0.0154), (-0.033, -0.011)],
    ovals: [(0.012, 0.019, 0.0), (0.012, 0.019, 0.0)],
  ),
  // An iris that is only a pupil, or a seed that keeps catching the skin
  // round the eye or a big glint: ovals too.
  'HOR09': _Tune(
    nudge: [(0.0055, 0.0098), (0.0069, 0.0098)],
    ovals: [(0.0094, 0.0209, 0.0), (0.0073, 0.0209, 0.0)],
    tolerance: 25,
  ),
  'HOR07': _Tune(
    nudge: [(-0.0017, 0.0112), (0.0038, 0.0032)],
    ovals: [(0.021, 0.015, 0.5), (0.044, 0.018, 0.42)],
    tolerance: 35,
    lit: true,
  ),
  'HOR13': _Tune(
    nudge: [(-0.0026, 0.015), (-0.0009, 0.0184)],
    ovals: [(0.0127, 0.0102, 0.3), (0.0407, 0.0178, -0.25)],
    tolerance: 40,
  ),
  'PIP01': _Tune(
    nudge: [(0.0, -0.0115), (0.0002, 0.0075)],
    ovals: [(0.026, 0.0455, 0.0), (0.0512, 0.0529, 0.0)],
    tolerance: 40,
    lit: true,
  ),
  'WNG09': _Tune(nudge: [(-0.0037, -0.0019)], ovals: [(0.004, 0.0075, 0.0)]),
  'LET06': _Tune(
    nudge: [(-0.0009, -0.0128), (0.0020, -0.0034)],
    ovals: [(0.0264, 0.0519, -0.5), (0.0548, 0.0283, -0.5)],
  ),
  'LET10': _Tune(
    nudge: [(0.0022, 0.0008), (-0.0040, 0.0008)],
    ovals: [(0.0328, 0.0510, 0.0), (0.0328, 0.0510, 0.0)],
  ),
  'PIP13': _Tune(
    nudge: [(-0.0022, -0.0034), (0.0228, -0.0079)],
    ovals: [(0.0224, 0.0269, 0.0), (0.0448, 0.0224, -0.3)],
    tolerance: 25,
  ),
  'WNG12': _Tune(
    nudge: [(-0.0087, 0.0051)],
    ovals: [(0.0064, 0.0128, 0.0)],
    tolerance: 25,
  ),
  'WNG13': _Tune(
    nudge: [(-0.0036, -0.0036)],
    ovals: [(0.0256, 0.0106, -0.4)],
    tolerance: 45,
  ),
  // Eyes that glow up and fade, or flash.
  'LET15': _Tune(nudge: [(0.027, 0.0), (-0.026, 0.0)], carry: true),
  'PIP07': _Tune(nudge: [(-0.005, 0.021), (0.001, 0.024)], carry: true),
  // Drawn shut.
  'LET04': _Tune(skip: true),
};

const _tolerances = [24.0, 17.0, 12.0, 8.0];

void main() {
  test('build albino eyes', () async {
    final only = Platform.environment['ALBINO_EYES'];
    if (only == null) return;
    final review = Platform.environment['ALBINO_EYES_REVIEW'];
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final entries = (data['creatures'] as List).cast<Map<String, dynamic>>();
    final fits = FamilyCostume.sunglasses.placements;
    final ids = only == 'all' ? (fits.keys.toList()..sort()) : only.split(',');
    final tiles = <_Tile>[];
    final built = <String>[];
    for (final id in ids) {
      final tune = _tunes[id] ?? const _Tune();
      final e = entries.singleWhere((x) => x['id'] == id);
      final sd = e['spriteData'] as Map<String, dynamic>;
      final sheetPath =
          'assets/images/${(e['image'] as String).replaceAll('.png', '_spritesheet.png')}';
      final sheet = await _decode(sheetPath);
      final fw = (sd['frameWidth'] as num).toInt();
      final fh = (sd['frameHeight'] as num).toInt();
      final frames = (sd['totalFrames'] as num).toInt();
      final rows = (sd['rows'] as num?)?.toInt() ?? 1;
      final cols = (frames + rows - 1) ~/ rows;

      final overlay = Uint8List(sheet.w * sheet.h * 4);
      if (!tune.skip) {
        // Each eye found in every frame (or, for an eye that pulses or
        // flashes, found in frame 0 and carried along with the head).
        final found = <List<_Eye?>>[];
        final origins = <(int, int)>[];
        for (var f = 0; f < frames; f++) {
          final ox = (f % cols) * fw, oy = (f ~/ cols) * fh;
          origins.add((ox, oy));
          final fit = FamilyCostume.sunglasses.fitAt(id, f)!;
          final centers = _eyeCenters(id, fit);
          final row = <_Eye?>[];
          for (var i = 0; i < centers.length; i++) {
            final nudge = i < tune.nudge.length ? tune.nudge[i] : (0.0, 0.0);
            final cx = ox + (centers[i].$1 + nudge.$1) * fw;
            final cy = oy + (centers[i].$2 + nudge.$2) * fh;
            final first = f == 0 ? null : found.first[i];
            row.add(
              tune.carry && first != null
                  ? first.movedTo(sheet, cx, cy)
                  : _findEye(
                      sheet,
                      cx,
                      cy,
                      fit.size * fw,
                      tune,
                      (ox, oy, ox + fw, oy + fh),
                      oval: tune.ovals?[i],
                      frameW: fw,
                    ),
            );
          }
          found.add(row);
        }
        for (var i = 0; i < found.first.length; i++) {
          final eyes = [for (final row in found) row[i]];
          final areas = [for (final e in eyes) e?.pixels.length ?? 0];
          // An eye that grows a lot bigger or smaller between frames has
          // leaked into the skin in one, or lost its iris.
          final lo = areas.reduce(math.min), hi = areas.reduce(math.max);
          if (lo == 0 || hi / lo > 1.5) {
            // ignore: avoid_print
            print('CHECK $id eye $i: areas $areas');
          }
          _paintEyes(sheet, overlay, eyes.whereType<_Eye>().toList());
        }
        built.add(id);
      }

      // Written at the size the albino sheet is baked at.
      final (bfw, bfh) = bakedFrameSize(fw.toDouble(), fh.toDouble());
      final bw = bfw * cols, bh = bfh * rows;
      if (!tune.skip) {
        final small = _areaResize(overlay, sheet.w, sheet.h, bw, bh);
        final out = sheetPath.replaceAll(
          '_spritesheet.png',
          '_albino_eyes.png',
        );
        File(out).writeAsBytesSync(await _png(small, bw, bh));
      }
      if (review != null) {
        // As the game bakes it: the albino body with these eyes over it.
        final baked = albinoRgba(
          MutationBakeJob(
            rgba: sheet.rgba,
            width: sheet.w,
            height: sheet.h,
            frameW: fw,
            frameH: fh,
            cols: cols,
            frames: frames,
            look: MutationLook.albino,
            eyes: overlay,
          ),
        );
        tiles.add(_tile(id, sheet.w, baked, fw, fh, tune.skip));
      }
      // ignore: avoid_print
      print('${tune.skip ? 'skipped' : 'built'} $id');
    }
    if (review != null) await _writeReview(review, tiles);
    // ignore: avoid_print
    print('\nwith eyes: ${built.join(', ')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}

/// The eyes' centers in frame fractions: both for a face seen front or
/// three-quarters on, the far one first; the one for a profile.
List<(double, double)> _eyeCenters(
  String id,
  ({double x, double y, double size, double tilt}) fit,
) {
  if (GlassesView.of(id) == GlassesView.profile) return [(fit.x, fit.y)];
  final dx = 0.5 * fit.size * math.cos(fit.tilt);
  final dy = 0.5 * fit.size * math.sin(fit.tilt);
  return [(fit.x - dx, fit.y - dy), (fit.x + dx, fit.y + dy)];
}

class _Sheet {
  _Sheet(this.w, this.h, this.rgba);
  final int w, h;

  /// Straight-alpha RGBA.
  final Uint8List rgba;
}

Future<_Sheet> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final image = (await codec.getNextFrame()).image;
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  ))!.buffer.asUint8List();
  final s = _Sheet(image.width, image.height, Uint8List.fromList(bytes));
  image.dispose();
  codec.dispose();
  return s;
}

// ── color ────────────────────────────────────────────────────────────────

double _lin(int c) {
  final v = c / 255.0;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _f(double t) =>
    t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;

/// CIELAB (D65) of a pixel.
(double, double, double) _lab(Uint8List p, int o) {
  final r = _lin(p[o]), g = _lin(p[o + 1]), b = _lin(p[o + 2]);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  final fx = _f(x), fy = _f(y), fz = _f(z);
  return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

double _de((double, double, double) a, (double, double, double) b) {
  final dl = a.$1 - b.$1, da = a.$2 - b.$2, db = a.$3 - b.$3;
  return math.sqrt(dl * dl + da * da + db * db);
}

/// A white glint (or a white of the eye): bright and nearly colorless.
bool _isGlint((double, double, double) c) =>
    c.$1 > 86 && math.sqrt(c.$2 * c.$2 + c.$3 * c.$3) < 18;

/// The albino eye, dark to light: deep crimson in shadow, red through the
/// iris, pink where it catches the light.
const List<(double, int)> _eyeRamp = [
  (0.00, 0x3A040C),
  (0.30, 0x8E0F1E),
  (0.50, 0xC8222F),
  (0.72, 0xEE5560),
  (1.00, 0xFFB8BE),
];

int _rampAt(double v) {
  for (var i = 1; i < _eyeRamp.length; i++) {
    final (p1, c1) = _eyeRamp[i];
    if (v <= p1 || i == _eyeRamp.length - 1) {
      final (p0, c0) = _eyeRamp[i - 1];
      final t = ((v - p0) / (p1 - p0)).clamp(0.0, 1.0);
      int ch(int s) =>
          (((c0 >> s) & 0xFF) + (((c1 >> s) & 0xFF) - ((c0 >> s) & 0xFF)) * t)
              .round();
      return (ch(16) << 16) | (ch(8) << 8) | ch(0);
    }
  }
  return _eyeRamp.last.$2;
}

// ── one eye ──────────────────────────────────────────────────────────────

/// One eye in one frame: its pixels, as byte offsets into the sheet.
class _Eye {
  _Eye(this.pixels, this.cx, this.cy, {required this.white});

  final List<int> pixels;

  /// Where it was seeded, in sheet pixels.
  final double cx, cy;

  /// Drawn in the skin's color or white, glints and all: every pixel of it
  /// turns red.
  final bool white;

  /// The same shape seeded at ([x], [y]) instead.
  _Eye movedTo(_Sheet s, double x, double y) {
    final dx = (x - cx).round(), dy = (y - cy).round();
    return _Eye(
      [
        for (final o in pixels)
          ((o ~/ 4) ~/ s.w + dy) * s.w * 4 + ((o ~/ 4) % s.w + dx) * 4,
      ],
      x,
      y,
      white: white,
    );
  }
}

/// Finds the eye seeded at ([cx], [cy]) in sheet pixels, inside [frame]
/// (left, top, right, bottom). [spacing] is the eye-to-eye distance in
/// pixels. Null when nothing there stays inside an eye's reach.
_Eye? _findEye(
  _Sheet s,
  double cx,
  double cy,
  double spacing,
  _Tune tune,
  (int, int, int, int) frame, {
  (double, double, double)? oval,
  int frameW = 0,
}) {
  final reach = oval == null
      ? math.max(6.0, spacing * tune.reach)
      : math.max(oval.$1, oval.$2) * frameW + 2;
  final x0 = math.max(frame.$1, (cx - reach).floor());
  final y0 = math.max(frame.$2, (cy - reach).floor());
  final x1 = math.min(frame.$3 - 1, (cx + reach).ceil());
  final y1 = math.min(frame.$4 - 1, (cy + reach).ceil());
  final ww = x1 - x0 + 1, wh = y1 - y0 + 1;
  if (ww <= 2 || wh <= 2) return null;
  final px = s.rgba;
  int at(int x, int y) => (y * s.w + x) * 4;
  final labs = List<(double, double, double)?>.filled(ww * wh, null);
  (double, double, double)? labAt(int x, int y) {
    final o = at(x, y);
    if (px[o + 3] < 128) return null;
    return labs[(y - y0) * ww + (x - x0)] ??= _lab(px, o);
  }

  bool inReach(int x, int y) {
    final dx = x - cx, dy = y - cy;
    return dx * dx + dy * dy <= reach * reach;
  }

  // The iris's color: the middle of what sits round the seed, glints aside
  // (unless the eye is all glint — a white eye).
  final r0 = math.max(2.0, spacing * 0.07);
  final near = <(double, double, double)>[];
  final seeds = <(int, int)>[];
  for (var y = (cy - r0).floor(); y <= (cy + r0).ceil(); y++) {
    for (var x = (cx - r0).floor(); x <= (cx + r0).ceil(); x++) {
      if (x < x0 || x > x1 || y < y0 || y > y1) continue;
      if ((x - cx) * (x - cx) + (y - cy) * (y - cy) > r0 * r0) continue;
      final c = labAt(x, y);
      if (c == null) continue;
      near.add(c);
      seeds.add((x, y));
    }
  }
  if (near.isEmpty) return null;
  final colored = near
      .where((c) => !_isGlint(c) && (!tune.lit || c.$1 > 25))
      .toList();
  final pool = colored.length * 4 >= near.length ? colored : near;
  double med(double Function((double, double, double)) by) {
    final v = pool.map(by).toList()..sort();
    return v[v.length ~/ 2];
  }

  final iris = (med((c) => c.$1), med((c) => c.$2), med((c) => c.$3));

  // Grow over the iris's color, tighter until it stays inside the eye; then,
  // for an eye drawn in the skin's own color (a white eye, a ring), over
  // anything not darker than it — the eye's outline closes it in.
  final queue = Queue<(int, int)>();
  (Uint8List, Uint8List)? grow(bool Function((double, double, double)) joins) {
    final inEye = Uint8List(ww * wh);
    for (final (x, y) in seeds) {
      if (!joins(labAt(x, y)!)) continue;
      inEye[(y - y0) * ww + (x - x0)] = 1;
      queue.add((x, y));
    }
    var size = 0, rim = 0;
    final rimR = reach * 0.9;
    while (queue.isNotEmpty) {
      final (x, y) = queue.removeFirst();
      size++;
      if ((x - cx) * (x - cx) + (y - cy) * (y - cy) > rimR * rimR) rim++;
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (nx < x0 || nx > x1 || ny < y0 || ny > y1) continue;
        final i = (ny - y0) * ww + (nx - x0);
        if (inEye[i] == 1 || !inReach(nx, ny)) continue;
        final c = labAt(nx, ny);
        if (c == null || !joins(c)) continue;
        inEye[i] = 1;
        queue.add((nx, ny));
      }
    }
    // Out to the edge of its reach: it got out of the eye.
    if (size == 0 || rim > math.max(3, size * 0.02)) return null;

    // Fill what it closes round — the pupil, a glint — from the window's
    // edge inward.
    final outside = Uint8List(ww * wh);
    void edge(int x, int y) {
      final i = y * ww + x;
      if (inEye[i] == 0 && outside[i] == 0) {
        outside[i] = 1;
        queue.add((x, y));
      }
    }

    for (var x = 0; x < ww; x++) {
      edge(x, 0);
      edge(x, wh - 1);
    }
    for (var y = 0; y < wh; y++) {
      edge(0, y);
      edge(ww - 1, y);
    }
    while (queue.isNotEmpty) {
      final (x, y) = queue.removeFirst();
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (nx < 0 || nx >= ww || ny < 0 || ny >= wh) continue;
        final i = ny * ww + nx;
        if (inEye[i] == 1 || outside[i] == 1) continue;
        outside[i] = 1;
        queue.add((nx, ny));
      }
    }
    return (inEye, outside);
  }

  if (oval != null) {
    final (rx, ry, turn) = oval;
    final cs = math.cos(turn), sn = math.sin(turn);
    final tol = tune.tolerance ?? double.infinity;
    return _Eye(
      [
        for (var y = y0; y <= y1; y++)
          for (var x = x0; x <= x1; x++)
            if (() {
              final dx = x - cx, dy = y - cy;
              final u = (dx * cs + dy * sn) / (rx * frameW);
              final v = (-dx * sn + dy * cs) / (ry * frameW);
              if (u * u + v * v > 1) return false;
              final c = labAt(x, y);
              return c != null && _de(c, iris) <= tol;
            }())
              at(x, y),
      ],
      cx,
      cy,
      white: tol.isInfinite,
    );
  }

  (Uint8List, Uint8List)? found;
  var whiteEye = identical(pool, near) && near.every(_isGlint);
  if (!tune.outlined) {
    for (final t in tune.tolerance != null ? [tune.tolerance!] : _tolerances) {
      found = grow((c) => _de(c, iris) <= t);
      if (found != null) break;
    }
  }
  if (found == null) {
    // Its outline: anything 28 L* darker than it.
    found = grow((c) => c.$1 >= iris.$1 - 28 && _de(c, iris) <= 45);
    whiteEye = true;
  }
  if (found == null) return null;
  final (inEye, outside) = found;
  return _Eye(
    [
      for (var y = y0; y <= y1; y++)
        for (var x = x0; x <= x1; x++)
          if (inEye[(y - y0) * ww + (x - x0)] == 1 ||
              outside[(y - y0) * ww + (x - x0)] == 0)
            if (px[at(x, y) + 3] > 0) at(x, y),
    ],
    cx,
    cy,
    white: whiteEye,
  );
}

/// Paints one eye, every frame of it, red into [overlay]: the iris's middle
/// light (over all its frames, so an eye that pulses still pulses) sits on
/// the ramp's red, its shadows deeper, its light pinker. A glint in a
/// colored eye is left out, to stay white.
void _paintEyes(_Sheet s, Uint8List overlay, List<_Eye> eyes) {
  if (eyes.isEmpty) return;
  final px = s.rgba;
  final white = eyes.first.white;
  final ls = <double>[];
  for (final e in eyes) {
    for (final o in e.pixels) {
      final c = _lab(px, o);
      if (white || !_isGlint(c)) ls.add(c.$1);
    }
  }
  if (ls.isEmpty) return;
  ls.sort();
  final mid = ls[ls.length ~/ 2];
  for (final e in eyes) {
    for (final o in e.pixels) {
      final a = px[o + 3];
      if (a == 0) continue;
      final c = _lab(px, o);
      if (!white && _isGlint(c)) continue;
      final rgb = _rampAt((0.5 + (c.$1 - mid) / 80).clamp(0.0, 1.0));
      overlay[o] = (rgb >> 16) & 0xFF;
      overlay[o + 1] = (rgb >> 8) & 0xFF;
      overlay[o + 2] = rgb & 0xFF;
      overlay[o + 3] = a;
    }
  }
}

// ── output ───────────────────────────────────────────────────────────────

/// Straight RGBA [w]×[h] → [tw]×[th], each target pixel the coverage-weighted
/// mean of the source pixels under it (straight color averaged over
/// coverage, so an edge keeps its red instead of greying into the clear).
Uint8List _areaResize(Uint8List src, int w, int h, int tw, int th) {
  final out = Uint8List(tw * th * 4);
  final sx = w / tw, sy = h / th;
  for (var ty = 0; ty < th; ty++) {
    final fy0 = ty * sy, fy1 = (ty + 1) * sy;
    for (var tx = 0; tx < tw; tx++) {
      final fx0 = tx * sx, fx1 = (tx + 1) * sx;
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0, area = 0.0;
      for (var y = fy0.floor(); y < fy1.ceil() && y < h; y++) {
        final wy = math.min(fy1, y + 1.0) - math.max(fy0, y.toDouble());
        for (var x = fx0.floor(); x < fx1.ceil() && x < w; x++) {
          final wx = math.min(fx1, x + 1.0) - math.max(fx0, x.toDouble());
          final wgt = wx * wy;
          final o = (y * w + x) * 4;
          final al = src[o + 3] / 255.0 * wgt;
          r += src[o] * al;
          g += src[o + 1] * al;
          b += src[o + 2] * al;
          a += al;
          area += wgt;
        }
      }
      final o = (ty * tw + tx) * 4;
      if (a <= 0) continue;
      out[o] = (r / a).round().clamp(0, 255);
      out[o + 1] = (g / a).round().clamp(0, 255);
      out[o + 2] = (b / a).round().clamp(0, 255);
      out[o + 3] = (a / area * 255).round().clamp(0, 255);
    }
  }
  return out;
}

/// PNG bytes of straight RGBA.
Future<Uint8List> _png(Uint8List straight, int w, int h) async {
  final pre = Uint8List(straight.length);
  for (var o = 0; o < straight.length; o += 4) {
    final a = straight[o + 3];
    pre[o] = (straight[o] * a / 255).round();
    pre[o + 1] = (straight[o + 1] * a / 255).round();
    pre[o + 2] = (straight[o + 2] * a / 255).round();
    pre[o + 3] = a;
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(pre, w, h, ui.PixelFormat.rgba8888, done.complete);
  final image = await done.future;
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return bytes.buffer.asUint8List();
}

// ── review ───────────────────────────────────────────────────────────────

class _Tile {
  _Tile(this.id, this.w, this.h, this.rgba);
  final String id;
  final int w, h;
  final Uint8List rgba;
}

const _tileW = 360, _tileH = 200;

/// Frame 0 of [id] from its [baked] (premultiplied) albino sheet, on the
/// review's ink: the whole creature at left, its eyes close up at right.
_Tile _tile(
  String id,
  int sheetW,
  Uint8List baked,
  int fw,
  int fh,
  bool skipped,
) {
  final out = Uint8List(_tileW * _tileH * 4);
  for (var o = 0; o < out.length; o += 4) {
    out[o] = 18;
    out[o + 1] = 17;
    out[o + 2] = 22;
    out[o + 3] = 255;
  }
  void blit(
    double sx0,
    double sy0,
    double sw,
    double sh,
    int dx,
    int dy,
    int dw,
    int dh,
  ) {
    for (var y = 0; y < dh; y++) {
      for (var x = 0; x < dw; x++) {
        final sx = (sx0 + (x + 0.5) * sw / dw).floor();
        final sy = (sy0 + (y + 0.5) * sh / dh).floor();
        if (sx < 0 || sy < 0 || sx >= fw || sy >= fh) continue;
        final o = (sy * sheetW + sx) * 4;
        final a = baked[o + 3] / 255.0;
        if (a == 0) continue;
        final d = ((dy + y) * _tileW + dx + x) * 4;
        for (var k = 0; k < 3; k++) {
          out[d + k] = (out[d + k] * (1 - a) + baked[o + k]).round().clamp(
            0,
            255,
          );
        }
      }
    }
  }

  blit(0, 0, fw.toDouble(), fh.toDouble(), 0, 0, _tileH, _tileH);
  final fit = FamilyCostume.sunglasses.fitAt(id, 0)!;
  final half = math.max(0.07, fit.size * 0.85) * fw;
  blit(
    fit.x * fw - half,
    fit.y * fh - half * 0.62,
    half * 2,
    half * 1.25,
    _tileH,
    0,
    _tileW - _tileH,
    _tileH,
  );
  if (skipped) {
    for (var x = 0; x < _tileW; x++) {
      for (final y in [0, 1, _tileH - 2, _tileH - 1]) {
        final d = (y * _tileW + x) * 4;
        out[d] = 200;
        out[d + 1] = 60;
        out[d + 2] = 60;
      }
    }
  }
  return _Tile(id, _tileW, _tileH, out);
}

Future<void> _writeReview(String path, List<_Tile> tiles) async {
  const per = 4;
  final rows = (tiles.length + per - 1) ~/ per;
  final w = per * (_tileW + 6), h = rows * (_tileH + 6);
  final out = Uint8List(w * h * 4);
  for (var i = 0; i < tiles.length; i++) {
    final t = tiles[i];
    final ox = (i % per) * (_tileW + 6), oy = (i ~/ per) * (_tileH + 6);
    for (var y = 0; y < t.h; y++) {
      out.setRange(
        ((oy + y) * w + ox) * 4,
        ((oy + y) * w + ox + t.w) * 4,
        t.rgba,
        y * t.w * 4,
      );
    }
  }
  File(path).writeAsBytesSync(await _png(out, w, h));
  // ignore: avoid_print
  print('review: $path (${tiles.map((t) => t.id).join(' ')})');
}
