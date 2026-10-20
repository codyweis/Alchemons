// The Emerald Cup's battle ladder: every round's set team is whole, and how
// often a player's four beat it.
//
//   LADDER_REPORT=1 flutter test test/gem_battle_ladder_test.dart
//     [LADDER_N=30]        fights per round and breeding
//     [LADDER_ROUNDS=0,4]  which rounds
//     [LADDER_P=78:2,95:10] the round's team bred otherwise (Potential:rank)
//     [LADDER_TEAM=Wing:Dark,Kin:Blood,Horn:Crystal,Let:Spirit] another
//                          four for the rounds asked (with LADDER_ROUNDS)
//     [LADDER_TRACE=1]     each round's first fight at its own breeding,
//                          event by event
//
// The player's four are drawn from the whole catalog (four families, no
// Mystics), the same draws at every breeding, so the table reads across.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/stadium/battle_ladder.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_test.dart' show battleArena, runBattle;

CreatureCatalog _catalog() {
  final json =
      jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
          as Map<String, dynamic>;
  return CreatureCatalog.fromList([
    for (final c in json['creatures'] as List)
      Creature.fromJson(c as Map<String, dynamic>),
  ]);
}

GemCup get _ladder => kGemCups.firstWhere((c) => c.event == GemEvent.battle);

void main() {
  final catalog = _catalog();

  test('every round brings four, none a Mystic', () {
    final cup = _ladder;
    expect(cup.bouts, hasLength(5));
    for (final bout in cup.bouts) {
      final team = ladderTeamFor(catalog, bout, sprites: false);
      expect(team, hasLength(4), reason: bout.id);
      expect(
        team.where((m) => m.family.toLowerCase() == 'mystic'),
        isEmpty,
        reason: bout.id,
      );
    }
  });

  test('ladder balance', () async {
    final env = Platform.environment;
    if (env['LADDER_REPORT'] == null) return;
    final cup = _ladder;
    final n = int.tryParse(env['LADDER_N'] ?? '') ?? 30;
    final rounds =
        env['LADDER_ROUNDS']?.split(',').map(int.parse).toList() ??
        [for (var i = 0; i < cup.bouts.length; i++) i];
    final overrides = env['LADDER_P']?.split(',');
    final pool = catalog.creatures
        .where(
          (c) =>
              c.baseStats != null &&
              c.types.isNotEmpty &&
              (c.mutationFamily ?? '').isNotEmpty &&
              c.mutationFamily!.toLowerCase() != 'mystic',
        )
        .toList();
    // The breeding each round is tuned for, in order, and perfect.
    const setups = [(50, 0), (65, 0), (78, 2), (88, 5), (95, 10), (100, 10)];
    stdout.writeln(
      '${'round'.padRight(18)}'
      '${setups.map((s) => 'P${s.$1}e${s.$2}'.padLeft(9)).join()}   (wins of $n)',
    );
    for (final r in rounds) {
      var bout = cup.bouts[r];
      final team = env['LADDER_TEAM']?.split(',').map((t) {
        final fe = t.split(':');
        return (fe[0], fe[1]);
      }).toList();
      if ((overrides != null && r < overrides.length) || team != null) {
        final pe = overrides != null && r < overrides.length
            ? overrides[r].split(':').map(int.parse).toList()
            : [bout.potential, bout.enhancement];
        bout = GemBout(
          id: bout.id,
          name: bout.name,
          place: bout.place,
          level: bout.level,
          team: team ?? bout.team,
          potential: pe[0],
          enhancement: pe.length > 1 ? pe[1] : 0,
        );
      }
      final rival = ladderTeamFor(catalog, bout, sprites: false);
      final cells = <String>[];
      var lengths = 0.0;
      for (final (p, e) in setups) {
        var wins = 0;
        for (var i = 0; i < n; i++) {
          // The same draws at every breeding.
          final rng = Random(1000 * r + i);
          final shuffled = List.of(pool)..shuffle(rng);
          final families = <String>{};
          final mine = <CosmicPartyMember>[];
          for (final c in shuffled) {
            if (mine.length == 4) break;
            if (!families.add(c.mutationFamily!.toLowerCase())) continue;
            mine.add(
              ladderMember(
                c,
                potential: p,
                enhancement: e,
                id: 'mine:$i:${mine.length}',
                slot: mine.length,
                sprites: false,
              ),
            );
          }
          final (game, center) = await battleArena();
          final b = game.startBattle(
            home: mine,
            away: rival,
            homeAuto: true,
            center: center,
          );
          runBattle(game);
          if (env['LADDER_TRACE'] == '1' &&
              i == 0 &&
              p == bout.potential &&
              e == bout.enhancement) {
            String who(BattleEvent ev) {
              final m = (ev.side == 0 ? mine : rival)[ev.creature];
              return '${m.element} ${m.family}';
            }

            stdout.writeln(
              '  ${bout.id}: winner ${b.result?.winner} by '
              '${b.result?.end.name} at ${b.result?.at.toStringAsFixed(1)} s',
            );
            for (final ev in b.log) {
              stdout.writeln(
                '    ${ev.at.toStringAsFixed(2).padLeft(6)}  '
                '${ev.side == 0 ? 'mine ' : 'rival'}  '
                '${ev.kind.name.padRight(8)} ${who(ev)}',
              );
            }
          }
          if (b.result?.winner == 0) wins++;
          lengths += b.result?.at ?? 0;
        }
        cells.add('${(100 * wins / n).round()}%'.padLeft(9));
      }
      stdout.writeln(
        '${'${r + 1} ${bout.id} P${bout.potential}e${bout.enhancement}'.padRight(18)}'
        '${cells.join()}   avg ${(lengths / (n * setups.length)).toStringAsFixed(0)} s',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));

  // Which species carry a fight at a breeding: random fours against random
  // fours, every species' share of the fights its side won.
  //
  //   LADDER_SPECIES=95:10 [LADDER_N=400] flutter test \
  //     test/gem_battle_ladder_test.dart --plain-name 'species balance'
  test('species balance', () async {
    final env = Platform.environment;
    final at = env['LADDER_SPECIES'];
    if (at == null) return;
    final pe = at.split(':').map(int.parse).toList();
    final n = int.tryParse(env['LADDER_N'] ?? '') ?? 400;
    final pool = catalog.creatures
        .where(
          (c) =>
              c.baseStats != null &&
              c.types.isNotEmpty &&
              (c.mutationFamily ?? '').isNotEmpty &&
              c.mutationFamily!.toLowerCase() != 'mystic',
        )
        .toList();
    final rng = Random(5);
    List<CosmicPartyMember> four(String side) {
      final shuffled = List.of(pool)..shuffle(rng);
      final families = <String>{};
      final out = <CosmicPartyMember>[];
      for (final c in shuffled) {
        if (out.length == 4) break;
        if (!families.add(c.mutationFamily!.toLowerCase())) continue;
        out.add(
          ladderMember(
            c,
            potential: pe[0],
            enhancement: pe.length > 1 ? pe[1] : 0,
            id: '$side:${out.length}:${c.id}',
            slot: out.length,
            sprites: false,
          ),
        );
      }
      return out;
    }

    final won = <String, double>{}, played = <String, int>{};
    final famWon = <String, double>{}, famPlayed = <String, int>{};
    var lengths = 0.0;
    for (var i = 0; i < n; i++) {
      final home = four('h'), away = four('a');
      final (game, center) = await battleArena();
      final b = game.startBattle(
        home: home,
        away: away,
        homeAuto: true,
        center: center,
      );
      runBattle(game);
      lengths += b.result?.at ?? 0;
      final w = b.result?.winner;
      for (final (side, team) in [(0, home), (1, away)]) {
        final score = w == null ? 0.5 : (w == side ? 1.0 : 0.0);
        for (final m in team) {
          final k = '${m.element} ${m.family}';
          won[k] = (won[k] ?? 0) + score;
          played[k] = (played[k] ?? 0) + 1;
          famWon[m.family] = (famWon[m.family] ?? 0) + score;
          famPlayed[m.family] = (famPlayed[m.family] ?? 0) + 1;
        }
      }
    }
    stdout.writeln(
      'P${pe[0]}e${pe.length > 1 ? pe[1] : 0}: $n fights, '
      'avg ${(lengths / n).toStringAsFixed(0)} s',
    );
    final fams = famWon.keys.toList()
      ..sort((a, b) => (famWon[b]! / famPlayed[b]!).compareTo(
        famWon[a]! / famPlayed[a]!,
      ));
    stdout.writeln(
      fams
          .map(
            (f) =>
                '$f ${(100 * famWon[f]! / famPlayed[f]!).round()}%',
          )
          .join(' · '),
    );
    final keys = won.keys.where((k) => played[k]! >= 8).toList()
      ..sort((a, b) => (won[b]! / played[b]!).compareTo(won[a]! / played[a]!));
    for (final k in [...keys.take(12), '…', ...keys.reversed.take(8)]) {
      if (k == '…') {
        stdout.writeln('  …');
        continue;
      }
      stdout.writeln(
        '  ${k.padRight(18)} ${(100 * won[k]! / played[k]!).round()}%'
        '  of ${played[k]}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
