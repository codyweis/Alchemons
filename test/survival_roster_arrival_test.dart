import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/roster_art.dart';
import 'package:alchemons/games/cosmic_survival/survival_kind.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicSurvivalEnemy _body(SurvivalKind kind, double age) {
  final (tier, conduct, trait) = switch (kind) {
    SurvivalKind.mote => (EnemyTier.wisp, EnemyConduct.charge, null),
    SurvivalKind.strand => (EnemyTier.drone, EnemyConduct.charge, null),
    SurvivalKind.braid => (
      EnemyTier.sentinel,
      EnemyConduct.charge,
      EnemyTrait.splitter,
    ),
    SurvivalKind.husk ||
    SurvivalKind.crest => (EnemyTier.brute, EnemyConduct.charge, null),
    SurvivalKind.hollow => (EnemyTier.phantom, EnemyConduct.stalk, null),
    SurvivalKind.spill ||
    SurvivalKind.snare => (EnemyTier.sentinel, EnemyConduct.orbit, null),
    SurvivalKind.core => (EnemyTier.brute, EnemyConduct.charge, null),
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
  };
  return CosmicSurvivalEnemy(
      position: const ui.Offset(400, 300),
      angle: 3.14159,
      hp: 100,
      maxHp: 100,
      speed: 60,
      damage: 10,
      radius: tierRadius(tier),
      tier: tier,
      element: 'Water',
      conduct: conduct,
      trait: trait,
      target: CosmicEnemyTarget.orb,
    )
    ..kind = kind
    ..age = age;
}

final _bodies = <SurvivalKind, CosmicSurvivalEnemy>{};

/// Grains [kind]'s body draws [age] seconds after it entered. The same body
/// each time: its turning is seeded by which body it is.
int _grains(SurvivalKind kind, double age) {
  final body = _bodies.putIfAbsent(kind, () => _body(kind, 0))..age = age;
  final batch = RosterBatch();
  batch.add(body, kind, 1.3, const ui.Offset(300, 300));
  final rec = ui.PictureRecorder();
  batch.flush(ui.Canvas(rec));
  rec.endRecording().dispose();
  return batch.lastGrains;
}

void main() {
  test('a body entering the field gathers: thin at first, whole once in', () {
    for (final kind in SurvivalKind.values) {
      final whole = _grains(kind, 10);
      final seconds = RosterBatch.arrivalSeconds(kind);
      var last = -1;
      for (final f in [0.0, 0.2, 0.5, 0.8, 1.0]) {
        final n = _grains(kind, f * seconds);
        expect(n, greaterThanOrEqualTo(last), reason: '$kind at $f');
        last = n;
      }
      // A strand is all tube: it uncoils instead of thinning.
      if (kind != SurvivalKind.strand) {
        expect(_grains(kind, 0), lessThan(whole), reason: '$kind');
      }
      expect(_grains(kind, seconds), whole, reason: '$kind');
    }
  });
}
