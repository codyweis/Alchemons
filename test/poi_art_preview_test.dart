@Tags(['preview'])
library;

// The lesser points of interest, as pictures to judge.
//
//   POI_ART_OUT=/tmp/poi_art flutter test \
//     test/poi_art_preview_test.dart --tags preview
//
// Writes sheet.png: each at a portrait phone's middle zoom, with the ship
// for size, in its resting and its active state.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/poi_art.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['POI_ART_OUT'];

  void space(Canvas c, Rect r, int seed) {
    c.drawRect(r, Paint()..color = const Color(0xFF020010));
    final rng = Random(seed);
    final p = Paint();
    for (var i = 0; i < r.width * r.height / 2600; i++) {
      p.color = Colors.white.withValues(alpha: 0.12 + rng.nextDouble() * 0.5);
      c.drawCircle(
        Offset(
          r.left + rng.nextDouble() * r.width,
          r.top + rng.nextDouble() * r.height,
        ),
        0.4 + rng.nextDouble() * 0.9,
        p,
      );
    }
  }

  test('poi art previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const unit = 0.72 * 2; // mid zoom, drawn at 2x
    const cw = 412.0 * 2, ch = 520.0 * 2;
    final scenes = <(String, void Function(Canvas c, bool active))>[
      (
        'nebula',
        (c, a) => paintNebula(
          c,
          at: Offset.zero,
          radius: 120,
          color: const Color(0xFFFF7043),
          t: 9,
          spent: a,
        ),
      ),
      ('derelict', (c, a) => paintDerelict(c, at: Offset.zero, t: 4, looted: a)),
      (
        'meteor zone',
        (c, a) => paintMeteorZone(
          c,
          at: Offset.zero,
          radius: 620,
          color: const Color(0xFF90A4AE),
          fall: 0.9,
          t: 13,
          shower: a ? 1 : 0,
        ),
      ),
      ('warp anomaly', (c, a) => paintWarpAnomaly(c, at: Offset.zero, radius: 42, t: a ? 3.3 : 1)),
      ('survival gate', (c, a) => paintSurvivalGate(c, at: Offset.zero, t: 5, near: a ? 1 : 0)),
      (
        'boss lair',
        (c, a) => paintBossLair(
          c,
          at: Offset.zero,
          element: const Color(0xFFFF5722),
          wakeRadius: 300,
          t: a ? 2.2 : 4,
        ),
      ),
      ('lore note', (c, a) => paintLoreNote(c, at: Offset.zero, t: a ? 2 : 0)),
    ];
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final sheet = Rect.fromLTWH(0, 0, cw * 2, ch * scenes.length);
    space(c, sheet, 3);
    for (var i = 0; i < scenes.length; i++) {
      for (var j = 0; j < 2; j++) {
        final centre = Offset(j * cw + cw / 2, i * ch + ch / 2);
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: cw, height: ch));
        c.translate(centre.dx, centre.dy);
        c.scale(unit);
        scenes[i].$2(c, j == 1);
        c.save();
        c.translate(-170, 150);
        paintShipHull(c, null, 3);
        c.restore();
        c.restore();
      }
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(sheet.width.round(), sheet.height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/sheet.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
