// lib/widgets/starter_granted_dialog.dart
//
// SystemDialog: the lab's notices and story cards. It draws in the shared
// story dialog (widgets/story_dialog.dart); this keeps the old call shape.

import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';

enum SystemDialogKind { info, success, warning, danger }

class SystemDialog {
  const SystemDialog._();

  /// [pages] as one dialog that pages in place, each page's [StoryPage.mainText]
  /// in the story's voice under its subtitle. [lead] goes first, as plain
  /// pages (an introduction to the story lines that follow).
  static Future<void> playStory(
    BuildContext context,
    List<StoryPage> pages, {
    List<StoryBeat> lead = const [],
  }) async {
    if (pages.isEmpty && lead.isEmpty) return;
    await showStoryDialog(
      context,
      beats: [
        ...lead,
        for (final page in pages)
          StoryBeat(
            title: page.subtitle ?? '',
            message: '',
            voice: page.mainText,
          ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    SystemDialogKind kind = SystemDialogKind.info,
    IconData? icon,
    String primaryLabel = 'CONTINUE',
    VoidCallback? onPrimary,
    String? secondaryLabel,
    VoidCallback? onSecondary,
    bool barrierDismissible = false,
  }) {
    return showStoryDialog(
      context,
      beats: [StoryBeat(title: title, message: message)],
      kind: StoryDialogKind.values[kind.index],
      primaryLabel: primaryLabel,
      onPrimary: onPrimary,
      secondaryLabel: secondaryLabel,
      onSecondary: onSecondary,
      barrierDismissible: barrierDismissible,
    );
  }
}
