// lib/widgets/fx/rift_vortex.dart
//
// A rift as grains: a tipped disk in its faction's colour falling into a
// black core, turning faster as it falls, with a ring of light hugging the
// core and dust drawn in from the dark. The same rift is the small one out in
// the wilderness (RiftPortalComponent) and the big one its threshold opens
// on (RiftThreshold), so tapping one opens into the other.
//
// Every grain is a point in a batch and every glow a radial gradient — no
// blur, so it is safe in a Flame render loop.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';

/// A rift's colours, drawn from its faction: ink at the disk's cold rim,
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
    this.grains = 1500,
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

  void paint(
    Canvas canvas,
    Size size,
    Offset c,
    double radius,
    RiftPalette pal, {
    Offset? keyFrom,
    double keyFlight = 0,
    double keySize = 52,
    Color? keyColor,
    bool backdrop = true,
  }) {
    final b = _b..clear();
    final o = _ease(open.clamp(0.0, 1.0));
    final rr = radius * (1 + 0.04 * charge);
    final coreR0 = rr * core * (0.3 + 0.7 * o) * (1 + 0.18 * charge);
    final t = time;

    // Falling in: everything spreads out from the core — positions, not
    // grain sizes, so the grains rush past as grains rather than swelling
    // into discs — and each leaves a short trail.
    final fallE = ((dive - 0.25) / 0.75).clamp(0.0, 1.0);
    final zoom = 1 + 11 * fallE * fallE;
    final trail = fallE > 0.02 ? 1 - 0.07 * fallE : 0.0;
    final coreR = coreR0 * zoom;

    if (backdrop) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFF050507),
      );
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);

    // The void: the whole screen when it is the screen; out in the world,
    // a dark tear round the rift, so it reads against a daylit sky.
    final reach = backdrop
        ? size.longestSide * (1 + 0.5 * fallE)
        : rr * 2.1 * o;
    canvas.drawCircle(
      Offset.zero,
      reach,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          reach,
          backdrop
              // Opening with the rift, so a rift that opens out of black
              // (the inside of one, after the fall) does not cut to colour.
              ? [
                  pal.tint.withValues(alpha: o),
                  pal.tint.withValues(alpha: 0.35 * o),
                  const Color(0x00050507),
                ]
              : [
                  pal.tint.withValues(alpha: 0.85),
                  pal.tint.withValues(alpha: 0.4),
                  pal.tint.withValues(alpha: 0),
                ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // ── dust drawn in from the dark ──
    for (var i = 0; i < motes; i++) {
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
    const flat = 0.3, turn = -0.22;
    final ct = math.cos(turn), st = math.sin(turn);
    final glintRate = 0.006 + 0.03 * charge;
    for (var i = 0; i < grains; i++) {
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
    for (var i = 0; i < ringGrains; i++) {
      final seed = (i * 0.7548776) % 1.0;
      final a =
          seed * math.pi * 2 + t * speed * (1.6 + seed) * (1 + 2 * charge);
      final d = coreR * (1.02 + 0.1 * ((i * 0.5698) % 1.0));
      final sa = math.sin(a);
      b.add(sa.abs() > 0.72 ? _ringB + 1 : _ringB, math.cos(a) * d, sa * d);
    }

    final d = (grainSize ?? math.max(1.25, rr * 0.011)) * (1 + 0.4 * fallE);

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

    // ── the key, flying into the core ──
    if (keyFrom != null && keyFlight > 0 && keyFlight < 1) {
      final e = Curves.easeInCubic.transform(keyFlight);
      final to = c;
      final mid = Offset.lerp(keyFrom, to, 0.5)! + Offset(0, -radius * 0.35);
      final m = 1 - e;
      final p = Offset(
        m * m * keyFrom.dx + 2 * m * e * mid.dx + e * e * to.dx,
        m * m * keyFrom.dy + 2 * m * e * mid.dy + e * e * to.dy,
      );
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(math.pi / 2 + e * math.pi * 1.5);
      PortalKeyGlyph.paintGlyph(
        canvas,
        Offset.zero,
        keySize * (1 - 0.8 * e),
        keyColor ?? pal.tones[3],
        t,
        fade: 1 - math.pow(e, 4).toDouble(),
      );
      canvas.restore();
    }

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
