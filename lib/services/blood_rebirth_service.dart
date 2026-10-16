import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/potential_soul.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/instance_stat_traits.dart';
import 'package:drift/drift.dart' show Value;

/// The Blood Ring's rite. The favorite is consumed; a Bloodborn Vial goes to
/// the extraction chamber with its whole record, and what is extracted from
/// it is the favorite made new: its level, training, name and natures, every
/// Potential at least 95 (never lowered), Bloodborn, in the Blood Aura.
class BloodRebirthService {
  BloodRebirthService(this.db);
  final AlchemonsDatabase db;

  /// The least any Potential comes back with. One already higher keeps its
  /// own: the rite never takes from a favorite.
  static const potential = 95.0;
  static const vialName = 'Bloodborn Vial';

  /// The offering's row as it was at the ring, kept in the vial's payload.
  static const recordKey = 'rebirthOf';

  /// Offers [instanceId] at the ring. The vial is ready at once: in the first
  /// free chamber, or in cold storage when every chamber is full. The
  /// offering's Potential Souls come back to the inventory, free, and what
  /// they added comes out with them; then each Potential it was born with
  /// rises to 95, or stays if it is higher. True when the vial went into a
  /// chamber, false when to cold storage, null when the rite was already
  /// done (nothing changes). The deletion, the vial, the Souls, the aura and
  /// the completion marker commit together.
  Future<bool?> offer(
    String instanceId,
    Creature species,
  ) => db.transaction(() async {
    if ((await db.settingsDao.getSetting(CampaignJournalService.endingKey) ??
            '')
        .isNotEmpty) {
      return null;
    }
    final instance = await db.creatureDao.getInstance(instanceId);
    if (instance == null || instance.baseId != species.id) {
      throw StateError('The chosen companion is no longer available.');
    }
    final souls = PotentialSoulLedger.decode(instance.potentialSouls);
    double reborn(double was, String stat) =>
        math.max(potential, was - souls.gainIn(stat));
    final record = instance.copyWith(
      statSpeedPotential: reborn(instance.statSpeedPotential, 'speed'),
      statIntelligencePotential: reborn(
        instance.statIntelligencePotential,
        'intelligence',
      ),
      statStrengthPotential: reborn(instance.statStrengthPotential, 'strength'),
      statBeautyPotential: reborn(instance.statBeautyPotential, 'beauty'),
      potentialSouls: const Value(null),
    );
    final payloadJson = jsonEncode({
      ..._vialPayload(record, species).toJson(),
      recordKey: record.toJson(),
    });
    final eggId = db.creatureDao.makeInstanceId('BLOOD');
    final free = await db.incubatorDao.firstFreeSlot();
    if (free != null) {
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: species.id,
        rarity: species.rarity,
        hatchAtUtc: DateTime.now().toUtc(),
        payloadJson: payloadJson,
      );
    } else {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: species.id,
        rarity: species.rarity,
        remaining: Duration.zero,
        payloadJson: payloadJson,
      );
    }
    if (souls.count > 0) {
      await db.inventoryDao.addItemQty(InvKeys.potentialSoul, souls.count);
    }
    await db.creatureDao.deleteInstances([instanceId]);
    await db.inventoryDao.addItemQty(InvKeys.alchemyBloodAura, 1);
    await db.settingsDao.setSetting(CampaignJournalService.endingKey, eggId);
    return free != null;
  });

  /// Whether [payload] is a vial from [offer] (it carries the offering).
  static bool carriesRecord(Map<String, dynamic> payload) =>
      payload[recordKey] is Map;

  /// Extracts a vial from [offer]: the offering's row under a new id,
  /// Bloodborn, every Potential at least 95, stats derived again at its own
  /// level and training, rested, in the Blood Aura. Null when its species is
  /// already at the cap (the vial stays).
  Future<String?> hatch(Map<String, dynamic> payload, Creature species) =>
      db.transaction(() async {
        final was = CreatureInstance.fromJson(
          Map<String, dynamic>.from(payload[recordKey] as Map),
        );
        if (!await db.creatureDao.canAddInstance(species.id)) return null;
        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        final id = db.creatureDao.makeInstanceId();
        double floor(double p) => math.max(potential, p);
        var reborn = was.copyWith(
          instanceId: id,
          baseId: species.id,
          source: 'bloodborn',
          variantFaction: const Value('bloodborn'),
          alchemyEffect: const Value('blood_aura'),
          potentialSouls: const Value(null),
          statSpeedPotential: floor(was.statSpeedPotential),
          statIntelligencePotential: floor(was.statIntelligencePotential),
          statStrengthPotential: floor(was.statStrengthPotential),
          statBeautyPotential: floor(was.statBeautyPotential),
          staminaBars: was.staminaMax,
          staminaLastUtcMs: now,
          createdAtUtcMs: now,
        );
        final joined = await FactionService.joinedId(db);
        final base = species.baseStats;
        double of(String key) => switch (key) {
          'speed' => reborn.statSpeedPotential,
          'intelligence' => reborn.statIntelligencePotential,
          'strength' => reborn.statStrengthPotential,
          _ => reborn.statBeautyPotential,
        };
        double stat(String key, int? points, int enhancement) =>
            AlchemonStatSystem.effectiveInternal(
              speciesBase: points ?? 60,
              level: reborn.level,
              potential: of(key),
              enhancementRank: enhancement,
              additionalMultiplier: instanceTraitMultiplier(
                reborn,
                key,
                species: species,
                joinedFaction: joined,
              ),
            );
        reborn = reborn.copyWith(
          statSpeed: stat('speed', base?.speed, reborn.statSpeedEnhancement),
          statIntelligence: stat(
            'intelligence',
            base?.intelligence,
            reborn.statIntelligenceEnhancement,
          ),
          statStrength: stat(
            'strength',
            base?.strength,
            reborn.statStrengthEnhancement,
          ),
          statBeauty: stat(
            'beauty',
            base?.beauty,
            reborn.statBeautyEnhancement,
          ),
        );
        await db.into(db.creatureInstances).insert(reborn);
        await db.settingsDao.setSetting(CampaignJournalService.endingKey, id);
        return id;
      });

  /// What the chamber and cold storage read: the species, its natures and
  /// genes for its look, and the Potentials it will come back with.
  static EggPayload _vialPayload(CreatureInstance was, Creature species) {
    Map<String, int> counts(String? raw) {
      if (raw == null || raw.isEmpty) return {};
      try {
        final m = jsonDecode(raw);
        if (m is! Map) return {};
        return {
          for (final e in m.entries)
            if (e.value is num) '${e.key}': (e.value as num).toInt(),
        };
      } catch (_) {
        return {};
      }
    }

    Map<String, String> genetics() {
      final raw = was.geneticsJson;
      if (raw == null || raw.isEmpty) return {};
      try {
        final m = jsonDecode(raw);
        if (m is! Map) return {};
        return {for (final e in m.entries) '${e.key}': '${e.value}'};
      } catch (_) {
        return {};
      }
    }

    return EggPayload(
      baseId: species.id,
      rarity: species.rarity,
      source: 'bloodborn',
      vialName: vialName,
      natureId: was.natureId,
      natureId2: was.natureId2,
      isPrismaticSkin: was.isPrismaticSkin,
      genetics: genetics(),
      mutation: was.mutation,
      stats: CreatureStats(
        speed: was.statSpeed,
        intelligence: was.statIntelligence,
        strength: was.statStrength,
        beauty: was.statBeauty,
      ),
      potentials: CreatureStatPotentials(
        speed: was.statSpeedPotential,
        intelligence: was.statIntelligencePotential,
        strength: was.statStrengthPotential,
        beauty: was.statBeautyPotential,
      ),
      lineage: LineageData(
        generationDepth: was.generationDepth,
        nativeFaction: elementalGroupNameOf(species),
        variantFaction: 'bloodborn',
        factionLineage: counts(was.factionLineageJson),
        elementLineage: counts(was.elementLineageJson),
        familyLineage: counts(was.familyLineageJson),
        isPure: was.isPure,
      ),
      likelihoodAnalysisJson: was.likelihoodAnalysisJson,
      provenance: was.provenance,
    );
  }
}
