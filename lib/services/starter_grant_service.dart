// lib/services/starter_grant_service.dart
import 'dart:math' as math;
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/constants/breed_constants.dart';

/// Service for granting starter creatures to new players.
/// Uses the standardized EggPayload system for consistency.
class StarterGrantService {
  final AlchemonsDatabase db;
  final EggPayloadFactory payloadFactory;

  StarterGrantService({required this.db, required this.payloadFactory});

  /// Grants exactly one starter egg that matches the chosen faction.
  /// - If an incubator is free: places egg there.
  /// - Else: enqueues to storage.
  /// Returns `true` if granted, `false` if already granted before.
  Future<bool> ensureStarterGranted(
    FactionId faction, {
    Duration? tutorialHatch,
  }) async {
    // Prevent double-grants (in case user re-opens picker)
    final already = await db.settingsDao.getSetting('starter_granted_v1');
    if (already == '1') return false;

    final baseId = _pickLetForFaction(faction);

    // Keep the actual egg rarity as "common" so hatch time uses your UI map.
    final rarity = 'common';
    final hatchDur =
        tutorialHatch ??
        (BreedConstants.rarityHatchTimes[rarity] ?? const Duration(minutes: 5));

    final eggId = _makeEggId('START');

    // Deterministic RNG so results are stable for a given egg
    final seed =
        int.tryParse(eggId.split('_')[1]) ??
        DateTime.now().millisecondsSinceEpoch;

    // --- CREATE STANDARDIZED PAYLOAD ---
    final payload = payloadFactory.createStarterPayload(
      baseId,
      faction,
      seed: seed,
    );

    final payloadJson = payload.toJsonString();

    // --- PLACE OR ENQUEUE EGG ---
    final free = await db.incubatorDao.firstFreeSlot();
    if (free != null) {
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: baseId,
        bonusVariantId: null,
        rarity: rarity, // UI expects lower-case key for hatch-time map
        hatchAtUtc: DateTime.now().toUtc().add(hatchDur),
        payloadJson: payloadJson,
      );
    } else {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: baseId,
        bonusVariantId: null,
        rarity: rarity,
        remaining: hatchDur,
        payloadJson: payloadJson,
      );
    }

    await db.settingsDao.setSetting('starter_granted_v1', '1');
    await db.settingsDao.setSetting('nav_locked_until_extraction_ack', '1');
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
    return '${prefix}_${now}_$r';
  }
}
