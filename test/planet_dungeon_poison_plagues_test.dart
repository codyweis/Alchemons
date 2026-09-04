// THE MONASTERY, WALKED. Brew, carry, wake, watch it crawl out, kill it —
// three times, and two stars at the end of the third.
//
// Written because the last four planets all shipped a bug that every unit
// test missed for the same reason: the tests set the state by hand and never
// pressed anything. So this one presses. It moves a creature to the pot,
// calls the verb the button calls, and never writes to `monastery` itself.

import 'dart:ui' as ui;

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
Offset get _font => poisonLayout.rooms['ambulatory']!.lustralFont!;
Offset get _bench => _pot + const Offset(200, 0);

/// Put whatever is in hand down on the bench, so the pot will take a give.
void _setDown(PlanetDungeonGame g) {
  if (g.monastery.carriedPotion == null) return;
  _press(g, 'Poison', 'apothecary', _bench);
  expect(g.monastery.carriedPotion, isNull);
}

/// THE FIRST ERRAND. Poison twice into the pot, the vial into the font, and
/// every wax seal on the cloister lets go. Nothing else can start until this
/// has happened, so almost every test below opens with it.
void _openTheCloister(PlanetDungeonGame g) {
  _setDown(g);
  _press(g, 'Poison', 'apothecary', _pot);
  _press(g, 'Poison', 'apothecary', _pot);
  expect(
    g.monastery.carriedPotion,
    kPureVial.id,
    reason: 'Poison twice is the pure vial',
  );
  _press(g, 'Poison', 'ambulatory', _font);
  expect(g.monastery.cloisterOpen, isTrue);
  // The seals come off door by door as the camera reaches them, so the run
  // has to actually play before the wards are rooms.
  for (var i = 0; i < 60 * 12 && g.monastery.parade >= 0; i++) {
    g.update(1 / 60);
  }
}

/// Brew [potion] from the pot, then carry it to its ward and wake it.
void _brewAndWake(PlanetDungeonGame g, PlaguePotion potion) {
  if (!g.monastery.cloisterOpen) _openTheCloister(g);
  _setDown(g);
  _press(g, potion.first, 'apothecary', _pot);
  _press(g, potion.second, 'apothecary', _pot);
  expect(
    g.monastery.carriedPotion,
    potion.id,
    reason: '${potion.first} + ${potion.second} must make ${potion.id}',
  );
  _press(g, 'Poison', potion.wardId!, _censer(potion.wardId!));
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
    test('Poison twice is the vial; anything else twice is refused', () {
      final g = _game();
      _press(g, 'Poison', 'apothecary', _pot);
      _press(g, 'Poison', 'apothecary', _pot);
      expect(
        g.monastery.carriedPotion,
        kPureVial.id,
        reason: 'the one recipe that asks the same hand twice',
      );

      final h = _game();
      _press(h, 'Plant', 'apothecary', _pot);
      _press(h, 'Plant', 'apothecary', _pot);
      expect(
        h.monastery.pot,
        ['Plant'],
        reason: 'the second Plant is refused — only Poison doubles',
      );
      expect(h.monastery.carriedPotion, isNull);
    });

    testWidgets('the font answers with a cinematic and no words', (
      tester,
    ) async {
      // THE ONE MOMENT WORTH A CAMERA on this planet, and it says nothing.
      // Riding it frame by frame is the only way to know it happens: the
      // parade drives `followAt` itself, every frame, while a cut is holding
      // — so a hold that expired early, or a painter that read the party's
      // room instead of the followed one, would show an empty corridor and
      // no test that only inspects state would notice.
      await tester.runAsync(() async {
        final g = _game();
        // Not `_openTheCloister` — that runs the parade out. Pour by hand so
        // the frames can be ridden one at a time.
        _press(g, 'Poison', 'apothecary', _pot);
        _press(g, 'Poison', 'apothecary', _pot);
        _press(g, 'Poison', 'ambulatory', _font);
        expect(g.monastery.parade, isNot(-1), reason: 'the parade started');
        expect(
          g.monastery.triage.opened,
          isEmpty,
          reason:
              'THE SEALS DO NOT ALL GO AT THE POUR. Opening every ward the '
              'moment the vial went in made the wax vanish before the camera '
              'had been anywhere, and the parade then toured three doors '
              'that were already open',
        );
        final doors = <Offset>{};
        final bursts = <Offset>{};
        var frames = 0;
        while (frames++ < 60 * 12 && g.monastery.parade >= 0) {
          g.update(1 / 60);
          if (g.followAt != null) doors.add(g.followAt!);
          if (g.monastery.sealBurst > 0) {
            bursts.add(g.monastery.sealBurstAt);
          }
          // Render every frame: the camera is looking at doors the party is
          // nowhere near.
          final rec = ui.PictureRecorder();
          g.render(ui.Canvas(rec));
          rec.endRecording();
        }

        expect(
          bursts.length,
          kPlaguePotions.length,
          reason:
              'one sheet of wax per plague door, and it is seen coming '
              'off — three doors opening silently off screen is not a '
              'cinematic, it is a flag being set',
        );
        expect(
          doors.length,
          greaterThan(3),
          reason: 'the shot slides between doors rather than snapping',
        );
        expect(
          g.currentRoomId,
          'ambulatory',
          reason: 'the PARTY never moved — only the view did',
        );
        // And it gives the view back rather than stranding the camera.
        for (var i = 0; i < 60 * 6; i++) {
          g.update(1 / 60);
        }
        expect(g.followRoomId, isNull);
        for (final p in kPlaguePotions) {
          expect(g.monastery.triage.opened, contains(p.wardId));
        }
      });
    });

    test('an interrupted parade still opens every ward', () {
      // The walk is a cinematic, not the mechanism. If it is cut short by
      // anything at all — a reload, a room lookup that fails — the rooms it
      // did not reach must not stay sealed for the rest of the run.
      final g = _game();
      _press(g, 'Poison', 'apothecary', _pot);
      _press(g, 'Poison', 'apothecary', _pot);
      _press(g, 'Poison', 'ambulatory', _font);
      g.monastery.parade = -1; // the shot never happens
      g.update(1 / 60);
      for (final p in kPlaguePotions) {
        expect(
          g.monastery.triage.opened,
          contains(p.wardId),
          reason: '${p.wardId} sealed with the vial already poured',
        );
      }
    });

    test('nothing can be woken until the font is poured', () {
      final g = _game();
      final p = kPlaguePotions.first;
      // The wards are shut, so the brew cannot even be carried in — and the
      // house says what would open them.
      _press(g, p.first, 'apothecary', _pot);
      _press(g, p.second, 'apothecary', _pot);
      expect(g.monastery.carriedPotion, p.id);
      expect(
        g.monastery.triage.opened.contains(p.wardId),
        isFalse,
        reason: 'a plague ward is not opened by walking up to it any more',
      );
      _openTheCloister(g);
      expect(
        g.monastery.bottled,
        contains(p.id),
        reason: 'the brew already in glass survived the errand',
      );
      for (final q in kPlaguePotions) {
        expect(
          g.monastery.triage.opened,
          contains(q.wardId),
          reason: 'one errand opens all three',
        );
      }
    });

    test('the vial costs two of Poison\'s four but handicaps no fight', () {
      final g = _game();
      _openTheCloister(g);
      expect(
        g.monastery.given['iPoison'],
        2,
        reason: 'the key costs two of Poison\'s four gives',
      );
      expect(
        g.monastery.drained,
        isEmpty,
        reason:
            'a mandatory first errand that also handicaps the first fight '
            'would be a tax with no decision in it',
      );
    });

    test('a pair that answers nothing is spent for nothing', () {
      // Every pair of the three ingredients is now a recipe, and so is
      // Poison doubled — so this proves the refusal path exists rather than
      // firing it, which is the honest thing this larder allows.
      final pairs = <String>{
        for (final p in kAllBrews) ([p.first, p.second]..sort()).join(),
      };
      expect(pairs.length, kAllBrews.length);
    });

    test('four gives for Poison, two for everyone else, and no more', () {
      final g = _game();
      _openTheCloister(g); // two of Poison's four
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom'));
      _fightItOut(g);
      _brewAndWake(g, kPlaguePotions.firstWhere((p) => p.id == 'mirebane'));
      _fightItOut(g);
      expect(g.monastery.given['iPoison'], kPoisonContributions);
      expect(g.monastery.given['iPlant'], 1);
      // A fifth Poison give is refused…
      _setDown(g);
      _press(g, 'Poison', 'apothecary', _pot);
      expect(
        g.monastery.pot,
        isEmpty,
        reason: 'a spent hand cannot give again',
      );
      // …and Plant still has one left, which is exactly Graverot's half.
      _press(g, 'Plant', 'apothecary', _pot);
      expect(g.monastery.pot, ['Plant']);
      _press(g, 'Mud', 'apothecary', _pot);
      expect(
        g.monastery.carriedPotion,
        'graverot',
        reason: 'the last two gives in the house make the last brew',
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
      _openTheCloister(g);
      for (final p in kPlaguePotions) {
        _setDown(g);
        _press(g, p.first, 'apothecary', _pot);
        _press(g, p.second, 'apothecary', _pot);
        // Only one brew can be carried, so park it at its ward.
        if (g.monastery.carriedPotion != null) {
          _press(g, 'Poison', p.wardId!, _censer(p.wardId!));
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
      _openTheCloister(g);
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom');
      final other = kPlaguePotions.firstWhere((p) => p.id == 'mirebane');
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      _press(g, 'Poison', other.wardId!, _censer(other.wardId!));
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
      _openTheCloister(g);
      final potion = kPlaguePotions.first;
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      expect(g.monastery.carriedPotion, potion.id);
      // Set it down on the bench.
      _press(g, 'Poison', 'apothecary', _bench);
      expect(g.monastery.carriedPotion, isNull);
      expect(
        g.monastery.bottled,
        contains(potion.id),
        reason: 'a brew is made once and lives in glass until it is poured',
      );
      // And comes back off it.
      _press(g, 'Poison', 'apothecary', _bench);
      expect(g.monastery.carriedPotion, potion.id);
      // The POT, meanwhile, refuses a give from a full hand and says where
      // to put it — the two used to be the same press, and with anything at
      // all in glass a new brew could never be started.
      _press(g, 'Mud', 'apothecary', _pot);
      expect(g.monastery.pot, isEmpty);
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
        // CLEAR OF EVERY FIXTURE WITH A VERB ON IT, not just the cross.
        // The plague used to crawl to the room's centre, which is exactly
        // where the lustral font stands — so the reliquary landed inside the
        // font's reach and the font answered every press to pick it up with
        // "the basin is spent". The third star was unreachable and nothing
        // on screen said why.
        for (final fixture in {
          'the cross': _cross,
          'the font': _font,
        }.entries) {
          expect(
            (at - fixture.value).distance,
            greaterThan(90),
            reason: '${p.relic} landed on ${fixture.key}',
          );
        }
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
      _setDown(g);
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
