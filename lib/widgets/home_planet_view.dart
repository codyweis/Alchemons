// lib/widgets/home_planet_view.dart
//
// A home planet drawn from how it looks (PlanetLook) alone, with no cosmic
// game behind it: a friend's, on their page and in the FRIENDS list. The
// same layers in the same order as space draws its own (CosmicGame
// _renderHomeBody): the glow, what it wears behind, the sphere, what it
// wears in front.
//
// A bigger planet is drawn bigger: its body takes from 62% (Tiny) to all
// (Huge) of [fill]. Still pictures ([animate] false) paint once.

import 'package:alchemons/games/cosmic/cosmic_data.dart' show homeColorSwatch;
import 'package:alchemons/games/cosmic/planets/planet_art.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Paints [look] round [center] with its body [bodyR] across, at [t].
void paintPlanetLook(
  Canvas canvas,
  Offset center,
  double bodyR,
  double t,
  PlanetLook look,
) {
  final vr = look.worldRadius;
  final col = homeColorSwatch(look.color);
  canvas.save();
  canvas.translate(center.dx, center.dy);
  canvas.scale(bodyR / vr);
  const o = Offset.zero;
  HomePlanetPaint.aura(canvas, o, vr, t, look.color, col);
  HomeEffectsArt.instance.paintBehind(
    canvas,
    o,
    vr,
    t,
    look.wearing,
    look.options,
    sizeTier: look.size,
  );
  HomePlanetPaint.sphere(canvas, o, vr, t, look.color, col);
  HomePlanetPaint.paintOriginals(canvas, o, vr, t, look.wearing, look.options);
  HomeEffectsArt.instance.paintFront(
    canvas,
    o,
    vr,
    t,
    look.wearing,
    look.options,
    sizeTier: look.size,
    color: col,
  );
  canvas.restore();
}

/// The body's radius for [look] in a box whose shorter side is [side].
double planetBodyRadius(PlanetLook look, double side, double fill) =>
    side / 2 * fill * (0.62 + 0.095 * look.size.clamp(0, 4));

class HomePlanetView extends StatefulWidget {
  const HomePlanetView({
    super.key,
    required this.look,
    this.fill = 0.5,
    this.animate = true,
    this.fadeIn = false,
  });

  /// Null for a player with no planet yet: the plain grey one.
  final PlanetLook? look;

  /// How much of half the box's shorter side a Huge planet's body takes.
  final double fill;

  /// Turning and breathing; false paints one still frame.
  final bool animate;

  /// Eases up out of nothing when it first appears.
  final bool fadeIn;

  @override
  State<HomePlanetView> createState() => _HomePlanetViewState();
}

class _HomePlanetViewState extends State<HomePlanetView>
    with SingleTickerProviderStateMixin {
  /// A moment into its turn, so a still one is not caught at its start.
  double _t = 4;
  late double _shown = widget.fadeIn ? 0 : 1;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    if (!widget.animate && !widget.fadeIn) return;
    _ticker = createTicker((d) {
      final s = d.inMicroseconds / 1e6;
      if (widget.animate) _t = 4 + s;
      if (_shown < 1) _shown = (s / 0.8).clamp(0.0, 1.0);
      _frame.value++;
      if (!widget.animate && _shown >= 1) _ticker?.stop();
    })..start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      size: Size.infinite,
      painter: _PlanetPainter(
        widget.look ?? const PlanetLook(),
        widget.fill,
        () => _t,
        () => _shown,
        _frame,
      ),
    ),
  );
}

class _PlanetPainter extends CustomPainter {
  _PlanetPainter(this.look, this.fill, this.time, this.shown, Listenable frame)
    : super(repaint: frame);

  final PlanetLook look;
  final double fill;
  final double Function() time, shown;

  @override
  void paint(Canvas canvas, Size size) {
    final s = shown();
    if (s <= 0) return;
    final eased = Curves.easeOutCubic.transform(s);
    final r = planetBodyRadius(look, size.shortestSide, fill);
    if (eased < 1) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, eased),
      );
    }
    paintPlanetLook(
      canvas,
      size.center(Offset.zero),
      r * (0.9 + 0.1 * eased),
      time(),
      look,
    );
    if (eased < 1) canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanetPainter old) =>
      old.fill != fill ||
      old.look.color != look.color ||
      old.look.size != look.size ||
      old.look.wearing.length != look.wearing.length ||
      !old.look.wearing.containsAll(look.wearing);
}
