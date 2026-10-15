@Tags(['preview'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An Alchemized Alchemon packing itself into the harvest flask, frame by
// frame, then its thicker stream beside a plain one's.
//
//   PACK_OUT=/tmp/pack flutter test \
//     test/extraction_vessel_pack_preview_test.dart --tags preview
// writes f000.png… (every 0.1 s from the pack), stream.png, and prints what
// a frame costs.
void main() {
  final out = Platform.environment['PACK_OUT'];

  testWidgets('alchemized pack preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const side = 300.0;
    const accent = Color(0xFFFF6B35);

    // The sprite baked Alchemized, as the bench shows it, and read into
    // grains the way the vessel reads it.
    final (ui.Image sprite, SpecimenGrains grains) = (await tester.runAsync(
      () async {
        final bytes = File(
          'assets/images/creatures/rare/HOR01_firehorn.png',
        ).readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes, targetWidth: 150);
        final plain = (await codec.getNextFrame()).image;
        final raw = (await plain.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        final baked = bakeMutation(
          MutationBakeJob(
            rgba: Uint8List.fromList(raw),
            width: plain.width,
            height: plain.height,
            frameW: plain.width,
            frameH: plain.height,
            cols: 1,
            frames: 1,
            look: MutationLook.alchemized,
          ),
        );
        final done = Completer<ui.Image>();
        ui.decodeImageFromPixels(
          baked,
          plain.width,
          plain.height,
          ui.PixelFormat.rgba8888,
          done.complete,
        );
        final img = await done.future;
        final data = await img.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        final g = SpecimenGrains.fromRgba(
          data!.buffer.asUint8List(),
          img.width,
          img.height,
          pixelRatio: 1,
          maxGrains: 900,
          tones: 12,
        );
        return (img, g);
      },
    ))!;

    ExtractionVesselField field({required bool alchemized, double level = 0}) {
      final f = ExtractionVesselField()
        ..accent = accent
        ..mode = VesselMode.running
        ..level = level
        ..occupied = true
        ..alchemized = alchemized;
      f.layout(const Size.square(side));
      f.setSpecimen(grains, f.geometry!.creatureCenter);
      return f;
    }

    ui.Image frame(ExtractionVesselField f) {
      final g = f.geometry!;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawRect(
        Offset.zero & const Size.square(side),
        Paint()..color = const Color(0xFF0B0C10),
      );
      f.paintBack(c);
      final cs = g.creatureSize * 0.86;
      c.drawImageRect(
        sprite,
        Offset.zero & Size(sprite.width.toDouble(), sprite.height.toDouble()),
        Rect.fromCenter(
          center: g.creatureCenter,
          width: cs,
          height: cs * sprite.height / sprite.width,
        ),
        Paint()..filterQuality = FilterQuality.medium,
      );
      f.paintFront(c);
      return rec.endRecording().toImageSync(side.toInt(), side.toInt());
    }

    Future<void> save(ui.Image img, String name) => tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name').writeAsBytesSync(png!.buffer.asUint8List());
    });

    // Put in: the stream has just begun, then it packs itself in.
    final f = field(alchemized: true, level: 0.01);
    for (var i = 0; i < 30; i++) {
      f.step(1 / 60);
    }
    f.pack();
    for (var k = 0; k <= 36; k++) {
      await save(frame(f), 'f${k.toString().padLeft(3, '0')}.png');
      for (var i = 0; i < 6; i++) {
        f.step(1 / 60);
      }
    }

    // A plain stream and an Alchemized one, half full.
    final plain = field(alchemized: false, level: 0.55);
    final alc = field(alchemized: true, level: 0.55);
    for (var i = 0; i < 180; i++) {
      plain.step(1 / 60);
      alc.step(1 / 60);
    }
    final rec = ui.PictureRecorder();
    Canvas(rec)
      ..drawImage(frame(plain), Offset.zero, Paint())
      ..drawImage(frame(alc), const Offset(side, 0), Paint());
    await save(
      rec.endRecording().toImageSync((side * 2).toInt(), side.toInt()),
      'stream.png',
    );

    // What a frame costs mid-pack and on a plain run (JIT, so a ceiling).
    double cost(ExtractionVesselField f) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        f.step(1 / 60);
        final r = ui.PictureRecorder();
        final c = Canvas(r);
        f.paintBack(c);
        f.paintFront(c);
        r.endRecording().dispose();
      }
      return sw.elapsedMicroseconds / 60;
    }

    final busy = field(alchemized: true, level: 0.01);
    for (var i = 0; i < 30; i++) {
      busy.step(1 / 60);
    }
    busy.pack();
    for (var i = 0; i < 50; i++) {
      busy.step(1 / 60);
    }
    // ignore: avoid_print
    print(
      'vessel frame µs: plain ${cost(plain).toStringAsFixed(0)}, '
      'alchemized ${cost(alc).toStringAsFixed(0)}, '
      'mid-pack ${cost(busy).toStringAsFixed(0)}',
    );
  });
}
