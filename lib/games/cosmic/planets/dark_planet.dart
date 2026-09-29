part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NYTHRALOR — the Dark planet: a black hole, feeding
//
//  The original the player preferred — a black core, a thin violet edge, a
//  flattened accretion disk of layered violets, all in the purple glow every
//  planet used to wear — with the disk brought to life the way Cindrath's
//  ring was: matter in orbit, hundreds of glowing motes, the inner ones
//  running fast and burning white-violet, the outer slow and deep purple,
//  the near half of the disk passing in front of the hole and the far half
//  behind it. And some of it is falling: streams spiralling in, brightening
//  as they heat, and going out at the edge of the black.
//
//  Tried and cut (2026-09-28/29): an implied void with star smears and a
//  broken one-sided glow ("disconnected"), and an obsidian sphere with a
//  ring (not a black hole).
// ─────────────────────────────────────────────────────────────────────────────

class DarkPlanetArt extends PlanetArt {
  DarkPlanetArt._(this._disk);

  factory DarkPlanetArt(int seed) =>
      DarkPlanetArt._(_AccretionDisk(Random(seed * 61 + 43)));

  static const _col = Color(0xFF4A148C);
  static const _deepPurple = Color(0xFF673AB7);

  final _AccretionDisk _disk;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _col);
    // The accretion disk's glow, as it always was.
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, _disk.flat);
    for (var i = 3; i >= 0; i--) {
      c.drawCircle(
        Offset.zero,
        r * (1.8 + i * 0.3),
        Paint()
          ..color = Color.lerp(_col, _deepPurple, i * 0.2)!
              .withValues(alpha: 0.08 + 0.03 * sin(t * 1.5 + i)),
      );
    }
    c.restore();
    _disk.paintGlow(c, p, r, t);
    _disk.paintMatter(c, p, r, t, front: false, wake: wake);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    c.drawCircle(p, r, Paint()..color = const Color(0xFF0A0010));
    c.drawCircle(
      p,
      r + 2,
      Paint()
        ..color = _col.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  /// Only the matter crosses in front of the hole — its glow stays behind,
  /// so the black stays black.
  @override
  void paintFront(Canvas c, Offset p, double r, double t) =>
      _disk.paintMatter(c, p, r, t, front: true, wake: wake);

  @override
  double get cardReach => 2.2;

  /// Space itself darkens here: the wash is black, and strong.
  @override
  Color get territoryTint => const Color(0xFF000000);

  @override
  double get territoryStrength => 0.4;

  /// What is left of the light, drawn in and turning as it goes.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFB08AF0),
    mid: Color(0xFF7A4AC8),
    dying: Color(0xFF2A1050),
    motion: MoteMotion.inward,
    speed: 0.04,
    travel: 280,
    size: 1.3,
    alpha: 0.75,
  );
}
