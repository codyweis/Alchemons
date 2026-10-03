// lib/widgets/background/faction_realm.dart
//
// THE FACTION'S REALM, IN GRAINS. The home background (and the faction
// picker's): the whole screen a fine sand of grains on near-black, gathered
// at the foot into the faction's own ground —
//
//   Volcanic  a basalt crust split by seams that breathe with heat, embers
//             lifting off them, now and then a far flash of lightning;
//   Oceanic   dark water under rain, its surface a line of grains that the
//             drops and the phone's tilt set rocking;
//   Earthen   strata of soil, mud and clay with crystal veins glinting,
//             dust rising off the top;
//   Verdant   no ground at all: banks of cloud and currents of wind that
//             carry green seeds across.
//
// A finger drawn through any of it stirs it like sand in water (the wild
// map's flow, the same constants), a tap pushes it out, and it settles back.
// Change the faction and the grains lift off and fly into the new realm.
//
// Cheap at rest: grains that hold still are drawn once into pictures, a
// whole-screen one while nothing is stirred and one per 48 px square while
// something is, and only the squares a finger has moved are drawn grain by
// grain. What breathes or rocks (seams, crystals, the waterline) and what
// flies (embers, rain, wind) is a few thousand sprites a frame. No blur.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/models/faction.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:sensors_plus/sensors_plus.dart';

const double _tau = math.pi * 2;

// What a grain does besides sit still.
const int _still = 0, _seam = 1, _twinkle = 2, _surface = 3;

// What a mover is.
const int _ember = 0, _drop = 1, _splash = 2, _mote = 3, _seed = 4;

/// The field: grains, the flow a finger leaves in them, and what flies.
class FactionRealmField {
  FactionRealmField({FactionId faction = FactionId.volcanic, bool ink = false})
    : _faction = faction,
      _ink = ink;

  FactionId _faction;
  FactionId get faction => _faction;

  /// A new faction: the grains fly from this realm into that one.
  set faction(FactionId f) {
    if (f == _faction) return;
    final was = _faction;
    _faction = f;
    if (_n > 0) _beginReform(was);
  }

  bool _ink;

  /// Drawn in ink, for a light page.
  set ink(bool v) {
    if (v == _ink) return;
    _ink = v;
    final c = _c, c2 = _c2;
    _c = _cOther;
    _c2 = _c2Other;
    _cOther = c;
    _c2Other = c2;
    _dropPictures();
  }

  /// The phone's tilt (x across, y along), each -1..1: the water leans.
  Offset tilt = Offset.zero;

  /// Grains handed to the canvas one by one last frame (pictures aside).
  int debugSprites = 0;

  /// Pictures drawn last frame.
  int debugPictures = 0;

  /// Whether the grains are flying between realms.
  bool get reforming => _reformT >= 0;

  Size _size = Size.zero;
  double _t = 0;
  final math.Random _rng = math.Random(7);

  // ── Grains ────────────────────────────────────────────────────────────

  int _n = 0;
  // Home, offset from it, velocity; size, phase, a per-role number.
  Float32List _hx = Float32List(0), _hy = Float32List(0);
  Float32List _ox = Float32List(0), _oy = Float32List(0);
  Float32List _vx = Float32List(0), _vy = Float32List(0);
  Float32List _sz = Float32List(0), _ph = Float32List(0);
  Float32List _aux = Float32List(0);
  Int32List _c = Int32List(0), _c2 = Int32List(0);
  // The grains' colours for the other page (ink while dark, and back).
  Int32List _cOther = Int32List(0), _c2Other = Int32List(0);
  Uint8List _role = Uint8List(0), _busy = Uint8List(0);

  // Grains [0, _restEnd) hold still and are sorted by square; the rest
  // breathe, twinkle or rock and are drawn every frame.
  int _restEnd = 0;

  // ── Squares (for the pictures) ────────────────────────────────────────

  static const double _cs = 48;
  int _cw = 0, _ch = 0;
  Int32List _chunkFrom = Int32List(0), _chunkTo = Int32List(0);
  Uint8List _chunkFlow = Uint8List(0), _chunkBusy = Uint8List(0);
  List<ui.Picture?> _chunkPics = const [];
  ui.Picture? _allPic;

  // ── The ground's shape, for movers ────────────────────────────────────

  // The top of the ground (or the waterline) every 6 px; empty for Verdant.
  Float32List _top = Float32List(0);
  static const double _col = 6;
  Int32List _seams = Int32List(0); // seam grains, for embers to rise from

  // The water's surface: a height per column and its speed.
  Float32List _wh = Float32List(0), _wv = Float32List(0);
  double _waterY = 0;

  // Lightning far off over the Volcano: seconds to the next, and how long
  // since the last.
  double _nextFlash = 6, _flashAge = 99;

  @visibleForTesting
  int get grainCount => _n;

  /// Grain [i]'s colour on the current page.
  @visibleForTesting
  int debugColourOf(int i) => _c[i];

  void layout(Size size) {
    if (size.isEmpty || size == _size) return;
    _size = size;
    final comp = _compose(_faction, _grainsFor(size), size, 11);
    _adopt(comp);
    _fieldW = (size.width / _cell).ceil() + 2;
    _fieldH = (size.height / _cell).ceil() + 2;
    _fu = Float32List(_fieldW * _fieldH);
    _fv = Float32List(_fieldW * _fieldH);
    _ft = Float32List(_fieldW * _fieldH);
    _fieldOn = false;
    _reformT = -1;
    _layoutWind();
    _movers.clear();
    final pending = _pendingEmerge;
    if (pending != null) {
      _pendingEmerge = null;
      emergeFrom(pending.$1, spread: pending.$2, colour: pending.$3);
    }
  }

  (Offset, double, int?)? _pendingEmerge;

  /// The realm gathers itself out of a knot of grains at [at]: every grain
  /// starts there, in [colour], and flies out to its place (the opening's
  /// last page ends in that knot, and the faction picker opens on it).
  /// Before the field has a size, it waits for [layout].
  void emergeFrom(
    Offset at, {
    double spread = 40,
    int? colour,
  }) {
    if (_n == 0 || _size.isEmpty) {
      _pendingEmerge = (at, spread, colour);
      return;
    }
    final next = _compose(_faction, _n, _size, 11);
    final r = math.Random(5);
    _fx = Float32List(_n);
    _fy = Float32List(_n);
    _fs = Float32List(_n);
    // Parchment by default; sepia on the light page, where parchment
    // would vanish into the paper.
    final knot = colour ?? (_ink ? 0xFF4A3C30 : 0xFFE8DCC8);
    _fc = Int32List(_n)..fillRange(0, _n, knot);
    for (var i = 0; i < _n; i++) {
      // A soft knot: dense at the middle, thinning out.
      final a = r.nextDouble() * math.pi * 2;
      final d = spread * math.sqrt(r.nextDouble()) * r.nextDouble();
      _fx[i] = at.dx + math.cos(a) * d;
      _fy[i] = at.dy + math.sin(a) * d;
      _fs[i] = _sz[i] * 0.7;
    }
    _targetOf = Int32List.fromList(List<int>.generate(_n, (i) => i));
    _from = _faction;
    _target = next;
    _reformT = 0;
    _fadeWindFrom = 0;
    _dropPictures();
  }

  static int _grainsFor(Size s) =>
      (s.width * s.height / 34).round().clamp(4000, 13000);

  /// Takes [comp] as the grains, settled.
  void _adopt(_Comp comp) {
    _n = comp.n;
    _hx = comp.x;
    _hy = comp.y;
    _sz = comp.s;
    _aux = comp.aux;
    _c = comp.colours(_ink);
    _c2 = comp.colours2(_ink);
    _cOther = comp.colours(!_ink);
    _c2Other = comp.colours2(!_ink);
    _role = comp.role;
    _ph = Float32List(_n);
    for (var i = 0; i < _n; i++) {
      _ph[i] = _hash(i);
    }
    _ox = Float32List(_n);
    _oy = Float32List(_n);
    _vx = Float32List(_n);
    _vy = Float32List(_n);
    _busy = Uint8List(_n);
    _top = comp.top;
    _waterY = comp.waterY;
    _wh = Float32List(_top.length);
    _wv = Float32List(_top.length);
    _sortForRest();
  }

  /// Still grains first, grouped by square; then everything that moves.
  void _sortForRest() {
    _cw = (_size.width / _cs).ceil() + 1;
    _ch = (_size.height / _cs).ceil() + 2;
    final chunks = _cw * _ch;
    final key = Int32List(_n);
    for (var i = 0; i < _n; i++) {
      if (_role[i] != _still) {
        key[i] = chunks;
        continue;
      }
      final cx = (_hx[i] / _cs).floor().clamp(0, _cw - 1);
      final cy = (_hy[i] / _cs).floor().clamp(0, _ch - 1);
      key[i] = cy * _cw + cx;
    }
    final order = List<int>.generate(_n, (i) => i)
      ..sort((a, b) => key[a] - key[b]);
    _hx = _permF(_hx, order);
    _hy = _permF(_hy, order);
    _ox = _permF(_ox, order);
    _oy = _permF(_oy, order);
    _vx = _permF(_vx, order);
    _vy = _permF(_vy, order);
    _sz = _permF(_sz, order);
    _ph = _permF(_ph, order);
    _aux = _permF(_aux, order);
    _c = _permI(_c, order);
    _c2 = _permI(_c2, order);
    _cOther = _permI(_cOther, order);
    _c2Other = _permI(_c2Other, order);
    _role = _permB(_role, order);
    _busy = _permB(_busy, order);
    _chunkFrom = Int32List(chunks)..fillRange(0, chunks, 0);
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
    var seams = 0;
    for (var i = _restEnd; i < _n; i++) {
      if (_role[i] == _seam) seams++;
    }
    _seams = Int32List(seams);
    seams = 0;
    for (var i = _restEnd; i < _n; i++) {
      if (_role[i] == _seam) _seams[seams++] = i;
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

  void dispose() {
    _dropPictures();
  }

  // ── Flying between realms ─────────────────────────────────────────────

  static const double _reformSecs = 1.7;
  double _reformT = -1;
  FactionId _from = FactionId.volcanic;
  Float32List _fx = Float32List(0), _fy = Float32List(0);
  Float32List _fs = Float32List(0);
  Int32List _fc = Int32List(0);
  _Comp? _target;
  Int32List _targetOf = Int32List(0);

  void _beginReform(FactionId was) {
    // Mid-flight already: start from wherever each grain is now.
    if (_reformT >= 0) _settleHomesMidway();
    _from = was;
    final next = _compose(_faction, _n, _size, 11);
    // The i-th grain from the top goes to the i-th place from the top, so
    // nothing crosses the whole screen.
    int keyOf(double x, double y) => (y / 24).floor() * 100000 + x.round();
    final cur = List<int>.generate(_n, (i) => i);
    final keysCur = Int32List(_n), keysNext = Int32List(_n);
    for (var i = 0; i < _n; i++) {
      keysCur[i] = keyOf(_hx[i], _hy[i]);
      keysNext[i] = keyOf(next.x[i], next.y[i]);
    }
    cur.sort((a, b) => keysCur[a] - keysCur[b]);
    final nxt = List<int>.generate(_n, (i) => i)
      ..sort((a, b) => keysNext[a] - keysNext[b]);
    _targetOf = Int32List(_n);
    for (var j = 0; j < _n; j++) {
      _targetOf[cur[j]] = nxt[j];
    }
    _fx = Float32List.fromList(_hx);
    _fy = Float32List.fromList(_hy);
    _fs = Float32List.fromList(_sz);
    _fc = Int32List.fromList(_c);
    _target = next;
    _reformT = 0;
    _fadeWindFrom = _windAlpha;
    _dropPictures();
  }

  // Where grain [i] is on its way: home, size and colour.
  double _e(int i) {
    final p = ((_reformT - 0.45 * _ph[i]) / (_reformSecs - 0.45)).clamp(
      0.0,
      1.0,
    );
    return p < 0.5 ? 4 * p * p * p : 1 - math.pow(-2 * p + 2, 3) / 2;
  }

  void _settleHomesMidway() {
    final tg = _target!;
    for (var i = 0; i < _n; i++) {
      final e = _e(i), j = _targetOf[i];
      _hx[i] = _fx[i] + (tg.x[j] - _fx[i]) * e;
      _hy[i] = _fy[i] + (tg.y[j] - _fy[i]) * e;
      _sz[i] = _fs[i] + (tg.s[j] - _fs[i]) * e;
      _c[i] = _mix(_fc[i], tg.colours(_ink)[j], e);
    }
  }

  void _stepReform(double dt) {
    _reformT += dt;
    final tg = _target!;
    for (var i = 0; i < _n; i++) {
      final e = _e(i), j = _targetOf[i];
      // A lift on the way, as sand thrown.
      final lift = math.sin(math.pi * e) * (16 + 30 * _ph[i]);
      _hx[i] =
          _fx[i] + (tg.x[j] - _fx[i]) * e + lift * 0.4 * (_ph[i] - 0.5) * 2;
      _hy[i] = _fy[i] + (tg.y[j] - _fy[i]) * e - lift;
      _sz[i] = _fs[i] + (tg.s[j] - _fs[i]) * e;
    }
    if (_reformT < _reformSecs) return;
    // Landed: the new realm's grains, in the order the pictures want.
    final perm = List<int>.filled(_n, 0);
    for (var i = 0; i < _n; i++) {
      perm[_targetOf[i]] = i;
    }
    // Each place keeps the offset of the grain that flew there.
    final ox = Float32List(_n), oy = Float32List(_n);
    final vx = Float32List(_n), vy = Float32List(_n);
    final busy = Uint8List(_n);
    for (var j = 0; j < _n; j++) {
      final i = perm[j];
      ox[j] = _ox[i];
      oy[j] = _oy[i];
      vx[j] = _vx[i];
      vy[j] = _vy[i];
      busy[j] = _busy[i];
    }
    _adopt(tg);
    _ox = ox;
    _oy = oy;
    _vx = vx;
    _vy = vy;
    _busy = busy;
    // _adopt sorted fresh offsets; sort these the same way.
    _resortOffsets(tg);
    _target = null;
    _reformT = -1;
  }

  // _adopt sorted the grains; carry the offsets through the same sort.
  void _resortOffsets(_Comp tg) {
    // Recover the sort by matching homes: _sortForRest is deterministic on
    // the same input, so redo it with the offsets attached.
    final chunks = _cw * _ch;
    final key = Int32List(_n);
    for (var i = 0; i < _n; i++) {
      if (tg.role[i] != _still) {
        key[i] = chunks;
        continue;
      }
      final cx = (tg.x[i] / _cs).floor().clamp(0, _cw - 1);
      final cy = (tg.y[i] / _cs).floor().clamp(0, _ch - 1);
      key[i] = cy * _cw + cx;
    }
    final order = List<int>.generate(_n, (i) => i)
      ..sort((a, b) => key[a] - key[b]);
    _ox = _permF(_ox, order);
    _oy = _permF(_oy, order);
    _vx = _permF(_vx, order);
    _vy = _permF(_vy, order);
    _busy = _permB(_busy, order);
    for (var i = 0; i < _n; i++) {
      if (_busy[i] != 0 && i < _restEnd) {
        final cx = (_hx[i] / _cs).floor().clamp(0, _cw - 1);
        final cy = (_hy[i] / _cs).floor().clamp(0, _ch - 1);
        _chunkBusy[cy * _cw + cx] = 1;
      }
    }
  }

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
    // Across the water, the finger makes waves.
    if (_waterY > 0 && (at.dy - _waterY).abs() < 40) {
      final c0 = ((at.dx - 30) / _col).floor(),
          c1 = ((at.dx + 30) / _col).ceil();
      for (var c = c0; c <= c1; c++) {
        if (c < 0 || c >= _wv.length) continue;
        final w = 1 - ((c * _col - at.dx).abs() / 30).clamp(0.0, 1.0);
        _wv[c] += (uy * 0.05 + ux.abs() * 0.015) * w;
      }
    }
  }

  /// A push out from [at], as a tap gives.
  void ripple(Offset at, {double strength = 260, double reach = 70}) {
    if (_fieldW == 0) return;
    _inject(at, reach, (dx, dy, w) {
      final l = math.max(1.0, math.sqrt(dx * dx + dy * dy));
      return (dx / l * strength * w, dy / l * strength * w);
    });
    if (_waterY > 0 && (at.dy - _waterY).abs() < 60) {
      final c = (at.dx / _col).round();
      if (c >= 0 && c < _wv.length) _wv[c] += 160;
    }
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

  // ── Stepping ──────────────────────────────────────────────────────────

  void step(double dt) {
    if (_n == 0) return;
    _t += dt;
    _stepField(dt);
    if (_reformT >= 0) {
      _stepReform(dt);
      _stepGrains(0, _n, dt);
    } else {
      for (var c = 0; c < _chunkFrom.length; c++) {
        if (_chunkFlow[c] == 0 && _chunkBusy[c] == 0) continue;
        _chunkBusy[c] = _stepGrains(_chunkFrom[c], _chunkTo[c], dt) ? 1 : 0;
      }
      _stepGrains(_restEnd, _n, dt);
    }
    _stepWater(dt);
    _stepWind(dt);
    _stepMovers(dt);
    if (_faction == FactionId.volcanic && _reformT < 0) {
      _flashAge += dt;
      _nextFlash -= dt;
      if (_nextFlash <= 0) {
        _flashAge = 0;
        _nextFlash = 9 + 10 * _rng.nextDouble();
      }
    }
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

  // The water's surface: a line of springs, a swell under it and the tilt.
  void _stepWater(double dt) {
    if (_wh.isEmpty || _waterY <= 0) return;
    final n = _wh.length;
    final h = _wh, v = _wv;
    // Two half steps keep the springs steady at 30 fps.
    final sdt = dt / 2;
    for (var s = 0; s < 2; s++) {
      for (var i = 0; i < n; i++) {
        final l = i > 0 ? h[i - 1] : h[i], r = i < n - 1 ? h[i + 1] : h[i];
        v[i] += ((l + r) * 0.5 - h[i]) * 1400 * sdt - h[i] * 6 * sdt;
        v[i] *= 1 - 1.6 * sdt;
      }
      for (var i = 0; i < n; i++) {
        h[i] = (h[i] + v[i] * sdt).clamp(-14.0, 14.0);
      }
    }
  }

  /// How far the waterline at [x] sits from its level (px, + is down).
  double _waterAt(double x) {
    final f = x / _col;
    final i = f.floor().clamp(0, _wh.length - 2);
    final t = (f - i).clamp(0.0, 1.0);
    final h = _wh[i] + (_wh[i + 1] - _wh[i]) * t;
    final swell =
        _fsin(x * 0.018 - _t * 1.1) * 3 + _fsin(x * 0.043 + _t * 1.7) * 1.4;
    final lean = tilt.dx.clamp(-1.0, 1.0) * 9 * (x / _size.width * 2 - 1);
    return h + swell + lean;
  }

  // ── Wind (Verdant): currents of grains across the screen ─────────────

  int _wn = 0;
  Float32List _wu = Float32List(0), _wnrm = Float32List(0);
  Float32List _wspd = Float32List(0), _wsz = Float32List(0);
  Float32List _wa = Float32List(0), _wox = Float32List(0);
  Float32List _woy = Float32List(0), _wvx = Float32List(0);
  Float32List _wvy = Float32List(0);
  Uint8List _wr = Uint8List(0);
  // Each current: its level, two swells and how fast it goes.
  static const List<(double, double, double, double, double)> _currents = [
    // (y share, amplitude, wavelength px, drift, speed px/s)
    (0.30, 26, 340, 0.21, 34),
    (0.43, 34, 420, -0.17, 46),
    (0.55, 22, 300, 0.26, 58),
    (0.66, 40, 480, -0.12, 40),
    (0.78, 28, 360, 0.19, 64),
    (0.90, 20, 280, -0.23, 50),
  ];
  double _windAlpha = 0, _fadeWindFrom = 0;

  void _layoutWind() {
    final w = _size.width;
    _wn = (w / 412 * 1300).round().clamp(900, 2200);
    _wu = Float32List(_wn);
    _wnrm = Float32List(_wn);
    _wspd = Float32List(_wn);
    _wsz = Float32List(_wn);
    _wa = Float32List(_wn);
    _wox = Float32List(_wn);
    _woy = Float32List(_wn);
    _wvx = Float32List(_wn);
    _wvy = Float32List(_wn);
    _wr = Uint8List(_wn);
    final r = math.Random(23);
    for (var k = 0; k < _wn; k++) {
      final c = r.nextInt(_currents.length);
      _wr[k] = c;
      _wu[k] = r.nextDouble() * (w + 80) - 40;
      // Gathered to the middle of the current, thinning outward.
      final g = (r.nextDouble() + r.nextDouble() + r.nextDouble()) / 3 - 0.5;
      _wnrm[k] = g * (40 + 30 * r.nextDouble());
      final core = 1 - (g.abs() * 2);
      _wspd[k] = _currents[c].$5 * (0.75 + 0.5 * core + 0.2 * r.nextDouble());
      _wsz[k] = 1.0 + 1.1 * r.nextDouble();
      _wa[k] = 0.16 + 0.6 * core * core;
    }
    _windAlpha = _faction == FactionId.verdant ? 1 : 0;
  }

  double _currentY(int c, double x) {
    final cur = _currents[c];
    final h = _size.height;
    return cur.$1 * h +
        cur.$2 * _fsin(x / cur.$3 * _tau + _t * cur.$4 + c * 1.7) +
        cur.$2 * 0.35 * _fsin(x / (cur.$3 * 0.47) * _tau - _t * cur.$4 * 1.6);
  }

  void _stepWind(double dt) {
    final want = _faction == FactionId.verdant ? 1.0 : 0.0;
    if (_reformT >= 0) {
      final p = (_reformT / _reformSecs).clamp(0.0, 1.0);
      _windAlpha = _fadeWindFrom + (want - _fadeWindFrom) * p;
    } else {
      _windAlpha = want;
    }
    if (_windAlpha <= 0) return;
    final w = _size.width;
    const drag = 5.0, spring = 6.0;
    for (var k = 0; k < _wn; k++) {
      var u = _wu[k] + _wspd[k] * dt;
      if (u > w + 40) u -= w + 80;
      _wu[k] = u;
      if (!_fieldOn && _wox[k] == 0 && _woy[k] == 0) continue;
      var ox = _wox[k], oy = _woy[k], vx = _wvx[k], vy = _wvy[k];
      var fu = 0.0, fv = 0.0;
      if (_fieldOn) {
        _sample(u + ox, _currentY(_wr[k], u) + _wnrm[k] + oy);
        fu = _su;
        fv = _sv;
      }
      vx += (drag * (fu - vx) - spring * ox) * dt;
      vy += (drag * (fv - vy) - spring * oy) * dt;
      ox += vx * dt;
      oy += vy * dt;
      if (!_fieldOn && ox.abs() < 0.1 && oy.abs() < 0.1 && vx.abs() < 1) {
        ox = oy = vx = vy = 0;
      }
      _wox[k] = ox;
      _woy[k] = oy;
      _wvx[k] = vx;
      _wvy[k] = vy;
    }
  }

  // ── Movers: embers, rain, splashes, dust, seeds ───────────────────────

  final _Movers _movers = _Movers(420);

  void _stepMovers(double dt) {
    final m = _movers;
    final w = _size.width, h = _size.height;
    // Keep each kind of this realm topped up, a few a frame.
    final settled = _reformT < 0 || _reformT > _reformSecs * 0.6;
    if (settled) {
      switch (_faction) {
        case FactionId.volcanic:
          if (_seams.isNotEmpty) {
            for (var s = 0; s < 2 && m.count(_ember) < 70; s++) {
              final g = _seams[_rng.nextInt(_seams.length)];
              m.spawn(
                _ember,
                _hx[g],
                _hy[g] - 2,
                (_rng.nextDouble() - 0.5) * 10,
                -(22 + 40 * _rng.nextDouble()),
                3 + 3 * _rng.nextDouble(),
                1.3 + 1.1 * _rng.nextDouble(),
                _rng.nextDouble(),
              );
            }
          }
        case FactionId.oceanic:
          for (var s = 0; s < 4 && m.count(_drop) < 90; s++) {
            m.spawn(
              _drop,
              _rng.nextDouble() * w * 1.2 - w * 0.1,
              -20 - _rng.nextDouble() * h * 0.6,
              0,
              520 + 160 * _rng.nextDouble(),
              99,
              0.8 + 0.5 * _rng.nextDouble(),
              _rng.nextDouble(),
            );
          }
        case FactionId.earthen:
          if (_top.isNotEmpty &&
              m.count(_mote) < 46 &&
              _rng.nextDouble() < 0.5) {
            final x = _rng.nextDouble() * w;
            m.spawn(
              _mote,
              x,
              _groundAt(x) - 2,
              0,
              -(7 + 14 * _rng.nextDouble()),
              5 + 4 * _rng.nextDouble(),
              1.2 + 1.2 * _rng.nextDouble(),
              _rng.nextDouble(),
            );
          }
        case FactionId.verdant:
          if (m.count(_seed) < 26 && _rng.nextDouble() < 0.3) {
            m.spawn(
              _seed,
              -20,
              _rng.nextInt(_currents.length).toDouble(),
              60 + 50 * _rng.nextDouble(),
              (_rng.nextDouble() - 0.5) * 50,
              99,
              1.6 + 1.2 * _rng.nextDouble(),
              _rng.nextDouble(),
            );
          }
      }
    }
    final wind = tilt.dx.clamp(-1.0, 1.0) * 110 + 26;
    for (var i = 0; i < m.n; i++) {
      if (m.life[i] <= 0) continue;
      final kind = m.kind[i];
      m.age[i] += dt;
      switch (kind) {
        case _ember:
          m.vx[i] += _fsin(_t * 2.3 + m.seed[i] * 40) * 18 * dt;
          m.x[i] += m.vx[i] * dt;
          m.y[i] += m.vy[i] * dt;
          if (m.age[i] > m.life[i]) m.life[i] = 0;
        case _drop:
          m.x[i] += wind * dt;
          m.y[i] += m.vy[i] * dt;
          if (_waterY > 0 && _faction == FactionId.oceanic) {
            final at = _waterY + _waterAt(m.x[i]);
            if (m.y[i] >= at) {
              final c = (m.x[i] / _col).round();
              if (c >= 0 && c < _wv.length) _wv[c] += 34;
              for (var s = 0; s < 3; s++) {
                m.spawn(
                  _splash,
                  m.x[i],
                  at - 1,
                  (_rng.nextDouble() - 0.5) * 70,
                  -(50 + 60 * _rng.nextDouble()),
                  0.32 + 0.2 * _rng.nextDouble(),
                  0.9 + 0.5 * _rng.nextDouble(),
                  _rng.nextDouble(),
                );
              }
              m.life[i] = 0;
            }
          } else if (m.y[i] > h + 30) {
            m.life[i] = 0;
          }
        case _splash:
          m.vy[i] += 520 * dt;
          m.x[i] += m.vx[i] * dt;
          m.y[i] += m.vy[i] * dt;
          if (m.age[i] > m.life[i]) m.life[i] = 0;
        case _mote:
          m.x[i] += _fsin(_t * 0.9 + m.seed[i] * 30) * 9 * dt;
          m.y[i] += m.vy[i] * dt;
          if (m.age[i] > m.life[i]) m.life[i] = 0;
        case _seed:
          // Rides its current (y holds which), tumbling a little across it.
          m.x[i] += m.vx[i] * dt;
          if (m.x[i] > w + 30) m.life[i] = 0;
      }
    }
  }

  double _groundAt(double x) {
    if (_top.isEmpty) return _size.height;
    final i = (x / _col).round().clamp(0, _top.length - 1);
    return _top[i];
  }

  // ── Drawing ───────────────────────────────────────────────────────────

  static ui.Image? _atlas;
  static final Paint _over = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _add = Paint()
    ..filterQuality = FilterQuality.medium
    ..blendMode = BlendMode.plus;

  final _Batch _dots = _Batch(_solid);
  final _Batch _glow = _Batch(_soft);
  final _Batch _wash = _Batch(_soft);
  final _Batch _streaks = _Batch(_streak);
  final Paint _bg = Paint();
  Object? _bgKey;

  void paint(Canvas canvas) {
    if (_size.isEmpty || _n == 0) return;
    _atlas ??= _buildAtlas();
    final atlas = _atlas!;
    debugSprites = 0;
    debugPictures = 0;
    // Light on the dark page adds up; pigment on the light one lies over.
    final glows = _ink ? _over : _add;

    _paintGround(canvas);
    _dots.clear();
    _glow.clear();
    _streaks.clear();

    if (_reformT >= 0) {
      _emitReform();
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
              _emitStill(k);
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
        _emitLive(k);
      }
    }
    _emitWind();
    _emitMovers();
    debugSprites = _dots.n + _glow.n + _streaks.n;
    _dots.draw(canvas, atlas, _over);
    _streaks.draw(canvas, atlas, _over);
    _glow.draw(canvas, atlas, glows);
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
  void _emitStill(int k) {
    final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k];
    final sp = _vx[k].abs() + _vy[k].abs();
    final c = _c[k];
    if (sp <= 30) {
      _dots.add(x, y, _sz[k], c);
      return;
    }
    final lit = math.min(1.0, (sp - 30) / 400);
    _dots.add(x, y, _sz[k], _lift(c, lit * 0.6, 0.35 * lit));
    if (lit > 0.5) {
      _glow.add(
        x,
        y,
        _sz[k] * 3,
        _ink
            ? _scaleAlpha(_pigmentOf(_faction), 0.12 * lit)
            : _scaleAlpha(c | 0xFF000000, 0.22 * lit),
      );
    }
  }

  // The realm's own pigment on the light page: what a grain deepens
  // toward when it is lit.
  static int _pigmentOf(FactionId f) => switch (f) {
    FactionId.volcanic => 0xFFD0401C, // vermilion
    FactionId.oceanic => 0xFF1E5A86, // Prussian blue
    FactionId.earthen => 0xFFB0602E, // burnt sienna
    FactionId.verdant => 0xFF4E4A7E, // slate violet
  };

  /// A grain lit (pushed fast, or thrown between realms): lighter on the
  /// dark page; deeper toward the realm's pigment on the light one, where
  /// lighter would only fade it into the paper.
  int _lift(int c, double t, double a) {
    if (!_ink) return _lighten(c, t, a);
    final al = (c >>> 24) / 255;
    final m = _mix(c | 0xFF000000, _pigmentOf(_faction), t);
    return _scaleAlpha(m, al + (1 - al) * a);
  }

  void _emitLive(int k) {
    switch (_role[k]) {
      case _seam:
        // Heat travels along the seams in slow waves.
        final w =
            0.5 +
            0.5 *
                _fsin(
                  _t * 1.25 + _hx[k] * 0.021 - _hy[k] * 0.013 + _ph[k] * 2.2,
                );
        final heat = (w * w) * _aux[k];
        final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k];
        _dots.add(x, y, _sz[k], _mix(_c[k], _c2[k], heat));
        // (On paper a glow only smudges; the cinnabar is heat enough.)
        if (!_ink && heat > 0.42 && (k & 3) == 0) {
          _glow.add(x, y, 9 + 6 * heat, _scaleAlpha(_c2[k], 0.16 * heat));
        }
      case _twinkle:
        final s = _fsin(_t * (0.6 + _aux[k]) + _ph[k] * _tau);
        final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k];
        if (s > 0.72) {
          final g = (s - 0.72) / 0.28;
          _dots.add(x, y, _sz[k] * (1 + 0.3 * g), _mix(_c[k], _c2[k], g));
          _glow.add(x, y, 8 * g + 2, _scaleAlpha(_c2[k], 0.3 * g));
        } else {
          _dots.add(x, y, _sz[k], _c[k]);
        }
      case _surface:
        final dy = _waterAt(_hx[k]) * _aux[k];
        final x = _hx[k] + _ox[k], y = _hy[k] + _oy[k] + dy;
        // Crests catch the light.
        final crest = (-dy / 6).clamp(0.0, 1.0) * _aux[k];
        _dots.add(
          x,
          y,
          _sz[k],
          crest > 0.05 ? _lighten(_c[k], crest * 0.45, 0) : _c[k],
        );
      default:
        _emitStill(k);
    }
  }

  void _emitReform() {
    final tg = _target!;
    final to = tg.colours(_ink);
    for (var i = 0; i < _n; i++) {
      final e = _e(i), j = _targetOf[i];
      final x = _hx[i] + _ox[i], y = _hy[i] + _oy[i];
      final c = _mix(_fc[i], to[j], e);
      // Sand in the air catches the light.
      final air = math.sin(math.pi * e);
      _dots.add(
        x,
        y,
        _sz[i],
        air > 0.05 ? _lift(c, air * 0.35, 0.25 * air) : c,
      );
    }
  }

  void _emitWind() {
    final a = _windAlpha;
    if (a <= 0 || _wn == 0) return;
    for (var k = 0; k < _wn; k++) {
      final u = _wu[k];
      final x = u + _wox[k];
      final y = _currentY(_wr[k], u) + _wnrm[k] + _woy[k];
      // Faint at the screen's sides, so a current comes in out of nothing.
      final edge = math.min(1.0, math.min(u + 40, _size.width + 40 - u) / 90);
      final al = _wa[k] * a * edge;
      if (al < 0.02) continue;
      _dots.add(
        x,
        y,
        _wsz[k],
        _ink ? _argb(al * 1.1, 0.34, 0.31, 0.5) : _argb(al, 0.86, 0.82, 0.95),
      );
    }
  }

  void _emitMovers() {
    final m = _movers;
    final vol = _flashAge < 0.5;
    if (vol) {
      // Far lightning: the ash sky lit twice from above.
      final f = _flashAge < 0.12
          ? _flashAge / 0.12
          : (_flashAge < 0.2
                ? 0.35
                : (_flashAge < 0.28 ? 0.9 : 1 - (_flashAge - 0.28) / 0.22));
      final w = _size.width;
      // (On the light page, a warm glare over the paper.)
      final k = _ink ? 0.7 : 1.0;
      _glow.add(w * 0.3, -20, w * 1.3, _argb(0.11 * f * k, 1, 0.82, 0.66));
      _glow.add(w * 0.8, 40, w * 0.9, _argb(0.07 * f * k, 1, 0.86, 0.72));
    }
    final wind = tilt.dx.clamp(-1.0, 1.0) * 110 + 26;
    for (var i = 0; i < m.n; i++) {
      if (m.life[i] <= 0) continue;
      final age = m.age[i];
      switch (m.kind[i]) {
        case _ember:
          final f = 1 - age / m.life[i];
          final fl = 0.7 + 0.3 * _fsin(_t * 14 + m.seed[i] * 50);
          final a = math.min(1.0, age * 3) * f * fl;
          _dots.add(
            m.x[i],
            m.y[i],
            m.size[i],
            _ink
                ? _argb(a, 0.84, 0.24 + 0.3 * f, 0.08)
                : _argb(a, 1, 0.45 + 0.35 * f, 0.15),
          );
          _glow.add(
            m.x[i],
            m.y[i],
            m.size[i] * 5,
            _ink
                ? _argb(0.1 * a, 0.86, 0.3, 0.1)
                : _argb(0.22 * a, 1, 0.4, 0.1),
          );
        case _drop:
          if (m.y[i] < -10) continue;
          final ang = math.atan2(wind, m.vy[i]);
          _streaks.addTurned(
            m.x[i],
            m.y[i],
            m.size[i] * 18,
            -ang,
            _ink ? _argb(0.3, 0.22, 0.4, 0.54) : _argb(0.24, 0.62, 0.8, 0.88),
          );
        case _splash:
          final a = 1 - age / m.life[i];
          _dots.add(
            m.x[i],
            m.y[i],
            m.size[i],
            _ink
                ? _argb(0.6 * a, 0.16, 0.36, 0.5)
                : _argb(0.7 * a, 0.75, 0.94, 0.95),
          );
        case _mote:
          final f = age / m.life[i];
          final a = math.min(1.0, f * 4) * (1 - f) * 0.6;
          _dots.add(
            m.x[i],
            m.y[i],
            m.size[i],
            _ink
                ? _argb(0.9 * a, 0.56, 0.42, 0.26)
                : _argb(a, 0.78, 0.66, 0.46),
          );
          if ((i & 3) == 0) {
            _glow.add(
              m.x[i],
              m.y[i],
              m.size[i] * 4,
              _ink
                  ? _argb(0.06 * a, 0.62, 0.46, 0.26)
                  : _argb(0.08 * a, 0.9, 0.75, 0.5),
            );
          }
        case _seed:
          final c = m.y[i].toInt();
          final x = m.x[i];
          final y =
              _currentY(c, x) +
              m.vy[i] * 0.4 +
              6 * _fsin(_t * 1.7 + m.seed[i] * 20);
          final a = _windAlpha * (0.55 + 0.35 * _fsin(_t * 3 + m.seed[i] * 30));
          if (_ink) {
            _dots.add(x, y, m.size[i], _argb(a, 0.24, 0.52, 0.3));
            _glow.add(x, y, m.size[i] * 5, _argb(0.08 * a, 0.3, 0.6, 0.36));
          } else {
            _dots.add(x, y, m.size[i], _argb(a, 0.5, 0.85, 0.62));
            _glow.add(x, y, m.size[i] * 5, _argb(0.12 * a, 0.45, 0.9, 0.6));
          }
      }
    }
  }

  final Paint _inkWashPaint = Paint();
  Object? _inkWashKey;

  // On the light page, a wash of the ground's own colour laid under its
  // grains, so the ground reads as a body (earth, water) and not as loose
  // specks on the paper. One gradient; no light breathes on paper.
  void _paintInkWash(Canvas canvas, double p) {
    final from = _inkWashOf(_reformT >= 0 ? _from : _faction);
    final to = _inkWashOf(_faction);
    final s0 = from.$1 + (to.$1 - from.$1) * p;
    final s1 = from.$2 + (to.$2 - from.$2) * p;
    final mid = _mix(from.$3, to.$3, p), low = _mix(from.$4, to.$4, p);
    final h = _size.height;
    final rect = Rect.fromLTRB(0, h * s0, _size.width, h);
    final key = (_size, s0, s1, mid, low);
    if (key != _inkWashKey) {
      _inkWashKey = key;
      _inkWashPaint.shader = ui.Gradient.linear(
        rect.topCenter,
        rect.bottomCenter,
        [Color(mid & 0x00FFFFFF), Color(mid), Color(low)],
        [0, ((s1 - s0) / (1 - s0)).clamp(0.0, 1.0), 1],
      );
    }
    canvas.drawRect(rect, _inkWashPaint);
  }

  // The near-black ground of the page, warmed by the realm's light.
  void _paintGround(Canvas canvas) {
    final rect = Offset.zero & _size;
    final p = _reformT >= 0 ? (_reformT / _reformSecs).clamp(0.0, 1.0) : 1.0;
    final from = _paletteOf(_reformT >= 0 ? _from : _faction, _ink);
    final to = _paletteOf(_faction, _ink);
    final top = _mix(from.$1, to.$1, p), bottom = _mix(from.$2, to.$2, p);
    final key = (_size, top, bottom);
    if (key != _bgKey) {
      _bgKey = key;
      _bg.shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [
        Color(top),
        Color(bottom),
      ]);
    }
    canvas.drawRect(rect, _bg);
    if (_ink) {
      _paintInkWash(canvas, p);
      return;
    }
    // A low light over the ground, breathing.
    _wash.clear();
    final w = _size.width, h = _size.height;
    final breathe = 0.85 + 0.15 * _fsin(_t * 0.7);
    void washes(FactionId f, double a) {
      if (a <= 0) return;
      switch (f) {
        case FactionId.volcanic:
          for (var i = 0; i < 4; i++) {
            final x = w * (0.1 + 0.27 * i);
            _wash.add(
              x,
              h * 0.74,
              w * 0.75,
              _argb(0.075 * a * breathe, 1, 0.3, 0.08),
            );
          }
        case FactionId.oceanic:
          _wash.add(
            w * 0.5,
            h * 0.66,
            w * 1.4,
            _argb(0.05 * a, 0.25, 0.75, 0.8),
          );
          _wash.add(w * 0.2, h * 0.35, w, _argb(0.025 * a, 0.3, 0.6, 0.8));
        case FactionId.earthen:
          _wash.add(
            w * 0.5,
            h * 0.72,
            w * 1.3,
            _argb(0.04 * a * breathe, 0.85, 0.6, 0.3),
          );
          _wash.add(
            w * 0.75,
            h * 0.86,
            w * 0.6,
            _argb(0.03 * a, 0.45, 0.85, 0.6),
          );
        case FactionId.verdant:
          _wash.add(
            w * 0.3,
            h * 0.55,
            w * 1.2,
            _argb(0.04 * a, 0.72, 0.65, 0.9),
          );
          _wash.add(
            w * 0.8,
            h * 0.8,
            w * 0.9,
            _argb(0.03 * a * breathe, 0.45, 0.8, 0.6),
          );
      }
    }

    if (_reformT >= 0) washes(_from, 1 - p);
    washes(_faction, p);
    _wash.draw(canvas, _atlas!, _add);
  }
}

// ── The realms ────────────────────────────────────────────────────────────

/// (top, bottom) of each realm's page.
(int, int) _paletteOf(FactionId f, bool ink) => ink
    // Parchment, each faintly the realm's.
    ? switch (f) {
        FactionId.volcanic => (0xFFF5EEE4, 0xFFEFE3D5),
        FactionId.oceanic => (0xFFF2EFE6, 0xFFE9EAE3),
        FactionId.earthen => (0xFFF4EEE2, 0xFFEEE4D3),
        FactionId.verdant => (0xFFF2EFE9, 0xFFE8E5EA),
      }
    : switch (f) {
        FactionId.volcanic => (0xFF0B0605, 0xFF170805),
        FactionId.oceanic => (0xFF04090D, 0xFF05141C),
        FactionId.earthen => (0xFF070806, 0xFF0F0C08),
        FactionId.verdant => (0xFF09080F, 0xFF0E0C16),
      };

/// The light page's wash under the ground: it starts (clear) at [$1] of the
/// height, is [$3] by [$2], and [$4] at the foot.
(double, double, int, int) _inkWashOf(FactionId f) => switch (f) {
  FactionId.volcanic => (0.67, 0.78, 0x22A06A50, 0x34603A2C),
  FactionId.oceanic => (0.655, 0.69, 0x2A2C6486, 0x3C1C4868),
  FactionId.earthen => (0.67, 0.78, 0x24A87A48, 0x34584838),
  FactionId.verdant => (0.45, 0.8, 0x0E6E6896, 0x1A5A5482),
};

class _Comp {
  _Comp(this.n)
    : x = Float32List(n),
      y = Float32List(n),
      s = Float32List(n),
      aux = Float32List(n),
      c = Int32List(n),
      c2 = Int32List(n),
      ic = Int32List(n),
      ic2 = Int32List(n),
      role = Uint8List(n);

  final int n;
  final Float32List x, y, s, aux;
  // Each grain in two palettes: light on the dark page ([c], [c2]) and
  // pigment on the light one ([ic], [ic2]).
  final Int32List c, c2, ic, ic2;
  final Uint8List role;
  Float32List top = Float32List(0);
  double waterY = 0;
  int i = 0;

  Int32List colours(bool ink) => ink ? ic : c;
  Int32List colours2(bool ink) => ink ? ic2 : c2;

  void add(
    double px,
    double py,
    double size,
    int col, {
    required int ink,
    int r = _still,
    int col2 = 0,
    int ink2 = 0,
    double a = 0,
  }) {
    if (i >= n) return;
    x[i] = px;
    y[i] = py;
    s[i] = size;
    c[i] = col;
    c2[i] = col2 == 0 ? col : col2;
    ic[i] = ink;
    ic2[i] = ink2 == 0 ? ink : ink2;
    role[i] = r;
    aux[i] = a;
    i++;
  }
}

_Comp _compose(FactionId f, int n, Size size, int seed) {
  final comp = _Comp(n);
  final r = math.Random(seed + f.index * 101);
  final w = size.width, h = size.height;
  final cols = (w / FactionRealmField._col).ceil() + 2;
  comp.top = Float32List(cols);

  // A fine dust over [0, yMax), drifting in banks, denser low. [colour]
  // gives (dark, ink).
  void dust(int count, double yMax, (int, int) Function(double d) colour) {
    var tries = 0;
    while (comp.i < n && count > 0 && tries < count * 40) {
      tries++;
      final x = r.nextDouble() * w, y = r.nextDouble() * yMax;
      final d = _fbm(x / 120, y / 120, seed + 3);
      final p = (0.22 + 0.9 * d * d) * (0.3 + 0.7 * y / yMax);
      if (r.nextDouble() > p) continue;
      final size = 1.0 + 1.1 * r.nextDouble();
      final (dark, ink) = colour(d);
      comp.add(x, y, size, dark, ink: ink);
      count--;
    }
  }

  // On the light page each realm is a plate in ink and earth pigments: what
  // glows on the dark page is the strongest colour on the light one (the
  // seams cinnabar, the veins viridian, the waterline indigo), and the
  // ground a stipple that deepens as it goes down.
  switch (f) {
    case FactionId.volcanic:
      double topAt(double x) =>
          h * 0.70 +
          h * 0.05 * (_fbm(x / 140, 0.5, seed) - 0.5) +
          7 * (_noise(x / 13, 2.5, seed + 1) - 0.5);
      for (var c = 0; c < cols; c++) {
        comp.top[c] = topAt(c * FactionRealmField._col);
      }
      final ground = (n * 0.72).round();
      final minTop = h * 0.66;
      while (comp.i < ground) {
        final x = r.nextDouble() * w;
        final y = minTop + r.nextDouble() * (h + 4 - minTop);
        final t = topAt(x);
        if (y < t) continue;
        final depth = ((y - t) / (h - t)).clamp(0.0, 1.0);
        // Basalt plates, flattened toward the eye, cracked between; the
        // cracks a little wider and hotter the deeper they run.
        final wx = x + 14 * (_fbm(x / 70, y / 70, seed + 7) - 0.5);
        final wy = y + 14 * (_fbm(x / 70, y / 70, seed + 8) - 0.5);
        final (edge, plate) = _crackle(wx, (wy - t) * 1.7, 44, seed + 9);
        final width = 2.2 + 2.4 * depth;
        final size = 1.7 + 1.2 * r.nextDouble();
        if (edge < width && y > t + 3) {
          final bias = 1 - edge / width;
          final hot = (bias * (0.6 + 0.4 * depth)).clamp(0.0, 1.0);
          comp.add(
            x,
            y,
            size,
            _mix(0xFF4A0E04, 0xFF8A2008, hot),
            ink: _mix(0xFF8A3624, 0xFFA82E18, hot),
            r: _seam,
            col2: _mix(0xFFFF5A14, 0xFFFFC870, hot * hot),
            ink2: _mix(0xFFD8401A, 0xFFF08A24, hot * hot),
            a: 0.45 + 0.55 * hot,
          );
        } else if (y < t + 2.5) {
          final v = r.nextDouble();
          comp.add(
            x,
            y,
            size,
            _mix(0xFF6A3220, 0xFF7E3A1E, v),
            ink: _mix(0xFF3E2A22, 0xFF56362A, v),
          );
        } else {
          // Each plate its own shade; warmed near its cracks.
          final warm = edge < width * 3
              ? 1 - (edge - width) / (width * 2)
              : 0.0;
          final shade = depth * 0.7 + r.nextDouble() * 0.2;
          final base = _mix(
            _mix(0xFF35201A, 0xFF24140F, plate),
            0xFF120A07,
            shade,
          );
          final inkBase = _mix(
            _mix(0xFFB6ACA4, 0xFF948A84, plate),
            0xFF5E5450,
            shade * 0.75,
          );
          comp.add(
            x,
            y,
            size,
            _mix(base, 0xFF5A2210, warm * warm * 0.85),
            ink: _mix(inkBase, 0xFFA86450, warm * warm * 0.3),
          );
        }
      }
      dust(n - comp.i, h * 0.70, (d) {
        if (r.nextDouble() < 0.02) {
          return (_argb(0.4, 1, 0.48, 0.22), _argb(0.5, 0.84, 0.3, 0.12));
        }
        return (
          _argb(0.08 + 0.22 * d, 0.42, 0.3, 0.26),
          _argb(0.1 + 0.26 * d, 0.38, 0.3, 0.27),
        );
      });
    case FactionId.oceanic:
      final wy = h * 0.66;
      comp.waterY = wy;
      for (var c = 0; c < cols; c++) {
        comp.top[c] = wy;
      }
      const band = 22.0;
      final water = (n * 0.66).round();
      while (comp.i < water) {
        final x = r.nextDouble() * w;
        final y = wy - 2 + math.pow(r.nextDouble(), 1.35) * (h + 6 - wy);
        final size = 1.4 + 1.1 * r.nextDouble();
        final dy = y - wy;
        if (dy < band) {
          final weight = 1 - dy / band * 0.75;
          final line = dy < 3.5;
          comp.add(
            x,
            y,
            size,
            line
                ? _argb(0.9, 0.56, 0.88, 0.85)
                : _mix(0xFF2D8F9C, 0xFF12505E, dy / band),
            ink: line
                ? _argb(0.94, 0.09, 0.25, 0.37)
                : _mix(0xFF2C6486, 0xFF7CA4B6, dy / band),
            r: _surface,
            a: weight,
          );
          continue;
        }
        final d = ((y - wy) / (h - wy)).clamp(0.0, 1.0);
        if (r.nextDouble() < 0.03) {
          comp.add(
            x,
            y,
            size,
            _mix(0xFF16505E, 0xFF0B2A34, d),
            ink: _mix(0xFF4C7C96, 0xFF285472, d),
            r: _twinkle,
            col2: 0xFF8FE2EA,
            ink2: 0xFFFFFDF6,
            a: 0.3 + r.nextDouble(),
          );
          continue;
        }
        final v = _fbm(x / 60, y / 30, seed + 5);
        comp.add(
          x,
          y,
          size,
          _mix(_mix(0xFF0F3E4C, 0xFF061922, d), 0xFF1A5462, v * 0.35),
          ink: _mix(_mix(0xFF80A8BA, 0xFF2C5A7A, d), 0xFFAECAD2, v * 0.35),
        );
      }
      dust(
        n - comp.i,
        wy - 4,
        (d) => (
          _argb(0.06 + 0.18 * d, 0.36, 0.5, 0.56),
          _argb(0.08 + 0.2 * d, 0.32, 0.44, 0.52),
        ),
      );
    case FactionId.earthen:
      double topAt(double x) =>
          h * 0.69 +
          h * 0.02 * _fsin(x * 0.006 + 1) +
          10 * (_fbm(x / 55, 0.5, seed) - 0.5);
      for (var c = 0; c < cols; c++) {
        comp.top[c] = topAt(c * FactionRealmField._col);
      }
      const layers = <int>[
        0xFF33251A, // topsoil
        0xFF5C3A24, // red mud
        0xFF7E6236, // ochre
        0xFF3F3A34, // grey clay
        0xFF1F1B17, // bedrock
      ];
      const inkLayers = <int>[
        0xFF6E5646, // raw umber
        0xFFA85E3C, // burnt sienna
        0xFFC69C58, // yellow ochre
        0xFF9C968E, // grey clay
        0xFF6C655E, // bedrock
      ];
      const splits = [0.1, 0.3, 0.44, 0.66];
      // Crystal veins, slanting through the strata.
      final veins = [
        for (var v = 0; v < 4; v++)
          (
            w * (0.12 + 0.24 * v + 0.08 * r.nextDouble()),
            h * (0.78 + 0.14 * r.nextDouble()),
            (r.nextDouble() - 0.5) * 1.6 - math.pi / 2,
            50 + 70 * r.nextDouble(),
          ),
      ];
      double veinDist(double x, double y) {
        var best = 99.0;
        for (final (vx, vy, a, len) in veins) {
          final dx = x - vx, dy = y - vy;
          final ux = math.cos(a), uy = math.sin(a);
          final along = (dx * ux + dy * uy).clamp(-len / 2, len / 2);
          final px = vx + ux * along, py = vy + uy * along;
          final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
          if (d < best) best = d;
        }
        return best;
      }

      final ground = (n * 0.72).round();
      final minTop = h * 0.66;
      while (comp.i < ground) {
        final x = r.nextDouble() * w;
        final y = minTop + r.nextDouble() * (h + 4 - minTop);
        final t = topAt(x);
        if (y < t) continue;
        final size = 1.7 + 1.2 * r.nextDouble();
        final vd = veinDist(x, y);
        if (vd < 3.6) {
          if (r.nextDouble() < 0.28) {
            comp.add(
              x,
              y,
              size + 0.3,
              0xFF4E8A6E,
              ink: 0xFF267458,
              r: _twinkle,
              col2: 0xFFC8F0D8,
              ink2: 0xFFE4FFF0,
              a: 0.4 + r.nextDouble(),
            );
          } else {
            final v = r.nextDouble();
            comp.add(
              x,
              y,
              size,
              _mix(0xFF3E6A55, 0xFF64A07E, v),
              ink: _mix(0xFF2C6A54, 0xFF4A9276, v),
            );
          }
          continue;
        }
        if (y < t + 2.5) {
          final v = r.nextDouble();
          comp.add(
            x,
            y,
            size,
            _mix(0xFF5E4830, 0xFF6E5638, v),
            ink: _mix(0xFF4A3A2C, 0xFF5E4A38, v),
          );
          continue;
        }
        final depth = ((y - t) / (h - t)).clamp(0.0, 1.0);
        final wob = 0.05 * (_fbm(x / 90, depth * 3, seed + 4) - 0.5) * 2;
        var layer = 0;
        while (layer < splits.length && depth + wob > splits[layer]) {
          layer++;
        }
        final jit = r.nextDouble();
        var col = _mix(layers[layer], 0xFF100D09, jit * 0.35);
        var ink = _mix(inkLayers[layer], 0xFF3A322A, jit * 0.25);
        // The top of each layer catches a little light (on the light page,
        // a drawn line between the layers).
        if (layer > 0 && depth + wob - splits[layer - 1] < 0.012) {
          col = _mix(col, 0xFF8A7050, 0.45);
          ink = _mix(ink, 0xFF3A2E24, 0.45);
        }
        if (r.nextDouble() < 0.035) {
          final v = r.nextDouble();
          col = _mix(0xFF7A5A30, 0xFF9A7A48, v);
          ink = _mix(0xFFDCB678, 0xFFC08A40, v);
        }
        comp.add(x, y, size, col, ink: ink);
      }
      dust(
        n - comp.i,
        h * 0.69,
        (d) => (
          _argb(0.07 + 0.2 * d, 0.42, 0.36, 0.27),
          _argb(0.09 + 0.22 * d, 0.42, 0.33, 0.24),
        ),
      );
    case FactionId.verdant:
      // Banks of cloud: (centre x, centre y, radius) lobes, as shares.
      const banks = [
        [
          (0.2, 0.62, 0.13),
          (0.34, 0.6, 0.16),
          (0.48, 0.63, 0.11),
          (0.3, 0.66, 0.14),
        ],
        [
          (0.66, 0.8, 0.12),
          (0.8, 0.77, 0.15),
          (0.94, 0.8, 0.12),
          (0.8, 0.83, 0.15),
        ],
        [
          (0.05, 0.92, 0.16),
          (0.3, 0.94, 0.18),
          (0.58, 0.95, 0.17),
          (0.9, 0.96, 0.2),
        ],
        [(0.72, 0.38, 0.08), (0.82, 0.37, 0.1), (0.9, 0.39, 0.07)],
      ];
      final cloud = (n * 0.45).round();
      var tries = 0;
      while (comp.i < cloud && tries < cloud * 30) {
        tries++;
        final b = banks[r.nextInt(banks.length)];
        final l = b[r.nextInt(b.length)];
        final cx = l.$1 * w, cy = l.$2 * h, rad = l.$3 * w;
        final a = r.nextDouble() * _tau, d = math.sqrt(r.nextDouble()) * rad;
        final x = cx + math.cos(a) * d, y = cy + math.sin(a) * d * 0.55;
        // Flat underneath.
        if (y > cy + rad * 0.22) continue;
        // Lit from above: the top of each lobe pale, its underside dark.
        final light = (1 - ((y - (cy - rad * 0.55)) / (rad * 0.8))).clamp(
          0.0,
          1.0,
        );
        final edge = d / rad;
        final al = 0.26 + 0.4 * (1 - edge * edge);
        comp.add(
          x,
          y,
          1.1 + 1.2 * r.nextDouble(),
          _argb(
            al,
            0.26 + 0.5 * light,
            0.24 + 0.46 * light,
            0.34 + 0.52 * light,
          ),
          // A wash of slate ink, heaviest along the underside.
          ink: _argb(
            al * (1.3 - 0.4 * light),
            0.3 + 0.38 * light,
            0.28 + 0.36 * light,
            0.42 + 0.34 * light,
          ),
        );
      }
      dust(n - comp.i, h, (d) {
        if (r.nextDouble() < 0.03) {
          return (_argb(0.32, 0.45, 0.78, 0.6), _argb(0.48, 0.28, 0.55, 0.36));
        }
        return (
          _argb(0.05 + 0.16 * d, 0.42, 0.39, 0.5),
          _argb(0.07 + 0.18 * d, 0.4, 0.37, 0.5),
        );
      });
  }
  // Anything a sampler fell short on: plain dust.
  while (comp.i < n) {
    comp.add(
      r.nextDouble() * w,
      r.nextDouble() * h,
      1.2,
      _argb(0.1, 0.4, 0.4, 0.4),
      ink: _argb(0.12, 0.4, 0.38, 0.36),
    );
  }
  return comp;
}

// ── Movers ────────────────────────────────────────────────────────────────

class _Movers {
  _Movers(int cap)
    : kind = Uint8List(cap),
      x = Float32List(cap),
      y = Float32List(cap),
      vx = Float32List(cap),
      vy = Float32List(cap),
      life = Float32List(cap),
      age = Float32List(cap),
      size = Float32List(cap),
      seed = Float32List(cap),
      n = cap;

  final Uint8List kind;
  final Float32List x, y, vx, vy, life, age, size, seed;
  final int n;

  int count(int k) {
    var c = 0;
    for (var i = 0; i < n; i++) {
      if (life[i] > 0 && kind[i] == k) c++;
    }
    return c;
  }

  void clear() => life.fillRange(0, n, 0);

  void spawn(
    int k,
    double px,
    double py,
    double ux,
    double uy,
    double l,
    double s,
    double sd,
  ) {
    for (var i = 0; i < n; i++) {
      if (life[i] > 0) continue;
      kind[i] = k;
      x[i] = px;
      y[i] = py;
      vx[i] = ux;
      vy[i] = uy;
      life[i] = l;
      age[i] = 0;
      size[i] = s;
      seed[i] = sd;
      return;
    }
  }
}

// ── Sprites ───────────────────────────────────────────────────────────────

const double _solidCell = 16, _softCell = 32, _streakW = 6, _streakH = 32;
const Rect _solid = Rect.fromLTWH(0, 0, _solidCell, _solidCell);
const Rect _soft = Rect.fromLTWH(_solidCell, 0, _softCell, _softCell);
const Rect _streak = Rect.fromLTWH(
  _solidCell + _softCell,
  0,
  _streakW,
  _streakH,
);

/// A grain, a soft light and a rain streak.
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
  // A streak: bright at its foot, fading up.
  final sr = _streak.deflate(1.5);
  c.drawRRect(
    RRect.fromRectAndRadius(sr, const Radius.circular(2)),
    Paint()
      ..shader = ui.Gradient.linear(
        sr.topCenter,
        sr.bottomCenter,
        [white.withValues(alpha: 0), white.withValues(alpha: 0.5), white],
        const [0, 0.6, 1],
      ),
  );
  return rec.endRecording().toImageSync(
    (_solidCell + _softCell + _streakW).toInt(),
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

  /// Its foot at (x, y), [length] long, turned by [angle].
  void addTurned(double x, double y, double length, double angle, int argb) {
    if ((argb >>> 24) < 3) return;
    if (n >= _colors.length) _grow();
    final s = length / _src.height;
    final sc = s * math.cos(angle), ss = s * math.sin(angle);
    final ax = _src.width / 2, ay = _src.height;
    final i = n * 4;
    _xf[i] = sc;
    _xf[i + 1] = ss;
    _xf[i + 2] = x - (sc * ax - ss * ay);
    _xf[i + 3] = y - (ss * ax + sc * ay);
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

// ── The view ──────────────────────────────────────────────────────────────

/// The realm on screen: stirred by a finger, pushed by a tap, the water
/// leaning with the phone. Pauses with [TickerMode].
class FactionRealmView extends StatefulWidget {
  const FactionRealmView({
    super.key,
    required this.faction,
    this.ink = false,
    this.field,
    this.stirs = true,
  });

  final FactionId faction;

  /// Whether a finger on it stirs it. Off when a [FactionRealmStir] round
  /// a whole screen does the stirring, so no finger stirs twice.
  final bool stirs;

  /// Drawn for a light page.
  final bool ink;

  /// A field to draw instead of a new one (tests).
  final FactionRealmField? field;

  @override
  State<FactionRealmView> createState() => _FactionRealmViewState();
}

class _FactionRealmViewState extends State<FactionRealmView>
    with SingleTickerProviderStateMixin {
  late final FactionRealmField _field =
      widget.field ??
      FactionRealmField(faction: widget.faction, ink: widget.ink);
  late final Ticker _ticker = createTicker(_tick);
  final _Frame _frame = _Frame();
  Duration _last = Duration.zero;
  StreamSubscription<AccelerometerEvent>? _accel;
  double _tx = 0, _ty = 0;

  @override
  void initState() {
    super.initState();
    _field
      ..faction = widget.faction
      ..ink = widget.ink;
    _ticker.start();
    _listenTilt();
  }

  @override
  void didUpdateWidget(covariant FactionRealmView old) {
    super.didUpdateWidget(old);
    _field
      ..faction = widget.faction
      ..ink = widget.ink;
    _listenTilt();
  }

  // Only the water leans, so only Oceanic listens.
  void _listenTilt() {
    final want = widget.faction == FactionId.oceanic;
    if (want == (_accel != null)) return;
    if (!want) {
      _accel?.cancel();
      _accel = null;
      _field.tilt = Offset.zero;
      return;
    }
    try {
      _accel =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.uiInterval,
          ).listen(
            (e) {
              const g = 9.81, lp = 0.06;
              _tx += ((e.x / g).clamp(-1.0, 1.0) - _tx) * lp;
              _ty += ((-e.y / g).clamp(-1.0, 1.0) - _ty) * lp;
              _field.tilt = Offset(-_tx, _ty);
            },
            onError: (Object _) {},
            cancelOnError: true,
          );
    } catch (_) {
      _accel = null;
    }
  }

  @override
  void dispose() {
    _accel?.cancel();
    _ticker.dispose();
    _frame.dispose();
    if (widget.field == null) _field.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _field.step(dt);
    _frame.tick();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _field.layout(Size(box.maxWidth, box.maxHeight));
        final paint = RepaintBoundary(
          child: CustomPaint(
            isComplex: true,
            willChange: true,
            painter: _RealmPainter(_field, repaint: _frame),
            child: const SizedBox.expand(),
          ),
        );
        if (!widget.stirs) return paint;
        return FactionRealmStir(
          field: _field,
          behavior: HitTestBehavior.opaque,
          child: paint,
        );
      },
    );
  }
}

/// Stirs [field] with every finger drawn over [child], and pushes it out
/// where one is lifted without having moved. A [Listener], not a gesture:
/// it takes nothing from the buttons, pages and scrolls on top of it, so a
/// swipe through a page stirs the sand under it too.
class FactionRealmStir extends StatefulWidget {
  const FactionRealmStir({
    super.key,
    required this.field,
    required this.child,
    this.behavior = HitTestBehavior.translucent,
  });

  final FactionRealmField field;
  final Widget child;
  final HitTestBehavior behavior;

  @override
  State<FactionRealmStir> createState() => _FactionRealmStirState();
}

class _FactionRealmStirState extends State<FactionRealmStir> {
  final Map<int, (Duration, double)> _down = {};

  @override
  Widget build(BuildContext context) => Listener(
    behavior: widget.behavior,
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

class _Frame extends ChangeNotifier {
  void tick() => notifyListeners();
}

class _RealmPainter extends CustomPainter {
  _RealmPainter(this.field, {required Listenable repaint})
    : super(repaint: repaint);

  final FactionRealmField field;

  @override
  void paint(Canvas canvas, Size size) => field.paint(canvas);

  @override
  bool shouldRepaint(covariant _RealmPainter old) => old.field != field;
}

// ── Helpers ───────────────────────────────────────────────────────────────

Float32List _permF(Float32List a, List<int> order) {
  final out = Float32List(a.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Int32List _permI(Int32List a, List<int> order) {
  final out = Int32List(a.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

Uint8List _permB(Uint8List a, List<int> order) {
  final out = Uint8List(a.length);
  for (var j = 0; j < order.length; j++) {
    out[j] = a[order[j]];
  }
  return out;
}

int _scaleAlpha(int argb, double t) =>
    (((argb >>> 24) * t).round().clamp(0, 255) << 24) | (argb & 0xFFFFFF);

/// [argb] lifted toward white by [t], and toward opaque by [a].
int _lighten(int argb, double t, double a) {
  final al = (argb >>> 24) / 255;
  final r = ((argb >> 16) & 0xFF) / 255, g = ((argb >> 8) & 0xFF) / 255;
  final b = (argb & 0xFF) / 255;
  return _argb(
    al + (1 - al) * a,
    r + (1 - r) * t,
    g + (1 - g) * t,
    b + (1 - b) * t,
  );
}

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

double _hash(int k) {
  final v = math.sin(k * 127.1 + 311.7) * 43758.5453;
  return v - v.floorToDouble();
}

/// Cracks between plates of size [cell]: how far (px, roughly) from the
/// nearest crack, and a fixed shade 0..1 for the plate.
(double, double) _crackle(double x, double y, double cell, int seed) {
  final cx = (x / cell).floor(), cy = (y / cell).floor();
  var d1 = 1e9, d2 = 1e9;
  var shade = 0.0;
  for (var j = -1; j <= 1; j++) {
    for (var i = -1; i <= 1; i++) {
      final gx = cx + i, gy = cy + j;
      final px = (gx + 0.15 + 0.7 * _lattice(gx, gy, seed)) * cell;
      final py = (gy + 0.15 + 0.7 * _lattice(gx, gy, seed + 1)) * cell;
      final d = math.sqrt((x - px) * (x - px) + (y - py) * (y - py));
      if (d < d1) {
        d2 = d1;
        d1 = d;
        shade = _lattice(gx, gy, seed + 2);
      } else if (d < d2) {
        d2 = d;
      }
    }
  }
  return ((d2 - d1) * 0.5, shade);
}

double _smooth(double t) => t * t * (3 - 2 * t);

double _lattice(int x, int y, int seed) {
  var h = (x * 0x27d4eb2d) ^ (y * 0x165667b1) ^ (seed * 0x5bd1e995);
  h = (h ^ (h >> 15)) * 0x2c1b3c6d;
  h = (h ^ (h >> 12)) * 0x297a2d39;
  h ^= h >> 15;
  return (h & 0xFFFFFF) / 0xFFFFFF;
}

double _noise(double x, double y, int seed) {
  final xi = x.floor(), yi = y.floor();
  final fx = _smooth(x - xi), fy = _smooth(y - yi);
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
