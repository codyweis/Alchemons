// lib/services/encounter_service.dart
import 'dart:math';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/encounters/wild_spawn.dart';
import 'package:alchemons/models/wilderness.dart'
    show PartyMember, WildEncounter;
import 'package:alchemons/models/scenes/scene_definition.dart';
import 'package:alchemons/utils/wilderness/weighted_picker.dart';
import 'package:flutter/foundation.dart';

/// Result of a roll
class EncounterRoll {
  final String speciesId;
  final EncounterRarity rarity;
  final String? spawnId; // NEW: carry which spawn produced this (optional here)
  EncounterRoll({required this.speciesId, required this.rarity, this.spawnId});
}

/// Build your scene-specific pools here.
/// You can also provide per-spawn overrides (keyed by Spawn.id).
typedef SceneEncounterTables = ({
  EncounterPool sceneWide,
  Map<String, EncounterPool> perSpawn,
});

class EncounterService extends ChangeNotifier {
  final SceneDefinition scene;
  final List<PartyMember> party;
  final Random _rng;
  final SceneEncounterTables Function(SceneDefinition) _tableBuilder;

  // Active spawns in the scene
  final List<WildSpawn> _spawns = [];

  // Optional: pity counter to slightly increase higher-rarity odds over time
  int _dryStreak = 0;

  EncounterService({
    required this.scene,
    required this.party,
    required SceneEncounterTables Function(SceneDefinition) tableBuilder,
    int? seed,
  }) : _tableBuilder = tableBuilder,
       _rng = Random(seed ?? _deriveSeed(scene, party));

  static int _deriveSeed(SceneDefinition scene, List<PartyMember> party) {
    final base = DateTime.now().millisecondsSinceEpoch;
    final partyHash = party.fold<int>(0, (h, m) => h ^ m.instanceId.hashCode);
    final sceneHash = scene.hashCode;
    return base ^ partyHash ^ sceneHash;
  }

  /// Slightly increases the odds of high-rarity the longer we go without it.
  double get pityMul {
    if (_dryStreak <= 3) return 1.0;
    // each dry roll beyond 3 boosts high-rarity by ~5% multiplicatively
    return 1.0 + min(0.5, (_dryStreak - 3) * 0.05); // cap at +50%
  }

  /// Roll an encounter for a specific spawn id (optional). If spawnId is null, use scene-wide table.
  EncounterRoll roll({String? spawnId}) {
    final tables = _tableBuilder(scene);
    final table =
        (spawnId != null ? tables.perSpawn[spawnId] : null) ?? tables.sceneWide;

    final now = DateTime.now();
    final choices = <WeightedChoice<EncounterEntry>>[];

    for (final e in table.entries) {
      var w = e.effectiveWeight(now);
      if (w <= 0) continue;

      final rarityBias = switch (e.rarity) {
        EncounterRarity.common => 0.2,
        EncounterRarity.uncommon => 0.4,
        EncounterRarity.rare => 0.8,
        EncounterRarity.legendary => 1.6,
      };
      w *= (1.0 + 0.0 * rarityBias);

      if (e.rarity.index >= EncounterRarity.rare.index) {
        w *= pityMul;
      }
      choices.add(WeightedChoice(e, w));
    }

    // Fallback if nothing eligible:
    if (choices.isEmpty) {
      final fb = tables.sceneWide.entries.firstWhere(
        (e) => e.rarity == EncounterRarity.common && e.effectiveWeight(now) > 0,
        orElse: () => tables.sceneWide.entries.first,
      );
      _dryStreak = (fb.rarity.index >= EncounterRarity.rare.index)
          ? 0
          : _dryStreak + 1;
      return EncounterRoll(
        speciesId: fb.speciesId,
        rarity: fb.rarity,
        spawnId: spawnId,
      );
    }

    final picker = WeightedPicker(choices);
    final picked = picker.pick(_rng);

    _dryStreak = (picked.rarity.index >= EncounterRarity.rare.index)
        ? 0
        : _dryStreak + 1;
    return EncounterRoll(
      speciesId: picked.speciesId,
      rarity: picked.rarity,
      spawnId: spawnId,
    );
  }

  String? pickRandomSpawnPointId() {
    if (scene.spawnPoints.isEmpty) return null;
    return scene.spawnPoints[_rng.nextInt(scene.spawnPoints.length)].id;
  }

  /// Force spawn at a specific point (for wilderness spawn service integration)
  void forceSpawnAt(String spawnPointId, WildEncounter encounter) {
    final spawnPoint = scene.spawnPoints.firstWhere(
      (sp) => sp.id == spawnPointId,
      orElse: () => throw Exception('Spawn point $spawnPointId not found'),
    );

    // Convert WildEncounter to WildSpawn
    final spawn = WildSpawn(
      speciesId: encounter.wildBaseId,
      rarity: EncounterRarityX.parse(encounter.rarity),
      spawnPointId: spawnPointId,
    );

    // Remove any existing spawn at this point
    _spawns.removeWhere((s) => s.spawnPointId == spawnPointId);

    // Add new spawn
    _spawns.add(spawn);
    notifyListeners();

    debugPrint('🎯 Forced spawn: ${encounter.wildBaseId} at $spawnPointId');
  }

  /// Get active spawns
  List<WildSpawn> get spawns => List.unmodifiable(_spawns);

  /// Clear all spawns (when leaving scene)
  void clearSpawns() {
    _spawns.clear();
    notifyListeners();
  }
}
