@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a fresh team falls in a real run. A report with a check.
///
/// The stat walls (survival_stat_wall_report_test) jump a level-10 party to
/// a wave with twenty picks already taken. This plays the run the way a new
/// player does: the benchmark species (PIP01, HOR02, MAN04, MSK12, LET02) at
/// Potential 50, no Guardian upgrades or masteries, from wave 1. One
/// Alchemon starts on the field; drafts are taken as they open, in the
/// order of the stat-wall benchmark's own twenty picks (Pack Leader, then
/// Strength, the orb's turret, regen and vitality, Mirror Shield, the
/// commands), and each new slot is filled from the bench. The pilot is the
/// stat-wall one.
///
/// Target (2026-10-10): level 1 falls around wave 8–10, level 5 around
/// 15–18, level 10 at 25 or later, and the spread comes from level, not
/// luck. Checked on the mean of 16 seeds: level 1 8–10.5, level 5 14–19,
/// level 10 23 or later.
///
///   flutter test test/survival_fresh_team_wall_report_test.dart --tags preview
///
/// FRESH_LEVELS (default 1,5,10) and FRESH_SEEDS (default: 16 seeds) narrow
/// or widen it; FRESH_DRAFTS=skip dismisses every draft instead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final levels = (env['FRESH_LEVELS'] ?? '1,5,10')
      .split(',')
      .map(int.parse)
      .toList();
  final seeds =
      (env['FRESH_SEEDS'] ??
              '7,19,29,41,53,67,83,97,101,202,303,404,505,606,707,808')
          .split(',')
          .map(int.parse)
          .toList();
  final takeDrafts = env['FRESH_DRAFTS'] != 'skip';

  test('fresh team walls', () async {
    final means = <int, double>{};
    for (final level in levels) {
      final waves = <int>[
        for (final seed in seeds) await _fall(level, seed, takeDrafts),
      ];
      means[level] = waves.reduce((a, b) => a + b) / waves.length;
      // ignore: avoid_print
      print(
        'L$level P50 ${takeDrafts ? 'drafts' : 'no drafts'}: falls on '
        '${waves.join(', ')} (mean ${means[level]!.toStringAsFixed(1)})',
      );
    }
    if (!takeDrafts) return;
    if (means.containsKey(1)) {
      expect(means[1], inInclusiveRange(8.0, 10.5));
    }
    if (means.containsKey(5)) {
      expect(means[5], inInclusiveRange(14.0, 19.0));
    }
    if (means.containsKey(10)) {
      expect(means[10], greaterThanOrEqualTo(23.0));
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

List<CosmicPartyMember> _party(int level) {
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final creatures = (data['creatures'] as List).cast<Map<String, dynamic>>();
  const ids = ['PIP01', 'HOR02', 'MAN04', 'MSK12', 'LET02'];
  const potential = 50;
  return [
    for (var i = 0; i < ids.length; i++)
      (() {
        final row = creatures.firstWhere((c) => c['id'] == ids[i]);
        final base = row['baseStats'] as Map<String, dynamic>;
        double stat(String key) => AlchemonStatSystem.effectiveInternal(
          speciesBase: base[key] as int,
          level: level,
          potential: potential,
        );
        return CosmicPartyMember(
          instanceId: 'fresh_$i',
          baseId: ids[i],
          displayName: row['name'] as String,
          family: row['mutationFamily'] as String,
          element: (row['types'] as List).first as String,
          level: level,
          slotIndex: i,
          statSpeed: stat('speed'),
          statIntelligence: stat('intelligence'),
          statStrength: stat('strength'),
          statBeauty: stat('beauty'),
          statSpeedPotential: potential.toDouble(),
          statIntelligencePotential: potential.toDouble(),
          statStrengthPotential: potential.toDouble(),
          statBeautyPotential: potential.toDouble(),
          staminaBars: 3,
          staminaMax: 3,
        );
      })(),
  ];
}

/// The draft order: the stat-wall benchmark's own picks first, in about the
/// proportions it takes them, then the plain stats.
const _draftOrder = [
  'pack_leader',
  'strength_up',
  'auto_turret',
  'regen_field',
  'orb_vitality',
  'mirror_shield',
  'command_strength',
  'command_intelligence',
  'command_speed',
  'lifesteal',
  'intelligence_up',
  'speed_up',
  'elemental_fury',
  'double_cast',
];

/// The wave the run's orb gives out on (or 40 if it never does).
Future<int> _fall(int level, int seed, bool takeDrafts) async {
  final party = _party(level);
  final game = CosmicSurvivalGame(
    party: party,
    random: Random(seed),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.startGame();
  game.summonCompanion(0);
  game.clearCompanionTether();

  var elapsed = 0.0;
  while (!game.isGameOver && elapsed < 3000 && game.spawner.currentWave < 40) {
    // Keep the field full from the bench.
    final alive = game.activeCompanions.values.where((c) => !c.isDead).length;
    if (alive < game.maxActiveCompanions) {
      for (var i = 0; i < party.length; i++) {
        if (game.activeCompanions.containsKey(i) ||
            game.defeatedCompanionSlots.contains(i)) {
          continue;
        }
        game.summonCompanion(i);
        game.clearCompanionTether();
        break;
      }
    }

    // The stat-wall pilot: guard the orb, purge sources, else the nearest.
    Offset? target;
    var best = double.infinity;
    for (final enemy in game.enemies) {
      if (enemy.isDead) continue;
      final orbDistance = (enemy.position - game.orb.position).distance;
      final score = !enemy.isPlagueCore && orbDistance < 300
          ? orbDistance - 2000
          : enemy.isPlagueCore
          ? -1000.0
          : orbDistance;
      if (score < best) {
        best = score;
        target = enemy.position;
      }
    }
    target ??= game.activeBoss?.position ?? game.orb.position;
    final delta = target - game.ship.position;
    final tangent = delta.distance > 0
        ? Offset(-delta.dy, delta.dx) / delta.distance
        : Offset.zero;
    game.setJoystickInput(
      delta.distance > 170 ? delta / delta.distance : tangent,
    );

    if (game.showingPowerUpSelection) {
      final wave = game.spawner.currentWave;
      // The same draft the screen offers.
      final choices = !takeDrafts
          ? const <OfferedPowerUpChoice>[]
          : !game.powerUps.hasKeystone && wave >= 10
          ? generateKeystoneChoices(game.powerUps, wave, party: party)
          : generatePowerUpChoices(
              game.powerUps,
              wave,
              party: party,
              defeatedCompanionSlots: game.defeatedCompanionSlots,
            );
      if (choices.isEmpty) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      } else {
        var choice = choices.first;
        var rank = _draftOrder.length;
        for (final c in choices) {
          final r = _draftOrder.indexOf(c.def.id);
          if (r >= 0 && r < rank) {
            rank = r;
            choice = c;
          }
        }
        game.applyPowerUp(
          choice.def,
          targetSlot: choice.targetSlot,
          targetName: choice.targetName,
        );
      }
    }
    game.update(1 / 30);
    elapsed += 1 / 30;
  }
  return game.spawner.currentWave;
}
