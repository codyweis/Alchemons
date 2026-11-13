@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/boss_roster_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// Where things go in a real run, written out as CSV so a path can be drawn
// and judged: every boss's place, the ship's and each Alchemon's, ten times
// a second, with the core at the origin.
//
//   MOTION_TRACE_OUT=/tmp/trace [MOTION_TRACE_WAVES=5,10,15] \
//   [MOTION_TRACE_SECONDS=45] [MOTION_TRACE_PARTY=Horn,Kin,Let,Mane,Wing] \
//   [MOTION_TRACE_TETHER=1] [MOTION_TRACE_SEED=11] \
//     flutter test test/survival_motion_trace_test.dart --tags preview
//
// Rows: t, what (boss/ship/comp), id, x, y, note.

CosmicPartyMember _member(String family, String element, int slot) =>
    CosmicPartyMember(
      instanceId: '$family-$element-$slot',
      baseId: '${family.substring(0, 3).toUpperCase()}01',
      displayName: '$element $family',
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 5,
      staminaMax: 5,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['MOTION_TRACE_OUT'];
  final waves = (Platform.environment['MOTION_TRACE_WAVES'] ?? '5,10,15,20,25,30,35')
      .split(',')
      .map(int.parse)
      .toList();
  final seconds = int.parse(
    Platform.environment['MOTION_TRACE_SECONDS'] ?? '45',
  );
  final families =
      (Platform.environment['MOTION_TRACE_PARTY'] ?? 'Horn,Kin,Let,Mane,Wing')
          .split(',');
  final seed = int.parse(Platform.environment['MOTION_TRACE_SEED'] ?? '11');
  const elements = ['Fire', 'Water', 'Earth', 'Air', 'Ice'];

  for (final wave in waves) {
    test('trace wave $wave', () async {
      if (out == null) return;
      final party = [
        for (var i = 0; i < families.length; i++)
          _member(families[i], elements[i % elements.length], i),
      ];
      final game = CosmicSurvivalGame(
        party: party,
        random: Random(seed),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(412, 915));
      await game.onLoad();
      game.startGame();
      final packLeader = kRarePerks.firstWhere((d) => d.id == 'pack_leader');
      for (var i = 1; i < party.length; i++) {
        game.powerUps.apply(packLeader);
      }
      game.spawner.currentWave = wave - 1;
      game.spawner.resumeAfterIntermission();
      void keepAlive() {
        game.alchemicalMeter = 0;
        game.gamePaused = false;
        if (game.showingPowerUpSelection) game.dismissPowerUpSelection();
        game.isGameOver = false;
        game.orb.currentHp = game.orb.maxHp;
        game.ship.currentHp = game.ship.maxHp.toDouble();
        for (final c in game.activeCompanions.values) {
          c.currentHp = c.maxHp;
        }
        // Long enough to watch: a boss walks all three of its phases, and
        // does not fall.
        for (final b in game.allLivingBosses) {
          b.hp = max(b.hp, b.maxHp * 0.12);
        }
      }

      final isBossWave = wave % 5 == 0;
      if (isBossWave) {
        for (var f = 0; f < 60 * 20 && game.activeBoss == null; f++) {
          keepAlive();
          game.update(1 / 60);
        }
      }
      for (final m in party) {
        game.summonCompanion(m.slotIndex);
      }
      // The first one out follows the ship unless the player lets it go;
      // let go here, so every family is seen choosing its own place.
      if (Platform.environment['MOTION_TRACE_TETHER'] != '1') {
        game.clearCompanionTether();
      }
      final rows = StringBuffer('t,what,id,x,y,note\n');
      final names = <String>{};
      for (var f = 0; f < 60 * seconds; f++) {
        keepAlive();
        // A boss wears down over the trace, so its later phases show.
        if (isBossWave) {
          for (final b in game.allLivingBosses) {
            final want = b.maxHp * (1 - 0.85 * f / (60 * seconds));
            if (b.hp > want && !b.shielded) {
              game.damageBoss(b.hp - want, target: b);
            }
          }
        }
        game.update(1 / 60);
        if (f % 6 != 0) continue;
        final t = (f / 60).toStringAsFixed(2);
        final o = game.orb.position;
        String xy(dynamic p) =>
            '${(p.dx - o.dx).toStringAsFixed(1)},'
            '${(p.dy - o.dy).toStringAsFixed(1)}';
        var k = 0;
        for (final b in game.allLivingBosses) {
          final kind = survivalBossKindOf(b).name;
          names.add('$kind/${b.discipline.name}/${b.type.name}');
          rows.writeln(
            '$t,boss,${k++},${xy(b.position)},'
            '$kind ${b.type.name} r${b.radius.round()} '
            'hp${(b.hpFraction * 100).round()}',
          );
        }
        rows.writeln('$t,ship,0,${xy(game.ship.position)},');
        for (final e in game.activeCompanions.entries) {
          final c = e.value;
          if (c.isDead) continue;
          rows.writeln(
            '$t,comp,${e.key},${xy(c.position)},'
            '${c.member.family}'
            '${c.engagedTarget != null ? ' fighting' : ''}',
          );
        }
      }
      Directory(out).createSync(recursive: true);
      File('$out/w$wave.csv').writeAsStringSync(rows.toString());
      stdout.writeln(
        'w$wave: ${names.join(', ')} '
        'enemies ${game.enemies.where((e) => !e.isDead).length}',
      );
      game.onRemove();
    });
  }
}
