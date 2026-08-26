// lib/games/planet_dungeon/dungeon_debug_party.dart
//
// Fabricating a descent party for the developer tools.
//
// This used to live as two private methods on the cosmic screen's state, which
// was fine while the only way to test a dungeon was to fly to its planet. The
// dungeon debug menu enters the same seventeen dungeons from the profile
// without a cosmic screen in the tree at all, so the fabrication had to come
// out here — copying it would let the two drift, and the whole point of the
// ideal trio is that it is EXACTLY the team a planet's hard gates want.
//
// Nothing in here writes to the save. A fabricated party is handed to
// PlanetDungeonScreen and forgotten; only what the run itself banks persists.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

/// Stat value given to every fabricated companion, on all four stats.
///
/// Deliberately maxed: stat-scaled tunables (reach, cast rate, the stat gates
/// on §4 interactions) only show their full behaviour at the top of the range,
/// and a debug run exists to see behaviour, not to be balanced.
const int kDebugPartyStatTier = 4;

/// One fabricated companion standing in for a real caught creature.
///
/// [statTier] is a parameter rather than a constant because the cosmic sandbox
/// lets the developer dial it — the dungeon menu always uses the max.
CosmicPartyMember debugMemberFromCreature(
  Creature creature, {
  int statTier = kDebugPartyStatTier,
}) {
  return CosmicPartyMember(
    instanceId:
        'sandbox_${creature.id}_${DateTime.now().microsecondsSinceEpoch}',
    baseId: creature.id,
    displayName: creature.name,
    imagePath: 'assets/images/${creature.image}',
    element: creature.types.firstOrNull ?? 'Fire',
    family: (creature.mutationFamily ?? 'Kin').toLowerCase(),
    level: 10,
    statSpeed: statTier.toDouble(),
    statIntelligence: statTier.toDouble(),
    statStrength: statTier.toDouble(),
    statBeauty: statTier.toDouble(),
    slotIndex: -1,
    staminaBars: 99,
    staminaMax: 99,
    spriteSheet: creature.spriteData != null
        ? sheetFromCreature(creature)
        : null,
  );
}

/// The planet's §6 ideal team, built from real species in the catalog.
///
/// For each entry slot ([kCosmicPlanetEntry]) this takes a real species of that
/// element AND the slot's ideal family ([kDungeonIdealFamilies]), so sprites
/// and abilities are genuine rather than stubbed; where no such species exists
/// it falls back to any creature of the element, which keeps the element gates
/// working even if the family gate then cannot be.
///
/// Animated species only — the dungeon renders sprite sheets — and never a
/// Mystic, which are guardians rather than party tools (§5).
///
/// Returns an empty list if the element has no dungeon or the catalog has
/// nothing that fits; callers must handle that rather than descend with a
/// party that cannot open the front door.
List<CosmicPartyMember> debugIdealTrio(
  CreatureCatalog catalog,
  String element, {
  int statTier = kDebugPartyStatTier,
}) {
  final slots = kCosmicPlanetEntry[element];
  if (slots == null) return const [];
  final families = kDungeonIdealFamilies[element];

  final out = <CosmicPartyMember>[];
  for (var i = 0; i < slots.length; i++) {
    final wantFamily = (families != null && i < families.length)
        ? families[i].toLowerCase()
        : null;
    final ofElement = catalog
        .byType(slots[i])
        .where((c) => c.spriteData != null)
        .where((c) => (c.mutationFamily ?? '').toLowerCase() != 'mystic')
        .toList();
    if (ofElement.isEmpty) continue;
    final match =
        ofElement.firstWhereOrNull(
          (c) => (c.mutationFamily ?? '').toLowerCase() == wantFamily,
        ) ??
        ofElement.first;
    out.add(debugMemberFromCreature(match, statTier: statTier));
  }
  return out;
}

/// Whether [element]'s ideal trio can be fabricated whole — every slot filled
/// by a species of the right element AND family.
///
/// The menu shows this per planet so a run that is about to be missing a hard
/// family gate's key says so BEFORE the descent, rather than after the player
/// has walked to the locked door and found no way through.
bool debugTrioIsExact(CreatureCatalog catalog, String element) {
  final slots = kCosmicPlanetEntry[element];
  final families = kDungeonIdealFamilies[element];
  if (slots == null || families == null) return false;
  if (slots.length != families.length) return false;
  for (var i = 0; i < slots.length; i++) {
    final want = families[i].toLowerCase();
    final has = catalog
        .byType(slots[i])
        .where((c) => c.spriteData != null)
        .any((c) => (c.mutationFamily ?? '').toLowerCase() == want);
    if (!has) return false;
  }
  return true;
}
