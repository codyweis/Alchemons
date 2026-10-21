import 'dart:math';
import 'dart:ui';

import 'cosmic_data.dart';

/// Repositions an authored cast without changing its count, power or lifetime.
/// Allies arrive in healing-priority order. Dust attaches through its own
/// runtime and does not use ground placement.
///
/// Survival's placement, shared so every mode lays the same field. A mode
/// without an arena passes a centre and radius that never clamp.
///
/// [guard] is the one thing the field stands in front of. Survival passes its
/// orb, with [target] on the orb's busiest approach ([MaskApproachLane]), so
/// the field is centred across that lane. Without one the field reaches from
/// [target] toward the nearest defended body, which can be the caster itself.
void placeMaskTraps({
  required List<Projectile> traps,
  required Offset caster,
  required Offset ship,
  required List<Offset> allies,
  required Offset target,
  required Offset arenaCenter,
  required double arenaRadius,
  Offset? guard,
}) {
  if (traps.isEmpty || traps.first.abilityFamily != 'mask') return;
  final element = traps.first.element;
  if (element == 'Dust') return;

  double footprint(Projectile p) => max(
    max(p.effectRadius, p.snareRadius),
    Projectile.radius * p.radiusMultiplier,
  );
  final margin = traps.map(footprint).reduce(max) + 12;
  Offset inside(Offset position, [double extra = 0]) {
    final limit = max(0.0, arenaRadius - margin - extra);
    final delta = position - arenaCenter;
    return delta.distance <= limit || delta.distance == 0
        ? position
        : arenaCenter + delta / delta.distance * limit;
  }

  if (element == 'Earth') {
    // Cover injured allies first, without spending every pool on a cluster
    // that a single pool can already heal. Spare pools make nearby refuges.
    final centers = <Offset>[];
    final radius = max(24.0, traps.first.effectRadius);
    for (final ally in allies.isEmpty ? [ship, caster] : allies) {
      final candidate = inside(ally);
      if (centers.any((p) => (candidate - p).distance < radius * 0.8)) continue;
      centers.add(candidate);
      if (centers.length == traps.length) break;
    }
    final refugeCenter = inside(ship, radius * 0.85);
    for (var i = 0; i < traps.length; i++) {
      if (i < centers.length) {
        traps[i].position = centers[i];
      } else {
        final angle = (i - centers.length) * 2.399963229728653;
        traps[i].position = inside(
          refugeCenter + Offset(cos(angle), sin(angle)) * radius * 0.85,
        );
      }
    }
    return;
  }

  if (element == 'Ice') {
    final positions = allies.isEmpty ? [ship, caster] : allies;
    final candidates = <Offset>[...positions];
    for (var i = 0; i < positions.length; i++) {
      for (var j = i + 1; j < positions.length; j++) {
        candidates.add((positions[i] + positions[j]) / 2);
      }
    }
    final radius = traps.first.effectRadius;
    var best = inside(caster);
    var bestScore = -1.0;
    for (final candidate in candidates.map(inside)) {
      final covered = positions
          .where((p) => (p - candidate).distance <= radius)
          .length;
      // Prefer covering the ship when two locations cover the same number.
      final score =
          covered + ((ship - candidate).distance <= radius ? 0.25 : 0.0);
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }
    for (final p in traps) {
      p.position = best;
    }
    return;
  }

  if (element == 'Spirit') {
    // A short collection route around the ship, within the pickup magnet's
    // reach. Keep the whole ring inside instead of flattening it at the wall.
    const reach = 130.0;
    final center = inside(ship, reach);
    for (var i = 0; i < traps.length; i++) {
      final angle = i * pi * 2 / traps.length;
      final radius = 85.0 + (i.isEven ? 0 : 45);
      traps[i].position = center + Offset(cos(angle), sin(angle)) * radius;
    }
    return;
  }

  final aim = inside(target);
  if (traps.length == 1) {
    traps.single.position = aim;
    return;
  }

  // One trap always covers the selected spot. The rest form a compact field
  // on its approach toward what it guards: the [guard], or else the nearest
  // defended body. Count increases density; it does not multiply the scatter
  // radius and waste upgraded casts.
  final Offset toward;
  if (guard != null) {
    toward = guard;
  } else {
    final defended = [ship, ...allies, arenaCenter]
      ..sort(
        (a, b) =>
            (a - aim).distanceSquared.compareTo((b - aim).distanceSquared),
      );
    toward = defended.first;
  }
  final delta = toward - aim;
  final direction = delta.distance > 0.01
      ? delta / delta.distance
      : const Offset(1, 0);
  final side = Offset(-direction.dy, direction.dx);
  final spread = (80.0 + footprint(traps.first) * 0.45).clamp(90.0, 155.0);
  // A guarded field is centred on its spot, so it sits across the lane
  // rather than reaching from it into the orb.
  final center = guard != null
      ? inside(aim, spread)
      : inside(aim + direction * (spread * 0.65), spread);
  traps.first.position = aim;
  for (var i = 1; i < traps.length; i++) {
    final fraction = (i - 0.5) / (traps.length - 1);
    final angle = i * 2.399963229728653;
    final radius = sqrt(fraction) * spread;
    traps[i].position =
        center +
        direction * (cos(angle) * radius) +
        side * (sin(angle) * radius * 0.75);
  }
}

/// How near the orb a Mask field on its approach may be centred.
const double kMaskApproachNear = 380.0;

/// And how far: with the field's own spread (at most 155 px) the traps lie
/// about 300-650 px out, in front of the inner ring and behind the rim.
const double kMaskApproachFar = 570.0;

/// The bodies within this of the orb make up its approaches.
const double kMaskApproachScan = 1100.0;

/// Finds the orb's busiest approach, for a Mask field to stand across.
///
/// User-approved spec (2026-10-20), "Mask — gatekeeper": traps went down at
/// the Mask's own target and reached toward the nearest defended body, which
/// was usually the Mask itself, so they sat in the middle ring in front of
/// the Mask, on bodies Wing and Mane were already shooting, and never on the
/// orb's approach. Now the bodies round the orb are counted into
/// [sectors] bearings, a body nearer the orb counting up to twice; the
/// busiest bearing (with half of each neighbour, so a lane split between two
/// bearings is still one lane) is the lane, and the field is centred on it
/// between [kMaskApproachNear] and [kMaskApproachFar] from the orb — a little
/// over halfway out to where that lane's bodies stand on average.
///
/// One per game, reset each cast; adding a body allocates nothing.
class MaskApproachLane {
  MaskApproachLane({this.sectors = 16})
    : _weight = List<double>.filled(sectors, 0),
      _sumX = List<double>.filled(sectors, 0),
      _sumY = List<double>.filled(sectors, 0),
      _sumR = List<double>.filled(sectors, 0);

  final int sectors;
  final List<double> _weight;
  final List<double> _sumX;
  final List<double> _sumY;
  final List<double> _sumR;

  void reset() {
    for (var i = 0; i < sectors; i++) {
      _weight[i] = 0;
      _sumX[i] = 0;
      _sumY[i] = 0;
      _sumR[i] = 0;
    }
  }

  /// A body at [fromOrb] from the orb; a boss passes a heavier [weight].
  void add(Offset fromOrb, {double weight = 1.0}) {
    final r = fromOrb.distance;
    if (r < 60 || r > kMaskApproachScan) return;
    final w = weight * (2.0 - r / kMaskApproachScan);
    final bearing = atan2(fromOrb.dy, fromOrb.dx);
    final s = ((bearing + pi) / (2 * pi) * sectors).floor() % sectors;
    _weight[s] += w;
    _sumX[s] += fromOrb.dx / r * w;
    _sumY[s] += fromOrb.dy / r * w;
    _sumR[s] += r * w;
  }

  /// The spot on the busiest approach round [orb], or null with nobody near.
  Offset? aim(Offset orb) {
    var best = -1;
    var bestScore = 0.0;
    for (var s = 0; s < sectors; s++) {
      final score =
          _weight[s] +
          0.5 *
              (_weight[(s + sectors - 1) % sectors] +
                  _weight[(s + 1) % sectors]);
      if (_weight[s] > 0 && score > bestScore) {
        bestScore = score;
        best = s;
      }
    }
    if (best < 0) return null;
    final dir = Offset(_sumX[best], _sumY[best]);
    final len = dir.distance;
    if (len <= 1e-6) return null;
    final meanR = _sumR[best] / _weight[best];
    final reach = (meanR * 0.6).clamp(kMaskApproachNear, kMaskApproachFar);
    return orb + dir / len * reach;
  }
}

/// The spot a Mask field guarding [orb] goes when the approach is empty:
/// toward [target], at the approach's distance.
Offset maskApproachFallback(Offset orb, Offset target) {
  final delta = target - orb;
  final d = delta.distance;
  final dir = d > 1 ? delta / d : const Offset(1, 0);
  return orb +
      dir * d.clamp(kMaskApproachNear, kMaskApproachFar).toDouble();
}

// ─────────────────────────────────────────────────────────────────────────────
//  What a Mask trap leaves or becomes once it is on the field
//
//  Survival's numbers, held here so every mode that runs Mask traps spawns
//  the same pieces from them: the shards a crystal breaks into, the pool a
//  fire ball leaves, the dust shield on each ally, how the Plant vine grows,
//  and the Spirit wisps the ship collects. The modes differ only in who their
//  allies are and where their pools live.
// ─────────────────────────────────────────────────────────────────────────────

/// Three smaller crystals round [at], turned by [baseAngle]. Each strikes
/// once and splashes its neighbours; none of them breaks again.
List<Projectile> maskCrystalShards(
  Projectile parent,
  Offset at,
  double baseAngle,
) => [
  for (var i = 0; i < 3; i++)
    Projectile(
      position: Offset(
        at.dx + cos(baseAngle + i * (pi * 2 / 3)) * 18.0,
        at.dy + sin(baseAngle + i * (pi * 2 / 3)) * 18.0,
      ),
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
];

/// The burning pool a fire ball leaves where it struck.
Projectile maskFirePool(Projectile parent, Offset at) => Projectile(
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
);

/// A dust shield riding [attachedToSlot] (-1 is the ship): it grinds what
/// touches it and stops five shots.
Projectile maskDustShield(
  Projectile seed, {
  required int? sourceSlotIndex,
  required int attachedToSlot,
  required Offset position,
}) => Projectile(
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
  sourceSlotIndex: sourceSlotIndex,
  attachedToSlot: attachedToSlot,
  abilityFamily: 'mask',
  tickEffect: AbilityEffectKind.zoneDamage,
  effectPower: max(seed.effectPower, 1.0),
  effectRadius: max(72.0, seed.effectRadius),
  effectDuration: seed.effectDuration,
  interceptRadius: max(72.0, seed.effectRadius),
  interceptCharges: 5,
);

/// A recast on a host already shielded tops the shield up rather than
/// stacking a second one, and it flares as it does.
void refreshMaskDustShield(Projectile shield, Projectile seed) {
  shield.life = max(shield.life, seed.life);
  shield.interceptCharges = max(shield.interceptCharges, 5);
  shield.abilityGrowthTimer = max(shield.abilityGrowthTimer, 0.8);
}

/// Casts it takes to grow the Plant vine to its full size.
const int kMaskPlantMaxFeeds = 100;

/// A new tendril sprouts every tenth feed.
bool maskPlantFeedSproutsTendril(int prevFeeds, int feeds) =>
    (feeds ~/ 10) != (prevFeeds ~/ 10);

/// Grows the vine to its size after [feeds] casts: a wider snare that holds
/// harder, a longer reach and a stronger bite.
void applyMaskPlantVineFeed(Projectile vine, int feeds) {
  // Linear grow from initial → max over kMaskPlantMaxFeeds casts.
  final t = (feeds / kMaskPlantMaxFeeds).clamp(0.0, 1.0);
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
  vine.maskBasePower ??= max(1.0, vine.effectPower);
  vine.effectPower = vine.maskBasePower! * (1 + 5 * t);
}

/// What a Blood-marked body bleeds each second until it dies...
double maskBloodDrainPerSecond(double maxHealth) => max(2.0, maxHealth * 0.06);

/// ...and the share of it that comes back to the party as healing.
const double kMaskBloodHealShare = 0.35;

/// A Spirit wisp left on the field for the ship to collect. It is not a
/// projectile: nothing collides with it, and only the collector takes it.
class MaskSpiritWisp {
  MaskSpiritWisp({
    required this.position,
    required this.sourceSlotIndex,
    required this.damage,
    required this.bobPhase,
    required this.life,
    this.clearAt = 1,
  });

  /// One wisp for a Spirit placement that scattered [castSize] of them.
  factory MaskSpiritWisp.fromTrap(
    Projectile trap, {
    required int? sourceSlotIndex,
    required double bobPhase,
    required int castSize,
  }) => MaskSpiritWisp(
    position: trap.position,
    sourceSlotIndex: sourceSlotIndex,
    damage: trap.effectPower,
    bobPhase: bobPhase,
    life: max(8.0, trap.life),
    clearAt: maskSpiritClearThreshold(castSize),
  );

  Offset position;
  double life;
  final int? sourceSlotIndex;
  final double damage;
  final double bobPhase;

  /// How many banked wisps set off the clear when this one is taken: its
  /// cast's [maskSpiritClearThreshold].
  final int clearAt;
  bool get dead => life <= 0;
}

/// Wisps a field holds at most.
const int kMaskSpiritWispCap = 120;

/// How many banked wisps set off a clear: a cast and a half of an average
/// caster's eight.
///
/// It was a flat six wisps, under the eight a single average cast scatters,
/// so every cast cleared the field on its own and Spirit measured 5.5-7x the
/// median special at every band, with nothing building. Banking across casts
/// is the ability's ramp ("faster progressed": it grows inside a run) — the
/// first cast of a deployment only fills the bank (ability pass, final
/// balance, 2026-10-10).
///
/// That pass then counted the clear in casts (1.5 × the cast's own wisps),
/// which made the count the board scales by stats cosmetic: four wisps or
/// fourteen, a clear every cast and a half (2026-10-20 audit). Counted in
/// wisps, the count is the ramp's speed: a weak caster's six take two casts,
/// an average eight a cast and a half, ten at Potential 80 a cast and a
/// fifth, and a perfect fourteen clear every cast — never more often, since
/// a clear never needs fewer wisps than one cast throws.
const int kMaskSpiritClearWisps = 12;

/// Wisps banked by one caster that set off its clear, for a cast that
/// scattered [castSize] of them.
int maskSpiritClearThreshold(int castSize) =>
    max(kMaskSpiritClearWisps, castSize);

const double kMaskSpiritCollectRadius = 56.0;
const double kMaskSpiritMagnetRadius = 200.0;
const double kMaskSpiritMagnetSpeed = 360.0;

/// Ages the wisps and lets [collector] take the ones it reaches, calling
/// [onCollect] for each; nearby wisps swoop in to meet it. With no collector
/// (the ship is down) they only age.
void stepMaskSpiritWisps(
  List<MaskSpiritWisp> wisps,
  Offset? collector,
  double dt,
  void Function(MaskSpiritWisp wisp) onCollect,
) {
  if (wisps.isEmpty) return;
  if (collector == null) {
    for (final wisp in wisps) {
      wisp.life -= dt;
    }
    wisps.removeWhere((w) => w.dead);
    return;
  }
  // Same magnet/collect feel as Plant flowers — generous radius +
  // proximity pull so wisps swoop in instead of requiring a precise
  // pickup.
  for (final wisp in wisps) {
    wisp.life -= dt;
    if (wisp.dead) continue;
    final dx = collector.dx - wisp.position.dx;
    final dy = collector.dy - wisp.position.dy;
    final distSq = dx * dx + dy * dy;
    if (distSq <= kMaskSpiritCollectRadius * kMaskSpiritCollectRadius) {
      wisp.life = 0;
      onCollect(wisp);
      continue;
    }
    if (distSq <= kMaskSpiritMagnetRadius * kMaskSpiritMagnetRadius) {
      final dist = sqrt(distSq);
      final norm = Offset(dx / dist, dy / dist);
      final t = 1.0 - (dist / kMaskSpiritMagnetRadius);
      final speed = kMaskSpiritMagnetSpeed * t * t;
      wisp.position = Offset(
        wisp.position.dx + norm.dx * speed * dt,
        wisp.position.dy + norm.dy * speed * dt,
      );
    }
  }
  wisps.removeWhere((w) => w.dead);
}
