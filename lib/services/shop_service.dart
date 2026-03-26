// lib/services/shop_service.dart
import 'dart:math' as math;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/widgets/animations/sprite_effects/alchemy_glow.dart';
import 'package:alchemons/widgets/animations/sprite_effects/beauty_radiance.dart';
import 'package:alchemons/widgets/animations/sprite_effects/intelligence_halo.dart';
import 'package:alchemons/widgets/animations/sprite_effects/orbiting_particles.dart';
import 'package:alchemons/widgets/animations/sprite_effects/prismatic_cascade.dart';
import 'package:alchemons/widgets/animations/sprite_effects/ritual_gold.dart';
import 'package:alchemons/widgets/animations/sprite_effects/speed_flux.dart';
import 'package:alchemons/widgets/animations/sprite_effects/strength_forge.dart';
import 'package:alchemons/utils/effect_size.dart';
import 'package:alchemons/widgets/animations/sprite_effects/void_rift.dart';
import 'package:alchemons/widgets/animations/sprite_effects/volcanic_aura.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/database/alchemons_db.dart';

enum PurchaseLimit { once, daily, unlimited }

class ShopOffer {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Map<String, int> cost; // currency/resource -> amount (per unit)
  final Map<String, dynamic> reward; // what you get (per unit)
  final String rewardType; // 'currency', 'resources', 'boost', 'bundle'
  final PurchaseLimit limit;
  final String? inventoryKey;
  final String? assetName;
  final Color? imageColor;
  final Color? iconColor;

  const ShopOffer({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.cost,
    required this.reward,
    required this.rewardType,
    required this.limit,
    this.inventoryKey,
    this.assetName,
    this.imageColor,
    this.iconColor,
  });
}

class ShopService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  final ConstellationEffectsService _constellations;
  final FactionService _factions;

  // Keep false in normal gameplay; set true only for temporary local debug.
  static const bool _debugUnlockContestEffectsInShop = false;

  static const beautyContestEffectOfferId = 'effects.beauty_radiance';
  static const speedContestEffectOfferId = 'effects.speed_flux';
  static const strengthContestEffectOfferId = 'effects.strength_forge';
  static const intelligenceContestEffectOfferId = 'effects.intelligence_halo';
  static const ritualGoldEffectOfferId = 'effects.ritual_gold';
  static const elementalCreatorOfferId = 'unlock.elemental_creator';

  static const Map<String, String> _contestEffectUnlockSettingByOfferId = {
    beautyContestEffectOfferId: 'shop_unlock.effect.beauty_radiance',
    speedContestEffectOfferId: 'shop_unlock.effect.speed_flux',
    strengthContestEffectOfferId: 'shop_unlock.effect.strength_forge',
    intelligenceContestEffectOfferId: 'shop_unlock.effect.intelligence_halo',
    ritualGoldEffectOfferId: 'shop_unlock.effect.ritual_gold',
  };

  // Track purchases
  final Map<String, int> _purchaseCounts = {}; // offerId -> count
  final Map<String, DateTime> _lastPurchaseTime = {}; // offerId -> last time
  final Set<String> _unlockedContestEffectOfferIds = <String>{};

  ShopService(this._db, this._constellations, this._factions) {
    _loadPurchaseHistory();
    _loadInventoryCache();
    _loadContestEffectUnlocks();
  }

  /// Faction-based discount for standard wild harvesters.
  /// Each faction gets 90% off *its own* biome harvester (pays 10% of base).
  double _harvesterFactionMultiplier(ShopOffer offer) {
    // Get current faction (adjust getter name to match your FactionService)
    final faction = _factions.current; // e.g. FactionId.volcanic

    switch (offer.id) {
      case 'device.harvest.std.volcanic':
        return faction == FactionId.volcanic ? 0.1 : 1.0;
      case 'device.harvest.std.oceanic':
        return faction == FactionId.oceanic ? 0.1 : 1.0;
      case 'device.harvest.std.verdant':
        return faction == FactionId.verdant ? 0.1 : 1.0;
      case 'device.harvest.std.earthen':
        return faction == FactionId.earthen ? 0.1 : 1.0;

      // No matching faction for arcane in the enum you showed earlier,
      // so we leave the Arcane harvester at full price for everyone.
      default:
        return 1.0;
    }
  }

  static Widget? getAlchemyEffectPreview(
    String inventoryKey, {
    double size = 32.0,
  }) {
    switch (inventoryKey) {
      case InvKeys.alchemyGlow:
        return AlchemyGlow(size: effectSizeFromWidgetSize(size));

      case InvKeys.alchemyElementalAura:
        final widgetEff = effectSizeFromWidgetSize(size);
        return SizedBox.square(
          dimension: size,
          child: ElementalAura(
            size: widgetEff,
            element: 'Volcanic', // or whatever element you want as default
          ),
        );

      case InvKeys.alchemyVolcanicAura:
        return SizedBox.square(
          dimension: size,
          child: VolcanicAura(size: effectSizeFromWidgetSize(size)),
        );

      case InvKeys.alchemyVoidRift:
        final widgetEff = effectSizeFromWidgetSize(size);
        return SizedBox.square(
          dimension: size,
          child: VoidRift(size: widgetEff * 0.8),
        );

      case InvKeys.alchemyPrismaticCascade:
        return SizedBox.square(
          dimension: size,
          child: PrismaticCascade(size: effectSizeFromWidgetSize(size)),
        );
      case InvKeys.alchemyRitualGold:
        return SizedBox.square(
          dimension: size,
          child: RitualGold(size: effectSizeFromWidgetSize(size)),
        );
      case InvKeys.alchemyBeautyRadiance:
        return SizedBox.square(
          dimension: size,
          child: BeautyRadiance(size: effectSizeFromWidgetSize(size)),
        );
      case InvKeys.alchemySpeedFlux:
        return SizedBox.square(
          dimension: size,
          child: SpeedFlux(size: effectSizeFromWidgetSize(size)),
        );
      case InvKeys.alchemyStrengthForge:
        return SizedBox.square(
          dimension: size,
          child: StrengthForge(size: effectSizeFromWidgetSize(size)),
        );
      case InvKeys.alchemyIntelligenceHalo:
        return SizedBox.square(
          dimension: size,
          child: IntelligenceHalo(size: effectSizeFromWidgetSize(size)),
        );

      default:
        return null;
    }
  }

  Future<void> _loadContestEffectUnlocks() async {
    _unlockedContestEffectOfferIds.clear();
    for (final entry in _contestEffectUnlockSettingByOfferId.entries) {
      final unlocked = await _db.settingsDao.getSetting(entry.value) == '1';
      if (unlocked) {
        _unlockedContestEffectOfferIds.add(entry.key);
      }
    }
    notifyListeners();
  }

  bool _isContestEffectOfferUnlocked(String offerId) {
    if (_debugUnlockContestEffectsInShop) return true;
    if (!_contestEffectUnlockSettingByOfferId.containsKey(offerId)) {
      return true;
    }
    return _unlockedContestEffectOfferIds.contains(offerId);
  }

  List<ShopOffer> getAlchemyEffectOffers() {
    return allOffers
        .where((o) => o.id.startsWith('effects.'))
        .where((o) => _isContestEffectOfferUnlocked(o.id))
        .toList();
  }

  Future<String?> unlockContestEffectOffer(
    String offerId, {
    int freeQty = 1,
  }) async {
    final unlockSetting = _contestEffectUnlockSettingByOfferId[offerId];
    if (unlockSetting == null) return null;

    final alreadyUnlocked =
        _unlockedContestEffectOfferIds.contains(offerId) ||
        (await _db.settingsDao.getSetting(unlockSetting) == '1');
    if (alreadyUnlocked) {
      _unlockedContestEffectOfferIds.add(offerId);
      return null;
    }

    await _db.settingsDao.setSetting(unlockSetting, '1');
    _unlockedContestEffectOfferIds.add(offerId);

    final offer = _resolveOfferById(offerId);
    if (offer?.inventoryKey != null && freeQty > 0) {
      await _db.inventoryDao.addItemQty(offer!.inventoryKey!, freeQty);
      _inventoryCache.update(
        offer.inventoryKey!,
        (v) => v + freeQty,
        ifAbsent: () => freeQty,
      );
    }
    notifyListeners();
    return offer?.name;
  }

  static const Map<int, ElementalGroup> _weekday2Group = {
    DateTime.monday: ElementalGroup.volcanic,
    DateTime.tuesday: ElementalGroup.oceanic,
    DateTime.wednesday: ElementalGroup.verdant,
    DateTime.thursday: ElementalGroup.earthen,
    // Saturday and Sunday will be handled randomly
  };

  // ==== Config for exchange & quantity ====
  static const int kSilverPerGold = 100; // informational
  static const double kFeePct = 0.05; // informational

  bool allowsQuantity(ShopOffer o) {
    return o.limit == PurchaseLimit.unlimited;
  }

  ShopOffer? getActiveDailyVialOffer() {
    final now = DateTime.now();
    final weekday = now.weekday;
    final rarity = VialRarity.common;
    const cost = {'silver': 100};

    late final ElementalGroup group;
    final bool isWeekend =
        (weekday == DateTime.saturday || weekday == DateTime.sunday);

    if (isWeekend) {
      // get random from here
      _weekday2Group.values.toList();
      final groups = _weekday2Group.values.toList();
      final randIndex = math.Random(now.day).nextInt(groups.length);
      group = groups[randIndex];
    } else {
      group = _weekday2Group[weekday] ?? ElementalGroup.volcanic;
    }

    final vialName = '${group.displayName} Vial';
    final offerId = 'vial.daily.${rarity.name}.${group.name}';

    // IMPORTANT: This key must match EXACTLY what inventory_dao.addVial creates
    // The format should be: 'vial.{group}.{rarity}.{name}'
    final inventoryKey = 'vial.${group.name}.${rarity.name}.$vialName';

    return ShopOffer(
      id: offerId,
      name: 'Daily Vial - ${group.displayName}',
      description:
          'A ${rarity.grade} extraction vial. Today\'s element: ${group.displayName}.',
      icon: Icons.science_rounded,
      assetName: null, // You can add specific vial images later
      cost: cost,
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.daily,
      inventoryKey: inventoryKey,
    );
  }

  // ==== Offers (existing + new) ====
  static final List<ShopOffer> allOffers = [
    // ── Cosmic Alchemy ──
    ShopOffer(
      id: 'cosmic.ship',
      name: 'Cosmic Ship',
      description:
          'Unlocks the Cosmic Alchemy Explorer. Pilot through space and summon creatures!',
      icon: Icons.rocket_launch_rounded,
      cost: const {'silver': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      inventoryKey: InvKeys.cosmicShip,
      assetName: 'assets/images/ui/cosmicship.png',
      iconColor: const Color(0xFF00E5FF),
    ),
    ShopOffer(
      id: 'boost.instant_stamina_potion',
      name: 'Stamina Elixir',
      description:
          'Fully restores an Alchemon\'s stamina so it can battle, harvest, or breed again immediately.',
      icon: Icons.local_drink_rounded,
      cost: const {'silver': 2500}, // tweak cost as desired
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.staminaPotion,
      assetName:
          'assets/images/ui/instantstaminaicon.png', // optional, if you add one
    ),
    ShopOffer(
      id: 'boost.instant_boss_refresh',
      name: 'Boss Summon',
      description:
          'Resets your daily boss rematch limit for one boss, allowing you to challenge the Mystic Altar again.',
      icon: Icons.local_drink_rounded,
      cost: const {'gold': 1},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.bossRefresh,
      assetName: 'assets/images/ui/boss-summon.png',
    ),
    ShopOffer(
      id: elementalCreatorOfferId,
      name: 'Elemental Essence Creator',
      description:
          'Consume Alchemons into elemental material to enhance other Alchemons.',
      icon: Icons.auto_fix_high_rounded,
      cost: const {
        'silver': 5000,
        'res_volcanic': 200,
        'res_oceanic': 200,
        'res_verdant': 200,
        'res_earthen': 200,
        'res_arcane': 200,
      },
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      inventoryKey: InvKeys.elementalCreator,
      assetName: 'assets/images/ui/enhanceicon.png',
    ),
    // --- NEW: Devices (standard per element) ---
    ShopOffer(
      id: 'device.harvest.std.volcanic',
      name: 'Wild Harvester – Volcanic',
      description:
          'Capture wild Volcanic-type Alchemons in the wilderness or cosmic rifts. Chance-based capture.',
      icon: Icons.local_fire_department_rounded,
      cost: const {'silver': 999, 'res_volcanic': 100},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdVolcanic, // NEW
      assetName: 'assets/images/ui/volcanicharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.oceanic',
      name: 'Wild Harvester – Oceanic',
      description:
          'Capture wild Oceanic-type Alchemons in the wilderness or cosmic rifts. Chance-based capture.',
      icon: Icons.water_rounded,
      cost: const {'silver': 999, 'res_oceanic': 100},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdOceanic, // NEW
      assetName: 'assets/images/ui/oceanicharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.verdant',
      name: 'Wild Harvester – Verdant',
      description:
          'Capture wild Verdant-type Alchemons in the wilderness or cosmic rifts. Chance-based capture.',
      icon: Icons.eco_rounded,
      cost: const {'silver': 999, 'res_verdant': 100},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdVerdant, // NEW
      assetName: 'assets/images/ui/verdantharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.earthen',
      name: 'Wild Harvester – Earthen',
      description:
          'Capture wild Earthen-type Alchemons in the wilderness or cosmic rifts. Chance-based capture.',
      icon: Icons.terrain_rounded,
      cost: const {'silver': 999, 'res_earthen': 100},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdEarthen, // NEW
      assetName: 'assets/images/ui/earthenharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.arcane',
      name: 'Wild Harvester – Arcane',
      description:
          'Capture wild Arcane-type Alchemons in the wilderness or cosmic rifts. Chance-based capture.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'silver': 999, 'res_arcane': 500},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdArcane, // NEW
      assetName: 'assets/images/ui/arcaneharvester.png',
    ),

    // Guaranteed device
    ShopOffer(
      id: 'device.harvest.guaranteed',
      name: 'Stabilized Harvester',
      description:
          'A premium harvester that guarantees capture of any wild Alchemon regardless of element. Works in the wilderness and cosmic rifts.',
      icon: Icons.shield_rounded,
      cost: const {'gold': 1},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterGuaranteed, // NEW
      assetName: 'assets/images/ui/universalharvest.png',
    ),

    // --- NEW: Eggs & Packs ---
    ShopOffer(
      id: 'boost.instant_hatch',
      name: 'Instant Fusion Extractor',
      description:
          'Instantly completes one active cultivation in your Alchemy Chamber. Skip the wait and extract your Alchemon now.',
      assetName: 'assets/images/ui/instantbreedicon.png',
      icon: Icons.access_alarms,
      cost: const {'gold': 15},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.instantHatch, // NEW
    ),

    // --- NEW: Currency exchange units (5% fee baked in) ---
    ShopOffer(
      id: 'fx.silver_to_gold.unit',
      name: 'Silver → Gold (10g)',
      description:
          'Exchange 500,000 silver for 10 gold. Use gold for premium items, portal keys, and rare cosmetics.',
      icon: Icons.currency_exchange_rounded,
      iconColor: const Color(0xFFF59E0B),
      cost: const {'silver': 500000},
      reward: const {'gold': 10},
      rewardType: 'currency',
      limit: PurchaseLimit.unlimited,
    ),
    ShopOffer(
      id: 'fx.gold_to_silver.unit',
      name: 'Gold → Silver (1,000s)',
      description:
          'Exchange 1 gold for 1,000 silver. Stock up on silver for harvesters, elixirs, and daily essentials.',
      icon: Icons.currency_exchange_rounded,
      cost: const {'gold': 1},
      reward: const {'silver': 1000},
      rewardType: 'currency',
      limit: PurchaseLimit.unlimited,
    ),

    // === SPECIAL UNLOCK: Fusion/Incubator Slots (single stepping card) ===
    ShopOffer(
      id: 'unlock.fusion_slot.1',
      name: 'Fusion Slot',
      description:
          'Unlock an additional Alchemy Chamber slot to cultivate more Alchemons simultaneously.',
      icon: Icons.biotech_rounded,
      cost: const {'silver': 1000}, // 1st purchase: 1,000 silver
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.2',
      name: 'Fusion Slot (Step 2)',
      description:
          'Unlock an additional Alchemy Chamber slot to cultivate more Alchemons simultaneously.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 10}, // 2nd purchase: 10 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.3',
      name: 'Fusion Slot (Step 3)',
      description:
          'Unlock an additional Alchemy Chamber slot to cultivate more Alchemons simultaneously.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 50}, // 3rd purchase: 50 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.4',
      name: 'Fusion Slot (Step 4)',
      description:
          'Unlock an additional Alchemy Chamber slot to cultivate more Alchemons simultaneously.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 250}, // 4th purchase: 250 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.5',
      name: 'Fusion Slot (Step 5)',
      description:
          'Unlock an additional Alchemy Chamber slot to cultivate more Alchemons simultaneously.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 500}, // 5th purchase: 500 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'boost.faction_change',
      name: 'Change Faction',
      description:
          'Switch your allegiance to a different elemental faction. Affects harvester discounts and resource bonuses.',
      icon: Icons.flag_rounded,
      cost: const {'gold': 500},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.daily,
      assetName: 'assets/images/ui/factionorb.png',
    ),

    // Alchemy Effects Section
    ShopOffer(
      id: 'effects.alchemy_glow',
      name: 'Alchemical Resonance',
      description:
          'Wraps your Alchemon in an ethereal glow. A subtle shimmer that pulses with alchemical energy.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'gold': 10},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyGlow,
      assetName: 'assets/images/ui/alchemyglow.png', // You'll need to add this
    ),
    ShopOffer(
      id: 'effects.elemental_aura',
      name: 'Elemental Aura',
      description:
          'Surrounds your Alchemon with orbiting elemental particles that match its type. Apply from the creature detail screen.',
      icon: Icons.bubble_chart_rounded,
      cost: const {'gold': 10},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyElementalAura,
      assetName: 'assets/images/ui/elementalaura.png',
    ),
    ShopOffer(
      id: 'effects.volcanic_aura',
      name: 'Volcanic Aura',
      description:
          'Engulfs your Alchemon in a blazing volcanic aura with rising embers and heat distortion.',
      icon: Icons.local_fire_department_rounded,
      cost: const {'gold': 10},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyVolcanicAura,
      assetName: 'assets/images/ui/volcanicaura.png',
    ),
    ShopOffer(
      id: 'effects.void_rift',
      name: 'Void Rift',
      description:
          'Tear open a swirling void of dark energy around your Alchemon.',
      icon: Icons.blur_circular_rounded,
      iconColor: const Color(0xFFBB00FF),
      cost: const {'gold': 15},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyVoidRift,
    ),
    ShopOffer(
      id: 'effects.prismatic_cascade',
      name: 'Prismatic Cascade',
      description:
          'Full-spectrum prismatic light cascade — the rarest cosmetic in existence.',
      icon: Icons.lens_blur_rounded,
      iconColor: const Color(0xFFFF80FF),
      cost: const {'gold': 100},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyPrismaticCascade,
    ),
    ShopOffer(
      id: ritualGoldEffectOfferId,
      name: 'Golden Rite',
      description:
          'Pureblood Rite completion effect. Projects a gold ritual chamber behind your Alchemon.',
      icon: Icons.auto_fix_high_rounded,
      iconColor: const Color(0xFFE5B74E),
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyRitualGold,
    ),
    ShopOffer(
      id: beautyContestEffectOfferId,
      name: 'Beauty Radiance',
      description:
          'Contest mastery effect. Unlocked by clearing Beauty Lv5. Bathes your Alchemon in a stage-lit radiance.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'gold': 40},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyBeautyRadiance,
    ),
    ShopOffer(
      id: speedContestEffectOfferId,
      name: 'Speed Flux',
      description:
          'Contest mastery effect. Unlocked by clearing Speed Lv5. Surrounds your Alchemon with kinetic velocity trails.',
      icon: Icons.bolt_rounded,
      cost: const {'gold': 40},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemySpeedFlux,
    ),
    ShopOffer(
      id: strengthContestEffectOfferId,
      name: 'Strength Forge',
      description:
          'Contest mastery effect. Unlocked by clearing Strength Lv5. Projects a forged pressure aura of raw power.',
      icon: Icons.fitness_center_rounded,
      cost: const {'gold': 40},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyStrengthForge,
    ),
    ShopOffer(
      id: intelligenceContestEffectOfferId,
      name: 'Intelligence Halo',
      description:
          'Contest mastery effect. Unlocked by clearing Intelligence Lv5. Wraps your Alchemon in a cerebral halo.',
      icon: Icons.psychology_rounded,
      cost: const {'gold': 40},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyIntelligenceHalo,
    ),

    // ── Portal Keys ──────────────────────────────────────────────────────────
    ShopOffer(
      id: 'key.portal.volcanic',
      name: 'Volcanic Portal Key',
      description:
          'Opens a Volcanic Rift portal in cosmic space. Battle and capture rare Volcanic Alchemons inside. Consumed on entry.',
      icon: Icons.vpn_key_rounded,
      iconColor: const Color(0xFFFF5722),
      assetName: 'assets/images/ui/volcanickey.png',
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.portalKeyVolcanic,
    ),
    ShopOffer(
      id: 'key.portal.oceanic',
      name: 'Oceanic Portal Key',
      description:
          'Opens an Oceanic Rift portal in cosmic space. Battle and capture rare Oceanic Alchemons inside. Consumed on entry.',
      icon: Icons.vpn_key_rounded,
      iconColor: const Color(0xFF64B5F6),
      assetName: 'assets/images/ui/oceanickey.png',
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.portalKeyOceanic,
    ),
    ShopOffer(
      id: 'key.portal.verdant',
      name: 'Verdant Portal Key',
      description:
          'Opens a Verdant Rift portal in cosmic space. Battle and capture rare Verdant Alchemons inside. Consumed on entry.',
      icon: Icons.vpn_key_rounded,
      iconColor: const Color(0xFF66BB6A),
      assetName: 'assets/images/ui/verdantkey.png',
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.portalKeyVerdant,
    ),
    ShopOffer(
      id: 'key.portal.earthen',
      name: 'Earthen Portal Key',
      description:
          'Opens an Earthen Rift portal in cosmic space. Battle and capture rare Earthen Alchemons inside. Consumed on entry.',
      icon: Icons.vpn_key_rounded,
      iconColor: const Color(0xFF8D6E63),
      assetName: 'assets/images/ui/earthenkey.png',
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.portalKeyEarthen,
    ),
    ShopOffer(
      id: 'key.portal.arcane',
      name: 'Arcane Portal Key',
      description:
          'Opens an Arcane Rift portal in cosmic space. Battle and capture rare Arcane Alchemons inside. Consumed on entry.',
      icon: Icons.vpn_key_rounded,
      iconColor: const Color(0xFFCE93D8),
      assetName: 'assets/images/ui/arcanekey.png',
      cost: const {'gold': 5},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.portalKeyArcane,
    ),

    // ── Survival Orb Base Skins ──────────────────────────────────────────────
    ShopOffer(
      id: 'survival.orb.voidforge',
      name: 'Voidforge Core',
      description:
          'Forged in the Void — an orb crackling with dark energy runes.',
      icon: Icons.nightlight_round,
      iconColor: const Color(0xFFBB00FF),
      cost: const {'gold': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.celestial',
      name: 'Celestial Beacon',
      description: 'A radiant sphere of starlight — pulsing with cosmic power.',
      icon: Icons.auto_awesome_rounded,
      iconColor: const Color(0xFFFFD700),
      cost: const {'gold': 1},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.infernal',
      name: 'Infernal Engine',
      description: 'Molten iron and dragonfire — enemies burn near the orb.',
      icon: Icons.local_fire_department_rounded,
      iconColor: const Color(0xFFFF4500),
      cost: const {'gold': 1},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.frozen',
      name: 'Frozen Nexus',
      description: 'An ancient ice crystal with jagged frost shards.',
      icon: Icons.ac_unit_rounded,
      iconColor: const Color(0xFF88DDFF),
      cost: const {'gold': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.phantom',
      name: 'Phantom Wisp',
      description: 'A ghostly sphere that phases between realms.',
      icon: Icons.blur_on_rounded,
      iconColor: const Color(0xFF7BFFCE),
      cost: const {'gold': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.prism',
      name: 'Prism Heart',
      description: 'A crystalline prism refracting all light.',
      icon: Icons.diamond_rounded,
      iconColor: const Color(0xFFFF69B4),
      cost: const {'gold': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'survival.orb.verdant',
      name: 'Verdant Bloom',
      description: 'A living orb of tangled vines and blossoms.',
      icon: Icons.eco_rounded,
      iconColor: const Color(0xFF32CD32),
      cost: const {'gold': 50},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
  ];

  // --- NEW: Faction change ---

  // --- NEW: Buildings / Special unlocks ---
  // ShopOffer(
  //   id: 'unlock.breeding_device',
  //   name: 'Genetic Fusion Device',
  //   description: 'Breed/fuse in the wild without a lab.',
  //   icon: Icons.biotech_rounded,
  //   cost: const {'gold': 200},
  //   reward: const {},
  //   rewardType: 'boost',
  //   limit: PurchaseLimit.once,
  // ),
  // ShopOffer(
  //   id: 'unlock.prismatic_chamber',
  //   name: 'Prismatic Chamber',
  //   description: 'Attempt prismatic alchemy on a selected creature.',
  //   icon: Icons.auto_awesome_rounded,
  //   cost: const {'gold': 250},
  //   reward: const {},
  //   rewardType: 'boost',
  //   limit: PurchaseLimit.once,
  // ),

  int getFusionSlotsPurchased() {
    return (_purchaseCounts['unlock.fusion_slot.1'] ?? 0) +
        (_purchaseCounts['unlock.fusion_slot.2'] ?? 0) +
        (_purchaseCounts['unlock.fusion_slot.3'] ?? 0) +
        (_purchaseCounts['unlock.fusion_slot.4'] ?? 0) +
        (_purchaseCounts['unlock.fusion_slot.5'] ?? 0);
  }

  // ---- DAILY ELEMENT→GOLD EXCHANGE (5,000 → 1 gold) ----
  static const int kResPerGold = 5000;

  static const Map<int, String> _weekday2ResKey = {
    DateTime.monday: 'res_volcanic',
    DateTime.tuesday: 'res_oceanic',
    DateTime.wednesday: 'res_verdant',
    DateTime.thursday: 'res_earthen',
    DateTime.friday: 'res_arcane',
    // weekend is handled separately (all resources available)
  };

  static const Map<String, (String label, String assetName)> _resMeta = {
    'res_volcanic': ('Volcanic', 'assets/images/ui/volcanic.png'),
    'res_oceanic': ('Oceanic', 'assets/images/ui/oceanic.png'),
    'res_verdant': ('Verdant', 'assets/images/ui/verdant.png'),
    'res_earthen': ('Earthen', 'assets/images/ui/earthen.png'),
    'res_arcane': ('Arcane', 'assets/images/ui/arcane.png'),
  };

  List<ShopOffer> getActiveExchangeOffers() {
    // include the static currency exchangers already defined in allOffers
    final base = allOffers.where(
      (o) =>
          o.id == 'fx.silver_to_gold.unit' || o.id == 'fx.gold_to_silver.unit',
    );

    final now = DateTime.now();
    final weekday = now.weekday;

    // weekend: allow ALL; weekdays: allow only mapped resource
    final List<String> resKeys;
    final isWeekend =
        (weekday == DateTime.saturday || weekday == DateTime.sunday);
    if (isWeekend) {
      resKeys = _resMeta.keys.toList();
    } else {
      final only = _weekday2ResKey[weekday];
      resKeys = only != null ? [only] : <String>[];
    }

    final todayOffers = resKeys.map((rk) {
      final (label, assetName) = _resMeta[rk]!;
      return ShopOffer(
        id: 'fx.res_to_gold.$rk', // e.g., fx.res_to_gold.res_volcanic
        name: '$label → Gold (1g)',
        description: isWeekend
            ? 'Exchange 5,000 $label for 1 gold. (Weekend: any element)'
            : 'Exchange 5,000 $label for 1 gold. (Today only)',
        icon: Icons.currency_exchange_rounded, // Keep a fallback icon
        assetName: assetName, // Add the asset path
        cost: {rk: kResPerGold},
        reward: const {'gold': 1},
        rewardType: 'currency',
        limit: PurchaseLimit.unlimited,
      );
    }).toList();

    return [...base, ...todayOffers];
  }

  Future<void> _loadPurchaseHistory() async {
    final history = await _db.shopDao.getShopPurchaseHistory();
    _purchaseCounts.clear();
    _lastPurchaseTime.clear();
    for (final entry in history) {
      _purchaseCounts[entry['offerId']] = entry['count'];
      if (entry['lastPurchaseUtcMs'] != null) {
        _lastPurchaseTime[entry['offerId']] =
            DateTime.fromMillisecondsSinceEpoch(
              entry['lastPurchaseUtcMs'],
              isUtc: true,
            );
      }
    }
    notifyListeners();
  }

  // lib/services/shop_service.dart

  ShopOffer? _resolveOfferById(String offerId) {
    // 1. Check static offers
    for (final o in allOffers) {
      if (o.id == offerId) return o;
    }

    // 2. Check dynamic currency exchange offers
    for (final o in getActiveExchangeOffers()) {
      if (o.id == offerId) return o;
    }

    // --- ADD THIS BLOCK ---
    // 3. Check the dynamic daily vial offer
    final dailyVial = getActiveDailyVialOffer();
    if (dailyVial != null && dailyVial.id == offerId) {
      return dailyVial;
    }
    // --- END OF ADDED BLOCK ---

    // 4. Not found
    return null;
  }

  bool canPurchase(String offerId) {
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false; // unknown offer -> not purchasable
    if (!_isContestEffectOfferUnlocked(offerId)) return false;

    switch (offer.limit) {
      case PurchaseLimit.once:
        return (_purchaseCounts[offerId] ?? 0) == 0;
      case PurchaseLimit.daily:
        final last = _lastPurchaseTime[offerId];
        if (last == null) return true;
        final now = DateTime.now().toUtc();
        return now.difference(last).inDays >= 1;
      case PurchaseLimit.unlimited:
        return true;
    }
  }

  String getPurchaseStatus(String offerId) {
    final offer = allOffers.firstWhere((o) => o.id == offerId);
    switch (offer.limit) {
      case PurchaseLimit.once:
        final purchased = (_purchaseCounts[offerId] ?? 0) > 0;
        return purchased ? 'OWNED' : '';
      case PurchaseLimit.daily:
        final last = _lastPurchaseTime[offerId];
        if (last == null) return 'AVAILABLE';
        final now = DateTime.now().toUtc();
        if (now.difference(last).inDays >= 1) return 'AVAILABLE';
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final hours = tomorrow.difference(now).inHours;
        final mins = tomorrow.difference(now).inMinutes % 60;
        return hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      case PurchaseLimit.unlimited:
        // NEW: show inventory total ONLY if the offer is inventory-able.
        if (offer.inventoryKey != null) {
          final qty = _inventoryCache[offer.inventoryKey!] ?? 0;
          return qty > 0 ? 'x$qty' : '';
        }
        // Non-inventory unlimited items: no status badge.
        return '';
    }
  }

  /// Get the *effective* cost of an offer after constellation + faction discounts
  Map<String, int> getEffectiveCost(ShopOffer offer) {
    final baseCost = offer.cost;

    // 🔮 Constellation discount
    final reduction = _constellations.getShopPriceReduction(); // e.g. 0.20
    var factor = (1.0 - reduction).clamp(0.0, 1.0);

    // 🪓 Faction discount for harvesters (90% off own biome)
    final harvesterMult = _harvesterFactionMultiplier(offer);
    factor = (factor * harvesterMult).clamp(0.0, 1.0);

    if (factor >= 0.999) {
      return Map<String, int>.from(baseCost);
    }

    final discounted = <String, int>{};

    baseCost.forEach((key, value) {
      if (value <= 0) {
        discounted[key] = value;
      } else {
        final raw = (value * factor).ceil();
        final clamped = raw > value ? value : raw;
        discounted[key] = clamped < 1 ? 1 : clamped;
      }
    });

    return discounted;
  }

  /// Purchase with optional quantity for unlimited items
  Future<bool> purchase(String offerId, {int qty = 1}) async {
    if (!canPurchase(offerId)) return false;
    qty = qty.clamp(1, 999);
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false;

    // Compute total cost (per-unit * qty), using discounted constellation price
    final perUnitCost = getEffectiveCost(offer);
    final totalCost = <String, int>{};
    perUnitCost.forEach((k, v) => totalCost[k] = v * qty);

    // Check affordability
    final currencies = await _db.currencyDao.getAllCurrencies();
    for (final e in totalCost.entries) {
      final have = currencies[e.key] ?? 0;
      if (have < e.value) return false;
    }

    // Deduct costs
    for (final e in totalCost.entries) {
      if (e.key == 'gold') {
        await _db.currencyDao.addGold(-e.value);
      } else if (e.key == 'silver') {
        await _db.currencyDao.addSilver(-e.value);
      } else {
        await _db.currencyDao.addResource(e.key, -e.value);
      }
    }

    // Apply reward/effect (per-unit * qty)
    bool ok = true;
    if (offer.rewardType == 'currency') {
      for (final entry in offer.reward.entries) {
        final amt = (entry.value as int) * qty;
        if (entry.key == 'gold') await _db.currencyDao.addGold(amt);
        if (entry.key == 'silver') await _db.currencyDao.addSilver(amt);
      }
    } else if (offer.rewardType == 'resources') {
      for (final entry in offer.reward.entries) {
        await _db.currencyDao.addResource(
          entry.key,
          (entry.value as int) * qty,
        );
      }
    } else if (offer.rewardType == 'bundle') {
      if (offer.reward.containsKey('gold')) {
        await _db.currencyDao.addGold((offer.reward['gold'] as int) * qty);
      }
      if (offer.reward.containsKey('silver')) {
        await _db.currencyDao.addSilver((offer.reward['silver'] as int) * qty);
      }
      if (offer.reward.containsKey('resources')) {
        final res = offer.reward['resources'] as Map<String, dynamic>;
        for (final e in res.entries) {
          await _db.currencyDao.addResource(e.key, (e.value as int) * qty);
        }
      }
    } else if (offer.rewardType == 'boost') {
      ok = await _applyBoost(offer.id, qty);
    }

    if (!ok) return false;

    // Record purchase
    await _db.shopDao.recordShopPurchase(
      offerId: offerId,
      timestamp: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
    _purchaseCounts[offerId] = (_purchaseCounts[offerId] ?? 0) + 1;
    _lastPurchaseTime[offerId] = DateTime.now().toUtc();

    // NEW: if it’s an inventory-able offer, update the cache immediately
    if (offer.inventoryKey != null) {
      _inventoryCache.update(
        offer.inventoryKey!,
        (v) => v + qty,
        ifAbsent: () => qty,
      );
    }

    notifyListeners();
    return true;
  }

  Future<bool> _applyBoost(String offerId, int qty) async {
    if (offerId.startsWith('vial.daily.common.')) {
      try {
        final groupName = offerId.split('.').last;
        final group = ElementalGroup.values.firstWhere(
          (g) => g.name == groupName,
        );
        final rarity = VialRarity.common;
        final name = '${group.displayName} Vial';

        // Use the dao to add the vial to inventory
        await _db.inventoryDao.addVial(name, group, rarity, qty: qty);
        return true;
      } catch (e, s) {
        if (kDebugMode) {
          debugPrint('Error applying daily vial boost: $e\n$s');
        }
        return false;
      }
    }
    switch (offerId) {
      case 'boost.instant_hatch':
        // grant tokens to inventory instead of applying immediately
        await _db.inventoryDao.addItemQty(InvKeys.instantHatch, qty);
        return true;

      // Devices -> inventory
      case 'device.harvest.std.volcanic':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterStdVolcanic, qty);
        return true;
      case 'device.harvest.std.oceanic':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterStdOceanic, qty);
        return true;
      case 'device.harvest.std.verdant':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterStdVerdant, qty);
        return true;
      case 'device.harvest.std.earthen':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterStdEarthen, qty);
        return true;
      case 'device.harvest.std.arcane':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterStdArcane, qty);
        return true;
      case 'device.harvest.guaranteed':
        await _db.inventoryDao.addItemQty(InvKeys.harvesterGuaranteed, qty);
        return true;

      case 'boost.faction_change':
        // No state to grant here—the picker will handle the actual change.
        // We just signal success so the UI can navigate.
        await _db.settingsDao.setMustPickFaction(true);
        return true;

      case elementalCreatorOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.elementalCreator, qty);
        return true;

      case 'effects.alchemy_glow':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyGlow, qty);
        return true;

      case 'effects.elemental_aura':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyElementalAura, qty);
        return true;
      case 'effects.volcanic_aura':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyVolcanicAura, qty);
        return true;
      case 'effects.void_rift':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyVoidRift, qty);
        return true;
      case 'effects.prismatic_cascade':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyPrismaticCascade, qty);
        return true;
      case ritualGoldEffectOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.alchemyRitualGold, qty);
        return true;
      case beautyContestEffectOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.alchemyBeautyRadiance, qty);
        return true;
      case speedContestEffectOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.alchemySpeedFlux, qty);
        return true;
      case strengthContestEffectOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.alchemyStrengthForge, qty);
        return true;
      case intelligenceContestEffectOfferId:
        await _db.inventoryDao.addItemQty(InvKeys.alchemyIntelligenceHalo, qty);
        return true;

      case 'unlock.fusion_slot.1':
      case 'unlock.fusion_slot.2':
      case 'unlock.fusion_slot.3':
      case 'unlock.fusion_slot.4':
      case 'unlock.fusion_slot.5':
        // One purchase = one slot
        for (int i = 0; i < qty; i++) {
          await _db.incubatorDao.purchaseFusionSlot();
        }
        return true;
      // Exchange handled elsewhere
      case 'fx.silver_to_gold.unit':
      case 'fx.gold_to_silver.unit':
        return true;

      case 'boost.instant_stamina_potion':
        await _db.inventoryDao.addItemQty(InvKeys.staminaPotion, qty);
        return true;

      case 'boost.instant_boss_refresh':
        await _db.inventoryDao.addItemQty(InvKeys.bossRefresh, qty);
        return true;

      // Survival Orb Skins → unlock via SurvivalUpgradeService
      case 'survival.orb.voidforge':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},voidforgeOrb',
        );
        return true;
      case 'survival.orb.celestial':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},celestialOrb',
        );
        return true;
      case 'survival.orb.infernal':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},infernalOrb',
        );
        return true;
      case 'survival.orb.frozen':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},frozenNexusOrb',
        );
        return true;
      case 'survival.orb.phantom':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},phantomWispOrb',
        );
        return true;
      case 'survival.orb.prism':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},prismHeartOrb',
        );
        return true;
      case 'survival.orb.verdant':
        await _db.settingsDao.setSetting(
          'survival.owned_skins',
          '${await _db.settingsDao.getSetting('survival.owned_skins') ?? 'defaultOrb'},verdantBloomOrb',
        );
        return true;

      // Portal Keys → inventory
      case 'key.portal.volcanic':
        await _db.inventoryDao.addItemQty(InvKeys.portalKeyVolcanic, qty);
        return true;
      case 'key.portal.oceanic':
        await _db.inventoryDao.addItemQty(InvKeys.portalKeyOceanic, qty);
        return true;
      case 'key.portal.verdant':
        await _db.inventoryDao.addItemQty(InvKeys.portalKeyVerdant, qty);
        return true;
      case 'key.portal.earthen':
        await _db.inventoryDao.addItemQty(InvKeys.portalKeyEarthen, qty);
        return true;
      case 'key.portal.arcane':
        await _db.inventoryDao.addItemQty(InvKeys.portalKeyArcane, qty);
        return true;

      // Cosmic Alchemy
      case 'cosmic.ship':
        await _db.inventoryDao.addItemQty(InvKeys.cosmicShip, qty);
        await _db.settingsDao.setSetting('cosmic_ship_unlocked', '1');
        return true;
      default:
        return false;
    }
  }

  Future<void> applyAlchemyEffect(String instanceId, String effect) async {
    await _db.creatureDao.updateAlchemyEffect(
      instanceId: instanceId,
      effect: effect,
    );
  }

  /// After purchasing an alchemy effect (which adds it to inventory), apply
  /// the purchased effect to a creature instance and consume one item.
  Future<bool> applyEffectToInstance(String offerId, String instanceId) async {
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false;

    // Map offer id -> effect key (e.g. 'effects.alchemy_glow' -> 'alchemy_glow')
    String? effectType;
    if (offer.id.startsWith('effects.')) {
      final parts = offer.id.split('.');
      effectType = parts.isNotEmpty ? parts.last : null;
    }

    if (effectType == null) return false;

    try {
      await applyAlchemyEffect(instanceId, effectType);

      // Consume one inventory item if this offer had an inventory key
      if (offer.inventoryKey != null) {
        await _db.inventoryDao.decrementItem(offer.inventoryKey!, by: 1);
        await refreshInventoryForOffer(offerId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // Track current inventory for inventory-able offers
  final Map<String, int> _inventoryCache = {}; // inventoryKey -> qty

  Future<void> _loadInventoryCache() async {
    // Only query keys we actually expose via offers
    final keys = allOffers
        .map((o) => o.inventoryKey)
        .whereType<String>()
        .toSet()
        .toList();

    for (final key in keys) {
      try {
        final qty = await _db.inventoryDao.getItemQty(
          key,
        ); // expects this to exist
        _inventoryCache[key] = qty;
      } catch (_) {
        _inventoryCache[key] = _inventoryCache[key] ?? 0;
      }
    }
    notifyListeners();
  }

  Future<void> refreshInventoryForOffer(String offerId) async {
    final offer = _resolveOfferById(offerId);
    final key = offer?.inventoryKey;
    if (key == null) return;
    final qty = await _db.inventoryDao.getItemQty(key);
    _inventoryCache[key] = qty;
    notifyListeners();
  }

  bool isInventoryable(String offerId) {
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false;
    return offer.inventoryKey != null;
  }

  int inventoryCountForOffer(String offerId) {
    final offer = _resolveOfferById(offerId);
    final key = offer?.inventoryKey;
    if (key == null) return 0;
    return _inventoryCache[key] ?? 0;
  }

  bool hasElementalCreatorUnlocked() =>
      (_purchaseCounts[elementalCreatorOfferId] ?? 0) > 0;

  int getPurchaseCount(String offerId) => _purchaseCounts[offerId] ?? 0;
}
