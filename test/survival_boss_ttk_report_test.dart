@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// How long each survival boss lives. A report, not a gate.
///
/// Drives the stat-wall benchmark party (survival_stat_wall_report_test) at
/// a stat band, jumps to each boss wave with about one pick per wave so far
/// (the meter opens a draft roughly once a wave), and times every boss from
/// the moment it is on the field to its death.
///
///   BOSS_BANDS=P50L5,P70,P100 BOSS_WAVES=5,10,20 \
///   flutter test test/survival_boss_ttk_report_test.dart --tags preview
///
/// A band is `P<potential>` with an optional `E<enhancement>` and
/// `L<level>` (level 10 when left out).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final bands = (Platform.environment['BOSS_BANDS'] ?? 'P50L5,P70,P100')
      .split(',');
  final waves = (Platform.environment['BOSS_WAVES'] ?? '5,10,15,20,25,30,40')
      .split(',')
      .map(int.parse)
      .toList();
  final seeds = (Platform.environment['BOSS_SEEDS'] ?? '7,19')
      .split(',')
      .map(int.parse)
      .toList();

  test('survival boss time to kill', () async {
    for (final band in bands) {
      final m = RegExp(r'^P(\d+)(?:E(\d+))?(?:L(\d+))?$').firstMatch(band)!;
      final potential = int.parse(m.group(1)!);
      final enhancement = int.parse(m.group(2) ?? '0');
      final level = int.parse(m.group(3) ?? '10');
      for (final wave in waves) {
        final outcomes = <String>[
          for (final seed in seeds)
            await _fight(potential, enhancement, level, wave, seed),
        ];
        // ignore: avoid_print
        print('$band  wave $wave  ${outcomes.join(' | ')}');
      }
    }
  }, timeout: const Timeout(Duration(hours: 2)));
}

List<CosmicPartyMember> _party(int potential, int enhancement, int level) {
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
          level: level,
          potential: potential,
          enhancementRank: enhancement,
        );
        return CosmicPartyMember(
          instanceId: 'boss_$i',
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

/// The benchmark's twenty picks, in the order a run might take them.
const _picks = <(String, int?)>[
  ('strength_up', 0),
  ('pack_leader', null),
  ('strength_up', 1),
  ('orb_vitality', null),
  ('strength_up', 2),
  ('auto_turret', null),
  ('pack_leader', null),
  ('strength_up', 3),
  ('regen_field', null),
  ('strength_up', 4),
  ('command_strength', null),
  ('pack_leader', null),
  ('lifesteal', 0),
  ('auto_turret', null),
  ('orb_vitality', null),
  ('command_intelligence', null),
  ('pack_leader', null),
  ('regen_field', null),
  ('mirror_shield', null),
  ('command_speed', null),
];

/// One boss wave from a cold start. Returns each boss's life in seconds
/// (`hp` in thousands after it), then how the wave ended.
Future<String> _fight(
  int potential,
  int enhancement,
  int level,
  int wave,
  int seed,
) async {
  final game = CosmicSurvivalGame(
    party: _party(potential, enhancement, level),
    random: Random(seed),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  for (final (id, slot) in _picks.take(min(wave - 1, _picks.length))) {
    game.applyPowerUp(
      kAllPowerUps.firstWhere((def) => def.id == id),
      targetSlot: slot,
    );
  }
  game.startGame();
  for (var w = 1; w < wave; w++) {
    game.spawner.resumeAfterIntermission();
  }
  for (var i = 0; i < 5; i++) {
    game.summonCompanion(i);
  }
  game.clearCompanionTether();

  final born = <SurvivalBoss, double>{};
  final lived = <SurvivalBoss, double>{};
  // When each boss fell past three quarters, half and a quarter of its
  // health, and how many other bodies were still up then.
  final marks = <SurvivalBoss, List<String>>{};
  var elapsed = 0.0;
  while (!game.isGameOver &&
      game.spawner.currentWave == wave &&
      elapsed < 300) {
    for (final boss in [?game.activeBoss, ...game.extraBosses]) {
      born.putIfAbsent(boss, () => elapsed);
    }
    for (final boss in born.keys) {
      if (lived.containsKey(boss)) continue;
      final gone =
          boss.isDead ||
          boss.hp <= 0 ||
          (game.activeBoss != boss && !game.extraBosses.contains(boss));
      if (gone) lived[boss] = elapsed - born[boss]!;
      final m = marks.putIfAbsent(boss, () => []);
      if (m.length < 3 && boss.hp / boss.maxHp <= 0.75 - 0.25 * m.length) {
        final others = game.enemies.where((e) => !e.isDead).length;
        m.add('${(elapsed - born[boss]!).toStringAsFixed(1)}/$others');
      }
    }
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
  // The wave ends on the frame its last boss dies, before the loop sees it.
  for (final boss in born.keys) {
    if (!lived.containsKey(boss) && (boss.isDead || boss.hp <= 0 ||
        game.spawner.currentWave > wave)) {
      lived[boss] = elapsed - born[boss]!;
    }
  }
  final bosses = [
    for (final boss in born.keys)
      '@${born[boss]!.round()} '
      '${lived[boss]?.toStringAsFixed(1) ?? 'alive'}s'
          '(${(boss.maxHp / 1000).toStringAsFixed(1)}k'
          '${boss.template.isTitanic ? ' titan' : ''})'
          '${Platform.environment['BOSS_CURVE'] == null ? '' : '[${marks[boss]?.join(' ')}]'}',
  ].join(' ');
  final orb = (100 * game.orb.currentHp / game.orb.maxHp).round();
  final end = game.isGameOver
      ? 'DIED@${elapsed.round()}s'
      : game.spawner.currentWave > wave
      ? 'clear ${elapsed.round()}s orb$orb%'
      : 'TIMEOUT orb$orb%';
  return '$bosses  $end';
}
