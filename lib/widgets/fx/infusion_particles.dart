// lib/widgets/fx/infusion_particles.dart
//
// AN INFUSION, IN PARTICLES — a power orb (or a potential soul) dropped on a
// specimen.
//
//   The orb lobs up from the tray and into the specimen; a soul rises above
//   its head, burns brighter there for as long as the roll is worth, then
//   plunges in. Then a wave of the stat's light runs up the specimen from its
//   feet, and where it passes the specimen comes apart into grains of
//   itself, lit in that colour, and settles back together.
//
//   Nothing happens round the specimen — no orbit, no rings, no streams
//   wound about it: the user called that cheesy. All of it is the specimen
//   itself, and the one thing dropped into it.
//
// Plain Dart: the screen captures the specimen into [InfusionBody] and
// drives [InfusionPainter] with its two controllers. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/power_orb.dart';
import 'package:alchemons/widgets/fx/soul_wisp.dart';
import 'package:flutter/material.dart';

/// A specimen read into grains, where it stands on the infusion's canvas.
class InfusionBody {
  InfusionBody(this.grains, this.centre) {
    final n = grains.length;
    _dirX = Float32List(n);
    _dirY = Float32List(n);
    _rise = Float32List(n);
    _phase = Float32List(n);
    var minY = double.infinity, maxY = double.negativeInfinity;
    var reach = 1.0;
    for (var i = 0; i < n; i++) {
      minY = math.min(minY, grains.hy[i]);
      maxY = math.max(maxY, grains.hy[i]);
      reach = math.max(reach, grains.hx[i].abs());
    }
    top = minY;
    bottom = maxY;
    halfWidth = reach;
    final span = math.max(1.0, maxY - minY);
    final rng = math.Random(41);
    final cy = (minY + maxY) / 2;
    for (var i = 0; i < n; i++) {
      final dx = grains.hx[i], dy = grains.hy[i] - cy;
      final d = math.sqrt(dx * dx + dy * dy) + 0.001;
      // Mostly up, a little out: it lifts off itself like heat, rather than
      // bursting into a cloud round it.
      final jitter = (rng.nextDouble() - 0.5) * 1.2;
      final a = math.atan2(dy * 0.6, dx) + jitter;
      _dirX[i] = math.cos(a) * 0.45 * (0.5 + 0.5 * (d / reach).clamp(0.0, 1.0));
      _dirY[i] = math.sin(a) * 0.3 - 0.75;
      // 0 at its feet, 1 at its crown: the wave climbs.
      _rise[i] = ((maxY - grains.hy[i]) / span).clamp(0.0, 1.0);
      _phase[i] = rng.nextDouble();
    }
  }

  final SpecimenGrains grains;

  /// Its centre, in the painter's coordinates.
  final Offset centre;

  late final double top, bottom, halfWidth;
  late final Float32List _dirX, _dirY, _rise, _phase;
}

/// Paints one frame of an infusion. Drop-in for the orb painter it replaces:
/// the same controllers and the same roll-driven knobs.
class InfusionPainter extends CustomPainter {
  InfusionPainter({
    required this.progress,
    required this.flash,
    required this.type,
    required this.rollLabel,
    required this.glowBoost,
    required this.isJackpot,
    required this.orbitEndProgress,
    this.deltaLabel,
    this.soulRoll,
    this.body,
  });

  /// The orb's flight, 0..1, then the power-up, 0..1.
  final double progress, flash;
  final AlchemicalPowerupType type;
  final String? rollLabel;
  final double glowBoost;
  final bool isJackpot;

  /// For a soul: when it stops burning above the specimen and plunges.
  final double orbitEndProgress;
  final String? deltaLabel;
  final int? soulRoll;

  /// The specimen as grains, once captured. Without it the infusion plays
  /// round the specimen's sprite instead of through it.
  final InfusionBody? body;

  bool get _isSoul => soulRoll != null;

  /// When the specimen is grains; outside it the sprite shows.
  static bool showsBody(double flash) => flash > 0 && flash < 0.97;

  /// The sprite's opacity under the grains: it fades as they lift and
  /// returns as they settle, so the change between the two never shows.
  static double spriteOpacity(double flash) {
    if (flash <= 0 || flash >= 0.97) return 1;
    return (1 - _smooth(0.0, 0.14, flash) + _smooth(0.8, 0.96, flash)).clamp(
      0.0,
      1.0,
    );
  }

  static final GrainBatch _b = GrainBatch(32);
  static final Paint _p = Paint();

  // Buckets: body tones (up to 20), body lit (6), the orb's tail (2),
  // glints.
  static const int _litB = 20, _trailB = 26, _tailB = 27, _glintB = 28;

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final b = _b..clear();
    final orbitCentre = Offset(size.width / 2, size.height * 0.47);
    final bd = body;
    final heart = bd?.centre ?? orbitCentre;
    final color = type.color;
    final hot = Color.lerp(color, Colors.white, 0.55)!;
    final time = progress * 2.2 + flash * 1.4;

    // ── what was dropped, in flight ──
    if (flash <= 0) {
      final at = _flightAt(orbitCentre, size, progress);
      if (_isSoul) {
        // Burning brighter the longer it hangs there.
        final charge = _smooth(0.2, orbitEndProgress, progress);
        SoulWispPaint.paint(
          canvas,
          at,
          46 * (1 + 0.35 * charge) * glowBoost.clamp(1.0, 1.4),
          color,
          time * 1.6,
          charge: charge,
        );
        return;
      }
      final orbR = _orbRadius(progress);
      // A short tail of its own dust.
      for (var k = 1; k <= 10; k++) {
        final pk = progress - k * 0.012;
        if (pk <= 0.02) break;
        final p = _flightAt(orbitCentre, size, pk);
        final wob = (k * 0.618) % 1.0 - 0.5;
        final spread = orbR * (0.25 + 0.04 * k);
        b.add(
          k < 5 ? _trailB : _tailB,
          p.dx + wob * spread,
          p.dy + ((k * 0.382) % 1.0 - 0.5) * spread,
        );
      }
      b.draw(canvas, _tailB, 1.6, color.withValues(alpha: 0.4));
      b.draw(canvas, _trailB, 2.0, hot.withValues(alpha: 0.75));
      PowerOrbPaint.paint(canvas, at, orbR, type, time * 2, glow: 1.1);
      return;
    }

    final u = flash.clamp(0.0, 1.0);
    final boost = glowBoost.clamp(1.0, 3.6);
    final roll = soulRoll ?? 0;

    // ── its light on the stage, swelling as the wave climbs ──
    final swell = math.sin(math.pi * math.min(1.0, u / 0.85));
    // Faint, and close: its light falling on the specimen, not a halo.
    final poolR = (70 + 30 * swell) * boost.clamp(1.0, 1.6);
    canvas.drawCircle(
      heart,
      poolR,
      _p
        ..shader = ui.Gradient.radial(
          heart,
          poolR,
          [
            Color.lerp(
              color,
              Colors.white,
              0.3,
            )!.withValues(alpha: 0.24 * swell),
            color.withValues(alpha: 0.08 * swell),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    _p.shader = null;

    // ── the specimen, coming apart where the wave passes ──
    if (bd != null && showsBody(u)) {
      final g = bd.grains;
      final tones = g.tones;
      // Capped: past this the grains thrown off form a band round it
      // instead of a cloud of it.
      final amp = (8 + 1.6 * roll) * boost.clamp(1.0, 1.3);
      // The wave climbs from the feet over the first 55%; each grain's
      // lift lasts about a third of the infusion.
      const climb = 0.55, width = 0.38;
      for (var i = 0; i < g.length; i++) {
        final start = bd._rise[i] * climb;
        final x = (u - start) / width;
        final pulse = x <= 0 || x >= 1 ? 0.0 : math.sin(math.pi * x);
        final ph = bd._phase[i];
        // Most lift off a little; a few come right away and drift up before
        // falling back in — the specimen briefly a cloud of itself.
        final loose = ph > 0.86;
        // Each its own distance, so what comes off is a cloud, not a shell.
        final reach = (bd._dirX[i] * 7.3 + ph * 3.1) % 1.0;
        final lift =
            pulse * amp * (loose ? 1.4 + 1.2 * reach : 0.4 + 0.8 * reach);
        final px = bd.centre.dx + g.hx[i] + bd._dirX[i] * lift;
        final py =
            bd.centre.dy +
            g.hy[i] +
            bd._dirY[i] * lift -
            (loose ? pulse * amp * (0.8 + reach) : 0);
        if (pulse > 0.9 && ph > 0.8) {
          b.add(_glintB, px, py);
        } else if (pulse > 0.2) {
          // Its own colours, lit through with the stat's as it passes.
          b.add(_litB + (g.tone[i] * 6) ~/ math.max(1, tones.length), px, py);
        } else {
          b.add(math.min(g.tone[i], 19), px, py);
        }
      }
      // Closed up, so at rest the grains read as the sprite they replace.
      final d = math.max(1.3, g.step * 1.22);
      for (var k = 0; k < math.min(tones.length, 20); k++) {
        b.draw(canvas, k, d, tones[k]);
      }
      for (var k = 0; k < 6; k++) {
        // The body's tones, sixths of them, pulled towards the stat's light.
        final rep =
            tones[((k + 0.5) * tones.length / 6).floor().clamp(
              0,
              tones.length - 1,
            )];
        b.draw(
          canvas,
          _litB + k,
          d * 1.05,
          // Towards the stat's own colour, not towards white: the specimen
          // stays itself, lit.
          Color.lerp(rep, Color.lerp(color, Colors.white, 0.12 * k)!, 0.42)!,
        );
      }
    }

    b.draw(canvas, _glintB, 3.6, const Color(0x40FFFFFF));
    b.draw(canvas, _glintB, 2.0, Colors.white);

    // The moment it lands: a bloom at the heart, wide and faint and quick —
    // a light, not a ring.
    final bloom = 1 - _smooth(0.0, 0.3, u);
    if (bloom > 0) {
      final r = 30 + 90 * (1 - bloom);
      canvas.drawCircle(
        heart,
        r * boost.clamp(1.0, 1.8),
        _p
          ..shader = ui.Gradient.radial(
            heart,
            r * boost.clamp(1.0, 1.8),
            [
              Colors.white.withValues(alpha: 0.65 * bloom),
              color.withValues(alpha: 0.3 * bloom),
              color.withValues(alpha: 0),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
      _p.shader = null;
    }

    _labels(canvas, orbitCentre, u);
  }

  void _labels(Canvas canvas, Offset centre, double u) {
    final glow = Color.lerp(type.color, Colors.white, 0.2)!;
    if (rollLabel != null) {
      final rp = TextPainter(
        text: TextSpan(
          text: rollLabel!,
          style: TextStyle(
            fontFamily: 'monospace',
            color: glow.withValues(alpha: 0.95),
            fontSize: isJackpot ? 15 : 12.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.2,
            shadows: const [
              Shadow(color: Color(0xCC000000), offset: Offset(0, 1.5)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      rp.paint(canvas, Offset(centre.dx - rp.width / 2, centre.dy - 150));
    }
    if (deltaLabel != null) {
      final rise = Curves.easeOut.transform(u);
      final dp = TextPainter(
        text: TextSpan(
          text: deltaLabel!,
          style: TextStyle(
            fontFamily: 'monospace',
            color: Colors.white.withValues(
              alpha: 0.95 * _smooth(0.05, 0.25, u),
            ),
            fontSize: isJackpot ? 28 : 22,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: glow.withValues(alpha: 0.9), offset: Offset.zero),
              const Shadow(color: Color(0xCC000000), offset: Offset(0, 2)),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      dp.paint(
        canvas,
        Offset(centre.dx - dp.width / 2, centre.dy - 108 - rise * 22),
      );
    }
  }

  double _orbRadius(double p) {
    if (p < 0.22) {
      return ui.lerpDouble(5, 16, Curves.easeOut.transform(p / 0.22))!;
    }
    final m = (p - 0.22) / 0.78;
    return ui.lerpDouble(16, 22, math.min(m / 0.6, 1.0))! *
        (isJackpot ? 1.15 : 1.0);
  }

  /// The flight. An orb lobs up from below the stage, over, and down into
  /// the specimen's heart. A soul rises to above its head, hangs there
  /// burning (to [orbitEndProgress]), and plunges in.
  Offset _flightAt(Offset centre, Size size, double p) {
    final heart = body?.centre ?? centre;
    final from = Offset(centre.dx + 26, size.height + 10);
    Offset quad(Offset a, Offset c, Offset b, double t) {
      final m = 1 - t;
      return a * (m * m) + c * (2 * m * t) + b * (t * t);
    }

    final bodyTop = body == null ? heart.dy - 80 : body!.centre.dy + body!.top;
    if (!_isSoul) {
      final t = Curves.easeInOutCubic.transform(p.clamp(0.0, 1.0));
      final over = Offset(heart.dx - 40, bodyTop - 70);
      return quad(from, over, heart, t);
    }
    final hover = Offset(heart.dx, bodyTop - 46);
    const rise = 0.22;
    if (p < rise) {
      final t = Curves.easeOutCubic.transform(p / rise);
      return quad(from, Offset(heart.dx + 60, hover.dy + 40), hover, t);
    }
    if (p < orbitEndProgress) {
      // A slow bob while it burns.
      final t = (p - rise) / math.max(0.01, orbitEndProgress - rise);
      return hover + Offset(0, math.sin(t * math.pi * 2) * 4);
    }
    final t = Curves.easeInCubic.transform(
      ((p - orbitEndProgress) / math.max(0.01, 1 - orbitEndProgress)).clamp(
        0.0,
        1.0,
      ),
    );
    return Offset.lerp(hover, heart, t)!;
  }

  @override
  bool shouldRepaint(covariant InfusionPainter old) =>
      old.progress != progress ||
      old.flash != flash ||
      old.type != type ||
      old.body != body ||
      old.deltaLabel != deltaLabel ||
      old.rollLabel != rollLabel ||
      old.soulRoll != soulRoll ||
      old.orbitEndProgress != orbitEndProgress ||
      old.glowBoost != glowBoost;
}
