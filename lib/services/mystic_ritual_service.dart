import 'dart:convert';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/data/mystic_altar_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/campaign_journal_service.dart';

class MysticRitualService {
  MysticRitualService(this.db);
  final AlchemonsDatabase db;

  Future<void> commit({
    required String bossId,
    required String speciesId,
    required String instanceId,
    required String snapshotJson,
  }) => db.transaction(() async {
    if (await db.altarDao.isSlotFilled(bossId, speciesId)) {
      throw StateError('This altar slot is already filled.');
    }
    final instance = await db.creatureDao.getInstance(instanceId);
    if (instance == null || instance.locked || instance.baseId != speciesId) {
      throw StateError('That specimen is no longer available.');
    }
    await db.altarDao.placeAlchemon(
      bossId: bossId,
      speciesId: speciesId,
      instanceId: instanceId,
      snapshotJson: snapshotJson,
    );
    await db.creatureDao.deleteInstances([instanceId]);
  });

  /// Reward placement, consumed commitments, and witness record are atomic.
  /// A full chamber sends the vial to storage; it never purchases a slot.
  Future<void> summon({
    required String bossId,
    required String element,
    required String targetSpeciesId,
    required Set<String> requiredSpecies,
    required Map<String, dynamic> Function(List<AltarPlacement>) payload,
  }) => db.transaction(() async {
    final placements = await db.altarDao.getPlacementsForBoss(bossId);
    final placed = placements.map((p) => p.speciesId).toSet();
    if (requiredSpecies.isEmpty || !placed.containsAll(requiredSpecies)) {
      throw StateError('The altar still needs specimens.');
    }
    final relicPlaced = (await db.altarDao.getRelicPlacedIds([
      bossId,
    ])).contains(bossId);
    final qty = await db.inventoryDao.getItemQty(
      BossLootKeys.traitKeyForElement(element),
    );
    if (!relicPlaced && qty < 1) {
      throw StateError('The guardian relic is missing.');
    }
    if (element.toLowerCase() == 'blood') {
      for (final witness in kAltarEntries.where((e) => e.order < 17)) {
        if ((await db.settingsDao.getSetting('altar_summoned_${witness.id}') ??
                '')
            .isEmpty) {
          throw StateError('The earlier Mystic rituals are not complete.');
        }
      }
    }
    final encoded = jsonEncode(payload(placements));
    final eggId = db.creatureDao.makeInstanceId('MYSTIC');
    final slot = await db.incubatorDao.firstFreeSlot();
    const delay = Duration(hours: 1);
    if (slot != null) {
      await db.incubatorDao.placeEgg(
        slotId: slot.id,
        eggId: eggId,
        resultCreatureId: targetSpeciesId,
        rarity: 'Mythic',
        hatchAtUtc: DateTime.now().toUtc().add(delay),
        payloadJson: encoded,
      );
    } else {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: targetSpeciesId,
        rarity: 'Mythic',
        remaining: delay,
        payloadJson: encoded,
      );
    }
    await db.altarDao.setRelicPlaced(bossId);
    await db.altarDao.clearPlacementsForBoss(bossId);
    await db.settingsDao.setSetting(
      'altar_summoned_$bossId',
      DateTime.now().toUtc().toIso8601String(),
    );
    await CampaignJournalService(db).record('mystic');
  });
}
