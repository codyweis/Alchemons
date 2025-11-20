// lib/services/black_market_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart'; // <-- use Settings table
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:drift/drift.dart';
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
  BlackMarketService(this._db, this._constellationEffectsService) {
    _checkStatus();
    _updateWeeklyContent();
    _initFromSettings(); // fire-and-forget: restores week + purchased set

    _checkTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkStatus();
      _checkWeeklyReset();
    });
  }

  // ----------------- deps -----------------
  final AlchemonsDatabase _db;
  final ConstellationEffectsService _constellationEffectsService;

  // ----------------- constants ------------
  static const int _openHour = 18; // 6 PM
  static const int _closeHour = 8; // 8 AM

  // ----------------- state ----------------
  bool _isOpen = false;
  Timer? _checkTimer;

  // Premium (weekly)
  String _premiumRarity = '';
  String _premiumType = '';
  double _premiumBonus = 1.0;

  // Offers/Vials (weekly; names kept to avoid refactors)
  List<DailyOffer> _dailyOffers = [];
  List<ExtractionVial> _dailyVials = [];

  // Purchases (reset weekly)
  final Set<String> _purchasedToday = {}; // = purchasedThisWeek
  String _lastPurchaseDate = ''; // = lastWeekKey (yyyy-MM-dd of Monday)

  // ----------------- public API -----------
  bool get isOpen => _isOpen;
  String get premiumRarity => _premiumRarity;
  String get premiumType => _premiumType;
  double get premiumBonus => _premiumBonus;
  List<DailyOffer> get dailyOffers => _dailyOffers;
  List<ExtractionVial> get dailyVials => _dailyVials;

  bool isPurchased(String offerId) => _purchasedToday.contains(offerId);

  /// Force a manual check (call when navigating to shop)
  void checkNow() {
    _checkStatus();
    _checkWeeklyReset();
  }

  // ----------------- schedule/open window -----------
  void _checkStatus() {
    final now = DateTime.now();

    final alwaysOpen = _constellationEffectsService.has24x7BlackMarket();
    final newStatus = alwaysOpen || _isOpenAt(now);

    if (newStatus != _isOpen) {
      _isOpen = newStatus;
      notifyListeners();
    }
  }

  bool _isOpenAt(DateTime t) => t.hour >= _openHour || t.hour < _closeHour;
  DateTime _at(DateTime base, int hour, {int addDays = 0}) => DateTime(
    base.year,
    base.month,
    base.day,
    hour,
  ).add(Duration(days: addDays));
  DateTime getNextOpenTime() {
    if (_constellationEffectsService.has24x7BlackMarket()) {
      // Conceptually "now" – already open.
      return DateTime.now();
    }

    final now = DateTime.now();

    final todayOpen = _at(now, _openHour);
    final tomorrowOpen = _at(now, _openHour, addDays: 1);

    if (!_isOpenAt(now)) {
      return now.isBefore(todayOpen) ? todayOpen : tomorrowOpen;
    }

    return tomorrowOpen;
  }

  DateTime getNextCloseTime() {
    if (_constellationEffectsService.has24x7BlackMarket()) {
      // Never really closes – return now so countdowns show 0.
      return DateTime.now();
    }

    final now = DateTime.now();

    if (now.hour < _closeHour) return _at(now, _closeHour);
    if (now.hour >= _openHour) return _at(now, _closeHour, addDays: 1);

    return _at(now, _closeHour, addDays: 1);
  }

  Duration _nonNeg(Duration d) => d.isNegative ? Duration.zero : d;

  Duration getTimeUntilOpen() {
    if (_constellationEffectsService.has24x7BlackMarket()) {
      return Duration.zero;
    }
    return _nonNeg(getNextOpenTime().difference(DateTime.now()));
  }

  Duration getTimeUntilClose() {
    if (_constellationEffectsService.has24x7BlackMarket()) {
      return Duration.zero;
    }
    return _nonNeg(getNextCloseTime().difference(DateTime.now()));
  }

  // ----------------- weekly helpers ----------------
  // Monday-start week key (yyyy-MM-dd of Monday)
  String _currentWeekKey([DateTime? at]) {
    final now = at ?? DateTime.now();
    final weekStart = now.subtract(
      Duration(days: now.weekday - DateTime.monday),
    );
    final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return monday.toIso8601String().substring(0, 10);
  }

  // Seed constant for the whole week
  int _weeklySeed() {
    final key = _currentWeekKey(); // e.g., 2025-11-03
    return int.parse(key.replaceAll('-', '')); // -> 20251103
  }

  // ----------------- persistence (Settings) --------
  static const String _bmLastWeekKey = 'bm_last_week_key';
  static String _bmPurchasesKeyFor(String weekKey) => 'bm_purchased_$weekKey';

  Future<void> _initFromSettings() async {
    // load last week; default to this week if not set
    final lastWeekRow = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(_bmLastWeekKey))).getSingleOrNull();

    final currentWeek = _currentWeekKey();
    _lastPurchaseDate = lastWeekRow?.value ?? currentWeek;

    if (_lastPurchaseDate != currentWeek) {
      // New week since last run: clear purchases and write the new week key
      _purchasedToday.clear();
      _lastPurchaseDate = currentWeek;
      await _saveWeekKey(_lastPurchaseDate);
      await _savePurchasedSet(); // writes empty list for this week
    } else {
      // Same week: restore purchased set
      final purchaseRow =
          await (_db.select(_db.settings)
                ..where((t) => t.key.equals(_bmPurchasesKeyFor(currentWeek))))
              .getSingleOrNull();
      final ids = purchaseRow == null || purchaseRow.value.isEmpty
          ? const <String>[]
          : List<String>.from(jsonDecode(purchaseRow.value) as List);
      _purchasedToday
        ..clear()
        ..addAll(ids);
    }

    notifyListeners();
  }

  Future<void> _saveWeekKey(String weekKey) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(key: Value(_bmLastWeekKey), value: Value(weekKey)),
        );
  }

  Future<void> _savePurchasedSet() async {
    final key = _bmPurchasesKeyFor(_lastPurchaseDate);
    final json = jsonEncode(_purchasedToday.toList());
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion(key: Value(key), value: Value(json)),
        );
  }

  // ----------------- weekly reset & content --------
  void _checkWeeklyReset() async {
    final weekKey = _currentWeekKey();

    if (_lastPurchaseDate != weekKey) {
      _purchasedToday.clear();
      _lastPurchaseDate = weekKey;
      await _saveWeekKey(weekKey);
      await _savePurchasedSet(); // persist cleared set for the new week

      _updateWeeklyContent();
      notifyListeners();
    }
  }

  void _updateWeeklyContent() {
    final seed = _weeklySeed();

    // Weekly premium
    final element = Elements.values.map((r) => r.name).toList();
    _premiumRarity = element[seed % element.length];

    final species = CreatureFamily.values
        .map((f) => f.displayName)
        .where((s) => s != CreatureFamily.mystic.displayName)
        .toList();
    _premiumType = species[(seed ~/ 3) % species.length];

    _premiumBonus = 2 + ((seed % 10) / 10.0);

    // Weekly offers & vials (names kept)
    _dailyOffers = _generateDailyOffers(seed);
    _dailyVials = _generateDailyVials(seed);
  }

  // ----------------- purchase flow -----------------
  Future<bool> purchaseOffer(String offerId) async {
    if (_purchasedToday.contains(offerId)) return false;

    _purchasedToday.add(offerId);
    await _savePurchasedSet();
    notifyListeners();
    return true;
  }

  // ----------------- content generation ------------
  List<DailyOffer> _generateDailyOffers(int seed) {
    final offers = <DailyOffer>[];

    // Offer 1: Currency exchange
    final goldAmount = 10 + ((seed % 5) * 100);
    offers.add(
      DailyOffer(
        id: 'gold_exchange_$seed',
        name: 'Gold Exchange',
        description: 'Convert silver to gold at a premium rate',
        icon: Icons.swap_horiz_rounded,
        cost: {'silver': goldAmount},
        rewardType: 'currency',
        reward: {'gold': goldAmount},
      ),
    );

    // Offer 2: Resource pack
    final resourceAmount = 100 + ((seed % 10) * 10);
    offers.add(
      DailyOffer(
        id: 'resource_pack_$seed',
        name: 'Elemental Cache',
        description: 'Rare elemental resources bundle',
        icon: Icons.inventory_rounded,
        cost: {'silver': 800 + ((seed % 5) * 100)},
        rewardType: 'resources',
        reward: {
          ElementResources.keyForBiome('volcanic'): resourceAmount,
          ElementResources.keyForBiome('oceanic'): resourceAmount,
          ElementResources.keyForBiome('verdant'): resourceAmount,
        },
      ),
    );

    return offers;
  }

  VialRarity _pickRarity(math.Random rng) {
    const weights = <VialRarity, int>{
      VialRarity.common: 62,
      VialRarity.uncommon: 27,
      VialRarity.rare: 9,
      VialRarity.legendary: 2,
      VialRarity.mythic: 0,
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
    switch (r) {
      case VialRarity.common:
        return 150;
      case VialRarity.uncommon:
        return 300;
      case VialRarity.rare:
        return 650;
      case VialRarity.legendary:
        return 10;
      case VialRarity.mythic:
        return 100;
    }
  }

  List<ExtractionVial> _generateDailyVials(int seed) {
    final rng = math.Random(seed);
    final groups = ElementalGroup.values;
    final list = <ExtractionVial>[];
    bool gaveLegendaryThisWeek = false;

    for (int i = 0; i < 4; i++) {
      final g = groups[rng.nextInt(groups.length)];
      var rarity = _pickRarity(rng);

      if (rarity == VialRarity.legendary) {
        if (gaveLegendaryThisWeek) {
          rarity = VialRarity.rare;
        } else {
          gaveLegendaryThisWeek = true;
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
          quantity: qty,
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
