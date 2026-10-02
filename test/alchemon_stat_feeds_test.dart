// The Battle tab prints which stats feed each combat number from
// alchemonStatFeeds. That table is written by hand next to the formulas, so
// this raises each stat in turn through the real derivation and cadence rules
// and checks the table names exactly the stats that move each number.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter_test/flutter_test.dart';

const _families = [
  'Horn',
  'Mane',
  'Wing',
  'Let',
  'Pip',
  'Mask',
  'Kin',
  'Mystic',
];

Map<AlchemonCombatOutput, double> _outputs(
  String family,
  Map<AlchemonStat, double> stats,
) {
  final member = CosmicPartyMember(
    instanceId: 'feeds',
    baseId: 'feeds',
    displayName: 'Feeds',
    family: family,
    element: 'Fire',
    level: 1,
    statStrength: stats[AlchemonStat.strength]!,
    statIntelligence: stats[AlchemonStat.intelligence]!,
    statBeauty: stats[AlchemonStat.beauty]!,
    statSpeed: stats[AlchemonStat.speed]!,
    slotIndex: 0,
    staminaBars: 3,
    staminaMax: 3,
  );
  final c = deriveAlchemonCombatStats(member: member);
  return {
    AlchemonCombatOutput.hp: c.maxHp.toDouble(),
    AlchemonCombatOutput.physAtk: c.physAtk.toDouble(),
    AlchemonCombatOutput.elemAtk: c.elemAtk.toDouble(),
    AlchemonCombatOutput.special: c.abilityAtk.toDouble(),
    AlchemonCombatOutput.physDef: c.physDef.toDouble(),
    AlchemonCombatOutput.elemDef: c.elemDef.toDouble(),
    AlchemonCombatOutput.range: c.attackRange,
    AlchemonCombatOutput.attackInterval: alchemonBasicAttackInterval(
      family: family,
      element: 'Fire',
      cooldownReduction: c.cooldownReduction,
      physAtk: c.physAtk,
    ),
    AlchemonCombatOutput.specialInterval: alchemonSpecialInterval(
      family: family,
      element: 'Fire',
      specialCooldownReduction: c.specialCooldownReduction,
      abilityAtk: c.abilityAtk,
    ),
  };
}

void main() {
  // Start points above the cadence floor (kAbilityStatLow: Speed and the
  // recharge stats count from 250). Some feeds act in only part of the range
  // — Strength speeds auto attacks until P-ATK 41; a Mystic's SPECIAL brings
  // its recharge down until 36 and its recharge stats count from 350 and only
  // while SPECIAL is short of that — so a stat must move a number from one of
  // these points, or from none.
  const profiles = [
    {
      AlchemonStat.strength: 3.0,
      AlchemonStat.intelligence: 3.0,
      AlchemonStat.beauty: 3.0,
      AlchemonStat.speed: 3.0,
    },
    {
      AlchemonStat.strength: 4.0,
      AlchemonStat.intelligence: 4.0,
      AlchemonStat.beauty: 4.0,
      AlchemonStat.speed: 4.0,
    },
    {
      AlchemonStat.strength: 4.0,
      AlchemonStat.intelligence: 4.0,
      AlchemonStat.beauty: 1.0,
      AlchemonStat.speed: 4.0,
    },
  ];
  const bump = 1.5;

  for (final family in _families) {
    test('$family: the stat table names exactly what moves each number', () {
      final declared = alchemonStatFeeds(family);
      for (final stat in AlchemonStat.values) {
        final moved = <AlchemonCombatOutput>{};
        for (final start in profiles) {
          final before = _outputs(family, start);
          final after = _outputs(family, {...start, stat: start[stat]! + bump});
          for (final output in AlchemonCombatOutput.values) {
            if ((after[output]! - before[output]!).abs() > 1e-9) {
              moved.add(output);
            }
          }
        }
        for (final output in AlchemonCombatOutput.values) {
          final moves = moved.contains(output);
          expect(
            moves,
            declared[output]!.containsKey(stat),
            reason:
                '$family ${stat.name} → ${output.name}: '
                '${moves ? 'moves it but the table leaves it out' : 'the table names it but it does not move'}',
          );
        }
      }
    });
  }

  test('the blended shares the tab prints add up', () {
    for (final family in _families) {
      final feeds = alchemonStatFeeds(family);
      for (final output in [
        AlchemonCombatOutput.hp,
        AlchemonCombatOutput.special,
        AlchemonCombatOutput.physDef,
        AlchemonCombatOutput.elemDef,
      ]) {
        final total = feeds[output]!.values.fold<double>(0, (a, w) => a + w!);
        expect(total, closeTo(1.0, 1e-9), reason: '$family ${output.name}');
      }
    }
  });

  test('Wing+Dark is twice as fast once, not twice over', () {
    double basic(String element) => alchemonBasicAttackInterval(
      family: 'Wing',
      element: element,
      cooldownReduction: 1.0,
      physAtk: 20,
    );
    double special(String element) => alchemonSpecialInterval(
      family: 'Wing',
      element: element,
      specialCooldownReduction: 1.0,
      abilityAtk: 20,
    );
    expect(basic('Dark'), closeTo(basic('Air') * 0.5, 1e-9));
    expect(
      special('Dark'),
      closeTo(
        special('Air') *
            0.5 *
            elementalSpecialCooldownMultiplierSurvival('wing', 'Dark') /
            elementalSpecialCooldownMultiplierSurvival('wing', 'Air'),
        1e-9,
      ),
    );
  });
}
