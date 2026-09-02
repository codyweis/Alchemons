// lib/games/planet_dungeon/planet_dungeon_verbs.dart
//
// Dungeon interaction framework: Element = power, Family = method, Stats =
// magnitude, Recipe = alternate ELEMENT. See docs/dungeons.md.
//
//  • DungeonAbility   — the family's interaction METHOD (one per family).
//  • DungeonInteractionRequirement — what a puzzle object wants.
//  • InteractionResult — pass / pass-via-recipe / a NAMED refusal.
//  • recipe table — element-combo alternate solutions.
//
// THE v2 RULE (no quality ladder): every puzzle object is exactly one of two
// shapes.
//   ELEMENT-ONLY  (`requiredFamily == null`) — any family of the right element
//                 acts at FULL power. No off-family timer, wisp or half-hold.
//   HARD GATE     (`requiredFamily != null`) — right element AND right family,
//                 else a clean refusal. There is no middle tier, and a recipe
//                 never buys past a family gate.
// Recipes substitute a missing ELEMENT only. Stats never gate the ladder (there
// is none) — they scale OUTPUT MAGNITUDE through the pure tunables below.
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

/// Which stat scales an ability's output magnitude.
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

// NO `abilityLabel`. It used to name each family verb for the action pad, and
// the entry it kept for `DungeonAbility.insight` was 'REVEAL' — a button that
// has not existed since the HINT button replaced it. Nothing called this, and
// the dead string was enough on its own to make a reader (me) describe a
// planet's room readings as "gated behind the Mask insight verb", which is
// exactly backwards: any party can press HINT. The per-room `_*Reveal`
// functions are that button's CONTENT, not an ability.

// ── Interaction result ──────────────────────────────────────

/// The outcome of testing a creature against a puzzle object. A refusal always
/// names WHAT is missing — [blockedFamily] in particular is kept distinct so a
/// hard gate can say so in its own words (and stamp its own UI chip).
enum InteractionResult {
  /// Acts at FULL power. There is no lesser success.
  passed,

  /// The element was missing but an element-combo stood in for it. Full power;
  /// a puzzle may still attach its own recipe downside (that is not a penalty
  /// for the family — it is the cost of the braid).
  passedViaRecipe,

  /// Wrong element, and no recipe was available/allowed.
  blockedElement,

  /// Right element, wrong family, at a HARD GATE.
  blockedFamily,

  /// Element and family are right, but a `min*` stat gate is unmet.
  blockedStat,
}

/// What a puzzle object requires.
///
///  • [requiredFamily] `null` → ELEMENT-ONLY: every family of [element] passes
///    at full power.
///  • [requiredFamily] non-null → HARD GATE: only that family passes; everyone
///    else is refused outright ([InteractionResult.blockedFamily]). A recipe
///    does NOT open a family gate.
///  • [allowRecipe] lets an element-combo stand in for the missing ELEMENT.
///
/// The `min*` stats (1..5; 0 = none) are the one remaining hard requirement
/// beyond element/family. Output MAGNITUDE (glide length, hint tier, channel
/// hold…) is scaled by the pure tunables below, never gated here.
/// Sentinel for [DungeonInteractionRequirement.element] meaning "any element".
///
/// Used by gates where the FAMILY VERB does the work and the element is
/// incidental — a wing that is only being asked to fly, a horn that is only
/// being asked to shove. Those should answer to any wing or any horn, because
/// requiring a particular element as well is a second lock the fiction never
/// asked for. Gates where the element is genuinely load-bearing (Ice setting a
/// molten pour, Light striking a lodestone) keep naming it.
const String kAnyElement = '';

class DungeonInteractionRequirement {
  /// The element that must act, or [kAnyElement] when only the family matters.
  final String element;
  final DungeonAbility? requiredFamily;
  final bool allowRecipe;

  // Stat gates (1..5). 0 = no requirement.
  final double minSpeed;
  final double minIntelligence;
  final double minStrength;
  final double minBeauty;

  const DungeonInteractionRequirement({
    required this.element,
    this.requiredFamily,
    this.allowRecipe = false,
    this.minSpeed = 0,
    this.minIntelligence = 0,
    this.minStrength = 0,
    this.minBeauty = 0,
  });

  /// True when this object gates on a family (vs. element-only).
  bool get isHardGate => requiredFamily != null;

  /// True when the element is incidental and only the family verb is required.
  bool get isFamilyOnly => element == kAnyElement && requiredFamily != null;

  /// True when BOTH an element and a family are demanded — the rare marquee
  /// lock, and the only kind that can make a planet unenterable (§4).
  bool get isElementAndFamily =>
      element != kAnyElement && requiredFamily != null;

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

/// Test [m] against [req]. [recipeAvailable] = a valid element-combo is set up
/// (puzzle-specific; e.g. fire fired through a wind current) — it can supply a
/// missing ELEMENT, never a missing family.
InteractionResult evaluateInteraction(
  CosmicPartyMember m,
  DungeonInteractionRequirement req, {
  bool recipeAvailable = false,
}) {
  // kAnyElement: the verb is the whole requirement, so nothing about the
  // creature's element can refuse it — and there is no recipe to consider,
  // because there is no missing element to stand in for.
  final anyElement = req.element == kAnyElement;
  final viaRecipe = !anyElement && m.element != req.element;
  if (viaRecipe && !(req.allowRecipe && recipeAvailable)) {
    return InteractionResult.blockedElement;
  }
  // A family gate stands whether the element came direct or from a braid.
  final family = req.requiredFamily;
  if (family != null && abilityForFamily(m.family) != family) {
    return InteractionResult.blockedFamily;
  }
  if (!req.meetsStats(m)) return InteractionResult.blockedStat;
  return viaRecipe
      ? InteractionResult.passedViaRecipe
      : InteractionResult.passed;
}

/// Convenience: did [r] let the creature act at all (at full power)?
bool interactionSucceeded(InteractionResult r) =>
    r == InteractionResult.passed || r == InteractionResult.passedViaRecipe;

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
