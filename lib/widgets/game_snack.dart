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
const double _barHeight = 96;

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

  // Top of the screen, not the bottom.
  //
  // A SnackBar has no anchor of its own; a floating one is positioned by its
  // margin off the bottom, so the whole viewport height minus the bar is what
  // puts it under the status bar. Clamped because a short viewport (a landscape
  // phone, a split screen) would otherwise ask for a negative margin.
  final media = MediaQuery.of(context);
  final topInset = media.padding.top;
  final liftBy = (media.size.height - topInset - _barHeight).clamp(
    0.0,
    double.infinity,
  );

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      behavior: SnackBarBehavior.floating,
      // Sideways, not down. Set here as well as on the theme because a
      // SnackBar's own value wins over the theme's.
      dismissDirection: DismissDirection.horizontal,
      backgroundColor: fc.bg1,
      elevation: 8,
      margin: EdgeInsets.only(left: 14, right: 14, bottom: liftBy),
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
      content: Row(
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
  );
}
