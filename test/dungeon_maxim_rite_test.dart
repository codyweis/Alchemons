// How a lost secret pays out: the Rite of Three.
//
// All seventeen used to end the same way — a permanent change to the room and
// a hint popup carrying an italic quotation from a dead philosopher. The
// change was the good part; the quotation was a label on it.
//
// What pays out now is a REACTION built from the party you brought: the three
// elements are drawn out of your creatures, bound over the thing you found,
// and the binding throws the gold. The things worth pinning are the ones that
// are easy to break and expensive to get wrong — the gold must arrive exactly
// once, it must arrive even if the player dies or walks off mid-reaction, and
// it must never arrive twice.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flame/game.dart' show Vector2;
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _m(String e, String f) => CosmicPartyMember(
  instanceId: '$e$f',
  baseId: 'b',
  displayName: '$e $f',
  imagePath: null,
  element: e,
  family: f,
  level: 10,
  statSpeed: 4,
  statIntelligence: 4,
  statStrength: 4,
  statBeauty: 4,
  slotIndex: -1,
  staminaBars: 9,
  staminaMax: 9,
);

PlanetDungeonGame _game(String element, List<String> discovered) {
  final els = kCosmicPlanetEntry[element]!;
  final fams = kDungeonIdealFamilies[element]!;
  final party = [
    for (var i = 0; i < els.length; i++) _m(els[i], fams[i].toLowerCase()),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
    onCloudDiscovered: discovered.add,
  );
  g.currentRoomId = g.layout.entranceRoomId;
  final at = g.currentRoom.bounds.center;
  for (final m in party) {
    g.creatures.add(DungeonCreature(member: m)..position = at..lastSafe = at);
  }
  g.onGameResize(Vector2(412, 915));
  return g;
}

void _run(PlanetDungeonGame g, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    g.update(1 / 60);
  }
}

const _egg = 'egg:test_rite';

void main() {
  test('the reaction runs before the gold arrives', () {
    final found = <String>[];
    final g = _game('Air', found);
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    expect(g.riteActive, isTrue);
    _run(g, 1.0);
    expect(
      found,
      isEmpty,
      reason: 'the elements are still travelling — nothing has bound yet',
    );
    _run(g, 2.0);
    expect(found, [_egg], reason: 'the binding pays');
  });

  test('and it ends', () {
    final g = _game('Air', []);
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    _run(g, 6.0);
    expect(g.riteActive, isFalse);
  });

  test('the gold arrives exactly once', () {
    final found = <String>[];
    final g = _game('Air', found);
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    _run(g, 6.0);
    // A re-entered room, a re-triggered object: the secret is already found.
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    _run(g, 6.0);
    expect(found, [_egg]);
    expect(g.riteActive, isFalse, reason: 'a found secret does not replay');
  });

  test('a second trigger during the reaction does not double it', () {
    final found = <String>[];
    final g = _game('Air', found);
    final at = g.currentRoom.bounds.center;
    g.beginMaximRite(_egg, at);
    _run(g, 0.5);
    g.beginMaximRite(_egg, at);
    _run(g, 6.0);
    expect(found, [_egg]);
  });

  test('walking out mid-reaction still pays — the find is not taken back', () {
    // The failure this prevents is the cruel one: the player triggers the
    // secret, leaves the room on the next step, and the payout is lost with
    // the animation that was carrying it.
    final found = <String>[];
    final g = _game('Air', found);
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    _run(g, 0.4);
    expect(found, isEmpty);
    g.currentRoomId = 'hub';
    _run(g, 0.2);
    expect(found, [_egg], reason: 'settled on the way out');
    expect(g.riteActive, isFalse);
  });

  test('a fallen party member still lends its element', () {
    // You brought three. One dying on the way down does not remove its colour
    // from the reaction — it was part of the descent.
    final g = _game('Air', []);
    for (final c in g.creatures.skip(1)) {
      c.hp = 0;
    }
    g.beginMaximRite(_egg, g.currentRoom.bounds.center);
    _run(g, 6.0);
    // No throw, and it still completed: the render reads the party, not the
    // survivors.
    expect(g.riteActive, isFalse);
  });

  test('every planet can run one', () {
    // The rite is shared machinery — all seventeen secrets will use it, and a
    // layout whose entrance is shaped oddly must not break it.
    for (final element in kPlanetDungeonLayouts.keys) {
      final found = <String>[];
      final g = _game(element, found);
      g.beginMaximRite(_egg, g.currentRoom.bounds.center);
      _run(g, 6.0);
      expect(found, [_egg], reason: element);
    }
  });
}
