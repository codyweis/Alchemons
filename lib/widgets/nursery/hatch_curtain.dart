import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
    final entry = OverlayEntry(builder: (_) => _Curtain(visible: visible));
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
  const _Curtain({required this.visible});

  final ValueListenable<bool> visible;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      // Nothing behind the curtain is meant to be tappable — the hatch is
      // already under way.
      child: AbsorbPointer(
        child: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (_, on, child) => AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: on ? HatchCurtain.fadeIn : HatchCurtain.fadeOut,
            curve: Curves.easeOut,
            child: child,
          ),
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );
  }
}
