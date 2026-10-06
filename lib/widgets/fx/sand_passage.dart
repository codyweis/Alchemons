// lib/widgets/fx/sand_passage.dart
//
// GOING BETWEEN PLACES AS SAND.
//
//   A screen being left comes apart: an edge closes in from its rim, and
//   every piece it passes lets go, shrinks to a grain of its own colour and
//   is carried on a curling current to the middle, where the grains settle
//   into a slowly turning ball of sand. The ball is round, so the phone can
//   turn behind it unseen. Then it either pours itself into a circle on the
//   screen behind (leaving a wild field for its realm on the map) or comes
//   undone into the next screen, its pieces flying out from the middle and
//   growing back into the picture where they belong (going in).
//
//   What comes apart may be the whole screen or just a circle of it: a
//   realm's circle on the map, the window home opens onto the home biome.
//
// Cheap, the way card_dissolve.dart is: each screen is rasterised once and
// drawn back through drawRawAtlas -- what is whole as one strip per run of a
// row, every loose piece as one sprite -- and the element's light is a
// second atlas of a single soft dot. Nothing is read back off the GPU, no
// blur, and the per-frame buffers are allocated once.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/widgets.dart';

/// Which way a [SandPicture]'s pieces go.
enum SandWay {
  /// From the picture into the ball, the rim first.
  gather,

  /// Out of the ball into the picture, the middle first.
  assemble,
}

/// The ball every passage goes through: in the middle of the screen, turning.
abstract final class SandBall {
  /// Its radius, in the screen's short side.
  static const double radius = 0.17;

  /// How fast it turns, rad/s, and how far its axis leans back.
  static const double turn = 0.85;
  static const double tilt = 0.42;
}

/// A picture of a screen (or of a circle on one) cut into pieces, each with
/// its place in the ball and its way there or back.
class SandPicture {
  /// [image] shows [size] (logical px) at [pixelRatio]. [origin] is where
  /// its top-left sat on the screen and [screenCentre] the screen's middle
  /// then, both global: pieces keep their places relative to the middle, so
  /// the picture follows the phone round if it turns. [circle] (global)
  /// cuts out just that circle; without it the whole picture is used.
  SandPicture({
    required this.image,
    required this.pixelRatio,
    required Size size,
    required this.way,
    Offset origin = Offset.zero,
    Offset? screenCentre,
    Rect? circle,
    String? element,
    int seed = 0,
  }) {
    final centre = screenCentre ?? origin + size.center(Offset.zero);
    // The part of the picture that is cut: the circle's square, or all of it.
    final local = circle?.shift(-origin) ?? Offset.zero & size;
    final box = local.intersect(Offset.zero & size);
    _box = box.isEmpty ? Offset.zero & size : box;
    final round = circle != null;
    final target = round ? 3000.0 : 8000.0;
    final cell = math.max(
      round ? 2.6 : 4.5,
      math.sqrt(_box.width * _box.height / target),
    );
    _cols = math.max(1, (_box.width / cell).ceil());
    _rows = math.max(1, (_box.height / cell).ceil());
    _cw = _box.width / _cols;
    _ch = _box.height / _rows;
    // A loose piece is about a grain and a half across.
    _grain = (1.5 / math.max(_cw, _ch)).clamp(0.12, 0.6);
    final n = _cols * _rows;
    _in = Uint8List(n);
    _hx = Float32List(n);
    _hy = Float32List(n);
    _rt = Float32List(n);
    _life = Float32List(n);
    _swing = Float32List(n);
    _spin = Float32List(n);
    _lat = Float32List(n);
    _lon = Float32List(n);
    _deep = Float32List(n);
    _lw = Float32List(n);
    _ll = Float32List(n);
    _lr = Float32List(n);
    _la = Float32List(n);
    _mote = Int32List(n);

    final rng = math.Random(seed);
    final ramp = essenceRamp(EssenceElement.of(element));
    final p1 = rng.nextDouble() * 2 * math.pi;
    final p2 = rng.nextDouble() * 2 * math.pi;
    final hw = _box.width / 2, hh = _box.height / 2;
    final rimMax = round ? 1.0 : math.sqrt2;
    final gather = way == SandWay.gather;
    var motes = 0;
    var gone = 0.0, done = 0.0;
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final i = r * _cols + c;
        final x = (c + 0.5) * _cw - hw;
        final y = (r + 0.5) * _ch - hh;
        final rim = math.sqrt((x / hw) * (x / hw) + (y / hh) * (y / hh));
        if (round && rim > 1) continue;
        _in[i] = 1;
        // From the middle of the screen: where the ball is.
        _hx[i] = origin.dx + _box.left + (c + 0.5) * _cw - centre.dx;
        _hy[i] = origin.dy + _box.top + (r + 0.5) * _ch - centre.dy;
        // One ragged front -- two slow waves round it and a touch of grit
        // -- so the picture never shows a scatter of holes ahead of it.
        final a = math.atan2(y, x);
        final tooth =
            0.09 * math.sin(2 * a + p1) +
            0.05 * math.sin(5 * a + p2) +
            (rng.nextDouble() - 0.5) * 0.024;
        final out = (rim / rimMax + tooth).clamp(0.0, 1.0);
        if (gather) {
          // The rim first; slow to start, then the middle goes quickly.
          final span = round ? 0.38 : 0.5;
          _rt[i] = span * math.sqrt(1 - out) + 0.012 * rng.nextDouble();
          _life[i] = 0.5 + 0.22 * rng.nextDouble();
        } else {
          // The middle first, the picture opening out to its rim on one
          // front: timed by when it ARRIVES, so nothing lands ahead of its
          // neighbours and the picture fills in whole behind the front.
          _life[i] = 0.45 + 0.2 * rng.nextDouble();
          _rt[i] = 0.66 + 0.55 * out + 0.012 * rng.nextDouble() - _life[i];
        }
        // All curl the same way, by different amounts: a current, not
        // spokes.
        _swing[i] = 0.12 + 0.22 * rng.nextDouble();
        _spin[i] = (rng.nextDouble() - 0.5) * 7;
        // A place in the ball: most on its skin, some inside it.
        final z = 2 * rng.nextDouble() - 1;
        _lat[i] = math.asin(z);
        _lon[i] = rng.nextDouble() * 2 * math.pi;
        final inside = rng.nextDouble();
        _deep[i] = inside < 0.82 ? 0.9 + 0.1 * inside : 0.35 + 0.6 * inside;
        // Where it lands in a circle it pours into, and when it sets off.
        _lw[i] = 0.07 * rng.nextDouble();
        _ll[i] = 0.42 + 0.2 * rng.nextDouble();
        _lr[i] = math.sqrt(rng.nextDouble());
        _la[i] = rng.nextDouble() * 2 * math.pi;
        gone = math.max(gone, _rt[i]);
        done = math.max(done, _rt[i] + _life[i]);
        if (rng.nextDouble() < _kMoteShare) {
          final tone = Color.lerp(ramp[2], ramp[3], rng.nextDouble())!;
          _mote[i] = tone.toARGB32() & 0xFFFFFF;
          motes++;
        } else {
          _mote[i] = -1;
        }
      }
    }
    goneBy = gone;
    doneBy = done;
    _xf = Float32List((n + _rows * 4) * 4);
    _src = Float32List((n + _rows * 4) * 4);
    _col = Int32List(n + _rows * 4);
    _mxf = Float32List(motes * 4);
    _msrc = Float32List(motes * 4);
    _mcol = Int32List(motes);
    for (var j = 0; j < motes; j++) {
      _msrc[j * 4 + 2] = _kDot;
      _msrc[j * 4 + 3] = _kDot;
    }
    _dot = _makeDot();
    _circleAt = round
        ? Offset(
            origin.dx + _box.center.dx - centre.dx,
            origin.dy + _box.center.dy - centre.dy,
          )
        : null;
    _circleR = round ? _box.shortestSide / 2 : 0;
    _gx = origin.dx + _box.left - centre.dx;
    _gy = origin.dy + _box.top - centre.dy;
  }

  /// The screen as it stood, at [pixelRatio].
  final ui.Image image;
  final double pixelRatio;
  final SandWay way;

  /// The share of pieces that also carry a grain of the element's light.
  static const double _kMoteShare = 0.2;

  /// Gathering, the last piece has let go of the picture by then; going
  /// out, the last has left the ball.
  late final double goneBy;

  /// The last piece is in the ball (gathering), or back in its place.
  late final double doneBy;

  /// From the pour setting off to the last grain gone.
  static const double pourTime = _kPour + 0.07 + 0.62;

  /// How long the ball takes to unspool into a circle, from the side facing
  /// it to the far side: it pours out as a stream, not as a lump.
  static const double _kPour = 0.5;

  late final Rect _box;
  late final int _cols, _rows;
  late final double _cw, _ch, _grain;

  /// A cut-out circle's centre from the screen's middle, and its radius.
  late final Offset? _circleAt;
  late final double _circleR;

  /// The cut grid's top-left corner, from the screen's middle.
  late final double _gx, _gy;

  // Per piece: whether it is cut at all, its place (from the screen's
  // middle), when it goes and how long it travels, how it curls and turns,
  // its place in the ball, and its way into a circle.
  late final Uint8List _in;
  late final Float32List _hx, _hy, _rt, _life, _swing, _spin;
  late final Float32List _lat, _lon, _deep, _lw, _ll, _lr, _la;

  /// The element's light it carries (0xRRGGBB), or -1 for none.
  late final Int32List _mote;

  late final Float32List _xf, _src, _mxf, _msrc;
  late final Int32List _col, _mcol;
  late final ui.Image _dot;

  static const double _kDot = 32;

  static final Paint _piecePaint = Paint()
    // Off, or the strips' shared edges each blend half a pixel and the
    // picture shows seams while it is whole.
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  static final Paint _motePaint = Paint()
    ..filterQuality = FilterQuality.low
    // Light adding up on the dark.
    ..blendMode = BlendMode.plus;
  static final Paint _voidPaint = Paint();

  /// A soft white dot, light at its heart and fading out: tinted, a grain
  /// with its own glow, and no blur.
  static ui.Image _makeDot() {
    const r = _kDot / 2;
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawCircle(
      const Offset(r, r),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(r, r),
          r,
          const [Color(0xFFFFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
          const [0.0, 0.3, 1.0],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(_kDot.toInt(), _kDot.toInt());
    picture.dispose();
    return image;
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  static double _smoother(double t) => t * t * t * (t * (t * 6 - 15) + 10);

  /// The black under a cut-out circle while it comes apart, so what it was
  /// cut from does not show through the holes. Nothing for a whole screen.
  void paintHole(Canvas canvas, Size size, Color ground) {
    final at = _circleAt;
    if (at == null) return;
    _voidPaint.color = ground;
    canvas.drawCircle(size.center(Offset.zero) + at, _circleR, _voidPaint);
  }

  // Per frame, while the loop runs: where piece i sits in the ball, and how
  // much of it faces the player.
  double _bx = 0, _by = 0, _face = 0;
  void _ball(int i, double turn, double ct, double st) {
    final lon = _lon[i] + turn;
    final cl = math.cos(_lat[i]);
    final x = cl * math.sin(lon);
    final y0 = math.sin(_lat[i]);
    final z0 = cl * math.cos(lon);
    _bx = x;
    _by = y0 * ct - z0 * st;
    _face = 0.5 + 0.5 * (y0 * st + z0 * ct);
  }

  int _strip(int n, int r, int from, int to, double x0, double y0, int col) {
    final pr = pixelRatio;
    final j = n * 4;
    _xf[j] = 1 / pr;
    _xf[j + 1] = 0;
    _xf[j + 2] = x0 + from * _cw;
    _xf[j + 3] = y0 + r * _ch;
    _src[j] = (_box.left + from * _cw) * pr;
    _src[j + 1] = (_box.top + r * _ch) * pr;
    _src[j + 2] = (_box.left + to * _cw) * pr;
    _src[j + 3] = (_box.top + (r + 1) * _ch) * pr;
    _col[n] = col;
    return n + 1;
  }

  int _piece(
    int n,
    int i,
    double px,
    double py,
    double s,
    double rot,
    double alpha,
  ) {
    final pr = pixelRatio;
    final r = i ~/ _cols, c = i - r * _cols;
    final sc = s / pr;
    final cs = rot == 0 ? sc : math.cos(rot) * sc;
    final sn = rot == 0 ? 0.0 : math.sin(rot) * sc;
    final ax = _cw * pr / 2, ay = _ch * pr / 2;
    final j = n * 4;
    _xf[j] = cs;
    _xf[j + 1] = sn;
    _xf[j + 2] = px - cs * ax + sn * ay;
    _xf[j + 3] = py - sn * ax - cs * ay;
    _src[j] = (_box.left + c * _cw) * pr;
    _src[j + 1] = (_box.top + r * _ch) * pr;
    _src[j + 2] = (_box.left + (c + 1) * _cw) * pr;
    _src[j + 3] = (_box.top + (r + 1) * _ch) * pr;
    _col[n] = ((alpha * 255).round().clamp(0, 255) << 24) | 0xFFFFFF;
    return n + 1;
  }

  int _glint(int m, int i, double px, double py, double size, double g) {
    final tone = _mote[i];
    if (g <= 0.01 || tone < 0) return m;
    final sc = size / _kDot;
    final j = m * 4;
    _mxf[j] = sc;
    _mxf[j + 1] = 0;
    _mxf[j + 2] = px - size / 2;
    _mxf[j + 3] = py - size / 2;
    _mcol[m] = ((g * 0.7 * 255).round().clamp(0, 255) << 24) | tone;
    return m + 1;
  }

  void _flush(Canvas canvas, int n, int m) {
    if (n > 0) {
      canvas.drawRawAtlas(
        image,
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
        _motePaint,
      );
    }
  }

  /// Draws a [SandWay.gather] picture [t] seconds into coming apart, on a
  /// screen of [size].
  ///
  /// [pourAt] is when the ball set off into [home] (a circle on the screen,
  /// in this canvas's coordinates; null: it thins out where it is). [fade]
  /// dims the ball, for when the next screen is coming out of it.
  void paintGather(
    Canvas canvas,
    Size size,
    double t, {
    double? pourAt,
    Rect? home,
    double fade = 1,
  }) {
    assert(way == SandWay.gather);
    final l = pourAt == null ? -1.0 : t - pourAt;
    final cx = size.width / 2, cy = size.height / 2;
    final ballR = SandBall.radius * size.shortestSide;
    final turn = SandBall.turn * t;
    final ct = math.cos(SandBall.tilt), st = math.sin(SandBall.tilt);
    final hc = home?.center;
    final hr = home == null ? 0.0 : home.width / 2 * 0.92;
    // Which side of the ball faces home: that side pours first.
    var hdx = 0.0, hdy = 0.0;
    if (hc != null) {
      final dx = hc.dx - cx, dy = hc.dy - cy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > 1) {
        hdx = dx / d;
        hdy = dy / d;
      }
    }
    var n = 0, m = 0;

    // What the edge has not reached, row by row, as strips -- under the
    // sand that blows across it.
    if (t < goneBy) {
      final xs = cx + _gx, ys = cy + _gy;
      for (var r = 0; r < _rows; r++) {
        var run = -1;
        for (var c = 0; c <= _cols; c++) {
          final i = r * _cols + c;
          if (c < _cols && _in[i] == 1 && t < _rt[i]) {
            if (run < 0) run = c;
            continue;
          }
          if (run < 0) continue;
          n = _strip(n, r, run, c, xs, ys, 0xFFFFFFFF);
          run = -1;
        }
      }
    }

    for (var i = 0; i < _in.length; i++) {
      if (_in[i] == 0 || t < _rt[i]) continue;
      final a = t - _rt[i];
      final u = (a / _life[i]).clamp(0.0, 1.0);
      // Off at once and slowing into the ball: the edge leaves black
      // behind it, never a field of loose tiles.
      final e = 1 - (1 - u) * (1 - u) * (1 - u);
      _ball(i, turn, ct, st);
      final bx = _bx, by = _by, face = _face;
      final rad = ballR * _deep[i];
      var px = cx + bx * rad, py = cy + by * rad;
      if (u < 1) {
        // On its way in from the picture, curling.
        final fx = cx + _hx[i], fy = cy + _hy[i];
        final dx = px - fx, dy = py - fy;
        final curl = _swing[i] * math.sin(math.pi * e);
        px = fx + dx * e - dy * curl;
        py = fy + dy * e + dx * curl;
      }
      // Down to a grain as soon as it is off.
      var s = 1 - (1 - _grain) * _smooth(0, 0.16, u);
      // Its far side dimmer and smaller, so the ball reads round.
      var alpha = (1 - (1 - (0.35 + 0.65 * face)) * e) * fade;
      s *= 1 - 0.25 * (1 - face) * e;
      var glow = _smooth(0.04, 0.3, u) * (1 - 0.6 * _smooth(0.6, 1, u));
      if (l >= 0) {
        // Pouring out of the ball: the side facing home goes first.
        final lu =
            ((l - _kPour * (0.5 - 0.5 * (bx * hdx + by * hdy)) - _lw[i]) /
                    _ll[i])
                .clamp(0.0, 1.0);
        if (lu >= 1) continue;
        final le = _smoother(lu);
        if (hc != null) {
          final qx = hc.dx + hr * _lr[i] * math.cos(_la[i]);
          final qy = hc.dy + hr * _lr[i] * math.sin(_la[i]);
          final dx = qx - px, dy = qy - py;
          final curl = (0.18 + 0.5 * _swing[i]) * math.sin(math.pi * le);
          px += dx * le - dy * curl;
          py += dy * le + dx * curl;
          alpha *= 1 - _smooth(0.55, 1, lu);
        } else {
          px += (px - cx) * 0.35 * le;
          py += (py - cy) * 0.35 * le;
          alpha *= 1 - _smooth(0.1, 1, lu);
        }
        s *= 1 - 0.3 * le;
        glow += 0.3 * _smooth(0, 0.3, lu);
      }
      if (alpha > 0.004) {
        n = _piece(n, i, px, py, s, _spin[i] * a * (1 - e) * 0.6, alpha);
      }
      // In the ball the light settles to a low, steady glow.
      final g = math.max(glow, 0.32 * e * face) * (l < 0 ? fade : alpha);
      m = _glint(m, i, px, py, _cw * (1.7 - 0.9 * e), g);
    }
    _flush(canvas, n, m);
  }

  /// Draws a [SandWay.assemble] picture coming out of the ball: [t] is the
  /// passage's own clock (the ball's turn) and [since] how long ago the
  /// ball began to come undone. [opacity] fades the finished picture off
  /// the screen it stands in for.
  void paintAssemble(
    Canvas canvas,
    Size size,
    double t,
    double since, {
    double opacity = 1,
  }) {
    assert(way == SandWay.assemble);
    final cx = size.width / 2, cy = size.height / 2;
    final ballR = SandBall.radius * size.shortestSide;
    final turn = SandBall.turn * t;
    final ct = math.cos(SandBall.tilt), st = math.sin(SandBall.tilt);
    // Its grains come into the ball as the old ones go out of it.
    final into = _smooth(0, 0.3, since);
    var n = 0, m = 0;

    // What has landed, row by row, as strips.
    final x0 = cx + _gx, y0 = cy + _gy;
    final strip = ((opacity * 255).round().clamp(0, 255) << 24) | 0xFFFFFF;
    for (var r = 0; r < _rows; r++) {
      var run = -1;
      for (var c = 0; c <= _cols; c++) {
        final i = r * _cols + c;
        if (c < _cols && _in[i] == 1 && since >= _rt[i] + _life[i]) {
          if (run < 0) run = c;
          continue;
        }
        if (run < 0) continue;
        n = _strip(n, r, run, c, x0, y0, strip);
        run = -1;
      }
    }

    if (since < doneBy) {
      for (var i = 0; i < _in.length; i++) {
        if (_in[i] == 0) continue;
        final a = since - _rt[i];
        final u = (a / _life[i]).clamp(0.0, 1.0);
        if (u >= 1) continue;
        final e = _smoother(u);
        _ball(i, turn, ct, st);
        final face = _face;
        final rad = ballR * _deep[i];
        final bx = cx + _bx * rad, by = cy + _by * rad;
        final fx = cx + _hx[i], fy = cy + _hy[i];
        final dx = fx - bx, dy = fy - by;
        // Curling out the way the ball turns, as the gathering curled in.
        final curl = -_swing[i] * math.sin(math.pi * e);
        final px = bx + dx * e - dy * curl;
        final py = by + dy * e + dx * curl;
        // A grain until it is nearly home, then its piece grows back.
        final s =
            (_grain + (1 - _grain) * _smooth(0.88, 1, u)) *
            (1 - 0.25 * (1 - face) * (1 - e));
        final inBall = 0.35 + 0.65 * face;
        final alpha = (inBall + (1 - inBall) * e) * into;
        if (alpha > 0.004) {
          n = _piece(n, i, px, py, s, _spin[i] * (1 - e) * 0.3, alpha);
        }
        final glow = u > 0 ? 0.75 * math.sin(math.pi * u) : 0.32 * face;
        m = _glint(m, i, px, py, _cw * (0.8 + 0.9 * e), glow * into);
      }
    }
    _flush(canvas, n, m);
  }

  void dispose() {
    image.dispose();
    _dot.dispose();
  }
}
