import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final commonCreature = Creature(
    id: 'LET01',
    name: 'Firelet',
    types: const ['Fire'],
    rarity: 'Common',
    description: 'Test creature',
    image: 'assets/images/creatures/common/LET01_firelet.png',
    mutationFamily: 'Let',
  );
  final legendaryCreature = Creature(
    id: 'WNG01',
    name: 'Firewing',
    types: const ['Fire'],
    rarity: 'Legendary',
    description: 'Test creature',
    image: 'assets/images/creatures/legendary/WNG01_firewing.png',
    mutationFamily: 'Wing',
  );

  group('Wilderness stat generation', () {
    setUpAll(() async {
      await loadNatures();
    });

    test(
      'wild breeding randomizer never rolls a base stat above potential',
      () {
        final randomizer = WildCreatureRandomizer();

        for (var seed = 0; seed < 500; seed++) {
          final rolled = randomizer.randomizeWildCreature(
            commonCreature,
            seed: seed,
          );
          final stats = rolled.stats!;

          expect(stats.speed, lessThanOrEqualTo(stats.speedPotential));
          expect(
            stats.intelligence,
            lessThanOrEqualTo(stats.intelligencePotential),
          );
          expect(stats.strength, lessThanOrEqualTo(stats.strengthPotential));
          expect(stats.beauty, lessThanOrEqualTo(stats.beautyPotential));
        }
      },
    );

    test('wild breeding randomizer uses boosted arcane wilderness ranges', () {
      final randomizer = WildCreatureRandomizer();

      for (var seed = 0; seed < 200; seed++) {
        final rolled = randomizer.randomizeWildCreature(
          commonCreature,
          seed: seed,
          arcaneBoostUnlocked: true,
        );
        final stats = rolled.stats!;

        expect(stats.speed, inInclusiveRange(1.5, 2.5));
        expect(stats.intelligence, inInclusiveRange(1.5, 2.5));
        expect(stats.strength, inInclusiveRange(1.5, 2.5));
        expect(stats.beauty, inInclusiveRange(1.5, 2.5));
        expect(stats.speedPotential, inInclusiveRange(2.0, 3.0));
        expect(stats.intelligencePotential, inInclusiveRange(2.0, 3.0));
        expect(stats.strengthPotential, inInclusiveRange(2.0, 3.0));
        expect(stats.beautyPotential, inInclusiveRange(2.0, 3.0));
      }
    });

    test('wild capture payload never rolls a base stat above potential', () {
      final payloadFactory = EggPayloadFactory(
        CreatureCatalog.fromList(const []),
      );

      for (var i = 0; i < 500; i++) {
        final payload = payloadFactory.createWildCapturePayload(commonCreature);

        expect(
          payload.stats.speed,
          lessThanOrEqualTo(payload.potentials.speed),
        );
        expect(
          payload.stats.intelligence,
          lessThanOrEqualTo(payload.potentials.intelligence),
        );
        expect(
          payload.stats.strength,
          lessThanOrEqualTo(payload.potentials.strength),
        );
        expect(
          payload.stats.beauty,
          lessThanOrEqualTo(payload.potentials.beauty),
        );
      }
    });

    test('wild capture payload uses boosted arcane wilderness ranges', () {
      final payloadFactory = EggPayloadFactory(
        CreatureCatalog.fromList(const []),
      );

      for (var i = 0; i < 200; i++) {
        final payload = payloadFactory.createWildCapturePayload(
          commonCreature,
          arcaneBoostUnlocked: true,
        );

        expect(payload.stats.speed, inInclusiveRange(1.5, 2.5));
        expect(payload.stats.intelligence, inInclusiveRange(1.5, 2.5));
        expect(payload.stats.strength, inInclusiveRange(1.5, 2.5));
        expect(payload.stats.beauty, inInclusiveRange(1.5, 2.5));
        expect(payload.potentials.speed, inInclusiveRange(2.0, 3.0));
        expect(payload.potentials.intelligence, inInclusiveRange(2.0, 3.0));
        expect(payload.potentials.strength, inInclusiveRange(2.0, 3.0));
        expect(payload.potentials.beauty, inInclusiveRange(2.0, 3.0));
      }
    });

    test('legendary wild capture uses boosted arcane wilderness ranges', () {
      final payloadFactory = EggPayloadFactory(
        CreatureCatalog.fromList(const []),
      );

      var foundAboveTwo = false;
      for (var i = 0; i < 500; i++) {
        final payload = payloadFactory.createWildCapturePayload(
          legendaryCreature,
          arcaneBoostUnlocked: true,
        );
        final stats = payload.stats;

        expect(stats.speed, inInclusiveRange(2.0, 4.0));
        expect(stats.intelligence, inInclusiveRange(2.0, 4.0));
        expect(stats.strength, inInclusiveRange(2.0, 4.0));
        expect(stats.beauty, inInclusiveRange(2.0, 4.0));
        expect(payload.potentials.speed, inInclusiveRange(2.0, 4.0));
        expect(payload.potentials.intelligence, inInclusiveRange(2.0, 4.0));
        expect(payload.potentials.strength, inInclusiveRange(2.0, 4.0));
        expect(payload.potentials.beauty, inInclusiveRange(2.0, 4.0));

        if (stats.speed > 2.0 ||
            stats.intelligence > 2.0 ||
            stats.strength > 2.0 ||
            stats.beauty > 2.0) {
          foundAboveTwo = true;
          break;
        }
      }

      expect(foundAboveTwo, isTrue);
    });
  });
}
