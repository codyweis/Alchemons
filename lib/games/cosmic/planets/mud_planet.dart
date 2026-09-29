part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MIREHOLM — the Mud planet: a heaving swamp
//
//  Its surface is mud heaped into domes, packed close: each a crisp mound
//  casting a little shadow, each with its own wet highlight on the side
//  toward the light — dozens of small glints, which is what makes it read
//  as wet rather than as rock. Bubbles swell among them and pop, and the
//  domes on the limb make the outline lumpy.
//
//  Tried and cut (2026-09-28): soft swirls of silt under one broad gloss
//  (read as blurry).
// ─────────────────────────────────────────────────────────────────────────────

class MudPlanetArt extends PlanetArt {
  MudPlanetArt._(this._domes, this._pools, this._bubbles);

  factory MudPlanetArt(int seed) {
    final rng = Random(seed * 31 + 17);
    final bubbles = Float64List(14 * 3);
    for (var i = 0; i < 14; i++) {
      final (x, y, z) = sphereAt(
        asin(rng.nextDouble() * 2 - 1),
        rng.nextDouble() * 2 * pi,
      );
      bubbles.setAll(i * 3, [x, y, z]);
    }
    return MudPlanetArt._(
      _BlobField.scatter(rng, 150, size: 0.055, rough: 0.2, soft: 1,
          uniform: true),
      _BlobField.scatter(rng, 9, size: 0.08, rough: 0.35, soft: 1,
          stretch: 1.4),
      bubbles,
    );
  }

  static const _spin = SphereSpin(period: 240);

  static const _dome = Color(0xFF6A5438);
  static const _deep = Color(0xFF2A1F14);
  static const _wet = Color(0xFFD8C498);

  final _BlobField _domes;
  final _BlobField _pools;
  final Float64List _bubbles;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFF6A5A30), alpha: 0.07, reach: 1.8);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    c.drawPath(_domes.limbBumps(view, scale: 0.5),
        Paint()..color = const Color(0xFF2E2317));
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(p, r, const [
          Color(0xFF3E3022),
          Color(0xFF2E2318),
          Color(0xFF1C150E),
        ], const [0.0, 0.7, 1.0]),
    );
    c.drawPath(_pools.gather(view), Paint()..color = const Color(0xFF4A4A30));

    final domes = _domes.gather(view);
    c.drawPath(domes.shift(Offset(r * 0.014, r * 0.018)),
        Paint()..color = _deep.withValues(alpha: 0.8));
    c.drawPath(domes, Paint()..color = _dome);

    // A wet glint on every dome facing us, on its side toward the light.
    final glints = Path();
    final cs = _domes.centres;
    for (var i = 0; i < _domes.sizes.length; i++) {
      final sp = view.project(cs[i * 3], cs[i * 3 + 1], cs[i * 3 + 2]);
      if (sp.depth < 0.2) continue;
      final dr = r * _domes.sizes[i] * sp.depth;
      glints.addOval(Rect.fromCenter(
        center: sp.offset + Offset(-dr * 0.38, -dr * 0.42),
        width: dr * 0.55,
        height: dr * 0.38,
      ));
    }
    c.drawPath(glints, Paint()..color = _wet.withValues(alpha: 0.75));

    // Bubbles: swell for a few seconds, then pop and are gone a while.
    final dome = Paint();
    for (var i = 0; i < _bubbles.length ~/ 3; i++) {
      final sp = view.project(
        _bubbles[i * 3],
        _bubbles[i * 3 + 1],
        _bubbles[i * 3 + 2],
      );
      if (sp.depth < 0.15) continue;
      final period = 4.0 + (i % 4) * 0.9;
      final life = ((t + i * 1.37) % period) / period;
      if (life > 0.75) continue;
      final br = r * 0.04 * sqrt(life / 0.75) * sp.depth;
      dome.color = const Color(0xFF6E5A3C);
      c.drawCircle(sp.offset, br, dome);
      dome.color = const Color(0xFFE8D8B0).withValues(alpha: 0.7);
      c.drawCircle(sp.offset + Offset(-br * 0.35, -br * 0.38), br * 0.3, dome);
    }

    _shade(c, p, r, night: const Color(0xFF050402));
    c.restore();
    _limb(c, p, r, const Color(0xFF8A7A50), alpha: 0.14, inner: 0.95,
        outer: 1.05);
  }

  @override
  Color get territoryTint => const Color(0xFF6A5A2E);

  @override
  double get territoryStrength => 0.065;

  /// Clods of mud, turning slowly.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFF8A7050),
    mid: Color(0xFF5D4630),
    dying: Color(0xFF2E2216),
    shape: MoteShape.pebble,
    speed: 0.025,
    travel: 120,
    size: 2.6,
    spin: 0.35,
  );
}
