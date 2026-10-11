@Tags(['preview'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flame/components.dart' show Vector2;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Every survival orb skin as a run draws it: the real game frame at the
// Fold's size (475 × 751), the orb at the start of a run with its HP ring
// and alchemy ring, and the Standard Orb's frame again holding a shield
// (frame_default_shield.png).
//
//   ORB_OUT=/tmp/orbs flutter test test/survival_orb_preview_test.dart \
//     --tags preview
void main() {
  final out = Platform.environment['ORB_OUT'];

  test('survival orbs', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    const w = 475.0, h = 751.0;
    final frames = <(String, ui.Image)>[];
    for (final def in kOrbBases) {
      final game = CosmicSurvivalGame(
        party: [
          CosmicPartyMember(
            instanceId: 'orb',
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
        random: Random(7),
        onGameOver: () {},
        upgradeState: SurvivalUpgradeState(
          equippedSkin: def.skin,
          ownedSkins: {def.skin},
        ),
      );
      game.onGameResize(Vector2(w, h));
      await game.onLoad();
      game.startGame();
      for (var i = 0; i < 90; i++) {
        game.update(1 / 60);
        game.enemies.clear();
      }
      game.orb.currentHp = game.orb.maxHp * 0.7;
      ui.Image shot() {
        final rec = ui.PictureRecorder();
        final c = Canvas(rec);
        c.drawRect(
          const Rect.fromLTWH(0, 0, w * 2, h * 2),
          Paint()..color = const Color(0xFF05060A),
        );
        c.scale(2);
        game.render(c);
        return rec.endRecording().toImageSync(950, 1502);
      }

      frames.add((def.name, shot()));
      if (def.skin == OrbBaseSkin.defaultOrb) {
        // The same frame holding a boss wave's shield (4% of the orb).
        game.orb.shieldHp = (game.orb.maxHp * 0.04).round();
        final shielded = await shot().toByteData(
          format: ui.ImageByteFormat.png,
        );
        File(
          '$out/frame_default_shield.png',
        ).writeAsBytesSync(shielded!.buffer.asUint8List());
        game.orb.shieldHp = 0;
      }
    }

    // A contact sheet: each frame cropped round the middle of the screen.
    const cell = 360.0;
    const cols = 4;
    final rows = (frames.length / cols).ceil();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      const Rect.fromLTWH(0, 0, cell * cols, cell * 2 + 40),
      Paint()..color = Colors.black,
    );
    for (var i = 0; i < frames.length; i++) {
      final (name, img) = frames[i];
      final dst = Rect.fromLTWH(
        (i % cols) * cell,
        (i ~/ cols) * (cell + 20) + 20,
        cell,
        cell,
      );
      c.drawImageRect(
        img,
        Rect.fromCenter(
          center: const Offset(772, 653),
          width: 352,
          height: 352,
        ),
        dst,
        Paint()..filterQuality = FilterQuality.medium,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, dst.topLeft + const Offset(8, -18));
    }
    final sheet = rec.endRecording().toImageSync(
      (cell * cols).round(),
      (rows * (cell + 20) + 20).round(),
    );
    final bytes = await sheet.toByteData(format: ui.ImageByteFormat.png);
    File('$out/orbs.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    final first = await frames.first.$2.toByteData(
      format: ui.ImageByteFormat.png,
    );
    File(
      '$out/frame_default.png',
    ).writeAsBytesSync(first!.buffer.asUint8List());
  });

  test('orb art sheet', () async {
    if (out == null) return;
    Directory(out).createSync(recursive: true);
    // The game's base zoom (0.595) on a 3x screen: about 1.8 px a unit.
    const scale = 1.8;
    const cell = 640.0;
    const cols = 4;
    final rows = (kOrbBases.length / cols).ceil();
    final w = cell * cols, h = cell * rows;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF05060A),
    );
    final r = Random(3);
    for (var i = 0; i < 500; i++) {
      c.drawCircle(
        Offset(r.nextDouble() * w, r.nextDouble() * h),
        r.nextDouble() * 1.1 + 0.3,
        Paint()
          ..color = Colors.white.withValues(
            alpha: 0.12 + r.nextDouble() * 0.35,
          ),
      );
    }
    for (var i = 0; i < kOrbBases.length; i++) {
      final def = kOrbBases[i];
      final t = 3.0 + i * 0.7;
      c.save();
      c.clipRect(
        Rect.fromLTWH((i % cols) * cell, (i ~/ cols) * cell, cell, cell),
      );
      c.translate((i % cols) * cell + cell / 2, (i ~/ cols) * cell + cell / 2);
      c.scale(scale);
      paintOrbField(c, def.skin, t);
      paintOrbCore(c, def.skin, t, beat: i == 2 ? 0.02 : 0.5);
      paintOrbReadings(
        c,
        def.skin,
        hpFrac: i == 5 ? 0.2 : 0.7,
        meterFrac: 0.4,
        // A boss wave's shield on one core, a large one overrunning the
        // health on another.
        shield: i == 0
            ? 0.06
            : i == 1
            ? 0.4
            : 0,
        time: t,
      );
      c.restore();
      final tp = TextPainter(
        text: TextSpan(
          text: def.name,
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset((i % cols) * cell + 12, (i ~/ cols) * cell + 10));
    }
    final img = rec.endRecording().toImageSync(w.round(), h.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$out/orb_art.png').writeAsBytesSync(bytes!.buffer.asUint8List());

    // Close up, without the readings, as the menus show them.
    const big = 300.0;
    final rec2 = ui.PictureRecorder();
    final c2 = Canvas(rec2);
    c2.drawRect(
      const Rect.fromLTWH(0, 0, big * 8, big),
      Paint()..color = const Color(0xFF05060A),
    );
    for (var i = 0; i < kOrbBases.length; i++) {
      c2.save();
      c2.translate(i * big + big / 2, big / 2);
      paintOrbCore(c2, kOrbBases[i].skin, 2.5 + i, radius: big * 0.28);
      c2.restore();
    }
    final img2 = rec2.endRecording().toImageSync(
      (big * 8).round(),
      big.round(),
    );
    final b2 = await img2.toByteData(format: ui.ImageByteFormat.png);
    File('$out/orb_cores.png').writeAsBytesSync(b2!.buffer.asUint8List());
  });
}
