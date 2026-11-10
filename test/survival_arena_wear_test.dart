import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic_survival/arena_wear.dart';
import 'package:flutter_test/flutter_test.dart';

void _tick(
  ArenaWear wear,
  double seconds, {
  int wave = 1,
  double fill = 0,
  double bearing = 0,
  bool boss = false,
}) {
  for (var f = 0; f < seconds * 60; f++) {
    wear.update(
      1 / 60,
      centre: ui.Offset.zero,
      wave: wave,
      fill: fill,
      bearing: bearing,
      bossAlive: boss,
    );
  }
}

void _paint(ArenaWear wear, ui.Rect view) {
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  wear.paintGloom(canvas, ui.Offset.zero, 1140, const ui.Color(0xFF42C8D8));
  wear.paintFloor(canvas, view);
  wear.paintDrift(canvas, view);
  rec.endRecording().dispose();
}

void main() {
  const view = ui.Rect.fromLTWH(-346, -769, 692, 1538);

  test('the arena wears with the wave and keeps wearing past fifty', () {
    var last = -1.0;
    for (final wave in [1, 5, 10, 25, 50, 75, 100]) {
      final d = ArenaWear.depthForWave(wave);
      expect(d, greaterThan(last));
      expect(d, lessThan(1));
      last = d;
    }
    expect(ArenaWear.depthForWave(1), 0);
    expect(
      ArenaWear.depthForWave(100) - ArenaWear.depthForWave(50),
      greaterThan(0.15),
    );
  });

  test('the rim darkens and the floor loses light as waves climb', () {
    final early = ArenaWear(), late = ArenaWear();
    _tick(early, 30, wave: 3, fill: 0.5);
    _tick(late, 30, wave: 62, fill: 0.5);
    expect(late.gloom, greaterThan(early.gloom + 0.3));
    expect(late.floorLight, lessThan(early.floorLight - 0.2));
  });

  test('a horde dying is rationed; heavies and blasts always mark', () {
    final wear = ArenaWear();
    _tick(wear, 1);
    for (var i = 0; i < 500; i++) {
      wear.fall(ui.Offset(i * 2.0, 0), 12);
    }
    expect(wear.marks, lessThan(20));
    final before = wear.marks;
    for (var i = 0; i < 10; i++) {
      wear.fall(ui.Offset(0, i * 30.0), 40, heavy: true);
      wear.scorch(ui.Offset(200, i * 30.0), 80);
    }
    expect(wear.marks, before + 20);
  });

  test('a grown creature leaves more than a weak one', () {
    final weak = ArenaWear(), strong = ArenaWear();
    _tick(weak, 1);
    _tick(strong, 1);
    const light = ui.Color(0xFFFFAA66);
    for (var i = 0; i < 60; i++) {
      weak.strike(ui.Offset(i * 9.0, 0), 0.0, light: light);
      strong.strike(ui.Offset(i * 9.0, 0), 1.0, light: light);
    }
    expect(strong.marks, 60);
    expect(weak.marks, lessThan(20));
  });

  test('a cleared wave settles, a hard one further, and it passes', () {
    final wear = ArenaWear();
    _tick(wear, 20, wave: 40, fill: 0.9);
    final dark = wear.gloom, lit = wear.floorLight;
    wear.waveCleared(wear.peakPressure);
    expect(wear.settle, greaterThan(0.9));
    _tick(wear, 0.1, wave: 41);
    expect(wear.gloom, lessThan(dark));
    expect(wear.floorLight, greaterThan(lit));
    final easy = ArenaWear()..waveCleared(0.1);
    expect(easy.settle, lessThan(wear.settle));
    _tick(wear, 8, wave: 41, fill: 0.9);
    expect(wear.settle, 0);
  });

  test('the drift thickens under a full front and a boss stills it', () {
    final quiet = ArenaWear(), full = ArenaWear(), boss = ArenaWear();
    _tick(quiet, 20, wave: 40, fill: 0.05);
    _tick(full, 20, wave: 40, fill: 1.0);
    _tick(boss, 20, wave: 40, fill: 1.0, boss: true);
    _paint(quiet, view);
    _paint(full, view);
    _paint(boss, view);
    expect(full.lastMotes, greaterThan(quiet.lastMotes * 3));
    expect(boss.lastMotes, lessThan(full.lastMotes ~/ 3));
  });

  test('a worn floor is a handful of draws, never one per mark', () {
    final wear = ArenaWear()..seed(100, ui.Offset.zero, 1140);
    _tick(wear, 20, wave: 100, fill: 1.0, bearing: pi / 3);
    // Bake what is in view (one tile a frame), then count a settled frame.
    for (var f = 0; f < 40; f++) {
      _tick(wear, 0.6, wave: 100, fill: 1.0);
      _paint(wear, view);
    }
    expect(wear.lastTilesBaked, 0);
    expect(wear.lastTilesDrawn, inInclusiveRange(4, 12));
    wear.dispose();
  });
}
