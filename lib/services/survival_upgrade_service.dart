// lib/services/survival_upgrade_service.dart
//
// Manages persistent survival upgrades — orb skins, guardian stat boosts,
// and base abilities. Uses Settings DAO key-value store for persistence.

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
  static String _guardianKey(GuardianUpgrade u) =>
      'survival.guardian.${u.name}';
  static String _abilityKey(BaseAbility a) => 'survival.ability.${a.name}';

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final dao = _db.settingsDao;

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

    // Guardian levels
    final guardianLevels = <GuardianUpgrade, int>{};
    for (final u in GuardianUpgrade.values) {
      final val = await dao.getSetting(_guardianKey(u));
      guardianLevels[u] = val != null ? (int.tryParse(val) ?? 0) : 0;
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
      guardianLevels: guardianLevels,
      abilityLevels: abilityLevels,
    );

    notifyListeners();
  }

  // ── Purchase Orb Skin ──────────────────────────────────────────────────────

  Future<bool> purchaseOrbSkin(OrbBaseSkin skin) async {
    if (_state.ownedSkins.contains(skin)) return false;
    final def = getOrbBaseDef(skin);
    if (def.cost <= 0) return false;

    final canAfford = await _db.currencyDao.spendSilver(def.cost);
    if (!canAfford) return false;

    _state.ownedSkins.add(skin);
    await _saveOwnedSkins();
    notifyListeners();
    return true;
  }

  Future<void> equipOrbSkin(OrbBaseSkin skin) async {
    if (!_state.ownedSkins.contains(skin)) return;
    _state.equippedSkin = skin;
    await _db.settingsDao.setSetting(_kEquippedSkin, skin.name);
    notifyListeners();
  }

  // ── Upgrade Guardian Stat ──────────────────────────────────────────────────

  Future<bool> upgradeGuardianStat(GuardianUpgrade upgrade) async {
    final currentLevel = _state.getGuardianLevel(upgrade);
    final def = getGuardianUpgradeDef(upgrade);
    if (currentLevel >= def.maxLevel) return false;

    final cost = def.costPerLevel[currentLevel];
    final canAfford = await _db.currencyDao.spendSilver(cost);
    if (!canAfford) return false;

    _state.guardianLevels[upgrade] = currentLevel + 1;
    await _db.settingsDao.setSetting(
      _guardianKey(upgrade),
      (currentLevel + 1).toString(),
    );
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

  int? nextGuardianCost(GuardianUpgrade upgrade) {
    final level = _state.getGuardianLevel(upgrade);
    final def = getGuardianUpgradeDef(upgrade);
    if (level >= def.maxLevel) return null;
    return def.costPerLevel[level];
  }

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
