import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _pureExtractionIntroSeenKey = 'pure_extraction_intro_seen_v1';

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

  final theme = context.read<FactionTheme>();
  final elementLabel = _singleLineageLabel(purity.elementLineage) ?? 'one';
  final familyLabel = _singleLineageLabel(purity.speciesLineage) ?? 'one';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: theme.surface,
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: theme.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pure Lineage Extracted',
                style: TextStyle(
                  color: theme.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You just extracted a Pure Alchemon.',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Pure means its ancestry resolves to one element line and one species line.',
                style: TextStyle(color: theme.text.withValues(alpha: 0.92)),
              ),
              const SizedBox(height: 12),
              Text(
                'This specimen carries a $elementLabel element line and a $familyLabel family line.',
                style: TextStyle(color: theme.text.withValues(alpha: 0.86)),
              ),
              const SizedBox(height: 12),
              Text(
                'This happened because the breeding line stayed unbroken through both its elemental ancestry and its species ancestry.',
                style: TextStyle(color: theme.text.withValues(alpha: 0.86)),
              ),
              const SizedBox(height: 12),
              Text(
                'Its generation number will still rise normally over future breeding. Purity is tracked separately, so a line can stay pure across generations if that ancestry stays unbroken.',
                style: TextStyle(color: theme.text.withValues(alpha: 0.86)),
              ),
              const SizedBox(height: 12),
              Text(
                'Pure specimens get small base bonuses to Beauty, Strength, and Intelligence when they are extracted.',
                style: TextStyle(color: theme.text.withValues(alpha: 0.86)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Understood', style: TextStyle(color: theme.accent)),
          ),
        ],
      );
    },
  );
}

String? _singleLineageLabel(Map<String, int> lineage) {
  if (lineage.length != 1) return null;
  return lineage.keys.first;
}
