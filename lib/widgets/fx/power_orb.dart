// lib/widgets/fx/power_orb.dart
//
// A POWER ORB, in grains: a small sphere of its stat's light, lit from the
// upper left, with a bright heart, turning — the same particle language as
// the cultivation sphere and the gold vault's sun. Each stat moves its own
// way, so the four read apart before their colors do:
//
//   speed         turns fast, with a comet of grains whipping round it
//   intelligence  a tipped disk of grains orbiting it, as round an atom
//   strength      dense and slow, swelling on a heartbeat, embers lifting
//   beauty        soft and gentle, glinting often
//
// One painter for every place an orb is drawn — the Enhance tray, the drag
// under your finger, the shop, the inventory, the infusion itself and the
// dock icon. No blur: points in batches and radial gradients.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints power orbs. Static: every orb shares the sphere's layout.
abstract final class PowerOrbPaint {
  static const int _n = 240;

  // A unit sphere of grains, laid out once: shell-weighted so it reads as a
  // ball, each with its own latitude, starting longitude and twinkle phase.
  static final List<double> _lat = [
    for (var i = 0; i < _n; i++) math.asin(2 * _h(i, 1) - 1),
  ];
  static final List<double> _lon = [
    for (var i = 0; i < _n; i++) _h(i, 2) * math.pi * 2,
  ];
  static final List<double> _rad = [
    for (var i = 0; i < _n; i++) 0.18 + 0.74 * math.pow(_h(i, 3), 0.6),
  ];
  static final List<double> _ph = [for (var i = 0; i < _n; i++) _h(i, 4)];

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  // Buckets: far side (3), near side by light (6), glints, extras (orbit
  // grains far / near), embers.
  static const int _farB = 0, _nearB = 3, _glintB = 9;
  static const int _extraFarB = 10, _extraNearB = 11, _emberB = 12;
  static final GrainBatch _b = GrainBatch(13);
  static final Paint _p = Paint();

  static final Map<(int, int), Shader> _glowShaders = {};
  static final Map<(int, int, int), Shader> _bodyShaders = {};
  static final Map<(int, int), Shader> _rimShaders = {};
  static final Map<(int, int), Shader> _heartShaders = {};
  static final Map<(int, int), Shader> _shineShaders = {};

  static double _spin(AlchemicalPowerupType t) => switch (t) {
    AlchemicalPowerupType.speed => 1.6,
    AlchemicalPowerupType.intelligence => 0.55,
    AlchemicalPowerupType.strength => 0.35,
    AlchemicalPowerupType.beauty => 0.45,
  };

  /// The orb's tones, deep to white, from its color.
  static List<Color> _tones(Color c) => [
    Color.lerp(c, const Color(0xFF07060B), 0.62)!,
    Color.lerp(c, const Color(0xFF07060B), 0.32)!,
    c,
    Color.lerp(c, const Color(0xFFFFFFFF), 0.32)!,
    Color.lerp(c, const Color(0xFFFFFFFF), 0.6)!,
    Color.lerp(c, const Color(0xFFFFFFFF), 0.86)!,
  ];

  static final Map<int, List<Color>> _toneCache = {};

  /// Paints [type]'s orb round [c] at radius [r] at time [t].
  ///
  /// [lit] 0..1 dims an orb that cannot be used. [fade] scales every alpha.
  /// [grains] scales how many are drawn — fewer for a tiny orb.
  static void paint(
    Canvas canvas,
    Offset c,
    double r,
    AlchemicalPowerupType type,
    double t, {
    double lit = 1,
    double fade = 1,
    double glow = 1,
    double bright = 0,
  }) {
    if (r <= 0 || fade <= 0) return;
    final color = type.color;
    final tones = _toneCache.putIfAbsent(color.toARGB32(), () => _tones(color));
    final b = _b..clear();
    final f = fade.clamp(0.0, 1.0);
    final dim = lit.clamp(0.0, 1.0);

    // A strength orb swells on a heartbeat.
    var rr = r;
    if (type == AlchemicalPowerupType.strength) {
      final beat = (t % 1.9) / 1.9;
      rr *= 1 + 0.05 * math.exp(-beat * 7);
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);

    // ── its light on what is round it ──
    final glowR = rr * 2.0;
    _p
      ..shader = _glowShaders.putIfAbsent(
        (glowR.round(), color.toARGB32()),
        () => ui.Gradient.radial(
          Offset.zero,
          glowR,
          [
            color.withValues(alpha: 0.34),
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, f * (0.35 + 0.65 * dim) * glow);
    canvas.drawCircle(Offset.zero, glowR, _p);
    _p.shader = null;

    // ── the sphere ──
    const tip = 0.38;
    final ct = math.cos(tip), st = math.sin(tip);
    final spin = t * _spin(type);
    // A tiny orb shows fewer grains; it cannot resolve more.
    final count = (_n * (rr / 30).clamp(0.35, 1.0)).round();
    final glintRate = type == AlchemicalPowerupType.beauty ? 0.03 : 0.008;
    for (var i = 0; i < count; i++) {
      final lat = _lat[i];
      // Faster round its middle than its poles.
      final lon = _lon[i] + spin * (1 - 0.3 * math.sin(lat) * math.sin(lat));
      final cl = math.cos(lat);
      final pr = _rad[i] * rr;
      final px = pr * cl * math.cos(lon);
      final py = pr * math.sin(lat);
      final pz = pr * cl * math.sin(lon);
      final y = py * ct + pz * st;
      final z = pz * ct - py * st;
      // Lit from the upper left and front.
      var light = (-0.45 * px - 0.6 * y + 0.66 * z) / (rr * 1.0) * 0.5 + 0.5;
      light = (light * light * (3 - 2 * light)).clamp(0.0, 1.0);
      // The far side shows dimmer through the glass.
      if (z < 0) {
        b.add(_farB + (light * 2.99).floor(), px, y);
        continue;
      }
      if ((t * 0.3 + _ph[i] * 7.7) % 1.0 < glintRate && light > 0.4) {
        b.add(_glintB, px, y);
        continue;
      }
      // Bright inside the dark glass; white is for the glints.
      b.add(_nearB + 2 + (light * 2.99).floor(), px, y);
    }

    // ── its signature ──
    switch (type) {
      case AlchemicalPowerupType.speed:
        // A comet: a head and a tail, whipping round just off the surface.
        for (var k = 0; k < 16; k++) {
          final a = t * 4.2 - k * 0.09;
          final orbit = rr * 1.22;
          final x = math.cos(a) * orbit;
          final yy = math.sin(a) * orbit * 0.38;
          final x2 = x * math.cos(-0.5) - yy * math.sin(-0.5);
          final y2 = x * math.sin(-0.5) + yy * math.cos(-0.5);
          b.add(math.sin(a) > 0 ? _extraNearB : _extraFarB, x2, y2);
        }
      case AlchemicalPowerupType.intelligence:
        // A tipped disk orbiting it.
        for (var k = 0; k < 34; k++) {
          final rho = 1.28 + 0.18 * _h(k, 9);
          final a = _h(k, 8) * math.pi * 2 + t * 1.1 / rho;
          final x = math.cos(a) * rho * rr;
          final yy = math.sin(a) * rho * rr * 0.3;
          final x2 = x * math.cos(0.42) - yy * math.sin(0.42);
          final y2 = x * math.sin(0.42) + yy * math.cos(0.42);
          b.add(math.sin(a) > 0 ? _extraNearB : _extraFarB, x2, y2);
        }
      case AlchemicalPowerupType.strength:
        // Embers lifting off its crown.
        for (var k = 0; k < 10; k++) {
          final p = (t * (0.35 + 0.2 * _h(k, 6)) + _h(k, 5)) % 1.0;
          final a = -math.pi / 2 + (_h(k, 7) - 0.5) * 1.6;
          final d = rr * (0.95 + 0.7 * p);
          b.add(_emberB, math.cos(a) * d, math.sin(a) * d - p * rr * 0.3);
        }
      case AlchemicalPowerupType.beauty:
        break;
    }

    final d = (rr * 0.075).clamp(1.0, 2.6);
    Color a(Color c, [double k = 1]) =>
        c.withValues(alpha: (c.a * k * f * (0.4 + 0.6 * dim)).clamp(0.0, 1.0));

    b.draw(canvas, _extraFarB, d * 0.85, a(tones[2], 0.55));
    // The glass: dark and tinted, so the light inside it glows.
    final bodyR = rr.roundToDouble();
    _p
      // [bright] lifts the glass for an icon among painted ones.
      ..shader = _bodyShaders.putIfAbsent(
        (bodyR.round(), color.toARGB32(), (bright * 10).round()),
        () => ui.Gradient.radial(
          Offset(-bodyR * 0.2, -bodyR * 0.25),
          bodyR * 1.25,
          [
            Color.lerp(
              color,
              const Color(0xFF07060B),
              0.45 - 0.35 * bright,
            )!.withValues(alpha: 0.6 + 0.3 * bright),
            Color.lerp(
              color,
              const Color(0xFF07060B),
              0.72 - 0.4 * bright,
            )!.withValues(alpha: 0.78 + 0.15 * bright),
            Color.lerp(
              color,
              const Color(0xFF07060B),
              0.86 - 0.3 * bright,
            )!.withValues(alpha: 0.92),
          ],
          const [0.0, 0.6, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, f);
    canvas.drawCircle(Offset.zero, rr, _p);
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, _farB + k, d * 0.8, a(tones[k + 1], 0.6));
    }
    // The light inside it.
    final heartR = rr * 0.8;
    _p
      ..shader = _heartShaders.putIfAbsent(
        (heartR.round(), color.toARGB32()),
        () => ui.Gradient.radial(
          Offset.zero,
          heartR,
          [
            Color.lerp(color, Colors.white, 0.55)!.withValues(alpha: 0.7),
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.45, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, f * (0.3 + 0.7 * dim));
    canvas.drawCircle(Offset.zero, heartR, _p);
    _p.shader = null;
    for (var k = 0; k < 6; k++) {
      b.draw(canvas, _nearB + k, d, a(tones[k], 0.9));
    }
    // Its edge catches the light, lower right more: a lens, not a disc.
    _p
      ..shader = _rimShaders.putIfAbsent(
        (bodyR.round(), color.toARGB32()),
        () => ui.Gradient.radial(
          Offset(bodyR * 0.12, bodyR * 0.14),
          bodyR * 1.02,
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: 0),
            Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: 0.55),
            color.withValues(alpha: 0),
          ],
          const [0.0, 0.8, 0.95, 1.0],
        ),
      )
      ..color = Color.fromRGBO(0, 0, 0, f * (0.35 + 0.65 * dim));
    canvas.drawCircle(Offset.zero, rr * 1.04, _p);
    _p.shader = null;
    // A soft catchlight, upper left: glass.
    final shineR = rr * 0.42;
    canvas.save();
    canvas.translate(-rr * 0.34, -rr * 0.4);
    _p
      ..shader = _shineShaders.putIfAbsent(
        (shineR.round(), 0),
        () => ui.Gradient.radial(Offset.zero, shineR, const [
          Color(0xCCFFFFFF),
          Color(0x00FFFFFF),
        ]),
      )
      ..color = Color.fromRGBO(0, 0, 0, f * (0.4 + 0.6 * dim));
    canvas.drawCircle(Offset.zero, shineR, _p);
    _p.shader = null;
    canvas.restore();
    b.draw(canvas, _glintB, d * 2.3, a(const Color(0x40FFFFFF)));
    b.draw(canvas, _glintB, d * 1.25, a(Colors.white));
    b.draw(canvas, _extraNearB, d * 1.05, a(tones[4]));
    b.draw(canvas, _emberB, d * 0.95, a(tones[4], 0.8));
    canvas.restore();
  }
}

/// A power orb as a widget. Animated ones share one clock (see
/// [GlyphClock]); a still one is a single frame.
class PowerOrb extends StatefulWidget {
  const PowerOrb({
    super.key,
    required this.type,
    required this.size,
    this.animate = true,
    this.lit = true,
  });

  final AlchemicalPowerupType type;

  /// The orb's box; the sphere's radius is a third of it, so its light and
  /// its orbiters fit inside.
  final double size;
  final bool animate;

  /// False dims an orb that cannot be used now.
  final bool lit;

  @override
  State<PowerOrb> createState() => _PowerOrbState();
}

class _PowerOrbState extends State<PowerOrb> with GlyphClockLease {
  /// Off while a route covers it or it is scrolled out of a gated list: the
  /// shared clock is a bare ticker, deaf to TickerMode, so the orb asks.
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant PowerOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        painter: _PowerOrbPainter(
          widget.type,
          lit: widget.lit,
          clock: glyphClock,
          // Each type starts its turn somewhere else, so a row of four is
          // not four copies in step.
          offset: widget.type.index * 1.7,
        ),
      ),
    );
  }
}

class _PowerOrbPainter extends CustomPainter {
  _PowerOrbPainter(
    this.type, {
    required this.lit,
    required this.clock,
    required this.offset,
  }) : super(repaint: clock);

  final AlchemicalPowerupType type;
  final bool lit;
  final ValueListenable<double>? clock;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) => PowerOrbPaint.paint(
    canvas,
    size.center(Offset.zero),
    size.shortestSide * 0.34,
    type,
    (clock?.value ?? 0) + offset,
    lit: lit ? 1 : 0.35,
  );

  @override
  bool shouldRepaint(_PowerOrbPainter old) =>
      old.type != type || old.lit != lit || old.clock != clock;
}
