// lib/games/shared/enemy_taxonomy.dart
//
// The shared enemy vocabulary. See docs/enemy_taxonomy.md for the audit that
// produced it.
//
// Both modes describe an enemy with the same four axes:
//
//   BODY    EnemyTier      what it is        (already shared, in cosmic_data)
//   CONDUCT EnemyConduct   how it moves      (this file)
//   TRAIT   EnemyTrait     what extra it does(this file)
//   AFFIX   EliteAffix     rare modifier     (this file)
//
// Mode belongs in spawn policy, not in the type system: survival simply does
// not roll `graze` today because its arena has nothing to graze on. Baking
// "open world only" into an enum is what produced two parallel vocabularies in
// the first place.

/// How an enemy moves and what it wants.
///
/// The single movement authority. Nothing else may override the vector this
/// produces — the previous split (role picks a vector, variant discards it)
/// is the bug this replaces.
enum EnemyConduct {
  /// Straight at its target. Was `aggressive` / `striker`.
  charge,

  /// Trails at range and strikes on weakness. Was `stalking` / `hunter`.
  stalk,

  /// Holds a ring and strafes around it. Was `orbiter`.
  orbit,

  /// Closes to firing range, then kites. Was `shooter`.
  standoff,

  /// Aimless; harmless until provoked. Was `drifting`.
  drift,

  /// Clusters on a resource, pack-aggros when one is hit. Was `feeding`.
  graze,

  /// Guards a zone, engages on entry. Was `territorial`.
  patrol,

  /// Moves as a pack sharing a `packId`. Was `swarming`, and separately
  /// survival's `wispHorde` / `swarmRush` wave patterns.
  swarm,
}

/// An extra mechanic that is NOT implied by body + conduct.
///
/// The four dropped variants (`crusher`, `pouncer`, `siegeShooter`, plus
/// `standard`) were labels for correlations the spawner had already forced —
/// a crusher was only ever a brute/colossus that charged. These three add
/// something a body and a conduct cannot express, so they can appear on any
/// body: a summoner wisp is now expressible, and interesting.
enum EnemyTrait {
  /// Periodically spawns wisps while alive.
  summoner,

  /// Bursts into fast drones on death.
  splitter,

  /// Prioritises and heavily damages the orb / structures. Was `orbBreaker`.
  breaker,
}

/// Rare elite modifier. Orthogonal to everything above, and already the most
/// legible thing in the game — a coloured ring plus a pip bar.
///
/// Renamed off the `Survival` prefix: an elite brute in open space means
/// exactly what one in a survival wave means.
enum EliteAffix { bulwarked, volatile, vampiric, overclocked, relentless }
