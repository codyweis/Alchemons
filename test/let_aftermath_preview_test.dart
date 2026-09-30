@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a Let leaves behind, at the size the game actually leaves it: the
/// crater opening, then whatever lingers on the ground afterwards. Zone
/// radii mirror the survival spawns (the source of truth), and a few
/// enemy-sized bodies sit in every cell for scale.
///
///   LET_AFTER_OUT=/tmp flutter test test/let_aftermath_preview_test.dart \
///     --tags preview
void main() {
  final outDir = Platform.environment['LET_AFTER_OUT'];

  String? labelFont;
  setUpAll(() async {
    const candidates = [
      '/System/Library/Fonts/Supplemental/Arial.ttf',
      '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      await (FontLoader('SheetLabel')..addFont(
            Future.value(ByteData.view(file.readAsBytesSync().buffer)),
          ))
          .load();
      labelFont = 'SheetLabel';
      return;
    }
  });

  testWidgets('let aftermath preview', (tester) async {
    const elements = kCosmicAbilityElements;
    // World units per cell; drawn at [scale].
    const world = 380.0;
    const scale = 0.55;
    const cell = world * scale;
    const labelW = 150.0;
    const impactAges = [0.05, 0.22, 0.5];
    const zoneTimes = [0.6, 3.0];
    const cols = 6;

    const w = labelW + cell * cols;
    final h = 40.0 + cell * elements.length;
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec, Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0B0A12),
    );

    void label(String s, Offset at, Color c, {double size = 11}) {
      TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              color: c,
              fontSize: size,
              fontWeight: FontWeight.w700,
              fontFamily: labelFont,
            ),
          ),
          textDirection: TextDirection.ltr,
        )
        ..layout(maxWidth: labelW - 14)
        ..paint(canvas, at);
    }

    const headers = [
      'crater +45ms',
      'crater +200ms',
      'crater +450ms',
      'aftermath beat',
      'lingers  t=0.6s',
      'lingers  t=3s',
    ];
    for (var c = 0; c < cols; c++) {
      label(
        headers[c],
        Offset(labelW + c * cell + 8, 14),
        c < 4 ? const Color(0xFFD4B78F) : const Color(0xFF9FB6D4),
        size: 11,
      );
    }

    // A handful of bodies for scale, the size of drones and sentinels.
    void bodies(Offset centre) {
      final rng = Random(7);
      for (var i = 0; i < 5; i++) {
        final a = rng.nextDouble() * pi * 2;
        final r = 40 + rng.nextDouble() * 110;
        canvas.drawCircle(
          centre + Offset(cos(a), sin(a)) * r,
          i.isEven ? 10 : 14,
          Paint()..color = const Color(0x55BFC4D0),
        );
      }
    }

    for (var r = 0; r < elements.length; r++) {
      final element = elements[r];
      final color = elementColor(element);
      final top = 40.0 + r * cell;
      if (r.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(0, top, w, cell),
          Paint()..color = const Color(0x08FFFFFF),
        );
      }
      label(element, Offset(10, top + 12), color, size: 14);
      label(
        cosmicSpecialAbilityName('let', element),
        Offset(10, top + 32),
        const Color(0xFF8C96A8),
        size: 10,
      );
      label(
        _aftermathNote[element] ?? '',
        Offset(10, top + 52),
        const Color(0xFF6C7688),
        size: 9,
      );

      final meteor = createCosmicSpecialAbility(
        origin: const Offset(-200, 0),
        baseAngle: 0,
        family: 'let',
        element: element,
        damage: 40,
        maxHp: 400,
        targetPos: Offset.zero,
      ).projectiles.first;
      final blast = letSkyfallBlastRadius(meteor);
      const centre = Offset(world / 2, world / 2);

      for (var c = 0; c < cols; c++) {
        canvas.save();
        canvas.translate(labelW + c * cell, top);
        canvas.clipRect(const Rect.fromLTWH(0, 0, cell, cell));
        canvas.scale(scale);
        bodies(centre);
        if (c < 3) {
          drawLetSkyfallImpact(
            canvas: canvas,
            centre: centre,
            color: color,
            element: element,
            radius: blast,
            age: impactAges[c],
          );
        } else if (c == 3) {
          final beat = _beatFor(element, centre, meteor);
          if (beat.isEmpty) {
            label(
              'no beat',
              centre + const Offset(-30, -8),
              const Color(0xFF4C5466),
              size: 18,
            );
          }
          for (final f in beat) {
            f.age = f.duration * (f.kind == LetFxKind.frost ||
                    f.kind == LetFxKind.crystal
                ? 0.5
                : 0.3);
          }
          drawLetFx(canvas, beat);
        } else {
          final zones = _zonesFor(element, centre, meteor);
          if (zones.isEmpty) {
            label(
              'nothing lingers',
              centre + const Offset(-60, -8),
              const Color(0xFF4C5466),
              size: 18,
            );
          }
          for (final zone in zones) {
            zone.life = zone.effectDuration - zoneTimes[c - 4];
            drawLetElementalProjectileVisual(
              canvas: canvas,
              projectile: zone,
              position: zone.position,
              color: color,
              time: zoneTimes[c - 4],
            );
          }
        }
        canvas.restore();
      }
    }

    final pic = rec.endRecording();
    ByteData? bytes;
    await tester.runAsync(() async {
      final img = await pic.toImage(w.round(), h.round());
      bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    });
    File(
      '$outDir/let_aftermath_preview.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  }, skip: outDir == null);
}

/// One line on what each Let does after landing, per the design board.
const _aftermathNote = {
  'Plant': 'kill: vines that hurt',
  'Air': 'hit: blows bodies back',
  'Dust': 'hit: slowing dust cloud',
  'Lava': 'hit: burning ground',
  'Poison': 'hit: poisons',
  'Blood': 'kill: leeches nearby, heals team',
  'Earth': 'hit: heals lowest ally',
  'Light': 'kill: healing light pool',
  'Spirit': 'hit: chance to execute',
  'Crystal': 'hit: 90% slow',
  'Fire': 'kill: big explosion',
  'Lightning': 'hit: chains to nearby',
  'Steam': 'kill: long geyser, pushes',
  'Dark': 'kill: up to 5 more meteors',
  'Ice': 'hit: freezes',
  'Mud': 'kill: stunning pool',
  'Water': 'hit: big splash',
};

/// What survival spawns after the landing, from the shared tables.
List<Projectile> _zonesFor(String element, Offset c, Projectile meteor) {
  final spec =
      CosmicAbilityRuntime.letContactZone(element) ??
      CosmicAbilityRuntime.letKillZone(element);
  if (spec != null) {
    return [CosmicAbilityRuntime.letZone(meteor, c, element, spec)];
  }
  if (element == 'Plant') {
    return [
      for (final spot in CosmicAbilityRuntime.letVineSpots(c, 0.4))
        CosmicAbilityRuntime.letVine(meteor, spot),
    ];
  }
  return const [];
}

/// The short beat each element's aftermath plays, where it has one. Fire's
/// blast is drawn at a third of its real reach so it fits the cell.
List<LetFx> _beatFor(String element, Offset c, Projectile meteor) {
  final rng = Random(7);
  final bodies = [
    for (var i = 0; i < 5; i++)
      () {
        final a = rng.nextDouble() * pi * 2;
        final r = 40 + rng.nextDouble() * 110;
        return c + Offset(cos(a), sin(a)) * r;
      }(),
  ];
  return switch (element) {
    'Fire' => [
      LetFx.blast(
        position: c,
        radius: CosmicAbilityRuntime.letFireReach(meteor) / 3,
      ),
    ],
    'Water' => [
      LetFx.splash(
        position: c,
        radius: CosmicAbilityRuntime.letWaterReach(meteor),
      ),
    ],
    'Air' => [
      LetFx.gust(position: c, radius: CosmicAbilityRuntime.letAirReach(meteor)),
    ],
    'Blood' => [for (final b in bodies) LetFx.drain(from: b, to: c)],
    'Ice' => [
      LetFx.frost(
        position: bodies[1],
        bodyRadius: 14,
        duration: CosmicAbilityRuntime.kLetIceHold,
      ),
    ],
    'Crystal' => [
      LetFx.crystal(
        position: bodies[1],
        bodyRadius: 14,
        duration: CosmicAbilityRuntime.kLetCrystalHold,
      ),
    ],
    'Spirit' => [LetFx.soul(position: bodies[1], bodyRadius: 14)],
    'Lightning' => [
      LetFx.chain(points: [c, bodies[0], bodies[2], bodies[4]]),
    ],
    'Plant' => [
      LetFx.lash(
        from: CosmicAbilityRuntime.letVineSpots(c, 0.4).first,
        to: bodies[0],
      ),
    ],
    _ => const [],
  };
}
