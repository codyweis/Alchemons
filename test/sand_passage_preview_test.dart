@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/sand_passage.dart';
import 'package:alchemons/widgets/wilderness/wild_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Going between the map and a field as sand, both ways, over the real map:
// in (the Valley's circle lifting into the ball, the turn, the ball coming
// undone into the field) and out (the field into the ball, the turn, the
// pour into the circle).
//
//   SANDEXIT_SRC=/tmp/valley/rest.png SANDEXIT_OUT=/tmp/sand \
//     flutter test test/sand_passage_preview_test.dart --tags preview
//
// SANDEXIT_SRC is a field frame at 2x (valley_field_preview_test's rest.png
// at VALLEY_SIZE=860x400); without it a plain gradient stands in. Writes
// key frames (in_*.png, out_*.png), and with SANDEXIT_CLIP=1 every frame at
// 30 fps (clip_0000.png...: in, then out) for ffmpeg.
void main() {
  final out = Platform.environment['SANDEXIT_OUT'];

  testWidgets('sand passage preview', (tester) async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const wide = Size(860, 400);
    const tall = Size(400, 860);
    const pr = 2.0;

    ui.Image fieldImage() {
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        Offset.zero & wide * pr,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, wide.height * pr),
            [
              const Color(0xFF2A3D6E),
              const Color(0xFFE0B070),
              const Color(0xFF2E4A22),
            ],
            [0, 0.55, 0.7],
          ),
      );
      return rec.endRecording().toImageSync(
        (wide.width * pr).round(),
        (wide.height * pr).round(),
      );
    }

    final path = Platform.environment['SANDEXIT_SRC'];
    ui.Image? loaded;
    if (path != null && File(path).existsSync()) {
      loaded = await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(
          File(path).readAsBytesSync(),
        );
        return (await codec.getNextFrame()).image;
      });
    }
    ui.Image field() => loaded?.clone() ?? fieldImage();

    final map = WildMapField()..layout(tall);
    map.settle();
    for (var i = 0; i < 4; i++) {
      map.step(1 / 60);
    }
    final home = map.circleOf(WildRealm.valley);
    ui.Image mapImage() {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(pr);
      c.drawRect(Offset.zero & tall, Paint()..color = const Color(0xFF050507));
      map.paint(c);
      return rec.endRecording().toImageSync(
        (tall.width * pr).round(),
        (tall.height * pr).round(),
      );
    }

    const ground = Color(0xFF050507);
    double smooth(double a, double b, double x) {
      final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    // ── In ────────────────────────────────────────────────────────────────
    final rise = SandPicture(
      image: mapImage(),
      pixelRatio: pr,
      size: tall,
      way: SandWay.gather,
      circle: home,
      element: 'plant',
      seed: 5,
    );
    final into = SandPicture(
      image: field(),
      pixelRatio: pr,
      size: wide,
      way: SandWay.assemble,
      element: 'plant',
      seed: 6,
    );
    // The overlay's timeline, with a 0.3 s turn and a 0.4 s load.
    final swapAt = rise.doneBy + 0.1;
    final inTurned = swapAt + 0.3;
    final assembleAt = inTurned + 0.4;
    final fadeAt = assembleAt + into.doneBy + 0.05;
    final inEnd = fadeAt + 0.3;

    ui.Image inFrame(double t) {
      final portrait = t < inTurned;
      final size = portrait ? tall : wide;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(pr);
      if (portrait) map.paint(c);
      final gone = smooth(0, 1, (t - fadeAt) / 0.3);
      if (t >= fadeAt) {
        // The live field under the fading picture.
        c.drawImageRect(
          into.image,
          Offset.zero & (wide * pr),
          Offset.zero & wide,
          Paint(),
        );
      }
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..color = ground.withValues(alpha: smooth(0, 0.6, t) * (1 - gone)),
      );
      if (t < swapAt) rise.paintHole(c, size, ground);
      final since = t >= assembleAt ? t - assembleAt : null;
      final fade = since == null ? 1.0 : 1 - smooth(0, 0.45, since);
      if (fade > 0) rise.paintGather(c, size, t, fade: fade);
      if (since != null) {
        into.paintAssemble(c, size, t, since, opacity: 1 - gone);
      }
      return rec.endRecording().toImageSync(
        (size.width * pr).round(),
        (size.height * pr).round(),
      );
    }

    // ── Out ───────────────────────────────────────────────────────────────
    final exit = SandPicture(
      image: field(),
      pixelRatio: pr,
      size: wide,
      way: SandWay.gather,
      element: 'plant',
      seed: 3,
    );
    final outSwap = exit.goneBy + 0.45;
    final outTurned = outSwap + 0.3;
    final pourAt = math.max(outTurned, exit.doneBy + 0.15);
    final outEnd = pourAt + SandPicture.pourTime;

    ui.Image outFrame(double t) {
      final portrait = t >= outTurned;
      final size = portrait ? tall : wide;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(pr);
      if (portrait) map.paint(c);
      final dark = t < pourAt ? 1.0 : 1 - smooth(0, 0.55, t - pourAt);
      c.drawRect(
        Offset.zero & size,
        Paint()..color = ground.withValues(alpha: dark),
      );
      exit.paintGather(
        c,
        size,
        t,
        pourAt: t >= pourAt ? pourAt : null,
        home: home,
      );
      return rec.endRecording().toImageSync(
        (size.width * pr).round(),
        (size.height * pr).round(),
      );
    }

    Future<void> save(String name, ui.Image img) async {
      await tester.runAsync(() async {
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    }

    for (final t in [
      0.0,
      0.25,
      0.5,
      0.8,
      swapAt,
      assembleAt + 0.15,
      assembleAt + 0.4,
      assembleAt + 0.65,
      assembleAt + 0.9,
      fadeAt,
    ]) {
      await save('in_${t.toStringAsFixed(2)}', inFrame(t));
    }
    for (final t in [
      0.0,
      0.3,
      0.45,
      0.65,
      outSwap,
      pourAt,
      pourAt + 0.3,
      pourAt + 0.6,
    ]) {
      await save('out_${t.toStringAsFixed(2)}', outFrame(t));
    }

    if (Platform.environment['SANDEXIT_CLIP'] == '1') {
      var k = 0;
      Future<void> clip(ui.Image img) async {
        // Every frame on one canvas size, so ffmpeg can take them.
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        const box = 1720.0;
        c.drawRect(
          const Rect.fromLTWH(0, 0, box, box),
          Paint()..color = const Color(0xFF000000),
        );
        c.drawImage(
          img,
          Offset((box - img.width) / 2, (box - img.height) / 2),
          Paint(),
        );
        await save(
          'clip_${(k++).toString().padLeft(4, '0')}',
          rec.endRecording().toImageSync(box.toInt(), box.toInt()),
        );
      }

      for (var t = 0.0; t <= inEnd + 0.5; t += 1 / 30) {
        await clip(inFrame(t));
      }
      for (var t = 0.0; t <= outEnd + 0.4; t += 1 / 30) {
        await clip(outFrame(t));
      }
    }
    rise.dispose();
    into.dispose();
    exit.dispose();
    map.dispose();
  });
}
