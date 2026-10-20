part of 'battle_arena_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE GLASS ORRERY
//
//  A floor of dark leaded glass — irregular shards, mostly smoked and clear,
//  a few coloured — over the works of an orrery: brass rings turning slowly
//  beneath it at their own paces, each carrying a small planet, and a dim
//  sun at the heart, all seen through the glass. (A rose window laid flat
//  read as a dartboard.) The pane under a
//  special lights in its element's colour and fades — the glass is the
//  signal, as in the dungeons. Lead cames between the panes; a bronze rim.
// ─────────────────────────────────────────────────────────────────────────────

/// The few coloured shards: teal, amber, violet, ink blue.
const List<Color> _kOrreryGlass = [
  Color(0xFF1C5A60),
  Color(0xFF6A4A1A),
  Color(0xFF4A2E6E),
  Color(0xFF223C70),
];

/// The rest: smoked, nearly clear.
const Color _orrerySmoke = Color(0xFF1B2731);

const Color _orreryBrass = Color(0xFFB89656);
const Color _orreryLead = Color(0xFF0A0A0C);

class OrreryFloor extends BattleFloor {
  OrreryFloor({required super.rx, required super.ry});

  ui.Picture? _back;
  ui.Picture? _glass;
  ui.Picture? _rim;
  late final List<_OrreryRing> _rings = _makeRings();
  late final List<_Shard> _panes = _makePanes();
  final List<_LitPane> _lit = [];

  @override
  void dispose() {
    for (final p in [_back, _glass, _rim]) {
      p?.dispose();
    }
    _back = _glass = _rim = null;
  }

  @override
  void paint(Canvas canvas, Offset centre, double time, Rect view) {
    canvas.drawRect(view, Paint()..color = _space);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.drawPicture(_back ??= _record(_paintBack));
    _paintWorks(canvas, time);
    canvas.drawPicture(_glass ??= _record(_paintGlass));
    _paintLit(canvas, time);
    canvas.drawPicture(_rim ??= _record(_paintRim));
    canvas.restore();
  }

  ui.Picture _record(void Function(Canvas c) paint) {
    final rec = ui.PictureRecorder();
    paint(Canvas(rec));
    return rec.endRecording();
  }

  // ── under the glass ───────────────────────────────────────────────────────

  void _paintBack(Canvas c) {
    paintStars(c, Random(31));
    BattleFloor.pool(c, Offset.zero, rx * 1.18, ry * 1.14, [
      const Color(0xFF1A1812).withValues(alpha: 0.5),
      const Color(0xFF1A1812).withValues(alpha: 0),
    ], const [0.8, 1.0]);
    // The bowl the works turn in.
    BattleFloor.pool(c, Offset.zero, rx, ry, const [
      Color(0xFF14131A),
      Color(0xFF0B0B10),
      Color(0xFF07070A),
    ], const [0.0, 0.7, 1.0]);
  }

  List<_OrreryRing> _makeRings() {
    final rng = Random(37);
    return [
      for (final (k, w) in [
        (0.22, 0.11),
        (0.38, -0.075),
        (0.54, 0.05),
        (0.70, -0.04),
        (0.85, 0.028),
      ])
        _OrreryRing.make(rng, k: k, speed: w, rx: rx, ry: ry),
    ];
  }

  /// The brass rings, the planets they carry and the sun, turning.
  void _paintWorks(Canvas c, double time) {
    // The sun at the heart, breathing.
    final beat = 0.85 + 0.15 * sin(time * 0.9);
    BattleFloor.pool(c, Offset.zero, 70, 70, [
      const Color(0xFFE2C98F).withValues(alpha: 0.16 * beat),
      const Color(0xFFE2C98F).withValues(alpha: 0),
    ]);
    BattleFloor.pool(c, Offset.zero, 20, 20, [
      const Color(0xFFF1DDAE).withValues(alpha: 0.5 * beat),
      const Color(0xFFB89656).withValues(alpha: 0.15),
      const Color(0xFFB89656).withValues(alpha: 0),
    ], const [0.0, 0.7, 1.0]);
    final dim = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = _orreryBrass.withValues(alpha: 0.34);
    final lit = Paint()
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFE2C98F).withValues(alpha: 0.7);
    for (final ring in _rings) {
      final turn = time * ring.speed;
      // The ring itself: a soft band of brass, not a line of dots.
      _paintBand(c, ring.k);
      c.drawRawPoints(ui.PointMode.points, ring.points(turn, lit: false), dim);
      c.drawRawPoints(ui.PointMode.points, ring.points(turn, lit: true), lit);
      // Its planet, riding the ring.
      final a = ring.planetAt + turn;
      final p = Offset(cos(a) * rx * ring.k, sin(a) * ry * ring.k);
      final r = ring.planetSize;
      BattleFloor.pool(c, p, r * 2.4, r * 2.4, [
        ring.planet.withValues(alpha: 0.22),
        ring.planet.withValues(alpha: 0),
      ]);
      c.drawCircle(
        p,
        r,
        Paint()
          ..shader = ui.Gradient.radial(
            p + Offset(-r * 0.4, -r * 0.45),
            r * 1.4,
            [
              Color.lerp(ring.planet, Colors.white, 0.35)!,
              ring.planet,
              Color.lerp(ring.planet, Colors.black, 0.7)!,
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }
  }

  /// A band of brass at [k] of the radius, about 7 units across, its light
  /// falling off to either side.
  void _paintBand(Canvas c, double k) {
    const width = 7.0;
    final r = rx * k;
    final inner = (r - width) / (r + width);
    c.save();
    c.scale(1, ry / rx);
    c.drawCircle(
      Offset.zero,
      r + width,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          r + width,
          [
            _orreryBrass.withValues(alpha: 0),
            _orreryBrass.withValues(alpha: 0),
            _orreryBrass.withValues(alpha: 0.22),
            _orreryBrass.withValues(alpha: 0),
          ],
          [0.0, inner, (inner + 1) / 2, 1.0],
        ),
    );
    c.restore();
  }

  // ── the glass ─────────────────────────────────────────────────────────────

  /// The shards: irregular cells round sites scattered over the floor,
  /// some merged into larger ones, each a little in from its neighbours so
  /// the lead between them shows. One in five is coloured.
  List<_Shard> _makePanes() {
    final rng = Random(47);
    final sites = <Offset>[];
    const step = 92.0;
    for (var y = -ry - step; y <= ry + step; y += step) {
      for (var x = -rx - step; x <= rx + step; x += step) {
        final p = Offset(
          x + (rng.nextDouble() - 0.5) * step * 0.8,
          y + (rng.nextDouble() - 0.5) * step * 0.8,
        );
        if (!inside(p, 1.12)) continue;
        // Some left out, so their neighbours grow into larger shards.
        if (rng.nextDouble() < 0.22) continue;
        sites.add(p);
      }
    }
    final cells = floorCells(
      sites,
      Rect.fromCenter(center: Offset.zero, width: rx * 2.4, height: ry * 2.4),
    );
    return [
      for (var i = 0; i < sites.length; i++)
        if (cells[i].length >= 3)
          _Shard(
            sites[i],
            insetCell(cells[i], sites[i], 2.6),
            rng.nextDouble() < 0.2
                ? _kOrreryGlass[rng.nextInt(_kOrreryGlass.length)]
                : null,
            rng.nextDouble(),
          ),
    ];
  }

  void _paintGlass(Canvas c) {
    final rng = Random(41);
    final oval = Path()
      ..addOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      );
    c.save();
    c.clipPath(oval);
    // The lead the shards sit in: dark, over the works.
    c.drawPath(oval, Paint()..color = _orreryLead.withValues(alpha: 0.5));
    for (final shard in _panes) {
      final b = shard.path.getBounds();
      final tint = shard.tint;
      // Smoked and nearly clear, or coloured; lit a little from the upper
      // left.
      final base = tint ?? _orrerySmoke;
      final alpha = tint == null ? 0.20 + shard.grain * 0.08 : 0.34;
      c.drawPath(
        shard.path,
        Paint()
          ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [
            Color.lerp(base, const Color(0xFFB7C9D8), 0.18)!
                .withValues(alpha: alpha * 0.8),
            base.withValues(alpha: alpha),
          ]),
      );
    }
    // Seeds and specks in the glass, and one long sheen.
    final paint = Paint();
    for (var i = 0; i < 220; i++) {
      final p = Offset(
        (rng.nextDouble() * 2 - 1) * rx,
        (rng.nextDouble() * 2 - 1) * ry,
      );
      if (!inside(p, 0.97)) continue;
      paint.color = const Color(0xFFDCE6EE).withValues(
        alpha: 0.03 + rng.nextDouble() * 0.06,
      );
      c.drawCircle(p, 0.5 + rng.nextDouble() * 0.8, paint);
    }
    BattleFloor.pool(c, Offset(-rx * 0.35, -ry * 0.42), rx * 0.75, ry * 0.5, [
      const Color(0xFFBFD2E2).withValues(alpha: 0.05),
      const Color(0xFFBFD2E2).withValues(alpha: 0),
    ]);
    c.restore();
  }

  /// The shard under [at] (relative to the centre), or null off the glass.
  _Shard? _paneAt(Offset at) {
    if (!inside(at)) return null;
    _Shard? best;
    var bestD = double.infinity;
    for (final shard in _panes) {
      final d = (shard.site - at).distanceSquared;
      if (d < bestD) {
        bestD = d;
        best = shard;
      }
    }
    return best;
  }

  @override
  void special(Offset at, Color color, double time) {
    final pane = _paneAt(at);
    if (pane == null) return;
    _lit.removeWhere((l) => identical(l.shard, pane));
    _lit.add(_LitPane(pane, color, time, at));
    if (_lit.length > 12) _lit.removeAt(0);
  }

  void _paintLit(Canvas c, double time) {
    _lit.removeWhere((l) => time - l.at > 1.6);
    for (final l in _lit) {
      final age = (time - l.at) / 1.6;
      // Lights at once, then fades slowly.
      final k = age < 0.08 ? age / 0.08 : pow(1 - (age - 0.08) / 0.92, 1.6);
      c.drawPath(
        l.shard.path,
        Paint()..color = l.color.withValues(alpha: 0.42 * k.toDouble()),
      );
      BattleFloor.pool(c, l.where, 60, 60, [
        Color.lerp(l.color, Colors.white, 0.4)!.withValues(
          alpha: 0.3 * k.toDouble(),
        ),
        l.color.withValues(alpha: 0),
      ]);
    }
  }

  // ── the rim ───────────────────────────────────────────────────────────────

  void _paintRim(Canvas c) {
    final rng = Random(43);
    final outer = Path()
      ..addOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: rx * 2 + 34,
          height: ry * 2 + 34,
        ),
      );
    final inner = Path()
      ..addOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      );
    final band = Path.combine(PathOperation.difference, outer, inner);
    c.drawPath(
      band,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(-rx, -ry),
          Offset(rx, ry),
          const [Color(0xFF3A3020), Color(0xFF221C12), Color(0xFF14110B)],
          const [0.0, 0.5, 1.0],
        ),
    );
    // Worn brass: light caught where the band faces the upper left.
    final paint = Paint();
    for (var i = 0; i < 1100; i++) {
      final a = rng.nextDouble() * pi * 2;
      final k = 1.0 + rng.nextDouble() * (17 / ry);
      final p = Offset(cos(a) * (rx + (k - 1) * ry), sin(a) * ry * k);
      final facing = (-cos(a) - sin(a)) / sqrt2;
      final lit = (0.5 + 0.5 * facing).clamp(0.0, 1.0);
      paint.color = Color.lerp(
        const Color(0xFF5A4A30),
        const Color(0xFFE2C98F),
        lit * rng.nextDouble(),
      )!.withValues(alpha: 0.12 + 0.4 * lit * rng.nextDouble());
      c.drawCircle(p, 0.6 + rng.nextDouble() * 1.2, paint);
    }
  }
}

class _OrreryRing {
  _OrreryRing._({
    required this.k,
    required this.speed,
    required this.angles,
    required this.offsets,
    required this.litMask,
    required this.planetAt,
    required this.planetSize,
    required this.planet,
    required this.rx,
    required this.ry,
  });

  /// A ring of brass grains, broken in places, brighter in stretches.
  factory _OrreryRing.make(
    Random rng, {
    required double k,
    required double speed,
    required double rx,
    required double ry,
  }) {
    final around = pi * (rx + ry) * k;
    final n = (around / 2.6).round();
    final angles = <double>[];
    final offsets = <double>[];
    final litMask = <bool>[];
    // Breaks: a few gaps where the ring is open-worked.
    final breaks = [
      for (var i = 0; i < 3 + rng.nextInt(3); i++) rng.nextDouble() * pi * 2,
    ];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2 + (rng.nextDouble() - 0.5) * 0.01;
      var open = false;
      for (final b in breaks) {
        var d = (a - b).abs() % (pi * 2);
        if (d > pi) d = pi * 2 - d;
        if (d < 0.05) open = true;
      }
      if (open) continue;
      angles.add(a);
      offsets.add((rng.nextDouble() - 0.5) * 7);
      litMask.add(sin(a * 3 + k * 9) > 0.35 && rng.nextDouble() < 0.8);
    }
    const planets = [
      Color(0xFF3F7A7E),
      Color(0xFF9A5A3A),
      Color(0xFFCBC3AE),
      Color(0xFF4F6694),
    ];
    return _OrreryRing._(
      k: k,
      speed: speed,
      angles: angles,
      offsets: offsets,
      litMask: litMask,
      planetAt: rng.nextDouble() * pi * 2,
      planetSize: 6 + rng.nextDouble() * 7,
      planet: planets[rng.nextInt(planets.length)],
      rx: rx,
      ry: ry,
    );
  }

  final double k;
  final double speed;
  final List<double> angles;

  /// Each grain's place across the band's width.
  final List<double> offsets;
  final List<bool> litMask;
  final double planetAt;
  final double planetSize;
  final Color planet;
  final double rx;
  final double ry;

  /// The grains turned by [turn]: the lit stretch or the rest.
  Float32List points(double turn, {required bool lit}) {
    final out = <double>[];
    for (var i = 0; i < angles.length; i++) {
      if (litMask[i] != lit) continue;
      final a = angles[i] + turn;
      final w = 1 + offsets[i] / (rx * k);
      out
        ..add(cos(a) * rx * k * w)
        ..add(sin(a) * ry * k * w);
    }
    return Float32List.fromList(out);
  }
}

class _Shard {
  _Shard(this.site, this.path, this.tint, this.grain);
  final Offset site;
  final Path path;

  /// Its colour, or null for smoked glass.
  final Color? tint;

  /// 0..1: its own small difference in shade.
  final double grain;
}

class _LitPane {
  _LitPane(this.shard, this.color, this.at, this.where);
  final _Shard shard;
  final Color color;
  final double at;
  final Offset where;
}
