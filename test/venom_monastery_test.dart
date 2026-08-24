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
//   4. the gate steers, it does not block — a party with no Lava horn can
//      still take both stars; the charnel simply becomes their sacrifice;
//   5. the map never strands — whichever ward is given up, every room
//      (crypt and vault included) is still reachable without a squint.
//
// Modelled on test/burn_field_test.dart, which proves Fire's garth the same
// way and for the same reason.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_poison.dart';
import 'package:flutter_test/flutter_test.dart';

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
/// party with no Lava horn cannot unseal the charnel).
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
bool _canStillFinishFor(WardTriage t, Map<String, WardStrain> strains,
    Set<String> openable) {
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
      expect(t.virulent, contains('ward_bell'),
          reason: 'the feeding is remembered even after the cure');
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

    test('THE DREGS: the cistern refills only while wards can still be saved',
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
      expect(t.dregsAvailable, isFalse,
          reason: 'three is all this house has, ever');
      expect(t.draw(WardDraught.stilling), isFalse);
    });

    test('the crypt font is separate — the finale is never a supply problem',
        () {
      final t = WardTriage(
        wardIds: kMonasteryWardIds,
        strains: {for (final w in kMonasteryWardIds) w: WardStrain.pulse},
      );
      t.cured.addAll(kMonasteryWardIds.take(kMonasteryCures));
      t.cistern = 0;
      expect(t.draw(WardDraught.stilling), isFalse);
      expect(t.drawCarrion(WardDraught.stilling), isTrue,
          reason: 'patient zero brews its own venom');
    });
  });

  group('THE EXHAUSTIVE SWEEP — every arrangement, every play', () {
    test('no run can ever cure a fourth ward', () {
      for (final strains in arrangements) {
        _explore(
          strains,
          openable: kMonasteryWardIds.toSet(),
          inspect: (t) {
            expect(t.cured.length, lessThanOrEqualTo(kMonasteryCures),
                reason: 'the house saved more than it had physic for');
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
            expect(t.canStillFinish, isTrue,
                reason: 'the module thinks this run is lost: ${_key(t)}');
          },
        );
        // And spot-prove the module's own optimism against a real search from
        // the two worst states a careless player can build: every ward opened
        // and fed, with the cistern dry.
        final worst = WardTriage(wardIds: kMonasteryWardIds, strains: strains)
          ..cistern = 0;
        worst.opened.addAll(all);
        worst.virulent.addAll(all);
        expect(_canStillFinishFor(worst, strains, all), isTrue,
            reason: 'four fed strains and a dry cistern must still finish');
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
        expect(surrendered, kMonasteryWardIds.toSet(),
            reason: 'a sacrifice you cannot choose is not a decision');
      }
    });

    test('THE GATE STEERS, IT DOES NOT BLOCK: no Lava horn still takes both '
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
        expect(everCommitted, isTrue,
            reason: 'a hornless party must still be able to close the triage');
        expect(surrendered, {'ward_charnel'},
            reason: 'without the horn the charnel is the only ward left over');
      }
    });
  });

  group('the authored monastery', () {
    final layout = kPlanetDungeonLayouts['Poison']!;

    test('it is registered, and its entry trio matches the §6 spec', () {
      expect(kCosmicPlanetEntry['Poison'], ['Poison', 'Lava', 'Mud']);
      expect(kDungeonIdealFamilies['Poison'], ['Mask', 'Horn', 'Mane']);
      expect(kComingSoonDungeons.contains('Poison'), isFalse);
      expect(layout.riddle.length, 3);
    });

    test('four wards, one still, one crypt font, one prior\'s seal', () {
      final wards = layout.rooms.values.where((r) => r.ward != null).toList();
      expect(wards.length, 4);
      expect(
        wards.map((r) => r.ward!.id).toSet(),
        kMonasteryWardIds.toSet(),
      );
      expect(wards.where((r) => r.ward!.bricked).map((r) => r.ward!.id),
          ['ward_charnel']);

      final stills =
          layout.rooms.values.where((r) => r.apothecary != null).toList();
      expect(stills.length, 2, reason: 'the infirmary still and the carrion font');
      for (final s in stills) {
        expect(
          s.apothecary!.spouts.map((p) => p.draught).toSet(),
          WardDraught.values.toSet(),
          reason: 'every tap must exist or a strain would have no answer',
        );
      }

      final seals =
          layout.rooms.values.where((r) => r.priorsSeal != null).toList();
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
        expect(seen, layout.rooms.keys.toSet(),
            reason: 'surrendering $given left rooms unreachable: '
                '${layout.rooms.keys.toSet().difference(seen)}');
      }
    });

    test('both family gates answer an entry slot, and neither owns a star',
        () {
      expect(layout.familyGates.length, 2);
      final slots = kCosmicPlanetEntry['Poison']!;
      for (final g in layout.familyGates) {
        expect(slots, contains(g.element));
        expect(g.discoveryId, startsWith('gate:'));
      }
      expect(
        layout.familyGates.map((g) => '${g.element}+${g.family}').toSet(),
        {'Lava+Horn', 'Mud+Mane'},
      );
    });
  });
}
