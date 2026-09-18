import 'dart:ui';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required String family,
  double strength = 3,
  double intelligence = 3,
  double beauty = 3,
}) => CosmicPartyMember(
  instanceId: '$family-$strength-$intelligence-$beauty',
  baseId: family,
  displayName: family,
  element: 'Fire',
  family: family,
  level: 10,
  statSpeed: 3,
  statIntelligence: intelligence,
  statStrength: strength,
  statBeauty: beauty,
  slotIndex: 0,
  staminaBars: 3,
  staminaMax: 3,
);

/// How much of the floor this cast covers: the widest reach it puts down,
/// multiplied by how many things it puts down. Families answer Beauty in
/// different currencies — Wing widens one beam, Mask scatters more traps — and
/// the product is what a player actually sees either way.
/// Fire reads for most families, but a few author their Fire special
/// survival-side and put nothing in the shared table. Each family is measured
/// on an element it actually writes projectiles for.
const _coverageElement = {'kin': 'Water'};

double _footprint({required String family, required double beauty}) {
  final result = createCosmicSpecialAbility(
    origin: Offset.zero,
    baseAngle: 0,
    family: family,
    element: _coverageElement[family] ?? 'Fire',
    damage: 100,
    maxHp: 500,
    targetPos: const Offset(220, 0),
    casterBeauty: beauty,
    casterBeautyPotential: beauty >= kAbilityStatPerfect ? 100 : 50,
  );
  // The charge and channel elements put nothing on the floor to measure, so
  // their sweep counts as the footprint.
  var widest = result.chargeFinalSweepRadius > result.chargeSweepRadius
      ? result.chargeFinalSweepRadius
      : result.chargeSweepRadius;
  for (final p in result.projectiles) {
    for (final reach in [
      p.radiusMultiplier,
      p.effectRadius,
      p.snareRadius,
      p.visualScale,
    ]) {
      if (reach > widest) widest = reach;
    }
  }
  // Wing fights with beams, not projectiles; its width is its footprint.
  for (final beam in result.beams) {
    if (beam.width > widest) widest = beam.width;
  }
  final placements = result.projectiles.length + result.beams.length;
  return widest * (placements == 0 ? 1 : placements);
}

void main() {
  test('every authored family uses the shared special-power contract', () {
    expect(kCosmicTranscribedAbilityFamilies, kCosmicAuthoredAbilityFamilies);

    for (final family in kCosmicAuthoredAbilityFamilies) {
      final weights = cosmicFamilyAbilityStatWeights(family);
      expect(
        weights.strength + weights.intelligence + weights.beauty,
        closeTo(1, 0.000001),
        reason: family,
      );
    }
  });

  test('each family special responds to the stats named in its contract', () {
    for (final family in kCosmicAuthoredAbilityFamilies) {
      final weights = cosmicFamilyAbilityStatWeights(family);
      final base = deriveCosmicSurvivalCompanionStats(
        member: _member(family: family),
      ).abilityAtk;

      if (weights.strength > 0) {
        expect(
          deriveCosmicSurvivalCompanionStats(
            member: _member(family: family, strength: 5),
          ).abilityAtk,
          greaterThan(base),
          reason: '$family Strength',
        );
      }
      if (weights.intelligence > 0) {
        expect(
          deriveCosmicSurvivalCompanionStats(
            member: _member(family: family, intelligence: 5),
          ).abilityAtk,
          greaterThan(base),
          reason: '$family Intelligence',
        );
      }
      if (weights.beauty > 0) {
        expect(
          deriveCosmicSurvivalCompanionStats(
            member: _member(family: family, beauty: 5),
          ).abilityAtk,
          greaterThan(base),
          reason: '$family Beauty',
        );
      }
    }
  });

  test('Speed changes cooldown, not family special power', () {
    final slow = deriveCosmicSurvivalCompanionStats(
      member: _member(family: 'mane'),
    );
    final fastMember = _member(family: 'mane');
    final fast = deriveCosmicSurvivalCompanionStats(
      member: CosmicPartyMember(
        instanceId: 'fast-mane',
        baseId: fastMember.baseId,
        displayName: fastMember.displayName,
        element: fastMember.element,
        family: fastMember.family,
        level: fastMember.level,
        statSpeed: 5,
        statIntelligence: fastMember.statIntelligence,
        statStrength: fastMember.statStrength,
        statBeauty: fastMember.statBeauty,
        slotIndex: 0,
        staminaBars: 3,
        staminaMax: 3,
      ),
    );

    expect(fast.abilityAtk, slow.abilityAtk);
    expect(fast.cooldownReduction, greaterThan(slow.cooldownReduction));
  });

  test('Beauty widens what every family puts on the floor', () {
    for (final family in kCosmicAuthoredAbilityFamilies) {
      final plain = _footprint(family: family, beauty: kAbilityStatLow);
      final average = _footprint(family: family, beauty: kAbilityStatAverage);
      final perfect = _footprint(family: family, beauty: kAbilityStatPerfect);

      expect(average, greaterThan(0), reason: '$family authored no footprint');
      expect(
        plain,
        lessThan(average),
        reason: '$family: a plain caster must cover less ground',
      );
      expect(
        perfect,
        greaterThan(average),
        reason: '$family: a perfect caster must cover more ground',
      );
    }
  });

  test('the coverage curve is anchored, not a flat thirty percent', () {
    // The scalers this replaced spanned roughly 0.82x-1.24x, a swing no player
    // could feel. Every family must now separate its plain caster from its
    // perfect one by at least a third.
    for (final family in kCosmicAuthoredAbilityFamilies) {
      final plain = _footprint(family: family, beauty: kAbilityStatLow);
      final perfect = _footprint(family: family, beauty: kAbilityStatPerfect);
      expect(
        perfect / plain,
        greaterThan(1.33),
        reason: '$family: Beauty barely changes the cast',
      );
    }
  });


}
