import 'dart:collection';
import 'dart:math';
import 'dart:ui' show Offset;

import 'cosmic_data.dart';
import 'horn_runtime.dart' show hornStatScale;

enum CosmicAbilityMode { openSpace, survival }

/// One kind of ground a Let leaves behind: what it does, how wide, how long.
///
/// Survival's numbers, held in one place. Open space used to carry its own
/// copies and they drifted — Steam's vent ran 8s instead of 12, Plant rooted
/// instead of cutting — so all three games now spawn from this.
class LetZoneSpec {
  const LetZoneSpec({
    required this.tick,
    required this.radius,
    required this.duration,
    this.damageShare = 0,
    this.effectShare = 0,
    this.visualScale = 1.35,
  });

  final AbilityEffectKind tick;
  final double radius;
  final double duration;

  /// Tick power as a share of the meteor's damage...
  final double damageShare;

  /// ...or, when [damageShare] is 0, of its effect power.
  final double effectShare;
  final double visualScale;

  double power(Projectile meteor) => damageShare > 0
      ? meteor.damage * damageShare
      : meteor.effectPower * effectShare;
}

class CosmicAbilityRuntime {
  /// How fast a shove dies away: velocity scales by exp(-damping × dt).
  static const double knockbackDamping = 7.5;

  /// A knockback smaller than this (px/s) has stopped.
  static const double knockbackRestSpeed = 2.0;

  /// The velocity an ability's knockback contact adds, from its effect
  /// power (an unset power counts as 4, as every effect's default does).
  static double knockbackImpulse(double power) =>
      (160.0 + (power > 0 ? power : 4.0) * 8.0).clamp(120.0, 520.0);

  /// Heavier bodies take less of an area shove (Let Air's gust and the like).
  static double knockbackMassScale(EnemyTier tier) => switch (tier) {
    EnemyTier.wisp => 1.0,
    EnemyTier.drone => 0.92,
    EnemyTier.sentinel => 0.84,
    EnemyTier.phantom => 0.78,
    EnemyTier.brute => 0.70,
    EnemyTier.colossus => 0.60,
  };

  /// A geyser throws what it scalds upward.
  static const Offset geyserKnockback = Offset(0, -140);

  /// A leech hit feeds the objective (survival's orb; open space's ship)
  /// this share of its power, and the caster the whole of it.
  static const double leechObjectiveShare = 0.45;

  /// A flower (or alchemy-bonus) hit feeds the objective this share.
  static const double flowerObjectiveShare = 0.30;

  /// A buff hit hastes its caster's basic attack to this at most.
  static const double buffHasteMultiplier = 0.72;

  /// A carry hit (Mane Water's contact) pushes the body this far from the
  /// point of contact.
  static const double carryHitPush = 18.0;

  /// A pull or black-hole hit drags every body within its radius toward the
  /// origin by this much (harder close in), and slows it to
  /// [blackHoleSlow] for the effect's duration.
  static double blackHolePullStep(double distance) =>
      min(28.0, 720.0 / distance);
  static const double blackHoleSlow = 0.25;

  /// A black-hole hit eats the bodies in its radius at or under this share
  /// of their health.
  static const double blackHoleExecute = 0.18;

  /// Chain lightning: each hop looks this far from the body it left.
  static const double chainRange = 135.0;

  /// Chain lightning: hop [i] (0 first) takes this much of [base].
  static double chainBounceDamage(double base, int i) =>
      base * (0.55 - i * 0.10).clamp(0.25, 0.55);

  /// The index of the entry with the lowest health fraction, first-wins on a
  /// tie — whom a zone heal tends. [fractions] are current/max; -1 if empty.
  static int lowestFraction(List<double> fractions) {
    var best = -1;
    var lowest = double.infinity;
    for (var i = 0; i < fractions.length; i++) {
      if (fractions[i] < lowest) {
        lowest = fractions[i];
        best = i;
      }
    }
    return best;
  }

  /// The ground a Let leaves where it COLLIDES — the board's "if collides"
  /// half. Null for elements whose contact effect leaves nothing behind.
  static LetZoneSpec? letContactZone(String? element) => switch (element) {
    'Dust' => const LetZoneSpec(
      tick: AbilityEffectKind.slow,
      radius: 130,
      duration: 4.5,
      effectShare: 0.25,
    ),
    'Lava' => const LetZoneSpec(
      tick: AbilityEffectKind.burn,
      radius: 145,
      duration: 4.2,
      damageShare: 0.13,
    ),
    'Poison' => const LetZoneSpec(
      tick: AbilityEffectKind.poison,
      radius: 116,
      duration: 3.8,
      damageShare: 0.08,
      visualScale: 1.9,
    ),
    'Earth' => const LetZoneSpec(
      tick: AbilityEffectKind.stun,
      radius: 128,
      duration: 3.2,
      damageShare: 0.10,
      visualScale: 1.55,
    ),
    _ => null,
  };

  /// The ground a Let leaves where it KILLS — the board's "if kills" half.
  /// Plant is not here: its vines are traps, not a zone (see [letVineSpots]).
  static LetZoneSpec? letKillZone(String? element) => switch (element) {
    'Light' => const LetZoneSpec(
      tick: AbilityEffectKind.zoneHeal,
      radius: 130,
      duration: 5.5,
      damageShare: 0.16,
      visualScale: 1.7,
    ),
    'Steam' => const LetZoneSpec(
      tick: AbilityEffectKind.geyser,
      radius: 115,
      duration: 12.0,
      damageShare: 0.12,
      visualScale: 1.6,
    ),
    'Mud' => const LetZoneSpec(
      tick: AbilityEffectKind.stun,
      radius: 130,
      duration: 4.8,
      damageShare: 0.08,
      visualScale: 1.5,
    ),
    _ => null,
  };

  /// Plant's kill: vines grow round the kill and wait. Per the board they
  /// "remain until an enemy collides with them" and "do damage" — each one is
  /// a trap that strikes the first body to come within [kLetVineReach] and is
  /// spent doing it.
  ///
  /// This replaced four overlapping 30-second damage fields. They sat almost
  /// on top of one another, so a body in the middle took four ticks every
  /// 0.35s and the kill left what was really one very strong damage zone.
  static const int kLetVineCount = 5;
  static const double kLetVineReach = 34.0;

  /// "Until an enemy collides" needs some ceiling so an unvisited corner of
  /// the arena does not collect vines forever.
  static const double kLetVineLife = 30.0;

  /// What one vine strikes for, as a share of the meteor's damage.
  static const double kLetVineDamageShare = 0.45;

  /// Where the vines grow: a ring round the kill, far enough apart that no
  /// two reaches overlap, turned by the cast so repeat kills do not stamp the
  /// same pattern.
  static List<Offset> letVineSpots(Offset centre, double angle) => [
    for (var i = 0; i < kLetVineCount; i++)
      centre +
          Offset(
                cos(angle + i * pi * 2 / kLetVineCount),
                sin(angle + i * pi * 2 / kLetVineCount),
              ) *
              (82.0 + (i.isEven ? 10.0 : 0.0)),
  ];

  static bool isLetVine(Projectile p) =>
      p.abilityFamily == 'let' &&
      p.stationary &&
      p.element == 'Plant' &&
      p.visualStyle == ProjectileVisualStyle.letShard;

  /// A vine, ready to be placed at [at]. Its strike is carried in
  /// [Projectile.effectPower]; [Projectile.damage] stays 0 so the ordinary
  /// contact pass never bills a body for touching it.
  static Projectile letVine(Projectile meteor, Offset at) => Projectile(
    position: at,
    angle: 0,
    element: 'Plant',
    damage: 0,
    life: kLetVineLife,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    // Let ground never collides, so the only thing still reading this is
    // survival's viewport cull — sized to the art so it does not pop out
    // at the screen edge.
    radiusMultiplier: 5.5,
    visualScale: 1.2,
    visualStyle: ProjectileVisualStyle.letShard,
    sourceSlotIndex: meteor.sourceSlotIndex,
    abilityFamily: 'let',
    effectPower: meteor.damage * kLetVineDamageShare,
    effectRadius: kLetVineReach,
    effectDuration: kLetVineLife,
  );

  /// A zone from [spec], ready to be placed at [at].
  static Projectile letZone(
    Projectile meteor,
    Offset at,
    String element,
    LetZoneSpec spec,
  ) => Projectile(
    position: at,
    angle: 0,
    element: element,
    damage: 0,
    life: spec.duration,
    speedMultiplier: 0,
    stationary: true,
    piercing: true,
    // Only survival's viewport cull reads this now (see [letVine]); sized so
    // a zone whose centre is just off screen is still drawn.
    radiusMultiplier: spec.radius / 7.0,
    visualScale: spec.visualScale,
    visualStyle: ProjectileVisualStyle.letShard,
    sourceSlotIndex: meteor.sourceSlotIndex,
    abilityFamily: 'let',
    tickEffect: spec.tick,
    effectPower: spec.power(meteor),
    effectRadius: spec.radius,
    effectDuration: spec.duration,
  );

  /// How far Air's knockback reaches, and Water's and Fire's second hits —
  /// the radii the aftermath beats are drawn to.
  static double letAirReach(Projectile p) => max(180.0, p.effectRadius);
  static double letWaterReach(Projectile p) => max(125.0, p.effectRadius);
  static double letFireReach(Projectile p) => max(555.0, p.effectRadius * 3.0);

  /// How long Ice's freeze and Crystal's slow hold the body they struck.
  static const double kLetIceHold = 3.2;
  static const double kLetCrystalHold = 3.5;

  static bool isLetMeteorCore(Projectile projectile) =>
      projectile.visualStyle == ProjectileVisualStyle.meteor;

  static bool letMeteorCanSpawnPersistentZones(Projectile projectile) =>
      isLetMeteorCore(projectile);

  /// Walks a descending Let meteor one frame down its drop line. Returns true
  /// on the single frame it touches down, which is the caller's cue to
  /// detonate it.
  ///
  /// The descent is parametric rather than simulated: the meteor's height
  /// above the impact point is a function of how much of [Projectile
  /// .skyfallDuration] is left, so it lands exactly on time at exactly
  /// [Projectile.skyfallImpact]. A velocity-driven fall can overshoot or
  /// arrive early, and a Let that lands somewhere other than where its
  /// telegraph promised is worse than one that never moved.
  ///
  /// [liveTarget] is the locked enemy's current position, or null once that
  /// enemy is gone. While it is supplied the impact point tracks it, tightly
  /// enough that an enemy cannot walk out from under the drop. That is
  /// deliberate: choosing where and when to drop a meteor is the decision,
  /// and making the player also lead a moving target would turn it into a
  /// reflex test.
  static bool advanceSkyfall(Projectile p, double dt, Offset? liveTarget) {
    if (p.skyfallDuration <= 0 || p.skyfallRemaining <= 0) return false;

    if (liveTarget != null) {
      // Tracking tightens as the meteor closes, so the trajectory reads as
      // committed early and unmissable late. A constant rate either looks
      // like the rock is steering itself, or lets a fast enemy escape.
      final closing = 1.0 - p.skyfallRemaining / p.skyfallDuration;
      final pull = ((0.18 + 0.82 * closing) * dt * 12.0).clamp(0.0, 1.0);
      p.skyfallImpact = Offset.lerp(p.skyfallImpact, liveTarget, pull)!;
    }

    p.skyfallRemaining = max(0.0, p.skyfallRemaining - dt);
    final remaining = p.skyfallRemaining / p.skyfallDuration;
    // A fall: it leaves the top at rest and is fastest at touchdown, so the
    // meteor creeps at the top of its arc and slams through the last
    // stretch. (It was remaining², which is the other way round — fastest
    // at the top, easing to a stop on the ground.) Linear descent reads as
    // a lift, not a fall.
    final height = p.skyfallDistance * remaining * (2 - remaining);
    p.position = p.skyfallImpact - Offset(cos(p.angle), sin(p.angle)) * height;
    return p.skyfallRemaining <= 0;
  }

  static int darkLetFollowupCount(double casterIntelligence) {
    return (2 + ((casterIntelligence - 0.5) / 4.5) * 3)
        .round()
        .clamp(2, 5)
        .toInt();
  }

  static double projectileEffectPower(
    Projectile projectile, {
    double fallbackMultiplier = 0.35,
    double fallbackPower = 4.0,
  }) {
    if (projectile.effectPower > 0) return projectile.effectPower;
    final fromDamage = projectile.damage * fallbackMultiplier;
    return fromDamage > 0 ? fromDamage : fallbackPower;
  }

  static double projectileEffectRadius(
    Projectile projectile, {
    double fallbackRadius = 80.0,
  }) {
    return projectile.effectRadius > 0
        ? projectile.effectRadius
        : fallbackRadius;
  }

  static double projectileEffectDuration(
    Projectile projectile, {
    double fallbackDuration = 1.5,
  }) {
    return projectile.effectDuration > 0
        ? projectile.effectDuration
        : fallbackDuration;
  }

  static bool isCrowdControl(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.slow ||
      AbilityEffectKind.root ||
      AbilityEffectKind.freeze ||
      AbilityEffectKind.stun ||
      AbilityEffectKind.suppressShooting => true,
      _ => false,
    };
  }

  /// Whether an effect still means something when its target is already dead.
  ///
  /// A KILL effect resolves against an enemy that has just died — that is what
  /// makes it a kill effect. The survival handler opened with a blanket
  /// `if (enemy.isDead) return`, so every kill effect routed through it was
  /// dropped on arrival: Pip+Blood and Pip+Light's heals, Plant's alchemy
  /// bonus, Water's splash, Crystal's taunt.
  ///
  /// Effects that change the enemy's own STATE — slowing it, freezing it,
  /// burning it — genuinely have nothing to do on a corpse and stay blocked.
  /// Effects that heal the caster, feed the orb, or act on the world around
  /// the kill do not care whether the body is still standing.
  static bool resolvesOnDeadTarget(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.leech ||
      AbilityEffectKind.zoneHeal ||
      AbilityEffectKind.buff ||
      AbilityEffectKind.cooldownRefund ||
      AbilityEffectKind.alchemyBonus ||
      AbilityEffectKind.flower ||
      AbilityEffectKind.splash ||
      AbilityEffectKind.blackHole ||
      AbilityEffectKind.taunt => true,
      _ => false,
    };
  }

  static bool isDirectDamage(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.burn ||
      AbilityEffectKind.poison ||
      AbilityEffectKind.zoneDamage ||
      AbilityEffectKind.geyser ||
      AbilityEffectKind.refraction ||
      AbilityEffectKind.chargeBlast ||
      AbilityEffectKind.execute => true,
      _ => false,
    };
  }

  static double directDamageForEffect(
    AbilityEffectKind effect, {
    required double power,
    required double targetHp,
    required double targetHpFraction,
  }) {
    if (effect == AbilityEffectKind.execute && targetHpFraction <= 0.20) {
      return targetHp + 1;
    }
    if (effect == AbilityEffectKind.execute) return power * 1.35;
    if (effect == AbilityEffectKind.chargeBlast) return power * 2.8;
    return power;
  }

  static double splashMultiplier(AbilityEffectKind effect) {
    return effect == AbilityEffectKind.chain ? 0.72 : 0.55;
  }

  static double openSpaceCrowdControlDuration(double duration) {
    if (duration >= 30) return duration.clamp(0.4, 60.0);
    return duration.clamp(0.4, 3.2);
  }

  static double survivalSlowMultiplier(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.freeze => 0.05,
      AbilityEffectKind.root => 0.0,
      AbilityEffectKind.stun => 0.08,
      AbilityEffectKind.suppressShooting => 0.72,
      _ => 0.45,
    };
  }

  static double survivalCrowdControlDuration(
    AbilityEffectKind effect,
    double duration,
  ) {
    final base = duration > 0 ? duration : 1.5;
    return effect == AbilityEffectKind.stun ? base * 0.7 : base;
  }

  static double maneCarryDistance(double effectPower) {
    return max(28.0, effectPower * 0.15).clamp(28.0, 64.0).toDouble();
  }

  static bool isSurvivalOnlyEffect(AbilityEffectKind effect) {
    return switch (effect) {
      AbilityEffectKind.alchemyBonus || AbilityEffectKind.flower => true,
      _ => false,
    };
  }

  /// How far a turret looks for a body to shoot at.
  static const double turretTargetRange = 360.0;

  /// The shot a placed turret fires at [targetPos] (a Mask Steam geyser, a
  /// Mystic Plant turret, an orbiting escort orb): Survival's shot, per
  /// element.
  static Projectile companionTurretShot(Projectile orb, Offset targetPos) {
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

  /// Where a void (a Mask Dark hole, a Mystic Dark maw) puts a body it
  /// throws out of the fight: on the ring of radius [ring] round [center],
  /// and never back in the mouth of the hole at [hole].
  static Offset fieldEjectLanding({
    required Offset center,
    required double ring,
    required Offset hole,
    required double holeRadius,
    required Random rng,
  }) {
    // A hole's pull can reach past that ring, so a body landing on its own
    // bearing would be eaten again immediately and never get anywhere —
    // stuck in a loop at the edge of the screen forever.
    var landing = center;
    for (var attempt = 0; attempt < 10; attempt++) {
      final a = rng.nextDouble() * 2 * pi;
      landing = center + Offset(cos(a), sin(a)) * ring;
      if ((landing - hole).distance > holeRadius * 1.2) break;
      if (attempt == 9) {
        // Fallback: straight across from the hole.
        final away = center - hole;
        final d = away.distance;
        final norm = d > 1 ? away / d : const Offset(0, 1);
        landing = center + norm * ring;
      }
    }
    return landing;
  }

  /// How an ejected body is held as it lands, so it walks the long way back.
  static const double ejectSlowMultiplier = 0.4;
  static const double ejectSlowDuration = 1.5;
}

/// Wing's beam rules — pure arithmetic, one copy for every game.
///
/// Survival is where the beams were built and tuned and is the source of
/// truth; open space used to carry its own numbers and they drifted (six
/// fixed Steam clouds instead of five to fourteen, a smaller Lava scar, two
/// thinner Light refractions, Ice frost at a different rate). Each game keeps
/// only what touches its own world: which bodies a beam crosses, how a hit
/// lands, where a zone is appended. Stats come in raw (survival adds its
/// power-ups first); every curve is survival's [hornStatScale], baseline 3.
abstract final class WingBeamRules {
  /// Live beams a game holds; the oldest goes when a new one would pass it.
  static const int beamCap = 14;

  /// How far from a line beam's segment a body is struck, before its own
  /// radius. Also the reach a boss is tested at.
  static double hitRadius(WingBeamEffect d) => max(10.0, d.width * 1.45);

  /// The radius a line beam hands its tick effect.
  static double lineEffectRadius(WingBeamEffect d) => hitRadius(d) * 6;

  /// A line beam's hit on one body: Blood's execute below its threshold,
  /// Lightning's charged multiplier, otherwise the flat tick.
  static double tickDamage(
    WingBeamEffect d, {
    required double hp,
    required double hpFraction,
  }) {
    if (d.executeThreshold > 0 && hpFraction <= d.executeThreshold) {
      return max(d.damagePerTick, hp + 1);
    }
    if (d.tickEffect == AbilityEffectKind.chargeBlast) {
      return CosmicAbilityRuntime.directDamageForEffect(
        d.tickEffect,
        power: d.damagePerTick,
        targetHp: hp,
        targetHpFraction: hpFraction,
      );
    }
    return d.damagePerTick;
  }

  /// A healing beam's tick heals the ship and the caster by its full heal,
  /// and survival's orb by this share of it.
  static const double orbHealShare = 0.55;

  // ── Ice ──
  /// Frost each tick adds; full (1.0) snaps the body into a freeze.
  static const double frostPerTick = 0.14;
  static const double freezeHold = 2.6;
  static const double freezeSlow = 0.05;

  // ── Lightning ──
  /// The blast is this many ticks' damage in one hit...
  static const double blastDamageScale = 18.0;

  /// ...and a body that lives through it takes its charged rider at this
  /// many times the effect power.
  static const double blastEffectScale = 3.0;

  /// How far from the blast line a body is struck, before its own radius.
  static double blastRadius(WingBeamEffect d) => max(22.0, d.width * 2.6);

  // ── Lava ──
  /// The glowing scar a Lava beam drops at its end every tick. Size follows
  /// Beauty, life Intelligence.
  static Projectile lavaScar(
    WingBeamEffect d,
    Offset at, {
    required double beauty,
    required double intelligence,
    int? sourceSlotIndex,
  }) {
    final size = hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.30);
    final dur = hornStatScale(
      intelligence,
      perPoint: 0.10,
      min: 0.88,
      max: 1.30,
    );
    return Projectile(
      position: at,
      angle: 0,
      element: 'Lava',
      damage: 0,
      life: 2.6 * dur,
      speedMultiplier: 0,
      stationary: true,
      piercing: true,
      radiusMultiplier: 1.2 * size,
      visualScale: 1.1 * size,
      visualStyle: ProjectileVisualStyle.sigil,
      sourceSlotIndex: sourceSlotIndex,
      abilityFamily: 'wing',
      tickEffect: AbilityEffectKind.burn,
      effectPower: d.damagePerTick * 0.45,
      effectRadius: 38 * size,
      effectDuration: 2.6 * dur,
    );
  }

  // ── Steam ──
  /// The field of clouds a Steam beam's first touch erupts round [center]:
  /// five to ten, more with Beauty (up to fourteen), bigger with Beauty,
  /// longer-lived with Intelligence.
  static List<Projectile> steamClouds(
    WingBeamEffect d,
    Offset center,
    Random rng, {
    required double beauty,
    required double intelligence,
    int? sourceSlotIndex,
  }) {
    final countScale = hornStatScale(
      beauty,
      perPoint: 0.08,
      min: 0.85,
      max: 1.30,
    );
    final sizeScale = hornStatScale(
      beauty,
      perPoint: 0.10,
      min: 0.85,
      max: 1.30,
    );
    final durScale = hornStatScale(
      intelligence,
      perPoint: 0.10,
      min: 0.88,
      max: 1.30,
    );
    final baseCount = 5 + rng.nextInt(6);
    final count = (baseCount * countScale).round().clamp(5, 14);
    final clouds = <Projectile>[];
    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + rng.nextDouble() * 0.7;
      final dist = (12.0 + rng.nextDouble() * 52.0) * sizeScale;
      clouds.add(
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
    return clouds;
  }

  // ── Light ──
  /// A kill refracts the beam only while this much of it is left.
  static const double lightSplitMinRemaining = 0.3;

  /// The smaller hunting beam a Light kill refracts into, living out the
  /// parent's [remaining] time. Beauty grows its share.
  static WingBeamEffect lightSplitChild(
    WingBeamEffect d, {
    required double remaining,
    required double beauty,
  }) {
    final refractScale = hornStatScale(
      beauty,
      perPoint: 0.08,
      min: 0.85,
      max: 1.25,
    );
    return WingBeamEffect(
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
  }

  /// The children's headings off the parent's: two, or three for a
  /// high-Beauty wing (the raw stat, as survival reads it).
  static List<double> lightSplitOffsets(double beauty) {
    final count = beauty >= 4.5 ? 3 : 2;
    return [
      for (var i = 0; i < count; i++)
        count == 2 ? (i == 0 ? -0.5 : 0.5) : (i - 1) * 0.45,
    ];
  }

  // ── Plant ──
  /// A Plant beam's damage multiplier from the flowers its caster has
  /// collected: 4 % a flower at Beauty 3, more with Beauty, at most 4×.
  static double plantStackBonus(int stacks, double beauty) {
    final perStack =
        0.04 * hornStatScale(beauty, perPoint: 0.10, min: 0.85, max: 1.50);
    return (1.0 + stacks.clamp(0, 50) * perStack).clamp(1.0, 4.0);
  }

  /// A flower lasts this long uncollected...
  static const double flowerLife = 12.0;

  /// ...and a game holds at most this many.
  static const int flowerCap = 80;

  /// The ship collects a flower this close, and pulls one in from this far
  /// at up to this speed, faster the closer it is.
  static const double flowerCollectRadius = 56.0;
  static const double flowerMagnetRadius = 180.0;
  static const double flowerMagnetMaxSpeed = 340.0;

  /// One frame of a flower at [flower] drifting toward the ship at
  /// [collector]: null once it is collected, else where it now is.
  static Offset? flowerStep(Offset flower, Offset collector, double dt) {
    final dx = collector.dx - flower.dx;
    final dy = collector.dy - flower.dy;
    final distSq = dx * dx + dy * dy;
    if (distSq <= flowerCollectRadius * flowerCollectRadius) return null;
    if (distSq > flowerMagnetRadius * flowerMagnetRadius) return flower;
    final dist = sqrt(distSq);
    final norm = Offset(dx / dist, dy / dist);
    final t = 1.0 - (dist / flowerMagnetRadius);
    final speed = flowerMagnetMaxSpeed * t * t;
    return Offset(
      flower.dx + norm.dx * speed * dt,
      flower.dy + norm.dy * speed * dt,
    );
  }
}

/// The ability projectiles one side has in flight, refusing new ones past
/// [cap] — Survival's pool ceiling (its `_appendCompanionProjectile`). Some
/// casts feed themselves: a Mane Lava pool that touches a body drops another
/// pool, which touches the body and drops another. The ceiling is what keeps
/// that bounded; without it a creature standing in the lava grows the pool by
/// sixty a second.
class CappedProjectileList extends ListBase<Projectile> {
  CappedProjectileList({this.cap = 220});

  final int cap;
  final List<Projectile> _items = [];

  @override
  int get length => _items.length;

  @override
  set length(int value) => _items.length = value;

  @override
  Projectile operator [](int index) => _items[index];

  @override
  void operator []=(int index, Projectile value) => _items[index] = value;

  @override
  void add(Projectile element) {
    if (_items.length < cap) _items.add(element);
  }

  @override
  void addAll(Iterable<Projectile> iterable) {
    for (final p in iterable) {
      if (_items.length >= cap) return;
      _items.add(p);
    }
  }

  @override
  Projectile removeAt(int index) => _items.removeAt(index);

  @override
  void removeWhere(bool Function(Projectile element) test) =>
      _items.removeWhere(test);

  @override
  void clear() => _items.clear();
}
