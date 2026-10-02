// lib/screens/mystic_altar/altar_grains.dart
//
// What the Mystic Altar is drawn from: its relics, its Mystics and their
// offerings, each read out of its painting into grains (see SpecimenGrains),
// and the colours each element burns with here. Everything on the altar is
// made of these, the way the fusion, the harvest and the cultivations are.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Reads the altar's paintings into grains, once each.
class AltarGrains {
  AltarGrains._();

  static final Map<String, Future<SpecimenGrains?>> _cache = {};

  /// [path] read into grains at [width] px across: grain positions are in
  /// those px, from the image's centre. [frame] crops a sprite sheet to its
  /// first frame (in the sheet's own px), so the grains stand exactly where
  /// the animated sprite will.
  static Future<SpecimenGrains?> asset(
    String path, {
    required int width,
    int maxGrains = 1200,
    int tones = 12,
    Size? frame,
  }) {
    final key = '$path|$width|$maxGrains|$tones|$frame';
    return _cache.putIfAbsent(key, () async {
      try {
        return await _read(path, width, maxGrains, tones, frame);
      } catch (_) {
        return null;
      }
    });
  }

  static Future<SpecimenGrains?> _read(
    String path,
    int width,
    int maxGrains,
    int tones,
    Size? frame,
  ) async {
    final data = await rootBundle.load(path);
    final bytes = data.buffer.asUint8List();
    ui.Image src;
    var crop = Rect.zero;
    if (frame == null) {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      src = (await codec.getNextFrame()).image;
      crop = Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble());
    } else {
      // The sheet's first frame, drawn down to [width] across below.
      final codec = await ui.instantiateImageCodec(bytes);
      src = (await codec.getNextFrame()).image;
      crop = Rect.fromLTWH(
        0,
        0,
        math.min(frame.width, src.width.toDouble()),
        math.min(frame.height, src.height.toDouble()),
      );
    }
    final k = width / crop.width;
    final w = width, h = math.max(1, (crop.height * k).round());
    final rec = ui.PictureRecorder();
    Canvas(rec).drawImageRect(
      src,
      crop,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final img = rec.endRecording().toImageSync(w, h);
    try {
      final px = await img.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (px == null) return null;
      final g = SpecimenGrains.fromRgba(
        px.buffer.asUint8List(),
        w,
        h,
        pixelRatio: 1,
        maxGrains: maxGrains,
        tones: tones,
      );
      return g.length < 24 ? null : g;
    } finally {
      img.dispose();
      src.dispose();
    }
  }

  /// A relic, small: it sits on a seat of the ring.
  static Future<SpecimenGrains?> relic(AltarEntry e, {int width = 46}) =>
      asset(e.relicImagePath, width: width, maxGrains: 560, tones: 8);

  /// A creature at [width] px across, read from its sprite sheet's first
  /// frame where it has one.
  static Future<SpecimenGrains?> creature(
    Creature c, {
    required int width,
    int maxGrains = 1600,
    int tones = 14,
  }) {
    final sd = c.spriteData;
    if (sd != null) {
      return asset(
        'assets/images/${sd.spriteSheetPath}',
        width: width,
        maxGrains: maxGrains,
        tones: tones,
        frame: Size(sd.frameWidth.toDouble(), sd.frameHeight.toDouble()),
      );
    }
    return asset(
      'assets/images/${c.image}',
      width: width,
      maxGrains: maxGrains,
      tones: tones,
    );
  }
}

/// How an element burns on the altar: shadow, body, lit, glint.
List<Color> altarRamp(String element) =>
    essenceRamp(EssenceElement.of(element));

/// An element's one colour here — its lit shade, which every element's ramp
/// keeps bright enough to read on the altar's black. Dark's lit shade sinks,
/// so it burns at its glint.
Color altarAccent(String element) {
  final e = EssenceElement.of(element);
  final r = essenceRamp(e);
  return e == EssenceElement.dark ? r[3] : r[2];
}

/// An element's colour as words: its accent lifted toward parchment, so
/// Lava's and Blood's reds and Dark's violet stay legible.
Color altarInk(String element) =>
    Color.lerp(altarAccent(element), AltarTone.parchment, 0.35)!;

/// The altar's tokens: the void, parchment and ash, and the arcane violet the
/// altar's own heart is drawn in until Blood claims it.
class AltarTone {
  AltarTone._();
  static const Color void0 = Color(0xFF040307);
  static const Color void1 = Color(0xFF0B0812);
  static const Color parchment = Color(0xFFE8DFC8);
  static const Color parchmentDim = Color(0xFFB5A98A);
  static const Color muted = Color(0xFF7D7062);
  static const Color ash = Color(0xFF5E5868);
  static const Color gold = Color(0xFFE4C16A);
  static const Color violet = Color(0xFFAB78FF);
  static const Color violetDeep = Color(0xFF3B2470);
  static const Color blood = Color(0xFFDC2F3A);
}
