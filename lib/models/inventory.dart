// lib/constants/inventory_items.dart
import 'package:flutter/material.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'dart:math';

class InventoryItemDef {
  final String key; // storage key
  final String name;
  final String description;
  final IconData icon;
  final bool stackable;
  final bool isKeyItem;
  final bool canDispose;
  final bool canUse;
  final Future<bool> Function(AlchemonsDatabase db)?
  onUse; // optional use behavior

  const InventoryItemDef({
    required this.key,
    required this.name,
    required this.description,
    required this.icon,
    this.stackable = true,
    this.isKeyItem = false,
    this.canDispose = true,
    this.canUse = true,
    this.onUse,
  });
}

class BossRewardMeta {
  final String traitName;
  final String traitDescription;
  final IconData traitIcon;
  final IconData lootboxIcon;

  const BossRewardMeta({
    required this.traitName,
    required this.traitDescription,
    required this.traitIcon,
    required this.lootboxIcon,
  });
}

class LootBoxDrop {
  final String itemKey;
  final int minQty;
  final int maxQty;
  final double weight;

  const LootBoxDrop({
    required this.itemKey,
    required this.minQty,
    required this.maxQty,
    required this.weight,
  });
}

class SurvivalLootBoxReward {
  final String boxKey;
  final int quantity;

  const SurvivalLootBoxReward({required this.boxKey, required this.quantity});
}

class BossLootKeys {
  static const String _traitPrefix = 'key.boss_trait';
  static const String _lootBoxPrefix = 'lootbox.boss';

  static String traitKeyForElement(String element) =>
      '$_traitPrefix.${element.toLowerCase()}';

  static String lootBoxKeyForElement(String element) =>
      '$_lootBoxPrefix.${element.toLowerCase()}';

  static bool isKeyItemKey(String key) => key.startsWith('key.');

  static final Map<String, BossRewardMeta> elementRewards = {
    'fire': const BossRewardMeta(
      traitName: 'Flame Feather',
      traitDescription:
          'A blazing relic from the Fire Mystic. Unlocks future fire-aligned secrets.',
      traitIcon: Icons.local_fire_department_rounded,
      lootboxIcon: Icons.whatshot_rounded,
    ),
    'water': const BossRewardMeta(
      traitName: 'Leviathan Scale',
      traitDescription:
          'A tide-forged scale from the Water Mystic. Unlocks future oceanic paths.',
      traitIcon: Icons.water_drop_rounded,
      lootboxIcon: Icons.waves_rounded,
    ),
    'earth': const BossRewardMeta(
      traitName: 'Terra Core',
      traitDescription:
          'A dense earth core from the Earth Mystic. Unlocks future terrestrial paths.',
      traitIcon: Icons.terrain_rounded,
      lootboxIcon: Icons.landscape_rounded,
    ),
    'air': const BossRewardMeta(
      traitName: 'Gale Plume',
      traitDescription:
          'A wind-touched plume from the Air Mystic. Unlocks future aerial paths.',
      traitIcon: Icons.air_rounded,
      lootboxIcon: Icons.cloud_rounded,
    ),
    'plant': const BossRewardMeta(
      traitName: 'Verdant Seed',
      traitDescription:
          'A primal seed from the Plant Mystic. Unlocks future growth-aligned paths.',
      traitIcon: Icons.eco_rounded,
      lootboxIcon: Icons.grass_rounded,
    ),
    'ice': const BossRewardMeta(
      traitName: 'Frost Shard',
      traitDescription:
          'A frozen crystal from the Ice Mystic. Unlocks future glacial paths.',
      traitIcon: Icons.ac_unit_rounded,
      lootboxIcon: Icons.severe_cold_rounded,
    ),
    'lightning': const BossRewardMeta(
      traitName: 'Storm Sigil',
      traitDescription:
          'A charged sigil from the Lightning Mystic. Unlocks future storm paths.',
      traitIcon: Icons.flash_on_rounded,
      lootboxIcon: Icons.bolt_rounded,
    ),
    'poison': const BossRewardMeta(
      traitName: 'Venom Fang',
      traitDescription:
          'A toxin-laced fang from the Poison Mystic. Unlocks future venom paths.',
      traitIcon: Icons.science_rounded,
      lootboxIcon: Icons.bug_report_rounded,
    ),
    'steam': const BossRewardMeta(
      traitName: 'Steam Stone',
      traitDescription:
          'A pressurized valve from the Steam Mystic. Unlocks future pressure paths.',
      traitIcon: Icons.device_thermostat_rounded,
      lootboxIcon: Icons.blur_on_rounded,
    ),
    'lava': const BossRewardMeta(
      traitName: 'Magma Heart',
      traitDescription:
          'A molten core from the Lava Mystic. Unlocks future volcanic paths.',
      traitIcon: Icons.public_rounded,
      lootboxIcon: Icons.local_fire_department_rounded,
    ),
    'mud': const BossRewardMeta(
      traitName: 'Mire Totem',
      traitDescription:
          'A swamp-carved totem from the Mud Mystic. Unlocks future mire paths.',
      traitIcon: Icons.forest_rounded,
      lootboxIcon: Icons.terrain_rounded,
    ),
    'dust': const BossRewardMeta(
      traitName: 'Dune Relic',
      traitDescription:
          'A weathered relic from the Dust Mystic. Unlocks future desert paths.',
      traitIcon: Icons.grain_rounded,
      lootboxIcon: Icons.air_rounded,
    ),
    'crystal': const BossRewardMeta(
      traitName: 'Prism Fragment',
      traitDescription:
          'A radiant shard from the Crystal Mystic. Unlocks future prism paths.',
      traitIcon: Icons.diamond_rounded,
      lootboxIcon: Icons.auto_awesome_rounded,
    ),
    'spirit': const BossRewardMeta(
      traitName: 'Wisp Lantern',
      traitDescription:
          'An echo-lit lantern from the Spirit Mystic. Unlocks future spectral paths.',
      traitIcon: Icons.nightlight_round_rounded,
      lootboxIcon: Icons.dark_mode_rounded,
    ),
    'dark': const BossRewardMeta(
      traitName: 'Umbral Crown',
      traitDescription:
          'A shadow crown from the Dark Mystic. Unlocks future umbral paths.',
      traitIcon: Icons.brightness_2_rounded,
      lootboxIcon: Icons.nights_stay_rounded,
    ),
    'light': const BossRewardMeta(
      traitName: 'Radiant Halo',
      traitDescription:
          'A holy halo from the Light Mystic. Unlocks future radiant paths.',
      traitIcon: Icons.wb_sunny_rounded,
      lootboxIcon: Icons.light_mode_rounded,
    ),
    'blood': const BossRewardMeta(
      traitName: 'Crimson Seal',
      traitDescription:
          'A sealed crest from the Blood Mystic. Unlocks future crimson paths.',
      traitIcon: Icons.opacity_rounded,
      lootboxIcon: Icons.inventory_2_rounded,
    ),
  };
}

class LootBoxConfig {
  static const List<LootBoxDrop> bossLootBoxPool = [
    LootBoxDrop(
      itemKey: InvKeys.harvesterStdVolcanic,
      minQty: 1,
      maxQty: 2,
      weight: 2.4,
    ),
    LootBoxDrop(
      itemKey: InvKeys.harvesterStdOceanic,
      minQty: 1,
      maxQty: 2,
      weight: 2.4,
    ),
    LootBoxDrop(
      itemKey: InvKeys.harvesterStdVerdant,
      minQty: 1,
      maxQty: 2,
      weight: 2.4,
    ),
    LootBoxDrop(
      itemKey: InvKeys.harvesterStdEarthen,
      minQty: 1,
      maxQty: 2,
      weight: 2.4,
    ),
    LootBoxDrop(
      itemKey: InvKeys.harvesterStdArcane,
      minQty: 1,
      maxQty: 2,
      weight: 2.2,
    ),
    LootBoxDrop(
      itemKey: InvKeys.staminaPotion,
      minQty: 1,
      maxQty: 2,
      weight: 2.0,
    ),
    LootBoxDrop(
      itemKey: InvKeys.alchemyGlow,
      minQty: 1,
      maxQty: 1,
      weight: 0.8,
    ),
    LootBoxDrop(
      itemKey: InvKeys.alchemyElementalAura,
      minQty: 1,
      maxQty: 1,
      weight: 0.6,
    ),
    LootBoxDrop(
      itemKey: InvKeys.alchemyVolcanicAura,
      minQty: 1,
      maxQty: 1,
      weight: 0.4,
    ),
    LootBoxDrop(
      itemKey: InvKeys.harvesterGuaranteed,
      minQty: 1,
      maxQty: 1,
      weight: 0.35,
    ),
    LootBoxDrop(
      itemKey: InvKeys.bossRefresh,
      minQty: 1,
      maxQty: 1,
      weight: 0.20,
    ),
    // ── Portal keys (rare drops — one random faction key per drop) ───────
    LootBoxDrop(
      itemKey: InvKeys.portalKeyVolcanic,
      minQty: 1,
      maxQty: 1,
      weight: 0.15,
    ),
    LootBoxDrop(
      itemKey: InvKeys.portalKeyOceanic,
      minQty: 1,
      maxQty: 1,
      weight: 0.15,
    ),
    LootBoxDrop(
      itemKey: InvKeys.portalKeyVerdant,
      minQty: 1,
      maxQty: 1,
      weight: 0.15,
    ),
    LootBoxDrop(
      itemKey: InvKeys.portalKeyEarthen,
      minQty: 1,
      maxQty: 1,
      weight: 0.15,
    ),
    LootBoxDrop(
      itemKey: InvKeys.portalKeyArcane,
      minQty: 1,
      maxQty: 1,
      weight: 0.15,
    ),
  ];

  static List<LootBoxDrop> contentsForBox(String boxKey) {
    if (boxKey.startsWith('lootbox.boss.')) return bossLootBoxPool;
    return const [];
  }

  static List<MapEntry<String, int>> rollBossLootBoxDrops(
    String boxKey,
    Random rng,
  ) {
    final pool = contentsForBox(boxKey);
    if (pool.isEmpty) return const [];

    final rolls = rng.nextDouble() < 0.2 ? 2 : 1;
    final rewards = <String, int>{};

    for (int i = 0; i < rolls; i++) {
      final drop = _weightedPick(pool, rng);
      final qty = drop.minQty + rng.nextInt(drop.maxQty - drop.minQty + 1);
      rewards.update(drop.itemKey, (value) => value + qty, ifAbsent: () => qty);
    }

    return rewards.entries.toList();
  }

  static List<MapEntry<String, int>> rollBossLootBoxDropsForQuantity(
    String boxKey,
    int quantity,
    Random rng,
  ) {
    if (quantity <= 0) return const [];

    final merged = <String, int>{};
    for (int i = 0; i < quantity; i++) {
      final opened = rollBossLootBoxDrops(boxKey, rng);
      for (final reward in opened) {
        merged.update(
          reward.key,
          (value) => value + reward.value,
          ifAbsent: () => reward.value,
        );
      }
    }

    return merged.entries.toList();
  }

  static SurvivalLootBoxReward? rollSurvivalLootBoxReward(
    int wave,
    Random rng,
  ) {
    if (wave < 10) return null;

    final keys = BossLootKeys.elementRewards.keys
        .map(BossLootKeys.lootBoxKeyForElement)
        .toList();
    final picked = keys[rng.nextInt(keys.length)];

    if (wave <= 20) {
      return SurvivalLootBoxReward(boxKey: picked, quantity: 1);
    }
    if (wave >= 50) {
      return SurvivalLootBoxReward(boxKey: picked, quantity: 2);
    }
    if (wave >= 35) {
      return rng.nextDouble() < 0.75
          ? SurvivalLootBoxReward(boxKey: picked, quantity: 1)
          : null;
    }
    if (wave > 20) {
      return rng.nextDouble() < 0.5
          ? SurvivalLootBoxReward(boxKey: picked, quantity: 1)
          : null;
    }
    return null;
  }

  static Map<String, int> rollBossRematchBonusCurrency(
    int bossOrder,
    Random rng,
  ) {
    final difficulty = bossOrder.clamp(1, 17);
    final silver = 150 + (difficulty * 25) + rng.nextInt(151);

    var gold = 0;
    final goldChance = 0.02 + (difficulty * 0.004); // 2.4% .. 8.8%
    if (rng.nextDouble() <= goldChance) {
      gold = 1;
    }

    final rewards = <String, int>{'silver': silver};
    if (gold > 0) rewards['gold'] = gold;
    return rewards;
  }

  static Map<String, int> rollSurvivalBonusCurrency(int wave, Random rng) {
    final difficulty = wave.clamp(1, 60);
    final silver = 75 + (difficulty * 12) + rng.nextInt(101);

    var gold = 0;
    final goldChance = wave >= 40
        ? 0.08
        : wave >= 25
        ? 0.04
        : 0.01;
    if (rng.nextDouble() <= goldChance) {
      gold = 1;
      if (wave >= 55 && rng.nextDouble() < 0.05) {
        gold += 1;
      }
    }

    final rewards = <String, int>{'silver': silver};
    if (gold > 0) rewards['gold'] = gold;
    return rewards;
  }

  /// Returns a random portal key item key guaranteed at wave 50+, null otherwise.
  static String? rollSurvivalBonusPortalKey(int wave, Random rng) {
    if (wave < 50) return null;
    final keys = [
      InvKeys.portalKeyVolcanic,
      InvKeys.portalKeyOceanic,
      InvKeys.portalKeyVerdant,
      InvKeys.portalKeyEarthen,
      InvKeys.portalKeyArcane,
    ];
    return keys[rng.nextInt(keys.length)];
  }

  static LootBoxDrop _weightedPick(List<LootBoxDrop> pool, Random rng) {
    final total = pool.fold<double>(0, (sum, drop) => sum + drop.weight);
    var ticket = rng.nextDouble() * total;

    for (final drop in pool) {
      ticket -= drop.weight;
      if (ticket <= 0) return drop;
    }
    return pool.last;
  }
}

// Keys
class InvKeys {
  static const instantHatch = 'item.instant_hatch';
  static const harvesterStdVolcanic = 'item.harvest_std_volcanic';
  static const harvesterStdOceanic = 'item.harvest_std_oceanic';
  static const harvesterStdVerdant = 'item.harvest_std_verdant';
  static const harvesterStdEarthen = 'item.harvest_std_earthen';
  static const harvesterStdArcane = 'item.harvest_std_arcane';
  static const harvesterGuaranteed = 'item.harvest_guaranteed';
  static const alchemyGlow = 'alchemy.glow';
  static const alchemyElementalAura = 'alchemy.elemental_aura';
  static const alchemyVolcanicAura = 'alchemy.volcanic_aura';
  static const alchemyVoidRift = 'alchemy.void_rift';
  static const alchemyPrismaticCascade = 'alchemy.prismatic_cascade';
  static const alchemyRitualGold = 'alchemy.ritual_gold';
  static const alchemyBeautyRadiance = 'alchemy.beauty_radiance';
  static const alchemySpeedFlux = 'alchemy.speed_flux';
  static const alchemyStrengthForge = 'alchemy.strength_forge';
  static const alchemyIntelligenceHalo = 'alchemy.intelligence_halo';
  static const staminaPotion = 'item.stamina_potion';
  static const bossRefresh = 'item.boss_refresh';
  static const bossSummon = 'item.boss_summon';
  static const elementalCreator = 'item.elemental_creator';

  // ── Portal Keys (one per rift faction) ────────────────────────────────────
  static const portalKeyVolcanic = 'item.portal_key.volcanic';
  static const portalKeyOceanic = 'item.portal_key.oceanic';
  static const portalKeyVerdant = 'item.portal_key.verdant';
  static const portalKeyEarthen = 'item.portal_key.earthen';
  static const portalKeyArcane = 'item.portal_key.arcane';

  // ── Cosmic Alchemy ──────────────────────────────────────────────────────
  static const cosmicShip = 'item.cosmic_ship';
  static const homePlanetSlots = 'item.home_planet_slots';

  /// Returns the portal key InvKey for a given rift faction name (lowercase).
  static String portalKeyForFaction(String factionName) =>
      'item.portal_key.${factionName.toLowerCase()}';
}

const Set<String> kHiddenInventoryUnlockKeys = {
  InvKeys.elementalCreator,
  InvKeys.cosmicShip,
};

bool shouldHideInventoryItem(String key) =>
    kHiddenInventoryUnlockKeys.contains(key);

Map<String, InventoryItemDef> buildInventoryRegistry(AlchemonsDatabase db) {
  final registry = <String, InventoryItemDef>{
    InvKeys.instantHatch: InventoryItemDef(
      key: InvKeys.instantHatch,
      name: 'Instant Fusion Extractor',
      description: 'Complete one active fusion vial instantly.',
      icon: Icons.access_alarms,
      canUse: false,
    ),
    InvKeys.harvesterStdVolcanic: InventoryItemDef(
      key: InvKeys.harvesterStdVolcanic,
      name: 'Wild Harvester – Volcanic',
      description: 'Chance-based capture device.',
      icon: Icons.local_fire_department_rounded,
      canUse: false,
    ),
    InvKeys.harvesterStdOceanic: InventoryItemDef(
      key: InvKeys.harvesterStdOceanic,
      name: 'Wild Harvester – Oceanic',
      description: 'Chance-based capture device.',
      icon: Icons.water_rounded,
      canUse: false,
    ),
    InvKeys.harvesterStdVerdant: InventoryItemDef(
      key: InvKeys.harvesterStdVerdant,
      name: 'Wild Harvester – Verdant',
      description: 'Chance-based capture device.',
      icon: Icons.eco_rounded,
      canUse: false,
    ),
    InvKeys.harvesterStdEarthen: InventoryItemDef(
      key: InvKeys.harvesterStdEarthen,
      name: 'Wild Harvester – Earthen',
      description: 'Chance-based capture device.',
      icon: Icons.terrain_rounded,
      canUse: false,
    ),
    InvKeys.harvesterStdArcane: InventoryItemDef(
      key: InvKeys.harvesterStdArcane,
      name: 'Wild Harvester – Arcane',
      description: 'Chance-based capture device.',
      icon: Icons.auto_awesome_rounded,
      canUse: false,
    ),
    InvKeys.harvesterGuaranteed: InventoryItemDef(
      key: InvKeys.harvesterGuaranteed,
      name: 'Stabilized Harvester',
      description: 'Guaranteed capture device.',
      icon: Icons.shield_rounded,
      canUse: false,
    ),
    // Alchemy Effects
    InvKeys.alchemyGlow: InventoryItemDef(
      key: InvKeys.alchemyGlow,
      name: 'Alchemical Resonance',
      description: 'Apply an ethereal glow effect to one of your Alchemons.',
      icon: Icons.auto_awesome_rounded,
    ),
    InvKeys.alchemyElementalAura: InventoryItemDef(
      key: InvKeys.alchemyElementalAura,
      name: 'Elemental Aura',
      description:
          'Apply orbiting elemental particles to one of your Alchemons.',
      icon: Icons.bubble_chart_rounded,
    ),
    InvKeys.alchemyVolcanicAura: InventoryItemDef(
      key: InvKeys.alchemyVolcanicAura,
      name: 'Volcanic Aura',
      description:
          'Apply a fiery volcanic aura to one of your Volcanic Alchemons.',
      icon: Icons.local_fire_department_rounded,
    ),
    InvKeys.alchemyVoidRift: InventoryItemDef(
      key: InvKeys.alchemyVoidRift,
      name: 'Void Rift',
      description:
          'Tear open a swirling rift of dark void energy around your Alchemon.',
      icon: Icons.blur_circular_rounded,
    ),
    InvKeys.alchemyPrismaticCascade: InventoryItemDef(
      key: InvKeys.alchemyPrismaticCascade,
      name: 'Prismatic Cascade',
      description:
          'Bathe your Alchemon in a full-spectrum prismatic light cascade — the rarest cosmetic in existence.',
      icon: Icons.lens_blur_rounded,
    ),
    InvKeys.alchemyRitualGold: InventoryItemDef(
      key: InvKeys.alchemyRitualGold,
      name: 'Golden Rite',
      description:
          'A luminous ritual circle of gold and ash, unlocked by completing the Pureblood Rite.',
      icon: Icons.auto_fix_high_rounded,
    ),
    InvKeys.alchemyBeautyRadiance: InventoryItemDef(
      key: InvKeys.alchemyBeautyRadiance,
      name: 'Beauty Radiance',
      description:
          'Contest reward effect: a stage-lit radiance that amplifies charm and presence.',
      icon: Icons.auto_awesome_rounded,
    ),
    InvKeys.alchemySpeedFlux: InventoryItemDef(
      key: InvKeys.alchemySpeedFlux,
      name: 'Speed Flux',
      description:
          'Contest reward effect: a kinetic flux aura that conveys relentless acceleration.',
      icon: Icons.bolt_rounded,
    ),
    InvKeys.alchemyStrengthForge: InventoryItemDef(
      key: InvKeys.alchemyStrengthForge,
      name: 'Strength Forge',
      description:
          'Contest reward effect: a forged pressure aura projecting raw force and impact.',
      icon: Icons.fitness_center_rounded,
    ),
    InvKeys.alchemyIntelligenceHalo: InventoryItemDef(
      key: InvKeys.alchemyIntelligenceHalo,
      name: 'Intelligence Halo',
      description:
          'Contest reward effect: a cerebral halo of void-lit focus and adaptive thought.',
      icon: Icons.psychology_rounded,
    ),
    InvKeys.staminaPotion: InventoryItemDef(
      key: InvKeys.staminaPotion,
      name: 'Stamina Elixir',
      description: 'Fully restores an Alchemon\'s stamina.',
      icon: Icons.local_drink_rounded,
    ),
    InvKeys.bossRefresh: InventoryItemDef(
      key: InvKeys.bossRefresh,
      name: 'Boss Summon Token',
      description:
          'Resets your daily boss rematch, allowing an additional attempt.',
      icon: Icons.local_drink_rounded,
      canUse: false,
    ),
    InvKeys.bossSummon: InventoryItemDef(
      key: InvKeys.bossSummon,
      name: 'Boss Summon',
      description:
          'Instantly challenges a defeated boss to a rematch, bypassing the daily cooldown.',
      icon: Icons.whatshot_rounded,
      canUse: false,
    ),

    // ── Portal Keys ─────────────────────────────────────────────────────────
    InvKeys.portalKeyVolcanic: InventoryItemDef(
      key: InvKeys.portalKeyVolcanic,
      name: 'Volcanic Portal Key',
      description: 'Grants entry to a Volcanic Rift. Consumed on entry.',
      icon: Icons.local_fire_department_rounded,
      stackable: true,
      canUse: false,
    ),
    InvKeys.portalKeyOceanic: InventoryItemDef(
      key: InvKeys.portalKeyOceanic,
      name: 'Oceanic Portal Key',
      description: 'Grants entry to an Oceanic Rift. Consumed on entry.',
      icon: Icons.water_rounded,
      stackable: true,
      canUse: false,
    ),
    InvKeys.portalKeyVerdant: InventoryItemDef(
      key: InvKeys.portalKeyVerdant,
      name: 'Verdant Portal Key',
      description: 'Grants entry to a Verdant Rift. Consumed on entry.',
      icon: Icons.eco_rounded,
      stackable: true,
      canUse: false,
    ),
    InvKeys.portalKeyEarthen: InventoryItemDef(
      key: InvKeys.portalKeyEarthen,
      name: 'Earthen Portal Key',
      description: 'Grants entry to an Earthen Rift. Consumed on entry.',
      icon: Icons.terrain_rounded,
      stackable: true,
      canUse: false,
    ),
    InvKeys.portalKeyArcane: InventoryItemDef(
      key: InvKeys.portalKeyArcane,
      name: 'Arcane Portal Key',
      description: 'Grants entry to an Arcane Rift. Consumed on entry.',
      icon: Icons.auto_awesome_rounded,
      stackable: true,
      canUse: false,
    ),
  };

  for (final entry in BossLootKeys.elementRewards.entries) {
    final element = entry.key;
    final meta = entry.value;

    registry[BossLootKeys.traitKeyForElement(element)] = InventoryItemDef(
      key: BossLootKeys.traitKeyForElement(element),
      name: meta.traitName,
      description: meta.traitDescription,
      icon: meta.traitIcon,
      stackable: false,
      isKeyItem: true,
      canDispose: false,
      canUse: false,
    );

    registry[BossLootKeys.lootBoxKeyForElement(element)] = InventoryItemDef(
      key: BossLootKeys.lootBoxKeyForElement(element),
      name:
          '${element[0].toUpperCase()}${element.substring(1)} Mystic Loot Box',
      description:
          'Late-game reward chest from a powered-up ${element.toUpperCase()} Mystic rematch. '
          'Contains survival items like Harvesters, Stamina Elixirs, Alchemy effects, and rare Stabilized Harvesters.',
      icon: meta.lootboxIcon,
      stackable: true,
      canUse: false,
    );
  }

  // ── Cosmic Alchemy items ──
  registry[InvKeys.homePlanetSlots] = InventoryItemDef(
    key: InvKeys.homePlanetSlots,
    name: 'Home Planet Slots',
    description: 'Additional Alchemon placement slots for your Home Planet.',
    icon: Icons.add_circle_outline_rounded,
    stackable: true,
    canUse: false,
  );

  return registry;
}
