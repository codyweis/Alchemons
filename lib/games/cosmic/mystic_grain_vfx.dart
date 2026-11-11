// lib/games/cosmic/mystic_grain_vfx.dart
//
// THREE OF A MYSTIC WORLD'S SET PIECES IN GRAINS: the Air world's tornado,
// the Earth world's quake and the Steam world's vent.
//
// The tornado was five stacked pairs of tilted crescents (it read as an
// atom symbol); the quake and the vent were expanding fronts drawn as a
// soft ring with blobs or puffs spaced round it (a faint hoop; a dotted
// circle). Here the funnel is wind turning in grains, each a short run
// along its turn, and the fronts are broad bands of grains whose density
// heaves round them, so they are ground thrown up and steam billowing, not
// a line. The camera pulls back under a Mystic world, so grains are drawn
// large enough to stay over a pixel there.
//
// Budget: at most ~2,000 grains a piece, a handful of point draws, nothing
// allocated per frame.

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

const _tau = pi * 2;

double _h(int i, int salt) {
  final x = sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

const int _tones = 8;
final List<Float32List> _buf = List.generate(_tones, (_) => Float32List(2048));
final List<int> _n = List.filled(_tones, 0);
final ui.Paint _pt = ui.Paint()
  ..strokeCap = ui.StrokeCap.round
  ..style = ui.PaintingStyle.stroke;

void _g(int tone, double x, double y) {
  var b = _buf[tone];
  final i = _n[tone];
  if (i + 2 > b.length) {
    _buf[tone] = b = Float32List(b.length * 2)..setAll(0, b);
  }
  b[i] = x;
  b[i + 1] = y;
  _n[tone] = i + 2;
}

void _flush(ui.Canvas canvas, List<(ui.Color, double)> look, double alpha) {
  for (var t = 0; t < _tones; t++) {
    final n = _n[t];
    if (n == 0) continue;
    _n[t] = 0;
    if (t >= look.length) continue;
    final c = look[t].$1;
    canvas.drawRawPoints(
      ui.PointMode.points,
      Float32List.sublistView(_buf[t], 0, n),
      _pt
        ..color = c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0))
        ..strokeWidth = look[t].$2,
    );
  }
}

// ── Air: the tornado ───────────────────────────────────────────────────────

const _windLook = [
  (ui.Color(0xFFE9F6F4), 3.4), // 0 wind on the near side, lit
  (ui.Color(0xCCB9D6D2), 3.2), // 1
  (ui.Color(0x808FB3B0), 3.0), // 2 the far side, behind the funnel
];

/// The funnel seen from above: wind turning in rings stacked up the column,
/// each wider and further along the [lean] than the last (that offset is
/// height), faster at the foot. Every grain is a short run along its turn.
void paintMysticTornadoGrains(
  ui.Canvas canvas,
  ui.Offset at,
  double radius,
  double phase,
  ui.Offset lean,
  double alpha,
) {
  if (alpha <= 0.01) return;
  const n = 520;
  for (var i = 0; i < n; i++) {
    final f = pow(_h(i, 1), 0.8).toDouble();
    final cx = at.dx + lean.dx * radius * 0.22 * f;
    final cy = at.dy + lean.dy * radius * 0.22 * f;
    final r = radius * (0.2 + 0.65 * f) * (0.9 + 0.2 * _h(i, 2));
    final spin = phase * (3.0 - 1.6 * f);
    final a0 = _h(i, 3) * _tau + spin;
    // Wind is thin where it is drawn in: some of each ring is clear air.
    if (sin(a0 * 2 + f * 5 + phase) < -0.55) continue;
    final near = sin(a0) > 0;
    final tone = near ? (f > 0.4 ? 0 : 1) : 2;
    for (var j = 0; j < 3; j++) {
      final a = a0 - j * 0.07;
      _g(tone, cx + cos(a) * r, cy + sin(a) * r * 0.6);
    }
  }
  _flush(canvas, _windLook, alpha);
}

// ── Earth: the quake front ─────────────────────────────────────────────────

const _quakeLook = [
  (ui.Color(0xFFE2CFA6), 5.0), // 0 thrown up, lit
  (ui.Color(0xFF9C8A6C), 5.0), // 1
  (ui.Color(0xFF3A2E22), 5.2), // 2 broken ground behind it
  (ui.Color(0xFF0E0A07), 5.6), // 3 rubble's shadow side, cracks
];

/// The quake's front going out: a broad band of ground thrown up, heaving
/// in sections round it, with rubble on its leading edge and the ground
/// split behind it. [radius] is how far it reaches at [progress] 1.
void paintMysticQuakeGrains(
  ui.Canvas canvas,
  ui.Offset centre,
  double radius,
  double progress,
) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;
  if (r < 4) return;
  final w = 70 * a + 26;
  // By the band's area: a front this size needs thousands to read as
  // ground, not a dotted ring.
  final n = (2 * pi * r * w / 40).clamp(200, 2200).round();
  for (var i = 0; i < n; i++) {
    final th = _h(i, 11) * _tau;
    // The front heaves in sections, not as one even ring.
    final heave = 0.5 + 0.5 * sin(5 * th + 2 * sin(3 * th) + 1.3);
    if (_h(i, 12) > 0.35 + 0.65 * heave) continue;
    if (_h(i, 13) > a * 1.3 + 0.1) continue;
    final u = pow(_h(i, 14), 0.6).toDouble();
    final d = r * (1 + 0.03 * sin(3 * th + 0.7)) - u * w;
    _g(u < 0.15 ? 0 : (u < 0.5 ? 1 : 2), centre.dx + cos(th) * d,
        centre.dy + sin(th) * d);
  }
  // Rubble heaved up on the leading edge: clumps lit on top.
  final clumps = (2 * pi * r / 46).floor().clamp(8, 60);
  for (var k = 0; k < clumps; k++) {
    if (_h(k, 20) > a + 0.15) continue;
    final th = k * _tau / clumps + _h(k, 21) * 0.08;
    final d = r * (0.98 + 0.05 * _h(k, 22));
    final cx = centre.dx + cos(th) * d, cy = centre.dy + sin(th) * d;
    final s = (5 + 5 * _h(k, 23)) * (0.5 + 0.5 * a);
    for (var j = 0; j < 9; j++) {
      final ga = _h(k * 9 + j, 24) * _tau;
      final gr = s * sqrt(_h(k * 9 + j, 25));
      final lit = sin(ga) < -0.3;
      _g(lit ? 0 : 3, cx + cos(ga) * gr, cy + sin(ga) * gr);
    }
  }
  // The ground split behind it: dark runs out from the middle.
  for (var c = 0; c < 10; c++) {
    final th0 = c * _tau / 10 + 0.21;
    for (var s = 0.68; s < 0.98; s += 0.012) {
      if (_h(c * 101 + (s * 1000).round(), 26) > a + 0.2) continue;
      final th = th0 + sin(c * 2.7 + s * 9) * 0.03;
      _g(3, centre.dx + cos(th) * r * s, centre.dy + sin(th) * r * s);
    }
  }
  _flush(canvas, _quakeLook, 1);
}

// ── Steam: the vent's exhale ───────────────────────────────────────────────

const _ventLook = [
  (ui.Color(0xFFF2FBFB), 3.6), // 0 lit steam
  (ui.Color(0xFFCBD8DA), 3.6), // 1
  (ui.Color(0xCC7F9094), 3.8), // 2 shadowed, thinning
];

/// The vent's exhale going out: a band of steam billowing, lumped round the
/// front and lit on the side toward the light, thinning behind it.
void paintMysticVentGrains(
  ui.Canvas canvas,
  ui.Offset centre,
  double radius,
  double progress,
  double time,
) {
  final t = progress.clamp(0.0, 1.0);
  if (t >= 1) return;
  final eased = 1.0 - (1.0 - t) * (1.0 - t);
  final a = (1.0 - t) * (1.0 - t);
  final r = radius * eased;
  if (r < 4) return;
  // Billows: clumps of steam along the front, each lit on its upper side,
  // the front lumped by their sizes. Single grains spread round a front
  // this size read as a dotted circle.
  // Each wider than the gap to the next, so they run together into one
  // band that swells and thins round the front.
  final billows = (2 * pi * r / 26).floor().clamp(10, 72);
  for (var k = 0; k < billows; k++) {
    final th = k * _tau / billows + (_h(k, 31) - 0.5) * 0.12;
    final swell = 0.5 + 0.5 * sin(6 * th + time * 0.8 + 3 * sin(2 * th));
    final br = (18 + 18 * swell) * (0.7 + 0.3 * a);
    final d = r * (1 + 0.04 * sin(4 * th + time * 1.5)) - br * 0.4;
    final cx = centre.dx + cos(th) * d, cy = centre.dy + sin(th) * d;
    final grains = (br * br * 0.3).round().clamp(12, 160);
    for (var i = 0; i < grains; i++) {
      if (_h(k * 131 + i, 35) > a * 1.1 + 0.12) continue;
      final u = sqrt(_h(k * 131 + i, 32));
      if (u > 0.8 && _h(k * 131 + i, 33) < (u - 0.8) / 0.2) continue;
      final ga = _h(k * 131 + i, 34) * _tau;
      final ly = sin(ga) * u;
      _g(ly < -0.3 ? 0 : (ly < 0.35 ? 1 : 2), cx + cos(ga) * u * br,
          cy + ly * br);
    }
  }
  _flush(canvas, _ventLook, 1);
}
