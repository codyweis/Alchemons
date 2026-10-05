import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_sand.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// The hatch ceremony's sand: still at rest, stirred locally, rolled by the
// burst and settled back -- and Alchemized's, which never settles.
void main() {
  const size = Size(475, 751);
  const fire = [Color(0xFFFF7E57), Color(0xFFFF8C00), Color(0xFFFFD700)];
  const water = [Color(0xFF1574A1), Color(0xFF38BDF8), Color(0xFF7DD3FC)];

  HatchSandField sandOf({
    HatchSandColour colour = HatchSandColour.elements,
    bool loose = false,
  }) => HatchSandField(
    paletteA: fire,
    paletteB: water,
    colour: colour,
    loose: loose,
  )..layout(size);

  void paint(HatchSandField f) {
    final rec = ui.PictureRecorder();
    f.paint(Canvas(rec));
    rec.endRecording().dispose();
  }

  void run(HatchSandField f, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      f.step(1 / 60);
      paint(f);
    }
  }

  test('rests as one picture, a stir wakes only what it crosses', () {
    final f = sandOf();
    expect(f.grainCount, greaterThan(4000));
    run(f, 1.5); // settled in
    expect(f.debugPictures, 1);
    final restSprites = f.debugSprites;

    // A short stroke low on the left.
    for (var i = 0; i < 10; i++) {
      f.stir(Offset(60 + i * 6.0, 650), const Offset(6, 0), 1 / 60);
      f.step(1 / 60);
      paint(f);
    }
    expect(f.debugPictures, greaterThan(1), reason: 'the rest stays cached');
    expect(f.debugSprites, greaterThan(restSprites));
    expect(
      f.debugSprites,
      lessThan(f.grainCount ~/ 3),
      reason: 'only the squares the finger crossed are drawn grain by grain',
    );

    // The flow takes a few seconds to fall below waking anything (as the
    // home realm's does).
    run(f, 5);
    expect(f.debugPictures, 1, reason: 'settled back to one picture');
  });

  test('the burst rolls through all of it, and it settles back', () {
    final f = sandOf();
    run(f, 1.5);
    f.burst();
    run(f, 0.5);
    expect(f.debugSprites, greaterThan(f.grainCount ~/ 2));
    run(f, 5);
    expect(f.debugPictures, 1);
  });

  test("each parent's sand lies on its own strands' side", () {
    final f = sandOf();
    var rightWarm = 0, rightAll = 0, leftWarm = 0, leftAll = 0;
    for (var i = 0; i < f.grainCount; i++) {
      final at = f.debugGrainAt(i);
      final c = f.debugColourOf(i);
      final warm = ((c >> 16) & 0xFF) > (c & 0xFF);
      if (at.dx > size.width * 0.85) {
        rightAll++;
        if (warm) rightWarm++;
      } else if (at.dx < size.width * 0.15) {
        leftAll++;
        if (warm) leftWarm++;
      }
    }
    // A (fire) is born on the shell's right, B (water) on its left.
    expect(rightWarm / rightAll, greaterThan(0.75));
    expect(leftWarm / leftAll, lessThan(0.25));
  });

  test('Alchemized sand never settles, and a stir stays in it', () {
    final stirred = sandOf(loose: true);
    final calm = sandOf(loose: true);
    run(stirred, 1.5);
    run(calm, 1.5);
    expect(stirred.debugPictures, 0);
    expect(stirred.debugSprites, greaterThan(stirred.grainCount * 0.8));

    for (var i = 0; i < 20; i++) {
      stirred.stir(Offset(80, 120 + i * 12.0), const Offset(0, 12), 1 / 60);
      stirred.step(1 / 60);
      calm.step(1 / 60);
    }
    run(stirred, 3);
    run(calm, 3);
    var moved = 0;
    for (var i = 0; i < stirred.grainCount; i++) {
      final d = (stirred.debugGrainAt(i) - calm.debugGrainAt(i)).distance;
      if (d > 6) moved++;
    }
    expect(moved, greaterThan(40), reason: 'the stir is still in it');
  });

  test('cost per frame', () {
    final rows = <String>[];
    double time(HatchSandField f, void Function(int frame) each) {
      final sw = Stopwatch()..start();
      for (var i = 0; i < 60; i++) {
        each(i);
        f.step(1 / 60);
        paint(f);
      }
      return sw.elapsedMicroseconds / 60;
    }

    for (final (name, colour, loose) in [
      ('elements', HatchSandColour.elements, false),
      ('prismatic', HatchSandColour.prismatic, false),
      ('gilded', HatchSandColour.gilded, false),
      ('alchemized', HatchSandColour.elements, true),
    ]) {
      final build = Stopwatch()..start();
      final f = sandOf(colour: colour, loose: loose);
      final built = build.elapsedMicroseconds;
      run(f, 1.5);
      final rest = time(f, (_) {});
      final stir = time(
        f,
        (i) => f.stir(
          Offset(100 + i * 4.0, 300 + i * 2.0),
          const Offset(4, 2),
          1 / 60,
        ),
      );
      run(f, 3);
      f.burst();
      final burst = time(f, (_) {});
      rows.add(
        '$name (${f.grainCount} grains): build ${(built / 1000).toStringAsFixed(1)} ms, '
        'rest ${rest.round()} µs, stirred ${stir.round()} µs, '
        'burst ${burst.round()} µs',
      );
    }
    // ignore: avoid_print
    print(rows.join('\n'));
  });
}
