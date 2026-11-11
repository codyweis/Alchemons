// THE ENEMIES' BUDGET. Survival fields up to 3,000 bodies and open space a
// few hundred, and every one in view is drawn every frame. They are drawn in
// grains (lib/games/cosmic_survival/roster_art.dart): each body appends its
// grains and tubes to buffers shared by its colour, and the field goes out in
// a handful of draws per colour, however many bodies there are. This keeps
// that true, and keeps every body and boss blur-free.
//
// A budget test, not a golden: it does not care what the enemies look like
// (test/survival_roster_art_preview_test.dart and
// test/survival_boss_roster_preview_test.dart render that), only what they
// cost.

import 'dart:ui';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/roster_art.dart';
import 'package:alchemons/games/cosmic_survival/survival_kind.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter_test/flutter_test.dart';

/// Records what a frame asks the GPU to do.
class _CensusCanvas implements Canvas {
  final Map<String, int> counts = {};
  int blurredDraws = 0;

  @override
  dynamic noSuchMethod(Invocation i) {
    final n = i.memberName.toString();
    final key = n.substring(8, n.length - 2);
    counts[key] = (counts[key] ?? 0) + 1;
    for (final a in i.positionalArguments) {
      if (a is Paint && a.maskFilter != null) blurredDraws++;
    }
    if (key == 'getSaveCount') return 1;
    return null;
  }

  int get draws => counts.entries
      .where((e) => e.key.startsWith('draw'))
      .fold(0, (s, e) => s + e.value);
}

/// The most draws one colour's bodies can take: two mass paths, three tube
/// widths, five heavy and six fine grain tones, and the heads.
const _perColour = 17;

const _elements = ['Fire', 'Water', 'Plant'];

/// Adds [copies] of every kind in every one of [_elements] to [batch],
/// spread over a field; returns how many Hollows went in.
int _field(RosterBatch batch, int copies, {double time = 1.3}) {
  var hollows = 0;
  var i = 0;
  for (final element in _elements) {
    for (final kind in SurvivalKind.values) {
      for (var k = 0; k < copies; k++, i++) {
        if (kind == SurvivalKind.hollow) hollows++;
        batch.addBody(
          kind: kind,
          time: time,
          position: Offset((i % 40) * 60.0, (i ~/ 40) * 60.0),
          radius: 14,
          heading: i * 0.7,
          hp: 0.3 + (i % 7) / 10,
          color: elementColor(element),
          seed: i,
          arrive: (i % 5) / 4,
        );
      }
    }
  }
  return hollows;
}

void main() {
  test('a field goes out in a few draws a colour, however many bodies', () {
    for (final copies in [1, 4, 12]) {
      final batch = RosterBatch();
      final hollows = _field(batch, copies);
      final c = _CensusCanvas();
      batch.flush(c as Canvas);
      expect(c.blurredDraws, 0);
      // A Hollow's gap is one draw of its own; nothing else grows with the
      // crowd.
      expect(
        c.draws,
        lessThanOrEqualTo(_perColour * _elements.length + hollows),
        reason: '${copies * SurvivalKind.values.length * 3} bodies',
      );
    }
  });

  test('struck bodies draw no blur and stay bounded', () {
    final batch = RosterBatch();
    var hollows = 0;
    for (final kind in SurvivalKind.values) {
      for (var copy = 0; copy < 5; copy++) {
        if (kind == SurvivalKind.hollow) hollows += 2;
        batch
          ..addBody(
            kind: kind,
            time: 2,
            position: Offset.zero,
            radius: 20,
            heading: 1,
            hp: 1,
            color: elementColor('Water'),
            seed: 3,
            hitFlash: 1,
          )
          ..addBody(
            kind: kind,
            time: 2,
            position: const Offset(80, 0),
            radius: 26,
            heading: 1,
            hp: 1,
            color: elementColor('Water'),
            seed: 4,
          );
      }
    }
    final c = _CensusCanvas();
    batch.flush(c as Canvas);
    expect(c.blurredDraws, 0);
    // The flash's palette and the element's.
    expect(c.draws, lessThanOrEqualTo(_perColour * 2 + hollows));
  });

  test('the tells drawn over a body draw no blur and stay small', () {
    for (final tier in EnemyTier.values) {
      for (final phase in EnemyActionPhase.values) {
        final e = CosmicSurvivalEnemy(
          position: const Offset(100, 100),
          hp: 100,
          maxHp: 100,
          speed: 60,
          damage: 10,
          radius: tierRadius(tier),
          tier: tier,
          element: 'Fire',
          conduct: EnemyConduct.charge,
          target: CosmicEnemyTarget.orb,
        )..hornPlantRootTimer = 0.3;
        e.action
          ..phase = phase
          ..timer = 0.1;
        final c = _CensusCanvas();
        drawSurvivalEnemyMarks(canvas: c as Canvas, enemy: e, time: 1.3);
        expect(c.blurredDraws, 0, reason: '$tier $phase blurs');
        expect(c.draws, lessThanOrEqualTo(14), reason: '$tier $phase');
      }
    }
  });

  test('bosses draw no blur and stay bounded', () {
    for (final type in BossType.values) {
      for (final enraged in [false, true]) {
        final ow = CosmicBoss(
          position: Offset.zero,
          name: type.name,
          element: 'Dark',
          level: 3,
          radius: 42,
          maxHealth: 1000,
          speed: 60,
          forcedType: type,
          charging: true,
          shieldUp: true,
          shieldHealth: 100,
        )..enraged = enraged;
        final c = _CensusCanvas();
        drawOpenWorldBoss(canvas: c as Canvas, boss: ow, time: 2.2);
        expect(c.blurredDraws, 0, reason: 'open-world $type blurs');
        expect(c.draws, lessThanOrEqualTo(30), reason: 'open-world $type');
      }
    }
    for (final d in SurvivalBossDiscipline.values) {
      for (final type in BossType.values) {
        final boss = SurvivalBoss(
          template: kBossTemplates.first,
          type: type,
          discipline: d,
          level: 5,
          position: Offset.zero,
          hp: 800,
          maxHp: 1000,
          speed: 70,
          baseSpeed: 70,
          radius: 40,
          color: Colors.orange,
        );
        final c = _CensusCanvas();
        drawSurvivalBoss(
          canvas: c as Canvas,
          boss: boss,
          time: 2.2,
          core: const Offset(-300, 0),
        );
        expect(c.blurredDraws, 0, reason: 'survival $d $type blurs');
        expect(c.draws, lessThanOrEqualTo(30), reason: 'survival $d $type');
      }
    }
  });
}
