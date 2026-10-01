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
//   harvest   an alchemist's flask, its glowing liquid a swirl of grains,
//             motes falling into it
//   survival  the Solaris Sentinel — the Light boss in its Armillary form,
//             brass bands turning round a sun — drawn by the same painter
//             that draws it in a run
//
// (A glass-lens frame round these was tried and taken off — "just the
// animation".)
//
// One shared clock (GlyphClock), stopped while the home screen is covered.
// Points in batches and gradients; no blur, no stroked outlines.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/enemy_body_art.dart';
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
  });

  final DockEmblemKind kind;
  final double size;
  final bool animate;

  /// The theme it sits on. On the light one, Enhance's creature is drawn in
  /// black grains.
  final bool dark;

  /// The creature the Enhance emblem is made of.
  static const String enhanceCreature =
      'assets/images/creatures/rare/HOR16_lighthorn.png';

  static Future<SpecimenGrains>? _creature;

  /// The Enhance creature read into grains, once.
  static Future<SpecimenGrains> creatureGrains() => _creature ??= () async {
    final data = await rootBundle.load(enhanceCreature);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 96,
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
        maxGrains: 520,
        tones: 8,
      );
    } finally {
      image.dispose();
    }
  }();

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
  }) : super(repaint: clock);

  /// The theme it sits on (see [DockEmblem.dark]).
  final bool dark;

  final DockEmblemKind kind;
  final ValueListenable<double>? clock;

  /// A fixed time, for a still frame (tests).
  final double? time;

  /// The Enhance creature, once read.
  final SpecimenGrains? creature;

  static final GrainBatch _b = GrainBatch(16);

  /// The Solaris Sentinel's light.
  static final EnemyPalette _solaris = enemyPalette('Light');
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
        // No frame: the scene dissolves into the screen at its edges.
        final box = Offset.zero & size;
        canvas.saveLayer(box, Paint());
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
      case DockEmblemKind.enhance:
        _enhance(canvas, c, s * 0.5, t);
      case DockEmblemKind.harvest:
        _harvest(canvas, c + Offset(0, s * 0.04), s * 0.62, t);
      case DockEmblemKind.survival:
        // Its reach is 1.8 radii; sized so the bands just fill the box.
        final r = s * 0.5 / bossFormReach(BossForm.armillary) * 1.05;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(r);
        paintBossForm(canvas, _solaris, BossForm.armillary, time: t, seed: 0.4);
        canvas.restore();
    }
  }

  // ── field: the wilds at dawn ─────────────────────────────────────────

  void _field(Canvas canvas, Offset c, double r, double t) {
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
    // Its light pooled at its feet — flat, so it reads as light on the
    // ground and not as a disc behind it.
    final floor = c + Offset(0, r * 0.62);
    canvas.save();
    canvas.translate(floor.dx, floor.dy);
    canvas.scale(1, 0.3);
    canvas.drawCircle(
      Offset.zero,
      r * 0.75,
      _p
        ..shader = ui.Gradient.radial(Offset.zero, r * 0.75, [
          accent.withValues(alpha: 0.55),
          accent.withValues(alpha: 0),
        ]),
    );
    _p.shader = null;
    canvas.restore();
    if (g == null) return;
    final b = _b..clear();
    var minY = double.infinity, maxY = double.negativeInfinity;
    var reach = 1.0;
    for (var i = 0; i < g.length; i++) {
      minY = math.min(minY, g.hy[i]);
      maxY = math.max(maxY, g.hy[i]);
      reach = math.max(reach, g.hx[i].abs());
    }
    final span = math.max(1.0, maxY - minY);
    final scale = math.min(r * 1.6 / span, r * 1.05 / reach);
    final midY = (minY + maxY) / 2;
    // The wave climbs it every 3.2 s.
    final wave = (t % 3.2) / 3.2;
    for (var i = 0; i < g.length; i++) {
      final rise = (maxY - g.hy[i]) / span;
      final x0 = (wave * 1.4 - rise) / 0.35;
      final pulse = x0 <= 0 || x0 >= 1 ? 0.0 : math.sin(math.pi * x0);
      final ph = _h(i, 40);
      final lift = pulse * r * (0.04 + (ph > 0.85 ? 0.16 : 0.04));
      final x = c.dx + g.hx[i] * scale;
      final y = c.dy + r * 0.08 + (g.hy[i] - midY) * scale - lift;
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
            ? Color.lerp(
                const Color(0xFF2A1F44),
                const Color(0xFFB7A2E6),
                (lum * 1.4).clamp(0.0, 1.0),
              )!
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

  // ── harvest: an alchemist's flask, filling ───────────────────────────

  void _harvest(Canvas canvas, Offset c, double r, double t) {
    final accent = kind.accent;
    final bulb = c + Offset(0, r * 0.22);
    final br = r * 0.46;
    final neckW = r * 0.16, neckTop = c.dy - r * 0.58;
    // The glass: a round-bottomed flask, dark, lit at its edge.
    final flask = Path()
      ..addOval(Rect.fromCircle(center: bulb, radius: br))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            c.dx - neckW,
            neckTop,
            c.dx + neckW,
            bulb.dy - br * 0.6,
          ),
          Radius.circular(neckW * 0.4),
        ),
      );
    canvas.drawPath(
      flask,
      _p
        ..shader = ui.Gradient.radial(
          bulb + Offset(-br * 0.3, -br * 0.4),
          br * 1.5,
          [
            Color.lerp(accent, const Color(0xFF0B0911), 0.7)!,
            const Color(0xFF120E0A),
          ],
        ),
    );
    _p.shader = null;
    // Its liquid: grains, swirling, filling the bulb's lower part.
    final b = _b..clear();
    final level = bulb.dy - br * (0.05 + 0.15 * math.sin(t * 0.4));
    for (var i = 0; i < 150; i++) {
      final a = _h(i, 50) * math.pi * 2 + t * (0.6 + 0.6 * _h(i, 51));
      final rr = br * 0.88 * math.sqrt(_h(i, 52));
      final x = bulb.dx + math.cos(a) * rr;
      var y = bulb.dy + math.sin(a) * rr * 0.55 + br * 0.25;
      if (y < level) y = level + (level - y) * 0.2;
      final hot = (t * 0.35 + _h(i, 53) * 5) % 1.0 < 0.05;
      b.add(hot ? 3 : (rr / br * 2.99).floor(), x, y);
    }
    // Motes falling into its neck.
    for (var i = 0; i < 8; i++) {
      final ph = (t * 0.5 + i / 8) % 1.0;
      final x = c.dx + math.sin(t * 2 + i * 1.7) * neckW * 0.4;
      final y = neckTop - r * 0.32 + ph * (level - neckTop + r * 0.32);
      b.add(4, x, y);
    }
    final d = math.max(1.0, r * 0.06);
    b.draw(canvas, 2, d, Color.lerp(accent, const Color(0xFF3A1E08), 0.45)!);
    b.draw(canvas, 1, d, accent);
    b.draw(canvas, 0, d * 1.05, Color.lerp(accent, Colors.white, 0.35)!);
    b.draw(canvas, 3, d * 1.3, const Color(0xFFFFF4D6));
    b.draw(canvas, 4, d * 1.1, Color.lerp(accent, Colors.white, 0.5)!);
    // The glass's edge, catching the light — filled, as glass is.
    canvas.drawPath(
      flask,
      _p
        ..shader = ui.Gradient.linear(
          c + Offset(-br, -br),
          c + Offset(br, br),
          [
            Colors.white.withValues(alpha: 0.18),
            Colors.white.withValues(alpha: 0.02),
            accent.withValues(alpha: 0.12),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    _p.shader = null;
  }

  @override
  bool shouldRepaint(covariant DockEmblemPainter old) =>
      old.kind != kind ||
      old.clock != clock ||
      old.time != time ||
      old.creature != creature ||
      old.dark != dark;
}
