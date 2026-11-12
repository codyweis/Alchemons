// A creature firing its special in the games that draw their own party
// (games/shared/creature_fire.dart): its fire sheet plays once from the cast,
// drawn at the size its idle is, and is gone when it has played through. An
// albino fires in its own baked copy of the sheet.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/shared/creature_fire.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_actions.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const idle = 'creatures/uncommon/PIP01_firepip_spritesheet.png';
  final own = SpriteSheetDef(
    path: idle,
    totalFrames: 8,
    rows: 2,
    frameSize: Vector2.all(1200),
    stepTime: 0.12,
  );

  Future<Images> cache() async {
    final images = Images();
    final def = actionSheetFor(idle, CreatureAction.fire)!;
    final codec = await ui.instantiateImageCodec(
      File('assets/images/${def.path}').readAsBytesSync(),
    );
    images.add(def.path, (await codec.getNextFrame()).image);
    codec.dispose();
    return images;
  }

  test('every fire species has its sheet beside its idle sheet', () {
    expect(kFireSpecies, isNotEmpty);
    expect(
      File(
        'assets/images/${idle.replaceAll('_spritesheet', '_fire')}',
      ).existsSync(),
      isTrue,
    );
  });

  test(
    'it plays once from the cast, at the idle\'s size, then is gone',
    () async {
      final images = await cache();
      final fire = CreatureFire(() => images);
      fire.warm(own, const SpriteVisuals());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(fire.of(0), isNull);
      fire.play(0, own, const SpriteVisuals());
      final playing = fire.of(0);
      expect(playing, isNotNull, reason: 'warmed: it starts on the cast');
      // A 1200 px idle frame over a 600 px fire frame.
      expect(playing!.sizeRatio, 2);
      expect(playing.ticker.currentIndex, 0);

      fire.tick(0, 0.2);
      expect(fire.of(0)!.ticker.currentIndex, greaterThan(2));
      for (var i = 0; i < 60; i++) {
        fire.tick(0, 1 / 60);
      }
      expect(fire.of(0), isNull, reason: 'played through');
    },
  );

  test('an albino fires in its own baked copy, at its idle\'s size', () async {
    final images = await cache();
    final fire = CreatureFire(() => images);
    const albino = SpriteVisuals(brightness: 1.45, saturation: 0);
    fire.play(0, own, albino);
    // The bake runs on another isolate.
    for (var i = 0; i < 100 && fire.of(0) == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    final playing = fire.of(0);
    expect(playing, isNotNull);
    // Its idle and its attack are both baked at 512 px a frame.
    expect(playing!.sizeRatio, 1);
  });
}
