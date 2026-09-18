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
}
