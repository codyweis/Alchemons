part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CINDRATH — the Dust planet: a big desert world in a dust ring
//
//  Banded sand latitudes, darker rock and dune seas turning with it, and a
//  storm front — a pale veil of lifted dust — travelling faster than the
//  ground under it. Round it, a ring of dust that moves: soft lanes, and
//  hundreds of grains on their orbits over them — inner grains faster than
//  outer, so clumps of them shear out into arcs as they go — twinkling as
//  they turn, the far half behind the planet and the near half across it.
// ─────────────────────────────────────────────────────────────────────────────

class DustPlanetArt extends PlanetArt {
  DustPlanetArt._(this._bands, this._rock, this._storm, this._ring);

  factory DustPlanetArt(int seed) {
    final rng = Random(seed * 37 + 21);
    final unit = unitView(_spin);
    final bands = <(Path, Color)>[];
    const lats = [0.18, 0.46, 0.82];
    const cols = [Color(0x30FFE6BC), Color(0x2A8A5A30), Color(0x38FFEBC8)];
    for (var i = 0; i < lats.length; i++) {
      final n = latitudeCap(
        unit,
        lats[i],
        wave: 0.035,
        waves: 5,
        phase: i * 1.0,
      );
      final s = latitudeCap(
        unit,
        -lats[i] - 0.04,
        south: true,
        wave: 0.035,
        waves: 4,
        phase: i * 2.0,
      );
      if (n != null) bands.add((n, cols[i]));
      if (s != null) bands.add((s, cols[(i + 1) % 3]));
    }
    return DustPlanetArt._(
      bands,
      _BlobField.scatter(
        rng,
        12,
        size: 0.09,
        spread: 2.2,
        stretch: 1.8,
        rough: 0.35,
        soft: 1,
      ),
      _BlobField.scatter(
        rng,
        4,
        size: 0.16,
        spread: 1.0,
        stretch: 2.8,
        rough: 0.35,
        soft: 1,
      ),
      _ParticleRing(
        rng,
        spin: _spin,
        lanes: const [(1.5, 0.11, 3.0), (1.87, 0.17, 4.0), (2.22, 0.1, 1.5)],
        laneColor: const Color(0xFFE8C08A),
        laneReach: 2.6,
        laneStops: const [
          0,
          0.47,
          0.54,
          0.58,
          0.64,
          0.69,
          0.77,
          0.81,
          0.85,
          0.93,
          1.0,
        ],
        laneAlphas: const [
          0,
          0,
          0.12,
          0.2,
          0.1,
          0.24,
          0.2,
          0.05,
          0.13,
          0.04,
          0,
        ],
        dim: const Color(0xFFD8B884).withValues(alpha: 0.55),
        bright: const Color(0xFFFFF0D4).withValues(alpha: 0.9),
      ),
    );
  }

  static const _spin = SphereSpin(period: 260, lean: 0.28);
  static const _stormSpin = SphereSpin(period: 150, lean: 0.28);

  final List<(Path, Color)> _bands;
  final _BlobField _rock;
  final _BlobField _storm;

  final _ParticleRing _ring;

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _halo(c, p, r, const Color(0xFFE0B070), alpha: 0.08, reach: 1.8);
    _ring.paint(c, p, r, t, front: false, wake: wake);
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) =>
      _ring.paint(c, p, r, t, front: true, wake: wake);

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    final storm = SphereView(p, r, _stormSpin.matrixAt(t));
    c.save();
    _clipDisc(c, p, r);
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          p,
          r,
          const [Color(0xFFE6BE88), Color(0xFFC89A64), Color(0xFF8C653C)],
          const [0.0, 0.7, 1.0],
        ),
    );
    for (final (path, col) in _bands) {
      _drawUnit(c, p, r, path, Paint()..color = col);
    }
    final rock = _rock.gather(view);
    c.drawPath(
      rock.shift(Offset(r * 0.012, r * 0.015)),
      Paint()..color = const Color(0xFF6E4424).withValues(alpha: 0.45),
    );
    c.drawPath(rock, Paint()..color = const Color(0xFFA06C40));
    _storm.paint(c, storm, const Color(0xFFF6E2BE), 0.4);
    _sheen(c, p, r, const Color(0xFFFFF0D0), alpha: 0.18);
    _shade(c, p, r, night: const Color(0xFF080503));
    c.restore();
    _limb(
      c,
      p,
      r,
      const Color(0xFFF0C890),
      alpha: 0.26,
      inner: 0.9,
      outer: 1.08,
    );
  }

  @override
  double get cardReach => 2.32;

  @override
  Color get territoryTint => const Color(0xFFC08A48);

  @override
  double get territoryStrength => 0.06;

  /// Grains of dust going round and round.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFF6E2BE),
    mid: Color(0xFFE0B070),
    dying: Color(0xFFA07040),
    motion: MoteMotion.orbit,
    perTile: 4,
    speed: 0.04,
    travel: 260,
    size: 1.1,
    glow: false,
  );
}
