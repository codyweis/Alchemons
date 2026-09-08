import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

List<CosmicPartyMember> potentialParty(int potential) {
  final data = jsonDecode(File('assets/data/alchemons_creatures.json').readAsStringSync()) as Map<String, dynamic>;
  final creatures = data['creatures'] as List;
  const ids = ['PIP01', 'HOR02', 'MAN04', 'MSK12', 'LET02'];
  return [for (var i = 0; i < ids.length; i++) (() {
    final row = creatures.cast<Map<String, dynamic>>().firstWhere((c) => c['id'] == ids[i]);
    final base = row['baseStats'] as Map<String, dynamic>;
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int, level: 10, potential: potential);
    return CosmicPartyMember(instanceId: 'benchmark_$i', baseId: ids[i],
      displayName: row['name'] as String, family: row['mutationFamily'] as String,
      element: (row['types'] as List).first as String,
      level: 10, slotIndex: i, statSpeed: stat('speed'), statIntelligence: stat('intelligence'),
      statStrength: stat('strength'), statBeauty: stat('beauty'), staminaBars: 3, staminaMax: 3);
  })()];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final seed in [11, 29, 47]) {
    test('80 Potential level-10 party can clear wave 50, seed $seed', () async {
      final game = CosmicSurvivalGame(party: potentialParty(80), random: Random(seed), onGameOver: () {});
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      void pick(String id, {int? slot}) => game.applyPowerUp(
        kAllPowerUps.firstWhere((def) => def.id == id), targetSlot: slot);
      // Twenty achievable run picks, no permanent upgrades or enhancements.
      for (var i = 0; i < 4; i++) { pick('pack_leader'); }
      for (var i = 0; i < 5; i++) { pick('strength_up', slot: i); }
      pick('orb_vitality');
      pick('orb_vitality');
      pick('lifesteal', slot: 0);
      for (var i = 0; i < 2; i++) { pick('auto_turret'); pick('regen_field'); }
      pick('mirror_shield');
      pick('command_strength');
      pick('command_intelligence');
      pick('command_speed');
      game.startGame();
      for (var wave = 1; wave < 50; wave++) { game.spawner.resumeAfterIntermission(); }
      for (var i = 0; i < 5; i++) { game.summonCompanion(i); }
      game.clearCompanionTether();
      var elapsed = 0.0;
      while (!game.isGameOver && game.spawner.currentWave == 50 && elapsed < 360) {
        // Simple legal pilot: protect the orb, purge sources, then close on boss.
        Offset? target;
        var best = double.infinity;
        for (final enemy in game.enemies) {
          if (enemy.isDead) continue;
          final orbDistance = (enemy.position - game.orb.position).distance;
          final score = !enemy.isPlagueCore && orbDistance < 300 ? orbDistance - 2000 : enemy.isPlagueCore ? -1000.0 : orbDistance;
          if (score < best) { best = score; target = enemy.position; }
        }
        target ??= game.activeBoss?.position ?? game.orb.position;
        final delta = target - game.ship.position;
        final tangent = delta.distance > 0 ? Offset(-delta.dy, delta.dx) / delta.distance : Offset.zero;
        final movement = delta.distance > 170 ? delta / delta.distance : tangent;
        game.setJoystickInput(movement);
        if (game.showingPowerUpSelection) {
          // No extra strength from mid-encounter drafts in this benchmark.
          game.alchemicalMeter = 0;
          game.dismissPowerUpSelection();
        }
        game.update(1 / 30);
        elapsed += 1 / 30;
      }
      print('seed=$seed wave=${game.spawner.currentWave} seconds=${elapsed.round()} '
        'orb=${game.orb.currentHp.round()} bossHp=${game.activeBoss?.hp.round()} '
        'party=${game.activeCompanions.length} outbreak=${game.outbreak?.name}');
      expect(game.isGameOver, isFalse);
      expect(game.spawner.currentWave, greaterThan(50));
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}

