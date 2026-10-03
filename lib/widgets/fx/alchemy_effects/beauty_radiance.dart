part of 'alchemy_effect_paint.dart';

/// BEAUTY RADIANCE — the beauty orb's signature at aura scale: soft and
/// gentle, glinting often.
///
/// Petals of light drift down past the creature, turning as they fall; now
/// and then a soft glint swells somewhere about it and fades; and a warm
/// rose-and-gold light pools at its feet and blushes behind it. No dial, no
/// spokes, no stars.
abstract final class _Beauty {
  static const int _petals = 10;
  static const int _glints = 6;

  static const List<int> _petalDark = [0xFFB0CC, 0xFF8FB8, 0xFFDFA0];
  static const List<int> _petalLight = [0xD9487F, 0xC23A6C, 0xC08A30];

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    double o,
    bool dark,
  ) {
    final cx = at.dx, cy = at.dy;
    final rose = dark ? const Color(0xFFFF8FB8) : const Color(0xFFC8507A);
    final gold = dark ? const Color(0xFFFFD58A) : const Color(0xFFC08A30);
    final breathe = 0.5 + 0.5 * math.sin(t * 1.3);

    _pool(
      c,
      cx,
      cy - r * 0.12,
      r * 0.95,
      r * 0.9,
      rose,
      (0.1 + 0.04 * breathe) * o,
    );
    _pool(c, cx, cy + r * 0.66, r * 0.82, r * 0.19, rose, 0.28 * o);
    _pool(c, cx + r * 0.05, cy + r * 0.66, r * 0.4, r * 0.09, gold, 0.22 * o);

    _Atlas.clear();
    // ── petals of light, drifting down and turning ──
    final petal = math.max(6.0, r * 0.25);
    final tones = dark ? _petalDark : _petalLight;
    for (var i = 0; i < _petals; i++) {
      final p = 5.5 + 2.5 * _h(i, 101);
      final u = _frac(t / p + _h(i, 102));
      final side = i.isEven ? -1.0 : 1.0;
      final x =
          side * (0.38 + 0.55 * _h(i, 103)) +
          0.14 * math.sin(u * 5 + _h(i, 104) * 6.28);
      final y = -1.1 + 1.72 * u;
      final env = _smooth(0.0, 0.1, u) * (1 - _smooth(0.82, 1.0, u));
      final spin = (i.isEven ? 1 : -1) * (0.8 + 0.6 * _h(i, 105));
      _Atlas.add(
        cx + x * r,
        cy + y * r,
        petal * (0.8 + 0.4 * _h(i, 106)),
        tones[i % tones.length],
        (dark ? 0.95 : 0.85) * env * o,
        cell: _Atlas.petal,
        rot: _h(i, 107) * 6.28 + t * spin,
      );
    }
    // ── soft glints, each swelling somewhere new and fading ──
    for (var k = 0; k < _glints; k++) {
      final p = 2.2 + 1.0 * _h(k, 108);
      final phase = t / p + _h(k, 109);
      final s = _frac(phase);
      if (s > 0.2) continue;
      final amp = math.pow(math.sin(math.pi * s / 0.2), 2).toDouble();
      final cyc = phase.floor();
      final a = _h(k * 17 + cyc, 110) * math.pi * 2;
      final rr = 0.55 + 0.55 * _h(k * 17 + cyc, 111);
      _Atlas.add(
        cx + math.cos(a) * rr * 0.95 * r,
        cy - r * 0.1 + math.sin(a) * rr * 0.9 * r,
        r * 0.36 * amp,
        dark ? 0xFFF0F6 : 0xD9487F,
        o,
      );
    }
    _Atlas.draw(c, additive: dark);
  }
}
