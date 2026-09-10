import 'dart:async';

import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

/// One look, and one place, for every notification in the game.
///
/// This used to be a styled SnackBar. A floating SnackBar cannot be put where
/// you want it: it is positioned by a bottom margin and grows upward, so
/// placing it at the top means subtracting a height you do not know, and the
/// framework then shifts it again on wide layouts by an amount you cannot
/// read back. Three attempts at that arithmetic put it under the notch on a
/// phone and two hundred pixels out on a tablet.
///
/// An overlay entry has no such problem. `top` is `top`.
class GameSnack {
  GameSnack._();

  static OverlayEntry? _entry;

  static void _dismiss() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

/// Breathing room under the status bar.
const double kSnackTopGap = 12;

/// What the app-level SnackBar theme assumes for the raw snackbars that do
/// not come through here. They keep the old lift-by-margin behaviour, so this
/// stays generous: too small clips them off the screen, too large only sits
/// them lower.
const double kSnackHeight = 140;

void showGameSnack(
  BuildContext context,
  String message, {
  IconData? icon,

  /// The severity colour. It tints the bar, the icon and the border; it is
  /// never the background.
  Color? accent,
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final fc = FC.of(context);
  final tint = accent ?? fc.amber;

  // One at a time. A second notification replaces the first rather than
  // stacking on top of it or queueing behind it.
  GameSnack._dismiss();

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TopNotification(
      message: message,
      icon: icon,
      tint: tint,
      surface: fc.bg1,
      text: fc.textPrimary,
      action: action,
      duration: duration,
      onDismiss: GameSnack._dismiss,
    ),
  );
  GameSnack._entry = entry;
  overlay.insert(entry);
}

class _TopNotification extends StatefulWidget {
  const _TopNotification({
    required this.message,
    required this.icon,
    required this.tint,
    required this.surface,
    required this.text,
    required this.action,
    required this.duration,
    required this.onDismiss,
  });

  final String message;
  final IconData? icon;
  final Color tint;
  final Color surface;
  final Color text;
  final SnackBarAction? action;
  final Duration duration;
  final VoidCallback onDismiss;

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  /// Owned here rather than by the static helper.
  ///
  /// A timer parked on the class outlives the tree it belongs to — and a
  /// progress reset disposes the whole tree, which would leave it to fire
  /// afterwards and reach for an entry that is already gone.
  Timer? _life;

  @override
  void initState() {
    super.initState();
    _life = Timer(widget.duration, widget.onDismiss);
  }

  @override
  void dispose() {
    _life?.cancel();
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The physical inset, read off the view rather than the nearest
    // MediaQuery: SafeArea consumes an inset by zeroing it for everything
    // below, so a call from inside one reports no status bar at all.
    final inset = MediaQueryData.fromView(View.of(context)).viewPadding.top;

    return Positioned(
      top: inset + kSnackTopGap,
      left: 14,
      right: 14,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _ctl, curve: Curves.easeOutCubic)),
        child: FadeTransition(
          opacity: _ctl,
          child: Dismissible(
            key: const ValueKey('game-snack'),
            // Sideways. A downward swipe is the gesture for putting a keyboard
            // or a sheet away, and it fought the scroll underneath.
            direction: DismissDirection.horizontal,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(
                  color: widget.surface,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: widget.tint.withValues(alpha: 0.5),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(0, 11, 12, 11),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 26,
                      color: widget.tint,
                      margin: const EdgeInsets.only(right: 11),
                    ),
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 16, color: widget.tint),
                      const SizedBox(width: 9),
                    ],
                    Expanded(
                      child: Text(
                        widget.message.toUpperCase(),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: widget.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (widget.action != null) ...[
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          widget.onDismiss();
                          widget.action!.onPressed();
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Text(
                            widget.action!.label.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: widget.tint,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
