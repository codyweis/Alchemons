part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TERRAGRIM — the Earth planet: bare stone with relief
//
//  Terraced mesas all over it: each rises in steps like contour lines, every
//  step a paler stone than the one below and casting a crisp shadow to the
//  lower right, so the land stands up off the sphere; a few canyons cut
//  through. A handful of boulders keep it company
//  on a tilted orbit, passing behind and coming round in front — the stone
//  debris the old planet had, now lit like everything else.
// ─────────────────────────────────────────────────────────────────────────────

class EarthPlanetArt extends PlanetArt {
  EarthPlanetArt._(this._levels, this._canyons, this._rocks);

  factory EarthPlanetArt(int seed) {
    final rng = Random(seed * 29 + 13);
    // Mesas: each the same lobed outline stepping in at every level, so
    // the terraces nest like contour lines.
    const steps = [1.0, 0.74, 0.5, 0.28];
    final levels = [for (var k = 0; k < 4; k++) <Float64List>[]];
    for (var m = 0; m < 30; m++) {
      final (x, y, z) = sphereAt(
        asin(rng.nextDouble() * 1.9 - 0.95),
        rng.nextDouble() * 2 * pi,
      );
      final size = 0.08 + pow(rng.nextDouble(), 1.4) * 0.17;
      final height = size > 0.17 ? 4 : (size > 0.11 ? 3 : 2);
      for (var k = 0; k < height; k++) {
        // Each step keeps the mesa's shape but drifts a little off-centre.
        final dl = (rng.nextDouble() - 0.5) * size * 0.25;
        final dn = (rng.nextDouble() - 0.5) * size * 0.25;
        final lat = asin(y.clamp(-1.0, 1.0)) + dl;
        final lon = atan2(z, x) + dn;
        final (sx, sy, sz) = sphereAt(lat, lon);
        levels[k].add(sphereBlob(sx, sy, sz, size * steps[k],
            Random(m * 7919 + k * 31), rough: 0.38, sides: 22));
      }
    }
    final canyons = <Float64List>[];
    for (var i = 0; i < 5; i++) {
      final lat = (rng.nextDouble() - 0.5) * 1.6;
      final lon = rng.nextDouble() * 2 * pi;
      final heading = rng.nextDouble() * pi;
      const n = 16;
      final pts = Float64List(n * 3);
      for (var k = 0; k < n; k++) {
        final s = (k / (n - 1) - 0.5) * 1.0;
        final (x, y, z) = sphereAt(
          lat + sin(heading) * s + sin(k * 1.3) * 0.025,
          lon + cos(heading) * s,
        );
        pts.setAll(k * 3, [x, y, z]);
      }
      canyons.add(pts);
    }
    final rocks = [
      for (var i = 0; i < 7; i++)
        (
          1.3 + rng.nextDouble() * 0.45, // orbit radius, planet radii
          rng.nextDouble() * 2 * pi, // phase
          0.03 + rng.nextDouble() * 0.035, // size
          rng.nextDouble() * 100, // shape seed
        ),
    ];
    return EarthPlanetArt._(
      [for (final l in levels) _BlobField._(l, const [], const [])],
      canyons,
      rocks,
    );
  }

  static const _spin = SphereSpin(period: 230);

  static const _low = [Color(0xFF5A4838), Color(0xFF45372B), Color(0xFF2A2119)];
  static const _steps = [
    Color(0xFF6E5B49),
    Color(0xFF84705D),
    Color(0xFF9C8874),
    Color(0xFFB6A38E),
  ];
  static const _cast = Color(0xFF221A13);
  static const _rockLit = Color(0xFF9E8266);
  static const _rockDark = Color(0xFF3A2B20);

  final List<_BlobField> _levels;
  final List<Float64List> _canyons;
  final List<(double, double, double, double)> _rocks;

  /// Boulders on an orbit tilted off the equator: the far ones ([front]
  /// false) are drawn behind the planet.
  void _paintRocks(Canvas c, Offset p, double r, double t, {required bool front}) {
    for (final (orbit, phase, size, shape) in _rocks) {
      final a = phase + t * 0.3 / (orbit * orbit);
      // Orbit plane: tilted so it crosses in front low and behind high.
      final x = cos(a) * orbit;
      final depth = sin(a);
      final y = sin(a) * orbit * 0.34;
      if ((depth > 0) != front) continue;
      final at = p + Offset(x * r * 0.94 + y * r * 0.25, y * r);
      final sz = r * size * (0.85 + 0.15 * depth);
      // Dark body, then its lit face nudged toward the light.
      c.drawPath(
        vfxBlob(at, sz, shape, n: 7, wobble: 0.28),
        Paint()..color = _rockDark,
      );
      c.drawPath(
        vfxBlob(at + Offset(-sz * 0.22, -sz * 0.24), sz * 0.72, shape + 3,
            n: 6, wobble: 0.3),
        Paint()..color = _rockLit,
      );
    }
  }

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFFB08050), alpha: 0.07, reach: 1.9);
    _paintRocks(c, p, r, t, front: false);
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) =>
      _paintRocks(c, p, r, t, front: true);

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, _low, const [0.0, 0.7, 1.0]),
    );
    // Terraces: each step first as its cast shadow, then itself, from the
    // valley floor up.
    final cast = Offset(r * 0.016, r * 0.02);
    for (var k = 0; k < _levels.length; k++) {
      final step = _levels[k].gather(view);
      c.drawPath(step.shift(cast),
          Paint()..color = _cast.withValues(alpha: 0.55));
      c.drawPath(step, Paint()..color = _steps[k]);
    }

    final cuts = Path();
    for (final pts in _canyons) {
      final n = pts.length ~/ 3;
      final run = <Offset>[];
      for (var k = 0; k < n; k++) {
        final sp = view.project(pts[k * 3], pts[k * 3 + 1], pts[k * 3 + 2]);
        if (sp.depth > 0.05) run.add(sp.offset);
      }
      if (run.length >= 3) {
        cuts.addPath(vfxRibbon(run, 0, r * 0.035, taperIn: true), Offset.zero);
      }
    }
    c.drawPath(cuts, Paint()..color = _cast.withValues(alpha: 0.85));

    _sheen(c, p, r, const Color(0xFFFFE2B8), alpha: 0.16);
    _shade(c, p, r, night: const Color(0xFF060403));
    c.restore();
    _limb(c, p, r, const Color(0xFFC49A70), alpha: 0.16, inner: 0.9);
  }

  @override
  double get cardReach => 1.8;

  @override
  Color get territoryTint => const Color(0xFF9A6A3E);

  @override
  double get territoryStrength => 0.06;

  /// Grit and gravel, tumbling.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFB89470),
    mid: Color(0xFF7A5A40),
    dying: Color(0xFF4A3526),
    shape: MoteShape.pebble,
    speed: 0.03,
    travel: 140,
    size: 2.4,
    spin: 0.5,
  );
}
