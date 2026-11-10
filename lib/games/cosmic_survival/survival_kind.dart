// lib/games/cosmic_survival/survival_kind.dart
//
// What a survival body IS, as the player sees it and fights it.
//
// The spawner still rolls body, conduct and trait (enemy_taxonomy.dart); a
// kind is read off those three with no dice of its own, so a seeded wave
// sends the same bodies it always did. The kind decides the shape the body
// is drawn in (roster_art.dart) and, for the ones that do not simply walk
// into the orb, what they do instead.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';

enum SurvivalKind {
  /// A pinch of grains led by one bright one. The crowd.
  mote,

  /// One stream tube, swimming. Fast.
  strand,

  /// Three strands twisted together; comes apart into strands when killed.
  braid,

  /// An empty shell of turning bands. Slow, tough.
  husk,

  /// A gap in the dust. Blinks.
  hollow,

  /// A sphere whose grains never settle. Circles and shoots.
  spill,

  /// A dense clot with an arm of sand. Parks far out and shells the orb.
  lobber,

  /// A sealed egg. Settles well short of the orb and hatches motes until it
  /// is destroyed.
  clutch,

  /// A small body on a long tube. Latches on from a distance and draws the
  /// orb down until it is killed.
  siphon,

  /// A crescent dune. Bodies in its wake move faster.
  sower,

  /// A wide bright front. What walks in its lee takes half of every hit
  /// until the front itself is broken. The spawner makes every third husk
  /// one.
  crest,

  /// A half-open shell. It goes for one of your Alchemons, closes round it
  /// and holds it still and silent until the shell is broken or tires. The
  /// spawner makes a few spills a wave one.
  snare,

  /// An outbreak's source: a lit knot in the outbreak's colour, stream tubes
  /// writhing out of it, fewer and shorter as it is worn down.
  core,
}

/// The kind a body is. Null is kept for a body with a look of its own;
/// none has one now.
SurvivalKind? survivalKindOf({
  required EnemyTier tier,
  required EnemyConduct conduct,
  required EnemyTrait? trait,
  required bool isPlagueCore,
}) {
  if (isPlagueCore) return SurvivalKind.core;
  switch (trait) {
    case EnemyTrait.summoner:
      return SurvivalKind.clutch;
    case EnemyTrait.splitter:
      return SurvivalKind.braid;
    case EnemyTrait.breaker:
      return SurvivalKind.siphon;
    case EnemyTrait.mender:
    case null:
      break;
  }
  if (conduct == EnemyConduct.siege && trait != EnemyTrait.mender) {
    return SurvivalKind.lobber;
  }
  return switch (tier) {
    EnemyTier.wisp => SurvivalKind.mote,
    EnemyTier.drone => SurvivalKind.strand,
    EnemyTier.sentinel => SurvivalKind.spill,
    EnemyTier.phantom => SurvivalKind.hollow,
    EnemyTier.brute => SurvivalKind.husk,
    EnemyTier.colossus => SurvivalKind.sower,
  };
}
