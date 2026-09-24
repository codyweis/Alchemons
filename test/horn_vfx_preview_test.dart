import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _elements = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

List<Projectile> _hornZones(String element) => createCosmicSpecialAbility(
  origin: Offset.zero,
  baseAngle: 0,
  family: 'horn',
  element: element,
  damage: 40,
  maxHp: 400,
  targetPos: const Offset(120, 0),
).projectiles;

/// Survival builds Ice's wall live during the dash; this is one segment.
Projectile _iceWallSegment() => Projectile(
  position: Offset.zero,
  angle: 0,
  element: 'Ice',
  damage: 0,
  life: 4.5,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: 1.4,
  visualScale: 1.6,
  visualStyle: ProjectileVisualStyle.hornImpact,
  abilityFamily: 'horn',
  decoy: true,
  effectRadius: 44,
  reflectsProjectiles: true,
);

void _paint(Canvas canvas, Projectile p, Offset at, double time) {
  final saved = p.position;
  p.position = at + saved;
  drawHornElementalProjectileVisual(
    canvas: canvas,
    projectile: p,
    position: p.position,
    color: elementColor(p.element!),
    time: time,
  );
  p.position = saved;
}

void main() {
  test('horn effects step, cap and expire', () {
    final fx = <HornFx>[];
    for (var i = 0; i < 14; i++) {
      pushHornFx(
        fx,
        HornFx.slam(
          position: Offset.zero,
          angle: 0,
          radius: 120,
          element: i.isEven ? 'Earth' : 'Fire',
        ),
      );
    }
    expect(fx.length, 10);
    updateHornFx(fx, 0.55);
    // Fire's shock is spent by now; Earth's lingers.
    expect(fx.every((f) => f.element == 'Earth'), isTrue);
    updateHornFx(fx, 0.2);
    expect(fx, isEmpty);
  });

  test('every horn projectile is claimed by the horn painter', () {
    final canvas = Canvas(ui.PictureRecorder());
    for (final element in _elements) {
      for (final p in _hornZones(element)) {
        expect(
          drawHornElementalProjectileVisual(
            canvas: canvas,
            projectile: p,
            position: Offset.zero,
            color: elementColor(element),
            time: 1,
          ),
          isTrue,
          reason: element,
        );
      }
    }
  });

  // HORN_VFX_OUT=/path/sheet.png flutter test test/horn_vfx_preview_test.dart
  test('preview sheet', () async {
    const cellW = 250.0, cellH = 190.0, cols = 5;
    final rows = _elements.length + 1;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cellW * cols, cellH * rows),
      Paint()..color = const Color(0xFF16130F),
    );
    for (var r = 0; r < _elements.length; r++) {
      final element = _elements[r];
      final color = elementColor(element);
      final y = r * cellH + cellH / 2;
      // 1: the wake, heading right.
      canvas.save();
      canvas.translate(cellW * 0.66, y);
      drawAdvancedChargeTrail(
        canvas: canvas,
        color: color,
        angle: 0,
        sweepRadius: 70,
        overshootDistance: 60,
        element: element,
        time: 0.37,
      );
      canvas.drawCircle(Offset.zero, 13, Paint()..color = color);
      canvas.restore();
      // 2, 3: the slam, just landed and fading.
      for (final (col, age) in [(1, 0.15), (2, 0.55)]) {
        final fx = HornFx.slam(
          position: Offset(cellW * col + cellW * 0.4, y),
          angle: 0,
          radius: 110,
          element: element,
        );
        fx.age = fx.duration * age;
        drawHornFx(canvas, [fx]);
      }
      // 4: what it leaves on the ground.
      final at = Offset(cellW * 3 + cellW / 2, y);
      final zones = element == 'Ice'
          ? [_iceWallSegment()]
          : _hornZones(element);
      if (element == 'Ice') {
        // A short run of wall segments.
        for (var i = -2; i <= 2; i++) {
          _paint(canvas, _iceWallSegment(), at + Offset(0, i * 26.0), 1.3);
        }
      } else {
        for (final p in zones) {
          // Fire's lane runs back along the charge; fold it into the cell.
          final shift = element == 'Fire' ? const Offset(64, 0) : Offset.zero;
          _paint(canvas, p, at + shift, 1.3);
        }
      }
      // 5: the small patches a moving horn paints (Fire, Mud, Poison).
      if (element == 'Fire' || element == 'Mud' || element == 'Poison') {
        for (var i = 0; i < 5; i++) {
          drawHornTrailPatch(
            canvas: canvas,
            element: element,
            position: Offset(cellW * 4 + 40 + i * 38.0, y + sin(i) * 8),
            radius: element == 'Mud' ? 26 : 34,
            time: 1.3 + i,
            fade: 1 - i * 0.15,
          );
        }
      }
      if (element == 'Plant') {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.drawCircle(
          Offset.zero,
          12,
          Paint()..color = const Color(0xFF7A5A8A),
        );
        drawHornPlantRootWrap(canvas: canvas, r: 12, time: 1.3);
        canvas.restore();
      }
      if (element == 'Poison') {
        canvas.save();
        canvas.translate(at.dx, at.dy);
        drawHornPoisonAura(canvas: canvas, radius: 80, time: 1.3);
        canvas.drawCircle(Offset.zero, 13, Paint()..color = color);
        canvas.restore();
      }
      if (element == 'Blood') {
        final sac = HornFx.sacrifice(position: at + const Offset(-50, 0))
          ..age = 0.2;
        final siphon = HornFx.siphon(
          from: at + const Offset(70, 60),
          to: at + const Offset(-50, 0),
        )..age = 0.22;
        drawHornFx(canvas, [sac, siphon]);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (cellW * cols).toInt(),
      (cellH * rows).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['HORN_VFX_OUT'];
    if (out != null) {
      await File(out).writeAsBytes(bytes!.buffer.asUint8List());
    }
  });
}
