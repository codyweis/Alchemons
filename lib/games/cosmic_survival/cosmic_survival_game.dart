// lib/games/cosmic_survival/cosmic_survival_game.dart
//
// COSMIC SURVIVAL FLAME GAME — REDESIGNED
// Uses the same companion abilities, enemy visuals, ship rendering,
// and boss AI as the main cosmic exploration game.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/gameengines/boss_battle_engine_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// COMPANION DATA - uses same stat formulas as cosmic game
// ---------------------------------------------------------------------------

class CosmicSurvivalCompanion {
  final CosmicPartyMember member;
  Offset position;
  Offset anchor;
  int maxHp;
  int currentHp;
  final int physAtk;
  final int elemAtk;
  final int physDef;
  final int elemDef;
  final double cooldownReduction;
  final double critChance;
  final double attackRange;
  final double specialAbilityRange;
  double basicCooldown;
  double specialCooldown;
  bool tethered;
  bool isDead;
  double hitFlash;
  double angle;
  int shieldHp;
  double chargeTimer;
  Offset? chargeTarget;
  double chargeDamage;
  double chargeSpeedMultiplier;
  double chargeSweepRadius;
  double chargeOvershootDistance;
  double chargeFinalSweepRadius;
  Set<int>? chargeHitIds;
  double blessingTimer;
  double blessingHealPerTick;
  double basicHasteTimer;
  double basicHasteMultiplier;
  double invincibleTimer;
  double doubleCastTimer;
  Offset? doubleCastTargetPos;
  double doubleCastAngle;
  // Sticky target — reduces frame-to-frame target switching jitter
  CosmicSurvivalEnemy? stickyTarget;

  static const double baseSpecialCooldown = 12.5;
  static const double baseBasicCooldown = 1.5;
  static const double chargeSpeed = 400.0;

  CosmicSurvivalCompanion({
    required this.member,
    required this.position,
    required this.anchor,
    required this.maxHp,
    int? currentHp,
    required this.physAtk,
    required this.elemAtk,
    required this.physDef,
    required this.elemDef,
    this.cooldownReduction = 1.0,
    this.critChance = 0.05,
    this.attackRange = 200,
    this.specialAbilityRange = 250,
    this.basicCooldown = 0,
    this.specialCooldown = baseSpecialCooldown,
    this.tethered = true,
    this.isDead = false,
    this.hitFlash = 0,
    this.angle = 0,
    this.shieldHp = 0,
    this.chargeTimer = 0,
    this.chargeTarget,
    this.chargeDamage = 0,
    this.chargeSpeedMultiplier = 1.0,
    this.chargeSweepRadius = 15.0,
    this.chargeOvershootDistance = 80.0,
    this.chargeFinalSweepRadius = 28.0,
    this.blessingTimer = 0,
    this.blessingHealPerTick = 0,
    this.basicHasteTimer = 0,
    this.basicHasteMultiplier = 1.0,
    this.invincibleTimer = 2.0,
    this.doubleCastTimer = 0,
    this.doubleCastTargetPos,
    this.doubleCastAngle = 0,
  }) : currentHp = currentHp ?? maxHp;

  double get hpPercent =>
      maxHp > 0 ? (currentHp / maxHp).clamp(0, 1).toDouble() : 0;

  double get effectiveBasicCooldown {
    final base = baseBasicCooldown / cooldownReduction;
    final factor = (1.0 + (physAtk - 1) * 0.05).clamp(0.5, 3.0);
    final familyMultiplier = switch (member.family.toLowerCase()) {
      'let' => 1.12,
      'pip' => 0.90,
      'mane' => 0.92,
      _ => 1.0,
    };
    final haste = basicHasteTimer > 0
        ? basicHasteMultiplier.clamp(0.45, 1.0)
        : 1.0;
    return (base / factor) * familyMultiplier * haste;
  }

  double get effectiveSpecialCooldown {
    final base = baseSpecialCooldown / cooldownReduction;
    // For mystic: cap the stat-scaling factor so high elemAtk can't collapse
    // the cooldown. Other families keep the full 0.5–6.0 range.
    final isMystic = member.family.toLowerCase() == 'mystic';
    final factorCap = isMystic ? 2.2 : 6.0;
    final factor = (1.0 + (elemAtk / 6.0) * 0.2).clamp(0.5, factorCap);
    final familyMultiplier = switch (member.family.toLowerCase()) {
      'let' => 1.18,
      'pip' => 0.92,
      'mane' => 0.88,
      'mask' => 1.05,
      'mystic' => 2.6,
      _ => 1.0,
    };
    final cd = (base / factor) * familyMultiplier;
    // Mystic specials: hard floor so cooldown-reduction stacking can't drop
    // below this regardless of upgrades or power-ups applied elsewhere.
    return isMystic ? cd.clamp(18.0, double.infinity) : cd;
  }

  void primeSpecialCooldown({
    double? savedCooldown,
    double cooldownMultiplier = 1.0,
  }) {
    specialCooldown = normalizedCompanionSpecialCooldown(
      effectiveCooldown: effectiveSpecialCooldown,
      savedCooldown: savedCooldown,
      cooldownMultiplier: cooldownMultiplier,
    );
  }

  void takeDamage(int dmg) {
    if (invincibleTimer > 0) return;
    if (shieldHp > 0) {
      final absorbed = min(dmg, shieldHp);
      shieldHp -= absorbed;
      final remaining = dmg - absorbed;
      if (remaining > 0) currentHp = (currentHp - remaining).clamp(0, maxHp);
    } else {
      currentHp = (currentHp - dmg).clamp(0, maxHp);
    }
    invincibleTimer = 0.45;
  }
}

// ---------------------------------------------------------------------------
// SHIP - uses ShipComponent rendering from cosmic game
// ---------------------------------------------------------------------------

class CosmicSurvivalShip {
  Offset position;
  double angle;
  double maxHp;
  double currentHp;
  double speed;
  double fireCooldown;
  double fireTimer;
  bool isDead;
  double hitFlash;

  CosmicSurvivalShip({
    required this.position,
    this.angle = -pi / 2,
    this.maxHp = 100,
    double? currentHp,
    this.speed = 180,
    this.fireCooldown = 0.4,
    this.fireTimer = 0,
    this.isDead = false,
    this.hitFlash = 0,
  }) : currentHp = currentHp ?? maxHp;

  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0, 1) : 0;
}

// ---------------------------------------------------------------------------
// ORB
// ---------------------------------------------------------------------------

class CosmicSurvivalOrb {
  Offset position;
  double maxHp;
  double currentHp;
  int shieldHp;
  final OrbBaseSkin skin;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  double shieldPulseTimer;
  double turretTimer;
  double regenTimer;
  double novaTimer;

  CosmicSurvivalOrb({
    required this.position,
    required this.maxHp,
    required this.skin,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    double? currentHp,
    this.shieldHp = 0,
    this.shieldPulseTimer = 0,
    this.turretTimer = 0,
    this.regenTimer = 0,
    this.novaTimer = 0,
  }) : currentHp = currentHp ?? maxHp;

  double get hpPercent => maxHp > 0 ? (currentHp / maxHp).clamp(0, 1) : 0;
}

// ---------------------------------------------------------------------------
// GAME STATS
// ---------------------------------------------------------------------------

class CosmicSurvivalStats {
  int kills = 0;
  int score = 0;
  double timeElapsed = 0;

  String get formattedTime {
    final minutes = (timeElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeElapsed % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

// ---------------------------------------------------------------------------
// BACKGROUND STAR
// ---------------------------------------------------------------------------

class _BgStar {
  final double x, y, size, twinkleSpeed;
  final double brightness;
  _BgStar(this.x, this.y, this.size, this.twinkleSpeed, this.brightness);
}

// ---------------------------------------------------------------------------
// VFX PARTICLE
// ---------------------------------------------------------------------------

class _VfxParticle {
  double x, y, vx, vy, size, life;
  final double maxLife;
  final Color color;
  _VfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  }) : maxLife = life;
  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;
  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vx *= 0.92;
    vy *= 0.92;
    life -= dt;
  }
}

class _CompanionTargetChoice {
  final Offset position;
  final CosmicSurvivalEnemy? enemy;
  final bool isBoss;

  const _CompanionTargetChoice({
    required this.position,
    this.enemy,
    this.isBoss = false,
  });
}

class _ProjectileControlBuckets {
  final List<Projectile> snares = <Projectile>[];
  final List<Projectile> lures = <Projectile>[];
  final List<Projectile> decoys = <Projectile>[];
  final List<Projectile> interceptors = <Projectile>[];
}

class _BeamFx {
  Offset start;
  Offset end;
  final Color color;
  final double width;
  double life;
  final double maxLife;

  _BeamFx({
    required this.start,
    required this.end,
    required this.color,
    required this.width,
    required this.life,
  }) : maxLife = life;

  bool get dead => life <= 0;
  double get alpha => (life / maxLife).clamp(0.0, 1.0);

  void update(double dt) {
    life -= dt;
  }
}

class MysticSpecialCastEvent {
  final Offset originScreen;
  final Offset? targetScreen;
  final String element;
  final bool isEcho;

  const MysticSpecialCastEvent({
    required this.originScreen,
    this.targetScreen,
    required this.element,
    this.isEcho = false,
  });
}

// ---------------------------------------------------------------------------
// MAIN GAME
// ---------------------------------------------------------------------------

class CosmicSurvivalGame extends FlameGame with PanDetector {
  static const int _maxCompanionProjectiles = 220;
  static const int _maxEnemyProjectiles = 90;
  static const int _maxBossProjectiles = 110;
  static const double _survivalShipSpeedMultiplier = 1.10;
  // Former collectible rewards used a 1.20 pickup value; direct grants are 20% lower.
  static const double _alchemyMeterGainMultiplier = 0.96;
  static const double _arenaShipPadding = 32.0;
  static const double _orbCoreRadius = 72.0;
  static const double _orbGlowRadius = 112.0;
  static const double _orbInnerRuneRadius = 96.0;
  static const double _orbOuterRuneRadius = 124.0;
  static const double _orbShieldRadius = 136.0;
  static const double _orbHpRingRadius = 112.0;
  static const double _orbAlchemyRingRadius = 160.0;
  static const double _orbGravityRadius = 720.0;
  static const double _orbShipOrbitRadius = 270.0;

  final List<CosmicPartyMember> party;
  final VoidCallback onGameOver;
  final VoidCallback? onWaveIntermission;
  final void Function(SurvivalBoss boss)? onBossSpawn;
  final void Function(MysticSpecialCastEvent event)? onMysticSpecialCast;
  final SurvivalUpgradeState upgradeState;
  String? shipSkin;

  // Camera
  static const double _baseZoom = 0.85;
  static const double _targetZoom = 0.595;
  double _currentZoom = _baseZoom;
  double _zoomAnimTimer = 0;
  static const double _zoomAnimDuration = 1.5;
  bool _zoomAnimComplete = false;

  // Core objects
  late CosmicSurvivalOrb orb;
  late CosmicSurvivalShip ship;

  // Multi-companion system (keyed by slot index)
  final Map<int, CosmicSurvivalCompanion> activeCompanions = {};
  final Set<int> defeatedCompanionSlots = <int>{};
  int? tetheredCompanionSlot;
  bool tetherModeEnabled = true;

  // Convenience getters for backward compatibility
  CosmicSurvivalCompanion? get activeCompanion => tetheredCompanionSlot != null
      ? activeCompanions[tetheredCompanionSlot!]
      : (activeCompanions.isNotEmpty ? activeCompanions.values.first : null);
  int? get activeCompanionSlot =>
      (tetherModeEnabled ? tetheredCompanionSlot : null) ??
      (activeCompanions.isNotEmpty ? activeCompanions.keys.first : null);
  bool get companionTethered =>
      tetherModeEnabled &&
      tetheredCompanionSlot != null &&
      activeCompanions.containsKey(tetheredCompanionSlot);
  bool isCompanionDefeated(int slotIndex) =>
      defeatedCompanionSlots.contains(slotIndex);
  int get maxActiveCompanions => powerUps.maxActiveCompanions;

  // Wave system
  final CosmicSurvivalSpawner spawner = CosmicSurvivalSpawner();
  final List<CosmicSurvivalEnemy> enemies = [];
  SurvivalBoss? activeBoss;
  final List<SurvivalBossProjectile> bossProjectiles = [];
  final List<SurvivalEnemyProjectile> enemyProjectiles = [];

  // Companion projectiles (uses cosmic game Projectile class)
  final List<Projectile> companionProjectiles = [];

  // Ship projectiles (simple)
  final List<ShipProjectile> shipProjectiles = [];

  // Power-ups
  final PowerUpState powerUps = PowerUpState();
  bool showingPowerUpSelection = false;
  bool gamePaused = false;

  // Stats
  final CosmicSurvivalStats stats = CosmicSurvivalStats();
  bool isGameOver = false;
  bool _started = false;
  final ValueNotifier<bool> detonationReadyNotifier = ValueNotifier(false);
  final ValueNotifier<double> detonationChargeNotifier = ValueNotifier(0);
  double _detonationTimer = 0;

  // Ship respawn
  static const double _shipRespawnDelay = 30.0;
  double _shipRespawnTimer = 0;
  double get shipRespawnRemaining => ship.isDead
      ? (_shipRespawnDelay - _shipRespawnTimer).clamp(0, _shipRespawnDelay)
      : 0;
  bool get detonationUnlocked => powerUps.novaDetonationLevel > 0;

  // Orb skin passives
  OrbBaseSkin _equippedSkin = OrbBaseSkin.defaultOrb;
  double _orbBurnAuraTimer = 0;
  double _orbSlowAuraRadius = 0;
  double _orbPassiveRegenRate = 0;
  double _orbDodgeChance = 0;
  double _celestialHealTimer = 0;

  double alchemicalMeter = 0;
  static const double _baseAlchemicalMeterMax = 100;
  double get alchemicalMeterMax {
    final wave = max(1, spawner.currentWave);
    final scaling = 1.0 + ((wave - 1) * 0.08).clamp(0.0, 2.4);
    return _baseAlchemicalMeterMax * scaling;
  }

  // Joystick input
  Offset? _dragTarget;
  Offset _joystickInput = Offset.zero;
  void setJoystickInput(Offset input) => _joystickInput = input;

  // Background stars
  final List<_BgStar> _stars = [];

  // VFX particles
  final List<_VfxParticle> _vfx = [];
  final List<_BeamFx> _beamFx = [];
  int _timeDilationWave = 0;
  double _timeDilationTimer = 0;
  double _timeDilationSlowFactor = 1.0;

  // HP fraction cache for companion panel
  final Map<int, double> companionHpFraction = {};
  final Map<int, double> companionSpecialCooldown = {};

  // Companion sprite rendering (per-slot)
  final Map<int, SpriteAnimationTicker> _companionTickers = {};
  final Map<int, SpriteVisuals?> _companionVisuals = {};
  final Map<int, double> _companionSpriteScales = {};
  final Map<String, TextPainter> _eliteAffixPainters = {};
  final Map<String, TextPainter> _bossNamePainters = {};

  static const Map<String, double> _companionSpeciesScale = {
    'let': 1.0,
    'pip': 1.0,
    'mane': 1.2,
    'horn': 1.7,
    'mask': 1.5,
    'wing': 2.0,
    'kin': 2.0,
    'mystic': 2.4,
  };

  @override
  bool isLoaded = false;

  double get camX => ship.position.dx - size.x / (2 * _currentZoom);
  double get camY => ship.position.dy - size.y / (2 * _currentZoom);

  final Random _rng = Random();

  CosmicSurvivalGame({
    required this.party,
    required this.onGameOver,
    this.onWaveIntermission,
    this.onBossSpawn,
    this.onMysticSpecialCast,
    this.shipSkin,
    SurvivalUpgradeState? upgradeState,
  }) : upgradeState = upgradeState ?? SurvivalUpgradeState();

  Offset worldToScreen(Offset world) => Offset(
    (world.dx - camX) * _currentZoom,
    (world.dy - camY) * _currentZoom,
  );

  void _emitMysticSpecialCast({
    required CosmicSurvivalCompanion companion,
    required Offset origin,
    required Offset? target,
    bool isEcho = false,
  }) {
    if (companion.member.family.toLowerCase() != 'mystic') return;
    onMysticSpecialCast?.call(
      MysticSpecialCastEvent(
        originScreen: worldToScreen(origin),
        targetScreen: target != null ? worldToScreen(target) : null,
        element: companion.member.element,
        isEcho: isEcho,
      ),
    );
  }

  @override
  Color backgroundColor() => const Color(0xFF020010);

  double get _renderPressure =>
      companionProjectiles.length +
      enemyProjectiles.length +
      bossProjectiles.length +
      enemies.length * 0.5 +
      _vfx.length * 0.35;
  double get _arenaRadius =>
      max(1140.0, max(size.x / _currentZoom, size.y / _currentZoom) * 0.54);

  bool get _reduceSecondaryGlows => _renderPressure >= 170;
  bool get _reduceMinorLabels => enemies.length >= 32 || _renderPressure >= 190;
  bool get _reduceAmbientVfx => _renderPressure >= 220;
  bool get _simplifyEnemyRendering =>
      enemies.length >= 30 || _renderPressure >= 200;
  bool get _simplifyProjectileRendering =>
      companionProjectiles.length >= 120 || _renderPressure >= 200;

  TextPainter _getEliteAffixPainter(String label, Color color) {
    final key = 'elite:$label:${color.toARGB32()}';
    return _eliteAffixPainters.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color.withValues(alpha: 0.95),
            fontSize: 7.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  TextPainter _getBossNamePainter(String name, Color color) {
    final key = 'boss:$name:${color.toARGB32()}';
    return _bossNamePainters.putIfAbsent(
      key,
      () => TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            color: color.withValues(alpha: 0.8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }

  @override
  Future<void> onLoad() async {
    final skinDef = kOrbBases.firstWhere(
      (d) => d.skin == upgradeState.equippedSkin,
      orElse: () => kOrbBases.first,
    );
    orb = CosmicSurvivalOrb(
      position: const Offset(0, 0),
      maxHp:
          ((400 + upgradeState.bonusOrbHp) *
                  powerUps.orbHpMultiplier *
                  skinDef.hpMultiplier)
              .round()
              .toDouble(),
      skin: skinDef.skin,
      primaryColor: skinDef.primaryColor,
      secondaryColor: skinDef.secondaryColor,
      glowColor: skinDef.glowColor,
    );

    ship = CosmicSurvivalShip(
      position: const Offset(-270, 0),
      speed: 180 * _survivalShipSpeedMultiplier,
    );

    // Initialize orb skin passives
    _equippedSkin = skinDef.skin;
    _initOrbSkinPassives(_equippedSkin);

    for (var i = 0; i < 400; i++) {
      _stars.add(
        _BgStar(
          _rng.nextDouble() * 6000 - 3000,
          _rng.nextDouble() * 6000 - 3000,
          0.5 + _rng.nextDouble() * 2.0,
          0.5 + _rng.nextDouble() * 3.0,
          0.3 + _rng.nextDouble() * 0.7,
        ),
      );
    }

    isLoaded = true;
  }

  void startGame() {
    _started = true;
    _zoomAnimTimer = 0;
    spawner.startFirstWave();
  }

  // == Update ==============================================================

  @override
  void update(double dt) {
    super.update(dt);
    if (!_started || isGameOver || gamePaused) return;

    stats.timeElapsed += dt;

    // Zoom animation
    if (!_zoomAnimComplete) {
      _zoomAnimTimer += dt;
      final t = (_zoomAnimTimer / _zoomAnimDuration).clamp(0.0, 1.0);
      final ease = 1.0 - pow(1.0 - t, 3).toDouble();
      _currentZoom = _baseZoom + (_targetZoom - _baseZoom) * ease;
      if (t >= 1.0) _zoomAnimComplete = true;
    }

    _updateShip(dt);
    _updateCompanion(dt);
    final enemyControlBuckets = _buildProjectileControlBuckets();
    _updateEnemies(dt, enemyControlBuckets);
    _updateCompanionProjectiles(dt);
    _updateShipProjectiles(dt);
    _updateOrbDefenses(dt);
    _updateDetonation(dt);
    _updateOrbSkinPassives(dt);
    _updateBoss(dt);
    final defenseControlBuckets = _buildProjectileControlBuckets();
    _updateBossProjectiles(dt, defenseControlBuckets.interceptors);
    _updateEnemyProjectiles(dt, defenseControlBuckets.interceptors);
    _updateVfx(dt);
    _timeDilationTimer = max(0, _timeDilationTimer - dt);
    if (_timeDilationTimer <= 0) _timeDilationSlowFactor = 1.0;

    // Spawn new enemies
    final viewW = size.x / _currentZoom;
    final viewH = size.y / _currentZoom;
    final newEnemies = spawner.update(
      dt,
      enemies.length,
      viewW,
      viewH,
      orb.position,
    );
    enemies.addAll(newEnemies);
    _applyWaveStartEffectsIfNeeded();

    // Spawn boss on boss waves
    if (spawner.isBossWave && !spawner.bossSpawned && activeBoss == null) {
      final bossAngle = _rng.nextDouble() * 2 * pi;
      final bossTargetRadius = max(260.0, _arenaRadius - 130.0);
      final bossSpawnPos = Offset(
        orb.position.dx + cos(bossAngle) * bossTargetRadius,
        orb.position.dy + sin(bossAngle) * bossTargetRadius,
      );
      activeBoss = spawner.createBossForWave(spawner.currentWave, bossSpawnPos);
      spawner.markBossSpawned();
      if (activeBoss != null) {
        _beginBossEntrance(activeBoss!, bossAngle);
        onBossSpawn?.call(activeBoss!);
      }
    }

    // Check wave completion
    final alive = enemies.length;
    final bossAlive = activeBoss != null && !activeBoss!.isDead;
    spawner.checkWaveComplete(alive, bossAlive: bossAlive);

    _maybeTriggerPowerUpSelection();

    if (spawner.intermission && !showingPowerUpSelection) {
      _cleanupBetweenWaves();
      spawner.resumeAfterIntermission();
    }

    _trimProjectilePools();

    // Game over
    if (orb.currentHp <= 0 && !isGameOver) {
      isGameOver = true;
      onGameOver();
    }
  }

  // == Ship ================================================================

  @override
  void onPanStart(DragStartInfo info) {
    _dragTarget = _clampToArena(
      Offset(
        info.eventPosition.global.x / _currentZoom + camX,
        info.eventPosition.global.y / _currentZoom + camY,
      ),
      padding: _arenaShipPadding,
    );
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    _dragTarget = _clampToArena(
      Offset(
        info.eventPosition.global.x / _currentZoom + camX,
        info.eventPosition.global.y / _currentZoom + camY,
      ),
      padding: _arenaShipPadding,
    );
  }

  @override
  void onPanEnd(DragEndInfo info) {
    // Keep drifting toward the last target, matching cosmic mode.
  }

  void _updateShip(double dt) {
    if (ship.isDead) {
      ship.fireTimer = 0;
      ship.hitFlash = 0;
      _shipRespawnTimer += dt;
      if (_shipRespawnTimer >= _shipRespawnDelay) {
        ship.isDead = false;
        ship.currentHp = ship.maxHp * 0.5;
        ship.position = _clampToArena(
          orb.position + const Offset(-_orbShipOrbitRadius, 0),
          padding: _arenaShipPadding,
        );
        _dragTarget = ship.position;
        _shipRespawnTimer = 0;
      }
      return;
    }

    var shipIsIdle = false;

    if (_joystickInput.distance > 0.1) {
      ship.angle = atan2(_joystickInput.dy, _joystickInput.dx);
      final inputScale = _joystickInput.distance.clamp(0.0, 1.0);
      ship.position = Offset(
        ship.position.dx + cos(ship.angle) * ship.speed * inputScale * dt,
        ship.position.dy + sin(ship.angle) * ship.speed * inputScale * dt,
      );
      _dragTarget = null;
    } else if (_dragTarget != null) {
      final dir = _dragTarget! - ship.position;
      final dist = dir.distance;
      if (dist > 5) {
        final nx = dir.dx / dist;
        final ny = dir.dy / dist;
        final move = min(ship.speed * dt, dist);
        ship.position = Offset(
          ship.position.dx + nx * move,
          ship.position.dy + ny * move,
        );
        ship.angle = atan2(ny, nx);
      } else {
        shipIsIdle = true;
      }
    } else {
      shipIsIdle = true;
    }

    _applyOrbGravityToShip(dt, shipIsIdle: shipIsIdle);
    ship.position = _clampToArena(ship.position, padding: _arenaShipPadding);

    // Auto-fire at nearest enemy or boss
    ship.fireTimer += dt;
    final rocketPenalty = powerUps.hasRocketBarrage ? 1.5 : 1.0;
    final effectiveFireCooldown =
        ship.fireCooldown * rocketPenalty / powerUps.fireRateMultiplier;
    if (ship.fireTimer >= effectiveFireCooldown) {
      final target = _nearestEnemyTo(ship.position, 400);
      Offset? fireTarget;
      if (target != null) {
        fireTarget = target.position;
      } else if (activeBoss != null && !activeBoss!.isDead) {
        final bd = (activeBoss!.position - ship.position).distance;
        if (bd < 500) fireTarget = activeBoss!.position;
      }
      if (fireTarget != null) {
        ship.fireTimer = 0;
        _fireShipAt(fireTarget);
      }
    }

    ship.hitFlash = (ship.hitFlash - dt * 4).clamp(0, 1);
  }

  void _applyOrbGravityToShip(double dt, {required bool shipIsIdle}) {
    final toOrb = orb.position - ship.position;
    final dist = toOrb.distance;
    if (dist <= 0.001) return;

    final dir = Offset(toOrb.dx / dist, toOrb.dy / dist);
    final gravityFalloff = (1 - (dist / _orbGravityRadius)).clamp(0.0, 1.0);
    if (gravityFalloff > 0) {
      final pull = 18.0 * gravityFalloff * gravityFalloff;
      ship.position += dir * pull * dt;
    }

    final minOrbitDistance = _orbAlchemyRingRadius + 56.0;
    if (dist < minOrbitDistance) {
      ship.position = orb.position - dir * minOrbitDistance;
      _dragTarget = ship.position;
      return;
    }

    if (!shipIsIdle || dist > _orbGravityRadius) return;

    final radialError = dist - _orbShipOrbitRadius;
    final radialSpeed = radialError.clamp(-90.0, 90.0) * 0.82;
    final tangent = Offset(-dir.dy, dir.dx);
    final orbitSpeed = 52.0 + 8.0 * sin(stats.timeElapsed * 0.7);

    ship.position += (dir * radialSpeed + tangent * orbitSpeed) * dt;
    ship.angle = atan2(tangent.dy, tangent.dx);
    _dragTarget = ship.position;
  }

  void _fireShipAt(Offset targetPos) {
    // Cap total ship projectiles to limit performance impact at high waves
    if (shipProjectiles.length >= 40) return;

    final dir = targetPos - ship.position;
    final dist = dir.distance;
    if (dist < 1) return;
    final norm = Offset(dir.dx / dist, dir.dy / dist);
    final baseDamage = 10.0 * powerUps.shipDamageMultiplier;

    // Rocket Barrage path (mutually exclusive with spread shot)
    if (powerUps.hasRocketBarrage) {
      final rocketLevel = powerUps.rocketBarrageLevel;
      final rocketDamage = baseDamage * (2.5 + rocketLevel * 1.5);
      final splashRadius = 60.0 + rocketLevel * 25.0;
      const rocketSpeed = 340.0;
      final nearest = _nearestEnemyTo(ship.position, 600);
      shipProjectiles.add(
        ShipProjectile(
          position: ship.position,
          velocity: Offset(norm.dx * rocketSpeed, norm.dy * rocketSpeed),
          damage: rocketDamage,
          isHoming: true,
          target: nearest,
          splashRadius: splashRadius,
        ),
      );
      // Level 3 fires a second rocket slightly offset
      if (rocketLevel >= 3) {
        final sideAngle = atan2(norm.dy, norm.dx) + 0.18;
        final nearest2 = _nearestEnemyTo(
          ship.position + Offset(norm.dx * 20, norm.dy * 20),
          600,
        );
        shipProjectiles.add(
          ShipProjectile(
            position: ship.position,
            velocity: Offset(
              cos(sideAngle) * rocketSpeed,
              sin(sideAngle) * rocketSpeed,
            ),
            damage: rocketDamage * 0.75,
            isHoming: true,
            target: nearest2,
            splashRadius: splashRadius * 0.8,
          ),
        );
      }
      return;
    }

    // Standard shot
    const speed = 400.0;
    shipProjectiles.add(
      ShipProjectile(
        position: ship.position,
        velocity: Offset(norm.dx * speed, norm.dy * speed),
        damage: baseDamage,
        isHoming: powerUps.hasHomingMissiles,
        target: powerUps.hasHomingMissiles
            ? _nearestEnemyTo(ship.position, 500)
            : null,
      ),
    );

    // Spread shot
    if (powerUps.spreadShotLevel > 0) {
      for (var i = 1; i <= powerUps.spreadShotLevel; i++) {
        for (final sign in [-1.0, 1.0]) {
          final spreadAngle = sign * i * 0.25;
          final sa = atan2(norm.dy, norm.dx) + spreadAngle;
          shipProjectiles.add(
            ShipProjectile(
              position: ship.position,
              velocity: Offset(cos(sa) * speed, sin(sa) * speed),
              damage: baseDamage * 0.6,
            ),
          );
        }
      }
    }
  }

  // == Companion ===========================================================

  void _updateCompanion(double dt) {
    // Remove dead companions
    final deadSlots = <int>[];
    for (final entry in activeCompanions.entries) {
      if (entry.value.isDead) {
        companionHpFraction[entry.key] = 0.0;
        companionSpecialCooldown[entry.key] = entry.value.specialCooldown;
        deadSlots.add(entry.key);
      }
    }
    for (final slot in deadSlots) {
      defeatedCompanionSlots.add(slot);
      if (tetheredCompanionSlot == slot) {
        tetheredCompanionSlot = null;
      }
      activeCompanions.remove(slot);
      _companionTickers.remove(slot);
      _companionVisuals.remove(slot);
      _companionSpriteScales.remove(slot);
    }

    for (final entry in activeCompanions.entries) {
      final targetChoice = _pickCompanionTargetChoice(entry.value);
      entry.value.stickyTarget = targetChoice?.enemy;
      _updateSingleCompanion(dt, entry.key, entry.value, targetChoice);
    }
  }

  void _updateSingleCompanion(
    double dt,
    int slotIndex,
    CosmicSurvivalCompanion comp,
    _CompanionTargetChoice? targetChoice,
  ) {
    if (comp.isDead) return;

    comp.invincibleTimer = (comp.invincibleTimer - dt).clamp(0, 100);
    comp.hitFlash = (comp.hitFlash - dt * 4).clamp(0, 1);
    _companionTickers[slotIndex]?.update(dt);

    // Charge state
    if (comp.chargeTimer > 0) {
      comp.chargeTimer -= dt;
      if (comp.chargeTarget != null) {
        final dir = comp.chargeTarget! - comp.position;
        final dist = dir.distance;
        if (dist > 5) {
          final step =
              CosmicSurvivalCompanion.chargeSpeed *
              comp.chargeSpeedMultiplier *
              dt;
          comp.position += (dir / dist) * min(step, dist);
          comp.angle = atan2(dir.dy, dir.dx);
          // Damage enemies touched during charge
          for (final e in enemies) {
            if (e.isDead) continue;
            final d = (e.position - comp.position).distance;
            if (d < e.radius + comp.chargeSweepRadius &&
                !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
              comp.chargeHitIds?.add(e.hashCode);
              _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
            }
          }
        }
      }
      if (comp.chargeTimer <= 0) {
        for (final e in enemies) {
          if (e.isDead) continue;
          final d = (e.position - comp.position).distance;
          if (d < e.radius + comp.chargeFinalSweepRadius &&
              !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
            comp.chargeHitIds?.add(e.hashCode);
            _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
          }
        }
        comp.chargeTarget = null;
        comp.chargeHitIds = null;
      }
      return; // don't do normal movement while charging
    }

    // Blessing timer
    if (comp.blessingTimer > 0) {
      comp.blessingTimer -= dt;
      final blessingHeal = (comp.blessingHealPerTick * dt).round();
      if (blessingHeal > 0) {
        comp.currentHp = min(comp.maxHp, comp.currentHp + blessingHeal);
        _healOrb(blessingHeal * 0.5);
      }
    }

    // Haste timer
    if (comp.basicHasteTimer > 0) comp.basicHasteTimer -= dt;

    // Movement
    if (comp.tethered) {
      final dist = (comp.position - ship.position).distance;
      if (dist > 96) {
        final dir = ship.position - comp.position;
        final norm = Offset(dir.dx / dist, dir.dy / dist);
        final moveSpeed = 160.0 * powerUps.companionSpeedMultiplier(slotIndex);
        final step = min(moveSpeed * dt, max(0.0, dist - 92.0));
        comp.position = Offset(
          comp.position.dx + norm.dx * step,
          comp.position.dy + norm.dy * step,
        );
        _setCompanionAngle(comp, atan2(norm.dy, norm.dx), 0.22);
      }
    } else {
      final rawMoveTarget = _desiredCompanionMoveTarget(
        slotIndex,
        comp,
        targetChoice,
      );
      final moveTarget = rawMoveTarget != null
          ? _resolveCompanionMoveTarget(
              slotIndex,
              comp,
              rawMoveTarget,
              targetChoice,
            )
          : null;
      if (moveTarget != null) {
        comp.anchor =
            Offset.lerp(
              comp.anchor,
              moveTarget,
              (0.06 + dt * 0.12).clamp(0.06, 0.14),
            ) ??
            moveTarget;
        final steeringTarget = comp.anchor;
        final dir = steeringTarget - comp.position;
        final dist = dir.distance;
        if (dist > 6) {
          final norm = Offset(dir.dx / dist, dir.dy / dist);
          final moveSpeed =
              120.0 *
              _familyMovementSpeedMultiplier(comp.member.family) *
              powerUps.companionSpeedMultiplier(slotIndex);
          final step = min(moveSpeed * dt, dist);
          comp.position = Offset(
            comp.position.dx + norm.dx * step,
            comp.position.dy + norm.dy * step,
          );
          _setCompanionAngle(comp, atan2(norm.dy, norm.dx), 0.18);
        }
      }
    }

    // Clamp companion within arena bounds
    comp.position = _clampToArena(comp.position, padding: 25);
    comp.anchor = _clampToArena(comp.anchor, padding: 25);

    // Find nearest enemy or boss for attacks
    final attackTarget = targetChoice?.position;
    final distToTarget = attackTarget != null
        ? (attackTarget - comp.position).distance
        : double.infinity;
    // Cooldowns always tick, even with no enemies
    comp.basicCooldown -= dt;
    comp.specialCooldown -= dt;

    // Double Cast delayed echo
    if (comp.doubleCastTimer > 0) {
      comp.doubleCastTimer -= dt;
      if (comp.doubleCastTimer <= 0 && comp.doubleCastTargetPos != null) {
        final result2 = createCosmicSpecialAbility(
          origin: comp.position,
          baseAngle: comp.doubleCastAngle + 0.15,
          family: comp.member.family,
          element: comp.member.element,
          damage:
              comp.elemAtk *
              0.70 *
              powerUps.companionAttackMultiplier(slotIndex),
          maxHp: comp.maxHp,
          casterPower: comp.member.statIntelligence.toDouble(),
          casterBeauty: comp.member.statBeauty.toDouble(),
          casterIntelligence: comp.member.statIntelligence.toDouble(),
          casterStrength: comp.member.statStrength.toDouble(),
          targetPos: comp.doubleCastTargetPos,
        );
        for (final projectile in result2.projectiles) {
          projectile.sourceSlotIndex = slotIndex;
          if (powerUps.companionHasChainLightning(slotIndex)) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              2,
            );
          }
        }
        companionProjectiles.addAll(result2.projectiles);
        _applyCompanionSpecialSupportEffects(comp, result2);
        _emitMysticSpecialCast(
          companion: comp,
          origin: comp.position,
          target: comp.doubleCastTargetPos,
          isEcho: true,
        );
        if (comp.member.family.toLowerCase() != 'mystic') {
          _spawnHitSpark(comp.position, elementColor(comp.member.element));
        }
        comp.doubleCastTargetPos = null;
      }
    }

    if (attackTarget != null) {
      final toTarget = attackTarget - comp.position;
      _setCompanionAngle(comp, atan2(toTarget.dy, toTarget.dx), 0.12);

      // Basic attack - family-specific projectiles (same as cosmic game)
      if (comp.basicCooldown <= 0 && distToTarget <= comp.attackRange) {
        final cooldown =
            comp.effectiveBasicCooldown *
            (1.0 -
                powerUps.companionCooldownReduction(slotIndex).clamp(0.0, 0.5));
        comp.basicCooldown = cooldown;
        final basics = createFamilyBasicAttack(
          origin: comp.position,
          angle: comp.angle,
          element: comp.member.element,
          family: comp.member.family,
          damage:
              comp.physAtk.toDouble() *
              powerUps.companionAttackMultiplier(slotIndex) *
              (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0),
        );
        for (final projectile in basics) {
          projectile.sourceSlotIndex = slotIndex;
          if (powerUps.companionHasChainLightning(slotIndex)) {
            projectile.chainLightningCharges = 2;
          }
        }
        companionProjectiles.addAll(basics);

        // Mystic family passive: basic attacks reduce special cooldown
        if (comp.member.family.toLowerCase() == 'mystic') {
          comp.specialCooldown -= 0.3;
        }
      }

      // Special ability - family x element (same as cosmic game!)
      if (comp.specialCooldown <= 0 &&
          distToTarget <= comp.specialAbilityRange) {
        final cooldown =
            comp.effectiveSpecialCooldown *
            (1.0 -
                powerUps.companionCooldownReduction(slotIndex).clamp(0.0, 0.5));
        comp.specialCooldown = cooldown;

        final result = createCosmicSpecialAbility(
          origin: comp.position,
          baseAngle: comp.angle,
          family: comp.member.family,
          element: comp.member.element,
          damage:
              comp.elemAtk *
              1.15 *
              powerUps.companionAttackMultiplier(slotIndex) *
              (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0),
          maxHp: comp.maxHp,
          casterPower: comp.member.statIntelligence.toDouble(),
          casterBeauty: comp.member.statBeauty.toDouble(),
          casterIntelligence: comp.member.statIntelligence.toDouble(),
          casterStrength: comp.member.statStrength.toDouble(),
          targetPos: attackTarget,
        );
        for (final projectile in result.projectiles) {
          projectile.sourceSlotIndex = slotIndex;
          if (powerUps.companionHasChainLightning(slotIndex)) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              2,
            );
          }
        }
        companionProjectiles.addAll(result.projectiles);

        // Apply state changes from ability
        _applyCompanionSpecialSupportEffects(comp, result);
        if (result.chargeTimer > 0) {
          comp.chargeDamage = result.chargeDamage;
          comp.chargeSpeedMultiplier = result.chargeSpeedMultiplier;
          comp.chargeSweepRadius = result.chargeSweepRadius;
          comp.chargeOvershootDistance = result.chargeOvershootDistance;
          comp.chargeFinalSweepRadius = result.chargeFinalSweepRadius;
          comp.chargeHitIds = <int>{};
          final dir = attackTarget - comp.position;
          final dist = dir.distance;
          if (dist > 1) {
            final overshoot =
                attackTarget + (dir / dist) * comp.chargeOvershootDistance;
            comp.chargeTarget = overshoot;
            final travelTime =
                (overshoot - comp.position).distance /
                (CosmicSurvivalCompanion.chargeSpeed *
                    comp.chargeSpeedMultiplier);
            comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
          } else {
            comp.chargeTarget = attackTarget;
            comp.chargeTimer = result.chargeTimer;
          }
        }
        if (result.basicHasteTimer > 0) {
          comp.basicHasteTimer = result.basicHasteTimer;
          comp.basicHasteMultiplier = result.basicHasteMultiplier;
        }

        // Double Cast — fires echo 2 seconds after the first cast
        if (powerUps.companionHasDoubleCast(slotIndex)) {
          comp.doubleCastTimer = 2.0;
          comp.doubleCastTargetPos = attackTarget;
          comp.doubleCastAngle = comp.angle;
        }

        _emitMysticSpecialCast(
          companion: comp,
          origin: comp.position,
          target: attackTarget,
        );
        if (comp.member.family.toLowerCase() != 'mystic') {
          _spawnHitSpark(comp.position, elementColor(comp.member.element));
        }
      }
    } else if (!comp.tethered) {
      final drift = comp.anchor - comp.position;
      if (drift.distance > 4) {
        _setCompanionAngle(comp, atan2(drift.dy, drift.dx), 0.12);
      }
    }

    // Companion takes damage from enemies
    for (final e in enemies) {
      if (e.isDead) continue;
      if (_withinRange(comp.position, e.position, e.radius + 15)) {
        final contactDmg = CosmicBalance.enemyCompanionContactDamage(e.tier);
        final dmg = max(
          1,
          (contactDmg *
                  100 /
                  (100 +
                      comp.physDef *
                          powerUps.companionDefenseMultiplier(slotIndex)))
              .round(),
        );
        comp.takeDamage(dmg);
        comp.hitFlash = 1.0;

        // Phoenix Rebirth
        if (comp.currentHp <= 0 &&
            powerUps.companionHasPhoenixRebirth(slotIndex)) {
          comp.currentHp = comp.maxHp;
          comp.isDead = false;
          powerUps.consumePhoenixRebirth(slotIndex);
        }

        if (comp.currentHp <= 0) comp.isDead = true;
      }
    }
  }

  _CompanionTargetChoice? _pickCompanionTargetChoice(
    CosmicSurvivalCompanion comp,
  ) {
    final family = comp.member.family.toLowerCase();
    final maxScan = max(comp.attackRange, comp.specialAbilityRange) + 180;

    CosmicSurvivalEnemy? bestEnemy;
    var bestEnemyScore = double.negativeInfinity;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final dist = (enemy.position - comp.position).distance;
      if (dist > maxScan) continue;
      var score = 220.0 - dist;
      if (enemy.target == CosmicEnemyTarget.orb) score += 170;
      if (enemy.target == CosmicEnemyTarget.ship) score += 90;
      if (enemy.role == CosmicEnemyRole.shooter) score += 120;
      if (enemy.role == CosmicEnemyRole.hunter) score += 70;
      if (enemy.isElite) score += 80;
      score += (1.0 - enemy.hpFraction) * 70;
      final orbDist = (enemy.position - orb.position).distance;
      score += max(0.0, 180 - orbDist) * 0.45;

      switch (family) {
        case 'horn':
          if (enemy.target == CosmicEnemyTarget.orb) score += 180;
          if (orbDist < 180) score += 120;
        case 'wing':
          if (enemy.role == CosmicEnemyRole.shooter) score += 140;
          if (enemy.role == CosmicEnemyRole.hunter) score += 80;
        case 'kin':
          if (enemy.target == CosmicEnemyTarget.orb) score += 150;
          if (enemy.target == CosmicEnemyTarget.ship) score += 110;
        case 'let':
          if (enemy.target == CosmicEnemyTarget.orb) score += 140;
          if (enemy.role == CosmicEnemyRole.orbiter) score += 90;
        case 'pip':
          score += (1.0 - enemy.hpFraction) * 180;
          if (enemy.role == CosmicEnemyRole.shooter) score += 75;
        case 'mane':
          score += max(0.0, 140 - dist) * 0.4;
        case 'mask':
          if (enemy.target == CosmicEnemyTarget.orb) score += 150;
          if (enemy.role == CosmicEnemyRole.hunter) score += 110;
        case 'mystic':
          if (enemy.isElite) score += 120;
          if (enemy.role == CosmicEnemyRole.shooter) score += 70;
          if (enemy.target == CosmicEnemyTarget.orb) score += 90;
      }
      // Sticky target bonus: prefer continuing to attack the same enemy
      if (identical(enemy, comp.stickyTarget)) score += 65;

      if (score > bestEnemyScore) {
        bestEnemyScore = score;
        bestEnemy = enemy;
      }
    }

    final boss = activeBoss;
    if (boss != null && !boss.isDead) {
      final bossDist = (boss.position - comp.position).distance;
      if (bossDist <= maxScan * 1.2) {
        var bossScore = 180.0 - bossDist;
        if (family == 'wing' || family == 'let' || family == 'mystic') {
          bossScore += 120;
        } else if (family == 'horn' || family == 'mane') {
          bossScore += 55;
        }
        if (boss.hpFraction < 0.45) bossScore += 80;
        if (bossScore >= bestEnemyScore - 20) {
          return _CompanionTargetChoice(position: boss.position, isBoss: true);
        }
      }
    }

    if (bestEnemy != null) {
      return _CompanionTargetChoice(
        position: bestEnemy.position,
        enemy: bestEnemy,
      );
    }
    if (boss != null && !boss.isDead) {
      return _CompanionTargetChoice(position: boss.position, isBoss: true);
    }
    return null;
  }

  Offset? _desiredCompanionMoveTarget(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    _CompanionTargetChoice? choice,
  ) {
    final family = comp.member.family.toLowerCase();
    final formationPoint = _companionFormationPoint(slotIndex, family);
    final idleAnchor = _companionIdleAnchor(
      slotIndex,
      family,
      comp,
      formationPoint,
    );
    if (choice == null) return idleAnchor;

    final targetPos = choice.position;
    final toTarget = targetPos - comp.position;
    final dist = toTarget.distance;
    if (dist <= 0.001) return null;
    final norm = Offset(toTarget.dx / dist, toTarget.dy / dist);
    final desiredRange = _familyPreferredDistance(comp, family);

    switch (family) {
      case 'horn':
        return targetPos - norm * desiredRange;
      case 'wing':
        return targetPos - norm * desiredRange;
      case 'kin':
        if ((targetPos - ship.position).distance < 150) {
          return ship.position - norm * 120;
        }
        return targetPos - norm * desiredRange;
      case 'let':
        if (dist > desiredRange * 1.15) {
          return targetPos - norm * desiredRange;
        }
        if (dist < desiredRange * 0.72) {
          return comp.position - norm * 50;
        }
        return comp.anchor; // hold position in preferred range band
      case 'pip':
        return targetPos - norm * desiredRange;
      case 'mane':
        return targetPos - norm * desiredRange;
      case 'mask':
        if (choice.enemy != null &&
            (choice.enemy!.target == CosmicEnemyTarget.orb ||
                (choice.enemy!.position - orb.position).distance < 170)) {
          return Offset.lerp(orb.position, choice.enemy!.position, 0.55);
        }
        return targetPos - norm * desiredRange;
      case 'mystic':
        return targetPos - norm * desiredRange;
      default:
        return targetPos - norm * desiredRange;
    }
  }

  Offset _resolveCompanionMoveTarget(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    Offset desiredTarget,
    _CompanionTargetChoice? choice,
  ) {
    final family = comp.member.family.toLowerCase();
    var resolved = desiredTarget;

    final threatPos = choice?.position;
    if (threatPos != null) {
      final minEnemyGap = _familyMinimumEnemyGap(comp, family);
      final toThreat = resolved - threatPos;
      final threatDist = toThreat.distance;
      if (threatDist < minEnemyGap) {
        if (threatDist > 0.001) {
          final norm = Offset(
            toThreat.dx / threatDist,
            toThreat.dy / threatDist,
          );
          resolved = threatPos + norm * minEnemyGap;
        } else {
          resolved = Offset(
            threatPos.dx + cos(comp.angle + pi) * minEnemyGap,
            threatPos.dy + sin(comp.angle + pi) * minEnemyGap,
          );
        }
      }
    }

    final separationRadius = _familyCompanionSeparationRadius(family);
    var separation = Offset.zero;
    for (final entry in activeCompanions.entries) {
      if (entry.key == slotIndex) continue;
      final other = entry.value;
      if (other.isDead) continue;
      final delta = resolved - other.position;
      final dist = delta.distance;
      if (dist <= 0.001 || dist >= separationRadius) continue;
      final strength = (separationRadius - dist) / separationRadius;
      separation += Offset(delta.dx / dist, delta.dy / dist) * strength;
    }
    if (separation != Offset.zero) {
      final pushScale = switch (family) {
        'horn' => 22.0,
        'let' => 30.0,
        'kin' => 28.0,
        'mystic' => 30.0,
        _ => 24.0,
      };
      resolved += separation * pushScale;
    }

    return resolved;
  }

  Offset _companionIdleAnchor(
    int slotIndex,
    String family,
    CosmicSurvivalCompanion comp,
    Offset fallbackFormationPoint,
  ) {
    final orbitPhase = stats.timeElapsed * 0.75 + slotIndex * 0.9;
    final idleRadius = switch (family) {
      'horn' => 14.0,
      'mane' => 18.0,
      'wing' => 22.0,
      'let' => 20.0,
      'pip' => 16.0,
      'mask' => 18.0,
      'kin' => 20.0,
      'mystic' => 22.0,
      _ => 18.0,
    };
    var anchor = Offset(
      fallbackFormationPoint.dx + cos(orbitPhase) * idleRadius,
      fallbackFormationPoint.dy + sin(orbitPhase * 1.15) * idleRadius * 0.55,
    );
    final orbDist = (anchor - orb.position).distance;
    if (orbDist > 320) {
      final toOrb = anchor - orb.position;
      if (orbDist > 0.001) {
        final norm = Offset(toOrb.dx / orbDist, toOrb.dy / orbDist);
        anchor = orb.position + norm * 220;
      } else {
        anchor = fallbackFormationPoint;
      }
    }

    final shipDist = (anchor - ship.position).distance;
    if (shipDist > 420 && !ship.isDead) {
      anchor = Offset.lerp(anchor, fallbackFormationPoint, 0.35) ?? anchor;
    }
    return anchor;
  }

  void _setCompanionAngle(
    CosmicSurvivalCompanion comp,
    double targetAngle,
    double smoothing,
  ) {
    final delta = atan2(
      sin(targetAngle - comp.angle),
      cos(targetAngle - comp.angle),
    );
    comp.angle += delta * smoothing.clamp(0.0, 1.0);
  }

  Offset _companionFormationPoint(int slotIndex, String family) {
    final angle = -pi / 2 + slotIndex * 0.9;
    final radius = switch (family) {
      'horn' => 88.0,
      'kin' => 132.0,
      'let' => 148.0,
      'mask' => 118.0,
      'mystic' => 138.0,
      'wing' => 118.0,
      'pip' => 98.0,
      _ => 108.0,
    };
    return Offset(
      ship.position.dx + cos(angle) * radius,
      ship.position.dy + sin(angle) * radius,
    );
  }

  double _familyPreferredDistance(CosmicSurvivalCompanion comp, String family) {
    return switch (family) {
      'horn' => comp.attackRange * 0.38,
      'mane' => comp.attackRange * 0.55,
      'pip' => comp.attackRange * 0.42,
      'mask' => comp.attackRange * 0.70,
      'wing' => comp.attackRange * 0.80,
      'kin' => comp.attackRange * 0.95,
      'mystic' => comp.specialAbilityRange * 0.95,
      'let' => comp.specialAbilityRange * 1.02,
      _ => comp.attackRange * 0.60,
    };
  }

  double _familyMinimumEnemyGap(CosmicSurvivalCompanion comp, String family) {
    final preferred = _familyPreferredDistance(comp, family);
    return switch (family) {
      'horn' => max(40.0, preferred * 0.55),
      'mane' => max(46.0, preferred * 0.72),
      'pip' => max(44.0, preferred * 0.78),
      'mask' => max(52.0, preferred * 0.80),
      'wing' => max(56.0, preferred * 0.82),
      'kin' => max(72.0, preferred * 0.92),
      'mystic' => max(86.0, preferred * 0.95),
      'let' => max(92.0, preferred * 0.98),
      _ => max(48.0, preferred * 0.75),
    };
  }

  double _familyCompanionSeparationRadius(String family) {
    return switch (family) {
      'horn' => 42.0,
      'mane' => 38.0,
      'wing' => 40.0,
      'kin' => 48.0,
      'let' => 54.0,
      'pip' => 34.0,
      'mask' => 44.0,
      'mystic' => 50.0,
      _ => 40.0,
    };
  }

  double _familyMovementSpeedMultiplier(String family) {
    return switch (family.toLowerCase()) {
      'horn' => 0.94,
      'mane' => 1.02,
      'wing' => 1.20,
      'kin' => 0.88,
      'let' => 0.74,
      'pip' => 1.24,
      'mask' => 0.92,
      'mystic' => 0.84,
      _ => 1.0,
    };
  }

  void summonCompanion(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= party.length) return;
    if (defeatedCompanionSlots.contains(slotIndex)) return;

    // Already active? Return it instead.
    if (activeCompanions.containsKey(slotIndex)) {
      returnCompanion(slotIndex);
      return;
    }

    // At max capacity? Return the oldest one first (only if max is 1).
    if (activeCompanions.length >= maxActiveCompanions) {
      if (maxActiveCompanions <= 1) {
        returnCompanion(activeCompanions.keys.first);
      } else {
        return; // Can't add more — panel already shows slots as active
      }
    }

    final member = party[slotIndex];
    final level = CosmicBalance.clampCompanionLevel(member.level);
    final family = member.family.toLowerCase();
    final str = member.statStrength.toDouble();
    final intel = member.statIntelligence.toDouble();
    final beauty = member.statBeauty.toDouble();
    final speed = member.statSpeed.toDouble();

    // Family-specific multipliers for survival mode.
    // horn  = tank: massive HP/def, short range, slow heavy hits
    // mane  = bruiser: extra HP, fast cooldowns, close range
    // wing  = sniper: long range, bonus elemAtk, fragile
    // let   = siege: big damage, slow, sturdy
    // pip   = assassin: fast attacks, high crit, fragile
    // mask  = duelist: piercing attacks, balanced, evasive
    // kin   = support: extra HP, broad range, summon orbs
    // mystic = glass cannon: huge elemAtk, slow special, long range
    final (
      double hpMult,
      double physAtkMult,
      double elemAtkMult,
      double physDefMult,
      double elemDefMult,
      double critMult,
    ) = switch (family) {
      'horn' => (1.40, 1.10, 0.80, 1.30, 1.20, 0.90),
      'mane' => (1.15, 1.15, 1.00, 1.10, 1.00, 1.10),
      'wing' => (0.85, 0.90, 1.30, 0.85, 0.90, 1.00),
      'let' => (1.20, 1.25, 1.10, 1.15, 1.10, 0.85),
      'pip' => (0.80, 1.00, 0.95, 0.80, 0.85, 1.40),
      'mask' => (1.00, 1.10, 1.10, 1.00, 1.05, 1.20),
      'kin' => (1.20, 0.90, 0.90, 1.10, 1.15, 0.90),
      'mystic' => (0.90, 0.85, 1.45, 0.85, 0.90, 1.00),
      _ => (1.00, 1.00, 1.00, 1.00, 1.00, 1.00),
    };

    final strPow = CosmicSurvivalBalance.survivalStatPower(str);
    final intPow = CosmicSurvivalBalance.survivalStatPower(intel);
    final beautyPow = CosmicSurvivalBalance.survivalStatPower(beauty);

    final maxHp =
        ((110 + level * 18 + 320 * strPow + 150 * intPow) *
                hpMult *
                powerUps.companionHpMultiplier(slotIndex))
            .round();

    final levelFactor = 1.04 + (level - 1) * 0.065;
    final physAtk = max(
      1,
      ((5.0 + 24.0 * strPow) * levelFactor * physAtkMult).round(),
    );
    final elemAtk = max(
      1,
      ((5.5 + 25.0 * beautyPow) * levelFactor * elemAtkMult).round(),
    );

    final physDef =
        ((15 + level * 2.8 + 58 * strPow + 34 * intPow) * physDefMult).round();
    final elemDef =
        ((15 + level * 2.8 + 58 * beautyPow + 34 * intPow) * elemDefMult)
            .round();

    var cooldownReduction = CosmicBalance.companionCooldownReduction(speed);
    var critChance = ((0.05 + strPow * 0.32) * critMult).clamp(0.05, 0.55);
    var baseRange = 100.0 + intel * 28.0;

    // ── Guardian stat upgrades (permanent passive bonuses) ──
    double guardianUpgradeValue(GuardianUpgrade u) {
      final lvl = upgradeState.getGuardianLevel(u);
      if (lvl <= 0) return 0.0;
      return getGuardianUpgradeDef(u).valuePerLevel[lvl - 1];
    }

    cooldownReduction *= (1 + guardianUpgradeValue(GuardianUpgrade.cooldown));
    final guardDefMult = 1 + guardianUpgradeValue(GuardianUpgrade.defense);
    final guardAtkMult = 1 + guardianUpgradeValue(GuardianUpgrade.attack);
    critChance = (critChance + guardianUpgradeValue(GuardianUpgrade.critChance))
        .clamp(0.05, 0.65);
    baseRange *= (1 + guardianUpgradeValue(GuardianUpgrade.range));

    final startHpFrac = companionHpFraction[slotIndex] ?? 1.0;
    final startHp = (maxHp * startHpFrac).round().clamp(1, maxHp);
    final savedSpecialCooldown = companionSpecialCooldown[slotIndex];

    final companion = CosmicSurvivalCompanion(
      member: member,
      position: ship.position,
      anchor: ship.position,
      maxHp: maxHp,
      currentHp: startHp,
      physAtk: (physAtk * guardAtkMult).round(),
      elemAtk: (elemAtk * guardAtkMult).round(),
      physDef: (physDef * guardDefMult).round(),
      elemDef: (elemDef * guardDefMult).round(),
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: _familyAttackRange(family, baseRange),
      specialAbilityRange: _familySpecialRange(family, baseRange),
      tethered: tetherModeEnabled && tetheredCompanionSlot == null,
    );
    companion.primeSpecialCooldown(
      savedCooldown: savedSpecialCooldown,
      cooldownMultiplier:
          1.0 - powerUps.companionCooldownReduction(slotIndex).clamp(0.0, 0.5),
    );
    activeCompanions[slotIndex] = companion;
    companionSpecialCooldown[slotIndex] = companion.specialCooldown;
    if (tetherModeEnabled) {
      tetheredCompanionSlot ??= slotIndex;
      for (final entry in activeCompanions.entries) {
        entry.value.tethered = entry.key == tetheredCompanionSlot;
      }
    } else {
      activeCompanions[slotIndex]?.tethered = false;
    }
    _loadCompanionSprite(slotIndex, member);
  }

  Future<void> _loadCompanionSprite(
    int slotIndex,
    CosmicPartyMember member,
  ) async {
    final sheet = member.spriteSheet;
    if (sheet == null) {
      _companionTickers.remove(slotIndex);
      _companionVisuals.remove(slotIndex);
      return;
    }
    final image = await images.load(sheet.path);
    final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
    final anim = SpriteAnimation.fromFrameData(
      image,
      SpriteAnimationData.sequenced(
        amount: sheet.totalFrames,
        amountPerRow: cols,
        textureSize: sheet.frameSize,
        stepTime: sheet.stepTime,
        loop: true,
      ),
    );
    _companionTickers[slotIndex] = anim.createTicker();
    _companionVisuals[slotIndex] = member.spriteVisuals;
    final desiredSize = 48.0;
    final sx = desiredSize / sheet.frameSize.x;
    final sy = desiredSize / sheet.frameSize.y;
    final family = member.family.toLowerCase();
    final specScale = _companionSpeciesScale[family] ?? 1.3;
    _companionSpriteScales[slotIndex] =
        min(sx, sy) * (member.spriteVisuals?.scale ?? 1.0) * specScale;
  }

  void returnCompanion([int? slotIndex]) {
    if (slotIndex != null) {
      final comp = activeCompanions[slotIndex];
      if (comp == null) return;
      companionHpFraction[slotIndex] = comp.hpPercent;
      companionSpecialCooldown[slotIndex] = comp.specialCooldown;
      if (tetheredCompanionSlot == slotIndex) {
        tetheredCompanionSlot = null;
      }
      activeCompanions.remove(slotIndex);
      _companionTickers.remove(slotIndex);
      _companionVisuals.remove(slotIndex);
      _companionSpriteScales.remove(slotIndex);
      if (tetherModeEnabled &&
          tetheredCompanionSlot == null &&
          activeCompanions.isNotEmpty) {
        tetherClosestCompanionToShip();
      }
    } else {
      // Return all companions
      for (final entry in activeCompanions.entries) {
        companionHpFraction[entry.key] = entry.value.hpPercent;
        companionSpecialCooldown[entry.key] = entry.value.specialCooldown;
      }
      tetheredCompanionSlot = null;
      tetherModeEnabled = false;
      activeCompanions.clear();
      _companionTickers.clear();
      _companionVisuals.clear();
      _companionSpriteScales.clear();
    }
  }

  void clearCompanionTether() {
    tetherModeEnabled = false;
    tetheredCompanionSlot = null;
    for (final comp in activeCompanions.values) {
      comp.tethered = false;
    }
  }

  void tetherClosestCompanionToShip() {
    if (activeCompanions.isEmpty) {
      tetheredCompanionSlot = null;
      return;
    }
    tetherModeEnabled = true;
    int? closestSlot;
    var closestDistance = double.infinity;
    for (final entry in activeCompanions.entries) {
      if (entry.value.isDead) continue;
      final distance = (entry.value.position - ship.position).distance;
      if (distance < closestDistance) {
        closestDistance = distance;
        closestSlot = entry.key;
      }
    }
    if (closestSlot == null) return;
    tetheredCompanionSlot = closestSlot;
    for (final entry in activeCompanions.entries) {
      entry.value.tethered = entry.key == tetheredCompanionSlot;
    }
  }

  // Family range helpers (same as cosmic game)
  double _familyAttackRange(String family, double baseRange) {
    return switch (family.toLowerCase()) {
      'horn' => baseRange * 0.58,
      'mane' => baseRange * 0.85,
      'mask' => baseRange * 0.95,
      'kin' => baseRange * 0.90,
      'wing' => baseRange * 1.05,
      _ => baseRange,
    };
  }

  double _familySpecialRange(String family, double baseRange) {
    return switch (family.toLowerCase()) {
      'horn' => baseRange * 0.82,
      'mane' => baseRange * 1.05,
      'mask' => baseRange * 1.20,
      'let' => baseRange * 1.25,
      'pip' => baseRange * 1.20,
      'wing' => baseRange * 1.35,
      'kin' => baseRange * 1.10,
      'mystic' => baseRange * 1.45,
      _ => baseRange * 1.25,
    };
  }

  // == Enemies =============================================================

  void _updateEnemies(double dt, _ProjectileControlBuckets controlBuckets) {
    for (final enemy in enemies) {
      if (enemy.isDead) continue;

      enemy.slowTimer = (enemy.slowTimer - dt).clamp(0, 100);
      enemy.hitFlash = (enemy.hitFlash - dt * 4).clamp(0, 1);
      enemy.attackCooldown = max(0, enemy.attackCooldown - dt);
      enemy.retargetTimer = max(0, enemy.retargetTimer - dt);
      if (enemy.retargetTimer <= 0) {
        enemy.retargetTimer = 1.4 + _rng.nextDouble() * 1.2;
        enemy.target = _pickEnemyTarget(enemy);
      }

      if (_applyProjectileLureControl(enemy, dt, controlBuckets.lures)) {
        _applyEnemyContactDamage(enemy, dt);
        _applyDecoyContactDamage(enemy, controlBuckets.decoys);
        continue;
      }

      final targetPos = _targetPositionForEnemy(enemy);
      final dir = targetPos - enemy.position;
      final dist = dir.distance;
      if (dist > enemy.radius) {
        var moveSpeedMult = 1.0;
        for (final proj in controlBuckets.snares) {
          final center =
              proj.transferOrbitCenter ?? proj.orbitCenter ?? proj.position;
          final snareDist = (center - enemy.position).distance;
          if (snareDist > proj.snareRadius) continue;
          moveSpeedMult = min(moveSpeedMult, proj.snareMoveMultiplier);
        }
        final norm = dist > 0
            ? Offset(dir.dx / dist, dir.dy / dist)
            : Offset.zero;
        final tangent = Offset(-norm.dy, norm.dx);
        final move = switch (enemy.role) {
          CosmicEnemyRole.striker => norm,
          CosmicEnemyRole.hunter => norm,
          CosmicEnemyRole.orbiter => (norm * 0.55 + tangent * 0.85),
          CosmicEnemyRole.shooter => dist > 240 ? norm : tangent * 0.8,
        };
        enemy.position = Offset(
          enemy.position.dx +
              move.dx *
                  enemy.effectiveSpeed *
                  moveSpeedMult *
                  _timeDilationSlowFactor *
                  dt,
          enemy.position.dy +
              move.dy *
                  enemy.effectiveSpeed *
                  moveSpeedMult *
                  _timeDilationSlowFactor *
                  dt,
        );
        enemy.angle = atan2(norm.dy, norm.dx);
      }

      if (enemy.isShooter &&
          enemy.attackCooldown <= 0 &&
          dist < 300 &&
          dist > enemy.radius + 35) {
        enemy.attackCooldown =
            (1.7 - min(enemy.tier.index * 0.12, 0.5)) *
            (enemy.isRelentless ? 0.88 : 1.0) *
            ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                    spawner.currentMutator ==
                        SurvivalWaveMutator.shatteredSpace)
                ? 0.82
                : 1.0);
        enemyProjectiles.add(
          SurvivalEnemyProjectile(
            position: enemy.position,
            angle: enemy.angle,
            element: enemy.element,
            damage:
                enemy.damage *
                0.8 *
                ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                        spawner.currentMutator ==
                            SurvivalWaveMutator.shatteredSpace)
                    ? 1.08
                    : 1.0),
            target: enemy.target,
            speed:
                (210 + enemy.tier.index * 18) *
                ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                        spawner.currentMutator ==
                            SurvivalWaveMutator.shatteredSpace)
                    ? 1.10
                    : 1.0),
          ),
        );
      }

      _applyEnemyContactDamage(enemy, dt);
      _applyDecoyContactDamage(enemy, controlBuckets.decoys);
    }

    enemies.removeWhere((e) => e.isDead);
  }

  CosmicEnemyTarget _pickEnemyTarget(CosmicSurvivalEnemy enemy) {
    if (spawner.currentMutator == SurvivalWaveMutator.orbSiege &&
        enemy.role != CosmicEnemyRole.hunter) {
      return CosmicEnemyTarget.orb;
    }
    if (enemy.role == CosmicEnemyRole.striker) return CosmicEnemyTarget.orb;
    if (enemy.role == CosmicEnemyRole.hunter && !ship.isDead) {
      return _rng.nextDouble() < 0.7
          ? CosmicEnemyTarget.ship
          : CosmicEnemyTarget.companion;
    }
    if (enemy.role == CosmicEnemyRole.shooter) {
      if (activeCompanions.isNotEmpty && _rng.nextDouble() < 0.55) {
        return CosmicEnemyTarget.companion;
      }
      return ship.isDead ? CosmicEnemyTarget.orb : CosmicEnemyTarget.ship;
    }
    if (activeCompanions.isNotEmpty && _rng.nextDouble() < 0.3) {
      return CosmicEnemyTarget.companion;
    }
    return CosmicEnemyTarget.orb;
  }

  Offset _targetPositionForEnemy(CosmicSurvivalEnemy enemy) {
    return switch (enemy.target) {
      CosmicEnemyTarget.orb => orb.position,
      CosmicEnemyTarget.ship => ship.isDead ? orb.position : ship.position,
      CosmicEnemyTarget.companion =>
        _nearestCompanionPosition(enemy.position) ?? orb.position,
    };
  }

  Offset? _nearestCompanionPosition(Offset from) {
    CosmicSurvivalCompanion? best;
    var bestDist = double.infinity;
    for (final comp in activeCompanions.values) {
      if (comp.isDead) continue;
      final d = (comp.position - from).distance;
      if (d < bestDist) {
        bestDist = d;
        best = comp;
      }
    }
    return best?.position;
  }

  bool _applyProjectileLureControl(
    CosmicSurvivalEnemy enemy,
    double dt,
    List<Projectile> lureProjectiles,
  ) {
    Projectile? nearestLure;
    var nearestDist = double.infinity;
    for (final proj in lureProjectiles) {
      if (proj.decoy && proj.decoyHp <= 0) continue;
      final center =
          proj.transferOrbitCenter ?? proj.orbitCenter ?? proj.position;
      final dist = (center - enemy.position).distance;
      final aggroRadius = proj.tauntRadius > 0 ? proj.tauntRadius : 180.0;
      if (dist > aggroRadius || dist >= nearestDist) continue;
      nearestDist = dist;
      nearestLure = proj;
    }

    if (nearestLure == null) return false;

    final center =
        nearestLure.transferOrbitCenter ??
        nearestLure.orbitCenter ??
        nearestLure.position;
    final toLure = center - enemy.position;
    final dist = toLure.distance;
    if (dist <= 0.001) return true;

    final norm = Offset(toLure.dx / dist, toLure.dy / dist);
    final snareMoveMult = nearestLure.snareRadius > 0
        ? nearestLure.snareMoveMultiplier.clamp(0.2, 1.0).toDouble()
        : 1.0;
    final tauntSpeedMult = nearestLure.tauntStrength > 0
        ? (1.0 + nearestLure.tauntStrength * 0.08).clamp(1.0, 1.6).toDouble()
        : 1.0;
    enemy.position = Offset(
      enemy.position.dx +
          norm.dx *
              enemy.effectiveSpeed *
              snareMoveMult *
              tauntSpeedMult *
              _timeDilationSlowFactor *
              dt,
      enemy.position.dy +
          norm.dy *
              enemy.effectiveSpeed *
              snareMoveMult *
              tauntSpeedMult *
              _timeDilationSlowFactor *
              dt,
    );
    enemy.angle = atan2(norm.dy, norm.dx);
    return true;
  }

  void _applyEnemyContactDamage(CosmicSurvivalEnemy enemy, double dt) {
    if (_withinRange(enemy.position, orb.position, enemy.radius + 30) &&
        enemy.target == CosmicEnemyTarget.orb) {
      final damageMultiplier = powerUps.hasMirrorShield ? 0.75 : 1.0;
      _damageOrb(enemy.damage * damageMultiplier);
      if (powerUps.hasMirrorShield) {
        _triggerMirrorShieldPulse(enemy.position, enemy.damage);
      }
      _killEnemy(enemy, grantAlchemyReward: false);
      return;
    }

    if (!ship.isDead) {
      if (_withinRange(enemy.position, ship.position, enemy.radius + 15) &&
          enemy.target != CosmicEnemyTarget.orb) {
        ship.currentHp -= enemy.damage * dt * 0.75;
        ship.hitFlash = 1.0;
        if (enemy.isVampiric) {
          enemy.hp = min(enemy.maxHp, enemy.hp + enemy.damage * dt * 0.4);
        }
        if (ship.currentHp <= 0) {
          ship.isDead = true;
          _shipRespawnTimer = 0;
        }
      }
    }

    for (final comp in activeCompanions.values) {
      if (comp.isDead) continue;
      if (_withinRange(enemy.position, comp.position, enemy.radius + 15) &&
          enemy.target == CosmicEnemyTarget.companion) {
        comp.takeDamage(max(1, enemy.damage.round()));
        comp.hitFlash = 1.0;
        if (enemy.isVampiric) {
          enemy.hp = min(enemy.maxHp, enemy.hp + enemy.damage * 0.18);
        }
        if (comp.currentHp <= 0) comp.isDead = true;
      }
    }
  }

  void _applyDecoyContactDamage(
    CosmicSurvivalEnemy enemy,
    List<Projectile> decoyProjectiles,
  ) {
    for (final decoy in decoyProjectiles) {
      if (!decoy.decoy || decoy.decoyHp <= 0) continue;
      final hitRadius =
          enemy.radius + Projectile.radius * decoy.radiusMultiplier;
      if (!_withinRange(enemy.position, decoy.position, hitRadius)) continue;

      decoy.decoyHp -= max(1.0, enemy.damage);
      enemy.hp -= decoy.damage * 0.3;
      _spawnHitSpark(decoy.position, elementColor(decoy.element ?? 'Earth'));
      if (enemy.hp <= 0) {
        _killEnemy(enemy);
      }
      if (decoy.decoyHp <= 0) {
        _spawnDecoyExplosion(decoy);
        companionProjectiles.remove(decoy);
      }
      return;
    }
  }

  void _spawnDecoyExplosion(Projectile decoy) {
    final count = max(0, decoy.deathExplosionCount);
    if (count == 0 || decoy.deathExplosionDamage <= 0) return;
    for (var i = 0; i < count; i++) {
      final angle = (i / count) * pi * 2;
      companionProjectiles.add(
        Projectile(
          position: decoy.position,
          angle: angle,
          element: decoy.element,
          damage: decoy.deathExplosionDamage,
          life: 0.85,
          speedMultiplier: decoy.deathExplosionRadius.clamp(0.6, 2.4),
          radiusMultiplier: decoy.deathExplosionRadius.clamp(0.8, 2.8),
          visualScale: min(1.8, decoy.deathExplosionRadius),
        ),
      );
    }
  }

  void _damageEnemy(
    CosmicSurvivalEnemy enemy,
    double damage, {
    int? sourceSlotIndex,
  }) {
    if (enemy.hasBulwark && enemy.hpFraction > 0.5) {
      damage *= 0.72;
    }
    if (enemy.isRelentless && enemy.slowTimer > 0) {
      damage *= 0.88;
    }
    enemy.hp -= damage;
    enemy.hitFlash = 1.0;

    if (powerUps.hasBerserker && orb.hpPercent < 0.3) {
      enemy.hp -= damage;
    }

    if (enemy.hp <= 0) _killEnemy(enemy, sourceSlotIndex: sourceSlotIndex);
  }

  void _killEnemy(
    CosmicSurvivalEnemy enemy, {
    int? sourceSlotIndex,
    bool grantAlchemyReward = true,
  }) {
    if (enemy.isDead) return;
    enemy.isDead = true;
    stats.kills++;
    final baseReward = tierShardReward(enemy.tier);
    var scoreGain = enemy.isElite ? (baseReward * 2.5).round() : baseReward;
    stats.score += scoreGain;
    final meterGain = switch (enemy.tier) {
      EnemyTier.wisp => 3.0,
      EnemyTier.drone => 5.0,
      EnemyTier.sentinel => 7.0,
      EnemyTier.phantom => 10.0,
      EnemyTier.brute => 13.0,
      EnemyTier.colossus => 18.0,
    };
    final alchemyValue =
        meterGain *
        (enemy.isElite ? 1.35 : 1.0) *
        (spawner.currentMutator == SurvivalWaveMutator.manaFlux ? 1.18 : 1.0);
    if (grantAlchemyReward && !ship.isDead) {
      _grantAlchemy(alchemyValue * _alchemyMeterGainMultiplier);
      _spawnAlchemyPickupBurst(
        enemy.position,
        _alchemyRewardColorForTier(enemy.tier),
        count: enemy.isElite ? 8 : 5,
      );
    }
    if (sourceSlotIndex != null) {
      final bloodPactHeal = powerUps.companionBloodPactHealPercent(
        sourceSlotIndex,
      );
      final companion = activeCompanions[sourceSlotIndex];
      if (bloodPactHeal > 0 && companion != null) {
        orb.currentHp = min(
          orb.maxHp,
          orb.currentHp + companion.maxHp * bloodPactHeal,
        );
      }
    }

    _spawnHitSpark(enemy.position, elementColor(enemy.element));
    _triggerEliteDeathAffix(enemy, sourceSlotIndex: sourceSlotIndex);

    if (powerUps.hasElementalFury) {
      final splashDamage = 10.0 + powerUps.elementalFuryLevel * 8.0;
      for (final other in enemies) {
        if (other.isDead) continue;
        if (_withinRange(other.position, enemy.position, 80)) {
          _damageEnemy(other, splashDamage, sourceSlotIndex: sourceSlotIndex);
        }
      }
    }
  }

  void _grantAlchemy(double value) {
    if (ship.isDead || value <= 0) return;
    alchemicalMeter = min(alchemicalMeterMax, alchemicalMeter + value);
  }

  Color _alchemyRewardColorForTier(EnemyTier tier) {
    return switch (tier) {
      EnemyTier.wisp => const Color(0xFF7DD3FC),
      EnemyTier.drone => const Color(0xFF60A5FA),
      EnemyTier.sentinel => const Color(0xFF34D399),
      EnemyTier.phantom => const Color(0xFFF472B6),
      EnemyTier.brute => const Color(0xFFF59E0B),
      EnemyTier.colossus => const Color(0xFFFFE082),
    };
  }

  void _spawnAlchemyPickupBurst(Offset center, Color color, {int count = 6}) {
    if (_vfx.length >= 150) return;
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * pi * 2;
      final speed = 32 + _rng.nextDouble() * 88;
      _vfx.add(
        _VfxParticle(
          x: center.dx,
          y: center.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: 2.0 + _rng.nextDouble() * 2.8,
          life: 0.22 + _rng.nextDouble() * 0.18,
          color: color,
        ),
      );
    }
  }

  void _triggerEliteDeathAffix(
    CosmicSurvivalEnemy enemy, {
    int? sourceSlotIndex,
  }) {
    if (!enemy.isElite) return;
    if (enemy.isVolatile) {
      final blastRadius = 110.0 + enemy.radius * 0.8;
      final blastDamage = 10.0 + enemy.damage * 0.65;
      for (final other in enemies) {
        if (other.isDead || identical(other, enemy)) continue;
        if (_withinRange(enemy.position, other.position, blastRadius)) {
          _damageEnemy(other, blastDamage, sourceSlotIndex: sourceSlotIndex);
        }
      }
      if (_withinRange(enemy.position, orb.position, blastRadius)) {
        _damageOrb(blastDamage * 0.55);
      }
      if (!ship.isDead &&
          _withinRange(enemy.position, ship.position, blastRadius)) {
        ship.currentHp -= blastDamage * 0.45;
        ship.hitFlash = 1.0;
        if (ship.currentHp <= 0) {
          ship.isDead = true;
          _shipRespawnTimer = 0;
        }
      }
      for (final comp in activeCompanions.values) {
        if (comp.isDead) continue;
        if (_withinRange(enemy.position, comp.position, blastRadius)) {
          comp.takeDamage(max(1, (blastDamage * 0.7).round()));
          comp.hitFlash = 1.0;
          if (comp.currentHp <= 0) comp.isDead = true;
        }
      }
      _spawnHitSpark(enemy.position, const Color(0xFFFFA34A));
    }
  }

  void _triggerMirrorShieldPulse(Offset impactPos, double incomingDamage) {
    final pulseRadius = 96.0;
    final pulseDamage = max(10.0, incomingDamage * 2.5);
    const reflectColor = Color(0xFFB3E5FC);
    _spawnBeam(orb.position, impactPos, reflectColor, width: 3.2, life: 0.12);
    _spawnHitSpark(impactPos, reflectColor);
    for (final other in enemies) {
      if (other.isDead) continue;
      if (_withinRange(other.position, impactPos, pulseRadius)) {
        _damageEnemy(other, pulseDamage);
      }
    }
    for (final proj in enemyProjectiles) {
      if (proj.life <= 0) continue;
      if (_withinRange(proj.position, impactPos, pulseRadius * 0.9)) {
        proj.life = 0;
      }
    }
    for (final proj in bossProjectiles) {
      if (proj.life <= 0) continue;
      if (_withinRange(proj.position, impactPos, pulseRadius * 0.9)) {
        proj.life = 0;
      }
    }
  }

  // == Boss ================================================================

  void _updateBoss(double dt) {
    final boss = activeBoss;
    if (boss == null || boss.isDead) return;

    boss.hitFlash = (boss.hitFlash - dt * 4).clamp(0, 1);
    if (boss.isSpawning) {
      _updateBossEntrance(dt, boss);
      return;
    }
    boss.phaseTimer += dt;

    switch (boss.discipline) {
      case SurvivalBossDiscipline.conductor:
        _updateBossConductor(dt, boss);
      case SurvivalBossDiscipline.duelist:
        _updateBossDuelist(dt, boss);
      case SurvivalBossDiscipline.artillery:
        _updateBossArtillery(dt, boss);
      case SurvivalBossDiscipline.trickster:
        _updateBossTrickster(dt, boss);
      case SurvivalBossDiscipline.standard:
        switch (boss.type) {
          case BossType.charger:
            _updateBossCharger(dt, boss);
          case BossType.gunner:
            _updateBossGunner(dt, boss);
          case BossType.skirmisher:
            _updateBossSkirmisher(dt, boss);
          case BossType.bulwark:
            _updateBossBulwark(dt, boss);
          case BossType.carrier:
            _updateBossCarrier(dt, boss);
          case BossType.warden:
            _updateBossWarden(dt, boss);
        }
    }

    _applyBossContactDamage(boss, dt);
  }

  void _beginBossEntrance(SurvivalBoss boss, double angle) {
    final dir = Offset(cos(angle), sin(angle));
    final tangent = Offset(-dir.dy, dir.dx);
    final target = boss.position;
    final (startDistance, duration, burstScale) = _bossEntranceSpec(boss);
    final lateralOffset = switch (boss.discipline) {
      SurvivalBossDiscipline.trickster => tangent * 120,
      SurvivalBossDiscipline.duelist => tangent * 36,
      SurvivalBossDiscipline.conductor => tangent * 64,
      _ => Offset.zero,
    };
    boss.spawnTargetPosition = target;
    boss.spawnFromPosition = target + dir * startDistance + lateralOffset;
    boss.position = boss.spawnFromPosition!;
    boss.spawnIntroDuration = duration;
    boss.spawnIntroTimer = boss.spawnIntroDuration;
    boss.angle = atan2(
      boss.spawnTargetPosition!.dy - boss.spawnFromPosition!.dy,
      boss.spawnTargetPosition!.dx - boss.spawnFromPosition!.dx,
    );
    _spawnDetonationBurst(
      target,
      boss.color.withValues(alpha: 0.8),
      boss.radius * burstScale,
    );
  }

  void _updateBossEntrance(double dt, SurvivalBoss boss) {
    final from = boss.spawnFromPosition;
    final target = boss.spawnTargetPosition;
    if (from == null || target == null) {
      boss.spawnIntroTimer = 0;
      return;
    }
    boss.spawnIntroTimer = max(0.0, boss.spawnIntroTimer - dt);
    final t = 1.0 - (boss.spawnIntroTimer / boss.spawnIntroDuration);
    final eased = _bossEntranceCurve(boss).transform(t.clamp(0.0, 1.0));
    boss.position = Offset.lerp(from, target, eased) ?? target;
    boss.angle = atan2(target.dy - from.dy, target.dx - from.dx);
    if (boss.spawnIntroTimer <= 0) {
      boss.position = target;
      boss.spawnFromPosition = null;
      boss.spawnTargetPosition = null;
    }
  }

  (double, double, double) _bossEntranceSpec(SurvivalBoss boss) {
    switch (boss.discipline) {
      case SurvivalBossDiscipline.conductor:
        return (360.0, 1.9, 3.0);
      case SurvivalBossDiscipline.duelist:
        return (300.0, 0.78, 2.0);
      case SurvivalBossDiscipline.artillery:
        return (420.0, 1.45, 2.8);
      case SurvivalBossDiscipline.trickster:
        return (220.0, 0.95, 1.9);
      case SurvivalBossDiscipline.standard:
        return switch (boss.type) {
          BossType.charger || BossType.skirmisher => (290.0, 0.86, 2.1),
          BossType.gunner || BossType.carrier => (340.0, 1.35, 2.5),
          BossType.bulwark || BossType.warden => (260.0, 1.18, 2.4),
        };
    }
  }

  Curve _bossEntranceCurve(SurvivalBoss boss) {
    switch (boss.discipline) {
      case SurvivalBossDiscipline.conductor:
        return Curves.easeInOutCubic;
      case SurvivalBossDiscipline.duelist:
        return Curves.easeOutBack;
      case SurvivalBossDiscipline.artillery:
        return Curves.easeOutQuart;
      case SurvivalBossDiscipline.trickster:
        return Curves.easeOutCirc;
      case SurvivalBossDiscipline.standard:
        return switch (boss.type) {
          BossType.charger || BossType.skirmisher => Curves.easeOutBack,
          BossType.gunner || BossType.carrier => Curves.easeOutQuart,
          BossType.bulwark || BossType.warden => Curves.easeOutCubic,
        };
    }
  }

  void _updateBossConductor(double dt, SurvivalBoss boss) {
    final anchor = orb.position;
    final toAnchor = anchor - boss.position;
    final dist = toAnchor.distance;
    final norm = dist > 1
        ? Offset(toAnchor.dx / dist, toAnchor.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    final targetDist = 280.0 + sin(boss.phaseTimer * 0.9) * 40.0;
    final radialForce = (dist - targetDist) * 0.48;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.62) * dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0) {
      boss.spreadTimer = max(2.0, 4.2 - boss.level * 0.06);
      final fanTarget =
          _nearestCompanionPosition(boss.position) ?? ship.position;
      final baseFanAngle = atan2(
        fanTarget.dy - boss.position.dy,
        fanTarget.dx - boss.position.dx,
      );
      final ringCount = boss.level >= 10 ? 8 : 6;
      for (var i = 0; i < ringCount; i++) {
        final a = baseFanAngle + (i - (ringCount - 1) / 2) * 0.16;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 7 + boss.level * 1.4,
            speed: 220,
            radius: 5.0,
            life: 3.5,
          ),
        );
      }
    }

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(5.5, 9.5 - boss.level * 0.12);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      for (final add in adds.take(4)) {
        add.target = switch (add.role) {
          CosmicEnemyRole.shooter => CosmicEnemyTarget.companion,
          CosmicEnemyRole.hunter => CosmicEnemyTarget.ship,
          _ => CosmicEnemyTarget.orb,
        };
      }
      enemies.addAll(adds.take(4));
    }
  }

  void _updateBossDuelist(double dt, SurvivalBoss boss) {
    final target =
        _nearestCompanionPosition(boss.position) ??
        (ship.isDead ? orb.position : ship.position);
    final toTarget = target - boss.position;
    final dist = toTarget.distance;
    final norm = dist > 1
        ? Offset(toTarget.dx / dist, toTarget.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    final targetDist = boss.hpFraction < 0.45 ? 95.0 : 135.0;
    final radialForce = (dist - targetDist) * 0.95;
    final weave = sin(boss.phaseTimer * 4.0) * boss.speed * 0.48;
    boss.position += (norm * radialForce + tangent * weave) * dt;
    boss.angle = atan2(toTarget.dy, toTarget.dx);

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = boss.hpFraction < 0.45 ? 0.85 : 1.15;
      final burstCount = boss.hpFraction < 0.45 ? 5 : 3;
      for (var i = 0; i < burstCount; i++) {
        final a = boss.angle + (i - (burstCount - 1) / 2) * 0.12;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 8 + boss.level * 1.9,
            speed: 305,
            radius: 4.8,
            life: 2.6,
          ),
        );
      }
    }

    boss.chargeTimer -= dt;
    if (boss.chargeTimer <= 0) {
      boss.chargeTimer = max(2.8, 5.0 - boss.level * 0.08);
      final sweepCount = 2 + (boss.level >= 12 ? 1 : 0);
      for (var i = 0; i < sweepCount; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        final a = boss.angle + side * (0.34 + i * 0.08);
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 6 + boss.level * 1.4,
            speed: 255,
            radius: 6.2,
            life: 2.2,
          ),
        );
      }
    }
  }

  void _updateBossArtillery(double dt, SurvivalBoss boss) {
    final anchor = ship.isDead ? orb.position : ship.position;
    final toAnchor = anchor - boss.position;
    final dist = toAnchor.distance;
    final norm = dist > 1
        ? Offset(toAnchor.dx / dist, toAnchor.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    const targetDist = 340.0;
    final radialForce = (dist - targetDist) * 0.42;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.35) * dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = max(1.2, 2.6 - boss.level * 0.04);
      final targets = <Offset>[
        orb.position,
        if (!ship.isDead) ship.position,
        ...activeCompanions.values
            .where((c) => !c.isDead)
            .take(2)
            .map((c) => c.position),
      ];
      for (final target in targets.take(3)) {
        final shotAngle = atan2(
          target.dy - boss.position.dy,
          target.dx - boss.position.dx,
        );
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: shotAngle,
            element: boss.template.element,
            damage: 10 + boss.level * 2.4,
            speed: 190,
            radius: 7.0,
            life: 5.0,
          ),
        );
      }
    }

    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0) {
      boss.spreadTimer = 4.5;
      for (var i = 0; i < 6; i++) {
        final a = boss.angle + (i - 2.5) * 0.18;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 7 + boss.level * 1.5,
            speed: 260,
            radius: 5.5,
            life: 3.2,
          ),
        );
      }
    }
  }

  void _updateBossTrickster(double dt, SurvivalBoss boss) {
    final anchor = ship.isDead ? orb.position : ship.position;
    final toAnchor = anchor - boss.position;
    final dist = toAnchor.distance;
    final norm = dist > 1
        ? Offset(toAnchor.dx / dist, toAnchor.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    final targetDist = 190.0 + sin(boss.phaseTimer * 1.7) * 45.0;
    final radialForce = (dist - targetDist) * 0.75;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.82) * dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0) {
      boss.escortTimer = max(4.5, 8.5 - boss.level * 0.12);
      final blinkAngle = _rng.nextDouble() * pi * 2;
      boss.position =
          anchor + Offset(cos(blinkAngle) * 210, sin(blinkAngle) * 210);
      final fanTarget =
          _nearestCompanionPosition(boss.position) ?? ship.position;
      final fanAngle = atan2(
        fanTarget.dy - boss.position.dy,
        fanTarget.dx - boss.position.dx,
      );
      for (var i = 0; i < 5; i++) {
        final a = fanAngle + (i - 2) * 0.22;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 8 + boss.level * 1.8,
            speed: 300,
            radius: 4.5,
            life: 2.8,
          ),
        );
      }
    }

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(7.0, 12.0 - boss.level * 0.15);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      enemies.addAll(adds.take(3));
    }
  }

  void _applyBossContactDamage(SurvivalBoss boss, double dt) {
    final orbDist = (boss.position - orb.position).distance;
    if (orbDist < boss.radius + 30) {
      _damageOrb(18 * dt);
    }

    if (!ship.isDead) {
      final shipDist = (boss.position - ship.position).distance;
      if (shipDist < boss.radius + 15) {
        ship.currentHp -= 16 * dt;
        ship.hitFlash = 1.0;
        if (ship.currentHp <= 0) {
          ship.isDead = true;
          _shipRespawnTimer = 0;
        }
      }
    }

    for (final comp in activeCompanions.values) {
      if (comp.isDead) continue;
      final dist = (boss.position - comp.position).distance;
      if (dist < boss.radius + 16) {
        comp.takeDamage(14 + boss.level * 2);
        comp.hitFlash = 1.0;
      }
    }
  }

  void _updateBossCharger(double dt, SurvivalBoss boss) {
    if (boss.charging) {
      boss.chargeDashTimer -= dt;
      final dashSpeed = boss.baseSpeed * SurvivalBoss.chargeSpeedMultiplier;
      boss.position = Offset(
        boss.position.dx + cos(boss.chargeAngle) * dashSpeed * dt,
        boss.position.dy + sin(boss.chargeAngle) * dashSpeed * dt,
      );
      if (boss.chargeDashTimer <= 0) boss.charging = false;
    } else {
      boss.chargeTimer -= dt;
      final toOrb = orb.position - boss.position;
      final dist = toOrb.distance;
      boss.angle = atan2(toOrb.dy, toOrb.dx);

      const orbitDist = 220.0;
      final norm = dist > 1
          ? Offset(toOrb.dx / dist, toOrb.dy / dist)
          : Offset.zero;
      final tangent = Offset(-norm.dy, norm.dx);
      final radialForce = (dist - orbitDist) * 0.8;
      boss.position += (norm * radialForce + tangent * boss.speed * 0.8) * dt;

      if (boss.chargeTimer <= 0) {
        // Charge toward ship if alive, else toward orb
        final target = ship.isDead ? orb.position : ship.position;
        final toTarget = target - boss.position;
        boss.chargeAngle = atan2(toTarget.dy, toTarget.dx);
        boss.charging = true;
        boss.chargeDashTimer = SurvivalBoss.chargeDashDuration;
        boss.chargeTimer = SurvivalBoss.chargeCooldown;
      }
    }
  }

  void _updateBossGunner(double dt, SurvivalBoss boss) {
    final anchor = ship.isDead ? orb.position : ship.position;
    final toOrb = anchor - boss.position;
    final dist = toOrb.distance;
    final tangent = Offset(-toOrb.dy / dist, toOrb.dx / dist);
    const orbitDist = 250.0;
    final radialForce = (dist - orbitDist) * 0.5;
    final norm = Offset(toOrb.dx / dist, toOrb.dy / dist);
    boss.position += (norm * radialForce + tangent * boss.speed * 0.5) * dt;
    boss.angle = atan2(toOrb.dy, toOrb.dx);

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = SurvivalBoss.shootCooldown;
      final dmgScale = 0.7 + boss.level * 0.14;
      for (final offset in [-0.16, 0.16]) {
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: boss.angle + offset,
            element: boss.template.element,
            damage: dmgScale * 12,
            speed: 300,
          ),
        );
      }
    }

    boss.shieldTimer -= dt;
    if (!boss.shieldUp && boss.shieldTimer <= 0) {
      boss.shieldUp = true;
      boss.shieldHealth = SurvivalBoss.shieldMaxHealth;
      boss.shieldTimer = SurvivalBoss.shieldDuration;
    } else if (boss.shieldUp &&
        (boss.shieldTimer <= 0 || boss.shieldHealth <= 0)) {
      boss.shieldUp = false;
      boss.shieldTimer = SurvivalBoss.shieldCooldown;
    }
  }

  void _updateBossSkirmisher(double dt, SurvivalBoss boss) {
    final anchor = _nearestCompanionPosition(boss.position) ?? ship.position;
    final toOrb = (ship.isDead ? orb.position : anchor) - boss.position;
    final dist = toOrb.distance;
    final norm = dist > 1
        ? Offset(toOrb.dx / dist, toOrb.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    final targetDist = 180.0 + sin(boss.phaseTimer * 1.5) * 60;
    final radialForce = (dist - targetDist) * 0.8;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.7) * dt;
    boss.angle = atan2(toOrb.dy, toOrb.dx);

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = 1.2;
      final dmgScale = 0.7 + boss.level * 0.14;
      bossProjectiles.add(
        SurvivalBossProjectile(
          position: boss.position,
          angle: boss.angle,
          element: boss.template.element,
          damage: dmgScale * 10,
          speed: 350,
        ),
      );
    }
  }

  void _updateBossBulwark(double dt, SurvivalBoss boss) {
    final toOrb = orb.position - boss.position;
    final dist = toOrb.distance;
    final norm = dist > 1
        ? Offset(toOrb.dx / dist, toOrb.dy / dist)
        : Offset.zero;
    boss.angle = atan2(toOrb.dy, toOrb.dx);

    const targetDist = 145.0;
    final tangent = Offset(-norm.dy, norm.dx);
    final radialForce = (dist - targetDist) * 0.75;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.45) * dt;

    boss.shieldTimer -= dt;
    if (!boss.shieldUp) {
      if (boss.shieldTimer <= 0) {
        boss.shieldUp = true;
        boss.shieldHealth = SurvivalBoss.shieldMaxHealth * 2;
        boss.shieldTimer = SurvivalBoss.shieldDuration * 2;
      }
    } else if (boss.shieldHealth <= 0 || boss.shieldTimer <= 0) {
      boss.shieldUp = false;
      boss.shieldTimer = SurvivalBoss.shieldCooldown;
    }
  }

  void _updateBossCarrier(double dt, SurvivalBoss boss) {
    final anchor = ship.isDead ? orb.position : ship.position;
    final toOrb = anchor - boss.position;
    final dist = toOrb.distance;
    final tangent = dist > 1
        ? Offset(-toOrb.dy / dist, toOrb.dx / dist)
        : Offset.zero;
    final norm = dist > 1
        ? Offset(toOrb.dx / dist, toOrb.dy / dist)
        : Offset.zero;
    final radialForce = (dist - 300) * 0.4;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.4) * dt;
    boss.angle = atan2(toOrb.dy, toOrb.dx);

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0) {
      boss.escortTimer = SurvivalBoss.escortCooldown;
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      enemies.addAll(adds);
    }

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = 2.6;
      final shotAngle = atan2(
        anchor.dy - boss.position.dy,
        anchor.dx - boss.position.dx,
      );
      bossProjectiles.add(
        SurvivalBossProjectile(
          position: boss.position,
          angle: shotAngle,
          element: boss.template.element,
          damage: 8 + boss.level * 2.2,
          speed: 240,
        ),
      );
    }
  }

  void _updateBossWarden(double dt, SurvivalBoss boss) {
    final toOrb = orb.position - boss.position;
    final dist = toOrb.distance;
    final norm = dist > 1
        ? Offset(toOrb.dx / dist, toOrb.dy / dist)
        : Offset.zero;
    boss.angle = atan2(toOrb.dy, toOrb.dx);

    if (!boss.enraged && boss.hpFraction <= SurvivalBoss.enrageThreshold) {
      boss.enraged = true;
      boss.speed = boss.baseSpeed * 1.5;
    }

    final targetDist = boss.enraged ? 140.0 : 220.0;
    final tangent = Offset(-norm.dy, norm.dx);
    final radialForce = (dist - targetDist) * 0.65;
    boss.position += (norm * radialForce + tangent * boss.speed * 0.55) * dt;

    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0) {
      boss.spreadTimer = boss.enraged ? 1.5 : SurvivalBoss.spreadCooldown;
      final fanCount = boss.enraged ? 8 : 5;
      final dmgScale = 0.85 + boss.level * 0.18;
      for (var i = 0; i < fanCount; i++) {
        final a = boss.angle + (i - fanCount / 2) * 0.3;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: dmgScale * 12,
            speed: 220,
          ),
        );
      }
    }

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = SurvivalBoss.summonCooldown;
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      enemies.addAll(adds);
    }
  }

  void damageBoss(double damage, {String? attackElement}) {
    final boss = activeBoss;
    if (boss == null || boss.isDead) return;

    // Apply element effectiveness
    final effectiveDamage = attackElement != null
        ? damage *
              BattleEngine.getTypeMultiplier(attackElement, [
                boss.template.element,
              ])
        : damage;

    if (boss.shieldUp) {
      boss.shieldHealth -= effectiveDamage / 6;
      if (boss.shieldHealth <= 0) {
        boss.shieldUp = false;
        boss.shieldTimer = SurvivalBoss.shieldCooldown;
      }
      return;
    }

    boss.hp -= effectiveDamage;
    boss.hitFlash = 1.0;

    if (boss.hp <= 0) {
      boss.isDead = true;
      stats.kills++;
      stats.score += (boss.template.health * 2).round();
      _spawnBossAlchemyReward(boss);
      _spawnHitSpark(boss.position, boss.color);
      activeBoss = null;
    }
  }

  void _spawnBossAlchemyReward(SurvivalBoss boss) {
    if (ship.isDead) return;
    final baseValue = max(
      26.0,
      34.0 + boss.level * 8.0 + boss.radius * 0.45 + spawner.currentWave * 1.6,
    );
    _grantAlchemy(baseValue * _alchemyMeterGainMultiplier);
    _spawnAlchemyPickupBurst(boss.position, boss.color, count: 10);
  }

  void _updateBossProjectiles(double dt, List<Projectile> interceptors) {
    for (final proj in bossProjectiles) {
      proj.position = Offset(
        proj.position.dx + cos(proj.angle) * proj.speed * dt,
        proj.position.dy + sin(proj.angle) * proj.speed * dt,
      );
      proj.life -= dt;

      if (_consumeCompanionInterceptionAt(
        proj.position,
        proj.radius,
        interceptors,
      )) {
        proj.life = 0;
        continue;
      }

      // Hit ship
      if (!ship.isDead) {
        if (_withinRange(proj.position, ship.position, proj.radius + 12)) {
          ship.currentHp -= proj.damage;
          ship.hitFlash = 1.0;
          if (ship.currentHp <= 0) {
            ship.isDead = true;
            _shipRespawnTimer = 0;
          }
          proj.life = 0;
        }
      }

      // Hit companions
      for (final comp in activeCompanions.values) {
        if (comp.isDead) continue;
        if (_withinRange(proj.position, comp.position, proj.radius + 12)) {
          comp.takeDamage(proj.damage.round());
          comp.hitFlash = 1.0;
          if (comp.currentHp <= 0) comp.isDead = true;
          proj.life = 0;
          break;
        }
      }

      // Hit orb
      if (_withinRange(proj.position, orb.position, proj.radius + 25)) {
        _damageOrb(proj.damage);
        proj.life = 0;
      }
    }
    bossProjectiles.removeWhere((p) => p.life <= 0);
  }

  void _updateEnemyProjectiles(double dt, List<Projectile> interceptors) {
    for (final proj in enemyProjectiles) {
      proj.position = Offset(
        proj.position.dx + cos(proj.angle) * proj.speed * dt,
        proj.position.dy + sin(proj.angle) * proj.speed * dt,
      );
      proj.life -= dt;

      if (_consumeCompanionInterceptionAt(
        proj.position,
        proj.radius,
        interceptors,
      )) {
        proj.life = 0;
        continue;
      }

      if (proj.target == CosmicEnemyTarget.orb) {
        if (_withinRange(proj.position, orb.position, proj.radius + 24)) {
          // Phantom orb dodge chance
          if (_orbDodgeChance > 0 && _rng.nextDouble() < _orbDodgeChance) {
            proj.life = 0;
            continue;
          }
          _damageOrb(proj.damage);
          proj.life = 0;
        }
      }

      if (proj.life > 0 &&
          proj.target == CosmicEnemyTarget.ship &&
          !ship.isDead) {
        if (_withinRange(proj.position, ship.position, proj.radius + 12)) {
          ship.currentHp -= proj.damage;
          ship.hitFlash = 1.0;
          if (ship.currentHp <= 0) {
            ship.isDead = true;
            _shipRespawnTimer = 0;
          }
          proj.life = 0;
        }
      }

      if (proj.life > 0 && proj.target == CosmicEnemyTarget.companion) {
        for (final comp in activeCompanions.values) {
          if (comp.isDead) continue;
          if (_withinRange(proj.position, comp.position, proj.radius + 12)) {
            comp.takeDamage(proj.damage.round());
            comp.hitFlash = 1.0;
            if (comp.currentHp <= 0) comp.isDead = true;
            proj.life = 0;
            break;
          }
        }
      }
    }
    enemyProjectiles.removeWhere((p) => p.life <= 0);
  }

  // == Companion Projectiles (cosmic game style) ===========================

  void _updateCompanionProjectiles(double dt) {
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];
      var transferringToOrbit = false;

      // Homing — rescan target at most ~6× per second instead of every frame.
      if (p.homing) {
        p.homingRescanTimer -= dt;
        if (p.homingRescanTimer <= 0) {
          p.homingRescanTimer = 0.15;
          double bestDistSq = double.infinity;
          Offset? bestTarget;
          for (final e in enemies) {
            if (e.isDead) continue;
            final dSq = _distanceSquared(e.position, p.position);
            if (dSq < bestDistSq) {
              bestDistSq = dSq;
              bestTarget = e.position;
            }
          }
          if (activeBoss != null && !activeBoss!.isDead) {
            final bdSq = _distanceSquared(activeBoss!.position, p.position);
            if (bdSq < bestDistSq) bestTarget = activeBoss!.position;
          }
          p.cachedHomingTarget = bestTarget;
        }
        final cachedTarget = p.cachedHomingTarget;
        if (cachedTarget != null) {
          final desired = atan2(
            cachedTarget.dy - p.position.dy,
            cachedTarget.dx - p.position.dx,
          );
          double diff = desired - p.angle;
          while (diff > pi) {
            diff -= 2 * pi;
          }
          while (diff < -pi) {
            diff += 2 * pi;
          }
          final maxTurn = p.homingStrength * dt;
          p.angle += diff.clamp(-maxTurn, maxTurn);
        }
      }

      if (p.transferToShipOrbit && !p.followShipOrbit) {
        if (p.shipOrbitDelay > 0) {
          p.shipOrbitDelay = max(0.0, p.shipOrbitDelay - dt);
        } else {
          transferringToOrbit = true;
          p.orbitAngle += p.orbitSpeed * dt;
          final desiredPos = Offset(
            ship.position.dx + cos(p.orbitAngle) * p.orbitRadius,
            ship.position.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          final toDesired = desiredPos - p.position;
          final dist = toDesired.distance;
          final attachStep = Projectile.speed * p.shipOrbitTransferSpeed * dt;
          if (dist <= attachStep || dist < 8) {
            p.position = desiredPos;
            p.orbitCenter = ship.position;
            p.followShipOrbit = true;
            transferringToOrbit = false;
          } else {
            p.position += (toDesired / dist) * attachStep;
          }
        }
      } else if (p.transferOrbitCenter != null) {
        if (p.shipOrbitDelay > 0) {
          p.shipOrbitDelay = max(0.0, p.shipOrbitDelay - dt);
        } else {
          transferringToOrbit = true;
          p.orbitAngle += p.orbitSpeed * dt;
          final desiredCenter = p.transferOrbitCenter!;
          final desiredPos = Offset(
            desiredCenter.dx + cos(p.orbitAngle) * p.orbitRadius,
            desiredCenter.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          final toDesired = desiredPos - p.position;
          final dist = toDesired.distance;
          final attachStep = Projectile.speed * p.shipOrbitTransferSpeed * dt;
          if (dist <= attachStep || dist < 8) {
            p.position = desiredPos;
            p.orbitCenter = desiredCenter;
            p.transferOrbitCenter = null;
            transferringToOrbit = false;
          } else {
            p.position += (toDesired / dist) * attachStep;
          }
        }
      }

      // Orbital movement and orbit-held turrets.
      if (!transferringToOrbit &&
          p.orbitCenter != null &&
          (p.holdOrbit || p.orbitTime > 0)) {
        if (!p.holdOrbit) {
          p.orbitTime = max(0.0, p.orbitTime - dt);
        }
        p.orbitAngle += p.orbitSpeed * dt;
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        if (p.followShipOrbit) p.orbitCenter = ship.position;
        _maybeFireProjectileTurret(p, dt);
        if (!p.holdOrbit && p.orbitTime <= 0) {
          p.angle = atan2(
            p.position.dy - p.orbitCenter!.dy,
            p.position.dx - p.orbitCenter!.dx,
          );
          p.orbitCenter = null;
        }
      } else if (!p.stationary && !transferringToOrbit) {
        final spd = Projectile.speed * p.speedMultiplier;
        p.position = Offset(
          p.position.dx + cos(p.angle) * spd * dt,
          p.position.dy + sin(p.angle) * spd * dt,
        );
      } else {
        _maybeFireProjectileTurret(p, dt);
      }

      p.life -= dt;

      // Cluster split at half-life
      if (p.clusterCount > 0 &&
          !p.clustered &&
          p.life < Projectile.maxLife * 0.5) {
        p.clustered = true;
        for (var c = 0; c < p.clusterCount; c++) {
          final clusterAngle = p.angle + (c - p.clusterCount / 2) * 0.3;
          companionProjectiles.add(
            Projectile(
              position: p.position,
              angle: clusterAngle,
              element: p.element,
              damage: p.clusterDamage,
              life: 1.0,
              speedMultiplier: p.speedMultiplier * 0.8,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: p.visualScale * 0.6,
              visualStyle: p.visualStyle == ProjectileVisualStyle.letShard
                  ? ProjectileVisualStyle.letShard
                  : ProjectileVisualStyle.standard,
              sourceSlotIndex: p.sourceSlotIndex,
              chainLightningCharges: p.chainLightningCharges,
            ),
          );
        }
      }

      // Trail
      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          companionProjectiles.add(
            Projectile(
              position: p.position,
              angle: 0,
              element: p.element,
              damage: p.trailDamage,
              life: p.trailLife,
              stationary: true,
              radiusMultiplier: 1.5,
              piercing: true,
              visualScale: 1.2,
              sourceSlotIndex: p.sourceSlotIndex,
            ),
          );
        }
      }

      // Hit detection vs enemies
      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;
      for (final enemy in enemies) {
        if (enemy.isDead) continue;
        if (_withinRange(
          p.position,
          enemy.position,
          enemy.radius + hitRadius,
        )) {
          _damageEnemy(enemy, p.damage, sourceSlotIndex: p.sourceSlotIndex);
          _spawnProjectileHitSpark(p);
          _triggerChainLightning(
            sourceEnemy: enemy,
            origin: p.position,
            baseDamage: p.damage,
            sourceSlotIndex: p.sourceSlotIndex,
            remainingChains: p.chainLightningCharges,
          );

          // Ricochet (Pip)
          if (p.bounceCount > 0) {
            p.bounceCount--;
            final next = _nearestEnemyTo(enemy.position, 150, exclude: enemy);
            if (next != null) {
              p.angle = atan2(
                next.position.dy - p.position.dy,
                next.position.dx - p.position.dx,
              );
            }
          } else if (!p.piercing) {
            consumed = true;
          } else {
            p.pierceCount++;
          }
          break;
        }
      }

      // Hit detection vs boss
      if (!consumed &&
          activeBoss != null &&
          !activeBoss!.isDead &&
          !p.hitBoss) {
        final d = (activeBoss!.position - p.position).distance;
        if (d < activeBoss!.radius + hitRadius) {
          damageBoss(p.damage, attackElement: p.element);
          p.hitBoss = true;
          _spawnProjectileHitSpark(p);
          if (!p.piercing) consumed = true;
        }
      }

      if (consumed) p.life = 0;
    }

    companionProjectiles.removeWhere((p) => p.life <= 0);
  }

  void _maybeFireProjectileTurret(Projectile projectile, double dt) {
    if (projectile.turretInterval <= 0 || projectile.turretDamage <= 0) return;
    projectile.turretTimer += dt;
    while (projectile.turretTimer >= projectile.turretInterval) {
      projectile.turretTimer -= projectile.turretInterval;
      final target = _nearestEnemyTo(projectile.position, 360) ?? activeBoss;
      if (target == null || (target is SurvivalBoss && target.isDead)) continue;
      final targetPos = target is CosmicSurvivalEnemy
          ? target.position
          : (target as SurvivalBoss).position;
      companionProjectiles.add(
        _createCompanionTurretShot(projectile, targetPos),
      );
    }
  }

  void _trimProjectilePools() {
    if (companionProjectiles.length > _maxCompanionProjectiles) {
      companionProjectiles.removeRange(
        0,
        companionProjectiles.length - _maxCompanionProjectiles,
      );
    }
    if (enemyProjectiles.length > _maxEnemyProjectiles) {
      enemyProjectiles.removeRange(
        0,
        enemyProjectiles.length - _maxEnemyProjectiles,
      );
    }
    if (bossProjectiles.length > _maxBossProjectiles) {
      bossProjectiles.removeRange(
        0,
        bossProjectiles.length - _maxBossProjectiles,
      );
    }
  }

  Projectile _createCompanionTurretShot(Projectile orb, Offset targetPos) {
    final angle = atan2(
      targetPos.dy - orb.position.dy,
      targetPos.dx - orb.position.dx,
    );
    return Projectile(
      position: orb.position,
      angle: angle,
      element: orb.element,
      damage: orb.turretDamage,
      life: orb.element == 'Lightning' ? 1.15 : 1.7,
      speedMultiplier: orb.turretSpeedMultiplier,
      radiusMultiplier: switch (orb.element) {
        'Dust' => 0.92,
        'Lightning' => 1.0,
        'Water' => 1.45,
        'Crystal' => 1.35,
        'Steam' || 'Mud' || 'Ice' => 1.35,
        'Lava' || 'Earth' => 1.5,
        _ => 1.2,
      },
      visualScale: switch (orb.element) {
        'Dust' => 0.74,
        'Lightning' => 0.82,
        'Water' => 1.05,
        'Steam' || 'Mud' || 'Ice' => 1.05,
        'Lava' || 'Earth' => 1.15,
        _ => 0.96,
      },
      piercing: const {
        'Crystal',
        'Spirit',
        'Dark',
        'Blood',
      }.contains(orb.element),
      homing: orb.turretHomingStrength > 0,
      homingStrength: orb.turretHomingStrength,
      bounceCount: switch (orb.element) {
        'Crystal' => 1,
        'Lightning' => 2,
        _ => 0,
      },
      trailInterval: orb.element == 'Fire' ? 0.12 : 0,
      trailDamage: orb.element == 'Fire' ? orb.turretDamage * 0.2 : 0,
      trailLife: orb.element == 'Fire' ? 0.45 : 0,
    );
  }

  _ProjectileControlBuckets _buildProjectileControlBuckets() {
    final buckets = _ProjectileControlBuckets();
    for (final projectile in companionProjectiles) {
      if (projectile.snareRadius > 0) {
        buckets.snares.add(projectile);
      }
      if (projectile.tauntRadius > 0 ||
          (projectile.decoy && projectile.decoyHp > 0)) {
        buckets.lures.add(projectile);
      }
      if (projectile.decoy && projectile.decoyHp > 0) {
        buckets.decoys.add(projectile);
      }
      if (projectile.interceptCharges > 0 && projectile.interceptRadius > 0) {
        buckets.interceptors.add(projectile);
      }
    }
    return buckets;
  }

  bool _consumeCompanionInterceptionAt(
    Offset hostilePosition,
    double hostileRadius,
    List<Projectile> interceptors,
  ) {
    for (final projectile in interceptors) {
      if (projectile.interceptCharges <= 0 || projectile.interceptRadius <= 0) {
        continue;
      }
      final hitRadius = hostileRadius + projectile.interceptRadius;
      if (!_withinRange(projectile.position, hostilePosition, hitRadius)) {
        continue;
      }

      projectile.interceptCharges--;
      _spawnHitSpark(projectile.position, const Color(0xFFFFF3C8));
      _spawnHitSpark(hostilePosition, const Color(0xFFFFF3C8));
      if (projectile.interceptCharges <= 0) {
        companionProjectiles.remove(projectile);
      }
      return true;
    }
    return false;
  }

  // == Ship Projectiles ====================================================

  void _updateShipProjectiles(double dt) {
    for (final proj in shipProjectiles) {
      if (proj.isHoming && proj.target != null && !proj.target!.isDead) {
        final dir = proj.target!.position - proj.position;
        final dist = dir.distance;
        if (dist > 1) {
          final norm = Offset(dir.dx / dist, dir.dy / dist);
          final speed = proj.velocity.distance;
          proj.velocity = Offset(
            norm.dx * speed * 1.02,
            norm.dy * speed * 1.02,
          );
        }
      }

      proj.position = Offset(
        proj.position.dx + proj.velocity.dx * dt,
        proj.position.dy + proj.velocity.dy * dt,
      );
      proj.life -= dt;

      for (final enemy in enemies) {
        if (enemy.isDead) continue;
        if (_withinRange(proj.position, enemy.position, enemy.radius + 5)) {
          _damageEnemy(enemy, proj.damage);
          // Rocket splash AoE
          if (proj.splashRadius > 0) {
            for (final other in enemies) {
              if (other.isDead || identical(other, enemy)) continue;
              if (_withinRange(
                proj.position,
                other.position,
                proj.splashRadius,
              )) {
                _damageEnemy(other, proj.damage * 0.55);
              }
            }
            if (activeBoss != null && !activeBoss!.isDead) {
              if (_withinRange(
                proj.position,
                activeBoss!.position,
                proj.splashRadius,
              )) {
                damageBoss(proj.damage * 0.55);
              }
            }
          }
          proj.life = 0;
          break;
        }
      }

      if (proj.life > 0 && activeBoss != null && !activeBoss!.isDead) {
        if (_withinRange(
          proj.position,
          activeBoss!.position,
          activeBoss!.radius + 5,
        )) {
          damageBoss(proj.damage);
          // Rocket splash AoE on boss
          if (proj.splashRadius > 0) {
            for (final other in enemies) {
              if (other.isDead) continue;
              if (_withinRange(
                proj.position,
                other.position,
                proj.splashRadius,
              )) {
                _damageEnemy(other, proj.damage * 0.55);
              }
            }
          }
          proj.life = 0;
        }
      }
    }

    shipProjectiles.removeWhere((p) => p.life <= 0);
  }

  void _cleanupBetweenWaves() {
    enemies.removeWhere((enemy) => enemy.isDead);
    enemyProjectiles.clear();
    bossProjectiles.clear();
  }

  double _distanceSquared(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  bool _withinRange(Offset a, Offset b, double radius) {
    return _distanceSquared(a, b) < radius * radius;
  }

  bool _isWithinViewport(
    Offset position,
    double radius,
    double minX,
    double minY,
    double maxX,
    double maxY, {
    double margin = 0,
  }) {
    return position.dx + radius >= minX - margin &&
        position.dx - radius <= maxX + margin &&
        position.dy + radius >= minY - margin &&
        position.dy - radius <= maxY + margin;
  }

  Offset _clampToArena(Offset position, {double padding = 0}) {
    final center = orb.position;
    final maxRadius = max(80.0, _arenaRadius - padding);
    final delta = position - center;
    final distance = delta.distance;
    if (distance <= maxRadius || distance <= 0.001) {
      return position;
    }
    final norm = Offset(delta.dx / distance, delta.dy / distance);
    return center + norm * maxRadius;
  }

  // == Orb Defenses ========================================================

  void _updateOrbDefenses(double dt) {
    if (powerUps.shieldPulseLevel > 0) {
      orb.shieldPulseTimer += dt;
      final interval = 12.0 - powerUps.shieldPulseLevel * 2;
      if (orb.shieldPulseTimer >= interval) {
        orb.shieldPulseTimer = 0;
        for (final enemy in enemies) {
          if (enemy.isDead) continue;
          final d = (enemy.position - orb.position).distance;
          if (d < 200) {
            final dir = enemy.position - orb.position;
            final norm = d > 0 ? Offset(dir.dx / d, dir.dy / d) : Offset.zero;
            enemy.position = Offset(
              enemy.position.dx + norm.dx * 120,
              enemy.position.dy + norm.dy * 120,
            );
          }
        }
      }
    }

    if (powerUps.autoTurretLevel > 0) {
      orb.turretTimer += dt;
      final interval = 1.5 - powerUps.autoTurretLevel * 0.3;
      while (orb.turretTimer >= interval) {
        orb.turretTimer -= interval;
        final target = _pickOrbTurretTarget(360);
        if (target != null) {
          final beamColor = Color.lerp(orb.secondaryColor, Colors.white, 0.25)!;
          _spawnBeam(
            orb.position,
            target.position,
            beamColor,
            width: 2.4 + powerUps.autoTurretLevel * 0.4,
          );
          _spawnHitSpark(target.position, beamColor);
          _damageEnemy(target, _orbTurretDamage(powerUps.autoTurretLevel));
        }
      }
    }

    if (powerUps.regenFieldLevel > 0) {
      orb.regenTimer += dt;
      if (orb.regenTimer >= 1.0) {
        orb.regenTimer = 0;
        orb.currentHp = (orb.currentHp + 2.0 * powerUps.regenFieldLevel).clamp(
          0,
          orb.maxHp,
        );
      }
    }

    if (powerUps.novaDetonationLevel > 0) {
      orb.novaTimer += dt;
      final interval = 15.0 - powerUps.novaDetonationLevel * 2;
      if (orb.novaTimer >= interval) {
        orb.novaTimer = 0;
        for (final enemy in enemies) {
          if (enemy.isDead) continue;
          final d = (enemy.position - orb.position).distance;
          if (d < 250) {
            _damageEnemy(enemy, 20.0 * powerUps.novaDetonationLevel);
          }
        }
      }
    }
  }

  void _updateDetonation(double dt) {
    if (!detonationUnlocked || showingPowerUpSelection || isGameOver) {
      _detonationTimer = 0;
      if (detonationChargeNotifier.value != 0) {
        detonationChargeNotifier.value = 0;
      }
      if (detonationReadyNotifier.value) {
        detonationReadyNotifier.value = false;
      }
      return;
    }
    if (detonationReadyNotifier.value) {
      if (detonationChargeNotifier.value != 1) {
        detonationChargeNotifier.value = 1;
      }
      return;
    }
    _detonationTimer += dt;
    detonationChargeNotifier.value = (_detonationTimer / _detonationCooldown)
        .clamp(0.0, 1.0);
    if (_detonationTimer >= _detonationCooldown) {
      _detonationTimer = 0;
      detonationChargeNotifier.value = 1;
      detonationReadyNotifier.value = true;
    }
  }

  double get _detonationCooldown =>
      max(20.0, 42.0 - powerUps.novaDetonationLevel * 4.0);

  double get detonationChargeFraction => detonationChargeNotifier.value;

  void triggerDetonation() {
    if (!detonationUnlocked || !detonationReadyNotifier.value) return;
    detonationReadyNotifier.value = false;
    detonationChargeNotifier.value = 0;

    final level = powerUps.novaDetonationLevel;
    final blastRadius = 280.0 + level * 32.0;
    final baseBlastDamage = 52.0 + level * 26.0;
    final maxTargets = 4 + level * 3;
    final targets =
        enemies
            .where((enemy) => !enemy.isDead)
            .where(
              (enemy) =>
                  _withinRange(enemy.position, orb.position, blastRadius),
            )
            .toList()
          ..sort(
            (a, b) => _detonationPriorityScore(
              b,
              blastRadius,
            ).compareTo(_detonationPriorityScore(a, blastRadius)),
          );

    for (final enemy in targets.take(maxTargets)) {
      final d = (enemy.position - orb.position).distance;
      final blastDamage = enemy.isElite
          ? max(baseBlastDamage * 1.75, enemy.maxHp * 0.45)
          : max(baseBlastDamage, enemy.hp + 1);
      _damageEnemy(enemy, blastDamage);
      final dir = enemy.position - orb.position;
      final norm = d > 0 ? Offset(dir.dx / d, dir.dy / d) : Offset.zero;
      enemy.position = Offset(
        enemy.position.dx + norm.dx * (90 + level * 18),
        enemy.position.dy + norm.dy * (90 + level * 18),
      );
      enemy.hitFlash = 1.0;
      _spawnDetonationBurst(enemy.position, orb.glowColor, enemy.radius * 1.8);
      for (var i = 0; i < 3; i++) {
        _spawnHitSpark(enemy.position, orb.glowColor);
      }
    }
    _spawnDetonationBurst(orb.position, orb.glowColor, blastRadius * 0.34);
    for (var i = 0; i < 18; i++) {
      final angle = (i / 18) * pi * 2;
      _spawnHitSpark(
        orb.position + Offset(cos(angle) * 30, sin(angle) * 30),
        orb.glowColor,
      );
    }
  }

  double _detonationPriorityScore(
    CosmicSurvivalEnemy enemy,
    double blastRadius,
  ) {
    var score = 0.0;
    if (enemy.isElite) score += 220;
    if (enemy.target == CosmicEnemyTarget.orb) score += 180;
    if (enemy.role == CosmicEnemyRole.shooter) score += 140;
    if (enemy.role == CosmicEnemyRole.hunter) score += 90;
    score += (1 - enemy.hpFraction) * 60;
    score += max(0.0, blastRadius - (enemy.position - orb.position).distance);
    for (final other in enemies) {
      if (other.isDead || identical(other, enemy)) continue;
      if (_withinRange(enemy.position, other.position, 90)) score += 18;
    }
    return score;
  }

  void _spawnDetonationBurst(Offset center, Color color, double radius) {
    if (_vfx.length >= 150) return;
    final burstCount = max(10, (radius / 10).round()).clamp(10, 26);
    for (var i = 0; i < burstCount; i++) {
      final angle = (i / burstCount) * pi * 2;
      final speed = radius * (1.4 + _rng.nextDouble() * 0.6);
      _vfx.add(
        _VfxParticle(
          x: center.dx,
          y: center.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: 3.0 + _rng.nextDouble() * 3.2,
          life: 0.24 + _rng.nextDouble() * 0.22,
          color: color.withValues(alpha: 0.92),
        ),
      );
    }
  }

  // == VFX =================================================================

  void _spawnProjectileHitSpark(Projectile projectile) {
    final color = elementColor(projectile.element ?? 'Fire');
    if (projectile.visualStyle != ProjectileVisualStyle.mysticOrbital) {
      _spawnHitSpark(projectile.position, color);
      return;
    }

    if (_vfx.length >= 150) return;
    final count = _reduceAmbientVfx ? 1 : 2;
    for (var i = 0; i < count; i++) {
      final a = projectile.angle + pi + (_rng.nextDouble() - 0.5) * 1.2;
      final spd = 26 + _rng.nextDouble() * 42;
      _vfx.add(
        _VfxParticle(
          x: projectile.position.dx,
          y: projectile.position.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 1.0 + _rng.nextDouble() * 1.2,
          life: 0.16 + _rng.nextDouble() * 0.14,
          color: color.withValues(alpha: 0.72),
        ),
      );
    }
  }

  void _spawnHitSpark(Offset pos, Color color) {
    if (_vfx.length >= 150) return;
    for (var i = 0; i < 6; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 40 + _rng.nextDouble() * 80;
      _vfx.add(
        _VfxParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 1.5 + _rng.nextDouble() * 2,
          life: 0.3 + _rng.nextDouble() * 0.3,
          color: color,
        ),
      );
    }
  }

  void _spawnBeam(
    Offset start,
    Offset end,
    Color color, {
    double width = 2.4,
    double life = 0.10,
  }) {
    if (_beamFx.length >= 24) {
      _beamFx.removeAt(0);
    }
    _beamFx.add(
      _BeamFx(start: start, end: end, color: color, width: width, life: life),
    );
  }

  void _updateVfx(double dt) {
    for (final p in _vfx) {
      p.update(dt);
    }
    _vfx.removeWhere((p) => p.dead);
    for (final beam in _beamFx) {
      beam.update(dt);
    }
    _beamFx.removeWhere((beam) => beam.dead);
  }

  void _applyWaveStartEffectsIfNeeded() {
    if (spawner.currentWave <= 0 || _timeDilationWave == spawner.currentWave) {
      return;
    }
    _timeDilationWave = spawner.currentWave;
    applyTimeDilation();
  }

  void applyTimeDilation() {
    final level = powerUps.timeDilationLevel;
    if (level <= 0) return;
    const slowByLevel = [0.10, 0.18, 0.28];
    const durationByLevel = [5.0, 7.0, 9.0];
    final index = (level - 1).clamp(0, slowByLevel.length - 1);
    _timeDilationSlowFactor = 1.0 - slowByLevel[index];
    _timeDilationTimer = durationByLevel[index];
    for (final enemy in enemies) {
      enemy.slowTimer = _timeDilationTimer;
    }
  }

  void applyPowerUp(PowerUpDef def, {int? targetSlot, String? targetName}) {
    final applied = powerUps.apply(
      def,
      targetSlot: targetSlot,
      targetName: targetName,
    );
    if (!applied) return;
    if (def.id == 'orb_vitality') {
      final hpGain = orb.maxHp * 0.10;
      orb.maxHp += hpGain;
      orb.currentHp = min(orb.maxHp, orb.currentHp + hpGain + 4);
    }
    if (def.id == 'keystone_bastion_heart') {
      final orbGain = orb.maxHp * 0.20;
      orb.maxHp += orbGain;
      orb.currentHp = min(orb.maxHp, orb.currentHp + orbGain);
      for (final companion in activeCompanions.values) {
        final hpGain = max(1, (companion.maxHp * 0.14).round());
        companion.maxHp += hpGain;
        companion.currentHp = min(
          companion.maxHp,
          companion.currentHp + hpGain,
        );
      }
    }
    if (def.id == 'revive_half' && targetSlot != null) {
      defeatedCompanionSlots.remove(targetSlot);
      companionHpFraction[targetSlot] = 0.5;
    }
    alchemicalMeter = 0;
    showingPowerUpSelection = false;
    gamePaused = false;
    if (!detonationReadyNotifier.value && detonationChargeNotifier.value != 0) {
      detonationChargeNotifier.value = 0;
    }
    if (def.id == 'time_dilation') applyTimeDilation();
  }

  void dismissPowerUpSelection() {
    showingPowerUpSelection = false;
    gamePaused = false;
  }

  // == Helpers =============================================================

  CosmicSurvivalEnemy? _nearestEnemyTo(
    Offset pos,
    double maxRange, {
    CosmicSurvivalEnemy? exclude,
  }) {
    CosmicSurvivalEnemy? best;
    var bestDistSq = maxRange * maxRange;
    for (final enemy in enemies) {
      if (enemy.isDead || enemy == exclude) continue;
      final dSq = _distanceSquared(enemy.position, pos);
      if (dSq < bestDistSq) {
        bestDistSq = dSq;
        best = enemy;
      }
    }
    return best;
  }

  CosmicSurvivalEnemy? _pickOrbTurretTarget(double maxRange) {
    CosmicSurvivalEnemy? best;
    var bestScore = double.negativeInfinity;
    final maxRangeSq = maxRange * maxRange;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final distSq = _distanceSquared(enemy.position, orb.position);
      if (distSq > maxRangeSq) continue;
      final dist = sqrt(distSq);
      var score = 200.0 - dist;
      if (enemy.target == CosmicEnemyTarget.orb) score += 140;
      if (enemy.role == CosmicEnemyRole.shooter) score += 80;
      if (enemy.role == CosmicEnemyRole.hunter) score += 45;
      if (enemy.isElite) score += 110;
      score += (1.0 - enemy.hpFraction) * 55;
      if (score > bestScore) {
        bestScore = score;
        best = enemy;
      }
    }
    return best;
  }

  double _orbTurretDamage(int level) {
    final waveFactor = 6.0 + max(0, spawner.currentWave - 1) * 0.45;
    final levelFactor = 0.85 + level * 0.55;
    return waveFactor * levelFactor;
  }

  void _maybeTriggerPowerUpSelection() {
    if (showingPowerUpSelection || alchemicalMeter < alchemicalMeterMax) return;
    showingPowerUpSelection = true;
    gamePaused = true;
    onWaveIntermission?.call();
  }

  void _applyCompanionSpecialSupportEffects(
    CosmicSurvivalCompanion comp,
    CosmicSpecialResult result,
  ) {
    if (result.shieldHp > 0) {
      comp.shieldHp = max(comp.shieldHp, result.shieldHp);
      _grantOrbShield((result.shieldHp * 0.7).round());
    }
    if (result.selfHeal > 0) {
      comp.currentHp = min(comp.maxHp, comp.currentHp + result.selfHeal);
      _healOrb(result.selfHeal * 0.35);
    }
    if (result.shipHeal > 0) {
      ship.currentHp = min(ship.maxHp, ship.currentHp + result.shipHeal);
      _healOrb(result.shipHeal.toDouble());
    }
    if (result.blessingTimer > 0) {
      comp.blessingTimer = max(comp.blessingTimer, result.blessingTimer);
      comp.blessingHealPerTick = max(
        comp.blessingHealPerTick,
        result.blessingHealPerTick,
      );
    }
  }

  void _healOrb(double amount) {
    if (amount <= 0) return;
    orb.currentHp = min(orb.maxHp, orb.currentHp + amount);
  }

  void _grantOrbShield(int amount) {
    if (amount <= 0) return;
    final maxShield = max(60, (orb.maxHp * 0.45).round());
    orb.shieldHp = min(maxShield, orb.shieldHp + amount);
  }

  void _damageOrb(double amount) {
    if (amount <= 0) return;
    var remaining = amount;
    if (orb.shieldHp > 0) {
      final absorbed = min(remaining, orb.shieldHp.toDouble());
      orb.shieldHp -= absorbed.round();
      remaining -= absorbed;
    }
    if (remaining > 0) {
      orb.currentHp = max(0, orb.currentHp - remaining);
    }
  }

  void _triggerChainLightning({
    required CosmicSurvivalEnemy sourceEnemy,
    required Offset origin,
    required double baseDamage,
    required int remainingChains,
    int? sourceSlotIndex,
  }) {
    if (remainingChains <= 0 || sourceSlotIndex == null) return;
    if (!powerUps.companionHasChainLightning(sourceSlotIndex)) return;

    var current = sourceEnemy;
    for (var i = 0; i < remainingChains; i++) {
      final next = _nearestEnemyTo(current.position, 135, exclude: current);
      if (next == null) break;
      final bounceDamage = baseDamage * (0.55 - i * 0.10).clamp(0.25, 0.55);
      _spawnHitSpark(next.position, elementColor('Lightning'));
      _damageEnemy(next, bounceDamage, sourceSlotIndex: sourceSlotIndex);
      current = next;
    }
  }

  // == Orb Skin Passives ===================================================

  void _initOrbSkinPassives(OrbBaseSkin skin) {
    switch (skin) {
      case OrbBaseSkin.infernalOrb:
        _orbBurnAuraTimer = 0;
        break;
      case OrbBaseSkin.frozenNexusOrb:
        _orbSlowAuraRadius = 200;
        break;
      case OrbBaseSkin.verdantBloomOrb:
        _orbPassiveRegenRate = 1.0; // +1 HP/s
        break;
      case OrbBaseSkin.phantomWispOrb:
        _orbDodgeChance = 0.10; // 10% projectile dodge
        break;
      case OrbBaseSkin.celestialOrb:
        // Score multiplier handled in _killEnemy
        _celestialHealTimer = 0;
        break;
      case OrbBaseSkin.voidforgeOrb:
        // Damage boost handled inline in companion attack
        break;
      case OrbBaseSkin.prismHeartOrb:
        // Prism: small all-round bonuses (HP mult already in OrbBaseDef)
        _orbPassiveRegenRate = 0.3;
        break;
      default:
        break;
    }
  }

  void _updateOrbSkinPassives(double dt) {
    // Infernal: burn aura — damage nearby enemies every 0.5s
    if (_equippedSkin == OrbBaseSkin.infernalOrb) {
      _orbBurnAuraTimer += dt;
      if (_orbBurnAuraTimer >= 0.5) {
        _orbBurnAuraTimer = 0;
        final burnRadius = 160.0;
        final burnDmg = 2.0 + spawner.currentWave * 0.15;
        for (final e in enemies) {
          final d = (e.position - orb.position).distance;
          if (d < burnRadius) {
            _damageEnemy(e, burnDmg);
          }
        }
      }
    }

    // Frozen Nexus: slow enemies within aura
    if (_orbSlowAuraRadius > 0) {
      for (final e in enemies) {
        final d = (e.position - orb.position).distance;
        if (d < _orbSlowAuraRadius) {
          e.slowTimer = 0.3; // keep refreshing slow
        }
      }
    }

    // Verdant Bloom: passive HP regen for orb
    if (_orbPassiveRegenRate > 0) {
      orb.currentHp = (orb.currentHp + _orbPassiveRegenRate * dt).clamp(
        0,
        orb.maxHp,
      );
    }

    // Celestial Beacon: heal all companions & ship for 3% max HP every 8s
    if (_equippedSkin == OrbBaseSkin.celestialOrb) {
      _celestialHealTimer += dt;
      if (_celestialHealTimer >= 8.0) {
        _celestialHealTimer = 0;
        for (final comp in activeCompanions.values) {
          if (!comp.isDead) {
            comp.currentHp = min(
              comp.maxHp,
              comp.currentHp + (comp.maxHp * 0.03).round(),
            );
          }
        }
        if (!ship.isDead) {
          ship.currentHp = min(ship.maxHp, ship.currentHp + ship.maxHp * 0.03);
        }
      }
    }
  }

  // == Render ==============================================================

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    final cx = camX;
    final cy = camY;
    final viewW = size.x / _currentZoom;
    final viewH = size.y / _currentZoom;

    canvas.save();
    canvas.scale(_currentZoom, _currentZoom);
    canvas.translate(-cx, -cy);

    _renderStars(
      canvas,
      minX: cx,
      minY: cy,
      maxX: cx + viewW,
      maxY: cy + viewH,
    );
    _renderArenaBoundary(canvas);
    _renderOrbGravityField(canvas);
    _renderOrb(canvas);

    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      if (!_isWithinViewport(
        enemy.position,
        enemy.radius * 2.8,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 32,
      )) {
        continue;
      }
      _renderEnemy(canvas, enemy);
    }

    if (activeBoss != null && !activeBoss!.isDead) {
      _renderBoss(canvas, activeBoss!);
    }

    // Boss projectiles
    for (final proj in bossProjectiles) {
      if (proj.life <= 0) continue;
      if (!_isWithinViewport(
        proj.position,
        proj.radius * 2.2,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 24,
      )) {
        continue;
      }
      final bpColor = elementColor(proj.element);
      canvas.drawCircle(
        proj.position,
        proj.radius,
        Paint()..color = bpColor.withValues(alpha: 0.9),
      );
      if (!_reduceSecondaryGlows) {
        canvas.drawCircle(
          proj.position,
          proj.radius * 1.8,
          Paint()
            ..color = bpColor.withValues(alpha: 0.15)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, proj.radius),
        );
      }
    }

    for (final proj in enemyProjectiles) {
      if (proj.life <= 0) continue;
      if (!_isWithinViewport(
        proj.position,
        proj.radius * 2.2,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 24,
      )) {
        continue;
      }
      final color = elementColor(proj.element);
      canvas.drawCircle(
        proj.position,
        proj.radius,
        Paint()..color = color.withValues(alpha: 0.88),
      );
    }

    // Companion projectiles
    for (final proj in companionProjectiles) {
      if (proj.life <= 0) continue;
      if (!_isWithinViewport(
        proj.position,
        Projectile.radius * proj.radiusMultiplier * 2.6,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 28,
      )) {
        continue;
      }
      _renderCompanionProjectile(canvas, proj);
    }

    // Ship projectiles
    for (final proj in shipProjectiles) {
      if (proj.life <= 0) continue;
      if (!_isWithinViewport(
        proj.position,
        max(6.0, proj.splashRadius),
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 24,
      )) {
        continue;
      }
      canvas.drawCircle(
        proj.position,
        3,
        Paint()..color = const Color(0xFF00E5FF),
      );
      if (!_reduceSecondaryGlows) {
        canvas.drawCircle(
          proj.position,
          6,
          Paint()
            ..color = const Color(0xFF00E5FF).withValues(alpha: 0.2)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }

    for (final beam in _beamFx) {
      final mid = Offset(
        (beam.start.dx + beam.end.dx) * 0.5,
        (beam.start.dy + beam.end.dy) * 0.5,
      );
      final halfLength = (beam.end - beam.start).distance * 0.5;
      if (!_isWithinViewport(
        mid,
        halfLength + beam.width * 2,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 28,
      )) {
        continue;
      }
      final alpha = beam.alpha;
      canvas.drawLine(
        beam.start,
        beam.end,
        Paint()
          ..color = beam.color.withValues(alpha: 0.85 * alpha)
          ..strokeWidth = beam.width
          ..strokeCap = StrokeCap.round,
      );
      if (!_reduceSecondaryGlows) {
        canvas.drawLine(
          beam.start,
          beam.end,
          Paint()
            ..color = beam.color.withValues(alpha: 0.22 * alpha)
            ..strokeWidth = beam.width * 2.2
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // Companions
    for (final entry in activeCompanions.entries) {
      if (!entry.value.isDead) {
        if (!_isWithinViewport(
          entry.value.position,
          36,
          cx,
          cy,
          cx + viewW,
          cy + viewH,
          margin: 40,
        )) {
          continue;
        }
        _renderCompanion(canvas, entry.value, entry.key);
      }
    }

    // Ship / ghost ship
    _renderShip(canvas);

    // VFX particles
    for (var i = 0; i < _vfx.length; i++) {
      final p = _vfx[i];
      if (p.dead) continue;
      if (_reduceAmbientVfx && i.isOdd) continue;
      canvas.drawCircle(
        Offset(p.x, p.y),
        p.size * p.alpha,
        Paint()..color = p.color.withValues(alpha: p.alpha * 0.8),
      );
    }

    canvas.restore();
  }

  void _renderStars(
    Canvas canvas, {
    required double minX,
    required double minY,
    required double maxX,
    required double maxY,
  }) {
    final starPaint = Paint();
    const margin = 48.0;
    for (final star in _stars) {
      if (star.x < minX - margin ||
          star.x > maxX + margin ||
          star.y < minY - margin ||
          star.y > maxY + margin) {
        continue;
      }
      final twinkle =
          0.5 +
          0.5 * sin(stats.timeElapsed * star.twinkleSpeed + star.x * 0.01);
      starPaint.color = Colors.white.withValues(
        alpha: star.brightness * twinkle,
      );
      canvas.drawCircle(Offset(star.x, star.y), star.size, starPaint);
    }
  }

  void _renderOrb(Canvas canvas) {
    final p = orb.position;
    final elapsed = stats.timeElapsed;
    final alchemyFrac = (alchemicalMeter / alchemicalMeterMax).clamp(0.0, 1.0);
    final center = p;

    switch (orb.skin) {
      case OrbBaseSkin.frozenNexusOrb:
        _renderFrozenNexusOrb(canvas, center, elapsed);
      case OrbBaseSkin.phantomWispOrb:
        _renderPhantomWispOrb(canvas, center, elapsed);
      case OrbBaseSkin.prismHeartOrb:
        _renderPrismHeartOrb(canvas, center, elapsed);
      case OrbBaseSkin.verdantBloomOrb:
        _renderVerdantBloomOrb(canvas, center, elapsed);
      default:
        _renderDefaultOrb(canvas, center, elapsed);
    }

    _renderOrbAlchemyRing(canvas, center, alchemyFrac);

    if (orb.shieldHp > 0) {
      final shieldAlpha = (0.22 + min(orb.shieldHp / max(orb.maxHp, 1), 0.3))
          .clamp(0.18, 0.52);
      canvas.drawCircle(
        center,
        _orbShieldRadius,
        Paint()
          ..color = const Color(0xFF7FDBFF).withValues(alpha: shieldAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0,
      );
    }

    final hpFrac = orb.hpPercent;
    final hpColor = hpFrac > 0.5
        ? const Color(0xFF00E676)
        : hpFrac > 0.25
        ? const Color(0xFFFFEA00)
        : const Color(0xFFE53935);
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: _orbHpRingRadius),
      -pi / 2,
      2 * pi * hpFrac,
      false,
      Paint()
        ..color = hpColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _renderOrbGravityField(Canvas canvas) {
    final center = orb.position;
    final elapsed = stats.timeElapsed;
    final fieldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final radius = _orbShipOrbitRadius + i * 92.0;
      final alpha = max(0.035, 0.12 - i * 0.022);
      final rotation = elapsed * (0.18 + i * 0.035) + i * pi / 5;
      final sweep = pi * (0.28 + i * 0.035);
      fieldPaint
        ..color = orb.glowColor.withValues(alpha: alpha)
        ..strokeWidth = max(1.0, 2.4 - i * 0.28);

      for (var segment = 0; segment < 5; segment++) {
        final start = rotation + segment * (2 * pi / 5);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          start,
          sweep,
          false,
          fieldPaint,
        );
      }
    }

    final orbitPaint = Paint()
      ..color = orb.secondaryColor.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(center, _orbShipOrbitRadius, orbitPaint);
  }

  void _renderArenaBoundary(Canvas canvas) {
    final center = orb.position;
    final radius = _arenaRadius;
    final pulse = 0.75 + 0.25 * sin(stats.timeElapsed * 1.4);

    if (!_reduceSecondaryGlows) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF4FC3F7).withValues(alpha: 0.07 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 18
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF9BE7FF).withValues(alpha: 0.26 + 0.08 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );

    final markerPaint = Paint()
      ..color = const Color(0xFFE1F5FE).withValues(alpha: 0.62)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * pi + stats.timeElapsed * 0.05;
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - 12);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + 12);
      canvas.drawLine(inner, outer, markerPaint);
    }
  }

  void _renderDefaultOrb(Canvas canvas, Offset center, double elapsed) {
    _drawOrbLayeredGlow(
      canvas,
      center,
      orb.glowColor,
      radius: _orbGlowRadius,
      alpha: 0.28,
    );
    _renderOrbRuneRing(
      canvas,
      center,
      radius: _orbInnerRuneRadius,
      speed: 0.5,
      segments: 3,
      color: orb.primaryColor.withValues(alpha: 0.52),
    );
    _renderOrbRuneRing(
      canvas,
      center,
      radius: _orbOuterRuneRadius,
      speed: -0.3,
      segments: 5,
      color: orb.secondaryColor.withValues(alpha: 0.44),
    );
    canvas.drawCircle(
      center,
      _orbCoreRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          _orbCoreRadius * 1.1,
          [
            Colors.white.withValues(alpha: 0.92),
            orb.primaryColor.withValues(alpha: 0.88),
            orb.secondaryColor.withValues(alpha: 0.72),
          ],
          const [0.08, 0.45, 1.0],
        ),
    );
  }

  void _renderFrozenNexusOrb(Canvas canvas, Offset center, double elapsed) {
    _drawOrbLayeredGlow(
      canvas,
      center,
      orb.glowColor,
      radius: _orbGlowRadius * 1.08,
      alpha: 0.22,
    );
    for (var i = 0; i < 6; i++) {
      final angle = elapsed * 0.4 + (i * pi / 3);
      final dist = _orbInnerRuneRadius + sin(elapsed * 1.5 + i) * 8;
      final sx = center.dx + cos(angle) * dist;
      final sy = center.dy + sin(angle) * dist;
      final shard = Path()
        ..moveTo(sx, sy - 16)
        ..lineTo(sx + 8, sy + 3)
        ..lineTo(sx, sy + 16)
        ..lineTo(sx - 8, sy + 3)
        ..close();
      canvas.drawPath(
        shard,
        Paint()..color = const Color(0xFFB0EAFF).withValues(alpha: 0.75),
      );
    }
    canvas.drawCircle(
      center,
      _orbCoreRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          _orbCoreRadius * 1.1,
          [Colors.white, orb.primaryColor, orb.secondaryColor],
          const [0.0, 0.35, 1.0],
        ),
    );
  }

  void _renderPhantomWispOrb(Canvas canvas, Offset center, double elapsed) {
    final flicker = 0.5 + 0.3 * sin(elapsed * 3.0) + 0.2 * sin(elapsed * 7.1);
    _drawOrbLayeredGlow(
      canvas,
      center,
      orb.glowColor,
      radius: _orbGlowRadius * 1.18,
      alpha: 0.24 * flicker,
    );
    final drift1 = Offset(sin(elapsed * 2.0) * 10, cos(elapsed * 1.5) * 8);
    final drift2 = Offset(cos(elapsed * 2.5) * 8, sin(elapsed * 1.8) * 10);
    canvas.drawCircle(
      center + drift1,
      _orbCoreRadius * 0.94,
      Paint()
        ..shader = ui.Gradient.radial(
          center + drift1,
          _orbCoreRadius,
          [
            Colors.white.withValues(alpha: flicker * 0.8),
            orb.primaryColor.withValues(alpha: flicker * 0.6),
            orb.secondaryColor.withValues(alpha: flicker * 0.2),
          ],
          const [0.0, 0.4, 1.0],
        ),
    );
    canvas.drawCircle(
      center + drift2,
      _orbCoreRadius * 0.83,
      Paint()..color = orb.glowColor.withValues(alpha: flicker * 0.22),
    );
    _renderOrbRuneRing(
      canvas,
      center,
      radius: _orbOuterRuneRadius * 0.9,
      speed: 0.2,
      segments: 8,
      color: orb.glowColor.withValues(alpha: 0.24 * flicker),
      strokeWidth: 3.0,
    );
  }

  void _renderPrismHeartOrb(Canvas canvas, Offset center, double elapsed) {
    final hueShift = (elapsed * 30) % 360;
    final sweepColors = List.generate(
      7,
      (i) => HSVColor.fromAHSV(
        0.5,
        (hueShift + i * 51.4) % 360,
        0.9,
        1.0,
      ).toColor(),
    );
    final glowColors = sweepColors
        .map((color) => color.withValues(alpha: 0.22))
        .toList();
    canvas.drawCircle(
      center,
      _orbGlowRadius,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [...glowColors, glowColors.first],
          const [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 1.0],
          TileMode.clamp,
          0,
          2 * pi,
        ),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(elapsed * 0.3);
    final path = Path();
    const facets = 8;
    const facetRadius = _orbCoreRadius;
    for (var i = 0; i <= facets; i++) {
      final a = (i / facets) * 2 * pi;
      final r = i.isEven ? facetRadius : facetRadius * 0.75;
      final x = cos(a) * r;
      final y = sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.sweep(
          const Offset(0, 0),
          [...sweepColors, sweepColors.first],
          const [0.0, 0.14, 0.28, 0.42, 0.56, 0.70, 0.84, 1.0],
          TileMode.clamp,
          0,
          2 * pi,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    canvas.restore();
  }

  void _renderVerdantBloomOrb(Canvas canvas, Offset center, double elapsed) {
    _drawOrbLayeredGlow(
      canvas,
      center,
      orb.glowColor,
      radius: _orbGlowRadius * 1.12,
      alpha: 0.28 + 0.06 * sin(elapsed * 1.5),
    );
    for (var ring = 0; ring < 2; ring++) {
      final baseRadius = ring == 0
          ? _orbInnerRuneRadius * 0.92
          : _orbOuterRuneRadius * 0.94;
      final speed = ring == 0 ? 0.25 : -0.2;
      final vinePath = Path();
      const segments = 32;
      for (var i = 0; i <= segments; i++) {
        final a = (i / segments) * 2 * pi + elapsed * speed;
        final wobble = sin(a * 4 + elapsed * 2) * 7.2;
        final r = baseRadius + wobble;
        final x = center.dx + cos(a) * r;
        final y = center.dy + sin(a) * r;
        if (i == 0) {
          vinePath.moveTo(x, y);
        } else {
          vinePath.lineTo(x, y);
        }
      }
      canvas.drawPath(
        vinePath,
        Paint()
          ..color = const Color(0xFF228B22).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4,
      );
    }
    final coreRadius = _orbCoreRadius * (1.0 + 0.08 * sin(elapsed * 3.0));
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          coreRadius,
          [const Color(0xFFFFF8DC), orb.primaryColor, orb.secondaryColor],
          const [0.0, 0.4, 1.0],
        ),
    );
  }

  void _drawOrbLayeredGlow(
    Canvas canvas,
    Offset center,
    Color color, {
    required double radius,
    double alpha = 0.22,
    int layers = 5,
  }) {
    for (var i = layers; i >= 1; i--) {
      final t = i / layers;
      final layerAlpha = alpha * (layers - i + 1) / layers * 0.35;
      canvas.drawCircle(
        center,
        radius * t,
        Paint()..color = color.withValues(alpha: layerAlpha),
      );
    }
  }

  void _renderOrbRuneRing(
    Canvas canvas,
    Offset center, {
    required double radius,
    required double speed,
    required int segments,
    required Color color,
    double strokeWidth = 3.2,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(stats.timeElapsed * speed);
    final sweepAngle = (2 * pi / segments) - 0.2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < segments; i++) {
      final startAngle = i * (2 * pi / segments);
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
    canvas.restore();
  }

  void _renderOrbAlchemyRing(Canvas canvas, Offset center, double alchemyFrac) {
    final rect = Rect.fromCircle(center: center, radius: _orbAlchemyRingRadius);
    canvas.drawCircle(
      center,
      _orbAlchemyRingRadius,
      Paint()
        ..color = const Color(0xFF3A2E5A).withValues(alpha: 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    final gradient = ui.Gradient.sweep(
      center,
      const [
        Color(0xFF6C5CE7),
        Color(0xFF9B59B6),
        Color(0xFFE056FD),
        Color(0xFF00D2FF),
        Color(0xFF6C5CE7),
      ],
      const [0.0, 0.28, 0.56, 0.82, 1.0],
      TileMode.clamp,
      -pi / 2,
      3 * pi / 2,
    );
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * alchemyFrac,
      false,
      Paint()
        ..shader = gradient
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Enemy rendering: EXACT SAME visuals as cosmic game per tier.
  void _renderEnemy(Canvas canvas, CosmicSurvivalEnemy enemy) {
    final eColor = elementColor(enemy.element);
    final affixColor = switch (enemy.eliteAffix) {
      SurvivalEliteAffix.bulwarked => const Color(0xFF7DD3FC),
      SurvivalEliteAffix.volatile => const Color(0xFFFFA34A),
      SurvivalEliteAffix.vampiric => const Color(0xFFFB7185),
      SurvivalEliteAffix.overclocked => const Color(0xFFFDE047),
      SurvivalEliteAffix.relentless => const Color(0xFFA78BFA),
      null => eColor,
    };
    final flashColor = enemy.hitFlash > 0
        ? Color.lerp(eColor, Colors.white, enemy.hitFlash)!
        : eColor;
    final r = enemy.radius;
    final elapsed = stats.timeElapsed;

    canvas.save();
    canvas.translate(enemy.position.dx, enemy.position.dy);

    if (_simplifyEnemyRendering) {
      canvas.drawCircle(
        Offset.zero,
        r,
        Paint()..color = flashColor.withValues(alpha: 0.92),
      );
      if (enemy.isElite) {
        canvas.drawCircle(
          Offset.zero,
          r * 1.35,
          Paint()
            ..color = affixColor.withValues(alpha: 0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
      if ((enemy.tier == EnemyTier.brute || enemy.tier == EnemyTier.colossus) &&
          enemy.hpFraction < 1.0) {
        final barW = r * (enemy.tier == EnemyTier.colossus ? 3.0 : 2.4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(0, -r - 8), width: barW, height: 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.55),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-barW / 2, -r - 9.5, barW * enemy.hpFraction, 3),
            const Radius.circular(1.5),
          ),
          Paint()..color = Color.lerp(Colors.red, eColor, enemy.hpFraction)!,
        );
      }
      canvas.restore();
      return;
    }

    // Outer elemental aura (all tiers)
    canvas.drawCircle(
      Offset.zero,
      r * 2.0,
      Paint()
        ..color = eColor.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.2),
    );

    if (enemy.isElite && enemy.eliteAffix != null) {
      canvas.drawCircle(
        Offset.zero,
        r * 2.3,
        Paint()
          ..color = affixColor.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    switch (enemy.tier) {
      case EnemyTier.wisp:
        final flicker = 0.7 + 0.3 * sin(elapsed * 6 + enemy.angle * 5);
        final wobble = r * flicker;
        canvas.drawCircle(
          Offset.zero,
          wobble,
          Paint()
            ..shader = ui.Gradient.radial(
              const Offset(-1, -1),
              wobble,
              [
                Colors.white.withValues(alpha: 0.7 * flicker),
                flashColor.withValues(alpha: 0.5 * flicker),
                flashColor.withValues(alpha: 0.0),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 0.15,
          Paint()
            ..color = Colors.red.withValues(alpha: 0.9 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
        );

      case EnemyTier.sentinel:
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.25, -r * 0.25),
              r * 1.2,
              [
                Color.lerp(
                  flashColor,
                  Colors.white,
                  0.35,
                )!.withValues(alpha: 0.9),
                flashColor.withValues(alpha: 0.8),
                Color.lerp(
                  flashColor,
                  Colors.black,
                  0.5,
                )!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawCircle(
          Offset(-r * 0.2, -r * 0.25),
          r * 0.3,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        canvas.save();
        canvas.rotate(elapsed * 0.3 + enemy.angle);
        final ringR = r * 1.8;
        canvas.drawCircle(
          Offset.zero,
          ringR,
          Paint()
            ..color = eColor.withValues(alpha: 0.12)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        for (var i = 0; i < 3; i++) {
          final orbitAngle = elapsed * (1.2 + i * 0.4) + i * pi * 2 / 3;
          final ox = cos(orbitAngle) * ringR;
          final oy = sin(orbitAngle) * ringR;
          final satR = r * (0.18 + i * 0.04);
          canvas.drawCircle(
            Offset(ox, oy),
            satR * 2,
            Paint()
              ..color = eColor.withValues(alpha: 0.2)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, satR),
          );
          canvas.drawCircle(
            Offset(ox, oy),
            satR,
            Paint()
              ..shader = ui.Gradient.radial(
                Offset(ox - satR * 0.3, oy - satR * 0.3),
                satR,
                [
                  Colors.white.withValues(alpha: 0.7),
                  eColor.withValues(alpha: 0.8),
                ],
              ),
          );
        }
        canvas.restore();
        canvas.drawCircle(
          Offset.zero,
          r * 0.25,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

      case EnemyTier.drone:
        final twitch = sin(elapsed * 12 + enemy.angle * 7) * r * 0.08;
        final hexPath = Path();
        for (var i = 0; i < 6; i++) {
          final a = i * pi / 3 - pi / 6;
          final hr = r * (1.0 + (i.isEven ? twitch / r : -twitch / r));
          final hx = cos(a) * hr;
          final hy = sin(a) * hr;
          if (i == 0) {
            hexPath.moveTo(hx, hy);
          } else {
            hexPath.lineTo(hx, hy);
          }
        }
        hexPath.close();
        canvas.drawPath(
          hexPath,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(0, -r),
              Offset(0, r),
              [
                Color.lerp(
                  flashColor,
                  Colors.white,
                  0.4,
                )!.withValues(alpha: 0.9),
                flashColor.withValues(alpha: 0.85),
                Color.lerp(
                  flashColor,
                  Colors.black,
                  0.3,
                )!.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        canvas.drawPath(
          hexPath,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        final eyePulse = 0.6 + 0.4 * sin(elapsed * 8 + enemy.angle * 3);
        canvas.drawCircle(
          Offset.zero,
          r * 0.2,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.9 * eyePulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
        for (var s = 0; s < 2; s++) {
          final sparkAngle = enemy.angle + pi + (s - 0.5) * 0.4;
          final sparkDist = r * (1.2 + 0.3 * sin(elapsed * 10 + s * 3));
          canvas.drawCircle(
            Offset(cos(sparkAngle) * sparkDist, sin(sparkAngle) * sparkDist),
            r * 0.12,
            Paint()
              ..color = eColor.withValues(alpha: 0.5 * eyePulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }

      case EnemyTier.phantom:
        final ghostPhase = elapsed * 1.5 + enemy.angle * 2;
        final breathe = 1.0 + 0.12 * sin(ghostPhase);
        canvas.drawCircle(
          Offset.zero,
          r * 1.6 * breathe,
          Paint()
            ..color = eColor.withValues(alpha: 0.06 + 0.03 * sin(ghostPhase))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
        );
        canvas.save();
        canvas.scale(0.8, 1.1 * breathe);
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.15, -r * 0.2),
              r * 1.2,
              [
                Colors.white.withValues(alpha: 0.25),
                eColor.withValues(alpha: 0.18),
                eColor.withValues(alpha: 0.04),
              ],
              [0.0, 0.4, 1.0],
            ),
        );
        canvas.restore();
        for (var t = 0; t < 4; t++) {
          final tAngle = t * pi / 2 + ghostPhase * 0.3;
          final tLen = r * (1.5 + 0.4 * sin(ghostPhase + t * 1.5));
          final tendril = Path()
            ..moveTo(cos(tAngle) * r * 0.4, sin(tAngle) * r * 0.4);
          final ctrlX = cos(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          final ctrlY = sin(tAngle + 0.3 * sin(ghostPhase + t)) * r * 1.0;
          tendril.quadraticBezierTo(
            ctrlX,
            ctrlY,
            cos(tAngle) * tLen,
            sin(tAngle) * tLen,
          );
          canvas.drawPath(
            tendril,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.15 + 0.08 * sin(ghostPhase + t * 2),
              )
              ..strokeWidth = 1.5
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        final eyeSpread = r * 0.25;
        final eyeY = -r * 0.15;
        for (final ex in [-eyeSpread, eyeSpread]) {
          canvas.drawCircle(
            Offset(ex, eyeY),
            r * 0.1,
            Paint()
              ..color = Colors.white.withValues(
                alpha: 0.4 + 0.2 * sin(ghostPhase * 2),
              )
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
          );
        }

      case EnemyTier.brute:
        canvas.drawCircle(
          Offset.zero,
          r,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.2, -r * 0.2),
              r * 1.3,
              [
                Color.lerp(
                  flashColor,
                  Colors.black,
                  0.3,
                )!.withValues(alpha: 0.9),
                Color.lerp(
                  flashColor,
                  Colors.black,
                  0.6,
                )!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.5, 1.0],
            ),
        );
        for (var crack = 0; crack < 5; crack++) {
          final ca = crack * pi * 2 / 5 + elapsed * 0.2;
          final crackPath = Path()
            ..moveTo(0, 0)
            ..lineTo(cos(ca) * r * 0.9, sin(ca) * r * 0.9);
          canvas.drawPath(
            crackPath,
            Paint()
              ..color = eColor.withValues(
                alpha: 0.6 + 0.2 * sin(elapsed * 2 + crack),
              )
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
        canvas.drawCircle(
          Offset.zero,
          r * 1.3,
          Paint()
            ..color = eColor.withValues(alpha: 0.08)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.5),
        );
        final bruteHpFrac = enemy.hpFraction;
        if (bruteHpFrac < 1.0) {
          final barW = r * 2.5;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 8),
                width: barW,
                height: 3,
              ),
              const Radius.circular(1.5),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-barW / 2, -r - 8 - 1.5, barW * bruteHpFrac, 3),
              const Radius.circular(1.5),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, bruteHpFrac)!,
          );
        }

      case EnemyTier.colossus:
        final pulse = 0.95 + 0.05 * sin(elapsed * 1.2 + enemy.angle);
        canvas.drawCircle(
          Offset.zero,
          r * pulse,
          Paint()
            ..shader = ui.Gradient.radial(
              Offset(-r * 0.3, -r * 0.3),
              r * 1.5,
              [
                Color.lerp(
                  flashColor,
                  Colors.white,
                  0.15,
                )!.withValues(alpha: 0.85),
                Color.lerp(
                  flashColor,
                  Colors.black,
                  0.3,
                )!.withValues(alpha: 0.8),
                Colors.black.withValues(alpha: 0.7),
              ],
              [0.0, 0.4, 1.0],
            ),
        );
        for (var t = 0; t < 6; t++) {
          final baseAngle = t * pi / 3 + elapsed * 0.08;
          final wave = sin(elapsed * 1.5 + t * 1.2) * 0.3;
          final tentacle = Path()
            ..moveTo(cos(baseAngle) * r * 0.8, sin(baseAngle) * r * 0.8);
          final midDist = r * 1.6;
          final tipDist = r * (2.2 + 0.3 * sin(elapsed * 0.8 + t));
          final ctrlAngle = baseAngle + wave;
          tentacle.quadraticBezierTo(
            cos(ctrlAngle) * midDist,
            sin(ctrlAngle) * midDist,
            cos(baseAngle + wave * 0.5) * tipDist,
            sin(baseAngle + wave * 0.5) * tipDist,
          );
          canvas.drawPath(
            tentacle,
            Paint()
              ..color = eColor.withValues(alpha: 0.35 + 0.15 * sin(elapsed + t))
              ..strokeWidth = 2.5 - t * 0.2
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
        }
        canvas.drawCircle(
          Offset.zero,
          r * 0.35,
          Paint()
            ..color = eColor.withValues(alpha: 0.4 + 0.2 * sin(elapsed * 2))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 0.15,
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
        canvas.drawCircle(
          Offset.zero,
          r * 1.5,
          Paint()
            ..color = eColor.withValues(alpha: 0.05)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.6),
        );
        final colHpFrac = enemy.hpFraction;
        if (colHpFrac < 1.0) {
          final barW = r * 3.0;
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(0, -r - 10),
                width: barW,
                height: 4,
              ),
              const Radius.circular(2),
            ),
            Paint()..color = Colors.black.withValues(alpha: 0.6),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-barW / 2, -r - 10 - 2, barW * colHpFrac, 4),
              const Radius.circular(2),
            ),
            Paint()..color = Color.lerp(Colors.red, eColor, colHpFrac)!,
          );
        }
    }

    if (!_reduceMinorLabels && enemy.isElite && enemy.eliteAffix != null) {
      final label = switch (enemy.eliteAffix!) {
        SurvivalEliteAffix.bulwarked => 'BULWARK',
        SurvivalEliteAffix.volatile => 'VOLATILE',
        SurvivalEliteAffix.vampiric => 'VAMPIRIC',
        SurvivalEliteAffix.overclocked => 'OVERCLOCK',
        SurvivalEliteAffix.relentless => 'RELENTLESS',
      };
      final tp = _getEliteAffixPainter(label, affixColor);
      tp.paint(canvas, Offset(-tp.width / 2, -r - 18));
    }

    canvas.restore();
  }

  /// Boss rendering — orbiting motes, core gradient, health bar
  void _renderBoss(Canvas canvas, SurvivalBoss boss) {
    final bColor = boss.color;
    final r = boss.radius;
    final elapsed = stats.timeElapsed;
    final pulse = 0.8 + 0.2 * sin(elapsed * 2.5);
    final spawnTarget = boss.spawnTargetPosition;
    if (boss.isSpawning && spawnTarget != null) {
      final introT = 1.0 - (boss.spawnIntroTimer / boss.spawnIntroDuration);
      final portalPulse = 0.7 + 0.3 * sin(elapsed * 8.0);
      final portalRadius = r * (1.7 + 0.25 * portalPulse);
      canvas.drawCircle(
        spawnTarget,
        portalRadius,
        Paint()
          ..color = bColor.withValues(alpha: 0.14 + 0.08 * (1.0 - introT))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(
        spawnTarget,
        r * (1.05 + 0.12 * portalPulse),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.18 + 0.10 * portalPulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
      for (var i = 0; i < 6; i++) {
        final a = elapsed * 1.7 + i * pi / 3;
        final inner = spawnTarget + Offset(cos(a), sin(a)) * (r * 0.8);
        final outer = spawnTarget + Offset(cos(a), sin(a)) * (r * 1.45);
        canvas.drawLine(
          inner,
          outer,
          Paint()
            ..color = bColor.withValues(alpha: 0.32)
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
      }
      switch (boss.discipline) {
        case SurvivalBossDiscipline.conductor:
          canvas.drawCircle(
            spawnTarget,
            portalRadius * 1.22,
            Paint()
              ..color = bColor.withValues(alpha: 0.2)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.2,
          );
          for (var i = 0; i < 8; i++) {
            final a = elapsed * 0.8 + i * pi / 4;
            final node =
                spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 1.1);
            canvas.drawCircle(
              node,
              r * 0.1,
              Paint()..color = Colors.white.withValues(alpha: 0.45),
            );
          }
        case SurvivalBossDiscipline.duelist:
          for (final offset in const [-0.22, 0.22]) {
            final a = elapsed * 1.4 + offset;
            final inner =
                spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 0.35);
            final outer =
                spawnTarget +
                Offset(cos(a + 0.04), sin(a + 0.04)) * (portalRadius * 1.3);
            canvas.drawLine(
              inner,
              outer,
              Paint()
                ..color = Colors.white.withValues(alpha: 0.58)
                ..strokeWidth = 3
                ..strokeCap = StrokeCap.round,
            );
          }
        case SurvivalBossDiscipline.artillery:
          for (var i = 0; i < 3; i++) {
            final arcRadius = portalRadius * (0.7 + i * 0.22);
            canvas.drawArc(
              Rect.fromCircle(center: spawnTarget, radius: arcRadius),
              -pi / 2 + i * 0.38 + elapsed * 0.18,
              pi * 0.9,
              false,
              Paint()
                ..color = bColor.withValues(alpha: 0.34 - i * 0.08)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2.0,
            );
          }
        case SurvivalBossDiscipline.trickster:
          for (var i = 0; i < 3; i++) {
            final phase = elapsed * 2.6 + i * 2.1;
            final echo =
                spawnTarget +
                Offset(cos(phase), sin(phase * 1.2)) * (portalRadius * 0.32);
            canvas.drawCircle(
              echo,
              r * (0.24 - i * 0.03),
              Paint()
                ..color = bColor.withValues(alpha: 0.22 - i * 0.05)
                ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
            );
          }
        case SurvivalBossDiscipline.standard:
          switch (boss.type) {
            case BossType.charger:
            case BossType.skirmisher:
              final a = elapsed * 1.7;
              final inner =
                  spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 0.25);
              final outer =
                  spawnTarget + Offset(cos(a), sin(a)) * (portalRadius * 1.28);
              canvas.drawLine(
                inner,
                outer,
                Paint()
                  ..color = Colors.white.withValues(alpha: 0.5)
                  ..strokeWidth = 3
                  ..strokeCap = StrokeCap.round,
              );
            case BossType.gunner:
            case BossType.carrier:
              canvas.drawArc(
                Rect.fromCircle(
                  center: spawnTarget,
                  radius: portalRadius * 1.08,
                ),
                -pi / 2 + elapsed * 0.15,
                pi * 1.2,
                false,
                Paint()
                  ..color = bColor.withValues(alpha: 0.28)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.2,
              );
            case BossType.bulwark:
            case BossType.warden:
              canvas.drawCircle(
                spawnTarget,
                portalRadius * 0.78,
                Paint()
                  ..color = bColor.withValues(alpha: 0.18)
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 2.6,
              );
          }
      }
    }

    canvas.save();
    canvas.translate(boss.position.dx, boss.position.dy);

    final auraColor = boss.enraged
        ? Colors.red.withValues(alpha: 0.15 * pulse)
        : bColor.withValues(alpha: 0.12 * pulse);
    if (!_reduceSecondaryGlows) {
      canvas.drawCircle(
        Offset.zero,
        r * 2.5,
        Paint()
          ..color = auraColor
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.8),
      );
    }

    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.3, -r * 0.3),
          r * 1.5,
          [
            Color.lerp(bColor, Colors.white, 0.2)!.withValues(alpha: 0.85),
            bColor.withValues(alpha: 0.8),
            Color.lerp(bColor, Colors.black, 0.5)!.withValues(alpha: 0.7),
          ],
          [0.0, 0.4, 1.0],
        ),
    );

    if (boss.shieldUp) {
      canvas.drawCircle(
        Offset.zero,
        r * 1.3,
        Paint()
          ..color = Colors.cyan.withValues(alpha: 0.2 + 0.1 * sin(elapsed * 3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    for (var i = 0; i < 6; i++) {
      final orbitAngle = elapsed * 0.8 + i * pi / 3;
      final orbitR = r * 1.4;
      final mx = cos(orbitAngle) * orbitR;
      final my = sin(orbitAngle) * orbitR;
      canvas.drawCircle(
        Offset(mx, my),
        3,
        Paint()
          ..color = bColor.withValues(alpha: 0.6 + 0.2 * sin(elapsed * 2 + i)),
      );
    }

    canvas.drawCircle(
      Offset.zero,
      r * 0.3,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );

    final hpFrac = boss.hpFraction;
    final barW = r * 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, -r - 14), width: barW, height: 5),
        const Radius.circular(2.5),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-barW / 2, -r - 14 - 2.5, barW * hpFrac, 5),
        const Radius.circular(2.5),
      ),
      Paint()
        ..color = boss.enraged
            ? Color.lerp(
                Colors.red,
                Colors.orange,
                sin(elapsed * 4) * 0.5 + 0.5,
              )!
            : Color.lerp(Colors.red, bColor, hpFrac)!,
    );

    final nameTP = _getBossNamePainter(boss.template.name, bColor);
    nameTP.paint(canvas, Offset(-nameTP.width / 2, -r - 24));

    canvas.restore();
  }

  void _renderCompanionProjectile(Canvas canvas, Projectile proj) {
    final eColor = elementColor(proj.element ?? 'Fire');

    if (proj.visualStyle == ProjectileVisualStyle.mysticOrbital) {
      final dir = Offset(cos(proj.angle), sin(proj.angle));
      final radius = (1.65 * proj.visualScale).clamp(1.4, 4.4).toDouble();
      final core = Paint()..color = eColor.withValues(alpha: 0.76);
      canvas.drawCircle(proj.position, radius, core);
      if (!_simplifyProjectileRendering) {
        canvas.drawLine(
          proj.position - dir * radius * 2.2,
          proj.position,
          Paint()
            ..color = eColor.withValues(alpha: 0.24)
            ..strokeWidth = max(1.0, radius * 0.72)
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(
          proj.position,
          radius * 2.2,
          Paint()
            ..color = eColor.withValues(alpha: 0.16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
      return;
    }

    if (_simplifyProjectileRendering) {
      final radius = switch (proj.visualStyle) {
        ProjectileVisualStyle.meteor => 3.6 * proj.visualScale,
        ProjectileVisualStyle.hornImpact => 3.4 * proj.visualScale,
        ProjectileVisualStyle.kinOrbital => 3.2 * proj.visualScale,
        ProjectileVisualStyle.slash => 2.4 * proj.visualScale,
        _ => 2.8 * proj.visualScale,
      };
      if (proj.visualStyle == ProjectileVisualStyle.slash) {
        final len = 6.0 * proj.visualScale;
        canvas.drawLine(
          Offset(
            proj.position.dx - cos(proj.angle) * len,
            proj.position.dy - sin(proj.angle) * len,
          ),
          Offset(
            proj.position.dx + cos(proj.angle) * len,
            proj.position.dy + sin(proj.angle) * len,
          ),
          Paint()
            ..color = eColor.withValues(alpha: 0.9)
            ..strokeWidth = 2.0
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(
          proj.position,
          radius,
          Paint()..color = eColor.withValues(alpha: 0.88),
        );
      }
      if (proj.decoy) {
        canvas.drawCircle(
          proj.position,
          10 * proj.visualScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      return;
    }

    if (drawLetElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }
    if (drawPipElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }
    if (drawManeElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }
    if (drawHornElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }

    switch (proj.visualStyle) {
      case ProjectileVisualStyle.meteor:
        final tailLen = 22.0 * proj.visualScale;
        final tailStart = Offset(
          proj.position.dx - cos(proj.angle) * tailLen,
          proj.position.dy - sin(proj.angle) * tailLen,
        );
        canvas.drawLine(
          tailStart,
          proj.position,
          Paint()
            ..shader = ui.Gradient.linear(
              tailStart,
              proj.position,
              [
                eColor.withValues(alpha: 0.02),
                eColor.withValues(alpha: 0.35),
                Color.lerp(eColor, Colors.white, 0.35)!,
              ],
              const [0.0, 0.6, 1.0],
            )
            ..strokeWidth = 7.5 * proj.visualScale
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        canvas.drawCircle(
          proj.position,
          6.0 * proj.visualScale,
          Paint()..color = eColor.withValues(alpha: 0.92),
        );
        canvas.drawCircle(
          Offset(
            proj.position.dx - cos(proj.angle) * (2.5 * proj.visualScale),
            proj.position.dy - sin(proj.angle) * (2.5 * proj.visualScale),
          ),
          3.2 * proj.visualScale,
          Paint()..color = Color.lerp(eColor, const Color(0xFF2B1A12), 0.55)!,
        );
        canvas.drawCircle(
          Offset(
            proj.position.dx + cos(proj.angle + 0.6) * (1.8 * proj.visualScale),
            proj.position.dy + sin(proj.angle + 0.6) * (1.8 * proj.visualScale),
          ),
          1.7 * proj.visualScale,
          Paint()..color = const Color(0xFFFFF2D6).withValues(alpha: 0.85),
        );

      case ProjectileVisualStyle.slash:
        final len = 8.0 * proj.visualScale;
        canvas.drawLine(
          Offset(
            proj.position.dx - cos(proj.angle) * len,
            proj.position.dy - sin(proj.angle) * len,
          ),
          Offset(
            proj.position.dx + cos(proj.angle) * len,
            proj.position.dy + sin(proj.angle) * len,
          ),
          Paint()
            ..color = eColor.withValues(alpha: 0.9)
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );

      case ProjectileVisualStyle.dart:
        canvas.drawCircle(
          proj.position,
          2 * proj.visualScale,
          Paint()..color = eColor.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          proj.position,
          4 * proj.visualScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );

      case ProjectileVisualStyle.sigil:
      case ProjectileVisualStyle.hornImpact:
        final pulse = 0.7 + 0.3 * sin(stats.timeElapsed * 4);
        canvas.drawCircle(
          proj.position,
          4 * proj.visualScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.4 * pulse)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              4 * proj.visualScale,
            ),
        );
        canvas.drawCircle(
          proj.position,
          2 * proj.visualScale,
          Paint()..color = Colors.white.withValues(alpha: 0.6 * pulse),
        );

      case ProjectileVisualStyle.kinOrbital:
      case ProjectileVisualStyle.mysticOrbital:
        canvas.drawCircle(
          proj.position,
          3 * proj.visualScale,
          Paint()..color = eColor.withValues(alpha: 0.6),
        );
        canvas.drawCircle(
          proj.position,
          6 * proj.visualScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.12)
            ..maskFilter = MaskFilter.blur(
              BlurStyle.normal,
              4 * proj.visualScale,
            ),
        );

      case ProjectileVisualStyle.letShard:
        final dir = Offset(cos(proj.angle), sin(proj.angle));
        final perp = Offset(-dir.dy, dir.dx);
        final tailLen = 30.0 * proj.visualScale;
        final tail = proj.position - dir * tailLen;

        canvas.drawLine(
          tail,
          proj.position,
          Paint()
            ..shader = ui.Gradient.linear(
              tail,
              proj.position,
              [
                eColor.withValues(alpha: 0.0),
                eColor.withValues(alpha: 0.16),
                Color.lerp(eColor, Colors.white, 0.18)!,
              ],
              const [0.0, 0.58, 1.0],
            )
            ..strokeWidth = 5.4 * proj.visualScale
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );

        final shard = Path()
          ..moveTo(
            proj.position.dx + dir.dx * (8.5 * proj.visualScale),
            proj.position.dy + dir.dy * (8.5 * proj.visualScale),
          )
          ..lineTo(
            proj.position.dx + perp.dx * (4.2 * proj.visualScale),
            proj.position.dy + perp.dy * (4.2 * proj.visualScale),
          )
          ..lineTo(
            proj.position.dx - dir.dx * (6.0 * proj.visualScale),
            proj.position.dy - dir.dy * (6.0 * proj.visualScale),
          )
          ..lineTo(
            proj.position.dx - perp.dx * (4.2 * proj.visualScale),
            proj.position.dy - perp.dy * (4.2 * proj.visualScale),
          )
          ..close();

        canvas.drawPath(
          shard,
          Paint()
            ..shader = ui.Gradient.linear(
              tail,
              proj.position + dir * (10.0 * proj.visualScale),
              [
                Color.lerp(eColor, const Color(0xFF1A1014), 0.42)!,
                eColor,
                Color.lerp(eColor, Colors.white, 0.55)!,
              ],
              const [0.0, 0.62, 1.0],
            ),
        );

        canvas.drawPath(
          shard,
          Paint()
            ..color = Color.lerp(
              eColor,
              Colors.white,
              0.42,
            )!.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.1 * proj.visualScale,
        );

        canvas.drawCircle(
          proj.position - dir * (1.2 * proj.visualScale),
          2.4 * proj.visualScale,
          Paint()..color = const Color(0xFFFFF4DC).withValues(alpha: 0.85),
        );

      case ProjectileVisualStyle.standard:
        canvas.drawCircle(
          proj.position,
          3 * proj.visualScale,
          Paint()..color = eColor.withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          proj.position,
          5 * proj.visualScale,
          Paint()
            ..color = eColor.withValues(alpha: 0.15)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
    }

    if (proj.decoy) {
      canvas.drawCircle(
        proj.position,
        12 * proj.visualScale,
        Paint()
          ..color = eColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _renderCompanion(
    Canvas canvas,
    CosmicSurvivalCompanion comp,
    int slotIndex,
  ) {
    final ec = elementColor(comp.member.element);
    final ticker = _companionTickers[slotIndex];
    final visuals = _companionVisuals[slotIndex];
    final spriteScale = _companionSpriteScales[slotIndex] ?? 1.0;

    canvas.save();
    canvas.translate(comp.position.dx, comp.position.dy);

    // Elemental aura glow
    canvas.drawCircle(
      Offset.zero,
      24,
      Paint()
        ..color = ec.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Shield bubble
    if (comp.shieldHp > 0) {
      canvas.drawCircle(
        Offset.zero,
        22,
        Paint()
          ..color = Colors.cyan.withValues(
            alpha: 0.25 + 0.1 * sin(stats.timeElapsed * 3),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    // Charge trail
    if (comp.chargeTimer > 0) {
      final chargeWidth = (comp.chargeSweepRadius / 48.0).clamp(0.70, 2.20);
      final trailScale = (comp.chargeOvershootDistance / 80.0).clamp(
        0.65,
        2.10,
      );
      canvas.drawCircle(
        Offset.zero,
        28 * chargeWidth,
        Paint()
          ..color = ec.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      for (var t = 0; t < 4; t++) {
        final trailAngle = comp.angle + pi;
        final trailDist = (7.0 + t * 7.0) * trailScale;
        canvas.drawCircle(
          Offset(cos(trailAngle) * trailDist, sin(trailAngle) * trailDist),
          (5.0 - t) * chargeWidth,
          Paint()
            ..color = ec.withValues(alpha: (1.0 - t / 4.0) * 0.34)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }

    // Sprite rendering (same as cosmic game)
    if (ticker != null) {
      final sprite = ticker.getSprite();
      final paint = Paint()..filterQuality = ui.FilterQuality.high;

      // Hit flash
      if (comp.hitFlash > 0) {
        paint.colorFilter = const ui.ColorFilter.mode(
          Colors.white,
          BlendMode.srcATop,
        );
      } else if (visuals != null) {
        // Apply genetics color filter
        final v = visuals;
        final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
        if (isAlbino) {
          paint.colorFilter = _albinoColorFilter(v.brightness);
        } else {
          paint.colorFilter = _geneticsColorFilter(v);
        }
      }

      // Flip sprite to face movement direction
      final facingRight = cos(comp.angle) > 0;
      canvas.save();
      if (facingRight) {
        canvas.scale(-spriteScale, spriteScale);
      } else {
        canvas.scale(spriteScale, spriteScale);
      }
      sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
      canvas.restore();
    } else {
      // Fallback: circle (no sprite sheet)
      final flashColor = comp.hitFlash > 0
          ? Color.lerp(ec, Colors.white, comp.hitFlash)!
          : ec;
      canvas.drawCircle(
        Offset.zero,
        14,
        Paint()..color = flashColor.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        Offset.zero,
        6,
        Paint()..color = Colors.white.withValues(alpha: 0.7),
      );
    }

    canvas.restore();

    // HP bar above companion
    final barW = 30.0;
    final barY = comp.position.dy - 28;
    canvas.drawRect(
      Rect.fromLTWH(comp.position.dx - barW / 2, barY, barW, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    final hpFrac = comp.hpPercent;
    final hpColor = hpFrac > 0.5
        ? const Color(0xFF00E676)
        : hpFrac > 0.25
        ? const Color(0xFFFFEA00)
        : const Color(0xFFE53935);
    canvas.drawRect(
      Rect.fromLTWH(comp.position.dx - barW / 2, barY, barW * hpFrac, 3),
      Paint()..color = hpColor,
    );
  }

  // == Genetics Color Filters (same as cosmic game) ========================

  ui.ColorFilter _geneticsColorFilter(SpriteVisuals v) {
    var m = _identityMatrix();
    if (v.saturation != 1.0 || v.brightness != 1.0) {
      m = _mulMatrix(_bsSatMatrix(v.brightness, v.saturation), m);
    }
    final rawHue = v.isPrismatic
        ? (v.hueShiftDeg + (stats.timeElapsed * 45.0) % 360)
        : v.hueShiftDeg;
    final normHue = ((rawHue % 360) + 360) % 360;
    if (normHue != 0) m = _mulMatrix(_hueMatrix(normHue), m);
    if (v.tint != null && !(v.brightness == 1.45 && !v.isPrismatic)) {
      final tr = v.tint!.r, tg = v.tint!.g, tb = v.tint!.b;
      m = _mulMatrix(<double>[
        tr,
        0,
        0,
        0,
        0,
        0,
        tg,
        0,
        0,
        0,
        0,
        0,
        tb,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ], m);
    }
    return ui.ColorFilter.matrix(m);
  }

  ui.ColorFilter _albinoColorFilter(double brightness) {
    const r = 0.299, g = 0.587, b = 0.114;
    return ui.ColorFilter.matrix(<double>[
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  List<double> _identityMatrix() => <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _bsSatMatrix(double brightness, double saturation) {
    final s = saturation;
    return <double>[
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueMatrix(double degrees) {
    final rad = degrees * (pi / 180.0);
    final c = cos(rad), s = sin(rad);
    return <double>[
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0,
      0,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0,
      0,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _mulMatrix(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      double tx = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        tx += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = tx;
    }
    return out;
  }

  /// Ship rendering: detailed ship design matching cosmic game
  void _renderShip(Canvas canvas) {
    final p = ship.position;
    final a = ship.angle;
    final ghostMode = ship.isDead;
    final flashColor = ship.hitFlash > 0
        ? Color.lerp(const Color(0xFF00B8D4), Colors.white, ship.hitFlash)!
        : ghostMode
        ? const Color(0xFF9FE8FF)
        : const Color(0xFF00B8D4);
    final elapsed = stats.timeElapsed;

    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.rotate(a + pi / 2);

    final enginePulse = ghostMode
        ? 0.55 + 0.18 * sin(elapsed * 4.5)
        : 0.85 + 0.15 * sin(elapsed * 9);
    if (ghostMode) {
      canvas.drawCircle(
        Offset.zero,
        28,
        Paint()
          ..color = const Color(
            0xFF7FDBFF,
          ).withValues(alpha: 0.10 + 0.05 * sin(elapsed * 2.2))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    canvas.drawCircle(
      const Offset(0, 18),
      9,
      Paint()
        ..color =
            (ghostMode ? const Color(0x808BE9FF) : const Color(0x7000CFFF))
                .withValues(alpha: (ghostMode ? 0.34 : 0.55) * enginePulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    for (final x in const [-5.5, 5.5]) {
      canvas.drawCircle(
        Offset(x, 15.5),
        3.2,
        Paint()
          ..color =
              (ghostMode ? const Color(0xAAE0F7FF) : const Color(0xCC8AF7FF))
                  .withValues(alpha: ghostMode ? 0.72 : 0.80),
      );
    }

    for (var i = 1; i <= 4; i++) {
      final wobble = sin(elapsed * 8 + i * 1.35) * (2.2 + i * 0.15);
      canvas.drawCircle(
        Offset(wobble, 18.0 + i * 7.5),
        4.2 - i * 0.65,
        Paint()
          ..color =
              (ghostMode ? const Color(0xFFA5EEFF) : const Color(0xFF5ED8FF))
                  .withValues(alpha: (ghostMode ? 0.18 : 0.24) - i * 0.03),
      );
    }

    final wingPath = Path()
      ..moveTo(0, -21)
      ..lineTo(-7, -13)
      ..lineTo(-14, -5)
      ..lineTo(-19, 10)
      ..lineTo(-9, 8)
      ..lineTo(-4, 18)
      ..lineTo(0, 15)
      ..lineTo(4, 18)
      ..lineTo(9, 8)
      ..lineTo(19, 10)
      ..lineTo(14, -5)
      ..lineTo(7, -13)
      ..close();

    final fuselagePath = Path()
      ..moveTo(0, -24)
      ..lineTo(-4.5, -11)
      ..lineTo(-5.5, -1)
      ..lineTo(-3.5, 13)
      ..lineTo(0, 15)
      ..lineTo(3.5, 13)
      ..lineTo(5.5, -1)
      ..lineTo(4.5, -11)
      ..close();

    canvas.drawPath(
      wingPath,
      Paint()
        ..color = Color.lerp(
          flashColor,
          Colors.black,
          ghostMode ? 0.15 : 0.4,
        )!.withValues(alpha: ghostMode ? 0.44 : 0.9),
    );
    canvas.drawPath(
      wingPath,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    canvas.drawPath(
      fuselagePath,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, -24),
          const Offset(0, 15),
          [
            Color.lerp(flashColor, Colors.white, 0.3)!.withValues(alpha: 0.95),
            flashColor.withValues(alpha: 0.85),
            Color.lerp(flashColor, Colors.black, 0.3)!.withValues(alpha: 0.75),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    canvas.drawCircle(
      const Offset(0, -12),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    canvas.drawCircle(
      const Offset(0, -12),
      2,
      Paint()..color = const Color(0xFF00E5FF).withValues(alpha: 0.5),
    );

    canvas.restore();

    final barW = 30.0;
    final barY = p.dy + 18;
    canvas.drawRect(
      Rect.fromLTWH(p.dx - barW / 2, barY, barW, 3),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    final hpFrac = ship.hpPercent;
    final hpColor = hpFrac > 0.5
        ? const Color(0xFF00E676)
        : hpFrac > 0.25
        ? const Color(0xFFFFEA00)
        : const Color(0xFFE53935);
    canvas.drawRect(
      Rect.fromLTWH(p.dx - barW / 2, barY, barW * hpFrac, 3),
      Paint()..color = hpColor,
    );
  }
}

// ---------------------------------------------------------------------------
// SHIP PROJECTILE (simple wrapper)
// ---------------------------------------------------------------------------

class ShipProjectile {
  Offset position;
  Offset velocity;
  double damage;
  double life;
  bool isHoming;
  CosmicSurvivalEnemy? target;
  final double splashRadius;

  ShipProjectile({
    required this.position,
    required this.velocity,
    required this.damage,
    this.life = 3.0,
    this.isHoming = false,
    this.target,
    this.splashRadius = 0,
  });

  bool get isRocket => splashRadius > 0;
}
