// A wild Alchemon come upon asleep in open space: it stays where it is and
// starts no fight of its own, even a territorial one with the ship beside it,
// and it wakes (and lets its sleep sheet go) when it is fought. One with no
// sleep drawn for it is simply awake.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_actions.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

const _idle = 'creatures/rare/HOR01_firehorn_spritesheet.png';

CosmicPartyMember _horn({required bool drawn}) => CosmicPartyMember(
  instanceId: 'wild-horn-$drawn',
  baseId: 'HOR01',
  displayName: 'Firehorn',
  family: 'Horn',
  element: 'Fire',
  level: 10,
  slotIndex: 0,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  staminaBars: 5,
  staminaMax: 5,
  spriteSheet: drawn
      ? SpriteSheetDef(
          path: _idle,
          totalFrames: 8,
          rows: 2,
          frameSize: Vector2.all(1200),
          stepTime: 0.12,
        )
      : null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<CosmicGame> arena() async {
    final game = CosmicGame(
      world_: CosmicWorld.generate(seed: 37),
      onMeterChanged: () {},
    );
    game.ship = ShipComponent(pos: Offset.zero);
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.enemies.clear();
    game.activeBoss = null;
    return game;
  }

  Future<void> settle() => Future<void>.delayed(
    const Duration(milliseconds: 20),
  );

  test('asleep it stays put and starts no fight; fought, it wakes', () async {
    final game = await arena();
    final sleep = actionSheetFor(_idle, CreatureAction.sleep)!;
    for (final path in [_idle, sleep.path]) {
      final codec = await ui.instantiateImageCodec(
        File('assets/images/$path').readAsBytesSync(),
      );
      game.images.add(path, (await codec.getNextFrame()).image);
      codec.dispose();
    }
    // Territorial, well inside the range at which it would turn on the ship.
    final at = game.ship.pos + const Offset(120, 0);
    final wild = SpaceWildAlchemon(
      id: 'w1',
      member: _horn(drawn: true),
      rarity: 'Rare',
      position: at,
      territorial: true,
    );
    game.addWildAlchemon(wild, asleep: true);
    await settle();
    expect(wild.asleep, isTrue);

    for (var i = 0; i < 60 * 6; i++) {
      game.update(1 / 60);
    }
    expect(wild.asleep, isTrue);
    expect(wild.position, at, reason: 'it did not drift');
    expect(game.wildDuelActive, isFalse, reason: 'it did not pick a fight');

    game.engageWild(wild);
    expect(game.wildDuelActive, isTrue);
    expect(wild.asleep, isFalse);
    expect(game.images.containsKey(sleep.path), isFalse);
  });

  test('with no sleep drawn for it, it is awake', () async {
    final game = await arena();
    final wild = SpaceWildAlchemon(
      id: 'w2',
      member: _horn(drawn: false),
      rarity: 'Rare',
      position: game.ship.pos + const Offset(600, 0),
    );
    game.addWildAlchemon(wild, asleep: true);
    await settle();
    expect(wild.asleep, isFalse);
  });
}
