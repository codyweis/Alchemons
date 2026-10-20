part of 'battle_arena_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE MOONLIT GARDEN
//
//  A sunken garden at night: old flagstones, uneven, with moss between them
//  and creeping over a few, walled by dark hedges and a few pale moonflowers.
//  The moon is off to the upper left: its light lies across the floor and
//  catches the stones' near edges. Fireflies drift over it, keep clear of
//  the fighters, and scatter from a blow.
// ─────────────────────────────────────────────────────────────────────────────

const Color _gardenSoil = Color(0xFF0B110D);
const Color _gardenMoss = Color(0xFF2E4A2A);
const Color _gardenMoon = Color(0xFFC9D8E6);
const Color _gardenFly = Color(0xFFD8E89A);

class GardenFloor extends BattleFloor {
  GardenFloor({required super.rx, required super.ry});

  ui.Picture? _still;
  late final List<_Firefly> _flies = _makeFlies();
  double _last = 0;

  @override
  void dispose() {
    _still?.dispose();
    _still = null;
  }

  @override
  void paint(Canvas canvas, Offset centre, double time, Rect view) {
    canvas.drawRect(view, Paint()..color = _space);
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.drawPicture(_still ??= _record());
    _paintFlies(canvas, time);
    canvas.restore();
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rng = Random(61);
    paintStars(c, rng, count: 240);
    BattleFloor.pool(c, Offset.zero, rx, ry, const [
      Color(0xFF111A13),
      _gardenSoil,
      Color(0xFF070B08),
    ], const [0.0, 0.75, 1.0]);
    _paintStones(c, rng);
    // The moon's light across the floor, and the far side in shadow.
    c.save();
    c.clipPath(
      Path()
        ..addOval(
          Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
        ),
    );
    BattleFloor.pool(c, Offset(-rx * 0.55, -ry * 0.6), rx * 1.3, ry * 1.0, [
      _gardenMoon.withValues(alpha: 0.10),
      _gardenMoon.withValues(alpha: 0),
    ]);
    BattleFloor.pool(c, Offset(rx * 0.7, ry * 0.75), rx * 1.0, ry * 0.8, [
      Colors.black.withValues(alpha: 0.35),
      Colors.black.withValues(alpha: 0),
    ]);
    c.restore();
    _paintHedge(c, rng);
    return rec.endRecording();
  }

  /// Crazy paving: irregular flagstones of mixed sizes (cells round
  /// scattered sites, some merged), dark and low in contrast so the fight
  /// reads over them, a touch lighter on the moon's side, with moss in the
  /// gaps and creeping over a few. (Even stones off a grid read as a grey
  /// honeycomb.)
  void _paintStones(Canvas c, Random rng) {
    final sites = <Offset>[];
    const step = 66.0;
    for (var y = -ry - step; y <= ry + step; y += step * 0.9) {
      for (var x = -rx - step; x <= rx + step; x += step) {
        final p = Offset(
          x + (rng.nextDouble() - 0.5) * step * 0.9,
          y + (rng.nextDouble() - 0.5) * step * 0.8,
        );
        if (!inside(p, 1.08)) continue;
        if (rng.nextDouble() < 0.3) continue;
        sites.add(p);
      }
    }
    final cells = floorCells(
      sites,
      Rect.fromCenter(center: Offset.zero, width: rx * 2.4, height: ry * 2.4),
    );
    final oval = Path()
      ..addOval(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2),
      );
    c.save();
    c.clipPath(oval);
    final moss = Paint();
    for (var i = 0; i < sites.length; i++) {
      final cell = cells[i];
      if (cell.length < 3) continue;
      final site = sites[i];
      // A missing stone now and then: moss where it was.
      if (rng.nextDouble() < 0.05) {
        BattleFloor.pool(c, site, 40, 34, [
          _gardenMoss.withValues(alpha: 0.45),
          _gardenMoss.withValues(alpha: 0),
        ]);
        continue;
      }
      final stone = insetCell(cell, site, 4.5 + rng.nextDouble() * 2.5);
      final b = stone.getBounds();
      final shade = rng.nextDouble() * 0.1;
      c.drawPath(
        stone,
        Paint()
          ..shader = ui.Gradient.linear(b.topLeft, b.bottomRight, [
            Color.lerp(const Color(0xFF20242A), _gardenMoon, 0.04 - shade * 0.3)!,
            Color.lerp(const Color(0xFF131518), Colors.black, shade)!,
          ]),
      );
      // Wear: a few pale specks on the moon side of the stone.
      for (var g = 0; g < 5; g++) {
        final p = Offset.lerp(site, b.topLeft, 0.2 + rng.nextDouble() * 0.5)! +
            Offset((rng.nextDouble() - 0.5) * 16, (rng.nextDouble() - 0.5) * 16);
        moss.color = _gardenMoon.withValues(alpha: 0.03 + rng.nextDouble() * 0.05);
        c.drawCircle(p, 0.6 + rng.nextDouble() * 0.9, moss);
      }
      // Moss creeping over the edge of a few.
      if (rng.nextDouble() < 0.3) {
        final corner = cell[rng.nextInt(cell.length)];
        BattleFloor.pool(c, Offset.lerp(site, corner, 0.75)!, 26, 22, [
          _gardenMoss.withValues(alpha: 0.42),
          _gardenMoss.withValues(alpha: 0),
        ]);
      }
      // Moss in the gaps: fine grains along its edges.
      for (var e = 0; e < cell.length; e++) {
        final p = cell[e], q = cell[(e + 1) % cell.length];
        final n = ((p - q).distance / 9).ceil();
        for (var g = 0; g < n; g++) {
          final at = Offset.lerp(p, q, rng.nextDouble())! +
              Offset((rng.nextDouble() - 0.5) * 4, (rng.nextDouble() - 0.5) * 4);
          moss.color = Color.lerp(
            _gardenMoss,
            const Color(0xFF6B8A4E),
            rng.nextDouble() * 0.45,
          )!.withValues(alpha: 0.18 + rng.nextDouble() * 0.32);
          c.drawCircle(at, 0.7 + rng.nextDouble() * 1.3, moss);
        }
      }
    }
    c.restore();
  }

  /// The garden's wall: dark hedge in clumps round the edge, leaves caught
  /// by the moon, and a few pale moonflowers glowing faintly.
  void _paintHedge(Canvas c, Random rng) {
    final leaf = Paint();
    for (var i = 0; i < 70; i++) {
      final a = rng.nextDouble() * pi * 2;
      final k = 1.02 + rng.nextDouble() * 0.09;
      final at = Offset(cos(a) * rx * k, sin(a) * ry * k);
      final size = 22 + rng.nextDouble() * 30;
      BattleFloor.pool(c, at, size, size * 0.85, const [
        Color(0xFF0F1A11),
        Color(0xFF0A120B),
        Color(0x000A120B),
      ], const [0.0, 0.7, 1.0]);
      final facing = (-cos(a) - sin(a)) / sqrt2;
      for (var g = 0; g < 14; g++) {
        final t = rng.nextDouble() * pi * 2;
        final r = size * rng.nextDouble() * 0.8;
        leaf.color = Color.lerp(
          const Color(0xFF223A22),
          const Color(0xFF8FB08A),
          (0.15 + 0.5 * facing).clamp(0.0, 1.0) * rng.nextDouble(),
        )!.withValues(alpha: 0.15 + rng.nextDouble() * 0.3);
        c.drawCircle(at + Offset(cos(t) * r, sin(t) * r), 1 + rng.nextDouble() * 1.6, leaf);
      }
    }
    // Moonflowers.
    for (var i = 0; i < 9; i++) {
      final a = i / 9 * pi * 2 + rng.nextDouble() * 0.4;
      final at = Offset(cos(a) * rx * 1.0, sin(a) * ry * 1.0);
      BattleFloor.pool(c, at, 26, 26, [
        const Color(0xFFE8EEF4).withValues(alpha: 0.12),
        const Color(0xFFE8EEF4).withValues(alpha: 0),
      ]);
      for (var p = 0; p < 5; p++) {
        final t = p / 5 * pi * 2 + a;
        c.drawOval(
          Rect.fromCenter(
            center: at + Offset(cos(t), sin(t)) * 4.5,
            width: 6,
            height: 6,
          ),
          Paint()..color = const Color(0xFFDCE4EC).withValues(alpha: 0.55),
        );
      }
      c.drawCircle(at, 1.6, Paint()..color = const Color(0xFFE9D98F).withValues(alpha: 0.7));
    }
  }

  List<_Firefly> _makeFlies() {
    final rng = Random(67);
    final flies = <_Firefly>[];
    while (flies.length < 34) {
      final p = Offset(
        (rng.nextDouble() * 2 - 1) * rx,
        (rng.nextDouble() * 2 - 1) * ry,
      );
      if (!inside(p, 0.9)) continue;
      flies.add(
        _Firefly(
          home: p,
          phase: rng.nextDouble() * pi * 2,
          rate: 0.6 + rng.nextDouble() * 0.9,
          pulse: 0.5 + rng.nextDouble() * 1.2,
        ),
      );
    }
    return flies;
  }

  @override
  void fighters(List<Offset> at, double dt) {
    for (final f in _flies) {
      // Drifting about its place; pushed off by anyone standing near.
      for (final p in at) {
        final d = f.at - p;
        final dist = d.distance;
        if (dist < 110 && dist > 0.1) {
          f.velocity += d / dist * (110 - dist) * 9 * dt;
        }
      }
      final wander = Offset(
        cos(f.phase + _last * f.rate) * 26,
        sin(f.phase * 1.3 + _last * f.rate * 0.8) * 20,
      );
      final pull = (f.home + wander) - f.at;
      f.velocity += pull * 1.4 * dt;
      f.velocity *= exp(-dt * 1.8);
      f.at += f.velocity * dt;
    }
  }

  @override
  void hit(Offset at, Color color, double strength, double time) {
    for (final f in _flies) {
      final d = f.at - at;
      final dist = d.distance;
      if (dist < 170 && dist > 0.1) {
        f.velocity += d / dist * (170 - dist) * (1.2 + strength);
      }
    }
  }

  @override
  void special(Offset at, Color color, double time) => hit(at, color, 1, time);

  void _paintFlies(Canvas canvas, double time) {
    _last = time;
    for (final f in _flies) {
      final glow = pow(0.5 + 0.5 * sin(time * f.pulse * 2 + f.phase), 3).toDouble();
      if (glow < 0.04) continue;
      BattleFloor.pool(canvas, f.at, 9, 9, [
        _gardenFly.withValues(alpha: 0.55 * glow),
        _gardenFly.withValues(alpha: 0),
      ]);
      canvas.drawCircle(
        f.at,
        1.3,
        Paint()..color = const Color(0xFFF4FAD8).withValues(alpha: 0.9 * glow),
      );
    }
  }
}

class _Firefly {
  _Firefly({
    required this.home,
    required this.phase,
    required this.rate,
    required this.pulse,
  }) : at = home;

  final Offset home;
  final double phase;
  final double rate;
  final double pulse;
  Offset at;
  Offset velocity = Offset.zero;
}
