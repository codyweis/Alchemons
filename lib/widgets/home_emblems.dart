// lib/widgets/home_emblems.dart
//
// The three ways off the right side of home, drawn as living grains with
// nothing framing them — the language of the dock's Enhance and Harvest:
//
//   constellation  UPGRADE: a dark disc with the chart's own sky in it — a
//                  way through to the star chart
//   altar          RELICS: the Mystic Altar in little — a tipped ring of dust
//                  carrying sixteen relics round the arcane heart
//   rite           RITE: a drop of blood in grains, turning, giving off souls
//
// Each scene is also its own way in (navigation/emblem_passage.dart): an
// [EmblemStage] says where the icon stands, how far it has grown over the
// screen ([EmblemStage.open]) and how far it has given way to the page
// ([EmblemStage.land]), and the scene paints that moment — so the thing the
// player touched is the thing that carries them in. The altar's ring grows
// into the hub's own ring; the sky disc opens until it is the chart's sky,
// and the chart lights its trees in it; the drop falls into a pool of blood
// that rises off as the rite's souls.
//
// One shared clock (GlyphClock), stopped while home is covered. Points in
// batches, gradients for light; no blur, no stroked outlines.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/screens/mystic_altar/altar_grains.dart';
import 'package:alchemons/screens/mystic_altar/altar_hub_field.dart';
import 'package:alchemons/screens/pureblood_rite/rite_pool.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum HomeEmblemKind { constellation, altar, rite }

/// One moment of an emblem: where its icon stands, and how far it has
/// carried the player toward its page.
class EmblemStage {
  const EmblemStage({
    required this.box,
    required this.screen,
    required this.time,
    this.pad = EdgeInsets.zero,
    this.open = 0,
    this.land = 0,
    this.closing = false,
  });

  /// The icon's box. For the icon itself, its own bounds.
  final Rect box;

  /// The screen the passage covers (the icon: its own size).
  final Size screen;

  /// The screen's safe area, for scenes that land on a page's layout.
  final EdgeInsets pad;

  /// Seconds, from the shared clock.
  final double time;

  /// 0 the icon in its box .. 1 grown over the whole screen.
  final double open;

  /// 0 covering the screen .. 1 given way to the page.
  final double land;

  /// Going back: the scene gathers home without its way-in flourishes.
  final bool closing;

  /// [open], eased: firmly on the way in, gently going back (a hard
  /// ease-in-out shrinking home reads as a spring).
  double get grow => closing ? _smooth(0, 1, open) : _ease(open);

  /// How much of the screen is the passage's own ground.
  double get ground => _smooth(0.0, 0.7, open);
}

/// Which part of a scene a painter draws: the passage puts the page between
/// its ground ([back]) and its grains ([front]).
enum EmblemLayer { all, back, front }

class HomeEmblem extends StatefulWidget {
  const HomeEmblem({
    super.key,
    required this.kind,
    required this.size,
    this.animate = true,
    this.lifted,
  });

  final HomeEmblemKind kind;
  final double size;
  final bool animate;

  /// True while the emblem is away carrying the player in: the icon leaves
  /// its place empty, as a hero's does.
  final ValueListenable<bool>? lifted;

  @override
  State<HomeEmblem> createState() => _HomeEmblemState();
}

class _HomeEmblemState extends State<HomeEmblem> with GlyphClockLease {
  bool _visible = true;

  /// Where it stopped, so stilling it (home is covered, or animations are
  /// off) holds the moment it was at instead of snapping to the start.
  double _stilled = 0;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  void _sync() {
    if (!wantsClock) _stilled = GlyphClock.instance.seconds.value;
    syncGlyphClock();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void didUpdateWidget(covariant HomeEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint(bool lifted) => CustomPaint(
      size: Size.square(widget.size),
      willChange: widget.animate && !lifted,
      painter: lifted
          ? null
          : HomeEmblemPainter(
              widget.kind,
              clock: glyphClock,
              time: glyphClock == null ? _stilled : null,
            ),
    );
    final lifted = widget.lifted;
    return RepaintBoundary(
      child: lifted == null
          ? paint(false)
          : ValueListenableBuilder<bool>(
              valueListenable: lifted,
              builder: (_, away, _) => paint(away),
            ),
    );
  }
}

/// Paints an emblem: as an icon (just [kind] and a clock), or at a moment
/// of its passage ([stage]).
class HomeEmblemPainter extends CustomPainter {
  HomeEmblemPainter(
    this.kind, {
    this.clock,
    this.time,
    this.stage,
    this.layer = EmblemLayer.all,
    Listenable? repaint,
  }) : super(repaint: repaint ?? clock);

  final HomeEmblemKind kind;
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The passage's moment on a screen of the given size; null for the
  /// icon, filling its box.
  final EmblemStage Function(Size size)? stage;

  final EmblemLayer layer;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s =
        stage?.call(size) ??
        EmblemStage(
          box: Offset.zero & size,
          screen: size,
          time: time ?? clock?.value ?? 0,
        );
    paintEmblem(canvas, kind, s, layer: layer);
  }

  @override
  bool shouldRepaint(covariant HomeEmblemPainter old) =>
      old.kind != kind ||
      old.clock != clock ||
      old.time != time ||
      old.stage != stage ||
      old.layer != layer;
}

/// Paints [kind] at the moment [s].
void paintEmblem(
  Canvas canvas,
  HomeEmblemKind kind,
  EmblemStage s, {
  EmblemLayer layer = EmblemLayer.all,
}) {
  final back = layer != EmblemLayer.front;
  final front = layer != EmblemLayer.back;
  switch (kind) {
    case HomeEmblemKind.constellation:
      _ConstellationScene.paint(canvas, s, back: back, front: front);
    case HomeEmblemKind.altar:
      _AltarScene.paint(canvas, s, back: back, front: front);
    case HomeEmblemKind.rite:
      _RiteScene.paint(canvas, s, back: back, front: front);
  }
}

// ── shared ──────────────────────────────────────────────────────────────────

double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

double _smooth(double e0, double e1, double x) {
  final t = _clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
}

double _ease(double x) {
  final t = _clamp01(x);
  return t < 0.5 ? 4 * t * t * t : 1 - math.pow(-2 * t + 2, 3) / 2;
}

double _h(int i, int salt) {
  final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

final Paint _glowPaint = Paint();

/// A soft light: one radial gradient, no blur.
void _glow(Canvas canvas, Offset c, double r, Color color, double alpha) {
  if (alpha <= 0.002 || r <= 0) return;
  canvas.drawCircle(
    c,
    r,
    _glowPaint
      ..shader = ui.Gradient.radial(
        c,
        r,
        [
          color.withValues(alpha: alpha.clamp(0.0, 1.0)),
          color.withValues(alpha: alpha.clamp(0.0, 1.0) * 0.35),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.4, 1.0],
      ),
  );
  _glowPaint.shader = null;
}

Color _a(Color c, double alpha) =>
    c.withValues(alpha: (c.a * alpha).clamp(0.0, 1.0));

// ── UPGRADE: a window onto the chart's sky ──────────────────────────────────

class _ConstellationScene {
  _ConstellationScene._();

  /// The chart's sky, sown in a disc as wide as the screen's half-diagonal
  /// round its middle, so a disc that grows to cover the screen is that sky
  /// at its own size. The icon shows the sky in little: the first
  /// [_iconCount] of the same stars.
  static const int _count = 560;
  static const int _iconCount = 104;

  /// The chart's star colours (StarfieldBackground): parchment, a few warm.
  static const Color _parchment = Color(0xFFE8DCC8);
  static const Color _warm = Color(0xFFE9B860);

  /// The chart's ground (the screen's bg0) and the disc's, a shade deeper so
  /// it reads as a way through on home.
  static const Color _ink = Color(0xFF09090B);
  static const Color _hole = Color(0xFF050507);

  /// Each tree's light, faint in the sky as the chart's nebulae are
  /// (constellation_art's kTreeLights essences), at (x, y) in the disc.
  static const List<(double, double, Color)> _hazes = [
    (-0.05, -0.32, Color(0xFF4FC6B0)),
    (0.42, 0.34, Color(0xFFE5AC4A)),
    (-0.44, 0.38, Color(0xFFDE6747)),
  ];

  static late final Float32List _x, _y, _ph, _sp;
  static late final Uint8List _cls, _hue;
  static bool _seeded = false;

  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final rng = math.Random(7);
    _x = Float32List(_count);
    _y = Float32List(_count);
    _ph = Float32List(_count);
    _sp = Float32List(_count);
    _cls = Uint8List(_count);
    _hue = Uint8List(_count);
    for (var i = 0; i < _count; i++) {
      final r = math.sqrt(rng.nextDouble());
      final a = rng.nextDouble() * math.pi * 2;
      _x[i] = math.cos(a) * r;
      _y[i] = math.sin(a) * r;
      _ph[i] = rng.nextDouble() * math.pi * 2;
      _sp[i] = 0.4 + rng.nextDouble() * 1.6;
      // The chart's three depths: mostly far and faint, a few near.
      final d = rng.nextDouble();
      _cls[i] = d < 0.55 ? 0 : (d < 0.9 ? 1 : 2);
      _hue[i] = rng.nextDouble() < 0.16 ? 1 : 0;
    }
  }

  // Buckets: (colour, size class, brightness step).
  static int _bucket(int hue, int cls, int step) => (hue * 3 + cls) * 3 + step;
  static final GrainBatch _b = GrainBatch(18);

  static void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    _seed();
    final t = s.time;
    final e = s.grow;
    final l = _ease(s.land);
    final screen = s.screen;
    final r0 = s.box.shortestSide / 2;
    final half =
        math.sqrt(screen.width * screen.width + screen.height * screen.height) /
        2;

    // The disc: from the icon's place to past the screen's corners.
    final c = Offset.lerp(
      s.box.center,
      Offset(screen.width / 2, screen.height / 2),
      e,
    )!;
    final r = _lerp(r0 * 0.86, half * 1.14, e);
    // The sky inside it, sown to [half] round the middle once grown.
    final sky = _lerp(r0 * 0.8, half * 1.02, e);

    if (back) {
      if (s.ground > 0) {
        // Home sinks a little as the disc opens over it.
        canvas.drawRect(
          Offset.zero & screen,
          Paint()..color = _ink.withValues(alpha: 0.55 * s.ground),
        );
      }
      // A faint light round its edge, so a dark disc reads on home: a
      // gradient, not a ring. It goes as the disc opens.
      final rim = 1 - _smooth(0, 0.5, s.open);
      if (rim > 0) {
        canvas.drawCircle(
          c,
          r * 1.3,
          _glowPaint
            ..shader = ui.Gradient.radial(
              c,
              r * 1.3,
              [
                const Color(0x00000000),
                const Color(0xFFCDB07A).withValues(alpha: 0.2 * rim),
                const Color(0xFF4FC6B0).withValues(alpha: 0.06 * rim),
                const Color(0x00000000),
              ],
              const [0.66, 0.77, 0.86, 1.0],
            ),
        );
        _glowPaint.shader = null;
      }
      // The disc itself, soft at its edge.
      canvas.drawCircle(
        c,
        r,
        _glowPaint
          ..shader = ui.Gradient.radial(
            c,
            r,
            [
              Color.lerp(_hole, _ink, e)!,
              Color.lerp(_hole, _ink, e)!,
              _hole.withValues(alpha: 0),
            ],
            const [0.0, 0.9, 1.0],
          ),
      );
      _glowPaint.shader = null;
      // The trees' light, faint in it. The chart opens on Alchemy's tree,
      // so only its verdigris is still there once the disc has opened.
      for (final (i, (hx, hy, color)) in _hazes.indexed) {
        _glow(
          canvas,
          c + Offset(hx, hy) * sky,
          sky * 0.62,
          color,
          (i == 0 ? _lerp(0.13, 0.07, e) : 0.13 * (1 - e)) * (1 - l),
        );
      }
    }
    if (!front || l >= 1) return;

    final b = _b..clear();
    final n = _lerp(_iconCount.toDouble(), _count.toDouble(), e).round();
    for (var i = 0; i < n; i++) {
      final cls = _cls[i];
      // Twinkling as the chart's stars do.
      final tw = math.sin(t * _sp[i] + _ph[i]);
      final tw2 = math.sin(t * _sp[i] * 0.7 + _ph[i] + 1) * 0.3;
      final lit = (((tw + tw2).clamp(-1.0, 1.0) + 1) / 2);
      final step = (lit * 2.99).floor();
      b.add(
        _bucket(_hue[i], cls, step),
        c.dx + _x[i] * sky,
        c.dy + _y[i] * sky,
      );
    }
    final fade = 1 - l;
    final grow = _lerp(0.72, 1.0, e);
    const sizes = [1.1, 1.8, 2.7];
    const alphas = [0.32, 0.5, 0.78];
    for (var hue = 0; hue < 2; hue++) {
      for (var cls = 0; cls < 3; cls++) {
        for (var step = 0; step < 3; step++) {
          b.draw(
            canvas,
            _bucket(hue, cls, step),
            sizes[cls] * grow,
            (hue == 0 ? _parchment : _warm).withValues(
              alpha: alphas[cls] * (0.6 + 0.2 * step) * fade,
            ),
          );
        }
      }
    }
  }
}

// ── RELICS: the altar in little ─────────────────────────────────────────────

class _AltarScene {
  _AltarScene._();

  static const int _ringCount = 1500;
  static const int _heartCount = 760;
  static const double _span = math.pi * 2 / 16;

  static final List<AltarEntry> _seats = [
    for (final e in kAltarEntries)
      if (e.element.toLowerCase() != 'blood') e,
  ];
  static final List<List<Color>> _ramps = [
    for (final e in _seats) altarRamp(e.element),
  ];
  static final List<Color> _accents = [
    for (final e in _seats) altarAccent(e.element),
  ];

  static late final Float32List _rr, _ra, _rph, _hr, _ha, _hph;
  static bool _seeded = false;

  /// The same lanes the hub's ring is sown in, so the one becomes the other.
  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final rng = math.Random(41);
    const lanes = [(1.0, 0.12, 1.0), (0.8, 0.035, 0.3), (1.18, 0.05, 0.28)];
    final total = lanes.fold(0.0, (s, l) => s + l.$3);
    _rr = Float32List(_ringCount);
    _ra = Float32List(_ringCount);
    _rph = Float32List(_ringCount);
    for (var i = 0; i < _ringCount; i++) {
      var pick = rng.nextDouble() * total;
      var r = 1.0;
      for (final (c, w, weight) in lanes) {
        pick -= weight;
        if (pick <= 0) {
          r = c + (rng.nextDouble() + rng.nextDouble() - 1) * w;
          break;
        }
      }
      _rr[i] = r;
      _ra[i] = rng.nextDouble() * math.pi * 2;
      _rph[i] = rng.nextDouble();
    }
    final hr = math.Random(17);
    _hr = Float32List(_heartCount);
    _ha = Float32List(_heartCount);
    _hph = Float32List(_heartCount);
    for (var i = 0; i < _heartCount; i++) {
      _hr[i] = 0.3 + 0.7 * math.pow(hr.nextDouble(), 0.8).toDouble();
      _ha[i] = hr.nextDouble() * math.pi * 2;
      _hph[i] = hr.nextDouble();
    }
  }

  // Buckets: ash far/near (4 each), a seat's stretch far/near (16 each),
  // the heart's 6 heat steps, its rim (2), glints, dust.
  static const int _ashB = 0, _tintB = 8, _heartB = 40, _rimB = 46;
  static const int _glintB = 48, _dustB = 49;
  static final GrainBatch _b = GrainBatch(50);
  static final GrainBatch _seatB = GrainBatch(2);

  static const List<Color> _heartPal = [
    Color(0xFF1D1530),
    Color(0xFF3B2A63),
    Color(0xFF6A4FB0),
    Color(0xFF9C82E0),
    Color(0xFFCDBCFF),
    Color(0xFFF4EEFF),
  ];

  static void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    _seed();
    final t = s.time;
    final e = s.grow;
    final fade = 1 - _smooth(0, 1, s.land);
    final r0 = s.box.shortestSide / 2;

    // From the icon's place to the hub's own ring.
    final hub = AltarHubField.ringFor(altarHubStage(s.screen, s.pad));
    final c =
        Offset.lerp(s.box.center + Offset(0, r0 * 0.06), hub.centre, e)! +
        Offset(0, -math.sin(math.pi * e) * s.screen.height * 0.04);
    final r = _lerp(r0 * 0.74, hub.radius, e);
    final flat = _lerp(0.6, AltarHubField.flat, e);
    final dot = _lerp(math.max(0.9, r0 * 0.026), math.max(1.1, r * 0.0085), e);
    final rot = t * 0.1;

    if (back && s.ground > 0) {
      final g = s.ground;
      canvas.drawRect(
        Offset.zero & s.screen,
        Paint()..color = AltarTone.void0.withValues(alpha: g),
      );
      final reach = s.screen.longestSide * 0.75;
      canvas.drawCircle(
        c,
        reach,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            reach,
            [
              AltarTone.violetDeep.withValues(alpha: 0.2 * g),
              AltarTone.violetDeep.withValues(alpha: 0.1 * g),
              const Color(0x00000000),
            ],
            const [0.0, 0.42, 1.0],
          ),
      );
      final b = _b..clear();
      for (var i = 0; i < 150; i++) {
        final s1 = (i * 0.6180339887) % 1.0;
        final s2 = (i * 0.7548776662 + 0.3) % 1.0;
        final y = (s2 - t * (0.006 + 0.01 * s1)) % 1.0;
        final x = (s1 + 0.02 * math.sin(t * 0.3 + i)) % 1.0;
        b.add(_dustB, x * s.screen.width, y * s.screen.height);
      }
      b.draw(
        canvas,
        _dustB,
        math.max(1.0, hub.radius * 0.007),
        const Color(0xFF8F86A8).withValues(alpha: 0.32 * g),
      );
    }
    if (!front || fade <= 0.01) return;

    final b = _b..clear();
    // The ring: ash, each seat's stretch tinted in its element.
    final n = _lerp(520, _ringCount.toDouble(), e).round();
    for (var i = 0; i < n; i++) {
      final rr = _rr[i];
      final local = _ra[i] + t * 0.16 / (rr * math.sqrt(rr));
      final a = local + rot;
      final cs = math.cos(a);
      final x = c.dx + r * rr * math.sin(a);
      final y = c.dy + r * flat * rr * cs;
      final near = cs >= 0;
      if ((t * 0.31 + _rph[i] * 9.1) % 1.0 < 0.006) {
        b.add(_glintB, x, y);
        continue;
      }
      final rel = (local % (math.pi * 2)) / _span;
      final k = rel.round() % 16;
      final off = (rel - rel.roundToDouble()).abs() * 2;
      final close = (1 - off) * (1 - ((rr - 1).abs() * 3).clamp(0.0, 1.0));
      if (close > 0.35 + 0.4 * _rph[i]) {
        b.add(_tintB + (near ? 16 : 0) + k, x, y);
      } else {
        final step = ((cs + 1) * 1.2 + _rph[i] * 1.4).floor().clamp(0, 3);
        b.add(_ashB + (near ? 4 : 0) + step, x, y);
      }
    }

    void drawRing({required bool near}) {
      final dim = (near ? 1.0 : 0.62) * fade;
      final half = near ? 4 : 0;
      for (var st = 0; st < 4; st++) {
        b.draw(
          canvas,
          _ashB + half + st,
          dot,
          Color.lerp(
            const Color(0xFF2A2536),
            const Color(0xFF8A8098),
            st / 3,
          )!.withValues(alpha: (0.46 + 0.17 * st) * dim),
        );
      }
      for (var k = 0; k < 16; k++) {
        b.draw(
          canvas,
          _tintB + (near ? 16 : 0) + k,
          dot,
          _a(_ramps[k][near ? 2 : 1], 0.9 * dim),
        );
      }
    }

    // Seats: a relic over its stretch, larger toward the front.
    double seatDepth(int i) => (math.cos(rot + i * _span) + 1) / 2;
    void drawSeat(int i) {
      final a = rot + i * _span;
      final depth = seatDepth(i);
      final sc = 0.55 + 0.45 * depth;
      final floor = c + Offset(r * math.sin(a), r * flat * math.cos(a));
      final bob = math.sin(t * 1.3 + i * 0.7) * r * 0.012;
      final at = floor - Offset(0, r * 0.075 * sc + bob);
      final dim = (0.55 + 0.45 * depth) * fade;
      _glow(canvas, at, r * 0.085 * sc, _accents[i], 0.42 * dim);
      final bs = _seatB..clear();
      for (var j = 0; j < 5; j++) {
        final g = i * 5 + j;
        final ang = _h(g, 80) * math.pi * 2 + t * 0.6;
        final rr = r * 0.022 * sc * math.sqrt(_h(g, 81));
        bs.add(0, at.dx + math.cos(ang) * rr, at.dy + math.sin(ang) * rr);
      }
      bs.add(1, at.dx, at.dy);
      bs.draw(canvas, 0, dot * 1.1, _a(_ramps[i][2], dim));
      bs.draw(canvas, 1, dot * 1.9 * sc, _a(_ramps[i][3], dim));
    }

    final order = List.generate(16, (i) => i)
      ..sort((x, y) => seatDepth(x).compareTo(seatDepth(y)));

    drawRing(near: false);
    for (final i in order) {
      if (seatDepth(i) < 0.5) drawSeat(i);
    }

    // The heart: the arcane disk feeding a black well, beating.
    final p = (t / 2.6) % 1.0;
    double bump(double at) =>
        math.exp(-math.pow((p - at) / 0.045, 2)).toDouble();
    final beat = bump(0.1) + 0.6 * bump(0.24);
    final hr = r * _lerp(0.42, 0.34, e) * (1 + 0.05 * beat);
    _glow(
      canvas,
      c,
      hr * (2.6 + 0.5 * beat),
      AltarTone.violet,
      (0.16 + 0.14 * beat) * fade,
    );
    final hn = _lerp(320, _heartCount.toDouble(), e).round();
    for (var i = 0; i < hn; i++) {
      final rr = _hr[i];
      final a = _ha[i] + t * 0.55 / (rr * math.sqrt(rr));
      final x = c.dx + hr * rr * math.cos(a);
      final y = c.dy + hr * flat * rr * math.sin(a);
      final heat = ((1 - rr) / 0.7).clamp(0.0, 1.0);
      final nearSide = math.sin(a) > 0 ? 1 : 0;
      final tone = (math.pow(heat, 1.2) * 5 + 0.9 * beat + nearSide * 0.6)
          .clamp(0.0, 5.0)
          .floor();
      if ((t * 0.4 + _hph[i] * 7.7) % 1.0 < 0.004) {
        b.add(_glintB, x, y);
      } else {
        b.add(_heartB + tone, x, y);
      }
    }
    for (var k = 0; k < 6; k++) {
      b.draw(canvas, _heartB + k, dot * 0.95, _a(_heartPal[k], fade));
    }
    final core = hr * 0.21;
    canvas.drawCircle(
      c,
      core * 1.12,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          core * 1.12,
          [
            const Color(0xFF010102).withValues(alpha: fade),
            const Color(0xFF010102).withValues(alpha: fade),
            const Color(0x00010102),
          ],
          const [0.0, 0.84, 1.0],
        ),
    );
    final rimN = _lerp(60, 150, e).round();
    for (var i = 0; i < rimN; i++) {
      final seed = (i * 0.7548776) % 1.0;
      final a = seed * math.pi * 2 + t * (1.2 + seed);
      final dd = core * (1.02 + 0.12 * ((i * 0.5698) % 1.0));
      final sa = math.sin(a);
      b.add(
        sa.abs() > 0.7 ? _rimB + 1 : _rimB,
        c.dx + math.cos(a) * dd,
        c.dy + sa * dd,
      );
    }
    b.draw(canvas, _rimB, dot * 0.75, _a(_heartPal[4], 0.45 * fade));
    b.draw(canvas, _rimB + 1, dot * 0.85, _a(_heartPal[5], fade));

    drawRing(near: true);
    for (final i in order) {
      if (seatDepth(i) >= 0.5) drawSeat(i);
    }
    b.draw(
      canvas,
      _glintB,
      dot * 2.6,
      Color.fromRGBO(255, 255, 255, 0.19 * fade),
    );
    b.draw(canvas, _glintB, dot * 1.4, _a(const Color(0xFFFFFBEA), fade));
  }
}

// ── RITE: the drop ──────────────────────────────────────────────────────────

class _RiteScene {
  _RiteScene._();

  /// The bulb's radius; the drop's point stands [_apex] above the bulb's
  /// middle, which is the drop's origin.
  static const double _bulb = 0.62;
  static const double _apex = 1.35;

  /// The drop's own grains; the pool it floods into has more (RitePool).
  static const int _count = 1100;

  static const Color _void = Color(0xFF080808);
  static const Color _soulBlue = RitePool.soulBlue;
  static const Color _soulGold = RitePool.soulGold;
  static const List<Color> _blood = RitePool.blood;

  /// The drop's half-width at height [y] (bulb middle 0, point -[_apex]).
  static double _width(double y) {
    if (y >= 0) {
      return math.sqrt(math.max(0, _bulb * _bulb - y * y));
    }
    final u = (y + _apex) / _apex;
    return _bulb * math.pow(math.sin(math.pi / 2 * u), 1.5).toDouble();
  }

  // Each grain's place in the drop, and a phase. Grain i becomes grain i
  // of the pool.
  static late final Float32List _x, _y, _ph;
  static late final Uint8List _inBulb;
  static bool _seeded = false;

  static void _seed() {
    if (_seeded) return;
    _seeded = true;
    final rng = math.Random(23);
    _x = Float32List(_count);
    _y = Float32List(_count);
    _ph = Float32List(_count);
    _inBulb = Uint8List(_count);
    var i = 0;
    while (i < _count) {
      final x = (rng.nextDouble() * 2 - 1) * _bulb;
      final y = -_apex + rng.nextDouble() * (_apex + _bulb);
      if (x.abs() > _width(y)) continue;
      _x[i] = x;
      _y[i] = y;
      _inBulb[i] = x * x + y * y <= _bulb * _bulb ? 1 : 0;
      _ph[i] = rng.nextDouble();
      i++;
    }
  }

  // Buckets: blood's 6 tones, then motes (blue, gold) and their trails.
  static const int _moteB = 6, _trailB = 8;
  static final GrainBatch _b = GrainBatch(9);

  static void paint(
    Canvas canvas,
    EmblemStage s, {
    required bool back,
    required bool front,
  }) {
    _seed();
    final t = s.time;
    final o = _clamp01(s.open);
    final fade = 1 - _smooth(0, 1, s.land);
    final screen = s.screen;
    final w = screen.width, h = screen.height;
    final r0 = s.box.shortestSide / 2;

    final pool = ritePoolFor(screen, s.pad);
    final poolC = pool.centre;
    final iconK = r0 * 0.58;
    final hangK = math.min(w, h) * 0.15;

    final double lift, impact, spread, stretch, k;
    Offset c;
    if (!s.closing) {
      // In its box the drop hangs, breathing. Carried in, it lifts out over
      // the screen (to 0.4), falls (to 0.62), and floods out into the rite's
      // own pool (to 1) — the one its screen opens on, at the same place, so
      // it hands over without a seam.
      lift = _ease(o / 0.4);
      final fall = _clamp01((o - 0.4) / 0.22);
      impact = _smooth(0.58, 0.72, o);
      spread = _ease((o - 0.6) / 0.4);
      final bob = math.sin(t * 1.05) * r0 * 0.03 * (1 - lift);
      final iconC = s.box.center + Offset(0, iconK * (_apex - _bulb) / 2 + bob);
      final hangC = Offset(
        w / 2,
        math.max(s.pad.top + hangK * _apex + 12, poolC.dy - h * 0.25),
      );
      k = _lerp(iconK, hangK, lift);
      // It swings out to the left as it rises, clear of the column above it.
      final swing = math.sin(math.pi * lift);
      c =
          Offset.lerp(iconC, hangC, lift)! +
          Offset(-swing * w * 0.14, -swing * h * 0.03);
      // Falling, it quickens, and draws long; its bottom meets the pool.
      c = Offset(c.dx, _lerp(c.dy, poolC.dy - _bulb * k, fall * fall));
      stretch = 1 + 0.22 * fall * (1 - impact);
    } else {
      // Going back it does not fall upward, and nothing springs. One
      // unbroken movement in overlapping parts, [p] 0..1 of the way home:
      // the pool draws in on itself (to 0.5); its middle stands up as the
      // drop (0.25 to 0.55), no larger than it needs to be; and the drop,
      // already moving as it forms, glides home (0.4 to 1) — down first,
      // then in from the left, under the column rather than over the
      // RELICS ring — shrinking steadily into its box. No squash, no
      // stretch.
      final p = 1 - o;
      spread = 1 - _smooth(0.0, 0.5, p);
      impact = 1 - _smooth(0.25, 0.55, p);
      final travel = _smooth(0.4, 1.0, p);
      lift = 1 - travel;
      final formK = math.min(w, h) * 0.11;
      final iconC = s.box.center + Offset(0, iconK * (_apex - _bulb) / 2);
      final risen = Offset(poolC.dx, poolC.dy - _bulb * formK);
      k = _lerp(formK, iconK, travel);
      final bend = Offset(risen.dx, iconC.dy);
      final u = 1 - travel;
      c = risen * (u * u) + bend * (2 * u * travel) + iconC * (travel * travel);
      stretch = 1;
    }
    final pr = _lerp(k * 0.8, pool.radius, math.pow(spread, 0.85).toDouble());
    final dot = _lerp(math.max(0.9, r0 * 0.028), 1.6, lift);

    if (back && s.ground > 0) {
      canvas.drawRect(
        Offset.zero & screen,
        Paint()..color = _void.withValues(alpha: s.ground),
      );
    }
    if (back) {
      // Its warmth round the drop, then the pool's own light.
      _glow(canvas, c, k * 1.25, _blood[2], 0.3 * (1 - impact));
      RitePool.paintGlow(canvas, poolC, pr, alpha: impact * fade);
    }
    if (!front || fade <= 0) return;

    final b = _b..clear();
    final n = _lerp(
      _lerp(700, 1100, lift),
      RitePool.count.toDouble(),
      spread,
    ).round();
    final swirl = t * 0.3;
    final narrow = 1 / math.sqrt(stretch);
    for (var i = 0; i < n; i++) {
      var px = 0.0, py = 0.0;
      var tone = 0;
      if (impact < 1 && i < _count) {
        var x = _x[i].toDouble(), y = _y[i].toDouble();
        final ph = _ph[i].toDouble();
        if (_inBulb[i] == 1) {
          // The bulb's blood turns slowly within it, faster in the middle.
          final rr = math.sqrt(x * x + y * y) / _bulb;
          final a = swirl * (0.4 + 0.6 * (1 - rr)) + ph * 0.3;
          final ca = math.cos(a), sa = math.sin(a);
          final nx = x * ca - y * sa;
          y = x * sa + y * ca;
          x = nx;
        } else {
          y += math.sin(t * 1.6 + ph * 9) * 0.015;
        }
        // Lit from up and to the left; the shade follows where the grain
        // is now, so the light stays put as the blood turns under it. Its
        // dark side stays a deep red, so the drop keeps its shape.
        final edge = _width(y) - x.abs();
        var lum = 0.5 - 0.42 * x / _bulb - 0.3 * (y + 0.3) / _bulb;
        if (edge < 0.05) lum += x < 0 ? 0.25 : 0.05;
        tone = 1 + (lum * 3.6).floor().clamp(0, 3);
        final spec = (x + 0.24) * (x + 0.24) + (y + 0.18) * (y + 0.18);
        if (spec < 0.006) tone = 5;
        px = c.dx + x * k * narrow;
        py = c.dy + y * k * stretch;
      }
      if (impact > 0) {
        // The pool: the same grain, in the same place, as the screen's.
        var q = RitePool.grainAt(i, poolC, pr, t);
        // A low crown where it struck, rising and falling back.
        if (_h(i, 95) < 0.05) {
          final up = math.sin(math.pi * _clamp01((o - 0.6) / 0.28));
          q = q.translate(0, -up * k * (0.5 + 0.7 * _h(i, 96)));
        }
        final poolTone = RitePool.toneAt(i, t);
        if (impact >= 1 || i >= _count) {
          px = q.dx;
          py = q.dy;
          tone = poolTone;
        } else {
          px = _lerp(px, q.dx, impact);
          py = _lerp(py, q.dy, impact);
          if (impact > 0.5) tone = poolTone;
        }
      }
      b.add(tone, px, py);
    }
    final grainDot = _lerp(dot, 1.6, spread);
    for (var k2 = 0; k2 < 6; k2++) {
      b.draw(canvas, k2, grainDot, _a(_blood[k2], fade));
    }

    // Souls: a few round the drop in its box, then the pool's own.
    final m = _b..clear();
    final mine = 1 - spread;
    if (mine > 0) {
      final top = _lerp(s.box.top, 0, lift);
      final bottom = s.box.bottom - r0 * 0.15;
      final span = bottom - top;
      final cx = _lerp(s.box.center.dx, w / 2, lift);
      final wide = _lerp(r0 * 0.85, w * 0.3, lift);
      for (var i = 0; i < 9; i++) {
        final speed = 0.16 + 0.1 * _h(i, 100);
        final x0 = (_h(i, 102) * 2 - 1) * wide;
        final gold = _h(i, 103) >= 0.7;
        for (var j = 0; j < 3; j++) {
          final life = (t * speed + _h(i, 101) - j * 0.014) % 1.0;
          final bright = math.sin(math.pi * life);
          if (bright < 0.2) continue;
          final x = cx + x0 + math.sin(life * 5 + i) * wide * 0.12;
          final y = bottom - span * (0.1 + 0.9 * life);
          m.add(j == 0 ? _moteB + (gold ? 1 : 0) : _trailB, x, y);
        }
      }
      m.draw(canvas, _trailB, dot * 0.9, _a(_soulBlue, 0.3 * mine));
      m.draw(canvas, _moteB, dot * 1.4, _a(_soulBlue, 0.85 * mine));
      m.draw(canvas, _moteB + 1, dot * 1.4, _a(_soulGold, 0.85 * mine));
    }
    RitePool.paintSouls(
      canvas,
      poolC,
      pool.radius,
      s.pad.top + kRiteHeaderHeight,
      t,
      alpha: spread * fade,
    );
  }
}
