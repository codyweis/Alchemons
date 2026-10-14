// lib/widgets/fx/discovery_filing.dart
//
// A NEW SPECIES FILING ITSELF AWAY, IN ITS OWN SAND.
//
//   The card of a species never seen before comes apart the way every card
//   does -- a ragged edge climbing it from the foot -- but its sand is not
//   let go. Each piece loosens and goes out, a grain of the specimen's sand
//   (the rim's colors) stands where it was, and the grains are drawn off in
//   one lopsided current that pours into the species' own cell in the
//   catalog. There they settle grain by grain onto the cell's grey shadow,
//   from the foot up, lighting it in the creature's own colors; then the
//   portrait comes up through them as they go out.
//
//   A batch files its discoveries after its cards are long gone, so there
//   the sand gathers out of the dark where the card stood and pours the
//   same way.
//
// Cheap: the card is one picture (its layer, rasterised once) drawn back
// through drawRawAtlas -- column strips for what the edge has not reached, a
// sprite per loose piece -- and the grains in flight are a second atlas of
// one soft dot. The settled grains are points, one draw per tone. Nothing is
// read back off the GPU, no blur, and the per-frame buffers are allocated
// once. The cell is looked up every frame, so a catalog still scrolling it
// into view is followed.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/widgets/animations/hatch_shell.dart'
    show ShellMutationLook;
import 'package:alchemons/widgets/fx/card_dissolve.dart' show CardPicture;
import 'package:alchemons/widgets/fx/codex_stage.dart' show PortraitBody;
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/fx/essence_rim.dart'
    show RimColor, rimPrismHue;
import 'package:alchemons/widgets/fx/fusion_particles.dart'
    show GrainBatch, SpecimenGrains;
import 'package:flutter/widgets.dart';

/// A catalog cell reads its species' portrait into grains this tall...
const double kCatalogGrainHeight = 52;

/// ...into at most this many...
const int kCatalogGrainCount = 480;

/// ...and draws them at this scale, round the cell's centre.
const double kCatalogGrainScale = 0.9;

/// A species' portrait as the catalog reads it into grains: the still grey
/// shadow of an unknown one when [locked], its own colors otherwise. Both
/// are the same grains, so a species filed into its cell lands exactly on
/// the shadow it had.
Future<PortraitBody?> catalogPortrait(
  Creature species, {
  bool locked = false,
}) => PortraitBody.load(
  species.image.startsWith('assets/')
      ? species.image
      : 'assets/images/${species.image}',
  height: kCatalogGrainHeight,
  element: species.types.isEmpty ? 'Spirit' : species.types.first,
  color: const Color(0xFF3A404C),
  locked: locked,
  maxGrains: kCatalogGrainCount,
);

/// How long the edge takes to climb the card.
const double _kSweep = 0.30;

/// How long the dim under the card takes to lift.
const double _kDimLift = 0.45;

/// How long the portrait takes to come up through the settled grains.
const double _kFill = 0.38;

/// How long a grain glints as it settles.
const double _kGlint = 0.12;

class DiscoveryFiling {
  DiscoveryFiling._();

  /// Pours [species]' sand from [from] into its catalog cell, in [overlay].
  /// The overlay goes in now, so with a [card] the card's route can be
  /// removed in the same frame: the picture stands in for it.
  ///
  /// Without a [card], the sand gathers out of the dark where it stood.
  ///
  /// [cell] finds the species' cell (null until the catalog has laid it
  /// out); [fallback] is where the sand goes if it never does. [onFill]
  /// hears the portrait come up, 0 to 1, for the cell to show it.
  ///
  /// Completes when the last grain has gone.
  static Future<void> play({
    required OverlayState overlay,
    required Creature species,
    required Rect from,
    required Rect? Function() cell,
    required Rect? Function() fallback,
    CardPicture? card,
    SpecimenGrains? portrait,
    RimColor color = RimColor.element,
    Color barrier = const Color(0x00000000),
    bool reduced = false,
    int seed = 0,
    ValueChanged<double>? onFill,
  }) {
    final field = DiscoveryFilingField(
      size: from.size,
      card: card,
      portrait: portrait,
      element: species.types.isEmpty ? null : species.types.first,
      color: color,
      reduced: reduced,
      seed: seed,
    );
    final done = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FilingOverlay(
        field: field,
        at: from.topLeft,
        barrier: barrier,
        cell: cell,
        fallback: fallback,
        onFill: onFill,
        onDone: () {
          if (entry.mounted) entry.remove();
          if (!done.isCompleted) done.complete();
        },
      ),
    );
    overlay.insert(entry);
    return done.future;
  }
}

/// A new species' sand, from where its card stood to its cell.
class DiscoveryFilingField {
  DiscoveryFilingField({
    required Size size,
    this.card,
    this.portrait,
    String? element,
    RimColor color = RimColor.element,
    bool reduced = false,
    int seed = 0,
  }) : _w = size.width,
       _h = size.height {
    final rng = math.Random(seed);
    final k = (_h / 700).clamp(0.75, 1.3);
    final ramp = essenceRamp(EssenceElement.of(element));
    _glow = switch (color) {
      RimColor.element => ramp[3],
      RimColor.gilded => ShellMutationLook.paleGold,
      RimColor.prismatic => rimPrismHue(rng.nextDouble() * 12),
    };
    int sand(double x01, double y01) {
      final tone = switch (color) {
        RimColor.element => Color.lerp(ramp[2], ramp[3], rng.nextDouble())!,
        RimColor.gilded => Color.lerp(
          ShellMutationLook.gold,
          ShellMutationLook.paleGold,
          rng.nextDouble(),
        )!,
        // Once round the rainbow, corner to corner, as the rim is.
        RimColor.prismatic => rimPrismHue((x01 * 0.75 + y01 * 0.25) * 12),
      };
      return tone.toARGB32() & 0xFFFFFF;
    }

    // ── The card's pieces ────────────────────────────────────────────────
    // Cut as the dissolve cuts it, so the edge climbs the same way; but a
    // piece only loosens and goes out where it stood. Its grain is what
    // travels.
    var pieceEnd = 0.0;
    if (card != null) {
      final target = reduced ? 4000 : 9000;
      final cell = math.max(reduced ? 6.5 : 4.5, math.sqrt(_w * _h / target));
      _cols = math.max(1, (_w / cell).ceil());
      _rows = math.max(1, (_h / cell).ceil());
    } else {
      _cols = 0;
      _rows = 0;
    }
    _cw = _cols == 0 ? 0 : _w / _cols;
    _ch = _rows == 0 ? 0 : _h / _rows;
    final n = _cols * _rows;
    _rt = Float32List(n);
    _hang = Float32List(n);
    _life = Float32List(n);
    _vx = Float32List(n);
    _vy = Float32List(n);
    _sway = Float32List(n);
    _phase = Float32List(n);
    _spin = Float32List(n);
    if (n > 0) {
      // The edge: two slow waves across the card, and a little grit per
      // column so it crumbles rather than cuts.
      final p1 = rng.nextDouble() * 2 * math.pi;
      final p2 = rng.nextDouble() * 2 * math.pi;
      final amp = _h * 0.07;
      final reach = amp + _cw * 1.2;
      for (var c = 0; c < _cols; c++) {
        final x01 = (c + 0.5) / _cols;
        final tooth =
            amp *
                (0.62 * math.sin(2 * math.pi * 1.15 * x01 + p1) +
                    0.38 * math.sin(2 * math.pi * 2.7 * x01 + p2)) +
            (rng.nextDouble() - 0.5) * _cw * 2.0;
        for (var r = 0; r < _rows; r++) {
          final i = r * _cols + c;
          final y = (r + 0.5) * _ch;
          final up = ((_h - y + tooth + reach) / (_h + 2 * reach)).clamp(
            0.0,
            1.0,
          );
          // The edge starts a touch slow and picks up.
          final p = (-0.35 + math.sqrt(0.1225 + 2.6 * up)) / 1.3;
          _rt[i] = _kSweep * p;
          final h = rng.nextDouble();
          _hang[i] = 0.06 * h * h;
          _life[i] = 0.16 + 0.10 * rng.nextDouble();
          _vx[i] = (rng.nextDouble() - 0.5) * 60 * k;
          _vy[i] = (10 + 30 * rng.nextDouble()) * k;
          _sway[i] = (2 + 5 * rng.nextDouble()) * k;
          _phase[i] = rng.nextDouble() * 2 * math.pi;
          _spin[i] = (rng.nextDouble() - 0.5) * 8;
          pieceEnd = math.max(pieceEnd, _rt[i] + _hang[i] + _life[i]);
        }
      }
    }
    _pieceEnd = pieceEnd;

    // ── The sand ─────────────────────────────────────────────────────────
    final formable = portrait?.length ?? 0;
    final s = math.max(reduced ? 560 : 1100, (formable * 1.4).ceil());
    _ox = Float32List(s);
    _oy = Float32List(s);
    _rel = Float32List(s);
    _dur = Float32List(s);
    _rise = Float32List(s);
    _curl = Float32List(s);
    _d0 = Float32List(s);
    _ex = Float32List(s);
    _ey = Float32List(s);
    _lx = Float32List(s);
    _ly = Float32List(s);
    _sand = Int32List(s);
    _slot = Int32List(s)..fillRange(0, s, -1);
    var last = 0.0;
    for (var j = 0; j < s; j++) {
      if (n > 0) {
        // Out of a piece, a beat after it lets go.
        final i = rng.nextInt(n);
        _ox[j] = (i % _cols + 0.2 + 0.6 * rng.nextDouble()) * _cw;
        _oy[j] = (i ~/ _cols + 0.2 + 0.6 * rng.nextDouble()) * _ch;
        _rel[j] = _rt[i] + _hang[i] + 0.02 + 0.06 * rng.nextDouble();
      } else {
        // Out of the dark where the card stood: banked low, as its rim was,
        // and gathering from the foot up.
        final up = math.pow(rng.nextDouble(), 1.7) * 0.9;
        _ox[j] = rng.nextDouble() * _w;
        _oy[j] = _h * (1 - up);
        _rel[j] = 0.02 + 0.26 * up + 0.08 * rng.nextDouble();
      }
      _dur[j] = 0.56 + 0.26 * rng.nextDouble();
      _rise[j] = (24 + 56 * rng.nextDouble()) * k;
      // One way round, mostly: a current, not a burst.
      _curl[j] =
          (0.06 + 0.16 * rng.nextDouble()) *
          (rng.nextDouble() < 0.14 ? -0.6 : 1);
      _d0[j] = (reduced ? 5.5 : 5.0) * (0.75 + 0.5 * rng.nextDouble());
      _ex[j] = (rng.nextDouble() - 0.5) * 0.6;
      _ey[j] = (rng.nextDouble() - 0.5) * 0.6;
      // A lane with some width: a current, not a wire.
      final lr = 34 * k * math.sqrt(rng.nextDouble());
      final la = rng.nextDouble() * 2 * math.pi;
      _lx[j] = lr * math.cos(la);
      _ly[j] = lr * math.sin(la);
      _sand[j] = sand(_ox[j] / _w, _oy[j] / _h);
      last = math.max(last, _rel[j] + _dur[j]);
    }

    // Which grains become the portrait: a scattered share, so the pour is
    // the same all through, given its grains in the order they arrive --
    // and the portrait's from its foot up, so it fills like a mould.
    if (formable > 0) {
      final g = portrait!;
      final order = List<int>.generate(s, (j) => j)..shuffle(rng);
      final chosen = order.sublist(0, formable)
        ..sort((a, b) => (_rel[a] + _dur[a]).compareTo(_rel[b] + _dur[b]));
      final depth = Float32List(formable);
      for (var q = 0; q < formable; q++) {
        depth[q] = -g.hy[q] + (rng.nextDouble() - 0.5) * g.step * 6;
      }
      final spots = List<int>.generate(formable, (q) => q)
        ..sort((a, b) => depth[a].compareTo(depth[b]));
      for (var q = 0; q < formable; q++) {
        _slot[chosen[q]] = spots[q];
      }
      _tone = Int32List(g.tones.length);
      for (var t = 0; t < g.tones.length; t++) {
        _tone[t] = g.tones[t].toARGB32() & 0xFFFFFF;
      }
      _settled = GrainBatch(g.tones.length);
    } else {
      _tone = Int32List(0);
      _settled = GrainBatch(1);
    }

    fillFrom = last - 0.10;
    fillTo = fillFrom + _kFill;
    duration = Duration(microseconds: ((fillTo + 0.04) * 1e6).ceil());

    _xf = Float32List((_cols + n) * 4);
    _src = Float32List((_cols + n) * 4);
    _col = Int32List(_cols + n);
    final dots = s * 3 + formable;
    _mxf = Float32List(dots * 4);
    _msrc = Float32List(dots * 4);
    _mcol = Int32List(dots);
    for (var j = 0; j < dots; j++) {
      _msrc[j * 4 + 2] = _kDot;
      _msrc[j * 4 + 3] = _kDot;
    }
    _dot = _makeDot();
  }

  /// The card as it stood. Null for a card long gone.
  final CardPicture? card;

  /// The species as its cell reads it, where the sand settles.
  final SpecimenGrains? portrait;

  /// From the edge starting up the card to the last grain going out.
  late final Duration duration;

  /// When the portrait starts to come up through its grains, and stands.
  late final double fillFrom, fillTo;

  final double _w, _h;
  late final int _cols, _rows;
  late final double _cw, _ch, _pieceEnd;
  late final Color _glow;

  // Per piece: when the edge reaches it, how long it hangs, how long it
  // lasts once loose, and how it goes.
  late final Float32List _rt, _hang, _life, _vx, _vy, _sway, _phase, _spin;

  // Per grain: where it starts (on the card), when, how long its pour is,
  // how it lifts and turns, how big it is, where it lands if it is not part
  // of the portrait, where it passes through the lane, its sand, and its
  // place in the portrait (or -1).
  late final Float32List _ox, _oy, _rel, _dur, _rise, _curl, _d0, _ex, _ey;
  late final Float32List _lx, _ly;
  late final Int32List _sand, _slot;

  /// The portrait's tones, 0xRRGGBB.
  late final Int32List _tone;
  late final GrainBatch _settled;

  late final Float32List _xf, _src, _mxf, _msrc;
  late final Int32List _col, _mcol;
  late final ui.Image _dot;

  static const double _kDot = 32;

  static final Paint _piecePaint = Paint()
    // Off, or the strips' shared edges each blend half a pixel and the card
    // shows seams before it has started to go.
    ..isAntiAlias = false
    ..filterQuality = FilterQuality.low;
  static final Paint _dotPaint = Paint()..filterQuality = FilterQuality.low;
  static final Paint _poolPaint = Paint();

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

  /// How far along its pour a grain is, [u] of the way through its time:
  /// slow to leave, and slowing to rest as it lands.
  static double _ease(double u) {
    final v = 1 - u;
    return 0.35 * u * v * v + u * u * (3 - 2 * u);
  }

  static int _mix(int a, int b, double t) {
    final r =
        ((a >> 16) & 0xFF) + (((b >> 16) & 0xFF) - ((a >> 16) & 0xFF)) * t;
    final g = ((a >> 8) & 0xFF) + (((b >> 8) & 0xFF) - ((a >> 8) & 0xFF)) * t;
    final bl = (a & 0xFF) + ((b & 0xFF) - (a & 0xFF)) * t;
    return (r.round() << 16) | (g.round() << 8) | bl.round();
  }

  /// How far the portrait has come up through its grains at [t] seconds.
  double fillAt(double t) => _smooth(fillFrom, fillTo, t);

  /// Draws the filing [t] seconds in: the card's top-left at [at], the sand
  /// pouring into [to] -- the species' cell when [toCell], else wherever it
  /// could find to go.
  void paint(
    Canvas canvas,
    Offset at,
    double t, {
    required Rect to,
    required bool toCell,
  }) {
    final g = portrait;
    final f = fillAt(t);
    // The settled grains lie on the cell's shadow, then follow the portrait
    // as it comes up (it stands a little higher and larger than the shadow).
    final fe = f * f * (3 - 2 * f);
    final side = math.min(to.width - 6, to.height - 8);
    final sc = toCell
        ? ui.lerpDouble(kCatalogGrainScale, side / kCatalogGrainHeight, fe)!
        : to.shortestSide / kCatalogGrainHeight;
    final cx = to.center.dx;
    final cy = toCell
        ? ui.lerpDouble(to.center.dy, to.top + 3 + (to.height - 8) / 2, fe)!
        : to.center.dy;
    final formed = toCell && g != null;

    // A pool of the element's light under the cell while the sand comes in.
    final pool = _smooth(0.35, 0.8, t) * (1 - _smooth(fillFrom, fillTo, t));
    if (toCell && pool > 0.01) {
      final r = to.shortestSide * 1.3;
      _poolPaint.shader = ui.Gradient.radial(to.center, r, [
        _glow.withValues(alpha: 0.24 * pool),
        _glow.withValues(alpha: 0),
      ]);
      canvas.drawCircle(to.center, r, _poolPaint);
    }

    final c = card;
    if (c != null && t < _pieceEnd) _paintPieces(canvas, c, at, t);

    final settledA = 1 - _smooth(0.25, 1, f);
    final grainD = g == null ? 1.8 : g.step * 1.22 * sc;
    if (formed) _settled.clear();
    final mxf = _mxf, mcol = _mcol;
    var m = 0;

    void dot(double x, double y, double d, double a, int rgb) {
      if (a <= 0.004) return;
      final s = d / _kDot;
      final j = m * 4;
      mxf[j] = s;
      mxf[j + 1] = 0;
      mxf[j + 2] = x - d / 2;
      mxf[j + 3] = y - d / 2;
      mcol[m++] = ((a.clamp(0.0, 1.0) * 255).round() << 24) | rgb;
    }

    // The lane: one point beside the cell every grain is drawn round on its
    // way in, so the sand gathers into one current and pours in from one
    // side. Off towards where the card stood, turned a little one way.
    final mid = at + Offset(_w / 2, _h / 2);
    var vx = mid.dx - to.center.dx, vy = mid.dy - to.center.dy;
    final len = math.sqrt(vx * vx + vy * vy);
    if (len < 60) {
      vx = 0.55;
      vy = -0.83;
    } else {
      vx /= len;
      vy /= len;
    }
    final reach = len < 60 ? 110.0 : (len * 0.45).clamp(100.0, 170.0);
    const turn = 0.6;
    final cs = math.cos(turn), sn = math.sin(turn);
    final laneX = to.center.dx + (vx * cs - vy * sn) * reach;
    final laneY = to.center.dy + (vx * sn + vy * cs) * reach;

    for (var j = 0; j < _rel.length; j++) {
      final a = t - _rel[j];
      if (a <= 0) continue;
      final dur = _dur[j];
      final u = a / dur;
      final q = formed ? _slot[j] : -1;
      final double dx, dy;
      if (q >= 0) {
        dx = cx + g!.hx[q] * sc;
        dy = cy + g.hy[q] * sc;
      } else {
        dx = to.center.dx + _ex[j] * to.width;
        dy = to.center.dy + _ey[j] * to.height;
      }

      if (u >= 1) {
        // Settled: part of the portrait now, glinting a moment as it lands.
        if (q < 0) continue;
        final tone = g!.tone[q];
        if (settledA > 0) _settled.add(tone, dx, dy);
        final age = a - dur;
        if (age < _kGlint) {
          dot(
            dx,
            dy,
            grainD * 3.2,
            0.55 * (1 - age / _kGlint) * settledA,
            _mix(_sand[j], _tone[tone], 0.5),
          );
        }
        continue;
      }

      // In the current: up off the card, round through the lane, and in.
      final ox = at.dx + _ox[j], oy = at.dy + _oy[j];
      final lx = laneX + _lx[j], ly = laneY + _ly[j];
      final chx = lx - ox, chy = ly - oy;
      final curl = _curl[j];
      final p1x = ox + chx * 0.3 - chy * curl;
      final p1y = oy + chy * 0.3 + chx * curl - _rise[j];
      final born = c != null ? _smooth(0, 0.1, a) : _smooth(0, 0.16, a);
      for (var k = 0; k < 3; k++) {
        final uk = u - k * 0.06;
        if (uk <= 0) break;
        final e = _ease(uk), r = 1 - e;
        final b0 = r * r * r, b1 = 3 * r * r * e;
        final b2 = 3 * r * e * e, b3 = e * e * e;
        final x = b0 * ox + b1 * p1x + b2 * lx + b3 * dx;
        final y = b0 * oy + b1 * p1y + b2 * ly + b3 * dy;
        final land = _smooth(0.7, 1, uk);
        var d = q >= 0
            ? ui.lerpDouble(_d0[j], grainD * 2.4, land)!
            : _d0[j] * (1 - 0.6 * land);
        var al = born;
        // Only the portrait's grains reach the cell; the rest thin out on the
        // way, or the cell drowns in a blot of sand.
        if (q < 0) al *= 1 - _smooth(0.4, 0.85, uk);
        if (k > 0) {
          d *= 1 - 0.18 * k;
          al *= k == 1 ? 0.42 : 0.18;
        }
        final rgb = q >= 0
            ? _mix(_sand[j], _tone[g!.tone[q]], _smooth(0.65, 1, uk))
            : _sand[j];
        dot(x, y, d, al, rgb);
      }
    }

    if (formed && settledA > 0) {
      for (var k = 0; k < g.tones.length; k++) {
        _settled.draw(
          canvas,
          k,
          grainD,
          g.tones[k].withValues(alpha: settledA),
        );
      }
    }
    if (m > 0) {
      canvas.drawRawAtlas(
        _dot,
        Float32List.sublistView(mxf, 0, m * 4),
        Float32List.sublistView(_msrc, 0, m * 4),
        Int32List.sublistView(mcol, 0, m),
        BlendMode.modulate,
        null,
        _dotPaint,
      );
    }
  }

  void _paintPieces(Canvas canvas, CardPicture card, Offset at, double t) {
    final pr = card.pixelRatio;
    final sw = _cw * pr, sh = _ch * pr;
    final ax = sw / 2, ay = sh / 2;
    final xf = _xf, src = _src, col = _col;
    var n = 0;
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
      for (var rr = r; rr < _rows; rr++) {
        final i = rr * _cols + c;
        final a = t - _rt[i] - _hang[i];
        var x = (c + 0.5) * _cw, y = (rr + 0.5) * _ch;
        var s = 1.0, rot = 0.0, alpha = 1.0;
        if (a > 0) {
          final u = a / _life[i];
          if (u >= 1) continue;
          x +=
              _vx[i] * a +
              _sway[i] * math.sin(_phase[i] + a * 11) * _smooth(0, 0.5, u);
          y -= _vy[i] * a;
          rot = _spin[i] * a;
          s = 1 - 0.6 * _smooth(0, 0.9, u);
          alpha = 1 - _smooth(0.05, 0.8, u);
        }
        if (alpha <= 0.004) continue;
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
    }
    if (n > 0) {
      canvas.drawRawAtlas(
        card.image,
        Float32List.sublistView(xf, 0, n * 4),
        Float32List.sublistView(src, 0, n * 4),
        Int32List.sublistView(col, 0, n),
        BlendMode.modulate,
        null,
        _piecePaint,
      );
    }
  }

  void dispose() {
    card?.dispose();
    _dot.dispose();
  }
}

class _FilingOverlay extends StatefulWidget {
  const _FilingOverlay({
    required this.field,
    required this.at,
    required this.barrier,
    required this.cell,
    required this.fallback,
    required this.onFill,
    required this.onDone,
  });

  final DiscoveryFilingField field;
  final Offset at;
  final Color barrier;
  final Rect? Function() cell;
  final Rect? Function() fallback;
  final ValueChanged<double>? onFill;
  final VoidCallback onDone;

  @override
  State<_FilingOverlay> createState() => _FilingOverlayState();
}

class _FilingOverlayState extends State<_FilingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.field.duration,
  );

  @override
  void initState() {
    super.initState();
    final onFill = widget.onFill;
    if (onFill != null) {
      _clock.addListener(() => onFill(widget.field.fillAt(_seconds)));
    }
    _clock.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    // Started from here, the clock's first tick is the frame after the one
    // that puts this in -- the frame the catalog is built in -- so that
    // frame's cost is not taken out of the card's first moments.
    _clock.forward();
  }

  double get _seconds =>
      _clock.value * widget.field.duration.inMicroseconds / 1e6;

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
          child: CustomPaint(painter: _FilingPainter(this)),
        ),
      ),
    );
  }
}

class _FilingPainter extends CustomPainter {
  _FilingPainter(this.state) : super(repaint: state._clock);

  final _FilingOverlayState state;

  /// The cell as last found, kept for a frame it cannot be.
  Rect? _cell;

  @override
  void paint(Canvas canvas, Size size) {
    final w = state.widget;
    final field = w.field;
    final t = state._seconds;
    final barrier = w.barrier;
    if (barrier.a > 0) {
      final lift = Curves.easeInOut.transform((t / _kDimLift).clamp(0.0, 1.0));
      if (lift < 1) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = barrier.withValues(alpha: barrier.a * (1 - lift)),
        );
      }
    }
    final cell = w.cell() ?? _cell;
    _cell = cell;
    final to =
        cell ??
        w.fallback() ??
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: 48,
          height: 48,
        );
    field.paint(canvas, w.at, t, to: to, toCell: cell != null);
  }

  @override
  bool shouldRepaint(_FilingPainter old) => old.state != state;
}
