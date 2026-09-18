@Tags(['stress'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

// Opt-in, deterministic CPU/raster reporting harness, not a device FPS claim.
// HORDE_REPORT_OUT=/tmp/horde flutter test test/survival_horde_stress_test.dart
// Normal wave caps are intentionally bypassed by injecting real enemy objects.
void main() {
  final output = Platform.environment['HORDE_REPORT_OUT'];
  testWidgets(
    'horde scaling: movement, specials, mass deaths and rendering',
    (tester) async {
      final reports = <Map<String, Object>>[];
      for (final count in [250, 500, 1000, 2000]) {
        final game = CosmicSurvivalGame(
          party: [
            CosmicPartyMember(
              instanceId: 'horde',
              baseId: 'MAN06',
              displayName: 'Stress Lavamane',
              family: 'Mane',
              element: 'Lava',
              level: 10,
              slotIndex: 0,
              statSpeed: 4,
              statIntelligence: 4,
              statStrength: 4,
              statBeauty: 4,
              staminaBars: 3,
              staminaMax: 3,
            ),
          ],
          random: Random(771),
          onGameOver: () {},
        );
        game.onGameResize(Vector2(900, 700));
        await game.onLoad();
        game.startGame();
        game.summonCompanion(0);
        game.enemies.clear();
        final rng = Random(314);
        for (var i = 0; i < count; i++) {
          final a = i * 2.399963;
          final r = 110 + sqrt((i + 0.5) / count) * 560;
          game.enemies.add(
            CosmicSurvivalEnemy(
              position:
                  game.orb.position + ui.Offset(cos(a) * r, sin(a) * r * 0.72),
              hp: 100000,
              maxHp: 100000,
              speed: 14,
              damage: 0,
              radius: 7,
              tier: i % 4 == 0 ? EnemyTier.drone : EnemyTier.wisp,
              element: i.isEven ? 'Earth' : 'Fire',
              conduct: EnemyConduct.charge,
              target: CosmicEnemyTarget.orb,
              retargetTimer: rng.nextDouble() * 2.6,
            ),
          );
        }
        // Persistent control + piercing + fields exercise the real collision path.
        for (final e in ['Water', 'Dark', 'Lava', 'Plant']) {
          final cast = createCosmicSpecialAbility(
            origin: game.orb.position,
            baseAngle: ['Water', 'Dark', 'Lava', 'Plant'].indexOf(e) * pi / 2,
            family: 'mane',
            element: e,
            damage: 30,
            maxHp: 400,
          );
          game.companionProjectiles.addAll(cast.projectiles);
        }
        for (var i = 0; i < 15; i++) {
          game.update(1 / 60);
          final warm = ui.PictureRecorder();
          game.render(ui.Canvas(warm));
          warm.endRecording().dispose();
        }
        final updates = <double>[];
        final renders = <double>[];
        for (var frame = 0; frame < 60; frame++) {
          final timer = Stopwatch()..start();
          game.update(1 / 60);
          updates.add(timer.elapsedMicroseconds / 1000);
          if (frame % 2 == 0) {
            final rec = ui.PictureRecorder();
            final canvas = ui.Canvas(rec);
            timer
              ..reset()
              ..start();
            game.render(canvas);
            final pic = rec.endRecording();
            renders.add(timer.elapsedMicroseconds / 1000);
            pic.dispose();
          }
        }
        Map<String, double> summary(List<double> values) {
          values.sort();
          return {
            'medianMs': values[values.length ~/ 2],
            'p95Ms': values[((values.length - 1) * 0.95).ceil()],
            'maxMs': values.last,
          };
        }

        final beforeKills = game.stats.kills;
        final victims = game.enemies.take(count ~/ 2).toList();
        final burst = Stopwatch()..start();
        for (final enemy in victims) {
          game.debugShipAttackDamage(enemy, 200000);
        }
        final deathMs = burst.elapsedMicroseconds / 1000;
        expect(game.stats.kills - beforeKills, victims.length);
        final burstParticles = game.vfxParticleCount;
        // Avoid upgrade-selection pause hiding the post-kill cost in this harness.
        game.alchemicalMeter = 0;
        game.gamePaused = false;
        final after = Stopwatch()..start();
        game.update(1 / 60);
        final afterMs = after.elapsedMicroseconds / 1000;
        final rec = ui.PictureRecorder();
        game.render(ui.Canvas(rec));
        final pic = rec.endRecording();
        double rasterMs = 0;
        await tester.runAsync(() async {
          final clock = Stopwatch()..start();
          final img = await pic.toImage(900, 700);
          rasterMs = clock.elapsedMicroseconds / 1000;
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          Directory(output!).createSync(recursive: true);
          File(
            '$output/horde_$count.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
        pic.dispose();
        reports.add({
          'enemies': count,
          'update': summary(updates),
          'recordRender': summary(renders),
          'snapshotRasterMs': rasterMs,
          'massKills': victims.length,
          'massKillMs': deathMs,
          'postKillUpdateMs': afterMs,
          'postKillParticles': burstParticles,
        });
        game.onRemove();
      }
      final report = {
        'mode': 'flutter_test debug, seeded; not device FPS',
        'viewport': '900x700',
        'scenarios': reports,
      };
      File(
        '$output/report.json',
      ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
      // ignore: avoid_print
      print(jsonEncode(report));
    },
    skip: output == null,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
