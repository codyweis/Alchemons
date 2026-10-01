part of 'alchemy_effect_paint.dart';

/// SPEED FLUX — the speed orb's comet at aura scale: three grain comets whip
/// past the creature on lopsided, tipped paths — in front of it, then behind
/// — each a bright head and a fading tail, and fade out until their next
/// pass. No spokes, no arcs: just the comets.
abstract final class _Speed {
  // Per comet: period, phase, centre offset, half-axes, tip, direction and
  // where its whip starts.
  static const List<double> _p = [1.8, 2.3, 2.9];
  static const List<double> _ph = [0.0, 0.45, 0.2];
  static const List<(double, double)> _off = [
    (0.04, -0.05),
    (-0.06, -0.42),
    (0.0, 0.32),
  ];
  static const List<(double, double)> _axes = [
    (1.12, 0.4),
    (0.9, 0.28),
    (1.2, 0.26),
  ];
  static const List<double> _tilt = [-0.28, 0.22, -0.08];
  static const List<double> _dir = [1, -1, 1];
  static const List<double> _from = [2.67, 0.3, 3.77];

  static const int _tail = 12;

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
    bool front,
  ) {
    final cx = at.dx, cy = at.dy;
    if (!front) {
      _pool(
        c,
        cx,
        cy + r * 0.66,
        r * 0.8,
        r * 0.17,
        dark ? const Color(0xFF59E3FF) : const Color(0xFF0B7FA0),
        (dark ? 0.12 : 0.1) * o,
      );
    }

    _Atlas.clear();
    final head = dark ? 0xEAFDFF : 0x0B7FA0;
    final hot = dark ? 0x59E3FF : 0x0B8FB0;
    final cold = dark ? 0x1A6EA8 : 0x0A4E6E;
    final g = math.max(4.0, r * 0.14);
    for (var j = 0; j < 3; j++) {
      final u = _frac(t / _p[j] + _ph[j]);
      if (u > 0.8) continue;
      final a = u / 0.8;
      final env = math.sin(math.pi * a);
      final th0 = _from[j] + _dir[j] * 2.6 * a;
      final (ox, oy) = _off[j];
      final (ax, ay) = _axes[j];
      final ct = math.cos(_tilt[j]), st = math.sin(_tilt[j]);
      for (var k = 0; k < _tail; k++) {
        final th = th0 - _dir[j] * k * 0.05;
        final sn = math.sin(th);
        // The near side passes in front of the creature.
        if ((sn > 0) != front) continue;
        final ex = math.cos(th) * ax, ey = sn * ay;
        final x = ox + ex * ct - ey * st;
        final y = oy + ex * st + ey * ct;
        final f = 1 - k / _tail;
        final rgb = k == 0 ? head : _mix(hot, cold, k / _tail);
        if (k == 0) {
          // The head's own light round it.
          _Atlas.add(cx + x * r, cy + y * r, g * 3.4, hot, 0.4 * env * o);
        }
        _Atlas.add(
          cx + x * r,
          cy + y * r,
          g * (k == 0 ? 1.7 : 0.4 + 0.9 * f * f),
          rgb,
          env * (0.2 + 0.8 * f) * o,
        );
      }
    }
    _Atlas.draw(c, additive: dark);
  }
}
