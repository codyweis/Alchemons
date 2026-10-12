// lib/widgets/nav_slab.dart
//
// Home's achievements bar and the Fusion side's action row stand in the same
// place, just above the dock, and are the same kind of thing: a slab, lit
// gold from below when it matters. A tab switch cuts the rest of the screen,
// so the slab seemed to jump and change. Between those two tabs it is handed
// over instead: it eases from the one's place and light into the other's,
// the old contents fading out of it and the new ones in.
//
// The arriving side draws the flight, being the one on screen: the slab
// under its own real, live contents, and a picture of the side it came from,
// taken just before the switch while that one was still on screen.

import 'dart:ui' as ui;

import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// The two places the slab stands.
enum NavSlabSite { home, fusion }

/// How a slab looks at rest, for a flight to ease between.
@immutable
class NavSlabLook {
  const NavSlabLook({
    required this.fill,
    this.lit,
    this.sillWidth = 1.2,
    this.opacity = 1,
    this.split,
  });

  final Color fill;

  /// The color its [BracketFramePainter] is given, or null for an unlit slab.
  final Color? lit;
  final double sillWidth;

  /// The whole slab's opacity: a button that cannot be pressed is faded.
  final double opacity;

  /// A second, quieter slab beside the first (Fusion's SAME PAIR).
  final NavSlabSplit? split;
}

/// A second slab after the first, unlit.
@immutable
class NavSlabSplit {
  const NavSlabSplit({
    required this.share,
    required this.gap,
    required this.fill,
  });

  /// The first slab's share of the width the gap leaves.
  final double share;
  final double gap;
  final Color fill;
}

/// How long a handover takes.
const Duration kNavSlabFlight = Duration(milliseconds: 380);

/// Hands the slab from one tab to the other. The shell calls [tabSwitch]
/// just before every switch.
class NavSlabHandoff {
  NavSlabHandoff._();
  static final NavSlabHandoff instance = NavSlabHandoff._();

  final Map<NavSlabSite, _NavSlabState> _sites = {};
  final Map<NavSlabSite, ValueNotifier<Offset>> _shifts = {
    for (final site in NavSlabSite.values) site: ValueNotifier(Offset.zero),
  };

  /// How far the top of the slab at [site] is from its rest place while it
  /// flies in, so what stands on it rides along (home's Furnace) rather than
  /// the slab passing behind it.
  ValueListenable<Offset> shiftOf(NavSlabSite site) => _shifts[site]!;

  @visibleForTesting
  bool get flying => _sites.values.any((s) => s._flight != null);

  /// Finishes any flight still going — its tab is about to go out of view,
  /// where its ticker stops — then, if [from] and [to] are both standing
  /// slabs, hands the slab over.
  void tabSwitch({NavSlabSite? from, NavSlabSite? to}) {
    var interrupted = false;
    for (final s in _sites.values.toList()) {
      interrupted |= s._finish();
    }
    // A slab caught mid-flight has not been painted whole, so a picture of
    // it would be wrong: that switch cuts.
    if (interrupted || from == null || to == null || from == to) return;
    final a = _sites[from], b = _sites[to];
    if (a == null || b == null) return;
    if (!a.widget.available || !b.widget.available) return;
    final ra = a._globalRect(), rb = b._globalRect();
    if (ra == null || rb == null) return;
    b._land(
      _Flight(
        from: ra.shift(-rb.topLeft),
        size: rb.size,
        look: a.widget.look,
        picture: a._picture(),
      ),
    );
  }
}

/// Marks [child] as the slab at [site]. [look] says how it is lit at rest.
/// [available] is false while it is not standing where it would be seen —
/// the Fusion row while the cultivations side is up, or scrolled.
class NavSlab extends StatefulWidget {
  const NavSlab({
    super.key,
    required this.site,
    required this.look,
    required this.child,
    this.available = true,
  });

  final NavSlabSite site;
  final NavSlabLook look;
  final bool available;
  final Widget child;

  @override
  State<NavSlab> createState() => _NavSlabState();
}

class _Flight {
  _Flight({
    required this.from,
    required this.size,
    required this.look,
    this.picture,
  });

  /// Where the slab left from, in the arriving slab's own coordinates.
  final Rect from;

  /// The arriving slab's size.
  final Size size;
  final NavSlabLook look;

  /// The leaving side as it last stood, or null if it could not be taken.
  final ui.Image? picture;
}

double _phase(double t, double from, double to, Curve curve) =>
    curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

class _NavSlabState extends State<NavSlab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: kNavSlabFlight)
        ..addListener(_publishShift)
        ..addStatusListener(_onStatus);
  final _picturedKey = GlobalKey();
  _Flight? _flight;
  Size _screen = Size.zero;
  double _dpr = 1;

  @override
  void initState() {
    super.initState();
    NavSlabHandoff.instance._sites[widget.site] = this;
  }

  @override
  void didUpdateWidget(NavSlab old) {
    super.didUpdateWidget(old);
    if (old.site != widget.site) {
      _unregister(old.site);
      NavSlabHandoff.instance._sites[widget.site] = this;
    }
    // Put out of sight mid-flight (the cultivations side came up): its
    // ticker stops there, so it would be found frozen half way.
    if (old.available && !widget.available) _finish();
  }

  void _unregister(NavSlabSite site) {
    final sites = NavSlabHandoff.instance._sites;
    if (sites[site] == this) sites.remove(site);
  }

  @override
  void dispose() {
    if (_flight != null) {
      NavSlabHandoff.instance._shifts[widget.site]!.value = Offset.zero;
    }
    _unregister(widget.site);
    _flight?.picture?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Rect? _globalRect() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = MatrixUtils.transformRect(
      box.getTransformTo(null),
      Offset.zero & box.size,
    );
    // Scrolled off, or a screen part way through a move of its own.
    final screen = (Offset.zero & _screen).inflate(1);
    if (!screen.contains(rect.topLeft) || !screen.contains(rect.bottomRight)) {
      return null;
    }
    return rect;
  }

  ui.Image? _picture() {
    final boundary = _picturedKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary || !boundary.hasSize) return null;
    try {
      return boundary.toImageSync(pixelRatio: _dpr);
    } catch (_) {
      // Never painted, or (in debug) waiting on a repaint: the flight starts
      // from an empty slab instead.
      return null;
    }
  }

  void _land(_Flight flight) {
    _flight?.picture?.dispose();
    setState(() => _flight = flight);
    _controller.forward(from: 0);
    _publishShift();
  }

  /// Where the slab stands now, in its own coordinates.
  Rect _now(_Flight flight) => Rect.lerp(
    flight.from,
    Offset.zero & flight.size,
    _phase(_controller.value, 0, 0.8, Curves.easeInOutCubic),
  )!;

  void _publishShift() {
    final flight = _flight;
    final now = flight == null || _controller.isCompleted ? null : _now(flight);
    NavSlabHandoff.instance._shifts[widget.site]!.value = now == null
        ? Offset.zero
        : Offset(now.center.dx - flight!.size.width / 2, now.top);
  }

  /// Ends a flight where it would have ended. True if one was going.
  bool _finish() {
    if (_flight == null) return false;
    _controller.value = 1;
    return true;
  }

  void _onStatus(AnimationStatus status) {
    final flight = _flight;
    if (status != AnimationStatus.completed || flight == null) return;
    setState(() => _flight = null);
    flight.picture?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _screen = MediaQuery.sizeOf(context);
    _dpr = MediaQuery.devicePixelRatioOf(context);
    // The same widgets with or without a flight, so the contents are never
    // rebuilt by one starting or ending.
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(key: _picturedKey, child: widget.child),
      builder: (context, child) {
        final flight = _flight;
        if (flight == null) {
          return CustomPaint(
            child: ClipRect(
              clipBehavior: Clip.none,
              child: Transform.translate(
                offset: Offset.zero,
                child: Opacity(opacity: 1, child: child),
              ),
            ),
          );
        }
        final t = _controller.value;
        // Place and light first, so the new contents come up in place.
        final g = _phase(t, 0, 0.8, Curves.easeInOutCubic);
        final leaving = 1 - _phase(t, 0, 0.42, Curves.easeOut);
        final arriving = _phase(t, 0.36, 0.92, Curves.easeInOut);
        // The slab gives way to the arriving contents' own fill at the end.
        final slab = 1 - _phase(t, 0.78, 1, Curves.easeIn);
        final rest = Offset.zero & flight.size;
        final now = _now(flight);
        return CustomPaint(
          painter: _SlabPainter(
            from: flight.look,
            to: widget.look,
            start: flight.from,
            g: g,
            strength: slab,
          ),
          foregroundPainter: flight.picture == null
              ? null
              : _PicturePainter(
                  picture: flight.picture!,
                  start: flight.from,
                  g: g,
                  opacity: leaving,
                ),
          // Kept inside the slab while it is a different width, or its
          // own fill pokes past the slab's ends. Its sill hangs just below
          // its box, so the clip does too.
          child: ClipRect(
            clipper: _SlabClip(
              Rect.fromLTRB(now.left, now.top - 2, now.right, now.bottom + 2),
            ),
            child: Transform.translate(
              offset: now.center - rest.center,
              child: Opacity(opacity: arriving, child: child),
            ),
          ),
        );
      },
    );
  }
}

class _SlabClip extends CustomClipper<Rect> {
  _SlabClip(this.rect);
  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_SlabClip old) => old.rect != rect;
}

/// The slab itself, part way from the leaving one's place and look ([g] 0)
/// to this one's ([g] 1).
class _SlabPainter extends CustomPainter {
  _SlabPainter({
    required this.from,
    required this.to,
    required this.start,
    required this.g,
    required this.strength,
  });

  final NavSlabLook from, to;
  final Rect start;
  final double g;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.lerp(start, Offset.zero & size, g)!;
    final opacity = ui.lerpDouble(from.opacity, to.opacity, g)! * strength;
    if (opacity < 0.01) return;
    final layered = opacity < 0.995;
    if (layered) {
      canvas.saveLayer(
        rect.inflate(2),
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    final a = from.split, b = to.split;
    final split = b ?? a;
    final fill = Color.lerp(from.fill, to.fill, g)!;
    if (split == null) {
      _part(canvas, rect, fill, from.lit, to.lit);
    } else {
      // The second slab parts from the end of the first (or closes into it).
      final gap = ui.lerpDouble(a?.gap ?? 0, b?.gap ?? 0, g)!;
      final first = (rect.width - gap) * split.share;
      _part(
        canvas,
        Rect.fromLTWH(rect.left, rect.top, first, rect.height),
        fill,
        from.lit,
        to.lit,
      );
      _part(
        canvas,
        Rect.fromLTRB(
          rect.left + first + gap,
          rect.top,
          rect.right,
          rect.bottom,
        ),
        Color.lerp(a?.fill ?? from.fill, b?.fill ?? to.fill, g)!,
        a == null ? from.lit : null,
        b == null ? to.lit : null,
      );
    }
    if (layered) canvas.restore();
  }

  void _part(Canvas canvas, Rect rect, Color fill, Color? litA, Color? litB) {
    if (rect.width <= 0) return;
    canvas.drawRect(rect, Paint()..color = fill);
    final tone = Color.lerp(litA ?? litB, litB ?? litA, g);
    if (tone == null) return;
    final lit = ui.lerpDouble(
      litA == null ? 0 : BracketFramePainter.litOf(litA),
      litB == null ? 0 : BracketFramePainter.litOf(litB),
      g,
    )!;
    canvas.save();
    canvas.translate(rect.left, rect.top);
    BracketFramePainter.paintLit(
      canvas,
      rect.size,
      tone,
      lit,
      ui.lerpDouble(from.sillWidth, to.sillWidth, g)!,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SlabPainter old) =>
      old.g != g ||
      old.strength != strength ||
      old.start != start ||
      old.from != from ||
      old.to != to;
}

/// The leaving side's contents, riding the slab as they fade.
class _PicturePainter extends CustomPainter {
  _PicturePainter({
    required this.picture,
    required this.start,
    required this.g,
    required this.opacity,
  });

  final ui.Image picture;
  final Rect start;
  final double g;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity < 0.01) return;
    final rect = Rect.lerp(start, Offset.zero & size, g)!;
    canvas.save();
    canvas.clipRect(rect);
    canvas.drawImageRect(
      picture,
      Offset.zero & Size(picture.width.toDouble(), picture.height.toDouble()),
      Rect.fromCenter(
        center: rect.center,
        width: start.width,
        height: start.height,
      ),
      Paint()
        ..color = Color.fromRGBO(255, 255, 255, opacity)
        ..filterQuality = FilterQuality.medium,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PicturePainter old) =>
      old.g != g ||
      old.opacity != opacity ||
      old.picture != picture ||
      old.start != start;
}
