// lib/widgets/dock_emblems.dart
//
// Two of the dock's icons, drawn as living scenes of grains — the particle
// language of the title, the cultivation sphere, the rifts and the infusion
// — with nothing framing them:
//
//   field     the wilds at dawn: three hills lit along their crests, stars
//             still out, fireflies — fading softly into the screen at its
//             edges, since nothing frames it
//   enhance   a creature made of grains, a wave of light rising through it
//             and lifting off its crown — the infusion; black grains on the
//             light theme
//   harvest   the harvest chamber's own flask of dark glass, its liquid a
//             swirl of grains, essence falling into its neck — drawn by the
//             chamber's painter (paintFlaskEmblem), so its way in can land
//             on the chamber's flask
//   survival  the player's own orb — the core they have equipped, drawn by
//             the painter that draws it in the survival hub and in a run
//
// Field, Harvest and Survival are also their own ways in
// (widgets/dock_passages.dart): the scene the player touched is what
// carries them to its screen.
//
// (A glass-lens frame round these was tried and taken off — "just the
// animation".)
//
// One shared clock (GlyphClock), stopped while the home screen is covered.
// Points in batches and gradients; no blur, no stroked outlines.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DockEmblemKind { field, enhance, harvest, survival }

extension DockEmblemKindX on DockEmblemKind {
  /// The scene's light.
  Color get accent => switch (this) {
    DockEmblemKind.field => const Color(0xFF6FD3A8),
    DockEmblemKind.enhance => const Color(0xFFB98CFF),
    DockEmblemKind.harvest => const Color(0xFFF0B254),
    DockEmblemKind.survival => const Color(0xFFFFD27A),
  };
}

class DockEmblem extends StatefulWidget {
  const DockEmblem({
    super.key,
    required this.kind,
    required this.size,
    this.animate = true,
    this.dark = true,
    this.orb = OrbBaseSkin.defaultOrb,
  });

  final DockEmblemKind kind;
  final double size;
  final bool animate;

  /// The survival orb the player has equipped (the Survival emblem).
  final OrbBaseSkin orb;

  /// The theme it sits on. On the light one, Enhance's creature is drawn in
  /// black grains.
  final bool dark;

  /// The creature the Enhance emblem is made of.
  static const String enhanceCreature =
      'assets/images/creatures/rare/HOR16_lighthorn.png';

  static Future<SpecimenGrains>? _creature, _fineCreature;

  /// The Enhance creature read into grains, once. [fine] reads it closely
  /// enough to stand over the whole screen, for its way in
  /// (widgets/dock_passages.dart).
  static Future<SpecimenGrains> creatureGrains({bool fine = false}) => fine
      ? _fineCreature ??= _readCreature(width: 260, grains: 2600)
      : _creature ??= _readCreature(width: 96, grains: 520);

  static Future<SpecimenGrains> _readCreature({
    required int width,
    required int grains,
  }) async {
    final data = await rootBundle.load(enhanceCreature);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final image = (await codec.getNextFrame()).image;
    try {
      final rgba = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      return SpecimenGrains.fromRgba(
        rgba!.buffer.asUint8List(),
        image.width,
        image.height,
        pixelRatio: 1,
        maxGrains: grains,
        tones: 8,
      );
    } finally {
      image.dispose();
    }
  }

  @override
  State<DockEmblem> createState() => _DockEmblemState();
}

class _DockEmblemState extends State<DockEmblem> with GlyphClockLease {
  bool _visible = true;
  SpecimenGrains? _creature;

  @override
  bool get wantsClock => widget.animate && _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
    if (widget.kind == DockEmblemKind.enhance) {
      DockEmblem.creatureGrains().then((g) {
        if (mounted) setState(() => _creature = g);
      }, onError: (_) {});
      // Read ahead for its way in, so the passage never waits on it.
      DockEmblem.creatureGrains(fine: true).ignore();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      syncGlyphClock();
    }
  }

  @override
  void didUpdateWidget(covariant DockEmblem oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        willChange: widget.animate,
        painter: DockEmblemPainter(
          widget.kind,
          clock: glyphClock,
          creature: _creature,
          dark: widget.dark,
          orb: widget.orb,
        ),
      ),
    );
  }
}

class DockEmblemPainter extends CustomPainter {
  DockEmblemPainter(
    this.kind, {
    this.clock,
    this.time,
    this.creature,
    this.dark = true,
    this.orb = OrbBaseSkin.defaultOrb,
  }) : super(repaint: clock);

  /// The theme it sits on (see [DockEmblem.dark]).
  final bool dark;

  /// The equipped survival orb.
  final OrbBaseSkin orb;

  final DockEmblemKind kind;
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The Enhance creature, once read.
  final SpecimenGrains? creature;

  static final GrainBatch _b = GrainBatch(16);
  static final Paint _p = Paint();

  static double _h(int i, int salt) {
    final x = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return x - x.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = time ?? clock?.value ?? 0;
    final c = size.center(Offset.zero);
    // The scene has the whole box — nothing frames it — and fills it as
    // the painted icons beside it fill theirs.
    switch (kind) {
      case DockEmblemKind.field:
        paintField(canvas, Offset.zero & size, t);
      case DockEmblemKind.enhance:
        _enhance(canvas, c, s * 0.5, t);
      case DockEmblemKind.harvest:
        final f = dockFlaskIn(Offset.zero & size);
        paintFlaskEmblem(
          canvas,
          f.centre,
          f.radius,
          t,
          ink: DockEmblemKind.harvest.accent,
          level: dockFlaskLevel(t),
        );
      case DockEmblemKind.survival:
        final o = dockOrbIn(Offset.zero & size);
        paintDockOrb(canvas, o.centre, o.radius, orb, t);
    }
  }

  /// The field scene in [box], fading softly into the screen at its edges
  /// (nothing frames it); [alpha] fades the whole.
  static void paintField(
    Canvas canvas,
    Rect box,
    double t, {
    double alpha = 1,
  }) {
    if (alpha <= 0.004) return;
    final c = box.center;
    final s = box.shortestSide;
    canvas.saveLayer(
      box,
      Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0.0, 1.0)),
    );
    _field(canvas, c, s * 0.5, t);
    canvas.drawRect(
      box,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          c,
          s * 0.5,
          const [Color(0xFF000000), Color(0xFF000000), Color(0x00000000)],
          const [0.0, 0.55, 1.0],
        ),
    );
    canvas.restore();
  }

  // ── field: the wilds at dawn ─────────────────────────────────────────

  static void _field(Canvas canvas, Offset c, double r, double t) {
    // Dawn behind the hills, and a few stars still out above.
    final sun = c + Offset(r * 0.2, r * 0.02);
    canvas.drawCircle(
      sun,
      r * 1.0,
      _p
        ..shader = ui.Gradient.radial(
          sun,
          r * 1.0,
          const [
            Color(0xFFFFE6B0),
            Color(0xB3F0A46E),
            Color(0x40407F80),
            Color(0x00000000),
          ],
          const [0.0, 0.16, 0.5, 1.0],
        ),
    );
    _p.shader = null;
    final b = _b..clear();
    for (var i = 0; i < 10; i++) {
      final x = c.dx - r * 0.75 + _h(i, 33) * r * 1.5;
      final y = c.dy - r * 0.85 + _h(i, 34) * r * 0.5;
      if ((t * 0.5 + _h(i, 35) * 4) % 1.0 < 0.8) b.add(7, x, y);
    }
    // Three hills, far to near: each a filled shape, lit at its crest by
    // the dawn, with grains of light along that crest.
    const fills = [
      [Color(0xFF3B7368), Color(0xFF1C3934)],
      [Color(0xFF2A5A50), Color(0xFF122824)],
      [Color(0xFF173A33), Color(0xFF0A1714)],
    ];
    double ridge(int k, double u) =>
        c.dy +
        r * (0.12 + 0.24 * k) -
        r *
            (0.16 - 0.03 * k) *
            (0.6 * math.sin(u * 5.1 + k * 1.7) +
                0.4 * math.sin(u * 11.3 + k * 0.6));
    for (var k = 0; k < 3; k++) {
      final path = Path()..moveTo(c.dx - r, c.dy + r);
      for (var j = 0; j <= 24; j++) {
        final u = j / 24;
        path.lineTo(c.dx - r + u * r * 2, ridge(k, u));
      }
      path
        ..lineTo(c.dx + r, c.dy + r)
        ..close();
      final top = c.dy + r * (0.12 + 0.24 * k) - r * 0.2;
      canvas.drawPath(
        path,
        _p
          ..shader = ui.Gradient.linear(
            Offset(c.dx, top),
            Offset(c.dx, top + r * 0.7),
            fills[k],
          ),
      );
      _p.shader = null;
      // The dawn on its crest, brightest towards the sun.
      for (var i = 0; i < 44; i++) {
        final u = _h(i, 10 + k);
        final x = c.dx - r + u * r * 2;
        final y = ridge(k, u) + _h(i, 20 + k) * r * 0.05;
        final toSun = 1 - ((x - sun.dx).abs() / (r * 1.4)).clamp(0.0, 1.0);
        b.add(k * 2 + (toSun > 0.55 ? 1 : 0), x, y);
      }
    }
    // Fireflies over the near hill.
    for (var i = 0; i < 8; i++) {
      final ph = (t * (0.06 + 0.03 * _h(i, 30)) + _h(i, 31)) % 1.0;
      final x =
          c.dx - r * 0.7 + _h(i, 32) * r * 1.4 + math.sin(t + i) * r * 0.05;
      final y = c.dy + r * 0.45 - ph * r * 0.5;
      if ((t * 0.7 + i * 0.37) % 1.0 < 0.75) b.add(6, x, y);
    }
    final d = math.max(1.0, r * 0.05);
    const crest = [
      [Color(0xFF7FC4A4), Color(0xFFF2D9A0)],
      [Color(0xFF5FA888), Color(0xFFE9C68A)],
      [Color(0xFF3F7C64), Color(0xFFD9AE76)],
    ];
    for (var k = 0; k < 3; k++) {
      b.draw(canvas, k * 2, d * 0.9, crest[k][0]);
      b.draw(canvas, k * 2 + 1, d, crest[k][1]);
    }
    b.draw(canvas, 6, d * 1.15, const Color(0xFFFFF0B0));
    b.draw(canvas, 7, d * 0.7, const Color(0xCCE8F4FF));
  }

  // ── enhance: a creature, made of grains, infused ─────────────────────

  void _enhance(Canvas canvas, Offset c, double r, double t) {
    final g = creature;
    final accent = kind.accent;
    paintEnhanceFloor(canvas, c, r);
    if (g == null) return;
    final b = _b..clear();
    final fit = EnhanceFit(g);
    final scale = fit.scale(r);
    final body = fit.centre(c, r);
    for (var i = 0; i < g.length; i++) {
      final pulse = fit.pulse(i, t);
      final ph = _h(i, 40);
      final lift = pulse * r * (0.04 + (ph > 0.85 ? 0.16 : 0.04));
      final x = body.dx + g.hx[i] * scale;
      final y = body.dy + (g.hy[i] - fit.midY) * scale - lift;
      if (pulse > 0.3) {
        b.add(8 + math.min(3, (pulse * 4).floor()), x, y);
      } else {
        b.add(math.min(7, g.tone[i]), x, y);
      }
    }
    final d = math.max(1.1, g.step * scale * 1.15);
    for (var k = 0; k < math.min(8, g.tones.length); k++) {
      // Its own shading, in a ghost of the infusion's violet so the light
      // running through it carries — or, on the light theme, in black.
      final lum = g.tones[k].computeLuminance();
      b.draw(
        canvas,
        k,
        d,
        dark
            ? enhanceInk(g.tones[k])
            : Color.lerp(
                const Color(0xFF000000),
                const Color(0xFF3A3540),
                (lum * 1.4).clamp(0.0, 1.0),
              )!,
      );
    }
    for (var k = 0; k < 4; k++) {
      // The wave: the stat's violet, deepened on the light theme so it
      // reads against a pale screen.
      b.draw(
        canvas,
        8 + k,
        d * 1.05,
        dark
            ? Color.lerp(accent, Colors.white, 0.15 * k)!
            : Color.lerp(const Color(0xFF4A1F9E), accent, 0.2 * k)!,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DockEmblemPainter old) =>
      old.kind != kind ||
      old.clock != clock ||
      old.time != time ||
      old.creature != creature ||
      old.dark != dark ||
      old.orb != orb;
}

/// How the Enhance creature stands in a scene of radius r round c: the
/// emblem's own fit, shared with its way in so the passage lifts off
/// exactly where the icon stood.
class EnhanceFit {
  EnhanceFit(this.grains) {
    var lo = double.infinity, hi = double.negativeInfinity, wide = 1.0;
    for (var i = 0; i < grains.length; i++) {
      lo = math.min(lo, grains.hy[i]);
      hi = math.max(hi, grains.hy[i]);
      wide = math.max(wide, grains.hx[i].abs());
    }
    minY = lo;
    maxY = hi;
    reach = wide;
  }

  final SpecimenGrains grains;

  /// Its grains' extent, in grain units.
  late final double minY, maxY, reach;

  double get span => math.max(1.0, maxY - minY);
  double get midY => (minY + maxY) / 2;

  /// Grain units to pixels in a scene of radius [r].
  double scale(double r) => math.min(r * 1.6 / span, r * 1.05 / reach);

  /// The middle of its body: grain i stands at
  /// centre + (hx, hy - midY) × scale.
  Offset centre(Offset c, double r) => c + Offset(0, r * 0.08);

  /// Where its light pools: just under its feet.
  static Offset floor(Offset c, double r) => c + Offset(0, r * 0.62);

  /// 0 at its feet .. 1 at its crown.
  double rise(int i) => (maxY - grains.hy[i]) / span;

  /// How lit grain i is by the wave that climbs it every 3.2 s (0..1).
  double pulse(int i, double t) {
    final x0 = ((t % 3.2) / 3.2 * 1.4 - rise(i)) / 0.35;
    return x0 <= 0 || x0 >= 1 ? 0.0 : math.sin(math.pi * x0);
  }
}

/// The Enhance creature's light pooled at its feet — flat, so it reads as
/// light on the ground and not as a disc behind it.
void paintEnhanceFloor(Canvas canvas, Offset c, double r, {double alpha = 1}) {
  if (alpha <= 0) return;
  final accent = DockEmblemKind.enhance.accent;
  final floor = EnhanceFit.floor(c, r);
  canvas.save();
  canvas.translate(floor.dx, floor.dy);
  canvas.scale(1, 0.3);
  canvas.drawCircle(
    Offset.zero,
    r * 0.75,
    Paint()
      ..shader = ui.Gradient.radial(Offset.zero, r * 0.75, [
        accent.withValues(alpha: 0.55 * alpha),
        accent.withValues(alpha: 0),
      ]),
  );
  canvas.restore();
}

/// One of the Enhance creature's own tones, in a ghost of the infusion's
/// violet so the light running through it carries.
Color enhanceInk(Color tone) => Color.lerp(
  const Color(0xFF2A1F44),
  const Color(0xFFB7A2E6),
  (tone.computeLuminance() * 1.4).clamp(0.0, 1.0),
)!;

/// Where the Harvest emblem's flask stands in [box]: its bulb's centre and
/// radius, the neck and the essence falling into it above.
({Offset centre, double radius}) dockFlaskIn(Rect box) {
  final s = box.shortestSide;
  final r = s * 0.34;
  return (
    centre: Offset(box.center.dx, box.top + s * 0.5 + r * 0.35),
    radius: r,
  );
}

/// How full the Harvest emblem's flask stands at [t]: it breathes.
double dockFlaskLevel(double t) => 0.64 + 0.05 * math.sin(t * 0.4);

/// Where the Survival emblem's orb sits in [box]: its core's centre and
/// radius.
({Offset centre, double radius}) dockOrbIn(Rect box) =>
    (centre: box.center, radius: box.shortestSide * 0.3);

/// The equipped orb's core at [centre], [radius] across, in a low pool of
/// its own light — as the survival hub shows it, without its reach.
void paintDockOrb(
  Canvas canvas,
  Offset centre,
  double radius,
  OrbBaseSkin skin,
  double t, {
  double light = 1,
}) {
  final look = orbLook(skin);
  if (light > 0) {
    canvas.drawCircle(
      centre,
      radius * 1.65,
      DockEmblemPainter._p
        ..shader = ui.Gradient.radial(
          centre,
          radius * 1.65,
          [
            look.essence.withValues(alpha: 0.22 * light),
            look.essence.withValues(alpha: 0.06 * light),
            look.essence.withValues(alpha: 0),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    DockEmblemPainter._p.shader = null;
  }
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  paintOrbCore(
    canvas,
    skin,
    t,
    radius: radius,
    beat: (t / 8) - (t / 8).floorToDouble(),
    reach: false,
  );
  canvas.restore();
}
