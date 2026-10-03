// lib/widgets/fx/mutation_sheets.dart
//
// A MUTATED ALCHEMON IS ITS OWN SPRITE SHEET.
//
// An Alchemized or Transmuted creature has to look the part everywhere it
// appears — every grid, the details screen, the party strip, the field, a
// survival run, a dungeon. Rather than teach each of those painters a new
// trick, the mutation is baked once into a copy of the species' sheet: same
// frames, same layout, so every place that can draw a sprite draws this one
// unchanged and pays nothing extra per frame.
//
//   • Transmuted — the sheet's own light and shade, recoloured from dark
//     bronze to pale gold, with a polished highlight across each frame. The
//     creature's tint is not applied on top: gold replaces the colour.
//   • Alchemized — the sheet re-read as grains, frame by frame: the summoning's
//     particles, at rest but never settling back into a sprite. Grains keep the
//     creature's colours, so tints still show; a prismatic one is read in
//     rainbow, and the usual prismatic hue cycle then sets it flowing.
//
// The pixel work runs on a background isolate. A big (1200px-frame) sheet is
// baked at [kMutationMaxFrame] — no screen draws a creature larger.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/foundation.dart' show compute, debugPrint;

/// The colour a mutation is named in: gold for Transmuted, the pale violet of
/// loose grains for Alchemized.
ui.Color mutationAccent(AlchemonMutation mutation) => switch (mutation) {
  AlchemonMutation.transmuted => const ui.Color(0xFFE4C16A),
  AlchemonMutation.alchemized => const ui.Color(0xFFB9A7F5),
};

/// The largest frame a mutated sheet is baked at, in sheet pixels.
const int kMutationMaxFrame = 512;

/// How a mutated sheet is drawn.
enum MutationLook {
  transmuted('transmuted'),
  alchemized('alchemized'),
  alchemizedPrismatic('alchemized-prismatic');

  const MutationLook(this.id);
  final String id;

  static MutationLook? of(
    AlchemonMutation? mutation, {
    bool prismatic = false,
  }) {
    switch (mutation) {
      case AlchemonMutation.transmuted:
        return MutationLook.transmuted;
      case AlchemonMutation.alchemized:
        return prismatic
            ? MutationLook.alchemizedPrismatic
            : MutationLook.alchemized;
      case null:
        return null;
    }
  }
}

/// What a baked key was made from.
class _BakeSpec {
  const _BakeSpec({
    required this.basePath,
    required this.look,
    required this.frameW,
    required this.frameH,
    required this.cols,
    required this.rowCount,
    required this.frames,
  });

  final String basePath;
  final MutationLook look;

  /// Frame size in the BAKED sheet.
  final int frameW, frameH;
  final int cols, rowCount, frames;
}

final Map<String, _BakeSpec> _specs = {};
final Map<String, Future<ui.Image>> _baked = {};

/// The sheet to draw for a creature with [mutation] (an [AlchemonMutation]
/// id, or null). Unmutated, it is [sheet] itself; mutated, it names a baked
/// copy — load it with [loadCreatureSheet], never `images.load`.
SpriteSheetDef mutatedSheet(
  SpriteSheetDef sheet, {
  String? mutation,
  bool prismatic = false,
}) {
  final look = MutationLook.of(
    AlchemonMutation.byId(mutation),
    prismatic: prismatic,
  );
  if (look == null) return sheet;
  final key = '${sheet.path}#mut:${look.id}';
  final rows = math.max(1, sheet.rows);
  final cols = (sheet.totalFrames + rows - 1) ~/ rows;
  final k = math.min(
    1.0,
    kMutationMaxFrame / math.max(sheet.frameSize.x, sheet.frameSize.y),
  );
  final fw = math.max(1, (sheet.frameSize.x * k).round());
  final fh = math.max(1, (sheet.frameSize.y * k).round());
  _specs[key] ??= _BakeSpec(
    basePath: sheet.path,
    look: look,
    frameW: fw,
    frameH: fh,
    cols: cols,
    rowCount: rows,
    frames: sheet.totalFrames,
  );
  return SpriteSheetDef(
    path: key,
    totalFrames: sheet.totalFrames,
    rows: sheet.rows,
    frameSize: Vector2(fw.toDouble(), fh.toDouble()),
    stepTime: sheet.stepTime,
  );
}

/// [mutatedSheet] for a creature drawn with [visuals] — the form game code
/// holds. Null in, null out.
SpriteSheetDef? sheetForVisuals(SpriteSheetDef? sheet, SpriteVisuals? visuals) {
  if (sheet == null) return null;
  return mutatedSheet(
    sheet,
    mutation: visuals?.mutation,
    prismatic: visuals?.isPrismatic ?? false,
  );
}

/// Whether [path] names a baked mutation sheet.
bool isMutatedSheetPath(String path) => _specs.containsKey(path);

/// Loads a creature's sheet into [images]: the asset for a plain path, the
/// baked copy (made once, shared by every cache) for a [mutatedSheet] one.
Future<ui.Image> loadCreatureSheet(Images images, String path) async {
  final spec = _specs[path];
  if (spec == null || images.containsKey(path)) return images.load(path);
  final baked = await _baked.putIfAbsent(path, () => _bake(images, spec));
  // A cache owns, and may dispose, what it is given: each gets its own handle.
  if (!images.containsKey(path)) images.add(path, baked.clone());
  return images.fromCache(path);
}

Future<ui.Image> _bake(Images images, _BakeSpec spec) async {
  final base = await images.load(spec.basePath);
  final w = spec.frameW * spec.cols;
  final h = spec.frameH * spec.rowCount;
  final scaled = (base.width == w && base.height == h)
      ? base
      : await _resized(base, w, h);
  try {
    final data = await scaled.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) throw StateError('sheet could not be read');
    final job = MutationBakeJob(
      rgba: data.buffer.asUint8List(),
      width: w,
      height: h,
      frameW: spec.frameW,
      frameH: spec.frameH,
      cols: spec.cols,
      frames: spec.frames,
      look: spec.look,
    );
    final out = await compute(bakeMutation, job);
    final baked = await _fromPremultiplied(out, w, h);
    if (!identical(scaled, base)) scaled.dispose();
    return baked;
  } catch (e) {
    // Better the plain creature than none: same frames, same size.
    debugPrint('[MutationSheets] bake failed for ${spec.basePath}: $e');
    return identical(scaled, base) ? base.clone() : scaled;
  }
}

Future<ui.Image> _resized(ui.Image src, int w, int h) {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  return picture.toImage(w, h).whenComplete(picture.dispose);
}

Future<ui.Image> _fromPremultiplied(Uint8List rgba, int w, int h) {
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(rgba, w, h, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

// ─────────────────────────────────────────────────────────────────────────
// The pixel work. Plain Dart on bytes, so it runs on an isolate and can be
// tested without a GPU. Input is straight-alpha RGBA; output is premultiplied,
// which is what [ui.decodeImageFromPixels] expects.
// ─────────────────────────────────────────────────────────────────────────

class MutationBakeJob {
  const MutationBakeJob({
    required this.rgba,
    required this.width,
    required this.height,
    required this.frameW,
    required this.frameH,
    required this.cols,
    required this.frames,
    required this.look,
  });

  final Uint8List rgba;
  final int width, height, frameW, frameH, cols, frames;
  final MutationLook look;
}

/// Bakes [job] into premultiplied RGBA of the same size.
Uint8List bakeMutation(MutationBakeJob job) => switch (job.look) {
  MutationLook.transmuted => transmuteRgba(job),
  MutationLook.alchemized => alchemizeRgba(job, rainbow: false),
  MutationLook.alchemizedPrismatic => alchemizeRgba(job, rainbow: true),
};

/// The polished-gold ramp, dark to light: bronze shadow to pale highlight.
const List<(double, int)> _goldRamp = [
  (0.00, 0x2A1606),
  (0.28, 0x6B4210),
  (0.52, 0xB8862B),
  (0.72, 0xE3BB52),
  (0.88, 0xF8E39A),
  (1.00, 0xFFFAF0),
];

/// The highlight's colour.
const int _glintColor = 0xFFF6D6;

/// How far a species' gold is pulled toward a middle brightness. A dark
/// creature still comes out a darker gold than a light one, only less so.
const double _evenOut = 0.45;

double _lum(Uint8List p, int o) =>
    (0.299 * p[o] + 0.587 * p[o + 1] + 0.114 * p[o + 2]) / 255.0;

Uint8List transmuteRgba(MutationBakeJob job) {
  final src = job.rgba;
  final n = job.width * job.height;
  final out = Uint8List(n * 4);

  // The species' own range of light, from its solid pixels: its gold spans
  // the whole ramp whether it was drawn pale or near-black.
  final hist = List<int>.filled(256, 0);
  var solid = 0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    if (src[o + 3] < 128) continue;
    hist[(_lum(src, o) * 255).round().clamp(0, 255)]++;
    solid++;
  }
  if (solid == 0) return out;
  int pct(double q) {
    final target = (solid * q).floor();
    var acc = 0;
    for (var b = 0; b < 256; b++) {
      acc += hist[b];
      if (acc > target) return b;
    }
    return 255;
  }

  final lo = pct(0.02) / 255.0;
  final hi = math.max(lo + 1 / 255.0, pct(0.98) / 255.0);
  final median = ((pct(0.5) / 255.0 - lo) / (hi - lo)).clamp(0.0, 1.0);
  var gamma = 1.0;
  if (median > 0.02 && median < 0.98) {
    final target = median + (0.5 - median) * _evenOut;
    gamma = (math.log(target) / math.log(median)).clamp(0.55, 1.6);
  }

  // Luminance byte → gold, once.
  final lutR = Uint8List(256), lutG = Uint8List(256), lutB = Uint8List(256);
  final lutL = Float32List(256);
  for (var b = 0; b < 256; b++) {
    final l = math
        .pow(((b / 255.0 - lo) / (hi - lo)).clamp(0.0, 1.0), gamma)
        .toDouble();
    lutL[b] = l;
    final c = _rampAt(l);
    lutR[b] = (c >> 16) & 0xFF;
    lutG[b] = (c >> 8) & 0xFF;
    lutB[b] = c & 0xFF;
  }

  // The highlight is laid across each frame's own body, not the cell.
  final boxes = _frameBoxes(job);
  const gr = (_glintColor >> 16) & 0xFF;
  const gg = (_glintColor >> 8) & 0xFF;
  const gb = _glintColor & 0xFF;

  for (var f = 0; f < job.frames; f++) {
    final box = boxes[f];
    if (box == null) continue;
    final (x0, y0, x1, y1) = box;
    final bw = math.max(1, x1 - x0 + 1), bh = math.max(1, y1 - y0 + 1);
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        final o = (y * job.width + x) * 4;
        final a = src[o + 3];
        if (a == 0) continue;
        final lb = (_lum(src, o) * 255).round().clamp(0, 255);
        final l = lutL[lb];
        var r = lutR[lb].toDouble(),
            g = lutG[lb].toDouble(),
            b = lutB[lb].toDouble();
        final u = ((x - x0) / bw) * 0.75 + ((y - y0) / bh) * 0.25;
        final d = (u - 0.38) / 0.07;
        final glint = 0.55 * math.exp(-d * d) * (0.35 + 0.65 * l);
        if (glint > 0.004) {
          r += (gr - r) * glint;
          g += (gg - g) * glint;
          b += (gb - b) * glint;
        }
        final k = a / 255.0;
        out[o] = (r * k).round();
        out[o + 1] = (g * k).round();
        out[o + 2] = (b * k).round();
        out[o + 3] = a;
      }
    }
  }
  return out;
}

int _rampAt(double l) {
  for (var i = 1; i < _goldRamp.length; i++) {
    final (p1, c1) = _goldRamp[i];
    if (l <= p1 || i == _goldRamp.length - 1) {
      final (p0, c0) = _goldRamp[i - 1];
      final t = ((l - p0) / (p1 - p0)).clamp(0.0, 1.0);
      int ch(int s) =>
          (((c0 >> s) & 0xFF) + (((c1 >> s) & 0xFF) - ((c0 >> s) & 0xFF)) * t)
              .round();
      return (ch(16) << 16) | (ch(8) << 8) | ch(0);
    }
  }
  return _goldRamp.last.$2;
}

/// Each frame's solid bounding box, in sheet pixels; null for an empty frame.
List<(int, int, int, int)?> _frameBoxes(MutationBakeJob job) {
  final src = job.rgba;
  return [
    for (var f = 0; f < job.frames; f++)
      () {
        final cx = (f % job.cols) * job.frameW;
        final cy = (f ~/ job.cols) * job.frameH;
        var x0 = 1 << 30, y0 = 1 << 30, x1 = -1, y1 = -1;
        for (var y = cy; y < cy + job.frameH && y < job.height; y++) {
          for (var x = cx; x < cx + job.frameW && x < job.width; x++) {
            if (src[(y * job.width + x) * 4 + 3] == 0) continue;
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
          }
        }
        return x1 < 0 ? null : (x0, y0, x1, y1);
      }(),
  ];
}

/// About how many grains one frame is read into. Coarser than a summon's
/// (which is read at screen size): a baked sheet is drawn shrunk, in grids at
/// a fifth of its size, and finer grains there alias into noise instead of
/// reading as particles.
const int kAlchemizedGrains = 1000;

Uint8List alchemizeRgba(MutationBakeJob job, {required bool rainbow}) {
  final src = job.rgba;
  final w = job.width, h = job.height;
  final out = Uint8List(w * h * 4);
  // Accumulated straight colour and coverage, composited at the end.
  final accR = Float32List(w * h),
      accG = Float32List(w * h),
      accB = Float32List(w * h),
      accA = Float32List(w * h);

  // One grain size for the whole sheet, from its average frame, so the grid
  // — and every grain's home on it — is the same in every frame.
  var solid = 0;
  for (var i = 3; i < src.length; i += 4) {
    if (src[i] >= 128) solid++;
  }
  if (solid == 0) return out;
  final sp = math.max(
    2.0,
    math.sqrt(solid / math.max(1, job.frames) / kAlchemizedGrains),
  );
  final q = sp * 0.25;

  for (var f = 0; f < job.frames; f++) {
    final cx = (f % job.cols) * job.frameW;
    final cy = (f ~/ job.cols) * job.frameH;
    final ex = math.min(w, cx + job.frameW), ey = math.min(h, cy + job.frameH);
    if (cx >= w || cy >= h) continue;
    // The same grains every frame, each wandering a little from frame to
    // frame: the body moves under them and they seethe, rather than a fixed
    // mosaic recolouring.
    final home = math.Random(5);
    final wobble = math.Random(101 + f);
    final radius = sp * 0.5;

    for (var sy = cy + sp / 2; sy < ey; sy += sp) {
      for (var sx = cx + sp / 2; sx < ex; sx += sp) {
        final hx = (home.nextDouble() - 0.5) * 0.6 * sp;
        final hy = (home.nextDouble() - 0.5) * 0.6 * sp;
        final glintRoll = home.nextDouble();
        final jx = sx + hx + (wobble.nextDouble() - 0.5) * 0.3 * sp;
        final jy = sy + hy + (wobble.nextDouble() - 0.5) * 0.3 * sp;
        final twinkle = wobble.nextDouble();

        // The patch's colour, alpha-weighted over five taps.
        var a = 0.0, r = 0.0, g = 0.0, b = 0.0;
        for (final (tx, ty) in const [
          (0.0, 0.0),
          (-1.0, -1.0),
          (1.0, -1.0),
          (-1.0, 1.0),
          (1.0, 1.0),
        ]) {
          final px = (jx + tx * q).round().clamp(cx, ex - 1);
          final py = (jy + ty * q).round().clamp(cy, ey - 1);
          final o = (py * w + px) * 4;
          final al = src[o + 3].toDouble();
          a += al;
          r += src[o] * al;
          g += src[o + 1] * al;
          b += src[o + 2] * al;
        }
        // Mostly empty: the edge of the body, or a faint aura.
        if (a < 5 * 120) continue;
        r /= a;
        g /= a;
        b /= a;

        if (rainbow) {
          // Hue runs across the body; each grain keeps its own lightness,
          // so eyes and markings survive the rainbow.
          final lx = (jx - cx) / job.frameW, ly = (jy - cy) / job.frameH;
          final hue = ((lx * 0.6 + ly * 0.9) / 1.5 * 1.6) % 1.0;
          final own =
              (math.max(r, math.max(g, b)) + math.min(r, math.min(g, b))) /
              510.0;
          final rgb = _hsl(hue, 0.6, 0.28 + 0.52 * own);
          r = rgb.$1;
          g = rgb.$2;
          b = rgb.$3;
        }

        // A few catch the light, and not the same few each frame.
        var rad = radius;
        if (glintRoll > 0.985 && twinkle > 0.35) {
          r = 255;
          g = 246;
          b = 224;
          rad = radius * 1.15;
        }
        _stampDisc(accR, accG, accB, accA, w, h, jx, jy, rad, r, g, b);
      }
    }
  }

  for (var i = 0; i < w * h; i++) {
    final a = accA[i];
    if (a <= 0) continue;
    final k = a.clamp(0.0, 1.0);
    final o = i * 4;
    // Straight colour of the topmost coverage, premultiplied on the way out.
    out[o] = (accR[i] * k).round().clamp(0, 255);
    out[o + 1] = (accG[i] * k).round().clamp(0, 255);
    out[o + 2] = (accB[i] * k).round().clamp(0, 255);
    out[o + 3] = (k * 255).round();
  }
  return out;
}

/// One antialiased grain, composited over what is already there.
void _stampDisc(
  Float32List ar,
  Float32List ag,
  Float32List ab,
  Float32List aa,
  int w,
  int h,
  double x,
  double y,
  double r,
  double cr,
  double cg,
  double cb,
) {
  final x0 = math.max(0, (x - r - 1).floor());
  final x1 = math.min(w - 1, (x + r + 1).ceil());
  final y0 = math.max(0, (y - r - 1).floor());
  final y1 = math.min(h - 1, (y + r + 1).ceil());
  for (var py = y0; py <= y1; py++) {
    for (var px = x0; px <= x1; px++) {
      final dx = px + 0.5 - x, dy = py + 0.5 - y;
      final cov = (r + 0.5 - math.sqrt(dx * dx + dy * dy)).clamp(0.0, 1.0);
      if (cov <= 0) continue;
      final i = py * w + px;
      final da = aa[i];
      final oa = cov + da * (1 - cov);
      ar[i] = (cr * cov + ar[i] * da * (1 - cov)) / oa;
      ag[i] = (cg * cov + ag[i] * da * (1 - cov)) / oa;
      ab[i] = (cb * cov + ab[i] * da * (1 - cov)) / oa;
      aa[i] = oa;
    }
  }
}

(double, double, double) _hsl(double h, double s, double l) {
  double hue(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
    return p;
  }

  final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  final p = 2 * l - q;
  return (
    hue(p, q, h + 1 / 3) * 255,
    hue(p, q, h) * 255,
    hue(p, q, h - 1 / 3) * 255,
  );
}
