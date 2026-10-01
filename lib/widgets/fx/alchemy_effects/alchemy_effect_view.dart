// lib/widgets/fx/alchemy_effects/alchemy_effect_view.dart
//
// An alchemy effect as a widget, round a creature sprite: painted behind its
// child, and in front of it for an effect that has a near side (Prismatic's
// ring). Animated ones share one clock (see [GlyphClock]) and stop while a
// route covers them or a list scrolls them away; a still one — the shop's
// frozen snapshot — is a single frame.

import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Paints [effectKey] round [child] (or alone in its box, with no child).
///
/// The effect's radius is half the box's shortest side less [inset], times
/// [scale]: a host wraps the sprite's own box, padding included, and the
/// effect fits the creature. It paints past the box (light over the head,
/// a ring round it, a pool at its feet), so nothing above should clip
/// tightly.
class AlchemyEffectView extends StatefulWidget {
  const AlchemyEffectView({
    super.key,
    required this.effectKey,
    this.element,
    this.scale = 1,
    this.inset = 0,
    this.animate = true,
    this.dark,
    this.child,
  });

  final String effectKey;

  /// The Elemental Aura's element or variant faction.
  final String? element;

  /// The creature's size gene: its sprite is drawn this much bigger than
  /// its box.
  final double scale;

  /// Padding round the sprite inside the box.
  final double inset;
  final bool animate;

  /// Over the dark plate or the light one; null reads the app's theme.
  final bool? dark;

  /// The sprite, drawn between the two layers.
  final Widget? child;

  /// The moment a still one shows: every effect has something up.
  static const double stillTime = 2.6;

  @override
  State<AlchemyEffectView> createState() => _AlchemyEffectViewState();
}

class _AlchemyEffectViewState extends State<AlchemyEffectView>
    with GlyphClockLease {
  /// Off while a route covers it or it is scrolled out of a gated list: the
  /// shared clock is a bare ticker, deaf to TickerMode, so the view asks.
  bool _visible = true;

  /// Two creatures wearing the same effect side by side are not in step.
  late final double _offset = (identityHashCode(this) % 997) / 97.0;

  @override
  bool get wantsClock => widget.animate && _visible;

  // Not in initState: TickerMode is only readable here, and a frozen bake
  // (the shop's snapshot) must never start the clock even for a frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant AlchemyEffectView oldWidget) {
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
    final dark = widget.dark ?? Theme.of(context).brightness == Brightness.dark;
    final clock = glyphClock;
    _AlchemyEffectPainter layer({required bool front}) => _AlchemyEffectPainter(
      widget.effectKey,
      element: widget.element,
      scale: widget.scale,
      inset: widget.inset,
      dark: dark,
      front: front,
      clock: clock,
      offset: clock == null ? 0 : _offset,
    );
    // Its own layer: a frame of the effect never repaints what is round it.
    return RepaintBoundary(
      child: CustomPaint(
        willChange: clock != null,
        painter: layer(front: false),
        foregroundPainter: AlchemyEffectPaint.hasFront(widget.effectKey)
            ? layer(front: true)
            : null,
        child: widget.child,
      ),
    );
  }
}

class _AlchemyEffectPainter extends CustomPainter {
  _AlchemyEffectPainter(
    this.effectKey, {
    required this.element,
    required this.scale,
    required this.inset,
    required this.dark,
    required this.front,
    required this.clock,
    required this.offset,
  }) : super(repaint: clock);

  final String effectKey;
  final String? element;
  final double scale, inset;
  final bool dark, front;
  final ValueListenable<double>? clock;
  final double offset;

  @override
  void paint(Canvas canvas, Size size) => AlchemyEffectPaint.paint(
    canvas,
    effectKey,
    size.center(Offset.zero),
    (size.shortestSide / 2 - inset) * scale,
    (clock?.value ?? AlchemyEffectView.stillTime) + offset,
    element: element,
    dark: dark,
    front: front,
  );

  @override
  bool shouldRepaint(_AlchemyEffectPainter old) =>
      old.effectKey != effectKey ||
      old.element != element ||
      old.scale != scale ||
      old.inset != inset ||
      old.dark != dark ||
      old.front != front ||
      old.clock != clock;
}
