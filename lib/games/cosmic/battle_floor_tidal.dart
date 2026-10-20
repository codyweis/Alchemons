part of 'battle_arena_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE TIDAL MIRROR
//
//  A floor of still black water in the dark, ringed by low wet rocks. The
//  stars are in it, and a moon's path of glitter from the upper left; the
//  fighters are mirrored in it (the game draws their reflections). Where a
//  foot comes down, a blow lands or a special goes off, the water rings —
//  soft, wide and quick to fade, lit on the moon's side, broken by glints,
//  so a ripple reads as water and never as a drawn hoop.
// ─────────────────────────────────────────────────────────────────────────────

const Color _tidalDeep = Color(0xFF070A0F);
const Color _tidalWater = Color(0xFF0C1219);
const Color _tidalSheen = Color(0xFFBFD3E6);

class TidalFloor extends BattleFloor {
  TidalFloor({required super.rx, required super.ry});

  @override
  bool get reflects => true;

  ui.Picture? _still;
  final List<_Ripple> _ripples = [];
  late final List<_Glint> _path = _makePath();

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
    _paintPath(canvas, time);
    _paintRipples(canvas, time);
    canvas.restore();
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final rng = Random(53);
    paintStars(c, rng);
    // The water, a shade lighter at its middle, and the shallows dark at
    // its edge where it meets the rocks.
    BattleFloor.pool(c, Offset.zero, rx * 1.08, ry * 1.06, [
      const Color(0xFF101820).withValues(alpha: 0.6),
      const Color(0xFF101820).withValues(alpha: 0),
    ], const [0.86, 1.0]);
    BattleFloor.pool(c, Offset.zero, rx, ry, const [
      _tidalWater,
      Color(0xFF0A0F15),
      _tidalDeep,
    ], const [0.0, 0.75, 1.0]);
    // The moon's light lying on the water, upper left.
    BattleFloor.pool(c, Offset(-rx * 0.38, -ry * 0.46), rx * 0.62, ry * 0.42, [
      _tidalSheen.withValues(alpha: 0.07),
      _tidalSheen.withValues(alpha: 0),
    ]);
    // The stars, in the water.
    final paint = Paint();
    for (var i = 0; i < 170; i++) {
      final p = Offset(
        (rng.nextDouble() * 2 - 1) * rx,
        (rng.nextDouble() * 2 - 1) * ry,
      );
      if (!inside(p, 0.94)) continue;
      paint.color = const Color(0xFFDDE4F0).withValues(
        alpha: 0.05 + pow(rng.nextDouble(), 2) * 0.22,
      );
      c.drawCircle(p, 0.5 + rng.nextDouble() * 0.9, paint);
    }
    _paintRocks(c, rng);
    return rec.endRecording();
  }

  /// Low wet rocks round the edge, half in the water: dark masses, their
  /// tops caught by the moon in grains, a lace of foam where they meet it.
  void _paintRocks(Canvas c, Random rng) {
    final paint = Paint();
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * pi * 2 + (rng.nextDouble() - 0.5) * 0.3;
      final k = 1.0 + rng.nextDouble() * 0.05;
      final at = Offset(cos(a) * rx * k, sin(a) * ry * k);
      final size = 26 + rng.nextDouble() * 34;
      final rock = Path();
      const n = 10;
      for (var s = 0; s <= n; s++) {
        final t = s / n * pi * 2;
        final r = size * (0.7 + 0.3 * sin(t * 2 + i) + rng.nextDouble() * 0.12);
        final p = at + Offset(cos(t) * r, sin(t) * r * 0.72);
        s == 0 ? rock.moveTo(p.dx, p.dy) : rock.lineTo(p.dx, p.dy);
      }
      rock.close();
      c.drawPath(
        rock,
        Paint()
          ..shader = ui.Gradient.radial(
            at + Offset(-size * 0.3, -size * 0.35),
            size * 1.3,
            const [Color(0xFF1A1E24), Color(0xFF101317), Color(0xFF08090B)],
            const [0.0, 0.5, 1.0],
          ),
      );
      // Wet tops caught by the moon.
      for (var g = 0; g < 40; g++) {
        final t = -pi * 0.75 + (rng.nextDouble() - 0.5) * 1.6;
        final r = size * (0.45 + rng.nextDouble() * 0.45);
        final p = at + Offset(cos(t) * r, sin(t) * r * 0.62);
        paint.color = const Color(0xFFC9D6E3).withValues(
          alpha: 0.03 + rng.nextDouble() * 0.12,
        );
        c.drawCircle(p, 0.5 + rng.nextDouble() * 1.0, paint);
      }
      // Foam lace at the waterline, on the floor's side.
      final toward = -at / at.distance;
      for (var g = 0; g < 26; g++) {
        final t = atan2(toward.dy, toward.dx) + (rng.nextDouble() - 0.5) * 2.2;
        final r = size * (0.85 + rng.nextDouble() * 0.3);
        final p = at + Offset(cos(t) * r, sin(t) * r * 0.72);
        paint.color = _tidalSheen.withValues(
          alpha: 0.04 + rng.nextDouble() * 0.12,
        );
        c.drawCircle(p, 0.5 + rng.nextDouble() * 1.3, paint);
      }
    }
  }

  /// The moon's path: a lane of glints from the upper left toward the
  /// middle, each glinting at its own moment.
  List<_Glint> _makePath() {
    final rng = Random(59);
    final from = Offset(-rx * 0.78, -ry * 0.8);
    const to = Offset.zero;
    return [
      for (var i = 0; i < 150; i++)
        () {
          final u = pow(rng.nextDouble(), 0.8).toDouble();
          final along = Offset.lerp(from, to, u)!;
          final across = Offset(0.8, -0.6) * ((rng.nextDouble() - 0.5) * 90 * (1.1 - u));
          return _Glint(
            along + across,
            rng.nextDouble() * pi * 2,
            1.2 + rng.nextDouble() * 2.4,
          );
        }(),
    ];
  }

  void _paintPath(Canvas canvas, double time) {
    final bright = <double>[], soft = <double>[];
    for (final g in _path) {
      final k = sin(time * g.speed + g.phase);
      if (k < 0.2) continue;
      (k > 0.85 ? bright : soft)
        ..add(g.at.dx)
        ..add(g.at.dy);
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(soft),
      Paint()
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = _tidalSheen.withValues(alpha: 0.22),
    );
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(bright),
      Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFEAF2FA).withValues(alpha: 0.55),
    );
  }

  void _ring(Offset at, double strength, Color tint, double time) {
    if (!inside(at, 0.97)) return;
    _ripples.add(_Ripple(at, time, strength, tint));
    if (_ripples.length > 28) _ripples.removeAt(0);
  }

  @override
  void step(Offset at, double time) =>
      _ring(at + const Offset(0, 14), 0.35, _tidalSheen, time);

  @override
  void hit(Offset at, Color color, double strength, double time) =>
      _ring(at, 0.55 + 0.45 * strength, color, time);

  @override
  void special(Offset at, Color color, double time) {
    _ring(at, 1.0, color, time);
    _ring(at, 0.7, color, time - 0.25);
  }

  void _paintRipples(Canvas canvas, double time) {
    _ripples.removeWhere((r) => time - r.born > _Ripple.life(r.strength));
    final glints = <double>[];
    for (final r in _ripples) {
      final age = time - r.born;
      if (age < 0) continue;
      final life = _Ripple.life(r.strength);
      final u = age / life;
      final radius = 10 + age * (60 + 60 * r.strength);
      final fade = pow(1 - u, 2).toDouble();
      final alpha = 0.16 * r.strength * fade;
      final tint = Color.lerp(_tidalSheen, r.tint, 0.35)!;
      // A soft, wide band, its centre nudged toward the moon so the crest
      // is brighter on that side.
      final at = r.at + const Offset(-0.06, -0.06) * radius;
      canvas.drawCircle(
        at,
        radius * 1.25,
        Paint()
          ..shader = ui.Gradient.radial(
            at,
            radius * 1.25,
            [
              tint.withValues(alpha: 0),
              tint.withValues(alpha: 0),
              tint.withValues(alpha: alpha),
              tint.withValues(alpha: alpha * 0.3),
              tint.withValues(alpha: 0),
            ],
            const [0.0, 0.62, 0.78, 0.88, 1.0],
          ),
      );
      // Glints along the moon side of its crest.
      for (var i = 0; i < 9; i++) {
        final a = -pi * 0.75 + (i - 4) * 0.22 + sin(i * 7.1 + r.born) * 0.1;
        glints
          ..add(r.at.dx + cos(a) * radius * 0.97)
          ..add(r.at.dy + sin(a) * radius * 0.97);
      }
    }
    if (glints.isEmpty) return;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.fromList(glints),
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFEAF2FA).withValues(alpha: 0.32),
    );
  }
}

class _Ripple {
  _Ripple(this.at, this.born, this.strength, this.tint);
  final Offset at;
  final double born;
  final double strength;
  final Color tint;

  static double life(double strength) => 0.9 + 0.9 * strength;
}
