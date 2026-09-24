@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// PIP_VFX_OUT=/path/sheet.png flutter test test/pip_vfx_preview_test.dart
// Special darts at game size and 2.5x, then what the element leaves behind.

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
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

Projectile? _dart(String element) => createCosmicSpecialAbility(
  origin: Offset.zero,
  baseAngle: 0,
  family: 'pip',
  element: element,
  damage: 40,
  maxHp: 400,
  targetPos: const Offset(200, 0),
).projectiles.firstOrNull;

Projectile _ground(
  String element, {
  double radiusMultiplier = 1.4,
  double visualScale = 1.3,
  AbilityEffectKind tick = AbilityEffectKind.none,
  double effectRadius = 60,
  bool decoy = false,
  double tauntRadius = 0,
}) => Projectile(
  position: Offset.zero,
  angle: 0,
  element: element,
  damage: 0,
  life: 4,
  speedMultiplier: 0,
  stationary: true,
  piercing: true,
  radiusMultiplier: radiusMultiplier,
  visualScale: visualScale,
  visualStyle: ProjectileVisualStyle.sigil,
  abilityFamily: 'pip',
  tickEffect: tick,
  effectPower: 4,
  effectRadius: effectRadius,
  effectDuration: 2,
  decoy: decoy,
  decoyHp: decoy ? 30 : 0,
  tauntRadius: tauntRadius,
  tauntStrength: tauntRadius > 0 ? 3.6 : 0,
);

/// What survival leaves on the ground for each element (empty = nothing).
List<(Offset, Projectile)> _leftovers(String element) => switch (element) {
  'Fire' => [
    (
      Offset.zero,
      _ground(
        'Fire',
        radiusMultiplier: 1.6,
        visualScale: 1.4,
        tick: AbilityEffectKind.burn,
      ),
    ),
  ],
  'Dust' => [
    (
      Offset.zero,
      _ground('Dust', tick: AbilityEffectKind.slow, effectRadius: 70),
    ),
  ],
  'Crystal' => [
    (
      Offset.zero,
      _ground(
        'Crystal',
        radiusMultiplier: 0.7,
        visualScale: 0.75,
        effectRadius: 38,
        decoy: true,
        tauntRadius: 130,
      ),
    ),
  ],
  'Dark' => [
    (
      Offset.zero,
      _ground(
        'Dark',
        radiusMultiplier: 1.5,
        visualScale: 1.4,
        tick: AbilityEffectKind.blackHole,
        effectRadius: 120,
      ),
    ),
  ],
  'Poison' => [
    for (var s = 0; s < 5; s++)
      (
        Offset(-72 + s * 36.0, s * 6.0),
        _ground(
          'Poison',
          radiusMultiplier: 0.95,
          visualScale: 0.85,
          tick: AbilityEffectKind.poison,
          effectRadius: 32,
        ),
      ),
  ],
  'Mud' => [
    for (var s = 0; s < 4; s++)
      (
        Offset(-60 + s * 40.0, (s.isEven ? 1 : -1) * 6.0),
        _ground(
          'Mud',
          radiusMultiplier: 1.1,
          visualScale: 1.0,
          tick: AbilityEffectKind.slow,
          effectRadius: 38,
        ),
      ),
  ],
  _ => const [],
};

void main() {
  test('pip preview sheet', () async {
    const cellW = 300.0, cellH = 150.0, cols = 3;
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
      for (final (col, zoom) in [(0, 1.0), (1, 2.5)]) {
        final p = _dart(element);
        if (p == null) continue; // Dark's special is passive.
        canvas.save();
        canvas.translate(cellW * col + cellW * 0.55, y);
        canvas.scale(zoom);
        p.position = Offset.zero;
        drawPipElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: Offset.zero,
          color: color,
          time: 0.8,
        );
        canvas.restore();
      }
      for (final (offset, p) in _leftovers(element)) {
        final at = Offset(cellW * 2 + cellW / 2, y) + offset;
        p.position = at;
        drawMaskElementalProjectileVisual(
          canvas: canvas,
          projectile: p,
          position: at,
          color: color,
          time: 1.3,
        );
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (cellW * cols).toInt(),
      (cellH * rows).toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);
    final out = Platform.environment['PIP_VFX_OUT'];
    if (out != null) {
      await File(out).writeAsBytes(bytes!.buffer.asUint8List());
    }
  });
}
