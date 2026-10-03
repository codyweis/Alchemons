@Tags(['preview'])
library;

// The four contest arenas, as pictures to judge.
//
//   CONTEST_ART_OUT=/tmp/contest_art flutter test \
//     test/contest_art_preview_test.dart --tags preview
//
// Writes sheet.png: each arena at rest and mid-contest, at the in-game
// scale of a portrait phone at the middle zoom, with the ship for size.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/contest_art.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['CONTEST_ART_OUT'];

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

  test('contest arena previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // Portrait phone, 412 points wide, mid zoom 0.72, drawn at 2x.
    const unit = 0.72 * 2;
    const cw = 412.0 * 2, ch = 620.0 * 2;
    final traits = CosmicContestTrait.values;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final sheet = Rect.fromLTWH(0, 0, cw * 2, ch * traits.length);
    space(c, sheet, 3);
    for (var i = 0; i < traits.length; i++) {
      for (var j = 0; j < 2; j++) {
        final centre = Offset(j * cw + cw / 2, i * ch + ch / 2);
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: cw, height: ch));
        c.translate(centre.dx, centre.dy);
        c.scale(unit);
        paintContestArena(
          c,
          traits[i],
          at: Offset.zero,
          t: 7.3 + i,
          active: j == 0 ? 0 : 1,
          focus: j == 0
              ? null
              : switch (traits[i]) {
                  CosmicContestTrait.strength => const Offset(38, 24),
                  CosmicContestTrait.intelligence => const Offset(52, 10),
                  _ => null,
                },
        );
        c.save();
        c.translate(-150, 120);
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

  // mastered.png: each arena crowned — three moments of the unveiling
  // (burst, leaves growing, settled) and then at rest long after.
  test('mastered contest arena previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // Pulled back to the camera's contest framing, so the whole crown shows.
    const unit = 0.45 * 2;
    const cw = 412.0 * 2, ch = 720.0 * 2;
    const ages = [0.6, 2.2, 4.0, 1000.0];
    final traits = CosmicContestTrait.values;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final sheet = Rect.fromLTWH(0, 0, cw * ages.length, ch * traits.length);
    space(c, sheet, 5);
    for (var i = 0; i < traits.length; i++) {
      for (var j = 0; j < ages.length; j++) {
        final centre = Offset(j * cw + cw / 2, i * ch + ch / 2 + 60);
        c.save();
        c.clipRect(
          Rect.fromCenter(
            center: centre - const Offset(0, 60),
            width: cw,
            height: ch,
          ),
        );
        c.translate(centre.dx, centre.dy);
        c.scale(unit);
        paintContestArena(
          c,
          traits[i],
          at: Offset.zero,
          t: 7.3 + i + ages[j],
          mastery: ages[j],
        );
        c.save();
        c.translate(-150, 120);
        paintShipHull(c, null, 3);
        c.restore();
        c.restore();
      }
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync(sheet.width.round(), sheet.height.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/mastered.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
