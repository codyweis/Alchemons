enum CreatureDetailsTutorialTarget {
  geneAnalyzer,
  potentialAnalyzer,
  lineageAnalyzer,
}

extension CreatureDetailsTutorialTargetX on CreatureDetailsTutorialTarget {
  String get settingKey => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer =>
      'creature_details_tutorial_gene_analyzer_pending',
    CreatureDetailsTutorialTarget.potentialAnalyzer =>
      'creature_details_tutorial_potential_analyzer_pending',
    CreatureDetailsTutorialTarget.lineageAnalyzer =>
      'creature_details_tutorial_lineage_analyzer_pending',
  };

  String get title => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer => 'Gene Analyzer',
    CreatureDetailsTutorialTarget.potentialAnalyzer => 'Potential Analyzer',
    CreatureDetailsTutorialTarget.lineageAnalyzer => 'Lineage Analyzer',
  };

  String get highlightLabel => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer => 'NEW: NATURE EFFECTS',
    CreatureDetailsTutorialTarget.potentialAnalyzer => 'NEW: POTENTIAL',
    CreatureDetailsTutorialTarget.lineageAnalyzer => 'NEW: PROBABILITY',
  };

  String get tutorialBody => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer =>
      'Traits now show what each nature does, and Lineage shows which stat a pure line raises.',
    CreatureDetailsTutorialTarget.potentialAnalyzer =>
      'Each stat now shows its Potential (P): the inherited 1–100 rating that sets how high it can grow.',
    CreatureDetailsTutorialTarget.lineageAnalyzer =>
      'Lineage now shows the probability each trait of a fusion had.',
  };

  int get sortOrder => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer => 0,
    CreatureDetailsTutorialTarget.potentialAnalyzer => 1,
    CreatureDetailsTutorialTarget.lineageAnalyzer => 2,
  };

  bool get requiresInstance => switch (this) {
    CreatureDetailsTutorialTarget.geneAnalyzer => false,
    CreatureDetailsTutorialTarget.potentialAnalyzer => true,
    CreatureDetailsTutorialTarget.lineageAnalyzer => true,
  };
}

CreatureDetailsTutorialTarget? creatureDetailsTutorialTargetForSkill(
  String skillId,
) {
  switch (skillId) {
    case 'breeder_gene_analyzer':
      return CreatureDetailsTutorialTarget.geneAnalyzer;
    case 'breeder_potential_analyzer':
      return CreatureDetailsTutorialTarget.potentialAnalyzer;
    case 'breeder_lineage_analyzer':
      return CreatureDetailsTutorialTarget.lineageAnalyzer;
    default:
      return null;
  }
}
