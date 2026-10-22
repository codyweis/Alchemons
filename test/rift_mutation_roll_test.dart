import 'dart:convert';
import 'dart:math';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/fx/rift_mutation_roll.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a rift rolls every mutation, about evenly', () {
    final rng = Random(1);
    final counts = <AlchemonMutation, int>{};
    for (var i = 0; i < 6000; i++) {
      final m = AlchemonMutation.rollRift(rng);
      counts[m] = (counts[m] ?? 0) + 1;
    }
    expect(counts.keys.toSet(), AlchemonMutation.values.toSet());
    for (final n in counts.values) {
      expect(n, inInclusiveRange(850, 1150));
    }
  });

  test('the ball lands on its mutation, slowing as it goes', () {
    for (final landing in AlchemonMutation.values) {
      for (var seed = 0; seed < 40; seed++) {
        final roll = RiftMutationRoll(landing, seed: seed);
        expect(roll.order.last, landing);
        expect(roll.order.length - 1, roll.washAt.length);
        for (var k = 1; k < roll.order.length; k++) {
          expect(roll.order[k], isNot(roll.order[k - 1]));
        }
        // Each gap longer than the one before.
        for (var k = 2; k < roll.washAt.length; k++) {
          expect(
            roll.washAt[k] - roll.washAt[k - 1],
            greaterThan(roll.washAt[k - 1] - roll.washAt[k - 2]),
          );
        }
        expect(roll.landed, greaterThan(roll.washAt.last));
        expect(roll.pourAt, greaterThan(roll.landed));
      }
    }
  });

  test('its first face says nothing about where it lands', () {
    final firsts = {
      for (var seed = 0; seed < 60; seed++)
        RiftMutationRoll(AlchemonMutation.starlit, seed: seed).order.first,
    };
    expect(firsts.length, AlchemonMutation.values.length);
  });

  test('a rift Alchemon\'s egg keeps its mutation', () {
    final creature = Creature(
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
    final factory = EggPayloadFactory(CreatureCatalog.fromList(const []));
    expect(factory.createWildCapturePayload(creature).mutation, isNull);
    final payload = factory.createWildCapturePayload(
      creature.copyWith(wildMutation: AlchemonMutation.obsidian.id),
    );
    expect(payload.mutation, AlchemonMutation.obsidian.id);
    expect(
      EggPayload.fromJson(
        jsonDecode(payload.toJsonString()) as Map<String, dynamic>,
      ).mutation,
      AlchemonMutation.obsidian.id,
    );
  });
}
