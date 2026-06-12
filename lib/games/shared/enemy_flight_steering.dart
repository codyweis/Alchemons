// lib/games/shared/enemy_flight_steering.dart
//
// FLOATY HOVER-AND-DIVE ENEMY STEERING — shared across all three cosmic
// modes (planet dungeons, cosmic survival, open cosmic space).
//
// The machine: an enemy drifts on a personal "breathing" orbit ring around
// its target (own arc direction and bob phase), periodically telegraphs by
// rearing back, then commits to a dive; on impact it floats back out instead
// of grinding on contact. Velocity is exponentially smoothed, so everything
// arcs and glides.
//
// Pure dart:math/dart:ui — no engine dependencies, fully unit-testable.
// Hosts own the surrounding rules (targeting, damage, walls/wrapping,
// despawning); this module only answers "what velocity this frame, and did
// a dive just land?".

import 'dart:math';
import 'dart:ui';

/// Per-mode/per-archetype tuning. All speeds are multipliers of the enemy's
/// own (effective) speed so slows/hastes keep working through the host.
class FlightSteeringProfile {
  const FlightSteeringProfile({
    required this.hoverRadius,
    this.ringBreathFraction = 0.16,
    this.ringFlattening = 1.0,
    this.bobAmplitude = 14.0,
    required this.orbitSpeed,
    this.hoverSpeedCapMul = 1.25,
    this.approachSpeedMul = 1.35,
    this.approachRangeMul = 2.4,
    this.commitRangeMul = 2.0,
    required this.windupSeconds,
    required this.diveSeconds,
    required this.diveSpeedMul,
    this.retreatSpeedMul = 1.7,
    this.hoverSteerRate = 3.0,
    this.diveSteerRate = 9.0,
    required this.swoopIntervalMin,
    required this.swoopIntervalMax,
  });

  /// Preferred standoff ring radius around the target.
  final double hoverRadius;

  /// Ring radius oscillation (± fraction of [hoverRadius]).
  final double ringBreathFraction;

  /// Vertical squash of the ring (top-down modes flatten it slightly so the
  /// hover reads as "around", not "above and below").
  final double ringFlattening;

  /// Personal vertical bob, px.
  final double bobAmplitude;

  /// Radians/sec drifted along the hover ring.
  final double orbitSpeed;

  /// Speed cap while ring-keeping, × enemy speed.
  final double hoverSpeedCapMul;

  /// Closing speed when far outside the ring, × enemy speed.
  final double approachSpeedMul;

  /// Beyond hoverRadius × this → close in directly.
  final double approachRangeMul;

  /// Within hoverRadius × this → allowed to begin a dive windup.
  final double commitRangeMul;

  /// Telegraph (rear-back) duration before the dive commits.
  final double windupSeconds;

  /// Max committed dive duration before giving up.
  final double diveSeconds;

  /// Dive speed, × enemy speed.
  final double diveSpeedMul;

  /// Post-impact float-away impulse, × enemy speed.
  final double retreatSpeedMul;

  /// Velocity smoothing while hovering (higher = snappier).
  final double hoverSteerRate;

  /// Velocity smoothing while diving.
  final double diveSteerRate;

  /// Seconds of hover between dives (uniform random in [min, max]).
  final double swoopIntervalMin;
  final double swoopIntervalMax;

  FlightSteeringProfile copyWith({
    double? hoverRadius,
    double? orbitSpeed,
    double? windupSeconds,
    double? diveSeconds,
    double? diveSpeedMul,
    double? swoopIntervalMin,
    double? swoopIntervalMax,
    double? approachSpeedMul,
  }) {
    return FlightSteeringProfile(
      hoverRadius: hoverRadius ?? this.hoverRadius,
      ringBreathFraction: ringBreathFraction,
      ringFlattening: ringFlattening,
      bobAmplitude: bobAmplitude,
      orbitSpeed: orbitSpeed ?? this.orbitSpeed,
      hoverSpeedCapMul: hoverSpeedCapMul,
      approachSpeedMul: approachSpeedMul ?? this.approachSpeedMul,
      approachRangeMul: approachRangeMul,
      commitRangeMul: commitRangeMul,
      windupSeconds: windupSeconds ?? this.windupSeconds,
      diveSeconds: diveSeconds ?? this.diveSeconds,
      diveSpeedMul: diveSpeedMul ?? this.diveSpeedMul,
      retreatSpeedMul: retreatSpeedMul,
      hoverSteerRate: hoverSteerRate,
      diveSteerRate: diveSteerRate,
      swoopIntervalMin: swoopIntervalMin ?? this.swoopIntervalMin,
      swoopIntervalMax: swoopIntervalMax ?? this.swoopIntervalMax,
    );
  }

  // ── Mode presets ──────────────────────────────────────────
  // Dungeon: roomy arenas, slow readable rhythm (the original tuning).
  static const dungeonWisp = FlightSteeringProfile(
    hoverRadius: 126,
    ringFlattening: 0.82,
    orbitSpeed: 0.85,
    windupSeconds: 0.28,
    diveSeconds: 1.1,
    diveSpeedMul: 2.7,
    swoopIntervalMin: 1.7,
    swoopIntervalMax: 2.8,
  );
  static const dungeonPouncer = FlightSteeringProfile(
    hoverRadius: 92,
    ringFlattening: 0.82,
    orbitSpeed: 1.5,
    windupSeconds: 0.28,
    diveSeconds: 1.1,
    diveSpeedMul: 2.7,
    swoopIntervalMin: 0.9,
    swoopIntervalMax: 2.0,
  );
  static const dungeonGuardian = FlightSteeringProfile(
    hoverRadius: 175,
    ringFlattening: 0.82,
    orbitSpeed: 0.51,
    windupSeconds: 0.45,
    diveSeconds: 1.4,
    diveSpeedMul: 3.4,
    swoopIntervalMin: 2.6,
    swoopIntervalMax: 3.7,
  );

  // Survival: horde mode — tight ring, fast frequent dives so the pressure
  // of a wave stays relentless even though individual enemies float.
  static const survivalMelee = FlightSteeringProfile(
    hoverRadius: 84,
    orbitSpeed: 1.2,
    windupSeconds: 0.22,
    diveSeconds: 0.9,
    diveSpeedMul: 2.4,
    approachSpeedMul: 1.2,
    swoopIntervalMin: 0.6,
    swoopIntervalMax: 1.4,
  );
  static const survivalPouncer = FlightSteeringProfile(
    hoverRadius: 64,
    orbitSpeed: 1.7,
    windupSeconds: 0.18,
    diveSeconds: 0.8,
    diveSpeedMul: 2.8,
    approachSpeedMul: 1.25,
    swoopIntervalMin: 0.45,
    swoopIntervalMax: 1.0,
  );

  // Open space: big distances, cinematic arcs.
  static const spaceMelee = FlightSteeringProfile(
    hoverRadius: 150,
    orbitSpeed: 0.8,
    windupSeconds: 0.3,
    diveSeconds: 1.2,
    diveSpeedMul: 2.6,
    approachSpeedMul: 1.3,
    swoopIntervalMin: 1.2,
    swoopIntervalMax: 2.4,
  );
  static const spacePouncer = FlightSteeringProfile(
    hoverRadius: 110,
    orbitSpeed: 1.4,
    windupSeconds: 0.22,
    diveSeconds: 1.0,
    diveSpeedMul: 3.0,
    swoopIntervalMin: 0.7,
    swoopIntervalMax: 1.5,
  );
  static const spaceCrusher = FlightSteeringProfile(
    hoverRadius: 190,
    orbitSpeed: 0.5,
    windupSeconds: 0.5,
    diveSeconds: 1.6,
    diveSpeedMul: 3.2,
    swoopIntervalMin: 2.2,
    swoopIntervalMax: 3.4,
  );
}

/// Mutable per-enemy steering state. Hosts attach one to each enemy (lazily)
/// and may also use [targetIndex]/[retargetTimer] for sticky target picks.
class FlightSteeringState {
  FlightSteeringState(Random rng)
    : orbitAngle = rng.nextDouble() * pi * 2,
      orbitDir = rng.nextBool() ? 1.0 : -1.0,
      phase = rng.nextDouble() * pi * 2,
      swoopTimer = 0.7 + rng.nextDouble() * 1.6;

  double orbitAngle; // current angle on the hover ring around the target
  final double orbitDir; // clockwise / counter-clockwise
  double phase; // personal bob phase
  double swoopTimer; // hover seconds left before the next dive
  double windupTimer = 0; // telegraph before the dive commits
  double diveTimer = 0; // dive timeout
  bool diving = false;
  Offset velocity = Offset.zero;

  /// Set once the first dive commits — the telegraph RING is a one-time
  /// teaching cue per enemy; later windups still rear back but stay quiet.
  bool telegraphShown = false;

  // Host-side target stickiness (optional convenience).
  int targetIndex = 0;
  double retargetTimer = 0;

  /// True while rearing back — hosts can render a telegraph off this.
  bool get telegraphing => windupTimer > 0;

  /// Render gate for the telegraph ring: only the enemy's FIRST windup
  /// draws it (after that the rear-back motion alone carries the warning).
  bool get showTelegraphRing => telegraphing && !telegraphShown;
}

/// One steering tick's outcome.
class FlightSteeringTick {
  const FlightSteeringTick({required this.velocity, required this.impact});

  /// Smoothed velocity for this frame; host applies
  /// `position += velocity * dt` (plus its own wrapping/clamping).
  final Offset velocity;

  /// True exactly when a dive reached contact range this tick — the host
  /// applies damage/cooldowns; the machine has already begun its retreat.
  final bool impact;
}

/// Advance [state] one tick toward a target [toTarget] away (host computes
/// the delta — including any world wrapping). [speed] is the enemy's current
/// effective speed (slows/hastes pre-applied).
FlightSteeringTick tickFlightSteering({
  required FlightSteeringState state,
  required FlightSteeringProfile profile,
  required Offset toTarget,
  required double speed,
  required double contactRange,
  required double dt,
  required Random rng,
}) {
  state.phase += dt;
  final dist = toTarget.distance;
  final dir = dist > 0.001
      ? toTarget / dist
      : Offset(cos(state.orbitAngle), sin(state.orbitAngle));

  var impact = false;
  Offset desiredVel;
  var steerRate = profile.hoverSteerRate;

  if (state.diving) {
    state.diveTimer -= dt;
    desiredVel = dir * speed * profile.diveSpeedMul;
    steerRate = profile.diveSteerRate;
    if (dist <= contactRange) {
      impact = true;
      state.diving = false;
      state.swoopTimer =
          profile.swoopIntervalMin +
          rng.nextDouble() *
              (profile.swoopIntervalMax - profile.swoopIntervalMin);
      state.orbitAngle = atan2(-dir.dy, -dir.dx);
      state.velocity = -dir * speed * profile.retreatSpeedMul; // float out
    } else if (state.diveTimer <= 0) {
      state.diving = false; // target slipped away — back to hovering
      state.swoopTimer = 0.8 + rng.nextDouble();
      state.orbitAngle = atan2(-dir.dy, -dir.dx);
    }
  } else if (state.windupTimer > 0) {
    state.windupTimer -= dt;
    // Telegraph: rear back slightly, locked on the target.
    desiredVel = -dir * speed * 0.55;
    if (state.windupTimer <= 0) {
      state.diving = true;
      state.diveTimer = profile.diveSeconds;
      state.telegraphShown = true; // the ring was a one-time teaching cue
    }
  } else {
    state.swoopTimer -= dt;
    if (state.swoopTimer <= 0 &&
        dist < profile.hoverRadius * profile.commitRangeMul) {
      state.windupTimer = profile.windupSeconds;
      desiredVel = Offset.zero;
    } else if (dist > profile.hoverRadius * profile.approachRangeMul) {
      // Far away: close in directly (still smoothed, so it arcs).
      desiredVel = dir * speed * profile.approachSpeedMul;
    } else {
      // Hover: drift along a breathing ring around the target.
      state.orbitAngle += state.orbitDir * profile.orbitSpeed * dt;
      final ring =
          profile.hoverRadius +
          sin(state.phase * 1.7) *
              profile.hoverRadius *
              profile.ringBreathFraction;
      final bob = sin(state.phase * 2.3) * profile.bobAmplitude;
      final desired =
          toTarget +
          Offset(
            cos(state.orbitAngle) * ring,
            sin(state.orbitAngle) * ring * profile.ringFlattening + bob,
          );
      desiredVel = desired * 2.4;
      final cap = speed * profile.hoverSpeedCapMul;
      final mag = desiredVel.distance;
      if (mag > cap) desiredVel = desiredVel / mag * cap;
    }
  }

  // Smooth steering → inertia → floaty.
  final blend = (1 - exp(-dt * steerRate)).clamp(0.0, 1.0).toDouble();
  state.velocity += (desiredVel - state.velocity) * blend;
  return FlightSteeringTick(velocity: state.velocity, impact: impact);
}
