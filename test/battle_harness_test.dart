// The PvP battle harness: runs computer-against-computer fights and prints
// how they go, to tune the battle against before any screen is built.
//
//   BATTLE_REPORT=1 flutter test test/battle_harness_test.dart
//     [BATTLE_SCALE=0.85]  damage scale on top of the duel's (the game's)
//     [BATTLE_GRACE=1]     keep open space's hit grace window
//     [BATTLE_OT=60,0.5,1.6] overtime: from, heal share, damage at the end
//     [BATTLE_N=200]       fights in the mixed table
//     [BATTLE_ONLY=trace|families|stats|output]
//     [BATTLE_STAT=6]      every stat of the output table's pairs (3 is
//                          about P50 on an average species, 6 about P80)
//     [FAMILY_TRY=...]     family numbers tried (family_frame_trials.dart)
//
// Not a gate: with no BATTLE_REPORT it runs one fight and checks it ends.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/games/stadium/battle_ladder.dart';
import 'package:alchemons/games/shared/battle_typing.dart';
import 'package:alchemons/models/creature.dart';
import 'package:flutter_test/flutter_test.dart';

import 'battle_test.dart' show battleArena, battleMember, runBattle;
import 'family_frame_trials.dart';

const _families = ['Horn', 'Wing', 'Let', 'Pip', 'Mane', 'Mask', 'Kin'];

/// The catalog's species by family (no Mystics), for BATTLE_P.
Map<String, List<Creature>> _catalogSpecies() {
  final json =
      jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync())
          as Map<String, dynamic>;
  final out = <String, List<Creature>>{};
  for (final c in json['creatures'] as List) {
    final s = Creature.fromJson(c as Map<String, dynamic>);
    final f = s.mutationFamily;
    if (f == null || !_families.contains(f) || s.baseStats == null) continue;
    if (s.types.isEmpty) continue;
    out.putIfAbsent(f, () => []).add(s);
  }
  return out;
}
const _elements = [
  'Fire', 'Water', 'Earth', 'Air', 'Plant', 'Ice', 'Lightning', 'Poison',
  'Steam', 'Lava', 'Mud', 'Dust', 'Crystal', 'Spirit', 'Dark', 'Light',
  'Blood',
];

class _Fight {
  _Fight(
    this.result,
    this.log,
    this.homeShare,
    this.awayShare, {
    this.standing = '',
  });

  /// Who was on the field at the end, with health: for reading stalls.
  final String standing;
  final BattleResult result;
  final List<BattleEvent> log;
  final double homeShare;
  final double awayShare;

  int specials(int side) =>
      log.where((e) => e.side == side && e.kind == BattleEventKind.special).length;
  int falls(int side) =>
      log.where((e) => e.side == side && e.kind == BattleEventKind.fall).length;
  double? firstFall() {
    for (final e in log) {
      if (e.kind == BattleEventKind.fall) return e.at;
    }
    return null;
  }

  /// Both of a side's places emptied within half a second of each other.
  bool get doubleKo {
    for (final side in [0, 1]) {
      final falls = [
        for (final e in log)
          if (e.side == side && e.kind == BattleEventKind.fall) e.at,
      ];
      for (var i = 1; i < falls.length; i++) {
        if (falls[i] - falls[i - 1] < 0.5) return true;
      }
    }
    return false;
  }
}

Future<_Fight> _fight(
  List<CosmicPartyMember> home,
  List<CosmicPartyMember> away, {
  double scale = 1.0,
  bool trace = false,
}) async {
  final (game, center) = await battleArena();
  final b = game.startBattle(
    home: home,
    away: away,
    homeAuto: true,
    center: center,
    damageScale: scale,
    hitGrace: Platform.environment['BATTLE_GRACE'] == '1',
    overtime: _overtime,
  );
  var next = 0.0;
  runBattle(
    game,
    each: trace
        ? () {
            if (b.clock < next) return;
            next += 2.0;
            String side(int i) => [
              for (var s = 0; s < kBattleFieldSpots; s++)
                if (b.sides[i].at(s) case final c?)
                  '${c.member.element[0]}${c.member.family.substring(0, 2)} '
                      '${c.body!.currentHp}/${c.body!.maxHp}'
                else
                  '—',
            ].join(', ');
            stdout.writeln(
              '  t=${b.clock.toStringAsFixed(1).padLeft(5)}  '
              'home [${side(0)}]  away [${side(1)}]',
            );
          }
        : null,
  );
  final c = b.counts;
  _strategy
    ..burns += c.burns
    ..poisonHarm += c.poisonHarm
    ..healCut += c.healCut
    ..interrupts += c.interrupts
    ..tauntSeconds += c.tauntSeconds
    ..typeUp += c.typeUp
    ..typeDown += c.typeDown;
  _strategyFights++;
  String side(int i) => [
    for (final c in b.sides[i].onField)
      '${c.member.element} ${c.member.family} '
          '${(c.healthShare * 100).round()}%'
          '${c.body!.shieldHp > 0 ? '+sh' : ''}',
  ].join(' & ');
  return _Fight(
    b.result!,
    List.of(b.log),
    b.sides[0].healthShare,
    b.sides[1].healthShare,
    standing: '${side(0)}  vs  ${side(1)}',
  );
}

/// How often the strategy rules came into the fights since the last reset
/// (cosmic_game_battle_status.dart).
var _strategy = BattleStrategyCount();
var _strategyFights = 0;

/// BATTLE_OT=at,heal,damage tries an overtime (e.g. 60,0.5,1.6).
BattleOvertime get _overtime {
  final raw = Platform.environment['BATTLE_OT'];
  if (raw == null) return kBattleOvertime;
  final v = raw.split(',').map(double.parse).toList();
  return BattleOvertime(at: v[0], heal: v[1], damage: v[2]);
}

double get _scale =>
    double.tryParse(Platform.environment['BATTLE_SCALE'] ?? '') ??
    kBattleDamageScale;

bool _only(String part) {
  final only = Platform.environment['BATTLE_ONLY'];
  return only == null || only.split(',').contains(part);
}

String _pct(num v) => '${(v * 100).round()}%'.padLeft(4);

void main() {
  final report = Platform.environment['BATTLE_REPORT'] == '1';

  test('a fight ends', () async {
    final f = await _fight(
      [battleMember('Horn', 'Fire'), battleMember('Wing', 'Air')],
      [battleMember('Kin', 'Water'), battleMember('Pip', 'Earth')],
      scale: _scale,
      trace: report && _only('trace'),
    );
    if (report) {
      stdout.writeln(
        'trace: winner ${f.result.winner} by ${f.result.end.name} at '
        '${f.result.at.toStringAsFixed(1)} s; specials ${f.specials(0)}/'
        '${f.specials(1)}; falls ${f.falls(0)}/${f.falls(1)}',
      );
      for (final e in f.log) {
        stdout.writeln(
          '  ${e.at.toStringAsFixed(2).padLeft(6)}  side ${e.side}  '
          '${e.kind.name}  #${e.creature}',
        );
      }
    }
    expect(f.result.at, lessThanOrEqualTo(kBattleTimeLimit + 0.1));
  });

  test(
    'family pairs: every family pair against every other',
    () async {
      if (!_only('families')) return;
      final tried = applyFamilyTrials();
      // Pairs of one family (two elements), so a family's own shape shows.
      // BATTLE_P=80 draws real catalog species bred to it instead of even
      // stats; BATTLE_R the fights per pairing (2).
      final rng = Random(7);
      final bred = int.tryParse(Platform.environment['BATTLE_P'] ?? '');
      final species = bred == null ? null : _catalogSpecies();
      List<CosmicPartyMember> pair(String family) {
        if (species != null) {
          final pool = species[family]!;
          final a = pool[rng.nextInt(pool.length)];
          var b = pool[rng.nextInt(pool.length)];
          while (b == a && pool.length > 1) {
            b = pool[rng.nextInt(pool.length)];
          }
          return [
            for (final (i, c) in [a, b].indexed)
              ladderMember(
                c,
                potential: bred!,
                id: '$family-$i-${c.id}',
                slot: i,
                sprites: false,
              ),
          ];
        }
        final e = List.of(_elements)..shuffle(rng);
        return [
          battleMember(family, e[0], id: '$family-a-${e[0]}'),
          battleMember(family, e[1], id: '$family-b-${e[1]}'),
        ];
      }

      final rounds =
          int.tryParse(Platform.environment['BATTLE_R'] ?? '') ?? 2;

      final wins = {for (final f in _families) f: 0.0};
      final games = {for (final f in _families) f: 0};
      final lengths = <double>[];
      var timeUps = 0, draws = 0, doubleKos = 0, n = 0;
      var specials = 0;
      for (final a in _families) {
        for (final c in _families) {
          if (a == c) continue;
          for (var r = 0; r < rounds; r++) {
            final f = await _fight(pair(a), pair(c), scale: _scale);
            n++;
            lengths.add(f.result.at);
            specials += f.specials(0) + f.specials(1);
            if (f.result.end == BattleEnd.timeUp) timeUps++;
            if (f.doubleKo) doubleKos++;
            games[a] = games[a]! + 1;
            games[c] = games[c]! + 1;
            switch (f.result.winner) {
              case 0:
                wins[a] = wins[a]! + 1;
              case 1:
                wins[c] = wins[c]! + 1;
              default:
                draws++;
                wins[a] = wins[a]! + 0.5;
                wins[c] = wins[c]! + 0.5;
            }
          }
        }
      }
      lengths.sort();
      stdout.writeln(
        'families (scale $_scale, $n fights, 2v2, no bench'
        '${bred == null ? '' : ', species at P$bred'})'
        '${tried.isEmpty ? '' : ' tried $tried'}:',
      );
      for (final f in _families) {
        stdout.writeln('  ${f.padRight(5)} ${_pct(wins[f]! / games[f]!)}');
      }
      stdout.writeln(
        '  length median ${lengths[lengths.length ~/ 2].toStringAsFixed(1)} s, '
        'p10 ${lengths[lengths.length ~/ 10].toStringAsFixed(1)}, '
        'p90 ${lengths[lengths.length * 9 ~/ 10].toStringAsFixed(1)}; '
        'time-ups $timeUps, draws $draws, double KOs $doubleKos, '
        'specials/fight ${(specials / n).toStringAsFixed(1)}',
      );
    },
    skip: report ? false : 'BATTLE_REPORT=1 prints the family table',
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'stats: how often the stronger side wins',
    () async {
      if (!_only('stats')) return;
      final rng = Random(11);
      List<CosmicPartyMember> team(double stat, String tag) {
        final fams = List.of(_families)..shuffle(rng);
        final els = List.of(_elements)..shuffle(rng);
        return [
          for (var i = 0; i < 4; i++)
            battleMember(fams[i], els[i], stat: stat, id: '$tag-$i'),
        ];
      }

      stdout.writeln('stats (scale $_scale, 4 v 4 with bench, mixed teams):');
      for (final gap in [0.0, 0.25, 0.5, 1.0]) {
        var strong = 0.0;
        const n = 16;
        for (var i = 0; i < n; i++) {
          final f = await _fight(
            team(3.0 + gap, 's$i'),
            team(3.0, 'w$i'),
            scale: _scale,
          );
          strong += switch (f.result.winner) {
            0 => 1.0,
            1 => 0.0,
            _ => 0.5,
          };
        }
        stdout.writeln('  +${gap.toStringAsFixed(2)} stat: stronger wins '
            '${_pct(strong / n)}');
      }
    },
    skip: report ? false : 'BATTLE_REPORT=1 prints the stat table',
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'matchups: one element against another, the same four families',
    () async {
      if (!report || !_only('matchups')) return;
      // BATTLE_MATCHUPS=Water:Fire,Fire:Plant,... ; BATTLE_R fights each.
      final pairs = (Platform.environment['BATTLE_MATCHUPS'] ??
              'Water:Fire,Fire:Plant,Earth:Lightning,Dark:Light,Water:Water')
          .split(',');
      final rounds =
          int.tryParse(Platform.environment['BATTLE_R'] ?? '') ?? 30;
      // BATTLE_TYPING=0: the same fights with typing off, to compare.
      battleTypingOn = Platform.environment['BATTLE_TYPING'] != '0';
      final four = (Platform.environment['BATTLE_FOUR'] ?? 'Horn,Wing,Kin,Pip')
          .split(',');
      stdout.writeln(
        'matchups (scale $_scale, $rounds fights each way, families $four):',
      );
      for (final pair in pairs) {
        final [a, c] = pair.split(':');
        var aWins = 0.0;
        for (var r = 0; r < rounds; r++) {
          // Each team on each side half the time.
          final flip = r.isOdd;
          // A little spread in stats, so the fights are not all one fight.
          final rng = Random(r * 31 + pair.hashCode);
          double stat() => 3.6 + rng.nextDouble() * 0.8;
          final teamA = [
            for (final (i, f) in four.indexed)
              battleMember(f, a, stat: stat(), id: 'a$i$f$r'),
          ];
          final teamC = [
            for (final (i, f) in four.indexed)
              battleMember(f, c, stat: stat(), id: 'c$i$f$r'),
          ];
          final f = await _fight(
            flip ? teamC : teamA,
            flip ? teamA : teamC,
            scale: _scale,
          );
          final w = f.result.winner;
          final aSide = flip ? 1 : 0;
          if (w == aSide) aWins += 1;
          if (w == null) aWins += 0.5;
        }
        stdout.writeln(
          '  $a vs $c: $a wins ${_pct(aWins / rounds)}',
        );
      }
      battleTypingOn = true;
    },
    timeout: const Timeout(Duration(minutes: 20)),
  );

  test(
    'mixed: random teams of four, with the bench and swaps',
    () async {
      if (!_only('mixed')) return;
      _strategy = BattleStrategyCount();
      _strategyFights = 0;
      final rng = Random(23);
      List<CosmicPartyMember> team(String tag) => [
        for (var i = 0; i < 4; i++)
          battleMember(
            _families[rng.nextInt(_families.length)],
            _elements[rng.nextInt(_elements.length)],
            id: '$tag-$i',
          ),
      ];
      final n = int.tryParse(Platform.environment['BATTLE_N'] ?? '') ?? 200;
      final score = {for (final f in _families) f: 0.0};
      final count = {for (final f in _families) f: 0};
      final lengths = <double>[];
      var timeUps = 0, draws = 0, doubleKos = 0, swaps = 0, phoenix = 0;
      var specials = 0;
      var benchUsed = 0;
      for (var i = 0; i < n; i++) {
        final home = team('h$i');
        final away = team('a$i');
        final f = await _fight(home, away, scale: _scale);
        lengths.add(f.result.at);
        if (f.result.end == BattleEnd.timeUp) {
          timeUps++;
          if (Platform.environment['BATTLE_STALLS'] == '1') {
            stdout.writeln('  stall: ${f.standing}');
          }
        }
        if (f.doubleKo) doubleKos++;
        swaps += f.log.where((e) => e.kind == BattleEventKind.swap).length;
        phoenix += f.log.where((e) => e.kind == BattleEventKind.phoenix).length;
        specials += f.specials(0) + f.specials(1);
        benchUsed += f.log.where((e) => e.kind == BattleEventKind.summon).length;
        final w = f.result.winner;
        for (final (side, t) in [(0, home), (1, away)]) {
          final s = w == null ? 0.5 : (w == side ? 1.0 : 0.0);
          for (final m in t) {
            score[m.family] = score[m.family]! + s;
            count[m.family] = count[m.family]! + 1;
          }
        }
        if (w == null) draws++;
      }
      lengths.sort();
      stdout.writeln(
        'mixed (scale $_scale, grace ${Platform.environment['BATTLE_GRACE'] == '1'}, '
        '$n fights, 4 v 4, 2 on the field):',
      );
      stdout.writeln('  win share of teams with each Alchemon of a family:');
      for (final f in _families) {
        stdout.writeln(
          '    ${f.padRight(5)} ${_pct(score[f]! / max(1, count[f]!))}',
        );
      }
      stdout.writeln(
        '  length median ${lengths[lengths.length ~/ 2].toStringAsFixed(1)} s, '
        'p10 ${lengths[lengths.length ~/ 10].toStringAsFixed(1)}, '
        'p90 ${lengths[lengths.length * 9 ~/ 10].toStringAsFixed(1)}; '
        'time-ups $timeUps, draws $draws, double KOs $doubleKos',
      );
      stdout.writeln(
        '  per fight: specials ${(specials / n).toStringAsFixed(1)}, '
        'bench summons ${(benchUsed / n).toStringAsFixed(1)}, '
        'swaps ${(swaps / n).toStringAsFixed(2)}, '
        'phoenix ${(phoenix / n).toStringAsFixed(2)}',
      );
      final per = max(1, _strategyFights);
      stdout.writeln(
        '  strategy per fight: burns ${(_strategy.burns / per).toStringAsFixed(1)}, '
        'heal cut ${(_strategy.healCut / per).round()} hp, '
        'poison harm ${(_strategy.poisonHarm / per).round()} hp, '
        'interrupts ${(_strategy.interrupts / per).toStringAsFixed(1)}, '
        'taunted ${(_strategy.tauntSeconds / per).toStringAsFixed(1)} s, '
        'typing +${(_strategy.typeUp / per).round()} / '
        '-${(_strategy.typeDown / per).round()} hp',
      );
    },
    skip: report ? false : 'BATTLE_REPORT=1 prints the mixed-team table',
    timeout: const Timeout(Duration(minutes: 30)),
  );

  test(
    'motion: where everyone goes, frame by frame',
    () async {
      if (!_only('motion')) return;
      // BATTLE_MOTION_OUT=file.csv: t, side, slot, family, x, y, facing
      // (+1 right), target distance, speed; and a summary of how the
      // movement reads: turns, flips, overlap, standing still.
      final (game, center) = await battleArena();
      final b = game.startBattle(
        home: [
          battleMember('Horn', 'Fire', id: 'h0'),
          battleMember('Wing', 'Air', id: 'h1'),
          battleMember('Kin', 'Water', id: 'h2'),
          battleMember('Pip', 'Lightning', id: 'h3'),
        ],
        away: [
          battleMember('Mane', 'Lava', id: 'a0'),
          battleMember('Mask', 'Plant', id: 'a1'),
          battleMember('Let', 'Ice', id: 'a2'),
          battleMember('Wing', 'Light', id: 'a3'),
        ],
        homeAuto: true,
        center: center,
        damageScale: _scale,
      );
      final rows = <String>['t,side,slot,family,x,y,facing,dist,speed'];
      final last = <CosmicCompanion, Offset>{};
      final lastVel = <CosmicCompanion, Offset>{};
      final lastFacing = <CosmicCompanion, bool>{};
      var frames = 0, flips = 0, sharpTurns = 0, still = 0, overlaps = 0;
      var pairs = 0;
      var speedSum = 0.0;
      const dt = 1 / 60;
      while (!b.over && b.clock < 40) {
        game.update(dt);
        final all = <(int, CosmicCompanion)>[
          for (final side in b.sides)
            for (final c in side.onField) (side.index, c.body!),
        ];
        for (final (side, comp) in all) {
          final p = comp.position - center;
          final prev = last[comp];
          final v = prev == null ? Offset.zero : (comp.position - prev) / dt;
          last[comp] = comp.position;
          final facing = comp.faceRight ?? cos(comp.angle) > 0;
          if (lastFacing[comp] case final f? when f != facing) flips++;
          lastFacing[comp] = facing;
          final pv = lastVel[comp];
          if (pv != null && pv.distance > 20 && v.distance > 20) {
            final turn = (atan2(v.dy, v.dx) - atan2(pv.dy, pv.dx)).abs();
            final t = turn > pi ? 2 * pi - turn : turn;
            if (t > pi / 2) sharpTurns++;
          }
          lastVel[comp] = v;
          if (v.distance < 5) still++;
          speedSum += v.distance;
          frames++;
          final foe = b.sides[1 - side];
          var nearest = double.infinity;
          for (final c in foe.onField) {
            nearest = min(nearest, (c.body!.position - comp.position).distance);
          }
          rows.add(
            '${b.clock.toStringAsFixed(3)},$side,${comp.member.slotIndex},'
            '${comp.member.family},${p.dx.toStringAsFixed(1)},'
            '${p.dy.toStringAsFixed(1)},${facing ? 1 : -1},'
            '${nearest.isFinite ? nearest.toStringAsFixed(1) : ''},'
            '${v.distance.toStringAsFixed(1)}',
          );
        }
        for (var i = 0; i < all.length; i++) {
          for (var j = i + 1; j < all.length; j++) {
            pairs++;
            if ((all[i].$2.position - all[j].$2.position).distance < 40) {
              overlaps++;
            }
          }
        }
      }
      final path = Platform.environment['BATTLE_MOTION_OUT'];
      if (path != null) File(path).writeAsStringSync(rows.join('\n'));
      final secs = frames * dt;
      stdout.writeln(
        'motion over ${b.clock.toStringAsFixed(1)} s ($frames creature-frames): '
        'facing flips ${(flips / secs).toStringAsFixed(2)}/creature-s, '
        'sharp turns ${(sharpTurns / secs).toStringAsFixed(2)}/creature-s, '
        'still ${_pct(still / frames)}, mean speed '
        '${(speedSum / frames).toStringAsFixed(0)} u/s, '
        'pairs closer than 40 ${_pct(overlaps / max(1, pairs))}',
      );
    },
    skip: report ? false : 'BATTLE_REPORT=1 prints the motion summary',
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'output: what each family deals and takes against a fixed pair',
    () async {
      if (!_only('output')) return;
      final tried = applyFamilyTrials();
      final stat =
          double.tryParse(Platform.environment['BATTLE_STAT'] ?? '') ?? 3;
      // Each family pair against two Earth Horns that never cast and are
      // healed to full every frame, so nothing dies, no shield soaks a hit,
      // and the numbers are rates.
      stdout.writeln(
        'output (scale $_scale, stat $stat, per second over 20 s, vs 2 '
        'Horns that never cast)${tried.isEmpty ? '' : ' tried $tried'}:',
      );
      stdout.writeln('  family   deals  takes   specials  (per element pair)');
      for (final family in _families) {
        final deals = <double>[];
        final takes = <double>[];
        var specials = 0;
        for (var k = 0; k < _elements.length; k += 2) {
          final e1 = _elements[k];
          final e2 = _elements[(k + 1) % _elements.length];
          final (game, center) = await battleArena();
          final b = game.startBattle(
            home: [
              battleMember(family, e1, stat: stat, id: '$family-$e1-a'),
              battleMember(family, e2, stat: stat, id: '$family-$e2-b'),
            ],
            away: [
              battleMember('Horn', 'Earth', stat: stat, id: 'ref-a'),
              battleMember('Horn', 'Earth', stat: stat, id: 'ref-b'),
            ],
            // BATTLE_NO_SPECIALS=1: auto attacks only, to see what the
            // specials add.
            homeAuto: Platform.environment['BATTLE_NO_SPECIALS'] != '1',
            awayAuto: false,
            center: center,
            damageScale: _scale,
            hitGrace: Platform.environment['BATTLE_GRACE'] == '1',
          );
          var dealt = 0.0;
          var taken = 0.0;
          var t = 0.0;
          const dt = 1 / 60;
          final last = <CosmicCompanion, int>{};
          while (t < 20 && !b.over) {
            game.update(dt);
            t += dt;
            for (final c in b.sides[1].onField) {
              final body = c.body!;
              dealt += body.maxHp - body.currentHp;
              body.currentHp = body.maxHp;
            }
            for (final c in b.sides[1].onField) {
              c.body!.shieldHp = 0;
            }
            for (final c in b.sides[0].onField) {
              final body = c.body!;
              final before = last[body] ?? body.maxHp;
              if (body.currentHp < before) taken += before - body.currentHp;
              last[body] = body.currentHp;
            }
          }
          deals.add(dealt / t);
          takes.add(taken / t);
          specials += b.log
              .where((e) => e.side == 0 && e.kind == BattleEventKind.special)
              .length;
        }
        String avg(List<double> v) =>
            (v.reduce((a, c) => a + c) / v.length).toStringAsFixed(1).padLeft(6);
        stdout.writeln(
          '  ${family.padRight(6)} ${avg(deals)} ${avg(takes)}   '
          '${(specials / deals.length).toStringAsFixed(1).padLeft(5)}     '
          '${[for (final d in deals) d.round()].join(' ')}',
        );
      }
    },
    skip: report ? false : 'BATTLE_REPORT=1 prints the output table',
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
