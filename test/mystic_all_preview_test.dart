@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// MYSTIC_ALL_OUT=/path/sheet.png flutter test test/mystic_all_preview_test.dart
// Every Mystic world painter, at game proportions scaled down to fit a cell.

const _cell = 300.0;
const _cols = 5;

void main() {
  test('every mystic world painter', () async {
    final cells = <(String, void Function(Canvas))>[
      (
        'Dawn · charging',
        (c) => drawMysticDawnStar(
          canvas: (c..scale(0.55)),
          at: Offset.zero,
          charge: 0.45,
          flare: 0,
          alpha: 1,
          time: 1.3,
        ),
      ),
      (
        'Dawn · ready',
        (c) => drawMysticDawnStar(
          canvas: (c..scale(0.55)),
          at: Offset.zero,
          charge: 1,
          flare: 0,
          alpha: 1,
          time: 1.3,
        ),
      ),
      (
        'Dawn · release',
        (c) => drawMysticDawnStar(
          canvas: (c..scale(0.55)),
          at: Offset.zero,
          charge: 1,
          flare: 0.7,
          alpha: 1,
          time: 1.3,
        ),
      ),
      (
        'Maw (Dark)',
        (c) {
          c.scale(0.3);
          drawMysticMaw(
            canvas: c,
            centre: Offset.zero,
            horizonRadius: 430 * 0.17,
            open: 1,
            spin: 1.2,
            alpha: 1,
            time: 1.3,
          );
        },
      ),
      (
        'Maelstrom (Water)',
        (c) {
          c.scale(0.3);
          drawMysticMaelstrom(
            canvas: c,
            centre: Offset.zero,
            radius: 460,
            phase: 1.2,
            alpha: 1,
            time: 1.3,
          );
        },
      ),
      (
        'Tornado (Air)',
        (c) {
          c.scale(0.6);
          drawMysticTornado(
            canvas: c,
            at: Offset.zero,
            radius: 190,
            phase: 1.2,
            travelAngle: pi / 2,
            alpha: 1,
            time: 1.3,
          );
        },
      ),
      (
        'Revenants (Spirit)',
        (c) {
          c.scale(2);
          for (var i = 0; i < 3; i++) {
            drawMysticRevenant(
              canvas: c,
              position: Offset(-40 + i * 40.0, 0),
              velocity: const Offset(40, 0),
              radius: 10 + i * 3.0,
              rise: 1,
              life: 3,
              alpha: 1,
              time: 1.3,
              seed: i * 1.7,
            );
          }
        },
      ),
      (
        'Storm charge (Lightning)',
        (c) => drawMysticStormCharge(
          canvas: c,
          at: Offset.zero,
          progress: 0.7,
          seed: 2,
          time: 1.3,
        ),
      ),
      (
        'Bolt (Lightning)',
        (c) => drawMysticLightningBolt(
          canvas: c,
          strike: const Offset(0, 90),
          progress: 0.25,
          seed: 3,
          onBoss: false,
        ),
      ),
      (
        'Quake (Earth)',
        (c) {
          c.scale(0.3);
          drawMysticQuake(
            canvas: c,
            centre: Offset.zero,
            radius: 450,
            progress: 0.35,
            earth: elementColor('Earth'),
          );
        },
      ),
      (
        'Vent (Steam)',
        (c) {
          c.scale(0.5);
          drawMysticVent(
            canvas: c,
            centre: Offset.zero,
            radius: 240,
            progress: 0.3,
            time: 1.3,
          );
        },
      ),
      (
        'Poison patches',
        (c) {
          for (var i = 0; i < 3; i++) {
            drawMysticPoisonPatch(
              canvas: c,
              centre: Offset(-70 + i * 70.0, 0),
              radius: 44,
              alpha: 1,
              seed: i * 2.3,
              time: 1.3,
              poison: elementColor('Poison'),
            );
          }
        },
      ),
      (
        'Crystal shards',
        (c) {
          c.scale(2);
          for (var i = 0; i < 3; i++) {
            drawMysticCrystalShard(
              canvas: c,
              at: Offset(-40 + i * 40.0, 0),
              alpha: 1,
              seed: i * 1.9,
              time: 1.3,
              tint: elementColor('Crystal'),
            );
          }
        },
      ),
      (
        'Fissure (Lava)',
        (c) {
          c.scale(0.6);
          drawMysticFissure(
            canvas: c,
            points: const [
              Offset(-200, -40),
              Offset(-80, 10),
              Offset(30, -20),
              Offset(200, 30),
            ],
            alpha: 1,
            flare: 0.3,
            seed: 1.1,
            time: 1.3,
          );
        },
      ),
      (
        'Lava meteor + scorch',
        (c) {
          drawMysticScorch(
            canvas: c,
            at: const Offset(-50, 30),
            age: 1,
            maxAge: 4,
            seed: 1,
          );
          drawMysticLavaMeteor(
            canvas: c,
            impact: const Offset(50, 30),
            progress: 0.6,
            seed: 2,
          );
        },
      ),
      for (final e in const [
        'Plant',
        'Earth',
        'Mud',
        'Crystal',
        'Dust',
        'Poison',
        'Ice',
        'Fire',
        'Blood',
      ])
        (
          'Flora · $e',
          (c) {
            for (var i = 0; i < 3; i++) {
              drawMysticFlora(
                canvas: c,
                at: Offset(-80 + i * 80.0, 20),
                element: e,
                size: 1.2 + i * 0.2,
                bloom: 1,
                seed: i * 1.3,
                time: 1.3,
                tint: elementColor(e),
              );
            }
          },
        ),
    ];
    final rows = (cells.length / _cols).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _cell * _cols, _cell * rows),
      Paint()..color = const Color(0xFF07080F),
    );
    for (var i = 0; i < cells.length; i++) {
      final (label, paint) = cells[i];
      final x = (i % _cols) * _cell, y = (i ~/ _cols) * _cell;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(x, y, _cell, _cell));
      canvas.translate(x + _cell / 2, y + _cell / 2 + 10);
      paint(canvas);
      canvas.restore();
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFFC9D8EE), fontSize: 13),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x + 8, y + 6));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_cell * _cols).toInt(),
      (_cell * rows).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['MYSTIC_ALL_OUT'];
    if (out != null) await File(out).writeAsBytes(bytes!.buffer.asUint8List());
  });
}
