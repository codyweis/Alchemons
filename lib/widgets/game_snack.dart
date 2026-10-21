import 'dart:async';

import 'package:alchemons/utils/app_scaffold_messenger.dart';
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

  /// Puts the notice that is showing away, if one is.
  static VoidCallback? _close;

  static void _dismiss() {
    final close = _close;
    _close = null;
    close?.call();
  }
}

/// Breathing room under the status bar.
const double kSnackTopGap = 12;

/// What the app-level SnackBar theme assumes for the raw snackbars that do
/// not come through here. They keep the old lift-by-margin behaviour, so this
/// stays generous: too small clips them off the screen, too large only sits
/// them lower.
const double kSnackHeight = 140;

/// [message] wherever the player is by now: for what comes back after the
/// screen that started it has gone (a write the server refused, while the
/// player had already moved on — screens never wait on the network).
void showGameSnackAnywhere(String message, {Color? accent}) {
  final nav = rootNavigatorKey.currentState;
  final overlay = nav?.overlay;
  if (nav == null || overlay == null) return;
  showGameSnack(nav.context, message, overlay: overlay, accent: accent);
}

void showGameSnack(
  BuildContext context,
  String message, {

  /// Notices no longer carry an icon; kept until the last caller drops it.
  @Deprecated('Notices no longer show an icon; drop the argument')
  IconData? icon,

  /// The severity color. It tints the bar and the border; it is
  /// never the background.
  Color? accent,
  SnackBarAction? action,

  /// A quieter second choice before [action] (an invitation's DECLINE).
  SnackBarAction? secondary,
  Duration duration = const Duration(seconds: 3),

  /// Where it shows, for a caller outside any screen (the navigator's own
  /// overlay); the root overlay over [context] otherwise.
  OverlayState? overlay,
}) {
  overlay ??= Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final fc = FC.of(context);
  final tint = accent ?? fc.amber;

  // One at a time. A second notification replaces the first rather than
  // stacking on top of it or queueing behind it.
  GameSnack._dismiss();

  // Each notice removes its own entry, once. Keyed on the entry rather than
  // on whichever is current: two shown in one frame used to leave the first
  // (inserted but not yet built, so not "mounted") in the overlay, and its
  // swipe then removed the second and left itself behind as a dismissed
  // Dismissible still in the tree.
  late OverlayEntry entry;
  var gone = false;
  void close() {
    if (gone) return;
    gone = true;
    if (GameSnack._close == close) GameSnack._close = null;
    // A progress reset can take the overlay down first.
    if (overlay!.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => _TopNotification(
      message: message,
      tint: tint,
      surface: fc.bg1,
      text: fc.textPrimary,
      action: action,
      secondary: secondary,
      duration: duration,
      onDismiss: close,
    ),
  );
  GameSnack._close = close;
  overlay.insert(entry);
}

class _TopNotification extends StatefulWidget {
  const _TopNotification({
    required this.message,
    required this.tint,
    required this.surface,
    required this.text,
    required this.action,
    required this.duration,
    required this.onDismiss,
    this.secondary,
  });

  final String message;
  final Color tint;
  final Color surface;
  final Color text;
  final SnackBarAction? action;
  final SnackBarAction? secondary;
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

  /// A choice on the right: tapping it puts the notice away and does it.
  Widget _label(SnackBarAction action, Color color) => GestureDetector(
    onTap: () {
      widget.onDismiss();
      action.onPressed();
    },
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Text(
        action.label.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
    ),
  );

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
              // The whole bar is the button when there is somewhere to go.
              // The label on the right says what tapping does; making only
              // that label live meant most taps — aimed at the words the
              // player was reading — did nothing.
              child: GestureDetector(
                onTap: widget.action == null
                    ? null
                    : () {
                        widget.onDismiss();
                        widget.action!.onPressed();
                      },
                behavior: HitTestBehavior.opaque,
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
                      if (widget.secondary case final second?) ...[
                        const SizedBox(width: 10),
                        _label(second, widget.text.withValues(alpha: 0.55)),
                      ],
                      if (widget.action case final action?) ...[
                        const SizedBox(width: 10),
                        _label(action, widget.tint),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
