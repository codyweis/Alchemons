// lib/games/cosmic_survival/cosmic_survival_spawner.dart
//
// COSMIC SURVIVAL WAVE SPAWNER
// Endless waves of cosmic enemy types that scale in count, HP, speed, and tier.
// Boss encounters at milestone waves (every 5 waves).

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'dart:ui';

import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';

enum CosmicEnemyTarget { orb, ship, companion }

enum SurvivalBossDiscipline {
  standard,
  artillery,
  trickster,
  duelist,
  conductor,
  siegebreaker,
  riftcaller,
}

/// How a boss prefers to move relative to the orb / player.
/// - [chase]: closes the gap, brawler. Old default.
/// - [orbit]: holds a medium-far ring and strafes around it.
/// - [sniper]: hangs back near the arena edge and fires from range.
enum SurvivalBossMovementStyle { chase, orbit, sniper }

enum SurvivalWavePattern {
  mixed,
  wispHorde,
  hunterPack,
  siegePush,
  shooterScreen,
  swarmRush,
}

enum SurvivalWaveMutator {
  orbSiege,
  hunterSwarm,
  arcStorm,
  fortified,
  shatteredSpace,
  manaFlux,
}

// ──────────────────────────────────────────────────────────────────────────────
// SURVIVAL ENEMY (uses same EnemyTier as cosmic game)
// ──────────────────────────────────────────────────────────────────────────────

/// The seventeen elements' shared status vocabulary, as written by the mastery
/// payload resolver.
///
/// Kept apart from the bespoke per-family ability fields on purpose: those are
/// seventeen family x element behaviours, while these are the one set of
/// statuses every mastery node in the game writes through, or does not write
/// at all. Enemies and bosses both carry it so a payload never has to ask what
/// kind of body it landed on.
mixin MasteryPayloadStatuses {
  /// Damage-over-time from a payload. [masteryDotDps] is the summed rate of
  /// all live stacks; [masteryDotStacks] enforces the element's stack cap.
  double masteryDotTimer = 0;
  double masteryDotDps = 0;
  int masteryDotStacks = 0;
  int? masteryDotSlot;

  /// Ice's stacking cold. At the element's cap this converts to a freeze and
  /// the stacks clear.
  double masteryChillTimer = 0;
  int masteryChillStacks = 0;

  /// Dark's expose: the target takes [masteryVulnerableAmount] more damage
  /// from every source while the timer runs.
  double masteryVulnerableTimer = 0;
  double masteryVulnerableAmount = 0;

  /// Light's illuminate: allied damage amplification, capped by the payload
  /// so several Light sources cannot stack into a multiplier.
  double masteryAmpTimer = 0;
  double masteryAmpAmount = 0;

  /// Dust's haze: movement and attack cadence both reduced.
  double masteryHazeTimer = 0;
  double masteryHazeAmount = 0;

  /// Let's Cratermaker crack: the next Let auto-attack meteor to land on this
  /// body deals more. Every landing re-cracks it.
  double letFractureTimer = 0;

  /// Let's Sight (Ground Zero), from the special meteor. [letSightSlot] is
  /// the Let that applied it, which telemetry credits; [letSightCalledShot]
  /// is whether that Let has Called Shot, which turns the Sight into a bonus
  /// for the whole team.
  double letSightTimer = 0;
  int? letSightSlot;
  bool letSightCalledShot = false;
  bool letSightFireForEffect = false;

  bool get isLetSighted => letSightTimer > 0;

  /// Marks this body Sighted, keeping whichever Sight lasts longer.
  void applyLetSight({
    required int slotIndex,
    required double duration,
    required bool calledShot,
    required bool fireForEffect,
  }) {
    if (duration > letSightTimer) letSightTimer = duration;
    letSightSlot = slotIndex;
    letSightCalledShot = calledShot;
    letSightFireForEffect = fireForEffect;
  }

  void clearLetSight() {
    letSightTimer = 0;
    letSightSlot = null;
    letSightCalledShot = false;
    letSightFireForEffect = false;
  }

  /// Total incoming damage multiplier from mastery statuses. 1.0 when clean.
  double get masteryDamageTakenMultiplier {
    var mult = 1.0;
    if (masteryVulnerableTimer > 0) mult += masteryVulnerableAmount;
    if (masteryAmpTimer > 0) mult += masteryAmpAmount;
    return mult;
  }

  /// Ticks the payload statuses and returns the damage the DoT owes this
  /// frame. Returning the damage rather than applying it keeps the enemy
  /// free of any reference to the game that would have to kill it.
  double tickMasteryStatuses(double dt) {
    var damage = 0.0;
    if (masteryDotTimer > 0) {
      masteryDotTimer -= dt;
      damage = masteryDotDps * dt;
      if (masteryDotTimer <= 0) {
        masteryDotTimer = 0;
        masteryDotDps = 0;
        masteryDotStacks = 0;
        masteryDotSlot = null;
      }
    }
    if (masteryChillTimer > 0) {
      masteryChillTimer -= dt;
      if (masteryChillTimer <= 0) {
        masteryChillTimer = 0;
        masteryChillStacks = 0;
      }
    }
    if (masteryVulnerableTimer > 0) {
      masteryVulnerableTimer -= dt;
      if (masteryVulnerableTimer <= 0) masteryVulnerableAmount = 0;
    }
    if (masteryAmpTimer > 0) {
      masteryAmpTimer -= dt;
      if (masteryAmpTimer <= 0) masteryAmpAmount = 0;
    }
    if (masteryHazeTimer > 0) {
      masteryHazeTimer -= dt;
      if (masteryHazeTimer <= 0) masteryHazeAmount = 0;
    }
    if (letFractureTimer > 0) {
      letFractureTimer -= dt;
      if (letFractureTimer < 0) letFractureTimer = 0;
    }
    if (letSightTimer > 0) {
      letSightTimer -= dt;
      if (letSightTimer <= 0) clearLetSight();
    }
    return damage;
  }
}

class CosmicSurvivalEnemy with MasteryPayloadStatuses {
  Offset position;
  Offset knockbackVelocity;
  double angle;
  double hp;
  final double maxHp;
  final double speed;
  final double damage;
  final double radius;
  final EnemyTier tier;
  final bool isPlagueCore;
  final Color? visualColor;
  final String element;

  /// Converged taxonomy (docs/enemy_taxonomy.md). Derived from role+variant
  /// during migration; once the spawner picks these directly, role and variant
  /// go away.
  final EnemyConduct conduct;
  final EnemyTrait? trait;
  CosmicEnemyTarget target;
  bool isDead;
  double hitFlash;
  double slowTimer;
  double slowMultiplier;
  double attackCooldown;
  double retargetTimer;
  final bool isElite;
  final EliteAffix? eliteAffix;
  // Mane+Plant pierce sets this to the source slot index. If the
  // enemy dies while still flagged, the resolver triggers an AOE
  // explosion at the kill site.
  int? maneRootSlot;
  double maneRootTimer;
  // Pip+Mud hit sets this to true so the enemy permanently leaves
  // mud trail puffs that slow other enemies behind it.
  bool pipMudTrail;
  double pipMudTrailTimer;
  // Wing+Dust disorient: while > 0, shooter-role enemies target
  // other enemies instead of the orb/ship.
  double disorientTimer;
  // Horn+Plant per-enemy root: while > 0, the enemy is rooted in
  // place and wears a green vine-wrap visual. Set by Plant horn's
  // charge-sweep hits.
  double hornPlantRootTimer;
  // Mane+Poison stacking damage: every pierce by the mane Poison
  // catapult increments this; persistent poison DoT scales with
  // the stack count so chained pierces hit harder.
  int manePoisonStacks;
  // Wing+Ice frost buildup: a sustained ice beam ramps this from 0→1;
  // at 1 the enemy snaps into a hard freeze and it resets.
  double frostBuildup;
  // Summoner-variant cooldown. >0 means "ready to summon in X seconds".
  double summonCooldown;
  // Mask+Blood permanent drain: enemies that pass through the blood
  // blob are tagged here with the source slot. Per-frame drain pulls
  // HP from them and splits it as healing across all allies until the
  // enemy dies. Cleared on death.
  int? maskBloodDrainSlot;

  /// Ice Mystic's blizzard. A separate multiplier from [slowMultiplier] on
  /// purpose: that field holds the single strongest slow currently applied, so
  /// a blizzard written into it would either be swallowed by a stronger slow or
  /// swallow one. The world is weather, not an effect competing with effects —
  /// it multiplies whatever else is already happening.
  double blizzardMultiplier = 1.0;

  // Shared hover/dive steering state (lazily created by whichever mode is
  // driving this enemy). See games/shared/enemy_flight_steering.dart.
  FlightSteeringState? flightSteering;

  /// The body's signature attack, as a four-phase performance.
  /// See games/shared/enemy_action.dart.
  final EnemyActionState action = EnemyActionState();

  CosmicSurvivalEnemy({
    required this.position,
    this.knockbackVelocity = Offset.zero,
    this.angle = 0,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.damage,
    required this.radius,
    required this.tier,
    this.isPlagueCore = false,
    this.visualColor,
    required this.element,
    required this.conduct,
    this.trait,
    required this.target,
    this.isDead = false,
    this.hitFlash = 0,
    this.slowTimer = 0,
    this.slowMultiplier = 0.5,
    this.attackCooldown = 0,
    this.retargetTimer = 0,
    this.isElite = false,
    this.eliteAffix,
    this.maneRootSlot,
    this.maneRootTimer = 0,
    this.pipMudTrail = false,
    this.pipMudTrailTimer = 0,
    this.disorientTimer = 0,
    this.hornPlantRootTimer = 0,
    this.manePoisonStacks = 0,
    this.frostBuildup = 0,
    this.summonCooldown = 0,
    this.maskBloodDrainSlot,
  });

  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0, 1) : 0;

  /// True for bodies heavy enough to earn the charge speed bonus that the old
  /// `crusher` variant used to smuggle into its movement vector.
  bool get hasHeavyBody =>
      tier == EnemyTier.brute || tier == EnemyTier.colossus;

  double get effectiveSpeed {
    if (maneRootTimer > 0 || hornPlantRootTimer > 0 || slowMultiplier <= 0) {
      return 0;
    }
    final blizzard = blizzardMultiplier;
    // Dust's haze is weather too, not an effect competing with effects: it
    // multiplies whatever slow is already running rather than fighting the
    // strongest-slow-wins rule in slowMultiplier.
    final haze = masteryHazeTimer > 0 ? (1.0 - masteryHazeAmount) : 1.0;
    // The crusher's old `* 1.08` lived in the direction vector, which made a
    // stat look like a steering rule. It is an explicit speed term now.
    final conductBonus = conductSpeedMultiplier(
      conduct,
      heavyBody: hasHeavyBody,
    );
    if (slowTimer <= 0) return speed * conductBonus * blizzard * haze;
    return speed *
        conductBonus *
        blizzard *
        haze *
        (isRelentless ? max(0.78, slowMultiplier) : slowMultiplier);
  }

  bool get isShooter =>
      conduct == EnemyConduct.standoff || conduct == EnemyConduct.siege;

  /// Artillery: holds past companion reach and shells the orb.
  bool get isSiegeArtillery => conduct == EnemyConduct.siege;
  bool get hasBulwark => eliteAffix == EliteAffix.bulwarked;
  bool get isVolatile => eliteAffix == EliteAffix.volatile;
  bool get isVampiric => eliteAffix == EliteAffix.vampiric;
  bool get isOverclocked => eliteAffix == EliteAffix.overclocked;
  bool get isRelentless => eliteAffix == EliteAffix.relentless;
}

// ──────────────────────────────────────────────────────────────────────────────
// SURVIVAL BOSS
// ──────────────────────────────────────────────────────────────────────────────

class SurvivalBoss with MasteryPayloadStatuses {
  final BossTemplate template;
  final BossType type;
  final SurvivalBossDiscipline discipline;
  final int level;
  Offset position;
  double angle;
  double hp;
  final double maxHp;
  double speed;
  final double baseSpeed;

  /// Crowd control. While [chillTimer] is running, everything the boss's AI
  /// does to its position in a frame is scaled by [chillMultiplier].
  ///
  /// Deliberately NOT a modifier on [speed]: the discipline AIs write that
  /// field themselves (the warden sets it to baseSpeed * 1.5 on enrage), so a
  /// scalar wrapped around them would clobber their own changes. Scaling the
  /// resulting displacement instead works for every AI, including charge
  /// dashes and strafes, and cannot fight anything.
  double chillTimer = 0;
  double chillMultiplier = 1.0;
  final double radius;
  final Color color;
  bool isDead;
  double hitFlash;
  double phaseTimer;

  // Charger state
  bool charging;
  double chargeTimer;
  double chargeAngle;
  double chargeDashTimer;

  // Gunner state
  double shootTimer;
  bool shieldUp;
  double shieldHealth;
  double shieldTimer;

  // Carrier state
  double escortTimer;

  // Warden state
  double spreadTimer;
  double summonTimer;
  bool enraged;
  double spawnIntroTimer;
  double spawnIntroDuration;
  Offset? spawnFromPosition;
  Offset? spawnTargetPosition;

  // Titanic trait state
  double colossalTraitTimer;
  double colossalTraitAuxTimer;

  // Movement profile chosen at spawn — drives whether the boss chases,
  // strafes a ring, or sits back firing.
  final SurvivalBossMovementStyle movementStyle;

  /// Preferred distance the boss tries to hold from its anchor target.
  /// Each AI uses this as the radial setpoint instead of a hardcoded value.
  final double engagementRange;

  /// Ranged bosses overheat after a burst: they plant, stop firing, and are
  /// exposed. Retreat has to be a PHASE, not a permanent state, or the fight
  /// is just a chase across the arena.
  double overheatTimer = 0;
  int shotsSinceVent = 0;

  bool get isVenting => overheatTimer > 0;

  /// 0..1 — how aggressively the boss tangentially strafes its ring.
  /// Snipers ≈ 0.15 (mostly still), orbiters ≈ 0.7, chasers ≈ 1.0.
  final double strafeWeight;

  // Constants
  static const double chargeCooldown = 3.0;
  static const double chargeDashDuration = 0.6;
  static const double chargeSpeedMultiplier = 3.0;
  static const double shootCooldown = 1.5;
  static const double shieldCooldown = 8.0;
  static const double shieldDuration = 4.0;
  static const double shieldMaxHealth = 50.0;
  static const double escortCooldown = 10.0;
  static const double spreadCooldown = 2.5;
  static const double summonCooldown = 12.0;
  static const double enrageThreshold = 0.3;

  SurvivalBoss({
    required this.template,
    required this.type,
    this.discipline = SurvivalBossDiscipline.standard,
    required this.level,
    required this.position,
    this.angle = 0,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.baseSpeed,
    required this.radius,
    required this.color,
    this.isDead = false,
    this.hitFlash = 0,
    this.phaseTimer = 0,
    this.charging = false,
    this.chargeTimer = 1.0, // first charge comes quickly
    this.chargeAngle = 0,
    this.chargeDashTimer = 0,
    this.shootTimer = 0.5, // fire soon after spawn
    this.shieldUp = false,
    this.shieldHealth = 0,
    this.shieldTimer = shieldCooldown,
    this.escortTimer = escortCooldown,
    this.spreadTimer = 1.0, // spread soon after spawn
    this.summonTimer = summonCooldown,
    this.enraged = false,
    this.spawnIntroTimer = 0,
    this.spawnIntroDuration = 1.2,
    this.spawnFromPosition,
    this.spawnTargetPosition,
    this.colossalTraitTimer = 0,
    this.colossalTraitAuxTimer = 0,
    this.movementStyle = SurvivalBossMovementStyle.chase,
    this.engagementRange = 220.0,
    this.strafeWeight = 0.8,
  });

  double get hpFraction => maxHp > 0 ? (hp / maxHp).clamp(0, 1) : 0;
  bool get isSpawning => spawnIntroTimer > 0;
}

// ──────────────────────────────────────────────────────────────────────────────
// BOSS PROJECTILE
// ──────────────────────────────────────────────────────────────────────────────

class SurvivalBossProjectile {
  Offset position;
  final double angle;
  final String element;
  final double damage;
  final double speed;
  double life;
  final double radius;

  SurvivalBossProjectile({
    required this.position,
    required this.angle,
    required this.element,
    required this.damage,
    this.speed = 250,
    this.life = 4.0,
    this.radius = 5.0,
  });
}

class SurvivalEnemyProjectile {
  Offset position;
  // Non-final so Horn+Ice walls and Horn+Light barriers can reflect
  // the projectile (mutates angle to point back at the firer side).
  double angle;
  final String element;
  final double damage;
  final double speed;
  double life;
  final double radius;
  final CosmicEnemyTarget target;
  // Wing+Dust disorient: when true, this enemy projectile damages
  // other enemies on collision instead of the orb/ship/companions.
  // Also flipped to true by Horn+Ice / Horn+Light reflects.
  bool friendlyFire;

  SurvivalEnemyProjectile({
    required this.position,
    required this.angle,
    required this.element,
    required this.damage,
    required this.target,
    this.speed = 220,
    this.life = 4.0,
    this.radius = 4.0,
    this.friendlyFire = false,
  });
}

/// A non-projectile enemy hazard: something with a shape and a lifetime rather
/// than a position and a velocity.
///
/// Two shapes cover every body's commit phase, so the beam and the shockwave
/// do not each need their own entity and collision path.
enum EnemyHazardKind {
  /// A line from [origin] along [angle]. Damages anything near the segment.
  beam,

  /// A ring expanding from [origin]. Damages anything the wavefront crosses.
  shockwave,
}

class SurvivalEnemyHazard {
  SurvivalEnemyHazard({
    required this.kind,
    required this.origin,
    required this.angle,
    required this.element,
    required this.damage,
    required this.life,
    required this.maxLife,
    this.length = 0,
    this.width = 0,
    this.maxRadius = 0,
  });

  final EnemyHazardKind kind;
  final Offset origin;
  final double angle;
  final String element;
  final double damage;

  double life;
  final double maxLife;

  /// Beam geometry.
  final double length;
  final double width;

  /// Shockwave geometry.
  final double maxRadius;

  /// Targets already hit — each hazard hits a given thing at most once.
  final Set<Object> hit = <Object>{};

  double get progress =>
      maxLife <= 0 ? 1.0 : (1.0 - life / maxLife).clamp(0.0, 1.0);

  /// Current wavefront radius for a shockwave.
  double get radius => maxRadius * progress;
}

// ──────────────────────────────────────────────────────────────────────────────
// TIER STAT HELPERS
// ──────────────────────────────────────────────────────────────────────────────

double tierBaseHp(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 8,
  EnemyTier.drone => 20,
  EnemyTier.sentinel => 50,
  EnemyTier.phantom => 85,
  EnemyTier.brute => 180,
  EnemyTier.colossus => 400,
};

double tierRadius(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 6,
  EnemyTier.drone => 10,
  EnemyTier.sentinel => 14,
  EnemyTier.phantom => 12,
  EnemyTier.brute => 20,
  EnemyTier.colossus => 28,
};

double tierBaseSpeed(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 90,
  EnemyTier.drone => 70,
  EnemyTier.sentinel => 45,
  EnemyTier.phantom => 65,
  EnemyTier.brute => 30,
  EnemyTier.colossus => 20,
};

double tierBaseDamage(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 2,
  EnemyTier.drone => 4,
  EnemyTier.sentinel => 7,
  EnemyTier.phantom => 10,
  EnemyTier.brute => 18,
  EnemyTier.colossus => 30,
};

int tierShardReward(EnemyTier tier) => switch (tier) {
  EnemyTier.wisp => 1,
  EnemyTier.drone => 3,
  EnemyTier.sentinel => 6,
  EnemyTier.phantom => 10,
  EnemyTier.brute => 20,
  EnemyTier.colossus => 40,
};

// ──────────────────────────────────────────────────────────────────────────────
// ELEMENTS (for random assignment)
// ──────────────────────────────────────────────────────────────────────────────

const _kElements = [
  'Fire',
  'Lava',
  'Lightning',
  'Water',
  'Ice',
  'Steam',
  'Earth',
  'Mud',
  'Dust',
  'Crystal',
  'Air',
  'Plant',
  'Poison',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];

// ──────────────────────────────────────────────────────────────────────────────
// WAVE SPAWNER
// ──────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalSpawner {
  static const double earlyAdvanceKillThreshold = 0.90;

  CosmicSurvivalSpawner({Random? random}) : _rng = random ?? Random();

  final Random _rng;
  final List<String> _recentBossNames = <String>[];
  final List<String> _recentBossElements = <String>[];

  int currentWave = 0;

  /// The arena's rim as of the last update; spawns land beyond it. Null until
  /// a game passes one in, when the old view-based margin is used.
  double? _arenaRim;
  bool intermission = false;
  bool isBossWave = false;
  bool bossSpawned = false;

  /// Direction the wave's fronts are centred on, and how many there are.
  /// Both roll per wave; the escape gap sits opposite the middle front.
  double frontBearing = 0;
  int frontCount = 3;
  double _waveSizeJitter = 1.0;
  SurvivalWaveMutator? _lastMutator;
  SurvivalWavePattern currentPattern = SurvivalWavePattern.mixed;
  SurvivalWaveMutator? currentMutator;

  double _spawnTimer = 0;
  int _spawnedThisWave = 0;
  int _artilleryThisWave = 0;
  int _broodThisWave = 0;
  int _targetCountThisWave = 0;
  bool _waveActive = false;
  bool _waitingForClear = false;

  int get targetCountThisWave => _targetCountThisWave;
  int get spawnedThisWave => _spawnedThisWave;

  void startFirstWave() {
    currentWave = 0;
    _advanceWave();
  }

  /// Advances the wave without requiring the arena to be cleared. Test-only:
  /// spawn-policy tests need to reach the deep-wave trait gates.
  @visibleForTesting
  void forceNextWaveForTest() => _advanceWave();

  void _advanceWave() {
    currentWave++;
    intermission = false;
    isBossWave = isBossWaveNumber(currentWave);
    currentPattern = isBossWave
        ? SurvivalWavePattern.mixed
        : _patternForWave(currentWave);
    currentMutator = isBossWave ? null : _rollMutatorForWave(currentWave);
    _lastMutator = currentMutator ?? _lastMutator;
    // Where the wave comes from, and how it is cut up. Rolled per wave so the
    // escape gap is somewhere new and a front can be a broad two or a tight
    // four rather than always three.
    frontBearing = _rng.nextDouble() * 2 * pi;
    final frontRoll = _rng.nextDouble();
    frontCount = frontRoll < 0.25
        ? 2
        : frontRoll < 0.78
        ? 3
        : 4;
    _waveSizeJitter = 0.90 + _rng.nextDouble() * 0.25;
    bossSpawned = false;
    _spawnedThisWave = 0;
    _artilleryThisWave = 0;
    _broodThisWave = 0;
    _targetCountThisWave = _enemyCountForWave(currentWave);
    _spawnTimer = 0;
    _waveActive = true;
    _waitingForClear = false;
  }

  static bool isBossWaveNumber(int wave) => wave > 0 && wave % 5 == 0;

  int _enemyCountForWave(int wave) {
    if (isBossWave) return CosmicSurvivalBalance.bossEscortCount(wave);
    final base = CosmicSurvivalBalance.hordeCountForWave(wave);
    final multiplier = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => 1.35,
      SurvivalWavePattern.hunterPack => 1.10,
      SurvivalWavePattern.siegePush => 0.78,
      SurvivalWavePattern.shooterScreen => 0.92,
      SurvivalWavePattern.swarmRush => 1.24,
      SurvivalWavePattern.mixed => 1.0,
    };
    final mutatorMultiplier = switch (currentMutator) {
      SurvivalWaveMutator.orbSiege => 1.12,
      SurvivalWaveMutator.hunterSwarm => 1.08,
      SurvivalWaveMutator.arcStorm => 1.05,
      SurvivalWaveMutator.fortified => 0.94,
      SurvivalWaveMutator.shatteredSpace => 0.92,
      SurvivalWaveMutator.manaFlux => 1.0,
      null => 1.0,
    };
    return (base * multiplier * mutatorMultiplier * _waveSizeJitter)
        .round()
        .clamp(24, CosmicSurvivalBalance.hordeWaveTotalCeiling);
  }

  double _spawnInterval(int wave) {
    if (isBossWave) return CosmicSurvivalBalance.bossEscortInterval(wave);
    final base = (0.85 - wave * 0.012).clamp(0.28, 0.85);
    final patternInterval = switch (currentPattern) {
      SurvivalWavePattern.wispHorde => max(0.12, base * 0.45),
      SurvivalWavePattern.hunterPack => max(0.16, base * 0.72),
      SurvivalWavePattern.siegePush => min(0.88, base * 1.08),
      SurvivalWavePattern.shooterScreen => max(0.18, base * 0.76),
      SurvivalWavePattern.swarmRush => max(0.14, base * 0.58),
      SurvivalWavePattern.mixed => base,
    };
    final mutatorFactor = switch (currentMutator) {
      SurvivalWaveMutator.hunterSwarm => 0.90,
      SurvivalWaveMutator.arcStorm => 0.92,
      SurvivalWaveMutator.shatteredSpace => 0.82,
      SurvivalWaveMutator.manaFlux => 0.96,
      _ => 1.0,
    };
    return max(0.10, patternInterval * mutatorFactor);
  }

  /// When each mutator becomes eligible. A run used to read the same schedule
  /// every time — wave 7 was always an Orb Siege — so the modifiers are now
  /// rolled from what the wave has unlocked.
  static const Map<SurvivalWaveMutator, int> kMutatorUnlockWave = {
    SurvivalWaveMutator.orbSiege: 7,
    SurvivalWaveMutator.hunterSwarm: 8,
    SurvivalWaveMutator.arcStorm: 10,
    SurvivalWaveMutator.manaFlux: 14,
    SurvivalWaveMutator.fortified: 14,
    SurvivalWaveMutator.shatteredSpace: 18,
  };

  /// What this wave could roll. Empty before wave 7 and on boss waves, which
  /// carry their own mechanics.
  static List<SurvivalWaveMutator> mutatorPoolForWave(int wave) {
    if (wave < 7 || isBossWaveNumber(wave)) return const [];
    return [
      for (final entry in kMutatorUnlockWave.entries)
        if (wave >= entry.value) entry.key,
    ];
  }

  /// Rolls this wave's modifier. Never the one the player just played, and
  /// often nothing at all, so a run has quiet waves as well as loud ones.
  SurvivalWaveMutator? _rollMutatorForWave(int wave) {
    final pool = mutatorPoolForWave(wave);
    if (pool.isEmpty) return null;
    // Early on, most waves are plain; later, most waves carry something.
    final chance = wave < 12 ? 0.55 : 0.78;
    if (_rng.nextDouble() > chance) return null;
    final choices = pool.length > 1
        ? (pool.where((m) => m != _lastMutator).toList())
        : pool;
    return choices[_rng.nextInt(choices.length)];
  }

  SurvivalWavePattern _patternForWave(int wave) {
    if (wave <= 2) return SurvivalWavePattern.mixed;
    // The old rules were hard locks, so wave 7 was a wisp horde in every run
    // that has ever been played. They are now strong leanings: the rhythm
    // survives, the certainty does not.
    const keep = 0.65;
    if (wave % 9 == 0 && _rng.nextDouble() < keep) {
      return SurvivalWavePattern.siegePush;
    }
    if (wave >= 8 && wave % 11 == 0 && _rng.nextDouble() < keep) {
      return SurvivalWavePattern.swarmRush;
    }
    if (wave % 7 == 0 && _rng.nextDouble() < keep) {
      return SurvivalWavePattern.wispHorde;
    }
    if (wave >= 10 && wave % 6 == 0 && _rng.nextDouble() < keep) {
      return SurvivalWavePattern.shooterScreen;
    }
    if (wave >= 5 && wave.isOdd) {
      return _rng.nextDouble() < 0.34
          ? SurvivalWavePattern.hunterPack
          : SurvivalWavePattern.mixed;
    }
    final roll = _rng.nextDouble();
    if (roll < 0.18) return SurvivalWavePattern.wispHorde;
    if (roll < 0.32) return SurvivalWavePattern.hunterPack;
    if (wave >= 8 && roll < 0.44) return SurvivalWavePattern.swarmRush;
    if (wave >= 10 && roll < 0.58) return SurvivalWavePattern.shooterScreen;
    return SurvivalWavePattern.mixed;
  }

  EnemyTier _tierForWave(int wave) {
    if (currentMutator == SurvivalWaveMutator.fortified) {
      final roll = _rng.nextDouble();
      if (wave >= 24 && roll < 0.12) return EnemyTier.colossus;
      if (wave >= 14 && roll < 0.38) return EnemyTier.brute;
      if (roll < 0.72) return EnemyTier.sentinel;
      return EnemyTier.drone;
    }
    switch (currentPattern) {
      case SurvivalWavePattern.wispHorde:
        final roll = _rng.nextDouble();
        if (wave >= 14 && roll < 0.06) return EnemyTier.sentinel;
        if (wave >= 8 && roll < 0.26) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.hunterPack:
        final roll = _rng.nextDouble();
        if (wave >= 18 && roll < 0.12) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.34) return EnemyTier.phantom;
        if (roll < 0.74) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.siegePush:
        final roll = _rng.nextDouble();
        if (wave >= 22 && roll < 0.16) return EnemyTier.colossus;
        if (wave >= 12 && roll < 0.42) return EnemyTier.brute;
        if (roll < 0.78) return EnemyTier.sentinel;
        return EnemyTier.drone;
      case SurvivalWavePattern.shooterScreen:
        final roll = _rng.nextDouble();
        if (wave >= 18 && roll < 0.16) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.46) return EnemyTier.phantom;
        if (roll < 0.82) return EnemyTier.sentinel;
        return EnemyTier.drone;
      case SurvivalWavePattern.swarmRush:
        final roll = _rng.nextDouble();
        if (wave >= 16 && roll < 0.08) return EnemyTier.brute;
        if (wave >= 10 && roll < 0.24) return EnemyTier.phantom;
        if (wave >= 12 && roll < 0.40) return EnemyTier.sentinel;
        if (roll < 0.78) return EnemyTier.drone;
        return EnemyTier.wisp;
      case SurvivalWavePattern.mixed:
        break;
    }

    // Progressively add harder tiers
    if (wave >= 30) {
      final roll = _rng.nextDouble();
      if (roll < 0.10) return EnemyTier.colossus;
      if (roll < 0.30) return EnemyTier.brute;
      if (roll < 0.55) return EnemyTier.phantom;
      if (roll < 0.80) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 20) {
      final roll = _rng.nextDouble();
      if (roll < 0.05) return EnemyTier.colossus;
      if (roll < 0.20) return EnemyTier.brute;
      if (roll < 0.45) return EnemyTier.phantom;
      if (roll < 0.75) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 12) {
      final roll = _rng.nextDouble();
      if (roll < 0.10) return EnemyTier.brute;
      if (roll < 0.30) return EnemyTier.phantom;
      if (roll < 0.60) return EnemyTier.sentinel;
      return EnemyTier.drone;
    } else if (wave >= 6) {
      final roll = _rng.nextDouble();
      if (roll < 0.05) return EnemyTier.phantom;
      if (roll < 0.25) return EnemyTier.sentinel;
      if (roll < 0.60) return EnemyTier.drone;
      return EnemyTier.wisp;
    } else if (wave >= 3) {
      final roll = _rng.nextDouble();
      if (roll < 0.15) return EnemyTier.sentinel;
      if (roll < 0.45) return EnemyTier.drone;
      return EnemyTier.wisp;
    } else {
      return _rng.nextDouble() < 0.3 ? EnemyTier.drone : EnemyTier.wisp;
    }
  }

  /// Called every frame. Returns new enemies to add.
  /// The field's cap right now — what a broodmother's output is bounded by.
  int get activeLimitNow =>
      CosmicSurvivalBalance.activeEnemyLimit(currentWave, bossWave: isBossWave);

  List<CosmicSurvivalEnemy> update(
    double dt,
    int aliveCount,
    double viewW,
    double viewH,
    Offset orbPos, {
    double? arenaRadius,
  }) {
    if (arenaRadius != null) _arenaRim = arenaRadius;
    if (!_waveActive || _waitingForClear) return const [];

    // Pause scheduled reinforcements while the arena is saturated. Boss adds
    // and plague sources count toward this limit too.
    final activeLimit = CosmicSurvivalBalance.activeEnemyLimit(
      currentWave,
      bossWave: isBossWave,
    );
    if (aliveCount >= activeLimit) return const [];
    _spawnTimer += dt;
    final interval = _spawnInterval(currentWave);
    if (_spawnTimer < interval) return const [];
    _spawnTimer = 0;

    if (_spawnedThisWave >= _targetCountThisWave) {
      _waitingForClear = true;
      return const [];
    }

    final batchLimit = isBossWave
        ? 2
        : CosmicSurvivalBalance.hordeBatchSize(currentWave);
    final batchSize = min(
      min(batchLimit, activeLimit - aliveCount),
      _targetCountThisWave - _spawnedThisWave,
    );
    final spawned = <CosmicSurvivalEnemy>[];
    for (var i = 0; i < batchSize; i++) {
      spawned.add(_spawnEnemy(viewW, viewH, orbPos));
      _spawnedThisWave++;
    }
    return spawned;
  }

  /// Bodies heavy enough to earn the charge stat profile the old `crusher`
  /// variant carried.
  static bool hasHeavyBody(EnemyTier tier) =>
      tier == EnemyTier.brute || tier == EnemyTier.colossus;

  /// Rolls an optional extra mechanic. Body-independent by design.
  EnemyTrait? _traitForWave(int wave) {
    if (wave >= 14 && _rng.nextDouble() < 0.10) return EnemyTrait.splitter;
    if (wave >= 12 && _rng.nextDouble() < 0.10) return EnemyTrait.summoner;
    if (wave >= 8 && _rng.nextDouble() < 0.12) return EnemyTrait.breaker;
    return null;
  }

  CosmicSurvivalEnemy _spawnEnemy(double viewW, double viewH, Offset orbPos) {
    // Bosses and outbreaks already supply the major mechanics. Escorts
    // provide interceptable pressure rather than another heavy siege wave.
    final escortRoll = isBossWave ? _rng.nextDouble() : 0.0;
    // A front is chaff plus the two things chaff cannot do: shell the orb
    // from outside anyone's reach, and keep replacing itself.
    final wantsArtillery =
        !isBossWave &&
        _artilleryThisWave <
            CosmicSurvivalBalance.artilleryCountForWave(currentWave) &&
        _rng.nextDouble() < 0.12;
    final wantsBrood =
        !isBossWave &&
        !wantsArtillery &&
        _broodThisWave < CosmicSurvivalBalance.broodCountForWave(currentWave) &&
        _rng.nextDouble() < 0.10;
    if (wantsArtillery) _artilleryThisWave++;
    if (wantsBrood) _broodThisWave++;
    // Keep a minority of authored threats among the slow advancing bodies.
    final hordeBody =
        !isBossWave &&
        !wantsArtillery &&
        !wantsBrood &&
        _rng.nextDouble() < 0.80;
    final tier = isBossWave
        ? (escortRoll < 0.45
              ? EnemyTier.drone
              : escortRoll < 0.75
              ? EnemyTier.sentinel
              : escortRoll < 0.95
              ? EnemyTier.phantom
              : EnemyTier.brute)
        : wantsArtillery
        ? EnemyTier.sentinel
        : wantsBrood
        ? EnemyTier.brute
        : hordeBody
        ? (_rng.nextDouble() < 0.72 ? EnemyTier.wisp : EnemyTier.drone)
        : _tierForWave(currentWave);
    final element = _kElements[_rng.nextInt(_kElements.length)];
    // CONDUCT — how it moves, straight from the wave's shape.
    var conduct = _conductForWave(currentWave, tier);
    if ((currentPattern == SurvivalWavePattern.siegePush ||
            currentMutator == SurvivalWaveMutator.fortified) &&
        _rng.nextDouble() < 0.34) {
      conduct = EnemyConduct.charge;
    } else if ((currentPattern == SurvivalWavePattern.hunterPack ||
            currentPattern == SurvivalWavePattern.swarmRush) &&
        _rng.nextDouble() < 0.32) {
      conduct = EnemyConduct.stalk;
    }

    if (hordeBody) conduct = EnemyConduct.charge;
    if (wantsArtillery) conduct = EnemyConduct.siege;
    if (wantsBrood) conduct = EnemyConduct.charge;

    // TRAIT — an extra mechanic, rolled INDEPENDENTLY of the body.
    //
    // This is the §2.4 fix. Traits used to be locked to the tier that implied
    // them: summoner only on sentinel/phantom, splitter only on
    // brute/colossus, breaker only on a heavy striker. So most of the nominal
    // combination space was unreachable by construction. Any body can now
    // carry any trait — a summoner wisp is a thing that can happen.
    final trait = isBossWave
        ? (_rng.nextDouble() < 0.12 ? EnemyTrait.breaker : null)
        : wantsBrood
        ? EnemyTrait.summoner
        : wantsArtillery
        ? null
        : hordeBody
        ? null
        : _traitForWave(currentWave);

    // Three coherent fronts leave a 60-degree escape sector. Each 24-body
    // band advances to the next front; later bands fill depth rather than
    // stacking every spawn at one point. Boss escorts keep their old spread.
    //
    // Everything that walks in, walks in from OUTSIDE the arena: bodies appear
    // beyond the rim and cross it, so a wave is something you watch arrive
    // rather than something that materialises on the field. Only enemies that
    // portal by design (phantom blinks, summons, splits, outbreak cores,
    // bosses' entrances) ever appear inside.
    final margin =
        (_arenaRim ?? max(viewW, viewH) * 0.55) +
        CosmicSurvivalBalance.hordeSpawnBeyondRim;
    final gap = CosmicSurvivalBalance.hordeSpawnGap;
    // Early waves send one or two bands total, so the full rim leaves them
    // strung too thin to meet anywhere. Pull the fronts together until the
    // wave is big enough to fill them.
    final usableArc =
        (2 * pi - gap) * CosmicSurvivalBalance.hordeFrontOpenness(currentWave);
    // A wave only earns as many fronts as it can fill. Opening a second front
    // for a four-body remainder is how wave 2 ended up arriving from two
    // bearings 150 degrees apart; the remainder becomes depth instead.
    final fronts = min(frontCount, max(1, _targetCountThisWave ~/ 24));
    // The rolled count sets how WIDE a front is; the capped count only sets how
    // many bearings get used. Dividing by the capped count instead would hand a
    // collapsed single front the entire wedge, which is the opposite of clumping.
    final frontSpan = usableArc / frontCount;
    final band = _spawnedThisWave ~/ 24;
    final front = band % fronts;
    final along = (_spawnedThisWave % 24) / 23;
    final angle = isBossWave
        ? _rng.nextDouble() * 2 * pi
        : frontBearing + gap / 2 + front * frontSpan + along * frontSpan * 0.78;
    // Step back a rank once every front has taken a band. This used to divide
    // by a hard-coded 72, which is three fronts' worth — at two or four fronts
    // whole bands were landing on top of each other.
    final depth = isBossWave
        ? 0.0
        : ((band ~/ fronts) % 6) * 18 + _rng.nextDouble() * 12;
    final pos = Offset(
      orbPos.dx + cos(angle) * (margin + depth),
      orbPos.dy + sin(angle) * (margin + depth),
    );

    // Elite champion chance past wave 20
    final isElite =
        currentWave >= 20 &&
        tier.index >= EnemyTier.sentinel.index &&
        _rng.nextDouble() < _eliteChance(currentWave);
    final eliteAffix = isElite
        ? rollEliteAffixForWave(currentWave, _rng)
        : null;
    final eliteMultiplier = isElite ? 2.2 : 1.0;

    final baseHp =
        tierBaseHp(tier) *
        CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
        eliteMultiplier *
        (currentMutator == SurvivalWaveMutator.fortified ? 1.12 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 0.88 : 1.0);
    final baseSpeed =
        tierBaseSpeed(tier) *
        CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
        (isElite ? 1.15 : 1.0) *
        (currentMutator == SurvivalWaveMutator.hunterSwarm ? 1.10 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 1.10 : 1.0) *
        (eliteAffix == EliteAffix.relentless ? 1.05 : 1.0) *
        (eliteAffix == EliteAffix.overclocked ? 1.18 : 1.0);
    final baseDamage =
        tierBaseDamage(tier) *
        CosmicSurvivalBalance.enemyWaveDamageScale(currentWave) *
        (isElite ? 1.5 : 1.0) *
        (currentMutator == SurvivalWaveMutator.orbSiege ? 1.08 : 1.0) *
        (currentMutator == SurvivalWaveMutator.shatteredSpace ? 1.10 : 1.0) *
        (eliteAffix == EliteAffix.vampiric ? 1.10 : 1.0);
    // (The old body-locked summoner/splitter roll lived here. It only ever
    // fired on sentinel/phantom and brute/colossus respectively, which is the
    // unreachable-combination problem; _traitForWave replaces it and is rolled
    // above, independent of tier.)

    // Stats split along the two axes the variant conflated. A trait says what
    // the enemy DOES (and costs HP/damage accordingly); a conduct says how it
    // closes (and costs speed). The old single table had to invent a row per
    // combination, which is why breaker and crusher each needed one.
    final traitHp = switch (trait) {
      EnemyTrait.breaker => 1.22,
      EnemyTrait.summoner => 1.15,
      EnemyTrait.splitter => 1.05,
      null => 1.0,
    };
    final conductHp = switch (conduct) {
      EnemyConduct.charge => hasHeavyBody(tier) ? 1.38 : 1.0,
      EnemyConduct.standoff => 0.92,
      EnemyConduct.stalk => 0.88,
      _ => 1.0,
    };
    final variantHpMult = traitHp * conductHp;

    final traitSpeed = switch (trait) {
      EnemyTrait.breaker => 0.84,
      EnemyTrait.summoner => 0.78,
      EnemyTrait.splitter => 0.82,
      null => 1.0,
    };
    final conductSpeed = switch (conduct) {
      EnemyConduct.charge => hasHeavyBody(tier) ? 0.76 : 1.0,
      EnemyConduct.standoff => 0.95,
      EnemyConduct.stalk => 1.22,
      _ => 1.0,
    };
    final variantSpeedMult = traitSpeed * conductSpeed;

    final traitDamage = switch (trait) {
      EnemyTrait.breaker => 1.2,
      EnemyTrait.summoner => 1.0,
      EnemyTrait.splitter => 1.18,
      null => 1.0,
    };
    final conductDamage = switch (conduct) {
      EnemyConduct.charge => hasHeavyBody(tier) ? 1.26 : 1.0,
      EnemyConduct.standoff => 1.16,
      EnemyConduct.stalk => 1.10,
      _ => 1.0,
    };
    final variantDamageMult = traitDamage * conductDamage;

    // Archetype shaping. Artillery is a fragile thing that has to be reached;
    // a broodmother is a wall that keeps producing until it is cut out.
    final archetypeHpMult = wantsArtillery
        ? 0.85
        : wantsBrood
        ? 2.2
        : hordeBody
        ? 0.65
        : 1.0;
    final archetypeSpeedMult = wantsArtillery
        ? 0.7
        : wantsBrood
        ? 0.5
        : hordeBody
        ? CosmicSurvivalBalance.hordeBodySpeedMultiplier
        : 1.0;
    return CosmicSurvivalEnemy(
      position: pos,
      angle: angle + pi,
      hp: baseHp * variantHpMult * archetypeHpMult,
      maxHp: baseHp * variantHpMult * archetypeHpMult,
      speed: baseSpeed * variantSpeedMult * archetypeSpeedMult,
      damage: baseDamage * variantDamageMult * (hordeBody ? 0.55 : 1),
      radius: tierRadius(tier) * (isElite ? 1.3 : 1.0),
      tier: tier,
      element: element,
      conduct: conduct,
      trait: trait,
      target: _initialTargetFor(conduct),
      isElite: isElite,
      eliteAffix: eliteAffix,
      summonCooldown: trait == EnemyTrait.summoner
          ? 5.0 + _rng.nextDouble() * 2.0
          : 0,
    );
  }

  /// Spawn the small swarm a summoner produces. Returned enemies should be
  /// appended to the game's main enemy list.
  List<CosmicSurvivalEnemy> spawnSummonerWisps(
    CosmicSurvivalEnemy parent, {
    int? count,
  }) {
    final out = <CosmicSurvivalEnemy>[];
    final addCount = count ?? (2 + _rng.nextInt(2));
    for (var i = 0; i < addCount; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final dist = parent.radius + 14.0;
      final pos = Offset(
        parent.position.dx + cos(angle) * dist,
        parent.position.dy + sin(angle) * dist,
      );
      const tier = EnemyTier.wisp;
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
          0.85;
      out.add(
        CosmicSurvivalEnemy(
          position: pos,
          angle: angle,
          hp: hp,
          maxHp: hp,
          speed:
              tierBaseSpeed(tier) *
              CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
              1.1,
          damage:
              tierBaseDamage(tier) *
              CosmicSurvivalBalance.enemyWaveDamageScale(currentWave),
          radius: tierRadius(tier),
          tier: tier,
          element: parent.element,
          conduct: EnemyConduct.charge,
          target: CosmicEnemyTarget.orb,
        ),
      );
    }
    return out;
  }

  /// Spawn the fast pouncer adds a splitter releases when it dies.
  List<CosmicSurvivalEnemy> spawnSplitterShards(CosmicSurvivalEnemy parent) {
    final out = <CosmicSurvivalEnemy>[];
    final shardCount = parent.tier == EnemyTier.colossus ? 4 : 3;
    final tier = parent.tier == EnemyTier.colossus
        ? EnemyTier.drone
        : EnemyTier.drone;
    for (var i = 0; i < shardCount; i++) {
      final angle = (i / shardCount) * 2 * pi + _rng.nextDouble() * 0.2;
      final dist = parent.radius + 6.0;
      final pos = Offset(
        parent.position.dx + cos(angle) * dist,
        parent.position.dy + sin(angle) * dist,
      );
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave) *
          0.65;
      out.add(
        CosmicSurvivalEnemy(
          position: pos,
          angle: angle,
          hp: hp,
          maxHp: hp,
          speed:
              tierBaseSpeed(tier) *
              CosmicSurvivalBalance.enemyWaveSpeedScale(currentWave) *
              1.35,
          damage:
              tierBaseDamage(tier) *
              CosmicSurvivalBalance.enemyWaveDamageScale(currentWave) *
              1.10,
          radius: tierRadius(tier) * 0.95,
          tier: tier,
          element: parent.element,
          conduct: EnemyConduct.stalk,
          target: CosmicEnemyTarget.orb,
        ),
      );
    }
    return out;
  }

  /// The wave's shape as a conduct distribution — this IS the wave pattern
  /// filtering over the taxonomy. It used to yield a `role`, a second
  /// vocabulary for the same idea.
  EnemyConduct _conductForWave(int wave, EnemyTier tier) {
    if (currentMutator == SurvivalWaveMutator.hunterSwarm) {
      return _rng.nextDouble() < 0.65
          ? EnemyConduct.stalk
          : EnemyConduct.charge;
    }
    if (currentMutator == SurvivalWaveMutator.arcStorm &&
        _rng.nextDouble() < 0.55) {
      return EnemyConduct.standoff;
    }
    if (currentMutator == SurvivalWaveMutator.shatteredSpace &&
        _rng.nextDouble() < 0.34) {
      return _rng.nextBool() ? EnemyConduct.stalk : EnemyConduct.standoff;
    }
    switch (currentPattern) {
      case SurvivalWavePattern.wispHorde:
        return _rng.nextDouble() < 0.75
            ? EnemyConduct.charge
            : EnemyConduct.orbit;
      case SurvivalWavePattern.hunterPack:
        final roll = _rng.nextDouble();
        if (roll < 0.56) return EnemyConduct.stalk;
        if (roll < 0.84) return EnemyConduct.charge;
        return EnemyConduct.orbit;
      case SurvivalWavePattern.siegePush:
        if (tier.index >= EnemyTier.sentinel.index &&
            _rng.nextDouble() < 0.42) {
          return EnemyConduct.orbit;
        }
        return EnemyConduct.charge;
      case SurvivalWavePattern.shooterScreen:
        final roll = _rng.nextDouble();
        if (roll < 0.48) return EnemyConduct.standoff;
        if (roll < 0.78) return EnemyConduct.orbit;
        return EnemyConduct.charge;
      case SurvivalWavePattern.swarmRush:
        final roll = _rng.nextDouble();
        if (roll < 0.58) return EnemyConduct.charge;
        if (roll < 0.92) return EnemyConduct.orbit;
        return EnemyConduct.stalk;
      case SurvivalWavePattern.mixed:
        break;
    }

    final roll = _rng.nextDouble();
    if (wave >= 12 && tier.index >= EnemyTier.drone.index && roll < 0.14) {
      return EnemyConduct.standoff;
    }
    if (wave >= 10 && roll < 0.28) return EnemyConduct.stalk;
    if (roll < 0.62) return EnemyConduct.orbit;
    return EnemyConduct.charge;
  }

  /// What an enemy goes for first, from its conduct. Target stays mode-aware
  /// (survival has an orb to defend; the open world does not) — see
  /// docs/enemy_taxonomy.md §5.
  CosmicEnemyTarget _initialTargetFor(EnemyConduct conduct) {
    return switch (conduct) {
      EnemyConduct.standoff => CosmicEnemyTarget.companion,
      EnemyConduct.stalk => CosmicEnemyTarget.ship,
      _ => CosmicEnemyTarget.orb,
    };
  }

  /// Check if wave is complete.
  void checkWaveComplete(int aliveCount, {bool bossAlive = false}) {
    if (!_waveActive) return;
    if (!_waitingForClear) return;
    if (bossAlive) return;
    if (aliveCount <= 0) {
      _waveActive = false;
      intermission = true;
      return;
    }

    if (!isBossWave && _targetCountThisWave > 0) {
      final defeated = (_spawnedThisWave - aliveCount).clamp(
        0,
        _targetCountThisWave,
      );
      final requiredDefeats = max(
        1,
        (_targetCountThisWave * earlyAdvanceKillThreshold).round(),
      );
      final allowedAlive = max(
        3,
        (_targetCountThisWave * (1 - earlyAdvanceKillThreshold)).ceil(),
      );
      if (defeated >= requiredDefeats && aliveCount <= allowedAlive) {
        _waveActive = false;
        intermission = true;
      }
      return;
    }

    _waveActive = false;
    intermission = true;
  }

  void markBossSpawned() {
    bossSpawned = true;
  }

  void resumeAfterIntermission() {
    _advanceWave();
  }

  static String bossDisciplineLabel(SurvivalBossDiscipline discipline) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => 'Artillery',
      SurvivalBossDiscipline.trickster => 'Trickster',
      SurvivalBossDiscipline.duelist => 'Duelist',
      SurvivalBossDiscipline.conductor => 'Conductor',
      SurvivalBossDiscipline.siegebreaker => 'Siegebreaker',
      SurvivalBossDiscipline.riftcaller => 'Riftcaller',
      SurvivalBossDiscipline.standard => 'Vanguard',
    };
  }

  static String bossDisciplineSummary(SurvivalBossDiscipline discipline) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => 'Long-range salvos and lane denial.',
      SurvivalBossDiscipline.trickster => 'Blink dives with flanking pouncers.',
      SurvivalBossDiscipline.duelist =>
        'High-tempo hunter pressure on your backline.',
      SurvivalBossDiscipline.conductor => 'Orb siege with rotating escorts.',
      SurvivalBossDiscipline.siegebreaker =>
        'Heavy crushers forcing the orb line.',
      SurvivalBossDiscipline.riftcaller =>
        'Portal volleys and crossfire screens.',
      SurvivalBossDiscipline.standard =>
        'Classic boss patterns with light support.',
    };
  }

  List<BossType> _preferredBossTypesForDiscipline(
    SurvivalBossDiscipline discipline,
  ) {
    return switch (discipline) {
      SurvivalBossDiscipline.artillery => const [
        BossType.gunner,
        BossType.warden,
      ],
      SurvivalBossDiscipline.trickster => const [
        BossType.skirmisher,
        BossType.charger,
      ],
      SurvivalBossDiscipline.duelist => const [
        BossType.skirmisher,
        BossType.charger,
      ],
      SurvivalBossDiscipline.conductor => const [
        BossType.carrier,
        BossType.warden,
      ],
      SurvivalBossDiscipline.siegebreaker => const [
        BossType.bulwark,
        BossType.charger,
      ],
      SurvivalBossDiscipline.riftcaller => const [
        BossType.warden,
        BossType.gunner,
      ],
      SurvivalBossDiscipline.standard => const [
        BossType.charger,
        BossType.gunner,
        BossType.warden,
      ],
    };
  }

  void _rememberBossTemplate(BossTemplate template) {
    _recentBossNames.add(template.name);
    if (_recentBossNames.length > 3) {
      _recentBossNames.removeAt(0);
    }
    _recentBossElements.add(template.element);
    if (_recentBossElements.length > 2) {
      _recentBossElements.removeAt(0);
    }
  }

  BossTemplate _pickBossTemplateForWave(
    int wave,
    SurvivalBossDiscipline discipline,
  ) {
    final forceTitanic = wave % 25 == 0;
    var pool = kBossTemplates
        .where((t) => forceTitanic ? t.isTitanic : !t.isTitanic)
        .toList();
    if (pool.isEmpty) {
      pool = List<BossTemplate>.of(kBossTemplates);
    }

    final preferredTypes = _preferredBossTypesForDiscipline(discipline);
    var candidates = pool
        .where(
          (t) =>
              t.preferredType == null ||
              preferredTypes.contains(t.preferredType),
        )
        .toList();
    if (candidates.isEmpty) candidates = pool;

    final freshNames = candidates
        .where((t) => !_recentBossNames.contains(t.name))
        .toList();
    if (freshNames.isNotEmpty) {
      candidates = freshNames;
    }

    final freshElements = candidates
        .where((t) => !_recentBossElements.contains(t.element))
        .toList();
    if (freshElements.isNotEmpty) {
      candidates = freshElements;
    }

    final template = candidates[_rng.nextInt(candidates.length)];
    _rememberBossTemplate(template);
    return template;
  }

  double _survivalBossRadius(BossTemplate template) {
    if (template.isTitanic) {
      // Titanic templates were 150 at 0.64; they shrank to 120 for open space
      // and this keeps survival's titans the size they were (96).
      return (template.radius * 0.8).clamp(84.0, 104.0);
    }
    return (template.radius * 0.9).clamp(24.0, 46.0);
  }

  /// Create a boss for a boss wave.
  SurvivalBoss? createBossForWave(int wave, Offset spawnPos) {
    if (kBossTemplates.isEmpty) return null;
    final bossLevel = (wave ~/ 5).clamp(1, 20);
    final discipline = switch (wave) {
      >= 35 when wave % 35 == 0 => SurvivalBossDiscipline.riftcaller,
      >= 30 when wave % 30 == 0 => SurvivalBossDiscipline.siegebreaker,
      >= 25 when wave % 25 == 0 => SurvivalBossDiscipline.conductor,
      >= 20 when wave % 20 == 0 => SurvivalBossDiscipline.duelist,
      >= 15 when wave % 15 == 0 => SurvivalBossDiscipline.trickster,
      >= 10 when wave % 10 == 0 => SurvivalBossDiscipline.artillery,
      _ => SurvivalBossDiscipline.standard,
    };
    final template = _pickBossTemplateForWave(wave, discipline);
    final hp = CosmicSurvivalBalance.bossHealthForWave(
      wave,
      titanic: template.isTitanic,
    );
    final speedScale =
        (1.0 + (bossLevel - 1) * 0.04) *
        (template.isTitanic ? 0.84 : 1.0) *
        (wave == 5 ? 1.15 : 1.0);
    final speed = (template.speed * speedScale).clamp(45.0, double.infinity);
    final type = template.preferredType ?? bossTypeForLevel(bossLevel);
    final movement = _pickBossMovementStyle(type, discipline);
    final engagement = _engagementRangeFor(movement);
    final strafe = _strafeWeightFor(movement);

    return SurvivalBoss(
      template: template,
      type: type,
      discipline: discipline,
      level: bossLevel,
      position: spawnPos,
      hp: hp,
      maxHp: hp,
      speed: speed,
      baseSpeed: speed,
      radius: _survivalBossRadius(template),
      color: elementColor(template.element),
      movementStyle: movement,
      engagementRange: engagement,
      strafeWeight: strafe,
    );
  }

  /// Pick how the boss prefers to move. Snipers/artillery sit back, brawlers
  /// chase, and a few archetypes patrol a mid-distance ring.
  SurvivalBossMovementStyle _pickBossMovementStyle(
    BossType type,
    SurvivalBossDiscipline discipline,
  ) {
    // Discipline overrides come first — they describe the wave-themed boss.
    switch (discipline) {
      case SurvivalBossDiscipline.artillery:
      case SurvivalBossDiscipline.riftcaller:
        return SurvivalBossMovementStyle.sniper;
      case SurvivalBossDiscipline.conductor:
      case SurvivalBossDiscipline.trickster:
        return SurvivalBossMovementStyle.orbit;
      case SurvivalBossDiscipline.duelist:
      case SurvivalBossDiscipline.siegebreaker:
        return SurvivalBossMovementStyle.chase;
      case SurvivalBossDiscipline.standard:
        // Fall through to per-type tuning.
        break;
    }
    switch (type) {
      case BossType.gunner:
        // 70% sniper, 30% orbit — keeps gunner fights feeling like artillery
        // bombardment from a distance rather than tight melee.
        return _rng.nextDouble() < 0.70
            ? SurvivalBossMovementStyle.sniper
            : SurvivalBossMovementStyle.orbit;
      case BossType.bulwark:
        return SurvivalBossMovementStyle.orbit;
      case BossType.warden:
        // Warden summons and shoots — keep it mid-far rather than in your face.
        return _rng.nextDouble() < 0.55
            ? SurvivalBossMovementStyle.orbit
            : SurvivalBossMovementStyle.sniper;
      case BossType.carrier:
        // Carrier escorts adds toward the orb but doesn't need to brawl.
        return SurvivalBossMovementStyle.orbit;
      case BossType.charger:
      case BossType.skirmisher:
        return SurvivalBossMovementStyle.chase;
    }
  }

  /// Test hooks for the boss-reachability guards.
  @visibleForTesting
  double engagementRangeForTest(SurvivalBossMovementStyle s) =>
      _engagementRangeFor(s);

  @visibleForTesting
  double strafeWeightForTest(SurvivalBossMovementStyle s) =>
      _strafeWeightFor(s);

  double _engagementRangeFor(SurvivalBossMovementStyle style) {
    // Snipers/orbiters get a randomized ring distance so two bosses on the
    // same wave don't stack on the exact same circle.
    switch (style) {
      case SurvivalBossMovementStyle.sniper:
        // Was 620-760, over half the arena radius (~1140): reaching one was a
        // trek, and it backed away the whole time. Still clearly "ranged", but
        // now on screen with you.
        return 430.0 + _rng.nextDouble() * 90.0;
      case SurvivalBossMovementStyle.orbit:
        return 360.0 + _rng.nextDouble() * 90.0;
      case SurvivalBossMovementStyle.chase:
        return 180.0 + _rng.nextDouble() * 40.0;
    }
  }

  double _strafeWeightFor(SurvivalBossMovementStyle style) {
    switch (style) {
      case SurvivalBossMovementStyle.sniper:
        // Was 0.18 — so it barely circled and mostly just reversed in a
        // straight line. Strafing keeps the distance without the retreat
        // reading as flight.
        return 0.55;
      case SurvivalBossMovementStyle.orbit:
        return 0.70;
      case SurvivalBossMovementStyle.chase:
        return 1.0;
    }
  }

  /// Spawn escort adds for carrier/warden bosses.
  List<CosmicSurvivalEnemy> spawnBossAdds(
    SurvivalBoss boss,
    Offset orbPos,
    double viewW,
    double viewH,
  ) {
    final adds = <CosmicSurvivalEnemy>[];
    final count = switch (boss.discipline) {
      SurvivalBossDiscipline.artillery => 2 + (boss.level >= 10 ? 1 : 0),
      SurvivalBossDiscipline.duelist => 2 + (boss.level >= 12 ? 1 : 0),
      SurvivalBossDiscipline.siegebreaker => 3 + (boss.level ~/ 5).clamp(0, 2),
      SurvivalBossDiscipline.trickster => 3 + (boss.level ~/ 4).clamp(0, 3),
      SurvivalBossDiscipline.conductor => 4 + (boss.level ~/ 4).clamp(0, 3),
      SurvivalBossDiscipline.riftcaller => 4 + (boss.level ~/ 4).clamp(0, 4),
      SurvivalBossDiscipline.standard => 3 + (boss.level ~/ 2).clamp(0, 5),
    };
    for (var i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * pi;
      final offset = Offset(
        cos(angle) * boss.radius * 2,
        sin(angle) * boss.radius * 2,
      );
      final pos = boss.position + offset;
      final tier = switch (boss.discipline) {
        SurvivalBossDiscipline.artillery =>
          (i == 0 && boss.level >= 10) ? EnemyTier.phantom : EnemyTier.sentinel,
        SurvivalBossDiscipline.duelist =>
          (i == 0 || boss.level >= 12) ? EnemyTier.phantom : EnemyTier.drone,
        SurvivalBossDiscipline.siegebreaker =>
          (i == 0 || boss.level >= 10) ? EnemyTier.brute : EnemyTier.sentinel,
        SurvivalBossDiscipline.trickster =>
          (i == 0 || boss.level >= 10) ? EnemyTier.phantom : EnemyTier.drone,
        SurvivalBossDiscipline.riftcaller =>
          i == 0 ? EnemyTier.phantom : EnemyTier.sentinel,
        SurvivalBossDiscipline.conductor =>
          (i % 3 == 0 && boss.level >= 10)
              ? EnemyTier.sentinel
              : EnemyTier.drone,
        _ => boss.level >= 10 ? EnemyTier.sentinel : EnemyTier.drone,
      };
      // Each discipline fields a pair of conducts, alternating across the
      // adds, plus an optional trait. One vocabulary — this used to pick a
      // role and then translate it.
      final (conduct, trait) = switch (boss.discipline) {
        SurvivalBossDiscipline.artillery => (
          i == 0 ? EnemyConduct.standoff : EnemyConduct.orbit,
          null,
        ),
        SurvivalBossDiscipline.duelist => (EnemyConduct.stalk, null),
        SurvivalBossDiscipline.siegebreaker =>
          i.isEven
              ? (EnemyConduct.charge, null)
              : (EnemyConduct.orbit, EnemyTrait.breaker),
        SurvivalBossDiscipline.trickster => (EnemyConduct.stalk, null),
        SurvivalBossDiscipline.riftcaller => (
          i.isEven ? EnemyConduct.standoff : EnemyConduct.orbit,
          null,
        ),
        SurvivalBossDiscipline.conductor =>
          i.isEven
              ? (EnemyConduct.orbit, EnemyTrait.breaker)
              : (EnemyConduct.charge, null),
        _ => (EnemyConduct.charge, null),
      };
      final hp =
          tierBaseHp(tier) *
          CosmicSurvivalBalance.enemyWaveHpScale(currentWave);
      // Same split as the wave spawner: trait says what it does, conduct says
      // how it closes.
      final heavy = hasHeavyBody(tier);
      final variantHpMult =
          (switch (trait) {
            EnemyTrait.breaker => 1.22,
            EnemyTrait.summoner => 1.15,
            EnemyTrait.splitter => 1.05,
            null => 1.0,
          }) *
          (switch (conduct) {
            EnemyConduct.charge => heavy ? 1.38 : 1.0,
            EnemyConduct.standoff => 0.92,
            EnemyConduct.stalk => 0.88,
            _ => 1.0,
          });
      final variantSpeedMult =
          (switch (trait) {
            EnemyTrait.breaker => 0.84,
            EnemyTrait.summoner => 0.78,
            EnemyTrait.splitter => 0.82,
            null => 1.0,
          }) *
          (switch (conduct) {
            EnemyConduct.charge => heavy ? 0.76 : 1.0,
            EnemyConduct.standoff => 0.95,
            EnemyConduct.stalk => 1.22,
            _ => 1.0,
          });
      final variantDamageMult =
          (switch (trait) {
            EnemyTrait.breaker => 1.2,
            EnemyTrait.summoner => 1.0,
            EnemyTrait.splitter => 1.18,
            null => 1.0,
          }) *
          (switch (conduct) {
            EnemyConduct.charge => heavy ? 1.26 : 1.0,
            EnemyConduct.standoff => 1.16,
            EnemyConduct.stalk => 1.10,
            _ => 1.0,
          });
      adds.add(
        CosmicSurvivalEnemy(
          position: pos,
          hp: hp * variantHpMult,
          maxHp: hp * variantHpMult,
          speed: tierBaseSpeed(tier) * variantSpeedMult,
          damage: tierBaseDamage(tier) * variantDamageMult,
          radius: tierRadius(tier),
          tier: tier,
          element: boss.template.element,
          conduct: conduct,
          trait: trait,
          target: switch (conduct) {
            EnemyConduct.standoff
                when boss.discipline == SurvivalBossDiscipline.artillery ||
                    boss.discipline == SurvivalBossDiscipline.riftcaller =>
              CosmicEnemyTarget.orb,
            EnemyConduct.stalk
                when boss.discipline == SurvivalBossDiscipline.duelist =>
              CosmicEnemyTarget.companion,
            EnemyConduct.charge
                when boss.discipline == SurvivalBossDiscipline.siegebreaker =>
              CosmicEnemyTarget.orb,
            EnemyConduct.standoff => CosmicEnemyTarget.companion,
            EnemyConduct.stalk => CosmicEnemyTarget.ship,
            _ => CosmicEnemyTarget.orb,
          },
        ),
      );
    }
    return adds;
  }

  static double _eliteChance(int wave) {
    if (wave < 20) return 0;
    return ((wave - 20) * 0.010 + 0.05).clamp(0.0, 0.22);
  }

  static List<EliteAffix> eliteAffixPoolForWave(int wave) {
    if (wave < 14) return const [];
    if (wave < 22) {
      return const [EliteAffix.bulwarked, EliteAffix.overclocked];
    }
    if (wave < 30) {
      return const [
        EliteAffix.bulwarked,
        EliteAffix.volatile,
        EliteAffix.overclocked,
      ];
    }
    if (wave < 38) {
      return const [
        EliteAffix.bulwarked,
        EliteAffix.volatile,
        EliteAffix.vampiric,
        EliteAffix.overclocked,
      ];
    }
    return List<EliteAffix>.of(EliteAffix.values);
  }

  static EliteAffix? rollEliteAffixForWave(int wave, Random rng) {
    final pool = eliteAffixPoolForWave(wave);
    if (pool.isEmpty) return null;
    return pool[rng.nextInt(pool.length)];
  }

  static String? mutatorLabel(SurvivalWaveMutator? mutator) {
    return switch (mutator) {
      SurvivalWaveMutator.orbSiege => 'ORB SIEGE',
      SurvivalWaveMutator.hunterSwarm => 'HUNTER SWARM',
      SurvivalWaveMutator.arcStorm => 'ARC STORM',
      SurvivalWaveMutator.fortified => 'FORTIFIED',
      SurvivalWaveMutator.shatteredSpace => 'SHATTERED SPACE',
      SurvivalWaveMutator.manaFlux => 'MANA FLUX',
      null => null,
    };
  }

  static String? mutatorDescription(SurvivalWaveMutator? mutator) {
    return switch (mutator) {
      SurvivalWaveMutator.orbSiege =>
        'Heavier orb pressure and sturdier assault lines.',
      SurvivalWaveMutator.hunterSwarm =>
        'Fast hunter packs collapse on ship and companions.',
      SurvivalWaveMutator.arcStorm =>
        'Shooter density rises and projectile pressure intensifies.',
      SurvivalWaveMutator.fortified =>
        'Heavier enemy tiers and stronger elite fronts.',
      SurvivalWaveMutator.shatteredSpace =>
        'Enemies break faster but surge in quicker, deadlier bursts.',
      SurvivalWaveMutator.manaFlux =>
        'Alchemical flow surges and build momentum accelerates.',
      null => null,
    };
  }
}
