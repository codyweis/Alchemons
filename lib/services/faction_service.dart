// lib/services/faction_service.dart
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:flutter/material.dart';

/// Each faction can provide perks/traits.
class FactionInfo {
  final String name;
  final String description;
  final List<PerkInfo> perks; // ordered [perk1, perk2]

  const FactionInfo({
    required this.name,
    required this.description,
    required this.perks,
  });
}

class FactionService extends ChangeNotifier {
  static const _kFactionKey = 'player_faction_v1';
  final AlchemonsDatabase db;
  String? _cached; // persisted faction id string

  FactionService(this.db);

  Future<bool> perk2Active() async {
    // however you're gating perk2 on Profile — replace with your real check
    // e.g., read a Settings key or use your ProfileViewModel
    final v = await db.settingsDao.getSetting('perk2_unlocked_v1');
    return v == '1';
  }

  bool isFire() => current == FactionId.fire;
  bool isWater() => current == FactionId.water;
  bool isAir() => current == FactionId.air;
  bool isEarth() => current == FactionId.earth;

  // ----------- Catalog -----------
  static Map<FactionId, FactionInfo> catalog = {
    FactionId.fire: const FactionInfo(
      name: "Fire",
      description: "Burn bright and breed faster.",
      perks: [
        PerkInfo(
          name: "HellRaiser",
          description: "5% increased XP to all creatures when leveling",
        ),
        PerkInfo(
          name: "FireBreeder",
          description: "50% off breed timers when using a fire parent",
        ),
      ],
    ),
    FactionId.water: const FactionInfo(
      name: "Water",
      description: "Adapt and flow with stamina mastery.",
      perks: [
        PerkInfo(
          name: "WaterBreeder",
          description:
              "Water creatures don’t lose stamina when breeding together",
        ),
        PerkInfo(
          name: "Aqua Sanctuary",
          description: "After expeditions, water creatures return fully rested",
        ),
      ],
    ),
    FactionId.air: const FactionInfo(
      name: "Air",
      description: "Freedom of the skies, swift discoveries.",
      perks: [
        PerkInfo(name: "AirDrop", description: "Unlock an extra breeding slot"),
        PerkInfo(
          name: "Air Sensory",
          description: "Predict if an egg will hatch to something undiscovered",
        ),
      ],
    ),
    FactionId.earth: const FactionInfo(
      name: "Earth",
      description: "Steady and grounded, explorers of the land.",
      perks: [
        PerkInfo(
          name: "LandExplorer",
          description: "Refresh 1 wildlife encounter instantly once per day",
        ),
        PerkInfo(
          name: "Earther",
          description: "25% increase success rate in wilderness",
        ),
      ],
    ),
  };

  // ----------- Faction selection -----------
  Future<String?> loadId() async {
    final before = _cached;
    _cached ??= await db.settingsDao.getSetting(_kFactionKey);
    if (_cached != null && _cached!.isNotEmpty) {
      await ensureDefaultPerkState(current!);
    }
    // notify only if value changed (prevents redundant rebuilds)
    if (before != _cached) notifyListeners(); // ⬅️ important
    return _cached;
  }

  Future<void> setId(FactionId id) async {
    await db.settingsDao.setSetting(_kFactionKey, id.name);
    _cached = id.name;
    await ensureDefaultPerkState(id);
    notifyListeners(); // ⬅️ important
  }

  FactionId? get current {
    final v = _cached;
    if (v == null || v.isEmpty) return null;
    return FactionId.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FactionId.fire,
    );
  }

  FactionInfo? get currentInfo => current == null ? null : catalog[current]!;

  // ----------- Perk unlock persistence -----------
  String _perkKey(FactionId id, int perkIndex) =>
      'faction::${id.name}::perk${perkIndex}_unlocked';

  Future<void> ensureDefaultPerkState(FactionId id) async {
    // By design: Perk 1 unlocked, Perk 2 locked
    final p1 = await db.settingsDao.getSetting(_perkKey(id, 1));
    final p2 = await db.settingsDao.getSetting(_perkKey(id, 2));
    if (p1 == null) await db.settingsDao.setSetting(_perkKey(id, 1), '1');
    if (p2 == null) await db.settingsDao.setSetting(_perkKey(id, 2), '0');
  }

  Future<bool> isPerkUnlocked(int perkIndex, {FactionId? forId}) async {
    final id = forId ?? current;
    if (id == null) return false;
    final v = await db.settingsDao.getSetting(_perkKey(id, perkIndex));
    return v == '1';
  }

  Future<bool> setBlobSlotsUnlockedTest() async {
    await db.settingsDao.setSetting('blob_slots_unlocked', '3');
    return true;
  }

  Future<void> _setPerkUnlocked(int perkIndex, bool value, {FactionId? forId}) {
    final id = forId ?? current;
    if (id == null) return Future.value();
    return db.settingsDao.setSetting(
      _perkKey(id, perkIndex),
      value ? '1' : '0',
    );
  }

  /// Example condition: unlock perk2 when discovering >= 10 creatures
  static const int perk2DiscoverThreshold = 10;

  Future<int> discoveredCount() async {
    final all = await db.creatureDao.getAllCreatures();
    return all.where((pc) => pc.discovered).length;
  }

  Future<bool> tryUnlockPerk2({FactionId? forId}) async {
    final id = forId ?? current;
    if (id == null) return false;
    if (await isPerkUnlocked(2, forId: id)) return true;

    final discovered = await discoveredCount();
    if (discovered >= perk2DiscoverThreshold) {
      await _setPerkUnlocked(2, true, forId: id);
      notifyListeners(); // optional, if UI cares
      return true;
    }
    return false;
  }

  // ----------- Helper -----------
  bool hasPerk(String perkKeyword) {
    final info = currentInfo;
    if (info == null) return false;
    return info.perks.any(
      (p) => p.toString().toLowerCase().contains(perkKeyword.toLowerCase()),
    );
  }

  bool get perk1Active => true;

  // ---- Fire
  double fireXpMultiplierOnLevelGain() => isFire() && perk1Active ? 1.05 : 1.0;
  double fireHatchTimeMultiplier({
    required bool hasFireParent,
    required bool perk2,
  }) => (isFire() && perk2 && hasFireParent) ? 0.5 : 1.0;

  // ---- Water
  bool waterSkipBreedStamina({required bool bothWater, required bool perk1}) =>
      isWater() && perk1 && bothWater;

  bool get waterSkipWildernessStaminaAfterExpedition =>
      false; // perk2 handled at scene exit with real check

  // ---- Air
  Future<bool> ensureAirExtraSlotUnlocked() async {
    if (!isAir() || !perk1Active) return false;
    final flag = await db.settingsDao.getSetting('air_slot_applied_v1');
    if (flag == '1') return false;
    await db.incubatorDao.unlockSlot(2); // unlock 3rd slot (id=2 in your seed)
    await db.settingsDao.setSetting('air_slot_applied_v1', '1');
    return true;
  }

  bool get airCanPredictUndiscovered => isAir(); // UI hint; gate by perk2 below

  // ---- Earth
  String _earthKey(String sceneId) {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'earth_landexplorer::$sceneId::${now.year}-$m-$d';
  }

  Future<bool> earthCanRefreshToday(String sceneId) async {
    if (!(isEarth() && perk1Active)) return false;
    final used = await db.settingsDao.getSetting(_earthKey(sceneId));
    return (used ?? '').isEmpty;
  }

  Future<void> earthMarkRefreshedToday(String sceneId) async {
    await db.settingsDao.setSetting(_earthKey(sceneId), 'used');
  }

  double earthWildernessSuccessBoost({required bool perk2}) =>
      (isEarth() && perk2) ? 0.25 : 0.0;
}

class PerkInfo {
  final String name;
  final String description;

  const PerkInfo({required this.name, required this.description});
}
