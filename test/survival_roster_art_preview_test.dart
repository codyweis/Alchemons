@Tags(['preview'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/roster_art.dart';
import 'package:alchemons/games/cosmic_survival/survival_kind.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The survival kinds as the game draws them (roster_art.dart), enlarged:
// one column per kind; rows are three elements, a hurt body, an elite, a
// struck body, and a body entering the field a third and two thirds of the
// way through gathering.
//
//   ROSTER_ART_OUT=/tmp/roster_art.png [ROSTER_ART_T=1.3] flutter test \
//     test/survival_roster_art_preview_test.dart --tags preview

CosmicSurvivalEnemy _enemy(
  SurvivalKind kind,
  Offset at, {
  String element = 'Fire',
  double hp = 1,
  bool elite = false,
  double flash = 0,
  double arrive = 1,
}) {
  final (tier, conduct, trait) = switch (kind) {
    SurvivalKind.mote => (EnemyTier.wisp, EnemyConduct.charge, null),
    SurvivalKind.strand => (EnemyTier.drone, EnemyConduct.charge, null),
    SurvivalKind.braid => (
      EnemyTier.sentinel,
      EnemyConduct.charge,
      EnemyTrait.splitter,
    ),
    SurvivalKind.husk => (EnemyTier.brute, EnemyConduct.charge, null),
    SurvivalKind.hollow => (EnemyTier.phantom, EnemyConduct.stalk, null),
    SurvivalKind.spill => (EnemyTier.sentinel, EnemyConduct.orbit, null),
    SurvivalKind.lobber => (EnemyTier.sentinel, EnemyConduct.siege, null),
    SurvivalKind.clutch => (
      EnemyTier.brute,
      EnemyConduct.charge,
      EnemyTrait.summoner,
    ),
    SurvivalKind.siphon => (
      EnemyTier.sentinel,
      EnemyConduct.charge,
      EnemyTrait.breaker,
    ),
    SurvivalKind.sower => (EnemyTier.colossus, EnemyConduct.charge, null),
    SurvivalKind.crest => (EnemyTier.brute, EnemyConduct.charge, null),
    SurvivalKind.snare => (EnemyTier.sentinel, EnemyConduct.orbit, null),
    SurvivalKind.core => (EnemyTier.brute, EnemyConduct.charge, null),
  };
  return (CosmicSurvivalEnemy(
      position: at,
      angle: 3.14159,
      hp: 100 * hp,
      maxHp: 100,
      speed: 60,
      damage: 10,
      radius: tierRadius(tier) * (elite ? 1.3 : 1),
      tier: tier,
      element: element,
      conduct: conduct,
      trait: trait,
      target: CosmicEnemyTarget.orb,
      isElite: elite,
      eliteAffix: elite ? EliteAffix.volatile : null,
      hitFlash: flash,
      summonCooldown: 0.8,
    )
    ..kind = kind
    ..age = arrive >= 1 ? 10 : arrive * RosterBatch.arrivalSeconds(kind)
    // The hurt row shows a snare closed.
    ..snareClosed = kind == SurvivalKind.snare && hp < 1);
}

void main() {
  final out = Platform.environment['ROSTER_ART_OUT'];

  testWidgets('survival roster art lineup', (tester) async {
    if (out == null) return;
    final time =
        double.tryParse(Platform.environment['ROSTER_ART_T'] ?? '') ?? 1.3;
    const cell = Size(150, 120), zoom = 3.0;
    const kinds = SurvivalKind.values;
    final rows = <CosmicSurvivalEnemy Function(SurvivalKind, Offset)>[
      (k, at) => _enemy(k, at),
      (k, at) => _enemy(k, at, element: 'Water'),
      (k, at) => _enemy(k, at, element: 'Plant'),
      (k, at) => _enemy(k, at, element: 'Spirit', hp: 0.3),
      (k, at) => _enemy(k, at, element: 'Fire', elite: true),
      (k, at) => _enemy(k, at, element: 'Fire', flash: 1),
      (k, at) => _enemy(k, at, element: 'Water', arrive: 0.33),
      (k, at) => _enemy(k, at, element: 'Water', arrive: 0.66),
    ];
    final size = Size(cell.width * kinds.length, cell.height * rows.length);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.scale(zoom);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0D1220),
    );
    final batch = RosterBatch();
    for (var r = 0; r < rows.length; r++) {
      for (var k = 0; k < kinds.length; k++) {
        final at = Offset(cell.width * (k + 0.6), cell.height * (r + 0.5));
        // The orb sits to each body's left, near enough for a Siphon to
        // have latched.
        final orb = at - const Offset(64, 0);
        batch.add(rows[r](kinds[k], at), kinds[k], time, orb);
        if (kinds[k] == SurvivalKind.siphon) {
          canvas.drawCircle(orb, 5, Paint()..color = const Color(0xFF39C2D8));
        }
      }
    }
    batch.flush(canvas);
    final img = rec.endRecording().toImageSync(
      (size.width * zoom).round(),
      (size.height * zoom).round(),
    );
    await tester.runAsync(() async {
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  });
}
