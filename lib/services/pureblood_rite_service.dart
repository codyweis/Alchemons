import 'dart:convert';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/genetics_loader.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';

class PurebloodChallenge {
  final Creature previewSpecies;
  final String displayTitle;
  final String requiredFamily;
  final String? requiredElement;
  final bool requireElementalPurity;
  final bool requireSpeciesPurity;
  final String? requiredSize;
  final String? requiredTint;
  final String? requiredTintLabel;
  final String? requiredNature;
  final String? requiredVariantFaction;
  final int goldReward;
  final int stageIndex;

  const PurebloodChallenge({
    required this.previewSpecies,
    required this.displayTitle,
    required this.requiredFamily,
    required this.requiredElement,
    required this.requireElementalPurity,
    required this.requireSpeciesPurity,
    required this.requiredSize,
    required this.requiredTint,
    required this.requiredTintLabel,
    required this.requiredNature,
    this.requiredVariantFaction,
    required this.goldReward,
    required this.stageIndex,
  });

  String get title => '$shortTitle Rite';

  String get shortTitle => displayTitle;

  String get accentElement =>
      requiredElement ??
      (previewSpecies.types.isNotEmpty ? previewSpecies.types.first : 'Fire');

  String get vesselDescription {
    final requirements = <String>[];
    if (requireElementalPurity) {
      requirements.add(
        requiredElement == null
            ? 'a pure elemental line'
            : 'a pure ${_labelize(requiredElement!)} element line',
      );
    }
    if (requireSpeciesPurity) {
      requirements.add('a pure $requiredFamily species line');
    }
    if (requiredTint != null) {
      requirements.add('${_traitLabel(requiredTint!, requiredTintLabel)} tint');
    }
    if (requiredSize != null) {
      requirements.add('${_labelize(requiredSize!)} size');
    }
    if (requiredNature != null) {
      requirements.add('${_labelize(requiredNature!)} nature');
    }
    if (requiredVariantFaction != null) {
      requirements.add('${_labelize(requiredVariantFaction!)} variant');
    }

    if (requirements.isEmpty) {
      return 'Any $requiredFamily specimen may answer this rite.';
    }

    return 'Any $requiredFamily specimen with ${_joinWithAnd(requirements)}.';
  }

  List<String> get requirementLines {
    final lines = <String>[];
    if (requireElementalPurity) {
      lines.add(
        requiredElement == null
            ? 'Elemental Lineage — Pure'
            : '${_labelize(requiredElement!)} Element Line — Pure',
      );
    }
    if (requireSpeciesPurity) {
      lines.add('$requiredFamily Species Line — Pure');
    }
    if (requiredTint != null) {
      lines.add('Tinting — ${_traitLabel(requiredTint!, requiredTintLabel)}');
    }
    if (requiredSize != null) {
      lines.add('Size — ${_labelize(requiredSize!)}');
    }
    if (requiredNature != null) {
      lines.add('Nature — ${_labelize(requiredNature!)}');
    }
    if (requiredVariantFaction != null) {
      lines.add('Variant — ${_labelize(requiredVariantFaction!)}');
    }
    lines.add('+$goldReward Gold Awarded');
    return lines;
  }
}

class PurebloodSacrificeCheck {
  final bool isEligible;
  final bool matchesFamily;
  final bool pureElement;
  final bool pureFamily;
  final bool matchesTint;
  final bool matchesSize;
  final bool matchesNature;
  final bool matchesVariant;
  final bool isProtected;
  final String message;

  const PurebloodSacrificeCheck({
    required this.isEligible,
    required this.matchesFamily,
    required this.pureElement,
    required this.pureFamily,
    required this.matchesTint,
    required this.matchesSize,
    required this.matchesNature,
    required this.matchesVariant,
    required this.isProtected,
    required this.message,
  });

  bool get matchesTrait =>
      matchesTint && matchesSize && matchesNature && matchesVariant;
}

class PurebloodSacrificeResult {
  final PurebloodChallenge challenge;
  final CreatureInstance instance;
  final int goldEarned;
  final int completionBonusGold;
  final int newStageIndex;
  final PurebloodChallenge? nextChallenge;
  final bool completedRite;

  const PurebloodSacrificeResult({
    required this.challenge,
    required this.instance,
    required this.goldEarned,
    required this.completionBonusGold,
    required this.newStageIndex,
    required this.nextChallenge,
    required this.completedRite,
  });
}

class PurebloodRiteException implements Exception {
  final String message;

  const PurebloodRiteException(this.message);

  @override
  String toString() => message;
}

class PurebloodRiteService {
  PurebloodRiteService(this._db, this._catalog);

  final AlchemonsDatabase _db;
  final CreatureCatalog _catalog;

  static const String _stageIndexKey = 'pureblood_rite_stage_index_v2';
  static const int completionBonusGold = 50;

  static const List<_ChallengeBlueprint> _blueprints = [
    _ChallengeBlueprint(
      title: 'Species Pure Let',
      family: 'Let',
      previewSpeciesName: 'Firelet',
      requireSpeciesPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Elementally Pure Airlet',
      family: 'Let',
      previewSpeciesName: 'Airlet',
      requiredElement: 'Air',
      requireElementalPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Pure Lightninglet',
      family: 'Let',
      previewSpeciesName: 'Lightninglet',
      requiredElement: 'Lightning',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Elementally Pure Lavapip',
      family: 'Pip',
      previewSpeciesName: 'Lavapip',
      requiredElement: 'Lava',
      requireElementalPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Pure Firepip',
      family: 'Pip',
      previewSpeciesName: 'Firepip',
      requiredElement: 'Fire',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Elementally Pure Steammane',
      family: 'Mane',
      previewSpeciesName: 'Steammane',
      requiredElement: 'Steam',
      requireElementalPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Large Waterlet',
      family: 'Let',
      previewSpeciesName: 'Waterlet',
      requiredElement: 'Water',
      requireElementalPurity: true,
      requiredSize: 'large',
    ),
    _ChallengeBlueprint(
      title: 'Cryogenic Icemane',
      family: 'Mane',
      previewSpeciesName: 'Icemane',
      requiredElement: 'Ice',
      requireElementalPurity: true,
      requiredTint: 'cool',
    ),
    _ChallengeBlueprint(
      title: 'Thermal Lightninghorn',
      family: 'Horn',
      previewSpeciesName: 'Lightninghorn',
      requiredElement: 'Lightning',
      requireElementalPurity: true,
      requiredTint: 'warm',
    ),
    _ChallengeBlueprint(
      title: 'Small Nullic Mudlet',
      family: 'Let',
      previewSpeciesName: 'Mudlet',
      requiredElement: 'Mud',
      requireElementalPurity: true,
      requiredSize: 'small',
      requiredNature: 'Nullic',
    ),
    _ChallengeBlueprint(
      title: 'Pure Icemask',
      family: 'Mask',
      previewSpeciesName: 'Icemask',
      requiredElement: 'Ice',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Giant Airhorn',
      family: 'Horn',
      previewSpeciesName: 'Airhorn',
      requiredElement: 'Air',
      requireElementalPurity: true,
      requiredSize: 'giant',
    ),
    _ChallengeBlueprint(
      title: 'Pure Radiant Large Firemane',
      family: 'Mane',
      previewSpeciesName: 'Firemane',
      requiredElement: 'Fire',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
      requiredSize: 'large',
      requiredTint: 'vibrant',
      requiredTintLabel: 'Radiant',
    ),
    _ChallengeBlueprint(
      title: 'Tiny Wing',
      family: 'Wing',
      requiredSize: 'tiny',
    ),
    _ChallengeBlueprint(
      title: 'Albino Darklet',
      family: 'Let',
      previewSpeciesName: 'Darklet',
      requiredElement: 'Dark',
      requireElementalPurity: true,
      requiredTint: 'albino',
    ),
    _ChallengeBlueprint(
      title: 'Giant Pure Bloodpip',
      family: 'Pip',
      previewSpeciesName: 'Bloodpip',
      requiredElement: 'Blood',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
      requiredSize: 'giant',
    ),
    _ChallengeBlueprint(
      title: 'Pure Poisonhorn',
      family: 'Horn',
      previewSpeciesName: 'Poisonhorn',
      requiredElement: 'Poison',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
    ),
    _ChallengeBlueprint(
      title: 'Mighty Species Pure Plantwing',
      family: 'Wing',
      previewSpeciesName: 'Plantwing',
      requiredElement: 'Plant',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
      requiredNature: 'Mighty',
    ),
    _ChallengeBlueprint(
      title: 'Giant Species Pure Kin',
      family: 'Kin',
      requireSpeciesPurity: true,
      requiredSize: 'giant',
    ),
    _ChallengeBlueprint(
      title: 'Pure Lighthorn Tiny Metabolic Albino',
      family: 'Horn',
      previewSpeciesName: 'Lighthorn',
      requiredElement: 'Light',
      requireElementalPurity: true,
      requireSpeciesPurity: true,
      requiredSize: 'tiny',
      requiredTint: 'albino',
      requiredNature: 'Metabolic',
    ),
  ];

  static int get totalChallenges => _blueprints.length;

  Future<int> getStageIndex() async {
    final raw = await _db.settingsDao.getSetting(_stageIndexKey);
    final parsed = int.tryParse(raw ?? '0') ?? 0;
    return parsed.clamp(0, totalChallenges);
  }

  Future<void> setStageIndex(int index) async {
    final clamped = index.clamp(0, totalChallenges);
    await _db.settingsDao.setSetting(_stageIndexKey, clamped.toString());
  }

  List<PurebloodChallenge> get challengeLadder =>
      List<PurebloodChallenge>.generate(
        totalChallenges,
        challengeForStageIndex,
        growable: false,
      );

  PurebloodChallenge? currentChallenge({required int stageIndex}) {
    if (stageIndex >= totalChallenges) return null;
    return challengeForStageIndex(stageIndex);
  }

  PurebloodChallenge? nextChallengeAfter(int stageIndex) {
    final nextIndex = stageIndex + 1;
    if (nextIndex >= totalChallenges) return null;
    return challengeForStageIndex(nextIndex);
  }

  PurebloodChallenge challengeForStageIndex(int stageIndex) {
    final clamped = stageIndex.clamp(0, totalChallenges - 1);
    final blueprint = _blueprints[clamped];
    return PurebloodChallenge(
      previewSpecies: _representativeSpeciesForBlueprint(blueprint),
      displayTitle: blueprint.title,
      requiredFamily: blueprint.family,
      requiredElement: blueprint.requiredElement,
      requireElementalPurity: blueprint.requireElementalPurity,
      requireSpeciesPurity: blueprint.requireSpeciesPurity,
      requiredSize: blueprint.requiredSize,
      requiredTint: blueprint.requiredTint,
      requiredTintLabel: blueprint.requiredTintLabel,
      requiredNature: blueprint.requiredNature,
      goldReward: _goldRewardForStage(clamped),
      stageIndex: clamped,
    );
  }

  List<Creature> challengePoolForFamily(String family) {
    final pool =
        _catalog.creatures
            .where(
              (creature) =>
                  _normalizedFamily(creature.mutationFamily) == family,
            )
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));

    if (pool.isEmpty) {
      throw StateError('No rite challenge species are available for $family.');
    }

    return pool;
  }

  Creature representativeSpeciesForFamily(String family) =>
      challengePoolForFamily(family).first;

  Creature _representativeSpeciesForBlueprint(_ChallengeBlueprint blueprint) {
    final requestedName = blueprint.previewSpeciesName;
    if (requestedName != null) {
      for (final creature in _catalog.creatures) {
        if (creature.name.trim().toLowerCase() ==
            requestedName.trim().toLowerCase()) {
          return creature;
        }
      }
    }
    return representativeSpeciesForFamily(blueprint.family);
  }

  bool isFinalChallenge(PurebloodChallenge challenge) =>
      challenge.stageIndex == totalChallenges - 1;

  int rewardForChallenge(PurebloodChallenge challenge) =>
      challenge.goldReward +
      (isFinalChallenge(challenge) ? completionBonusGold : 0);

  bool speciesMatchesChallenge(
    Creature? species, {
    required PurebloodChallenge challenge,
  }) => _normalizedFamily(species?.mutationFamily) == challenge.requiredFamily;

  PurebloodSacrificeCheck evaluate(
    CreatureInstance instance, {
    required PurebloodChallenge challenge,
  }) {
    final species = _catalog.getCreatureById(instance.baseId);
    final speciesFamily = _normalizedFamily(species?.mutationFamily);
    final matchesFamily = speciesFamily == challenge.requiredFamily;
    final elementLineage = _decodeLineage(
      instance.elementLineageJson,
      fallback: instance.generationDepth == 0 && species != null
          ? species.types.firstOrNull
          : null,
    );
    final satisfiesElementPurity = !challenge.requireElementalPurity
        ? true
        : challenge.requiredElement == null
        ? _isSingleLineage(elementLineage)
        : _matchesSingleLineage(elementLineage, challenge.requiredElement!);
    final pureFamily = _matchesSingleLineage(
      _decodeLineage(
        instance.familyLineageJson,
        fallback: instance.generationDepth == 0 ? speciesFamily : null,
      ),
      challenge.requiredFamily,
    );
    final genetics = decodeGenetics(instance.geneticsJson);
    final matchesTint =
        challenge.requiredTint == null ||
        genetics?.tinting?.trim().toLowerCase() ==
            challenge.requiredTint!.trim().toLowerCase();
    final matchesSize =
        challenge.requiredSize == null ||
        genetics?.size?.trim().toLowerCase() ==
            challenge.requiredSize!.trim().toLowerCase();
    final matchesNature =
        challenge.requiredNature == null ||
        instance.natureId?.trim().toLowerCase() ==
            challenge.requiredNature!.trim().toLowerCase();
    final matchesVariant =
        challenge.requiredVariantFaction == null ||
        instance.variantFaction?.trim().toLowerCase() ==
            challenge.requiredVariantFaction!.trim().toLowerCase();
    final isProtected = instance.locked || instance.isFavorite == true;

    if (!matchesFamily) {
      return PurebloodSacrificeCheck(
        isEligible: false,
        matchesFamily: false,
        pureElement: satisfiesElementPurity,
        pureFamily: pureFamily,
        matchesTint: matchesTint,
        matchesSize: matchesSize,
        matchesNature: matchesNature,
        matchesVariant: matchesVariant,
        isProtected: false,
        message:
            'Only ${challenge.requiredFamily} specimens may answer this rite.',
      );
    }

    if (isProtected) {
      return PurebloodSacrificeCheck(
        isEligible: false,
        matchesFamily: true,
        pureElement: satisfiesElementPurity,
        pureFamily: pureFamily,
        matchesTint: matchesTint,
        matchesSize: matchesSize,
        matchesNature: matchesNature,
        matchesVariant: matchesVariant,
        isProtected: true,
        message: 'Favorited or locked specimens cannot be sacrificed.',
      );
    }

    final missing = <String>[];
    if (!satisfiesElementPurity) {
      missing.add(
        challenge.requiredElement == null
            ? 'a pure elemental line'
            : 'a pure ${_labelize(challenge.requiredElement!)} element line',
      );
    }
    if (challenge.requireSpeciesPurity && !pureFamily) {
      missing.add('a pure ${challenge.requiredFamily} species line');
    }
    if (!matchesTint && challenge.requiredTint != null) {
      missing.add(
        '${_traitLabel(challenge.requiredTint!, challenge.requiredTintLabel)} tinting',
      );
    }
    if (!matchesSize && challenge.requiredSize != null) {
      missing.add('${_labelize(challenge.requiredSize!)} size');
    }
    if (!matchesNature && challenge.requiredNature != null) {
      missing.add('${_labelize(challenge.requiredNature!)} nature');
    }
    if (!matchesVariant && challenge.requiredVariantFaction != null) {
      missing.add('${_labelize(challenge.requiredVariantFaction!)} variant');
    }

    if (missing.isNotEmpty) {
      return PurebloodSacrificeCheck(
        isEligible: false,
        matchesFamily: true,
        pureElement: satisfiesElementPurity,
        pureFamily: pureFamily,
        matchesTint: matchesTint,
        matchesSize: matchesSize,
        matchesNature: matchesNature,
        matchesVariant: matchesVariant,
        isProtected: false,
        message: 'Requires ${_joinWithAnd(missing)}.',
      );
    }

    return PurebloodSacrificeCheck(
      isEligible: true,
      matchesFamily: true,
      pureElement: satisfiesElementPurity,
      pureFamily: !challenge.requireSpeciesPurity || pureFamily,
      matchesTint: true,
      matchesSize: true,
      matchesNature: true,
      matchesVariant: true,
      isProtected: false,
      message: 'All rite conditions satisfied.',
    );
  }

  Future<PurebloodSacrificeResult> sacrifice({
    required String instanceId,
    required PurebloodChallenge challenge,
    required int currentStageIndex,
  }) async {
    final active = currentChallenge(stageIndex: currentStageIndex);
    if (active == null) {
      throw const PurebloodRiteException('The rite is already complete.');
    }
    if (active.stageIndex != challenge.stageIndex ||
        active.requiredFamily != challenge.requiredFamily ||
        active.requiredElement != challenge.requiredElement ||
        active.requireElementalPurity != challenge.requireElementalPurity ||
        active.requireSpeciesPurity != challenge.requireSpeciesPurity ||
        active.requiredSize != challenge.requiredSize ||
        active.requiredTint != challenge.requiredTint ||
        active.requiredNature != challenge.requiredNature) {
      throw const PurebloodRiteException(
        'The rite has shifted. Reopen the altar and try again.',
      );
    }

    final instance = await _db.creatureDao.getInstance(instanceId);
    if (instance == null) {
      throw const PurebloodRiteException(
        'That specimen is no longer available.',
      );
    }

    final check = evaluate(instance, challenge: active);
    if (!check.isEligible) {
      throw PurebloodRiteException(check.message);
    }

    var newStageIndex = currentStageIndex;
    final completionBonus = isFinalChallenge(active) ? completionBonusGold : 0;
    final totalGoldEarned = active.goldReward + completionBonus;

    await _db.transaction(() async {
      await _db.creatureDao.deleteInstances([instance.instanceId]);
      await _db.currencyDao.addGold(totalGoldEarned);
      newStageIndex = (currentStageIndex + 1).clamp(0, totalChallenges);
      await _db.settingsDao.setSetting(
        _stageIndexKey,
        newStageIndex.toString(),
      );
    });

    return PurebloodSacrificeResult(
      challenge: active,
      instance: instance,
      goldEarned: totalGoldEarned,
      completionBonusGold: completionBonus,
      newStageIndex: newStageIndex,
      nextChallenge: currentChallenge(stageIndex: newStageIndex),
      completedRite: newStageIndex >= totalChallenges,
    );
  }

  int _goldRewardForStage(int stageIndex) {
    if (stageIndex < 5) return stageIndex + 1;
    if (stageIndex < 10) return 5;
    if (stageIndex < 15) return 10;
    return 15;
  }

  // ─── Weekly Challenge ────────────────────────────────────────────────────────

  static const String _weeklyCompletedWeekKey =
      'pureblood_weekly_rite_completed_week_v1';

  static String currentWeekKey() {
    final now = DateTime.now().toUtc();
    final daysFromMonday = (now.weekday - DateTime.monday) % 7;
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysFromMonday));
    return '${monday.year}-'
        '${monday.month.toString().padLeft(2, '0')}-'
        '${monday.day.toString().padLeft(2, '0')}';
  }

  static int _seedFromWeekKey(String weekKey) =>
      int.parse(weekKey.replaceAll('-', ''));

  static Duration timeUntilWeeklyReset() {
    final now = DateTime.now().toUtc();
    final daysFromMonday = (now.weekday - DateTime.monday) % 7;
    final monday = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: daysFromMonday));
    final nextMonday = monday.add(const Duration(days: 7));
    return nextMonday.difference(now);
  }

  PurebloodChallenge weeklyChallenge() {
    final seed = _seedFromWeekKey(currentWeekKey());
    return _generateWeeklyChallenge(seed);
  }

  Future<bool> isWeeklyComplete() async {
    final stored = await _db.settingsDao.getSetting(_weeklyCompletedWeekKey);
    return stored == currentWeekKey();
  }

  Future<PurebloodSacrificeResult> sacrificeWeekly({
    required String instanceId,
    required PurebloodChallenge challenge,
  }) async {
    if (challenge.stageIndex != -1) {
      throw const PurebloodRiteException('Not a weekly challenge.');
    }
    if (await isWeeklyComplete()) {
      throw const PurebloodRiteException(
        'Weekly challenge already completed this week.',
      );
    }

    final instance = await _db.creatureDao.getInstance(instanceId);
    if (instance == null) {
      throw const PurebloodRiteException(
        'That specimen is no longer available.',
      );
    }

    final check = evaluate(instance, challenge: challenge);
    if (!check.isEligible) {
      throw PurebloodRiteException(check.message);
    }

    await _db.transaction(() async {
      await _db.creatureDao.deleteInstances([instance.instanceId]);
      await _db.currencyDao.addGold(challenge.goldReward);
      await _db.settingsDao.setSetting(
        _weeklyCompletedWeekKey,
        currentWeekKey(),
      );
    });

    return PurebloodSacrificeResult(
      challenge: challenge,
      instance: instance,
      goldEarned: challenge.goldReward,
      completionBonusGold: 0,
      newStageIndex: totalChallenges,
      nextChallenge: null,
      completedRite: false,
    );
  }

  PurebloodChallenge _generateWeeklyChallenge(int seed) {
    final rng = math.Random(seed);

    final families = _catalog.allFamilies();
    final family = families[rng.nextInt(families.length)];

    final familyCreatures = _catalog.creatures
        .where((c) => _normalizedFamily(c.mutationFamily) == family)
        .toList();

    final availableElements = <String>{};
    for (final c in familyCreatures) {
      availableElements.addAll(c.types);
    }
    final elementsList = availableElements.toList()..sort();

    final requiredElement = elementsList.isEmpty
        ? null
        : elementsList[rng.nextInt(elementsList.length)];

    // Pick preview species deterministically (sorted by id then first match)
    final previewCandidates =
        (requiredElement == null
                ? familyCreatures
                : familyCreatures
                      .where((c) => c.types.contains(requiredElement))
                      .toList())
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    final previewSpecies =
        (previewCandidates.isEmpty
                ? (familyCreatures..sort((a, b) => a.id.compareTo(b.id)))
                : previewCandidates)
            .first;

    // Shuffle the extras pool with our seeded rng
    final pool = ['speciesPurity', 'size', 'tint', 'nature', 'variant'];
    for (var i = pool.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final tmp = pool[i];
      pool[i] = pool[j];
      pool[j] = tmp;
    }

    bool requireSpeciesPurity = false;
    String? requiredSize;
    String? requiredTint;
    String? requiredNature;
    String? requiredVariantFaction;

    final sizes = GeneticsCatalog.track(
      'size',
    ).variants.map((v) => v.id).where((id) => id != 'normal').toList();
    final tints = GeneticsCatalog.track(
      'tinting',
    ).variants.map((v) => v.id).where((id) => id != 'normal').toList();
    final natures = NatureCatalog.all.map((n) => n.id).toList();
    final variantFactions = FactionId.values.map((f) => f.name).toList();

    // Always pick at least 1 extra (to guarantee 4 total things: family +
    // element + elementalPurity + extra). Additional picks use decreasing odds.
    const extraPickOdds = [1.0, 0.65, 0.40, 0.20, 0.0];
    int picked = 0;
    for (final option in pool) {
      if (picked >= extraPickOdds.length) break;
      final odds = extraPickOdds[picked];
      if (odds <= 0.0 || (picked > 0 && rng.nextDouble() >= odds)) continue;
      switch (option) {
        case 'speciesPurity':
          requireSpeciesPurity = true;
        case 'size':
          requiredSize = sizes[rng.nextInt(sizes.length)];
        case 'tint':
          requiredTint = tints[rng.nextInt(tints.length)];
        case 'nature':
          requiredNature = natures[rng.nextInt(natures.length)];
        case 'variant':
          requiredVariantFaction =
              variantFactions[rng.nextInt(variantFactions.length)];
      }
      picked++;
    }

    final goldReward = _weeklyGoldReward(
      element: requiredElement,
      speciesPurity: requireSpeciesPurity,
      size: requiredSize,
      tint: requiredTint,
      nature: requiredNature,
      variantFaction: requiredVariantFaction,
    );

    final title = _buildWeeklyTitle(
      family: family,
      element: requiredElement,
      speciesPurity: requireSpeciesPurity,
      size: requiredSize,
      tint: requiredTint,
      nature: requiredNature,
      variantFaction: requiredVariantFaction,
    );

    return PurebloodChallenge(
      previewSpecies: previewSpecies,
      displayTitle: title,
      requiredFamily: family,
      requiredElement: requiredElement,
      requireElementalPurity: true,
      requireSpeciesPurity: requireSpeciesPurity,
      requiredSize: requiredSize,
      requiredTint: requiredTint,
      requiredTintLabel: null,
      requiredNature: requiredNature,
      requiredVariantFaction: requiredVariantFaction,
      goldReward: goldReward,
      stageIndex: -1,
    );
  }

  static int _weeklyGoldReward({
    required String? element,
    required bool speciesPurity,
    required String? size,
    required String? tint,
    required String? nature,
    required String? variantFaction,
  }) {
    int difficulty = 0;
    if (element != null) {
      difficulty += 1;
    }
    difficulty += 1; // elementalPurity is always required
    if (speciesPurity) {
      difficulty += 1;
    }
    if (size == 'tiny' || size == 'giant') {
      difficulty += 2;
    } else if (size != null) {
      difficulty += 1;
    }
    if (tint == 'albino') {
      difficulty += 2;
    } else if (tint != null) {
      difficulty += 1;
    }
    if (nature != null) {
      difficulty += 1;
    }
    final hasVariant =
        variantFaction != null &&
        variantFaction.trim().isNotEmpty &&
        variantFaction.trim().toLowerCase() != 'bloodborn';
    if (hasVariant) {
      difficulty += 2;
    }
    // Minimum difficulty 3 (element + purity + 1 extra) maps to 5 gold.
    // Any variant challenge is always maximum reward.
    if (hasVariant) return 10;
    return (difficulty + 2).clamp(5, 9);
  }

  static String _buildWeeklyTitle({
    required String family,
    required String? element,
    required bool speciesPurity,
    required String? size,
    required String? tint,
    required String? nature,
    required String? variantFaction,
  }) {
    final parts = <String>[];
    if (speciesPurity) {
      parts.add('Pure');
    }
    if (size != null) {
      parts.add(_labelize(size));
    }
    if (tint != null) {
      parts.add(_traitLabel(tint, null));
    }
    if (nature != null) {
      parts.add(_labelize(nature));
    }
    if (variantFaction != null &&
        variantFaction.trim().isNotEmpty &&
        variantFaction.trim().toLowerCase() != 'bloodborn') {
      parts.add('${_labelize(variantFaction)} Variant');
    }
    if (element != null) {
      parts.add('$element$family');
    } else {
      parts.add(family);
    }
    return parts.join(' ');
  }

  Map<String, int> _decodeLineage(String? raw, {String? fallback}) {
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = (jsonDecode(raw) as Map).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        );
        decoded.removeWhere((_, value) => value <= 0);
        if (decoded.isNotEmpty) {
          return Map<String, int>.from(decoded);
        }
      } catch (_) {}
    }

    final normalizedFallback = _normalizedFamily(fallback);
    if (normalizedFallback.isNotEmpty) {
      return {normalizedFallback: 1};
    }
    return const {};
  }

  bool _isSingleLineage(Map<String, int> lineage) {
    if (lineage.length != 1) return false;
    return lineage.values.first > 0;
  }

  bool _matchesSingleLineage(Map<String, int> lineage, String expected) {
    if (lineage.length != 1) return false;
    final entry = lineage.entries.first;
    return entry.value > 0 &&
        entry.key.trim().toLowerCase() == expected.trim().toLowerCase();
  }
}

class _ChallengeBlueprint {
  final String title;
  final String family;
  final String? previewSpeciesName;
  final String? requiredElement;
  final bool requireElementalPurity;
  final bool requireSpeciesPurity;
  final String? requiredSize;
  final String? requiredTint;
  final String? requiredTintLabel;
  final String? requiredNature;

  const _ChallengeBlueprint({
    required this.title,
    required this.family,
    this.previewSpeciesName,
    this.requiredElement,
    this.requireElementalPurity = false,
    this.requireSpeciesPurity = false,
    this.requiredSize,
    this.requiredTint,
    this.requiredTintLabel,
    this.requiredNature,
  });
}

String _normalizedFamily(String? family) {
  final normalized = family?.trim() ?? '';
  if (normalized.isEmpty) return '';
  return normalized[0].toUpperCase() + normalized.substring(1).toLowerCase();
}

String _labelize(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}

String _traitLabel(String value, String? customLabel) {
  if (customLabel != null && customLabel.trim().isNotEmpty) {
    return customLabel.trim();
  }
  switch (value.trim().toLowerCase()) {
    case 'warm':
      return 'Thermal';
    case 'cool':
      return 'Cryogenic';
    default:
      return _labelize(value);
  }
}

String _joinWithAnd(List<String> parts) {
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  if (parts.length == 2) return '${parts.first} and ${parts.last}';
  return '${parts.sublist(0, parts.length - 1).join(', ')}, and ${parts.last}';
}

extension on List<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
