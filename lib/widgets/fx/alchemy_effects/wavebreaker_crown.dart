part of 'alchemy_effect_paint.dart';

/// WAVEBREAKER CROWN — the survival trophy: a three-point crown floating
/// over the creature's head, and five shards of glass — one for each of the
/// five ten-wave gauntlets — drifting lopsidedly about it.
///
/// The crown is filled gold with cyan gems at its points; the shards are
/// amber and cyan glass, each with a lit facet and a catchlight. The old
/// broken rings are gone.
abstract final class _Wavebreaker {
  /// A crown, a unit wide, its base on y = 0.2 and its tallest point at
  /// y = -0.55.
  static final Path _crown = Path()
    ..moveTo(-0.5, 0.2)
    ..lineTo(-0.53, -0.02)
    ..lineTo(-0.36, -0.42)
    ..lineTo(-0.19, -0.06)
    ..lineTo(0, -0.55)
    ..lineTo(0.19, -0.06)
    ..lineTo(0.36, -0.42)
    ..lineTo(0.53, -0.02)
    ..lineTo(0.5, 0.2)
    ..quadraticBezierTo(0, 0.3, -0.5, 0.2)
    ..close();
  static const List<(double, double)> _gems = [
    (-0.36, -0.42),
    (0, -0.55),
    (0.36, -0.42),
  ];
  // Lit from the upper left, a hard step where the light turns the corner:
  // metal, not a flat sticker.
  static final Shader _goldDark = ui.Gradient.linear(
    const Offset(-0.5, -0.55),
    const Offset(0.5, 0.3),
    const [
      Color(0xFFFFF4D0),
      Color(0xFFF0CC78),
      Color(0xFFB8862A),
      Color(0xFF7A5014),
    ],
    const [0.0, 0.42, 0.5, 1.0],
  );
  static final Shader _goldLight = ui.Gradient.linear(
    const Offset(-0.5, -0.55),
    const Offset(0.5, 0.3),
    const [
      Color(0xFFE0B050),
      Color(0xFFC08A28),
      Color(0xFF8A5A14),
      Color(0xFF5A380A),
    ],
    const [0.0, 0.42, 0.5, 1.0],
  );

  /// The cyan inlay along its band.
  static final Path _band = vfxLens(0.9, 0.09, 0.2, 0.2);
  static final Paint _crownPaint = Paint();

  /// A shard pointing up its own axis, and its lit facet.
  static final Path _shard = vfxShard(Offset.zero, 1, 0.38, -math.pi / 2);
  static final Path _facet = Path()
    ..moveTo(0, -1)
    ..lineTo(0.38, 0)
    ..lineTo(0, 0.35)
    ..close();

  // Where the five shards hang, lopsided round the head, and how long each.
  static const List<(double, double)> _at = [
    (-0.7, -0.58),
    (0.66, -0.78),
    (-0.38, -1.2),
    (0.86, -0.34),
    (0.36, -1.26),
  ];
  static const List<double> _len = [0.21, 0.18, 0.17, 0.2, 0.16];

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final cx = at.dx, cy = at.dy;
    const amber = Color(0xFFE4C16A), cyan = Color(0xFF57E7F2);

    // Its light round the crown.
    _pool(
      c,
      cx,
      cy - r * 0.92,
      r * 0.5,
      r * 0.34,
      dark ? amber : const Color(0xFFA8761E),
      (dark ? 0.24 : 0.16) * o,
    );

    _Atlas.clear();
    final glint = math.max(2.8, r * 0.09);

    // ── the shards ──
    for (var k = 0; k < 5; k++) {
      final (bx, by) = _at[k];
      final x = bx + 0.04 * math.sin(t * 0.6 + k * 1.7);
      final y = by + 0.05 * math.sin(t * 0.9 + k * 2.3);
      // Pointing out from the head, turning a little.
      final a = math.atan2(y + 0.7, x) + math.pi / 2 +
          0.22 * math.sin(t * 0.5 + k * 1.1);
      final len = _len[k] * r;
      final px = cx + x * r, py = cy + y * r;
      final isCyan = k.isOdd;
      final body = isCyan
          ? (dark ? cyan : const Color(0xFF1A9AA8))
          : (dark ? amber : const Color(0xFFB8862A));
      final face = isCyan
          ? (dark ? const Color(0xFFCFFBFF) : const Color(0xFF5AD0DC))
          : (dark ? const Color(0xFFFFEDB8) : const Color(0xFFE4C16A));
      final turn = 0.6 + 0.4 * math.cos(t * 0.8 + k * 1.9).abs();
      _shape(c, _shard, px, py, a, len * turn, len, _fade(body, 0.8 * o));
      _shape(c, _facet, px, py, a, len * turn, len, _fade(face, 0.85 * o));
      // A catchlight near its tip, brightest as it turns to face us.
      _Atlas.add(
        px + math.sin(a) * len * 0.55,
        py - math.cos(a) * len * 0.55,
        glint,
        dark ? 0xFFFFFF : _rgb(face),
        (0.35 + 0.6 * (turn - 0.6) / 0.4) * o,
      );
    }

    // ── the crown ──
    final w = r * 0.5;
    final ccx = cx + r * 0.02;
    final ccy = cy - r * 0.9 + r * 0.03 * math.sin(t * 1.3);
    final tilt = 0.05 * math.sin(t * 0.7);
    c.save();
    c.translate(ccx, ccy);
    c.rotate(tilt);
    c.scale(w, w);
    _crownPaint
      ..shader = dark ? _goldDark : _goldLight
      ..color = Color.fromRGBO(0, 0, 0, 0.95 * o);
    c.drawPath(_crown, _crownPaint);
    c.translate(-0.45, 0.13);
    c.drawPath(
      _band,
      _shapePaint
        ..color = (dark ? cyan : const Color(0xFF1A9AA8)).withValues(
          alpha: 0.85 * o,
        ),
    );
    c.restore();
    // Cyan gems at its points.
    final ct = math.cos(tilt), st = math.sin(tilt);
    for (var k = 0; k < 3; k++) {
      final (gx, gy) = _gems[k];
      final shimmer = 0.7 + 0.3 * math.sin(t * 2.2 + k * 2.1);
      _Atlas.add(
        ccx + (gx * ct - gy * st) * w,
        ccy + (gx * st + gy * ct) * w,
        glint * 1.5,
        dark ? 0x9AF4FF : 0x0E7A88,
        shimmer * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
