// lib/games/planet_dungeon/planet_dungeon_verbs.dart
//
// Dungeon interaction framework: Element = power, Family = method, Stats =
// quality, Recipe = alternate solution. See docs/dungeons.md.
//
//  • DungeonAbility   — the family's interaction METHOD (one per family).
//  • DungeonInteractionRequirement — what a puzzle object wants.
//  • InteractionQuality (Perfect/Valid/Weak/Failed) — how well the active
//    creature satisfies a requirement.
//  • recipe table — element-combo alternate solutions.
//
// All maths are pure (unit-tested without the engine).

import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';

/// The interaction method a creature's FAMILY brings to a dungeon.
enum DungeonAbility {
  smallAccess, // Pip   — pipes, vents, tiny doors, inner mechanisms
  terrainTrail, // Mane — dash paths, element trails, temp bridges, terrain
  heavyForce, // Horn   — heavy gates, blocks, conductors, plates, seals
  insight, // Mask      — runes, truth, hidden things, map pings
  aerialTraversal, // Wing — wind rings, updrafts, islands, aerial switches
  ancientStabilize, // Kin — ancient machines, cores, relic vaults, guardians
  guardianRelic, // Mystic — planet guardian / boss (not a normal tool)
  none,
}

DungeonAbility abilityForFamily(String family) {
  switch (family.toLowerCase()) {
    case 'pip':
      return DungeonAbility.smallAccess;
    case 'mane':
      return DungeonAbility.terrainTrail;
    case 'horn':
      return DungeonAbility.heavyForce;
    case 'mask':
      return DungeonAbility.insight;
    case 'wing':
      return DungeonAbility.aerialTraversal;
    case 'kin':
      return DungeonAbility.ancientStabilize;
    case 'mystic':
      return DungeonAbility.guardianRelic;
    default:
      return DungeonAbility.none;
  }
}

/// Which stat scales an ability's quality/power.
CosmicContestTrait? statForAbility(DungeonAbility a) {
  switch (a) {
    case DungeonAbility.aerialTraversal:
      return CosmicContestTrait.speed;
    case DungeonAbility.insight:
      return CosmicContestTrait.intelligence;
    case DungeonAbility.heavyForce:
      return CosmicContestTrait.strength;
    case DungeonAbility.terrainTrail:
      return CosmicContestTrait.strength;
    case DungeonAbility.smallAccess:
      return CosmicContestTrait.speed;
    case DungeonAbility.ancientStabilize:
      return CosmicContestTrait.beauty;
    case DungeonAbility.guardianRelic:
    case DungeonAbility.none:
      return null;
  }
}

double abilityStatValue(CosmicPartyMember member, DungeonAbility a) {
  switch (statForAbility(a)) {
    case CosmicContestTrait.speed:
      return member.statSpeed;
    case CosmicContestTrait.intelligence:
      return member.statIntelligence;
    case CosmicContestTrait.strength:
      return member.statStrength;
    case CosmicContestTrait.beauty:
      return member.statBeauty;
    case null:
      return 0;
  }
}

String abilityLabel(DungeonAbility a) {
  switch (a) {
    case DungeonAbility.aerialTraversal:
      return 'GLIDE';
    case DungeonAbility.insight:
      return 'REVEAL';
    case DungeonAbility.heavyForce:
      return 'CHANNEL';
    case DungeonAbility.ancientStabilize:
      return 'CALM';
    case DungeonAbility.smallAccess:
      return 'SLIP';
    case DungeonAbility.terrainTrail:
      return 'TRAIL';
    case DungeonAbility.guardianRelic:
    case DungeonAbility.none:
      return '—';
  }
}

// ── Interaction quality ─────────────────────────────────────

enum InteractionQuality { perfect, valid, weak, failed }

/// What a puzzle object requires. [preferred] null = any family of [element]
/// is Perfect. The `min*` stats are soft gates: quality (element/family) and
/// stat-sufficiency ([meetsStats]) are checked separately — a creature can be
/// the right element+family yet still need more of a stat to act at full power
/// (e.g. a strong current needs Speed; a heavy seal needs Strength). Output
/// magnitude (glide length, hint tier, channel hold…) is scaled by the pure
/// tunables below, NOT gated here.
class DungeonInteractionRequirement {
  final String element;
  final DungeonAbility? preferred;
  final bool allowWrongFamily; // element-match but wrong family → Valid
  final bool allowRecipe; // recipe combo → Weak

  // Soft stat gates (1..5). 0 = no requirement.
  final double minSpeed;
  final double minIntelligence;
  final double minStrength;
  final double minBeauty;

  const DungeonInteractionRequirement({
    required this.element,
    this.preferred,
    this.allowWrongFamily = true,
    this.allowRecipe = false,
    this.minSpeed = 0,
    this.minIntelligence = 0,
    this.minStrength = 0,
    this.minBeauty = 0,
  });

  /// Whether [m] clears all of this requirement's stat gates.
  bool meetsStats(CosmicPartyMember m) =>
      m.statSpeed >= minSpeed &&
      m.statIntelligence >= minIntelligence &&
      m.statStrength >= minStrength &&
      m.statBeauty >= minBeauty;
}

/// Mystic guardian encounters are kept OUT of the normal interaction model so a
/// Mystic never becomes "just another key". A guardian declares its element +
/// Mystic species and how it can be resolved (calm via Beauty/Kin, or defeat).
class GuardianEncounterRequirement {
  final String element;
  final String mysticId; // e.g. 'Roc' (Air), 'Simurgh' (Fire)
  final bool canCalm;
  final bool canDefeat;

  const GuardianEncounterRequirement({
    required this.element,
    required this.mysticId,
    this.canCalm = true,
    this.canDefeat = true,
  });
}

/// Grade how well [m] satisfies [req]. [recipeAvailable] = a valid element-combo
/// is set up (puzzle-specific; e.g. fire fired through a wind current).
InteractionQuality evaluateInteraction(
  CosmicPartyMember m,
  DungeonInteractionRequirement req, {
  bool recipeAvailable = false,
}) {
  final sameElement = m.element == req.element;
  final ability = abilityForFamily(m.family);
  if (sameElement && (req.preferred == null || ability == req.preferred)) {
    return InteractionQuality.perfect;
  }
  if (sameElement && req.allowWrongFamily) {
    return InteractionQuality.valid;
  }
  if (req.allowRecipe && recipeAvailable) {
    return InteractionQuality.weak;
  }
  return InteractionQuality.failed;
}

// ── Recipe table (element-combo alternate solutions) ────────

const Map<String, String> _dungeonRecipes = {
  'Air+Fire': 'Lightning',
  'Earth+Fire': 'Lava',
  'Ice+Lava': 'Steam',
  'Fire+Water': 'Steam',
  'Plant+Fire': 'Dust',
  'Air+Earth': 'Dust',
  'Spirit+Water': 'Ice',
  'Plant+Water': 'Mud',
  'Lava+Mud': 'Poison',
  'Plant+Mud': 'Poison',
  'Earth+Lightning': 'Crystal',
  'Lightning+Crystal': 'Spirit',
  'Crystal+Spirit': 'Light',
  'Poison+Spirit': 'Dark',
  'Dark+Light': 'Blood',
  'Mud+Light': 'Plant',
  'Ice+Light': 'Air',
  'Air+Ice': 'Water',
};

/// Element produced by combining [a] and [b] (order-independent), or null.
String? dungeonRecipeResult(String a, String b) =>
    _dungeonRecipes['$a+$b'] ?? _dungeonRecipes['$b+$a'];

// ── Stat-scaled tunables (pure) ─────────────────────────────

double normStat(double stat) => ((stat.clamp(1.0, 5.0)) - 1.0) / 4.0;

double glideSeconds(double speed) => 3.0 + 5.0 * normStat(speed);

double revealRadius(double intelligence) =>
    90.0 + 120.0 * normStat(intelligence);

int revealHintTier(double intelligence) {
  final t = normStat(intelligence);
  if (t >= 0.67) return 2;
  if (t >= 0.34) return 1;
  return 0;
}

double channelHoldSeconds(double strength) => 3.0 + 7.0 * normStat(strength);

bool charmOk(double beauty) => normStat(beauty) >= 0.6; // ≈ Beauty ≥ 3.4
