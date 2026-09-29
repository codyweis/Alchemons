part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  VOLTARA — the Lightning planet: a charged world in its own storm
//
//  The original's mystical electric look, restored at the player's word
//  ("more lightning and more mystical, like before"): a deep electric-blue
//  sphere with a pulsing light at its core, a flickering aura, a haze of
//  charge out to its gravitational reach, bolts striking in toward it from
//  that reach, sparks riding round — the original's four bolts and eight
//  sparks — and under its surface the in-cloud flashes the player liked from
//  the second pass, patches lighting up from inside with a bolt showing
//  through. Lightning keeps real lines (a lit core over a faint wide glow);
//  every other soft shape is a gradient, not a blur pass.
//
//  Tried and cut (2026-09-29): seven bolts and arcs leaping over the limb
//  ("too much lightning"; the arcs read as weird half circles).
// ─────────────────────────────────────────────────────────────────────────────

class LightningPlanetArt extends PlanetArt {
  LightningPlanetArt._(this._bolts, this._storms, this._seed);

  factory LightningPlanetArt(int seed) {
    final rng = Random(seed);
    final bolts = [
      for (var i = 0; i < 4; i++)
        (rng.nextInt(10000).toDouble(), (rng.nextDouble() - 0.5) * 0.6),
    ];
    final storms = Float64List(8 * 3);
    for (var i = 0; i < 8; i++) {
      final (x, y, z) = sphereAt(
        (rng.nextDouble() - 0.5) * 1.8,
        rng.nextDouble() * 2 * pi,
      );
      storms.setAll(i * 3, [x, y, z]);
    }
    return LightningPlanetArt._(bolts, storms, seed);
  }

  static const _col = Color(0xFFFFEB3B);
  static const _body = Color(0xFF1A237E);
  static const _spin = SphereSpin(period: 150);
  static const _white = Color(0xFFFFFFFF);
  static const _flash = Color(0xFFF4F2C8);
  static const _boltGlow = Color(0xFF9FB4FF);

  /// (seed, inward swing) per bolt.
  final List<(double, double)> _bolts;

  final Float64List _storms;
  final int _seed;

  /// A bolt as the original drew it: a faint wide glow under a thin bright
  /// core.
  static void _strike(Canvas c, Path path, double a, {double width = 4}) {
    _softStroke(c, path, _col.withValues(alpha: a * 0.4), width, 6);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 1.5
        ..color = _white.withValues(alpha: a * 0.9),
    );
  }

  @override
  void paintBack(Canvas c, Offset p, double r, double t) {
    _oldAura(c, p, r, _col);
    final gravR = r * 2.2;
    // The haze of charge out to its reach.
    _softCircle(
      c,
      p,
      gravR,
      _col.withValues(alpha: 0.04 + 0.02 * sin(t * 4)),
      gravR * 0.3,
    );

    // Bolts striking in toward it from that reach.
    for (var i = 0; i < _bolts.length; i++) {
      final (seed, swing) = _bolts[i];
      final phase = t * (2.5 + i * 0.7) + seed;
      final flash = sin(phase) * sin(phase * 3.7 + i);
      if (flash <= 0.3) continue;
      final a = ((flash - 0.3) * 1.4).clamp(0.0, 1.0);
      final startAngle =
          (seed * 0.1 + t * 0.15 * (i.isEven ? 1 : -1)) % (pi * 2);
      final reach = gravR * (0.85 + 0.15 * sin(t * 2 + i));
      final start = p + Offset(cos(startAngle), sin(startAngle)) * reach;
      final endAngle = startAngle + swing;
      final end = p + Offset(cos(endAngle), sin(endAngle)) * (r * 1.1);
      final path = Path()..moveTo(start.dx, start.dy);
      final d = end - start;
      final perp = Offset(-d.dy, d.dx) / max(1.0, d.distance);
      const segments = 6;
      for (var s = 1; s <= segments; s++) {
        final mid = start + d * (s / segments);
        final jag = sin(t * 12 + s * 3.0 + i * 7) * r * 0.12;
        final q = s < segments ? mid + perp * jag : mid;
        path.lineTo(q.dx, q.dy);
      }
      _strike(c, path, a);
      _softCircle(
        c,
        start,
        3.0 + 2.0 * a,
        _white.withValues(alpha: a * 0.7),
        4,
      );
    }
  }

  /// How lit storm [i] is at [t]: mostly 0; a flash and a weaker flicker
  /// after it, on its own irregular clock.
  (double, int) _flashAt(int i, double t) {
    final period = 3.5 + (i * 1.7) % 3.5;
    final shifted = t + i * 2.3;
    final cycle = (shifted / period).floor();
    final tau = shifted - cycle * period;
    if (Random(_seed + i * 131 + cycle).nextDouble() < 0.25) return (0, cycle);
    var f = exp(-tau * 16);
    if (tau > 0.13) f += 0.7 * exp(-(tau - 0.13) * 13);
    return (f < 0.02 ? 0.0 : f, cycle);
  }

  @override
  void paintBody(Canvas c, Offset p, double r, double t) {
    final view = SphereView(p, r, _spin.matrixAt(t));
    _oldSphere(c, p, r, _body, highlight: 0.5);

    // In-cloud flashes on the turning surface, a bolt showing through the
    // strong ones.
    c.save();
    _clipDisc(c, p, r);
    for (var i = 0; i < 8; i++) {
      final (f, cycle) = _flashAt(i, t);
      if (f == 0) continue;
      final sp = view.project(
        _storms[i * 3],
        _storms[i * 3 + 1],
        _storms[i * 3 + 2],
      );
      if (sp.depth < 0.05) continue;
      final rr = r * 0.34 * (0.55 + 0.45 * sp.depth);
      c.drawCircle(
        sp.offset,
        rr,
        Paint()
          ..shader = ui.Gradient.radial(
            sp.offset,
            rr,
            [
              _flash.withValues(alpha: 0.7 * f),
              _flash.withValues(alpha: 0.22 * f),
              _flash.withValues(alpha: 0),
            ],
            const [0.0, 0.35, 1.0],
          ),
      );
      if (f > 0.45) _cloudBolt(c, sp.offset, rr * 0.8, f, i * 977 + cycle);
    }
    c.restore();

    // The light at its core, pulsing, and the aura flickering on its skin.
    _softCircle(
      c,
      Offset(p.dx - r * 0.15, p.dy - r * 0.15),
      r * 0.4,
      _white.withValues(alpha: 0.12 + 0.08 * sin(t * 4.5)),
      r * 0.3,
    );
    _softCircle(
      c,
      p,
      r * 1.3,
      _col.withValues(alpha: 0.06 + 0.04 * sin(t * 6)),
      r * 0.25,
    );
  }

  /// A forked bolt seen through the cloud.
  void _cloudBolt(Canvas c, Offset at, double len, double f, int seed) {
    final rng = Random(seed);
    final a = rng.nextDouble() * 2 * pi;
    final main = Path();
    var pt = at - Offset(cos(a), sin(a)) * len * 0.5;
    main.moveTo(pt.dx, pt.dy);
    Offset? fork;
    for (var k = 1; k <= 6; k++) {
      final dir = a + (rng.nextDouble() - 0.5) * 1.1;
      pt += Offset(cos(dir), sin(dir)) * len / 6;
      main.lineTo(pt.dx, pt.dy);
      if (k == 3) fork = pt;
    }
    if (fork != null) {
      var q = fork;
      main.moveTo(q.dx, q.dy);
      for (var k = 0; k < 3; k++) {
        final dir = a + 0.8 + (rng.nextDouble() - 0.5) * 1.0;
        q += Offset(cos(dir), sin(dir)) * len / 8;
        main.lineTo(q.dx, q.dy);
      }
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    c.drawPath(
      main,
      stroke
        ..strokeWidth = len * 0.07
        ..color = _boltGlow.withValues(alpha: 0.28 * f),
    );
    c.drawPath(
      main,
      stroke
        ..strokeWidth = max(0.8, len * 0.018)
        ..color = _white.withValues(alpha: 0.9 * f),
    );
  }

  @override
  void paintFront(Canvas c, Offset p, double r, double t) {
    // Sparks riding round at its reach.
    final gravR = r * 2.2;
    final spark = Paint();
    for (var i = 0; i < 8; i++) {
      final a = t * (0.5 + i * 0.12) + i * pi / 4;
      final dist = gravR * (0.9 + 0.1 * sin(t * 3 + i * 2));
      spark.color = _col.withValues(
        alpha: (0.3 + 0.4 * sin(t * 6 + i * 1.7)).clamp(0.0, 0.7),
      );
      c.drawCircle(
        p + Offset(cos(a), sin(a)) * dist,
        1.5 + sin(t * 4 + i) * 0.5,
        spark,
      );
    }
  }

  @override
  double get cardReach => 1.5;

  @override
  Color get territoryTint => const Color(0xFF3D4CC0);

  /// Loose charge: points that spark and are gone.
  @override
  TerritoryMotes get motes => const TerritoryMotes(
    born: Color(0xFFFFFFFF),
    mid: Color(0xFFFFF59D),
    dying: Color(0xFF8C9CFF),
    motion: MoteMotion.twinkle,
    speed: 0.45,
    size: 1.2,
    perTile: 4,
  );
}
