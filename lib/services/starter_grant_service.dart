// lib/services/starter_grant.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/constants/breed_constants.dart';

extension StarterGrant on AlchemonsDatabase {
  /// Grants exactly one starter egg that matches the chosen faction.
  /// - If an incubator is free: places egg there.
  /// - Else: enqueues to storage.
  /// Returns `true` if granted, `false` if already granted before.
  Future<bool> ensureStarterGranted(
    FactionId faction, {
    Duration? tutorialHatch,
  }) async {
    // Prevent double-grants (in case user re-opens picker)
    final already = await getSetting('starter_granted_v1');
    if (already == '1') return false;

    final baseId = _pickLetForFaction(faction);
    final rarity = 'common'; // lower-case plays nice with your UI maps
    final hatchDur =
        tutorialHatch ??
        (BreedConstants.rarityHatchTimes[rarity] ?? const Duration(minutes: 5));

    final eggId = _makeEggId('START');

    // Optional payload to tag the egg as starter (and carry defaults through)
    final payload = jsonEncode({
      'source': 'starter',
      'baseId': baseId,
      'rarity': 'Common', // base creature rarity label (cosmetic)
      // 'genetics': {...} // add later if you want random genes
    });

    final free = await firstFreeSlot();
    if (free != null) {
      await placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: baseId,
        bonusVariantId: null,
        rarity: rarity, // UI expects lower-case key for hatch-time map
        hatchAtUtc: DateTime.now().toUtc().add(hatchDur),
        payloadJson: payload,
      );
    } else {
      await enqueueEgg(
        eggId: eggId,
        resultCreatureId: baseId,
        bonusVariantId: null,
        rarity: rarity,
        remaining: hatchDur,
        payloadJson: payload,
      );
    }

    await setSetting('starter_granted_v1', '1');
    return true;
  }

  // Map faction → the Let that matches its element.
  String _pickLetForFaction(FactionId faction) {
    switch (faction) {
      case FactionId.fire:
        return 'LET01'; // Fire
      case FactionId.water:
        return 'LET02'; // Water
      case FactionId.earth:
        return 'LET03'; // Earth
      case FactionId.air:
        return 'LET04'; // Air
    }
  }

  // Quick unique-ish id (fine for local DB)
  String _makeEggId(String prefix) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final r = math.Random(
      now,
    ).nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '$prefix\_$now\_$r';
  }
}
