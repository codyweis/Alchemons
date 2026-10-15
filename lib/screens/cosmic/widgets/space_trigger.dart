// lib/screens/cosmic/widgets/space_trigger.dart
//
// How space's combat buttons (boost, missiles, gun) take a press: from raw
// pointers, never a tap recogniser. A tap gives up the moment the thumb
// drifts past its slop — and a thumb holding boost or fire mid-fight always
// drifts — so a held boost used to cut out, and a toggle pressed on the move
// was never taken (the author, 2026-10-14: "it always stops going when I
// pressing it down").
//
// Held: on while any finger is down on it, off when the last one lifts,
// however far it wanders meanwhile — or if the button goes away under it.
// Toggled: taken as the finger lands, so it answers at once and a moving
// press still counts.
//
// [reach] widens what it catches past the button drawn, all round, so a
// thumb that lands just off its edge still presses it.

import 'package:flutter/widgets.dart';

class SpaceTrigger extends StatefulWidget {
  /// On while held: [onHeld] true as the first finger lands, false as the
  /// last lifts (or the button is taken away).
  const SpaceTrigger.hold({
    super.key,
    required ValueChanged<bool> this.onHeld,
    required this.child,
    this.reach = 0,
  }) : onPressed = null;

  /// A toggle: [onPressed] once per press, as the finger lands.
  const SpaceTrigger.toggle({
    super.key,
    required VoidCallback this.onPressed,
    required this.child,
    this.reach = 0,
  }) : onHeld = null;

  final ValueChanged<bool>? onHeld;
  final VoidCallback? onPressed;
  final Widget child;

  /// How far past [child] a press is caught, on every side.
  final double reach;

  @override
  State<SpaceTrigger> createState() => _SpaceTriggerState();
}

class _SpaceTriggerState extends State<SpaceTrigger> {
  /// The fingers down on it now.
  final Set<int> _down = {};

  /// The hold that is on, to be let go of the same way it was taken.
  ValueChanged<bool>? _holding;

  void _onDown(PointerDownEvent e) {
    final first = _down.isEmpty;
    _down.add(e.pointer);
    if (!first) return;
    final held = widget.onHeld;
    if (held != null) {
      _holding = held;
      held(true);
    } else {
      widget.onPressed?.call();
    }
  }

  void _onUp(PointerEvent e) {
    if (!_down.remove(e.pointer) || _down.isNotEmpty) return;
    _release();
  }

  void _release() {
    final held = _holding;
    _holding = null;
    held?.call(false);
  }

  /// Lets go once the tree is done changing: the owner sets its state.
  void _releaseLater() {
    final held = _holding;
    _holding = null;
    if (held != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => held(false));
    }
  }

  @override
  void didUpdateWidget(SpaceTrigger old) {
    super.didUpdateWidget(old);
    if (_holding == null) return;
    if (widget.onHeld == null) {
      // Turned into a toggle mid-hold: the hold ends now, not on a lift
      // the toggle would take for nothing.
      _releaseLater();
    } else {
      // Still a hold: let go through the newest handler.
      _holding = widget.onHeld;
    }
  }

  @override
  void dispose() {
    // Taken away with a finger still on it (an overlay opened mid-boost):
    // nothing will lift, so let go now.
    _releaseLater();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.opaque,
    onPointerDown: _onDown,
    onPointerUp: _onUp,
    onPointerCancel: _onUp,
    child: Padding(padding: EdgeInsets.all(widget.reach), child: widget.child),
  );
}
