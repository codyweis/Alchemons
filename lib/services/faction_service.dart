// lib/services/faction_service.dart
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:flutter/material.dart';

class PerkInfo {
  /// Logical identifier, e.g. 'FireBreeder'
  final String code;

  /// Display name, e.g. 'Fire Breeder'
  final String title;

  /// Short description used in UI
  final String description;

  const PerkInfo({
    required this.code,
    required this.title,
    required this.description,
  });
}

/// Each faction can provide perks/traits.
class FactionInfo {
  final String name;
  final String description;
  final String philosophy;
  final List<PerkInfo> perks; // ordered [perk1, perk2]

  const FactionInfo({
    required this.name,
    required this.description,
    required this.philosophy,
    required this.perks,
  });
}

class FactionService extends ChangeNotifier {
  static const String _kFactionKey = 'player_faction_v1';

  final AlchemonsDatabase db;
  String? _cached; // persisted faction id string

  FactionService(this.db);

  // ---------------------------------------------------------------------------
  // Basics
  // ---------------------------------------------------------------------------

  Future<bool> perk2Active() async {
    // Global gate for perk2 (e.g. profile progression).
    final v = await db.settingsDao.getSetting('perk2_unlocked_v1');
    return v == '1';
  }

  bool isVolcanic() => current == FactionId.volcanic;
  bool isWater() => current == FactionId.oceanic;
  bool isAir() => current == FactionId.verdant;
  bool isEarth() => current == FactionId.earthen;

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  static const Map<FactionId, FactionInfo> catalog = {
    FactionId.volcanic: FactionInfo(
      name: "Volcanic",
      philosophy:
          'Transformation through destruction. The forge that reshapes reality. Power that consumes and creates.',
      description:
          'Masters of fire and transmutation, the Volcanic Division believes in radical change through controlled chaos. They see destruction as the first step of creation.',
      perks: [
        PerkInfo(
          code: "FireBreeder",
          title: "Fire Breeder",
          description:
              "50% chance to get half off extraction timers when using two fire specimens",
        ),
        PerkInfo(
          code: "VolcanicHarvester",
          title: "Volcanic Harvester",
          description: "Extreme discounts on volcanic harvesting devices",
        ),
      ],
    ),
    FactionId.oceanic: FactionInfo(
      name: "Oceanic",
      philosophy:
          'Adaptation without resistance. The current that shapes stone. Life that flows through all things.',
      description:
          'Scholars of water and adaptability, the Oceanic Division embraces change as a natural flow. They understand that the greatest strength lies in flexibility.',
      perks: [
        PerkInfo(
          code: "WaterBreeder",
          title: "Water Breeder",
          description:
              "50% chance Water specimens don't lose stamina when breeding together",
        ),
        PerkInfo(
          code: "OceanicHarvester",
          title: "Oceanic Harvester",
          description: "Extreme discounts on oceanic harvesting devices",
        ),
      ],
    ),
    FactionId.verdant: FactionInfo(
      name: "Verdant",
      philosophy:
          'Freedom beyond boundaries. The wind that carries knowledge. Thought that transcends form.',
      description:
          'Seekers of air and knowledge, the Verdant Division pursues understanding without limits. They believe wisdom comes from exploring the unknown.',
      perks: [
        PerkInfo(
          code: "AirDrop",
          title: "AirDrop",
          description: "Unlock an extra extraction chamber",
        ),
        PerkInfo(
          code: "VerdantHarvester",
          title: "Verdant Harvester",
          description: "Extreme discounts on verdant harvesting devices",
        ),
      ],
    ),
    FactionId.earthen: FactionInfo(
      name: "Earthen",
      philosophy:
          'Stability against chaos. The foundation that endures. Wisdom buried in ancient roots.',
      description:
          'Guardians of earth and preservation, the Earthen Division values patience and resilience. They know that true power comes from unshakeable foundations.',
      perks: [
        PerkInfo(
          code: "EarthenSale",
          title: "Earthen Sale",
          description: "50% increase in value to earthen specimens sold",
        ),
        PerkInfo(
          code: "EarthenHarvester",
          title: "Earthen Harvester",
          description: "Extreme discounts on earthen harvesting devices",
        ),
      ],
    ),
  };

  // ---------------------------------------------------------------------------
  // Faction selection
  // ---------------------------------------------------------------------------

  Future<String?> loadId() async {
    final before = _cached;
    _cached ??= await db.settingsDao.getSetting(_kFactionKey);

    if (_cached != null && _cached!.isNotEmpty && current != null) {
      await ensureDefaultPerkState(current!);
    }

    // Prevent redundant rebuilds
    if (before != _cached) {
      notifyListeners();
    }
    return _cached;
  }

  Future<void> setId(FactionId id) async {
    await db.settingsDao.setSetting(_kFactionKey, id.name);
    _cached = id.name;
    await ensureDefaultPerkState(id);
    notifyListeners();
  }

  FactionId? get current {
    final v = _cached;
    if (v == null || v.isEmpty) return null;
    return FactionId.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FactionId.volcanic,
    );
  }

  FactionInfo? get currentInfo => current == null ? null : catalog[current]!;

  // ---------------------------------------------------------------------------
  // Perk unlock persistence
  // ---------------------------------------------------------------------------

  String _perkKey(FactionId id, int perkIndex) =>
      'faction::${id.name}::perk${perkIndex}_unlocked';

  Future<void> ensureDefaultPerkState(FactionId id) async {
    // Perk 1 unlocked, Perk 2 locked by default
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

  /// Test helper for unlocking extra blob slots.
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
      notifyListeners();
      return true;
    }
    return false;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Check for a perk by keyword against its code or title.
  bool hasPerk(String perkKeyword) {
    final info = currentInfo;
    if (info == null) return false;

    final kw = perkKeyword.toLowerCase();
    return info.perks.any(
      (p) =>
          p.code.toLowerCase().contains(kw) ||
          p.title.toLowerCase().contains(kw),
    );
  }

  /// Right now perk1 is always active once you’re in a faction.
  /// If you later want to gate it, wire this into `isPerkUnlocked(1)`.
  bool get perk1Active => true;

  // ---------------------------------------------------------------------------
  // VOLCANIC FACTION PERKS
  // ---------------------------------------------------------------------------

  /// Fire Breeder (Perk 1): 50% chance for half-off extraction timers
  /// when using two fire parents. Returns a time multiplier.
  double fireBreederTimeMultiplier({required bool bothParentsFire}) {
    if (!isVolcanic() || !perk1Active || !bothParentsFire) {
      return 1.0;
    }

    // 50% chance to trigger the perk
    final random = Random();
    final triggered = random.nextDouble() < 0.5;

    return triggered ? 0.5 : 1.0;
  }

  /// For UI: shows whether the Fire Breeder perk *can* apply (not whether it triggered).
  bool canFireBreederApply({required bool bothParentsFire}) {
    return isVolcanic() && perk1Active && bothParentsFire;
  }

  // ---------------------------------------------------------------------------
  // EARTHEN FACTION PERKS
  // ---------------------------------------------------------------------------

  /// Earthen Sale (Perk 1): 50% increase in value when selling earthen specimens.
  double earthenSaleValueMultiplier({required bool isEarthenCreature}) {
    if (!isEarth() || !perk1Active || !isEarthenCreature) {
      return 1.0;
    }
    return 1.5;
  }

  bool canEarthenSaleApply({required bool isEarthenCreature}) {
    return isEarth() && perk1Active && isEarthenCreature;
  }

  // ---------------------------------------------------------------------------
  // WATER FACTION PERKS
  // ---------------------------------------------------------------------------

  /// Water Breeder (Perk 1): 50% chance water specimens don't lose stamina
  /// when breeding together.
  bool waterSkipBreedStamina({required bool bothWater, required bool perk1}) {
    return isWater() && perk1 && bothWater;
  }

  bool get waterSkipWildernessStaminaAfterExpedition =>
      false; // perk2 handled elsewhere

  // ---------------------------------------------------------------------------
  // AIR FACTION PERKS
  // ---------------------------------------------------------------------------

  /// AirDrop (Perk 1): Unlock an extra extraction chamber.
  Future<bool> ensureAirExtraSlotUnlocked() async {
    if (!isAir() || !perk1Active) return false;

    final flag = await db.settingsDao.getSetting('air_slot_applied_v1');
    if (flag == '1') return false;

    await db.incubatorDao.unlockSlot(2); // unlock 3rd slot (id=2 in your seed)
    await db.settingsDao.setSetting('air_slot_applied_v1', '1');
    return true;
  }

  // ---------------------------------------------------------------------------
  // Utility
  // ---------------------------------------------------------------------------

  String _earthKey(String sceneId) {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'earth_landexplorer::$sceneId::${now.year}-$m-$d';
  }
}
