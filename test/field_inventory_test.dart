// The wilderness Items panel shows field gear only.
//
// It used to list everything that was not a vial, so boss relics, loot boxes
// and enhancement items — none of which a field can use — buried the
// harvesters and keys, in a full-height panel. These pin what is in it and
// the order it comes in.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/wilderness/inventory_hud.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InventoryItem held(String key, [int qty = 1]) =>
      InventoryItem(key: key, qty: qty);

  test('boss relics and other non-field items stay out', () {
    final shown = fieldGearIn([
      held(BossLootKeys.traitKeyForElement('fire')),
      held(BossLootKeys.traitKeyForElement('water')),
      held(BossLootKeys.lootBoxKeyForElement('fire'), 2),
      held(InvKeys.bossSummon),
      held(InvKeys.raidBeacon),
      held(InvKeys.instantHatch),
      held(InvKeys.potentialSoul),
      held(InvKeys.powerupSpeed),
      held(InvKeys.alchemyGlow),
      held(InvKeys.homePlanetSlots),
      held('vial.common.fire'),
      held(InvKeys.wildFusion, 4),
    ]).map((i) => i.key);

    expect(shown, [InvKeys.wildFusion]);
  });

  test('gear comes in the order a player reaches for it', () {
    // Stored order is alphabetical by key, which put Stamina before Wild
    // Fusion and the keys between the harvesters.
    final shown = fieldGearIn([
      held(InvKeys.staminaPotion),
      held(InvKeys.portalKeyVolcanic),
      held(InvKeys.harvesterStdOceanic),
      held(InvKeys.harvesterGuaranteed),
      held(InvKeys.wildlifeLure),
      held(InvKeys.wildFusion),
    ]).map((i) => i.key);

    expect(shown, [
      InvKeys.wildFusion,
      InvKeys.wildlifeLure,
      InvKeys.harvesterGuaranteed,
      InvKeys.harvesterStdOceanic,
      InvKeys.portalKeyVolcanic,
      InvKeys.staminaPotion,
    ]);
  });

  test('an empty stack is not shown', () {
    expect(fieldGearIn([held(InvKeys.wildlifeLure, 0)]), isEmpty);
  });

  test('every piece of field gear has an inventory entry', () {
    // A key with no registry entry used to render as a blank gap in the grid.
    final registry = buildInventoryRegistry(
      // The registry only reads the db inside item use callbacks.
      _NoDb(),
    );
    for (final key in kFieldGearOrder) {
      expect(registry.containsKey(key), isTrue, reason: key);
    }
  });
}

class _NoDb implements AlchemonsDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
