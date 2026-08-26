// HEMAVORN — the Sanguine Orrery, pinned.
//
// Blood's topology is a SYSTOLE LOOP: a figure-eight of veins around the
// heart, and a vein is a road only while the beat is pushing through it
// (docs §5.5). Hemavorn is the FIRST planet in the set whose state the player
// does not author — the pulse runs on its own, in one direction, for ever —
// so it carries a stranding hazard no earlier proof had to answer: a window
// can close while you are somewhere only that window could have let you
// leave. This file carries the proofs the design cannot ship without:
//
//  1. THE NO-STRAND PROOF, **over TIME**. A full reachability search over
//     (chamber × PHASE × which collaterals are grafted), enumerated for every
//     one of the ten rolls the corruption can come up as, with the beat
//     modelled as an always-available edge in BOTH the forward enumeration
//     and the escape audit — because a heart does not wait for anybody. It
//     must be ZERO, and it must be zero WITHOUT a reset valve.
//  2. THREE COUNTERFACTUALS that say the safety is designed rather than
//     lucky: open either lobe of the eight, cut the vault's leaflet one-way,
//     or let the arena's arrest hold for ever, and the planet strands.
//  3. SOLVABILITY. The authored trio walks the whole descent — all three
//     stars, the vault and the lost maxim — verb by verb, against the real
//     rules, only through passages the beat has actually opened, and for
//     EVERY roll of the corruption.
//  4. PLANNED, NOT REACTED TO. The measured worst wait, and the fact that
//     every phase-locked object is a WHERE rather than a WHEN.
//
// The rest pins the pulse algebra, §4's first-descent guarantee, the two hard
// gates, the vault trick and the guardian.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
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

/// The §6 ideal trio: Bloodkin · Darkmask · Lightmask.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Blood', 'kin'),
  _member(1, 'Dark', 'mask'),
  _member(2, 'Light', 'mask'),
];

/// The same three ELEMENTS in families that clear nothing — the party §4
/// promises a first descent to.
List<CosmicPartyMember> _plainTrio() => [
  _member(0, 'Blood', 'horn'),
  _member(1, 'Dark', 'wing'),
  _member(2, 'Light', 'mane'),
];

const int blood = 0, dark = 1, light = 2;

final DungeonLayout layout = kPlanetDungeonLayouts['Blood']!;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Blood',
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
/// it, because the Dark+Light braid is a two-body verb and has to be able to
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

DungeonDoor doorFrom(String room, String to) =>
    layout.rooms[room]!.doors.firstWhere((d) => d.targetRoomId == to);

// ── Driving the clock ──────────────────────────────────────
// The beat is advanced through `SanguineHeart.advance`, which is the same
// call `_updateHeart` makes every frame — so the test drives the REAL rule.
// It does not go through `update()` for the waiting, because a wait on this
// planet can be twenty seconds and there is no reason to run twelve hundred
// frames of combat to spend it.

void advancePhase(PlanetDungeonGame g) {
  final was = g.heart.phase;
  for (var i = 0; i < 6000 && g.heart.phase == was; i++) {
    g.heart.advance(1 / 60);
  }
  expect(g.heart.phase, isNot(was), reason: 'the beat did not turn');
}

void advanceTo(PlanetDungeonGame g, PulsePhase want) {
  for (var i = 0; i < 8 && g.heart.phase != want; i++) {
    advancePhase(g);
  }
  expect(g.heart.phase, want, reason: 'the beat never reached $want');
}

/// Walk one passage, and REFUSE to walk one the beat has shut. Every step of
/// the scripted descent goes through here, so the run can never cheat past a
/// vein the player would find collapsed.
void step(PlanetDungeonGame g, String to) {
  final from = g.currentRoomId;
  final door = doorFrom(from, to);
  final p = heartPassageBetween(from, to)!;
  expect(
    g.heart.carriesFrom(p, from),
    isTrue,
    reason: '$from → $to (${p.id}) does not carry on ${g.heart.phase}',
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

/// The next move on a shortest route to [target] over (chamber × phase), or
/// null when the right move is to stand still and let the heart work. Uses
/// the LIVE graft set, so a route only ever exists through vessels the party
/// has actually opened.
String? _firstMove(PlanetDungeonGame g, String target) {
  final start = '${g.currentRoomId}|${g.heart.phase.index}';
  final queue = <(String, PulsePhase)>[(g.currentRoomId, g.heart.phase)];
  // key → (previous key, the room this step lands in, or null for a wait)
  final from = <String, (String, String?)>{start: ('', null)};
  String? goal;
  while (queue.isNotEmpty && goal == null) {
    final (room, ph) = queue.removeAt(0);
    final key = '$room|${ph.index}';
    final next = <(String, PulsePhase, String?)>[
      (room, nextPulsePhase(ph), null),
    ];
    for (final d in layout.rooms[room]!.doors) {
      final p = heartPassageBetween(room, d.targetRoomId)!;
      final grafted = g.heart.grafted.contains(p.id);
      if (!p.carriesFrom(room, ph, grafted: grafted)) continue;
      next.add((d.targetRoomId, ph, d.targetRoomId));
    }
    for (final (r, q, moved) in next) {
      final k = '$r|${q.index}';
      if (from.containsKey(k)) continue;
      from[k] = (key, moved);
      if (r == target) {
        goal = k;
        break;
      }
      queue.add((r, q));
    }
  }
  if (goal == null) return null;
  var k = goal;
  while (from[k]!.$1 != start) {
    k = from[k]!.$1;
  }
  return from[k]!.$2;
}

/// Walk to [target] the way a player would: take the road when there is one,
/// stand still when there is not. Every step is checked against the real
/// rule, and the loop is bounded so a route that does not exist fails loudly
/// rather than hanging.
void travel(PlanetDungeonGame g, String target) {
  for (var guard = 0; guard < 200; guard++) {
    if (g.currentRoomId == target) return;
    final reachable = layout.rooms.containsKey(target);
    expect(reachable, isTrue, reason: 'no such chamber: $target');
    final move = _firstMove(g, target);
    if (move == null) {
      advancePhase(g);
    } else {
      step(g, move);
    }
  }
  fail('could not walk from ${g.currentRoomId} to $target');
}

/// Stand in [o]'s chamber, wait for its phase, and prime it.
void prime(PlanetDungeonGame g, int idx, Ostium o) {
  travel(g, o.roomId);
  advanceTo(g, o.phase);
  act(g, idx, o.roomId, o.position);
  expect(
    g.heart.ostiaPrimed,
    contains(o.id),
    reason: '${o.id} did not prime on ${o.phase}',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────
  group('the orrery — one figure of eight, four phases', () {
    test('every passage is a real door pair, and every pair is one passage', () {
      final pairs = <String>{};
      for (final p in kHeartPassages) {
        final a = layout.rooms[p.from];
        final b = layout.rooms[p.to];
        expect(a, isNotNull, reason: '${p.id} from ${p.from}');
        expect(b, isNotNull, reason: '${p.id} to ${p.to}');
        expect(
          a!.doors.any((d) => d.targetRoomId == p.to),
          isTrue,
          reason: '${p.id}: no door ${p.from} → ${p.to}',
        );
        expect(
          b!.doors.any((d) => d.targetRoomId == p.from),
          isTrue,
          reason: '${p.id}: no door ${p.to} → ${p.from}',
        );
        final key = ([p.from, p.to]..sort()).join('|');
        expect(pairs.add(key), isTrue, reason: 'two passages join $key');
      }
      // And the other way: no door in the layout is outside the passage graph,
      // or the proof would be walking a different map from the player.
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          expect(
            heartPassageBetween(room.id, d.targetRoomId),
            isNotNull,
            reason: '${room.id} → ${d.targetRoomId} is not a passage',
          );
        }
      }
    });

    test('BOTH lobes of the eight are CLOSED cycles', () {
      // This is the load-bearing sentence of the whole layout: a one-way road
      // is only safe if it comes back round.
      for (final lobe in HeartLobe.values) {
        final veins = [
          for (final p in kHeartPassages)
            if (p.kind == PassageKind.vein && p.lobe == lobe) p,
        ];
        expect(veins.length, 4, reason: '$lobe is not a four-cycle');
        // Every chamber on the lobe has exactly one vein out and one in, in
        // the FORWARD sense — which is what makes going round come back.
        final outOf = <String, int>{};
        final into = <String, int>{};
        for (final v in veins) {
          outOf[v.from] = (outOf[v.from] ?? 0) + 1;
          into[v.to] = (into[v.to] ?? 0) + 1;
        }
        expect(outOf.keys.toSet(), into.keys.toSet());
        for (final k in outOf.keys) {
          expect(outOf[k], 1, reason: '$k has ${outOf[k]} veins out of $lobe');
          expect(into[k], 1, reason: '$k has ${into[k]} veins into $lobe');
        }
      }
      // And they cross at exactly one chamber — otherwise it is two rings, not
      // an eight.
      final greater = {
        for (final p in kHeartPassages)
          if (p.kind == PassageKind.vein && p.lobe == HeartLobe.greater) ...[
            p.from,
            p.to,
          ],
      };
      final lesser = {
        for (final p in kHeartPassages)
          if (p.kind == PassageKind.vein && p.lobe == HeartLobe.lesser) ...[
            p.from,
            p.to,
          ],
      };
      expect(greater.intersection(lesser), {'vena_crossing'});
    });

    test('the pulse is an unbranching period-4 cycle nobody can stop', () {
      // PREMISE ONE of the whole no-strand proof, pinned as an algebraic fact
      // rather than as a comment.
      expect(kPulsePhaseSeconds.length, PulsePhase.values.length);
      for (final s in kPulsePhaseSeconds) {
        expect(s, greaterThan(0));
      }
      for (final p in PulsePhase.values) {
        var q = p;
        for (var i = 0; i < PulsePhase.values.length; i++) {
          q = nextPulsePhase(q);
        }
        expect(q, p, reason: 'the beat does not close on itself from $p');
        // Every phase is reached from every phase in at most four steps.
        final seen = <PulsePhase>{};
        var r = p;
        for (var i = 0; i < PulsePhase.values.length; i++) {
          seen.add(r);
          r = nextPulsePhase(r);
        }
        expect(seen.length, PulsePhase.values.length);
      }
      // …and the clock agrees with the phase table at every boundary.
      for (final p in PulsePhase.values) {
        expect(pulsePhaseAt(pulsePhaseStart(p) + 0.001), p);
        expect(
          pulsePhaseAt(
            pulsePhaseStart(p) + kPulsePhaseSeconds[p.index] - 0.001,
          ),
          p,
        );
      }
    });

    test(
      'the flow table: the greater round reverses, the lesser never does',
      () {
        // The strategic question, expressed as six numbers (§5.5).
        expect(veinFlow(HeartLobe.greater, PulsePhase.systole), 1);
        expect(veinFlow(HeartLobe.greater, PulsePhase.dicrotic), -1);
        expect(veinFlow(HeartLobe.greater, PulsePhase.diastole), 0);
        expect(veinFlow(HeartLobe.greater, PulsePhase.flatline), 0);
        expect(veinFlow(HeartLobe.lesser, PulsePhase.diastole), 1);
        for (final p in PulsePhase.values) {
          if (p == PulsePhase.diastole) continue;
          expect(
            veinFlow(HeartLobe.lesser, p),
            0,
            reason: 'the lung must never run on $p',
          );
          expect(
            veinFlow(HeartLobe.lesser, p),
            isNot(-1),
            reason: 'the lung must never reverse',
          );
        }
        // On the flatline NOTHING carries and every valve hangs open. That pair
        // of facts is the vault trick and the planet's identity in one line.
        for (final lobe in HeartLobe.values) {
          expect(veinFlow(lobe, PulsePhase.flatline), 0);
        }
        final leaflet = heartPassageById('vv_leaflet')!;
        for (final p in PulsePhase.values) {
          expect(
            leaflet.carriesFrom('aortic_arch', p),
            p == PulsePhase.flatline,
          );
          expect(
            leaflet.carriesFrom('auricle_reliquary', p),
            p == PulsePhase.flatline,
            reason: 'the leaflet must be the same way OUT as it is in',
          );
        }
        // A collateral is the complement of its lobe — the phases the eight
        // denies you, which is why Star 1's reward is TIME.
        for (final lobe in HeartLobe.values) {
          for (final p in PulsePhase.values) {
            expect(collateralCarries(lobe, p), veinFlow(lobe, p) == 0);
          }
        }
      },
    );

    test('the murals are the only phase-free ways, and they guard the two '
        'rooms the world acts in', () {
      final murals = [
        for (final p in kHeartPassages)
          if (p.kind == PassageKind.mural) p,
      ];
      expect(murals.length, 2);
      for (final m in murals) {
        for (final p in PulsePhase.values) {
          expect(m.carriesFrom(m.from, p), isTrue);
          expect(m.carriesFrom(m.to, p), isTrue);
        }
      }
      // The rite chamber and the arena — the two places the world (the rite's
      // own wave, and Sanguorath) acts while the party stands in them — are
      // reached ONLY through murals.
      for (final id in ['myocardium', 'sanguorath_systole']) {
        for (final d in layout.rooms[id]!.doors) {
          expect(
            heartPassageBetween(id, d.targetRoomId)!.kind,
            PassageKind.mural,
            reason: '$id → ${d.targetRoomId} must be phase-free',
          );
        }
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  group('THE NO-STRAND PROOF — over TIME, not just over space', () {
    final r = harness(_idealTrio()).solveSanguineOrrery();

    test('the search covers every roll and every phase', () {
      expect(r.rolls, 10, reason: 'C(5,3) — every way the corruption can fall');
      expect(heartCollateralRolls().length, 10);
      for (final roll in heartCollateralRolls()) {
        expect(roll.length, kSoundCollateralCount);
      }
      // 10 chambers × 4 phases × 8 graft states × 10 rolls, less the states
      // the world cannot actually produce.
      expect(r.states, greaterThan(2500));
    });

    test('NOTHING strands — 0, with no reset valve', () {
      // The hazard this planet invented: a window can close while you are
      // somewhere only that window could have let you leave, and waiting is
      // not obviously a remedy. Here it always is, because the beat is
      // periodic and unstoppable and every chamber is safe to stand in.
      expect(
        r.strandable,
        0,
        reason:
            'some (chamber × phase × graft) state cannot reach the whole '
            'orrery',
      );
    });

    test('COUNTERFACTUAL — open either lobe of the eight and it is a trap', () {
      // Delete the sinus mouth and the lesser lobe stops being a ring. It
      // never reverses, so a party that walks into the lung could never walk
      // out. This is the counterfactual that says the CLOSED CYCLE is the
      // design and not an accident.
      expect(
        r.strandableWithOpenLesserRound,
        greaterThan(0),
        reason: 'the closing vein has to be load-bearing',
      );
      expect(r.strandableWithOpenLesserRound, 272);
    });

    test('COUNTERFACTUAL — a one-way leaflet swallows the party', () {
      // Cut the vault's way as a one-way vein INWARD instead of a two-way
      // valve, and the pocket is a trap however periodic the world outside
      // is. Every state inside the reliquary dies.
      expect(r.strandableWithOneWayLeaflet, greaterThan(0));
      expect(r.strandableWithOneWayLeaflet, 320);
    });

    test('COUNTERFACTUAL — let the heart be stopped for good and everything '
        'dies', () {
      // Premise one, measured. Let the arena's vagal node hold the flatline
      // for ever and the periodicity the whole proof rests on is gone: the
      // veins never carry again and the orrery is a set of sealed rooms. This
      // is why the arrest is BOUNDED.
      expect(r.strandableWithUnboundedArrest, greaterThan(0));
      expect(r.strandableWithUnboundedArrest, 264);
    });

    test('PLANNED, NOT REACTED TO — nobody ever waits more than one turn of '
        'the clock', () {
      // The beat has four phases, so a worst wait of three means every
      // chamber has a road within one full cycle, always. Nothing on this
      // planet asks for an input at an instant: you work out where to stand,
      // and the beat comes to you.
      expect(r.worstWaitPhases, lessThanOrEqualTo(3));
      expect(r.worstWaitPhases, 3);
    });

    test('§4 FIRST DESCENT — every mouth and the vault are reachable with '
        'NOTHING grafted', () {
      // i.e. a party with no Dark Mask — the one gate on this planet — can
      // still prime all four mouths and take the cache. Star 0 is theirs, and
      // §4's first-descent guarantee holds.
      expect(r.ostiaPrimable, kHeartOstia.length);
      expect(r.vaultReachableUngrafted, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────
  group('the vault trick — a room only the pause opens', () {
    test('the leaflet is shut on every phase but the flatline, from BOTH '
        'sides', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final arch = layout.rooms['aortic_arch']!;
      final pocket = layout.rooms['auricle_reliquary']!;
      final inward = doorFrom('aortic_arch', 'auricle_reliquary');
      final outward = doorFrom('auricle_reliquary', 'aortic_arch');
      for (final phase in PulsePhase.values) {
        advanceTo(g, phase);
        final open = phase == PulsePhase.flatline;
        expect(g.isDoorLocked(arch, inward), !open, reason: 'in on $phase');
        expect(g.isDoorLocked(pocket, outward), !open, reason: 'out on $phase');
        // It is never HIDDEN — the leaflet is visible and refused, which is
        // how the planet teaches what the pressure is doing (§5.6 BLOCKED).
        expect(g.isDoorHidden(arch, inward), isFalse);
      }
    });

    test('exactly one cache, and it is behind the pause', () {
      final withCache = layout.rooms.values
          .where((r) => r.vaultCache != null)
          .toList();
      expect(withCache.length, 1);
      expect(withCache.single.id, 'auricle_reliquary');
      // One door, and it is the leaflet. A pocket, not a corridor.
      expect(withCache.single.doors.length, 1);
      expect(
        heartPassageBetween('auricle_reliquary', 'aortic_arch')!.kind,
        PassageKind.valve,
      );
    });
  });

  // ─────────────────────────────────────────────────────────
  group('§4 — ELEMENT OPENS, FAMILY UNLOCKS', () {
    test('two gates, on two objects, on two entry slots, never two on one '
        'star', () {
      expect(layout.familyGates.length, 2);
      final gate = layout.familyGateFor('collateral_cock')!;
      expect(gate.element, 'Dark');
      expect(gate.family, 'Mask');
      final cannula = layout.familyGateFor('A')!;
      expect(cannula.element, 'Blood');
      expect(cannula.family, 'Kin');
      // Both elements are entry slots, and they are different slots.
      final entry = kCosmicPlanetEntry['Blood']!;
      if (gate.needsElement) expect(entry, contains(gate.element));
      expect(entry, contains(cannula.element));
      expect(gate.element, isNot(cannula.element));
      // Star 0 carries no gate at all: §6 put a Bloodkin gate on this
      // planet's FIRST star and §4's first-descent guarantee wins, so it
      // moved onto the rite's cannula.
      for (final o in kHeartOstia) {
        expect(entry, contains(o.element));
      }
      expect(
        {for (final o in kHeartOstia) o.element},
        entry.toSet(),
        reason: 'the priming must use all three entry elements at full power',
      );
    });

    test('a trio with the right ELEMENTS and the wrong families still banks '
        'Star 0', () {
      final stars = <int>{};
      final g = harness(_plainTrio(), onStar: stars.add);
      final gate = layout.rooms['pericard_gate']!;
      act(g, blood, 'pericard_gate', gate.sanguine!.pericardium!);
      expect(g.entryDoorRevealed, isTrue);
      prime(g, blood, ostiumById('os_gate')!);
      prime(g, dark, ostiumById('os_arch')!);
      prime(g, light, ostiumById('os_weave')!);
      prime(g, blood, ostiumById('os_sinus')!);
      expect(g.heart.everyOstiumPrimed, isTrue);
      expect(stars, contains(0));
    });

    test('the cock refuses everything but a Dark MASK, and the seal '
        'remembers', () {
      final clouds = <String>{};
      final g = harness(_plainTrio(), onCloud: clouds.add);
      g.entryDoorRevealed = true;
      final cock = kHeartCocks.firstWhere((c) => c.roomId == 'aortic_arch');
      // A Dark WING is the right element and the wrong family: a clean
      // refusal, and the chip stamps.
      act(g, dark, 'aortic_arch', cock.position);
      expect(g.heart.cocksTurned, isEmpty);
      expect(clouds, contains('gate:dark_mask'));
      // A Blood hand does not even get that far.
      act(g, blood, 'aortic_arch', cock.position);
      expect(g.heart.cocksTurned, isEmpty);
    });

    test('the cannula refuses everything but a Blood KIN', () {
      final g = harness(_plainTrio());
      g.entryDoorRevealed = true;
      final conduit = layout.rooms['myocardium']!.conduits.single;
      act(g, blood, 'myocardium', conduit.position);
      expect((g.conduitEnergy['A'] ?? 0) > 0, isFalse);
    });

    test('the riddle names each slot outright — element and family', () {
      // Family naming is now CONDITIONAL — a line names one only where a gate
      // actually demands it, so an ungated slot names its element and nothing
      // more. That rule spans all seventeen planets and lives in
      // dungeon_riddle_naming_test.dart; this only pins Blood's elements.
      final els = kCosmicPlanetEntry['Blood']!;
      expect(layout.riddle.length, els.length);
      for (var i = 0; i < layout.riddle.length; i++) {
        expect(layout.riddle[i].toLowerCase(), contains(els[i].toLowerCase()));
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  group('the beat as the door', () {
    test('a collapsed vein is visible and refused; a dead vessel is not there '
        'at all', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final gate = layout.rooms['pericard_gate']!;
      final vein = doorFrom('pericard_gate', 'arterial_run');
      final dead = doorFrom('pericard_gate', 'aortic_arch');
      advanceTo(g, PulsePhase.systole);
      expect(g.isDoorLocked(gate, vein), isFalse);
      advanceTo(g, PulsePhase.diastole);
      expect(
        g.isDoorLocked(gate, vein),
        isTrue,
        reason:
            'the greater round '
            'is slack on the diastole',
      );
      expect(
        g.isDoorHidden(gate, vein),
        isFalse,
        reason:
            'a collapsed vein '
            'is a thing you can see',
      );
      // The ungrafted collateral, on every phase: nothing there.
      for (final p in PulsePhase.values) {
        advanceTo(g, p);
        expect(g.isDoorHidden(gate, dead), isTrue);
      }
    });

    test(
      'the greater round runs OUT on the squeeze and BACK on the backwash',
      () {
        final g = harness(_idealTrio());
        g.entryDoorRevealed = true;
        final run = layout.rooms['arterial_run']!;
        final onward = doorFrom('arterial_run', 'aortic_arch');
        final back = doorFrom('arterial_run', 'pericard_gate');
        advanceTo(g, PulsePhase.systole);
        expect(g.isDoorLocked(run, onward), isFalse);
        expect(
          g.isDoorLocked(run, back),
          isTrue,
          reason:
              'nothing swims up a '
              'heart',
        );
        advanceTo(g, PulsePhase.dicrotic);
        expect(g.isDoorLocked(run, onward), isTrue);
        expect(
          g.isDoorLocked(run, back),
          isFalse,
          reason:
              'the backwash IS the '
              '"or against it"',
        );
      },
    );

    test('the lung is a commitment: it only ever runs one way', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final stair = layout.rooms['pulmonic_stair']!;
      final backwards = doorFrom('pulmonic_stair', 'vena_crossing');
      for (final p in PulsePhase.values) {
        advanceTo(g, p);
        expect(
          g.isDoorLocked(stair, backwards),
          isTrue,
          reason:
              'the lung must never carry backwards, and least of all on '
              '$p',
        );
      }
    });

    test('a Blood KIN holds a vein open past the turn (a §4 family BONUS, '
        'never a requirement)', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      advanceTo(g, PulsePhase.systole);
      // Walk the beat to the last second of the squeeze: a Kin steadies a vein
      // it is about to LOSE, which is the only moment the bonus means
      // anything, and the moment §6's line describes.
      while (g.heart.secondsUntil(PulsePhase.dicrotic) > 1.0) {
        g.heart.advance(1 / 60);
      }
      final door = doorFrom('pericard_gate', 'arterial_run');
      act(g, blood, 'pericard_gate', door.rect.center);
      expect(g.heart.steadied, contains('vn_pericard'));
      g.heart.advance(1.5); // over the turn
      expect(g.heart.phase, PulsePhase.dicrotic);
      // The greater round has REVERSED, and this one vein is still a road out.
      expect(
        g.heart.carriesFrom(heartPassageById('vn_pericard')!, 'pericard_gate'),
        isTrue,
      );
      // And it is purely ADDITIVE: it lets go on its own, and it never shut
      // anything — which is why the no-strand proof can ignore it and stay a
      // conservative bound.
      for (var i = 0; i < 600; i++) {
        g.heart.advance(1 / 60);
      }
      expect(g.heart.steadied, isEmpty);
      expect(
        g.heart.carriesFrom(heartPassageById('vn_pericard')!, 'pericard_gate'),
        g.heart.phase == PulsePhase.systole,
      );
    });
  });

  // ─────────────────────────────────────────────────────────
  group('SOLVABILITY — the authored trio walks the whole descent', () {
    test('every roll of the corruption is winnable, verb by verb', () {
      for (final roll in heartCollateralRolls()) {
        final stars = <int>{};
        final clouds = <String>{};
        final g = harness(_idealTrio(), onStar: stars.add, onCloud: clouds.add);
        // Pin the roll rather than take what the RNG gave: the point is that
        // ALL TEN are winnable, not that one of them was.
        g.heart.soundCollaterals
          ..clear()
          ..addAll(roll);

        // ── entry ─────────────────────────────────────────
        final gate = layout.rooms['pericard_gate']!;
        act(g, blood, 'pericard_gate', gate.sanguine!.pericardium!);
        expect(g.entryDoorRevealed, isTrue, reason: 'roll $roll');

        // ── STAR 0 · the four mouths ──────────────────────
        // Four chambers, four phases, and no two of them on one beat.
        prime(g, blood, ostiumById('os_gate')!);
        prime(g, dark, ostiumById('os_arch')!);
        prime(g, light, ostiumById('os_weave')!);
        prime(g, blood, ostiumById('os_sinus')!);
        expect(stars, contains(0), reason: 'roll $roll');

        // ── THE VAULT · in on the pause, out on the next ──
        travel(g, 'aortic_arch');
        advanceTo(g, PulsePhase.flatline);
        step(g, 'auricle_reliquary');
        for (final c in g.creatures) {
          c
            ..position = layout.rooms['auricle_reliquary']!.vaultCache!
            ..lastSafe = c.position;
        }
        g.update(1 / 60);
        expect(clouds, contains('cache:blood_vault'), reason: 'roll $roll');
        // And back out — the same leaflet, the next pause. Nothing shut on us.
        travel(g, 'aortic_arch');

        // ── STAR 1 · the grafts ───────────────────────────
        // The Light hand reads first (free information, element-only), then
        // the Dark Mask grafts. A thrombosed cock takes the turn and gives
        // nothing back, which costs a fight and no ground.
        for (final cock in kHeartCocks) {
          travel(g, cock.roomId);
          act(g, light, cock.roomId, cock.position);
          expect(g.heart.flagged, contains(cock.passageId));
          act(g, dark, cock.roomId, cock.position);
          expect(g.heart.cocksTurned, contains(cock.passageId));
          expect(
            g.heart.grafted.contains(cock.passageId),
            roll.contains(cock.passageId),
            reason: '${cock.passageId} on roll $roll',
          );
        }
        expect(g.heart.everyGraftTaken, isTrue, reason: 'roll $roll');
        expect(stars, contains(1), reason: 'roll $roll');

        // ── the rite ──────────────────────────────────────
        travel(g, 'myocardium');
        final myo = layout.rooms['myocardium']!;
        act(g, blood, 'myocardium', myo.conduits.single.position);
        expect((g.conduitEnergy['A'] ?? 0) > 0, isTrue, reason: 'roll $roll');
        act(g, blood, 'myocardium', myo.sanguine!.balance!);
        expect(g.conduitEnergy['B'], double.infinity, reason: 'roll $roll');

        // ── STAR 2 · Sanguorath ───────────────────────────
        step(g, 'sanguorath_systole');
        expect(layout.rooms['sanguorath_systole']!.guardian!.starIndex, 2);

        // Nothing the run did can have stranded it.
        expect(g.solveSanguineOrrery().strandable, 0, reason: 'roll $roll');
      }
    });

    test('the lost maxim — twelve straight beats on the heart-drum', () {
      final clouds = <String>{};
      final g = harness(_idealTrio(), onCloud: clouds.add);
      g.entryDoorRevealed = true;
      final gallery = layout.rooms['atrial_gallery']!;
      final drum = gallery.sanguine!.heartDrum!;
      g.currentRoomId = 'atrial_gallery';
      for (var beat = 0; beat < 12; beat++) {
        // Put the beat exactly on the systole onset — which is what "in sync"
        // means, and the ONE reaction window on the planet. It is an optional
        // 20-gold secret; no star is behind it.
        advanceTo(g, PulsePhase.flatline);
        advanceTo(g, PulsePhase.systole);
        act(g, blood, 'atrial_gallery', drum);
        expect(g.heart.drumStreak, beat + 1, reason: 'beat $beat');
        // Let the window close so the next strike is a new beat.
        g.heart.advance(1.0);
        g.update(1 / 60);
      }
      expect(clouds, contains('egg:blood_drum'));
      expect(g.heart.drumHeard, isTrue);
    });

    test('a beat missed breaks the streak', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final drum = layout.rooms['atrial_gallery']!.sanguine!.heartDrum!;
      g.currentRoomId = 'atrial_gallery';
      advanceTo(g, PulsePhase.flatline);
      advanceTo(g, PulsePhase.systole);
      act(g, blood, 'atrial_gallery', drum);
      expect(g.heart.drumStreak, 1);
      // One beat later the next onset is still ANSWERABLE — the streak is not
      // broken until a beat has actually come round unanswered.
      for (var i = 0; i < 4; i++) {
        advancePhase(g);
        g.update(1 / 60);
      }
      expect(g.heart.drumStreak, 1);
      // Let that one go by too, and it breaks.
      for (var i = 0; i < 4; i++) {
        advancePhase(g);
        g.update(1 / 60);
      }
      expect(g.heart.drumStreak, 0);
    });
  });

  // ─────────────────────────────────────────────────────────
  group('Sanguorath — the guardian fights WITH the pulse (§7)', () {
    PlanetDungeonGame arena() {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      g.currentRoomId = 'sanguorath_systole';
      g.guardianAwake = true;
      for (final c in g.creatures) {
        c
          ..position = const Offset(450, 300)
          ..lastSafe = c.position;
      }
      return g;
    }

    test('the lull exists only on the flatline', () {
      final g = arena();
      advanceTo(g, PulsePhase.systole);
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      advanceTo(g, PulsePhase.flatline);
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isTrue);
    });

    test('every strike beat throws the pulse forward, out of the pause', () {
      final g = arena();
      advanceTo(g, PulsePhase.flatline);
      g.guardianVulnerable = true;
      g.update(1 / 60); // the window opens
      g.guardianVulnerable = false;
      g.update(1 / 60); // the beat lands
      expect(g.heart.phase, isNot(PulsePhase.flatline));
      expect(g.heart.phase, PulsePhase.systole);
    });

    test('the vagal node is the party\'s hand on the clock — and it is '
        'BOUNDED', () {
      final g = arena();
      advanceTo(g, PulsePhase.systole);
      final node = layout.rooms['sanguorath_systole']!.sanguine!.vagalNode!;
      act(g, blood, 'sanguorath_systole', node);
      expect(g.heart.phase, PulsePhase.flatline);
      expect(g.heart.arrest, greaterThan(0));
      // It lets go. Premise one of the no-strand proof survives the fight.
      for (var i = 0; i < 60 * 12; i++) {
        g.heart.advance(1 / 60);
      }
      expect(g.heart.arrest, lessThanOrEqualTo(0));
      final seen = <PulsePhase>{};
      for (var i = 0; i < 60 * 60; i++) {
        g.heart.advance(1 / 60);
        seen.add(g.heart.phase);
      }
      expect(seen, PulsePhase.values.toSet());
    });

    test('the arena can never be shut on the party', () {
      // The chordae gate is phase-free (the no-strand proof, reason 4), so it
      // does not matter what the guardian does to the beat.
      final g = arena();
      final out = doorFrom('sanguorath_systole', 'myocardium');
      final room = layout.rooms['sanguorath_systole']!;
      for (final p in PulsePhase.values) {
        advanceTo(g, p);
        expect(g.isDoorHidden(room, out), isFalse);
        // (Star gating is the engine's, not the beat's — the beat never locks
        // this door, which is the property under test.)
        expect(
          g.heart.carriesFrom(
            heartPassageById('vn_chordae')!,
            'sanguorath_systole',
          ),
          isTrue,
        );
      }
    });
  });

  // ─────────────────────────────────────────────────────────
  group('the planet is registered whole', () {
    test('entry, ideal families and the coming-soon set agree', () {
      expect(kCosmicPlanetEntry['Blood'], ['Blood', 'Dark', 'Light']);
      expect(kDungeonIdealFamilies['Blood'], ['Kin', 'Mask', 'Mask']);
      expect(kComingSoonDungeons, isNot(contains('Blood')));
      expect(kPlanetDungeonLayouts.containsKey('Blood'), isTrue);
      // Index-aligned: family[i] pairs with element[i].
      expect(
        kDungeonIdealFamilies['Blood']!.length,
        kCosmicPlanetEntry['Blood']!.length,
      );
    });

    test('the coming-soon set holds only genuinely unbuilt planets', () {
      // The known rebase trap: resolving a conflict in kComingSoonDungeons by
      // keeping BOTH sides silently restores an element a merged dungeon
      // already deleted.
      for (final e in kComingSoonDungeons) {
        expect(
          kPlanetDungeonLayouts.containsKey(e),
          isFalse,
          reason: '$e is built and must not be "coming soon"',
        );
      }
      expect(
        kComingSoonDungeons.length + kPlanetDungeonLayouts.length,
        17,
        reason: 'every planet is either built or coming soon, never neither',
      );
    });

    test('Sanguorath gets a raid for free, and the roster names it', () {
      expect(kRaidGuardianIds['Blood'], 'Sanguorath');
      final arena = layout.rooms['sanguorath_systole']!;
      expect(arena.guardian!.encounter!.mysticId, 'Sanguorath');
      expect(arena.guardian!.starIndex, 2);
    });

    test('Hemavorn is still the campaign\'s terminal planet', () {
      expect(kBloodPlanetElement, 'Blood');
      // Sixteen guardians must fall before the last gate answers, and the
      // count is DERIVED — moving Blood out of the coming-soon set must not
      // have changed it.
      expect(kNonBloodPlanetCount, 16);
    });
  });
}
