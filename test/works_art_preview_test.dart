@Tags(['preview'])
library;

// The Works' buildings, as pictures to judge.
//
//   WORKS_ART_OUT=/tmp/works_art flutter test \
//     test/works_art_preview_test.dart --tags preview
//
// Writes sheet.png (each building at the in-game zoom, the ship for scale:
// extractor tiers and fills on a planet's rim, the bay and the press at
// rest and at work), close_<name>.png (scaled up for the material) and
// strip_<name>.png (over a few seconds).

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/games/cosmic/works_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['WORKS_ART_OUT'];

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

  /// A plain lit planet whose top edge is at the origin.
  void planetBelow(Canvas c, Color col, double r) {
    final centre = Offset(0, r);
    c.drawCircle(
      centre,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          centre + Offset(-r * 0.4, -r * 0.5),
          r * 1.4,
          [
            Color.lerp(col, Colors.white, 0.25)!,
            col,
            Color.lerp(col, Colors.black, 0.85)!,
          ],
          const [0.0, 0.35, 1.0],
        ),
    );
  }

  Future<void> save(ui.Picture pic, int w, int h, String name) async {
    final img = pic.toImageSync(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
    pic.dispose();
  }

  const fire = Color(0xFFFF6B2B);
  const water = Color(0xFF2E9BFF);
  const crystal = Color(0xFFB388FF);

  test('works art previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    // In-game: about 2.5 px a world unit at the closest zoom; the rigs are
    // drawn at 1.6 world units an art unit.
    const unit = 2.5;
    const artScale = 1.6;
    const cell = 420.0;
    final cells = <void Function(Canvas)>[
      for (final (tier, fill, col) in [
        (1, 0.0, fire),
        (1, 0.55, fire),
        (2, 1.0, water),
        (3, 0.7, crystal),
      ])
        (c) {
          c.translate(0, 70);
          planetBelow(c, col, 150);
          paintExtractor(
            c,
            at: Offset.zero,
            essence: col,
            tier: tier,
            t: 5.1 + tier,
            scale: artScale,
            fill: fill,
            mining: tier != 1 || fill > 0,
          );
        },
      (c) => paintScavengerBay(
        c,
        at: Offset.zero,
        tier: 2,
        t: 3.4,
        scale: artScale,
        resting: const [true, false],
        crates: const [fire, water, crystal],
        crateCap: 12,
        searching: true,
      ),
      (c) => paintScavengerBay(
        c,
        at: Offset.zero,
        tier: 3,
        t: 7.4,
        scale: artScale,
        resting: const [true, true, true],
        crates: const [],
        crateCap: 20,
      ),
      (c) =>
          paintSilverPress(c, at: Offset.zero, tier: 1, t: 2, scale: artScale),
      (c) => paintSilverPress(
        c,
        at: Offset.zero,
        tier: 3,
        t: 1.3,
        scale: artScale,
        pressing: true,
        intake: const [fire, water],
      ),
      (c) => paintGrainFlow(
        c,
        from: const Offset(-70, 50),
        to: const Offset(70, -50),
        p: 0.45,
        colors: const [fire, water],
      ),
    ];
    {
      const cols = 3;
      final rows = (cells.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final sheet = Rect.fromLTWH(0, 0, cols * cell, rows * cell);
      space(c, sheet, 3);
      for (var i = 0; i < cells.length; i++) {
        final centre = Offset(
          (i % cols) * cell + cell / 2,
          (i ~/ cols) * cell + cell / 2,
        );
        c.save();
        c.clipRect(Rect.fromCenter(center: centre, width: cell, height: cell));
        c.translate(centre.dx, centre.dy);
        c.scale(unit);
        cells[i](c);
        c.save();
        c.translate(-60, -50);
        c.rotate(0.6);
        paintShipHull(c, null, 3);
        c.restore();
        c.restore();
      }
      await save(
        rec.endRecording(),
        sheet.width.round(),
        sheet.height.round(),
        'sheet',
      );
    }

    final closes = <String, void Function(Canvas, double t)>{
      'extractor': (c, t) {
        c.translate(0, 34);
        planetBelow(c, fire, 120);
        paintExtractor(
          c,
          at: Offset.zero,
          essence: fire,
          tier: 3,
          t: t,
          fill: 0.62,
        );
      },
      'extractor_full': (c, t) {
        c.translate(0, 34);
        planetBelow(c, water, 120);
        paintExtractor(
          c,
          at: Offset.zero,
          essence: water,
          tier: 2,
          t: t,
          fill: 1,
        );
      },
      'bay': (c, t) => paintScavengerBay(
        c,
        at: Offset.zero,
        tier: 3,
        t: t,
        resting: const [true, false, true],
        crates: const [fire, water, crystal, fire],
        crateCap: 6,
        searching: true,
      ),
      'press': (c, t) => paintSilverPress(
        c,
        at: Offset.zero,
        tier: 2,
        t: t,
        pressing: true,
        intake: const [fire],
      ),
    };
    for (final e in closes.entries) {
      const sz = 900.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      space(c, const Rect.fromLTWH(0, 0, sz, sz), 9);
      c.translate(sz / 2, sz / 2);
      c.scale(sz * 0.42 / 62);
      e.value(c, 4.2);
      await save(rec.endRecording(), sz.round(), sz.round(), 'close_${e.key}');

      const sc = 300.0;
      const n = 6;
      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      space(c2, const Rect.fromLTWH(0, 0, sc * n, sc), 5);
      for (var j = 0; j < n; j++) {
        c2.save();
        c2.translate(sc * j + sc / 2, sc / 2);
        c2.scale(2.2);
        e.value(c2, j * 0.6);
        c2.restore();
      }
      await save(
        rec2.endRecording(),
        (sc * n).round(),
        sc.round(),
        'strip_${e.key}',
      );
    }
  });
}
