@Tags(['preview'])
library;

// The great landmarks, as pictures to judge.
//
//   LANDMARK_ART_OUT=/tmp/landmarks flutter test \
//     test/landmark_art_preview_test.dart --tags preview
//
// Writes sheet.png: each at a portrait phone's middle zoom, the ship for
// size, in two of its states.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/landmark_art.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['LANDMARK_ART_OUT'];

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

  test('landmark art previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const unit = 0.72 * 2;
    const cw = 412.0 * 2, ch = 915.0 * 2;
    final scenes = <(String, void Function(Canvas c, bool alt))>[
      (
        'galaxy whirl',
        (c, a) => paintGalaxyWhirl(
          c,
          at: Offset.zero,
          radius: 65,
          color: const Color(0xFF4FC3F7),
          spin: 2,
          t: 3,
          look: a ? WhirlLook.active : WhirlLook.dormant,
        ),
      ),
      (
        'nexus',
        (c, a) => paintElementalNexus(
          c,
          at: Offset.zero,
          radius: 300,
          t: a ? 9 : 4,
          near: a ? 1 : 0,
        ),
      ),
      (
        'blood ring: quiet | armed',
        (c, a) => paintBloodRing(
          c,
          at: Offset.zero,
          radius: 320,
          t: 6,
          armed: a ? 1 : 0,
        ),
      ),
      (
        'blood ring: ritual half | ritual flood',
        (c, a) => paintBloodRing(
          c,
          at: Offset.zero,
          radius: 320,
          t: 6,
          armed: 1,
          ritual: a ? 0.86 : 0.45,
        ),
      ),
      (
        'blood ring: opened',
        (c, a) => paintBloodRing(
          c,
          at: Offset.zero,
          radius: 320,
          t: a ? 11 : 6,
          opened: true,
        ),
      ),
      (
        'prismatic aurora',
        (c, a) => paintPrismaticAurora(
          c,
          at: const Offset(0, -60),
          radius: 600,
          t: 7,
          claimed: a,
        ),
      ),
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
        c.translate(-120, 420);
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
