// lib/widgets/fx/realm_sift.dart
//
// A REALM SIFTING AWAY. A picture of a whole field comes loose from one
// place outward on a ragged front, and every piece the front passes shrinks
// to a grain of its own colour and falls, carried sideways on one current
// (all the same way, by different amounts), thinning to nothing. Whatever
// is behind the picture shows through where it has gone.
//
// A share of the grains do not fall. They slow and hang in the air as
// lights of the colours they were ([RealmAir]), and stay there after the
// realm is gone, drifting, until something gathers them.
//
// Cheap, the way sand_passage.dart is: the field is rasterised once and drawn
// back through drawRawAtlas -- what is whole as one strip per run of a row,
// every loose piece as one sprite -- and the hanging lights are a second
// atlas of a single soft dot. The buffers are allocated once. Colours for
// the lights come from a thumbnail read once when the picture is made.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// A soft white dot, light at its heart and fading out: tinted, a grain
/// with its own glow, and no blur.
ui.Image _makeDot(double d) {
  final r = d / 2;
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawCircle(
    Offset(r, r),
    r,
    Paint()
      ..shader = ui.Gradient.radial(
        Offset(r, r),
        r,
        const [Color(0xFFFFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
        const [0.0, 0.3, 1.0],
      ),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(d.toInt(), d.toInt());
  picture.dispose();
  return image;
}

double _smooth(double a, double b, double x) {
  final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

/// One realm, pictured: the field at [pixelRatio], and a small copy of it
/// (RGBA, [thumbW] × [thumbH]) to read its colours from.
class RealmPicture {
  RealmPicture({
    required this.id,
    required this.image,
    required this.pixelRatio,
    required this.thumb,
    required this.thumbW,
    required this.thumbH,
  });

  final String id;
  final ui.Image image;
  final double pixelRatio;
  final Uint8List thumb;
  final int thumbW, thumbH;

  /// The field's colour at ([u], [v]) of the picture (0–1), 0xRRGGBB.
  int colourAt(double u, double v) {
    if (thumbW == 0 || thumbH == 0) return 0xFFFFFF;
    final x = (u * thumbW).floor().clamp(0, thumbW - 1);
    final y = (v * thumbH).floor().clamp(0, thumbH - 1);
    final j = (y * thumbW + x) * 4;
    return (thumb[j] << 16) | (thumb[j + 1] << 8) | thumb[j + 2];
  }

  /// Pictures [paint] (drawing a [size] screen) at [pixelRatio], with its
  /// thumbnail.
  static Future<RealmPicture> record(
    String id,
    Size size,
    double pixelRatio,
    void Function(Canvas canvas) paint,
  ) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..scale(pixelRatio);
    paint(canvas);
    final picture = rec.endRecording();
    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    picture.dispose();
    const tw = 64;
    final th = math.max(1, (tw * size.height / size.width).round());
    final small = ui.PictureRecorder();
    Canvas(small).drawImageRect(
      image,
      Offset.zero & Size(image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, tw.toDouble(), th.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    final thumbPicture = small.endRecording();
    final thumbImage = await thumbPicture.toImage(tw, th);
    thumbPicture.dispose();
    final data = await thumbImage.toByteData();
    thumbImage.dispose();
    return RealmPicture(
      id: id,
      image: image,
      pixelRatio: pixelRatio,
      thumb: data?.buffer.asUint8List() ?? Uint8List(0),
      thumbW: data == null ? 0 : tw,
      thumbH: data == null ? 0 : th,
    );
  }

  void dispose() => image.dispose();
}

/// A [RealmPicture] coming apart from [from] (screen px) over [frontTime]
/// seconds, on a screen of [size].
class RealmSift {
  RealmSift({
    required this.picture,
    required Size size,
    required Offset from,
    required this.frontTime,
    this.wind = 1,
    double keep = 0.035,
    int seed = 0,
  }) {
    final rng = math.Random(seed);
    final cell = math.max(4.5, math.sqrt(size.width * size.height / 10000));
    _cols = math.max(1, (size.width / cell).ceil());
    _rows = math.max(1, (size.height / cell).ceil());
    _cw = size.width / _cols;
    _ch = size.height / _rows;
    // A loose piece is about a grain and a half across.
    _grain = (1.6 / math.max(_cw, _ch)).clamp(0.12, 0.6);
    final n = _cols * _rows;
    _rt = Float32List(n);
    _life = Float32List(n);
    _g = Float32List(n);
    _up = Float32List(n);
    _drift = Float32List(n);
    _swayA = Float32List(n);
    _swayF = Float32List(n);
    _ph = Float32List(n);
    _spin = Float32List(n);
    _kept = Uint8List(n);
    _handed = Uint8List(n);
    _tone = Int32List(n);
    _xf = Float32List((n + _rows * 4) * 4);
    _src = Float32List((n + _rows * 4) * 4);
    _col = Int32List(n + _rows * 4);
    _mxf = Float32List(n * 4);
    _msrc = Float32List(n * 4);
    _mcol = Int32List(n);
    for (var j = 0; j < n; j++) {
      _msrc[j * 4 + 2] = _kDot;
      _msrc[j * 4 + 3] = _kDot;
    }
    _dot = _makeDot(_kDot);

    // How far the front has to go: to the farthest corner.
    var reach = 0.0;
    for (final c in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      reach = math.max(reach, (c - from).distance);
    }
    final p1 = rng.nextDouble() * 2 * math.pi;
    final p2 = rng.nextDouble() * 2 * math.pi;
    var gone = 0.0;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final i = r * _cols + c;
        final dx = (c + 0.5) * _cw - from.dx;
        final dy = (r + 0.5) * _ch - from.dy;
        final a = math.atan2(dy, dx);
        // One ragged front -- two slow waves round it and a touch of grit --
        // so the picture never shows a scatter of holes ahead of it.
        final tooth =
            0.07 * math.sin(3 * a + p1) +
            0.04 * math.sin(7 * a + p2) +
            (rng.nextDouble() - 0.5) * 0.02;
        final d = (math.sqrt(dx * dx + dy * dy) / reach + tooth).clamp(
          0.0,
          1.0,
        );
        // Slow to start, then the rest goes quickly.
        _rt[i] = frontTime * math.sqrt(d) + 0.02 * rng.nextDouble();
        gone = math.max(gone, _rt[i]);
        _life[i] = 1.1 + 0.7 * rng.nextDouble();
        _g[i] = size.height * (0.55 + 0.6 * rng.nextDouble());
        _up[i] = size.height * 0.05 * rng.nextDouble();
        _drift[i] = size.width * 0.05 * (0.4 + 0.9 * rng.nextDouble());
        _swayA[i] = _cw * (0.5 + 2.5 * rng.nextDouble());
        _swayF[i] = 2 + 3 * rng.nextDouble();
        _ph[i] = rng.nextDouble() * 2 * math.pi;
        _spin[i] = (rng.nextDouble() - 0.5) * 6;
        _kept[i] = rng.nextDouble() < keep ? 1 : 0;
        // A share of the falling grains carry a little light of their own
        // colour, so the realm pours away as lit sand, not dark chips.
        _tone[i] = rng.nextDouble() < 0.22
            ? _lifted(
                picture.colourAt((c + 0.5) / _cols, (r + 0.5) / _rows),
                0.3,
              )
            : -1;
      }
    }
    goneBy = gone;
    _size = size;
  }

  final RealmPicture picture;

  /// How long the front takes to reach the far corner.
  final double frontTime;

  /// Which way, and how hard, the current carries the grains: + to the
  /// right.
  final double wind;

  /// The last piece has let go by then.
  late final double goneBy;

  /// The last falling grain is gone by then.
  double get doneBy => goneBy + 1.9;

  /// How long a hanging grain is carried as a piece before it is a light.
  static const double handAt = 0.32;

  late final Size _size;
  late final int _cols, _rows;
  late final double _cw, _ch, _grain;
  late final Float32List _rt, _life, _g, _up, _drift, _swayA, _swayF;
  late final Float32List _ph, _spin;
  late final Uint8List _kept, _handed;
  late final Int32List _tone;
  late final Float32List _xf, _src, _mxf, _msrc;
  late final Int32List _col, _mcol;
  late final ui.Image _dot;

  static const double _kDot = 32;

  static final Paint _glintPaint = Paint()
    ..filterQuality = FilterQuality.low
    ..blendMode = BlendMode.plus;

  static final Paint _piecePaint = Paint()
    // Off, or the strips' shared edges each blend half a pixel and the
    // picture shows seams while it is whole.
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;

  /// Where piece [i] is [a] seconds after it let go.
  Offset _at(int i, double a) {
    final r = i ~/ _cols, c = i - r * _cols;
    final hx = (c + 0.5) * _cw, hy = (r + 0.5) * _ch;
    final u = (a / _life[i]).clamp(0.0, 1.0);
    final sway = _swayA[i] * math.sin(_swayF[i] * a + _ph[i]) * _smooth(0, 0.3, u);
    final x = hx + wind * _drift[i] * (a + 0.6 * a * a) + sway;
    if (_kept[i] == 1) {
      // Lifted a little and slowing, as if the air held it.
      final k = 1 - math.exp(-a / 0.35);
      return Offset(x, hy - _up[i] * 0.6 * k + 0.04 * _g[i] * a * a);
    }
    return Offset(x, hy - _up[i] * a + 0.5 * _g[i] * a * a);
  }

  /// Hands every hanging grain whose time has come to [air]: where it is,
  /// how it is moving and its colour.
  void handOver(double t, RealmAir air, int realm) {
    for (var i = 0; i < _kept.length; i++) {
      if (_kept[i] == 0 || _handed[i] == 1) continue;
      final a = t - _rt[i];
      if (a < handAt) continue;
      _handed[i] = 1;
      final p = _at(i, a);
      final q = _at(i, a - 1 / 60);
      final r = i ~/ _cols, c = i - r * _cols;
      air.add(
        p.dx,
        p.dy,
        (p.dx - q.dx) * 60,
        (p.dy - q.dy) * 60,
        picture.colourAt(
          (c + 0.5) / _cols,
          (r + 0.5) / _rows,
        ),
        realm,
      );
    }
  }

  /// Draws the picture [t] seconds into coming apart (whole before 0).
  void paint(Canvas canvas, double t) {
    final pr = picture.pixelRatio;
    var n = 0, m = 0;
    // What the front has not reached, row by row, as strips.
    if (t < goneBy) {
      for (var r = 0; r < _rows; r++) {
        var run = -1;
        for (var c = 0; c <= _cols; c++) {
          final i = r * _cols + c;
          if (c < _cols && t < _rt[i]) {
            if (run < 0) run = c;
            continue;
          }
          if (run < 0) continue;
          final j = n * 4;
          _xf[j] = 1 / pr;
          _xf[j + 1] = 0;
          _xf[j + 2] = run * _cw;
          _xf[j + 3] = r * _ch;
          _src[j] = run * _cw * pr;
          _src[j + 1] = r * _ch * pr;
          _src[j + 2] = c * _cw * pr;
          _src[j + 3] = (r + 1) * _ch * pr;
          _col[n] = 0xFFFFFFFF;
          n++;
          run = -1;
        }
      }
    }
    // Every piece that has let go, falling (or, hanging, until it is a
    // light in the air).
    for (var i = 0; i < _rt.length; i++) {
      final a = t - _rt[i];
      if (a < 0) continue;
      final kept = _kept[i] == 1;
      if (kept && a >= handAt) continue;
      final u = (a / _life[i]).clamp(0.0, 1.0);
      if (!kept && u >= 1) continue;
      final p = _at(i, a);
      if (p.dy > _size.height + 20) continue;
      // Down to a grain as soon as it is off; gone over its last half.
      final s = 1 - (1 - _grain) * _smooth(0, 0.07, u);
      final alpha = kept ? 1.0 : 1 - _smooth(0.45, 1, u);
      if (alpha <= 0.004) continue;
      final tone = _tone[i];
      if (tone >= 0 && !kept) {
        final g = alpha * 0.4 * _smooth(0.02, 0.12, u);
        if (g > 0.01) {
          final size = _cw * (0.75 + 0.35 * u);
          final k = m * 4;
          _mxf[k] = size / _kDot;
          _mxf[k + 1] = 0;
          _mxf[k + 2] = p.dx - size / 2;
          _mxf[k + 3] = p.dy - size / 2;
          _mcol[m] = ((g * 255).round().clamp(0, 255) << 24) | tone;
          m++;
        }
      }
      final r = i ~/ _cols, c = i - r * _cols;
      final sc = s / pr;
      final rot = _spin[i] * a;
      final cs = math.cos(rot) * sc, sn = math.sin(rot) * sc;
      final ax = _cw * pr / 2, ay = _ch * pr / 2;
      final j = n * 4;
      _xf[j] = cs;
      _xf[j + 1] = sn;
      _xf[j + 2] = p.dx - cs * ax + sn * ay;
      _xf[j + 3] = p.dy - sn * ax - cs * ay;
      _src[j] = c * _cw * pr;
      _src[j + 1] = r * _ch * pr;
      _src[j + 2] = (c + 1) * _cw * pr;
      _src[j + 3] = (r + 1) * _ch * pr;
      _col[n] = ((alpha * 255).round().clamp(0, 255) << 24) | 0xFFFFFF;
      n++;
    }
    if (n > 0) {
      canvas.drawRawAtlas(
        picture.image,
        Float32List.sublistView(_xf, 0, n * 4),
        Float32List.sublistView(_src, 0, n * 4),
        Int32List.sublistView(_col, 0, n),
        BlendMode.modulate,
        null,
        _piecePaint,
      );
    }
    if (m > 0) {
      canvas.drawRawAtlas(
        _dot,
        Float32List.sublistView(_mxf, 0, m * 4),
        Float32List.sublistView(_msrc, 0, m * 4),
        Int32List.sublistView(_mcol, 0, m),
        BlendMode.modulate,
        null,
        _glintPaint,
      );
    }
  }

  void dispose() => _dot.dispose();
}

/// [tone] (0xRRGGBB) carried [by] of the way to white.
int _lifted(int tone, double by) {
  int lift(int v) => (v + (255 - v) * by).round().clamp(0, 255);
  return (lift((tone >> 16) & 0xFF) << 16) |
      (lift((tone >> 8) & 0xFF) << 8) |
      lift(tone & 0xFF);
}

/// The grains the realms left hanging in the air: lights of the colours
/// they were, drifting on a slow current, until [gather] draws each realm's
/// into the place it is sent.
class RealmAir {
  RealmAir(this.capacity) {
    _x = Float32List(capacity);
    _y = Float32List(capacity);
    _vx = Float32List(capacity);
    _vy = Float32List(capacity);
    _born = Float32List(capacity);
    _size = Float32List(capacity);
    _ph = Float32List(capacity);
    _sx = Float32List(capacity);
    _sy = Float32List(capacity);
    _tx = Float32List(capacity);
    _ty = Float32List(capacity);
    _go = Float32List(capacity);
    _dur = Float32List(capacity);
    _curl = Float32List(capacity);
    _tone = Int32List(capacity);
    _realm = Uint8List(capacity);
    _cap = Uint8List(capacity);
    _xf = Float32List(capacity * 4);
    _src = Float32List(capacity * 4);
    _col = Int32List(capacity);
    for (var j = 0; j < capacity; j++) {
      _src[j * 4 + 2] = _kDot;
      _src[j * 4 + 3] = _kDot;
    }
    _dot = _makeDot(_kDot);
  }

  final int capacity;
  int _n = 0;
  double _t = 0;
  final _rng = math.Random(11);

  late final Float32List _x, _y, _vx, _vy, _born, _size, _ph;
  late final Float32List _sx, _sy, _tx, _ty, _go, _dur, _curl;
  late final Int32List _tone;
  late final Uint8List _realm, _cap;
  late final Float32List _xf, _src;
  late final Int32List _col;
  late final ui.Image _dot;

  static const double _kDot = 32;

  static final Paint _paint = Paint()
    ..filterQuality = FilterQuality.low
    // Light adding up on the dark.
    ..blendMode = BlendMode.plus;

  /// How many are hanging.
  int get length => _n;

  /// The air's own clock: how long it has been stepped.
  double get clock => _t;

  void add(double x, double y, double vx, double vy, int tone, int realm) {
    if (_n >= capacity) return;
    final i = _n++;
    _x[i] = x;
    _y[i] = y;
    _vx[i] = vx;
    _vy[i] = vy;
    _born[i] = _t;
    _size[i] = 2.2 + 1.6 * _rng.nextDouble();
    _ph[i] = _rng.nextDouble() * 2 * math.pi;
    _go[i] = -1;
    _realm[i] = realm;
    // Lifted a little toward the light, so a dark meadow's grain still
    // reads on the dark, and still its own colour.
    _tone[i] = _lifted(tone, 0.2);
  }

  /// Sends realm [realm]'s grains, starting at [at] (the air's clock),
  /// each to a point [target] picks for it.
  void gather(int realm, double at, Offset Function(math.Random) target) {
    for (var i = 0; i < _n; i++) {
      if (_realm[i] != realm || _go[i] >= 0) continue;
      final p = target(_rng);
      _tx[i] = p.dx;
      _ty[i] = p.dy;
      _go[i] = at + 0.9 * _rng.nextDouble();
      _dur[i] = 1.9 + 0.8 * _rng.nextDouble();
      _curl[i] = (0.25 + 0.5 * _rng.nextDouble());
    }
  }

  /// Every grain still in the air has been gathered, or none was sent.
  bool get settled {
    for (var i = 0; i < _n; i++) {
      if (_go[i] < 0 || _t < _go[i] + _dur[i]) return false;
    }
    return true;
  }

  void step(double dt, Size size) {
    _t += dt;
    final t = _t;
    for (var i = 0; i < _n; i++) {
      final go = _go[i];
      if (go >= 0 && t >= go) {
        // Set off from wherever the current had it.
        if (_cap[i] == 0) {
          _cap[i] = 1;
          _sx[i] = _x[i];
          _sy[i] = _y[i];
        }
        continue;
      }
      // A slow current, mostly sideways, lifting a little: hanging, not
      // falling.
      final x = _x[i], y = _y[i];
      final fx = math.sin(y * 0.012 + t * 0.35 + _ph[i]) * 14;
      final fy = math.cos(x * 0.009 - t * 0.3 + _ph[i]) * 9 - 3;
      final k = math.min(1.0, dt * 1.4);
      _vx[i] += (fx - _vx[i]) * k;
      _vy[i] += (fy - _vy[i]) * k;
      var nx = x + _vx[i] * dt, ny = y + _vy[i] * dt;
      // Held off the edges, softly.
      if (nx < 8) _vx[i] += (8 - nx) * dt * 2;
      if (nx > size.width - 8) _vx[i] -= (nx - size.width + 8) * dt * 2;
      if (ny < 8) _vy[i] += (8 - ny) * dt * 2;
      if (ny > size.height - 8) _vy[i] -= (ny - size.height + 8) * dt * 2;
      _x[i] = nx;
      _y[i] = ny;
    }
  }

  /// Draws them, all dimmed by [fade].
  void paint(Canvas canvas, {double fade = 1}) {
    if (_n == 0 || fade <= 0) return;
    final t = _t;
    var m = 0;
    for (var i = 0; i < _n; i++) {
      var x = _x[i], y = _y[i];
      // Lit as it comes off its piece.
      var alpha = 0.5 * _smooth(0, 0.35, t - _born[i]);
      var size = _size[i] * (0.9 + 0.15 * math.sin(t * 1.7 + _ph[i]));
      final go = _go[i];
      if (go >= 0 && t >= go) {
        final u = ((t - go) / _dur[i]).clamp(0.0, 1.0);
        final e = u * u * u * (u * (u * 6 - 15) + 10);
        final dx = _tx[i] - _sx[i], dy = _ty[i] - _sy[i];
        // Carried in curling, all the same way: a current, not spokes.
        final curl = _curl[i] * math.sin(math.pi * e);
        x = _sx[i] + dx * e - dy * curl;
        y = _sy[i] + dy * e + dx * curl;
        // Brighter on the way, and gone into its circle as it arrives.
        alpha *= (1 + 0.4 * math.sin(math.pi * u)) * (1 - _smooth(0.72, 1, u));
        size *= 1 - 0.35 * e;
      }
      alpha *= fade;
      if (alpha <= 0.01) continue;
      final sc = size / _kDot;
      final j = m * 4;
      _xf[j] = sc;
      _xf[j + 1] = 0;
      _xf[j + 2] = x - size / 2;
      _xf[j + 3] = y - size / 2;
      _col[m] = ((alpha * 255).round().clamp(0, 255) << 24) | _tone[i];
      m++;
    }
    if (m == 0) return;
    canvas.drawRawAtlas(
      _dot,
      Float32List.sublistView(_xf, 0, m * 4),
      Float32List.sublistView(_src, 0, m * 4),
      Int32List.sublistView(_col, 0, m),
      BlendMode.modulate,
      null,
      _paint,
    );
  }

  void dispose() => _dot.dispose();
}
