@Tags(['preview'])
library;

// The six stations of open space, as pictures to judge.
//
//   STATION_ART_OUT=/tmp/station_art flutter test \
//     test/station_art_preview_test.dart --tags preview
//
// Writes sheet.png (every station at the closest in-game zoom, beside the
// ship for scale, idle and with the ship alongside), strip_<kind>.png (one
// station over a few seconds) and close_<kind>.png (scaled up).

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/ship_art.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final out = Platform.environment['STATION_ART_OUT'];

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

  double scaleFor(StationKind k) => switch (k) {
    StationKind.starDustScanner || StationKind.planetScanner => 1.35,
    _ => 1.0,
  };

  Future<void> save(ui.Picture pic, int w, int h, String name) async {
    final img = pic.toImageSync(w, h);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    img.dispose();
    pic.dispose();
  }

  test('station art previews', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);

    // In-game: closest zoom is 0.85 on a ~3x screen, so about 2.5 px a unit.
    const unit = 2.5;
    const cell = 420.0;
    final kinds = StationKind.values;
    {
      const cols = 3;
      final rows = (kinds.length * 2 / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final sheet = Rect.fromLTWH(0, 0, cols * cell, rows * cell);
      space(c, sheet, 3);
      var i = 0;
      for (final k in kinds) {
        for (final near in [false, true]) {
          final centre = Offset(
            (i % cols) * cell + cell / 2,
            (i ~/ cols) * cell + cell / 2,
          );
          c.save();
          c.clipRect(Rect.fromCenter(center: centre, width: cell, height: cell));
          c.translate(centre.dx, centre.dy);
          c.scale(unit);
          final s = scaleFor(k);
          paintStation(
            c,
            k,
            at: Offset.zero,
            t: 6.3 + i,
            scale: s,
            wake: near ? 1 : 0,
            aim: near ? -0.7 : null,
            highlight: near ? 1 : null,
          );
          // The ship for scale.
          c.save();
          c.translate(-k.reach * s - 4, 46);
          c.rotate(0.6);
          paintShipHull(c, null, 3);
          c.restore();
          c.restore();
          i++;
        }
      }
      await save(rec.endRecording(), sheet.width.round(),
          sheet.height.round(), 'sheet');
    }

    for (final k in kinds) {
      // Close up, for the material.
      const sz = 900.0;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      space(c, const Rect.fromLTWH(0, 0, sz, sz), 9);
      c.translate(sz / 2, sz / 2);
      c.scale(sz * 0.42 / (k.reach * scaleFor(k)));
      paintStation(c, k, at: Offset.zero, t: 4.2, scale: scaleFor(k));
      await save(rec.endRecording(), sz.round(), sz.round(),
          'close_${k.name}');

      // A strip over time.
      const sc = 300.0;
      const n = 6;
      final rec2 = ui.PictureRecorder();
      final c2 = Canvas(rec2);
      space(c2, const Rect.fromLTWH(0, 0, sc * n, sc), 5);
      for (var j = 0; j < n; j++) {
        c2.save();
        c2.translate(sc * j + sc / 2, sc / 2);
        c2.scale(unit * 0.8);
        paintStation(c2, k, at: Offset.zero, t: j * 0.8, scale: scaleFor(k));
        c2.restore();
      }
      await save(rec2.endRecording(), (sc * n).round(), sc.round(),
          'strip_${k.name}');
    }
  });
}
