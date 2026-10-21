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
//   • Transmuted — the sheet's own light and shade, recolored from dark
//     bronze to pale gold, with a polished highlight across each frame. The
//     creature's tint is not applied on top: gold replaces the color.
//   • Alchemized — the sheet re-read as grains, frame by frame: the summoning's
//     particles, at rest but never settling back into a sprite. Grains keep the
//     creature's colors, so tints still show.
//   • Prismatic — a rainbow carried by the sheet's height and shading, a
//     quarter of its own color kept; the prismatic hue cycle sets it flowing.
//   • Silverlite — liquid silver: chrome bands from the shading, its lines
//     kept dark so the face still reads.
//   • Starlit — a night sky inside the body: deep indigo, a nebula in the
//     creature's own main color, stars, its lines in faint blue.
//   • Obsidian — black glass: its element's light where its lines are drawn,
//     a faint gloss on its brightest parts and a cool rim. Nothing moves.
//
// An albino is baked the same way, though it is a pigment and not a
// mutation: its ivory body and red eyes (albino_look.dart). So is a faction
// variant of a polished species: its palette swap (variant_look.dart). A
// mutated albino or variant keeps its mutation's sheet and is filtered as it
// is drawn.
//
// The pixel work runs on a background isolate. A big (1200px-frame) sheet is
// baked at [kMutationMaxFrame] — no screen draws a creature larger
// ([bakedFrameSize]).

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/darklet_ring.dart';
import 'package:alchemons/widgets/fx/variant_look.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/foundation.dart' show compute, debugPrint;

/// The color a mutation is named in: gold for Transmuted, the pale violet of
/// loose grains for Alchemized, the ember in Obsidian's lines.
ui.Color mutationAccent(AlchemonMutation mutation) => switch (mutation) {
  AlchemonMutation.transmuted => const ui.Color(0xFFE4C16A),
  AlchemonMutation.alchemized => const ui.Color(0xFFB9A7F5),
  AlchemonMutation.prismatic => const ui.Color(0xFFE879F9),
  AlchemonMutation.silverlite => const ui.Color(0xFFD5DCE8),
  AlchemonMutation.starlit => const ui.Color(0xFF8EA6FF),
  AlchemonMutation.obsidian => const ui.Color(0xFFE0A070),
};

/// The largest frame a mutated sheet is baked at, in sheet pixels.
const int kMutationMaxFrame = 512;

/// How a mutated sheet is drawn.
enum MutationLook {
  transmuted('transmuted'),
  alchemized('alchemized'),
  prismatic('prismatic'),
  silverlite('silverlite'),
  starlit('starlit'),
  obsidian('obsidian'),
  albino('albino'),
  variantVolcanic('variant-volcanic', 'Volcanic'),
  variantOceanic('variant-oceanic', 'Oceanic'),
  variantVerdant('variant-verdant', 'Verdant'),
  variantEarthen('variant-earthen', 'Earthen'),
  variantArcane('variant-arcane', 'Arcane');

  const MutationLook(this.id, [this.faction]);
  final String id;

  /// A variant's faction ([kVariantPalette]'s spelling); null for the rest.
  final String? faction;

  /// The variant look for [faction], or null.
  static MutationLook? variant(String? faction) => values
      .where((l) => l.faction != null && l.faction == faction)
      .firstOrNull;

  static MutationLook? of(AlchemonMutation? mutation) => switch (mutation) {
    AlchemonMutation.transmuted => MutationLook.transmuted,
    AlchemonMutation.alchemized => MutationLook.alchemized,
    AlchemonMutation.prismatic => MutationLook.prismatic,
    AlchemonMutation.silverlite => MutationLook.silverlite,
    AlchemonMutation.starlit => MutationLook.starlit,
    AlchemonMutation.obsidian => MutationLook.obsidian,
    null => null,
  };

  /// A look whose eyes are kept from the sheet (or, for the albino, painted
  /// over it) by the species' eye overlay.
  bool get keepsEyes =>
      this == MutationLook.albino ||
      faction != null ||
      this == MutationLook.prismatic ||
      this == MutationLook.silverlite ||
      this == MutationLook.starlit ||
      this == MutationLook.obsidian;
}

/// The frame a sheet with [width]×[height] frames is baked at: no bigger than
/// [kMutationMaxFrame]. But Darklet's: its ring knows it by its frame size
/// (darklet_ring.dart), so its bake keeps it.
(int, int) bakedFrameSize(double width, double height) {
  final k = DarkletRing.matches(width, height)
      ? 1.0
      : math.min(1.0, kMutationMaxFrame / math.max(width, height));
  return (math.max(1, (width * k).round()), math.max(1, (height * k).round()));
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
    this.eyes,
  });

  final String basePath;
  final MutationLook look;

  /// An albino's eye overlay, if its species has one.
  final String? eyes;

  /// Frame size in the BAKED sheet.
  final int frameW, frameH;
  final int cols, rowCount, frames;
}

final Map<String, _BakeSpec> _specs = {};
final Map<String, Future<ui.Image>> _baked = {};

/// The sheet to draw for a creature with [mutation] (an [AlchemonMutation]
/// id, or null), [albino] or not ([isAlbinoLook]), and of [variant] faction
/// or none. Plain, it is [sheet] itself; mutated, albino or a polished
/// species' variant ([variantSwap]), it names a baked copy — load it with
/// [loadCreatureSheet], never `images.load`. A baked sheet passed back in is
/// returned as it is.
SpriteSheetDef mutatedSheet(
  SpriteSheetDef sheet, {
  String? mutation,
  bool prismatic = false,
  bool albino = false,
  String? variant,
}) {
  if (_specs.containsKey(sheet.path)) return sheet;
  // The old prismatic flag, on a creature not yet given the mutation.
  mutation ??= prismatic ? AlchemonMutation.prismatic.id : null;
  final pale = albino && mutation == null;
  final look =
      MutationLook.of(AlchemonMutation.byId(mutation)) ??
      (albinoBakes(albino: pale, mutation: mutation)
          ? MutationLook.albino
          : MutationLook.variant(
              variantSwap(
                speciesId: speciesOfSheet(sheet.path),
                faction: variant,
                albino: pale,
                mutation: mutation,
              ),
            ));
  if (look == null) return sheet;
  final key = '${sheet.path}#mut:${look.id}';
  final rows = math.max(1, sheet.rows);
  final cols = (sheet.totalFrames + rows - 1) ~/ rows;
  final (fw, fh) = bakedFrameSize(sheet.frameSize.x, sheet.frameSize.y);
  _specs[key] ??= _BakeSpec(
    basePath: sheet.path,
    look: look,
    frameW: fw,
    frameH: fh,
    cols: cols,
    rowCount: rows,
    frames: sheet.totalFrames,
    // An albino's eyes are painted red from it; a variant's or a material
    // mutation's kept as drawn.
    eyes: look.keepsEyes ? albinoEyesPath(sheet.path) : null,
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
    albino: visuals != null && isAlbinoLook(visuals),
    variant: visuals != null && variantBaked(visuals)
        ? visuals.variantFaction
        : null,
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
    final eyes = spec.eyes == null
        ? null
        : await _readOverlay(images, spec.eyes!, w, h);
    final job = MutationBakeJob(
      rgba: data.buffer.asUint8List(),
      width: w,
      height: h,
      frameW: spec.frameW,
      frameH: spec.frameH,
      cols: spec.cols,
      frames: spec.frames,
      look: spec.look,
      eyes: eyes,
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

/// The overlay at [path] (under the cache's prefix) as straight RGBA, [w]×[h]:
/// read once for a bake and let go, never kept in the cache. Null if it will
/// not load — the albino is baked without its eyes.
Future<Uint8List?> _readOverlay(
  Images images,
  String path,
  int w,
  int h,
) async {
  try {
    final bytes = await images.bundle.load('${images.prefix}$path');
    final codec = await ui.instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: w,
      targetHeight: h,
    );
    final image = (await codec.getNextFrame()).image;
    codec.dispose();
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    image.dispose();
    return data?.buffer.asUint8List();
  } catch (e) {
    debugPrint('[MutationSheets] no albino eyes from $path: $e');
    return null;
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
    this.eyes,
  });

  final Uint8List rgba;
  final int width, height, frameW, frameH, cols, frames;
  final MutationLook look;

  /// The eye overlay, straight RGBA the size of [rgba], or null: an albino's
  /// red eyes, or where a variant's eyes are, to keep.
  final Uint8List? eyes;
}

/// Bakes [job] into premultiplied RGBA of the same size.
Uint8List bakeMutation(MutationBakeJob job) => switch (job.look) {
  MutationLook.transmuted => transmuteRgba(job),
  MutationLook.alchemized => alchemizeRgba(job),
  MutationLook.prismatic => prismaticRgba(job),
  MutationLook.silverlite => silverliteRgba(job),
  MutationLook.starlit => starlitRgba(job),
  MutationLook.obsidian => obsidianRgba(job),
  MutationLook.albino => albinoRgba(job),
  MutationLook.variantVolcanic ||
  MutationLook.variantOceanic ||
  MutationLook.variantVerdant ||
  MutationLook.variantEarthen ||
  MutationLook.variantArcane => variantRgba(job),
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

/// The highlight's color.
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
    final c = _rampOf(_goldRamp, l);
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

int _rampOf(List<(double, int)> ramp, double l) {
  for (var i = 1; i < ramp.length; i++) {
    final (p1, c1) = ramp[i];
    if (l <= p1 || i == ramp.length - 1) {
      final (p0, c0) = ramp[i - 1];
      final t = ((l - p0) / (p1 - p0)).clamp(0.0, 1.0);
      int ch(int s) =>
          (((c0 >> s) & 0xFF) + (((c1 >> s) & 0xFF) - ((c0 >> s) & 0xFF)) * t)
              .round();
      return (ch(16) << 16) | (ch(8) << 8) | ch(0);
    }
  }
  return ramp.last.$2;
}

/// The albino: the sheet's light and shade, its middle lifted to
/// [kAlbinoMid] if it sits lower, on [kAlbinoRamp], with [kAlbinoPigment] of
/// its own colors and its red eyes ([MutationBakeJob.eyes]) laid over.
Uint8List albinoRgba(MutationBakeJob job) {
  final src = job.rgba;
  final eyes = job.eyes;
  final n = job.width * job.height;
  final out = Uint8List(n * 4);

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

  // Its darkest lines stay dark, but never the body itself: a species drawn
  // nearly all in one dark tone (Darklet) still has a middle to lift.
  final lo = math.min(pct(0.02), pct(0.5) * 0.5) / 255.0;
  final hi = math.max(lo + 1 / 255.0, pct(0.98) / 255.0);
  final median = ((pct(0.5) / 255.0 - lo) / (hi - lo)).clamp(0.0, 1.0);
  var gamma = 1.0;
  if (median > 0.005 && median < kAlbinoMid) {
    gamma = (math.log(kAlbinoMid) / math.log(median)).clamp(0.15, 1.0);
  }

  // Luminance byte → ivory, once.
  final lutR = Uint8List(256), lutG = Uint8List(256), lutB = Uint8List(256);
  for (var b = 0; b < 256; b++) {
    final l = math
        .pow(((b / 255.0 - lo) / (hi - lo)).clamp(0.0, 1.0), gamma)
        .toDouble();
    final c = _rampOf(kAlbinoRamp, l);
    lutR[b] = (c >> 16) & 0xFF;
    lutG[b] = (c >> 8) & 0xFF;
    lutB[b] = c & 0xFF;
  }

  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final a = src[o + 3];
    if (a == 0) continue;
    final y = 0.299 * src[o] + 0.587 * src[o + 1] + 0.114 * src[o + 2];
    final lb = y.round().clamp(0, 255);
    var r = lutR[lb] + kAlbinoPigment * (src[o] - y);
    var g = lutG[lb] + kAlbinoPigment * (src[o + 1] - y);
    var b = lutB[lb] + kAlbinoPigment * (src[o + 2] - y);
    if (eyes != null && eyes[o + 3] > 0) {
      final e = eyes[o + 3] / 255.0;
      r += (eyes[o] - r) * e;
      g += (eyes[o + 1] - g) * e;
      b += (eyes[o + 2] - b) * e;
    }
    final k = a / 255.0;
    out[o] = (r.clamp(0.0, 255.0) * k).round();
    out[o + 1] = (g.clamp(0.0, 255.0) * k).round();
    out[o + 2] = (b.clamp(0.0, 255.0) * k).round();
    out[o + 3] = a;
  }
  return out;
}

/// A faction variant: every color turned in OKLab by the one amount that
/// lands the sheet's main color (the hue most of its body is, eyes aside) on
/// its faction's hue ([kVariantPalette]) — or, where that would hardly change it
/// ([kVariantLeastChange]), on the far end of the faction's range; a pale or
/// dark body's color raised toward [kVariantBodyChroma], near-greys given
/// the faction's hue; its strength and light scaled as the faction keeps
/// them; its eyes ([MutationBakeJob.eyes], read as a mask) left their own
/// color, unless that is the color the body turns to.
Uint8List variantRgba(MutationBakeJob job) {
  final swap = kVariantPalette[job.look.faction]!;
  final src = job.rgba;
  final eyes = job.eyes;
  final n = job.width * job.height;
  final out = Uint8List(n * 4);
  final labL = Float32List(n), labA = Float32List(n), labB = Float32List(n);
  final body = Uint8List(n);
  final lin = Float64List(256);
  for (var c = 0; c < 256; c++) {
    final v = c / 255.0;
    lin[c] = v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  // The body — what is solid, eyes aside: how its colors fall round the
  // hue circle (in 5° steps, by area), and how colored it is. And the eyes'
  // own color.
  const steps = 72;
  final hues = Float64List(steps);
  var sumC = 0.0, eyeA = 0.0, eyeB = 0.0;
  var bodyCount = 0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    if (src[o + 3] == 0) continue;
    final r = lin[src[o]], g = lin[src[o + 1]], b = lin[src[o + 2]];
    final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    final la = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    final lb = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    labL[i] = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    labA[i] = la;
    labB[i] = lb;
    final c = math.sqrt(la * la + lb * lb);
    if (src[o + 3] < 128) continue;
    if (eyes != null && eyes[o + 3] > 0) {
      if (c >= 0.04) {
        eyeA += la;
        eyeB += lb;
      }
      continue;
    }
    body[i] = 1;
    bodyCount++;
    sumC += c;
    if (c < 0.04) continue;
    final h = math.atan2(lb, la) % (2 * math.pi);
    hues[(h / (2 * math.pi) * steps).floor() % steps] += 1;
  }

  double rad(double degrees) => degrees * math.pi / 180;
  double apart(double a, double b) {
    final d = (a - b) % (2 * math.pi);
    return math.min(d, 2 * math.pi - d);
  }

  // How much the body changes, on average, turned by [turn].
  double change(double turn) {
    if (bodyCount == 0) return double.infinity;
    final ct = math.cos(turn) * swap.chroma, st = math.sin(turn) * swap.chroma;
    final dl = 1 - swap.light;
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      if (body[i] == 0) continue;
      final a = labA[i], b = labB[i], l = labL[i] * dl;
      final da = a - (a * ct - b * st), db = b - (a * st + b * ct);
      total += math.sqrt(l * l + da * da + db * db);
    }
    return total / bodyCount;
  }

  // Its main color: the hue most of its body is (not the mean of all its
  // colors, which a bright flame or crest drags off the body), refined to
  // the mean of the body's colors within 15° of it.
  double? own;
  var peak = -1, most = 0.0;
  for (var k = 0; k < steps; k++) {
    var around = 0.0;
    for (var d = -2; d <= 2; d++) {
      around += hues[(k + d) % steps];
    }
    if (around > most) {
      most = around;
      peak = k;
    }
  }
  if (peak >= 0) {
    final centre = (peak + 0.5) / steps * 2 * math.pi;
    var a = 0.0, b = 0.0;
    for (var i = 0; i < n; i++) {
      if (body[i] == 0) continue;
      final la = labA[i], lb = labB[i];
      if (la * la + lb * lb < 0.04 * 0.04) continue;
      if (apart(math.atan2(lb, la), centre) > rad(15)) continue;
      a += la;
      b += lb;
    }
    own = math.atan2(b, a);
  }
  var hue = rad(swap.hue);
  if (own != null && change(hue - own) < kVariantLeastChange) {
    final low = rad(swap.low), high = rad(swap.high);
    hue = apart(low, own) > apart(high, own) ? low : high;
  }
  final turn = own == null ? 0.0 : hue - own;
  final ct = math.cos(turn), st = math.sin(turn);
  // Its eyes keep their own color — unless the body is turning to it, where
  // they would vanish into it: then they turn with the body, keeping the
  // contrast they were drawn with.
  final keepEyes =
      eyes != null &&
      (eyeA == 0 && eyeB == 0 || apart(math.atan2(eyeB, eyeA), hue) > rad(45));
  final lift = bodyCount == 0
      ? 1.0
      : (kVariantBodyChroma / math.max(sumC / bodyCount, 1e-6)).clamp(
          1.0,
          kVariantMostLift,
        );

  int srgb(double v) {
    if (v <= 0) return 0;
    if (v >= 1) return 255;
    final e = v <= 0.0031308
        ? 12.92 * v
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
    return (e * 255).round().clamp(0, 255);
  }

  for (var i = 0; i < n; i++) {
    final o = i * 4;
    final alpha = src[o + 3];
    if (alpha == 0) continue;
    final light = labL[i];
    var aa = labA[i] * ct - labB[i] * st, bb = labA[i] * st + labB[i] * ct;
    var c = math.sqrt(aa * aa + bb * bb) * lift;
    // A near-grey, away from the darkest lines and brightest glints, takes
    // a little of the faction's hue.
    final grey =
        kVariantGreyChroma *
        ((light - 0.12) / 0.2).clamp(0.0, 1.0) *
        ((0.97 - light) / 0.12).clamp(0.0, 1.0);
    var h = math.atan2(bb, aa);
    if (c < grey) {
      final w = (grey - c) / grey;
      final from = c > 1e-4 ? h : hue;
      h = math.atan2(
        (1 - w) * math.sin(from) + w * math.sin(hue),
        (1 - w) * math.cos(from) + w * math.cos(hue),
      );
      c = grey;
    }
    aa = c * math.cos(h) * swap.chroma;
    bb = c * math.sin(h) * swap.chroma;
    final ll = light * swap.light;
    final l = ll + 0.3963377774 * aa + 0.2158037573 * bb;
    final m = ll - 0.1055613458 * aa - 0.0638541728 * bb;
    final s = ll - 0.0894841775 * aa - 1.2914855480 * bb;
    final l3 = l * l * l, m3 = m * m * m, s3 = s * s * s;
    var r = srgb(
      4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3,
    ).toDouble();
    var g = srgb(
      -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3,
    ).toDouble();
    var bl = srgb(
      -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3,
    ).toDouble();
    if (keepEyes && eyes[o + 3] > 0) {
      final e = eyes[o + 3] / 255.0;
      r += (src[o] - r) * e;
      g += (src[o + 1] - g) * e;
      bl += (src[o + 2] - bl) * e;
    }
    final k = alpha / 255.0;
    out[o] = (r * k).round();
    out[o + 1] = (g * k).round();
    out[o + 2] = (bl * k).round();
    out[o + 3] = alpha;
  }
  return out;
}

// ─────────────────────────────────────────────────────────────────────────
// The material mutations: Prismatic, Silverlite, Starlit, Obsidian. Each
// replaces the creature's color with a material read from its own light and
// shade ([_Material]): where its lines are drawn, where its silhouette's edge
// is, and its main color. Sizes are given for a 320px frame and scaled.
// ─────────────────────────────────────────────────────────────────────────

/// What every material look reads from a sheet once.
class _Material {
  _Material(this.job) {
    final src = job.rgba;
    final w = job.width, h = job.height, n = w * h;
    k = job.frameW / 320.0;
    lum = Float32List(n);
    final alpha = Float32List(n);
    for (var i = 0; i < n; i++) {
      final o = i * 4;
      alpha[i] = src[o + 3] / 255.0;
      if (src[o + 3] > 0) lum[i] = _lum(src, o);
    }
    // The edge: how near the silhouette's rim a solid pixel is.
    final eroded = _minFilter(alpha, w, h, math.max(1, (4 * k).round()));
    final r = math.max(1, (2.5 * k).round());
    final soft = _boxBlur(_boxBlur(eroded, w, h, r), w, h, r);
    edge = Float32List(n);
    for (var i = 0; i < n; i++) {
      if (alpha[i] > 0) edge[i] = (1 - soft[i]).clamp(0.0, 1.0);
    }
    // The lines: darker than the neighbourhood around them.
    final lr = math.max(1, (2 * k).round());
    final around = _boxBlur(_boxBlur(lum, w, h, lr), w, h, lr);
    lines = Float32List(n);
    for (var i = 0; i < n; i++) {
      if (alpha[i] > 0) lines[i] = _smoothstep(0.02, 0.14, around[i] - lum[i]);
    }
    main = _mainColor(src, n);
  }

  final MutationBakeJob job;
  late final double k;
  late final Float32List lum, edge, lines;

  /// The creature's main color, lit: what its nebula or its glow is made of.
  late final (double, double, double) main;

  /// How much of [o]'s pixel is eye (0–1), from the overlay.
  double eye(int o) {
    final e = job.eyes;
    return e == null ? 0 : e[o + 3] / 255.0;
  }

  /// (x, y) of sheet pixel [i] within its frame, 0–1.
  (double, double) local(int i) {
    final x = i % job.width, y = i ~/ job.width;
    return (
      (x % job.frameW) / job.frameW,
      (y % job.frameH) / job.frameH,
    );
  }
}

/// The color most of a creature's saturated pixels are, as a lit color.
(double, double, double) _mainColor(Uint8List src, int n) {
  var wr = 0.0, wg = 0.0, wb = 0.0, wt = 0.0;
  for (var i = 0; i < n; i++) {
    final o = i * 4;
    if (src[o + 3] < 128) continue;
    final r = src[o], g = src[o + 1], b = src[o + 2];
    final c = (math.max(r, math.max(g, b)) - math.min(r, math.min(g, b))) / 255;
    if (c < 0.2) continue;
    final wgt = c * c;
    wr += r * wgt;
    wg += g * wgt;
    wb += b * wgt;
    wt += wgt;
  }
  if (wt < 1) return (150.0, 200.0, 215.0);
  final (h, sat, _) = _toHsl(wr / wt, wg / wt, wb / wt);
  return _hsl(h, math.max(sat, 0.65), 0.6);
}

Uint8List prismaticRgba(MutationBakeJob job) {
  final m = _Material(job);
  final src = job.rgba;
  final out = Uint8List(src.length);
  for (var i = 0; i < job.width * job.height; i++) {
    final o = i * 4;
    final a = src[o + 3];
    if (a == 0) continue;
    final l = m.lum[i];
    final (_, fy) = m.local(i);
    final (pr, pg, pb) = _hsl((fy * 0.9 + l * 0.35) % 1.0, 0.85, 0.25 + 0.6 * l);
    var r = pr * 0.75 + src[o] * 0.25;
    var g = pg * 0.75 + src[o + 1] * 0.25;
    var b = pb * 0.75 + src[o + 2] * 0.25;
    final e = m.edge[i] * 0.25;
    r += (255 - r) * e;
    g += (255 - g) * e;
    b += (255 - b) * e;
    final eye = m.eye(o);
    r += (src[o] - r) * eye;
    g += (src[o + 1] - g) * eye;
    b += (src[o + 2] - b) * eye;
    _put(out, o, r, g, b, a);
  }
  return out;
}

/// Chrome: dark and bright bands from the shading, so it reads as a mirror.
const List<(double, int)> _chromeRamp = [
  (0.00, 0x12141A),
  (0.18, 0x3C424E),
  (0.32, 0xC8D0DC),
  (0.42, 0x6E7684),
  (0.58, 0x282C36),
  (0.74, 0xAAB2C0),
  (0.88, 0xECF0F8),
  (1.00, 0xFFFFFF),
];

Uint8List silverliteRgba(MutationBakeJob job) {
  final m = _Material(job);
  final src = job.rgba;
  final out = Uint8List(src.length);
  final (er, eg, eb) = m.main;
  for (var i = 0; i < job.width * job.height; i++) {
    final o = i * 4;
    final a = src[o + 3];
    if (a == 0) continue;
    final l = m.lum[i];
    final (fx, fy) = m.local(i);
    final u =
        (0.15 + l * 0.6 + 0.22 * math.sin((fx * 1.3 + fy * 0.6) * 2 * math.pi))
            .clamp(0.0, 1.0);
    final c = _rampOf(_chromeRamp, u);
    var r = ((c >> 16) & 0xFF).toDouble(),
        g = ((c >> 8) & 0xFF).toDouble(),
        b = (c & 0xFF).toDouble();
    final tint = 0.10 * (1 - l);
    r += (er - r) * tint;
    g += (eg - g) * tint;
    b += (eb - b) * tint;
    final e = m.edge[i] * 0.35;
    r += (255 - r) * e;
    g += (255 - g) * e;
    b += (255 - b) * e;
    final ln = m.lines[i] * 0.7;
    r += (24 - r) * ln;
    g += (26 - g) * ln;
    b += (34 - b) * ln;
    final eye = m.eye(o);
    r += (src[o] - r) * eye;
    g += (src[o + 1] - g) * eye;
    b += (src[o + 2] - b) * eye;
    _put(out, o, r, g, b, a);
  }
  return out;
}

Uint8List starlitRgba(MutationBakeJob job) {
  final m = _Material(job);
  final src = job.rgba;
  final w = job.width, h = job.height;
  final out = Uint8List(src.length);
  final (mh, ms, _) = _toHsl(m.main.$1, m.main.$2, m.main.$3);
  final (nr, ng, nb) = _hsl(mh, math.min(1.0, ms * 1.1), 0.42);
  final rimR = (nr + 255) / 2, rimG = (ng + 255) / 2, rimB = (nb + 255) / 2;

  // The stars: the same sky in every frame, so they hold still as it moves.
  final stars = Float32List(w * h);
  final perFrame = (260 * (job.frameW * job.frameH) / (320 * 320)).round();
  for (var f = 0; f < job.frames; f++) {
    final cx = (f % job.cols) * job.frameW, cy = (f ~/ job.cols) * job.frameH;
    final rng = math.Random(7);
    for (var s = 0; s < perFrame; s++) {
      final sx = cx + rng.nextDouble() * job.frameW;
      final sy = cy + rng.nextDouble() * job.frameH;
      final bright = rng.nextDouble();
      final level = 0.45 + 0.55 * rng.nextDouble();
      final rad = (bright > 0.85 ? 1.6 : 1.0) * m.k + 0.6;
      final x0 = math.max(0, (sx - rad - 1).floor());
      final x1 = math.min(w - 1, (sx + rad + 1).ceil());
      final y0 = math.max(0, (sy - rad - 1).floor());
      final y1 = math.min(h - 1, (sy + rad + 1).ceil());
      for (var py = y0; py <= y1; py++) {
        for (var px = x0; px <= x1; px++) {
          final d = math.sqrt((px - sx) * (px - sx) + (py - sy) * (py - sy));
          final v = math.max(0.0, 1 - d / rad) * level * (0.5 + 0.5 * bright);
          final i = py * w + px;
          if (v > stars[i]) stars[i] = v;
        }
      }
    }
  }

  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final a = src[o + 3];
    if (a == 0) continue;
    final l = m.lum[i];
    final (fx, fy) = m.local(i);
    final x = fx * 320, y = fy * 320;
    var n =
        0.5 +
        0.5 *
            math.sin(x / 23 + 1.3 * math.sin(y / 31)) *
            math.cos(y / 19 - x / 47);
    n = _smoothstep(0.35, 1.0, n);
    var r = 8 + (nr - 8) * 0.40 * n,
        g = 10 + (ng - 10) * 0.40 * n,
        b = 28 + (nb - 28) * 0.40 * n;
    final violet = 0.30 * (1 - n);
    r += (52 - r) * violet;
    g += (30 - g) * violet;
    b += (96 - b) * violet;
    final shade = 0.75 + 0.6 * l;
    r *= shade;
    g *= shade;
    b *= shade;
    final ln = m.lines[i] * 0.35;
    r += (150 - r) * ln;
    g += (170 - g) * ln;
    b += (230 - b) * ln;
    final st = stars[i];
    r += (255 - r) * st;
    g += (250 - g) * st;
    b += (235 - b) * st;
    final e = m.edge[i] * 0.6;
    r += (rimR - r) * e;
    g += (rimG - g) * e;
    b += (rimB - b) * e;
    final eye = m.eye(o);
    r += (255 - r) * eye;
    g += (244 - g) * eye;
    b += (214 - b) * eye;
    _put(out, o, r, g, b, a);
  }
  return out;
}

Uint8List obsidianRgba(MutationBakeJob job) {
  final m = _Material(job);
  final src = job.rgba;
  final w = job.width, h = job.height;
  final out = Uint8List(src.length);
  final (er, eg, eb) = m.main;
  final hr = er + (255 - er) * 0.35,
      hg = eg + (255 - eg) * 0.35,
      hb = eb + (255 - eb) * 0.35;
  final gr = math.max(1, (2.5 * m.k).round());
  final glow = _boxBlur(_boxBlur(m.lines, w, h, gr), w, h, gr);
  for (var i = 0; i < w * h; i++) {
    final o = i * 4;
    final a = src[o + 3];
    if (a == 0) continue;
    final l = m.lum[i];
    var r = 12 + 28 * l, g = 12 + 28 * l, b = 17 + 34 * l;
    final halo = math.min(1.0, glow[i] * 1.6) * 0.6 * 0.85;
    r += (er - r) * halo;
    g += (eg - g) * halo;
    b += (eb - b) * halo;
    final ln = m.lines[i] * 0.95 * 0.85;
    r += (hr - r) * ln;
    g += (hg - g) * ln;
    b += (hb - b) * ln;
    final gloss = _smoothstep(0.80, 0.98, l) * 0.3;
    r += (150 - r) * gloss;
    g += (154 - g) * gloss;
    b += (170 - b) * gloss;
    final e = m.edge[i] * 0.55;
    r += (118 - r) * e;
    g += (122 - g) * e;
    b += (146 - b) * e;
    final eye = m.eye(o);
    r += (hr - r) * eye;
    g += (hg - g) * eye;
    b += (hb - b) * eye;
    _put(out, o, r, g, b, a);
  }
  return out;
}

/// Straight [r], [g], [b] at alpha [a], premultiplied into [out] at [o].
void _put(Uint8List out, int o, double r, double g, double b, int a) {
  final k = a / 255.0;
  out[o] = (r.clamp(0.0, 255.0) * k).round();
  out[o + 1] = (g.clamp(0.0, 255.0) * k).round();
  out[o + 2] = (b.clamp(0.0, 255.0) * k).round();
  out[o + 3] = a;
}

double _smoothstep(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// A box blur of radius [r], edges clamped: twice is near enough a gaussian.
Float32List _boxBlur(Float32List src, int w, int h, int r) {
  final tmp = Float32List(w * h), out = Float32List(w * h);
  final span = 2 * r + 1;
  for (var y = 0; y < h; y++) {
    final row = y * w;
    var acc = 0.0;
    for (var x = -r; x <= r; x++) {
      acc += src[row + x.clamp(0, w - 1)];
    }
    for (var x = 0; x < w; x++) {
      tmp[row + x] = acc / span;
      acc += src[row + (x + r + 1).clamp(0, w - 1)] -
          src[row + (x - r).clamp(0, w - 1)];
    }
  }
  for (var x = 0; x < w; x++) {
    var acc = 0.0;
    for (var y = -r; y <= r; y++) {
      acc += tmp[y.clamp(0, h - 1) * w + x];
    }
    for (var y = 0; y < h; y++) {
      out[y * w + x] = acc / span;
      acc += tmp[(y + r + 1).clamp(0, h - 1) * w + x] -
          tmp[(y - r).clamp(0, h - 1) * w + x];
    }
  }
  return out;
}

/// The smallest value within [r] of each pixel (a square), edges clamped.
Float32List _minFilter(Float32List src, int w, int h, int r) {
  final tmp = Float32List(w * h), out = Float32List(w * h);
  for (var y = 0; y < h; y++) {
    final row = y * w;
    for (var x = 0; x < w; x++) {
      var v = 1e9;
      for (var d = -r; d <= r; d++) {
        final s = src[row + (x + d).clamp(0, w - 1)];
        if (s < v) v = s;
      }
      tmp[row + x] = v;
    }
  }
  for (var x = 0; x < w; x++) {
    for (var y = 0; y < h; y++) {
      var v = 1e9;
      for (var d = -r; d <= r; d++) {
        final s = tmp[(y + d).clamp(0, h - 1) * w + x];
        if (s < v) v = s;
      }
      out[y * w + x] = v;
    }
  }
  return out;
}

/// [r], [g], [b] (0–255) as hue (0–1), saturation and lightness.
(double, double, double) _toHsl(double r, double g, double b) {
  r /= 255;
  g /= 255;
  b /= 255;
  final mx = math.max(r, math.max(g, b)), mn = math.min(r, math.min(g, b));
  final l = (mx + mn) / 2;
  if (mx == mn) return (0.0, 0.0, l);
  final d = mx - mn;
  final s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
  final double h;
  if (mx == r) {
    h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
  } else if (mx == g) {
    h = ((b - r) / d + 2) / 6;
  } else {
    h = ((r - g) / d + 4) / 6;
  }
  return (h, s, l);
}

double _cbrt(double x) => x <= 0 ? 0 : math.pow(x, 1 / 3).toDouble();

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

Uint8List alchemizeRgba(MutationBakeJob job) {
  final src = job.rgba;
  final w = job.width, h = job.height;
  final out = Uint8List(w * h * 4);
  // Accumulated straight color and coverage, composited at the end.
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
    // mosaic recoloring.
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

        // The patch's color, alpha-weighted over five taps.
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
    // Straight color of the topmost coverage, premultiplied on the way out.
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
