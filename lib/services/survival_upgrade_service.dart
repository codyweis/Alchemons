// lib/services/survival_upgrade_service.dart
//
// Manages persistent survival upgrades — orb skins, the five Specials, and
// base abilities. Uses Settings DAO key-value store for persistence.

import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flutter/foundation.dart';

class SurvivalUpgradeService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  late SurvivalUpgradeState _state;

  SurvivalUpgradeService(this._db) {
    _state = SurvivalUpgradeState();
  }

  SurvivalUpgradeState get state => _state;

  // ── Settings keys ──────────────────────────────────────────────────────────

  static const _kEquippedSkin = 'survival.equipped_skin';
  static const _kOwnedSkins = 'survival.owned_skins';
  static String _specialKey(SurvivalSpecial s) => 'survival.special.${s.name}';
  static String _abilityKey(BaseAbility a) => 'survival.ability.${a.name}';

  /// Precision Runes sold critical-hit chance, and no attack ever rolled a
  /// crit. The upgrade is retired; what a player spent on it comes back once.
  static const _kRetiredCritKey = 'survival.guardian.critChance';
  static const _kRetiredCritCostPerLevel = [1000, 5000, 10000, 20000, 50000];

  /// Silver owed for [level] levels of the retired Precision Runes.
  @visibleForTesting
  static int retiredCritRefund(int level) => _kRetiredCritCostPerLevel
      .take(level.clamp(0, _kRetiredCritCostPerLevel.length))
      .fold(0, (sum, cost) => sum + cost);

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final dao = _db.settingsDao;
    await _refundRetiredCritUpgrade();

    // Equipped skin
    final skinStr = await dao.getSetting(_kEquippedSkin);
    final equippedSkin = OrbBaseSkin.values.firstWhere(
      (s) => s.name == skinStr,
      orElse: () => OrbBaseSkin.defaultOrb,
    );

    // Owned skins
    final ownedStr = await dao.getSetting(_kOwnedSkins);
    final ownedSkins = <OrbBaseSkin>{OrbBaseSkin.defaultOrb};
    if (ownedStr != null && ownedStr.isNotEmpty) {
      for (final name in ownedStr.split(',')) {
        final match = OrbBaseSkin.values.where((s) => s.name == name);
        if (match.isNotEmpty) ownedSkins.add(match.first);
      }
    }

    // Specials
    final ownedSpecials = <SurvivalSpecial>{};
    for (final s in SurvivalSpecial.values) {
      if (await dao.getSetting(_specialKey(s)) == '1') ownedSpecials.add(s);
    }

    // Ability levels
    final abilityLevels = <BaseAbility, int>{};
    for (final a in BaseAbility.values) {
      final val = await dao.getSetting(_abilityKey(a));
      abilityLevels[a] = val != null ? (int.tryParse(val) ?? 0) : 0;
    }

    _state = SurvivalUpgradeState(
      equippedSkin: equippedSkin,
      ownedSkins: ownedSkins,
      ownedSpecials: ownedSpecials,
      abilityLevels: abilityLevels,
    );

    notifyListeners();
  }

  /// Pays back the retired Precision Runes and forgets them, in one step so
  /// a crash between the two can neither pay twice nor lose the refund.
  Future<void> _refundRetiredCritUpgrade() async {
    final dao = _db.settingsDao;
    final stored = await dao.getSetting(_kRetiredCritKey);
    if (stored == null) return;
    final refund = retiredCritRefund(int.tryParse(stored) ?? 0);
    await _db.transaction(() async {
      if (refund > 0) await _db.currencyDao.addSilver(refund);
      await dao.deleteSetting(_kRetiredCritKey);
    });
  }

  // ── Purchase Orb Skin ──────────────────────────────────────────────────────

  Future<bool> purchaseOrbSkin(OrbBaseSkin skin) async {
    if (_state.ownedSkins.contains(skin)) return false;
    final def = getOrbBaseDef(skin);
    if (def.cost <= 0) return false;

    final canAfford = await _db.currencyDao.spendGold(def.cost);
    if (!canAfford) return false;

    _state.ownedSkins.add(skin);
    await _saveOwnedSkins();
    notifyListeners();
    return true;
  }

  Future<void> equipOrbSkin(OrbBaseSkin skin) async {
    if (!_state.ownedSkins.contains(skin)) return;
    _state.equippedSkin = skin;
    // Listeners first: the home dock shows this orb, and the saves below can
    // outlast the trip back to it.
    notifyListeners();
    await _db.settingsDao.setSetting(_kEquippedSkin, skin.name);
    // Owning a base is a purchase; carrying one into a run is the thing the
    // achievement is for, so it marks on equip and only for a real choice.
    if (skin != OrbBaseSkin.defaultOrb) {
      await CampaignJournalService.mark(_db.settingsDao, 'orbSkin');
    }
  }

  // ── Buy a Special ──────────────────────────────────────────────────────────

  /// Buys [special] for its silver price. False when it is already owned or
  /// the silver is short. The silver and the purchase are one step, so a crash
  /// between them cannot take the silver and leave the Special unbought.
  Future<bool> purchaseSpecial(SurvivalSpecial special) async {
    if (_state.ownsSpecial(special)) return false;
    final def = getSurvivalSpecialDef(special);
    final bought = await _db.transaction(() async {
      if (!await _db.currencyDao.spendSilver(def.cost)) return false;
      await _db.settingsDao.setSetting(_specialKey(special), '1');
      return true;
    });
    if (!bought) return false;
    _state.ownedSpecials.add(special);
    notifyListeners();
    return true;
  }

  // ── Upgrade Base Ability ───────────────────────────────────────────────────

  Future<bool> upgradeBaseAbility(BaseAbility ability) async {
    final currentLevel = _state.getAbilityLevel(ability);
    final def = getBaseAbilityDef(ability);
    if (currentLevel >= def.maxLevel) return false;

    final cost = def.costPerLevel[currentLevel];
    final canAfford = await _db.currencyDao.spendSilver(cost);
    if (!canAfford) return false;

    _state.abilityLevels[ability] = currentLevel + 1;
    await _db.settingsDao.setSetting(
      _abilityKey(ability),
      (currentLevel + 1).toString(),
    );
    notifyListeners();
    return true;
  }

  // ── Silver cost queries ─────────────────────────────────────────────────────

  int? nextAbilityCost(BaseAbility ability) {
    final level = _state.getAbilityLevel(ability);
    final def = getBaseAbilityDef(ability);
    if (level >= def.maxLevel) return null;
    return def.costPerLevel[level];
  }

  // ── Persistence helpers ────────────────────────────────────────────────────

  Future<void> _saveOwnedSkins() async {
    final str = _state.ownedSkins.map((s) => s.name).join(',');
    await _db.settingsDao.setSetting(_kOwnedSkins, str);
  }
}
