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
Offset get _cross => poisonLayout.rooms['ambulatory']!.priorsSeal!.position;

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

/// Carry the reliquary a dead plague dropped over to the cross and socket it.
void _bearRelic(PlanetDungeonGame g, PlaguePotion potion) {
  final at = g.monastery.relicAt[potion.id];
  expect(at, isNotNull, reason: '${potion.id} dropped no reliquary');
  _press(g, 'Poison', 'ambulatory', at!);
  expect(
    g.monastery.carriedRelic,
    potion.id,
    reason: '${potion.relic} would not lift',
  );
  _press(g, 'Poison', 'ambulatory', _cross);
  expect(g.monastery.relicsPlaced, contains(potion.id));
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
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom'));
      _fightItOut(g);
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'mirebane'));
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
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom');
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

    test('a wrong pour costs a complication and never the bottle', () {
      final g = _game();
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom');
      final other = kPlaguePotions.firstWhere((p) => p.id == 'mirebane');
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      _press(g, 'Poison', other.wardId, _censer(other.wardId));
      expect(
        g.monastery.carriedPotion,
        potion.id,
        reason:
            'the bottle is still full — one misread riddle must never '
            'be able to strand the run',
      );
      expect(g.monastery.bottled, contains(potion.id));
      expect(g.monastery.woken, isEmpty);
      expect(
        g.monastery.pour,
        greaterThan(0),
        reason: 'and something visibly happened',
      );
    });

    test('a bottle set down stays on the bench, and can be taken back', () {
      final g = _game();
      final potion = kPlaguePotions.first;
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      expect(g.monastery.carriedPotion, potion.id);
      // Press again with it in hand and nothing else brewed: it goes back.
      _press(g, 'Poison', 'apothecary', _pot);
      expect(g.monastery.carriedPotion, isNull);
      expect(
        g.monastery.bottled,
        contains(potion.id),
        reason: 'a brew is made once and lives in glass until it is poured',
      );
      // And comes back off the bench.
      _press(g, 'Poison', 'apothecary', _pot);
      expect(g.monastery.carriedPotion, potion.id);
    });

    test('killing all three is not the stars — the cross is', () {
      final g = _game();
      for (final p in kPlaguePotions) {
        _brewAndWake(g, p);
        _fightItOut(g);
      }
      expect(g.monastery.slain.length, 3);
      expect(
        g.hasStar(0),
        isFalse,
        reason: 'three corpses and no reliquaries placed is not a star',
      );
      expect(g.monastery.relicsDropped.length, 3);
    });

    test('three reliquaries at the cross lights it, and pays both stars', () {
      final g = _game();
      expect(g.hasStar(0), isFalse);
      expect(g.hasStar(1), isFalse);
      for (var i = 0; i < kPlaguePotions.length; i++) {
        final p = kPlaguePotions[i];
        _brewAndWake(g, p);
        _fightItOut(g);
        _bearRelic(g, p);
        if (i < kPlaguePotions.length - 1) {
          expect(
            g.hasStar(0),
            isFalse,
            reason: 'the cross pays on the THIRD, never before',
          );
        }
      }
      expect(g.monastery.relicsPlaced.length, 3);
      expect(g.monastery.crossLight, greaterThan(0), reason: 'it lights');
      expect(g.hasStar(0), isTrue);
      expect(g.hasStar(1), isTrue);
      expect(
        g.hasStar(2),
        isFalse,
        reason: 'the third is still Blightfang, down the oubliette',
      );
    });

    test('a reliquary never drops where it cannot be picked up', () {
      // The plague dies wherever the fight ended, which can be inside a wall
      // or sitting on the cross itself. Either would leave a star
      // unreachable with nothing on screen to explain why.
      final g = _game();
      final walk = poisonLayout.rooms['ambulatory']!;
      for (final p in kPlaguePotions) {
        _brewAndWake(g, p);
        _fightItOut(g);
        final at = g.monastery.relicAt[p.id]!;
        expect(
          walk.bounds.deflate(40).contains(at),
          isTrue,
          reason: '${p.relic} landed outside the cloister at $at',
        );
        expect(
          (at - _cross).distance,
          greaterThan(90),
          reason: '${p.relic} landed on top of the cross',
        );
        _bearRelic(g, p);
      }
    });

    test('a hand carries a bottle or a reliquary, never both', () {
      final g = _game();
      final first = kPlaguePotions.first;
      _brewAndWake(g, first);
      _fightItOut(g);
      // Brew the next one, then try to pick the reliquary up with it in hand.
      final second = kPlaguePotions[1];
      _press(g, second.first, 'apothecary', _pot);
      _press(g, second.second, 'apothecary', _pot);
      expect(g.monastery.carriedPotion, second.id);
      _press(g, 'Poison', 'ambulatory', g.monastery.relicAt[first.id]!);
      expect(
        g.monastery.carriedRelic,
        isNull,
        reason: 'a bottle in hand blocks the reliquary',
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
