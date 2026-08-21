// lib/games/shared/enemy_movement.dart
//
// The enemy movement vector, as one pure function.
//
// This used to be inline in the survival update loop: the role picked a vector
// and the next four lines threw it away if the variant was crusher or pouncer.
// Two axes fighting over one output, with no way to test either.
//
// Extracted verbatim first so the behaviour could be pinned by tests, ahead of
// the taxonomy change that replaces role+variant with a single conduct. See
// docs/enemy_taxonomy.md §2.2.

import 'dart:ui';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';

/// Where an enemy wants to move this frame, as a direction (not normalised —
/// callers scale by speed and dt).
///
/// [norm] points at the target, [tangent] is perpendicular to it, and [dist]
/// is the distance to the target.
///
/// NOTE the precedence: variant overrides role. That is the existing
/// behaviour, preserved deliberately so the extraction is a no-op. It is also
/// the thing the taxonomy work removes.
Offset enemyMoveVector({
  required CosmicEnemyRole role,
  required SurvivalEnemyVariant variant,
  required double dist,
  required Offset norm,
  required Offset tangent,
}) {
  final base = switch (role) {
    CosmicEnemyRole.striker => norm,
    CosmicEnemyRole.hunter => norm,
    CosmicEnemyRole.orbiter => (norm * 0.55 + tangent * 0.85),
    CosmicEnemyRole.shooter => dist > 240 ? norm : tangent * 0.8,
  };
  return switch (variant) {
    SurvivalEnemyVariant.crusher => norm * 1.08,
    SurvivalEnemyVariant.pouncer =>
      dist > 140 ? (norm * 1.15 + tangent * 0.12) : norm,
    _ => base,
  };
}

/// Movement under the converged taxonomy: conduct alone decides.
///
/// Trait is deliberately absent — a trait adds a mechanic, it does not steer.
/// That separation is the whole point of the change: under the old scheme a
/// `crusher` silently discarded whatever its role wanted.
Offset conductMoveVector({
  required EnemyConduct conduct,
  required double dist,
  required Offset norm,
  required Offset tangent,
}) => switch (conduct) {
  EnemyConduct.charge => norm,

  // Stalk takes the OLD POUNCER vector, not the old hunter one. Hunter and
  // striker produced an identical vector (docs §2.2) — keeping that would
  // carry the redundancy into the new taxonomy for nothing. The pouncer's
  // hold-then-lunge is what "stalking" already meant everywhere else in the
  // design, so it becomes the definition.
  //
  // This IS a behaviour change: enemies that were hunters now hold at range
  // and lunge instead of driving straight in.
  EnemyConduct.stalk => dist > 140 ? (norm * 1.15 + tangent * 0.12) : norm,

  EnemyConduct.orbit => (norm * 0.55 + tangent * 0.85),
  EnemyConduct.standoff => dist > 240 ? norm : tangent * 0.8,

  // Open-world conducts, previously expressed only as EnemyBehavior and never
  // as a movement vector — the world systems steered them ad hoc.
  EnemyConduct.drift => Offset.zero,
  EnemyConduct.graze => dist > 320 ? norm * 0.35 : Offset.zero,
  EnemyConduct.patrol => dist > 260 ? Offset.zero : norm * 0.9,
  EnemyConduct.swarm => norm * 0.92 + tangent * 0.25,
};

/// Old role + variant → new conduct.
///
/// `crusher` and `pouncer` map to a conduct rather than a trait because that
/// is what they always were: a body that charges, and a body that stalks and
/// darts. Their squash/stretch survives on the visual side.
///
/// One thing is deliberately NOT carried over: the crusher's `* 1.08` speed
/// bonus. That was a stat wearing a steering rule's clothes — a crusher is
/// faster, which belongs in `effectiveSpeed`, not in the direction vector.
/// See [conductSpeedMultiplier].
EnemyConduct conductFromRoleVariant(
  CosmicEnemyRole role,
  SurvivalEnemyVariant variant,
) {
  if (variant == SurvivalEnemyVariant.crusher) return EnemyConduct.charge;
  if (variant == SurvivalEnemyVariant.pouncer) return EnemyConduct.stalk;
  return switch (role) {
    CosmicEnemyRole.striker => EnemyConduct.charge,
    CosmicEnemyRole.hunter => EnemyConduct.stalk,
    CosmicEnemyRole.orbiter => EnemyConduct.orbit,
    CosmicEnemyRole.shooter => EnemyConduct.standoff,
  };
}

/// Old variant → new trait, or null when the variant carried no mechanic of
/// its own (it was a label for a body+conduct correlation).
EnemyTrait? traitFromVariant(SurvivalEnemyVariant variant) => switch (variant) {
  SurvivalEnemyVariant.summoner => EnemyTrait.summoner,
  SurvivalEnemyVariant.splitter => EnemyTrait.splitter,
  SurvivalEnemyVariant.orbBreaker => EnemyTrait.breaker,
  SurvivalEnemyVariant.standard ||
  SurvivalEnemyVariant.crusher ||
  SurvivalEnemyVariant.pouncer ||
  SurvivalEnemyVariant.siegeShooter => null,
};

/// Speed scaling that used to be smuggled into the movement vector.
///
/// The old crusher multiplied its direction by 1.08, which made it move 8%
/// faster while looking like a steering rule. Kept as an explicit stat so the
/// migration does not silently nerf heavy chargers.
double conductSpeedMultiplier(EnemyConduct conduct, {required bool heavyBody}) {
  if (conduct == EnemyConduct.charge && heavyBody) return 1.08;
  return 1.0;
}

/// Open-world behaviour → conduct. One-to-one; the two enums were the same
/// idea under different names (docs/enemy_taxonomy.md §2.1).
EnemyConduct conductFromBehavior(EnemyBehavior b) => switch (b) {
  EnemyBehavior.aggressive => EnemyConduct.charge,
  EnemyBehavior.stalking => EnemyConduct.stalk,
  EnemyBehavior.drifting => EnemyConduct.drift,
  EnemyBehavior.feeding => EnemyConduct.graze,
  EnemyBehavior.territorial => EnemyConduct.patrol,
  EnemyBehavior.swarming => EnemyConduct.swarm,
};

/// Open-world variant → conduct. `crusher`/`pouncer` mean the same here as in
/// survival, which is precisely the duplication being removed.
EnemyConduct conductFromOpenWorld(
  EnemyBehavior behavior,
  CosmicEnemyVariant variant,
) => switch (variant) {
  CosmicEnemyVariant.crusher => EnemyConduct.charge,
  CosmicEnemyVariant.pouncer => EnemyConduct.stalk,
  CosmicEnemyVariant.standard => conductFromBehavior(behavior),
};
