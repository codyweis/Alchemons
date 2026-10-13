// lib/services/friend_fusion_lab.dart
//
// The save's side of fusing with a friend (TradeMode.fuse in
// lib/models/trade.dart), for TradeService: whether this player's Alchemon
// may fuse with the friend's here — the lab's own rules, each player's own
// unlocks — making the cultivation the two of them get, and placing this
// player's copy of it with the rest its parent takes.

import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';

class FriendFusionLab {
  const FriendFusionLab({required this.breeding, required this.stamina});

  final BreedingServiceV2 breeding;
  final StaminaService stamina;

  CreatureCatalog get catalog => breeding.repository;

  /// The longest a cultivation may be on the table (the rules allow 60000);
  /// past it, its fusion analysis is left out.
  static const int maxResultLength = 50000;

  /// Why [mine] can't fuse with the friend's [theirs] in this game, or null.
  /// The friend's game asks the same of theirs.
  Future<String?> whyNot(CreatureInstance mine, CreatureInstance theirs) async {
    final a = catalog.getCreatureById(mine.baseId);
    final b = catalog.getCreatureById(theirs.baseId);
    if (a == null || b == null) return 'This game does not know that Alchemon.';
    final mysticA = a.mutationFamily == 'Mystic';
    final mysticB = b.mutationFamily == 'Mystic';
    if ((mysticA || mysticB) && !(mysticA && mysticB && a.id == b.id)) {
      return 'Mystics fuse only with their own species.';
    }
    if (!await breeding.canCrossBreed(a.id, b.id)) {
      return 'Two families: you need Cross-Species Lineage.';
    }
    if (!await stamina.canBreed(mine.instanceId)) return 'Yours is resting.';
    return null;
  }

  /// The cultivation the two make, as it goes on the table; null when they
  /// make nothing. [a] is the table's first side's, [b] its second's.
  String? brew(CreatureInstance a, CreatureInstance b) {
    final payload = breeding.brewForFriends(a, b);
    if (payload == null) return null;
    final raw = payload.toJsonString();
    if (raw.length <= maxResultLength) return raw;
    final lean = EggPayload.fromJson(
      payload.toJson()..remove('likelihoodAnalysis'),
    );
    final leanRaw = lean.toJsonString();
    return leanRaw.length <= maxResultLength ? leanRaw : null;
  }

  /// [raw] (a table's cultivation) read, or null when this game can't hatch
  /// it.
  EggPayload? read(String? raw) {
    if (raw == null || raw.isEmpty || raw.length > maxResultLength) return null;
    try {
      final p = EggPayload.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      return catalog.getCreatureById(p.baseId) == null ? null : p;
    } catch (_) {
      return null;
    }
  }

  /// This player's copy of [payload] into a chamber (or cold storage), with
  /// [origin] in its history, and [mineId] resting after it as after any
  /// fusion (if it is still here). [theirs] is the friend's parent.
  Future<EggCreationResult> place({
    required EggPayload payload,
    required FusionOrigin origin,
    required String mineId,
    required CreatureInstance theirs,
  }) async {
    final mine = await breeding.db.creatureDao.getInstance(mineId);
    final mineSpecies = mine == null
        ? null
        : catalog.getCreatureById(mine.baseId);
    final theirSpecies = catalog.getCreatureById(theirs.baseId);
    bool fire(Creature? c) => c?.types.contains('Fire') ?? false;
    final placed = await breeding.placeFriendVial(
      EggPayload.fromJson({
        ...payload.toJson(),
        'provenance': TradeProvenance(const [], fused: origin).encode(),
      }),
      bothParentsFire: fire(mineSpecies) && fire(theirSpecies),
    );
    if (placed.success && mine != null) {
      await stamina.spendForBreeding(
        mineId,
        instanceOverlayForNature: mineSpecies,
      );
    }
    return placed;
  }
}
