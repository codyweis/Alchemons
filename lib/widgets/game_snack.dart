import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

/// One look for every notification in the game.
///
/// There were sixty-odd snackbars across the app in three different states:
/// thirty-five raw ones that rendered as a plain Material slab with none of
/// the game on them (the achievement notice among them), twenty-five styled
/// by hand in whatever way that screen felt like, and several that used a
/// saturated red or green as the *background*, which made an ordinary
/// "not enough silver" shout louder than anything else on screen.
///
/// This is the same grammar the dialogs use — dark surface, a coloured bar
/// down the left, caps monospace — so a notification reads as this game's
/// notification, and the colour carries the severity instead of the whole
/// rectangle.
/// The fixed height of a notification's content row, and the padding above
/// and below it. Together they make the bar's total height known, which is
/// what lets it be placed exactly rather than approximately.
const double _contentHeight = 38;
const double _verticalPadding = 11;

/// What the app-level builder assumes for snackbars that do NOT come through
/// here — the raw ones scattered around the codebase, whose height it cannot
/// know. Generous on purpose: too small clips them off the top of the screen,
/// too large only sits them lower.
const double kSnackHeight = 140;

/// Breathing room under the status bar.
const double kSnackTopGap = 14;

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
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final fc = FC.of(context);
  final tint = accent ?? fc.amber;

  // Positioned here rather than left to the theme, because only here is the
  // height known.
  //
  // A floating SnackBar is placed by its bottom margin and then grows UPWARD
  // from that edge, so a guessed height is only ever right for one shape of
  // notification: anything taller — two lines of text, or an action button
  // beside them — pushed its top past the status bar and clipped. Fixing the
  // content's height makes the total predictable, so the lift is exact for
  // every notification instead of approximately right for short ones.
  final media = MediaQuery.of(context);
  final total = _contentHeight + _verticalPadding * 2;
  final lift =
      (media.size.height - media.viewPadding.top - kSnackTopGap - total).clamp(
        0.0,
        double.infinity,
      );

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(left: 14, right: 14, bottom: lift),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: _verticalPadding,
      ),
      // Sideways, not down. Set here as well as on the theme because a
      // SnackBar's own value wins over the theme's.
      dismissDirection: DismissDirection.horizontal,
      backgroundColor: fc.bg1,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: tint.withValues(alpha: 0.5)),
      ),
      action: action == null
          ? null
          : SnackBarAction(
              label: action.label,
              onPressed: action.onPressed,
              textColor: tint,
            ),
      content: SizedBox(
        height: _contentHeight,
        child: Row(
          children: [
            Container(width: 3, height: 26, color: tint),
            const SizedBox(width: 11),
            if (icon != null) ...[
              Icon(icon, size: 16, color: tint),
              const SizedBox(width: 9),
            ],
            Expanded(
              child: Text(
                message.toUpperCase(),
                // Two lines is the ceiling. A notification long enough to need
                // three is one that should have been shorter, and letting it
                // grow is what made the height unknowable.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fc.textPrimary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
