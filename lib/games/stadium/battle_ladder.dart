import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';

// The Emerald Cup's battle ladder: each round's set team (GemBout.team) as
// the four it brings to the battle (cosmic_game_battle.dart).

/// The catalog species of [family] whose first element is [element].
Creature? ladderSpecies(
  CreatureCatalog catalog,
  String family,
  String element,
) {
  for (final c in catalog.creatures) {
    if ((c.mutationFamily ?? '').toLowerCase() == family.toLowerCase() &&
        c.types.isNotEmpty &&
        c.types.first == element &&
        c.baseStats != null) {
      return c;
    }
  }
  return null;
}

/// [species] at level 10, bred to [potential] in every stat and enhanced
/// [enhancement] ranks, as one of a battle's four ([sprites] false for a
/// fight with no screen: a test's).
CosmicPartyMember ladderMember(
  Creature species, {
  required int potential,
  int enhancement = 0,
  required String id,
  int slot = 0,
  bool sprites = true,
}) {
  final base = species.baseStats!;
  double stat(int b) => AlchemonStatSystem.effectiveInternal(
    speciesBase: b,
    level: AlchemonStatSystem.maxLevel,
    potential: potential,
    enhancementRank: enhancement,
  );
  return CosmicPartyMember(
    instanceId: id,
    baseId: species.id,
    displayName: species.name,
    element: species.types.first,
    family: species.mutationFamily!,
    level: AlchemonStatSystem.maxLevel,
    statSpeed: stat(base.speed),
    statIntelligence: stat(base.intelligence),
    statStrength: stat(base.strength),
    statBeauty: stat(base.beauty),
    slotIndex: slot,
    staminaBars: 3,
    staminaMax: 3,
    spriteSheet: sprites && species.spriteData != null
        ? sheetFromCreature(species)
        : null,
    spriteVisuals: sprites ? visualsFromInstance(species, null) : null,
  );
}

/// [bout]'s set team, as it fights.
List<CosmicPartyMember> ladderTeamFor(
  CreatureCatalog catalog,
  GemBout bout, {
  bool sprites = true,
}) {
  final out = <CosmicPartyMember>[];
  for (final (family, element) in bout.team) {
    final species = ladderSpecies(catalog, family, element);
    if (species == null) continue;
    out.add(
      ladderMember(
        species,
        potential: bout.potential,
        enhancement: bout.enhancement,
        id: 'ladder:${bout.id}:${out.length}',
        slot: out.length,
        sprites: sprites,
      ),
    );
  }
  return out;
}
