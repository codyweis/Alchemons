// lib/widgets/animations/extraction_veil.dart
//
// THE VEIL — what covers the gap between tapping Extract and the cinematic.
//
// Extracting a specimen used to be three unrelated events: the dialog popped
// with its default exit, a hardcoded 140ms of nothing followed, and then a
// stack of database work ran — insert the instance, mark the discovery, tick
// the constellation, check an unlock, register the recipe, read the quality
// setting — all of it on the nursery screen with nothing happening on it.
// Only then did the cinematic fade up over black. The gap was unbounded,
// because it was however long the writes took.
//
// So the veil goes up FIRST, an iris closing out of the vial you just tapped,
// and everything else happens behind it. The cinematic opens on a screen that
// is already black, which means its own fade has nothing to cross and the two
// read as one continuous plunge.
//
// It is an overlay entry rather than a route, so routes pushed afterwards
// (the cinematic, the result) sit above it and it can stay as the black floor
// under the whole ceremony instead of flashing the nursery between them.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Live handle on a veil. Call [dismiss] when the ceremony is over.
class ExtractionVeil {
  ExtractionVeil._(this._route, this._navigator);

  final Route<void> _route;
  final NavigatorState _navigator;
  bool _gone = false;

  Future<void> dismiss() async {
    if (_gone) return;
    _gone = true;
    if (!_navigator.mounted) return;
    // Normally the veil is the top route by now (the cinematic and the result
    // have both popped) and can leave with its own reverse transition. If
    // anything is still stacked on it, take it out from underneath instead of
    // popping whatever happens to be on top.
    if (_route.isCurrent) {
      _navigator.pop();
    } else if (_route.isActive) {
      _navigator.removeRoute(_route);
    }
  }
}

/// Close an iris over the screen, out of [from] (the vial's own rect).
///
/// Returns once the screen is dark, so the caller can start work that must
/// not be seen.
///
/// This is a ROUTE, not an overlay entry. An entry inserted into the overlay
/// stays above every route pushed afterwards — which meant the cinematic
/// played underneath an opaque black rectangle and the screen just went dark
/// and stayed there. As a route it is simply the thing the cinematic is
/// pushed on top of.
Future<ExtractionVeil> showExtractionVeil(
  BuildContext context, {
  Rect? from,
  required Color accent,
  TickerProvider? vsync,
}) async {
  final navigator = Navigator.of(context);
  final route = PageRouteBuilder<void>(
    // Opaque once it has closed: nothing below it needs painting, and the
    // cinematic that lands on top of it has a solid floor.
    opaque: true,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 520),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const SizedBox.expand(
      child: ColoredBox(color: Colors.black),
    ),
    transitionsBuilder: (_, animation, __, child) => AnimatedBuilder(
      animation: animation,
      builder: (_, ___) => CustomPaint(
        size: Size.infinite,
        painter: _VeilPainter(
          t: animation.value,
          origin: from?.center,
          radius: from == null ? 60 : from.longestSide * 0.5,
          accent: accent,
        ),
      ),
    ),
  );

  unawaited(navigator.push(route));

  // Wait for the iris itself, not a guessed duration: the caller's work must
  // start behind a screen that is actually dark.
  final animation = route.animation;
  if (animation != null && animation.status != AnimationStatus.completed) {
    final closed = Completer<void>();
    void listener(AnimationStatus s) {
      if (s == AnimationStatus.completed && !closed.isCompleted) {
        closed.complete();
      }
    }

    animation.addStatusListener(listener);
    await closed.future;
    animation.removeStatusListener(listener);
  }
  return ExtractionVeil._(route, navigator);
}

class _VeilPainter extends CustomPainter {
  _VeilPainter({
    required this.t,
    required this.origin,
    required this.radius,
    required this.accent,
  });

  final double t;
  final Offset? origin;
  final double radius;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final c = origin ?? size.center(Offset.zero);
    final rect = Offset.zero & size;

    // The dark closes in from the edges rather than fading flat, so the vial
    // is the last thing standing in the light.
    final reach = math.sqrt(size.width * size.width + size.height * size.height);
    final hole = (1.0 - Curves.easeInCubic.transform(t)) * (reach * 0.62) +
        radius * 0.6;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (c.dx / size.width) * 2 - 1,
            (c.dy / size.height) * 2 - 1,
          ),
          radius: (hole / reach) * 2.2 + 0.02,
          colors: [
            // Reaches FULL black, not 92%: the cinematic is handed a screen
            // with nothing left on it, so its own fade has nothing to cross.
            Colors.black.withValues(alpha: math.min(1.0, 1.12 * t)),
            Colors.black.withValues(alpha: math.min(1.0, 0.55 + 0.45 * t)),
            Colors.black,
          ],
          stops: const [0.0, 0.62, 1.0],
        ).createShader(rect),
    );

    // A ring leaving the vial: the seal being drawn, and the only warm thing
    // on screen as the light goes.
    final ring = Curves.easeOutCubic.transform(t);
    if (ring > 0.02 && ring < 0.99) {
      canvas.drawCircle(
        c,
        radius * (0.7 + 2.6 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0 * (1 - ring) + 0.6
          ..color = accent.withValues(alpha: 0.7 * (1 - ring)),
      );
      canvas.drawCircle(
        c,
        radius * (0.5 + 1.5 * ring),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * (1 - ring) + 0.4
          ..color = Color.lerp(accent, Colors.white, 0.4)!.withValues(
            alpha: 0.5 * (1 - ring),
          ),
      );
    }

    // The last of the light in the vial itself, pinched out.
    final ember = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
    if (ember > 0.02) {
      for (var i = 3; i >= 1; i--) {
        canvas.drawCircle(
          c,
          radius * 0.5 * i * ember,
          Paint()..color = accent.withValues(alpha: 0.16 * ember / i),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VeilPainter old) =>
      old.t != t || old.origin != origin || old.accent != accent;
}
