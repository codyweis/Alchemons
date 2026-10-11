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

/// Where each stat band meets its wall. A report, not a gate.
///
/// Survival is meant to be a grind: better-bred, better-enhanced Alchemons go
/// further (docs/survival_stat_walls.md has the targets and the history).
/// This drives the wave-50 benchmark party at a range of Potentials and
/// Enhancement ranks, jumps straight to each wave and reports whether it held.
///
/// Only ordinary horde waves are sampled. Boss waves cap the field at 24
/// bodies, so they are easier than the waves either side and say nothing
/// about the wall.
///
///   WALL_BANDS=P70,P100E10 WALL_WAVES=36,41,46 \
///   flutter test test/survival_stat_wall_report_test.dart --tags preview
///
/// Bands default to P50..P100E10 and waves to every fifth non-boss wave from
/// 31; a band stops at the first wave every seed dies on. Bands run
/// one after another — split them across processes to go faster.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bands = (Platform.environment['WALL_BANDS'] ??
          'P50,P70,P80,P90,P100,P100E10')
      .split(',');
  final waves = (Platform.environment['WALL_WAVES'] ??
          '31,36,41,46,51,56,61,66,71,76,81,86,91')
      .split(',')
      .map(int.parse)
      .toList();
  const seeds = [7, 19, 29];

  test('survival stat walls', () async {
    for (final band in bands) {
      final m = RegExp(r'^P(\d+)(?:E(\d+))?$').firstMatch(band)!;
      final potential = int.parse(m.group(1)!);
      final enhancement = int.parse(m.group(2) ?? '0');
      for (final wave in waves) {
        final outcomes = <String>[
          for (final seed in seeds)
            await _hold(potential, enhancement, wave, seed),
        ];
        // ignore: avoid_print
        print('$band  wave $wave  ${outcomes.join(' | ')}');
        if (outcomes.every((o) => o.startsWith('DIED'))) break;
      }
    }
  }, timeout: const Timeout(Duration(hours: 2)));
}

/// The benchmark party (survival_wave50_potential_test), at level 10 with
/// [potential] in every stat and [enhancement] ranks on every stat.
List<CosmicPartyMember> _party(int potential, int enhancement) {
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final creatures = (data['creatures'] as List).cast<Map<String, dynamic>>();
  const ids = ['PIP01', 'HOR02', 'MAN04', 'MSK12', 'LET02'];
  return [
    for (var i = 0; i < ids.length; i++)
      (() {
        final row = creatures.firstWhere((c) => c['id'] == ids[i]);
        final base = row['baseStats'] as Map<String, dynamic>;
        double stat(String key) => AlchemonStatSystem.effectiveInternal(
          speciesBase: base[key] as int,
          level: 10,
          potential: potential,
          enhancementRank: enhancement,
        );
        return CosmicPartyMember(
          instanceId: 'wall_$i',
          baseId: ids[i],
          displayName: row['name'] as String,
          family: row['mutationFamily'] as String,
          element: (row['types'] as List).first as String,
          level: 10,
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

/// One wave from a cold start with the benchmark's twenty picks and the same
/// simple pilot. Returns `ok <s> orb<%>`, `DIED@<s>` or `TIMEOUT orb<%>`.
Future<String> _hold(int potential, int enhancement, int wave, int seed) async {
  final game = CosmicSurvivalGame(
    party: _party(potential, enhancement),
    random: Random(seed),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  void pick(String id, {int? slot}) => game.applyPowerUp(
    kAllPowerUps.firstWhere((def) => def.id == id),
    targetSlot: slot,
  );
  for (var i = 0; i < 4; i++) {
    pick('pack_leader');
  }
  for (var i = 0; i < 5; i++) {
    pick('strength_up', slot: i);
  }
  pick('orb_vitality');
  pick('orb_vitality');
  pick('lifesteal', slot: 0);
  for (var i = 0; i < 2; i++) {
    pick('auto_turret');
    pick('regen_field');
  }
  pick('mirror_shield');
  pick('command_strength');
  pick('command_intelligence');
  pick('command_speed');
  game.startGame();
  for (var w = 1; w < wave; w++) {
    game.spawner.resumeAfterIntermission();
  }
  for (var i = 0; i < 5; i++) {
    game.summonCompanion(i);
  }
  game.clearCompanionTether();

  var elapsed = 0.0;
  while (!game.isGameOver &&
      game.spawner.currentWave == wave &&
      elapsed < 300) {
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
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
    game.update(1 / 30);
    elapsed += 1 / 30;
  }
  final orb = (100 * game.orb.currentHp / game.orb.maxHp).round();
  if (game.isGameOver) return 'DIED@${elapsed.round()}s';
  if (game.spawner.currentWave > wave) return 'ok ${elapsed.round()}s orb$orb%';
  return 'TIMEOUT orb$orb%';
}
