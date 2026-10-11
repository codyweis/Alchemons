part of 'alchemy_effect_paint.dart';

/// THE PEACOCK'S TAIL (the Athanor, the Black Work's capstone) — between
/// the black work and the white, the old books say, the matter shows every
/// color at once. The creature stands in a pool of black water under a
/// film of oil: where the film is thin the black shows through, and where
/// it thickens it gives back color by thin-film interference — gold,
/// magenta, peacock blue, teal, each band the film's own thickness — so
/// the colors flow with the film as slow currents marble it, and shift
/// again as its surface tilts toward the light, a white sheen sliding over
/// the crests. Beads of that color rise off it and dissolve, and a faint
/// light of whatever color is uppermost lies behind the creature.
///
/// The pool is one mesh (drawVertices), its color reckoned at each vertex:
/// the film is marbled by a divergence-free curl flow ([_Flow], warped
/// twice), its thickness read off as color through the three wavelengths'
/// interference. Every vertex is a smooth function of the clock; no
/// gradients rebuilt, no blur.
abstract final class _PeacockTail {
  static const int _rings = 10, _segs = 36;
  static final _Tris _tris = _Tris(_segs * (2 * _rings - 1) + 8);
  static const int _verts = _rings * _segs + 1;
  static final Float64List _vx = Float64List(_verts), _vy = Float64List(_verts);
  static final Int32List _vc = Int32List(_verts);

  /// The pool's own currents, in pool space (its rim the unit circle).
  static final _Flow _flow = _Flow(
    const [
      (0.9, 0.7, 0.16, 0.4, 0.9),
      (-0.6, 1.1, -0.13, 2.1, 0.8),
      (2.1, -1.0, 0.24, 1.3, 0.3),
      (0.8, 2.3, -0.21, 4.4, 0.25),
    ],
    scale: 0.42,
    x0: -1.3,
    x1: 1.3,
    y0: -1.3,
    y1: 1.3,
    n: 14,
  );

  /// The unit pool's ring points, and how much each ring fades at its edge.
  static final Float64List _ca = Float64List.fromList([
    for (var s = 0; s < _segs; s++) math.cos(s / _segs * math.pi * 2),
  ]);
  static final Float64List _sa = Float64List.fromList([
    for (var s = 0; s < _segs; s++) math.sin(s / _segs * math.pi * 2),
  ]);
  static final Float64List _edge = Float64List.fromList([
    for (var ring = 0; ring <= _rings; ring++)
      math.pow(1 - math.pow(ring / _rings, 2.4), 1.1).toDouble(),
  ]);

  // The film at the point last read: its color (0xRRGGBB) and its sheen.
  static int _rgb0 = 0;
  static double _sheen = 0;

  /// The film at (x, y) on the unit pool at [t] into [_rgb0], [_sheen].
  static void _film(double x, double y, double t) {
    // Marbled: carried twice along the currents.
    _flow.sample(x, y);
    final qx = x + 0.3 * _flow.vx, qy = y + 0.3 * _flow.vy;
    _flow.sample(qx, qy);
    final wx = qx + 0.22 * _flow.vx, wy = qy + 0.22 * _flow.vy;
    // Its thickness in nanometres: thin (black) in streaks, thick in
    // bands.
    final s1 = math.sin(1.9 * wx + 1.6 * wy + t * 0.12);
    final s2 = math.sin(-1.3 * wx + 2.5 * wy - t * 0.09 + 1.3);
    final h = math.max(0.0, 180 + 230 * s1 + 110 * s2);
    // How the surface leans: toward the light the bands shift and shine.
    final tilt = (-0.6 * _flow.vx - 0.8 * _flow.vy) * 0.5;
    final cosT = (0.78 + 0.18 * y + 0.1 * tilt).clamp(0.4, 1.0);
    // Interference in red, green and blue light: the film's optical path
    // against each wavelength.
    final path = 2 * 1.45 * h * cosT;
    double band(double lambda) {
      final s = math.sin(math.pi * path / lambda);
      return s * s;
    }

    // A film too thin to colour shows the black water.
    final show = _smooth(25, 110, h);
    final rr = band(640) * show, gg = band(540) * show, bb = band(455) * show;
    // Richer than a real film, so it reads at a glance and at HUD size.
    final lum = (rr + gg + bb) / 3;
    int ch(double v) =>
        (255 * (lum + (v - lum) * 1.12).clamp(0.0, 1.0) * 0.94).round();
    _rgb0 = (ch(rr) << 16) | (ch(gg) << 8) | ch(bb);
    _sheen = _smooth(0.55, 1.0, tilt) * show;
  }

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
  ) {
    final cx = at.dx, fy = at.dy + r * 0.64;
    final rx = r * 1.22, ry = r * 0.33;
    _flow.prepare(t);
    if (!front) {
      // The light of the uppermost color, faint behind the creature.
      _film(0, -0.25, t);
      _pool(c, cx, at.dy - r * 0.05, r * 0.95, r * 0.85,
          Color(0xFF000000 | _rgb0), 0.16 * o);
      _film(0.3, 0.2, t);
      _pool(c, cx, fy, rx * 1.2, ry * 1.6, Color(0xFF000000 | _rgb0),
          0.16 * o);
      // The pool: vertex 0 the centre, then ring by ring outward.
      var k = 0;
      void vert(double ux, double uy, double edge) {
        _film(ux, uy, t);
        _vx[k] = cx + ux * rx;
        _vy[k] = fy + uy * ry;
        final lit = _sheen > 0.01 ? _mix(_rgb0, 0xFFFFFF, 0.55 * _sheen) : _rgb0;
        _vc[k] = _argb(lit, 0.96 * edge * o);
        k++;
      }

      vert(0, 0, 1);
      for (var ring = 1; ring <= _rings; ring++) {
        final rho = ring / _rings;
        for (var s = 0; s < _segs; s++) {
          final wob =
              1 + 0.05 * math.sin(3 * s / _segs * math.pi * 2 + t * 0.4) * rho;
          vert(_ca[s] * rho * wob, _sa[s] * rho * wob, _edge[ring]);
        }
      }
      int idx(int ring, int s) =>
          ring == 0 ? 0 : 1 + (ring - 1) * _segs + (s % _segs);
      void tri(int a, int b, int cc) => _tris.add(
        _vx[a],
        _vy[a],
        _vx[b],
        _vy[b],
        _vx[cc],
        _vy[cc],
        _vc[a],
        _vc[b],
        _vc[cc],
      );
      for (var s = 0; s < _segs; s++) {
        tri(0, idx(1, s), idx(1, s + 1));
      }
      for (var ring = 1; ring < _rings; ring++) {
        for (var s = 0; s < _segs; s++) {
          tri(idx(ring, s), idx(ring + 1, s), idx(ring + 1, s + 1));
          tri(idx(ring, s), idx(ring + 1, s + 1), idx(ring, s + 1));
        }
      }
      _tris.draw(c);
      // The wet sheen along its far edge.
      _pool(c, cx - rx * 0.2, fy - ry * 0.62, rx * 0.5, ry * 0.12,
          const Color(0xFFE8E2FF), 0.22 * o);
    }

    // Beads of the film's color rising off it and dissolving, with short
    // trails so they read as currents.
    _Atlas.clear();
    for (var i = 0; i < 22; i++) {
      final a = _h(i, 61) * math.pi * 2;
      final near = math.sin(a) > 0.1;
      if (near != front) continue;
      final rho = 0.35 + 0.6 * math.sqrt(_h(i, 62));
      final ux = math.cos(a) * rho, uy = math.sin(a) * rho;
      final period = 4.5 + 3 * _h(i, 63);
      final u = _frac(t / period + _h(i, 64));
      final env = _smooth(0.0, 0.15, u) * (1 - _smooth(0.55, 1.0, u));
      if (env <= 0.01) continue;
      _film(ux, uy, t);
      final rgb = _mix(_rgb0, 0xFFFFFF, 0.3);
      final rise = r * (0.55 + 0.4 * _h(i, 65));
      final size = math.max(2.4, r * 0.085);
      for (var tr = 3; tr >= 0; tr--) {
        final uu = (u - tr * 0.02).clamp(0.0, 1.0);
        final px = cx + ux * rx + math.sin(t * 0.8 + i) * r * 0.05 * uu;
        final py = fy + uy * ry - rise * uu;
        _Atlas.add(
          px,
          py,
          size * (1 - tr * 0.18),
          rgb,
          (tr == 0 ? 0.85 : 0.3 - tr * 0.06) * env * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
