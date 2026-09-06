import 'dart:math';

import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final commonCreature = Creature(
    id: 'LET01',
    name: 'Firelet',
    types: const ['Fire'],
    rarity: 'Common',
    description: 'Test creature',
    image: 'test.png',
    mutationFamily: 'Let',
    baseStats: const SpeciesBaseStats(
      speed: 52,
      intelligence: 50,
      strength: 50,
      beauty: 54,
    ),
  );
  final legendaryCreature = Creature(
    id: 'WNG01',
    name: 'Firewing',
    types: const ['Fire'],
    rarity: 'Legendary',
    description: 'Test creature',
    image: 'test.png',
    mutationFamily: 'Wing',
    baseStats: const SpeciesBaseStats(
      speed: 80,
      intelligence: 64,
      strength: 52,
      beauty: 72,
    ),
  );

  group('Wilderness stat generation', () {
    setUpAll(loadNatures);

    test('wild specimens derive stats from species base and Potential', () {
      final randomizer = WildCreatureRandomizer();

      for (var seed = 0; seed < 100; seed++) {
        final rolled = randomizer.randomizeWildCreature(
          commonCreature,
          seed: seed,
        );
        final stats = rolled.stats!;
        expect(stats.speedPotential, inInclusiveRange(1, 100));
        expect(stats.intelligencePotential, inInclusiveRange(1, 100));
        expect(stats.strengthPotential, inInclusiveRange(1, 100));
        expect(stats.beautyPotential, inInclusiveRange(1, 100));
        expect(
          stats.speed,
          closeTo(
            AlchemonStatSystem.effectiveInternal(
              speciesBase: 52,
              level: 1,
              potential: stats.speedPotential,
              additionalMultiplier: AlchemonStatSystem.natureMultiplier(
                rolled.nature?.id,
                'speed',
                rolled.nature2?.id,
              ),
            ),
            0.0001,
          ),
        );
      }
    });

    test('Arcane boost improves wild Potential without changing its scale', () {
      var normalTotal = 0.0;
      var boostedTotal = 0.0;
      for (var seed = 0; seed < 500; seed++) {
        normalTotal += WildCreatureRandomizer()
            .randomizeWildCreature(commonCreature, seed: seed)
            .stats!
            .speedPotential;
        boostedTotal += WildCreatureRandomizer()
            .randomizeWildCreature(
              commonCreature,
              seed: seed,
              arcaneBoostUnlocked: true,
            )
            .stats!
            .speedPotential;
      }

      expect(boostedTotal, greaterThan(normalTotal));
      expect(boostedTotal / 500, inInclusiveRange(60, 75));
    });

    test('a prepared wild specimen keeps the Potential block players saw', () {
      final prepared = WildCreatureRandomizer().randomizeWildCreature(
        commonCreature,
        seed: 42,
      );
      final reused = WildCreatureRandomizer().randomizeWildCreature(
        prepared,
        seed: 999,
        arcaneBoostUnlocked: true,
      );

      expect(reused, same(prepared));
      expect(reused.stats!.toJson(), prepared.stats!.toJson());
    });

    test('wild capture payload uses the same derived formula', () {
      for (var seed = 0; seed < 100; seed++) {
        final payload = EggPayloadFactory(
          CreatureCatalog.fromList(const []),
          random: Random(seed),
        ).createWildCapturePayload(commonCreature);

        expect(payload.potentials.speed, inInclusiveRange(1, 100));
        expect(
          payload.stats.speed,
          closeTo(
            AlchemonStatSystem.effectiveInternal(
              speciesBase: 52,
              level: 1,
              potential: payload.potentials.speed,
            ),
            0.0001,
          ),
        );
      }
    });

    test('stronger species bases produce stronger wild specimens', () {
      var commonTotal = 0.0;
      var legendaryTotal = 0.0;
      for (var seed = 0; seed < 200; seed++) {
        commonTotal += EggPayloadFactory(
          CreatureCatalog.fromList(const []),
          random: Random(seed),
        ).createWildCapturePayload(commonCreature).stats.speed;
        legendaryTotal += EggPayloadFactory(
          CreatureCatalog.fromList(const []),
          random: Random(seed),
        ).createWildCapturePayload(legendaryCreature).stats.speed;
      }

      expect(legendaryTotal, greaterThan(commonTotal * 1.45));
    });
  });
}
