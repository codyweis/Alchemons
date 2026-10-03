part of 'alchemy_effect_paint.dart';

/// GOLDEN RITE — the Pureblood Rite's mark: a gold alchemical sigil lying
/// flat on the ground under the creature, turning slowly, with gold dust
/// rising off it.
///
/// The sigil is filled glyph work — three tapered arcs broken by the
/// element glyphs, a triangle of tapered strokes inside, a sun at its heart —
/// not stroked rings, and foreshortened onto the ground rather than standing
/// behind the creature like a clock face. It is one prebuilt path, so it
/// costs one draw however much is in it.
abstract final class _GoldenRite {
  /// The sigil at unit radius.
  static final Path _sigil = _buildSigil();

  static Path _buildSigil() {
    final p = Path();
    const gaps = [-math.pi / 2, math.pi / 6, math.pi * 5 / 6];
    // The circle: three arcs tapering into the gaps where the glyphs sit.
    for (var k = 0; k < 3; k++) {
      p.addPath(
        vfxCrescent(Offset.zero, 0.95, 0.085, gaps[k] + math.pi / 3, 1.58),
        Offset.zero,
      );
    }
    // A finer inner circle, broken the other way.
    for (var k = 0; k < 3; k++) {
      p.addPath(
        vfxCrescent(Offset.zero, 0.78, 0.04, gaps[k], 1.2),
        Offset.zero,
      );
    }
    // The glyphs: fire's triangle, the moon, earth's diamond.
    final fire = vfxPolar(gaps[0], 0.95);
    p.addPath(
      Path()
        ..moveTo(fire.dx, fire.dy - 0.11)
        ..lineTo(fire.dx + 0.1, fire.dy + 0.07)
        ..lineTo(fire.dx - 0.1, fire.dy + 0.07)
        ..close(),
      Offset.zero,
    );
    p.addPath(
      vfxCrescent(vfxPolar(gaps[1], 0.95), 0.085, 0.055, gaps[1], 2.8),
      Offset.zero,
    );
    p.addPath(
      vfxShard(vfxPolar(gaps[2], 0.95), 0.1, 0.07, gaps[2]),
      Offset.zero,
    );
    // The triangle inside: tapered strokes between three points.
    for (var k = 0; k < 3; k++) {
      final a = vfxPolar(gaps[k], 0.66);
      final b = vfxPolar(gaps[(k + 1) % 3], 0.66);
      final d = b - a;
      final len = d.distance;
      final ang = math.atan2(d.dy, d.dx);
      final cs = math.cos(ang), sn = math.sin(ang);
      p.addPath(
        vfxLens(len, 0.06, len * 0.3, len * 0.3),
        Offset.zero,
        matrix4: Float64List.fromList([
          cs, sn, 0, 0, //
          -sn, cs, 0, 0,
          0, 0, 1, 0,
          a.dx, a.dy, 0, 1,
        ]),
      );
    }
    // The sun at its heart, and three seeds on the triangle's sides.
    p.addOval(Rect.fromCircle(center: Offset.zero, radius: 0.1));
    for (var k = 0; k < 3; k++) {
      p.addOval(
        Rect.fromCircle(
          center: vfxPolar(gaps[k] + math.pi, 0.33),
          radius: 0.04,
        ),
      );
    }
    return p;
  }

  static final Shader _goldDark = _gold(
    const Color(0xFFFFEBB0),
    const Color(0xFFE6AE40),
    const Color(0xFFB07818),
  );
  static final Shader _goldLight = _gold(
    const Color(0xFFD49A28),
    const Color(0xFF9A6812),
    const Color(0xFF6A420A),
  );
  static Shader _gold(Color a, Color b, Color c) =>
      ui.Gradient.radial(Offset.zero, 1, [a, b, c], const [0.0, 0.6, 1.0]);
  static final Paint _sigilPaint = Paint();

  static const int _motes = 24;

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final cx = at.dx, fy = at.dy + r * 0.64;
    final big = r * 0.98;
    const squash = 0.3;
    final shine = 0.8 + 0.2 * math.sin(t * 1.1);

    // Its light on the ground.
    final glow = dark ? const Color(0xFFF0B848) : const Color(0xFFB07818);
    _pool(c, cx, fy, big * 1.15, big * squash * 1.3, glow, 0.28 * o);
    _pool(c, cx, fy, big * 0.5, big * squash * 0.55, glow, 0.22 * o);

    // The sigil: turning in the ground's plane, then laid flat.
    c.save();
    c.translate(cx, fy);
    c.scale(big, big * squash);
    c.rotate(t * 0.12);
    _sigilPaint
      ..shader = dark ? _goldDark : _goldLight
      ..color = Color.fromRGBO(0, 0, 0, shine * o);
    c.drawPath(_sigil, _sigilPaint);
    c.restore();

    // Gold dust rising off it.
    _Atlas.clear();
    final size = math.max(2.8, r * 0.085);
    for (var i = 0; i < _motes; i++) {
      final p = 3.0 + 2.0 * _h(i, 81);
      final u = _frac(t / p + _h(i, 82));
      final rho = math.sqrt(_h(i, 83)) * 0.95;
      final phi = _h(i, 84) * math.pi * 2;
      final x = math.cos(phi) * rho * big + math.sin(t * 0.9 + i) * r * 0.04;
      final y =
          fy +
          math.sin(phi) * rho * big * squash -
          (0.45 + 0.6 * _h(i, 85)) * r * u;
      final env = _smooth(0.0, 0.12, u) * (1 - _smooth(0.6, 1.0, u));
      final flare = _frac(t * 0.5 + _h(i, 86) * 7) < 0.05;
      _Atlas.add(
        cx + x,
        y,
        size * (flare ? 1.6 : 1.0),
        flare
            ? (dark ? 0xFFF6DC : 0xB07818)
            : (dark ? (i.isEven ? 0xFFE08A : 0xF5C04A) : 0xA06A10),
        env * (dark ? 0.9 : 0.8) * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
