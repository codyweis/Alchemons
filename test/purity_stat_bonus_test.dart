import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// An unbroken bloodline is worth one rolled stat. The roll has to be the same
/// every time it is asked for, because the stat formula runs and writes back on
/// every load — a roll from a plain random source would re-roll the creature on
/// every launch.
void main() {
  PurityStatBonus roll(
    String id, {
    required bool element,
    required bool species,
  }) => resolvePurityStatBonus(
    instanceId: id,
    isElementallyPure: element,
    isSpeciesPure: species,
  );

  group('what each lineage is worth', () {
    test('a mixed lineage is worth nothing', () {
      final bonus = roll('mixed-1', element: false, species: false);
      expect(bonus.isNone, isTrue);
      expect(bonus.statKey, isNull);
      for (final stat in kFullPurityStatPool) {
        expect(bonus.multiplierFor(stat), 1.0);
      }
    });

    test('full purity rolls 15% on any one of the four', () {
      for (var i = 0; i < 40; i++) {
        final bonus = roll('full-$i', element: true, species: true);
        expect(bonus.kind, PurityStatBonusKind.full);
        expect(bonus.bonus, kFullPurityBonus);
        expect(kFullPurityStatPool, contains(bonus.statKey));
      }
    });

    test('an elemental line rolls 10% on Beauty or Intelligence', () {
      for (var i = 0; i < 40; i++) {
        final bonus = roll('elem-$i', element: true, species: false);
        expect(bonus.kind, PurityStatBonusKind.elemental);
        expect(bonus.bonus, kPartialPurityBonus);
        expect(kElementalPurityStatPool, contains(bonus.statKey));
      }
    });

    test('a species line rolls 10% on Speed or Strength', () {
      for (var i = 0; i < 40; i++) {
        final bonus = roll('spec-$i', element: false, species: true);
        expect(bonus.kind, PurityStatBonusKind.species);
        expect(bonus.bonus, kPartialPurityBonus);
        expect(kSpeciesPurityStatPool, contains(bonus.statKey));
      }
    });

    test('the bonus lands on exactly one stat, never all of them', () {
      final bonus = roll('one-stat', element: true, species: true);
      final lifted = kFullPurityStatPool
          .where((s) => bonus.multiplierFor(s) > 1.0)
          .toList();
      expect(lifted, hasLength(1));
      expect(lifted.single, bonus.statKey);
    });
  });

  group('the roll never moves', () {
    test('the same creature rolls the same stat every time', () {
      final first = roll('stable-abc', element: true, species: true);
      for (var i = 0; i < 100; i++) {
        expect(
          roll('stable-abc', element: true, species: true).statKey,
          first.statKey,
        );
      }
    });

    test('the roll is pinned to known values, not merely self-consistent', () {
      // A recorded expectation, so a change to the hash is a failing test
      // rather than a silent re-roll of every pure creature in every save.
      expect(
        roll('alpha', element: true, species: true).statKey,
        kStatStrength,
      );
      expect(roll('bravo', element: true, species: false).statKey, kStatBeauty);
      expect(
        roll('charlie', element: false, species: true).statKey,
        kStatStrength,
      );
    });

    test('the four stats come up about equally often', () {
      final counts = <String, int>{};
      for (var i = 0; i < 400; i++) {
        final key = roll('spread-$i', element: true, species: true).statKey!;
        counts[key] = (counts[key] ?? 0) + 1;
      }
      expect(
        counts.keys.toSet(),
        kFullPurityStatPool.toSet(),
        reason: 'The roll collapsed onto $counts — that is not a roll.',
      );
      // A hash that clumps would make one stat the "pure" stat in practice.
      for (final entry in counts.entries) {
        expect(
          entry.value,
          inInclusiveRange(70, 130),
          reason: 'Lopsided distribution: $counts',
        );
      }
    });

    test('an empty id cannot roll at all', () {
      expect(roll('', element: true, species: true).isNone, isTrue);
    });
  });

  group('what it is worth in real stats', () {
    test('15% of a median creature is a visible amount', () {
      double stat(double multiplier) => AlchemonStatSystem.effectiveInternal(
        speciesBase: 69,
        level: 10,
        potential: 50,
        additionalMultiplier: multiplier,
      );
      final plain = stat(1.0);
      final pure = stat(1.0 + kFullPurityBonus);
      expect(plain, closeTo(4.31, 0.01));
      expect(pure, closeTo(4.96, 0.01));
    });

    test('it multiplies alongside nature rather than replacing it', () {
      final bonus = roll('combined', element: true, species: true);
      final key = bonus.statKey!;
      final combined =
          AlchemonStatSystem.natureMultiplier('Elegant', 'beauty') *
          bonus.multiplierFor(key);
      // Whatever it rolled, the purity part is still its own factor.
      expect(combined, greaterThan(1.0));
    });
  });

  group('the analysis readout', () {
    test('names the lineage and what it rolled', () {
      final bonus = roll('readout', element: true, species: true);
      expect(bonus.readout, startsWith('Pure · +15% '));
      expect(
        bonus.readout.toLowerCase(),
        contains(bonus.statKey!.toLowerCase()),
      );
    });

    test('a mixed lineage reads as mixed and promises nothing', () {
      final bonus = roll('plain', element: false, species: false);
      expect(bonus.readout, 'Mixed Lineage');
      expect(bonus.readout, isNot(contains('%')));
    });

    test('each partial lineage names itself', () {
      expect(
        roll('e', element: true, species: false).readout,
        startsWith('Elementally Pure · +10% '),
      );
      expect(
        roll('s', element: false, species: true).readout,
        startsWith('Species Pure · +10% '),
      );
    });
  });
}
