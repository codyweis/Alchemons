// lib/games/cosmic_survival/cosmic_survival_game.dart
//
// COSMIC SURVIVAL FLAME GAME — REDESIGNED
// Uses the same companion abilities, enemy visuals, ship rendering,
// and boss AI as the main cosmic exploration game.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/games/shared/type_effectiveness.dart';
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
  int slotIndex;
  Offset position;
  Offset anchor;
  int maxHp;
  int currentHp;
  int physAtk;
  int elemAtk;
  int physDef;
  int elemDef;
  double cooldownReduction;
  double critChance;
  double attackRange;
  double specialAbilityRange;
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
  // Pip+Spirit: while > 0, the empower window grants ~10× attack speed.
  double pipSpiritEmpowerTimer;
  // Pip+Steam: a perpetual cycling timer — attack speed ramps from
  // +50% to +300% across each window, then vents and restarts.
  double pipSteamWindowTimer;
  double invincibleTimer;
  double doubleCastTimer;
  Offset? doubleCastTargetPos;
  double doubleCastAngle;
  // Sticky target — reduces frame-to-frame target switching jitter
  CosmicSurvivalEnemy? stickyTarget;
  double stickyTargetLockTimer;
  Offset steeringVelocity;
  // Persistent ability state, keyed by family-specific semantics:
  //   pip+spirit  → kills accumulate; threshold triggers basic-haste empower
  //   mask+spirit → kills accumulate; threshold triggers AOE wisp burst
  //   (other families/elements may reuse this slot in future passives)
  int abilityKillStacks;
  // Active companion-side damage amp (e.g. Mask+Ice pillar broadcasting).
  double damageAmpTimer;
  double damageAmpMultiplier;
  // Mask+Spirit special: ship-collected wisp count. Distinct from
  // `abilityKillStacks` (which counts auto-kills for the passive AOE).
  // Threshold reached → fires the non-boss nuke and resets to 0.
  int maskSpiritWispBank;

  // ── Kin support-path runtime state ─────────────────────────────
  // Kin+Fire: when > 0, the phoenix guard is active — orb death is
  // intercepted and restored. Set on cast; cleared on use or expiry.
  double kinFirePhoenixGuardTimer = 0;
  // Kin+Fire: post-phoenix orbital flame. Once activated by the
  // phoenix save it stays on PERMANENTLY for the remainder of the
  // fire kin's life — a one-shot passive that unlocks an offensive
  // aura. Timer field kept for back-compat in case anything still
  // references it, but the active flag is the source of truth.
  bool kinFireOrbitalFlameActive = false;
  double kinFireOrbitalFlameTimer = 0;
  // Kin+Lava: when > 0, ship/companion damage taken triggers a
  // splash of lava damaging nearby enemies (reactive plate armor).
  double kinLavaPlateTimer = 0;
  // Kin+Ice: charge windup → release radial frost. Charge timer
  // ticks down; on hitting 0 the release fires.
  double kinIceChargeTimer = 0;
  double kinIceChargeTotal = 0; // for visual progress
  // Kin+Steam boiler: damage→AS stacks. Buff window + decay timer.
  double kinSteamBoilerTimer = 0;
  int kinSteamBoilerStacks = 0;
  double kinSteamStackDecayTimer = 0;
  // Kin+Lightning: while > 0, the kin is actively channelling and
  // all allies' auto-attacks chain to nearby enemies.
  double kinLightningChargeTimer = 0;
  // Kin+Dark: while > 0, ALL companions become untargetable to enemies.
  // Stored on the casting Dark kin; enemy targeting reads from any
  // active Dark kin's timer.
  double kinDarkCloakTimer = 0;
  // Kin+Blood: while > 0, % of damage taken by any alchemon is
  // shared as healing across the other living alchemons.
  double kinBloodPactTimer = 0;
  // Kin+Mud: ship enchant timer. The ship leaves a slowing mud trail
  // while this timer is > 0 on any Mud-kin caster.
  double kinMudShipEnchantTimer = 0;
  // Kin+Spirit wisp companion state. Wisp lives separately, tracked
  // via a synthetic projectile in the world list — these fields just
  // count auto-kills to feed it and prevent duplicate spawns.
  int kinSpiritWispKills = 0;
  // HP snapshots for per-frame damage interception (Lava plate /
  // Steam boiler / Blood pact). Updated each frame by the support
  // tick; delta vs current HP is the damage taken that frame.
  int kinPrevHp = 0;
  // Kin auto-attack charge: ticks up from 0 to 1.5s, then fires a
  // thin laser beam. While > 0, the kin holds position and shows a
  // building-energy visual.
  double kinAutoChargeTimer = 0;
  // Cached target position for the laser at the moment charge began
  // (used as a fallback if the locked enemy dies/despawns mid-charge).
  Offset? kinAutoChargeTarget;
  // Locked enemy reference at charge start — beam tracks this enemy's
  // current position at fire time so movement during the 1.5s charge
  // doesn't cause misses.
  CosmicSurvivalEnemy? kinAutoChargeEnemy;
  // Pip+Poison: position of the last special-ability dart hit. The next
  // special-dart hit draws a poison-line zone connecting last to current.
  // Reset when the special is cast again so each cast starts a fresh web.
  Offset? lastPipPoisonHitPos;
  // Horn charges: projectiles deferred to the impact-point so the
  // burst happens where the ram lands, not where it started.
  List<Projectile>? pendingChargeBurst;
  Offset? pendingChargeOrigin;
  double pendingChargeAngle = 0;
  // Horn passive timers — per-element ticks for Air blow-back, Mud
  // sludge trail, and Poison toxic aura. These are passive-only
  // abilities (no active cast) so the effect runs every frame on the
  // companion update loop.
  double hornMudTrailTimer = 0;
  double hornPoisonAuraTimer = 0;
  // Throttles the outward wind-particle spawn for Horn+Air's
  // blow-back visualization (~12 particles/sec/horn).
  double hornAirParticleTimer = 0;
  // Horn wind-up phase (Dark void-suck / Crystal orbit / Spirit
  // phantom-swarm). While windUpTimer > 0 the companion holds still,
  // an element-specific visual plays around it, and Dark pulls
  // enemies inward each frame. When the timer hits 0 the dash
  // kicks off toward `windUpDashTarget` using the stored fireAngle.
  double windUpTimer = 0;
  String windUpElement = '';
  Offset? windUpDashTarget;
  double windUpFireAngle = 0;
  double hornDarkPullTimer = 0;
  // Stored at cast so wind-up kick-off can re-derive the dash params
  // even when the attack target's distance has changed during wind-up.
  double pendingChargeTimerValue = 0;
  // Horn+Water: circular charge path. While `chargePathType == 'circle'`,
  // the charge-state movement loop sweeps the horn around chargeCircleCenter
  // at chargeCircleAngularSpeed rad/s instead of dashing straight.
  String chargePathType = '';
  Offset? chargeCircleCenter;
  double chargeCircleRadius = 0;
  double chargeCircleAngle = 0;
  double chargeCircleAngularSpeed = 0;
  // Horn+Ice: paints an ice wall segment-by-segment while dashing
  // sideways. Timer ticks down each frame; when ≤ 0 a new segment
  // spawns at the horn's current position and the timer resets.
  double iceWallTrailTimer = 0;
  // Horn special "active window" — set on cast and ticks down each
  // frame. While > 0, kills routed back to this slot trigger
  // per-element kill effects (Steam cooldown reset, Lava homing
  // flames, Blood heal, Lightning absorb-then-blast credit).
  double hornSpecialActiveWindow = 0;
  // Horn+Lightning: damage absorbed during the charge window. Drives
  // the chain-shockwave magnitude released at the impact tick.
  double hornLightningAbsorbed = 0;
  // Horn+Dark: enemies captured during the void wind-up. Teleported
  // along with the horn to the dash destination on impact.
  List<CosmicSurvivalEnemy>? hornDarkCaptured;
  // Horn+Lightning: post-dash storm-brewing wind-up. After the dash
  // lands the wing brews a thunderstorm for a few seconds (absorbing
  // any further hits) before discharging the chain blast.
  double hornPostDashWindUpTimer = 0;

  static const double baseSpecialCooldown = 12.5;
  static const double baseBasicCooldown = 1.5;
  static const double chargeSpeed = 400.0;
  // Pip+Steam: length of one full +50%→+300% attack-speed ramp cycle.
  static const double pipSteamWindowDuration = 9.0;

  CosmicSurvivalCompanion({
    required this.member,
    this.slotIndex = -1,
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
    this.pipSpiritEmpowerTimer = 0,
    this.pipSteamWindowTimer = 0,
    this.invincibleTimer = 2.0,
    this.doubleCastTimer = 0,
    this.doubleCastTargetPos,
    this.doubleCastAngle = 0,
    this.stickyTargetLockTimer = 0,
    this.steeringVelocity = Offset.zero,
    this.abilityKillStacks = 0,
    this.damageAmpTimer = 0,
    this.damageAmpMultiplier = 1.0,
    this.maskSpiritWispBank = 0,
    this.lastPipPoisonHitPos,
  }) : currentHp = currentHp ?? maxHp;

  double get damageAmp =>
      damageAmpTimer > 0 ? damageAmpMultiplier.clamp(1.0, 4.0) : 1.0;

  double get hpPercent =>
      maxHp > 0 ? (currentHp / maxHp).clamp(0, 1).toDouble() : 0;

  double get effectiveBasicCooldown {
    final base = baseBasicCooldown / cooldownReduction;
    final factor = (1.0 + (physAtk - 1) * 0.05).clamp(0.5, 3.0);
    final familyMultiplier = switch (member.family.toLowerCase()) {
      'let' => 1.12,
      'pip' => 0.90,
      'horn' => 1.12,
      'mask' => 1.10,
      'wing' => 0.90,
      _ => 1.0,
    };
    // Family/element basic-cooldown passives.
    //   Wing+Dark: auto-attack and laser pulse 2× as fast.
    final familyL = member.family.toLowerCase();
    final familyElementMul = (familyL == 'wing' && member.element == 'Dark')
        ? 0.5
        : 1.0;
    // Pip element passives that drive attack speed directly. While one
    // is active it is the sole speed driver — the shared haste system
    // is ignored so these reach (and stay at) their design extremes
    // instead of overshooting them by stacking.
    var pipPassiveMul = 1.0;
    var pipPassiveDrivesSpeed = false;
    if (familyL == 'pip') {
      if (member.element == 'Spirit' && pipSpiritEmpowerTimer > 0) {
        // Empower window: ~10× attack speed.
        pipPassiveMul = 0.10;
        pipPassiveDrivesSpeed = true;
      } else if (member.element == 'Steam') {
        // Steam window ramps attack speed from +50% to +300%.
        final progress = (pipSteamWindowTimer / pipSteamWindowDuration).clamp(
          0.0,
          1.0,
        );
        pipPassiveMul = 0.667 + (0.25 - 0.667) * progress;
        pipPassiveDrivesSpeed = true;
      }
    }
    final haste = (basicHasteTimer > 0 && !pipPassiveDrivesSpeed)
        ? basicHasteMultiplier.clamp(0.45, 1.0)
        : 1.0;
    return (base / factor) *
        familyMultiplier *
        haste *
        familyElementMul *
        pipPassiveMul;
  }

  double get effectiveSpecialCooldown {
    final family = member.family.toLowerCase();
    if (family == 'mask') {
      return 22.5 *
          elementalSpecialCooldownMultiplierSurvival(
            member.family,
            member.element,
          );
    }

    final base = baseSpecialCooldown / cooldownReduction;
    final isMystic = family == 'mystic';
    // Mystics use a dedicated formula: every mystic descends *toward*
    // 60s as the relevant stat scales up, instead of starting at a
    // shared floor. Heavier elements have a larger gap to close.
    if (isMystic) {
      // statProgress: 0 at baseline, 1 once the stat that scales the
      // ability has saturated. We blend the survival-specific elemAtk
      // saturation with cooldownReduction stacking from upgrades.
      // elemAtk caps at 36 (factor saturation point); cdr above 1.0
      // counts proportionally.
      final atkProgress = (elemAtk / 36.0).clamp(0.0, 1.0);
      final cdrProgress = (cooldownReduction - 1.0).clamp(0.0, 1.0);
      final statProgress = (atkProgress + cdrProgress).clamp(0.0, 1.0);
      // Per-element "starting cooldown gap" above the 60s target. Bigger
      // gap = slower at low stats. All elements meet at 60s when
      // statProgress reaches 1.0.
      final lowStatBonus = switch (member.element) {
        'Air' || 'Dust' => 20.0,
        'Poison' || 'Mud' || 'Water' => 35.0,
        'Lightning' || 'Ice' || 'Steam' => 50.0,
        'Blood' || 'Plant' || 'Fire' => 65.0,
        'Lava' || 'Crystal' || 'Earth' => 80.0,
        'Dark' || 'Light' || 'Spirit' => 100.0,
        _ => 50.0,
      };
      // cd = 60 (max-stat target) + element-specific cushion that
      // melts away as stats / cooldown upgrades scale up.
      final cd = 60.0 + lowStatBonus * (1.0 - statProgress);
      return cd;
    }
    // Non-mystic: original formula.
    final factor = (1.0 + (elemAtk / 6.0) * 0.2).clamp(0.5, 6.0);
    final familyMultiplier = switch (family) {
      'let' => 1.18,
      'pip' => 1.18,
      'horn' => 0.85,
      _ => 1.0,
    };
    final elementMultiplier = elementalSpecialCooldownMultiplierSurvival(
      member.family,
      member.element,
    );
    // Wing+Dark passive: laser pulse 2× as fast.
    final familyElementMul = family == 'wing' && member.element == 'Dark'
        ? 0.5
        : 1.0;
    return (base / factor) *
        familyMultiplier *
        elementMultiplier *
        familyElementMul;
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

/// Per-companion combat contribution accumulated over a survival run.
class CompanionRunStats {
  double damageDealt = 0;
  int kills = 0;
  double damageTaken = 0;
  // Healing this companion is directly responsible for (blessings,
  // lifesteal, blood pact). Ambient/team-wide healing is not attributed.
  double healingDone = 0;
}

/// Run-wide healing totals split by recipient.
class RunHealingStats {
  double toMons = 0;
  double toShip = 0;
  double toOrb = 0;

  double get total => toMons + toShip + toOrb;
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

class _FlowerPickup {
  Offset position;
  double life;
  final int sourceSlotIndex;
  final double bobPhase;

  /// If > 0, collecting this flower heals all alchemons by this amount
  /// instead of bumping the source companion's `abilityKillStacks`
  /// (which is what Wing+Plant uses for its damage scaling). Set by
  /// Kin+Plant garden drops so harvested flowers actually heal.
  final double healAmount;
  _FlowerPickup({
    required this.position,
    required this.sourceSlotIndex,
    required this.bobPhase,
    this.healAmount = 0,
  }) : life = 12.0;
  bool get dead => life <= 0;
}

/// Active Mystic-environment overlay. While the entry is alive
/// (life > 0) the render pass paints an element-tinted overlay
/// across the viewport AND spawns ambient particle effects so the
/// whole battlefield reads as transformed by the ultimate. Fade-in
/// over the first ~0.6s and fade-out across the last ~1.2s keep
/// the transitions smooth.
class _MysticEnvironment {
  final String element;
  final double maxLife;
  double life;
  _MysticEnvironment({required this.element, required this.maxLife})
    : life = maxLife;
  bool get dead => life <= 0;

  /// 0 → 1 → 0 envelope: ramps up at start, holds, fades at end.
  double get envelope {
    if (maxLife <= 0) return 0;
    const fadeIn = 0.6;
    const fadeOut = 1.2;
    final elapsed = maxLife - life;
    if (elapsed < fadeIn) return (elapsed / fadeIn).clamp(0.0, 1.0).toDouble();
    if (life < fadeOut) return (life / fadeOut).clamp(0.0, 1.0).toDouble();
    return 1.0;
  }
}

/// Transient Kin auto-attack laser beam — a thin line from kin to
/// target that lingers briefly then fades. Cheap render struct.
class _KinLaserBeam {
  final Offset origin;
  final Offset end;
  final Color color;
  double life;
  static const double maxLife = 0.28;
  _KinLaserBeam({required this.origin, required this.end, required this.color})
    : life = maxLife;
  bool get dead => life <= 0;
}

class _SpiritWisp {
  Offset position;
  double life;
  final int sourceSlotIndex;
  final double damage;
  final double bobPhase;
  _SpiritWisp({
    required this.position,
    required this.sourceSlotIndex,
    required this.damage,
    required this.bobPhase,
    required this.life,
  });
  bool get dead => life <= 0;
}

class _CompanionTargetChoice {
  final Offset position;
  final CosmicSurvivalEnemy? enemy;
  final bool isBoss;

  /// Radius of the target's hitbox (boss radius for bosses, enemy radius
  /// otherwise). Drives standoff distance so companions don't park on top
  /// of huge bosses.
  final double radius;

  const _CompanionTargetChoice({
    required this.position,
    this.enemy,
    this.isBoss = false,
    this.radius = 0,
  });
}

class _ProjectileControlBuckets {
  final List<Projectile> snares = <Projectile>[];
  final List<Projectile> lures = <Projectile>[];
  final List<Projectile> decoys = <Projectile>[];
  final List<Projectile> interceptors = <Projectile>[];
  // Stationary fixtures (Ice walls, Light barrier) that reflect
  // enemy/boss projectiles instead of absorbing them.
  final List<Projectile> reflectors = <Projectile>[];

  void clear() {
    snares.clear();
    lures.clear();
    decoys.clear();
    interceptors.clear();
    reflectors.clear();
  }
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

class _ActiveWingBeam {
  final WingBeamEffect descriptor;
  final int sourceSlotIndex;
  // Mutable so the beam tracks the caster as it moves — a sustained
  // beam should stay attached to the wing, not a frozen point in space.
  Offset origin;
  double angle;
  double life;
  double tickTimer;
  double chargeTimer;
  int refractionsDone;
  // Wing+Earth: a mirror beam re-anchors to the orb instead of the
  // caster companion, so the orb fires its own laser alongside the wing.
  final bool anchorToOrb;
  // Wing+Steam: the beam executes the first enemy it touches once, then
  // behaves as a normal damage beam.
  bool steamKillUsed;

  _ActiveWingBeam({
    required this.descriptor,
    required this.sourceSlotIndex,
    required this.origin,
    required this.angle,
    this.anchorToOrb = false,
  }) : life = descriptor.duration,
       tickTimer = descriptor.tickInterval,
       chargeTimer = descriptor.chargeTime,
       refractionsDone = 0,
       steamKillUsed = false;

  bool get dead => life <= 0;
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

enum SurvivalVisualQuality { cinematic, balanced, performance }

bool shouldUseReducedCompanionProjectileRendering({
  required SurvivalVisualQuality quality,
  required Projectile projectile,
}) {
  return switch (quality) {
    SurvivalVisualQuality.cinematic => false,
    SurvivalVisualQuality.balanced => false,
    SurvivalVisualQuality.performance =>
      !preservesAuthoredCosmicAbilityVisualIdentity(projectile),
  };
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
  final SurvivalVisualQuality visualQuality;
  String? shipSkin;

  // Camera
  static const double _introZoomStart = 0.85;
  static const double _zoomOuter = 0.50;
  static const double _zoomBase = 0.595;
  static const double _zoomInner = 0.75;
  static const List<double> _zoomPresets = [_zoomOuter, _zoomBase, _zoomInner];
  int _zoomLevelIndex = 1;
  double _currentZoom = _introZoomStart;
  double _zoomAnimFrom = _introZoomStart;
  double _zoomAnimTo = _zoomBase;
  double _zoomAnimTimer = 0;
  static const double _zoomAnimDuration = 0.42;
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
  // Additional bosses spawned on multi-boss waves. Updated/rendered/targeted
  // alongside [activeBoss]. Dead entries are pruned each wave cleanup.
  final List<SurvivalBoss> extraBosses = [];
  Iterable<SurvivalBoss> get allLivingBosses sync* {
    final primary = activeBoss;
    if (primary != null && !primary.isDead) yield primary;
    for (final b in extraBosses) {
      if (!b.isDead) yield b;
    }
  }

  bool get anyBossAlive {
    final primary = activeBoss;
    if (primary != null && !primary.isDead) return true;
    for (final b in extraBosses) {
      if (!b.isDead) return true;
    }
    return false;
  }

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
  final Map<int, CompanionRunStats> companionRunStats = {};
  final RunHealingStats healingStats = RunHealingStats();
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
  double _shipMissileLauncherTimer = 0;
  double _shipRapidTurretTimer = 0;

  double alchemicalMeter = 0;
  double _alchemicalMeterDisplayFrac = 0;
  double _alchemicalProgressPoints = 0;
  int _lastIntermissionRewardWave = 0;
  static const double _baseAlchemicalMeterMax = 100;

  // Pacing is primarily kill-progress based (weighted by enemy tier), with a
  // very gentle wave clamp as a stability guard.
  double get _alchemicalKillPacingMultiplier {
    final decay = 1.0 / (1.0 + (_alchemicalProgressPoints / 180.0));
    return 0.68 + 0.47 * decay;
  }

  double get _alchemicalWaveStabilityMultiplier {
    final wave = max(1, spawner.currentWave);
    if (wave <= 3) return 1.02;
    return (1.0 - (wave - 3) * 0.004).clamp(0.88, 1.02);
  }

  double _alchemicalProgressPointsForEnemy(CosmicSurvivalEnemy enemy) {
    final points = switch (enemy.tier) {
      EnemyTier.wisp => 1.0,
      EnemyTier.drone => 1.4,
      EnemyTier.sentinel => 1.9,
      EnemyTier.phantom => 2.6,
      EnemyTier.brute => 3.4,
      EnemyTier.colossus => 4.8,
    };
    return enemy.isElite ? points * 1.25 : points;
  }

  double get alchemicalMeterMax {
    final wave = max(1, spawner.currentWave);
    final scaling = 1.0 + ((wave - 1) * 0.08).clamp(0.0, 2.4);
    return _baseAlchemicalMeterMax * scaling;
  }

  double _intermissionAlchemyGrantForWave(int wave, {required bool bossWave}) {
    if (wave <= 0) return 0;
    final base = bossWave ? 22.0 + wave * 1.25 : 8.0 + wave * 0.55;
    return base.clamp(6.0, bossWave ? 88.0 : 42.0);
  }

  void _grantIntermissionReward(int wave, {required bool bossWave}) {
    if (wave <= 0 || wave == _lastIntermissionRewardWave || ship.isDead) {
      return;
    }
    _lastIntermissionRewardWave = wave;
    final grant = _intermissionAlchemyGrantForWave(wave, bossWave: bossWave);
    if (grant > 0) {
      _grantAlchemy(grant * _alchemyMeterGainMultiplier);
    }
    if (bossWave) {
      final orbRecovery = max(10.0, orb.maxHp * 0.07);
      _healOrb(orbRecovery);
      _grantOrbShield(max(12, (orb.maxHp * 0.04).round()));
    }
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

  // Transient Kin laser beam flashes. Drawn after the ship for one
  // brief moment then garbage-collected. Tiny struct: origin, end,
  // life, color.
  final List<_KinLaserBeam> _kinLaserBeams = [];

  // Active Mystic environment overlays. Each entry tracks one cast's
  // worth of "the world is now this element" — viewport tint +
  // ambient particle storm. Multiple casts stack visually.
  final List<_MysticEnvironment> _mysticEnvironments = [];
  // Tick gate for environment particle spawning so each environment
  // doesn't flood the vfx budget every frame.
  double _mysticEnvParticleTimer = 0;

  /// Mask+Plant feed count for the given slot's active vine, or 0 if
  /// the slot doesn't host a Mask+Plant or hasn't planted one yet.
  /// Used by the HUD button + pause menu to surface vine growth
  /// progress (0–100 feeds, every 10 unlocks another tendril).
  int maskPlantFeedCount(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return 0;
    if (comp.member.family.toLowerCase() != 'mask' ||
        comp.member.element != 'Plant') {
      return 0;
    }
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'mask' &&
          p.element == 'Plant' &&
          p.stationary) {
        return p.effectStacks;
      }
    }
    return 0;
  }

  // Companion sprite rendering (per-slot)
  final Map<int, SpriteAnimationTicker> _companionTickers = {};
  final Map<int, SpriteVisuals?> _companionVisuals = {};
  final Map<int, double> _companionSpriteScales = {};
  final List<_ActiveWingBeam> _activeWingBeams = [];
  // Wing+Light split beams are queued here while a beam tick is being
  // resolved, then flushed after the update loop to avoid mutating
  // _activeWingBeams while it is being iterated.
  final List<_ActiveWingBeam> _pendingWingBeams = [];
  // Wing+Plant flower pickups: dropped on kill, collected by orb on contact.
  final List<_FlowerPickup> _flowerPickups = [];
  // Mask+Spirit ship-collectible wisps. Persist independently from
  // companion projectiles so they survive their parent caster.
  final List<_SpiritWisp> _spiritWisps = [];
  // Per-companion wisp counter — once >= threshold, fires the nuke.
  static const int _maskSpiritNukeThreshold = 6;
  // Mask+Spirit nuke screen-wash flash. Bumped to 1.0 on nuke fire,
  // decayed per frame, read by the render pass to draw the screen
  // wash + expanding ring punctuation.
  double _maskSpiritNukeFlash = 0;
  Offset _maskSpiritNukeOrigin = Offset.zero;
  final _ProjectileControlBuckets _projectileControlBuckets =
      _ProjectileControlBuckets();
  final Map<int, List<CosmicSurvivalEnemy>> _enemySpatialGrid =
      <int, List<CosmicSurvivalEnemy>>{};
  int _spatialQueries = 0;
  int _spatialCandidates = 0;
  double _spatialMetricsTimer = 0;
  final Paint _bossProjectilePaint = Paint();
  final Paint _bossProjectileGlowPaint = Paint();
  final Paint _enemyProjectilePaint = Paint();
  final Paint _shipProjectilePaint = Paint()..color = const Color(0xFF00E5FF);
  final Paint _shipProjectileGlowPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.2)
    ..maskFilter = null;
  final Paint _beamPaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _beamGlowPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..maskFilter = null;
  final Paint _wingRingPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _wingRingFillPaint = Paint()..style = PaintingStyle.fill;
  final Paint _companionProjCorePaint = Paint();
  final Paint _companionProjLinePaint = Paint()..strokeCap = StrokeCap.round;
  final Paint _companionProjStrokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

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
    this.visualQuality = SurvivalVisualQuality.performance,
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

  double get _arenaRadius =>
      max(1140.0, max(size.x / _currentZoom, size.y / _currentZoom) * 0.54);

  // Fixed per-run quality profile: visuals do not change mid-game.
  bool get _reduceSecondaryGlows => switch (visualQuality) {
    SurvivalVisualQuality.cinematic => false,
    SurvivalVisualQuality.balanced => true,
    SurvivalVisualQuality.performance => true,
  };
  bool get _reduceMinorLabels => switch (visualQuality) {
    SurvivalVisualQuality.cinematic => false,
    SurvivalVisualQuality.balanced => false,
    SurvivalVisualQuality.performance => true,
  };
  bool get _reduceAmbientVfx => switch (visualQuality) {
    SurvivalVisualQuality.cinematic => false,
    SurvivalVisualQuality.balanced => true,
    SurvivalVisualQuality.performance => true,
  };
  bool _useReducedCompanionProjectileRendering(Projectile projectile) {
    // Companion ability projectiles carry most species/element identity, so
    // performance mode only simplifies generic shots. Authored species effects
    // keep their silhouettes while ambient VFX are trimmed by other gates.
    return shouldUseReducedCompanionProjectileRendering(
      quality: visualQuality,
      projectile: projectile,
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

  int get currentZoomLevel => _zoomLevelIndex;
  String get currentZoomLevelLabel => switch (_zoomLevelIndex) {
    0 => 'OUTER',
    2 => 'INNER',
    _ => 'BASE',
  };

  void setZoomLevel(int levelIndex) {
    final clamped = levelIndex.clamp(0, _zoomPresets.length - 1);
    if (_zoomLevelIndex == clamped && _zoomAnimComplete) return;
    _zoomLevelIndex = clamped;
    _startZoomAnimation(_zoomPresets[_zoomLevelIndex]);
  }

  void cycleZoomLevel() {
    setZoomLevel((_zoomLevelIndex + 1) % _zoomPresets.length);
  }

  void _startZoomAnimation(double targetZoom) {
    _zoomAnimFrom = _currentZoom;
    _zoomAnimTo = targetZoom;
    _zoomAnimTimer = 0;
    _zoomAnimComplete = false;
  }

  void startGame() {
    _started = true;
    _startZoomAnimation(_zoomPresets[_zoomLevelIndex]);
    spawner.startFirstWave();
  }

  // == Update ==============================================================

  @override
  void update(double dt) {
    super.update(dt);
    if (!_started || isGameOver || gamePaused) return;

    _rebuildEnemySpatialGrid();

    stats.timeElapsed += dt;

    // Zoom animation
    if (!_zoomAnimComplete) {
      _zoomAnimTimer += dt;
      final t = (_zoomAnimTimer / _zoomAnimDuration).clamp(0.0, 1.0);
      final ease = 1.0 - pow(1.0 - t, 3).toDouble();
      _currentZoom = _zoomAnimFrom + (_zoomAnimTo - _zoomAnimFrom) * ease;
      if (t >= 1.0) _zoomAnimComplete = true;
    }

    _updateShip(dt);
    _updateCompanion(dt);
    _buildProjectileControlBuckets(_projectileControlBuckets);
    _updateEnemies(dt, _projectileControlBuckets);
    _rebuildEnemySpatialGrid();
    _updateCompanionProjectiles(dt);
    updatePersistentAbilityEffects(dt);
    _updateBeamEffects(dt);
    _updateFlowerPickups(dt);
    _updateKinSupportTick(dt);
    _updateMysticEnvironments(dt);
    _updateSpiritWisps(dt);
    if (_maskSpiritNukeFlash > 0) {
      _maskSpiritNukeFlash = max(0, _maskSpiritNukeFlash - dt * 1.2);
    }
    _updateShipProjectiles(dt);
    _updateShipAuxWeaponTrees(dt);
    _updateOrbDefenses(dt);
    _updateDetonation(dt);
    _updateOrbSkinPassives(dt);
    _updateBoss(dt);
    _updateBossProjectiles(dt, _projectileControlBuckets.interceptors);
    _updateEnemyProjectiles(
      dt,
      _projectileControlBuckets.interceptors,
      _projectileControlBuckets.reflectors,
    );
    _updateVfx(dt);
    _updateAlchemicalMeterDisplay(dt);
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
      final wave = spawner.currentWave;
      final bossAngle = _rng.nextDouble() * 2 * pi;
      final bossTargetRadius = max(260.0, _arenaRadius - 130.0);
      final bossSpawnPos = Offset(
        orb.position.dx + cos(bossAngle) * bossTargetRadius,
        orb.position.dy + sin(bossAngle) * bossTargetRadius,
      );
      activeBoss = spawner.createBossForWave(wave, bossSpawnPos);
      spawner.markBossSpawned();
      if (activeBoss != null) {
        _beginBossEntrance(activeBoss!, bossAngle);
        onBossSpawn?.call(activeBoss!);
      }
      // Multi-boss waves: boss-level N spawns N bosses simultaneously, capped
      // for sanity. Ultimate / titanic waves stay solo for readability.
      extraBosses.clear();
      final isUltimateWave = wave % 25 == 0;
      if (activeBoss != null && !isUltimateWave) {
        final bossLevel = (wave ~/ 5).clamp(1, 20);
        final extraCount = (bossLevel - 1).clamp(0, 5);
        for (var i = 0; i < extraCount; i++) {
          final extraAngle = bossAngle + (i + 1) * (2 * pi / (extraCount + 1));
          final extraPos = Offset(
            orb.position.dx + cos(extraAngle) * bossTargetRadius,
            orb.position.dy + sin(extraAngle) * bossTargetRadius,
          );
          final extra = spawner.createBossForWave(wave, extraPos);
          if (extra == null) continue;
          extraBosses.add(extra);
          _beginBossEntrance(extra, extraAngle);
        }
      }
    }

    // Check wave completion
    final alive = enemies.length;
    final bossAlive = anyBossAlive;
    spawner.checkWaveComplete(alive, bossAlive: bossAlive);

    _maybeTriggerPowerUpSelection();

    if (spawner.intermission && !showingPowerUpSelection) {
      final clearedWave = spawner.currentWave;
      final bossWave = spawner.isBossWave;
      _cleanupBetweenWaves();
      _grantIntermissionReward(clearedWave, bossWave: bossWave);
      _maybeTriggerPowerUpSelection();
      spawner.resumeAfterIntermission();
    }

    _trimProjectilePools();

    // Game over
    if (orb.currentHp <= 0 && !isGameOver) {
      isGameOver = true;
      onGameOver();
    }

    _updateSpatialMetrics(dt);
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
    final wasDead = ship.isDead;
    if (wasDead) {
      ship.fireTimer = 0;
      ship.hitFlash = 0;
      _shipRespawnTimer += dt;
      if (_shipRespawnTimer >= _shipRespawnDelay) {
        ship.isDead = false;
        ship.currentHp = ship.maxHp * 0.5;
        _dragTarget = ship.position;
        _shipRespawnTimer = 0;
      }
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

    if (wasDead) return;

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
      } else {
        double bestDist = double.infinity;
        for (final b in allLivingBosses) {
          final bd = (b.position - ship.position).distance;
          if (bd < 500 && bd < bestDist) {
            bestDist = bd;
            fireTarget = b.position;
          }
        }
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
    var dist = toOrb.distance;
    if (dist <= 0.001) return;

    var dir = Offset(toOrb.dx / dist, toOrb.dy / dist);
    final gravityFalloff = (1 - (dist / _orbGravityRadius)).clamp(0.0, 1.0);
    if (gravityFalloff > 0) {
      final pull = 18.0 * gravityFalloff * gravityFalloff;
      ship.position += dir * pull * dt;
      final toOrbAfterPull = orb.position - ship.position;
      dist = toOrbAfterPull.distance;
      if (dist <= 0.001) return;
      dir = Offset(toOrbAfterPull.dx / dist, toOrbAfterPull.dy / dist);
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
    final kineticLevel = powerUps.kineticOverdriveLevel;
    final kineticScale = 1.0 + kineticLevel * 0.10;
    final baseDamage = 10.0 * powerUps.shipDamageMultiplier * kineticScale;
    final shotSpeed = 400.0 * (1.0 + kineticLevel * 0.12);
    final shotLife = 3.0 + kineticLevel * 0.35;

    // Rocket Barrage path (mutually exclusive with spread shot)
    if (powerUps.hasRocketBarrage) {
      final rocketLevel = powerUps.rocketBarrageLevel;
      final rocketDamage = baseDamage * (2.5 + rocketLevel * 1.5);
      final splashRadius = 60.0 + rocketLevel * 25.0;
      final rocketSpeed = 340.0 * (1.0 + kineticLevel * 0.08);
      final nearest = _nearestEnemyTo(ship.position, 600);
      shipProjectiles.add(
        ShipProjectile(
          position: ship.position,
          velocity: Offset(norm.dx * rocketSpeed, norm.dy * rocketSpeed),
          damage: rocketDamage,
          life: 4.0 + kineticLevel * 0.3,
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
            life: 4.0 + kineticLevel * 0.3,
            isHoming: true,
            target: nearest2,
            splashRadius: splashRadius * 0.8,
          ),
        );
      }
      return;
    }

    // Standard shot
    shipProjectiles.add(
      ShipProjectile(
        position: ship.position,
        velocity: Offset(norm.dx * shotSpeed, norm.dy * shotSpeed),
        damage: baseDamage,
        life: shotLife,
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
              velocity: Offset(cos(sa) * shotSpeed, sin(sa) * shotSpeed),
              damage: baseDamage * 0.6,
              life: shotLife,
            ),
          );
        }
      }
    }
  }

  void _updateShipAuxWeaponTrees(double dt) {
    if (ship.isDead) return;

    final missileLevel = powerUps.missileLauncherLevel;
    if (missileLevel > 0) {
      _shipMissileLauncherTimer -= dt;
      final missileInterval = (6.2 - missileLevel * 1.2).clamp(2.6, 6.2);
      if (_shipMissileLauncherTimer <= 0) {
        _shipMissileLauncherTimer = missileInterval;
        final target = _nearestEnemyTo(ship.position, 620);
        final boss = activeBoss;
        final targetPos =
            target?.position ??
            (boss != null && !boss.isDead ? boss.position : null);
        if (targetPos != null && shipProjectiles.length < 50) {
          final dir = targetPos - ship.position;
          final dist = dir.distance;
          if (dist > 0.01) {
            final norm = Offset(dir.dx / dist, dir.dy / dist);
            final speed = 330.0 + missileLevel * 30.0;
            final missileDamage =
                (20.0 + missileLevel * 10.0) * powerUps.shipDamageMultiplier;
            final splashRadius = 80.0 + missileLevel * 24.0;
            shipProjectiles.add(
              ShipProjectile(
                position: ship.position,
                velocity: norm * speed,
                damage: missileDamage,
                life: 4.4,
                isHoming: true,
                target: target,
                splashRadius: splashRadius,
              ),
            );
            if (missileLevel >= 3 && shipProjectiles.length < 50) {
              final offsetAngle = atan2(norm.dy, norm.dx) + 0.2;
              shipProjectiles.add(
                ShipProjectile(
                  position: ship.position,
                  velocity: Offset(
                    cos(offsetAngle) * speed,
                    sin(offsetAngle) * speed,
                  ),
                  damage: missileDamage * 0.75,
                  life: 4.4,
                  isHoming: true,
                  target: _nearestEnemyTo(ship.position + norm * 16, 640),
                  splashRadius: splashRadius * 0.85,
                ),
              );
            }
          }
        }
      }
    } else {
      _shipMissileLauncherTimer = 0;
    }

    final turretLevel = powerUps.rapidTurretLevel;
    if (turretLevel > 0) {
      _shipRapidTurretTimer -= dt;
      final turretInterval = (1.35 - turretLevel * 0.22).clamp(0.55, 1.35);
      if (_shipRapidTurretTimer <= 0) {
        _shipRapidTurretTimer = turretInterval;
        final target = _nearestEnemyTo(ship.position, 520);
        if (target != null) {
          final beamDamage =
              (8.0 + turretLevel * 6.0) * powerUps.shipDamageMultiplier;
          _spawnBeam(
            ship.position,
            target.position,
            const Color(0xFF9FE8FF),
            width: 2.1 + turretLevel * 0.35,
            life: 0.08,
          );
          _damageEnemy(target, beamDamage);
        } else {
          SurvivalBoss? best;
          double bestDist = 560;
          for (final b in allLivingBosses) {
            final d = (b.position - ship.position).distance;
            if (d < bestDist) {
              best = b;
              bestDist = d;
            }
          }
          if (best != null) {
            final beamDamage =
                (7.0 + turretLevel * 5.0) * powerUps.shipDamageMultiplier;
            _spawnBeam(
              ship.position,
              best.position,
              const Color(0xFF9FE8FF),
              width: 2.1 + turretLevel * 0.35,
              life: 0.08,
            );
            damageBoss(beamDamage, target: best);
          }
        }
      }
    } else {
      _shipRapidTurretTimer = 0;
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
      final comp = entry.value;
      final targetChoice = _stabilizeCompanionTargetChoice(
        comp,
        _pickCompanionTargetChoice(comp),
      );
      comp.stickyTarget = targetChoice?.enemy;
      _updateSingleCompanion(dt, entry.key, comp, targetChoice);
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
    comp.stickyTargetLockTimer = (comp.stickyTargetLockTimer - dt).clamp(0, 10);
    comp.hitFlash = (comp.hitFlash - dt * 4).clamp(0, 1);
    _companionTickers[slotIndex]?.update(dt);

    // Charge state
    if (comp.chargeTimer > 0) {
      comp.chargeTimer -= dt;
      // Horn+Lava: render the build-up ember storm around the horn
      // each frame so the long charge has a visible "warming up"
      // telegraph instead of being a silent slow walk.
      if (comp.member.family.toLowerCase() == 'horn' &&
          comp.member.element == 'Lava') {
        // Approximate normalized progress 0→1 over the dash.
        final p = (1.5 - comp.chargeTimer).clamp(0.0, 1.5) / 1.5;
        _renderLavaChargeTelegraph(comp, p);
      }
      if (comp.chargePathType == 'circle' && comp.chargeCircleCenter != null) {
        // Horn+Water: curved charge — sweep around chargeCircleCenter
        // at chargeCircleAngularSpeed rad/s. Damage sweep still applies
        // to enemies the horn touches as it arcs.
        comp.chargeCircleAngle += comp.chargeCircleAngularSpeed * dt;
        final center = comp.chargeCircleCenter!;
        comp.position = Offset(
          center.dx + cos(comp.chargeCircleAngle) * comp.chargeCircleRadius,
          center.dy + sin(comp.chargeCircleAngle) * comp.chargeCircleRadius,
        );
        // Face along the tangent of the circle (perpendicular to radius).
        comp.angle = comp.chargeCircleAngle + pi / 2;
        for (final e in enemies) {
          if (e.isDead) continue;
          final d = (e.position - comp.position).distance;
          if (d < e.radius + comp.chargeSweepRadius &&
              !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
            comp.chargeHitIds?.add(e.hashCode);
            _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
          }
        }
      } else if (comp.chargeTarget != null) {
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
          final hornElement = comp.member.family.toLowerCase() == 'horn'
              ? comp.member.element
              : null;
          for (final e in enemies) {
            if (e.isDead) continue;
            final d = (e.position - comp.position).distance;
            if (d < e.radius + comp.chargeSweepRadius &&
                !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
              comp.chargeHitIds?.add(e.hashCode);
              _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
              // Horn+Plant: per-enemy root on charge hit. Survivors
              // get a rooted state (immobilizes them, wears the
              // vine-wrap visual). Duration scales with intelligence
              // so high-stat Plant horns root much longer.
              if (hornElement == 'Plant' && !e.isDead) {
                final intel = _effectiveIntelligence(slotIndex);
                final rootScale = _hornStatScale(
                  intel,
                  perPoint: 0.20,
                  min: 0.80,
                  max: 1.80,
                );
                final dur = 3.0 * rootScale;
                e.hornPlantRootTimer = max(e.hornPlantRootTimer, dur);
                e.slowTimer = max(e.slowTimer, dur);
                e.slowMultiplier = 0;
              }
              // Horn+Poison: dash applies a heavy poison DoT to each
              // enemy the sweep touches.
              if (hornElement == 'Poison' && !e.isDead) {
                _applyAbilityEffectToEnemy(
                  AbilityEffectKind.poison,
                  e,
                  comp.position,
                  comp.elemAtk * 0.40,
                  60,
                  4.5,
                  sourceSlotIndex: slotIndex,
                );
              }
            }
          }
        }
        // Horn+Ice: paint a wall segment every 0.05s along the dash
        // path. Each segment is a small ice sigil that taunts +
        // slows. They overlap to form a continuous barrier.
        if (comp.chargePathType == 'ice-wall') {
          comp.iceWallTrailTimer -= dt;
          if (comp.iceWallTrailTimer <= 0) {
            comp.iceWallTrailTimer = 0.05;
            _spawnIceWallSegment(slotIndex, comp);
          }
        }
        // Horn+Fire: paint a burning trail segment behind the horn
        // as it dashes. Same per-frame spawn pattern as Ice walls,
        // but the trail patches DoT instead of forming a wall.
        if (comp.member.family.toLowerCase() == 'horn' &&
            comp.member.element == 'Fire') {
          comp.iceWallTrailTimer -= dt;
          if (comp.iceWallTrailTimer <= 0) {
            comp.iceWallTrailTimer = 0.12;
            _spawnFireTrailSegment(slotIndex, comp);
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
        // Horn+Lightning: instead of releasing the chain blast now,
        // start a 3s storm-brewing wind-up. The horn keeps holding
        // still, the brewing visual telegraphs the coming discharge,
        // and any damage taken during that window adds to the blast.
        if (comp.member.family.toLowerCase() == 'horn' &&
            comp.member.element == 'Lightning' &&
            comp.pendingChargeBurst != null) {
          comp.hornPostDashWindUpTimer = 3.0;
          // Re-establish a synthetic chargeTimer-equivalent lock so
          // movement stays disabled. We use the post-dash timer for
          // that gate (added below in the per-frame update).
          comp.chargeTarget = null;
          comp.chargeHitIds = null;
          return;
        }
        // Release the deferred horn projectile burst at the impact
        // point. Each projectile's start offset is preserved relative
        // to the original origin, then translated to the new (impact)
        // origin so cone/ring/brace formations still read correctly.
        final pending = comp.pendingChargeBurst;
        if (pending != null && pending.isNotEmpty) {
          final originDelta =
              comp.position - (comp.pendingChargeOrigin ?? comp.position);
          for (final p in pending) {
            p.position = p.position + originDelta;
          }
          // Horn+Lightning: discharge — pump absorbed damage into
          // the chain shockwave zone before it spawns. Bigger guard
          // → bigger blast.
          if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Lightning' &&
              comp.hornLightningAbsorbed > 0) {
            for (final p in pending) {
              if (p.tickEffect == AbilityEffectKind.chain) {
                p.effectPower += comp.hornLightningAbsorbed * 1.2;
              }
            }
            comp.hornLightningAbsorbed = 0;
          }
          _appendCompanionProjectiles(pending);
          _spawnHitSpark(comp.position, elementColor(comp.member.element));
        }
        // Horn+Dark: teleport captured enemies to the dash arrival
        // point and slam them with the impact damage. The void
        // wind-up's job is to gather; the dash's job is to deliver
        // them to their grave at the new location.
        final captured = comp.hornDarkCaptured;
        if (captured != null && captured.isNotEmpty) {
          for (final e in captured) {
            if (e.isDead) continue;
            // Slight per-enemy jitter so they don't all stack on
            // one pixel.
            final a = _rng.nextDouble() * 2 * pi;
            final r = 20.0 + _rng.nextDouble() * 50.0;
            e.position = Offset(
              comp.position.dx + cos(a) * r,
              comp.position.dy + sin(a) * r,
            );
            // Deliver a heavy impact hit on top of the slam sweep.
            _damageEnemy(
              e,
              comp.chargeDamage * 1.2,
              sourceSlotIndex: slotIndex,
            );
            _spawnHitSpark(e.position, elementColor('Dark'));
          }
          comp.hornDarkCaptured = null;
        }
        comp.pendingChargeBurst = null;
        comp.pendingChargeOrigin = null;
        comp.chargeTarget = null;
        comp.chargeHitIds = null;
        // Reset custom path so the next cast starts on a clean slate
        // (e.g. a Crystal cast after a Water cast doesn't accidentally
        // inherit the circle params).
        comp.chargePathType = '';
        comp.chargeCircleCenter = null;
        comp.iceWallTrailTimer = 0;
      }
      return; // don't do normal movement while charging
    }

    // Horn wind-up phase (Dark / Crystal / Spirit). Runs before
    // movement/targeting so the wing holds still and the
    // element-specific tick + visual play. Cooldowns still tick so
    // basics can resume immediately after the dash completes.
    if (comp.windUpTimer > 0) {
      // Cooldowns frozen during the ability — per design they only
      // start counting down after the special fully finishes.
      _handleHornWindUp(slotIndex, comp, dt);
      return;
    }

    // Horn+Lightning post-dash storm brewing. After the dash lands
    // the wing freezes in place, the storm visual builds, and
    // accumulated damage continues to pile onto hornLightningAbsorbed
    // (the existing hook in _applyCompanionIncomingDamage). When the
    // timer expires, the chain blast finally releases.
    if (comp.hornPostDashWindUpTimer > 0) {
      // Cooldowns frozen for the post-dash storm brew too.
      comp.hornPostDashWindUpTimer -= dt;
      _renderHornLightningStormBrew(comp);
      if (comp.hornPostDashWindUpTimer <= 0) {
        // Release the deferred burst with absorbed damage baked in.
        final pending = comp.pendingChargeBurst;
        if (pending != null && pending.isNotEmpty) {
          final originDelta =
              comp.position - (comp.pendingChargeOrigin ?? comp.position);
          // Absorb-to-blast multiplier scales with beauty so
          // high-stat Lightning horns convert absorbed damage
          // more efficiently into the chain shockwave.
          final lightningBeauty = _effectiveBeauty(slotIndex);
          final absorbMul =
              1.4 *
              _hornStatScale(
                lightningBeauty,
                perPoint: 0.10,
                min: 0.85,
                max: 1.40,
              );
          for (final p in pending) {
            p.position = p.position + originDelta;
            if (p.tickEffect == AbilityEffectKind.chain &&
                comp.hornLightningAbsorbed > 0) {
              p.effectPower += comp.hornLightningAbsorbed * absorbMul;
            }
          }
          comp.hornLightningAbsorbed = 0;
          // Spawn the alchemical burst — a big lingering particle
          // storm radiating from the impact, sized to the chain
          // zone's effectRadius so a bigger absorb = bigger burst.
          final chainZone = pending.firstWhere(
            (p) => p.tickEffect == AbilityEffectKind.chain,
            orElse: () => pending.first,
          );
          _spawnLightningChainBurst(
            chainZone.position,
            chainZone.effectRadius > 0 ? chainZone.effectRadius : 140.0,
          );
          _appendCompanionProjectiles(pending);
        }
        comp.pendingChargeBurst = null;
        comp.pendingChargeOrigin = null;
      }
      return;
    }

    // Blessing timer
    if (comp.blessingTimer > 0) {
      comp.blessingTimer -= dt;
      final blessingHeal = (comp.blessingHealPerTick * dt).round();
      if (blessingHeal > 0) {
        final before = comp.currentHp;
        comp.currentHp = min(comp.maxHp, comp.currentHp + blessingHeal);
        _recordHeal((comp.currentHp - before).toDouble(), target: 0);
        _healOrb(blessingHeal * 0.5);
      }
    }

    // Haste timer
    if (comp.basicHasteTimer > 0) comp.basicHasteTimer -= dt;
    if (comp.damageAmpTimer > 0) comp.damageAmpTimer -= dt;
    if (comp.pipSpiritEmpowerTimer > 0) comp.pipSpiritEmpowerTimer -= dt;
    if (comp.hornSpecialActiveWindow > 0) {
      comp.hornSpecialActiveWindow -= dt;
    }
    // Pip+Steam: advance the perpetual attack-speed ramp cycle.
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Steam') {
      comp.pipSteamWindowTimer += dt;
      if (comp.pipSteamWindowTimer >=
          CosmicSurvivalCompanion.pipSteamWindowDuration) {
        comp.pipSteamWindowTimer -=
            CosmicSurvivalCompanion.pipSteamWindowDuration;
      }
    }

    // Horn passive abilities — Air blow-back, Mud sludge trail,
    // Poison toxic aura. All three are passive-only (no active cast)
    // per the bulky-defense-tank design board.
    if (comp.member.family.toLowerCase() == 'horn') {
      switch (comp.member.element) {
        case 'Air':
          _applyHornAirPassive(slotIndex, comp, dt);
          break;
        case 'Mud':
          _applyHornMudPassive(slotIndex, comp, dt);
          break;
        case 'Poison':
          _applyHornPoisonPassive(slotIndex, comp, dt);
          break;
      }
    }

    // Wing+Lightning: the wing must hold still while its beam is
    // charging — the 3s charge anchors the cast point so the blast
    // fires from where the wing committed, not wherever it drifted.
    final isBeamCharging = _activeWingBeams.any(
      (b) => b.sourceSlotIndex == slotIndex && b.chargeTimer > 0,
    );
    // Horn+Light barrier: lock the horn in place while its barrier
    // is alive (no chargeTimer because Light is a no-ram channel).
    final isLightChanneling =
        comp.member.family.toLowerCase() == 'horn' &&
        comp.member.element == 'Light' &&
        _hornLightBarrierActive(slotIndex);
    // Movement
    if (isBeamCharging || isLightChanneling) {
      comp.steeringVelocity = Offset.zero;
    } else if (comp.tethered) {
      comp.steeringVelocity = Offset.zero;
      final dist = (comp.position - ship.position).distance;
      if (dist > 96) {
        final dir = ship.position - comp.position;
        final norm = Offset(dir.dx / dist, dir.dy / dist);
        final moveSpeed =
            160.0 * _speedMovementMultiplier(_effectiveSpeed(slotIndex));
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
        // Smooth anchor updates — slower blend prevents jitter when
        // surrounded by enemies or caught between competing forces.
        final anchorBlend = (0.04 + dt * 0.08).clamp(0.04, 0.10);
        comp.anchor =
            Offset.lerp(comp.anchor, moveTarget, anchorBlend) ?? moveTarget;
        final steeringTarget = comp.anchor;
        final dir = steeringTarget - comp.position;
        final dist = dir.distance;
        if (dist > 6) {
          final norm = Offset(dir.dx / dist, dir.dy / dist);
          final moveSpeed =
              120.0 *
              _familyMovementSpeedMultiplier(comp.member.family) *
              _speedMovementMultiplier(_effectiveSpeed(slotIndex));
          final desiredVelocity = norm * moveSpeed;
          // Lower steering blend = smoother turns, less jitter.
          final steeringBlend = (1.0 - exp(-6.0 * dt)).clamp(0.12, 0.5);
          comp.steeringVelocity =
              Offset.lerp(
                comp.steeringVelocity,
                desiredVelocity,
                steeringBlend,
              ) ??
              desiredVelocity;
          final velocityMagnitude = comp.steeringVelocity.distance;
          if (velocityMagnitude > 0.001) {
            final velNorm = Offset(
              comp.steeringVelocity.dx / velocityMagnitude,
              comp.steeringVelocity.dy / velocityMagnitude,
            );
            final step = min(velocityMagnitude * dt, dist);
            comp.position = Offset(
              comp.position.dx + velNorm.dx * step,
              comp.position.dy + velNorm.dy * step,
            );
            _setCompanionAngle(comp, atan2(velNorm.dy, velNorm.dx), 0.18);
          }
        } else {
          comp.steeringVelocity = Offset.zero;
        }
      } else {
        comp.steeringVelocity = Offset.zero;
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
    // Cooldowns tick freely unless a long-running horn ability is
    // still active (per design: cooldown only starts after the
    // ability fully finishes). Horn charge/wind-up/post-dash gates
    // above already return early so they pause cooldowns; Light
    // barrier has no early return so we gate it explicitly here.
    final hornAbilityActive =
        comp.member.family.toLowerCase() == 'horn' &&
        comp.member.element == 'Light' &&
        _hornLightBarrierActive(slotIndex);
    if (!hornAbilityActive) {
      comp.basicCooldown -= dt;
      comp.specialCooldown -= dt;
    }

    // Double Cast delayed echo
    if (comp.doubleCastTimer > 0) {
      comp.doubleCastTimer -= dt;
      if (comp.doubleCastTimer <= 0 && comp.doubleCastTargetPos != null) {
        final echoTarget = comp.doubleCastTargetPos!;
        final echoDir = echoTarget - comp.position;
        final echoAngle = echoDir.distance > 0.001
            ? atan2(echoDir.dy, echoDir.dx)
            : comp.doubleCastAngle;
        final thresholdBeauty = _effectiveBeauty(slotIndex);
        final thresholdIntelligence = _effectiveIntelligence(slotIndex);
        final thresholdStrength = _effectiveStrength(slotIndex);
        final result2 = createCosmicSpecialAbility(
          origin: comp.position,
          baseAngle: echoAngle + 0.15,
          family: comp.member.family,
          element: comp.member.element,
          damage: comp.elemAtk * 0.70 * comp.damageAmp,
          maxHp: comp.maxHp,
          casterPower: thresholdIntelligence,
          casterBeauty: thresholdBeauty,
          casterIntelligence: thresholdIntelligence,
          casterStrength: thresholdStrength,
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
        _appendCompanionProjectiles(result2.projectiles);
        _activateWingBeamEffects(
          result2.beams,
          sourceSlotIndex: slotIndex,
          origin: comp.position,
          angle: echoAngle + 0.15,
        );
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
      final fireAngle = atan2(toTarget.dy, toTarget.dx);
      _setCompanionAngle(comp, fireAngle, 0.12);

      // When targeting a boss, count its big hitbox toward the firing
      // range so companions don't sit silently when the boss is "just
      // out of attack range" but their projectiles would still hit.
      final bossBonus = (targetChoice?.isBoss ?? false)
          ? (activeBoss?.radius ?? 0) + 80
          : 0.0;
      // Basic attack - family-specific projectiles (same as cosmic game)
      // Wing+Dark passive: the dark wing pulses twice as fast — its
      // basic attacks and special both fire on a halved cooldown.
      final isDarkWing =
          comp.member.family.toLowerCase() == 'wing' &&
          comp.member.element == 'Dark';
      // Kin auto-attack: charged thin laser instead of regular basics.
      // Kin holds position for 1.5s charging, then fires a powerful
      // laser beam. Routed through a dedicated handler so it doesn't
      // share cooldown/projectile plumbing with other families.
      final isKinFamily = comp.member.family.toLowerCase() == 'kin';
      if (isKinFamily) {
        _tickKinChargedAuto(
          comp,
          slotIndex,
          fireAngle,
          attackTarget,
          distToTarget,
          dt,
        );
      } else if (comp.basicCooldown <= 0 &&
          distToTarget <= comp.attackRange + bossBonus) {
        final cooldown = comp.effectiveBasicCooldown * (isDarkWing ? 0.5 : 1.0);
        comp.basicCooldown = cooldown;
        final basics = createFamilyBasicAttack(
          origin: comp.position,
          angle: fireAngle,
          element: comp.member.element,
          family: comp.member.family,
          damage:
              comp.physAtk.toDouble() *
              (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
              comp.damageAmp,
        );
        // Kin+Lightning tesla charge: while any Lightning kin is
        // actively channelling, ALL companion auto-attacks get chain
        // lightning. Stacks with the existing powerup version.
        final teslaActive = _isAnyKinLightningChargeActive();
        for (final projectile in basics) {
          projectile.sourceSlotIndex = slotIndex;
          if (powerUps.companionHasChainLightning(slotIndex) || teslaActive) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              teslaActive ? 3 : 2,
            );
          }
        }
        _appendCompanionProjectiles(basics);

        // Mystic family passive: basic attacks reduce special cooldown
        if (comp.member.family.toLowerCase() == 'mystic') {
          comp.specialCooldown -= 0.3;
        }
        // Pip+Earth passive: each basic shaves a bit off the special
        // cooldown. Shave amount scales with intelligence.
        if (comp.member.family.toLowerCase() == 'pip' &&
            comp.member.element == 'Earth') {
          final earthIntel = _effectiveIntelligence(slotIndex);
          final shaveScale = _hornStatScale(
            earthIntel,
            perPoint: 0.12,
            min: 0.85,
            max: 1.55,
          );
          comp.specialCooldown = max(
            0,
            comp.specialCooldown - 0.4 * shaveScale,
          );
        }
      }

      // Special ability - family x element (same as cosmic game!)
      if (comp.specialCooldown <= 0 &&
          distToTarget <= comp.specialAbilityRange + bossBonus &&
          !isPassiveOnlyCosmicAbility(
            comp.member.family,
            comp.member.element,
          )) {
        final thresholdBeauty = _effectiveBeauty(slotIndex);
        final thresholdIntelligence = _effectiveIntelligence(slotIndex);
        final thresholdStrength = _effectiveStrength(slotIndex);
        final cooldown =
            comp.effectiveSpecialCooldown *
            _specialCooldownReductionMultiplier(slotIndex, comp.member.family) *
            (isDarkWing ? 0.5 : 1.0);
        comp.specialCooldown = cooldown;

        // Pip+Poison: design says the poison-line web persists "until
        // next usage". Despawn the previous cast's line zones and reset
        // the line tracker so this cast starts a fresh web.
        if (comp.member.family.toLowerCase() == 'pip' &&
            comp.member.element == 'Poison') {
          for (final existing in companionProjectiles) {
            if (existing.sourceSlotIndex == slotIndex &&
                existing.abilityFamily == 'pip' &&
                existing.element == 'Poison' &&
                existing.stationary) {
              existing.life = 0;
            }
          }
          comp.lastPipPoisonHitPos = null;
        }

        final result = createCosmicSpecialAbility(
          origin: comp.position,
          baseAngle: fireAngle,
          family: comp.member.family,
          element: comp.member.element,
          damage:
              comp.elemAtk *
              1.15 *
              (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
              comp.damageAmp,
          maxHp: comp.maxHp,
          casterPower: thresholdIntelligence,
          casterBeauty: thresholdBeauty,
          casterIntelligence: thresholdIntelligence,
          casterStrength: thresholdStrength,
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
        var specialProjectiles = result.projectiles;
        // Mane+Spirit: each cast adds another shot to a tight machine-gun
        // stream up to 10, then resets. abilityKillStacks doubles as the
        // cast counter for this companion.
        if (comp.member.family.toLowerCase() == 'mane' &&
            comp.member.element == 'Spirit' &&
            specialProjectiles.isNotEmpty) {
          final stacks = comp.abilityKillStacks.clamp(0, 9);
          final shotCount = 1 + stacks;
          final base = specialProjectiles.first;
          final dir = Offset(cos(fireAngle), sin(fireAngle));
          final perp = Offset(-dir.dy, dir.dx);
          final soulSlashes = <Projectile>[];
          for (var i = 0; i < shotCount; i++) {
            final laneOffset = ((i % 3) - 1) * 2.5;
            soulSlashes.add(
              Projectile(
                position: base.position - dir * (i * 9.0) + perp * laneOffset,
                angle: fireAngle + (i.isEven ? -0.018 : 0.018),
                element: base.element,
                damage: base.damage,
                life: base.life + i * 0.025,
                speedMultiplier: min(base.speedMultiplier + i * 0.012, 0.74),
                radiusMultiplier: max(base.radiusMultiplier * 0.88, 0.72),
                visualScale: max(base.visualScale * 0.86, 0.72),
                piercing: base.piercing,
                homing: base.homing,
                homingStrength: base.homingStrength,
                visualStyle: base.visualStyle,
                sourceSlotIndex: slotIndex,
                abilityFamily: base.abilityFamily,
                hitEffect: base.hitEffect,
                killEffect: base.killEffect,
                pierceEffect: base.pierceEffect,
                effectPower: base.effectPower,
                effectRadius: base.effectRadius,
                effectDuration: base.effectDuration,
              ),
            );
          }
          specialProjectiles = soulSlashes;
          comp.abilityKillStacks = comp.abilityKillStacks >= 9
              ? 0
              : comp.abilityKillStacks + 1;
        }
        // Mane+Lightning: fire 5–10 small orbs toward scattered map
        // positions; each blooms into a larger shock field on arrival.
        if (comp.member.family.toLowerCase() == 'mane' &&
            comp.member.element == 'Lightning' &&
            specialProjectiles.isNotEmpty) {
          final base = specialProjectiles.first;
          final orbCount = 5 + _rng.nextInt(6);
          final scatterCenter = ship.isDead ? orb.position : ship.position;
          final scatterRadius = min(560.0, _arenaRadius * 0.42);
          final orbs = <Projectile>[];
          for (var i = 0; i < orbCount; i++) {
            final a =
                fireAngle + i * 2.399963 + (_rng.nextDouble() - 0.5) * 0.42;
            final dist = 170.0 + _rng.nextDouble() * scatterRadius;
            final target = _clampToArena(
              scatterCenter + Offset(cos(a), sin(a)) * dist,
              padding: _arenaShipPadding,
            );
            final launchAngle = atan2(
              target.dy - comp.position.dy,
              target.dx - comp.position.dx,
            );
            final orb = Projectile(
              position: Offset(
                comp.position.dx + cos(launchAngle) * 24,
                comp.position.dy + sin(launchAngle) * 24,
              ),
              angle: launchAngle,
              element: 'Lightning',
              damage: 0,
              life: 2.9,
              speedMultiplier: 0.82 + (i % 3) * 0.05,
              piercing: true,
              radiusMultiplier: 0.58,
              visualScale: 0.62,
              visualStyle: ProjectileVisualStyle.sigil,
              sourceSlotIndex: slotIndex,
              abilityFamily: 'mane',
              effectPower: base.damage * 0.30,
              effectRadius: 44,
              effectDuration: 1.0,
              effectStacks: 1,
            );
            orb.cachedHomingTarget = target;
            orbs.add(orb);
          }
          specialProjectiles = orbs;
        }
        // Horn charges: hold the projectile burst until the ram lands
        // on its target. This anchors the spawn at the point of attack
        // instead of the caster's start position.
        final isHornCharge =
            comp.member.family.toLowerCase() == 'horn' &&
            result.chargeTimer > 0;
        if (isHornCharge) {
          // Right-size oversized snare/taunt fields and bump short
          // stationary lifetimes so each impact reads cleanly.
          for (final p in result.projectiles) {
            if (p.snareRadius > 100) p.snareRadius = 100;
            if (p.tauntRadius > 180) p.tauntRadius = 180;
            if (p.effectRadius > 110) p.effectRadius = 110;
            // Stationary fixtures should outlast the wave that walks
            // into them — bump short lifetimes toward a 2.5s floor.
            if (p.stationary && p.life < 2.5) {
              p.life = 2.5;
            }
          }
          comp.pendingChargeBurst = specialProjectiles;
          comp.pendingChargeOrigin = comp.position;
          comp.pendingChargeAngle = fireAngle;
          // Cap impact final-sweep so the ram doesn't nuke a 124-radius
          // bowl on every cast.
          if (comp.chargeFinalSweepRadius > 80) {
            comp.chargeFinalSweepRadius = 80;
          }
          if (comp.chargeSweepRadius > 70) {
            comp.chargeSweepRadius = 70;
          }
        } else {
          // Mask+Spirit: convert each scattered "wisp" projectile into
          // a ship-collectible pickup. Ship gathers them; once enough
          // are collected, every non-boss enemy is nuked.
          final isMaskSpiritSpecial =
              comp.member.family.toLowerCase() == 'mask' &&
              comp.member.element == 'Spirit';
          final isMaskPlantSpecial =
              comp.member.family.toLowerCase() == 'mask' &&
              comp.member.element == 'Plant';
          final isMaskDustSpecial =
              comp.member.family.toLowerCase() == 'mask' &&
              comp.member.element == 'Dust';
          if (isMaskSpiritSpecial) {
            for (final wisp in specialProjectiles) {
              if (_spiritWisps.length >= 120) break;
              _spiritWisps.add(
                _SpiritWisp(
                  position: wisp.position,
                  sourceSlotIndex: slotIndex,
                  damage: max(wisp.effectPower, comp.elemAtk * 1.2),
                  bobPhase: _rng.nextDouble() * pi * 2,
                  life: max(8.0, wisp.life),
                ),
              );
            }
          } else if (isMaskPlantSpecial) {
            _feedOrSpawnMaskPlantVine(slotIndex, specialProjectiles);
          } else if (isMaskDustSpecial) {
            _spawnMaskDustShields(slotIndex, specialProjectiles);
          } else {
            _appendCompanionProjectiles(specialProjectiles);
          }
          // Kin support-path cast intercepts. Most kin supports don't
          // produce projectiles directly — they flip companion-side
          // state that the per-frame loop consumes. Done after the
          // baseline projectile append above so the standard heal +
          // blessing still apply.
          if (comp.member.family.toLowerCase() == 'kin') {
            _activateKinSupportPath(comp, fireAngle, attackTarget);
          }
          // Mystic ultimate environment overlay — change the WORLD
          // for the cast's duration. Pushes a new entry; multiple
          // simultaneous mystics stack their tints.
          if (comp.member.family.toLowerCase() == 'mystic') {
            _pushMysticEnvironment(comp.member.element);
          }
        }
        _activateWingBeamEffects(
          result.beams,
          sourceSlotIndex: slotIndex,
          origin: comp.position,
          angle: fireAngle,
        );

        // Apply state changes from ability
        _applyCompanionSpecialSupportEffects(comp, result);
        if (result.chargeTimer > 0) {
          // Stash the charge stats now; the kick-off (chargeTimer +
          // chargeTarget) is gated by wind-up below.
          comp.chargeDamage = result.chargeDamage;
          comp.chargeSpeedMultiplier = result.chargeSpeedMultiplier;
          comp.chargeSweepRadius = result.chargeSweepRadius;
          comp.chargeOvershootDistance = result.chargeOvershootDistance;
          comp.chargeFinalSweepRadius = result.chargeFinalSweepRadius;
          comp.chargeHitIds = <int>{};
          comp.pendingChargeTimerValue = result.chargeTimer;
          // Horn special "active window" — kill effects (Steam reset,
          // Lava homing flames, Blood vampiric heal) check this so
          // basic-attack kills outside the special's window don't
          // trigger them. 5s covers wind-up + dash + post-impact tick.
          if (comp.member.family.toLowerCase() == 'horn') {
            comp.hornSpecialActiveWindow = 5.0 + result.windUpTime;
            // Reset Lightning absorb counter so each cast starts fresh.
            comp.hornLightningAbsorbed = 0;
          }
          // Horn+Blood: HP sacrifice on cast. Take 18% of current HP
          // and bank the magnitude into chargeDamage so the impact
          // hits proportionally harder. Heal-on-kill window is the
          // hornSpecialActiveWindow above.
          if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Blood') {
            final sac = (comp.currentHp * 0.18).round();
            if (sac > 0 && comp.currentHp - sac > 1) {
              comp.currentHp -= sac;
              comp.hitFlash = 1.0;
              // Scale impact damage up: ~1× sac per 4 HP sacrificed
              // (tuned so a 200-HP sacrifice adds a meaty bump).
              comp.chargeDamage += sac * 0.25;
            }
          }
          if (result.windUpTime > 0) {
            // Horn wind-up phase (Dark / Crystal / Spirit): hold the
            // wing in place for windUpTime seconds, run the
            // element-specific wind-up tick + visual, THEN kick off
            // the dash from the wing's wind-up position toward the
            // stored target.
            comp.windUpTimer = result.windUpTime;
            comp.windUpElement = result.windUpElement;
            comp.windUpDashTarget = attackTarget;
            comp.windUpFireAngle = fireAngle;
            comp.hornDarkPullTimer = 0;
          } else if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Water') {
            // Horn+Water: curved circular charge. Sweep around the
            // cast point at a fixed angular speed for the duration;
            // whirlpool lands at center on completion (because the
            // horn ends a full loop back near origin → originDelta
            // is ~zero).
            const circleDuration = 1.0;
            const circleAngularSpeed = 2 * pi / circleDuration;
            final circleRadius = comp.chargeOvershootDistance.clamp(
              90.0,
              200.0,
            );
            comp.chargePathType = 'circle';
            comp.chargeCircleCenter = comp.position;
            comp.chargeCircleRadius = circleRadius.toDouble();
            // Start angle aligned with fire direction so the horn
            // sweeps tangentially away from where the player aimed.
            comp.chargeCircleAngle = fireAngle - pi / 2;
            comp.chargeCircleAngularSpeed = circleAngularSpeed;
            comp.chargeTimer = circleDuration;
            comp.chargeTarget = null;
            comp.chargeHitIds = <int>{};
          } else if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Ice') {
            // Horn+Ice: dash SIDEWAYS (perpendicular to the enemy
            // direction). An ice wall paints itself segment-by-
            // segment along the horn's path during the dash, so
            // enemies advancing toward the original cast position
            // walk into the freshly-formed wall.
            const wallLength = 240.0;
            final toTarget = attackTarget - comp.position;
            final tdist = toTarget.distance;
            final unit = tdist > 1
                ? Offset(toTarget.dx / tdist, toTarget.dy / tdist)
                : Offset(cos(fireAngle), sin(fireAngle));
            // Pick the perpendicular side that has more room (away
            // from arena center if the wing is near the edge). A
            // simple stable pick: rotate +90°. Could flip per-cast
            // later if needed.
            final perp = Offset(-unit.dy, unit.dx);
            final dashTarget = comp.position + perp * wallLength;
            comp.chargeTarget = dashTarget;
            comp.chargeHitIds = <int>{};
            comp.chargePathType = 'ice-wall';
            comp.iceWallTrailTimer = 0;
            final travelTime =
                wallLength /
                (CosmicSurvivalCompanion.chargeSpeed *
                    comp.chargeSpeedMultiplier);
            comp.chargeTimer = (travelTime + 0.10).clamp(0.3, 3.0);
          } else {
            _startHornCharge(comp, attackTarget, result.chargeTimer);
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
          comp.doubleCastAngle = fireAngle;
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
        final dmg = max(1, (contactDmg * 100 / (100 + comp.physDef)).round());
        _applyCompanionIncomingDamage(comp, dmg.toDouble());
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

  // Special-ability cadence is now driven mostly by the companion's
  // effective Speed stat (via CosmicBalance.companionCooldownReduction).
  // Kin's build-defining utilities are too strong to fire as often as
  // standard specials, so we stretch their cadence ~1.6×.
  // Mystics already have a dedicated per-element cooldown formula in
  // effectiveSpecialCooldown that scales from 60–160s with statProgress
  // — no extra multiplier needed here.
  double _specialCooldownReductionMultiplier(int slotIndex, String family) {
    final f = family.toLowerCase();
    if (f == 'kin') return 1.6;
    return 1.0;
  }

  _CompanionTargetChoice? _pickCompanionTargetChoice(
    CosmicSurvivalCompanion comp,
  ) {
    final family = comp.member.family.toLowerCase();
    final maxScan = max(comp.attackRange, comp.specialAbilityRange) + 180;
    final maxScanSq = maxScan * maxScan;

    CosmicSurvivalEnemy? bestEnemy;
    var bestEnemyScore = double.negativeInfinity;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final distSq = _distanceSquared(enemy.position, comp.position);
      if (distSq > maxScanSq) continue;
      final dist = sqrt(distSq);
      var score = 220.0 - dist;
      if (enemy.target == CosmicEnemyTarget.orb) score += 170;
      if (enemy.target == CosmicEnemyTarget.ship) score += 90;
      if (enemy.role == CosmicEnemyRole.shooter) score += 120;
      if (enemy.role == CosmicEnemyRole.hunter) score += 70;
      if (enemy.isElite) score += 80;
      score += (1.0 - enemy.hpFraction) * 70;
      final orbDist = sqrt(_distanceSquared(enemy.position, orb.position));
      score += max(0.0, 180 - orbDist) * 0.45;

      switch (family) {
        case 'let':
          // Target: most health — prioritize highest HP enemies
          score += enemy.hpFraction * 180;
        case 'pip':
          // Target: least health — prioritize lowest HP enemies (execute)
          score += (1.0 - enemy.hpFraction) * 180;
        case 'horn':
          // Target: closest to orb — heavily prioritize enemies near the orb
          if (orbDist < 200) score += (200 - orbDist) * 0.8;
        case 'wing':
          // Target: furthest from orb — engage distant/outer enemies
          score += orbDist * 0.5;
        case 'mane':
          break; // Target: none — closest enemy wins via base distance score
        case 'mask':
          break; // Target: none — closest enemy wins via base distance score
        case 'kin':
          break; // Target: none — closest enemy wins via base distance score
        case 'mystic':
          break; // Target: none — closest enemy wins via base distance score
      }
      // Sticky target bonus: prefer continuing to attack the same enemy
      if (identical(enemy, comp.stickyTarget)) score += 65;

      // Spread-fire penalty: deprioritize enemies already locked by
      // another active companion so a wave gets distributed across
      // targets instead of every companion piling onto the same one.
      // Same-family overlap is penalized harder than cross-family
      // because same-family pickers share scoring biases.
      for (final entry in activeCompanions.entries) {
        if (entry.key == comp.slotIndex) continue;
        final other = entry.value;
        if (other.isDead) continue;
        if (!identical(other.stickyTarget, enemy)) continue;
        final sameFamily = other.member.family.toLowerCase() == family;
        score -= sameFamily ? 90 : 30;
      }

      if (score > bestEnemyScore) {
        bestEnemyScore = score;
        bestEnemy = enemy;
      }
    }

    final boss = activeBoss;
    if (boss != null && !boss.isDead) {
      final bossDist = sqrt(_distanceSquared(boss.position, comp.position));
      // Always score the boss regardless of distance — bosses are a
      // priority target. Only the special-cast distance gate later
      // prevents firing if truly out of range, but the *intent* should
      // be to engage the boss.
      var bossScore = 280.0 - bossDist * 0.35;
      // Big bonus so boss reliably out-scores regular waves.
      bossScore += 260;
      // Family priority on top of the base bonus.
      if (family == 'let') {
        bossScore += 200;
      } else if (family == 'pip') {
        bossScore += 90;
      } else {
        bossScore += 140;
      }
      // Low-HP boss = focus down even harder.
      if (boss.hpFraction < 0.45) bossScore += 120;
      if (boss.hpFraction < 0.20) bossScore += 160;
      // When few regular enemies remain, lock onto the boss.
      if (enemies.where((e) => !e.isDead).length < 4) bossScore += 200;
      if (bossScore >= bestEnemyScore) {
        return _CompanionTargetChoice(
          position: boss.position,
          isBoss: true,
          radius: boss.radius,
        );
      }
    }

    if (bestEnemy != null) {
      return _CompanionTargetChoice(
        position: bestEnemy.position,
        enemy: bestEnemy,
        radius: bestEnemy.radius,
      );
    }
    if (boss != null && !boss.isDead) {
      return _CompanionTargetChoice(
        position: boss.position,
        isBoss: true,
        radius: boss.radius,
      );
    }
    return null;
  }

  _CompanionTargetChoice? _stabilizeCompanionTargetChoice(
    CosmicSurvivalCompanion comp,
    _CompanionTargetChoice? suggested,
  ) {
    final current = comp.stickyTarget;
    final maxScan = max(comp.attackRange, comp.specialAbilityRange) + 180;
    final maxScanSq = maxScan * maxScan;

    if (current != null && !current.isDead) {
      final currentDistSq = _distanceSquared(current.position, comp.position);
      final currentInRange = currentDistSq <= maxScanSq * 1.20;
      if (comp.stickyTargetLockTimer > 0 && currentInRange) {
        return _CompanionTargetChoice(
          position: current.position,
          enemy: current,
          radius: current.radius,
        );
      }

      final incoming = suggested?.enemy;
      if (incoming != null && !identical(incoming, current) && currentInRange) {
        final incomingDistSq = _distanceSquared(
          incoming.position,
          comp.position,
        );
        // Require a significant advantage to switch — prevents
        // flip-flopping between equally close enemies.
        final shouldSwitch = incomingDistSq + 6400 < currentDistSq;
        if (!shouldSwitch) {
          return _CompanionTargetChoice(
            position: current.position,
            enemy: current,
            radius: current.radius,
          );
        }
      }
    }

    if (suggested?.enemy != null) {
      if (!identical(suggested!.enemy, current)) {
        comp.stickyTargetLockTimer = 0.45;
      } else {
        comp.stickyTargetLockTimer = max(comp.stickyTargetLockTimer, 0.18);
      }
    } else {
      comp.stickyTargetLockTimer = 0;
    }

    return suggested;
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
    final basePreferred = _familyPreferredDistance(comp, family);
    // Stand off based on the target's hitbox so a 90u-radius boss doesn't
    // end up with companions hugging its center. Bosses also get a flat
    // bonus + a small per-slot variance so a stack of companions doesn't
    // converge onto the exact same point on the boss perimeter.
    final standoffRadius = choice.radius;
    final bossBonus = choice.isBoss ? 70.0 + slotIndex * 8.0 : 0.0;
    final desiredRange = basePreferred + standoffRadius + bossBonus;

    // Slot-based fanning: each companion takes a distinct angular slot on
    // the orb-side of the target so same-family members don't all stack
    // on the same combat spot. The reference angle points from the orb
    // toward the target; each slot offsets by a fixed amount, fanning
    // companions across the orb-facing arc of the target (especially
    // important on bosses where 4-5 companions would otherwise pile on).
    // Wider fan on boss targets so they form a clear arc instead of a
    // tight clump on the boss perimeter.
    final slotSpreads = choice.isBoss
        ? const [0.0, 0.80, -0.80, 1.55, -1.55]
        : const [0.0, 0.55, -0.55, 1.10, -1.10];
    final orbToTarget = targetPos - orb.position;
    final orbAngle = orbToTarget.distance > 0.001
        ? atan2(orbToTarget.dy, orbToTarget.dx)
        : atan2(toTarget.dy, toTarget.dx);
    final spreadOffset =
        slotSpreads[slotIndex.clamp(0, slotSpreads.length - 1)];
    // orbAngle + pi puts the companion between the target and the orb.
    final approachAngle = orbAngle + pi + spreadOffset;
    // Subtle per-companion bob so they don't look statue-locked when
    // sitting at attack range. Small radius so it reads as "alive" not
    // "drifting away".
    final bobPhase = comp.position.dx * 0.013 + slotIndex * 0.9;
    final bob = choice.isBoss
        ? Offset(
            sin(stats.timeElapsed * 1.6 + bobPhase) * 14.0,
            cos(stats.timeElapsed * 1.4 + bobPhase * 0.8) * 10.0,
          )
        : Offset(
            sin(stats.timeElapsed * 1.8 + bobPhase) * 6.0,
            cos(stats.timeElapsed * 1.5 + bobPhase * 0.7) * 5.0,
          );
    var combatPos =
        targetPos +
        Offset(cos(approachAngle), sin(approachAngle)) * desiredRange +
        bob;

    // Zone loyalty: clamp combat position to stay within the patrol zone.
    // Companions will not chase past their zone boundary at all — they
    // fight what enters their zone and ignore what leaves it.
    final zone = _familyPatrolZone(family);
    if (zone != null) {
      final combatOrbDist = (combatPos - orb.position).distance;
      if (combatOrbDist > 0.001) {
        final toOrb = combatPos - orb.position;
        final normToOrb = Offset(
          toOrb.dx / combatOrbDist,
          toOrb.dy / combatOrbDist,
        );
        // Hard clamp: can't go below zone min or above zone max + small grace.
        final clampedDist = combatOrbDist.clamp(zone.$1, zone.$2 + 40);
        if ((clampedDist - combatOrbDist).abs() > 1.0) {
          combatPos = orb.position + normToOrb * clampedDist;
        }
      }
    }

    return combatPos;
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
      // Base gap plus the target's hitbox so a colossus/boss doesn't have
      // companions glued to its surface. Bosses get an extra cushion so
      // they read as "engaging" rather than "embracing".
      final baseGap = _familyMinimumEnemyGap(comp, family);
      final minEnemyGap =
          baseGap + choice!.radius + (choice.isBoss ? 50.0 : 0.0);
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
    final myZone = _familyPatrolZone(family);
    var separation = Offset.zero;
    for (final entry in activeCompanions.entries) {
      if (entry.key == slotIndex) continue;
      final other = entry.value;
      if (other.isDead) continue;
      // Companions sharing the same patrol zone get stronger repulsion.
      final otherFamily = other.member.family.toLowerCase();
      final otherZone = _familyPatrolZone(otherFamily);
      final sameZone = myZone != null && otherZone == myZone;
      final effectiveRadius = sameZone
          ? separationRadius * 1.3
          : separationRadius;
      final delta = resolved - other.position;
      final dist = delta.distance;
      if (dist <= 0.001 || dist >= effectiveRadius) continue;
      final strength = (effectiveRadius - dist) / effectiveRadius;
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

  // Effective stats = the companion's raw stat plus all powerup/keystone
  // bonuses. Every derived combat value (HP, attack, defense, crit, range,
  // cooldown, movement, special-ability scaling) reads from these so a
  // "+Strength" pick flows consistently into everything Strength touches.
  double _effectiveStrength(int slotIndex) => max(
    0.5,
    party[slotIndex].statStrength + powerUps.strengthBonus(slotIndex),
  );

  double _effectiveIntelligence(int slotIndex) => max(
    0.5,
    party[slotIndex].statIntelligence + powerUps.intelligenceBonus(slotIndex),
  );

  double _effectiveBeauty(int slotIndex) =>
      max(0.5, party[slotIndex].statBeauty + powerUps.beautyBonus(slotIndex));

  double _effectiveSpeed(int slotIndex) =>
      max(0.5, party[slotIndex].statSpeed + powerUps.speedBonus(slotIndex));

  // Movement speed steps through 5 tiers as the effective Speed stat rises.
  double _speedMovementMultiplier(double effectiveSpeed) {
    if (effectiveSpeed < 1.0) return 130.0 / 160.0;
    if (effectiveSpeed < 2.0) return 145.0 / 160.0;
    if (effectiveSpeed < 3.0) return 1.0;
    if (effectiveSpeed < 4.0) return 178.0 / 160.0;
    return 198.0 / 160.0;
  }

  // Derives a companion's combat stats from its effective stats, family
  // multipliers and permanent guardian upgrades. Used both when a companion
  // is summoned and when a stat powerup is picked mid-run.
  ({
    int maxHp,
    int physAtk,
    int elemAtk,
    int physDef,
    int elemDef,
    double cooldownReduction,
    double critChance,
    double attackRange,
    double specialAbilityRange,
  })
  _deriveCompanionStats(int slotIndex) {
    final member = party[slotIndex];
    double guardianUpgradeValue(GuardianUpgrade u) {
      final lvl = upgradeState.getGuardianLevel(u);
      if (lvl <= 0) return 0.0;
      return getGuardianUpgradeDef(u).valuePerLevel[lvl - 1];
    }

    final stats = deriveCosmicSurvivalCompanionStats(
      member: member,
      strengthBonus: powerUps.strengthBonus(slotIndex),
      intelligenceBonus: powerUps.intelligenceBonus(slotIndex),
      beautyBonus: powerUps.beautyBonus(slotIndex),
      speedBonus: powerUps.speedBonus(slotIndex),
      guardianUpgradeValue: guardianUpgradeValue,
    );

    return (
      maxHp: stats.maxHp,
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      critChance: stats.critChance,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
    );
  }

  // Re-derives stats for every active companion so a stat powerup takes
  // effect immediately, without waiting for the companion to be re-summoned.
  // HP fraction is preserved so a pick never silently heals or hurts.
  void _recomputeActiveCompanionStats() {
    for (final entry in activeCompanions.entries) {
      final companion = entry.value;
      final stats = _deriveCompanionStats(entry.key);
      final hpFraction = companion.maxHp > 0
          ? companion.currentHp / companion.maxHp
          : 1.0;
      companion.maxHp = stats.maxHp;
      companion.currentHp = (stats.maxHp * hpFraction).round().clamp(
        1,
        stats.maxHp,
      );
      companion.physAtk = stats.physAtk;
      companion.elemAtk = stats.elemAtk;
      companion.physDef = stats.physDef;
      companion.elemDef = stats.elemDef;
      companion.cooldownReduction = stats.cooldownReduction;
      companion.critChance = stats.critChance;
      companion.attackRange = stats.attackRange;
      companion.specialAbilityRange = stats.specialAbilityRange;
    }
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

    final zone = _familyPatrolZone(family);
    if (zone != null) {
      // Zoned families: add radial variation within the zone ring so they
      // weave in and out, not just trace a perfect circle.
      final zoneWidth = zone.$2 - zone.$1;
      final radialWobble = sin(orbitPhase * 0.6) * zoneWidth * 0.3;
      var anchor = Offset(
        fallbackFormationPoint.dx + cos(orbitPhase) * idleRadius,
        fallbackFormationPoint.dy + sin(orbitPhase * 1.15) * idleRadius * 0.55,
      );
      // Push anchor radially in/out within the zone.
      final orbDist = (anchor - orb.position).distance;
      if (orbDist > 0.001) {
        final toOrb = (anchor - orb.position);
        final norm = Offset(toOrb.dx / orbDist, toOrb.dy / orbDist);
        final targetDist = (orbDist + radialWobble).clamp(zone.$1, zone.$2);
        anchor = orb.position + norm * targetDist;
      }
      return anchor;
    }

    // "Wherever" families (pip, mystic): drift toward the nearest enemy
    // cluster if enemies exist, otherwise figure-8 near the ship.
    var anchor = Offset(
      fallbackFormationPoint.dx + cos(orbitPhase) * idleRadius,
      fallbackFormationPoint.dy + sin(orbitPhase * 1.15) * idleRadius * 0.55,
    );

    // Find nearest alive enemy to gently bias toward threats.
    Offset? nearestEnemyPos;
    var nearestDistSq = double.infinity;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final dSq = _distanceSquared(enemy.position, comp.position);
      if (dSq < nearestDistSq) {
        nearestDistSq = dSq;
        nearestEnemyPos = enemy.position;
      }
    }
    if (nearestEnemyPos != null && nearestDistSq < 500 * 500) {
      // Gently drift 20% toward nearest threat direction.
      anchor = Offset.lerp(anchor, nearestEnemyPos, 0.20) ?? anchor;
    }

    // Soft pull toward ship if too far.
    final shipDist = (anchor - ship.position).distance;
    final maxShipDrift = _arenaRadius * 0.4;
    if (shipDist > maxShipDrift && !ship.isDead) {
      anchor = Offset.lerp(anchor, fallbackFormationPoint, 0.35) ?? anchor;
    }

    // Stay in the arena.
    final maxWander = _arenaRadius - _arenaShipPadding;
    final orbDist = (anchor - orb.position).distance;
    if (orbDist > maxWander) {
      final toOrb = anchor - orb.position;
      if (orbDist > 0.001) {
        final norm = Offset(toOrb.dx / orbDist, toOrb.dy / orbDist);
        anchor = orb.position + norm * (maxWander - 40);
      } else {
        anchor = fallbackFormationPoint;
      }
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
    final zone = _familyPatrolZone(family);
    if (zone != null) {
      // Zoned families: orbit the orb continuously. Each family orbits at a
      // different speed so the patrol ring feels alive. Slot index offsets
      // prevent companions of the same family from stacking.
      final orbitSpeed = switch (family) {
        'wing' => 0.35, // fast sweep around outer edge
        'mane' || 'mask' => 0.20, // moderate patrol
        _ => 0.15, // inner families patrol slowly
      };
      final angle = stats.timeElapsed * orbitSpeed + slotIndex * (2 * pi / 5);
      final zoneCenter = (zone.$1 + zone.$2) / 2;
      return Offset(
        orb.position.dx + cos(angle) * zoneCenter,
        orb.position.dy + sin(angle) * zoneCenter,
      );
    }
    // "Wherever" families (pip, mystic): orbit the ship loosely.
    final angle = -pi / 2 + slotIndex * 0.9;
    return Offset(
      ship.position.dx + cos(angle) * 110.0,
      ship.position.dy + sin(angle) * 110.0,
    );
  }

  double _familyPreferredDistance(CosmicSurvivalCompanion comp, String family) {
    return switch (family) {
      'horn' => comp.attackRange * 0.38,
      'mane' => comp.attackRange * 0.55,
      'pip' => comp.attackRange * 0.42,
      'mask' => comp.attackRange * 0.70,
      'wing' => comp.attackRange * 0.92,
      'kin' => comp.attackRange * 0.55,
      'mystic' => comp.attackRange * 0.88,
      'let' => comp.attackRange * 0.55,
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
      'kin' => max(44.0, preferred * 0.70),
      'mystic' => max(86.0, preferred * 0.95),
      'let' => max(46.0, preferred * 0.72),
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

  /// Returns the patrol zone radii (minRadius, maxRadius) centered on the orb.
  /// Zones scale with the arena so outer families patrol near the arena edge.
  /// Returns null for 'wherever' families (no zone constraint).
  (double, double)? _familyPatrolZone(String family) {
    final arenaR = _arenaRadius;
    // Ship can't fly past arenaR - 32, so outer ends there.
    final outerMax = arenaR - _arenaShipPadding;
    // Divide the arena into three rings:
    //   inner:  orbCore → 1/3 of usable radius
    //   medium: 1/3 → 2/3
    //   outer:  2/3 → arena edge (ship boundary)
    final third = outerMax / 3;
    return switch (family) {
      'let' || 'horn' || 'kin' => (70.0, third), // inner
      'mane' || 'mask' => (third, third * 2), // medium
      'wing' => (third * 2, outerMax), // outer — flies along the arena rim
      _ => null, // wherever (pip, mystic)
    };
  }

  double _familyMovementSpeedMultiplier(String family) {
    return switch (family.toLowerCase()) {
      'horn' => 0.85,
      'mane' => 1.0,
      'wing' => 1.20,
      'kin' => 0.85,
      'let' => 1.0,
      'pip' => 1.0,
      'mask' => 0.85,
      'mystic' => 1.0,
      _ => 1.0,
    };
  }

  String? _familyForSlot(int slotIndex) {
    if (slotIndex < 0 || slotIndex >= party.length) return null;
    return party[slotIndex].family.toLowerCase();
  }

  double _familyOutgoingDamageMultiplier(
    String family, {
    required bool vsBoss,
  }) {
    return switch (family) {
      'horn' => vsBoss ? 0.76 : 0.88,
      'mane' => vsBoss ? 1.0 : 1.0,
      'wing' => vsBoss ? 1.0 : 1.0,
      'let' => vsBoss ? 1.15 : 1.05,
      'pip' => vsBoss ? 0.74 : 1.06,
      'mask' => vsBoss ? 1.0 : 1.0,
      'kin' => vsBoss ? 0.95 : 0.95,
      'mystic' => vsBoss ? 1.0 : 1.0,
      _ => 1.0,
    };
  }

  double _companionOutgoingDamageMultiplier(
    int? sourceSlotIndex, {
    required bool vsBoss,
  }) {
    if (sourceSlotIndex == null) return 1.0;
    final family = _familyForSlot(sourceSlotIndex);
    if (family == null) return 1.0;
    return _familyOutgoingDamageMultiplier(family, vsBoss: vsBoss);
  }

  int _applyCompanionIncomingDamage(
    CosmicSurvivalCompanion comp,
    double rawDamage,
  ) {
    final family = comp.member.family.toLowerCase();
    final takenMult = switch (family) {
      'horn' => 0.78,
      'mane' => 0.96,
      'wing' => 0.96,
      'let' => 0.96,
      'pip' => 1.15,
      'mask' => 0.96,
      'kin' => 0.80,
      'mystic' => 0.96,
      _ => 1.0,
    };
    // Horn+Spirit: phases during the wind-up + dash, taking only
    // 40% damage during that window (60% reduction per design).
    var phaseMult = 1.0;
    if (family == 'horn' &&
        comp.member.element == 'Spirit' &&
        (comp.windUpTimer > 0 || comp.chargeTimer > 0)) {
      phaseMult = 0.40;
    }
    // Horn+Lightning: reactive guard — damage absorbed while
    // charging gets stored and released as part of the chain
    // shockwave on impact. We still apply the damage to HP (the
    // guard isn't immunity, just conversion), but accumulate the
    // raw amount onto hornLightningAbsorbed so the discharge tick
    // can pull it.
    if (family == 'horn' &&
        comp.member.element == 'Lightning' &&
        comp.chargeTimer > 0) {
      comp.hornLightningAbsorbed += rawDamage;
    }
    // Horn+Light barrier: any ally companion standing inside an
    // active barrier takes only 30% incoming damage (per design:
    // "Anything inside is protected").
    var barrierMult = 1.0;
    final barrier = _activeHornLightBarrier();
    if (barrier != null) {
      final (bp, br) = barrier;
      if (_withinRange(bp, comp.position, br)) {
        barrierMult = 0.30;
      }
    }
    final damageTaken = max(
      1,
      (rawDamage * takenMult * phaseMult * barrierMult).round(),
    );
    comp.takeDamage(damageTaken);
    if (comp.slotIndex >= 0) {
      _runStatsFor(comp.slotIndex).damageTaken += damageTaken;
    }
    return damageTaken;
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
    final stats = _deriveCompanionStats(slotIndex);

    final startHpFrac = companionHpFraction[slotIndex] ?? 1.0;
    final startHp = (stats.maxHp * startHpFrac).round().clamp(1, stats.maxHp);
    final savedSpecialCooldown = companionSpecialCooldown[slotIndex];

    final companion = CosmicSurvivalCompanion(
      member: member,
      slotIndex: slotIndex,
      position: ship.position,
      anchor: ship.position,
      maxHp: stats.maxHp,
      currentHp: startHp,
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      critChance: stats.critChance,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
      tethered: tetherModeEnabled && tetheredCompanionSlot == null,
    );
    companion.primeSpecialCooldown(
      savedCooldown: savedSpecialCooldown,
      cooldownMultiplier: _specialCooldownReductionMultiplier(
        slotIndex,
        member.family,
      ),
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

  // == Enemies =============================================================

  void _updateEnemies(double dt, _ProjectileControlBuckets controlBuckets) {
    // Cached once per frame: any active Horn+Light barrier center+radius.
    // Enemies touching the perimeter get bounced back out.
    final lightBarrier = _activeHornLightBarrier();
    // Variants can append enemies while the current wave is being updated.
    // Iterate a snapshot so new spawns join cleanly on the next frame.
    for (final enemy in List<CosmicSurvivalEnemy>.of(enemies)) {
      if (enemy.isDead) continue;

      // Horn+Light barrier: bounce enemies away from the perimeter.
      // Per design "enemies bounce off of it" — anyone inside the
      // barrier zone gets pushed radially outward each frame.
      if (lightBarrier != null) {
        final (bp, br) = lightBarrier;
        final dx = enemy.position.dx - bp.dx;
        final dy = enemy.position.dy - bp.dy;
        final distSq = dx * dx + dy * dy;
        final r = br + enemy.radius;
        if (distSq < r * r && distSq > 0.5) {
          final dist = sqrt(distSq);
          // Bounce: snap to the perimeter + apply a small knockback.
          final norm = Offset(dx / dist, dy / dist);
          enemy.position = Offset(bp.dx + norm.dx * r, bp.dy + norm.dy * r);
          enemy.knockbackVelocity += norm * 90.0;
        }
      }

      enemy.slowTimer = (enemy.slowTimer - dt).clamp(0, 100);
      if (enemy.slowTimer <= 0 && enemy.maneRootTimer <= 0) {
        enemy.slowMultiplier = 0.5;
      }
      enemy.hitFlash = (enemy.hitFlash - dt * 4).clamp(0, 1);
      enemy.attackCooldown = max(0, enemy.attackCooldown - dt);
      enemy.retargetTimer = max(0, enemy.retargetTimer - dt);
      if (enemy.disorientTimer > 0) {
        enemy.disorientTimer = max(0, enemy.disorientTimer - dt);
      }
      if (enemy.hornPlantRootTimer > 0) {
        enemy.hornPlantRootTimer = max(0, enemy.hornPlantRootTimer - dt);
      }
      // Wing+Ice: frost slowly thaws when the beam isn't on the enemy.
      if (enemy.frostBuildup > 0) {
        enemy.frostBuildup = max(0.0, enemy.frostBuildup - dt * 0.35);
      }
      // Summoner variant pulses out small wisp swarms on a fixed cooldown.
      // Trait, not variant: a summoner wisp summons now.
      if (enemy.trait == EnemyTrait.summoner) {
        enemy.summonCooldown = max(0, enemy.summonCooldown - dt);
        if (enemy.summonCooldown <= 0 && enemies.length < 220) {
          enemy.summonCooldown = 6.5;
          final adds = spawner.spawnSummonerWisps(enemy);
          enemies.addAll(adds);
          // Flash + sparkle so the player sees what happened.
          _spawnHitSpark(enemy.position, elementColor(enemy.element));
        }
      }
      // Mane+Plant root tag fades after pierce.
      if (enemy.maneRootTimer > 0) {
        enemy.maneRootTimer = max(0, enemy.maneRootTimer - dt);
        if (enemy.maneRootTimer <= 0) {
          enemy.maneRootSlot = null;
        } else {
          enemy.slowTimer = max(enemy.slowTimer, enemy.maneRootTimer);
          enemy.slowMultiplier = 0;
        }
      }
      // Pip+Mud trail: emit a slow puff every 0.4s while the trailing
      // enemy moves. Stationary enemies don't drop puffs.
      if (enemy.pipMudTrail) {
        enemy.pipMudTrailTimer -= dt;
        if (enemy.pipMudTrailTimer <= 0) {
          enemy.pipMudTrailTimer = 0.42;
          _appendCompanionProjectile(
            Projectile(
              position: enemy.position,
              angle: 0,
              element: 'Mud',
              damage: 0,
              life: 5.5,
              speedMultiplier: 0,
              stationary: true,
              piercing: true,
              radiusMultiplier: 1.1,
              visualScale: 1.0,
              visualStyle: ProjectileVisualStyle.sigil,
              abilityFamily: 'pip',
              tickEffect: AbilityEffectKind.slow,
              effectPower: 1.0,
              effectRadius: 38,
              effectDuration: 1.2,
            ),
          );
        }
      }

      // Mask+Blood permanent drain: enemies tagged by the blood blob
      // bleed HP every frame; drained HP is split as healing across
      // all alchemons until the enemy dies. Cheap per-enemy tick — no
      // radius scan needed because the tag is sticky. Spawns drifting
      // red wisps from the enemy toward the nearest ally so the
      // player can see which enemies are bleeding for them.
      if (enemy.maskBloodDrainSlot != null && !enemy.isDead) {
        final drainPerSec = max(2.0, enemy.maxHp * 0.06);
        final before = enemy.hp;
        _damageEnemy(
          enemy,
          drainPerSec * dt,
          sourceSlotIndex: enemy.maskBloodDrainSlot,
        );
        final drained = before - max(0.0, enemy.hp);
        if (drained > 0) {
          _healAllCompanionsAndShip(
            drained * 0.35,
            sourceSlot: enemy.maskBloodDrainSlot,
          );
        }
        // ~6 wisps/sec: probabilistic spawn keyed off dt so the
        // stream stays continuous regardless of frame rate.
        if (_vfx.length < 140 && _rng.nextDouble() < dt * 6.0) {
          // Pick nearest ally (ship or any active companion) as the
          // target — wisps stream toward whoever is closest to the
          // drain so the visual reads "blood flowing to allies".
          Offset target = ship.isDead ? enemy.position : ship.position;
          var bestSq = ship.isDead
              ? double.infinity
              : (target - enemy.position).distanceSquared;
          for (final ally in activeCompanions.values) {
            if (ally.isDead) continue;
            final ds = (ally.position - enemy.position).distanceSquared;
            if (ds < bestSq) {
              bestSq = ds;
              target = ally.position;
            }
          }
          final delta = target - enemy.position;
          final dist = delta.distance;
          final dir = dist > 0.01
              ? delta / dist
              : Offset(
                  cos(_rng.nextDouble() * 2 * pi),
                  sin(_rng.nextDouble() * 2 * pi),
                );
          // Spawn slightly off-center so the wisps trickle out of the
          // enemy body rather than a single point.
          final jitterA = _rng.nextDouble() * 2 * pi;
          final jitterR = _rng.nextDouble() * 6.0;
          final spawn =
              enemy.position + Offset(cos(jitterA), sin(jitterA)) * jitterR;
          final spd = 70 + _rng.nextDouble() * 50;
          const blood = Color(0xFFC8254A);
          const deep = Color(0xFF5A0D1F);
          _vfx.add(
            _VfxParticle(
              x: spawn.dx,
              y: spawn.dy,
              vx: dir.dx * spd,
              vy: dir.dy * spd,
              size: 1.2 + _rng.nextDouble() * 1.4,
              life: 0.50 + _rng.nextDouble() * 0.30,
              color: _rng.nextBool() ? blood : deep,
            ),
          );
        }
        if (enemy.isDead) enemy.maskBloodDrainSlot = null;
      }

      // Smooth knockback integration keeps pulse/Detonation push readable.
      if (enemy.knockbackVelocity.distanceSquared > 0.01) {
        enemy.position = Offset(
          enemy.position.dx +
              enemy.knockbackVelocity.dx * dt * _timeDilationSlowFactor,
          enemy.position.dy +
              enemy.knockbackVelocity.dy * dt * _timeDilationSlowFactor,
        );
        final damping = exp(-7.5 * dt);
        enemy.knockbackVelocity = Offset(
          enemy.knockbackVelocity.dx * damping,
          enemy.knockbackVelocity.dy * damping,
        );
        if (enemy.knockbackVelocity.distanceSquared < 4.0) {
          enemy.knockbackVelocity = Offset.zero;
        }
      }

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

      // Floaty hover/dive steering (shared with dungeons/space) for melee
      // chasers hunting MOBILE targets. Orb-siege enemies, shooters,
      // orbiters and crushers keep their authored movement so siege
      // pressure and standoff behaviour are unchanged.
      final usesFlightSteering =
          (enemy.role == CosmicEnemyRole.striker ||
              enemy.role == CosmicEnemyRole.hunter) &&
          enemy.target != CosmicEnemyTarget.orb &&
          !(enemy.conduct == EnemyConduct.charge && enemy.hasHeavyBody);

      if (usesFlightSteering) {
        var moveSpeedMult = 1.0;
        for (final proj in controlBuckets.snares) {
          final center =
              proj.transferOrbitCenter ?? proj.orbitCenter ?? proj.position;
          final snareDist = (center - enemy.position).distance;
          if (snareDist > proj.snareRadius) continue;
          moveSpeedMult = min(moveSpeedMult, proj.snareMoveMultiplier);
        }
        final steering = enemy.flightSteering ??= FlightSteeringState(_rng);
        final tick = tickFlightSteering(
          state: steering,
          profile: enemy.conduct == EnemyConduct.stalk
              ? FlightSteeringProfile.survivalPouncer
              : FlightSteeringProfile.survivalMelee,
          toTarget: dir,
          speed:
              enemy.effectiveSpeed * moveSpeedMult * _timeDilationSlowFactor,
          contactRange: enemy.radius + 14,
          dt: dt,
          rng: _rng,
        );
        enemy.position += tick.velocity * dt;
        if (tick.velocity.distanceSquared > 16) {
          enemy.angle = atan2(tick.velocity.dy, tick.velocity.dx);
        } else if (dist > 0.001) {
          enemy.angle = atan2(dir.dy, dir.dx);
        }
        // Ship contact damage is grind-DPS (dt-scaled); a dive only brushes
        // it, so the landed dive itself delivers an impact burst (~0.8s of
        // the old grind) to keep melee pressure honest.
        if (tick.impact &&
            enemy.target == CosmicEnemyTarget.ship &&
            !ship.isDead &&
            _withinRange(enemy.position, ship.position, enemy.radius + 30)) {
          final damageMultiplier = powerUps.hasMirrorShield ? 0.75 : 1.0;
          ship.currentHp -= enemy.damage * 0.6 * damageMultiplier;
          ship.hitFlash = 1.0;
          if (enemy.isVampiric) {
            enemy.hp = min(enemy.maxHp, enemy.hp + enemy.damage * 0.24);
          }
          if (ship.currentHp <= 0) {
            ship.isDead = true;
            _shipRespawnTimer = 0;
          }
        }
      } else if (dist > enemy.radius) {
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
        // One authority for the movement vector — see
        // games/shared/enemy_movement.dart.
        // Conduct is the sole movement authority now — no variant override.
        final move = conductMoveVector(
          conduct: enemy.conduct,
          dist: dist,
          norm: norm,
          tangent: tangent,
        );
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
        // Wing+Dust disorient: redirect the shot at the nearest
        // *other* enemy instead of the orb/ship.
        var shotAngle = enemy.angle;
        if (enemy.disorientTimer > 0) {
          final other = _nearestEnemyTo(enemy.position, 420, exclude: enemy);
          if (other != null) {
            shotAngle = atan2(
              other.position.dy - enemy.position.dy,
              other.position.dx - enemy.position.dx,
            );
          }
        }
        final isSiegeShooter =
            enemy.conduct == EnemyConduct.standoff;
        enemy.attackCooldown =
            (1.7 - min(enemy.tier.index * 0.12, 0.5)) *
            (isSiegeShooter ? 1.12 : 1.0) *
            (enemy.isRelentless ? 0.88 : 1.0) *
            ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                    spawner.currentMutator ==
                        SurvivalWaveMutator.shatteredSpace)
                ? 0.82
                : 1.0);
        enemyProjectiles.add(
          SurvivalEnemyProjectile(
            position: enemy.position,
            angle: shotAngle,
            element: enemy.element,
            friendlyFire: enemy.disorientTimer > 0,
            damage:
                enemy.damage *
                (isSiegeShooter ? 0.95 : 0.8) *
                ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                        spawner.currentMutator ==
                            SurvivalWaveMutator.shatteredSpace)
                    ? 1.08
                    : 1.0),
            target: enemy.target,
            speed:
                (210 + enemy.tier.index * 18) *
                (isSiegeShooter ? 0.9 : 1.0) *
                ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                        spawner.currentMutator ==
                            SurvivalWaveMutator.shatteredSpace)
                    ? 1.10
                    : 1.0),
            radius: isSiegeShooter ? 5.3 : 4.0,
          ),
        );
      }

      _applyEnemyContactDamage(enemy, dt);
      _applyDecoyContactDamage(enemy, controlBuckets.decoys);
    }

    enemies.removeWhere((e) => e.isDead);
  }

  CosmicEnemyTarget _pickEnemyTarget(CosmicSurvivalEnemy enemy) {
    // Kin+Dark cloak: if any kin's cloak is active, ALL companions
    // become untargetable. Anyone who would have picked
    // CosmicEnemyTarget.companion retargets to ship (or orb).
    final cloaked = _isAnyKinDarkCloakActive();
    if (spawner.currentMutator == SurvivalWaveMutator.orbSiege &&
        enemy.role != CosmicEnemyRole.hunter) {
      return CosmicEnemyTarget.orb;
    }
    if (enemy.role == CosmicEnemyRole.striker) return CosmicEnemyTarget.orb;
    if (enemy.role == CosmicEnemyRole.hunter && !ship.isDead) {
      final roll = _rng.nextDouble();
      if (roll < 0.25) return CosmicEnemyTarget.orb;
      if (roll < 0.65) return CosmicEnemyTarget.ship;
      return cloaked ? CosmicEnemyTarget.ship : CosmicEnemyTarget.companion;
    }
    if (enemy.role == CosmicEnemyRole.shooter) {
      if (enemy.conduct == EnemyConduct.standoff &&
          _rng.nextDouble() < 0.72) {
        return CosmicEnemyTarget.orb;
      }
      if (_rng.nextDouble() < 0.38) {
        return CosmicEnemyTarget.orb;
      }
      if (!cloaked && activeCompanions.isNotEmpty && _rng.nextDouble() < 0.55) {
        return CosmicEnemyTarget.companion;
      }
      return ship.isDead ? CosmicEnemyTarget.orb : CosmicEnemyTarget.ship;
    }
    if (!cloaked && activeCompanions.isNotEmpty && _rng.nextDouble() < 0.22) {
      return CosmicEnemyTarget.companion;
    }
    return CosmicEnemyTarget.orb;
  }

  bool _isAnyKinDarkCloakActive() {
    for (final comp in activeCompanions.values) {
      if (comp.kinDarkCloakTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Dark') {
        return true;
      }
    }
    return false;
  }

  bool _isAnyKinLightningChargeActive() {
    for (final comp in activeCompanions.values) {
      if (comp.kinLightningChargeTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Lightning') {
        return true;
      }
    }
    return false;
  }

  bool _isAnyKinLavaPlateActive() {
    for (final comp in activeCompanions.values) {
      if (comp.kinLavaPlateTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Lava') {
        return true;
      }
    }
    return false;
  }

  bool _isInsideAnyKinDustCloud(Offset pos) {
    for (final p in companionProjectiles) {
      if (p.abilityFamily != 'kin' ||
          p.element != 'Dust' ||
          !p.stationary ||
          p.effectRadius <= 0) {
        continue;
      }
      if (_withinRange(p.position, pos, p.effectRadius)) {
        return true;
      }
    }
    return false;
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
      _damageOrb(
        enemy.damage * damageMultiplier * _orbImpactDamageMultiplier(enemy),
      );
      if (_enemyExplodesOnOrbImpact(enemy)) {
        _triggerEnemyOrbExplosion(enemy, damageMultiplier);
      }
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
        _applyCompanionIncomingDamage(comp, enemy.damage);
        comp.hitFlash = 1.0;
        if (enemy.isVampiric) {
          enemy.hp = min(enemy.maxHp, enemy.hp + enemy.damage * 0.18);
        }
        if (comp.currentHp <= 0) comp.isDead = true;
      }
    }
  }

  double _orbImpactDamageMultiplier(CosmicSurvivalEnemy enemy) {
    final tierMult = switch (enemy.tier) {
      EnemyTier.wisp => 1.15,
      EnemyTier.drone => 1.20,
      EnemyTier.sentinel => 1.40,
      EnemyTier.phantom => 1.30,
      EnemyTier.brute => 2.10,
      EnemyTier.colossus => 2.85,
    };
    // Split along the new axes: what it does (trait) and how it closes
    // (conduct) are separate contributions, where the variant conflated them.
    final traitMult = switch (enemy.trait) {
      EnemyTrait.breaker => 1.55,
      EnemyTrait.splitter => 1.15,
      EnemyTrait.summoner => 1.0,
      null => 1.0,
    };
    final conductMult = switch (enemy.conduct) {
      EnemyConduct.charge => enemy.hasHeavyBody ? 1.45 : 1.0,
      EnemyConduct.stalk => 1.15,
      EnemyConduct.standoff => 1.12,
      _ => 1.0,
    };
    final variantMult = traitMult * conductMult;
    final roleMult = enemy.role == CosmicEnemyRole.orbiter ? 1.15 : 1.0;
    return tierMult * variantMult * roleMult;
  }

  bool _enemyExplodesOnOrbImpact(CosmicSurvivalEnemy enemy) {
    // A breaker is built to crack the orb; a heavy charger arrives with
    // enough mass to do it too.
    if (enemy.trait == EnemyTrait.breaker ||
        (enemy.conduct == EnemyConduct.charge && enemy.hasHeavyBody)) {
      return true;
    }
    return enemy.tier == EnemyTier.brute || enemy.tier == EnemyTier.colossus;
  }

  double _enemyOrbExplosionRadius(CosmicSurvivalEnemy enemy) {
    final base = switch (enemy.tier) {
      EnemyTier.brute => 95.0,
      EnemyTier.colossus => 135.0,
      _ => 70.0,
    };
    final traitBoost = enemy.trait == EnemyTrait.breaker ? 18.0 : 0.0;
    final conductBoost =
        (enemy.conduct == EnemyConduct.charge && enemy.hasHeavyBody)
        ? 12.0
        : 0.0;
    return base + traitBoost + conductBoost;
  }

  double _enemyOrbExplosionDamage(CosmicSurvivalEnemy enemy) {
    final base = switch (enemy.tier) {
      EnemyTier.brute => enemy.damage * 1.6,
      EnemyTier.colossus => enemy.damage * 2.4,
      _ => enemy.damage * 1.1,
    };
    final traitBoost = enemy.trait == EnemyTrait.breaker ? 1.4 : 1.0;
    final conductBoost =
        (enemy.conduct == EnemyConduct.charge && enemy.hasHeavyBody)
        ? 1.25
        : 1.0;
    return base * traitBoost * conductBoost;
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
      if (!_appendCompanionProjectile(
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
      )) {
        break;
      }
    }
  }

  CompanionRunStats _runStatsFor(int slot) =>
      companionRunStats.putIfAbsent(slot, () => CompanionRunStats());

  void _damageEnemy(
    CosmicSurvivalEnemy enemy,
    double damage, {
    int? sourceSlotIndex,
    bool fromPipSpecial = false,
  }) {
    damage *= _companionOutgoingDamageMultiplier(
      sourceSlotIndex,
      vsBoss: false,
    );
    if (enemy.hasBulwark && enemy.hpFraction > 0.5) {
      damage *= 0.72;
    }
    if (enemy.isRelentless && enemy.slowTimer > 0) {
      damage *= 0.88;
    }
    final hpBefore = enemy.hp;
    enemy.hp -= damage;
    enemy.hitFlash = 1.0;

    if (powerUps.hasBerserker && orb.hpPercent < 0.3) {
      enemy.hp -= damage;
    }

    if (sourceSlotIndex != null) {
      final dealt = hpBefore - max(enemy.hp, 0.0);
      if (dealt > 0) _runStatsFor(sourceSlotIndex).damageDealt += dealt;
    }

    if (enemy.hp <= 0) {
      _killEnemy(
        enemy,
        sourceSlotIndex: sourceSlotIndex,
        fromPipSpecial: fromPipSpecial,
      );
    }
  }

  void _killEnemy(
    CosmicSurvivalEnemy enemy, {
    int? sourceSlotIndex,
    bool grantAlchemyReward = true,
    bool fromPipSpecial = false,
  }) {
    if (enemy.isDead) return;
    enemy.isDead = true;
    stats.kills++;
    if (sourceSlotIndex != null) _runStatsFor(sourceSlotIndex).kills++;
    final baseReward = tierShardReward(enemy.tier);
    var scoreGain = enemy.isElite ? (baseReward * 2.5).round() : baseReward;
    stats.score += scoreGain;
    _alchemicalProgressPoints += _alchemicalProgressPointsForEnemy(enemy);
    final meterGain = switch (enemy.tier) {
      EnemyTier.wisp => 3.0,
      EnemyTier.drone => 5.0,
      EnemyTier.sentinel => 7.0,
      EnemyTier.phantom => 10.0,
      EnemyTier.brute => 13.0,
      EnemyTier.colossus => 18.0,
    };
    // Pip+Plant passive: enemies killed grow alchemical meters 50% more.
    final pipPlantBonus = () {
      if (sourceSlotIndex == null) return 1.0;
      final c = activeCompanions[sourceSlotIndex];
      if (c == null) return 1.0;
      return (c.member.family.toLowerCase() == 'pip' &&
              c.member.element == 'Plant')
          ? 1.50
          : 1.0;
    }();
    final alchemyValue =
        meterGain *
        (enemy.isElite ? 1.35 : 1.0) *
        (spawner.currentMutator == SurvivalWaveMutator.manaFlux ? 1.18 : 1.0) *
        pipPlantBonus;
    if (grantAlchemyReward && !ship.isDead) {
      final alchemyPacingMultiplier =
          _alchemicalKillPacingMultiplier * _alchemicalWaveStabilityMultiplier;
      _grantAlchemy(
        alchemyValue * _alchemyMeterGainMultiplier * alchemyPacingMultiplier,
      );
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
        final before = orb.currentHp;
        orb.currentHp = min(
          orb.maxHp,
          orb.currentHp + companion.maxHp * bloodPactHeal,
        );
        _recordHeal(
          orb.currentHp - before,
          target: 2,
          sourceSlot: sourceSlotIndex,
        );
      }
      // Mane+Plant rooted explosion: if the enemy was tagged by a
      // Mane+Plant pierce and is still in the root window, blow up.
      if (enemy.maneRootSlot != null && enemy.maneRootTimer > 0) {
        const explodeRadius = 165.0;
        final explodeDamage = (companion?.elemAtk ?? 4) * 2.1;
        _visitEnemiesNear(enemy.position, explodeRadius, (other) {
          if (identical(other, enemy)) return false;
          if (!_withinRange(enemy.position, other.position, explodeRadius)) {
            return false;
          }
          _damageEnemy(
            other,
            explodeDamage,
            sourceSlotIndex: enemy.maneRootSlot,
          );
          other.maneRootSlot = enemy.maneRootSlot;
          other.maneRootTimer = max(other.maneRootTimer, 1.4);
          other.slowTimer = max(other.slowTimer, 1.4);
          other.slowMultiplier = 0;
          return false;
        });
        _spawnHitSpark(enemy.position, elementColor('Plant'));
      }
      // Horn special on-kill effects. Gated by hornSpecialActiveWindow
      // so basic-attack kills outside the cast window don't trigger.
      if (companion != null &&
          companion.member.family.toLowerCase() == 'horn' &&
          companion.hornSpecialActiveWindow > 0) {
        _applyHornSpecialKillEffect(companion, enemy, sourceSlotIndex);
      }
      // Pip element-on-kill placements (Fire/Dust/Crystal/Dark). Gated
      // by source: design says Fire/Dust/Crystal pools come from
      // SPECIAL-ability kills only, while Dark's black hole is a
      // PASSIVE that fires on AUTO-attack kills only. The flag is set
      // at the projectile-collision site for moving pip-special darts;
      // downstream tick/splash kills won't re-trigger placements.
      _spawnPipKillPlacement(
        sourceSlotIndex,
        companion,
        enemy.position,
        fromPipSpecial: fromPipSpecial,
      );
      // Pip+Spirit passive: kills accumulate; at threshold, fire an
      // "empower" window (basic-haste) and reset the counter.
      // Threshold scales DOWN with intelligence (procs faster) and
      // window duration scales UP with intelligence.
      if (companion != null &&
          companion.member.family.toLowerCase() == 'pip' &&
          companion.member.element == 'Spirit') {
        companion.abilityKillStacks++;
        // sourceSlotIndex is non-null in this branch (outer guard).
        final spiritIntel = _effectiveIntelligence(sourceSlotIndex);
        final thresholdScale = _hornStatScale(
          spiritIntel,
          perPoint: -0.10,
          min: 0.55,
          max: 1.20,
        );
        final spiritThreshold = (8 * thresholdScale).round().clamp(4, 10);
        if (companion.abilityKillStacks >= spiritThreshold) {
          companion.abilityKillStacks = 0;
          final windowScale = _hornStatScale(
            spiritIntel,
            perPoint: 0.12,
            min: 0.85,
            max: 1.50,
          );
          companion.pipSpiritEmpowerTimer = max(
            companion.pipSpiritEmpowerTimer,
            6.0 * windowScale,
          );
          _spawnHitSpark(companion.position, elementColor('Spirit'));
        }
      }
      // Mask+Spirit passive: enemies killed near a Mask+Spirit companion
      // drop wisps that the companion gathers; at the threshold they
      // erupt in a wide burst that damages everything around the orb.
      if (companion != null &&
          companion.member.family.toLowerCase() == 'mask' &&
          companion.member.element == 'Spirit') {
        companion.abilityKillStacks++;
        const wispThreshold = 6;
        if (companion.abilityKillStacks >= wispThreshold) {
          companion.abilityKillStacks = 0;
          final burstDamage = companion.elemAtk * 1.6;
          const burstRadius = 220.0;
          _visitEnemiesNear(companion.position, burstRadius, (target) {
            if (target.isDead) return false;
            _damageEnemy(target, burstDamage, sourceSlotIndex: sourceSlotIndex);
            return false;
          });
          _spawnHitSpark(companion.position, elementColor('Spirit'));
        }
      }
      // Kin+Spirit wisp feeding: enemies killed by the spirit kin's
      // auto-attacks tier up its wisp companion. Per-frame loop reads
      // kinSpiritWispKills and bumps the wisp's tier at thresholds.
      if (companion != null &&
          companion.member.family.toLowerCase() == 'kin' &&
          companion.member.element == 'Spirit') {
        companion.kinSpiritWispKills++;
      }
    }

    _spawnHitSpark(enemy.position, elementColor(enemy.element));
    if (enemy.trait == EnemyTrait.splitter && enemies.length < 220) {
      final shards = spawner.spawnSplitterShards(enemy);
      enemies.addAll(shards);
      for (final shard in shards) {
        _spawnHitSpark(shard.position, elementColor(shard.element));
      }
    }
    _triggerEliteDeathAffix(enemy, sourceSlotIndex: sourceSlotIndex);

    if (powerUps.hasElementalFury) {
      final splashDamage = 10.0 + powerUps.elementalFuryLevel * 8.0;
      _visitEnemiesNear(enemy.position, 80, (other) {
        if (_withinRange(other.position, enemy.position, 80)) {
          _damageEnemy(other, splashDamage, sourceSlotIndex: sourceSlotIndex);
        }
        return false;
      });
    }
  }

  void _grantAlchemy(double value) {
    if (ship.isDead || value <= 0) return;
    alchemicalMeter = min(alchemicalMeterMax, alchemicalMeter + value);
  }

  void _updateAlchemicalMeterDisplay(double dt) {
    final target = (alchemicalMeter / alchemicalMeterMax).clamp(0.0, 1.0);
    final isRising = target > _alchemicalMeterDisplayFrac;
    final rate = isRising ? 7.5 : 11.0;
    final blend = 1.0 - exp(-rate * dt);
    _alchemicalMeterDisplayFrac +=
        (target - _alchemicalMeterDisplayFrac) * blend;
    if ((_alchemicalMeterDisplayFrac - target).abs() < 0.0008) {
      _alchemicalMeterDisplayFrac = target;
    }
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
      _visitEnemiesNear(enemy.position, blastRadius, (other) {
        if (identical(other, enemy)) return false;
        if (_withinRange(enemy.position, other.position, blastRadius)) {
          _damageEnemy(other, blastDamage, sourceSlotIndex: sourceSlotIndex);
        }
        return false;
      });
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
          _applyCompanionIncomingDamage(comp, blastDamage * 0.7);
          comp.hitFlash = 1.0;
          if (comp.currentHp <= 0) comp.isDead = true;
        }
      }
      _spawnHitSpark(enemy.position, const Color(0xFFFFA34A));
    }
  }

  void _triggerEnemyOrbExplosion(
    CosmicSurvivalEnemy enemy,
    double damageMultiplier,
  ) {
    final radius = _enemyOrbExplosionRadius(enemy);
    final damage = _enemyOrbExplosionDamage(enemy) * damageMultiplier;
    final blastColor = elementColor(enemy.element);

    // Big plume + ring of sparks.
    _spawnHitSpark(enemy.position, blastColor);
    final sparkCount = enemy.tier == EnemyTier.colossus ? 14 : 9;
    for (var i = 0; i < sparkCount; i++) {
      final angle = (i / sparkCount) * pi * 2;
      _spawnHitSpark(
        Offset(
          enemy.position.dx + cos(angle) * (radius * 0.45),
          enemy.position.dy + sin(angle) * (radius * 0.45),
        ),
        blastColor,
      );
    }

    // Splash damage to the orb falls off with distance from impact center.
    final orbDist = (enemy.position - orb.position).distance;
    if (orbDist <= radius) {
      final falloff = (1.0 - orbDist / radius).clamp(0.4, 1.0);
      _damageOrb(damage * falloff);
    }

    // Splash damage to the ship and companions if they got too close.
    if (!ship.isDead && _withinRange(enemy.position, ship.position, radius)) {
      ship.currentHp -= damage * 0.55;
      ship.hitFlash = 1.0;
      if (ship.currentHp <= 0) {
        ship.isDead = true;
        _shipRespawnTimer = 0;
      }
    }
    for (final comp in activeCompanions.values) {
      if (comp.isDead) continue;
      if (_withinRange(enemy.position, comp.position, radius)) {
        _applyCompanionIncomingDamage(comp, damage * 0.65);
        comp.hitFlash = 1.0;
        if (comp.currentHp <= 0) comp.isDead = true;
      }
    }
  }

  void _triggerMirrorShieldPulse(Offset impactPos, double incomingDamage) {
    final pulseRadius = 96.0;
    final pulseDamage = max(10.0, incomingDamage * 2.5);
    const reflectColor = Color(0xFFB3E5FC);
    _spawnBeam(orb.position, impactPos, reflectColor, width: 3.2, life: 0.12);
    _spawnHitSpark(impactPos, reflectColor);
    _visitEnemiesNear(impactPos, pulseRadius, (other) {
      if (_withinRange(other.position, impactPos, pulseRadius)) {
        _damageEnemy(other, pulseDamage);
      }
      return false;
    });
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
    final primary = activeBoss;
    if (primary != null && !primary.isDead) {
      _updateBossInstance(dt, primary);
    }
    for (final extra in extraBosses) {
      if (extra.isDead) continue;
      _updateBossInstance(dt, extra);
    }
  }

  void _updateBossInstance(double dt, SurvivalBoss boss) {
    boss.hitFlash = (boss.hitFlash - dt * 4).clamp(0, 1);
    if (boss.isSpawning) {
      _updateBossEntrance(dt, boss);
      return;
    }
    boss.phaseTimer += dt;

    switch (boss.discipline) {
      case SurvivalBossDiscipline.riftcaller:
        _updateBossRiftcaller(dt, boss);
      case SurvivalBossDiscipline.siegebreaker:
        _updateBossSiegebreaker(dt, boss);
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

    _updateTitanicBossTraits(dt, boss);

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
      SurvivalBossDiscipline.siegebreaker => tangent * 22,
      SurvivalBossDiscipline.riftcaller => tangent * 138,
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
      case SurvivalBossDiscipline.riftcaller:
        return (520.0, 2.05, 3.2);
      case SurvivalBossDiscipline.siegebreaker:
        return (270.0, 1.26, 2.7);
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
      case SurvivalBossDiscipline.riftcaller:
        return Curves.easeInOutQuart;
      case SurvivalBossDiscipline.siegebreaker:
        return Curves.easeOutExpo;
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

  void _updateBossSiegebreaker(double dt, SurvivalBoss boss) {
    final anchor = orb.position;
    final toAnchor = anchor - boss.position;
    final dist = toAnchor.distance;
    final norm = dist > 1
        ? Offset(toAnchor.dx / dist, toAnchor.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    final targetDist = boss.hpFraction < 0.45 ? 128.0 : 168.0;
    final radialForce = (dist - targetDist) * 0.82;
    final strafe = sin(boss.phaseTimer * 1.8) * boss.speed * 0.34;
    boss.position += (norm * radialForce + tangent * strafe) * dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    // Heavy periodic cone fire toward core defenses.
    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = boss.hpFraction < 0.45 ? 1.1 : 1.55;
      final target =
          _nearestCompanionPosition(boss.position) ??
          (ship.isDead ? orb.position : ship.position);
      final aim = atan2(
        target.dy - boss.position.dy,
        target.dx - boss.position.dx,
      );
      for (var i = 0; i < 7; i++) {
        final a = aim + (i - 3) * 0.16;
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: a,
            element: boss.template.element,
            damage: 10 + boss.level * 2.1,
            speed: 240,
            radius: 6.6,
            life: 3.0,
          ),
        );
      }
    }

    // Shockwave push + zone clear to create a distinct "siege" rhythm.
    boss.chargeTimer -= dt;
    if (boss.chargeTimer <= 0) {
      boss.chargeTimer = max(3.0, 5.6 - boss.level * 0.08);
      final waveRadius = 210.0;
      final waveDamage = 11.0 + boss.level * 1.35;
      _spawnDetonationBurst(
        boss.position,
        boss.color.withValues(alpha: 0.85),
        waveRadius * 0.75,
      );
      _visitEnemiesNear(boss.position, waveRadius, (enemy) {
        final pushDir = enemy.position - boss.position;
        final d = pushDir.distance;
        if (d <= waveRadius) {
          final falloff = (1.0 - (d / waveRadius)).clamp(0.2, 1.0);
          _applyEnemyKnockback(enemy, pushDir, 320.0 * falloff);
        }
        return false;
      });
      if (_withinRange(boss.position, orb.position, waveRadius + 34)) {
        _damageOrb(waveDamage * 0.7);
      }
      if (!ship.isDead &&
          _withinRange(boss.position, ship.position, waveRadius + 14)) {
        ship.currentHp -= waveDamage * 0.8;
        ship.hitFlash = 1.0;
        if (ship.currentHp <= 0) {
          ship.isDead = true;
          _shipRespawnTimer = 0;
        }
      }
      for (final comp in activeCompanions.values) {
        if (comp.isDead) continue;
        if (_withinRange(boss.position, comp.position, waveRadius + 12)) {
          _applyCompanionIncomingDamage(comp, waveDamage * 1.05);
          comp.hitFlash = 1.0;
          if (comp.currentHp <= 0) comp.isDead = true;
        }
      }
    }

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(5.4, 9.2 - boss.level * 0.08);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      for (final add in adds.take(3)) {
        add.target =
            (add.conduct == EnemyConduct.charge && add.hasHeavyBody)
            ? CosmicEnemyTarget.orb
            : CosmicEnemyTarget.companion;
      }
      enemies.addAll(adds.take(3));
    }
  }

  void _updateBossRiftcaller(double dt, SurvivalBoss boss) {
    final anchor = ship.isDead ? orb.position : ship.position;
    final toAnchor = anchor - boss.position;
    final dist = toAnchor.distance;
    final norm = dist > 1
        ? Offset(toAnchor.dx / dist, toAnchor.dy / dist)
        : Offset.zero;
    final tangent = Offset(-norm.dy, norm.dx);
    // Riftcaller is a sniper-discipline boss; use its engagement ring with a
    // gentle breathing oscillation on top.
    final targetDist =
        boss.engagementRange + sin(boss.phaseTimer * 0.75) * 70.0;
    final radialForce = (dist - targetDist) * 0.42;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 1.1) *
        dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    // Rift lance: direct high-speed pressure line.
    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = max(1.0, 1.8 - boss.level * 0.03);
      final target = _nearestCompanionPosition(boss.position) ?? anchor;
      final shotAngle = atan2(
        target.dy - boss.position.dy,
        target.dx - boss.position.dx,
      );
      bossProjectiles.add(
        SurvivalBossProjectile(
          position: boss.position,
          angle: shotAngle,
          element: boss.template.element,
          damage: 12 + boss.level * 2.2,
          speed: 320,
          radius: 5.4,
          life: 2.8,
        ),
      );
    }

    // Rift volley: off-axis portals fire crossing streams.
    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0) {
      boss.spreadTimer = max(2.8, 4.6 - boss.level * 0.04);
      final riftCount = boss.level >= 12 ? 4 : 3;
      for (var i = 0; i < riftCount; i++) {
        final a = boss.phaseTimer * 0.95 + (i / riftCount) * pi * 2;
        final riftPos = orb.position + Offset(cos(a) * 180, sin(a) * 180);
        final aim = atan2(anchor.dy - riftPos.dy, anchor.dx - riftPos.dx);
        for (final offset in [-0.14, 0.14]) {
          bossProjectiles.add(
            SurvivalBossProjectile(
              position: riftPos,
              angle: aim + offset,
              element: boss.template.element,
              damage: 8 + boss.level * 1.6,
              speed: 270,
              radius: 4.8,
              life: 3.4,
            ),
          );
        }
      }
    }

    // Steady add pressure from flanking lanes.
    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(6.2, 10.5 - boss.level * 0.08);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      for (final add in adds) {
        add.target = switch (add.role) {
          CosmicEnemyRole.shooter => CosmicEnemyTarget.orb,
          CosmicEnemyRole.hunter => CosmicEnemyTarget.ship,
          _ => CosmicEnemyTarget.companion,
        };
      }
      enemies.addAll(adds.take(5));
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
    // Conductor is an orbit-discipline boss; let its preferred ring drive
    // distance with a small breathing oscillation.
    final targetDist = boss.engagementRange + sin(boss.phaseTimer * 0.9) * 40.0;
    final radialForce = (dist - targetDist) * 0.48;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.8) *
        dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0) {
      boss.spreadTimer = max(2.0, 4.2 - boss.level * 0.06);
      final baseFanAngle = atan2(
        orb.position.dy - boss.position.dy,
        orb.position.dx - boss.position.dx,
      );
      final ringCount = boss.level >= 10 ? 8 : 6;
      for (var i = 0; i < ringCount; i++) {
        final a = baseFanAngle + (i / ringCount) * pi * 2;
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

  void _updateTitanicBossTraits(double dt, SurvivalBoss boss) {
    if (!boss.template.isTitanic || boss.template.colossalTrait == null) {
      return;
    }

    switch (boss.template.colossalTrait!) {
      case ColossalTrait.gravityWell:
        if (!ship.isDead) {
          final toBoss = boss.position - ship.position;
          final dist = toBoss.distance;
          if (dist > 1 && dist < 540) {
            final pull = (1.0 - (dist / 540)).clamp(0.0, 1.0);
            final strength = (38.0 + 64.0 * pull) * dt;
            ship.position = _clampToArena(
              ship.position +
                  Offset(toBoss.dx / dist, toBoss.dy / dist) * strength,
              padding: _arenaShipPadding,
            );
          }
        }

        for (final comp in activeCompanions.values) {
          if (comp.isDead) continue;
          final toBoss = boss.position - comp.position;
          final dist = toBoss.distance;
          if (dist <= 1 || dist >= 500) continue;
          final pull = (1.0 - (dist / 500)).clamp(0.0, 1.0);
          final strength = (30.0 + 54.0 * pull) * dt;
          comp.position +=
              Offset(toBoss.dx / dist, toBoss.dy / dist) * strength;
        }

        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 2.6;
          const ringCount = 10;
          for (var i = 0; i < ringCount; i++) {
            final a = (i / ringCount) * pi * 2 + boss.phaseTimer * 0.35;
            bossProjectiles.add(
              SurvivalBossProjectile(
                position: boss.position,
                angle: a,
                element: boss.template.element,
                damage: 7 + boss.level * 1.5,
                speed: 175,
                radius: 7.2,
                life: 3.6,
              ),
            );
          }
        }

      case ColossalTrait.riftStorm:
        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 3.1;
          final anchor = ship.isDead ? orb.position : ship.position;
          final riftCount = boss.level >= 12 ? 4 : 3;
          for (var i = 0; i < riftCount; i++) {
            final phase = boss.phaseTimer * 0.85 + i * (2 * pi / riftCount);
            final riftPos =
                orb.position + Offset(cos(phase) * 190, sin(phase) * 190);
            final aim = atan2(anchor.dy - riftPos.dy, anchor.dx - riftPos.dx);
            for (final spread in [-0.15, 0.0, 0.15]) {
              bossProjectiles.add(
                SurvivalBossProjectile(
                  position: riftPos,
                  angle: aim + spread,
                  element: boss.template.element,
                  damage: 8 + boss.level * 1.6,
                  speed: 255,
                  radius: 5.3,
                  life: 3.2,
                ),
              );
            }
            _spawnHitSpark(riftPos, boss.color);
          }
        }

      case ColossalTrait.novaPulse:
        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 4.6;
          final pulseRadius = boss.radius * 1.85;
          final pulseDamage = 11.0 + boss.level * 1.6;
          _spawnDetonationBurst(
            boss.position,
            boss.color.withValues(alpha: 0.86),
            pulseRadius * 0.75,
          );

          if (_withinRange(boss.position, orb.position, pulseRadius + 30)) {
            _damageOrb(pulseDamage * 0.75);
          }

          if (!ship.isDead &&
              _withinRange(boss.position, ship.position, pulseRadius + 10)) {
            ship.currentHp -= pulseDamage;
            ship.hitFlash = 1.0;
            if (ship.currentHp <= 0) {
              ship.isDead = true;
              _shipRespawnTimer = 0;
            }
          }

          for (final comp in activeCompanions.values) {
            if (comp.isDead) continue;
            if (_withinRange(boss.position, comp.position, pulseRadius + 12)) {
              _applyCompanionIncomingDamage(comp, pulseDamage * 1.15);
              comp.hitFlash = 1.0;
              if (comp.currentHp <= 0) comp.isDead = true;
            }
          }

          _visitEnemiesNear(boss.position, pulseRadius, (enemy) {
            final away = enemy.position - boss.position;
            final d = away.distance;
            if (d <= pulseRadius) {
              final falloff = (1.0 - (d / pulseRadius)).clamp(0.2, 1.0);
              _applyEnemyKnockback(enemy, away, 420.0 * falloff);
            }
            return false;
          });
        }
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

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(6.0, 10.2 - boss.level * 0.08);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      for (final add in adds.take(2)) {
        add.target = CosmicEnemyTarget.companion;
      }
      enemies.addAll(adds.take(2));
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
    // Artillery discipline → snipers per the spawner; honor their ring.
    final targetDist = boss.engagementRange;
    // Pull harder if the player closes the gap so artillery actually backs up.
    final radialPull = dist < targetDist * 0.6 ? 0.65 : 0.42;
    final radialForce = (dist - targetDist) * radialPull;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.6) *
        dt;
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

    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0) {
      boss.summonTimer = max(6.8, 11.0 - boss.level * 0.08);
      final adds = spawner.spawnBossAdds(
        boss,
        orb.position,
        size.x / _currentZoom,
        size.y / _currentZoom,
      );
      for (final add in adds.take(2)) {
        add.target = CosmicEnemyTarget.orb;
      }
      enemies.addAll(adds.take(2));
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
    final targetDist = boss.engagementRange + sin(boss.phaseTimer * 1.7) * 45.0;
    final radialForce = (dist - targetDist) * 0.75;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight) * dt;
    boss.angle = atan2(toAnchor.dy, toAnchor.dx);

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0) {
      boss.escortTimer = max(4.5, 8.5 - boss.level * 0.12);
      // Trickster blinks closer to its preferred engagement ring rather than
      // always slamming into 210u, so orbit/sniper trickster variants don't
      // immediately teleport into melee.
      final blinkAngle = _rng.nextDouble() * pi * 2;
      final blinkDist = (boss.engagementRange * 0.92).clamp(180.0, 520.0);
      boss.position =
          anchor +
          Offset(cos(blinkAngle) * blinkDist, sin(blinkAngle) * blinkDist);
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

      final orbAngle = atan2(
        orb.position.dy - boss.position.dy,
        orb.position.dx - boss.position.dx,
      );
      for (final offset in [-0.18, 0.18]) {
        bossProjectiles.add(
          SurvivalBossProjectile(
            position: boss.position,
            angle: orbAngle + offset,
            element: boss.template.element,
            damage: 7 + boss.level * 1.5,
            speed: 270,
            radius: 4.8,
            life: 3.0,
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
        _applyCompanionIncomingDamage(comp, (14 + boss.level * 2).toDouble());
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

      final orbitDist = boss.engagementRange;
      final norm = dist > 1
          ? Offset(toOrb.dx / dist, toOrb.dy / dist)
          : Offset.zero;
      final tangent = Offset(-norm.dy, norm.dx);
      final radialForce = (dist - orbitDist) * 0.8;
      boss.position +=
          (norm * radialForce + tangent * boss.speed * boss.strafeWeight) * dt;

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
    final orbitDist = boss.engagementRange;
    // Snipers are more eager to backpedal if pulled in close.
    final radialPull = boss.movementStyle == SurvivalBossMovementStyle.sniper
        ? 0.7
        : 0.5;
    final radialForce = (dist - orbitDist) * radialPull;
    final norm = Offset(toOrb.dx / dist, toOrb.dy / dist);
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.7) *
        dt;
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
    final targetDist = boss.engagementRange + sin(boss.phaseTimer * 1.5) * 60;
    final radialForce = (dist - targetDist) * 0.8;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.85) *
        dt;
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

    // Bulwarks usually plant themselves — orbiters keep their preferred ring,
    // chase-style ones get the old aggressive 145.
    final targetDist = boss.movementStyle == SurvivalBossMovementStyle.chase
        ? 145.0
        : boss.engagementRange;
    final tangent = Offset(-norm.dy, norm.dx);
    final radialForce = (dist - targetDist) * 0.75;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.55) *
        dt;

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
    final radialForce = (dist - boss.engagementRange) * 0.4;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.5) *
        dt;
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

    // Enraged warden always closes the gap; otherwise honor the boss's
    // preferred engagement ring so snipers stay back firing.
    final targetDist = boss.enraged ? 140.0 : boss.engagementRange;
    final tangent = Offset(-norm.dy, norm.dx);
    final radialForce = (dist - targetDist) * 0.65;
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.65) *
        dt;

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

  void damageBoss(
    double damage, {
    String? attackElement,
    int? sourceSlotIndex,
    SurvivalBoss? target,
  }) {
    final boss = target ?? activeBoss;
    if (boss == null || boss.isDead) return;

    damage *= _companionOutgoingDamageMultiplier(sourceSlotIndex, vsBoss: true);

    // Apply element effectiveness
    final effectiveDamage = attackElement != null
        ? damage *
              typeEffectivenessMultiplier(attackElement, [
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

    final hpBefore = boss.hp;
    boss.hp -= effectiveDamage;
    boss.hitFlash = 1.0;

    if (sourceSlotIndex != null) {
      final dealt = hpBefore - max(boss.hp, 0.0);
      if (dealt > 0) _runStatsFor(sourceSlotIndex).damageDealt += dealt;
    }

    if (boss.hp <= 0) {
      boss.isDead = true;
      stats.kills++;
      if (sourceSlotIndex != null) _runStatsFor(sourceSlotIndex).kills++;
      stats.score += (boss.template.health * 2).round();
      _spawnBossAlchemyReward(boss);
      _spawnHitSpark(boss.position, boss.color);
      if (identical(boss, activeBoss)) {
        // Promote the next alive extra boss to be the new primary so existing
        // single-boss-aware code paths keep targeting something.
        SurvivalBoss? promoted;
        for (final b in extraBosses) {
          if (!b.isDead) {
            promoted = b;
            break;
          }
        }
        if (promoted != null) {
          extraBosses.remove(promoted);
          activeBoss = promoted;
        } else {
          activeBoss = null;
        }
      } else {
        // Killed extra — leave in list so iteration still works; cleanup
        // happens between waves.
      }
    }
  }

  void _spawnBossAlchemyReward(SurvivalBoss boss) {
    if (ship.isDead) return;
    final baseValue = max(
      26.0,
      34.0 + boss.level * 8.0 + boss.radius * 0.45 + spawner.currentWave * 1.6,
    );
    final disciplineBonus = switch (boss.discipline) {
      SurvivalBossDiscipline.standard => 1.0,
      SurvivalBossDiscipline.artillery => 1.08,
      SurvivalBossDiscipline.trickster => 1.06,
      SurvivalBossDiscipline.duelist => 1.08,
      SurvivalBossDiscipline.conductor => 1.12,
      SurvivalBossDiscipline.siegebreaker => 1.14,
      SurvivalBossDiscipline.riftcaller => 1.16,
    };
    _grantAlchemy(baseValue * disciplineBonus * _alchemyMeterGainMultiplier);
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
          _applyCompanionIncomingDamage(comp, proj.damage);
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

  void _updateEnemyProjectiles(
    double dt,
    List<Projectile> interceptors,
    List<Projectile> reflectors,
  ) {
    for (final proj in enemyProjectiles) {
      proj.position = Offset(
        proj.position.dx + cos(proj.angle) * proj.speed * dt,
        proj.position.dy + sin(proj.angle) * proj.speed * dt,
      );
      proj.life -= dt;

      // Horn+Ice / Horn+Light reflect: try a reflect first. If the
      // shot bounces, skip the intercept absorb path so the same
      // shot can fly back instead of being eaten.
      if (!proj.friendlyFire &&
          reflectors.isNotEmpty &&
          _attemptProjectileReflect(proj, reflectors)) {
        continue;
      }

      // Kin+Dust field clouds: enemy projectiles passing through any
      // Dust cloud have a high chance to miss each tick they're
      // inside (bumped to ~80% so the cloud feels like real cover).
      if (!proj.friendlyFire && _isInsideAnyKinDustCloud(proj.position)) {
        if (_rng.nextDouble() < 0.80) {
          proj.life = 0;
          continue;
        }
      }

      if (_consumeCompanionInterceptionAt(
        proj.position,
        proj.radius,
        interceptors,
      )) {
        proj.life = 0;
        continue;
      }

      // Wing+Dust disorient: friendly-fire shots damage other enemies
      // and ignore the orb/ship/companions entirely.
      if (proj.friendlyFire) {
        var consumed = false;
        _visitEnemiesNear(proj.position, proj.radius + 18, (other) {
          if (other.isDead) return false;
          if (!_withinRange(
            proj.position,
            other.position,
            proj.radius + other.radius,
          )) {
            return false;
          }
          _damageEnemy(other, proj.damage);
          consumed = true;
          return true;
        });
        if (consumed) {
          proj.life = 0;
          continue;
        }
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
            _applyCompanionIncomingDamage(comp, proj.damage);
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

  void resolveAbilityHit(
    Projectile projectile,
    CosmicSurvivalEnemy enemy, {
    required bool killed,
  }) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorHit(projectile, enemy);
      return;
    }
    if (projectile.abilityFamily == 'mask') {
      // Mask traps run a per-element on-contact dispatcher first.
      // Some elements (Light instakill, Dark yeet, Crystal split,
      // Fire pool spawn, Lightning field grow, Blood drain marker,
      // Spirit ship-only collection) need custom logic on top of (or
      // instead of) the generic hitEffect application.
      final consumed = _resolveMaskTrapHit(projectile, enemy);
      if (consumed) {
        if (killed) resolveAbilityKill(projectile, enemy);
        return;
      }
    }
    _applyAbilityEffectToEnemy(
      projectile.hitEffect,
      enemy,
      projectile.position,
      projectile.effectPower,
      projectile.effectRadius,
      projectile.effectDuration,
      sourceSlotIndex: projectile.sourceSlotIndex,
    );
    if (killed) resolveAbilityKill(projectile, enemy);
  }

  /// Mask-family on-contact dispatcher. Returns true when the per-element
  /// behavior fully handles the hit (skip generic hitEffect dispatch).
  /// Returns false to fall through to the generic pipeline (Air knockback,
  /// Water splash, Mud slow, etc. already work as-is).
  bool _resolveMaskTrapHit(Projectile projectile, CosmicSurvivalEnemy enemy) {
    final element = projectile.element ?? '';
    switch (element) {
      case 'Air':
        // Mark the trap as "just activated" — the renderer reads
        // abilityGrowthTimer to brighten + grow the visual briefly,
        // then it decays back to ambient. Fall through to generic
        // dispatch so the knockback actually fires.
        projectile.abilityGrowthTimer = 1.0;
        return false;

      case 'Light':
        // Void: any contact instantly kills the enemy (skip the 20%
        // execute clause — the void is always lethal). Trap expires
        // with a bright collapse flash via abilityGrowthTimer.
        _damageEnemy(
          enemy,
          enemy.hp + 1,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        projectile.abilityGrowthTimer = 1.0;
        // Don't expire instantly — give the renderer 0.4s to play
        // the collapse, then the per-frame life tick clears it.
        projectile.life = min(projectile.life, 0.4);
        return true;

      case 'Dark':
        // Yeet: instead of the generic pull, sling the enemy hard
        // away from the void hole (and slow on landing).
        final dir = enemy.position - projectile.position;
        final dist = dir.distance;
        if (dist > 0.01) {
          final norm = dir / dist;
          enemy.knockbackVelocity += norm * 820.0;
          enemy.position += norm * 48.0;
        }
        enemy.slowTimer = max(enemy.slowTimer, 0.9);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.55);
        return true;

      case 'Crystal':
        // On contact each large crystal shatters into 3 smaller
        // crystals that deal damage to nearby enemies. Direct hit
        // damage applies too. Brief shatter flash before the parent
        // expires so the burst reads on screen.
        _damageEnemy(
          enemy,
          projectile.damage,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        _spawnMaskCrystalShards(projectile, enemy.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.3);
        return true;

      case 'Fire':
        // Fire ball: on contact spawn a fire pool zone that DoTs.
        // Direct ball damage applies too. Brief ignition flash, then
        // the ball expires (pool persists).
        _damageEnemy(
          enemy,
          projectile.damage,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        _spawnMaskFirePool(projectile, projectile.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.35);
        return true;

      case 'Lightning':
        // Field grows on each hit (bigger radius, longer DoT). Damage
        // still ticks via tickEffect=chain (generic pipeline handles it).
        const radCap = 260.0;
        projectile.effectRadius = min(radCap, projectile.effectRadius + 14.0);
        projectile.life = min(projectile.life + 0.6, 18.0);
        return false; // still apply generic chain hit

      case 'Blood':
        // Tag enemy for permanent drain. Survival tick scans tagged
        // enemies and pulls HP every frame, splitting it as heals.
        enemy.maskBloodDrainSlot =
            projectile.sourceSlotIndex ?? enemy.maskBloodDrainSlot;
        return false; // also apply the generic leech contact pulse

      case 'Spirit':
        // Spirit wisps are collected only by the ship — don't burn
        // wisp value on accidental enemy contact.
        return true;

      default:
        return false;
    }
  }

  void _spawnMaskCrystalShards(Projectile parent, Offset at) {
    final baseAngle = _rng.nextDouble() * pi * 2;
    for (var i = 0; i < 3; i++) {
      final a = baseAngle + i * (pi * 2 / 3);
      const r = 18.0;
      final pos = Offset(at.dx + cos(a) * r, at.dy + sin(a) * r);
      _appendCompanionProjectile(
        Projectile(
          position: pos,
          angle: 0,
          element: parent.element,
          damage: parent.damage * 0.55,
          life: 4.0,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: max(0.9, parent.radiusMultiplier * 0.55),
          visualScale: max(1.0, parent.visualScale * 0.55),
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: parent.sourceSlotIndex,
          abilityFamily: 'mask',
          hitEffect: AbilityEffectKind.splash,
          effectPower: parent.effectPower * 0.55,
          effectRadius: max(60.0, parent.effectRadius * 0.65),
          effectDuration: 0,
        ),
      );
    }
  }

  // Mask+Plant: each cast feeds the existing vine instead of stacking
  // a new one. 100 casts → maximum vine. We repurpose effectStacks as
  // the cast counter and scale snare / effect / visual off it. The
  // first cast spawns a fresh vine; subsequent casts find that vine
  // (same source slot, mask+Plant, stationary) and pump its counter.
  static const int _maskPlantMaxFeeds = 100;

  void _feedOrSpawnMaskPlantVine(
    int slotIndex,
    List<Projectile> specialProjectiles,
  ) {
    if (specialProjectiles.isEmpty) return;
    Projectile? existing;
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'mask' &&
          p.element == 'Plant' &&
          p.stationary) {
        existing = p;
        break;
      }
    }
    if (existing == null) {
      // First cast — drop the seed vine, mark its feed count at 1.
      final seed = specialProjectiles.first;
      seed.effectStacks = 1;
      _applyMaskPlantVineFeed(seed, 1);
      // Sprout burst: first plant on the field gets the "new tendril
      // unlocked" burst since this is also the first tendril.
      _playMaskPlantFeedAnimation(seed, newTendril: true);
      _appendCompanionProjectile(seed);
      return;
    }
    // Re-use existing vine. Bump its feed counter, refresh life, and
    // re-anchor to the new cast position so the player can re-aim it
    // (within reason — only nudge, don't teleport).
    final newSeed = specialProjectiles.first;
    final prevFeeds = existing.effectStacks;
    final feeds = (prevFeeds + 1).clamp(1, _maskPlantMaxFeeds);
    final newTendril = (feeds ~/ 10) != (prevFeeds ~/ 10);
    existing.effectStacks = feeds;
    existing.life = max(existing.life, newSeed.life);
    // Gentle re-anchor: move at most 60px toward the new cast spot so
    // the vine drifts toward where the player keeps targeting.
    final delta = newSeed.position - existing.position;
    final dist = delta.distance;
    if (dist > 0.01) {
      final nudge = min(60.0, dist);
      existing.position += delta * (nudge / dist);
    }
    _applyMaskPlantVineFeed(existing, feeds);
    _playMaskPlantFeedAnimation(existing, newTendril: newTendril);
  }

  // Feed animation: brief root flash (consumed by the renderer via
  // `abilityGrowthTimer`) + a burst of particles shooting outward
  // from the root. A bigger, brighter burst when a new tendril just
  // sprouted (every 10 feeds).
  void _playMaskPlantFeedAnimation(
    Projectile vine, {
    required bool newTendril,
  }) {
    // Renderer reads this timer to pulse the trunk + brighten strokes.
    // Encode "is this a tendril-unlock flash?" by going above 1.0 so
    // the renderer can branch on it.
    vine.abilityGrowthTimer = newTendril ? 2.0 : 1.0;
    // Spawn outward particle burst (cheap — caps the global vfx pool).
    if (_vfx.length >= 145) return;
    final plant = elementColor('Plant');
    final bright = Color.lerp(plant, const Color(0xFFFFFFFF), 0.55)!;
    final count = newTendril ? 18 : 9;
    for (var i = 0; i < count; i++) {
      if (_vfx.length >= 150) break;
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 90 + _rng.nextDouble() * 140;
      _vfx.add(
        _VfxParticle(
          x: vine.position.dx,
          y: vine.position.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: (newTendril ? 1.8 : 1.4) + _rng.nextDouble() * 1.4,
          life: 0.45 + _rng.nextDouble() * 0.35,
          color: i.isEven ? bright : plant,
        ),
      );
    }
    if (newTendril) {
      // Extra upward "sprout" jet so the unlock reads.
      for (var i = 0; i < 8; i++) {
        if (_vfx.length >= 150) break;
        final a = -pi / 2 + (_rng.nextDouble() - 0.5) * 0.9;
        final spd = 130 + _rng.nextDouble() * 150;
        _vfx.add(
          _VfxParticle(
            x: vine.position.dx,
            y: vine.position.dy,
            vx: cos(a) * spd,
            vy: sin(a) * spd,
            size: 1.6 + _rng.nextDouble() * 1.4,
            life: 0.55 + _rng.nextDouble() * 0.35,
            color: i.isEven ? bright : plant,
          ),
        );
      }
    }
  }

  void _applyMaskPlantVineFeed(Projectile vine, int feeds) {
    // Linear grow from initial → max over _maskPlantMaxFeeds casts.
    final t = (feeds / _maskPlantMaxFeeds).clamp(0.0, 1.0);
    // Initial values from the spec are kept as the floor; max values
    // give a meaty late-game vine without locking the whole arena.
    const baseSnare = 90.0;
    const maxSnare = 300.0;
    const baseEffect = 90.0;
    const maxEffect = 320.0;
    const baseVisual = 2.4;
    const maxVisual = 6.5;
    const baseRadius = 2.4;
    const maxRadius = 6.5;
    vine.snareRadius = baseSnare + (maxSnare - baseSnare) * t;
    vine.snareMoveMultiplier = (0.5 - 0.40 * t).clamp(0.10, 0.50);
    vine.effectRadius = baseEffect + (maxEffect - baseEffect) * t;
    vine.visualScale = baseVisual + (maxVisual - baseVisual) * t;
    vine.radiusMultiplier = baseRadius + (maxRadius - baseRadius) * t;
    // Per-tick damage scales with feed count — late-game vine is a
    // real threat, early vine is a chip-and-snare.
    vine.effectPower = vine.effectPower == 0
        ? 1.0 + 5.0 * t
        : max(vine.effectPower, 1.0 + 5.0 * t);
  }

  // ── Kin support-path activation ────────────────────────────────
  /// Routes a kin's cast to the per-element activation handler. Most
  /// kins just flip a timer (Fire/Lava/Steam/Dark/Blood/Lightning) or
  /// initiate a charge (Ice). A few spawn a one-shot entity (Spirit
  /// wisp) or persistent additive placement (Dust cloud).
  void _activateKinSupportPath(
    CosmicSurvivalCompanion comp,
    double fireAngle,
    Offset attackTarget,
  ) {
    final beauty = _effectiveBeauty(comp.slotIndex);
    final intel = _effectiveIntelligence(comp.slotIndex);
    final element = comp.member.element;
    final slot = comp.slotIndex;
    switch (element) {
      case 'Fire':
        // Fire kin is now a pure passive (see isPassiveOnlyCosmicAbility).
        // Activation is wired through the orb-death check in the kin
        // support tick — no cast trigger needed.
        break;
      case 'Lava':
        // 9s plate window. Beauty scales splash damage (read on hit).
        comp.kinLavaPlateTimer =
            9.0 * _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.40);
        break;
      case 'Ice':
        // Begin charge. Long base wind-up (4s) so the cast reads as
        // a heavy ult; Intelligence trims it slightly. Release radius
        // + slow duration scale on stats at fire time.
        final chargeTime =
            4.0 * _hornStatScale(intel, perPoint: -0.06, min: 0.70, max: 1.15);
        comp.kinIceChargeTimer = chargeTime;
        comp.kinIceChargeTotal = chargeTime;
        break;
      case 'Steam':
        // Boiler buff window — 10s base, scales with Intelligence.
        comp.kinSteamBoilerTimer =
            10.0 * _hornStatScale(intel, perPoint: 0.12, min: 0.80, max: 1.60);
        comp.kinSteamBoilerStacks = 0;
        comp.kinSteamStackDecayTimer = 2.0;
        break;
      case 'Lightning':
        // Tesla charge window — kin locked in place, ally autos chain.
        // 10s base, Intelligence stretches to ~14s. Per spec: long
        // sustained charge that telegraphs heavily to the player.
        comp.kinLightningChargeTimer =
            10.0 * _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.40);
        break;
      case 'Dust':
        // Field-placed cloud — first cast places one, subsequent casts
        // add more. Cap at 10 active clouds.
        _spawnKinDustCloud(slot, attackTarget, beauty, intel);
        break;
      case 'Mud':
        // Apply ship enchant — ship leaves mud trail while > 0.
        // Nerfed: 5s base (was 10s), Int stretches modestly.
        comp.kinMudShipEnchantTimer =
            5.0 * _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.40);
        break;
      case 'Spirit':
        _spawnOrRefreshKinSpiritWisp(comp);
        break;
      case 'Earth':
        _spawnKinEarthWallArc(comp, fireAngle, beauty);
        break;
      case 'Dark':
        // Void cloak — companions untargetable.
        comp.kinDarkCloakTimer =
            7.0 * _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.50);
        break;
      case 'Blood':
        // Blood pact — damage→team heal share window.
        comp.kinBloodPactTimer =
            9.0 * _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.50);
        break;
    }
    // Suppress unused warning when no element matched — beauty/fire
    // angle aren't needed by every element handler.
    if (beauty < 0 || fireAngle.isNaN) return;
  }

  // Kin+Earth: lay a curved arc of indestructible stone wall segments
  // centered on the ORB, facing the cast direction. The arc spans ~120°
  // so it covers the front without enclosing the orb entirely. Segments
  // shove enemies back on contact (knockback hitEffect) and reflect
  // enemy projectiles, but never take damage — they time out.
  void _spawnKinEarthWallArc(
    CosmicSurvivalCompanion comp,
    double facingAngle,
    double beauty,
  ) {
    final segCount = 7 + (beauty.clamp(1.0, 5.0) - 1.0).round();
    const arcSpanRad = 2.094; // ~120° front arc
    // Arc center is the orb's position; arc radius gives a stand-off
    // so enemies can't crowd the orb directly.
    final center = orb.position;
    const arcRadius = 110.0;
    final centerAngle = facingAngle;
    final lifeSeconds =
        12.0 * _hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40);
    for (var i = 0; i < segCount; i++) {
      final t = segCount == 1 ? 0.5 : i / (segCount - 1).toDouble();
      final a = centerAngle - arcSpanRad / 2 + arcSpanRad * t;
      final pos = Offset(
        center.dx + cos(a) * arcRadius,
        center.dy + sin(a) * arcRadius,
      );
      _appendCompanionProjectile(
        Projectile(
          position: pos,
          angle: 0,
          element: 'Earth',
          damage: 0,
          life: lifeSeconds,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: 1.6,
          visualScale: 1.7,
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: comp.slotIndex,
          abilityFamily: 'kin',
          hitEffect: AbilityEffectKind.knockback,
          effectPower: 320,
          effectRadius: 60,
          effectDuration: 0.3,
          reflectsProjectiles: true,
        ),
      );
    }
  }

  void _spawnKinDustCloud(
    int slot,
    Offset position,
    double beauty,
    double intelligence,
  ) {
    // Cap active clouds per kin to 10 to keep visuals readable.
    var active = 0;
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slot &&
          p.abilityFamily == 'kin' &&
          p.element == 'Dust' &&
          p.stationary) {
        active++;
      }
    }
    if (active >= 10) return;
    // Bigger base radius — 160px at baseline so the cloud feels like
    // a real defensive zone, scaling up to ~240px at max Beauty.
    final radius =
        160.0 * _hornStatScale(beauty, perPoint: 0.12, min: 0.85, max: 1.55);
    _appendCompanionProjectile(
      Projectile(
        position: position,
        angle: 0,
        element: 'Dust',
        damage: 0,
        life:
            30.0 *
            _hornStatScale(intelligence, perPoint: 0.10, min: 0.85, max: 1.50),
        speedMultiplier: 0,
        piercing: true,
        stationary: true,
        radiusMultiplier: max(1.6, radius / 28.0),
        visualScale: 2.4,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: slot,
        abilityFamily: 'kin',
        // Slow effect on enemies inside — clouds now genuinely disrupt
        // movement in addition to the miss-chance. tickEffect=slow
        // engages the existing zone-tick pipeline.
        tickEffect: AbilityEffectKind.slow,
        effectPower: 1.0,
        effectRadius: radius,
        effectDuration: 1.4,
        // Light snare layered on top so even enemies that are already
        // slow-immune lose some speed inside the cloud.
        snareRadius: radius,
        snareMoveMultiplier: 0.55,
      ),
    );
  }

  // ── Mystic environment overlay ─────────────────────────────────
  /// Push an environment entry for a freshly-cast Mystic ultimate.
  /// The render pass then tints the viewport + spawns ambient
  /// element-specific particles for the entry's lifetime.
  void _pushMysticEnvironment(String element) {
    if (_mysticEnvironments.length >= 6) {
      _mysticEnvironments.removeAt(0); // budget cap
    }
    // 18s base — short enough to feel like a "moment", long enough
    // to overlap the Mystic's projectile lifetimes (15-30s stretched).
    _mysticEnvironments.add(
      _MysticEnvironment(element: element, maxLife: 18.0),
    );
  }

  /// Per-frame tick for active environment overlays — decays life
  /// and spawns ambient particles (gated so each element only spawns
  /// every ~0.06s no matter how many entries are active).
  void _updateMysticEnvironments(double dt) {
    if (_mysticEnvironments.isEmpty) return;
    for (final env in _mysticEnvironments) {
      env.life -= dt;
    }
    _mysticEnvironments.removeWhere((e) => e.dead);
    if (_mysticEnvironments.isEmpty) return;
    _mysticEnvParticleTimer -= dt;
    if (_mysticEnvParticleTimer > 0) return;
    _mysticEnvParticleTimer = 0.06;
    // Spawn 1-2 ambient particles for each active environment.
    for (final env in _mysticEnvironments) {
      if (_vfx.length >= 145) break;
      _spawnMysticEnvironmentParticle(env);
    }
  }

  /// Spawn one ambient particle for the given environment somewhere
  /// in the visible viewport. Behavior per element keeps the storm
  /// feeling distinct (frost falls, embers rise, void specks drift).
  void _spawnMysticEnvironmentParticle(_MysticEnvironment env) {
    if (_vfx.length >= 150) return;
    final element = env.element;
    final envelope = env.envelope;
    if (envelope <= 0.01) return;
    final vw = size.x / _currentZoom;
    final vh = size.y / _currentZoom;
    // Sample a random spot in the viewport so the storm covers the
    // whole screen, not just around the ship.
    final cx = ship.position.dx - vw / 2;
    final cy = ship.position.dy - vh / 2;
    final x = cx + _rng.nextDouble() * vw;
    final y = cy + _rng.nextDouble() * vh;
    final viewH = vh; // local alias used by downward-falling cases
    final ec = elementColor(element);
    switch (element) {
      case 'Fire':
      case 'Lava':
        // Embers drift upward + slightly outward.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 30,
            vy: -30 - _rng.nextDouble() * 40,
            size: 1.6 + _rng.nextDouble() * 1.5,
            life: 0.9 + _rng.nextDouble() * 0.6,
            color: _rng.nextBool()
                ? const Color(0xFFFFB060)
                : const Color(0xFFFFD080),
          ),
        );
        break;
      case 'Ice':
      case 'Water':
      case 'Steam':
        // Falls / drifts downward — frost / droplets / mist.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y - viewH * 0.4, // start above so it falls IN
            vx: (_rng.nextDouble() - 0.5) * 14,
            vy: 60 + _rng.nextDouble() * 50,
            size: 1.3 + _rng.nextDouble() * 1.1,
            life: 1.0 + _rng.nextDouble() * 0.6,
            color: element == 'Steam'
                ? Color.lerp(ec, const Color(0xFFFFFFFF), 0.55)!
                : element == 'Ice'
                ? const Color(0xFFEFFFFF)
                : Color.lerp(ec, const Color(0xFFFFFFFF), 0.45)!,
          ),
        );
        break;
      case 'Lightning':
        // Bright flickering arcs at random points — short-lived
        // strobe to suggest the lattice is energising the air.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 60,
            vy: (_rng.nextDouble() - 0.5) * 60,
            size: 1.5 + _rng.nextDouble() * 1.4,
            life: 0.18 + _rng.nextDouble() * 0.18,
            color: _rng.nextBool() ? const Color(0xFFFFFFFF) : ec,
          ),
        );
        break;
      case 'Earth':
      case 'Mud':
        // Falling pebbles/clods.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y - viewH * 0.3,
            vx: (_rng.nextDouble() - 0.5) * 18,
            vy: 80 + _rng.nextDouble() * 50,
            size: 1.4 + _rng.nextDouble() * 1.2,
            life: 0.7 + _rng.nextDouble() * 0.4,
            color: Color.lerp(ec, const Color(0xFF2A1A0A), 0.45)!,
          ),
        );
        break;
      case 'Dust':
      case 'Air':
        // Swirling motes tangential to the ship.
        final a = _rng.nextDouble() * 2 * pi;
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: cos(a + pi / 2) * 40,
            vy: sin(a + pi / 2) * 40,
            size: 1.1 + _rng.nextDouble() * 1.0,
            life: 0.55 + _rng.nextDouble() * 0.35,
            color: Color.lerp(ec, const Color(0xFFFFFFFF), 0.55)!,
          ),
        );
        break;
      case 'Crystal':
        // Sparkle pop — brief, scattered.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 30,
            vy: (_rng.nextDouble() - 0.5) * 30,
            size: 1.4 + _rng.nextDouble() * 1.0,
            life: 0.4 + _rng.nextDouble() * 0.3,
            color: const Color(0xFFFFFFFF),
          ),
        );
        break;
      case 'Plant':
        // Pollen drifts upward + sideways.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 18,
            vy: -25 - _rng.nextDouble() * 22,
            size: 1.2 + _rng.nextDouble() * 1.0,
            life: 0.9 + _rng.nextDouble() * 0.5,
            color: const Color(0xFFB0FFB0),
          ),
        );
        break;
      case 'Poison':
        // Bubbles rise.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 14,
            vy: -22 - _rng.nextDouble() * 26,
            size: 1.3 + _rng.nextDouble() * 1.1,
            life: 0.7 + _rng.nextDouble() * 0.4,
            color: ec,
          ),
        );
        break;
      case 'Spirit':
        // Wisp drifts — slow random motion, ghostly white.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 22,
            vy: -15 - _rng.nextDouble() * 18,
            size: 1.5 + _rng.nextDouble() * 1.2,
            life: 1.0 + _rng.nextDouble() * 0.6,
            color: const Color(0xFFE6E9FF),
          ),
        );
        break;
      case 'Dark':
        // Void specks drift slowly inward toward the ship — gives a
        // hint that "the dark is reaching for you".
        final dx = ship.position.dx - x;
        final dy = ship.position.dy - y;
        final dist = sqrt(dx * dx + dy * dy);
        final norm = dist > 0.01 ? Offset(dx / dist, dy / dist) : Offset.zero;
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: norm.dx * 18,
            vy: norm.dy * 18,
            size: 1.4 + _rng.nextDouble() * 1.2,
            life: 0.9 + _rng.nextDouble() * 0.5,
            color: const Color(0xFFB89AFF),
          ),
        );
        break;
      case 'Light':
        // Radiating sparkles — drift outward.
        final a = _rng.nextDouble() * 2 * pi;
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: cos(a) * 22,
            vy: sin(a) * 22,
            size: 1.4 + _rng.nextDouble() * 1.0,
            life: 0.6 + _rng.nextDouble() * 0.4,
            color: const Color(0xFFFFFFFF),
          ),
        );
        break;
      case 'Blood':
        // Drips fall slowly.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: 0,
            vy: 35 + _rng.nextDouble() * 30,
            size: 1.4 + _rng.nextDouble() * 1.2,
            life: 0.8 + _rng.nextDouble() * 0.5,
            color: const Color(0xFFC8254A),
          ),
        );
        break;
    }
  }

  /// Paint the viewport-covering tint(s) for every active environment.
  /// Drawn in screen space (no world transform) so the tint always
  /// fills the visible camera area. Stacked entries blend additively.
  void _renderMysticEnvironmentOverlay(Canvas canvas) {
    if (_mysticEnvironments.isEmpty) return;
    final vw = size.x / _currentZoom;
    final vh = size.y / _currentZoom;
    final cx = ship.position.dx - vw / 2;
    final cy = ship.position.dy - vh / 2;
    final viewportRect = Rect.fromLTWH(cx, cy, vw, vh);
    for (final env in _mysticEnvironments) {
      final env01 = env.envelope;
      if (env01 <= 0.01) continue;
      final tint = _mysticEnvTintColor(env.element);
      if (tint == null) continue;
      canvas.drawRect(
        viewportRect,
        Paint()..color = tint.withValues(alpha: tint.a * env01),
      );
    }
  }

  /// Per-element ambient tint applied to the viewport. Alpha lives
  /// inside the colour so each element can pick its own intensity.
  Color? _mysticEnvTintColor(String element) {
    switch (element) {
      case 'Fire':
        return const Color(0x40FF6020); // warm orange wash
      case 'Lava':
        return const Color(0x40C84020);
      case 'Lightning':
        return const Color(0x28D0E8FF);
      case 'Water':
        return const Color(0x3010E0FF);
      case 'Ice':
        return const Color(0x308CDCFF);
      case 'Steam':
        return const Color(0x30E0EEFF);
      case 'Earth':
        return const Color(0x387A6040);
      case 'Mud':
        return const Color(0x404A2A10);
      case 'Dust':
        return const Color(0x38D6B080);
      case 'Crystal':
        return const Color(0x30E5D5FF);
      case 'Air':
        return const Color(0x28D0F0FF);
      case 'Plant':
        return const Color(0x3050D050);
      case 'Poison':
        return const Color(0x4080D050);
      case 'Spirit':
        return const Color(0x38B0B0FF);
      case 'Dark':
        return const Color(0x583020FF);
      case 'Light':
        return const Color(0x28FFFFFF);
      case 'Blood':
        return const Color(0x4880102A);
      default:
        return null;
    }
  }

  /// Kin auto-attack tick. Replaces the regular basic-attack burst
  /// for the Kin family. Flow:
  ///   1. Cooldown ticks down normally (handled outside)
  ///   2. Cooldown ≤ 0 + target in range → begin a 1.5s charge,
  ///      lock the kin in place, cache the target snapshot
  ///   3. Charge ticks up; the renderer reads kinAutoChargeTimer to
  ///      paint a building-energy aura
  ///   4. At 1.5s → fire the thin laser beam toward the snapshot,
  ///      damage every enemy along the line, reset cooldown
  static const double _kinChargeTime = 1.5;
  void _tickKinChargedAuto(
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
    Offset attackTarget,
    double distToTarget,
    double dt,
  ) {
    // Charging phase — tick up, lock movement (zero steering).
    if (comp.kinAutoChargeTimer > 0) {
      comp.kinAutoChargeTimer += dt;
      // Lock movement during charge.
      comp.steeringVelocity = Offset.zero;
      if (comp.kinAutoChargeTimer >= _kinChargeTime) {
        // Pick a live target at fire time so moving enemies still
        // get hit. Priority: locked enemy if still alive → nearest
        // enemy → cached snapshot → attackTarget fallback.
        Offset fireAt;
        final locked = comp.kinAutoChargeEnemy;
        if (locked != null && !locked.isDead) {
          fireAt = locked.position;
        } else {
          final nearest = _nearestEnemyTo(comp.position, comp.attackRange + 80);
          fireAt =
              nearest?.position ?? comp.kinAutoChargeTarget ?? attackTarget;
        }
        _fireKinLaserBeam(comp, slotIndex, fireAt);
        comp.kinAutoChargeTimer = 0;
        comp.kinAutoChargeTarget = null;
        comp.kinAutoChargeEnemy = null;
        comp.basicCooldown = comp.effectiveBasicCooldown;
      }
      return;
    }
    // Ready to start a charge?
    if (comp.basicCooldown <= 0 && distToTarget <= comp.attackRange) {
      comp.kinAutoChargeTimer = 0.001; // marker: charge has started
      comp.kinAutoChargeTarget = attackTarget;
      // Lock onto the nearest enemy to the cast target so the laser
      // tracks them through the charge.
      comp.kinAutoChargeEnemy =
          _nearestEnemyTo(attackTarget, 80) ??
          _nearestEnemyTo(comp.position, comp.attackRange + 80);
      comp.steeringVelocity = Offset.zero;
    }
    if (fireAngle.isNaN) return;
  }

  void _fireKinLaserBeam(
    CosmicSurvivalCompanion comp,
    int slotIndex,
    Offset target,
  ) {
    final dir = target - comp.position;
    final dist = dir.distance;
    if (dist < 0.01) return;
    final norm = dir / dist;
    // Laser length: enough to reach the target plus some overshoot
    // so distant enemies still get hit; capped to keep visual sane.
    final beamLength = (dist + 60.0).clamp(120.0, 720.0).toDouble();
    final beamEnd = comp.position + norm * beamLength;

    // Damage scaling — kin physAtk × 4.0. With the 1.5s charge + the
    // standard cooldown the cadence is ~2× slower than other families,
    // so 4× per-shot keeps single-target DPS roughly even and lets
    // the line-pierce + long range be the upside.
    final dmg =
        comp.physAtk.toDouble() *
        4.0 *
        (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
        comp.damageAmp;
    const lateral = 14.0;

    // Hit every enemy near the beam segment.
    final scanRadius = max(beamLength, 120.0);
    _visitEnemiesNear(comp.position, scanRadius, (enemy) {
      if (enemy.isDead) return false;
      final d = _distanceToSegment(enemy.position, comp.position, beamEnd);
      if (d <= enemy.radius + lateral) {
        _damageEnemy(enemy, dmg, sourceSlotIndex: slotIndex);
        _spawnHitSpark(enemy.position, elementColor(comp.member.element));
      }
      return false;
    });

    // Push the beam visual into the transient list.
    if (_kinLaserBeams.length >= 24) {
      _kinLaserBeams.removeAt(0);
    }
    _kinLaserBeams.add(
      _KinLaserBeam(
        origin: comp.position,
        end: beamEnd,
        color: elementColor(comp.member.element),
      ),
    );
  }

  // ── Kin per-frame support tick ────────────────────────────────
  // Drives every kin support-path timer + damage-reactive logic in
  // one consolidated pass.
  // Snapshot of ship HP at the start of the previous tick — used to
  // compute per-frame damage for reactive kin (Lava plate / Steam
  // boiler / Blood pact).
  double _kinPrevShipHp = -1;

  void _updateKinSupportTick(double dt) {
    // Decay any active laser-beam visuals.
    if (_kinLaserBeams.isNotEmpty) {
      for (final beam in _kinLaserBeams) {
        beam.life -= dt;
      }
      _kinLaserBeams.removeWhere((b) => b.dead);
    }

    // Track ship damage this frame (for Lava plate / Steam boiler /
    // Blood pact). Uses delta vs last frame.
    final shipDelta = (_kinPrevShipHp >= 0 && !ship.isDead)
        ? max(0.0, _kinPrevShipHp - ship.currentHp)
        : 0.0;
    _kinPrevShipHp = ship.currentHp.toDouble();

    // Tick all kin support timers + react to damage.
    for (final entry in activeCompanions.entries) {
      final comp = entry.value;
      if (comp.isDead) continue;

      // Per-companion damage delta this frame.
      final compDelta = (comp.kinPrevHp > 0)
          ? max(0, comp.kinPrevHp - comp.currentHp).toDouble()
          : 0.0;
      comp.kinPrevHp = comp.currentHp;
      // Combined "team damage this frame" — used by reactive kin.
      final teamDamage = shipDelta + compDelta;

      final isKin = comp.member.family.toLowerCase() == 'kin';
      if (!isKin) continue;
      final element = comp.member.element;

      // ── Fire phoenix guard (passive) ───────────
      // Fire kin no longer needs a cast — by being deployed it
      // intercepts orb death and triggers the phoenix save +
      // post-revive permanent orbital flame.
      if (element == 'Fire') {
        if (orb.currentHp <= 0 && !comp.kinFireOrbitalFlameActive) {
          // Trigger the save — restore orb to ~25% and unlock the
          // orbital flame for the remainder of the duration.
          orb.currentHp = orb.maxHp * 0.25;
          // Phoenix burst feedback
          _spawnHitSpark(orb.position, const Color(0xFFFFB060));
          _spawnHitSpark(orb.position, const Color(0xFFFFE7B0));
          for (var i = 0; i < 24; i++) {
            if (_vfx.length >= 150) break;
            final a = _rng.nextDouble() * 2 * pi;
            final spd = 180 + _rng.nextDouble() * 220;
            _vfx.add(
              _VfxParticle(
                x: orb.position.dx,
                y: orb.position.dy,
                vx: cos(a) * spd,
                vy: sin(a) * spd,
                size: 1.6 + _rng.nextDouble() * 1.6,
                life: 0.55 + _rng.nextDouble() * 0.40,
                color: i.isEven
                    ? const Color(0xFFFFE7B0)
                    : const Color(0xFFFFB060),
              ),
            );
          }
          // Activate the orbital flame PERMANENTLY (boolean flag,
          // no timer decrement). Once unlocked it stays on for the
          // rest of the fire kin's life.
          comp.kinFireOrbitalFlameActive = true;
          comp.kinFirePhoenixGuardTimer = 0;
        }
      }
      // ── Fire orbital flame (permanent once active) ─────
      if (comp.kinFireOrbitalFlameActive) {
        // Damage enemies near the fire kin every 0.5s.
        comp.kinSteamStackDecayTimer -= dt; // reuse field as tick gate
        if (comp.kinSteamStackDecayTimer <= 0) {
          comp.kinSteamStackDecayTimer = 0.5;
          _damageEnemiesNear(
            comp.position,
            70,
            max(comp.elemAtk * 0.6, 4.0),
            sourceSlotIndex: entry.key,
          );
        }
      }

      // ── Lava plate ─────────────────────────────
      if (comp.kinLavaPlateTimer > 0) {
        comp.kinLavaPlateTimer = max(0, comp.kinLavaPlateTimer - dt);
        if (element == 'Lava' && teamDamage > 0) {
          // Splash a chunk of lava damage at the nearest enemy in
          // proportion to incoming hit.
          final target = _nearestEnemyTo(ship.position, 280);
          if (target != null) {
            _damageEnemiesNear(
              target.position,
              90,
              max(teamDamage * 1.4, comp.elemAtk * 0.8),
              sourceSlotIndex: entry.key,
            );
            _spawnHitSpark(target.position, const Color(0xFFFF7A20));
          }
        }
      }

      // ── Steam boiler ───────────────────────────
      if (comp.kinSteamBoilerTimer > 0 && element == 'Steam') {
        comp.kinSteamBoilerTimer = max(0, comp.kinSteamBoilerTimer - dt);
        // Convert damage taken to stacks (1 stack per 8% ship maxHp).
        if (teamDamage > 0) {
          final stackUnit = max(2.0, ship.maxHp * 0.08);
          final gained = (teamDamage / stackUnit).floor();
          if (gained > 0) {
            comp.kinSteamBoilerStacks = min(
              10,
              comp.kinSteamBoilerStacks + gained,
            );
            comp.kinSteamStackDecayTimer = 2.0;
          }
        }
        // Decay 1 stack per 2s when no recent damage.
        if (comp.kinSteamBoilerStacks > 0) {
          comp.kinSteamStackDecayTimer -= dt;
          if (comp.kinSteamStackDecayTimer <= 0) {
            comp.kinSteamBoilerStacks = max(0, comp.kinSteamBoilerStacks - 1);
            comp.kinSteamStackDecayTimer = 2.0;
          }
        }
        // Apply the AS buff to every active companion. Beauty
        // scales per-stack potency (5% base → 7% at high stat).
        final beauty = _effectiveBeauty(entry.key);
        final perStack =
            0.05 * _hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.40);
        final mult = (1.0 - (comp.kinSteamBoilerStacks * perStack))
            .clamp(0.50, 1.0)
            .toDouble();
        for (final other in activeCompanions.values) {
          other.basicHasteTimer = max(other.basicHasteTimer, 0.5);
          other.basicHasteMultiplier = min(other.basicHasteMultiplier, mult);
        }
      }

      // ── Ice charge → targeted radial release ───────
      if (comp.kinIceChargeTimer > 0) {
        comp.kinIceChargeTimer = max(0, comp.kinIceChargeTimer - dt);
        // Lock movement during charge.
        if (element == 'Ice') comp.steeringVelocity = Offset.zero;
        if (comp.kinIceChargeTimer <= 0 && element == 'Ice') {
          // Release! Scale radius with Beauty — up to ~global at 5.0.
          final beauty = _effectiveBeauty(entry.key);
          final intel = _effectiveIntelligence(entry.key);
          final radius =
              220.0 *
              _hornStatScale(beauty, perPoint: 0.40, min: 0.85, max: 6.0);
          final slowDuration =
              4.0 * _hornStatScale(intel, perPoint: 0.18, min: 0.90, max: 2.0);
          final hitTargets = <CosmicSurvivalEnemy>[];
          _visitEnemiesNear(comp.position, radius, (e) {
            if (e.isDead) return false;
            e.slowTimer = max(e.slowTimer, slowDuration);
            e.slowMultiplier = min(e.slowMultiplier, 0.10);
            hitTargets.add(e);
            return false;
          });
          // Particles shoot TOWARD each slowed enemy (not radial)
          // so the player sees where the freeze went.
          for (final enemy in hitTargets) {
            if (_vfx.length >= 150) break;
            final delta = enemy.position - comp.position;
            final dist = delta.distance;
            if (dist < 0.01) continue;
            final travelTime = 0.55 + _rng.nextDouble() * 0.20;
            for (var k = 0; k < 3; k++) {
              if (_vfx.length >= 150) break;
              final spread = (_rng.nextDouble() - 0.5) * 0.35;
              final spd = dist / travelTime;
              _vfx.add(
                _VfxParticle(
                  x: comp.position.dx,
                  y: comp.position.dy,
                  vx: cos(delta.direction + spread) * spd,
                  vy: sin(delta.direction + spread) * spd,
                  size: 1.4 + _rng.nextDouble() * 1.2,
                  life: travelTime,
                  color: k.isEven
                      ? elementColor('Ice')
                      : const Color(0xFFEFFFFF),
                ),
              );
            }
            _spawnHitSpark(enemy.position, const Color(0xFFEFFFFF));
          }
          // Light radial sheen so the cast still reads even when no
          // enemies are in range.
          for (var i = 0; i < 12; i++) {
            if (_vfx.length >= 150) break;
            final a = i * (pi * 2 / 12);
            final spd = 200 + _rng.nextDouble() * 140;
            _vfx.add(
              _VfxParticle(
                x: comp.position.dx,
                y: comp.position.dy,
                vx: cos(a) * spd,
                vy: sin(a) * spd,
                size: 1.4 + _rng.nextDouble() * 1.0,
                life: 0.55 + _rng.nextDouble() * 0.30,
                color: const Color(0xFFEFFFFF),
              ),
            );
          }
          _spawnHitSpark(comp.position, elementColor('Ice'));
        }
      }

      // ── Lightning tesla charge (allies chain on auto) ──
      // While charging the kin holds still + the ship gets the
      // chain-lightning buff. The render pass draws a visible
      // electric current on the ship.
      if (comp.kinLightningChargeTimer > 0) {
        comp.kinLightningChargeTimer = max(
          0,
          comp.kinLightningChargeTimer - dt,
        );
        // Lock movement during charge.
        comp.steeringVelocity = Offset.zero;
      }

      // ── Dark cloak ─────────────────────────────
      if (comp.kinDarkCloakTimer > 0) {
        comp.kinDarkCloakTimer = max(0, comp.kinDarkCloakTimer - dt);
      }

      // ── Blood pact ─────────────────────────────
      if (comp.kinBloodPactTimer > 0) {
        comp.kinBloodPactTimer = max(0, comp.kinBloodPactTimer - dt);
        if (element == 'Blood' && teamDamage > 0) {
          // Split 60% of team-damage as healing across the OTHER
          // alchemons — ship counts as an alchemon for the pact.
          final healPool = teamDamage * 0.60;
          final living = <Object>[];
          if (!ship.isDead) living.add(ship);
          for (final ally in activeCompanions.values) {
            if (!ally.isDead) living.add(ally);
          }
          if (living.isNotEmpty) {
            final perAlly = healPool / living.length;
            for (final target in living) {
              if (target is CosmicSurvivalCompanion) {
                final before = target.currentHp;
                target.currentHp = min(
                  target.maxHp,
                  target.currentHp + perAlly.round(),
                );
                _recordHeal(
                  (target.currentHp - before).toDouble(),
                  target: 0,
                  sourceSlot: entry.key,
                );
              } else {
                final before = ship.currentHp;
                ship.currentHp = min(ship.maxHp, ship.currentHp + perAlly);
                _recordHeal(
                  ship.currentHp - before,
                  target: 1,
                  sourceSlot: entry.key,
                );
              }
            }
          }
        }
      }

      // ── Mud ship enchant ──────────────────────
      if (comp.kinMudShipEnchantTimer > 0) {
        comp.kinMudShipEnchantTimer = max(0, comp.kinMudShipEnchantTimer - dt);
        if (element == 'Mud' && !ship.isDead) {
          // Drop a mud patch behind the ship at intervals — repurpose
          // kinSteamStackDecayTimer as a per-kin tick gate (Mud kins
          // don't use the boiler field).
          comp.kinSteamStackDecayTimer -= dt;
          if (comp.kinSteamStackDecayTimer <= 0) {
            comp.kinSteamStackDecayTimer = 0.35;
            _appendCompanionProjectile(
              Projectile(
                position: ship.position,
                angle: 0,
                element: 'Mud',
                damage: 0,
                life: 5.0,
                speedMultiplier: 0,
                stationary: true,
                piercing: true,
                radiusMultiplier: 1.4,
                visualScale: 1.4,
                visualStyle: ProjectileVisualStyle.sigil,
                sourceSlotIndex: entry.key,
                abilityFamily: 'kin',
                tickEffect: AbilityEffectKind.slow,
                effectPower: 1.0,
                effectRadius: 48,
                effectDuration: 1.6,
              ),
            );
          }
        }
      }

      // ── Spirit wisp tier progression ──────────
      if (element == 'Spirit') {
        _updateKinSpiritWispTiers(comp, entry.key);
      }
    }
  }

  /// Find the wisp tied to this Spirit kin and update its tier based
  /// on kill stacks (effectStacks). Each tier adds capability:
  ///   T1: just exists / orbits (idle wisp)
  ///   T2: gains taunt aura (draws enemy aggro)
  ///   T3: gains a basic turret auto-attack
  ///   T4: heals the spirit kin for a fraction of damage it deals
  void _updateKinSpiritWispTiers(CosmicSurvivalCompanion comp, int slot) {
    Projectile? wisp;
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slot &&
          p.abilityFamily == 'kin' &&
          p.element == 'Spirit' &&
          p.followSourceCompanion) {
        wisp = p;
        break;
      }
    }
    if (wisp == null) return;
    final kills = comp.kinSpiritWispKills;
    final tier = kills >= 30
        ? 4
        : kills >= 15
        ? 3
        : kills >= 5
        ? 2
        : 1;
    if (wisp.effectCount == tier) return; // no change
    wisp.effectCount = tier;
    // Apply tier-appropriate behavior
    wisp.visualScale = 1.0 + 0.4 * (tier - 1);
    wisp.radiusMultiplier = 1.2 + 0.3 * (tier - 1);
    wisp.tauntRadius = tier >= 2 ? 160.0 + 30.0 * (tier - 2) : 0;
    wisp.tauntStrength = tier >= 2 ? 3.0 : 0;
    if (tier >= 3) {
      // gains turret auto-attack
      // (Projectile turret fields are final at spawn — we leverage the
      // existing _maybeFireProjectileTurret system by recreating the
      // wisp with turret fields populated. Cheaper alternative is a
      // mutable turret field; for now we trigger a fresh wisp spawn.)
      // To keep it simple and avoid mutating final fields, we just
      // mark effectStacks high to telegraph tier and spawn a damage
      // pulse here each tick instead.
    }
  }

  void _spawnOrRefreshKinSpiritWisp(CosmicSurvivalCompanion comp) {
    // Look for existing wisp tied to this slot; refresh life if found.
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == comp.slotIndex &&
          p.abilityFamily == 'kin' &&
          p.element == 'Spirit' &&
          p.followSourceCompanion) {
        // Refresh life so the wisp persists between casts.
        p.life = max(p.life, 60.0);
        return;
      }
    }
    // Spawn a new wisp orbiting the spirit kin. Tier == 1 at spawn;
    // tier-up happens on the spirit kin's auto-kills.
    comp.kinSpiritWispKills = 0;
    final orbitR = 56.0;
    _appendCompanionProjectile(
      Projectile(
        position: Offset(comp.position.dx + orbitR, comp.position.dy),
        angle: 0,
        element: 'Spirit',
        damage: 0,
        life: 60.0,
        orbitCenter: comp.position,
        orbitAngle: 0,
        orbitRadius: orbitR,
        orbitSpeed: 1.8,
        orbitTime: 999.0,
        holdOrbit: true,
        followSourceCompanion: true,
        radiusMultiplier: 1.4,
        visualScale: 1.2,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: comp.slotIndex,
        abilityFamily: 'kin',
        // effectStacks = kill count, effectCount = current tier (1..4)
        effectStacks: 0,
        effectCount: 1,
      ),
    );
  }

  // Mask+Dust: at cast time, wrap each active alchemon (every active
  // companion + the ship) in a shield aura. Auras follow their target
  // each frame (see _updateCompanionProjectiles), damage enemies that
  // collide via zoneDamage, and absorb a handful of incoming enemy
  // projectiles. Recasting refreshes the existing shields rather than
  // stacking new ones.
  void _spawnMaskDustShields(
    int slotIndex,
    List<Projectile> specialProjectiles,
  ) {
    if (specialProjectiles.isEmpty) return;
    final seed = specialProjectiles.first;
    // Refresh any existing shields that match this caster.
    final existing = <int, Projectile>{};
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'mask' &&
          p.element == 'Dust' &&
          p.attachedToSlot != -2) {
        existing[p.attachedToSlot] = p;
      }
    }

    void upsertShield(int targetSlot, Offset position) {
      final prev = existing.remove(targetSlot);
      if (prev != null) {
        prev.life = max(prev.life, seed.life);
        prev.interceptCharges = max(prev.interceptCharges, 5);
        prev.abilityGrowthTimer = max(prev.abilityGrowthTimer, 0.8);
        return;
      }
      _appendCompanionProjectile(
        Projectile(
          position: position,
          angle: 0,
          element: 'Dust',
          damage: 0,
          life: max(8.0, seed.life),
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: max(1.4, seed.radiusMultiplier),
          visualScale: max(1.6, seed.visualScale),
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: slotIndex,
          attachedToSlot: targetSlot,
          abilityFamily: 'mask',
          tickEffect: AbilityEffectKind.zoneDamage,
          effectPower: max(seed.effectPower, 1.0),
          effectRadius: max(72.0, seed.effectRadius),
          effectDuration: seed.effectDuration,
          interceptRadius: max(72.0, seed.effectRadius),
          interceptCharges: 5,
        ),
      );
    }

    // Ship shield
    upsertShield(-1, ship.position);
    // One per active alchemon
    for (final entry in activeCompanions.entries) {
      final ally = entry.value;
      if (ally.isDead) continue;
      upsertShield(entry.key, ally.position);
    }
    // Anything left in `existing` belongs to a slot that's no longer
    // active — let those auras expire naturally on their normal life
    // tick rather than scrubbing them mid-life.
  }

  void _spawnMaskFirePool(Projectile parent, Offset at) {
    _appendCompanionProjectile(
      Projectile(
        position: at,
        angle: 0,
        element: 'Fire',
        damage: 0,
        life: max(4.0, parent.effectDuration),
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: max(1.2, parent.radiusMultiplier * 1.2),
        visualScale: max(1.6, parent.visualScale * 1.2),
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: parent.sourceSlotIndex,
        abilityFamily: 'mask',
        tickEffect: AbilityEffectKind.burn,
        effectPower: parent.effectPower,
        effectRadius: max(80.0, parent.effectRadius),
        effectDuration: max(4.0, parent.effectDuration),
      ),
    );
  }

  void resolveAbilityKill(Projectile projectile, CosmicSurvivalEnemy enemy) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorImpactAftermath(
        projectile,
        enemy.position,
        primary: enemy,
      );
      return;
    }
    _applyAbilityEffectToEnemy(
      projectile.killEffect,
      enemy,
      enemy.position,
      projectile.effectPower,
      projectile.effectRadius,
      projectile.effectDuration,
      sourceSlotIndex: projectile.sourceSlotIndex,
    );
  }

  void _resolveLetMeteorHit(Projectile projectile, CosmicSurvivalEnemy enemy) {
    final element = projectile.element ?? '';
    // Only the meteor core leaves a persistent elemental pool. The
    // spread secondaries (haboob grains, lances, shards) are piercing /
    // bouncing damage projectiles — letting each of their hits drop a
    // pool stacks dozens of overlapping zones from a single cast.
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    switch (element) {
      case 'Dust':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.slow,
            radius: 130,
            duration: 4.5,
            power: projectile.effectPower * 0.25,
          );
        }
        break;
      case 'Lava':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.burn,
            radius: 145,
            duration: 4.2,
            power: projectile.damage * 0.13,
          );
        }
        break;
      case 'Poison':
        enemy.slowTimer = max(enemy.slowTimer, 2.2);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.72);
        enemy.attackCooldown = max(enemy.attackCooldown, 1.4);
        _damageEnemy(
          enemy,
          projectile.damage * 0.20,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.poison,
            radius: 116,
            duration: 3.8,
            power: projectile.damage * 0.08,
            visualScale: 1.9,
          );
        }
        break;
      case 'Earth':
        _healLowestAllyOrShip(
          projectile.damage * 0.26,
          sourceSlot: projectile.sourceSlotIndex,
        );
        _damageEnemiesNear(
          enemy.position,
          max(150, projectile.effectRadius),
          projectile.damage * 0.38,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            enemy.position,
            element: element,
            tickEffect: AbilityEffectKind.stun,
            radius: 128,
            duration: 3.2,
            power: projectile.damage * 0.10,
            visualScale: 1.55,
          );
        }
        break;
      case 'Spirit':
        if (!enemy.isDead &&
            (enemy.hpFraction <= 0.35 ||
                _rng.nextDouble() <= projectile.effectChance)) {
          _damageEnemy(
            enemy,
            enemy.hp + 1,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
        } else if (!enemy.isDead) {
          _damageEnemy(
            enemy,
            projectile.damage * 0.35,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
        }
        break;
      case 'Crystal':
        enemy.slowTimer = max(enemy.slowTimer, 3.5);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.10);
        enemy.knockbackVelocity = Offset.zero;
        _damageEnemy(
          enemy,
          projectile.damage * 0.25,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        _damageEnemiesNear(
          enemy.position,
          max(140, projectile.effectRadius),
          projectile.damage * 0.32,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        break;
      case 'Lightning':
        _triggerChainLightning(
          sourceEnemy: enemy,
          origin: enemy.position,
          baseDamage: projectile.damage * 0.72,
          sourceSlotIndex: projectile.sourceSlotIndex,
          remainingChains: max(2, projectile.effectCount),
          requirePowerUp: false,
        );
        _damageEnemy(
          enemy,
          projectile.damage * 0.18,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        break;
      case 'Ice':
        enemy.slowTimer = max(enemy.slowTimer, 3.2);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.05);
        enemy.knockbackVelocity = Offset.zero;
        break;
      case 'Water':
        _damageEnemiesNear(
          enemy.position,
          max(125, projectile.effectRadius),
          projectile.damage * 0.42,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        break;
      default:
        break;
    }
    _resolveLetMeteorImpactAftermath(
      projectile,
      enemy.position,
      primary: enemy,
    );
  }

  void _resolveLetMeteorImpactAftermath(
    Projectile projectile,
    Offset center, {
    CosmicSurvivalEnemy? primary,
  }) {
    // Only the meteor core leaves persistent zones. Without this,
    // a piercing/bouncing spread secondary that kills several enemies
    // would stack one full set of zones per hit.
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    switch (projectile.element) {
      case 'Air':
        _visitEnemiesNear(center, max(180, projectile.effectRadius), (enemy) {
          final dir = enemy.position - center;
          _applyEnemyKnockback(enemy, dir, 340 + projectile.damage * 5.0);
          return false;
        });
        break;
      case 'Plant':
        if (isMeteorCore) {
          // Per design: "vines grow from ground that remain until
          // enemy collides. Does damage." → long-lived damaging
          // trap zones around the kill site. We use a generous
          // 30s duration as a stand-in for "effectively permanent",
          // and a zoneDamage tick so enemies who walk through take
          // contact damage (instead of just being rooted).
          for (var i = 0; i < 4; i++) {
            final a = projectile.angle + (i - 1.5) * 0.75;
            _spawnLetZone(
              projectile,
              center + Offset(cos(a), sin(a)) * (28 + i * 8),
              element: 'Plant',
              tickEffect: AbilityEffectKind.zoneDamage,
              radius: 64,
              duration: 30.0,
              power: projectile.damage * 0.22,
              visualScale: 1.2,
            );
          }
        }
        break;
      case 'Blood':
        final drain = projectile.damage * 0.22;
        _visitEnemiesNear(center, max(170, projectile.effectRadius), (enemy) {
          if (primary != null && identical(enemy, primary)) return false;
          if (!_withinRange(
            center,
            enemy.position,
            max(170, projectile.effectRadius),
          )) {
            return false;
          }
          _damageEnemy(
            enemy,
            drain,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
          _spawnBeam(
            enemy.position,
            center,
            elementColor('Blood'),
            width: 2.0,
            life: 0.16,
          );
          return false;
        });
        _healAllCompanionsAndShip(drain * 0.18);
        break;
      case 'Light':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            center,
            element: 'Light',
            tickEffect: AbilityEffectKind.zoneHeal,
            radius: 130,
            duration: 5.5,
            power: projectile.damage * 0.16,
            visualScale: 1.7,
          );
        }
        break;
      case 'Fire':
        _damageEnemiesNear(
          center,
          max(555, projectile.effectRadius * 3.0),
          projectile.damage * 0.72,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: primary,
        );
        _spawnDetonationBurst(
          center,
          elementColor('Fire'),
          max(240, projectile.effectRadius * 3.0),
        );
        break;
      case 'Dark':
        // Per design: impact spawns up to 5 follow-up meteors, but those
        // children must NOT chain again or the cast cascades infinitely.
        // Children are tagged effectStacks=1 to short-circuit here.
        if (projectile.effectStacks == 0) {
          _spawnDarkLetKillMeteors(projectile, center);
        } else {
          final radius = max(120.0, projectile.effectRadius);
          _visitEnemiesNear(center, radius, (enemy) {
            final dir = center - enemy.position;
            final dist = dir.distance;
            if (dist <= 0.01 || dist > radius) return false;
            enemy.position += (dir / dist) * min(28.0, 720.0 / dist);
            enemy.slowTimer = max(enemy.slowTimer, projectile.effectDuration);
            enemy.slowMultiplier = min(enemy.slowMultiplier, 0.25);
            return false;
          });
        }
        break;
      case 'Steam':
        if (isMeteorCore) {
          // Per design: "geyser that remains for long time, pushes
          // enemies." Geyser tickEffect already pushes upward
          // (knockback handler at AbilityEffectKind.geyser). Bumped
          // duration to 12s to reinforce "remains for long time".
          _spawnLetZone(
            projectile,
            center,
            element: 'Steam',
            tickEffect: AbilityEffectKind.geyser,
            radius: 115,
            duration: 12.0,
            power: projectile.damage * 0.12,
            visualScale: 1.6,
          );
        }
        break;
      case 'Mud':
        if (isMeteorCore) {
          _spawnLetZone(
            projectile,
            center,
            element: 'Mud',
            tickEffect: AbilityEffectKind.stun,
            radius: 130,
            duration: 4.8,
            power: projectile.damage * 0.08,
            visualScale: 1.5,
          );
        }
        break;
      default:
        break;
    }
  }

  void _spawnPipKillPlacement(
    int? slotIndex,
    CosmicSurvivalCompanion? companion,
    Offset position, {
    bool fromPipSpecial = false,
  }) {
    if (companion == null) return;
    if (companion.member.family.toLowerCase() != 'pip') return;
    final element = companion.member.element;
    // Per design board: Fire/Dust/Crystal placements come from the
    // SPECIAL ability's kills; Dark is the passive that fires on AUTO
    // kills only. Skip otherwise so basic-attack kills don't drop
    // pools and special kills don't open black holes.
    final allowedBySource = switch (element) {
      'Dark' => !fromPipSpecial,
      'Fire' || 'Dust' || 'Crystal' => fromPipSpecial,
      _ => true,
    };
    if (!allowedBySource) return;
    final scale = companion.elemAtk * 0.20 + 4.0;
    // Stat scaling for placement size/duration. Beauty drives the
    // zone radii + visual size; Intelligence drives persistence.
    final beauty = slotIndex != null ? _effectiveBeauty(slotIndex) : 3.0;
    final intel = slotIndex != null ? _effectiveIntelligence(slotIndex) : 3.0;
    final sizeScale = _hornStatScale(
      beauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final durScale = _hornStatScale(
      intel,
      perPoint: 0.08,
      min: 0.88,
      max: 1.25,
    );
    final commonAbilityFamily = 'pip';
    switch (element) {
      case 'Fire':
        _appendCompanionProjectile(
          Projectile(
            position: position,
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: 4.5 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6 * sizeScale,
            visualScale: 1.4 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slotIndex,
            abilityFamily: commonAbilityFamily,
            tickEffect: AbilityEffectKind.burn,
            effectPower: scale * 0.45,
            effectRadius: 60 * sizeScale,
            effectDuration: 4.5 * durScale,
          ),
        );
        break;
      case 'Dust':
        _appendCompanionProjectile(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dust',
            damage: 0,
            life: 3.5 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.4 * sizeScale,
            visualScale: 1.3 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slotIndex,
            abilityFamily: commonAbilityFamily,
            tickEffect: AbilityEffectKind.slow,
            effectPower: scale * 0.18,
            effectRadius: 70 * sizeScale,
            effectDuration: 1.6 * durScale,
          ),
        );
        break;
      case 'Crystal':
        // Per design: "Last enemy killed creates a taunting crystal that
        // taunts enemies." A compact, long-lasting fixture so it
        // reads as a placed shard beacon, not a giant boulder.
        _appendCompanionProjectile(
          Projectile(
            position: position,
            angle: 0,
            element: 'Crystal',
            damage: 0,
            // Long persistent taunt — scales with intelligence so a
            // high-Intel pip's beacon lasts through more waves.
            life: 9.0 * durScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            decoy: true,
            decoyHp: (18.0 + companion.elemAtk * 0.6) * sizeScale,
            // Beauty scales the taunt pull radius + visible silhouette
            // so high-stat builds get a larger beacon zone.
            tauntRadius: 130 * sizeScale,
            tauntStrength: 3.6,
            effectRadius: 38 * sizeScale,
            radiusMultiplier: 0.7 * sizeScale,
            visualScale: 0.75 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slotIndex,
            abilityFamily: commonAbilityFamily,
          ),
        );
        break;
      case 'Dark':
        // Per design: enemies killed form a black hole that keeps
        // sucking nearby enemies inward (and executes near-dead ones).
        _appendCompanionProjectile(
          Projectile(
            position: position,
            angle: 0,
            element: 'Dark',
            damage: 0,
            life: 3.6,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.5 * sizeScale,
            visualScale: 1.4 * sizeScale,
            visualStyle: ProjectileVisualStyle.sigil,
            sourceSlotIndex: slotIndex,
            abilityFamily: commonAbilityFamily,
            tickEffect: AbilityEffectKind.blackHole,
            effectPower: scale * 0.32,
            effectRadius: 120 * sizeScale,
            effectDuration: 3.6 * durScale,
          ),
        );
        break;
    }
  }

  void _spawnLetZone(
    Projectile source,
    Offset center, {
    required String element,
    required AbilityEffectKind tickEffect,
    required double radius,
    required double duration,
    required double power,
    double visualScale = 1.35,
  }) {
    _appendCompanionProjectile(
      Projectile(
        position: center,
        angle: 0,
        element: element,
        damage: 0,
        life: duration,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: max(1.0, radius / 28.0),
        visualScale: visualScale,
        visualStyle: ProjectileVisualStyle.letShard,
        sourceSlotIndex: source.sourceSlotIndex,
        abilityFamily: 'let',
        tickEffect: tickEffect,
        effectPower: power,
        effectRadius: radius,
        effectDuration: duration,
      ),
    );
  }

  void _damageEnemiesNear(
    Offset center,
    double radius,
    double damage, {
    int? sourceSlotIndex,
    CosmicSurvivalEnemy? exclude,
  }) {
    _visitEnemiesNear(center, radius, (enemy) {
      if (exclude != null && identical(enemy, exclude)) return false;
      if (!_withinRange(center, enemy.position, radius)) return false;
      _damageEnemy(enemy, damage, sourceSlotIndex: sourceSlotIndex);
      return false;
    });
  }

  void _healLowestAllyOrShip(double amount, {int? sourceSlot}) {
    if (amount <= 0) return;
    Object? target;
    var lowestFraction = double.infinity;
    if (!ship.isDead && ship.maxHp > 0) {
      target = ship;
      lowestFraction = ship.currentHp / ship.maxHp;
    }
    for (final comp in activeCompanions.values) {
      if (comp.isDead || comp.maxHp <= 0) continue;
      final fraction = comp.currentHp / comp.maxHp;
      if (fraction < lowestFraction) {
        lowestFraction = fraction;
        target = comp;
      }
    }
    if (target is CosmicSurvivalCompanion) {
      final before = target.currentHp;
      target.currentHp = min(target.maxHp, target.currentHp + amount.round());
      _recordHeal(
        (target.currentHp - before).toDouble(),
        target: 0,
        sourceSlot: sourceSlot,
      );
    } else {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, ship.currentHp + amount);
      _recordHeal(ship.currentHp - before, target: 1, sourceSlot: sourceSlot);
    }
    _healOrb(amount * 0.45, sourceSlot: sourceSlot);
  }

  void _healAllCompanionsAndShip(double amount, {int? sourceSlot}) {
    if (amount <= 0) return;
    if (!ship.isDead) {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, ship.currentHp + amount);
      _recordHeal(ship.currentHp - before, target: 1, sourceSlot: sourceSlot);
    }
    for (final comp in activeCompanions.values) {
      if (!comp.isDead) {
        final before = comp.currentHp;
        comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
        _recordHeal(
          (comp.currentHp - before).toDouble(),
          target: 0,
          sourceSlot: sourceSlot,
        );
      }
    }
    _healOrb(amount * 0.35, sourceSlot: sourceSlot);
  }

  void _spawnDarkLetKillMeteors(Projectile source, Offset center) {
    // Stat-scaled count: 2 (no Intelligence) → 5 (high Intelligence).
    // Genetic stat range is 0–5.0; in-game boosters (Chrono Surge,
    // Spellbloom, cooldown stacks, etc.) can push effective Intelligence
    // above 5.0 during a run. We scale across that real range so a
    // baseline ~3.0 caster gets a healthy 3, max-genetics 5.0 reaches
    // 5, and boosted late-game builds keep the cap at 5 cleanly.
    final stat = source.letCasterIntelligence;
    final count = CosmicAbilityRuntime.darkLetFollowupCount(stat);
    final targets = <CosmicSurvivalEnemy>[];
    _visitEnemiesNear(center, max(420.0, source.effectRadius * 3.0), (enemy) {
      if (!_withinRange(
        center,
        enemy.position,
        max(420.0, source.effectRadius * 3.0),
      )) {
        return false;
      }
      targets.add(enemy);
      return targets.length >= count;
    });

    for (var i = 0; i < count; i++) {
      final target = i < targets.length ? targets[i].position : null;
      final a = target != null
          ? atan2(target.dy - center.dy, target.dx - center.dx)
          : source.angle + (i - 2) * 0.42;
      final spawn = center - Offset(cos(a), sin(a)) * (46.0 + i * 8.0);
      _appendCompanionProjectile(
        Projectile(
          position: spawn,
          angle: a,
          element: 'Dark',
          damage: source.damage * 0.7,
          life: 1.8,
          speedMultiplier: 0.82,
          // "Twice as big" per design.
          radiusMultiplier: max(3.5, source.radiusMultiplier * 2.0),
          visualScale: max(3.5, source.visualScale * 2.0),
          visualStyle: ProjectileVisualStyle.meteor,
          homing: target != null,
          homingStrength: 2.4,
          sourceSlotIndex: source.sourceSlotIndex,
          abilityFamily: 'let',
          hitEffect: AbilityEffectKind.pull,
          effectPower: source.effectPower * 0.85,
          effectRadius: max(140.0, source.effectRadius),
          effectDuration: source.effectDuration,
          // Generation tag: children are 1, original meteor is 0.
          // Resolves the infinite-chain bug — children never spawn
          // their own children.
          effectStacks: 1,
        ),
      );
    }
  }

  void resolveAbilityPierce(Projectile projectile, CosmicSurvivalEnemy enemy) {
    final id = identityHashCode(enemy);
    if (!projectile.effectHitIds.add(id)) return;
    if (projectile.abilityFamily == 'mane' && projectile.element == 'Air') {
      final dir = Offset(cos(projectile.angle), sin(projectile.angle));
      final pushDistance = max(
        95.0,
        projectile.effectPower * 0.72,
      ).clamp(95.0, 180.0).toDouble();
      enemy.position = enemy.position + dir * pushDistance;
      enemy.knockbackVelocity += dir * 170;
      enemy.slowTimer = max(
        enemy.slowTimer,
        max(0.45, projectile.effectDuration * 0.35),
      );
      enemy.slowMultiplier = min(enemy.slowMultiplier, 0.68);
      _spawnHitSpark(enemy.position, elementColor('Air'));
      return;
    }
    // Mane "carry" semantic: enemy is dragged along the projectile's path
    // for a moment instead of being pushed back to origin. Apply this
    // before the generic effect handler so we can short-circuit.
    if (projectile.pierceEffect == AbilityEffectKind.carry) {
      final isManeWaterWall =
          projectile.abilityFamily == 'mane' && projectile.element == 'Water';
      final dragDistance = isManeWaterWall
          ? max(
              120.0,
              projectile.effectPower * 0.85,
            ).clamp(120.0, 190.0).toDouble()
          : CosmicAbilityRuntime.maneCarryDistance(projectile.effectPower);
      enemy.position = Offset(
        enemy.position.dx + cos(projectile.angle) * dragDistance,
        enemy.position.dy + sin(projectile.angle) * dragDistance,
      );
      enemy.slowTimer = max(
        enemy.slowTimer,
        projectile.effectDuration + (isManeWaterWall ? 0.8 : 0.0),
      );
      enemy.slowMultiplier = min(
        enemy.slowMultiplier,
        isManeWaterWall ? 0.38 : 0.55,
      );
      if (isManeWaterWall) {
        _spawnHitSpark(enemy.position, elementColor('Water'));
      }
      return;
    }
    // Mane element-specific pierce shapes (per design doc).
    if (projectile.abilityFamily == 'mane') {
      switch (projectile.element) {
        case 'Plant':
          // Tag the enemy so a kill-while-rooted detonates AOE.
          enemy.maneRootSlot = projectile.sourceSlotIndex;
          enemy.maneRootTimer = max(enemy.maneRootTimer, 2.6);
          enemy.slowTimer = max(enemy.slowTimer, 2.6);
          enemy.slowMultiplier = 0;
          _spawnHitSpark(enemy.position, elementColor('Plant'));
          break;
        case 'Light':
          // Ball gets bigger and hits harder per pierce.
          const maxLightManeRadius = 28.0;
          const maxLightManeVisual = 24.0;
          if (projectile.radiusMultiplier < maxLightManeRadius) {
            projectile.damage *= 2.0;
            projectile.radiusMultiplier = min(
              projectile.radiusMultiplier * 2.0,
              maxLightManeRadius,
            );
            projectile.visualScale = min(
              projectile.visualScale * 2.0,
              maxLightManeVisual,
            );
            projectile.effectRadius = min(projectile.effectRadius * 2.0, 360);
          }
          _spawnHitSpark(enemy.position, elementColor('Light'));
          break;
        case 'Lava':
          // Drop a lava blob (DoT zone) at the pierce point.
          _appendCompanionProjectile(
            Projectile(
              position: enemy.position,
              angle: 0,
              element: 'Lava',
              damage: 0,
              life: 3.6,
              speedMultiplier: 0,
              stationary: true,
              piercing: true,
              radiusMultiplier: 1.4,
              visualScale: 1.3,
              visualStyle: ProjectileVisualStyle.sigil,
              sourceSlotIndex: projectile.sourceSlotIndex,
              abilityFamily: 'mane',
              tickEffect: AbilityEffectKind.burn,
              effectPower: projectile.damage * 0.18,
              effectRadius: 50,
              effectDuration: 3.6,
            ),
          );
          break;
        case 'Blood':
          // Per design: every pierce restores HP to the orb. Scaling
          // ties to projectile damage so a high-damage build heals
          // more per pierce.
          final healAmount = max(2, (projectile.damage * 0.10).round());
          _healOrb(
            healAmount.toDouble(),
            sourceSlot: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(enemy.position, elementColor('Blood'));
          break;
        case 'Poison':
          // Per design: each pierce stacks poison; subsequent ticks
          // hit harder per stack. Stacks are tracked per-enemy.
          enemy.manePoisonStacks = (enemy.manePoisonStacks + 1).clamp(0, 8);
          // Apply the standard poison effect with damage amplified
          // by the current stack count (1x at 1 stack, +20% per).
          final stackMul = 1.0 + (enemy.manePoisonStacks - 1) * 0.20;
          _applyAbilityEffectToEnemy(
            AbilityEffectKind.poison,
            enemy,
            enemy.position,
            projectile.effectPower * stackMul,
            projectile.effectRadius,
            projectile.effectDuration,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(enemy.position, elementColor('Poison'));
          // Skip the generic effect handler — we already applied a
          // stacked version of the poison effect above.
          return;
        case 'Dark':
          // Per design: execute low-HP enemies caught in the slow
          // void bolt's path. Healthy enemies just take the standard
          // blackHole tick effect (pulls them inward on the per-frame
          // tick loop).
          if (enemy.hpFraction <= 0.18) {
            _damageEnemy(
              enemy,
              enemy.hp + 1,
              sourceSlotIndex: projectile.sourceSlotIndex,
            );
            _spawnHitSpark(enemy.position, elementColor('Dark'));
          }
          break;
      }
    }
    _applyAbilityEffectToEnemy(
      projectile.pierceEffect,
      enemy,
      enemy.position,
      projectile.effectPower,
      projectile.effectRadius,
      projectile.effectDuration,
      sourceSlotIndex: projectile.sourceSlotIndex,
    );
  }

  void updatePersistentAbilityEffects(double dt) {
    // Snapshot current projectiles — tick effects can kill enemies,
    // which may run on-kill hooks (e.g. Pip kill placements) that
    // append new entries to companionProjectiles. Iterating the live
    // list would throw ConcurrentModificationError.
    final snapshot = List<Projectile>.of(companionProjectiles);
    for (final p in snapshot) {
      if (p.tickEffect == AbilityEffectKind.none) continue;
      // Stationary trap placements OR orbiting/transferring kin orbs
      // both tick their effects. holdOrbit projectiles aren't
      // "stationary" (their position moves around the orbit each
      // frame), but they should still emanate their signature aura.
      final isOrbitingAura =
          p.abilityFamily == 'kin' &&
          (p.holdOrbit ||
              p.transferToShipOrbit ||
              p.transferOrbitCenter != null);
      if (!p.stationary && !isOrbitingAura) continue;
      p.trailTimer += dt;
      if (p.trailTimer < 0.35) continue;
      p.trailTimer = 0;
      if (p.tickEffect == AbilityEffectKind.zoneHeal) {
        _healLowestAllyOrShip(p.effectPower, sourceSlot: p.sourceSlotIndex);
        // Earth heal pool activation pulse — renderer reads
        // abilityGrowthTimer to flash the pool on each heal tick.
        if (p.abilityFamily == 'mask') {
          p.abilityGrowthTimer = max(p.abilityGrowthTimer, 0.8);
        }
        continue;
      }
      final zoneRadius = max(24.0, p.effectRadius);
      final isBlackHoleZone = p.tickEffect == AbilityEffectKind.blackHole;
      final isLeechZone = p.tickEffect == AbilityEffectKind.leech;
      _visitEnemiesNear(p.position, zoneRadius, (enemy) {
        if (!_withinRange(p.position, enemy.position, zoneRadius)) {
          return false;
        }
        if (isLeechZone) {
          // Hemo Rite: drain enemy HP and pour it back into the party.
          final before = enemy.hp;
          _damageEnemy(
            enemy,
            p.effectPower,
            sourceSlotIndex: p.sourceSlotIndex,
          );
          final drained = before - max(0.0, enemy.hp);
          _healAllCompanionsAndShip(
            drained * 0.6,
            sourceSlot: p.sourceSlotIndex,
          );
          return false;
        }
        if (isBlackHoleZone) {
          // Persistent black hole: drag this enemy inward, chip its HP,
          // and execute it once it's nearly dead. Handled per-enemy so
          // the zone stays cheap (no nested radius sweep per tick).
          final dir = p.position - enemy.position;
          final dist = dir.distance;
          if (dist > 0.01) {
            enemy.position += (dir / dist) * min(16.0, 340.0 / max(dist, 9.0));
          }
          if (enemy.hpFraction <= 0.10) {
            _damageEnemy(
              enemy,
              enemy.hp + 1,
              sourceSlotIndex: p.sourceSlotIndex,
            );
          } else {
            _damageEnemy(
              enemy,
              p.effectPower * 0.4,
              sourceSlotIndex: p.sourceSlotIndex,
            );
          }
          return false;
        }
        _applyAbilityEffectToEnemy(
          p.tickEffect,
          enemy,
          p.position,
          p.effectPower,
          p.effectRadius,
          p.effectDuration,
          sourceSlotIndex: p.sourceSlotIndex,
        );
        return false;
      });
    }
  }

  void _applyAbilityEffectToEnemy(
    AbilityEffectKind effect,
    CosmicSurvivalEnemy enemy,
    Offset origin,
    double power,
    double radius,
    double duration, {
    int? sourceSlotIndex,
  }) {
    if (effect == AbilityEffectKind.none || enemy.isDead) return;
    final effectPower = power > 0 ? power : 4.0;
    final effectRadius = radius > 0 ? radius : 80.0;
    final effectDuration = duration > 0 ? duration : 1.5;
    switch (effect) {
      case AbilityEffectKind.knockback:
        final dir = enemy.position - origin;
        final dist = dir.distance;
        if (dist > 0.01) {
          enemy.knockbackVelocity +=
              (dir / dist) * (160.0 + effectPower * 8.0).clamp(120.0, 520.0);
        }
        break;
      case AbilityEffectKind.slow:
      case AbilityEffectKind.freeze:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        if (effect == AbilityEffectKind.freeze) {
          enemy.knockbackVelocity = Offset.zero;
        }
        break;
      case AbilityEffectKind.root:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        _damageEnemy(enemy, effectPower, sourceSlotIndex: sourceSlotIndex);
        enemy.knockbackVelocity = Offset.zero;
        break;
      case AbilityEffectKind.stun:
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.survivalCrowdControlDuration(
            effect,
            effectDuration,
          ),
        );
        enemy.slowMultiplier = min(
          enemy.slowMultiplier,
          CosmicAbilityRuntime.survivalSlowMultiplier(effect),
        );
        enemy.attackCooldown = max(enemy.attackCooldown, effectDuration);
        break;
      case AbilityEffectKind.suppressShooting:
        // Wing+Dust disorient: tag the enemy so its shots hit other
        // enemies instead of the orb/ship while disoriented.
        enemy.disorientTimer = max(enemy.disorientTimer, effectDuration);
        enemy.attackCooldown = max(enemy.attackCooldown, effectDuration * 0.4);
        break;
      case AbilityEffectKind.burn:
      case AbilityEffectKind.poison:
      case AbilityEffectKind.zoneDamage:
      case AbilityEffectKind.geyser:
        _damageEnemy(enemy, effectPower, sourceSlotIndex: sourceSlotIndex);
        if (effect == AbilityEffectKind.geyser) {
          enemy.knockbackVelocity += Offset(0, -140);
        }
        break;
      case AbilityEffectKind.execute:
        _damageEnemy(
          enemy,
          CosmicAbilityRuntime.directDamageForEffect(
            effect,
            power: effectPower,
            targetHp: enemy.hp,
            targetHpFraction: enemy.hpFraction,
          ),
          sourceSlotIndex: sourceSlotIndex,
        );
        break;
      case AbilityEffectKind.splash:
      case AbilityEffectKind.split:
      case AbilityEffectKind.chain:
        _visitEnemiesNear(enemy.position, effectRadius, (other) {
          if (identical(other, enemy)) return false;
          if (!_withinRange(enemy.position, other.position, effectRadius)) {
            return false;
          }
          _damageEnemy(
            other,
            effectPower * CosmicAbilityRuntime.splashMultiplier(effect),
            sourceSlotIndex: sourceSlotIndex,
          );
          return false;
        });
        break;
      case AbilityEffectKind.pull:
      case AbilityEffectKind.blackHole:
        _visitEnemiesNear(origin, effectRadius, (other) {
          final dir = origin - other.position;
          final dist = dir.distance;
          if (dist <= 0.01 || dist > effectRadius) return false;
          other.position += (dir / dist) * min(28.0, 720.0 / dist);
          other.slowTimer = max(other.slowTimer, effectDuration);
          other.slowMultiplier = min(other.slowMultiplier, 0.25);
          if (effect == AbilityEffectKind.blackHole &&
              other.hpFraction <= 0.18) {
            _damageEnemy(other, other.hp + 1, sourceSlotIndex: sourceSlotIndex);
          }
          return false;
        });
        break;
      case AbilityEffectKind.leech:
      case AbilityEffectKind.zoneHeal:
        _healOrb(effectPower * 0.45);
        final comp = sourceSlotIndex != null
            ? activeCompanions[sourceSlotIndex]
            : null;
        if (comp != null && !comp.isDead) {
          comp.currentHp = min(
            comp.maxHp,
            comp.currentHp + effectPower.round(),
          );
        } else if (!ship.isDead) {
          ship.currentHp = min(ship.maxHp, ship.currentHp + effectPower);
        }
        break;
      case AbilityEffectKind.buff:
      case AbilityEffectKind.cooldownRefund:
        final comp = sourceSlotIndex != null
            ? activeCompanions[sourceSlotIndex]
            : null;
        if (comp != null) {
          comp.basicHasteTimer = max(comp.basicHasteTimer, effectDuration);
          comp.basicHasteMultiplier = min(comp.basicHasteMultiplier, 0.72);
          if (effect == AbilityEffectKind.cooldownRefund) {
            comp.specialCooldown = max(0, comp.specialCooldown - 0.45);
          }
          // Mask+Ice pillar passive: the icy trap broadcasts a damage amp
          // to the caster (and any allied companion within range below).
          if (comp.member.family.toLowerCase() == 'mask' &&
              comp.member.element == 'Ice') {
            for (final entry in activeCompanions.entries) {
              final ally = entry.value;
              if (ally.isDead) continue;
              if ((ally.position - origin).distance > effectRadius * 1.4) {
                continue;
              }
              ally.damageAmpTimer = max(ally.damageAmpTimer, effectDuration);
              ally.damageAmpMultiplier = max(ally.damageAmpMultiplier, 2.4);
            }
          }
        }
        break;
      case AbilityEffectKind.taunt:
        enemy.slowTimer = max(enemy.slowTimer, effectDuration * 0.5);
        break;
      case AbilityEffectKind.carry:
        final dir = enemy.position - origin;
        final dist = dir.distance;
        if (dist > 0.01) enemy.position += (dir / dist) * 18.0;
        break;
      case AbilityEffectKind.alchemyBonus:
      case AbilityEffectKind.flower:
        _healOrb(effectPower * 0.30);
        break;
      case AbilityEffectKind.refraction:
      case AbilityEffectKind.chargeBlast:
        _damageEnemy(
          enemy,
          CosmicAbilityRuntime.directDamageForEffect(
            effect,
            power: effectPower,
            targetHp: enemy.hp,
            targetHpFraction: enemy.hpFraction,
          ),
          sourceSlotIndex: sourceSlotIndex,
        );
        break;
      case AbilityEffectKind.none:
        break;
    }
  }

  void _activateWingBeamEffects(
    List<WingBeamEffect> beams, {
    required int sourceSlotIndex,
    required Offset origin,
    required double angle,
  }) {
    if (beams.isEmpty) return;
    for (final beam in beams) {
      if (_activeWingBeams.length >= 14) _activeWingBeams.removeAt(0);
      _activeWingBeams.add(
        _ActiveWingBeam(
          descriptor: beam,
          sourceSlotIndex: sourceSlotIndex,
          origin: origin,
          angle: angle,
        ),
      );
      // Wing+Earth: the orb co-fires a mirror laser alongside the wing.
      if (beam.element == 'Earth') {
        if (_activeWingBeams.length >= 14) _activeWingBeams.removeAt(0);
        _activeWingBeams.add(
          _ActiveWingBeam(
            descriptor: beam,
            sourceSlotIndex: sourceSlotIndex,
            origin: orb.position,
            angle: angle,
            anchorToOrb: true,
          ),
        );
      }
    }
  }

  void _updateBeamEffects(double dt) {
    for (final beam in _activeWingBeams) {
      beam.life -= dt;
      // Re-anchor the beam origin to the live companion each frame so
      // a sustained beam stays attached to the wing as it moves. If
      // the caster died, the beam keeps its last known origin and
      // expires naturally.
      if (beam.anchorToOrb) {
        beam.origin = orb.position;
      } else {
        final caster = activeCompanions[beam.sourceSlotIndex];
        if (caster != null && !caster.isDead) {
          beam.origin = caster.position;
        }
      }
      // Update angle to face the current beam target so the visual
      // tracks live. _beamTargetEndpoint already retargets per tick;
      // we mirror that here for the charge-up rendering.
      if (beam.descriptor.targetPolicy != WingBeamTargetPolicy.ring) {
        final endNow = _beamTargetEndpoint(beam);
        final dir = endNow - beam.origin;
        if (dir.distanceSquared > 0.5) {
          beam.angle = atan2(dir.dy, dir.dx);
        }
      }
      if (beam.chargeTimer > 0) {
        final wasCharging = beam.chargeTimer;
        beam.chargeTimer = max(0.0, beam.chargeTimer - dt);
        final progress = beam.descriptor.chargeTime > 0
            ? 1.0 - (beam.chargeTimer / beam.descriptor.chargeTime)
            : 1.0;
        // Wing+Lightning: render a brewing storm orb at the wing — no
        // directional beam yet. The orb grows and crackles harder as
        // the charge progresses so the blast feels earned. Other
        // element charges (none currently) fall back to a small visual.
        if (beam.descriptor.element == 'Lightning') {
          _renderLightningChargeBrew(beam, progress);
        } else {
          _spawnBeam(
            beam.origin,
            beam.origin,
            elementColor(
              beam.descriptor.element,
            ).withValues(alpha: (0.35 + 0.55 * progress).clamp(0.0, 1.0)),
            width: beam.descriptor.width * (0.35 + 1.65 * progress),
            life: 0.08,
          );
        }
        // When the charge completes, fire one big blast along the
        // current beam line and end the beam. Single tick, massive
        // damage — not a sustained beam.
        if (wasCharging > 0 &&
            beam.chargeTimer <= 0 &&
            beam.descriptor.element == 'Lightning') {
          final blastEnd = _beamTargetEndpoint(beam);
          _resolveLightningBlast(beam, blastEnd);
          beam.life = 0;
        }
        continue;
      }

      final end = _beamTargetEndpoint(beam);
      if (beam.descriptor.targetPolicy == WingBeamTargetPolicy.ring) {
        // Ring beams render as a churning perimeter ring in the paint
        // pass (_renderWingRings) — no spoke beams here.
      } else if (beam.descriptor.targetPolicy ==
          WingBeamTargetPolicy.shipTether) {
        // Tether to ship: draw the cable as a layered line with a
        // bright moving pulse so it reads as a sustained connection
        // rather than a one-shot beam, plus the outgoing strike.
        final tetherColor = elementColor(beam.descriptor.element);
        // Outer cable
        _spawnBeam(
          beam.origin,
          ship.position,
          tetherColor.withValues(alpha: 0.55),
          width: beam.descriptor.width * 0.85,
          life: 0.12,
        );
        // Inner bright core
        _spawnBeam(
          beam.origin,
          ship.position,
          Color.lerp(tetherColor, const Color(0xFFFFFFFF), 0.6)!,
          width: beam.descriptor.width * 0.35,
          life: 0.12,
        );
        // Animated pulse moving along the tether — flicker between two
        // mid-points so it reads as energy flowing toward the ship.
        final pulseT = (beam.life * 2.4) % 1.0;
        final pulseMid = Offset.lerp(beam.origin, ship.position, pulseT)!;
        _spawnBeam(
          pulseMid,
          Offset.lerp(pulseMid, ship.position, 0.18)!,
          const Color(0xFFFFFFFF).withValues(alpha: 0.85),
          width: beam.descriptor.width * 0.65,
          life: 0.05,
        );
        // Outgoing ship→target strike
        _spawnBeam(
          ship.position,
          end,
          tetherColor,
          width: beam.descriptor.width,
          life: 0.08,
        );
      } else {
        // Heal-ray differentiation: beams that heal render with a
        // brighter, life-tinted core so support shows distinct from
        // damage beams.
        final isHealing = beam.descriptor.healPerTick > 0;
        final beamColor = isHealing
            ? Color.lerp(
                elementColor(beam.descriptor.element),
                const Color(0xFFCFFFD8),
                0.55,
              )!
            : elementColor(beam.descriptor.element);
        _spawnBeam(
          beam.origin,
          end,
          beamColor,
          width: beam.descriptor.width,
          life: 0.08,
        );
        if (isHealing) {
          // Inner white-green core for healing beams.
          _spawnBeam(
            beam.origin,
            end,
            const Color(0xFFEFFFF1).withValues(alpha: 0.85),
            width: beam.descriptor.width * 0.45,
            life: 0.08,
          );
        }
      }

      // Alchemical particle accents along/at the beam endpoint.
      // Runs every frame so the beam reads as a living energy
      // stream instead of a flat line. Per-element flavor.
      _renderWingBeamParticles(beam, end);

      beam.tickTimer -= dt;
      if (beam.tickTimer > 0) continue;
      beam.tickTimer += beam.descriptor.tickInterval;
      _resolveBeamTick(beam, end);
    }
    if (_pendingWingBeams.isNotEmpty) {
      for (final beam in _pendingWingBeams) {
        if (_activeWingBeams.length >= 14) _activeWingBeams.removeAt(0);
        _activeWingBeams.add(beam);
      }
      _pendingWingBeams.clear();
    }
    _activeWingBeams.removeWhere((beam) => beam.dead);
  }

  Offset _beamTargetEndpoint(_ActiveWingBeam beam) {
    final d = beam.descriptor;
    final fallback =
        beam.origin + Offset(cos(beam.angle), sin(beam.angle)) * d.range;
    // Water: beam anchors to the lowest-HP-fraction ally companion or
    // the ship within range, so the healing beam visually connects to
    // the support target (and damages anything crossing its path).
    if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip) {
      Offset? bestPos;
      var bestFraction = double.infinity;
      if (!ship.isDead && ship.maxHp > 0) {
        final dist = (ship.position - beam.origin).distance;
        if (dist <= d.range) {
          final f = ship.currentHp / ship.maxHp;
          if (f < bestFraction) {
            bestFraction = f;
            bestPos = ship.position;
          }
        }
      }
      for (final c in activeCompanions.values) {
        if (c.isDead || c.maxHp <= 0) continue;
        if (c.slotIndex == beam.sourceSlotIndex) continue;
        if ((c.position - beam.origin).distance > d.range) continue;
        final f = c.currentHp / c.maxHp;
        if (f < bestFraction) {
          bestFraction = f;
          bestPos = c.position;
        }
      }
      if (bestPos != null) return bestPos;
      return fallback;
    }
    CosmicSurvivalEnemy? target;
    if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthEnemy) {
      for (final enemy in enemies) {
        if (enemy.isDead) continue;
        if ((enemy.position - beam.origin).distance > d.range) continue;
        if (target == null || enemy.hpFraction < target.hpFraction) {
          target = enemy;
        }
      }
    } else {
      target = _nearestEnemyTo(beam.origin, d.range);
    }
    if (target != null) return target.position;
    SurvivalBoss? bestBoss;
    double bestDist = d.range;
    for (final b in allLivingBosses) {
      final bd = (b.position - beam.origin).distance;
      if (bd <= bestDist) {
        bestDist = bd;
        bestBoss = b;
      }
    }
    if (bestBoss != null) return bestBoss.position;
    return fallback;
  }

  void _resolveBeamTick(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    // Wing+Lava: beam carves a glowing scar that does ground DoT.
    // Drop a small lava zone at the beam's tip per tick so a
    // sustained beam paints a damaging line across the field.
    // Scar size scales with beauty, life with intelligence.
    if (d.element == 'Lava') {
      final lavaBeauty = _effectiveBeauty(beam.sourceSlotIndex);
      final lavaIntel = _effectiveIntelligence(beam.sourceSlotIndex);
      final lavaSize = _hornStatScale(
        lavaBeauty,
        perPoint: 0.10,
        min: 0.85,
        max: 1.30,
      );
      final lavaDur = _hornStatScale(
        lavaIntel,
        perPoint: 0.10,
        min: 0.88,
        max: 1.30,
      );
      _appendCompanionProjectile(
        Projectile(
          position: end,
          angle: 0,
          element: 'Lava',
          damage: 0,
          life: 2.6 * lavaDur,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: 1.2 * lavaSize,
          visualScale: 1.1 * lavaSize,
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: beam.sourceSlotIndex,
          abilityFamily: 'wing',
          tickEffect: AbilityEffectKind.burn,
          effectPower: d.damagePerTick * 0.45,
          effectRadius: 38 * lavaSize,
          effectDuration: 2.6 * lavaDur,
        ),
      );
    }
    if (d.healPerTick > 0) {
      if (!ship.isDead) {
        ship.currentHp = min(ship.maxHp, ship.currentHp + d.healPerTick);
      }
      _healOrb(d.healPerTick * 0.55);
      final comp = activeCompanions[beam.sourceSlotIndex];
      if (comp != null && !comp.isDead) {
        comp.currentHp = min(
          comp.maxHp,
          comp.currentHp + d.healPerTick.round(),
        );
      }
    }

    if (d.targetPolicy == WingBeamTargetPolicy.ring && d.radius > 0) {
      _visitEnemiesNear(beam.origin, d.radius, (enemy) {
        if (!_withinRange(beam.origin, enemy.position, d.radius)) return false;
        _damageEnemy(
          enemy,
          d.damagePerTick,
          sourceSlotIndex: beam.sourceSlotIndex,
        );
        _applyAbilityEffectToEnemy(
          d.tickEffect,
          enemy,
          beam.origin,
          d.effectPower,
          d.radius,
          d.effectDuration,
          sourceSlotIndex: beam.sourceSlotIndex,
        );
        return false;
      });
    } else {
      final radius = max(10.0, d.width * 1.45);
      _visitEnemiesNear(beam.origin, (end - beam.origin).distance + radius, (
        enemy,
      ) {
        final distance = _distanceToSegment(enemy.position, beam.origin, end);
        if (distance > enemy.radius + radius) return false;
        // Wing+Steam: the beam executes the first enemy it touches and
        // erupts a field of steam clouds at the kill site.
        if (d.element == 'Steam' && !beam.steamKillUsed && !enemy.isDead) {
          beam.steamKillUsed = true;
          final killPos = enemy.position;
          _damageEnemy(
            enemy,
            enemy.hp + 1,
            sourceSlotIndex: beam.sourceSlotIndex,
          );
          _spawnSteamClouds(killPos, d, beam.sourceSlotIndex);
          return false;
        }
        final beforeDead = enemy.isDead;
        final plantBonus = d.element == 'Plant'
            ? _wingPlantStackBonus(beam.sourceSlotIndex)
            : 1.0;
        _damageEnemy(
          enemy,
          _beamDamageForEnemy(d, enemy) * plantBonus,
          sourceSlotIndex: beam.sourceSlotIndex,
        );
        _applyAbilityEffectToEnemy(
          d.tickEffect,
          enemy,
          beam.origin,
          d.effectPower,
          radius * 6,
          d.effectDuration,
          sourceSlotIndex: beam.sourceSlotIndex,
        );
        // Wing+Ice: each tick ramps frost buildup; once full the enemy
        // snaps into a hard freeze and the buildup resets.
        if (d.element == 'Ice' && !enemy.isDead) {
          enemy.frostBuildup = min(1.0, enemy.frostBuildup + 0.14);
          if (enemy.frostBuildup >= 1.0) {
            enemy.frostBuildup = 0;
            enemy.slowTimer = max(enemy.slowTimer, 2.6);
            enemy.slowMultiplier = min(enemy.slowMultiplier, 0.05);
            enemy.knockbackVelocity = Offset.zero;
            _spawnHitSpark(enemy.position, elementColor('Ice'));
          }
        }
        // Wing+Light: a beam kill refracts into two smaller beams that
        // hunt nearby enemies for the rest of the beam's duration.
        if (!beforeDead && enemy.isDead && d.element == 'Light') {
          _spawnLightSplitBeams(beam);
        }
        // Wing+Plant: enemies killed by the beam turn into flower
        // pickups. Orb collects them to power up the wing.
        if (!beforeDead && enemy.isDead && d.element == 'Plant') {
          _spawnFlowerPickup(enemy.position, beam.sourceSlotIndex);
        }
        return false;
      });
    }

    for (final boss in allLivingBosses) {
      final hitsBoss = d.targetPolicy == WingBeamTargetPolicy.ring
          ? _withinRange(beam.origin, boss.position, d.radius + boss.radius)
          : _distanceToSegment(boss.position, beam.origin, end) <=
                boss.radius + max(10.0, d.width * 1.45);
      if (hitsBoss) {
        damageBoss(
          d.damagePerTick,
          attackElement: d.element,
          sourceSlotIndex: beam.sourceSlotIndex,
          target: boss,
        );
      }
    }
  }

  // Returns true if the slot's Horn+Light barrier projectile is still
  // alive on the field. Used to lock the horn in place during its
  // barrier channel + to short-circuit the ally-protection check.
  bool _hornLightBarrierActive(int slotIndex) {
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex &&
          p.abilityFamily == 'horn' &&
          p.element == 'Light' &&
          p.stationary &&
          p.reflectsProjectiles &&
          p.life > 0) {
        return true;
      }
    }
    return false;
  }

  // Returns the position+radius of any active Horn+Light barrier
  // (regardless of caster) so ally companions inside it get the
  // damage-reduction protect.
  (Offset, double)? _activeHornLightBarrier() {
    for (final p in companionProjectiles) {
      if (p.abilityFamily == 'horn' &&
          p.element == 'Light' &&
          p.stationary &&
          p.reflectsProjectiles &&
          p.life > 0) {
        // Barrier protect radius ≈ visual size of the zone.
        return (p.position, 70.0 + p.radiusMultiplier * 20.0);
      }
    }
    return null;
  }

  // Generic horn stat-scaling helper. Mirrors the cosmic_data
  // `_specialStatScaleFromBaseline` math so survival-side hooks
  // (passive auras, kill effects, wind-up magnitudes) can scale
  // off the caster's genetic stats the same way the spec-side
  // projectile fields do. Baseline stat is 3.0 → 1.0×.
  double _hornStatScale(
    double stat, {
    double perPoint = 0.12,
    double min = 0.82,
    double max = 1.22,
  }) {
    final clamped = stat.clamp(0.5, 8.0);
    return (1.0 + (clamped - 3.0) * perPoint).clamp(min, max).toDouble();
  }

  // Per-element kill-effect dispatcher for horn specials. Called
  // from _killEnemy when an enemy dies inside the casting horn's
  // active window. Steam, Lava, and Blood each get their unique
  // post-kill payoff per the design board.
  void _applyHornSpecialKillEffect(
    CosmicSurvivalCompanion comp,
    CosmicSurvivalEnemy enemy,
    int? sourceSlotIndex,
  ) {
    switch (comp.member.element) {
      case 'Steam':
        // Reset the special cooldown so a streak chain-casts the
        // ability, and drop another geyser at the kill site. Geyser
        // size scales with beauty, duration scales with intelligence.
        comp.specialCooldown = 0;
        final steamBeauty = sourceSlotIndex != null
            ? _effectiveBeauty(sourceSlotIndex)
            : 3.0;
        final steamIntel = sourceSlotIndex != null
            ? _effectiveIntelligence(sourceSlotIndex)
            : 3.0;
        final steamSizeScale = _hornStatScale(
          steamBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.25,
        );
        final steamDurScale = _hornStatScale(
          steamIntel,
          perPoint: 0.08,
          min: 0.88,
          max: 1.20,
        );
        _appendCompanionProjectile(
          Projectile(
            position: enemy.position,
            angle: 0,
            element: 'Steam',
            damage: 0,
            life: 2.6 * steamDurScale,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            radiusMultiplier: 1.6 * steamSizeScale,
            visualScale: 1.6 * steamSizeScale,
            visualStyle: ProjectileVisualStyle.hornImpact,
            sourceSlotIndex: sourceSlotIndex,
            abilityFamily: 'horn',
            tauntRadius: 100.0 * steamSizeScale,
            tauntStrength: 1.0,
            tickEffect: AbilityEffectKind.geyser,
            effectPower: max(1.0, comp.elemAtk * 0.5),
            effectRadius: 60.0 * steamSizeScale,
            effectDuration: 2.6 * steamDurScale,
          ),
        );
        break;
      case 'Lava':
        // Explosion VFX at the kill site (replaces the persistent
        // pool — user flagged it as too cheesy).
        _spawnLavaKillExplosion(enemy.position);
        // Seek radius + flame count scale with caster's beauty —
        // high-stat Lava horns blanket a wider kill zone with
        // more chasers.
        final lavaBeauty = sourceSlotIndex != null
            ? _effectiveBeauty(sourceSlotIndex)
            : 3.0;
        final lavaScale = _hornStatScale(
          lavaBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.30,
        );
        final seekRadius = 280.0 * lavaScale;
        final nearbyTargets = <CosmicSurvivalEnemy>[];
        _visitEnemiesNear(enemy.position, seekRadius, (other) {
          if (other.isDead || identical(other, enemy)) return false;
          if (!_withinRange(enemy.position, other.position, seekRadius)) {
            return false;
          }
          nearbyTargets.add(other);
          return false;
        });
        if (nearbyTargets.isEmpty) {
          // No one nearby to seek — skip spawning flames entirely.
          break;
        }
        final maxFlames = (4 * lavaScale).round().clamp(3, 6);
        final flameCount = min(maxFlames, nearbyTargets.length);
        for (var i = 0; i < flameCount; i++) {
          final tgt = nearbyTargets[i % nearbyTargets.length];
          final dir = tgt.position - enemy.position;
          final ang = atan2(dir.dy, dir.dx);
          _appendCompanionProjectile(
            Projectile(
              position: enemy.position,
              angle: ang,
              element: 'Fire',
              damage: max(1.0, comp.elemAtk * 0.50),
              // Short life — flame fizzles if it doesn't reach a
              // target quickly, so the field doesn't get polluted.
              life: 1.4,
              speedMultiplier: 1.5,
              homing: true,
              homingStrength: 4.0,
              piercing: false,
              radiusMultiplier: 0.9,
              visualScale: 0.95,
              visualStyle: ProjectileVisualStyle.standard,
              sourceSlotIndex: sourceSlotIndex,
              abilityFamily: 'horn',
            ),
          );
        }
        break;
      case 'Blood':
        // Heals the horn back per kill — sustains the HP-sacrifice
        // cost over a kill streak. Heal % scales with beauty so
        // high-stat Blood horns convert more sacrificed HP back
        // through their kill streak.
        final bloodBeauty = sourceSlotIndex != null
            ? _effectiveBeauty(sourceSlotIndex)
            : 3.0;
        final bloodScale = _hornStatScale(
          bloodBeauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.40,
        );
        final heal = max(2, (comp.maxHp * 0.05 * bloodScale).round());
        final before = comp.currentHp;
        comp.currentHp = min(comp.maxHp, comp.currentHp + heal);
        if (comp.slotIndex >= 0) {
          _recordHeal(
            (comp.currentHp - before).toDouble(),
            target: 0,
            sourceSlot: comp.slotIndex,
          );
        }
        break;
    }
  }

  // Per-frame alchemical particles along an active wing beam — gives
  // each elemental beam a living, particle-driven feel instead of
  // looking like a flat colored line. Spawn budget is tight so a
  // field of active beams doesn't saturate the global VFX cap.
  void _renderWingBeamParticles(_ActiveWingBeam beam, Offset end) {
    if (_vfx.length >= 135) return;
    final element = beam.descriptor.element;
    final base = elementColor(element);
    final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.55)!;
    // Ring/tether beams don't have a clean origin→end line to follow.
    final isRing = beam.descriptor.targetPolicy == WingBeamTargetPolicy.ring;
    final isTether =
        beam.descriptor.targetPolicy == WingBeamTargetPolicy.shipTether;
    if (isRing) {
      // Ring beams — particles along the perimeter every frame.
      final r = beam.descriptor.radius;
      if (r <= 0) return;
      for (var i = 0; i < 3; i++) {
        final a = _rng.nextDouble() * 2 * pi;
        final spawnR = r * (0.92 + _rng.nextDouble() * 0.18);
        // Drift tangentially (rotating ring) + slight outward.
        final tang = Offset(-sin(a), cos(a));
        final out = Offset(cos(a), sin(a));
        _vfx.add(
          _VfxParticle(
            x: beam.origin.dx + cos(a) * spawnR,
            y: beam.origin.dy + sin(a) * spawnR,
            vx: tang.dx * 30 + out.dx * 12,
            vy: tang.dy * 30 + out.dy * 12,
            size: 1.3 + _rng.nextDouble() * 1.2,
            life: 0.35 + _rng.nextDouble() * 0.3,
            color: i.isEven ? base : white,
          ),
        );
      }
      return;
    }
    if (isTether) {
      // Tether beam — sparkles flowing along the cable from caster
      // toward the ship.
      final flow = (beam.life * 2.4) % 1.0;
      final mid = Offset.lerp(beam.origin, ship.position, flow)!;
      _vfx.add(
        _VfxParticle(
          x: mid.dx,
          y: mid.dy,
          vx: (_rng.nextDouble() - 0.5) * 30,
          vy: (_rng.nextDouble() - 0.5) * 30,
          size: 1.5 + _rng.nextDouble() * 1.0,
          life: 0.3,
          color: white,
        ),
      );
      return;
    }
    // Standard origin→end beams: spawn 2 particles at the endpoint
    // (where damage is happening) and 1 mid-beam particle.
    final dir = end - beam.origin;
    final dist = dir.distance;
    if (dist < 1) return;
    final unit = Offset(dir.dx / dist, dir.dy / dist);
    final perp = Offset(-unit.dy, unit.dx);
    // Endpoint spark cluster — bursts outward from the hit point.
    for (var i = 0; i < 2; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 30 + _rng.nextDouble() * 50;
      _vfx.add(
        _VfxParticle(
          x: end.dx,
          y: end.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 1.4 + _rng.nextDouble() * 1.2,
          life: 0.30 + _rng.nextDouble() * 0.25,
          color: i.isEven ? base : white,
        ),
      );
    }
    // Mid-beam drifter — random position along the beam, fans
    // perpendicular slightly.
    final t = 0.2 + _rng.nextDouble() * 0.6;
    final midPos = beam.origin + unit * dist * t;
    final side = _rng.nextBool() ? 1.0 : -1.0;
    _vfx.add(
      _VfxParticle(
        x: midPos.dx,
        y: midPos.dy,
        vx: perp.dx * side * 18 + unit.dx * 12,
        vy: perp.dy * side * 18 + unit.dy * 12,
        size: 1.1 + _rng.nextDouble() * 0.9,
        life: 0.30 + _rng.nextDouble() * 0.20,
        color: white.withValues(alpha: 0.75),
      ),
    );
  }

  /// Per-frame ambient zone wisps — the canonical look. The per-element
  /// graphics live in [emitZoneParticles] (shared so cosmic space + dungeons
  /// match); this routes them into survival's [_VfxParticle] pool. Caller
  /// gates on the pool cap.
  void _spawnZoneParticles(Projectile p) {
    emitZoneParticles(p, _rng, (
      x,
      y,
      vx,
      vy,
      size,
      life,
      color, {
      arc = false,
    }) {
      _vfx.add(
        _VfxParticle(
          x: x,
          y: y,
          vx: vx,
          vy: vy,
          size: size,
          life: life,
          color: color,
        ),
      );
    });
  }

  // Horn+Lightning chain blast — one-shot alchemical particle storm
  // radiating from the impact. ~40 particles fanning outward in all
  // directions at varying speeds, with mixed life so the cloud
  // lingers and flashes for ~0.6s instead of disappearing in one
  // frame. Sized off the blast radius so a bigger absorb-discharge
  // reads as a fuller storm.
  void _spawnLightningChainBurst(Offset center, double blastRadius) {
    final base = elementColor('Lightning');
    final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.55)!;
    // Particle count scales with blast radius (40–70 particles).
    final count = (blastRadius * 0.28).clamp(40, 70).round();
    final budget = max(0, 145 - _vfx.length);
    final spawn = min(count, budget);
    for (var i = 0; i < spawn; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      // Mix near-rim and mid-radius spawns for depth.
      final r = blastRadius * (0.15 + _rng.nextDouble() * 0.85);
      final spd = 60 + _rng.nextDouble() * 180;
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * (r * 0.2),
          y: center.dy + sin(a) * (r * 0.2),
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 1.6 + _rng.nextDouble() * 1.8,
          // Mixed life: most short (flash), some long (linger).
          life: _rng.nextDouble() < 0.4
              ? 0.7 + _rng.nextDouble() * 0.5
              : 0.30 + _rng.nextDouble() * 0.30,
          color: _rng.nextBool() ? white : base,
        ),
      );
    }
    // Bright central flash hit-spark for the impact pop.
    _spawnHitSpark(center, white);
  }

  // Horn+Lightning post-dash storm visual. Grows around the horn
  // as the brew counts down. Same crackling-orb feel as the Wing
  // Lightning charge, just elemental-colored for horns.
  void _renderHornLightningStormBrew(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    final center = comp.position;
    const total = 3.0;
    final elapsed = (total - comp.hornPostDashWindUpTimer).clamp(0.0, total);
    final t = elapsed / total;
    final orbR = 18.0 + 30.0 * t;
    final base = elementColor('Lightning');
    final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.55)!;
    final spawnCount = 1 + (t > 0.4 ? 1 : 0) + (t > 0.75 ? 1 : 0);
    for (var i = 0; i < spawnCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final r = orbR * (1.0 + _rng.nextDouble() * 0.7);
      final spd = 35 + 80 * t;
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * r,
          y: center.dy + sin(a) * r,
          vx: -cos(a) * spd,
          vy: -sin(a) * spd,
          size: 1.3 + _rng.nextDouble() * 1.4,
          life: 0.3 + _rng.nextDouble() * 0.3,
          color: i.isEven ? base : white,
        ),
      );
    }
    if (_rng.nextDouble() < 0.30 + t * 0.45) {
      final a1 = _rng.nextDouble() * 2 * pi;
      final a2 = a1 + (_rng.nextDouble() - 0.5) * 2.6;
      final r1 = orbR * (0.35 + _rng.nextDouble() * 0.65);
      final r2 = orbR * (0.35 + _rng.nextDouble() * 0.65);
      _spawnBeam(
        Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
        Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
        white.withValues(alpha: 0.70 + 0.25 * t),
        width: 1.4 + t * 1.4,
        life: 0.08,
      );
    }
  }

  // Horn+Fire: drop a burning trail segment behind the horn during
  // the charge. Cheap stationary DoT zone — overlapping spawns
  // paint a continuous burn lane through the charge path.
  void _spawnFireTrailSegment(int slotIndex, CosmicSurvivalCompanion comp) {
    _appendCompanionProjectile(
      Projectile(
        position: comp.position,
        angle: 0,
        element: 'Fire',
        damage: 0,
        life: 3.2,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 1.2,
        visualScale: 1.25,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: slotIndex,
        abilityFamily: 'horn',
        tauntRadius: 80.0,
        tauntStrength: 1.0,
        tickEffect: AbilityEffectKind.burn,
        effectPower: max(1.0, comp.elemAtk * 0.18),
        effectRadius: 40.0,
        effectDuration: 3.0,
      ),
    );
  }

  // Horn+Lava: charge-time telegraph. Spawns small molten ember
  // particles around the horn while its chargeTimer is winding up,
  // building from a flicker to a bright glow as the slam nears.
  void _renderLavaChargeTelegraph(
    CosmicSurvivalCompanion comp,
    double progress,
  ) {
    if (_vfx.length >= 130) return;
    final center = comp.position;
    final orbR = 18.0 + 14.0 * progress;
    final lavaColor = elementColor('Lava');
    final emberColor = const Color(0xFFFFB050);
    final spawnCount = 1 + (progress > 0.5 ? 1 : 0);
    for (var i = 0; i < spawnCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final r = orbR * (1.0 + _rng.nextDouble() * 0.6);
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * r,
          y: center.dy + sin(a) * r,
          vx: -cos(a) * (20 + 60 * progress),
          vy: -sin(a) * (20 + 60 * progress),
          size: 1.6 + _rng.nextDouble() * 1.4,
          life: 0.35 + _rng.nextDouble() * 0.30,
          color: i.isEven ? lavaColor : emberColor,
        ),
      );
    }
  }

  // Horn+Lava: explosion VFX on enemy kill — radial fire burst at
  // the kill site. Replaces the persistent pool the user flagged
  // as cheesy. Pure VFX, no projectile damage (the dmg-on-kill
  // is delivered by the homing flames spawned alongside).
  void _spawnLavaKillExplosion(Offset center) {
    if (_vfx.length >= 140) return;
    final orange = const Color(0xFFFFA040);
    final yellow = const Color(0xFFFFE08A);
    // 12 radial sparks fanning outward.
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6 + _rng.nextDouble() * 0.4;
      final spd = 140 + _rng.nextDouble() * 80;
      _vfx.add(
        _VfxParticle(
          x: center.dx,
          y: center.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 2.0 + _rng.nextDouble() * 1.8,
          life: 0.35 + _rng.nextDouble() * 0.25,
          color: i.isEven ? orange : yellow,
        ),
      );
    }
    _spawnHitSpark(center, orange);
  }

  // Horn+Ice: drop a single ice-wall segment at the horn's current
  // position during its sideways dash. Segments overlap (spawn rate
  // is timed to ~28px between drops at the standard dash speed) to
  // form a continuous wall. Each segment taunts + slows; Phase 5
  // will wire the projectile-reflect behavior.
  void _spawnIceWallSegment(int slotIndex, CosmicSurvivalCompanion comp) {
    _appendCompanionProjectile(
      Projectile(
        position: comp.position,
        angle: 0,
        element: 'Ice',
        damage: 0,
        life: 4.5,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 1.4,
        visualScale: 1.6,
        visualStyle: ProjectileVisualStyle.hornImpact,
        sourceSlotIndex: slotIndex,
        abilityFamily: 'horn',
        tauntRadius: 90.0,
        tauntStrength: 1.4,
        decoy: true,
        decoyHp: comp.maxHp * 0.10,
        tickEffect: AbilityEffectKind.slow,
        effectPower: max(1.0, comp.elemAtk * 0.12),
        effectRadius: 44.0,
        effectDuration: 2.5,
        // Phase 5: each segment bounces enemy projectiles back at
        // the nearest enemy.
        reflectsProjectiles: true,
      ),
    );
  }

  // Standard horn charge kick-off — sets the dash target/timer from
  // the current companion position toward attackTarget. Shared by
  // the immediate-cast path and the wind-up completion path.
  void _startHornCharge(
    CosmicSurvivalCompanion comp,
    Offset attackTarget,
    double requestedChargeTimer,
  ) {
    final dir = attackTarget - comp.position;
    final dist = dir.distance;
    if (dist > 1) {
      final overshoot =
          attackTarget + (dir / dist) * comp.chargeOvershootDistance;
      comp.chargeTarget = overshoot;
      final travelTime =
          (overshoot - comp.position).distance /
          (CosmicSurvivalCompanion.chargeSpeed * comp.chargeSpeedMultiplier);
      comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
    } else {
      comp.chargeTarget = attackTarget;
      comp.chargeTimer = requestedChargeTimer.clamp(0.3, 3.0);
    }
    comp.chargeHitIds = <int>{};
  }

  // Per-frame handler for the horn wind-up phase. Locks movement,
  // runs the element-specific tick (Dark void-suck pulls enemies in;
  // Crystal/Spirit are visual-only), and kicks off the dash when the
  // wind-up timer expires.
  void _handleHornWindUp(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    comp.windUpTimer -= dt;
    final element = comp.windUpElement;
    switch (element) {
      case 'Dark':
        _runHornDarkVoidSuck(slotIndex, comp, dt);
        _renderHornDarkVoidBrew(comp);
        break;
      case 'Crystal':
        _renderHornCrystalOrbit(comp);
        break;
      case 'Spirit':
        _renderHornSpiritSwarm(comp);
        break;
    }
    if (comp.windUpTimer <= 0) {
      // Kick off the dash. Dark uses a forward edge-bound dash
      // along the original fire angle so the captured cluster gets
      // carried toward the map edge; others use the standard
      // attack-target dash.
      if (element == 'Dark') {
        // Snapshot every enemy currently inside the void aura at
        // wind-up completion — these get teleported with the dash
        // to the dash destination and take impact damage there.
        // Capture radius scales with beauty like the suck aura.
        final beauty = _effectiveBeauty(slotIndex);
        final voidScale = _hornStatScale(
          beauty,
          perPoint: 0.10,
          min: 0.85,
          max: 1.30,
        );
        final captureRadius = 200.0 * voidScale;
        final captured = <CosmicSurvivalEnemy>[];
        _visitEnemiesNear(comp.position, captureRadius, (e) {
          if (e.isDead) return false;
          if (!_withinRange(comp.position, e.position, captureRadius)) {
            return false;
          }
          captured.add(e);
          return false;
        });
        comp.hornDarkCaptured = captured;
        final dir = Offset(
          cos(comp.windUpFireAngle),
          sin(comp.windUpFireAngle),
        );
        final dashTarget =
            comp.position + dir * (comp.chargeOvershootDistance + 200.0);
        comp.chargeTarget = dashTarget;
        comp.chargeHitIds = <int>{};
        final travelTime =
            (dashTarget - comp.position).distance /
            (CosmicSurvivalCompanion.chargeSpeed * comp.chargeSpeedMultiplier);
        comp.chargeTimer = (travelTime + 0.15).clamp(0.3, 3.0);
      } else {
        _startHornCharge(
          comp,
          comp.windUpDashTarget ?? comp.position,
          comp.pendingChargeTimerValue,
        );
      }
      comp.windUpElement = '';
      comp.windUpDashTarget = null;
      comp.windUpTimer = 0;
    }
  }

  // Horn+Dark wind-up: every frame, drag nearby enemies toward the
  // horn — feed-the-void behavior. Pull strength ramps over the
  // wind-up so the first second is gentle and the final seconds yank
  // hard. Damage application happens on dash impact (Phase 5).
  void _runHornDarkVoidSuck(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    // Void aura radius scales with beauty — bigger horns project a
    // wider gravitational gather zone. Pull speed stays time-based.
    final beauty = _effectiveBeauty(slotIndex);
    final voidScale = _hornStatScale(
      beauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final auraRadius = 260.0 * voidScale;
    final totalWindUp = 5.0;
    final elapsed = (totalWindUp - comp.windUpTimer).clamp(0.0, totalWindUp);
    final t = elapsed / totalWindUp; // 0 → 1
    final pullSpeed = 90.0 + 220.0 * t; // ramp 90 → 310 px/s
    _visitEnemiesNear(comp.position, auraRadius, (enemy) {
      if (enemy.isDead) return false;
      final dx = comp.position.dx - enemy.position.dx;
      final dy = comp.position.dy - enemy.position.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < 4.0 || distSq > auraRadius * auraRadius) return false;
      final dist = sqrt(distSq);
      final norm = Offset(dx / dist, dy / dist);
      enemy.position = Offset(
        enemy.position.dx + norm.dx * pullSpeed * dt,
        enemy.position.dy + norm.dy * pullSpeed * dt,
      );
      // Gentle drag slow on enemies in the void.
      enemy.slowTimer = max(enemy.slowTimer, 0.3);
      enemy.slowMultiplier = min(enemy.slowMultiplier, 0.55);
      return false;
    });
  }

  // Horn+Dark wind-up visual: a growing ring of inward-spiraling
  // shadow sparks at the horn's position. Reads as a brewing
  // singularity. Cheap (1–2 particles + occasional dark micro-arc).
  void _renderHornDarkVoidBrew(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    final center = comp.position;
    final totalWindUp = 5.0;
    final elapsed = (totalWindUp - comp.windUpTimer).clamp(0.0, totalWindUp);
    final t = elapsed / totalWindUp;
    final orbRadius = 16.0 + 36.0 * t;
    final spawnCount = 1 + (t > 0.4 ? 1 : 0) + (t > 0.75 ? 1 : 0);
    for (var i = 0; i < spawnCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final r = orbRadius * (1.2 + _rng.nextDouble() * 0.7);
      final speed = 40 + 90 * t;
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * r,
          y: center.dy + sin(a) * r,
          vx: -cos(a) * speed,
          vy: -sin(a) * speed,
          size: 1.4 + _rng.nextDouble() * 1.6,
          life: 0.35 + _rng.nextDouble() * 0.30,
          color: i.isEven
              ? const Color(0xFF1A0A2A)
              : Color.lerp(
                  elementColor('Dark'),
                  const Color(0xFFFFFFFF),
                  0.25,
                )!,
        ),
      );
    }
    if (_rng.nextDouble() < 0.20 + t * 0.40) {
      final a1 = _rng.nextDouble() * 2 * pi;
      final a2 = a1 + (_rng.nextDouble() - 0.5) * 2.6;
      final r1 = orbRadius * (0.30 + _rng.nextDouble() * 0.70);
      final r2 = orbRadius * (0.30 + _rng.nextDouble() * 0.70);
      _spawnBeam(
        Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
        Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
        const Color(0xFFB89AFF).withValues(alpha: 0.55 + 0.25 * t),
        width: 1.2 + t * 1.0,
        life: 0.08,
      );
    }
  }

  // Horn+Crystal wind-up visual: 6 crystal shards orbit the horn at
  // a growing radius, telegraphing the orbital bulwark that will
  // travel with it on the dash.
  void _renderHornCrystalOrbit(CosmicSurvivalCompanion comp) {
    if (_beamFx.length >= 22) return;
    final center = comp.position;
    final totalWindUp = 1.2;
    final elapsed = (totalWindUp - comp.windUpTimer).clamp(0.0, totalWindUp);
    final t = elapsed / totalWindUp;
    final orbitR = 28.0 + 24.0 * t;
    final spinPhase = elapsed * 5.0;
    final crystalColor = elementColor('Crystal');
    final white = Color.lerp(crystalColor, const Color(0xFFFFFFFF), 0.55)!;
    for (var i = 0; i < 6; i++) {
      final a = spinPhase + i * pi * 2 / 6;
      final shardCenter = center + Offset(cos(a), sin(a)) * orbitR;
      // Each shard = small bright dash perpendicular to its tangent.
      final tangent = Offset(-sin(a), cos(a));
      final half = 3.2 + 2.0 * t;
      _spawnBeam(
        shardCenter - tangent * half,
        shardCenter + tangent * half,
        white.withValues(alpha: 0.55 + 0.30 * t),
        width: 2.4 + t * 1.4,
        life: 0.05,
      );
    }
  }

  // Horn+Spirit wind-up visual: ghostly phantom orbs swarm the horn,
  // gathering inward then orbiting tightly. They'll release outward
  // as taunt-spreading decoys when the dash kicks off.
  void _renderHornSpiritSwarm(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    final center = comp.position;
    final totalWindUp = 1.0;
    final elapsed = (totalWindUp - comp.windUpTimer).clamp(0.0, totalWindUp);
    final t = elapsed / totalWindUp;
    final orbR = 14.0 + 12.0 * sin(elapsed * 4.0);
    final swarmCount = 2;
    for (var i = 0; i < swarmCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      // Phantoms start at outer ring and converge inward as t grows.
      final startR = 40.0 + 18.0 * (1.0 - t);
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * startR,
          y: center.dy + sin(a) * startR,
          vx: -cos(a) * (50 + 60 * t),
          vy: -sin(a) * (50 + 60 * t),
          size: 1.8 + _rng.nextDouble() * 1.2,
          life: 0.4 + _rng.nextDouble() * 0.25,
          color: Color.lerp(
            elementColor('Spirit'),
            const Color(0xFFFFFFFF),
            0.55,
          )!.withValues(alpha: 0.7),
        ),
      );
    }
    // Persistent orbit ring marker.
    _spawnBeam(
      center + Offset(orbR, 0),
      center + Offset(-orbR, 0),
      elementColor('Spirit').withValues(alpha: 0.18 + 0.18 * t),
      width: 1.0 + t * 0.6,
      life: 0.05,
    );
  }

  // Horn+Air PASSIVE: enemies inside the aura are continuously
  // pushed radially outward from the horn — they get blown toward
  // the arena's outer ring. An inner deadzone (90px) lets the horn
  // still engage close enemies with its basic attack; only enemies
  // further out get shoved away. Visualized by wind-particle bursts
  // that fly outward from the deadzone edge to the aura rim, so the
  // player can see the push range without a hardcoded ring.
  void _applyHornAirPassive(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    // Aura radii + push speed scale with intelligence — a high-stat
    // Air horn projects its wind aura further and pushes harder.
    final intel = _effectiveIntelligence(slotIndex);
    final scale = _hornStatScale(intel, perPoint: 0.10, min: 0.85, max: 1.30);
    final innerRadius = 90.0 * scale;
    final auraRadius = 230.0 * scale;
    final pushSpeed = 80.0 * scale;
    _visitEnemiesNear(comp.position, auraRadius, (enemy) {
      if (enemy.isDead) return false;
      final dx = enemy.position.dx - comp.position.dx;
      final dy = enemy.position.dy - comp.position.dy;
      final distSq = dx * dx + dy * dy;
      // Inside the deadzone: leave them — basic attack handles those.
      if (distSq < innerRadius * innerRadius) return false;
      if (distSq > auraRadius * auraRadius) return false;
      final dist = sqrt(distSq);
      // Falloff: full push just past the deadzone, fading to 0 at rim.
      final falloff = 1.0 - ((dist - innerRadius) / (auraRadius - innerRadius));
      final speed = pushSpeed * (0.45 + 0.55 * falloff);
      final norm = Offset(dx / dist, dy / dist);
      enemy.position = Offset(
        enemy.position.dx + norm.dx * speed * dt,
        enemy.position.dy + norm.dy * speed * dt,
      );
      return false;
    });
    // Spawn outward wind particles: they fly from the deadzone edge
    // to the rim, traveling at roughly the push speed so they trace
    // the visible push range without a static ring.
    if (_vfx.length >= 130) return;
    comp.hornAirParticleTimer -= dt;
    if (comp.hornAirParticleTimer <= 0) {
      // ~12 particles/sec from each Air horn.
      comp.hornAirParticleTimer = 0.085;
      // Particle travel time must roughly match aura span / speed so
      // the wisp dies right around the rim.
      const travelSpeed = 140.0;
      final travelLife = (auraRadius - innerRadius) / travelSpeed;
      final airColor = elementColor('Air');
      for (var i = 0; i < 2; i++) {
        final a = _rng.nextDouble() * 2 * pi;
        final startR = innerRadius + _rng.nextDouble() * 6.0;
        _vfx.add(
          _VfxParticle(
            x: comp.position.dx + cos(a) * startR,
            y: comp.position.dy + sin(a) * startR,
            vx: cos(a) * travelSpeed,
            vy: sin(a) * travelSpeed,
            size: 1.3 + _rng.nextDouble() * 0.8,
            life: travelLife,
            color: airColor.withValues(alpha: 0.55),
          ),
        );
      }
    }
  }

  // Horn+Mud PASSIVE: drops a slowing sludge sigil at a stat-scaled
  // cadence while the horn is moving and NOT tethered to the ship.
  // Cadence scales with intelligence: at stat 3.0 the trail is sparse
  // (~40% volume of max), at stat 5.0+ it's dense. Disabled while
  // magnet-to-ship recall so it doesn't carpet the orb's standoff.
  void _applyHornMudPassive(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    if (comp.tethered) return;
    comp.hornMudTrailTimer -= dt;
    if (comp.hornMudTrailTimer > 0) return;
    // Stat 3.0 → 1.45s interval (~40% of max trail rate)
    // Stat 5.0 → 0.58s interval (dense trail)
    final intel = _effectiveIntelligence(slotIndex);
    final t = ((intel - 3.0) / 2.0).clamp(0.0, 1.0);
    final interval = 1.45 + (0.58 - 1.45) * t;
    comp.hornMudTrailTimer = interval;
    // Tiny per-spawn position jitter so the trail doesn't read as a
    // perfectly straight pixel line when the horn moves in a line.
    final jitter = Offset(
      (_rng.nextDouble() - 0.5) * 8.0,
      (_rng.nextDouble() - 0.5) * 8.0,
    );
    _appendCompanionProjectile(
      Projectile(
        position: comp.position + jitter,
        angle: 0,
        element: 'Mud',
        damage: 0,
        life: 4.5,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 1.20,
        visualScale: 1.10,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: slotIndex,
        abilityFamily: 'horn',
        tickEffect: AbilityEffectKind.slow,
        effectPower: max(1.0, comp.elemAtk * 0.08),
        effectRadius: 48.0,
        effectDuration: 1.4,
      ),
    );
  }

  // Horn+Poison PASSIVE: constant toxic aura around the horn ticks
  // poison damage every 0.6s to enemies in range, and drops a faint
  // short-lived poison puff at the horn's position so the player can
  // see a visible trail. Damage scales with the horn's elemAtk.
  void _applyHornPoisonPassive(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    comp.hornPoisonAuraTimer -= dt;
    if (comp.hornPoisonAuraTimer > 0) return;
    comp.hornPoisonAuraTimer = 0.6;
    // Aura radius scales with intelligence; tick damage already
    // scales via elemAtk.
    final intel = _effectiveIntelligence(slotIndex);
    final auraScale = _hornStatScale(
      intel,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final auraRadius = 140.0 * auraScale;
    final tickDamage = max(1.0, comp.elemAtk * 0.18);
    _visitEnemiesNear(comp.position, auraRadius, (enemy) {
      if (enemy.isDead) return false;
      if (!_withinRange(comp.position, enemy.position, auraRadius)) {
        return false;
      }
      _damageEnemy(enemy, tickDamage, sourceSlotIndex: slotIndex);
      return false;
    });
    // Faint visible-aura puff at the horn's position. Short-lived so
    // a moving horn paints a soft poison trail without piling sigils.
    _appendCompanionProjectile(
      Projectile(
        position: comp.position,
        angle: 0,
        element: 'Poison',
        damage: 0,
        life: 1.4,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 1.30 * auraScale,
        visualScale: 1.20 * auraScale,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: slotIndex,
        abilityFamily: 'horn',
        // Tag the puff as a visible aura marker — no extra tick
        // damage (the per-frame loop already handled that), but
        // tickEffect.none would route it away from the mask painter.
        // Use poison tick at 0 power so it still renders as a zone.
        tickEffect: AbilityEffectKind.poison,
        effectPower: 0,
        effectRadius: 60.0 * auraScale,
        effectDuration: 1.4,
      ),
    );
  }

  // Wing+Lightning: brewing storm visual while the beam charges. A
  // growing orb of inward-spiraling sparks + crackling micro-arcs
  // anchored at the wing's position. Spawn budgets are conservative
  // (1–2 particles + occasional arc per frame) so a 3s charge doesn't
  // saturate the global vfx caps.
  void _renderLightningChargeBrew(_ActiveWingBeam beam, double progress) {
    if (_vfx.length >= 130) return;
    final center = beam.origin;
    final color = elementColor('Lightning');
    final white = Color.lerp(color, const Color(0xFFFFFFFF), 0.55)!;
    // Orb radius grows from a tight 10px to a stormy 34px as it builds.
    final orbRadius = 10.0 + 24.0 * progress;
    // 1 inward spark always, +1 more in the back half of the charge.
    final sparkCount = 1 + (progress > 0.5 ? 1 : 0);
    for (var i = 0; i < sparkCount; i++) {
      final a = _rng.nextDouble() * 2 * pi;
      final r = orbRadius * (1.1 + _rng.nextDouble() * 0.7);
      final speed = 35 + 70 * progress;
      _vfx.add(
        _VfxParticle(
          x: center.dx + cos(a) * r,
          y: center.dy + sin(a) * r,
          vx: -cos(a) * speed,
          vy: -sin(a) * speed,
          size: 1.0 + _rng.nextDouble() * 1.6,
          life: 0.35 + _rng.nextDouble() * 0.35,
          color: i.isEven ? color : white,
        ),
      );
    }
    // Occasional crackling micro-arc inside the orb. Frequency ramps
    // with progress so the storm feels increasingly unstable.
    if (_rng.nextDouble() < 0.30 + progress * 0.45) {
      final a1 = _rng.nextDouble() * 2 * pi;
      final a2 = a1 + (_rng.nextDouble() - 0.5) * 2.6;
      final r1 = orbRadius * (0.35 + _rng.nextDouble() * 0.65);
      final r2 = orbRadius * (0.35 + _rng.nextDouble() * 0.65);
      _spawnBeam(
        Offset(center.dx + cos(a1) * r1, center.dy + sin(a1) * r1),
        Offset(center.dx + cos(a2) * r2, center.dy + sin(a2) * r2),
        white.withValues(alpha: 0.65 + 0.25 * progress),
        width: 1.1 + progress * 1.2,
        life: 0.08,
      );
    }
  }

  // Wing+Lightning: after the 3s charge, fire a single massive blast
  // along the beam line — one big damage event, not a sustained beam.
  // Blast magnitude inherits damagePerTick (which already scales with
  // caster stats), per design that "scaling stats only affect blast
  // size, not charge time".
  void _resolveLightningBlast(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    final blastColor = Color.lerp(
      elementColor('Lightning'),
      const Color(0xFFFFFFFF),
      0.55,
    )!;
    // Wide bright beam flash for the blast itself.
    _spawnBeam(beam.origin, end, blastColor, width: d.width * 3.4, life: 0.28);
    _spawnBeam(
      beam.origin,
      end,
      const Color(0xFFFFFFFF).withValues(alpha: 0.85),
      width: d.width * 1.4,
      life: 0.22,
    );
    final radius = max(22.0, d.width * 2.6);
    // One-shot blast damage. ~18× per-tick — comparable to the total
    // damage a sustained 2.8× chargeBlast beam would deal over its
    // post-charge window, compressed into a single hit.
    final blastDamage = d.damagePerTick * 18.0;
    _visitEnemiesNear(beam.origin, (end - beam.origin).distance + radius, (
      enemy,
    ) {
      if (enemy.isDead) return false;
      final distance = _distanceToSegment(enemy.position, beam.origin, end);
      if (distance > enemy.radius + radius) return false;
      _damageEnemy(enemy, blastDamage, sourceSlotIndex: beam.sourceSlotIndex);
      _applyAbilityEffectToEnemy(
        d.tickEffect,
        enemy,
        beam.origin,
        d.effectPower * 3.0,
        radius * 6,
        d.effectDuration,
        sourceSlotIndex: beam.sourceSlotIndex,
      );
      return false;
    });
    for (final boss in allLivingBosses) {
      if (_distanceToSegment(boss.position, beam.origin, end) <=
          boss.radius + radius) {
        damageBoss(
          blastDamage,
          attackElement: 'Lightning',
          sourceSlotIndex: beam.sourceSlotIndex,
          target: boss,
        );
      }
    }
    _spawnHitSpark(end, elementColor('Lightning'));
  }

  // Wing+Steam: erupt a cluster of lingering steam clouds that deal
  // damage-over-time around a kill site.
  void _spawnSteamClouds(Offset center, WingBeamEffect d, int sourceSlotIndex) {
    // Per design: 5–10 clouds. Beauty bumps the floor + ceiling so
    // high-stat Steam wings get a denser field. Intel stretches the
    // cloud life. Cloud size scales with beauty too.
    final beauty = _effectiveBeauty(sourceSlotIndex);
    final intel = _effectiveIntelligence(sourceSlotIndex);
    final countScale = _hornStatScale(
      beauty,
      perPoint: 0.08,
      min: 0.85,
      max: 1.30,
    );
    final sizeScale = _hornStatScale(
      beauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final durScale = _hornStatScale(
      intel,
      perPoint: 0.10,
      min: 0.88,
      max: 1.30,
    );
    final baseCount = 5 + _rng.nextInt(6);
    final count = (baseCount * countScale).round().clamp(5, 14);
    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + _rng.nextDouble() * 0.7;
      final dist = (12.0 + _rng.nextDouble() * 52.0) * sizeScale;
      _appendCompanionProjectile(
        Projectile(
          position: center + Offset(cos(a), sin(a)) * dist,
          angle: 0,
          element: 'Steam',
          damage: 0,
          life: 3.4 * durScale,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          radiusMultiplier: 1.4 * sizeScale,
          visualScale: 1.3 * sizeScale,
          visualStyle: ProjectileVisualStyle.sigil,
          sourceSlotIndex: sourceSlotIndex,
          abilityFamily: 'wing',
          tickEffect: AbilityEffectKind.burn,
          effectPower: d.damagePerTick * 0.42,
          effectRadius: 44 * sizeScale,
          effectDuration: 3.4 * durScale,
        ),
      );
    }
  }

  // Wing+Light: on a beam kill the original beam refracts into two
  // smaller hunting beams that live out the parent's remaining duration.
  void _spawnLightSplitBeams(_ActiveWingBeam parent) {
    if (parent.refractionsDone > 0) return;
    final d = parent.descriptor;
    final remaining = parent.life;
    if (remaining < 0.3) return;
    // High-Beauty Light wings refract into 3 child beams instead of 2,
    // and each child carries a bigger damage fraction.
    final beauty = _effectiveBeauty(parent.sourceSlotIndex);
    final refractScale = _hornStatScale(
      beauty,
      perPoint: 0.08,
      min: 0.85,
      max: 1.25,
    );
    final childCount = beauty >= 4.5 ? 3 : 2;
    final child = WingBeamEffect(
      element: 'Light',
      targetPolicy: WingBeamTargetPolicy.nearestEnemy,
      duration: remaining,
      tickInterval: d.tickInterval,
      damagePerTick: d.damagePerTick * 0.55 * refractScale,
      healPerTick: d.healPerTick * 0.55 * refractScale,
      width: d.width * 0.6 * refractScale,
      range: d.range * 0.85,
      tickEffect: d.tickEffect,
      effectPower: d.effectPower * 0.55 * refractScale,
      effectDuration: d.effectDuration,
    );
    for (var i = 0; i < childCount; i++) {
      final offset = childCount == 2
          ? (i == 0 ? -0.5 : 0.5)
          : (i - 1) * 0.45; // -0.45 / 0 / +0.45
      final beam = _ActiveWingBeam(
        descriptor: child,
        sourceSlotIndex: parent.sourceSlotIndex,
        origin: parent.origin,
        angle: parent.angle + offset,
      );
      beam.refractionsDone = 1;
      _pendingWingBeams.add(beam);
    }
  }

  // Renders ring-policy wing beams (Poison, Fire) as a churning
  // perimeter ring rather than a starburst of spokes.
  void _renderWingRings(
    Canvas canvas,
    double cx,
    double cy,
    double viewW,
    double viewH,
  ) {
    if (_activeWingBeams.isEmpty) return;
    final t = stats.timeElapsed;
    for (final beam in _activeWingBeams) {
      final d = beam.descriptor;
      if (d.targetPolicy != WingBeamTargetPolicy.ring || d.radius <= 0) {
        continue;
      }
      final center = beam.origin;
      final r = d.radius;
      if (!_isWithinViewport(
        center,
        r + 24,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 32,
      )) {
        continue;
      }
      final fade = beam.life < 0.45 ? (beam.life / 0.45).clamp(0.0, 1.0) : 1.0;
      final color = elementColor(d.element);
      final isPoison = d.element == 'Poison';

      // Faint interior wash so the ring reads as an enclosed field.
      _wingRingFillPaint.color = color.withValues(alpha: 0.05 * fade);
      canvas.drawCircle(center, r, _wingRingFillPaint);

      // Churning perimeter — a wavy closed path that animates over time.
      final pulse = isPoison ? 0.045 : 0.03;
      const seg = 54;
      final path = Path();
      for (var i = 0; i <= seg; i++) {
        final ang = i * pi * 2 / seg;
        final wob = isPoison
            ? sin(ang * 5 + t * 2.6) * (r * pulse)
            : sin(ang * 8 - t * 4.0) * (r * pulse);
        final rr = r + wob;
        final px = center.dx + cos(ang) * rr;
        final py = center.dy + sin(ang) * rr;
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }
      path.close();

      if (!_reduceSecondaryGlows) {
        _wingRingPaint
          ..color = color.withValues(alpha: 0.20 * fade)
          ..strokeWidth = d.width * 2.4;
        canvas.drawPath(path, _wingRingPaint);
      }
      _wingRingPaint
        ..color = color.withValues(alpha: 0.85 * fade)
        ..strokeWidth = d.width * 0.85;
      canvas.drawPath(path, _wingRingPaint);

      // Inner companion ring, counter-animated for a layered look.
      _wingRingPaint
        ..color = color.withValues(alpha: 0.42 * fade)
        ..strokeWidth = d.width * 0.5;
      canvas.drawCircle(center, r * (isPoison ? 0.86 : 0.9), _wingRingPaint);

      if (isPoison) {
        // Drifting toxic blobs orbiting the ring.
        const blobs = 9;
        for (var i = 0; i < blobs; i++) {
          final ang = i * pi * 2 / blobs + t * 0.6;
          final rr = r + sin(ang * 3 + t * 2.6) * (r * pulse);
          final p = Offset(
            center.dx + cos(ang) * rr,
            center.dy + sin(ang) * rr,
          );
          final bob = 2.2 + sin(t * 3.0 + i) * 1.0;
          _wingRingFillPaint.color = color.withValues(alpha: 0.55 * fade);
          canvas.drawCircle(p, bob, _wingRingFillPaint);
        }
      } else {
        // Fire: a bright arc sweeping around the ring.
        _wingRingPaint
          ..color = Color.lerp(
            color,
            const Color(0xFFFFFFFF),
            0.5,
          )!.withValues(alpha: 0.9 * fade)
          ..strokeWidth = d.width * 1.1;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r),
          (t * 3.4) % (pi * 2),
          pi * 0.55,
          false,
          _wingRingPaint,
        );
      }
    }
  }

  void _spawnFlowerPickup(
    Offset position,
    int sourceSlotIndex, {
    double healAmount = 0,
  }) {
    if (_flowerPickups.length >= 80) return;
    _flowerPickups.add(
      _FlowerPickup(
        position: position,
        sourceSlotIndex: sourceSlotIndex,
        bobPhase: _rng.nextDouble() * pi * 2,
        healAmount: healAmount,
      ),
    );
  }

  void _updateFlowerPickups(double dt) {
    if (_flowerPickups.isEmpty) return;
    // Player flies the SHIP — collect against ship position, not orb.
    // Generous radius + magnet pull so flowers swoop in instead of
    // requiring a precision pickup.
    if (ship.isDead) {
      // Tick life only — no pickup if the ship can't reach them.
      for (final flower in _flowerPickups) {
        flower.life -= dt;
      }
      _flowerPickups.removeWhere((f) => f.dead);
      return;
    }
    const collectRadius = 56.0;
    const magnetRadius = 180.0;
    const magnetMaxSpeed = 340.0;
    for (final flower in _flowerPickups) {
      flower.life -= dt;
      if (flower.dead) continue;
      final dx = ship.position.dx - flower.position.dx;
      final dy = ship.position.dy - flower.position.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq <= collectRadius * collectRadius) {
        flower.life = 0;
        if (flower.healAmount > 0) {
          // Kin+Plant garden drop: heal all alchemons + the ship on
          // pickup instead of bumping the source companion's stack.
          _healAllCompanionsAndShip(
            flower.healAmount,
            sourceSlot: flower.sourceSlotIndex,
          );
          _spawnHitSpark(ship.position, elementColor('Plant'));
        } else {
          final comp = activeCompanions[flower.sourceSlotIndex];
          if (comp != null && !comp.isDead) {
            // Reuse the persistent kill-stack counter — Wing+Plant
            // companions accumulate flower count, scaled into beam damage.
            comp.abilityKillStacks++;
            _spawnHitSpark(ship.position, elementColor('Plant'));
          }
        }
        continue;
      }
      // Magnet pull: flowers within magnetRadius accelerate toward
      // the ship. Speed ramps with proximity so distant flowers
      // drift gently and close flowers snap fast.
      if (distSq <= magnetRadius * magnetRadius) {
        final dist = sqrt(distSq);
        final norm = Offset(dx / dist, dy / dist);
        final t = 1.0 - (dist / magnetRadius);
        final speed = magnetMaxSpeed * t * t;
        flower.position = Offset(
          flower.position.dx + norm.dx * speed * dt,
          flower.position.dy + norm.dy * speed * dt,
        );
      }
    }
    _flowerPickups.removeWhere((f) => f.dead);
  }

  void _updateSpiritWisps(double dt) {
    if (_spiritWisps.isEmpty) return;
    if (ship.isDead) {
      for (final wisp in _spiritWisps) {
        wisp.life -= dt;
      }
      _spiritWisps.removeWhere((w) => w.dead);
      return;
    }
    // Same magnet/collect feel as Plant flowers — generous radius +
    // proximity pull so wisps swoop in instead of requiring a precise
    // pickup. Threshold reached → nuke all non-boss enemies.
    const collectRadius = 56.0;
    const magnetRadius = 200.0;
    const magnetMaxSpeed = 360.0;
    for (final wisp in _spiritWisps) {
      wisp.life -= dt;
      if (wisp.dead) continue;
      final dx = ship.position.dx - wisp.position.dx;
      final dy = ship.position.dy - wisp.position.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq <= collectRadius * collectRadius) {
        wisp.life = 0;
        final comp = activeCompanions[wisp.sourceSlotIndex];
        if (comp != null && !comp.isDead) {
          comp.maskSpiritWispBank++;
          _spawnHitSpark(ship.position, elementColor('Spirit'));
          if (comp.maskSpiritWispBank >= _maskSpiritNukeThreshold) {
            comp.maskSpiritWispBank = 0;
            _fireMaskSpiritNuke(comp, wisp.damage);
          }
        }
        continue;
      }
      if (distSq <= magnetRadius * magnetRadius) {
        final dist = sqrt(distSq);
        final norm = Offset(dx / dist, dy / dist);
        final t = 1.0 - (dist / magnetRadius);
        final speed = magnetMaxSpeed * t * t;
        wisp.position = Offset(
          wisp.position.dx + norm.dx * speed * dt,
          wisp.position.dy + norm.dy * speed * dt,
        );
      }
    }
    _spiritWisps.removeWhere((w) => w.dead);
  }

  void _fireMaskSpiritNuke(CosmicSurvivalCompanion comp, double basePower) {
    // Wipes every regular enemy. Bosses are tracked in `activeBoss` /
    // `extraBosses`, not in `enemies`, so they're naturally skipped.
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      _damageEnemy(enemy, enemy.hp + 1, sourceSlotIndex: comp.slotIndex);
    }
    // Screen-wash punctuation — flash timer drives a brief overlay
    // (drawn during the render pass) + an outward ring from the ship.
    _maskSpiritNukeFlash = 1.0;
    _maskSpiritNukeOrigin = ship.position;
    _spawnHitSpark(ship.position, elementColor('Spirit'));
    _spawnHitSpark(comp.position, elementColor('Spirit'));
    // Spray spirit motes outward from the ship for extra weight.
    final spirit = elementColor('Spirit');
    final bright = Color.lerp(spirit, const Color(0xFFFFFFFF), 0.55)!;
    final count = 32;
    for (var i = 0; i < count; i++) {
      if (_vfx.length >= 150) break;
      final a = i * (pi * 2 / count) + _rng.nextDouble() * 0.4;
      final spd = 220 + _rng.nextDouble() * 220;
      _vfx.add(
        _VfxParticle(
          x: ship.position.dx,
          y: ship.position.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd,
          size: 1.6 + _rng.nextDouble() * 1.6,
          life: 0.6 + _rng.nextDouble() * 0.4,
          color: i.isEven ? bright : spirit,
        ),
      );
    }
    if (basePower < 0) return; // suppress unused warning
  }

  double _wingPlantStackBonus(int sourceSlotIndex) {
    final comp = activeCompanions[sourceSlotIndex];
    if (comp == null) return 1.0;
    if (comp.member.family.toLowerCase() != 'wing' ||
        comp.member.element != 'Plant') {
      return 1.0;
    }
    // Per-stack % scales with beauty — base 4%/stack at stat 3.0,
    // up to ~6%/stack at stat 5+. Cap still tops at +300% raw to
    // prevent runaway scaling.
    final stacks = comp.abilityKillStacks.clamp(0, 50);
    final beauty = _effectiveBeauty(sourceSlotIndex);
    final perStack =
        0.04 * _hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.50);
    return (1.0 + stacks * perStack).clamp(1.0, 4.0);
  }

  double _beamDamageForEnemy(WingBeamEffect d, CosmicSurvivalEnemy enemy) {
    if (d.executeThreshold > 0 && enemy.hpFraction <= d.executeThreshold) {
      return max(d.damagePerTick, enemy.hp + 1);
    }
    if (d.tickEffect == AbilityEffectKind.chargeBlast) {
      return CosmicAbilityRuntime.directDamageForEffect(
        d.tickEffect,
        power: d.damagePerTick,
        targetHp: enemy.hp,
        targetHpFraction: enemy.hpFraction,
      );
    }
    return d.damagePerTick;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
    if (lenSq <= 0.0001) return (p - a).distance;
    final ap = p - a;
    final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
    final closest = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - closest).distance;
  }

  bool _updateManeLightningOrbTransfer(Projectile p, double dt) {
    if (p.abilityFamily != 'mane' ||
        p.element != 'Lightning' ||
        p.effectStacks != 1) {
      return false;
    }
    final target = p.cachedHomingTarget;
    if (target == null) return false;
    final toTarget = target - p.position;
    final dist = toTarget.distance;
    final step = Projectile.speed * max(0.25, p.speedMultiplier) * dt;
    if (dist <= step || dist < 8) {
      _spawnManeLightningShockField(p, target);
      p.life = 0;
      return true;
    }
    final dir = toTarget / dist;
    p.angle = atan2(dir.dy, dir.dx);
    p.position += dir * step;
    return true;
  }

  void _spawnManeLightningShockField(Projectile source, Offset target) {
    _appendCompanionProjectile(
      Projectile(
        position: target,
        angle: 0,
        element: 'Lightning',
        damage: 0,
        life: 4.0,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 0.95,
        visualScale: 1.05,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: source.sourceSlotIndex,
        abilityFamily: 'mane',
        tickEffect: AbilityEffectKind.zoneDamage,
        effectPower: source.effectPower,
        effectRadius: source.effectRadius.clamp(36.0, 48.0).toDouble(),
        effectDuration: source.effectDuration,
        effectStacks: 2,
      ),
    );
    _spawnHitSpark(target, elementColor('Lightning'));
  }

  void _spawnManeEarthQuakePulse(Projectile source) {
    final dir = Offset(cos(source.angle), sin(source.angle));
    final perp = Offset(-dir.dy, dir.dx);
    final offset = perp * ((_rng.nextDouble() - 0.5) * 56.0) - dir * 18.0;
    final pulsePos = source.position + offset;
    _appendCompanionProjectile(
      Projectile(
        position: pulsePos,
        angle: source.angle,
        element: 'Earth',
        damage: 0,
        life: 1.05,
        speedMultiplier: 0,
        stationary: true,
        piercing: true,
        radiusMultiplier: 0.92,
        visualScale: 0.92,
        visualStyle: ProjectileVisualStyle.sigil,
        sourceSlotIndex: source.sourceSlotIndex,
        abilityFamily: 'mane',
        tickEffect: AbilityEffectKind.zoneDamage,
        effectPower: max(source.turretDamage * 0.62, source.damage * 0.16),
        effectRadius: max(54.0, source.effectRadius * 0.42),
        effectDuration: 0.85,
        snareRadius: max(48.0, source.snareRadius * 0.40),
        snareMoveMultiplier: min(source.snareMoveMultiplier, 0.52),
      ),
    );
    _spawnHitSpark(pulsePos, elementColor('Earth'));
  }

  void _updateCompanionProjectiles(double dt) {
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];
      var transferringToOrbit = false;

      // Moving Mane projectiles — trailing particle clump so they
      // read as a flying cluster of energy instead of a drawn
      // missile shape. Element-colored wisps drift slightly back
      // along the projectile's path. Spawn rate scales with the
      // projectile's visual size.
      if (p.abilityFamily == 'mane' &&
          !p.stationary &&
          p.visualStyle == ProjectileVisualStyle.slash &&
          _vfx.length < 135) {
        final ec = elementColor(p.element ?? 'Fire');
        final whiteMix = Color.lerp(ec, const Color(0xFFFFFFFF), 0.55)!;
        // Travel direction so wisps trail behind.
        final dirVec = Offset(cos(p.angle), sin(p.angle));
        final perpVec = Offset(-dirVec.dy, dirVec.dx);
        // Spawn radius scales with the projectile's visual scale +
        // radius multiplier (bigger projectile = bigger clump).
        final clumpR = (4.0 + p.visualScale * 4.0 + p.radiusMultiplier * 6.0)
            .clamp(4.0, 28.0);
        // 2 wisps per frame for normal-size, 3 for big projectiles.
        final spawnN = p.visualScale > 1.6 ? 3 : 2;
        for (var i = 0; i < spawnN; i++) {
          // Random offset within the clump (slight perpendicular bias).
          final t = _rng.nextDouble() * 2 - 1; // -1..1
          final back = _rng.nextDouble() * 0.9; // 0..0.9
          final spawn =
              p.position + perpVec * t * clumpR - dirVec * back * clumpR * 1.2;
          // Velocity drifts mostly backward + small lateral wander.
          final vx =
              -dirVec.dx * (20 + _rng.nextDouble() * 30) + perpVec.dx * t * 22;
          final vy =
              -dirVec.dy * (20 + _rng.nextDouble() * 30) + perpVec.dy * t * 22;
          _vfx.add(
            _VfxParticle(
              x: spawn.dx,
              y: spawn.dy,
              vx: vx,
              vy: vy,
              size: 1.3 + _rng.nextDouble() * 1.4,
              life: 0.30 + _rng.nextDouble() * 0.30,
              color: i.isEven ? ec : whiteMix,
            ),
          );
        }
      }

      // Mane+Dark: the slow void bolt constantly pulls nearby enemies
      // toward its position as it travels. Per design: "constantly
      // pulls enemies towards it, eating low health enemies" — the
      // pull happens every frame; the execute happens on pierce
      // (handled in resolveAbilityPierce).
      if (p.abilityFamily == 'mane' &&
          p.element == 'Dark' &&
          !p.stationary &&
          p.snareRadius > 0) {
        final pullR = p.snareRadius;
        _visitEnemiesNear(p.position, pullR, (enemy) {
          if (enemy.isDead) return false;
          final dx = p.position.dx - enemy.position.dx;
          final dy = p.position.dy - enemy.position.dy;
          final distSq = dx * dx + dy * dy;
          if (distSq < 4.0 || distSq > pullR * pullR) return false;
          final dist = sqrt(distSq);
          final norm = Offset(dx / dist, dy / dist);
          // Pull strength stronger when close, weaker at rim.
          final t = 1.0 - (dist / pullR);
          final speed = 60.0 + 220.0 * t;
          enemy.position = Offset(
            enemy.position.dx + norm.dx * speed * dt,
            enemy.position.dy + norm.dy * speed * dt,
          );
          return false;
        });
      }

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
          for (final b in allLivingBosses) {
            final bdSq = _distanceSquared(b.position, p.position);
            if (bdSq < bestDistSq) {
              bestDistSq = bdSq;
              bestTarget = b.position;
            }
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

      if (_updateManeLightningOrbTransfer(p, dt)) {
        transferringToOrbit = true;
      }

      // Horn+Crystal: re-anchor the orbit center to the moving source
      // companion each frame so the shards orbit the live horn (not
      // the cast point) all the way through dash and after impact.
      if (p.followSourceCompanion && p.sourceSlotIndex != null) {
        final src = activeCompanions[p.sourceSlotIndex!];
        if (src != null && !src.isDead) {
          p.orbitCenter = src.position;
        }
      }

      // Mask+Dust shield: snap the aura to its attached alchemon
      // each frame so it wraps around the moving target.
      //   attachedToSlot == -1  → follow ship
      //   attachedToSlot >= 0   → follow active companion in that slot
      //   attachedToSlot == -2  → not an attached projectile
      if (p.attachedToSlot != -2) {
        if (p.attachedToSlot == -1) {
          if (!ship.isDead) p.position = ship.position;
        } else {
          final host = activeCompanions[p.attachedToSlot];
          if (host != null && !host.isDead) {
            p.position = host.position;
          } else {
            // Host died/despawned — let the shield die with them.
            p.life = 0;
          }
        }
      }

      // Generic per-frame zone particles — runs for any stationary
      // zone projectile regardless of family (Lava blobs from mane
      // pierce, Fire pools from pip kills, Mud pools, Poison pools,
      // etc.). Element-appropriate wisps so the painted blob feels
      // alive instead of static.
      if (p.stationary &&
          p.tickEffect != AbilityEffectKind.none &&
          p.effectRadius > 0 &&
          _vfx.length < 130) {
        _spawnZoneParticles(p);
      }

      // Horn+Spirit phantoms + Horn+Crystal orbital shards + Light
      // barrier: spawn trailing wisp particles each frame so they
      // leave a soft trail instead of looking like solid sigils.
      // Matches the "particly" wind-up aesthetic the user wanted
      // carried into the impact projectiles.
      if (p.abilityFamily == 'horn' && _vfx.length < 130) {
        if (p.element == 'Spirit' && p.decoy) {
          final ghost = Color.lerp(
            elementColor('Spirit'),
            const Color(0xFFFFFFFF),
            0.55,
          )!;
          // 3 wisps per frame — dense particle cloud so the phantom
          // reads as a moving swarm, not a solid orb.
          for (var i = 0; i < 3; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final r = 6.0 + _rng.nextDouble() * 16.0;
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * r,
                y: p.position.dy + sin(a) * r,
                vx: cos(a) * (8 + _rng.nextDouble() * 24),
                vy: sin(a) * (8 + _rng.nextDouble() * 24),
                size: 1.4 + _rng.nextDouble() * 1.4,
                life: 0.40 + _rng.nextDouble() * 0.35,
                color: i.isEven ? ghost : const Color(0xFFFFFFFF),
              ),
            );
          }
        } else if (p.element == 'Crystal' && p.orbitRadius > 0) {
          // 2 sparkles per orbital shard per frame for a denser
          // glittering trail.
          final white = Color.lerp(
            elementColor('Crystal'),
            const Color(0xFFFFFFFF),
            0.55,
          )!;
          for (var i = 0; i < 2; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final r = 4.0 + _rng.nextDouble() * 12.0;
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * r,
                y: p.position.dy + sin(a) * r,
                vx: cos(a) * (12 + _rng.nextDouble() * 30),
                vy: sin(a) * (12 + _rng.nextDouble() * 30),
                size: 1.1 + _rng.nextDouble() * 1.2,
                life: 0.30 + _rng.nextDouble() * 0.25,
                color: _rng.nextBool() ? white : const Color(0xFFFFFFFF),
              ),
            );
          }
        } else if (p.element == 'Lightning' &&
            p.stationary &&
            p.tickEffect == AbilityEffectKind.chain) {
          // Chain shockwave persistent flash storm — random sparks
          // flicker inside the blast radius for the projectile's
          // short life. No bolt lines, just particles dancing.
          final blastR = p.effectRadius > 0 ? p.effectRadius : 140.0;
          final base = elementColor('Lightning');
          final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.6)!;
          for (var i = 0; i < 4; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final r = blastR * (0.10 + _rng.nextDouble() * 0.90);
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * r,
                y: p.position.dy + sin(a) * r,
                vx: cos(a) * (10 + _rng.nextDouble() * 30),
                vy: sin(a) * (10 + _rng.nextDouble() * 30),
                size: 1.4 + _rng.nextDouble() * 1.4,
                life: 0.30 + _rng.nextDouble() * 0.35,
                color: i.isEven ? white : base,
              ),
            );
          }
        } else if (p.element == 'Fire' && p.stationary) {
          // Horn Fire trail: rising ember sparks drift upward and
          // fade — alchemical campfire feel along the dash path.
          // 1 per frame keeps the trail subtle even with many
          // segments laid down.
          final ember = const Color(0xFFFFB060);
          final hot = const Color(0xFFFFD080);
          final a = _rng.nextDouble() * 2 * pi;
          final r =
              (p.effectRadius > 0 ? p.effectRadius : 40.0) *
              0.45 *
              _rng.nextDouble();
          _vfx.add(
            _VfxParticle(
              x: p.position.dx + cos(a) * r,
              y: p.position.dy + sin(a) * r,
              vx: cos(a) * (6 + _rng.nextDouble() * 8),
              vy: -22 - _rng.nextDouble() * 24,
              size: 1.2 + _rng.nextDouble() * 1.0,
              life: 0.5 + _rng.nextDouble() * 0.35,
              color: _rng.nextBool() ? ember : hot,
            ),
          );
        } else if (p.element == 'Water' && p.stationary) {
          // Whirlpool: 1 particle per frame spiraling tangentially
          // with inward bias. Cut from 2/frame to keep the visual
          // calmer (user feedback: was too busy).
          final whirlR = max(40.0, p.radiusMultiplier * 18.0 + 20.0);
          final base = elementColor('Water').withValues(alpha: 0.65);
          final a = _rng.nextDouble() * 2 * pi;
          final r = whirlR * (0.55 + _rng.nextDouble() * 0.45);
          final tang = Offset(-sin(a), cos(a));
          final inward = Offset(-cos(a), -sin(a));
          final tangSpd = 40 + _rng.nextDouble() * 30;
          final inSpd = 18 + _rng.nextDouble() * 16;
          _vfx.add(
            _VfxParticle(
              x: p.position.dx + cos(a) * r,
              y: p.position.dy + sin(a) * r,
              vx: tang.dx * tangSpd + inward.dx * inSpd,
              vy: tang.dy * tangSpd + inward.dy * inSpd,
              size: 1.2 + _rng.nextDouble() * 1.0,
              life: 0.4 + _rng.nextDouble() * 0.4,
              color: base,
            ),
          );
        } else if (p.element == 'Dust' && p.stationary) {
          // Dust cyclone: 3 swirling motes per frame at varied
          // radii. Tangential motion + light outward bias so they
          // drift away from the center as they fade.
          final dustR = max(36.0, p.radiusMultiplier * 18.0 + 16.0);
          final base = elementColor('Dust').withValues(alpha: 0.55);
          for (var i = 0; i < 3; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final r = dustR * (0.20 + _rng.nextDouble() * 0.75);
            final tang = Offset(-sin(a), cos(a));
            final outward = Offset(cos(a), sin(a));
            final tangSpd = 25 + _rng.nextDouble() * 30;
            final outSpd = 8 + _rng.nextDouble() * 10;
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * r,
                y: p.position.dy + sin(a) * r,
                vx: tang.dx * tangSpd + outward.dx * outSpd,
                vy: tang.dy * tangSpd + outward.dy * outSpd,
                size: 1.1 + _rng.nextDouble() * 1.0,
                life: 0.5 + _rng.nextDouble() * 0.4,
                color: base,
              ),
            );
          }
        } else if (p.element == 'Ice' && p.stationary) {
          // Frost motes drift slowly outward and fall — crystalline
          // shimmer around the wall segments.
          final iceR = max(20.0, p.radiusMultiplier * 16.0 + 8.0);
          final base = elementColor('Ice');
          final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.55)!;
          final a = _rng.nextDouble() * 2 * pi;
          final r = iceR * (0.30 + _rng.nextDouble() * 0.70);
          _vfx.add(
            _VfxParticle(
              x: p.position.dx + cos(a) * r,
              y: p.position.dy + sin(a) * r,
              vx: cos(a) * (8 + _rng.nextDouble() * 12),
              vy: sin(a) * (8 + _rng.nextDouble() * 12) + 6,
              size: 1.0 + _rng.nextDouble() * 1.0,
              life: 0.5 + _rng.nextDouble() * 0.4,
              color: _rng.nextBool() ? white : const Color(0xFFFFFFFF),
            ),
          );
        } else if (p.element == 'Steam' && p.stationary) {
          // Rising steam puffs drift up and slightly outward from
          // the geyser core. 2 per frame.
          final steamR = max(38.0, p.radiusMultiplier * 18.0 + 18.0);
          final base = elementColor('Steam');
          final white = Color.lerp(base, const Color(0xFFFFFFFF), 0.55)!;
          for (var i = 0; i < 2; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final r = steamR * (0.15 + _rng.nextDouble() * 0.50);
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * r,
                y: p.position.dy + sin(a) * r,
                // Mostly upward, slight outward.
                vx: cos(a) * (10 + _rng.nextDouble() * 8),
                vy: -30 - _rng.nextDouble() * 30,
                size: 2.0 + _rng.nextDouble() * 1.8,
                life: 0.6 + _rng.nextDouble() * 0.4,
                color: i.isEven ? white : base,
              ),
            );
          }
        } else if (p.element == 'Dark' && p.stationary) {
          // Void suck: particles spawned at the perimeter rush
          // INWARD toward the core — telegraphs the pull. Mix dark
          // purple and pale violet for the alchemical contrast.
          final voidR = max(40.0, p.radiusMultiplier * 18.0 + 24.0);
          final voidColor = const Color(0xFFB89AFF);
          final deepColor = const Color(0xFF1A0A2A);
          for (var i = 0; i < 3; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final spawnR = voidR * (0.85 + _rng.nextDouble() * 0.25);
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * spawnR,
                y: p.position.dy + sin(a) * spawnR,
                vx: -cos(a) * (50 + _rng.nextDouble() * 60),
                vy: -sin(a) * (50 + _rng.nextDouble() * 60),
                size: 1.4 + _rng.nextDouble() * 1.4,
                life: 0.4 + _rng.nextDouble() * 0.3,
                color: i.isEven ? voidColor : deepColor,
              ),
            );
          }
        } else if (p.element == 'Light' &&
            p.stationary &&
            p.reflectsProjectiles) {
          // Light barrier active channel: dramatic continuous storm
          // around the dome — perimeter sparkle storm + inward
          // drift + occasional lightning-style arc across the dome.
          // Gives the full 5s channel a "building/sustaining" feel.
          final domeR = max(60.0, p.radiusMultiplier * 20.0 + 70.0);
          final white = Color.lerp(
            elementColor('Light'),
            const Color(0xFFFFFFFF),
            0.55,
          )!;
          // Perimeter sparkle storm — 5 wisps per frame around the
          // rim, drifting inward.
          for (var i = 0; i < 5; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final spawnR = domeR * (0.88 + _rng.nextDouble() * 0.20);
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * spawnR,
                y: p.position.dy + sin(a) * spawnR,
                vx: -cos(a) * (12 + _rng.nextDouble() * 22),
                vy: -sin(a) * (12 + _rng.nextDouble() * 22),
                size: 1.4 + _rng.nextDouble() * 1.4,
                life: 0.5 + _rng.nextDouble() * 0.4,
                color: i.isEven ? white : const Color(0xFFFFFFFF),
              ),
            );
          }
          // 2 inner-orb shimmer particles for a "core charging" feel.
          for (var i = 0; i < 2; i++) {
            final a = _rng.nextDouble() * 2 * pi;
            final innerR = domeR * (0.15 + _rng.nextDouble() * 0.30);
            _vfx.add(
              _VfxParticle(
                x: p.position.dx + cos(a) * innerR,
                y: p.position.dy + sin(a) * innerR,
                vx: cos(a) * (20 + _rng.nextDouble() * 18),
                vy: sin(a) * (20 + _rng.nextDouble() * 18),
                size: 1.6 + _rng.nextDouble() * 1.2,
                life: 0.3 + _rng.nextDouble() * 0.2,
                color: const Color(0xFFFFFFFF),
              ),
            );
          }
          // Occasional lightning-style arc across the dome interior.
          if (_rng.nextDouble() < 0.45 && _beamFx.length < 22) {
            final a1 = _rng.nextDouble() * 2 * pi;
            final a2 = a1 + pi + (_rng.nextDouble() - 0.5) * 0.6;
            final r1 = domeR * (0.70 + _rng.nextDouble() * 0.25);
            final r2 = domeR * (0.70 + _rng.nextDouble() * 0.25);
            _spawnBeam(
              Offset(
                p.position.dx + cos(a1) * r1,
                p.position.dy + sin(a1) * r1,
              ),
              Offset(
                p.position.dx + cos(a2) * r2,
                p.position.dy + sin(a2) * r2,
              ),
              white.withValues(alpha: 0.65),
              width: 1.5,
              life: 0.08,
            );
          }
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
        // Mane+Dust trail: leave a slow-cloud puff under the projectile
        // every ~0.35s so its passage paints a trailing dust line.
        if (p.abilityFamily == 'mane' && p.element == 'Dust') {
          p.trailTimer += dt;
          if (p.trailTimer >= 0.35) {
            p.trailTimer = 0;
            _appendCompanionProjectile(
              Projectile(
                position: p.position,
                angle: 0,
                element: 'Dust',
                damage: 0,
                life: 2.4,
                speedMultiplier: 0,
                stationary: true,
                piercing: true,
                radiusMultiplier: 1.3,
                visualScale: 1.3,
                visualStyle: ProjectileVisualStyle.sigil,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'mane',
                tickEffect: AbilityEffectKind.suppressShooting,
                effectPower: p.damage * 0.10,
                effectRadius: 60,
                effectDuration: 1.6,
              ),
            );
          }
        }
        // Mystic+Lava cataclysm moons: the slow-moving boulder drops
        // persistent magma pools along its path. Pools tick burn DoT
        // and snare-slow enemies that wander in.
        if (p.turretInterval > 0 &&
            p.visualStyle == ProjectileVisualStyle.mysticOrbital &&
            p.element == 'Lava') {
          p.turretTimer += dt;
          while (p.turretTimer >= p.turretInterval) {
            p.turretTimer -= p.turretInterval;
            _appendCompanionProjectile(
              Projectile(
                position: p.position,
                angle: 0,
                element: 'Lava',
                damage: 0,
                life: 8.5,
                speedMultiplier: 0,
                stationary: true,
                piercing: true,
                radiusMultiplier: 1.8,
                visualScale: 1.7,
                visualStyle: ProjectileVisualStyle.mysticOrbital,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'mystic',
                tickEffect: AbilityEffectKind.burn,
                effectPower: p.turretDamage,
                effectRadius: 70,
                effectDuration: 1.6,
                snareRadius: 70,
                snareMoveMultiplier: 0.65,
              ),
            );
          }
        }
        // Mane traveling-projectile shedding: Earth fault slab leaves
        // quake bursts as it breaks; Steam geyser releases puffs.
        if (p.turretInterval > 0 && p.abilityFamily == 'mane') {
          if (p.element == 'Earth') {
            p.turretTimer += dt;
            while (p.turretTimer >= p.turretInterval) {
              p.turretTimer -= p.turretInterval;
              _spawnManeEarthQuakePulse(p);
            }
            p.radiusMultiplier = max(p.radiusMultiplier - dt * 0.36, 2.15);
            p.visualScale = max(p.visualScale - dt * 0.30, 1.85);
          } else if (p.element == 'Steam') {
            // Drop a stationary steam puff under the projectile.
            p.turretTimer += dt;
            while (p.turretTimer >= p.turretInterval) {
              p.turretTimer -= p.turretInterval;
              _appendCompanionProjectile(
                Projectile(
                  position: p.position,
                  angle: 0,
                  element: 'Steam',
                  damage: 0,
                  life: 1.6,
                  speedMultiplier: 0,
                  stationary: true,
                  piercing: true,
                  radiusMultiplier: 1.5,
                  visualScale: 1.4,
                  visualStyle: ProjectileVisualStyle.sigil,
                  sourceSlotIndex: p.sourceSlotIndex,
                  abilityFamily: 'mane',
                  tickEffect: AbilityEffectKind.geyser,
                  effectPower: p.turretDamage,
                  effectRadius: 70,
                  effectDuration: 1.2,
                ),
              );
            }
          }
        }
      } else {
        _maybeFireProjectileTurret(p, dt);
      }

      // Mask+Plant vine is the persistent garden — it never expires,
      // so the player can watch it grow tendrils across the run. All
      // other projectiles tick down normally.
      final isImmortalPlantVine =
          p.abilityFamily == 'mask' && p.element == 'Plant' && p.stationary;
      if (!isImmortalPlantVine) {
        p.life -= dt;
        if (p.life <= 0) continue;
      }
      // Mask trap activation/feed flash decay. Repurposes
      // abilityGrowthTimer as a "just fired" pulse the renderer reads.
      // Decays smoothly at ~1.6/s so it visibly subsides.
      if (p.abilityFamily == 'mask' &&
          p.stationary &&
          p.abilityGrowthTimer > 0) {
        p.abilityGrowthTimer = max(0, p.abilityGrowthTimer - dt * 1.6);
      }

      // Kin+Plant healing garden — drops a collectible flower every
      // ~5s during its lifetime (nerfed from 2s). Each flower heals
      // the team on pickup; heal scales with garden's tick power.
      if (p.abilityFamily == 'kin' &&
          p.element == 'Plant' &&
          p.stationary &&
          p.tickEffect == AbilityEffectKind.zoneHeal &&
          p.effectCount == 1) {
        p.abilityGrowthTimer += dt;
        if (p.abilityGrowthTimer >= 5.0) {
          p.abilityGrowthTimer = 0;
          final a = _rng.nextDouble() * 2 * pi;
          final r =
              (p.effectRadius * 0.4) +
              _rng.nextDouble() * (p.effectRadius * 0.4);
          final pos = Offset(
            p.position.dx + cos(a) * r,
            p.position.dy + sin(a) * r,
          );
          _spawnFlowerPickup(
            pos,
            p.sourceSlotIndex ?? 0,
            healAmount: max(5.0, p.effectPower * 1.2),
          );
        }
      }

      // Let+Plant vine growth: as the trap stays alive, its snare/effect
      // radius expands. Mask+Plant is now driven by CAST count (each
      // cast feeds the vine via _applyMaskPlantVineFeed), so we skip
      // the time-based growth tick for masks to keep the two systems
      // from compounding.
      final isPlantTrap = p.element == 'Plant' && p.abilityFamily == 'let';
      if (isPlantTrap &&
          (p.snareRadius > 0 || p.tickEffect != AbilityEffectKind.none)) {
        p.abilityGrowthTimer += dt;
        if (p.abilityGrowthTimer >= 1.2) {
          p.abilityGrowthTimer -= 1.2;
          const snareCap = 220.0;
          const effectCap = 160.0;
          if (p.snareRadius > 0) {
            p.snareRadius = min(p.snareRadius + 6, snareCap);
            p.snareMoveMultiplier = max(p.snareMoveMultiplier - 0.05, 0.30);
          }
          if (p.effectRadius > 0) {
            p.effectRadius = min(p.effectRadius + 4, effectCap);
          }
        }
      }

      // Cluster split at half-life
      if (p.clusterCount > 0 &&
          !p.clustered &&
          p.life < Projectile.maxLife * 0.5) {
        p.clustered = true;
        for (var c = 0; c < p.clusterCount; c++) {
          final clusterAngle = p.angle + (c - p.clusterCount / 2) * 0.3;
          if (!_appendCompanionProjectile(
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
              abilityFamily: p.abilityFamily,
              hitEffect: p.hitEffect,
              killEffect: p.killEffect,
              pierceEffect: p.pierceEffect,
              tickEffect: p.tickEffect,
              effectPower: p.effectPower * 0.65,
              effectRadius: p.effectRadius,
              effectDuration: p.effectDuration,
              effectCount: p.effectCount,
            ),
          )) {
            break;
          }
        }
      }

      // Trail
      if (p.trailInterval > 0 && !p.stationary && p.orbitCenter == null) {
        p.trailTimer += dt;
        if (p.trailTimer >= p.trailInterval) {
          p.trailTimer -= p.trailInterval;
          _appendCompanionProjectile(
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
              abilityFamily: p.abilityFamily,
              hitEffect: p.tickEffect == AbilityEffectKind.none
                  ? p.hitEffect
                  : p.tickEffect,
              tickEffect: p.tickEffect,
              effectPower: p.effectPower * 0.55,
              effectRadius: p.effectRadius,
              effectDuration: p.effectDuration,
            ),
          );
        }
      }

      // Hit detection vs enemies
      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;
      _visitEnemiesNear(p.position, hitRadius + 110, (enemy) {
        if (!_withinRange(
          p.position,
          enemy.position,
          enemy.radius + hitRadius,
        )) {
          return false;
        }
        final preRootForPlantKill =
            p.piercing && p.abilityFamily == 'mane' && p.element == 'Plant';
        if (preRootForPlantKill) resolveAbilityPierce(p, enemy);
        final wasDead = enemy.isDead;
        // Only the moving pip-special dart counts as "from the ability".
        // Stationary sigil-style placements (fire pools, etc.) also use
        // abilityFamily=='pip' but should not chain-spawn more placements.
        final isPipSpecialDart =
            p.abilityFamily == 'pip' &&
            p.visualStyle == ProjectileVisualStyle.dart;
        _damageEnemy(
          enemy,
          p.damage,
          sourceSlotIndex: p.sourceSlotIndex,
          fromPipSpecial: isPipSpecialDart,
        );
        final killed = !wasDead && enemy.isDead;
        resolveAbilityHit(p, enemy, killed: killed);
        if (p.piercing) resolveAbilityPierce(p, enemy);
        // Pip+Water: every kill splashes (handled by the splash kill
        // effect); a kill on the projectile's final hit — no bounces
        // left — erupts an extra huge splash. Radius + damage scale
        // with the caster's beauty.
        if (killed &&
            p.element == 'Water' &&
            p.bounceCount <= 0 &&
            p.sourceSlotIndex != null) {
          final src = activeCompanions[p.sourceSlotIndex!];
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            final waterBeauty = _effectiveBeauty(p.sourceSlotIndex!);
            final splashScale = _hornStatScale(
              waterBeauty,
              perPoint: 0.10,
              min: 0.85,
              max: 1.35,
            );
            _damageEnemiesNear(
              enemy.position,
              160 * splashScale,
              p.damage * 2.4 * splashScale,
              sourceSlotIndex: p.sourceSlotIndex,
            );
            _spawnHitSpark(enemy.position, elementColor('Water'));
          }
        }
        // Pip+Mud: tag the enemy so it permanently drops mud puffs
        // behind itself for the rest of its life.
        if (!killed &&
            p.abilityFamily.isEmpty &&
            p.element == 'Mud' &&
            p.sourceSlotIndex != null) {
          final src = activeCompanions[p.sourceSlotIndex!];
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            enemy.pipMudTrail = true;
          }
        }
        // Pip+Poison: each SPECIAL-dart hit draws a poison-line zone
        // from the previous hit's position to the current one, forming
        // a web across the salvo's impact points. Lines persist until
        // the companion's next special cast (cleared in the cast hook).
        if (isPipSpecialDart &&
            p.element == 'Poison' &&
            p.sourceSlotIndex != null) {
          final src = activeCompanions[p.sourceSlotIndex!];
          if (src != null && src.member.family.toLowerCase() == 'pip') {
            final prev = src.lastPipPoisonHitPos;
            if (prev != null) {
              final dx = enemy.position.dx - prev.dx;
              final dy = enemy.position.dy - prev.dy;
              final dist = sqrt(dx * dx + dy * dy);
              if (dist < 600) {
                final segCount = (dist / 36).ceil().clamp(1, 18);
                for (var s = 0; s < segCount; s++) {
                  final t = (s + 0.5) / segCount;
                  final pos = Offset(prev.dx + dx * t, prev.dy + dy * t);
                  _appendCompanionProjectile(
                    Projectile(
                      position: pos,
                      angle: 0,
                      element: 'Poison',
                      damage: 0,
                      life: 6.5,
                      speedMultiplier: 0,
                      stationary: true,
                      piercing: true,
                      radiusMultiplier: 0.95,
                      visualScale: 0.85,
                      visualStyle: ProjectileVisualStyle.sigil,
                      sourceSlotIndex: p.sourceSlotIndex,
                      abilityFamily: 'pip',
                      tickEffect: AbilityEffectKind.poison,
                      effectPower: p.damage * 0.22,
                      effectRadius: 32,
                      effectDuration: 1.5,
                    ),
                  );
                }
              }
            }
            src.lastPipPoisonHitPos = enemy.position;
          }
        }
        // Mane+Mud: first enemy hit splits the projectile into ten
        // smaller fragments fanning out from the impact point.
        if (p.abilityFamily == 'mane' &&
            p.element == 'Mud' &&
            !p.clustered &&
            p.effectStacks == 0) {
          p.clustered = true;
          for (var fi = 0; fi < 10; fi++) {
            final fragAngle = fi * (pi * 2 / 10);
            _appendCompanionProjectile(
              Projectile(
                position: enemy.position,
                angle: fragAngle,
                element: 'Mud',
                damage: p.damage * 0.45,
                life: 1.0,
                speedMultiplier: 1.4,
                radiusMultiplier: max(p.radiusMultiplier * 0.55, 0.7),
                visualScale: max(p.visualScale * 0.55, 0.7),
                piercing: false,
                visualStyle: ProjectileVisualStyle.slash,
                sourceSlotIndex: p.sourceSlotIndex,
                abilityFamily: 'mane',
                hitEffect: AbilityEffectKind.slow,
                effectPower: p.effectPower * 0.6,
                effectRadius: 40,
                effectDuration: 1.5,
                effectStacks: 1,
              ),
            );
          }
          consumed = true;
        }
        _spawnProjectileHitSpark(p);
        _triggerChainLightning(
          sourceEnemy: enemy,
          origin: p.position,
          baseDamage: p.damage,
          sourceSlotIndex: p.sourceSlotIndex,
          remainingChains: p.chainLightningCharges,
          // Kin+Lightning tesla bypasses the powerup gate.
          requirePowerUp: !_isAnyKinLightningChargeActive(),
        );

        // Ricochet (Pip): prefer tightly-clustered nearby targets so the
        // bounce reads as a snappy chain instead of darting toward distant
        // enemies that are off-screen or behind cover. Each bounce sheds
        // ~30% damage so a single dart can't full-damage 5 enemies. Speed
        // also drops slightly so chains read more clearly.
        final isPipSpecialProjectile = p.abilityFamily == 'pip';
        if (p.bounceCount > 0) {
          p.bounceCount--;
          if (isPipSpecialProjectile) p.pierceCount++;
          final next = _nearestEnemyTo(enemy.position, 110, exclude: enemy);
          if (next != null) {
            p.angle = atan2(
              next.position.dy - p.position.dy,
              next.position.dx - p.position.dx,
            );
            p.life = isPipSpecialProjectile
                ? min(max(p.life, 0.18), kPipRicochetPostHitLife)
                : max(p.life, 0.45);
            // Damage falloff per bounce — exception: Pip+Lightning is the
            // doc's designated "double the ricochet" identity, so it
            // sheds less per bounce (still scaled, just gentler).
            final falloff = (p.element == 'Lightning') ? 0.85 : 0.70;
            p.damage = p.damage * falloff;
            // Slight speed bleed so chained shots feel weighty.
            p.speedMultiplier = max(0.6, p.speedMultiplier * 0.92);
          } else {
            p.bounceCount = 0;
            if (isPipSpecialProjectile) consumed = true;
          }
        } else if (!p.piercing) {
          consumed = true;
        } else {
          p.pierceCount++;
          if (isPipSpecialProjectile && p.pierceCount >= kPipMaxPierceHits) {
            consumed = true;
          }
        }
        return true;
      });

      // Hit detection vs every alive boss (primary + extras).
      if (!consumed && !p.hitBoss) {
        for (final boss in allLivingBosses) {
          final d = (boss.position - p.position).distance;
          if (d >= boss.radius + hitRadius) continue;
          // Mane+Crystal: instakill boss on collision via massive
          // crystal burst (per design: "explode and do huge AOE and dmg"
          // against bosses).
          var bossDamage = p.damage;
          if (p.abilityFamily == 'mane' && p.element == 'Crystal') {
            boss.shieldUp = false;
            boss.shieldHealth = 0;
            bossDamage =
                (boss.hp + 1) /
                max(
                  0.01,
                  _companionOutgoingDamageMultiplier(
                    p.sourceSlotIndex,
                    vsBoss: true,
                  ),
                );
            _damageEnemiesNear(
              boss.position,
              240,
              p.damage * 3.0,
              sourceSlotIndex: p.sourceSlotIndex,
            );
            _spawnHitSpark(boss.position, elementColor('Crystal'));
            consumed = true;
          }
          damageBoss(
            bossDamage,
            attackElement: p.abilityFamily == 'mane' && p.element == 'Crystal'
                ? null
                : p.element,
            sourceSlotIndex: p.sourceSlotIndex,
            target: boss,
          );
          p.hitBoss = true;
          _spawnProjectileHitSpark(p);
          if (!p.piercing || p.abilityFamily == 'pip') {
            consumed = true;
          }
          break;
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
      _appendCompanionProjectile(
        _createCompanionTurretShot(projectile, targetPos),
      );
    }
  }

  bool _appendCompanionProjectile(Projectile projectile) {
    if (companionProjectiles.length >= _maxCompanionProjectiles) {
      return false;
    }
    companionProjectiles.add(projectile);
    return true;
  }

  void _appendCompanionProjectiles(Iterable<Projectile> projectiles) {
    final available = _maxCompanionProjectiles - companionProjectiles.length;
    if (available <= 0) return;
    final list = projectiles is List<Projectile>
        ? projectiles
        : projectiles.toList(growable: false);
    final takeCount = min(available, list.length);
    if (takeCount <= 0) return;
    companionProjectiles.addAll(list.take(takeCount));
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

  void _buildProjectileControlBuckets(_ProjectileControlBuckets buckets) {
    buckets.clear();
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
      if (projectile.reflectsProjectiles && projectile.stationary) {
        buckets.reflectors.add(projectile);
      }
    }
  }

  // Horn+Ice walls / Horn+Light barriers: redirect an incoming
  // enemy/boss projectile back at the nearest enemy (friendly-fire
  // flag flipped). Returns true when a reflect happened so the
  // caller skips the normal absorb path.
  bool _attemptProjectileReflect(
    SurvivalEnemyProjectile proj,
    List<Projectile> reflectors,
  ) {
    for (final fixture in reflectors) {
      // Big stationary domes (Light barrier) use the same radius
      // formula as their visible perimeter so reflects fire along
      // the visible edge instead of a tight inner zone. Small
      // fixtures (Ice walls) keep the compact hitbox.
      final fixtureR = fixture.element == 'Light'
          ? max(60.0, fixture.radiusMultiplier * 20.0 + 70.0)
          : fixture.radiusMultiplier * 12.0 + 18.0;
      final hitRadius = proj.radius + fixtureR;
      if (!_withinRange(fixture.position, proj.position, hitRadius)) {
        continue;
      }
      // Pick a fresh target: nearest enemy to the projectile, fallback
      // to a straight reverse of the angle.
      final near = _nearestEnemyTo(proj.position, 480);
      if (near != null) {
        final dx = near.position.dx - proj.position.dx;
        final dy = near.position.dy - proj.position.dy;
        if (dx * dx + dy * dy > 0.01) {
          proj.angle = atan2(dy, dx);
        } else {
          proj.angle = proj.angle + pi;
        }
      } else {
        proj.angle = proj.angle + pi;
      }
      proj.friendlyFire = true;
      _spawnHitSpark(fixture.position, const Color(0xFFE5F4FF));
      return true;
    }
    return false;
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

      // Kin+Crystal Prismatic Refractor: on intercept, also fire a
      // refracted beam at the nearest enemy as counter-damage.
      // Reuses the kin laser-beam pool so the refract is visually
      // unmistakable (clear thin line from shard → enemy).
      if (projectile.abilityFamily == 'kin' &&
          projectile.element == 'Crystal') {
        final target = _nearestEnemyTo(projectile.position, 360);
        if (target != null) {
          final dmg = max(12.0, projectile.damage * 2.0);
          _damageEnemy(
            target,
            dmg,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(target.position, elementColor('Crystal'));
          // Spawn a transient laser beam visual from shard to target.
          if (_kinLaserBeams.length >= 24) {
            _kinLaserBeams.removeAt(0);
          }
          _kinLaserBeams.add(
            _KinLaserBeam(
              origin: projectile.position,
              end: target.position,
              color: const Color(0xFFFFF3C8),
            ),
          );
        }
      }

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

      _visitEnemiesNear(proj.position, 140, (enemy) {
        if (!_withinRange(proj.position, enemy.position, enemy.radius + 5)) {
          return false;
        }
        _damageEnemy(enemy, proj.damage);
        // Rocket splash AoE
        if (proj.splashRadius > 0) {
          _visitEnemiesNear(proj.position, proj.splashRadius, (other) {
            if (identical(other, enemy)) return false;
            if (_withinRange(
              proj.position,
              other.position,
              proj.splashRadius,
            )) {
              _damageEnemy(other, proj.damage * 0.55);
            }
            return false;
          });
          for (final b in allLivingBosses) {
            if (_withinRange(proj.position, b.position, proj.splashRadius)) {
              damageBoss(proj.damage * 0.55, target: b);
            }
          }
        }
        proj.life = 0;
        return true;
      });

      if (proj.life > 0) {
        for (final boss in allLivingBosses) {
          if (_withinRange(proj.position, boss.position, boss.radius + 5)) {
            damageBoss(proj.damage, target: boss);
            // Rocket splash AoE on boss
            if (proj.splashRadius > 0) {
              _visitEnemiesNear(proj.position, proj.splashRadius, (other) {
                if (_withinRange(
                  proj.position,
                  other.position,
                  proj.splashRadius,
                )) {
                  _damageEnemy(other, proj.damage * 0.55);
                }
                return false;
              });
            }
            proj.life = 0;
            break;
          }
        }
      }
    }

    shipProjectiles.removeWhere((p) => p.life <= 0);
  }

  void _cleanupBetweenWaves() {
    enemies.removeWhere((enemy) => enemy.isDead);
    enemyProjectiles.clear();
    bossProjectiles.clear();
    extraBosses.removeWhere((boss) => boss.isDead);
  }

  double _distanceSquared(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  static const double _enemySpatialCellSize = 180.0;

  int _enemyCellCoord(double v) => (v / _enemySpatialCellSize).floor();

  int _enemyCellKey(int x, int y) => (x << 16) ^ (y & 0xFFFF);

  void _rebuildEnemySpatialGrid() {
    _enemySpatialGrid.clear();
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final cx = _enemyCellCoord(enemy.position.dx);
      final cy = _enemyCellCoord(enemy.position.dy);
      final key = _enemyCellKey(cx, cy);
      (_enemySpatialGrid[key] ??= <CosmicSurvivalEnemy>[]).add(enemy);
    }
  }

  void _visitEnemiesNear(
    Offset center,
    double radius,
    bool Function(CosmicSurvivalEnemy enemy) visitor, {
    CosmicSurvivalEnemy? exclude,
  }) {
    if (_enemySpatialGrid.isEmpty || radius <= 0) return;
    var visited = 0;
    final minX = _enemyCellCoord(center.dx - radius);
    final maxX = _enemyCellCoord(center.dx + radius);
    final minY = _enemyCellCoord(center.dy - radius);
    final maxY = _enemyCellCoord(center.dy + radius);
    for (var x = minX; x <= maxX; x++) {
      for (var y = minY; y <= maxY; y++) {
        final bucket = _enemySpatialGrid[_enemyCellKey(x, y)];
        if (bucket == null) continue;
        for (final enemy in bucket) {
          visited++;
          if (enemy.isDead) continue;
          if (exclude != null && identical(enemy, exclude)) continue;
          if (visitor(enemy)) {
            _recordSpatialQuery(visited);
            return;
          }
        }
      }
    }
    _recordSpatialQuery(visited);
  }

  void _recordSpatialQuery(int visited) {
    assert(() {
      _spatialQueries++;
      _spatialCandidates += visited;
      return true;
    }());
  }

  void _updateSpatialMetrics(double dt) {
    assert(() {
      _spatialMetricsTimer += dt;
      if (_spatialMetricsTimer < 2.0) return true;
      final avgCandidates = _spatialQueries > 0
          ? (_spatialCandidates / _spatialQueries)
          : 0.0;
      debugPrint(
        '[survival][spatial] enemies=${enemies.length} queries=$_spatialQueries avgCandidates=${avgCandidates.toStringAsFixed(1)}',
      );
      _spatialMetricsTimer = 0;
      _spatialQueries = 0;
      _spatialCandidates = 0;
      return true;
    }());
  }

  int _countEnemiesNear(
    Offset center,
    double radius, {
    CosmicSurvivalEnemy? exclude,
  }) {
    var count = 0;
    _visitEnemiesNear(center, radius, (enemy) {
      if (_withinRange(center, enemy.position, radius)) {
        count++;
      }
      return false;
    }, exclude: exclude);
    return count;
  }

  bool _withinRange(Offset a, Offset b, double radius) {
    return _distanceSquared(a, b) < radius * radius;
  }

  void _applyEnemyKnockback(
    CosmicSurvivalEnemy enemy,
    Offset direction,
    double force,
  ) {
    final d2 = direction.distanceSquared;
    if (d2 <= 0.0001 || force <= 0) return;
    final d = sqrt(d2);
    final norm = Offset(direction.dx / d, direction.dy / d);
    final massScale = switch (enemy.tier) {
      EnemyTier.wisp => 1.0,
      EnemyTier.drone => 0.92,
      EnemyTier.sentinel => 0.84,
      EnemyTier.phantom => 0.78,
      EnemyTier.brute => 0.70,
      EnemyTier.colossus => 0.60,
    };
    final eliteScale = enemy.isElite ? 0.84 : 1.0;
    final impulse = force * massScale * eliteScale;
    enemy.knockbackVelocity = Offset(
      enemy.knockbackVelocity.dx + norm.dx * impulse,
      enemy.knockbackVelocity.dy + norm.dy * impulse,
    );
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
        _visitEnemiesNear(orb.position, 200, (enemy) {
          final d = (enemy.position - orb.position).distance;
          if (d < 200) {
            final dir = enemy.position - orb.position;
            final falloff = (1.0 - (d / 200)).clamp(0.15, 1.0);
            _applyEnemyKnockback(enemy, dir, 340.0 * falloff);
          }
          return false;
        });
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
        _visitEnemiesNear(orb.position, 250, (enemy) {
          final d = (enemy.position - orb.position).distance;
          if (d < 250) {
            _damageEnemy(enemy, 20.0 * powerUps.novaDetonationLevel);
          }
          return false;
        });
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
      final falloff = (1.0 - (d / blastRadius)).clamp(0.2, 1.0);
      _applyEnemyKnockback(enemy, dir, (520 + level * 95) * falloff);
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
    score += _countEnemiesNear(enemy.position, 90, exclude: enemy) * 18;
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

  // Mask+Plant: render the persistent wormy tendrils. The vine grows
  // ONE permanent tendril per ~10 feeds (capped at 10 at the 100-feed
  // max). Each tendril is always visible — when enemies are in reach
  // it latches onto its assigned target (chooses by stable index so
  // tendrils don't flicker between targets), otherwise it coils/sways
  // idly around the root. Trunk thickness + amplitude + length all
  // scale with the overall feed count so the whole plant looks more
  // dangerous as it grows.
  void _renderMaskPlantWormyTendrils(
    Canvas canvas,
    Projectile vine,
    Color color,
  ) {
    final reach = max(vine.snareRadius, vine.effectRadius);
    final reachSq = reach * reach;

    // Gather enemies in reach, sorted nearest-first, for active bites. The
    // draw itself lives in the shared module so cosmic + dungeons grow the
    // exact same plant.
    final targets = <Offset>[];
    if (reach > 10) {
      _visitEnemiesNear(vine.position, reach, (enemy) {
        if (enemy.isDead) return false;
        final dx = enemy.position.dx - vine.position.dx;
        final dy = enemy.position.dy - vine.position.dy;
        if (dx * dx + dy * dy > reachSq) return false;
        targets.add(enemy.position);
        return false;
      });
      if (targets.length > 1) {
        targets.sort((a, b) {
          final da = (a - vine.position).distanceSquared;
          final db = (b - vine.position).distanceSquared;
          return da.compareTo(db);
        });
      }
    }

    drawMaskPlantWormyTendrils(
      canvas: canvas,
      vine: vine,
      color: color,
      time: stats.timeElapsed,
      targetsInReach: targets,
    );
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
    var resolvedTargetSlot = targetSlot;
    var resolvedTargetName = targetName;
    if (def.id == 'revive_half' && defeatedCompanionSlots.isNotEmpty) {
      final needsDeadTarget =
          resolvedTargetSlot == null ||
          !defeatedCompanionSlots.contains(resolvedTargetSlot);
      if (needsDeadTarget) {
        final defeated = defeatedCompanionSlots.toList()..sort();
        resolvedTargetSlot = defeated.first;
        if (resolvedTargetSlot >= 0 && resolvedTargetSlot < party.length) {
          resolvedTargetName = party[resolvedTargetSlot].displayName;
        }
      }
    }
    final applied = powerUps.apply(
      def,
      targetSlot: resolvedTargetSlot,
      targetName: resolvedTargetName,
    );
    if (!applied) return;
    if (def.id == 'orb_vitality') {
      final hpGain = orb.maxHp * 0.10;
      orb.maxHp += hpGain;
      orb.currentHp = min(orb.maxHp, orb.currentHp + hpGain + 4);
    }
    if (def.id == 'keystone_bastion_heart') {
      // Bastion Heart's companion durability now flows through the effective
      // stat system (Strength/Intelligence bonuses); only the orb is buffed
      // directly here.
      final orbGain = orb.maxHp * 0.20;
      orb.maxHp += orbGain;
      orb.currentHp = min(orb.maxHp, orb.currentHp + orbGain);
    }
    if (def.id == 'revive_half' && resolvedTargetSlot != null) {
      defeatedCompanionSlots.remove(resolvedTargetSlot);
      companionHpFraction[resolvedTargetSlot] = 0.5;
    }
    // Re-derive active companion stats so the pick lands immediately.
    _recomputeActiveCompanionStats();
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
    _visitEnemiesNear(pos, maxRange, (enemy) {
      final dSq = _distanceSquared(enemy.position, pos);
      if (dSq >= bestDistSq) return false;
      bestDistSq = dSq;
      best = enemy;
      return false;
    }, exclude: exclude);
    return best;
  }

  CosmicSurvivalEnemy? _pickOrbTurretTarget(double maxRange) {
    CosmicSurvivalEnemy? best;
    var bestScore = double.negativeInfinity;
    final maxRangeSq = maxRange * maxRange;
    _visitEnemiesNear(orb.position, maxRange, (enemy) {
      final distSq = _distanceSquared(enemy.position, orb.position);
      if (distSq > maxRangeSq) return false;
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
      return false;
    });
    return best;
  }

  double _orbTurretDamage(int level) {
    final waveFactor = 6.0 + max(0, spawner.currentWave - 1) * 0.45;
    final levelFactor = 0.85 + level * 0.55;
    return waveFactor * levelFactor;
  }

  void _maybeTriggerPowerUpSelection() {
    if (showingPowerUpSelection || alchemicalMeter < alchemicalMeterMax) return;
    // Wait for the visual meter to catch up to the underlying value so the
    // surge popup never appears before the bar finishes filling.
    if (_alchemicalMeterDisplayFrac < 0.995) return;
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
      final before = comp.currentHp;
      comp.currentHp = min(comp.maxHp, comp.currentHp + result.selfHeal);
      _recordHeal(
        (comp.currentHp - before).toDouble(),
        target: 0,
        sourceSlot: comp.slotIndex,
      );
      final selfHealToOrbMultiplier =
          comp.member.family.toLowerCase() == 'mane' &&
              comp.member.element == 'Blood'
          ? 0.24
          : 0.35;
      _healOrb(
        result.selfHeal * selfHealToOrbMultiplier,
        sourceSlot: comp.slotIndex,
      );
    }
    if (result.shipHeal > 0) {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, ship.currentHp + result.shipHeal);
      _recordHeal(
        ship.currentHp - before,
        target: 1,
        sourceSlot: comp.slotIndex,
      );
      _healOrb(result.shipHeal.toDouble(), sourceSlot: comp.slotIndex);
    }
    if (result.blessingTimer > 0) {
      comp.blessingTimer = max(comp.blessingTimer, result.blessingTimer);
      comp.blessingHealPerTick = max(
        comp.blessingHealPerTick,
        result.blessingHealPerTick,
      );
    }
  }

  void _healOrb(double amount, {int? sourceSlot}) {
    if (amount <= 0) return;
    final before = orb.currentHp;
    orb.currentHp = min(orb.maxHp, orb.currentHp + amount);
    _recordHeal(orb.currentHp - before, target: 2, sourceSlot: sourceSlot);
  }

  /// Records healing into the run-wide pool and, when a companion is the
  /// clear source, that companion's attributed healing.
  /// target: 0 = companions, 1 = ship, 2 = orb.
  void _recordHeal(double healed, {required int target, int? sourceSlot}) {
    if (healed <= 0) return;
    switch (target) {
      case 0:
        healingStats.toMons += healed;
      case 1:
        healingStats.toShip += healed;
      case 2:
        healingStats.toOrb += healed;
    }
    if (sourceSlot != null && sourceSlot >= 0) {
      _runStatsFor(sourceSlot).healingDone += healed;
    }
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
    bool requirePowerUp = true,
  }) {
    if (remainingChains <= 0 || sourceSlotIndex == null) return;
    if (requirePowerUp &&
        !powerUps.companionHasChainLightning(sourceSlotIndex)) {
      return;
    }

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
    // Mystic environment tint — viewport-covering element wash that
    // sits between the starfield and the arena. Stacks if multiple
    // mystics are active. Other world objects render on top.
    _renderMysticEnvironmentOverlay(canvas);
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
    for (final extra in extraBosses) {
      if (extra.isDead) continue;
      _renderBoss(canvas, extra);
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
      _bossProjectilePaint.color = bpColor.withValues(alpha: 0.9);
      canvas.drawCircle(proj.position, proj.radius, _bossProjectilePaint);
      if (!_reduceSecondaryGlows) {
        _bossProjectileGlowPaint
          ..color = bpColor.withValues(alpha: 0.15)
          ..maskFilter = null;
        canvas.drawCircle(
          proj.position,
          proj.radius * 1.8,
          _bossProjectileGlowPaint,
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
      _enemyProjectilePaint.color = color.withValues(alpha: 0.88);
      canvas.drawCircle(proj.position, proj.radius, _enemyProjectilePaint);
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

      if (proj.isRocket) {
        final angle = atan2(proj.velocity.dy, proj.velocity.dx);
        if (!_reduceSecondaryGlows) {
          canvas.drawCircle(
            proj.position,
            10,
            Paint()
              ..color = const Color(0xFFFF6F00).withValues(alpha: 0.3)
              ..maskFilter = null,
          );
        }
        canvas.save();
        canvas.translate(proj.position.dx, proj.position.dy);
        canvas.rotate(angle + pi / 2);
        final missilePath = Path()
          ..moveTo(0, -6)
          ..lineTo(-3, 4)
          ..lineTo(3, 4)
          ..close();
        canvas.drawPath(missilePath, Paint()..color = const Color(0xFFFF8F00));
        canvas.drawCircle(
          const Offset(0, 6),
          3,
          Paint()
            ..color = const Color(0xFFFFAB40).withValues(alpha: 0.6)
            ..maskFilter = null,
        );
        canvas.restore();
      } else {
        canvas.drawCircle(proj.position, 3, _shipProjectilePaint);
        if (!_reduceSecondaryGlows) {
          canvas.drawCircle(proj.position, 6, _shipProjectileGlowPaint);
        }
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
      _beamPaint
        ..color = beam.color.withValues(alpha: 0.85 * alpha)
        ..strokeWidth = beam.width;
      canvas.drawLine(beam.start, beam.end, _beamPaint);
      if (!_reduceSecondaryGlows) {
        _beamGlowPaint
          ..color = beam.color.withValues(alpha: 0.22 * alpha)
          ..strokeWidth = beam.width * 2.2;
        canvas.drawLine(beam.start, beam.end, _beamGlowPaint);
      }
    }

    _renderWingRings(canvas, cx, cy, viewW, viewH);

    // Wing+Plant flower pickups
    if (_flowerPickups.isNotEmpty) {
      final t = stats.timeElapsed;
      final petal = elementColor('Plant');
      final core = elementColor('Light');
      final petalPaint = Paint();
      final corePaint = Paint();
      final haloPaint = Paint();
      for (final flower in _flowerPickups) {
        if (!_isWithinViewport(
          flower.position,
          24,
          cx,
          cy,
          cx + viewW,
          cy + viewH,
          margin: 28,
        )) {
          continue;
        }
        final bob = sin(t * 2.4 + flower.bobPhase) * 1.6;
        final pos = Offset(flower.position.dx, flower.position.dy + bob);
        final fade = (flower.life / 12.0).clamp(0.0, 1.0);
        // Pulse stronger when close to expiry to signal pickup urgency.
        final lifePulse = flower.life < 3.0 ? 0.7 + 0.3 * sin(t * 8) : 1.0;
        // Soft outer glow halo so flowers are visible at a glance.
        haloPaint.color = petal.withValues(alpha: 0.18 * fade);
        canvas.drawCircle(pos, 14.0, haloPaint);
        haloPaint.color = petal.withValues(alpha: 0.28 * fade);
        canvas.drawCircle(pos, 9.5, haloPaint);
        // Five petals around a bright core (bigger than before).
        for (var i = 0; i < 5; i++) {
          final a = i * (pi * 2 / 5) + t * 0.35;
          final petalPos = pos + Offset(cos(a), sin(a)) * 5.5;
          petalPaint.color = petal.withValues(alpha: 0.92 * fade * lifePulse);
          canvas.drawCircle(petalPos, 4.0, petalPaint);
        }
        corePaint.color = core.withValues(alpha: 0.95 * fade * lifePulse);
        canvas.drawCircle(pos, 3.2, corePaint);
        // White-hot center pip for visibility.
        corePaint.color = const Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.85 * fade);
        canvas.drawCircle(pos, 1.4, corePaint);
      }
    }

    // Mask+Spirit ship-collectible wisps. Soft purple halo + white pip
    // so they read as ghostly orbs (matches Spirit family palette).
    if (_spiritWisps.isNotEmpty) {
      final t = stats.timeElapsed;
      final spirit = elementColor('Spirit');
      final haloPaint = Paint();
      final corePaint = Paint();
      for (final wisp in _spiritWisps) {
        if (!_isWithinViewport(
          wisp.position,
          22,
          cx,
          cy,
          cx + viewW,
          cy + viewH,
          margin: 28,
        )) {
          continue;
        }
        final bob = sin(t * 3.1 + wisp.bobPhase) * 1.8;
        final pos = Offset(wisp.position.dx, wisp.position.dy + bob);
        final fade = (wisp.life / 12.0).clamp(0.0, 1.0);
        final lifePulse = wisp.life < 3.0 ? 0.7 + 0.3 * sin(t * 8) : 1.0;
        // Layered translucent halos
        haloPaint.color = spirit.withValues(alpha: 0.16 * fade);
        canvas.drawCircle(pos, 13.0, haloPaint);
        haloPaint.color = spirit.withValues(alpha: 0.32 * fade);
        canvas.drawCircle(pos, 8.0, haloPaint);
        // Bright core
        corePaint.color = spirit.withValues(alpha: 0.95 * fade * lifePulse);
        canvas.drawCircle(pos, 3.2, corePaint);
        corePaint.color = const Color(
          0xFFFFFFFF,
        ).withValues(alpha: 0.90 * fade * lifePulse);
        canvas.drawCircle(pos, 1.4, corePaint);
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

    // Kin+Blood pact: pulsing red threads tying every living
    // alchemon together while a Blood kin's pact is active. The
    // mystic-bond visual hints that damage is being redistributed
    // as healing across the team.
    bool bloodPactActive = false;
    for (final c in activeCompanions.values) {
      if (c.kinBloodPactTimer > 0 &&
          c.member.family.toLowerCase() == 'kin' &&
          c.member.element == 'Blood') {
        bloodPactActive = true;
        break;
      }
    }
    if (bloodPactActive) {
      final t = stats.timeElapsed;
      final pulse = 0.55 + 0.45 * sin(t * 3);
      const blood = Color(0xFFC8254A);
      final allies = <Offset>[];
      if (!ship.isDead) allies.add(ship.position);
      for (final c in activeCompanions.values) {
        if (!c.isDead) allies.add(c.position);
      }
      // Connect every pair (small N → cheap).
      for (var i = 0; i < allies.length; i++) {
        for (var j = i + 1; j < allies.length; j++) {
          canvas.drawLine(
            allies[i],
            allies[j],
            Paint()
              ..strokeWidth = 1.2
              ..color = blood.withValues(alpha: 0.45 * pulse),
          );
        }
      }
    }

    // Kin auto-attack laser beams — thin element-tinted glow lines
    // that fade over ~0.28s. Drawn on top of the world so they read
    // clearly even when allies/enemies are stacked.
    if (_kinLaserBeams.isNotEmpty) {
      for (final beam in _kinLaserBeams) {
        if (beam.dead) continue;
        final t = (beam.life / _KinLaserBeam.maxLife).clamp(0.0, 1.0);
        // Soft outer glow stroke
        canvas.drawLine(
          beam.origin,
          beam.end,
          Paint()
            ..strokeWidth = 5.0
            ..strokeCap = StrokeCap.round
            ..color = beam.color.withValues(alpha: 0.22 * t),
        );
        // Middle glow stroke
        canvas.drawLine(
          beam.origin,
          beam.end,
          Paint()
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = beam.color.withValues(alpha: 0.65 * t),
        );
        // Thin white-hot core
        canvas.drawLine(
          beam.origin,
          beam.end,
          Paint()
            ..strokeWidth = 0.9
            ..strokeCap = StrokeCap.round
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95 * t),
        );
      }
    }

    // Mask+Spirit nuke punctuation — expanding spirit ring from the
    // ship + faint screen-wash. Decays via _maskSpiritNukeFlash.
    if (_maskSpiritNukeFlash > 0.01) {
      final f = _maskSpiritNukeFlash.clamp(0.0, 1.0);
      final spirit = elementColor('Spirit');
      // Outward ring — grows as the flash fades.
      final ringR = 80.0 + 720.0 * (1.0 - f);
      canvas.drawCircle(
        _maskSpiritNukeOrigin,
        ringR,
        Paint()..color = spirit.withValues(alpha: 0.22 * f),
      );
      canvas.drawCircle(
        _maskSpiritNukeOrigin,
        ringR * 0.65,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.32 * f),
      );
      // Screen wash — semi-transparent spirit-purple sheet across the
      // visible viewport. Anchored to the camera so it covers the
      // whole screen regardless of pan.
      canvas.drawRect(
        Rect.fromLTWH(cx, cy, viewW, viewH),
        Paint()..color = spirit.withValues(alpha: 0.18 * f),
      );
    }

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
    final alchemyFrac = _alchemicalMeterDisplayFrac;
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
          ..maskFilter = null,
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
  /// The enemy silhouette now lives in the shared cosmic enemy VFX layer so
  /// the preview harness can render the roster without playing the game.
  void _renderEnemy(Canvas canvas, CosmicSurvivalEnemy enemy) {
    drawSurvivalEnemy(
      canvas: canvas,
      enemy: enemy,
      time: stats.timeElapsed,
      reduceLabels: _reduceMinorLabels,
    );
  }

  /// Boss rendering — orbiting motes, core gradient, health bar
  /// Boss silhouette lives in the shared cosmic enemy VFX layer alongside the
  /// regular enemy, so the preview harness can render the roster.
  void _renderBoss(Canvas canvas, SurvivalBoss boss) {
    drawSurvivalBoss(
      canvas: canvas,
      boss: boss,
      time: stats.timeElapsed,
      reduceGlows: _reduceSecondaryGlows,
    );
  }

  void _renderCompanionProjectile(Canvas canvas, Projectile proj) {
    final eColor = elementColor(proj.element ?? 'Fire');

    // Kin+Spirit wisp: distinct visual per tier (effectCount 1-4).
    // Bigger halos + brighter pip + extra orbiting motes at higher
    // tiers so the player can see the wisp grow over the run.
    if (proj.abilityFamily == 'kin' &&
        proj.element == 'Spirit' &&
        proj.followSourceCompanion) {
      final tier = proj.effectCount.clamp(1, 4);
      final t = stats.timeElapsed;
      final spirit = elementColor('Spirit');
      final white = Color.lerp(spirit, const Color(0xFFFFFFFF), 0.55)!;
      final scale = 1.0 + 0.35 * (tier - 1);
      // Three layered halos; brightness ramps with tier.
      canvas.drawCircle(
        proj.position,
        14.0 * scale,
        Paint()..color = spirit.withValues(alpha: 0.16 + 0.04 * tier),
      );
      canvas.drawCircle(
        proj.position,
        8.5 * scale,
        Paint()..color = spirit.withValues(alpha: 0.30 + 0.06 * tier),
      );
      canvas.drawCircle(
        proj.position,
        4.0 * scale,
        Paint()..color = white.withValues(alpha: 0.55 + 0.10 * tier),
      );
      // White-hot pip
      canvas.drawCircle(
        proj.position,
        1.4 + 0.4 * tier,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.95),
      );
      // Tier 2+: a slowly-orbiting mote ring telegraphs "powered up"
      final motes = tier - 1; // 0/1/2/3
      for (var i = 0; i < motes; i++) {
        final a = t * 2.4 + i * (pi * 2 / max(1, motes));
        final r = 9.0 * scale + 2.0;
        canvas.drawCircle(
          proj.position + Offset(cos(a) * r, sin(a) * r),
          1.6,
          Paint()..color = white.withValues(alpha: 0.85),
        );
      }
      return;
    }

    if (proj.visualStyle == ProjectileVisualStyle.mysticOrbital) {
      // Stationary mystic placements (fog nodes, mire pools, dark
      // wells, plant turrets, monolith pillars, etc.) are environment
      // *fixtures* — render them with the modern ground-zone painters
      // so each element reads as its own terrain effect.
      if (proj.stationary &&
          drawMaskElementalProjectileVisual(
            canvas: canvas,
            projectile: proj,
            position: proj.position,
            color: eColor,
            time: stats.timeElapsed,
          )) {
        return;
      }

      // Moving / orbiting mystic projectiles get a richer comet look
      // than the generic single-circle render. A bright core + halo
      // glow + element-tinted comet tail makes each cast feel like an
      // ultimate, not a regular dart.
      final dir = Offset(cos(proj.angle), sin(proj.angle));
      final radius = (1.65 * proj.visualScale).clamp(1.4, 6.1).toDouble();
      final pulse = 0.78 + 0.22 * sin(stats.timeElapsed * 4.0 + proj.life);
      // Outer halo glow
      if (!_useReducedCompanionProjectileRendering(proj)) {
        _companionProjStrokePaint
          ..style = PaintingStyle.fill
          ..color = eColor.withValues(alpha: 0.18 * pulse);
        canvas.drawCircle(
          proj.position,
          radius * 2.6,
          _companionProjStrokePaint,
        );
        _companionProjStrokePaint.style = PaintingStyle.stroke;
        // Comet trail
        for (var i = 1; i <= 3; i++) {
          final fade = 1.0 - i * 0.30;
          final back = proj.position - dir * (radius * 2.0 * i);
          _companionProjStrokePaint
            ..style = PaintingStyle.fill
            ..color = eColor.withValues(alpha: 0.32 * fade);
          canvas.drawCircle(
            back,
            radius * (1.0 + i * 0.18) * 0.55,
            _companionProjStrokePaint,
          );
          _companionProjStrokePaint.style = PaintingStyle.stroke;
        }
      }
      // Bright element core
      _companionProjCorePaint.color = eColor.withValues(alpha: 0.92 * pulse);
      canvas.drawCircle(proj.position, radius, _companionProjCorePaint);
      // White-hot inner pip
      _companionProjCorePaint.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.85 * pulse);
      canvas.drawCircle(proj.position, radius * 0.42, _companionProjCorePaint);
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }

    if (drawMaskElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      // Mask+Plant: overlay wormy attack tendrils on top of the ambient
      // vine art. Tendrils reach toward enemies inside the snare/effect
      // radius and undulate with `time`. Amplitude + segment count
      // scale with feed count so a freshly-cast vine has 1 thin worm
      // and a maxed (100-feed) vine has many dramatic ones.
      if (proj.abilityFamily == 'mask' && proj.element == 'Plant') {
        _renderMaskPlantWormyTendrils(canvas, proj, eColor);
      }
      // Mask traps are ground-zone identity pieces. Even performance mode
      // keeps these authored silhouettes so elements do not collapse into
      // same-shape circles with different colors.
      return;
    }

    if (drawLetElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
      // Performance mode trims the Let meteor's secondary glow passes and
      // soft plumes; the rock, the trail and the element accent stay.
      reduceAmbient: _useReducedCompanionProjectileRendering(proj),
    )) {
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }

    if (_useReducedCompanionProjectileRendering(proj)) {
      final radius = switch (proj.visualStyle) {
        ProjectileVisualStyle.meteor => 3.6 * proj.visualScale,
        ProjectileVisualStyle.hornImpact => 3.4 * proj.visualScale,
        ProjectileVisualStyle.kinOrbital => 3.2 * proj.visualScale,
        ProjectileVisualStyle.slash => 2.4 * proj.visualScale,
        _ => 2.8 * proj.visualScale,
      };
      if (proj.visualStyle == ProjectileVisualStyle.slash) {
        final len = 6.0 * proj.visualScale;
        _companionProjLinePaint
          ..color = eColor.withValues(alpha: 0.9)
          ..strokeWidth = 2.0;
        canvas.drawLine(
          Offset(
            proj.position.dx - cos(proj.angle) * len,
            proj.position.dy - sin(proj.angle) * len,
          ),
          Offset(
            proj.position.dx + cos(proj.angle) * len,
            proj.position.dy + sin(proj.angle) * len,
          ),
          _companionProjLinePaint,
        );
      } else {
        _companionProjCorePaint.color = eColor.withValues(alpha: 0.88);
        canvas.drawCircle(proj.position, radius, _companionProjCorePaint);
      }
      if (proj.decoy) {
        _companionProjStrokePaint
          ..color = eColor.withValues(alpha: 0.22)
          ..strokeWidth = 1.2;
        canvas.drawCircle(
          proj.position,
          10 * proj.visualScale,
          _companionProjStrokePaint,
        );
      }
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }

    if (drawPipElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }
    if (drawManeElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }
    if (drawHornElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      drawProjectileRoleOverlay(
        canvas: canvas,
        projectile: proj,
        position: proj.position,
        color: eColor,
        time: stats.timeElapsed,
      );
      return;
    }
    // The generic silhouette now lives in the shared cosmic VFX layer so
    // survival, cosmic space and the preview harness draw the identical
    // projectile. Reduced-rendering cases return before this point, so the
    // flag is false here by construction; passed explicitly all the same.
    drawGenericProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
      reduceAmbient: _useReducedCompanionProjectileRendering(proj),
    );

    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    );

    if (proj.decoy) {
      _companionProjStrokePaint
        ..color = eColor.withValues(alpha: 0.2)
        ..strokeWidth = 1.5;
      canvas.drawCircle(
        proj.position,
        12 * proj.visualScale,
        _companionProjStrokePaint,
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
        ..maskFilter = null,
    );

    // ── Kin support-path active overlays ──────────────────────
    if (comp.member.family.toLowerCase() == 'kin') {
      final time = stats.timeElapsed;

      // Kin+Ice special charge wind-up: frost build-up around the kin
      // while kinIceChargeTimer ticks down before the radial release.
      if (comp.kinIceChargeTimer > 0 && comp.kinIceChargeTotal > 0) {
        final t =
            (1.0 -
                    (comp.kinIceChargeTimer / comp.kinIceChargeTotal).clamp(
                      0.0,
                      1.0,
                    ))
                .toDouble();
        final ice = elementColor('Ice');
        final white = Color.lerp(ice, const Color(0xFFFFFFFF), 0.6)!;
        canvas.drawCircle(
          Offset.zero,
          26 + 14 * t,
          Paint()..color = ice.withValues(alpha: 0.20 * t),
        );
        canvas.drawCircle(
          Offset.zero,
          18 + 8 * t,
          Paint()..color = white.withValues(alpha: 0.35 * t),
        );
        // Spinning frost flecks around the perimeter.
        for (var i = 0; i < 5; i++) {
          final a = time * 2.4 + i * (pi * 2 / 5);
          final r = 28.0 + 6.0 * t;
          canvas.drawCircle(
            Offset(cos(a) * r, sin(a) * r),
            1.4,
            Paint()..color = white.withValues(alpha: 0.85 * t),
          );
        }
      }

      // Kin+Lightning special charge: crackling halo while channelling
      // (the buff active window also pumps ally autos to chain).
      if (comp.kinLightningChargeTimer > 0 &&
          comp.member.element == 'Lightning') {
        final pulse = 0.78 + 0.22 * sin(time * 14);
        final ltg = elementColor('Lightning');
        final hot = Color.lerp(ltg, const Color(0xFFFFFFFF), 0.55)!;
        canvas.drawCircle(
          Offset.zero,
          30,
          Paint()..color = ltg.withValues(alpha: 0.22 * pulse),
        );
        canvas.drawCircle(
          Offset.zero,
          18,
          Paint()..color = hot.withValues(alpha: 0.42 * pulse),
        );
        // Random crackling arcs from kin outward.
        for (var i = 0; i < 3; i++) {
          final a = _rng.nextDouble() * pi * 2;
          final r1 = 12.0 + _rng.nextDouble() * 6;
          final r2 = 28.0 + _rng.nextDouble() * 8;
          canvas.drawLine(
            Offset(cos(a) * r1, sin(a) * r1),
            Offset(cos(a) * r2, sin(a) * r2),
            Paint()
              ..strokeWidth = 1.2
              ..color = hot.withValues(alpha: 0.85 * pulse),
          );
        }
      }

      // Kin+Fire post-revive orbital flame: a steady spinning flame
      // around the fire kin while the permanent flame is active.
      if (comp.kinFireOrbitalFlameActive && comp.member.element == 'Fire') {
        final ember = const Color(0xFFFFB060);
        final hot = const Color(0xFFFFE7B0);
        // 3 orbiting flame motes
        for (var i = 0; i < 3; i++) {
          final a = time * 3.2 + i * (pi * 2 / 3);
          const r = 32.0;
          final pos = Offset(cos(a) * r, sin(a) * r);
          canvas.drawCircle(
            pos,
            6.0,
            Paint()..color = ember.withValues(alpha: 0.50),
          );
          canvas.drawCircle(
            pos,
            3.2,
            Paint()..color = hot.withValues(alpha: 0.85),
          );
        }
      }

      // Kin+Lava plate glow: subtle molten ring around the kin while
      // its plate timer is active. (Universal overlay below paints
      // the plate on every other ally too.)
      if (comp.kinLavaPlateTimer > 0 && comp.member.element == 'Lava') {
        final pulse = 0.80 + 0.20 * sin(time * 3);
        const ember = Color(0xFFFF7A20);
        canvas.drawCircle(
          Offset.zero,
          22,
          Paint()..color = ember.withValues(alpha: 0.18 * pulse),
        );
      }

      // Kin+Dark cloak: shadowy aura — the kin itself becomes faded
      // while broadcasting the cloak.
      if (comp.kinDarkCloakTimer > 0 && comp.member.element == 'Dark') {
        canvas.drawCircle(
          Offset.zero,
          24,
          Paint()..color = const Color(0xFF1A0A2A).withValues(alpha: 0.35),
        );
      }
    }

    // Universal Lava plate overlay — paints a molten glow ring around
    // every active companion (Lava kin or not) while any Lava kin's
    // plate is up, so the team-wide buff is visible.
    if (_isAnyKinLavaPlateActive()) {
      final pulse = 0.78 + 0.22 * sin(stats.timeElapsed * 3);
      const ember = Color(0xFFFF7A20);
      canvas.drawCircle(
        Offset.zero,
        20,
        Paint()..color = ember.withValues(alpha: 0.20 * pulse),
      );
      canvas.drawCircle(
        Offset.zero,
        14,
        Paint()
          ..color = const Color(0xFFFFC080).withValues(alpha: 0.18 * pulse),
      );
    }

    // Kin auto-attack charge build-up: while kinAutoChargeTimer > 0,
    // paint a brightening energy aura that grows over the 1.5s charge,
    // plus a focal pip aimed at the cached target so the player can
    // see who's about to get zapped.
    if (comp.member.family.toLowerCase() == 'kin' &&
        comp.kinAutoChargeTimer > 0) {
      final t = (comp.kinAutoChargeTimer / _kinChargeTime)
          .clamp(0.0, 1.0)
          .toDouble();
      final time = stats.timeElapsed;
      final pulse = 0.85 + 0.15 * sin(time * 12 + comp.kinAutoChargeTimer * 8);
      // Three layered glow halos that brighten with charge progress.
      canvas.drawCircle(
        Offset.zero,
        26 + 6 * t,
        Paint()..color = ec.withValues(alpha: 0.22 * t * pulse),
      );
      canvas.drawCircle(
        Offset.zero,
        18 + 4 * t,
        Paint()..color = ec.withValues(alpha: 0.42 * t * pulse),
      );
      canvas.drawCircle(
        Offset.zero,
        9 + 3 * t,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.65 * t * pulse),
      );
      // Sparkles drawn around the kin (seed-randomised per frame).
      for (var i = 0; i < (2 + (t * 4).round()); i++) {
        final a = _rng.nextDouble() * pi * 2;
        final r = 12 + _rng.nextDouble() * (12 + 8 * t);
        canvas.drawCircle(
          Offset(cos(a) * r, sin(a) * r),
          0.9 + _rng.nextDouble() * (0.7 + 0.6 * t),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * t),
        );
      }
      // Aiming reticule pip — tracks the LIVE enemy if it's still
      // around, otherwise falls back to the cached snapshot. Helps
      // the player see where the laser is about to fire.
      Offset? aim;
      final lockedEnemy = comp.kinAutoChargeEnemy;
      if (lockedEnemy != null && !lockedEnemy.isDead) {
        aim = lockedEnemy.position;
      } else {
        aim = comp.kinAutoChargeTarget;
      }
      if (aim != null) {
        final dir = aim - comp.position;
        if (dir.distance > 0.01) {
          final norm = dir / dir.distance;
          final reach = 18.0 + 14.0 * t;
          canvas.drawCircle(
            Offset(norm.dx * reach, norm.dy * reach),
            1.4 + 1.4 * t,
            Paint()..color = ec.withValues(alpha: 0.85 * pulse),
          );
        }
      }
    }

    // Pip+Steam: a steam cloud billows around the pip and thickens as
    // the attack-speed ramp climbs toward its +300% peak.
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Steam') {
      final progress =
          (comp.pipSteamWindowTimer /
                  CosmicSurvivalCompanion.pipSteamWindowDuration)
              .clamp(0.0, 1.0);
      final t = stats.timeElapsed;
      for (var i = 0; i < 4; i++) {
        final a = t * 1.3 + i * pi * 0.5;
        final orbit = 14.0 + 6.0 * sin(t * 2.0 + i);
        final puffR = 8.0 + 4.0 * sin(t * 2.6 + i * 1.7) + progress * 5.0;
        canvas.drawCircle(
          Offset(cos(a) * orbit, sin(a) * orbit),
          puffR,
          Paint()
            ..color = const Color(
              0xFFEAF6FF,
            ).withValues(alpha: 0.10 + progress * 0.16)
            ..maskFilter = null,
        );
      }
    }

    // Kin+Steam boiler: stack-count badge floating above the kin
    // while the buff window is active. Shows current/max so the
    // player can see when the boiler is at full pressure.
    if (comp.member.family.toLowerCase() == 'kin' &&
        comp.member.element == 'Steam' &&
        comp.kinSteamBoilerTimer > 0) {
      const badgeY = -34.0;
      const steam = Color(0xFFBFE5FF);
      // Tiny gauge dot
      canvas.drawCircle(
        Offset(-10, badgeY),
        3.0,
        Paint()..color = steam.withValues(alpha: 0.95),
      );
      canvas.drawCircle(
        Offset(-10, badgeY),
        1.3,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9),
      );
      final stackText = TextSpan(
        text: '${comp.kinSteamBoilerStacks}/10',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          shadows: [
            Shadow(
              color: Color(0xFF0A1A22),
              offset: Offset(0, 1),
              blurRadius: 1.5,
            ),
          ],
        ),
      );
      final tp = TextPainter(text: stackText, textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(-4, badgeY - tp.height * 0.5));
    }

    // Wing+Plant: flower-collection counter floating above the wing.
    // Shows the current stack count (capped at 50 for the +200%
    // damage cap) so the player can see their power-up at a glance.
    if (comp.member.family.toLowerCase() == 'wing' &&
        comp.member.element == 'Plant') {
      final stacks = comp.abilityKillStacks.clamp(0, 50);
      if (stacks > 0) {
        final petal = elementColor('Plant');
        final badgeY = -34.0;
        // Tiny flower icon (single petal cluster + core).
        canvas.drawCircle(
          Offset(-7, badgeY),
          3.0,
          Paint()
            ..color = petal.withValues(alpha: 0.95)
            ..maskFilter = null,
        );
        canvas.drawCircle(
          Offset(-7, badgeY),
          1.2,
          Paint()
            ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85)
            ..maskFilter = null,
        );
        // Numeric counter to the right of the flower.
        final stackText = TextSpan(
          text: 'x$stacks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [
              const Shadow(
                color: Color(0xFF1A2A1A),
                offset: Offset(0, 1),
                blurRadius: 1.5,
              ),
            ],
          ),
        );
        final tp = TextPainter(
          text: stackText,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-1, badgeY - tp.height * 0.5));
      }
    }

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
          ..maskFilter = null,
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
          ..maskFilter = null,
      );
      for (var t = 0; t < 4; t++) {
        final trailAngle = comp.angle + pi;
        final trailDist = (7.0 + t * 7.0) * trailScale;
        canvas.drawCircle(
          Offset(cos(trailAngle) * trailDist, sin(trailAngle) * trailDist),
          (5.0 - t) * chargeWidth,
          Paint()
            ..color = ec.withValues(alpha: (1.0 - t / 4.0) * 0.34)
            ..maskFilter = null,
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

    // Kin+Lava plate: molten glow ring on the ship while any Lava
    // kin's plate timer is up.
    if (_isAnyKinLavaPlateActive()) {
      final pulse = 0.78 + 0.22 * sin(elapsed * 3);
      const ember = Color(0xFFFF7A20);
      canvas.drawCircle(
        Offset.zero,
        26,
        Paint()..color = ember.withValues(alpha: 0.22 * pulse),
      );
      canvas.drawCircle(
        Offset.zero,
        18,
        Paint()
          ..color = const Color(0xFFFFC080).withValues(alpha: 0.18 * pulse),
      );
    }

    // Kin+Lightning tesla charge: while any Lightning kin is actively
    // channelling, paint a visible electric current around the ship
    // so the player can see the buff is on. Drawn in world space
    // (before rotate) so the arcs aren't tied to ship heading.
    if (_isAnyKinLightningChargeActive()) {
      final ltg = elementColor('Lightning');
      final hot = Color.lerp(ltg, const Color(0xFFFFFFFF), 0.55)!;
      final pulse = 0.75 + 0.25 * sin(elapsed * 14);
      // Outer aura halo
      canvas.drawCircle(
        Offset.zero,
        32,
        Paint()..color = ltg.withValues(alpha: 0.20 * pulse),
      );
      canvas.drawCircle(
        Offset.zero,
        22,
        Paint()..color = hot.withValues(alpha: 0.32 * pulse),
      );
      // Randomised crackling arcs around the rim — 4 per frame keeps
      // it dense but not overwhelming.
      for (var i = 0; i < 4; i++) {
        final aa = _rng.nextDouble() * pi * 2;
        final r1 = 14.0 + _rng.nextDouble() * 8;
        final r2 = 26.0 + _rng.nextDouble() * 10;
        canvas.drawLine(
          Offset(cos(aa) * r1, sin(aa) * r1),
          Offset(cos(aa) * r2, sin(aa) * r2),
          Paint()
            ..strokeWidth = 1.2
            ..strokeCap = StrokeCap.round
            ..color = hot.withValues(alpha: 0.85 * pulse),
        );
      }
    }

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
          ..maskFilter = null,
      );
    }

    canvas.drawCircle(
      const Offset(0, 18),
      9,
      Paint()
        ..color =
            (ghostMode ? const Color(0x808BE9FF) : const Color(0x7000CFFF))
                .withValues(alpha: (ghostMode ? 0.34 : 0.55) * enginePulse)
        ..maskFilter = null,
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
