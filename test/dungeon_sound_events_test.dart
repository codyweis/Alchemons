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
}
