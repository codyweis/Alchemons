@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_enemy_vfx.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mender_vfx.dart';
import 'package:alchemons/games/shared/burn_healing.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the mender for judging: a sheet through one pulse (the mantle
/// gathering, the flow going out, the light on the mended bodies), a row
/// where every body it mends is burning, and the real game around it at the
/// phone's camera, as stills and a short film.
///
///   MENDER_OUT=dir flutter test test/survival_mender_preview_test.dart \
///     --tags preview
///
/// The film needs ffmpeg on the PATH; without it the frames are left as PNGs.
void main() {
  final out = Platform.environment['MENDER_OUT'];

  CosmicSurvivalEnemy body(
    EnemyTier tier,
    String element,
    Offset at, {
    EnemyTrait? trait,
    double hpFraction = 0.4,
  }) => CosmicSurvivalEnemy(
    position: at,
    hp: 100 * hpFraction,
    maxHp: 100,
    speed: 0,
    damage: 0,
    radius: tierRadius(tier),
    tier: tier,
    element: element,
    conduct: trait == EnemyTrait.mender
        ? EnemyConduct.siege
        : EnemyConduct.charge,
    trait: trait,
    target: CosmicEnemyTarget.orb,
  )..angle = -0.4;

  void space(Canvas c, double w, double h) {
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF06050E),
    );
    final rng = Random(3);
    final star = Paint();
    for (var i = 0; i < (w * h / 2500).round(); i++) {
      star.color = const Color(
        0xFFFFFFFF,
      ).withValues(alpha: 0.15 + rng.nextDouble() * 0.45);
      c.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h),
        0.4 + rng.nextDouble() * 0.9,
        star,
      );
    }
  }

  Future<void> save(
    WidgetTester tester,
    String name,
    ui.Picture pic,
    int w,
    int h,
  ) async {
    await tester.runAsync(() async {
      final img = await pic.toImage(w, h);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(out!).createSync(recursive: true);
      File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
      img.dispose();
    });
    pic.dispose();
  }

  testWidgets('mender through one pulse', (tester) async {
    const cell = 320.0;
    // About the phone's pixels: the game's camera at 0.6 on a ~2.6x screen.
    const px = 1.6;
    // Seconds into the scene; the pulse goes out at 2.5.
    const times = [1.4, 2.4, 2.7, 2.95, 3.2, 3.6];
    const rows = [
      ('Plant', false),
      ('Water', false),
      ('Spirit', false),
      ('Plant', true),
    ];
    final w = cell * times.length * px;
    final h = cell * rows.length * px;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    space(c, w, h);
    c.scale(px);
    for (var row = 0; row < rows.length; row++) {
      final (element, burning) = rows[row];
      final flows = MenderFlows();
      final mender = body(
        EnemyTier.phantom,
        element,
        const Offset(80, 160),
        trait: EnemyTrait.mender,
      )..menderPulseTimer = CosmicSurvivalBalance.menderPulseInterval;
      final targets = [
        body(EnemyTier.brute, element, const Offset(236, 88)),
        body(EnemyTier.sentinel, element, const Offset(262, 196)),
        body(EnemyTier.drone, element, const Offset(178, 262)),
      ];
      var t = 0.0;
      for (var col = 0; col < times.length; col++) {
        while (t < times[col]) {
          const dt = 1 / 60;
          t += dt;
          mender.menderPulseTimer -= dt;
          if (mender.menderPulseTimer <= 0) {
            mender.menderPulseTimer = CosmicSurvivalBalance.menderPulseInterval;
            for (final target in targets) {
              flows.send(
                mender,
                target,
                elementColor(element),
                CosmicSurvivalBalance.menderMendTravel,
              );
            }
          }
          for (final target in targets) {
            target.burnTimer = burning ? kBurnSeconds : 0;
          }
          flows.update(dt);
        }
        final origin = Offset(col * cell, row * cell);
        c.save();
        c.clipRect(origin & const Size(cell, cell));
        c.translate(origin.dx, origin.dy);
        for (final e in [...targets, mender]) {
          drawSurvivalEnemy(canvas: c, enemy: e, time: t);
        }
        const view = Rect.fromLTWH(0, 0, cell, cell);
        paintMenderMantles(c, [mender], view, t);
        flows.paint(c, view);
        c.restore();
      }
    }
    await save(
      tester,
      'mender_pulse',
      rec.endRecording(),
      w.round(),
      h.round(),
    );
  }, skip: out == null);

  testWidgets('mender in the game', (tester) async {
    CosmicPartyMember member(int slot, String id, String family, String el) =>
        CosmicPartyMember(
          instanceId: 'p$slot',
          baseId: id,
          displayName: '$family $el',
          family: family,
          element: el,
          level: 10,
          slotIndex: slot,
          statSpeed: 4,
          statIntelligence: 4,
          statStrength: 4,
          statBeauty: 4,
          staminaBars: 3,
          staminaMax: 3,
        );
    final game = CosmicSurvivalGame(
      party: [member(0, 'MAN06', 'Mane', 'Lava')],
      random: Random(7),
      onGameOver: () {},
    );
    const w = 900.0, h = 1400.0;
    game.onGameResize(Vector2(w, h));
    await game.onLoad();
    game.startGame();
    void hold() {
      game.alchemicalMeter = 0;
      game.gamePaused = false;
      game.showingPowerUpSelection = false;
      game.orb.currentHp = game.orb.maxHp;
      game.ship.currentHp = game.ship.maxHp.toDouble();
    }

    // Clear the opening wave; the bodies placed below hold the wave open.
    for (
      var i = 0;
      i < 60 * 60 &&
          game.spawner.spawnedThisWave < game.spawner.targetCountThisWave;
      i++
    ) {
      hold();
      game.update(1 / 60);
    }
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.ship.fireTimer = -1e9;
    final at = game.orb.position + const Offset(0, 470);
    game.ship.position = at + const Offset(0, 260);
    final element = 'Plant';
    CosmicSurvivalEnemy place(
      EnemyTier tier,
      Offset offset, {
      EnemyTrait? trait,
      double hpFraction = 0.35,
    }) {
      final e = body(
        tier,
        element,
        at + offset,
        trait: trait,
        hpFraction: hpFraction,
      );
      game.enemies.add(e);
      return e;
    }

    final mender = place(
      EnemyTier.phantom,
      Offset.zero,
      trait: EnemyTrait.mender,
      hpFraction: 1,
    )..menderPulseTimer = 1.2;
    place(EnemyTier.brute, const Offset(170, -60));
    final burning = place(EnemyTier.sentinel, const Offset(-150, 70));
    place(EnemyTier.drone, const Offset(60, 175));
    // Chaff around it at full health, which it leaves alone.
    for (var i = 0; i < 14; i++) {
      final a = i * 2.39996;
      place(
        EnemyTier.wisp,
        Offset(cos(a), sin(a)) * (120 + (i % 4) * 40.0),
        hpFraction: 1,
      );
    }

    final frames = Directory('${out!}/mender_film_frames')
      ..createSync(recursive: true);
    const fps = 30;
    const seconds = 4.4;
    const dpr = 2.6;
    const crop = 1080.0;
    var frame = 0;
    final stills = {12, 54, 63, 72, 84};
    for (var f = 0; f < (seconds * 60).round(); f++) {
      hold();
      game.ship.position = at + const Offset(0, 260);
      // The sentinel is under a Fire burn the whole time; its flow gutters.
      burning.burnTimer = kBurnSeconds;
      game.update(1 / 60);
      if (f.isOdd) continue;
      game.setCameraZoom(0.6);
      game.cameraPanOffset = at - game.ship.position;
      // The phone's pixels round the mender: the screen at its density,
      // cropped to a square about the middle of it.
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawRect(
        const ui.Rect.fromLTWH(0, 0, crop, crop),
        ui.Paint()..color = game.backgroundColor(),
      );
      canvas.translate(crop / 2 - w / 2 * dpr, crop / 2 - h / 2 * dpr);
      canvas.scale(dpr);
      game.render(canvas);
      final pic = rec.endRecording();
      await tester.runAsync(() async {
        final img = await pic.toImage(crop.toInt(), crop.toInt());
        final png = await img.toByteData(format: ui.ImageByteFormat.png);
        final name = 'f${frame.toString().padLeft(4, '0')}';
        final bytes = png!.buffer.asUint8List();
        File('${frames.path}/$name.png').writeAsBytesSync(bytes);
        if (stills.contains(frame)) {
          File('$out/mender_game_$frame.png').writeAsBytesSync(bytes);
        }
        img.dispose();
      });
      pic.dispose();
      frame++;
    }
    expect(mender.isDead, isFalse);
    game.onRemove();
    await tester.runAsync(() async {
      try {
        final r = await Process.run('ffmpeg', [
          '-y',
          '-loglevel',
          'error',
          '-framerate',
          '$fps',
          '-i',
          '${frames.path}/f%04d.png',
          '-vf',
          'scale=720:-2',
          '-pix_fmt',
          'yuv420p',
          '$out/mender_film.mp4',
        ]);
        if (r.exitCode == 0) frames.deleteSync(recursive: true);
      } on ProcessException {
        // No ffmpeg: the frames stay.
      }
    });
  }, skip: out == null);
}
