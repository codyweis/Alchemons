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
            'You extracted a ${mutation.label} Alchemon. ${mutation.perk}\n\n'
            'Mutations only happen when fusing with wild Alchemons in the '
            'realms, and they are not inherited. There are '
            '${AlchemonMutation.values.length} kinds.',
      ),
    ],
  );
}
