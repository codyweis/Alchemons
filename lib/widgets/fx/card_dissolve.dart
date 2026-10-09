// lib/widgets/fx/card_dissolve.dart
//
// A CARD COMING APART INTO ITS SPECIMEN'S SAND.
//
//   When the player is done with a card it does not just close: it comes
//   apart from the foot up. A ragged edge climbs it from where the button was
//   pressed, and every piece the edge passes lets go -- a moment's hang, then
//   up on a rising draught, turning and shrinking -- and as it goes it turns
//   from a piece of the card into a grain of the specimen's own sand (the
//   rim's colors: the element's light shades, gold, or the rainbow) and
//   thins out to nothing. The dim the card sat on lifts with it, so the
//   screen comes back as the card goes.
//
//   Fast: the edge is over the card in under a third of a second and the
//   last grain is gone by about three quarters. The card's route goes the
//   moment its picture stands in for it, so nothing waits on the sand.
//
// Cheap: the card's own layer is rasterised once and drawn back through
// drawRawAtlas -- what the edge has not reached as one strip per column,
// every loose piece as one sprite -- and the grains are a second atlas of a
// single soft dot. Nothing is read back off the GPU, no blur, and the
// per-frame buffers are allocated once.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/animations/hatch_shell.dart'
    show ShellMutationLook;
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/essence_rim.dart'
    show RimColor, rimPrismHue;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// How long the edge takes to climb the card.
const double _kSweep = 0.30;

/// How long the dim under the card takes to lift.
const double _kDimLift = 0.45;

class CardDissolve {
  CardDissolve._();

  /// Stands what [boundaryKey] shows in the root overlay, and lets it come
  /// apart there.
  ///
  /// True once the overlay is standing in for the card: remove the card's
  /// route straight away, in the same frame. False when the card could not
  /// be pictured (it has gone, or the raster did not come back in time) --
  /// just close it.
  ///
  /// [barrier] is the dim the card's route sits on; it lifts with the card.
  static Future<bool> play({
    required BuildContext context,
    required GlobalKey boundaryKey,
    String? element,
    RimColor color = RimColor.element,
    Color barrier = const Color(0x00000000),
    bool reduced = false,
    int seed = 0,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final boundary = boundaryKey.currentContext?.findRenderObject();
    if (overlay == null ||
        boundary is! RenderRepaintBoundary ||
        !boundary.attached) {
      return false;
    }
    final rect = boundary.localToGlobal(Offset.zero) & boundary.size;
    // At the screen's own density: the first frames ARE the card, and a
    // softer picture would show as it swapped in.
    final pixelRatio = math.min(
      MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0,
      3.0,
    );
    final Future<ui.Image> pending;
    try {
      pending = boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      return false;
    }
    final ui.Image image;
    try {
      image = await pending.timeout(const Duration(milliseconds: 400));
    } on TimeoutException {
      unawaited(pending.then<void>((i) => i.dispose(), onError: (_) {}));
      return false;
    } catch (_) {
      return false;
    }
    if (!overlay.mounted) {
      image.dispose();
      return false;
    }
    final field = CardDissolveField(
      image: image,
      pixelRatio: pixelRatio,
      size: rect.size,
      element: element,
      color: color,
      reduced: reduced,
      seed: seed,
    );
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DissolveOverlay(
        field: field,
        at: rect.topLeft,
        barrier: barrier,
        onDone: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    return true;
  }
}

/// A pictured card cut into pieces, each with the way it will go.
class CardDissolveField {
  CardDissolveField({
    required this.image,
    required this.pixelRatio,
    required Size size,
    String? element,
    RimColor color = RimColor.element,
    bool reduced = false,
    int seed = 0,
  }) : _w = size.width,
       _h = size.height {
    // Pieces about the size of a grain of the rim's sand; a big card is cut
    // coarser rather than into more of them.
    final target = reduced ? 4000 : 9000;
    final cell = math.max(reduced ? 6.5 : 4.5, math.sqrt(_w * _h / target));
    _cols = math.max(1, (_w / cell).ceil());
    _rows = math.max(1, (_h / cell).ceil());
    _cw = _w / _cols;
    _ch = _h / _rows;
    final n = _cols * _rows;
    _rt = Float32List(n);
    _hang = Float32List(n);
    _life = Float32List(n);
    _v0 = Float32List(n);
    _g = Float32List(n);
    _drift = Float32List(n);
    _sway = Float32List(n);
    _phase = Float32List(n);
    _spin = Float32List(n);
    _mote = Int32List(n);

    final rng = math.Random(seed);
    final k = (_h / 700).clamp(0.75, 1.3);
    _spread = 60 * k;
    // The edge: two slow waves across the card, and a little grit per
    // column so it crumbles rather than cuts.
    final p1 = rng.nextDouble() * 2 * math.pi;
    final p2 = rng.nextDouble() * 2 * math.pi;
    final amp = _h * 0.07;
    final reach = amp + cell * 1.2;
    final ramp = essenceRamp(EssenceElement.of(element));
    // Not every piece leaves a grain: the light is in the scatter.
    final moteShare = reduced ? 0.16 : 0.22;
    var motes = 0;
    var end = 0.0;
    for (var c = 0; c < _cols; c++) {
      final x01 = (c + 0.5) / _cols;
      final tooth =
          amp *
              (0.62 * math.sin(2 * math.pi * 1.15 * x01 + p1) +
                  0.38 * math.sin(2 * math.pi * 2.7 * x01 + p2)) +
          (rng.nextDouble() - 0.5) * cell * 2.0;
      for (var r = 0; r < _rows; r++) {
        final i = r * _cols + c;
        final y = (r + 0.5) * _ch;
        // How far up the card it lies, as the edge sees it: 0 at the foot.
        final up = ((_h - y + tooth + reach) / (_h + 2 * reach)).clamp(
          0.0,
          1.0,
        );
        // The edge starts a touch slow and picks up (up = 0.35p + 0.65p²).
        final p = (-0.35 + math.sqrt(0.1225 + 2.6 * up)) / 1.3;
        _rt[i] = _kSweep * p;
        final h = rng.nextDouble();
        _hang[i] = 0.07 * h * h;
        _life[i] = 0.26 + 0.14 * rng.nextDouble();
        _v0[i] = (20 + 80 * rng.nextDouble()) * k;
        _g[i] = (1700 + 2000 * rng.nextDouble()) * k;
        _drift[i] = (rng.nextDouble() - 0.5) * 100 * k;
        _sway[i] = (4 + 10 * rng.nextDouble()) * k;
        _phase[i] = rng.nextDouble() * 2 * math.pi;
        _spin[i] = (rng.nextDouble() - 0.5) * 10;
        end = math.max(end, _rt[i] + _hang[i] + _life[i]);
        if (rng.nextDouble() < moteShare) {
          final tone = switch (color) {
            RimColor.element => Color.lerp(
              ramp[2],
              ramp[3],
              rng.nextDouble(),
            )!,
            RimColor.gilded => Color.lerp(
              ShellMutationLook.gold,
              ShellMutationLook.paleGold,
              rng.nextDouble(),
            )!,
            // Once round the rainbow, corner to corner, as the rim is.
            RimColor.prismatic => rimPrismHue(
              (x01 * 0.75 + (y / _h) * 0.25) * 12,
            ),
          };
          _mote[i] = tone.toARGB32() & 0xFFFFFF;
          motes++;
        } else {
          _mote[i] = -1;
        }
      }
    }
    duration = Duration(microseconds: (end * 1e6).ceil());
    _xf = Float32List((_cols + n) * 4);
    _src = Float32List((_cols + n) * 4);
    _col = Int32List(_cols + n);
    _mxf = Float32List(motes * 4);
    _msrc = Float32List(motes * 4);
    _mcol = Int32List(motes);
    for (var j = 0; j < motes; j++) {
      _msrc[j * 4 + 2] = _kDot;
      _msrc[j * 4 + 3] = _kDot;
    }
    _dot = _makeDot();
  }

  /// The card as it stood, at [pixelRatio].
  final ui.Image image;
  final double pixelRatio;

  /// From the first piece letting go to the last grain going out.
  late final Duration duration;

  final double _w, _h;
  late final int _cols, _rows;
  late final double _cw, _ch, _spread;

  // Per piece: when the edge reaches it, how long it hangs there, how long
  // it lasts once moving, and how it goes.
  late final Float32List _rt, _hang, _life, _v0, _g, _drift, _sway, _phase;
  late final Float32List _spin;

  /// The grain it becomes (0xRRGGBB), or -1 for none.
  late final Int32List _mote;

  late final Float32List _xf, _src, _mxf, _msrc;
  late final Int32List _col, _mcol;
  late final ui.Image _dot;

  static const double _kDot = 32;

  static final Paint _piecePaint = Paint()
    // Off, or the strips' shared edges each blend half a pixel and the card
    // shows seams before it has started to go.
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  static final Paint _motePaint = Paint()..filterQuality = FilterQuality.low;

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

  /// Draws the card [t] seconds into coming apart, its top-left at [at].
  void paint(Canvas canvas, Offset at, double t) {
    final pr = pixelRatio;
    final sw = _cw * pr, sh = _ch * pr;
    final ax = sw / 2, ay = sh / 2;
    final xf = _xf, src = _src, col = _col;
    final mxf = _mxf, mcol = _mcol;
    var n = 0, m = 0;

    for (var c = 0; c < _cols; c++) {
      // The edge has passed the pieces below r; above it the column is
      // still whole, and goes as one strip.
      var r = _rows;
      while (r > 0 && _rt[(r - 1) * _cols + c] <= t) {
        r--;
      }
      if (r > 0) {
        final j = n * 4;
        xf[j] = 1 / pr;
        xf[j + 1] = 0;
        xf[j + 2] = at.dx + c * _cw;
        xf[j + 3] = at.dy;
        src[j] = c * sw;
        src[j + 1] = 0;
        src[j + 2] = (c + 1) * sw;
        src[j + 3] = r * sh;
        col[n++] = 0xFFFFFFFF;
      }
      final out = ((c + 0.5) / _cols - 0.5) * 2 * _spread;
      for (var rr = r; rr < _rows; rr++) {
        final i = rr * _cols + c;
        final a = t - _rt[i] - _hang[i];
        var x = (c + 0.5) * _cw, y = (rr + 0.5) * _ch;
        var s = 1.0, rot = 0.0, alpha = 1.0, glow = 0.0;
        if (a > 0) {
          final u = a / _life[i];
          if (u >= 1) continue;
          x +=
              _drift[i] * a +
              _sway[i] * math.sin(_phase[i] + a * 11) * _smooth(0, 0.5, u) +
              out * u * u;
          y -= _v0[i] * a + 0.5 * _g[i] * a * a;
          rot = _spin[i] * a;
          s = 1 - 0.7 * _smooth(0, 0.85, u);
          alpha = 1 - _smooth(0.12, 0.7, u);
          glow = _smooth(0.04, 0.3, u) * (1 - _smooth(0.45, 1, u));
        }
        if (alpha > 0.004) {
          final sc = s / pr;
          final cs = rot == 0 ? sc : math.cos(rot) * sc;
          final sn = rot == 0 ? 0.0 : math.sin(rot) * sc;
          final j = n * 4;
          xf[j] = cs;
          xf[j + 1] = sn;
          xf[j + 2] = at.dx + x - cs * ax + sn * ay;
          xf[j + 3] = at.dy + y - sn * ax - cs * ay;
          src[j] = c * sw;
          src[j + 1] = rr * sh;
          src[j + 2] = (c + 1) * sw;
          src[j + 3] = (rr + 1) * sh;
          col[n++] = ((alpha * 255).round() << 24) | 0xFFFFFF;
        }
        final tone = _mote[i];
        if (glow > 0.01 && tone >= 0) {
          // About a piece across at first, smaller as it thins.
          final sc = _cw * (1.7 - 0.8 * a / _life[i]) / _kDot;
          final j = m * 4;
          mxf[j] = sc;
          mxf[j + 1] = 0;
          mxf[j + 2] = at.dx + x - sc * _kDot / 2;
          mxf[j + 3] = at.dy + y - sc * _kDot / 2;
          mcol[m++] = ((glow * 0.7 * 255).round() << 24) | tone;
        }
      }
    }

    if (n > 0) {
      canvas.drawRawAtlas(
        image,
        Float32List.sublistView(xf, 0, n * 4),
        Float32List.sublistView(src, 0, n * 4),
        Int32List.sublistView(col, 0, n),
        BlendMode.modulate,
        null,
        _piecePaint,
      );
    }
    if (m > 0) {
      canvas.drawRawAtlas(
        _dot,
        Float32List.sublistView(mxf, 0, m * 4),
        Float32List.sublistView(_msrc, 0, m * 4),
        Int32List.sublistView(mcol, 0, m),
        BlendMode.modulate,
        null,
        _motePaint,
      );
    }
  }

  void dispose() {
    image.dispose();
    _dot.dispose();
  }
}

class _DissolveOverlay extends StatefulWidget {
  const _DissolveOverlay({
    required this.field,
    required this.at,
    required this.barrier,
    required this.onDone,
  });

  final CardDissolveField field;
  final Offset at;
  final Color barrier;
  final VoidCallback onDone;

  @override
  State<_DissolveOverlay> createState() => _DissolveOverlayState();
}

class _DissolveOverlayState extends State<_DissolveOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.field.duration,
  );

  @override
  void initState() {
    super.initState();
    _clock.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _clock.forward();
  }

  @override
  void dispose() {
    _clock.dispose();
    widget.field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // The screen under it is live again from the first frame.
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DissolvePainter(
              widget.field,
              widget.at,
              widget.barrier,
              _clock,
            ),
          ),
        ),
      ),
    );
  }
}

class _DissolvePainter extends CustomPainter {
  _DissolvePainter(this.field, this.at, this.barrier, this.clock)
    : super(repaint: clock);

  final CardDissolveField field;
  final Offset at;
  final Color barrier;
  final AnimationController clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value * field.duration.inMicroseconds / 1e6;
    if (barrier.a > 0) {
      final lift = Curves.easeInOut.transform((t / _kDimLift).clamp(0.0, 1.0));
      if (lift < 1) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = barrier.withValues(alpha: barrier.a * (1 - lift)),
        );
      }
    }
    field.paint(canvas, at, t);
  }

  @override
  bool shouldRepaint(_DissolvePainter old) =>
      old.field != field || old.at != at || old.barrier != barrier;
}
