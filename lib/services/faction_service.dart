// lib/services/faction_service.dart
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/dock_sets.dart';
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
          title: "Fire Alchemy",
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
          title: "Water Alchemy",
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
          description:
              "50% discount on additional extraction chambers and storage upgrades",
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
    final dockChanged = await _loadDock();

    // Prevent redundant rebuilds
    if (before != _cached || dockChanged) {
      notifyListeners();
    }
    return _cached;
  }

  Future<void> reloadFromStorage() async {
    _cached = null;
    _dockLoaded = false;
    await loadId();
  }

  Future<void> setId(FactionId id) async {
    final before = current;
    await db.settingsDao.setSetting(_kFactionKey, id.name);
    _cached = id.name;
    await ensureDefaultPerkState(id);
    // Every faction joined leaves its own dock set behind, and a new
    // faction's goes on the dock.
    for (final f in {?before, id}) {
      await _ownDockSet(DockSet.of(f));
    }
    if (before != id) await _setWornDockSet(DockSet.of(id));
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
  // The dock (models/dock_sets.dart)
  // ---------------------------------------------------------------------------

  static const String _kDockSetKey = 'dock_set_worn_v1';

  bool _dockLoaded = false;
  String? _wornDockSet;
  final Set<String> _ownedDockSets = {};

  /// The dock set worn: the one chosen while it is owned, otherwise the
  /// faction's own.
  DockSet get dockSet {
    final chosen = DockSet.byId(_wornDockSet);
    if (chosen != null && ownsDockSet(chosen)) return chosen;
    return DockSet.of(current);
  }

  /// Whether [set] is the player's: the faction's own set, any set of a
  /// faction they were in, any set they bought.
  bool ownsDockSet(DockSet set) =>
      set == DockSet.of(current) || _ownedDockSets.contains(set.id);

  /// Puts [set] on the dock, if it is owned.
  Future<void> wearDockSet(DockSet set) async {
    if (!ownsDockSet(set) || set == dockSet) return;
    await _setWornDockSet(set);
    notifyListeners();
  }

  /// [set] bought in the shop: owned, and on the dock.
  Future<void> grantDockSet(DockSet set) async {
    await _ownDockSet(set);
    await _setWornDockSet(set);
    notifyListeners();
  }

  /// Reads which dock sets are owned and which is worn, once; true if that
  /// changed anything.
  Future<bool> _loadDock() async {
    if (_dockLoaded) return false;
    _dockLoaded = true;
    final before = dockSet;
    _wornDockSet = await db.settingsDao.getSetting(_kDockSetKey);
    _ownedDockSets.clear();
    for (final s in kDockSets) {
      if (await db.settingsDao.getSetting(s.settingKey) == '1') {
        _ownedDockSets.add(s.id);
      }
    }
    return dockSet != before;
  }

  Future<void> _ownDockSet(DockSet set) async {
    if (_ownedDockSets.contains(set.id)) return;
    await db.settingsDao.setSetting(set.settingKey, '1');
    _ownedDockSets.add(set.id);
  }

  Future<void> _setWornDockSet(DockSet set) async {
    await db.settingsDao.setSetting(_kDockSetKey, set.id);
    _wornDockSet = set.id;
  }

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

  // ---------------------------------------------------------------------------
  // AIR FACTION PERKS
  // ---------------------------------------------------------------------------

  /// AirDrop (Perk 1): 50% discount on additional extraction chambers and
  /// storage upgrades.
  double get airBubbleSlotCostMultiplier {
    if (!isAir() || !perk1Active) return 1.0;
    return 0.5;
  }

  Map<String, int> discountedBubbleSlotCost(Map<String, int> baseCost) {
    final mult = airBubbleSlotCostMultiplier;
    if (mult >= 1.0) return Map<String, int>.from(baseCost);

    return {
      for (final entry in baseCost.entries)
        entry.key: (entry.value * mult).round(),
    };
  }
}
