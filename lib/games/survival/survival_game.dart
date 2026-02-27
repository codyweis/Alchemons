import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/guardian_inspect_hud.dart';
import 'package:alchemons/games/survival/components/guardian_slot_indicator.dart';
import 'package:alchemons/games/survival/components/survival_hud.dart';
import 'package:alchemons/games/survival/scaling_system.dart';
import 'package:alchemons/games/survival/special_attacks/ability_config.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/enemies/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_spawner_v2.dart';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

class WavePhase {
  final int startWave;
  final double waveDuration; // seconds per wave
  final int waveCount; // number of waves in this phase (or -1 for infinite)

  const WavePhase({
    required this.startWave,
    required this.waveDuration,
    required this.waveCount,
  });
}

class GuardianSlot {
  final int index;
  final Vector2 offset; // relative to orb
  String? boundUnitId; // once set, only this unit can ever use this slot
  HoardGuardian? guardian; // currently spawned guardian in this slot

  GuardianSlot({
    required this.index,
    required this.offset,
    this.boundUnitId,
    this.guardian,
  });

  bool get isEmpty => guardian == null;
  bool get isUnbound => boundUnitId == null;
}

enum AlchemyUpgradeKind { maxHp, deployBench, specialAbility, orbHeal }

class AlchemyChoiceOption {
  final AlchemyUpgradeKind kind;
  final String label;
  final String description;
  final SurvivalUnit? targetUnit; // Specific target for the option

  const AlchemyChoiceOption({
    required this.kind,
    required this.label,
    required this.description,
    this.targetUnit,
  });
}

class AlchemyChoiceState {
  final List<AlchemyChoiceOption> options;
  const AlchemyChoiceState(this.options);
}

class SurvivalGameStats {
  final int kills;
  final int score;
  final double timeElapsed;
  final int wave;

  SurvivalGameStats({
    required this.kills,
    required this.score,
    required this.timeElapsed,
    required this.wave,
  });

  String get formattedTime {
    final minutes = (timeElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeElapsed % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String get formattedWave => 'Wave $wave';
}

class SurvivalHoardGame extends FlameGame
    with HasCollisionDetection, ScaleDetector {
  final List<PartyMember> party;
  final VoidCallback onGameOver;

  late World world;
  late CameraComponent cameraComponent;
  late AlchemyOrb orb;

  final List<HoardGuardian> _guardians = [];
  final List<HoardEnemy> _enemies = [];
  final Map<int, List<HoardEnemy>> _enemySpatialGrid = {};
  final List<SurvivalUnit> _benchUnits = [];
  final List<GuardianSlot> _slots = [];
  SurvivalUnit? _pendingDeployUnit; // waiting for player to pick a slot
  static const double _enemyGridCellSize = 220.0;

  // ADDED: Death cascade manager for chain kill effects
  DeathCascadeManager? deathCascade;

  int _totalChoicesMade = 0; // Track how many times we've leveled up
  int _killsSinceLastChoice = 0;

  int get totalChoicesMade => _totalChoicesMade;

  List<HoardEnemy> get enemies => _enemies;
  int get enemyCount => enemies.length;

  // Calculate cost dynamically: Base 80 + (50 per Level)
  // transmutation progression
  int get _killsRequiredForNextLevel => 40 + (_totalChoicesMade * 20);

  int get killsSinceLastChoice => _killsSinceLastChoice;
  int get killsRequiredForNextLevel => _killsRequiredForNextLevel;

  // Tracks upgrade history: { 'unit_id': { AlchemyUpgradeKind.strength: 2 } }
  final Map<String, Map<AlchemyUpgradeKind, int>> _unitUpgradeCounts = {};
  final Map<String, Map<String, int>> _specialAbilityUpgradeRanks = {};

  final ValueNotifier<HoardGuardian?> selectedGuardianNotifier =
      ValueNotifier<HoardGuardian?>(null);

  Vector2? _lastFocalPoint;
  final math.Random _rng = math.Random();

  // Convenience helpers:
  void selectGuardian(HoardGuardian? guardian) {
    selectedGuardianNotifier.value = guardian;
  }

  // Expose upgrade ranks for HUD:
  int getTransmuteRank(String unitId) {
    return _unitUpgradeCounts[unitId]?[AlchemyUpgradeKind.maxHp] ?? 0;
  }

  int getSpecialRankForUnit(SurvivalUnit unit) {
    final element = unit.types.firstOrNull ?? 'Normal';
    return getSpecialAbilityRank(unit.id, element);
  }

  int kills = 0;
  int score = 0;
  double timeElapsed = 0;
  bool isGameOver = false;
  bool isInAlchemyPause = false;
  double _simulationSpeed = 1.0;

  double get simulationSpeed => _simulationSpeed;
  void setSimulationSpeed(double value) {
    _simulationSpeed = value.clamp(0.5, 4.0);
  }

  final ValueNotifier<SurvivalGameStats> statsNotifier = ValueNotifier(
    SurvivalGameStats(kills: 0, score: 0, timeElapsed: 0, wave: 1),
  );

  final ValueNotifier<AlchemyChoiceState?> alchemyChoiceNotifier =
      ValueNotifier<AlchemyChoiceState?>(null);

  SurvivalHoardGame({required this.party, required this.onGameOver});

  List<HoardGuardian> get guardians => _guardians;

  // Public getters for Spawner
  bool get bossAlive => _enemies.any((e) => e.isBoss && !e.isDead);

  final List<WavePhase> wavePhases = [
    WavePhase(startWave: 1, waveDuration: 10.0, waveCount: 20), // waves 1–20
    WavePhase(startWave: 21, waveDuration: 15.0, waveCount: 10), // waves 21–30
    WavePhase(startWave: 31, waveDuration: 20.0, waveCount: -1), // waves 31+
  ];

  int get currentWave {
    double time = timeElapsed.clamp(0, double.infinity);

    for (final phase in wavePhases) {
      final bool isInfinite = phase.waveCount == -1;
      final double phaseDuration = isInfinite
          ? double.infinity
          : phase.waveDuration * phase.waveCount;

      if (time < phaseDuration) {
        final int waveIndex = (time / phase.waveDuration).floor();
        final int rawWave = phase.startWave + waveIndex;

        // Clamp to the phase's max wave if finite
        if (!isInfinite) {
          final int maxWave = phase.startWave + phase.waveCount - 1;
          return rawWave.clamp(phase.startWave, maxWave);
        }

        return rawWave; // infinite phase
      }

      time -= phaseDuration;
    }

    // Should never happen if wavePhases includes an infinite phase.
    return wavePhases.last.startWave;
  }

  int getSpecialAbilityRank(String unitId, String element) {
    final byElement = _specialAbilityUpgradeRanks[unitId];
    if (byElement == null) return 0;
    return byElement[element] ?? 0;
  }

  void incrementSpecialAbilityRank(String unitId, String element) {
    const int maxTier = 3; // 0–3: locked + 3 power ups

    _specialAbilityUpgradeRanks.putIfAbsent(unitId, () => {});
    final current = _specialAbilityUpgradeRanks[unitId]![element] ?? 0;

    if (current >= maxTier) {
      // Already maxed, do nothing.
      return;
    }

    _specialAbilityUpgradeRanks[unitId]![element] = current + 1;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    world = World();
    cameraComponent = CameraComponent(world: world)
      ..viewfinder.anchor = Anchor.center
      ..viewfinder.zoom = .4;

    add(world);
    add(cameraComponent);

    orb = AlchemyOrb(maxHp: 500);
    world.add(orb);

    _initGuardianSlots();

    // Add the spawner (v3 has wave surges)
    add(ImprovedSurvivalSpawner());

    // ADDED: Initialize death cascade manager for chain kill effects
    deathCascade = DeathCascadeManager();
    add(deathCascade!);

    _setupFormation();
    _initBenchFromParty();
    cameraComponent.viewport.add(SurvivalHud());

    cameraComponent.viewport.add(GuardianInspectHud());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final rect = canvas.getLocalClipBounds();
    if (!rect.isEmpty) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.85)],
          stops: const [0.6, 1.0],
          radius: 0.8,
        ).createShader(rect);

      canvas.drawRect(rect, paint);
    }
  }

  void _initGuardianSlots() {
    // We maintain 'index' outside the loop to ensure unique IDs across all rings
    int globalSlotIndex = 0;

    void addRing(double radius, int count, {double angleOffset = 0}) {
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * math.pi * 2 + angleOffset;
        final offset = Vector2(
          math.cos(angle) * radius,
          math.sin(angle) * radius,
        );

        _slots.add(GuardianSlot(index: globalSlotIndex++, offset: offset));
      }
    }

    // RING 1 (Inner Defense) - Close to orb, for tanks (Horn, Mask)
    // 8 slots, tightly packed for frontline defense
    addRing(350.0, 8, angleOffset: -math.pi / 2);

    // RING 2 (Mid Inner) - NEW! Fills the old gap between 400→750
    // 10 slots for mid-range attackers (Mane, Kin, Mystic)
    addRing(550.0, 10, angleOffset: math.pi / 10);

    // RING 3 (Mid Outer) - Standard ranged positions
    // 12 slots for general crowd control
    addRing(780.0, 12, angleOffset: 0);

    // RING 4 (Long Range) - Sniper positions (Wing, Pip, Let)
    // 14 slots for long-range damage dealers
    addRing(1000.0, 14, angleOffset: math.pi / 7);

    // RING 5 (Outpost) - Far interception
    // 16 slots for early interception of incoming waves
    addRing(1250.0, 16, angleOffset: 0);
  }

  void _initBenchFromParty() {
    // If party has more than 4, put the rest on bench
    if (party.length <= 4) return;

    for (int i = 4; i < party.length; i++) {
      final member = party[i];
      final c = member.combatant;

      final unit = SurvivalUnit(
        id: '${c.id}_bench$i',
        name: c.name,
        types: c.types,
        family: c.family,
        level: c.level,
        statSpeed: c.statSpeed,
        statIntelligence: c.statIntelligence,
        statStrength: c.statStrength,
        statBeauty: c.statBeauty,
        sheetDef: c.sheetDef,
        spriteVisuals: c.spriteVisuals,
      );

      // Apply scaling once so bench units are on the same power curve
      _applyScalingToGuardian(unit);

      _benchUnits.add(unit);
    }
  }
  // --- HELPERS ---

  int _cellKey(int cellX, int cellY) {
    return (cellX * 73856093) ^ (cellY * 19349663);
  }

  void _rebuildEnemySpatialGrid() {
    _enemySpatialGrid.clear();
    for (final enemy in _enemies) {
      if (enemy.isDead) continue;
      final cellX = (enemy.position.x / _enemyGridCellSize).floor();
      final cellY = (enemy.position.y / _enemyGridCellSize).floor();
      final key = _cellKey(cellX, cellY);
      (_enemySpatialGrid[key] ??= <HoardEnemy>[]).add(enemy);
    }
  }

  List<HoardEnemy> _getEnemyCandidatesInRange(Vector2 center, double range) {
    if (_enemySpatialGrid.isEmpty && _enemies.isNotEmpty) {
      _rebuildEnemySpatialGrid();
    }

    final minX = ((center.x - range) / _enemyGridCellSize).floor();
    final maxX = ((center.x + range) / _enemyGridCellSize).floor();
    final minY = ((center.y - range) / _enemyGridCellSize).floor();
    final maxY = ((center.y + range) / _enemyGridCellSize).floor();

    final result = <HoardEnemy>[];
    for (int cellX = minX; cellX <= maxX; cellX++) {
      for (int cellY = minY; cellY <= maxY; cellY++) {
        final bucket = _enemySpatialGrid[_cellKey(cellX, cellY)];
        if (bucket != null) result.addAll(bucket);
      }
    }
    return result;
  }

  void addHoardEnemy(HoardEnemy enemy) {
    _enemies.add(enemy);
    world.add(enemy);
  }

  List<HoardEnemy> getEnemiesInRange(Vector2 center, double range) {
    final result = <HoardEnemy>[];
    final rangeSq = range * range;
    for (final enemy in _getEnemyCandidatesInRange(center, range)) {
      if (enemy.isDead) continue;
      if (center.distanceToSquared(enemy.position) <= rangeSq) {
        result.add(enemy);
      }
    }
    return result;
  }

  void confirmDeployAtSlot(int slotIndex) {
    final unit = _pendingDeployUnit;
    if (unit == null) return;

    if (slotIndex < 0 || slotIndex >= _slots.length) {
      return;
    }

    final slot = _slots[slotIndex];

    // Slot must be empty
    if (!slot.isEmpty) {
      return;
    }

    // If already bound, it must be bound to THIS unit
    if (slot.boundUnitId != null && slot.boundUnitId != unit.id) {
      return;
    }

    // Bind this slot permanently to this unit (if it wasn't already)
    if (slot.isUnbound) {
      slot.boundUnitId = unit.id;
    }

    final guardian = HoardGuardian(
      unit: unit,
      position: orb.position + slot.offset,
    );

    slot.guardian = guardian;
    _guardians.add(guardian);
    world.add(guardian);

    // Mystics arrive with orbitals already active (rank 1).
    // They're unique altar-summoned creatures — no need to unlock first.
    if (unit.family == 'Mystic') {
      final elem = unit.types.firstOrNull ?? 'Normal';
      if (getSpecialAbilityRank(unit.id, elem) <= 0) {
        incrementSpecialAbilityRank(unit.id, elem);
      }
    }

    // Cleanup
    _pendingDeployUnit = null;

    // Remove all indicators
    for (final c
        in world.children.whereType<GuardianSlotIndicator>().toList()) {
      c.removeFromParent();
    }

    isInAlchemyPause = false;
  }

  HoardGuardian? getRandomGuardianInRange({
    required Vector2 center,
    required double range,
  }) {
    final rangeSq = range * range;
    HoardGuardian? selected;
    int seen = 0;

    for (final guardian in _guardians) {
      if (guardian.isDead) continue;
      if (center.distanceToSquared(guardian.position) > rangeSq) continue;

      seen++;
      if (_rng.nextInt(seen) == 0) {
        selected = guardian;
      }
    }

    return selected;
  }

  List<HoardGuardian> getGuardiansInRange({
    required Vector2 center,
    required double range,
  }) {
    final result = <HoardGuardian>[];
    for (final guardian in _guardians) {
      if (guardian.isDead) continue;
      final dist = guardian.position.distanceTo(center);
      if (dist <= range) {
        result.add(guardian);
      }
    }
    return result;
  }

  List<HoardEnemy> getRandomEnemies(int count) {
    final liveEnemies = _enemies.where((e) => !e.isDead).toList();
    if (liveEnemies.isEmpty) return [];
    if (liveEnemies.length <= count) return liveEnemies;

    liveEnemies.shuffle();
    return liveEnemies.take(count).toList();
  }

  HoardEnemy? getFurthestEnemy(Vector2 position, double range) {
    HoardEnemy? furthest;
    double maxDstSq = 0;
    final rangeSq = range * range;

    for (final enemy in _getEnemyCandidatesInRange(position, range)) {
      if (enemy.isDead) continue;
      final dstSq = position.distanceToSquared(enemy.position);
      if (dstSq <= rangeSq && dstSq > maxDstSq) {
        maxDstSq = dstSq;
        furthest = enemy;
      }
    }
    return furthest;
  }

  HoardEnemy? getBossEnemyInRange(Vector2 position, double range) {
    HoardEnemy? best;
    double minDstSq = range * range;

    for (final enemy in _getEnemyCandidatesInRange(position, range)) {
      if (enemy.isDead || !enemy.isBoss) continue;
      final dstSq = position.distanceToSquared(enemy.position);
      if (dstSq < minDstSq) {
        minDstSq = dstSq;
        best = enemy;
      }
    }

    return best;
  }

  HoardEnemy? pickTargetForGuardian(HoardGuardian guardian) {
    final pos = guardian.position;
    final range = guardian.unit.attackRange;

    switch (guardian.targetPriority) {
      case TargetPriority.closest:
        return getNearestEnemy(pos, range);

      case TargetPriority.furthest:
        return getFurthestEnemy(pos, range);

      case TargetPriority.boss:
        // Prefer boss, but fall back to closest if none in range.
        return getBossEnemyInRange(pos, range) ?? getNearestEnemy(pos, range);
    }
  }

  HoardEnemy? getNearestEnemy(Vector2 position, double range) {
    HoardEnemy? nearest;
    double minDstSq = range * range;

    for (final enemy in _getEnemyCandidatesInRange(position, range)) {
      if (enemy.isDead) continue;
      final dstSq = position.distanceToSquared(enemy.position);
      if (dstSq < minDstSq) {
        minDstSq = dstSq;
        nearest = enemy;
      }
    }
    return nearest;
  }

  // --- GAME LOOP ---
  @override
  void update(double dt) {
    if (isGameOver) return;

    if (isInAlchemyPause) {
      super.update(0);
      return;
    }

    final scaledDt = dt * _simulationSpeed;
    _rebuildEnemySpatialGrid();
    super.update(scaledDt);

    timeElapsed += scaledDt;

    // Update LOD system with current enemy count for performance scaling
    ImprovedBlobBody.globalEnemyCount = _enemies.length;

    // 🔮 keep the transmutation ring in sync with kill progress
    orb.setTransmutationProgress(
      currentKills: _killsSinceLastChoice,
      requiredKills: _killsRequiredForNextLevel,
    );

    statsNotifier.value = SurvivalGameStats(
      kills: kills,
      score: score,
      timeElapsed: timeElapsed,
      wave: currentWave,
    );

    if (orb.isDestroyed) {
      isGameOver = true;
      onGameOver();
    }
  }

  void removeEnemy(HoardEnemy enemy) {
    _enemies.remove(enemy);
    world.remove(enemy);

    // How much this enemy is "worth" for the power-up bar
    final int killValue = enemy.isBoss
        ? 20
        : 1; // tweak 8 → 5 or whatever feels right

    kills +=
        killValue; // or keep a separate visible counter if you want UI to stay "true"
    score += enemy.template.tier.tier * 10 * killValue;

    _handleKillProgression(killValue);
  }

  void removeEnemyWithoutReward(HoardEnemy enemy) {
    _enemies.remove(enemy);
    enemy.removeFromParent();
  }

  void _handleKillProgression(int killValue) {
    if (isGameOver || isInAlchemyPause) return;

    _killsSinceLastChoice += killValue;

    // 🔮 update orb fill immediately when kills change
    orb.setTransmutationProgress(
      currentKills: _killsSinceLastChoice,
      requiredKills: _killsRequiredForNextLevel,
    );

    if (_killsSinceLastChoice >= _killsRequiredForNextLevel) {
      _killsSinceLastChoice = 0;
      _totalChoicesMade++;
      _triggerAlchemyChoice();
    }
  }

  // --- ALCHEMY CHOICE LOGIC ---

  void _triggerAlchemyChoice() {
    isInAlchemyPause = true;

    final List<AlchemyChoiceOption> candidates = [];

    const int maxAbilityTier = 3; // 3 power ups for elemental special
    const int maxTransmuteRank = 5; // keep 5 steps for Transmute if you like

    // 1. Generate "Deploy from Bench" Candidates
    // Only show these if there is actually room on the field (limit 8 active for balance, or use _slots.length)
    // Check if we have empty slots available
    final hasSpace = _slots.any((s) => s.isEmpty);

    // Only one Mystic is allowed on the field at a time.
    final hasMysticDeployed = _guardians.any(
      (g) => !g.isDead && g.unit.family == 'Mystic',
    );

    if (hasSpace) {
      for (final benchUnit in _benchUnits) {
        // Enforce 1-Mystic limit: hide the option when one is already active.
        if (benchUnit.family == 'Mystic' && hasMysticDeployed) continue;

        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.deployBench,
            label: 'Deploy ${benchUnit.name}',
            description: benchUnit.family == 'Mystic'
                ? 'Summon ${benchUnit.name} — the singular Mystic guardian.'
                : 'Summon ${benchUnit.name} to join the defense.',
            targetUnit: benchUnit,
          ),
        );
      }
    }

    // 2. Generate Upgrade Candidates for Active Guardians
    final livingGuardians = _guardians.where((g) => !g.isDead).toList();

    for (final g in livingGuardians) {
      final unit = g.unit;
      final element = unit.types.firstOrNull ?? 'Normal';

      // --- OPTION A: EMPOWER (Special Ability) ---
      final specialTier = getSpecialAbilityRank(unit.id, element); // 0–3 now
      final nextTier = specialTier + 1;

      if (specialTier < maxAbilityTier) {
        final label = 'Empower ${unit.name}';
        String effectText;

        // Tier 1: use the nice config text (unlock)
        if (nextTier == 1) {
          effectText = describeSpecialRank1(unit);
        } else if (nextTier == 2) {
          // Strengthened – pull from config if you want more flavor
          effectText = AbilitySystemConfig.getAbilityDescription(
            unit.family,
            element,
            2,
          );
        } else {
          // Tier 3: massive update
          effectText = AbilitySystemConfig.getAbilityDescription(
            unit.family,
            element,
            3,
          );
        }

        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.specialAbility,
            label: label,
            description:
                '$effectText\n(${element} Special • Tier $nextTier of $maxAbilityTier)',
            targetUnit: unit,
          ),
        );
      }

      // --- OPTION B: TRANSMUTE (All Stats) ---
      final transmuteRank = _getUpgradeRank(
        g.unit.id,
        AlchemyUpgradeKind.maxHp,
      );

      if (transmuteRank < maxTransmuteRank) {
        final nextRank = transmuteRank + 1;
        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.maxHp,
            label: 'Transmute ${g.unit.name}',
            description:
                '+7.5% HP & +10% core stats\n(Rank $nextRank of $maxTransmuteRank)',
            targetUnit: g.unit,
          ),
        );
      }
    }

    // 3. Fallback: If we don't have enough options to fill 4 slots, add generic heals
    while (candidates.length < 4) {
      candidates.add(
        AlchemyChoiceOption(
          kind: AlchemyUpgradeKind.orbHeal,
          label: "Restoration",
          description: "Heal the Alchemy Orb by 200 HP.",
          targetUnit: null, // doesn't need a unit
        ),
      );

      // If there is literally nothing else to offer, break to avoid infinite loop
      if (livingGuardians.isEmpty && !hasSpace) break;
    }
    // 4. Select exactly 4 Options (or fewer if total candidates < 4)
    candidates.shuffle();
    final selectedOptions = candidates.take(4).toList();

    if (selectedOptions.isEmpty) {
      isInAlchemyPause = false;
      return;
    }

    alchemyChoiceNotifier.value = AlchemyChoiceState(selectedOptions);
  }

  int _getUpgradeRank(String unitId, AlchemyUpgradeKind kind) {
    if (!_unitUpgradeCounts.containsKey(unitId)) {
      _unitUpgradeCounts[unitId] = {};
    }
    return _unitUpgradeCounts[unitId]![kind] ?? 0;
  }

  void _incrementUpgradeRank(String unitId, AlchemyUpgradeKind kind) {
    if (!_unitUpgradeCounts.containsKey(unitId)) {
      _unitUpgradeCounts[unitId] = {};
    }
    final current = _unitUpgradeCounts[unitId]![kind] ?? 0;
    _unitUpgradeCounts[unitId]![kind] = current + 1;
  }

  void applyAlchemyChoice(AlchemyChoiceOption option) {
    // Global options that don't need a unit
    if (option.kind == AlchemyUpgradeKind.orbHeal) {
      if (!orb.isDestroyed) {
        orb.heal(200);
      }
      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      return;
    }

    // Everything below here requires a unit
    final unit = option.targetUnit;
    if (unit == null) {
      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      return;
    }

    // Bench deploy stays as-is
    if (option.kind == AlchemyUpgradeKind.deployBench) {
      _startDeployFromBench(unit);
      return;
    }

    if (option.kind == AlchemyUpgradeKind.specialAbility) {
      final element = unit.types.firstOrNull ?? 'Normal';
      incrementSpecialAbilityRank(unit.id, element);

      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      return;
    }

    // 3) Otherwise: ENHANCE (Transmute) → buff every category
    double scaleGain(double stat) {
      return math.max(0.2, stat * 0.10);
    }

    unit.statStrength += scaleGain(unit.statStrength);
    unit.statIntelligence += scaleGain(unit.statIntelligence);
    unit.statBeauty += scaleGain(unit.statBeauty);
    unit.statSpeed += scaleGain(unit.statSpeed);

    unit.maxHp = (unit.maxHp * 1.075).round();

    unit.calculateCombatStats();
    _applyScalingToGuardian(unit);

    unit.currentHp = unit.maxHp;

    _incrementUpgradeRank(unit.id, AlchemyUpgradeKind.maxHp);

    alchemyChoiceNotifier.value = null;
    isInAlchemyPause = false;
  }

  void _startDeployFromBench(SurvivalUnit unit) {
    // Hard enforce: only one Mystic may be active at a time.
    if (unit.family == 'Mystic') {
      final alreadyHasMystic = _guardians.any(
        (g) => !g.isDead && g.unit.family == 'Mystic',
      );
      if (alreadyHasMystic) {
        // Put the unit back on the bench and resume.
        _benchUnits.add(unit);
        _pendingDeployUnit = null;
        alchemyChoiceNotifier.value = null;
        isInAlchemyPause = false;
        return;
      }
    }

    _pendingDeployUnit = unit;

    // Only slots that are currently empty AND either unbound or already this unit's seat.
    final availableSlots = _slots.where((s) {
      if (!s.isEmpty) return false;
      if (s.boundUnitId == null) return true;
      return s.boundUnitId == unit.id;
    }).toList();

    // Safety: if there are no valid slots, bail out and resume the game.
    if (availableSlots.isEmpty) {
      _pendingDeployUnit = null;
      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      return;
    }

    // Remove from bench immediately so we don't see it again
    _benchUnits.removeWhere((u) => u.id == unit.id);

    // Hide the choice UI now
    alchemyChoiceNotifier.value = null;

    // Sort slots by preference: family-appropriate rings first
    // This makes the "best" slots appear first/highlighted for the player
    final preferredRadius = _getPreferredRadius(unit.family);
    availableSlots.sort((a, b) {
      final aDist = (a.offset.length - preferredRadius).abs();
      final bDist = (b.offset.length - preferredRadius).abs();
      return aDist.compareTo(bDist);
    });

    // Spawn glowing slot indicators (preferred slots shown first)
    for (final slot in availableSlots) {
      world.add(
        GuardianSlotIndicator(
          slotIndex: slot.index,
          position: orb.position + slot.offset,
        ),
      );
    }

    // Game remains paused until a slot is tapped.
  }

  /// Returns the ideal ring radius for a given guardian family
  double _getPreferredRadius(String family) {
    switch (family.toLowerCase()) {
      case 'horn':
      case 'mask':
        return 350.0; // Ring 1: close-range tank
      case 'kin':
      case 'mystic':
      case 'mane':
        return 550.0; // Ring 2: mid-range support
      case 'wing':
      case 'pip':
        return 1000.0; // Ring 4: long-range sniper
      case 'let':
        return 780.0; // Ring 3: mid-range mage
      default:
        return 550.0;
    }
  }
  // --- PROJECTILES & COMBAT ---

  void spawnAlchemyProjectile({
    required Vector2 start,
    required PositionComponent target,
    required int damage,
    required Color color,
    required ProjectileShape shape,
    required double speed,
    bool isEnemy = false,
    VoidCallback? onHit,
  }) {
    final projectile = AlchemyProjectile(
      start: start,
      end: target.position,
      color: color,
      shape: shape,
      speedMultiplier: speed,
      onHit:
          onHit ??
          () {
            if (target is HoardEnemy) {
              target.takeDamage(damage);
            } else if (target is HoardGuardian) {
              target.takeDamage(damage);
            } else if (target is AlchemyOrb) {
              target.takeDamage(damage);
            }
          },
    );
    world.add(projectile);
  }

  void _applyScalingToGuardian(SurvivalUnit unit) {
    final counts = _unitUpgradeCounts[unit.id] ?? {};
    final element = unit.types.firstOrNull ?? 'Normal';
    final abilityRank = getSpecialAbilityRank(unit.id, element);

    final scaling = ImprovedScalingSystem.calculateGuardianScaling(
      baseLevel: unit.level,
      strUpgrades: 0, // You don't track these separately
      intUpgrades: 0,
      beautyUpgrades: 0,
      hpUpgrades: counts[AlchemyUpgradeKind.maxHp] ?? 0,
      abilityRank: abilityRank,
    );

    ImprovedScalingSystem.applyGuardianScaling(unit, scaling);
  }

  void spawnSplitChildren({
    required HoardEnemy parent,
    required int count,
    double speedMultiplier = 1.0,
  }) {
    final wave = currentWave;
    final parentTier = parent.template.tier.tier;
    if (parentTier <= 1) return;

    final childTier = parentTier - 1;

    for (int i = 0; i < count; i++) {
      final template =
          SurvivalEnemyCatalog.getTemplate(
            parent.template.element,
            childTier,
          ) ??
          SurvivalEnemyCatalog.getRandomTemplateForTier(childTier);

      final unit = SurvivalEnemyCatalog.buildEnemy(
        template: template,
        tier: childTier,
        wave: wave,
      );

      // Make split kids scamper faster
      unit.statSpeed *= speedMultiplier;

      final angle = _rng.nextDouble() * math.pi * 2;
      final offset = Vector2(math.cos(angle), math.sin(angle)) * 40;

      final child = HoardEnemy(
        position: parent.position + offset,
        targetOrb: parent.targetOrb,
        template: template,
        role: parent.role, // keep same melee/shooter style
        unit: unit,
        sizeScale: parent.sizeScale * 0.6,
        bossArchetype: null,
        isMegaBoss: false,
      );

      addHoardEnemy(child);
    }
  }

  void spawnBossMinions({
    required HoardEnemy boss,
    required String element,
    required int tier,
    required int count,
    double ringRadius = 140,
  }) {
    final wave = currentWave;
    final basePos = boss.position;
    final double r = ringRadius;

    for (int i = 0; i < count; i++) {
      final angle = (i / count) * math.pi * 2;
      final offset = Vector2(math.cos(angle), math.sin(angle)) * r;

      final template =
          SurvivalEnemyCatalog.getTemplate(element, tier) ??
          SurvivalEnemyCatalog.getRandomTemplateForTier(tier);

      final unit = SurvivalEnemyCatalog.buildEnemy(
        template: template,
        tier: tier,
        wave: wave,
      );

      final role =
          (template.element == 'Air' ||
              template.element == 'Lightning' ||
              template.element == 'Spirit')
          ? EnemyRole.shooter
          : EnemyRole.charger;

      final child = HoardEnemy(
        position: basePos + offset,
        targetOrb: boss.targetOrb,
        template: template,
        role: role,
        unit: unit,
        sizeScale: boss.sizeScale * 0.55, // nice small orbiting minions
        bossArchetype: null,
        isMegaBoss: false,
      );

      addHoardEnemy(child);
    }
  }

  void _setupFormation() {
    // The first 4 party members are active — positions chosen by the player
    // during the deployment phase (TOP, RIGHT, BOTTOM, LEFT).
    // They map to cardinal directions on the inner ring (8 slots total).
    final int activeCount = party.length.clamp(0, 4);

    // Slot indices for the 4 starting positions: N, E, S, W
    const List<int> startingSlotIndices = [0, 2, 4, 6];

    for (int idx = 0; idx < activeCount; idx++) {
      final member = party[idx];
      final c = member.combatant;

      final slotIndex = startingSlotIndices[idx];
      final slot = _slots[slotIndex];

      final unit = SurvivalUnit(
        id: c.id,
        name: c.name,
        types: c.types,
        family: c.family,
        level: c.level,
        statSpeed: c.statSpeed,
        statIntelligence: c.statIntelligence,
        statStrength: c.statStrength,
        statBeauty: c.statBeauty,
        sheetDef: c.sheetDef,
        spriteVisuals: c.spriteVisuals,
      );

      // Apply scaling for starters
      _applyScalingToGuardian(unit);

      final guardian = HoardGuardian(
        unit: unit,
        position: orb.position + slot.offset,
      );

      slot.boundUnitId = unit.id; // this slot is permanently this unit's "seat"
      slot.guardian = guardian;

      _guardians.add(guardian);
      world.add(guardian);

      // Mystics arrive with orbitals already active (rank 1).
      if (unit.family == 'Mystic') {
        final elem = unit.types.firstOrNull ?? 'Normal';
        if (getSpecialAbilityRank(unit.id, elem) <= 0) {
          incrementSpecialAbilityRank(unit.id, elem);
        }
      }
    }
  }

  void onGuardianDied(HoardGuardian guardian) {
    // Find the slot this guardian was in
    for (final slot in _slots) {
      if (slot.guardian == guardian) {
        slot.guardian = null;
        break;
      }
    }
  }

  void spawnProjectile({
    required Vector2 start,
    required HoardEnemy target,
    required int damage,
    required Color color,
  }) {
    final projectile = SimpleProjectile(
      start: start,
      end: target.position,
      color: color,
      onHit: () => target.takeDamage(damage),
    );
    world.add(projectile);
  }

  void spawnEnemyProjectile({
    required Vector2 start,
    required Vector2 targetPosition,
    required Color color,
    required VoidCallback onHit,
  }) {
    final projectile = SimpleProjectile(
      start: start,
      end: targetPosition,
      color: color.withOpacity(0.9),
      onHit: onHit,
    );
    world.add(projectile);
  }

  double _initialZoom = 1.0;

  @override
  void onScaleStart(ScaleStartInfo info) {
    _initialZoom = cameraComponent.viewfinder.zoom;
    _lastFocalPoint = info.eventPosition.global.clone();
  }

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    // --- ZOOM ---
    // Flame guarantees rawScale is uniform & stable
    final newZoom = (_initialZoom * info.raw.scale).clamp(
      0.2,
      2.0,
    ); // adjust your min/max
    cameraComponent.viewfinder.zoom = newZoom;

    // --- PAN ---
    if (_lastFocalPoint != null) {
      final delta = info.eventPosition.global - _lastFocalPoint!;
      cameraComponent.viewfinder.position -=
          delta / cameraComponent.viewfinder.zoom;
    }

    _lastFocalPoint = info.eventPosition.global.clone();
  }

  @override
  void onScaleEnd(ScaleEndInfo info) {
    _lastFocalPoint = null;
  }
}

String describeSpecialRank1(SurvivalUnit unit) {
  final element = unit.types.firstOrNull ?? 'Normal';
  return AbilitySystemConfig.getAbilityDescription(unit.family, element, 1);
}
