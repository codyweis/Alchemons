part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  PYRATHIS — the Fire planet: a burning world
//
//  An ember sphere — gold at the heart, deepening to red at the edge, with
//  slow darker and brighter churn turning across its face — and round it a
//  corona of fire made the way fire is: hundreds of embers boiling up off
//  the limb from flickering sources, curling as they climb, cooling from
//  gold to orange to red and going out in the dark. Where sources flare the
//  embers stand up in tongues; between them, lulls. The same idea that made
//  Cindrath's ring come alive: many small lights on real motion, not drawn
//  shapes. Sunk in a warm haze, as every planet used to be.
//
//  Tried and cut (2026-09-28/29): granulation (honeycomb), soft plasma blobs
//  and gradient corona tongues (blurry), flames over the whole face in
//  three random heats with white-hot hearts (busy, "cheesy"), separate
//  nested flame tongues round the limb (outlined petals), and a continuous
//  three-layer crown with pointed tongues (still "cartoony").
// ─────────────────────────────────────────────────────────────────────────────

class FirePlanetArt extends PlanetArt {
  FirePlanetArt._(this._corona, this._churn);

  factory FirePlanetArt(int seed) {
    final rng = Random(seed * 17 + 3);
    final corona = _EmberCorona(rng);
    final churn = Float64List(7 * 3);
    for (var i = 0; i < 7; i++) {
      final (x, y, z) = sphereAt(
        (rng.nextDouble() - 0.5) * 2.0,
        rng.nextDouble() * 2 * pi,
      );
      churn.setAll(i * 3, [x, y, z]);
    }
    return FirePlanetArt._(corona, churn);
  }

  static const _spin = SphereSpin(period: 120);
  static const _warm = Color(0xFFFF6A1E);

  final _EmberCorona _corona;
  final Float64List _churn;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _warm);
    _halo(c, p, r, _warm, alpha: 0.24, reach: 1.9);
    _corona.paint(c, p, r, t);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    final breathe = 0.5 + 0.5 * sin(t * 0.6);
    // The ember face: gold at the heart, red at the edge.
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          [
            Color.lerp(
              const Color(0xFFFFB44A),
              const Color(0xFFFFD27A),
              breathe,
            )!,
            const Color(0xFFF07A26),
            const Color(0xFFD2461A),
            const Color(0xFF8E1E08),
          ],
          const [0.0, 0.45, 0.78, 1.0],
        ),
    );
    // Slow churn across it: soft darker and brighter patches turning with
    // the world.
    c.save();
    _clipDisc(c, p, r);
    for (var i = 0; i < 7; i++) {
      final sp = view.project(
        _churn[i * 3],
        _churn[i * 3 + 1],
        _churn[i * 3 + 2],
      );
      if (sp.depth < 0) continue;
      final pulse = 0.5 + 0.5 * sin(t * 0.5 + i * 1.9);
      _softCircle(
        c,
        sp.offset,
        r * 0.18 * (0.6 + 0.4 * sp.depth),
        (i.isEven ? const Color(0xFFFFE2A0) : const Color(0xFF9E2A0C))
            .withValues(alpha: 0.28 * pulse),
        r * 0.08,
      );
    }
    c.restore();
    _limb(c, p, r, const Color(0xFFFFB060), alpha: 0.32, inner: 0.9);
  }

  @override
  Color get territoryTint => const Color(0xFFD2401A);

  @override
  double get cardReach => 1.35;

  /// Sparks thrown off it, streaking outward and going red as they cool.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFFFE08A),
    mid: Color(0xFFFF8A2E),
    dying: Color(0xFF8A1E08),
    motion: MoteMotion.outward,
    shape: MoteShape.streak,
    speed: 0.07,
    travel: 240,
    size: 1.5,
  );
}
