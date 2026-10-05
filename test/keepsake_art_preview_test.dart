@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/home_keepsakes.dart';
import 'package:alchemons/widgets/fx/keepsake_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Every keepsake of the home biome, by day and by night, each on a patch
// of dark ground, in shelf order (then the second portal and an effigy's
// plinth).
//
//   KEEPSAKE_OUT=/tmp/keepsakes flutter test \
//     test/keepsake_art_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['KEEPSAKE_OUT'];

  test('keepsake art preview', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final pieces = [
      for (final k in Keepsake.all) (k.id, 0),
      ('twin_portals', 1),
      ('effigy:LET01', 0),
    ];
    const cell = Size(150, 260);
    const cols = 8;
    const scale = 2.0;
    for (final (label, night, t) in [
      ('day', 0.0, 3.2),
      ('night', 1.0, 7.9),
    ]) {
      final rows = (pieces.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      c.drawRect(
        Rect.fromLTWH(0, 0, cell.width * cols, cell.height * rows),
        Paint()
          ..color = night > 0.5
              ? const Color(0xFF070A12)
              : const Color(0xFF2A3440),
      );
      for (var i = 0; i < pieces.length; i++) {
        final (id, copy) = pieces[i];
        final art = KeepsakeArt.of(id, copy: copy)!;
        final x = (i % cols) * cell.width + cell.width / 2;
        final y = (i ~/ cols) * cell.height + cell.height - 30;
        c.drawRect(
          Rect.fromLTRB(x - cell.width / 2, y, x + cell.width / 2, y + 30),
          Paint()..color = const Color(0xFF15181E),
        );
        c.save();
        c.translate(x, y);
        art.paint(
          c,
          KeepsakeTime(t: t, night: night, daylight: 1 - night, stir: 0),
        );
        c.restore();
      }
      final img = await rec.endRecording().toImage(
        (cell.width * cols * scale).round(),
        (cell.height * rows * scale).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File(
        '$out/keepsakes_$label.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    }
  });

  test('decor art preview', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    final pieces = [
      for (final d in HomeDecor.all)
        for (var st = 0; st < (d.styles.isEmpty ? 1 : 1); st++) (d.id, st),
    ];
    const cell = Size(260, 380);
    const cols = 7;
    const scale = 1.6;
    for (final (label, night, t, stir) in [
      ('day', 0.0, 3.2, 0.0),
      ('night', 1.0, 7.9, 0.0),
      ('stirred', 0.6, 5.1, 1.0),
    ]) {
      final rows = (pieces.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(scale);
      c.drawRect(
        Rect.fromLTWH(0, 0, cell.width * cols, cell.height * rows),
        Paint()
          ..color = night > 0.5
              ? const Color(0xFF070A12)
              : const Color(0xFF2A3440),
      );
      for (var i = 0; i < pieces.length; i++) {
        final (id, style) = pieces[i];
        final art = KeepsakeArt.of(id, style: style)!;
        final x = (i % cols) * cell.width + cell.width / 2;
        final y = (i ~/ cols) * cell.height + cell.height - 40;
        c.drawRect(
          Rect.fromLTRB(x - cell.width / 2, y, x + cell.width / 2, y + 40),
          Paint()..color = const Color(0xFF15181E),
        );
        c.save();
        c.translate(x, y);
        // Drawn as the field draws them: ×0.62 of a creature's units, and
        // a creature-sized ghost for scale at its first seat.
        c.scale(0.62);
        final k = KeepsakeTime(t: t, night: night, daylight: 1 - night, stir: stir);
        art.paint(c, k);
        for (final seat in art.seats(k)) {
          c.drawCircle(
            Offset(seat.dx, -seat.dy),
            5,
            Paint()..color = const Color(0xFF66FF88),
          );
        }
        if (art.hasFront) art.front(c, k);
        c.restore();
        // A creature's size on its row, 100 units, for scale.
        c.drawRect(
          Rect.fromLTWH(x + cell.width / 2 - 34, y - 60, 30, 60),
          Paint()..color = const Color(0x22FFFFFF),
        );
      }
      final img = await rec.endRecording().toImage(
        (cell.width * cols * scale).round(),
        (cell.height * rows * scale).round(),
      );
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/decor_$label.png').writeAsBytesSync(png!.buffer.asUint8List());
    }
  });
}
