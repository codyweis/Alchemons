// lib/widgets/fx/essence_rim.dart
//
// A CARD'S RIM, IN THE SPECIMEN'S OWN SAND.
//
//   Once a specimen has gathered out of its element on the extraction card,
//   what is left of the essence runs off the stage and round the card's edge
//   and settles there as a bank of sand: that is the card's border. It lies
//   as sand would -- deepest along the foot and pooled in the bottom corners,
//   thinner up the sides, only a broken dusting along the top -- and it runs
//   out from the stage's side, so the two currents meet on the far side,
//   lopsided.
//
//   At rest it is still sand with a little life in it: a few grains catching
//   the light, and a few loose ones doing what the element does -- rising up
//   the sides (fire, steam, light...), running down them (water, blood...),
//   or creeping round the bank (earth, crystal...).
//
//   Dressed as the hatch's sand is (hatch_sand.dart): gilded for a
//   Transmuted, with a polish passing over it; a rainbow once round for a
//   prismatic skin, its glints turning through the hues; a variant's colour
//   as a twinkling scatter. An Alchemized one never settles: its bank runs
//   round the card like a river.
//
// Cheap at rest: the settled bank is one recorded picture, and only the few
// hundred grains that glint or drift are drawn each frame, as points in
// batches. The pour itself (about two and a half seconds) is drawn live, and
// so is an Alchemized river, with fewer grains. No blur.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart'
    show ShellMutationLook;
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart' show GrainBatch;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// What the rim's sand is coloured as.
enum RimColour {
  /// The specimen's element.
  element,

  /// Transmuted: read into gold, a polish passing over it.
  gilded,

  /// A prismatic skin: a rainbow once round, its glints turning.
  prismatic,
}

/// What the loose grains do at rest.
enum _Drift { rise, fall, creep }

_Drift _driftOf(EssenceElement e) => switch (e) {
  EssenceElement.fire ||
  EssenceElement.lava ||
  EssenceElement.steam ||
  EssenceElement.air ||
  EssenceElement.lightning ||
  EssenceElement.spirit ||
  EssenceElement.light => _Drift.rise,
  EssenceElement.water ||
  EssenceElement.mud ||
  EssenceElement.poison ||
  EssenceElement.blood => _Drift.fall,
  _ => _Drift.creep,
};

/// Embers and sparks flicker; everything else glints now and then.
bool _flickers(EssenceElement e) =>
    e == EssenceElement.fire ||
    e == EssenceElement.lava ||
    e == EssenceElement.lightning;

/// The rainbow, as the hatch's prismatic sand has it.
const List<Color> _prism = [
  Color(0xFFFF6B6B),
  Color(0xFFFFB86B),
  Color(0xFFFFE66D),
  Color(0xFF4ECDC4),
  Color(0xFF6B9BFF),
  Color(0xFFB06BFF),
];

/// 0..12 round the rim's rainbow, for whatever else wears a prismatic
/// specimen's sand (the card coming apart, card_dissolve.dart).
Color rimPrismHue(double h) => _hue12(h);

/// 0..12 round the rainbow.
Color _hue12(double h) {
  final x = (h % 12) / 2;
  final i = x.floor();
  return Color.lerp(_prism[i % 6], _prism[(i + 1) % 6], x - i)!;
}

/// The rim's grains: where each lies, how it got there, what it does.
class EssenceRimField {
  EssenceRimField({
    required this.element,
    this.colour = RimColour.element,
    this.loose = false,
    this.fleck,
    this.looseLight = const Color(0xFFB9A7F5),
    this.reduced = false,
    this.seed = 0,
  });

  final EssenceElement element;
  final RimColour colour;

  /// Alchemized: the bank never settles. See the file's head.
  final bool loose;

  /// A variant's colour: a scatter of grains of it, twinkling.
  final Color? fleck;

  /// The light loose grains glint in (Alchemized's violet).
  final Color looseLight;

  /// Fewer grains, for the performance setting.
  final bool reduced;

  /// Every specimen's bank lies a little differently.
  final int seed;

  // What a grain does besides lie still.
  static const int _still = 0, _twinkle = 1, _fleckle = 2, _polish = 3;
  static const int _turn = 4;

  // Settled grains are bucketed by tone, how deep they lie, and size.
  static const int _alphas = 3, _sizes = 3;
  static const List<double> _alphaOf = [0.9, 0.62, 0.34];
  static const List<double> _diaOf = [1.0, 1.4, 1.9];

  // The live layer's buckets.
  static const int _gl = 0, _gh = 4, _fl = 6, _fh = 10, _dr = 12, _po = 16;
  static const int _tu = 20, _liveBuckets = 32;
  static const List<double> _levelAlpha = [0.24, 0.48, 0.74, 0.96];

  Size _size = Size.zero;
  double _sourceY = -1;
  double _w = 0, _h = 0, _p = 0, _k = 1;

  /// How deep the bank lies, every 2 px round the rim.
  Float32List _depth = Float32List(0);

  // Grains.
  int _n = 0;
  Float32List _s = Float32List(0), _d = Float32List(0);
  Float32List _hx = Float32List(0), _hy = Float32List(0);
  Float32List _ta = Float32List(0), _ts = Float32List(0);
  Float32List _len = Float32List(0), _d0 = Float32List(0);
  Float32List _wave = Float32List(0), _ph = Float32List(0);
  Float32List _aux = Float32List(0), _flow = Float32List(0);
  Int8List _dir = Int8List(0);
  Uint8List _bucket = Uint8List(0), _role = Uint8List(0);
  Int32List _lively = Int32List(0);
  int _drifters = 0;
  double _pourEnd = 0;

  // Colours.
  List<Color> _tones = const [];
  Color _glint = const Color(0xFFFFFBEA);
  Color _drift = const Color(0xFFFFFBEA);
  int _fleckTone = -1, _looseTone = -1;
  late final _Drift _mode = _driftOf(element);
  late final bool _flicker = _flickers(element);

  GrainBatch _main = GrainBatch(1);
  GrainBatch _trailA = GrainBatch(1), _trailB = GrainBatch(1);
  final GrainBatch _live = GrainBatch(_liveBuckets);
  final List<Color> _liveColour = List.filled(
    _liveBuckets,
    const Color(0x00000000),
  );
  final List<double> _liveDia = List.filled(_liveBuckets, 1);

  ui.Picture? _rest;

  /// How long after the pour begins every grain has settled, in seconds.
  double get pourEnd => _pourEnd;

  /// Grains in the bank.
  int get debugGrains => _n;

  /// The most grains the live layer can draw in a frame at rest.
  int get debugLiveCap => _lively.length * 2 + _drifters * 3;

  void dispose() {
    _rest?.dispose();
    _rest = null;
  }

  // ── Layout ────────────────────────────────────────────────────────────

  /// [sourceY] is where on the left edge the essence spills from, 0..1 down
  /// it.
  void layout(Size size, double sourceY) {
    if (size == _size && sourceY == _sourceY) return;
    _size = size;
    _sourceY = sourceY;
    _w = size.width;
    _h = size.height;
    _p = 2 * (_w + _h);
    _k = (math.min(_w, _h) / 370).clamp(0.85, 1.5);
    _rest?.dispose();
    _rest = null;
    if (_w < 8 || _h < 8) {
      _n = 0;
      return;
    }
    _dressTones();
    _measureBank();
    _compose();
  }

  // The rim runs clockwise from the top-left corner: along the top, down the
  // right, back along the foot, up the left. A grain lies [d] in from it.
  double _px = 0, _py = 0;
  void _place(double s, double d) {
    final w = _w, h = _h;
    s %= _p;
    if (s < w) {
      _px = s;
      _py = d;
    } else if (s < w + h) {
      _px = w - d;
      _py = s - w;
    } else if (s < 2 * w + h) {
      _px = w - (s - w - h);
      _py = h - d;
    } else {
      _px = d;
      _py = h - (s - 2 * w - h);
    }
  }

  double _bank(double s) {
    final i = ((s % _p) / 2).floor();
    return _depth[math.min(i, _depth.length - 1)];
  }

  void _measureBank() {
    final w = _w, h = _h, p = _p;
    final m = (p / 2).ceil() + 1;
    _depth = Float32List(m);
    double toCorner(double s, double c) {
      final d = (s - c).abs();
      return math.min(d, p - d);
    }

    double pool(double s, double c, double r) {
      final x = toCorner(s, c) / r;
      return math.exp(-x * x);
    }

    // Up a side: a dusting at the top, deepening to the foot.
    double side(double y01) =>
        2.6 + 6.6 * math.pow(_smooth(0, 1, y01), 1.4).toDouble();

    for (var i = 0; i < m; i++) {
      final s = math.min(i * 2.0, p - 0.001);
      double base;
      if (s < w) {
        // The top: a dusting, gathered here and there.
        base = 0.9 + 2.0 * _smooth(0.3, 0.6, _noise(s, 70, 3));
      } else if (s < w + h) {
        base = side((s - w) / h) * 0.9;
      } else if (s < 2 * w + h) {
        base = 9.5;
      } else {
        // The stage's side, where it spilled from, holds a little more.
        base = side((h - (s - 2 * w - h)) / h) * 1.1;
      }
      // Pooled in the corners: deep at the foot, a catch at the top.
      base +=
          7.0 * pool(s, w + h, 34) +
          8.0 * pool(s, 2 * w + h, 38) +
          2.4 * pool(s, 0, 22) +
          2.0 * pool(s, w, 20);
      final drift = 0.62 + 0.76 * _noise(s, 110, 1);
      final fine = 0.82 + 0.36 * _noise(s, 26, 2);
      _depth[i] = math.min(base * drift * fine, 20.0) * _k;
    }
  }

  void _dressTones() {
    final tones = <Color>[];
    switch (colour) {
      case RimColour.element:
        final ramp = essenceRamp(element);
        for (var k = 0; k < 8; k++) {
          final x = (0.14 + 0.8 * k / 7) * 3;
          final i = math.min(x.floor(), 2);
          tones.add(Color.lerp(ramp[i], ramp[i + 1], x - i)!);
        }
        _glint = ramp[3];
        _drift = Color.lerp(ramp[2], ramp[3], 0.35)!;
      case RimColour.gilded:
        for (var k = 0; k < 8; k++) {
          final v = k / 7;
          tones.add(
            v < 0.5
                ? Color.lerp(
                    ShellMutationLook.bronze,
                    ShellMutationLook.gold,
                    v / 0.5,
                  )!
                : Color.lerp(
                    ShellMutationLook.gold,
                    ShellMutationLook.paleGold,
                    (v - 0.5) / 0.5 * 0.7,
                  )!,
          );
        }
        _glint = ShellMutationLook.paleGold;
        _drift = Color.lerp(
          ShellMutationLook.gold,
          ShellMutationLook.paleGold,
          0.5,
        )!;
      case RimColour.prismatic:
        for (var k = 0; k < 12; k++) {
          tones.add(
            Color.lerp(_hue12(k.toDouble()), const Color(0xFF000000), 0.06)!,
          );
        }
        _glint = const Color(0xFFFFFBEA);
        _drift = const Color(0xFFFFF4E0);
    }
    final f = fleck;
    if (f != null) {
      _fleckTone = tones.length;
      tones.add(Color.lerp(f, const Color(0xFF000000), 0.3)!);
    }
    if (loose) {
      _looseTone = tones.length;
      tones.add(looseLight);
      _drift = looseLight;
    }
    _tones = tones;
    final buckets = tones.length * _alphas * _sizes;
    _main = GrainBatch(buckets);
    _trailA = GrainBatch(buckets);
    _trailB = GrainBatch(buckets);

    void level(int at, Color c, double dia, [List<double> a = _levelAlpha]) {
      for (var i = 0; i < a.length; i++) {
        _liveColour[at + i] = c.withValues(alpha: a[i]);
        _liveDia[at + i] = dia * _k;
      }
    }

    final fl = Color.lerp(f ?? _glint, const Color(0xFFFFFFFF), 0.3)!;
    level(_gl, _glint, 1.5);
    level(_gh, _glint, 4.4, const [0.06, 0.11]);
    level(_fl, fl, 1.5);
    level(_fh, fl, 4.4, const [0.06, 0.11]);
    level(_dr, _drift, 1.6);
    level(_po, ShellMutationLook.paleGold, 1.7, const [0.3, 0.55, 0.8, 1.0]);
    for (var i = 0; i < 12; i++) {
      _liveColour[_tu + i] = _hue12(i.toDouble()).withValues(alpha: 0.92);
      _liveDia[_tu + i] = 1.6 * _k;
    }
  }

  void _compose() {
    final r = math.Random(seed);
    final w = _w, h = _h, p = _p;
    var area = 0.0, deepest = 0.0;
    for (final t in _depth) {
      area += t * 2;
      deepest = math.max(deepest, t);
    }
    // About one grain per 4 px² of bank: enough to read as sand, not so many
    // that the edge closes into a drawn line.
    var want = (area * 0.26).round().clamp(1200, 6000);
    if (reduced) want = (want * 0.6).round();
    if (loose) want = (want * 0.7).round();

    _s = Float32List(want);
    _d = Float32List(want);
    _hx = Float32List(want);
    _hy = Float32List(want);
    _ta = Float32List(want);
    _ts = Float32List(want);
    _len = Float32List(want);
    _d0 = Float32List(want);
    _wave = Float32List(want);
    _ph = Float32List(want);
    _aux = Float32List(want);
    _flow = Float32List(want);
    _dir = Int8List(want);
    _bucket = Uint8List(want);
    _role = Uint8List(want);
    final lively = <int>[];

    // Where it spills from: the left edge, level with the stage's floor.
    final source = 2 * w + h + (h - _sourceY.clamp(0.0, 1.0) * h);
    final reach = p / 2;
    var last = 0.0;
    var i = 0, tries = 0;
    while (i < want && tries < want * 30) {
      tries++;
      final s = r.nextDouble() * p;
      final t = _bank(s);
      if (r.nextDouble() * deepest > t) continue;

      // How far in: most of it at the edge, thinning inward, a few grains
      // strayed further (never off the dusted top).
      // (Only a little way: further in they land on the card's words.)
      final stray = s >= w && r.nextDouble() < 0.02;
      double d;
      int alpha;
      if (stray) {
        d = t + (2 + 10 * math.pow(r.nextDouble(), 2)) * _k;
        alpha = 2;
      } else {
        final u = math.pow(r.nextDouble(), 1.5).toDouble();
        d = -1.6 * _k + (t + 1.6 * _k) * u;
        alpha = u < 0.3 ? 0 : (u < 0.68 ? 1 : 2);
        // Some in shadow wherever they lie, so the edge reads as grains
        // rather than a drawn line.
        if (r.nextDouble() < 0.35) alpha = math.min(alpha + 1, 2);
      }
      _s[i] = s;
      _d[i] = d;
      _place(s, d);
      _hx[i] = _px;
      _hy[i] = _py;
      final v = r.nextDouble();
      final size = stray ? 0 : (v < 0.45 ? 0 : (v < 0.83 ? 1 : 2));

      // Its colour, and whether it does anything.
      var tone = 0;
      var role = _still;
      switch (colour) {
        case RimColour.element:
        case RimColour.gilded:
          tone = (math.pow(r.nextDouble(), 1.3) * 8).floor().clamp(0, 7);
        case RimColour.prismatic:
          final hue = (s / p * 12 + 2.6 * (_noise(s, 150, 17) - 0.5) + 12) % 12;
          tone = hue.floor().clamp(0, 11);
          _aux[i] = hue;
      }
      final roll = r.nextDouble();
      if (colour == RimColour.gilded && roll < 0.09) {
        role = _polish;
        _aux[i] = 0.7 * _px / w + 0.3 * _py / h;
      } else if (colour == RimColour.prismatic && roll < 0.07) {
        role = _turn;
      } else if (roll > 0.975) {
        role = _twinkle;
      } else if (_fleckTone >= 0 && roll > 0.93) {
        role = _fleckle;
        tone = _fleckTone;
      } else if (_looseTone >= 0 && roll > 0.85) {
        tone = _looseTone;
      }
      _role[i] = role;
      if (role != _still && !loose) lively.add(i);
      _bucket[i] = (tone * _alphas + alpha) * _sizes + size;

      // The pour: a front runs both ways round the rim from the source,
      // fast at first and slowing, and each grain is carried a little way
      // along behind it into its place. Those that settle near the source
      // come out of the stage instead, from further in.
      var delta = (s - source) % p;
      if (delta > p / 2) delta -= p;
      _dir[i] = delta >= 0 ? 1 : -1;
      final dist = delta.abs();
      final x =
          1 - math.pow(1 - (dist / reach).clamp(0.0, 1.0), 1 / 2.2).toDouble();
      final ta = 0.3 + 1.9 * x + 0.14 * r.nextDouble();
      final travel = 0.5 + 0.35 * r.nextDouble();
      _ta[i] = ta;
      _ts[i] = math.max(0.04 * r.nextDouble(), ta - travel);
      last = math.max(last, ta);
      _len[i] = math.min(dist, (40 + 120 * r.nextDouble()) * _k);
      final near = 1 - _smooth(0, 90 * _k, dist);
      _d0[i] = _lerp(
        d - (2 + 4 * r.nextDouble()) * _k,
        d + (16 + 28 * r.nextDouble()) * _k,
        near,
      );
      _wave[i] = (r.nextDouble() - 0.5) * 3 * _k;
      _ph[i] = r.nextDouble();
      // Alchemized: most of the river runs one way, a slower layer the other.
      _flow[i] = r.nextDouble() < 0.28 ? -0.6 : 1.0;
      i++;
    }
    _n = i;
    _lively = Int32List.fromList(lively);
    _pourEnd = last + 0.05;
    final drifters = loose ? 0 : (_n * 0.016).round().clamp(24, 80);
    _drifters = reduced ? (drifters * 0.6).round() : drifters;
  }

  // ── Painting ──────────────────────────────────────────────────────────

  /// [t] is seconds since the pour began.
  void paint(Canvas canvas, double t) {
    if (_n == 0 || t <= 0) return;
    if (t < _pourEnd) {
      _paintPour(canvas, t);
    } else if (loose) {
      _paintRiver(canvas, t - _pourEnd);
    } else {
      canvas.drawPicture(_rest ??= _record());
    }
    _paintLive(canvas, t);
  }

  void _moving(int i, double q) {
    final p = 1 - math.pow(1 - q, 3).toDouble();
    final s = _s[i] - _dir[i] * _len[i] * (1 - p);
    final e = p * p * (3 - 2 * p);
    final d = _d0[i] + (_d[i] - _d0[i]) * e + _wave[i] * math.sin(p * math.pi);
    _place(s, d);
  }

  void _paintPour(Canvas canvas, double t) {
    _main.clear();
    _trailA.clear();
    _trailB.clear();
    for (var i = 0; i < _n; i++) {
      final ts = _ts[i];
      if (t < ts) continue;
      final b = _bucket[i];
      final ta = _ta[i];
      if (t >= ta) {
        _main.add(b, _hx[i], _hy[i]);
        continue;
      }
      final span = ta - ts;
      final q = (t - ts) / span;
      _moving(i, q);
      // Comes up out of nothing over the first part of its run.
      final fade = q / 0.3;
      (fade >= 1 ? _main : (fade > 0.45 ? _trailA : _trailB)).add(b, _px, _py);
      if (fade < 1) continue;
      // A short trail, so the runs read as currents.
      final q1 = (t - 0.035 - ts) / span;
      if (q1 > 0) {
        _moving(i, q1);
        _trailA.add(b, _px, _py);
      }
      final q2 = (t - 0.07 - ts) / span;
      if (q2 > 0) {
        _moving(i, q2);
        _trailB.add(b, _px, _py);
      }
    }
    _draw(canvas, _main, 1);
    _draw(canvas, _trailA, 0.45);
    _draw(canvas, _trailB, 0.2);
  }

  void _draw(Canvas canvas, GrainBatch batch, double mult) {
    var b = 0;
    for (final tone in _tones) {
      for (var a = 0; a < _alphas; a++) {
        final c = tone.withValues(alpha: _alphaOf[a] * mult);
        for (var z = 0; z < _sizes; z++) {
          batch.draw(canvas, b++, _diaOf[z] * _k, c);
        }
      }
    }
  }

  ui.Picture _record() {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    _main.clear();
    for (var i = 0; i < _n; i++) {
      _main.add(_bucket[i], _hx[i], _hy[i]);
    }
    _draw(c, _main, 1);
    return rec.endRecording();
  }

  /// Alchemized: the whole bank running round, each grain keeping how far in
  /// it lies as a share of the bank wherever it has got to.
  void _paintRiver(Canvas canvas, double since) {
    _main.clear();
    final run = since * _smooth(0, 1.5, since);
    for (var i = 0; i < _n; i++) {
      final home = math.max(_bank(_s[i]), 0.5 * _k);
      final share = _d[i] / home;
      final speed =
          15 * _k * _flow[i] * (0.55 + 0.45 * (1 - share.clamp(0.0, 1.0)));
      final s = _s[i] + speed * run;
      _place(s, share * _bank(s));
      _main.add(_bucket[i], _px, _py);
    }
    _draw(canvas, _main, 1);
  }

  void _paintLive(Canvas canvas, double t) {
    _live.clear();
    final since = t - _pourEnd;
    // The gold's polish crosses the card, then rests.
    final sweep = (math.max(since, 0) % 5.0) / 2.6;
    final polishAt = -0.15 + 1.3 * sweep;
    for (final i in _lively) {
      final from = _ta[i] + 0.3;
      if (t < from) continue;
      final appear = _smooth(from, from + 0.9, t);
      final x = _hx[i], y = _hy[i];
      switch (_role[i]) {
        case _twinkle:
        case _fleckle:
          final ph = _ph[i];
          final period = _flicker ? 0.9 + 0.9 * ph : 2.8 + 3.2 * ph;
          final wave = math.sin(math.pi * 2 * (t / period + ph * 7));
          if (wave <= 0) break;
          final lit =
              (_flicker ? wave * wave * wave : math.pow(wave, 10)) * appear;
          if (lit < 0.08) break;
          final level = (lit * 4).floor().clamp(0, 3);
          final fl = _role[i] == _fleckle;
          _live.add((fl ? _fl : _gl) + level, x, y);
          if (level >= 2) _live.add((fl ? _fh : _gh) + level - 2, x, y);
        case _polish:
          if (sweep > 1) break;
          final off = (_aux[i] - polishAt) / 0.07;
          final lit = math.exp(-off * off) * appear;
          if (lit < 0.1) break;
          _live.add(_po + (lit * 4).floor().clamp(0, 3), x, y);
        case _turn:
          if (appear < 0.5) break;
          _live.add(
            _tu + ((_aux[i] + t * 0.6) % 12).floor().clamp(0, 11),
            x,
            y,
          );
      }
    }
    if (since > 0) _addDrifters(since);
    for (var b = 0; b < _liveBuckets; b++) {
      _live.draw(canvas, b, _liveDia[b], _liveColour[b]);
    }
  }

  /// A few loose grains doing what the element does. Each lives a few
  /// seconds and is born again somewhere new, worked out from the time
  /// alone.
  void _addDrifters(double since) {
    final all = _smooth(0, 1.6, since);
    for (var j = 0; j < _drifters; j++) {
      final life = 3.6 + 3.4 * _hash01(j, 9001);
      final tt = since + _hash01(j, 9002) * life;
      final c = (tt / life).floor();
      final tau = tt - c * life;
      final h1 = _hash01(j * 4 + 1, c), h2 = _hash01(j * 4 + 2, c);
      final h3 = _hash01(j * 4 + 3, c), h4 = _hash01(j * 4 + 4, c);
      double x, y, a, tx, ty;
      switch (_mode) {
        case _Drift.rise:
          final left = h1 < 0.58;
          final v = (7 + 9 * h3) * _k;
          y = _h * (0.45 + 0.53 * h2) - v * tau;
          final d = (1.2 + 6.5 * h4) * _k + 2.2 * _k * math.sin(tau * 1.5 + j);
          x = left ? d : _w - d;
          a =
              _smooth(0, 0.9, tau) *
              (1 - _smooth(life * 0.55, life, tau)) *
              _smooth(0, _h * 0.12, y);
          tx = 0;
          ty = 3 * _k;
        case _Drift.fall:
          final left = h1 < 0.5;
          final v = (5 + 7 * h3) * _k;
          y = _h * (0.06 + 0.5 * h2) + v * tau + 1.2 * _k * tau * tau;
          final d = (1.2 + 6.5 * h4) * _k + 1.4 * _k * math.sin(tau * 1.1 + j);
          x = left ? d : _w - d;
          a =
              _smooth(0, 0.9, tau) *
              (1 - _smooth(life * 0.6, life, tau)) *
              (1 - _smooth(_h * 0.9, _h, y));
          tx = 0;
          ty = -3 * _k;
        case _Drift.creep:
          final s = h2 * _p + (3.5 + 5 * h3) * _k * tau;
          final d = _bank(s) * (0.15 + 0.6 * h4);
          _place(s - 3 * _k, d);
          final bx = _px, by = _py;
          _place(s, d);
          x = _px;
          y = _py;
          tx = bx - x;
          ty = by - y;
          a = _smooth(0, 1.2, tau) * (1 - _smooth(life * 0.6, life, tau));
      }
      a *= all;
      if (a < 0.08) continue;
      final level = (a * 4).floor().clamp(0, 3);
      _live.add(_dr + level, x, y);
      if (level >= 1) _live.add(_dr + level - 1, x + tx, y + ty);
      if (level >= 2) _live.add(_dr + level - 2, x + 2 * tx, y + 2 * ty);
    }
  }

  // ── Noise ─────────────────────────────────────────────────────────────

  double _hash01(int a, int b) {
    var h = (a * 0x27d4eb2d) ^ (b * 0x165667b1) ^ (seed * 0x1b873593);
    h &= 0xffffffff;
    h = ((h ^ (h >> 15)) * 0x85ebca6b) & 0xffffffff;
    h = ((h ^ (h >> 13)) * 0xc2b2ae35) & 0xffffffff;
    h ^= h >> 16;
    return (h & 0xffffff) / 16777216.0;
  }

  /// Smooth value noise round the rim, [scale] px to a step. It closes on
  /// itself, so there is no seam where the rim starts.
  double _noise(double s, double scale, int salt) {
    final n = math.max(1, (_p / scale).round());
    final x = (s % _p) / _p * n;
    final i = x.floor();
    final f = x - i;
    final a = _hash01(salt, i % n), b = _hash01(salt, (i + 1) % n);
    return a + (b - a) * f * f * (3 - 2 * f);
  }
}

double _smooth(double e0, double e1, double x) {
  final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Wraps a card: once [pour] turns true, its rim fills with sand of the
/// specimen's [element] and stays that way. The sand is painted over the
/// card's edge and may lie a couple of pixels outside it, so leave the card
/// a little room.
class EssenceRim extends StatefulWidget {
  const EssenceRim({
    super.key,
    required this.element,
    required this.pour,
    required this.child,
    this.colour = RimColour.element,
    this.loose = false,
    this.fleck,
    this.looseLight = const Color(0xFFB9A7F5),
    this.sourceY = 0.35,
    this.seed = 0,
    this.reduced = false,
  });

  /// A creature type name ('Fire', 'lava'…).
  final String? element;
  final bool pour;
  final Widget child;
  final RimColour colour;
  final bool loose;
  final Color? fleck;
  final Color looseLight;

  /// Where on the left edge the sand spills from, 0..1 down it.
  final double sourceY;
  final int seed;
  final bool reduced;

  @override
  State<EssenceRim> createState() => _EssenceRimState();
}

class _EssenceRimState extends State<EssenceRim>
    with SingleTickerProviderStateMixin {
  late EssenceRimField _field = _build();
  late final Ticker _ticker = createTicker(_tick);
  final ValueNotifier<double> _clock = ValueNotifier(-1);

  EssenceRimField _build() => EssenceRimField(
    element: EssenceElement.of(widget.element),
    colour: widget.colour,
    loose: widget.loose,
    fleck: widget.fleck,
    looseLight: widget.looseLight,
    reduced: widget.reduced,
    seed: widget.seed,
  );

  @override
  void initState() {
    super.initState();
    if (widget.pour) _ticker.start();
  }

  @override
  void didUpdateWidget(EssenceRim old) {
    super.didUpdateWidget(old);
    if (old.element != widget.element ||
        old.colour != widget.colour ||
        old.loose != widget.loose ||
        old.fleck != widget.fleck ||
        old.seed != widget.seed ||
        old.reduced != widget.reduced) {
      _field.dispose();
      _field = _build();
    }
    if (widget.pour && !_ticker.isActive) _ticker.start();
  }

  void _tick(Duration elapsed) => _clock.value = elapsed.inMicroseconds / 1e6;

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _RimPainter(_field, _clock, widget.sourceY),
    child: widget.child,
  );
}

class _RimPainter extends CustomPainter {
  _RimPainter(this.field, this.clock, this.sourceY) : super(repaint: clock);

  final EssenceRimField field;
  final ValueListenable<double> clock;
  final double sourceY;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    if (t <= 0) return;
    field.layout(size, sourceY);
    field.paint(canvas, t);
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.field != field || old.sourceY != sourceY;
}
