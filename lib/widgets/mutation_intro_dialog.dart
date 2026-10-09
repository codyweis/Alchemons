import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _mutationIntroSeenKey(AlchemonMutation m) =>
    'mutation_extraction_intro_seen_${m.id}_v1';

/// The first time each mutation is extracted: what it is and where it comes
/// from. Once per mutation, so the second kind is explained when it arrives.
Future<void> maybeShowFirstMutationExtractionDialog(
  BuildContext context, {
  required CreatureInstance instance,
}) async {
  final mutation = AlchemonMutation.byId(instance.mutation);
  if (mutation == null) return;

  final prefs = await SharedPreferences.getInstance();
  final key = _mutationIntroSeenKey(mutation);
  if ((prefs.getBool(key) ?? false) || !context.mounted) return;

  await prefs.setBool(key, true);
  if (!context.mounted) return;

  await showStoryDialog(
    context,
    kind: StoryDialogKind.success,
    primaryLabel: 'UNDERSTOOD',
    barrierDismissible: true,
    beats: [
      StoryBeat(
        title: mutation.label,
        message:
            'You extracted a ${mutation.label} Alchemon. This is a rare '
            'mutation that only occurs when fusing with wild Alchemons in '
            'the realms.\n\n'
            'It is not genetic.\n\n'
            'Only two mutations are known, though there are rumored to be '
            'more.',
      ),
    ],
  );
}
