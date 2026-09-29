part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ZEPHYRIA — the Air planet: an ethereal wind sphere
//
//  The original, restored at the player's word ("I liked the old one
//  better"): a translucent sky-blue sphere in a wide faint halo, soft wind
//  bands drifting across its face in alternate directions, and zephyr
//  motes riding round it. Its blurred shapes are gradients and
//  layered strokes of the same softness now — the look, without a blur pass
//  per shape per frame.
//
//  Tried and cut (2026-09-28/29): crisp shearing streaks, then crisp wind
//  ribbons (both "looks bad"); the original's curling wind-streak lines off
//  the limb, its cyclone-eye spiral and ribbon-shaped territory wisps (all
//  "cheesy").
// ─────────────────────────────────────────────────────────────────────────────

class AirPlanetArt extends PlanetArt {
  AirPlanetArt._(this._bands, this._motes);

  factory AirPlanetArt(int seed) {
    // Consumed in the original's order.
    final rng = Random(seed);
    final bands = [
      for (var i = 0; i < 7; i++)
        (0.8 + rng.nextDouble() * 0.6, 0.15 + rng.nextDouble() * 0.1),
    ];
    final motes = [
      for (var i = 0; i < 10; i++)
        (0.4 + rng.nextDouble() * 0.3, 1.5 + rng.nextDouble() * 1.5),
    ];
    return AirPlanetArt._(bands, motes);
  }

  static const _col = Color(0xFF81D4FA);

  /// (drift speed, width in radii) per band.
  final List<(double, double)> _bands;

  /// (orbit speed, size) per mote.
  final List<(double, double)> _motes;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _col);
    _softCircle(
      c,
      p,
      r * 2.5,
      _col.withValues(alpha: 0.04 + 0.02 * sin(t * 0.4)),
      r * 1.2,
    );
    _softCircle(
      c,
      p,
      r * 1.8,
      _col.withValues(alpha: 0.06 + 0.02 * sin(t * 0.7)),
      r * 0.6,
    );
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    _oldSphere(c, p, r, _col, highlight: 0.5, shadow: 0.15);
    c.save();
    _clipDisc(c, p, r);

    // Wind bands drifting across, alternate ones the other way.
    for (var i = 0; i < 7; i++) {
      final (speed, width) = _bands[i];
      final bandY = p.dy - r + (i + 0.5) * (2 * r / 7);
      final drift = t * speed * (i.isEven ? 1 : -1);
      final waveAmp = r * 0.08 * sin(t * 1.2 + i * 1.1);
      final bandWidth = r * width;
      double y(double frac) =>
          bandY +
          sin(frac * pi * 3 + drift) * waveAmp +
          cos(frac * pi * 2 + drift * 0.7) * waveAmp * 0.5;
      final spine = Path();
      for (var s = 0; s <= 20; s++) {
        final frac = s / 20.0;
        final x = p.dx - r * 1.1 + frac * r * 2.2;
        s == 0 ? spine.moveTo(x, y(frac)) : spine.lineTo(x, y(frac));
      }
      final alpha = (0.06 + 0.03 * sin(t * 0.9 + i)).clamp(0.0, 1.0);
      // A soft band: the blurred fill of the original, as layered strokes
      // down its middle.
      final band = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      c.drawPath(
        spine,
        band
          ..strokeWidth = bandWidth * 2.2
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.35),
      );
      c.drawPath(
        spine,
        band
          ..strokeWidth = bandWidth * 1.2
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.55),
      );
      c.drawPath(
        spine,
        band
          ..strokeWidth = bandWidth * 0.5
          ..color = const Color(0xFFFFFFFF).withValues(alpha: alpha * 0.6),
      );
    }

    c.restore();
    // A soft luminous rim of air.
    _limb(
      c,
      p,
      r,
      const Color(0xFFE2F5FF),
      alpha: 0.3,
      inner: 0.86,
      outer: 1.1,
    );
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) {
    // Zephyr motes riding the wind.
    for (var i = 0; i < 10; i++) {
      final (speed, size) = _motes[i];
      final orbitR = r * (1.1 + 0.3 * sin(i * 1.7));
      final a = t * speed * (i.isEven ? 1 : -1) + i * pi * 2 / 10;
      final bob = sin(t * 2.0 + i * 0.9) * r * 0.1;
      final at = Offset(
        p.dx + cos(a) * orbitR,
        p.dy + sin(a) * orbitR * 0.35 + bob,
      );
      final alpha = (0.3 + 0.2 * sin(t * 3 + i)).clamp(0.0, 1.0);
      _softCircle(
        c,
        at,
        size * 3,
        _col.withValues(alpha: alpha * 0.2),
        size * 2,
      );
      c.drawCircle(
        at,
        size,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
  }

  @override
  double get cardReach => 1.6;

  @override
  Color get territoryTint => const Color(0xFF5AAAD8);

  @override
  double get territoryStrength => 0.06;

  /// Faint motes of pale air, carried round it.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFFFFFFF),
    mid: Color(0xFFD2EEFA),
    dying: Color(0xFF81D4FA),
    motion: MoteMotion.orbit,
    speed: 0.05,
    travel: 260,
    size: 1.3,
    alpha: 0.55,
  );
}
