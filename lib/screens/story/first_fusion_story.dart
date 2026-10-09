// lib/screens/story/first_fusion_story.dart
//
// "Two becomes one again": the remembered line that answers the first time
// the player pours two Alchemons into one. It played at the first
// extraction once — the starter vial, which fuses nothing — so it now waits
// for a fusion that lands, from the breed chamber or out in the wild,
// whichever the player makes first.

import 'package:alchemons/screens/story/models/story_page.dart';
import 'package:alchemons/widgets/starter_granted_dialog.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Plays the first-fusion story once, if it has not been seen; returns
/// straight away otherwise (and where no [StoryManager] is provided).
Future<void> maybePlayFirstFusionStory(BuildContext context) async {
  final story = context.read<StoryManager?>();
  if (story == null || story.hasSeen(StoryEvent.firstBreeding)) return;
  story.trigger(StoryEvent.firstBreeding);
  final pages = story.drainQueue();
  if (pages.isEmpty) return;
  // The introduction and the remembered lines it introduces are one
  // dialog with two pages, not two dialogs back to back.
  await SystemDialog.playStory(
    context,
    pages,
    lead: const [
      StoryBeat(
        title: 'An older echo',
        message:
            'Two lives pour into one vial. Another presence speaks as '
            'though it remembers an earlier ritual.',
      ),
    ],
  );
  await story.acknowledge(StoryEvent.firstBreeding);
}
