// lib/services/shop_service.dart
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/animations/sprite_effects/alchemy_glow.dart';
import 'package:alchemons/widgets/animations/sprite_effects/orbiting_particles.dart';
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
  });
}

class ShopService extends ChangeNotifier {
  final AlchemonsDatabase _db;

  // Track purchases
  final Map<String, int> _purchaseCounts = {}; // offerId -> count
  final Map<String, DateTime> _lastPurchaseTime = {}; // offerId -> last time

  ShopService(this._db) {
    _loadPurchaseHistory();
    _loadInventoryCache();
  }

  static Widget? getAlchemyEffectPreview(
    String inventoryKey, {
    double size = 32.0,
  }) {
    switch (inventoryKey) {
      case InvKeys.alchemyGlow:
        return AlchemyGlow(size: size / 2);

      case InvKeys.alchemyElementalAura:
        return SizedBox.square(
          dimension: size,
          child: ElementalAura(
            size: size,
            element: 'Volcanic', // or whatever element you want as default
          ),
        );

      case InvKeys.alchemyVolcanicAura:
        return SizedBox.square(
          dimension: size,
          child: VolcanicAura(size: size),
        );

      default:
        return null;
    }
  }

  // ==== Config for exchange & quantity ====
  static const int kSilverPerGold = 100; // informational
  static const double kFeePct = 0.05; // informational

  static const Set<String> _quantityEligible = {
    // Devices
    'device.harvest.std.volcanic',
    'device.harvest.std.oceanic',
    'device.harvest.std.verdant',
    'device.harvest.std.earthen',
    'device.harvest.std.arcane',
    'device.harvest.guaranteed',
    // Currency unit exchangers
    'fx.silver_to_gold.unit',
    'fx.gold_to_silver.unit',
    // Packs/currency packs you already had
    'small_gold_pack',
    'medium_gold_pack',
    'large_gold_pack',
    'volcanic_bundle',
    'oceanic_bundle',
    'pack.elemental',
  };

  bool allowsQuantity(ShopOffer o) {
    if (o.limit != PurchaseLimit.unlimited) return false;
    if (_quantityEligible.contains(o.id)) return true;
    // NEW: allow quantity for any resource→gold unit exchangers
    if (o.id.startsWith('fx.res_to_gold.')) return true;
    return false;
  }

  // ==== Offers (existing + new) ====
  static final List<ShopOffer> allOffers = [
    ShopOffer(
      id: 'boost.instant_stamina_potion',
      name: 'Stamina Elixir',
      description: 'Fully restores an Alchemon\'s stamina.',
      icon: Icons.local_drink_rounded,
      cost: const {'silver': 3000}, // tweak cost as desired
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.staminaPotion,
      assetName:
          'assets/images/ui/instantstaminaicon.png', // optional, if you add one
    ),
    // --- NEW: Devices (standard per element) ---
    ShopOffer(
      id: 'device.harvest.std.volcanic',
      name: 'Wild Harvester – Volcanic',
      description: 'Standard device. Chance-based.',
      icon: Icons.local_fire_department_rounded,
      cost: const {'gold': 8},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdVolcanic, // NEW
      assetName: 'assets/images/ui/volcanicharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.oceanic',
      name: 'Wild Harvester – Oceanic',
      description: 'Standard device. Chance-based.',
      icon: Icons.water_rounded,
      cost: const {'gold': 8},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdOceanic, // NEW
      assetName: 'assets/images/ui/oceanicharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.verdant',
      name: 'Wild Harvester – Verdant',
      description: 'Standard device. Chance-based.',
      icon: Icons.eco_rounded,
      cost: const {'gold': 8},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdVerdant, // NEW
      assetName: 'assets/images/ui/verdantharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.earthen',
      name: 'Wild Harvester – Earthen',
      description: 'Standard device. Chance-based.',
      icon: Icons.terrain_rounded,
      cost: const {'gold': 8},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.harvesterStdEarthen, // NEW
      assetName: 'assets/images/ui/earthenharvester.png',
    ),
    ShopOffer(
      id: 'device.harvest.std.arcane',
      name: 'Wild Harvester – Arcane',
      description: 'Standard device. Chance-based.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'gold': 10},
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
      description: 'Guaranteed capture device.',
      icon: Icons.shield_rounded,
      cost: const {'gold': 45},
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
      description: 'Complete one active fusion vial instantly.',
      assetName: 'assets/images/ui/instantbreedicon.png',
      icon: Icons.access_alarms,
      cost: const {'silver': 5000},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.instantHatch, // NEW
    ),

    // --- NEW: Currency exchange units (5% fee baked in) ---
    ShopOffer(
      id: 'fx.silver_to_gold.unit',
      name: 'Silver → Gold (10g)',
      description: 'Convert 20,000 silver to 10 gold.',
      icon: Icons.currency_exchange_rounded,
      cost: const {'silver': 20000},
      reward: const {'gold': 10},
      rewardType: 'currency',
      limit: PurchaseLimit.unlimited,
    ),
    ShopOffer(
      id: 'fx.gold_to_silver.unit',
      name: 'Gold → Silver (1,000s)',
      description: 'Convert 1 gold to 1,000 silver.',
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
      description: 'Add another incubator slot.',
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
      description: 'Add another incubator slot.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 10}, // 2nd purchase: 5 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.3',
      name: 'Fusion Slot (Step 3)',
      description: 'Add another incubator slot.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 50}, // 3rd purchase: 25 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'unlock.fusion_slot.4',
      name: 'Fusion Slot (Step 4)',
      description: 'Add another incubator slot.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 100}, // 4th purchase: 100 gold
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
      assetName: 'assets/images/ui/breedicon.png',
    ),
    ShopOffer(
      id: 'boost.faction_change',
      name: 'Change Faction',
      description: 'Align with a new faction.',
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
      description: 'Ethereal glow effect for your Alchemon.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'silver': 10000},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyGlow,
      assetName: 'assets/images/ui/alchemyglow.png', // You'll need to add this
    ),
    ShopOffer(
      id: 'effects.elemental_aura',
      name: 'Elemental Aura',
      description: 'Orbiting particles matching your Alchemon\'s element.',
      icon: Icons.bubble_chart_rounded,
      cost: const {'silver': 10000},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyElementalAura,
      assetName: 'assets/images/ui/elementalaura.png',
    ),
    ShopOffer(
      id: 'effects.volcanic_aura',
      name: 'Volcanic Aura',
      description: 'Fiery aura effect for your Alchemon.',
      icon: Icons.local_fire_department_rounded,
      cost: const {'gold': 10},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.alchemyVolcanicAura,
      assetName: 'assets/images/ui/volcanicaura.png',
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
        (_purchaseCounts['unlock.fusion_slot.4'] ?? 0);
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

  ShopOffer? _resolveOfferById(String offerId) {
    for (final o in allOffers) {
      if (o.id == offerId) return o;
    }
    for (final o in getActiveExchangeOffers()) {
      if (o.id == offerId) return o;
    }
    return null;
  }

  bool canPurchase(String offerId) {
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false; // unknown offer -> not purchasable

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

  /// Purchase with optional quantity for unlimited items
  Future<bool> purchase(String offerId, {int qty = 1}) async {
    if (!canPurchase(offerId)) return false;
    qty = qty.clamp(1, 999);
    final offer = _resolveOfferById(offerId);
    if (offer == null) return false;

    // Compute total cost (per-unit * qty)
    final totalCost = <String, int>{};
    offer.cost.forEach((k, v) => totalCost[k] = v * qty);

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

      case 'effects.alchemy_glow':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyGlow, qty);
        return true;

      case 'effects.elemental_aura':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyElementalAura, qty);
        return true;
      case 'effects.volcanic_aura':
        await _db.inventoryDao.addItemQty(InvKeys.alchemyVolcanicAura, qty);
        return true;

      case 'unlock.fusion_slot.1':
      case 'unlock.fusion_slot.2':
      case 'unlock.fusion_slot.3':
      case 'unlock.fusion_slot.4':
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

  int getPurchaseCount(String offerId) => _purchaseCounts[offerId] ?? 0;
}
