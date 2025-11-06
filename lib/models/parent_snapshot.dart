import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/nature.dart';
import 'package:alchemons/services/creature_repository.dart';

class ParentSnapshot {
  // IDs
  final String? instanceId; // ULID/GUID of the specific instance
  final String baseId; // species/catalog id (e.g. "CR001")

  // Display/cache
  final String name;
  final List<String> types;
  final String rarity;
  final String image;
  final bool isPrismaticSkin;
  final Genetics? genetics;
  final NatureDef? nature;
  final SpriteData? spriteData;
  final CreatureStats? stats;

  // 🔥 NEW: lineage / variant data for breeding math
  final int generationDepth; // how many breed steps from a founder
  final Map<String, int> factionLineage; // {"oceanic":2,"volcanic":1}
  final String
  nativeFaction; // the creature's own faction/family (ex: "oceanic")
  final String?
  variantFaction; // if this parent already expressed an off-faction pigment
  final Map<String, int> elementLineage; // {"Water":3,"Fire":1}
  final Map<String, int> familyLineage; // {"pip":2,"wing":1}

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
    this.stats,
    // NEW required (with defaults in factories for backcompat)
    required this.generationDepth,
    required this.factionLineage,
    required this.nativeFaction,
    required this.variantFaction,
    this.elementLineage = const {},
    this.familyLineage = const {},
  });

  /// Use this when breeding **instances** from DB.
  factory ParentSnapshot.fromDbInstance(
    db.CreatureInstance inst,
    CreatureCatalog repo,
  ) {
    final base = repo.getCreatureById(inst.baseId)!;
    final genetics = decodeGenetics(inst.geneticsJson);

    // decode lineage JSON from DB
    Map<String, int> _decodeLineage(String? raw) {
      if (raw == null || raw.isEmpty) return {};
      try {
        final map = (jsonDecode(raw) as Map<String, dynamic>);
        return map.map((k, v) {
          var key = k.toString();

          // Normalize legacy enum keys: "CreatureFamily.let" -> "Let"
          if (key.startsWith('CreatureFamily.')) {
            final tail = key.split('.').last; // "let"
            key = tail.isEmpty
                ? 'Unknown'
                : tail[0].toUpperCase() + tail.substring(1); // "Let"
          }

          return MapEntry(key, (v as num).toInt());
        });
      } catch (_) {
        return {};
      }
    }

    final nativeFaction = elementalGroupNameOf(base);

    return ParentSnapshot(
      instanceId: inst.instanceId,
      baseId: inst.baseId,
      name: base.name,
      types: base.types,
      rarity: base.rarity,
      image: base.image,
      isPrismaticSkin: inst.isPrismaticSkin || (base.isPrismaticSkin ?? false),
      genetics: genetics ?? base.genetics,
      nature: inst.natureId != null
          ? NatureCatalog.byId(inst.natureId!)
          : base.nature,
      spriteData: base.spriteData,
      stats: CreatureStats(
        speed: inst.statSpeed,
        intelligence: inst.statIntelligence,
        strength: inst.statStrength,
        beauty: inst.statBeauty,
        beautyPotential: inst.statBeautyPotential,
        intelligencePotential: inst.statIntelligencePotential,
        speedPotential: inst.statSpeedPotential,
        strengthPotential: inst.statStrengthPotential,
      ),

      // NEW pulls from DB (these cols must exist in CreatureInstances table)
      generationDepth: inst.generationDepth ?? 0,
      factionLineage: _decodeLineage(inst.factionLineageJson),
      nativeFaction: nativeFaction,
      variantFaction: inst.variantFaction,
      elementLineage: _decodeLineage(inst.elementLineageJson),
      familyLineage: _decodeLineage(inst.familyLineageJson),
    );
  }

  /// Legacy helper for catalog-only creatures (wild spawn, undomesticated).
  /// These guys are effectively "founders": depth 0, lineage = {their faction:1}.
  factory ParentSnapshot.fromCreature(Creature c) {
    final nf = c.mutationFamily ?? 'Unknown';
    final seedLineage = <String, int>{};
    if (nf != 'Unknown') {
      seedLineage[nf] = 1;
    }
    final seedElem = <String, int>{};
    if (c.types.isNotEmpty) seedElem[c.types.first] = 1;
    final seedFamily = <String, int>{};
    if (nf != 'Unknown')
      seedFamily[nf] = 1; // using mutationFamily as family id

    return ParentSnapshot(
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
      stats: null,

      // NEW defaults for wild/founder
      generationDepth: 0,
      factionLineage: seedLineage,
      nativeFaction: nf,
      variantFaction: null,
      elementLineage: seedElem,
      familyLineage: seedFamily,
    );
  }

  /// Wild creature with explicit stats override.
  /// Same founder assumptions as above.
  factory ParentSnapshot.fromCreatureWithStats(
    Creature c,
    CreatureStats? stats,
  ) {
    final nf = c.mutationFamily ?? 'Unknown';
    final seedLineage = <String, int>{};
    if (nf != 'Unknown') {
      seedLineage[nf] = 1;
    }
    final seedElem = <String, int>{};
    if (c.types.isNotEmpty) seedElem[c.types.first] = 1;
    final seedFamily = <String, int>{};
    if (nf != 'Unknown') seedFamily[nf] = 1;

    return ParentSnapshot(
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
      stats: stats ?? c.stats,

      // NEW
      generationDepth: 0,
      factionLineage: seedLineage,
      nativeFaction: nf,
      variantFaction: null,
      elementLineage: seedElem,
      familyLineage: seedFamily,
    );
  }

  /// Back-compat JSON decode for save data from before lineage existed.
  factory ParentSnapshot.fromJson(Map<String, dynamic> j) {
    final legacyId = j['id'] as String?;
    final baseId = (j['baseId'] ?? legacyId) as String;
    final instanceId = j['instanceId'] as String?;

    // try to read lineage info if it was saved, else fallback to founder defaults
    final decodedLineageRaw = j['factionLineage'];
    Map<String, int> decodedLineage = {};
    if (decodedLineageRaw is Map) {
      decodedLineage = decodedLineageRaw.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
    }

    final nativeFaction = (j['nativeFaction'] as String?) ?? 'Unknown';
    final genDepth = (j['generationDepth'] as num?)?.toInt() ?? 0;
    final variantFaction = j['variantFaction'] as String?;
    Map<String, int> _coerceIntMap(dynamic raw) {
      if (raw is Map) {
        return raw.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
      }
      return {};
    }

    final elemLineage = _coerceIntMap(j['elementLineage']);
    final famLineage = _coerceIntMap(j['familyLineage']);

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
      stats: j['stats'] != null
          ? CreatureStats.fromJson(j['stats'] as Map<String, dynamic>)
          : null,

      // NEW with safe fallback
      generationDepth: genDepth,
      factionLineage: decodedLineage.isNotEmpty
          ? decodedLineage
          : (nativeFaction != 'Unknown' ? {nativeFaction: 1} : {}),
      nativeFaction: nativeFaction,
      variantFaction: variantFaction,
      elementLineage: elemLineage,
      familyLineage: famLineage,
    );
  }

  Map<String, dynamic> toJson() => {
    // Old keys kept for backward compat
    'instanceId': instanceId,
    'baseId': baseId,
    'id': baseId, // legacy
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
    if (stats != null) 'stats': stats!.toJson(),

    // NEW lineage metadata so children can reconstruct odds later
    'generationDepth': generationDepth,
    'factionLineage': factionLineage,
    'nativeFaction': nativeFaction,
    if (variantFaction != null) 'variantFaction': variantFaction,
    'elementLineage': elementLineage,
    'familyLineage': familyLineage,
  };

  /// Rehydrate display fields from repo after app restart.
  /// We KEEP lineage/generation exactly as saved.
  ParentSnapshot rehydrate(CreatureCatalog repo) {
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
      genetics: genetics ?? base.genetics,
      nature: nature ?? base.nature,
      spriteData: spriteData ?? base.spriteData,
      stats: stats,

      generationDepth: generationDepth,
      factionLineage: factionLineage,
      nativeFaction: nativeFaction,
      variantFaction: variantFaction,
      elementLineage: elementLineage,
      familyLineage: familyLineage,
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

  Parentage rehydrate(CreatureCatalog repo) => Parentage(
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
