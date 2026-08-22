// lib/games/shared/enemy_action.dart
//
// What an enemy DOES, as a four-phase performance.
//
// Enemies previously had cooldowns, not actions: a shooter fired the instant
// its cooldown expired and everything else damaged you by touching you. Nothing
// took time, so nothing showed intent — which is why they read as moving
// obstacles rather than creatures.
//
//   idle → windUp → commit → recover
//
// Wind-up is where the creature lives: it stops, something charges, and you are
// told what is coming. Commit is the payoff. Recover is a vulnerable window
// that pays you for reading the wind-up. That is a fairness property as much as
// an aesthetic one — before this, nothing an enemy did could be dodged by
// reading it.
//
// Body decides the action, because body is the axis that answers "how do I
// fight this thing" (conduct owns movement, trait owns extras).

import 'package:alchemons/games/cosmic/cosmic_data.dart';

enum EnemyActionPhase { idle, windUp, commit, recover }

/// The signature move for a body.
class EnemyActionDef {
  const EnemyActionDef({
    required this.windUp,
    required this.commit,
    required this.recover,
    required this.range,
    required this.cooldown,
    this.freezesDuringWindUp = true,
    this.freezesDuringCommit = true,
  });

  /// Telegraph length. Longer = more readable, more dodgeable.
  final double windUp;

  /// How long the payoff lasts.
  final double commit;

  /// The vulnerable window afterwards.
  final double recover;

  /// Distance to target within which the action may start.
  final double range;

  /// Idle seconds between actions.
  final double cooldown;

  final bool freezesDuringWindUp;
  final bool freezesDuringCommit;

  double get total => windUp + commit + recover;
}

/// No two bodies share a performance — this is what makes six bodies feel like
/// six creatures rather than six health bars.
///
/// Wisps are deliberately absent: they are swarm chaff and fight by contact.
/// Giving thirty of them a telegraphed attack would be unreadable noise.
const Map<EnemyTier, EnemyActionDef> kEnemyActions = {
  // Quick, twitchy, punished hard if you sidestep it.
  EnemyTier.drone: EnemyActionDef(
    windUp: 0.35,
    commit: 0.28,
    recover: 0.75,
    range: 260,
    cooldown: 2.6,
    freezesDuringCommit: false, // the dash IS the commit
  ),

  // Satellites gather inward, then fan outward.
  EnemyTier.sentinel: EnemyActionDef(
    windUp: 0.75,
    commit: 0.2,
    recover: 0.6,
    range: 420,
    cooldown: 3.4,
  ),

  // Blinks out and reappears behind you; solid and exposed on recover.
  EnemyTier.phantom: EnemyActionDef(
    windUp: 0.6,
    commit: 0.15,
    recover: 0.9,
    range: 380,
    cooldown: 4.2,
  ),

  // The siege beam: plates open, the core charges, then it fires.
  EnemyTier.brute: EnemyActionDef(
    windUp: 1.15,
    commit: 0.55,
    recover: 1.1,
    range: 560,
    cooldown: 5.0,
  ),

  // Slow, enormous, unmissable — and it tells you well in advance.
  EnemyTier.colossus: EnemyActionDef(
    windUp: 1.6,
    commit: 0.35,
    recover: 1.4,
    range: 300,
    cooldown: 6.5,
  ),
};

/// Per-enemy action state. Cheap: one enum, one timer, one flag.
class EnemyActionState {
  EnemyActionPhase phase = EnemyActionPhase.idle;

  /// Seconds remaining in the current phase.
  double timer = 0;

  /// Set when the commit effect has been fired, so it happens exactly once.
  bool fired = false;

  /// Facing locked at wind-up start, so the attack goes where it was
  /// telegraphed rather than tracking you through the commit.
  double aimAngle = 0;

  /// 0 → 1 through the current phase, for telegraph rendering.
  double progress(double phaseLength) =>
      phaseLength <= 0 ? 1.0 : (1.0 - (timer / phaseLength)).clamp(0.0, 1.0);

  bool get isBusy => phase != EnemyActionPhase.idle;

  /// Recover is the punish window — hosts can use this for bonus damage.
  bool get isExposed => phase == EnemyActionPhase.recover;
}
