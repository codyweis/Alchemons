import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/creature_stats.dart';
import 'package:alchemons/screens/cosmic/cosmic_prologue_screen.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:flutter_test/flutter_test.dart';

Creature _wild({required Map<String, String> genetics}) => Creature(
  id: 'LET01',
  name: 'Test Let',
  types: const ['Fire'],
  rarity: 'legendary',
  description: '',
  image: 'creatures/let.png',
  mutationFamily: 'let',
  genetics: Genetics(genetics),
  stats: const CreatureStats(
    speed: 1.1,
    intelligence: 1.2,
    strength: 1.3,
    beauty: 1.4,
    speedPotential: 40.0,
    intelligencePotential: 40.0,
    strengthPotential: 40.0,
    beautyPotential: 40.0,
  ),
);

void main() {
  group('the Let behind the gate', () {
    test('is authored at 2.5 across the board with 76 potentials', () {
      final shaped = shapeCrossingLet(_wild(genetics: const {}));
      final s = shaped.stats!;

      expect(s.speed, 2.5);
      expect(s.intelligence, 2.5);
      expect(s.strength, 2.5);
      expect(s.beauty, 2.5);
      expect(s.speedPotential, 76);
      expect(s.intelligencePotential, 76);
      expect(s.strengthPotential, 76);
      expect(s.beautyPotential, 76);
    });

    test('keeps its prismatic skin', () {
      expect(shapeCrossingLet(_wild(genetics: const {})).isPrismaticSkin, true);
    });

    test('renders at normal pigment whatever the generator rolled', () {
      for (final rolled in ['pale', 'vibrant', 'warm', 'cool', 'albino']) {
        final shaped = shapeCrossingLet(
          _wild(genetics: {'tinting': rolled, 'size': 'giant'}),
        );
        final g = shaped.genetics!;

        expect(g.get('tinting'), 'normal', reason: 'rolled $rolled');
        // Normal pigment means no hue shift, no desaturation, no blow-out.
        expect(satFromGenes(g), 1.0);
        expect(briFromGenes(g), 1.0);
        expect(hueFromGenes(g), 0.0);
        // Non-pigment genetics are left alone.
        expect(g.get('size'), 'giant');
      }
    });

    test('adds a normal pigment track even when genetics are empty', () {
      final shaped = shapeCrossingLet(_wild(genetics: const {}));
      expect(shaped.genetics!.get('tinting'), 'normal');
    });
  });
}
