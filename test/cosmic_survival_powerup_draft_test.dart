import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required String family,
  required double speed,
  required double intelligence,
  required double strength,
  required double beauty,
  int slotIndex = 0,
}) {
  return CosmicPartyMember(
    instanceId: 'test_${family}_$slotIndex',
    baseId: 'base_$family',
    displayName: family,
    element: 'Fire',
    family: family,
    level: 10,
    statSpeed: speed,
    statIntelligence: intelligence,
    statStrength: strength,
    statBeauty: beauty,
    slotIndex: slotIndex,
    staminaBars: 3,
    staminaMax: 3,
  );
}

void main() {
  group('cosmic survival draft weighting', () {
    test('speed-focused pip values tempo upgrades over horn', () {
      final pip = _member(
        family: 'pip',
        speed: 4.1,
        intelligence: 3.2,
        strength: 3.8,
        beauty: 2.8,
      );
      final horn = _member(
        family: 'horn',
        speed: 2.4,
        intelligence: 3.0,
        strength: 4.0,
        beauty: 2.4,
      );
      final tempoDef = kCompanionStatBoosts.firstWhere(
        (def) => def.id == 'speed_boost',
      );

      expect(
        powerUpDraftWeightForMember(tempoDef, pip),
        greaterThan(powerUpDraftWeightForMember(tempoDef, horn)),
      );
    });

    test('mystic values special-cast perks over pip', () {
      final mystic = _member(
        family: 'mystic',
        speed: 3.0,
        intelligence: 4.0,
        strength: 2.3,
        beauty: 4.2,
      );
      final pip = _member(
        family: 'pip',
        speed: 4.0,
        intelligence: 3.0,
        strength: 3.7,
        beauty: 2.2,
      );
      final doubleCast = kRarePerks.firstWhere(
        (def) => def.id == 'double_cast',
      );

      expect(
        powerUpDraftWeightForMember(doubleCast, mystic),
        greaterThan(powerUpDraftWeightForMember(doubleCast, pip)),
      );
    });

    test(
      'fortress teams value orb and sustain tools more than tempo squads',
      () {
        final fortressTeam = [
          _member(
            family: 'horn',
            speed: 2.6,
            intelligence: 3.5,
            strength: 4.0,
            beauty: 2.4,
          ),
          _member(
            family: 'kin',
            speed: 2.5,
            intelligence: 4.0,
            strength: 3.0,
            beauty: 3.6,
            slotIndex: 1,
          ),
        ];
        final tempoTeam = [
          _member(
            family: 'pip',
            speed: 4.2,
            intelligence: 3.3,
            strength: 3.7,
            beauty: 2.4,
          ),
          _member(
            family: 'wing',
            speed: 3.5,
            intelligence: 4.0,
            strength: 2.4,
            beauty: 3.8,
            slotIndex: 1,
          ),
        ];
        final regenField = kOrbDefenses.firstWhere(
          (def) => def.id == 'regen_field',
        );

        expect(
          powerUpDraftWeightForParty(regenField, fortressTeam),
          greaterThan(powerUpDraftWeightForParty(regenField, tempoTeam)),
        );
      },
    );

    test('keystone offers appear as three unique run-defining picks', () {
      final casterTeam = [
        _member(
          family: 'mystic',
          speed: 3.0,
          intelligence: 4.1,
          strength: 2.4,
          beauty: 4.3,
        ),
        _member(
          family: 'wing',
          speed: 3.5,
          intelligence: 4.0,
          strength: 2.6,
          beauty: 3.8,
          slotIndex: 1,
        ),
      ];

      final choices = generateKeystoneChoices(
        PowerUpState(),
        10,
        party: casterTeam,
      );

      expect(choices, hasLength(3));
      expect(choices.map((choice) => choice.def.id).toSet().length, 3);
      expect(choices.every((choice) => choice.def.isKeystone), isTrue);
      expect(
        choices.any((choice) => choice.def.id == 'keystone_spellbloom'),
        isTrue,
      );
    });

    test('keystone state applies persistent modifiers once chosen', () {
      final state = PowerUpState();
      final keystone = kKeystonePowerUps.firstWhere(
        (def) => def.id == 'keystone_chrono_surge',
      );

      expect(state.hasKeystone, isFalse);
      expect(state.apply(keystone), isTrue);
      expect(state.hasKeystone, isTrue);
      expect(state.fireRateMultiplier, closeTo(1.20, 0.0001));
      expect(state.companionSpeedMultiplier(0), closeTo(1.16, 0.0001));
      expect(state.companionCooldownReduction(0), closeTo(0.10, 0.0001));
      expect(generateKeystoneChoices(state, 9, party: const []), isEmpty);
    });
  });
}
