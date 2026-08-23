// drawDriftingClouds is the atmospheric mist behind every dungeon and raid.
// It drew each band as two large MaskFilter.blur ovals — 150x66 at blur 12,
// eight of them a frame — in the one file whose header promises "no per-frame
// MaskFilter blur". Blur cost scales with the blurred area, so these were far
// more expensive than the small ones removed from the constellation.
//
// It now blits the soft blob this file already bakes once into a ui.Image.

import 'dart:ui' as ui;

import 'package:alchemons/games/planet_dungeon/planet_dungeon_fx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Census implements Canvas {
  int blurs = 0;
  int images = 0;
  int ovals = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final name = i.memberName.toString();
    if (name.contains('drawImageRect')) images++;
    if (name.contains('drawOval')) ovals++;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurs++;
    }
    if (name.contains('getSaveCount')) return 1;
    return null;
  }
}

ui.Image _bakedPuff() {
  final rec = ui.PictureRecorder();
  Canvas(rec).drawCircle(const Offset(64, 42), 40, Paint());
  return rec.endRecording().toImageSync(128, 84);
}

_Census _run({ui.Image? puff}) {
  final c = _Census();
  drawDriftingClouds(c as Canvas, const Size(900, 1600), 3.0, puff: puff);
  return c;
}

void main() {
  test('with the baked sprite it blits and never blurs', () {
    final c = _run(puff: _bakedPuff());
    expect(c.blurs, 0, reason: 'this is the whole point of baking the sprite');
    expect(c.images, greaterThan(0), reason: 'bands should be blitted');
    expect(c.ovals, 0);
  });

  test('without one it still draws, so a dungeon is never blank', () {
    // The fallback matters: assets load asynchronously, so the first frames
    // of a dungeon can run before the bake finishes.
    final c = _run();
    expect(c.ovals, greaterThan(0));
    expect(c.images, 0);
  });

  test('the fallback is what used to run every frame', () {
    // Documents the cost that was there: two blurred ovals per visible band.
    final c = _run();
    expect(c.blurs, c.ovals);
    expect(c.blurs, greaterThan(4));
  });

  test('both paths draw the same number of bands', () {
    final blitted = _run(puff: _bakedPuff());
    final fallback = _run();
    expect(blitted.images, fallback.ovals);
  });
}
