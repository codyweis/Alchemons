// test/battle_engine_test.dart
// Copy this to your test folder and run: flutter test

import 'package:alchemons/models/boss/boss_model.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Battle Engine Tests', () {
    test('Calculate combat stats correctly', () {
      final combatant = BattleCombatant(
        id: 'test1',
        name: 'Firelet',
        types: ['Fire'],
        family: 'Let',
        statSpeed: 8.0,
        statIntelligence: 6.0,
        statStrength: 5.0,
        statBeauty: 7.0,
        level: 5,
      );

      // Test formulas from StatsFormulas.csv
      expect(combatant.maxHp, (5 * 10) + (5 * 5)); // 75
      expect(combatant.physAtk, 5 + (5 * 5)); // 30
      expect(combatant.elemAtk, 34);
      expect(combatant.physDef, ((50 + 70) * 0.2 + 5).round()); // 29
      expect(combatant.elemDef, (70 * 0.4 + (5 * 2)).round()); // 38
      expect(combatant.speed, (80 * 0.4).round()); // 32

      debugPrint('✅ Stat calculations correct!');
      debugPrint('   Max HP: ${combatant.maxHp}');
      debugPrint('   Phys Atk: ${combatant.physAtk}');
      debugPrint('   Elem Atk: ${combatant.elemAtk}');
    });

    test('Type effectiveness works correctly', () {
      // Fire beats Plant (×2)
      expect(BattleEngine.getTypeMultiplier('Fire', ['Plant']), 2.0);

      // Water beats Fire (×2)
      expect(BattleEngine.getTypeMultiplier('Water', ['Fire']), 2.0);

      // Fire vs Water (×0.5, not effective)
      expect(BattleEngine.getTypeMultiplier('Fire', ['Water']), 0.5);

      // Fire vs Earth (×0.5, not effective)
      expect(BattleEngine.getTypeMultiplier('Fire', ['Earth']), 0.5);

      // Lightning beats Water (×2)
      expect(BattleEngine.getTypeMultiplier('Lightning', ['Water']), 2.0);

      // Light beats Dark (×2)
      expect(BattleEngine.getTypeMultiplier('Light', ['Dark']), 2.0);

      debugPrint('✅ Type effectiveness working!');
      debugPrint('   Fire vs Plant: 2.0×');
      debugPrint('   Fire vs Water: 0.5×');
    });

    test('Damage calculation formula correct', () {
      final attacker = BattleCombatant(
        id: 'a1',
        name: 'Attacker',
        types: ['Fire'],
        family: 'Let',
        statSpeed: 10.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 10,
      );

      final defender = BattleCombatant(
        id: 'd1',
        name: 'Defender',
        types: ['Water'],
        family: 'Pip',
        statSpeed: 5.0,
        statIntelligence: 5.0,
        statStrength: 5.0,
        statBeauty: 5.0,
        level: 10,
      );

      final move = BattleMove.getBasicMove('Let');

      final damage = BattleEngine.calculateBaseDamage(
        move: move,
        attacker: attacker,
        defender: defender,
      );

      // Base = (Atk × 2) - Def
      // Phys Atk = (100 × 0.4) + (10 × 2) = 60
      // Phys Def = ((50 + 50) × 0.2) + 10 = 30
      // Base = (60 × 2) - 30 = 90

      expect(damage, 90);
      debugPrint('✅ Damage formula correct!');
      debugPrint('   Base damage: $damage');
    });

    test('Basic moves are correct for each family', () {
      expect(BattleMove.getBasicMove('Let').name, 'Catalyst Strike');
      expect(BattleMove.getBasicMove('Pip').name, 'Reagent Strike');
      expect(BattleMove.getBasicMove('Mane').name, 'Aether Strike');
      expect(BattleMove.getBasicMove('Horn').name, 'Crucible Strike');
      expect(BattleMove.getBasicMove('Mask').name, 'Sigil Strike');
      expect(BattleMove.getBasicMove('Wing').name, 'Flux Strike');
      expect(BattleMove.getBasicMove('Kin').name, 'Alloy Strike');
      expect(BattleMove.getBasicMove('Mystic').name, 'Quintessence Strike');

      debugPrint('✅ All basic moves correct!');
    });

    test('Special moves are correct for each family', () {
      expect(BattleMove.getSpecialMove('Let').name, 'Meteor Strike');
      expect(BattleMove.getSpecialMove('Pip').name, 'Frenzy');
      expect(BattleMove.getSpecialMove('Mane').name, 'Entangle');
      expect(BattleMove.getSpecialMove('Horn').name, 'Fortress');
      expect(BattleMove.getSpecialMove('Mask').name, 'Hex Field');
      expect(BattleMove.getSpecialMove('Wing').name, 'Piercing Beam');
      expect(BattleMove.getSpecialMove('Kin').name, 'Sanctuary');
      expect(BattleMove.getSpecialMove('Mystic').name, 'Arcane Orbitals');

      debugPrint('✅ All special moves correct!');
    });

    test('Full battle action with type advantage', () {
      final firelet = BattleCombatant(
        id: 'fire1',
        name: 'Firelet',
        types: ['Fire'],
        family: 'Let',
        statSpeed: 8.0,
        statIntelligence: 6.0,
        statStrength: 5.0,
        statBeauty: 7.0,
        level: 5,
      );

      final plantBoss =
          BattleCombatant(
              id: 'boss1',
              name: 'Plant Boss',
              types: ['Plant'],
              family: 'Boss',
              statSpeed: 10.0,
              statIntelligence: 20.0,
              statStrength: 20.0,
              statBeauty: 20.0,
              level: 15,
            )
            ..maxHp = 1500
            ..currentHp = 1500
            ..physAtk = 50
            ..physDef = 40;

      final move = BattleMove.getBasicMove('Let');
      final action = BattleAction(
        actor: firelet,
        move: move,
        target: plantBoss,
      );

      final result = BattleEngine.executeAction(action);

      expect(result.typeMultiplier, 2.0); // Fire vs Plant
      expect(result.damage, greaterThan(0));
      expect(result.messages.isNotEmpty, true);
      expect(plantBoss.currentHp, lessThan(1500));

      debugPrint('✅ Full battle action works!');
      debugPrint('   Type multiplier: ${result.typeMultiplier}');
      debugPrint('   Damage dealt: ${result.damage}');
      debugPrint('   Boss HP: ${plantBoss.currentHp}/1500');
      debugPrint('   Messages: ${result.messages}');
    });

    test('Status effects work', () {
      final combatant = BattleCombatant(
        id: 'test',
        name: 'Test',
        types: ['Fire'],
        family: 'Let',
        statSpeed: 10.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 5,
      );

      // Apply burn
      combatant.applyStatusEffect(
        StatusEffect(type: 'burn', damagePerTurn: 10, duration: 3),
      );

      expect(combatant.statusEffects.containsKey('burn'), true);
      expect(combatant.statusEffects['burn']!.duration, 3);

      // Tick once
      combatant.tickStatusEffects();
      expect(combatant.statusEffects['burn']!.duration, 2);

      // Tick until expired
      combatant.tickStatusEffects();
      combatant.tickStatusEffects();
      expect(combatant.statusEffects.containsKey('burn'), false);

      debugPrint('✅ Status effects working!');
    });

    test('Stat modifiers work', () {
      final combatant = BattleCombatant(
        id: 'test',
        name: 'Test',
        types: ['Fire'],
        family: 'Let',
        statSpeed: 10.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 10,
      );

      final baseAtk = combatant.physAtk;

      // Apply attack up
      combatant.applyStatModifier(StatModifier(type: 'attack_up', duration: 3));

      final boostedAtk = combatant.getEffectivePhysAtk();
      expect(boostedAtk, (baseAtk * 1.5).toInt());

      debugPrint('✅ Stat modifiers working!');
      debugPrint('   Base Atk: $baseAtk');
      debugPrint('   Boosted Atk: $boostedAtk');
    });

    test('Turn order determined by speed', () {
      final slow = BattleCombatant(
        id: 's1',
        name: 'Slow',
        types: ['Earth'],
        family: 'Horn',
        statSpeed: 5.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 5,
      );

      final fast = BattleCombatant(
        id: 'f1',
        name: 'Fast',
        types: ['Air'],
        family: 'Let',
        statSpeed: 15.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 5,
      );

      final medium = BattleCombatant(
        id: 'm1',
        name: 'Medium',
        types: ['Water'],
        family: 'Pip',
        statSpeed: 10.0,
        statIntelligence: 10.0,
        statStrength: 10.0,
        statBeauty: 10.0,
        level: 5,
      );

      final order = BattleEngine.determineTurnOrder([slow, fast, medium]);

      expect(order[0].name, 'Fast'); // Speed 15
      expect(order[1].name, 'Medium'); // Speed 10
      expect(order[2].name, 'Slow'); // Speed 5

      debugPrint('✅ Turn order correct!');
      debugPrint('   Order: ${order.map((c) => c.name).join(' → ')}');
    });
  });

  group('Boss Integration Tests', () {
    test('Boss combatant creation from Boss model', () {
      final boss = Boss(
        id: 'boss_001',
        name: 'Fire Lord',
        element: 'Fire',
        recommendedLevel: 15,
        hp: 1500,
        atk: 50,
        def: 40,
        spd: 40,
        tier: BossTier.basic,
        order: 1,
        moveset: [],
      );

      final combatant = BattleCombatant.fromBoss(boss);

      expect(combatant.maxHp, 1500);
      expect(combatant.currentHp, 1500);
      expect(combatant.physAtk, 50);
      expect(combatant.physDef, 40);
      expect(combatant.speed, 40);
      expect(combatant.types, ['Fire']);

      debugPrint('✅ Boss conversion works!');
      debugPrint('   Boss: ${combatant.name}');
      debugPrint('   HP: ${combatant.maxHp}');
      debugPrint('   Atk: ${combatant.physAtk}');
    });
  });
}

// Run this test with: flutter test test/battle_engine_test.dart
//
// Expected output:
//   ✅ All 10+ tests pass
//   ✅ Combat formulas verified
//   ✅ Type effectiveness working
//   ✅ Battle system functional
