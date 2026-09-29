part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VERDANTHOS — the Plant planet: one forest, all the way round
//
//  Canopy, crown on crown, in three greens, so thick that the planet's edge
//  is not a clean circle — the crowns on the limb stand up off it. On the
//  night side the forest shows its own light: blooms that glow where the
//  sun has gone.
// ─────────────────────────────────────────────────────────────────────────────

class PlantPlanetArt extends PlanetArt {
  PlantPlanetArt._(this._crowns, this._young, this._edge, this._blooms);

  factory PlantPlanetArt(int seed) {
    final rng = Random(seed * 47 + 31);
    final crowns = _BlobField.scatter(rng, 150, size: 0.065, rough: 0.14,
        soft: 1, uniform: true);
    final young = _BlobField.scatter(rng, 40, size: 0.045, rough: 0.14,
        soft: 1, uniform: true);
    final edge = <(double, double, double, double)>[];
    final cs = crowns.centres;
    for (var i = 0; i < crowns.cores.length; i++) {
      edge.add((cs[i * 3], cs[i * 3 + 1], cs[i * 3 + 2], 0.065));
    }
    final blooms = Float64List(18 * 3);
    for (var i = 0; i < 18; i++) {
      final (x, y, z) = sphereAt(
        asin(rng.nextDouble() * 2 - 1),
        rng.nextDouble() * 2 * pi,
      );
      blooms.setAll(i * 3, [x, y, z]);
    }
    return PlantPlanetArt._(crowns, young, edge, blooms);
  }

  static const _spin = SphereSpin(period: 210);
  static const _crownEdge = Color(0xFF1B4420);
  static const _bloom = Color(0xFFC8FF8A);

  final _BlobField _crowns;
  final _BlobField _young;
  final List<(double, double, double, double)> _edge;
  final Float64List _blooms;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF4CAF50), alpha: 0.09, reach: 2.0);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));

    // Crowns standing up off the limb: drawn first, unclipped, so the body
    // covers all but the part that stands proud of the edge.
    final bumps = Path();
    for (final (x, y, z, size) in _edge) {
      final sp = view.project(x, y, z);
      if (sp.depth.abs() > 0.14) continue;
      final rel = sp.offset - p;
      final l = rel.distance;
      if (l < 1) continue;
      final at = p + rel / l * r;
      bumps.addOval(Rect.fromCircle(center: at, radius: r * size * 0.55));
    }
    c.drawPath(bumps, Paint()..color = _crownEdge);

    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, const [
          Color(0xFF1E4E24),
          Color(0xFF173F1C),
          Color(0xFF0E2A12),
        ], const [0.0, 0.7, 1.0]),
    );
    // Crown on crown, each casting a little shadow to the lower right, so
    // the canopy stands up in lumps rather than lying flat.
    final crowns = _gatherRings(view, _crowns.cores, _crowns.centres);
    final cast = Offset(r * 0.018, r * 0.022);
    c.drawPath(crowns.shift(cast),
        Paint()..color = const Color(0xFF0C2410).withValues(alpha: 0.75));
    c.drawPath(crowns, Paint()..color = const Color(0xFF357A3A));
    final young = _gatherRings(view, _young.cores, _young.centres);
    c.drawPath(young.shift(cast * 0.7),
        Paint()..color = const Color(0xFF123218).withValues(alpha: 0.6));
    c.drawPath(young, Paint()..color = const Color(0xFF56A04A));
    _sheen(c, p, r, const Color(0xFFE8FFB0), alpha: 0.16);
    _shade(c, p, r, night: const Color(0xFF020803));

    // Blooms, brightest where it is darkest.
    final glow = Paint();
    for (var i = 0; i < 18; i++) {
      final sp = view.project(
        _blooms[i * 3],
        _blooms[i * 3 + 1],
        _blooms[i * 3 + 2],
      );
      if (sp.depth < 0.1) continue;
      final rel = (sp.offset - p) / r;
      final night = ((rel.dx * 0.66 + rel.dy * 0.74) + 0.25).clamp(0.0, 1.0);
      if (night <= 0.02) continue;
      final pulse = 0.65 + 0.35 * sin(t * 0.7 + i * 1.9);
      final a = night * pulse;
      final br = r * 0.022 * (0.5 + 0.5 * sp.depth);
      glow.color = _bloom.withValues(alpha: 0.12 * a);
      c.drawCircle(sp.offset, br * 3.2, glow);
      glow.color = _bloom.withValues(alpha: 0.85 * a);
      c.drawCircle(sp.offset, br, glow);
    }
    c.restore();
    _limb(c, p, r, const Color(0xFFA6E890), alpha: 0.16, inner: 0.9);
  }

  @override
  Color get territoryTint => const Color(0xFF2E8A40);

  @override
  double get territoryStrength => 0.06;

  /// Leaves, adrift and tumbling.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFB8E890),
    mid: Color(0xFF66BB5A),
    dying: Color(0xFF2E6B32),
    shape: MoteShape.leaf,
    speed: 0.03,
    travel: 150,
    size: 2.6,
    spin: 0.9,
  );
}
