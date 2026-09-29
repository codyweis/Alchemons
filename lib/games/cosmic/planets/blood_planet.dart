part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  HEMAVORN — the Blood planet: made of it
//
//  Packed all over with blood cells — crisp discs, each with the dimple at
//  its heart and a shadow under its edge, the planet's outline lumpy with
//  them — in a deep plasma. It has a heartbeat: every couple of seconds —
//  lub, dub — the cells flush brighter and the air round it swells.
//
//  Tried and cut (2026-09-28): a glossy crimson sea with soft currents and
//  clots (read as blurry, and as a plain red ball).
// ─────────────────────────────────────────────────────────────────────────────

class BloodPlanetArt extends PlanetArt {
  BloodPlanetArt._(this._cells, this._dimples);

  factory BloodPlanetArt(int seed) {
    final rng = Random(seed * 71 + 53);
    final cells = <Float64List>[], dimples = <Float64List>[];
    final sizes = <double>[];
    for (var i = 0; i < 150; i++) {
      final (x, y, z) = sphereAt(
        asin(rng.nextDouble() * 2 - 1),
        rng.nextDouble() * 2 * pi,
      );
      final size = 0.04 + rng.nextDouble() * 0.028;
      final shape = rng.nextInt(1 << 30);
      sizes.add(size);
      cells.add(
        sphereBlob(x, y, z, size, Random(shape), rough: 0.07, sides: 18),
      );
      dimples.add(
        sphereBlob(x, y, z, size * 0.46, Random(shape), rough: 0.07, sides: 14),
      );
    }
    return BloodPlanetArt._(
      _BlobField._(cells, const [], sizes),
      _BlobField._(dimples, const [], const []),
    );
  }

  static const _spin = SphereSpin(period: 200);
  static const _cell = Color(0xFFB0202C);
  static const _flush = Color(0xFFE23A44);
  static const _dimple = Color(0xFF780E1A);

  final _BlobField _cells;
  final _BlobField _dimples;

  /// Lub-dub, every 1.8 seconds: 0 at rest, ~1 on the first beat.
  static double _beat(double t) {
    final tau = t % 1.8;
    double bump(double at, double w) =>
        exp(-((tau - at) / w) * ((tau - at) / w));
    return bump(0.08, 0.07) + 0.6 * bump(0.36, 0.08);
  }

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    final beat = _beat(t);
    _halo(
      c,
      p,
      r,
      const Color(0xFFD32F2F),
      alpha: 0.1 + 0.06 * beat,
      reach: 1.9 + 0.1 * beat,
    );
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    final beat = _beat(t);
    c.drawPath(
      _cells.limbBumps(view, scale: 0.55),
      Paint()..color = const Color(0xFF5A0A12),
    );
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          const [Color(0xFF5E0A14), Color(0xFF44060E), Color(0xFF260308)],
          const [0.0, 0.7, 1.0],
        ),
    );
    final cells = _cells.gather(view);
    c.drawPath(
      cells.shift(Offset(r * 0.012, r * 0.016)),
      Paint()..color = const Color(0xFF1A0205).withValues(alpha: 0.8),
    );
    c.drawPath(cells, Paint()..color = Color.lerp(_cell, _flush, 0.45 * beat)!);
    c.drawPath(
      _dimples.gather(view),
      Paint()..color = Color.lerp(_dimple, _cell, 0.3 * beat)!,
    );
    _shade(c, p, r, night: const Color(0xFF0A0204));
    c.restore();
    _limb(
      c,
      p,
      r,
      const Color(0xFFFF5A5A),
      alpha: 0.16 + 0.1 * beat,
      inner: 0.95,
      outer: 1.05,
    );
  }

  @override
  Color get territoryTint => const Color(0xFFA0141E);

  /// Drops of it, adrift.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFE04046),
    mid: Color(0xFFB0202A),
    dying: Color(0xFF5A0A12),
    shape: MoteShape.drop,
    speed: 0.035,
    travel: 150,
    size: 2.0,
  );
}
