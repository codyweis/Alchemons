// lib/games/wilderness/field/sand_floor.dart
//
// LIVING SANDS' FLOOR. A tile of fine particles on the dark, seamless end
// to end, in the one to five colors the player picks, lying as they
// choose: poured together in veins, laid in layers, in broad drifts, or
// mixed grain by grain. Each grain is a little lighter or darker than the
// next, and a dust of the shimmer's color lies through them, a few of it
// catching the light now and then. Between the grains is the dark: where
// they are moved off it, it shows.
//
// A finger drawn through it does as the player chooses. The grains are
// carried along and aside and spring back, as the extraction's sand and the
// map's do (a tap pushes them out). Or they are ploughed out of the way and
// stay there — grooves down to the dark, ridges, craters — until smoothed.
// Or they mix: the grains under the finger are swirled along with it and
// those round it flow in behind, as a stylus drawn through marbling, so the
// colors are drawn through each other and nothing is dug (a tap twists
// them).
//
// Cheap at rest: one picture of the still grains, and the glints. A stir
// draws grain by grain only the squares it moves. New colors or shimmer
// dress the grains where they lie (a few ms); density and grain size only
// draw the picture again; only a new pattern reads the floor again. No
// blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Canvas, Color, Offset, Paint, Rect, Size;

import 'package:alchemons/models/home_sand.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

const double _tau = math.pi * 2;

// What a grain is: sand, or one of the few that can glint.
const int _sand = 0, _glint = 1;

class SandFloor {
  SandFloor(HomeSandStyle style, {this.reduced = false}) : _style = style;

  /// Fewer grains, for the performance setting.
  final bool reduced;

  HomeSandStyle _style;

  /// The style last dressed into the grains; null before the first.
  HomeSandStyle? _dressed;

  HomeSandStyle get style => _style;

  /// Takes effect from the next [step] or [paint]: only what changed is
  /// done again (see the file's head).
  set style(HomeSandStyle style) {
    if (style == _style) return;
    final wasStaying = _style.stays;
    _style = style;
    if (style.motion != SandMotion.mixes) _twists.clear();
    // Sand that stayed where it was pushed goes back to its lie when it is
    // told to spring back.
    if (wasStaying && !style.stays) smooth();
  }

  Size _size = Size.zero;
  double _t = 0;

  /// Grains handed to the canvas one by one last frame (pictures aside).
  int debugSprites = 0;

  /// Pictures drawn last frame.
  int debugPictures = 0;

  void layout(Size size) {
    if (size.isEmpty || size == _size) return;
    _size = size;
    _buildGrid();
    _compose();
    _readPattern();
    _sortForRest();
    _fieldInit();
    _dressed = null;
  }

  // ── The lie of the floor, read every few px ─────────────────────────────

  // Points across (one more past the right edge, wrapping, so the floor
  // reads on round the seam) and down.
  int _gw = 0, _gh = 0;
  double _gsx = 1, _gsy = 1;
  Float32List _gTone = Float32List(0), _gU = Float32List(0);
  SandPattern? _read;

  void _buildGrid() {
    final w = _size.width, h = _size.height;
    // About every 3 px.
    final s = math.max(3.0, math.sqrt(w * h / 56000));
    final cols = math.max(2, (w / s).round());
    final rows = math.max(2, (h / s).round());
    _gsx = w / cols;
    _gsy = h / rows;
    _gw = cols + 2;
    _gh = rows + 1;
    final v = _gw * _gh;
    _gTone = Float32List(v);
    _gU = Float32List(v);
    for (var j = 0; j < _gh; j++) {
      for (var i = 0; i < _gw; i++) {
        final k = j * _gw + i;
        _gTone[k] = i >= cols
            ? _gTone[j * _gw + (i - cols)]
            : _toneAt(i * _gsx, j * _gsy);
      }
    }
  }

  /// Broad light and shade over the floor, -1..1.
  double _toneAt(double x, double y) => (_wf(x, y, 420, 53) - 0.5) * 2.4;

  /// Where (x, y) lies in [pattern] before it is split into sands: a share
  /// of the floor, 0..1, for every pattern but the layers (which are a
  /// height, 0..1 down the floor, warped).
  double _patternAt(SandPattern pattern, double x, double y) {
    switch (pattern) {
      case SandPattern.marbled:
        final qx = _wf(x, y, 240, 61), qy = _wf(x, y, 240, 67);
        final wx = x + 220 * (qx - 0.5), wy = y + 220 * (qy - 0.5);
        final rx = _wf(wx, wy, 150, 71), ry = _wf(wx, wy, 150, 73);
        return _wf(wx + 130 * (rx - 0.5), wy + 130 * (ry - 0.5), 190, 79);
      case SandPattern.layered:
        final h = _size.height;
        return (y +
                0.28 * h * (_wf(x, y, 300, 83) - 0.5) +
                0.08 * h * (_wf(x, y, 80, 89) - 0.5)) /
            h;
      case SandPattern.drifts:
        return _wf(x, y, 330, 97);
      case SandPattern.mixed:
        return 0;
    }
  }

  /// Reads the floor in the style's pattern, onto the grid and the grains.
  void _readPattern() {
    final pattern = _style.pattern;
    _read = pattern;
    final cols = _gw - 2;
    for (var j = 0; j < _gh; j++) {
      for (var i = 0; i <= cols; i++) {
        final k = j * _gw + i;
        _gU[k] = i == cols
            ? _gU[j * _gw]
            : _patternAt(pattern, i * _gsx, j * _gsy);
      }
      _gU[j * _gw + cols + 1] = _gU[j * _gw + 1];
    }
    // Shares of the floor, evened out, so each sand lies over as much of it
    // as the others.
    if (pattern == SandPattern.marbled || pattern == SandPattern.drifts) {
      final sorted = Float32List.fromList(_gU)..sort();
      for (var k = 0; k < _gU.length; k++) {
        _gU[k] = _rank(sorted, _gU[k]);
      }
    }
    for (var k = 0; k < _n; k++) {
      _u[k] = pattern == SandPattern.mixed
          ? _ph[k]
          : _gridAt(_gU, _ix[k], _iy[k]);
    }
  }

  static double _rank(Float32List sorted, double v) {
    var lo = 0, hi = sorted.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (sorted[m] < v) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo / sorted.length;
  }

  /// [grid] at (x, y), between its vertices.
  double _gridAt(Float32List grid, double x, double y) {
    final fx = (x / _gsx).clamp(0.0, _gw - 1.001);
    final fy = (y / _gsy).clamp(0.0, _gh - 1.001);
    final i = fx.floor(), j = fy.floor();
    final tx = fx - i, ty = fy - j;
    final k = j * _gw + i;
    final a = grid[k],
        b = grid[k + 1],
        c = grid[k + _gw],
        d = grid[k + _gw + 1];
    return a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty;
  }

  /// [_fbmWrap] at (x, y) in px with features [scale] px across, seamless
  /// from the tile's right edge round to its left.
  double _wf(double x, double y, double scale, int seed) {
    final cells = math.max(1, (_size.width / scale).round());
    return _fbmWrap(x / _size.width * cells, y / scale, seed, cells);
  }

  // ── Grains ──────────────────────────────────────────────────────────────

  /// The most a floor holds, however big the screen: a big screen gets
  /// fewer grains for its size, not more of them.
  static const int _cap = 60000;

  int _n = 0;
  // Home, offset from it, velocity; where it first lay.
  Float32List _hx = Float32List(0), _hy = Float32List(0);
  Float32List _ox = Float32List(0), _oy = Float32List(0);
  Float32List _vx = Float32List(0), _vy = Float32List(0);
  Float32List _ix = Float32List(0), _iy = Float32List(0);
  // Size; whether it lies at a density (drawn below it); a die for what it
  // is besides sand; its own light and shade, and the floor's there; where
  // it lies in the pattern, and how far over a sand's edge it may stray; a
  // phase.
  Float32List _sz = Float32List(0), _keep = Float32List(0);
  Float32List _die = Float32List(0), _jit = Float32List(0);
  Float32List _tone = Float32List(0);
  Float32List _u = Float32List(0), _dith = Float32List(0);
  Float32List _ph = Float32List(0);
  // How heaped up it lies, pushed into a ridge (sand that stays), 0..1:
  // it catches more of the light.
  Float32List _heap = Float32List(0);
  // At rest, and lit (pushed fast; a glint's peak).
  Int32List _c = Int32List(0), _c2 = Int32List(0);
  Uint8List _role = Uint8List(0), _busy = Uint8List(0);

  // Grains [0, _restEnd) are sand, sorted by square; the rest can glint and
  // are drawn every frame.
  int _restEnd = 0;

  // Sand ploughed since the squares were last sorted, which may have been
  // carried out of its square (in front of a finger): a plough looks at
  // these wherever they are.
  Int32List _strays = Int32List(0);
  int _strayN = 0;
  Uint8List _stray = Uint8List(0);

  @visibleForTesting
  int get grainCount => _n;

  /// Grains drawn at the style's density.
  @visibleForTesting
  int get drawnCount {
    final keep = _keepBelow;
    var n = 0;
    for (var k = 0; k < _n; k++) {
      if (_keep[k] < keep) n++;
    }
    return n;
  }

  @visibleForTesting
  Offset debugGrainAt(int i) => Offset(_hx[i] + _ox[i], _hy[i] + _oy[i]);

  @visibleForTesting
  Offset debugFirstLieOf(int i) => Offset(_ix[i], _iy[i]);

  @visibleForTesting
  int debugColorOf(int i) => _c[i];

  /// Whether every grain lies still.
  @visibleForTesting
  bool get debugAtRest => !_fieldOn && !_chunkBusy.contains(1);

  /// Which of the style's sands grain [i] is, as last dressed.
  @visibleForTesting
  int debugSandOf(int i) => _sandOf(_u[i], _dith[i], _style.count);

  /// Where (x, y) lies in [pattern], before it is split into sands.
  @visibleForTesting
  double debugPatternAt(SandPattern pattern, double x, double y) =>
      _patternAt(pattern, x, y);

  void _compose() {
    final w = _size.width, h = _size.height;
    final area = w * h;
    final most = math.min(_cap * (reduced ? 0.6 : 1.0), area / 6.5);
    // One grain to a cell, anywhere in it: even, as packed sand is, never
    // the clumps and holes of grains thrown down at random.
    final s = math.sqrt(area / most);
    final cols = math.max(1, (w / s).round());
    final rows = math.max(1, (h / s).round());
    final n = cols * rows;
    final cx = w / cols, cy = h / rows;
    _hx = Float32List(n);
    _hy = Float32List(n);
    _ix = Float32List(n);
    _iy = Float32List(n);
    _sz = Float32List(n);
    _keep = Float32List(n);
    _die = Float32List(n);
    _jit = Float32List(n);
    _tone = Float32List(n);
    _u = Float32List(n);
    _dith = Float32List(n);
    _ph = Float32List(n);
    _heap = Float32List(n);
    _c = Int32List(n);
    _c2 = Int32List(n);
    _role = Uint8List(n);
    final r = math.Random(29);
    var i = 0;
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final x = (col + r.nextDouble()) * cx;
        final y = (row + r.nextDouble()) * cy;
        _hx[i] = _ix[i] = x;
        _hy[i] = _iy[i] = y;
        // Most fine, a few coarse.
        final big = r.nextDouble();
        _sz[i] = 1.3 + 1.1 * big * big;
        _keep[i] = r.nextDouble();
        _die[i] = r.nextDouble();
        _jit[i] = r.nextDouble() * 2 - 1;
        _dith[i] = r.nextDouble() * 2 - 1;
        _ph[i] = r.nextDouble();
        _tone[i] = _gridAt(_gTone, x, y);
        // A few can catch the light.
        _role[i] = _die[i] < _glintShare ? _glint : _sand;
        i++;
      }
    }
    _n = n;
    _ox = Float32List(n);
    _oy = Float32List(n);
    _vx = Float32List(n);
    _vy = Float32List(n);
    _busy = Uint8List(n);
    _strays = Int32List(_maxStrays + 64);
  }

  /// Ploughed sand held apart before the squares are sorted again.
  static const int _maxStrays = 6000;

  /// The share of grains that can glint.
  static const double _glintShare = 0.015;

  /// Grains with [_keep] under this are drawn.
  double get _keepBelow => 0.3 + 0.7 * _style.density;

  /// How big a grain is drawn, against its own size.
  double get _grainScale => 0.7 + 1.1 * _style.grain;

  // ── Dressing ────────────────────────────────────────────────────────────

  // Each sand's colors from deep shadow to pale light, and the shimmer's.
  static const int _levels = 32;
  List<Int32List> _ramps = const [];
  Int32List _shimmerRamp = Int32List(0);

  static Int32List _ramp(Color c) {
    final deep = Color.lerp(const Color(0xFF07060A), c, 0.2)!;
    final pale = Color.lerp(c, const Color(0xFFFFF6EA), 0.7)!;
    return Int32List.fromList([
      for (var q = 0; q < _levels; q++)
        () {
          final l = _levelOf(q);
          return (l <= 1
                  ? Color.lerp(deep, c, (l - 0.25) / 0.75)!
                  : Color.lerp(c, pale, (l - 1) / 0.65)!)
              .toARGB32();
        }(),
    ]);
  }

  static double _levelOf(int q) => 0.25 + 1.4 * q / (_levels - 1);

  static int _q(double level) =>
      ((level - 0.25) / 1.4 * (_levels - 1)).round().clamp(0, _levels - 1);

  /// Which sand [u] (with [dith] of straying) lies in, of [count].
  int _sandOf(double u, double dith, int count) {
    if (count == 1) return 0;
    switch (_style.pattern) {
      case SandPattern.marbled:
        // Two sands: veins of each through the other.
        final reps = count == 2 ? 3 : 2;
        return _band(u * count * reps + 0.2 * dith) % count;
      case SandPattern.layered:
        return _band(u * count * 2 + 0.12 * dith) % count;
      case SandPattern.drifts:
        return (u * count + 0.2 * dith).floor().clamp(0, count - 1);
      case SandPattern.mixed:
        return (u * count).floor().clamp(0, count - 1);
    }
  }

  /// Bands of sand as poured, some thick and some thin: where their edges
  /// fall, from [_bandFrom] on, each about one wide.
  static final Float32List _edges = () {
    final r = math.Random(31);
    final widths = [for (var i = 0; i < 96; i++) 0.4 + 1.2 * r.nextDouble()];
    final mean = widths.reduce((a, b) => a + b) / widths.length;
    var at = _bandFrom.toDouble();
    return Float32List.fromList([for (final w in widths) at += w / mean]);
  }();
  static const int _bandFrom = -24;

  /// The band [b] (about one to a unit) lies in.
  static int _band(double b) {
    var lo = 0, hi = _edges.length;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (_edges[m] <= b) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo - _bandFrom;
  }

  /// Grain [k]'s colors, at rest and lit, in the style as it is now.
  void _dressGrain(int k) {
    final st = _style;
    final ramp = _ramps[_sandOf(_u[k], _dith[k], st.count)];
    var level = 0.8 + 0.2 * _jit[k] + 0.08 * _tone[k] + 0.42 * _heap[k];
    final die = _die[k];
    // A few of other stuff in it, darker and paler than the sand.
    if (die > 0.95) level *= die > 0.975 ? 1.32 : 0.62;
    _c[k] = ramp[_q(level)];
    _c2[k] = ramp[_q(1.3)];
    if (_role[k] == _glint) {
      _c2[k] = _shimmerRamp[_levels - 1];
    } else if (die < _glintShare + 0.05 * st.sparkle) {
      // A dust of the shimmer through it.
      _c[k] = _shimmerRamp[_q(level + 0.08)];
      _c2[k] = _shimmerRamp[_levels - 1];
    }
  }

  /// Dresses the grains in the style as it is now.
  void _dress() {
    final st = _style;
    if (_read != st.pattern) _readPattern();
    final was = _dressed;
    _dressed = st;
    // Only the density, the grain or how it moves: the same colors.
    if (was != null &&
        st.copyWith(
              density: was.density,
              grain: was.grain,
              motion: was.motion,
            ) ==
            was) {
      _dropPictures();
      return;
    }
    _ramps = [for (final c in st.sands) _ramp(c)];
    _shimmerRamp = _ramp(st.shimmer);
    for (var k = 0; k < _n; k++) {
      _dressGrain(k);
    }
    _dropPictures();
  }

  // ── Squares (for the pictures) ──────────────────────────────────────────

  static const double _cs = 48;
  int _cw = 0, _ch = 0;
  double _csx = _cs;
  Int32List _chunkFrom = Int32List(0), _chunkTo = Int32List(0);
  Uint8List _chunkFlow = Uint8List(0), _chunkBusy = Uint8List(0);
  List<ui.Picture?> _chunkPics = const [];
  ui.Picture? _allPic;

  int _chunkAt(double x, double y) {
    final cx = (x / _csx).floor() % _cw;
    final cy = (y / _cs).floor().clamp(0, _ch - 1);
    return cy * _cw + cx;
  }

  /// Sand first, grouped by square; then the grains that can glint.
  void _sortForRest() {
    _cw = math.max(1, (_size.width / _cs).round());
    _csx = _size.width / _cw;
    _ch = (_size.height / _cs).ceil() + 1;
    final chunks = _cw * _ch;
    _chunkFrom = Int32List(chunks);
    _chunkTo = Int32List(chunks);
    _chunkFlow = Uint8List(chunks);
    _chunkBusy = Uint8List(chunks);
    _rebin();
  }

  /// Sorts the grains by the square their home is in (a counting sort: a
  /// few ms, after sand that stays has been pushed), and lets the squares'
  /// pictures go.
  void _rebin() {
    final chunks = _cw * _ch;
    final key = Int32List(_n);
    final count = Int32List(chunks + 2);
    for (var i = 0; i < _n; i++) {
      final k = _role[i] != _sand ? chunks : _chunkAt(_hx[i], _hy[i]);
      key[i] = k;
      count[k + 1]++;
    }
    for (var c = 0; c <= chunks; c++) {
      count[c + 1] += count[c];
    }
    for (var c = 0; c < chunks; c++) {
      _chunkFrom[c] = count[c];
      _chunkTo[c] = count[c + 1];
    }
    _restEnd = count[chunks];
    final order = Int32List(_n);
    final at = Int32List.fromList(count);
    for (var i = 0; i < _n; i++) {
      order[at[key[i]]++] = i;
    }
    _hx = _permF(_hx, order);
    _hy = _permF(_hy, order);
    _ox = _permF(_ox, order);
    _oy = _permF(_oy, order);
    _vx = _permF(_vx, order);
    _vy = _permF(_vy, order);
    _ix = _permF(_ix, order);
    _iy = _permF(_iy, order);
    _sz = _permF(_sz, order);
    _keep = _permF(_keep, order);
    _die = _permF(_die, order);
    _jit = _permF(_jit, order);
    _tone = _permF(_tone, order);
    _u = _permF(_u, order);
    _dith = _permF(_dith, order);
    _ph = _permF(_ph, order);
    _heap = _permF(_heap, order);
    _c = _permI(_c, order);
    _c2 = _permI(_c2, order);
    _role = _permB(_role, order);
    _busy = _permB(_busy, order);
    _stray = Uint8List(_n);
    _strayN = 0;
    // A square with a grain still moving in it keeps being stepped.
    _chunkBusy.fillRange(0, chunks, 0);
    for (var c = 0; c < chunks; c++) {
      for (var k = _chunkFrom[c]; k < _chunkTo[c]; k++) {
        if (_busy[k] != 0) {
          _chunkBusy[c] = 1;
          break;
        }
      }
    }
    _dropPictures();
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

  // ── The flow a finger leaves ────────────────────────────────────────────

  // Seamless across: a cell's right-hand neighbour in the last column is
  // the first.
  static const double _cell = 12;
  int _fieldW = 0, _fieldH = 0;
  double _cellX = _cell;
  Float32List _fu = Float32List(0), _fv = Float32List(0), _ft = Float32List(0);
  bool _fieldOn = false;

  void _fieldInit() {
    _fieldW = math.max(2, (_size.width / _cell).round());
    _cellX = _size.width / _fieldW;
    _fieldH = (_size.height / _cell).ceil() + 2;
    _fu = Float32List(_fieldW * _fieldH);
    _fv = Float32List(_fieldW * _fieldH);
    _ft = Float32List(_fieldW * _fieldH);
    _fieldOn = false;
  }

  /// How far round a finger sand that springs back feels it (px).
  static const double _reach = 30;

  /// How wide a furrow a finger leaves in sand that stays: its half (px).
  static const double _furrow = 12;

  /// A finger moved by [moved] (px, over [dt] s) to [at].
  ///
  /// Sand that springs back is carried along with it, and a little aside,
  /// and flows back. Sand that stays is ploughed out of its way — a furrow,
  /// the sand heaped along its edges and in front of it. Sand that mixes is
  /// swirled along with it.
  void stir(Offset at, Offset moved, double dt) {
    if (_fieldW == 0) return;
    if (_style.motion == SandMotion.mixes) {
      // A step at a time, each short against the swirl.
      final len = moved.distance;
      if (len < 1e-3) return;
      final steps = math.max(1, (len / (_swirlR * 0.25)).ceil());
      for (var i = steps - 1; i >= 0; i--) {
        _swirl(at - moved * (i / steps), moved / steps.toDouble());
      }
      return;
    }
    if (_style.stays) {
      // Swept the way it came a step at a time: a fast finger leaves no
      // gaps.
      final len = moved.distance;
      final dir = len > 1e-3 ? moved / len : const Offset(1, 0);
      final steps = math.max(1, (len / (_furrow * 0.5)).ceil());
      for (var i = steps - 1; i >= 0; i--) {
        _plough(at - moved * (i / steps), _furrow, dir);
      }
      return;
    }
    final s = 1 / math.max(dt, 1 / 240);
    final vx = (moved.dx * s).clamp(-1600.0, 1600.0);
    final vy = (moved.dy * s).clamp(-1600.0, 1600.0);
    final sp = math.sqrt(vx * vx + vy * vy);
    if (sp < 1) return;
    final ux = vx / sp, uy = vy / sp;
    _inject(at, _reach, (dx, dy, w) {
      // Out to whichever side of its path it lies.
      final side = dx * -uy + dy * ux >= 0 ? 1.0 : -1.0;
      return ((vx - uy * side * sp * 0.3) * w, (vy + ux * side * sp * 0.3) * w);
    }, blend: true);
  }

  /// A tap at [at]: the sand pushed out from it (sand that stays: a
  /// crater; sand that mixes: twisted round it).
  void ripple(Offset at) {
    if (_fieldW == 0) return;
    if (_style.motion == SandMotion.mixes) {
      _twists.add((at, _twistTurn));
      return;
    }
    if (_style.stays) {
      _plough(at, _furrow * 1.3, const Offset(1, 0));
      return;
    }
    const strength = 240.0;
    _inject(at, 44, (dx, dy, w) {
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      return (dx / l * strength * w, dy / l * strength * w);
    });
  }

  /// [visit] each grain that may lie within [r] of [at] — by where it is
  /// going, not where it is on its way — which says whether it gave the
  /// grain a new home. Grains given one are held apart as strays, and the
  /// pictures they were drawn in are let go: drawn again once they lie
  /// still, never as they lay before.
  void _eachNear(Offset at, double r, bool Function(int k) visit) {
    var any = false;
    // Those held apart before this, each visited once.
    final strays = _strayN;
    void changed(int k) {
      any = true;
      if (k < _restEnd && _stray[k] == 0 && _strayN < _strays.length) {
        _stray[k] = 1;
        _strays[_strayN++] = k;
      }
    }

    // The squares round it, and one more each way: a grain's square is
    // where it lay when they were last sorted.
    final cx0 = ((at.dx - r) / _csx).floor() - 1;
    final cx1 = ((at.dx + r) / _csx).floor() + 1;
    final cy0 = math.max(0, ((at.dy - r) / _cs).floor() - 1);
    final cy1 = math.min(_ch - 1, ((at.dy + r) / _cs).floor() + 1);
    for (var cy = cy0; cy <= cy1; cy++) {
      for (var cx = cx0; cx <= math.min(cx1, cx0 + _cw - 1); cx++) {
        final c = cy * _cw + cx % _cw;
        var hit = false;
        for (var k = _chunkFrom[c]; k < _chunkTo[c]; k++) {
          if (_stray[k] == 0 && visit(k)) {
            changed(k);
            hit = true;
          }
        }
        if (hit) _touchChunk(c);
      }
    }
    for (var k = _restEnd; k < _n; k++) {
      if (visit(k)) changed(k);
    }
    for (var i = 0; i < strays; i++) {
      final k = _strays[i];
      if (visit(k)) {
        any = true;
        _touchChunk(_chunkOfIndex(k));
      }
    }
    if (!any) return;
    _allPic?.dispose();
    _allPic = null;
    _moved = true;
    // Too many to keep looking through: sort them into their squares now.
    if (_strayN > _maxStrays) _rebin();
  }

  /// Square [c] drawn grain by grain until it lies still, and then drawn
  /// again.
  void _touchChunk(int c) {
    _chunkBusy[c] = 1;
    _chunkPics[c]?.dispose();
    _chunkPics[c] = null;
  }

  /// The square sand grain [k] (< [_restEnd]) was sorted into.
  int _chunkOfIndex(int k) {
    var lo = 0, hi = _chunkTo.length - 1;
    while (lo < hi) {
      final m = (lo + hi) >> 1;
      if (_chunkTo[m] <= k) {
        lo = m + 1;
      } else {
        hi = m;
      }
    }
    return lo;
  }

  /// Grain [k] given a new home at (hx, hy), drawn where it is and gliding
  /// there.
  void _rehome(int k, double hx, double hy) {
    final w = _size.width;
    hx -= (hx / w).floorToDouble() * w;
    hy = hy.clamp(0.0, _size.height);
    var ox = _hx[k] + _ox[k] - hx;
    // The short way round the seam.
    if (ox > w / 2) {
      ox -= w;
    } else if (ox < -w / 2) {
      ox += w;
    }
    _ox[k] = ox;
    _oy[k] = _hy[k] + _oy[k] - hy;
    _hx[k] = hx;
    _hy[k] = hy;
    _busy[k] = 1;
  }

  /// From (cx, cy) to grain [k]'s home, the short way round the seam.
  double _toX(int k, double cx) {
    final w = _size.width;
    final dx = _hx[k] - cx;
    return dx > w / 2 ? dx - w : (dx < -w / 2 ? dx + w : dx);
  }

  /// Every grain within [r] of [at] pushed out to just past its edge (one
  /// straight under it, out to a side of [dir]): it is given its new home
  /// there and glides to it.
  void _plough(Offset at, double r, Offset dir) {
    final r2 = r * r;
    _eachNear(at, r, (k) {
      // Judged by where it is going: one still gliding out of the last
      // step's way would be pushed back into the furrow.
      final dx = _toX(k, at.dx), dy = _hy[k] - at.dy;
      final d2 = dx * dx + dy * dy;
      // A few lie too deep to be moved, and are left in the furrow.
      if (d2 >= r2 || _jit[k] > 0.88) return false;
      final d = math.sqrt(d2);
      double nx, ny;
      if (d > 0.5) {
        nx = dx / d;
        ny = dy / d;
      } else {
        final side = _dith[k] >= 0 ? 1.0 : -1.0;
        nx = -dir.dy * side;
        ny = dir.dx * side;
      }
      // Most of it heaped right at the edge, thinning further out.
      final out = r + 1 + 8 * _ph[k] * _ph[k];
      _rehome(k, at.dx + nx * out, at.dy + ny * out);
      // Heaped up where it is pushed, in the light.
      _heap[k] = math.min(1.0, _heap[k] + 0.25);
      _dressGrain(k);
      return true;
    });
  }

  /// How far round a finger sand that mixes feels it (px), and how much of
  /// the finger's way the sand right under it goes with it.
  static const double _swirlR = 44, _swirlCarry = 0.8;

  /// The sand round [at] swirled as a stylus moved by [step] swirls
  /// marbling: carried along under it, out round its sides ahead of it and
  /// in behind it, a little drawn back beside it. The flow neither gathers
  /// nor spreads the sand (it is the turn of a stream function), so it
  /// mixes the sands without digging.
  void _swirl(Offset at, Offset step) {
    final len = step.distance;
    final ux = step.dx / len, uy = step.dy / len;
    const r2 = _swirlR * _swirlR, k4 = 4 / r2;
    final carry = len * _swirlCarry;
    // The flow at (dx, dy) from the finger, over this step.
    (double, double) flow(double dx, double dy) {
      final d2 = dx * dx + dy * dy;
      if (d2 >= r2) return (0.0, 0.0);
      // Along the finger's way, and across it.
      final a = dx * ux + dy * uy, b = dy * ux - dx * uy;
      final f = 1 - d2 / r2;
      final along = carry * f * (f - k4 * b * b);
      final across = carry * f * k4 * a * b;
      return (along * ux - across * uy, along * uy + across * ux);
    }

    // Taken from the middle of the step, not its start: a step taken
    // straight off its start gathers and spreads the sand a little each
    // time, and over a stroke that shows.
    (double, double) move(double dx, double dy) {
      final (hx, hy) = flow(dx, dy);
      return flow(dx + hx / 2, dy + hy / 2);
    }

    _eachNear(at, _swirlR, (k) {
      final dx = _toX(k, at.dx), dy = _hy[k] - at.dy;
      if (dx * dx + dy * dy >= r2) return false;
      final (mx, my) = move(dx, dy);
      _rehome(k, _hx[k] + mx, _hy[k] + my);
      return true;
    });
  }

  // Taps still twisting sand that mixes: where, and how far it has yet to
  // turn (radians).
  final List<(Offset, double)> _twists = [];

  /// How far round a tap sand that mixes is twisted (px), how far it turns
  /// at the middle, and how soon it slows (s).
  static const double _twistR = 44, _twistTurn = 3.0, _twistEase = 0.16;

  void _turnTwists(double dt) {
    // Quick at first, slowing to a stop.
    final share = 1 - math.exp(-dt / _twistEase);
    for (var i = _twists.length - 1; i >= 0; i--) {
      final (at, left) = _twists[i];
      final turn = left < 0.01 ? left : left * share;
      _twist(at, turn);
      if (left - turn <= 1e-4) {
        _twists.removeAt(i);
      } else {
        _twists[i] = (at, left - turn);
      }
    }
  }

  /// The sand round [at] turned about it by [turn] at the middle, less
  /// further out: a turn about a point by how far from it neither gathers
  /// nor spreads the sand.
  void _twist(Offset at, double turn) {
    const r2 = _twistR * _twistR;
    _eachNear(at, _twistR, (k) {
      final dx = _toX(k, at.dx), dy = _hy[k] - at.dy;
      final d2 = dx * dx + dy * dy;
      if (d2 >= r2) return false;
      final f = 1 - d2 / r2;
      final th = turn * f * f;
      final c = math.cos(th), s = math.sin(th);
      _rehome(k, at.dx + dx * c - dy * s, at.dy + dx * s + dy * c);
      return true;
    });
  }

  void _inject(
    Offset at,
    double reach,
    (double, double) Function(double dx, double dy, double w) push, {
    bool blend = false,
  }) {
    final g0x = ((at.dx - reach) / _cellX).floor();
    final g1x = ((at.dx + reach) / _cellX).ceil();
    final g0y = ((at.dy - reach) / _cell).floor().clamp(0, _fieldH - 1);
    final g1y = ((at.dy + reach) / _cell).ceil().clamp(0, _fieldH - 1);
    for (var gy = g0y; gy <= g1y; gy++) {
      for (var gx = g0x; gx <= g1x; gx++) {
        final dx = gx * _cellX - at.dx, dy = gy * _cell - at.dy;
        final q = (dx * dx + dy * dy) / (reach * reach);
        if (q >= 1) continue;
        final w = (1 - q) * (1 - q);
        final (pu, pv) = push(dx, dy, w);
        final i = gy * _fieldW + gx % _fieldW;
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
      g0x * _cellX - _cellX,
      g0y * _cell - _cell,
      g1x * _cellX + _cellX,
      g1y * _cell + _cell,
    );
  }

  void _markChunks(double x0, double y0, double x1, double y1) {
    final a = (x0 / _csx).floor(), b = (x1 / _csx).floor();
    final c = (y0 / _cs).floor().clamp(0, _ch - 1);
    final d = (y1 / _cs).floor().clamp(0, _ch - 1);
    final span = math.min(b - a, _cw - 1);
    for (var y = c; y <= d; y++) {
      for (var x = a; x <= a + span; x++) {
        _chunkFlow[y * _cw + x % _cw] = 1;
      }
    }
  }

  void _stepField(double dt) {
    _chunkFlow.fillRange(0, _chunkFlow.length, 0);
    if (!_fieldOn) return;
    final decay = math.exp(-dt / 0.3);
    final fw = _fieldW;
    var most = 0.0;
    for (final f in [_fu, _fv]) {
      final t = _ft;
      for (var gy = 0; gy < _fieldH; gy++) {
        final row = gy * fw;
        for (var gx = 0; gx < fw; gx++) {
          final i = row + gx;
          var s =
              f[i] * 4 +
              f[row + (gx == 0 ? fw - 1 : gx - 1)] +
              f[row + (gx == fw - 1 ? 0 : gx + 1)];
          var w = 6.0;
          if (gy > 0) {
            s += f[i - fw];
            w++;
          }
          if (gy < _fieldH - 1) {
            s += f[i + fw];
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
          final x = (i % fw) * _cellX, y = (i ~/ fw) * _cell;
          _markChunks(x - _cellX, y - _cell, x + _cellX, y + _cell);
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
    final fx = x / _cellX, fy = y / _cell;
    final gx = fx.floor(), gy = fy.floor();
    if (gy < 0 || gy >= _fieldH - 1) return;
    final tx = fx - gx, ty = fy - gy;
    final fw = _fieldW;
    final c0 = gx % fw, c1 = (gx + 1) % fw;
    final r0 = gy * fw, r1 = r0 + fw;
    final u0 = _fu[r0 + c0], u1 = _fu[r0 + c1];
    final u2 = _fu[r1 + c0], u3 = _fu[r1 + c1];
    _su = u0 + (u1 - u0) * tx + (u2 - u0) * ty + (u0 - u1 - u2 + u3) * tx * ty;
    final v0 = _fv[r0 + c0], v1 = _fv[r0 + c1];
    final v2 = _fv[r1 + c0], v3 = _fv[r1 + c1];
    _sv = v0 + (v1 - v0) * tx + (v2 - v0) * ty + (v0 - v1 - v2 + v3) * tx * ty;
  }

  // ── Stepping ────────────────────────────────────────────────────────────

  /// Sand that stayed was moved; its squares are sorted again once all of
  /// it lies still.
  bool _moved = false;

  /// Smoothing: every grain going back to where it first lay, even sand
  /// that stays.
  bool _smoothing = false;

  void step(double dt) {
    if (_n == 0 || dt <= 0) return;
    if (_dressed != _style) _dress();
    _t += dt;
    if (_twists.isNotEmpty) _turnTwists(dt);
    _stepField(dt);
    var busy = _twists.isNotEmpty;
    for (var c = 0; c < _chunkFrom.length; c++) {
      if (_chunkFlow[c] == 0 && _chunkBusy[c] == 0) continue;
      final b = _stepGrains(_chunkFrom[c], _chunkTo[c], dt);
      _chunkBusy[c] = b ? 1 : 0;
      busy |= b;
    }
    busy |= _stepGrains(_restEnd, _n, dt);
    if (!busy && !_fieldOn) {
      _smoothing = false;
      if (_moved) {
        _moved = false;
        _rebin();
      }
    }
  }

  /// Grains [from]..[to] pushed by the flow and pulled home — sand that
  /// stays, quickly, to the new home it was ploughed to; whether any is
  /// still moving.
  bool _stepGrains(int from, int to, double dt) {
    final stays = _style.stays && !_smoothing;
    final drag = stays ? 11.0 : 5.0, spring = stays ? 30.0 : 14.0;
    final on = _fieldOn;
    var moving = false;
    for (var k = from; k < to; k++) {
      if (!on && _busy[k] == 0) continue;
      var ox = _ox[k], oy = _oy[k], vx = _vx[k], vy = _vy[k];
      var fu = 0.0, fv = 0.0;
      if (on) {
        _sample(_hx[k] + ox, _hy[k] + oy);
        // Some grains go further than others: a furrow keeps a few, and
        // what is ploughed out lies in a ridge, not a line.
        final m = 0.85 + 0.15 * _dith[k];
        fu = _su * m;
        fv = _sv * m;
      }
      vx += (drag * (fu - vx) - spring * ox) * dt;
      vy += (drag * (fv - vy) - spring * oy) * dt;
      ox += vx * dt;
      oy += vy * dt;
      // Within a fraction of a pixel and barely moving: home (a jump too
      // small to see, and the square goes back to its picture sooner).
      if (fu.abs() < 1 &&
          fv.abs() < 1 &&
          ox.abs() < 0.15 &&
          oy.abs() < 0.15 &&
          vx.abs() < 1 &&
          vy.abs() < 1) {
        ox = oy = vx = vy = 0;
        _busy[k] = 0;
      } else {
        _busy[k] = 1;
        moving = true;
      }
      _ox[k] = ox;
      _oy[k] = oy;
      _vx[k] = vx;
      _vy[k] = vy;
    }
    return moving;
  }

  /// Every grain back to where it first lay, gliding there.
  void smooth() {
    if (_n == 0) return;
    final w = _size.width;
    for (var k = 0; k < _n; k++) {
      var ox = _hx[k] + _ox[k] - _ix[k];
      // The short way round the seam.
      if (ox > w / 2) ox -= w;
      if (ox < -w / 2) ox += w;
      final oy = _hy[k] + _oy[k] - _iy[k];
      _hx[k] = _ix[k];
      _hy[k] = _iy[k];
      if (_heap[k] > 0) {
        _heap[k] = 0;
        _dressGrain(k);
      }
      _ox[k] = ox;
      _oy[k] = oy;
      if (ox.abs() > 0.05 || oy.abs() > 0.05) _busy[k] = 1;
    }
    _twists.clear();
    _smoothing = true;
    _moved = false;
    _rebin();
  }

  // ── Drawing ─────────────────────────────────────────────────────────────

  static ui.Image? _atlas;
  static final Paint _over = Paint()..filterQuality = ui.FilterQuality.medium;
  static final Paint _add = Paint()
    ..filterQuality = ui.FilterQuality.medium
    ..blendMode = ui.BlendMode.plus;

  final _Batch _dots = _Batch(_solid);
  final _Batch _glow = _Batch(_soft);

  /// The grains, in the tile's own units, on whatever lies under them.
  void paint(Canvas canvas) {
    debugSprites = 0;
    debugPictures = 0;
    if (_size.isEmpty || _n == 0) return;
    if (_dressed != _style) _dress();
    final atlas = _atlas ??= _buildAtlas();
    _dots.clear();
    _glow.clear();
    final keep = _keepBelow, scale = _grainScale;
    var anyLive = false;
    for (var c = 0; c < _chunkBusy.length; c++) {
      if (_chunkBusy[c] != 0 || _chunkFlow[c] != 0) {
        anyLive = true;
        break;
      }
    }
    if (!anyLive) {
      _allPic ??= _record((c) => _drawRest(c, 0, _restEnd, keep, scale));
      canvas.drawPicture(_allPic!);
      debugPictures++;
    } else {
      for (var c = 0; c < _chunkFrom.length; c++) {
        final from = _chunkFrom[c], to = _chunkTo[c];
        if (to <= from) continue;
        if (_chunkBusy[c] != 0 || _chunkFlow[c] != 0) {
          for (var k = from; k < to; k++) {
            if (_keep[k] < keep) _emitSand(k, scale);
          }
        } else {
          final pic = _chunkPics[c] ??= _record(
            (cv) => _drawRest(cv, from, to, keep, scale),
          );
          canvas.drawPicture(pic);
          debugPictures++;
        }
      }
    }
    final sparkle = _style.sparkle;
    for (var k = _restEnd; k < _n; k++) {
      if (_keep[k] >= keep) continue;
      // How many of the grains that can glint do, by the shimmer's amount.
      if (_die[k] / _glintShare < sparkle) {
        _emitGlint(k, scale);
      } else {
        _emitSand(k, scale);
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

  void _drawRest(Canvas c, int from, int to, double keep, double scale) {
    final b = _Batch(_solid);
    for (var k = from; k < to; k++) {
      if (_keep[k] < keep) {
        b.add(_hx[k] + _ox[k], _hy[k] + _oy[k], _sz[k] * scale, _c[k]);
      }
    }
    b.draw(c, _atlas!, _over);
  }

  // A grain where the flow has it, lit when pushed fast.
  void _emitSand(int k, double scale) {
    final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k];
    final sp = _vx[k].abs() + _vy[k].abs();
    if (sp <= 30) {
      _dots.add(x, y, _sz[k] * scale, _c[k]);
      return;
    }
    final lit = math.min(1.0, (sp - 30) / 400);
    _dots.add(
      x,
      y,
      _sz[k] * scale * (1 + 0.2 * lit),
      _mix(_c[k], _c2[k], 0.8 * lit),
    );
    if (lit > 0.45) {
      _glow.add(x, y, _sz[k] * scale * 3.4, _scaleAlpha(_c2[k], 0.2 * lit));
    }
  }

  // A grain on a crest catching the light now and then, in the shimmer.
  void _emitGlint(int k, double scale) {
    final s = _fsin(_t * (0.4 + 0.7 * _ph[k]) + _ph[k] * _tau * 7);
    final g = s > 0.8 ? (s - 0.8) / 0.2 : 0.0;
    if (g < 0.03) {
      _emitSand(k, scale);
      return;
    }
    final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k];
    _dots.add(x, y, _sz[k] * scale * (1 + 0.3 * g), _mix(_c[k], _c2[k], g));
    _glow.add(x, y, 2 + 3.5 * g, _scaleAlpha(_c2[k], 0.22 * g));
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

/// Sprites of one kind, each its own color, size and place, in one call.
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
      ui.BlendMode.modulate,
      null,
      paint,
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

Float32List _permF(Float32List a, Int32List order) {
  final out = Float32List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Int32List _permI(Int32List a, Int32List order) {
  final out = Int32List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Uint8List _permB(Uint8List a, Int32List order) {
  final out = Uint8List(order.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

int _scaleAlpha(int argb, double t) =>
    (((argb >>> 24) * t).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF);

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

int _hash(int x, int y, int seed) {
  var h = (x * 0x27d4eb2d) ^ (y * 0x165667b1) ^ (seed * 0x5bd1e995);
  h = (h ^ (h >> 15)) * 0x2c1b3c6d;
  h = (h ^ (h >> 12)) * 0x297a2d39;
  return (h ^ (h >> 15)) & 0x3FF;
}

// Unit gradients round the circle, for the lattice to pick from.
final Float32List _gradX = Float32List.fromList([
  for (var i = 0; i < 1024; i++) math.cos(i / 1024 * _tau),
]);
final Float32List _gradY = Float32List.fromList([
  for (var i = 0; i < 1024; i++) math.sin(i / 1024 * _tau),
]);

/// Gradient noise, 0..1 about 0.5, repeating every [period] lattice cells
/// across: rounder than value noise, whose blobs come out square.
double _noiseWrap(double x, double y, int seed, int period) {
  final xi = x.floor(), yi = y.floor();
  final fx = x - xi, fy = y - yi;
  final x0 = xi % period, x1 = (xi + 1) % period;
  double dot(int gx, int gy, double dx, double dy) {
    final g = _hash(gx, gy, seed);
    return _gradX[g] * dx + _gradY[g] * dy;
  }

  final a = dot(x0, yi, fx, fy), b = dot(x1, yi, fx - 1, fy);
  final c = dot(x0, yi + 1, fx, fy - 1), d = dot(x1, yi + 1, fx - 1, fy - 1);
  final u = fx * fx * fx * (fx * (fx * 6 - 15) + 10);
  final v = fy * fy * fy * (fy * (fy * 6 - 15) + 10);
  final n = a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  return 0.5 + 0.72 * n;
}

/// Three octaves of [_noiseWrap], repeating every [period] cells across.
double _fbmWrap(double x, double y, int seed, int period) {
  var sum = 0.0, amp = 0.5, norm = 0.0;
  var f = 1;
  for (var o = 0; o < 3; o++) {
    sum += amp * _noiseWrap(x * f, y * f, seed + o * 31, period * f);
    norm += amp;
    amp *= 0.5;
    f *= 2;
  }
  return sum / norm;
}
