@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/wilderness/field/sand_floor.dart';
import 'package:alchemons/models/home_sand.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Living Sands' floor on its own, one tile, in each pattern and setting,
// and with a finger drawn through it — springing back, staying and mixing.
//
//   SAND_FLOOR_OUT=/tmp/sand_floor flutter test \
//     test/sand_floor_preview_test.dart --tags preview
//
// SAND_FLOOR_ONLY=marbled,layered,… picks shots; SAND_FLOOR_DPR the scale
// (default 2).
void main() {
  final out = Platform.environment['SAND_FLOOR_OUT'];
  final only = Platform.environment['SAND_FLOOR_ONLY']?.split(',').toSet();
  final dpr =
      double.tryParse(Platform.environment['SAND_FLOOR_DPR'] ?? '') ?? 2;
  bool wants(String id) => only == null || only.contains(id);
  const tile = Size(933, 412);
  const five = HomeSandStyle(count: 5);

  // A finger drawn in an S across the middle in [time] s, sampled twice a
  // frame (a 120 Hz screen).
  void stroke(SandFloor f, {double time = 0.9}) {
    final steps = (time * 120).round();
    Offset at(double t) =>
        Offset(180 + 560 * t, 206 + 90 * math.sin(t * math.pi * 2));
    for (var i = 1; i <= steps; i++) {
      final p = at(i / steps), was = at((i - 1) / steps);
      f.stir(p, p - was, 1 / 120);
      if (i.isEven) f.step(1 / 60);
    }
  }

  test('sand floor preview', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    Future<void> shoot(
      String id,
      HomeSandStyle style, {
      void Function(SandFloor f)? then,
      double settle = 0,
    }) async {
      if (!wants(id)) return;
      final f = SandFloor(style)..layout(tile);
      f.step(1 / 60);
      then?.call(f);
      for (var t = 0.0; t < settle; t += 1 / 60) {
        f.step(1 / 60);
      }
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(dpr);
      // On the realm's dark, as the screen lays it.
      c.drawRect(Offset.zero & tile, Paint()..color = const Color(0xFF0B090F));
      f.paint(c);
      final img = await rec.endRecording().toImage(
        (tile.width * dpr).round(),
        (tile.height * dpr).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$id.png').writeAsBytesSync(png!.buffer.asUint8List());
      f.dispose();
    }

    await shoot('marbled', const HomeSandStyle());
    await shoot('marbled5', five);
    await shoot('layered', five.copyWith(pattern: SandPattern.layered));
    await shoot('drifts', five.copyWith(pattern: SandPattern.drifts));
    await shoot('mixed', five.copyWith(pattern: SandPattern.mixed));
    await shoot('one', const HomeSandStyle(count: 1));
    await shoot('glinting', const HomeSandStyle(sparkle: 1));
    await shoot('sparse', const HomeSandStyle(density: 0, grain: 0));
    await shoot('thick', const HomeSandStyle(density: 1, grain: 1));
    await shoot('stirring', const HomeSandStyle(), then: stroke);
    await shoot(
      'stayed',
      const HomeSandStyle(motion: SandMotion.staysPut),
      then: stroke,
      settle: 3,
    );
    await shoot(
      'smoothing',
      const HomeSandStyle(motion: SandMotion.staysPut),
      then: (f) {
        stroke(f);
        for (var i = 0; i < 180; i++) {
          f.step(1 / 60);
        }
        f.smooth();
      },
      settle: 0.15,
    );
    const mixes = HomeSandStyle(motion: SandMotion.mixes);
    await shoot('mixing', mixes, then: stroke);
    await shoot('mixes', mixes, then: stroke, settle: 3);
    await shoot(
      'twisted',
      mixes,
      then: (f) {
        for (final at in const [
          Offset(330, 200),
          Offset(520, 150),
          Offset(640, 300),
        ]) {
          f.ripple(at);
        }
      },
      settle: 1,
    );
    // Drawn back and forth across the middle like a comb, then three taps.
    await shoot(
      'combed',
      five.copyWith(motion: SandMotion.mixes),
      then: (f) {
        for (var pass = 0; pass < 6; pass++) {
          final y = 120.0 + 34 * pass, dir = pass.isEven ? 1.0 : -1.0;
          for (var i = 0; i <= 120; i++) {
            final x = dir > 0 ? 100 + 6.0 * i : 820 - 6.0 * i;
            f.stir(Offset(x, y), Offset(6 * dir, 0), 1 / 120);
            if (i.isEven) f.step(1 / 60);
          }
        }
        for (final at in const [
          Offset(250, 140),
          Offset(470, 260),
          Offset(690, 160),
        ]) {
          f.ripple(at);
        }
      },
      settle: 3,
    );
  });
}
