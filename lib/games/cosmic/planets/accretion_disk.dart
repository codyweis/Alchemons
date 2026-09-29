part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AN ACCRETION DISK — matter wheeling round something that is eating it
//
//  Nythralor's disk, made reusable (the home planet's Black Hole wears one
//  too): hundreds of motes in a flattened disk, the inner ones running fast
//  and burning white-violet, the outer slow and deep purple; streams
//  spiralling in and going out at the edge; a hot glow at the inner rim,
//  behind whatever the disk surrounds. The near half passes in front, the
//  far half behind. Motes part round the ship as it flies through. Batched:
//  positions once a frame for both halves, a few point draws for all of it.
// ─────────────────────────────────────────────────────────────────────────────

class _AccretionDisk {
  _AccretionDisk(
    Random rng, {
    int motes = 700,
    int infall = 90,
    this.inner = 1.18,
    this.outer = 2.83,
    this.speed = 0.55,
    this.flat = 0.35,
    this.grain = 1.0,
    this.lensed = false,
  }) : _disk = [
         for (var i = 0; i < motes; i++)
           (
             inner + (outer - inner) * pow(rng.nextDouble(), 1.3),
             rng.nextDouble() * 2 * pi,
             0.5 + rng.nextDouble() * 0.9,
             rng.nextDouble() * 2 * pi,
           ),
       ],
       _infall = [
         for (var i = 0; i < infall; i++)
           (
             inner + (outer - inner) * (0.45 + rng.nextDouble() * 0.55),
             rng.nextDouble() * 2 * pi,
             4.0 + rng.nextDouble() * 4.0,
             rng.nextDouble(),
           ),
       ];

  /// Where the disk starts and ends, in radii of what it surrounds.
  final double inner, outer;

  /// Orbital speed at one radius.
  final double speed;

  /// How flat the disk is seen (1 is face-on).
  final double flat;

  /// Mote size, as a multiple of Nythralor's.
  final double grain;

  /// Whether the far half is also seen bent up over the top of what the
  /// disk surrounds (and faintly under the bottom), the way light from
  /// behind a black hole comes round it.
  final bool lensed;

  /// Matter by heat, hottest (innermost) first.
  static const heat = [
    Color(0xFFF2E2FF),
    Color(0xFFC88CFA),
    Color(0xFF8E58E0),
    Color(0xFF5A2CA8),
  ];

  /// (radius, angle, size, twinkle phase).
  final List<(double, double, double, double)> _disk;

  /// Infalling streams: (start radius, angle, fall time, phase).
  final List<(double, double, double, double)> _infall;

  int _heatOf(double rad) {
    final f = (rad - inner) / (outer - inner);
    return f < 0.14 ? 0 : (f < 0.38 ? 1 : (f < 0.68 ? 2 : 3));
  }

  final _DotBatch _behind = _DotBatch(8);
  final _DotBatch _ahead = _DotBatch(8);
  final _DotBatch _bent = _DotBatch(8);
  double _preparedT = double.nan;
  Offset _preparedP = Offset.zero;
  double _preparedR = 0;
  Offset? _preparedWake;

  void _prepare(Offset p, double r, double t, Offset? wake) {
    if (t == _preparedT &&
        p == _preparedP &&
        r == _preparedR &&
        wake == _preparedWake) {
      return;
    }
    _preparedT = t;
    _preparedP = p;
    _preparedR = r;
    _preparedWake = wake;
    _behind.clear();
    _ahead.clear();
    _bent.clear();
    final reach = max(170.0, r * 0.7);
    void add(double rad, double a, double size) {
      final sy = sin(a);
      final cx = cos(a);
      var x = p.dx + cx * rad * r;
      var y = p.dy + sy * rad * r * flat;
      // The ship flying through parts the matter round it.
      final push = _wakePush(x, y, wake, reach, reach * 0.45);
      x += push.dx;
      y += push.dy;
      final bucket = _heatOf(rad) * 2 + (size > 0.95 ? 1 : 0);
      (sy > 0 ? _ahead : _behind).add(bucket, x, y);
      if (!lensed) return;
      // The bent image: the far half arched over the top, hugging the
      // body at the crown and opening out to meet the disk at the sides;
      // the near half, fainter and tighter, under the bottom.
      final f = (rad - inner) / (outer - inner);
      final open = pow(cx.abs(), 4).toDouble();
      final far = sy < 0;
      final hug = r * (far ? 1.07 + 0.34 * f : 1.03 + 0.14 * f);
      final bend = hug + (rad * r - hug) * open;
      final th = cx * pi / 2;
      _bent.add(
        bucket.clamp(0, 7),
        p.dx + sin(th) * bend,
        p.dy + (far ? -1 : 1) * cos(th) * bend,
      );
    }

    // In orbit: inner matter much faster than outer.
    for (final (rad, a0, size, ph) in _disk) {
      final a = a0 + t * speed / (rad * sqrt(rad));
      add(rad, a, size * (0.75 + 0.25 * sin(t * 2.4 + ph)));
    }
    // Falling in: a spiral inward, gone at the edge.
    final edge = inner * 0.87;
    for (final (r0, a0, fall, ph) in _infall) {
      final life = (t / fall + ph) % 1.0;
      final fade = (life < 0.15 ? life / 0.15 : 1.0) * (1 - pow(life, 6));
      if (fade < 0.3) continue;
      add(r0 - (r0 - edge) * pow(life, 1.4), a0 + life * 3.2, 0.9 * fade);
    }
  }

  /// The hot glow at the inner rim, in the disk's plane. Behind only.
  void paintGlow(Canvas c, Offset p, double r, double t, {double alpha = 0.3}) {
    final pulse = 0.85 + 0.15 * sin(t * 0.9);
    final reach = r * (inner + 0.72);
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, flat);
    c.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          reach,
          [
            const Color(0xFFE8C8FF).withValues(alpha: 0),
            const Color(0xFFE8C8FF).withValues(alpha: alpha * pulse),
            const Color(0xFFA070F0).withValues(alpha: alpha * 0.45 * pulse),
            const Color(0xFF6A3AB8).withValues(alpha: 0),
          ],
          [
            (inner - 0.25) / (inner + 0.72),
            (inner - 0.16) / (inner + 0.72),
            (inner + 0.17) / (inner + 0.72),
            1.0,
          ],
        ),
    );
    c.restore();
  }

  /// The matter on one side: the near half ([front]) or the far half.
  void paintMatter(
    Canvas c,
    Offset p,
    double r,
    double t, {
    required bool front,
    Offset? wake,
  }) {
    _prepare(p, r, t, wake);
    final batch = front ? _ahead : _behind;
    for (var k = heat.length - 1; k >= 0; k--) {
      for (var sz = 0; sz < 2; sz++) {
        final b = k * 2 + sz;
        final d = r * 0.0055 * (sz == 0 ? 0.7 : 1.15) * 2 * grain;
        batch.draw(
          c,
          b,
          d * 2.2,
          heat[k].withValues(alpha: 0.06 + 0.02 * (3 - k)),
        );
        batch.draw(c, b, d, heat[k].withValues(alpha: 0.85 - k * 0.12));
      }
    }
  }

  /// The bent image of the disk round what it surrounds — only for a
  /// [lensed] disk, drawn after the body so it rims it.
  void paintLensed(Canvas c, Offset p, double r, double t, {Offset? wake}) {
    if (!lensed) return;
    _prepare(p, r, t, wake);
    // The light it is made of, a soft band round the body.
    final band = r * (inner + 0.2);
    c.drawCircle(
      p,
      band,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          band,
          [
            const Color(0xFFE8C8FF).withValues(alpha: 0),
            const Color(0xFFE8C8FF).withValues(alpha: 0.22),
            const Color(0xFFA070F0).withValues(alpha: 0.08),
            const Color(0xFF6A3AB8).withValues(alpha: 0),
          ],
          [0.9 / (inner + 0.2), 1.06 / (inner + 0.2), 1.2 / (inner + 0.2), 1.0],
        ),
    );
    for (var k = heat.length - 1; k >= 0; k--) {
      for (var sz = 0; sz < 2; sz++) {
        final b = k * 2 + sz;
        final d = r * 0.0055 * (sz == 0 ? 0.7 : 1.15) * 1.6 * grain;
        _bent.draw(
          c,
          b,
          d * 2.4,
          heat[k].withValues(alpha: 0.05 + 0.02 * (3 - k)),
        );
        _bent.draw(c, b, d, heat[k].withValues(alpha: 0.7 - k * 0.12));
      }
    }
  }
}
