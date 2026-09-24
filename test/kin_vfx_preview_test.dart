@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// KIN_VFX_OUT=/path/sheet.png flutter test test/kin_vfx_preview_test.dart
// Each Kin's real special, drawn through the same painter chain the dungeon
// uses, then the creature-side art: support aura, basic laser, charge,
// blessing, shield.

const _elements = [
  'Light',
  'Water',
  'Plant',
  'Earth',
  'Air',
  'Fire',
  'Lava',
  'Ice',
  'Steam',
  'Crystal',
  'Lightning',
  'Dust',
  'Mud',
  'Poison',
  'Spirit',
  'Dark',
  'Blood',
];

List<Projectile> _special(String element) => createCosmicSpecialAbility(
  origin: Offset.zero,
  baseAngle: 0,
  family: 'kin',
  element: element,
  damage: 40,
  maxHp: 400,
  targetPos: const Offset(160, 0),
).projectiles;

void _paint(Canvas canvas, Projectile p, Offset at, double time) {
  final saved = p.position;
  p.position = at + saved;
  final color = elementColor(p.element ?? 'Light');
  final pos = p.position;
  final drawn =
      drawKinSpiritWispVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawMysticOrbitalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawMaskElementalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawLetElementalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawPipElementalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawManeElementalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      ) ||
      drawHornElementalProjectileVisual(
        canvas: canvas,
        projectile: p,
        position: pos,
        color: color,
        time: time,
      );
  if (!drawn) {
    drawGenericProjectileVisual(
      canvas: canvas,
      projectile: p,
      position: pos,
      color: color,
      time: time,
    );
  }
  p.position = saved;
}

Projectile _sigil(
  String element, {
  double radiusMultiplier = 1.4,
  double visualScale = 1.4,
  double effectRadius = 48,
  AbilityEffectKind tick = AbilityEffectKind.none,
  bool reflects = false,
  int tier = 0,
}) => Projectile(
  position: Offset.zero,
  angle: 0,
  element: element,
  damage: 0,
  life: 8,
  speedMultiplier: 0,
  stationary: tier == 0,
  piercing: true,
  radiusMultiplier: radiusMultiplier,
  visualScale: visualScale,
  visualStyle: ProjectileVisualStyle.sigil,
  abilityFamily: 'kin',
  tickEffect: tick,
  effectPower: 1,
  effectRadius: effectRadius,
  effectDuration: 1.4,
  reflectsProjectiles: reflects,
  followSourceCompanion: tier > 0,
  holdOrbit: tier > 0,
  orbitRadius: tier > 0 ? 56 : 0,
  effectCount: tier,
);

/// Pieces survival spawns itself rather than through the ability table.
List<(Offset, Projectile)> _gameSpawned(String element) => switch (element) {
  'Earth' => [
    for (var i = 0; i < 7; i++)
      (
        Offset(cos(-1.05 + i * 0.35) * 70, sin(-1.05 + i * 0.35) * 70),
        _sigil(
          'Earth',
          radiusMultiplier: 1.6,
          visualScale: 1.7,
          effectRadius: 30,
          reflects: true,
        ),
      ),
  ],
  'Dust' => [
    (
      Offset.zero,
      _sigil(
        'Dust',
        radiusMultiplier: 3.0,
        visualScale: 2.4,
        effectRadius: 80,
        tick: AbilityEffectKind.slow,
      ),
    ),
  ],
  'Mud' => [
    for (var i = 0; i < 4; i++)
      (
        Offset(-60 + i * 40.0, 0),
        _sigil('Mud', effectRadius: 30, tick: AbilityEffectKind.slow),
      ),
  ],
  'Spirit' => [
    for (var t = 1; t <= 4; t++)
      (
        Offset(-90 + t * 36.0, 0),
        _sigil('Spirit', radiusMultiplier: 1.4, visualScale: 1.2, tier: t),
      ),
  ],
  _ => const [],
};

void main() {
  test('kin preview sheet', () async {
    const cellW = 260.0, cellH = 170.0, cols = 4;
    final rows = _elements.length;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, cellW * cols, cellH * rows),
      Paint()..color = const Color(0xFF16130F),
    );
    for (var r = 0; r < rows; r++) {
      final element = _elements[r];
      final color = elementColor(element);
      final y = r * cellH + cellH / 2;
      // 1: the special's projectiles/placements, as spawned.
      final at = Offset(cellW * 0.5, y);
      final ps = _special(element);
      for (final p in ps) {
        // Squash wide spreads into the cell.
        final shrink = p.position.distance > 110
            ? 110 / p.position.distance
            : 1.0;
        final saved = p.position;
        p.position = saved * shrink;
        _paint(canvas, p, at, 1.3);
        p.position = saved;
      }
      for (final (offset, p) in _gameSpawned(element)) {
        _paint(canvas, p, at + offset, 1.3);
      }
      // 2: the creature with its support aura.
      canvas.save();
      canvas.translate(cellW * 1.5, y);
      drawAdvancedKinSupportAura(
        canvas: canvas,
        element: element,
        color: color,
        time: 1.3,
        iceChargeProgress: element == 'Ice' ? 0.6 : 0,
        lightningActive: element == 'Lightning',
        fireOrbitalActive: element == 'Fire',
        lavaPlateActive: element == 'Lava',
        darkCloakActive: element == 'Dark',
        steamPressure: element == 'Steam' ? 0.7 : 0,
      );
      canvas.drawCircle(Offset.zero, 15, Paint()..color = color);
      canvas.restore();
      // 3: basic laser + charge.
      canvas.save();
      canvas.translate(cellW * 2 + 30, y);
      drawAdvancedKinCharge(
        canvas: canvas,
        color: color,
        progress: 0.7,
        time: 1.3,
        aimDirection: const Offset(1, 0),
      );
      canvas.drawCircle(Offset.zero, 10, Paint()..color = color);
      canvas.restore();
      drawKinLaser(
        canvas: canvas,
        start: Offset(cellW * 2 + 60, y),
        end: Offset(cellW * 3 - 20, y),
        color: color,
        width: 2.6,
      );
      // 4: blessing + shield (same for every kin; drawn on row 0 only).
      if (r == 0) {
        canvas.save();
        canvas.translate(cellW * 3.3, y);
        drawAdvancedBlessingAura(canvas: canvas, time: 1.0);
        canvas.drawCircle(Offset.zero, 10, Paint()..color = color);
        canvas.restore();
        canvas.save();
        canvas.translate(cellW * 3.7, y);
        drawAdvancedCompanionShield(canvas: canvas, time: 1.0);
        canvas.drawCircle(Offset.zero, 10, Paint()..color = color);
        canvas.restore();
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (cellW * cols).toInt(),
      (cellH * rows).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['KIN_VFX_OUT'];
    if (out != null) {
      await File(out).writeAsBytes(bytes!.buffer.asUint8List());
    }
  });
}
