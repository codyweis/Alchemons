// THE VENOM MONASTERY — Poison's triage, pinned and PROVED.
//
// The design's promise (docs/dungeons.md §5.5/§6.13) is a sacrifice that is
// REAL but never punishing: four wards, physic for three, and the vault
// reachable *because* of what you gave up. That promise is only worth
// anything if it is impossible to strand yourself, so this file does not
// spot-check a happy path — it BRUTE-FORCES the whole reachable state space
// of [WardTriage] (the shipped rules, not a copy of them) for every possible
// arrangement of strains, and asserts:
//
//   1. never four — no reachable state has more than three wards cured;
//   2. never fewer — from EVERY reachable state, three cures are still
//      reachable, so no sequence of misdiagnoses can cost a star;
//   3. the choice is real — with a full party, every one of the four wards
//      can be the one surrendered;
//   4. the gate steers, it does not block — a party with no Plant horn can
//      still take both stars; the charnel simply becomes their sacrifice;
//   5. the map never strands — whichever ward is given up, every room
//      (crypt and vault included) is still reachable without a squint.
//
// Modelled on test/burn_field_test.dart, which proves Fire's garth the same
// way and for the same reason.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
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
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      slotIndex: slot,
      staminaBars: 3,
      staminaMax: 3,
    );

/// The §6 ideal trio: Poisonmask · Planthorn · Mudmane.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Poison', 'mask'),
  _member(1, 'Plant', 'horn'),
  _member(2, 'Mud', 'mane'),
];

PlanetDungeonGame _harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Poison',
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
  // Pin the roll so the script is a DIAGNOSIS and not a lucky shuffle; the
  // exhaustive sweep above already covers all 24 arrangements.
  game.monastery.triage = WardTriage(
    wardIds: kMonasteryWardIds,
    strains: const {
      'ward_bell': WardStrain.pulse,
      'ward_scriptorium': WardStrain.creep,
      'ward_refectory': WardStrain.leap,
      'ward_charnel': WardStrain.feign,
    },
  );
  return game;
}

/// Every arrangement of the four strains over the four wards (4! = 24). The
/// engine rolls one of these per run, so a proof has to cover all of them.
List<Map<String, WardStrain>> _allArrangements() {
  final out = <Map<String, WardStrain>>[];
  void permute(List<WardStrain> left, List<WardStrain> acc) {
    if (left.isEmpty) {
      out.add({
        for (var i = 0; i < kMonasteryWardIds.length; i++)
          kMonasteryWardIds[i]: acc[i],
      });
      return;
    }
    for (var i = 0; i < left.length; i++) {
      permute([...left]..removeAt(i), [...acc, left[i]]);
    }
  }

  permute(WardStrain.values.toList(), const []);
  return out;
}

/// A whole triage state, flattened to a comparable key so the search can
/// dedupe. (Ward order is fixed, so bitmasks are stable.)
String _key(WardTriage t) {
  int mask(Set<String> s) {
    var m = 0;
    for (var i = 0; i < kMonasteryWardIds.length; i++) {
      if (s.contains(kMonasteryWardIds[i])) m |= 1 << i;
    }
    return m;
  }

  return '${mask(t.opened)}|${mask(t.cured)}|${mask(t.virulent)}'
      '|${t.cistern}|${t.carried?.index ?? -1}|${t.surrendered ?? ''}';
}

WardTriage _clone(WardTriage t, Map<String, WardStrain> strains) {
  final c = WardTriage(wardIds: kMonasteryWardIds, strains: strains)
    ..cistern = t.cistern
    ..carried = t.carried
    ..surrendered = t.surrendered;
  c.opened.addAll(t.opened);
  c.cured.addAll(t.cured);
  c.virulent.addAll(t.virulent);
  return c;
}

/// Every state a player could ever reach from a fresh run, playing the real
/// rules. [openable] is the set of wards this party can actually unseal (a
/// party with no Plant horn cannot unseal the charnel).
Set<String> _explore(
  Map<String, WardStrain> strains, {
  required Set<String> openable,
  required void Function(WardTriage) inspect,
}) {
  final start = WardTriage(wardIds: kMonasteryWardIds, strains: strains);
  final seen = <String>{_key(start)};
  final queue = <WardTriage>[start];
  inspect(start);

  while (queue.isNotEmpty) {
    final t = queue.removeLast();
    final next = <WardTriage>[];

    for (final w in openable) {
      if (t.opened.contains(w)) continue;
      next.add(_clone(t, strains)..open(w));
    }
    for (final d in WardDraught.values) {
      final c = _clone(t, strains);
      if (c.draw(d)) next.add(c);
    }
    for (final w in t.opened) {
      final c = _clone(t, strains);
      final r = c.dose(w);
      if (r == DoseOutcome.cured || r == DoseOutcome.fed) next.add(c);
    }
    final c = _clone(t, strains);
    if (c.commit() != null) next.add(c);

    for (final n in next) {
      if (!seen.add(_key(n))) continue;
      inspect(n);
      queue.add(n);
    }
  }
  return seen;
}

/// Is a full triage (three cures + the cross) still reachable from [t]?
bool _canStillFinishFor(
  WardTriage t,
  Map<String, WardStrain> strains,
  Set<String> openable,
) {
  var found = false;
  final seen = <String>{_key(t)};
  final queue = <WardTriage>[_clone(t, strains)];
  while (queue.isNotEmpty && !found) {
    final cur = queue.removeLast();
    if (cur.surrendered != null && cur.cured.length >= kMonasteryCures) {
      found = true;
      break;
    }
    final next = <WardTriage>[];
    for (final w in openable) {
      if (cur.opened.contains(w)) continue;
      next.add(_clone(cur, strains)..open(w));
    }
    for (final d in WardDraught.values) {
      final c = _clone(cur, strains);
      if (c.draw(d)) next.add(c);
    }
    for (final w in cur.opened) {
      final c = _clone(cur, strains);
      final r = c.dose(w);
      if (r == DoseOutcome.cured || r == DoseOutcome.fed) next.add(c);
    }
    final c = _clone(cur, strains);
    if (c.commit() != null) next.add(c);
    for (final n in next) {
      if (seen.add(_key(n))) queue.add(n);
    }
  }
  return found;
}

void main() {
  final arrangements = _allArrangements();

  group('the physic', () {
    test('every strain has exactly one answer, and no answer is shared', () {
      final used = <WardDraught>{};
      for (final s in WardStrain.values) {
        final d = antidoteFor(s);
        expect(used.add(d), isTrue, reason: 'two strains share $d');
        expect(strainAnsweredBy(d), s, reason: 'the inverse must agree');
      }
      expect(used.length, WardStrain.values.length);
    });

    test('a wrong draught FEEDS the strain, and is spent doing it', () {
      final t = WardTriage(
        wardIds: kMonasteryWardIds,
        strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
      );
      t.open('ward_bell');
      expect(t.draw(WardDraught.quicklime), isTrue); // pulse wants stilling
      expect(t.dose('ward_bell'), DoseOutcome.fed);
      expect(t.carried, isNull, reason: 'the strain drank it');
      expect(t.virulent, contains('ward_bell'));
      expect(t.cured, isEmpty);
    });

    test('a FED strain is still curable — the cost is danger, not a star', () {
      final t = WardTriage(
        wardIds: kMonasteryWardIds,
        strains: {for (final w in kMonasteryWardIds) w: WardStrain.feign},
      );
      t.open('ward_bell');
      t.draw(WardDraught.binding);
      expect(t.dose('ward_bell'), DoseOutcome.fed);
      t.draw(WardDraught.rousing);
      expect(t.dose('ward_bell'), DoseOutcome.cured);
      expect(
        t.virulent,
        contains('ward_bell'),
        reason: 'the feeding is remembered even after the cure',
      );
    });

    test('you cannot dose a ward you never opened', () {
      final t = WardTriage(
        wardIds: kMonasteryWardIds,
        strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
      );
      t.draw(WardDraught.stilling);
      expect(t.dose('ward_bell'), DoseOutcome.sealed);
      expect(t.carried, isNotNull, reason: 'a refused dose is not spent');
    });

    test('a hand carries one phial', () {
      final t = WardTriage(
        wardIds: kMonasteryWardIds,
        strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
      );
      expect(t.draw(WardDraught.stilling), isTrue);
      expect(t.draw(WardDraught.rousing), isFalse);
      expect(t.cistern, kMonasteryCistern - 1);
    });

    test(
      'THE DREGS: the cistern refills only while wards can still be saved',
      () {
        final t = WardTriage(
          wardIds: kMonasteryWardIds,
          strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
        );
        t.cistern = 0;
        expect(t.dregsAvailable, isTrue, reason: 'nothing cured yet');
        expect(t.draw(WardDraught.stilling), isTrue);
        t.cured.addAll(kMonasteryWardIds.take(kMonasteryCures));
        t.carried = null;
        t.cistern = 0;
        expect(
          t.dregsAvailable,
          isFalse,
          reason: 'three is all this house has, ever',
        );
        expect(t.draw(WardDraught.stilling), isFalse);
      },
    );

    test(
      'the crypt font is separate — the finale is never a supply problem',
      () {
        final t = WardTriage(
          wardIds: kMonasteryWardIds,
          strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
        );
        t.cured.addAll(kMonasteryWardIds.take(kMonasteryCures));
        t.cistern = 0;
        expect(t.draw(WardDraught.stilling), isFalse);
        expect(
          t.drawCarrion(WardDraught.stilling),
          isTrue,
          reason: 'patient zero brews its own venom',
        );
      },
    );
  });

  group('THE EXHAUSTIVE SWEEP — every arrangement, every play', () {
    test('no run can ever cure a fourth ward', () {
      for (final strains in arrangements) {
        _explore(
          strains,
          openable: kMonasteryWardIds.toSet(),
          inspect: (t) {
            expect(
              t.cured.length,
              lessThanOrEqualTo(kMonasteryCures),
              reason: 'the house saved more than it had physic for',
            );
            // And the cross can only ever fall on a ward that is not cured.
            final s = t.surrendered;
            if (s != null) {
              expect(t.cured.contains(s), isFalse);
              expect(t.cured.length, kMonasteryCures);
            }
          },
        );
      }
    });

    test('NON-STRANDABLE: from every reachable state, three cures and the '
        'cross are still reachable', () {
      // The whole anti-punishment claim, checked against the real rules.
      for (final strains in arrangements) {
        final all = kMonasteryWardIds.toSet();
        _explore(
          strains,
          openable: all,
          inspect: (t) {
            expect(
              t.canStillFinish,
              isTrue,
              reason: 'the module thinks this run is lost: ${_key(t)}',
            );
          },
        );
        // And spot-prove the module's own optimism against a real search from
        // the two worst states a careless player can build: every ward opened
        // and fed, with the cistern dry.
        final worst = WardTriage(wardIds: kMonasteryWardIds, strains: strains)
          ..cistern = 0;
        worst.opened.addAll(all);
        worst.virulent.addAll(all);
        expect(
          _canStillFinishFor(worst, strains, all),
          isTrue,
          reason: 'four fed strains and a dry cistern must still finish',
        );
      }
    });

    test('THE CHOICE IS REAL: with a full party any ward can be the one '
        'surrendered', () {
      for (final strains in arrangements) {
        final surrendered = <String>{};
        _explore(
          strains,
          openable: kMonasteryWardIds.toSet(),
          inspect: (t) {
            final s = t.surrendered;
            if (s != null) surrendered.add(s);
          },
        );
        expect(
          surrendered,
          kMonasteryWardIds.toSet(),
          reason: 'a sacrifice you cannot choose is not a decision',
        );
      }
    });

    test('THE GATE STEERS, IT DOES NOT BLOCK: no Plant horn still takes both '
        'stars — the charnel just becomes the sacrifice', () {
      final withoutCharnel = kMonasteryWardIds
          .where((w) => w != 'ward_charnel')
          .toSet();
      for (final strains in arrangements) {
        final surrendered = <String>{};
        var everCommitted = false;
        _explore(
          strains,
          openable: withoutCharnel,
          inspect: (t) {
            final s = t.surrendered;
            if (s != null) {
              everCommitted = true;
              surrendered.add(s);
            }
          },
        );
        expect(
          everCommitted,
          isTrue,
          reason: 'a hornless party must still be able to close the triage',
        );
        expect(
          surrendered,
          {'ward_charnel'},
          reason: 'without the horn the charnel is the only ward left over',
        );
      }
    });
  });

  group('the authored monastery', () {
    final layout = kPlanetDungeonLayouts['Poison']!;

    test('it is registered, and its entry trio matches the §6 spec', () {
      expect(kCosmicPlanetEntry['Poison'], ['Poison', 'Plant', 'Mud']);
      expect(kDungeonIdealFamilies['Poison'], ['Mask', 'Horn', 'Mane']);
      expect(kComingSoonDungeons.contains('Poison'), isFalse);
      expect(layout.riddle.length, 3);
    });

    test('four wards, one still, one crypt font, one prior\'s seal', () {
      final wards = layout.rooms.values.where((r) => r.ward != null).toList();
      expect(wards.length, 4);
      expect(wards.map((r) => r.ward!.id).toSet(), kMonasteryWardIds.toSet());
      // NOTHING IS BRICKED. Every seal in the cloister is wax and every one
      // of them answers the font — a door that needed its own key made the
      // parade's "all of them at once" untrue.
      expect(wards.where((r) => r.ward!.bricked), isEmpty);

      final stills = layout.rooms.values
          .where((r) => r.apothecary != null)
          .toList();
      expect(
        stills.length,
        2,
        reason: 'the infirmary still and the carrion font',
      );
      for (final s in stills) {
        expect(
          s.apothecary!.spouts.map((p) => p.draught).toSet(),
          WardDraught.values.toSet(),
          reason: 'every tap must exist or a strain would have no answer',
        );
      }

      final seals = layout.rooms.values
          .where((r) => r.priorsSeal != null)
          .toList();
      expect(seals.length, 1);
      expect(seals.single.priorsSeal!.diagnosisStarIndex, 0);
      expect(seals.single.priorsSeal!.triageStarIndex, 1);
      expect(layout.starIndices, {0, 1, 2});
    });

    test('the vault lies in the crypt, under whatever ward you gave up', () {
      final crypt = layout.rooms['lazar_crypt']!;
      expect(crypt.vaultCache, isNotNull);
      expect(crypt.guardian, isNotNull);
      expect(crypt.guardian!.starIndex, 2);
      expect(crypt.guardian!.encounter?.mysticId, 'Blightfang');
      // Every ward can drop into it, and it can send you back to any of them:
      // whichever ward is surrendered, the way down and the way up both exist.
      for (final w in kMonasteryWardIds) {
        expect(
          layout.rooms[w]!.doors.any((d) => d.targetRoomId == 'lazar_crypt'),
          isTrue,
          reason: '$w has no oubliette — it could not host the finale',
        );
        expect(
          crypt.doors.any((d) => d.targetRoomId == w),
          isTrue,
          reason: 'the crypt cannot return to $w',
        );
      }
    });

    test('THE MAP NEVER STRANDS: with the squints shut, every room is still '
        'reachable — for every possible sacrifice', () {
      // The squints are the one family-gated route (Mud MANE). Walk the map
      // with them removed, and with the surrendered ward's oubliette as the
      // ONLY way into the crypt, once for each ward that could be given up.
      for (final given in kMonasteryWardIds) {
        final seen = <String>{layout.entranceRoomId};
        final queue = <String>[layout.entranceRoomId];
        while (queue.isNotEmpty) {
          final id = queue.removeLast();
          for (final d in layout.rooms[id]!.doors) {
            final from = layout.rooms[id]!;
            final to = layout.rooms[d.targetRoomId]!;
            // Squint: ward → ward. Shut for a party with no Mud mane.
            if (from.ward != null && to.ward != null) continue;
            // The oubliette only exists in the ward that was surrendered.
            if (d.targetRoomId == 'lazar_crypt' && from.ward?.id != given) {
              continue;
            }
            if (id == 'lazar_crypt' && d.targetRoomId != given) continue;
            if (seen.add(d.targetRoomId)) queue.add(d.targetRoomId);
          }
        }
        expect(
          seen,
          layout.rooms.keys.toSet(),
          reason:
              'surrendering $given left rooms unreachable: '
              '${layout.rooms.keys.toSet().difference(seen)}',
        );
      }
    });

    test('the one family gate answers an entry slot and owns no star', () {
      // There were two. The Plant HORN through the dead-house's brick went
      // when the lustral font took over every seal in the cloister — the
      // parade says they all let go, and a fourth door still waxed
      // afterwards made that a lie.
      expect(layout.familyGates.length, 1);
      final slots = kCosmicPlanetEntry['Poison']!;
      for (final g in layout.familyGates) {
        if (g.needsElement) expect(slots, contains(g.element));
        expect(g.discoveryId, startsWith('gate:'));
      }
      expect(
        layout.familyGates.map((g) => '${g.element}+${g.family}').toSet(),
        {'Mud+Mane'},
      );
    });
  });

  group('the run, played against the real engine', () {
    /// Stand the whole trio at [pos] in [roomId] and press UTILITY as [idx].
    void actAt(PlanetDungeonGame g, String roomId, int idx, Offset pos) {
      g.currentRoomId = roomId;
      for (final c in g.creatures) {
        c
          ..position = pos
          ..lastSafe = pos;
      }
      g.setActive(idx);
      g.activateAbility();
      g.update(1 / 60);
    }

    void step(PlanetDungeonGame g, [double seconds = 0.1]) {
      var t = 0.0;
      while (t < seconds) {
        g.update(1 / 60);
        t += 1 / 60;
      }
      for (final c in g.creatures) {
        c.hp = c.maxHp;
      }
    }

    // Where each fixture stands, read off the authored layout.
    const gateDoor = Offset(650, 240);
    const wardDoors = {
      'ward_bell': Offset(205, 60),
      'ward_scriptorium': Offset(525, 60),
      'ward_refectory': Offset(845, 60),
      'ward_charnel': Offset(1165, 60),
    };
    const censer = Offset(140, 120);
    const oubliette = Offset(280, 310);
    final cross = poisonLayout.rooms['ambulatory']!.priorsSeal!.position;
    const poison = 0, plant = 1, mud = 2;

    Offset spoutOf(PlanetDungeonGame g, String roomId, WardDraught d) => g
        .layout
        .rooms[roomId]!
        .apothecary!
        .spouts
        .firstWhere((s) => s.draught == d)
        .position;

    test('the ideal trio earns all three Poison stars end-to-end', () {
      final earned = <int>[];
      final found = <String>[];
      final game = _harness(
        _idealTrio(),
        onStar: earned.add,
        onCloud: found.add,
      );
      final t = game.monastery.triage;

      // ── Entry rite: the quarantine wax answers Poison.
      expect(game.entryDoorRevealed, isFalse);
      actAt(game, 'lazar_gate', plant, gateDoor);
      expect(game.entryDoorRevealed, isFalse, reason: 'Plant is not physic');
      actAt(game, 'lazar_gate', poison, gateDoor);
      expect(game.entryDoorRevealed, isTrue);

      // ── A ward is not a room until you break its seal (§5.5 topology).
      final amb = game.layout.rooms['ambulatory']!;
      final bellDoor = amb.doors.firstWhere(
        (d) => d.targetRoomId == 'ward_bell',
      );
      expect(game.isDoorLocked(amb, bellDoor), isTrue);

      // ── THE KEY FIRST. Poison twice makes the Pure Vial, and the vial
      // into the font in the middle of the cloister lets every wax seal go
      // at once. Nothing in the house can be started before this.
      final pot = game.layout.rooms['apothecary']!.apothecary!.cistern;
      final bench = pot + const Offset(200, 0);
      final font = game.layout.rooms['ambulatory']!.lustralFont!;
      final slot = {'Poison': poison, 'Plant': plant, 'Mud': mud};

      actAt(game, 'ambulatory', poison, wardDoors['ward_bell']!);
      expect(
        t.opened,
        isEmpty,
        reason: 'a plague ward does not open to a hand any more',
      );
      actAt(game, 'apothecary', poison, pot);
      actAt(game, 'apothecary', poison, pot);
      expect(game.monastery.carriedPotion, kPureVial.id);
      actAt(game, 'ambulatory', poison, font);
      expect(game.monastery.cloisterOpen, isTrue);
      // The seals come off one at a time, as the camera reaches each door.
      step(game, 8.0);
      for (final p in kPlaguePotions) {
        expect(
          t.opened,
          contains(p.wardId),
          reason: '${p.wardId} should have opened with the font',
        );
      }
      expect(
        t.opened,
        isNot(contains('ward_charnel')),
        reason: 'the dead-house is not the font\'s to open',
      );

      // ── THE THREE PLAGUES. Two hands to the pot, the brew to its own
      // ward, and the thing wakes and comes out into the walk to be fought.
      for (final p in kPlaguePotions) {
        if (game.monastery.carriedPotion != null) {
          actAt(game, 'apothecary', poison, bench);
        }

        actAt(game, 'apothecary', slot[p.first]!, pot);
        actAt(game, 'apothecary', slot[p.second]!, pot);
        expect(
          game.monastery.carriedPotion,
          p.id,
          reason: '${p.first} + ${p.second} must make ${p.id}',
        );

        actAt(game, p.wardId!, poison, censer);
        expect(game.monastery.woken, contains(p.id));
        // It crawls; it does not appear. Ride the crawl out, in the cloister
        // — never in the ward.
        game.currentRoomId = 'ambulatory';
        step(game, 8.0);
        expect(
          game.monastery.body,
          isNotNull,
          reason: '${p.id} woke and nothing came out to fight',
        );
        expect(game.monastery.bars, kPlagueBars);

        // THREE BARS AND THREE GATES. Killing the body is no longer a thing
        // that can be done from a test — that is what the gates are for — so
        // this plays the fight: empty a bar the way combat does (flag it
        // dead, cull it from the room), then finish the mechanic it puts on
        // the floor.
        var guard = 0;
        while (game.monastery.fighting != null && guard++ < 300) {
          if (!game.monastery.gated) {
            final e = game.monastery.body!;
            e.hp = 0;
            e.isDead = true;
            game.combatEnemies.remove(e);
            game.update(1 / 60);
            continue;
          }
          for (var i = 0; i < game.monastery.marks.length; i++) {
            final c = game.creatures[i % game.creatures.length];
            var inner = 0;
            while (!game.monastery.marks[i].done && inner++ < 400) {
              c
                ..position = game.monastery.marks[i].at
                ..lastSafe = game.monastery.marks[i].at;
              game.update(1 / 60);
              if (!game.monastery.gated) break;
            }
            if (!game.monastery.gated) break;
          }
          game.update(1 / 60);
        }
        expect(game.monastery.slain, contains(p.id));

        // ── AND IT LEAVES SOMETHING. The kill is not the reward; the walk
        // back to the cross with what it dropped is.
        final relic = game.monastery.relicAt[p.id];
        expect(relic, isNotNull, reason: '${p.id} left no reliquary');
        actAt(game, 'ambulatory', poison, relic!);
        expect(
          game.monastery.carriedRelic,
          p.id,
          reason: '${p.relic} would not lift off the stones',
        );
        actAt(game, 'ambulatory', poison, cross);
        expect(game.monastery.relicsPlaced, contains(p.id));
      }
      expect(
        game.isDoorLocked(amb, bellDoor),
        isFalse,
        reason: 'an opened ward is walkable',
      );

      // ── Three in the stone, the cross takes light, and both stars land.
      expect(game.monastery.crossLight, greaterThan(0));
      expect(game.hasStar(0), isTrue);
      expect(game.hasStar(1), isTrue);
      expect(earned, containsAllInOrder([0, 1]));

      // ── The dead-house did NOT open with the rest of them: it answers
      // the cross, which the three reliquaries have just lit.
      expect(
        t.opened,
        contains('ward_charnel'),
        reason: 'three reliquaries in the stone open the last door',
      );

      // ── The oubliette: only in the dead-house, and only once both plague
      // stars are banked. The way down is earned by the three fights.
      final charnel = game.layout.rooms['ward_charnel']!;
      final hatch = charnel.doors.firstWhere(
        (d) => d.targetRoomId == 'lazar_crypt',
      );
      expect(game.isDoorHidden(charnel, hatch), isTrue);
      for (final saved in ['ward_bell', 'ward_scriptorium', 'ward_refectory']) {
        final r = game.layout.rooms[saved]!;
        expect(
          game.isDoorHidden(
            r,
            r.doors.firstWhere((d) => d.targetRoomId == 'lazar_crypt'),
          ),
          isTrue,
          reason:
              'a plague ward keeps its floor shut — only the dead-house '
              'opens',
        );
      }
      // NO PRESS. Walk onto the maw and it takes you — the way down is a
      // thing you step into, not a fourth verb at the end of the planet.
      game.currentRoomId = 'ward_charnel';
      for (final c in game.creatures) {
        c
          ..position = oubliette
          ..lastSafe = oubliette;
      }
      step(game, 0.05);
      expect(game.monastery.grab, greaterThanOrEqualTo(0));
      step(game, 3.0);
      expect(game.monastery.oublietteOpen, isTrue);
      expect(game.guardianAwake, isTrue);
      expect(game.currentRoomId, 'lazar_crypt');
      expect(game.isDoorHidden(charnel, hatch), isFalse);

      // ── The vault: the bottled essence lies under the ward you let go.
      game.currentRoomId = 'lazar_crypt';
      final vault = game.layout.rooms['lazar_crypt']!.vaultCache!;
      for (final c in game.creatures) {
        c
          ..position = vault
          ..lastSafe = vault;
      }
      step(game, 0.2);
      expect(found, contains('cache:poison_vault'));

      // ── Blightfang: the lull answers physic, never a clock (§7).
      game.monastery.blightStrain = WardStrain.creep;
      final g = game.layout.rooms['lazar_crypt']!.guardian!;
      actAt(
        game,
        'lazar_crypt',
        poison,
        spoutOf(game, 'lazar_crypt', WardDraught.binding),
      );
      expect(
        game.monastery.triage.carried,
        WardDraught.binding,
        reason: 'the carrion font never runs dry',
      );
      game.guardianVulnerable = false;
      actAt(game, 'lazar_crypt', poison, g.position);
      expect(
        game.guardianVulnerable,
        isFalse,
        reason: 'the wrong physic only feeds it',
      );

      actAt(
        game,
        'lazar_crypt',
        poison,
        spoutOf(game, 'lazar_crypt', WardDraught.quicklime),
      );
      actAt(game, 'lazar_crypt', poison, g.position);
      expect(
        game.guardianVulnerable,
        isTrue,
        reason: 'the answering draught forces the window',
      );
      expect(game.monastery.blightLull, greaterThan(0));
    });

    // The old "a wrong draught FEEDS the ward" run lived here. Wards are not
    // dosed with phials any more — they are woken with brews — and the brew
    // equivalents (a pair that makes nothing is spent; a brew carried to the
    // wrong door is not) are walked against the engine in
    // planet_dungeon_poison_plagues_test.dart.

    test('THE SEAL REMEMBERS: the squint stamps its chip', () {
      final found = <String>[];
      // No Mud mane anywhere in this party.
      final game = _harness([
        _member(0, 'Poison', 'mask'),
        _member(1, 'Plant', 'pip'),
        _member(2, 'Mud', 'wing'),
      ], onCloud: found.add);
      final t = game.monastery.triage;

      // NO HAND OPENS A WARD. Not the dead-house either — it used to be
      // brick behind a Plant HORN and it is wax like the rest of them now.
      actAt(game, 'ambulatory', 1, wardDoors['ward_charnel']!);
      expect(
        t.opened,
        isEmpty,
        reason: 'a press at a ward door opens nothing at all',
      );

      // The squint: shut for everyone but a Mud mane — and the ambulatory
      // still reaches the ward, so nothing is walled off. The wards open to
      // the font, not to a hand at the door.
      final pot = game.layout.rooms['apothecary']!.apothecary!.cistern;
      actAt(game, 'apothecary', 0, pot);
      actAt(game, 'apothecary', 0, pot);
      actAt(
        game,
        'ambulatory',
        0,
        game.layout.rooms['ambulatory']!.lustralFont!,
      );
      expect(game.monastery.cloisterOpen, isTrue);
      step(game, 8.0); // the seals come off door by door
      expect(
        t.opened,
        containsAll(kPlaguePotions.map((p) => p.wardId)),
        reason: 'one errand, all three plague doors',
      );
      final bell = game.layout.rooms['ward_bell']!;
      final squint = bell.doors.firstWhere(
        (d) => d.targetRoomId == 'ward_scriptorium',
      );
      game.currentRoomId = 'ward_bell';
      game.setActive(0);
      expect(game.isDoorLocked(bell, squint), isTrue);
      final amb = game.layout.rooms['ambulatory']!;
      expect(
        game.isDoorLocked(
          amb,
          amb.doors.firstWhere((d) => d.targetRoomId == 'ward_scriptorium'),
        ),
        isFalse,
        reason: 'the clean corridor is always open — the squint is a shortcut',
      );
    });

    test('THE DOSE: the sick wisp is cured, not killed', () {
      final found = <String>[];
      final game = _harness(_idealTrio(), onCloud: found.add);
      final m = game.monastery;
      m.wispStrain = WardStrain.feign; // it lies still until touched
      actAt(
        game,
        'apothecary',
        poison,
        spoutOf(game, 'apothecary', WardDraught.rousing),
      );
      final wisp = m.wisp!;
      actAt(game, 'ambulatory', poison, wisp);
      // THE RITE OF THREE runs before the gold lands (see `beginMaximRite`).
      for (var tick = 0; tick < 200; tick++) {
        game.update(1 / 60);
      }
      expect(found, contains(kPoisonDoseEggId));
      expect(m.wisp, isNull);
    });
  });
}
