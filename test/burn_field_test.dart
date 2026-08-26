// THE BURN — Fire Star 2's rules, pinned.
//
// Every claim the design makes, tested against the real module: fire needs
// fuel, fire follows the wind, burnt ground is spent (so the trail is the
// wall), water grows vine that never catches, and an unfed head gets exactly
// one beat of grace before it goes out.

import 'package:alchemons/games/planet_dungeon/burn_field.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:flutter_test/flutter_test.dart';

BurnField _field(
  List<String> art, {
  BurnWind wind = BurnWind.east,
  int goal = 0,
}) => BurnField.parse(art, wind: wind, coverageGoal: goal);

void main() {
  group('the burn', () {
    test('fire needs FUEL: it walks into vine and nothing else', () {
      final f = _field(['vv.']);
      expect(f.light(0), isTrue);
      expect(f.step(), BurnStep.advanced, reason: 'vine downwind');
      expect(f.step(), BurnStep.smouldered, reason: 'bare soil downwind');
    });

    test('fire follows the WIND, and swinging the vane bends it', () {
      // A corner: vine east, then vine south of that.
      final f = _field(['vv', '.v']);
      expect(f.light(0), isTrue);
      expect(f.step(), BurnStep.advanced); // east onto (1,0)
      expect(f.head, 1);
      // Due east there is nothing — but south there is.
      expect(f.step(), BurnStep.smouldered);
      f.wind = BurnWind.south;
      expect(f.step(), BurnStep.advanced, reason: 'the vane turned the fire');
      expect(f.head, 3);
    });

    test('burnt ground is SPENT: no flame, and no new vine', () {
      final f = _field(['vv']);
      f.light(0);
      expect(f.at(0), BurnCell.ash);
      expect(f.plant(0), isFalse, reason: 'ash takes no vine');
      f.step();
      expect(f.at(1), BurnCell.ash);
    });

    test('THE SNAKE: the fire cannot cross its own trail', () {
      // A ring of vine. Going round it, the head comes back to its own ash.
      final f = _field(['vvv', 'v.v', 'vvv']);
      f.light(0); // top-left, heading east
      expect(f.step(), BurnStep.advanced);
      expect(f.step(), BurnStep.advanced); // at top-right
      f.wind = BurnWind.south;
      expect(f.step(), BurnStep.advanced);
      expect(f.step(), BurnStep.advanced); // bottom-right
      f.wind = BurnWind.west;
      expect(f.step(), BurnStep.advanced);
      expect(f.step(), BurnStep.advanced); // bottom-left
      f.wind = BurnWind.north;
      expect(f.step(), BurnStep.advanced); // (0,1)
      // Due north is where it STARTED, and that is ash now.
      expect(
        f.step(),
        BurnStep.smouldered,
        reason: 'its own trail is the wall',
      );
    });

    test('WATER grows vine that never catches — fuel is not fire', () {
      final f = _field(['v~v']);
      expect(f.plant(1), isTrue, reason: 'wet ground takes vine happily');
      expect(f.at(1), BurnCell.wetVine);
      f.light(0);
      expect(
        f.step(),
        BurnStep.smouldered,
        reason: 'the chain dies at the water',
      );
      expect(f.light(1), isFalse, reason: 'and it cannot be lit directly');
    });

    test('STONE is a wall for vine and flame alike', () {
      final f = _field(['v#v']);
      expect(f.plant(1), isFalse);
      f.light(0);
      expect(f.step(), BurnStep.smouldered);
    });

    test('the SMOULDER is exactly one beat of grace', () {
      final f = _field(['v..']);
      f.light(0);
      expect(f.step(), BurnStep.smouldered);
      expect(f.alight, isTrue, reason: 'still time to plant ahead of it');
      expect(f.step(), BurnStep.died);
      expect(f.alight, isFalse);
    });

    test('planting into the grace beat saves the chain', () {
      final f = _field(['v..']);
      f.light(0);
      expect(f.step(), BurnStep.smouldered);
      expect(f.plant(1), isTrue); // laid in front of a smouldering head
      expect(f.step(), BurnStep.advanced, reason: 'the scramble works');
      expect(f.smoulder, 0, reason: 'and the grace resets');
    });

    test('the POOL fills with coverage, and only coverage frees the star', () {
      final f = _field(['vvvv'], goal: 4);
      f.light(0);
      expect(f.poolFull, isFalse);
      f.step();
      f.step();
      expect(f.poolFraction, closeTo(0.75, 0.001));
      expect(f.poolFull, isFalse, reason: 'a short greedy chain is not enough');
      f.step();
      expect(f.burnt, 4);
      expect(f.poolFull, isTrue);
    });

    test('a sealed-in fire is honestly declared lost, not left hoping', () {
      // Goal needs the whole board, but the flame boxes itself in a corner.
      final f = _field(['vv', 'vv'], goal: 4);
      f.light(0);
      f.wind = BurnWind.south;
      f.step(); // (0,1)
      f.wind = BurnWind.east;
      f.step(); // (1,1)
      f.wind = BurnWind.north;
      f.step(); // (1,0) — every cell burnt
      expect(f.burnt, 4);
      expect(f.poolFull, isTrue);
    });

    test('an authored field can be PROVEN to meet its goal', () {
      final f = _field(['.....', '.###.', '.....']);
      // Twelve cells are dry ground and the ring walks end to end.
      expect(f.canBurnAtLeast(0, 12), isTrue);
      expect(
        f.canBurnAtLeast(0, 13),
        isFalse,
        reason: 'a field whose goal exceeds its ground is unauthorable',
      );
    });

    test('canStillFill turns a doomed run into an honest restart', () {
      final f = _field(['v#', '##'], goal: 4);
      f.light(0);
      expect(
        f.canStillFill,
        isFalse,
        reason: 'walled in on every side — the answer is the restart',
      );
    });
  });

  group('the authored garth', () {
    test('the cloister field can actually meet its coverage goal', () {
      final room = kPlanetDungeonLayouts['Fire']!.rooms['cloister']!;
      final garth = room.garth;
      expect(garth, isNotNull, reason: 'Fire Star 2 is THE BURN now');

      final f = BurnField.parse(garth!.art, coverageGoal: garth.coverageGoal);
      // SOME start must be able to reach the goal, walking the real rules.
      var reachable = false;
      for (var i = 0; i < garth.cols * garth.rows && !reachable; i++) {
        if (f.at(i) != BurnCell.soil) continue;
        reachable = f.canBurnAtLeast(i, garth.coverageGoal);
      }
      expect(
        reachable,
        isTrue,
        reason:
            'a garth whose pool cannot be filled is unauthorable '
            '(goal ${garth.coverageGoal})',
      );
      // And the goal must DEMAND a real route: count the burnable ground.
      var dry = 0;
      for (var i = 0; i < garth.cols * garth.rows; i++) {
        if (f.at(i) == BurnCell.soil || f.at(i) == BurnCell.vine) dry++;
      }
      expect(
        garth.coverageGoal,
        greaterThan(dry * 0.4),
        reason: 'a goal a lazy short chain could reach is not a puzzle',
      );
    });

    test('the garth is a maze, not a lawn', () {
      final garth = kPlanetDungeonLayouts['Fire']!.rooms['cloister']!.garth!;
      final f = BurnField.parse(garth.art);
      var stone = 0, wet = 0;
      for (var i = 0; i < garth.cols * garth.rows; i++) {
        if (f.at(i) == BurnCell.stone) stone++;
        if (f.at(i) == BurnCell.wet) wet++;
      }
      expect(stone, greaterThan(0), reason: 'fallen columns bend the route');
      expect(
        wet,
        greaterThan(0),
        reason: 'the seep is the trap that teaches fuel != fire',
      );
    });
  });
}
