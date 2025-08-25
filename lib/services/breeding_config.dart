/// What element results from two parent elements.
class ElementRecipeConfig {
  final Map<String, Map<String, int>> recipes;
  ElementRecipeConfig({required this.recipes});

  static String _norm(String s) => s.trim(); // keep case, just trim

  /// Canonical unordered key: alphabetical + '+'
  static String keyOf(String a, String b) {
    final x = _norm(a), y = _norm(b);
    return (x.compareTo(y) <= 0) ? '$x+$y' : '$y+$x';
  }
}

/// What family results from two parent families (unordered).
// family_recipes.dart
class FamilyRecipeConfig {
  final Map<String, Map<String, int>> recipes; // key: unordered "A+B"
  const FamilyRecipeConfig({required this.recipes});

  static String keyOf(String a, String b) =>
      (a.compareTo(b) <= 0) ? '$a+$b' : '$b+$a';

  Map<String, int>? recipeFor(String a, String b) => recipes[keyOf(a, b)];

  /// Build a config from raw JSON keys (which may be ordered), then:
  ///  • normalize keys to unordered
  ///  • auto-create inverse/backlink rules:
  ///     If A+B → (top=C), then C+A → B and C+B → A (weighted).
  factory FamilyRecipeConfig.fromRaw(
    Map<String, Map<String, int>> raw, {
    // tweak these if you want the inverse to be stronger/weaker
    int inversePrimary = 70, // C+A → B  (main target)
    int keepChild = 15, // C+A → C  (some stickiness)
    int keepParent = 15, // C+A → A  (some regression)
  }) {
    // 1) normalize keys
    final out = <String, Map<String, int>>{};
    raw.forEach((k, v) {
      final parts = k.split('+');
      final a = parts[0].trim();
      final b = parts[1].trim();
      out[FamilyRecipeConfig.keyOf(a, b)] = Map<String, int>.from(v); // copy
    });

    // 2) backlinks for “A+B → top=C”
    final additions = <String, Map<String, int>>{};
    out.forEach((key, dist) {
      final parts = key.split('+');
      final a = parts[0], b = parts[1];

      // find the top “child” that is NOT one of the parents
      String? child;
      int best = -1;
      dist.forEach((k, w) {
        if (k != a && k != b && w > best) {
          child = k;
          best = w;
        }
      });
      if (child == null) return;

      // C+A → B
      final k1 = FamilyRecipeConfig.keyOf(child!, a);
      additions.putIfAbsent(
        k1,
        () => {
          if (!out.containsKey(k1)) b: inversePrimary,
          if (!out.containsKey(k1)) child!: keepChild,
          if (!out.containsKey(k1)) a: keepParent,
        },
      );

      // C+B → A
      final k2 = FamilyRecipeConfig.keyOf(child!, b);
      additions.putIfAbsent(
        k2,
        () => {
          if (!out.containsKey(k2)) a: inversePrimary,
          if (!out.containsKey(k2)) child!: keepChild,
          if (!out.containsKey(k2)) b: keepParent,
        },
      );
    });

    // merge additions only if the key doesn't already exist
    additions.forEach((k, v) {
      if (!out.containsKey(k)) out[k] = v;
    });

    return FamilyRecipeConfig(recipes: out);
  }
}

// breeding_config.dart (add this)
class VariantRulesConfig {
  /// Unordered "A+B" (elements) → chance (%) to produce a dual-type variant
  /// Example: { "Fire+Water": 20, "Crystal+Spirit": 10 }
  final Map<String, int> pairChance;
  const VariantRulesConfig({this.pairChance = const {}});

  static String keyOfTypes(String a, String b) =>
      (a.compareTo(b) <= 0) ? "$a+$b" : "$b+$a";
}

/// Special rules that can short-circuit normal breeding.
class SpecialRulesConfig {
  /// Guaranteed or probabilistic fixed results for ID pairs (unordered).
  /// Example: { "MAN01+WNG09": [{"resultId":"CRE16", "chance":100}] }
  final Map<String, List<GuaranteedOutcome>> guaranteedPairs;

  /// Per-creature required type(s): offspring can only be bred if parents contain at least one of these types.
  /// Example: { "CRE16": ["Light"], "HOR06": ["Lava","Fire"] }
  final Map<String, Set<String>> requiredTypesByCreatureId;

  const SpecialRulesConfig({
    this.guaranteedPairs = const {},
    this.requiredTypesByCreatureId = const {},
  });

  static String idKey(String a, String b) =>
      (a.compareTo(b) <= 0) ? "$a+$b" : "$b+$a";
}

class GuaranteedOutcome {
  final String resultId;
  final int chance; // 1..100
  const GuaranteedOutcome({required this.resultId, this.chance = 100});
}

/// Global knobs (tweak freely)
class BreedingTuning {
  final int parentRepeatChance; // %
  final int variantChanceOnPure; // kept for backward compat (unused here)
  final int variantChanceCross; // % chance to produce a cross-variant
  final int
  sameFamilyMutationChancePct; // % chance to pop to a new family when same-family parents
  final Set<String> variantBlockedTypes; // still honored if you want to block
  final int inheritNatureChance; // % chance to inherit nature from one parent
  final double prismaticSkinChance; // ~0.01% chance to be prismatic
  final int
  sameNatureLockInChance; // % chance to lock in nature if both parents share it

  const BreedingTuning({
    this.inheritNatureChance =
        60, // 90% chance to inherit nature from one parent
    this.parentRepeatChance = 15,
    this.prismaticSkinChance = 0.0001, // ~0.01% chance to be prismatic
    this.variantChanceOnPure = 0, // not used now
    this.variantChanceCross = 20, // tweak
    this.sameFamilyMutationChancePct = 5, // tweak
    this.variantBlockedTypes = const {"Blood"},
    this.sameNatureLockInChance =
        50, // 50% chance to lock in nature if both parents share it
  });
}
