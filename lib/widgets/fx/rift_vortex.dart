// lib/widgets/fx/rift_vortex.dart
//
// A rift as grains: a tipped disk in its faction's color falling into a
// black core, turning faster as it falls, with a ring of light hugging the
// core and dust drawn in from the dark. The same rift is the small one out in
// the wilderness (RiftPortalComponent) and the big one its threshold opens
// on (RiftThreshold), so tapping one opens into the other.
//
// Every grain is a point in a batch and every glow a radial gradient — no
// blur, so it is safe in a Flame render loop.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart'
    show GrainBatch, SpecimenGrains;
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';

/// A rift's colors, drawn from its faction: ink at the disk's cold rim,
/// white-hot at the core's edge.
class RiftPalette {
  RiftPalette(Color base)
    : tones = [
        Color.lerp(base, const Color(0xFF000000), 0.62)!,
        Color.lerp(base, const Color(0xFF000000), 0.34)!,
        base,
        Color.lerp(base, const Color(0xFFFFF4E6), 0.3)!,
        Color.lerp(base, const Color(0xFFFFF4E6), 0.58)!,
        Color.lerp(base, const Color(0xFFFFFFFF), 0.85)!,
      ],
      glow = Color.lerp(base, const Color(0xFFFFF4E6), 0.25)!,
      tint = Color.lerp(base, const Color(0xFF050507), 0.86)!;

  /// Cold to hot.
  final List<Color> tones;
  final Color glow;

  /// The void's wash.
  final Color tint;
}

/// The rift's grains: a tipped disk falling inward and turning faster as it
/// falls, a ring of light hugging the black core, and dust drawn in from
/// the dark. Plain Dart — [step] advances it, [paint] draws it.
class RiftVortexField {
  RiftVortexField({
    this.grains = defaultGrains,
    this.ringGrains = 260,
    this.motes = 70,
    this.core = 0.21,
    this.speed = 1,
    this.grainSize,
  }) : _inner = core + 0.06,
       _rho = List.filled(grains, 0),
       _theta = List.filled(grains, 0),
       _ph = List.filled(grains, 0) {
    for (var i = 0; i < grains; i++) {
      _respawn(i, initial: true);
    }
  }

  final int grains, ringGrains, motes;

  /// A threshold's grains: the rift at its own size.
  static const int defaultGrains = 1500;

  /// The core's radius, and the disk's inner edge, as fractions of the
  /// rift's radius.
  final double core;
  final double _inner;

  /// How fast it turns and falls. Below 1 for a rift seen huge (the inside
  /// of one), where the rim's pace in px would otherwise race.
  final double speed;

  /// A grain's diameter in px. Null scales it with the rift's radius, which
  /// suits a rift drawn small or mid-sized but not one filling a screen.
  final double? grainSize;

  final List<double> _rho, _theta, _ph;
  final math.Random _rng = math.Random(7);

  double time = 0;

  /// 0→1 as the rift tears open when the screen appears.
  double open = 0;

  /// 0→1 as the key is turned; spins it up.
  double charge = 0;

  /// 0→1 as the camera falls in. Ends black.
  double dive = 0;

  void _respawn(int i, {bool initial = false}) {
    final u = _rng.nextDouble();
    // Denser towards the core, as a disk feeding a hole is.
    _rho[i] = initial
        ? _inner + (1 - _inner) * math.pow(u, 0.85)
        : 0.86 + 0.14 * u;
    _theta[i] = _rng.nextDouble() * math.pi * 2;
    _ph[i] = _rng.nextDouble();
  }

  void step(double dt) {
    time += dt;
    final spin = (1 + 2.4 * charge + 7 * dive) * speed;
    final fall = (1 + 3 * charge + 10 * dive) * speed;
    for (var i = 0; i < grains; i++) {
      final r = _rho[i];
      // Kepler: the inner disk turns far faster than the rim.
      _theta[i] += dt * 0.5 / (r * math.sqrt(r)) * spin;
      _rho[i] = r - dt * (0.012 + 0.03 / r) * fall;
      if (_rho[i] < _inner * 0.92) _respawn(i);
    }
  }

  static double _ease(double x) => 1 - math.pow(1 - x, 3).toDouble();

  // Buckets: disk far (6) / near (6), ring dim / bright, motes, glints,
  // trails.
  static const int _nearB = 6, _ringB = 12, _moteB = 14, _glintB = 15;
  static const int _trailB = 16;
  final GrainBatch _b = GrainBatch(17);

  /// How the disk lies: squashed to [flat] of its width, tipped by [turn].
  static const double flat = 0.3, turn = -0.22;

  /// Draws the rift round [c], its disk [radius] wide.
  ///
  /// A rift standing in for a smaller one ([RiftThreshold] growing out of
  /// the world's) draws as that one did: [density] of its grains, its core
  /// [coreScale] times as wide, a [grain] diameter of its own, and with
  /// [backdrop] only [fill] of the way to a screen of void. [key] is a key
  /// [keyT] of the way into it.
  void paint(
    Canvas canvas,
    Size size,
    Offset c,
    double radius,
    RiftPalette pal, {
    RiftKeyGrains? key,
    double keyT = 0,
    bool backdrop = true,
    double fill = 1,
    double density = 1,
    double coreScale = 1,
    double? grain,
  }) {
    final b = _b..clear();
    final o = _ease(open.clamp(0.0, 1.0));
    final rr = radius * (1 + 0.04 * charge);
    final coreR0 =
        rr * core * coreScale * (0.3 + 0.7 * o) * (1 + 0.18 * charge);
    final t = time;
    final dense = density.clamp(0.0, 1.0);
    final shownGrains = (grains * dense).round();
    final shownRing = (ringGrains * dense).round();
    final shownMotes = (motes * dense).round();

    // Falling in: everything spreads out from the core — positions, not
    // grain sizes, so the grains rush past as grains rather than swelling
    // into discs — and each leaves a short trail.
    final fallE = ((dive - 0.25) / 0.75).clamp(0.0, 1.0);
    final zoom = 1 + 11 * fallE * fallE;
    final trail = fallE > 0.02 ? 1 - 0.07 * fallE : 0.0;
    final coreR = coreR0 * zoom;

    // How far towards a screen of void: none out in the world.
    final void_ = backdrop ? fill.clamp(0.0, 1.0) : 0.0;
    if (void_ > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF050507).withValues(alpha: void_),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);

    // The void: the whole screen when it is the screen; out in the world,
    // a dark tear round the rift, so it reads against a daylit sky.
    final tear = rr * 2.1 * o;
    final reach = void_ <= 0
        ? tear
        : tear + (size.longestSide * (1 + 0.5 * fallE) - tear) * void_;
    // Opening with the rift, so a rift that opens out of black (the inside
    // of one, after the fall) does not cut to color.
    final screen = [
      pal.tint.withValues(alpha: o),
      pal.tint.withValues(alpha: 0.35 * o),
      const Color(0x00050507),
    ];
    final torn = [
      pal.tint.withValues(alpha: 0.85),
      pal.tint.withValues(alpha: 0.4),
      pal.tint.withValues(alpha: 0),
    ];
    canvas.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          reach,
          [for (var k = 0; k < 3; k++) Color.lerp(torn[k], screen[k], void_)!],
          const [0.0, 0.45, 1.0],
        ),
    );

    // ── dust drawn in from the dark ──
    for (var i = 0; i < shownMotes; i++) {
      final seed = (i * 0.6180339) % 1.0;
      final p =
          (t * speed * (0.05 + 0.05 * seed) * (1 + 2 * charge) + seed * 7.1) %
          1;
      final a = seed * math.pi * 2 + p * 1.6;
      final d = rr * (2.6 - 1.7 * p * p) * zoom;
      if (p < 0.06) continue;
      b.add(_moteB, math.cos(a) * d, math.sin(a) * d * 0.62);
    }

    // ── the disk ──
    final ct = math.cos(turn), st = math.sin(turn);
    final glintRate = 0.006 + 0.03 * charge;
    for (var i = 0; i < shownGrains; i++) {
      final rho = core + (_rho[i] - core) * o;
      final th = _theta[i];
      final sn = math.sin(th), cs = math.cos(th);
      final x0 = cs * rho * rr, y0 = sn * rho * rr * flat;
      final x = (x0 * ct - y0 * st) * zoom, y = (x0 * st + y0 * ct) * zoom;
      final heat = (1 - (_rho[i] - _inner) / (1 - _inner)).clamp(0.0, 1.0);
      final near = sn > 0;
      if (trail > 0) b.add(_trailB, x * trail, y * trail);
      if (near && (t * 0.3 + _ph[i] * 9.1) % 1.0 < glintRate && heat > 0.4) {
        b.add(_glintB, x, y);
        continue;
      }
      // The side turning towards you burns a shade brighter.
      final tone =
          (math.pow(heat, 1.3) * 5.99 + 0.6 * charge + (cs < -0.35 ? 0.8 : 0))
              .clamp(0.0, 5.99)
              .floor();
      b.add((near ? _nearB : 0) + tone, x, y);
    }

    // ── the light bent round the core: hugging its edge, brightest above
    // and below it ──
    for (var i = 0; i < shownRing; i++) {
      final seed = (i * 0.7548776) % 1.0;
      final a =
          seed * math.pi * 2 + t * speed * (1.6 + seed) * (1 + 2 * charge);
      final d = coreR * (1.02 + 0.1 * ((i * 0.5698) % 1.0));
      final sa = math.sin(a);
      b.add(sa.abs() > 0.72 ? _ringB + 1 : _ringB, math.cos(a) * d, sa * d);
    }

    final d =
        (grain ?? grainSize ?? math.max(1.25, rr * 0.011)) * (1 + 0.4 * fallE);

    b.draw(canvas, _moteB, d * 0.9, pal.tones[3].withValues(alpha: 0.4));

    // The disk's own haze, behind everything in it. Never in front of the
    // core: a glow over the hole greys its black.
    canvas.save();
    canvas.rotate(turn);
    canvas.scale(1, flat);
    final lane = rr * 1.05 * zoom;
    canvas.drawCircle(
      Offset.zero,
      lane,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          lane,
          [
            pal.tones[3].withValues(alpha: 0),
            pal.tones[3].withValues(alpha: 0.2 * o),
            pal.tones[2].withValues(alpha: 0.09 * o),
            pal.tones[1].withValues(alpha: 0),
          ],
          const [0.18, 0.32, 0.62, 1.0],
        ),
    );
    canvas.restore();

    // The hot glow behind the hole.
    canvas.drawCircle(
      Offset.zero,
      coreR * 3.4,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          coreR * 3.4,
          [
            pal.glow.withValues(alpha: 0.42 * o + 0.2 * charge),
            pal.glow.withValues(alpha: 0.1 * o),
            pal.glow.withValues(alpha: 0),
          ],
          const [0.0, 0.42, 1.0],
        ),
    );

    b.draw(canvas, _trailB, d * 0.8, pal.tones[2].withValues(alpha: 0.35));
    for (var k = 0; k < 6; k++) {
      b.draw(
        canvas,
        k,
        d * 0.9,
        Color.lerp(pal.tones[k], const Color(0xFF000000), 0.4)!,
      );
    }

    // The key's grains go under the core: the hole swallows each one.
    key?.paint(canvas, c, rr, coreR, keyT, pal, d);

    // The core: black, with a soft edge so the far disk fades behind it.
    canvas.drawCircle(
      Offset.zero,
      coreR * 1.06,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          coreR * 1.06,
          const [Color(0xFF010102), Color(0xFF010102), Color(0x00010102)],
          const [0.0, 0.86, 1.0],
        ),
    );

    b.draw(canvas, _ringB, d * 0.7, pal.tones[4].withValues(alpha: 0.55 * o));
    b.draw(
      canvas,
      _ringB + 1,
      d * 0.8,
      pal.tones[5].withValues(alpha: 0.85 * o),
    );

    for (var k = 0; k < 6; k++) {
      b.draw(canvas, _nearB + k, d, pal.tones[k]);
    }
    b.draw(canvas, _glintB, d * 2.4, const Color(0x33FFFFFF));
    b.draw(canvas, _glintB, d * 1.3, const Color(0xFFFFFFFF));
    canvas.restore();

    // The key itself, as it stood, giving way to its grains.
    key?.paintKey(canvas, keyT, t);

    // The fall ends in the void the glyph portal starts from.
    final black = ((dive - 0.55) / 0.45).clamp(0.0, 1.0);
    if (black > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF050507).withValues(alpha: black),
      );
    }
  }
}

final double _turnCos = math.cos(RiftVortexField.turn);
final double _turnSin = math.sin(RiftVortexField.turn);

double _smooth(double x) {
  final u = x.clamp(0.0, 1.0);
  return u * u * (3 - 2 * u);
}

/// A turned key coming apart into grains and drawn into a rift.
///
/// The painted key gives way to its grains where it stood; they loosen, then
/// each streams round the disk into the core — the end nearest the rift
/// first, so the key unravels into the pull rather than flying in whole —
/// warming to the rift's light as it falls. Drawn under the core, so the
/// hole swallows each grain.
class RiftKeyGrains {
  RiftKeyGrains(
    this.grains, {
    required this.from,
    required this.color,
    this.angle = 0,
    this.glyphSize = 52,
  }) : _b = GrainBatch(grains.tones.length + 5);

  /// The key read into grains round its own centre, standing upright
  /// ([PortalKeyGlyph.grainsOf]).
  final SpecimenGrains grains;

  /// Where the key stood, in the painter's coordinates, and how far round
  /// it had been turned.
  final Offset from;
  final double angle;

  /// The key's own color and size, for the glyph it gives way to.
  final Color color;
  final double glyphSize;

  /// From the turn to the last grain swallowed.
  static const double seconds = 1.25;

  // The beats, as fractions of [seconds]: the painted key gives way to its
  // grains, they loosen, and each falls for [_fall], the last setting off
  // [_spread] after the first.
  static const double _swap = 0.08, _loosen = 0.12, _spread = 0.3;
  static const double _fall = 1 - _loosen - _spread;

  final GrainBatch _b;
  Float32List? _rho0, _a0, _delay, _swing, _end, _jx, _jy, _band;

  /// Each grain's way in, settled the first time the rift is known.
  void _plan(Offset c, double coreR) {
    final n = grains.length;
    final rho0 = _rho0 = Float32List(n);
    final a0 = _a0 = Float32List(n);
    final delay = _delay = Float32List(n);
    final swing = _swing = Float32List(n);
    final end = _end = Float32List(n);
    final jx = _jx = Float32List(n);
    final jy = _jy = Float32List(n);
    final band = _band = Float32List(n);
    final rng = math.Random(11);
    final ca = math.cos(angle), sa = math.sin(angle);
    // Into the disk's own frame, untipped, so the way in can settle into
    // its plane.
    final ct = math.cos(-RiftVortexField.turn);
    final st = math.sin(-RiftVortexField.turn);
    var lo = double.infinity, hi = 0.0;
    for (var i = 0; i < n; i++) {
      final hx = grains.hx[i], hy = grains.hy[i];
      final sx = from.dx + hx * ca - hy * sa - c.dx;
      final sy = from.dy + hx * sa + hy * ca - c.dy;
      final vx = sx * ct - sy * st, vy = sx * st + sy * ct;
      rho0[i] = math.sqrt(vx * vx + vy * vy);
      a0[i] = math.atan2(vy, vx);
      lo = math.min(lo, rho0[i]);
      hi = math.max(hi, rho0[i]);
      swing[i] = 2.3 + rng.nextDouble() * 1.1;
      end[i] = coreR * (0.9 + 0.22 * rng.nextDouble());
      jx[i] = (rng.nextDouble() - 0.5) * 3.2;
      jy[i] = (rng.nextDouble() - 0.5) * 3.2;
      // How far off the middle of the stream it strays, either way.
      band[i] = (rng.nextDouble() + rng.nextDouble() - 1) * coreR * 0.9;
    }
    final span = math.max(1e-3, hi - lo);
    for (var i = 0; i < n; i++) {
      delay[i] =
          _spread * (0.82 * (rho0[i] - lo) / span + 0.18 * rng.nextDouble());
    }
  }

  /// Where grain [i] is, [u] of the way in, from the rift's centre.
  Offset _at(int i, double u, double drift) {
    // Drawn in on a curve that tightens as it nears the core, settling into
    // the disk's plane as it goes; the stream loosens into a band on the
    // way and gathers again at the core.
    final r =
        _rho0![i] +
        (_end![i] - _rho0![i]) * (1 - math.pow(1 - u, 1.6)) +
        _band![i] * math.sin(math.pi * u);
    final a = _a0![i] + _swing![i] * math.pow(u, 1.3);
    final f = 1 + (RiftVortexField.flat - 1) * _smooth(u);
    final x0 = math.cos(a) * r, y0 = math.sin(a) * r * f;
    final k = drift * (1 - u);
    return Offset(
      x0 * _turnCos - y0 * _turnSin + _jx![i] * k,
      x0 * _turnSin + y0 * _turnCos + _jy![i] * k,
    );
  }

  /// The grains, [keyT] of the way in, on a canvas already moved to the
  /// rift's centre [c].
  void paint(
    Canvas canvas,
    Offset c,
    double rr,
    double coreR,
    double keyT,
    RiftPalette pal,
    double d,
  ) {
    if (grains.length == 0) return;
    if (_rho0 == null) _plan(c, coreR);
    final b = _b..clear();
    final tones = grains.tones.length;
    final hot = tones, white = tones + 1, trail = tones + 2;
    final ca = math.cos(angle), sa = math.sin(angle);
    final sx = from.dx - c.dx, sy = from.dy - c.dy;
    final drift = _smooth(keyT / _loosen);
    for (var i = 0; i < grains.length; i++) {
      final u = ((keyT - _loosen - _delay![i]) / _fall).clamp(0.0, 1.0);
      if (u >= 1) continue;
      if (u <= 0) {
        // Still the key, loosening.
        final hx = grains.hx[i], hy = grains.hy[i];
        b.add(
          grains.tone[i],
          sx + hx * ca - hy * sa + _jx![i] * drift,
          sy + hx * sa + hy * ca + _jy![i] * drift,
        );
        continue;
      }
      final p = _at(i, u, drift);
      b.add(u < 0.3 ? grains.tone[i] : (u < 0.68 ? hot : white), p.dx, p.dy);
      for (var k = 1; k <= 3; k++) {
        final v = u - 0.035 * k;
        if (v <= 0) break;
        final q = _at(i, v, drift);
        b.add(trail + k - 1, q.dx, q.dy);
      }
    }
    final appear = _smooth(keyT / _swap);
    final gd = math.max(1.05, grains.step * 1.2);
    for (var k = 0; k < 3; k++) {
      b.draw(
        canvas,
        trail + k,
        d * 0.8,
        pal.tones[3].withValues(alpha: 0.34 - 0.1 * k),
      );
    }
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, gd, grains.tones[k].withValues(alpha: appear));
    }
    b.draw(canvas, hot, d, pal.tones[4]);
    b.draw(canvas, white, d, pal.tones[5]);
  }

  /// The painted key, as it stood, fading as its grains take its place.
  void paintKey(Canvas canvas, double keyT, double time) {
    final fade = 1 - _smooth(keyT / _swap);
    if (fade <= 0) return;
    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(angle);
    PortalKeyGlyph.paintGlyph(
      canvas,
      Offset.zero,
      glyphSize,
      color,
      time,
      fade: fade,
    );
    canvas.restore();
  }
}

/// An Alchemon poured out of a rift into its core.
///
/// Each grain of the read sprite is born in the disk, turns inward with it,
/// and leaves it for its own place — feet first — cooling from the rift's
/// light into its own color. From 1 on every grain sits where its pixel
/// was, so the sprite can take over unseen.
class RiftPour {
  RiftPour(this.specimen)
    : _b = GrainBatch(specimen.tones.length + 4),
      _theta = Float32List(specimen.length),
      _rho = Float32List(specimen.length),
      _delay = Float32List(specimen.length),
      _swing = Float32List(specimen.length),
      _cool = Float32List(specimen.length) {
    final n = specimen.length;
    final rng = math.Random(3);
    var top = double.infinity, foot = -double.infinity;
    for (var i = 0; i < n; i++) {
      top = math.min(top, specimen.hy[i]);
      foot = math.max(foot, specimen.hy[i]);
    }
    final tall = math.max(1e-3, foot - top);
    for (var i = 0; i < n; i++) {
      // Feet first: the lowest grains set off first.
      final up = (foot - specimen.hy[i]) / tall;
      _delay[i] = _spread * (0.8 * up + 0.2 * rng.nextDouble());
      _theta[i] = rng.nextDouble() * math.pi * 2;
      _rho[i] = 0.42 + 0.56 * math.sqrt(rng.nextDouble());
      _swing[i] = 1.5 + rng.nextDouble() * 1.3;
      _cool[i] = 0.52 + rng.nextDouble() * 0.26;
    }
  }

  /// The sprite read into grains, round the centre it stands on.
  final SpecimenGrains specimen;

  /// From the first grain stirring to the last one home.
  static const double seconds = 2.4;

  static const double _spread = 0.45, _travel = 1 - _spread;

  final GrainBatch _b;
  final Float32List _theta, _rho, _delay, _swing, _cool;

  /// [t] of the way through the pour (1 and on: all home), on a canvas
  /// already moved to the rift's centre, which is where the sprite stands.
  /// [fade] takes it away as the sprite takes over. [colors] stand in for
  /// the read ones, for a sprite whose colors have moved on since it was
  /// read (a prismatic one turning through its hues).
  void paint(
    Canvas canvas,
    double rr,
    double core,
    double t,
    RiftPalette pal, {
    double fade = 1,
    List<Color>? colors,
  }) {
    if (fade <= 0 || specimen.length == 0) return;
    final b = _b..clear();
    final own = colors ?? specimen.tones;
    final tones = specimen.tones.length;
    final born = tones, hot = tones + 1, trail = tones + 2;
    for (var i = 0; i < specimen.length; i++) {
      final u = (t - _delay[i]) / _travel;
      if (u <= 0) continue;
      if (u >= 1) {
        b.add(specimen.tone[i], specimen.hx[i], specimen.hy[i]);
        continue;
      }
      final p = _at(i, u, rr, core);
      b.add(
        u < 0.12 ? born : (u < _cool[i] ? hot : specimen.tone[i]),
        p.dx,
        p.dy,
      );
      if (u < 0.9) {
        for (var k = 1; k <= 2; k++) {
          final v = u - 0.05 * k;
          if (v <= 0) break;
          final q = _at(i, v, rr, core);
          b.add(trail + k - 1, q.dx, q.dy);
        }
      }
    }
    final d = math.max(1.0, specimen.step * 1.12);
    b.draw(
      canvas,
      trail + 1,
      d * 0.8,
      pal.tones[3].withValues(alpha: 0.14 * fade),
    );
    b.draw(canvas, trail, d * 0.85, pal.tones[3].withValues(alpha: 0.3 * fade));
    b.draw(canvas, born, d, pal.tones[2].withValues(alpha: 0.55 * fade));
    b.draw(canvas, hot, d, pal.tones[4].withValues(alpha: fade));
    for (var k = 0; k < tones; k++) {
      b.draw(canvas, k, d, own[k].withValues(alpha: fade));
    }
  }

  /// Where grain [i] is, [u] of the way home.
  Offset _at(int i, double u, double rr, double core) {
    // In the disk, turning inward with it...
    final a = _theta[i] + _swing[i] * (1 - (1 - u) * (1 - u));
    final r = rr * (_rho[i] + (core * 1.2 - _rho[i]) * math.min(1.0, u * 1.4));
    final x0 = math.cos(a) * r;
    final y0 = math.sin(a) * r * RiftVortexField.flat;
    final dx = x0 * _turnCos - y0 * _turnSin;
    final dy = x0 * _turnSin + y0 * _turnCos;
    // ...then leaving it for its own place.
    final w = _smooth((u - 0.25) / 0.75);
    return Offset(
      dx + (specimen.hx[i] - dx) * w,
      dy + (specimen.hy[i] - dy) * w,
    );
  }
}
