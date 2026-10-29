import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/material.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// The app's navigator, for what arrives from outside any screen (an
/// invitation to race) to show itself and open where it leads.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// A notice from outside any screen, in the game's one notice look.
void showAppSnack(
  String message, {
  bool isError = false,
  BuildContext? fallbackContext,
}) {
  final accent = isError ? const Color(0xFFE57373) : null;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    // Before the navigator exists (the very first frames), the caller's own
    // screen is the only place to show it.
    if (rootNavigatorKey.currentState?.overlay == null &&
        fallbackContext != null &&
        fallbackContext.mounted) {
      showGameSnack(fallbackContext, message, accent: accent);
      return;
    }
    showGameSnackAnywhere(message, accent: accent);
  });
}
