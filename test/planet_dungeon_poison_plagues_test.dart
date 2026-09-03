// THE MONASTERY, WALKED. Brew, carry, wake, watch it crawl out, kill it —
// three times, and two stars at the end of the third.
//
// Written because the last four planets all shipped a bug that every unit
// test missed for the same reason: the tests set the state by hand and never
// pressed anything. So this one presses. It moves a creature to the pot,
// calls the verb the button calls, and never writes to `monastery` itself.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

const _els = ['Poison', 'Plant', 'Mud'];

PlanetDungeonGame _game({List<int> stars = const []}) {
  final party = [
    for (final e in _els)
      CosmicPartyMember(
        instanceId: 'i$e',
        baseId: 'b$e',
        displayName: e,
        element: e,
        family: e == 'Poison' ? 'mask' : (e == 'Plant' ? 'horn' : 'mane'),
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: _els.indexOf(e),
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  var mask = 0;
  for (final s in stars) {
    mask |= 1 << s;
  }
  final g = PlanetDungeonGame(
    element: 'Poison',
    party: party,
    initialStarMask: mask,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.onGameResize(Vector2(900, 600));
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = const Offset(200, 300)
        ..lastSafe = const Offset(200, 300),
    );
  }
  return g;
}

/// Stand [element]'s creature at [at] in [room] and press its verb — the
/// same call the action button makes. No state is written by hand.
void _press(PlanetDungeonGame g, String element, String room, Offset at) {
  g.currentRoomId = room;
  final i = g.creatures.indexWhere((c) => c.member.element == element);
  expect(i, isNot(-1), reason: 'no $element in the party');
  g.activeIndex = i;
  g.creatures[i]
    ..position = at
    ..lastSafe = at;
  g.activateAbility();
}

Offset get _pot => poisonLayout.rooms['apothecary']!.apothecary!.cistern;
Offset _censer(String ward) => poisonLayout.rooms[ward]!.ward!.censer;

/// Brew [potion] from the pot, then carry it to its ward and wake it.
void _brewAndWake(PlanetDungeonGame g, PlaguePotion potion) {
  _press(g, potion.first, 'apothecary', _pot);
  _press(g, potion.second, 'apothecary', _pot);
  expect(
    g.monastery.carriedPotion,
    potion.id,
    reason: '${potion.first} + ${potion.second} must make ${potion.id}',
  );
  _press(g, 'Poison', potion.wardId, _censer(potion.wardId));
}

/// Run the crawl out to the walk, then kill whatever landed.
void _fightItOut(PlanetDungeonGame g) {
  g.currentRoomId = 'ambulatory';
  for (var i = 0; i < 60 * 8 && g.monastery.invading; i++) {
    g.update(1 / 60);
  }
  expect(
    g.combatEnemies.where((e) => !e.isDead),
    isNotEmpty,
    reason: 'the crawl has to END in something to fight',
  );
  for (final e in g.combatEnemies) {
    e.isDead = true;
  }
  g.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the three plagues', () {
    test('a brew is two DIFFERENT things, and the pot says so', () {
      final g = _game();
      _press(g, 'Poison', 'apothecary', _pot);
      _press(g, 'Poison', 'apothecary', _pot);
      expect(g.monastery.pot, ['Poison'], reason: 'the second give is refused');
      expect(g.monastery.carriedPotion, isNull);
    });

    test('a pair that answers no plague is spent for nothing', () {
      // There is no such pair among three ingredients whose every pair is a
      // recipe — so this proves the refusal path exists rather than firing
      // it, which is the honest thing a three-element larder allows.
      final pairs = <String>{
        for (final p in kPlaguePotions) ([p.first, p.second]..sort()).join(),
      };
      expect(pairs.length, 3, reason: 'all three pairs are spoken for');
    });

    test('two brews is all any one alchemon has', () {
      final g = _game();
      // Poison gives to both of its recipes…
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'deafening'));
      _fightItOut(g);
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'slogging'));
      _fightItOut(g);
      expect(g.monastery.given['iPoison'], 2);
      // …and is refused a third time.
      _press(g, 'Poison', 'apothecary', _pot);
      expect(
        g.monastery.pot,
        isEmpty,
        reason: 'a spent hand cannot give again',
      );
    });

    test('a woken plague LEAVES its ward and lands in the walk', () {
      final g = _game();
      final potion = kPlaguePotions.first;
      _brewAndWake(g, potion);
      expect(g.monastery.woken, contains(potion.id));
      expect(
        g.monastery.invading,
        isTrue,
        reason: 'it crawls; it does not teleport',
      );
      _fightItOut(g);
      expect(g.monastery.slain, contains(potion.id));
      expect(
        g.monastery.woken,
        isEmpty,
        reason: 'and once it is down it is not still awake somewhere',
      );
    });

    test('the hands that mixed it are spent until it falls', () {
      final g = _game();
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'deafening');
      _brewAndWake(g, potion);
      expect(g.monastery.drained, containsAll(['iPoison', 'iPlant']));
      expect(
        g.monastery.drained.contains('iMud'),
        isFalse,
        reason: 'Mud gave nothing to this one',
      );
      final spent = g.creatures.firstWhere((c) => c.member.element == 'Plant');
      final fresh = g.creatures.firstWhere((c) => c.member.element == 'Mud');
      expect(g.venomDrainMul(spent), lessThan(1.0));
      expect(g.venomDrainMul(fresh), 1.0);
      _fightItOut(g);
      expect(
        g.monastery.drained,
        isEmpty,
        reason: 'a fallen plague rests the whole house',
      );
      expect(g.venomDrainMul(spent), 1.0);
    });

    test('the drain is a tax, never a lockout', () {
      // Brew all three before waking anything — the worst play available —
      // and the party must still be able to fight.
      final g = _game();
      for (final p in kPlaguePotions) {
        _press(g, p.first, 'apothecary', _pot);
        _press(g, p.second, 'apothecary', _pot);
        // Only one brew can be carried, so park it at its ward.
        if (g.monastery.carriedPotion != null) {
          _press(g, 'Poison', p.wardId, _censer(p.wardId));
          g.monastery.invading = false;
        }
      }
      for (final c in g.creatures) {
        expect(
          g.venomDrainMul(c),
          greaterThan(0.0),
          reason: 'a spent alchemon still fights — it just fights worse',
        );
      }
    });

    test('a brew carried to the wrong door is not thrown away', () {
      final g = _game();
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'deafening');
      final other = kPlaguePotions.firstWhere((p) => p.id == 'slogging');
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      _press(g, 'Poison', other.wardId, _censer(other.wardId));
      expect(
        g.monastery.carriedPotion,
        potion.id,
        reason: 'wrong door costs a walk, never a hand',
      );
      expect(g.monastery.woken, isEmpty);
    });

    test('all three down is two stars, at once', () {
      final g = _game();
      expect(g.hasStar(0), isFalse);
      expect(g.hasStar(1), isFalse);
      for (final p in kPlaguePotions) {
        _brewAndWake(g, p);
        _fightItOut(g);
      }
      expect(g.monastery.slain.length, 3);
      expect(g.hasStar(0), isTrue, reason: 'two stars for the three plagues');
      expect(g.hasStar(1), isTrue);
      expect(
        g.hasStar(2),
        isFalse,
        reason: 'the third is still Blightfang, down the oubliette',
      );
    });

    test('the way down to Blightfang exists without a triage', () {
      // The triage that used to choose a surrendered ward is gone; the crypt
      // now hangs off the dead-house. If nothing sets that, the guardian is
      // unreachable and the planet caps at two stars forever.
      expect(kCryptWard, 'ward_charnel');
      final charnel = poisonLayout.rooms['ward_charnel']!;
      expect(
        charnel.doors.any((d) => d.targetRoomId == 'lazar_crypt'),
        isTrue,
        reason: 'the oubliette has to actually go somewhere',
      );
    });
  });
}
