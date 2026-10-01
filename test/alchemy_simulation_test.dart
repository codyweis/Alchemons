import 'dart:convert';
import 'dart:io';
import 'package:alchemons/games/alchemy/alchemy_simulation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final json =
      jsonDecode(
            File(
              'assets/data/alchemons_element_recipes.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;
  AlchemySimulation make() => AlchemySimulation(recipeJson: json);

  test(
    'All canonical recipes always produce their main result in both orders',
    () {
      final sim = make();
      expect(sim.recipes.length, 41);
      for (final entry in (json['recipes'] as Map<String, dynamic>).entries) {
        final names = entry.key.split('+');
        if (names.length != 2) continue;
        final outcomes = (entry.value as Map<String, dynamic>).entries.toList()
          ..sort((a, b) => (b.value as num).compareTo(a.value as num));
        final expected = AlchemyElement.named(outcomes.first.key);
        for (final reversed in [false, true]) {
          for (var n = 0; n < 20; n++) {
            final a = AlchemyElement.named(names[reversed ? 1 : 0]),
                b = AlchemyElement.named(names[reversed ? 0 : 1]);
            sim.clear();
            sim.put(20, 20, a);
            sim.put(21, 20, b);
            expect(
              sim.react(
                20 * AlchemySimulation.width + 20,
                20 * AlchemySimulation.width + 21,
              ),
              isTrue,
              reason: entry.key,
            );
            expect(sim.cells[20 * AlchemySimulation.width + 20], expected.id);
            expect(sim.particleCount, 1);
          }
        }
      }
    },
  );

  test('Unknown contacts and same-element contacts are left alone', () {
    final sim = make();
    sim.put(20, 20, AlchemyElement.blood);
    sim.put(21, 20, AlchemyElement.earth);
    expect(sim.react(2580, 2581), false);
    expect(sim.particleCount, 2);
    sim.clear();
    sim.put(20, 20, AlchemyElement.water);
    sim.put(21, 20, AlchemyElement.water);
    expect(sim.react(2580, 2581), false);
    expect(sim.particleCount, 2);
  });

  test(
    'All studies produce reactions; clear empties the vessel and stops sources',
    () {
      final sim = make();
      for (final study in AlchemyStudy.values) {
        sim.reset(study);
        for (var i = 0; i < 300; i++) {
          sim.step();
        }
        expect(sim.reactionCount, greaterThan(0), reason: study.name);
        expect(
          sim.cells.every((id) => id <= AlchemyElement.values.length),
          true,
        );
        expect(sim.flashes.length, lessThanOrEqualTo(60));
      }
      sim.clear();
      for (var i = 0; i < 100; i++) {
        sim.step();
      }
      expect(sim.particleCount, 0);
      expect(sim.feeding, false);
      expect(sim.journal, isEmpty);
    },
  );

  test(
    'Gravity settles water; crystal stays fixed; erased matter is removed',
    () {
      final sim = make()..feeding = false;
      sim.put(30, 30, AlchemyElement.water);
      sim.put(50, 30, AlchemyElement.crystal);
      for (var i = 0; i < 220; i++) {
        sim.step();
      }
      expect(
        sim.cells[30 * AlchemySimulation.width + 50],
        AlchemyElement.crystal.id,
      );
      final water = sim.cells.indexOf(AlchemyElement.water.id);
      expect(water ~/ AlchemySimulation.width, greaterThan(145));
      sim.brush(50, 30, AlchemyElement.water, AlchemyTool.erase, 3);
      expect(sim.cells[30 * AlchemySimulation.width + 50], 0);
    },
  );
}
