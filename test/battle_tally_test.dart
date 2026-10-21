// The battle's tally of who did what (cosmic_game_battle.dart), which the
// result card's DETAILS shows: every creature's damage dealt, damage taken
// and healing. What one side dealt is what the other side lost, a fallen
// Alchemon took at least its whole health, and nearly all of it is put to a
// creature rather than to its side.
//
//   TALLY_REPORT=1 flutter test test/battle_tally_test.dart
// prints each fight's lines.

import 'dart:io';

import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_test.dart' show battleArena, battleMember, runBattle;

double _dealt(BattleSide s) =>
    s.creatures.fold(0.0, (sum, c) => sum + c.damageDealt);
double _taken(BattleSide s) =>
    s.creatures.fold(0.0, (sum, c) => sum + c.damageTaken);

void main() {
  final report = Platform.environment['TALLY_REPORT'] != null;

  // Every family on one side or the other, healers and shields included.
  final fights = [
    (
      [
        battleMember('Horn', 'Fire'),
        battleMember('Wing', 'Air'),
        battleMember('Kin', 'Water'),
        battleMember('Pip', 'Earth'),
      ],
      [
        battleMember('Mane', 'Lava'),
        battleMember('Mask', 'Plant'),
        battleMember('Let', 'Ice'),
        battleMember('Wing', 'Light'),
      ],
    ),
    (
      [
        battleMember('Kin', 'Fire'),
        battleMember('Mask', 'Blood'),
        battleMember('Horn', 'Earth'),
        battleMember('Let', 'Dark'),
      ],
      [
        battleMember('Kin', 'Plant'),
        battleMember('Pip', 'Mud'),
        battleMember('Mane', 'Air'),
        battleMember('Mask', 'Spirit'),
      ],
    ),
    (
      [
        battleMember('Wing', 'Crystal'),
        battleMember('Wing', 'Water'),
        battleMember('Pip', 'Lightning'),
      ],
      [
        battleMember('Horn', 'Light'),
        battleMember('Let', 'Fire'),
        battleMember('Mane', 'Crystal'),
      ],
    ),
  ];

  for (final (i, (home, away)) in fights.indexed) {
    test('fight ${i + 1}: what each side dealt is what the other lost', () async {
      final (game, center) = await battleArena();
      final b = game.startBattle(
        home: home,
        away: away,
        homeAuto: true,
        center: center,
      );
      runBattle(game);
      expect(b.over, isTrue);

      for (final s in b.sides) {
        final other = b.sides[1 - s.index];
        // Every point one side lost is some creature's of the other's.
        expect(_dealt(s), closeTo(_taken(other), 1e-6 * (1 + _taken(other))));
        expect(_taken(other), greaterThan(0));
        for (final c in s.creatures) {
          expect(c.damageDealt, greaterThanOrEqualTo(0));
          expect(c.damageTaken, greaterThanOrEqualTo(0));
          expect(c.healing, greaterThanOrEqualTo(0));
          // One kept on the bench all fight did nothing and took nothing.
          if (!c.wasOnField) {
            expect(c.damageDealt + c.damageTaken + c.healing, 0);
          }
          // A fallen one lost at least the whole health it came in with.
          if (c.fallen) {
            final full = deriveAlchemonCombatStats(member: c.member).maxHp;
            expect(c.damageTaken, greaterThanOrEqualTo(full - 1));
          }
        }
        // Whoever was out and lived long enough to act dealt something.
        expect(
          s.creatures.where((c) => c.wasOnField && c.damageDealt > 0),
          isNotEmpty,
        );
      }
      // Nearly all of it is put to one creature, not shared out by side.
      final all = _taken(b.sides[0]) + _taken(b.sides[1]);
      expect(b.unattributed / all, lessThan(0.05));

      if (report) {
        stdout.writeln(
          'fight ${i + 1}: winner ${b.result!.winner} at '
          '${b.result!.at.toStringAsFixed(1)} s, unattributed '
          '${(100 * b.unattributed / all).toStringAsFixed(2)}%',
        );
        for (final s in b.sides) {
          for (final c in s.creatures) {
            stdout.writeln(
              '  ${s.index} ${c.member.displayName.padRight(14)} '
              'dealt ${c.damageDealt.round().toString().padLeft(6)}  '
              'taken ${c.damageTaken.round().toString().padLeft(6)}  '
              'healed ${c.healing.round().toString().padLeft(5)}'
              '${c.fallen ? '  fallen' : ''}${c.wasOnField ? '' : '  benched'}',
            );
          }
        }
      }
    });
  }

  test('a healer is credited with its healing', () async {
    final (game, center) = await battleArena();
    final b = game.startBattle(
      home: [
        battleMember('Kin', 'Water', stat: 4.5),
        battleMember('Horn', 'Fire', stat: 4.5),
      ],
      away: [battleMember('Mane', 'Lava'), battleMember('Let', 'Ice')],
      homeAuto: true,
      center: center,
    );
    runBattle(game);
    expect(b.sides[0].creatures[0].healing, greaterThan(0));
    // Healing is the healer's, never the healed's own.
    expect(b.sides[1].creatures.every((c) => c.healing == 0), isTrue);
  });
}
