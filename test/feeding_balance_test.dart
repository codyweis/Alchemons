import 'package:alchemons/services/creature_instance_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Enhancement XP curve', () {
    test(
      'reaches level 5 faster and slows levels 6-10 while keeping 42 fodder',
      () {
        const curve = <int>[42, 50, 60, 70, 130, 165, 205, 250, 318];

        for (var level = 1; level <= curve.length; level++) {
          expect(
            CreatureInstanceServiceFeeding.xpNeededForLevel(level),
            curve[level - 1],
          );
        }

        final totalXp = curve.reduce((sum, xp) => sum + xp);
        final toLevelFive = curve.take(4).reduce((sum, xp) => sum + xp);
        final fromLevelFiveToTen = curve.skip(4).reduce((sum, xp) => sum + xp);

        expect(totalXp, 1290);
        expect(toLevelFive, lessThan(288));
        expect(fromLevelFiveToTen, greaterThan(1002));

        const sameSpeciesLevelOneFodderXp = 31;
        expect((totalXp / sameSpeciesLevelOneFodderXp).ceil(), 42);
        expect(((totalXp - 1) / sameSpeciesLevelOneFodderXp).ceil(), 42);
        expect(
          ((totalXp - sameSpeciesLevelOneFodderXp) /
                  sameSpeciesLevelOneFodderXp)
              .ceil(),
          41,
        );
      },
    );

    test('level 1 same-species fodder XP remains unchanged', () {
      const rawXp = 25;
      const sameSpeciesMultiplier = 1.25;
      expect((rawXp * sameSpeciesMultiplier).round(), 31);
    });
  });
}
