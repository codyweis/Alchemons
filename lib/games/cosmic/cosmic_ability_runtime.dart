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

/// A per-caster ceiling on heals that grow with the bodies an ability
/// touches: Mane Blood's heal on every pierce and the Wing leech beams.
///
/// Those heals scale with bodies touched times casts, so a well-bred caster
/// in a dense wave out-healed everything the objective took — Mane Blood up
/// to 8x of all incoming orb damage — and the run stopped being losable.
/// Each caster now refills a small budget, a share of the objective's health
/// per second that grows with Beauty, and banks at most [bucketSeconds] of
/// it. The heal still answers damage as it happens and still grows with the
/// creature; it just can't outrun a wave near the team's wall.
class HealCeiling {
  /// Share of the objective's max health a caster may restore per second at
  /// average Beauty; [scaledAbilityValue] takes it to about 1.7x at perfect.
  static const double sharePerSecond = 0.012;
  static const double bucketSeconds = 2.0;

  final Map<int, double> _budget = {};
  final Map<int, double> _at = {};

  /// How much of [amount] caster [slot] may heal now, spending it. [pool] is
  /// the objective's max health, [now] the game clock in seconds.
  double grant({
    required int? slot,
    required double amount,
    required double pool,
    required double beauty,
    required double now,
  }) {
    if (amount <= 0) return 0;
    if (slot == null) return amount;
    final rate =
        pool *
        sharePerSecond *
        scaledAbilityValue(beauty, atLow: 0.8, atAverage: 1.0, atPerfect: 1.7);
    final cap = rate * bucketSeconds;
    final last = _at[slot];
    final budget = last == null
        ? cap
        : min(cap, (_budget[slot] ?? cap) + (now - last) * rate);
    final granted = min(amount, budget);
    _budget[slot] = budget - granted;
    _at[slot] = now;
    return granted;
  }

  void clear() {
    _budget.clear();
    _at.clear();
  }
}

/// The persistent pieces a caster's specials leave on the field — zones,
/// walls, clouds, pools, wards, traps, decoys, orbitals — and the one rule
/// that keeps them from piling up with cadence (ability pass M7).
///
/// A piece lives its authored time, and a better-bred creature recasts up to
/// three times as fast, so its pieces used to stack: Kin Earth's wall went
/// from 14 live segments to 64, Pip Fire's pools ×7. Now a caster keeps the
/// pieces of its last few casts ([windowFor]: two, three for a Kin): each
/// recast, every piece it already had counts one more recast, and a piece
/// that has seen its window of them fades out. A caster whose pieces die of
/// age first never meets the rule (an average one rarely does), and a fast
/// one holds about what its window of casts lays, whatever its cadence.
///
/// Every game calls [onCast] where its special fires (survival, open space,
/// dungeons), so the rule is the same everywhere — including Mask traps when
/// Mask casts faster.
abstract final class CasterPieces {
  /// How many casts' worth of pieces a caster keeps.
  static const int castWindow = 2;

  /// The Kin supports keep three: their pieces are authored to span about
  /// three casts at an average stat (trap persistence ×3), and a window of
  /// two cut an average Kin's heal at Potential 70 by a sixth.
  static const int kinCastWindow = 3;

  /// A retired piece fades over this long rather than popping out.
  static const double retireFade = 0.35;

  static final Expando<int> _recastsSeen = Expando('casterPieceRecasts');

  /// Whether [p] holds a place on the field: stationary, orbiting or riding
  /// someone, or a decoy. A shot still in flight is not a piece.
  static bool holdsPlace(Projectile p) =>
      p.stationary ||
      p.holdOrbit ||
      p.orbitCenter != null ||
      p.followSourceCompanion ||
      p.followShipOrbit ||
      p.decoy;

  /// A fixture a recast feeds or refreshes in place instead of laying anew:
  /// the Mane Light ward's rings, the Mask Plant vine, a Mask Dust shield, a
  /// Kin Spirit wisp. One cast never laid it, so no recast retires it. A
  /// mastery's own pieces keep their own budgets too.
  static bool isStandingFixture(Projectile p) {
    if (p.masteryGenerated || p.masteryNoLifetime) return true;
    return switch ((p.abilityFamily, p.element)) {
      ('mane', 'Light') => p.holdOrbit,
      ('mask', 'Plant') => p.stationary,
      ('mask', 'Dust') => p.attachedToSlot != -2,
      ('kin', 'Spirit') => p.followSourceCompanion,
      _ => false,
    };
  }

  /// A Plant Let's vines wait up to 30 s for a body, and a Let throws every
  /// two or three seconds, so they keep the last four casts' worth: up to
  /// twenty vines a Let rather than a ring per throw for half a minute.
  static const int letVineCastWindow = 4;

  /// A Mask's traps keep its last three casts: a trap outlives two recasts.
  ///
  /// The traps are the family's whole special, authored to live 8-22 s and
  /// wait for the wave to walk into them, and a bred Mask recasts every 5-10
  /// s. On two casts Air's 25 s pads lived 18.6 s at Potential 80 and 10.5 s
  /// at 100 + Enhancement 10 (2026-10-20 audit); on three, every zone but
  /// Air's lives its authored life through Potential 80.
  static const int maskCastWindow = 3;

  /// How many casts' worth an ability keeps: [castWindow], [kinCastWindow]
  /// for the Kin supports, [maskCastWindow] for Mask traps, 1 for Pip Poison
  /// (its web lasts until the next cast, per the board), [letVineCastWindow]
  /// for a Plant Let's vines, or null for Kin Dust, whose clouds piling up
  /// cast after cast to their own cap (KinSupport.dustCloudCap) is the
  /// ability, and for the other Lets.
  ///
  /// A Let's ground lives a few seconds (Lava's 4.2 to Steam's 9) and is
  /// laid only where a meteor landed, so it never piles up; on a two-cast
  /// window a Let throwing every two or three seconds cut every pool and
  /// vent short (2026-10-20 audit).
  static int? windowFor(String family, String? element) =>
      switch ((family, element)) {
        ('kin', 'Dust') => null,
        ('kin', _) => kinCastWindow,
        ('mask', _) => maskCastWindow,
        ('pip', 'Poison') => 1,
        ('let', 'Plant') => letVineCastWindow,
        ('let', _) => null,
        _ => castWindow,
      };

  /// [slot] has just cast its [family]/[element] special (before the cast
  /// lays anything). Its pieces in [pieces] each count one more recast; those
  /// past their window fade out.
  static void onCast(
    Iterable<Projectile> pieces, {
    required int? slot,
    required String family,
    required String? element,
  }) {
    if (slot == null) return;
    final fam = family.toLowerCase();
    final window = windowFor(fam, element);
    if (window == null) return;
    for (final p in pieces) {
      if (p.sourceSlotIndex != slot ||
          p.life <= 0 ||
          p.abilityFamily != fam ||
          p.element != element ||
          !holdsPlace(p) ||
          isStandingFixture(p)) {
        continue;
      }
      final seen = (_recastsSeen[p] ?? 0) + 1;
      _recastsSeen[p] = seen;
      if (seen >= window) p.life = min(p.life, retireFade);
    }
  }
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

  /// How hard a geyser throws what it scalds, px/s added each tick.
  static const double geyserKnockbackSpeed = 140;

  /// A geyser throws what it scalds away from [from]: in survival the orb,
  /// the point the party defends; in open space and the battle the geyser's
  /// own centre. It used to throw everything up the screen, which under the
  /// orb was straight at it (2026-10-20 audit). A body standing exactly on
  /// [from] still goes up.
  static Offset geyserKnockbackFrom(Offset from, Offset body) {
    final dx = body.dx - from.dx;
    final dy = body.dy - from.dy;
    final d = sqrt(dx * dx + dy * dy);
    if (d < 0.01) return const Offset(0, -geyserKnockbackSpeed);
    final s = geyserKnockbackSpeed / d;
    return Offset(dx * s, dy * s);
  }

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
    // Steam's vent vents for 9 s (it was 12, which read 3.4x the median
    // special at P50; final balance, 2026-10-10).
    'Steam' => const LetZoneSpec(
      tick: AbilityEffectKind.geyser,
      radius: 115,
      duration: 9.0,
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

  /// A zone from [spec], ready to be placed at [at]. Its reach grows with the
  /// caster's Intelligence past an average stat ([letZoneReach]); the
  /// authored radius is the average creature's.
  static Projectile letZone(
    Projectile meteor,
    Offset at,
    String element,
    LetZoneSpec spec,
  ) {
    final reach = letZoneReach(meteor.letCasterIntelligence);
    final radius = spec.radius * reach;
    return Projectile(
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
      radiusMultiplier: radius / 7.0,
      visualScale: spec.visualScale * reach,
      visualStyle: ProjectileVisualStyle.letShard,
      sourceSlotIndex: meteor.sourceSlotIndex,
      abilityFamily: 'let',
      tickEffect: spec.tick,
      effectPower: spec.power(meteor),
      effectRadius: radius,
      effectDuration: spec.duration,
    );
  }

  /// How far Air's knockback reaches, and Water's and Fire's second hits —
  /// the radii the aftermath beats are drawn to.
  static double letAirReach(Projectile p) => max(180.0, p.effectRadius);
  static double letWaterReach(Projectile p) => max(125.0, p.effectRadius);
  static double letFireReach(Projectile p) =>
      p.effectRadius * kLetFireKillReach;

  /// Fire's kill blast reaches this many times the meteor's own blast. It was
  /// three times with a 555 px floor: most of the arena at every band, so a
  /// kill re-blasted the whole wave and Let Fire measured 5-6.5x the median
  /// special at every band. Trimming its damage barely moved that, because
  /// the blast already killed what it reached (ability pass, final balance,
  /// 2026-10-10).
  static const double kLetFireKillReach = 2.0;

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
  /// The impact point never moves once thrown. It used to slide after the
  /// locked enemy, which made the rock read as a guided missile; it never
  /// needed to, because no enemy covers the crater's radius in one descent.
  static bool advanceSkyfall(Projectile p, double dt) {
    if (p.skyfallDuration <= 0 || p.skyfallRemaining <= 0) return false;

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

  /// How many follow-up meteors a Dark Let's kill calls down: two from a weak
  /// caster, three from an average one, five from a perfect one, by
  /// Intelligence on the anchored count curve. It was a straight line that
  /// already read five at an average stat, so the volley never grew past P50
  /// (ability pass, final balance, 2026-10-10).
  static int darkLetFollowupCount(double casterIntelligence) =>
      scaledAbilityCount(
        casterIntelligence,
        atLow: 2,
        atAverage: 3,
        atPerfect: 5,
      );

  /// Where a Dark Let's follow-ups fall: spread by angle round the kill at
  /// [centre], one to each of [count] equal slices of the circle (turned by
  /// [startAngle]). A slice's follow-up takes the body in [bodies] nearest the
  /// kill in it that stands at least [minDistance] out (the parent's crater,
  /// just cleared) and at least [spacing] from the aims already chosen, or
  /// failing that the nearest that keeps the spacing. A slice with no such
  /// body takes the one furthest from every aim so far, if it keeps the
  /// spacing, and otherwise open ground along the slice's middle, past the
  /// parent's crater ([fallbackDistance] at least).
  ///
  /// The follow-ups used to take the first bodies the enemy grid visited,
  /// and it visits west to east, so the whole bombardment came down on one
  /// side of the kill (2026-10-20 audit). In slice order, so the staggered
  /// barrage rolls round the kill.
  static List<Offset> darkLetFollowupAims({
    required Offset centre,
    required List<Offset> bodies,
    required int count,
    required double startAngle,
    required double spacing,
    double minDistance = 0,
    double fallbackDistance = 180.0,
  }) {
    if (count <= 0) return const [];
    final slice = 2 * pi / count;
    final minSq = minDistance * minDistance;
    final spacingSq = spacing * spacing;
    final aims = List<Offset?>.filled(count, null);
    final taken = <int>{};
    bool spaced(Offset at) {
      for (final aim in aims) {
        if (aim == null) continue;
        final d = at - aim;
        if (d.dx * d.dx + d.dy * d.dy < spacingSq) return false;
      }
      return true;
    }

    int sliceOf(Offset at) {
      final d = at - centre;
      final a = (atan2(d.dy, d.dx) - startAngle) % (2 * pi);
      return min(count - 1, (a / slice).floor());
    }

    for (var k = 0; k < count; k++) {
      var best = -1;
      var bestSq = double.infinity;
      var near = -1;
      var nearSq = double.infinity;
      for (var i = 0; i < bodies.length; i++) {
        if (taken.contains(i) || sliceOf(bodies[i]) != k) continue;
        if (!spaced(bodies[i])) continue;
        final d = bodies[i] - centre;
        final dSq = d.dx * d.dx + d.dy * d.dy;
        if (dSq >= minSq && dSq < bestSq) {
          bestSq = dSq;
          best = i;
        }
        if (dSq < nearSq) {
          nearSq = dSq;
          near = i;
        }
      }
      final pick = best >= 0 ? best : near;
      if (pick < 0) continue;
      aims[k] = bodies[pick];
      taken.add(pick);
    }
    for (var k = 0; k < count; k++) {
      if (aims[k] != null) continue;
      var pick = -1;
      var pickSq = -1.0;
      for (var i = 0; i < bodies.length; i++) {
        if (taken.contains(i)) continue;
        var nearestSq = double.infinity;
        for (final aim in aims) {
          if (aim == null) continue;
          final d = bodies[i] - aim;
          nearestSq = min(nearestSq, d.dx * d.dx + d.dy * d.dy);
        }
        if (nearestSq > pickSq) {
          pickSq = nearestSq;
          pick = i;
        }
      }
      if (pick >= 0 && pickSq >= spacingSq) {
        aims[k] = bodies[pick];
        taken.add(pick);
      } else {
        final mid = startAngle + (k + 0.5) * slice;
        aims[k] =
            centre +
            Offset(cos(mid), sin(mid)) * max(fallbackDistance, minDistance);
      }
    }
    return [for (final aim in aims) aim!];
  }

  /// How far past its crater a Let's contact and kill effects reach, as a
  /// multiple of the crater ([letRimReach]).
  ///
  /// The crater kills what it lands on, so an effect that acted only inside
  /// it — Ice's freeze, Spirit's execute, Lightning's chain, Water's splash,
  /// the Earth and Crystal sweeps, Blood's drain, Air's shove once the crater
  /// outgrew it — fell on bodies already dead (2026-10-20 audit). They act
  /// out to here now: the crater's survivors and the ring just outside it.
  static const double kLetRimReach = 1.3;

  /// [kLetRimReach] of [meteor]'s crater.
  static double letRimReach(Projectile meteor) =>
      letSkyfallBlastRadius(meteor) * kLetRimReach;

  /// A follow-up lands this much bigger than the meteor that called it down.
  /// The board says twice as big; at twice, five of them covered the wave
  /// around every kill and Dark measured up to 4.5x the median special.
  static const double kDarkLetFollowupScale = 1.4;

  /// A follow-up's hit radius, from the meteor that called it down.
  static double darkLetFollowupRadius(Projectile source) =>
      max(3.5, source.radiusMultiplier * kDarkLetFollowupScale);

  /// A follow-up's drawn size: the same growth, so it looks as big as it hits.
  static double darkLetFollowupVisualScale(Projectile source) =>
      max(3.5, source.visualScale * kDarkLetFollowupScale);

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
      // The shot is the caster's: credited to it, and filed as its special
      // rather than as an anonymous auto attack (a Mask Steam geyser's shots
      // were missing from its caster's damage, and fed a Blood world's tithe).
      sourceSlotIndex: orb.sourceSlotIndex,
      abilityFamily: orb.abilityFamily,
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

  /// How fast a Mask Dark hole draws in a body [distance] from it, in px/s,
  /// for a hole whose suction reaches [radius]: [voidPullRimSpeed] at the
  /// edge, rising to [voidPullCoreSpeed] at the mouth.
  ///
  /// The board: "the hole's suction radius scales with stats". The pull was
  /// a step of min(16, 340 / distance) a tick, a few px/s across most of the
  /// radius, so a body walking past at 50-90 px/s never noticed it and the
  /// radius the stats paid for was dead; only bodies that walked into the
  /// mouth were thrown out (2026-10-20 audit). The rim speed is a little
  /// under a horde wisp's walk, so a body crossing the edge is bent in, and
  /// one inside half the radius cannot walk out.
  static double voidPullSpeed(double distance, double radius) {
    final t = radius > 0 ? (1.0 - distance / radius).clamp(0.0, 1.0) : 0.0;
    return voidPullRimSpeed + (voidPullCoreSpeed - voidPullRimSpeed) * t;
  }

  static const double voidPullRimSpeed = 70.0;
  static const double voidPullCoreSpeed = 230.0;

  /// The knockback impulse that carries a body [voidPullSpeed] for one zone
  /// tick of [tick] seconds as the shove dies away ([knockbackDamping]), so
  /// the hole pulls smoothly between its ticks instead of teleporting bodies
  /// a step at a time.
  static double voidPullImpulse(
    double distance,
    double radius, {
    double tick = 0.35,
  }) {
    final carried = (1.0 - exp(-knockbackDamping * tick)) / knockbackDamping;
    return voidPullSpeed(distance, radius) * tick / carried;
  }

  /// The shove a Mask Air pad gives the body that touches it, from its
  /// power (360 authored, × the caster's impact scale).
  ///
  /// It went through [knockbackImpulse], whose 520 ceiling a power of 360
  /// passes forty times over, so every pad shoved the same whatever its
  /// caster (2026-10-20 audit). This keeps the authored pad at about the old
  /// 520 and lets a stronger caster's pads throw up to [maskAirImpulseCeiling]
  /// (about 100 px against 70).
  static double maskAirImpulse(double power) =>
      (power * 1.45).clamp(300.0, maskAirImpulseCeiling).toDouble();

  static const double maskAirImpulseCeiling = 760.0;
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

  /// A beam a Wing co-fires from an anchor (Earth's from the orb, Spirit's
  /// from the ship) holds for this share of the wing's own beam. A second
  /// full-length line doubled the cast, and Earth measured 2.7-3.7x the
  /// median special (ability pass, final balance, 2026-10-10).
  static const double coBeamLifeShare = 0.5;

  /// How long a co-fired beam of [d] holds.
  static double coBeamLife(WingBeamEffect d) => d.duration * coBeamLifeShare;

  /// How far from a line beam's segment a body is struck, before its own
  /// radius. Also the reach a boss is tested at.
  static double hitRadius(WingBeamEffect d) => max(10.0, d.width * 1.45);

  /// The radius a line beam hands its tick effect.
  static double lineEffectRadius(WingBeamEffect d) => hitRadius(d) * 6;

  /// A line beam's hit on one body: Blood's execute below its threshold,
  /// Lightning's charged multiplier, otherwise the tick — each at [heat] of
  /// its strength ([heatAt] for the body the beam is held on, [lineShare] for
  /// one it only crosses). An execute still kills whatever the heat.
  static double tickDamage(
    WingBeamEffect d, {
    required double hp,
    required double hpFraction,
    double heat = 1.0,
  }) {
    final tick = d.damagePerTick * heat;
    if (d.executeThreshold > 0 && hpFraction <= d.executeThreshold) {
      return max(tick, hp + 1);
    }
    if (d.tickEffect == AbilityEffectKind.chargeBlast) {
      return CosmicAbilityRuntime.directDamageForEffect(
        d.tickEffect,
        power: tick,
        targetHp: hp,
        targetHpFraction: hpFraction,
      );
    }
    return tick;
  }

  // ── Focus ──
  // "maybe wings have really low damage but the longer they are in a target
  // it gets stronger" (the user, 2026-10-20, for every Wing). A line beam
  // starts cold and heats while it stays on one body: its tick on that body
  // climbs from [heatFloor] to [heatPeak] of the authored tick over
  // [heatRampSeconds] of contact, and falls back to the floor the moment the
  // beam's target changes or dies. A P80 beam held on one body the whole way
  // (the PvP battle's case) deals 0.84 of the old flat tick over its twelve
  // ticks; one jumping from body to body in a horde stays cold, and the line
  // it runs on past its body (see [sweeps]) only chips what it crosses. The
  // user's sketch was 0.25 to 1.4; against the family probe
  // (family_balance_survival_test) that left a P20 Wing a point under its
  // band, so the floor came up a little and the peak down to keep the held
  // beam at 0.84 (wing_focus_test), 2026-10-20.

  /// The tick on a body the beam has only just reached, as a share of the
  /// authored tick.
  static const double heatFloor = 0.3;

  /// The tick on a body held for [heatRampSeconds] or longer.
  static const double heatPeak = 1.35;

  /// Seconds of contact from [heatFloor] to [heatPeak].
  static const double heatRampSeconds = 2.0;

  /// What a body takes that the beam only crosses on its way to the one it
  /// is held on: the unheated tick.
  static const double lineShare = heatFloor;

  /// The share of the authored tick a body takes after [held] seconds under
  /// the beam: a straight climb from the floor to the peak.
  static double heatAt(double held) =>
      heatFloor +
      (heatPeak - heatFloor) * (held / heatRampSeconds).clamp(0.0, 1.0);

  /// How hot a beam reads, 0 (just landed) to 1 (white-hot), for the art.
  static double heatGlow(double heat) =>
      ((heat - heatFloor) / (heatPeak - heatFloor)).clamp(0.0, 1.0);

  /// Whether [d] heats. Every line beam does; the Fire and Poison rings burn
  /// round the Wing at their authored strength, and Lightning's charged
  /// blast is one hit, so neither has anything to hold.
  static bool heats(WingBeamEffect d) =>
      d.targetPolicy != WingBeamTargetPolicy.ring && d.chargeTime <= 0;

  /// Whether [d] runs on through the body it aims at to its full range, so
  /// the line cuts through the crowd behind it. The beams that aim at the
  /// nearest body do; Blood's ends on the body it has locked, Water's on its
  /// ally, and the rings have no line.
  static bool sweeps(WingBeamEffect d) =>
      d.targetPolicy == WingBeamTargetPolicy.nearestEnemy;

  /// Where a sweeping beam from [origin] aimed at [target] ends: on through
  /// it to [range]. A target on top of the origin keeps [angle].
  static Offset sweepEnd(
    Offset origin,
    Offset target,
    double range,
    double angle,
  ) {
    final dx = target.dx - origin.dx;
    final dy = target.dy - origin.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.5) {
      return origin + Offset(cos(angle), sin(angle)) * range;
    }
    final reach = max(range, dist);
    return Offset(origin.dx + dx / dist * reach, origin.dy + dy / dist * reach);
  }

  /// Whether a beam's rider [effect] scales with the hit it rides on: the
  /// ones that deal damage or heal from it (Lava's burn, Poison's, Blood's
  /// execute, Light's refraction, Steam's geyser, Crystal's lifesteal). The
  /// control riders — Air's shove, Dust's disorient, the slows, Spirit's
  /// haste — land whole on every body the beam touches.
  static bool riderScales(AbilityEffectKind effect) => switch (effect) {
    AbilityEffectKind.burn ||
    AbilityEffectKind.poison ||
    AbilityEffectKind.zoneDamage ||
    AbilityEffectKind.geyser ||
    AbilityEffectKind.execute ||
    AbilityEffectKind.refraction ||
    AbilityEffectKind.leech => true,
    _ => false,
  };

  /// A healing beam's tick heals the ship and the caster by its full heal,
  /// and survival's orb by this share of it.
  static const double orbHealShare = 0.55;

  // ── Water ──
  /// What one tick of a Water beam mends on the ally or ship it is aimed at,
  /// as a share of that one's own maximum — the board's "heals % of max HP".
  /// Beauty buys more. Over an average beam (about 2.4 s of 0.2 s ticks) that
  /// is roughly a sixth of a health bar for an average Wing. Survival's.
  static double waterHealShare(double beauty) => scaledAbilityValue(
    beauty,
    atLow: 0.010,
    atAverage: 0.014,
    atPerfect: 0.022,
  );

  // ── Ice ──
  /// Frost each tick adds; full (1.0) snaps the body into a freeze. Six
  /// ticks held — a little over a second on a bred Wing, about one and a half
  /// on a plain one — so a beam held on one body freezes it, as the board
  /// says ("if held on long enough enemies freeze").
  static const double frostPerTick = 0.17;
  static const double freezeHold = 2.6;
  static const double freezeSlow = 0.05;

  /// How long frost holds after a tick before it starts to thaw. The thaw
  /// used to run every frame, beam or no beam, and took back more than the
  /// ticks laid down, so the freeze was out of reach (2026-10-20 audit). Now
  /// a body only thaws once no beam has touched it for longer than a tick.
  static double frostGrace(WingBeamEffect d) => d.tickInterval + 0.12;

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

/// One Wing beam's heat ([WingBeamRules.heatAt]): the body it is held on and
/// how long it has been there. Every game's beam keeps one and asks it once a
/// tick, so survival, open space and the battle heat alike.
class WingBeamHeat {
  Object? _on;
  double _held = 0;
  double _last = WingBeamRules.heatFloor;

  /// The body the beam is held on, or null.
  Object? get on => _on;

  /// The heat of the beam's last tick, for the art.
  double get current => _last;

  /// The heat this tick lands at on [focus], the body the beam is aimed at
  /// (null for none). A new body, or none, starts over from the floor; the
  /// same body is held [interval] longer by the next tick.
  double tick(Object? focus, double interval) {
    if (focus == null || !identical(focus, _on)) {
      _on = focus;
      _held = 0;
    }
    _last = WingBeamRules.heatAt(_held);
    if (focus != null) _held += interval;
    return _last;
  }
}

/// What one contact did to a Pip special dart ([PipRicochet.settle]).
enum PipDartStep {
  /// It killed, and carries what the body did not need on to the next one.
  carry,

  /// The body survived: a bounce is spent and the dart turns to the next.
  bounce,

  /// The body survived and the dart, out of bounces, passes through it.
  pierce,

  /// The dart is done.
  spent,
}

/// Pip's ricochet, one rule for every mode: survival, open space (and the
/// battle, which runs on it) and the dungeons.
///
/// Pip is the late bloomer (the 2026-10-20 rebuild, user-approved: weak
/// early, threading crowds late). A special dart that kills keeps the damage
/// the body did not need and carries it to its next body: the kill spends no
/// bounce and sheds nothing. A body that survives the hit costs a bounce and
/// the falloff, as the ricochet always has; a piercing dart out of bounces
/// passes through [kPipMaxPierceHits] survivors before the next one stops it;
/// and a boss is always a survivor, so a dart that reaches one bounces on
/// instead of being spent on it. A dart strikes no body twice.
///
/// At Potential 20 a dart barely kills what it hits, so little carries; a
/// bred one threads a crowd. Every element's own hit and kill effect still
/// lands on each body the dart touches.
abstract final class PipRicochet {
  /// Most bodies one dart may touch: the bound on its cost in a dense horde.
  static const int maxContacts = 24;

  /// How far from the body it struck a dart looks for the next one.
  static const double nextReach = 110;

  /// A dart lays its element's kill piece (Fire's pool, Dust's cloud,
  /// Crystal's beacon) on its first kill and every this many kills after,
  /// not on every body of a long thread: the pieces share the capped
  /// projectile list with every other placement in the game.
  static const int killsPerPiece = 4;

  /// Carried damage below this is nothing left to carry.
  static const double minCarry = 1.0;

  static bool isSpecialDart(Projectile p) =>
      p.abilityFamily == 'pip' &&
      p.visualStyle == ProjectileVisualStyle.dart &&
      !p.stationary;

  /// The damage a dart keeps through a body that survives it. Lightning is
  /// the board's "double the ricochet" and sheds less.
  static double falloff(Projectile p) =>
      p.element == 'Lightning' ? 0.85 : 0.70;

  /// The share of a killing hit the body did not need: its overkill over
  /// the damage the hit dealt, from its health before and after.
  static double carriedShare(double hpBefore, double hpAfter) {
    if (hpAfter >= 0 || hpBefore <= 0) return 0;
    final dealt = hpBefore - hpAfter;
    return dealt > 0 ? (-hpAfter / dealt).clamp(0.0, 1.0) : 0;
  }

  /// Whether the kill [p] is about to make lays its element's piece.
  static bool laysPiece(Projectile p) => p.pipKills % killsPerPiece == 0;

  /// Whether the kill [p] is about to make pays its kill effect. Every one
  /// does but Earth's cooldown refund, which only a dart's first kill pays:
  /// a dart used to make one kill and stop, and on a twenty-body thread the
  /// refund on every body had the special ready again as it went off.
  static bool paysKillEffect(Projectile p) =>
      p.killEffect != AbilityEffectKind.cooldownRefund ||
      !isSpecialDart(p) ||
      p.pipKills == 0;

  /// Settles one contact: [killed] with [carried] of the hit left over
  /// ([carriedShare]), or a body (a boss always) that survived.
  static PipDartStep settle(
    Projectile p, {
    required bool killed,
    double carried = 0,
  }) {
    p.pipContacts++;
    final full = p.pipContacts >= maxContacts;
    if (killed) {
      p.pipKills++;
      p.damage *= carried;
      return full || p.damage < minCarry ? PipDartStep.spent : PipDartStep.carry;
    }
    final PipDartStep step;
    if (p.bounceCount > 0) {
      p.bounceCount--;
      step = PipDartStep.bounce;
    } else if (p.piercing && p.pierceCount < kPipMaxPierceHits) {
      p.pierceCount++;
      step = PipDartStep.pierce;
    } else {
      return PipDartStep.spent;
    }
    if (full) return PipDartStep.spent;
    p.damage *= falloff(p);
    // Slight speed bleed so chained shots feel weighty.
    p.speedMultiplier = max(0.6, p.speedMultiplier * 0.92);
    return step;
  }

  /// Sends a dart that lives on after a contact toward [next], or on along
  /// its heading for its homing to find a body it has not struck when there
  /// is none. Either way it has [kPipRicochetPostHitLife] to reach it.
  static void turn(Projectile p, Offset? next) {
    if (next != null) {
      p.angle = atan2(next.dy - p.position.dy, next.dx - p.position.dx);
    }
    // The homing cache still held the body just struck, so a homing dart
    // curled back toward it after every bounce.
    p.cachedHomingTarget = next;
    p.homingRescanTimer = next == null ? 0 : 0.15;
    p.life = min(max(p.life, 0.18), kPipRicochetPostHitLife);
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
