// lib/widgets/fx/costume_paint.dart
//
// COSTUMES, WORN: part of the sprite, not an effect round it.
//
//   Each sprite renderer — the widget, the Flame component, space — paints
//   it straight after the frame, in the frame's own space, at that frame's
//   fit. So it rides everything the sprite does without being told: the
//   head bobbing between frames, a turn, a squash, the size gene.

import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/widgets/fx/alchemical_clown_nose.dart';
import 'package:alchemons/widgets/fx/alchemical_party_hat.dart';
import 'package:alchemons/widgets/fx/alchemical_sunglasses.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

abstract final class CostumePaint {
  /// Paints the costumes saved as [costumes] (a `WornCostumes`, encoded)
  /// over sprite frame [index], drawn into [frame] on [canvas]. Nothing worn
  /// paints nothing. [t] is in seconds.
  static void paintWorn(
    Canvas canvas,
    String? costumes,
    Rect frame,
    int index,
    double t, {
    double opacity = 1,
  }) {
    final worn = WornCostumes.parse(costumes);
    if (worn == null || opacity <= 0) return;
    for (final costume in FamilyCostume.paintOrder) {
      if (!worn.wears(costume)) continue;
      final fit = costume.fitAt(worn.species, index);
      if (fit == null) continue;
      final at = Offset(
        frame.left + fit.x * frame.width,
        frame.top + fit.y * frame.height,
      );
      final size = fit.size * frame.width;
      final color = worn.colorOf(costume);
      switch (costume) {
        case FamilyCostume.partyHat:
          AlchemicalPartyHat.paint(
            canvas,
            at,
            size,
            t,
            opacity: opacity,
            tilt: fit.tilt,
            velvet: color,
          );
        case FamilyCostume.nose:
          AlchemicalClownNose.paint(
            canvas,
            at,
            size,
            t,
            opacity: opacity,
            color: color,
          );
        case FamilyCostume.sunglasses:
          AlchemicalSunglasses.paint(
            canvas,
            at,
            size,
            t,
            opacity: opacity,
            tilt: fit.tilt,
            tint: color,
            view: GlassesView.of(worn.species),
          );
      }
    }
  }

  /// Paints costume [costume] on its own, with no creature, in a box
  /// centred on [center] with half-side [r] (the shop's and inventory's
  /// cards). [color] is the color it is worn in; null is its own.
  static void paintPreview(
    Canvas canvas,
    FamilyCostume costume,
    Offset center,
    double r,
    double t, {
    double opacity = 1,
    Color? color,
  }) {
    switch (costume) {
      case FamilyCostume.partyHat:
        AlchemicalPartyHat.paint(
          canvas,
          center + Offset(0, r * 0.62),
          r,
          t,
          opacity: opacity,
          velvet: color ?? costume.defaultColor,
        );
      case FamilyCostume.nose:
        AlchemicalClownNose.paint(
          canvas,
          center,
          r * 0.34,
          t,
          opacity: opacity,
          color: color ?? costume.defaultColor,
        );
      case FamilyCostume.sunglasses:
        // Left a little: the near arm reaches out to the right.
        AlchemicalSunglasses.paint(
          canvas,
          center + Offset(-r * 0.2, 0),
          r * 0.85,
          t,
          opacity: opacity,
          tilt: -0.08,
          tint: color ?? costume.defaultColor,
        );
    }
  }
}

/// Worn costumes over a sprite widget: [child] is the sprite, its frame
/// drawn into the top-left of this box at the largest size that fits (as
/// Flame's sprite widget draws it), and [frameIndex] says which frame is up.
/// Runs on the shared glyph clock, and stops while a route covers it.
class WornCostume extends StatefulWidget {
  const WornCostume({
    super.key,
    required this.costumes,
    required this.frameSize,
    required this.frameIndex,
    required this.child,
  });

  final String costumes;
  final Size frameSize;
  final int Function() frameIndex;
  final Widget child;

  @override
  State<WornCostume> createState() => _WornCostumeState();
}

class _WornCostumeState extends State<WornCostume> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _WornCostumePainter(
      widget.costumes,
      widget.frameSize,
      widget.frameIndex,
      glyphClock,
    ),
    child: widget.child,
  );
}

class _WornCostumePainter extends CustomPainter {
  _WornCostumePainter(
    this.costumes,
    this.frameSize,
    this.frameIndex,
    this.clock,
  )
    : super(repaint: clock);

  final String costumes;
  final Size frameSize;
  final int Function() frameIndex;
  final ValueListenable<double>? clock;

  @override
  void paint(Canvas canvas, Size size) {
    if (frameSize.isEmpty) return;
    final fit = size.width / frameSize.width < size.height / frameSize.height
        ? size.width / frameSize.width
        : size.height / frameSize.height;
    CostumePaint.paintWorn(
      canvas,
      costumes,
      Offset.zero & (frameSize * fit),
      frameIndex(),
      clock?.value ?? 2.6,
    );
  }

  @override
  bool shouldRepaint(_WornCostumePainter old) =>
      old.costumes != costumes || old.frameSize != frameSize || old.clock != clock;
}
