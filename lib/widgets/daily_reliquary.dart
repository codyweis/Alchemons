// lib/widgets/daily_reliquary.dart
//
// The day's cache on home: one of the sealed reliquaries from the cosmos
// (cosmic_cache_vfx.dart), in the element of the player's division — near-
// black glass split by a seam of its light, the shards of its seal turning
// round it. Opened, it unseals the way those caches do, and the element
// pours out of the seam. It replaced a cartoon treasure chest.

import 'package:alchemons/games/cosmic/cosmic_cache_vfx.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The element a division's cache holds: the brightest of its own, so the
/// seam reads on the realm behind it (Earth's own brown all but vanished on
/// the Earthen strata; crystal is the light in them).
String dailyCacheElementFor(FactionId? faction) => switch (faction) {
  FactionId.volcanic => 'Fire',
  FactionId.oceanic => 'Water',
  FactionId.earthen => 'Crystal',
  FactionId.verdant => 'Plant',
  null => 'Light',
};

class DailyReliquary extends StatefulWidget {
  const DailyReliquary({
    super.key,
    required this.element,
    required this.size,
    this.opening,
  });

  final String element;

  /// The box it is drawn in; the unsealing throws its light past it.
  final double size;

  /// 0 → 1 through the unsealing; sealed while null or at 0.
  final Animation<double>? opening;

  @override
  State<DailyReliquary> createState() => _DailyReliquaryState();
}

class _DailyReliquaryState extends State<DailyReliquary> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => _visible;

  @override
  void initState() {
    super.initState();
    syncGlyphClock();
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
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: DailyReliquaryPainter(
          element: widget.element,
          clock: glyphClock,
          opening: widget.opening,
        ),
      ),
    );
  }
}

class DailyReliquaryPainter extends CustomPainter {
  DailyReliquaryPainter({
    required this.element,
    this.clock,
    this.opening,
    this.life,
    this.open,
  }) : super(repaint: Listenable.merge([clock, opening]));

  final String element;

  /// Its idle breathing; still when null.
  final ValueListenable<double>? clock;
  final Animation<double>? opening;

  /// Fixed moments, for still frames (tests).
  final double? life;
  final double? open;

  /// How many of a cache's units fit across the box: the seal's shards turn
  /// at about 55, so this leaves them a small margin.
  static const double _unitsAcross = 150;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / _unitsAcross;
    final l = life ?? clock?.value ?? 1.0;
    final t = open ?? opening?.value ?? 0.0;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    if (t > 0) {
      paintCacheUnseal(canvas, Offset.zero, element, l, t.clamp(0.0, 1.0));
    } else {
      paintSealedCache(canvas, Offset.zero, element, l);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DailyReliquaryPainter old) =>
      old.element != element ||
      old.clock != clock ||
      old.opening != opening ||
      old.life != life ||
      old.open != open;
}
