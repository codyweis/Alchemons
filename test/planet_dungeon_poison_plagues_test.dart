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

/// Run the crawl out to the walk, then actually fight the thing: drain each
/// bar, work the gate that follows it, three times.
///
/// Killing the body outright is no longer a thing a test can do — that is the
/// point of the gates — so this plays the fight the way a player has to.
void _fightItOut(PlanetDungeonGame g) {
  g.currentRoomId = 'ambulatory';
  for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
    g.update(1 / 60);
  }
  final body = g.combatEnemies.where((e) => !e.isDead);
  expect(
    body,
    isNotEmpty,
    reason: 'the crawl has to END in something to fight',
  );
  expect(g.monastery.bars, kPlagueBars);

  var guard = 0;
  while (g.monastery.fighting != null && guard++ < 200) {
    if (!g.monastery.gated) {
      _emptyTheBar(g);
      continue;
    }
    _workTheGate(g);
  }
  expect(g.monastery.fighting, isNull, reason: 'the plague never went down');
}

/// Empty the current bar THE WAY COMBAT DOES: every damage site in the
/// engine flags the enemy dead the instant its health reaches zero, and the
/// cull sweeps it out of the list in the same frame.
///
/// Setting `hp = 0` and nothing else is what every test here used to do, and
/// it is why the fight passed headlessly while dying outright on a phone —
/// the tick got to read the zero before anything else had reacted to it.
void _emptyTheBar(PlanetDungeonGame g) {
  final e = g.monastery.body!;
  e.hp = 0;
  e.isDead = true; // as `_damageEnemy` does
  g.combatEnemies.remove(e); // as the combat cull does
  g.update(1 / 60);
}

/// Do whatever this plague's mechanic asks: walk a creature onto each mark
/// and hold it there until the mark is finished.
void _workTheGate(PlanetDungeonGame g) {
  final m = g.monastery;
  expect(m.marks, isNotEmpty, reason: 'a gate with nothing to do is a stall');
  for (var i = 0; i < m.marks.length; i++) {
    final c = g.creatures[i % g.creatures.length];
    var guard = 0;
    while (!m.marks[i].done && guard++ < 400) {
      // Re-read the position every tick: a spore-pod is moving.
      c
        ..position = m.marks[i].at
        ..lastSafe = m.marks[i].at;
      g.update(1 / 60);
      if (!m.gated) return; // the gate resolved or timed out under us
    }
    expect(m.marks[i].done, isTrue, reason: 'mark $i would not finish');
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

    test('a plague is three bars, and each one ends in its own gate', () {
      final g = _game();
      final p = kPlaguePotions.first;
      _brewAndWake(g, p);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      expect(g.monastery.bars, kPlagueBars);

      var gates = 0;
      var guard = 0;
      while (g.monastery.fighting != null && guard++ < 200) {
        if (!g.monastery.gated) {
          _emptyTheBar(g);
          if (g.monastery.gated) gates++;
          continue;
        }
        _workTheGate(g);
      }
      expect(
        gates,
        kPlagueBars,
        reason:
            'every bar ends in a gate — including the last, so the '
            'mechanic is how it dies rather than an interruption on the way',
      );
      expect(g.monastery.slain, contains(p.id));
    });

    test('nothing lands on a closed plague', () {
      final g = _game();
      _brewAndWake(g, kPlaguePotions.first);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      final body = g.monastery.body!;
      _emptyTheBar(g);
      expect(g.monastery.gated, isTrue);
      expect(
        body.hp,
        greaterThan(0),
        reason: 'a bar running out must not kill it — the gate does that',
      );
      expect(
        body.isDead,
        isFalse,
        reason:
            'combat flags it dead the instant the bar empties; the fight has '
            'to take that back, or the plague drops its reliquary on the '
            'first bar and there is no fight at all',
      );
      expect(
        g.combatEnemies,
        contains(body),
        reason: 'and the cull took it out of the room — put it back',
      );
      expect(g.monastery.slain, isEmpty);
      expect(g.monastery.relicsDropped, isEmpty);
      expect(
        g.venomGated(body),
        isTrue,
        reason:
            'hitting it harder has to stop being an option, or the mechanic '
            'is decoration',
      );
    });

    test('letting the gate run out heals the bar back', () {
      final g = _game();
      _brewAndWake(g, kPlaguePotions.first);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      final body = g.monastery.body!;
      _emptyTheBar(g);
      expect(g.monastery.gated, isTrue);
      final barsAtGate = g.monastery.bars;

      // Stand well clear and wait it out.
      for (final c in g.creatures) {
        c.position = const Offset(60, 60);
        c.lastSafe = const Offset(60, 60);
      }
      for (var i = 0; i < 60 * 20 && g.monastery.gated; i++) {
        g.update(1 / 60);
      }
      expect(g.monastery.gated, isFalse);
      expect(
        g.monastery.bars,
        barsAtGate,
        reason: 'a gate that timed out takes no bar off it',
      );
      expect(
        body.hp,
        body.maxHp,
        reason: 'and the bar you had just emptied comes back full',
      );
      expect(g.monastery.fighting, isNotNull);
    });

    test('the gate is long enough to think in', () {
      // The standing rule on this game is that a puzzle rewards thinking and
      // never reflexes. A heal-back gate is the one place that rule is under
      // real pressure, so the window is pinned here rather than left to
      // whatever a constant happens to say — and it is MEASURED off the
      // engine, so tuning the constant cannot quietly turn the fight into a
      // reaction test.
      final g = _game();
      _brewAndWake(g, kPlaguePotions.first);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      _emptyTheBar(g);
      expect(g.monastery.gated, isTrue);
      for (final c in g.creatures) {
        c.position = const Offset(60, 60);
        c.lastSafe = const Offset(60, 60);
      }
      var frames = 0;
      while (g.monastery.gated && frames < 60 * 60) {
        g.update(1 / 60);
        frames++;
      }
      final seconds = frames / 60;

      // Long enough to walk the length of the cloister and back, at the
      // game's own walking speed, with time left to decide anything.
      final walk = poisonLayout.rooms['ambulatory']!.bounds;
      const speed = 187.5; // PlanetDungeonGame._speed
      expect(
        seconds,
        greaterThan(walk.width / speed * 1.4),
        reason:
            'a gate of ${seconds}s cannot be crossed at a walk — that is a '
            'reaction test, which this game does not do',
      );
      // …and short enough that ignoring the mechanic is not a strategy.
      expect(seconds, lessThan(30));
    });

    test('every plague brings a different mechanic', () {
      // Three fights that play the same way are one fight run three times.
      final g = _game();
      final kinds = <CauldronReaction>{};
      for (final p in kPlaguePotions) {
        _brewAndWake(g, p);
        g.currentRoomId = 'ambulatory';
        for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
          g.update(1 / 60);
        }
        _emptyTheBar(g);
        expect(g.monastery.gated, isTrue);
        expect(
          g.monastery.marks.length,
          greaterThan(0),
          reason: '${p.id} opened a gate with nothing to do in it',
        );
        kinds.add(p.pot);
        // Finish the fight so the next brew can be made.
        var guard = 0;
        while (g.monastery.fighting != null && guard++ < 200) {
          if (!g.monastery.gated) {
            _emptyTheBar(g);
            continue;
          }
          _workTheGate(g);
        }
        _bearRelic(g, p);
      }
      expect(kinds.length, kPlaguePotions.length);
    });

    test('the thing you fight is the thing that arrived', () {
      // `spawnDungeonEnemy` brings everything in from off the viewport,
      // which is right for an ambush and exactly wrong here: the plague you
      // watched crawl the length of the cloister would wink out and a
      // different body would walk in from the wall a second later. The whole
      // point of the crawl is that it IS the boss.
      final g = _game();
      final p = kPlaguePotions.first;
      _brewAndWake(g, p);
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 14 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      final landed = g.monastery.invadeTo;
      expect(g.monastery.body, isNotNull);
      expect(
        (g.monastery.body!.position - landed).distance,
        lessThan(4),
        reason: 'the body stands where the crawl put it',
      );
      expect(
        poisonLayout.rooms['ambulatory']!.bounds.contains(
          g.monastery.body!.position,
        ),
        isTrue,
        reason: 'and inside the room, not off the edge of it',
      );
    });

    test('the crawl is slow enough to watch', () {
      // It is the one look at the thing before it is a fight. Measured off
      // the engine rather than read off a constant, so tuning cannot quietly
      // turn the arrival back into a blink.
      final g = _game();
      _brewAndWake(g, kPlaguePotions.first);
      g.currentRoomId = 'ambulatory';
      var frames = 0;
      while (g.monastery.invading && frames < 60 * 40) {
        g.update(1 / 60);
        frames++;
      }
      expect(
        frames / 60,
        greaterThan(6.0),
        reason: 'a crawl under six seconds reads as a teleport',
      );
    });

    test('a spent font stops answering, and gets out of the way', () {
      // The fight happens in the cloister, and the basin stood in the middle
      // of it. A fixture that is finished but still has a verb on it is the
      // exact shape of the bug that swallowed reliquary pickups earlier.
      final g = _game();
      _openTheCloister(g);
      final before = g.monastery.relicsDropped.length;
      _press(g, 'Poison', 'ambulatory', _font);
      expect(g.monastery.relicsDropped.length, before);
      // Drop a reliquary right on top of where the basin was and lift it.
      final p = kPlaguePotions.first;
      g.monastery.relicsDropped.add(p.id);
      g.monastery.relicAt[p.id] = _font;
      _press(g, 'Poison', 'ambulatory', _font);
      expect(
        g.monastery.carriedRelic,
        p.id,
        reason:
            'the spent basin must not answer a press meant for the '
            'reliquary lying on it',
      );
    });

    test('a stray wisp is not the boss', () {
      // A wrong pour leaves wisps in the cloister. The fight used to find
      // its body by scanning for the first live enemy that was not the
      // guardian, so one of those wisps could be taken for the plague — and
      // a single frame with no enemies at all read as the plague having
      // died, dropping its reliquary without a fight.
      final g = _game();
      _openTheCloister(g);
      final potion = kPlaguePotions.firstWhere((p) => p.id == 'bloomvenom');
      final wrongDoor = kPlaguePotions.firstWhere((p) => p.id == 'mirebane');
      _setDown(g);
      _press(g, potion.first, 'apothecary', _pot);
      _press(g, potion.second, 'apothecary', _pot);
      // Pour it at the wrong door on purpose: that is what puts wisps out.
      _press(g, 'Poison', wrongDoor.wardId!, _censer(wrongDoor.wardId!));
      g.currentRoomId = 'ambulatory';
      g.update(1 / 60);
      final strays = g.combatEnemies.where((e) => !e.isDead).length;

      // Now wake it properly.
      _press(g, 'Poison', potion.wardId!, _censer(potion.wardId!));
      g.currentRoomId = 'ambulatory';
      for (var i = 0; i < 60 * 10 && g.monastery.invading; i++) {
        g.update(1 / 60);
      }
      expect(g.monastery.fighting, potion.id);
      final body = g.monastery.body;
      expect(body, isNotNull);

      expect(
        strays,
        greaterThan(0),
        reason:
            'the wrong pour has to actually put something in the room, '
            'or this proves nothing',
      );
      expect(
        g.combatEnemies.indexOf(body!),
        greaterThan(0),
        reason:
            'the wisps came first — a scan for "the first live enemy" '
            'would hand back one of them',
      );

      // THE BITE. Empty the plague's own bar with wisps still alive. If the
      // fight is finding its body by scanning, it is watching a wisp's
      // health and this does nothing at all.
      _emptyTheBar(g);
      expect(
        g.monastery.gated,
        isTrue,
        reason: 'the bar that ran out was the PLAGUE\'s',
      );

      // And clearing the strays is not defeating anything.
      for (final e in g.combatEnemies) {
        if (!identical(e, body)) e.isDead = true;
      }
      g.update(1 / 60);
      expect(g.monastery.fighting, potion.id);
      expect(g.monastery.slain, isEmpty);
      expect(g.monastery.relicsDropped, isEmpty);
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
