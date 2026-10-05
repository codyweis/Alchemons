import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/story_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _pureExtractionIntroSeenKey = 'pure_extraction_intro_seen_v1';

/// The first time a bred specimen comes out pure: what purity is, and what it
/// does, as two pages of the shared story dialog.
Future<void> maybeShowFirstPureExtractionDialog(
  BuildContext context, {
  required CreatureInstance instance,
  required Creature species,
}) async {
  if ((instance.parentageJson ?? '').trim().isEmpty) return;

  final purity = classifyInstancePurity(instance, species: species);
  if (!purity.isPure) return;

  final prefs = await SharedPreferences.getInstance();
  final alreadySeen = prefs.getBool(_pureExtractionIntroSeenKey) ?? false;
  if (alreadySeen || !context.mounted) return;

  await prefs.setBool(_pureExtractionIntroSeenKey, true);
  if (!context.mounted) return;

  final elementLabel = _singleLineageLabel(purity.elementLineage) ?? 'one';
  final familyLabel = _singleLineageLabel(purity.speciesLineage) ?? 'one';

  await showStoryDialog(
    context,
    kind: StoryDialogKind.success,
    primaryLabel: 'UNDERSTOOD',
    barrierDismissible: true,
    beats: [
      StoryBeat(
        title: 'Pure lineage',
        message:
            'You extracted a Pure Alchemon: its ancestry resolves to one '
            'element line and one species line. This one carries a '
            '$elementLabel element line and a $familyLabel family line.\n\n'
            'Purity is tracked apart from generation, so a line stays pure '
            'for as long as its ancestry stays unbroken.',
      ),
      const StoryBeat(
        title: 'What purity does',
        message:
            'A pure line strengthens one stat, chosen at extraction and fixed '
            'for life. A full line raises one of the four by 15%. An element '
            'line raises Beauty or Intelligence by 10%; a species line raises '
            'Speed or Strength by 10%. Analysis shows which one it rolled.\n\n'
            'Everything else still comes from species, level, Potential, '
            'nature and Enhancement.',
      ),
    ],
  );
}

String? _singleLineageLabel(Map<String, int> lineage) {
  if (lineage.length != 1) return null;
  return lineage.keys.first;
}
