import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter_test/flutter_test.dart';

/// The alchemical surges that deepen a Mystic's world.
///
/// A Mystic is the single-slot pick, and until these existed nothing in the
/// draft could make that choice pay off any harder. The thing worth guarding is
/// the gate: a world surge names one element, and offering it to a party that
/// cannot field it burns one of three draft slots on a pick that does nothing.
void main() {
  CosmicPartyMember member(String family, String element) => CosmicPartyMember(
    instanceId: '$family-$element',
    baseId: 'SRG01',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: 0,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    statSpeedPotential: 80,
    statIntelligencePotential: 80,
    statStrengthPotential: 80,
    statBeautyPotential: 80,
    staminaBars: 3,
    staminaMax: 3,
  );

  test('there is one surge per reworked world, and no duplicates', () {
    const worlds = {
      'Fire',
      'Spirit',
      'Blood',
      'Dark',
      'Plant',
      'Lightning',
      'Poison',
      'Mud',
      'Earth',
    };
    expect(
      kMysticWorldPowerUps.map((d) => d.mysticElement).toSet(),
      worlds,
      reason:
          'the eight Mystics that are still projectile ultimates have nothing '
          'standing on the map to deepen — they get surges when they get worlds',
    );
    expect(
      kMysticWorldPowerUps.map((d) => d.id).toSet(),
      hasLength(kMysticWorldPowerUps.length),
    );
    for (final def in kMysticWorldPowerUps) {
      expect(def.maxStacks, 3, reason: '${def.id} should have three levels');
      expect(def.scope, PowerUpScope.companion);
    }
  });

  test('a world surge is never offered to a party that cannot use it', () {
    final state = PowerUpState();
    // A party with no Mystic at all.
    final noMystic = [member('Horn', 'Fire'), member('Pip', 'Plant')];
    for (var wave = 1; wave <= 40; wave++) {
      final offers = generatePowerUpChoices(state, wave, party: noMystic);
      expect(
        offers.where((o) => o.def.mysticElement != null),
        isEmpty,
        reason: 'wave $wave offered a world surge with no Mystic fielded',
      );
    }

    // A Plant Mystic fielded: Grove may appear, but no other world's surge.
    final plantMystic = [member('Mystic', 'Plant'), member('Horn', 'Fire')];
    var sawGrove = false;
    for (var wave = 1; wave <= 60; wave++) {
      final offers = generatePowerUpChoices(state, wave, party: plantMystic);
      for (final o in offers) {
        final element = o.def.mysticElement;
        if (element == null) continue;
        expect(
          element,
          'Plant',
          reason: 'offered a $element world surge to a Plant Mystic party',
        );
        // And it must land on the Mystic, not on the Horn standing beside it.
        expect(
          o.targetSlot,
          0,
          reason: 'the surge was aimed at a companion that owns no world',
        );
        sawGrove = true;
      }
    }
    expect(
      sawGrove,
      isTrue,
      reason: 'a fielded world never had its surge offered in sixty waves',
    );
  });

  test('three picks deepen a world by three quarters', () {
    final state = PowerUpState();
    final def = kMysticWorldPowerUps.firstWhere((d) => d.id == 'world_plant');
    expect(state.mysticWorldPower(0, 'Plant'), 1.0);
    for (var i = 1; i <= 3; i++) {
      state.apply(def, targetSlot: 0);
      expect(state.mysticWorldLevel(0, 'Plant'), i);
    }
    expect(state.mysticWorldPower(0, 'Plant'), closeTo(1.75, 0.0001));

    // Capped: a fourth pick is not offered, and would not stack if forced.
    expect(state.canApply(def, targetSlot: 0, companionCount: 1), isFalse);
    // And it is that Mystic's world, not the party's.
    expect(state.mysticWorldPower(1, 'Plant'), 1.0);
  });
}
