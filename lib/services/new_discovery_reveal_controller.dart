import 'dart:ui' as ui;

import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Coordinates the "filing-away" animation when a new alchemon is discovered
/// via extraction. The card flies into the CREATURES bottom-nav icon, the app
/// switches to the creatures tab, and the new species tile is briefly
/// highlighted in the catalog.
class NewDiscoveryReveal {
  NewDiscoveryReveal._();
  static final NewDiscoveryReveal instance = NewDiscoveryReveal._();

  /// GlobalKey on the CREATURES nav button; set by [BottomNav].
  GlobalKey? databaseNavKey;

  /// Section-switch callback registered by MainShell.
  void Function(NavSection section)? onSwitchSection;

  /// Watched by CreaturesScreen. Non-null while a reveal pulse should play.
  final ValueNotifier<String?> pendingRevealCreatureId = ValueNotifier(null);

  Rect? _rectOf(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Capture the card render boundary into an image and push an overlay that
  /// animates that image into the CREATURES nav icon. Partway through the
  /// flight, the app switches to the creatures tab; once the card lands,
  /// CreaturesScreen is signalled to reveal the new species.
  ///
  /// Returns as soon as the overlay snapshot is in place (or a fallback path
  /// is taken), so the caller can immediately dismiss the source dialog
  /// without a visible gap. The animation itself completes independently.
  Future<void> playFilingAway({
    required BuildContext context,
    required GlobalKey cardBoundaryKey,
    required String creatureId,
  }) async {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    final navRect = _rectOf(databaseNavKey);
    final cardCtx = cardBoundaryKey.currentContext;

    void revealOnly() {
      onSwitchSection?.call(NavSection.creatures);
      pendingRevealCreatureId.value = creatureId;
    }

    if (overlayState == null || cardCtx == null || navRect == null) {
      revealOnly();
      return;
    }

    final boundary =
        cardCtx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      revealOnly();
      return;
    }

    final srcRect = boundary.localToGlobal(Offset.zero) & boundary.size;

    ui.Image? snapshot;
    try {
      final pixelRatio =
          MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
      snapshot = await boundary.toImage(pixelRatio: pixelRatio);
    } catch (_) {
      // toImage can fail mid-frame; fall back to a graceful reveal.
    }

    if (snapshot == null) {
      revealOnly();
      return;
    }

    final capturedImage = snapshot;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FilingAwayOverlay(
        image: capturedImage,
        startRect: srcRect,
        endRect: navRect,
        onMidFlight: () {
          onSwitchSection?.call(NavSection.creatures);
        },
        onComplete: () {
          entry.remove();
          capturedImage.dispose();
          pendingRevealCreatureId.value = creatureId;
        },
      ),
    );
    overlayState.insert(entry);
  }
}

class _FilingAwayOverlay extends StatefulWidget {
  final ui.Image image;
  final Rect startRect;
  final Rect endRect;
  final VoidCallback onMidFlight;
  final VoidCallback onComplete;

  const _FilingAwayOverlay({
    required this.image,
    required this.startRect,
    required this.endRect,
    required this.onMidFlight,
    required this.onComplete,
  });

  @override
  State<_FilingAwayOverlay> createState() => _FilingAwayOverlayState();
}

class _FilingAwayOverlayState extends State<_FilingAwayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;
  bool _midFired = false;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _ctl.addListener(() {
      if (!_midFired && _ctl.value >= 0.55) {
        _midFired = true;
        widget.onMidFlight();
      }
    });
    _ctl.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete();
    });
    _ctl.forward();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = _ctl.value;
        // Position eases out, scale eases in (so it lingers big, then snaps in).
        final posT = Curves.easeInCubic.transform(t);
        final scaleT = Curves.easeInQuart.transform(t);

        final start = widget.startRect;
        final end = widget.endRect;

        final w = ui.lerpDouble(start.width, end.width, scaleT)!;
        final h = ui.lerpDouble(start.height, end.height, scaleT)!;

        // Slight upward arc to feel like it's being lifted before being filed away.
        final arcLift = (1 - (2 * t - 1).abs()) * -22.0;

        final cx = ui.lerpDouble(start.center.dx, end.center.dx, posT)!;
        final cy =
            ui.lerpDouble(start.center.dy, end.center.dy, posT)! + arcLift;

        final rect = Rect.fromCenter(
          center: Offset(cx, cy),
          width: w,
          height: h,
        );

        final rotation = (1 - t) * 0.0 + t * 0.18; // small spin into icon
        final opacity = t < 0.78
            ? 1.0
            : (1.0 - (t - 0.78) / 0.22).clamp(0.0, 1.0);

        return Positioned.fromRect(
          rect: rect,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: RawImage(
                  image: widget.image,
                  fit: BoxFit.fill,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

