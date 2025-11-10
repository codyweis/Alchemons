import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Push a page with a pre-rotation + portal animation.
/// - Rotates to landscape first (so route animation is already in land).
/// - Plays a portal overlay on top of the current route.
/// - Pushes [page] with a subtle scale/fade.
/// - On pop, plays the portal again and rotates back to portrait.
Future<T?> pushWorld<T>(
  BuildContext context, {
  required Widget page,
  Duration portalDuration = const Duration(milliseconds: 420),
}) async {
  // 1) Portal IN on the map
  final entryIn = _showPortalOverlay(context, duration: portalDuration);

  // 2) Rotate to landscape before pushing
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // give the system a beat to settle orientation
  await Future<void>.delayed(const Duration(milliseconds: 10));

  // Let the portal animate in
  await Future<void>.delayed(portalDuration);
  entryIn.remove();

  // 3) Push scene with a subtle scale/fade (no orientation jank now)
  final result = await Navigator.of(context).push<T>(
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.985, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );

  // 4) Coming back: portal OUT + rotate to portrait
  final entryOut = _showPortalOverlay(
    context,
    reverse: true,
    duration: portalDuration,
  );
  await Future<void>.delayed(portalDuration);
  entryOut.remove();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  return result;
}

OverlayEntry _showPortalOverlay(
  BuildContext context, {
  bool reverse = false,
  required Duration duration,
}) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (_) => _PortalCurtain(duration: duration, reverse: reverse),
  );
  overlay.insert(entry);
  return entry;
}

class _PortalCurtain extends StatefulWidget {
  const _PortalCurtain({required this.duration, required this.reverse});
  final Duration duration;
  final bool reverse;

  @override
  State<_PortalCurtain> createState() => _PortalCurtainState();
}

class _PortalCurtainState extends State<_PortalCurtain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
      parent: _c,
      curve: widget.reverse ? Curves.easeInCubic : Curves.easeOutCubic,
    );

    // 0→1 when entering, reverse when exiting
    final t = widget.reverse ? ReverseAnimation(curve) : curve;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: t,
        builder: (_, __) {
          return Stack(
            children: [
              // Dim & tint
              Opacity(
                opacity: 0.75 * t.value,
                child: Container(color: Colors.black),
              ),
              // Subtle blur that strengthens as the veil opens/closes
              BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: 2.0 + 6.0 * t.value,
                  sigmaY: 2.0 + 6.0 * t.value,
                ),
                child: Container(color: Colors.black.withOpacity(0.0)),
              ),
              // Arcane ring
              Center(
                child: Transform.scale(
                  scale: 0.9 + 0.3 * t.value,
                  child: Opacity(
                    opacity: 0.6 + 0.4 * t.value,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 3,
                          color: Colors.tealAccent.withOpacity(0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 28 * (0.6 + t.value),
                            spreadRadius: 2,
                            color: Colors.tealAccent.withOpacity(
                              0.35 + 0.25 * t.value,
                            ),
                          ),
                        ],
                        gradient: RadialGradient(
                          colors: [
                            Colors.tealAccent.withOpacity(
                              0.25 + 0.25 * t.value,
                            ),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }
}
