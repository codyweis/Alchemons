// lib/widgets/fx/sand_passage.dart
//
// GOING BETWEEN PLACES AS SAND.
//
//   A screen being left comes apart: an edge closes in from its rim, and
//   every piece it passes lets go, shrinks to a grain of its own colour and
//   is carried on a curling current to the middle, where the grains settle
//   into a slowly turning ball of sand. The ball is round, so the phone can
//   turn behind it unseen. Then it either pours itself into a circle on the
//   screen behind (leaving a wild field for its realm on the map) or opens
//   onto the next screen (going in): a hole widens from its middle with the
//   live screen behind showing through it, and the sand is carried out on
//   the hole's rim, thinning away before it reaches the edges.
//
//   A whole screen being left stays live while it goes: the dark closes in
//   on it as the same hole, shutting, and the screen crumbles into its
//   grains just ahead of the dark's edge.
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

/// The ball every passage goes through: in the middle of the screen, turning.
abstract final class SandBall {
  /// Its radius, in the screen's short side.
  static const double radius = 0.17;

  /// How fast it turns, rad/s, and how far its axis leans back.
  static const double turn = 0.85;
  static const double tilt = 0.42;
}

/// The hole in the dark a passage looks through: opening out of the ball
/// onto the next screen ([SandPicture.paintOpen]), or closing in on a
/// screen being left. Shared by what draws the dark round it and what
/// draws the sand at its edge.
abstract final class SandHole {
  /// From the first grain moving to the last one gone.
  static const double time = _widen + 0.05;

  /// How long the hole takes to widen past the corners, and how much of
  /// that it stays shut while the ball kindles.
  static const double _widen = 1.85, _shut = 0.12;

  /// How far open the hole is [since] seconds in: 0 shut, 1 past the
  /// corners. Shut a moment as the ball kindles, then easing open.
  static double open(double since) {
    final u = ((since - _shut) / (_widen - _shut)).clamp(0.0, 1.0);
    return u * u * (3 - 2 * u);
  }

  /// The hole's soft edge at [open], from clear to dark: wider as it opens.
  static double feather(Size size, double open) =>
      size.shortestSide * (0.12 + 0.3 * open);

  /// The hole's clear radius at [open]: shut (its soft edge too) at 0, the
  /// whole screen clear at 1.
  static double radius(Size size, double open) {
    final shut = feather(size, 0);
    final past = size.center(Offset.zero).distance + shut;
    return -shut + (past + shut) * open;
  }

  /// The hole's middle at [open]: drifting a little off the screen's, so it
  /// is not a lens opening square on.
  static Offset centre(Size size, double open, double lean) =>
      size.center(Offset.zero) +
      Offset.fromDirection(lean, size.shortestSide * 0.05 * open);

  /// Leaving, the hole shuts from the corners in this long.
  static const double closeTime = 0.5;

  /// How open the hole is [t] seconds into leaving a screen of [size]: its
  /// clear edge at the corners at first, so the dark starts in at once,
  /// and 0 shut. Slow to start, then the middle goes quickly.
  static double closing(Size size, double t) {
    final u = (t / closeTime).clamp(0.0, 1.0);
    return _cornered(size) * (1 - u * u);
  }

  /// When, leaving a screen of [size], the hole's clear edge reaches a
  /// point it is [open] at ([openWhere]).
  static double closesAt(Size size, double open) =>
      closeTime * math.sqrt(1 - (open / _cornered(size)).clamp(0.0, 1.0));

  /// Leaving, the hole's edge stays as tight as it is shut: the screen is
  /// seen to crumble at it, not shed sand well inside a soft dark.
  static double closingEdge(Size size) => feather(size, 0);

  /// How open the hole is with its clear edge on the corners.
  static double _cornered(Size size) =>
      openWhere(size, size.center(Offset.zero).distance);

  /// How open the hole is when its clear edge is [d] from its middle.
  static double openWhere(Size size, double d) {
    final shut = feather(size, 0);
    final past = size.center(Offset.zero).distance + shut;
    return ((d + shut) / (past + shut)).clamp(0.0, 1.0);
  }
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
    _band = Float32List(n);
    _lag = Float32List(n);
    _thin = Float32List(n);
    _ox = Float32List(n);
    _oy = Float32List(n);
    _tone = Int32List(n);

    final rng = math.Random(seed);
    final ramp = essenceRamp(EssenceElement.of(element));
    final p1 = rng.nextDouble() * 2 * math.pi;
    final p2 = rng.nextDouble() * 2 * math.pi;
    final hw = _box.width / 2, hh = _box.height / 2;
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
        final a = math.atan2(y, x);
        final double out;
        if (round) {
          // One ragged front -- two slow waves round it and a touch of
          // grit -- so the circle never shows a scatter of holes ahead of
          // it.
          final tooth =
              0.09 * math.sin(2 * a + p1) +
              0.05 * math.sin(5 * a + p2) +
              (rng.nextDouble() - 0.5) * 0.024;
          out = (rim + tooth).clamp(0.0, 1.0);
        } else {
          // Just ahead of the dark closing in on it (SandHole.closing),
          // raggedly: the screen still shows where a piece lifts off, so
          // one that goes early leaves no hole, and none goes late.
          final d = math.sqrt(_hx[i] * _hx[i] + _hy[i] * _hy[i]);
          final early =
              0.018 * (1 + math.sin(2 * a + p1)) +
              0.01 * (1 + math.sin(5 * a + p2)) +
              0.008 * rng.nextDouble();
          out = SandHole.openWhere(size, d) + early;
        }
        // The rim first; slow to start, then the middle goes quickly.
        _rt[i] =
            (round
                ? 0.38 * math.sqrt(1 - out)
                : SandHole.closesAt(size, out)) +
            0.012 * rng.nextDouble();
        _life[i] = 0.5 + 0.22 * rng.nextDouble();
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
        } else {
          _mote[i] = -1;
        }
      }
    }
    goneBy = gone;
    doneBy = done;
    // How each rides the rim of the hole the ball opens into: how far out
    // of the rim's line (mostly just outside it, a few well out), how far
    // behind it (a few trailing well inside, over what is showing), and
    // how soon it thins away.
    for (var i = 0; i < n; i++) {
      final b = rng.nextDouble();
      _band[i] = -0.03 + 0.22 * b * b;
      final l = rng.nextDouble();
      _lag[i] = l < 0.9 ? 0.12 * l : 0.12 + 0.18 * rng.nextDouble();
      _thin[i] = 0.32 + 0.3 * rng.nextDouble();
      _tone[i] = _mote[i] >= 0
          ? _mote[i]
          : Color.lerp(ramp[2], ramp[3], rng.nextDouble())!.toARGB32() &
                0xFFFFFF;
    }
    _lean = rng.nextDouble() * 2 * math.pi;
    _bank = rng.nextDouble() * 2 * math.pi;
    _xf = Float32List((n + _rows * 4) * 4);
    _src = Float32List((n + _rows * 4) * 4);
    _col = Int32List(n + _rows * 4);
    // Room for every piece's light: opening, all of them carry one.
    _mxf = Float32List(n * 4);
    _msrc = Float32List(n * 4);
    _mcol = Int32List(n);
    for (var j = 0; j < n; j++) {
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

  /// The share of pieces that also carry a grain of the element's light.
  static const double _kMoteShare = 0.2;

  /// Gathering, the last piece has let go of the picture by then; going
  /// out, the last has left the ball.
  late final double goneBy;

  /// The last piece is in the ball.
  late final double doneBy;

  /// Which way the hole the ball opens into leans off the middle, for
  /// [SandHole.centre].
  double get lean => _lean;
  late final double _lean;

  /// Where round the hole's rim the sand banks thickest.
  late final double _bank;

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

  // Per piece, opening: how far out of the rim's line it rides, how far
  // behind it, how soon it thins away, and which way it was carried out
  // (fixed the moment the opening began, so nothing swaps sides as the
  // ball's turn dies away).
  late final Float32List _band, _lag, _thin, _ox, _oy;
  double? _openedAt;

  /// The element's light every piece turns to once the rim has it
  /// (0xRRGGBB): the screen's own colours would show as dark chips over
  /// the bright one opening behind.
  late final Int32List _tone;

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

  int _glint(
    int m,
    int i,
    double px,
    double py,
    double size,
    double g, {
    bool all = false,
  }) {
    final tone = all ? _tone[i] : _mote[i];
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

  /// Draws the picture [t] seconds into coming apart, on a screen of
  /// [size].
  ///
  /// [pourAt] is when the ball set off into [home] (a circle on the screen,
  /// in this canvas's coordinates; null: it thins out where it is). [fade]
  /// dims the ball, for when it goes out while the phone turns. [live]: the
  /// screen itself shows where nothing has left yet, through the closing
  /// [SandHole], so only what has let go is drawn.
  void paintGather(
    Canvas canvas,
    Size size,
    double t, {
    double? pourAt,
    Rect? home,
    double fade = 1,
    bool live = false,
  }) {
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
    if (!live && t < goneBy) {
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

  /// Draws the ball, gathered, opening onto the screen behind: [t] is the
  /// passage's own clock (the ball's turn) and [since] how long ago the
  /// opening began. The hole is [SandHole]'s; draw the dark round it
  /// first. Its widening rim sweeps the sand up off the ball as it reaches
  /// it and carries it out, curling, until it thins away.
  void paintOpen(Canvas canvas, Size size, double t, double since) {
    final ballR = SandBall.radius * size.shortestSide;
    final ct = math.cos(SandBall.tilt), st = math.sin(SandBall.tilt);
    final from = t - since;
    final opened = _openedAt;
    if (opened == null || (opened - from).abs() > 1e-6) {
      // Which way each is carried out: from where it sat in the ball as
      // the opening began, nudged by a way of its own so the ones in the
      // very middle have one.
      _openedAt = from;
      final turn = SandBall.turn * from;
      for (var i = 0; i < _in.length; i++) {
        if (_in[i] == 0) continue;
        _ball(i, turn, ct, st);
        final x = _bx * _deep[i] * ballR + 2 * math.cos(_la[i]);
        final y = _by * _deep[i] * ballR + 2 * math.sin(_la[i]);
        final d = math.max(1e-3, math.sqrt(x * x + y * y));
        _ox[i] = x / d;
        _oy[i] = y / d;
      }
    }
    // The ball's turn dies away as it opens.
    final turn =
        SandBall.turn * (from + _kSteady * (1 - math.exp(-since / _kSteady)));
    final open = SandHole.open(since);
    final c = SandHole.centre(size, open, _lean);
    final cx = size.width / 2, cy = size.height / 2;
    final sweep = 0.22 * ballR;
    final clear = SandHole.radius(size, open);
    // The ball kindles as it loosens, every grain lighting.
    final kindle = _smooth(0, 0.35, since);
    final sag = size.shortestSide * 0.035;
    final cb = math.cos(_bank), sb = math.sin(_bank);
    var n = 0, m = 0;
    for (var i = 0; i < _in.length; i++) {
      if (_in[i] == 0) continue;
      final o = SandHole.open(since - _lag[i]);
      // Thinned away before the rim reaches the edges.
      final keep = 1 - _smooth(_thin[i], _thin[i] + 0.3, open);
      if (keep <= 0.004) continue;
      _ball(i, turn, ct, st);
      final face = _face;
      final rad = ballR * _deep[i];
      final bx = cx + _bx * rad, by = cy + _by * rad;
      // The rim's line: the middle of the hole's soft edge, banked thicker
      // in places, as heaped sand would be.
      final f = SandHole.feather(size, o);
      final line = SandHole.radius(size, o) + 0.45 * f;
      final ux = _ox[i], uy = _oy[i];
      // sin 3 * (its angle + the bank's), off its direction.
      final s1 = uy * cb + ux * sb;
      final bank = 1 + 0.5 * (3 * s1 - 4 * s1 * s1 * s1);
      final rim = line * (1 + _band[i] * bank) + f * 0.25 * _band[i] * o;
      // Swept up once the rim has reached where it sits in the ball.
      final dx0 = bx - c.dx, dy0 = by - c.dy;
      final d = math.sqrt(dx0 * dx0 + dy0 * dy0);
      // A piece over what is showing is light already, whether or not its
      // own (trailing) rim has come for it.
      final w = math.max(
        _smooth(-0.4 * sweep, sweep, rim - d),
        _smooth(0, sweep, clear - d),
      );
      // Carried out curling, all the same way by different amounts, and
      // sagging a little, as sand would.
      final curl = (0.35 + 1.1 * _swing[i]) * o;
      final cc = math.cos(curl), sc = math.sin(curl);
      final r = math.max(rim, d);
      final rx = c.dx + (ux * cc - uy * sc) * r;
      final ry = c.dy + (ux * sc + uy * cc) * r + sag * o * o * _lr[i];
      final px = bx + (rx - bx) * w, py = by + (ry - by) * w;
      // In the ball its piece, the far side dimmer and smaller; swept up,
      // a grain of light, growing as it rides out past the player and
      // softer once it trails in over what is showing.
      final inBall = (0.35 + 0.65 * face) * (1 - w) * keep;
      if (inBall > 0.004) {
        final s = _grain * (1 - 0.25 * (1 - face));
        n = _piece(n, i, px, py, s, 0, inBall);
      }
      final over = _smooth(0, f * 0.5, line - 0.45 * f - r);
      final light = w * (0.75 - 0.4 * over) * keep;
      // In the ball, the light it had gathered (none, for most) swelling
      // as it kindles.
      final had = _mote[i] >= 0 ? 0.4 : 0.0;
      final warm =
          (had + ((0.3 + 0.3 * face) - had) * kindle) * (1 - w) * keep;
      final held = _cw * (0.8 + 0.3 * kindle);
      final carried = _cw * (1.2 + 1.4 * o) * (0.8 + 0.4 * _lr[i]);
      m = _glint(
        m,
        i,
        px,
        py,
        held + (carried - held) * w,
        math.max(warm, light),
        all: kindle > 0 || w > 0,
      );
    }
    _flush(canvas, n, m);
  }

  /// How quickly the ball's turn dies away as it opens, in seconds.
  static const double _kSteady = 0.35;

  void dispose() {
    image.dispose();
    _dot.dispose();
  }
}
