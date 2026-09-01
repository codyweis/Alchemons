// VERDANTHOS — the Verdant Crypt, pinned.
//
// Plant's topology is NESTED SCALES: one geometry, two bodies, and passages
// cut for exactly one of them (docs §5.5). Its world edit — a seed bed — is
// irreversible and its trunk DELETES a crack, so this file carries the two
// proofs the design cannot ship without:
//
//  1. THE NO-STRAND PROOF. A full reachability search over
//     (room × scale × every bed's state), enumerated under player moves AND
//     Botanica's spore burst, audited using only the moves the player
//     controls. Being stuck at the wrong scale is this planet's own named
//     hazard, so it is measured separately from the room count.
//  2. SOLVABILITY. The authored trio walks the whole descent — all three
//     stars, the vault and the lost maxim — verb by verb, against the real
//     rules.
//
// The rest pins the scale rule, the bed trade, the two hard gates, the vault
// trick and the guardian.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(int slot, String element, String family) =>
    CosmicPartyMember(
      instanceId: 'inst_$slot',
      baseId: 'base_$slot',
      displayName: '$element $family',
      element: element,
      family: family,
      level: 10,
      statSpeed: 3,
      statIntelligence: 5,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

/// The §6 ideal trio: Plantmane · Lightmask · Mudpip.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Plant', 'mane'),
  _member(1, 'Light', 'mask'),
  _member(2, 'Mud', 'pip'),
];

const int plant = 0, light = 1, mud = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Plant',
    party: party,
    initialStarMask: 0,
    onStarEarned: onStar ?? (_) {},
    onCloudDiscovered: onCloud,
    onPlayerDown: () => fail('the scripted run must never wipe'),
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  for (final m in party) {
    final c = DungeonCreature(member: m)
      ..position = game.layout.entranceSpawn
      ..lastSafe = game.layout.entranceSpawn;
    game.creatures.add(c);
    final stats = deriveCosmicSurvivalCompanionStats(member: m);
    game.combatCompanions.add(
      CosmicSurvivalCompanion(
        member: m,
        slotIndex: m.slotIndex,
        position: c.position,
        anchor: c.position,
        maxHp: stats.maxHp,
        currentHp: stats.maxHp,
        physAtk: stats.physAtk,
        elemAtk: stats.elemAtk,
        physDef: stats.physDef,
        elemDef: stats.elemDef,
        cooldownReduction: stats.cooldownReduction,
        critChance: stats.critChance,
        attackRange: stats.attackRange,
        specialAbilityRange: stats.specialAbilityRange,
        tethered: false,
        invincibleTimer: 0,
      ),
    );
  }
  return game;
}

/// Stand [idx] on [pos] in [room] and press the verb. Every body moves with
/// it, because the Mud+Light braid is a two-body verb and has to be able to
/// happen (§6's recipe).
void act(PlanetDungeonGame game, int idx, String room, Offset pos) {
  game.currentRoomId = room;
  game.setActive(idx);
  for (final c in game.creatures) {
    c
      ..position = pos
      ..lastSafe = pos;
  }
  game.activateAbility();
}

/// Stand the party ON a door and let a frame run: that is the only way a
/// sealed door's BLOCKED line is spoken (§5.6 is attempt-edged), so the test
/// reads it exactly the way the player hears it.
String? doorHint(PlanetDungeonGame game, String room, DungeonDoor door) {
  game.currentRoomId = room;
  for (final c in game.creatures) {
    c
      ..position = door.rect.center
      ..lastSafe = door.rect.center;
  }
  game.hintText = null;
  game.update(1 / 60);
  // The world no longer speaks a refusal — it records one and flashes. The
  // player learns WHY by pressing HINT, so that is what a hint assertion has
  // to do too.
  game.askForRoomHint();
  return game.hintText;
}

Offset bedOf(String id) => cryptBedById(id)!.crown;
Offset lampOf(String id) => kGraveLamps.firstWhere((l) => l.id == id).position;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final layout = kPlanetDungeonLayouts['Plant']!;

  group('the crypt — one geometry, two sizes', () {
    test('every span is a real door pair, and every pair is one span', () {
      final pairs = <String>{};
      for (final s in kCryptSpans) {
        final a = layout.rooms[s.from];
        final b = layout.rooms[s.to];
        expect(a, isNotNull, reason: '${s.id} from ${s.from}');
        expect(b, isNotNull, reason: '${s.id} to ${s.to}');
        expect(
          a!.doors.any((d) => d.targetRoomId == s.to),
          isTrue,
          reason: '${s.id}: no door ${s.from} → ${s.to}',
        );
        expect(
          b!.doors.any((d) => d.targetRoomId == s.from),
          isTrue,
          reason: '${s.id}: no door back ${s.to} → ${s.from}',
        );
        final key = ([s.from, s.to]..sort()).join('|');
        expect(
          pairs.add(key),
          isTrue,
          reason: 'one room pair, one span — $key is authored twice',
        );
      }
      // And the other way: no door in the crypt is outside the span graph, or
      // the proof would be walking a different map from the player.
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          expect(
            cryptSpanBetween(room.id, d.targetRoomId),
            isNotNull,
            reason: '${room.id} → ${d.targetRoomId} has no span',
          );
        }
      }
    });

    test('a span that needs a bed names one, and a permanent one does not', () {
      for (final s in kCryptSpans) {
        if (s.bedId == null) {
          expect(s.need, isNull, reason: s.id);
          continue;
        }
        expect(s.need, isNotNull, reason: s.id);
        expect(cryptBedById(s.bedId!), isNotNull, reason: s.id);
        // The products are roads for the size you were NOT: a creeper is only
        // ever a small way, a trunk only ever a large one. That symmetry is
        // the planet's whole grammar, so it is pinned rather than assumed.
        if (s.need == SpanNeed.creeper) {
          expect(s.size, SpanSize.tinyOnly, reason: s.id);
        }
        if (s.need == SpanNeed.trunk) {
          expect(s.size, SpanSize.hugeOnly, reason: s.id);
        }
        if (s.need == SpanNeed.fissure) {
          expect(s.size, SpanSize.tinyOnly, reason: s.id);
        }
      }
      for (final b in kCryptBeds) {
        expect(layout.rooms[b.roomId], isNotNull, reason: b.id);
        expect(
          layout.rooms[b.roomId]!.bounds.contains(b.crown),
          isTrue,
          reason: '${b.id} must stand inside its own room',
        );
      }
    });

    test('the vault is a pocket you can always walk back out of', () {
      // §5.5's declared trick for Plant is "visible at huge scale, enterable
      // only at tiny" — so the rim door is tinyOnly, and it is PERMANENT: no
      // bed can ever take it away behind you (Ice's shelf rule). Without that
      // the vault is a trap, and the search says so.
      final cacheRoom = layout.rooms.values.singleWhere(
        (r) => r.vaultCache != null,
      );
      expect(cacheRoom.doors.length, 1, reason: 'the vault must be a pocket');
      final rim = cryptSpanBetween(
        cacheRoom.id,
        cacheRoom.doors.single.targetRoomId,
      )!;
      expect(rim.size, SpanSize.tinyOnly);
      expect(rim.bedId, isNull, reason: 'the rim door is never a vine');
      // And the room it hangs off is the growth altar's own — the bowl you can
      // stand over at huge and see the little door in.
      expect(
        layout.rooms[cacheRoom.doors.single.targetRoomId]!.grove?.growthAltar,
        isNotNull,
      );
    });

    test('a virgin crypt is already connected at BOTH sizes', () {
      // §4's first-descent guarantee, geometrically: before anything is
      // planted, the large graph reaches every large room and the small graph
      // reaches every small room the star content lives in — and both of them
      // contain a gall, so a first descent can always change back.
      final crypt = VerdantCrypt();
      Set<String> walk(PlantScale size) {
        final seen = <String>{layout.entranceRoomId};
        final q = [layout.entranceRoomId];
        while (q.isNotEmpty) {
          final r = q.removeLast();
          for (final d in layout.rooms[r]!.doors) {
            final s = cryptSpanBetween(r, d.targetRoomId)!;
            if (!crypt.spanExists(s) || !crypt.spanFits(s, size)) continue;
            if (seen.add(d.targetRoomId)) q.add(d.targetRoomId);
          }
        }
        return seen;
      }

      final big = walk(PlantScale.huge);
      expect(
        big,
        containsAll([
          'mosswalk',
          'lantern_court',
          'islet',
          'bloom_hall',
          'botanica_heart',
        ]),
      );
      expect(big, isNot(contains('crypt_niche')));
      expect(big, isNot(contains('gourd_hollow')));

      // The small graph is walked from the porch too — a first descent starts
      // large and shrinks at the porch's own gall.
      final small = walk(PlantScale.tiny);
      expect(small, contains('crypt_niche'));
      expect(
        small.any((r) => layout.rooms[r]!.grove?.bole != null),
        isTrue,
        reason: 'a small body must always be able to find a gall',
      );
    });
  });

  group('the scale rule', () {
    test(
      'a gall is the only thing that changes your size, and it is two-way',
      () {
        final g = harness(_idealTrio());
        expect(g.crypt.scale, PlantScale.huge);
        // No gall in the moss walk: pressing the verb there changes nothing.
        act(g, plant, 'mosswalk', const Offset(450, 300));
        expect(g.crypt.scale, PlantScale.huge);
        final gall = layout.rooms['root_porch']!.grove!.bole!;
        act(g, plant, 'root_porch', gall);
        expect(g.crypt.scale, PlantScale.tiny);
        act(g, plant, 'root_porch', gall);
        expect(g.crypt.scale, PlantScale.huge);
      },
    );

    test(
      'the gall is element-only, and Mud+Light braids for a downed Plant',
      () {
        // §4: the planet's own grammar can never be family-gated, and §6's
        // Mud+Light→Plant recipe substitutes the ELEMENT.
        final g = harness([
          _member(0, 'Mud', 'pip'),
          _member(1, 'Light', 'mask'),
          _member(2, 'Water', 'wing'),
        ]);
        final gall = layout.rooms['root_porch']!.grove!.bole!;
        act(g, 0, 'root_porch', gall); // the Mud body, with a Light beside it
        expect(g.crypt.scale, PlantScale.tiny, reason: 'the braid must plant');

        final lone = harness([
          _member(0, 'Water', 'wing'),
          _member(1, 'Water', 'pip'),
          _member(2, 'Water', 'mask'),
        ]);
        act(lone, 0, 'root_porch', gall);
        expect(lone.crypt.scale, PlantScale.huge);
        lone.askForRoomHint();
        expect(lone.hintText, contains('Plant'));
      },
    );

    test('a door refuses the wrong body, and says which way it is wrong', () {
      final g = harness(_idealTrio());
      final porch = layout.rooms['root_porch']!;
      final flagGap = porch.doors.singleWhere(
        (d) => d.targetRoomId == 'pollen_stair',
      );
      // Large: the flagstone gap is a hairline.
      g.entryDoorRevealed = true;
      expect(g.isDoorLocked(porch, flagGap), isTrue);
      expect(doorHint(g, 'root_porch', flagGap), contains('Too big'));
      g.crypt.scale = PlantScale.tiny;
      expect(g.isDoorLocked(porch, flagGap), isFalse);
      // …and now the arch is fine but the rill is a river.
      final walk = layout.rooms['mosswalk']!;
      final rill = walk.doors.singleWhere((d) => d.targetRoomId == 'islet');
      expect(g.isDoorLocked(walk, rill), isTrue);
      expect(doorHint(g, 'mosswalk', rill), contains('Too small'));
    });
  });

  group('the beds — scale-determined authorship', () {
    test('a huge hand gets a creeper and a tiny hand gets a trunk', () {
      final g = harness(_idealTrio());
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.creeper);

      final h = harness(_idealTrio());
      h.crypt.scale = PlantScale.tiny;
      act(h, plant, 'fern_gallery', bedOf('b_root'));
      expect(h.crypt.stateOf('b_root'), VineState.trunk);
    });

    test('a bed takes ONE seed for the run, and a trunk fills its fissure', () {
      final g = harness(_idealTrio());
      g.crypt.scale = PlantScale.tiny;
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.trunk);
      // The worm-run is gone for good — the very crack you climbed down to
      // set the seed in.
      final gallery = layout.rooms['fern_gallery']!;
      final wormRun = gallery.doors.singleWhere(
        (d) => d.targetRoomId == 'crypt_niche',
      );
      g.entryDoorRevealed = true;
      expect(g.isDoorLocked(gallery, wormRun), isTrue);
      expect(doorHint(g, 'fern_gallery', wormRun), contains('Grown shut'));
      // And the bed will not take a second seed, at either size.
      g.crypt.scale = PlantScale.huge;
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.trunk);
    });

    test('THE TRAP: b_root\'s trunk costs the only small road to the islet', () {
      // The sharpest instance, authored on purpose (§5.5): b_root's creeper is
      // the ONE small way across the rill, and Star 1's seeding and the vault
      // both want it. Committing the trunk instead is legal, recoverable only
      // by the withering, and the crypt never warns you.
      final g = harness(_idealTrio());
      g.crypt.scale = PlantScale.tiny;
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      final small = <String>{layout.entranceRoomId};
      final q = [layout.entranceRoomId];
      while (q.isNotEmpty) {
        final r = q.removeLast();
        for (final d in layout.rooms[r]!.doors) {
          final s = cryptSpanBetween(r, d.targetRoomId)!;
          if (!g.crypt.spanExists(s) || !g.crypt.spanFits(s, PlantScale.tiny)) {
            continue;
          }
          if (small.add(d.targetRoomId)) q.add(d.targetRoomId);
        }
      }
      expect(small, isNot(contains('islet')));
      expect(small, isNot(contains('gourd_hollow')));
    });
  });

  group('THE NO-STRAND PROOF', () {
    final g = harness(_idealTrio());
    final r = g.solveVerdantCrypt();

    test('no state reachable by legal play can strand the party', () {
      expect(
        r.strandable,
        0,
        reason:
            'from every one of ${r.states} states the world can reach, every '
            'room in the crypt must still be reachable',
      );
    });

    test('the party can NEVER be stuck at the wrong size — not even without '
        'the valve', () {
      // This planet's OWN named hazard (§5.5) is shifting somewhere you cannot
      // shift back from, and it is eliminated by GEOMETRY rather than paid for
      // by the valve: the three galls are placed so that every small component
      // the world can actually put you in contains one. Measured with the
      // withering DELETED, so it is a fact about the map and not about the
      // take-back.
      expect(
        r.sizeLocked,
        0,
        reason:
            'a gall must stand in every small component reachable by legal '
            'play — move one and this is the test that catches it',
      );
    });

    test('THE WITHERING is load-bearing, not decoration', () {
      // Ice measured 120/122, Mud 1200/1284, Dust 319/396. If this ever drops
      // to zero someone has quietly made a trunk reversible.
      expect(
        r.strandableWithoutWithering,
        greaterThan(0),
        reason: 'delete the valve and the crypt must strand',
      );
      // ignore: avoid_print
      print(
        'Verdanthos: ${r.states} states / ${r.arrangements} arrangements · '
        'strandable ${r.strandable} · without the withering '
        '${r.strandableWithoutWithering} · vault losable ${r.vaultLosable} · '
        'size-locked ${r.sizeLocked}',
      );
    });

    test('the vault really can be lost — that is the price of the trick', () {
      expect(r.vaultLosable, greaterThan(0));
      expect(
        r.vaultLosable,
        lessThan(r.states),
        reason: 'and it must not be lost from the opening state',
      );
    });

    test(
      'the exit, every star room and the vault survive every state, by name',
      () {
        // Names, not counts: a renamed room must break this test rather than
        // quietly shrink the guarantee.
        const mustLive = [
          'root_porch',
          'lantern_court',
          'islet',
          'crypt_niche',
          'bloom_hall',
          'botanica_heart',
          'gourd_hollow',
        ];
        for (final id in mustLive) {
          expect(layout.rooms.containsKey(id), isTrue, reason: id);
        }
        expect(r.strandable, 0);
      },
    );
  });

  group('Star 0 — THE GRAVE-LAMPS (ungated)', () {
    test('a lamp answers Light, and only a body of its own size', () {
      final g = harness(_idealTrio());
      // The niche's wick is thumb-sized: no large hand goes in it.
      g.crypt.scale = PlantScale.huge;
      act(g, light, 'crypt_niche', lampOf('lamp_niche'));
      expect(g.crypt.lampsLit, isEmpty);
      g.askForRoomHint();
      expect(g.hintText, contains('size'));
      g.crypt.scale = PlantScale.tiny;
      act(g, light, 'crypt_niche', lampOf('lamp_niche'));
      expect(g.crypt.lampsLit, contains('lamp_niche'));
      // …and the sconce is a world above a small body's head.
      act(g, light, 'mosswalk', lampOf('lamp_walk'));
      expect(g.crypt.lampsLit, isNot(contains('lamp_walk')));
    });

    test('the wrong element is refused, whatever size it is', () {
      final g = harness(_idealTrio());
      act(g, mud, 'mosswalk', lampOf('lamp_walk'));
      expect(g.crypt.lampsLit, isEmpty);
      g.askForRoomHint();
      expect(g.hintText, contains('Light'));
    });

    test('§4 FIRST DESCENT: any trio of the right elements banks Star 0', () {
      // No Mane, no Mask, no Pip anywhere — and no bed committed and no vine
      // grown. This is the star §4 guarantees, and it is why §6's Plantmane
      // gate had to move off it.
      var banked = <int>{};
      final g = harness([
        _member(0, 'Plant', 'kin'),
        _member(1, 'Light', 'wing'),
        _member(2, 'Mud', 'horn'),
      ], onStar: banked.add);

      final porchGall = layout.rooms['root_porch']!.grove!.bole!;
      act(g, plant, 'root_porch', porchGall); // huge → tiny
      act(g, light, 'crypt_niche', lampOf('lamp_niche'));
      act(g, plant, 'root_porch', porchGall); // tiny → huge
      act(g, light, 'mosswalk', lampOf('lamp_walk'));
      expect(banked, isEmpty);
      act(g, light, 'lantern_court', lampOf('lamp_court'));

      expect(g.crypt.allLampsLit, isTrue);
      expect(banked, contains(0));
      expect(g.hasStar(0), isTrue);
      for (final b in kCryptBeds) {
        expect(
          g.crypt.stateOf(b.id),
          VineState.bare,
          reason: 'the first-descent star must cost no ground',
        );
      }
    });
  });

  group('Star 1 — THE GROWTH ALTAR', () {
    test('the three steps come in the order the ground puts them in', () {
      final g = harness(_idealTrio());
      final altar = layout.rooms['islet']!.grove!.growthAltar!;
      // Seed first, at the wrong size and out of turn: nothing moves.
      act(g, plant, 'islet', altar);
      expect(g.crypt.bloomStep, 0);
      act(g, mud, 'islet', altar);
      expect(g.crypt.bloomStep, 1);
      // Now the seed, and it wants a small body.
      act(g, plant, 'islet', altar);
      expect(g.crypt.bloomStep, 1);
      g.askForRoomHint();
      expect(g.hintText, contains('big'));
      g.crypt.scale = PlantScale.tiny;
      act(g, plant, 'islet', altar);
      expect(g.crypt.bloomStep, 2);
    });

    test('the sun is a HARD gate, and refusing it stamps the chip', () {
      var clouds = <String>[];
      final g = harness([
        _member(0, 'Plant', 'mane'),
        _member(1, 'Light', 'wing'), // Light, wrong family
        _member(2, 'Mud', 'pip'),
      ], onCloud: clouds.add);
      final altar = layout.rooms['islet']!.grove!.growthAltar!;
      act(g, mud, 'islet', altar);
      g.crypt.scale = PlantScale.tiny;
      act(g, plant, 'islet', altar);
      g.crypt.scale = PlantScale.huge;
      act(g, light, 'islet', altar);
      expect(g.crypt.bloomWoken, isFalse);
      expect(clouds, contains('gate:light_mask'));
    });

    test('THE AUTHORED SOLUTION wakes the heart-seed and banks the star', () {
      var banked = <int>{};
      final g = harness(_idealTrio(), onStar: banked.add);
      final altar = layout.rooms['islet']!.grove!.growthAltar!;
      act(g, mud, 'islet', altar);
      g.crypt.scale = PlantScale.tiny;
      act(g, plant, 'islet', altar);
      g.crypt.scale = PlantScale.huge;
      act(g, light, 'islet', altar);
      expect(g.crypt.bloomWoken, isTrue);
      expect(banked, contains(1));
    });
  });

  group('the withering — the valve', () {
    test('it takes two turns, and the first one names the price', () {
      final g = harness(_idealTrio());
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.creeper);
      final pit = layout.rooms['fern_gallery']!.grove!.mulchPit!;
      act(g, mud, 'fern_gallery', pit);
      expect(g.crypt.stateOf('b_root'), VineState.creeper);
      expect(g.crypt.armedPitRoom, 'fern_gallery');
      act(g, mud, 'fern_gallery', pit);
      expect(g.crypt.stateOf('b_root'), VineState.bare);
      expect(g.crypt.witherings, 1);
    });

    test('it puts you out at the gate, in your own body', () {
      // The load-bearing half: a small body on the islet has ONE small road
      // out, and it is the very creeper the season takes away.
      final g = harness(_idealTrio());
      g.crypt.scale = PlantScale.tiny;
      final pit = layout.rooms['islet']!.grove!.mulchPit!;
      act(g, mud, 'islet', pit);
      act(g, mud, 'islet', pit);
      expect(g.currentRoomId, layout.entranceRoomId);
      expect(g.crypt.scale, PlantScale.huge);
    });

    test('it is element-only Mud, and it declines a fallow crypt', () {
      final g = harness(_idealTrio());
      final pit = layout.rooms['mosswalk']!.grove!.mulchPit!;
      act(g, plant, 'mosswalk', pit);
      expect(g.crypt.armedPitRoom, isNull);
      g.askForRoomHint();
      expect(g.hintText, contains('Mud'));
      act(g, mud, 'mosswalk', pit);
      expect(g.crypt.armedPitRoom, isNull, reason: 'nothing to turn');
      g.askForRoomHint();
      expect(g.hintText, contains('fallow'));
    });

    test('a banked star survives the season', () {
      final g = harness(_idealTrio());
      act(g, light, 'mosswalk', lampOf('lamp_walk'));
      final pit = layout.rooms['mosswalk']!.grove!.mulchPit!;
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      act(g, mud, 'mosswalk', pit);
      act(g, mud, 'mosswalk', pit);
      expect(g.crypt.lampsLit, contains('lamp_walk'));
    });
  });

  group('the rite and the guardian', () {
    test('the rood screen is a HARD Plant+Mane gate', () {
      final hall = layout.rooms['bloom_hall']!;
      final conduit = hall.conduits.single;
      expect(conduit.id, 'A');
      expect(conduit.requireElement, 'Plant');
      expect(conduit.requiredFamily, DungeonAbility.terrainTrail);
      final gate = layout.familyGateFor('A')!;
      expect(gate.element, 'Plant');
      expect(gate.family, 'Mane');
      // §4's budget: two gates, on two objects, on two different entry slots,
      // and NOT on Star 0.
      expect(layout.familyGates.length, 2);
      expect(layout.familyGates.map((x) => x.element).toSet(), {
        'Plant',
        'Light',
      });
    });

    test('the sepulchre is element-only Mud, and waits on both stars', () {
      final g = harness(_idealTrio());
      final tomb = layout.rooms['bloom_hall']!.grove!.sepulchre!;
      act(g, mud, 'bloom_hall', tomb);
      expect(g.conduitEnergy['B'] ?? 0, 0);
      g.askForRoomHint();
      expect(g.hintText, contains(layout.starName(0)));
      g.starMask = 0x3;
      act(g, plant, 'bloom_hall', tomb);
      expect(g.conduitEnergy['B'] ?? 0, 0);
      act(g, mud, 'bloom_hall', tomb);
      expect(g.conduitEnergy['B'], double.infinity);
    });

    test('Botanica keeps its lull shut while you are your own size', () {
      final g = harness(_idealTrio());
      g.currentRoomId = 'botanica_heart';
      g.guardianAwake = true;
      g.guardianVulnerable = true;
      g.crypt.scale = PlantScale.huge;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      // Small enough to be at the stem: the window is allowed to stand.
      g.crypt.scale = PlantScale.tiny;
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isTrue);
    });

    test('every strike beat swells you back, and rots a road', () {
      final g = harness(_idealTrio());
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.creeper);
      g.currentRoomId = 'botanica_heart';
      g.guardianAwake = true;
      g.crypt.scale = PlantScale.tiny;
      g.guardianVulnerable = true;
      g.update(1 / 60); // the window opens
      g.guardianVulnerable = false;
      g.update(1 / 60); // the beat lands
      expect(g.crypt.scale, PlantScale.huge);
      expect(g.crypt.stateOf('b_root'), VineState.bare);
    });

    test('the arena\'s root-gall only ever shrinks, and the rood door is '
        'scale-free', () {
      final g = harness(_idealTrio());
      final gall = layout.rooms['botanica_heart']!.grove!.rootBole!;
      act(g, plant, 'botanica_heart', gall);
      expect(g.crypt.scale, PlantScale.tiny);
      act(g, plant, 'botanica_heart', gall);
      expect(g.crypt.scale, PlantScale.tiny, reason: 'no way back up in here');
      final rood = cryptSpanBetween('bloom_hall', 'botanica_heart')!;
      expect(rood.size, SpanSize.both);
      expect(rood.bedId, isNull);
    });
  });

  group('the lost maxim — THE UNSEEN SHADE', () {
    test(
      'tend it small with all three, then look at it from your own size',
      () {
        var clouds = <String>[];
        final g = harness(_idealTrio(), onCloud: clouds.add);
        final seed = layout.rooms['fern_gallery']!.grove!.shadeSeed!;
        // A large body cannot even see under the root.
        act(g, mud, 'fern_gallery', seed);
        expect(g.crypt.tendedBy, isEmpty);
        g.crypt.scale = PlantScale.tiny;
        act(g, mud, 'fern_gallery', seed);
        act(g, light, 'fern_gallery', seed);
        act(g, plant, 'fern_gallery', seed);
        expect(g.crypt.tendedBy.length, 3);
        expect(clouds, isNot(contains(kPlantUnseenShadeEggId)));
        // And it only towers for someone who can stand back and look.
        act(g, plant, 'fern_gallery', seed);
        expect(clouds, isNot(contains(kPlantUnseenShadeEggId)));
        g.crypt.scale = PlantScale.huge;
        act(g, plant, 'fern_gallery', seed);
        // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
        for (var tick = 0; tick < 200; tick++) {
          g.update(1 / 60);
        }
        expect(clouds, contains(kPlantUnseenShadeEggId));
        expect(g.crypt.shadeRisen, isTrue);
      },
    );
  });

  group('the descent', () {
    test('the planet is descendable, with the §6 trio and riddle', () {
      expect(kCosmicPlanetEntry['Plant'], ['Plant', 'Light', 'Mud']);
      expect(kDungeonIdealFamilies['Plant'], ['Mane', 'Mask', 'Pip']);
      expect(kComingSoonDungeons, isNot(contains('Plant')));
      expect(layout.riddle.length, 3);
      // INVERTED (see dungeon_riddle_naming_test.dart): the riddle now names
      // the element and the family outright. Encoding them made sense while
      // the verse was the only warning of what a gate wanted; the descent
      // panel declares and enforces them now, so an encoded line is a puzzle
      // whose answer sits directly beneath it.
      // A family is named only where a gate demands one (Plant's third slot
      // is ungated), so this pins the elements and leaves the family rule to
      // dungeon_riddle_naming_test.dart.
      final els = kCosmicPlanetEntry['Plant']!;
      for (var i = 0; i < layout.riddle.length; i++) {
        expect(layout.riddle[i].toLowerCase(), contains(els[i].toLowerCase()));
      }
    });

    test('THE WHOLE DESCENT: the authored trio walks it end to end', () {
      var banked = <int>{};
      var clouds = <String>[];
      final g = harness(_idealTrio(), onStar: banked.add, onCloud: clouds.add);

      final porchGall = layout.rooms['root_porch']!.grove!.bole!;
      final briar = layout.rooms['root_porch']!.grove!.briarGate!;
      final altar = layout.rooms['islet']!.grove!.growthAltar!;
      final tomb = layout.rooms['bloom_hall']!.grove!.sepulchre!;

      // The gate.
      act(g, plant, 'root_porch', briar);
      expect(g.entryDoorRevealed, isTrue);

      // Star 0 — the three lamps, two bodies, no ground spent.
      act(g, light, 'mosswalk', lampOf('lamp_walk'));
      act(g, light, 'lantern_court', lampOf('lamp_court'));
      act(g, plant, 'root_porch', porchGall);
      act(g, light, 'crypt_niche', lampOf('lamp_niche'));
      expect(banked, contains(0));

      // The road to the islet at the small size: b_root's creeper, and it can
      // only be planted by a body that came at the OTHER size.
      act(g, plant, 'root_porch', porchGall); // back to your own size
      act(g, plant, 'fern_gallery', bedOf('b_root'));
      expect(g.crypt.stateOf('b_root'), VineState.creeper);

      // Star 1 — three arrivals at two sizes.
      act(g, mud, 'islet', altar);
      act(g, plant, 'pollen_stair', layout.rooms['pollen_stair']!.grove!.bole!);
      expect(g.crypt.isTiny, isTrue);
      act(g, plant, 'islet', altar);
      // The vault, while a small body is out here anyway.
      act(g, plant, 'gourd_hollow', layout.rooms['gourd_hollow']!.vaultCache!);
      act(g, plant, 'pollen_stair', layout.rooms['pollen_stair']!.grove!.bole!);
      act(g, light, 'islet', altar);
      expect(banked, contains(1));
      expect(g.guardianRiteUnlocked, isTrue);

      // The rite: the Mane's screen is the engine's conduit; the clay is ours.
      act(g, mud, 'bloom_hall', tomb);
      expect(g.conduitEnergy['B'], double.infinity);

      // And the crypt is walkable, at some size, from end to end throughout.
      expect(g.solveVerdantCrypt().strandable, 0);
    });
  });
}
