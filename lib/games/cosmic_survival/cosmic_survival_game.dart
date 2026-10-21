import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/services/debug_settings_service.dart';
// lib/games/cosmic_survival/cosmic_survival_game.dart
//
// COSMIC SURVIVAL FLAME GAME — REDESIGNED
// Uses the same companion abilities, enemy visuals, ship rendering,
// and boss AI as the main cosmic exploration game.

import 'dart:collection' show ListBase;
import 'dart:math';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'dart:typed_data';

import 'survival_outbreak.dart';
import '../cosmic/mask_trap_placement.dart';
import 'components/mystic_world_ambience.dart';
import 'cosmic_survival_balance.dart';
import 'survival_outbreak_vfx.dart';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic/mane_alchemical_vfx.dart'
    show maneLavaPoolCrowd;
import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/games/shared/enemy_action.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' show ShipComponent;
import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_projectile_vfx.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart'
    show vfxFlare, vfxGrain, vfxGrainsFlush, vfxMaterial, vfxPolar, vfxSpill;
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/kin_support_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/cosmic_survival/surge_grains.dart';
import 'package:alchemons/games/cosmic_survival/survival_mender_vfx.dart';
import 'package:alchemons/games/shared/burn_healing.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_let.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mask.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mane.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_payload.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_pip.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_runtime.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/games/cosmic_survival/arena_art.dart';
import 'package:alchemons/games/cosmic/hostile_shot_vfx.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/games/shared/damage_numbers.dart';
import 'package:alchemons/games/shared/enemy_flight_steering.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/games/shared/type_effectiveness.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/albino_look.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/variant_look.dart';
import 'package:flame/components.dart' show Anchor;
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// COMPANION DATA - uses same stat formulas as cosmic game
// ---------------------------------------------------------------------------

/// One of the orb's fronts in flight (paintOrbFront).
class _OrbFront {
  _OrbFront({required this.reach, required this.seconds, required this.nova});
  final double reach, seconds;
  final bool nova;
  double age = 0;
}

/// The least time between two hit flashes on one companion.
const double kCompanionFlashGap = 0.5;

/// Below this share of its health a companion or the ship stands in ember
/// light.
const double _kLowHealth = 0.35;

class CosmicSurvivalCompanion {
  final CosmicPartyMember member;
  int slotIndex;
  Offset position;
  Offset anchor;
  int maxHp;
  int currentHp;
  int physAtk;
  int elemAtk;

  /// What this family's special hits for. See the ability stat contract in
  /// alchemon_combat_stats.dart — a Mane's catapult is paid for out of
  /// Strength, not Beauty.
  int abilityAtk;
  int physDef;
  int elemDef;
  double cooldownReduction;

  /// Special cadence, from this family's own stat blend. Basic attacks keep
  /// reading [cooldownReduction], which is Speed's alone.
  double specialCooldownReduction;
  double attackRange;
  double specialAbilityRange;
  double basicCooldown;
  double specialCooldown;
  bool tethered;
  bool isDead;

  /// Set to 1 by every hit and run down in the update. Gameplay reads it;
  /// the sprite shows [shownFlash] instead.
  double hitFlash;

  /// The flash the sprite shows: a hit lights it as a short soft wash at
  /// most once every [kCompanionFlashGap] seconds. Shown raw, a creature in
  /// contact with a horde was re-lit every frame and stayed a white cut-out.
  double shownFlash = 0;
  double _flashGate = 0;
  double _flashAfterDecay = 0;

  /// Runs [hitFlash] down and decides what the sprite shows this frame.
  void tickFlash(double dt) {
    final struck = hitFlash > _flashAfterDecay + 0.001;
    _flashGate -= dt;
    if (struck && _flashGate <= 0) {
      shownFlash = 1;
      _flashGate = kCompanionFlashGap;
    } else {
      shownFlash = max(0.0, shownFlash - dt * 7);
    }
    hitFlash = (hitFlash - dt * 4).clamp(0.0, 1.0);
    _flashAfterDecay = hitFlash;
  }

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

  /// Fractional blessing healing not yet worth a whole HP. See the blessing
  /// tick in the companion update for why this has to be carried.
  double blessingCarry = 0;

  /// This blessing is a Kin's, shared by Communion, not one this companion
  /// cast: it heals the companion and is not echoed into the orb again.
  bool blessingShared = false;
  double basicHasteTimer;
  double basicHasteMultiplier;

  /// The Steam boilers' haste on this companion, set fresh by the Kin tick
  /// every frame from the stacks they hold now. Kept apart from the timed
  /// haste above: written through that window's min(), the boiler's peak
  /// stuck for good once reached, because the boiler held the window open
  /// every frame and nothing ever raised the value again (2026-10-20 audit).
  double kinSteamHasteMultiplier = 1.0;
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

  /// What it is fighting — an enemy or the boss — so the companions on one
  /// target can share out the arc round it.
  Object? engagedTarget;
  double stickyTargetLockTimer;
  Offset steeringVelocity;

  /// Which way the sprite faces. Turns only once the heading is clearly
  /// the other way, so a target straight above or below does not flick it
  /// back and forth.
  bool facingRight = true;
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
  // Threshold reached → fires the non-boss nuke and resets to 0. The bank
  // carries across casts: a clear takes a set number of wisps, one to three
  // casts' worth by the caster's count ([maskSpiritClearThreshold]);
  // [maskSpiritClearAt] is the last cast's.
  int maskSpiritWispBank;
  int maskSpiritClearAt = 0;

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
  // Kin+Fire: the rebirth payoff. Fire kin is the one companion whose whole
  // kit is dormant until the orb dies, so when the phoenix finally fires it
  // pays for the wait — permanently, and in proportion to the kin's own stats.
  // Rolled once at the moment of rebirth and kept for the rest of the run.
  double kinFireRebirthDamageAmp = 1.0;
  double kinFireRebirthHaste = 1.0;
  double kinFireFlameRadius = 70;
  double kinFireFlameInterval = 0.5;
  double kinFireFlameTimer = 0;
  // Kin+Lava: when > 0, damage taken by the orb, ship or a companion
  // triggers a splash of lava at whatever struck (reactive plate armor).
  double kinLavaPlateTimer = 0;
  // Kin+Ice: charge windup → release radial frost. Charge timer
  // ticks down; on hitting 0 the release fires.
  double kinIceChargeTimer = 0;
  double kinIceChargeTotal = 0; // for visual progress
  // Kin+Steam boiler: damage→AS stacks. Buff window + decay timer.
  double kinSteamBoilerTimer = 0;
  int kinSteamBoilerStacks = 0;
  double kinSteamStackDecayTimer = 0;
  // Fractional stack progress. Chaff hits the orb for a few HP at a time,
  // and flooring each frame's share on its own never reached one stack.
  double kinSteamStackCarry = 0;
  // Kin+Lightning: while > 0, the kin is actively channelling and
  // all allies' auto-attacks chain to nearby enemies.
  double kinLightningChargeTimer = 0;
  // Kin+Dark veil: while > 0, the orb is hidden and companions are
  // untargetable. Bodies that came for the orb go for the ship instead,
  // so the veil is a decoy the player has to fly. Stored on the casting
  // Dark kin; enemy targeting reads from any active Dark kin's timer.
  double kinDarkCloakTimer = 0;
  // Kin+Blood pact: while > 0, a share of damage that would reach the orb
  // is taken by the living companions instead, and a share of damage any
  // alchemon takes is healed across the others.
  double kinBloodPactTimer = 0;
  double kinBloodPactAbsorbCarry = 0;
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

  /// The boss the charge began on, when it began on one. The laser fires at
  /// where it stands at release, as it does for a locked body.
  SurvivalBoss? kinAutoChargeBoss;
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

  static const double baseSpecialCooldown = kAlchemonBaseSpecialCooldown;
  static const double baseBasicCooldown = kAlchemonBaseBasicCooldown;
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
    required this.abilityAtk,
    required this.physDef,
    required this.elemDef,
    this.cooldownReduction = 1.0,
    this.specialCooldownReduction = 1.0,
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

  /// The strongest damage amp this companion has right now: an open window's,
  /// or a reborn Fire Kin's own, which is kept for good.
  ///
  /// The rebirth's amp and haste are read here rather than written into the
  /// shared windows. Holding those windows open with max/min froze whatever
  /// else had opened them, so a temporary amp gained while reborn — Mask
  /// Ice's 2.4x — stuck for the rest of the run (2026-10-20 audit).
  double get damageAmp => max(
    damageAmpTimer > 0 ? damageAmpMultiplier : 1.0,
    kinFireOrbitalFlameActive ? kinFireRebirthDamageAmp : 1.0,
  ).clamp(1.0, kCompanionDamageAmpCeiling);

  /// The deepest basic-attack haste this companion has right now (lower is
  /// faster): an open window's, a Steam boiler's, or a reborn Fire Kin's.
  double get basicHaste => min(
    min(
      basicHasteTimer > 0 ? basicHasteMultiplier : 1.0,
      kinSteamHasteMultiplier,
    ),
    kinFireOrbitalFlameActive ? kinFireRebirthHaste : 1.0,
  );

  double get hpPercent =>
      maxHp > 0 ? (currentHp / maxHp).clamp(0, 1).toDouble() : 0;

  /// Seconds between auto attacks — the shared rule in
  /// alchemon_combat_stats.dart, with this companion's live haste and Pip
  /// element passive.
  double get effectiveBasicCooldown => alchemonBasicAttackInterval(
    family: member.family,
    element: member.element,
    cooldownReduction: cooldownReduction,
    physAtk: physAtk,
    haste: basicHaste,
    elementPassive: pipElementBasicPassive(
      family: member.family,
      element: member.element,
      spiritEmpowerTimer: pipSpiritEmpowerTimer,
      steamWindowTimer: pipSteamWindowTimer,
      steamWindowDuration: pipSteamWindowDuration,
    ),
  );

  /// Seconds between specials — the shared rule in alchemon_combat_stats.dart,
  /// and survival's own pace for a Mane ([kSurvivalManeSpecialPace]).
  double get effectiveSpecialCooldown =>
      alchemonSpecialInterval(
        family: member.family,
        element: member.element,
        specialCooldownReduction: specialCooldownReduction,
        abilityAtk: abilityAtk,
      ) *
      (member.family.toLowerCase() == 'mane' ? kSurvivalManeSpecialPace : 1.0);

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

  /// Damage this body chose to take for someone else — Bodyguard's share of
  /// a hit on the orb. It lands through the hit invulnerability and leaves it
  /// as it was: the invulnerability is for blows this body was struck with,
  /// and a share that vanished inside it made Bastion a free cut for the orb.
  void takeSharedDamage(int dmg) {
    if (dmg <= 0) return;
    var remaining = dmg;
    if (shieldHp > 0) {
      final absorbed = min(remaining, shieldHp);
      shieldHp -= absorbed;
      remaining -= absorbed;
    }
    if (remaining > 0) currentHp = (currentHp - remaining).clamp(0, maxHp);
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

  /// Damage no Alchemon dealt: the ship's guns, the orb's own defenses, run
  /// perks. With each companion's [CompanionRunStats.damageDealt] it makes
  /// up everything the run dealt, so the results' shares add up.
  double otherDamage = 0;

  /// The ship's share of [otherDamage]: its guns, rockets, missiles and
  /// turret. [shipKills] are the bodies it finished.
  double shipDamage = 0;
  int shipKills = 0;

  String get formattedTime {
    final minutes = (timeElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (timeElapsed % 60).toInt().toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// Per-companion combat contribution accumulated over a survival run.
/// How much longer a Mane waits between catapults in survival than the
/// shared rule says (the frame's 0.70 reads about 0.91 here).
///
/// "Mane — still the clearer, not the whole show" (2026-10-20 spec, aim
/// 24-32% of a party's damage at every band). Survival's alone, like the
/// family damage multipliers: the horde is where one heavy line through a
/// lane every 1-3 s added up to the whole show, and the battle and open
/// space keep the frame's pace. Cadence was the lever that moved the share
/// at every band; the shorter life and the hitbox cap barely did, because a
/// Mane's catapults overlapped and the next one took what the last missed.
const double kSurvivalManeSpecialPace = 1.3;

/// What a Mane's hits on ordinary bodies are worth in survival (bosses 1.0).
const double kSurvivalManeTrashDamage = 0.9;

class CompanionRunStats {
  double damageDealt = 0;

  int kills = 0;
  double damageTaken = 0;
  // Healing this companion is directly responsible for (blessings,
  // lifesteal, blood pact). Ambient/team-wide healing is not attributed.
  double healingDone = 0;

  /// Seconds out on the field, alive, on the run's clock.
  double fieldSeconds = 0;
}

/// Run-wide healing totals split by recipient.
class RunHealingStats {
  double toMons = 0;
  double toShip = 0;
  double toOrb = 0;

  double get total => toMons + toShip + toOrb;
}

/// A mender's heal on its way to [body]: [amount] lands when [eta] runs out.
class _Mend {
  _Mend(this.body, this.amount, this.eta);
  final CosmicSurvivalEnemy body;
  final double amount;
  double eta;
}

// ---------------------------------------------------------------------------
// BACKGROUND STAR
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// VFX PARTICLE
// ---------------------------------------------------------------------------

class _VfxParticle {
  double x, y, vx, vy, size, life;
  final double maxLife;
  final Color color;

  /// The grain colours this particle is drawn in (ability_grains.dart).
  final AbilityGrainTone tone;
  _VfxParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.life,
    required this.color,
  }) : maxLife = life,
       tone = abilityGrainTone(color);
  double get alpha => (life / maxLife * 2).clamp(0.0, 1.0);
  bool get dead => life <= 0;

  // Drag per second, shared with AbilityVfxPool (ability_grains.dart): the
  // same distance at 60 and 120 Hz, and light enough that a burst authored
  // as speed × life reaches its area (0.92 per frame stopped it at ≈ v/5).
  void update(double dt) {
    final drag = abilityParticleDragFactor(dt);
    x += vx * dt;
    y += vy * dt;
    vx *= drag;
    vy *= drag;
    life -= dt;
  }
}

/// Survival's ability particle pool. A plain list, except that with [thin]
/// set (the reduced-quality settings) every other spawn is dropped where it
/// is born. It used to skip odd indices at draw time, and as the list
/// compacted particles changed parity and blinked frame to frame.
class _VfxPool extends ListBase<_VfxParticle> {
  final List<_VfxParticle> _items = [];
  bool thin = false;
  int _spawned = 0;

  @override
  int get length => _items.length;

  @override
  set length(int n) => _items.length = n;

  @override
  _VfxParticle operator [](int i) => _items[i];

  @override
  void operator []=(int i, _VfxParticle p) => _items[i] = p;

  @override
  Iterator<_VfxParticle> get iterator => _items.iterator;

  @override
  void add(_VfxParticle element) {
    if (thin && (_spawned++).isOdd) return;
    _items.add(element);
  }

  @override
  void addAll(Iterable<_VfxParticle> iterable) {
    for (final p in iterable) {
      add(p);
    }
  }

  @override
  void removeWhere(bool Function(_VfxParticle) test) =>
      _items.removeWhere(test);

  @override
  void clear() => _items.clear();
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
/// One drifting ember from a Fire Mystic's field.
///
/// The field is not a timed effect. It exists for as long as its caster is
/// alive and deployed, which is the whole point of the mechanic: a Mystic is
/// the single-slot pick, so choosing one should mean choosing what the map IS
/// rather than buying one big explosion. Embers make the player care whether a
/// specific companion lives, which nothing else in the roster does.
class _MysticEmber {
  /// Its heat and its lit heart, as grain colours (0xRRGGBB): Fire's
  /// material light and glint.
  static const int heat = 0xE0703A;
  static const int lit = 0xFFC27A;

  _MysticEmber({
    required this.position,
    required this.velocity,
    required this.ownerSlot,
    required this.seed,
  });

  Offset position;
  Offset velocity;

  /// Which companion's field this belongs to. When that companion is recalled
  /// or dies, its embers fade.
  final int ownerSlot;

  /// Per-ember phase so the field shimmers instead of pulsing in unison.
  final double seed;

  /// Counts down after igniting something, so a single ember parked on an
  /// enemy cannot set it alight every frame. The ember survives — the field is
  /// meant to persist, not to be spent.
  double reignite = 0;

  /// 1 while the field is live; drains once the caster is gone, so the embers
  /// visibly go out rather than vanishing between frames.
  double fade = 1.0;
}

/// A small enemy that died inside a Spirit Mystic's world and came back on our
/// side: white, lit from within, hunting whatever it used to fight beside.
///
/// It is not a summon the cast pays for — it is the fight's own dead. A Spirit
/// world therefore gets stronger exactly when the screen is worst, which is the
/// opposite of how every other ability in the game scales.
class _MysticRevenant {
  _MysticRevenant({
    required this.position,
    required this.ownerSlot,
    required this.damage,
    required this.radius,
    required this.speed,
    required this.seed,
    required this.life,
  });

  Offset position;
  Offset velocity = Offset.zero;
  final int ownerSlot;
  final double damage;
  final double radius;
  final double speed;
  final double seed;

  /// Seconds left before it goes back to being dead.
  double life;

  /// Ramps 0 → 1 as the body turns over: the color drains out of it and the
  /// glow comes up. The turn is the whole point of the mechanic, so it is
  /// animated rather than instant.
  double rise = 0;

  /// Per-strike recovery so a revenant parked on something does not grind it
  /// down every frame.
  double strikeCooldown = 0;

  /// 1 while the world holds; drains once the caster is gone.
  double fade = 1.0;

  bool get dead => life <= 0 || fade <= 0;
}

/// One piece of ground cover a world grows on the map: a sprout under a Plant
/// world, a cinder under Fire, a rime shard under Ice.
///
/// The tint and the particle storm were never enough on their own — they sit
/// in FRONT of the fight rather than in it, so a world could be running and the
/// ground underneath still looked like every other map. These come up out of
/// the floor, stand a few seconds and go back down.
class _MysticFlora {
  _MysticFlora({
    required this.position,
    required this.ownerSlot,
    required this.element,
    required this.size,
    required this.seed,
    required this.life,
  });

  final Offset position;
  final int ownerSlot;
  final String element;
  final double size;
  final double seed;

  final double life;
  double age = 0;

  /// 0 → 1 → 0 across its life: sprouts, stands, withers. Nothing belonging to
  /// a world should pop in or blink out.
  double get bloom {
    final f = (age / life).clamp(0.0, 1.0);
    if (f < 0.18) return f / 0.18;
    if (f > 0.76) return ((1.0 - f) / 0.24).clamp(0.0, 1.0);
    return 1.0;
  }

  bool get dead => age >= life;
}

/// An Air world's tornado, walking a circuit around the arena.
class _MysticTornado {
  _MysticTornado({
    required this.ownerSlot,
    required this.orbitRadius,
    required this.funnelRadius,
    required this.damage,
    required this.angle,
  });

  final int ownerSlot;

  /// How far out its circuit runs from the orb.
  final double orbitRadius;
  final double funnelRadius;
  final double damage;

  /// Where it currently is on that circuit, in radians.
  double angle;

  /// Radians per second around the circuit. Slow enough to be tracked and
  /// planned around — the whole difference between this and a static hold is
  /// that the player can know where it will be.
  final double travelSpeed = 0.22;

  Offset position = Offset.zero;
  double phase = 0;
  double dt = 0;
  double grind = 0;
  double fade = 1.0;
}

/// A Water world's whirlpool, turning on the orb.
class _MysticMaelstrom {
  _MysticMaelstrom({
    required this.ownerSlot,
    required this.anchor,
    required this.radius,
    required this.damage,
  });

  final int ownerSlot;

  /// Where it turns. Fixed at the cast, out in the middle-to-outer ring — a
  /// whirlpool that followed the orb would sit under the fight forever.
  final Offset anchor;
  final double radius;

  /// Per-grind damage, applied twice a second to everything in the water.
  final double damage;

  Offset centre = Offset.zero;

  /// Radians per second at the eye. Slow on purpose — the brief is that bodies
  /// drift around, and a fast spin would read as a blender rather than as a
  /// current.
  final double spinRate = 0.55;

  /// Drawing phase, and the frame delta the carry step works from.
  double phase = 0;
  double dt = 0;

  /// Countdown between grinds.
  double grind = 0;

  double fade = 1.0;
}

/// A crack a Lava world has opened across the arena.
///
/// A jagged polyline rather than a zone: the player has to be able to see
/// exactly where the edge is, because the whole mechanic is whether something
/// heavy steps over it.
class _MysticFissure {
  _MysticFissure({
    required this.ownerSlot,
    required this.points,
    required this.seed,
  });

  final int ownerSlot;
  final List<Offset> points;
  final double seed;

  /// Per-crack recovery, so a boss parked on one does not call meteors every
  /// frame it stands there.
  double cooldown = 0;

  /// Countdown to the crack's next look for a heavy body on it. Bodies are
  /// looked for a few times a second rather than every frame: a crossing
  /// takes a heavy body longer than that.
  double scan = 0;

  /// The middle of the crack, and how far its ends reach from there, so the
  /// look for bodies on it is one query round the middle.
  late final Offset mid = points[points.length ~/ 2];
  late final double reach = points.fold(
    0.0,
    (r, p) => max(r, (p - mid).distance),
  );

  /// Counts down after a crossing, brightening the crack that just broke.
  double flare = 0;

  double fade = 1.0;

  /// Whether [at] is within [slack] of any segment of the crack.
  bool touches(Offset at, double slack) {
    final slackSq = slack * slack;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ab = b - a;
      final lenSq = ab.dx * ab.dx + ab.dy * ab.dy;
      if (lenSq < 0.0001) continue;
      final ap = at - a;
      // Projection clamped to the segment, so the ends of a crack do not
      // reach on forever the way an infinite line would.
      final t = ((ap.dx * ab.dx + ap.dy * ab.dy) / lenSq).clamp(0.0, 1.0);
      final closest = a + ab * t;
      final d = at - closest;
      if (d.dx * d.dx + d.dy * d.dy <= slackSq) return true;
    }
    return false;
  }
}

/// One of the meteors a broken crack throws up. Aimed at a place, not a body.
class _MysticMeteor {
  _MysticMeteor({
    required this.impact,
    required this.ownerSlot,
    required this.damage,
    required this.seed,
    required this.remaining,
  });

  final Offset impact;
  final int ownerSlot;
  final double damage;
  final double seed;

  double remaining;
  static const double fallTime = 0.85;

  /// 0 → 1 as it comes down.
  double get progress =>
      (1.0 - (remaining / fallTime)).clamp(0.0, 1.0).toDouble();
}

/// The mark a meteor leaves, cooling.
class _MysticScorch {
  _MysticScorch({required this.at, required this.seed});

  final Offset at;
  final double seed;
  double age = 0;
  static const double maxAge = 4.5;

  bool get dead => age >= maxAge;
}

/// The ring a Steam world's vent throws out. Visual only — the shove itself is
/// applied the instant it blows.
class _MysticVent {
  _MysticVent({required this.centre, required this.radius});

  final Offset centre;
  final double radius;
  double age = 0;
  static const double maxAge = 1.15;

  bool get dead => age >= maxAge;
}

/// A shard dropped by something that died inside a Crystal world.
class _MysticCrystal {
  _MysticCrystal({
    required this.position,
    required this.ownerSlot,
    required this.seed,
    required this.value,
  });

  Offset position;
  final int ownerSlot;
  final double seed;

  /// How much alchemical meter collecting it is worth.
  final double value;

  double life = 14.0;
  double fade = 1.0;

  bool get dead => life <= 0 || fade <= 0;
}

/// A Light Mystic's star, hanging outside the arena and getting closer to
/// going off. When it does, everything the player owns goes back to full.
class _MysticStar {
  _MysticStar({
    required this.ownerSlot,
    required this.position,
    required this.period,
  });

  final int ownerSlot;
  final Offset position;

  /// Seconds from dark to dawn.
  final double period;

  /// 0 → 1 across [period]. The whole ability is watching this fill.
  double charge = 0;

  /// Counts down through the flare, so dawn is something that happens rather
  /// than a number quietly changing.
  double flare = 0;

  double fade = 1.0;

  bool get dead => fade <= 0;
}

/// The sky gathering over a spot before it strikes it.
///
/// The mark commits to a PLACE, not a body: the roll picks somewhere, and
/// whatever is standing there when the bolt lands is what it hits. That is
/// what turns a fixed cadence into something the player can play around,
/// rather than a turret that fires on a timer.
class _MysticCharge {
  _MysticCharge({
    required this.at,
    required this.ownerSlot,
    required this.seed,
  });

  final Offset at;
  final int ownerSlot;
  final double seed;

  double remaining = windUp;
  static const double windUp = 0.62;

  /// 0 → 1 across the wind-up.
  double get progress =>
      (1.0 - (remaining / windUp)).clamp(0.0, 1.0).toDouble();
}

/// One bolt out of a Lightning Mystic's storm — a visual only; the damage is
/// dealt the instant it falls.
class _MysticBolt {
  _MysticBolt({required this.strike, required this.seed, required this.onBoss});

  final Offset strike;
  final double seed;

  /// Bolts that land on a boss flash harder, because that is the one that
  /// bought the player a second of stillness.
  final bool onBoss;

  double life = maxLife;
  static const double maxLife = 0.36;

  bool get dead => life <= 0;
}

/// The ring an Earth Mystic's quake throws out. Visual only.
class _MysticQuake {
  _MysticQuake({required this.centre, required this.radius});

  final Offset centre;
  final double radius;
  double age = 0;
  static const double maxAge = 1.05;

  bool get dead => age >= maxAge;
}

/// A patch of the trail a Poison Mystic's world lays under the ship.
///
/// The ship is the one thing on the field the player steers directly, so this
/// is the only world whose shape they author themselves — where the poison
/// goes is wherever they chose to fly.
class _MysticPool {
  _MysticPool({
    required this.position,
    required this.ownerSlot,
    required this.radius,
    required this.damage,
    required this.seed,
    required this.life,
  });

  final Offset position;
  final int ownerSlot;
  final double radius;
  final double damage;
  final double seed;

  double life;
  double fade = 1.0;

  /// Seconds since the ship laid it, so a patch can spread into existence.
  double age = 0;

  /// Per-pool tick gate so a patch does not damage every frame.
  double tick = 0;

  /// How far this patch has spread, 0 → 1 over [spreadTime].
  ///
  /// A spill does not arrive finished. Patches used to appear at full size and
  /// full opacity the instant the ship passed, which read as objects being
  /// dropped behind it rather than as something running out across the floor.
  static const double spreadTime = 0.55;
  double get spread =>
      spreadTime <= 0 ? 1.0 : (age / spreadTime).clamp(0.0, 1.0);

  /// Eased so it rushes out and settles, the way a liquid does.
  double get spreadEase {
    final t = spread;
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  bool get dead => life <= 0 || fade <= 0;
}

/// The hole a Dark Mystic tears in the north of the arena.
///
/// It does not kill: it drags, swallows, and spits whatever it swallowed back
/// out at the rim. That makes Dark the one Mystic that buys distance rather
/// than damage — the northern approach stops existing while it is open.
class _MysticMaw {
  _MysticMaw({
    required this.position,
    required this.ownerSlot,
    required this.radius,
    required this.damage,
  });

  final Offset position;
  final int ownerSlot;

  /// How far the pull reaches. The event horizon is a small fraction of it.
  final double radius;
  final double damage;

  double spin = 0;

  /// Ramps 0 → 1 as it opens, so the hole tears rather than appearing.
  double open = 0;

  double fade = 1.0;

  bool get dead => fade <= 0;

  double get horizon => radius * 0.17;
}

/// One of the two vines a Plant Mystic grows. They are the cast: one lashes
/// what comes close, one spits thorns at what does not.
class _MysticVine {
  _MysticVine({
    required this.root,
    required this.ownerSlot,
    required this.lashes,
    required this.damage,
    required this.reach,
    required this.seed,
  });

  final Offset root;
  final int ownerSlot;

  /// true = the lasher, false = the spitter. Two jobs so a grove covers both
  /// ranges instead of being one turret twice.
  final bool lashes;
  final double damage;

  /// Melee sweep radius for the lasher; firing range for the spitter.
  final double reach;
  final double seed;

  /// 0 → 1 while it grows out of the ground.
  double growth = 0;
  double cooldown = 0;

  /// Counts 1 → 0 through a lash, driving the whip in the renderer.
  double swing = 0;
  double aimAngle = -pi / 2;
  double fade = 1.0;

  bool get dead => fade <= 0;
}

/// The world a Mystic makes: viewport tint plus an ambient particle storm.
///
/// It used to run on a fixed eighteen-second timer, which made the world a
/// long buff. It lasts as long as its caster is alive and deployed now — the
/// same rule the Fire ember field follows, and the point of the family: a
/// Mystic is the single-slot pick, so choosing one means choosing what the map
/// IS, not buying eighteen seconds of weather.
class _MysticEnvironment {
  _MysticEnvironment({required this.element, required this.ownerSlot});

  final String element;

  /// Whose world this is. It holds while that companion is alive and out.
  final int ownerSlot;

  /// Seconds since the cast — drives the ramp in.
  double age = 0;

  /// Counts down once the caster is gone, so the world visibly closes rather
  /// than being switched off.
  double closing = -1;

  static const double fadeIn = 0.6;
  static const double fadeOut = 1.8;

  bool get dead => closing >= 0 && closing <= 0;

  /// Ramps up at the cast, holds for as long as the caster stands, then closes.
  double get envelope {
    if (closing >= 0) {
      return (closing / fadeOut).clamp(0.0, 1.0).toDouble();
    }
    if (age < fadeIn) return (age / fadeIn).clamp(0.0, 1.0).toDouble();
    return 1.0;
  }

  /// Begins the close. Harmless to call repeatedly.
  void beginClosing() {
    if (closing < 0) closing = fadeOut * envelope;
  }
}

/// Transient Kin auto-attack laser beam — a thin line from kin to
/// target that lingers briefly then fades. Cheap render struct.
/// A Spirit payload's pending echo: the same hit, repeated at reduced power
/// after a delay. Holds the body directly because the echo is meaningless if
/// that body is already gone.
class _MasteryEcho {
  _MasteryEcho({
    required this.slotIndex,
    required this.damage,
    required this.delay,
    this.enemy,
    this.boss,
  });

  final int slotIndex;
  final double damage;
  double delay;
  final CosmicSurvivalEnemy? enemy;
  final SurvivalBoss? boss;
}

/// A Thousand Cuts volley waiting out its 0.2s beat. Holds the body's id
/// rather than the body, because the whole point is that the first volley may
/// already have killed it — in which case the bonus fires where the Pip is
/// looking instead of chasing a corpse.
class _PipBonusVolley {
  _PipBonusVolley({
    required this.slotIndex,
    required this.targetId,
    required this.delay,
  });

  final int slotIndex;
  final int targetId;
  double delay;
}

/// A Horn special as Juggernaut sees it the moment it goes off: whether it is
/// the second run, what that run is worth, how much more ground it covers,
/// and whether Full Weight keeps the element's effect at full strength.
typedef _HornRun = ({
  bool second,
  double power,
  double coverage,
  bool fullWeight,
});

/// How many times one Kin+Light escort orb may strike the same body. Its
/// contact is incidental to escorting, so once: the orb passes through.
const int kKinLightEscortHitsPerBody = 1;

/// What the rest of a Let special's crater takes in survival, as a share of
/// the meteor: less than the shared [kLetSkyfallSplashShare] open space and
/// the battle use, because survival's meteor is aimed at the crowd and its
/// element effects reach out past the crater's rim
/// (CosmicAbilityRuntime.kLetRimReach). The rock stops growing past
/// Potential 80 ([kLetImpactDamping]) while the waves keep toughening, so at
/// this share the crater still clears chaff at Potential 20 to 80 and by
/// Potential 100 + Enhancement 10 only the smallest bodies (2026-10-20).
const double kLetSurvivalCraterShare = 0.42;

/// How often one Mane+Light ward ring may strike a boss it is turning
/// through: the cadence a zone ticks a boss standing in it. A ring meets an
/// ordinary body on every contact tick, which only works because the body
/// dies; a boss on that clock would take sixty hits a second.
const double kManeLightBossRehitSeconds = 0.35;

/// What a Pip special dart's damage is multiplied by in survival: the crowd
/// payload a bred Pip's ricochet carries, by the caster's Beauty.
///
/// Pip is survival's late bloomer (the 2026-10-20 family rebuild: weak early,
/// threading crowds late). A special dart carries the damage a kill did not
/// need on to the next body (PipRicochet), so how far it threads a horde is
/// its damage over the bodies' health. On its own damage that came to two or
/// three bodies at every band, because the waves a Pip is bred to face toughen
/// as fast as its SPECIAL grows (a Potential-80 dart of about 130 against
/// wave 101's 47-health wisps). The payload is what grows instead: 1 for a
/// Pip of Beauty [kPipPayloadFrom] and below (about Potential 20), rising
/// with the square of the Beauty past it, to [kPipPayloadCeiling] by about
/// Potential 80, where a dart threads most of [PipRicochet.maxContacts].
/// Measured on the family probe (test/family_balance_survival_test.dart,
/// 105 parties): Pip's share of its party's damage went from 4% / 8% / 3% /
/// 5% at P20 / P50 / P80 / P100+E10 to about 8% / 13% / 20% / 27%.
///
/// The crowd's alone: a boss takes the dart's own damage, and so do the
/// element riders built on it (Water's last splash, Poison's line), which
/// were tuned against the dart.
double pipSurvivalPayload(double beauty) {
  final over = max(0.0, beauty - kPipPayloadFrom);
  return min(kPipPayloadCeiling, 1.0 + kPipPayloadRate * over * over);
}

const double kPipPayloadFrom = 3.0;
const double kPipPayloadRate = 1.4;
const double kPipPayloadCeiling = 12.0;

/// What a Pip Earth dart's first kill hands back, as a share of the Pip's
/// special interval.
const double kPipEarthRefundShare = 0.08;

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
  final String? wingElement;
  final double width;
  double life;
  final double maxLife;

  _BeamFx({
    required this.start,
    required this.end,
    required this.color,
    required this.width,
    required this.life,
    this.wingElement,
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

  /// Wing+Spirit tethers its laser to the SHIP, which then fires its own beam
  /// at whatever is nearest. Same mechanism as the orb anchor.
  final bool anchorToShip;
  // Wing+Steam: the beam executes the first enemy it touches once, then
  // behaves as a normal damage beam.
  bool steamKillUsed;

  /// Where the beam landed on its last update, for the render pass to paint
  /// it from (null until it has fired). Visual only.
  Offset? drawEnd;

  /// Wing+Light: the beam this one refracted out of, or null for a beam the
  /// Wing cast. A refraction hunts its own body ([huntTarget]) rather than
  /// the nearest one, which is the body its parent is already on.
  final _ActiveWingBeam? refractedFrom;
  CosmicSurvivalEnemy? huntTarget;

  /// The body this beam aimed at on its last update.
  CosmicSurvivalEnemy? aimedAt;

  /// Where the body (or boss) it is aimed at stood on its last update, for
  /// the art: a sweeping beam runs on past it, and its heat pools there.
  Offset? focusAt;

  /// Focus: how long the beam has been held on [aimedAt], and so how hot its
  /// tick there is (WingBeamRules.heatAt).
  final WingBeamHeat heat = WingBeamHeat();

  /// Wing+Water: the ally the healing beam is on, or whether it is on the
  /// ship, as of its last update. Null and false while it has no one.
  CosmicSurvivalCompanion? aimedAlly;
  bool aimedAtShip = false;

  _ActiveWingBeam({
    required this.descriptor,
    required this.sourceSlotIndex,
    required this.origin,
    required this.angle,
    this.anchorToOrb = false,
    this.anchorToShip = false,
    this.refractedFrom,
    this.huntTarget,
  }) : life = anchorToOrb || anchorToShip
           ? WingBeamRules.coBeamLife(descriptor)
           : descriptor.duration,
       tickTimer = descriptor.tickInterval,
       chargeTimer = descriptor.chargeTime,
       // A refraction never refracts again.
       refractionsDone = refractedFrom != null ? 1 : 0,
       steamKillUsed = false;

  bool get dead => life <= 0;
  bool get isRefraction => refractedFrom != null;
  bool get isCoBeam => anchorToOrb || anchorToShip;
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

  /// Trails stop being laid at this many live companion projectiles. Slightly
  /// lower than the turret ceiling because trails are the denser of the two
  /// self-generating sources.
  static const int _trailProjectileCeiling =
      (_maxCompanionProjectiles * 0.60) ~/ 1;

  /// Turrets stop firing at this many live companion projectiles, leaving the
  /// rest of the list free for casts the player actually triggered.
  static const int _turretFireProjectileCeiling =
      (_maxCompanionProjectiles * 0.72) ~/ 1;
  static const int _maxEnemyProjectiles = 90;
  static const int _maxBossProjectiles = 110;
  /// 1.10, then 20% more (user, 2026-10-21: "make the ship 20% faster in
  /// survival").
  static const double _survivalShipSpeedMultiplier = 1.32;
  // Former collectible rewards used a 1.20 pickup value; direct grants are 20% lower.
  static const double _alchemyMeterGainMultiplier = 0.96;
  static const double _arenaShipPadding = 32.0;
  static const double _orbCoreRadius = 72.0;
  static const double _orbShieldRadius = 136.0;
  static const double _orbGravityRadius = 720.0;
  static const double _orbShipOrbitRadius = 270.0;
  double _idleOrbitRadius = _orbShipOrbitRadius;

  /// Simulation multiplier selected by the player. The screen pauses the
  /// engine for decisions, so those overlays never inherit fast-forward.
  double timeScale = 1.0;

  /// The fast-forward speed. Two was too fast to read a front and pick where
  /// to break it.
  static const double fastForwardTimeScale = 1.5;

  final List<CosmicPartyMember> party;
  final void Function(SoundCue cue)? onSound;
  final VoidCallback onGameOver;
  final VoidCallback? onWaveIntermission;
  final void Function(int clearedWave)? onWaveCleared;
  final void Function(SurvivalBoss boss)? onBossSpawn;
  final void Function(MysticSpecialCastEvent event)? onMysticSpecialCast;

  /// Fired on the run's first frame and as each new wave begins: the moment
  /// the run is worth keeping as it stands (survival_suspended_run.dart).
  final VoidCallback? onWaveCheckpoint;
  bool _checkpointDue = false;
  final SurvivalUpgradeState upgradeState;
  final SurvivalVisualQuality visualQuality;

  /// Family Mastery's combat event surface. Holds the run's immutable path
  /// snapshot and answers the cast/hit/kill questions mastery nodes are
  /// written against. Inert — and free — when nothing in the party has a path
  /// equipped. See survival_mastery_runtime.dart.
  final SurvivalMasteryRuntime mastery;

  /// A cosmic ship design id ('skin_phantom', …); null flies the standard
  /// hull.
  String? shipSkin;
  final ShipComponent _shipArt = ShipComponent(pos: Offset.zero);

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
  final CosmicSurvivalSpawner spawner;
  final List<CosmicSurvivalEnemy> enemies = [];
  SurvivalOutbreak? outbreak;
  SurvivalOutbreakKind? _previousOutbreak;

  SurvivalBoss? activeBoss;

  /// Floating damage numbers, shown on bosses only. Regular waves are crowd
  /// control — a number per contact tick across thirty enemies is noise.
  final DamageNumberField damageNumbers = DamageNumberField(bigThreshold: 60);
  // Additional bosses spawned on multi-boss waves. Updated/rendered/targeted
  // alongside [activeBoss]. Dead entries are pruned each wave cleanup.
  final List<SurvivalBoss> extraBosses = [];
  // By index: killing the primary promotes the next extra out of
  // [extraBosses], and area hits now reach bosses (2026-10-20), so a hit on
  // one extra can kill the primary while this walk is still going.
  Iterable<SurvivalBoss> get allLivingBosses sync* {
    final primary = activeBoss;
    if (primary != null && !primary.isDead) yield primary;
    for (var i = 0; i < extraBosses.length; i++) {
      final b = extraBosses[i];
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

  /// Beams and shockwaves — the commit phase of a body's signature action.
  /// See games/shared/enemy_action.dart.
  final List<SurvivalEnemyHazard> enemyHazards = [];

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

  /// Every party slot summoned at some point this run — for its mastery: a
  /// creature that went out earns more than one kept in reserve throughout.
  final Set<int> deployedCompanionSlots = {};
  final RunHealingStats healingStats = RunHealingStats();
  bool isGameOver = false;

  /// Seconds since the core gave out. The fight stops then, but the core
  /// coming apart (orb_art.dart) plays on over the stilled arena.
  double get coreFallTime => _coreFallT;
  double _coreFallT = 0;
  bool _started = false;
  final ValueNotifier<bool> detonationReadyNotifier = ValueNotifier(false);
  final ValueNotifier<double> detonationChargeNotifier = ValueNotifier(0);
  double _detonationTimer = 0;

  // Ship respawn: 30 s, and 6 s sooner for each Reinforced Hull.
  static const double _kShipRespawnBase = 30.0;
  static const double _kShipRespawnPerHull = 6.0;
  double get _shipRespawnDelay =>
      _kShipRespawnBase - powerUps.shipHullLevel * _kShipRespawnPerHull;
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

  double get alchemicalMeterMax =>
      CosmicSurvivalBalance.alchemicalMeterCapacity(spawner.currentWave);

  /// The meter as the arena shows it (eased toward the real value), 0..1:
  /// what the HUD's surge tube reads, so the two fill together.
  double get alchemicalMeterShown => _alchemicalMeterDisplayFrac;

  double _intermissionAlchemyGrantForWave(int wave, {required bool bossWave}) {
    if (wave <= 0) return 0;
    final base = bossWave ? 22.0 + wave * 1.25 : 8.0 + wave * 0.55;
    return base.clamp(6.0, bossWave ? 88.0 : 42.0);
  }

  void _grantIntermissionReward(int wave, {required bool bossWave}) {
    if (wave <= 0 || wave == _lastIntermissionRewardWave) return;
    _lastIntermissionRewardWave = wave;
    final grant = _intermissionAlchemyGrantForWave(wave, bossWave: bossWave);
    if (grant > 0 && !ship.isDead) {
      _grantAlchemy(grant * _alchemyMeterGainMultiplier);
    }
    // Past wave 10 a cleared wave gives back a growing share of the orb's
    // and the fielded team's health (CosmicSurvivalBalance.waveRestShare).
    // A boss wave gives back at least 7% and a 4% shield on top. The rest
    // comes whether or not the ship is down: it used to sit behind the
    // ship's gate, so a ship lost late in a wave cost the orb its rest too.
    final rest = CosmicSurvivalBalance.waveRestShare(wave);
    final orbRecovery = bossWave
        ? max(rest * orb.maxHp, max(10.0, orb.maxHp * 0.07))
        : rest * orb.maxHp;
    if (orbRecovery > 0) _healOrb(orbRecovery);
    if (bossWave) _grantOrbShield(max(12, (orb.maxHp * 0.04).round()));
    if (rest > 0) {
      for (final comp in activeCompanions.values) {
        if (comp.isDead) continue;
        comp.currentHp = min(
          comp.maxHp,
          comp.currentHp + (comp.maxHp * rest).round(),
        );
      }
    }
  }

  // Joystick input
  Offset? _dragTarget;
  Offset _joystickInput = Offset.zero;
  void setJoystickInput(Offset input) {
    // A pointer held before entering camera mode must not take control back.
    _joystickInput = autopilot ? Offset.zero : input;
  }

  // Background stars
  final ArenaSky _sky = ArenaSky();
  final ArenaNebula _nebula = ArenaNebula();
  final SurgeGrains _surgeGrains = SurgeGrains();

  /// The shield pulse's and the nova's fronts going out from the orb.
  final List<_OrbFront> _orbFronts = [];
  final ArenaRim _rim = ArenaRim();

  // VFX particles
  final _VfxPool _vfx = _VfxPool();
  final AbilityGrainBatch _vfxGrains = AbilityGrainBatch();
  final List<_BeamFx> _beamFx = [];
  final MaskTrapVisuals _maskTrapVisuals = MaskTrapVisuals();

  /// Running count of Pip+Mud trail puffs, refreshed on [_pipMudPuffScanTimer]
  /// rather than every emission — the budget only needs to be roughly right,
  /// and a full scan per puff per enemy would cost more than the puffs do.
  int _pipMudPuffCount = 0;
  double _pipMudPuffScanTimer = 0;

  /// Live ambient-particle count. Exposed so the particle budget can be
  /// asserted in tests — the pool is a shared resource every effect competes
  /// for, and the competition is invisible from outside without this.
  @visibleForTesting
  int get vfxParticleCount => _vfx.length;

  // Let meteor craters. One entry per landing, alive for a fraction of a
  // second. Kept as plain state rather than projectiles because nothing about
  // them interacts — they are purely the punch at the end of a descent. The
  // painter lives in the shared vfx module so cosmic and the dungeon draw the
  // identical landing.
  final List<LetSkyfallImpact> _letSkyfallImpacts = [];
  final List<LetFx> _letFx = [];
  final List<HornFx> _hornFx = [];
  int _timeDilationWave = 0;
  double _timeDilationTimer = 0;
  double _timeDilationSlowFactor = 1.0;

  // HP fraction cache for companion panel
  final Map<int, double> companionHpFraction = {};
  final Map<int, double> companionSpecialCooldown = {};

  // Transient Kin laser beam flashes. Drawn after the ship for one
  // brief moment then garbage-collected. Tiny struct: origin, end,
  // life, color.
  final List<KinLaserBeam> _kinLaserBeams = [];

  // Active Mystic environment overlays. Each entry tracks one cast's
  // worth of "the world is now this element" — viewport tint +
  // ambient particle storm. Multiple casts stack visually.
  final List<_MysticEnvironment> _mysticEnvironments = [];

  /// Live Fire-Mystic embers, across every caster. Deliberately its OWN list
  /// and not part of companionProjectiles: that list is capped at 220 and
  /// shared with every trap, ward and pool in the game, and a permanent field
  /// of forty embers would quietly eat a fifth of it forever.
  final List<_MysticEmber> _mysticEmbers = [];
  static const int _maxMysticEmbers = 90;

  final List<_MysticRevenant> _mysticRevenants = [];
  static const int _maxMysticRevenants = 16;

  /// Empties the Spirit world's revenant pool, so a test can check the tier
  /// gate without depending on how full a dense wave has already made it.
  @visibleForTesting
  void debugClearMysticRevenants() => _mysticRevenants.clear();

  final List<_MysticVine> _mysticVines = [];
  final List<_MysticMaw> _mysticMaws = [];
  final List<_MysticBolt> _mysticBolts = [];
  final List<_MysticCharge> _mysticCharges = [];
  final List<_MysticCrystal> _mysticCrystals = [];
  static const int _maxMysticCrystals = 30;
  final List<_MysticStar> _mysticStars = [];
  final List<_MysticVent> _mysticVents = [];
  final List<_MysticFissure> _mysticFissures = [];
  final List<_MysticMeteor> _mysticMeteors = [];
  static const int _maxMysticMeteors = 48;
  final List<_MysticScorch> _mysticScorches = [];
  final List<_MysticMaelstrom> _mysticMaelstroms = [];
  final List<_MysticTornado> _mysticTornados = [];
  final List<_MysticQuake> _mysticQuakes = [];
  final List<_MysticPool> _mysticPools = [];
  static const int _maxMysticPools = 26;

  final List<_MysticFlora> _mysticFlora = [];
  static const int _maxMysticFlora = 22;
  double _mysticFloraTimer = 0;

  /// Cadence for the worlds that happen on a clock rather than on contact —
  /// Lightning's strikes and Earth's quakes. Keyed by the slot that owns them.
  final Map<int, double> _mysticClock = {};

  /// Earth worlds whose quake lead-in has already sounded this beat: the cue
  /// carries the build AND the break, so it starts 1.6 s early, once.
  final Set<int> _mysticQuakeCued = {};

  /// Where the ship was when a Poison world last laid a patch, so the trail is
  /// spaced by distance flown rather than by frames elapsed.
  final Map<int, Offset> _mysticPoisonLastDrop = {};

  /// Elements whose Mystic cast stops being a spell and becomes the map.
  ///
  /// A world is lit once per deployment, holds for as long as its caster is
  /// alive and out, and dies with it. The rest of the roster still throws the
  /// projectile ultimate from the shared ability table.
  static const Set<String> _mysticWorldElements = {
    'Fire',
    'Spirit',
    'Blood',
    'Dark',
    'Plant',
    'Lightning',
    'Poison',
    'Mud',
    'Earth',
    'Ice',
    'Crystal',
    'Light',
    'Dust',
    'Steam',
    'Lava',
    'Water',
    'Air',
  };

  /// Slots whose Mystic has already cast this deployment. A Mystic's world is
  /// cast ONCE — the ability comes back only by recalling and redeploying it,
  /// which costs the field.
  final Set<int> _mysticSpentSlots = <int>{};
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

  /// Per-caster ceiling on heals that grow with bodies touched (Mane Blood,
  /// the Wing leech beams); see [HealCeiling].
  final HealCeiling _healCeiling = HealCeiling();
  // Mask+Spirit ship-collectible wisps. Persist independently from
  // companion projectiles so they survive their parent caster.
  final List<MaskSpiritWisp> _spiritWisps = [];
  // Per-companion wisp counter — once >= threshold, fires the nuke.
  // Mask+Spirit nuke screen-wash flash. Bumped to 1.0 on nuke fire,
  // decayed per frame, read by the render pass to draw the screen
  // wash + expanding ring punctuation.
  double _maskSpiritNukeFlash = 0;
  Offset _maskSpiritNukeOrigin = Offset.zero;
  final _ProjectileControlBuckets _projectileControlBuckets =
      _ProjectileControlBuckets();
  // Flat enemy grid: a window of cells around the orb, filled by counting
  // sort (stable, so each cell keeps list order). Replaces a Map of buckets
  // whose lookups and rebuilds were ~18% of a 2,000-body device frame.
  int _gridMinCx = 0;
  int _gridMinCy = 0;
  int _gridCols = 0;
  int _gridRows = 0;
  Int32List _gridCellStart = Int32List(1);
  Int32List _gridCursor = Int32List(1);
  Int32List _gridEnemyCell = Int32List(0);
  List<CosmicSurvivalEnemy?> _gridItems = List.filled(0, null);
  final List<CosmicSurvivalEnemy> _gridOverflow = [];
  bool _gridEmpty = true;
  int _spatialQueries = 0;
  int _spatialCandidates = 0;
  double _spatialMetricsTimer = 0;
  final Paint _shipProjectilePaint = Paint()..color = const Color(0xFF00E5FF);
  final Paint _shipProjectileGlowPaint = Paint()
    ..color = const Color(0xFF00E5FF).withValues(alpha: 0.2);
  final Paint _companionProjCorePaint = Paint();

  /// Species-type scale factors for companion sprites. Shared with open cosmic
  /// — see [kCompanionSpeciesScale] in cosmic_data.dart.
  static const Map<String, double> _companionSpeciesScale =
      kCompanionSpeciesScale;

  @override
  bool isLoaded = false;

  /// World-space offset added to the camera, which otherwise sits on the
  /// ship. A manual pan anchors the view in world space; previews may also
  /// assign a fixed ship-relative offset.
  Offset _cameraPanOffset = Offset.zero;
  Offset? _freeCameraCentre;
  Offset get cameraPanOffset => _freeCameraCentre == null
      ? _cameraPanOffset
      : _freeCameraCentre! - ship.position;
  set cameraPanOffset(Offset value) {
    _freeCameraCentre = null;
    _cameraPanOffset = value;
  }

  /// Whether the ship is drawn. Always in a run; the ability preview hides
  /// it when the special being shown has nothing to do with it.
  bool renderShip = true;

  double get cameraZoom => _currentZoom;

  /// Jump the camera to [zoom] with no animation.
  void setCameraZoom(double zoom) {
    _cameraGlideZooms = false;
    _currentZoom = zoom;
    _zoomAnimFrom = zoom;
    _zoomAnimTo = zoom;
    _zoomAnimComplete = true;
  }

  /// Pinch bounds. The arena is the larger of its fixed radius and the
  /// visible view, so zooming out past the point where the view covers the
  /// arena would grow the arena itself. The limit is exactly that point: the
  /// whole rim in frame, and not a unit more. Note the horde caps were
  /// device-measured at the presets (0.5-0.75); fully zoomed out draws every
  /// body at once, so watch frame time there before raising the caps.
  double get cameraZoomMin =>
      (max(size.x, size.y) * _arenaViewShare / _arenaFixedRadius).clamp(
        0.2,
        _zoomOuter,
      );
  double get cameraZoomMax => 1.0;

  @protected
  double cameraGestureStartZoom = _zoomBase;

  void beginCameraGesture() {
    cameraGestureStartZoom = _currentZoom;
    setCameraZoom(_currentZoom);
  }

  /// One step of a drag or pinch on the arena. [panDelta] is in screen
  /// pixels; [scale] is the pinch's total scale since the gesture began.
  void cameraGesture({
    required Offset panDelta,
    required double scale,
    Offset? focalPoint,
  }) {
    if (!autopilot || !scale.isFinite || scale <= 0) return;
    final oldZoom = _currentZoom;
    final centre = ship.position + cameraPanOffset;
    final zoom = (cameraGestureStartZoom * scale).clamp(
      cameraZoomMin,
      cameraZoomMax,
    );
    final focalOffset =
        (focalPoint ?? Offset(size.x / 2, size.y / 2)) -
        Offset(size.x / 2, size.y / 2);
    // Keep the world under the fingers stationary during a pinch, and anchor
    // free-pan in world space rather than to the orbiting ship.
    _freeCameraCentre = clampCameraCentre(
      centre - panDelta / oldZoom + focalOffset * (1 / oldZoom - 1 / zoom),
    );
    setCameraZoom(zoom);
  }

  /// Keeps a camera centre within a little of the arena rim.
  @protected
  Offset clampCameraCentre(Offset centre) {
    final fromOrb = centre - orb.position;
    final limit = _arenaRadius + 80;
    if (fromOrb.distance <= limit) return centre;
    return orb.position + fromOrb / fromOrb.distance * limit;
  }

  /// Back to the ship, at the zoom the player flies at.
  void recenterCamera() {
    cameraPanOffset = Offset.zero;
    _startZoomAnimation(_flyingZoom);
  }

  /// A zoom the player locked in camera mode, flown at instead of the run's
  /// preset (user, 2026-10-21: "can we add a way to lock camera when zooming
  /// out? So I can fly around zoomed out"); null when unlocked. Zoomed far
  /// out, every body in the horde is drawn at once, past the zooms the horde
  /// caps were measured at on the Fold.
  double? _lockedZoom;
  final ValueNotifier<bool> _zoomLockState = ValueNotifier(false);
  ValueListenable<bool> get zoomLockState => _zoomLockState;
  bool get zoomLocked => _zoomLockState.value;

  /// Locks the zoom the camera has now ([on]), or goes back to the preset.
  void setZoomLock(bool on) {
    _lockedZoom = on ? _currentZoom : null;
    _zoomLockState.value = on;
    if (!on && !autopilot) _startZoomAnimation(_flyingZoom);
  }

  /// The zoom the camera follows the flying ship at.
  double get _flyingZoom => _lockedZoom ?? _zoomPresets[_zoomLevelIndex];

  /// Camera mode: ship orbits automatically until the player explicitly exits.
  /// One observable state drives the HUD, gestures, and joystick together.
  final ValueNotifier<bool> _autopilotState = ValueNotifier(false);
  ValueListenable<bool> get autopilotState => _autopilotState;
  bool get autopilot => _autopilotState.value;

  void setAutopilot(bool on) {
    if (autopilot == on || !isLoaded || isGameOver) return;
    _joystickInput = Offset.zero;
    _dragTarget = null;
    if (on) {
      _rememberCurrentOrbitRadius();
      _startZoomAnimation(_zoomOuter.clamp(cameraZoomMin, cameraZoomMax));
    } else {
      recenterCamera();
    }
    _autopilotState.value = on;
  }

  double get camX => _cameraCentreX - size.x / (2 * _currentZoom);
  double get camY => _cameraCentreY - size.y / (2 * _currentZoom);

  /// The point the camera looks at: the ship (plus any pan), or — while the
  /// entrance holds it — the core, gliding from one to the other.
  double get _cameraCentreX {
    final follow = ship.position.dx + cameraPanOffset.dx;
    if (_cameraGlide >= 1) return follow;
    return orb.position.dx + (follow - orb.position.dx) * _cameraGlide;
  }

  double get _cameraCentreY {
    final follow = ship.position.dy + cameraPanOffset.dy;
    if (_cameraGlide >= 1) return follow;
    return orb.position.dy + (follow - orb.position.dy) * _cameraGlide;
  }

  // == The entrance ==========================================================
  //
  // The lobby carries its core into the run (survival_orb_entrance.dart). The
  // run is built held, the camera on the core at [entranceZoom]; while the
  // arena fades in, the lobby's overlay draws the core through
  // [paintCorePresentation] and the run leaves its own out
  // ([entranceCoreHidden]). Then the overlay steps aside in the same frame
  // the run draws the core again — same place, size and phase
  // ([alignCorePresentation]) — and the camera glides out to the ship.

  /// The zoom a run opens at, and the zoom the entrance holds the core at.
  static const double entranceZoom = _introZoomStart;

  /// The core's radius, in world units.
  static const double coreRadius = _orbCoreRadius;

  /// The radius of the field's innermost lane: the ship's orbit.
  static const double coreFieldOrbit = _orbShipOrbitRadius;

  /// While true the run draws no core, field or readings: the entrance
  /// overlay is drawing them in the same place.
  bool entranceCoreHidden = false;

  /// Added to the run's clock wherever the core is drawn, so the run picks
  /// up the lobby core's turning where it left off.
  double _coreClockOffset = 0;

  bool _cameraHeldOnCore = false;

  /// 0: the camera on the core; 1: following the ship.
  double _cameraGlide = 1;
  double _cameraGlideT = 0;
  double _cameraGlideZoomTo = _zoomBase;
  bool _cameraGlideZooms = false;
  static const double _cameraGlideSeconds = 1.6;

  /// The clock the core is drawn at.
  double get corePresentationTime => stats.timeElapsed + _coreClockOffset;

  /// How far a Celestial core is through the wait for its next heal.
  double get _coreBeat => orb.skin == OrbBaseSkin.celestialOrb
      ? (_celestialHealTimer / 8.0).clamp(0.0, 1.0)
      : 1;

  /// Holds the camera on the core at [entranceZoom] until
  /// [releaseCameraToShip]. Call after [startGame].
  void holdCameraOnCore() {
    setCameraZoom(entranceZoom);
    _cameraHeldOnCore = true;
    _cameraGlide = 0;
    _cameraGlideZooms = false;
  }

  /// The core is to carry on from [time] (and, for a Celestial core, from
  /// [beat] through its heal wait), as the lobby was last drawing it.
  void alignCorePresentation({required double time, required double beat}) {
    _coreClockOffset = time - stats.timeElapsed;
    if (orb.skin == OrbBaseSkin.celestialOrb) {
      _celestialHealTimer = beat.clamp(0.0, 1.0) * 8.0;
    }
  }

  /// Lets the camera go: it glides from the core to the ship, and from
  /// [entranceZoom] out to the run's zoom, easing in and out.
  void releaseCameraToShip() {
    if (!_cameraHeldOnCore) return;
    _cameraHeldOnCore = false;
    _cameraGlideT = 0;
    _cameraGlideZoomTo = _zoomPresets[_zoomLevelIndex];
    _cameraGlideZooms = true;
  }

  void _updateCameraGlide(double dt) {
    if (_cameraGlide >= 1 || _cameraHeldOnCore) return;
    _cameraGlideT += dt;
    final x = (_cameraGlideT / _cameraGlideSeconds).clamp(0.0, 1.0);
    final e = x * x * x * (x * (x * 6 - 15) + 10);
    _cameraGlide = e;
    if (_cameraGlideZooms) {
      _currentZoom = entranceZoom + (_cameraGlideZoomTo - entranceZoom) * e;
      _zoomAnimFrom = _currentZoom;
      _zoomAnimTo = _currentZoom;
    }
    if (x >= 1) {
      _cameraGlide = 1;
      if (_cameraGlideZooms) setCameraZoom(_cameraGlideZoomTo);
      _cameraGlideZooms = false;
    }
  }

  /// The core as the run draws it — its field, the core, and its readings
  /// at [readings] strength — centred on the canvas origin in world units.
  void paintCorePresentation(Canvas canvas, {double readings = 1}) {
    _paintCoreField(canvas);
    _paintCoreBody(canvas);
    if (readings <= 0) return;
    if (readings >= 1) {
      _paintCoreReadings(canvas);
      return;
    }
    canvas.saveLayer(
      Rect.fromCircle(center: Offset.zero, radius: _orbShieldRadius + 40),
      Paint()..color = Color.fromRGBO(0, 0, 0, readings),
    );
    _paintCoreReadings(canvas);
    canvas.restore();
  }

  final Random _rng;

  CosmicSurvivalGame({
    required this.party,
    required this.onGameOver,
    Random? random,
    this.onSound,
    this.onWaveIntermission,
    this.onWaveCleared,
    this.onBossSpawn,
    this.onMysticSpecialCast,
    this.onWaveCheckpoint,
    this.shipSkin,
    this.visualQuality = SurvivalVisualQuality.performance,
    SurvivalUpgradeState? upgradeState,
    SurvivalFamilyMasterySnapshot? masterySnapshot,
  }) : upgradeState = upgradeState ?? SurvivalUpgradeState(),
       mastery = SurvivalMasteryRuntime(snapshot: masterySnapshot),
       _rng = random ?? Random(),
       spawner = CosmicSurvivalSpawner(random: random);

  Offset worldToScreen(Offset world) => Offset(
    (world.dx - camX) * _currentZoom,
    (world.dy - camY) * _currentZoom,
  );

  /// Whether a world point is inside the visible area, with [margin] world
  /// units of slack. Used to skip ambient work for things off camera.
  bool _isOnScreen(Offset world, double margin) {
    final viewW = size.x / _currentZoom;
    final viewH = size.y / _currentZoom;
    return world.dx >= camX - margin &&
        world.dx <= camX + viewW + margin &&
        world.dy >= camY - margin &&
        world.dy <= camY + viewH + margin;
  }

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

  @visibleForTesting
  double get debugArenaRadius => _arenaRadius;

  static const double _arenaFixedRadius = 1140.0;
  static const double _arenaViewShare = 0.54;
  double get _arenaRadius => max(
    _arenaFixedRadius,
    max(size.x / _currentZoom, size.y / _currentZoom) * _arenaViewShare,
  );

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
    // The ability particle grain (ability_grains.dart), built off the frame
    // with toImage; particles draw as plain discs until it lands.
    AbilityGrainSprite.ensureLoaded().ignore();
    ensureSurvivalSwarmAtlas().ignore();
    final skinDef = kOrbBases.firstWhere(
      (d) => d.skin == upgradeState.equippedSkin,
      orElse: () => kOrbBases.first,
    );
    orb = CosmicSurvivalOrb(
      position: const Offset(0, 0),
      // 800, doubled from 400 when waves went from dozens of bodies to
      // hundreds. Note this does NOT make heavy hits twice as survivable:
      // orbContactDamage caps a hit at a SHARE of max HP (10%, 22% heavy), so
      // brutes and breakers still take the same number of impacts to finish
      // the orb. What it buys is room against chaff, whose raw damage is flat
      // — a leaked swarm now costs half of what it did.
      maxHp:
          ((800 + upgradeState.bonusOrbHp) *
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

    // Drawn from the run's own random, in the same order as ever, so a
    // seeded run plays out the same.
    for (var i = 0; i < 400; i++) {
      _sky.addStar(
        _rng.nextDouble() * 6000 - 3000,
        _rng.nextDouble() * 6000 - 3000,
        0.5 + _rng.nextDouble() * 2.0,
        0.5 + _rng.nextDouble() * 3.0,
        0.3 + _rng.nextDouble() * 0.7,
      );
    }

    isLoaded = true;
    // A continued run was set up before there was an orb or ship to put its
    // hit points back on.
    if (_pendingResume != null) _restoreResumedBodies();
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
    // Choosing a preset gives up a locked zoom.
    _lockedZoom = null;
    _zoomLockState.value = false;
    _zoomLevelIndex = clamped;
    _startZoomAnimation(_zoomPresets[_zoomLevelIndex]);
  }

  void cycleZoomLevel() {
    setZoomLevel((_zoomLevelIndex + 1) % _zoomPresets.length);
  }

  void _startZoomAnimation(double targetZoom) {
    // A zoom asked for mid-glide takes over from the glide's.
    _cameraGlideZooms = false;
    _zoomAnimFrom = _currentZoom;
    _zoomAnimTo = targetZoom;
    _zoomAnimTimer = 0;
    _zoomAnimComplete = false;
  }

  void startGame() {
    _started = true;
    // The path snapshot is locked for the run; the rhythm it drives is not,
    // so a second run in the same session starts from zero.
    mastery.reset();
    _maneMastery.clear();
    _pipMastery.clear();
    _pipBonusVolleys.clear();
    _letMastery.clear();
    _hornMastery.clear();
    _maskMastery.clear();
    _maskRearmQueue.clear();
    _wingMastery.clear();
    _kinMastery.clear();
    _unbrokenKin.clear();
    _mysticMastery.clear();
    _masteryEchoes.clear();
    _shipBlessingTimer = 0;
    _shipBlessingPerSecond = 0;
    _startZoomAnimation(_zoomPresets[_zoomLevelIndex]);
    spawner.startFirstWave();
    _checkpointDue = true;
  }

  // == Suspend and continue ================================================

  /// Set by [resumeRun] until the orb and ship exist to take its hit points.
  SuspendedSurvivalRun? _pendingResume;

  /// The run as it stands, to keep (survival_suspended_run.dart). Taken as a
  /// wave begins, it is that wave's checkpoint; taken mid-wave, it is only
  /// read for its hit points ([SuspendedSurvivalRun.leftAt]).
  SuspendedSurvivalRun captureSuspendedRun({int? savedAtMs}) {
    final slots = <SuspendedSlotHealth>[];
    for (var i = 0; i < party.length; i++) {
      final comp = activeCompanions[i];
      final dead =
          defeatedCompanionSlots.contains(i) || (comp?.isDead ?? false);
      final hp = dead
          ? 0.0
          : comp != null
          ? comp.hpPercent
          : (companionHpFraction[i] ?? 1.0).clamp(0.0, 1.0);
      slots.add(SuspendedSlotHealth(slot: i, hp: hp, dead: dead));
    }
    final runStats = companionRunStats.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final tethered = tetheredCompanionSlot;
    return SuspendedSurvivalRun(
      savedAtMs: savedAtMs ?? DateTime.now().millisecondsSinceEpoch,
      wave: max(1, spawner.currentWave),
      picks: [
        for (final applied in powerUps.history)
          SuspendedPick(
            id: applied.def.id,
            targetSlot: applied.targetSlot,
            targetName: applied.targetName,
          ),
      ],
      // A Phoenix held but no longer available has been spent.
      phoenixUsed: {
        for (var i = 0; i < party.length; i++)
          if (powerUps.has('phoenix_rebirth', slotIndex: i) &&
              !powerUps.companionHasPhoenixRebirth(i))
            i,
      },
      meter: alchemicalMeter,
      meterProgress: _alchemicalProgressPoints,
      orbMaxHp: orb.maxHp,
      orbHp: orb.currentHp,
      orbShield: orb.shieldHp,
      shipHp: ship.isDead ? 0 : ship.currentHp,
      shipDead: ship.isDead,
      shipRespawnElapsed: ship.isDead ? _shipRespawnTimer : 0,
      slots: slots,
      activeSlots: [
        for (final entry in activeCompanions.entries)
          if (!entry.value.isDead) entry.key,
      ],
      tetheredSlot: tethered != null && activeCompanions.containsKey(tethered)
          ? tethered
          : null,
      tetherMode: tetherModeEnabled,
      kills: stats.kills,
      score: stats.score,
      timeElapsed: stats.timeElapsed,
      healingToMons: healingStats.toMons,
      healingToShip: healingStats.toShip,
      healingToOrb: healingStats.toOrb,
      slotStats: [
        for (final MapEntry(key: slot, value: s) in runStats)
          SuspendedSlotStats(
            slot: slot,
            damageDealt: s.damageDealt,
            kills: s.kills,
            damageTaken: s.damageTaken,
            healingDone: s.healingDone,
            fieldSeconds: s.fieldSeconds,
          ),
      ],
      otherDamage: stats.otherDamage,
      shipDamage: stats.shipDamage,
      shipKills: stats.shipKills,
      deployedSlots: deployedCompanionSlots,
      party: party,
      equippedOrb: upgradeState.equippedSkin,
      guardianLevels: {
        for (final u in GuardianUpgrade.values)
          u: upgradeState.getGuardianLevel(u),
      },
      abilityLevels: {
        for (final a in BaseAbility.values) a: upgradeState.getAbilityLevel(a),
      },
      mastery: mastery.snapshot,
      shipSkin: shipSkin,
      rerollsLeft: powerUps.rerollsLeft,
      banishesLeft: powerUps.banishesLeft,
      banished: powerUps.banished,
      fusionParentsSeen: powerUps.seenFusionParents,
    );
  }

  /// Starts this run as [run] left it: in place of [startGame]. Build the
  /// game with the run's own party, upgrade state, mastery snapshot and ship
  /// first. The picks are replayed in order (straight onto the pick state,
  /// so a replayed Orb Vitality or revive does not act a second time — the
  /// hit points below are the run's own), the wave in progress starts again
  /// from its beginning, and everything the run has built up is put back.
  /// What only lives inside a wave — enemies, projectiles, cooldowns, the
  /// outbreak, effects — starts fresh, as it does at any wave's start.
  void resumeRun(SuspendedSurvivalRun run) {
    for (final pick in run.picks) {
      final def = kSurvivalPowerUpsById[pick.id];
      if (def == null) continue;
      powerUps.apply(
        def,
        targetSlot: pick.targetSlot,
        targetName: pick.targetName,
      );
    }
    for (final slot in run.phoenixUsed) {
      powerUps.consumePhoenixRebirth(slot);
    }
    powerUps.restoreDraftKeys(
      rerollsLeft: run.rerollsLeft,
      banishesLeft: run.banishesLeft,
      banished: run.banished,
    );
    powerUps.restoreSeenFusionParents(run.fusionParentsSeen);

    startGame();
    for (var wave = 1; wave < run.wave; wave++) {
      spawner.resumeAfterIntermission();
    }
    _lastIntermissionRewardWave = run.wave - 1;
    alchemicalMeter = run.meter;
    _alchemicalProgressPoints = run.meterProgress;

    stats
      ..kills = run.kills
      ..score = run.score
      ..timeElapsed = run.timeElapsed
      ..otherDamage = run.otherDamage
      ..shipDamage = run.shipDamage
      ..shipKills = run.shipKills;
    healingStats
      ..toMons = run.healingToMons
      ..toShip = run.healingToShip
      ..toOrb = run.healingToOrb;
    companionRunStats.clear();
    for (final s in run.slotStats) {
      companionRunStats[s.slot] = CompanionRunStats()
        ..damageDealt = s.damageDealt
        ..kills = s.kills
        ..damageTaken = s.damageTaken
        ..healingDone = s.healingDone
        ..fieldSeconds = s.fieldSeconds;
    }
    deployedCompanionSlots
      ..clear()
      ..addAll(run.deployedSlots);

    defeatedCompanionSlots.clear();
    companionHpFraction.clear();
    for (final slot in run.slots) {
      if (slot.dead) defeatedCompanionSlots.add(slot.slot);
      companionHpFraction[slot.slot] = slot.dead ? 0.0 : slot.hp;
    }

    _pendingResume = run;
    if (isLoaded) _restoreResumedBodies();
  }

  /// The resumed run's orb, ship and deployed companions, once they exist.
  void _restoreResumedBodies() {
    final run = _pendingResume;
    if (run == null) return;
    _pendingResume = null;

    orb.maxHp = run.orbMaxHp;
    orb.currentHp = run.orbHp.clamp(1.0, run.orbMaxHp).toDouble();
    orb.shieldHp = run.orbShield;

    ship.isDead = run.shipDead;
    _syncShipHull();
    ship.currentHp = run.shipDead
        ? 0
        : run.shipHp.clamp(1.0, ship.maxHp).toDouble();
    _shipRespawnTimer = run.shipDead ? run.shipRespawnElapsed : 0;

    tetherModeEnabled = run.tetherMode;
    for (final slot in run.activeSlots) {
      summonCompanion(slot);
    }
    final tethered = run.tetheredSlot;
    if (!run.tetherMode) {
      clearCompanionTether();
    } else if (tethered != null && activeCompanions.containsKey(tethered)) {
      tetheredCompanionSlot = tethered;
      for (final entry in activeCompanions.entries) {
        entry.value.tethered = entry.key == tethered;
      }
    }
  }

  // == Update ==============================================================

  @override
  void update(double dt) {
    super.update(dt);
    if (!_started) return;
    if (isGameOver) {
      _coreFallT += dt;
      return;
    }
    // Not while a draft is open or about to open (the meter is full and the
    // bar is still filling): a checkpoint taken there kept the full meter
    // without the pick, so SAVE & EXIT and CONTINUE rolled the draft again
    // for free. It waits for the pick and keeps it.
    if (_checkpointDue &&
        !showingPowerUpSelection &&
        alchemicalMeter < alchemicalMeterMax) {
      _checkpointDue = false;
      onWaveCheckpoint?.call();
    }
    if (gamePaused) return;
    dt *= timeScale.clamp(1.0, fastForwardTimeScale);
    final soundHpBefore = ship.currentHp + orb.currentHp;

    _rebuildEnemySpatialGrid();

    stats.timeElapsed += dt;
    activeCompanions.forEach((slot, comp) {
      if (!comp.isDead) _runStatsFor(slot).fieldSeconds += dt;
    });
    damageNumbers.update(dt);
    mastery.tick(dt);

    // Zoom animation
    if (!_zoomAnimComplete) {
      _zoomAnimTimer += dt;
      final t = (_zoomAnimTimer / _zoomAnimDuration).clamp(0.0, 1.0);
      final ease = 1.0 - pow(1.0 - t, 3).toDouble();
      _currentZoom = _zoomAnimFrom + (_zoomAnimTo - _zoomAnimFrom) * ease;
      if (t >= 1.0) _zoomAnimComplete = true;
    }
    _updateCameraGlide(dt);

    _updateShip(dt);
    _updateCompanion(dt);
    _buildProjectileControlBuckets(_projectileControlBuckets);
    _updateEnemies(dt, _projectileControlBuckets);
    _rebuildEnemySpatialGrid();
    _updateCompanionProjectiles(dt);
    _updateManeMastery(dt);
    _updatePipMastery(dt);
    _updateHornMastery(dt);
    _updateMaskMastery(dt);
    _updateWingMastery(dt);
    _updateMysticMastery(dt);
    _updateShipBlessing(dt);
    _updateMasteryEchoes(dt);
    updatePersistentAbilityEffects(dt);
    _updateLetVines();
    _updateBeamEffects(dt);
    _updateFlowerPickups(dt);
    _updateKinSupportTick(dt);
    _updateMysticEnvironments(dt);
    _updateMysticEmbers(dt);
    _updateMysticWorlds(dt);
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
    _updateOutbreak(dt);
    final magnet = powerUps.surgeMagnetLevel;
    _surgeGrains.update(
      dt,
      orb.position,
      ship.position,
      pull: ship.isDead
          ? null
          : kSurgePullRange[min(magnet, kSurgePullRange.length - 1)],
      onTaken: _takeSurgeGrain,
    );
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
      arenaRadius: _arenaRadius,
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
      // One shared encounter budget keeps later waves from suddenly adding
      // six independent boss health bars, projectile patterns, and rewards.
      extraBosses.clear();
      if (activeBoss != null) {
        final extraCount = CosmicSurvivalBalance.bossCountForWave(wave) - 1;
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
    final bossAlive = anyBossAlive || (outbreak != null && !outbreak!.cleared);
    spawner.checkWaveComplete(alive, bossAlive: bossAlive);

    _maybeTriggerPowerUpSelection();

    if (spawner.intermission && !showingPowerUpSelection) {
      final clearedWave = spawner.currentWave;
      final bossWave = spawner.isBossWave;
      onWaveCleared?.call(clearedWave);
      _cleanupBetweenWaves();
      _endWaveGrains();
      _grantIntermissionReward(clearedWave, bossWave: bossWave);
      _maybeTriggerPowerUpSelection();
      spawner.resumeAfterIntermission();
      // Kept at the top of the next frame, once this one has settled.
      _checkpointDue = true;
    }

    if (ship.currentHp + orb.currentHp < soundHpBefore) {
      onSound?.call(SoundCue.combatPlayerHurt);
    }
    _trimProjectilePools();

    // Game over
    if (orb.currentHp <= 0 && !isGameOver) _catchOrbDeathWithPhoenix();
    if (orb.currentHp <= 0 && !isGameOver) {
      isGameOver = true;
      onGameOver();
    }

    _updateSpatialMetrics(dt);
  }

  // == Ship ================================================================

  @override
  void onPanStart(DragStartInfo info) {
    if (autopilot) return;
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
    if (autopilot) return;
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

  // The ship keeps pace with the waves: its hull follows the enemies' damage
  // and its hits their health, so what a player builds into it keeps its
  // worth from the first wave to the last instead of melting away. Unbuilt
  // it is still one small gun, a percent or two of a run's damage; the
  // weapon picks are what make it count.
  static const double _kShipBaseHull = 100;

  /// The wave and Reinforced Hull level the hull was last sized for.
  int _hullWave = 0;
  double _hullBuilt = 0;

  double get _shipWaveDamage =>
      CosmicSurvivalBalance.enemyWaveHpScale(spawner.currentWave);

  /// Sizes the hull for the wave, keeping the share of it the ship has left.
  void _syncShipHull() {
    final wave = spawner.currentWave;
    final built = powerUps.shipHullMultiplier;
    if (wave == _hullWave && built == _hullBuilt) return;
    _hullWave = wave;
    _hullBuilt = built;
    final hull =
        _kShipBaseHull *
        CosmicSurvivalBalance.enemyWaveDamageScale(wave) *
        built;
    final left = ship.maxHp > 0 ? ship.currentHp / ship.maxHp : 1.0;
    ship.maxHp = hull;
    if (!ship.isDead) ship.currentHp = hull * left.clamp(0.0, 1.0);
  }

  void _updateShip(double dt) {
    _syncShipHull();
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
    final plagueMove = outbreak?.movementMultiplier(ship.position) ?? 1.0;

    if (autopilot) {
      // Nothing to fly toward: the idle orbit below is the autopilot.
      _dragTarget = null;
    }
    if (_joystickInput.distance > 0.1) {
      ship.angle = atan2(_joystickInput.dy, _joystickInput.dx);
      final inputScale = _joystickInput.distance.clamp(0.0, 1.0);
      ship.position = Offset(
        ship.position.dx +
            cos(ship.angle) * ship.speed * inputScale * plagueMove * dt,
        ship.position.dy +
            sin(ship.angle) * ship.speed * inputScale * plagueMove * dt,
      );
      _dragTarget = null;
      _rememberCurrentOrbitRadius();
      _letGoFor = 0;
      _gatherAt = null;
    } else if (_dragTarget != null &&
        (_dragTarget! - ship.position).distance > 5) {
      final dir = _dragTarget! - ship.position;
      final dist = dir.distance;
      final nx = dir.dx / dist;
      final ny = dir.dy / dist;
      final move = min(ship.speed * plagueMove * dt, dist);
      ship.position = Offset(
        ship.position.dx + nx * move,
        ship.position.dy + ny * move,
      );
      ship.angle = atan2(ny, nx);
      _rememberCurrentOrbitRadius();
      _letGoFor = 0;
      _gatherAt = null;
    } else if (!_autopilotGather(dt, plagueMove)) {
      shipIsIdle = true;
    }

    _applyOrbGravityToShip(dt, shipIsIdle: shipIsIdle);
    ship.position = _clampToArena(ship.position, padding: _arenaShipPadding);

    if (wasDead) return;

    // Auto-fire at nearest enemy or boss
    ship.fireTimer += dt;
    // Rapid Rockets (a fusion): rockets reload faster than plain shots.
    final rocketPenalty = !powerUps.hasRocketBarrage
        ? 1.0
        : powerUps.hasRapidRockets
        ? kRapidRocketsReload
        : 1.5;
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

  /// How long the ship must be let go before Autopilot takes it out.
  static const double _kAutopilotLetGo = 0.6;

  /// Seconds since the player last steered the ship.
  double _letGoFor = 0;

  /// Where Autopilot is flying the ship, and when it next looks again.
  Offset? _gatherAt;
  double _gatherLook = 0;

  /// Autopilot (a draft pick): a ship let go for a moment, or flying itself
  /// in CAMERA, goes out for the surge grains lying anywhere in the arena,
  /// and once none are left flies home to its orbit. True while it is on its
  /// way somewhere; false hands it to the idle orbit.
  bool _autopilotGather(double dt, double plagueMove) {
    if (!powerUps.hasAutopilot || ship.isDead) {
      _gatherAt = null;
      return false;
    }
    _letGoFor += dt;
    if (!autopilot && _letGoFor < _kAutopilotLetGo) return false;
    _gatherLook -= dt;
    if (_gatherLook <= 0) {
      _gatherLook = 0.3;
      final found = _surgeGrains.gatherTarget(
        ship.position,
        orb.position,
        reach: _arenaRadius,
        prefer: _gatherAt,
      );
      _gatherAt = found == null
          ? null
          : _clampToArena(found, padding: _arenaShipPadding);
    }
    var at = _gatherAt;
    if (at == null) {
      // Nothing to fetch: home, to where the orbit takes it over.
      final fromOrb = ship.position - orb.position;
      final d = fromOrb.distance;
      if (d <= _idleOrbitRadius + 60 || d < 1) return false;
      at = orb.position + fromOrb / d * _idleOrbitRadius;
    }
    final dir = at - ship.position;
    final dist = dir.distance;
    if (dist < 12) {
      // There: look again next frame.
      _gatherLook = 0;
      return false;
    }
    final move = min(ship.speed * plagueMove * dt, dist);
    ship.position += dir / dist * move;
    ship.angle = atan2(dir.dy, dir.dx);
    _dragTarget = null;
    return true;
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

    final radialError = dist - _idleOrbitRadius;
    final radialSpeed = radialError.clamp(-90.0, 90.0) * 0.82;
    final tangent = Offset(-dir.dy, dir.dx);
    final orbitSpeed = 52.0 + 8.0 * sin(stats.timeElapsed * 0.7);

    ship.position += (dir * radialSpeed + tangent * orbitSpeed) * dt;
    ship.angle = atan2(tangent.dy, tangent.dx);
    _dragTarget = ship.position;
  }

  void _rememberCurrentOrbitRadius() {
    final distance = (ship.position - orb.position).distance;
    final maxRadius = (_arenaRadius - 110.0).clamp(220.0, 560.0);
    _idleOrbitRadius = distance.clamp(150.0, maxRadius);
  }

  void _fireShipAt(Offset targetPos) {
    // Cap total ship projectiles to limit performance impact at high waves
    if (shipProjectiles.length >= 40) return;

    final dir = targetPos - ship.position;
    final dist = dir.distance;
    if (dist < 1) return;
    final norm = Offset(dir.dx / dist, dir.dy / dist);
    // Rocket Barrage replaces the gun's bolts with rockets, and sounds so.
    onSound?.call(
      powerUps.hasRocketBarrage ? SoundCue.shipMissile : SoundCue.shipBolt,
    );
    final kineticLevel = powerUps.kineticOverdriveLevel;
    final kineticScale = 1.0 + kineticLevel * 0.10;
    final baseDamage =
        10.0 *
        powerUps.shipDamageMultiplier *
        maskShipDamageAmp *
        kineticScale *
        _shipWaveDamage;
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
      final homing = powerUps.hasHomingSpread;
      for (var i = 1; i <= powerUps.spreadShotLevel; i++) {
        for (final sign in [-1.0, 1.0]) {
          final spreadAngle = sign * i * 0.25;
          final sa = atan2(norm.dy, norm.dx) + spreadAngle;
          final dir = Offset(cos(sa), sin(sa));
          // Homing Spread (a fusion): each side shot steers at the body
          // nearest its own line, so the fan still covers its arc.
          final target = homing
              ? _nearestEnemyTo(ship.position + dir * 160, 220)
              : null;
          shipProjectiles.add(
            ShipProjectile(
              position: ship.position,
              velocity: dir * shotSpeed,
              // Homing Spread: the side shots hit as hard as the centre.
              damage: baseDamage * (homing ? 1.0 : 0.6),
              life: shotLife,
              isHoming: target != null,
              target: target,
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
            // Heavy Missiles (a fusion): Kinetic Overdrive's impact and
            // speed carry to the launcher's missiles.
            final kinetic = powerUps.hasHeavyMissiles
                ? powerUps.kineticOverdriveLevel
                : 0;
            final speed =
                (330.0 + missileLevel * 30.0) * (1.0 + kinetic * 0.12);
            final missileDamage =
                (20.0 + missileLevel * 10.0) *
                powerUps.shipDamageMultiplier *
                maskShipDamageAmp *
                (1.0 + kinetic * kHeavyMissilesImpactPerLevel) *
                _shipWaveDamage;
            final splashRadius = 80.0 + missileLevel * 24.0;
            onSound?.call(SoundCue.shipMissile);
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
              (8.0 + turretLevel * 6.0) *
              powerUps.shipDamageMultiplier *
              maskShipDamageAmp *
              _shipWaveDamage;
          // The rapid turret's zap: the ship's own gun sound.
          onSound?.call(SoundCue.shipBolt);
          _spawnBeam(
            ship.position,
            target.position,
            const Color(0xFF9FE8FF),
            width: 2.1 + turretLevel * 0.35,
            life: 0.08,
          );
          _damageEnemy(target, beamDamage, autoAttack: true, fromShip: true);
          if (powerUps.hasLinkedTurrets) _fireLinkedOrbTurret(target);
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
                (7.0 + turretLevel * 5.0) *
                powerUps.shipDamageMultiplier *
                maskShipDamageAmp *
                _shipWaveDamage;
            onSound?.call(SoundCue.shipBolt);
            _spawnBeam(
              ship.position,
              best.position,
              const Color(0xFF9FE8FF),
              width: 2.1 + turretLevel * 0.35,
              life: 0.08,
            );
            damageBoss(
              beamDamage,
              target: best,
              autoAttack: true,
              fromShip: true,
            );
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
      // A Mystic that dies loses its world. The embers fade over a couple of
      // seconds rather than blinking out, so it is something the player sees
      // happen and can read as a consequence.
      _extinguishMysticField(slot);
      _closeMysticEnvironment(slot);
      defeatedCompanionSlots.add(slot);
      if (tetheredCompanionSlot == slot) {
        tetheredCompanionSlot = null;
      }
      final downed = activeCompanions[slot];
      if (downed != null) _noteKinCompanionDown(slot, downed);
      activeCompanions.remove(slot);
      _companionTickers.remove(slot);
      _companionVisuals.remove(slot);
      _companionSpriteScales.remove(slot);
    }

    for (final entry in activeCompanions.entries) {
      final comp = entry.value;
      // While a lock holds, the stabilizer returns the current target and
      // discards any fresh pick, so skip the pick: at horde density it is a
      // scored scan of hundreds of bodies per companion per frame.
      final targetChoice = _stabilizeCompanionTargetChoice(
        comp,
        _companionTargetLocked(comp) ? null : _pickCompanionTargetChoice(comp),
      );
      comp.stickyTarget = targetChoice?.enemy;
      comp.engagedTarget = targetChoice == null
          ? null
          : (targetChoice.enemy ?? (targetChoice.isBoss ? activeBoss : null));
      _updateSingleCompanion(dt, entry.key, comp, targetChoice);
    }
    _separateCompanionBodies(dt);
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
    comp.tickFlash(dt);
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
        comp.position = hornCirclePoint(
          comp.chargeCircleCenter!,
          comp.chargeCircleRadius,
          comp.chargeCircleAngle,
        );
        // Face along the tangent of the circle (perpendicular to radius).
        comp.angle = comp.chargeCircleAngle + pi / 2;
        // SNAPSHOT: killing something here can APPEND to `enemies` — a
        // splitter breaks into smaller bodies on death, and a summoner's brood
        // lands in the same list — so walking the live list throws Concurrent
        // modification mid-frame. `_updateEnemies` already iterates a copy for
        // exactly this reason.
        for (final e in List<CosmicSurvivalEnemy>.of(enemies)) {
          if (e.isDead) continue;
          final d = (e.position - comp.position).distance;
          if (d < e.radius + comp.chargeSweepRadius &&
              !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
            comp.chargeHitIds?.add(e.hashCode);
            _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
          }
        }
        _hornRamBosses(slotIndex, comp, comp.chargeSweepRadius);
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
          // SNAPSHOT: killing something here can APPEND to `enemies` — a
          // splitter breaks into smaller bodies on death, and a summoner's
          // brood lands in the same list — so walking the live list throws
          // Concurrent modification mid-frame. `_updateEnemies` already
          // iterates a copy for exactly this reason.
          for (final e in List<CosmicSurvivalEnemy>.of(enemies)) {
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
                final dur = hornPlantRootDuration(
                  _effectiveIntelligence(slotIndex),
                );
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
                  comp.abilityAtk * 0.40,
                  60,
                  4.5,
                  sourceSlotIndex: slotIndex,
                );
              }
            }
          }
          _hornRamBosses(slotIndex, comp, comp.chargeSweepRadius);
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
        // SNAPSHOT: killing something here can APPEND to `enemies` — a
        // splitter breaks into smaller bodies on death, and a summoner's brood
        // lands in the same list — so walking the live list throws Concurrent
        // modification mid-frame. `_updateEnemies` already iterates a copy for
        // exactly this reason.
        for (final e in List<CosmicSurvivalEnemy>.of(enemies)) {
          if (e.isDead) continue;
          final d = (e.position - comp.position).distance;
          if (d < e.radius + comp.chargeFinalSweepRadius &&
              !(comp.chargeHitIds?.contains(e.hashCode) ?? false)) {
            comp.chargeHitIds?.add(e.hashCode);
            _damageEnemy(e, comp.chargeDamage, sourceSlotIndex: slotIndex);
          }
        }
        _hornRamBosses(slotIndex, comp, comp.chargeFinalSweepRadius);
        if (comp.member.family.toLowerCase() == 'horn') {
          pushHornFx(
            _hornFx,
            HornFx.slam(
              position: comp.position,
              angle: comp.angle,
              radius: comp.chargeFinalSweepRadius,
              element: comp.member.element,
            ),
          );
          final slam = SoundCue.forHornSlam(comp.member.element);
          if (slam != null) onSound?.call(slam);
        }
        // Horn+Lightning: instead of releasing the chain blast now,
        // start a 3s storm-brewing wind-up. The horn keeps holding
        // still, the brewing visual telegraphs the coming discharge,
        // and any damage taken during that window adds to the blast.
        if (comp.member.family.toLowerCase() == 'horn' &&
            comp.member.element == 'Lightning' &&
            comp.pendingChargeBurst != null) {
          comp.hornPostDashWindUpTimer = 3.0;
          onSound?.call(SoundCue.specialHornBrew);
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
          final absorbMul = hornLightningAbsorbMultiplier(
            _effectiveBeauty(slotIndex),
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
          onSound?.call(SoundCue.specialHornDischarge);
          _appendCompanionProjectiles(pending);
        }
        comp.pendingChargeBurst = null;
        comp.pendingChargeOrigin = null;
      }
      return;
    }

    // Blessing timer
    //
    // Carried as a fraction and spent in whole points, because companion HP is
    // an integer and a blessing's tick is a fraction of one.
    //
    // This used to round the per-FRAME amount, which silently paid out nothing
    // at all. Every blessing in the game sits between 2.3 and 5.4 HP a second,
    // which at sixty frames is 0.04 to 0.09 a frame — and `.round()` of
    // anything under 0.5 is zero. Not a weak heal: a heal that never once
    // landed, for every family, at every level. The same rounding would have
    // paid 60 HP a second the moment a tick crossed 30, so it was a cliff as
    // well as a hole.
    if (comp.blessingTimer > 0) {
      comp.blessingTimer -= dt;
      comp.blessingCarry += comp.blessingHealPerTick * dt;
      if (comp.blessingCarry >= 1) {
        final blessingHeal = comp.blessingCarry.floor();
        comp.blessingCarry -= blessingHeal;
        final before = comp.currentHp;
        comp.currentHp = min(comp.maxHp, comp.currentHp + blessingHeal);
        _recordHeal((comp.currentHp - before).toDouble(), target: 0);
        // A blessing echoes into the orb once, from its caster. Shared by
        // Communion, every ally's copy echoed as well, so the orb's mending
        // went up with the party, five-fold in a full one (2026-10-21
        // mastery sweep; KinTuning.communionShare). The allies still get
        // theirs.
        if (!comp.blessingShared) _healOrb(blessingHeal * 0.5);
      }
    } else {
      comp.blessingCarry = 0;
      comp.blessingShared = false;
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
      // Follow a creature's own size off the ship, so a big one is not
      // drawn over the hull.
      final followGap = max(
        92.0,
        _shipHullRadius + _companionBodyRadius(comp) + 28,
      );
      if (dist > followGap + 4) {
        final dir = ship.position - comp.position;
        final norm = Offset(dir.dx / dist, dir.dy / dist);
        final moveSpeed =
            160.0 * _speedMovementMultiplier(_effectiveSpeed(slotIndex));
        final step = min(moveSpeed * dt, max(0.0, dist - followGap));
        comp.position = Offset(
          comp.position.dx + norm.dx * step,
          comp.position.dy + norm.dy * step,
        );
        _setCompanionAngle(comp, atan2(norm.dy, norm.dx), 0.22);
      } else {
        // The ship flew onto it: step aside off the hull (the same
        // clearance [_separateCompanionBodies] keeps for everyone).
        final clear = _shipHullRadius + _companionBodyRadius(comp) * 0.8;
        if (dist < clear && !ship.isDead) {
          final away = dist > 0.001
              ? (comp.position - ship.position) / dist
              : const Offset(0, -1);
          final moveSpeed =
              160.0 * _speedMovementMultiplier(_effectiveSpeed(slotIndex));
          comp.position += away * min(moveSpeed * dt, clear - dist);
        }
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
        // A family that holds off the orb goes round it, not through it.
        final routed = _roundTheOrb(
          comp.position,
          moveTarget,
          _familyOrbClearance(comp.member.family.toLowerCase()),
        );
        // Smooth anchor updates — slower blend prevents jitter when
        // surrounded by enemies or caught between competing forces. Per
        // second, not per frame, so it moves the same at 60 and 120 fps.
        final anchorBlend = 1.0 - exp(-2.5 * dt);
        comp.anchor = Offset.lerp(comp.anchor, routed, anchorBlend) ?? routed;
        final steeringTarget = comp.anchor;
        final dir = steeringTarget - comp.position;
        final dist = dir.distance;
        if (dist > 1) {
          final norm = Offset(dir.dx / dist, dir.dy / dist);
          // Eases in over the last few units instead of stopping dead inside
          // six of them, which read as park, hop, park. Only a few: easing in
          // from further out left a ring of them lagging their places, close
          // enough to overlap.
          final moveSpeed =
              120.0 *
              _familyMovementSpeedMultiplier(comp.member.family) *
              _speedMovementMultiplier(_effectiveSpeed(slotIndex)) *
              min(1.0, dist / 12);
          final desiredVelocity = norm * moveSpeed;
          // Lower steering blend = smoother turns, less jitter.
          final steeringBlend = 1.0 - exp(-7.7 * dt);
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
      // A Let's echo waits for room for its meteor rather than being lost
      // to a full projectile list ([_letSpecialHasRoom]).
      if (comp.doubleCastTimer <= 0 &&
          comp.doubleCastTargetPos != null &&
          !_letSpecialHasRoom(comp)) {
        comp.doubleCastTimer = 1 / 30;
      }
      if (comp.doubleCastTimer <= 0 && comp.doubleCastTargetPos != null) {
        final thresholdBeauty = _effectiveBeauty(slotIndex);
        // A Let's echo aims at the crowd as it stands now, two seconds on.
        final echoTarget = _letSpecialAim(
          comp,
          comp.doubleCastTargetPos!,
          beauty: thresholdBeauty,
          atBoss: anyBossAlive,
        );
        final echoDir = echoTarget - comp.position;
        final echoAngle = echoDir.distance > 0.001
            ? atan2(echoDir.dy, echoDir.dx)
            : comp.doubleCastAngle;
        final thresholdIntelligence = _effectiveIntelligence(slotIndex);
        final thresholdStrength = _effectiveStrength(slotIndex);
        final result2 = createCosmicSpecialAbility(
          origin: comp.position,
          baseAngle: echoAngle + 0.15,
          family: comp.member.family,
          element: comp.member.element,
          damage: comp.abilityAtk * 0.70 * comp.damageAmp,
          maxHp: comp.maxHp,
          casterPower: thresholdIntelligence,
          casterBeauty: thresholdBeauty,
          casterIntelligence: thresholdIntelligence,
          casterStrength: thresholdStrength,
          casterBeautyPotential: comp.member.statBeautyPotential,
          targetPos: echoTarget,
        );
        // The echo is the same attack happening twice, but it lands on its
        // own schedule, so it gets its own cast rather than reopening one
        // whose dual-hit window closed a second ago.
        final echoCastId = mastery.beginCast(
          slotIndex: slotIndex,
          family: creatureFamilyFromStorage(comp.member.family),
          element: comp.member.element,
          kind: MasteryCastKind.special,
          projectileCount: result2.projectiles.length,
        );
        for (final projectile in result2.projectiles) {
          projectile.sourceSlotIndex = slotIndex;
          projectile.masteryCastId = echoCastId;
          if (powerUps.companionHasChainLightning(slotIndex)) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              2,
            );
          }
        }
        _loadPipPayload(result2.projectiles, comp, slotIndex);
        // The echo is the SAME cast happening twice; it takes the plain
        // launch so a double-cast does not stack two cast cues on itself.
        if (!_activateMaskPlacements(
          slotIndex,
          result2.projectiles,
          target: echoTarget,
        )) {
          // A Wing echo's sound is its beam's (_activateWingBeamEffects).
          _appendCompanionProjectiles(
            result2.projectiles,
            cue: SoundCue.combatProjectile,
            silent: comp.member.family.toLowerCase() == 'wing',
          );
          _noteMaskPlacedLives(slotIndex, result2.projectiles);
        }
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

    // Skyreach (Let): the auto-attack can land anywhere in the arena, so it
    // fires on its own target whether or not anything is near the Let. It
    // spends the cooldown, which keeps the ordinary attack below from firing
    // a second rock this frame.
    _tryFireLetSkyreach(comp, slotIndex);

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
      // Basic attack - family-specific projectiles (same as cosmic game).
      // Wing+Dark's doubled rate is part of the shared cadence rule.
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
          bossBonus: bossBonus,
          targetBoss: (targetChoice?.isBoss ?? false) ? activeBoss : null,
        );
      } else if (comp.basicCooldown <= 0 &&
          distToTarget <=
              comp.attackRange * _masteryAttackRangeMultiplier(slotIndex) +
                  bossBonus) {
        final cooldown =
            comp.effectiveBasicCooldown *
            _masteryBasicCooldownMultiplier(slotIndex);
        comp.basicCooldown = cooldown;
        _bankHornGuard(slotIndex, comp);
        // Tracer is paid when a shot lands, not here ([_onWingHit]).
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
        // One scheduled attack is one cast, however many projectiles it
        // throws. Every slash, dart and feather below carries the same id so
        // mastery can ask "did both blades land on that body" without a
        // multishot family triggering cast nodes three times as often.
        final shaped = _applyLetBasicMastery(
          _applyPipBasicMastery(
            _applyManeBasicMastery(basics, comp, slotIndex, fireAngle),
            comp,
            slotIndex,
            fireAngle,
          ),
          comp,
          slotIndex,
          fireAngle,
          attackTarget,
        );
        final basicCastId = mastery.beginCast(
          slotIndex: slotIndex,
          family: creatureFamilyFromStorage(comp.member.family),
          element: comp.member.element,
          kind: MasteryCastKind.basic,
          projectileCount: shaped.length,
          masteryDamageFraction: _masteryBasicUplift(slotIndex),
        );
        _onManeBasicCast(slotIndex, basicCastId, fireAngle);
        _onLetBasicCast(slotIndex, basicCastId);
        _onPipBasicCast(slotIndex, basicCastId, fireAngle);
        // Kin+Lightning tesla charge: while any Lightning kin is
        // actively channelling, ALL companion auto-attacks get chain
        // lightning. Stacks with the existing powerup version.
        final teslaActive = _isAnyKinLightningChargeActive();
        for (final projectile in shaped) {
          projectile.sourceSlotIndex = slotIndex;
          projectile.masteryCastId = basicCastId;
          if (powerUps.companionHasChainLightning(slotIndex) || teslaActive) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              teslaActive ? 3 : 2,
            );
          }
        }
        _appendCompanionProjectiles(shaped, cue: _basicCue(comp, shaped));

        // Mystic family passive: basic attacks reduce special cooldown
        if (comp.member.family.toLowerCase() == 'mystic') {
          comp.specialCooldown -= 0.3;
        }
        // Pip+Earth passive: each basic shaves a bit off the special
        // cooldown. Shave amount scales with intelligence. 0.1 s a basic
        // (0.4 before the 2026-10-20 rebuild): at 0.4 a bred Earth Pip threw
        // its volley about once a second, three times as often as any other
        // Pip, and once every dart carried on through the bodies it killed
        // that was half its party's damage.
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
            comp.specialCooldown - 0.1 * shaveScale,
          );
        }
      }

      // Special ability - family x element (same as cosmic game!)
      if (comp.specialCooldown <= 0 &&
          distToTarget <= comp.specialAbilityRange + bossBonus &&
          !isPassiveOnlyCosmicAbility(
            comp.member.family,
            comp.member.element,
          ) &&
          _letSpecialHasRoom(comp)) {
        final thresholdBeauty = _effectiveBeauty(slotIndex);
        final thresholdIntelligence = _effectiveIntelligence(slotIndex);
        final thresholdStrength = _effectiveStrength(slotIndex);
        comp.specialCooldown = _mysticCastCooldown(
          comp,
          comp.effectiveSpecialCooldown,
        );
        // A SPECIAL WENT OFF. Survival played the same generic launch blip
        // for a basic and for a special, so the one thing a player most
        // needs to hear — the cooldown you were waiting on just spent
        // itself — sounded identical to the shot before it. The element cue
        // carries the color; this only marks the distinction, quietly, and
        // several ability families append no projectile at all (the world
        // mystics, the kin supports), so it cannot live in the appender.
        // Each family now has its own cast gesture (Wing's sounds where its
        // beam starts, the only place its length is known). Lightning Wing's
        // accent waits for the blast instead of the charge.
        final castElement = SoundCue.forElement(comp.member.element);
        final castFamily = comp.member.family;
        if (castElement != null &&
            !(castFamily.toLowerCase() == 'wing' &&
                comp.member.element == 'Lightning')) {
          onSound?.call(castElement);
        }
        final familyCast = SoundCue.forFamilySpecial(
          castFamily,
          comp.member.element,
        );
        if (familyCast != null) onSound?.call(familyCast);

        // A caster keeps the pieces of its last two casts; older ones fade
        // (CasterPieces, shared with open space and dungeons).
        CasterPieces.onCast(
          companionProjectiles,
          slot: slotIndex,
          family: comp.member.family,
          element: comp.member.element,
        );

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
              comp.abilityAtk *
              1.15 *
              (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
              comp.damageAmp,
          maxHp: comp.maxHp,
          casterPower: thresholdIntelligence,
          casterBeauty: thresholdBeauty,
          casterIntelligence: thresholdIntelligence,
          casterStrength: thresholdStrength,
          casterBeautyPotential: comp.member.statBeautyPotential,
          // A Let drops its meteor on the crowd, not on the one body it is
          // shooting at; a boss still comes first ([_letSpecialAim]).
          targetPos: _letSpecialAim(
            comp,
            attackTarget,
            beauty: thresholdBeauty,
            atBoss: targetChoice?.isBoss ?? false,
          ),
        );
        final specialCastId = mastery.beginCast(
          slotIndex: slotIndex,
          family: creatureFamilyFromStorage(comp.member.family),
          element: comp.member.element,
          kind: MasteryCastKind.special,
          projectileCount: result.projectiles.length,
          masteryDamageFraction: _masterySpecialUplift(slotIndex),
        );
        _onManeSpecialCast(slotIndex);
        for (final projectile in result.projectiles) {
          projectile.sourceSlotIndex = slotIndex;
          projectile.masteryCastId = specialCastId;
          if (powerUps.companionHasChainLightning(slotIndex)) {
            projectile.chainLightningCharges = max(
              projectile.chainLightningCharges,
              2,
            );
          }
        }
        var specialProjectiles = result.projectiles;
        // Mane+Light: hang a ring, then another, then a third, then feed them.
        //
        // Casts 1-3 add the outer, middle and inner rings. Every cast after
        // that feeds one ring a rung up its size ladder, cycling outer ->
        // middle -> inner, for up to kManeLightMaxGrowth feedings. Nothing is
        // thrown: the cast's whole output is the ward it leaves turning.
        if (comp.member.family.toLowerCase() == 'mane' &&
            comp.member.element == 'Light' &&
            specialProjectiles.isNotEmpty) {
          // Limitless reaches the ward through its seed: the ring is built
          // from this projectile's damage and lifetime, so shaping it here is
          // what makes Far Throw and Overdraw mean anything to a Light Mane.
          _applyManeSpecialShape(specialProjectiles, slotIndex);
          _castManeLightWard(slotIndex, comp, specialProjectiles.first);
          _maybeSendLightRingToCircuit(slotIndex, comp);
          specialProjectiles = const <Projectile>[];
        }
        // Mane+Spirit: each cast adds another shot to a tight machine-gun
        // stream up to 10, then resets. abilityKillStacks doubles as the
        // cast counter for this companion.
        if (comp.member.family.toLowerCase() == 'mane' &&
            comp.member.element == 'Spirit' &&
            specialProjectiles.isNotEmpty) {
          final (soulSlashes, nextStacks) = ManeRuntime.spiritStream(
            specialProjectiles.first,
            fireAngle,
            comp.abilityKillStacks,
            slotIndex,
          );
          specialProjectiles = soulSlashes;
          comp.abilityKillStacks = nextStacks;
        }
        // Mane+Lightning: fire 5–10 small orbs toward scattered map
        // positions; each blooms into a larger shock field on arrival.
        if (comp.member.family.toLowerCase() == 'mane' &&
            comp.member.element == 'Lightning' &&
            specialProjectiles.isNotEmpty) {
          specialProjectiles = ManeRuntime.lightningOrbs(
            specialProjectiles.first,
            count: specialProjectiles.length,
            casterPos: comp.position,
            angle: fireAngle,
            scatterCenter: ship.isDead ? orb.position : ship.position,
            scatterRadius: min(560.0, _arenaRadius * 0.42),
            rng: _rng,
            clamp: (p) => _clampToArena(p, padding: _arenaShipPadding),
            slot: slotIndex,
          );
        }
        // Wing+Plant: the shot's trail puffs carry Plant's flower rider, which
        // does nothing on the ground, so its 16-18 puffs a cast only held
        // slots in the shared projectile list (2026-10-20 audit). Plant's
        // power is the flowers its beam's kills leave; the shot lays no trail.
        if (comp.member.family.toLowerCase() == 'wing' &&
            comp.member.element == 'Plant') {
          specialProjectiles = [
            for (final p in specialProjectiles)
              p.trailInterval > 0 ? copyProjectile(p, trailInterval: 0) : p,
          ];
        }
        // Kin+Light: the escort orbs circle the Kin, move to the ship,
        // intercept shots and heal what they guard for as long as they live.
        // They were not piercing, so the first body one brushed spent it and
        // its aura with it, and in a horde the escort never got going
        // (2026-10-20 audit). They pass through bodies now, striking each one
        // once.
        if (comp.member.family.toLowerCase() == 'kin' &&
            comp.member.element == 'Light') {
          specialProjectiles = [
            for (final p in specialProjectiles)
              p.holdOrbit && !p.piercing
                  ? (copyProjectile(p, piercing: true)
                      ..maxHitsPerEnemy = kKinLightEscortHitsPerBody)
                  : p,
          ];
        }
        // Several families rebuild their projectile list above rather than
        // editing it — Mane's soul-slash stream and lightning orbs construct
        // fresh Projectiles from a seed — so re-stamp here, once, after every
        // rewrite. A special that reached the world with cast id 0 would be
        // invisible to mastery for no reason a player could ever see.
        for (final projectile in specialProjectiles) {
          projectile.sourceSlotIndex ??= slotIndex;
          if (projectile.masteryCastId == 0) {
            projectile.masteryCastId = specialCastId;
          }
        }
        _applyManeSpecialMastery(specialProjectiles, comp, slotIndex);
        specialProjectiles = _applyPipSpecialMastery(
          specialProjectiles,
          comp,
          slotIndex,
          fireAngle,
        );
        _loadPipPayload(specialProjectiles, comp, slotIndex);
        // Juggernaut: whether this cast is the second run, settled before
        // the burst and the support go out so they come out at its strength
        // along with the ram. Only the ram used to be scaled (2026-10-20
        // audit). Settled for every Horn that casts, the no-ram Light barrier
        // included, which never owed a second run before.
        final hornRun = comp.member.family.toLowerCase() == 'horn'
            ? _settleHornRun(slotIndex)
            : null;
        if (hornRun != null && hornRun.second) {
          _scaleHornSecondRun(specialProjectiles, hornRun);
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
          // Stationary fixtures should outlast the wave that walks
          // into them — short lifetimes are bumped toward a 2.5s floor.
          clampHornChargeBurst(
            result.projectiles,
            reach: hornZoneReach(thresholdBeauty),
          );
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
          if (!_activateMaskPlacements(
            slotIndex,
            specialProjectiles,
            target: attackTarget,
          )) {
            // Silent: the family's own cast cue above already marks it.
            _appendCompanionProjectiles(specialProjectiles, silent: true);
            _noteMaskPlacedLives(slotIndex, specialProjectiles);
          }
          // Kin support-path cast intercepts. Most kin supports don't
          // produce projectiles directly — they flip companion-side
          // state that the per-frame loop consumes. Done after the
          // baseline projectile append above so the standard heal +
          // blessing still apply.
          if (comp.member.family.toLowerCase() == 'kin') {
            _activateKinSupportPath(comp, fireAngle, attackTarget);
            _applyKinBenedictionTimers(slotIndex, comp);
          }
          // Mystic ultimate environment overlay — change the WORLD
          // for the cast's duration. Pushes a new entry; multiple
          // simultaneous mystics stack their tints.
          if (comp.member.family.toLowerCase() == 'mystic') {
            _pushMysticEnvironment(comp.member.element, slotIndex);
            // A world outlives its cast, so the cast is spent for this
            // deployment. Recalling the Mystic (or losing it) is what gives the
            // ability back — and costs the world.
            if (_mysticWorldElements.contains(comp.member.element)) {
              _igniteMysticWorld(comp, slotIndex);
              _mysticSpentSlots.add(slotIndex);
              // A world registers once and the button goes dark. Developer
              // tools used to re-arm it at five seconds so a field could be
              // re-lit while its numbers were judged, and that was wrong: the
              // world tore itself down and rebuilt every five seconds, which
              // is not what any of these abilities are. The switch still
              // shortens the wait for the FIRST cast after a deployment (see
              // _mysticCastCooldown), which is the part that was worth having.
              comp.specialCooldown = double.infinity;
            }
          }
        }
        _activateWingBeamEffects(
          result.beams,
          sourceSlotIndex: slotIndex,
          origin: comp.position,
          angle: fireAngle,
        );

        // Apply state changes from ability
        final hornRunScale = hornRun != null && hornRun.second
            ? hornRun.power
            : 1.0;
        _applyCompanionSpecialSupportEffects(
          comp,
          result,
          scale: hornRunScale,
        );
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
            _applyHornCastMastery(slotIndex, comp, hornRun);
          }
          // Horn+Blood: HP sacrifice on cast. Take 18% of current HP
          // and bank the magnitude into chargeDamage so the impact
          // hits proportionally harder. Heal-on-kill window is the
          // hornSpecialActiveWindow above. A Juggernaut second run gives
          // and gains its share of it, like the rest of the run.
          if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Blood') {
            final sac = hornBloodSacrifice(comp.currentHp);
            if (sac != null) {
              comp.currentHp -= (sac.sacrifice * hornRunScale).round();
              comp.hitFlash = 1.0;
              pushHornFx(_hornFx, HornFx.sacrifice(position: comp.position));
              // Scale impact damage up: ~1× sac per 4 HP sacrificed
              // (tuned so a 200-HP sacrifice adds a meaty bump).
              comp.chargeDamage += sac.bonus * hornRunScale;
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
            // Start angle aligned with fire direction so the horn
            // sweeps tangentially away from where the player aimed.
            final circle = hornWaterCircle(
              fireAngle,
              comp.chargeOvershootDistance,
            );
            comp.chargePathType = 'circle';
            comp.chargeCircleCenter = comp.position;
            comp.chargeCircleRadius = circle.radius;
            comp.chargeCircleAngle = circle.startAngle;
            comp.chargeCircleAngularSpeed = circle.angularSpeed;
            comp.chargeTimer = circle.duration;
            comp.chargeTarget = null;
            comp.chargeHitIds = <int>{};
          } else if (comp.member.family.toLowerCase() == 'horn' &&
              comp.member.element == 'Ice') {
            // Horn+Ice: dash SIDEWAYS (perpendicular to the enemy
            // direction). An ice wall paints itself segment-by-
            // segment along the horn's path during the dash, so
            // enemies advancing toward the original cast position
            // walk into the freshly-formed wall.
            // A simple stable pick of side: rotate +90°.
            final dash = hornIceWallDash(
              comp.position,
              attackTarget,
              fireAngle,
              comp.chargeSpeedMultiplier,
            );
            comp.chargeTarget = dash.target;
            comp.chargeHitIds = <int>{};
            comp.chargePathType = 'ice-wall';
            comp.iceWallTrailTimer = 0;
            comp.chargeTimer = dash.timer;
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

    // Companion takes damage from enemies.
    //
    // By index: a Bastion's guard breaking in here ruptures (Last Stand), and
    // a splitter that kills adds its shards to this list mid-walk.
    for (var i = 0; i < enemies.length; i++) {
      final e = enemies[i];
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

  _CompanionTargetChoice? _pickCompanionTargetChoice(
    CosmicSurvivalCompanion comp,
  ) {
    final family = comp.member.family.toLowerCase();
    final maxScan =
        max(
          comp.attackRange * _masteryAttackRangeMultiplier(comp.slotIndex),
          comp.specialAbilityRange,
        ) +
        180;
    final walkingFire =
        family == 'let' &&
        mastery.hasNode(comp.slotIndex, LetNodes.walkingFire);
    final maxScanSq = maxScan * maxScan;

    // Spread-fire penalties, gathered once per pick rather than re-derived
    // (with a string lowercase per companion) for every candidate body.
    final lockedTargets = <CosmicSurvivalEnemy>[];
    final lockedPenalties = <double>[];
    for (final entry in activeCompanions.entries) {
      if (entry.key == comp.slotIndex) continue;
      final other = entry.value;
      if (other.isDead) continue;
      final target = other.stickyTarget;
      if (target == null) continue;
      final sameFamily = other.member.family.toLowerCase() == family;
      lockedTargets.add(target);
      lockedPenalties.add(sameFamily ? 90 : 30);
    }

    CosmicSurvivalEnemy? bestEnemy;
    var bestEnemyScore = double.negativeInfinity;
    // Grid query instead of a whole-list scan: at horde density most bodies
    // are out of range, and this runs for every companion every frame.
    _visitEnemiesNear(comp.position, maxScan, (enemy) {
      final distSq = _distanceSquared(enemy.position, comp.position);
      if (distSq > maxScanSq) return false;
      final dist = sqrt(distSq);
      var score = 220.0 - dist;
      if (enemy.target == CosmicEnemyTarget.orb) score += 170;
      if (enemy.target == CosmicEnemyTarget.ship) score += 90;
      if (enemy.conduct == EnemyConduct.standoff) score += 120;
      if (enemy.conduct == EnemyConduct.stalk) score += 70;
      if (enemy.isElite) score += 80;
      score += (1.0 - enemy.hpFraction) * 70;
      final orbDist = sqrt(_distanceSquared(enemy.position, orb.position));
      score += max(0.0, 180 - orbDist) * 0.45;

      switch (family) {
        case 'let':
          // Target: most health — prioritize highest HP enemies
          score += enemy.hpFraction * 180;
          // Walking Fire: what the special Sighted comes first.
          if (walkingFire && enemy.isLetSighted) {
            score += LetTuning.walkingFireTargetBonus;
          }
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
      for (var i = 0; i < lockedTargets.length; i++) {
        if (identical(lockedTargets[i], enemy)) score -= lockedPenalties[i];
      }

      if (score > bestEnemyScore) {
        bestEnemyScore = score;
        bestEnemy = enemy;
      }
      return false;
    });

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

    final picked = bestEnemy;
    if (picked != null) {
      return _CompanionTargetChoice(
        position: picked.position,
        enemy: picked,
        radius: picked.radius,
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

  /// Mirrors the first branch of [_stabilizeCompanionTargetChoice]: when this
  /// holds, that branch returns before the suggested pick is looked at.
  bool _companionTargetLocked(CosmicSurvivalCompanion comp) {
    final current = comp.stickyTarget;
    if (current == null || current.isDead || comp.stickyTargetLockTimer <= 0) {
      return false;
    }
    final maxScan =
        max(
          comp.attackRange * _masteryAttackRangeMultiplier(comp.slotIndex),
          comp.specialAbilityRange,
        ) +
        180;
    return _distanceSquared(current.position, comp.position) <=
        maxScan * maxScan * 1.20;
  }

  _CompanionTargetChoice? _stabilizeCompanionTargetChoice(
    CosmicSurvivalCompanion comp,
    _CompanionTargetChoice? suggested,
  ) {
    final current = comp.stickyTarget;
    final maxScan =
        max(
          comp.attackRange * _masteryAttackRangeMultiplier(comp.slotIndex),
          comp.specialAbilityRange,
        ) +
        180;
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

    // Fanning: the companions on one target share out the orb-facing arc of
    // it, spaced by the biggest body among them so their sprites clear, and
    // in the order they already stand round it so nobody crosses a partner
    // to reach its place. (It was a fixed spread per party slot, which put
    // five kins on one enemy about 60 apart when they need about 100.)
    final orbToTarget = targetPos - orb.position;
    final orbAngle = orbToTarget.distance > 0.001
        ? atan2(orbToTarget.dy, orbToTarget.dx)
        : atan2(toTarget.dy, toTarget.dx);
    // orbAngle + pi puts the companion between the target and the orb.
    final baseAngle = orbAngle + pi;
    final fan = _companionFanPlace(comp, targetPos, baseAngle);
    final minStep = choice.isBoss ? 0.80 : 0.55;
    final step = max(
      minStep,
      (2 * fan.groupBody + 26) / max(desiredRange, 1.0),
    ).clamp(minStep, 1.3);
    final approachAngle = baseAngle + (fan.rank - (fan.count - 1) / 2) * step;
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

    return _keepOffOrb(combatPos, _familyOrbClearance(family));
  }

  /// How far from the orb's centre a family with no patrol ring holds.
  ///
  /// Pip goes where the ship goes, and the ship goes where the wave is
  /// thickest, which late in a run is the orb itself: a body that reaches
  /// the orb bursts there (up to 165 px from its edge,
  /// [_enemyOrbExplosionRadius]), and a Pip, the frailest family, was
  /// standing in every burst. Measured 2026-10-20 at Potential 80, wave 101:
  /// Pips were alive for a third to two thirds of the wave and died a median
  /// 50 px from the orb's centre, 200-400 hit points a burst. It holds
  /// outside the burst ring now (230 still left it in the big ones) and
  /// reaches the bodies at the orb's edge from there. A Pip alone on the
  /// field, or with a boss at the orb, fights at the orb all the same:
  /// nobody else is there to hold it (the fresh-team report, 2026-10-20: a
  /// new team's first Pip, held outside the ring, let the wave-5 and wave-10
  /// bosses grind the orb, and level 10 fell at wave 18 instead of 23+).
  double _familyOrbClearance(String family) => switch (family) {
    'pip' => _bossAtOrb() || !_anotherHoldsTheOrb() ? 0.0 : 300.0,
    _ => 0.0,
  };

  /// Whether a living companion other than a Pip is out on the field.
  bool _anotherHoldsTheOrb() {
    for (final c in activeCompanions.values) {
      if (!c.isDead && c.member.family.toLowerCase() != 'pip') return true;
    }
    return false;
  }

  /// Whether a living boss stands within the Pip clearance ring of the orb.
  bool _bossAtOrb() {
    bool at(SurvivalBoss b) =>
        !b.isDead && (b.position - orb.position).distance < 300 + b.radius;
    final primary = activeBoss;
    if (primary != null && at(primary)) return true;
    for (var i = 0; i < extraBosses.length; i++) {
      if (at(extraBosses[i])) return true;
    }
    return false;
  }

  Offset _keepOffOrb(Offset at, double clearance) {
    if (clearance <= 0) return at;
    final away = at - orb.position;
    final dist = away.distance;
    if (dist >= clearance) return at;
    if (dist < 0.001) return orb.position + Offset(clearance, 0);
    return orb.position + away * (clearance / dist);
  }

  /// [to], or a step round the orb toward it when the straight way from
  /// [from] passes inside [clearance] of the orb's centre: its places either
  /// side of the orb are both outside the burst ring, and the line between
  /// them runs through it.
  Offset _roundTheOrb(Offset from, Offset to, double clearance) {
    if (clearance <= 0) return to;
    final a = from - orb.position;
    final b = to - orb.position;
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    final t = len2 > 0
        ? (-(a.dx * ab.dx + a.dy * ab.dy) / len2).clamp(0.0, 1.0)
        : 0.0;
    final closest = a + ab * t;
    if (closest.distance >= clearance * 0.95) return to;
    final from0 = atan2(a.dy, a.dx);
    var turn = atan2(b.dy, b.dx) - from0;
    while (turn > pi) {
      turn -= 2 * pi;
    }
    while (turn < -pi) {
      turn += 2 * pi;
    }
    final step = turn.sign * min(turn.abs(), 0.6);
    return orb.position +
        Offset(cos(from0 + step), sin(from0 + step)) * (clearance * 1.06);
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
      // The companion's own body counts too, or its sprite overlaps the
      // enemy it is fighting.
      final baseGap = max(
        _familyMinimumEnemyGap(comp, family),
        _companionBodyRadius(comp) + 6,
      );
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

    // Keep clear of the other companions by both bodies, not by a fixed
    // radius smaller than the creatures themselves.
    final body = _companionBodyRadius(comp);
    var separation = Offset.zero;
    for (final entry in activeCompanions.entries) {
      if (entry.key == slotIndex) continue;
      final other = entry.value;
      if (other.isDead) continue;
      final want = body + _companionBodyRadius(other) + 12;
      final delta = resolved - other.position;
      final dist = delta.distance;
      if (dist >= want) continue;
      final away = dist > 0.001
          ? Offset(delta.dx / dist, delta.dy / dist)
          : Offset(cos(slotIndex * 2.4), sin(slotIndex * 2.4));
      separation += away * (want - dist);
    }
    resolved += separation;

    // And off the ship's hull.
    final fromShip = resolved - ship.position;
    final shipDist = fromShip.distance;
    final shipClear = _shipHullRadius + body + 10;
    if (shipDist < shipClear && !ship.isDead) {
      resolved = shipDist > 0.001
          ? ship.position + fromShip / shipDist * shipClear
          : ship.position + Offset(0, -shipClear);
    }

    return resolved;
  }

  // Effective stats = the companion's raw stat plus all powerup/keystone
  // bonuses. Every derived combat value (HP, attack, defense, range,
  // cooldown, movement, special-ability scaling) reads from these so a
  // "+Strength" pick flows consistently into everything Strength touches.
  double _effectiveStrength(int slotIndex) => max(
    0.5,
    party[slotIndex].statStrength +
        powerUps.strengthBonus(slotIndex, party[slotIndex].statStrength),
  );

  double _effectiveIntelligence(int slotIndex) => max(
    0.5,
    party[slotIndex].statIntelligence +
        powerUps.intelligenceBonus(
          slotIndex,
          party[slotIndex].statIntelligence,
        ),
  );

  double _effectiveBeauty(int slotIndex) =>
      max(
        0.5,
        party[slotIndex].statBeauty +
            powerUps.beautyBonus(slotIndex, party[slotIndex].statBeauty),
      );

  double _effectiveSpeed(int slotIndex) =>
      max(
        0.5,
        party[slotIndex].statSpeed +
            powerUps.speedBonus(slotIndex, party[slotIndex].statSpeed),
      );

  // Movement speed steps through 5 tiers as the effective Speed stat rises.
  double _speedMovementMultiplier(double effectiveSpeed) {
    if (effectiveSpeed < 1.0) return 130.0 / 160.0;
    if (effectiveSpeed < 2.0) return 145.0 / 160.0;
    if (effectiveSpeed < 3.0) return 1.0;
    if (effectiveSpeed < 4.0) return 178.0 / 160.0;
    return 198.0 / 160.0;
  }

  // Derives a companion's combat stats from its effective stats, family
  // frame and permanent guardian upgrades. Used both when a companion is
  // summoned and when a stat powerup is picked mid-run.
  AlchemonCombatStats _deriveCompanionStats(int slotIndex) {
    double guardianUpgradeValue(GuardianUpgrade u) {
      final lvl = upgradeState.getGuardianLevel(u);
      if (lvl <= 0) return 0.0;
      return getGuardianUpgradeDef(u).valuePerLevel[lvl - 1];
    }

    final member = party[slotIndex];
    return deriveAlchemonCombatStats(
      member: member,
      strengthBonus: powerUps.strengthBonus(slotIndex, member.statStrength),
      intelligenceBonus: powerUps.intelligenceBonus(
        slotIndex,
        member.statIntelligence,
      ),
      beautyBonus: powerUps.beautyBonus(slotIndex, member.statBeauty),
      speedBonus: powerUps.speedBonus(slotIndex, member.statSpeed),
      guardianUpgradeValue: guardianUpgradeValue,
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
      companion.abilityAtk = stats.abilityAtk;
      companion.physDef = stats.physDef;
      companion.elemDef = stats.elemDef;
      companion.cooldownReduction = stats.cooldownReduction;
      companion.specialCooldownReduction = stats.specialCooldownReduction;
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
    anchor = _keepOffOrb(anchor, _familyOrbClearance(family));

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
      // Zoned families orbit the orb continuously, a ring per zone turning at
      // its own speed so the patrol feels alive. Everyone on a ring takes an
      // even share of it, in the order they already stand round it, and a
      // crowded ring widens within its zone, so five kins spread round the
      // inner ring instead of bunching where their party slots put them.
      final orbitSpeed = switch (family) {
        'wing' => 0.35, // fast sweep around outer edge
        'mane' || 'mask' => 0.20, // moderate patrol
        _ => 0.15, // inner families patrol slowly
      };
      final phase = stats.timeElapsed * orbitSpeed;
      final ring = <CosmicSurvivalCompanion>[];
      var ringBody = 0.0;
      for (final other in activeCompanions.values) {
        if (other.isDead || other.tethered) continue;
        if (_familyPatrolZone(other.member.family.toLowerCase()) != zone) {
          continue;
        }
        ring.add(other);
        ringBody = max(ringBody, _companionBodyRadius(other));
      }
      final self = activeCompanions[slotIndex];
      if (self != null && !ring.contains(self)) ring.add(self);
      final n = max(1, ring.length);
      final needed = n * (2 * ringBody + 24) / (2 * pi);
      final radius = max(
        (zone.$1 + zone.$2) / 2,
        needed,
      ).clamp(zone.$1, zone.$2);
      final place = self == null ? 0 : _ringPlace(self, ring, phase);
      // Each keeps its share of the ring, swaying round it and in and out at
      // its own pace, so the ring does not turn like one rigid wheel. Only by
      // as much room as the ring has spare: a ring packed body to body
      // barely sways, so neighbours never sway into each other.
      final share = 2 * pi * radius / n;
      final slack = max(0.0, share - (2 * ringBody + 24));
      final sway = min(0.22, 0.45 * slack / radius);
      final breathe = min(0.06, 0.4 * slack / share);
      final t = stats.timeElapsed;
      final angle =
          phase +
          place * (2 * pi / n) +
          sway * sin(t * (0.45 + 0.13 * place) + slotIndex * 2.4);
      final r =
          (radius * (1 + breathe * sin(t * (0.37 + 0.09 * place) + slotIndex)))
              .clamp(zone.$1, zone.$2);
      return Offset(
        orb.position.dx + cos(angle) * r,
        orb.position.dy + sin(angle) * r,
      );
    }
    // "Wherever" families (pip, mystic): orbit the ship loosely, on an arc
    // above it, spaced by body and far enough out to clear its hull.
    final group = <CosmicSurvivalCompanion>[];
    var groupBody = 0.0;
    for (final other in activeCompanions.values) {
      if (other.isDead || other.tethered) continue;
      if (_familyPatrolZone(other.member.family.toLowerCase()) != null) {
        continue;
      }
      group.add(other);
      groupBody = max(groupBody, _companionBodyRadius(other));
    }
    final self = activeCompanions[slotIndex];
    if (self != null && !group.contains(self)) group.add(self);
    final radius = max(110.0, _shipHullRadius + 50 + groupBody);
    final step = max(0.9, (2 * groupBody + 24) / radius);
    const top = -pi / 2;
    var rank = 0;
    if (self != null) {
      final mine = _angleFrom(self.position - ship.position, top);
      for (final other in group) {
        if (identical(other, self)) continue;
        if (_angleFrom(other.position - ship.position, top) < mine) rank++;
      }
    }
    final angle = top + (rank - (group.length - 1) / 2) * step;
    return Offset(
      ship.position.dx + cos(angle) * radius,
      ship.position.dy + sin(angle) * radius,
    );
  }

  /// The ship's hull, for keeping companions off it.
  static const double _shipHullRadius = 24.0;

  /// The creature's radius on screen: it is drawn in a 62.4 box scaled by
  /// its family and size genes, and fills about two thirds of that.
  double _companionBodyRadius(CosmicSurvivalCompanion comp) =>
      62.4 *
      (_companionSpeciesScale[comp.member.family.toLowerCase()] ?? 1.3) *
      (comp.member.spriteVisuals?.scale ?? 1.0) *
      0.34;

  /// [v]'s angle measured from [reference], in (-pi, pi].
  double _angleFrom(Offset v, double reference) {
    var a = atan2(v.dy, v.dx) - reference;
    while (a > pi) {
      a -= 2 * pi;
    }
    while (a <= -pi) {
      a += 2 * pi;
    }
    return a;
  }

  /// Which of a ring's [ring].length even places [comp] takes: the ring's
  /// members keep the cyclic order they stand in, turned to whichever of the
  /// n shifts moves them least, so nobody crosses a ring-mate to reach its
  /// place.
  int _ringPlace(
    CosmicSurvivalCompanion comp,
    List<CosmicSurvivalCompanion> ring,
    double phase,
  ) {
    final n = ring.length;
    if (n <= 1) return 0;
    final spacing = 2 * pi / n;
    double around(CosmicSurvivalCompanion c) {
      final a = _angleFrom(c.position - orb.position, phase);
      return a < 0 ? a + 2 * pi : a;
    }

    final order = List<CosmicSurvivalCompanion>.of(ring)
      ..sort((a, b) => around(a).compareTo(around(b)));
    var bestShift = 0;
    var bestCost = double.infinity;
    for (var shift = 0; shift < n; shift++) {
      var cost = 0.0;
      for (var i = 0; i < n; i++) {
        cost += _angleFrom(
          order[i].position - orb.position,
          phase + ((i + shift) % n) * spacing,
        ).abs();
      }
      if (cost < bestCost) {
        bestCost = cost;
        bestShift = shift;
      }
    }
    return (order.indexOf(comp) + bestShift) % n;
  }

  /// [comp]'s place among the companions fighting the same target: its rank
  /// in the order they stand round it (measured from [baseAngle]), how many
  /// share it, and the biggest body among them.
  ({int rank, int count, double groupBody}) _companionFanPlace(
    CosmicSurvivalCompanion comp,
    Offset targetPos,
    double baseAngle,
  ) {
    final target = comp.engagedTarget;
    var rank = 0;
    var count = 1;
    var groupBody = _companionBodyRadius(comp);
    if (target == null) return (rank: 0, count: 1, groupBody: groupBody);
    final mine = _angleFrom(comp.position - targetPos, baseAngle);
    for (final other in activeCompanions.values) {
      if (identical(other, comp) || other.isDead) continue;
      if (!identical(other.engagedTarget, target)) continue;
      count++;
      groupBody = max(groupBody, _companionBodyRadius(other));
      if (_angleFrom(other.position - targetPos, baseAngle) < mine) rank++;
    }
    return (rank: rank, count: count, groupBody: groupBody);
  }

  /// Held where it stands by its own ability: a horn mid-charge, a wing
  /// charging its beam, a horn holding its Light barrier.
  bool _companionHeldInPlace(int slotIndex, CosmicSurvivalCompanion comp) {
    if (comp.chargeTimer > 0) return true;
    if (_activeWingBeams.any(
      (b) => b.sourceSlotIndex == slotIndex && b.chargeTimer > 0,
    )) {
      return true;
    }
    return comp.member.family.toLowerCase() == 'horn' &&
        comp.member.element == 'Light' &&
        _hornLightBarrierActive(slotIndex);
  }

  /// Bodies that overlap anyway (stations meeting as targets move, a charge
  /// landing on a partner) are eased apart each frame, so nothing stays
  /// stacked, and off the ship's hull. One held in place by its own ability
  /// does not move; its partner takes the whole push.
  void _separateCompanionBodies(double dt) {
    if (activeCompanions.isEmpty || dt <= 0) return;
    final slots = activeCompanions.keys.toList();
    final rate = min(1.0, 8.0 * dt);
    // Nor over the ship: the player has to be able to see it. It does not
    // give way; the companion does.
    if (!ship.isDead) {
      for (final slot in slots) {
        final c = activeCompanions[slot]!;
        if (c.isDead || _companionHeldInPlace(slot, c)) continue;
        final clear = _shipHullRadius + _companionBodyRadius(c) * 0.8;
        final off = c.position - ship.position;
        final dist = off.distance;
        if (dist >= clear) continue;
        final away = dist > 0.5
            ? off / dist
            : Offset(cos(slot * 2.4), sin(slot * 2.4));
        c.position = _clampToArena(
          c.position + away * ((clear - dist) * rate),
          padding: 25,
        );
      }
    }
    if (slots.length < 2) return;
    for (var i = 0; i < slots.length; i++) {
      final a = activeCompanions[slots[i]]!;
      if (a.isDead) continue;
      for (var j = i + 1; j < slots.length; j++) {
        final b = activeCompanions[slots[j]]!;
        if (b.isDead) continue;
        final want = _companionBodyRadius(a) + _companionBodyRadius(b) + 4;
        final delta = b.position - a.position;
        final dist = delta.distance;
        if (dist >= want) continue;
        final heldA = _companionHeldInPlace(slots[i], a);
        final heldB = _companionHeldInPlace(slots[j], b);
        if (heldA && heldB) continue;
        final axis = dist > 0.5
            ? delta / dist
            : Offset(cos(slots[j] * 2.4), sin(slots[j] * 2.4));
        final push = (want - dist) * rate;
        final shareA = heldA ? 0.0 : (heldB ? 1.0 : 0.5);
        final shareB = 1.0 - shareA;
        a.position = _clampToArena(
          a.position - axis * (push * shareA),
          padding: 25,
        );
        b.position = _clampToArena(
          b.position + axis * (push * shareB),
          padding: 25,
        );
      }
    }
  }

  double _familyPreferredDistance(CosmicSurvivalCompanion comp, String family) {
    return switch (family) {
      'horn' => comp.attackRange * 0.38,
      'mane' => comp.attackRange * 0.55,
      // A dart thrower, not a brawler: it stood at 0.42, closer than every
      // family but the Horn (2026-10-20).
      'pip' => comp.attackRange * 0.80,
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
      // Mane is the family that is supposed to clear a wave; Wing could
      // answer every problem in the scorecard at once, which left the others
      // with nothing that was theirs. Reach stays Wing's — the damage behind
      // it comes down a little.
      // 1.12 until 2026-10-20: the trash bonus on the family that already
      // took 38-40% of a party's damage at every band ("still the clearer,
      // not the whole show").
      'mane' => vsBoss ? 1.0 : kSurvivalManeTrashDamage,
      'wing' => vsBoss ? 1.0 : 0.88,
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
      // Pip was 1.15 on top of the frailest frame (HP 0.80, defences
      // 0.80/0.85), and it is the one family with no ring: it fights where
      // the ship takes it, which late in a run is the front. At Potential
      // 80 it was down for a third of the wave or more, to brute siege beams
      // and volatile bursts of 200-400 a hit against its ~900 health, and a
      // party with a Pip held 27% of waves against 47% without one
      // (2026-10-20 family probe). Its health over what it takes now sits
      // between the ringed damage families' (about 1.1) and the tanks'
      // (1.7-1.8) at about 1.45; the frame keeps it the frailest in the
      // battle and open space.
      'pip' => 0.55,
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
      (rawDamage *
              takenMult *
              phaseMult *
              barrierMult *
              _hornShieldWallMultiplier(comp) *
              _firmamentMitigation(comp.position))
          .round(),
    );
    // A Bastion spends its own guard shield before its hit points, and the
    // hit that breaks the shield is the one Last Stand ruptures on.
    if (comp.slotIndex >= 0 && _isMasteryHorn(comp.slotIndex)) {
      _applyHornGuardedDamage(comp.slotIndex, comp, damageTaken.toDouble());
    } else {
      comp.takeDamage(damageTaken);
    }
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
      abilityAtk: stats.abilityAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      specialCooldownReduction: stats.specialCooldownReduction,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
      tethered: tetherModeEnabled && tetheredCompanionSlot == null,
    );
    companion.primeSpecialCooldown(savedCooldown: savedSpecialCooldown);
    // Same shortcut on the opening wait, or the first cast of a run still
    // costs the full Mystic cadence before anything can be judged.
    companion.specialCooldown = _mysticCastCooldown(
      companion,
      companion.specialCooldown,
    );
    activeCompanions[slotIndex] = companion;
    deployedCompanionSlots.add(slotIndex);
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
    final sheet = sheetForVisuals(member.spriteSheet, member.spriteVisuals);
    if (sheet == null) {
      _companionTickers.remove(slotIndex);
      _companionVisuals.remove(slotIndex);
      return;
    }
    final image = await loadCreatureSheet(images, sheet.path);
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
    final desiredSize = 62.4;
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
      // A Mystic pulled out takes its world with it, and gets its cast back on
      // a normal cooldown. That trade IS the mechanic: the ability is only
      // available to someone who has not yet spent it here.
      if (comp.member.family.toLowerCase() == 'mystic') {
        _closeMysticEnvironment(slotIndex);
        if (isMysticFieldSpent(slotIndex)) {
          _extinguishMysticField(slotIndex);
          comp.specialCooldown = comp.effectiveSpecialCooldown;
        }
      }
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

  // == Menders =============================================================
  //
  // EnemyTrait.mender: a body that holds back and mends the wounded around
  // it. Each pulse sends a flow of its grains into the most wounded bodies
  // near it, and the heal lands when the flow arrives. It never mends itself
  // or another mender, and a body it mended cannot be mended again until a
  // pulse later, so a pack of them spreads its heals rather than stacking
  // them and killing one always pays. A burning body takes half.

  final List<_Mend> _mends = [];
  final List<CosmicSurvivalEnemy> _menderPicks = [];

  /// The menders on the field as of this frame's update, for the painter.
  final List<CosmicSurvivalEnemy> _livingMenders = [];
  final MenderFlows _menderFlows = MenderFlows();

  void _tickMender(CosmicSurvivalEnemy mender, double dt) {
    mender.menderPulseTimer -= dt;
    if (mender.menderPulseTimer > 0) return;
    // Nothing near it is hurt: it stays charged and looks again shortly.
    mender.menderPulseTimer = _menderPulse(mender) > 0
        ? CosmicSurvivalBalance.menderPulseInterval
        : 0.3;
  }

  /// Sends one pulse; returns how many bodies it is mending.
  int _menderPulse(CosmicSurvivalEnemy mender) {
    const range = CosmicSurvivalBalance.menderHealRange;
    final picks = _menderPicks..clear();
    _visitEnemiesNear(mender.position, range, (other) {
      if (other.isMender || other.isPlagueCore || other.mendLock > 0) {
        return false;
      }
      if (other.hpFraction >= 0.98 ||
          !_withinRange(mender.position, other.position, range)) {
        return false;
      }
      picks.add(other);
      return false;
    }, exclude: mender);
    if (picks.isEmpty) return 0;
    // The most health missing first: what a heal is worth most to, which is
    // the heavy body the team has been working on, not a scratched wisp.
    picks.sort((a, b) => (b.maxHp - b.hp).compareTo(a.maxHp - a.hp));
    final count = min(
      picks.length,
      CosmicSurvivalBalance.menderTargetsPerPulse,
    );
    final color = elementColor(mender.element);
    for (var i = 0; i < count; i++) {
      final body = picks[i];
      // A beat short of a whole pulse, so a lone mender working one body
      // is not a frame late for it every time.
      body.mendLock = CosmicSurvivalBalance.menderPulseInterval - 0.25;
      _mends.add(
        _Mend(
          body,
          body.maxHp * CosmicSurvivalBalance.menderHealShare,
          CosmicSurvivalBalance.menderMendTravel,
        ),
      );
      _menderFlows.send(
        mender,
        body,
        color,
        CosmicSurvivalBalance.menderMendTravel,
      );
    }
    picks.clear();
    return count;
  }

  /// Lands the mends whose flow has arrived.
  void _updateMends(double dt) {
    _menderFlows.update(dt);
    if (_mends.isEmpty) return;
    for (final mend in _mends) {
      mend.eta -= dt;
      if (mend.eta <= 0) _healEnemy(mend.body, mend.amount);
    }
    _mends.removeWhere((mend) => mend.eta <= 0);
  }

  /// Every heal a survival body receives comes through here, a mender's and
  /// a vampiric elite's alike, so Burn halves all of them. Returns what
  /// landed.
  double _healEnemy(CosmicSurvivalEnemy enemy, double amount) {
    if (amount <= 0 || enemy.isDead) return 0;
    final before = enemy.hp;
    enemy.hp = min(enemy.maxHp, enemy.hp + enemy.healingReceived(amount));
    return enemy.hp - before;
  }

  /// A Fire or Lava burn landed: the body burns for [kBurnSeconds] from now.
  void _burnEnemy(CosmicSurvivalEnemy enemy) {
    enemy.burnTimer = kBurnSeconds;
  }

  /// Whether the abilities of the Alchemon in [slot] burn: Fire and Lava.
  bool _burnsWhatItHits(int? slot) {
    if (slot == null || slot < 0 || slot >= party.length) return false;
    final element = party[slot].element;
    return element == 'Fire' || element == 'Lava';
  }

  /// Lands [effect] on [enemy] as an ability would from [origin].
  @visibleForTesting
  void debugApplyAbilityEffect(
    AbilityEffectKind effect,
    CosmicSurvivalEnemy enemy, {
    double power = 1,
    Offset? origin,
  }) => _applyAbilityEffectToEnemy(
    effect,
    enemy,
    origin ?? enemy.position,
    power,
    0,
    0,
  );

  /// Heals [enemy] through the one heal path, as a mender or a vampiric elite
  /// would. Returns what landed.
  @visibleForTesting
  double debugHealEnemy(CosmicSurvivalEnemy enemy, double amount) =>
      _healEnemy(enemy, amount);

  @visibleForTesting
  int get debugMendsInFlight => _mends.length;

  @visibleForTesting
  MenderFlows get debugMenderFlows => _menderFlows;

  // == Enemies =============================================================

  void _updateEnemies(double dt, _ProjectileControlBuckets controlBuckets) {
    // After the casts, before anything picks a target or lands a blow.
    _refreshKinDarkVeil();
    // A Dust world's haze, read once a frame: the chance a body walking to
    // its target loses it each time it looks for one.
    final hazeSlot = _activeMysticWorldSlot('Dust');
    final hazeChance = hazeSlot == null ? 0.0 : _mysticHazeChance(hazeSlot);
    // Cached once per frame: any active Horn+Light barrier center+radius.
    // Enemies touching the perimeter get bounced back out.
    final lightBarrier = _activeHornLightBarrier();
    _updateMends(dt);
    _livingMenders.clear();
    // Variants can append enemies while the current wave is being updated.
    // Iterate a snapshot so new spawns join cleanly on the next frame.
    for (final enemy in List<CosmicSurvivalEnemy>.of(enemies)) {
      if (enemy.isDead) continue;
      if (enemy.burnTimer > 0) enemy.burnTimer = max(0, enemy.burnTimer - dt);
      if (enemy.mendLock > 0) enemy.mendLock = max(0, enemy.mendLock - dt);

      // Horn+Light barrier: bounce enemies away from the perimeter.
      // Per design "enemies bounce off of it" — anyone inside the
      // barrier zone gets pushed radially outward each frame.
      if (lightBarrier != null && !enemy.isPlagueCore) {
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

      // Payload statuses tick inside the loop that is already walking every
      // body, rather than in a second pass over the same list.
      if (mastery.enabled) {
        final dot = enemy.tickMasteryStatuses(dt);
        if (dot > 0) {
          _damageEnemy(
            enemy,
            dot,
            sourceSlotIndex: enemy.masteryDotSlot,
            masterySource: MasteryDamageSource.mastery,
          );
          if (enemy.isDead) continue;
        }
      }

      enemy.slowTimer = (enemy.slowTimer - dt).clamp(0, 100);
      if (enemy.slowTimer <= 0 && enemy.maneRootTimer <= 0) {
        enemy.slowMultiplier = 0.5;
      }
      enemy.hitFlash = (enemy.hitFlash - dt * 4).clamp(0, 1);
      enemy.attackCooldown = max(0, enemy.attackCooldown - dt);
      enemy.retargetTimer = max(0, enemy.retargetTimer - dt);
      // Signature action: idle → windUp → commit → recover.
      _updateEnemyAction(enemy, dt);
      if (enemy.disorientTimer > 0) {
        enemy.disorientTimer = max(0, enemy.disorientTimer - dt);
      }
      if (enemy.mysticHazeLostTimer > 0) {
        enemy.mysticHazeLostTimer = max(0, enemy.mysticHazeLostTimer - dt);
      }
      if (enemy.hornPlantRootTimer > 0) {
        enemy.hornPlantRootTimer = max(0, enemy.hornPlantRootTimer - dt);
      }
      // Wing+Ice: frost slowly thaws once the beam is off the enemy. It used
      // to thaw every frame, under the beam too, and took back more than the
      // ticks laid down, so a held beam never froze anything (2026-10-20
      // audit).
      if (enemy.frostGrace > 0) {
        enemy.frostGrace = max(0.0, enemy.frostGrace - dt);
      } else if (enemy.frostBuildup > 0) {
        enemy.frostBuildup = max(0.0, enemy.frostBuildup - dt * 0.35);
      }
      // Summoner variant pulses out small wisp swarms on a fixed cooldown.
      // Trait, not variant: a summoner wisp summons now.
      if (enemy.trait == EnemyTrait.summoner) {
        enemy.summonCooldown = max(0, enemy.summonCooldown - dt);
        // The old flat 220 ceiling silenced every broodmother on a horde
        // wave; the field's own limit is the right bound.
        if (enemy.summonCooldown <= 0 &&
            enemies.length < spawner.activeLimitNow) {
          enemy.summonCooldown = CosmicSurvivalBalance.broodInterval;
          final adds = spawner.spawnSummonerWisps(
            enemy,
            count: CosmicSurvivalBalance.broodBurst,
          );
          enemies.addAll(adds);
          // Flash + sparkle so the player sees what happened.
          _spawnHitSpark(enemy.position, elementColor(enemy.element));
        }
      }
      if (enemy.isMender) {
        _livingMenders.add(enemy);
        _tickMender(enemy, dt);
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
          // The tag is permanent and every tagged enemy emits, so this is the
          // one effect in the game whose output scales with the size of the
          // WAVE rather than with what the player did. Thirteen live puffs per
          // enemy against a 220-slot list shared with every trap, ward and
          // pool means a long fight could quietly leave no room for anything
          // else. Budgeted so the trail can never own the field.
          //
          // (Until the pip-dart narrowing above, this never came up: the puffs
          // were being consumed on spawn, so the trail did not exist at all.)
          _pipMudPuffScanTimer -= dt;
          if (_pipMudPuffScanTimer <= 0) {
            _pipMudPuffScanTimer = 0.25;
            _pipMudPuffCount = companionProjectiles
                .where(
                  (p) =>
                      p.abilityFamily == 'pip' &&
                      p.element == 'Mud' &&
                      p.stationary,
                )
                .length;
          }
          // Guarded rather than `continue`d: the rest of this enemy's frame
          // (Mask+Blood drain and the like) still has to run.
          if (_pipMudPuffCount < kPipMudTrailBudget) {
            _pipMudPuffCount++;
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
      }

      // Mask+Blood permanent drain: enemies tagged by the blood blob
      // bleed HP every frame; drained HP is split as healing across
      // all alchemons until the enemy dies. Cheap per-enemy tick — no
      // radius scan needed because the tag is sticky. Spawns drifting
      // red wisps from the enemy toward the nearest ally so the
      // player can see which enemies are bleeding for them.
      if (enemy.maskBloodDrainSlot != null && !enemy.isDead) {
        final drainPerSec = maskBloodDrainPerSecond(enemy.maxHp);
        final before = enemy.hp;
        _damageEnemy(
          enemy,
          drainPerSec * dt,
          sourceSlotIndex: enemy.maskBloodDrainSlot,
        );
        final drained = before - max(0.0, enemy.hp);
        if (drained > 0) {
          _healMaskBloodDrain(
            drained * kMaskBloodHealShare,
            enemy.maskBloodDrainSlot,
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
          emitMaskBloodDrainWisp(
            from: enemy.position,
            toward: target,
            rng: _rng,
            emit: _emitVfxParticle,
          );
        }
        if (enemy.isDead) enemy.maskBloodDrainSlot = null;
      }

      // Plague roots receive status damage above, but never chase or attack.
      if (enemy.isPlagueCore) continue;

      // Smooth knockback integration keeps pulse/Detonation push readable.
      if (enemy.knockbackVelocity.distanceSquared > 0.01) {
        enemy.position = Offset(
          enemy.position.dx +
              enemy.knockbackVelocity.dx * dt * _timeDilationSlowFactor,
          enemy.position.dy +
              enemy.knockbackVelocity.dy * dt * _timeDilationSlowFactor,
        );
        final damping = exp(-CosmicAbilityRuntime.knockbackDamping * dt);
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
        if (hazeChance > 0) _loseWayInHaze(enemy, hazeSlot!, hazeChance);
      }

      if (_applyProjectileLureControl(enemy, dt, controlBuckets.lures)) {
        _applyEnemyContactDamage(enemy, dt);
        _applyDecoyContactDamage(enemy, controlBuckets.decoys);
        continue;
      }

      final targetPos = _targetPositionForEnemy(enemy);
      var dir = targetPos - enemy.position;
      // Lost in a Dust world's haze: for a moment the body walks off its
      // true heading ([_loseWayInHaze]).
      if (enemy.mysticHazeLostTimer > 0) {
        final c = cos(enemy.mysticHazeHeading);
        final s = sin(enemy.mysticHazeHeading);
        dir = Offset(dir.dx * c - dir.dy * s, dir.dx * s + dir.dy * c);
      }
      final dist = dir.distance;

      // Floaty hover/dive steering (shared with dungeons/space) for melee
      // chasers hunting MOBILE targets. Orb-siege enemies, shooters,
      // orbiters and crushers keep their authored movement so siege
      // pressure and standoff behaviour are unchanged.
      final usesFlightSteering =
          (enemy.conduct == EnemyConduct.charge ||
              enemy.conduct == EnemyConduct.stalk) &&
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
          speed: enemy.effectiveSpeed * moveSpeedMult * _timeDilationSlowFactor,
          contactRange: enemy.radius + 14,
          dt: dt,
          rng: _rng,
        );
        enemy.position += tick.velocity * dt;
        enemy.angle = flightHeading(
          steering,
          dir,
          fallback: dist > 0.001 ? atan2(dir.dy, dir.dx) : enemy.angle,
        );
        // Ship contact damage is grind-DPS (dt-scaled); a dive only brushes
        // it, so the landed dive itself delivers an impact burst (~0.8s of
        // the old grind) to keep melee pressure honest.
        if (tick.impact &&
            enemy.target == CosmicEnemyTarget.ship &&
            !ship.isDead &&
            _withinRange(enemy.position, ship.position, enemy.radius + 30)) {
          final damageMultiplier = powerUps.hasMirrorShield ? 0.75 : 1.0;
          ship.currentHp -=
              enemy.damage * 0.6 * damageMultiplier * _shipBodyDamageTaken;
          ship.hitFlash = 1.0;
          if (enemy.isVampiric) _healEnemy(enemy, enemy.damage * 0.24);
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
        // A body performing its signature action plants itself — the stop is
        // half the telegraph. Conduct still owns the vector otherwise.
        final actDef = kEnemyActions[enemy.tier];
        final planted =
            actDef != null &&
            ((enemy.action.phase == EnemyActionPhase.windUp &&
                    actDef.freezesDuringWindUp) ||
                (enemy.action.phase == EnemyActionPhase.commit &&
                    actDef.freezesDuringCommit));
        // Conduct is the sole movement authority now — no variant override.
        final move = planted
            ? Offset.zero
            : conductMoveVector(
                conduct: enemy.conduct,
                dist: dist,
                norm: norm,
                tangent: tangent,
                siegeHold: enemy.isMender
                    ? CosmicSurvivalBalance.menderHoldRange
                    : CosmicSurvivalBalance.artilleryHoldRange,
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

      // Artillery shells from its hold; ordinary shooters still have to come
      // to 300.
      final firingRange = enemy.isSiegeArtillery
          ? CosmicSurvivalBalance.artilleryHoldRange + 160
          : 300;
      if (enemy.isShooter &&
          enemy.attackCooldown <= 0 &&
          dist < firingRange &&
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
        final isSiegeShooter = enemy.conduct == EnemyConduct.standoff;
        // Inside a Dust world the round may go off in its own face. Checked
        // here, before the projectile exists, so the shot is spent — a haze
        // that redirected the shot instead would be Wing+Dust at a larger
        // size, and that ability already turns shooters on each other.
        final misfired = _mysticHazeMisfire(enemy);
        enemy.attackCooldown =
            _shooterCadence(enemy.tier) *
            // A shell is a slow, readable, heavy thing, not a stream.
            (enemy.isSiegeArtillery ? 2.6 : 1.0) *
            (isSiegeShooter ? 1.12 : 1.0) *
            (enemy.isRelentless ? 0.88 : 1.0) *
            ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                    spawner.currentMutator ==
                        SurvivalWaveMutator.shatteredSpace)
                ? 0.82
                : 1.0);
        // A round that never leaves the barrel is its own failure: the
        // shot is spent and nothing flies.
        if (!misfired) {
          enemyProjectiles.add(
            SurvivalEnemyProjectile(
              position: enemy.position,
              angle: shotAngle,
              element: enemy.element,
              friendlyFire: enemy.disorientTimer > 0,
              damage:
                  enemy.damage *
                  (enemy.isSiegeArtillery
                      ? CosmicSurvivalBalance.artilleryShellDamage
                      : 1.0) *
                  (isSiegeShooter ? 0.95 : 0.8) *
                  ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                          spawner.currentMutator ==
                              SurvivalWaveMutator.shatteredSpace)
                      ? 1.08
                      : 1.0),
              target: enemy.target,
              speed:
                  _shooterRoundSpeed(enemy.tier) *
                  (enemy.isSiegeArtillery ? 0.62 : 1.0) *
                  (isSiegeShooter ? 0.9 : 1.0) *
                  ((spawner.currentMutator == SurvivalWaveMutator.arcStorm ||
                          spawner.currentMutator ==
                              SurvivalWaveMutator.shatteredSpace)
                      ? 1.10
                      : 1.0),
              radius: enemy.isSiegeArtillery
                  ? 7.5
                  : isSiegeShooter
                  ? 5.3
                  : 4.0,
              life: enemy.isSiegeArtillery ? 11.0 : 4.0,
            ),
          );
        }
      }

      _applyEnemyContactDamage(enemy, dt);
      _applyDecoyContactDamage(enemy, controlBuckets.decoys);
    }

    enemies.removeWhere((e) => e.isDead);
  }

  CosmicEnemyTarget _pickEnemyTarget(CosmicSurvivalEnemy enemy) {
    // Kin+Dark veil: while any Dark kin's veil holds, the orb is hidden and
    // the companions are untargetable. A body that came for the orb goes
    // for the ship instead, so the horde is pulled off the orb for as long
    // as the player can fly the decoy. Artillery shells a position, not a
    // target, and is unaffected. Once the veil has lifted off a ship fallen
    // low (see [_refreshKinDarkVeil]) the orb is in sight again; the
    // companions stay hidden for the rest of the cast.
    final cloaked = _isAnyKinDarkCloakActive();
    final orbOrDecoy = cloaked && !_kinDarkVeilLifted && !ship.isDead
        ? CosmicEnemyTarget.ship
        : CosmicEnemyTarget.orb;
    if (spawner.currentMutator == SurvivalWaveMutator.orbSiege &&
        enemy.conduct != EnemyConduct.stalk) {
      return orbOrDecoy;
    }
    if (enemy.conduct == EnemyConduct.charge) return orbOrDecoy;
    // Artillery is a siege weapon: it is here for the orb, never the ship.
    if (enemy.conduct == EnemyConduct.siege) return CosmicEnemyTarget.orb;
    if (enemy.conduct == EnemyConduct.stalk && !ship.isDead) {
      final roll = _rng.nextDouble();
      if (roll < 0.25) return orbOrDecoy;
      if (roll < 0.65) return CosmicEnemyTarget.ship;
      return cloaked ? CosmicEnemyTarget.ship : CosmicEnemyTarget.companion;
    }
    if (enemy.conduct == EnemyConduct.standoff) {
      if (enemy.conduct == EnemyConduct.standoff && _rng.nextDouble() < 0.72) {
        return orbOrDecoy;
      }
      if (_rng.nextDouble() < 0.38) {
        return orbOrDecoy;
      }
      if (!cloaked && activeCompanions.isNotEmpty && _rng.nextDouble() < 0.55) {
        return CosmicEnemyTarget.companion;
      }
      return ship.isDead ? CosmicEnemyTarget.orb : CosmicEnemyTarget.ship;
    }
    if (!cloaked && activeCompanions.isNotEmpty && _rng.nextDouble() < 0.22) {
      return CosmicEnemyTarget.companion;
    }
    return orbOrDecoy;
  }

  bool _isAnyKinDarkCloakActive() {
    for (final comp in _kinSupportSources.map((e) => e.value)) {
      if (comp.kinDarkCloakTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Dark') {
        return true;
      }
    }
    return false;
  }

  // Kin+Dark veil, as this frame's bodies see it (see _refreshKinDarkVeil):
  // whether it is drawing them onto the ship, and whether it has lifted off
  // the ship until a Dark kin casts again.
  bool _kinDarkVeilDraws = false;
  bool _kinDarkVeilLifted = false;

  /// Kin+Dark: what the veil does this frame. It turns the bodies that came
  /// for the orb onto the ship, which has a hundred-odd points and a 30 s
  /// respawn; they killed it in about a second, and the veil stood inert
  /// through the respawn, cast after cast (2026-10-20 audit). So the veil
  /// shrouds the ship it draws them to (it takes
  /// [KinSupport.darkVeilShipDamageTaken] of their blows), and lifts when
  /// the ship falls under [KinSupport.darkVeilLiftFraction] of its hull:
  /// the bodies chasing it turn back to the orb at once, rather than kill
  /// the decoy, and the next cast draws them again.
  void _refreshKinDarkVeil() {
    final holds = _isAnyKinDarkCloakActive();
    if (holds &&
        !_kinDarkVeilLifted &&
        (ship.isDead ||
            ship.currentHp < ship.maxHp * KinSupport.darkVeilLiftFraction)) {
      _kinDarkVeilLifted = true;
      for (final enemy in enemies) {
        if (enemy.target == CosmicEnemyTarget.ship) enemy.retargetTimer = 0;
      }
    }
    _kinDarkVeilDraws = holds && !_kinDarkVeilLifted && !ship.isDead;
  }

  /// The share of a body's blow the ship takes: shrouded while a Dark veil
  /// draws the horde onto it.
  double get _shipBodyDamageTaken =>
      _kinDarkVeilDraws ? KinSupport.darkVeilShipDamageTaken : 1.0;

  /// Whether a Dark kin's veil is drawing the horde onto the ship.
  @visibleForTesting
  bool get debugKinDarkVeilDraws => _kinDarkVeilDraws;

  bool _isAnyKinLightningChargeActive() {
    for (final comp in _kinSupportSources.map((e) => e.value)) {
      if (comp.kinLightningChargeTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Lightning') {
        return true;
      }
    }
    return false;
  }

  bool _isAnyKinLavaPlateActive() {
    for (final comp in _kinSupportSources.map((e) => e.value)) {
      if (comp.kinLavaPlateTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Lava') {
        return true;
      }
    }
    return false;
  }

  bool _isInsideAnyKinDustCloud(Offset pos) =>
      KinSupport.insideDustCloud(companionProjectiles, pos);

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
        CosmicSurvivalBalance.orbContactDamage(
          enemy.damage * damageMultiplier * _orbImpactDamageMultiplier(enemy),
          orb.maxHp,
          heavy: enemy.hasHeavyBody,
          breaker: enemy.trait == EnemyTrait.breaker,
        ),
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
        ship.currentHp -= enemy.damage * dt * 0.75 * _shipBodyDamageTaken;
        ship.hitFlash = 1.0;
        if (enemy.isVampiric) _healEnemy(enemy, enemy.damage * dt * 0.4);
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
        if (enemy.isVampiric) _healEnemy(enemy, enemy.damage * 0.18);
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
      EnemyTrait.mender => 1.0,
      null => 1.0,
    };
    final conductMult = switch (enemy.conduct) {
      EnemyConduct.charge => enemy.hasHeavyBody ? 1.45 : 1.0,
      EnemyConduct.stalk => 1.15,
      EnemyConduct.standoff => 1.12,
      _ => 1.0,
    };
    final variantMult = traitMult * conductMult;
    final roleMult = enemy.conduct == EnemyConduct.orbit ? 1.15 : 1.0;
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

  // == Family Mastery combat events ========================================
  //
  // Phase 2 of docs/survival_species_mastery_design.md. Everything a mastery
  // node needs to observe combat and act on it lives between here and
  // [_applyPayloadToBoss]. Nodes themselves arrive in phases 3-5 and plug in
  // at [_onMasteryHit] and [_onMasteryKill]; they do not reach into the
  // combat loop, and they do not apply element behaviour themselves.

  /// A tracked projectile landing, after its damage has resolved.
  ///
  /// The hit arrives already accounted: whether it is the second blade of a
  /// pair on one body, whether the whole volley landed, which cast it belongs
  /// to. Family node reactions attach here.
  void _onMasteryHit(
    MasteryHit hit, {
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
  }) {
    // Family node reactions dispatch from here. Phases 4-5 add their own
    // branches; nothing else in the combat loop needs to know they exist.
    if (hit.family == CreatureFamily.mane) {
      _onManeHit(hit, enemy: enemy, boss: boss);
    } else if (hit.family == CreatureFamily.pip) {
      _onPipHit(hit, enemy: enemy, boss: boss);
    } else if (hit.family == CreatureFamily.wing) {
      _onWingHit(hit);
    }
  }

  /// A body dying, attributed to the cast that killed it when there was one.
  void _onMasteryKill(
    MasteryKill kill, {
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
  }) {
    final slotIndex = kill.slotIndex;
    if (slotIndex == null) return;
    if (mastery.equippedFor(slotIndex)?.family == CreatureFamily.mane) {
      _onManeKill(kill);
    }
  }

  /// Fires the caster's elemental payload on one body.
  ///
  /// This is the only way a payload may be applied. A node says when and how
  /// strongly; the element table says what happens. Routing every node
  /// through one function is what makes the shared rules — no recursion, no
  /// unbudgeted objects, one rate limiter — true for all 96 of them instead
  /// of true for whichever ones remembered.
  ///
  /// Returns whether the payload actually fired.
  bool triggerElementalPayload({
    required int slotIndex,
    required String effectId,
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
    double strength = 1.0,
    double triggeringDamage = 0,
    double procCooldown = 0,
  }) {
    if (!mastery.enabled) return false;
    if (enemy == null && boss == null) return false;
    if (enemy != null && enemy.isDead) return false;
    if (boss != null && boss.isDead) return false;
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.isDead) return false;

    final targetId = identityHashCode(enemy ?? boss);
    // The node's own rate limit, then the element's. Blood is the only
    // element that rate-limits itself, because its payload is a resource
    // rather than an effect on the target.
    if (!mastery.tryProc(
      slotIndex,
      effectId,
      procCooldown,
      targetId: targetId,
    )) {
      return false;
    }

    final payload = resolveElementalPayload(
      element: comp.member.element,
      elementalAttack: comp.elemAtk.toDouble(),
      strength: strength,
      vsBoss: boss != null,
      triggeringDamage: triggeringDamage,
    );
    if (payload.isEmpty) return false;
    if (payload.procCooldown > 0 &&
        !mastery.tryProc(
          slotIndex,
          'payload.${payload.element}',
          payload.procCooldown,
        )) {
      return false;
    }

    // A payload cannot trigger a payload. The guard is closed for the whole
    // application, so a thorn hit that kills, whose kill reaction would fire
    // another payload, finds it shut.
    return mastery.runGuarded<bool>(() {
      for (final action in payload.actions) {
        if (boss != null) {
          _applyPayloadToBoss(action, boss, slotIndex);
        } else {
          _applyPayloadToEnemy(action, enemy!, slotIndex);
        }
      }
      mastery.recordPayload(slotIndex);
      return true;
    }, orElse: false);
  }

  /// Turns one [PayloadAction] into survival's own status and damage fields.
  void _applyPayloadToEnemy(
    PayloadAction action,
    CosmicSurvivalEnemy enemy,
    int slotIndex,
  ) {
    switch (action.effect) {
      case PayloadEffect.damageOverTime:
        if (action.duration <= 0) break;
        final cap = action.maxStacks <= 0 ? 1 : action.maxStacks;
        if (enemy.masteryDotStacks < cap) enemy.masteryDotStacks++;
        // Stacks add rate, not duration: three Poison stacks burn three times
        // as fast for the same three seconds, which is what the table says
        // and what keeps a long fight from accruing a minute of pending DoT.
        enemy.masteryDotDps =
            (action.amount / action.duration) * enemy.masteryDotStacks;
        enemy.masteryDotTimer = max(enemy.masteryDotTimer, action.duration);
        enemy.masteryDotSlot = slotIndex;

      case PayloadEffect.directDamage:
        _damageEnemy(
          enemy,
          action.amount,
          sourceSlotIndex: slotIndex,
          masterySource: MasteryDamageSource.mastery,
        );

      case PayloadEffect.arc:
        var remaining = action.targets <= 0 ? 1 : action.targets;
        _visitEnemiesNear(enemy.position, action.radius, (other) {
          if (remaining <= 0) return true;
          if (identical(other, enemy) || other.isDead) return false;
          if (!_withinRange(enemy.position, other.position, action.radius)) {
            return false;
          }
          remaining--;
          _damageEnemy(
            other,
            action.amount,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
          return remaining <= 0;
        });

      case PayloadEffect.areaBurst:
        _damageEnemiesNear(
          enemy.position,
          action.radius,
          action.amount,
          sourceSlotIndex: slotIndex,
          masterySource: MasteryDamageSource.mastery,
        );

      case PayloadEffect.zone:
        // A patch is an object, so it comes out of mastery's budget. When the
        // budget is spent the patch is skipped rather than queued: a payload
        // that owes the world objects is the trap-chain bug in waiting.
        if (!mastery.requestObjects(1)) break;
        _appendCompanionProjectile(
          Projectile(
            position: enemy.position,
            angle: 0,
            element: activeCompanions[slotIndex]?.member.element,
            damage: 0,
            life: action.duration,
            stationary: true,
            radiusMultiplier: action.radius / Projectile.radius,
            visualScale: action.radius / 12.0,
            sourceSlotIndex: slotIndex,
            tickEffect: AbilityEffectKind.zoneDamage,
            effectPower: action.amount,
            effectRadius: action.radius,
            effectDuration: action.duration,
          )..masteryGenerated = true,
        );

      case PayloadEffect.slow:
        enemy.slowTimer = max(enemy.slowTimer, action.duration);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 1.0 - action.amount);
        mastery.recordControl(slotIndex, action.duration);

      case PayloadEffect.stagger:
      case PayloadEffect.root:
        // A hard stop is a slow to zero. Borrowing a family's own root field
        // would drag that family's visual along with it.
        enemy.slowTimer = max(enemy.slowTimer, action.duration);
        enemy.slowMultiplier = 0;
        if (action.effect == PayloadEffect.root) {
          enemy.attackCooldown = max(enemy.attackCooldown, action.duration);
        }
        mastery.recordControl(slotIndex, action.duration);

      case PayloadEffect.push:
      case PayloadEffect.pull:
        final origin = activeCompanions[slotIndex]?.position;
        if (origin == null) break;
        final delta = action.effect == PayloadEffect.push
            ? enemy.position - origin
            : origin - enemy.position;
        final dist = delta.distance;
        if (dist <= 0.01) break;
        // Knockback damps at exp(-7.5 dt), so total travel is v0 / 7.5.
        // Solving for the table's distance keeps "push 45 units" honest.
        enemy.knockbackVelocity += (delta / dist) * action.amount * 7.5;

      case PayloadEffect.interrupt:
        enemy.action.interrupt();
        enemy.attackCooldown = max(enemy.attackCooldown, 0.4);

      case PayloadEffect.chill:
        enemy.masteryChillTimer = max(enemy.masteryChillTimer, action.duration);
        enemy.masteryChillStacks++;
        final cap = action.maxStacks <= 0 ? 3 : action.maxStacks;
        if (enemy.masteryChillStacks >= cap) {
          enemy.masteryChillStacks = 0;
          enemy.masteryChillTimer = 0;
          enemy.slowTimer = max(enemy.slowTimer, action.followUpDuration);
          enemy.slowMultiplier = 0;
          mastery.recordControl(slotIndex, action.followUpDuration);
        } else {
          // Each stack is cold, not a freeze: a modest slow that the third
          // stack cashes in.
          enemy.slowTimer = max(enemy.slowTimer, action.duration);
          enemy.slowMultiplier = min(enemy.slowMultiplier, 0.82);
          mastery.recordControl(slotIndex, action.duration);
        }

      case PayloadEffect.haze:
        enemy.masteryHazeTimer = max(enemy.masteryHazeTimer, action.duration);
        enemy.masteryHazeAmount = max(enemy.masteryHazeAmount, action.amount);
        enemy.attackCooldown += enemy.attackCooldown * action.amount;
        mastery.recordControl(slotIndex, action.duration);

      case PayloadEffect.vulnerable:
        enemy.masteryVulnerableTimer = max(
          enemy.masteryVulnerableTimer,
          action.duration,
        );
        enemy.masteryVulnerableAmount = max(
          enemy.masteryVulnerableAmount,
          action.amount,
        );

      case PayloadEffect.allyAmp:
        enemy.masteryAmpTimer = max(enemy.masteryAmpTimer, action.duration);
        // Capped rather than summed: several Light sources on one body is a
        // party composition, not a multiplier.
        enemy.masteryAmpAmount = min(
          action.cap,
          enemy.masteryAmpAmount + action.amount,
        );

      case PayloadEffect.delayedEcho:
        if (action.amount <= 0) break;
        _masteryEchoes.add(
          _MasteryEcho(
            slotIndex: slotIndex,
            enemy: enemy,
            damage: action.amount,
            delay: action.followUpDuration,
          ),
        );

      case PayloadEffect.heal:
        final comp = activeCompanions[slotIndex];
        if (comp == null) break;
        final healed = _healCompanion(comp, comp.maxHp * action.amount);
        mastery.recordHealing(slotIndex, healed);
    }
  }

  /// The boss version. Bosses cannot be rooted, pushed or frozen, so those
  /// actions become the table's stated substitutes rather than nothing —
  /// "payload damage is not silently removed".
  void _applyPayloadToBoss(
    PayloadAction action,
    SurvivalBoss boss,
    int slotIndex,
  ) {
    switch (action.effect) {
      case PayloadEffect.damageOverTime:
        if (action.duration <= 0) break;
        final cap = action.maxStacks <= 0 ? 1 : action.maxStacks;
        if (boss.masteryDotStacks < cap) boss.masteryDotStacks++;
        boss.masteryDotDps =
            (action.amount / action.duration) * boss.masteryDotStacks;
        boss.masteryDotTimer = max(boss.masteryDotTimer, action.duration);
        boss.masteryDotSlot = slotIndex;

      case PayloadEffect.directDamage:
      case PayloadEffect.areaBurst:
        damageBoss(
          action.amount,
          sourceSlotIndex: slotIndex,
          target: boss,
          masterySource: MasteryDamageSource.mastery,
        );

      case PayloadEffect.arc:
        // The arc has to land on something other than its own target, and a
        // boss fight still has a crowd around it.
        var remaining = action.targets <= 0 ? 1 : action.targets;
        _visitEnemiesNear(boss.position, action.radius, (other) {
          if (remaining <= 0 || other.isDead) return remaining <= 0;
          remaining--;
          _damageEnemy(
            other,
            action.amount,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
          return remaining <= 0;
        });

      case PayloadEffect.zone:
        if (!mastery.requestObjects(1)) break;
        _appendCompanionProjectile(
          Projectile(
            position: boss.position,
            angle: 0,
            element: activeCompanions[slotIndex]?.member.element,
            damage: 0,
            life: action.duration,
            stationary: true,
            radiusMultiplier: action.radius / Projectile.radius,
            visualScale: action.radius / 12.0,
            sourceSlotIndex: slotIndex,
            tickEffect: AbilityEffectKind.zoneDamage,
            effectPower: action.amount,
            effectRadius: action.radius,
            effectDuration: action.duration,
            effectOnBoss: true,
          )..masteryGenerated = true,
        );

      case PayloadEffect.slow:
      case PayloadEffect.chill:
      case PayloadEffect.haze:
      case PayloadEffect.stagger:
      case PayloadEffect.root:
        // Bosses take every form of control as a chill on their movement,
        // which is the one channel their discipline AIs cannot write over.
        final amount = action.effect == PayloadEffect.slow
            ? action.amount
            : 0.15;
        final duration = action.duration > 0 ? action.duration : 0.5;
        boss.chillTimer = max(boss.chillTimer, duration);
        boss.chillMultiplier = min(boss.chillMultiplier, 1.0 - amount);
        mastery.recordControl(slotIndex, duration);

      case PayloadEffect.push:
      case PayloadEffect.pull:
      case PayloadEffect.interrupt:
        // Deliberately nothing: shoving a boss would break every discipline
        // AI's positioning, and a payload that does it once per cast would
        // do it constantly.
        break;

      case PayloadEffect.vulnerable:
        boss.masteryVulnerableTimer = max(
          boss.masteryVulnerableTimer,
          action.duration,
        );
        boss.masteryVulnerableAmount = max(
          boss.masteryVulnerableAmount,
          action.amount,
        );

      case PayloadEffect.allyAmp:
        boss.masteryAmpTimer = max(boss.masteryAmpTimer, action.duration);
        boss.masteryAmpAmount = min(
          action.cap,
          boss.masteryAmpAmount + action.amount,
        );

      case PayloadEffect.delayedEcho:
        if (action.amount <= 0) break;
        _masteryEchoes.add(
          _MasteryEcho(
            slotIndex: slotIndex,
            boss: boss,
            damage: action.amount,
            delay: action.followUpDuration,
          ),
        );

      case PayloadEffect.heal:
        final comp = activeCompanions[slotIndex];
        if (comp == null) break;
        final healed = _healCompanion(comp, comp.maxHp * action.amount);
        mastery.recordHealing(slotIndex, healed);
    }
  }

  /// Spirit's delayed echo. A small list rather than a projectile because the
  /// echo has no travel — it is the same hit, later.
  final List<_MasteryEcho> _masteryEchoes = [];

  void _updateMasteryEchoes(double dt) {
    if (_masteryEchoes.isEmpty) return;
    for (var i = _masteryEchoes.length - 1; i >= 0; i--) {
      final echo = _masteryEchoes[i];
      echo.delay -= dt;
      if (echo.delay > 0) continue;
      _masteryEchoes.removeAt(i);
      final enemy = echo.enemy;
      final boss = echo.boss;
      if (enemy != null && !enemy.isDead) {
        _damageEnemy(
          enemy,
          echo.damage,
          sourceSlotIndex: echo.slotIndex,
          masterySource: MasteryDamageSource.mastery,
        );
      } else if (boss != null && !boss.isDead) {
        damageBoss(
          echo.damage,
          sourceSlotIndex: echo.slotIndex,
          target: boss,
          masterySource: MasteryDamageSource.mastery,
        );
      }
    }
  }

  // == Let mastery (phase 4) ===============================================

  /// Per-slot Let state, created on demand and dropped on a run reset.
  final Map<int, LetMasteryState> _letMastery = {};

  LetMasteryState _letStateFor(int slotIndex) =>
      _letMastery.putIfAbsent(slotIndex, LetMasteryState.new);

  /// Read-only view of a Let's run state, for tests and the HUD.
  LetMasteryState? letMasteryFor(int slotIndex) => _letMastery[slotIndex];

  bool _isMasteryLet(int slotIndex) {
    if (!mastery.enabled) return false;
    return mastery.equippedFor(slotIndex)?.family == CreatureFamily.let;
  }

  /// Basic attack range multiplier from mastery (Ranging Shots).
  double _masteryAttackRangeMultiplier(int slotIndex) {
    if (!mastery.enabled) return 1.0;
    if (mastery.hasNode(slotIndex, LetNodes.rangingShots)) {
      return LetTuning.rangingShotsRangeScale;
    }
    // Longshot buys reach twice, and the whole path is read against it.
    return wingRangeMultiplier(hasNode: (id) => mastery.hasNode(slotIndex, id));
  }

  /// Reshapes a Let auto-attack for the equipped path: a denser rock or a
  /// comet (Falling Star), or a rock that falls instead of flying
  /// (Bombardment). Ground Zero leaves the throw alone — its work happens
  /// where the rock lands.
  List<Projectile> _applyLetBasicMastery(
    List<Projectile> basics,
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
    Offset? targetPos,
  ) {
    if (basics.isEmpty || !_isMasteryLet(slotIndex)) return basics;
    final state = _letStateFor(slotIndex);
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);
    state
      ..pendingMasteryDamageFraction = 0
      ..pendingComet = false;
    final denseCore = has(LetNodes.denseCore);
    final deadfall = has(LetNodes.deadfall) && targetPos != null;
    if (!denseCore && !deadfall) return basics;

    final seed = basics.first;
    var fraction = LetTuning.baseMeteorFraction;
    var size = 1.0;
    var speed = 1.0;
    if (denseCore) {
      fraction = LetTuning.denseCoreFraction;
      size *= LetTuning.denseCoreSizeScale;
      speed *= LetTuning.denseCoreSpeedScale;
    }
    final comet = has(LetNodes.extinctionEvent) && state.takeCometTurn();
    if (comet) {
      fraction = LetTuning.cometFraction;
      size *= LetTuning.cometSizeScale;
      mastery.recordCapstone(slotIndex);
    }
    state.pendingComet = comet;
    final uplift = fraction / LetTuning.baseMeteorFraction;
    state.pendingMasteryDamageFraction = uplift <= 1.0
        ? 0.0
        : (uplift - 1.0) / uplift;
    final damage = seed.damage * uplift;

    if (deadfall) {
      final drop = letSkyfallDrop(targetPos, fireAngle);
      final ordnance = has(LetNodes.heavyOrdnance);
      return [
        Projectile(
            position: drop.position,
            angle: drop.angle,
            element: seed.element,
            damage: damage,
            life: drop.duration + 0.4,
            speedMultiplier: 0,
            radiusMultiplier: seed.radiusMultiplier * size,
            visualScale: seed.visualScale * size,
            visualStyle: seed.visualStyle,
            skyfallDuration: drop.duration,
            skyfallImpact: targetPos,
            skyfallDistance: drop.distance,
          )
          ..letDeadfall = true
          ..letCraterRadius =
              LetTuning.deadfallCraterRadius *
              (ordnance ? LetTuning.heavyOrdnanceRadiusScale : 1.0)
          ..letCraterShare = ordnance
              ? LetTuning.heavyOrdnanceSplashShare
              : LetTuning.craterSplashShare,
      ];
    }

    final shot = Projectile(
      position: seed.position,
      angle: seed.angle,
      element: seed.element,
      damage: damage,
      life: seed.life,
      speedMultiplier: seed.speedMultiplier * speed,
      radiusMultiplier: seed.radiusMultiplier * size,
      visualScale: seed.visualScale * size,
      visualStyle: seed.visualStyle,
    );
    if (comet) {
      shot
        ..letCraterRadius = LetTuning.cometCraterRadius
        ..letCraterShare = LetTuning.craterSplashShare;
    }
    return [shot];
  }

  void _onLetBasicCast(int slotIndex, int castId) {
    if (castId == 0 || !_isMasteryLet(slotIndex)) return;
    if (_letStateFor(slotIndex).pendingComet) {
      mastery.cast(castId)?.tag(LetCastTags.comet);
    }
  }

  /// Skyreach: an auto-attack that falls on the toughest thing in the arena,
  /// wherever it is. Returns whether it fired.
  bool _tryFireLetSkyreach(CosmicSurvivalCompanion comp, int slotIndex) {
    if (comp.basicCooldown > 0) return false;
    if (!_isMasteryLet(slotIndex)) return false;
    if (!mastery.hasNode(slotIndex, LetNodes.skyreach)) return false;
    final target = _letSkyreachTarget();
    if (target == null) return false;

    final toTarget = target - comp.position;
    final fireAngle = atan2(toTarget.dy, toTarget.dx);
    _setCompanionAngle(comp, fireAngle, 0.12);
    comp.basicCooldown =
        comp.effectiveBasicCooldown *
        _masteryBasicCooldownMultiplier(slotIndex);
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
    final shaped = _applyLetBasicMastery(
      basics,
      comp,
      slotIndex,
      fireAngle,
      target,
    );
    final castId = mastery.beginCast(
      slotIndex: slotIndex,
      family: CreatureFamily.let,
      element: comp.member.element,
      kind: MasteryCastKind.basic,
      projectileCount: shaped.length,
      masteryDamageFraction: _masteryBasicUplift(slotIndex),
    );
    _onLetBasicCast(slotIndex, castId);
    final teslaActive = _isAnyKinLightningChargeActive();
    for (final projectile in shaped) {
      projectile.sourceSlotIndex = slotIndex;
      projectile.masteryCastId = castId;
      if (powerUps.companionHasChainLightning(slotIndex) || teslaActive) {
        projectile.chainLightningCharges = max(
          projectile.chainLightningCharges,
          teslaActive ? 3 : 2,
        );
      }
    }
    _appendCompanionProjectiles(shaped, cue: _basicCue(comp, shaped));
    // Only a throw the Let could not otherwise have made counts as the
    // capstone working.
    final reach = comp.attackRange * _masteryAttackRangeMultiplier(slotIndex);
    if (toTarget.distance > reach) mastery.recordCapstone(slotIndex);
    return true;
  }

  /// The toughest living thing in the arena: a boss if there is one,
  /// otherwise the enemy with the most health.
  Offset? _letSkyreachTarget() {
    SurvivalBoss? bestBoss;
    for (final boss in allLivingBosses) {
      if (bestBoss == null || boss.hp > bestBoss.hp) bestBoss = boss;
    }
    if (bestBoss != null) return bestBoss.position;
    CosmicSurvivalEnemy? best;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      if (best == null || enemy.hp > best.hp) best = enemy;
    }
    return best?.position;
  }

  /// Whether [comp]'s special can be cast now. A Let's whole special is its
  /// one meteor, and the shared projectile list drops what is appended past
  /// its cap, so a Let that cast into a full list spent its cooldown on
  /// nothing (2026-10-20 audit). It waits for room instead.
  bool _letSpecialHasRoom(CosmicSurvivalCompanion comp) =>
      comp.member.family.toLowerCase() != 'let' ||
      companionProjectiles.length < _maxCompanionProjectiles;

  /// Where [comp]'s special lands: [target] for every family but a Let, and
  /// for a Let going for a boss ([atBoss]); otherwise the crowd's heart
  /// ([_letCrowdAim]) for a crater of the size its meteor will open.
  Offset _letSpecialAim(
    CosmicSurvivalCompanion comp,
    Offset target, {
    required double beauty,
    required bool atBoss,
  }) {
    if (atBoss || comp.member.family.toLowerCase() != 'let') return target;
    return _letCrowdAim(
      comp,
      target,
      letMeteorCraterRadius(element: comp.member.element, beauty: beauty),
    );
  }

  /// Most bodies a crowd aim tries as the heart of the crater.
  static const int _letAimCandidates = 24;

  /// How much more a body at the orb counts toward a crowd aim than one
  /// [_letAimOrbReach] or further out: the crowd that matters is the one
  /// closing on the orb, not the thickest stream at the edge of reach.
  static const double _letAimOrbWeight = 2.0;
  static const double _letAimOrbReach = 500.0;

  /// The bodies in a Let's reach, gathered once per crowd aim.
  final List<CosmicSurvivalEnemy> _letAimBodies = <CosmicSurvivalEnemy>[];

  /// The point a crater of [crater] should come down on to catch the most
  /// living bodies, from those within [comp]'s special reach — or [target]
  /// when nothing does better.
  ///
  /// User-approved spec (2026-10-20), "aim at the crowd": a Let picked one
  /// fresh body near the orb and dropped the whole crater on it, so a meteor
  /// that could take a clump took one leaker. Up to [_letAimCandidates]
  /// bodies, spread through the reach, each suggest a centre; it moves once
  /// to the middle of the bodies within a crater of it, and the centre that
  /// catches the most wins (nearer the orb on a tie). A body closing on the
  /// orb counts for more ([_letAimOrbWeight]). Once a cast, through the enemy
  /// grid.
  Offset _letCrowdAim(
    CosmicSurvivalCompanion comp,
    Offset target,
    double crater,
  ) {
    final reach = comp.specialAbilityRange;
    final bodies = _letAimBodies..clear();
    _visitEnemiesNear(comp.position, reach, (enemy) {
      if (_withinRange(comp.position, enemy.position, reach)) {
        bodies.add(enemy);
      }
      return false;
    });
    if (bodies.length < 2) {
      bodies.clear();
      return target;
    }
    final craterSq = crater * crater;
    final orbAt = orb.position;
    double caught(Offset at) {
      var n = 0.0;
      _visitEnemiesNear(at, crater, (enemy) {
        if (_distanceSquared(enemy.position, at) > craterSq) return false;
        final orbDistance = sqrt(_distanceSquared(enemy.position, orbAt));
        n +=
            1.0 +
            _letAimOrbWeight * max(0.0, 1.0 - orbDistance / _letAimOrbReach);
        return false;
      });
      return n;
    }

    var best = target;
    var bestCount = caught(target);
    var bestOrbSq = _distanceSquared(target, orbAt);
    final stride = max(1, (bodies.length / _letAimCandidates).ceil());
    for (var i = 0; i < bodies.length; i += stride) {
      final seed = bodies[i].position;
      var sx = 0.0;
      var sy = 0.0;
      var n = 0;
      _visitEnemiesNear(seed, crater, (enemy) {
        if (_distanceSquared(enemy.position, seed) <= craterSq) {
          sx += enemy.position.dx;
          sy += enemy.position.dy;
          n++;
        }
        return false;
      });
      final aim = n > 0 ? Offset(sx / n, sy / n) : seed;
      final count = caught(aim);
      final orbSq = _distanceSquared(aim, orbAt);
      if (count > bestCount || (count == bestCount && orbSq < bestOrbSq)) {
        best = aim;
        bestCount = count;
        bestOrbSq = orbSq;
      }
    }
    bodies.clear();
    return best;
  }

  /// A basic's launch: its family's own, or Deadfall's heavier throw when the
  /// Let mastery turned the shot into a falling rock.
  SoundCue? _basicCue(CosmicSurvivalCompanion comp, List<Projectile> shots) =>
      shots.isNotEmpty && shots.first.letDeadfall
      ? SoundCue.basicLetDeadfall
      : SoundCue.forFamilyBasic(comp.member.family);

  /// Deadfall's landing: the body underneath takes the rock, the rest of the
  /// crater takes a share. No element behaviour — that is the special's.
  void _detonateLetDeadfall(Projectile p) {
    final centre = p.skyfallImpact;
    final radius = p.letCraterRadius;
    pushLetSkyfallImpact(
      _letSkyfallImpacts,
      LetSkyfallImpact(
        position: centre,
        color: elementColor(p.element ?? 'Earth'),
        element: p.element,
        radius: radius,
        minor: true,
      ),
    );
    onSound?.call(SoundCue.specialLetImpactMinor);

    SurvivalBoss? struckBoss;
    var bestSq = double.infinity;
    for (final boss in allLivingBosses) {
      final reach = radius + boss.radius;
      final dSq = _distanceSquared(boss.position, centre);
      if (dSq <= reach * reach && dSq < bestSq) {
        bestSq = dSq;
        struckBoss = boss;
      }
    }
    CosmicSurvivalEnemy? struck;
    if (struckBoss == null) {
      _visitEnemiesNear(centre, radius + 40, (enemy) {
        if (enemy.isDead) return false;
        final reach = radius + enemy.radius;
        final dSq = _distanceSquared(enemy.position, centre);
        if (dSq <= reach * reach && dSq < bestSq) {
          bestSq = dSq;
          struck = enemy;
        }
        return false;
      });
    }

    final hitBoss = struckBoss;
    final hitEnemy = struck;
    if (hitBoss != null) {
      damageBoss(
        p.damage,
        attackElement: p.element,
        sourceSlotIndex: p.sourceSlotIndex,
        target: hitBoss,
        autoAttack: true,
        masteryCastId: p.masteryCastId,
      );
    } else if (hitEnemy != null) {
      _damageEnemy(
        hitEnemy,
        p.damage,
        sourceSlotIndex: p.sourceSlotIndex,
        autoAttack: true,
        masteryCastId: p.masteryCastId,
      );
    }
    _openLetCrater(p, centre, exclude: hitEnemy, excludeBoss: hitBoss);
    p.life = 0;
  }

  /// The share of an auto-attack meteor's hit that the rest of its crater
  /// takes. Everything here is mastery's doing: the chassis rock has no
  /// crater at all.
  void _openLetCrater(
    Projectile p,
    Offset centre, {
    CosmicSurvivalEnemy? exclude,
    SurvivalBoss? excludeBoss,
  }) {
    final radius = p.letCraterRadius;
    if (radius <= 0) return;
    // A flat comet opens its crater once, on whatever it struck first.
    if (!p.letDeadfall) {
      p.letCraterRadius = 0;
      pushLetSkyfallImpact(
        _letSkyfallImpacts,
        LetSkyfallImpact(
          position: centre,
          color: elementColor(p.element ?? 'Earth'),
          element: p.element,
          radius: radius,
          minor: true,
        ),
      );
    }
    final splash = p.damage * p.letCraterShare;
    if (splash <= 0) return;
    _visitEnemiesNear(centre, radius + 40, (enemy) {
      if (enemy.isDead || identical(enemy, exclude)) return false;
      if (!_withinRange(centre, enemy.position, radius + enemy.radius)) {
        return false;
      }
      _damageEnemy(
        enemy,
        splash,
        sourceSlotIndex: p.sourceSlotIndex,
        masterySource: MasteryDamageSource.mastery,
      );
      return false;
    });
    for (final boss in allLivingBosses.toList()) {
      if (identical(boss, excludeBoss)) continue;
      if (!_withinRange(centre, boss.position, radius + boss.radius)) {
        continue;
      }
      damageBoss(
        splash,
        attackElement: p.element,
        sourceSlotIndex: p.sourceSlotIndex,
        target: boss,
        masterySource: MasteryDamageSource.mastery,
      );
    }
  }

  /// The additive bonus a Let auto-attack meteor earns on [body], or 0 for
  /// any other damage. Resolves Cratermaker's crack, Dead Weight, the
  /// Ranging Shots streak and the Sighted bonus in one place.
  double _letAutoAttackBonus(
    int castId,
    MasteryPayloadStatuses body,
    double hpFraction,
    int targetId,
  ) {
    if (castId == 0) return 0;
    final cast = mastery.cast(castId);
    if (cast == null ||
        cast.family != CreatureFamily.let ||
        cast.kind != MasteryCastKind.basic) {
      return 0;
    }
    final slotIndex = cast.slotIndex;
    return resolveLetAutoAttackBonus(
      hasNode: (nodeId) => mastery.hasNode(slotIndex, nodeId),
      targetHpFraction: hpFraction,
      fractureRemaining: body.letFractureTimer,
      sightRemaining: body.letSightTimer,
      consumeFracture: () => body.letFractureTimer = 0,
      applyFracture: () => body.letFractureTimer = LetTuning.fractureDuration,
      extendSight: () => body.letSightTimer = min(
        LetTuning.sightMaxRemaining,
        body.letSightTimer + LetTuning.walkingFireExtension,
      ),
      rangingStreakBonus: () =>
          _letStateFor(slotIndex).landDrop(targetId, mastery.clock),
    );
  }

  /// Sighted on whatever else a Let deals to a body it Sighted: "your
  /// meteors deal +20% damage to them", the special's crater included. It
  /// was the auto-attack meteor's alone, about a fifteenth of a Let's damage
  /// since the 2026-10-20 rebuild put it in the special, so Ground Zero's
  /// opening node was worth about 1% to the Let (2026-10-21 mastery sweep).
  double _letSightedBonus(int slotIndex, MasteryPayloadStatuses body) {
    if (!body.isLetSighted || body.letSightSlot != slotIndex) return 0;
    if (!mastery.hasNode(slotIndex, LetNodes.sighted)) return 0;
    return LetTuning.sightedBonus;
  }

  /// Records damage, crediting the parts Let mastery is responsible for.
  ///
  /// [letUplift] is the share the dealer's own auto-attack bonus added;
  /// [calledShotSlot] is the Let whose Called Shot added its bonus on top,
  /// credited to that Let rather than to whoever happened to be shooting.
  void _recordDamageWithLetUplift(
    int? slotIndex,
    double dealt,
    MasteryDamageSource source, {
    required int castId,
    required double letUplift,
    required int? calledShotSlot,
  }) {
    var remaining = dealt;
    if (calledShotSlot != null && remaining > 0) {
      final share = remaining * letUpliftFraction(LetTuning.calledShotBonus);
      mastery.recordDamage(calledShotSlot, share, MasteryDamageSource.mastery);
      remaining -= share;
    }
    if (letUplift > 0 && remaining > 0) {
      final share = remaining * letUplift;
      mastery.recordDamage(slotIndex, share, MasteryDamageSource.mastery);
      remaining -= share;
    }
    mastery.recordDamage(slotIndex, remaining, source, castId: castId);
  }

  /// Sighted: everything the special meteor's crater catches is marked.
  void _applyLetSightFromSpecial(
    Projectile p,
    Offset centre,
    double blast,
    List<CosmicSurvivalEnemy> inBlast,
  ) {
    final slotIndex = p.sourceSlotIndex;
    if (slotIndex == null) return;
    if (!mastery.hasNode(slotIndex, LetNodes.sighted)) return;
    final calledShot = mastery.hasNode(slotIndex, LetNodes.calledShot);
    final fireForEffect = mastery.hasNode(slotIndex, LetNodes.fireForEffect);
    void sight(MasteryPayloadStatuses body) => body.applyLetSight(
      slotIndex: slotIndex,
      duration: LetTuning.sightDuration,
      calledShot: calledShot,
      fireForEffect: fireForEffect,
    );
    for (final enemy in inBlast) {
      sight(enemy);
    }
    for (final boss in allLivingBosses) {
      if (_distanceSquared(boss.position, centre) <= blast * blast) {
        sight(boss);
      }
    }
  }

  /// Whether anything in the arena is Sighted right now (Fire for Effect).
  bool _anyLetSighted() {
    for (final boss in allLivingBosses) {
      if (boss.isLetSighted) return true;
    }
    for (final enemy in enemies) {
      if (!enemy.isDead && enemy.isLetSighted) return true;
    }
    return false;
  }

  /// Fire for Effect: a Sighted body's death hands its Sight, with the time
  /// it had left, to the nearest living enemy. One hop per death — the body
  /// it lands on is alive, so nothing cascades inside a frame.
  void _hopLetSight(MasteryPayloadStatuses dying) {
    final remaining = dying.letSightTimer;
    final slotIndex = dying.letSightSlot;
    final calledShot = dying.letSightCalledShot;
    final hops = dying.letSightFireForEffect;
    dying.clearLetSight();
    if (!hops || slotIndex == null || remaining <= 0) return;

    final Offset from;
    if (dying is CosmicSurvivalEnemy) {
      from = dying.position;
    } else if (dying is SurvivalBoss) {
      from = dying.position;
    } else {
      return;
    }
    MasteryPayloadStatuses? nearest;
    var bestSq = double.infinity;
    for (final enemy in enemies) {
      if (enemy.isDead || identical(enemy, dying)) continue;
      final dSq = _distanceSquared(enemy.position, from);
      if (dSq < bestSq) {
        bestSq = dSq;
        nearest = enemy;
      }
    }
    for (final boss in allLivingBosses) {
      if (identical(boss, dying)) continue;
      final dSq = _distanceSquared(boss.position, from);
      if (dSq < bestSq) {
        bestSq = dSq;
        nearest = boss;
      }
    }
    if (nearest == null) return;
    nearest.applyLetSight(
      slotIndex: slotIndex,
      duration: remaining,
      calledShot: calledShot,
      fireForEffect: true,
    );
    mastery.recordCapstone(slotIndex);
  }

  // == Pip mastery ==========================================================

  final Map<int, PipMasteryState> _pipMastery = {};

  PipMasteryState _pipStateFor(int slotIndex) =>
      _pipMastery.putIfAbsent(slotIndex, PipMasteryState.new);

  /// Read-only view of a Pip's run state — Pins held, cadence counters.
  PipMasteryState? pipMasteryFor(int slotIndex) => _pipMastery[slotIndex];

  bool _isMasteryPip(int slotIndex) {
    if (!mastery.enabled) return false;
    return mastery.equippedFor(slotIndex)?.family == CreatureFamily.pip;
  }

  /// Pin Cushion: "each Pin makes your darts deal +3% damage to it". What a
  /// Pip's darts add on a body it has pinned, as a fraction. The Pins were
  /// banked and spent and never read, so the per-Pin bonus did nothing
  /// (2026-10-20 audit). Its darts: the auto-attack's, and since the
  /// 2026-10-21 mastery sweep the special's as well, which past Potential 50
  /// are most of what a Pip throws (an auto-attack-only Pin was worth about
  /// 1% of a Pip's damage at Potential 80). Not the Pluck burst.
  double _pipPinBonus(
    int? slotIndex,
    int targetId, {
    required bool autoAttack,
    int castId = 0,
  }) {
    if (slotIndex == null) return 0;
    final state = _pipMastery[slotIndex];
    if (state == null || !mastery.hasNode(slotIndex, PipNodes.pinCushion)) {
      return 0;
    }
    if (!autoAttack && mastery.cast(castId)?.kind != MasteryCastKind.special) {
      return 0;
    }
    return state.pinsOn(targetId) * PipTuning.pinDamagePerStack;
  }

  /// Rebuilds a Pip volley to the equipped path's shape.
  ///
  /// Rebuilt rather than edited for the same reason Mane's pair is: spread,
  /// homing and dart count are decided together, and homing is final on a
  /// projectile. Per-dart damage is derived from the chassis factory's own
  /// output so the chassis stays the single source of base scaling.
  List<Projectile> _applyPipBasicMastery(
    List<Projectile> basics,
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
  ) {
    if (basics.isEmpty || !_isMasteryPip(slotIndex)) return basics;
    final state = _pipStateFor(slotIndex);
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);

    final shape = resolvePipVolleyShape(hasNode: has);
    final seed = basics.first;
    final perDart =
        seed.damage * (shape.dartFraction / PipTuning.baseDartFraction);
    state.pendingMasteryDamageFraction = pipUpliftFraction(
      shape.dartFraction / PipTuning.baseDartFraction,
    );

    return _buildPipVolley(
      comp: comp,
      slotIndex: slotIndex,
      fireAngle: fireAngle,
      count: shape.dartCount,
      spread: shape.spread,
      damage: perDart,
      homingStrength: shape.homingStrength,
      seed: seed,
    );
  }

  /// One fan of darts, centred on [fireAngle].
  List<Projectile> _buildPipVolley({
    required CosmicSurvivalCompanion comp,
    required int slotIndex,
    required double fireAngle,
    required int count,
    required double spread,
    required double damage,
    required double homingStrength,
    required Projectile seed,
    double? life,
    double? speedMultiplier,
  }) {
    final darts = <Projectile>[];
    final centre = (count - 1) / 2.0;
    for (var i = 0; i < count; i++) {
      final a = fireAngle + (i - centre) * spread;
      darts.add(
        Projectile(
          position: Offset(
            comp.position.dx + cos(a) * 14,
            comp.position.dy + sin(a) * 14,
          ),
          angle: a,
          element: comp.member.element,
          damage: damage,
          life: life ?? seed.life,
          speedMultiplier: speedMultiplier ?? seed.speedMultiplier,
          visualScale: seed.visualScale,
          visualStyle: seed.visualStyle,
          homing: homingStrength > 0,
          homingStrength: homingStrength,
          sourceSlotIndex: slotIndex,
        ),
      );
    }
    return darts;
  }

  /// Cadence bookkeeping at the moment a Pip volley launches.
  void _onPipBasicCast(int slotIndex, int castId, double fireAngle) {
    if (castId == 0 || !_isMasteryPip(slotIndex)) return;
    final state = _pipStateFor(slotIndex);
    final cast = mastery.cast(castId);
    if (state.pendingBonusVolley) cast?.tag(PipCastTags.bonusVolley);
    state.pendingBonusVolley = false;

    if (mastery.hasNode(slotIndex, PipNodes.scatterStorm) &&
        state.takeStormTurn()) {
      _castPipScatterStorm(slotIndex, fireAngle);
    }
  }

  /// Scatter Storm: a fan of darts, each seeking its own body.
  void _castPipScatterStorm(int slotIndex, double fireAngle) {
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.isDead) return;
    if (!mastery.requestObjects(PipTuning.scatterStormDarts)) return;

    final stormCastId = mastery.beginCast(
      slotIndex: slotIndex,
      family: CreatureFamily.pip,
      element: comp.member.element,
      kind: MasteryCastKind.basic,
      projectileCount: PipTuning.scatterStormDarts,
      countsAsCast: false,
    );
    mastery.cast(stormCastId)?.tag(PipCastTags.scatterStorm);

    final damage =
        comp.physAtk.toDouble() *
        PipTuning.scatterStormFraction *
        comp.damageAmp;
    final storm = <Projectile>[];
    for (var i = 0; i < PipTuning.scatterStormDarts; i++) {
      final a = fireAngle + i * 2 * pi / PipTuning.scatterStormDarts;
      storm.add(
        Projectile(
            position: Offset(
              comp.position.dx + cos(a) * 16,
              comp.position.dy + sin(a) * 16,
            ),
            angle: a,
            element: comp.member.element,
            damage: damage,
            life: 1.5,
            speedMultiplier: 1.6,
            visualScale: 0.78,
            visualStyle: ProjectileVisualStyle.dart,
            homing: true,
            homingStrength: PipTuning.wideHoming,
            sourceSlotIndex: slotIndex,
          )
          ..masteryCastId = stormCastId
          ..masteryGenerated = true,
      );
    }
    _appendCompanionProjectiles(storm, cue: SoundCue.basicPip);
    mastery.recordCapstone(slotIndex);
  }

  /// Salvo: load extra darts into the special.
  ///
  /// Appended to whatever the ability table built rather than replacing it,
  /// so every element keeps its own behaviour — a Lightning dart still
  /// ricochets five times, a Blood dart still heals on a kill. The path adds
  /// darts; it does not decide what a dart does.
  /// Returns the volley to throw. A new list, because several abilities hand
  /// back a fixed-length one and appending to it throws.
  List<Projectile> _applyPipSpecialMastery(
    List<Projectile> projectiles,
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
  ) {
    if (projectiles.isEmpty || !_isMasteryPip(slotIndex)) return projectiles;
    final salvo = resolvePipSalvo(
      hasNode: (nodeId) => mastery.hasNode(slotIndex, nodeId),
    );
    if (salvo.extraDarts <= 0) return projectiles;
    if (!mastery.requestObjects(salvo.extraDarts)) return projectiles;

    // The extras fan outward from the authored volley rather than stacking on
    // top of it, so more darts reads as a wider salvo.
    final loaded = List<Projectile>.of(projectiles);
    final seed = projectiles.first;
    final spread = PipTuning.baseSpread * 1.15;
    final offset = (loaded.length + salvo.extraDarts - 1) / 2.0;
    for (var i = 0; i < salvo.extraDarts; i++) {
      final a = fireAngle + (loaded.length + i - offset) * spread;
      loaded.add(
        copyProjectile(
          seed,
          position: Offset(
            comp.position.dx + cos(a) * 14,
            comp.position.dy + sin(a) * 14,
          ),
          angle: a,
          damage: seed.damage * salvo.fraction,
        )
          ..masteryGenerated = true
          // Lighter, and spent sooner by the same share. In a crowd a Pip
          // dart kills as it goes and carries on, to its contact ceiling
          // ([PipRicochet.maxContacts]), so how many bodies it may thread is
          // what it is worth there: at three-quarters of the damage, and
          // with its flight cut too, the full path still carried a Pip to
          // 41% of its party's damage at P100 E10 (2026-10-21 mastery sweep).
          ..pipContacts =
              ((1 - salvo.fraction) * PipRicochet.maxContacts).round(),
      );
    }
    return loaded;
  }

  /// Loads a Pip volley's special darts with the payload they carry through
  /// the crowd ([pipSurvivalPayload]).
  void _loadPipPayload(
    List<Projectile> projectiles,
    CosmicSurvivalCompanion comp,
    int slotIndex,
  ) {
    if (comp.member.family.toLowerCase() != 'pip') return;
    final payload = pipSurvivalPayload(_effectiveBeauty(slotIndex));
    for (final p in projectiles) {
      if (!PipRicochet.isSpecialDart(p) || p.pipPayload != 1.0) continue;
      p.pipPayload = payload;
      p.damage *= payload;
    }
  }

  /// Pip's reactions to one of its darts landing.
  void _onPipHit(
    MasteryHit hit, {
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
  }) {
    final slotIndex = hit.slotIndex;
    final state = _pipStateFor(slotIndex);
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);
    final comp = activeCompanions[slotIndex];
    if (comp == null) return;

    // A storm dart is not a scheduled volley; it banks nothing.
    if (hit.cast.hasTag(PipCastTags.scatterStorm)) return;

    // ── Needlepoint ──
    if (has(PipNodes.pinCushion) && hit.isFullVolleyHit) {
      // A bonus volley may not bank Pins, or Thousand Cuts would feed itself.
      if (!hit.cast.hasTag(PipCastTags.bonusVolley) &&
          mastery.claimCastOnce(hit.cast.id)) {
        state.addPin(hit.targetId, mastery.clock);
        if (has(PipNodes.thousandCuts) && state.takeBonusVolleyTurn()) {
          _queuePipBonusVolley(slotIndex, hit.targetId);
        }
      }
    }
    if (has(PipNodes.pluckThePins) &&
        state.pinsOn(hit.targetId) >= PipTuning.maxPins) {
      final spent = state.spendPins(hit.targetId, isBoss: hit.isBoss);
      if (spent > 0) {
        final burst =
            comp.physAtk.toDouble() * PipTuning.pluckFraction * comp.damageAmp;
        if (enemy != null) {
          _damageEnemy(
            enemy,
            burst,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
        } else if (boss != null) {
          damageBoss(
            burst,
            sourceSlotIndex: slotIndex,
            target: boss,
            masterySource: MasteryDamageSource.mastery,
          );
        }
      }
    }

    // ── Scattershot ──
    // Three Fronts: "when your 3 darts hit 3 different enemies, each one
    // deals +20%". It paid only the dart that reached the third body (and
    // any after it), so two of the three it named went unpaid; the first
    // two bodies are now held until the third is reached, then paid
    // (2026-10-21 mastery sweep).
    if (has(PipNodes.threeFronts)) {
      final cast = hit.cast;
      if (state.frontsCastId != cast.id) state.startFronts(cast.id);
      if (cast.targetsHit < 3) {
        if (hit.isFirstHitOnTarget) state.holdFront(enemy ?? boss, hit.damage);
      } else {
        for (var i = 0; i < state.heldFronts; i++) {
          final body = state.frontBody(i);
          if (!mastery.claimPayloadTarget(cast.id, identityHashCode(body))) {
            continue;
          }
          _payPipFront(slotIndex, body, state.frontDamage(i));
        }
        state.clearFronts();
        if (mastery.claimPayloadTarget(cast.id, hit.targetId)) {
          _payPipFront(slotIndex, enemy ?? boss, hit.damage);
        }
      }
    }
  }

  /// One Three Fronts bonus, on a body that is still standing.
  void _payPipFront(int slotIndex, Object? body, double hitDamage) {
    final bonus = hitDamage * PipTuning.threeFrontsBonus;
    if (bonus <= 0) return;
    if (body is CosmicSurvivalEnemy && !body.isDead) {
      _damageEnemy(
        body,
        bonus,
        sourceSlotIndex: slotIndex,
        masterySource: MasteryDamageSource.mastery,
      );
    } else if (body is SurvivalBoss && !body.isDead) {
      damageBoss(
        bonus,
        sourceSlotIndex: slotIndex,
        target: body,
        masterySource: MasteryDamageSource.mastery,
      );
    }
  }

  /// Thousand Cuts: a second volley at the same body, a moment later.
  void _queuePipBonusVolley(int slotIndex, int targetId) {
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.isDead) return;
    _pipBonusVolleys.add(
      _PipBonusVolley(
        slotIndex: slotIndex,
        targetId: targetId,
        delay: PipTuning.thousandCutsDelay,
      ),
    );
  }

  final List<_PipBonusVolley> _pipBonusVolleys = [];

  void _updatePipMastery(double dt) {
    if (_pipMastery.isNotEmpty) {
      for (final state in _pipMastery.values) {
        state.expirePins(mastery.clock);
      }
    }
    if (_pipBonusVolleys.isEmpty) return;
    for (var i = _pipBonusVolleys.length - 1; i >= 0; i--) {
      final queued = _pipBonusVolleys[i];
      queued.delay -= dt;
      if (queued.delay > 0) continue;
      _pipBonusVolleys.removeAt(i);
      _firePipBonusVolley(queued);
    }
  }

  void _firePipBonusVolley(_PipBonusVolley queued) {
    final comp = activeCompanions[queued.slotIndex];
    if (comp == null || comp.isDead) return;
    if (!mastery.requestObjects(PipTuning.thousandCutsDarts)) return;
    // Aim at the body that earned it, if it is still standing.
    CosmicSurvivalEnemy? target;
    for (final enemy in enemies) {
      if (!enemy.isDead && identityHashCode(enemy) == queued.targetId) {
        target = enemy;
        break;
      }
    }
    final aim =
        target?.position ??
        comp.position + Offset(cos(comp.angle) * 100, sin(comp.angle) * 100);
    final dir = aim - comp.position;
    final angle = dir.distance > 0.01 ? atan2(dir.dy, dir.dx) : comp.angle;

    final state = _pipStateFor(queued.slotIndex);
    state.pendingBonusVolley = true;
    final castId = mastery.beginCast(
      slotIndex: queued.slotIndex,
      family: CreatureFamily.pip,
      element: comp.member.element,
      kind: MasteryCastKind.basic,
      projectileCount: PipTuning.thousandCutsDarts,
      countsAsCast: false,
    );
    mastery.cast(castId)?.tag(PipCastTags.bonusVolley);
    state.pendingBonusVolley = false;

    final damage =
        comp.physAtk.toDouble() *
        PipTuning.thousandCutsFraction *
        comp.damageAmp;
    final darts = <Projectile>[];
    final centre = (PipTuning.thousandCutsDarts - 1) / 2.0;
    for (var i = 0; i < PipTuning.thousandCutsDarts; i++) {
      final a = angle + (i - centre) * PipTuning.baseSpread * 0.5;
      darts.add(
        Projectile(
            position: Offset(
              comp.position.dx + cos(a) * 14,
              comp.position.dy + sin(a) * 14,
            ),
            angle: a,
            element: comp.member.element,
            damage: damage,
            life: 1.25,
            speedMultiplier: 1.75,
            visualScale: 0.78,
            visualStyle: ProjectileVisualStyle.dart,
            sourceSlotIndex: queued.slotIndex,
          )
          ..masteryCastId = castId
          ..masteryGenerated = true,
      );
    }
    _appendCompanionProjectiles(darts, cue: SoundCue.basicPip);
    mastery.recordCapstone(queued.slotIndex);
  }

  // == Kin mastery (phase 5) ===============================================

  /// Per-slot Kin state, created on demand and dropped on a run reset.
  final Map<int, KinMasteryState> _kinMastery = {};

  /// Kin who have gone down while holding Unbroken, kept only so their
  /// support finishes. A dead companion is dropped from [activeCompanions]
  /// outright, so a support that is meant to outlive its caster has to be
  /// held somewhere the support tick can still find it.
  final Map<int, CosmicSurvivalCompanion> _unbrokenKin = {};

  /// Every Kin whose support is still running, living or not.
  Iterable<MapEntry<int, CosmicSurvivalCompanion>> get _kinSupportSources =>
      activeCompanions.entries.followedBy(_unbrokenKin.entries);

  /// Called as a companion is removed: keeps the ones that earned it.
  void _noteKinCompanionDown(int slotIndex, CosmicSurvivalCompanion comp) {
    if (!_kinBenedictionFor(slotIndex).survivesDeath) return;
    if (!_kinHasRunningSupport(comp)) return;
    _unbrokenKin[slotIndex] = comp;
  }

  bool _kinHasRunningSupport(CosmicSurvivalCompanion comp) =>
      comp.kinLavaPlateTimer > 0 ||
      comp.kinIceChargeTimer > 0 ||
      comp.kinSteamBoilerTimer > 0 ||
      comp.kinLightningChargeTimer > 0 ||
      comp.kinDarkCloakTimer > 0 ||
      comp.kinBloodPactTimer > 0 ||
      comp.kinMudShipEnchantTimer > 0;

  KinMasteryState _kinStateFor(int slotIndex) =>
      _kinMastery.putIfAbsent(slotIndex, KinMasteryState.new);

  /// Read-only view of a Kin's run state — what it has shielded, and any
  /// support still running without it.
  KinMasteryState? kinMasteryFor(int slotIndex) => _kinMastery[slotIndex];

  bool _isMasteryKin(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.kin;
  }

  /// Longline: how far the charged laser should actually run.
  double _kinLaserLengthFor(int slotIndex, double distanceToTarget) {
    if (!_isMasteryKin(slotIndex)) {
      return (distanceToTarget + 60.0).clamp(120.0, 720.0).toDouble();
    }
    return kinLaserLength(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      distanceToTarget: distanceToTarget,
    );
  }

  /// Conduction: hands one ally what the line earned for it.
  void _applyKinConduction(
    int slotIndex,
    CosmicSurvivalCompanion kin,
    double laserDamage,
    Offset origin,
    Offset beamEnd,
  ) {
    if (!_isMasteryKin(slotIndex)) return;
    if (!mastery.hasNode(slotIndex, KinNodes.liveCurrent)) return;

    final probe = kinConduction(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      laserDamage: laserDamage,
      allyMaxHp: 1,
      allyHealthFraction: 1,
    );
    final lateral = 14.0 + probe.radius;

    for (final entry in activeCompanions.entries) {
      final ally = entry.value;
      if (ally.isDead || identical(ally, kin)) continue;
      if (_distanceToSegment(ally.position, origin, beamEnd) > lateral) {
        continue;
      }
      final gift = kinConduction(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
        laserDamage: laserDamage,
        allyMaxHp: ally.maxHp.toDouble(),
        allyHealthFraction: ally.maxHp <= 0 ? 1.0 : ally.currentHp / ally.maxHp,
      );
      var given = 0.0;
      if (gift.heal > 0) {
        given = _healCompanion(ally, gift.heal);
      } else if (gift.shield > 0) {
        // Topped up to a ceiling, not stacked (kinConductionShieldCeiling).
        final ceiling = kinConductionShieldCeiling(
          hasNode: (id) => mastery.hasNode(slotIndex, id),
          allyMaxHp: ally.maxHp.toDouble(),
        ).round();
        final add = min(gift.shield.round(), ceiling - ally.shieldHp);
        if (add > 0) {
          ally.shieldHp += add;
          given = add.toDouble();
        }
      }
      _kinStateFor(slotIndex).shieldGranted += given;
    }

    // The ship stands on the line like anything else.
    if (!ship.isDead &&
        _distanceToSegment(ship.position, origin, beamEnd) <= lateral + 12) {
      final gift = kinConduction(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
        laserDamage: laserDamage,
        allyMaxHp: ship.maxHp,
        allyHealthFraction: ship.maxHp <= 0 ? 1.0 : ship.currentHp / ship.maxHp,
      );
      if (gift.heal > 0) {
        ship.currentHp = min(ship.maxHp, ship.currentHp + gift.heal);
      }
    }
  }

  /// Devotion: stretches every support window this Kin just opened.
  ///
  /// The seventeen supports flip seventeen different timers, so this scales
  /// them by name rather than trying to find one shared duration that does
  /// not exist.
  void _applyKinBenedictionTimers(int slotIndex, CosmicSurvivalCompanion comp) {
    final benediction = _kinBenedictionFor(slotIndex);
    if (benediction.duration <= 1.0) return;
    final d = benediction.duration;
    comp.kinLavaPlateTimer *= d;
    comp.kinIceChargeTimer *= d;
    comp.kinIceChargeTotal *= d;
    comp.kinSteamBoilerTimer *= d;
    comp.kinLightningChargeTimer *= d;
    comp.kinDarkCloakTimer *= d;
    comp.kinBloodPactTimer *= d;
    comp.kinMudShipEnchantTimer *= d;
  }

  /// Communion: a blessing the whole team receives, not only its caster —
  /// "every ally and the ship". The ship's share is the same part of its
  /// hull the caster's blessing is of the caster; it used to get nothing
  /// (2026-10-21 mastery sweep).
  void _shareKinBlessing(int slotIndex, CosmicSurvivalCompanion caster) {
    if (_kinBenedictionFor(slotIndex).allyRange <= 0) return;
    if (caster.blessingTimer <= 0) return;
    final shared = caster.blessingHealPerTick * KinTuning.communionShare;
    for (final ally in activeCompanions.values) {
      if (ally.isDead || identical(ally, caster)) continue;
      if (ally.blessingTimer <= 0 || shared >= ally.blessingHealPerTick) {
        ally.blessingShared = true;
      }
      ally.blessingTimer = max(ally.blessingTimer, caster.blessingTimer);
      ally.blessingHealPerTick = max(ally.blessingHealPerTick, shared);
    }
    _shipBlessingTimer = max(_shipBlessingTimer, caster.blessingTimer);
    _shipBlessingPerSecond = max(
      _shipBlessingPerSecond,
      shared / max(1, caster.maxHp) * ship.maxHp,
    );
  }

  /// Communion's blessing on the ship: seconds left, and hull a second.
  double _shipBlessingTimer = 0;
  double _shipBlessingPerSecond = 0;

  void _updateShipBlessing(double dt) {
    if (_shipBlessingTimer <= 0) return;
    _shipBlessingTimer -= dt;
    if (_shipBlessingTimer <= 0) {
      _shipBlessingTimer = 0;
      _shipBlessingPerSecond = 0;
      return;
    }
    if (ship.isDead || ship.currentHp >= ship.maxHp) return;
    final before = ship.currentHp;
    ship.currentHp = min(
      ship.maxHp,
      ship.currentHp + _shipBlessingPerSecond * dt,
    );
    _recordHeal(ship.currentHp - before, target: 1);
  }

  /// Benediction: what the equipped path does to a support ability.
  ({double duration, double power, bool survivesDeath, double allyRange})
  _kinBenedictionFor(int slotIndex) {
    if (!_isMasteryKin(slotIndex)) {
      return (duration: 1.0, power: 1.0, survivesDeath: false, allyRange: 0.0);
    }
    return kinBenediction(hasNode: (id) => mastery.hasNode(slotIndex, id));
  }

  // == Wing mastery (phase 5) ==============================================

  /// Per-slot Wing state, created on demand and dropped on a run reset.
  final Map<int, WingMasteryState> _wingMastery = {};

  WingMasteryState _wingStateFor(int slotIndex) =>
      _wingMastery.putIfAbsent(slotIndex, WingMasteryState.new);

  /// Read-only view of a Wing's run state — beam time banked by Tracer, and
  /// any ramp carried over from a body that died under the beam.
  WingMasteryState? wingMasteryFor(int slotIndex) => _wingMastery[slotIndex];

  bool _isMasteryWing(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.wing;
  }

  /// Burn Through: what the beam has earned on a body (or boss) it has been
  /// held on.
  double _wingBoreMultiplier(int slotIndex, MasteryPayloadStatuses body) {
    if (!_isMasteryWing(slotIndex)) return 1.0;
    if (body.wingBeamDwellSlot != slotIndex) return 1.0;
    return wingBoreMultiplier(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      dwell: body.wingBeamDwell,
    );
  }

  /// Longshot: what the distance between a Wing and its target is worth.
  double _wingLongshotMultiplier(int slotIndex, Offset targetPos) {
    if (!_isMasteryWing(slotIndex)) return 1.0;
    if (!mastery.hasNode(slotIndex, WingNodes.rangefinder)) return 1.0;
    final comp = activeCompanions[slotIndex];
    if (comp == null) return 1.0;
    final range = comp.attackRange * _masteryAttackRangeMultiplier(slotIndex);
    return 1 +
        wingLongshotBonus(
          hasNode: (id) => mastery.hasNode(slotIndex, id),
          distance: (targetPos - comp.position).distance,
          range: range,
          nearestEnemyDistance:
              mastery.hasNode(slotIndex, WingNodes.standoff)
              ? _wingStandoffNearest(
                  slotIndex,
                  comp.position,
                  range * WingTuning.standoffThreshold,
                )
              : double.infinity,
        );
  }

  /// How far the closest body inside [radius] of a Wing is, or infinity for
  /// none, worked out once a frame per Wing. Standoff reads it to decide
  /// whether the Wing has actually kept its distance or merely aimed far,
  /// and only asks about [radius]: a grid query, where the walk over every
  /// body on the field it replaced ran on every hit any mastery Wing landed.
  double _wingStandoffNearest(int slotIndex, Offset pos, double radius) {
    if (_wingStandoffClock != mastery.clock) {
      _wingStandoffClock = mastery.clock;
      _wingStandoffCache.clear();
    }
    final cached = _wingStandoffCache[slotIndex];
    if (cached != null) return cached;
    final nearest = _nearestEnemyTo(pos, radius);
    final distance = nearest == null
        ? double.infinity
        : (nearest.position - pos).distance;
    _wingStandoffCache[slotIndex] = distance;
    return distance;
  }

  final Map<int, double> _wingStandoffCache = {};
  double _wingStandoffClock = -1;

  /// Wing's reaction to one of its shots landing: Tracer, "each attack that
  /// lands". Paid once per attack, on the first of its shots to reach a body
  /// or a boss. It used to be paid as the attack was fired, so a Wing earned
  /// beam time for shots that hit nothing (2026-10-20 audit).
  void _onWingHit(MasteryHit hit) {
    if (!hit.fromBasic) return;
    final slotIndex = hit.slotIndex;
    if (!mastery.hasNode(slotIndex, WingNodes.tracerRounds)) return;
    if (!mastery.claimCastOnce(hit.cast.id)) return;
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.isDead) return;
    _applyWingTracer(slotIndex, comp);
  }

  /// Tracer: one landed attack, turned into beam time.
  void _applyWingTracer(int slotIndex, CosmicSurvivalCompanion comp) {
    if (!_isMasteryWing(slotIndex)) return;
    final running = _activeWingBeams.any((b) => b.sourceSlotIndex == slotIndex);
    final tracer = wingTracer(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      beamRunning: running,
    );
    if (tracer.shave <= 0) return;

    comp.specialCooldown = max(0, comp.specialCooldown - tracer.shave);
    if (tracer.extend <= 0) return;

    if (tracer.intoRunningBeam) {
      // Live Feed: the time goes into the beam already firing. Capped the
      // same way the bank is, so a fast Wing cannot hold one beam forever.
      for (final beam in _activeWingBeams) {
        if (beam.sourceSlotIndex != slotIndex) continue;
        beam.life = min(
          beam.life + tracer.extend,
          beam.descriptor.duration + tracer.cap,
        );
      }
      return;
    }
    _wingStateFor(slotIndex).bankBeamTime(tracer.extend, tracer.cap);
  }

  /// Per-frame Wing upkeep: the dwell that no beam is feeding this frame has
  /// to fall away, or every body on the field would keep a full ramp forever.
  void _updateWingMastery(double dt) {
    if (!mastery.enabled || _wingMastery.isEmpty) return;
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      _decayWingDwell(enemy, dt);
    }
    for (final boss in allLivingBosses) {
      _decayWingDwell(boss, dt);
    }
  }

  /// A beam ticks every 0.12-0.28 s, so a body it holds is untouched on the
  /// frames between two ticks: the dwell decays only once a whole tick has
  /// gone by without one ([MasteryPayloadStatuses.wingBeamHold]). It used to
  /// decay on every frame the beam had not ticked, which without No Reprieve
  /// dropped the ramp to nothing between ticks, so Bore and Deeper never
  /// held more than one tick's worth (2026-10-21 mastery sweep).
  void _decayWingDwell(MasteryPayloadStatuses body, double dt) {
    if (body.wingBeamDwell <= 0) return;
    final slotIndex = body.wingBeamDwellSlot;
    if (slotIndex == null) return;
    if (body.wingBeamHold > 0) {
      body.wingBeamHold -= dt;
      return;
    }
    body.decayWingBeamDwell(
      dt,
      wingBoreCurve(hasNode: (id) => mastery.hasNode(slotIndex, id)).fade,
    );
  }

  /// Carry Through: a body that dies at a full ramp hands it to the next
  /// thing the beam touches.
  void _noteWingBeamKill(int slotIndex, CosmicSurvivalEnemy enemy) {
    if (!_isMasteryWing(slotIndex)) return;
    if (!mastery.hasNode(slotIndex, WingNodes.carryThrough)) return;
    if (enemy.wingBeamDwellSlot != slotIndex) return;
    final curve = wingBoreCurve(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
    );
    if (curve.rampSeconds <= 0) return;
    final ramp = (enemy.wingBeamDwell / curve.rampSeconds).clamp(0.0, 1.0);
    if (ramp < WingTuning.carryThreshold) return;
    _wingStateFor(slotIndex).carriedRamp = enemy.wingBeamDwell;
  }

  // == Mask mastery (phase 5) ==============================================

  /// Per-slot Mask state, created on demand and dropped on a run reset.
  final Map<int, MaskMasteryState> _maskMastery = {};

  /// Fixtures waiting to come back, for Rearm. Held here rather than on the
  /// state so the pure family file never has to know what a Projectile is.
  final List<_MaskRearmEntry> _maskRearmQueue = [];

  MaskMasteryState _maskStateFor(int slotIndex) =>
      _maskMastery.putIfAbsent(slotIndex, MaskMasteryState.new);

  /// Read-only view of a Mask's run state — graves held, trigger counts.
  MaskMasteryState? maskMasteryFor(int slotIndex) => _maskMastery[slotIndex];

  /// Fixtures queued to re-arm. Exposed so tests can see the path working
  /// without having to guess at frame timing.
  int get maskRearmPending => _maskRearmQueue.length;

  bool _isMasteryMask(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.mask;
  }

  /// Whether [pos] is inside one of this Mask's own fixtures — what
  /// Necropolis reads to decide a kill deserves a full-strength grave.
  bool _isInsideOwnMaskTrap(int slotIndex, Offset pos) {
    for (final p in companionProjectiles) {
      if (p.abilityFamily != 'mask') continue;
      if (p.sourceSlotIndex != slotIndex) continue;
      if (!p.stationary) continue;
      final reach = p.effectRadius > 0 ? p.effectRadius : 40.0;
      if (_withinRange(p.position, pos, reach)) return true;
    }
    return false;
  }

  /// Deathmask: a dart kill leaves a trap of the Mask's own element.
  ///
  /// The fixture is taken from the element's real special rather than
  /// re-authored here, so all seventeen stay correct for free and a grave is
  /// always recognisably the same trap the special places.
  void _spawnMaskGrave(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    Offset position, {
    required bool fromAutoAttack,
  }) {
    if (!_isMasteryMask(slotIndex)) return;
    final state = _maskStateFor(slotIndex);
    state.graves.removeWhere(
      (id) => !companionProjectiles.any((p) => identityHashCode(p) == id),
    );

    final strength = maskGraveStrength(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      fromAutoAttack: fromAutoAttack,
      insideOwnTrap: _isInsideOwnMaskTrap(slotIndex, position),
      gravesAlive: state.graves.length,
    );
    if (strength <= 0) return;
    if (!mastery.tryProc(
      slotIndex,
      MaskNodes.graveGoods,
      MaskTuning.graveProcCooldown,
    )) {
      return;
    }
    if (!mastery.requestObjects(1)) return;

    mastery.runGuarded(() {
      final template = createCosmicSpecialAbility(
        origin: position,
        baseAngle: 0,
        family: 'mask',
        element: comp.member.element,
        damage: comp.abilityAtk.toDouble(),
        maxHp: comp.maxHp,
        casterBeauty: _effectiveBeauty(slotIndex),
        casterIntelligence: _effectiveIntelligence(slotIndex),
        casterStrength: _effectiveStrength(slotIndex),
        targetPos: position,
      );
      final seed = template.projectiles.isEmpty
          ? null
          : template.projectiles.first;
      if (seed == null) return null;

      final shape = maskGraveShape(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
      );
      // Cold Ground: the grave carries the element at full strength rather
      // than scaled down with everything else.
      final elementScale = mastery.hasNode(slotIndex, MaskNodes.coldGround)
          ? 1.0
          : strength;
      final grave = copyProjectile(
        seed,
        position: position,
        damage: seed.damage * strength,
        life: seed.life * shape.life,
        visualScale: seed.visualScale * shape.scale,
        radiusMultiplier: seed.radiusMultiplier * shape.scale,
        effectRadius: seed.effectRadius * shape.scale,
        effectPower: seed.effectPower * elementScale,
        sourceSlotIndex: slotIndex,
        abilityFamily: 'mask',
      );
      _appendCompanionProjectile(grave);
      state.addGrave(identityHashCode(grave));
      _noteMaskPlacedLives(slotIndex, [grave]);
      return null;
    }, orElse: null);
  }

  /// Hair Trigger: "re-arming no longer shortens how long it lasts". A trap
  /// came back for a flat 6 s whatever it was placed for (8-30 s by
  /// element), so the second half of the node did nothing; the life each
  /// fixture was placed with is kept here for it to come back with
  /// (2026-10-21 mastery sweep).
  void _noteMaskPlacedLives(int slotIndex, List<Projectile> placed) {
    if (!_isMasteryMask(slotIndex)) return;
    if (!mastery.hasNode(slotIndex, MaskNodes.hairTrigger)) return;
    final state = _maskStateFor(slotIndex);
    for (final p in placed) {
      if (p.abilityFamily != 'mask' || !p.stationary || p.life <= 0) continue;
      state.notePlacedLife(identityHashCode(p), p.life);
    }
  }

  /// Rearm: a Mask fixture that has run out comes back instead of being gone.
  void _noteMaskFixtureExpired(Projectile p) {
    final slotIndex = p.sourceSlotIndex;
    if (slotIndex == null || !_isMasteryMask(slotIndex)) return;
    if (p.abilityFamily != 'mask' || !p.stationary) return;

    final delay = maskRearmDelay(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
    );
    if (delay <= 0) return;

    final state = _maskStateFor(slotIndex);
    final fixtureId = identityHashCode(p);
    final held = state.noteTrigger(
      fixtureId,
      hasHeldGround: mastery.hasNode(slotIndex, MaskNodes.heldGround),
    );
    final placedLife = state.placedLifeOf(fixtureId);
    state.dropFixture(fixtureId);
    if (_maskRearmQueue.length >= MaskTuning.graveCap * 2) return;

    _maskRearmQueue.add(
      _MaskRearmEntry(
        slotIndex: slotIndex,
        template: p,
        timer: delay,
        // Held Ground: a fixture that has gone off three times stops
        // expiring, so it comes back with a life nothing will run out.
        lifeScale: held ? 1000.0 : 1.0,
        triggers: state.triggersOn(fixtureId),
        placedLife: placedLife,
      ),
    );
  }

  void _updateMaskRearm(double dt) {
    if (_maskRearmQueue.isEmpty) return;
    for (var i = _maskRearmQueue.length - 1; i >= 0; i--) {
      final entry = _maskRearmQueue[i];
      entry.timer -= dt;
      if (entry.timer > 0) continue;
      _maskRearmQueue.removeAt(i);

      final comp = activeCompanions[entry.slotIndex];
      if (comp == null || comp.isDead) continue;
      if (!mastery.requestObjects(1)) continue;

      final t = entry.template;
      final snapShut = mastery.hasNode(entry.slotIndex, MaskNodes.snapShut);
      // Spring Again brings a trap back for [MaskTuning.rearmLife]; Hair
      // Trigger for the life it was placed with.
      final hairTrigger = mastery.hasNode(
        entry.slotIndex,
        MaskNodes.hairTrigger,
      );
      final life = hairTrigger && entry.placedLife > 0
          ? entry.placedLife
          : MaskTuning.rearmLife;
      final revived = copyProjectile(
        t,
        life: life * entry.lifeScale,
        // Snap Shut: a re-armed trap catches everything in reach at once
        // rather than the first body to touch it.
        piercing: snapShut ? true : t.piercing,
      );
      _appendCompanionProjectile(revived);
      final state = _maskStateFor(entry.slotIndex);
      state.triggers[identityHashCode(revived)] = entry.triggers;
      if (entry.placedLife > 0) {
        state.notePlacedLife(identityHashCode(revived), entry.placedLife);
      }
    }
  }

  /// Contagion: a body that leaves a Mask trap alive carries it onward.
  void _infectFromMaskTrap(
    int slotIndex,
    CosmicSurvivalEnemy enemy, {
    int generation = 0,
  }) {
    if (!_isMasteryMask(slotIndex)) return;
    final infection = maskInfection(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      generation: generation,
    );
    if (infection.duration <= 0) return;
    _catchMaskInfection(
      _maskStateFor(slotIndex),
      slotIndex,
      enemy,
      duration: infection.duration,
      generation: generation,
    );
  }

  /// [body] catches [slotIndex]'s infection at [generation], if that Mask
  /// may hold one more carrier ([MaskTuning.carrierCap]) and the generation
  /// is inside [MaskTuning.maxGenerations]. A body already carrying it only
  /// has its clock refreshed. False when it was refused.
  bool _catchMaskInfection(
    MaskMasteryState state,
    int slotIndex,
    CosmicSurvivalEnemy body, {
    required double duration,
    required int generation,
  }) {
    if (generation > MaskTuning.maxGenerations) return false;
    if (!body.isMaskInfected) {
      if (!state.canInfectAnother) return false;
      state.carriers++;
      // A body passes it on a second after it caught it, not in the same
      // frame: with no wait a crowd went through every generation at once.
      body.maskInfectionSpreadTimer = MaskTuning.spreadInterval;
    }
    body.applyMaskInfection(
      slotIndex: slotIndex,
      duration: duration,
      generation: generation,
    );
    return true;
  }

  /// Per-frame Contagion upkeep: ticking, jumping, and the death burst.
  void _updateMaskMastery(double dt) {
    if (!mastery.enabled) return;
    // Give every equipped Mask its state up front. Only Deathmask creates it
    // as a side effect of placing a grave, so without this a pure Rearm or
    // Contagion build would never tick at all.
    for (final slotIndex in activeCompanions.keys) {
      if (_isMasteryMask(slotIndex)) _maskStateFor(slotIndex);
    }
    _updateMaskRearm(dt);
    if (_maskMastery.isEmpty) return;

    // Count each Mask's carriers afresh, so the cap reads the field as it is
    // (bodies die and recover between frames without telling anyone).
    for (final state in _maskMastery.values) {
      state.carriers = 0;
    }
    for (final enemy in enemies) {
      if (enemy.isDead || !enemy.isMaskInfected) continue;
      final slot = enemy.maskInfectionSlot;
      if (slot != null) _maskMastery[slot]?.carriers++;
    }

    // By index: a splitter killed by the infection adds its shards to the
    // list mid-walk.
    for (var i = 0; i < enemies.length; i++) {
      final enemy = enemies[i];
      if (enemy.isDead || !enemy.isMaskInfected) continue;
      enemy.maskInfectionTimer -= dt;
      if (enemy.maskInfectionTimer <= 0) {
        enemy.clearMaskInfection();
        continue;
      }
      final slotIndex = enemy.maskInfectionSlot;
      if (slotIndex == null) continue;
      final comp = activeCompanions[slotIndex];
      if (comp == null) continue;
      final infection = maskInfection(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
        generation: enemy.maskInfectionGeneration,
      );

      if (infection.ticks) {
        enemy.maskInfectionTickTimer -= dt;
        if (enemy.maskInfectionTickTimer <= 0) {
          enemy.maskInfectionTickTimer = 0.5;
          _damageEnemy(
            enemy,
            comp.abilityAtk * MaskTuning.virulenceStrength * 0.5,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
        }
      }

      if (!infection.spreads) continue;
      enemy.maskInfectionSpreadTimer -= dt;
      if (enemy.maskInfectionSpreadTimer > 0) continue;
      enemy.maskInfectionSpreadTimer = MaskTuning.spreadInterval;
      final state = _maskMastery[slotIndex];
      if (state == null || !state.canInfectAnother) continue;
      final nextGeneration = enemy.maskInfectionGeneration + 1;
      final from = enemy.position;
      var room = MaskTuning.spreadPerCarrier;
      _visitEnemiesNear(from, MaskTuning.spreadRadius, (other) {
        if (identical(other, enemy) || other.isMaskInfected) return false;
        if (!_withinRange(other.position, from, MaskTuning.spreadRadius)) {
          return false;
        }
        if (!_catchMaskInfection(
          state,
          slotIndex,
          other,
          duration: infection.duration,
          generation: nextGeneration,
        )) {
          return true;
        }
        return --room <= 0;
      });
    }
  }

  /// Plague: an infected body that dies bursts, and what it catches is one
  /// generation further from the trap, never reset to zero.
  void _applyMaskPlague(CosmicSurvivalEnemy enemy) {
    final slotIndex = enemy.maskInfectionSlot;
    if (slotIndex == null || !_isMasteryMask(slotIndex)) return;
    final infection = maskInfection(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      generation: enemy.maskInfectionGeneration,
    );
    if (!infection.bursts) return;
    final comp = activeCompanions[slotIndex];
    if (comp == null) return;

    mastery.runGuarded(() {
      _damageEnemiesNear(
        enemy.position,
        MaskTuning.plagueRadius,
        comp.abilityAtk * MaskTuning.plagueDamage,
        sourceSlotIndex: slotIndex,
        exclude: enemy,
        masterySource: MasteryDamageSource.mastery,
      );
      _spawnHitSpark(enemy.position, elementColor(comp.member.element));
      final nextGeneration = enemy.maskInfectionGeneration + 1;
      if (infection.spreads) {
        final state = _maskStateFor(slotIndex);
        final from = enemy.position;
        _visitEnemiesNear(from, MaskTuning.plagueRadius, (other) {
          if (identical(other, enemy)) return false;
          if (!_withinRange(other.position, from, MaskTuning.plagueRadius)) {
            return false;
          }
          // Everything nearby catches it, as long as the Mask has room.
          return !_catchMaskInfection(
            state,
            slotIndex,
            other,
            duration: infection.duration,
            generation: nextGeneration,
          );
        });
      }
      return null;
    }, orElse: null);
  }

  // == Horn mastery (phase 5) ==============================================

  /// Per-slot Horn state, created on demand and dropped on a run reset.
  final Map<int, HornMasteryState> _hornMastery = {};

  HornMasteryState _hornStateFor(int slotIndex) =>
      _hornMastery.putIfAbsent(slotIndex, HornMasteryState.new);

  /// Read-only view of a Horn's run state — the guard shield it is carrying
  /// and whether a second run is pending. The HUD reads it, and so do tests.
  HornMasteryState? hornMasteryFor(int slotIndex) => _hornMastery[slotIndex];

  /// Whether this slot is a Horn with a path equipped. The gate every Horn
  /// hook opens with, so nothing below runs for other families.
  bool _isMasteryHorn(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.horn;
  }

  /// Bulwark's weight: the damage a Horn adds from its own bulk.
  ///
  /// Auto-attacks read this through [_damageEnemy]; the special reads it once
  /// at cast, folded into `chargeDamage`, so every body the charge ploughs
  /// through carries it without the bonus being re-applied per contact.
  double _hornBulwarkBonusFor(
    int slotIndex,
    CosmicSurvivalCompanion comp, {
    required bool isSpecial,
  }) {
    if (!_isMasteryHorn(slotIndex)) return 0;
    return hornBulwarkBonus(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      maxHp: comp.maxHp.toDouble(),
      currentHp: comp.currentHp.toDouble(),
      isSpecial: isSpecial,
      specialStrikes: hornSpecialStrikes(comp.member.element),
    );
  }

  /// Anvil: a body killed by a weighted hit ruptures for a share of the
  /// Horn's maximum HP. Guarded so the rupture cannot kill into itself.
  void _applyHornAnvil(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    CosmicSurvivalEnemy enemy,
  ) {
    if (!_isMasteryHorn(slotIndex)) return;
    if (!mastery.hasNode(slotIndex, HornNodes.anvil)) return;
    if (!mastery.tryProc(
      slotIndex,
      HornNodes.anvil,
      HornTuning.anvilProcCooldown,
    )) {
      return;
    }
    mastery.runGuarded(() {
      final damage = comp.maxHp * HornTuning.anvilMaxHpFraction;
      _damageEnemiesNear(
        enemy.position,
        HornTuning.anvilRadius,
        damage,
        sourceSlotIndex: slotIndex,
        exclude: enemy,
        masterySource: MasteryDamageSource.mastery,
      );
      _spawnHitSpark(enemy.position, elementColor(comp.member.element));
      return null;
    }, orElse: null);
  }

  /// Guarded Shot: each attack banks a shield toward a ceiling.
  void _bankHornGuard(int slotIndex, CosmicSurvivalCompanion comp) {
    if (!_isMasteryHorn(slotIndex)) return;
    final guard = hornGuardShield(
      hasNode: (id) => mastery.hasNode(slotIndex, id),
      maxHp: comp.maxHp.toDouble(),
    );
    if (guard.perShot <= 0) return;
    final state = _hornStateFor(slotIndex);
    state.guardShield = min(state.guardShield + guard.perShot, guard.cap);
  }

  /// Bastion's share of what the orb is about to take. Returns what the orb
  /// still takes; the Horn's share is dealt here.
  double _hornBodyguardOrbDamage(double incoming) {
    if (incoming <= 0 || !mastery.enabled) return incoming;
    var remaining = incoming;
    for (final entry in activeCompanions.entries) {
      if (remaining <= 0) break;
      final slotIndex = entry.key;
      if (!_isMasteryHorn(slotIndex)) continue;
      final comp = entry.value;
      // A Horn already down this frame stands between nothing.
      if (comp.isDead) continue;
      final split = hornBodyguardSplit(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
        incoming: remaining,
        distanceToOrb: (comp.position - orb.position).distance,
      );
      if (split.toHorn <= 0) continue;
      remaining = split.toOrb;
      _applyHornGuardedDamage(slotIndex, comp, split.toHorn, shared: true);
    }
    return remaining;
  }

  /// Puts damage through a Bastion's guard shield before its hit points, and
  /// ruptures the shield if this is the hit that breaks it.
  ///
  /// [shared] is Bodyguard's share of an orb hit. It always lands: through the
  /// hit invulnerability, without refreshing it, and with the fractions
  /// carried rather than rounded away. Before, the share went through the
  /// ordinary hit path, so most of it vanished inside the 0.45 s the Horn's
  /// last contact had bought, and every chip re-armed that window — Bastion
  /// was a near-free 25% cut for the orb rather than a trade (2026-10-20
  /// audit).
  void _applyHornGuardedDamage(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double amount, {
    bool shared = false,
  }) {
    var remaining = amount;
    final state = _hornStateFor(slotIndex);
    if (state.guardShield > 0) {
      final absorbed = min(remaining, state.guardShield);
      state.guardShield -= absorbed;
      remaining -= absorbed;
      if (state.guardShield <= 0.001) {
        state.guardShield = 0;
        _applyHornLastStand(slotIndex, comp, absorbed);
      }
    }
    if (remaining <= 0) return;
    if (!shared) {
      comp.takeDamage(remaining.round());
      return;
    }
    final owed = remaining + state.bodyguardCarry;
    final whole = owed.floor();
    state.bodyguardCarry = owed - whole;
    if (whole <= 0) return;
    comp.takeSharedDamage(whole);
    _runStatsFor(slotIndex).damageTaken += whole;
    if (comp.currentHp <= 0) comp.isDead = true;
  }

  /// Last Stand: a shield broken through ruptures and gives back part of the
  /// special's cooldown.
  void _applyHornLastStand(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double shieldSpent,
  ) {
    if (!mastery.hasNode(slotIndex, HornNodes.lastStand)) return;
    final state = _hornStateFor(slotIndex);
    if (state.lastStandCooldownTimer > 0) return;
    state.lastStandCooldownTimer = HornTuning.lastStandCooldown;

    mastery.runGuarded(() {
      _damageEnemiesNear(
        comp.position,
        HornTuning.lastStandRadius,
        shieldSpent * HornTuning.lastStandDamageScale,
        sourceSlotIndex: slotIndex,
        masterySource: MasteryDamageSource.mastery,
      );
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
      return null;
    }, orElse: null);

    comp.specialCooldown = max(
      0,
      comp.specialCooldown -
          comp.effectiveSpecialCooldown * HornTuning.lastStandCooldownRefund,
    );
  }

  /// Shield Wall: how much less an ally near a shielded Bastion takes.
  double _hornShieldWallMultiplier(CosmicSurvivalCompanion target) {
    if (!mastery.enabled) return 1.0;
    for (final entry in activeCompanions.entries) {
      final slotIndex = entry.key;
      if (!_isMasteryHorn(slotIndex)) continue;
      if (!mastery.hasNode(slotIndex, HornNodes.shieldWall)) continue;
      if (_hornStateFor(slotIndex).guardShield <= 0) continue;
      final horn = entry.value;
      if (identical(horn, target)) continue;
      if ((horn.position - target.position).distance >
          HornTuning.shieldWallRadius) {
        continue;
      }
      return 1 - HornTuning.shieldWallMitigation;
    }
    return 1.0;
  }

  /// Juggernaut at the moment a Horn's special goes off: whether this cast is
  /// the second run, and what that run is worth. A first cast owes one, which
  /// is settled when the ability finishes, because Horn's ability occupies
  /// time ([_updateHornMasteryFor]). Null for a Horn with no mastery path.
  _HornRun? _settleHornRun(int slotIndex) {
    if (!_isMasteryHorn(slotIndex)) return null;
    final state = _hornStateFor(slotIndex);
    final run = hornSecondRun(hasNode: (id) => mastery.hasNode(slotIndex, id));
    final second = state.consumeSecondRun();
    if (!second && run.power > 0) state.secondRunOwed = true;
    return (
      second: second,
      power: run.power,
      coverage: run.coverage,
      fullWeight: mastery.hasNode(slotIndex, HornNodes.fullWeight),
    );
  }

  /// What a second run leaves on the ground, at the run's strength: the
  /// burst a ram drops on impact, or the Light barrier that is the whole of a
  /// no-ram Horn's special. The hit is always the run's power. The element's
  /// own effect — a zone's tick, how long the barrier stands — is weakened
  /// with it unless Full Weight is held, which is that node's promise. Second
  /// Front's wider ground widens the barrier; a ram's is its sweep.
  void _scaleHornSecondRun(List<Projectile> burst, _HornRun run) {
    final effect = run.fullWeight ? 1.0 : run.power;
    for (final p in burst) {
      p.damage *= run.power;
      p.effectPower *= effect;
      if (isHornLightBarrier(p)) {
        p.life *= effect;
        p.radiusMultiplier *= run.coverage;
        p.visualScale *= run.coverage;
      }
    }
  }

  /// Everything Horn mastery does to a charge as it goes off: folds Bulwark's
  /// weight in, and scales Juggernaut's second run.
  ///
  /// The weight goes in once, here, rather than per contact. A charge that
  /// ploughs through six bodies would otherwise add a Horn's whole bulk six
  /// times, which is how a tank path turns into the best damage path.
  void _applyHornCastMastery(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    _HornRun? run,
  ) {
    if (!_isMasteryHorn(slotIndex)) return;
    if (run != null && run.second) {
      comp.chargeDamage *= run.power;
      comp.chargeSweepRadius *= run.coverage;
      comp.chargeFinalSweepRadius *= run.coverage;
      // Full Weight: the active window is what gates every element-specific
      // Horn behaviour — Steam's chain, Lava's flames, Blood's heal, Fire's
      // trail. Without the node the second run gets a short one, so it lands
      // as a weaker echo; with it the element reads exactly as it did first
      // time, which is the whole of what the node promises.
      if (!run.fullWeight) {
        comp.hornSpecialActiveWindow *= run.power;
      }
    }

    final bonus = _hornBulwarkBonusFor(slotIndex, comp, isSpecial: true);
    if (bonus > 0) comp.chargeDamage += bonus;
  }

  /// Per-frame Horn mastery upkeep: the second run Juggernaut owes, and a
  /// passive Horn's pulse in place of one.
  void _updateHornMastery(double dt) {
    if (!mastery.enabled) return;
    for (final entry in activeCompanions.entries) {
      _updateHornMasteryFor(entry.key, entry.value, dt);
    }
  }

  void _updateHornMasteryFor(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    if (!_isMasteryHorn(slotIndex)) return;
    final state = _hornStateFor(slotIndex);
    if (state.lastStandCooldownTimer > 0) {
      state.lastStandCooldownTimer -= dt;
    }

    final run = hornSecondRun(hasNode: (id) => mastery.hasNode(slotIndex, id));
    if (run.power <= 0) return;

    // A Horn that never casts cannot run its special twice, so it pulses.
    if (isPassiveOnlyCosmicAbility(comp.member.family, comp.member.element)) {
      final relentless = mastery.hasNode(slotIndex, HornNodes.relentless);
      if (state.takePassivePulse(dt, relentless: relentless)) {
        mastery.runGuarded(() {
          _damageEnemiesNear(
            comp.position,
            HornTuning.passivePulseRadius * run.coverage,
            comp.abilityAtk * run.power,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
          _spawnHitSpark(comp.position, elementColor(comp.member.element));
          return null;
        }, orElse: null);
      }
      return;
    }

    // The ability occupies time, and "finished" has to be read off the timers
    // that actually run it. hornSpecialActiveWindow is a flat five seconds —
    // longer than Horn's own special cooldown of about four — so a Horn that
    // keeps casting re-opens it forever and it never closes at all.
    final midAbility =
        comp.chargeTimer > 0 ||
        comp.windUpTimer > 0 ||
        _hornLightBarrierActive(slotIndex);
    if (state.secondRunOwed) {
      if (midAbility) {
        state.sawMidAbility = true;
      } else if (state.sawMidAbility) {
        state.secondRunOwed = false;
        state.sawMidAbility = false;
        state.armSecondRun();
      }
    }
    if (state.takeSecondRun(dt)) {
      state.secondRunActive = true;
      comp.specialCooldown = 0;
    }
  }

  // == Mane mastery (phase 3 vertical slice) ===============================

  /// Per-slot Mane state, created on demand and dropped on a run reset.
  final Map<int, ManeMasteryState> _maneMastery = {};

  ManeMasteryState _maneStateFor(int slotIndex) =>
      _maneMastery.putIfAbsent(slotIndex, ManeMasteryState.new);

  /// Read-only view of a Mane's run state — Rhythm, Encore, the empowered
  /// cast counters. The HUD needs it to show Rhythm, and so do the tests.
  ManeMasteryState? maneMasteryFor(int slotIndex) => _maneMastery[slotIndex];

  /// Whether this slot is a Mane with a path equipped. The gate every Mane
  /// hook opens with, so nothing below runs for other families.
  bool _isMasteryMane(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.mane;
  }

  /// Rebuilds a Mane basic cast's pair of slashes to the equipped path's
  /// geometry, and opens the windows that cast is entitled to.
  ///
  /// The pair is rebuilt rather than edited because spread, homing and width
  /// are all decided together — and homing is final on a projectile, so a
  /// Predator Step cast cannot be made to track by tweaking what came back
  /// from the chassis factory. Per-slash damage is derived from the factory's
  /// own output so the chassis stays the single source of base scaling.
  List<Projectile> _applyManeBasicMastery(
    List<Projectile> basics,
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
  ) {
    if (basics.isEmpty || !_isMasteryMane(slotIndex)) return basics;
    final state = _maneStateFor(slotIndex);
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);

    final crescendoEmpowered =
        has(ManeNodes.crescendo) && state.crescendoCasts > 0;
    if (crescendoEmpowered) state.crescendoCasts--;
    final bladeDanceEmpowered =
        has(ManeNodes.bladeDance) && state.bladeDanceCasts > 0;
    if (bladeDanceEmpowered) state.bladeDanceCasts--;
    state.pendingCrescendoCast = crescendoEmpowered;
    state.pendingBladeDanceCast = bladeDanceEmpowered;

    final shape = resolveManeBasicShape(
      hasNode: has,
      state: state,
      crescendoEmpowered: crescendoEmpowered,
    );
    // Predator Step is spent by the cast it empowers, not by time alone.
    if (shape.homes) state.predatorStepTimer = 0;

    // How much of this cast's damage the path is responsible for. A path that
    // trades damage away for reach (Sweeping Claws) is owed nothing here; its
    // payoff is counted in payloads and control instead.
    final upliftMultiplier =
        (shape.slashFraction / ManeTuning.baseSlashFraction) *
        shape.damageMultiplier;
    state.pendingMasteryDamageFraction = upliftMultiplier <= 1.0
        ? 0.0
        : (upliftMultiplier - 1.0) / upliftMultiplier;

    final seed = basics.first;
    // The chassis hands back its own 65% cut; scale from that to whatever the
    // path asks for rather than re-deriving physical attack here.
    final perSlash =
        seed.damage *
        (shape.slashFraction / ManeTuning.baseSlashFraction) *
        shape.damageMultiplier;

    final slashes = <Projectile>[];
    for (final sign in const [-1.0, 1.0]) {
      final angle = fireAngle + sign * shape.spread;
      slashes.add(
        Projectile(
            position: Offset(
              comp.position.dx + cos(angle) * 15,
              comp.position.dy + sin(angle) * 15,
            ),
            angle: angle,
            element: comp.member.element,
            damage: perSlash,
            // From the seed, so the family's halved blade speed is not lost
            // the moment a path is equipped.
            speedMultiplier: seed.speedMultiplier,
            life: seed.life,
            radiusMultiplier: seed.radiusMultiplier * shape.widthScale,
            visualScale: seed.visualScale * shape.widthScale,
            visualStyle: seed.visualStyle,
            homing: shape.homes,
            homingStrength: shape.homingStrength,
            sourceSlotIndex: slotIndex,
          )
          ..masteryReturnFraction = bladeDanceEmpowered
              ? ManeTuning.bladeDanceReturnFraction
              : 0,
      );
    }
    return slashes;
  }

  /// Everything a Mane basic cast does at launch: tags, Rhythm bookkeeping,
  /// and the Tempest Ring cadence.
  void _onManeBasicCast(int slotIndex, int castId, double fireAngle) {
    if (castId == 0 || !_isMasteryMane(slotIndex)) return;
    final state = _maneStateFor(slotIndex);
    final cast = mastery.cast(castId);
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);

    if (cast != null) {
      if (state.pendingCrescendoCast) cast.tag(ManeCastTags.crescendo);
      if (state.pendingBladeDanceCast) cast.tag(ManeCastTags.bladeDance);
    }
    state.pendingCrescendoCast = false;
    state.pendingBladeDanceCast = false;

    // Measured Cuts judges a cast that landed nothing, which cannot be known
    // until its slashes have had time to fly. The queue is drained in the
    // per-frame tick.
    if (has(ManeNodes.measuredCuts)) {
      state.pendingCasts.add(castId);
      // Bounded even at full Encore haste; a queue is a leak waiting to be
      // found, not a feature.
      if (state.pendingCasts.length > 16) state.pendingCasts.removeAt(0);
    }

    if (has(ManeNodes.tempestRing)) {
      state.castsSinceRing++;
      if (state.castsSinceRing >= ManeTuning.tempestRingCadence) {
        state.castsSinceRing = 0;
        _castManeTempestRing(slotIndex, fireAngle);
      }
    }
  }

  /// Tempest Ring: eight radial slashes on every fourth cast.
  void _castManeTempestRing(int slotIndex, double fireAngle) {
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.isDead) return;
    // The whole ring or none of it — half a ring reads as a bug, not a budget.
    if (!mastery.requestObjects(ManeTuning.tempestRingSlashes)) return;

    final basePower =
        comp.physAtk.toDouble() *
        ManeTuning.tempestRingSlashFraction *
        comp.damageAmp;

    // Its own cast: the hits must account (that is what caps them at three per
    // body and fires exactly one payload), but it is not a scheduled attack
    // and must not count as one.
    final ringCastId = mastery.beginCast(
      slotIndex: slotIndex,
      family: CreatureFamily.mane,
      element: comp.member.element,
      kind: MasteryCastKind.basic,
      projectileCount: ManeTuning.tempestRingSlashes,
      maxHitsPerTarget: ManeTuning.tempestRingMaxHitsPerTarget,
      countsAsCast: false,
    );
    mastery.cast(ringCastId)?.tag(ManeCastTags.tempestRing);

    final ring = <Projectile>[];
    for (var i = 0; i < ManeTuning.tempestRingSlashes; i++) {
      // Offset from the aim so the ring reads as thrown, not as a grid.
      final angle = fireAngle + (i * 2 * pi / ManeTuning.tempestRingSlashes);
      ring.add(
        Projectile(
            position: Offset(
              comp.position.dx + cos(angle) * 18,
              comp.position.dy + sin(angle) * 18,
            ),
            angle: angle,
            element: comp.member.element,
            damage: basePower,
            life: ManeTuning.tempestRingLife,
            speedMultiplier: ManeTuning.tempestRingSpeed,
            piercing: true,
            visualStyle: ProjectileVisualStyle.slash,
            sourceSlotIndex: slotIndex,
          )
          ..masteryCastId = ringCastId
          ..masteryGenerated = true,
      );
    }
    _appendCompanionProjectiles(ring);
  }

  /// Limitless reshapes the special itself: how far it carries, how hard it
  /// lands, whether it fades at all, and finally where the first shot goes.
  ///
  /// Runs after the per-family rewrites have settled, so it operates on the
  /// projectiles that will actually reach the world rather than on the
  /// ability table's first draft.
  void _applyManeSpecialMastery(
    List<Projectile> projectiles,
    CosmicSurvivalCompanion comp,
    int slotIndex,
  ) {
    _applyManeSpecialShape(projectiles, slotIndex);
    // Nothing reached the world to send. Light's ward swallows its whole cast
    // and builds its circuit from a ring instead; when the shared pool was
    // full that ring was refused, and asking an empty cast for its first shot
    // threw (2026-10-20 audit). The next cast tries again.
    if (projectiles.isEmpty) return;
    // Only when this Mane has no circuit turning. If one is lost — carried
    // out of the arena — the next cast quietly builds another.
    if (mastery.hasNode(slotIndex, ManeNodes.endlessCircuit) &&
        !_hasManeCircuit(slotIndex)) {
      _sendManeProjectileToOrbit(projectiles.first, comp, slotIndex);
    }
  }

  /// The three shape nodes of Limitless, without the capstone.
  ///
  /// Separate because Light's special never reaches the world as a projectile
  /// — the ward swallows it — so it needs these applied to the seed the ward
  /// is built from while its capstone is handled on the ward itself.
  void _applyManeSpecialShape(List<Projectile> projectiles, int slotIndex) {
    if (projectiles.isEmpty || !_isMasteryMane(slotIndex)) return;
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);
    if (!has(ManeNodes.farThrow)) return;

    final overdraw = has(ManeNodes.overdraw)
        ? 1.0 + ManeTuning.overdrawDamageBonus
        : 1.0;
    final noHorizon = has(ManeNodes.noHorizon);
    for (final projectile in projectiles) {
      projectile.life *= ManeTuning.farThrowLifeScale;
      projectile.damage *= overdraw;
      if (noHorizon) projectile.masteryNoLifetime = true;
    }
  }

  /// Light's version of the capstone: the outermost ring of the ward leaves
  /// the Mane and takes up the same circuit every other element rides.
  ///
  /// Light is the one element whose special never becomes a projectile in
  /// flight, so there is no "first shot" to peel off. Sending a ring instead
  /// is the same idea in its own language: the ward stops guarding the
  /// creature and starts guarding the map. The ward simply hangs a
  /// replacement on its next cast, because the circuit no longer counts as
  /// one of its rings.
  void _maybeSendLightRingToCircuit(
    int slotIndex,
    CosmicSurvivalCompanion comp,
  ) {
    if (!mastery.hasNode(slotIndex, ManeNodes.endlessCircuit)) return;
    if (_hasManeCircuit(slotIndex)) return;
    final rings = _maneLightRings(slotIndex);
    if (rings.isEmpty) return;
    _sendManeProjectileToOrbit(rings.first, comp, slotIndex);
  }

  /// Whether this Mane already has a circuit riding the rim.
  bool _hasManeCircuit(int slotIndex) {
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex && p.masteryCircuit && p.life > 0) {
        return true;
      }
    }
    return false;
  }

  /// Endless Circuit: one shot peels out to the rim and circles the arena.
  ///
  /// Established once, not on every cast. Fifteen of the seventeen Mane
  /// elements throw a single projectile, so taking the first shot of every
  /// cast would mean those Manes never hit their target again — the special
  /// would be permanently spent on a perimeter that already existed. One cast
  /// builds the circuit; every cast after it fires normally.
  ///
  /// Enemies spawn on a ring around the orb and walk inward, so the rim is
  /// not empty space — it is the line every wave crosses on its way in. That
  /// is what makes this a perimeter rather than a projectile thrown away.
  void _sendManeProjectileToOrbit(
    Projectile projectile,
    CosmicSurvivalCompanion comp,
    int slotIndex,
  ) {
    final centre = orb.position;
    final toCaster = comp.position - centre;
    final startAngle = toCaster.distance > 0.01
        ? atan2(toCaster.dy, toCaster.dx)
        : 0.0;
    projectile
      ..damage = projectile.damage * ManeTuning.circuitDamageScale
      ..orbitCenter = centre
      ..orbitRadius = _arenaRadius * ManeTuning.circuitRadiusFraction
      ..orbitAngle = startAngle
      ..orbitSpeed = ManeTuning.circuitAngularSpeed
      ..holdOrbit = true
      ..followShipOrbit = false
      // A Light ring re-anchors to its caster every frame. A circuit rides
      // the arena, not the Mane.
      ..followSourceCompanion = false
      ..masteryNoLifetime = true
      // A per-body ceiling, cleared once a lap (see the orbit update); one
      // strike a lap since 2026-10-21. Unlimited was wrong in both
      // directions: a body the head overlaps is billed every frame it
      // touches — four times a pass at
      // the old speed, eight at the halved one — while a flat ceiling with no
      // reset would retire the head against anything that survived one pass.
      ..maxHitsPerEnemy = ManeTuning.circuitHitsPerLap
      ..masteryCircuit = true
      // The slash is drawn eight units per point of visual scale to either
      // side of its position, but collides as a circle a fifth of that. On a
      // shot that crosses the arena in a second nobody can tell; on a blade
      // parked across the rim for the rest of the run, every enemy that walks
      // visibly through it and takes nothing is a lie the capstone tells. The
      // circuit collides as the blade it draws.
      ..radiusMultiplier = max(
        projectile.radiusMultiplier,
        ManeTuning.circuitBladeHalfLength *
            projectile.visualScale /
            Projectile.radius,
      )
      // Everything this shot does from here is the capstone's doing — left
      // alone it would have flown off and expired — so all of it attributes
      // to mastery rather than to the special that threw it.
      ..masteryGenerated = true;
    projectile.position = Offset(
      centre.dx + cos(startAngle) * projectile.orbitRadius,
      centre.dy + sin(startAngle) * projectile.orbitRadius,
    );
    mastery.recordCapstone(slotIndex);
  }

  /// Crescendo and Blade Dance both fire when the special goes out.
  void _onManeSpecialCast(int slotIndex) {
    if (!_isMasteryMane(slotIndex)) return;
    final state = _maneStateFor(slotIndex);

    if (mastery.hasNode(slotIndex, ManeNodes.crescendo)) {
      final spent = state.consumeRhythm();
      if (spent > 0) {
        state.crescendoCasts = spent;
        mastery.recordSpecialAmplification(slotIndex);
        // Only a full reserve opens an Encore, and only if one is not
        // already running.
        if (spent >= ManeTuning.maxRhythm &&
            mastery.hasNode(slotIndex, ManeNodes.encore) &&
            state.tryOpenEncore()) {
          mastery.recordCapstone(slotIndex);
          _spawnHitSpark(
            activeCompanions[slotIndex]?.position ?? orb.position,
            elementColor(activeCompanions[slotIndex]?.member.element ?? 'Fire'),
          );
        }
      }
    }

    if (mastery.hasNode(slotIndex, ManeNodes.bladeDance)) {
      state.bladeDanceCasts = ManeTuning.bladeDanceCasts;
      mastery.recordCapstone(slotIndex);
    }
  }

  /// Mane's reactions to one of its slashes landing.
  void _onManeHit(
    MasteryHit hit, {
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
  }) {
    final slotIndex = hit.slotIndex;
    final state = _maneStateFor(slotIndex);
    final cast = hit.cast;
    bool has(String nodeId) => mastery.hasNode(slotIndex, nodeId);

    // ── Tempest Ring: the first radial hit carries the element, once. ──
    if (cast.hasTag(ManeCastTags.tempestRing)) {
      if (has(ManeNodes.tempestRing) && mastery.claimCastOnce(cast.id)) {
        triggerElementalPayload(
          slotIndex: slotIndex,
          effectId: ManeNodes.tempestRing,
          enemy: enemy,
          boss: boss,
          triggeringDamage: hit.damage,
        );
      }
      return;
    }

    if (!hit.fromBasic) return;

    // ── Twin Fang ──
    if (has(ManeNodes.crosscut) && hit.isDualHit) {
      final comp = activeCompanions[slotIndex];
      if (comp != null) {
        final bonus =
            comp.physAtk.toDouble() *
            ManeTuning.crosscutBonusFraction *
            comp.damageAmp;
        if (enemy != null) {
          _damageEnemy(
            enemy,
            bonus,
            sourceSlotIndex: slotIndex,
            masterySource: MasteryDamageSource.mastery,
          );
        } else if (boss != null) {
          damageBoss(
            bonus,
            sourceSlotIndex: slotIndex,
            target: boss,
            masterySource: MasteryDamageSource.mastery,
          );
        }
      }
      if (mastery.claimCastOnce(cast.id)) {
        triggerElementalPayload(
          slotIndex: slotIndex,
          effectId: ManeNodes.crosscut,
          enemy: enemy,
          boss: boss,
          strength: ManeTuning.crosscutPayloadStrength,
          triggeringDamage: hit.damage,
        );
      }
    }

    // ── War Rhythm ──
    if (has(ManeNodes.measuredCuts) && hit.isDualHit) {
      state.gainRhythm();
    }
    if (cast.hasTag(ManeCastTags.crescendo) && mastery.claimCastOnce(cast.id)) {
      triggerElementalPayload(
        slotIndex: slotIndex,
        effectId: ManeNodes.crescendo,
        enemy: enemy,
        boss: boss,
        strength: ManeTuning.crescendoPayloadStrength,
        triggeringDamage: hit.damage,
      );
    }
  }

  /// Mane's reactions to a kill.
  void _onManeKill(MasteryKill kill) {
    final slotIndex = kill.slotIndex;
    if (slotIndex == null || !_isMasteryMane(slotIndex)) return;
    if (!kill.fromBasic) return;
    final state = _maneStateFor(slotIndex);

    if (mastery.hasNode(slotIndex, ManeNodes.predatorStep)) {
      state.predatorStepTimer = ManeTuning.predatorStepWindow;
    }
    if (mastery.hasNode(slotIndex, ManeNodes.encore)) {
      state.extendEncore();
    }
  }

  /// The share of the next basic cast's damage that mastery is owed, set by
  /// the shape pass that just ran.
  double _masteryBasicUplift(int slotIndex) =>
      _maneMastery[slotIndex]?.pendingMasteryDamageFraction ??
      _letMastery[slotIndex]?.pendingMasteryDamageFraction ??
      _pipMastery[slotIndex]?.pendingMasteryDamageFraction ??
      0.0;

  /// The same for a special. Limitless is the only path that raises special
  /// damage outright, and it does so by a flat amount that depends on nothing
  /// but which nodes are equipped — so unlike the basic uplift it is knowable
  /// before the cast opens.
  double _masterySpecialUplift(int slotIndex) {
    if (!mastery.hasNode(slotIndex, ManeNodes.overdraw)) return 0.0;
    const bonus = ManeTuning.overdrawDamageBonus;
    return bonus / (1.0 + bonus);
  }

  /// Basic-attack cooldown multiplier from mastery. Below 1 is faster.
  double _masteryBasicCooldownMultiplier(int slotIndex) {
    if (_isMasteryLet(slotIndex)) {
      if (mastery.hasNode(slotIndex, LetNodes.fireForEffect) &&
          _anyLetSighted()) {
        return 1.0 / (1.0 + LetTuning.fireForEffectHaste);
      }
      return 1.0;
    }
    if (!_isMasteryMane(slotIndex)) return 1.0;
    return _maneStateFor(slotIndex).hasteMultiplier(
      hasMeasuredCuts: mastery.hasNode(slotIndex, ManeNodes.measuredCuts),
      hasEncore: mastery.hasNode(slotIndex, ManeNodes.encore),
    );
  }

  /// Blade Dance: a spent slash flies home, hitting once more on the way.
  ///
  /// The return carries no cast and no return fraction of its own, so it
  /// cannot trigger Crosscut, cannot fire a payload and cannot boomerang
  /// again — the capstone's three exclusions, all of them structural rather
  /// than checked.
  void _spawnMasteryReturns() {
    if (!mastery.enabled) return;
    List<Projectile>? returns;
    for (final p in companionProjectiles) {
      if (p.life > 0 || p.masteryReturnFraction <= 0) continue;
      final slotIndex = p.sourceSlotIndex;
      if (slotIndex == null) continue;
      final comp = activeCompanions[slotIndex];
      if (comp == null || comp.isDead) continue;
      if (!mastery.requestObjects(1)) break;

      final toward = comp.position - p.position;
      final dist = toward.distance;
      if (dist < 1) continue;
      final angle = atan2(toward.dy, toward.dx);
      (returns ??= <Projectile>[]).add(
        Projectile(
          position: p.position,
          angle: angle,
          element: p.element,
          damage: p.damage * p.masteryReturnFraction,
          life: (dist / Projectile.speed) + 0.1,
          radiusMultiplier: p.radiusMultiplier,
          visualScale: p.visualScale * 0.82,
          visualStyle: p.visualStyle,
          sourceSlotIndex: slotIndex,
        )..masteryGenerated = true,
      );
    }
    if (returns != null) {
      _appendCompanionProjectiles(returns, cue: SoundCue.combatProjectile);
    }
  }

  /// Per-frame Mane upkeep: windows expire, and casts that landed nothing
  /// finally cost their Rhythm.
  void _updateManeMastery(double dt) {
    if (_maneMastery.isEmpty) return;
    for (final entry in _maneMastery.entries) {
      final slotIndex = entry.key;
      final state = entry.value;
      state.tick(dt);

      if (state.pendingCasts.isEmpty) continue;
      // Oldest first, so one pass drains everything that has come due.
      while (state.pendingCasts.isNotEmpty) {
        final castId = state.pendingCasts.first;
        final cast = mastery.cast(castId);
        if (cast == null) {
          // Pruned out from under us; nothing left to judge.
          state.pendingCasts.removeAt(0);
          continue;
        }
        if (mastery.clock - cast.castTime < ManeTuning.missGrace) break;
        state.pendingCasts.removeAt(0);
        if (cast.totalHits == 0 &&
            mastery.hasNode(slotIndex, ManeNodes.measuredCuts)) {
          state.loseRhythm();
        }
      }
    }
  }

  /// Heals a companion and reports how much actually landed, so telemetry
  /// counts healing rather than attempted healing.
  double _healCompanion(CosmicSurvivalCompanion comp, double amount) {
    if (amount <= 0 || comp.isDead) return 0;
    final before = comp.currentHp;
    comp.currentHp = min(comp.maxHp, comp.currentHp + amount.round());
    return (comp.currentHp - before).toDouble();
  }

  void _damageEnemy(
    CosmicSurvivalEnemy enemy,
    double damage, {
    int? sourceSlotIndex,
    bool fromPipSpecial = false,
    bool autoAttack = false,
    bool execute = false,
    bool fromShip = false,
    int masteryCastId = 0,
    MasteryDamageSource? masterySource,

    /// The share of this hit a mastery multiplier added, filed as mastery.
    double masteryUplift = 0,
  }) {
    damage *= outbreak?.damageMultiplier(enemy) ?? 1.0;
    // Payload statuses that make a body take more: Dark's expose and Light's
    // illuminate. Applied before the family/tier multipliers so they read as
    // a property of the target, which is what both payloads describe.
    if (mastery.enabled) damage *= enemy.masteryDamageTakenMultiplier;
    // Let: the auto-attack meteor's own bonuses, and Called Shot for anyone.
    // Pip: Pin Cushion. Either is the share of the hit the source's own
    // mastery earned; one slot is never both families.
    var ownUplift = masteryUplift;
    int? calledShotSlot;
    if (mastery.enabled) {
      final letBonus = _letAutoAttackBonus(
        masteryCastId,
        enemy,
        enemy.hpFraction,
        identityHashCode(enemy),
      );
      if (letBonus > 0) {
        damage *= 1 + letBonus;
        ownUplift = letUpliftFraction(letBonus);
      }
      if (sourceSlotIndex != null &&
          enemy.isLetSighted &&
          enemy.letSightCalledShot) {
        damage *= 1 + LetTuning.calledShotBonus;
        calledShotSlot = enemy.letSightSlot;
      }
      final pinBonus = _pipPinBonus(
        sourceSlotIndex,
        identityHashCode(enemy),
        autoAttack: autoAttack,
        castId: masteryCastId,
      );
      if (pinBonus > 0) {
        damage *= 1 + pinBonus;
        ownUplift = pipUpliftFraction(1 + pinBonus);
      }
    }
    // Sighted, for the rest of what a Let throws: its auto-attack meteor
    // reads it in _letAutoAttackBonus.
    if (mastery.enabled && sourceSlotIndex != null && !autoAttack) {
      final sight = _letSightedBonus(sourceSlotIndex, enemy);
      if (sight > 0) {
        damage *= 1 + sight;
        ownUplift = letUpliftFraction(sight);
      }
    }
    // Bulwark: a Horn's own bulk, added to its auto-attacks. The special
    // carries its share through chargeDamage instead, folded in once at cast,
    // so a charge ploughing through six bodies does not add it six times.
    // Longshot: what a Wing earns for the distance it kept. Applied to its
    // auto-attacks here; the beam applies its own at the tick site.
    int? sanctumSlot;
    if (mastery.enabled && sourceSlotIndex != null) {
      damage *= _homeGroundPower(sourceSlotIndex, autoAttack: autoAttack);
      // Longshot: "everything you do to an enemy past 60% of your range",
      // the special included. It was read for auto-attacks and the beam
      // only, and a Wing's special is most of what it deals (2026-10-21
      // mastery sweep).
      final longshot = _wingLongshotMultiplier(sourceSlotIndex, enemy.position);
      if (longshot > 1) {
        damage *= longshot;
        ownUplift = 1 - (1 - ownUplift) / longshot;
      }
    }
    if (mastery.enabled && sourceSlotIndex != null && autoAttack) {
      sanctumSlot = _sanctumFor(sourceSlotIndex);
    }
    // Weight of Heaven: applied here rather than at seventeen bespoke world
    // sites. A world's output is everything a spent Mystic deals that is not
    // its own auto-attack, which is exactly what this condition says.
    if (mastery.enabled &&
        sourceSlotIndex != null &&
        !autoAttack &&
        _mysticSpentSlots.contains(sourceSlotIndex)) {
      damage *= _mysticWorldDamageMultiplier(sourceSlotIndex);
    }
    var hornWeighted = false;
    if (mastery.enabled && sourceSlotIndex != null && autoAttack) {
      final comp = activeCompanions[sourceSlotIndex];
      if (comp != null) {
        final bonus = _hornBulwarkBonusFor(
          sourceSlotIndex,
          comp,
          isSpecial: false,
        );
        if (bonus > 0) {
          damage += bonus;
          hornWeighted = true;
          // The weight's part of the hit is the path's, for telemetry.
          ownUplift = bonus / damage;
        }
      }
    }
    final weight = _mysticWeightMultiplier(enemy.tier);
    damage *= weight;
    // Only worth showing on the bodies the world actually leans on.
    if (weight > 1.2 && _tierHeft(enemy.tier) >= 2) {
      _splatterMire(enemy.position);
    }
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
    // True executions bypass mitigation but retain normal damage attribution
    // and kill hooks. Boss damage uses a separate pipeline.
    if (execute) damage = max(0.0, enemy.hp);
    final hpBefore = enemy.hp;
    if (damage > 0 && !enemy.isDead) {
      onSound?.call(
        damage >= 100 ? SoundCue.combatHitHeavy : SoundCue.combatHitLight,
      );
    }
    enemy.hp -= damage;
    enemy.hitFlash = 1.0;

    if (powerUps.hasBerserker && orb.hpPercent < 0.3) {
      enemy.hp -= damage;
    }

    final dealt = hpBefore - max(enemy.hp, 0.0);
    // Burn: whatever shape a Fire or Lava Alchemon's ability takes (a ram, a
    // crater, a trap, a world), what it hits burns. Most of them never pass
    // through AbilityEffectKind.burn, so it is marked here, by who dealt it.
    if (dealt > 0 &&
        !autoAttack &&
        enemy.hp > 0 &&
        _burnsWhatItHits(sourceSlotIndex)) {
      _burnEnemy(enemy);
    }
    if (sourceSlotIndex != null && dealt > 0) {
      _runStatsFor(sourceSlotIndex).damageDealt += dealt;
    } else if (dealt > 0) {
      stats.otherDamage += dealt;
      if (fromShip) {
        stats.shipDamage += dealt;
        if (hpBefore > 0 && enemy.hp <= 0) stats.shipKills++;
      }
    }
    if (autoAttack) _payMysticBloodTithe(dealt, enemy.position);

    final source =
        masterySource ?? _inferMasterySource(masteryCastId, autoAttack);
    _recordDamageWithLetUplift(
      sourceSlotIndex,
      dealt,
      source,
      castId: masteryCastId,
      letUplift: ownUplift,
      calledShotSlot: calledShotSlot,
    );
    final hit = mastery.recordHit(
      castId: masteryCastId,
      targetId: identityHashCode(enemy),
      damage: dealt,
    );
    if (hit != null) _onMasteryHit(hit, enemy: enemy);
    // Sanctum: the world's element rides an ally's attack onto what it hit.
    if (sanctumSlot != null && enemy.hp > 0 && !enemy.isDead) {
      _applySanctum(sanctumSlot, enemy: enemy, dealt: dealt);
    }

    if (enemy.hp <= 0) {
      _killEnemy(
        enemy,
        sourceSlotIndex: sourceSlotIndex,
        fromPipSpecial: fromPipSpecial,
        masteryCastId: masteryCastId,
        masterySource: source,
        hornWeighted: hornWeighted,
      );
    }
  }

  /// What bucket a projectile's damage belongs in.
  ///
  /// Returning null defers to the cast, which knows whether it was a basic or
  /// a special. A projectile with no cast still knows: every special stamps an
  /// ability family and a basic leaves it empty. Without this a party with no
  /// mastery equipped filed all of its special damage under "other", which
  /// made the no-mastery baseline — the thing every balance comparison is
  /// measured against — silently useless.
  MasteryDamageSource? _projectileDamageSource(Projectile p) {
    if (p.masteryGenerated) return MasteryDamageSource.mastery;
    if (p.masteryCastId != 0) return null;
    return p.abilityFamily.isEmpty ? null : MasteryDamageSource.special;
  }

  /// Where a piece of damage came from, when the caller did not say.
  ///
  /// A tracked cast knows whether it was a basic or a special; anything with
  /// no cast is either the family autoattack (survival's long-standing
  /// `autoAttack` flag, which every special stamps off) or someone else's
  /// damage entirely — the ship, an orb turret, a run perk.
  MasteryDamageSource _inferMasterySource(int castId, bool autoAttack) {
    final cast = mastery.cast(castId);
    if (cast != null) {
      return cast.kind == MasteryCastKind.basic
          ? MasteryDamageSource.basic
          : MasteryDamageSource.special;
    }
    return autoAttack ? MasteryDamageSource.basic : MasteryDamageSource.other;
  }

  void _killEnemy(
    CosmicSurvivalEnemy enemy, {
    int? sourceSlotIndex,
    bool grantAlchemyReward = true,
    bool fromPipSpecial = false,
    int masteryCastId = 0,
    MasteryDamageSource? masterySource,

    /// This kill was dealt by a hit carrying Bulwark's weight, which is the
    /// only thing Anvil ruptures on.
    bool hornWeighted = false,
  }) {
    if (enemy.isDead) return;
    if (mastery.enabled && enemy.isLetSighted) _hopLetSight(enemy);
    if (mastery.enabled && sourceSlotIndex != null) {
      _onMasteryKill(
        MasteryKill(
          slotIndex: sourceSlotIndex,
          targetId: identityHashCode(enemy),
          cast: mastery.cast(masteryCastId),
          isBoss: false,
          source: masterySource ?? _inferMasterySource(masteryCastId, false),
        ),
        enemy: enemy,
      );
    }
    onSound?.call(SoundCue.combatEnemyDefeat);
    enemy.isDead = true;
    // Inside a Spirit world the chaff gets back up on our side. Done here,
    // at the one place a body actually dies, so it works for every source of
    // death — a companion, the ship, a trap, a burn tick — rather than only
    // for whatever path happened to be wired up.
    _raiseMysticRevenant(enemy);
    _dropMysticCrystal(enemy);
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
      // Paid when its grains are taken in, not on the kill: see
      // surge_grains.dart.
      _surgeGrains.spawn(
        enemy.position,
        surgeGrainsFor(enemy.tier, enemy.isElite),
        alchemyValue * _alchemyMeterGainMultiplier * alchemyPacingMultiplier,
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
        const explodeRadius = ManeRuntime.plantRootExplodeRadius;
        final explodeDamage =
            (companion?.elemAtk ?? 4) * ManeRuntime.plantRootExplodeShare;
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
      // Anvil: a body killed by Bulwark's weight ruptures. Gated on the hit
      // having actually carried the weight, so ordinary kills pay nothing.
      if (companion != null && hornWeighted) {
        _applyHornAnvil(sourceSlotIndex, companion, enemy);
      }
      // Deathmask: a dart kill leaves a trap where the body fell. Only a
      // dart kill — a trap's own kills spawning traps is the chain that once
      // cost this game 2.2 seconds in a single frame.
      if (companion != null &&
          companion.member.family.toLowerCase() == 'mask') {
        _spawnMaskGrave(
          sourceSlotIndex,
          companion,
          enemy.position,
          fromAutoAttack: masterySource == MasteryDamageSource.basic,
        );
      }
      // Plague: an infected body bursts on death.
      if (mastery.enabled && enemy.isMaskInfected) _applyMaskPlague(enemy);
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
        fromAutoAttack: masterySource == MasteryDamageSource.basic,
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
          final burstDamage = companion.abilityAtk * 1.6;
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
        final heal = KinSupport.spiritWispKillHeal(
          KinSupport.findSpiritWisp(companionProjectiles, companion.slotIndex),
          companion.abilityAtk,
        );
        if (heal > 0 && !companion.isDead) {
          companion.currentHp = min(
            companion.maxHp,
            companion.currentHp + heal.round(),
          );
        }
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

    // Elemental Fury: one eruption per kill, paid out of the killer's
    // elemental attack. It used to splash a flat 18/26/34 and every body the
    // splash finished erupted in turn, so one kill in a dense front chained
    // through all of it until wisp health outgrew the flat number (wipes to
    // wave 40-60, then nothing) — and it ignored the creature's stats.
    // Bodies the splash finishes do not erupt again.
    if (powerUps.hasElementalFury && !_furyErupting) {
      final splashDamage = _furySplashDamage(sourceSlotIndex);
      if (splashDamage > 0) {
        _furyErupting = true;
        _visitEnemiesNear(enemy.position, 80, (other) {
          if (_withinRange(other.position, enemy.position, 80)) {
            _damageEnemy(
              other,
              splashDamage,
              sourceSlotIndex: sourceSlotIndex,
            );
          }
          return false;
        });
        _furyErupting = false;
      }
    }
  }

  /// True while a Fury eruption is dealing its splash, so the kills it makes
  /// do not erupt in turn.
  bool _furyErupting = false;

  /// Fury's splash: a share of the killer's E-ATK by level (25/40/55%). A
  /// kill with no creature behind it (the ship, the orb, a trap with no
  /// owner) splashes from the team's average E-ATK.
  double _furySplashDamage(int? sourceSlotIndex) {
    final share = const [0.0, 0.25, 0.40, 0.55][powerUps.elementalFuryLevel
        .clamp(0, 3)];
    if (share <= 0) return 0;
    final killer = sourceSlotIndex == null
        ? null
        : activeCompanions[sourceSlotIndex];
    if (killer != null) return killer.elemAtk * share;
    if (activeCompanions.isEmpty) return 0;
    var total = 0.0;
    for (final companion in activeCompanions.values) {
      total += companion.elemAtk;
    }
    return total / activeCompanions.length * share;
  }

  @visibleForTesting
  void debugGrantAlchemy(double value) => _grantAlchemy(value);

  /// When the ship last made the gathering sound.
  double _lastGrainSound = -1;

  /// A surge grain taken in by the ship or the core. Paid even while the
  /// ship is down: the kill that left it was made while it was up. The ship
  /// gathering them is heard (a soft intake and a pinch of grains, at most
  /// every 150 ms); the core drinking them is silent.
  void _takeSurgeGrain(double value, bool byShip) {
    if (value <= 0) return;
    if (byShip && stats.timeElapsed - _lastGrainSound >= 0.15) {
      _lastGrainSound = stats.timeElapsed;
      onSound?.call(SoundCue.cosmicMatterCollect);
    }
    alchemicalMeter = min(
      alchemicalMeterMax,
      alchemicalMeter +
          value * CosmicSurvivalBalance.alchemicalRewardMultiplier,
    );
  }

  /// A cleared wave: at the top Surge Magnet level, whatever the ship did
  /// not gather flows to the core; below it, the grains stay out for the
  /// ship.
  void _endWaveGrains() {
    if (powerUps.surgeMagnetLevel >= kSurgeMagnetMaxLevel) {
      _surgeGrains.flushToCore();
    }
  }

  /// The wave-clear step for grains, for tests.
  @visibleForTesting
  void debugEndWaveGrains() => _endWaveGrains();

  /// Surge value lying on the field, not yet taken in.
  @visibleForTesting
  double get debugSurgeOut => _surgeGrains.valueOut;

  @visibleForTesting
  SurgeGrains get debugSurgeGrains => _surgeGrains;

  void _grantAlchemy(double value) {
    if (ship.isDead || value <= 0) return;
    alchemicalMeter = min(
      alchemicalMeterMax,
      alchemicalMeter +
          value * CosmicSurvivalBalance.alchemicalRewardMultiplier,
    );
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

  void _spawnAlchemyPickupBurst(Offset center, Color color, {int count = 6}) {
    if (_vfx.length >= 150) return;
    for (var i = 0; i < count && _vfx.length < 150; i++) {
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

    // The orb already took the contact hit. Charging the same explosion
    // again made heavy breakers capable of deleting a healthy orb in one hit.

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
    // By index: an extra's hit on the orb can break a Bastion's shield, and
    // the rupture can kill the primary, which promotes an extra out of this
    // list mid-walk.
    for (var i = 0; i < extraBosses.length; i++) {
      final extra = extraBosses[i];
      if (extra.isDead) continue;
      _updateBossInstance(dt, extra);
    }
  }

  void _updateBossInstance(double dt, SurvivalBoss boss) {
    boss.hitFlash = (boss.hitFlash - dt * 4).clamp(0, 1);
    if (mastery.enabled) {
      final dot = boss.tickMasteryStatuses(dt);
      if (dot > 0) {
        damageBoss(
          dot,
          sourceSlotIndex: boss.masteryDotSlot,
          target: boss,
          masterySource: MasteryDamageSource.mastery,
        );
        if (boss.isDead) return;
      }
    }
    if (boss.isSpawning) {
      _updateBossEntrance(dt, boss);
      return;
    }
    boss.phaseTimer += dt;

    // A chilled boss crawls. Captured before the AI runs and scaled after, so
    // whatever the discipline did to its position this frame is slowed by the
    // same factor without touching boss.speed, which the AIs write themselves.
    final positionBeforeAi = boss.position;
    final chilled = boss.chillTimer > 0;
    if (chilled) {
      boss.chillTimer = max(0.0, boss.chillTimer - dt);
      if (boss.chillTimer <= 0) boss.chillMultiplier = 1.0;
    }
    // Wing+Ice frost thaws once the beam is off the boss, as on a body.
    if (boss.frostGrace > 0) {
      boss.frostGrace = max(0.0, boss.frostGrace - dt);
    } else if (boss.frostBuildup > 0) {
      boss.frostBuildup = max(0.0, boss.frostBuildup - dt * 0.35);
    }

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

    // Scale whatever ground the AI just covered. Done here rather than inside
    // each discipline so charge dashes, strafes and approach all slow by the
    // same factor, and so nothing has to know about the chill.
    if (chilled) {
      boss.position =
          Offset.lerp(positionBeforeAi, boss.position, boss.chillMultiplier) ??
          boss.position;
    }

    _applyBossContactDamage(boss, dt);
  }

  /// The live Mane+Light rings belonging to one companion, outermost first.
  List<Projectile> _maneLightRings(int slotIndex) =>
      ManeLightWard.rings(companionProjectiles, slotIndex);

  /// Whether [p] is a Mane+Light ward ring, the one projectile that strikes a
  /// boss on a cadence rather than once.
  static bool _isManeLightRing(Projectile p) =>
      p.holdOrbit && p.abilityFamily == 'mane' && p.element == 'Light';

  /// One Mane+Light cast: hang the next ring, or feed the next one in the
  /// cycle if all three are already turning.
  ///
  /// How far the ward has been fed is read off the rings still standing
  /// ([ManeLightWard.fedLevels]), so a ward whose rings have expired is built
  /// and fed again from the start. The companion's counter is only kept in
  /// step with it.
  void _castManeLightWard(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    Projectile template,
  ) {
    // Hang the next ring on the first free orbit (every ring is born at
    // level 0 however far along the ward is), or feed the least-fed one once
    // all are turning — over the rings this ward actually has: a Light whose
    // Beauty holds three has no fourth to feed.
    final result = ManeLightWard.cast(
      rings: _maneLightRings(slotIndex),
      // Beauty decides how wide a ward this Light can hold up.
      ringCap: maneLightRingCount(
        _effectiveBeauty(slotIndex),
        potential: party[slotIndex].statBeautyPotential,
      ),
      casterPos: comp.position,
      casterAngle: comp.angle,
      template: template,
      slot: slotIndex,
    );
    comp.abilityKillStacks = result.growth;
    final hung = result.hung;
    if (hung != null) {
      // Silent: hanging the ward is the cast, already heard.
      _appendCompanionProjectile(hung, silent: true);
      _spawnHitSpark(comp.position, elementColor('Light'));
      return;
    }
    final fed = result.fed;
    if (fed != null) {
      _spawnDetonationBurst(
        fed.position,
        elementColor('Light'),
        result.burstRadius,
      );
    }
  }

  /// Lands a crowd-control effect on a boss.
  ///
  /// Bosses had no CC state at all before this — every slow, root and freeze in
  /// the game checked `CosmicSurvivalEnemy` and silently did nothing to a boss,
  /// which is why Mane+Ice froze everything on the field except the one target
  /// the player most wanted stopped.
  ///
  /// Resisted rather than immune: a boss keeps [kBossChillFloor] of its speed
  /// and holds the chill for a fraction of the duration an ordinary enemy
  /// would. A fully frozen boss would trivialise the fight it is the centre of.
  void _applyBossCrowdControl(
    SurvivalBoss boss,
    AbilityEffectKind effect,
    double duration,
  ) {
    if (boss.isDead || boss.isSpawning) return;
    if (!CosmicAbilityRuntime.isCrowdControl(effect)) return;
    final slow = CosmicAbilityRuntime.survivalSlowMultiplier(effect);
    boss.chillMultiplier = min(
      boss.chillMultiplier,
      max(kBossChillFloor, slow),
    );
    boss.chillTimer = max(
      boss.chillTimer,
      CosmicAbilityRuntime.survivalCrowdControlDuration(effect, duration) *
          kBossChillDurationScale,
    );
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
        add.target = (add.conduct == EnemyConduct.charge && add.hasHeavyBody)
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
        add.target = switch (add.conduct) {
          EnemyConduct.standoff => CosmicEnemyTarget.orb,
          EnemyConduct.stalk => CosmicEnemyTarget.ship,
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
        add.target = switch (add.conduct) {
          EnemyConduct.standoff => CosmicEnemyTarget.companion,
          EnemyConduct.stalk => CosmicEnemyTarget.ship,
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

  /// How many volleys a ranged boss fires before it must vent.
  static const int _bossBurstBeforeVent = 3;

  /// How long it stands planted and exposed afterwards.
  static const double _bossVentDuration = 1.9;

  void _updateBossGunner(double dt, SurvivalBoss boss) {
    // The fight needs a PLACE. Position is held relative to the ORB — the
    // thing you are defending — while aim tracks you. Anchoring position to
    // the player meant the boss fled whenever you approached, so it could be
    // dragged anywhere and the fight had no ground to stand on.
    final aimAt = ship.isDead ? orb.position : ship.position;
    final station = orb.position;

    // Venting: after a burst it plants, stops firing, and is exposed. This is
    // the counterplay that makes closing the distance worth doing.
    if (boss.isVenting) {
      boss.overheatTimer -= dt;
      if (boss.overheatTimer <= 0) {
        boss.shotsSinceVent = 0;
      }
      boss.angle = atan2(
        aimAt.dy - boss.position.dy,
        aimAt.dx - boss.position.dx,
      );
      return;
    }

    final toStation = station - boss.position;
    final dist = max(1.0, toStation.distance);
    final tangent = Offset(-toStation.dy / dist, toStation.dx / dist);
    final orbitDist = boss.engagementRange;
    final radialPull = boss.movementStyle == SurvivalBossMovementStyle.sniper
        ? 0.7
        : 0.5;
    final radialForce = (dist - orbitDist) * radialPull;
    final norm = Offset(toStation.dx / dist, toStation.dy / dist);
    boss.position +=
        (norm * radialForce + tangent * boss.speed * boss.strafeWeight * 0.7) *
        dt;
    boss.angle = atan2(
      aimAt.dy - boss.position.dy,
      aimAt.dx - boss.position.dx,
    );

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0) {
      boss.shootTimer = SurvivalBoss.shootCooldown;
      // Count the burst; overheat once it is spent.
      boss.shotsSinceVent++;
      if (boss.shotsSinceVent >= _bossBurstBeforeVent) {
        boss.overheatTimer = _bossVentDuration;
      }
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
    // Same fix as the gunner: hold station on the objective, aim at the
    // player. Anchoring position to the player made it retreat on approach.
    final anchor = orb.position;
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
    bool autoAttack = false,
    bool fromShip = false,
    int masteryCastId = 0,
    MasteryDamageSource? masterySource,

    /// The share of this hit a mastery multiplier added, filed as mastery.
    double masteryUplift = 0,
  }) {
    final boss = target ?? activeBoss;
    if (boss == null || boss.isDead) return;
    if (mastery.enabled) damage *= boss.masteryDamageTakenMultiplier;
    var ownUplift = masteryUplift;
    int? calledShotSlot;
    int? sanctumSlot;
    if (mastery.enabled) {
      final letBonus = _letAutoAttackBonus(
        masteryCastId,
        boss,
        boss.hpFraction,
        identityHashCode(boss),
      );
      if (letBonus > 0) {
        damage *= 1 + letBonus;
        ownUplift = letUpliftFraction(letBonus);
      }
      if (sourceSlotIndex != null &&
          boss.isLetSighted &&
          boss.letSightCalledShot) {
        damage *= 1 + LetTuning.calledShotBonus;
        calledShotSlot = boss.letSightSlot;
      }
      final pinBonus = _pipPinBonus(
        sourceSlotIndex,
        identityHashCode(boss),
        autoAttack: autoAttack,
        castId: masteryCastId,
      );
      if (pinBonus > 0) {
        damage *= 1 + pinBonus;
        ownUplift = pipUpliftFraction(1 + pinBonus);
      }
      if (sourceSlotIndex != null && autoAttack) {
        sanctumSlot = _sanctumFor(sourceSlotIndex);
      }
    }
    // What [_damageEnemy] gives a hit for who threw it, given on a boss too.
    // Each of these reached bodies only, so a boss wave took four paths away
    // (2026-10-21 mastery sweep): Home Ground for standing in a Mystic's
    // world, Longshot for the distance a Wing kept, Bulwark's weight on a
    // Horn's auto-attacks, and Weight of Heaven on a lit world's output.
    if (mastery.enabled && sourceSlotIndex != null) {
      damage *= _homeGroundPower(sourceSlotIndex, autoAttack: autoAttack);
      final longshot = _wingLongshotMultiplier(sourceSlotIndex, boss.position);
      if (longshot > 1) {
        damage *= longshot;
        ownUplift = 1 - (1 - ownUplift) / longshot;
      }
      if (autoAttack) {
        final horn = activeCompanions[sourceSlotIndex];
        final weight = horn == null
            ? 0.0
            : _hornBulwarkBonusFor(sourceSlotIndex, horn, isSpecial: false);
        if (weight > 0) {
          damage += weight;
          ownUplift = weight / damage;
        }
      } else if (_mysticSpentSlots.contains(sourceSlotIndex)) {
        damage *= _mysticWorldDamageMultiplier(sourceSlotIndex);
      }
    }
    if (mastery.enabled && sourceSlotIndex != null && !autoAttack) {
      final sight = _letSightedBonus(sourceSlotIndex, boss);
      if (sight > 0) {
        damage *= 1 + sight;
        ownUplift = letUpliftFraction(sight);
      }
    }
    // A Blood world tithes from bosses as well. Taken off the incoming figure
    // rather than the post-shield one: what the player feels is the shot they
    // fired, and a boss with its shield up would otherwise quietly turn the
    // world off.
    if (autoAttack) _payMysticBloodTithe(damage, boss.position);

    damage *= _companionOutgoingDamageMultiplier(sourceSlotIndex, vsBoss: true);
    damage *= _mysticBossWeightMultiplier();

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
    damageNumbers.spawn(
      boss.position,
      effectiveDamage,
      // Jittered so simultaneous hits don't stack into one illegible blob.
      jitter: Offset(
        (_rng.nextDouble() - 0.5) * boss.radius * 1.2,
        -boss.radius * 0.75 - _rng.nextDouble() * 8,
      ),
    );

    final dealtToBoss = hpBefore - max(boss.hp, 0.0);
    if (sourceSlotIndex != null && dealtToBoss > 0) {
      _runStatsFor(sourceSlotIndex).damageDealt += dealtToBoss;
    } else if (dealtToBoss > 0) {
      stats.otherDamage += dealtToBoss;
      if (fromShip) stats.shipDamage += dealtToBoss;
    }

    final bossSource =
        masterySource ?? _inferMasterySource(masteryCastId, autoAttack);
    _recordDamageWithLetUplift(
      sourceSlotIndex,
      dealtToBoss,
      bossSource,
      castId: masteryCastId,
      letUplift: ownUplift,
      calledShotSlot: calledShotSlot,
    );
    final bossHit = mastery.recordHit(
      castId: masteryCastId,
      targetId: identityHashCode(boss),
      damage: dealtToBoss,
      isBoss: true,
    );
    if (bossHit != null) _onMasteryHit(bossHit, boss: boss);
    if (sanctumSlot != null && boss.hp > 0 && !boss.isDead) {
      _applySanctum(sanctumSlot, boss: boss, dealt: dealtToBoss);
    }

    if (boss.hp <= 0) {
      if (mastery.enabled && boss.isLetSighted) _hopLetSight(boss);
      if (mastery.enabled && sourceSlotIndex != null) {
        _onMasteryKill(
          MasteryKill(
            slotIndex: sourceSlotIndex,
            targetId: identityHashCode(boss),
            cast: mastery.cast(masteryCastId),
            isBoss: true,
            source: bossSource,
          ),
          boss: boss,
        );
      }
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
    _grantAlchemy(CosmicSurvivalBalance.bossAlchemyReward(spawner.currentWave));
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

      if (proj.life <= 0) continue;

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

      if (proj.life <= 0) continue;

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
          ship.currentHp -= proj.damage * _shipBodyDamageTaken;
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
    // Beams and shockwaves tick alongside the projectiles they replace.
    _updateEnemyHazards(dt);
  }

  // == Companion Projectiles (cosmic game style) ===========================

  void resolveAbilityHit(
    Projectile projectile,
    CosmicSurvivalEnemy enemy, {
    required bool killed,
  }) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorHit(projectile, enemy, killed: killed);
      return;
    }
    if (projectile.abilityFamily == 'mask') {
      // Contagion: whatever walks out of a Mask trap alive is a carrier.
      // Generation zero, because this body caught it from the trap itself.
      final infectSlot = projectile.sourceSlotIndex;
      if (mastery.enabled && infectSlot != null && !killed && !enemy.isDead) {
        _infectFromMaskTrap(infectSlot, enemy);
      }
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
      element: projectile.element,
      family: projectile.abilityFamily,
    );
    if (killed) resolveAbilityKill(projectile, enemy);
  }

  /// A Mask trap springing (once per contact echo); silent for the elements
  /// whose contact is ongoing rather than an event.
  void _soundMaskSpring(Projectile trap) {
    final cue = SoundCue.forMaskSpring(trap.element ?? '');
    if (cue != null) onSound?.call(cue);
  }

  /// Mask-family on-contact dispatcher. Returns true when the per-element
  /// behavior fully handles the hit (skip generic hitEffect dispatch).
  /// Returns false to fall through to the generic pipeline (Air knockback,
  /// Water splash, Mud slow, etc. already work as-is).
  bool _resolveMaskTrapHit(Projectile projectile, CosmicSurvivalEnemy enemy) {
    if (projectile.trapSpent) return true;
    if (_maskTrapVisuals.contact(projectile)) _soundMaskSpring(projectile);
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
        // A void consumes exactly one body, including armored enemies.
        projectile.trapSpent = true;
        if (!enemy.isDead) {
          _damageEnemy(
            enemy,
            enemy.hp,
            execute: true,
            sourceSlotIndex: projectile.sourceSlotIndex,
            masteryCastId: projectile.masteryCastId,
            masterySource: _projectileDamageSource(projectile),
          );
        }
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.4);
        return true;

      case 'Dark':
        // Yeet: the hole does not hit, hold or grind. Whatever touches it is
        // put out of the area, unharmed, to walk the whole way back.
        _ejectBodyFromField(
          enemy,
          hole: projectile.position,
          holeRadius: max(projectile.effectRadius, 40),
        );
        return true;

      case 'Crystal':
        if (projectile.hitEffect != AbilityEffectKind.split) return false;
        // Base contact damage has already been applied by the collision loop.
        projectile.trapSpent = true;
        _spawnMaskCrystalShards(projectile, enemy.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.3);
        return true;

      case 'Fire':
        if (projectile.hitEffect != AbilityEffectKind.burn) return true;
        projectile.trapSpent = true;
        _spawnMaskFirePool(projectile, projectile.position);
        projectile.abilityGrowthTimer = 1.0;
        projectile.life = min(projectile.life, 0.35);
        return true;

      case 'Lightning':
        // Area ticks handle both damage and growth, including lone enemies.
        return true;

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
    for (final shard in maskCrystalShards(parent, at, baseAngle)) {
      _appendCompanionProjectile(shard);
    }
  }

  // Mask+Plant: each cast feeds the existing vine instead of stacking
  // a new one. 100 casts → maximum vine. We repurpose effectStacks as
  // the cast counter and scale snare / effect / visual off it. The
  // first cast spawns a fresh vine; subsequent casts find that vine
  // (same source slot, mask+Plant, stationary) and pump its counter.
  // The growth itself is shared (mask_trap_placement.dart).

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
      applyMaskPlantVineFeed(seed, 1);
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
    final feeds = (prevFeeds + 1).clamp(1, kMaskPlantMaxFeeds);
    final newTendril = maskPlantFeedSproutsTendril(prevFeeds, feeds);
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
    applyMaskPlantVineFeed(existing, feeds);
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
    emitMaskPlantFeedBurst(
      at: vine.position,
      newTendril: newTendril,
      rng: _rng,
      poolSize: () => _vfx.length,
      emit: _emitVfxParticle,
    );
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
        comp.kinLavaPlateTimer = KinSupport.lavaPlateDuration(intel);
        break;
      case 'Ice':
        // Begin charge. Long base wind-up (4s) so the cast reads as
        // a heavy ult; Intelligence trims it slightly. Release radius
        // + slow duration scale on stats at fire time.
        //
        // A recast while a charge is still running leaves it running. The
        // charge is 3-4 s, and a well-bred Kin comes back in about 2 s, so
        // restarting it on every recast meant the frost never released.
        if (comp.kinIceChargeTimer > 0) break;
        final chargeTime = KinSupport.iceChargeDuration(intel);
        comp.kinIceChargeTimer = chargeTime;
        comp.kinIceChargeTotal = chargeTime;
        break;
      case 'Steam':
        // Boiler buff window — 10s base, scales with Intelligence. A recast
        // while the boiler is still lit only refreshes the window: emptying
        // the stacks on every cast meant a fast-recasting Kin never built
        // any pressure.
        final boilerLit = comp.kinSteamBoilerTimer > 0;
        comp.kinSteamBoilerTimer = KinSupport.steamBoilerDuration(intel);
        if (!boilerLit) {
          comp.kinSteamBoilerStacks = 0;
          comp.kinSteamStackCarry = 0;
          comp.kinSteamStackDecayTimer = KinSupport.steamDecayInterval;
        }
        break;
      case 'Lightning':
        // Tesla charge window — kin locked in place, ally autos chain.
        // 10s base, Intelligence stretches to ~14s. Per spec: long
        // sustained charge that telegraphs heavily to the player.
        comp.kinLightningChargeTimer = KinSupport.lightningChargeDuration(
          intel,
        );
        break;
      case 'Dust':
        // Field-placed cloud — first cast places one, subsequent casts
        // add more. Cap at 10 active clouds.
        _spawnKinDustCloud(slot, attackTarget, beauty, intel);
        break;
      case 'Mud':
        // Apply ship enchant — ship leaves mud trail while > 0.
        // Nerfed: 5s base (was 10s), Int stretches modestly.
        comp.kinMudShipEnchantTimer = KinSupport.mudEnchantDuration(intel);
        break;
      case 'Spirit':
        _spawnOrRefreshKinSpiritWisp(comp);
        break;
      case 'Earth':
        _spawnKinEarthWallArc(comp, fireAngle, beauty);
        break;
      case 'Dark':
        // Void veil — the orb hidden, companions untargetable. A fresh
        // cast draws the horde onto the ship again after a lift.
        comp.kinDarkCloakTimer = KinSupport.darkVeilDuration(intel);
        _kinDarkVeilLifted = false;
        break;
      case 'Blood':
        // Blood pact — damage→team heal share window.
        comp.kinBloodPactTimer = KinSupport.bloodPactDuration(intel);
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
    // Arc center is the orb's position; arc radius gives a stand-off
    // so enemies can't crowd the orb directly.
    for (final segment in KinSupport.earthWallArc(
      center: orb.position,
      facing: facingAngle,
      beauty: beauty,
      slot: comp.slotIndex,
    )) {
      _appendCompanionProjectile(segment);
    }
  }

  void _spawnKinDustCloud(
    int slot,
    Offset position,
    double beauty,
    double intelligence,
  ) {
    // Cap active clouds per kin to keep visuals readable.
    if (KinSupport.countDustClouds(companionProjectiles, slot) >=
        KinSupport.dustCloudCap) {
      return;
    }
    _appendCompanionProjectile(
      KinSupport.dustCloud(
        position,
        beauty: beauty,
        intelligence: intelligence,
        slot: slot,
      ),
    );
  }

  // ── Mystic environment overlay ─────────────────────────────────
  /// Push an environment entry for a freshly-cast Mystic ultimate.
  /// The render pass then tints the viewport + spawns ambient
  /// element-specific particles for the entry's lifetime.
  /// Seconds a Mystic waits between casts while developer tools are on.
  ///
  /// Mystic carries the longest cadence in the game on purpose, which is
  /// correct for play and miserable for tuning: judging whether an ember field
  /// reads as a hazard means seeing it dozens of times, not twice a run.
  static const double kDebugMysticCooldown = 5.0;

  /// Collapses a Mystic's cadence to [kDebugMysticCooldown] while the
  /// developer-tools switch is on, and leaves every other family alone.
  ///
  /// Gated on DebugSettingsService rather than kDebugMode deliberately: that
  /// constant is compile-time and false in profile, which is the build you
  /// actually want to feel this in. The switch is persisted, so it works in
  /// any build type — the same reasoning that file already documents.
  double _mysticCastCooldown(CosmicSurvivalCompanion comp, double normal) {
    if (!DebugSettingsService.toolsVisible) return normal;
    if (comp.member.family.toLowerCase() != 'mystic') return normal;
    return min(normal, kDebugMysticCooldown);
  }

  /// Lights a Fire Mystic's ember field. Count scales with the caster, per the
  /// brief: roughly twenty at low stats up to fifty at high.
  void _igniteMysticEmberField(CosmicSurvivalCompanion comp) {
    final beauty = _effectiveBeauty(comp.slotIndex);
    final intel = _effectiveIntelligence(comp.slotIndex);
    final scale = _hornStatScale(
      beauty * 0.5 + intel * 0.5,
      perPoint: 0.16,
      min: 0.62,
      max: 1.45,
    );
    // The surge buys embers first: a field is its density.
    final surge = _mysticWorldPower(comp.slotIndex);
    final target = (35 * scale * surge).round().clamp(20, 70);

    // Clear any field this caster already had, so a recall-and-redeploy
    // replaces its world rather than stacking a second one.
    _mysticEmbers.removeWhere((e) => e.ownerSlot == comp.slotIndex);

    final centre = orb.position;
    final spread = max(220.0, _arenaRadius * 0.85);
    for (var i = 0; i < target; i++) {
      if (_mysticEmbers.length >= _maxMysticEmbers) break;
      // Scattered across the whole arena, not around the caster — the field is
      // the map's new weather, not an aura the Mystic wears.
      final a = _rng.nextDouble() * 2 * pi;
      final r = spread * sqrt(_rng.nextDouble());
      final drift = _rng.nextDouble() * 2 * pi;
      _mysticEmbers.add(
        _MysticEmber(
          position: centre + Offset(cos(a), sin(a)) * r,
          // Slow enough to read as floating rather than as projectiles that
          // happen to be orange.
          velocity:
              Offset(cos(drift), sin(drift)) * (10 + _rng.nextDouble() * 16),
          ownerSlot: comp.slotIndex,
          seed: _rng.nextDouble() * 6.28,
        ),
      );
    }
  }

  /// Whether this companion's Mystic world is already out.
  bool isMysticFieldSpent(int slotIndex) =>
      _mysticSpentSlots.contains(slotIndex);

  /// How many embers a slot currently has burning — drives the slot readout so
  /// the disabled ability reads as "your world is out there" rather than as a
  /// broken button.
  int mysticEmberCount(int slotIndex) =>
      _mysticEmbers.where((e) => e.ownerSlot == slotIndex && e.fade > 0).length;

  /// How strong this slot's Mystic world currently is, 0 when there is none.
  /// Exposed so a test can assert the world outlives the cast and closes with
  /// its caster rather than on a timer.
  @visibleForTesting
  double mysticWorldStrength(int slotIndex) {
    var strongest = 0.0;
    for (final env in _mysticEnvironments) {
      if (env.ownerSlot != slotIndex) continue;
      final e = env.envelope;
      if (e > strongest) strongest = e;
    }
    return strongest;
  }

  /// Everything a slot's world currently has standing on the field — embers,
  /// revenants, vines, holes. Exposed so a test can assert that nothing a world
  /// placed outlives the world itself.
  @visibleForTesting
  int mysticWorldEntityCount(int slotIndex) =>
      mysticEmberCount(slotIndex) +
      mysticRevenantCount(slotIndex) +
      mysticVineCount(slotIndex) +
      _mysticMaws.where((m) => m.ownerSlot == slotIndex && m.fade > 0).length +
      _mysticPools.where((p) => p.ownerSlot == slotIndex && p.fade > 0).length +
      // Everything below was missing, which made the "nothing outlives its
      // world" assertion pass for six worlds by simply not looking at them.
      // The family was built one or two elements at a time over a long stretch
      // and this counter was never revisited — the exact failure an audit is
      // for.
      _mysticCrystals.where((c) => c.ownerSlot == slotIndex && !c.dead).length +
      _mysticStars.where((s) => s.ownerSlot == slotIndex && !s.dead).length +
      _mysticFissures
          .where((f) => f.ownerSlot == slotIndex && f.fade > 0)
          .length +
      _mysticMeteors.where((m) => m.ownerSlot == slotIndex).length +
      _mysticMaelstroms
          .where((m) => m.ownerSlot == slotIndex && m.fade > 0)
          .length +
      _mysticTornados
          .where((t) => t.ownerSlot == slotIndex && t.fade > 0)
          .length;

  /// How many poison patches this slot's world has laid down.
  @visibleForTesting
  int mysticPoolCount(int slotIndex) =>
      _mysticPools.where((p) => p.ownerSlot == slotIndex && p.fade > 0).length;

  /// What a slot's Mystic world is doing right now, for the pause readout.
  ///
  /// Returns null when that slot is not a Mystic, or has not cast yet. The
  /// count is whatever that world is MADE of — embers, revenants, vines,
  /// patches, or the hole itself — so the player can see their world rather
  /// than being told it exists.
  ({String element, String effect, String status, double strength})?
  mysticWorldReadout(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null || comp.member.family.toLowerCase() != 'mystic') {
      return null;
    }
    if (!isMysticFieldSpent(slotIndex)) return null;
    final element = comp.member.element;

    /// Seconds until this world's next beat, for the ones that run on a clock.
    String nextBeat() {
      final left = _mysticClock[slotIndex];
      if (left == null) return '';
      return ' · next in ${left.ceil()}s';
    }

    int inRangeOf(Offset centre, double radius) => enemies
        .where((e) => !e.isDead && (e.position - centre).distance <= radius)
        .length;

    // Two lines, not one. The old readout gave a bare count and a noun, which
    // produced things like "42 toward dawn" and "1 maw open" — a number the
    // player has no way to interpret next to a phrase that is not a sentence.
    // What they actually need is what this world DOES, and then how it is
    // going right now.
    final (effect, status) = switch (element) {
      'Fire' => (
        'Embers drift the whole arena and set light to whatever walks into them.',
        '${mysticEmberCount(slotIndex)} embers adrift',
      ),
      'Spirit' => (
        'Small enemies that die anywhere get back up on your side and hunt their own.',
        mysticRevenantCount(slotIndex) == 0
            ? 'nothing risen yet'
            : '${mysticRevenantCount(slotIndex)} revenants fighting for you',
      ),
      'Blood' => (
        "Every auto attack that lands — the party's and the ship's — drains life back into the orb.",
        'passive · nothing on the field to lose',
      ),
      'Dark' => (
        'A hole north of the orb drags enemies in and puts them off the map, to walk back from the edge.',
        _mysticMaws.any((m) => m.ownerSlot == slotIndex && m.fade > 0)
            ? 'the maw is open'
            : 'closing',
      ),
      'Plant' => (
        'Two vines flank the orb: one lashes whatever closes, one spits thorns at whatever does not.',
        '${mysticVineCount(slotIndex)} of 2 still standing',
      ),
      'Lightning' => (
        'The sky marks a spot, then strikes it. A boss caught by one is stunned for a second.',
        '${mysticStrikeCount(slotIndex)} bolts fallen${nextBeat()}',
      ),
      'Poison' => (
        'The ship leaves poison wherever it flies, so the shape of this world is whatever you draw.',
        '${mysticPoolCount(slotIndex)} patches still burning',
      ),
      'Mud' => (
        'Mud cakes everything on the field and it all takes more damage — a little on the small bodies, far more on the heavy ones.',
        (() {
          final heavy = enemies
              .where((e) => !e.isDead && _tierHeft(e.tier) >= 3)
              .length;
          final worst =
              ((_mysticWeightMultiplier(EnemyTier.colossus) - 1) * 100).round();
          return 'heaviest take +$worst% · $heavy big bodies out there';
        })(),
      ),
      'Earth' => (
        'The ground never settles, and every quake damages every enemy on the field and puts it down.',
        '${mysticStrikeCount(slotIndex)} quakes run${nextBeat()}',
      ),
      'Steam' => (
        'Pressure builds and vents, throwing every enemy outward from the orb. It buys room; it deals no damage.',
        '${mysticStrikeCount(slotIndex)} vents blown${nextBeat()}',
      ),
      'Ice' => (
        'Every enemy on the field is slowed for as long as this world holds, on top of any other slow.',
        '${enemies.where((e) => !e.isDead && e.blizzardMultiplier < 1.0).length} caught in the blizzard',
      ),
      'Crystal' => (
        'The dead crystallise. The ship draws the shards in, and each one feeds your surge meter.',
        '${mysticCrystalCount(slotIndex)} shards waiting to be collected',
      ),
      'Light' => (
        'A star is rising outside the arena. When it breaks, the orb, the ship and every alchemon go back to full.',
        (() {
          for (final star in _mysticStars) {
            if (star.ownerSlot != slotIndex) continue;
            if (star.flare > 0) return 'dawn breaking';
            final left = (1.0 - star.charge) * star.period;
            return 'dawn in ${left.ceil()}s';
          }
          return 'dark';
        })(),
      ),
      'Dust' => (
        "The air is thick with grit. Enemy shooters choke on it and their rounds go off in their own faces.",
        '$_mysticMisfires rounds turned back so far',
      ),
      'Lava' => (
        'Cracks split the floor. Anything as heavy as a BOSS crossing one brings meteors down on that ground.',
        '${_mysticFissures.where((f) => f.ownerSlot == slotIndex && f.fade > 0).length} cracks glowing',
      ),
      'Water' => (
        'A whirlpool turns out in the ring. Everything it catches stops advancing and is carried round the eye.',
        (() {
          for (final storm in _mysticMaelstroms) {
            if (storm.ownerSlot != slotIndex) continue;
            return '${inRangeOf(storm.centre, storm.radius)} held in the water';
          }
          return 'still';
        })(),
      ),
      'Air' => (
        'A tornado walks a circuit around the arena, lifting whatever it passes over and grinding it down.',
        (() {
          for (final twister in _mysticTornados) {
            if (twister.ownerSlot != slotIndex) continue;
            return '${inRangeOf(twister.position, twister.funnelRadius)} caught in the funnel';
          }
          return 'still';
        })(),
      ),
      _ => ('This world holds while its Mystic stands.', ''),
    };

    return (
      element: element,
      effect: effect,
      status: status,
      strength: mysticWorldStrength(slotIndex),
    );
  }

  /// How far the most recently laid patch has spread, and the oldest. Exposed
  /// so a test can assert a spill arrives unfinished and finishes.
  @visibleForTesting
  double mysticNewestPoolSpread(int slotIndex) {
    for (final pool in _mysticPools.reversed) {
      if (pool.ownerSlot == slotIndex && pool.fade > 0) return pool.spread;
    }
    return 0;
  }

  @visibleForTesting
  double mysticOldestPoolSpread(int slotIndex) {
    for (final pool in _mysticPools) {
      if (pool.ownerSlot == slotIndex && pool.fade > 0) return pool.spread;
    }
    return 0;
  }

  @visibleForTesting
  int mysticCrystalCount(int slotIndex) =>
      _mysticCrystals.where((c) => c.ownerSlot == slotIndex && !c.dead).length;

  @visibleForTesting
  double mysticStarCharge(int slotIndex) {
    for (final star in _mysticStars) {
      if (star.ownerSlot == slotIndex) return star.charge;
    }
    return -1;
  }

  @visibleForTesting
  double? mysticStarPeriod(int slotIndex) {
    for (final star in _mysticStars) {
      if (star.ownerSlot == slotIndex) return star.period;
    }
    return null;
  }

  /// Forces the star to the brink, so a test can watch dawn break without
  /// simulating the better part of a minute.
  @visibleForTesting
  void debugRushMysticDawn(int slotIndex) {
    for (final star in _mysticStars) {
      if (star.ownerSlot == slotIndex) star.charge = 0.999;
    }
  }

  /// Spots the sky is currently gathering over. Exposed so a test can assert
  /// the storm telegraphs before it lands rather than simply appearing.
  @visibleForTesting
  int mysticStormChargeCount(int slotIndex) =>
      _mysticCharges.where((c) => c.ownerSlot == slotIndex).length;

  @visibleForTesting
  Offset? mysticStormChargeAt(int slotIndex) {
    for (final c in _mysticCharges) {
      if (c.ownerSlot == slotIndex) return c.at;
    }
    return null;
  }

  /// Current screen-shake trauma, 0 when still. Exposed so a test can assert a
  /// quake actually moves the view and then settles — shake is invisible to
  /// every other kind of assertion.
  @visibleForTesting
  double get screenShakeTrauma => _shakeTrauma;

  /// Distance from [from] to the closest piece of ground cover. Exposed so a
  /// test can assert the scenery stays out at the rim.
  @visibleForTesting
  double mysticFloraNearestTo(Offset from) {
    var nearest = double.infinity;
    for (final f in _mysticFlora) {
      final d = (f.position - from).distance;
      if (d < nearest) nearest = d;
    }
    return nearest;
  }

  /// How much ground cover this slot's world currently has standing.
  @visibleForTesting
  int mysticFloraCount(int slotIndex) =>
      _mysticFlora.where((f) => f.ownerSlot == slotIndex && !f.dead).length;

  /// How many bolts a Lightning world has thrown this run, and quakes an Earth
  /// world has shaken. Counted so a test can assert the clock actually runs and
  /// stops with its caster.
  @visibleForTesting
  int mysticStrikeCount(int slotIndex) => _mysticStrikes[slotIndex] ?? 0;

  @visibleForTesting
  int mysticRevenantCount(int slotIndex) =>
      _mysticRevenants.where((r) => r.ownerSlot == slotIndex && !r.dead).length;

  @visibleForTesting
  int mysticVineCount(int slotIndex) =>
      _mysticVines.where((v) => v.ownerSlot == slotIndex && v.fade > 0).length;

  @visibleForTesting
  int mysticVineLashCount(int slotIndex) => _mysticVines
      .where((v) => v.ownerSlot == slotIndex && v.fade > 0 && v.lashes)
      .length;

  @visibleForTesting
  Offset? mysticMawPosition(int slotIndex) {
    for (final maw in _mysticMaws) {
      if (maw.ownerSlot == slotIndex && maw.fade > 0) return maw.position;
    }
    return null;
  }

  @visibleForTesting
  List<Offset> get debugMaskSpiritWispPositions =>
      _spiritWisps.where((w) => !w.dead).map((w) => w.position).toList();

  /// Kills a body the way the game does, so a test can watch what the death
  /// triggers rather than reaching into the rules that trigger on it.
  @visibleForTesting
  void debugKillEnemy(CosmicSurvivalEnemy enemy) => _killEnemy(enemy);

  /// Re-files [enemies] into the spatial grid, so bodies a test placed by hand
  /// are found by area effects without running a frame.
  @visibleForTesting
  void debugRebuildEnemyGrid() => _rebuildEnemySpatialGrid();

  /// Whether this slot's Mystic world is standing.
  bool debugMysticWorldLit(int slotIndex) =>
      _mysticSpentSlots.contains(slotIndex);

  /// Lengths of the Kin laser beams currently drawn, so a test can see
  /// Longline working without reaching into the render list.
  List<double> get debugKinLaserLengths => [
    for (final b in _kinLaserBeams) (b.end - b.origin).distance,
  ];

  /// The Wing beams in the air: whose each one is, how many times it has
  /// refracted, where it last landed, how hard it ticks, whether it is the
  /// orb's or the ship's co-beam rather than the Wing's own, and its focus:
  /// the body it is held on, where that stood, and its last tick's heat.
  @visibleForTesting
  List<
    ({
      int slot,
      int refractions,
      Offset? end,
      double damagePerTick,
      bool coBeam,
      Object? heldOn,
      Offset? focus,
      double heat,
    })
  >
  get debugWingBeams => [
    for (final b in _activeWingBeams)
      (
        slot: b.sourceSlotIndex,
        refractions: b.refractionsDone,
        end: b.drawEnd,
        damagePerTick: b.descriptor.damagePerTick,
        coBeam: b.anchorToOrb || b.anchorToShip,
        heldOn: b.heat.on,
        focus: b.focusAt,
        heat: b.heat.current,
      ),
  ];

  /// Opens [beam] for the Wing in [slotIndex] the way its special does.
  @visibleForTesting
  void debugCastWingBeam(int slotIndex, WingBeamEffect beam) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return;
    _activateWingBeamEffects(
      [beam],
      sourceSlotIndex: slotIndex,
      origin: comp.position,
      angle: comp.angle,
    );
  }

  /// The range multiplier mastery is applying to this slot.
  double debugAttackRangeMultiplier(int slotIndex) =>
      _masteryAttackRangeMultiplier(slotIndex);

  /// Kills [enemy] as an auto-attack from [slotIndex] would, so tests can
  /// exercise the kill hooks without waiting on a dart to land.
  void debugKillByDart(int slotIndex, CosmicSurvivalEnemy enemy) => _killEnemy(
    enemy,
    sourceSlotIndex: slotIndex,
    masterySource: MasteryDamageSource.basic,
  );

  /// Seeds a Contagion infection as a trap contact would.
  void debugInfect(int slotIndex, CosmicSurvivalEnemy enemy) =>
      _infectFromMaskTrap(slotIndex, enemy);

  /// Puts damage through the orb's real intake, Bastion's split included.
  void debugDamageOrb(double amount) => _damageOrb(amount);

  /// The two halves of the Blood tithe's gate, as a test can drive them:
  /// damage that came from somebody's basic attack, and damage that did not.
  /// [sourceSlotIndex] makes it that companion's attack.
  @visibleForTesting
  void debugAutoAttackDamage(
    CosmicSurvivalEnemy enemy,
    double damage, {
    int? sourceSlotIndex,
  }) => _damageEnemy(
    enemy,
    damage,
    autoAttack: true,
    sourceSlotIndex: sourceSlotIndex,
  );

  @visibleForTesting
  void debugAbilityDamage(
    CosmicSurvivalEnemy enemy,
    double damage, {
    int? sourceSlotIndex,
  }) => _damageEnemy(enemy, damage, sourceSlotIndex: sourceSlotIndex);

  /// Hands [slotIndex] the support half of a special as a cast would: its
  /// shield, heals and blessing.
  @visibleForTesting
  void debugApplySpecialSupport(int slotIndex, CosmicSpecialResult result) {
    final comp = activeCompanions[slotIndex];
    if (comp != null) _applyCompanionSpecialSupportEffects(comp, result);
  }

  /// Damage the way the SHIP deals it.
  @visibleForTesting
  void debugShipAttackDamage(CosmicSurvivalEnemy enemy, double damage) {
    _damageEnemy(enemy, damage, autoAttack: true, fromShip: true);
  }

  /// The ship's hull and the hit it would land now, after the wave's scaling
  /// and its picks.
  @visibleForTesting
  ({double hull, double hit}) get debugShipPower {
    _syncShipHull();
    return (
      hull: ship.maxHp,
      hit: 10.0 * powerUps.shipDamageMultiplier * _shipWaveDamage,
    );
  }

  /// Seconds a downed ship waits to be rebuilt.
  @visibleForTesting
  double get debugShipRespawnDelay => _shipRespawnDelay;

  /// How far this slot's embers reach from [from] — the distance to the
  /// furthest one. Exposed so a test can assert the field covers the arena
  /// rather than orbiting its caster.
  @visibleForTesting
  double mysticEmberSpreadFrom(int slotIndex, Offset from) {
    var furthest = 0.0;
    for (final ember in _mysticEmbers) {
      if (ember.ownerSlot != slotIndex || ember.fade <= 0) continue;
      final d = (ember.position - from).distance;
      if (d > furthest) furthest = d;
    }
    return furthest;
  }

  /// Ends a slot's field and frees its cast. Called when the Mystic is recalled
  /// or dies; the embers fade rather than blinking out, so losing the world is
  /// something the player watches happen.
  void _extinguishMysticField(int slotIndex) {
    _mysticSpentSlots.remove(slotIndex);
    for (final ember in _mysticEmbers) {
      if (ember.ownerSlot == slotIndex) ember.fade = min(ember.fade, 0.999);
    }
    // Every world goes out the same way, and none of them blink: a world
    // ending is the consequence the player is meant to watch.
    for (final r in _mysticRevenants) {
      if (r.ownerSlot == slotIndex) r.fade = min(r.fade, 0.999);
    }
    for (final v in _mysticVines) {
      if (v.ownerSlot == slotIndex) v.fade = min(v.fade, 0.999);
    }
    for (final m in _mysticMaws) {
      if (m.ownerSlot == slotIndex) m.fade = min(m.fade, 0.999);
    }
    for (final pool in _mysticPools) {
      if (pool.ownerSlot == slotIndex) pool.fade = min(pool.fade, 0.999);
    }
    // Ground cover withers on its own schedule; stopping the seeding is what
    // ends it, so the map goes back to normal over a few seconds rather than
    // between two frames.
    for (final f in _mysticFlora) {
      if (f.ownerSlot == slotIndex) {
        f.age = max(f.age, f.life * 0.80);
      }
    }
    _mysticCharges.removeWhere((c) => c.ownerSlot == slotIndex);
    for (final shard in _mysticCrystals) {
      if (shard.ownerSlot == slotIndex) shard.fade = min(shard.fade, 0.999);
    }
    for (final star in _mysticStars) {
      if (star.ownerSlot == slotIndex) star.fade = min(star.fade, 0.999);
    }
    for (final fissure in _mysticFissures) {
      if (fissure.ownerSlot == slotIndex) {
        fissure.fade = min(fissure.fade, 0.999);
      }
    }
    for (final storm in _mysticMaelstroms) {
      if (storm.ownerSlot == slotIndex) storm.fade = min(storm.fade, 0.999);
    }
    for (final twister in _mysticTornados) {
      if (twister.ownerSlot == slotIndex) {
        twister.fade = min(twister.fade, 0.999);
      }
    }
    // A blizzard has to LIFT. It writes to every enemy on the field, so a
    // world that ended without thawing would leave the arena slowed for the
    // rest of the run by a Mystic that is no longer there.
    _thawMysticBlizzard();
    _mysticClock.remove(slotIndex);
    _mysticQuakeCued.remove(slotIndex);
    _mysticPoisonLastDrop.remove(slotIndex);
  }

  /// How many times each slot has lit a world this run. A world is meant to be
  /// lit ONCE per deployment; developer tools re-arming the cast used to tear
  /// it down and rebuild it every five seconds, so this is counted rather than
  /// assumed.
  final Map<int, int> _mysticWorldIgnitions = {};

  @visibleForTesting
  int mysticWorldIgnitions(int slotIndex) =>
      _mysticWorldIgnitions[slotIndex] ?? 0;

  @visibleForTesting
  double? mysticMawRadius(int slotIndex) {
    for (final maw in _mysticMaws) {
      if (maw.ownerSlot == slotIndex && maw.fade > 0) return maw.radius;
    }
    return null;
  }

  /// Where a slot's two vines are rooted, in the order they were grown.
  @visibleForTesting
  List<Offset> mysticVineRoots(int slotIndex) => [
    for (final v in _mysticVines)
      if (v.ownerSlot == slotIndex && v.fade > 0) v.root,
  ];

  /// How far a slot's world surge has deepened it — 1.0 with no picks, 1.75 at
  /// three. Every world reads the same number and spends it on whatever that
  /// world is made of, so a surge is worth about the same wherever it lands.
  double _mysticWorldPower(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return 1.0;
    var power = powerUps.mysticWorldPower(slotIndex, comp.member.element);
    // Quickening divides the beat the same way the surge does, so a world
    // cannot be driven to a continuous beam however the two stack: the rate
    // is read back out of the clamped interval rather than applied raw.
    if (_isMasteryMystic(slotIndex)) {
      final authored = 4.0;
      final driven = mysticWorldInterval(
        hasNode: (id) => mastery.hasNode(slotIndex, id),
        authoredInterval: authored,
      );
      if (driven > 0) power *= authored / driven;
    }
    return power;
  }

  /// How hard this Mystic's damage world lands at its SPECIAL — the world's
  /// answer to the recasts every other family's SPECIAL buys
  /// ([mysticWorldIntensity]). Damage only: the surge above owns counts and
  /// sizes, and [_mysticWorldTempo] how fast and how far the world works.
  double _mysticWorldIntensity(CosmicSurvivalCompanion caster) =>
      mysticWorldIntensity(
        element: caster.member.element,
        abilityAtk: caster.abilityAtk,
      );

  /// How much faster (and, for a world that covers ground, wider) this
  /// Mystic's damage world works at its SPECIAL — 1 at P50
  /// ([mysticWorldTempo]).
  double _mysticWorldTempo(CosmicSurvivalCompanion caster) =>
      mysticWorldTempo(
        element: caster.member.element,
        abilityAtk: caster.abilityAtk,
      );

  /// Seconds between a clocked world's beats (the storm's strikes, the
  /// quake, the vents) for this caster: the authored beat, quickened by the
  /// world surge and by the caster's SPECIAL ([_mysticWorldTempo]). Divided
  /// rather than subtracted, so nothing can drive a beat to zero.
  ///
  /// The surge, mastery quickening and SPECIAL tempo multiply, and at the top
  /// of all three a storm struck about every 0.34 s, a continuous beam. Their
  /// product is held to [kMysticBeatQuickeningCap]: SPECIAL alone tops out at
  /// 2.43, so the cap only trims a fully surged, mastered world.
  double _mysticBeat(int slotIndex, CosmicSurvivalCompanion caster,
          double authored) =>
      authored /
      min(
        kMysticBeatQuickeningCap,
        _mysticWorldPower(slotIndex) * _mysticWorldTempo(caster),
      );

  /// Most a clocked world's beat can be quickened, all sources together.
  static const double kMysticBeatQuickeningCap = 3.0;

  /// The beat [slotIndex]'s clocked world runs on right now, or null when it
  /// has none.
  @visibleForTesting
  double? mysticWorldBeat(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return null;
    return switch (comp.member.element) {
      'Lightning' => _mysticBeat(slotIndex, comp, kMysticStrikeInterval),
      'Earth' => _mysticBeat(slotIndex, comp, kMysticQuakeInterval),
      'Steam' => _mysticBeat(slotIndex, comp, kMysticVentInterval),
      _ => null,
    };
  }

  // == Mystic mastery (phase 5) ============================================

  /// Per-slot Mystic state, created on demand and dropped on a run reset.
  final Map<int, MysticMasteryState> _mysticMastery = {};

  MysticMasteryState _mysticStateFor(int slotIndex) =>
      _mysticMastery.putIfAbsent(slotIndex, MysticMasteryState.new);

  /// Read-only view of a Mystic's run state — what its world has mended.
  MysticMasteryState? mysticMasteryFor(int slotIndex) =>
      _mysticMastery[slotIndex];

  bool _isMasteryMystic(int slotIndex) {
    if (!mastery.enabled) return false;
    final equipped = mastery.equippedFor(slotIndex);
    return equipped != null && equipped.family == CreatureFamily.mystic;
  }

  /// Weight of Heaven: how much harder everything a world does lands.
  double _mysticWorldDamageMultiplier(int slotIndex) =>
      _isMasteryMystic(slotIndex)
      ? mysticWorldPower(hasNode: (id) => mastery.hasNode(slotIndex, id))
      : 1.0;

  /// The slot of a standing world whose Firmament covers [pos], if any.
  int? _firmamentCovering(Offset pos) {
    if (_mysticSpentSlots.isEmpty || !mastery.enabled) return null;
    for (final slot in _mysticSpentSlots) {
      if (!_isMasteryMystic(slot)) continue;
      if (!mastery.hasNode(slot, MysticNodes.nativeAir)) continue;
      final caster = activeCompanions[slot];
      if (caster == null || caster.isDead) continue;
      if ((caster.position - pos).distance <= MysticTuning.insideRadius) {
        return slot;
      }
    }
    return null;
  }

  /// Native Air: what an ally standing in the world takes instead.
  double _firmamentMitigation(Offset pos) {
    final slot = _firmamentCovering(pos);
    if (slot == null) return 1.0;
    return mysticFirmament(
      hasNode: (id) => mastery.hasNode(slot, id),
    ).mitigation;
  }

  /// Home Ground: what an ally standing in the world deals instead.
  double _firmamentPower(Offset pos) {
    final slot = _firmamentCovering(pos);
    if (slot == null) return 1.0;
    return mysticFirmament(hasNode: (id) => mastery.hasNode(slot, id)).power;
  }

  /// Home Ground on one hit from [slot]: "they deal 15% more while they
  /// stand in it", whatever they deal it with, on a body or a boss. It was
  /// read for auto-attacks on bodies only (2026-10-21 mastery sweep). A lit
  /// world's own output is Weight of Heaven's, so the world is not lifted
  /// by the shelter it is.
  double _homeGroundPower(int slot, {required bool autoAttack}) {
    if (_mysticSpentSlots.isEmpty) return 1.0;
    if (!autoAttack && _mysticSpentSlots.contains(slot)) return 1.0;
    final shooter = activeCompanions[slot];
    if (shooter == null) return 1.0;
    return _firmamentPower(shooter.position);
  }

  /// Sanctum: the Mystic whose world lends its element to an attack from
  /// [shooterSlot], or null. Only an ally's — the Mystic's own attacks carry
  /// its element already — and only from inside the world.
  int? _sanctumFor(int shooterSlot) {
    if (_mysticSpentSlots.isEmpty || !mastery.enabled) return null;
    final shooter = activeCompanions[shooterSlot];
    if (shooter == null) return null;
    final slot = _firmamentCovering(shooter.position);
    if (slot == null || slot == shooterSlot) return null;
    if (!mysticFirmament(
      hasNode: (id) => mastery.hasNode(slot, id),
    ).lendsElement) {
      return null;
    }
    return slot;
  }

  /// Sanctum's payload on what an ally's attack just struck. The world's
  /// element, through the one payload table every node shares, so a Fire
  /// world scorches what its guests shoot and an Ice one chills it. The node
  /// was computed and read nowhere, so it did nothing (2026-10-20 audit).
  void _applySanctum(
    int mysticSlot, {
    CosmicSurvivalEnemy? enemy,
    SurvivalBoss? boss,
    required double dealt,
  }) {
    triggerElementalPayload(
      slotIndex: mysticSlot,
      effectId: MysticNodes.sanctum,
      enemy: enemy,
      boss: boss,
      strength: MysticTuning.sanctumStrength,
      triggeringDamage: dealt,
      procCooldown: MysticTuning.sanctumCooldown,
    );
  }

  /// Tended: the world mends whoever is standing in it.
  void _updateMysticMastery(double dt) {
    if (!mastery.enabled || _mysticSpentSlots.isEmpty) return;
    for (final slot in _mysticSpentSlots) {
      if (!_isMasteryMystic(slot)) continue;
      final firmament = mysticFirmament(
        hasNode: (id) => mastery.hasNode(slot, id),
      );
      if (!firmament.mends) continue;
      final caster = activeCompanions[slot];
      if (caster == null || caster.isDead) continue;
      if (!_mysticStateFor(slot).takeTendedTick(dt)) continue;

      for (final ally in activeCompanions.values) {
        if (ally.isDead) continue;
        if ((ally.position - caster.position).distance >
            MysticTuning.insideRadius) {
          continue;
        }
        final mend = ally.maxHp * MysticTuning.tendedHealPerSecond;
        final before = ally.currentHp;
        ally.currentHp = min(ally.maxHp, ally.currentHp + mend.round());
        _mysticStateFor(slot).healedInside += ally.currentHp - before;
      }
      if (!ship.isDead &&
          (ship.position - caster.position).distance <=
              MysticTuning.insideRadius) {
        ship.currentHp = min(
          ship.maxHp,
          ship.currentHp + ship.maxHp * MysticTuning.tendedHealPerSecond,
        );
      }
    }
  }

  /// Lights whichever world this Mystic makes.
  void _igniteMysticWorld(CosmicSurvivalCompanion comp, int slotIndex) {
    _mysticWorldIgnitions[slotIndex] =
        (_mysticWorldIgnitions[slotIndex] ?? 0) + 1;
    // First Light: the clocks below are set to a full interval, so a world
    // normally spends its first turn doing nothing at all. This makes the sky
    // change and act in the same moment.
    final actsNow =
        _isMasteryMystic(slotIndex) &&
        mysticActsOnIgnition(hasNode: (id) => mastery.hasNode(slotIndex, id));
    switch (comp.member.element) {
      case 'Fire':
        _igniteMysticEmberField(comp);
      case 'Spirit':
        // Nothing is placed: the world is a RULE, and the fight supplies the
        // bodies. Clearing first means a redeploy starts from an empty host.
        _mysticRevenants.removeWhere((r) => r.ownerSlot == slotIndex);
      case 'Blood':
        // Also a rule — see _payMysticBloodTithe. Nothing to place.
        break;
      case 'Dark':
        _openMysticMaw(comp);
      case 'Plant':
        _growMysticGrove(comp);
      case 'Lightning':
        // The storm's first bolt comes on the clock like every other, so the
        // cast is the sky changing rather than a bolt being thrown.
        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticStrikeInterval);
      case 'Earth':
        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticQuakeInterval);
        _mysticQuakeCued.remove(slotIndex);
      case 'Poison':
        _mysticPools.removeWhere((p) => p.ownerSlot == slotIndex);
        _mysticPoisonLastDrop[slotIndex] = ship.position;
      case 'Mud':
        // A rule on the ship's guns; nothing to place.
        break;
      case 'Ice':
      case 'Crystal':
      case 'Dust':
        // Rules on the whole field; nothing to place.
        break;
      case 'Steam':
        _mysticClock[slotIndex] = actsNow
            ? 0.0
            : _mysticBeat(slotIndex, comp, kMysticVentInterval);
      case 'Lava':
        _openMysticFissures(comp);
      case 'Water':
        _openMysticMaelstrom(comp);
      case 'Air':
        _raiseMysticTornado(comp);
      case 'Light':
        _raiseMysticStar(comp);
    }
  }

  /// Seconds between a Lightning world's strikes, and between an Earth world's
  /// quakes, at P50. These are the weather's rhythm, and a player has to be
  /// able to count on it to play around it, so for a given creature the beat
  /// holds steady; a stronger creature's world beats faster
  /// ([_mysticBeat]). A strike is a single bolt and a quake floors the whole
  /// arena, so how often they come is what sets how much each world is worth.
  static const double kMysticStrikeInterval = 2.2;
  static const double kMysticQuakeInterval = 33.0;

  /// The slot hosting a live world of [element], or null. Deliberately checks
  /// the caster rather than the leftover entities: a world belongs to a Mystic
  /// that is alive and standing in it, and the entities are only its evidence.
  int? _activeMysticWorldSlot(String element) {
    for (final entry in activeCompanions.entries) {
      final comp = entry.value;
      if (comp.isDead) continue;
      if (comp.member.family.toLowerCase() != 'mystic') continue;
      if (comp.member.element != element) continue;
      if (!_mysticSpentSlots.contains(entry.key)) continue;
      return entry.key;
    }
    return null;
  }

  // ── SPIRIT: the dead change sides ───────────────────────────────────────

  /// Called from [_killEnemy]. A small body that dies inside a Spirit world
  /// gets back up on our side.
  ///
  /// Gated to the two smallest tiers on purpose: the mechanic should read as
  /// "the chaff turns", not as "every brute you kill becomes a second brute",
  /// which would make the world win fights by itself the moment it came up.
  void _raiseMysticRevenant(CosmicSurvivalEnemy enemy) {
    if (enemy.tier != EnemyTier.wisp && enemy.tier != EnemyTier.drone) return;
    final slot = _activeMysticWorldSlot('Spirit');
    if (slot == null) return;
    final owner = activeCompanions[slot];
    if (owner == null || owner.isDead) return;

    final intel = _effectiveIntelligence(slot);
    final surge = _mysticWorldPower(slot);
    // Half the host at the low anchor, the whole host at perfect. (The old
    // hornStatScale(min 0.5, max 1.0) was already 1.0 at stat 3, so every
    // fielded Spirit had the full host from the first wave — M6.)
    // A stronger Mystic raises a bigger host ([mysticWorldTempo]), up to
    // twice the authored one.
    final cap =
        (_maxMysticRevenants *
                (0.5 + 0.5 * mysticWorldHookProgress(intel)) *
                surge *
                _mysticWorldTempo(owner))
            .round()
            .clamp(5, _maxMysticRevenants * 2);
    var standing = 0;
    for (final r in _mysticRevenants) {
      if (r.ownerSlot == slot && !r.dead) standing++;
    }
    if (standing >= cap) return;

    _mysticRevenants.add(
      _MysticRevenant(
        position: enemy.position,
        ownerSlot: slot,
        damage: max(
          4.0,
          owner.abilityAtk * 0.85 * surge * _mysticWorldIntensity(owner),
        ),
        radius: max(9.0, enemy.radius * 0.82),
        // A shade is lighter than the body was.
        speed: max(70.0, enemy.speed * 1.45),
        seed: _rng.nextDouble() * 6.28,
        life:
            (9.0 +
                _hornStatScale(intel, perPoint: 0.16, min: 0.8, max: 1.9) *
                    4.0) *
            surge,
      ),
    );
    _spawnHitSpark(enemy.position, const Color(0xFFEAF2FF));
  }

  void _updateMysticRevenants(double dt) {
    if (_mysticRevenants.isEmpty) return;
    // Indexed against the count at entry, because a revenant's strike can kill
    // — and a kill inside a Spirit world raises another revenant, which
    // appends to the very list being walked. The new one waits for next frame.
    final standingCount = _mysticRevenants.length;
    for (var ri = 0; ri < standingCount; ri++) {
      final r = _mysticRevenants[ri];
      final owner = activeCompanions[r.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        r.fade = max(0.0, r.fade - dt * 0.8);
        if (r.fade <= 0) continue;
      }
      if (r.rise < 1) r.rise = min(1.0, r.rise + dt * 2.6);
      r.life -= dt;
      if (r.strikeCooldown > 0) {
        r.strikeCooldown = max(0.0, r.strikeCooldown - dt);
      }

      // Hunt. A revenant fights whatever it used to stand beside, and ignores
      // the orb entirely — it is ours now.
      final prey = _nearestEnemyTo(r.position, 620);
      final goal = prey?.position ?? orb.position;
      final delta = goal - r.position;
      final dist = delta.distance;
      if (dist > 0.5) {
        final norm = delta / dist;
        // Eases in so a fresh revenant drifts up out of the body rather than
        // snapping to a heading the instant it rises.
        final ease = 0.35 + 0.65 * r.rise;
        r.velocity = norm * (r.speed * ease);
        r.position += r.velocity * dt;
      }

      if (prey == null || !standing || r.strikeCooldown > 0) continue;
      if (_withinRange(r.position, prey.position, prey.radius + r.radius + 4)) {
        _damageEnemy(prey, r.damage, sourceSlotIndex: r.ownerSlot);
        r.strikeCooldown = 0.45 / _mysticWorldTempo(owner);
        _spawnHitSpark(prey.position, const Color(0xFFDCE8FF));
      }
    }
    _mysticRevenants.removeWhere((r) => r.dead);
  }

  // ── BLOOD: the tithe ────────────────────────────────────────────────────

  double _mysticBloodMoteTimer = 0;
  double _mysticBloodCarry = 0;

  /// Every auto attack that lands inside a Blood world feeds the orb.
  ///
  /// Deliberately auto attacks ONLY — including the ship's. A Blood world
  /// should reward the fire the player never stops putting out, not the
  /// burst abilities they were going to press anyway; tying it to everything
  /// would make the strongest play "stack cooldowns" instead of "keep
  /// shooting", and would scale with whoever else happens to be in the party.
  void _payMysticBloodTithe(double dealt, Offset where) {
    if (dealt <= 0) return;
    final slot = _activeMysticWorldSlot('Blood');
    if (slot == null) return;
    final comp = activeCompanions[slot];
    if (comp == null || comp.isDead) return;

    final share =
        0.10 *
        _mysticWorldPower(slot) *
        _hornStatScale(
          _effectiveStrength(slot) * 0.5 + _effectiveBeauty(slot) * 0.5,
          perPoint: 0.14,
          min: 0.75,
          max: 1.85,
        );
    final drawn = dealt * share;
    _healOrb(drawn * 0.72, sourceSlot: slot);
    // The Mystic keeps a cut. It is the one standing in the blood.
    //
    // Companion HP is an integer, and a tithe off one auto attack is a
    // fraction of a point, so paying it directly would round to nothing every
    // time and the Mystic would never heal at all. Carried instead, and spent
    // whole.
    _mysticBloodCarry += drawn * 0.28;
    if (_mysticBloodCarry >= 1 && comp.currentHp < comp.maxHp) {
      final points = _mysticBloodCarry.floor();
      _mysticBloodCarry -= points;
      final before = comp.currentHp;
      comp.currentHp = min(comp.maxHp, comp.currentHp + points);
      _recordHeal(
        (comp.currentHp - before).toDouble(),
        target: 0,
        sourceSlot: slot,
      );
    }

    // A mote every so often rather than one per hit — at full auto-attack
    // rate that would be dozens a second, and the ambient pool is shared.
    // The timer is drained by the per-frame tick, not from here.
    if (_mysticBloodMoteTimer <= 0 && _vfx.length < 140) {
      _mysticBloodMoteTimer = 0.10;
      final toOrb = orb.position - where;
      final d = toOrb.distance;
      final norm = d > 1 ? toOrb / d : const Offset(0, -1);
      _vfx.add(
        _VfxParticle(
          x: where.dx,
          y: where.dy,
          vx: norm.dx * 190,
          vy: norm.dy * 190,
          size: 1.6 + _rng.nextDouble() * 1.2,
          life: 0.45 + _rng.nextDouble() * 0.25,
          color: const Color(0xFFC8254A),
        ),
      );
    }
  }

  double _mysticMireSplatTimer = 0;
  double _mysticMireDripTimer = 0;

  /// Mud thrown off a heavy body as it takes a hit.
  ///
  /// The weight is a number on a damage roll and numbers are invisible, so this
  /// is the moment it becomes legible: the bigger the thing, the more comes off
  /// it. Throttled hard — a Mud world applies to every hit on the field.
  void _splatterMire(Offset at) {
    if (_mysticMireSplatTimer > 0) return;
    if (_vfx.length >= 138) return;
    _mysticMireSplatTimer = 0.07;
    final mud = elementColor('Mud');
    final dark = Color.lerp(mud, const Color(0xFF2A1608), 0.55)!;
    for (var i = 0; i < 7; i++) {
      if (_vfx.length >= 150) break;
      final a = _rng.nextDouble() * 2 * pi;
      final spd = 40 + _rng.nextDouble() * 110;
      _vfx.add(
        _VfxParticle(
          x: at.dx,
          y: at.dy,
          vx: cos(a) * spd,
          vy: sin(a) * spd - 20,
          size: 1.8 + _rng.nextDouble() * 2.4,
          life: 0.35 + _rng.nextDouble() * 0.35,
          color: i.isEven ? mud : dark,
        ),
      );
    }
  }

  /// Mud sliding off whatever the world is caking.
  ///
  /// The splatter marks a hit; this marks the STATE, so the heavy bodies keep
  /// looking caked whether or not anything is shooting them. Weighted toward
  /// the big ones, because that is where the world's effect actually lands.
  void _dripMire(double dt) {
    final slot = _activeMysticWorldSlot('Mud');
    if (slot == null) return;
    final comp = activeCompanions[slot];
    if (comp == null || comp.isDead) return;
    _mysticMireDripTimer -= dt;
    if (_mysticMireDripTimer > 0) return;
    _mysticMireDripTimer = 0.09;
    if (_vfx.length >= 132) return;

    final mud = elementColor('Mud');
    final dark = Color.lerp(mud, const Color(0xFF2A1608), 0.5)!;
    var dripped = 0;
    // Heaviest first: the mud is on everything, but a colossus is wearing most
    // of it and a wisp is barely marked.
    final caking = [
      for (final e in enemies)
        if (!e.isDead && _isOnScreen(e.position, 40)) e,
    ]..sort(
      (a, b) => _tierHeft(b.tier).compareTo(_tierHeft(a.tier)),
    );
    for (final enemy in caking) {
      if (dripped >= 3) break;
      if (_tierHeft(enemy.tier) < 1 && _rng.nextDouble() < 0.75) {
        continue;
      }
      if (_vfx.length >= 148) break;
      dripped++;
      final a = _rng.nextDouble() * 2 * pi;
      _vfx.add(
        _VfxParticle(
          x: enemy.position.dx + cos(a) * enemy.radius * 0.8,
          y: enemy.position.dy + sin(a) * enemy.radius * 0.8,
          vx: (_rng.nextDouble() - 0.5) * 14,
          vy: 34 + _rng.nextDouble() * 26,
          size: 1.5 + _rng.nextDouble() * 1.6,
          life: 0.45 + _rng.nextDouble() * 0.3,
          color: _rng.nextBool() ? mud : dark,
        ),
      );
    }
  }

  // ── DARK: the maw ───────────────────────────────────────────────────────

  void _openMysticMaw(CosmicSurvivalCompanion comp) {
    _mysticMaws.removeWhere((m) => m.ownerSlot == comp.slotIndex);
    final strength = _effectiveStrength(comp.slotIndex);
    final scale = _hornStatScale(strength, perPoint: 0.10, min: 0.8, max: 1.45);
    final surge = _mysticWorldPower(comp.slotIndex);
    _mysticMaws.add(
      _MysticMaw(
        // Fixed at the top of the arena, above the orb. A landmark, not a
        // placement: the player learns where the north went and fights around
        // it, which is something no other ability in the game asks of them.
        position: orb.position + Offset(0, -_arenaRadius * 0.34),
        ownerSlot: comp.slotIndex,
        radius: 430.0 * scale * surge,
        damage: max(6.0, comp.abilityAtk * 1.25 * surge),
      ),
    );
  }

  void _updateMysticMaws(double dt) {
    if (_mysticMaws.isEmpty) return;
    for (final maw in _mysticMaws) {
      final owner = activeCompanions[maw.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        maw.fade = max(0.0, maw.fade - dt * 0.6);
        if (maw.fade <= 0) continue;
      }
      if (maw.open < 1) maw.open = min(1.0, maw.open + dt * 0.9);
      maw.spin += dt * 1.15;
      if (!standing) continue;

      final reach = maw.radius * maw.open;
      final horizon = maw.horizon * maw.open;
      _visitEnemiesNear(maw.position, reach, (enemy) {
        final delta = maw.position - enemy.position;
        final dist = delta.distance;
        if (dist > reach) return false;
        if (dist <= horizon) {
          _swallowIntoMaw(maw, enemy);
          return false;
        }
        // Harder the closer it gets, so the last stretch is a fall rather
        // than a walk.
        final t = 1.0 - (dist / reach);
        final pull = (40.0 + 300.0 * t * t) * maw.open;
        enemy.position += (delta / dist) * pull * dt;
        return false;
      });
    }
    _mysticMaws.removeWhere((m) => m.dead);
  }

  /// Eats an enemy and puts it back at the rim.
  ///
  /// It is displacement, not execution — the body comes back, and the player
  /// gets the walk-in time again. A maw that killed would just be a bigger
  /// version of every other Mystic.
  void _swallowIntoMaw(_MysticMaw maw, CosmicSurvivalEnemy enemy) {
    // No damage: the comment above is the design. A hole that also ground
    // bodies down would be a damage ability wearing a crowd-control coat.
    _ejectBodyFromField(
      enemy,
      hole: maw.position,
      holeRadius: maw.radius,
      flash: const Color(0xFFB89AFF),
      landingFlash: const Color(0xFF6A4AA8),
    );
  }

  /// Throws a body out of the fight, unharmed, and makes it walk back in.
  ///
  /// Shared by every void that ejects — a Mystic+Dark maw and a Mask+Dark void
  /// hole — so "sent out of the area" means one thing. It lands on the ring
  /// walking bodies arrive on, OUTSIDE the arena rim, which is what makes this
  /// displacement rather than a shove: the player gets the whole march back.
  void _ejectBodyFromField(
    CosmicSurvivalEnemy enemy, {
    required Offset hole,
    required double holeRadius,
    Color flash = const Color(0xFFB89AFF),
    Color landingFlash = const Color(0xFF6A4AA8),
  }) {
    // And not back into the mouth (see fieldEjectLanding).
    enemy.position = CosmicAbilityRuntime.fieldEjectLanding(
      center: orb.position,
      ring: _arenaRadius + CosmicSurvivalBalance.hordeSpawnBeyondRim,
      hole: hole,
      holeRadius: holeRadius,
      rng: _rng,
    );
    enemy.knockbackVelocity = Offset.zero;
    enemy.slowTimer = max(
      enemy.slowTimer,
      CosmicAbilityRuntime.ejectSlowDuration,
    );
    enemy.slowMultiplier = min(
      enemy.slowMultiplier,
      CosmicAbilityRuntime.ejectSlowMultiplier,
    );
    enemy.retargetTimer = 0;
    _spawnHitSpark(hole, flash);
    _spawnHitSpark(enemy.position, landingFlash);
  }

  // ── PLANT: the grove ────────────────────────────────────────────────────

  void _growMysticGrove(CosmicSurvivalCompanion comp) {
    _mysticVines.removeWhere((v) => v.ownerSlot == comp.slotIndex);
    final strength = _effectiveStrength(comp.slotIndex);
    final scale =
        _hornStatScale(strength, perPoint: 0.11, min: 0.82, max: 1.5) *
        _mysticWorldPower(comp.slotIndex);
    // Rooted east and west of the ORB, evenly, and set well back from it.
    //
    // Anchoring to the caster put the grove wherever that companion happened to
    // be drifting at cast time, which is neither a place the player chose nor a
    // place they fight; the orb is what is being defended and the fixed point
    // everyone reads from. Flanking rather than bracketing because the vines
    // grow upward: stacked north and south, the northern one's canopy hung over
    // the orb and the southern one's over the fight.
    const spacing = 430.0;
    for (var i = 0; i < 2; i++) {
      final lashes = i == 0;
      _mysticVines.add(
        _MysticVine(
          root: orb.position + Offset(lashes ? -spacing : spacing, 0),
          ownerSlot: comp.slotIndex,
          lashes: lashes,
          damage: max(
            5.0,
            comp.abilityAtk *
                (lashes ? 1.5 : 1.15) *
                _mysticWorldIntensity(comp),
          ),
          reach: (lashes ? 200.0 : 620.0) * scale,
          seed: _rng.nextDouble() * 6.28,
        ),
      );
    }
  }

  /// Where a vine's head is this frame. Reads the same spine the painter draws,
  /// so what shoots and what is drawn shooting are the same point.
  Offset _mysticVineHead(_MysticVine vine) => mysticGroveVineHead(
    root: vine.root,
    growth: vine.growth,
    seed: vine.seed,
    time: stats.timeElapsed,
  );

  void _updateMysticVines(double dt) {
    if (_mysticVines.isEmpty) return;
    for (final vine in _mysticVines) {
      final owner = activeCompanions[vine.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        vine.fade = max(0.0, vine.fade - dt * 0.7);
        if (vine.fade <= 0) continue;
      }
      if (vine.growth < 1) vine.growth = min(1.0, vine.growth + dt * 1.1);
      if (vine.swing > 0) vine.swing = max(0.0, vine.swing - dt * 3.2);
      if (vine.cooldown > 0) vine.cooldown = max(0.0, vine.cooldown - dt);
      if (!standing || vine.growth < 1) continue;

      // Everything this plant does, it does from its head — the whip's root or
      // the flower — and the head is wherever the swaying stem has carried it
      // this frame. Working off `vine.root` meant a flower fired thorns that
      // came out of the ground underneath it.
      final head = _mysticVineHead(vine);
      final prey = _nearestEnemyTo(head, vine.reach);
      if (prey == null) continue;
      vine.aimAngle = atan2(
        prey.position.dy - head.dy,
        prey.position.dx - head.dx,
      );
      if (vine.cooldown > 0) continue;

      if (vine.lashes) {
        // A sweep, not a point hit: everything in the arc in front of it goes
        // flying. This is the half that punishes anything that closed.
        vine.cooldown = 2.1 / _mysticWorldTempo(owner);
        vine.swing = 1.0;
        _visitEnemiesNear(head, vine.reach, (enemy) {
          final delta = enemy.position - head;
          final dist = delta.distance;
          if (dist > vine.reach) return false;
          var diff = atan2(delta.dy, delta.dx) - vine.aimAngle;
          while (diff > pi) {
            diff -= 2 * pi;
          }
          while (diff < -pi) {
            diff += 2 * pi;
          }
          if (diff.abs() > 1.15) return false;
          _damageEnemy(enemy, vine.damage, sourceSlotIndex: vine.ownerSlot);
          if (dist > 0.5) {
            enemy.knockbackVelocity += (delta / dist) * 260;
          }
          return false;
        });
        _spawnHitSpark(
          head +
              Offset(cos(vine.aimAngle), sin(vine.aimAngle)) *
                  (vine.reach * 0.6),
          const Color(0xFF7CE07C),
        );
      } else {
        // The other half covers everything that did not.
        vine.cooldown = 1.7 / _mysticWorldTempo(owner);
        vine.swing = 1.0;
        if (companionProjectiles.length >= 210) continue;
        companionProjectiles.add(
          Projectile(
            position:
                head + Offset(cos(vine.aimAngle), sin(vine.aimAngle)) * 26,
            angle: vine.aimAngle,
            element: 'Plant',
            damage: vine.damage,
            life: 2.4,
            speedMultiplier: 1.45,
            radiusMultiplier: 1.25,
            visualScale: 1.15,
            visualStyle: ProjectileVisualStyle.mysticOrbital,
            homing: true,
            homingStrength: 5.0,
            piercing: true,
            abilityFamily: 'mystic',
            sourceSlotIndex: vine.ownerSlot,
          ),
        );
      }
    }
    _mysticVines.removeWhere((v) => v.dead);
  }

  // ── AIR: the tornado ────────────────────────────────────────────────────

  void _raiseMysticTornado(CosmicSurvivalCompanion comp) {
    _mysticTornados.removeWhere((t) => t.ownerSlot == comp.slotIndex);
    final speedStat = _effectiveIntelligence(comp.slotIndex);
    final scale =
        _hornStatScale(speedStat, perPoint: 0.10, min: 0.82, max: 1.45) *
        _mysticWorldPower(comp.slotIndex);
    _mysticTornados.add(
      _MysticTornado(
        ownerSlot: comp.slotIndex,
        // Walks a circuit out where the fight comes from, not around the orb's
        // doorstep: a tornado parked on the thing being defended would be a
        // second maelstrom, and the point of this one is that it MOVES and the
        // player has to keep track of where it is.
        orbitRadius: _arenaRadius * 0.46,
        funnelRadius: 190.0 * scale,
        damage: max(
          2.0,
          comp.abilityAtk * 0.5 * scale * _mysticWorldIntensity(comp),
        ),
        angle: _rng.nextDouble() * 2 * pi,
      ),
    );
  }

  /// Walks the tornado round its circuit and drags in whatever it passes.
  ///
  /// Anything inside the funnel is off the ground: it cannot advance, it is
  /// pulled toward the core and turned around it, and it is ground down while
  /// it is in there. When the tornado moves on it simply leaves them wherever
  /// they ended up — it never throws them anywhere, which is what keeps it
  /// clear of Steam's vent and Dark's maw.
  void _walkMysticTornado(int slotIndex, CosmicSurvivalCompanion owner) {
    for (final twister in _mysticTornados) {
      if (twister.ownerSlot != slotIndex) continue;
      // A stronger Mystic's tornado walks faster, so it sweeps more of the
      // field in the same time without losing the circuit the player tracks.
      twister.angle +=
          twister.travelSpeed * _mysticWorldTempo(owner) * twister.dt;
      twister.position =
          orb.position +
          Offset(cos(twister.angle), sin(twister.angle)) * twister.orbitRadius;
      twister.phase += twister.dt * 3.1;

      final centre = twister.position;
      final reach = twister.funnelRadius;
      _visitEnemiesNear(centre, reach, (enemy) {
        if (enemy.isDead) return false;
        final delta = enemy.position - centre;
        final dist = delta.distance;
        if (dist > reach || dist < 0.01) return false;

        enemy.slowTimer = max(enemy.slowTimer, 0.2);
        enemy.slowMultiplier = 0;
        enemy.knockbackVelocity = Offset.zero;

        // Hauled inward and turned. Tighter and faster the closer to the core,
        // so the funnel's shape is readable from the way the crowd moves.
        final closeness = 1.0 - (dist / reach);
        final omega = 2.6 * (0.4 + 1.2 * closeness);
        final angle = atan2(delta.dy, delta.dx) + omega * twister.dt;
        final pulled = dist - (70.0 + 150.0 * closeness) * twister.dt;
        enemy.position =
            centre + Offset(cos(angle), sin(angle)) * max(18.0, pulled);
        return false;
      });

      // Too heavy to lift, but it still has to fight the wind.
      for (final boss in allLivingBosses) {
        if (!_withinRange(centre, boss.position, reach)) continue;
        _applyBossCrowdControl(boss, AbilityEffectKind.slow, 0.4);
      }

      twister.grind -= twister.dt;
      if (twister.grind > 0) continue;
      twister.grind = 0.4;
      _visitEnemiesNear(centre, reach, (enemy) {
        if (enemy.isDead) return false;
        if (!_withinRange(centre, enemy.position, reach)) return false;
        _damageEnemy(enemy, twister.damage, sourceSlotIndex: slotIndex);
        return false;
      });
    }
  }

  void _updateMysticTornados(double dt) {
    if (_mysticTornados.isEmpty) return;
    for (final twister in _mysticTornados) {
      twister.dt = dt;
      final owner = activeCompanions[twister.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        twister.fade = max(0.0, twister.fade - dt * 0.7);
      }
    }
    _mysticTornados.removeWhere((t) => t.fade <= 0);
  }

  // ── WATER: the maelstrom ────────────────────────────────────────────────

  void _openMysticMaelstrom(CosmicSurvivalCompanion comp) {
    _mysticMaelstroms.removeWhere((m) => m.ownerSlot == comp.slotIndex);
    final beauty = _effectiveBeauty(comp.slotIndex);
    final intel = _effectiveIntelligence(comp.slotIndex);
    final scale = _hornStatScale(
      beauty * 0.5 + intel * 0.5,
      perPoint: 0.10,
      min: 0.82,
      max: 1.45,
    );
    // Out in the middle-to-outer ring, not on the orb.
    //
    // Centred on the orb it sat under the fight and under the player, which is
    // both the busiest part of the screen and the part that most needs to stay
    // readable — and a hold wrapped around the thing being defended is closer
    // to an off switch than to a hazard. Out here it is somewhere the player
    // steers bodies INTO, or keeps clear of.
    final bearing = _rng.nextDouble() * 2 * pi;
    _mysticMaelstroms.add(
      _MysticMaelstrom(
        ownerSlot: comp.slotIndex,
        anchor:
            orb.position +
            Offset(cos(bearing), sin(bearing)) * (_arenaRadius * 0.44),
        radius: 460.0 * scale * _mysticWorldPower(comp.slotIndex),
        damage: max(2.0, comp.abilityAtk * 0.42 * scale),
      ),
    );
  }

  /// Turns the water. Everything inside is held and carried around the eye.
  ///
  /// The hold is the point and the spin is what makes it readable: a stun with
  /// no motion looks like a bug, where bodies sliding slowly around a centre
  /// reads instantly as being caught in something. Unlike Dark's maw this never
  /// lets go and never throws anything anywhere — it keeps them, grinding.
  void _turnMysticMaelstrom(int slotIndex, CosmicSurvivalCompanion owner) {
    for (final storm in _mysticMaelstroms) {
      if (storm.ownerSlot != slotIndex) continue;
      final centre = storm.anchor;
      storm.centre = centre;

      for (final enemy in enemies) {
        if (enemy.isDead) continue;
        final delta = enemy.position - centre;
        final dist = delta.distance;
        if (dist > storm.radius || dist < 0.01) continue;

        // Held: no advance of its own for as long as it is in the water.
        enemy.slowTimer = max(enemy.slowTimer, 0.25);
        enemy.slowMultiplier = 0;
        enemy.knockbackVelocity = Offset.zero;

        // Carried. Faster near the eye, so the shape of the current is legible
        // from how the crowd moves rather than from the painting alone.
        final closeness = 1.0 - (dist / storm.radius);
        final omega = storm.spinRate * (0.35 + 0.85 * closeness);
        final angle = atan2(delta.dy, delta.dx) + omega * storm.dt;
        // Drawn slowly inward as well as around, so the crowd gathers rather
        // than orbiting at a fixed distance forever.
        final pull = dist - (14.0 + 26.0 * closeness) * storm.dt;
        enemy.position =
            centre + Offset(cos(angle), sin(angle)) * max(26.0, pull);
      }

      // A boss is too heavy to be carried, but the water still drags on it.
      for (final boss in allLivingBosses) {
        if (!_withinRange(centre, boss.position, storm.radius)) continue;
        _applyBossCrowdControl(boss, AbilityEffectKind.slow, 0.4);
      }

      storm.grind -= storm.dt;
      if (storm.grind > 0) continue;
      storm.grind = 0.5;
      _visitEnemiesNear(centre, storm.radius, (enemy) {
        if (enemy.isDead) return false;
        if (!_withinRange(centre, enemy.position, storm.radius)) return false;
        _damageEnemy(enemy, storm.damage, sourceSlotIndex: slotIndex);
        return false;
      });
    }
  }

  void _updateMysticMaelstroms(double dt) {
    if (_mysticMaelstroms.isEmpty) return;
    for (final storm in _mysticMaelstroms) {
      storm.dt = dt;
      storm.phase += dt * storm.spinRate;
      final owner = activeCompanions[storm.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        storm.fade = max(0.0, storm.fade - dt * 0.7);
      }
    }
    _mysticMaelstroms.removeWhere((m) => m.fade <= 0);
  }

  // ── LAVA: the fissures ──────────────────────────────────────────────────

  /// Cracks the arena open. Their number scales with the caster; their layout
  /// does not, so a Lava world always reads as a broken floor rather than as a
  /// few lines someone placed.
  void _openMysticFissures(CosmicSurvivalCompanion comp) {
    _mysticFissures.removeWhere((f) => f.ownerSlot == comp.slotIndex);
    final strength = _effectiveStrength(comp.slotIndex);
    // Five at the low anchor, six at an average stat, nine at perfect. (The
    // old hornStatScale(min 0, max 1.0) was already 1.0 at stat 3 — M6.)
    final count = (5 + mysticWorldHookProgress(strength) * 4).round().clamp(
      5,
      9,
    );
    final centre = orb.position;

    for (var i = 0; i < count; i++) {
      // SHORT cracks scattered through the ring, not chords across the arena.
      //
      // They were laid as full-width chords — nearly two thousand pixels each,
      // five to eight of them — which covered the entire screen in glowing
      // lines and left nothing for the eye to rest on. A crack is a local
      // thing. These are a few hundred pixels long, placed out where the fight
      // moves rather than through the middle of it, and the floor between them
      // stays floor.
      final place = _rng.nextDouble() * 2 * pi;
      final away = 0.26 + _rng.nextDouble() * 0.52;
      final mid =
          centre + Offset(cos(place), sin(place)) * (_arenaRadius * away);
      final bearing = _rng.nextDouble() * pi;
      final dir = Offset(cos(bearing), sin(bearing));
      final normal = Offset(-dir.dy, dir.dx);
      final length = 190.0 + _rng.nextDouble() * 210.0;

      final points = <Offset>[];
      const steps = 8;
      final wander = _rng.nextDouble() * 6.28;
      for (var k = 0; k <= steps; k++) {
        final f = k / steps - 0.5;
        final jag = sin(f * 9.0 + wander) * 17.0 + sin(f * 21.0 + wander) * 6.0;
        points.add(mid + dir * (length * f) + normal * jag);
      }
      _mysticFissures.add(
        _MysticFissure(
          ownerSlot: comp.slotIndex,
          points: points,
          seed: _rng.nextDouble() * 6.28,
        ),
      );
    }
  }

  /// Seconds between a crack's looks for a heavy body on it.
  static const double kMysticFissureScanInterval = 0.2;

  /// How near a crack a body's edge must come to break it.
  static const double kMysticFissureSlack = 26.0;

  /// What a heavy body that is not a boss brings down, as a share of a
  /// boss's fall, and how much longer the crack it broke takes to rearm.
  /// Measured at Potential 80, wave 41 (the family probe, the world lit): at a
  /// boss's full fall and rearm the Lava world took 48% of its party's damage
  /// against 20% for a Mystic of any element, and held 97% of waves; at half
  /// the fall and twice the rearm, 35% and 91% (a lit Mystic of any element
  /// 85%), and 28-34% from Potential 20 to 100 + Enhancement 10.
  static const double kMysticFissureHeavyFall = 0.5;
  static const double kMysticFissureHeavyRearm = 2.0;

  /// Watches for something heavy stepping over a crack.
  ///
  /// A crack does not care about the rank and file walking over it — it opens
  /// for something heavy enough to break it further. It used to open for a
  /// boss only, which left a Lava world doing nothing on four waves in five
  /// (2026-10-20 audit; user, the same day: "everything can have a niche").
  /// A brute, a colossus or an elite breaks one too, so the world punishes
  /// the heavy bodies on every wave and the boss on a boss wave, and the
  /// chaff still walks over it untouched.
  void _updateMysticFissures(double dt) {
    if (_mysticFissures.isEmpty) return;
    for (final fissure in _mysticFissures) {
      final owner = activeCompanions[fissure.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        fissure.fade = max(0.0, fissure.fade - dt * 0.7);
        continue;
      }
      if (fissure.flare > 0) {
        fissure.flare = max(0.0, fissure.flare - dt * 1.1);
      }
      if (fissure.cooldown > 0) {
        fissure.cooldown = max(0.0, fissure.cooldown - dt);
        continue;
      }
      Offset? brokenAt;
      for (final boss in allLivingBosses) {
        if (boss.isSpawning) continue;
        if (!fissure.touches(boss.position, boss.radius + kMysticFissureSlack)) {
          continue;
        }
        brokenAt = boss.position;
        break;
      }
      // A boss brings the whole fall down; anything else heavy, a lighter
      // one, and the crack takes longer to rearm after it.
      final byBoss = brokenAt != null;
      if (brokenAt == null) {
        fissure.scan -= dt;
        if (fissure.scan > 0) continue;
        fissure.scan = kMysticFissureScanInterval;
        brokenAt = _heavyBodyOnFissure(fissure)?.position;
      }
      if (brokenAt == null) continue;
      // A crack rearms sooner for a stronger Mystic ([mysticWorldTempo]).
      fissure.cooldown =
          4.0 /
          _mysticWorldTempo(owner) *
          (byBoss ? 1.0 : kMysticFissureHeavyRearm);
      fissure.flare = 1.0;
      _rainMysticMeteors(
        fissure,
        brokenAt,
        owner,
        fall: byBoss ? 1.0 : kMysticFissureHeavyFall,
      );
    }
    _mysticFissures.removeWhere((f) => f.fade <= 0);
  }

  /// Whether a Lava world's crack breaks under [enemy]: a brute, a colossus or
  /// an elite of any size. A plague root never walks, so it never crosses one.
  static bool _breaksMysticFissure(CosmicSurvivalEnemy enemy) =>
      _isHeavyBody(enemy);

  /// A brute, a colossus or an elite (not a plague root): what breaks a
  /// Lava fissure and what a Light Mask's void waits for.
  static bool _isHeavyBody(CosmicSurvivalEnemy enemy) =>
      !enemy.isPlagueCore && (enemy.hasHeavyBody || enemy.isElite);

  /// The first heavy body standing on [fissure], or null.
  CosmicSurvivalEnemy? _heavyBodyOnFissure(_MysticFissure fissure) {
    CosmicSurvivalEnemy? found;
    // The largest body, an elite colossus, reaches about 75 px from its
    // centre.
    _visitEnemiesNear(fissure.mid, fissure.reach + kMysticFissureSlack + 75, (
      enemy,
    ) {
      if (!_breaksMysticFissure(enemy)) return false;
      if (!fissure.touches(enemy.position, enemy.radius + kMysticFissureSlack)) {
        return false;
      }
      found = enemy;
      return true;
    });
    return found;
  }

  /// Meteors, aimed at nothing.
  ///
  /// Scattered across the area the crack was broken open at, not at the boss
  /// that broke it: an untargeted fall means the boss can walk out of it, the
  /// player can steer it back in, and anything else standing nearby eats one
  /// too. Homing them would make this a big single-target hit, which the
  /// roster already has several of.
  void _rainMysticMeteors(
    _MysticFissure fissure,
    Offset at,
    CosmicSurvivalCompanion owner, {
    double fall = 1.0,
  }) {
    final strength = _effectiveStrength(fissure.ownerSlot);
    final scale =
        _hornStatScale(strength, perPoint: 0.12, min: 0.8, max: 1.7) *
        _mysticWorldPower(fissure.ownerSlot);
    // [fall] is the share of a boss's fall this break brings down.
    final count = (5 * scale * fall).round().clamp(
      (4 * fall).ceil(),
      (12 * fall).ceil(),
    );
    final damage = max(
      6.0,
      owner.abilityAtk * 1.9 * scale * _mysticWorldIntensity(owner),
    );

    for (var i = 0; i < count; i++) {
      if (_mysticMeteors.length >= _maxMysticMeteors) break;
      final a = _rng.nextDouble() * 2 * pi;
      final r = 150.0 * sqrt(_rng.nextDouble());
      _mysticMeteors.add(
        _MysticMeteor(
          impact: at + Offset(cos(a), sin(a)) * r,
          ownerSlot: fissure.ownerSlot,
          damage: damage,
          seed: _rng.nextDouble() * 6.28,
          // Staggered, so they come down as a fall rather than all at once.
          remaining: _MysticMeteor.fallTime + _rng.nextDouble() * 0.85,
        ),
      );
    }
    onSound?.call(SoundCue.specialMysticRain);
  }

  void _updateMysticMeteors(double dt) {
    if (_mysticMeteors.isEmpty) return;
    for (var i = _mysticMeteors.length - 1; i >= 0; i--) {
      final meteor = _mysticMeteors[i];
      final owner = activeCompanions[meteor.ownerSlot];
      if (owner == null || owner.isDead) {
        _mysticMeteors.removeAt(i);
        continue;
      }
      meteor.remaining -= dt;
      if (meteor.remaining > 0) continue;
      _landMysticMeteor(meteor);
      _mysticMeteors.removeAt(i);
    }
  }

  void _landMysticMeteor(_MysticMeteor meteor) {
    const blast = 96.0;
    _visitEnemiesNear(meteor.impact, blast, (enemy) {
      if (enemy.isDead) return false;
      if (!_withinRange(meteor.impact, enemy.position, blast + enemy.radius)) {
        return false;
      }
      _damageEnemy(enemy, meteor.damage, sourceSlotIndex: meteor.ownerSlot);
      return false;
    });
    for (final boss in allLivingBosses) {
      if (!_withinRange(meteor.impact, boss.position, blast + boss.radius)) {
        continue;
      }
      damageBoss(
        meteor.damage,
        attackElement: 'Lava',
        sourceSlotIndex: meteor.ownerSlot,
        target: boss,
      );
    }
    _mysticScorches.add(_MysticScorch(at: meteor.impact, seed: meteor.seed));
    _spawnHitSpark(meteor.impact, const Color(0xFFFF7A1E));
    _addShake(0.14);
    // Every landing asks; the cue's cooldown thins a staggered fall.
    onSound?.call(SoundCue.specialMysticMeteor);
  }

  void _updateMysticScorches(double dt) {
    if (_mysticScorches.isEmpty) return;
    for (final scorch in _mysticScorches) {
      scorch.age += dt;
    }
    _mysticScorches.removeWhere((s) => s.dead);
  }

  // ── STEAM: the pressure ─────────────────────────────────────────────────

  /// Seconds between vents. The world's whole shape is the build and the
  /// release, so the wait is fixed and readable rather than stat-scaled.
  static const double kMysticVentInterval = 8.0;

  /// The arena exhales, and everything standing in it is thrown outward.
  ///
  /// Pure displacement, no damage. That is the point: it is the exact inverse
  /// of Dark's maw, which pulls bodies to one fixed place, and it is what
  /// keeps Steam clear of Ice (slow), Earth (stun) and every other world that
  /// resolves a crowd by hurting it. A Steam world buys the orb room, over and
  /// over, and never kills anything for you.
  void _ventMysticSteam(int slotIndex, CosmicSurvivalCompanion owner) {
    _mysticStrikes[slotIndex] = (_mysticStrikes[slotIndex] ?? 0) + 1;
    final intel = _effectiveIntelligence(slotIndex);
    final scale =
        _hornStatScale(intel, perPoint: 0.11, min: 0.8, max: 1.7) *
        _mysticWorldPower(slotIndex);
    final centre = orb.position;
    final reach = _arenaRadius * 0.92;

    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      final delta = enemy.position - centre;
      final dist = delta.distance;
      if (dist > reach) continue;
      final dir = dist > 0.01
          ? delta / dist
          : Offset(
              cos(_rng.nextDouble() * 2 * pi),
              sin(_rng.nextDouble() * 2 * pi),
            );
      // Hardest on whatever is closest to the orb, which is the thing the vent
      // is for. A uniform shove would move the far ranks as much as the ones
      // actually on top of what is being defended.
      final closeness = 1.0 - (dist / reach);
      final push = (300.0 + 620.0 * closeness * closeness) * scale;
      enemy.knockbackVelocity += dir * push;
    }
    // A boss is too heavy to throw, so the pressure staggers it instead — a
    // world that did nothing at all on boss waves would be a dead pick there.
    for (final boss in allLivingBosses) {
      _stunBoss(boss, 0.45);
    }

    _mysticVents.add(_MysticVent(centre: centre, radius: reach));
    _addShake(0.45);
    onSound?.call(SoundCue.specialMysticVent);
  }

  // ── ICE: the blizzard ───────────────────────────────────────────────────

  /// Everything on the field is slowed, always, for as long as the world holds.
  ///
  /// Written to a dedicated multiplier rather than the shared slow so it STACKS
  /// with everything else: the ordinary slow field carries the single strongest
  /// effect, so a blizzard put there would either be swallowed by a Mud world
  /// or swallow a frost hit. Weather multiplies what is already happening.
  void _breatheMysticBlizzard(int slotIndex, CosmicSurvivalCompanion owner) {
    final intel = _effectiveIntelligence(slotIndex);
    // The real stat band: about 36% slower at an average stat, 55% at perfect.
    // (The old hornStatScale(min 0, max 1.0) was already 1.0 at stat 3, so
    // every blizzard was the full 55% — M6.)
    final scale = mysticWorldHookProgress(intel);
    // 30% slower at the bottom of the stat range, 55% at the top, further with
    // the surge — and all of it on top of any other slow in play.
    final surge = _mysticWorldPower(slotIndex);
    final factor = max(0.22, (0.70 - 0.25 * scale) / surge);
    for (final enemy in enemies) {
      if (enemy.isDead) continue;
      enemy.blizzardMultiplier = factor;
    }
  }

  double _mysticRimeTimer = 0;

  /// Frost sliding off whatever the blizzard is holding.
  ///
  /// The blizzard's whole effect is a number — everything moves slower — and a
  /// crowd that is uniformly slower looks exactly like a crowd. This is what
  /// puts the cold ON the bodies, so the world is visible in the fight rather
  /// than only in the tint at the edges of the screen. Throttled and capped:
  /// a blizzard holds the entire field at once.
  void _rimeMysticBlizzard(double dt) {
    _mysticRimeTimer -= dt;
    if (_mysticRimeTimer > 0) return;
    _mysticRimeTimer = 0.07;
    if (_vfx.length >= 130) return;

    final ice = elementColor('Ice');
    final white = Color.lerp(ice, const Color(0xFFFFFFFF), 0.65)!;
    var rimed = 0;
    for (final enemy in enemies) {
      if (rimed >= 4) break;
      if (enemy.isDead || enemy.blizzardMultiplier >= 1.0) continue;
      if (!_isOnScreen(enemy.position, 40)) continue;
      if (_vfx.length >= 148) break;
      rimed++;
      final a = _rng.nextDouble() * 2 * pi;
      _vfx.add(
        _VfxParticle(
          x: enemy.position.dx + cos(a) * enemy.radius * 0.9,
          y: enemy.position.dy + sin(a) * enemy.radius * 0.9,
          // Barely drifts: frost settles, it does not fly off.
          vx: (_rng.nextDouble() - 0.5) * 10,
          vy: 12 + _rng.nextDouble() * 14,
          size: 1.1 + _rng.nextDouble() * 1.3,
          life: 0.7 + _rng.nextDouble() * 0.5,
          color: _rng.nextBool() ? white : const Color(0xFFEFFFFF),
        ),
      );
    }
  }

  /// Lifts the blizzard off everything. Called when an Ice world ends, so the
  /// field is not left permanently slowed by a Mystic that is no longer there.
  void _thawMysticBlizzard() {
    for (final enemy in enemies) {
      enemy.blizzardMultiplier = 1.0;
    }
  }

  // ── CRYSTAL: the vein ───────────────────────────────────────────────────

  /// A body that dies inside a Crystal world may leave a shard behind.
  ///
  /// Called from [_killEnemy], like Spirit's revenants, so it works for every
  /// source of death rather than only the paths that were wired up.
  void _dropMysticCrystal(CosmicSurvivalEnemy enemy) {
    // A body a shard's own burst killed leaves nothing: shards dropped round
    // the ship would be taken at once and burst again, and the vein would
    // clear the ship's ground by itself in a chain.
    if (_mysticCrystalBursting) return;
    final slot = _activeMysticWorldSlot('Crystal');
    if (slot == null) return;
    final owner = activeCompanions[slot];
    if (owner == null || owner.isDead) return;

    final beauty = _effectiveBeauty(slot);
    final chance =
        (0.16 *
                _hornStatScale(beauty, perPoint: 0.10, min: 0.7, max: 1.8) *
                _mysticWorldPower(slot))
            .clamp(0.05, 0.55);
    if (_rng.nextDouble() > chance) return;

    // The vein keeps its freshest shards. At the cap the oldest still lying
    // out dims and goes, so new ones keep appearing where the fight is: on a
    // horde wave the first thirty dropped out at the rim as it came in and
    // then blocked every other drop for their fourteen seconds, out of the
    // ship's reach (2026-10-20).
    if (_mysticCrystals.length >= _maxMysticCrystals) {
      if (_mysticCrystals.length >= _maxMysticCrystals + 10) return;
      _MysticCrystal? oldest;
      for (final c in _mysticCrystals) {
        if (c.life > kMysticCrystalRetireTime) {
          oldest = c;
          break;
        }
      }
      if (oldest == null) return;
      oldest.life = kMysticCrystalRetireTime;
    }

    _mysticCrystals.add(
      _MysticCrystal(
        position: enemy.position,
        ownerSlot: slot,
        seed: _rng.nextDouble() * 6.28,
        value: _mysticCrystalValue(enemy.tier),
      ),
    );
  }

  /// Bigger bodies leave more worth picking up.
  static double _mysticCrystalValue(EnemyTier tier) =>
      9.0 + _tierHeft(tier) * 4.0;

  /// How heavy a body of this tier is, 0 for the lightest to 5 for the
  /// heaviest, by its health.
  ///
  /// The Mud and Crystal worlds used the tier's place in [EnemyTier], which is
  /// not a size order (wisp, sentinel, brute, drone, phantom, colossus), so a
  /// drone weighed more than a brute (2026-10-20 audit). Shooters read it as
  /// well: a heavier body fires sooner and its rounds fly faster.
  static int _tierHeft(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp => 0,
    EnemyTier.drone => 1,
    EnemyTier.sentinel => 2,
    EnemyTier.phantom => 3,
    EnemyTier.brute => 4,
    EnemyTier.colossus => 5,
  };

  /// Seconds between a shooter's rounds before its traits and the wave's
  /// mutator, and how fast those rounds fly: a heavier body fires sooner and
  /// harder. Both used to read the tier's place in [EnemyTier], which put a
  /// drone above a brute ([_tierHeft], 2026-10-20 audit).
  static double _shooterCadence(EnemyTier tier) =>
      1.7 - min(_tierHeft(tier) * 0.12, 0.5);
  static double _shooterRoundSpeed(EnemyTier tier) =>
      210.0 + _tierHeft(tier) * 18;

  @visibleForTesting
  double debugShooterCadence(EnemyTier tier) => _shooterCadence(tier);
  @visibleForTesting
  double debugShooterRoundSpeed(EnemyTier tier) => _shooterRoundSpeed(tier);

  void _updateMysticCrystals(double dt) {
    if (_mysticCrystals.isEmpty) return;
    // Same magnet feel as the Plant flowers, so collecting is a reward rather
    // than a precision task in the middle of a fight.
    const collectRadius = 54.0;
    const magnetRadius = 210.0;
    for (final shard in _mysticCrystals) {
      final owner = activeCompanions[shard.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        shard.fade = max(0.0, shard.fade - dt * 0.9);
        if (shard.fade <= 0) continue;
      }
      shard.life -= dt;
      if (shard.life <= 0 || ship.isDead) continue;

      final delta = ship.position - shard.position;
      final dist = delta.distance;
      if (dist <= collectRadius) {
        shard.life = 0;
        _grantAlchemy(shard.value * _alchemyMeterGainMultiplier);
        _spawnHitSpark(ship.position, elementColor('Crystal'));
        if (owner != null && !owner.isDead) {
          _burstMysticCrystal(shard, ship.position, owner);
        }
        continue;
      }
      if (dist <= magnetRadius && dist > 0.01) {
        final t = 1.0 - (dist / magnetRadius);
        shard.position += (delta / dist) * (380.0 * t * t) * dt;
      }
    }
    _mysticCrystals.removeWhere((c) => c.dead);
  }

  /// How long a shard the vein has retired for a fresher one takes to go.
  static const double kMysticCrystalRetireTime = 0.35;

  /// How far a taken shard's burst reaches round the ship (user, 2026-10-21,
  /// after trying 160, 240 and 320: "Yeah 320 is good").
  static const double kMysticCrystalBurstRadius = 320.0;

  /// A taken shard's burst, as a share of the Mystic's SPECIAL, for a shard a
  /// wisp left; a heavier body's shard bursts harder ([_mysticCrystalBurst]).
  /// At 320 px and 8, about 16% of its party's damage and 23% of the kills
  /// at P50, 9% and 13% at P80 (the family probe, the world lit; 10% and 6%
  /// at 160 px and 3.5). How often a party held did not move with it.
  static const double kMysticCrystalBurstPower = 8.0;

  /// A burst radius and power tried in place of the constants: the family
  /// probe's (FAMILY_VEIN); null in the game.
  @visibleForTesting
  static double? veinBurstRadiusTrial, veinBurstPowerTrial;

  /// True while a shard's burst is landing, so what it kills drops no shard.
  bool _mysticCrystalBursting = false;

  /// Shards that have burst this run, for the tests.
  int _mysticCrystalBursts = 0;

  @visibleForTesting
  int get mysticCrystalBurstCount => _mysticCrystalBursts;

  /// What a shard worth [value] bursts for, from a Mystic with [special].
  /// The square root of how much more it is worth than a wisp's: a colossus's
  /// shard bursts about 1.8 times as hard.
  static double _mysticCrystalBurst(double value, int special) =>
      special *
      (veinBurstPowerTrial ?? kMysticCrystalBurstPower) *
      sqrt(max(1.0, value / _mysticCrystalValue(EnemyTier.wisp)));

  @visibleForTesting
  double debugMysticCrystalBurst(double value, int special) =>
      _mysticCrystalBurst(value, special);

  /// A taken shard shatters round the ship.
  ///
  /// The vein used to pay only alchemical meter, which made it the one world
  /// with no hand in the fight (2026-10-20 audit; user, the same day:
  /// "everything can have a niche"). It still pays the meter; and the shard
  /// breaks as it is taken, cutting what stands round the ship, so a ship
  /// that flies the vein's harvest through the horde fights with it.
  void _burstMysticCrystal(
    _MysticCrystal shard,
    Offset at,
    CosmicSurvivalCompanion owner,
  ) {
    _mysticCrystalBursts++;
    final damage =
        _mysticCrystalBurst(shard.value, owner.abilityAtk) *
        _mysticWorldPower(shard.ownerSlot);
    final radius = veinBurstRadiusTrial ?? kMysticCrystalBurstRadius;
    _mysticCrystalBursting = true;
    _visitEnemiesNear(at, radius, (enemy) {
      if (enemy.isDead) return false;
      if (!_withinRange(at, enemy.position, radius + enemy.radius)) {
        return false;
      }
      _damageEnemy(enemy, damage, sourceSlotIndex: shard.ownerSlot);
      return false;
    });
    for (final boss in allLivingBosses) {
      if (!_withinRange(at, boss.position, radius + boss.radius)) continue;
      damageBoss(
        damage,
        attackElement: 'Crystal',
        sourceSlotIndex: shard.ownerSlot,
        target: boss,
      );
    }
    _mysticCrystalBursting = false;
    // Splinters thrown out to the edge of the burst.
    if (_vfx.length < 140) {
      final crystal = elementColor('Crystal');
      for (var i = 0; i < 8; i++) {
        if (_vfx.length >= 150) break;
        final a = i * (pi / 4) + _rng.nextDouble() * 0.5;
        final speed = 160 + _rng.nextDouble() * 90;
        _vfx.add(
          _VfxParticle(
            x: at.dx,
            y: at.dy,
            vx: cos(a) * speed,
            vy: sin(a) * speed,
            size: 1.6 + _rng.nextDouble() * 1.6,
            life: 0.45 + _rng.nextDouble() * 0.2,
            color: i.isEven ? crystal : const Color(0xFFEAF6FF),
          ),
        );
      }
    }
  }

  // ── DUST: the haze ──────────────────────────────────────────────────────

  /// Whether a shooter's round goes off in its own face this time.
  ///
  /// Checked where the shot is fired rather than by redirecting the projectile:
  /// Wing+Dust already turns shooters on each other, and a Dust WORLD doing the
  /// same thing would be that ability at a larger size. A round that never
  /// leaves the barrel is its own failure.
  /// Rounds a Dust world has turned back on their owners. Counted because the
  /// failure is a shot that never happens, which leaves nothing behind to look
  /// for afterwards.
  int _mysticMisfires = 0;

  @visibleForTesting
  int get mysticMisfireCount => _mysticMisfires;

  @visibleForTesting
  Offset? mysticTornadoPosition(int slotIndex) {
    for (final t in _mysticTornados) {
      if (t.ownerSlot == slotIndex && t.fade > 0) return t.position;
    }
    return null;
  }

  @visibleForTesting
  double? mysticTornadoFunnelRadius(int slotIndex) {
    for (final t in _mysticTornados) {
      if (t.ownerSlot == slotIndex && t.fade > 0) return t.funnelRadius;
    }
    return null;
  }

  /// How many bodies a Water world currently has in its grip. Exposed so a
  /// test can assert the hold, which is otherwise only visible as enemies
  /// failing to arrive somewhere.
  @visibleForTesting
  int mysticMaelstromHeld(int slotIndex) {
    for (final storm in _mysticMaelstroms) {
      if (storm.ownerSlot != slotIndex) continue;
      return enemies
          .where(
            (e) =>
                !e.isDead &&
                (e.position - storm.centre).distance <= storm.radius,
          )
          .length;
    }
    return 0;
  }

  @visibleForTesting
  Offset? mysticMaelstromCentre(int slotIndex) {
    for (final storm in _mysticMaelstroms) {
      if (storm.ownerSlot == slotIndex && storm.fade > 0) return storm.anchor;
    }
    return null;
  }

  @visibleForTesting
  double? mysticMaelstromRadius(int slotIndex) {
    for (final storm in _mysticMaelstroms) {
      if (storm.ownerSlot == slotIndex && storm.fade > 0) return storm.radius;
    }
    return null;
  }

  @visibleForTesting
  int mysticFissureCount(int slotIndex) => _mysticFissures
      .where((f) => f.ownerSlot == slotIndex && f.fade > 0)
      .length;

  @visibleForTesting
  int get mysticMeteorCount => _mysticMeteors.length;

  /// Whether any of this slot's cracks runs within [slack] of [at]. Exposed so
  /// a test can put a boss on a crack without knowing where the cracks are.
  @visibleForTesting
  Offset? mysticFissurePointNear(int slotIndex) {
    for (final f in _mysticFissures) {
      if (f.ownerSlot == slotIndex && f.fade > 0) {
        return f.points[f.points.length ~/ 2];
      }
    }
    return null;
  }

  /// Blows a Steam world's vent now, exactly as the clock does.
  ///
  /// Exposed so a test can assert the vent itself deals no damage: waiting for
  /// the clock means the party spends those eight seconds shooting, and the
  /// chip damage from that is indistinguishable from damage the vent might
  /// have done.
  @visibleForTesting
  void debugVentSteam(int slotIndex) {
    final comp = activeCompanions[slotIndex];
    if (comp == null) return;
    _ventMysticSteam(slotIndex, comp);
  }

  /// What a Mud world currently multiplies damage by, for a body of this size.
  /// Exposed because the effect is a factor on a damage roll, which leaves
  /// nothing on the field to observe afterwards.
  @visibleForTesting
  double debugWeightMultiplier(EnemyTier tier) => _mysticWeightMultiplier(tier);

  /// What a shard a Crystal world drops from a body of this size is worth.
  @visibleForTesting
  double debugMysticCrystalValue(EnemyTier tier) => _mysticCrystalValue(tier);

  /// Rolls the haze against one enemy, as the fire path does.
  ///
  /// Exposed because shooter-conduct enemies do not appear until deep waves —
  /// a test that waited for one to fire naturally would run for minutes and
  /// still be at the mercy of the spawn table.
  @visibleForTesting
  bool debugRollHaze(CosmicSurvivalEnemy enemy) => _mysticHazeMisfire(enemy);

  /// The chance the haze of the Dust world [slot] hosts takes a body: a
  /// shooter's round going off in its face, or a walker losing its way.
  double _mysticHazeChance(int slot) {
    final intel = _effectiveIntelligence(slot);
    return (0.22 *
            _hornStatScale(intel, perPoint: 0.09, min: 0.7, max: 1.7) *
            _mysticWorldPower(slot))
        .clamp(0.08, 0.60)
        .toDouble();
  }

  bool _mysticHazeMisfire(CosmicSurvivalEnemy enemy) {
    final slot = _activeMysticWorldSlot('Dust');
    if (slot == null) return false;
    final owner = activeCompanions[slot];
    if (owner == null || owner.isDead) return false;

    final chance = _mysticHazeChance(slot);
    if (_rng.nextDouble() > chance) return false;

    _mysticMisfires++;
    _damageEnemy(enemy, enemy.damage * 1.35, sourceSlotIndex: slot);
    _spawnHitSpark(enemy.position, elementColor('Dust'));
    if (_vfx.length < 142) {
      final dust = elementColor('Dust');
      for (var i = 0; i < 6; i++) {
        if (_vfx.length >= 150) break;
        final a = _rng.nextDouble() * 2 * pi;
        _vfx.add(
          _VfxParticle(
            x: enemy.position.dx,
            y: enemy.position.dy,
            vx: cos(a) * (50 + _rng.nextDouble() * 70),
            vy: sin(a) * (50 + _rng.nextDouble() * 70),
            size: 1.4 + _rng.nextDouble() * 1.8,
            life: 0.4 + _rng.nextDouble() * 0.3,
            color: i.isEven ? dust : const Color(0xFFD6B080),
          ),
        );
      }
    }
    return true;
  }

  /// How long a body that lost its way in the haze walks off its heading.
  static const double kMysticHazeLostMin = 1.2;
  static const double kMysticHazeLostMax = 2.2;

  /// How far off its true heading a lost body walks, in radians: from
  /// 70 degrees, across the orb's approach, to 160, nearly back the way it
  /// came.
  static const double kMysticHazeTurnMin = 1.22;
  static const double kMysticHazeTurnMax = 2.79;

  /// Bodies the haze has turned off their way this run, for the tests.
  int _mysticHazeLost = 0;

  @visibleForTesting
  int get mysticHazeLostCount => _mysticHazeLost;

  /// Rolls the haze against a body that walks to its target, as it looks for
  /// one, with the world's own chance.
  @visibleForTesting
  bool debugLoseWayInHaze(CosmicSurvivalEnemy enemy) {
    final slot = _activeMysticWorldSlot('Dust');
    if (slot == null) return false;
    return _loseWayInHaze(enemy, slot, _mysticHazeChance(slot));
  }

  /// Whether a body that walks to its target loses it in the haze this time.
  ///
  /// The haze only ever choked shooters, and a horde body never shoots, so on
  /// most of the field the world did nothing (2026-10-20 audit; user, the same
  /// day: "everything can have a niche"). A body that walks in now loses its
  /// target in the grit, at the chance a shooter misfires, and for a moment
  /// walks off its heading ([kMysticHazeTurnMin] to [kMysticHazeTurnMax]).
  /// Shooters keep their misfire instead; bosses are not in the grit's
  /// reach.
  bool _loseWayInHaze(CosmicSurvivalEnemy enemy, int slot, double chance) {
    if (enemy.isShooter || enemy.isPlagueCore) return false;
    final owner = activeCompanions[slot];
    if (owner == null || owner.isDead) return false;
    if (_rng.nextDouble() > chance) return false;

    _mysticHazeLost++;
    enemy.mysticHazeLostTimer =
        kMysticHazeLostMin +
        _rng.nextDouble() * (kMysticHazeLostMax - kMysticHazeLostMin);
    final turn =
        kMysticHazeTurnMin +
        _rng.nextDouble() * (kMysticHazeTurnMax - kMysticHazeTurnMin);
    enemy.mysticHazeHeading = _rng.nextBool() ? turn : -turn;
    // A puff of grit where it loses its way, so a player can see the haze
    // turning bodies.
    if (_vfx.length < 130) {
      final dust = elementColor('Dust');
      for (var i = 0; i < 3; i++) {
        final a = _rng.nextDouble() * 2 * pi;
        _vfx.add(
          _VfxParticle(
            x: enemy.position.dx + cos(a) * enemy.radius * 0.8,
            y: enemy.position.dy + sin(a) * enemy.radius * 0.8,
            vx: cos(a) * (20 + _rng.nextDouble() * 25),
            vy: sin(a) * (20 + _rng.nextDouble() * 25),
            size: 1.4 + _rng.nextDouble() * 1.4,
            life: 0.5 + _rng.nextDouble() * 0.3,
            color: i.isEven ? dust : const Color(0xFFD6B080),
          ),
        );
      }
    }
    return true;
  }

  // ── LIGHT: the dawn ─────────────────────────────────────────────────────

  void _raiseMysticStar(CosmicSurvivalCompanion comp) {
    _mysticStars.removeWhere((s) => s.ownerSlot == comp.slotIndex);
    final beauty = _effectiveBeauty(comp.slotIndex);
    final scale = _hornStatScale(beauty, perPoint: 0.09, min: 0.75, max: 1.5);
    _mysticStars.add(
      _MysticStar(
        ownerSlot: comp.slotIndex,
        // Outside the arena entirely, up and to one side. It is a thing on the
        // horizon rather than a thing in the fight, and the player watches it
        // get closer to going off.
        position:
            orb.position + Offset(_arenaRadius * 0.62, -_arenaRadius * 0.78),
        // Faster with beauty and with the surge: the whole ability is the wait.
        period: max(18.0, 46.0 / (scale * _mysticWorldPower(comp.slotIndex))),
      ),
    );
  }

  void _updateMysticStars(double dt) {
    if (_mysticStars.isEmpty) return;
    for (final star in _mysticStars) {
      final owner = activeCompanions[star.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        star.fade = max(0.0, star.fade - dt * 0.7);
        if (star.fade <= 0) continue;
      }
      if (star.flare > 0) {
        star.flare = max(0.0, star.flare - dt * 1.6);
        continue;
      }
      if (!standing) continue;
      star.charge += dt / star.period;
      if (star.charge < 1.0) continue;
      star.charge = 0;
      star.flare = 1.0;
      _breakMysticDawn(star.ownerSlot);
    }
    _mysticStars.removeWhere((s) => s.dead);
  }

  /// Dawn. Everything the player owns goes back to full.
  ///
  /// A full heal rather than a big one: the ability is the WAIT, and a number
  /// the player has to compare against their current health is a worse thing to
  /// watch a countdown for than a promise they already understand.
  void _breakMysticDawn(int slotIndex) {
    final before = orb.currentHp;
    orb.currentHp = orb.maxHp;
    _recordHeal(orb.currentHp - before, target: 2, sourceSlot: slotIndex);
    if (!ship.isDead) {
      final shipBefore = ship.currentHp;
      ship.currentHp = ship.maxHp;
      _recordHeal(
        ship.currentHp - shipBefore,
        target: 1,
        sourceSlot: slotIndex,
      );
    }
    for (final comp in activeCompanions.values) {
      if (comp.isDead) continue;
      final compBefore = comp.currentHp;
      comp.currentHp = comp.maxHp;
      _recordHeal(
        (comp.currentHp - compBefore).toDouble(),
        target: 0,
        sourceSlot: slotIndex,
      );
    }
    _mysticSkyFlash = max(_mysticSkyFlash, 1.0);
    _mysticSkyFlashAt = orb.position;
    _mysticSkyFlashElement = 'Light';
    onSound?.call(SoundCue.specialMysticDawn);
  }

  // ── LIGHTNING: the storm ────────────────────────────────────────────────

  /// One strike, on the clock. Picks a body at random rather than the biggest
  /// or the nearest: a storm is not aiming, and a bolt the player cannot
  /// predict is the thing that makes the sky feel like weather instead of a
  /// turret they own.
  /// Strikes and quakes delivered per slot — the clock's odometer.
  final Map<int, int> _mysticStrikes = {};

  void _strikeMysticLightning(int slotIndex, CosmicSurvivalCompanion owner) {
    // Bosses stand in the same pool as everything else, so whether a strike
    // lands on one is luck — which is what makes it land.
    final live = [
      for (final e in enemies)
        if (!e.isDead) e,
    ];
    final bosses = allLivingBosses.toList();
    final total = live.length + bosses.length;
    if (total == 0) return;

    final pick = _rng.nextInt(total);
    final at = pick < live.length
        ? live[pick].position
        : bosses[pick - live.length].position;

    // The sky charges before it strikes.
    //
    // A bolt that simply appeared was over before the player could register
    // it, and there was nothing to play around — a fixed rhythm is only worth
    // having if you can see the beat coming. The mark commits to a PLACE, so
    // in the window the player can walk something into it, or pull a boss out.
    _mysticCharges.add(
      _MysticCharge(
        at: at,
        ownerSlot: slotIndex,
        seed: _rng.nextDouble() * 6.28,
      ),
    );
    // Scored from the mark: the bolt in it lands as the charge does.
    onSound?.call(SoundCue.specialMysticStrike);
  }

  /// Resolves a strike on the spot the sky marked.
  ///
  /// Damages the GROUND rather than the body originally rolled: the target may
  /// have moved, died, or been replaced by something that wandered in, and
  /// "whatever is standing there when it lands" is both fairer and the thing
  /// that makes the telegraph worth watching.
  void _landMysticLightning(_MysticCharge charge) {
    _mysticStrikes[charge.ownerSlot] =
        (_mysticStrikes[charge.ownerSlot] ?? 0) + 1;
    final owner = activeCompanions[charge.ownerSlot];
    if (owner == null || owner.isDead) return;

    final intel = _effectiveIntelligence(charge.ownerSlot);
    final scale = _hornStatScale(intel, perPoint: 0.15, min: 0.8, max: 2.0);
    final damage = max(
      8.0,
      owner.abilityAtk *
          5.5 *
          scale *
          _mysticWorldPower(charge.ownerSlot) *
          _mysticWorldIntensity(owner),
    );
    const splash = 120.0;

    var hitBoss = false;
    for (final boss in allLivingBosses) {
      if (!_withinRange(charge.at, boss.position, splash + boss.radius)) {
        continue;
      }
      damageBoss(
        damage,
        attackElement: 'Lightning',
        sourceSlotIndex: charge.ownerSlot,
        target: boss,
      );
      _stunBoss(boss, 1.0);
      hitBoss = true;
    }
    _visitEnemiesNear(charge.at, splash, (enemy) {
      if (enemy.isDead) return false;
      if (!_withinRange(charge.at, enemy.position, splash + enemy.radius)) {
        return false;
      }
      _damageEnemy(enemy, damage, sourceSlotIndex: charge.ownerSlot);
      return false;
    });

    _mysticBolts.add(
      _MysticBolt(strike: charge.at, seed: charge.seed, onBoss: hitBoss),
    );
    _spawnHitSpark(charge.at, const Color(0xFFE8F4FF));
    // Lightning lights the ground it strikes, and the thunder is felt. A boss
    // taking one earns more of both — that strike bought the player a second.
    _mysticSkyFlash = max(_mysticSkyFlash, hitBoss ? 1.0 : 0.62);
    _mysticSkyFlashAt = charge.at;
    _mysticSkyFlashElement = 'Lightning';
    _addShake(hitBoss ? 0.55 : 0.24);
  }

  void _updateMysticCharges(double dt) {
    if (_mysticCharges.isEmpty) return;
    for (var i = _mysticCharges.length - 1; i >= 0; i--) {
      final charge = _mysticCharges[i];
      final owner = activeCompanions[charge.ownerSlot];
      if (owner == null || owner.isDead) {
        _mysticCharges.removeAt(i);
        continue;
      }
      charge.remaining -= dt;
      if (charge.remaining > 0) continue;
      _landMysticLightning(charge);
      _mysticCharges.removeAt(i);
    }
  }

  /// A strike's (or the dawn's) light, decaying, pooled round
  /// [_mysticSkyFlashAt] in [_mysticSkyFlashElement]'s material.
  double _mysticSkyFlash = 0;
  Offset _mysticSkyFlashAt = Offset.zero;
  String _mysticSkyFlashElement = 'Lightning';

  /// A hard stop, unlike the ordinary chill.
  ///
  /// `_applyBossCrowdControl` floors a boss's slow at [kBossChillFloor] so no
  /// combination of abilities can lock one down forever. A Mystic world is the
  /// deliberate exception: one second, once every five, bought by spending the
  /// single Mystic slot on it. Attack timers are held too — a boss that keeps
  /// firing while frozen in place has not been stunned, it has been slowed.
  void _stunBoss(SurvivalBoss boss, double seconds) {
    if (boss.isDead || boss.isSpawning) return;
    boss.chillMultiplier = 0;
    boss.chillTimer = max(boss.chillTimer, seconds);
    boss.shootTimer = max(boss.shootTimer, seconds);
    boss.spreadTimer = max(boss.spreadTimer, seconds);
    boss.summonTimer = max(boss.summonTimer, seconds);
  }

  /// Screen shake, as a decaying trauma value rather than a countdown.
  ///
  /// Trauma squared drives the amplitude, which is what makes a shake feel
  /// like an impact instead of a vibration: it hits hard and lets go fast,
  /// and two shakes overlapping add rather than replacing one another.
  double _shakeTrauma = 0;
  double _shakeClock = 0;

  void _addShake(double amount) {
    _shakeTrauma = min(1.0, _shakeTrauma + amount);
  }

  void _updateShake(double dt) {
    _shakeClock += dt;
    // Decays on its own, so the world has to keep asserting it.
    _tremor = max(0.0, _tremor - dt * 18.0);
    if (_shakeTrauma > 0) {
      _shakeTrauma = max(0.0, _shakeTrauma - dt * 1.35);
    }
  }

  /// A constant low tremor while an Earth world stands, rising as the next
  /// quake approaches. Set every frame by the world; zero otherwise.
  ///
  /// This is the whole answer to "I can hardly tell": a tint and a quake every
  /// fifteen seconds left thirteen of those seconds with nothing in them. A
  /// floor that never quite stops moving is felt continuously without ever
  /// taking the screen, and its rising makes the quake something the player
  /// sees coming rather than something that simply happens to them.
  double _tremor = 0;

  Offset _screenShakeOffset() {
    final tremor = _tremor;
    if (_shakeTrauma <= 0.001 && tremor <= 0.001) {
      return Offset.zero;
    }
    final power = _shakeTrauma * _shakeTrauma;
    final amplitude = 26.0 * power + tremor;
    // Two different frequencies so the motion never looks like a clean orbit.
    return Offset(
      sin(_shakeClock * 43.0) * amplitude,
      cos(_shakeClock * 37.0) * amplitude * 0.8,
    );
  }

  // ── EARTH: the quake ────────────────────────────────────────────────────

  /// [led] when the quake's lead-in cue already carries this break.
  void _shakeMysticEarth(
    int slotIndex,
    CosmicSurvivalCompanion owner, {
    bool led = false,
  }) {
    _mysticStrikes[slotIndex] = (_mysticStrikes[slotIndex] ?? 0) + 1;
    final strength = _effectiveStrength(slotIndex);
    final scale = _hornStatScale(strength, perPoint: 0.12, min: 0.8, max: 1.8);
    final damage = max(
      5.0,
      owner.abilityAtk *
          2.0 *
          scale *
          _mysticWorldPower(slotIndex) *
          _mysticWorldIntensity(owner),
    );
    // Arena-wide: the ground is the ground. A radius would make it a big
    // explosion, which every other family already has several of.
    _mysticQuakes.add(
      _MysticQuake(centre: orb.position, radius: _arenaRadius * 0.95),
    );
    // SNAPSHOT: killing something here can APPEND to `enemies` — a splitter
    // breaks into smaller bodies on death, and a summoner's brood lands in the
    // same list — so walking the live list throws Concurrent modification mid-
    // frame. `_updateEnemies` already iterates a copy for exactly this reason.
    for (final enemy in List<CosmicSurvivalEnemy>.of(enemies)) {
      if (enemy.isDead) continue;
      _damageEnemy(enemy, damage, sourceSlotIndex: slotIndex);
      if (enemy.isDead) continue;
      // Off its feet, not merely slowed.
      enemy.slowTimer = max(enemy.slowTimer, 1.2);
      enemy.slowMultiplier = 0;
      enemy.knockbackVelocity = Offset.zero;
    }
    for (final boss in allLivingBosses) {
      damageBoss(
        damage,
        attackElement: 'Earth',
        sourceSlotIndex: slotIndex,
        target: boss,
      );
      _stunBoss(boss, 0.7);
    }
    // The quake is the whole arena moving. A ring drawn on the floor can only
    // ever say that; shaking the view is the thing that makes the player feel
    // it, and it is why the ring itself can now be subtle.
    _addShake(0.85);
    if (!led) onSound?.call(SoundCue.combatHitHeavy);
  }

  // ── POISON: the ship's wake ─────────────────────────────────────────────

  void _trailMysticPoison(
    int slotIndex,
    CosmicSurvivalCompanion owner,
    double dt,
  ) {
    if (ship.isDead) return;
    final last = _mysticPoisonLastDrop[slotIndex];
    if (last == null) {
      _mysticPoisonLastDrop[slotIndex] = ship.position;
      return;
    }
    // Spaced by distance flown, not by time: a parked ship should not stack a
    // tower of patches on one spot, and a fast one should not leave gaps.
    const spacing = 46.0;
    if ((ship.position - last).distance < spacing) return;
    _mysticPoisonLastDrop[slotIndex] = ship.position;

    final intel = _effectiveIntelligence(slotIndex);
    final beauty = _effectiveBeauty(slotIndex);
    final scale =
        _hornStatScale(
          intel * 0.5 + beauty * 0.5,
          perPoint: 0.12,
          min: 0.8,
          max: 1.6,
        ) *
        _mysticWorldPower(slotIndex);
    // A stronger Mystic's miasma spreads wider, lingers longer and trails a
    // longer wake ([mysticWorldTempo]). Its hits already killed what a patch
    // covered, so reach was what fell behind: with fixed patches it read 3.4x
    // the median special at P50 and 1.5x at P100E10 (ability pass, final
    // balance, 2026-10-10).
    final tempo = _mysticWorldTempo(owner);
    if (_mysticPools.length >= (_maxMysticPools * tempo).round()) {
      // Oldest patch goes first, so the trail behaves like a trail.
      _mysticPools.removeAt(0);
    }
    // Laid from behind the hull rather than under it, so it comes off the
    // ship's wake instead of materialising beneath the thing the player is
    // looking at.
    final trailing =
        ship.position - Offset(cos(ship.angle), sin(ship.angle)) * 20.0;
    _mysticPools.add(
      _MysticPool(
        position: trailing,
        ownerSlot: slotIndex,
        radius: 22.0 * scale * tempo * sqrt(tempo),
        damage: max(
          2.0,
          owner.abilityAtk * 0.55 * scale * _mysticWorldIntensity(owner),
        ),
        seed: _rng.nextDouble() * 6.28,
        life: 6.0 * scale * tempo,
      ),
    );
  }

  void _updateMysticPools(double dt) {
    if (_mysticPools.isEmpty) return;
    for (final pool in _mysticPools) {
      final owner = activeCompanions[pool.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) {
        pool.fade = max(0.0, pool.fade - dt * 0.9);
        if (pool.fade <= 0) continue;
      }
      pool.age += dt;
      pool.life -= dt;
      if (pool.life <= 0 || !standing) continue;
      pool.tick -= dt;
      if (pool.tick > 0) continue;
      // Bites faster for a stronger Mystic ([mysticWorldTempo]).
      pool.tick = 0.45 / _mysticWorldTempo(owner);
      // Bites only as far as it has actually spread, so a patch never damages
      // ground it has not visibly covered yet.
      final reach = pool.radius * pool.spreadEase;
      _visitEnemiesNear(pool.position, reach, (enemy) {
        if (enemy.isDead) return false;
        if (!_withinRange(
          pool.position,
          enemy.position,
          reach + enemy.radius,
        )) {
          return false;
        }
        _applyAbilityEffectToEnemy(
          AbilityEffectKind.poison,
          enemy,
          pool.position,
          pool.damage,
          reach,
          2.0,
          sourceSlotIndex: pool.ownerSlot,
          element: 'Poison',
          family: 'mystic',
        );
        return false;
      });
    }
    _mysticPools.removeWhere((p) => p.dead);
  }

  // ── MUD: the weight ─────────────────────────────────────────────────────

  /// A Mud world cakes everything on the field, and heavy things worst.
  ///
  /// This was a slow applied to whatever the ship hit, and that was a dead end:
  /// Ice already slows the entire field, always, stacking with everything else,
  /// so Mud was a strictly worse copy of a world that already existed. Weight
  /// is a verb nothing else in the family has — the mud does not make anything
  /// slower, it makes everything take MORE.
  ///
  /// Scaled by the size of the body, which inverts the usual problem: a wisp
  /// barely notices and a colossus is dragging half the arena around with it.
  /// The bigger the thing, the more the world hates it.
  double _mysticWeightMultiplier(EnemyTier tier) {
    final slot = _activeMysticWorldSlot('Mud');
    if (slot == null) return 1.0;
    final comp = activeCompanions[slot];
    if (comp == null || comp.isDead) return 1.0;

    final scale = _hornStatScale(
      _effectiveStrength(slot) * 0.5 + _effectiveIntelligence(slot) * 0.5,
      perPoint: 0.11,
      min: 0.75,
      max: 1.5,
    );
    // 12% on the lightest body up to 60% on the heaviest, before stats and the
    // surge — enough that a colossus walking into a Mud world is a different
    // fight, without turning the chaff into paper.
    final byTier = 0.12 + _tierHeft(tier) * 0.096;
    return 1.0 + byTier * scale * _mysticWorldPower(slot);
  }

  /// The same weight on a boss, which is the heaviest thing on the field and
  /// so takes the top of the scale.
  double _mysticBossWeightMultiplier() =>
      _mysticWeightMultiplier(EnemyTier.colossus);

  // ── GROUND COVER: what a world does to the map itself ───────────────────

  /// Seeds ground cover for whichever world is standing.
  ///
  /// On the arena's OUTER RING, around the orb — not around the ship. Ground
  /// cover is scenery: it says what the map is, and it should frame the fight
  /// from the border rather than grow up through the middle of it, where it
  /// competes with the enemies and effects the player is actually reading.
  void _updateMysticFlora(double dt) {
    for (final f in _mysticFlora) {
      f.age += dt;
    }
    _mysticFlora.removeWhere((f) => f.dead);

    _mysticFloraTimer -= dt;
    if (_mysticFloraTimer > 0) return;
    _mysticFloraTimer = 0.28;
    if (_mysticFlora.length >= _maxMysticFlora) return;
    if (_mysticSpentSlots.isEmpty) return;

    for (final slot in _mysticSpentSlots) {
      final comp = activeCompanions[slot];
      if (comp == null || comp.isDead) continue;
      if (!_mysticFloraElements.contains(comp.member.element)) continue;
      if (_mysticFlora.length >= _maxMysticFlora) break;

      // A band at the arena's edge — the outer third, the same ring the
      // outermost families patrol.
      final a = _rng.nextDouble() * 2 * pi;
      final r = _arenaRadius * (0.74 + _rng.nextDouble() * 0.22);
      _mysticFlora.add(
        _MysticFlora(
          position: orb.position + Offset(cos(a), sin(a)) * r,
          ownerSlot: slot,
          element: comp.member.element,
          size: 0.7 + _rng.nextDouble() * 0.7,
          seed: _rng.nextDouble() * 6.28,
          life: 4.0 + _rng.nextDouble() * 4.0,
        ),
      );
    }
  }

  /// Worlds that dress the ground.
  ///
  /// Mud was excluded on the reasoning that a rule on the ship's guns has no
  /// scenery to justify — which was wrong twice over. Its fiction is that the
  /// FIELD turns to mud, so mire on the ground is the literal claim, not
  /// decoration around it; and without any, a Mud world was a brown tint and
  /// nothing else, by far the thinnest of the nine.
  ///
  /// Blood and Dark stay out. Blood genuinely happens on the party's guns and
  /// nowhere else, and Dark's map is defined by the hole in it.
  static const Set<String> _mysticFloraElements = {
    'Plant',
    'Fire',
    'Poison',
    'Spirit',
    'Mud',
    'Ice',
    'Dust',
  };

  /// Per-frame tick for every Mystic world except the ember field, which has
  /// its own pass.
  void _updateMysticWorlds(double dt) {
    if (_mysticBloodMoteTimer > 0) {
      _mysticBloodMoteTimer = max(0.0, _mysticBloodMoteTimer - dt);
    }
    if (_mysticMireSplatTimer > 0) {
      _mysticMireSplatTimer = max(0.0, _mysticMireSplatTimer - dt);
    }
    _dripMire(dt);
    if (_activeMysticWorldSlot('Ice') != null) _rimeMysticBlizzard(dt);
    _updateMysticRevenants(dt);
    _updateMysticMaws(dt);
    _updateMysticVines(dt);
    _updateMysticPools(dt);
    _updateMysticWeatherClocks(dt);
    _updateMysticFlora(dt);
    _updateMysticCharges(dt);
    _updateMysticCrystals(dt);
    _updateMysticStars(dt);
    _updateMysticMaelstroms(dt);
    _updateMysticTornados(dt);
    _updateMysticFissures(dt);
    _updateMysticMeteors(dt);
    _updateMysticScorches(dt);
    _updateShake(dt);
    if (_mysticSkyFlash > 0) {
      _mysticSkyFlash = max(0.0, _mysticSkyFlash - dt * 3.4);
    }

    for (final bolt in _mysticBolts) {
      bolt.life -= dt;
    }
    _mysticBolts.removeWhere((b) => b.dead);
    for (final quake in _mysticQuakes) {
      quake.age += dt;
    }
    _mysticQuakes.removeWhere((q) => q.dead);
    for (final vent in _mysticVents) {
      vent.age += dt;
    }
    _mysticVents.removeWhere((v) => v.dead);
  }

  /// Drives the worlds that happen on a clock — Lightning's strikes, Earth's
  /// quakes — and the one that happens wherever the ship has been.
  ///
  /// The clock runs off the CASTER, not off a standing entity, so a world that
  /// leaves nothing on the field behaves like the ones that do: it stops the
  /// moment its Mystic is recalled or falls.
  void _updateMysticWeatherClocks(double dt) {
    if (_mysticSpentSlots.isEmpty) return;
    for (final slot in _mysticSpentSlots.toList()) {
      final comp = activeCompanions[slot];
      if (comp == null || comp.isDead) continue;
      switch (comp.member.element) {
        // The surge shortens the wait as well as raising the damage. Divided
        // rather than subtracted so three picks can never drive an interval to
        // zero and turn the weather into a continuous beam.
        case 'Lightning':
          final beat = _mysticBeat(slot, comp, kMysticStrikeInterval);
          final next = (_mysticClock[slot] ?? beat) - dt;
          if (next <= 0) {
            _mysticClock[slot] = beat;
            _strikeMysticLightning(slot, comp);
          } else {
            _mysticClock[slot] = next;
          }
        case 'Earth':
          final beat = _mysticBeat(slot, comp, kMysticQuakeInterval);
          final next = (_mysticClock[slot] ?? beat) - dt;
          if (next <= 0) {
            _mysticClock[slot] = beat;
            final led = _mysticQuakeCued.remove(slot);
            _shakeMysticEarth(slot, comp, led: led);
          } else {
            _mysticClock[slot] = next;
            if (next <= 1.6 && _mysticQuakeCued.add(slot)) {
              onSound?.call(SoundCue.specialMysticQuake);
            }
            // Always trembling a little, and hard in the last second or so
            // before it breaks. Quartic so the build stays almost unnoticed
            // until the end and then arrives fast.
            final closing = 1.0 - (next / beat);
            final ramp = closing * closing * closing * closing;
            _tremor = max(_tremor, 0.9 + 7.5 * ramp);
          }
        case 'Poison':
          _trailMysticPoison(slot, comp, dt);
        case 'Steam':
          final beat = _mysticBeat(slot, comp, kMysticVentInterval);
          final next = (_mysticClock[slot] ?? beat) - dt;
          if (next <= 0) {
            _mysticClock[slot] = beat;
            _ventMysticSteam(slot, comp);
          } else {
            _mysticClock[slot] = next;
          }
        case 'Water':
          _turnMysticMaelstrom(slot, comp);
        case 'Air':
          _walkMysticTornado(slot, comp);
        case 'Ice':
          // Reapplied every frame rather than on a timer: bodies spawn into
          // the blizzard mid-run, and a world that only caught what was
          // already standing there would thin out as the wave went on.
          _breatheMysticBlizzard(slot, comp);
      }
    }
  }

  void _updateMysticEmbers(double dt) {
    if (_mysticEmbers.isEmpty) return;
    final centre = orb.position;
    final bound = max(260.0, _arenaRadius);
    for (final ember in _mysticEmbers) {
      final owner = activeCompanions[ember.ownerSlot];
      final alive = owner != null && !owner.isDead;
      if (!alive) {
        // Two seconds to go out.
        ember.fade = max(0.0, ember.fade - dt * 0.5);
        if (ember.fade <= 0) continue;
      }

      // Wander: the heading drifts so the field churns instead of every ember
      // travelling in a straight line forever.
      final wander = sin(stats.timeElapsed * 0.7 + ember.seed) * 0.6;
      final v = ember.velocity;
      final speed = v.distance.clamp(6.0, 34.0);
      final heading = atan2(v.dy, v.dx) + wander * dt;
      ember.velocity = Offset(cos(heading), sin(heading)) * speed;
      ember.position += ember.velocity * dt;

      // Stay in the arena — turn back rather than bouncing hard, so the drift
      // keeps looking aimless.
      final away = ember.position - centre;
      if (away.distance > bound) {
        final inward = -away / away.distance;
        ember.velocity = inward * speed;
        ember.position = centre + (away / away.distance) * bound;
      }

      if (ember.reignite > 0) {
        ember.reignite = max(0.0, ember.reignite - dt);
        continue;
      }
      if (!alive) continue;

      // Anything that walks into an ember catches light.
      _visitEnemiesNear(ember.position, 26.0, (enemy) {
        if (enemy.isDead) return false;
        if (!_withinRange(ember.position, enemy.position, enemy.radius + 9.0)) {
          return false;
        }
        _applyAbilityEffectToEnemy(
          AbilityEffectKind.burn,
          enemy,
          ember.position,
          max(
            3.0,
            owner.abilityAtk *
                0.34 *
                _mysticWorldPower(ember.ownerSlot) *
                _mysticWorldIntensity(owner),
          ),
          60,
          2.4,
          sourceSlotIndex: ember.ownerSlot,
          element: 'Fire',
          family: 'mystic',
        );
        _spawnHitSpark(enemy.position, const Color(0xFFFF8A2B));
        ember.reignite = 0.65 / _mysticWorldTempo(owner);
        return true;
      });
    }
    _mysticEmbers.removeWhere((e) => e.fade <= 0);
  }

  void _pushMysticEnvironment(String element, int ownerSlot) {
    // One world per caster. Recasting replaces it rather than stacking a
    // second copy of the same weather on top of itself.
    for (final env in _mysticEnvironments) {
      if (env.ownerSlot == ownerSlot) env.beginClosing();
    }
    if (_mysticEnvironments.length >= 6) {
      _mysticEnvironments.removeAt(0); // budget cap
    }
    _mysticEnvironments.add(
      _MysticEnvironment(element: element, ownerSlot: ownerSlot),
    );
  }

  /// Closes a slot's world. Called when its Mystic is recalled or dies.
  void _closeMysticEnvironment(int ownerSlot) {
    for (final env in _mysticEnvironments) {
      if (env.ownerSlot == ownerSlot) _closeMysticWorld(env);
    }
  }

  /// The caster is gone and its world begins to close: heard once, on the
  /// first transition, and only for a world that had visibly opened. A
  /// recast replacing a world ([_pushMysticEnvironment]) closes it silently.
  void _closeMysticWorld(_MysticEnvironment env) {
    if (env.closing < 0 && env.envelope > 0.05) {
      onSound?.call(SoundCue.specialMysticClose);
    }
    env.beginClosing();
  }

  /// Per-frame tick for active environment overlays — decays life
  /// and spawns ambient particles (gated so each element only spawns
  /// every ~0.06s no matter how many entries are active).
  void _updateMysticEnvironments(double dt) {
    if (_mysticEnvironments.isEmpty) return;
    for (final env in _mysticEnvironments) {
      env.age += dt;
      // The world holds while its caster is alive and out. A Mystic that dies
      // or gets recalled takes its weather with it — and it closes over a
      // second and a half rather than blinking off, so losing it is something
      // the player watches rather than something that simply stops.
      final owner = activeCompanions[env.ownerSlot];
      final standing = owner != null && !owner.isDead;
      if (!standing) _closeMysticWorld(env);
      if (env.closing >= 0) env.closing = max(0.0, env.closing - dt);
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
    final cx = camX;
    final cy = camY;
    final x = cx + _rng.nextDouble() * vw;
    final y = cy + _rng.nextDouble() * vh;
    final viewH = vh; // local alias used by downward-falling cases
    final ec = mysticAtmosphereColors[element] ?? elementColor(element);
    switch (element) {
      case 'Fire':
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
      case 'Lava':
        // Lava does not float. Fire's embers rise because they are light;
        // molten rock is heavy, so it lobs up and falls back — a spatter,
        // not a drift. Sharing Fire's motion made the two the same weather
        // in two oranges, and they are the pair most in need of telling
        // apart.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: (_rng.nextDouble() - 0.5) * 46,
            // Thrown upward, but slow and heavy, and the pool's drag lets it
            // sag back down over its life.
            vy: -14 - _rng.nextDouble() * 16,
            size: 2.2 + _rng.nextDouble() * 2.0,
            life: 1.1 + _rng.nextDouble() * 0.6,
            color: _rng.nextBool()
                ? const Color(0xFFFF7A1E)
                : const Color(0xFFC23A12),
          ),
        );
        break;
      case 'Steam':
        // Steam RISES. It was grouped with frost and rain and made to fall,
        // which is simply the wrong way up for the element — and it was the
        // third member of a trio that already shared one motion.
        _vfx.add(
          _VfxParticle(
            x: x,
            // Enters from below, so the screen fills with vapour climbing.
            y: y + viewH * 0.35,
            vx: (_rng.nextDouble() - 0.5) * 26,
            vy: -34 - _rng.nextDouble() * 26,
            // Fat and soft: mist, not droplets.
            size: 2.6 + _rng.nextDouble() * 2.4,
            life: 1.3 + _rng.nextDouble() * 0.7,
            color: Color.lerp(ec, const Color(0xFFFFFFFF), 0.62)!,
          ),
        );
        break;
      case 'Ice':
        // Frost falls slowly and almost straight — crystalline, weightless.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y - viewH * 0.4,
            vx: (_rng.nextDouble() - 0.5) * 8,
            vy: 34 + _rng.nextDouble() * 24,
            size: 1.1 + _rng.nextDouble() * 0.9,
            life: 1.4 + _rng.nextDouble() * 0.7,
            color: const Color(0xFFEFFFFF),
          ),
        );
        break;
      case 'Water':
        // Rain falls fast and hard, and slants. Separated from frost so the
        // two cold storms are not one storm in two blues.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y - viewH * 0.4,
            vx: 18 + _rng.nextDouble() * 22,
            vy: 96 + _rng.nextDouble() * 70,
            size: 1.0 + _rng.nextDouble() * 0.8,
            life: 0.7 + _rng.nextDouble() * 0.4,
            color: Color.lerp(ec, const Color(0xFFFFFFFF), 0.45)!,
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
        // Dry stone: small, fast, and it drops almost straight.
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y - viewH * 0.3,
            vx: (_rng.nextDouble() - 0.5) * 14,
            vy: 96 + _rng.nextDouble() * 54,
            size: 1.3 + _rng.nextDouble() * 1.1,
            life: 0.65 + _rng.nextDouble() * 0.35,
            color: Color.lerp(ec, const Color(0xFF2A1A0A), 0.45)!,
          ),
        );
        break;
      case 'Mud':
        // Mud does not FALL. Earth's world rains stone from above and Mud was
        // doing the same thing in a wetter brown, which is both the wrong
        // physics and the pair most needing to be told apart. A mire churns:
        // it wells up off the floor, rises a little, and sags back.
        final churn = _rng.nextDouble() * 2 * pi;
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: cos(churn) * (10 + _rng.nextDouble() * 18),
            // Barely lifts — heavy, wet, and the pool's drag drops it back.
            vy: -8 - _rng.nextDouble() * 14,
            size: 2.8 + _rng.nextDouble() * 2.6,
            life: 1.2 + _rng.nextDouble() * 0.7,
            color: Color.lerp(ec, const Color(0xFF3A2410), 0.55)!,
          ),
        );
        break;
      case 'Dust':
        // Grit hanging in the air: slow, gritty, going nowhere in particular.
        // Two per tick and larger than the rest, because a dust world's whole
        // claim is that the air is FULL — one small mote at a time read as a
        // clean sky with a speck in it.
        for (var d = 0; d < 2; d++) {
          if (_vfx.length >= 150) break;
          final dustAngle = _rng.nextDouble() * 2 * pi;
          _vfx.add(
            _VfxParticle(
              x: x + (_rng.nextDouble() - 0.5) * 90,
              y: y + (_rng.nextDouble() - 0.5) * 90,
              vx: cos(dustAngle) * 16,
              vy: sin(dustAngle) * 16,
              size: 1.4 + _rng.nextDouble() * 1.8,
              life: 1.4 + _rng.nextDouble() * 0.8,
              color: Color.lerp(ec, const Color(0xFF8A6A3A), 0.35)!,
            ),
          );
        }
        break;
      case 'Air':
        // Clean fast streaks sweeping ACROSS the field in one direction —
        // wind has a bearing. Sharing Dust's aimless swirl made the windy
        // world and the gritty one the same haze.
        final gust = stats.timeElapsed * 0.35;
        final bearing = gust - gust.floorToDouble() < 0.5 ? -0.35 : 0.35;
        _vfx.add(
          _VfxParticle(
            x: x,
            y: y,
            vx: 92 + _rng.nextDouble() * 60,
            vy: bearing * (30 + _rng.nextDouble() * 40),
            size: 0.9 + _rng.nextDouble() * 0.8,
            life: 0.5 + _rng.nextDouble() * 0.3,
            color: Color.lerp(ec, const Color(0xFFFFFFFF), 0.70)!,
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
            color: ec,
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
            color: const Color(0xFF9CAE84),
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
            color: const Color(0xFF9684AC),
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
            color: ec,
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
            color: const Color(0xFFAD5261),
          ),
        );
        break;
    }
  }

  /// Atmospheric patterns sit behind combat and follow the actual camera,
  /// including manual pan. Multiple worlds share an opacity/detail budget.
  void _renderMysticEnvironmentOverlay(Canvas canvas) {
    _renderMysticSkyFlash(canvas);
    if (_mysticEnvironments.isEmpty) return;
    final viewport = Rect.fromLTWH(
      camX,
      camY,
      size.x / _currentZoom,
      size.y / _currentZoom,
    );
    final weight = _mysticEnvironments.fold<double>(
      0,
      (sum, env) => sum + env.envelope,
    );
    final mix = 1 / max(1.0, weight);
    for (final env in _mysticEnvironments) {
      drawMysticWorldAmbience(
        canvas: canvas,
        viewport: viewport,
        element: env.element,
        time: stats.timeElapsed,
        seed: env.ownerSlot,
        strength: env.envelope * mix,
        reducedDetail: _reduceSecondaryGlows || weight > 2,
      );
    }
  }

  /// A strike lighting the ground round it for an instant; the dawn warming
  /// the core it just healed.
  ///
  /// A bolt is a thin figure on a big dark screen, and on a busy field it was
  /// easy to miss — the light is what makes a strike an event. It used to
  /// wash the whole viewport (and the dawn's wash was lightning blue); now it
  /// is a local soft glow in the element's material: a wide faint pool and a
  /// small brighter heart, no white, gone in about a third of a second.
  void _renderMysticSkyFlash(Canvas canvas) {
    if (_mysticSkyFlash <= 0.01) return;
    final f = _mysticSkyFlash.clamp(0.0, 1.0);
    final strength = f * f;
    final element = _mysticSkyFlashElement;
    final dawn = element == 'Light';
    final m = vfxMaterial(element);
    final r = dawn ? 280.0 : 190.0;
    final tint = Color.lerp(m.light, elementColor(element), dawn ? 0.3 : 0.2)!;
    // Spreads a little as it fades, the way a flash's light settles.
    vfxSpill(
      canvas,
      _mysticSkyFlashAt,
      r * (1.15 - 0.15 * f),
      tint,
      0.30 * strength,
    );
    vfxSpill(canvas, _mysticSkyFlashAt, r * 0.36, m.glint, 0.2 * strength);
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
  static const double _kinChargeTime = KinLaser.chargeTime;
  void _tickKinChargedAuto(
    CosmicSurvivalCompanion comp,
    int slotIndex,
    double fireAngle,
    Offset attackTarget,
    double distToTarget,
    double dt, {
    double bossBonus = 0,
    SurvivalBoss? targetBoss,
  }) {
    // Charging phase — tick up, lock movement (zero steering).
    if (comp.kinAutoChargeTimer > 0) {
      final was = comp.kinAutoChargeTimer;
      comp.kinAutoChargeTimer += dt;
      // The charge's swell, timed to lead into the release by 0.6 s.
      const swellAt = _kinChargeTime - 0.6;
      if (was < swellAt && comp.kinAutoChargeTimer >= swellAt) {
        onSound?.call(SoundCue.basicKinCharge);
      }
      // Lock movement during charge.
      comp.steeringVelocity = Offset.zero;
      if (comp.kinAutoChargeTimer >= _kinChargeTime) {
        // Pick a live target at fire time so moving enemies still
        // get hit. Priority: locked enemy if still alive → nearest
        // enemy → cached snapshot → attackTarget fallback.
        Offset fireAt;
        final locked = comp.kinAutoChargeEnemy;
        final lockedBoss = comp.kinAutoChargeBoss;
        if (lockedBoss != null && !lockedBoss.isDead) {
          fireAt = lockedBoss.position;
        } else if (locked != null && !locked.isDead) {
          fireAt = locked.position;
        } else {
          final nearest = _nearestEnemyTo(
            comp.position,
            comp.attackRange + KinLaser.fallbackExtra,
          );
          fireAt =
              nearest?.position ?? comp.kinAutoChargeTarget ?? attackTarget;
        }
        _fireKinLaserBeam(comp, slotIndex, fireAt);
        comp.kinAutoChargeTimer = 0;
        comp.kinAutoChargeTarget = null;
        comp.kinAutoChargeEnemy = null;
        comp.kinAutoChargeBoss = null;
        comp.basicCooldown = comp.effectiveBasicCooldown;
      }
      return;
    }
    // Ready to start a charge? A boss's hitbox counts toward the range, as it
    // does for every other family; without it a Kin locked on a boss just
    // short of its range neither lasered nor cast (2026-10-20 audit).
    if (comp.basicCooldown <= 0 &&
        distToTarget <= comp.attackRange + bossBonus) {
      comp.kinAutoChargeTimer = 0.001; // marker: charge has started
      comp.kinAutoChargeTarget = attackTarget;
      if (targetBoss != null && !targetBoss.isDead) {
        // On a boss: the laser goes at the boss, and whatever stands on the
        // line on the way is hit as it passes.
        comp.kinAutoChargeBoss = targetBoss;
        comp.kinAutoChargeEnemy = null;
      } else {
        comp.kinAutoChargeBoss = null;
        // Lock onto the nearest enemy to the cast target so the laser
        // tracks them through the charge.
        comp.kinAutoChargeEnemy =
            _nearestEnemyTo(attackTarget, KinLaser.lockRadius) ??
            _nearestEnemyTo(
              comp.position,
              comp.attackRange + KinLaser.fallbackExtra,
            );
      }
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
    // A kin's basic is this charged line, so its cue belongs here, at the
    // release, as the dungeon plays it — the charge itself is silent. It
    // went through no appender, so it was the one basic with no sound.
    onSound?.call(SoundCue.basicKin);
    final norm = dir / dist;
    // Laser length: enough to reach the target plus some overshoot
    // so distant enemies still get hit; capped to keep visual sane.
    final beamLength = _kinLaserLengthFor(slotIndex, dist);
    final beamEnd = comp.position + norm * beamLength;
    // Crossfire: the same line, fired straight back through the Kin, so one
    // charge covers the whole width of the field instead of half of it.
    final crossfire =
        _isMasteryKin(slotIndex) &&
        mastery.hasNode(slotIndex, KinNodes.crossfire);
    final backEnd = comp.position - norm * beamLength;

    // Damage scaling — kin physAtk × 4.0. With the 1.5s charge + the
    // standard cooldown the cadence is ~2× slower than other families,
    // so 4× per-shot keeps single-target DPS roughly even and lets
    // the line-pierce + long range be the upside.
    final dmg =
        comp.physAtk.toDouble() *
        KinLaser.damageScale *
        (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
        comp.damageAmp;
    const lateral = KinLaser.lateral;

    // Kin's charged beam IS its basic attack, so it opens a cast like any
    // other. One "projectile": a body the line touches has taken everything
    // this cast had for it, which is what a full volley hit means here.
    final castId = mastery.beginCast(
      slotIndex: slotIndex,
      family: creatureFamilyFromStorage(comp.member.family),
      element: comp.member.element,
      kind: MasteryCastKind.basic,
      projectileCount: 1,
    );
    // Grounding: the Kin's element on every body the line crosses. The laser
    // carried no element at all, so the node did nothing (2026-10-20 audit);
    // it now lands the element's payload, the one every mastery node shares,
    // on each body and boss the shot reaches.
    final grounding =
        _isMasteryKin(slotIndex) &&
        mastery.hasNode(slotIndex, KinNodes.grounding);

    // Hit every enemy near the beam segment.
    final scanRadius = max(beamLength, 120.0);
    _visitEnemiesNear(comp.position, scanRadius, (enemy) {
      if (enemy.isDead) return false;
      final d = _distanceToSegment(enemy.position, comp.position, beamEnd);
      final back = crossfire
          ? _distanceToSegment(enemy.position, comp.position, backEnd)
          : double.infinity;
      final onLine = d <= enemy.radius + lateral;
      final onBackLine = back <= enemy.radius + lateral;
      if (onLine || onBackLine) {
        // Deep Line: the far end of the line hits hardest, which is what
        // makes the length worth buying rather than just looking longer.
        final along = (enemy.position - comp.position).distance;
        final deep = _isMasteryKin(slotIndex)
            ? kinDeepLineMultiplier(
                hasNode: (id) => mastery.hasNode(slotIndex, id),
                along: along,
                length: beamLength,
              )
            : 1.0;
        // Kin's charged beam IS its basic attack, so it tithes too.
        final hpBefore = enemy.hp;
        _damageEnemy(
          enemy,
          dmg * deep * (onLine ? 1.0 : KinTuning.crossfireStrength),
          sourceSlotIndex: slotIndex,
          autoAttack: true,
          masteryCastId: castId,
          masteryUplift: kinUpliftFraction(deep),
        );
        _spawnHitSpark(enemy.position, elementColor(comp.member.element));
        if (grounding && !enemy.isDead) {
          triggerElementalPayload(
            slotIndex: slotIndex,
            effectId: KinNodes.grounding,
            enemy: enemy,
            strength: KinTuning.groundingStrength,
            triggeringDamage: hpBefore - enemy.hp,
          );
        }
      }
      return false;
    });

    // Bosses on the line. The scan above walks the enemy grid, which holds
    // no bosses, so the laser used to pass through every boss it was fired at
    // (2026-10-20 audit). Same reach and the same Deep Line as for a body.
    if (anyBossAlive) {
      for (final boss in allLivingBosses) {
        if (boss.isSpawning) continue;
        final d = _distanceToSegment(boss.position, comp.position, beamEnd);
        final back = crossfire
            ? _distanceToSegment(boss.position, comp.position, backEnd)
            : double.infinity;
        final onLine = d <= boss.radius + lateral;
        if (!onLine && back > boss.radius + lateral) continue;
        final along = (boss.position - comp.position).distance;
        final deep = _isMasteryKin(slotIndex)
            ? kinDeepLineMultiplier(
                hasNode: (id) => mastery.hasNode(slotIndex, id),
                along: along,
                length: beamLength,
              )
            : 1.0;
        final bossHpBefore = boss.hp;
        damageBoss(
          dmg * deep * (onLine ? 1.0 : KinTuning.crossfireStrength),
          attackElement: comp.member.element,
          sourceSlotIndex: slotIndex,
          target: boss,
          autoAttack: true,
          masteryCastId: castId,
          masteryUplift: kinUpliftFraction(deep),
        );
        _spawnHitSpark(boss.position, elementColor(comp.member.element));
        if (grounding && !boss.isDead) {
          triggerElementalPayload(
            slotIndex: slotIndex,
            effectId: KinNodes.grounding,
            boss: boss,
            strength: KinTuning.groundingStrength,
            triggeringDamage: bossHpBefore - boss.hp,
          );
        }
      }
    }

    // Conduction: the same line, read for allies instead of enemies.
    _applyKinConduction(slotIndex, comp, dmg, comp.position, beamEnd);
    if (crossfire) {
      _applyKinConduction(slotIndex, comp, dmg, comp.position, backEnd);
    }

    // Push the beam visual into the transient list.
    pushKinLaserBeam(
      _kinLaserBeams,
      KinLaserBeam(
        origin: comp.position,
        end: beamEnd,
        color: elementColor(comp.member.element),
      ),
    );
    if (crossfire) {
      pushKinLaserBeam(
        _kinLaserBeams,
        KinLaserBeam(
          origin: comp.position,
          end: backEnd,
          color: elementColor(comp.member.element),
        ),
      );
    }
  }

  /// Fire Kin's phoenix: the orb has just died and this Kin has not yet
  /// spent its save. Restores the orb and unlocks the reborn flame.
  void _kinFirePhoenixSave(int slotIndex, CosmicSurvivalCompanion comp) {
    if (comp.kinFireOrbitalFlameActive) return;
    // Trigger the save — restore orb to ~25% and unlock the
    // orbital flame for the remainder of the duration.
    orb.currentHp = orb.maxHp * KinSupport.phoenixRestoreFraction;
    onSound?.call(SoundCue.specialKinPhoenix);
    // Phoenix burst feedback
    _spawnHitSpark(orb.position, KinSupport.phoenixEmber);
    _spawnHitSpark(orb.position, KinSupport.phoenixFlash);
    emitKinPhoenixBurst(
      at: orb.position,
      rng: _rng,
      hasRoom: _kinVfxHasRoom,
      emit: _emitVfxParticle,
    );
    // Activate the orbital flame PERMANENTLY (boolean flag,
    // no timer decrement). Once unlocked it stays on for the
    // rest of the fire kin's life.
    comp.kinFireOrbitalFlameActive = true;
    comp.kinFirePhoenixGuardTimer = 0;

    // Rise-from-the-ashes buff, rolled from this kin's own stats and
    // kept for the rest of the run. Each stat buys the thing the family
    // contract says it owns: Beauty the reach of the flame, Speed the
    // rate it ticks and the kin's own attack rate, Strength and
    // Intelligence its damage (already blended into abilityAtk).
    final rebirth = KinSupport.fireRebirth(
      beauty: _effectiveBeauty(slotIndex),
      speed: _effectiveSpeed(slotIndex),
    );
    comp.kinFireFlameRadius = rebirth.radius;
    comp.kinFireFlameInterval = rebirth.interval;
    comp.kinFireRebirthHaste = rebirth.haste;
    comp.kinFireRebirthDamageAmp = rebirth.damageAmp;
    comp.kinFireFlameTimer = 0;
  }

  /// The phoenix's second look, just before the run would end.
  ///
  /// The Kin tick reads the orb partway through the frame, but bosses, boss
  /// and enemy rounds, artillery shells and outbreaks all resolve after it,
  /// so an orb they killed reached the game-over check unseen and the save
  /// never fired on a boss wave or against shooters (2026-10-20 audit).
  void _catchOrbDeathWithPhoenix() {
    for (final entry in _kinSupportSources) {
      final comp = entry.value;
      if (comp.isDead && !_unbrokenKin.containsKey(entry.key)) continue;
      if (comp.member.family.toLowerCase() != 'kin') continue;
      if (comp.member.element != 'Fire') continue;
      if (comp.kinFireOrbitalFlameActive) continue;
      _kinFirePhoenixSave(entry.key, comp);
      return;
    }
  }

  // ── Kin per-frame support tick ────────────────────────────────
  // Drives every kin support-path timer + damage-reactive logic in
  // one consolidated pass.
  // Snapshot of ship HP at the start of the previous tick — used to
  // compute per-frame damage for reactive kin (Lava plate / Steam
  // boiler / Blood pact).
  double _kinPrevShipHp = -1;
  // Damage that reached the orb (its shield or its health) since the kin
  // tick last looked. The reactive kin read this the way they read ship
  // and companion damage: the orb is the health bar that actually loses.
  double _kinOrbDamageThisFrame = 0;

  void _updateKinSupportTick(double dt) {
    // Decay any active laser-beam visuals.
    updateKinLaserBeams(_kinLaserBeams, dt);

    // Track ship damage this frame (for Lava plate / Steam boiler /
    // Blood pact). Uses delta vs last frame.
    final shipDelta = (_kinPrevShipHp >= 0 && !ship.isDead)
        ? max(0.0, _kinPrevShipHp - ship.currentHp)
        : 0.0;
    _kinPrevShipHp = ship.currentHp.toDouble();
    final orbDelta = _kinOrbDamageThisFrame;
    _kinOrbDamageThisFrame = 0;

    // The boilers write this afresh below; one that has gone cold or left
    // the field simply stops writing it.
    for (final comp in activeCompanions.values) {
      comp.kinSteamHasteMultiplier = 1.0;
    }

    // Tick all kin support timers + react to damage.
    // Unbroken: a downed Kin's support runs its course, so the orphans are
    // walked alongside the living. They are pruned as their timers expire.
    if (_unbrokenKin.isNotEmpty) {
      _unbrokenKin.removeWhere((_, comp) => !_kinHasRunningSupport(comp));
    }
    for (final entry in _kinSupportSources.toList(growable: false)) {
      final comp = entry.value;
      if (comp.isDead && !_unbrokenKin.containsKey(entry.key)) continue;

      // Per-companion damage delta this frame.
      final compDelta = (comp.kinPrevHp > 0)
          ? max(0, comp.kinPrevHp - comp.currentHp).toDouble()
          : 0.0;
      comp.kinPrevHp = comp.currentHp;
      // Damage to the alchemons themselves, and to everything the kin
      // protects. Ordinary bodies go for the orb three times in four, so a
      // kin that only reacted to ship and companion damage sat idle.
      final bodyDamage = shipDelta + compDelta;
      final teamDamage = bodyDamage + orbDelta;

      final isKin = comp.member.family.toLowerCase() == 'kin';
      if (!isKin) continue;
      final element = comp.member.element;

      // ── Fire phoenix guard (passive) ───────────
      // Fire kin no longer needs a cast — by being deployed it
      // intercepts orb death and triggers the phoenix save +
      // post-revive permanent orbital flame.
      if (element == 'Fire' && orb.currentHp <= 0) {
        _kinFirePhoenixSave(entry.key, comp);
      }
      // ── Fire orbital flame (permanent once active) ─────
      if (comp.kinFireOrbitalFlameActive) {
        // The reborn kin keeps its buff for good. It is read off the kin's
        // own rebirth fields (CosmicSurvivalCompanion.damageAmp, basicHaste),
        // so the shared windows other sources open still close on time.
        // Burn enemies near the fire kin. Its own tick gate, because this used
        // to borrow the Steam boiler's decay timer.
        comp.kinFireFlameTimer -= dt;
        if (comp.kinFireFlameTimer <= 0) {
          comp.kinFireFlameTimer = comp.kinFireFlameInterval;
          _damageEnemiesNear(
            comp.position,
            comp.kinFireFlameRadius,
            KinSupport.fireFlameDamage(comp.abilityAtk),
            sourceSlotIndex: entry.key,
            attackElement: element,
          );
        }
      }

      // ── Lava plate ─────────────────────────────
      if (comp.kinLavaPlateTimer > 0) {
        comp.kinLavaPlateTimer = max(0, comp.kinLavaPlateTimer - dt);
        if (element == 'Lava' && teamDamage > 0) {
          // Splash lava at whatever struck: the body pressing the orb when
          // the orb was hit, otherwise the one nearest the ship. Capped so a
          // crowd breaking on the orb pays a steady price, not one frame of
          // everything.
          final searchFrom = orbDelta > 0 ? orb.position : ship.position;
          final searchRadius = orbDelta > 0
              ? KinSupport.lavaSearchOrb
              : KinSupport.lavaSearchShip;
          // On a boss wave the thing pressing the orb is often the boss
          // itself, with nothing smaller near it to splash.
          final at =
              _nearestEnemyTo(searchFrom, searchRadius)?.position ??
              _nearestBossTo(searchFrom, searchRadius)?.position;
          if (at != null) {
            _damageEnemiesNear(
              at,
              KinSupport.lavaSplashRadius,
              KinSupport.lavaSplashDamage(teamDamage, comp.abilityAtk),
              sourceSlotIndex: entry.key,
              attackElement: element,
            );
            _spawnHitSpark(at, KinSupport.lavaSplashColor);
          }
        }
      }

      // ── Steam boiler ───────────────────────────
      if (comp.kinSteamBoilerTimer > 0 && element == 'Steam') {
        comp.kinSteamBoilerTimer = max(0, comp.kinSteamBoilerTimer - dt);
        // Convert damage taken to stacks: 8% of the ship's health per
        // stack for ship and companion hits, 1.5% of the orb's for hits on
        // the orb. Carried across frames so chaff chipping the orb counts.
        final boiler = KinSupport.steamStep(
          stacks: comp.kinSteamBoilerStacks,
          carry: comp.kinSteamStackCarry,
          decayTimer: comp.kinSteamStackDecayTimer,
          gain: teamDamage > 0
              ? bodyDamage / KinSupport.steamBodyUnit(ship.maxHp) +
                    orbDelta / KinSupport.steamObjectiveUnit(orb.maxHp)
              : 0,
          dt: dt,
        );
        comp.kinSteamBoilerStacks = boiler.stacks;
        comp.kinSteamStackCarry = boiler.carry;
        comp.kinSteamStackDecayTimer = boiler.decayTimer;
        // Apply the AS buff to every active companion. Beauty
        // scales per-stack potency (5% base → 7% at high stat), and Deep
        // Reserves deepens it by its power.
        final boiled = KinSupport.steamHasteMultiplier(
          comp.kinSteamBoilerStacks,
          _effectiveBeauty(entry.key),
        );
        final mult =
            1 - (1 - boiled) * _kinBenedictionFor(entry.key).power;
        for (final other in activeCompanions.values) {
          other.kinSteamHasteMultiplier = min(
            other.kinSteamHasteMultiplier,
            mult,
          );
        }
      }

      // ── Ice charge → targeted radial release ───────
      if (comp.kinIceChargeTimer > 0) {
        comp.kinIceChargeTimer = max(0, comp.kinIceChargeTimer - dt);
        // Lock movement during charge.
        if (element == 'Ice') comp.steeringVelocity = Offset.zero;
        if (comp.kinIceChargeTimer <= 0 && element == 'Ice') {
          onSound?.call(SoundCue.specialKinIceRelease);
          // Release! Scale radius with Beauty — up to ~global at 5.0.
          final radius = KinSupport.iceReleaseRadius(
            _effectiveBeauty(entry.key),
          );
          final slowDuration = KinSupport.iceSlowDuration(
            _effectiveIntelligence(entry.key),
          );
          final hitTargets = <Offset>[];
          _visitEnemiesNear(comp.position, radius, (e) {
            if (e.isDead) return false;
            e.slowTimer = max(e.slowTimer, slowDuration);
            e.slowMultiplier = min(
              e.slowMultiplier,
              KinSupport.iceSlowMultiplier,
            );
            hitTargets.add(e.position);
            return false;
          });
          // Particles shoot TOWARD each slowed enemy (not radial) so the
          // player sees where the freeze went, then a light radial sheen so
          // the cast still reads even when no enemies are in range.
          emitKinIceRelease(
            origin: comp.position,
            targets: hitTargets,
            rng: _rng,
            hasRoom: _kinVfxHasRoom,
            emit: _emitVfxParticle,
            spark: _spawnHitSpark,
            iceColor: elementColor('Ice'),
          );
          _spawnHitSpark(comp.position, elementColor('Ice'));
          // The release seen at its real reach (the particles above only
          // travel a fraction of it).
          pushLetFx(
            _letFx,
            LetFx.frostFront(position: comp.position, radius: radius),
          );
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
        if (element == 'Blood' && bodyDamage > 0) {
          // Split 60% of the damage the alchemons took as healing across
          // the living ones — ship included. What they took for the orb
          // (see _kinBloodPactShareOrbDamage) is part of it.
          final healPool = bodyDamage * KinSupport.bloodHealShare;
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
            comp.kinSteamStackDecayTimer = KinSupport.mudPatchInterval;
            _appendCompanionProjectile(
              KinSupport.mudPatch(ship.position, entry.key),
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
    final wisp = KinSupport.findSpiritWisp(companionProjectiles, slot);
    if (wisp == null) return;
    // T3's turret attack and T4's heal are on the design board only; the
    // tier function sets the form and T2's taunt.
    final tierBefore = wisp.effectCount;
    KinSupport.applySpiritWispTier(
      wisp,
      comp.kinSpiritWispKills,
      power: comp.abilityAtk,
    );
    if (wisp.effectCount > tierBefore) {
      onSound?.call(SoundCue.specialKinWispTier);
    }
  }

  void _spawnOrRefreshKinSpiritWisp(CosmicSurvivalCompanion comp) {
    // Look for existing wisp tied to this slot; refresh life if found so
    // the wisp persists between casts.
    final existing = KinSupport.findSpiritWisp(
      companionProjectiles,
      comp.slotIndex,
    );
    if (existing != null) {
      existing.life = max(existing.life, KinSupport.spiritWispLife);
      existing.turretDamage = KinSupport.spiritWispShotDamage(comp.abilityAtk);
      return;
    }
    // Spawn a new wisp orbiting the spirit kin. Tier == 1 at spawn;
    // tier-up happens on the spirit kin's auto-kills.
    comp.kinSpiritWispKills = 0;
    _appendCompanionProjectile(
      KinSupport.spiritWisp(
        comp.position,
        comp.slotIndex,
        power: comp.abilityAtk,
      ),
    );
  }

  /// The Mask elements whose placement follows the allies, not the threat.
  static const Set<String> _kMaskAlliedPlacements = {
    'Dust',
    'Earth',
    'Ice',
    'Spirit',
  };

  /// Counts the orb's approaches for a Mask cast ([MaskApproachLane]).
  final MaskApproachLane _maskLane = MaskApproachLane();

  /// How much more a boss counts toward the lane it walks than one body.
  static const double _maskLaneBossWeight = 12.0;

  /// The spot on the orb's busiest approach a Mask field goes across, or
  /// [target]'s bearing at that distance when nothing is near. Once a cast,
  /// through the enemy grid.
  Offset _maskApproachAim(Offset target) {
    final lane = _maskLane..reset();
    final orbAt = orb.position;
    _visitEnemiesNear(orbAt, kMaskApproachScan, (enemy) {
      lane.add(enemy.position - orbAt);
      return false;
    });
    for (final boss in allLivingBosses) {
      if (boss.isSpawning) continue;
      lane.add(boss.position - orbAt, weight: _maskLaneBossWeight);
    }
    return lane.aim(orbAt) ?? maskApproachFallback(orbAt, target);
  }

  /// Both the initial cast and Double Cast echo use the same lifecycle.
  bool _activateMaskPlacements(
    int slotIndex,
    List<Projectile> placements, {
    required Offset target,
  }) {
    if (placements.isEmpty || placements.first.abilityFamily != 'mask') {
      return false;
    }
    final comp = activeCompanions[slotIndex];
    final allies = <({Offset position, double health})>[
      if (!ship.isDead)
        (position: ship.position, health: ship.currentHp / max(1, ship.maxHp)),
      for (final ally in activeCompanions.values)
        if (!ally.isDead)
          (
            position: ally.position,
            health: ally.currentHp / max(1, ally.maxHp),
          ),
    ]..sort((a, b) => a.health.compareTo(b.health));
    placeMaskTraps(
      traps: placements,
      caster: comp?.position ?? ship.position,
      ship: ship.position,
      allies: allies.map((a) => a.position).toList(),
      // The gatekeeper: the field goes across the orb's busiest approach,
      // not at the body the Mask happened to be shooting. Earth, Ice and
      // Spirit place by the allies and Dust rides them, so they skip it.
      target: _kMaskAlliedPlacements.contains(placements.first.element)
          ? target
          : _maskApproachAim(target),
      guard: orb.position,
      arenaCenter: orb.position,
      arenaRadius: _arenaRadius,
    );
    switch (placements.first.element) {
      case 'Spirit':
        comp?.maskSpiritClearAt = maskSpiritClearThreshold(placements.length);
        for (final wisp in placements) {
          if (_spiritWisps.length >= kMaskSpiritWispCap) break;
          _spiritWisps.add(
            MaskSpiritWisp.fromTrap(
              wisp,
              sourceSlotIndex: slotIndex,
              bobPhase: _rng.nextDouble() * pi * 2,
              castSize: placements.length,
            ),
          );
        }
        return true;
      case 'Plant':
        _feedOrSpawnMaskPlantVine(slotIndex, placements);
        return true;
      case 'Dust':
        _spawnMaskDustShields(slotIndex, placements);
        return true;
    }
    return false;
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
        refreshMaskDustShield(prev, seed);
        return;
      }
      _appendCompanionProjectile(
        maskDustShield(
          seed,
          sourceSlotIndex: slotIndex,
          attachedToSlot: targetSlot,
          position: position,
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
    _appendCompanionProjectile(maskFirePool(parent, at));
  }

  void resolveAbilityKill(Projectile projectile, CosmicSurvivalEnemy enemy) {
    if (projectile.abilityFamily == 'let') {
      _resolveLetMeteorImpactAftermath(
        projectile,
        enemy.position,
        primary: enemy,
        killed: true,
      );
      return;
    }
    if (!PipRicochet.paysKillEffect(projectile)) return;
    _applyAbilityEffectToEnemy(
      projectile.killEffect,
      enemy,
      enemy.position,
      projectile.effectPower,
      projectile.effectRadius,
      projectile.effectDuration,
      sourceSlotIndex: projectile.sourceSlotIndex,
      element: projectile.element,
      family: projectile.abilityFamily,
    );
  }

  /// A few sparks shed off the meteor on the way down, so the descent has
  /// something moving in it before the impact does the talking. Bounded and
  /// skipped entirely when the particle pool is busy.
  void _spawnLetDescentEmbers(Projectile p) {
    if (_reduceAmbientVfx || _vfx.length >= 120) return;
    // Only once the meteor is most of the way down and actually on screen —
    // shedding embers from off-screen is pure cost.
    if (p.skyfallProgress < 0.35) return;
    // A Deadfall auto-attack falls every second or so; it sheds a fraction of
    // what a special does, so a Let at full haste does not fill the pool.
    if (p.letDeadfall && _rng.nextDouble() > 0.35) return;
    if (!_isOnScreen(p.position, 80)) return;
    final ec = elementColor(p.element ?? 'Fire');
    final dir = Offset(cos(p.angle), sin(p.angle));
    final a = p.angle + pi + (_rng.nextDouble() - 0.5) * 0.8;
    final spd = 30 + _rng.nextDouble() * 70;
    _vfx.add(
      _VfxParticle(
        x: p.position.dx - dir.dx * 6,
        y: p.position.dy - dir.dy * 6,
        vx: cos(a) * spd,
        vy: sin(a) * spd,
        size: 1.6 + _rng.nextDouble() * 2.0,
        life: 0.22 + _rng.nextDouble() * 0.26,
        color: ec.withValues(alpha: 0.85),
      ),
    );
  }

  /// The crater and the sound of a meteor arriving. The crater throws its
  /// own element's debris (let_vfx.dart); the generic particle burst that used
  /// to ride on top of it made all seventeen landings look alike.
  void _spawnLetSkyfallImpactVfx(Projectile p, Offset centre, double blast) {
    onSound?.call(
      SoundCue.forLetImpact(p.element ?? '', barrageChild: p.effectStacks >= 1),
    );
    pushLetSkyfallImpact(
      _letSkyfallImpacts,
      LetSkyfallImpact(
        position: centre,
        color: elementColor(p.element ?? 'Fire'),
        element: p.element,
        radius: blast,
      ),
    );
  }

  /// The landing. Everything a Let does happens here.
  ///
  /// The old meteor was consumed by the first body it flew into, so a cast
  /// that reached nobody did nothing at all. A meteor that falls always
  /// arrives: it cracks the ground it lands on, catches whatever is standing
  /// in the crater, and leaves the element's mark either way.
  void _detonateLetSkyfall(Projectile p) {
    final centre = p.skyfallImpact;
    final blast = letSkyfallBlastRadius(p);
    _spawnLetSkyfallImpactVfx(p, centre, blast);

    // The body nearest the point of impact takes the meteor itself; it is the
    // one the element's on-collide behaviour resolves against.
    CosmicSurvivalEnemy? primary;
    double bestSq = blast * blast;
    _visitEnemiesNear(centre, blast, (enemy) {
      if (enemy.isDead) return false;
      final dSq = _distanceSquared(enemy.position, centre);
      if (dSq < bestSq) {
        bestSq = dSq;
        primary = enemy;
      }
      return false;
    });

    // A boss standing in the crater eats the impact too — it just is not
    // eligible to be the "primary" body, since the per-element contact
    // switch is written against ordinary enemies.
    for (final boss in allLivingBosses) {
      if (_distanceSquared(boss.position, centre) > blast * blast) continue;
      damageBoss(
        p.damage,
        attackElement: p.element,
        sourceSlotIndex: p.sourceSlotIndex,
        target: boss,
      );
    }

    final struck = primary;
    // Everything in the crater is caught at a reduced share — including when
    // the meteor came down on a boss and there is no ordinary "primary" body.
    // Leaving this inside the struck branch was a real loss of power: a Let
    // dropped onto a boss surrounded by adds touched none of them, where the
    // old flat-flying meteor at least clipped whatever it passed through.
    // Snapshot who is standing in the crater before anything detonates, so the
    // kill-gated aftermath can be judged on what the METEOR killed — including
    // bodies finished by the splash rather than by the direct hit. "The meteor
    // killed something" is the design's condition, and the splash is the
    // meteor.
    final inBlast = <CosmicSurvivalEnemy>[];
    _visitEnemiesNear(centre, blast, (enemy) {
      if (enemy.isDead) return false;
      if (_distanceSquared(enemy.position, centre) <= blast * blast) {
        inBlast.add(enemy);
      }
      return false;
    });

    _applyLetSightFromSpecial(p, centre, blast, inBlast);

    _damageEnemiesNear(
      centre,
      blast,
      p.damage * kLetSurvivalCraterShare,
      sourceSlotIndex: p.sourceSlotIndex,
      exclude: struck,
      // Any boss in the crater already took the full impact above.
      includeBosses: false,
    );
    if (struck != null) {
      _damageEnemy(struck, p.damage, sourceSlotIndex: p.sourceSlotIndex);
      final killedInCrater = inBlast.any((enemy) => enemy.isDead);
      // Runs the per-element contact behaviour, and the kill-gated aftermath
      // only if the crater actually claimed someone.
      _resolveLetMeteorHit(p, struck, killed: killedInCrater);
    } else {
      // Nothing underneath it (or only a boss): nothing collided and nothing
      // died, so the kill-gated aftermath does not fire. An earlier version
      // ran it here so a Let on open ground "still left its mark", and it
      // handed a Dark Let landing on empty ground a free bombardment, Fire a
      // free explosion and Light a free healing pool; the rest has to be
      // earned.
      //
      // The ground a meteor leaves where it lands is not a kill effect,
      // though, and the design keeps it "even on empty ground": Dust's pall,
      // Lava's burning ground, Poison's sump and Earth's rubble are laid
      // where it came down, for whatever walks in next. Dropping them too
      // left an empty landing doing nothing at all (2026-10-20 audit).
      final zone = CosmicAbilityRuntime.letContactZone(p.element);
      if (zone != null && CosmicAbilityRuntime.isLetMeteorCore(p)) {
        _spawnLetZone(p, centre, p.element!, zone);
      }
    }

    p.life = 0;
  }

  /// The meteor's per-element contact behaviour, plus — only when it actually
  /// killed — the kill-gated aftermath.
  ///
  /// [killed] used to be ignored entirely: `resolveAbilityHit` took the flag
  /// and the `let` branch returned before ever reading it, so the aftermath
  /// ran on every hit. Eight of the seventeen Lets have their whole identity
  /// in there and every one of them is written "if the meteor kills" — Dark
  /// most consequentially, since it throws five more meteors. Firing those on
  /// a graze rather than a kill was the difference between a finisher and a
  /// damage engine.
  void _resolveLetMeteorHit(
    Projectile projectile,
    CosmicSurvivalEnemy enemy, {
    required bool killed,
  }) {
    final element = projectile.element ?? '';
    // Only the meteor core leaves a persistent elemental pool. The
    // spread secondaries (haboob grains, lances, shards) are piercing /
    // bouncing damage projectiles — letting each of their hits drop a
    // pool stacks dozens of overlapping zones from a single cast.
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    // Contact zones — Dust's pall, Lava's burning ground, Poison's sump,
    // Earth's rubble — come from the shared table.
    final zone = CosmicAbilityRuntime.letContactZone(element);
    if (zone != null && isMeteorCore) {
      _spawnLetZone(projectile, enemy.position, element, zone);
    }
    // The crater has just killed most of what stood in it, so the effects
    // that spread from the impact act out to its rim: on the crater's
    // survivors and the ring just past it (CosmicAbilityRuntime.kLetRimReach).
    final rimCentre = _letImpactCentre(projectile, enemy.position);
    final rim = CosmicAbilityRuntime.letRimReach(projectile);
    switch (element) {
      case 'Poison':
        enemy.slowTimer = max(enemy.slowTimer, 2.2);
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.72);
        enemy.attackCooldown = max(enemy.attackCooldown, 1.4);
        _damageEnemy(
          enemy,
          projectile.damage * 0.20,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        break;
      case 'Earth':
        _healLowestAllyOrShip(
          projectile.damage * 0.26,
          sourceSlot: projectile.sourceSlotIndex,
        );
        // Out to the rim of the widest crater a Let opens, at a smaller
        // share than the 0.38 it took when it stayed inside (2026-10-20).
        _damageEnemiesNear(
          rimCentre,
          max(rim, max(150, projectile.effectRadius)),
          projectile.damage * 0.24,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
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
          // The execute has to be seen, or a one-shot reads as an ordinary
          // big hit.
          if (isMeteorCore) {
            pushLetFx(
              _letFx,
              LetFx.soul(position: enemy.position, bodyRadius: enemy.radius),
            );
          }
        } else if (!enemy.isDead) {
          _damageEnemy(
            enemy,
            projectile.damage * 0.35,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
        }
        // Every body still standing out to the rim rolls the same chance.
        _executeLetSpiritRim(projectile, enemy, rimCentre, rim, isMeteorCore);
        break;
      case 'Crystal':
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.kLetCrystalHold,
        );
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.10);
        enemy.knockbackVelocity = Offset.zero;
        _damageEnemy(
          enemy,
          projectile.damage * 0.25,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        // Out to the rim, at a smaller share than the 0.32 it took inside the
        // crater: Crystal throws at twice the rate (2026-10-20).
        _damageEnemiesNear(
          rimCentre,
          max(rim, max(140, projectile.effectRadius)),
          projectile.damage * 0.20,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        if (isMeteorCore && !enemy.isDead) {
          final held = enemy;
          pushLetFx(
            _letFx,
            LetFx.crystal(
              position: held.position,
              bodyRadius: held.radius,
              duration: CosmicAbilityRuntime.kLetCrystalHold,
              anchor: () => held.isDead ? null : held.position,
            ),
          );
        }
        break;
      case 'Lightning':
        _chainLetLightning(projectile, enemy, rimCentre, rim);
        _damageEnemy(
          enemy,
          projectile.damage * 0.18,
          sourceSlotIndex: projectile.sourceSlotIndex,
        );
        break;
      case 'Ice':
        enemy.slowTimer = max(
          enemy.slowTimer,
          CosmicAbilityRuntime.kLetIceHold,
        );
        enemy.slowMultiplier = min(enemy.slowMultiplier, 0.05);
        enemy.knockbackVelocity = Offset.zero;
        if (isMeteorCore && !enemy.isDead) {
          final held = enemy;
          pushLetFx(
            _letFx,
            LetFx.frost(
              position: held.position,
              bodyRadius: held.radius,
              duration: CosmicAbilityRuntime.kLetIceHold,
              anchor: () => held.isDead ? null : held.position,
            ),
          );
        }
        // The frost runs on to the rim and holds what stands there too.
        _freezeLetIceRim(projectile, enemy, rimCentre, rim, isMeteorCore);
        break;
      case 'Water':
        // Out to the rim, at a smaller share than the 0.42 it took inside the
        // crater (2026-10-20).
        final reach = max(rim, CosmicAbilityRuntime.letWaterReach(projectile));
        _damageEnemiesNear(
          rimCentre,
          reach,
          projectile.damage * 0.30,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: enemy,
        );
        if (isMeteorCore) {
          pushLetFx(_letFx, LetFx.splash(position: rimCentre, radius: reach));
        }
        break;
      default:
        break;
    }
    // Re-read the enemy rather than trusting the flag alone: a few contact
    // behaviours deal damage of their own (Spirit's execute above all), so the
    // impact can finish something the initial hit did not.
    _resolveLetMeteorImpactAftermath(
      projectile,
      enemy.position,
      primary: enemy,
      killed: killed || enemy.isDead,
    );
  }

  /// The kill-gated half of a Let impact.
  ///
  /// Every element in this switch is authored "if the meteor kills" — vines,
  /// geysers, healing pools, Dark's bombardment. [killed] enforces that.
  ///
  /// Air is the one deliberate exception and does NOT require a kill: its
  /// knockback is the cast's crowd control, and a shove that only lands when
  /// the meteor also happens to finish something is not something a player can
  /// plan around. Authored choice, not an oversight — do not "fix" it.
  void _resolveLetMeteorImpactAftermath(
    Projectile projectile,
    Offset center, {
    CosmicSurvivalEnemy? primary,
    required bool killed,
  }) {
    if (!killed && projectile.element != 'Air') return;
    // Only the meteor core leaves persistent zones. Without this,
    // a piercing/bouncing spread secondary that kills several enemies
    // would stack one full set of zones per hit.
    final isMeteorCore = CosmicAbilityRuntime.isLetMeteorCore(projectile);
    // Kill zones — Light's well, Steam's vent, Mud's mire — from the shared
    // table.
    final zone = CosmicAbilityRuntime.letKillZone(projectile.element);
    if (zone != null && isMeteorCore) {
      _spawnLetZone(projectile, center, projectile.element!, zone);
    }
    // Out to the crater's rim, as the contact effects reach.
    final rimCentre = _letImpactCentre(projectile, center);
    final rim = CosmicAbilityRuntime.letRimReach(projectile);
    switch (projectile.element) {
      case 'Air':
        final reach = max(rim, CosmicAbilityRuntime.letAirReach(projectile));
        _visitEnemiesNear(rimCentre, reach, (enemy) {
          final dir = enemy.position - rimCentre;
          _applyEnemyKnockback(enemy, dir, 340 + projectile.damage * 5.0);
          return false;
        });
        if (isMeteorCore) {
          pushLetFx(_letFx, LetFx.gust(position: rimCentre, radius: reach));
        }
        break;
      case 'Plant':
        if (isMeteorCore) {
          for (final spot in CosmicAbilityRuntime.letVineSpots(
            center,
            projectile.angle,
          )) {
            _appendCompanionProjectile(
              CosmicAbilityRuntime.letVine(projectile, spot),
            );
          }
        }
        break;
      case 'Blood':
        final drain = projectile.damage * 0.22;
        final reach = max(rim, max(170.0, projectile.effectRadius));
        // Every body in reach is drained; only the first few are drawn, so a
        // kill in the middle of a horde does not flood the effect list.
        var drawn = 0;
        _visitEnemiesNear(center, reach, (enemy) {
          if (primary != null && identical(enemy, primary)) return false;
          if (!_withinRange(center, enemy.position, reach)) return false;
          _damageEnemy(
            enemy,
            drain,
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
          if (drawn < 8) {
            drawn++;
            pushLetFx(_letFx, LetFx.drain(from: enemy.position, to: center));
          }
          return false;
        });
        _healAllCompanionsAndShip(drain * 0.18);
        break;
      case 'Fire':
        // The kill blast reaches past the crater: at Potential 20 the old
        // reach (twice the effect radius) fell inside the wider crater. Its
        // share came down from 0.72 with it (2026-10-20).
        final reach = max(rim, CosmicAbilityRuntime.letFireReach(projectile));
        _damageEnemiesNear(
          center,
          reach,
          projectile.damage * 0.50,
          sourceSlotIndex: projectile.sourceSlotIndex,
          exclude: primary,
        );
        pushLetFx(_letFx, LetFx.blast(position: center, radius: reach));
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
      default:
        break;
    }
  }

  /// Where a Let meteor came down: its committed impact point, or [fallback]
  /// for a Let projectile that never fell.
  Offset _letImpactCentre(Projectile p, Offset fallback) =>
      p.skyfallDuration > 0 ? p.skyfallImpact : fallback;

  /// Spirit's execute, rolled for every body still standing out to the rim
  /// of the crater: the meteor's own chance, or a sure thing on a body at or
  /// under 35% health, as the struck body has. Draws at most six souls.
  void _executeLetSpiritRim(
    Projectile projectile,
    CosmicSurvivalEnemy struck,
    Offset centre,
    double rim,
    bool isMeteorCore,
  ) {
    var drawn = 0;
    _visitEnemiesNear(centre, rim, (enemy) {
      if (identical(enemy, struck)) return false;
      if (!_withinRange(centre, enemy.position, rim)) return false;
      if (enemy.hpFraction > 0.35 &&
          _rng.nextDouble() > projectile.effectChance) {
        return false;
      }
      final at = enemy.position;
      final bodyRadius = enemy.radius;
      _damageEnemy(
        enemy,
        enemy.hp + 1,
        sourceSlotIndex: projectile.sourceSlotIndex,
      );
      if (isMeteorCore && drawn < 6) {
        drawn++;
        pushLetFx(_letFx, LetFx.soul(position: at, bodyRadius: bodyRadius));
      }
      return false;
    });
  }

  /// Ice's freeze, run on from the struck body to every body standing out to
  /// the rim of the crater. Draws the hold on at most eight of them.
  void _freezeLetIceRim(
    Projectile projectile,
    CosmicSurvivalEnemy struck,
    Offset centre,
    double rim,
    bool isMeteorCore,
  ) {
    var drawn = 0;
    _visitEnemiesNear(centre, rim, (enemy) {
      if (identical(enemy, struck)) return false;
      if (!_withinRange(centre, enemy.position, rim)) return false;
      enemy.slowTimer = max(enemy.slowTimer, CosmicAbilityRuntime.kLetIceHold);
      enemy.slowMultiplier = min(enemy.slowMultiplier, 0.05);
      enemy.knockbackVelocity = Offset.zero;
      if (isMeteorCore && drawn < 8) {
        drawn++;
        final held = enemy;
        pushLetFx(
          _letFx,
          LetFx.frost(
            position: held.position,
            bodyRadius: held.radius,
            duration: CosmicAbilityRuntime.kLetIceHold,
            anchor: () => held.isDead ? null : held.position,
          ),
        );
      }
      return false;
    });
  }

  /// Lightning's contact: a chain from the struck body. Its first hop goes to
  /// the nearest body still standing out to the rim of the crater, so a
  /// crater that killed everything round the struck body still chains
  /// outward; every hop after that leaps [CosmicAbilityRuntime.chainRange]
  /// from the last and never returns to a body it struck. It used to hop
  /// only [CosmicAbilityRuntime.chainRange] from the struck body, inside the
  /// crater it had just emptied, and could bounce back and forth between
  /// two bodies.
  void _chainLetLightning(
    Projectile projectile,
    CosmicSurvivalEnemy from,
    Offset centre,
    double rim,
  ) {
    final hops = max(2, projectile.effectCount);
    final base = projectile.damage * 0.72;
    final struck = <CosmicSurvivalEnemy>[from];
    final points = <Offset>[from.position];
    var at = from.position;
    for (var h = 0; h < hops; h++) {
      final searchCentre = h == 0 ? centre : at;
      final searchReach = h == 0 ? rim : CosmicAbilityRuntime.chainRange;
      final last = at;
      CosmicSurvivalEnemy? next;
      var bestSq = double.infinity;
      _visitEnemiesNear(searchCentre, searchReach, (enemy) {
        if (struck.contains(enemy)) return false;
        if (!_withinRange(searchCentre, enemy.position, searchReach)) {
          return false;
        }
        final dSq = _distanceSquared(enemy.position, last);
        if (dSq < bestSq) {
          bestSq = dSq;
          next = enemy;
        }
        return false;
      });
      final hop = next;
      if (hop == null) break;
      struck.add(hop);
      points.add(hop.position);
      _spawnHitSpark(hop.position, elementColor('Lightning'));
      _damageEnemy(
        hop,
        CosmicAbilityRuntime.chainBounceDamage(base, h),
        sourceSlotIndex: projectile.sourceSlotIndex,
      );
      at = hop.position;
    }
    if (points.length > 1 && CosmicAbilityRuntime.isLetMeteorCore(projectile)) {
      pushLetFx(_letFx, LetFx.chain(points: points));
    }
  }

  void _spawnPipKillPlacement(
    int? slotIndex,
    CosmicSurvivalCompanion? companion,
    Offset position, {
    bool fromPipSpecial = false,
    bool fromAutoAttack = false,
  }) {
    if (companion == null) return;
    if (companion.member.family.toLowerCase() != 'pip') return;
    final element = companion.member.element;
    // Per design board: Fire/Dust/Crystal placements come from the
    // SPECIAL ability's kills; Dark is the passive that fires on AUTO
    // kills only. Skip otherwise so basic-attack kills don't drop
    // pools and special kills don't open black holes.
    // Dark reads the AUTO-attack flag, not "anything but the special": a
    // black hole's own execute is neither, and counting it let every hole
    // open the next — a horde fell into a chain of them (6.0x the median
    // ability, measured 2026-10-07).
    final allowedBySource = switch (element) {
      'Dark' => fromAutoAttack,
      'Fire' || 'Dust' || 'Crystal' => fromPipSpecial,
      _ => true,
    };
    if (!allowedBySource) return;
    final scale = companion.abilityAtk * 0.20 + 4.0;
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
            decoyHp: (18.0 + companion.abilityAtk * 0.6) * sizeScale,
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
        // Pip+Dark never casts; the void opening is its special's sound.
        final opened = _appendCompanionProjectile(
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
          cue: SoundCue.specialPipVoid,
        );
        if (opened && slotIndex != null) {
          _loadPipDarkSalvo(slotIndex, companion, position);
        }
        break;
    }
  }

  /// Salvo for a Pip Dark. "Load more darts into every special" had nothing
  /// to load: Pip Dark's ability is passive and it never throws a special, so
  /// the whole path was dead for it (2026-10-20 audit). Its special is the
  /// hole an auto kill opens, so the hole is what Salvo loads — it spits one
  /// dart per Salvo node at the bodies round it, each worth the share a Salvo
  /// dart carries, at most once per special interval so a horde of auto kills
  /// is still one salvo per special, as it is for every other Pip. The darts
  /// are the special's, so their kills open no hole of their own.
  void _loadPipDarkSalvo(
    int slotIndex,
    CosmicSurvivalCompanion pip,
    Offset hole,
  ) {
    if (!_isMasteryPip(slotIndex)) return;
    final salvo = resolvePipSalvo(
      hasNode: (nodeId) => mastery.hasNode(slotIndex, nodeId),
    );
    if (salvo.extraDarts <= 0) return;
    if (mastery.procRemaining(slotIndex, PipNodes.salvoPath) > 0) return;
    if (!mastery.requestObjects(salvo.extraDarts)) return;
    mastery.tryProc(
      slotIndex,
      PipNodes.salvoPath,
      max(1.0, pip.effectiveSpecialCooldown),
    );
    final damage =
        pip.abilityAtk *
        1.15 *
        (_equippedSkin == OrbBaseSkin.voidforgeOrb ? 1.12 : 1.0) *
        pip.damageAmp *
        PipTuning.darkSalvoDartScale *
        salvo.fraction;
    final darts = <Projectile>[];
    final turn = _rng.nextDouble() * 2 * pi;
    for (var i = 0; i < salvo.extraDarts; i++) {
      final a = turn + i * 2 * pi / salvo.extraDarts;
      darts.add(
        Projectile(
          position: hole + Offset(cos(a) * 14, sin(a) * 14),
          angle: a,
          element: 'Dark',
          damage: damage,
          life: PipTuning.darkSalvoDartLife,
          speedMultiplier: 2.0,
          homing: true,
          homingStrength: 3.0,
          visualScale: 0.9,
          visualStyle: ProjectileVisualStyle.dart,
          sourceSlotIndex: slotIndex,
          abilityFamily: 'pip',
        )..masteryGenerated = true,
      );
    }
    _appendCompanionProjectiles(darts, silent: true);
  }

  void _spawnLetZone(
    Projectile source,
    Offset center,
    String element,
    LetZoneSpec spec,
  ) {
    _appendCompanionProjectile(
      CosmicAbilityRuntime.letZone(source, center, element, spec),
    );
  }

  /// Plant's vines: each strikes the first body to come into its reach and is
  /// spent doing it — "remain until an enemy collides with them".
  void _updateLetVines() {
    final count = companionProjectiles.length;
    for (var i = 0; i < count && i < companionProjectiles.length; i++) {
      final vine = companionProjectiles[i];
      if (vine.life <= 0 || vine.trapSpent) continue;
      if (!CosmicAbilityRuntime.isLetVine(vine)) continue;
      final reach = vine.effectRadius;
      CosmicSurvivalEnemy? struck;
      _visitEnemiesNear(vine.position, reach + _maxEnemyRadius, (enemy) {
        if (!_withinRange(
          vine.position,
          enemy.position,
          reach + enemy.radius,
        )) {
          return false;
        }
        struck = enemy;
        return true;
      });
      final body = struck;
      Offset? at;
      if (body != null) {
        at = body.position;
        _damageEnemy(
          body,
          vine.effectPower,
          sourceSlotIndex: vine.sourceSlotIndex,
        );
      } else {
        for (final boss in allLivingBosses) {
          if (boss.isSpawning ||
              !_withinRange(
                vine.position,
                boss.position,
                reach + boss.radius,
              )) {
            continue;
          }
          at = boss.position;
          damageBoss(
            vine.effectPower,
            attackElement: 'Plant',
            sourceSlotIndex: vine.sourceSlotIndex,
            target: boss,
          );
          break;
        }
      }
      if (at == null) continue;
      pushLetFx(_letFx, LetFx.lash(from: vine.position, to: at));
      vine
        ..trapSpent = true
        ..life = 0;
    }
  }

  /// Damages every body within [radius] of [center], bosses included.
  ///
  /// Bosses used to be skipped here, which quietly took Horn's Anvil, Last
  /// Stand and Juggernaut pulse, Mask's Plague, and Kin's flame and lava
  /// splash out of every boss fight (2026-10-20 audit). A boss is caught when
  /// any of its body is inside the area, and takes the hit through its own
  /// path, matchup and shield included, as the caster's element unless
  /// [attackElement] says otherwise. [includeBosses] is for the one caller
  /// that has already hit the bosses in the same area itself.
  void _damageEnemiesNear(
    Offset center,
    double radius,
    double damage, {
    int? sourceSlotIndex,
    CosmicSurvivalEnemy? exclude,
    String? attackElement,
    SurvivalBoss? excludeBoss,
    bool includeBosses = true,
    MasteryDamageSource? masterySource,
  }) {
    _visitEnemiesNear(center, radius, (enemy) {
      if (exclude != null && identical(enemy, exclude)) return false;
      if (!_withinRange(center, enemy.position, radius)) return false;
      _damageEnemy(
        enemy,
        damage,
        sourceSlotIndex: sourceSlotIndex,
        masterySource: masterySource,
      );
      return false;
    });
    if (includeBosses) {
      _damageBossesNear(
        center,
        radius,
        damage,
        sourceSlotIndex: sourceSlotIndex,
        attackElement: attackElement,
        exclude: excludeBoss,
        masterySource: masterySource,
      );
    }
  }

  /// The boss half of an area hit: every living boss with any of its body
  /// inside [radius] of [center]. Bosses are few, so they are tested directly
  /// rather than filed in the enemy grid, and only while one is alive.
  void _damageBossesNear(
    Offset center,
    double radius,
    double damage, {
    int? sourceSlotIndex,
    String? attackElement,
    SurvivalBoss? exclude,
    MasteryDamageSource? masterySource,
  }) {
    if (damage <= 0 || !anyBossAlive) return;
    final element =
        attackElement ??
        (sourceSlotIndex == null
            ? null
            : (activeCompanions[sourceSlotIndex] ??
                      _unbrokenKin[sourceSlotIndex])
                  ?.member
                  .element);
    for (final boss in allLivingBosses) {
      if (boss.isDead || boss.isSpawning || identical(boss, exclude)) continue;
      if (!_withinRange(center, boss.position, radius + boss.radius)) continue;
      damageBoss(
        damage,
        attackElement: element,
        sourceSlotIndex: sourceSlotIndex,
        target: boss,
        masterySource: masterySource,
      );
    }
  }

  final Map<int?, double> _maskBloodHealRemainders = {};

  void _healMaskBloodDrain(double amount, int? sourceSlot) {
    final total = (_maskBloodHealRemainders[sourceSlot] ?? 0) + amount;
    final whole = total.floorToDouble();
    _maskBloodHealRemainders[sourceSlot] = total - whole;
    if (whole > 0) _healAllCompanionsAndShip(whole, sourceSlot: sourceSlot);
  }

  void _healMaskPool(Projectile p) {
    if (!ship.isDead &&
        _withinRange(ship.position, p.position, p.effectRadius)) {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, before + p.effectPower);
      _recordHeal(
        ship.currentHp - before,
        target: 1,
        sourceSlot: p.sourceSlotIndex,
      );
    }
    for (final ally in activeCompanions.values) {
      if (ally.isDead ||
          !_withinRange(ally.position, p.position, p.effectRadius)) {
        continue;
      }
      final before = ally.currentHp;
      ally.currentHp = min(ally.maxHp, before + p.effectPower.round());
      _recordHeal(
        (ally.currentHp - before).toDouble(),
        target: 0,
        sourceSlot: p.sourceSlotIndex,
      );
    }
  }

  /// The strongest Mask Ice pillar the ship stands by ([maskIceAmpOf]), or 1.
  double get maskShipDamageAmp {
    var amp = 1.0;
    for (final p in companionProjectiles) {
      if (p.abilityFamily == 'mask' &&
          p.element == 'Ice' &&
          p.life > 0 &&
          _withinRange(ship.position, p.position, p.effectRadius)) {
        amp = max(amp, maskIceAmpOf(p));
      }
    }
    return amp;
  }

  void _healLowestAllyOrShip(double amount, {int? sourceSlot}) {
    if (amount <= 0) return;
    // The one body with the lowest health fraction, the ship first on a tie.
    final bodies = <Object>[
      if (!ship.isDead && ship.maxHp > 0) ship,
      for (final comp in activeCompanions.values)
        if (!comp.isDead && comp.maxHp > 0) comp,
    ];
    final pick = CosmicAbilityRuntime.lowestFraction([
      for (final body in bodies)
        body is CosmicSurvivalCompanion
            ? body.currentHp / body.maxHp
            : ship.currentHp / ship.maxHp,
    ]);
    final target = pick < 0 ? null : bodies[pick];
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

  /// The bodies round a Dark Let's kill, gathered once per bombardment.
  final List<Offset> _letDarkBodies = <Offset>[];

  void _spawnDarkLetKillMeteors(Projectile source, Offset center) {
    // Stat-scaled count. The shared ability runtime handles the full canonical
    // stat range, including Potential, Enhancement, and in-run boosts.
    final stat = source.letCasterIntelligence;
    final count = CosmicAbilityRuntime.darkLetFollowupCount(stat);
    final reach = max(420.0, source.effectRadius * 3.0);
    final bodies = _letDarkBodies..clear();
    _visitEnemiesNear(center, reach, (enemy) {
      if (_withinRange(center, enemy.position, reach)) {
        bodies.add(enemy.position);
      }
      return false;
    });
    // Spread by angle round the kill, on the bodies just past the crater it
    // cleared ([CosmicAbilityRuntime.darkLetFollowupAims]).
    final aims = CosmicAbilityRuntime.darkLetFollowupAims(
      centre: center,
      bodies: bodies,
      count: count,
      startAngle: source.angle,
      // Follow-ups may overlap a quarter of a crater, no more.
      spacing:
          letSkyfallBlastRadiusFor(
            CosmicAbilityRuntime.darkLetFollowupRadius(source),
          ) *
          0.75,
      minDistance: letSkyfallBlastRadius(source),
    );
    bodies.clear();

    for (var i = 0; i < aims.length; i++) {
      final aim = aims[i];
      final a = atan2(aim.dy - center.dy, aim.dx - center.dx);
      // The follow-ups fall too. Per design this is a bombardment, and a
      // volley of sideways meteors beside a parent that dropped out of the
      // sky would read as two different abilities. Staggered so they land as
      // a rolling barrage rather than one simultaneous thud.
      final drop = letSkyfallDrop(aim, a, timeScale: 0.72 + i * 0.16);
      _appendCompanionProjectile(
        Projectile(
          position: drop.position,
          angle: drop.angle,
          element: 'Dark',
          damage: source.damage * 0.7,
          life: drop.duration + 0.4,
          speedMultiplier: 0,
          skyfallDuration: drop.duration,
          skyfallImpact: aim,
          skyfallDistance: drop.distance,
          // Bigger than its parent, per design.
          radiusMultiplier: CosmicAbilityRuntime.darkLetFollowupRadius(source),
          visualScale: CosmicAbilityRuntime.darkLetFollowupVisualScale(source),
          visualStyle: ProjectileVisualStyle.meteor,
          homing: false,
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
      final pushDistance = ManeRuntime.airPushDistance(projectile);
      enemy.position = enemy.position + dir * pushDistance;
      enemy.knockbackVelocity += dir * ManeRuntime.airShoveSpeed;
      enemy.slowTimer = max(
        enemy.slowTimer,
        ManeRuntime.airSlowDuration(projectile),
      );
      enemy.slowMultiplier = min(enemy.slowMultiplier, ManeRuntime.airSlow);
      _spawnHitSpark(enemy.position, elementColor('Air'));
      return;
    }
    // Mane "carry" semantic: enemy is dragged along the projectile's path
    // for a moment instead of being pushed back to origin. Apply this
    // before the generic effect handler so we can short-circuit.
    if (projectile.pierceEffect == AbilityEffectKind.carry) {
      final isManeWaterWall = ManeRuntime.isWaterWall(projectile);
      final dragDistance = isManeWaterWall
          ? ManeRuntime.waterWallDrag(projectile)
          : CosmicAbilityRuntime.maneCarryDistance(projectile.effectPower);
      enemy.position = Offset(
        enemy.position.dx + cos(projectile.angle) * dragDistance,
        enemy.position.dy + sin(projectile.angle) * dragDistance,
      );
      enemy.slowTimer = max(
        enemy.slowTimer,
        projectile.effectDuration +
            (isManeWaterWall ? ManeRuntime.waterWallExtraSlowTime : 0.0),
      );
      enemy.slowMultiplier = min(
        enemy.slowMultiplier,
        isManeWaterWall ? ManeRuntime.waterWallSlow : ManeRuntime.carrySlow,
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
          // The vine THICKENS as it passes through things — growth by feeding,
          // which is what a plant does. This is the growth mechanic Light used
          // to carry; Light has become an orbiting cast and no longer wants
          // it, and it suits a vine far better than it ever suited a ball of
          // light. The root tag stays: a kill while rooted still detonates.
          enemy.maneRootSlot = projectile.sourceSlotIndex;
          enemy.maneRootTimer = max(
            enemy.maneRootTimer,
            ManeRuntime.plantRootTime,
          );
          enemy.slowTimer = max(enemy.slowTimer, ManeRuntime.plantRootTime);
          enemy.slowMultiplier = 0;
          // Growth per bite is gentler than the doubling Light used, and
          // compounds over more hits — a vine creeps outward, it does not
          // erupt. Damage climbs with the thickness.
          ManeRuntime.growPlantVine(projectile);
          _spawnHitSpark(enemy.position, elementColor('Plant'));
          break;
        case 'Lava':
          // Drop a lava blob (DoT zone) at the pierce point.
          if (!ManeRuntime.dropsLavaBlob(projectile)) break;
          _appendCompanionProjectile(
            ManeRuntime.lavaBlob(projectile, enemy.position),
            silent: true,
          );
          break;
        case 'Blood':
          // Per design: every pierce restores HP to the orb. Scaling
          // ties to projectile damage so a high-damage build heals
          // more per pierce.
          _healOrb(
            _cappedOrbHeal(
              projectile.sourceSlotIndex,
              ManeRuntime.bloodPierceHeal(projectile).toDouble(),
            ),
            sourceSlot: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(enemy.position, elementColor('Blood'));
          break;
        case 'Poison':
          // Per design: each pierce stacks poison; subsequent ticks
          // hit harder per stack. Stacks are tracked per-enemy.
          // Apply the standard poison effect with damage amplified
          // by the current stack count (1x at 1 stack, +20% per).
          final (stacks, stackMul) = ManeRuntime.poisonStackStep(
            enemy.manePoisonStacks,
          );
          enemy.manePoisonStacks = stacks;
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
          if (enemy.hpFraction <= ManeRuntime.darkExecuteFraction) {
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
      // The handler needs to know whose cast this is: Pip's two leeches heal
      // different things, and Mane Blood's leech answers to the heal
      // ceiling. Without these it healed through the pierce path uncapped.
      element: projectile.element,
      family: projectile.abilityFamily,
    );
  }

  void updatePersistentAbilityEffects(double dt) {
    // Snapshot current projectiles — tick effects can kill enemies,
    // which may run on-kill hooks (e.g. Pip kill placements) that
    // append new entries to companionProjectiles. Iterating the live
    // list would throw ConcurrentModificationError.
    final snapshot = List<Projectile>.of(companionProjectiles);
    for (final p in snapshot) {
      if (p.life <= 0 || p.trapSpent) continue;
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
      if (p.isMaskDamageZone) {
        for (final boss in allLivingBosses.toList(growable: false)) {
          if (boss.isSpawning ||
              !_withinRange(
                boss.position,
                p.position,
                p.effectRadius + boss.radius,
              )) {
            continue;
          }
          damageBoss(
            p.effectPower,
            attackElement: p.element,
            sourceSlotIndex: p.sourceSlotIndex,
            target: boss,
            masteryCastId: p.masteryCastId,
            masterySource: _projectileDamageSource(p),
          );
          _applyBossCrowdControl(boss, p.tickEffect, 0.5);
          if (p.element == 'Lightning' &&
              p.noteMaskGrowthHit(identityHashCode(boss))) {
            p.effectRadius = min(260.0, p.effectRadius + 14);
            p.life = min(18.0, p.life + 0.6);
          }
        }
      } else if (anyBossAlive) {
        _tickZoneOnBosses(p);
      }
      if (p.tickEffect == AbilityEffectKind.zoneHeal) {
        if (p.abilityFamily == 'mask') {
          _healMaskPool(p);
        } else {
          _healLowestAllyOrShip(p.effectPower, sourceSlot: p.sourceSlotIndex);
        }
        // Earth heal pool activation pulse — renderer reads
        // abilityGrowthTimer to flash the pool on each heal tick.
        if (p.abilityFamily == 'mask') {
          p.abilityGrowthTimer = max(p.abilityGrowthTimer, 0.8);
        }
        continue;
      }
      final zoneRadius = max(24.0, p.effectRadius);
      if (p.abilityFamily == 'mask' && p.element == 'Ice') {
        for (final ally in activeCompanions.values) {
          if (ally.isDead ||
              !_withinRange(ally.position, p.position, zoneRadius)) {
            continue;
          }
          if (ally.damageAmpTimer <= 0) ally.damageAmpMultiplier = 1;
          ally.damageAmpTimer = max(ally.damageAmpTimer, 0.5);
          ally.damageAmpMultiplier = max(
            ally.damageAmpMultiplier,
            maskIceAmpOf(p),
          );
        }
        continue;
      }
      final isBlackHoleZone = p.tickEffect == AbilityEffectKind.blackHole;
      final isLeechZone = p.tickEffect == AbilityEffectKind.leech;
      _visitEnemiesNear(p.position, zoneRadius, (enemy) {
        if (!_withinRange(p.position, enemy.position, zoneRadius)) {
          return false;
        }
        if (p.abilityFamily == 'mask' && p.element == 'Lightning') {
          _damageEnemy(
            enemy,
            p.effectPower,
            sourceSlotIndex: p.sourceSlotIndex,
          );
          if (p.noteMaskGrowthHit(identityHashCode(enemy))) {
            p.effectRadius = min(260.0, p.effectRadius + 14);
            p.life = min(18.0, p.life + 0.6);
          }
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
          if (p.voidEjectOnly) {
            // A void hole moves bodies and nothing else: it draws them in,
            // and whatever reaches the middle is put out of the area. The
            // draw is a shove toward the mouth each tick, carried smoothly
            // by the knockback integrator until the next one, strong enough
            // across the whole suction radius to beat a body's walk.
            if (dist > 56 && dist > 0.01) {
              enemy.knockbackVelocity +=
                  (dir / dist) *
                  (CosmicAbilityRuntime.voidPullImpulse(dist, zoneRadius) *
                      CosmicAbilityRuntime.knockbackMassScale(enemy.tier));
            } else {
              if (_maskTrapVisuals.contact(p)) _soundMaskSpring(p);
              _ejectBodyFromField(
                enemy,
                hole: p.position,
                holeRadius: zoneRadius,
              );
            }
            return false;
          }
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
      _seedMaskContagionInZone(p, zoneRadius);
    }
  }

  /// Contagion's Carrier: "an enemy that walks out of one of your traps
  /// alive is infected". Only a body touching a trap's centre was (its
  /// contact radius, a few px for a pool 90-110 px wide), so a Mask's zones
  /// seeded almost nothing and the path's reach came from the spread alone.
  /// What a zone tick leaves standing inside it catches it now, within the
  /// Mask's carrier cap. Once a tick, and only for a Contagion Mask's zones.
  void _seedMaskContagionInZone(Projectile p, double zoneRadius) {
    final slot = p.sourceSlotIndex;
    if (slot == null ||
        p.abilityFamily != 'mask' ||
        p.voidEjectOnly ||
        !mastery.enabled ||
        !_isMasteryMask(slot) ||
        !mastery.hasNode(slot, MaskNodes.carrier)) {
      return;
    }
    final state = _maskStateFor(slot);
    if (!state.canInfectAnother) return;
    final duration = maskInfection(
      hasNode: (id) => mastery.hasNode(slot, id),
      generation: 0,
    ).duration;
    final at = p.position;
    _visitEnemiesNear(at, zoneRadius, (enemy) {
      if (!_withinRange(at, enemy.position, zoneRadius)) return false;
      _catchMaskInfection(
        state,
        slot,
        enemy,
        duration: duration,
        generation: 0,
      );
      return !state.canInfectAnother;
    });
  }

  /// What one tick of a family's zone deals a boss standing in it, or 0 for a
  /// zone that only moves, slows, heals or is there to be seen.
  ///
  /// The same figure the zone deals a body: its power for the direct-damage
  /// ticks, the chain's splash share for a chain zone, and a void's chip.
  /// Horn and Mane first; then Pip's pools and holes, Wing's Lava scars,
  /// Steam clouds and trail, Let's ground and Kin's pieces, which were as
  /// blind to a boss (2026-10-20 audit). Mask's traps have their own branch,
  /// and a Mystic's world its own rules.
  static double _zoneBossTickDamage(Projectile p) {
    switch (p.abilityFamily) {
      case 'horn' || 'mane' || 'pip' || 'wing' || 'let' || 'kin':
        break;
      default:
        return 0;
    }
    if (p.effectPower <= 0 || p.voidEjectOnly) return 0;
    return switch (p.tickEffect) {
      AbilityEffectKind.burn ||
      AbilityEffectKind.poison ||
      AbilityEffectKind.zoneDamage ||
      AbilityEffectKind.geyser ||
      AbilityEffectKind.root => p.effectPower,
      AbilityEffectKind.chain =>
        p.effectPower *
            CosmicAbilityRuntime.splashMultiplier(AbilityEffectKind.chain),
      AbilityEffectKind.blackHole => p.effectPower * 0.4,
      _ => 0,
    };
  }

  /// A Horn or Mane zone's tick on the bosses inside it.
  ///
  /// The zone tick only visited the enemy grid, so Horn's burning trail,
  /// geysers, quakes, voids and chain zones, and Mane's lava, steam, quake
  /// and lightning fields, never touched a boss standing in them (2026-10-20
  /// audit). Mask's traps have their own boss branch above. Bosses are few
  /// and tested directly, by index because a kill promotes an extra.
  void _tickZoneOnBosses(Projectile p) {
    final damage = _zoneBossTickDamage(p);
    if (damage <= 0) return;
    final reach = max(24.0, p.effectRadius);
    final primary = activeBoss;
    if (primary != null) _tickZoneOnBoss(p, primary, damage, reach);
    for (var i = 0; i < extraBosses.length; i++) {
      _tickZoneOnBoss(p, extraBosses[i], damage, reach);
    }
  }

  void _tickZoneOnBoss(
    Projectile p,
    SurvivalBoss boss,
    double damage,
    double reach,
  ) {
    if (boss.isDead || boss.isSpawning) return;
    if (!_withinRange(boss.position, p.position, reach + boss.radius)) return;
    damageBoss(
      damage,
      attackElement: p.element,
      sourceSlotIndex: p.sourceSlotIndex,
      target: boss,
      masteryCastId: p.masteryCastId,
      masterySource: _projectileDamageSource(p),
    );
    _applyBossCrowdControl(boss, p.tickEffect, 0.5);
  }

  void _applyAbilityEffectToEnemy(
    AbilityEffectKind effect,
    CosmicSurvivalEnemy enemy,
    Offset origin,
    double power,
    double radius,
    double duration, {
    int? sourceSlotIndex,
    // Two elements share the leech effect but are authored to heal different
    // things, so the handler has to know which cast it is resolving.
    String? element,
    String? family,
  }) {
    if (effect == AbilityEffectKind.none) return;
    // A kill effect arrives with its target already dead — that is what makes
    // it a kill effect — so a blanket isDead guard silently dropped every one
    // of them that came through here. Only the behaviours that act on the
    // enemy's own state need it alive.
    if (enemy.isDead && !CosmicAbilityRuntime.resolvesOnDeadTarget(effect)) {
      return;
    }
    final effectPower = power > 0 ? power : 4.0;
    final effectRadius = radius > 0 ? radius : 80.0;
    final effectDuration = duration > 0 ? duration : 1.5;
    switch (effect) {
      case AbilityEffectKind.knockback:
        // Pip Air pushes back what survives its dart: back from the orb.
        // Along the dart's flight, a dart coming in toward the orb (from a
        // ricochet, or a Pip out on the rim) shoved its survivors at it
        // (2026-10-20 audit).
        final away = family == 'pip' ? enemy.position - orb.position : null;
        final dir = away != null && away.distanceSquared > 0.0001
            ? away
            : enemy.position - origin;
        final dist = dir.distance;
        if (dist > 0.01) {
          // A Mask Air pad's power is its shove; the shared impulse clamps
          // every power that large to one figure.
          enemy.knockbackVelocity +=
              (dir / dist) *
              (family == 'mask'
                  ? CosmicAbilityRuntime.maskAirImpulse(effectPower)
                  : CosmicAbilityRuntime.knockbackImpulse(effectPower));
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
        // A burning body takes half of every heal (games/shared/burn_healing).
        if (effect == AbilityEffectKind.burn) _burnEnemy(enemy);
        _damageEnemy(enemy, effectPower, sourceSlotIndex: sourceSlotIndex);
        if (effect == AbilityEffectKind.geyser) {
          // Away from the orb, whichever side of it the geyser stands.
          enemy.knockbackVelocity += CosmicAbilityRuntime.geyserKnockbackFrom(
            orb.position,
            enemy.position,
          );
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
          other.position +=
              (dir / dist) * CosmicAbilityRuntime.blackHolePullStep(dist);
          other.slowTimer = max(other.slowTimer, effectDuration);
          other.slowMultiplier = min(
            other.slowMultiplier,
            CosmicAbilityRuntime.blackHoleSlow,
          );
          if (effect == AbilityEffectKind.blackHole &&
              other.hpFraction <= CosmicAbilityRuntime.blackHoleExecute) {
            _damageEnemy(other, other.hp + 1, sourceSlotIndex: sourceSlotIndex);
          }
          return false;
        });
        break;
      case AbilityEffectKind.leech:
      case AbilityEffectKind.zoneHeal:
        // Pip+Blood and Pip+Light both resolve to leech, and both used to heal
        // the orb AND the caster — which made them mechanically the same
        // ability. The design board gives them different targets, and that
        // difference is the only thing separating the two: Blood feeds itself,
        // Light feeds the orb.
        final comp = sourceSlotIndex != null
            ? activeCompanions[sourceSlotIndex]
            : null;
        final isPip = family == 'pip';
        final healsCasterOnly = isPip && element == 'Blood';
        final healsOrbOnly = isPip && element == 'Light';

        if (!healsCasterOnly) {
          final orbHeal =
              effectPower *
              (healsOrbOnly ? 1.0 : CosmicAbilityRuntime.leechObjectiveShare);
          // Wing leech beams and Mane Blood's shot heal with every body they
          // cross, so they answer to the per-caster ceiling.
          _healOrb(
            family == 'wing' || family == 'mane'
                ? _cappedOrbHeal(sourceSlotIndex, orbHeal)
                : orbHeal,
          );
        }
        if (!healsOrbOnly) {
          if (comp != null && !comp.isDead) {
            comp.currentHp = min(
              comp.maxHp,
              comp.currentHp + effectPower.round(),
            );
          } else if (!ship.isDead) {
            ship.currentHp = min(ship.maxHp, ship.currentHp + effectPower);
          }
        }
        break;
      case AbilityEffectKind.buff:
      case AbilityEffectKind.cooldownRefund:
        final comp = sourceSlotIndex != null
            ? activeCompanions[sourceSlotIndex]
            : null;
        if (comp != null) {
          // A closed window starts from no haste, not from its last value.
          if (comp.basicHasteTimer <= 0) comp.basicHasteMultiplier = 1.0;
          comp.basicHasteTimer = max(comp.basicHasteTimer, effectDuration);
          comp.basicHasteMultiplier = min(
            comp.basicHasteMultiplier,
            CosmicAbilityRuntime.buffHasteMultiplier,
          );
          // Pip Earth: a dart's first kill hands back a share of the
          // special's interval. It was a flat 0.45 s, which a slow Pip
          // barely felt and a bred one's four darts turned into a special
          // that was ready again the moment it went off (its interval is
          // under 1.5 s by then; 2026-10-20).
          if (effect == AbilityEffectKind.cooldownRefund) {
            comp.specialCooldown = max(
              0,
              comp.specialCooldown -
                  kPipEarthRefundShare * comp.effectiveSpecialCooldown,
            );
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
              ally.damageAmpMultiplier = max(
                ally.damageAmpMultiplier,
                effectPower.clamp(kMaskIceAmpMin, kMaskIceAmpMax).toDouble(),
              );
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
        if (dist > 0.01) {
          enemy.position += (dir / dist) * CosmicAbilityRuntime.carryHitPush;
        }
        break;
      case AbilityEffectKind.alchemyBonus:
        _healOrb(effectPower * CosmicAbilityRuntime.flowerObjectiveShare);
        break;
      case AbilityEffectKind.flower:
        // Wing+Plant: the beam's kills drop flowers and the flowers are the
        // reward — collected, they power up the wing
        // (WingBeamRules.plantStackBonus). The beam used to heal the orb on
        // every tick as well, which out-healed everything the orb took
        // (1.4-3.7x) and buried the power-up the design is about.
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
    // Ranging Shots: the autos that landed since the last beam paid for a
    // longer one. Spent here, once, however many beams this cast opens.
    final banked = _isMasteryWing(sourceSlotIndex)
        ? _wingStateFor(sourceSlotIndex).takeBankedBeamTime()
        : 0.0;
    // The cast's one sound, sized to how long the beam will hold.
    final first = beams.first;
    onSound?.call(SoundCue.forWingBeam(first.element, first.duration + banked));
    for (final beam in beams) {
      final own = _ActiveWingBeam(
        descriptor: beam,
        sourceSlotIndex: sourceSlotIndex,
        origin: origin,
        angle: angle,
      )..life += banked;
      if (!_addWingBeam(own)) continue;
      // Wing+Earth: the orb co-fires a mirror laser alongside the wing.
      if (beam.element == 'Earth') {
        _addWingBeam(
          _ActiveWingBeam(
            descriptor: beam,
            sourceSlotIndex: sourceSlotIndex,
            origin: orb.position,
            angle: angle,
            anchorToOrb: true,
          ),
          keep: own,
        );
      }
      // Wing+Spirit: the beam tethers to the SHIP, and the ship fires its own
      // at whatever is nearest.
      //
      // The board has always said so; nothing implemented it. It is the same
      // shape as Earth's orb co-fire, one anchor over — and because the beam
      // updater re-aims every frame toward its own target, a ship-anchored
      // beam tracks the nearest enemy on its own without any new targeting.
      //
      // Earth's second beam and this one differ in the way that matters: the
      // orb never moves, so Earth's is a fixed second line, where the ship is
      // wherever the player has flown it. Spirit turns the thing the player
      // steers into the weapon, which is the identity the board was reaching
      // for.
      if (beam.element == 'Spirit' && !ship.isDead) {
        _addWingBeam(
          _ActiveWingBeam(
            descriptor: beam,
            sourceSlotIndex: sourceSlotIndex,
            origin: ship.position,
            angle: angle,
            anchorToShip: true,
          ),
          keep: own,
        );
      }
    }
  }

  /// Puts [beam] in the air under the beam cap.
  ///
  /// At the cap the caster gives up its own oldest beam, never another
  /// Wing's and never a co-beam (the orb's or the ship's), and never [keep] —
  /// the beam this one belongs with. The cap used to drop whatever was first
  /// in the list, so a Light Wing splitting on every kill pushed every other
  /// Wing's beam off the field (2026-10-20 audit). When the caster has nothing
  /// of its own to give up, the new beam is the one that does not fire.
  bool _addWingBeam(_ActiveWingBeam beam, {_ActiveWingBeam? keep}) {
    if (_activeWingBeams.length >= WingBeamRules.beamCap) {
      var evict = -1;
      for (var i = 0; i < _activeWingBeams.length; i++) {
        final b = _activeWingBeams[i];
        if (b.sourceSlotIndex != beam.sourceSlotIndex ||
            b.isCoBeam ||
            identical(b, keep)) {
          continue;
        }
        evict = i;
        break;
      }
      if (evict < 0) return false;
      _activeWingBeams.removeAt(evict);
    }
    _activeWingBeams.add(beam);
    return true;
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
      } else if (beam.anchorToShip) {
        // Follows the ship, and stops if the ship is destroyed — the tether
        // is to the ship, not to the place the ship used to be.
        if (!ship.isDead) {
          beam.origin = ship.position;
        } else {
          beam.life = 0;
        }
      } else {
        final caster = activeCompanions[beam.sourceSlotIndex];
        if (caster != null && !caster.isDead) {
          beam.origin = caster.position;
        }
      }
      // Update angle to face the current beam target so the visual
      // tracks live. _beamTargetEndpoint already retargets per tick;
      // we mirror that here for the charge-up rendering.
      Offset? endNow;
      if (beam.descriptor.targetPolicy != WingBeamTargetPolicy.ring) {
        endNow = _beamTargetEndpoint(beam);
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
        // Shared with open space (wing_vfx.dart).
        emitWingChargeVisual(
          descriptor: beam.descriptor,
          center: beam.origin,
          progress: progress,
          particleRoom: _vfx.length < kWingChargeParticleBudget,
          rng: _rng,
          emit: _emitWingParticle,
          segment: _emitWingSegment,
        );
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

      // Found once a frame: the line beams already have it from the aim above.
      final end = endNow ?? _beamTargetEndpoint(beam);
      // The render pass paints the beam itself once a frame from here (see
      // _renderWingBeams; ring beams paint their perimeter in
      // _renderWingRings): nothing is laid into _beamFx per frame any more.
      // Then the particle accents that keep it reading as a living stream,
      // bursting where the beam is held rather than where a sweep runs out.
      // Shared with open space (wing_vfx.dart).
      beam.drawEnd = end;
      if (_vfx.length < kWingBeamParticleBudget) {
        emitWingBeamParticles(
          descriptor: beam.descriptor,
          origin: beam.origin,
          end: beam.focusAt ?? end,
          tetherTo: ship.position,
          beamLife: beam.life,
          rng: _rng,
          emit: _emitWingParticle,
          heat: WingBeamRules.heatGlow(beam.heat.current),
        );
      }

      beam.tickTimer -= dt;
      if (beam.tickTimer > 0) continue;
      beam.tickTimer += beam.descriptor.tickInterval;
      _resolveBeamTick(beam, end);
    }
    if (_pendingWingBeams.isNotEmpty) {
      for (final beam in _pendingWingBeams) {
        _addWingBeam(beam, keep: beam.refractedFrom);
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
      CosmicSurvivalCompanion? bestAlly;
      var onShip = false;
      if (!ship.isDead && ship.maxHp > 0) {
        final dist = (ship.position - beam.origin).distance;
        if (dist <= d.range) {
          final f = ship.currentHp / ship.maxHp;
          if (f < bestFraction) {
            bestFraction = f;
            bestPos = ship.position;
            onShip = true;
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
          bestAlly = c;
          onShip = false;
        }
      }
      beam.aimedAlly = bestAlly;
      beam.aimedAtShip = onShip;
      if (bestPos != null) return bestPos;
      return fallback;
    }
    CosmicSurvivalEnemy? target;
    if (beam.isRefraction) {
      target = _refractionTarget(beam);
    } else if (d.targetPolicy == WingBeamTargetPolicy.lowestHealthEnemy) {
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
    beam.aimedAt = target;
    Offset? aim = target?.position;
    if (aim == null) {
      SurvivalBoss? bestBoss;
      double bestDist = d.range;
      for (final b in allLivingBosses) {
        final bd = (b.position - beam.origin).distance;
        if (bd <= bestDist) {
          bestDist = bd;
          bestBoss = b;
        }
      }
      aim = bestBoss?.position;
    }
    beam.focusAt = aim;
    if (aim == null) return fallback;
    // Focus: a beam aimed at the nearest body runs on through it to its full
    // range, so the line cuts through the crowd behind; it used to stop on
    // the body, and in a horde that was most of the beams on the field
    // touching one body each (2026-10-20 audit). Spirit's beam from the ship
    // aims the same way. Blood's ends on the body it has locked.
    if (WingBeamRules.sweeps(d) || beam.anchorToShip) {
      return WingBeamRules.sweepEnd(beam.origin, aim, d.range, beam.angle);
    }
    return aim;
  }

  /// One Water beam tick's heal on whoever the beam is on: a share of that
  /// ally's (or the ship's) own maximum, larger with the Wing's Beauty.
  void _healWingWaterTarget(_ActiveWingBeam beam) {
    final share = WingBeamRules.waterHealShare(
      _effectiveBeauty(beam.sourceSlotIndex),
    );
    final ally = beam.aimedAlly;
    if (ally != null && !ally.isDead && ally.maxHp > 0) {
      final healed = _healCompanion(ally, max(1.0, ally.maxHp * share));
      _recordHeal(healed, target: 0, sourceSlot: beam.sourceSlotIndex);
    } else if (beam.aimedAtShip && !ship.isDead && ship.maxHp > 0) {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, ship.currentHp + ship.maxHp * share);
      _recordHeal(
        ship.currentHp - before,
        target: 1,
        sourceSlot: beam.sourceSlotIndex,
      );
    }
  }

  void _resolveBeamTick(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    // Focus (2026-10-20): the body the beam is held on takes its tick at the
    // beam's heat, which climbs the longer it stays there; every other body
    // the line crosses takes the unheated tick. The rings and Lightning's
    // blast have no heat. Water's beam is held on an ally rather than a
    // body: it heats on that ally, and every body it crosses takes its heat.
    final heats = WingBeamRules.heats(d);
    final onAlly = d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip;
    final focus = heats && !onAlly ? beam.aimedAt : null;
    final Object? heldOn = onAlly
        ? (beam.aimedAlly ?? (beam.aimedAtShip ? ship : null))
        : focus;
    final heat = heats ? beam.heat.tick(heldOn, d.tickInterval) : 1.0;
    final lineShare = !heats
        ? 1.0
        : onAlly
        ? heat
        : WingBeamRules.lineShare;
    // Wing+Lava: beam carves a glowing scar that does ground DoT.
    // Drop a small lava zone where the beam is held per tick so a
    // sustained beam paints a damaging line across the field (a sweeping
    // beam's tip is past the crowd, out at full range).
    // Scar size scales with beauty, life with intelligence.
    if (d.element == 'Lava') {
      _appendCompanionProjectile(
        WingBeamRules.lavaScar(
          d,
          beam.focusAt ?? end,
          beauty: _effectiveBeauty(beam.sourceSlotIndex),
          intelligence: _effectiveIntelligence(beam.sourceSlotIndex),
          sourceSlotIndex: beam.sourceSlotIndex,
        ),
      );
    }
    if (d.healPerTick > 0 &&
        d.targetPolicy == WingBeamTargetPolicy.lowestHealthAllyOrShip) {
      // Wing+Water: "targets lowest-health ally or ship and heals % of max
      // HP". The beam found that ally and then healed the ship, the orb and
      // itself, never the one it was on (2026-10-20 audit). It now mends
      // whoever it is aimed at by a share of that one's own health bar, and
      // keeps its share for the orb.
      _healWingWaterTarget(beam);
      _healOrb(d.healPerTick * WingBeamRules.orbHealShare);
    } else if (d.healPerTick > 0) {
      // Crystal's and Light's heal is the beam's own damage coming back, so
      // it runs at the beam's heat.
      final heal = d.healPerTick * heat;
      if (!ship.isDead) {
        ship.currentHp = min(ship.maxHp, ship.currentHp + heal);
      }
      _healOrb(heal * WingBeamRules.orbHealShare);
      final comp = activeCompanions[beam.sourceSlotIndex];
      if (comp != null && !comp.isDead) {
        comp.currentHp = min(comp.maxHp, comp.currentHp + heal.round());
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
      final radius = WingBeamRules.hitRadius(d);
      final riderScales = WingBeamRules.riderScales(d.tickEffect);
      // The grid around the line's middle, not its start: a sweeping beam
      // runs out to full range, and a circle round the wing that reaches its
      // tip visits four times the ground the line can touch.
      final mid = Offset(
        (beam.origin.dx + end.dx) * 0.5,
        (beam.origin.dy + end.dy) * 0.5,
      );
      final reach =
          (end - beam.origin).distance * 0.5 + radius + _maxEnemyRadius;
      _visitEnemiesNear(mid, reach, (enemy) {
        final distance = _distanceToSegment(enemy.position, beam.origin, end);
        if (distance > enemy.radius + radius) return false;
        // Wing+Steam: the beam executes the first enemy it touches and
        // erupts a field of steam clouds at the kill site. A beam held on a
        // body touches that one first; the line runs on past it.
        if (d.element == 'Steam' &&
            !beam.steamKillUsed &&
            !enemy.isDead &&
            (focus == null || identical(enemy, focus))) {
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
        final share = identical(enemy, focus) ? heat : lineShare;
        final plantBonus = d.element == 'Plant'
            ? _wingPlantStackBonus(beam.sourceSlotIndex)
            : 1.0;
        // A sustained beam is the special's output, but it is not a cast:
        // tying six seconds of ticks to one cast id would leave the volley
        // reading as "fully landed" for as long as the beam burned. It gets
        // the attribution and none of the cast accounting.
        // Burn Through: the beam earns its ramp by staying on one body, so
        // the dwell is counted here, where the beam actually holds it.
        var beamMastery = 1.0;
        if (mastery.enabled && _isMasteryWing(beam.sourceSlotIndex)) {
          final carried = _wingStateFor(beam.sourceSlotIndex).takeCarriedRamp();
          if (carried > 0 && enemy.wingBeamDwell <= 0) {
            enemy.wingBeamDwellSlot = beam.sourceSlotIndex;
            enemy.wingBeamDwell = carried;
          }
          enemy.noteWingBeamDwell(beam.sourceSlotIndex, d.tickInterval);
          beamMastery = _wingBoreMultiplier(beam.sourceSlotIndex, enemy);
        }
        final beforeBeamHp = enemy.hp;
        _damageEnemy(
          enemy,
          _beamDamageForEnemy(d, enemy, share) * plantBonus * beamMastery,
          sourceSlotIndex: beam.sourceSlotIndex,
          masterySource: MasteryDamageSource.special,
          masteryUplift: wingUpliftFraction(beamMastery),
        );
        if (beforeBeamHp > 0 && enemy.hp <= 0) {
          _noteWingBeamKill(beam.sourceSlotIndex, enemy);
        }
        _applyAbilityEffectToEnemy(
          d.tickEffect,
          enemy,
          beam.origin,
          riderScales ? d.effectPower * share : d.effectPower,
          WingBeamRules.lineEffectRadius(d),
          d.effectDuration,
          sourceSlotIndex: beam.sourceSlotIndex,
        );
        // Wing+Ice: each tick ramps frost buildup; once full the enemy
        // snaps into a hard freeze and the buildup resets. The frost holds
        // while the beam stays on it and thaws once it moves off.
        if (d.element == 'Ice' && !enemy.isDead) {
          enemy.frostGrace = WingBeamRules.frostGrace(d);
          enemy.frostBuildup = min(
            1.0,
            enemy.frostBuildup + WingBeamRules.frostPerTick,
          );
          if (enemy.frostBuildup >= 1.0) {
            enemy.frostBuildup = 0;
            enemy.slowTimer = max(enemy.slowTimer, WingBeamRules.freezeHold);
            enemy.slowMultiplier = min(
              enemy.slowMultiplier,
              WingBeamRules.freezeSlow,
            );
            enemy.knockbackVelocity = Offset.zero;
            _spawnHitSpark(enemy.position, elementColor('Ice'));
          }
        }
        // Wing+Light: a beam kill refracts into two smaller beams that
        // hunt nearby enemies for the rest of the beam's duration.
        if (!beforeDead && enemy.isDead && d.element == 'Light') {
          _spawnLightSplitBeams(beam, enemy.position);
        }
        // Wing+Plant: enemies killed by the beam turn into flower
        // pickups. Orb collects them to power up the wing.
        if (!beforeDead && enemy.isDead && d.element == 'Plant') {
          _spawnFlowerPickup(enemy.position, beam.sourceSlotIndex);
        }
        return false;
      });
    }

    // A boss takes the authored tick wherever the line crosses it, held or
    // not: its health was tuned against that, and the heat is for bodies.
    for (final boss in allLivingBosses) {
      final hitsBoss = d.targetPolicy == WingBeamTargetPolicy.ring
          ? _withinRange(beam.origin, boss.position, d.radius + boss.radius)
          : _distanceToSegment(boss.position, beam.origin, end) <=
                boss.radius + WingBeamRules.hitRadius(d);
      if (hitsBoss) {
        // Burn Through on a boss, as on a body: a boss is the one enemy a
        // beam is held on longest, and the ramp reached bodies only
        // (2026-10-21 mastery sweep). The focus heat stays the bodies'.
        var beamMastery = 1.0;
        if (mastery.enabled && _isMasteryWing(beam.sourceSlotIndex)) {
          boss.noteWingBeamDwell(beam.sourceSlotIndex, d.tickInterval);
          beamMastery = _wingBoreMultiplier(beam.sourceSlotIndex, boss);
        }
        damageBoss(
          d.damagePerTick * beamMastery,
          attackElement: d.element,
          sourceSlotIndex: beam.sourceSlotIndex,
          target: boss,
          masterySource: MasteryDamageSource.special,
          masteryUplift: wingUpliftFraction(beamMastery),
        );
        if (d.element == 'Ice') _frostBoss(boss, d);
      }
    }
  }

  /// Wing+Ice frost on a boss. It builds as on a body, but full it chills
  /// rather than freezes: [_applyBossCrowdControl] holds the slow at the
  /// boss floor and shortens it, because a frozen boss ends the fight it is
  /// the centre of.
  void _frostBoss(SurvivalBoss boss, WingBeamEffect d) {
    if (boss.isDead || boss.isSpawning) return;
    boss.frostGrace = WingBeamRules.frostGrace(d);
    boss.frostBuildup = min(
      1.0,
      boss.frostBuildup + WingBeamRules.frostPerTick,
    );
    if (boss.frostBuildup < 1.0) return;
    boss.frostBuildup = 0;
    _applyBossCrowdControl(
      boss,
      AbilityEffectKind.freeze,
      WingBeamRules.freezeHold,
    );
    _spawnHitSpark(boss.position, elementColor('Ice'));
  }

  // Returns true if the slot's Horn+Light barrier projectile is still
  // alive on the field. Used to lock the horn in place during its
  // barrier channel + to short-circuit the ally-protection check.
  bool _hornLightBarrierActive(int slotIndex) {
    for (final p in companionProjectiles) {
      if (p.sourceSlotIndex == slotIndex && isHornLightBarrier(p)) return true;
    }
    return false;
  }

  // Returns the position+radius of any active Horn+Light barrier
  // (regardless of caster) so ally companions inside it get the
  // damage-reduction protect.
  (Offset, double)? _activeHornLightBarrier() {
    for (final p in companionProjectiles) {
      // Barrier protect radius ≈ visual size of the zone.
      if (isHornLightBarrier(p)) return (p.position, hornLightProtectRadius(p));
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
  }) => hornStatScale(stat, perPoint: perPoint, min: min, max: max);

  // Per-element kill-effect dispatcher for horn specials. Called
  // from _killEnemy when an enemy dies inside the casting horn's
  // active window. Steam, Lava, and Blood each get their unique
  // post-kill payoff per the design board.
  void _applyHornSpecialKillEffect(
    CosmicSurvivalCompanion comp,
    CosmicSurvivalEnemy enemy,
    int? sourceSlotIndex,
  ) {
    // Steam and Lava pay out on what the SLAM killed (the board: "if the
    // slam KILLS", "enemies killed by the slam"), not on any kill in the
    // window. Gated on the window alone, every flame kill threw more
    // flames and every kill reset Steam's cooldown: in a horde Lava ran to
    // 2,195 kills in 45s (12.8x the median ability, measured 2026-10-07).
    // The ram's hit set is live through the slam's own damage call and
    // cleared when the charge ends, so this is exactly the slam.
    final slamKill = comp.chargeHitIds?.contains(enemy.hashCode) ?? false;
    switch (comp.member.element) {
      case 'Steam':
        if (!slamKill) break;
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
        final steam = hornSteamKillScales(steamBeauty, steamIntel);
        _appendCompanionProjectile(
          hornSteamKillGeyser(
            position: enemy.position,
            abilityAtk: comp.abilityAtk,
            sizeScale: steam.size,
            durScale: steam.dur,
            sourceSlot: sourceSlotIndex,
          ),
        );
        break;
      case 'Lava':
        if (!slamKill) break;
        // Explosion VFX at the kill site (replaces the persistent
        // pool — user flagged it as too cheesy).
        _spawnLavaKillExplosion(enemy.position);
        // Seek radius + flame count scale with caster's beauty —
        // high-stat Lava horns blanket a wider kill zone with
        // more chasers.
        final lavaBeauty = sourceSlotIndex != null
            ? _effectiveBeauty(sourceSlotIndex)
            : 3.0;
        final seek = hornLavaSeek(lavaBeauty);
        final seekRadius = seek.radius;
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
        final flameCount = min(seek.maxFlames, nearbyTargets.length);
        for (var i = 0; i < flameCount; i++) {
          final tgt = nearbyTargets[i % nearbyTargets.length];
          final dir = tgt.position - enemy.position;
          // Short life — a flame fizzles if it doesn't reach a target
          // quickly, so the field doesn't get polluted.
          _appendCompanionProjectile(
            hornLavaSeekerFlame(
              position: enemy.position,
              angle: atan2(dir.dy, dir.dx),
              abilityAtk: comp.abilityAtk,
              sourceSlot: sourceSlotIndex,
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
        final heal = hornBloodKillHeal(comp.maxHp, bloodBeauty);
        pushHornFx(
          _hornFx,
          HornFx.siphon(from: enemy.position, to: comp.position),
        );
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

  // The sinks Wing's shared per-frame emitters (wing_vfx.dart) draw into:
  // survival's particle pool and beam list.
  void _emitWingParticle(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    Color color,
  ) => _vfx.add(
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

  void _emitWingSegment(
    Offset start,
    Offset end,
    Color color,
    double width,
    double life,
    String? wingElement,
  ) => _spawnBeam(
    start,
    end,
    color,
    width: width,
    life: life,
    wingElement: wingElement,
  );


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

  /// A shared emitter's particle, into the pool. Callers gate on the cap.
  /// Whether the ambient pool can take another Kin/Mane particle; the
  /// shared emitters stop where survival's own loops broke off.
  bool _kinVfxHasRoom() => _vfx.length < 150;

  void _emitVfxParticle(
    double x,
    double y,
    double vx,
    double vy,
    double size,
    double life,
    Color color, {
    bool arc = false,
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
  }

  // Horn+Lightning chain blast — one-shot alchemical particle storm
  // radiating from the impact. ~40 particles fanning outward in all
  // directions at varying speeds, with mixed life so the cloud
  // lingers and flashes for ~0.6s instead of disappearing in one
  // frame. Sized off the blast radius so a bigger absorb-discharge
  // reads as a fuller storm.
  void _spawnLightningChainBurst(Offset center, double blastRadius) {
    emitHornLightningChainBurst(
      center,
      blastRadius,
      145 - _vfx.length,
      _rng,
      _emitVfxParticle,
    );
    // Bright central flash hit-spark for the impact pop.
    _spawnHitSpark(center, hornLightningFlashColor);
  }

  // Horn+Lightning post-dash storm visual. Grows around the horn
  // as the brew counts down. Same crackling-orb feel as the Wing
  // Lightning charge, just elemental-colored for horns.
  void _renderHornLightningStormBrew(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    emitHornLightningStormBrew(
      comp.position,
      comp.hornPostDashWindUpTimer,
      _rng,
      _emitVfxParticle,
    );
  }

  // Horn+Fire: drop a burning trail segment behind the horn during
  // the charge. Cheap stationary DoT zone — overlapping spawns
  // paint a continuous burn lane through the charge path.
  void _spawnFireTrailSegment(int slotIndex, CosmicSurvivalCompanion comp) {
    _appendCompanionProjectile(
      hornFireTrailSegment(
        position: comp.position,
        abilityAtk: comp.abilityAtk,
        sourceSlot: slotIndex,
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
    emitHornLavaChargeTelegraph(
      comp.position,
      progress,
      _rng,
      _emitVfxParticle,
    );
  }

  // Horn+Lava: explosion VFX on enemy kill — radial fire burst at
  // the kill site. Replaces the persistent pool the user flagged
  // as cheesy. Pure VFX, no projectile damage (the dmg-on-kill
  // is delivered by the homing flames spawned alongside).
  void _spawnLavaKillExplosion(Offset center) {
    if (_vfx.length >= 140) return;
    emitHornLavaKillExplosion(center, _rng, _emitVfxParticle);
    _spawnHitSpark(center, kHornLavaKillSparkColor);
  }

  // Horn+Ice: drop a single ice-wall segment at the horn's current
  // position during its sideways dash. Segments overlap (spawn rate
  // is timed to ~28px between drops at the standard dash speed) to
  // form a continuous wall. Each segment taunts + slows; Phase 5
  // will wire the projectile-reflect behavior.
  void _spawnIceWallSegment(int slotIndex, CosmicSurvivalCompanion comp) {
    // Each segment bounces enemy projectiles back at the nearest enemy.
    _appendCompanionProjectile(
      hornIceWallSegment(
        position: comp.position,
        maxHp: comp.maxHp,
        abilityAtk: comp.abilityAtk,
        sourceSlot: slotIndex,
      ),
    );
  }

  /// The ram against bosses: any living boss whose body the Horn is within
  /// [sweepRadius] of takes the charge, once per cast, as a body does.
  ///
  /// The sweeps only walked [enemies], so a Horn's whole cast went straight
  /// through every boss it rammed (2026-10-20 audit). Bosses are few, so they
  /// are tested here directly; the hit goes through [damageBoss], which
  /// applies the Horn's own lower damage against bosses, the matchup and the
  /// shield.
  void _hornRamBosses(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double sweepRadius,
  ) {
    final hit = comp.chargeHitIds;
    if (hit == null || !anyBossAlive) return;
    for (final boss in allLivingBosses) {
      if (boss.isSpawning) continue;
      final id = identityHashCode(boss);
      if (hit.contains(id)) continue;
      if (!_withinRange(
        comp.position,
        boss.position,
        boss.radius + sweepRadius,
      )) {
        continue;
      }
      hit.add(id);
      damageBoss(
        comp.chargeDamage,
        attackElement: comp.member.element,
        sourceSlotIndex: slotIndex,
        target: boss,
      );
    }
  }

  // Standard horn charge kick-off — sets the dash target/timer from
  // the current companion position toward attackTarget. Shared by
  // the immediate-cast path and the wind-up completion path.
  void _startHornCharge(
    CosmicSurvivalCompanion comp,
    Offset attackTarget,
    double requestedChargeTimer,
  ) {
    final dash = hornStandardDash(
      comp.position,
      attackTarget,
      comp.chargeOvershootDistance,
      comp.chargeSpeedMultiplier,
      requestedChargeTimer,
    );
    comp.chargeTarget = dash.target;
    comp.chargeTimer = dash.timer;
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
        final captureRadius = hornDarkCaptureRadius(
          _effectiveBeauty(slotIndex),
        );
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
        final dash = hornDarkEdgeDash(
          comp.position,
          comp.windUpFireAngle,
          comp.chargeOvershootDistance,
          comp.chargeSpeedMultiplier,
        );
        comp.chargeTarget = dash.target;
        comp.chargeHitIds = <int>{};
        comp.chargeTimer = dash.timer;
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
    final auraRadius = hornDarkAuraRadius(_effectiveBeauty(slotIndex));
    final pullSpeed = hornDarkPullSpeed(comp.windUpTimer); // ramp 90 → 310 px/s
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
    emitHornDarkVoidBrew(
      comp.position,
      comp.windUpTimer,
      _rng,
      _emitVfxParticle,
    );
  }

  // Horn+Crystal wind-up visual: crystal grains drawn in onto the horn
  // while its shards grow on the body (drawHornWindUpOverlay in
  // _renderCompanion), telegraphing the bulwark it carries on the dash.
  void _renderHornCrystalOrbit(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    emitHornCrystalGather(
      comp.position,
      comp.windUpTimer,
      _rng,
      _emitVfxParticle,
    );
  }

  // Horn+Spirit wind-up visual: ghostly phantom orbs swarm the horn,
  // gathering inward then orbiting tightly. They'll release outward
  // as taunt-spreading decoys when the dash kicks off.
  void _renderHornSpiritSwarm(CosmicSurvivalCompanion comp) {
    if (_vfx.length >= 130) return;
    emitHornSpiritSwarm(
      comp.position,
      comp.windUpTimer,
      _rng,
      _emitVfxParticle,
    );
  }

  // Horn+Air PASSIVE: enemies inside the aura are continuously
  // blown toward the arena's outer ring. An inner deadzone (90px) lets
  // the horn still engage close enemies with its basic attack; only
  // enemies further out get shoved away. Visualized by wind-particle
  // bursts that fly outward from the deadzone edge to the aura rim, so
  // the player can see the push range without a hardcoded ring.
  //
  // The aura is the horn's, but the push is away from the ORB, the
  // centre of the arena: pushed away from the horn, which stands by the
  // orb, every body between the two was shoved into the orb (2026-10-20
  // audit). Open space has no orb and keeps the horn's own push.
  void _applyHornAirPassive(
    int slotIndex,
    CosmicSurvivalCompanion comp,
    double dt,
  ) {
    // Aura radii + push speed scale with intelligence — a high-stat
    // Air horn projects its wind aura further and pushes harder.
    final aura = hornAirAura(_effectiveIntelligence(slotIndex));
    final innerRadius = aura.inner;
    final auraRadius = aura.outer;
    final pushSpeed = aura.push;
    final centre = orb.position;
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
      // Outward from the orb; from the horn only for a body on the orb.
      var ox = enemy.position.dx - centre.dx;
      var oy = enemy.position.dy - centre.dy;
      var outward = sqrt(ox * ox + oy * oy);
      if (outward < 0.01) {
        ox = dx;
        oy = dy;
        outward = dist;
      }
      enemy.position = Offset(
        enemy.position.dx + ox / outward * speed * dt,
        enemy.position.dy + oy / outward * speed * dt,
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
      comp.hornAirParticleTimer = HornRules.airParticleInterval;
      emitHornAirWind(
        comp.position,
        innerRadius,
        auraRadius,
        _rng,
        _emitVfxParticle,
        awayFrom: centre,
      );
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
    comp.hornMudTrailTimer = hornMudInterval(_effectiveIntelligence(slotIndex));
    // Tiny per-spawn position jitter so the trail doesn't read as a
    // perfectly straight pixel line when the horn moves in a line.
    final jitter = Offset(
      (_rng.nextDouble() - 0.5) * 8.0,
      (_rng.nextDouble() - 0.5) * 8.0,
    );
    _appendCompanionProjectile(
      hornMudSludge(
        position: comp.position + jitter,
        abilityAtk: comp.abilityAtk,
        sourceSlot: slotIndex,
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
    final auraScale = hornPoisonAuraScale(_effectiveIntelligence(slotIndex));
    final auraRadius = HornRules.poisonAuraRadius * auraScale;
    final tickDamage = max(1.0, comp.abilityAtk * 0.18);
    _visitEnemiesNear(comp.position, auraRadius, (enemy) {
      if (enemy.isDead) return false;
      if (!_withinRange(comp.position, enemy.position, auraRadius)) {
        return false;
      }
      _damageEnemy(enemy, tickDamage, sourceSlotIndex: slotIndex);
      return false;
    });
    // A boss the Horn is standing against breathes it too.
    _damageBossesNear(
      comp.position,
      auraRadius,
      tickDamage,
      sourceSlotIndex: slotIndex,
      attackElement: 'Poison',
    );
    // Faint visible-aura puff at the horn's position. Short-lived so
    // a moving horn paints a soft poison trail without piling sigils.
    _appendCompanionProjectile(
      hornPoisonAuraPuff(
        position: comp.position,
        auraScale: auraScale,
        sourceSlot: slotIndex,
      ),
    );
  }

  // Wing+Lightning: after the 3s charge, fire a single massive blast
  // along the beam line — one big damage event, not a sustained beam.
  // Blast magnitude inherits damagePerTick (which already scales with
  // caster stats), per design that "scaling stats only affect blast
  // size, not charge time".
  void _resolveLightningBlast(_ActiveWingBeam beam, Offset end) {
    final d = beam.descriptor;
    // The element accent, moved here from the cast: it is the blast.
    onSound?.call(SoundCue.elementLightning);
    // Wide bright beam flash for the blast itself (wing_vfx.dart).
    emitWingLightningBlastFlash(
      descriptor: d,
      origin: beam.origin,
      end: end,
      segment: _emitWingSegment,
    );
    final radius = WingBeamRules.blastRadius(d);
    // One-shot blast damage. ~18× per-tick — comparable to the total
    // damage a sustained 2.8× chargeBlast beam would deal over its
    // post-charge window, compressed into a single hit.
    final blastDamage = d.damagePerTick * WingBeamRules.blastDamageScale;
    // The blast runs the full line (it sweeps, as the beam would), so the
    // grid is visited round the line's middle rather than the wing.
    final mid = Offset(
      (beam.origin.dx + end.dx) * 0.5,
      (beam.origin.dy + end.dy) * 0.5,
    );
    final reach = (end - beam.origin).distance * 0.5 + radius + _maxEnemyRadius;
    _visitEnemiesNear(mid, reach, (enemy) {
      if (enemy.isDead) return false;
      final distance = _distanceToSegment(enemy.position, beam.origin, end);
      if (distance > enemy.radius + radius) return false;
      _damageEnemy(enemy, blastDamage, sourceSlotIndex: beam.sourceSlotIndex);
      _applyAbilityEffectToEnemy(
        d.tickEffect,
        enemy,
        beam.origin,
        d.effectPower * WingBeamRules.blastEffectScale,
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
    // cloud life. Cloud size scales with beauty too. The rule is shared
    // with open space (WingBeamRules.steamClouds).
    for (final cloud in WingBeamRules.steamClouds(
      d,
      center,
      _rng,
      beauty: _effectiveBeauty(sourceSlotIndex),
      intelligence: _effectiveIntelligence(sourceSlotIndex),
      sourceSlotIndex: sourceSlotIndex,
    )) {
      _appendCompanionProjectile(cloud);
    }
  }

  // Wing+Light: on a beam kill the original beam refracts into two
  // smaller hunting beams that live out the parent's remaining duration.
  //
  // Once per beam. Only the children used to be marked, so the parent split
  // again on every kill it made — up to the fourteen-beam cap from one cast,
  // pushing other Wings' beams off the field and healing with every one
  // (2026-10-20 audit). And the children re-aimed every frame at the nearest
  // body, which is the body the parent was already on; the board says they
  // target nearby enemies, so each one hunts a body of its own.
  void _spawnLightSplitBeams(_ActiveWingBeam parent, Offset killedAt) {
    if (parent.refractionsDone > 0 || parent.isRefraction) return;
    final remaining = parent.life;
    if (remaining < WingBeamRules.lightSplitMinRemaining) return;
    parent.refractionsDone = 1;
    // High-Beauty Light wings refract into 3 child beams instead of 2,
    // and each child carries a bigger damage fraction (WingBeamRules,
    // shared with open space).
    final beauty = _effectiveBeauty(parent.sourceSlotIndex);
    final child = WingBeamRules.lightSplitChild(
      parent.descriptor,
      remaining: remaining,
      beauty: beauty,
    );
    final offsets = WingBeamRules.lightSplitOffsets(beauty);
    // Where the parent goes next, so no child doubles it.
    parent.aimedAt = _nearestEnemyTo(parent.origin, parent.descriptor.range);
    final prey = _refractionPrey(
      killedAt,
      origin: parent.origin,
      reach: child.range,
      count: offsets.length,
      avoid: parent.aimedAt,
    );
    for (var i = 0; i < offsets.length; i++) {
      final hunted = i < prey.length ? prey[i] : null;
      final toward = hunted?.position;
      final dir = toward == null ? null : toward - parent.origin;
      _pendingWingBeams.add(
        _ActiveWingBeam(
          descriptor: child,
          sourceSlotIndex: parent.sourceSlotIndex,
          origin: parent.origin,
          angle: dir != null && dir.distanceSquared > 0.5
              ? atan2(dir.dy, dir.dx)
              : parent.angle + offsets[i],
          refractedFrom: parent,
          huntTarget: hunted,
        ),
      );
    }
  }

  /// Up to [count] distinct bodies nearest [from] and within [reach] of
  /// [origin], other than [avoid]. Nearest first. Small and kept by insertion,
  /// since [count] is at most three.
  List<CosmicSurvivalEnemy> _refractionPrey(
    Offset from, {
    required Offset origin,
    required double reach,
    required int count,
    CosmicSurvivalEnemy? avoid,
  }) {
    final picked = <CosmicSurvivalEnemy>[];
    final distSq = <double>[];
    final reachSq = reach * reach;
    _visitEnemiesNear(from, reach, (enemy) {
      if (identical(enemy, avoid)) return false;
      if (_distanceSquared(enemy.position, origin) > reachSq) return false;
      final dSq = _distanceSquared(enemy.position, from);
      if (picked.length == count && dSq >= distSq.last) return false;
      var at = picked.length;
      while (at > 0 && distSq[at - 1] > dSq) {
        at--;
      }
      picked.insert(at, enemy);
      distSq.insert(at, dSq);
      if (picked.length > count) {
        picked.removeLast();
        distSq.removeLast();
      }
      return false;
    });
    return picked;
  }

  /// A refraction's body: the one it was given while it lives and stays in
  /// reach, then the nearest to where that one fell that neither its parent
  /// nor a sibling is on. With nothing like that left it takes the nearest
  /// body at all, so it never idles.
  CosmicSurvivalEnemy? _refractionTarget(_ActiveWingBeam beam) {
    final range = beam.descriptor.range;
    final held = beam.huntTarget;
    if (held != null &&
        !held.isDead &&
        _withinRange(beam.origin, held.position, range)) {
      return held;
    }
    final parent = beam.refractedFrom;
    final from = held?.position ?? beam.origin;
    final rangeSq = range * range;
    CosmicSurvivalEnemy? best;
    var bestSq = double.infinity;
    _visitEnemiesNear(from, range, (enemy) {
      if (_distanceSquared(enemy.position, beam.origin) > rangeSq) {
        return false;
      }
      final dSq = _distanceSquared(enemy.position, from);
      if (dSq >= bestSq) return false;
      if (identical(enemy, parent?.aimedAt)) return false;
      for (final other in _activeWingBeams) {
        if (!identical(other, beam) &&
            identical(other.refractedFrom, parent) &&
            identical(other.huntTarget, enemy)) {
          return false;
        }
      }
      bestSq = dSq;
      best = enemy;
      return false;
    });
    beam.huntTarget = best;
    return best ?? _nearestEnemyTo(beam.origin, range);
  }

  // Renders ring-policy wing beams (Poison, Fire) as a churning
  // perimeter ring rather than a starburst of spokes.
  /// Every live, firing line beam, once: the pieces [emitWingBeamSegments]
  /// names for it — the beam, Spirit's cable into the ship and the beam on
  /// from it, a healing beam's core — at full strength, fading over its last
  /// moments ([wingBeamFade]). The dungeons and open space paint theirs the
  /// same way.
  void _renderWingBeams(
    Canvas canvas,
    double cx,
    double cy,
    double viewW,
    double viewH,
  ) {
    if (_activeWingBeams.isEmpty) return;
    final t = stats.timeElapsed;
    for (final beam in _activeWingBeams) {
      final end = beam.drawEnd;
      if (beam.dead || beam.chargeTimer > 0 || end == null) continue;
      final fade = wingBeamFade(beam.life);
      // Focus: a line beam is drawn as hot as it is (pale just landed,
      // white-hot held), its heat pooled on the body it is held on.
      final heats = WingBeamRules.heats(beam.descriptor);
      final glow = heats ? WingBeamRules.heatGlow(beam.heat.current) : null;
      emitWingBeamSegments(
        descriptor: beam.descriptor,
        origin: beam.origin,
        end: end,
        tetherTo: ship.position,
        segment: (start, segEnd, color, width, life, element) {
          final mid = Offset(
            (start.dx + segEnd.dx) * 0.5,
            (start.dy + segEnd.dy) * 0.5,
          );
          final halfLength = (segEnd - start).distance * 0.5;
          if (!_isWithinViewport(
            mid,
            halfLength + width * 2,
            cx,
            cy,
            cx + viewW,
            cy + viewH,
            margin: 28,
          )) {
            return;
          }
          drawAdvancedAbilityBeam(
            canvas: canvas,
            start: start,
            end: segEnd,
            color: color,
            wingElement: element,
            width: width,
            alpha: fade,
            time: t,
            heat: glow,
            focus: segEnd == end ? beam.focusAt : null,
          );
        },
      );
    }
  }

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
        r + kWingRingCullPad,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 32,
      )) {
        continue;
      }
      final fade = wingRingFade(beam.life);
      drawAdvancedWingBeamRing(
        canvas: canvas,
        center: center,
        radius: r,
        width: d.width,
        color: elementColor(d.element),
        element: d.element,
        alpha: fade,
        time: t,
        details: !_reduceAmbientVfx,
      );
    }
  }

  void _spawnFlowerPickup(
    Offset position,
    int sourceSlotIndex, {
    double healAmount = 0,
  }) {
    if (_flowerPickups.length >= WingBeamRules.flowerCap) return;
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
    // Collect radius, magnet reach and pull are WingBeamRules.flowerStep,
    // shared with open space.
    for (final flower in _flowerPickups) {
      flower.life -= dt;
      if (flower.dead) continue;
      final next = WingBeamRules.flowerStep(flower.position, ship.position, dt);
      if (next == null) {
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
      // Magnet pull: flowers within reach accelerate toward the ship,
      // gently far out and snapping in close.
      flower.position = next;
    }
    _flowerPickups.removeWhere((f) => f.dead);
  }

  void _updateSpiritWisps(double dt) {
    // The ship collects them; threshold reached → nuke all non-boss enemies.
    stepMaskSpiritWisps(_spiritWisps, ship.isDead ? null : ship.position, dt, (
      wisp,
    ) {
      final comp = activeCompanions[wisp.sourceSlotIndex];
      if (comp != null && !comp.isDead) {
        comp.maskSpiritWispBank++;
        _spawnHitSpark(ship.position, elementColor('Spirit'));
        if (comp.maskSpiritWispBank >= wisp.clearAt) {
          comp.maskSpiritWispBank = 0;
          _fireMaskSpiritNuke(comp, wisp.damage);
        }
      }
    });
  }

  void _fireMaskSpiritNuke(CosmicSurvivalCompanion comp, double basePower) {
    // Wipes every regular enemy. Bosses are tracked in `activeBoss` /
    // `extraBosses`, not in `enemies`, so they're naturally skipped.
    // SNAPSHOT: killing something here can APPEND to `enemies` — a splitter
    // breaks into smaller bodies on death, and a summoner's brood lands in the
    // same list — so walking the live list throws Concurrent modification mid-
    // frame. `_updateEnemies` already iterates a copy for exactly this reason.
    for (final enemy in List<CosmicSurvivalEnemy>.of(enemies)) {
      if (enemy.isDead) continue;
      _damageEnemy(
        enemy,
        enemy.hp,
        execute: true,
        sourceSlotIndex: comp.slotIndex,
        masterySource: MasteryDamageSource.special,
      );
    }
    // Screen-wash punctuation — flash timer drives a brief overlay
    // (drawn during the render pass) + an outward ring from the ship.
    _maskSpiritNukeFlash = 1.0;
    _maskSpiritNukeOrigin = ship.position;
    _spawnHitSpark(ship.position, elementColor('Spirit'));
    _spawnHitSpark(comp.position, elementColor('Spirit'));
    // Spray spirit motes outward from the ship for extra weight.
    emitMaskSpiritNukeMotes(
      origin: ship.position,
      rng: _rng,
      poolSize: () => _vfx.length,
      emit: _emitVfxParticle,
    );
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
    // (WingBeamRules.plantStackBonus, shared with open space.)
    return WingBeamRules.plantStackBonus(
      comp.abilityKillStacks,
      _effectiveBeauty(sourceSlotIndex),
    );
  }

  double _beamDamageForEnemy(
    WingBeamEffect d,
    CosmicSurvivalEnemy enemy, [
    double heat = 1.0,
  ]) => WingBeamRules.tickDamage(
    d,
    hp: enemy.hp,
    hpFraction: enemy.hpFraction,
    heat: heat,
  );

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
    final step = ManeRuntime.lightningOrbStep(p, dt);
    if (step == null) return false;
    final landed = step.landedAt;
    if (landed != null) _spawnManeLightningShockField(p, landed);
    return true;
  }

  void _spawnManeLightningShockField(Projectile source, Offset target) {
    _appendCompanionProjectile(
      ManeRuntime.lightningShockField(source, target),
      cue: SoundCue.specialManeOrbLand,
    );
    _spawnHitSpark(target, elementColor('Lightning'));
  }

  void _spawnManeEarthQuakePulse(Projectile source) {
    final pulse = ManeRuntime.earthQuakePulse(source, _rng);
    _appendCompanionProjectile(pulse, cue: SoundCue.specialManeQuake);
    _spawnHitSpark(pulse.position, elementColor('Earth'));
  }

  void _updateCompanionProjectiles(double dt) {
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final p = companionProjectiles[i];
      var transferringToOrbit = false;

      // Let meteors fall. A descending meteor is not in play yet: it takes no
      // collisions, lays no trail, does no homing, and does not age. It is
      // somewhere above the field on its way to a committed impact point, and
      // everything it does happens when it lands.
      if (p.isDescending) {
        _spawnLetDescentEmbers(p);
        final landed = CosmicAbilityRuntime.advanceSkyfall(p, dt);
        if (landed) {
          if (p.letDeadfall) {
            _detonateLetDeadfall(p);
          } else {
            _detonateLetSkyfall(p);
          }
        }
        continue;
      }

      // The Mane blade's trailing wisp clump used to be spawned here, two or
      // three real particles per projectile per frame — the emission rate
      // outran the ambient pool's drain rate, so any Mane cast in flight held
      // the pool at its ceiling and starved every other effect in the game.
      // Each Mane painter carries its own wake now (mane_alchemical_vfx.dart).

      // Mane+Dark: the slow void bolt constantly pulls nearby enemies
      // toward its position as it travels. Per design: "constantly
      // pulls enemies towards it, eating low health enemies" — the
      // pull happens every frame; the execute happens on pierce
      // (handled in resolveAbilityPierce).
      if (ManeRuntime.pullsInFlight(p)) {
        final pullR = p.snareRadius;
        _visitEnemiesNear(p.position, pullR, (enemy) {
          if (enemy.isDead) return false;
          // Pull strength stronger when close, weaker at rim.
          final step = ManeRuntime.darkPullStep(
            p.position,
            enemy.position,
            pullR,
            dt,
          );
          if (step != null) enemy.position = enemy.position + step;
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
          // A Pip dart hunts only bodies it has not struck: the nearest body
          // to a dart that has just bounced is the one it bounced off.
          final pipDart = PipRicochet.isSpecialDart(p);
          for (final e in enemies) {
            if (e.isDead) continue;
            final dSq = _distanceSquared(e.position, p.position);
            if (dSq < bestDistSq) {
              if (pipDart && !p.canHitEnemy(identityHashCode(e))) continue;
              bestDistSq = dSq;
              bestTarget = e.position;
            }
          }
          for (final b in allLivingBosses) {
            if (pipDart && p.hitBoss) break;
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
        emitHornProjectileParticles(p, _rng, _emitVfxParticle);
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
        final previousAngle = p.orbitAngle;
        p.orbitAngle += p.orbitSpeed * dt;
        p.position = Offset(
          p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
          p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
        );
        if (p.followShipOrbit) p.orbitCenter = ship.position;
        if (p.masteryCircuit) {
          // Every lap is a fresh pass over the bodies on the rim.
          if ((p.orbitAngle / (2 * pi)).floor() !=
              (previousAngle / (2 * pi)).floor()) {
            p.resetEnemyHits();
          }
          // A blade sweeping the rim points the way it is travelling.
          p.angle = p.orbitAngle + pi / 2;
        }
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
        if (ManeRuntime.shedsDustPuffs(p)) {
          p.trailTimer += dt;
          if (p.trailTimer >= ManeRuntime.dustPuffInterval) {
            p.trailTimer = 0;
            // Sheds are not launches: silent (they used to puff the
            // ship-gun launch every ~0.35 s).
            if (ManeRuntime.dustTrailHasRoom(companionProjectiles)) {
              _appendCompanionProjectile(
                ManeRuntime.dustTrailPuff(p),
                silent: true,
              );
            }
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
            ManeRuntime.earthShrink(p, dt);
          } else if (p.element == 'Steam') {
            // Drop a stationary steam puff under the projectile.
            p.turretTimer += dt;
            while (p.turretTimer >= p.turretInterval) {
              p.turretTimer -= p.turretInterval;
              _appendCompanionProjectile(
                ManeRuntime.steamPuff(p),
                silent: true,
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
      if (p.masteryNoLifetime) {
        // No Horizon: the shot does not fade, but the arena still ends it.
        // Without this the only bound on a Limitless cast would be the
        // projectile pool, which is not a bound anyone should rely on.
        if ((p.position - orb.position).distance > _arenaRadius * 1.08) {
          p.life = 0;
          continue;
        }
      } else if (!isImmortalPlantVine) {
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
      if (isKinGarden(p)) {
        p.abilityGrowthTimer += dt;
        if (p.abilityGrowthTimer >= kKinGardenFlowerInterval) {
          p.abilityGrowthTimer = 0;
          _spawnFlowerPickup(
            kinGardenFlowerSpot(p, _rng),
            p.sourceSlotIndex ?? 0,
            healAmount: kinGardenFlowerHeal(p),
          );
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
      //
      // Budgeted for the same reason turret fire is: this is a
      // self-generating source feeding a capped list that every placement in
      // the game shares. Cost scales with the number of trailing projectiles,
      // which no single emitter knows — a Mystic+Plant cast puts twelve
      // trailing thorns on the field at once, each dropping a puff every fifth
      // of a second with a three-second life, and the twelve together held
      // ~204 of the 220 slots. Everything else silently stopped placing.
      // A circuit is exempt from the "not while orbiting" rule: an element
      // whose special already lays something down as it travels — Dust's
      // cloud, and Steam's geysers through the turret path above — keeps
      // doing it while riding the rim. The capstone adds nothing of its own;
      // it only stops the shot, so what the shot was already doing continues.
      if (p.trailInterval > 0 &&
          !p.stationary &&
          (p.orbitCenter == null || p.masteryCircuit) &&
          companionProjectiles.length < _trailProjectileCeiling) {
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

      // Let's ground never collides. Its zones act through their tick
      // (updatePersistentAbilityEffects) and its vines through
      // _updateLetVines; a contact pass here only re-ran the meteor's own
      // contact behaviour at zero damage — Earth's area sweep included — for
      // every body that brushed the zone's centre.
      if (p.stationary && p.abilityFamily == 'let') continue;
      // An unbounded re-hitter touches on a fixed 60 Hz clock, not per frame.
      if (!p.takeContactTick(dt)) continue;

      // Hit detection vs enemies
      final hitRadius = Projectile.radius * p.radiusMultiplier;
      bool consumed = false;
      // Contact needs centre distance < enemy.radius + hitRadius; the slack
      // covers knockback since the grid was rebuilt this frame.
      _visitEnemiesNear(p.position, hitRadius + _maxEnemyRadius + 12, (enemy) {
        if (p.trapSpent) return false;
        if (p.abilityFamily == 'mask' && p.stationary) p.maxHitsPerEnemy = 1;
        if (!_withinRange(
          p.position,
          enemy.position,
          enemy.radius + hitRadius,
        )) {
          return false;
        }
        // A Light void lets the small walk over it and waits for something
        // heavy (user, 2026-10-21, choosing it over more voids: the first
        // wisps to arrive used to spend every void a cast laid).
        if (p.stationary &&
            p.abilityFamily == 'mask' &&
            p.element == 'Light' &&
            !_isHeavyBody(enemy)) {
          return false;
        }
        final enemyId = identityHashCode(enemy);
        // A capped cast (a Tempest Ring) refuses its own surplus hits here,
        // before damage: a cap counted after the fact is not a cap.
        if (!mastery.allowsHit(p.masteryCastId, enemyId)) return false;
        // The same rule at the projectile level, which applies with or
        // without a mastery path equipped. A piercing projectile is not
        // consumed by a hit and contact is re-tested every frame, so this is
        // what stops a slow one from billing a standing body once a frame.
        if (!p.canHitEnemy(enemyId)) return false;
        p.noteEnemyHit(enemyId);
        final preRootForPlantKill =
            p.piercing && p.abilityFamily == 'mane' && p.element == 'Plant';
        if (preRootForPlantKill) resolveAbilityPierce(p, enemy);
        final wasDead = enemy.isDead;
        // Only the moving pip-special dart counts as "from the ability".
        // Stationary sigil-style placements (fire pools, etc.) also use
        // abilityFamily=='pip' but should not chain-spawn more placements.
        final isPipSpecialDart = PipRicochet.isSpecialDart(p);
        final hpBefore = enemy.hp;
        _damageEnemy(
          enemy,
          p.damage,
          sourceSlotIndex: p.sourceSlotIndex,
          // A dart threading a crowd lays its element's piece on its first
          // kill and every few after ([PipRicochet.killsPerPiece]).
          fromPipSpecial: isPipSpecialDart && PipRicochet.laysPiece(p),
          // Basic attacks leave abilityFamily empty; every special stamps one.
          // That is what a Blood world tithes from.
          autoAttack: p.abilityFamily.isEmpty,
          masteryCastId: p.masteryCastId,
          masterySource: _projectileDamageSource(p),
        );
        final killed = !wasDead && enemy.isDead;
        resolveAbilityHit(p, enemy, killed: killed);
        if (p.piercing) resolveAbilityPierce(p, enemy);
        if (p.letCraterRadius > 0 && !p.letDeadfall) {
          _openLetCrater(p, enemy.position, exclude: enemy);
        }
        // Pip+Water: every kill splashes (handled by the splash kill
        // effect); a kill on the RICOCHET's final hit — no bounces
        // left — erupts an extra huge splash. Radius + damage scale
        // with the caster's beauty. The special dart only: a basic dart
        // never bounces, so every basic kill erupted too (the Pip's
        // auto-attack outdamaged other Pips' 4x in a horde, 2026-10-07).
        // Once a dart: a kill no longer ends the dart, so a dart out of
        // bounces carrying through a crowd would erupt on every body.
        if (killed &&
            isPipSpecialDart &&
            p.element == 'Water' &&
            p.bounceCount <= 0 &&
            !p.pipSplashed &&
            p.sourceSlotIndex != null) {
          p.pipSplashed = true;
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
              // The dart's own damage, not the crowd payload it carries.
              p.damage / p.pipPayload * 2.4 * splashScale,
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
                      effectPower: p.damage / p.pipPayload * 0.22,
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
        if (ManeRuntime.shattersOnHit(p)) {
          p.clustered = true;
          // One burst for the shatter; the shards themselves are silent.
          onSound?.call(SoundCue.specialManeBurst);
          for (final shard in ManeRuntime.mudShards(p, enemy.position)) {
            _appendCompanionProjectile(shard, silent: true);
          }
          consumed = true;
        }
        _spawnProjectileHitSpark(p);
        _triggerChainLightning(
          sourceEnemy: enemy,
          origin: p.position,
          baseDamage: p.damage / p.pipPayload,
          sourceSlotIndex: p.sourceSlotIndex,
          remainingChains: p.chainLightningCharges,
          // Kin+Lightning tesla bypasses the powerup gate.
          requirePowerUp: !_isAnyKinLightningChargeActive(),
        );

        // Ricochet (Pip): prefer tightly-clustered nearby targets so the
        // bounce reads as a snappy chain instead of darting toward distant
        // enemies that are off-screen or behind cover. Only the MOVING dart
        // ricochets and is spent by it ([PipRicochet.isSpecialDart]). Pip
        // also places stationary things — Mud's trail puffs, Fire's pools,
        // Poison's line — and this test used to catch those too, so they were
        // consumed after kPipMaxPierceHits contacts like a dart that had run
        // out of bounces. Since a puff is dropped directly on top of the
        // enemy that is trailing it, it died effectively on spawn, and Mud's
        // "affected enemies PERMANENTLY leave mud trails" never slowed
        // anything (measured: 665 puffs emitted over 900 frames, at most 11
        // alive at once).
        //
        // A kill carries the damage the body did not need on to the next
        // body and costs nothing; a survivor costs a bounce and the falloff
        // (PipRicochet, shared with open space and the dungeons).
        if (isPipSpecialDart) {
          final step = PipRicochet.settle(
            p,
            killed: killed,
            carried: killed
                ? PipRicochet.carriedShare(hpBefore, enemy.hp)
                : 0,
          );
          if (step == PipDartStep.spent) {
            consumed = true;
          } else {
            final next = step == PipDartStep.pierce
                ? null
                : _nextPipDartTarget(
                    p,
                    enemy.position,
                    PipRicochet.nextReach,
                    struck: enemy,
                  );
            if (next != null) onSound?.call(SoundCue.specialPipRicochet);
            PipRicochet.turn(p, next?.position);
          }
        } else if (p.bounceCount > 0) {
          p.bounceCount--;
          final next = _nearestEnemyTo(enemy.position, 110, exclude: enemy);
          if (next != null) {
            p.angle = atan2(
              next.position.dy - p.position.dy,
              next.position.dx - p.position.dx,
            );
            p.life = max(p.life, 0.45);
            p.damage *= p.element == 'Lightning' ? 0.85 : 0.70;
            p.speedMultiplier = max(0.6, p.speedMultiplier * 0.92);
          } else {
            p.bounceCount = 0;
          }
        } else if (!p.piercing) {
          consumed = true;
        } else {
          p.pierceCount++;
          if (p.pierceSpent) consumed = true;
        }
        return true;
      });

      // Hit detection vs every alive boss (primary + extras). Most things
      // strike a boss once; a Mane+Light ring turns round its caster for half
      // a minute, so it strikes again on its own cadence instead of once in
      // its whole life (2026-10-20 audit).
      final ward = _isManeLightRing(p);
      if (!consumed &&
          !p.trapSpent &&
          (!p.hitBoss || (ward && stats.timeElapsed >= p.bossRehitAt))) {
        for (final boss in allLivingBosses) {
          final d = (boss.position - p.position).distance;
          if (d >= boss.radius + hitRadius) continue;
          final isCrystalMane =
              p.abilityFamily == 'mane' && p.element == 'Crystal';
          // A boss still flying in is not in the fight yet. The catapult
          // carries on past it rather than shattering on nothing.
          if (isCrystalMane && boss.isSpawning) continue;
          // A Pip dart's crowd payload is for the crowd: a boss takes the
          // dart (pipSurvivalPayload).
          var bossDamage = p.damage / p.pipPayload;
          if (p.abilityFamily == 'mask') {
            if (p.element == 'Crystal' &&
                p.hitEffect == AbilityEffectKind.split) {
              p.trapSpent = true;
              p.life = min(p.life, 0.3);
              _spawnMaskCrystalShards(p, boss.position);
              if (_maskTrapVisuals.contact(p)) _soundMaskSpring(p);
            } else if (p.element == 'Fire' &&
                p.hitEffect == AbilityEffectKind.burn) {
              p.trapSpent = true;
              p.life = min(p.life, 0.35);
              _spawnMaskFirePool(p, p.position);
              if (_maskTrapVisuals.contact(p)) _soundMaskSpring(p);
            }
          }
          // Mane+Crystal: the board's "if it hits a boss, instantly explodes
          // for huge AOE damage". It used to deal the boss's whole remaining
          // health, so one catapult ended any fight at any wave (2026-10-20
          // audit). Now the boss takes the shot and the burst it sits in, at
          // its element matchup, and the burst catches everything round it.
          if (isCrystalMane) {
            if (boss.shieldUp) {
              boss.shieldUp = false;
              boss.shieldHealth = 0;
              boss.shieldTimer = SurvivalBoss.shieldCooldown;
            }
            bossDamage = p.damage * ManeRuntime.crystalBossHitShare;
            onSound?.call(SoundCue.specialManeShatter);
            _damageEnemiesNear(
              boss.position,
              ManeRuntime.crystalBossBlastRadius,
              p.damage * ManeRuntime.crystalBossBlastShare,
              sourceSlotIndex: p.sourceSlotIndex,
              attackElement: 'Crystal',
              excludeBoss: boss,
            );
            _spawnHitSpark(boss.position, elementColor('Crystal'));
            consumed = true;
          }
          damageBoss(
            bossDamage,
            attackElement: p.element,
            sourceSlotIndex: p.sourceSlotIndex,
            autoAttack: p.abilityFamily.isEmpty,
            target: boss,
            masteryCastId: p.masteryCastId,
            masterySource: _projectileDamageSource(p),
          );
          // Crowd control lands on bosses too. This branch used to deal damage
          // and nothing else, so Mane+Ice — whose whole line is "freezes
          // anything it touches as it travels" — froze every trash mob it
          // passed and left the boss walking.
          for (final effect in [p.pierceEffect, p.hitEffect]) {
            _applyBossCrowdControl(
              boss,
              effect,
              p.effectDuration > 0 ? p.effectDuration : 1.5,
            );
          }
          p.hitBoss = true;
          if (ward) {
            p.bossRehitAt = stats.timeElapsed + kManeLightBossRehitSeconds;
          }
          if (p.letCraterRadius > 0 && !p.letDeadfall) {
            _openLetCrater(p, boss.position, excludeBoss: boss);
          }
          _spawnProjectileHitSpark(p);
          if (PipRicochet.isSpecialDart(p)) {
            // A boss is a body that survives the dart: it costs a bounce and
            // the falloff and the dart goes on to the crowd round it. Every
            // dart used to be spent on its first boss touch, so a boss wave
            // turned the whole volley into one hit each (2026-10-20).
            final step = PipRicochet.settle(p, killed: false);
            if (step == PipDartStep.spent) {
              consumed = true;
            } else {
              final next = step == PipDartStep.pierce
                  ? null
                  : _nextPipDartTarget(
                      p,
                      boss.position,
                      boss.radius + PipRicochet.nextReach,
                    );
              if (next != null) onSound?.call(SoundCue.specialPipRicochet);
              PipRicochet.turn(p, next?.position);
            }
          } else if (!p.piercing ||
              (p.abilityFamily == 'pip' && !p.stationary)) {
            // A Pip placement (a pool, a hole, a poison line, a beacon) is
            // not spent on a boss. Reading the family alone deleted every one
            // of them the moment a boss walked onto it, so a boss never stood
            // in one long enough to take its tick (2026-10-20 audit).
            consumed = true;
          }
          break;
        }
      }

      if (consumed) p.life = 0;
    }

    // Read before the sweep: a returning slash starts where the outgoing one
    // died, and after removeWhere there is nothing left to ask. Rearm has to
    // read its fixtures here for the same reason.
    _spawnMasteryReturns();
    if (mastery.enabled && _maskMastery.isNotEmpty) {
      for (final p in companionProjectiles) {
        if (p.life <= 0) _noteMaskFixtureExpired(p);
      }
    }
    companionProjectiles.removeWhere((p) => p.life <= 0);
  }

  void _maybeFireProjectileTurret(Projectile projectile, double dt) {
    if (projectile.turretInterval <= 0 || projectile.turretDamage <= 0) return;
    // Turret fire yields to authored casts.
    //
    // companionProjectiles is one capped list shared by every placement in the
    // game, and _appendCompanionProjectile simply fails once it is full — so
    // whoever fills it first wins and everyone else silently stops placing
    // anything. Turret shots are the one source that generates itself: a
    // Mystic+Plant cast plants several turrets, each firing every 0.56s for
    // nine seconds, and against a wave that is out-living the damage the chain
    // filled all 220 slots from a single cast.
    //
    // Authored casts are what the player actually pressed a button for, so the
    // self-generating source is the one that has to give way. Stopping at a
    // fraction of the cap leaves that headroom.
    if (companionProjectiles.length >= _turretFireProjectileCeiling) return;
    projectile.turretTimer += dt;
    while (projectile.turretTimer >= projectile.turretInterval) {
      projectile.turretTimer -= projectile.turretInterval;
      final target =
          _nearestEnemyTo(
            projectile.position,
            CosmicAbilityRuntime.turretTargetRange,
          ) ??
          activeBoss;
      if (target == null || (target is SurvivalBoss && target.isDead)) continue;
      final targetPos = target is CosmicSurvivalEnemy
          ? target.position
          : (target as SurvivalBoss).position;
      _appendCompanionProjectile(
        _createCompanionTurretShot(projectile, targetPos),
        cue: SoundCue.combatProjectile,
      );
    }
  }

  /// [cue] is what this launch SOUNDS like, and without one it makes no
  /// sound. It used to default to the generic launch, which put the same
  /// puff on everything appended here — a special's shards, pools, walls,
  /// clouds and sheds, some every 0.35 s for a whole cast — on top of the
  /// sounds those families now have of their own. A real launch says so.
  ///
  /// [silent] silences even a given [cue], for a caller that sometimes
  /// passes one.
  bool _appendCompanionProjectile(
    Projectile projectile, {
    SoundCue? cue,
    bool silent = false,
  }) {
    if (companionProjectiles.length >= _maxCompanionProjectiles) {
      return false;
    }
    if (!silent && cue != null) onSound?.call(cue);
    companionProjectiles.add(projectile);
    return true;
  }

  void _appendCompanionProjectiles(
    Iterable<Projectile> projectiles, {
    SoundCue? cue,
    bool silent = false,
  }) {
    final available = _maxCompanionProjectiles - companionProjectiles.length;
    if (available <= 0) return;
    final list = projectiles is List<Projectile>
        ? projectiles
        : projectiles.toList(growable: false);
    final takeCount = min(available, list.length);
    if (takeCount <= 0) return;
    if (!silent && cue != null) onSound?.call(cue);
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

  Projectile _createCompanionTurretShot(Projectile orb, Offset targetPos) =>
      CosmicAbilityRuntime.companionTurretShot(orb, targetPos);

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
        final target = _nearestEnemyTo(
          projectile.position,
          KinSupport.crystalRefractRange,
        );
        if (target != null) {
          _damageEnemy(
            target,
            KinSupport.crystalRefractDamage(projectile),
            sourceSlotIndex: projectile.sourceSlotIndex,
          );
          _spawnHitSpark(target.position, elementColor('Crystal'));
          // Spawn a transient laser beam visual from shard to target.
          pushKinLaserBeam(
            _kinLaserBeams,
            KinLaserBeam(
              origin: projectile.position,
              end: target.position,
              color: KinSupport.refractColor,
            ),
          );
        }
      }

      // A Pip Light dart blocks a shot on its way and flies on: it is a
      // dart, not a shield, and deleting it on the block threw its whole
      // ricochet away (2026-10-20).
      if (projectile.interceptCharges <= 0 &&
          !PipRicochet.isSpecialDart(projectile)) {
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
        _damageEnemy(enemy, proj.damage, autoAttack: true, fromShip: true);
        // Rocket splash AoE
        if (proj.splashRadius > 0) {
          _visitEnemiesNear(proj.position, proj.splashRadius, (other) {
            if (identical(other, enemy)) return false;
            if (_withinRange(
              proj.position,
              other.position,
              proj.splashRadius,
            )) {
              _damageEnemy(
                other,
                proj.damage * 0.55,
                autoAttack: true,
                fromShip: true,
              );
            }
            return false;
          });
          for (final b in allLivingBosses) {
            if (_withinRange(proj.position, b.position, proj.splashRadius)) {
              damageBoss(
                proj.damage * 0.55,
                target: b,
                autoAttack: true,
                fromShip: true,
              );
            }
          }
        }
        proj.life = 0;
        return true;
      });

      if (proj.life > 0) {
        for (final boss in allLivingBosses) {
          if (_withinRange(proj.position, boss.position, boss.radius + 5)) {
            damageBoss(
              proj.damage,
              target: boss,
              autoAttack: true,
              fromShip: true,
            );
            // Rocket splash AoE on boss
            if (proj.splashRadius > 0) {
              _visitEnemiesNear(proj.position, proj.splashRadius, (other) {
                if (_withinRange(
                  proj.position,
                  other.position,
                  proj.splashRadius,
                )) {
                  _damageEnemy(
                    other,
                    proj.damage * 0.55,
                    autoAttack: true,
                    fromShip: true,
                  );
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
    outbreak = null;
    enemyProjectiles.clear();
    bossProjectiles.clear();
    extraBosses.removeWhere((boss) => boss.isDead);
  }

  double _distanceSquared(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return dx * dx + dy * dy;
  }

  // Sized for horde density: at 1,000+ bodies a 180-unit cell held dozens of
  // candidates for every small contact test. Larger area queries just visit
  // more (cheap) cells; results are identical either way.
  static const double _enemySpatialCellSize = 96.0;

  /// Largest live body radius as of the last grid rebuild. Contact queries pad
  /// by this rather than a fixed worst case, so they stay in one or two cells.
  double _maxEnemyRadius = 0;

  int _enemyCellCoord(double v) => (v / _enemySpatialCellSize).floor();

  void _rebuildEnemySpatialGrid() {
    // Window: the arena plus a band past the rim where bodies spawn and walk
    // in. Anything further out (a yeeted body walking back) goes to overflow.
    final reach = _arenaRadius + 700;
    _gridMinCx = _enemyCellCoord(orb.position.dx - reach);
    _gridMinCy = _enemyCellCoord(orb.position.dy - reach);
    _gridCols = _enemyCellCoord(orb.position.dx + reach) - _gridMinCx + 1;
    _gridRows = _enemyCellCoord(orb.position.dy + reach) - _gridMinCy + 1;
    final cells = _gridCols * _gridRows;
    if (_gridCellStart.length < cells + 1) {
      _gridCellStart = Int32List(cells + 1);
      _gridCursor = Int32List(cells + 1);
    } else {
      _gridCellStart.fillRange(0, cells + 1, 0);
    }
    final count = enemies.length;
    if (_gridEnemyCell.length < count) {
      _gridEnemyCell = Int32List(max(count, _gridEnemyCell.length * 2));
    }
    _gridOverflow.clear();
    var maxRadius = 0.0;
    var inGrid = 0;
    for (var i = 0; i < count; i++) {
      final enemy = enemies[i];
      if (enemy.isDead) {
        _gridEnemyCell[i] = -1;
        continue;
      }
      if (enemy.radius > maxRadius) maxRadius = enemy.radius;
      final cx = _enemyCellCoord(enemy.position.dx) - _gridMinCx;
      final cy = _enemyCellCoord(enemy.position.dy) - _gridMinCy;
      if (cx < 0 || cy < 0 || cx >= _gridCols || cy >= _gridRows) {
        _gridEnemyCell[i] = -1;
        _gridOverflow.add(enemy);
        continue;
      }
      // Column-major, so a query's x-outer / y-inner walk is contiguous.
      final cell = cx * _gridRows + cy;
      _gridEnemyCell[i] = cell;
      _gridCellStart[cell + 1]++;
      inGrid++;
    }
    for (var c = 0; c < cells; c++) {
      _gridCellStart[c + 1] += _gridCellStart[c];
    }
    _gridCursor.setRange(0, cells, _gridCellStart);
    if (_gridItems.length < inGrid) {
      _gridItems = List.filled(max(inGrid, _gridItems.length * 2), null);
    }
    for (var i = 0; i < count; i++) {
      final cell = _gridEnemyCell[i];
      if (cell < 0) continue;
      _gridItems[_gridCursor[cell]++] = enemies[i];
    }
    _gridEmpty = inGrid == 0 && _gridOverflow.isEmpty;
    _maxEnemyRadius = maxRadius;
  }

  void _visitEnemiesNear(
    Offset center,
    double radius,
    bool Function(CosmicSurvivalEnemy enemy) visitor, {
    CosmicSurvivalEnemy? exclude,
  }) {
    if (_gridEmpty || radius <= 0) return;
    var visited = 0;
    final minX = _enemyCellCoord(center.dx - radius);
    final maxX = _enemyCellCoord(center.dx + radius);
    final minY = _enemyCellCoord(center.dy - radius);
    final maxY = _enemyCellCoord(center.dy + radius);
    final x0 = max(minX - _gridMinCx, 0);
    final x1 = min(maxX - _gridMinCx, _gridCols - 1);
    final y0 = max(minY - _gridMinCy, 0);
    final y1 = min(maxY - _gridMinCy, _gridRows - 1);
    for (var x = x0; x <= x1; x++) {
      final column = x * _gridRows;
      for (var y = y0; y <= y1; y++) {
        final cell = column + y;
        final end = _gridCellStart[cell + 1];
        for (var k = _gridCellStart[cell]; k < end; k++) {
          final enemy = _gridItems[k]!;
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
    if (_gridOverflow.isNotEmpty &&
        (x0 != minX - _gridMinCx ||
            x1 != maxX - _gridMinCx ||
            y0 != minY - _gridMinCy ||
            y1 != maxY - _gridMinCy)) {
      // The query reaches past the window: check the few bodies out there
      // against the same cell range the window would have used.
      for (final enemy in _gridOverflow) {
        final cx = _enemyCellCoord(enemy.position.dx);
        final cy = _enemyCellCoord(enemy.position.dy);
        if (cx < minX || cx > maxX || cy < minY || cy > maxY) continue;
        visited++;
        if (enemy.isDead) continue;
        if (exclude != null && identical(enemy, exclude)) continue;
        if (visitor(enemy)) {
          _recordSpatialQuery(visited);
          return;
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
    final massScale = CosmicAbilityRuntime.knockbackMassScale(enemy.tier);
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
    for (final f in _orbFronts) {
      f.age += dt;
    }
    _orbFronts.removeWhere((f) => f.age >= f.seconds);
    if (powerUps.shieldPulseLevel > 0) {
      orb.shieldPulseTimer += dt;
      final interval = 12.0 - powerUps.shieldPulseLevel * 2;
      if (orb.shieldPulseTimer >= interval) {
        orb.shieldPulseTimer = 0;
        _orbFronts.add(_OrbFront(reach: 200, seconds: 0.42, nova: false));
        _visitEnemiesNear(orb.position, 200, (enemy) {
          final d = (enemy.position - orb.position).distance;
          if (d < 200) {
            final dir = enemy.position - orb.position;
            final falloff = (1.0 - (d / 200)).clamp(0.15, 1.0);
            _applyEnemyKnockback(enemy, dir, 340.0 * falloff);
          }
          return false;
        });
        // Nova Pulse (a fusion): the pulse sets off the nova as it goes.
        if (powerUps.hasNovaPulse && powerUps.novaDetonationLevel > 0) {
          _releaseOrbNova();
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
        // Tempered Field (a fusion): a share of the orb's max HP as well.
        final tempered = powerUps.hasTemperedField
            ? orb.maxHp * kTemperedFieldShare
            : 0.0;
        orb.currentHp =
            (orb.currentHp + 2.0 * powerUps.regenFieldLevel + tempered).clamp(
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
        _releaseOrbNova();
      }
    }
  }

  /// The orb's nova: its damage to every body in its reach.
  void _releaseOrbNova() {
    _orbFronts.add(_OrbFront(reach: 250, seconds: 0.5, nova: true));
    _visitEnemiesNear(orb.position, 250, (enemy) {
      final d = (enemy.position - orb.position).distance;
      if (d < 250) {
        _damageEnemy(enemy, 20.0 * powerUps.novaDetonationLevel);
      }
      return false;
    });
  }

  /// Linked Turrets (a fusion): the orb turret's shot at what the ship's
  /// turret has just hit, when that is within the orb turret's reach.
  void _fireLinkedOrbTurret(CosmicSurvivalEnemy target) {
    final level = powerUps.autoTurretLevel;
    if (level <= 0 || target.isDead) return;
    if (!_withinRange(target.position, orb.position, kLinkedTurretReach)) {
      return;
    }
    final beamColor = Color.lerp(orb.secondaryColor, Colors.white, 0.25)!;
    _spawnBeam(
      orb.position,
      target.position,
      beamColor,
      width: 2.4 + level * 0.4,
    );
    _spawnHitSpark(target.position, beamColor);
    _damageEnemy(target, _orbTurretDamage(level));
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
    if (enemy.conduct == EnemyConduct.standoff) score += 140;
    if (enemy.conduct == EnemyConduct.stalk) score += 90;
    score += (1 - enemy.hpFraction) * 60;
    score += max(0.0, blastRadius - (enemy.position - orb.position).distance);
    score += _countEnemiesNear(enemy.position, 90, exclude: enemy) * 18;
    return score;
  }

  void _spawnDetonationBurst(Offset center, Color color, double radius) =>
      emitDetonationBurst(
        center: center,
        color: color,
        radius: radius,
        rng: _rng,
        hasRoom: _kinVfxHasRoom,
        emit: _emitVfxParticle,
      );

  // == VFX =================================================================

  void _spawnProjectileHitSpark(Projectile projectile) {
    onSound?.call(SoundCue.combatHitLight);
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
    for (var i = 0; i < 6 && _vfx.length < 150; i++) {
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
    String? wingElement,
    double width = 2.4,
    double life = 0.10,
  }) {
    if (_beamFx.length >= 24) {
      _beamFx.removeAt(0);
    }
    _beamFx.add(
      _BeamFx(
        start: start,
        end: end,
        color: color,
        width: width,
        life: life,
        wingElement: wingElement,
      ),
    );
  }

  void _updateVfx(double dt) {
    _maskTrapVisuals.update(dt);
    _vfx.thin = _reduceAmbientVfx;
    for (final p in _vfx) {
      p.update(dt);
    }
    _vfx.removeWhere((p) => p.dead);
    updateLetSkyfallImpacts(_letSkyfallImpacts, dt);
    updateLetFx(_letFx, dt);
    updateHornFx(_hornFx, dt);
    for (final beam in _beamFx) {
      beam.update(dt);
    }
    _beamFx.removeWhere((beam) => beam.dead);
  }

  void _updateOutbreak(double dt) {
    final event = outbreak;
    if (event == null || event.cleared || spawner.intermission) return;
    event.anchorCores();
    final pulse = event.advance(dt);
    var shipDamage = 0.0;
    for (final core in event.cores) {
      if (core.isDead) continue;
      switch (event.kind) {
        case SurvivalOutbreakKind.verdigris:
        case SurvivalOutbreakKind.calcified:
          if (pulse && event.contains(core, ship.position)) {
            // Overlapping fields cannot multiply the same pulse's damage.
            shipDamage = max(shipDamage, ship.maxHp * 0.045);
          }
        case SurvivalOutbreakKind.sanguine:
          if (pulse) {
            for (final enemy in enemies) {
              if (!enemy.isDead &&
                  !enemy.isPlagueCore &&
                  event.contains(core, enemy.position)) {
                _healEnemy(enemy, enemy.maxHp * 0.06);
              }
            }
          }
        case SurvivalOutbreakKind.quicksilver:
          if (event.surging &&
              !ship.isDead &&
              event.contains(core, ship.position)) {
            final delta = core.position - ship.position;
            if (delta.distance > core.radius + 24) {
              ship.position +=
                  delta /
                  delta.distance *
                  min(70 * dt, delta.distance - core.radius - 24);
            }
          }
        case SurvivalOutbreakKind.nigredo:
          if (pulse) _damageOrb(orb.maxHp * 0.015);
        case SurvivalOutbreakKind.cinder:
          event.brood.removeWhere((enemy) => enemy.isDead);
          if (pulse && event.brood.length < 8) {
            final hp =
                tierBaseHp(EnemyTier.wisp) *
                CosmicSurvivalBalance.enemyWaveHpScale(spawner.currentWave);
            final child = CosmicSurvivalEnemy(
              position: core.position + const Offset(38, 0),
              hp: hp,
              maxHp: hp,
              speed: 90,
              damage: 8 + spawner.currentWave * 0.3,
              radius: tierRadius(EnemyTier.wisp),
              tier: EnemyTier.wisp,
              element: 'Fire',
              conduct: EnemyConduct.charge,
              target: CosmicEnemyTarget.ship,
            );
            event.brood.add(child);
            enemies.add(child);
          }
        case SurvivalOutbreakKind.mirror:
          if (pulse && !ship.isDead) {
            final aim = atan2(
              ship.position.dy - core.position.dy,
              ship.position.dx - core.position.dx,
            );
            for (final spread in [-0.24, 0.0, 0.24]) {
              enemyProjectiles.add(
                SurvivalEnemyProjectile(
                  position: core.position,
                  angle: aim + spread,
                  element: 'Light',
                  damage: ship.maxHp * 0.025,
                  target: CosmicEnemyTarget.ship,
                  speed: 190,
                  life: 3.0,
                ),
              );
            }
          }
        case SurvivalOutbreakKind.voltaic:
        case SurvivalOutbreakKind.crystal:
        case SurvivalOutbreakKind.frost:
          break;
      }
    }
    if (pulse && event.kind == SurvivalOutbreakKind.voltaic) {
      for (final (a, b) in event.links) {
        if (SurvivalOutbreak.touchesLink(ship.position, a, b, 25)) {
          shipDamage = ship.maxHp * 0.05;
          break;
        }
      }
    }
    if (shipDamage > 0 && !ship.isDead) {
      ship.currentHp = max(
        0,
        ship.currentHp - shipDamage * (powerUps.hasMirrorShield ? 0.75 : 1.0),
      );
      ship.hitFlash = 1;
      if (ship.currentHp <= 0) {
        ship.isDead = true;
        _shipRespawnTimer = 0;
      }
    }
  }

  void _applyWaveStartEffectsIfNeeded() {
    if (spawner.currentWave <= 0 || _timeDilationWave == spawner.currentWave) {
      return;
    }
    _timeDilationWave = spawner.currentWave;
    outbreak = SurvivalOutbreak.forWave(
      spawner.currentWave,
      orb.position,
      _arenaRadius,
      random: _rng,
      previous: _previousOutbreak,
    );
    if (outbreak case final event?) {
      onSound?.call(SoundCue.survivalOutbreak);
      _previousOutbreak = event.kind;
      enemies.addAll(event.cores);
    }
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

  /// The body a Pip special dart turns to after a contact at [from]: the
  /// nearest within [maxRange] that it has not struck yet.
  CosmicSurvivalEnemy? _nextPipDartTarget(
    Projectile dart,
    Offset from,
    double maxRange, {
    CosmicSurvivalEnemy? struck,
  }) {
    CosmicSurvivalEnemy? best;
    var bestDistSq = maxRange * maxRange;
    _visitEnemiesNear(from, maxRange, (enemy) {
      // Never back onto the body just struck, hit memory or not.
      if (identical(enemy, struck)) return false;
      final dSq = _distanceSquared(enemy.position, from);
      if (dSq >= bestDistSq) return false;
      if (!dart.canHitEnemy(identityHashCode(enemy))) return false;
      bestDistSq = dSq;
      best = enemy;
      return false;
    });
    return best;
  }

  /// The nearest boss in the fight with any of its body within [maxRange] of
  /// [pos]. One still flying in is not in the fight yet.
  SurvivalBoss? _nearestBossTo(Offset pos, double maxRange) {
    SurvivalBoss? best;
    var bestGap = maxRange;
    final primary = activeBoss;
    if (primary != null && !primary.isDead && !primary.isSpawning) {
      final gap = (primary.position - pos).distance - primary.radius;
      if (gap <= bestGap) {
        bestGap = gap;
        best = primary;
      }
    }
    for (final boss in extraBosses) {
      if (boss.isDead || boss.isSpawning) continue;
      final gap = (boss.position - pos).distance - boss.radius;
      if (gap <= bestGap) {
        bestGap = gap;
        best = boss;
      }
    }
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
      if (enemy.conduct == EnemyConduct.standoff) score += 80;
      if (enemy.conduct == EnemyConduct.stalk) score += 45;
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
    onSound?.call(SoundCue.survivalPowerupCollect);
    showingPowerUpSelection = true;
    gamePaused = true;
    onWaveIntermission?.call();
  }

  /// [scale] is what a Horn's Juggernaut second run is worth: its shield,
  /// heals and blessing come out at the run's power, as its ram does.
  void _applyCompanionSpecialSupportEffects(
    CosmicSurvivalCompanion comp,
    CosmicSpecialResult result, {
    double scale = 1.0,
  }) {
    final benediction = comp.slotIndex >= 0
        ? _kinBenedictionFor(comp.slotIndex)
        : (duration: 1.0, power: 1.0, survivesDeath: false, allyRange: 0.0);
    // Deep Reserves: "its healing, shielding and buffs are 25% stronger".
    // Only the blessing was, so a Kin's self-heal, ship heal and shield were
    // untouched (2026-10-21 mastery sweep). The Steam boiler's haste is the
    // buff ([_updateKinSupportTick]).
    final support = scale * benediction.power;
    final shieldHp = (result.shieldHp * support).round();
    final selfHeal = (result.selfHeal * support).round();
    final shipHeal = (result.shipHeal * support).round();
    // A companion's shield stays on the companion. It used to be copied onto
    // the orb as well (70%, capped at 45% of the orb), which with any Horn or
    // Kin on the team became a second health bar that refilled on every cast:
    // a fresh level-1 team rode it from wave 9 to wave 12 and beyond. The
    // orb hardens with the wave instead (CosmicSurvivalBalance
    // .orbWaveDamageShare), which leaves the opening waves to the team.
    if (shieldHp > 0) {
      comp.shieldHp = max(comp.shieldHp, shieldHp);
    }
    if (selfHeal > 0) {
      final before = comp.currentHp;
      comp.currentHp = min(comp.maxHp, comp.currentHp + selfHeal);
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
      _healOrb(selfHeal * selfHealToOrbMultiplier, sourceSlot: comp.slotIndex);
    }
    if (shipHeal > 0) {
      final before = ship.currentHp;
      ship.currentHp = min(ship.maxHp, ship.currentHp + shipHeal);
      _recordHeal(
        ship.currentHp - before,
        target: 1,
        sourceSlot: comp.slotIndex,
      );
      // A Kin's ship heal is authored as a share of the ship's hundred
      // points. The orb it also mends holds eight hundred and up, so a Kin
      // pays the same share against the orb's pool; every other family
      // keeps the point-for-point echo.
      final isKin = comp.member.family.toLowerCase() == 'kin';
      _healOrb(
        isKin
            ? shipHeal / max(1.0, ship.maxHp.toDouble()) * orb.maxHp
            : shipHeal.toDouble(),
        sourceSlot: comp.slotIndex,
      );
    }
    if (result.blessingTimer > 0) {
      comp.blessingTimer = max(
        comp.blessingTimer,
        result.blessingTimer * benediction.duration,
      );
      comp.blessingHealPerTick = max(
        comp.blessingHealPerTick,
        result.blessingHealPerTick * benediction.power * scale,
      );
      comp.blessingShared = false;
      _shareKinBlessing(comp.slotIndex, comp);
    }
  }

  /// [amount] cut to what caster [slot] may still heal under
  /// [_healCeiling].
  double _cappedOrbHeal(int? slot, double amount) => _healCeiling.grant(
    slot: slot,
    amount: amount,
    pool: orb.maxHp,
    beauty: slot != null && slot >= 0 && slot < party.length
        ? _effectiveBeauty(slot)
        : kAbilityStatAverage,
    now: stats.timeElapsed,
  );

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
    onSound?.call(SoundCue.combatHeal);
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

  /// What the orb's shield holds, as a share of its maximum health: the
  /// brass run on the health ring and the HUD's orb gauge both show it.
  double get orbShieldFraction =>
      orb.shieldHp > 0 ? orb.shieldHp / max(orb.maxHp, 1) : 0.0;

  void _grantOrbShield(int amount) {
    if (amount <= 0) return;
    final maxShield = max(60, (orb.maxHp * 0.45).round());
    orb.shieldHp = min(maxShield, orb.shieldHp + amount);
  }

  void _damageOrb(double amount) {
    if (amount <= 0) return;
    // Past the opening waves the orb takes a falling share of every hit.
    amount *= CosmicSurvivalBalance.orbWaveDamageShare(spawner.currentWave);
    // A Bastion standing between takes a share of this first, mitigated by
    // its bulk, so what reaches the orb is genuinely less.
    var remaining = _hornBodyguardOrbDamage(amount);
    if (remaining <= 0) return;
    _kinOrbDamageThisFrame += remaining;
    if (orb.shieldHp > 0) {
      final absorbed = min(remaining, orb.shieldHp.toDouble());
      orb.shieldHp -= absorbed.round();
      remaining -= absorbed;
      onSound?.call(
        orb.shieldHp <= 0
            ? SoundCue.combatShieldBreak
            : SoundCue.combatShieldHit,
      );
    }
    // Only what would reach the orb's own health is shared under a pact;
    // the shield is spent first.
    remaining = _kinBloodPactShareOrbDamage(remaining);
    if (remaining > 0) {
      final wasSafe = orb.hpPercent >= 0.25;
      orb.currentHp = max(0, orb.currentHp - remaining);
      if (wasSafe && orb.hpPercent < 0.25 && orb.currentHp > 0) {
        onSound?.call(SoundCue.combatDanger);
      }
    }
  }

  /// Kin+Blood pact: while a pact holds, the living companions take a share
  /// of what would have reached the orb's health, split evenly, never past
  /// their last point. Returns what the orb still takes. The damage they
  /// absorb is then ordinary companion damage, which the pact's other half
  /// heals across the team the next tick.
  double _kinBloodPactShareOrbDamage(double amount) {
    if (amount <= 0) return amount;
    var pactActive = false;
    for (final comp in _kinSupportSources.map((e) => e.value)) {
      if (comp.kinBloodPactTimer > 0 &&
          comp.member.family.toLowerCase() == 'kin' &&
          comp.member.element == 'Blood') {
        pactActive = true;
        break;
      }
    }
    if (!pactActive) return amount;
    final living = <CosmicSurvivalCompanion>[
      for (final c in activeCompanions.values)
        if (!c.isDead && c.currentHp > 1) c,
    ];
    if (living.isEmpty) return amount;
    final perAlly = amount * _kinBloodPactOrbShare / living.length;
    var absorbed = 0.0;
    for (final c in living) {
      c.kinBloodPactAbsorbCarry += perAlly;
      final whole = c.kinBloodPactAbsorbCarry.floor();
      if (whole <= 0) continue;
      final take = min(whole, c.currentHp - 1);
      if (take <= 0) continue;
      c.kinBloodPactAbsorbCarry -= take;
      c.currentHp -= take;
      c.hitFlash = 1.0;
      absorbed += take;
    }
    return max(0.0, amount - absorbed);
  }

  static const double _kinBloodPactOrbShare = 0.40;

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
      final next = _nearestEnemyTo(
        current.position,
        CosmicAbilityRuntime.chainRange,
        exclude: current,
      );
      if (next == null) break;
      final bounceDamage = CosmicAbilityRuntime.chainBounceDamage(
        baseDamage,
        i,
      );
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
        // By index: a splitter it kills adds its shards to the list.
        for (var i = 0; i < enemies.length; i++) {
          final e = enemies[i];
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

    maneLavaPoolCrowd = ManeRuntime.countLavaPools(companionProjectiles);

    canvas.save();
    canvas.scale(_currentZoom, _currentZoom);
    // Screen shake rides the world transform, so the arena moves under the
    // HUD rather than the HUD moving with it.
    final shake = _screenShakeOffset();
    canvas.translate(-cx + shake.dx, -cy + shake.dy);

    final view = Rect.fromLTWH(cx, cy, viewW, viewH);
    _nebula.paint(canvas, view, orb.position, stats.timeElapsed);
    _sky.paint(canvas, view, stats.timeElapsed, _currentZoom);
    // Mystic environment tint — viewport-covering element wash that
    // sits between the starfield and the arena. Stacks if multiple
    // mystics are active. Other world objects render on top.
    _renderMysticEnvironmentOverlay(canvas);
    _rim.paint(
      canvas,
      orb.position,
      _arenaRadius,
      orb.skin,
      stats.timeElapsed,
      view,
      _currentZoom,
    );
    _renderOrbGravityField(canvas);
    if (outbreak case final event?) {
      drawSurvivalOutbreak(
        canvas,
        event,
        orb.position,
        viewport: Rect.fromLTWH(cx, cy, viewW, viewH),
      );
    }
    _renderOrb(canvas);
    for (final f in _orbFronts) {
      paintOrbFront(
        canvas,
        orb.position,
        f.reach,
        f.nova ? orbLook(orb.skin).essence : const Color(0xFFE2C98F),
        f.age / f.seconds,
        hot: f.nova,
      );
    }

    // Incoming Let meteors mark the ground they are committed to. Drawn under
    // the bodies standing on it, because it is a mark on the arena floor and
    // not an overlay — and drawn before anything else so a player reading the
    // field sees "something is about to land there" at a glance.
    for (final proj in companionProjectiles) {
      if (!proj.isDescending) continue;
      // A Deadfall auto-attack marks the crater it will actually open, not
      // the special's.
      final telegraphRadius = proj.letDeadfall
          ? proj.letCraterRadius
          : letSkyfallBlastRadius(proj);
      if (!_isWithinViewport(
        proj.skyfallImpact,
        telegraphRadius * 2.4,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
      )) {
        continue;
      }
      drawLetSkyfallTelegraph(
        canvas: canvas,
        centre: proj.skyfallImpact,
        color: elementColor(proj.element ?? 'Fire'),
        element: proj.element,
        radius: telegraphRadius,
        progress: proj.skyfallProgress,
        time: stats.timeElapsed,
        reduceAmbient: _reduceAmbientVfx,
      );
    }

    final batchSwarm = enemies.length >= _kSwarmBatchThreshold;
    final denseField = enemies.length >= _kDenseFieldThreshold;
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
      if (batchSwarm &&
          _swarmBatch.add(enemy, stats.timeElapsed, dense: denseField)) {
        continue;
      }
      _renderEnemy(canvas, enemy);
    }
    _swarmBatch.flush(canvas, stats.timeElapsed);
    // Menders: the grains they gather, and the heal flowing out of them.
    paintMenderMantles(canvas, _livingMenders, view, stats.timeElapsed);
    _menderFlows.paint(canvas, view);
    _surgeGrains.paint(canvas, view);

    // Beams and shockwaves sit above the bodies that threw them.
    _renderEnemyHazards(canvas);

    if (activeBoss != null && !activeBoss!.isDead) {
      _renderBoss(canvas, activeBoss!);
    }
    for (final extra in extraBosses) {
      if (extra.isDead) continue;
      _renderBoss(canvas, extra);
    }
    damageNumbers.render(canvas);

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
      paintHostileShot(
        canvas,
        proj.position,
        proj.angle,
        proj.radius,
        proj.element,
        heavy: true,
      );
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
      paintHostileShot(
        canvas,
        proj.position,
        proj.angle,
        proj.radius,
        proj.element,
      );
    }

    // Companion projectiles
    for (final proj in companionProjectiles) {
      if (proj.life <= 0) continue;
      if (!_isWithinViewport(
        proj.position,
        // A parked piece is drawn over the area it acts on, often far wider
        // than its contact radius: cull by what is drawn, so it does not pop
        // in and out at the screen edge.
        proj.stationary
            ? max(
                Projectile.radius * proj.radiusMultiplier * 2.6,
                max(proj.effectRadius, proj.snareRadius),
              )
            : Projectile.radius * proj.radiusMultiplier * 2.6,
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
        );
        canvas.restore();
      } else {
        canvas.drawCircle(proj.position, 3, _shipProjectilePaint);
        if (!_reduceSecondaryGlows) {
          canvas.drawCircle(proj.position, 6, _shipProjectileGlowPaint);
        }
      }
    }

    // Each live Wing beam, painted once a frame straight from
    // _activeWingBeams (shared with open space and the dungeons; it used to
    // lay a 0.08 s copy of itself into _beamFx every frame, which stacked
    // ~5 copies and took slots in that list).
    _renderWingBeams(canvas, cx, cy, viewW, viewH);
    // What is left in _beamFx is short-lived: Lightning's blast, a charge's
    // sparks, Horn's arcs, the orb turret. Each at its own strength.
    for (final beam in _beamFx) {
      final alpha = beam.alpha;
      if (alpha <= 0) continue;
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
      drawAdvancedAbilityBeam(
        canvas: canvas,
        start: beam.start,
        end: beam.end,
        color: beam.color,
        wingElement: beam.wingElement,
        width: beam.width,
        alpha: alpha,
        time: stats.timeElapsed,
      );
    }

    _renderWingRings(canvas, cx, cy, viewW, viewH);
    _maskTrapVisuals.render(
      canvas,
      reduced: _reduceAmbientVfx,
      viewport: Rect.fromLTWH(cx, cy, viewW, viewH),
    );

    // Wing+Plant flower pickups (art shared with open space, wing_vfx.dart)
    if (_flowerPickups.isNotEmpty) {
      final t = stats.timeElapsed;
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
        drawWingFlowerPickup(
          canvas: canvas,
          position: flower.position,
          life: flower.life,
          bobPhase: flower.bobPhase,
          time: t,
        );
      }
    }

    // Mask+Spirit collectibles share the same ash-like remnant as Cosmic.
    if (_spiritWisps.isNotEmpty) {
      final t = stats.timeElapsed;
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
        drawMaskSpiritWisp(
          canvas: canvas,
          position: wisp.position,
          life: wisp.life,
          bobPhase: wisp.bobPhase,
          time: t,
          reduced: _reduceAmbientVfx,
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
    if (renderShip) _renderShip(canvas);

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
      drawKinBloodThreads(
        canvas: canvas,
        allies: [
          if (!ship.isDead) ship.position,
          for (final c in activeCompanions.values)
            if (!c.isDead) c.position,
        ],
        time: stats.timeElapsed,
      );
    }

    // Kin auto-attack laser beams — thin element-tinted glow lines
    // that fade over ~0.28s. Drawn on top of the world so they read
    // clearly even when allies/enemies are stacked.
    if (_kinLaserBeams.isNotEmpty) {
      for (final beam in _kinLaserBeams) {
        if (beam.dead) continue;
        drawKinLaser(
          canvas: canvas,
          start: beam.origin,
          end: beam.end,
          color: beam.color,
          width: KinLaser.beamWidth,
          alpha: beam.alpha,
        );
      }
    }

    // Mask+Spirit nuke punctuation — expanding spirit ring from the
    // ship + faint screen-wash. Decays via _maskSpiritNukeFlash.
    drawMaskSpiritNukeFlash(
      canvas: canvas,
      origin: _maskSpiritNukeOrigin,
      flash: _maskSpiritNukeFlash,
      viewport: Rect.fromLTWH(cx, cy, viewW, viewH),
    );

    // Ground cover, under everything else a world puts on the map: it is the
    // floor, and the fight happens on top of it.
    for (final f in _mysticFlora) {
      if (!_isWithinViewport(
        f.position,
        30,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 36,
      )) {
        continue;
      }
      drawMysticFlora(
        canvas: canvas,
        at: f.position,
        element: f.element,
        size: f.size,
        bloom: f.bloom,
        seed: f.seed,
        time: stats.timeElapsed,
        tint: elementColor(f.element),
      );
    }

    // Poison Mystic's trail, under everything: it is on the floor, and the
    // ship that laid it has to be readable while flying back over it.
    for (final pool in _mysticPools) {
      if (pool.fade <= 0.01) continue;
      if (!_isWithinViewport(
        pool.position,
        pool.radius,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 40,
      )) {
        continue;
      }
      // Thins out over its last second rather than vanishing on a frame, and
      // spreads into existence rather than appearing finished.
      final ebb = pool.life < 1.0 ? pool.life.clamp(0.0, 1.0) : 1.0;
      final spread = pool.spreadEase;
      drawMysticPoisonPatch(
        canvas: canvas,
        centre: pool.position,
        radius: pool.radius * (0.28 + 0.72 * spread),
        alpha: pool.fade * ebb * spread,
        seed: pool.seed,
        time: stats.timeElapsed,
        poison: elementColor('Poison'),
      );
    }

    // Air Mystic's tornado. Over the floor rather than under it: the funnel is
    // in the air, and what it has picked up is in the air with it.
    for (final twister in _mysticTornados) {
      if (twister.fade <= 0.01) continue;
      if (!_isWithinViewport(
        twister.position,
        twister.funnelRadius * 1.6,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 60,
      )) {
        continue;
      }
      drawMysticTornado(
        canvas: canvas,
        at: twister.position,
        radius: twister.funnelRadius,
        phase: twister.phase,
        travelAngle: twister.angle + pi / 2,
        alpha: twister.fade,
        time: stats.timeElapsed,
      );
    }

    // Water Mystic's maelstrom, beneath everything: it is the surface the
    // fight is happening on.
    for (final storm in _mysticMaelstroms) {
      if (storm.fade <= 0.01) continue;
      drawMysticMaelstrom(
        canvas: canvas,
        centre: storm.centre,
        radius: storm.radius,
        phase: storm.phase,
        alpha: storm.fade,
        time: stats.timeElapsed,
      );
    }

    // Lava Mystic's fissures and the scorches its meteors leave, on the floor
    // under everything that walks over them.
    for (final fissure in _mysticFissures) {
      if (fissure.fade <= 0.01) continue;
      drawMysticFissure(
        canvas: canvas,
        points: fissure.points,
        alpha: fissure.fade,
        flare: fissure.flare,
        seed: fissure.seed,
        time: stats.timeElapsed,
      );
    }
    for (final scorch in _mysticScorches) {
      drawMysticScorch(
        canvas: canvas,
        at: scorch.at,
        age: scorch.age,
        maxAge: _MysticScorch.maxAge,
        seed: scorch.seed,
      );
    }

    // Steam Mystic's vents, on the floor with the quakes.
    for (final vent in _mysticVents) {
      drawMysticVent(
        canvas: canvas,
        centre: vent.centre,
        radius: vent.radius,
        progress: vent.age / _MysticVent.maxAge,
        time: stats.timeElapsed,
      );
    }

    // Earth Mystic's quakes, also on the floor.
    for (final quake in _mysticQuakes) {
      drawMysticQuake(
        canvas: canvas,
        centre: quake.centre,
        radius: quake.radius,
        progress: quake.age / _MysticQuake.maxAge,
        earth: elementColor('Earth'),
      );
    }

    // Dark Mystic's maw. Drawn before everything else in this pass because it
    // is a hole in the floor, not an effect sitting on top of one — bodies
    // being dragged across it have to pass OVER it.
    for (final maw in _mysticMaws) {
      if (maw.fade <= 0.01) continue;
      if (!_isWithinViewport(
        maw.position,
        maw.radius * maw.open,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 40,
      )) {
        continue;
      }
      drawMysticMaw(
        canvas: canvas,
        centre: maw.position,
        horizonRadius: maw.horizon,
        open: maw.open,
        spin: maw.spin,
        alpha: maw.fade,
        time: stats.timeElapsed,
      );
    }

    // Plant Mystic's grove: the vine that lashes what closes, and the one that
    // spits at what does not.
    for (final vine in _mysticVines) {
      if (vine.fade <= 0.01) continue;
      if (!_isWithinViewport(
        vine.root,
        vine.reach,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 160,
      )) {
        continue;
      }
      drawMysticGroveVine(
        canvas: canvas,
        root: vine.root,
        lashes: vine.lashes,
        growth: vine.growth,
        swing: vine.swing,
        aimAngle: vine.aimAngle,
        reach: vine.reach,
        seed: vine.seed,
        alpha: vine.fade,
        time: stats.timeElapsed,
        plant: elementColor('Plant'),
      );
    }

    // Spirit Mystic's revenants: the fight's own dead, turned.
    for (final r in _mysticRevenants) {
      if (r.fade <= 0.01) continue;
      if (!_isWithinViewport(
        r.position,
        r.radius * 3,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 32,
      )) {
        continue;
      }
      drawMysticRevenant(
        canvas: canvas,
        position: r.position,
        velocity: r.velocity,
        radius: r.radius,
        rise: r.rise,
        life: r.life,
        alpha: r.fade,
        time: stats.timeElapsed,
        seed: r.seed,
      );
    }

    // A Light world's star, behind everything: it hangs outside the arena.
    for (final star in _mysticStars) {
      drawMysticDawnStar(
        canvas: canvas,
        at: star.position,
        charge: star.charge,
        flare: star.flare,
        alpha: star.fade,
        time: stats.timeElapsed,
      );
    }

    // The sky gathering, under the bodies it is about to hit — it marks the
    // ground, so anything standing on that ground has to read on top of it.
    for (final charge in _mysticCharges) {
      if (!_isWithinViewport(
        charge.at,
        110,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 40,
      )) {
        continue;
      }
      drawMysticStormCharge(
        canvas: canvas,
        at: charge.at,
        progress: charge.progress,
        seed: charge.seed,
        time: stats.timeElapsed,
      );
    }

    // Crystal shards, over the floor so they are never lost under debris.
    for (final shard in _mysticCrystals) {
      if (!_isWithinViewport(
        shard.position,
        20,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 30,
      )) {
        continue;
      }
      final ebb = shard.life < 1.5 ? (shard.life / 1.5).clamp(0.0, 1.0) : 1.0;
      drawMysticCrystalShard(
        canvas: canvas,
        at: shard.position,
        alpha: shard.fade * ebb,
        seed: shard.seed,
        time: stats.timeElapsed,
        tint: elementColor('Crystal'),
      );
    }

    // Falling lava, over the field: the rock has to pass in front of whatever
    // it is about to land on.
    for (final meteor in _mysticMeteors) {
      if (!_isWithinViewport(
        meteor.impact,
        120,
        cx,
        cy,
        cx + viewW,
        cy + viewH,
        margin: 80,
      )) {
        continue;
      }
      drawMysticLavaMeteor(
        canvas: canvas,
        impact: meteor.impact,
        progress: meteor.progress,
        seed: meteor.seed,
      );
    }

    // Lightning Mystic's strikes, over the field: a bolt falls in front of
    // whatever it hits.
    for (final bolt in _mysticBolts) {
      drawMysticLightningBolt(
        canvas: canvas,
        strike: bolt.strike,
        progress: 1.0 - bolt.life / _MysticBolt.maxLife,
        seed: bolt.seed,
        onBoss: bolt.onBoss,
      );
    }

    // Fire Mystic embers. Drawn under the craters and debris so they read as
    // weather the fight happens inside, rather than as effects on top of it.
    // Lit grains in Fire's material, culled to the view, in one atlas draw
    // flushed here (they were three discs an ember, each a new Paint, ~270
    // draws for a full field).
    if (_mysticEmbers.isNotEmpty) {
      final grains = _vfxGrains;
      for (final ember in _mysticEmbers) {
        if (!_isWithinViewport(
          ember.position,
          12,
          cx,
          cy,
          cx + viewW,
          cy + viewH,
          margin: 12,
        )) {
          continue;
        }
        // Each breathes on its own phase, so a field of forty shimmers
        // instead of pulsing as one.
        final glow = 0.55 + 0.45 * sin(stats.timeElapsed * 2.1 + ember.seed);
        final a = ember.fade;
        final r = (2.0 + glow * 1.4);
        final x = ember.position.dx, y = ember.position.dy;
        grains.add(x, y, r * 2.2, _MysticEmber.heat, 0.16 * a * glow);
        grains.add(x, y, r * 0.9, _MysticEmber.lit, 0.9 * a * (0.7 + 0.3 * glow));
      }
      grains.flush(canvas);
    }

    // Let meteor craters, under the particle debris the same landing threw.
    for (final impact in _letSkyfallImpacts) {
      drawLetSkyfallImpact(
        canvas: canvas,
        centre: impact.position,
        color: impact.color,
        element: impact.element,
        minor: impact.minor,
        radius: impact.radius,
        age: impact.t,
        reduceAmbient: _reduceAmbientVfx,
      );
    }
    drawLetFx(canvas, _letFx, reduceAmbient: _reduceAmbientVfx);

    drawHornFx(canvas, _hornFx, reduceAmbient: _reduceAmbientVfx);

    // VFX particles: lit grains in one atlas draw, exactly as
    // AbilityVfxPool draws open space's and the dungeons' (ability_grains
    // .dart). Reduced quality thins them at spawn (_VfxPool), not here.
    final grains = _vfxGrains;
    for (final p in _vfx) {
      if (p.dead) continue;
      grains.addParticle(p.x, p.y, p.size, p.life, p.maxLife, p.tone);
    }
    grains.flush(canvas);

    canvas.restore();

    if (isGameOver) _renderCoreFall(canvas);
  }

  /// The end of the run: the arena dims and stills, and over it the core
  /// comes apart into grains of its own light (orb_art.dart).
  void _renderCoreFall(Canvas canvas) {
    final t = _coreFallT;
    final x = ((t - 0.1) / 1.4).clamp(0.0, 1.0);
    final dim = 0.62 * x * x * (3 - 2 * x);
    if (dim > 0) {
      canvas.drawRect(
        Offset.zero & Size(size.x, size.y),
        Paint()..color = Color.fromRGBO(4, 4, 6, dim),
      );
    }
    canvas.save();
    canvas.scale(_currentZoom, _currentZoom);
    final shake = _screenShakeOffset();
    canvas.translate(
      -camX + shake.dx + orb.position.dx,
      -camY + shake.dy + orb.position.dy,
    );
    paintCoreFall(
      canvas,
      orb.skin,
      t,
      corePresentationTime,
      radius: _orbCoreRadius,
    );
    canvas.restore();
  }

  /// The core, and its readings round it (orb_art.dart). Health and the
  /// alchemy meter are rings of cells; a held shield is brass cells after
  /// the health and a glass shell.
  void _renderOrb(Canvas canvas) {
    // Once it has given out, the fall draws it, over the dimmed arena.
    if (isGameOver || entranceCoreHidden) return;
    final center = orb.position;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    _paintCoreBody(canvas);
    _paintCoreReadings(canvas);
    canvas.restore();

    if (_kinDarkVeilDraws) {
      // The veil: the orb reads as hidden, darkness closing over it.
      drawKinDarkVeil(
        canvas: canvas,
        center: center,
        radius: _orbShieldRadius + 8,
        time: stats.timeElapsed,
      );
    }
  }

  /// The core itself, at the canvas origin.
  void _paintCoreBody(Canvas canvas) {
    paintOrbCore(
      canvas,
      orb.skin,
      corePresentationTime,
      radius: _orbCoreRadius,
      beat: _coreBeat,
    );
  }

  /// The core's readings, at the canvas origin.
  void _paintCoreReadings(Canvas canvas) {
    paintOrbReadings(
      canvas,
      orb.skin,
      hpFrac: orb.hpPercent,
      meterFrac: _alchemicalMeterDisplayFrac,
      shield: orbShieldFraction,
      shieldRadius: _orbShieldRadius,
      time: corePresentationTime,
    );
  }

  /// The field the ship orbits in: lanes of drifting dust (orb_art.dart),
  /// the innermost on the ship's orbit.
  void _renderOrbGravityField(Canvas canvas) {
    if (entranceCoreHidden) return;
    canvas.save();
    canvas.translate(orb.position.dx, orb.position.dy);
    _paintCoreField(canvas);
    canvas.restore();
  }

  /// The field, at the canvas origin.
  void _paintCoreField(Canvas canvas) {
    paintOrbField(
      canvas,
      orb.skin,
      corePresentationTime,
      orbit: _orbShipOrbitRadius,
    );
  }

  /// Enemy rendering: EXACT SAME visuals as cosmic game per tier.
  /// The enemy silhouette now lives in the shared cosmic enemy VFX layer so
  /// the preview harness can render the roster without playing the game.

  /// Hazards: beams and shockwaves. Each hits any given target at most once,
  /// tracked on the hazard itself, so a beam that lingers for half a second
  /// does not tick damage every frame.
  void _updateEnemyHazards(double dt) {
    for (var i = enemyHazards.length - 1; i >= 0; i--) {
      final h = enemyHazards[i];
      h.life -= dt;
      if (h.life <= 0) {
        enemyHazards.removeAt(i);
        continue;
      }

      bool reaches(Offset p, double r) {
        switch (h.kind) {
          case EnemyHazardKind.beam:
            // Distance from the point to the beam segment.
            final d = Offset(cos(h.angle), sin(h.angle));
            final rel = p - h.origin;
            final t = (rel.dx * d.dx + rel.dy * d.dy).clamp(0.0, h.length);
            final closest = h.origin + d * t;
            return (p - closest).distance <= h.width * 0.5 + r;
          case EnemyHazardKind.shockwave:
            // Only the wavefront hurts, not the whole disc.
            final dist = (p - h.origin).distance;
            return (dist - h.radius).abs() <= 26 + r;
        }
      }

      if (!h.hit.contains(orb) && reaches(orb.position, 26)) {
        h.hit.add(orb);
        // The orb cannot sidestep a beam or shockwave. Keep their full
        // damage against mobile targets, but bound stationary-core damage.
        _damageOrb(min(h.damage * 0.35, orb.maxHp * 0.08));
      }
      // As every other hit on the ship: only a living ship, and one this
      // empties is down (a beam left it flying at -200, 2026-10-20).
      if (!ship.isDead &&
          !h.hit.contains(ship) &&
          reaches(ship.position, 16)) {
        h.hit.add(ship);
        ship.currentHp -= h.damage * _shipBodyDamageTaken;
        ship.hitFlash = 1.0;
        if (ship.currentHp <= 0) {
          ship.isDead = true;
          _shipRespawnTimer = 0;
        }
      }
      for (final comp in activeCompanions.values) {
        if (comp.isDead || h.hit.contains(comp)) continue;
        if (reaches(comp.position, 14)) {
          h.hit.add(comp);
          _applyCompanionIncomingDamage(comp, h.damage);
        }
      }
    }
  }

  void _renderEnemyHazards(Canvas canvas) {
    for (final h in enemyHazards) {
      final fade = (1.0 - h.progress).clamp(0.0, 1.0);
      switch (h.kind) {
        case EnemyHazardKind.beam:
          paintSiegeBeam(
            canvas,
            h.origin,
            h.angle,
            h.length,
            h.width,
            h.element,
            fade,
          );
        case EnemyHazardKind.shockwave:
          paintShockFront(canvas, h.origin, h.radius, h.element, fade);
      }
    }
  }

  // ── Enemy signature actions ────────────────────────────────────────────
  //
  // idle → windUp → commit → recover. See games/shared/enemy_action.dart for
  // why this exists: enemies had cooldowns, not actions, so nothing they did
  // took time or showed intent.

  /// Where this enemy is aiming — whatever it currently wants to hit.
  Offset _enemyAimPoint(CosmicSurvivalEnemy enemy) => switch (enemy.target) {
    CosmicEnemyTarget.ship => ship.position,
    CosmicEnemyTarget.companion =>
      _nearestCompanionPos(enemy.position) ?? orb.position,
    _ => orb.position,
  };

  Offset? _nearestCompanionPos(Offset from) {
    Offset? best;
    var bestSq = double.infinity;
    for (final c in activeCompanions.values) {
      if (c.isDead) continue;
      final d = _distanceSquared(c.position, from);
      if (d < bestSq) {
        bestSq = d;
        best = c.position;
      }
    }
    return best;
  }

  void _updateEnemyAction(CosmicSurvivalEnemy enemy, double dt) {
    final def = kEnemyActions[enemy.tier];
    // Wisps fight by contact; a mender's pulse is its only act.
    if (enemy.isPlagueCore || enemy.isMender || def == null) return;
    final a = enemy.action;

    if (a.phase == EnemyActionPhase.idle) {
      // attackCooldown doubles as the idle gate, so existing slows and stuns
      // that already push it out keep working.
      if (enemy.attackCooldown > 0) return;
      final aim = _enemyAimPoint(enemy);
      if (_distanceSquared(aim, enemy.position) > def.range * def.range) return;
      a.phase = EnemyActionPhase.windUp;
      a.timer = def.windUp;
      a.fired = false;
      // Facing locks here: the attack lands where it was telegraphed, not
      // wherever you dodged to. That is what makes the tell worth reading.
      a.aimAngle = atan2(
        aim.dy - enemy.position.dy,
        aim.dx - enemy.position.dx,
      );
      return;
    }

    a.timer -= dt;
    if (a.timer > 0) {
      if (a.phase == EnemyActionPhase.commit && !a.fired) {
        a.fired = true;
        _fireEnemyAction(enemy);
      }
      return;
    }

    switch (a.phase) {
      case EnemyActionPhase.windUp:
        a.phase = EnemyActionPhase.commit;
        a.timer = def.commit;
        a.fired = true;
        _fireEnemyAction(enemy);
      case EnemyActionPhase.commit:
        a.phase = EnemyActionPhase.recover;
        a.timer = def.recover;
      case EnemyActionPhase.recover:
        a.phase = EnemyActionPhase.idle;
        a.timer = 0;
        enemy.attackCooldown = def.cooldown;
      case EnemyActionPhase.idle:
        break;
    }
  }

  /// The payoff. One signature per body — this is what makes six bodies feel
  /// like six creatures instead of six health bars.
  void _fireEnemyAction(CosmicSurvivalEnemy enemy) {
    final a = enemy.action;
    final dir = Offset(cos(a.aimAngle), sin(a.aimAngle));

    switch (enemy.tier) {
      case EnemyTier.drone:
        // Dash-strike: a committed lunge along the telegraphed line. Reuses
        // knockbackVelocity, which the movement integrator already applies.
        enemy.knockbackVelocity += dir * 520;

      case EnemyTier.sentinel:
        // Satellites gather in, then fan out.
        const shots = 5;
        for (var i = 0; i < shots; i++) {
          final spread = (i - (shots - 1) / 2) * 0.20;
          enemyProjectiles.add(
            SurvivalEnemyProjectile(
              position: enemy.position,
              angle: a.aimAngle + spread,
              element: enemy.element,
              damage: enemy.damage * 0.55,
              target: enemy.target,
              speed: 250,
              life: 2.6,
            ),
          );
        }

      case EnemyTier.phantom:
        // Blink behind the target, then stand exposed through recover.
        final aim = _enemyAimPoint(enemy);
        enemy.position = aim + dir * 46;
        enemy.hitFlash = max(enemy.hitFlash, 0.6);

      case EnemyTier.brute:
        // The siege beam.
        enemyHazards.add(
          SurvivalEnemyHazard(
            kind: EnemyHazardKind.beam,
            origin: enemy.position,
            angle: a.aimAngle,
            element: enemy.element,
            damage:
                enemy.damage *
                CosmicSurvivalBalance.bruteBeamDamage(spawner.currentWave),
            life: kEnemyActions[EnemyTier.brute]!.commit,
            maxLife: kEnemyActions[EnemyTier.brute]!.commit,
            length: 900,
            width: 16,
          ),
        );

      case EnemyTier.colossus:
        enemyHazards.add(
          SurvivalEnemyHazard(
            kind: EnemyHazardKind.shockwave,
            origin: enemy.position,
            angle: 0,
            element: enemy.element,
            damage: enemy.damage * 1.4,
            life: kEnemyActions[EnemyTier.colossus]!.commit,
            maxLife: kEnemyActions[EnemyTier.colossus]!.commit,
            maxRadius: 340,
          ),
        );

      case EnemyTier.wisp:
        break;
    }
  }

  /// Below this the detailed per-body silhouettes are affordable and read
  /// better; above it ordinary bodies go through one batched atlas draw.
  static const _kSwarmBatchThreshold = 250;

  /// Above this, sentinels, phantoms and bodies mid-attack also come from the
  /// atlas, with only their attack telegraph drawn live. Device profile at
  /// 3,000: the detailed renderer was 40-48% of the UI thread.
  static const _kDenseFieldThreshold = 1200;
  final SurvivalSwarmBatch _swarmBatch = SurvivalSwarmBatch();

  void _renderEnemy(Canvas canvas, CosmicSurvivalEnemy enemy) {
    drawSurvivalEnemy(
      canvas: canvas,
      enemy: enemy,
      time: stats.timeElapsed,
      reduceLabels: _reduceMinorLabels,
      simplifySwarm: enemies.length >= _kSwarmBatchThreshold,
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

    if (drawKinSpiritWispVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }
    if (drawMysticOrbitalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    )) {
      return;
    }

    // Stationary mystic placements (fog nodes, mire pools, dark wells, plant
    // turrets, monolith pillars, etc.) are environment fixtures: the shared
    // ground-zone painters draw them, else the cast's comet silhouette.
    if (drawMysticOrbitalFixtureVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
      reduceAmbient: _useReducedCompanionProjectileRendering(proj),
    )) {
      return;
    }

    if (drawMaskElementalProjectileVisual(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
      reduceAmbient: _reduceAmbientVfx,
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
      // Performance quality reduces only standard-style shots of families
      // without authored art (shouldUseReducedCompanionProjectileRendering):
      // one disc. (Its slash and decoy-ring branches could not be reached.)
      _companionProjCorePaint.color = eColor.withValues(alpha: 0.88);
      canvas.drawCircle(
        proj.position,
        2.8 * proj.visualScale,
        _companionProjCorePaint,
      );
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

    // A taunting decoy pools its light under itself here; the stroked hoop
    // that used to ring it is gone.
    drawProjectileRoleOverlay(
      canvas: canvas,
      projectile: proj,
      position: proj.position,
      color: eColor,
      time: stats.timeElapsed,
    );
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

    // Elemental aura: light of the creature's material pooled under it, soft
    // to its edge (it was a flat disc in the raw element colour).
    vfxSpill(canvas, Offset.zero, 27, abilityMaterialTint(ec), 0.24);
    // Low health: ember light gathers under it. Its exact health is on its
    // party case; the field carries no bars.
    _paintLowHealthPool(canvas, Offset.zero, comp.hpPercent);

    // ── Kin support-path active overlays ──────────────────────
    if (comp.member.family.toLowerCase() == 'kin') {
      drawAdvancedKinSupportAura(
        canvas: canvas,
        element: comp.member.element,
        color: ec,
        time: stats.timeElapsed,
        iceChargeProgress:
            comp.kinIceChargeTimer > 0 && comp.kinIceChargeTotal > 0
            ? 1 - comp.kinIceChargeTimer / comp.kinIceChargeTotal
            : 0,
        lightningActive: comp.kinLightningChargeTimer > 0,
        fireOrbitalActive: comp.kinFireOrbitalFlameActive,
        fireOrbitalRadius: comp.kinFireFlameRadius,
        lavaPlateActive: comp.kinLavaPlateTimer > 0,
        darkCloakActive: comp.kinDarkCloakTimer > 0,
        steamPressure: comp.kinSteamBoilerTimer > 0
            ? comp.kinSteamBoilerStacks / 10
            : 0,
      );
    }

    // Universal Lava plate overlay — paints a molten glow ring around
    // every active companion (Lava kin or not) while any Lava kin's
    // plate is up, so the team-wide buff is visible.
    if (_isAnyKinLavaPlateActive() &&
        !(comp.member.family.toLowerCase() == 'kin' &&
            comp.member.element == 'Lava')) {
      drawKinLavaPlate(canvas: canvas, time: stats.timeElapsed, scale: 0.85);
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
      Offset? aim;
      final lockedEnemy = comp.kinAutoChargeEnemy;
      final lockedBoss = comp.kinAutoChargeBoss;
      if (lockedBoss != null && !lockedBoss.isDead) {
        aim = lockedBoss.position;
      } else if (lockedEnemy != null && !lockedEnemy.isDead) {
        aim = lockedEnemy.position;
      } else {
        aim = comp.kinAutoChargeTarget;
      }
      drawAdvancedKinCharge(
        canvas: canvas,
        color: ec,
        progress: t,
        time: stats.timeElapsed,
        aimDirection: aim == null ? null : aim - comp.position,
      );
    }

    // Pip+Steam: a steam cloud billows around the pip and thickens as
    // the attack-speed ramp climbs toward its +300% peak.
    if (comp.member.family.toLowerCase() == 'pip' &&
        comp.member.element == 'Steam') {
      final progress =
          (comp.pipSteamWindowTimer /
                  CosmicSurvivalCompanion.pipSteamWindowDuration)
              .clamp(0.0, 1.0);
      // Shared with open space (pip_vfx.dart).
      drawPipSteamCloud(
        canvas: canvas,
        progress: progress,
        time: stats.timeElapsed,
      );
    }

    // Kin+Steam boiler: stack-count badge floating above the kin
    // while the buff window is active. Shows current/max so the
    // player can see when the boiler is at full pressure.
    if (comp.member.family.toLowerCase() == 'kin' &&
        comp.member.element == 'Steam' &&
        comp.kinSteamBoilerTimer > 0) {
      drawKinSteamBadge(
        canvas: canvas,
        stacks: comp.kinSteamBoilerStacks,
        time: stats.timeElapsed,
      );
    }

    // Wing+Plant: flower-collection counter floating above the wing.
    // Shows the current stack count (capped at 50 for the +200%
    // damage cap) so the player can see their power-up at a glance.
    if (comp.member.family.toLowerCase() == 'wing' &&
        comp.member.element == 'Plant') {
      final stacks = comp.abilityKillStacks.clamp(0, 50);
      if (stacks > 0) {
        final badgeY = -34.0;
        // Tiny flower icon: a clump of the pickups' green grains round a
        // warm one (no white pip).
        final plant = vfxMaterial('Plant');
        for (var k = 0; k < 5; k++) {
          final p = Offset(-7, badgeY) + vfxPolar(k * pi * 2 / 5, 2.2);
          vfxGrain(p.dx, p.dy);
        }
        vfxGrainsFlush(canvas, 2.4, plant.glint, 0.95);
        vfxGrain(-7, badgeY);
        vfxGrainsFlush(canvas, 2.2, vfxFlare(vfxMaterial('Light')), 0.9);
        // Numeric counter to the right of the flower. The shadow is a crisp
        // offset: no blurred text shadows in the frame.
        final stackText = TextSpan(
          text: 'x$stacks',
          style: const TextStyle(
            color: Color(0xFFE8ECE4),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Color(0xFF1A2A1A), offset: Offset(0, 1))],
          ),
        );
        final tp = TextPainter(
          text: stackText,
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(-1, badgeY - tp.height * 0.5));
      }
    }

    // Horn+Poison: the reach of the always-on toxic aura — the radius the
    // tick in _applyHornPoisonPassive actually uses (it was drawn at a fixed
    // 140 while the tick grew to 163 / 182).
    if (comp.member.family.toLowerCase() == 'horn' &&
        comp.member.element == 'Poison') {
      drawHornPoisonAura(
        canvas: canvas,
        radius:
            HornRules.poisonAuraRadius *
            hornPoisonAuraScale(_effectiveIntelligence(slotIndex)),
        time: stats.timeElapsed,
      );
    }
    // Horn wind-ups worn on the body: Crystal's shards growing, Lightning's
    // storm brewing where it landed (shared with open space and dungeons).
    if (comp.windUpTimer > 0 && comp.windUpElement == 'Crystal') {
      drawHornWindUpOverlay(
        canvas: canvas,
        element: 'Crystal',
        progress: 1 - comp.windUpTimer / HornRules.crystalWindUp,
        time: stats.timeElapsed,
      );
    } else if (comp.hornPostDashWindUpTimer > 0 &&
        comp.member.element == 'Lightning') {
      drawHornWindUpOverlay(
        canvas: canvas,
        element: 'Lightning',
        progress: 1 - comp.hornPostDashWindUpTimer / HornRules.postDashBrew,
        time: stats.timeElapsed,
      );
    } else if (comp.windUpTimer > 0 && comp.windUpElement == 'Dark') {
      // Dark's void gathering out to the reach _runHornDarkVoidSuck drags.
      drawHornWindUpOverlay(
        canvas: canvas,
        element: 'Dark',
        progress: 1 - comp.windUpTimer / HornRules.darkWindUp,
        time: stats.timeElapsed,
        reach: hornDarkAuraRadius(_effectiveBeauty(slotIndex)),
      );
    }

    // Shield bubble
    if (comp.shieldHp > 0) {
      drawAdvancedCompanionShield(canvas: canvas, time: stats.timeElapsed);
    }

    if (comp.blessingTimer > 0) {
      drawAdvancedBlessingAura(canvas: canvas, time: stats.timeElapsed);
    }

    // Charge trail
    if (comp.chargeTimer > 0) {
      drawAdvancedChargeTrail(
        canvas: canvas,
        color: ec,
        angle: comp.angle,
        sweepRadius: comp.chargeSweepRadius,
        overshootDistance: comp.chargeOvershootDistance,
        element: comp.member.element,
        time: stats.timeElapsed,
      );
    }

    // Sprite rendering (same as cosmic game)
    if (ticker != null) {
      final sprite = ticker.getSprite();
      // What it wears, as open space and the home field show it: its alchemy
      // effect round it (behind, then its near side over the sprite) and
      // its costumes on the sprite.
      final auraR = wornAuraRadius(
        spriteScale * max(sprite.srcSize.x, sprite.srcSize.y),
      );
      paintWornAura(canvas, visuals, auraR, stats.timeElapsed);
      final paint = Paint()..filterQuality = ui.FilterQuality.high;

      // Hit flash: a soft white wash over its own colours, never a cut-out.
      final flash = comp.shownFlash;
      if (flash > 0.01) {
        final v = visuals;
        final List<double>? base = v == null
            ? null
            : isAlbinoLook(v)
            ? (albinoBaked(v) ? null : kAlbinoMatrix)
            : _geneticsMatrix(v);
        paint.colorFilter = ui.ColorFilter.matrix(
          _washMatrix(base, 0.55 * flash * flash),
        );
      } else if (visuals != null) {
        // Apply genetics color filter: none for an albino, whose look is in
        // its sheet — but a mutated one's.
        final v = visuals;
        paint.colorFilter = isAlbinoLook(v)
            ? albinoFilter(v)
            : _geneticsColorFilter(v);
      }

      // Flip sprite to face movement direction (past a margin either way).
      final heading = cos(comp.angle);
      if (heading > 0.25) comp.facingRight = true;
      if (heading < -0.25) comp.facingRight = false;
      final facingRight = comp.facingRight;
      canvas.save();
      if (facingRight) {
        canvas.scale(-spriteScale, spriteScale);
      } else {
        canvas.scale(spriteScale, spriteScale);
      }
      sprite.render(canvas, anchor: Anchor.center, overridePaint: paint);
      paintWornCostumes(
        canvas,
        visuals,
        sprite,
        ticker.currentIndex,
        stats.timeElapsed,
      );
      canvas.restore();
      paintWornAura(canvas, visuals, auraR, stats.timeElapsed, front: true);
    } else {
      // Fallback: circle (no sprite sheet)
      final flashColor = comp.shownFlash > 0
          ? Color.lerp(ec, Colors.white, 0.55 * comp.shownFlash)!
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
  }

  // == Genetics Color Filters (same as cosmic game) ========================

  ui.ColorFilter _geneticsColorFilter(SpriteVisuals v) =>
      ui.ColorFilter.matrix(_geneticsMatrix(v));

  /// [base] (identity when null) washed [w] of the way toward white.
  List<double> _washMatrix(List<double>? base, double w) {
    final m = List<double>.of(base ?? _identityMatrix());
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 4; col++) {
        m[row * 5 + col] *= 1 - w;
      }
      m[row * 5 + 4] = m[row * 5 + 4] * (1 - w) + 255 * w;
    }
    return m;
  }

  List<double> _geneticsMatrix(SpriteVisuals v) {
    var m = _identityMatrix();
    if (v.saturation != 1.0 || v.brightness != 1.0) {
      m = _mulMatrix(_bsSatMatrix(v.brightness, v.saturation), m);
    }
    final rawHue = v.isPrismatic
        ? (v.hueShiftDeg + (stats.timeElapsed * 45.0) % 360)
        : v.hueShiftDeg;
    final normHue = ((rawHue % 360) + 360) % 360;
    if (normHue != 0) m = _mulMatrix(_hueMatrix(normHue), m);
    // No lineage tint over a variant whose palette swap is in its sheet.
    if (v.tint != null &&
        !(v.brightness == 1.45 && !v.isPrismatic) &&
        !variantBaked(v)) {
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
    return m;
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
    final ghostMode = ship.isDead;
    final elapsed = stats.timeElapsed;

    canvas.save();
    canvas.translate(p.dx, p.dy);

    // Kin+Lava plate: molten glow ring on the ship while any Lava
    // kin's plate timer is up.
    if (_isAnyKinLavaPlateActive()) {
      drawKinLavaShipGlow(canvas: canvas, time: elapsed);
    }

    // Kin+Lightning tesla charge: while any Lightning kin is actively
    // channelling, paint a visible electric current around the ship
    // so the player can see the buff is on. Drawn in world space
    // (before rotate) so the arcs aren't tied to ship heading.
    if (_isAnyKinLightningChargeActive()) {
      drawKinTeslaShip(canvas: canvas, time: elapsed);
    }

    // Kin+Dark veil: the decoy is shrouded too, while the veil draws the
    // horde onto it.
    if (_kinDarkVeilDraws) {
      drawKinDarkVeil(
        canvas: canvas,
        center: Offset.zero,
        radius: 30,
        time: elapsed,
      );
    }

    if (!ghostMode) _paintLowHealthPool(canvas, Offset.zero, ship.hpPercent);

    canvas.restore();
    _renderShipHull(canvas, elapsed, ghostMode);
  }

  /// The hull, drawn by the cosmic ship painter (ship_art.dart) so it looks
  /// the same in both modes — minus the light pooled round it, which
  /// survival leaves off. Its wake is laid in world space, so the hull is
  /// drawn at the ship's position rather than on a translated canvas.
  void _renderShipHull(Canvas canvas, double elapsed, bool ghostMode) {
    _shipArt
      ..pos = ship.position
      ..angle = ship.angle;
    if (ghostMode) {
      // Only while respawning, so the layer is not an every-frame cost.
      canvas.saveLayer(
        Rect.fromCircle(center: ship.position, radius: 160),
        Paint()..color = Colors.white.withValues(alpha: 0.45),
      );
    }
    _shipArt.render(
      canvas,
      elapsed,
      skin: shipSkin,
      glow: false,
      flash: ship.hitFlash,
    );
    if (ghostMode) canvas.restore();
  }

  /// Ember light pooled under a body below [_kLowHealth] of its health,
  /// stronger the lower it is.
  void _paintLowHealthPool(Canvas canvas, Offset at, double hp) {
    if (hp >= _kLowHealth) return;
    vfxSpill(
      canvas,
      at + const Offset(0, 10),
      26,
      const Color(0xFFE0703A),
      0.2 + 0.4 * (1 - hp / _kLowHealth),
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

/// One Mask fixture waiting to come back, for Rearm.
class _MaskRearmEntry {
  _MaskRearmEntry({
    required this.slotIndex,
    required this.template,
    required this.timer,
    required this.lifeScale,
    required this.triggers,
    this.placedLife = 0,
  });

  final int slotIndex;
  final Projectile template;
  double timer;
  final double lifeScale;
  final int triggers;

  /// The life the fixture was placed with, for Hair Trigger; 0 when unknown.
  final double placedLife;
}
