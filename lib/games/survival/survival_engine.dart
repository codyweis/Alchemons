import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Formation positions for strategic gameplay
enum FormationPosition {
  frontLeft(0, true),
  frontRight(1, true),
  backLeft(2, false),
  backRight(3, false);

  final int i;
  final bool isFrontRow;

  const FormationPosition(this.i, this.isFrontRow);

  bool get isBackRow => !isFrontRow;
}

/// Minimal stats used by survival hoard mode.
/// This intentionally avoids the full turn-based BattleCombatant.
class PartyCombatantStats {
  final String id;
  final String name;
  final List<String> types; // element types
  final String family; // Let, Wing, Mystic, etc.
  final int level;

  // 🔹 Optional visuals
  final SpriteSheetDef? sheetDef;
  final SpriteVisuals? spriteVisuals;

  // Base stats in your usual 0–5 range
  final double statSpeed;
  final double statIntelligence;
  final double statStrength;
  final double statBeauty;

  const PartyCombatantStats({
    required this.id,
    required this.name,
    required this.types,
    required this.family,
    required this.level,
    required this.statSpeed,
    required this.statIntelligence,
    required this.statStrength,
    required this.statBeauty,
    this.sheetDef,
    this.spriteVisuals,
  });
}

/// Party member with formation position
class PartyMember {
  final PartyCombatantStats combatant;
  final FormationPosition position;

  PartyMember({required this.combatant, required this.position});
}

/// Helper class to build a party for survival hoard mode
class SurvivalFormationHelper {
  /// Convert formation slots to PartyMember list for the engine
  ///
  /// Expects:
  /// - Active slots: indices 0–3 (FormationPosition indices)
  /// - Bench slots: indices 100–103 (ignored here for now)
  static Future<List<PartyMember>> buildPartyFromFormation({
    required Map<int, String> formationSlots,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
  }) async {
    final party = <PartyMember>[];
    final instances = await db.creatureDao.getAllInstances();

    // --- 1) ACTIVE SLOTS 0–3 ---
    for (var positionIndex = 0; positionIndex < 4; positionIndex++) {
      final instanceId = formationSlots[positionIndex];
      if (instanceId == null) continue;

      final instance = instances
          .where((inst) => inst.instanceId == instanceId)
          .firstOrNull;
      if (instance == null) continue;

      final species = catalog.getCreatureById(instance.baseId);
      if (species == null) continue;

      final sheetDef = sheetFromCreature(species);
      final visuals = visualsFromInstance(species, instance);

      final stats = PartyCombatantStats(
        id: instance.instanceId,
        name: instance.nickname ?? species.name,
        types: species.types,
        family: species.mutationFamily!,
        level: instance.level,
        statSpeed: instance.statSpeed,
        statIntelligence: instance.statIntelligence,
        statStrength: instance.statStrength,
        statBeauty: instance.statBeauty,
        sheetDef: sheetDef,
        spriteVisuals: visuals,
      );

      final position = FormationPosition.values[positionIndex];
      party.add(PartyMember(combatant: stats, position: position));
    }

    // --- 2) BENCH SLOTS 100–199 ---
    // We still wrap them as PartyMember so SurvivalHoardGame
    // can convert them to SurvivalUnit in _initBenchFromParty().
    final benchEntries = formationSlots.entries.where(
      (e) => e.key >= 100 && e.key < 200,
    );

    for (final entry in benchEntries) {
      final instanceId = entry.value;

      final instance = instances
          .where((inst) => inst.instanceId == instanceId)
          .firstOrNull;
      if (instance == null) continue;

      final species = catalog.getCreatureById(instance.baseId);
      if (species == null) continue;

      final sheetDef = sheetFromCreature(species);
      final visuals = visualsFromInstance(species, instance);

      final stats = PartyCombatantStats(
        id: instance.instanceId,
        name: instance.nickname ?? species.name,
        types: species.types,
        family: species.mutationFamily!,
        level: instance.level,
        statSpeed: instance.statSpeed,
        statIntelligence: instance.statIntelligence,
        statStrength: instance.statStrength,
        statBeauty: instance.statBeauty,
        sheetDef: sheetDef,
        spriteVisuals: visuals,
      );

      // FormationPosition is irrelevant for bench; we’ll *not* use these
      // indices in _setupFormation (see next section). Just pick anything.
      party.add(
        PartyMember(combatant: stats, position: FormationPosition.backRight),
      );
    }

    return party;
  }

  /// Validate that formation is complete and valid.
  ///
  /// We only care that:
  /// - All 4 ACTIVE slots (0–3) are filled
  /// - No duplicate instances across active + bench
  static bool isFormationValid(Map<int, String> formationSlots) {
    // 1) Check active slots 0–3 are all present
    final activeIds = <String>[];

    for (var i = 0; i < 4; i++) {
      final id = formationSlots[i];
      if (id == null) {
        return false;
      }
      activeIds.add(id);
    }

    // 2) Gather bench ids (100–103, or more generally 100–199)
    final benchIds = formationSlots.entries
        .where((e) => e.key >= 100 && e.key < 200)
        .map((e) => e.value)
        .toList();

    // 3) Ensure NO duplicates across active + bench
    final allIds = [...activeIds, ...benchIds];
    if (allIds.toSet().length != allIds.length) {
      return false;
    }

    return true;
  }

  /// Optional helper: extract bench instance IDs from formation map
  ///
  /// Bench slots are encoded as keys 100–103 in the formationSlots map.
  static List<String> getBenchInstanceIds(Map<int, String> formationSlots) {
    return formationSlots.entries
        .where((e) => e.key >= 100 && e.key < 200)
        .map((e) => e.value)
        .toList();
  }

  /// Get formation slot labels for UI display
  static String getPositionLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'Front Left';
      case FormationPosition.frontRight:
        return 'Front Right';
      case FormationPosition.backLeft:
        return 'Back Left';
      case FormationPosition.backRight:
        return 'Back Right';
    }
  }

  /// Get abbreviated position label
  static String getPositionShortLabel(FormationPosition position) {
    switch (position) {
      case FormationPosition.frontLeft:
        return 'FL';
      case FormationPosition.frontRight:
        return 'FR';
      case FormationPosition.backLeft:
        return 'BL';
      case FormationPosition.backRight:
        return 'BR';
    }
  }
}

/// Debug helpers for quickly creating a strong test team for survival hoard mode.
class DebugTeams {
  /// "God" team: 4 creatures with formation positions
  static List<PartyMember> makeGodTeam() {
    return [
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_tank',
          name: 'Obsidian Horn',
          types: ['Earth'],
          family: 'Horn',
          level: 10,
          speed: 3.2,
          intelligence: 2.5,
          strength: 5.0,
          beauty: 2.0,
        ),
        position: FormationPosition.frontLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_dps_fire',
          name: 'Solar Let',
          types: ['Fire'],
          family: 'Let',
          level: 10,
          speed: 3.8,
          intelligence: 3.0,
          strength: 5.0,
          beauty: 3.0,
        ),
        position: FormationPosition.frontRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_dps_lightning',
          name: 'Storm Wing',
          types: ['Lightning'],
          family: 'Wing',
          level: 10,
          speed: 5.0,
          intelligence: 3.5,
          strength: 4.2,
          beauty: 2.5,
        ),
        position: FormationPosition.backLeft,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_support',
          name: 'Aurora KIN',
          types: ['Light'],
          family: 'Kin',
          level: 10,
          speed: 3.5,
          intelligence: 5.0,
          strength: 3.0,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_bench1',
          name: 'Aurora PIP',
          types: ['Fire'],
          family: 'Pip',
          level: 10,
          speed: 3.5,
          intelligence: 3.0,
          strength: 3.0,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_bench1',
          name: 'Aurora MANE',
          types: ['Water'],
          family: 'Mane',
          level: 10,
          speed: 3,
          intelligence: 4.0,
          strength: 3.5,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_bench1',
          name: 'poison Mask',
          types: ['Poison'],
          family: 'Mask',
          level: 10,
          speed: 3,
          intelligence: 4.0,
          strength: 3.5,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
      PartyMember(
        combatant: _makeCreature(
          id: 'debug_bench1',
          name: 'Ice Horn',
          types: ['Ice'],
          family: 'Horn',
          level: 10,
          speed: 3,
          intelligence: 4.0,
          strength: 3.5,
          beauty: 4.5,
        ),
        position: FormationPosition.backRight,
      ),
    ];
  }

  static PartyCombatantStats _makeCreature({
    required String id,
    required String name,
    required List<String> types,
    required String family,
    required int level,
    required double speed,
    required double intelligence,
    required double strength,
    required double beauty,
  }) {
    return PartyCombatantStats(
      id: id,
      name: name,
      types: types,
      family: family,
      level: level,
      statSpeed: speed,
      statIntelligence: intelligence,
      statStrength: strength,
      statBeauty: beauty,
    );
  }
}
