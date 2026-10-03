// lib/widgets/fx/extraction_vessel.dart
//
// The harvest chamber: the working Alchemon stands on a bench beside a
// round-bottomed flask of dark glass (the dock's harvest emblem). While a job
// runs, grains peel off the creature in its own colours, heat into the
// element's as they arc across into the neck, and gather as a glowing liquid
// of grains whose level IS the job's progress. A tap splashes the liquid and shakes a
// burst of essence loose (the tap boost). Full, it breathes; collected, it
// pours up out of the neck.
//
// No hoops, no strokes: glass is filled gradients, light is pools, the
// contents are grains (see feedback on VFX material, and the cultivation
// sphere / dock emblem this borrows from).

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// What the chamber is doing.
enum VesselMode {
  /// Not yet bought: cold glass, grey dust in the bottom.
  locked,

  /// Open and waiting for a specimen.
  empty,

  /// A specimen is in it and the liquid is rising.
  running,

  /// Full, waiting to be collected.
  ready,
}

/// Cheap stable hash → 0..1.
double _h(int i, int salt) {
  var x = (i * 374761393 + salt * 668265263) & 0x7fffffff;
  x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff;
  x = x ^ (x >> 16);
  return (x & 0xffff) / 65536.0;
}

double _smooth(double x) {
  final t = x.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// The bench inside a box of [size]: the Alchemon standing on the left,
/// the flask on the right, both on one floor.
class VesselGeometry {
  /// [slide] is 0 with the flask alone in the middle of the bench, 1 with it
  /// moved aside for an Alchemon.
  factory VesselGeometry(Size size, {double slide = 1}) {
    final w = size.width, h = size.height;
    final r = math.min(w * 0.25, h * 0.24);
    final cs = math.min(w * 0.5, h * 0.55);
    // The scene (flask, neck, and the arc over it) centred in the box, a
    // little low so the arc has its room.
    final floor = math.min(h * 0.94, h * 0.5 + r * 1.75);
    return VesselGeometry._(
      slide: slide,
      size,
      floor,
      Offset(w * (0.5 + 0.215 * slide), floor - r * 0.985),
      r,
      Offset(w * 0.255, floor - cs * 0.4),
      cs,
    );
  }

  VesselGeometry._(
    this.size,
    this.floorY,
    this.center,
    this.radius,
    this.creatureCenter,
    this.creatureSize, {
    this.slide = 1,
  });

  final Size size;
  final double slide;

  /// Where both stand.
  final double floorY;

  /// The flask's bulb.
  final Offset center;
  final double radius;

  /// Where the creature stands: its box's centre and side. Its feet are on
  /// the floor.
  final Offset creatureCenter;
  final double creatureSize;

  double get neckHalf => radius * 0.24;
  double get mouthY => center.dy - radius * 1.5;
  double get bottom => center.dy + radius * 0.965;

  /// Where the surface stands when the chamber is full.
  double get fullLevel => center.dy + radius * 0.24;

  /// Half the liquid's width at height [y].
  double chord(double y) {
    final dy = y - center.dy;
    final r2 = radius * radius * 0.93 - dy * dy;
    return r2 <= 0 ? 0 : math.sqrt(r2);
  }

  /// The neck's open top, in the box's coordinates.
  Rect get mouth => Rect.fromCenter(
    center: Offset(center.dx, mouthY + radius * 0.04),
    width: neckHalf * 2.6,
    height: radius * 0.3,
  );

  late final Path bulb = Path()
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  late final Path glass = _glass();

  /// A soft crescent high on the left, where the room's light catches.
  late final Path catchlight = Path.combine(
    PathOperation.difference,
    Path()..addOval(
      Rect.fromCircle(
        center: center + Offset(-radius * 0.06, -radius * 0.04),
        radius: radius * 0.86,
      ),
    ),
    Path()..addOval(
      Rect.fromCircle(
        center: center + Offset(radius * 0.06, radius * 0.07),
        radius: radius * 0.85,
      ),
    ),
  );

  /// A thin crescent of light inside the edge, low on the right.
  late final Path rimlight = Path.combine(
    PathOperation.difference,
    Path()..addOval(Rect.fromCircle(center: center, radius: radius * 0.975)),
    Path()..addOval(
      Rect.fromCircle(
        center: center + Offset(-radius * 0.045, -radius * 0.05),
        radius: radius * 0.96,
      ),
    ),
  );

  Path _glass() {
    final neckBottom = center.dy - radius * 0.86;
    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            center.dx - neckHalf,
            mouthY + radius * 0.05,
            center.dx + neckHalf,
            neckBottom,
          ),
          Radius.circular(neckHalf * 0.3),
        ),
      );
  }

  /// The lip at the neck's top: a little wider than the neck.
  RRect lip() => RRect.fromRectAndRadius(
    Rect.fromLTRB(
      center.dx - neckHalf * 1.18,
      mouthY,
      center.dx + neckHalf * 1.18,
      mouthY + radius * 0.06,
    ),
    Radius.circular(radius * 0.03),
  );
}

/// The flask's contents, as plain Dart: stepped by its host, painted in two
/// layers either side of the creature.
class ExtractionVesselField {
  ExtractionVesselField();

  // ── Inputs, set by the host each frame ───────────────────────────────
  Color accent = const Color(0xFFF0B254);
  VesselMode mode = VesselMode.empty;

  /// 0..1, how full: the job's progress, or what is left mid-collect.
  double level = 0;

  /// Mid-collect (or ending a run): the liquid pours up and out of the neck.
  bool venting = false;

  /// An Alchemon is at the bench: the flask stands aside for it.
  bool occupied = false;
  double _slide = -1;

  // ── State ─────────────────────────────────────────────────────────────
  double time = 0;
  double _shown = 0;
  double _stir = 0;
  double _swirl = 0;
  double _peelDebt = 0, _ventDebt = 0, _dustDebt = 0, _riseDebt = 0;
  int _spawned = 0;
  double _lastBeat = 0;
  VesselGeometry? _geo;

  SpecimenGrains? _specimen;
  Offset _specimenAt = Offset.zero;

  /// Grains held in the liquid at full.
  static const int poolGrains = 1500;

  /// Grains along the surface.
  static const int surfaceGrains = 90;

  // Motes: everything loose in the glass. Struct of arrays, fixed capacity.
  static const int _cap = 420;
  final Float32List _ox = Float32List(_cap), _oy = Float32List(_cap);
  final Float32List _vx = Float32List(_cap), _vy = Float32List(_cap);
  final Float32List _born = Float32List(_cap), _life = Float32List(_cap);
  final Uint8List _kind = Uint8List(_cap), _tone = Uint8List(_cap);
  final Int32List _seed = Int32List(_cap);
  int _n = 0;

  static const int _peel = 0, _splash = 1, _rise = 2, _vent = 3, _dust = 4;

  // Ripples on the surface from taps: x, born.
  final Float32List _ripX = Float32List(4),
      _ripT = Float32List(4)..fillRange(0, 4, -100);
  int _rip = 0;

  /// The creature's grains, read off its sprite, centred on [at] (box
  /// coordinates). Peeled motes leave from them in its own colours.
  void setSpecimen(SpecimenGrains? grains, Offset at) {
    _specimen = (grains == null || grains.length == 0) ? null : grains;
    _specimenAt = at;
  }

  bool get hasSpecimen => _specimen != null;

  void layout(Size size) {
    final slide = _slide < 0 ? (occupied ? 1.0 : 0.0) : _smooth(_slide);
    if (_geo?.size != size || (_geo!.slide - slide).abs() > 1e-4) {
      _geo = VesselGeometry(size, slide: slide);
    }
  }

  VesselGeometry? get geometry => _geo;

  /// How far the surface sits, 0 empty → 1 full, as drawn.
  double get shownLevel => _shown;

  double _residue() => switch (mode) {
    VesselMode.locked => 0.035,
    VesselMode.empty => 0.045,
    _ => 0.045,
  };

  double surfaceBase() {
    final g = _geo!;
    final l = math.max(_shown, _residue());
    // Rises by volume, not by height: the bottom of a sphere fills fast.
    final k = math.pow(l, 0.72).toDouble();
    return g.bottom + (g.fullLevel - g.bottom) * k;
  }

  double _wave(double x, double base) {
    final g = _geo!;
    final r = g.radius;
    final calm = mode == VesselMode.locked ? 0.25 : 1.0;
    var y =
        base +
        calm *
            (r * 0.011 * math.sin(x / r * 5.2 + time * 1.5) +
                r * 0.007 * math.sin(x / r * 9.1 - time * 2.2));
    for (var i = 0; i < 4; i++) {
      final age = time - _ripT[i];
      if (age < 0 || age > 2.2) continue;
      final d = (x - _ripX[i]).abs();
      final front = age * r * 1.3;
      if (d > front) continue;
      y +=
          r *
          0.05 *
          math.exp(-age * 2.4) *
          math.sin(d / r * 15 - age * 10) *
          (1 - d / (front + 1));
    }
    return y;
  }

  int _alloc() {
    if (_n < _cap) return _n++;
    // Full: recycle the oldest-born slot.
    var oldest = 0;
    for (var i = 1; i < _cap; i++) {
      if (_born[i] < _born[oldest]) oldest = i;
    }
    return oldest;
  }

  void _kill(int i) {
    _n--;
    if (i == _n) return;
    _ox[i] = _ox[_n];
    _oy[i] = _oy[_n];
    _vx[i] = _vx[_n];
    _vy[i] = _vy[_n];
    _born[i] = _born[_n];
    _life[i] = _life[_n];
    _kind[i] = _kind[_n];
    _tone[i] = _tone[_n];
    _seed[i] = _seed[_n];
  }

  void _spawn(
    int kind,
    double x,
    double y,
    double life, {
    double vx = 0,
    double vy = 0,
    int tone = 255,
  }) {
    final i = _alloc();
    _ox[i] = x;
    _oy[i] = y;
    _vx[i] = vx;
    _vy[i] = vy;
    _born[i] = time;
    _life[i] = life;
    _kind[i] = kind;
    _tone[i] = tone;
    _seed[i] = _spawned++;
  }

  void _spawnPeel() {
    final g = _geo!;
    final k = _spawned;
    final sp = _specimen;
    if (sp != null) {
      final j = (_h(k, 7) * sp.length).floor().clamp(0, sp.length - 1);
      _spawn(
        _peel,
        _specimenAt.dx + sp.hx[j],
        _specimenAt.dy + sp.hy[j],
        2.1 + _h(k, 8) * 0.8,
        tone: math.min(sp.tone[j], 254),
      );
    } else {
      final a = _h(k, 7) * math.pi * 2;
      final r = math.sqrt(_h(k, 9)) * g.creatureSize * 0.26;
      final c = g.creatureCenter;
      _spawn(
        _peel,
        c.dx + math.cos(a) * r,
        c.dy + math.sin(a) * r * 1.15,
        2.1 + _h(k, 8) * 0.8,
      );
    }
  }

  /// A tap at [p] (box coordinates): the liquid splashes there and, while a
  /// job runs, a burst of essence shakes loose.
  void splash(Offset p) {
    final g = _geo;
    if (g == null || mode == VesselMode.locked) return;
    final base = surfaceBase();
    final cw = g.chord(base) * 0.9;
    final x = p.dx.clamp(g.center.dx - cw, g.center.dx + cw).toDouble();
    _ripX[_rip] = x;
    _ripT[_rip] = time;
    _rip = (_rip + 1) % 4;
    _stir = math.min(_stir + 1.3, 3.2);
    final r = g.radius;
    final drops = mode == VesselMode.empty ? 6 : 22;
    for (var i = 0; i < drops; i++) {
      final k = _spawned;
      final a = -math.pi / 2 + (_h(k, 21) - 0.5) * 1.5;
      final v = r * (1.0 + 1.3 * _h(k, 22));
      _spawn(
        _splash,
        x + (_h(k, 23) - 0.5) * r * 0.08,
        _wave(x, base),
        1.4,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
      );
    }
    if (mode == VesselMode.running) {
      for (var i = 0; i < 14; i++) {
        _spawnPeel();
      }
    }
  }

  /// The ready heartbeat, as cultivations have it: a swell every 2.6 s.
  static double heartbeat(double time) {
    final beat = (time % 2.6) / 2.6;
    return math.exp(-beat * 9) + 0.45 * math.exp(-((beat - 0.16).abs()) * 22);
  }

  void step(double dt) {
    final g = _geo;
    if (g == null) return;
    dt = dt.clamp(0.0, 0.05);
    time += dt;
    // The surface follows the level, a little behind, so a tap boost or a
    // drain moves rather than jumps.
    final target = mode == VesselMode.ready && !venting ? 1.0 : level;
    _shown += (target - _shown) * (1 - math.exp(-dt * (venting ? 14 : 4)));
    // The first frame takes its place outright; after that it moves.
    final aside = occupied ? 1.0 : 0.0;
    _slide = _slide < 0
        ? aside
        : (_slide + (aside - _slide).sign * dt * 1.6).clamp(
            math.min(_slide, aside),
            math.max(_slide, aside),
          );
    _stir *= math.exp(-dt * 1.8);
    final calm = mode == VesselMode.ready ? 0.45 : 1.0;
    _swirl += dt * (0.22 + 0.35 * _shown + 0.9 * _stir) * calm;

    final r = g.radius;
    final base = surfaceBase();

    // New motes.
    if (venting) {
      _ventDebt += dt * 150;
      while (_ventDebt >= 1) {
        _ventDebt -= 1;
        final k = _spawned;
        final cw = g.chord(base) * 0.85;
        final x = g.center.dx + (_h(k, 31) * 2 - 1) * cw;
        _spawn(_vent, x, _wave(x, base), 0.75 + _h(k, 32) * 0.35);
      }
    } else if (mode == VesselMode.running) {
      _peelDebt += dt * (42 + 30 * _stir);
      while (_peelDebt >= 1) {
        _peelDebt -= 1;
        _spawnPeel();
      }
    } else if (mode == VesselMode.ready) {
      final beat = (time % 2.6) / 2.6;
      final burst = beat < _lastBeat;
      _lastBeat = beat;
      _riseDebt += dt * 3 + (burst ? 7 : 0);
      while (_riseDebt >= 1) {
        _riseDebt -= 1;
        final k = _spawned;
        final cw = g.chord(base) * 0.8;
        final x = g.center.dx + (_h(k, 41) * 2 - 1) * cw;
        _spawn(_rise, x, _wave(x, base), 1.8 + _h(k, 42) * 1.2);
      }
    }
    if (mode == VesselMode.empty) {
      _dustDebt += dt * 3;
      while (_dustDebt >= 1) {
        _dustDebt -= 1;
        final k = _spawned;
        final a = _h(k, 51) * math.pi * 2;
        final d = math.sqrt(_h(k, 52)) * r * 0.78;
        _spawn(
          _dust,
          g.center.dx + math.cos(a) * d,
          g.center.dy - r * 0.1 + math.sin(a) * d * 0.8,
          5 + _h(k, 53) * 3,
        );
      }
    }

    // Retire finished motes.
    for (var i = _n - 1; i >= 0; i--) {
      final age = time - _born[i];
      if (age >= _life[i]) {
        _kill(i);
        continue;
      }
      final kind = _kind[i];
      if (kind == _peel || kind == _splash) {
        final p = _motePos(i, age, base);
        // In the liquid now.
        if (p.dy > _wave(p.dx, base) &&
            (kind == _peel ? age / _life[i] > _pourAt : age > 0.12)) {
          _kill(i);
        }
      }
    }
  }

  /// A peeled grain's flight: off the body until [_liftAt], across to the
  /// neck until [_pourAt], then down into the liquid.
  static const double _liftAt = 0.14, _pourAt = 0.7;

  Offset _motePos(int i, double age, double base) {
    final g = _geo!;
    final r = g.radius;
    final s = _seed[i];
    final tau = (age / _life[i]).clamp(0.0, 1.0);
    switch (_kind[i]) {
      case _peel:
        // Off the body, outward and up; across in an arc; down the neck.
        final ox = _ox[i], oy = _oy[i];
        final c = g.creatureCenter;
        var dx = ox - c.dx, dy = oy - c.dy;
        final dl = math.sqrt(dx * dx + dy * dy) + 1e-3;
        dx /= dl;
        dy /= dl;
        final lift = _smooth(tau / _liftAt);
        final lx = ox + dx * r * 0.12 * lift;
        final ly = oy + dy * r * 0.06 * lift - r * 0.1 * lift;
        if (tau <= _liftAt) return Offset(lx, ly);
        // Into the neck, a little to either side of its middle.
        final mx = g.center.dx + (_h(s, 61) - 0.5) * g.neckHalf * 0.9;
        final my = g.mouthY + r * 0.02;
        if (tau <= _pourAt) {
          final u = Curves.easeInOut.transform(
            (tau - _liftAt) / (_pourAt - _liftAt),
          );
          final cx = (lx + mx) / 2;
          final cy = math.min(ly, my) - r * (0.82 + 0.12 * _h(s, 62));
          final a = (1 - u) * (1 - u), b = 2 * u * (1 - u), e = u * u;
          // A ribbon, not a wire: each grain a little off the line, most in
          // the middle of the flight.
          final off = math.sin(u * math.pi) * r * 0.07 * (_h(s, 63) - 0.5);
          return Offset(
            a * lx + b * cx + e * mx,
            a * ly + b * cy + e * my + off,
          );
        }
        final f = (tau - _pourAt) / (1 - _pourAt);
        return Offset(
          mx + math.sin(f * 4 + s) * g.neckHalf * 0.25,
          my + (g.bottom - my) * f * f,
        );
      case _splash:
        return Offset(
          _ox[i] + _vx[i] * age,
          _oy[i] + _vy[i] * age + 0.5 * r * 5.5 * age * age,
        );
      case _rise:
        return Offset(
          _ox[i] + math.sin(time * 1.3 + s) * r * 0.03 * tau,
          _oy[i] - r * 0.55 * tau,
        );
      case _vent:
        // Drawn into the neck and up out of it.
        final e = Curves.easeIn.transform(tau);
        final top = g.mouthY - r * 0.35;
        final x =
            _ox[i] +
            (g.center.dx - _ox[i]) * _smooth(tau * 1.5) +
            math.sin(tau * 9 + s) * r * 0.12 * (1 - tau);
        final y = _oy[i] + (top - _oy[i]) * e;
        return Offset(x, y);
      default: // dust
        return Offset(
          _ox[i] + math.sin(time * 0.4 + s) * r * 0.05,
          _oy[i] - r * 0.12 * tau,
        );
    }
  }

  // ── Painting ──────────────────────────────────────────────────────────

  static final Paint _p = Paint();

  // Buckets: pool tones 0-4, surface 5-6, specimen tones 7-22, peel stages
  // 23-25, splash 26, rise 27, vent 28, dust 29.
  static const int _poolB = 0, _surfB = 5, _specB = 7, _stageB = 23;
  static const int _splashB = 26, _riseB = 27, _ventB = 28, _dustB = 29;
  final GrainBatch _batch = GrainBatch(30);

  Color get _ink => mode == VesselMode.locked
      ? const Color(0xFF6E6A73)
      : mode == VesselMode.empty
      ? Color.lerp(accent, const Color(0xFF6E6A73), 0.45)!
      : accent;

  double get _glow {
    final beat = mode == VesselMode.ready ? heartbeat(time) : 0.0;
    return switch (mode) {
      VesselMode.locked => 0.12,
      VesselMode.empty => 0.35,
      _ => 0.55 + 0.45 * _shown + 0.5 * beat + 0.4 * _stir.clamp(0.0, 1.0),
    };
  }

  /// The glass, and the light the liquid throws on its back wall: under the
  /// creature.
  void paintBack(Canvas canvas) {
    final g = _geo;
    if (g == null) return;
    final c = g.center, r = g.radius;
    final ink = _ink;
    final base = surfaceBase();

    _paintFloor(canvas, g, ink);

    // The glass body: dark smoke, faintly the element's colour.
    final glass = g.glass;
    _p.shader = ui.Gradient.radial(c + Offset(-r * 0.25, -r * 0.35), r * 1.45, [
      Color.lerp(ink, const Color(0xFF0A090D), 0.8)!.withValues(alpha: 0.6),
      const Color(0xFF07060A).withValues(alpha: 0.86),
    ]);
    canvas.drawPath(glass, _p);

    // The liquid's light up the back wall.
    canvas.save();
    canvas.clipPath(glass);
    _p.shader = ui.Gradient.radial(
      Offset(c.dx, base),
      r * 1.05,
      [
        ink.withValues(alpha: 0.2 * _glow),
        ink.withValues(alpha: 0.05 * _glow),
        Colors.transparent,
      ],
      const [0.0, 0.45, 1.0],
    );
    canvas.drawRect(Rect.fromCircle(center: c, radius: r * 1.1), _p);
    canvas.restore();
    _p.shader = null;
  }

  /// A flattened pool of light at [at], [rx] wide.
  void _pool(
    Canvas canvas,
    Offset at,
    double rx,
    double ry,
    List<Color> colors,
  ) {
    _p.shader = ui.Gradient.radial(at, rx, colors);
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(1, ry / rx);
    canvas.translate(-at.dx, -at.dy);
    canvas.drawCircle(at, rx, _p);
    canvas.restore();
  }

  /// The floor they share: no edge, only light on it — the liquid's under the
  /// flask, the essence's under the Alchemon, and a shadow under each.
  void _paintFloor(Canvas canvas, VesselGeometry g, Color ink) {
    final r = g.radius;
    final y = g.floorY;
    final working = mode == VesselMode.running || mode == VesselMode.ready;
    final w = g.size.width;
    // The bench's top, catching a little light across its whole width.
    _pool(canvas, Offset(w * 0.5, y + r * 0.04), w * 0.62, r * 0.32, [
      const Color(0xFF2A2420).withValues(alpha: 0.55),
      Colors.transparent,
    ]);
    _pool(canvas, Offset(g.center.dx, y + r * 0.02), r * 1.5, r * 0.3, [
      ink.withValues(alpha: 0.2 * _glow * _shown.clamp(0.15, 1.0)),
      Colors.transparent,
    ]);
    _pool(canvas, Offset(g.center.dx, y), r * 0.8, r * 0.1, [
      Colors.black.withValues(alpha: 0.6),
      Colors.transparent,
    ]);
    final feet = Offset(g.creatureCenter.dx, y);
    final cs = g.creatureSize;
    if (working) {
      _pool(canvas, feet, cs * 0.55, r * 0.22, [
        ink.withValues(alpha: 0.16 * math.min(_glow, 1.3)),
        Colors.transparent,
      ]);
    }
    _pool(canvas, feet, cs * 0.3, r * 0.07, [
      Colors.black.withValues(alpha: 0.5),
      Colors.transparent,
    ]);
    _p.shader = null;
  }

  /// The liquid, the loose grains and the glass's face: over the creature.
  void paintFront(Canvas canvas) {
    final g = _geo;
    if (g == null) return;
    final c = g.center, r = g.radius;
    final ink = _ink;
    final glow = _glow;
    final base = surfaceBase();
    final b = _batch..clear();
    final grain = math.max(1.2, r * 0.016);

    canvas.save();
    canvas.clipPath(g.bulb);

    // The liquid's body: a luminous wash under its grains.
    final surface = Path()..moveTo(c.dx - r, _wave(c.dx - r, base));
    for (var k = 1; k <= 24; k++) {
      final x = c.dx - r + 2 * r * k / 24;
      surface.lineTo(x, _wave(x, base));
    }
    surface
      ..lineTo(c.dx + r, c.dy + r)
      ..lineTo(c.dx - r, c.dy + r)
      ..close();
    _p.shader = ui.Gradient.linear(
      Offset(0, base),
      Offset(0, g.bottom),
      [
        ink.withValues(alpha: 0.42 * math.min(glow, 1.2)),
        Color.lerp(ink, Colors.black, 0.35)!.withValues(alpha: 0.36),
        Color.lerp(ink, Colors.black, 0.7)!.withValues(alpha: 0.5),
      ],
      const [0.0, 0.4, 1.0],
    );
    canvas.drawPath(surface, _p);
    // Light at the surface, brightest in the middle.
    final cw = math.max(g.chord(base), r * 0.2);
    _p.shader = ui.Gradient.radial(Offset(c.dx, base), cw, [
      ink.withValues(alpha: 0.28 * glow),
      Colors.transparent,
    ]);
    canvas.save();
    canvas.translate(c.dx, base);
    canvas.scale(1, 0.14);
    canvas.translate(-c.dx, -base);
    canvas.drawCircle(Offset(c.dx, base), cw, _p);
    canvas.restore();
    _p.shader = null;

    // The liquid's grains, turning in a slow roll.
    final depth = g.bottom - base;
    if (depth > 0.5) {
      final full = g.bottom - g.fullLevel;
      final frac = (depth / full).clamp(0.0, 1.0);
      final count = (poolGrains * math.pow(frac, 1.2)).round().clamp(
        28,
        poolGrains,
      );
      final mid = base + depth / 2;
      final hh = depth / 2;
      for (var i = 0; i < count; i++) {
        final th = _h(i, 1) * math.pi * 2 + _swirl * (0.6 + 0.8 * _h(i, 2));
        final rho = math.sqrt(_h(i, 3));
        var y = mid + math.sin(th) * rho * hh;
        final x = c.dx + math.cos(th) * rho * g.chord(y) * 0.96;
        final top = _wave(x, base);
        if (y < top) y = top + (top - y) * 0.4;
        final d = ((y - top) / depth).clamp(0.0, 1.0);
        final glint = (time * 0.3 + _h(i, 4) * 7) % 1.0 < 0.012;
        b.add(
          glint
              ? _poolB + 4
              : _poolB +
                    (d < 0.18
                        ? 3
                        : d < 0.42
                        ? 2
                        : d < 0.7
                        ? 1
                        : 0),
          x,
          y,
        );
      }
      // Its surface, picked out in grains.
      final sw = g.chord(base) * 0.97;
      final sn = (surfaceGrains * math.sqrt(sw / r)).round();
      for (var i = 0; i < sn; i++) {
        final x =
            c.dx -
            sw +
            2 * sw * ((_h(i, 11) + time * 0.02 * (_h(i, 12) - 0.5)) % 1.0);
        final y = _wave(x, base) + _h(i, 13) * r * 0.012;
        final glint = (time * 0.5 + _h(i, 14) * 9) % 1.0 < 0.03;
        b.add(_surfB + (glint ? 1 : 0), x, y);
      }
    }
    canvas.restore();

    // The loose grains, inside the glass.
    final sp = _specimen;
    for (var i = 0; i < _n; i++) {
      final age = time - _born[i];
      final p = _motePos(i, age, base);
      final tau = age / _life[i];
      switch (_kind[i]) {
        case _peel:
          if (tau < 0.2 && sp != null && _tone[i] < 16) {
            b.add(_specB + _tone[i], p.dx, p.dy);
          } else {
            b.add(
              _stageB +
                  (tau < 0.5
                      ? 0
                      : tau < _pourAt
                      ? 1
                      : 2),
              p.dx,
              p.dy,
            );
          }
        case _splash:
          b.add(_splashB, p.dx, p.dy);
        case _rise:
          if (tau < 0.85) b.add(_riseB, p.dx, p.dy);
        case _vent:
          b.add(_ventB, p.dx, p.dy);
        default:
          final a = math.sin(tau * math.pi);
          if (a > 0.3) b.add(_dustB, p.dx, p.dy);
      }
    }

    final deep = Color.lerp(ink, const Color(0xFF0A0710), 0.58)!;
    final hot = Color.lerp(ink, Colors.white, 0.24)!;
    final white = Color.lerp(ink, Colors.white, 0.78)!;
    // Under the pool's grains, a wide faint pass so they read as light.
    b.draw(canvas, _poolB + 3, grain * 2.6, ink.withValues(alpha: 0.10 * glow));
    b.draw(canvas, _poolB + 0, grain, deep.withValues(alpha: 0.9));
    b.draw(canvas, _poolB + 1, grain, Color.lerp(ink, deep, 0.45)!);
    b.draw(canvas, _poolB + 2, grain, ink.withValues(alpha: 0.95));
    b.draw(canvas, _poolB + 3, grain * 1.05, hot.withValues(alpha: 0.9));
    b.draw(canvas, _poolB + 4, grain * 1.25, white);
    b.draw(canvas, _surfB, grain * 1.1, hot);
    b.draw(canvas, _surfB + 1, grain * 1.35, white);

    if (sp != null) {
      for (var t = 0; t < sp.tones.length && t < 16; t++) {
        b.draw(canvas, _specB + t, grain * 1.4, sp.tones[t]);
      }
    }
    // The stream: wide faint light under each grain, so the arc reads as a
    // ribbon of light and not a scatter of sparks.
    b.draw(canvas, _stageB, grain * 5, ink.withValues(alpha: 0.10));
    b.draw(canvas, _stageB + 1, grain * 4.4, ink.withValues(alpha: 0.10));
    b.draw(canvas, _stageB, grain * 1.7, hot);
    b.draw(canvas, _stageB + 1, grain * 1.5, Color.lerp(ink, hot, 0.4)!);
    b.draw(canvas, _stageB + 2, grain * 1.3, ink);
    b.draw(canvas, _splashB, grain * 3.2, ink.withValues(alpha: 0.16));
    b.draw(canvas, _splashB, grain * 1.35, hot);
    b.draw(canvas, _riseB, grain * 2.8, ink.withValues(alpha: 0.12));
    b.draw(canvas, _riseB, grain * 1.1, white.withValues(alpha: 0.85));
    b.draw(canvas, _ventB, grain * 3, ink.withValues(alpha: 0.14));
    b.draw(canvas, _ventB, grain * 1.2, hot);
    b.draw(canvas, _dustB, grain * 2.6, ink.withValues(alpha: 0.08));
    b.draw(canvas, _dustB, grain * 1.1, ink.withValues(alpha: 0.6));

    _paintGlassFace(canvas, g, ink);
  }

  void _paintGlassFace(Canvas canvas, VesselGeometry g, Color ink) {
    final c = g.center, r = g.radius;
    // The glass's thickness at its edge, catching the room's light — filled,
    // as glass is, never a stroke.
    _p.shader = ui.Gradient.radial(
      c,
      r,
      [
        Colors.transparent,
        Colors.transparent,
        Colors.white.withValues(alpha: 0.025),
        Colors.white.withValues(alpha: 0.075),
      ],
      const [0.0, 0.84, 0.96, 1.0],
    );
    canvas.drawPath(g.bulb, _p);
    // Its body's shade: the far side of the sphere, away from the light, so
    // the edge is a volume and not a hoop.
    _p.shader = ui.Gradient.radial(
      c,
      r,
      [
        Colors.transparent,
        Colors.transparent,
        Colors.black.withValues(alpha: 0.42),
      ],
      const [0.0, 0.62, 1.0],
      TileMode.clamp,
      null,
      c + Offset(-r * 0.32, -r * 0.38),
    );
    canvas.drawPath(g.bulb, _p);
    // Lit from inside at the bottom, where the liquid is.
    _p.shader = ui.Gradient.radial(Offset(c.dx, c.dy + r * 0.55), r * 0.9, [
      ink.withValues(alpha: 0.10 * _glow * _shown.clamp(0.25, 1.0)),
      Colors.transparent,
    ]);
    canvas.save();
    canvas.clipPath(g.bulb);
    canvas.drawRect(Rect.fromCircle(center: c, radius: r), _p);
    canvas.restore();

    // Light come round through the glass, on the far side from the
    // catchlight: what makes a dark sphere read as glass and not a ball.
    _p.shader = ui.Gradient.linear(
      c + Offset(r * 0.75, r * 0.75),
      c + Offset(r * 0.1, r * 0.1),
      [Colors.white.withValues(alpha: 0.11), Colors.transparent],
    );
    canvas.drawPath(g.rimlight, _p);

    // The catchlight.
    _p.shader = ui.Gradient.linear(
      c + Offset(-r * 0.7, -r * 0.7),
      c + Offset(-r * 0.05, r * 0.2),
      [Colors.white.withValues(alpha: 0.13), Colors.transparent],
    );
    canvas.drawPath(g.catchlight, _p);

    // The neck: a pale streak down its left side, and the lip.
    final nh = g.neckHalf;
    _p.shader = ui.Gradient.linear(
      Offset(c.dx - nh, 0),
      Offset(c.dx + nh, 0),
      [
        Colors.white.withValues(alpha: 0.09),
        Colors.white.withValues(alpha: 0.01),
        Colors.white.withValues(alpha: 0.05),
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(
      Rect.fromLTRB(c.dx - nh, g.mouthY + r * 0.06, c.dx + nh, c.dy - r * 0.9),
      _p,
    );
    final lip = g.lip();
    _p.shader = ui.Gradient.linear(Offset(0, lip.top), Offset(0, lip.bottom), [
      Colors.white.withValues(alpha: 0.12),
      Colors.white.withValues(alpha: 0.02),
    ]);
    canvas.drawRRect(lip, _p);
    _p.shader = null;
  }
}

class _VesselPainter extends CustomPainter {
  _VesselPainter(this.field, this.front, Listenable repaint)
    : super(repaint: repaint);

  final ExtractionVesselField field;
  final bool front;

  @override
  void paint(Canvas canvas, Size size) {
    field.layout(size);
    if (front) {
      field.paintFront(canvas);
    } else {
      field.paintBack(canvas);
    }
  }

  @override
  bool shouldRepaint(_VesselPainter old) =>
      old.field != field || old.front != front;
}

/// The harvest chamber as a widget: the Alchemon at work on the left, its
/// essence arcing into the flask on the right, and the liquid rising as
/// [level] does.
class ExtractionVessel extends StatefulWidget {
  const ExtractionVessel({
    super.key,
    required this.accent,
    required this.mode,
    required this.level,
    this.creature,
    this.creatureId,
    this.element,
    this.reveal,
    this.vent,
    this.onTap,
    this.lockedIcon,
  });

  final Color accent;
  final VesselMode mode;

  /// 0..1: the job's progress, or what is left of it mid-collect.
  final ValueListenable<double> level;

  /// Builds the creature's sprite at the side it is given.
  final Widget Function(double size)? creature;

  /// Which creature is in it, so a new one is read afresh.
  final Object? creatureId;

  /// Its element ('Fire'…), for the gather when it is put in.
  final String? element;

  /// Set when the creature has just been put in: it gathers into place.
  final EssenceReveal? reveal;

  /// Runs while the liquid pours out (a collect, or ending a run).
  final Animation<double>? vent;

  /// A tap on the chamber. The splash is the vessel's own.
  final VoidCallback? onTap;

  /// Shown faintly in the glass of a locked chamber.
  final IconData? lockedIcon;

  /// The neck's mouth in global coordinates, for whatever leaves through it.
  static Rect? mouthOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final m = VesselGeometry(box.size).mouth;
    return box.localToGlobal(m.topLeft) & m.size;
  }

  @override
  State<ExtractionVessel> createState() => _ExtractionVesselState();
}

class _ExtractionVesselState extends State<ExtractionVessel>
    with TickerProviderStateMixin {
  final ExtractionVesselField _field = ExtractionVesselField();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// One per creature: a creature fading out and the next fading in are both
  /// mounted for a moment, and a shared key would be in two places at once.
  final Map<Object?, GlobalKey> _spriteKeys = {};
  GlobalKey _spriteKey(Object? id) =>
      _spriteKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'vessel_$id'));
  late final AnimationController _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );
  bool _reading = false;
  Object? _readFor;

  @override
  void initState() {
    super.initState();
    _apply();
    _field.level = widget.level.value;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void didUpdateWidget(ExtractionVessel old) {
    super.didUpdateWidget(old);
    _apply();
    if (widget.creatureId != old.creatureId) {
      _field.setSpecimen(null, Offset.zero);
      _readFor = null;
      _spriteKeys.removeWhere(
        (k, _) => k != widget.creatureId && k != old.creatureId,
      );
    }
  }

  void _apply() {
    _field
      ..accent = widget.accent
      ..mode = widget.mode
      ..occupied = widget.creature != null;
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final vent = widget.vent;
    _field
      ..level = widget.level.value
      ..venting = vent != null && vent.isAnimating && vent.value < 0.8;
    _field.step(dt);
    _frame.value++;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _wobble.dispose();
    _frame.dispose();
    super.dispose();
  }

  bool _onSpriteReady(SpriteReadyNotification n) {
    _scheduleRead();
    return false;
  }

  /// Reads the creature, as drawn, into grains: the motes that peel off it
  /// leave in its own colours.
  Future<void> _scheduleRead() async {
    final id = widget.creatureId;
    if (_reading || id == null || _readFor == id) return;
    _reading = true;
    try {
      // Let the reveal (if any) finish first; the read is of the whole body.
      await Future<void>.delayed(
        Duration(milliseconds: widget.reveal != null ? 1700 : 120),
      );
      if (!mounted || widget.creatureId != id) return;
      WidgetsBinding.instance.scheduleFrame();
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _spriteKey(id).currentContext?.findRenderObject();
      if (!mounted) return;
      if (boundary is! RenderRepaintBoundary || !boundary.attached) return;
      final ratio = math.min(MediaQuery.devicePixelRatioOf(context), 2.0);
      final image = await boundary.toImage(pixelRatio: ratio);
      try {
        final data = await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        if (data == null || !mounted || widget.creatureId != id) return;
        final grains = SpecimenGrains.fromRgba(
          data.buffer.asUint8List(),
          image.width,
          image.height,
          pixelRatio: ratio,
          maxGrains: 900,
          tones: 12,
        );
        if (grains.length < 60) return;
        final g = _field.geometry;
        if (g == null) return;
        _field.setSpecimen(grains, g.creatureCenter);
        _readFor = id;
      } finally {
        image.dispose();
      }
    } catch (_) {
      // No read just means the motes leave in the element's colour.
    } finally {
      _reading = false;
    }
  }

  void _onTapDown(TapDownDetails d, Size size) {
    if (widget.mode == VesselMode.locked) {
      widget.onTap?.call();
      return;
    }
    _field.splash(d.localPosition);
    if (widget.mode == VesselMode.running) _wobble.forward(from: 0);
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = Size(box.maxWidth, box.maxHeight);
        final g = VesselGeometry(size, slide: widget.creature != null ? 1 : 0);
        final cs = g.creatureSize;
        final creature = widget.creature;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _onTapDown(d, size),
          child: Center(
            child: SizedBox.fromSize(
              size: size,
              child: RepaintBoundary(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _VesselPainter(_field, false, _frame),
                      ),
                    ),
                    if (widget.mode == VesselMode.locked &&
                        widget.lockedIcon != null)
                      Positioned(
                        left: g.center.dx - 14,
                        top: g.center.dy - 14,
                        child: Icon(
                          widget.lockedIcon,
                          size: 28,
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                    Positioned(
                      left: g.creatureCenter.dx - cs / 2,
                      top: g.creatureCenter.dy - cs / 2,
                      width: cs,
                      height: cs,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 380),
                        child: creature == null
                            ? const SizedBox.expand()
                            : KeyedSubtree(
                                key: ValueKey(widget.creatureId),
                                child: _Wobble(
                                  controller: _wobble,
                                  child:
                                      NotificationListener<
                                        SpriteReadyNotification
                                      >(
                                        onNotification: _onSpriteReady,
                                        child: ElementalEssence(
                                          key: ValueKey(widget.creatureId),
                                          element: widget.element,
                                          reveal: widget.reveal,
                                          tappable: false,
                                          maxGrains: 1600,
                                          child: RepaintBoundary(
                                            key: _spriteKey(widget.creatureId),
                                            child: Center(
                                              child: creature(cs * 0.86),
                                            ),
                                          ),
                                        ),
                                      ),
                                ),
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _VesselPainter(_field, true, _frame),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The creature's start when the glass is tapped: a quick shake that dies.
class _Wobble extends StatelessWidget {
  const _Wobble({required this.controller, required this.child});
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final v = controller.value;
        if (v == 0 || v == 1) return child!;
        final osc = math.sin(v * math.pi * 9);
        final amp = 4.0 * (1 - v);
        return Transform.translate(
          offset: Offset(osc * amp * 0.6, -osc.abs() * amp * 0.5),
          child: Transform.rotate(angle: osc * 0.018 * (1 - v), child: child),
        );
      },
    );
  }
}
