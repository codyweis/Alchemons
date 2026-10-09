@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/particle_title.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The home screen's particle title, frame by frame: the intro filling in
// letter by letter, a drag, a tap, a recolor, Void's black hole, and the
// light theme — plus what each costs.
//
//   TITLE_OUT=/tmp/title.png flutter test \
//     test/particle_title_preview_test.dart --tags preview
void main() {
  final out = Platform.environment['TITLE_OUT'];

  testWidgets('particle title preview', (tester) async {
    if (out == null) return;
    late TitleSamples gold, ink;
    await tester.runAsync(() async {
      gold = await TitleSamples.of('assets/images/ui/alchemonstitle.png');
      ink = await TitleSamples.of('assets/images/ui/alchemonstitledark.png');
    });
    // ignore: avoid_print
    print('grains: gold ${gold.length}, ink ${ink.length}');

    const dt = 1 / 60;
    final frames = <(String, ui.Image)>[];
    const scale = 3.0;
    const pad = 14.0;

    ui.Image shoot(TitleParticleField f, double now, {bool dark = true}) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      final w = TitleSamples.box.width * scale;
      final h = (TitleSamples.box.height + pad * 2) * scale;
      c.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = dark ? const Color(0xFF0B0A16) : const Color(0xFFF1ECE0),
      );
      c.scale(scale);
      f.paint(c, const Offset(0, pad), now, darkBackdrop: dark);
      return rec.endRecording().toImageSync(w.round(), h.round());
    }

    double run(TitleParticleField f, double from, double to,
        [void Function(double t)? each]) {
      var t = from;
      while (t < to) {
        each?.call(t);
        f.step(dt, t);
        t += dt;
      }
      return t;
    }

    // The intro.
    final f = TitleParticleField(gold)..hideForIntro();
    f.startIntro(0);
    var t = 0.0;
    for (final at in [0.25, 0.6, 0.95, 1.3, 1.7, 3.6]) {
      t = run(f, t, at);
      frames.add(('intro t=$at', shoot(f, t)));
    }

    // A drag left to right through the middle.
    t = run(f, t, t + 0.5);
    final dragFrom = t;
    t = run(f, t, t + 0.45, (now) {
      final k = (now - dragFrom) / 0.45;
      f.pointer = Offset(60 + 170 * k, 32);
      f.pointerVel = const Offset(380, 0);
    });
    frames.add(('drag', shoot(f, t)));
    f.pointer = null;
    t = run(f, t, t + 0.3);
    frames.add(('drag released +0.3', shoot(f, t)));

    // A tap.
    t = run(f, t, t + 1.5);
    f.tap(150, 30, t);
    t = run(f, t, t + 0.12);
    frames.add(('tap +0.12', shoot(f, t)));
    t = run(f, t, t + 0.25);
    frames.add(('tap +0.37', shoot(f, t)));

    // Recolor to violet from the left.
    t = run(f, t, t + 1.5);
    f.setHue(titleHue('violet'), 20, 30, t);
    t = run(f, t, t + 0.45);
    frames.add(('recolor violet', shoot(f, t)));
    t = run(f, t, t + 2);
    frames.add(('violet, rest', shoot(f, t)));

    // Void.
    f.setHueNow(titleHue('void'));
    t = run(f, t, t + 0.5);
    frames.add(('void, rest', shoot(f, t)));
    final holdFrom = t;
    t = run(f, t, t + 0.8, (now) {
      final k = (now - holdFrom) / 0.8;
      f.pointer = Offset(120 + 40 * k, 30);
      f.pointerVel = const Offset(50, 0);
    });
    frames.add(('void drag (black hole)', shoot(f, t)));
    f.pointer = null;
    t = run(f, t, t + 1.5);
    f.tap(190, 30, t);
    t = run(f, t, t + 0.15);
    frames.add(('void tap +0.15', shoot(f, t)));
    t = run(f, t, t + 0.2);
    frames.add(('void tap +0.35', shoot(f, t)));

    // The light theme, and the ember color.
    final light = TitleParticleField(ink)..settleNow();
    frames.add(('light theme', shoot(light, 10, dark: false)));
    final ember = TitleParticleField(gold, hue: titleHue('ember'))..settleNow();
    frames.add(('ember', shoot(ember, 10)));

    // Cost: a frame's step + paint, recorded, in each state.
    double cost(TitleParticleField f, double t0, void Function(double) set) {
      var tt = t0;
      for (var i = 0; i < 60; i++) {
        set(tt);
        f.step(dt, tt);
        final rec = ui.PictureRecorder();
        f.paint(Canvas(rec), Offset.zero, tt);
        rec.endRecording().dispose();
        tt += dt;
      }
      final sw = Stopwatch()..start();
      for (var i = 0; i < 300; i++) {
        set(tt);
        f.step(dt, tt);
        final rec = ui.PictureRecorder();
        f.paint(Canvas(rec), Offset.zero, tt);
        rec.endRecording().dispose();
        tt += dt;
      }
      return sw.elapsedMicroseconds / 300;
    }

    final idle = TitleParticleField(gold)..settleNow();
    final restUs = cost(idle, 0, (_) {});
    final moving = TitleParticleField(gold)..settleNow();
    final dragUs = cost(moving, 0, (tt) {
      moving.pointer = Offset(60 + (tt * 200) % 180, 30);
      moving.pointerVel = const Offset(200, 0);
    });
    final intro = TitleParticleField(gold)..hideForIntro();
    intro.startIntro(0);
    final introUs = cost(intro, 0, (_) {});
    // ignore: avoid_print
    print('cost per frame: rest ${restUs.round()}us, '
        'drag ${dragUs.round()}us, intro ${introUs.round()}us');

    await tester.runAsync(() async {
      final w = TitleSamples.box.width * scale;
      final h = (TitleSamples.box.height + pad * 2) * scale;
      const cols = 2;
      final rows = (frames.length / cols).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      for (var i = 0; i < frames.length; i++) {
        final (label, img) = frames[i];
        final at = Offset((i % cols) * (w + 8), (i ~/ cols) * (h + 8));
        c.drawImage(img, at, Paint());
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF8A8AA0), fontSize: 22),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, at + const Offset(10, 6));
      }
      final img = rec.endRecording().toImageSync(
        (cols * (w + 8)).round(),
        (rows * (h + 8)).round(),
      );
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
