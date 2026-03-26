// lib/data/boss_data.dart

import 'package:alchemons/models/boss/boss_model.dart';

class BossRepository {
  static final List<Boss> allBosses = [
    // Tier 1: Basic Elements (1-4)
    Boss(
      id: 'boss_001',
      name: 'Fire Lord',
      element: 'Fire',
      recommendedLevel: 10,
      hp: 340,
      atk: 20,
      def: 10,
      spd: 7,
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
      recommendedLevel: 10,
      hp: 380,
      atk: 21,
      def: 11,
      spd: 8,
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
      recommendedLevel: 10,
      hp: 425,
      atk: 22,
      def: 12,
      spd: 9,
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
      recommendedLevel: 10,
      hp: 470,
      atk: 23,
      def: 13,
      spd: 10,
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
      recommendedLevel: 10,
      hp: 520,
      atk: 24,
      def: 14,
      spd: 11,
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
      recommendedLevel: 10,
      hp: 570,
      atk: 25,
      def: 15,
      spd: 12,
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
      recommendedLevel: 10,
      hp: 610,
      atk: 25,
      def: 16,
      spd: 12,
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
      recommendedLevel: 10,
      hp: 660,
      atk: 26,
      def: 17,
      spd: 13,
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
      recommendedLevel: 10,
      hp: 740,
      atk: 28,
      def: 18,
      spd: 13,
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
      recommendedLevel: 10,
      hp: 770,
      atk: 28,
      def: 19,
      spd: 14,
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
      recommendedLevel: 10,
      hp: 830,
      atk: 29,
      def: 20,
      spd: 14,
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
      recommendedLevel: 10,
      hp: 860,
      atk: 29,
      def: 20,
      spd: 15,
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
      recommendedLevel: 10,
      hp: 910,
      atk: 30,
      def: 21,
      spd: 15,
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
      recommendedLevel: 10,
      hp: 900,
      atk: 29,
      def: 20,
      spd: 16,
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
      recommendedLevel: 10,
      hp: 925,
      atk: 30,
      def: 20,
      spd: 16,
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
      recommendedLevel: 10,
      hp: 935,
      atk: 30,
      def: 20,
      spd: 16,
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
      recommendedLevel: 10,
      hp: 950,
      atk: 31,
      def: 20,
      spd: 17,
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
