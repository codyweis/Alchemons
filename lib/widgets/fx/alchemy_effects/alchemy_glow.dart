part of 'alchemy_effect_paint.dart';

/// ALCHEMICAL RESONANCE — the plainest effect: the creature gives off a soft
/// amber light, as a brew does.
///
/// It breathes on a slow ~3 s swell with a small range (it used to pulse
/// 0.4 → 1.2 every second, which strobed), in the game's amber and parchment
/// with a cool undertone from the old cyan, a little light on the ground,
/// and a few motes rising through it.
abstract final class _Resonance {
  static const double _period = 3.2;

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final cx = at.dx, cy = at.dy;
    final breathe = 0.5 + 0.5 * math.sin(t * math.pi * 2 / _period);
    final s = 0.95 + 0.07 * breathe;
    final amber = dark ? const Color(0xFFE8A04A) : const Color(0xFFB06A14);
    final core = dark ? const Color(0xFFFFD98A) : const Color(0xFFC98A2A);

    // A cool undertone, off-centre: the old effect's cyan, kept faint.
    _pool(
      c,
      cx + r * 0.12,
      cy + r * 0.08,
      r * 1.0,
      r * 0.95,
      dark ? const Color(0xFF5FB4C8) : const Color(0xFF2F7484),
      (dark ? 0.08 : 0.07) * o,
    );
    _pool(
      c,
      cx,
      cy - r * 0.05,
      r * 1.22 * s,
      r * 1.15 * s,
      amber,
      (0.2 + 0.08 * breathe) * o,
    );
    _pool(
      c,
      cx - r * 0.04,
      cy - r * 0.08,
      r * 0.72 * s,
      r * 0.68 * s,
      core,
      (0.16 + 0.08 * breathe) * o,
    );
    _pool(
      c,
      cx,
      cy + r * 0.66,
      r * 0.72,
      r * 0.16,
      amber,
      (0.18 + 0.06 * breathe) * o,
    );

    // A few motes rising slowly through the light.
    _Atlas.clear();
    final mote = dark ? 0xFFE0A0 : 0xA86418;
    for (var i = 0; i < 7; i++) {
      final p = 4.5 + 2.0 * _h(i, 51);
      final u = _frac(t / p + _h(i, 52));
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.42 + 0.34 * _h(i, 53)) +
          0.06 * math.sin(t * 0.8 + i * 1.9);
      final y = 0.45 - 1.4 * u;
      final env = math.sin(math.pi * u);
      _Atlas.add(
        cx + x * r,
        cy + y * r,
        math.max(3.0, r * 0.11),
        mote,
        (dark ? 0.7 : 0.6) * env * o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
