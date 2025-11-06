// lib/services/black_market_service.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class DailyOffer {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Map<String, int> cost; // currency type -> amount
  final String rewardType; // 'currency', 'item', 'boost'
  final Map<String, dynamic> reward;

  const DailyOffer({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.cost,
    required this.rewardType,
    required this.reward,
  });
}

class BlackMarketService extends ChangeNotifier {
  bool _isOpen = false;
  Timer? _checkTimer;

  // Premium items that rotate daily
  String _premiumRarity = '';
  String _premiumType = '';
  double _premiumBonus = 1.0;

  // Daily offers
  List<DailyOffer> _dailyOffers = [];

  // Purchased items (resets daily)
  final Set<String> _purchasedToday = {};
  String _lastPurchaseDate = '';

  bool get isOpen => !_isOpen;
  String get premiumRarity => _premiumRarity;
  String get premiumType => _premiumType;
  double get premiumBonus => _premiumBonus;
  List<DailyOffer> get dailyOffers => _dailyOffers;

  bool isPurchased(String offerId) => _purchasedToday.contains(offerId);

  List<ExtractionVial> _dailyVials = [];
  List<ExtractionVial> get dailyVials => _dailyVials;

  BlackMarketService() {
    _checkStatus();
    _updateDailyContent();
    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkStatus();
      _checkDailyReset();
    });
  }

  void _checkStatus() {
    final now = DateTime.now();
    // Black Market open from 8 PM to 4 AM (20:00 - 04:00)
    final newStatus = now.hour >= 20 || now.hour < 4;

    if (newStatus != _isOpen) {
      _isOpen = newStatus;
      notifyListeners();
    }
  }

  void _checkDailyReset() {
    final today = DateTime.now().toString().substring(0, 10);
    if (_lastPurchaseDate != today) {
      _purchasedToday.clear();
      _lastPurchaseDate = today;
      _updateDailyContent();
      notifyListeners();
    }
  }

  void _updateDailyContent() {
    final now = DateTime.now();
    // Use date as seed for consistent daily values
    final seed = now.year * 10000 + now.month * 100 + now.day;

    // Update premium selling bonus
    final element = Elements.values.map((r) => r.name).toList();
    _premiumRarity = element[seed % element.length];

    final species = CreatureFamily.values
        .map((f) => f.displayName)
        .toList()
        .where((s) => s != CreatureFamily.mystic.displayName)
        .toList();
    _premiumType = species[(seed ~/ 3) % species.length];

    _premiumBonus = 2 + ((seed % 10) / 10.0);

    // Generate daily offers
    _dailyOffers = _generateDailyOffers(seed);
    _dailyVials = _generateDailyVials(seed);
  }

  List<DailyOffer> _generateDailyOffers(int seed) {
    final offers = <DailyOffer>[];

    // Offer 1: Currency exchange
    final goldAmount = 500 + ((seed % 5) * 100);
    offers.add(
      DailyOffer(
        id: 'gold_exchange_$seed',
        name: 'Gold Exchange',
        description: 'Convert silver to gold at a premium rate',
        icon: Icons.swap_horiz_rounded,
        cost: {'silver': goldAmount * 3},
        rewardType: 'currency',
        reward: {'gold': goldAmount},
      ),
    );

    // Offer 2: Resource pack
    final resourceAmount = 50 + ((seed % 10) * 10);
    offers.add(
      DailyOffer(
        id: 'resource_pack_$seed',
        name: 'Elemental Cache',
        description: 'Rare elemental resources bundle',
        icon: Icons.inventory_rounded,
        cost: {'silver': 800 + ((seed % 5) * 100)},
        rewardType: 'resources',
        reward: {
          'volcanic': resourceAmount,
          'oceanic': resourceAmount,
          'verdant': resourceAmount,
        },
      ),
    );

    // Offer 3: XP Boost
    offers.add(
      DailyOffer(
        id: 'xp_boost_$seed',
        name: 'Experience Elixir',
        description: '2x XP for 1 hour',
        icon: Icons.trending_up_rounded,
        cost: {'silver': 500},
        rewardType: 'boost',
        reward: {'type': 'xp', 'multiplier': 2.0, 'duration': 3600},
      ),
    );

    // Offer 4: Rare item (more expensive)
    offers.add(
      DailyOffer(
        id: 'rare_item_$seed',
        name: 'Mysterious Egg',
        description: 'Contains a random rare creature',
        icon: Icons.egg_rounded,
        cost: {'gold': 100 + ((seed % 3) * 50)},
        rewardType: 'item',
        reward: {'type': 'egg', 'rarity': 'rare'},
      ),
    );

    return offers;
  }

  Future<bool> purchaseOffer(String offerId) async {
    if (_purchasedToday.contains(offerId)) {
      return false;
    }

    // Mark as purchased
    _purchasedToday.add(offerId);
    notifyListeners();
    return true;
  }

  /// Force a manual check (call when navigating to shop)
  void checkNow() {
    _checkStatus();
    _checkDailyReset();
  }

  /// Get the next time the market will open
  DateTime getNextOpenTime() {
    final now = DateTime.now();
    if (now.hour < 4) {
      return DateTime(now.year, now.month, now.day, 20);
    } else if (now.hour < 20) {
      return DateTime(now.year, now.month, now.day, 20);
    } else {
      return DateTime(now.year, now.month, now.day + 1, 20);
    }
  }

  /// Get duration until the market opens
  Duration getTimeUntilOpen() {
    final now = DateTime.now();
    final nextOpen = getNextOpenTime();
    return nextOpen.difference(now);
  }

  /// Get the time the market will close (4 AM)
  DateTime getNextCloseTime() {
    final now = DateTime.now();
    if (now.hour < 4) {
      return DateTime(now.year, now.month, now.day, 4);
    } else {
      return DateTime(now.year, now.month, now.day + 1, 4);
    }
  }

  /// Get duration until the market closes
  Duration getTimeUntilClose() {
    final now = DateTime.now();
    final nextClose = getNextCloseTime();
    return nextClose.difference(now);
  }

  // Map your Elements enum to the widget's ElementalGroup
  ElementalGroup _mapElementToGroup(String elementName) {
    switch (elementName.toLowerCase()) {
      case 'fire':
      case 'lava':
      case 'lightning':
        return ElementalGroup.volcanic;
      case 'water':
      case 'ice':
      case 'steam':
        return ElementalGroup.oceanic;
      case 'earth':
      case 'mud':
      case 'crystal':
        return ElementalGroup.earthen;
      case 'plant':
      case 'poison':
        return ElementalGroup.verdant;
      default:
        // spirit/light/dark etc. → arcane
        return ElementalGroup.arcane;
    }
  }

  VialRarity _rarityFromIndex(int i) {
    switch (i.clamp(0, 4)) {
      case 0:
        return VialRarity.common;
      case 1:
        return VialRarity.uncommon;
      case 2:
        return VialRarity.rare;
      case 3:
        return VialRarity.legendary;
      default:
        return VialRarity.mythic;
    }
  }

  VialRarity _pickRarity(math.Random rng) {
    // Tune these weights to taste; they sum to 100.
    const weights = <VialRarity, int>{
      VialRarity.common: 62,
      VialRarity.uncommon: 27,
      VialRarity.rare: 9,
      VialRarity.legendary: 2,
      VialRarity.mythic:
          0, // set to 1 for ~1% *if* you want mythics to exist here
    };
    final total = weights.values.reduce((a, b) => a + b);
    int roll = rng.nextInt(total);
    for (final e in weights.entries) {
      if (roll < e.value) return e.key;
      roll -= e.value;
    }
    return VialRarity.common;
  }

  int _priceFor(VialRarity r) {
    // tune to your economy; uses silver for most, gold for mythic
    switch (r) {
      case VialRarity.common:
        return 150; // silver
      case VialRarity.uncommon:
        return 300; // silver
      case VialRarity.rare:
        return 650; // silver
      case VialRarity.legendary:
        return 1200; // silver
      case VialRarity.mythic:
        return 100; // gold (handled specially on buy)
    }
  }

  List<ExtractionVial> _generateDailyVials(int seed) {
    final rng = math.Random(seed);
    final groups = ElementalGroup.values;
    final list = <ExtractionVial>[];
    bool gaveLegendaryToday = false;

    for (int i = 0; i < 6; i++) {
      final g = groups[rng.nextInt(groups.length)];
      var rarity = _pickRarity(rng);

      if (rarity == VialRarity.legendary) {
        if (gaveLegendaryToday) {
          // downgrade to Rare on the second+ legendary roll
          rarity = VialRarity.rare;
        } else {
          gaveLegendaryToday = true;
        }
      }

      final price = _priceFor(rarity);
      final qty = 1 + rng.nextInt(2);

      final nice = {
        ElementalGroup.volcanic: ['Volcanic'],
        ElementalGroup.oceanic: ['Oceanic'],
        ElementalGroup.earthen: ['Earthen'],
        ElementalGroup.verdant: ['Verdant'],
        ElementalGroup.arcane: ['Arcane'],
      }[g]!;

      final name = '${nice[rng.nextInt(nice.length)]} Vial';

      list.add(
        ExtractionVial(
          id: 'vial_${seed}_$i',
          name: name,
          group: g,
          rarity: rarity,
          quantity: 1,
          price: price,
        ),
      );
    }
    return list;
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
