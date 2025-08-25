import 'dart:convert';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/services/creature_repository.dart';

class ParentSnapshot {
  // NEW: keep both ids
  final String? instanceId; // ULID/GUID of the parent instance (for audit)
  final String baseId; // species/catalog id (e.g. CR001)

  // Display/cache fields (can be rehydrated from repo via baseId)
  final String name;
  final List<String> types;
  final String rarity;
  final String image;
  final bool isPrismaticSkin;
  final Genetics? genetics; // instance genetics at breed time
  final NatureDef? nature; // instance nature at breed time
  final SpriteData? spriteData;

  const ParentSnapshot({
    required this.instanceId,
    required this.baseId,
    required this.name,
    required this.types,
    required this.rarity,
    required this.image,
    this.isPrismaticSkin = false,
    this.genetics,
    this.nature,
    this.spriteData,
  });

  /// Use this when you are breeding **instances**.
  factory ParentSnapshot.fromDbInstance(
    db.CreatureInstance inst,
    CreatureRepository repo,
  ) {
    final base = repo.getCreatureById(inst.baseId)!; // repo must be loaded
    final genetics = decodeGenetics(inst.geneticsJson);

    return ParentSnapshot(
      instanceId: inst.instanceId,
      baseId: inst.baseId,
      name: base.name,
      types: base.types,
      rarity: base.rarity,
      image: base.image,
      isPrismaticSkin: inst.isPrismaticSkin,
      genetics: genetics,
      nature: inst.natureId != null
          ? NatureCatalog.byId(inst.natureId!)
          : base.nature,
      spriteData: base.spriteData, // for thumbnail animation
    );
  }

  /// Legacy helper (catalog creature only) — OK for wild/exploration spawns.
  factory ParentSnapshot.fromCreature(Creature c) => ParentSnapshot(
    instanceId: null,
    baseId: c.id,
    name: c.name,
    types: List<String>.from(c.types),
    rarity: c.rarity,
    image: c.image,
    isPrismaticSkin: c.isPrismaticSkin,
    genetics: c.genetics,
    nature: c.nature,
    spriteData: c.spriteData,
  );

  /// Back-compat JSON decode. Old saves used `id` ambiguously.
  factory ParentSnapshot.fromJson(Map<String, dynamic> j) {
    final legacyId = j['id'] as String?;
    final baseId = (j['baseId'] ?? legacyId) as String; // prefer baseId
    final instanceId = j['instanceId'] as String?; // null in old saves

    return ParentSnapshot(
      instanceId: instanceId,
      baseId: baseId,
      name: j['name'] as String,
      types: List<String>.from(j['types'] as List),
      rarity: j['rarity'] as String,
      image: j['image'] as String,
      isPrismaticSkin: (j['isPrismaticSkin'] ?? false) as bool,
      genetics: j['genetics'] != null
          ? Genetics(Map<String, String>.from(j['genetics'] as Map))
          : null,
      nature: j['nature'] != null
          ? NatureDef.fromJson(j['nature'] as Map<String, dynamic>)
          : null,
      spriteData: j['spriteData'] != null
          ? SpriteData.fromJson(j['spriteData'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    // Write new keys; keep legacy 'id' for older readers if you want
    'instanceId': instanceId,
    'baseId': baseId,
    'id': baseId, // legacy compatibility
    'name': name,
    'types': types,
    'rarity': rarity,
    'image': image,
    'isPrismaticSkin': isPrismaticSkin,
    if (genetics != null) 'genetics': genetics!.variants,
    if (nature != null) 'nature': nature!.toJson(),
    if (spriteData != null)
      'spriteData': {
        'frameWidth': spriteData!.frameWidth,
        'frameHeight': spriteData!.frameHeight,
        'totalFrames': spriteData!.totalFrames,
        'frameDurationMs': spriteData!.frameDurationMs,
        'rows': spriteData!.rows,
        'spriteSheetPath': spriteData!.spriteSheetPath,
      },
  };

  /// Rehydrate display fields from the catalog (use after app restart).
  ParentSnapshot rehydrate(CreatureRepository repo) {
    final base = repo.getCreatureById(baseId);
    if (base == null) return this;
    return ParentSnapshot(
      instanceId: instanceId,
      baseId: baseId,
      name: base.name,
      types: base.types,
      rarity: base.rarity,
      image: base.image,
      isPrismaticSkin: isPrismaticSkin,
      genetics: genetics,
      nature: nature ?? base.nature,
      spriteData: spriteData ?? base.spriteData,
    );
  }
}

class Parentage {
  final ParentSnapshot parentA;
  final ParentSnapshot parentB;
  final DateTime bredAt;

  const Parentage({
    required this.parentA,
    required this.parentB,
    required this.bredAt,
  });

  factory Parentage.fromJson(Map<String, dynamic> j) => Parentage(
    parentA: ParentSnapshot.fromJson(j['parentA'] as Map<String, dynamic>),
    parentB: ParentSnapshot.fromJson(j['parentB'] as Map<String, dynamic>),
    bredAt: DateTime.parse(j['bredAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'parentA': parentA.toJson(),
    'parentB': parentB.toJson(),
    'bredAt': bredAt.toIso8601String(),
  };

  Parentage rehydrate(CreatureRepository repo) => Parentage(
    parentA: parentA.rehydrate(repo),
    parentB: parentB.rehydrate(repo),
    bredAt: bredAt,
  );
}

// tiny helper for the factory above
Genetics? decodeGenetics(String? jsonStr) {
  if (jsonStr == null || jsonStr.isEmpty) return null;
  try {
    final map = Map<String, dynamic>.from(jsonDecode(jsonStr));
    return Genetics(map.map((k, v) => MapEntry(k, v.toString())));
  } catch (_) {
    return null;
  }
}
