part of 'alchemy_effect_paint.dart';

/// THE PEACOCK'S TAIL (the Athanor, the Black Work's capstone) — between
/// the black work and the white, the old books say, the matter shows every
/// color at once. The creature stands in a pool of black whose surface is
/// an oil-slick: bands of violet, teal, gold and rose that marble slowly
/// through each other, bright on their crests and black between. Beads of
/// that color rise off it and dissolve, and a faint light of whatever color
/// is uppermost lies behind it.
///
/// The pool is one mesh (drawVertices), its color reckoned at each vertex
/// from a slowly turning marbling field — no gradients rebuilt, no blur.
abstract final class _PeacockTail {
  static const int _rings = 8, _segs = 30;
  static final _Tris _tris = _Tris(_segs * (2 * _rings - 1) + 8);
  static final Float64List _vx = Float64List(_rings * _segs + 1);
  static final Float64List _vy = Float64List(_rings * _segs + 1);
  static final Int32List _vc = Int32List(_rings * _segs + 1);

  /// The unit pool's ring points, and how much each ring fades at its edge.
  static final Float64List _ca = Float64List.fromList([
    for (var s = 0; s < _segs; s++) math.cos(s / _segs * math.pi * 2),
  ]);
  static final Float64List _sa = Float64List.fromList([
    for (var s = 0; s < _segs; s++) math.sin(s / _segs * math.pi * 2),
  ]);
  static final Float64List _edge = Float64List.fromList([
    for (var ring = 0; ring <= _rings; ring++)
      math.pow(1 - math.pow(ring / _rings, 2.2), 1.2).toDouble(),
  ]);

  /// An oil-slick's colors in the order they run into each other: deep
  /// violet, blue, teal, old gold, rose — no pure red or green, which read
  /// as a rainbow rather than oil.
  static const List<int> _oil = [
    0x6A3AB8,
    0x3A62D0,
    0x22A8A4,
    0xC8A044,
    0xB8508E,
  ];

  /// The slick's color at phase [p] (any real; one turn runs the list).
  static int _oilAt(double p) {
    final f = _frac(p) * _oil.length;
    final i = f.floor();
    return _mix(_oil[i % _oil.length], _oil[(i + 1) % _oil.length], f - i);
  }

  static double _phase = 0, _crest = 0;

  /// The slick at (x, y) on the unit pool at [t], into [_phase] (where it
  /// is along the colors) and [_crest] (how bright the band is there:
  /// black between bands).
  static void _slick(double x, double y, double t) {
    final u =
        x +
        0.32 * math.sin(2.1 * y * 3 + t * 0.19) +
        0.18 * math.sin(1.3 * x * 3 - t * 0.11);
    final v = y * 3 + 0.4 * math.sin(1.7 * x * 3 - t * 0.14);
    final band = math.sin(3.4 * u + 1.3 * v + t * 0.2);
    _phase = 0.5 * band + 0.008 * t + 0.15 * u;
    final crest = 0.5 + 0.5 * math.sin(5.6 * u - 1.8 * v + t * 0.27 + band);
    _crest = math.pow(crest, 1.7).toDouble();
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
    if (!front) {
      // The light of the uppermost color, faint behind the creature.
      _slick(0, -0.2, t);
      final h0 = _phase;
      _pool(
        c,
        cx,
        at.dy - r * 0.05,
        r * 0.95,
        r * 0.85,
        Color(0xFF000000 | _oilAt(h0)),
        0.13 * o,
      );
      _pool(
        c,
        cx,
        fy,
        rx * 1.2,
        ry * 1.5,
        Color(0xFF000000 | _oilAt(h0 + 0.3)),
        0.12 * o,
      );
      // The pool: vertex 0 the centre, then ring by ring outward.
      var k = 0;
      void vert(double ux, double uy, double edge) {
        _slick(ux, uy, t);
        final val = 0.04 + 1.12 * _crest;
        _vx[k] = cx + ux * rx;
        _vy[k] = fy + uy * ry;
        // Black between the bands, so it reads as oil on dark water.
        final lit = _mix(0x050408, _oilAt(_phase), math.min(1.0, val));
        _vc[k] = _argb(
          val > 1 ? _mix(lit, 0xFFFFFF, (val - 1) * 2) : lit,
          0.95 * edge * o,
        );
        k++;
      }

      vert(0, 0, 1);
      for (var ring = 1; ring <= _rings; ring++) {
        final rho = ring / _rings;
        for (var s = 0; s < _segs; s++) {
          final wob = 1 + 0.05 * math.sin(3 * s / _segs * math.pi * 2 + t * 0.4) * rho;
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
      _pool(
        c,
        cx - rx * 0.2,
        fy - ry * 0.62,
        rx * 0.5,
        ry * 0.12,
        const Color(0xFFE8E2FF),
        0.2 * o,
      );
    }

    // Beads of the slick's color rising off it and dissolving, with short
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
      _slick(ux, uy, t);
      final rgb = _mix(_oilAt(_phase), 0xFFFFFF, 0.3);
      final rise = r * (0.55 + 0.4 * _h(i, 65));
      final size = r * 0.085;
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
