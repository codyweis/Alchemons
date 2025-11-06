// lib/services/shop_service.dart
import 'package:alchemons/models/inventory.dart';
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

  bool allowsQuantity(ShopOffer o) =>
      o.limit == PurchaseLimit.unlimited && _quantityEligible.contains(o.id);

  // ==== Offers (existing + new) ====
  static final List<ShopOffer> allOffers = [
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
      name: 'Instant Egg Hatcher',
      description: 'Finish one incubating egg instantly.',
      icon: Icons.egg_rounded,
      cost: const {'gold': 30},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.unlimited,
      inventoryKey: InvKeys.instantHatch, // NEW
    ),

    // --- NEW: Currency exchange units (5% fee baked in) ---
    ShopOffer(
      id: 'fx.silver_to_gold.unit',
      name: 'Silver → Gold (1g)',
      description: 'Convert 105 silver to 1 gold (incl. 5% fee).',
      icon: Icons.currency_exchange_rounded,
      cost: const {'silver': 105},
      reward: const {'gold': 1},
      rewardType: 'currency',
      limit: PurchaseLimit.unlimited,
    ),
    ShopOffer(
      id: 'fx.gold_to_silver.unit',
      name: 'Gold → Silver (100s)',
      description: 'Convert 1 gold to 95 silver (5% fee).',
      icon: Icons.swap_horiz_rounded,
      cost: const {'gold': 1},
      reward: const {'silver': 95},
      rewardType: 'currency',
      limit: PurchaseLimit.unlimited,
    ),

    // --- NEW: Faction change ---
    ShopOffer(
      id: 'boost.faction_change',
      name: 'Change Faction',
      description: 'Align with a new faction.',
      icon: Icons.flag_rounded,
      cost: const {'gold': 120},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.daily,
      assetName: 'assets/images/ui/factionorb.png',
    ),

    // --- NEW: Buildings / Special unlocks ---
    ShopOffer(
      id: 'unlock.breeding_device',
      name: 'Genetic Fusion Device',
      description: 'Breed/fuse in the wild without a lab.',
      icon: Icons.biotech_rounded,
      cost: const {'gold': 200},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
    ShopOffer(
      id: 'unlock.prismatic_chamber',
      name: 'Prismatic Chamber',
      description: 'Attempt prismatic alchemy on a selected creature.',
      icon: Icons.auto_awesome_rounded,
      cost: const {'gold': 250},
      reward: const {},
      rewardType: 'boost',
      limit: PurchaseLimit.once,
    ),
  ];

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

  bool canPurchase(String offerId) {
    final offer = allOffers.firstWhere((o) => o.id == offerId);
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
    final offer = allOffers.firstWhere((o) => o.id == offerId);

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

      // Exchange handled elsewhere
      case 'fx.silver_to_gold.unit':
      case 'fx.gold_to_silver.unit':
        return true;

      default:
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
    final offer = allOffers.firstWhere((o) => o.id == offerId);
    final key = offer.inventoryKey;
    if (key == null) return;
    final qty = await _db.inventoryDao.getItemQty(key);
    _inventoryCache[key] = qty;
    notifyListeners();
  }

  bool isInventoryable(String offerId) {
    final offer = allOffers.firstWhere((o) => o.id == offerId);
    return offer.inventoryKey != null;
  }

  int inventoryCountForOffer(String offerId) {
    final offer = allOffers.firstWhere((o) => o.id == offerId);
    final key = offer.inventoryKey;
    if (key == null) return 0;
    return _inventoryCache[key] ?? 0;
  }

  int getPurchaseCount(String offerId) => _purchaseCounts[offerId] ?? 0;
}
