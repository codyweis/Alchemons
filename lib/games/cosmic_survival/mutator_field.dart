// lib/games/cosmic_survival/mutator_field.dart
//
// WHAT A WAVE'S MUTATOR DOES TO THE FIELD.
//
// A mutator changes a wave's numbers (cosmic_survival_spawner.dart) and
// nothing on screen said so. Each one now lays something over the arena
// floor for as long as its wave runs, in the same grains everything else is
// made of. No rules change and nothing is announced; the field looks
// different because the wave is.
//
//   orbSiege        sand drawn in toward the core from all round
//   hunterSwarm     quick streaks circling the core, the way the packs come
//   arcStorm        short chains of bright grains that gather and let go
//   fortified       broken ramparts of heavy grain turning at the rim
//   shatteredSpace  seams across the floor, glinting, shards adrift on them
//   manaFlux        violet motes rising everywhere, the essence's own light
//
// Nothing is stored per grain: a grain's place is read off its index and
// the clock. Only what is in view is added, and the whole layer is three
// point draws. No blur.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';

const _ink = Color(0xFF07060B);
const _white = Color(0xFFFFF6E4);
const _essence = Color(0xFFB08CFF);
const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

class _Buf {
  Float32List d = Float32List(1024);
  int n = 0;

  void add(double x, double y) {
    if (n + 2 > d.length) d = Float32List(d.length * 2)..setAll(0, d);
    d[n] = x;
    d[n + 1] = y;
    n += 2;
  }
}

class MutatorField {
  SurvivalWaveMutator? _shown;
  double _strength = 0;

  // Dim, the colour itself, and lit.
  final List<_Buf> _pts = List.generate(3, (_) => _Buf());
  Rect _view = Rect.zero;

  static final Paint _pt = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  /// How far the look has come in, 0..1.
  double get strength => _strength;

  /// The mutator whose look is on the field (still fading, perhaps).
  SurvivalWaveMutator? get shown => _strength > 0 ? _shown : null;

  /// Eases the wave's mutator in over a couple of seconds and the last one
  /// out before the next comes in.
  void update(double dt, SurvivalWaveMutator? mutator) {
    if (mutator != _shown && _strength <= 0.02) {
      _shown = mutator;
      _strength = 0;
    }
    final want = mutator != null && mutator == _shown ? 1.0 : 0.0;
    _strength += (want - _strength) * min(1.0, dt * 0.7);
    if (want == 0 && _strength < 0.02) _strength = 0;
  }

  void _add(int tone, double x, double y) {
    if (x < _view.left || x > _view.right || y < _view.top || y > _view.bottom) {
      return;
    }
    _pts[tone].add(x, y);
  }

  /// Draws the look over the floor. [core] is the orb, [rim] the arena's
  /// radius, [color] the wave's element.
  void paint(
    Canvas canvas,
    Rect view,
    Offset core,
    double rim,
    double time,
    Color color,
  ) {
    final shown = _shown;
    if (shown == null || _strength <= 0) return;
    _view = view.inflate(8);
    // Lifted toward bone, so a dark element's wave still shows on the floor.
    var tint = Color.lerp(color, _white, 0.42)!;
    var fluxLit = false;
    switch (shown) {
      case SurvivalWaveMutator.orbSiege:
        _siege(view, core, time);
      case SurvivalWaveMutator.hunterSwarm:
        _hunters(view, core, time);
      case SurvivalWaveMutator.arcStorm:
        _arcs(view, time);
        tint = Color.lerp(color, _white, 0.6)!;
      case SurvivalWaveMutator.fortified:
        _ramparts(core, rim, time);
        tint = Color.lerp(color, const Color(0xFF8E8778), 0.55)!;
      case SurvivalWaveMutator.shatteredSpace:
        _seams(core, rim, time);
      case SurvivalWaveMutator.manaFlux:
        _flux(view, time);
        tint = _essence;
        fluxLit = true;
    }
    final a = _strength;
    final tones = [
      Color.lerp(tint, _ink, 0.35)!.withValues(alpha: 0.5 * a),
      tint.withValues(alpha: 0.75 * a),
      Color.lerp(tint, _white, fluxLit ? 0.25 : 0.55)!.withValues(
        alpha: 0.95 * a,
      ),
    ];
    final sizes = fluxLit ? const [2.0, 2.6, 3.4] : const [1.8, 2.2, 2.7];
    for (var t = 0; t < 3; t++) {
      final b = _pts[t];
      if (b.n == 0) continue;
      canvas.drawRawPoints(
        PointMode.points,
        Float32List.sublistView(b.d, 0, b.n),
        _pt
          ..strokeWidth = sizes[t]
          ..color = tones[t],
      );
      b.n = 0;
    }
  }

  /// Sand running in toward the core from everywhere in view, each grain
  /// dragging a second behind it.
  void _siege(Rect view, Offset core, double time) {
    const cell = 44.0;
    final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
    final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
    for (var gx = x0; gx < x1; gx++) {
      for (var gy = y0; gy < y1; gy++) {
        final id = gx * 7919 + gy * 104729;
        final bx = (gx + _h(id, 1)) * cell, by = (gy + _h(id, 2)) * cell;
        final dx = core.dx - bx, dy = core.dy - by;
        final d = sqrt(dx * dx + dy * dy);
        if (d < 120) continue;
        final s = (_h(id, 3) + time * (0.35 + 0.25 * _h(id, 4))) % 1.0;
        // Faint as it starts and as it goes, so the run never pops.
        final edge = sin(s * pi);
        if (edge < 0.2) continue;
        final run = (s - 0.5) * cell * 2.4;
        final x = bx + dx / d * run, y = by + dy / d * run;
        // A short run of grains along the line to the core: a lone grain
        // on this floor is a star.
        for (var k = 0; k < 5; k++) {
          _add(
            k == 0 && edge > 0.7 ? 2 : (k < 3 ? 1 : 0),
            x - dx / d * k * 5.5,
            y - dy / d * k * 5.5,
          );
        }
      }
    }
  }

  /// Quick streaks circling the core, ring by ring in opposite directions.
  void _hunters(Rect view, Offset core, double time) {
    const cell = 84.0;
    final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
    final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
    for (var gx = x0; gx < x1; gx++) {
      for (var gy = y0; gy < y1; gy++) {
        final id = gx * 7919 + gy * 104729;
        final bx = (gx + _h(id, 11)) * cell, by = (gy + _h(id, 12)) * cell;
        final dx = bx - core.dx, dy = by - core.dy;
        final d = sqrt(dx * dx + dy * dy);
        if (d < 140) continue;
        final dir = (d / 110).floor().isEven ? 1.0 : -1.0;
        final s = (_h(id, 13) + time * (0.9 + 0.5 * _h(id, 14))) % 1.0;
        final edge = sin(s * pi);
        if (edge < 0.25) continue;
        // Along the tangent: across the line to the core.
        final tx = -dy / d * dir, ty = dx / d * dir;
        final run = (s - 0.5) * cell * 2.6;
        // A pack of three running abreast, the middle one ahead: one short
        // streak of five grains was lost on the floor.
        for (var m = 0; m < 3; m++) {
          final abreast = (m - 1) * 9.0;
          final lag = m == 1 ? 0.0 : 9.0 + 6.0 * _h(id, 15 + m);
          final ox = dx / d * abreast, oy = dy / d * abreast;
          for (var k = 0; k < 9; k++) {
            final at = run - lag - k * 5.0;
            _add(
              k == 0 && edge > 0.5 ? 2 : (k < 4 ? 1 : 0),
              bx + ox + tx * at,
              by + oy + ty * at,
            );
          }
        }
      }
    }
  }

  /// Short chains of bright grains that gather, hold a moment and let go,
  /// each cell of the view on its own clock.
  void _arcs(Rect view, double time) {
    const cell = 105.0;
    final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
    final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
    for (var gx = x0; gx < x1; gx++) {
      for (var gy = y0; gy < y1; gy++) {
        final id = gx * 7919 + gy * 104729;
        final clock = time * 0.55 + _h(id, 21) * 9;
        final beat = clock.floor();
        final s = clock - beat;
        // Eased in and out, so nothing pops.
        final lit = sin(s * pi);
        if (lit < 0.35) continue;
        var x = (gx + _h(id + beat, 22)) * cell;
        var y = (gy + _h(id + beat, 23)) * cell;
        var a = _h(id + beat, 24) * _tau;
        final links = (6 + 9 * (lit - 0.35) / 0.65).round();
        for (var k = 0; k < links; k++) {
          _add(lit > 0.8 && k.isEven ? 2 : 1, x, y);
          a += (_h(id + beat + k, 25) - 0.5) * 1.5;
          x += cos(a) * 6.5;
          y += sin(a) * 6.5;
        }
      }
    }
  }

  /// Broken ramparts of heavy grain ringing the core, band outside band,
  /// each turning against the next.
  void _ramparts(Offset core, double rim, double time) {
    var band = 0;
    for (var r0 = 250.0; r0 < rim; r0 += 165, band++) {
      final turn = time * (band.isEven ? 0.03 : -0.024) * 250 / r0;
      final slots = (_tau * r0 / 6.5).floor();
      final plates = 5 + band * 2;
      for (var i = 0; i < slots; i++) {
        final u = i / slots;
        // Plates with gaps between them.
        if ((u * plates + band * 0.37) % 1.0 > 0.68) continue;
        final a = u * _tau + turn;
        final x = core.dx + r0 * cos(a), y = core.dy + r0 * sin(a);
        if (x < _view.left - 20 ||
            x > _view.right + 20 ||
            y < _view.top - 20 ||
            y > _view.bottom + 20) {
          continue;
        }
        // Three courses deep, the inner face lit.
        for (var course = 0; course < 3; course++) {
          final r = r0 + course * 7 + 6 * (_h(i + band * 977, 31 + course) - 0.5);
          final b = a + 5 * (_h(i + band * 977, 35 + course) - 0.5) / r0;
          _add(
            course == 0 ? 2 : (course == 1 ? 1 : 0),
            core.dx + r * cos(b),
            core.dy + r * sin(b),
          );
        }
      }
    }
  }

  /// Seams running out across the floor from near the core, glints
  /// travelling along them and shards adrift at their edges.
  void _seams(Offset core, double rim, double time) {
    for (var seam = 0; seam < 16; seam++) {
      var a = seam * _tau / 16 + _h(seam, 41) * 0.3;
      var x = core.dx + 150 * cos(a), y = core.dy + 150 * sin(a);
      final glint = (time * 0.22 + _h(seam, 42)) % 1.0;
      const steps = 150;
      final step = (rim - 150) / steps;
      for (var k = 0; k < steps; k++) {
        // A seam kinks every so often and otherwise runs straight.
        if (k % 14 == 6) a += (_h(seam * 100 + k, 43) - 0.5) * 0.9;
        x += cos(a) * step;
        y += sin(a) * step;
        final near = (k / steps - glint).abs() < 0.04;
        _add(near ? 2 : 1, x, y);
        _add(0, x - sin(a) * 4, y + cos(a) * 4);
        // A shard off to one side, slowly drifting out and back.
        if (k % 4 == 0) {
          final off =
              (10 + 16 * _h(seam * 100 + k, 44)) *
              (k.isEven ? 1 : -1) *
              (0.6 + 0.4 * sin(time * 0.5 + k));
          _add(0, x - sin(a) * off, y + cos(a) * off);
        }
      }
    }
  }

  /// Motes rising everywhere in the essence's own violet, swaying and
  /// twinkling as they go.
  void _flux(Rect view, double time) {
    const cell = 46.0;
    final x0 = (view.left / cell).floor(), x1 = (view.right / cell).ceil();
    final y0 = (view.top / cell).floor(), y1 = (view.bottom / cell).ceil();
    for (var gx = x0; gx < x1; gx++) {
      for (var gy = y0; gy < y1; gy++) {
        final id = gx * 7919 + gy * 104729;
        // Two cells in three: every cell made it a curtain of rain.
        if (_h(id, 56) < 0.34) continue;
        final rise = (_h(id, 51) + time * (0.13 + 0.11 * _h(id, 52))) % 1.0;
        final phase = _h(id, 54) * _tau;
        final bx = (gx + _h(id, 53)) * cell;
        final by = (gy + 1.5 - rise * 2) * cell;
        // Faint as it starts and as it goes.
        final edge = sin(rise * pi);
        if (edge < 0.2) continue;
        // A wisp, not a mote: a lit head and what it sheds below it, swaying
        // as it climbs. (One grain at a time read as a star on the floor.)
        for (var k = 0; k < 5; k++) {
          final y = by + k * 5.5;
          final x = bx + 7 * sin(time * 0.9 + phase + y * 0.045);
          _add(k == 0 && edge > 0.45 ? 2 : (k < 3 && edge > 0.5 ? 1 : 0), x, y);
        }
      }
    }
  }
}
