import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/survival/components/alchemy_orb.dart';
import 'package:alchemons/games/survival/components/alchemy_projectile.dart';
import 'package:alchemons/games/survival/components/guardian_slot_indicator.dart';
import 'package:alchemons/games/survival/components/survival_hud.dart';
import 'package:alchemons/games/survival/survival_creature_sprite.dart';
import 'package:alchemons/games/survival/survival_enemies.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_combat.dart';
import 'package:alchemons/games/survival/survival_spawner.dart';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

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

enum AlchemyUpgradeKind {
  maxHp,
  strength,
  intelligence,
  beauty,
  deployBench,
  specialAbility,
}

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

  SurvivalGameStats({
    required this.kills,
    required this.score,
    required this.timeElapsed,
  });

  String get formattedTime {
    final minutes = (timeElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeElapsed % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
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
  final List<SurvivalUnit> _benchUnits = [];
  final List<GuardianSlot> _slots = [];
  SurvivalUnit? _pendingDeployUnit; // waiting for player to pick a slot

  int _totalChoicesMade = 0; // Track how many times we've leveled up
  int _killsSinceLastChoice = 0;

  int get totalChoicesMade => _totalChoicesMade;

  // Calculate cost dynamically: Base 15 + (10 per Level)
  int get _killsRequiredForNextLevel => 15 + (_totalChoicesMade * 10);

  int get killsSinceLastChoice => _killsSinceLastChoice;
  int get killsRequiredForNextLevel => _killsRequiredForNextLevel;

  // Tracks upgrade history: { 'unit_id': { AlchemyUpgradeKind.strength: 2 } }
  final Map<String, Map<AlchemyUpgradeKind, int>> _unitUpgradeCounts = {};
  final Map<String, Map<String, int>> _specialAbilityUpgradeRanks = {};

  int kills = 0;
  int score = 0;
  double timeElapsed = 0;
  bool isGameOver = false;
  bool isInAlchemyPause = false;

  final ValueNotifier<SurvivalGameStats> statsNotifier = ValueNotifier(
    SurvivalGameStats(kills: 0, score: 0, timeElapsed: 0),
  );

  final ValueNotifier<AlchemyChoiceState?> alchemyChoiceNotifier =
      ValueNotifier<AlchemyChoiceState?>(null);

  double _startZoom = .5;

  SurvivalHoardGame({required this.party, required this.onGameOver});

  List<HoardGuardian> get guardians => _guardians;

  // Public getters for Spawner
  bool get bossAlive => _enemies.any((e) => e.isBoss && !e.isDead);
  int get currentWave => (timeElapsed / 20).floor() + 1;

  int getSpecialAbilityRank(String unitId, String element) {
    final byElement = _specialAbilityUpgradeRanks[unitId];
    if (byElement == null) return 0;
    return byElement[element] ?? 0;
  }

  void incrementSpecialAbilityRank(String unitId, String element) {
    _specialAbilityUpgradeRanks.putIfAbsent(unitId, () => {});
    final current = _specialAbilityUpgradeRanks[unitId]![element] ?? 0;
    _specialAbilityUpgradeRanks[unitId]![element] = current + 1;
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    world = World();
    cameraComponent = CameraComponent(world: world)
      ..viewfinder.anchor = Anchor.center
      ..viewfinder.zoom = .5;

    add(world);
    add(cameraComponent);

    world.add(AlchemyRuneBackground());

    orb = AlchemyOrb(maxHp: 1000);
    world.add(orb);

    _initGuardianSlots();

    add(SurvivalSpawner());

    _setupFormation();
    _initBenchFromParty();
    cameraComponent.viewport.add(SurvivalHud());
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

    // RING 1 (Inner Defense) - Radius 220
    // Indices 0-7. Kept at 8 slots so your _setupFormation() logic works perfectly.
    addRing(220.0, 8, angleOffset: -math.pi / 2);

    // RING 2 (Mid Field) - Radius 380
    // 12 Slots. Good for general crowd control units.
    addRing(380.0, 12, angleOffset: 0);

    // RING 3 (Long Range) - Radius 580
    // 16 Slots. Great for snipers (Wing/Pip).
    addRing(580.0, 16, angleOffset: math.pi / 8);

    // RING 4 (Outposts) - Radius 820
    // 20 Slots. Way out there. Good for intercepting bosses early.
    addRing(820.0, 20, angleOffset: 0);
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

      _benchUnits.add(unit);
    }
  }

  // --- HELPERS ---

  void addHoardEnemy(HoardEnemy enemy) {
    _enemies.add(enemy);
    world.add(enemy);
  }

  List<HoardEnemy> getEnemiesInRange(Vector2 center, double range) {
    return _enemies.where((e) {
      if (e.isDead) return false;
      return e.position.distanceTo(center) <= range;
    }).toList();
  }

  void confirmDeployAtSlot(int slotIndex) {
    final unit = _pendingDeployUnit;
    if (unit == null) return;

    final slot = _slots[slotIndex];

    // Ensure slot is available
    if (!slot.isEmpty) {
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

    // Cleanup
    _pendingDeployUnit = null;

    // Remove all indicators
    for (final c
        in world.children.whereType<GuardianSlotIndicator>().toList()) {
      c.removeFromParent();
    }

    isInAlchemyPause = false;
    // We no longer call resumeEngine() here, as the engine is never paused.
  }

  HoardGuardian? getRandomGuardianInRange({
    required Vector2 center,
    required double range,
  }) {
    final candidates = _guardians
        .where((g) => !g.isDead && g.position.distanceTo(center) <= range)
        .toList();
    if (candidates.isEmpty) return null;
    return candidates[math.Random().nextInt(candidates.length)];
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

  HoardEnemy? getNearestEnemy(Vector2 position, double range) {
    HoardEnemy? nearest;
    double minDstSq = range * range;

    for (final enemy in _enemies) {
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
      // Let Flame process add/remove and events, but don't advance time
      super.update(0);
      return;
    }

    // Normal running state
    super.update(dt);

    timeElapsed += dt;

    statsNotifier.value = SurvivalGameStats(
      kills: kills,
      score: score,
      timeElapsed: timeElapsed,
    );

    if (orb.isDestroyed) {
      isGameOver = true;
      onGameOver();
    }
  }

  void removeEnemy(HoardEnemy enemy) {
    _enemies.remove(enemy);
    world.remove(enemy);

    // How much this enemy is “worth” for the power-up bar
    final int killValue = enemy.isBoss
        ? 20
        : 1; // tweak 8 → 5 or whatever feels right

    kills +=
        killValue; // or keep a separate visible counter if you want UI to stay “true”
    score += enemy.template.tier.tier * 10 * killValue;

    _handleKillProgression(killValue * 2);
  }

  void _handleKillProgression(int killValue) {
    if (isGameOver || isInAlchemyPause) return;

    _killsSinceLastChoice += killValue;

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
    final rng = math.Random();
    const int maxRank = 5;

    // 1. Generate "Deploy from Bench" Candidates
    // Only show these if there is actually room on the field (limit 8 active for balance, or use _slots.length)
    final activeCount = _guardians.where((g) => !g.isDead).length;

    // Check if we have empty slots available
    final hasSpace = _slots.any((s) => s.isEmpty);

    if (hasSpace) {
      for (final benchUnit in _benchUnits) {
        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.deployBench,
            label: 'Deploy ${benchUnit.name}',
            description: 'Summon ${benchUnit.name} to join the defense.',
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
      final specialRank = getSpecialAbilityRank(unit.id, element);
      final nextRank = specialRank + 1;

      if (specialRank < maxRank) {
        final label = 'Empower ${unit.name}';
        String effectText;

        // Rank 1: Explain the Sustain/Utility unlock
        if (nextRank == 1) {
          effectText = describeSpecialRank1(unit);
        } else {
          // generic message for higher ranks
          effectText =
              'Empowers ${unit.types.firstOrNull ?? unit.family} special '
              '(more damage, bigger area & stronger effects).';
        }

        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.specialAbility,
            label: label,
            description: '$effectText\n(${element} Special • Rank $nextRank)',
            targetUnit: unit,
          ),
        );
      }

      // --- OPTION B: TRANSMUTE (All Stats) ---
      final transmuteRank = _getUpgradeRank(
        g.unit.id,
        AlchemyUpgradeKind.maxHp,
      );

      if (transmuteRank < maxRank) {
        final totalHpPct = ((math.pow(1.075, transmuteRank) - 1) * 100)
            .toStringAsFixed(0);

        candidates.add(
          AlchemyChoiceOption(
            kind: AlchemyUpgradeKind.maxHp,
            label: 'Transmute ${g.unit.name}',
            description:
                '+7.5% HP, +Stats across board\n(Current: \nRank ${transmuteRank + 1}',
            targetUnit: g.unit,
          ),
        );
      }
    }

    // 3. Fallback: If we don't have enough options to fill 4 slots, add generic heals
    // This happens if you have few units or everything is maxed.
    while (candidates.length < 4) {
      candidates.add(
        AlchemyChoiceOption(
          kind: AlchemyUpgradeKind.maxHp,
          label: "Restoration",
          description: "Heal the Alchemy Orb by 200 HP.",
          targetUnit: orb.isDestroyed
              ? null
              : (livingGuardians.isNotEmpty
                    ? livingGuardians.first.unit
                    : null),
        ),
      );
      // Break loop if we have no units to even target for the dummy check
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
    if (option.targetUnit == null) {
      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      return;
    }

    final unit = option.targetUnit!;

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
    // HP buff
    unit.maxHp = (unit.maxHp * 1.075).round();
    unit.currentHp = unit.maxHp;

    unit.calculateCombatStats();

    // Track rank so your UI / options know how many times we’ve enhanced
    _incrementUpgradeRank(unit.id, AlchemyUpgradeKind.maxHp);

    alchemyChoiceNotifier.value = null;
    isInAlchemyPause = false;
  }

  void _startDeployFromBench(SurvivalUnit unit) {
    _pendingDeployUnit = unit;

    // Only check for s.isEmpty (currently vacant slot).
    final availableSlots = _slots.where((s) => s.isEmpty).toList();

    // Safety: if all 8 slots are full, bail out and resume
    if (availableSlots.isEmpty) {
      _pendingDeployUnit = null;
      alchemyChoiceNotifier.value = null;
      isInAlchemyPause = false;
      // Removed resumeEngine() call
      return;
    }

    // Remove from bench immediately so we don't see it again
    _benchUnits.removeWhere((u) => u.id == unit.id);

    // Hide the choice UI now
    alchemyChoiceNotifier.value = null;

    // Spawn glowing slot indicators
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

      final angle = math.Random().nextDouble() * math.pi * 2;
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
    // Only first 4 party members are on the field at start
    final int activeCount = party.length.clamp(0, 4);

    for (int idx = 0; idx < activeCount; idx++) {
      final member = party[idx];
      final c = member.combatant;

      // Map formation to slot index based on _initGuardianSlots (0=Top, 4=Bottom)
      late int slotIndex;
      switch (member.position) {
        // Mapping the 4 initial spots to the 8 generated slots
        case FormationPosition.frontLeft:
          slotIndex = 6; // Around 3/4 way around the circle
          break;
        case FormationPosition.frontRight:
          slotIndex = 2; // Around 1/4 way around the circle
          break;
        case FormationPosition.backLeft:
          slotIndex = 7; // Just before the top center
          break;
        case FormationPosition.backRight:
          slotIndex = 1; // Just after the top center
          break;
      }

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

      final guardian = HoardGuardian(
        unit: unit,
        position: orb.position + slot.offset,
      );

      slot.boundUnitId = unit.id; // this slot is permanently this unit's "seat"
      slot.guardian = guardian;

      _guardians.add(guardian);
      world.add(guardian);
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

  @override
  void onScaleStart(ScaleStartInfo info) =>
      _startZoom = cameraComponent.viewfinder.zoom;

  @override
  void onScaleUpdate(ScaleUpdateInfo info) {
    if (!info.scale.global.isIdentity()) {
      cameraComponent.viewfinder.zoom = (_startZoom * info.scale.global.y)
          .clamp(0.3, 3.0);
    } else {
      // Allow panning/movement even if the game logic is paused
      cameraComponent.viewfinder.position +=
          (-info.delta.global / cameraComponent.viewfinder.zoom);
    }
  }
}

class AlchemyRuneBackground extends PositionComponent {
  static const double _runeSize = 300.0;
  static const double _center = _runeSize / 2;

  AlchemyRuneBackground()
    : super(
        size: Vector2.all(_runeSize),
        position: Vector2.zero(),
        anchor: Anchor.center,
      );

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 64, 21, 72).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final centerOffset = Offset(_center, _center);

    canvas.drawCircle(centerOffset, 140, paint);
    canvas.drawCircle(centerOffset, 120, paint);

    final path = Path();
    path.moveTo(_center, _center - 120);
    path.lineTo(_center + 104, _center + 60);
    path.lineTo(_center - 104, _center + 60);
    path.close();
    canvas.drawPath(path, paint);

    canvas.drawCircle(
      centerOffset,
      30,
      paint
        ..style = PaintingStyle.fill
        ..color = Colors.purple.withOpacity(0.05),
    );
  }
}

String describeSpecialRank1(SurvivalUnit unit) {
  final family = unit.family;
  final element = unit.types.firstOrNull ?? 'Neutral';

  switch (family) {
    case 'Let':
      return _describeLetRank1(element);
    case 'Pip':
      return _describePipRank1(element);
    case 'Mane':
      return _describeManeRank1(element);
    case 'Horn':
      return _describeHornRank1(element);
    case 'Wing':
      return _describeWingRank1(element);
    case 'Mask':
      return _describeMaskRank1(element);
    case 'Kin':
      return _describeKinRank1(element);
    case 'Mystic':
      return _describeMysticRank1(element);
    default:
      return 'Unlock: unique ${element} special upgrade.';
  }
}

String _describeLetRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Meteor leaves a burning crater and heals you from damage dealt.';
    case 'Blood':
      return 'Unlock: Meteor heavily drains enemies and converts it to self-heal.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Meteor chills the area, slowing and pushing enemies away.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Meteor slams harder and shatters, damaging around the impact.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Meteor falls faster and knocks enemies back in a shockwave.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Meteor poisons / seeds a damaging patch on impact.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Meteor amplifies damage on low HP enemies (finisher feel).';
    case 'Light':
      return 'Unlock: Meteor blasts enemies and lightly heals nearby allies.';
    default:
      return 'Unlock: Elemental Meteor upgrade based on type.';
  }
}

String _describePipRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Ricochet shots leave burning hits on enemies.';
    case 'Blood':
      return 'Unlock: Ricochet drains enemies and heals the Orb.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Ricochet splashes, nudging enemies and lightly healing allies.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Ricochet spreads poison / thorns to multiple enemies.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Ricochet hits knock enemies around and feel heavier.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Ricochet travels faster and chains between enemies.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Ricochet adds a draining / entropy tick to each bounce.';
    case 'Light':
      return 'Unlock: Ricochet lightly heals allies when it bounces.';
    default:
      return 'Unlock: Elemental Ricochet upgrade based on type.';
  }
}

String _describeManeRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Hazard zone becomes a burning field of fire damage.';
    case 'Blood':
      return 'Unlock: Hazard zone drains enemies and heals the caster.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Hazard zone slows and pushes enemies while ticking damage.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Hazard zone becomes a toxic/thorn patch with strong DoT.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Hazard zone pulls or bogs enemies down (heavy slow).';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Hazard zone jitters / shocks enemies caught inside.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Hazard zone saps enemies and sustains the caster.';
    case 'Light':
      return 'Unlock: Hazard zone damages enemies and gently heals allies inside.';
    default:
      return 'Unlock: Elemental Hazard upgrade based on type.';
  }
}

String _describeHornRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Nova ignites enemies around you.';
    case 'Blood':
      return 'Unlock: Nova damages enemies and heals you from the impact.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Nova strongly slows and pushes enemies away.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Nova applies poison / thorn damage around you.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Nova hits harder and grants a sturdier shield.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Nova knocks enemies back and shocks them.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Nova saps enemies in a ring around you.';
    case 'Light':
      return 'Unlock: Nova blasts enemies and heals nearby allies.';
    default:
      return 'Unlock: Elemental Nova upgrade based on type.';
  }
}

String _describeWingRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Beam leaves a burning line on the ground.';
    case 'Blood':
      return 'Unlock: Beam converts damage into lifesteal for the team.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Beam slows enemies and can heal allies near its path.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Beam seeds thorn/poison patches along its path.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Beam knocks enemies back and toughens the caster.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Beam blows enemies away and may chain lightning.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Beam deals extra damage to weakened enemies.';
    case 'Light':
      return 'Unlock: Beam heals allies near it and scorches enemies.';
    default:
      return 'Unlock: Elemental Beam upgrade based on type.';
  }
}

String _describeMaskRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Void burns enemies as they are pulled in.';
    case 'Blood':
      return 'Unlock: Void drains HP from trapped enemies to heal you.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Void slows or wets enemies while pulling them.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Void applies thorns/poison to enemies caught inside.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Void becomes more controlling, holding enemies longer.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Void jitters or shocks enemies pulled into it.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Void saps enemies and sets up a big finisher.';
    case 'Light':
      return 'Unlock: Void purifies around the center and buffs nearby allies.';
    default:
      return 'Unlock: Elemental Void upgrade based on type.';
  }
}

String _describeKinRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Blessing powers up frontliners and burns nearby foes.';
    case 'Blood':
      return 'Unlock: Blessing converts healing into damage to enemies.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Blessing adds regen/slow aura around the Orb.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Blessing adds team regen and poisons enemies near the base.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Blessing gives bigger heals and toughens the team.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Blessing heals allies and pushes/shocks enemies back.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Blessing heals allies and damages enemies near the Orb.';
    case 'Light':
      return 'Unlock: Holy Nova – huge team heal and AoE Light damage.';
    default:
      return 'Unlock: Elemental Blessing upgrade based on type.';
  }
}

String _describeMysticRank1(String element) {
  switch (element) {
    case 'Fire':
    case 'Lava':
      return 'Unlock: Orbitals explode in small fire blasts on hit.';
    case 'Blood':
      return 'Unlock: Orbitals heal the caster heavily when they connect.';
    case 'Water':
    case 'Ice':
    case 'Steam':
      return 'Unlock: Orbitals heal allies or slow enemies around impact.';
    case 'Plant':
    case 'Poison':
      return 'Unlock: Orbitals leave small thorn/poison zones at impact.';
    case 'Earth':
    case 'Mud':
    case 'Crystal':
      return 'Unlock: Orbitals create sturdy blasts or shard chains on hit.';
    case 'Air':
    case 'Dust':
    case 'Lightning':
      return 'Unlock: Orbitals push, confuse, or chain lightning between enemies.';
    case 'Spirit':
    case 'Dark':
      return 'Unlock: Orbitals drain or deal spectral burst damage on impact.';
    case 'Light':
      return 'Unlock: Orbitals heal allies in the impact area and burn enemies.';
    default:
      return 'Unlock: Elemental Orbital upgrade based on type.';
  }
}
