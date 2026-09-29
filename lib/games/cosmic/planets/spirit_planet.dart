part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ETHERION — the Spirit planet: a lantern
//
//  A sphere of midnight glass — the stars behind it show faintly through —
//  with a soul in it: a light at its heart fading out into the glass,
//  drifting and breathing, motes of it circling inside, veils of aqua and
//  violet light moving slowly round it. The edge is a soft glow. Every so
//  often the whole lantern thins, as the old planet phased.
//
//  Palette per the Spirit direction: deep midnight base, ONE luminous
//  accent (aqua), violet only in the veils.
//
//  Tried and cut (2026-09-28/29): see-through mist blobs (blurry, and read
//  as continents), wisp motes (feathers, like Zephyria's), an aurora
//  curtain standing off the surface (a detached arc), a crisp core ball,
//  and aurora bands, a reflection streak and a sharp rim line on the glass
//  (all "cheesy lines/reflections").
// ─────────────────────────────────────────────────────────────────────────────

class SpiritPlanetArt extends PlanetArt {
  SpiritPlanetArt._(this._veils);

  factory SpiritPlanetArt(int seed) {
    final rng = Random(seed * 59 + 41);
    return SpiritPlanetArt._([
      for (var i = 0; i < 5; i++)
        (
          rng.nextDouble() * 2 * pi, // angle round the heart
          0.25 + rng.nextDouble() * 0.4, // distance, radii
          0.28 + rng.nextDouble() * 0.22, // size, radii
          (rng.nextDouble() - 0.5) * 0.08, // drift
        ),
    ]);
  }

  static const _aqua = Color(0xFF7FF5E8);
  static const _violet = Color(0xFF8A6AE8);

  /// Veils of light drifting in the glass: (angle, distance, size, drift).
  final List<(double, double, double, double)> _veils;

  /// 1 normally; dips toward thin for a couple of seconds every twelve.
  double _presence(double t) {
    final tau = t % 12.0;
    if (tau > 2.4) return 1;
    return 1 - 0.3 * sin(pi * tau / 2.4);
  }

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF4A6AE0), alpha: 0.12, reach: 2.2);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final presence = _presence(t);
    c.save();
    _clipDisc(c, p, r);
    // The glass.
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, [
          const Color(0xFF1A2654).withValues(alpha: 0.74 * presence),
          const Color(0xFF121A40).withValues(alpha: 0.78 * presence),
          const Color(0xFF0B1030).withValues(alpha: 0.92 * presence),
        ], const [0.0, 0.72, 1.0]),
    );
    // The soul in it: a light, not a ball — bright at its heart and fading
    // into the glass, drifting and breathing, with motes of it circling
    // inside.
    final core = p +
        Offset(sin(t * 0.31) * r * 0.06, cos(t * 0.23) * r * 0.05 - r * 0.04);
    final cr = r * (0.5 + 0.03 * sin(t * 0.9));
    c.drawCircle(
      core,
      cr,
      Paint()
        ..shader = ui.Gradient.radial(core, cr, [
          const Color(0xFFEFFFFC).withValues(alpha: 0.95 * presence),
          _aqua.withValues(alpha: 0.7 * presence),
          const Color(0xFF3AB8C0).withValues(alpha: 0.28 * presence),
          const Color(0xFF3AB8C0).withValues(alpha: 0),
        ], const [0.0, 0.18, 0.5, 1.0]),
    );
    final mote = Paint();
    for (var i = 0; i < 7; i++) {
      final a = t * (0.12 + i * 0.03) * (i.isEven ? 1 : -1) + i * 0.9;
      final orbit = r * (0.28 + 0.05 * i);
      final at = core + Offset(cos(a) * orbit, sin(a) * orbit * 0.55);
      final glow = 0.5 + 0.5 * sin(t * 1.3 + i * 2.1);
      mote.color = _aqua.withValues(alpha: 0.12 * glow * presence);
      c.drawCircle(at, r * 0.035, mote);
      mote.color = const Color(0xFFEFFFFC).withValues(alpha: 0.8 * glow * presence);
      c.drawCircle(at, r * 0.009, mote);
    }
    // Veils of aqua and violet light drifting slowly round the heart.
    for (var i = 0; i < _veils.length; i++) {
      final (a0, dist, size, drift) = _veils[i];
      final a = a0 + t * drift;
      final breathe = 0.6 + 0.4 * sin(t * 0.35 + i * 1.7);
      _softCircle(
        c,
        p + Offset(cos(a), sin(a) * 0.8) * (dist * r),
        size * r,
        (i.isEven ? _aqua : _violet).withValues(alpha: 0.1 * breathe * presence),
        r * 0.14,
      );
    }
    _shade(c, p, r, strength: 0.45, night: const Color(0xFF02040E));
    c.restore();

    // The edge as a soft glow, not a line.
    _limb(c, p, r, _aqua, alpha: 0.18 * presence, inner: 0.8, outer: 1.14);
  }

  @override
  Color get territoryTint => const Color(0xFF3A4AB8);

  @override
  double get territoryStrength => 0.07;

  /// Small lights — the planet's own, wandering loose.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFD8FFFA),
    mid: Color(0xFF7FF5E8),
    dying: Color(0xFF6A5AD0),
    speed: 0.03,
    travel: 120,
    size: 2.0,
    alpha: 0.8,
  );
}
