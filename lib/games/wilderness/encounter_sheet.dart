import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/widgets/wilderness/encounter_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EncounterSheet extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  const EncounterSheet({
    super.key,
    required this.encounter,
    required this.party,
  });
  @override
  State<EncounterSheet> createState() => _EncounterSheetState();
}

class _EncounterSheetState extends State<EncounterSheet> {
  String? _chosenInstanceId;
  bool _busy = false;
  String _status = 'The wild creature is curious...';

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final wilderness = WildernessService(db, context.read<StaminaService>());

    final totalLuck = widget.party.fold<double>(
      0,
      (a, m) => a + m.luck,
    ); // e.g., sum of 0.0..0.10
    final matchupMult = 1.0; // TODO: compute from types if you like
    final p = wilderness.computeBreedChance(
      base: widget.encounter.baseBreedChance,
      partyLuck: totalLuck,
      matchupMult: matchupMult,
    );

    return EncounterScaffold(
      chanceText: '${(p * 100).toStringAsFixed(0)}% chance',
      status: _status,
      party: widget.party,
      chosenInstanceId: _chosenInstanceId,
      onSelectParty: (id) => setState(() => _chosenInstanceId = id),
      onTry: _busy || _chosenInstanceId == null
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                final spent = await wilderness.trySpendForAttempt(
                  _chosenInstanceId!,
                );
                if (spent == null) {
                  setState(() => _status = 'Too tired… needs rest.');
                  return;
                }

                final success = wilderness.rollSuccess(p);
                if (success) {
                  // spawn egg → same flow you already use in breeding tab
                  await _placeWildEgg(context, widget.encounter.wildBaseId);
                  if (!mounted) return;
                  setState(() => _status = 'Success! You formed an egg.');
                } else {
                  setState(
                    () => _status =
                        'No luck this time… the wild creature is still around.',
                  );
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      onRun: () => Navigator.pop(context),
    );
  }

  Future<void> _placeWildEgg(BuildContext ctx, String baseId) async {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureRepository>();
    final c = repo.getCreatureById(baseId);
    if (c == null) return;

    final rarityKey = c.rarity.toLowerCase();
    final baseHatchDelay =
        BreedConstants.rarityHatchTimes[rarityKey] ??
        const Duration(minutes: 10);
    final hatchAtUtc = DateTime.now().toUtc().add(baseHatchDelay);

    final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';
    final free = await db.firstFreeSlot();
    final payloadJson = jsonEncode({
      'baseId': c.id,
      'rarity': c.rarity,
      'natureId': null,
      'genetics': {}, // wild eggs default genetics; or roll some here
      'parentage': null,
      'isPrismaticSkin': false,
    });

    if (free == null) {
      await db.enqueueEgg(
        eggId: eggId,
        resultCreatureId: c.id,
        bonusVariantId: null,
        rarity: c.rarity,
        remaining: baseHatchDelay,
        payloadJson: payloadJson,
      );
    } else {
      await db.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: c.id,
        bonusVariantId: null,
        rarity: c.rarity,
        hatchAtUtc: hatchAtUtc,
        payloadJson: payloadJson,
      );
    }
  }
}
