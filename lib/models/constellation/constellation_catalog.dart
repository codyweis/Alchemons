// lib/models/constellation_skill.dart

/// Represents a skill node in the constellation tree
class ConstellationSkill {
  final String id;
  final String name;
  final String description;
  final ConstellationTree tree;
  final int pointsCost;
  final List<String> prerequisites; // IDs of skills that must be unlocked first
  final int tier; // For visual positioning (1 = bottom/start, higher = top)

  const ConstellationSkill({
    required this.id,
    required this.name,
    required this.description,
    required this.tree,
    required this.pointsCost,
    this.prerequisites = const [],
    required this.tier,
  });

  /// Check if all prerequisites are met
  bool canUnlock(Set<String> unlockedSkillIds) {
    return prerequisites.every((prereq) => unlockedSkillIds.contains(prereq));
  }
}

/// The three main constellation trees
enum ConstellationTree {
  breeder, // Breeder & Genetics Tree
  combat, // Boss Hunter & Combat Tree
  extraction, // Extraction & Resource Tree
}

/// Catalog of all constellation skills
class ConstellationCatalog {
  // ==================== BREEDER & GENETICS TREE ====================

  static const lineageAnalyzer = ConstellationSkill(
    id: 'breeder_lineage_analyzer',
    name: 'Lineage Analyzer',
    description:
        'Unlock advanced lineage and outcome statistics during analysis',
    tree: ConstellationTree.breeder,
    pointsCost: 1,
    prerequisites: [],
    tier: 1,
  );

  static const crossSpeciesLineage = ConstellationSkill(
    id: 'breeder_cross_species',
    name: 'Cross-Species Lineage',
    description: 'Unlock the ability to breed two different species',
    tree: ConstellationTree.breeder,
    pointsCost: 1,
    prerequisites: ['breeder_lineage_analyzer'],
    tier: 2,
  );

  static const geneAnalyzer = ConstellationSkill(
    id: 'breeder_gene_analyzer',
    name: 'Gene Analyzer',
    description:
        'Unlock the ability to view what nature effects do to creatures',
    tree: ConstellationTree.breeder,
    pointsCost: 1,
    prerequisites: ['breeder_cross_species'],
    tier: 3,
  );

  static const potentialAnalyzer = ConstellationSkill(
    id: 'breeder_potential_analyzer',
    name: 'Potential Analyzer',
    description: 'Be able to view stat potentials of creature instances',
    tree: ConstellationTree.breeder,
    pointsCost: 4,
    prerequisites: ['breeder_gene_analyzer'],
    tier: 4,
  );

  // path 1 – Accelerated Gestation
  static const acceleratedGestation = ConstellationSkill(
    id: 'breeder_accelerated_gestation',
    name: 'Accelerated Gestation',
    description: 'Reduce faction creature hatching times by 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 6,
    prerequisites: ['breeder_potential_analyzer'],
    tier: 5,
  );

  static const acceleratedGestation2 = ConstellationSkill(
    id: 'breeder_accelerated_gestation2',
    name: 'Accelerated Gestation',
    description: 'Reduce faction creature hatching times by another 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 10,
    prerequisites: ['breeder_accelerated_gestation'],
    tier: 6,
  );

  static const acceleratedGestation3 = ConstellationSkill(
    id: 'breeder_accelerated_gestation3',
    name: 'Accelerated Gestation',
    description: 'Reduce faction creature hatching times by another 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 16,
    prerequisites: ['breeder_accelerated_gestation2'],
    tier: 7,
  );

  // path 2 – Harvesting Wilderness Specimens
  static const harvestingWildernessSpecimens = ConstellationSkill(
    id: 'breeder_harvesting_wilderness_specimens',
    name: 'Harvesting Wilderness Specimens',
    description:
        'Increase probability of harvesting wilderness specimens by 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 6,
    prerequisites: ['breeder_potential_analyzer'],
    tier: 5,
  );

  static const harvestingWildernessSpecimens2 = ConstellationSkill(
    id: 'breeder_harvesting_wilderness_specimens2',
    name: 'Harvesting Wilderness Specimens',
    description:
        'Increase probability of harvesting wilderness specimens by another 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 10,
    prerequisites: ['breeder_harvesting_wilderness_specimens'],
    tier: 6,
  );

  static const harvestingWildernessSpecimens3 = ConstellationSkill(
    id: 'breeder_harvesting_wilderness_specimens3',
    name: 'Harvesting Wilderness Specimens',
    description:
        'Increase probability of harvesting wilderness specimens by another 5%',
    tree: ConstellationTree.breeder,
    pointsCost: 16,
    prerequisites: ['breeder_harvesting_wilderness_specimens2'],
    tier: 7,
  );

  // ==================== COMBAT & ELEMENTAL TREE ====================
  // Battle stats: costs ramp up hard for Boost 4 & 5

  // Strength
  static const atkBoost1 = ConstellationSkill(
    id: 'combat_atk_boost_1',
    name: 'Faction Strength Boost',
    description: 'Increase faction specimens\' strength by .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 2,
    prerequisites: [],
    tier: 1,
  );

  static const atkBoost2 = ConstellationSkill(
    id: 'combat_atk_boost_2',
    name: 'Faction Strength Boost',
    description:
        'Increase faction specimens\' strength by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 4,
    prerequisites: ['combat_atk_boost_1'],
    tier: 2,
  );

  static const atkBoost3 = ConstellationSkill(
    id: 'combat_atk_boost_3',
    name: 'Faction Strength Boost',
    description:
        'Increase faction specimens\' strength by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 8,
    prerequisites: ['combat_atk_boost_2'],
    tier: 3,
  );

  static const atkBoost4 = ConstellationSkill(
    id: 'combat_atk_boost_4',
    name: 'Faction Strength Boost',
    description:
        'Increase faction specimens\' strength by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 16,
    prerequisites: ['combat_atk_boost_3'],
    tier: 4,
  );

  static const atkBoost5 = ConstellationSkill(
    id: 'combat_atk_boost_5',
    name: 'Faction Strength Boost',
    description:
        'Increase faction specimens\' strength by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 32,
    prerequisites: ['combat_atk_boost_4'],
    tier: 5,
  );

  // Intelligence
  static const intBoost1 = ConstellationSkill(
    id: 'combat_int_boost_1',
    name: 'Faction Intelligence Boost',
    description:
        'Increase faction specimens\' intelligence by .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 2,
    prerequisites: [],
    tier: 1,
  );

  static const intBoost2 = ConstellationSkill(
    id: 'combat_int_boost_2',
    name: 'Faction Intelligence Boost',
    description:
        'Increase faction specimens\' intelligence by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 4,
    prerequisites: ['combat_int_boost_1'],
    tier: 2,
  );

  static const intBoost3 = ConstellationSkill(
    id: 'combat_int_boost_3',
    name: 'Faction Intelligence Boost',
    description:
        'Increase faction specimens\' intelligence by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 8,
    prerequisites: ['combat_int_boost_2'],
    tier: 3,
  );

  static const intBoost4 = ConstellationSkill(
    id: 'combat_int_boost_4',
    name: 'Faction Intelligence Boost',
    description:
        'Increase faction specimens\' intelligence by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 16,
    prerequisites: ['combat_int_boost_3'],
    tier: 4,
  );

  static const intBoost5 = ConstellationSkill(
    id: 'combat_int_boost_5',
    name: 'Faction Intelligence Boost',
    description:
        'Increase faction specimens\' intelligence by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 32,
    prerequisites: ['combat_int_boost_4'],
    tier: 5,
  );

  // Beauty
  static const beautyBoost1 = ConstellationSkill(
    id: 'combat_beauty_boost_1',
    name: 'Faction Beauty Boost',
    description: 'Increase faction specimens\' beauty by .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 2,
    prerequisites: [],
    tier: 1,
  );

  static const beautyBoost2 = ConstellationSkill(
    id: 'combat_beauty_boost_2',
    name: 'Faction Beauty Boost',
    description:
        'Increase faction specimens\' beauty by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 4,
    prerequisites: ['combat_beauty_boost_1'],
    tier: 2,
  );

  static const beautyBoost3 = ConstellationSkill(
    id: 'combat_beauty_boost_3',
    name: 'Faction Beauty Boost',
    description:
        'Increase faction specimens\' beauty by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 8,
    prerequisites: ['combat_beauty_boost_2'],
    tier: 3,
  );

  static const beautyBoost4 = ConstellationSkill(
    id: 'combat_beauty_boost_4',
    name: 'Faction Beauty Boost',
    description:
        'Increase faction specimens\' beauty by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 16,
    prerequisites: ['combat_beauty_boost_3'],
    tier: 4,
  );

  static const beautyBoost5 = ConstellationSkill(
    id: 'combat_beauty_boost_5',
    name: 'Faction Beauty Boost',
    description:
        'Increase faction specimens\' beauty by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 32,
    prerequisites: ['combat_beauty_boost_4'],
    tier: 5,
  );

  // Speed
  static const speedBoost1 = ConstellationSkill(
    id: 'combat_speed_boost_1',
    name: 'Faction Speed Boost',
    description: 'Increase faction specimens\' speed by .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 2,
    prerequisites: [],
    tier: 1,
  );

  static const speedBoost2 = ConstellationSkill(
    id: 'combat_speed_boost_2',
    name: 'Faction Speed Boost',
    description:
        'Increase faction specimens\' speed by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 4,
    prerequisites: ['combat_speed_boost_1'],
    tier: 2,
  );

  static const speedBoost3 = ConstellationSkill(
    id: 'combat_speed_boost_3',
    name: 'Faction Speed Boost',
    description:
        'Increase faction specimens\' speed by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 8,
    prerequisites: ['combat_speed_boost_2'],
    tier: 3,
  );

  static const speedBoost4 = ConstellationSkill(
    id: 'combat_speed_boost_4',
    name: 'Faction Speed Boost',
    description:
        'Increase faction specimens\' speed by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 16,
    prerequisites: ['combat_speed_boost_3'],
    tier: 4,
  );

  static const speedBoost5 = ConstellationSkill(
    id: 'combat_speed_boost_5',
    name: 'Faction Speed Boost',
    description:
        'Increase faction specimens\' speed by another .005 when enhancing',
    tree: ConstellationTree.combat,
    pointsCost: 32,
    prerequisites: ['combat_speed_boost_4'],
    tier: 5,
  );

  // ==================== EXTRACTION & RESOURCE TREE ====================

  static const resourceAlchemy = ConstellationSkill(
    id: 'extraction_resource_alchemy',
    name: 'Valuable Resources',
    description: 'Elemental resources can be sold at the Black Market',
    tree: ConstellationTree.extraction,
    pointsCost: 4,
    prerequisites: [],
    tier: 1,
  );

  static const marketplaceInsight = ConstellationSkill(
    id: 'extraction_marketplace_insight',
    name: 'Marketplace Insight',
    description: 'Decrease shop prices by 20%',
    tree: ConstellationTree.extraction,
    pointsCost: 6,
    prerequisites: ['extraction_resource_alchemy'],
    tier: 2,
  );

  static const wildernessPreview = ConstellationSkill(
    id: 'extraction_wilderness_preview',
    name: 'Alchemic Wild Peek',
    description:
        'Peek into the wilderness to see spawned creatures and reset spawns instantly',
    tree: ConstellationTree.extraction,
    pointsCost: 10,
    prerequisites: ['extraction_marketplace_insight'],
    tier: 3,
  );

  static const instantReload = ConstellationSkill(
    id: 'extraction_instant_reload',
    name: 'Instant Chamber Reload',
    description: 'Extraction chambers reload instantly',
    tree: ConstellationTree.extraction,
    pointsCost: 14,
    prerequisites: ['extraction_wilderness_preview'],
    tier: 4,
  );

  static const allDayBlackMarket = ConstellationSkill(
    id: 'extraction_all_day_market',
    name: '24/7 Black Market',
    description: 'Black market is available at all times',
    tree: ConstellationTree.extraction,
    pointsCost: 18,
    prerequisites: ['extraction_instant_reload'],
    tier: 5,
  );

  // more for sales
  static const salePriceBoost1 = ConstellationSkill(
    id: 'extraction_sale_boost_1',
    name: 'Alchemon Sale Boost',
    description: '5% increase to sale prices of alchemons',
    tree: ConstellationTree.extraction,
    pointsCost: 10,
    prerequisites: ['extraction_all_day_market'],
    tier: 6,
  );

  static const salePriceBoost2 = ConstellationSkill(
    id: 'extraction_sale_boost_2',
    name: 'Alchemon Sale Boost',
    description: 'Another 5% increase to sale prices of alchemons',
    tree: ConstellationTree.extraction,
    pointsCost: 14,
    prerequisites: ['extraction_sale_boost_1'],
    tier: 7,
  );

  static const salePriceBoost3 = ConstellationSkill(
    id: 'extraction_sale_boost_3',
    name: 'Alchemon Sale Boost',
    description: 'Another 5% increase to sale prices of alchemons',
    tree: ConstellationTree.extraction,
    pointsCost: 18,
    prerequisites: ['extraction_sale_boost_2'],
    tier: 8,
  );

  // xp boost
  static const xpBoost1 = ConstellationSkill(
    id: 'exraction_xp_boost_1',
    name: 'Enhancement XP Boost',
    description: 'Gain 5% more XP from enhancements',
    tree: ConstellationTree.extraction,
    pointsCost: 8,
    prerequisites: ['extraction_all_day_market'],
    tier: 6,
  );

  static const xpBoost2 = ConstellationSkill(
    id: 'exraction_xp_boost_2',
    name: 'Enhancement XP Boost',
    description: 'Gain 5% more XP from enhancements',
    tree: ConstellationTree.extraction,
    pointsCost: 12,
    prerequisites: ['exraction_xp_boost_1'],
    tier: 7,
  );

  static const xpBoost3 = ConstellationSkill(
    id: 'exraction_xp_boost_3',
    name: 'Enhanecement XP Boost',
    description: 'Gain 5% more XP from enhancements',
    tree: ConstellationTree.extraction,
    pointsCost: 16,
    prerequisites: ['exraction_xp_boost_2'],
    tier: 8,
  );
  // ==================== CATALOG ACCESS ====================

  /// All skills in the constellation system
  static const List<ConstellationSkill> allSkills = [
    // Breeder tree
    lineageAnalyzer,
    geneAnalyzer,
    potentialAnalyzer,
    acceleratedGestation,
    crossSpeciesLineage,
    acceleratedGestation2,
    acceleratedGestation3,
    harvestingWildernessSpecimens,
    harvestingWildernessSpecimens2,
    harvestingWildernessSpecimens3,

    // Combat tree
    atkBoost1,
    atkBoost2,
    atkBoost3,
    atkBoost4,
    atkBoost5,
    intBoost1,
    intBoost2,
    intBoost3,
    intBoost4,
    intBoost5,
    beautyBoost1,
    beautyBoost2,
    beautyBoost3,
    beautyBoost4,
    beautyBoost5,
    speedBoost1,
    speedBoost2,
    speedBoost3,
    speedBoost4,
    speedBoost5,

    // Extraction tree
    resourceAlchemy,
    marketplaceInsight,
    wildernessPreview,
    instantReload,
    allDayBlackMarket,
    salePriceBoost1,
    salePriceBoost2,
    salePriceBoost3,
    xpBoost1,
    xpBoost2,
    xpBoost3,
  ];

  /// Get all skills for a specific tree
  static List<ConstellationSkill> forTree(ConstellationTree tree) {
    return allSkills.where((skill) => skill.tree == tree).toList();
  }

  /// Get a skill by ID
  static ConstellationSkill? byId(String id) {
    try {
      return allSkills.firstWhere((skill) => skill.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get skills by tier for a tree (for rendering vertical layers)
  static Map<int, List<ConstellationSkill>> byTierForTree(
    ConstellationTree tree,
  ) {
    final skills = forTree(tree);
    final Map<int, List<ConstellationSkill>> tierMap = {};

    for (final skill in skills) {
      tierMap.putIfAbsent(skill.tier, () => []).add(skill);
    }

    return tierMap;
  }
}

/// Breeding milestones that award constellation points
class BreedingMilestone {
  final int count; // Number of creatures bred
  final int pointsAwarded;
  final String displayName;

  const BreedingMilestone({
    required this.count,
    required this.pointsAwarded,
    required this.displayName,
  });

  static const List<BreedingMilestone> milestones = [
    BreedingMilestone(
      count: 10,
      pointsAwarded: 1,
      displayName: 'Novice Alchemist',
    ),
    BreedingMilestone(
      count: 25,
      pointsAwarded: 2,
      displayName: 'Skilled Alchemist',
    ),
    BreedingMilestone(
      count: 50,
      pointsAwarded: 3,
      displayName: 'Expert Alchemist',
    ),
    BreedingMilestone(
      count: 100,
      pointsAwarded: 5,
      displayName: 'Master Alchemist',
    ),
    BreedingMilestone(
      count: 250,
      pointsAwarded: 10,
      displayName: 'Grandmaster Alchemist',
    ),
    BreedingMilestone(
      count: 500,
      pointsAwarded: 20,
      displayName: 'Legendary Alchemist',
    ),
  ];

  /// Get the next milestone after a given count
  static BreedingMilestone? nextMilestone(int currentCount) {
    try {
      return milestones.firstWhere((m) => m.count > currentCount);
    } catch (_) {
      return null;
    }
  }

  /// Get the milestone number (index + 1) for a given count
  static int milestoneNumber(int count) {
    for (int i = 0; i < milestones.length; i++) {
      if (milestones[i].count == count) return i + 1;
    }
    return 0;
  }
}
