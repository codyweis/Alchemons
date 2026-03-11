// lib/services/boss_upgrade_service.dart
//
// Manages persistent boss-battle squad upgrades.
// Uses Settings DAO key-value store + silver currency.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/boss_upgrades.dart';
import 'package:flutter/foundation.dart';

class BossUpgradeService extends ChangeNotifier {
  final AlchemonsDatabase _db;
  late BossUpgradeState _state;

  BossUpgradeService(this._db) {
    _state = BossUpgradeState();
  }

  BossUpgradeState get state => _state;

  // ── Settings keys ──────────────────────────────────────────────────────────

  static String _upgradeKey(BossSquadUpgrade u) => 'boss.upgrade.${u.name}';

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    final dao = _db.settingsDao;

    final levels = <BossSquadUpgrade, int>{};
    for (final u in BossSquadUpgrade.values) {
      final val = await dao.getSetting(_upgradeKey(u));
      levels[u] = val != null ? (int.tryParse(val) ?? 0) : 0;
    }

    _state = BossUpgradeState(levels: levels);
    notifyListeners();
  }

  // ── Upgrade ────────────────────────────────────────────────────────────────

  Future<bool> upgradeSquadStat(BossSquadUpgrade upgrade) async {
    final currentLevel = _state.getLevel(upgrade);
    final def = getBossSquadUpgradeDef(upgrade);
    if (currentLevel >= def.maxLevel) return false;

    final cost = def.costPerLevel[currentLevel];
    final canAfford = await _db.currencyDao.spendSilver(cost);
    if (!canAfford) return false;

    _state.levels[upgrade] = currentLevel + 1;
    await _db.settingsDao.setSetting(
      _upgradeKey(upgrade),
      (currentLevel + 1).toString(),
    );
    notifyListeners();
    return true;
  }

  // ── Cost queries ───────────────────────────────────────────────────────────

  int? nextCost(BossSquadUpgrade upgrade) {
    final level = _state.getLevel(upgrade);
    final def = getBossSquadUpgradeDef(upgrade);
    if (level >= def.maxLevel) return null;
    return def.costPerLevel[level];
  }
}
