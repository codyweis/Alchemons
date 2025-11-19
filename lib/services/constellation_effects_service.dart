// lib/services/constellation_effects_service.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:flutter/foundation.dart';

/// Service for applying constellation skill effects throughout the game
class ConstellationEffectsService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  Set<String> _unlockedSkillIds = {};

  ConstellationEffectsService(this._db) {
    _init();
  }

  Future<void> _init() async {
    // Load initial unlocked skills
    _unlockedSkillIds = await _db.constellationDao.getUnlockedSkillIds();

    // Watch for changes
    _db.constellationDao.watchUnlockedSkillIds().listen((skills) {
      _unlockedSkillIds = skills;
      notifyListeners();
    });
  }

  // ==================== BATTLE/COMBAT TREE EFFECTS ====================

  /// Calculate total stat boost from unlocked combat skills
  /// Returns the multiplier to apply when enhancing (feeding)
  double getStatBoostMultiplier(String statName) {
    double boost = 0.0;

    switch (statName.toLowerCase()) {
      case 'strength':
      case 'atk':
        // Each strength boost skill adds 0.005
        if (_unlockedSkillIds.contains('combat_atk_boost_1')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_atk_boost_2')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_atk_boost_3')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_atk_boost_4')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_atk_boost_5')) boost += 0.005;
        break;

      case 'intelligence':
      case 'int':
        // Each intelligence boost skill adds 0.005
        if (_unlockedSkillIds.contains('combat_int_boost_1')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_int_boost_2')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_int_boost_3')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_int_boost_4')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_int_boost_5')) boost += 0.005;
        break;

      case 'beauty':
        // Each beauty boost skill adds 0.005
        if (_unlockedSkillIds.contains('combat_beauty_boost_1')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_beauty_boost_2')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_beauty_boost_3')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_beauty_boost_4')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_beauty_boost_5')) boost += 0.005;
        break;

      case 'speed':
        // Each speed boost skill adds 0.005
        if (_unlockedSkillIds.contains('combat_speed_boost_1')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_speed_boost_2')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_speed_boost_3')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_speed_boost_4')) boost += 0.005;
        if (_unlockedSkillIds.contains('combat_speed_boost_5')) boost += 0.005;
        break;
    }

    return boost;
  }

  /// Apply constellation boosts to stat gains during enhancement
  Map<String, double> applyStatBoosts(Map<String, double> baseGains) {
    final boosted = <String, double>{};

    baseGains.forEach((statName, baseValue) {
      final boost = getStatBoostMultiplier(statName);
      // Add the boost as a flat bonus to the gain
      boosted[statName] = baseValue + boost;
    });

    return boosted;
  }

  /// Get total possible boost for a stat (for UI display)
  double getMaxStatBoost(String statName) {
    // Each stat has 5 levels, each adding 0.005
    return 5 * 0.005; // = 0.025 max
  }

  /// Get current stat boost level (0-5)
  int getStatBoostLevel(String statName) {
    int level = 0;

    switch (statName.toLowerCase()) {
      case 'strength':
      case 'atk':
        if (_unlockedSkillIds.contains('combat_atk_boost_1')) level++;
        if (_unlockedSkillIds.contains('combat_atk_boost_2')) level++;
        if (_unlockedSkillIds.contains('combat_atk_boost_3')) level++;
        if (_unlockedSkillIds.contains('combat_atk_boost_4')) level++;
        if (_unlockedSkillIds.contains('combat_atk_boost_5')) level++;
        break;

      case 'intelligence':
      case 'int':
        if (_unlockedSkillIds.contains('combat_int_boost_1')) level++;
        if (_unlockedSkillIds.contains('combat_int_boost_2')) level++;
        if (_unlockedSkillIds.contains('combat_int_boost_3')) level++;
        if (_unlockedSkillIds.contains('combat_int_boost_4')) level++;
        if (_unlockedSkillIds.contains('combat_int_boost_5')) level++;
        break;

      case 'beauty':
        if (_unlockedSkillIds.contains('combat_beauty_boost_1')) level++;
        if (_unlockedSkillIds.contains('combat_beauty_boost_2')) level++;
        if (_unlockedSkillIds.contains('combat_beauty_boost_3')) level++;
        if (_unlockedSkillIds.contains('combat_beauty_boost_4')) level++;
        if (_unlockedSkillIds.contains('combat_beauty_boost_5')) level++;
        break;

      case 'speed':
        if (_unlockedSkillIds.contains('combat_speed_boost_1')) level++;
        if (_unlockedSkillIds.contains('combat_speed_boost_2')) level++;
        if (_unlockedSkillIds.contains('combat_speed_boost_3')) level++;
        if (_unlockedSkillIds.contains('combat_speed_boost_4')) level++;
        if (_unlockedSkillIds.contains('combat_speed_boost_5')) level++;
        break;
    }

    return level;
  }

  // ==================== BREEDER TREE EFFECTS ====================

  /// Check if lineage analyzer is unlocked
  bool hasLineageAnalyzer() {
    return _unlockedSkillIds.contains('breeder_lineage_analyzer');
  }

  /// Check if cross-species breeding is unlocked
  bool hasCrossSpeciesBreeding() {
    return _unlockedSkillIds.contains('breeder_cross_species');
  }

  /// Check if gene analyzer is unlocked
  bool hasGeneAnalyzer() {
    return _unlockedSkillIds.contains('breeder_gene_analyzer');
  }

  /// Check if potential analyzer is unlocked
  bool hasPotentialAnalyzer() {
    return _unlockedSkillIds.contains('breeder_potential_analyzer');
  }

  /// Get total gestation time reduction (percentage)
  double getGestationReduction() {
    double reduction = 0.0;

    if (_unlockedSkillIds.contains('breeder_accelerated_gestation')) {
      reduction += 0.05; // 5%
    }
    if (_unlockedSkillIds.contains('breeder_accelerated_gestation2')) {
      reduction += 0.05; // +5%
    }
    if (_unlockedSkillIds.contains('breeder_accelerated_gestation3')) {
      reduction += 0.05; // +5%
    }

    return reduction; // Max 15% reduction
  }

  /// Get wilderness harvest bonus (percentage)
  double getWildernessHarvestBonus() {
    double bonus = 0.0;

    if (_unlockedSkillIds.contains('breeder_harvesting_wilderness_specimens')) {
      bonus += 0.05; // 5%
    }
    if (_unlockedSkillIds.contains(
      'breeder_harvesting_wilderness_specimens2',
    )) {
      bonus += 0.05; // +5%
    }
    if (_unlockedSkillIds.contains(
      'breeder_harvesting_wilderness_specimens3',
    )) {
      bonus += 0.05; // +5%
    }

    return bonus; // Max 15% bonus
  }

  // ==================== EXTRACTION TREE EFFECTS ====================

  /// Check if resources can be sold at black market
  bool canSellResources() {
    return _unlockedSkillIds.contains('extraction_resource_alchemy');
  }

  /// Get shop price reduction (percentage)
  double getShopPriceReduction() {
    return _unlockedSkillIds.contains('extraction_marketplace_insight')
        ? 0.20
        : 0.0;
  }

  /// Check if wilderness preview is unlocked
  bool hasWildernessPreview() {
    return _unlockedSkillIds.contains('extraction_wilderness_preview');
  }

  /// Check if instant chamber reload is unlocked
  bool hasInstantReload() {
    return _unlockedSkillIds.contains('extraction_instant_reload');
  }

  /// Check if 24/7 black market is unlocked
  bool has24x7BlackMarket() {
    return _unlockedSkillIds.contains('extraction_all_day_market');
  }

  /// Get number of bonus extraction chambers
  int getBonusExtractionChambers() {
    int bonus = 0;

    if (_unlockedSkillIds.contains('extraction_sale_boost_1')) bonus++;
    if (_unlockedSkillIds.contains('extraction_sale_boost_2')) bonus++;
    if (_unlockedSkillIds.contains('extraction_sale_boost_3')) bonus++;

    return bonus;
  }

  /// Get XP boost multiplier
  double getXpBoostMultiplier() {
    double boost = 1.0;

    if (_unlockedSkillIds.contains('exraction_xp_boost_1')) boost += 0.05;
    if (_unlockedSkillIds.contains('exraction_xp_boost_2')) boost += 0.05;
    if (_unlockedSkillIds.contains('exraction_xp_boost_3')) boost += 0.05;

    return boost; // Max 1.15x
  }

  /// Get Alchemon sale price multiplier from Extraction Sale Boost skills.
  /// Each tier adds +5% (max +15%).
  double getAlchemonSaleMultiplier() {
    double mult = 1.0;

    if (_unlockedSkillIds.contains('extraction_sale_boost_1')) mult += 0.05;
    if (_unlockedSkillIds.contains('extraction_sale_boost_2')) mult += 0.05;
    if (_unlockedSkillIds.contains('extraction_sale_boost_3')) mult += 0.05;

    return mult; // Max 1.15x
  }

  // ==================== UTILITY ====================

  /// Check if any skill in a list is unlocked
  bool hasAnySkill(List<String> skillIds) {
    return skillIds.any((id) => _unlockedSkillIds.contains(id));
  }

  /// Get all unlocked skills
  Set<String> get unlockedSkills => Set.from(_unlockedSkillIds);
}
