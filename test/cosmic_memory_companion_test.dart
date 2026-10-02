// The memory's companion has to be a veteran in every sense.
//
// The tutorial borrows whatever creature the player owns first — a starter —
// and hands it a veteran's stats, because special cooldown scales off those
// and the memory otherwise spends its length waiting for the one ability it
// is trying to teach. But LEVEL is a separate multiplier on every combat
// number, so boosting the stats alone left the memory's companion swinging
// like a level-1 starter. These pin why the level has to travel with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';

void main() {
  const stat = 95.0;

  test('identical stats, and level alone still separates them', () {
    AlchemonCombatStats at(int level) => deriveAlchemonCombatStats(
      member: CosmicPartyMember(
        instanceId: 'memory',
        baseId: 'memory',
        displayName: 'Memory',
        element: 'Spirit',
        family: 'Pip',
        level: level,
        statSpeed: stat,
        statIntelligence: stat,
        statStrength: stat,
        statBeauty: stat,
        slotIndex: 0,
        staminaBars: 3,
        staminaMax: 3,
      ),
    );
    int hp(int level) => at(level).maxHp;
    int atk(int level) => at(level).physAtk;
    int def(int level) => at(level).physDef;

    const top = CosmicBalance.maxCompanionLevel;
    expect(
      hp(top),
      greaterThan(hp(1)),
      reason: 'a level-1 memory companion sits on the floor of the HP curve',
    );
    expect(atk(top), greaterThan(atk(1)));
    expect(def(top), greaterThan(def(1)));
  });

  test('the memory uses the top of the companion band', () {
    expect(CosmicBalance.maxCompanionLevel, 10);
    expect(
      CosmicBalance.clampCompanionLevel(CosmicBalance.maxCompanionLevel),
      CosmicBalance.maxCompanionLevel,
      reason: 'the memory passes this straight through as its level',
    );
  });
}
