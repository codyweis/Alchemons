part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  LUMISHARA — the Crystal planet: a cut gem
//
//  A sphere of flat facets, each shaded by which way it faces, over a light
//  that lives inside it and shows through the seams and the translucent
//  faces. As it turns, a facet swinging into line between the light and the
//  eye flashes white and fades — a glint that travels across the gem. That
//  glint is the planet.
// ─────────────────────────────────────────────────────────────────────────────

class CrystalPlanetArt extends PlanetArt {
  CrystalPlanetArt._(this._plates, this._facets);

  factory CrystalPlanetArt(int seed) {
    final rng = Random(seed * 41 + 23);
    final plates = SpherePlates.fromSeeds(
      SpherePlates.spreadSeeds(count: 46, rng: rng, jitter: 1.0),
      sides: 16,
    );
    final facets = [
      for (var i = 0; i < plates.plateCount; i++)
        plates.ring(i, (k, x, y, z) => 0.012, minFrac: 0.5),
    ];
    return CrystalPlanetArt._(plates, facets);
  }

  static const _spin = SphereSpin(period: 140);
  static const _levels = 5;

  /// Light and half-vector in view space (x right, y up, z to the eye).
  static const _lx = -0.5, _ly = 0.55, _lz = 0.67;
  static final _hl = () {
    final hx = _lx, hy = _ly, hz = _lz + 1;
    final l = sqrt(hx * hx + hy * hy + hz * hz);
    return (hx / l, hy / l, hz / l);
  }();

  static const _dark = Color(0xFF0C4A44);
  static const _lit = Color(0xFFA6F5E0);

  final SpherePlates _plates;
  final List<Float64List> _facets;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF1DE9B6), alpha: 0.13, reach: 2.1);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final m = _spin.matrixAt(t);
    final view = SphereView(p, r, m);
    c.save();
    _clipDisc(c, p, r);

    // The light inside.
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(p.dx - r * 0.1, p.dy - r * 0.12),
          r,
          const [Color(0xFFCFFFF4), Color(0xFF2FCFA8), Color(0xFF0B5A50)],
          const [0.0, 0.55, 1.0],
        ),
    );

    // Facets, bucketed by how squarely they face the light: five fills.
    final buckets = List.generate(_levels, (_) => Path());
    final glints = <(Float64List, double)>[];
    final (hx, hy, hz) = _hl;
    final s = _plates.seeds;
    for (var i = 0; i < _plates.plateCount; i++) {
      final x = s[i * 3], y = s[i * 3 + 1], z = s[i * 3 + 2];
      final nx = m[0] * x + m[1] * y + m[2] * z;
      final ny = m[3] * x + m[4] * y + m[5] * z;
      final nz = m[6] * x + m[7] * y + m[8] * z;
      if (nz < -0.3) continue;
      final lambert = (nx * _lx + ny * _ly + nz * _lz).clamp(0.0, 1.0);
      final level = (lambert * (_levels - 1)).round();
      addSphereRing(buckets[level], view, _facets[i]);
      final spec = pow((nx * hx + ny * hy + nz * hz).clamp(0.0, 1.0), 40);
      if (spec > 0.15 && nz > 0) glints.add((_facets[i], spec.toDouble()));
    }
    for (var k = 0; k < _levels; k++) {
      c.drawPath(
        buckets[k],
        Paint()
          ..color = Color.lerp(_dark, _lit, k / (_levels - 1))!
              .withValues(alpha: 0.82),
      );
    }
    for (final (ring, spec) in glints) {
      final glint = Path();
      addSphereRing(glint, view, ring);
      c.drawPath(
        glint,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * spec),
      );
    }
    _shade(c, p, r, strength: 0.55, night: const Color(0xFF021412));
    c.restore();
    _limb(c, p, r, const Color(0xFF5CF5D0), alpha: 0.28, inner: 0.86);
  }

  @override
  Color get territoryTint => const Color(0xFF14B08A);

  @override
  double get territoryStrength => 0.065;

  /// Loose shards of it, turning and flashing.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFE0FFF6),
    mid: Color(0xFF7CF5D8),
    dying: Color(0xFF1DA88A),
    motion: MoteMotion.twinkle,
    shape: MoteShape.shard,
    speed: 0.07,
    size: 2.4,
    spin: 0.7,
  );
}
