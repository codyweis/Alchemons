// lib/widgets/animations/hatch_sand.dart
//
// THE SAND THE CEREMONY STANDS IN. Round the extraction ceremony's shell, a
// bank of fine sand along the screen's edges, the middle left black with only
// a light scatter across it. The sand is the two parents' elements: each
// parent's on the side its strands are born on, marbled together along the top
// and the foot where the two meet. A finger drawn through it stirs it like sand
// in water (the home realm's and the wild map's flow, the same constants), a
// tap pushes it out, and it settles back. When the shell bursts, a wave rolls
// out from under it and breaks against the banks.
//
// Dressed by what is hatching:
//   elements    the two parents' sands, a few grains glinting in their light;
//   prismatic   rainbow sand, once round the screen, its glints turning
//               through the hues;
//   gilded      Transmuted: the same sands read into gold, a polish sweeping
//               across them;
//   loose       Alchemized: it never settles. Every grain is loose and the
//               banks run round the screen like a river, in two layers
//               running against each other. A stir stays in it and is carried
//               off along the bank instead of smoothing back out.
//
// Cheap at rest: still grains are drawn once into pictures, one for the whole
// field while nothing is stirred and one per 48 px square while something is,
// and only the squares a finger has moved are drawn grain by grain. Glints are
// a few hundred sprites a frame. Loose sand is all live, so it carries fewer
// grains. No blur.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart'
    show HatchShellPainter, ShellMutationLook;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

const double _tau = math.pi * 2;

/// What the sand is coloured as.
enum HatchSandColour {
  /// The two parents' sands, each on its own side, marbled where they meet.
  elements,

  /// Rainbow sand, its glints turning through the hues.
  prismatic,

  /// Transmuted: the parents' sands read into gold, a polish sweeping over.
  gilded,
}

// What a grain does besides sit still: twinkle in its own light, catch the
// gold's polish as it passes, or turn through the hues.
const int _still = 0, _twinkle = 1, _polish = 2, _turn = 3;

/// The rainbow, as the newborn's prismatic grains have it.
const List<int> _prism = [
  0xFFFF6B6B,
  0xFFFFB86B,
  0xFFFFE66D,
  0xFF4ECDC4,
  0xFF6B9BFF,
  0xFFB06BFF,
];

/// The field: grains, the flow a finger leaves in them, and the burst's wave.
class HatchSandField {
  HatchSandField({
    required List<Color> paletteA,
    required List<Color> paletteB,
    this.colour = HatchSandColour.elements,
    this.loose = false,
    this.fleck,
    this.looseLight = const Color(0xFFB9A7F5),
    this.reduced = false,
  }) : _pa = _three(paletteA),
       _pb = _three(paletteB);

  final HatchSandColour colour;

  /// Alchemized: the grains never settle. See the file's head.
  final bool loose;

  /// A variant's colour: a scatter of grains of it, twinkling.
  final Color? fleck;

  /// The light loose grains glint in (Alchemized's violet).
  final Color looseLight;

  /// Fewer grains, for the performance setting.
  final bool reduced;

  // Each parent's (dark body, light body, accent). A is the parent whose
  // strands are born on the shell's right.
  final List<Color> _pa, _pb;

  static List<Color> _three(List<Color> p) => switch (p.length) {
    0 => const [Color(0xFF8A7A66), Color(0xFFB8A68C), Color(0xFFE8DCC8)],
    1 => [p[0], p[0], p[0]],
    2 => [p[0], p[1], p[1]],
    _ => [p[0], p[1], p[2]],
  };

  /// Grains handed to the canvas one by one last frame (pictures aside).
  int debugSprites = 0;

  /// Pictures drawn last frame.
  int debugPictures = 0;

  Size _size = Size.zero;
  Offset _centre = Offset.zero;
  Offset _axis = const Offset(1, 0);
  double _span = 1;
  double _t = 0;

  // ── Grains ────────────────────────────────────────────────────────────

  int _n = 0;
  // Home, offset from it, velocity; size, phase, a per-role number.
  Float32List _hx = Float32List(0), _hy = Float32List(0);
  Float32List _ox = Float32List(0), _oy = Float32List(0);
  Float32List _vx = Float32List(0), _vy = Float32List(0);
  Float32List _sz = Float32List(0), _ph = Float32List(0);
  Float32List _aux = Float32List(0);
  // At rest, and lit (pushed fast; a glint's peak).
  Int32List _c = Int32List(0), _c2 = Int32List(0);
  Uint8List _role = Uint8List(0), _busy = Uint8List(0);

  // Loose sand: the radius each grain turns at, its turn (signed: its layer)
  // and how hard it is pushed off that turn (for its light).
  Float32List _r0 = Float32List(0), _w = Float32List(0);
  Float32List _push = Float32List(0);

  // Grains [0, _restEnd) hold still and are sorted by square; the rest glint
  // and are drawn every frame.
  int _restEnd = 0;

  @visibleForTesting
  int get grainCount => _n;

  @visibleForTesting
  Offset debugGrainAt(int i) => Offset(_hx[i] + _ox[i], _hy[i] + _oy[i]);

  @visibleForTesting
  int debugColourOf(int i) => _c[i];

  // ── Squares (for the pictures) ────────────────────────────────────────

  static const double _cs = 48;
  int _cw = 0, _ch = 0;
  Int32List _chunkFrom = Int32List(0), _chunkTo = Int32List(0);
  Uint8List _chunkFlow = Uint8List(0), _chunkBusy = Uint8List(0);
  List<ui.Picture?> _chunkPics = const [];
  ui.Picture? _allPic;

  void layout(Size size) {
    if (size.isEmpty || size == _size) return;
    _size = size;
    _span = size.shortestSide;
    // Where the shell stands and which way its two clusters lie, from the
    // shell itself, so each parent's sand is on its own strands' side.
    final (a, b) = HatchShellPainter.clusterCentres(size);
    _centre = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final d = a - b;
    _axis = d / math.max(1e-6, d.distance);
    _compose();
    _sortForRest();
    _fieldW = (size.width / _cell).ceil() + 2;
    _fieldH = (size.height / _cell).ceil() + 2;
    _fu = Float32List(_fieldW * _fieldH);
    _fv = Float32List(_fieldW * _fieldH);
    _ft = Float32List(_fieldW * _fieldH);
    _fieldOn = false;
    _waveR = -1;
  }

  /// How deep the bank runs in from the edge, as a share of the short side.
  static const double _bank = 0.13;

  /// The scatter across the black, as a share of the bank's thickness.
  static const double _scatter = 0.035;

  // Enough for the banks to read as sand (about one grain per 11 px² where
  // they are full), capped: a big screen gets bigger grains, not more of
  // them. The field's area is sampled on a coarse grid.
  int _grainsFor() {
    const g = 40;
    var sum = 0.0;
    for (var j = 0; j < g; j++) {
      for (var i = 0; i < g; i++) {
        sum += _density(
          (i + 0.5) / g * _size.width,
          (j + 0.5) / g * _size.height,
        );
      }
    }
    final area = sum / (g * g) * _size.width * _size.height;
    final n = (area / 11).round().clamp(2500, 14000);
    return (n * (reduced ? 0.6 : 1.0) * (loose ? 0.65 : 1.0)).round();
  }

  // How far (x, y) lies in from the screen's edge. The top counts a little
  // further and the foot a little nearer, so the sand lies deeper at the
  // foot, as it would settle.
  double _inFrom(double x, double y) => math.min(
    math.min(x, _size.width - x),
    math.min(y * 1.1, (_size.height - y) * 0.85),
  );

  // How thickly the sand lies at (x, y), 0..1: a bank along the edges,
  // thickest at the very edge, its inner side wandering as a drift's does,
  // and only a light scatter across the black inside it.
  double _density(double x, double y) {
    final e = _inFrom(x, y) / _span;
    final edge =
        _bank +
        0.13 * (_fbm(x / 120, y / 120, 7) - 0.5) +
        0.04 * (_fbm(x / 40, y / 40, 9) - 0.5);
    final inside = 1 - _smoothstep(edge - 0.05, edge + 0.01, e);
    final deep = 0.55 + 0.45 * (1 - (e / edge).clamp(0.0, 1.0));
    final grain = 0.6 + 0.6 * _fbm(x / 80, y / 80, 3);
    return math.min(1.0, inside * deep * grain + (1 - inside) * _scatter);
  }

  void _compose() {
    final want = _grainsFor();
    final r = math.Random(23);
    final w = _size.width, h = _size.height;
    final grain = (_span / 420).clamp(1.0, 1.5);
    _hx = Float32List(want);
    _hy = Float32List(want);
    _sz = Float32List(want);
    _ph = Float32List(want);
    _aux = Float32List(want);
    _c = Int32List(want);
    _c2 = Int32List(want);
    _role = Uint8List(want);
    _r0 = Float32List(want);
    _w = Float32List(want);
    var i = 0, tries = 0;
    while (i < want && tries < want * 40) {
      tries++;
      final x = r.nextDouble() * w, y = r.nextDouble() * h;
      if (r.nextDouble() > _density(x, y)) continue;
      _hx[i] = x;
      _hy[i] = y;
      _sz[i] = (1.0 + 1.1 * r.nextDouble()) * grain;
      _ph[i] = r.nextDouble();
      _dress(i, x, y, r);
      if (loose) {
        _r0[i] = _inFrom(x, y);
        // Most run one way; a layer of them runs slower, the other way.
        _w[i] = r.nextDouble() < 0.28 ? -0.6 : 1.0;
      }
      i++;
    }
    _n = i;
    _ox = Float32List(_n);
    _oy = Float32List(_n);
    _vx = Float32List(_n);
    _vy = Float32List(_n);
    _busy = Uint8List(_n);
    _push = Float32List(_n);
  }

  // How much of parent A's sand lies at (x, y): A on its own side of the
  // shell, B on the other, the line between them warped into swirls and
  // dithered across a band, so the two read as poured together, not split.
  double _sideA(double x, double y) {
    final along =
        ((x - _centre.dx) * _axis.dx + (y - _centre.dy) * _axis.dy) / _span;
    final warp =
        0.36 * (_fbm(x / 160, y / 160, 11) - 0.5) +
        0.05 * math.sin(y / _span * 8);
    return _smoothstep(-0.1, 0.1, along + warp);
  }

  // The rainbow once round the screen, its bands warped as the sides are.
  double _hueAt(double x, double y) {
    final a = math.atan2(y - _size.height / 2, x - _size.width / 2);
    final h = 3 + a / _tau * 6 + 1.8 * (_fbm(x / 140, y / 140, 17) - 0.5);
    return h - (h / 6).floorToDouble() * 6;
  }

  void _dress(int i, double x, double y, math.Random r) {
    final p = r.nextDouble() < _sideA(x, y) ? _pa : _pb;
    final body = Color.lerp(p[0], p[1], r.nextDouble())!;
    // Most grains deep in shadow, a few catching light; loose ones catch
    // more of it, being in the air.
    final v = loose
        ? 0.34 + 0.46 * math.pow(r.nextDouble(), 1.4)
        : 0.32 + 0.48 * math.pow(r.nextDouble(), 1.5);
    _role[i] = _still;
    switch (colour) {
      case HatchSandColour.elements:
        _c[i] = _shade(body, v, 0.95);
        _c2[i] = _shade(Color.lerp(body, p[2], 0.55)!, 1, 1);
        if (r.nextDouble() < 0.02) {
          _role[i] = _twinkle;
          _c2[i] = _shade(p[2], 1, 1);
        }
      case HatchSandColour.prismatic:
        final hue = _hueAt(x, y);
        final c = Color(_prismAt(hue));
        // A little brighter than the parents' sands: the bands are the point.
        _c[i] = _shade(c, v + 0.1, 0.95);
        _c2[i] = _shade(c, 1, 1);
        _aux[i] = hue;
        if (r.nextDouble() < 0.07) _role[i] = _turn;
      case HatchSandColour.gilded:
        final g = ShellMutationLook.gilt(body, shade: r.nextDouble());
        _c[i] = _shade(g, v + 0.08, 0.95);
        _c2[i] = _shade(Color.lerp(g, ShellMutationLook.paleGold, 0.6)!, 1, 1);
        // Where the polish finds it: across and a little down.
        _aux[i] = 0.7 * x / _size.width + 0.3 * y / _size.height;
        if (r.nextDouble() < 0.09) _role[i] = _polish;
    }
    final f = fleck;
    if (f != null && _role[i] == _still && r.nextDouble() < 0.04) {
      _role[i] = _twinkle;
      _c[i] = _shade(f, 0.45, 0.95);
      _c2[i] = _shade(f, 1, 1);
    }
    // Loose: one grain in twelve is the mutation's own violet.
    if (loose && _role[i] == _still && r.nextDouble() < 0.08) {
      _role[i] = _twinkle;
      _c[i] = _shade(looseLight, v + 0.1, 0.95);
      _c2[i] = _shade(looseLight, 1, 1);
    }
  }

  /// Still grains first, grouped by square; then everything that glints.
  void _sortForRest() {
    _cw = (_size.width / _cs).ceil() + 1;
    _ch = (_size.height / _cs).ceil() + 1;
    final chunks = _cw * _ch;
    final key = Int32List(_n);
    for (var i = 0; i < _n; i++) {
      key[i] = _role[i] != _still ? chunks : _chunkAt(_hx[i], _hy[i]);
    }
    final order = List<int>.generate(_n, (i) => i)
      ..sort((a, b) => key[a] - key[b]);
    _hx = _permF(_hx, order);
    _hy = _permF(_hy, order);
    _sz = _permF(_sz, order);
    _ph = _permF(_ph, order);
    _aux = _permF(_aux, order);
    _r0 = _permF(_r0, order);
    _w = _permF(_w, order);
    _c = _permI(_c, order);
    _c2 = _permI(_c2, order);
    _role = _permB(_role, order);
    _chunkFrom = Int32List(chunks);
    _chunkTo = Int32List(chunks);
    _restEnd = 0;
    var c = 0;
    for (var j = 0; j < _n; j++) {
      final k = key[order[j]];
      if (k >= chunks) break;
      while (c < k) {
        _chunkTo[c] = j;
        c++;
        _chunkFrom[c] = j;
      }
      _restEnd = j + 1;
    }
    while (c < chunks) {
      _chunkTo[c] = _restEnd;
      if (c + 1 < chunks) _chunkFrom[c + 1] = _restEnd;
      c++;
    }
    _chunkFlow = Uint8List(chunks);
    _chunkBusy = Uint8List(chunks);
    _dropPictures();
  }

  int _chunkAt(double x, double y) {
    final cx = (x / _cs).floor().clamp(0, _cw - 1);
    final cy = (y / _cs).floor().clamp(0, _ch - 1);
    return cy * _cw + cx;
  }

  void _dropPictures() {
    for (final p in _chunkPics) {
      p?.dispose();
    }
    _chunkPics = List<ui.Picture?>.filled(_cw * _ch, null);
    _allPic?.dispose();
    _allPic = null;
  }

  void dispose() => _dropPictures();

  // ── The flow a finger leaves (the wild map's) ─────────────────────────

  static const double _cell = 14;
  int _fieldW = 0, _fieldH = 0;
  Float32List _fu = Float32List(0), _fv = Float32List(0), _ft = Float32List(0);
  bool _fieldOn = false;

  /// A finger drawn [delta] (px, over [dt] s) through [at].
  void stir(Offset at, Offset delta, double dt) {
    if (_fieldW == 0) return;
    final s = 1 / math.max(dt, 1 / 120);
    final ux = (delta.dx * s).clamp(-1600.0, 1600.0);
    final uy = (delta.dy * s).clamp(-1600.0, 1600.0);
    _inject(at, 50, (dx, dy, w) => (ux * w, uy * w), blend: true);
  }

  /// A push out from [at], as a tap gives.
  void ripple(Offset at, {double strength = 260, double reach = 70}) {
    if (_fieldW == 0) return;
    _inject(at, reach, (dx, dy, w) {
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      return (dx / l * strength * w, dy / l * strength * w);
    });
  }

  void _inject(
    Offset at,
    double reach,
    (double, double) Function(double dx, double dy, double w) push, {
    bool blend = false,
  }) {
    final g0x = ((at.dx - reach) / _cell).floor().clamp(0, _fieldW - 1);
    final g1x = ((at.dx + reach) / _cell).ceil().clamp(0, _fieldW - 1);
    final g0y = ((at.dy - reach) / _cell).floor().clamp(0, _fieldH - 1);
    final g1y = ((at.dy + reach) / _cell).ceil().clamp(0, _fieldH - 1);
    for (var gy = g0y; gy <= g1y; gy++) {
      for (var gx = g0x; gx <= g1x; gx++) {
        final dx = gx * _cell - at.dx, dy = gy * _cell - at.dy;
        final q = (dx * dx + dy * dy) / (reach * reach);
        if (q >= 1) continue;
        final w = (1 - q) * (1 - q);
        final (pu, pv) = push(dx, dy, w);
        final i = gy * _fieldW + gx;
        if (blend) {
          // Toward the finger's own speed, never past it.
          _fu[i] += (pu / math.max(w, 1e-3) - _fu[i]) * w * 0.7;
          _fv[i] += (pv / math.max(w, 1e-3) - _fv[i]) * w * 0.7;
        } else {
          _fu[i] += pu;
          _fv[i] += pv;
        }
      }
    }
    _fieldOn = true;
    _markChunks(
      g0x * _cell - _cell,
      g0y * _cell - _cell,
      g1x * _cell + _cell,
      g1y * _cell + _cell,
    );
  }

  void _markChunks(double x0, double y0, double x1, double y1) {
    final a = (x0 / _cs).floor().clamp(0, _cw - 1);
    final b = (x1 / _cs).floor().clamp(0, _cw - 1);
    final c = (y0 / _cs).floor().clamp(0, _ch - 1);
    final d = (y1 / _cs).floor().clamp(0, _ch - 1);
    for (var y = c; y <= d; y++) {
      for (var x = a; x <= b; x++) {
        _chunkFlow[y * _cw + x] = 1;
      }
    }
  }

  void _stepField(double dt) {
    _chunkFlow.fillRange(0, _chunkFlow.length, 0);
    if (!_fieldOn) return;
    final decay = math.exp(-dt / 0.3);
    var most = 0.0;
    for (final f in [_fu, _fv]) {
      final t = _ft;
      for (var gy = 0; gy < _fieldH; gy++) {
        for (var gx = 0; gx < _fieldW; gx++) {
          final i = gy * _fieldW + gx;
          var s = f[i] * 4;
          var w = 4.0;
          if (gx > 0) {
            s += f[i - 1];
            w++;
          }
          if (gx < _fieldW - 1) {
            s += f[i + 1];
            w++;
          }
          if (gy > 0) {
            s += f[i - _fieldW];
            w++;
          }
          if (gy < _fieldH - 1) {
            s += f[i + _fieldW];
            w++;
          }
          t[i] = s / w * decay;
        }
      }
      for (var i = 0; i < f.length; i++) {
        f[i] = t[i];
        final a = f[i].abs();
        if (a > most) most = a;
        // Slower than this barely moves a grain: not worth waking for.
        if (a > 12) {
          final x = (i % _fieldW) * _cell, y = (i ~/ _fieldW) * _cell;
          _markChunks(x - _cell, y - _cell, x + _cell, y + _cell);
        }
      }
    }
    if (most < 3) {
      _fu.fillRange(0, _fu.length, 0);
      _fv.fillRange(0, _fv.length, 0);
      _fieldOn = false;
    }
  }

  // The flow at (x, y), into [_su], [_sv].
  double _su = 0, _sv = 0;
  void _sample(double x, double y) {
    _su = _sv = 0;
    final fx = x / _cell, fy = y / _cell;
    final gx = fx.floor(), gy = fy.floor();
    if (gx < 0 || gy < 0 || gx >= _fieldW - 1 || gy >= _fieldH - 1) return;
    final tx = fx - gx, ty = fy - gy;
    final i = gy * _fieldW + gx;
    final u0 = _fu[i], u1 = _fu[i + 1], u2 = _fu[i + _fieldW];
    final u3 = _fu[i + _fieldW + 1];
    _su = u0 + (u1 - u0) * tx + (u2 - u0) * ty + (u0 - u1 - u2 + u3) * tx * ty;
    final v0 = _fv[i], v1 = _fv[i + 1], v2 = _fv[i + _fieldW];
    final v3 = _fv[i + _fieldW + 1];
    _sv = v0 + (v1 - v0) * tx + (v2 - v0) * ty + (v0 - v1 - v2 + v3) * tx * ty;
  }

  // ── The burst ─────────────────────────────────────────────────────────

  // How far out the wave has rolled (px); below 0 when there is none.
  double _waveR = -1;
  static const double _waveKick = 330;

  /// The shell bursting: a wave rolls out through the sand from under it.
  void burst() {
    if (_n == 0) return;
    _waveR = 0;
  }

  void _stepWave(double dt) {
    if (_waveR < 0) return;
    final r0 = _waveR, r1 = r0 + _span * 1.5 * dt;
    _waveR = r1;
    final cx = _centre.dx, cy = _centre.dy;
    final r0s = r0 * r0, r1s = r1 * r1;
    // The kick is slower than the wave, so no grain is caught by it twice.
    for (var k = 0; k < _n; k++) {
      final dx = _hx[k] + _ox[k] - cx, dy = _hy[k] + _oy[k] - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < r0s || d2 >= r1s) continue;
      final d = math.sqrt(d2) + 1e-3;
      final f = _waveKick / (1 + d / (0.5 * _span));
      _vx[k] += dx / d * f;
      _vy[k] += dy / d * f;
      _busy[k] = 1;
      if (k < _restEnd) _chunkBusy[_chunkAt(_hx[k], _hy[k])] = 1;
    }
    if (r1 > _size.longestSide * 1.2) _waveR = -1;
  }

  // ── Stepping ──────────────────────────────────────────────────────────

  void step(double dt) {
    if (_n == 0 || dt <= 0) return;
    _t += dt;
    _stepField(dt);
    _stepWave(dt);
    if (loose) {
      _stepLoose(dt);
      return;
    }
    for (var c = 0; c < _chunkFrom.length; c++) {
      if (_chunkFlow[c] == 0 && _chunkBusy[c] == 0) continue;
      _chunkBusy[c] = _stepGrains(_chunkFrom[c], _chunkTo[c], dt) ? 1 : 0;
    }
    _stepGrains(_restEnd, _n, dt);
  }

  /// Grains [from]..[to] pushed by the flow and pulled home; whether any is
  /// still off its home.
  bool _stepGrains(int from, int to, double dt) {
    const drag = 5.0, spring = 14.0;
    final on = _fieldOn;
    var off = false;
    for (var k = from; k < to; k++) {
      if (!on && _busy[k] == 0) continue;
      var ox = _ox[k], oy = _oy[k], vx = _vx[k], vy = _vy[k];
      var fu = 0.0, fv = 0.0;
      if (on) {
        _sample(_hx[k] + ox, _hy[k] + oy);
        fu = _su;
        fv = _sv;
      }
      vx += (drag * (fu - vx) - spring * ox) * dt;
      vy += (drag * (fv - vy) - spring * oy) * dt;
      ox += vx * dt;
      oy += vy * dt;
      if (fu.abs() < 1 &&
          fv.abs() < 1 &&
          ox.abs() < 0.05 &&
          oy.abs() < 0.05 &&
          vx.abs() < 0.5 &&
          vy.abs() < 0.5) {
        ox = oy = vx = vy = 0;
        _busy[k] = 0;
      } else {
        _busy[k] = 1;
        off = true;
      }
      _ox[k] = ox;
      _oy[k] = oy;
      _vx[k] = vx;
      _vy[k] = vy;
    }
    return off;
  }

  /// Loose sand: every grain carried round the screen along its own bank,
  /// clockwise (a layer of them slower, the other way), pushed by the flow
  /// on top of it, with nothing pulling it back to a home. Only how far in
  /// from the edge it runs is held, and loosely: wherever a stir leaves it,
  /// it soon takes as its own.
  void _stepLoose(double dt) {
    final w = _size.width, h = _size.height;
    final on = _fieldOn;
    final follow = math.min(1.0, 2.6 * dt);
    final keep = math.min(1.0, 0.45 * dt);
    final speed = 0.075 * _span;
    // Within this of the nearest edge another edge has a say in which way a
    // grain runs, so it rounds the corners instead of turning on them.
    const soft = 16.0;
    for (var k = 0; k < _n; k++) {
      final x = _hx[k], y = _hy[k];
      final dl = x, dr = w - x, dtop = y * 1.1, dbot = (h - y) * 0.85;
      final e = math.min(math.min(dl, dr), math.min(dtop, dbot));
      final wl = _say(dl - e, soft), wr = _say(dr - e, soft);
      final wt = _say(dtop - e, soft), wb = _say(dbot - e, soft);
      // Clockwise: right along the top, down the right, left along the foot,
      // up the left. Inward is away from whichever edges have the say.
      var fx = wt - wb, fy = wr - wl;
      final fl = math.sqrt(fx * fx + fy * fy);
      if (fl > 1e-3) {
        fx /= fl;
        fy /= fl;
      }
      var nx = wl - wr, ny = wt - wb;
      final nl = math.sqrt(nx * nx + ny * ny);
      if (nl > 1e-3) {
        nx /= nl;
        ny /= nl;
      }
      final run = _w[k] * speed;
      final pull = (_r0[k] - e) * 0.9;
      final tx = fx * run + nx * pull, ty = fy * run + ny * pull;
      var ux = tx, uy = ty;
      if (on) {
        _sample(x, y);
        ux += _su;
        uy += _sv;
      }
      final vx = _vx[k] + (ux - _vx[k]) * follow;
      final vy = _vy[k] + (uy - _vy[k]) * follow;
      _vx[k] = vx;
      _vy[k] = vy;
      _hx[k] = x + vx * dt;
      _hy[k] = y + vy * dt;
      _push[k] = (vx - tx).abs() + (vy - ty).abs();
      // Never off the screen for good: a grain thrown past the edge is drawn
      // back in.
      _r0[k] = math.max(2.0, _r0[k] + (e - _r0[k]) * keep);
    }
  }

  static double _say(double d, double soft) => d >= soft ? 0 : 1 - d / soft;

  // ── Drawing ───────────────────────────────────────────────────────────

  static ui.Image? _atlas;
  static final Paint _over = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _add = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  final _Batch _dots = _Batch(_solid);
  final _Batch _glow = _Batch(_soft);

  /// The sand settling in at the start, 0..1: until it is in, every grain
  /// is drawn live, falling the last few pixels into its place.
  double get _appear => _smooth01((_t - 0.05) / 1.1);

  double _settle(int k, double appear) =>
      _smooth01(appear * 1.5 - _ph[k] * 0.5);

  void paint(Canvas canvas) {
    debugSprites = 0;
    debugPictures = 0;
    if (_size.isEmpty || _n == 0) return;
    final atlas = _atlas ??= _buildAtlas();
    _dots.clear();
    _glow.clear();
    final appear = _appear;
    if (loose) {
      _emitLoose(appear);
    } else if (appear < 1) {
      for (var k = 0; k < _restEnd; k++) {
        _emitStill(k, appear);
      }
      for (var k = _restEnd; k < _n; k++) {
        _emitGlint(k, appear);
      }
    } else {
      var anyLive = false;
      for (var c = 0; c < _chunkBusy.length; c++) {
        if (_chunkBusy[c] != 0 || _chunkFlow[c] != 0) {
          anyLive = true;
          break;
        }
      }
      if (!anyLive) {
        _allPic ??= _record((c) => _drawRest(c, 0, _restEnd));
        canvas.drawPicture(_allPic!);
        debugPictures++;
      } else {
        for (var c = 0; c < _chunkFrom.length; c++) {
          final from = _chunkFrom[c], to = _chunkTo[c];
          if (to <= from) continue;
          if (_chunkBusy[c] != 0 || _chunkFlow[c] != 0) {
            for (var k = from; k < to; k++) {
              _emitStill(k, 1);
            }
          } else {
            final pic = _chunkPics[c] ??= _record(
              (cv) => _drawRest(cv, from, to),
            );
            canvas.drawPicture(pic);
            debugPictures++;
          }
        }
      }
      for (var k = _restEnd; k < _n; k++) {
        _emitGlint(k, 1);
      }
    }
    debugSprites = _dots.n + _glow.n;
    _dots.draw(canvas, atlas, _over);
    _glow.draw(canvas, atlas, _add);
  }

  ui.Picture _record(void Function(Canvas c) draw) {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec));
    return rec.endRecording();
  }

  void _drawRest(Canvas c, int from, int to) {
    final b = _Batch(_solid);
    for (var k = from; k < to; k++) {
      b.add(_hx[k], _hy[k], _sz[k], _c[k]);
    }
    b.draw(c, _atlas!, _over);
  }

  // A still grain where the flow has it, lit when pushed fast.
  void _emitStill(int k, double appear) {
    final x = _hx[k] + _ox[k];
    var y = _hy[k] + _oy[k];
    var c = _c[k];
    if (appear < 1) {
      final a = _settle(k, appear);
      if (a <= 0) return;
      y -= (1 - a) * 18 * (0.3 + _ph[k]);
      c = _scaleAlpha(c, a);
    }
    final sp = _vx[k].abs() + _vy[k].abs();
    if (sp <= 30) {
      _dots.add(x, y, _sz[k], c);
      return;
    }
    final lit = math.min(1.0, (sp - 30) / 400);
    _dots.add(x, y, _sz[k] * (1 + 0.2 * lit), _mix(c, _c2[k], 0.8 * lit));
    if (lit > 0.45) {
      _glow.add(x, y, _sz[k] * 3.4, _scaleAlpha(_c2[k], 0.2 * lit));
    }
  }

  static const double _polishPeriod = 2.6;

  // How lit a glinting grain is now, 0..1, and the colour it peaks at.
  (double, int) _glintOf(int k) {
    switch (_role[k]) {
      case _polish:
        // The polish: one bright band wiped across the gold, again and again.
        final sweep = (_t / _polishPeriod) % 1.0 * 1.5 - 0.25;
        final d = (_aux[k] - sweep) / 0.05;
        return (d.abs() > 3 ? 0.0 : math.exp(-d * d), _c2[k]);
      case _turn:
        final s = _fsin(_t * (0.8 + _ph[k]) + _ph[k] * _tau * 5);
        return (
          s > 0.55 ? (s - 0.55) / 0.45 : 0.0,
          _prismAt(_aux[k] + _t * 0.6),
        );
      default:
        final s = _fsin(_t * (0.5 + 0.8 * _ph[k]) + _ph[k] * _tau * 7);
        return (s > 0.72 ? (s - 0.72) / 0.28 : 0.0, _c2[k]);
    }
  }

  void _emitGlint(int k, double appear) {
    final (g, peak) = _glintOf(k);
    if (g < 0.03) {
      _emitStill(k, appear);
      return;
    }
    final x = _hx[k] + _ox[k];
    var y = _hy[k] + _oy[k];
    var a = 1.0;
    if (appear < 1) {
      a = _settle(k, appear);
      if (a <= 0) return;
      y -= (1 - a) * 18 * (0.3 + _ph[k]);
    }
    _dots.add(
      x,
      y,
      _sz[k] * (1 + 0.4 * g),
      _scaleAlpha(_mix(_c[k], peak, g), a),
    );
    _glow.add(x, y, 3 + 7 * g, _scaleAlpha(peak, 0.32 * g * a));
  }

  void _emitLoose(double appear) {
    final w = _size.width, h = _size.height;
    for (var k = 0; k < _n; k++) {
      final x = _hx[k];
      var y = _hy[k];
      if (x < -6 || y < -6 || x > w + 6 || y > h + 6) continue;
      var a = 1.0;
      if (appear < 1) {
        a = _settle(k, appear);
        if (a <= 0) continue;
        y -= (1 - a) * 18 * (0.3 + _ph[k]);
      }
      // Lit by how hard it is pushed off its turn.
      final lit = ((_push[k] - 40) / 400).clamp(0.0, 1.0);
      var c = _c[k];
      if (lit > 0) c = _mix(c, _c2[k], 0.8 * lit);
      if (a < 1) c = _scaleAlpha(c, a);
      _dots.add(x, y, _sz[k], c);
      if (_role[k] != _still) {
        // The violet ones (and prismatic's turning ones) shimmer as they go.
        final s = 0.5 + 0.5 * _fsin(_t * (1.1 + _ph[k]) + _ph[k] * _tau * 3);
        final glow = _role[k] == _turn ? _prismAt(_aux[k] + _t * 0.6) : _c2[k];
        _glow.add(x, y, _sz[k] * 3.6, _scaleAlpha(glow, (0.04 + 0.12 * s) * a));
      } else if (lit > 0.45) {
        _glow.add(x, y, _sz[k] * 3.4, _scaleAlpha(_c2[k], 0.2 * lit * a));
      }
    }
  }
}

// ── Sprites ───────────────────────────────────────────────────────────────

const double _solidCell = 16, _softCell = 32;
const Rect _solid = Rect.fromLTWH(0, 0, _solidCell, _solidCell);
const Rect _soft = Rect.fromLTWH(_solidCell, 0, _softCell, _softCell);

/// A grain and a soft light.
ui.Image _buildAtlas() {
  final rec = ui.PictureRecorder();
  final c = Canvas(rec);
  const white = Color(0xFFFFFFFF);
  const sc = Offset(_solidCell / 2, _solidCell / 2);
  c.drawCircle(
    sc,
    _solidCell / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        sc,
        _solidCell / 2,
        [
          white,
          white,
          white.withValues(alpha: 0.6),
          white.withValues(alpha: 0),
        ],
        const [0, 0.55, 0.8, 1],
      ),
  );
  const gc = Offset(_solidCell + _softCell / 2, _softCell / 2);
  c.drawCircle(
    gc,
    _softCell / 2,
    Paint()
      ..shader = ui.Gradient.radial(
        gc,
        _softCell / 2,
        [
          white,
          white.withValues(alpha: 0.55),
          white.withValues(alpha: 0.18),
          white.withValues(alpha: 0.05),
          white.withValues(alpha: 0),
        ],
        const [0, 0.18, 0.42, 0.7, 1],
      ),
  );
  return rec.endRecording().toImageSync(
    (_solidCell + _softCell).toInt(),
    _softCell.toInt(),
  );
}

/// Sprites of one kind, each its own colour, size and place, in one call.
class _Batch {
  _Batch(this._src);

  final Rect _src;
  Float32List _xf = Float32List(0), _rects = Float32List(0);
  Int32List _colors = Int32List(0);
  int n = 0;

  void clear() => n = 0;

  /// Centred on (x, y), [size] across.
  void add(double x, double y, double size, int argb) {
    if ((argb >>> 24) < 3 || size <= 0) return;
    if (n >= _colors.length) _grow();
    final cell = _src.width;
    final s = size / cell;
    final i = n * 4;
    _xf[i] = s;
    _xf[i + 1] = 0;
    _xf[i + 2] = x - s * cell / 2;
    _xf[i + 3] = y - s * _src.height / 2;
    _colors[n++] = argb;
  }

  void _grow() {
    final cap = math.max(1024, _colors.length * 2);
    _xf = Float32List(cap * 4)..setAll(0, _xf);
    final rects = Float32List(cap * 4)..setAll(0, _rects);
    for (var i = _colors.length; i < cap; i++) {
      rects[i * 4] = _src.left;
      rects[i * 4 + 1] = _src.top;
      rects[i * 4 + 2] = _src.right;
      rects[i * 4 + 3] = _src.bottom;
    }
    _rects = rects;
    _colors = Int32List(cap)..setAll(0, _colors);
  }

  void draw(Canvas c, ui.Image atlas, Paint paint) {
    if (n == 0) return;
    c.drawRawAtlas(
      atlas,
      Float32List.sublistView(_xf, 0, n * 4),
      Float32List.sublistView(_rects, 0, n * 4),
      Int32List.sublistView(_colors, 0, n),
      BlendMode.modulate,
      null,
      paint,
    );
  }
}

// ── On screen ─────────────────────────────────────────────────────────────

/// Draws [field], laying it out to the canvas it is given.
class HatchSandPainter extends CustomPainter {
  HatchSandPainter(this.field, {required Listenable repaint})
    : super(repaint: repaint);

  final HatchSandField field;

  @override
  void paint(Canvas canvas, Size size) {
    field.layout(size);
    field.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant HatchSandPainter old) => old.field != field;
}

/// Stirs [field] with every finger drawn over [child], and pushes it out
/// where one is lifted without having moved. A [Listener], not a gesture, so
/// it takes nothing from the buttons on top of it.
class HatchSandStir extends StatefulWidget {
  const HatchSandStir({super.key, required this.field, required this.child});

  final HatchSandField field;
  final Widget child;

  @override
  State<HatchSandStir> createState() => _HatchSandStirState();
}

class _HatchSandStirState extends State<HatchSandStir> {
  final Map<int, (Duration, double)> _down = {};

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) => _down[e.pointer] = (e.timeStamp, 0),
    onPointerMove: (e) {
      final was = _down[e.pointer];
      final dt = was == null
          ? 1 / 60
          : ((e.timeStamp - was.$1).inMicroseconds / 1e6).clamp(1 / 240, 0.1);
      _down[e.pointer] = (e.timeStamp, (was?.$2 ?? 0) + e.delta.distance);
      widget.field.stir(e.localPosition, e.delta, dt);
    },
    onPointerUp: (e) {
      final was = _down.remove(e.pointer);
      if (was != null && was.$2 < 8) widget.field.ripple(e.localPosition);
    },
    onPointerCancel: (e) => _down.remove(e.pointer),
    child: widget.child,
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────

Float32List _permF(Float32List a, List<int> order) {
  final out = Float32List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Int32List _permI(Int32List a, List<int> order) {
  final out = Int32List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Uint8List _permB(Uint8List a, List<int> order) {
  final out = Uint8List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

/// [c] darkened to [v] of its brightness, at alpha [a].
int _shade(Color c, double v, double a) => _argb(a, c.r * v, c.g * v, c.b * v);

/// The rainbow at hue [h] (0..6, wrapping), blended between its bands.
int _prismAt(double h) {
  final w = h - (h / 6).floorToDouble() * 6;
  final i = w.floor() % 6;
  return _mix(_prism[i], _prism[(i + 1) % 6], w - w.floorToDouble());
}

int _scaleAlpha(int argb, double t) =>
    (((argb >>> 24) * t).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF);

@pragma('vm:prefer-inline')
int _byte(double v) => v <= 0 ? 0 : (v >= 1 ? 255 : (v * 255).toInt());

@pragma('vm:prefer-inline')
int _argb(double a, double r, double g, double b) =>
    (_byte(a) << 24) | (_byte(r) << 16) | (_byte(g) << 8) | _byte(b);

int _mix(int a, int b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  int ch(int s) =>
      (((a >> s) & 0xFF) + ((((b >> s) & 0xFF) - ((a >> s) & 0xFF)) * t))
          .round()
          .clamp(0, 255);
  return (ch(24) << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0);
}

final Float32List _sinTable = Float32List.fromList([
  for (var i = 0; i < 1024; i++) math.sin(i / 1024 * _tau),
]);

double _fsin(double x) => _sinTable[(x * (1024 / _tau)).floor() & 1023];

double _smooth01(double x) {
  final c = x < 0 ? 0.0 : (x > 1 ? 1.0 : x);
  return c * c * (3 - 2 * c);
}

double _smoothstep(double a, double b, double x) =>
    _smooth01((x - a) / (b - a));

double _lattice(int x, int y, int seed) {
  var h = (x * 0x27d4eb2d) ^ (y * 0x165667b1) ^ (seed * 0x5bd1e995);
  h = (h ^ (h >> 15)) * 0x2c1b3c6d;
  h = (h ^ (h >> 12)) * 0x297a2d39;
  h ^= h >> 15;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}

double _noise(double x, double y, int seed) {
  final xi = x.floor(), yi = y.floor();
  final fx = _smooth01(x - xi), fy = _smooth01(y - yi);
  final a = _lattice(xi, yi, seed), b = _lattice(xi + 1, yi, seed);
  final c = _lattice(xi, yi + 1, seed), d = _lattice(xi + 1, yi + 1, seed);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

double _fbm(double x, double y, int seed) {
  var sum = 0.0, amp = 0.5, norm = 0.0, f = 1.0;
  for (var o = 0; o < 3; o++) {
    sum += amp * _noise(x * f, y * f, seed + o * 31);
    norm += amp;
    amp *= 0.5;
    f *= 2.03;
  }
  return sum / norm;
}
