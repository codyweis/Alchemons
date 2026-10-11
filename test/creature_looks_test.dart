import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/creature_looks.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// What an Alchemon wears shows in every mode (author, 2026-10-11: "Do all
/// our effects show in survival cosmic etc?" — survival and the dungeons
/// drew neither its aura nor its costumes, and the dungeons not its
/// genetics colours either).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// How many pixels [draw] leaves lit on a clear 160 square, drawn about
  /// its middle.
  Future<int> litPixels(void Function(Canvas canvas) draw) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec)..translate(80, 80);
    draw(canvas);
    final image = await rec.endRecording().toImage(160, 160);
    final bytes = (await image.toByteData())!;
    image.dispose();
    var lit = 0;
    for (var i = 3; i < bytes.lengthInBytes; i += 4) {
      if (bytes.getUint8(i) > 8) lit++;
    }
    return lit;
  }

  test('an aura is drawn only when one is worn', () async {
    expect(await litPixels((c) => paintWornAura(c, null, 30, 1.2)), 0);
    expect(
      await litPixels((c) => paintWornAura(c, const SpriteVisuals(), 30, 1.2)),
      0,
    );
    const glowing = SpriteVisuals(alchemyEffect: 'alchemy_glow');
    expect(
      await litPixels((c) => paintWornAura(c, glowing, 30, 1.2)),
      greaterThan(100),
    );
  });

  test('costumes are drawn on the sprite only when worn', () async {
    final rec = ui.PictureRecorder();
    Canvas(rec);
    final blank = await rec.endRecording().toImage(64, 64);
    final sprite = Sprite(blank);
    final hat = WornCostumes('WNG04', {
      FamilyCostume.partyHat: FamilyCostume.partyHat.defaultColor,
    }).encode();
    expect(
      await litPixels(
        (c) => paintWornCostumes(c, const SpriteVisuals(), sprite, 0, 1),
      ),
      0,
    );
    expect(
      await litPixels(
        (c) => paintWornCostumes(c, SpriteVisuals(costumes: hat), sprite, 0, 1),
      ),
      greaterThan(20),
    );
  });

  test('a prismatic creature turns with time; a plain one does not', () {
    const plain = SpriteVisuals(hueShiftDeg: 40);
    const prismatic = SpriteVisuals(isPrismatic: true);
    expect(creatureGeneticsFilter(plain, 0), creatureGeneticsFilter(plain, 3));
    expect(
      creatureGeneticsFilter(prismatic, 0),
      isNot(creatureGeneticsFilter(prismatic, 3)),
    );
  });

  test('the aura grows with the sprite, within open space\'s bounds', () {
    expect(wornAuraRadius(40), 20);
    expect(wornAuraRadius(5), 10);
    expect(wornAuraRadius(400), 38);
  });

  test('survival and the dungeons draw what is worn', () {
    for (final path in [
      'lib/games/cosmic_survival/cosmic_survival_game.dart',
      'lib/games/planet_dungeon/planet_dungeon_game.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, contains('paintWornAura('), reason: path);
      expect(src, contains('paintWornCostumes('), reason: path);
    }
    expect(
      File(
        'lib/games/planet_dungeon/planet_dungeon_game.dart',
      ).readAsStringSync(),
      contains('creatureGeneticsFilter('),
    );
  });
}
