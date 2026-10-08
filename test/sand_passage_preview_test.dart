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
// in (the Valley's circle lifting into the ball, the turn, the ball opening
// onto the field) and out (the field into the ball, the turn, the pour into
// the circle).
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
      circle: home,
      element: 'plant',
      seed: 5,
    );
    final live = field();
    // The overlay's timeline: the ball out for a 0.3 s turn, lit again,
    // then open onto the field (already built).
    final dimAt = rise.doneBy + 0.1;
    final swapAt = dimAt + 0.3;
    final inTurned = swapAt + 0.3;
    final lightAt = inTurned + 0.06;
    final openAt = lightAt + 0.35;
    final inEnd = openAt + SandHole.time;

    void paintHole(Canvas c, Size size, double open, Offset centre) {
      final r = SandHole.radius(size, open);
      // Going in the edge softens as it opens; leaving it stays tight.
      final f = centre == size.center(Offset.zero)
          ? SandHole.closingEdge(size)
          : SandHole.feather(size, open);
      final reach = r + f;
      if (reach <= 0.5) {
        c.drawRect(Offset.zero & size, Paint()..color = ground);
        return;
      }
      final start = math.max(0.0, r) / reach;
      final stops = [for (var k = 0; k <= 4; k++) start + (1 - start) * k / 4];
      c.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.radial(
            centre,
            reach,
            [
              for (final at in stops)
                ground.withValues(alpha: smooth(r, reach, at * reach)),
            ],
            stops,
          ),
      );
    }

    ui.Image inFrame(double t) {
      final portrait = t < inTurned;
      final size = portrait ? tall : wide;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(pr);
      if (portrait) map.paint(c);
      if (t >= openAt) {
        // The live field, settling back as the hole opens onto it.
        final since = t - openAt;
        final open = SandHole.open(since);
        final k = 1 + 0.06 * (1 - open);
        c
          ..save()
          ..translate(wide.width / 2, wide.height / 2)
          ..scale(k)
          ..translate(-wide.width / 2, -wide.height / 2)
          ..drawImageRect(
            live,
            Offset.zero & (wide * pr),
            Offset.zero & wide,
            Paint()..filterQuality = FilterQuality.medium,
          )
          ..restore();
        paintHole(c, size, open, SandHole.centre(size, open, rise.lean));
        rise.paintOpen(c, size, t, since);
      } else {
        c.drawRect(
          Offset.zero & size,
          Paint()..color = ground.withValues(alpha: smooth(0, 0.6, t)),
        );
        if (t < swapAt) rise.paintHole(c, size, ground);
        final lit = t < lightAt
            ? 1 - smooth(dimAt, swapAt, t)
            : smooth(lightAt, openAt, t);
        if (lit > 0.002) {
          final k = 0.55 + 0.45 * lit;
          c
            ..save()
            ..translate(size.width / 2, size.height / 2)
            ..scale(k)
            ..translate(-size.width / 2, -size.height / 2);
          rise.paintGather(c, size, t, fade: lit);
          c.restore();
        }
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
      if (portrait) {
        map.paint(c);
        final dark = t < pourAt ? 1.0 : 1 - smooth(0, 0.55, t - pourAt);
        c.drawRect(
          Offset.zero & size,
          Paint()..color = ground.withValues(alpha: dark),
        );
      } else {
        // The field, still live, as the dark closes in on it.
        c.drawImageRect(
          live,
          Offset.zero & (wide * pr),
          Offset.zero & wide,
          Paint()..filterQuality = FilterQuality.medium,
        );
        paintHole(
          c,
          size,
          SandHole.closing(size, t),
          size.center(Offset.zero),
        );
      }
      exit.paintGather(
        c,
        size,
        t,
        pourAt: t >= pourAt ? pourAt : null,
        home: home,
        live: true,
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
      dimAt,
      openAt,
      openAt + 0.2,
      openAt + 0.35,
      openAt + 0.5,
      openAt + 0.65,
      openAt + 0.8,
      openAt + 1.0,
      openAt + 1.25,
      openAt + 1.5,
    ]) {
      await save('in_${t.toStringAsFixed(2)}', inFrame(t));
    }
    for (final t in [
      0.0,
      0.1,
      0.2,
      0.3,
      0.4,
      0.5,
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
    live.dispose();
    exit.dispose();
    map.dispose();
  });
}
