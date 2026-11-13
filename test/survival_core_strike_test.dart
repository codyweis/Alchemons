// A strike on the core shows on its glass (core_strike_art.dart): it runs
// for a moment, leaves a bruise, and is gone; never more than the cap at
// once. STRIKE_OUT=file.png writes a strip of one strike of each weight at
// six ages.

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/core_strike_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a strike shows, fades and is gone; the cap holds', () {
    final strikes = CoreStrikes();
    strikes.add(0.4, 1, const ui.Color(0xFFFF7A3C), 10);
    expect(strikes.showing(10.1), 1);
    expect(strikes.showing(10 + CoreStrikes.life - 0.01), 1);
    expect(strikes.showing(10 + CoreStrikes.life + 0.01), 0);
    for (var i = 0; i < 60; i++) {
      strikes.add(i * 0.3, 2, const ui.Color(0xFFFF7A3C), 20 + i * 0.01);
    }
    expect(strikes.showing(20.7), CoreStrikes.cap);
    // Drawing a full set is three point draws and throws nothing.
    final rec = ui.PictureRecorder();
    strikes.paint(ui.Canvas(rec), 86, 20.7);
    rec.endRecording().dispose();
  });

  test('a body that reaches the glass marks the core where it struck', () async {
    final game = CosmicSurvivalGame(
      party: [
        CosmicPartyMember(
          instanceId: 'a',
          baseId: 'MAN01',
          displayName: 'Mane',
          family: 'Mane',
          element: 'Fire',
          level: 10,
          slotIndex: 0,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
          staminaBars: 3,
          staminaMax: 3,
        ),
      ],
      random: Random(4),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(412, 915));
    await game.onLoad();
    game.startGame();
    // Nobody defends: the first bodies of wave 1 walk in and strike.
    var marked = false;
    for (var f = 0; f < 60 * 60 && !marked; f++) {
      game.orb.currentHp = game.orb.maxHp;
      game.ship.position = game.orb.position + const ui.Offset(0, 900);
      game.ship.fireTimer = -1e9;
      game.update(1 / 60);
      marked = game.debugCoreStrikes.showing(game.stats.timeElapsed) > 0;
    }
    game.onRemove();
    expect(marked, isTrue);
  });

  test('a shot lands at the glass if its path hits the core, and passes if '
      'it does not', () async {
    Future<(double, double)> fire(double offCentre) async {
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'a',
            baseId: 'MAN01',
            displayName: 'Mane',
            family: 'Mane',
            element: 'Fire',
            level: 10,
            slotIndex: 0,
            statSpeed: 3,
            statIntelligence: 3,
            statStrength: 3,
            statBeauty: 3,
            staminaBars: 3,
            staminaMax: 3,
          ),
        ],
        random: Random(4),
        onGameOver: () {},
      );
      game.onGameResize(Vector2(412, 915));
      await game.onLoad();
      game.startGame();
      game.ship.position = game.orb.position + const ui.Offset(0, 900);
      game.ship.fireTimer = -1e9;
      game.orb.shieldHp = 0;
      final shot = SurvivalBossProjectile(
        position: game.orb.position + ui.Offset(-300, offCentre),
        angle: 0,
        element: 'Fire',
        damage: 5,
        speed: 250,
        radius: 5,
        life: 4,
      );
      game.bossProjectiles.add(shot);
      final before = game.orb.currentHp;
      var landedAt = double.nan;
      for (var f = 0; f < 60 * 3; f++) {
        game.update(1 / 60);
        if (landedAt.isNaN && shot.life <= 0) {
          landedAt = (shot.position - game.orb.position).distance;
        }
      }
      final lost = (before - game.orb.currentHp).toDouble();
      game.onRemove();
      return (lost, landedAt);
    }

    // Straight at the core: it lands, out at the glass and not in the
    // middle (it used to fly on to within 30 of the centre).
    final (lost, landedAt) = await fire(8);
    expect(lost, greaterThan(0));
    expect(landedAt, greaterThan(60));
    // Passing 70 off its centre, through the glass's edge: it flies on, as
    // it always did.
    final (passed, _) = await fire(70);
    expect(passed, 0);
  });

  test('strike strip', () async {
    final out = Platform.environment['STRIKE_OUT'];
    if (out == null) return;
    const cell = 300.0, radius = 86.0;
    const ages = [0.04, 0.14, 0.3, 0.5, 1.1, 2.1];
    final size = ui.Size(cell * ages.length, cell);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xFF0D1220),
    );
    for (var k = 0; k < ages.length; k++) {
      final strikes = CoreStrikes()
        // A light body, a heavy one that bursts, a shot.
        ..add(-0.5, 1.0, elementColor('Fire'), 5)
        ..add(2.6, 2.6, elementColor('Fire'), 5)
        ..add(1.3, 0.8, elementColor('Fire'), 5);
      canvas.save();
      canvas.translate(cell * (k + 0.5), cell * 0.5);
      paintOrbCore(canvas, OrbBaseSkin.defaultOrb, 3.0, radius: radius);
      strikes.paint(canvas, radius, 5 + ages[k]);
      canvas.restore();
    }
    final img = await rec
        .endRecording()
        .toImage(size.width.round(), size.height.round());
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File(out)
      ..createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}
