// lib/data/boss_data.dart

import 'package:alchemons/models/boss/boss_model.dart';

class BossRepository {
  static final List<Boss> allBosses = [
    // Tier 1: Basic Elements (1-4)
    Boss(
      id: 'boss_001',
      name: 'Fire Lord',
      element: 'Fire',
      recommendedLevel: 15,
      hp: 1000,
      atk: 10,
      def: 10,
      spd: 10,
      tier: BossTier.basic,
      order: 1,
      moveset: [
        BossMove(
          name: 'Fireball',
          description: 'Hurls a blazing fireball at a single target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Eruption',
          description: 'Unleashes volcanic fury hitting all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Harden',
          description: 'Hardens molten armor, raising Defense',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_002',
      name: 'Water Serpent',
      element: 'Water',
      recommendedLevel: 20,
      hp: 2000,
      atk: 20,
      def: 20,
      spd: 20,
      tier: BossTier.basic,
      order: 2,
      moveset: [
        BossMove(
          name: 'Aqua-jet',
          description: 'High-pressure water blast at one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Tidal Wave',
          description: 'Massive wave crashes into all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Slow',
          description: 'Drenches target, reducing their Speed',
          type: BossMoveType.debuff,
        ),
      ],
    ),
    Boss(
      id: 'boss_003',
      name: 'Earth Golem',
      element: 'Earth',
      recommendedLevel: 25,
      hp: 2800,
      atk: 30,
      def: 30,
      spd: 30,
      tier: BossTier.basic,
      order: 3,
      moveset: [
        BossMove(
          name: 'Rock-throw',
          description: 'Hurls a massive boulder at one target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Earthquake',
          description: 'Ground-shaking tremor hits all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Fortify',
          description: 'Stone body hardens, raising Defense',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_004',
      name: 'Air Elemental',
      element: 'Air',
      recommendedLevel: 30,
      hp: 2000,
      atk: 100,
      def: 10,
      spd: 100,
      tier: BossTier.basic,
      order: 4,
      moveset: [
        BossMove(
          name: 'Gale-slash',
          description: 'Cutting wind blade strikes one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Tornado',
          description: 'Violent whirlwind engulfs all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Evade',
          description: 'Wind currents boost Speed drastically',
          type: BossMoveType.buff,
        ),
      ],
    ),

    // Tier 2: Hybrid Elements (5-8)
    Boss(
      id: 'boss_005',
      name: 'Overgrown Treant',
      element: 'Plant',
      recommendedLevel: 35,
      hp: 4000,
      atk: 80,
      def: 75,
      spd: 55,
      tier: BossTier.hybrid,
      order: 5,
      moveset: [
        BossMove(
          name: 'Vine-whip',
          description: 'Thorny vines lash at single target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Overgrow',
          description: 'Wild vegetation entangles all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Regen',
          description: 'Regenerates HP over 3 turns',
          type: BossMoveType.heal,
        ),
      ],
    ),
    Boss(
      id: 'boss_006',
      name: 'Tundra Behemoth',
      element: 'Ice',
      recommendedLevel: 40,
      hp: 4500,
      atk: 90,
      def: 85,
      spd: 60,
      tier: BossTier.hybrid,
      order: 6,
      moveset: [
        BossMove(
          name: 'Icicle-spear',
          description: 'Piercing ice lance at one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Blizzard',
          description: 'Freezing storm hits all (10% Freeze chance)',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Ice-shield',
          description: 'Creates frozen barrier around self',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_007',
      name: 'Thunder Wyvern',
      element: 'Lightning',
      recommendedLevel: 45,
      hp: 4200,
      atk: 110,
      def: 70,
      spd: 90,
      tier: BossTier.hybrid,
      order: 7,
      moveset: [
        BossMove(
          name: 'Zap-cannon',
          description: 'Concentrated lightning bolt at one target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Thunderstorm',
          description: 'Electrical storm with high crit chance',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Charge-up',
          description: 'Next attack deals double damage',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_008',
      name: 'Plague Dragon',
      element: 'Poison',
      recommendedLevel: 50,
      hp: 5500,
      atk: 100,
      def: 90,
      spd: 70,
      tier: BossTier.hybrid,
      order: 8,
      moveset: [
        BossMove(
          name: 'Toxin-spit',
          description: 'Venomous projectile at single target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Plague-mist',
          description: 'Toxic fog with high Poison chance',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Corrode',
          description: 'Acid reduces all enemies\' Defense',
          type: BossMoveType.debuff,
        ),
      ],
    ),

    // Tier 3: Advanced Hybrids (9-13)
    Boss(
      id: 'boss_009',
      name: 'Steam Centurion',
      element: 'Steam',
      recommendedLevel: 55,
      hp: 6000,
      atk: 120,
      def: 110,
      spd: 80,
      tier: BossTier.advanced,
      order: 9,
      moveset: [
        BossMove(
          name: 'Scald',
          description: 'Boiling water burns single enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Geyser-field',
          description: 'Steam eruptions hit all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Mist-shroud',
          description: 'Vapor increases Speed & Accuracy',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_010',
      name: 'Magma Titan',
      element: 'Lava',
      recommendedLevel: 60,
      hp: 7000,
      atk: 140,
      def: 130,
      spd: 50,
      tier: BossTier.advanced,
      order: 10,
      moveset: [
        BossMove(
          name: 'Lava-plume',
          description: 'Molten rock blast at one target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Volcano',
          description: 'Volcanic explosion applies "Melt" debuff',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Molten-armor',
          description: 'Raises Def, burns attackers',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_011',
      name: 'Swamp Horror',
      element: 'Mud',
      recommendedLevel: 65,
      hp: 7500,
      atk: 130,
      def: 140,
      spd: 60,
      tier: BossTier.advanced,
      order: 11,
      moveset: [
        BossMove(
          name: 'Mud-bomb',
          description: 'Sticky sludge hits single enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Quagmire',
          description: 'Swamp trap applies "Slow" to all',
          type: BossMoveType.debuff,
        ),
        BossMove(
          name: 'Sink',
          description: 'Submerges for 1 turn, then strikes',
          type: BossMoveType.special,
        ),
      ],
    ),
    Boss(
      id: 'boss_012',
      name: 'Sandstorm Djinn',
      element: 'Dust',
      recommendedLevel: 70,
      hp: 6800,
      atk: 150,
      def: 100,
      spd: 120,
      tier: BossTier.advanced,
      order: 12,
      moveset: [
        BossMove(
          name: 'Sand-vortex',
          description: 'Swirling sand strikes one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Sandstorm',
          description: 'Desert storm applies "Grit" debuff',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Mirage',
          description: 'Creates illusory copy of itself',
          type: BossMoveType.special,
        ),
      ],
    ),
    Boss(
      id: 'boss_013',
      name: 'Crystal Colossus',
      element: 'Crystal',
      recommendedLevel: 75,
      hp: 8500,
      atk: 130,
      def: 160,
      spd: 70,
      tier: BossTier.advanced,
      order: 13,
      moveset: [
        BossMove(
          name: 'Gem-shard',
          description: 'Razor-sharp crystal at one target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Crystal-nova',
          description: 'Prismatic explosion hits all',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Refract',
          description: 'Light barrier grants damage shield',
          type: BossMoveType.buff,
        ),
      ],
    ),

    // Tier 4: Arcane & Cosmic (14-17)
    Boss(
      id: 'boss_014',
      name: 'Ancient Phantom',
      element: 'Spirit',
      recommendedLevel: 80,
      hp: 10000,
      atk: 170,
      def: 150,
      spd: 100,
      tier: BossTier.cosmic,
      order: 14,
      moveset: [
        BossMove(
          name: 'Ecto-ball',
          description: 'Ghostly energy strikes one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Phantom-wail',
          description: 'Terrifying scream hits all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Cleanse',
          description: 'Removes all debuffs from itself',
          type: BossMoveType.buff,
        ),
      ],
    ),
    Boss(
      id: 'boss_015',
      name: 'Umbral Abomination',
      element: 'Dark',
      recommendedLevel: 85,
      hp: 12000,
      atk: 250,
      def: 180,
      spd: 110,
      tier: BossTier.cosmic,
      order: 15,
      moveset: [
        BossMove(
          name: 'Night-slash',
          description: 'Shadowy blade cuts single target',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Void-pulse',
          description: 'Dark energy drains life from all',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Eclipse',
          description: 'Applies "Blind" to all enemies',
          type: BossMoveType.debuff,
        ),
      ],
    ),
    Boss(
      id: 'boss_016',
      name: 'Radiant Avatar',
      element: 'Light',
      recommendedLevel: 90,
      hp: 12000,
      atk: 200,
      def: 200,
      spd: 150,
      tier: BossTier.cosmic,
      order: 16,
      moveset: [
        BossMove(
          name: 'Holy-smite',
          description: 'Divine light strikes one enemy',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Supernova',
          description: 'Celestial explosion hits all',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Genesis',
          description: 'Heals 25% HP, grants Boon buff',
          type: BossMoveType.heal,
        ),
      ],
    ),
    Boss(
      id: 'boss_017',
      name: 'Crimson King',
      element: 'Blood',
      recommendedLevel: 100,
      hp: 20000,
      atk: 250,
      def: 220,
      spd: 150,
      tier: BossTier.cosmic,
      order: 17,
      moveset: [
        BossMove(
          name: 'Life-drain',
          description: 'Vampiric attack steals HP from one',
          type: BossMoveType.singleTarget,
        ),
        BossMove(
          name: 'Blood-boil',
          description: 'Sanguine explosion hits all enemies',
          type: BossMoveType.aoe,
        ),
        BossMove(
          name: 'Empower',
          description: 'Trades 10% HP for 50% Attack boost',
          type: BossMoveType.buff,
        ),
      ],
    ),
  ];

  static Boss? getBossById(String id) {
    try {
      return allBosses.firstWhere((b) => b.id == id);
    } catch (e) {
      return null;
    }
  }

  static Boss? getBossByOrder(int order) {
    try {
      return allBosses.firstWhere((b) => b.order == order);
    } catch (e) {
      return null;
    }
  }

  static List<Boss> getBossesByTier(BossTier tier) {
    return allBosses.where((b) => b.tier == tier).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }
}
