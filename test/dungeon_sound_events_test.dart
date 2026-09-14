import 'package:flutter_test/flutter_test.dart';
import 'package:alchemons/audio/sound_cue.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';

PlanetDungeonGame atLintel(String element, List<SoundCue> sounds) {
  final member = CosmicPartyMember(
    instanceId: 'test',
    baseId: 'test',
    displayName: 'Test',
    element: element,
    family: 'horn',
    level: 10,
    statSpeed: 3,
    statIntelligence: 3,
    statStrength: 3,
    statBeauty: 3,
    slotIndex: 0,
    staminaBars: 3,
    staminaMax: 3,
  );
  final game = PlanetDungeonGame(
    element: 'Earth',
    party: [member],
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    onSound: sounds.add,
  );
  game.creatures.add(
    DungeonCreature(member: member)
      ..position = kBarrowLintel
      ..lastSafe = kBarrowLintel,
  );
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('lifting the lintel sounds once; repeating an open gate does not', () {
    final sounds = <SoundCue>[];
    final game = atLintel('Earth', sounds);
    game.activateAbility();
    expect(game.entryDoorRevealed, isTrue);
    expect(
      sounds.where((cue) => cue == SoundCue.dungeonGateOpen),
      hasLength(1),
    );
    game.activateAbility();
    expect(
      sounds.where((cue) => cue == SoundCue.dungeonGateOpen),
      hasLength(1),
    );
  });
  test('wrong element never plays a successful gate opening', () {
    final sounds = <SoundCue>[];
    final game = atLintel('Water', sounds);
    game.activateAbility();
    expect(game.entryDoorRevealed, isFalse);
    expect(sounds, isNot(contains(SoundCue.dungeonGateOpen)));
  });

  // THE INTERACT CUE IS A FALLBACK, NOT A GREETING.
  //
  // `dungeonInteract` used to be the FIRST line of activateAbility, before
  // anything had decided whether the press meant something. So it played on
  // a working press, on a refused one, and on a press into empty air — the
  // audio said the same thing about all three, in every one of seventeen
  // dungeons, which is the same as saying nothing while still being loud.
  group('the press has to have done something to sound like it did', () {
    test('a verb with its own cue does not also get the generic one', () {
      final sounds = <SoundCue>[];
      final game = atLintel('Earth', sounds);
      game.activateAbility();
      expect(sounds, contains(SoundCue.dungeonGateOpen));
      expect(
        sounds,
        isNot(contains(SoundCue.dungeonInteract)),
        reason: 'the lintel said something better; two cues for one press',
      );
    });

    test('a refused press sounds refused, not successful', () {
      final sounds = <SoundCue>[];
      // Water at the Earth lintel: the stone answers earthen strength and
      // turns the press down.
      final game = atLintel('Water', sounds);
      game.activateAbility();
      expect(sounds, contains(SoundCue.uiDenied));
      expect(
        sounds,
        isNot(contains(SoundCue.dungeonInteract)),
        reason: 'a refusal must not sound like a success',
      );
    });

    test('an open gate refusing a second press sounds refused', () {
      final sounds = <SoundCue>[];
      final game = atLintel('Earth', sounds);
      game.activateAbility(); // opens it
      sounds.clear();
      game.activateAbility(); // already open — refused
      expect(sounds, contains(SoundCue.uiDenied));
      expect(
        sounds,
        isNot(contains(SoundCue.dungeonInteract)),
        reason: 'a refusal must not sound like a success',
      );
    });
  });
}
