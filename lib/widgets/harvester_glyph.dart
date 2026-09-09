import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A harvester drawn as the device it is: a pulser.
///
/// Deliberately not the element's own particle field — a harvester and the
/// resource it yields sit side by side in the shop and the inventory, and if
/// both were loose motes of the same colour they would read as the same item.
/// So this is hardware: a hard-edged core that beats on a fixed rhythm, throws
/// a shockwave out to the rim, and hauls the element back in along it. The
/// element only shows in what gets captured and how it comes home.
///
/// [biomeId] takes the five elements plus [universalHarvester], the stabilized
/// unit that pulls every element at once.
class HarvesterGlyph extends StatefulWidget {
  const HarvesterGlyph({
    super.key,
    required this.biomeId,
    required this.size,
    this.color,
    this.animate = true,
  });

  /// 'volcanic' | 'oceanic' | 'earthen' | 'verdant' | 'arcane' | 'universal'
  final String biomeId;
  final double size;

  /// Overrides the element's own colour — used to carry a can-afford state.
  final Color? color;

  /// Off for a still frame; a shop card scrolling past does not need to beat.
  final bool animate;

  @override
  State<HarvesterGlyph> createState() => _HarvesterGlyphState();
}

/// The stabilized harvester, which is not tied to one element.
const String universalHarvester = 'universal';

class _HarvesterGlyphState extends State<HarvesterGlyph> with GlyphClockLease {
  @override
  bool get wantsClock => widget.animate;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant HarvesterGlyph oldWidget) {
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
    final tint =
        widget.color ??
        ElementResources.byBiomeId[widget.biomeId]?.color ??
        const Color(0xFFCBD5E1);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: CustomPaint(
        willChange: widget.animate,
        isComplex: false,
        painter: _PulserPainter(
          biomeId: widget.biomeId,
          color: tint,
          clock: glyphClock,
        ),
      ),
    );
  }
}

class _PulserPainter extends CustomPainter {
  _PulserPainter({
    required this.biomeId,
    required this.color,
    required this.clock,
  }) : super(repaint: clock);

  final String biomeId;
  final Color color;
  final ValueListenable<double>? clock;

  /// Reused across every frame and every pulser on screen. No MaskFilter
  /// anywhere in here — blur in a per-frame paint is this app's main source of
  /// jank, and these appear six to a shelf.
  static final Paint _p = Paint();

  /// One beat, shared by the shockwave, the intake and the core's charge, so
  /// the whole device reads as a single machine rather than three loops.
  static const double _period = 1.6;

  double get _t => clock?.value ?? 0;

  /// 0..1 through the current beat.
  double get _beat => (_t % _period) / _period;

  /// Stable per-mote spread, so a glyph looks the same every time it is built
  /// rather than reshuffling on scroll.
  static double _seed(int i, int salt) => ((i * 41 + salt * 23) % 100) / 100.0;

  static const List<String> _allElements = [
    'volcanic',
    'oceanic',
    'earthen',
    'verdant',
    'arcane',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final c = Offset(size.width / 2, size.height / 2);
    final beat = _beat;

    _shockwave(canvas, c, s, beat);
    _intake(canvas, c, s, beat);
    _core(canvas, c, s, beat);
  }

  /// The pulse going out. Two rings a half-beat apart so the device never
  /// looks idle between beats.
  void _shockwave(Canvas canvas, Offset c, double s, double beat) {
    for (var ring = 0; ring < 2; ring++) {
      final phase = (beat + ring * 0.5) % 1.0;
      // Snaps out and eases to a stop, the way a discharge does.
      final e = Curves.easeOutCubic.transform(phase);
      final r = s * (0.16 + 0.30 * e);
      final fade = (1 - phase) * 0.55;
      if (fade <= 0.01) continue;
      canvas.drawCircle(
        c,
        r,
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.035 * (1 - e * 0.7)
          ..color = color.withValues(alpha: fade),
      );
    }
    _p.style = PaintingStyle.fill;
  }

  /// What the pulse drags home. Each element comes in the way that element
  /// moves — the capture is where the identity lives, not the hardware.
  void _intake(Canvas canvas, Offset c, double s, double beat) {
    final elements = biomeId == universalHarvester
        ? _allElements
        : [biomeId.isEmpty ? 'arcane' : biomeId];
    // The stabilized unit hauls one mote of each element; a tuned one hauls a
    // fuller stream of its own.
    final perElement = biomeId == universalHarvester ? 2 : 7;

    for (var e = 0; e < elements.length; e++) {
      final element = elements[e];
      final moteColor = biomeId == universalHarvester
          ? (ElementResources.byBiomeId[element]?.color ?? color)
          : color;
      final bright = Color.lerp(moteColor, Colors.white, 0.45)!;

      for (var i = 0; i < perElement; i++) {
        final idx = e * 7 + i;
        // Staggered so motes stream continuously rather than arriving as a
        // block on the beat.
        final phase = (beat + _seed(idx, 1)) % 1.0;
        // Distance runs rim → aperture; eased in so they accelerate as the
        // pulse takes hold.
        final pull = Curves.easeInCubic.transform(phase);
        final dist = s * (0.46 - 0.34 * pull);
        final baseAngle = _seed(idx, 2) * math.pi * 2;
        final angle = baseAngle + _swirl(element, phase, idx);
        final wobble = _wobble(element, phase, idx, s);

        final pos =
            c + Offset(math.cos(angle) * dist, math.sin(angle) * dist + wobble);
        // Fades in off the rim and is swallowed at the aperture.
        final fade =
            (phase < 0.14 ? phase / 0.14 : 1.0) *
            (phase > 0.86 ? (1 - phase) / 0.14 : 1.0);
        if (fade <= 0.02) continue;

        final r = s * (0.030 + 0.022 * (1 - pull));
        canvas.drawCircle(
          pos,
          r,
          _p..color = bright.withValues(alpha: 0.85 * fade),
        );
      }
    }
  }

  /// How the intake path curves, per element.
  double _swirl(String element, double phase, int idx) {
    switch (element) {
      // Fire is dragged in fighting, curling as it goes.
      case 'volcanic':
        return math.sin(phase * math.pi * 2 + idx) * 0.55;
      // Water arcs in smoothly, always the same way round.
      case 'oceanic':
        return phase * 1.1;
      // Earth comes straight in. It does not wander.
      case 'earthen':
        return 0;
      // Spores drift, taking their time about the last stretch.
      case 'verdant':
        return math.sin(phase * math.pi * 3 + idx * 0.7) * 0.35;
      // Arcane spirals hard, more than a full turn on the way in.
      case 'arcane':
        return phase * 3.4;
      default:
        return phase * 1.2;
    }
  }

  /// Vertical bias, per element: embers climb, water falls, stone sinks.
  double _wobble(String element, double phase, int idx, double s) {
    switch (element) {
      case 'volcanic':
        return -s * 0.06 * (1 - phase);
      case 'oceanic':
        return s * 0.05 * phase;
      case 'earthen':
        // Hauled in in steps rather than a glide.
        return s * 0.02 * (((phase * 4).floor() % 2 == 0) ? 1 : -1);
      case 'verdant':
        return math.sin(phase * math.pi * 2 + idx) * s * 0.045;
      default:
        return 0;
    }
  }

  /// The device. A hard hexagonal shell that stays put while everything else
  /// moves, and an aperture that swallows what arrives and flares on the beat.
  void _core(Canvas canvas, Offset c, double s, double beat) {
    final shell = s * 0.155;

    // Charge builds through the beat and discharges at the top of it.
    final charge = beat < 0.82
        ? Curves.easeInQuad.transform(beat / 0.82)
        : 1 - (beat - 0.82) / 0.18;

    // Aperture glow, brightest at discharge. Flat discs, no blur.
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
        c,
        shell * (0.55 + 0.42 * i) * (1 + 0.12 * charge),
        _p..color = color.withValues(alpha: (0.16 * charge) / i),
      );
    }

    // Hexagonal shell — the one hard-edged thing in the glyph, so it reads as
    // built rather than grown.
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2 - math.pi / 2;
      final p = c + Offset(math.cos(a) * shell, math.sin(a) * shell);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      _p
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          const Color(0xFF11151C),
          color,
          0.18 + 0.22 * charge,
        )!,
    );
    canvas.drawPath(
      path,
      _p
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.028
        ..color = Color.lerp(
          color,
          Colors.white,
          0.25 + 0.45 * charge,
        )!.withValues(alpha: 0.9),
    );
    _p.style = PaintingStyle.fill;

    // The aperture itself: a bright pip that swells as the chamber fills.
    canvas.drawCircle(
      c,
      shell * (0.26 + 0.24 * charge),
      _p..color = Color.lerp(color, Colors.white, 0.6 + 0.4 * charge)!,
    );
  }

  @override
  bool shouldRepaint(covariant _PulserPainter old) =>
      old.biomeId != biomeId || old.color != color || old.clock != clock;
}

/// The element a harvester is tuned to, or [universalHarvester] for the
/// stabilized unit. Null for anything that is not a harvester.
///
/// Single source of truth for the shop card, the inventory tile, the space
/// market and the wild-harvest cinematic, so a harvester looks like itself
/// everywhere it appears.
String? harvesterBiomeForKey(String? inventoryKey) => switch (inventoryKey) {
  InvKeys.harvesterStdVolcanic => 'volcanic',
  InvKeys.harvesterStdOceanic => 'oceanic',
  InvKeys.harvesterStdEarthen => 'earthen',
  InvKeys.harvesterStdVerdant => 'verdant',
  InvKeys.harvesterStdArcane => 'arcane',
  InvKeys.harvesterGuaranteed => universalHarvester,
  _ => null,
};
