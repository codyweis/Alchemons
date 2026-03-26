import 'dart:convert';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
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
            ? 'Elemental lineage — pure'
            : '${_labelize(requiredElement!)} element line — pure',
      );
    }
    if (requireSpeciesPurity) {
      lines.add('$requiredFamily species line — pure');
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
    lines.add('+$goldReward gold awarded');
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
    required this.isProtected,
    required this.message,
  });

  bool get matchesTrait => matchesTint && matchesSize && matchesNature;
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

    if (missing.isNotEmpty) {
      return PurebloodSacrificeCheck(
        isEligible: false,
        matchesFamily: true,
        pureElement: satisfiesElementPurity,
        pureFamily: pureFamily,
        matchesTint: matchesTint,
        matchesSize: matchesSize,
        matchesNature: matchesNature,
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
