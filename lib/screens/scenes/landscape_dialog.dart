// lib/screens/scenes/landscape_dialog.dart
//
// The in-world notice used by the wilderness, open space, survival and the
// altar. It draws in the shared story dialog (widgets/story_dialog.dart); this
// keeps the old call shape so those screens didn't all have to change.

import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';

enum LandscapeDialogKind { info, success, warning, danger }

class LandscapeDialog {
  const LandscapeDialog._();

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    LandscapeDialogKind kind = LandscapeDialogKind.info,
    IconData? icon,
    String primaryLabel = 'CONTINUE',
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = false,
  }) {
    return showStoryDialog(
      context,
      // An untitled notice is a story line ("Is this a memory?"), set in the
      // story's voice rather than as a heading-less paragraph.
      beats: [
        title.isEmpty
            ? StoryBeat(title: '', message: '', voice: message)
            : StoryBeat(title: title, message: message),
      ],
      kind: StoryDialogKind.values[kind.index],
      icon: icon,
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      barrierDismissible: barrierDismissible,
    );
  }
}
