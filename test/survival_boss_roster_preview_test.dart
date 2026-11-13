@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/boss_roster_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

// The new bosses (boss_roster_art.dart) in a real run: the game is played to
// a boss wave (BOSS_ROSTER_WAVE, default 35: the Drift), the boss fights for
// a while, and frames are shot every two seconds centred on the core, at the
// flying zoom and wider, so a boss's whole shape and what its wave does to
// the arena are in view.
//
//   BOSS_ROSTER_OUT=/tmp/bosses [BOSS_ROSTER_WAVE=35] flutter test \
//     test/survival_boss_roster_preview_test.dart --tags preview

void main() {
  final out = Platform.environment['BOSS_ROSTER_OUT'];
  final wave = int.parse(Platform.environment['BOSS_ROSTER_WAVE'] ?? '35');

  // One boss of the wave in each of the states its look answers to: whole,
  // half, nearly down, shielded, venting, dashing, enraged.
  testWidgets('boss states', (tester) async {
    if (out == null) return;
    final spawner = CosmicSurvivalSpawner(random: Random(3));
    spawner.currentWave = wave;
    const cell = 260.0;
    final states = <String, void Function(SurvivalBoss)>{
      'whole': (_) {},
      'half': (b) => b.hp = b.maxHp * 0.5,
      'low': (b) => b.hp = b.maxHp * 0.1,
      'shield': (b) => b.shieldUp = true,
      'vent': (b) => b.overheatTimer = 1.4,
      'dash': (b) => b
        ..charging = true
        ..chargeAngle = pi,
      'enraged': (b) => b
        ..enraged = true
        ..hp = b.maxHp * 0.25,
      // A quarter second after it hatched (the Unhatched).
      'hatched': (b) => noteUnhatchedHatch(b, 1.95),
      // A fifth of a second after a blink from 200 units to its left.
      'blink': (b) {
        tickSurvivalBossArt(b, 1.98);
        b.position += const ui.Offset(-200, 0);
        tickSurvivalBossArt(b, 1.99);
        b.position -= const ui.Offset(-200, 0);
        tickSurvivalBossArt(b, 2.0);
      },
      // The Eclipse about to open below where it stands: the dark gathering
      // there, early and just before.
      'opening soon': (b) => noteEclipseOpening(
        b,
        b.position + ui.Offset(0, b.radius * 1.75),
        2.2 - kEclipseTellSeconds * 0.4,
      ),
      'opening now': (b) => noteEclipseOpening(
        b,
        b.position + ui.Offset(0, b.radius * 1.75),
        2.2 - kEclipseTellSeconds * 0.92,
      ),
    };
    // Your party, as an Other Orb's guard: three creatures' sprites.
    final shadows = <BossShadow>[];
    await tester.runAsync(() async {
      for (final asset in const [
        'assets/images/creatures/legendary/WNG01_firewing.png',
        'assets/images/creatures/uncommon/MAN01_firemane.png',
        'assets/images/creatures/common/LET01_firelet.png',
      ]) {
        final data = (await rootBundle.load(asset)).buffer.asUint8List();
        final image = (await (await ui.instantiateImageCodec(
          data,
        )).getNextFrame()).image;
        final shadow = await bossShadowFromSheet(
          image,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        if (shadow != null) shadows.add(shadow);
      }
    });
    final size = ui.Size(cell * states.length, cell * 1.5);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xFF0D1220),
    );
    var k = 0;
    for (final setUp in states.values) {
      final at = ui.Offset(cell * (k + 0.5), cell * 0.8);
      final boss = spawner.createBossForWave(wave, at)!
        ..spawnIntroTimer = 0
        ..angle = pi;
      setUp(boss);
      final scale = cell * 0.3 / boss.radius;
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(scale);
      canvas.translate(-at.dx, -at.dy);
      drawSurvivalBoss(
        canvas: canvas,
        boss: boss,
        time: 2.2,
        core: at - ui.Offset(boss.radius * 3, 0),
        shadows: shadows,
      );
      canvas.restore();
      k++;
    }
    final img = rec.endRecording().toImageSync(
      size.width.round(),
      size.height.round(),
    );
    await tester.runAsync(() async {
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(out).createSync(recursive: true);
      File(
        '$out/w${wave}_states.png',
      ).writeAsBytesSync(png!.buffer.asUint8List());
    });
  });

  testWidgets('new boss in a run', (tester) async {
    if (out == null) return;
    final game = CosmicSurvivalGame(
      party: [
        for (final (i, (id, n, f, e)) in const [
          ('MAN06', 'Lavamane', 'Mane', 'Lava'),
          ('LET03', 'Earthlet', 'Let', 'Earth'),
          ('KIN14', 'Spiritkin', 'Kin', 'Spirit'),
        ].indexed)
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
    game.spawner.currentWave = wave - 1;
    game.spawner.resumeAfterIntermission();
    game.debugWear.seed(wave);
    void keepAlive() {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.orb.currentHp = game.orb.maxHp.toDouble();
      game.ship.currentHp = game.ship.maxHp.toDouble();
      for (final c in game.activeCompanions.values) {
        c.currentHp = c.maxHp;
      }
      // Long enough to watch: the boss does not fall.
      for (final b in game.allLivingBosses) {
        b.hp = max(b.hp, b.maxHp * 0.6);
      }
    }

    Future<void> shoot(String file, double zoom) async {
      game.setCameraZoom(zoom);
      game.cameraPanOffset = game.orb.position - game.ship.position;
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

    for (var f = 0; f < 60 * 20 && game.activeBoss == null; f++) {
      keepAlive();
      game.update(1 / 60);
    }
    for (var i = 0; i < 3; i++) {
      game.summonCompanion(i);
    }
    for (var shot = 0; shot < 12; shot++) {
      for (var f = 0; f < 120; f++) {
        keepAlive();
        game.update(1 / 60);
      }
      final t = shot.toString().padLeft(2, '0');
      await shoot('w${wave}_t${t}_near', 0.595);
      await shoot('w${wave}_t${t}_wide', 0.36);
    }
    if (Platform.environment['BOSS_ROSTER_COST'] != null) {
      // What the sea costs to record at the flying zoom: the same frames
      // drawn with it and without it, alternated.
      game.setCameraZoom(0.595);
      final withSea = <int>[], without = <int>[];
      for (var f = 0; f < 240; f++) {
        keepAlive();
        game.update(1 / 60);
        final off = f.isOdd;
        final keep = game.debugDustSea.amount;
        if (off) game.debugDustSea.amount = 0;
        final sw = Stopwatch()..start();
        final rec = ui.PictureRecorder();
        game.render(ui.Canvas(rec));
        rec.endRecording().dispose();
        sw.stop();
        game.debugDustSea.amount = keep;
        if (f >= 40) (off ? without : withSea).add(sw.elapsedMicroseconds);
      }
      double med(List<int> v) => (v..sort())[v.length ~/ 2] / 1000;
      stdout.writeln(
        'render median with sea ${med(withSea)} ms, without ${med(without)} ms',
      );
    }
    stdout.writeln(
      'w$wave bosses ${game.allLivingBosses.length} '
      'enemies ${game.enemies.where((e) => !e.isDead).length} '
      'dust ${game.debugDustSea.amount.toStringAsFixed(2)} '
      'grains ${game.debugDustSea.lastGrains} '
      'sources ${game.debugDustSea.sources} '
      'shadows ${game.debugPartyShadows} '
      'sprites ${game.debugCompanionSpritesLoaded}',
    );
    game.onRemove();
  });
}
