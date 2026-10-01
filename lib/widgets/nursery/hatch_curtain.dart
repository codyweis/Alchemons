import 'package:alchemons/widgets/fx/cultivation_sphere.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// A black cover held across the seam between the extraction dialog closing
/// and the hatching cinematic opening.
///
/// The dialog sits on a near-black barrier and the cinematic opens on black,
/// so the two ends of the moment already match. What did not match was the
/// middle: the barrier left with the dialog, the nursery flashed back at full
/// brightness for a beat while the hatch did its database work, and then the
/// cinematic cut in. Keeping that beat black makes the whole thing read as one
/// continuous transition instead of a close followed by an open.
///
/// There is only ever one curtain. [raise] while one is already up simply
/// waits on the one that exists, so any hatch entry point can ask for it
/// without knowing whether an earlier step already did.
///
/// When the extraction dialog has handed its cultivation on (a staged
/// [CultivationHandoff]), the curtain comes down BEHIND it: the black rises
/// round the sphere, which stays where it was and keeps turning until the
/// ceremony picks it up — so the cultivation you tapped is never cut away.
class HatchCurtain {
  HatchCurtain._();

  static const Duration fadeIn = Duration(milliseconds: 200);
  static const Duration fadeOut = Duration(milliseconds: 220);

  static OverlayEntry? _entry;
  static ValueNotifier<bool>? _visible;
  static Future<void>? _raising;

  /// Fades black in over whatever is on screen, and completes once it is
  /// opaque — so the caller can dismiss a dialog behind it unseen.
  static Future<void> raise(BuildContext context) {
    final pending = _raising;
    if (pending != null) return pending;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future<void>.value();

    final visible = ValueNotifier<bool>(false);
    final carried = CultivationHandoff.staged;
    final entry = OverlayEntry(
      builder: (_) => _Curtain(visible: visible, carried: carried),
    );
    _visible = visible;
    _entry = entry;
    overlay.insert(entry);
    // Flipped after insertion so there is a transparent frame to animate from;
    // set in the same frame it would just appear.
    WidgetsBinding.instance.addPostFrameCallback((_) => visible.value = true);

    return _raising = Future<void>.delayed(
      fadeIn + const Duration(milliseconds: 16),
    );
  }

  /// Takes the curtain away.
  ///
  /// Pass `fade: false` when something opaque is already behind it — the
  /// cinematic, once its own entrance has finished — so there is no crossfade
  /// to see. The fade is for the paths where the hatch failed and there is
  /// nothing to hand over to.
  static void lower({bool fade = true}) {
    final entry = _entry;
    final visible = _visible;
    // A cultivation nobody picked up goes with the curtain.
    CultivationHandoff.stage(null);
    if (entry == null) return;
    _entry = null;
    _visible = null;
    _raising = null;

    void remove() {
      if (entry.mounted) entry.remove();
      visible?.dispose();
    }

    if (!fade) {
      remove();
      return;
    }
    visible?.value = false;
    Future<void>.delayed(fadeOut, remove);
  }
}

class _Curtain extends StatelessWidget {
  const _Curtain({required this.visible, this.carried});

  final ValueListenable<bool> visible;
  final CultivationHandoff? carried;

  @override
  Widget build(BuildContext context) {
    final carried = this.carried;
    return Positioned.fill(
      // Nothing behind the curtain is meant to be tappable — the hatch is
      // already under way.
      child: AbsorbPointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, on, child) => AnimatedOpacity(
                opacity: on ? 1 : 0,
                duration: on ? HatchCurtain.fadeIn : HatchCurtain.fadeOut,
                curve: Curves.easeOut,
                child: child,
              ),
              child: const ColoredBox(color: Colors.black),
            ),
            if (carried != null) _CarriedSphere(carried),
          ],
        ),
      ),
    );
  }
}

/// The cultivation, held where it stood while the hatch gets under way.
class _CarriedSphere extends StatefulWidget {
  const _CarriedSphere(this.handoff);

  final CultivationHandoff handoff;

  @override
  State<_CarriedSphere> createState() => _CarriedSphereState();
}

class _CarriedSphereState extends State<_CarriedSphere>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = _last == Duration.zero
          ? 1 / 60
          : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
      _last = elapsed;
      // Once the ceremony is carrying it, it moves it; this only draws.
      if (!widget.handoff.carried) {
        widget.handoff.advance(dt, CultivationSphere.readySpin);
      }
      _frame.value++;
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _CarriedPainter(widget.handoff, repaint: _frame));
}

class _CarriedPainter extends CustomPainter {
  _CarriedPainter(this.handoff, {super.repaint});

  final CultivationHandoff handoff;

  // Drawn until the curtain is lowered — including while the ceremony fades
  // in over it, holding the sphere at this same place, so the two draw one
  // identical frame and it never dims. The ceremony only moves it once this
  // is gone.
  @override
  void paint(Canvas canvas, Size size) =>
      handoff.paint(canvas, at: handoff.centre, radius: handoff.radius);

  @override
  bool shouldRepaint(_CarriedPainter old) => old.handoff != handoff;
}
