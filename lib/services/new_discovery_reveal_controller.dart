import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;

import 'package:alchemons/widgets/nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Coordinates the "filing-away" animation when a new alchemon is discovered
/// via extraction. The card flies into the CREATURES bottom-nav icon, the app
/// switches to the creatures tab, and the new species tile is briefly
/// highlighted in the catalog.
/// A snapshot of a result card, taken while the card is still on screen so the
/// flight can be played later.
///
/// The batch ceremony needs exactly this: it cannot fly a card at the moment
/// the card is dismissed, because that would switch sections in the middle of
/// the run. It captures each new discovery as it goes and flies them all once
/// the last card is done.
class DiscoveryFlightCapture {
  DiscoveryFlightCapture({required this.image, required this.srcRect});

  final ui.Image image;
  final Rect srcRect;

  void dispose() => image.dispose();
}

class NewDiscoveryReveal {
  NewDiscoveryReveal._();
  static final NewDiscoveryReveal instance = NewDiscoveryReveal._();

  /// GlobalKey on the revealed species' own tile in the catalog, set by the
  /// creatures grid while a reveal is pending. The filing-away card retargets
  /// onto this once the grid has laid it out, so it lands on the entry rather
  /// than on the tab button that merely leads to it.
  GlobalKey? revealTileKey;

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
  /// Rasterise the card so it can be flown now or later. Null means the card
  /// could not be captured and the caller should fall back to a plain reveal.
  Future<DiscoveryFlightCapture?> captureCard({
    required BuildContext context,
    required GlobalKey cardBoundaryKey,
  }) async {
    final cardCtx = cardBoundaryKey.currentContext;
    if (cardCtx == null) return null;
    final boundary = cardCtx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final srcRect = boundary.localToGlobal(Offset.zero) & boundary.size;
    try {
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
      final image = await boundary.toImage(pixelRatio: math.min(dpr, 1.75));
      return DiscoveryFlightCapture(image: image, srcRect: srcRect);
    } catch (_) {
      // toImage can fail mid-frame; the caller falls back to a plain reveal.
      return null;
    }
  }

  /// Reveal several new species one after another, flying each captured card
  /// at its own tile and waiting for it to land before starting the next.
  ///
  /// The section switch happens once, on the first entry. Everything after it
  /// is the catalog scrolling from one new entry to the next.
  Future<void> playCapturedSequence({
    required BuildContext context,
    required List<({DiscoveryFlightCapture? capture, String creatureId})>
    entries,
  }) async {
    for (final e in entries) {
      if (!context.mounted) {
        e.capture?.dispose();
        continue;
      }
      await _flyCapture(
        context: context,
        capture: e.capture,
        creatureId: e.creatureId,
        awaitLanding: true,
      );
      if (!context.mounted) continue;
      // Let the highlight sit before moving on, so each entry reads as its
      // own arrival rather than the grid jumping between them.
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
  }

  Future<void> _flyCapture({
    required BuildContext context,
    required DiscoveryFlightCapture? capture,
    required String creatureId,
    bool awaitLanding = false,
  }) async {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    final navRect = _rectOf(databaseNavKey);

    void revealOnly() {
      pendingRevealCreatureId.value = creatureId;
      onSwitchSection?.call(NavSection.creatures);
    }

    if (capture == null || overlayState == null || navRect == null) {
      capture?.dispose();
      revealOnly();
      if (awaitLanding) {
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
      return;
    }

    pendingRevealCreatureId.value = creatureId;
    onSwitchSection?.call(NavSection.creatures);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(kRevealScrollSettle);
    if (!context.mounted) {
      capture.dispose();
      return;
    }

    final landed = Completer<void>();
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FilingAwayOverlay(
        image: capture.image,
        startRect: capture.srcRect,
        endRect: _rectOf(revealTileKey) ?? navRect,
        endRectResolver: () => _rectOf(revealTileKey),
        onComplete: () {
          entry.remove();
          capture.dispose();
          revealTileKey = null;
          if (!landed.isCompleted) landed.complete();
        },
      ),
    );
    overlayState.insert(entry);
    if (awaitLanding) await landed.future;
  }

  Future<void> playFilingAway({
    required BuildContext context,
    required GlobalKey cardBoundaryKey,
    required String creatureId,
  }) async {
    final overlayState = Overlay.maybeOf(context, rootOverlay: true);
    final navRect = _rectOf(databaseNavKey);
    final cardCtx = cardBoundaryKey.currentContext;

    void revealOnly() {
      // Pending first — see the note on the main path below.
      pendingRevealCreatureId.value = creatureId;
      onSwitchSection?.call(NavSection.creatures);
    }

    if (overlayState == null || cardCtx == null || navRect == null) {
      revealOnly();
      return;
    }

    final boundary = cardCtx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      revealOnly();
      return;
    }

    final srcRect = boundary.localToGlobal(Offset.zero) & boundary.size;

    ui.Image? snapshot;
    try {
      // Capped rather than the device ratio. This card is full-width and the
      // flight immediately shrinks it to a grid tile, so rasterising at 2.6x
      // on a large screen was a big texture allocated for pixels nothing ever
      // sees — and it landed right as the catalog was building.
      final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
      snapshot = await boundary.toImage(pixelRatio: math.min(dpr, 1.75));
    } catch (_) {
      // toImage can fail mid-frame; fall back to a graceful reveal.
    }

    if (snapshot == null) {
      revealOnly();
      return;
    }

    final capturedImage = snapshot;

    // Reveal BEFORE the flight, not partway through it.
    //
    // The section switch and the reveal used to fire at 55% of a 720ms
    // flight, which left the catalog building and scrolling while the card
    // was already most of the way to where the tile was going to be. The card
    // chased a moving target and landed as the scroll finished. Now the
    // catalog settles first and the card flies at something that is standing
    // still.
    // ORDER MATTERS: the pending id goes up before the section switch.
    //
    // MainShell fires the first-visit database tutorial when it arrives at
    // the creatures section, and it suppresses that when a reveal is in
    // flight — but it reads the pending id to decide, and the switch used to
    // happen while that id was still null. So the very first extraction
    // opened the tutorial on top of the extraction result, and the dismissal
    // meant for the result closed the tutorial instead, stranding the result
    // on screen. Setting it first is what makes that check able to see
    // anything.
    pendingRevealCreatureId.value = creatureId;
    onSwitchSection?.call(NavSection.creatures);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(kRevealScrollSettle);
    if (!context.mounted) {
      capturedImage.dispose();
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _FilingAwayOverlay(
        image: capturedImage,
        startRect: srcRect,
        endRect: _rectOf(revealTileKey) ?? navRect,
        // Resolved once now that the catalog has settled, and still re-read
        // each frame so a late layout is picked up. Falls back to the nav
        // button when the tile never resolves.
        endRectResolver: () => _rectOf(revealTileKey),
        onComplete: () {
          entry.remove();
          capturedImage.dispose();
          revealTileKey = null;
        },
      ),
    );
    overlayState.insert(entry);
  }
}

/// How long the catalog is given to build and ease the revealed tile into
/// view before the card starts flying at it. Matches the scroll in
/// CreaturesScreen, plus a frame of slack.
const Duration kRevealScrollSettle = Duration(milliseconds: 340);

class _FilingAwayOverlay extends StatefulWidget {
  final ui.Image image;
  final Rect startRect;
  final Rect endRect;

  /// Optional live destination, preferred over [endRect] whenever it resolves.
  final Rect? Function()? endRectResolver;
  final VoidCallback onComplete;

  const _FilingAwayOverlay({
    required this.image,
    required this.startRect,
    required this.endRect,
    this.endRectResolver,
    required this.onComplete,
  });

  @override
  State<_FilingAwayOverlay> createState() => _FilingAwayOverlayState();
}

class _FilingAwayOverlayState extends State<_FilingAwayOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
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
        final end = widget.endRectResolver?.call() ?? widget.endRect;

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
                child: RawImage(image: widget.image, fit: BoxFit.fill),
              ),
            ),
          ),
        );
      },
    );
  }
}
