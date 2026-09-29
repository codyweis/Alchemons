part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GLACERON — the Ice planet: pack ice, and its ring
//
//  A frozen sea broken into floes: flat plates of ice, each shaded by which
//  way it faces and catching a white glint as it turns into the light, with
//  dark water showing in the leads between them — Magmora's plates, frozen,
//  and lit like Lumishara's facets. The poles are solid cap. Round it, the
//  ring it always had, as crisp translucent bands with a gap.
//
//  Tried and cut (2026-09-28): a smooth ice ball scored with fracture lines
//  (read as blurry and scratched).
// ─────────────────────────────────────────────────────────────────────────────

class IcePlanetArt extends PlanetArt {
  IcePlanetArt._(this._floes, this._caps, this._ring);

  factory IcePlanetArt(int seed) {
    final rng = Random(seed * 19 + 1);
    final unit = unitView(_spin);
    return IcePlanetArt._(
      _FacetShell(rng, count: 130, gap: 0.0045, gapVar: 2.2, sides: 14),
      <Path>[
        ?latitudeCap(unit, 1.12, wave: 0.05, waves: 5),
        ?latitudeCap(unit, -1.16, south: true, wave: 0.05, waves: 4),
      ],
      // Ice rings: two broad lanes split by a clean gap and a thin outer
      // one, glinting grains of ice on their orbits over them.
      _ParticleRing(
        rng,
        spin: _spin,
        lanes: const [(1.5, 0.09, 3.0), (1.82, 0.14, 4.5), (2.08, 0.05, 1.2)],
        laneColor: const Color(0xFFCFEFFA),
        laneReach: 2.3,
        laneStops: const [
          0, 0.6, 0.63, 0.67, 0.695, 0.72, 0.75, 0.826, 0.852, 0.878, 0.92,
          0.96,
        ],
        laneAlphas: const [
          0, 0, 0.16, 0.22, 0.03, 0.05, 0.26, 0.22, 0.03, 0.14, 0.08, 0,
        ],
        dim: const Color(0xFFB8DCEC).withValues(alpha: 0.6),
        bright: const Color(0xFFFFFFFF),
        count: 420,
        grainSize: 0.005,
        brightCut: 0.7,
      ),
    );
  }

  /// No roll: the pole stands straight up, so the ring lies level.
  static const _spin = SphereSpin(period: 190, roll: 0);

  static const _ice = [
    Color(0xFF6F92AA),
    Color(0xFF93B6CA),
    Color(0xFFB4D3E2),
    Color(0xFFD3E9F2),
    Color(0xFFEDF7FB),
  ];

  final _FacetShell _floes;
  final List<Path> _caps;
  final _ParticleRing _ring;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF8BE6FF), alpha: 0.08, reach: 1.8);
    _ring.paint(c, p, r, t, front: false, wake: wake);
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) =>
      _ring.paint(c, p, r, t, front: true, wake: wake);

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    c.save();
    _clipDisc(c, p, r);
    // The sea in the leads.
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, const [
          Color(0xFF3A7494),
          Color(0xFF285A7A),
          Color(0xFF16395A),
        ], const [0.0, 0.7, 1.0]),
    );
    _floes.paint(c, view, _ice, glintAlpha: 0.75, glintPower: 30);
    final cap = Paint()..color = const Color(0xFFF4FAFD);
    for (final path in _caps) {
      _drawUnit(c, p, r, path, cap);
    }
    _shade(c, p, r, strength: 0.85, night: const Color(0xFF040C18));
    c.restore();
    _limb(c, p, r, const Color(0xFFC4F2FF), alpha: 0.22, inner: 0.94,
        outer: 1.06);
  }

  @override
  double get cardReach => 2.2;

  @override
  Color get territoryTint => const Color(0xFF3FB8D8);

  @override
  double get territoryStrength => 0.06;

  /// Ice splinters, turning and catching the light.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFFFFFFF),
    mid: Color(0xFFCFF6FF),
    dying: Color(0xFF7FD8F0),
    motion: MoteMotion.twinkle,
    shape: MoteShape.shard,
    speed: 0.08,
    size: 2.0,
    spin: 0.9,
  );
}
