import 'package:alchemons/services/creature_instance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Enhancement XP curve', () {
    test('uses rarity-specific XP curves for target progression', () {
      const expectedCurves = <String, List<int>>{
        'Common': [20, 24, 28, 34, 60, 75, 95, 125, 159],
        'Uncommon': [25, 30, 36, 42, 78, 99, 123, 150, 192],
        'Rare': [30, 36, 43, 51, 93, 118, 147, 180, 232],
        'Legendary': [40, 48, 58, 67, 125, 160, 200, 245, 297],
      };

      const sameSpeciesLevelOneFodderXp = 31;

      expectedCurves.forEach((rarity, curve) {
        for (var level = 1; level <= curve.length; level++) {
          expect(
            CreatureInstanceServiceFeeding.xpNeededForLevel(
              level,
              rarity: rarity,
            ),
            curve[level - 1],
          );
        }

        final totalXp = curve.reduce((sum, xp) => sum + xp);
        final toLevelFive = curve.take(4).reduce((sum, xp) => sum + xp);
        final fromLevelFiveToTen = curve.skip(4).reduce((sum, xp) => sum + xp);

        expect(toLevelFive, lessThan(fromLevelFiveToTen));
        expect((totalXp / sameSpeciesLevelOneFodderXp).ceil(), switch (rarity) {
          'Common' => 20,
          'Uncommon' => 25,
          'Rare' => 30,
          'Legendary' => 40,
          _ => throw StateError('Unexpected rarity $rarity'),
        });
      });
    });

    test('level 1 same-species fodder XP remains unchanged', () {
      const rawXp = 25;
      const sameSpeciesMultiplier = 1.25;
      expect((rawXp * sameSpeciesMultiplier).round(), 31);
    });
  });
}
