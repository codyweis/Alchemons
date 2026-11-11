@Tags(['preview'])
library;

// Survival's field as the player sees it, to judge by eye (look audit,
// 2026-11-03):
//  - LOOK_OUT=dir: a late wave (LOOK_WAVES, default 24) with a full party
//    out, as frames 0.1 s apart at the flying zoom on a phone, then with
//    every special cast at once. LOOK_FURY=1 adds Elemental Fury.
//  - KILL_OUT=dir: one death of each tier and a volatile elite close up,
//    frames 1/15 s apart (survival_death_vfx.dart), with the bodies' wind-up
//    and some ship fire in the first. KILL_FURY=1 adds Elemental Fury.
//  - BOSS_OUT=dir: a boss wave (BOSS_WAVE, default 25): the boss arriving
//    in frames 1/6 s apart, the fight eight seconds in, and a vent.
//   KILL_OUT=/tmp/kill flutter test test/survival_field_preview_test.dart \
//     --tags preview

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/games/cosmic/ability_grains.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _parties = <String, List<(String, String, String, String)>>{
  'a': [
    ('MAN06', 'Lavamane', 'Mane', 'Lava'),
    ('KIN12', 'Plantkin', 'Kin', 'Plant'),
    ('WNG15', 'Darkwing', 'Wing', 'Dark'),
    ('MSK13', 'Poisonmask', 'Mask', 'Poison'),
    ('HOR01', 'Firehorn', 'Horn', 'Fire'),
  ],
  'b': [
    ('PIP07', 'Lightningpip', 'Pip', 'Lightning'),
    ('LET03', 'Earthlet', 'Let', 'Earth'),
    ('HOR01', 'Firehorn', 'Horn', 'Fire'),
    ('KIN14', 'Spiritkin', 'Kin', 'Spirit'),
    ('MYS06', 'Magmara', 'Mystic', 'Lava'),
  ],
};

void main() {
  final out = Platform.environment['LOOK_OUT'];
  testWidgets('kill closeups', (tester) async {
    final kout = Platform.environment['KILL_OUT'];
    if (kout == null) return;
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'p0',
          baseId: 'MAN06',
          displayName: 'Lavamane',
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
      random: Random(3),
      onGameOver: () {},
    );
    const w = 412.0, h = 915.0;
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.startGame();
    for (var f = 0; f < 60 * 4; f++) {
      game.update(1 / 60);
    }
    if (Platform.environment['KILL_FURY'] != null) {
      final fury = kAllPowerUps.firstWhere((d) => d.id == 'elemental_fury');
      for (var i = 0; i < 3; i++) {
        game.powerUps.apply(fury);
      }
      game.summonCompanion(0);
    }
    game.enemies.clear();
    game.spawner.intermission = true;
    final at = game.ship.position;
    final specs = <(EnemyTier, String, EliteAffix?, Offset)>[
      (EnemyTier.wisp, 'Fire', null, const Offset(-150, -260)),
      (EnemyTier.drone, 'Water', null, const Offset(-50, -260)),
      (EnemyTier.sentinel, 'Earth', null, const Offset(60, -260)),
      (EnemyTier.phantom, 'Spirit', null, const Offset(160, -260)),
      (EnemyTier.brute, 'Lightning', null, const Offset(-120, -60)),
      (EnemyTier.colossus, 'Poison', null, const Offset(80, -40)),
      (EnemyTier.drone, 'Ice', EliteAffix.volatile, const Offset(-60, 200)),
    ];
    final bodies = <CosmicSurvivalEnemy>[];
    for (final (tier, element, affix, off) in specs) {
      final e = CosmicSurvivalEnemy(
        position: at + off,
        hp: 100,
        maxHp: 100,
        speed: 40,
        damage: 0,
        radius: tierRadius(tier) * (affix != null ? 1.3 : 1.0),
        tier: tier,
        element: element,
        conduct: EnemyConduct.charge,
        target: CosmicEnemyTarget.orb,
        isElite: affix != null,
        eliteAffix: affix,
      );
      bodies.add(e);
      game.enemies.add(e);
    }
    await tester.runAsync(() => AbilityGrainSprite.ensureLoaded());
    game.setCameraZoom(0.75);
    game.cameraPanOffset = Offset.zero;
    final frames = <ui.Image>[];
    Future<void> grab() async {
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.scale(2);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = game.backgroundColor(),
      );
      game.render(canvas);
      final pic = rec.endRecording();
      await tester.runAsync(() async {
        frames.add(await pic.toImage(w.toInt() * 2, h.toInt() * 2));
      });
      pic.dispose();
    }

    // Let the bodies wind up first, then lay some ship fire in view.
    for (var f = 0; f < 40; f++) {
      game.update(1 / 60);
    }
    for (var i = 0; i < 5; i++) {
      game.shipProjectiles.add(
        ShipProjectile(
          position: at + Offset(140 + i * 22.0, 60 - i * 30.0),
          velocity: const Offset(300, -420),
          damage: 0,
          life: 9,
        ),
      );
    }
    game.shipProjectiles.add(
      ShipProjectile(
        position: at + const Offset(200, 160),
        velocity: const Offset(420, 120),
        damage: 0,
        life: 9,
        splashRadius: 60,
      ),
    );
    await grab();
    for (final e in bodies) {
      game.debugShipAttackDamage(e, 1e6);
    }
    for (var shot = 0; shot < 18; shot++) {
      for (var f = 0; f < 4; f++) {
        game.update(1 / 60);
      }
      await grab();
    }
    await tester.runAsync(() async {
      Directory(kout).createSync(recursive: true);
      for (final (i, img) in frames.indexed) {
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        File(
          '$kout/kill_${i.toString().padLeft(2, '0')}.png',
        ).writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      }
    });
    game.onRemove();
  });
  testWidgets('boss wave', (tester) async {
    final bout = Platform.environment['BOSS_OUT'];
    if (bout == null) return;
    final wave = int.parse(Platform.environment['BOSS_WAVE'] ?? '25');
    final game = CosmicSurvivalGame(
      party: [
        for (final (i, (id, n, f, e)) in _parties['a']!.indexed)
          CosmicPartyMember(
            instanceId: 'p$i',
            baseId: id,
            displayName: n,
            family: f,
            element: e,
            level: 10,
            slotIndex: i,
            statSpeed: 4,
            statIntelligence: 4,
            statStrength: 4,
            statBeauty: 4,
            staminaBars: 3,
            staminaMax: 3,
          ),
      ],
      random: Random(11),
      onGameOver: () {},
    );
    const w = 412.0, h = 915.0;
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.startGame();
    await tester.runAsync(() => AbilityGrainSprite.ensureLoaded());
    game.spawner.currentWave = wave - 1;
    game.spawner.resumeAfterIntermission();
    game.debugWear.seed(wave, game.orb.position, 1140);
    void keepAlive() {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.orb.currentHp = game.orb.maxHp.toDouble();
      game.ship.currentHp = game.ship.maxHp.toDouble();
    }

    Future<void> shoot(String file) async {
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.scale(2);
      canvas.clipRect(const ui.Rect.fromLTWH(0, 0, w, h));
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, w, h),
        ui.Paint()..color = game.backgroundColor(),
      );
      game.render(canvas);
      final pic = rec.endRecording();
      await tester.runAsync(() async {
        final img = await pic.toImage(w.toInt() * 2, h.toInt() * 2);
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        Directory(bout).createSync(recursive: true);
        File('$bout/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
        img.dispose();
      });
      pic.dispose();
    }

    // The frame the boss is called, then its arrival, with the camera on
    // the spot it comes to.
    game.setCameraZoom(0.595);
    for (var f = 0; f < 600 && game.activeBoss == null; f++) {
      keepAlive();
      game.update(1 / 60);
    }
    final boss = game.activeBoss!;
    final spot = boss.spawnTargetPosition ?? boss.position;
    game.ship.position = spot + const Offset(60, 190);
    for (var f = 0; f < 30; f++) {
      keepAlive();
      game.update(1 / 60);
    }
    // Its arrival again from the start, now that the camera is there.
    game.debugRestartBossEntrance();
    for (var shot = 0; shot < 8; shot++) {
      await shoot('boss_w${wave}_in${shot.toString().padLeft(2, '0')}');
      for (var f = 0; f < 10; f++) {
        keepAlive();
        game.update(1 / 60);
      }
    }
    // The fight, eight seconds in.
    for (var f = 0; f < 60 * 8; f++) {
      keepAlive();
      game.update(1 / 60);
    }
    game.ship.position = boss.position + const Offset(60, 190);
    for (var f = 0; f < 30; f++) {
      keepAlive();
      game.update(1 / 60);
    }
    await shoot('boss_w${wave}_fight');
    // Venting.
    boss.overheatTimer = 1.9;
    for (var shot = 0; shot < 4; shot++) {
      for (var f = 0; f < 12; f++) {
        keepAlive();
        game.update(1 / 60);
      }
      boss.overheatTimer = max(boss.overheatTimer, 1.9 - shot * 0.5);
      await shoot('boss_w${wave}_vent${shot.toString().padLeft(2, '0')}');
    }
    game.onRemove();
  });
  final waves = (Platform.environment['LOOK_WAVES'] ?? '24')
      .split(',')
      .map(int.parse);
  for (final MapEntry(key: name, value: party) in _parties.entries) {
    for (final wave in waves) {
      testWidgets('look audit $name w$wave', (tester) async {
        if (out == null) return;
        final game = CosmicSurvivalGame(
          party: [
            for (final (i, (id, n, f, e)) in party.indexed)
              CosmicPartyMember(
                instanceId: 'p$i',
                baseId: id,
                displayName: n,
                family: f,
                element: e,
                level: 10,
                slotIndex: i,
                statSpeed: 4,
                statIntelligence: 4,
                statStrength: 4,
                statBeauty: 4,
                staminaBars: 3,
                staminaMax: 3,
              ),
          ],
          random: Random(11),
          onGameOver: () {},
        );
        // A phone in portrait, in logical pixels.
        const w = 412.0, h = 915.0;
        game.onGameResize(Vector2(w, h));
        await game.onLoad();
        game.startGame();
        final pack = kAllPowerUps.firstWhere((d) => d.id == 'pack_leader');
        for (var i = 0; i < 4; i++) {
          game.powerUps.apply(pack);
        }
        if (Platform.environment['LOOK_FURY'] != null) {
          final fury = kAllPowerUps.firstWhere((d) => d.id == 'elemental_fury');
          for (var i = 0; i < 3; i++) {
            game.powerUps.apply(fury);
          }
        }
        // LOOK_MUTATOR=arcStorm: that mutator's look on the field, whatever
        // the wave rolled.
        final look = Platform.environment['LOOK_MUTATOR'];
        if (look != null) {
          game.debugMutatorLook = SurvivalWaveMutator.values.byName(look);
        }
        game.spawner.currentWave = wave - 1;
        game.spawner.resumeAfterIntermission();
        // The floor a run this deep would have left.
        game.debugWear.seed(wave, game.orb.position, 1140);
        game.spawner.isBossWave = false;
        void keepAlive() {
          game.alchemicalMeter = 0;
          game.gamePaused = false;
          game.showingPowerUpSelection = false;
          game.orb.currentHp = game.orb.maxHp.toDouble();
          game.ship.currentHp = game.ship.maxHp.toDouble();
          for (final c in game.activeCompanions.values) {
            c.currentHp = c.maxHp;
          }
        }

        for (var f = 0; f < 60 * 3; f++) {
          keepAlive();
          game.update(1 / 60);
        }
        for (var i = 0; i < party.length; i++) {
          game.summonCompanion(i);
        }
        for (var f = 0; f < 60 * 16; f++) {
          keepAlive();
          game.update(1 / 60);
        }
        game.setCameraZoom(0.595);
        game.cameraPanOffset = Offset.zero;

        Future<void> shoot(String file, {double zoom = 0.595}) async {
          game.setCameraZoom(zoom);
          final rec = ui.PictureRecorder();
          final canvas = ui.Canvas(rec);
          canvas.scale(2);
          canvas.clipRect(const ui.Rect.fromLTWH(0, 0, w, h));
          canvas.drawRect(
            const ui.Rect.fromLTWH(0, 0, w, h),
            ui.Paint()..color = game.backgroundColor(),
          );
          game.render(canvas);
          final pic = rec.endRecording();
          await tester.runAsync(() async {
            final img = await pic.toImage(w.toInt() * 2, h.toInt() * 2);
            final png = await img.toByteData(format: ui.ImageByteFormat.png);
            Directory(out).createSync(recursive: true);
            File('$out/$file.png').writeAsBytesSync(png!.buffer.asUint8List());
            img.dispose();
          });
          pic.dispose();
        }

        // Frames every 0.1 s for 2.4 s at the flying zoom.
        for (var shot = 0; shot < 24; shot++) {
          for (var f = 0; f < 6; f++) {
            keepAlive();
            game.update(1 / 60);
          }
          await shoot('${name}_w${wave}_f${shot.toString().padLeft(2, '0')}');
        }
        // Wider, and every special on the same frame.
        for (final c in game.activeCompanions.values) {
          c.specialCooldown = 0;
        }
        for (var shot = 0; shot < 12; shot++) {
          for (var f = 0; f < 6; f++) {
            keepAlive();
            game.update(1 / 60);
          }
          await shoot('${name}_w${wave}_sp${shot.toString().padLeft(2, '0')}');
        }
        stdout.writeln(
          'party $name w$wave: enemies ${game.enemies.where((e) => !e.isDead).length} '
          'enemyShots ${game.enemyProjectiles.length} '
          'compProj ${game.companionProjectiles.length} '
          'active ${game.activeCompanions.length}',
        );
        game.onRemove();
      });
    }
  }
}
