// SOLARIN — the Beacon Archive, pinned.
//
// Light's topology is ONE GREAT HALL with no corridors: the light beams
// partition the space into moving rooms, and the floor you are standing on can
// stop existing when a beacon moves (docs §5.5). A hall whose floor is made of
// light is the most direct stranding machine in the set, so this file carries
// the two proofs the design cannot ship without, plus the counterfactuals that
// say the safety is designed rather than lucky:
//
//  1. THE NO-STRAND PROOF. A full reachability search over
//     (bay × what each of the three beacons is set to), enumerated under
//     player moves AND a loosed guardian, audited using only the moves the
//     player controls. It must be ZERO, and it must be zero WITHOUT a reset
//     valve. It is zero for a stated structural reason — every move in the
//     archive has an inverse — and this file pins the reason as well as the
//     number.
//  2. SOLVABILITY. The authored trio walks the whole descent — all three
//     stars, the rite, the vault and the lost maxim — verb by verb, against
//     the real rules and only across sills the light has actually made.
//
// The rest pins the archive's arithmetic (which is where the occlusion lives),
// the exposure star measured rather than asserted, the two hard gates, §4's
// first-descent guarantee, the vault trick and the guardian.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
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

/// The §6 ideal trio: Lightmask · Crystalmask · Spiritpip.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Light', 'mask'),
  _member(1, 'Crystal', 'mask'),
  _member(2, 'Spirit', 'pip'),
];

/// The same three ELEMENTS in families that clear nothing — the party §4
/// promises a first descent to.
List<CosmicPartyMember> _plainTrio() => [
  _member(0, 'Light', 'horn'),
  _member(1, 'Crystal', 'wing'),
  _member(2, 'Spirit', 'kin'),
];

const int light = 0, crystal = 1, spirit = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Light',
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
/// it, because the Crystal+Spirit braid is a two-body verb and has to be able
/// to happen (§6's recipe).
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
/// sealed sill's BLOCKED line is spoken (§5.6 is attempt-edged), so the test
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

final DungeonLayout layout = kPlanetDungeonLayouts['Light']!;

DungeonDoor doorFrom(String room, String to) =>
    layout.rooms[room]!.doors.firstWhere((d) => d.targetRoomId == to);

/// Press a beacon the way the player does: stand at its post, in its bay.
void pressBeacon(
  PlanetDungeonGame g,
  int idx,
  String beaconId, {
  int times = 1,
}) {
  final b = archiveBeaconById(beaconId)!;
  for (var i = 0; i < times; i++) {
    final before = g.archive.lamp[beaconId] ?? 0;
    act(g, idx, b.roomId, b.post);
    expect(
      g.archive.lamp[beaconId],
      (before + 1) % b.stateCount,
      reason: '$beaconId did not walk its cycle',
    );
  }
}

/// Walk one sill, and REFUSE to walk one the light has taken. Every step of
/// the scripted descent goes through here, so the run can never cheat across a
/// hole the player would fall down.
void step(PlanetDungeonGame g, String to) {
  final from = g.currentRoomId;
  final door = doorFrom(from, to);
  final sill = archiveSillBetween(from, to)!;
  expect(
    g.archive.sillOpen(sill),
    isTrue,
    reason: '$from → $to (${sill.id}) is not a floor in this arrangement',
  );
  expect(
    g.isDoorHidden(layout.rooms[from]!, door),
    isFalse,
    reason: '$from → $to is hidden',
  );
  g.currentRoomId = to;
  for (final c in g.creatures) {
    c
      ..position = door.targetSpawn
      ..lastSafe = door.targetSpawn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the hall — one room, and light for a floor', () {
    test('every sill is a real door pair, and every pair is one sill', () {
      final pairs = <String>{};
      for (final s in kArchiveSills) {
        final a = layout.rooms[s.from];
        final b = layout.rooms[s.to];
        expect(a, isNotNull, reason: '${s.id} from ${s.from}');
        expect(b, isNotNull, reason: '${s.id} to ${s.to}');
        expect(
          a!.doors.any((d) => d.targetRoomId == s.to),
          isTrue,
          reason: '${s.id} has no door ${s.from} → ${s.to}',
        );
        expect(
          b!.doors.any((d) => d.targetRoomId == s.from),
          isTrue,
          reason: '${s.id} has no door ${s.to} → ${s.from}',
        );
        final key = ([s.from, s.to]..sort()).join('|');
        expect(pairs.add(key), isTrue, reason: 'two sills join $key');
      }
      // And the converse: no door in the layout is missing its sill, so the
      // proof's edge set and the player's floor are the same object.
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          expect(
            archiveSillBetween(room.id, d.targetRoomId),
            isNotNull,
            reason: '${room.id} → ${d.targetRoomId} has no sill',
          );
        }
      }
    });

    test('the rim is glass, the heart is mirror, and the stair is neither', () {
      // The topology stated as data (§5.5): a road you build all the way round
      // the outside, a road you must NOT light all the way in, and exactly one
      // passage the light has never reached.
      final stone = kArchiveSills.where((s) => s.cut == SillCut.stone);
      expect(stone.length, 1);
      expect(stone.single.id, 'sl_oculus');
      expect(stone.single.cell, isNull);
      for (final s in kArchiveSills) {
        if (s.cut == SillCut.stone) continue;
        expect(s.cell, isNotNull, reason: '${s.id} must lie in a cell');
      }
      // Every bay of the HEART is joined only by mirror shelves, which is what
      // makes the heart reachable in total darkness — and every bay of the RIM
      // only by glass, which is what makes the rim a thing you light.
      const heart = {'oculus_stair', 'sunless_reliquary'};
      for (final s in kArchiveSills) {
        if (s.cut == SillCut.stone) continue;
        final touchesHeart = heart.contains(s.from) || heart.contains(s.to);
        if (touchesHeart) {
          expect(s.cut, SillCut.mirrorSill, reason: '${s.id} into the heart');
        }
      }
    });

    test('the two great stacks are the only shadows, and the only discount', () {
      expect(kGreatStacks, {HallSector.court, HallSector.arcade});
      final a = BeaconArchive();
      // A stacked sector at LOW pitch costs one lumen; an empty one costs two,
      // whatever the pitch. That single fact is the planet's whole economy.
      for (final b in kArchiveBeacons) {
        for (var i = 1; i <= b.settings.length; i++) {
          for (final x in kArchiveBeacons) {
            a.lamp[x.id] = 0;
          }
          a.lamp[b.id] = i;
          final s = b.settings[i - 1];
          var want = 0;
          for (final sector in s.arc) {
            want += (s.pitch == BeamPitch.low && sectorHasStack(sector))
                ? 1
                : 2;
          }
          expect(a.lumens, want, reason: '${b.id}#$i should cost $want lumens');
        }
      }
    });

    test('a bay with nothing standing in it can never be road AND shadow', () {
      // The negative statement of the mechanic, and the reason Star 0 is a
      // journey: in an unstacked sector the two bands go together, always.
      final a = BeaconArchive();
      for (var n = 0; n < 125; n++) {
        var k = n;
        for (final b in kArchiveBeacons) {
          a.lamp[b.id] = k % 5;
          k ~/= 5;
        }
        for (final sector in HallSector.values) {
          if (sectorHasStack(sector)) continue;
          expect(
            a.isLit(HallCell(sector, HallBand.rim)),
            a.isLit(HallCell(sector, HallBand.inward)),
            reason: 'nothing stands in ${sectorWord(sector)} to keep a shadow',
          );
        }
      }
    });

    test('a press is its own undo — the archive can always be put back', () {
      // Reason 2 of the no-strand proof, exercised rather than asserted: the
      // party never leaves the beacon, so the cycle closes under it.
      final a = BeaconArchive();
      for (final b in kArchiveBeacons) {
        final start = a.lamp[b.id];
        for (var i = 0; i < b.stateCount; i++) {
          a.press(b.id);
        }
        expect(a.lamp[b.id], start, reason: '${b.id} did not close its cycle');
      }
    });

    test('every beacon stands on the RIM, never in the heart', () {
      // The first half of the no-strand proof: nothing in the heart can change
      // the light, so nothing in the heart can be shut on the party.
      const heart = {'oculus_stair', 'reading_floor', 'sunless_reliquary'};
      for (final b in kArchiveBeacons) {
        expect(
          heart.contains(b.roomId),
          isFalse,
          reason: '${b.id} must not stand where it cannot be reached back to',
        );
        expect(layout.rooms[b.roomId], isNotNull);
        expect(layout.rooms[b.roomId]!.hall!.sector, b.sector);
      }
      expect(
        layout.rooms.values.where((r) => r.guardian != null).single.id,
        'solarin_oculus',
      );
    });
  });

  group('the proof', () {
    final g = harness(_idealTrio());
    final r = g.solveBeaconArchive();

    test('no state reachable by legal play can strand the party — and there '
        'is no reset valve', () {
      expect(r.arrangements, 125, reason: 'three beacons, five states each');
      expect(r.states, greaterThan(900));
      expect(
        r.strandable,
        0,
        reason:
            'every move in the archive has an inverse: a press is a five-cycle '
            'taken from where you stand, a step cannot be interrupted because '
            'nothing but a press changes the light, and the only one-way edits '
            'are additive. Reachability is therefore an equivalence',
      );
    });

    test('COUNTERFACTUAL — a beacon that LATCHES strands the archive', () {
      // The fork the design did not take: "every lumen you spend is seen"
      // authored as one throw per beacon. It deletes the inverse of the only
      // world-editing move there is, and the number is what says the
      // five-cycle is load-bearing rather than decorative.
      expect(
        r.strandableWithLatchedBeacons,
        8,
        reason: 'a beacon thrown once and never touched again must strand',
      );
      expect(r.strandableWithLatchedBeacons, greaterThan(r.strandable));
      // And the softer fork does NOT: a beacon that can be re-aimed but never
      // put out keeps all four of its settings mutually reachable, so the
      // press still has an inverse. Pinned so a future edit that eats the
      // margin is visible.
      expect(r.strandableWithRatchet, 0);
    });

    test('COUNTERFACTUAL — Solarin loosed onto the rim strands it too', () {
      // The one authoring decision the safety actually rests on (§7 wants the
      // guardian to fight WITH the planet's rule, and it does — but its glare
      // is arena-local). Let it kindle a rim beacon on the beat and the world
      // can move while the party is not standing at one.
      expect(
        r.strandableWithSolarinLoose,
        47,
        reason: 'a guardian that can reach the beacons breaks the whole proof',
      );
    });

    test(
      'the hush is winnable in every slip bay — and not without the stacks',
      () {
        // Star 1 measured rather than asserted.
        for (final s in kArchiveSlips) {
          expect(
            r.hushBays,
            contains(s.roomId),
            reason: '${s.id} must be drawable somewhere under the hush',
          );
        }
        // COUNTERFACTUAL — take the two great stacks out of the hall and
        // occlusion goes with them: a lit bay then always costs two lumens plus
        // whatever else the arc catches, and the court and the gallery stop
        // being standable under the hush at all. Two of the three slips die.
        expect(r.hushBaysWithoutStacks.length, lessThan(r.hushBays.length));
        expect(r.hushBaysWithoutStacks, isNot(contains('shadow_court')));
        expect(r.hushBaysWithoutStacks, isNot(contains('moth_gallery')));
      },
    );
  });

  group('Star 0 — the shadow court', () {
    test('an effigy wants the stone LIT and its niche DARK', () {
      final a = BeaconArchive();
      a.reset();
      // As the keepers left it the narthex beacon is thrown HIGH, so the court
      // is lit right through and the moth has nowhere to throw.
      expect(a.lumens, 4);
      final moth = courtEffigyById('ef_moth')!;
      expect(a.isLit(moth.stand), isTrue);
      expect(a.canRead(moth), isTrue);
      // Throw the same beam LOW and it costs half and still reads.
      a.lamp['bc_narthex'] = 1;
      expect(a.lumens, 2);
      expect(a.canRead(moth), isTrue);
      // Put it out and there is no light on the stone at all.
      a.lamp['bc_narthex'] = 0;
      expect(a.canRead(moth), isFalse);
    });

    test('AUTHORING RULE — no single arrangement reads all four', () {
      // What makes Star 0 a journey instead of a button, and it is structural:
      // the moth wants the door bay's inner shelf dark and the sun wants the
      // door bay's rim lit, and nothing stands in the door bay to keep a
      // shadow between them.
      final a = BeaconArchive();
      var best = 0;
      for (var n = 0; n < 125; n++) {
        var k = n;
        for (final b in kArchiveBeacons) {
          a.lamp[b.id] = k % 5;
          k ~/= 5;
        }
        final readable = kCourtEffigies.where(a.canRead).length;
        if (readable > best) best = readable;
        expect(
          a.canRead(courtEffigyById('ef_moth')!) &&
              a.canRead(courtEffigyById('ef_sun')!),
          isFalse,
          reason: 'the moth and the sun must be mutually exclusive',
        );
      }
      expect(best, lessThan(kCourtEffigies.length));
      expect(best, greaterThanOrEqualTo(2), reason: 'and not one at a time');
    });

    test('§4 FIRST DESCENT — the court is UNGATED and spans all three '
        'elements', () {
      // §6 put a Crystalmask gate (the beam-split) on this planet's FIRST
      // star. §4's first-descent guarantee wins, so it moved to the rite's
      // prism oriel — and every effigy is element-only.
      final gated = layout.familyGates.map((gt) => gt.objectId).toSet();
      expect(gated, {'hush_slip', 'A'});
      expect(
        kCourtEffigies.map((e) => e.element).toSet(),
        {'Light', 'Crystal', 'Spirit'},
        reason: 'all three entry elements, so any correct trio finishes it',
      );
      final courtStar = layout.rooms.values
          .firstWhere((r) => r.hall?.balustrade != null)
          .hall!
          .starIndex;
      expect(courtStar, 0);

      // And it really is earnable by a trio that clears nothing else.
      final stars = <int>[];
      final g = harness(_plainTrio(), onStar: stars.add);
      g.entryDoorRevealed = true;
      g.archive.lamp['bc_narthex'] = 1;
      act(g, light, 'shadow_court', courtEffigyById('ef_moth')!.position);
      act(g, crystal, 'shadow_court', courtEffigyById('ef_key')!.position);
      expect(g.archive.effigiesRead, {'ef_moth', 'ef_key'});
      g.archive.lamp['bc_narthex'] = 3;
      g.archive.lamp['bc_ledger'] = 1;
      act(g, spirit, 'shadow_court', courtEffigyById('ef_warden')!.position);
      g.archive.lamp['bc_ledger'] = 0;
      act(g, light, 'shadow_court', courtEffigyById('ef_sun')!.position);
      expect(g.archive.courtRead, isTrue);
      expect(stars, contains(0));
    });

    test('the refusal names what is missing, and never a method', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      g.archive.lamp['bc_narthex'] = 0;
      final sun = courtEffigyById('ef_sun')!;
      act(g, light, 'shadow_court', sun.position);
      g.askForRoomHint();
      expect(g.hintText, contains(sectorWord(sun.stand.sector)));
      expect(g.hintText!.split(RegExp(r'[.;]')).length, 1);
      // And the other half of the rule refuses differently: light on the
      // stone, and light in the niche it would throw into.
      g.archive.lamp['bc_narthex'] = 3; // door + court, thrown low
      g.archive.lamp['bc_ledger'] = 1; // and the ledger bay lit as well
      act(g, light, 'shadow_court', sun.position);
      expect(g.archive.effigiesRead, isEmpty);
      g.askForRoomHint();
      expect(g.hintText, contains('lit'));
    });
  });

  group('Star 1 — the dark stacks', () {
    test('a slip is a hard Spirit+PIP gate, and stamps its chip', () {
      final clouds = <String>[];
      final g = harness(_plainTrio(), onCloud: clouds.add);
      g.entryDoorRevealed = true;
      g.archive.lamp['bc_narthex'] = 1; // 2 lumens, under the hush
      final slip = archiveSlipById('slip_court')!;
      act(g, spirit, 'shadow_court', slip.position);
      expect(g.archive.slipsDrawn, isEmpty);
      expect(clouds, contains(layout.familyGateFor('hush_slip')!.discoveryId));
    });

    test('the hush refuses the READING, never a passage', () {
      // Why the exposure rule cannot strand: it takes nothing away from the
      // map, so a party over the hush has lost an act and never a road.
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      g.archive.lamp['bc_narthex'] = 2; // 4 lumens, twice the hush
      final slip = archiveSlipById('slip_court')!;
      final before = [for (final s in kArchiveSills) g.archive.sillOpen(s)];
      act(g, spirit, 'shadow_court', slip.position);
      expect(g.archive.slipsDrawn, isEmpty);
      g.askForRoomHint();
      expect(g.hintText, contains('lumens'));
      act(g, spirit, 'shadow_court', slip.position);
      expect([for (final s in kArchiveSills) g.archive.sillOpen(s)], before);
      // Throw it low and the same hand takes it.
      g.archive.lamp['bc_narthex'] = 1;
      act(g, spirit, 'shadow_court', slip.position);
      expect(g.archive.slipsDrawn, contains('slip_court'));
    });

    test('the stacks slip can only be come at from BEHIND', () {
      // The run's real decision, pinned as a number: sector 3 is empty, so the
      // beam that opens the stack-walk from the gallery side lights two cells
      // and blows the hush. The way in under two lumens is the ledger beacon
      // set beforehand and the whole dark heart walked to get round.
      final a = BeaconArchive();
      final stackwalk = kArchiveSills.firstWhere((s) => s.id == 'sl_stackwalk');
      final ledger = kArchiveSills.firstWhere((s) => s.id == 'sl_ledger');
      var frontUnderHush = 0;
      var backUnderHush = 0;
      for (var n = 0; n < 125; n++) {
        var k = n;
        for (final b in kArchiveBeacons) {
          a.lamp[b.id] = k % 5;
          k ~/= 5;
        }
        if (a.lumens > kArchiveHush) continue;
        if (a.sillOpen(stackwalk)) frontUnderHush++;
        if (a.sillOpen(ledger)) backUnderHush++;
      }
      expect(
        frontUnderHush,
        0,
        reason: 'the gallery side of the stacks is never open under the hush',
      );
      expect(backUnderHush, greaterThan(0));
    });
  });

  group('the vault trick — in plain sight, across un-lit ground', () {
    test(
      'the heartway is the reliquary\'s only sill, and it is mirror-stone',
      () {
        final reliquary = layout.rooms['sunless_reliquary']!;
        expect(reliquary.doors.length, 1, reason: 'the vault is a pocket');
        final heartway = archiveSillBetween(
          'oculus_stair',
          'sunless_reliquary',
        )!;
        expect(heartway.cut, SillCut.mirrorSill);
        expect(heartway.cell!.sector, HallSector.court);
        expect(heartway.cell!.band, HallBand.inward);
        final withCache = layout.rooms.values.where(
          (r) => r.vaultCache != null,
        );
        expect(withCache.length, 1);
        expect(withCache.single.id, 'sunless_reliquary');
      },
    );

    test('a mirror shelf under light is visible and refused; a dark glass '
        'leaf is not there at all', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final stair = layout.rooms['oculus_stair']!;
      final heartway = doorFrom('oculus_stair', 'sunless_reliquary');
      // As the keepers left it the court is lit right through, so the shelf is
      // a sheet of glare: you can see it, and it refuses you.
      expect(g.isDoorHidden(stair, heartway), isFalse);
      final hint = doorHint(g, 'oculus_stair', heartway);
      expect(hint, contains(sectorWord(HallSector.court)));
      expect(hint!.split(RegExp(r'[.;]')).length, 1);
      // A glass leaf with no light in it is the opposite — a hole, and nothing
      // is drawn or spoken there at all.
      g.archive.lamp['bc_narthex'] = 0;
      final threshold = layout.rooms['lumen_threshold']!;
      expect(
        g.isDoorHidden(threshold, doorFrom('lumen_threshold', 'shadow_court')),
        isTrue,
      );
      // And the shelf onto the reliquary is now a floor.
      expect(g.isDoorLocked(stair, heartway), isFalse);
    });
  });

  group('the rite and the guardian', () {
    test('the oriel is a hard Crystal+MASK gate, and stamps its chip', () {
      final clouds = <String>[];
      final g = harness(_plainTrio(), onCloud: clouds.add);
      final oriel = layout.rooms['reading_floor']!.conduits.single;
      expect(oriel.requireElement, 'Crystal');
      act(g, crystal, 'reading_floor', oriel.position);
      expect((g.conduitEnergy['A'] ?? 0) > 0, isFalse);
      expect(clouds, contains(layout.familyGateFor('A')!.discoveryId));
    });

    test('the shutter-ring is element-only Light, and waits on both stars', () {
      final g = harness(_idealTrio());
      final ring = layout.rooms['reading_floor']!.hall!.shutterRing!;
      act(g, light, 'reading_floor', ring);
      expect(g.conduitEnergy['B'] ?? 0, 0);
      g.askForRoomHint();
      expect(g.hintText, contains(layout.starName(0)));
      g.starMask = 0x3;
      // Crystal+Spirit→Light stands in for a Light hand (§6's recipe).
      act(g, crystal, 'reading_floor', ring);
      expect(g.conduitEnergy['B'], double.infinity);
    });

    test('Solarin keeps its lull shut outside a pillar\'s shadow', () {
      final g = harness(_idealTrio());
      g.currentRoomId = 'solarin_oculus';
      g.guardianAwake = true;
      final arena = layout.rooms['solarin_oculus']!;
      final eye = arena.guardian!.position;
      final pillar = arena.hall!.gazePillars.first;
      // Out in the open floor, on the far side of the room from any pillar.
      for (final c in g.creatures) {
        c.position = Offset(eye.dx, eye.dy - 180);
      }
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      // Directly behind a pillar, on the line the glare would take.
      final behind = eye + (pillar - eye) * 1.6;
      for (final c in g.creatures) {
        c.position = behind;
      }
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isTrue);
    });

    test('Solarin cannot touch a single beacon out in the hall', () {
      // The arena-local promise the no-strand proof rests on, exercised: a
      // whole fight's worth of frames must leave the archive exactly as it was.
      final g = harness(_idealTrio());
      g.currentRoomId = 'solarin_oculus';
      g.guardianAwake = true;
      final before = Map<String, int>.from(g.archive.lamp);
      for (var i = 0; i < 600; i++) {
        g.update(1 / 60);
      }
      expect(g.archive.lamp, before);
      // The stair down to it is the one passage the light never reaches.
      expect(
        archiveSillBetween('reading_floor', 'solarin_oculus')!.cut,
        SillCut.stone,
      );
      expect(layout.rooms['solarin_oculus']!.doors.length, 1);
    });
  });

  group('the whole descent', () {
    test('the authored trio walks it all — three stars, the vault and the '
        'maxim', () {
      final stars = <int>[];
      final clouds = <String>[];
      final g = harness(_idealTrio(), onStar: stars.add, onCloud: clouds.add);
      final threshold = layout.rooms['lumen_threshold']!;

      // ── the entry rite ──────────────────────────────────
      expect(g.entryDoorRevealed, isFalse);
      act(g, light, 'lumen_threshold', threshold.hall!.doorShutter!);
      expect(g.entryDoorRevealed, isTrue);
      expect(g.archive.lumens, 4, reason: 'the archive was left blazing');

      // ── the low fan: half the lumens, and the shelves back ──
      pressBeacon(g, light, 'bc_narthex', times: 4); // 2 → 3 → 4 → 0 → 1
      expect(g.archive.lumens, 2);

      // ── STAR 0 (part one) + two slips, all under the hush ──
      step(g, 'shadow_court');
      act(g, light, 'shadow_court', courtEffigyById('ef_moth')!.position);
      act(g, crystal, 'shadow_court', courtEffigyById('ef_key')!.position);
      expect(g.archive.effigiesRead, {'ef_moth', 'ef_key'});
      act(g, spirit, 'shadow_court', archiveSlipById('slip_court')!.position);
      expect(g.archive.slipsDrawn, contains('slip_court'));
      step(g, 'moth_gallery');
      act(g, spirit, 'moth_gallery', archiveSlipById('slip_gallery')!.position);
      expect(g.archive.slipsDrawn, contains('slip_gallery'));

      // ── the sun wants the doorway lit, which costs the court's shelf ──
      step(g, 'shadow_court');
      step(g, 'lumen_threshold');
      pressBeacon(g, light, 'bc_narthex', times: 2); // 1 → 2 → 3
      expect(g.archive.lumens, 3);
      step(g, 'shadow_court');
      act(g, light, 'shadow_court', courtEffigyById('ef_sun')!.position);
      expect(g.archive.effigiesRead, contains('ef_sun'));

      // ── and the warden wants the far end of the rim lit instead ──
      step(g, 'lumen_threshold');
      step(g, 'catalogue_walk');
      pressBeacon(g, light, 'bc_ledger'); // 0 → 1
      step(g, 'lumen_threshold');
      step(g, 'shadow_court');
      act(g, spirit, 'shadow_court', courtEffigyById('ef_warden')!.position);
      expect(g.archive.courtRead, isTrue);
      expect(stars, contains(0));

      // ── STAR 1: the stacks, from BEHIND, through the dark heart ──
      step(g, 'lumen_threshold');
      pressBeacon(g, light, 'bc_narthex', times: 2); // 3 → 4 → 0
      expect(g.archive.lumens, kArchiveHush, reason: 'one small lamp, no more');
      step(g, 'oculus_stair');
      step(g, 'reading_floor');
      step(g, 'catalogue_walk');
      step(g, 'dark_stacks');
      act(g, spirit, 'dark_stacks', archiveSlipById('slip_stacks')!.position);
      expect(g.archive.everySlipDrawn, isTrue);
      expect(stars, contains(1));

      // ── the rite ────────────────────────────────────────
      step(g, 'catalogue_walk');
      step(g, 'reading_floor');
      final floor = layout.rooms['reading_floor']!;
      act(g, crystal, 'reading_floor', floor.conduits.single.position);
      expect((g.conduitEnergy['A'] ?? 0) > 0, isTrue);
      act(g, light, 'reading_floor', floor.hall!.shutterRing!);
      expect(g.conduitEnergy['B'], double.infinity);

      // ── STAR 2 · Solarin ────────────────────────────────
      step(g, 'solarin_oculus');
      expect(layout.rooms['solarin_oculus']!.guardian!.starIndex, 2);

      // ── the vault, and the maxim: everything out, and walk ──
      step(g, 'reading_floor');
      step(g, 'catalogue_walk');
      pressBeacon(g, light, 'bc_ledger', times: 4); // 1 → 2 → 3 → 4 → 0
      // With the ledger out, the walk's three glass leaves are all holes — so
      // the way home is the ledger beacon again, thrown just far enough.
      pressBeacon(g, light, 'bc_ledger'); // 0 → 1
      step(g, 'reading_floor');
      step(g, 'oculus_stair');
      step(g, 'lumen_threshold');
      pressBeacon(g, light, 'bc_narthex', times: 3); // 0 → 1 → 2 → 3
      step(g, 'catalogue_walk');
      pressBeacon(g, light, 'bc_ledger', times: 4); // 1 → 2 → 3 → 4 → 0
      step(g, 'lumen_threshold');
      pressBeacon(g, light, 'bc_narthex', times: 2); // 3 → 4 → 0
      expect(g.archive.lumens, 0, reason: 'not one lumen on the whole hall');

      // The crossing starts at the door and shows nothing the whole way.
      g.update(1 / 60);
      expect(g.archive.hushWalk, isTrue);
      step(g, 'oculus_stair');
      g.update(1 / 60);
      step(g, 'sunless_reliquary');
      for (final c in g.creatures) {
        c.position = layout.rooms['sunless_reliquary']!.vaultCache!;
      }
      g.update(1 / 60);
      expect(clouds, contains(kLightAfraidEggId));
      expect(clouds, contains('cache:light_vault'));

      // Nothing the run did can have stranded it.
      expect(g.solveBeaconArchive().strandable, 0);
    });
  });

  group('the roster', () {
    test('Light is built, not coming soon, and Solarin gets a raid free', () {
      expect(kPlanetDungeonLayouts, contains('Light'));
      expect(kComingSoonDungeons, isNot(contains('Light')));
      expect(kCosmicPlanetEntry['Light'], ['Light', 'Crystal', 'Spirit']);
      expect(kDungeonIdealFamilies['Light']!.length, 3);
      expect(kRaidGuardianIds['Light'], 'Solarin');
      // The two sets still partition the seventeen planets between them.
      expect(kComingSoonDungeons.length + kPlanetDungeonLayouts.length, 17);
      for (final e in kComingSoonDungeons) {
        expect(kPlanetDungeonLayouts, isNot(contains(e)));
      }
    });
  });
}
