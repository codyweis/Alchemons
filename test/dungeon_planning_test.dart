import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame game(String element) {
  final party = [
    for (final (i, e) in kCosmicPlanetEntry[element]!.indexed)
      CosmicPartyMember(
        instanceId: '$i',
        baseId: '$i',
        displayName: e,
        element: e,
        family: 'mane',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  g.entryDoorRevealed = true;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

void stand(PlanetDungeonGame g, String room, Offset at) {
  g.currentRoomId = room;
  for (final c in g.creatures) {
    c.position = at;
    c.lastSafe = at;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the trellis root previews exactly where the tendril will go', () {
    final g = game('Plant');
    g.starMask = 1;
    stand(g, 'trellis_garden', kTrellisRootKnuckle);
    final t = g.greenhouse.trellis;
    expect(g.puzzlePreview, contains('It stops at dry earth'));
    t.watered = true;
    expect(g.puzzlePreview, contains('open water'));
    t.lit = TrellisLamp.west;
    expect(g.puzzlePreview, contains('the end of the west bed'));
    t.lit = TrellisLamp.east;
    t.frozen = true;
    final line = g.puzzlePreview!;
    expect(line, contains('It reaches the bud'));
    expect(line, contains('GROW · 6 tiles'));
    // Reading it changed nothing.
    expect(g.greenhouse.grown, isFalse);
  });

  test('Spirit raises no line when walking the bearers\' flags', () {
    final g = game('Spirit');
    final fr = g.layout.rooms['bearers_court']!.funeral!;
    for (var f = 0; f < 9; f++) {
      stand(g, 'bearers_court', fr.flagCentre(f));
      expect(g.puzzlePreview, isNull);
    }
  });

  test('Dark raises no planning line: the aim is drawn on the wall', () {
    // The Black Sun (2026-09-30) shows where a cast would land as a ghost
    // mouth on the face the Dark is looking at; a line would say it twice.
    final g = game('Dark');
    expect(g.puzzlePreview, isNull);
  });

  test('Light raises no planning line: the shadow floor shows itself', () {
    // The Shadow Floor (2026-09-28) has no hidden settings to forecast: every
    // shadow is drawn where it falls, and the floor it makes is the floor.
    final g = game('Light');
    expect(g.puzzlePreview, isNull);
  });

  test('Blood raises no planning line: its rooms show their own previews',
      () {
    final g = game('Blood');
    expect(g.puzzlePreview, isNull);
  });
}
