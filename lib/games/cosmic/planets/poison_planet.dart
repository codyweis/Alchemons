part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  TOXIVYRE — the Poison planet: a foaming brew
//
//  A violet froth: bubbles of every size packed over the whole sphere, each
//  crisp, each with a glint on its lit side and a shadow on the other, the
//  outline of the planet bubbly with them. Among them float bubbles of
//  something acid-green that make their own light, so on the night side
//  they are all you see; and some of those swell and pop.
//
//  Tried and cut (2026-09-28): violet haze veils with soft glowing acid
//  lakes (read as blurry).
// ─────────────────────────────────────────────────────────────────────────────

class PoisonPlanetArt extends PlanetArt {
  PoisonPlanetArt._(this._froth, this._small, this._acid, this._popping);

  factory PoisonPlanetArt(int seed) {
    final rng = Random(seed * 53 + 37);
    final popping = Float64List(10 * 3);
    for (var i = 0; i < 10; i++) {
      final (x, y, z) = sphereAt(
        asin(rng.nextDouble() * 2 - 1),
        rng.nextDouble() * 2 * pi,
      );
      popping.setAll(i * 3, [x, y, z]);
    }
    return PoisonPlanetArt._(
      _BlobField.scatter(rng, 110, size: 0.06, rough: 0.06, soft: 1,
          uniform: true),
      _BlobField.scatter(rng, 120, size: 0.028, rough: 0.05, soft: 1,
          uniform: true),
      _BlobField.scatter(rng, 16, size: 0.045, rough: 0.05, soft: 1,
          uniform: true),
      popping,
    );
  }

  static const _spin = SphereSpin(period: 180);
  static const _acidCol = Color(0xFF8CFF4E);

  final _BlobField _froth;
  final _BlobField _small;
  final _BlobField _acid;
  final Float64List _popping;

  /// A glint on each bubble of [field] facing us, on its lit side.
  static Path _glints(SphereView view, _BlobField field, {double k = 1}) {
    final path = Path();
    final cs = field.centres;
    final r = view.radius;
    for (var i = 0; i < field.sizes.length; i++) {
      final sp = view.project(cs[i * 3], cs[i * 3 + 1], cs[i * 3 + 2]);
      if (sp.depth < 0.25) continue;
      final br = r * field.sizes[i] * sp.depth * k;
      path.addOval(Rect.fromCircle(
        center: sp.offset + Offset(-br * 0.42, -br * 0.45),
        radius: br * 0.24,
      ));
    }
    return path;
  }

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF9C27B0), alpha: 0.12, reach: 2.0);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    c.drawPath(_froth.limbBumps(view, scale: 0.6),
        Paint()..color = const Color(0xFF3A1450));
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, const [
          Color(0xFF3E1452),
          Color(0xFF2A0C3A),
          Color(0xFF16061F),
        ], const [0.0, 0.7, 1.0]),
    );
    final shadow = Offset(r * 0.014, r * 0.018);
    for (final (field, col) in [
      (_froth, const Color(0xFF6E2C8E)),
      (_small, const Color(0xFF8A40A8)),
    ]) {
      final path = field.gather(view);
      c.drawPath(path.shift(shadow),
          Paint()..color = const Color(0xFF12041A).withValues(alpha: 0.7));
      c.drawPath(path, Paint()..color = col);
    }
    final glint = Paint()..color = const Color(0xFFE2B8F6).withValues(alpha: 0.8);
    c.drawPath(_glints(view, _froth), glint);
    c.drawPath(_glints(view, _small), glint);
    _shade(c, p, r, night: const Color(0xFF07020A));

    // The acid, above the night: it makes its own light.
    final breathe = 0.85 + 0.15 * sin(t * 0.8);
    c.drawPath(_acid.gather(view),
        Paint()..color = _acidCol.withValues(alpha: 0.9 * breathe));
    c.drawPath(_glints(view, _acid, k: 1.1),
        Paint()..color = const Color(0xFFE6FFD0).withValues(alpha: 0.85));
    final pop = Paint();
    for (var i = 0; i < _popping.length ~/ 3; i++) {
      final sp = view.project(
        _popping[i * 3],
        _popping[i * 3 + 1],
        _popping[i * 3 + 2],
      );
      if (sp.depth < 0.15) continue;
      final period = 3.2 + (i % 3) * 0.8;
      final life = ((t + i * 0.91) % period) / period;
      if (life > 0.7) continue;
      final br = r * 0.035 * sqrt(life / 0.7) * sp.depth;
      pop.color = _acidCol.withValues(alpha: 0.85);
      c.drawCircle(sp.offset, br, pop);
      pop.color = const Color(0xFFE6FFD0).withValues(alpha: 0.8);
      c.drawCircle(sp.offset + Offset(-br * 0.4, -br * 0.4), br * 0.26, pop);
    }
    c.restore();
    _limb(c, p, r, const Color(0xFFA6FF70), alpha: 0.16, inner: 0.95,
        outer: 1.05);
  }

  @override
  Color get territoryTint => const Color(0xFF7A1E96);

  /// Spores and loose bubbles, drifting.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFC4FF8A),
    mid: Color(0xFF7CE04A),
    dying: Color(0xFF6A2A80),
    shape: MoteShape.bubble,
    speed: 0.04,
    travel: 140,
    size: 2.2,
  );
}
