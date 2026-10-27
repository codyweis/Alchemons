part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE RING A FALLEN GUARDIAN LEAVES
//
//  When a planet's guardian falls, matter lifts off its surface and winds out
//  into a ring, and the ring stays: from anywhere in space, a planet that has
//  been beaten reads as beaten, and the galaxy fills with ringed worlds as
//  the campaign goes on.
//
//  One ring for all seventeen, so it reads as one sign: Cindrath's moving
//  ring ([_ParticleRing]) in the planet's own colour, on a fixed tilt that
//  leans the other way from every planet's equator. Where a planet already
//  wears a ring (Cindrath, Glaceron, Nythralor's disk), this one sits outside
//  it and crosses it. The first time, it forms: see [_ParticleRing.paint]'s
//  `form`.
// ─────────────────────────────────────────────────────────────────────────────

class ClearedRing {
  ClearedRing._(this._ring, this.reach);

  /// The ring for the planet [art] draws. [seed] scatters its grains.
  factory ClearedRing.of(PlanetArt art, int seed) {
    // Outside anything the planet already has going round it.
    final at = max(1.5, art.cardReach + 0.25);
    final reach = at + 0.3;
    final (stops, alphas) = _ParticleRing.laneProfile([
      (at, 0.07, 0.2),
      (at + 0.14, 0.035, 0.09),
    ], reach);
    final tint = art.territoryTint;
    return ClearedRing._(
      _ParticleRing(
        Random(seed * 37 + 11),
        spin: _tilt,
        lanes: [(at, 0.07, 3.0), (at + 0.14, 0.035, 1.0)],
        laneColor: _tone(tint, 0.6, 0.8),
        laneReach: reach,
        laneStops: stops,
        laneAlphas: alphas,
        dim: _tone(tint, 0.58, 0.85).withValues(alpha: 0.72),
        bright: _tone(tint, 0.82, 0.95),
        count: 340,
        clumps: 7,
        perClump: 16,
        grainSize: 0.0072,
      ),
      reach,
    );
  }

  /// Leans the other way from the planets' own equators (their roll is
  /// -0.35, or level), and opens a little wider, so it never reads as the
  /// ring a planet was born with.
  static const _tilt = SphereSpin(period: 1, roll: 0.5, lean: 0.42);

  /// How long it takes to form, seconds.
  static const double formSeconds = 4.5;

  final _ParticleRing _ring;

  /// How far out it reaches, planet radii.
  final double reach;

  /// The near half ([front]) or the far half. [form] (0..1) is how far it
  /// has formed; 1 is the ring as it stays.
  void paint(
    Canvas c,
    Offset p,
    double r,
    double t, {
    required bool front,
    Offset? wake,
    double form = 1,
  }) {
    if (form <= 0) return;
    _ring.paint(c, p, r, t, front: front, wake: wake, form: form);
  }

  /// [c] at [light], its saturation held to [maxSat]: territory tints are
  /// picked to wash space faintly, and lit grains need them lifted.
  static Color _tone(Color c, double light, double maxSat) {
    final h = HSLColor.fromColor(c);
    return h
        .withSaturation(min(h.saturation, maxSat))
        .withLightness(light)
        .toColor();
  }
}
