part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VAPORIS — the Steam planet: dense fog and erupting geysers
//
//  The original, restored at the player's word ("I liked the look of the
//  steam coming out before a lot better"): a pale sphere sunk in layers of
//  drifting fog, hot vents glowing on its face, geysers firing plumes of
//  steam off the limb in turn, and wisps of fog trailing round it. Every
//  blurred shape it drew is here as a gradient of the same softness, so it
//  looks as it did without a blur pass per shape per frame.
//
//  The original seeded its "random" layout from the planet's position every
//  frame, so the layout was constant; it is worked out once here instead.
//
//  Tried and cut (2026-09-28/29): a veiled cloud ball with soft haze layers,
//  then hot-spring pools with bead-like puffs ("cheesy").
// ─────────────────────────────────────────────────────────────────────────────

class SteamPlanetArt extends PlanetArt {
  SteamPlanetArt._(this._clouds, this._vents, this._geysers, this._wisps);

  factory SteamPlanetArt(int seed) {
    // Consumed in exactly the order the original drew in.
    final rng = Random(seed);
    final clouds = [
      for (var i = 0; i < 8; i++)
        (
          rng.nextDouble() * pi * 2,
          0.8 + rng.nextDouble() * 1.2,
          0.12 + rng.nextDouble() * 0.08,
        ),
    ];
    final vents = [
      for (var i = 0; i < 4; i++)
        (rng.nextDouble() * pi * 2, rng.nextDouble() * 0.6),
    ];
    final geysers = [
      for (var g = 0; g < 5; g++)
        (rng.nextDouble() * pi * 2, 0.6 + rng.nextDouble() * 0.4),
    ];
    final wisps = [
      for (var i = 0; i < 6; i++)
        (rng.nextDouble() * pi * 2, 1.0 + rng.nextDouble() * 0.6),
    ];
    return SteamPlanetArt._(clouds, vents, geysers, wisps);
  }

  static const _col = Color(0xFF90A4AE);
  static const _vent = Color(0xFFFFAB40);

  /// (angle, distance in radii, drift speed)
  final List<(double, double, double)> _clouds;

  /// (angle, distance in radii)
  final List<(double, double)> _vents;

  /// (angle, eruption speed)
  final List<(double, double)> _geysers;

  /// (angle, distance in radii)
  final List<(double, double)> _wisps;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _col);

    // Thick ambient fog blanket.
    for (var ring = 0; ring < 4; ring++) {
      final fogR = r * (2.2 + ring * 0.5) + sin(t * 0.15 + ring) * r * 0.15;
      final fogAlpha = (0.04 - ring * 0.008).clamp(0.005, 0.06);
      _softCircle(
        c,
        Offset(
          p.dx + cos(t * 0.08 + ring * 1.7) * r * 0.2,
          p.dy + sin(t * 0.1 + ring * 2.1) * r * 0.15,
        ),
        fogR,
        _col.withValues(alpha: fogAlpha),
        r * 0.6,
      );
    }

    // Rolling fog clouds.
    final pale = Color.lerp(_col, const Color(0xFFFFFFFF), 0.15)!;
    for (var i = 0; i < _clouds.length; i++) {
      final (angle, dist, speed) = _clouds[i];
      final drift = t * speed;
      final at = Offset(
        p.dx + cos(angle + drift) * dist * r,
        p.dy + sin(angle + drift * 0.7) * dist * r,
      );
      final cr = r * (0.3 + 0.2 * sin(t * 0.3 + i * 0.9));
      final a = (0.08 + 0.04 * sin(t * 0.4 + i * 1.1)).clamp(0.0, 0.15);
      _softCircle(c, at, cr, pale.withValues(alpha: a), r * 0.3);
    }

    // Inner mist swirl.
    for (var i = 0; i < 5; i++) {
      _softCircle(
        c,
        Offset(
          p.dx + cos(t * 0.3 + i * 1.2) * r * 0.4,
          p.dy + sin(t * 0.4 + i * 1.5) * r * 0.3,
        ),
        r * (0.5 + 0.2 * sin(t * 0.5 + i)),
        _col.withValues(alpha: 0.18),
        12,
      );
    }
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    _oldSphere(c, p, r, _col, highlight: 0.5, shadow: 0.2);

    // Hot vents glowing on the surface.
    c.save();
    _clipDisc(c, p, r);
    for (var i = 0; i < _vents.length; i++) {
      final (va, vd) = _vents[i];
      final glow = (0.25 + 0.15 * sin(t * 1.5 + i * 2.0)).clamp(0.0, 0.5);
      _softCircle(
        c,
        Offset(p.dx + cos(va) * vd * r, p.dy + sin(va) * vd * r),
        r * 0.06,
        _vent.withValues(alpha: glow),
        3,
      );
    }
    c.restore();
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) {
    // Geysers erupting off the surface, each on its own beat.
    for (var g = 0; g < _geysers.length; g++) {
      final (ga, speed) = _geysers[g];
      final phase = (t * speed + g * 1.8) % (pi * 2);
      final intensity = sin(phase).clamp(0.0, 1.0);
      if (intensity < 0.15) continue;
      final gx = p.dx + cos(ga) * r * 0.85;
      final gy = p.dy + sin(ga) * r * 0.85;
      final nx = cos(ga), ny = sin(ga);
      final height = r * (0.6 + intensity * 1.0);
      for (var s = 0; s < 6; s++) {
        final frac = s / 6.0;
        final sr = r * (0.04 + 0.08 * frac) * intensity;
        final sa = ((0.35 - frac * 0.3) * intensity).clamp(0.0, 0.4);
        final steam = Color.lerp(const Color(0xFFFFFFFF), _col, frac)!;
        _softCircle(
          c,
          Offset(gx + nx * height * frac, gy + ny * height * frac),
          sr,
          steam.withValues(alpha: sa),
          sr * 1.5,
        );
      }
      if (intensity > 0.5) {
        _softCircle(
          c,
          Offset(gx, gy),
          r * 0.05,
          _vent.withValues(alpha: (intensity - 0.5) * 0.6),
          4,
        );
      }
    }

    // Wisps of fog trailing round it.
    for (var i = 0; i < _wisps.length; i++) {
      final (a0, dist) = _wisps[i];
      final a = a0 + t * 0.05;
      final tw = r * (0.15 + 0.1 * sin(t * 0.25 + i));
      final sigma = r * 0.15;
      c.save();
      c.translate(p.dx + cos(a) * dist * r, p.dy + sin(a) * dist * r);
      c.rotate(a);
      c.scale(1, (r * 0.06 + 2 * sigma) / (tw + 2 * sigma));
      _softCircle(
        c,
        Offset.zero,
        tw,
        _col.withValues(alpha: (0.06 + 0.03 * sin(t * 0.3 + i * 0.7)) * 0.5),
        sigma,
      );
      c.restore();
    }
  }

  @override
  double get cardReach => 1.6;

  @override
  Color get territoryTint => const Color(0xFF7F95A2);

  /// Vapour, drifting and thinning.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFE8EEF0),
    mid: Color(0xFFC8D4DA),
    dying: Color(0xFF90A4AE),
    shape: MoteShape.puff,
    perTile: 2,
    speed: 0.03,
    travel: 110,
    size: 3,
    alpha: 0.9,
    glow: false,
  );
}
