part of 'keepsake_art.dart';

// The home's Silverlite (models/home_decor.dart): liquid metal as the
// Quicksilver aura draws it (liquid_metal.dart) — a drop over a dish, two
// drops that become one and part again, and a fountain whose column swells
// into a ball and falls back. Dark stone round one luminous thing, as the
// rest of the decor is; the metal dims with the night, its highlight kept.
// (User 2026-10-22: "i really like the animation of the quicksilver blobs".)

/// The stone the quicksilver is held in: cold and dark.
const Color _mercuryStone = Color(0xFF9AA8C0);

/// The fine silver grains the metal goes back up as.
const Color _mercuryGrain = Color(0xFFDCE4EE);

/// How much the metal dims by night.
double _mercuryDim(KeepsakeTime k) => 0.38 * k.night;

final Paint _mercuryPaint = Paint()..isAntiAlias = true;

/// A pool of the metal lying flat, as a mirror lying flat gives the world
/// back: its far half the sky, a hard horizon, the dark of the ground,
/// lightening toward the near edge. Unit-sized, stretched onto each pool.
final ui.Shader _mercurySurface = ui.Gradient.linear(
  const Offset(0, -1),
  const Offset(0, 1),
  const [
    Color(0xFFF2F5FA),
    Color(0xFFC4CDD9),
    Color(0xFF8C97A6),
    Color(0xFF2C323C),
    Color(0xFF20252D),
    Color(0xFF5E6876),
    Color(0xFFB4BECB),
  ],
  const [0.0, 0.18, 0.4, 0.47, 0.7, 0.9, 1.0],
);

/// A ripple's near and far halves, at unit radius: filled crescents, no
/// hoop.
final Path _mercuryRippleNear = vfxCrescent(
  Offset.zero,
  1,
  0.11,
  math.pi / 2,
  math.pi * 1.5,
);
final Path _mercuryRippleFar = vfxCrescent(
  Offset.zero,
  1,
  0.08,
  -math.pi / 2,
  math.pi * 0.9,
);

/// The metal's flat face, [rx] by [ry] round [at], with light running over
/// it: glints of sky across its dark middle, each across in a few seconds
/// and fading at either end, and its far edge bright.
void _mercuryPool(
  Canvas c,
  Offset at,
  double rx,
  double ry,
  KeepsakeTime k, {
  int glints = 3,
}) {
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(rx, ry);
  _mercuryPaint
    ..shader = _mercurySurface
    ..color = const Color(0xFF000000);
  c.drawCircle(Offset.zero, 1, _mercuryPaint);
  c.clipPath(LiquidMetal.unit);
  _mercuryPaint.shader = null;
  for (var i = 0; i < glints; i++) {
    final f = (k.t / (2.8 + 1.2 * _hash(i, 71)) + _hash(i, 72)) % 1;
    final fade = math.sin(math.pi * f);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(
          (i.isEven ? 1 : -1) * (-1.5 + 3 * f),
          -0.16 + i * 0.22 + 0.05 * math.sin(k.t * 2.3 + i),
        ),
        width: (0.7 - i * 0.08) * (0.75 + 0.25 * math.sin(k.t * 3.1 + i)),
        height: 0.12,
      ),
      _mercuryPaint
        ..color = Color.fromRGBO(240, 245, 252, (0.8 - i * 0.12) * fade),
    );
  }
  final dim = _mercuryDim(k);
  if (dim > 0.004) {
    _mercuryPaint.color = Color.fromRGBO(6, 8, 14, dim);
    c.drawCircle(Offset.zero, 1, _mercuryPaint);
  }
  c.restore();
}

/// A ripple on the metal at [at], [g] of the way through (0..1),
/// spreading to [reach] and fading.
void _mercuryRipple(Canvas c, Offset at, double reach, double g) {
  if (g <= 0 || g >= 1) return;
  final fade = (1 - g) * (1 - g);
  final rr = reach * (0.15 + 0.85 * g);
  c.save();
  c.translate(at.dx, at.dy);
  c.scale(rr, rr * 0.18);
  _mercuryPaint
    ..shader = null
    ..color = Color.fromRGBO(235, 242, 250, 0.55 * fade);
  c.drawPath(_mercuryRippleNear, _mercuryPaint);
  _mercuryPaint.color = Color.fromRGBO(235, 242, 250, 0.32 * fade);
  c.drawPath(_mercuryRippleFar, _mercuryPaint);
  c.restore();
}

/// A ball of the metal [rad] round at [at] at [t]: its skin moving, a drip
/// [sag]ging from it, squashed by [shake], its reflection sloshing (turning
/// by [slosh] of its swing).
void _mercuryBall(
  Canvas c,
  Offset at,
  double rad,
  KeepsakeTime k, {
  double sag = 0,
  double width = 0.7,
  double shake = 0,
  double phase = 0,
  double slosh = 1,
}) {
  final t = k.t + phase;
  final tilt = 0.25 * slosh * math.sin(t * 1.1);
  final lift = 0.08 * math.sin(t * 1.9);
  LiquidMetal.skin(
    t,
    sag: sag,
    width: width,
    shake: shake,
    tilt: tilt,
    lift: lift,
    waves: 1 + 0.8 * k.stir.clamp(0.0, 1.0),
  );
  LiquidMetal.paint(
    c,
    at,
    rad,
    LiquidMetal.plain,
    LiquidMetal.seen,
    tilt: tilt,
    lift: lift,
    dim: _mercuryDim(k),
  );
}

// ── Silverlite Drop (Curio) ───────────────────────────────────────────────

/// A ball of liquid silver over a dark dish. A drip swells on it, draws out
/// and pinches off; the drop falls into the dish, which takes it in with a
/// ripple and throws up a bead or two; and the metal goes back up to the
/// ball as fine grains.
class _SilverliteDrop extends KeepsakeArt {
  _SilverliteDrop() : super(_mercuryStone);

  /// The ball's size and where its middle hangs; the dish's face.
  static const double _rad = 18, _hang = -104, _face = -16;

  /// Seconds between drips; where in one it lets go; how long it falls.
  static const double _period = 3.4, _pinch = 0.62, _fall = 0.36;

  /// How far below the ball's middle the bulb hangs as it lets go, and its
  /// size then, in the ball's radii.
  static const double _letGo = 1.85, _bulb = 0.3;

  final List<_Grains> _rise = [for (var i = 0; i < 3; i++) _Grains(12)];

  @override
  Rect get box => const Rect.fromLTRB(-44, -134, 44, 6);

  @override
  void body(Canvas c) {
    // A wide, shallow dish of dark stone sitting on the ground.
    final open = Path()
      ..addOval(
        Rect.fromCenter(center: const Offset(0, _face), width: 76, height: 13),
      );
    _solid(c, open, Color.lerp(m.ink, const Color(0xFF000000), 0.4)!);
    final dish = Path()
      ..moveTo(-38, _face)
      ..quadraticBezierTo(-33, 0, 0, 0)
      ..quadraticBezierTo(33, 0, 38, _face)
      ..arcTo(
        Rect.fromCenter(center: const Offset(0, _face), width: 76, height: 13),
        0,
        math.pi,
        false,
      )
      ..close();
    _solid(c, dish, m.ink);
    _shade(c, dish, _litAcross(m, -38, 38, k: 0.55));
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 46, 0.18 + 0.2 * k.night);

  @override
  void live(Canvas c, KeepsakeTime k) {
    final by = _hang + 3 * math.sin(k.t * 1.9);
    final cyc = k.t / _period;
    final now = cyc.floor();
    final u = cyc - now;

    // The metal in the dish, and what the drops do there.
    _mercuryPool(c, const Offset(0, _face), 33, 5, k, glints: 2);
    for (var back = 0; back < 2; back++) {
      final n = now - back;
      final s = k.t - (n + _pinch) * _period - _fall;
      if (s < 0) continue;
      _mercuryRipple(c, const Offset(0, _face), 32, s / 0.7);
      // A bead or two thrown up, landing on the metal and rolling home.
      for (var j = 0; j < 2; j++) {
        final side = (_hash(n * 2 + j, 41) - 0.5) * 2;
        final out = 10 + 16 * _hash(n * 2 + j, 42);
        final double x, lift, size;
        if (s < 0.3) {
          final g = s / 0.3;
          x = side * out * g;
          lift = 14 * 4 * g * (1 - g);
          size = 2.6;
        } else {
          final g = ((s - 0.3) / 0.9).clamp(0.0, 1.0);
          x = side * out * (1 - g * g);
          lift = 0;
          size = 2.6 * (1 - _smooth(0.75, 1.0, g));
        }
        if (size > 0.3) {
          LiquidMetal.sphere(
            c,
            Offset(x, _face - 1.5 - lift),
            size,
            dim: _mercuryDim(k),
          );
        }
      }
    }
    // The metal going back up to the ball as fine grains, each on an arc
    // of its own bowed out to one side, so they never stand in a column,
    // and fading in and out (three depths of light, one pass each).
    for (final b in _rise) {
      b.clear();
    }
    final topY = by + _rad * 0.6, footY = _face - 2;
    for (var i = 0; i < 9; i++) {
      final f = (k.t / (2.2 + 0.8 * _hash(i, 51)) + _hash(i, 52)) % 1;
      final x0 = (_hash(i, 53) - 0.5) * 30;
      final bow = (12 + 14 * _hash(i, 54)) * (i.isEven ? 1 : -1);
      final e = 1 - f;
      final light = math.sin(math.pi * f);
      _rise[light < 0.4 ? 0 : (light < 0.75 ? 1 : 2)].add(
        x0 * e * e + (x0 + bow) * 2 * e * f,
        footY * e * e + (footY + topY) * e * f + topY * f * f,
      );
    }
    for (var b = 0; b < 3; b++) {
      _rise[b].draw(c, 1.7, _a(_mercuryGrain, 0.22 + 0.24 * b));
    }

    // The drop falling, quickening, a faint trail above it.
    final since = k.t - (now + _pinch) * _period;
    final falling = since >= 0 && since < _fall
        ? since
        : k.t - (now - 1 + _pinch) * _period;
    if (falling >= 0 && falling < _fall) {
      final y0 = by + _rad * _letGo;
      for (var j = 2; j >= 0; j--) {
        final g = (falling / _fall - j * 0.06).clamp(0.0, 1.0);
        LiquidMetal.sphere(
          c,
          Offset(0, y0 + (_face - 2 - y0) * g * g),
          _rad * _bulb * (1 - j * 0.25),
          opacity: 1 - j * 0.35,
          dim: _mercuryDim(k),
        );
      }
    }

    // The drip, then the ball over its top: the underside sagging, drawn
    // out into a neck with the bulb coming out below it, letting go, and
    // the ball jiggling back round.
    double sag, width, shake, bulbAt = 0, bulb = 0;
    if (u < 0.45) {
      final g = _smooth(0.0, 0.45, u);
      sag = 0.4 * g;
      width = 0.95 - 0.25 * g;
      shake = 0;
    } else if (u < _pinch) {
      final p = _smooth(0.45, _pinch, u);
      sag = 0.4 + 0.2 * p;
      width = 0.7 - 0.5 * p;
      shake = -0.04 * p;
      bulb = 0.34 - (0.34 - _bulb) * p;
      bulbAt = 1.06 + (_letGo - 1.06) * p;
    } else {
      final s = (u - _pinch) * _period;
      sag = 0.6 * math.exp(-9 * s) * math.cos(15 * s);
      width = 0.2 + 0.5 * _smooth(0.0, 0.3, s);
      shake = -0.04 * math.exp(-4 * s) * math.cos(14 * s);
    }
    if (bulb > 0) {
      LiquidMetal.sphere(
        c,
        Offset(0, by + _rad * bulbAt),
        _rad * bulb,
        dim: _mercuryDim(k),
      );
    }
    _mercuryBall(
      c,
      Offset(0, by),
      _rad,
      k,
      sag: sag,
      width: width,
      shake: shake,
    );
  }
}

// ── Twin Drops (Living) ────────────────────────────────────────────────────

/// Two balls of liquid silver hanging in the air on nothing, only their
/// light on the ground under them (user 2026-10-22: "remove the base"),
/// drifting together: they touch, run into one another and are one ball,
/// which wobbles and settles; then it draws out long, necks and parts, each
/// snapping round as it goes.
///
/// While they touch they are one outline: along every ray from between
/// them, each ball's edge, the two blended smoothly (the cube root of the
/// sum of their cubes) — pinched to nothing as they first touch, and at the
/// last exactly one ball with the metal of both. Each half is lit about its
/// own ball's middle, so the light runs on unbroken across the join.
class _TwinDrops extends KeepsakeArt {
  _TwinDrops() : super(_mercuryStone);

  /// Each ball's size, where they hang, and seconds from one parting to
  /// the next.
  static const double _rad = 15, _hang = -112, _period = 9.0;

  static const int _n = 72;
  static final Float64List _xs = Float64List(_n), _ys = Float64List(_n);
  static final Path _one = Path();
  static final Path _clip = Path();

  @override
  Rect get box => const Rect.fromLTRB(-72, -146, 72, 6);

  @override
  void body(Canvas c) {}

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 64, 0.18 + 0.2 * k.night);

  /// How far along a ray at [cos], [sin] from between them it is to the
  /// edge of the ball whose middle is [cx] along (in its radii; it holds
  /// the start of the ray).
  static double _edge(double cx, double cos, double sin) =>
      cx * cos + math.sqrt(math.max(0.0, 1 - cx * cx * sin * sin));

  /// The two as one outline, [d] apart (at most 2, touching), in the balls'
  /// radii round the point between them: its skin moving at [t], squashed
  /// by [shake].
  static Path _joined(double d, double t, double shake) {
    for (var i = 0; i < _n; i++) {
      final a = i / _n * math.pi * 2;
      final co = math.cos(a), si = math.sin(a);
      final ra = _edge(-d / 2, co, si), rb = _edge(d / 2, co, si);
      var r = math.pow(ra * ra * ra + rb * rb * rb, 1 / 3).toDouble();
      r *=
          1 +
          0.04 * math.sin(2 * a + t * 1.7) +
          0.025 * math.sin(3 * a - t * 2.3 + 1) +
          shake * math.cos(2 * a);
      _xs[i] = co * r;
      _ys[i] = si * r;
    }
    _one
      ..reset()
      ..moveTo((_xs[_n - 1] + _xs[0]) / 2, (_ys[_n - 1] + _ys[0]) / 2);
    for (var i = 0; i < _n; i++) {
      final j = (i + 1) % _n;
      _one.quadraticBezierTo(
        _xs[i],
        _ys[i],
        (_xs[i] + _xs[j]) / 2,
        (_ys[i] + _ys[j]) / 2,
      );
    }
    return _one..close();
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final u = (k.t / _period) % 1;
    final mid = Offset(0, _hang + 3 * math.sin(k.t * 1.3));
    final dim = _mercuryDim(k);
    final lift = 0.08 * math.sin(k.t * 1.9);

    // How far apart they are (in their radii; 2 is touching, 0 is one),
    // and how the metal is squashed.
    final double d;
    double shake = 0;
    if (u < 0.3) {
      d = 3.4 - 1.4 * _smooth(0.0, 0.3, u);
      shake = 0.06 * _smooth(0.2, 0.3, u);
    } else if (u < 0.42) {
      d = 2 * (1 - _smooth(0.3, 0.42, u));
    } else if (u < 0.66) {
      final s = (u - 0.42) * _period;
      d = 0;
      shake = 0.12 * math.exp(-2.5 * s) * math.cos(9 * s);
    } else if (u < 0.84) {
      final p = (u - 0.66) / 0.18;
      d = 2 * p * p;
    } else {
      final s = (u - 0.84) * _period;
      d = 2.0 + 1.4 * _smooth(0.84, 1.0, u);
      shake = 0.12 * math.exp(-4 * s) * math.cos(14 * s);
    }

    if (d >= 2) {
      for (var side = -1; side <= 1; side += 2) {
        _mercuryBall(
          c,
          mid + Offset(side * d / 2 * _rad, 0),
          _rad,
          k,
          shake: shake,
          // Their reflections stop turning as they meet, so the two halves
          // of the one they make give back the same sky.
          slosh: _smooth(2.0, 2.8, d),
        );
      }
      return;
    }

    // Joined: one outline, each half lit about its own ball's middle — a
    // ball growing to hold the metal of both as they become one.
    final grow = 1 + 0.26 * (1 - d / 2);
    final joined = _joined(d, k.t, shake);
    for (var side = -1; side <= 1; side += 2) {
      c.save();
      c.translate(mid.dx, mid.dy);
      c.scale(_rad);
      _clip
        ..reset()
        ..addRect(
          side < 0
              ? const Rect.fromLTRB(-4, -4, 0, 4)
              : const Rect.fromLTRB(0, -4, 4, 4),
        );
      c.clipPath(joined);
      c.clipPath(_clip);
      c.translate(side * d / 2, 0);
      c.scale(grow);
      LiquidMetal.shade(c, lift: lift, dim: dim);
      c.restore();
    }
    for (var side = -1; side <= 1; side += 2) {
      LiquidMetal.shine(
        c,
        mid + Offset(side * d / 2 * _rad, 0),
        _rad * grow,
        lift: lift,
        opacity: 0.5 + 0.5 * d / 2,
      );
    }
  }
}

// ── Silverlite Fountain (Wonder) ──────────────────────────────────────────

/// A basin of liquid silver. A dome swells out of its middle and rises as a
/// column with a ball on top, the ball lets go and hangs, wobbling, then
/// falls back in: the metal takes it with ripples and throws up drops that
/// land on it as beads and roll home.
class _SilverliteFountain extends KeepsakeArt {
  _SilverliteFountain() : super(_mercuryStone);

  /// The metal's face: its middle, and how far across and deep it is.
  static const Offset _face = Offset(0, -40);
  static const double _rx = 96, _ry = 13;

  /// Seconds from one rise to the next.
  static const double _period = 4.6;

  /// The ball at the top: its size, and how high it hangs.
  static const double _rad = 24, _top = -178;

  static final Path _column = Path();

  @override
  Rect get box => const Rect.fromLTRB(-118, -214, 118, 6);

  @override
  void body(Canvas c) {
    _block(c, m, const Rect.fromLTRB(-46, -8, 46, 0), bevel: 2.4);
    final rim = Rect.fromCenter(center: _face, width: 208, height: 32);
    _solid(
      c,
      Path()..addOval(rim),
      Color.lerp(m.ink, const Color(0xFF000000), 0.4)!,
    );
    final bowl = Path()
      ..moveTo(-104, _face.dy)
      ..quadraticBezierTo(-92, -8, 0, -9)
      ..quadraticBezierTo(92, -8, 104, _face.dy)
      ..arcTo(rim, 0, math.pi, false)
      ..close();
    _solid(c, bowl, m.ink);
    _shade(c, bowl, _litAcross(m, -104, 104, k: 0.55));
  }

  @override
  void under(Canvas c, KeepsakeTime k) =>
      _groundPool(c, m, 0, 140, 0.18 + 0.2 * k.night);

  /// A column of the metal from the face up to [topY], [foot] round where
  /// it leaves the face, [head] round where it meets the ball, [waist] round
  /// at its narrowest — in the ball's units round [mid].
  Path _columnAt(
    Offset mid,
    double footY,
    double topY,
    double foot,
    double head,
    double waist,
  ) {
    final my = (footY + topY) / 2;
    final ctl = 2 * waist - (foot + head) / 2;
    Offset u(double x, double y) =>
        Offset((x - mid.dx) / _rad, (y - mid.dy) / _rad);
    final a = u(-foot, footY), b = u(-head, topY);
    final cl = u(-ctl, my), cr = u(ctl, my);
    final d = u(head, topY), e = u(foot, footY);
    return _column
      ..reset()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(cl.dx, cl.dy, b.dx, b.dy)
      ..lineTo(d.dx, d.dy)
      ..quadraticBezierTo(cr.dx, cr.dy, e.dx, e.dy)
      ..close();
  }

  @override
  void live(Canvas c, KeepsakeTime k) {
    final dim = _mercuryDim(k);
    final cyc = k.t / _period;
    final now = cyc.floor();
    final u = cyc - now;
    _mercuryPool(c, _face, _rx, _ry, k);

    // Where the ball is, how big, and the column under it.
    double? ballY;
    double ball = _rad, shake = 0;
    double colTop = _face.dy, colHead = 0, colFoot = 0, waist = 0;
    if (u < 0.14) {
      // A dome swelling out of the middle.
      final g = _smooth(0.0, 0.14, u);
      ball = 15 * g;
      ballY = _face.dy - ball * 0.55;
    } else if (u < 0.52) {
      // Rising on its column, the ball growing on top.
      final p = 1 - math.pow(1 - (u - 0.14) / 0.38, 2).toDouble();
      ball = 15 + (_rad - 15) * p;
      ballY = _face.dy - ball * 0.55 + (_top - _face.dy + ball * 0.55) * p;
      colTop = ballY + ball * 0.7;
      colHead = ball * 0.55;
      colFoot = 13;
      waist = 7 - 3 * p;
    } else if (u < 0.68) {
      // Let go: the column falls back in under it; it rises a little
      // further, slows, and hangs there, wobbling.
      final s = (u - 0.52) * _period;
      final g = _smooth(0.52, 0.6, u);
      ballY = _top - 10 * (1 - math.pow(1 - (u - 0.52) / 0.16, 2).toDouble());
      shake = 0.14 * math.exp(-3 * s) * math.cos(12 * s);
      final top0 = _top + _rad * 0.7;
      colTop = top0 + (_face.dy - top0) * g;
      colHead = _rad * 0.5 * (1 - g);
      colFoot = 13 * (1 - g);
      waist = 4 * (1 - g);
    } else if (u < 0.8) {
      // Falling back, quickening, drawn a little long.
      final g = (u - 0.68) / 0.12;
      ballY = _top - 10 + (_face.dy - _top + 10) * g * g;
      shake = -0.08 * g;
    }
    // Where it fell: ripples, and drops thrown up that land as beads and
    // roll home.
    for (var back = 0; back < 2; back++) {
      final n = now - back;
      final s = k.t - (n + 0.8) * _period;
      if (s < 0) continue;
      _mercuryRipple(c, _face, _rx * 0.95, s / 1.1);
      _mercuryRipple(c, _face, _rx * 0.7, (s - 0.25) / 0.9);
      for (var j = 0; j < 6; j++) {
        final a = _hash(n * 6 + j, 61) * math.pi * 2;
        final out = 0.35 + 0.5 * _hash(n * 6 + j, 62);
        final size = 2.6 + 2 * _hash(n * 6 + j, 63);
        final double r, lift;
        double grow = 1;
        if (s < 0.5) {
          final g = s / 0.5;
          r = out * g;
          lift = (24 + 20 * _hash(n * 6 + j, 64)) * 4 * g * (1 - g);
        } else {
          final g = ((s - 0.5) / 1.4).clamp(0.0, 1.0);
          r = out * (1 - g * g);
          lift = 0;
          grow = 1 - _smooth(0.8, 1.0, g);
        }
        if (grow <= 0) continue;
        LiquidMetal.sphere(
          c,
          _face +
              Offset(
                math.cos(a) * _rx * r,
                math.sin(a) * _ry * r - lift - size * 0.4,
              ),
          size * grow,
          dim: dim,
        );
      }
      // The ball sinking back into the face as it lands.
      if (s < 0.3) {
        final g = 1 - s / 0.3;
        c.save();
        c.clipRect(Rect.fromLTRB(-_rx, -400, _rx, _face.dy));
        LiquidMetal.sphere(c, _face, _rad * 0.85 * g, dim: dim);
        c.restore();
      }
    }

    if (colHead > 0.5) {
      final mid = Offset(0, (colTop + _face.dy) / 2);
      final col = _columnAt(mid, _face.dy + 2, colTop, colFoot, colHead, waist);
      LiquidMetal.paint(
        c,
        mid,
        _rad,
        col,
        col,
        dim: dim,
        round: false,
        shine: false,
      );
    }
    if (ballY != null && ball > 0.5) {
      final rising = u < 0.14;
      if (rising) {
        c.save();
        c.clipRect(Rect.fromLTRB(-_rx, -400, _rx, _face.dy));
      }
      _mercuryBall(c, Offset(0, ballY), ball, k, shake: shake);
      if (rising) c.restore();
    }
  }
}
