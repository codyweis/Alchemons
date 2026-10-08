import 'package:flutter/material.dart';

import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

/// Shows the "leave the game" confirmation for the app shell, asked the way
/// every other leave/exit question is ([showBracketConfirm]).
///
/// Resolves to `true` only when the player deliberately confirms.
Future<bool?> showExitGameDialog(BuildContext context) {
  return showBracketConfirm(
    context,
    palette: BracketPalette.dark,
    accent: kLeaveQuietAccent,
    title: 'EXIT ALCHEMONS?',
    message: 'Your progress is saved.',
    cancelLabel: 'STAY',
    confirmLabel: 'EXIT',
  );
}
