// lib/widgets/fx/kin_pour.dart
//
// KIN, POURED IN — spare Alchemons of the same species given up to another.
//
//   Each kin in the tray comes apart into grains of itself, one after
//   another, and its grains lift and arc up into the specimen, warming
//   towards gold as they go. Where they land they sink into its body: each
//   grain comes to rest on a grain of the specimen and is gone. Kin are the
//   same species, so their grains are the specimen's own colours.
//
//   Nothing is drawn round the specimen. The stream goes into it.
//
// Plain Dart and no blur: the screen reads the specimen into grains, hands
// over where each kin card sits, and drives [KinPourPainter] with one
// controller. The power-up after it is [InfusionPainter]'s.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/infusion_particles.dart';
import 'package:flutter/material.dart';

/// Where every grain of a pour starts, when it leaves, and where it lands.
class KinPour {
  KinPour({
    required this.sources,
    required this.body,
    required this.target,
    this.grainsPerKin = 220,
  }) {
    final kin = math.max(1, sources.length);
    final per = math.min(grainsPerKin, 1100 ~/ kin);
    final n = per * sources.length;
    _src = Uint8List(n);
    _sx = Float32List(n);
    _sy = Float32List(n);
    _dest = Int32List(n);
    _leave = Float32List(n);
    _lift = Float32List(n);
    _swing = Float32List(n);
    final rng = math.Random(17);
    final g = body.grains;
    // One kin after another; the last one still leaves in time to land.
    final stagger = math.min(0.14, 0.34 / kin);
    for (var i = 0; i < n; i++) {
      final k = i ~/ per;
      _src[i] = k;
      // A card-sized cloud: the kin's sprite is about 44 px.
      final a = rng.nextDouble() * math.pi * 2;
      final r = math.sqrt(rng.nextDouble()) * 18;
      _sx[i] = math.cos(a) * r;
      _sy[i] = math.sin(a) * r * 1.1;
      _dest[i] = g.length == 0 ? 0 : rng.nextInt(g.length);
      // Top grains of the cloud first, so it comes apart from the head down.
      final order = ((_sy[i] + 20) / 40).clamp(0.0, 1.0);
      _leave[i] = k * stagger + order * 0.12 + rng.nextDouble() * (0.28 - 0.12);
      _lift[i] = 0.7 + rng.nextDouble() * 0.6;
      _swing[i] = (rng.nextDouble() - 0.5) * 2;
    }
    _travel = 0.42;
    final last = (kin - 1) * stagger + 0.28;
    // Scale so the last grain lands by 0.92.
    _scale = math.min(1.0, (0.92 - _travel) / math.max(0.01, last));
  }

  /// Each kin card's centre, on the painter's canvas.
  final List<Offset> sources;

  /// The specimen, read into grains.
  final InfusionBody body;

  /// The specimen's centre on the painter's canvas.
  final Offset target;
  final int grainsPerKin;

  late final Uint8List _src;
  late final Float32List _sx, _sy, _leave, _lift, _swing;
  late final Int32List _dest;
  late final double _travel, _scale;

  int get length => _src.length;

  /// How far kin [k] has come apart at [t]: 0 whole, 1 gone.
  double kinGone(int k, double t) {
    final kin = math.max(1, sources.length);
    final stagger = math.min(0.14, 0.34 / kin);
    final start = k * stagger * _scale;
    final end = start + 0.28 * _scale + 0.06;
    return ((t - start) / (end - start)).clamp(0.0, 1.0);
  }
}

/// Paints one frame of a pour.
class KinPourPainter extends CustomPainter {
  KinPourPainter({required this.pour, required this.t, required this.color});

  final KinPour pour;

  /// 0..1 over the whole pour.
  final double t;

  /// What the grains warm towards as they arrive.
  final Color color;

  static final GrainBatch _b = GrainBatch(32);
  static final Paint _p = Paint();

  // Buckets: kin tones (up to 20), warm (6), landing glints.
  static const int _warmB = 20, _glintB = 26, _haloB = 27;

  static double _smooth(double e0, double e1, double x) {
    final u = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final b = _b..clear();
    final g = pour.body.grains;
    if (g.length == 0) return;
    final tones = g.tones;
    final tc = math.min(tones.length, 20);
    final target = pour.target;
    final top = target.dy + pour.body.top;
    var landed = 0;

    for (var i = 0; i < pour.length; i++) {
      final src = pour.sources[pour._src[i]];
      final leave = pour._leave[i] * pour._scale;
      final d = pour._dest[i];
      final tone = math.min(g.tone[d], tc - 1);
      final local = (t - leave) / pour._travel;
      final sx = src.dx + pour._sx[i];
      final sy = src.dy + pour._sy[i];
      if (local <= 0) {
        // Still the kin: grains sitting in its card until their turn, and
        // only once it has begun to go (before that the sprite shows).
        if (pour.kinGone(pour._src[i], t) > 0) b.add(tone, sx, sy);
        continue;
      }
      final dx = target.dx + g.hx[d];
      final dy = target.dy + g.hy[d];
      if (local >= 1) {
        // Sunk in: a brief warm glint where it came to rest, then nothing.
        final after = (local - 1) * pour._travel;
        if (after < 0.05) b.add(_glintB, dx, dy);
        landed++;
        continue;
      }
      final e = Curves.easeInOutCubic.transform(local);
      // Up out of the tray, over, and down into the body from above.
      // Fanned wide, so the kin rise as a plume rather than a thread.
      final cx = (sx + dx) / 2 + pour._swing[i] * 110;
      final cy = math.min(sy, top) - 40 * pour._lift[i];
      final m = 1 - e;
      final px = m * m * sx + 2 * m * e * cx + e * e * dx;
      final py = m * m * sy + 2 * m * e * cy + e * e * dy;
      if (local < 0.45) {
        b.add(tone, px, py);
      } else {
        b.add(_warmB + (tone * 6) ~/ math.max(1, tc), px, py);
      }
      if (local > 0.1 && local < 0.9 && (i % 5) == 0) b.add(_haloB, px, py);
    }

    // The specimen taking it in: a faint warmth as the grains arrive.
    final soak = landed / math.max(1, pour.length);
    final glow =
        math.sin(math.pi * soak.clamp(0.0, 1.0)) * 0.8 +
        _smooth(0.0, 0.4, soak) * 0.2;
    if (glow > 0.01) {
      final r = math.max(60.0, (pour.body.bottom - pour.body.top) * 0.62);
      canvas.drawCircle(
        target,
        r,
        _p
          ..shader = ui.Gradient.radial(
            target,
            r,
            [
              color.withValues(alpha: 0.2 * glow),
              color.withValues(alpha: 0.06 * glow),
              color.withValues(alpha: 0),
            ],
            const [0.0, 0.5, 1.0],
          ),
      );
      _p.shader = null;
    }

    final dot = math.max(1.6, g.step * 1.15);
    b.draw(canvas, _haloB, dot * 3.2, color.withValues(alpha: 0.10));
    for (var k = 0; k < tc; k++) {
      b.draw(canvas, k, dot, tones[k]);
    }
    for (var k = 0; k < 6; k++) {
      final rep = tones[((k + 0.5) * tc / 6).floor().clamp(0, tc - 1)];
      b.draw(
        canvas,
        _warmB + k,
        dot * 1.1,
        Color.lerp(rep, Color.lerp(color, Colors.white, 0.1 * k)!, 0.55)!,
      );
    }
    b.draw(canvas, _glintB, dot * 2.4, color.withValues(alpha: 0.35));
    b.draw(canvas, _glintB, dot * 1.2, Colors.white.withValues(alpha: 0.9));
  }

  @override
  bool shouldRepaint(KinPourPainter old) =>
      old.t != t || old.pour != pour || old.color != color;
}
