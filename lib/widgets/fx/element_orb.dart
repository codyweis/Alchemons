// lib/widgets/fx/element_orb.dart
//
// AN ELEMENT ON ITS OWN: a turning ball of its grains in dark glass, lit
// from inside — the power orb's material in the element's own shades.
//
// For where an element is shown with no creature to be it: the Codex's
// table (one still frame) and its stage, where the ball comes apart into the
// element's form ([EssenceField]) and gathers back. [ElementOrb.grainsAt]
// hands the grains over exactly where they stand, so the change never shows.
//
// Each element turns at its own pace and has a small habit at rest — fire
// and lava shed embers, lightning flickers, ice and crystal catch the light,
// blood swells on a heartbeat, dark turns the other way.
//
// Points in batches and radial gradients; no blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/rendering.dart';

/// How an element's orb behaves at rest.
class _Habit {
  const _Habit({
    this.spin = 0.45,
    this.glint = 0.008,
    this.embers = 0,
    this.beat = 0,
    this.flicker = 0,
  });

  /// Radians a second; below zero it turns the other way.
  final double spin;

  /// The share of its lit grains catching the light at any moment.
  final double glint;

  /// Grains lifting off its crown.
  final int embers;

  /// How far it swells on a heartbeat.
  final double beat;

  /// The share of its grains flashing at once.
  final double flicker;
}

const _Habit _defaultHabit = _Habit();
const Map<EssenceElement, _Habit> _habits = {
  EssenceElement.fire: _Habit(spin: 0.8, embers: 10),
  EssenceElement.water: _Habit(spin: 0.5, glint: 0.012),
  EssenceElement.earth: _Habit(spin: 0.2, glint: 0),
  EssenceElement.air: _Habit(spin: 1.25, glint: 0.01),
  EssenceElement.steam: _Habit(spin: 0.4, glint: 0),
  EssenceElement.lava: _Habit(spin: 0.25, embers: 6, glint: 0),
  EssenceElement.lightning: _Habit(spin: 0.9, flicker: 0.022, glint: 0),
  EssenceElement.mud: _Habit(spin: 0.22, glint: 0.003),
  EssenceElement.ice: _Habit(spin: 0.3, glint: 0.03),
  EssenceElement.dust: _Habit(spin: 0.6, glint: 0),
  EssenceElement.crystal: _Habit(spin: 0.28, glint: 0.035),
  EssenceElement.plant: _Habit(spin: 0.35, glint: 0.006),
  EssenceElement.poison: _Habit(spin: 0.45, glint: 0.004),
  EssenceElement.spirit: _Habit(spin: 0.6, glint: 0.015),
  EssenceElement.dark: _Habit(spin: -0.45, glint: 0.006),
  EssenceElement.light: _Habit(spin: 0.5, glint: 0.04),
  EssenceElement.blood: _Habit(spin: 0.35, beat: 0.05, glint: 0),
};

/// The tint of each element's glass and the light inside it. Picked so that
/// elements whose grains are alike — air, steam, ice and spirit; earth, mud
/// and dust — still read apart in a table of them.
const Map<EssenceElement, Color> _tints = {
  EssenceElement.fire: Color(0xFFFF7A1A),
  EssenceElement.water: Color(0xFF2E8BD0),
  EssenceElement.earth: Color(0xFFB07A44),
  EssenceElement.air: Color(0xFF8FE0CC),
  EssenceElement.steam: Color(0xFFCDB9CC),
  EssenceElement.lava: Color(0xFFFF4A12),
  EssenceElement.lightning: Color(0xFFFFE45C),
  EssenceElement.mud: Color(0xFF6E5038),
  EssenceElement.ice: Color(0xFF8FC4FF),
  EssenceElement.dust: Color(0xFFE0CDA6),
  EssenceElement.crystal: Color(0xFF8A68FF),
  EssenceElement.plant: Color(0xFF5FC46B),
  EssenceElement.poison: Color(0xFF8E52D6),
  EssenceElement.spirit: Color(0xFFE6DCFF),
  EssenceElement.dark: Color(0xFF5A3A96),
  EssenceElement.light: Color(0xFFFFE08A),
  EssenceElement.blood: Color(0xFFD01E2A),
};

/// An element's color, as its orb shows it.
Color elementOrbTint(EssenceElement e) => _tints[e]!;

/// An element as a ball of its grains in glass.
///
/// [locked] is an element not yet known: the glass with nothing in it.
class ElementOrb {
  ElementOrb(
    this.element, {
    required this.radius,
    int? grains,
    this.locked = false,
  }) : length = locked ? 0 : (grains ?? defaultGrains(radius)),
       _habit = _habits[element] ?? _defaultHabit,
       _ramp = essenceRamp(element) {
    final n = length;
    _lat = Float32List(n);
    _lon = Float32List(n);
    _rad = Float32List(n);
    _ph = Float32List(n);
    for (var i = 0; i < n; i++) {
      _lat[i] = math.asin(2 * _h(i, 1) - 1);
      _lon[i] = _h(i, 2) * math.pi * 2;
      // Shell-weighted, so it reads as a ball and not a disc.
      _rad[i] = 0.22 + 0.78 * math.pow(_h(i, 3), 0.55);
      _ph[i] = _h(i, 4);
    }
    _x = Float32List(n);
    _y = Float32List(n);
    _tone = Uint8List(n);
    color = _tints[element]!;
    tones = [
      // The far side, seen through the glass: dim.
      for (var k = 0; k < _far; k++)
        Color.lerp(_rampAt(0.15 + 0.2 * k), const Color(0xFF07060B), 0.38)!,
      // The near side by how it is lit; white is for the glints.
      for (var k = 0; k < _near; k++) _rampAt(0.3 + 0.62 * k / (_near - 1)),
    ];
  }

  final EssenceElement element;
  final double radius;
  final bool locked;
  final int length;
  final _Habit _habit;
  final List<Color> _ramp;

  /// The element's color, for its light and its glass.
  late final Color color;

  /// Its grains' colors, darkest first: the far side, then the near.
  late final List<Color> tones;

  late final Float32List _lat, _lon, _rad, _ph;
  late final Float32List _x, _y;
  late final Uint8List _tone;
  double _laidAt = double.nan;

  static const int _far = 3, _near = 8;
  static const double _tip = 0.38;

  /// Enough grains that a ball of [r] reads as one.
  static int defaultGrains(double r) =>
      (300 * (r / 30) * (r / 30)).round().clamp(140, 1400);

  /// How wide each grain is drawn.
  double get grainSize => (radius * 0.065).clamp(1.2, 2.4);

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  Color _rampAt(double t) {
    final x = t.clamp(0.0, 1.0) * (_ramp.length - 1);
    final i = x.floor().clamp(0, _ramp.length - 2);
    return Color.lerp(_ramp[i], _ramp[i + 1], x - i)!;
  }

  double _swell(double t) {
    if (_habit.beat == 0) return 1;
    // Lub-dub.
    final beat = (t % 1.6) / 1.6;
    return 1 +
        _habit.beat *
            (math.exp(-beat * 18) + 0.6 * math.exp(-(beat - 0.2).abs() * 22));
  }

  /// Where every grain is at [t], and which tone it shows.
  void _layout(double t) {
    if (t == _laidAt) return;
    _laidAt = t;
    final ct = math.cos(_tip), st = math.sin(_tip);
    final spin = t * _habit.spin;
    final r = radius * _swell(t);
    for (var i = 0; i < length; i++) {
      final lat = _lat[i];
      final sl = math.sin(lat);
      // Faster round its middle than its poles.
      final lon = _lon[i] + spin * (1 - 0.3 * sl * sl);
      final cl = math.cos(lat);
      final pr = _rad[i] * r;
      final px = pr * cl * math.cos(lon);
      final py = pr * sl;
      final pz = pr * cl * math.sin(lon);
      final y = py * ct + pz * st;
      final z = pz * ct - py * st;
      // Lit from the upper left and the front.
      var light = (-0.45 * px - 0.6 * y + 0.66 * z) / r * 0.5 + 0.5;
      light = (light * light * (3 - 2 * light)).clamp(0.0, 1.0);
      _x[i] = px;
      _y[i] = y;
      _tone[i] = z < 0
          ? (light * (_far - 0.01)).floor()
          : _far + (light * (_near - 0.01)).floor();
    }
  }

  /// The grains as they stand at [t], centred on the orb: for a field to
  /// take over from.
  SpecimenGrains grainsAt(double t) {
    _layout(t);
    return SpecimenGrains.points(
      Float32List.fromList(_x),
      Float32List.fromList(_y),
      Uint8List.fromList(_tone),
      tones,
      grainSize / 1.22,
    );
  }

  static const int _glintB = _far + _near, _emberB = _glintB + 1;
  static final GrainBatch _batch = GrainBatch(_emberB + 1);
  static final Paint _p = Paint();

  /// Paints the orb round [c] at time [t].
  ///
  /// [opacity] is the glass and its light, for crossing over to a field
  /// that is drawing the grains ([grains] false leaves them to it). [fade]
  /// scales everything.
  void paint(
    Canvas canvas,
    Offset c,
    double t, {
    double opacity = 1,
    bool grains = true,
    double fade = 1,
  }) {
    final f = fade.clamp(0.0, 1.0);
    final g = (opacity * f).clamp(0.0, 1.0);
    if (f <= 0) return;
    final r = radius * _swell(t);
    final b = _batch..clear();
    canvas.save();
    canvas.translate(c.dx, c.dy);

    if (locked) {
      _paintEmpty(canvas, r, g);
      canvas.restore();
      return;
    }

    // ── its light on what is round it ──
    if (g > 0) {
      final glowR = r * 2.0;
      canvas.drawCircle(
        Offset.zero,
        glowR,
        _p
          ..shader = ui.Gradient.radial(
            Offset.zero,
            glowR,
            [
              color.withValues(alpha: 0.3 * g),
              color.withValues(alpha: 0.09 * g),
              color.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
      _p.shader = null;
    }

    if (grains) {
      _layout(t);
      final q = (t * 12).floor();
      for (var i = 0; i < length; i++) {
        final tone = _tone[i];
        if (tone >= _far) {
          final lit = (tone - _far) / (_near - 1);
          if (_habit.flicker > 0 && _flick(i, q) < _habit.flicker) {
            b.add(_glintB, _x[i], _y[i]);
            continue;
          }
          if (_habit.glint > 0 &&
              lit > 0.4 &&
              (t * 0.3 + _ph[i] * 7.7) % 1.0 < _habit.glint) {
            b.add(_glintB, _x[i], _y[i]);
            continue;
          }
        }
        b.add(tone, _x[i], _y[i]);
      }
      for (var k = 0; k < _habit.embers; k++) {
        final p = (t * (0.35 + 0.2 * _h(k, 6)) + _h(k, 5)) % 1.0;
        final a = -math.pi / 2 + (_h(k, 7) - 0.5) * 1.6;
        final d = r * (0.95 + 0.7 * p);
        b.add(_emberB, math.cos(a) * d, math.sin(a) * d - p * r * 0.3);
      }
    }

    final d = grainSize;
    Color a(Color c, [double k = 1]) =>
        c.withValues(alpha: (c.a * k * f).clamp(0.0, 1.0));

    // The glass: dark and tinted, so the light inside it glows.
    if (g > 0) {
      canvas.drawCircle(
        Offset.zero,
        r,
        _p
          ..shader = ui.Gradient.radial(
            Offset(-r * 0.2, -r * 0.25),
            r * 1.25,
            [
              Color.lerp(
                color,
                const Color(0xFF07060B),
                0.5,
              )!.withValues(alpha: 0.55 * g),
              Color.lerp(
                color,
                const Color(0xFF07060B),
                0.74,
              )!.withValues(alpha: 0.75 * g),
              Color.lerp(
                color,
                const Color(0xFF07060B),
                0.86,
              )!.withValues(alpha: 0.9 * g),
            ],
            const [0.0, 0.6, 1.0],
          ),
      );
      _p.shader = null;
    }
    for (var k = 0; k < _far; k++) {
      b.draw(canvas, k, d * 0.82, a(tones[k], 0.7));
    }
    // The light inside it.
    if (g > 0) {
      final heartR = r * 0.8;
      canvas.drawCircle(
        Offset.zero,
        heartR,
        _p
          ..shader = ui.Gradient.radial(
            Offset.zero,
            heartR,
            [
              Color.lerp(
                color,
                const Color(0xFFFFFFFF),
                0.5,
              )!.withValues(alpha: 0.55 * g),
              color.withValues(alpha: 0.24 * g),
              color.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
      _p.shader = null;
    }
    for (var k = 0; k < _near; k++) {
      b.draw(canvas, _far + k, d, a(tones[_far + k], 0.92));
    }
    if (g > 0) _paintRimAndShine(canvas, r, g, color);
    b.draw(canvas, _glintB, d * 2.3, a(const Color(0x40FFFFFF)));
    b.draw(canvas, _glintB, d * 1.25, a(const Color(0xFFFFFBEA)));
    b.draw(canvas, _emberB, d * 1.05, a(_ramp[3], 0.85));
    canvas.restore();
  }

  static double _flick(int i, int q) {
    var x = (i * 0x27d4eb2d) ^ (q * 0x165667b1);
    x &= 0xffffffff;
    x = ((x ^ (x >> 15)) * 0x85ebca6b) & 0xffffffff;
    x ^= x >> 13;
    return (x & 0xffffff) / 0x1000000;
  }

  /// Its edge catches the light, lower right more — a lens, not a disc —
  /// and a soft catchlight, upper left: glass.
  static void _paintRimAndShine(Canvas canvas, double r, double g, Color tint) {
    canvas.drawCircle(
      Offset.zero,
      r * 1.04,
      _p
        ..shader = ui.Gradient.radial(
          Offset(r * 0.12, r * 0.14),
          r * 1.02,
          [
            tint.withValues(alpha: 0),
            tint.withValues(alpha: 0),
            Color.lerp(
              tint,
              const Color(0xFFFFFFFF),
              0.35,
            )!.withValues(alpha: 0.5 * g),
            tint.withValues(alpha: 0),
          ],
          const [0.0, 0.8, 0.95, 1.0],
        ),
    );
    final shineR = r * 0.42;
    final sc = Offset(-r * 0.34, -r * 0.4);
    canvas.drawCircle(
      sc,
      shineR,
      _p
        ..shader = ui.Gradient.radial(sc, shineR, [
          Color.fromRGBO(255, 255, 255, 0.7 * g),
          const Color(0x00FFFFFF),
        ]),
    );
    _p.shader = null;
  }

  /// Glass with nothing in it yet.
  static void _paintEmpty(Canvas canvas, double r, double g) {
    const smoke = Color(0xFF8C93A3);
    canvas.drawCircle(
      Offset.zero,
      r,
      _p
        ..shader = ui.Gradient.radial(
          Offset(-r * 0.2, -r * 0.25),
          r * 1.25,
          [
            const Color(0xFF2A2E38).withValues(alpha: 0.5 * g),
            const Color(0xFF15171D).withValues(alpha: 0.7 * g),
            const Color(0xFF0B0C10).withValues(alpha: 0.85 * g),
          ],
          const [0.0, 0.6, 1.0],
        ),
    );
    _p.shader = null;
    _paintRimAndShine(canvas, r, g * 0.55, smoke);
  }
}
