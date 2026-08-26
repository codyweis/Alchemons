// NYTHRALOR — the Eclipse Vault, pinned.
//
// Dark's topology is an INVERTING MAZE: one geometry cut into four quarters,
// each in shadow or in light, and which it is decides for every passage in it
// whether that passage is a door or a wall (docs §5.5). A global flip that
// swaps walls and doors is the purest stranding machine in the set — a flip
// can close the corridor you are standing in — so this file carries the two
// proofs the design cannot ship without, plus the counterfactuals that say
// the geometry is load-bearing rather than lucky:
//
//  1. THE NO-STRAND PROOF. A full reachability search over
//     (room × where each gnomon's shadow lies × which anchors are open),
//     enumerated under player moves AND Noctryos' beat, audited using only
//     the moves the player controls. It must be ZERO, and it must be zero
//     WITHOUT a reset valve — the first planet since Crystal to carry none.
//  2. SOLVABILITY. The authored trio walks the whole descent — all three
//     stars, the vault and the lost maxim — verb by verb, against the real
//     rules and only through passages the eclipse has actually opened.
//
// The rest pins the eclipse algebra (which is where the zero-sum lives), the
// promise rules every safe road is built on, the two hard gates, §4's
// first-descent guarantee, the vault trick and the guardian.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
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

/// The §6 ideal trio: Darkmask · Poisonpip · Spiritmane.
List<CosmicPartyMember> _idealTrio() => [
  _member(0, 'Dark', 'mask'),
  _member(1, 'Poison', 'pip'),
  _member(2, 'Spirit', 'mane'),
];

/// The same three ELEMENTS in families that clear nothing — the party §4
/// promises a first descent to.
List<CosmicPartyMember> _plainTrio() => [
  _member(0, 'Dark', 'horn'),
  _member(1, 'Poison', 'wing'),
  _member(2, 'Spirit', 'kin'),
];

const int dark = 0, poison = 1, spirit = 2;

PlanetDungeonGame harness(
  List<CosmicPartyMember> party, {
  void Function(int)? onStar,
  void Function(String)? onCloud,
}) {
  final game = PlanetDungeonGame(
    element: 'Dark',
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
/// it, because the Poison+Spirit braid is a two-body verb and has to be able
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
  return game.hintText;
}

final DungeonLayout layout = kPlanetDungeonLayouts['Dark']!;

DungeonDoor doorFrom(String room, String to) => layout.rooms[room]!.doors
    .firstWhere((d) => d.targetRoomId == to);

Offset gnomonShaft(String id) => vaultGnomonById(id)!.shaft;
Offset stoneAt(String id) => shadowStoneById(id)!.position;

/// Turn a gnomon the way the player does: stand at its shaft, in its room,
/// and press.
void turnGnomon(PlanetDungeonGame g, int idx, String gnomonId) {
  final gn = vaultGnomonById(gnomonId)!;
  final before = g.vault.shadowOf(gnomonId);
  act(g, idx, gn.roomId, gn.shaft);
  expect(
    g.vault.shadowOf(gnomonId),
    isNot(before),
    reason: '$gnomonId did not turn',
  );
}

/// Walk one passage, and REFUSE to walk one the eclipse has shut. Every step
/// of the scripted descent goes through here, so the run can never cheat past
/// a wall the player would meet.
void step(PlanetDungeonGame g, String to) {
  final from = g.currentRoomId;
  final door = doorFrom(from, to);
  final span = vaultSpanBetween(from, to)!;
  expect(
    g.vault.spanOpen(span),
    isTrue,
    reason: '$from → $to (${span.id}) is not open in this arrangement',
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

  group('the vault — one geometry, two states', () {
    test('every span is a real door pair, and every pair is one span', () {
      final pairs = <String>{};
      for (final s in kVaultSpans) {
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
      // And the other way: no door in the vault is outside the span graph, or
      // the proof would be walking a different map from the player.
      for (final room in layout.rooms.values) {
        for (final d in room.doors) {
          expect(
            vaultSpanBetween(room.id, d.targetRoomId),
            isNotNull,
            reason: '${room.id} → ${d.targetRoomId} has no span',
          );
        }
      }
    });

    test('every room declares a quarter, and every cut span names one', () {
      for (final room in layout.rooms.values) {
        expect(room.eclipse, isNotNull, reason: '${room.id} has no quarter');
      }
      for (final s in kVaultSpans) {
        if (s.cut == SpanCut.unmoved) {
          expect(s.leaf, isNull, reason: s.id);
          continue;
        }
        expect(s.leaf, isNotNull, reason: s.id);
      }
    });

    test('THE PLACEMENT RULE: a gnomon never stands behind the door it '
        'commands', () {
      // Reason 3 of the no-strand proof, and the one thing the geometry
      // actually depends on. Each finger stands in the UPPER of its two
      // quarters, so nothing below it is ever the only way back to it.
      for (final g in kVaultGnomons) {
        final room = layout.rooms[g.roomId];
        expect(room, isNotNull, reason: g.id);
        expect(
          room!.eclipse!.leaf,
          g.upper,
          reason: '${g.id} must stand in ${g.upper}, not below its own line',
        );
        expect(g.upper, isNot(g.lower), reason: g.id);
      }
      // One gnomon per room at most, and three fingers over four quarters —
      // which is the whole reason the vault is zero-sum.
      expect(kVaultGnomons.map((g) => g.roomId).toSet().length, 3);
      expect(kVaultGnomons.length, EclipseLeaf.values.length - 1);
    });

    test('THE PROMISE RULES: no room can ever have all its ways shut', () {
      // Every room is held open either by a TWINNED crossing (a shadow-way
      // and a light-walk through the SAME quarter, so exactly one is always
      // there) or by THE GNOMON'S PROMISE (both ways cut through the two
      // quarters of one finger, whose shadow is always in one of them). Two
      // rooms are deliberate exceptions and are named here rather than
      // silently skipped.
      const pocket = 'umbral_reliquary'; // one door; see the vault trick
      final arena = layout.rooms.values.firstWhere((r) => r.guardian != null);
      for (final room in layout.rooms.values) {
        if (room.id == pocket) continue;
        final spans = [
          for (final d in room.doors) vaultSpanBetween(room.id, d.targetRoomId)!,
        ];
        if (room.id == arena.id) {
          expect(
            spans.any((s) => s.cut == SpanCut.unmoved),
            isTrue,
            reason: 'the arena must keep a phase-free door — Noctryos flips '
                'the vault from in there',
          );
          continue;
        }
        final twinned = EclipseLeaf.values.any(
          (l) =>
              spans.any((s) => s.cut == SpanCut.shadowWay && s.leaf == l) &&
              spans.any((s) => s.cut == SpanCut.lightWalk && s.leaf == l),
        );
        final promised = kVaultGnomons.any(
          (g) =>
              spans.any(
                (s) => s.cut == SpanCut.shadowWay && s.leaf == g.upper,
              ) &&
              spans.any(
                (s) => s.cut == SpanCut.shadowWay && s.leaf == g.lower,
              ),
        );
        expect(
          twinned || promised,
          isTrue,
          reason: '${room.id} has no promise: it can be sealed shut',
        );
      }
      // The pocket really is a pocket, and its one door is the vault trick.
      final slot = layout.rooms[pocket]!.doors;
      expect(slot.length, 1);
      final span = vaultSpanBetween(pocket, slot.single.targetRoomId)!;
      expect(span.cut, SpanCut.shadowWay);
      expect(span.leaf, EclipseLeaf.deep);
    });
  });

  group('THE ECLIPSE ALGEBRA — where the zero-sum lives', () {
    /// Every arrangement of the three shadows, as a set of dark quarters.
    List<Set<EclipseLeaf>> arrangements() {
      final out = <Set<EclipseLeaf>>[];
      for (final a in [kVaultGnomons[0].upper, kVaultGnomons[0].lower]) {
        for (final b in [kVaultGnomons[1].upper, kVaultGnomons[1].lower]) {
          for (final c in [kVaultGnomons[2].upper, kVaultGnomons[2].lower]) {
            out.add({a, b, c});
          }
        }
      }
      return out;
    }

    test('three shadows over four quarters: never fewer than two dark, never '
        'more than two lit', () {
      for (final dark in arrangements()) {
        expect(dark.length, greaterThanOrEqualTo(2), reason: '$dark');
        expect(
          EclipseLeaf.values.length - dark.length,
          lessThanOrEqualTo(2),
          reason: '$dark',
        );
      }
    });

    test('ALL FOUR QUARTERS ARE NEVER DARK AT ONCE — which is Star 0', () {
      // Star 0's four stones each want their own quarter in shadow, so this
      // single fact is what turns the dial from a button into a journey.
      for (final dark in arrangements()) {
        expect(
          dark.length,
          lessThan(EclipseLeaf.values.length),
          reason: 'the analemma could be finished in one shape of the vault',
        );
      }
    });

    test('no two NEIGHBOURING quarters ever share the light', () {
      for (final dark in arrangements()) {
        for (final g in kVaultGnomons) {
          expect(
            dark.contains(g.upper) || dark.contains(g.lower),
            isTrue,
            reason: 'both of ${g.id}\'s quarters are lit in $dark — its '
                'shadow has to be in one of them',
          );
        }
      }
    });

    test('the live rules agree with the algebra', () {
      final v = EclipseVault();
      // Turning is involutive — reason 1 of the no-strand proof, and the
      // reason this planet needs no valve at all.
      for (final g in kVaultGnomons) {
        final before = v.shadowOf(g.id);
        v.turn(g.id);
        expect(v.shadowOf(g.id), isNot(before));
        v.turn(g.id);
        expect(v.shadowOf(g.id), before, reason: '${g.id} is not its own undo');
      }
      // A shadow-way and a light-walk through one quarter are opposites.
      for (final s in kVaultSpans) {
        if (s.cut == SpanCut.unmoved) {
          expect(v.spanOpen(s), isTrue);
          continue;
        }
        expect(
          v.spanOpen(s),
          s.cut == SpanCut.shadowWay ? v.isDark(s.leaf!) : v.isLit(s.leaf!),
        );
      }
      expect(v.litLeaves.length, lessThanOrEqualTo(2));
    });
  });

  group('THE NO-STRAND PROOF', () {
    final g = harness(_idealTrio());
    final r = g.solveEclipseVault();

    test('no state reachable by legal play can strand the party — and there '
        'is NO reset valve', () {
      // Ice (120/122), Mud (1200/1284), Dust (319/396) and Plant all shipped a
      // costly full-reset valve. Nythralor carries none, because a turn is its
      // own undo: the walk/turn relation is symmetric, so reachability over it
      // is an equivalence and the whole reachable set is one class.
      expect(
        r.strandable,
        0,
        reason:
            'from every one of ${r.states} states the world can reach, every '
            'room in the vault must still be reachable',
      );
      expect(r.states, 392, reason: 'the shipped count, pinned so a quiet '
          'change to the map shows up here');
      expect(r.arrangements, 8, reason: 'three shadows, two places each');
    });

    test('the arena\'s two safety belts are load-bearing, not decoration', () {
      // Noctryos is the ONE thing that flips the vault while the party is not
      // standing at a gnomon. Phase-cut the rood door and pull the floor-vane
      // and the fight can shut you in behind its own beat.
      expect(
        r.strandableWithoutVane,
        22,
        reason: 'if this is zero the arena is over-proofed and one of the two '
            'belts is dead weight — say so rather than leaving it in',
      );
    });

    test('MOVE A GNOMON BEHIND ITS OWN DOOR AND THE VAULT BECOMES A TRAP', () {
      // The counterfactual for the placement rule. Drop the walk and stair
      // fingers one quarter each, so each stands behind the very passage it
      // opens, and the descent stops having a way back.
      expect(
        r.strandableWithGnomonBelowItsDoor,
        124,
        reason: 'the placement is what makes the geometry work; if this is '
            'zero the rule is not doing anything and the header lies',
      );
      expect(
        r.strandableWithGnomonBelowItsDoor,
        greaterThan(r.strandableWithoutVane),
        reason: 'it should be the WORSE of the two failures by a long way',
      );
    });

    test('the measured algebra matches the authored one', () {
      expect(r.maxQuartersLit, 2);
      expect(
        r.allQuartersDarkStates,
        0,
        reason: 'Star 0 depends on this being impossible',
      );
    });
  });

  group('§4 — the first descent', () {
    test('STAR 0 IS UNGATED: a trio in the wrong families still banks it', () {
      // §6 put a Darkmask gate on this planet's FIRST star. §4's
      // first-descent guarantee wins, so the flipping verb is element-only
      // and that gate moved onto the rite's reredos. This is the test that
      // says so — a Dark HORN, a Poison WING and a Spirit KIN clear the dial.
      var star = -1;
      final g = harness(_plainTrio(), onStar: (i) => star = i);
      // The pall: element-only Dark.
      act(g, dark, 'pall_porch', layout.rooms['pall_porch']!.eclipse!
          .pallCurtain!);
      expect(g.entryDoorRevealed, isTrue);

      // Three quarters lie in shadow at the mouth of the run, and the creep
      // into the court is one of them.
      step(g, 'analemma_court');
      act(g, dark, 'analemma_court', stoneAt('stone_pall'));
      act(g, spirit, 'analemma_court', stoneAt('stone_gallery'));
      act(g, poison, 'analemma_court', stoneAt('stone_ossuary'));
      expect(g.vault.stonesSeated.length, 3);
      // And the fourth cannot be had here: the Deep stands in the light, and
      // no shape of the vault darkens all four (the algebra above).
      act(g, dark, 'analemma_court', stoneAt('stone_deep'));
      expect(g.vault.stonesSeated.length, 3);
      expect(g.hintText, contains('the Deep'));
      expect(g.hasStar(0), isFalse);

      // So: out to the fingers and back. Take the gallery's shadow off with
      // the walk gnomon, put the deep's on with the stair gnomon, then bring
      // the gallery's shadow back so the lych-way home is there again.
      step(g, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk');
      step(g, 'gnomon_stair');
      turnGnomon(g, dark, 'gn_stair');
      expect(g.vault.isDark(EclipseLeaf.deep), isTrue);
      step(g, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk');
      step(g, 'analemma_court');
      act(g, dark, 'analemma_court', stoneAt('stone_deep'));
      expect(g.vault.analemmaWoken, isTrue);
      expect(star, 0);
      // And not one anchor was touched: this party cannot open one.
      expect(g.vault.anchorsOpen, isEmpty);
    });

    test('a party with no Poison PIP is refused at the rings, and the seal '
        'remembers', () {
      final clouds = <String>[];
      final g = harness(_plainTrio(), onCloud: clouds.add);
      final an = vaultAnchorById('an_walk')!;
      act(g, poison, an.near, an.nearRing);
      expect(g.vault.anchorsOpen, isEmpty);
      expect(
        clouds,
        contains(
          layout.familyGateFor('anchor_ring')!.discoveryId,
        ),
        reason: '§4 "the seal remembers" — first refusal stamps the chip',
      );
    });

    test('the gate budget is legal: two gates, two keys, never two on one '
        'star', () {
      expect(layout.familyGates.length, 2);
      // The anchor ring was re-audited to VERB-ONLY: it is a narrow opening
      // and a pip is what fits through it — Poison never did anything to it.
      expect(
        layout.familyGates.map((x) => x.label).toSet(),
        {'any PIP', 'Dark MASK'},
      );
      // Every gate's element is one of the planet's three entry slots (§4).
      final entry = kCosmicPlanetEntry['Dark']!.toSet();
      for (final gate in layout.familyGates) {
        if (gate.needsElement) expect(entry, contains(gate.element));
      }
    });
  });

  group('THE DESCENT — the authored trio walks the whole vault', () {
    test('all three stars, the vault cache and the lost maxim', () {
      var stars = <int>[];
      final clouds = <String>[];
      final g = harness(
        _idealTrio(),
        onStar: (i) => stars.add(i),
        onCloud: clouds.add,
      );

      // ── the pall ────────────────────────────────────────
      act(g, dark, 'pall_porch', layout.rooms['pall_porch']!.eclipse!
          .pallCurtain!);
      expect(g.entryDoorRevealed, isTrue);

      // ── STAR 0 · the analemma ───────────────────────────
      step(g, 'analemma_court');
      act(g, dark, 'analemma_court', stoneAt('stone_pall'));
      act(g, spirit, 'analemma_court', stoneAt('stone_gallery'));
      act(g, poison, 'analemma_court', stoneAt('stone_ossuary'));
      step(g, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk');
      step(g, 'gnomon_stair');
      turnGnomon(g, dark, 'gn_stair');
      step(g, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk');
      step(g, 'analemma_court');
      act(g, dark, 'analemma_court', stoneAt('stone_deep'));
      expect(stars, contains(0));

      // ── THE VAULT, without a portal: in through the slot ─
      // The run's sharpest trade, walked. The gulf and the slot both want the
      // DEEP in shadow, and the stair head behind you wants the OSSUARY in
      // shadow — one finger cannot hold both, so the ossuary's shadow has to
      // come off the OTHER one before you come down.
      step(g, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk'); // the ossuary's shadow, off gn_walk
      expect(g.vault.isDark(EclipseLeaf.ossuary), isTrue);
      expect(g.vault.isDark(EclipseLeaf.deep), isTrue);
      step(g, 'gnomon_stair');
      step(g, 'abyssal_font');
      step(g, 'umbral_reliquary');
      expect(layout.rooms['umbral_reliquary']!.vaultCache, isNotNull);

      // ── THE ABYSS (the lost maxim) ──────────────────────
      step(g, 'abyssal_font');
      final rim = layout.rooms['abyssal_font']!.eclipse!.abyss!;
      for (var t = 0.0; t < _kAbyssRunSeconds; t += 1 / 30) {
        // "Utterly still" is the whole maxim, so the test holds the party on
        // its mark every frame — otherwise the combat sim's steering drifts
        // them and the vigil resets, which is exactly what it is there to do.
        for (final c in g.creatures) {
          c
            ..position = rim
            ..lastSafe = rim;
        }
        g.update(1 / 30);
      }
      expect(
        clouds,
        contains('egg:dark_abyss'),
        reason: 'a full minute of standing utterly still in the dark',
      );

      // ── STAR 1 · the three portals ──────────────────────
      // Every ring: the rust first, then both ends in shadow at once.
      final anWalk = vaultAnchorById('an_walk')!;
      step(g, 'gnomon_stair');
      step(g, 'penumbral_walk');
      // A hole is a hole in the DARK, at both ends. The walk stands in the
      // light after the descent, so the gallery's shadow has to come back
      // before this ring goes anywhere — and putting it back is what takes
      // the ossuary's away.
      turnGnomon(g, dark, 'gn_walk');
      expect(g.vault.isDark(EclipseLeaf.gallery), isTrue);
      expect(g.vault.isDark(EclipseLeaf.ossuary), isFalse);
      act(g, poison, 'penumbral_walk', anWalk.nearRing);
      expect(g.vault.anchorsOpen, contains('an_walk'));
      // The Spirit hand reads where it comes out before anyone steps in it.
      act(g, spirit, 'penumbral_walk', anWalk.nearRing);
      expect(g.vault.anchorsRead, contains('an_walk'));
      act(g, dark, 'penumbral_walk', anWalk.nearRing);
      expect(g.currentRoomId, 'umbral_reliquary');
      expect(g.vault.portalsWalked, contains('an_walk'));

      // Back out, and round for the other two.
      final anCourt = vaultAnchorById('an_court')!;
      final anNave = vaultAnchorById('an_nave')!;
      act(g, dark, 'umbral_reliquary', anWalk.farRing); // straight back
      expect(g.currentRoomId, 'penumbral_walk');
      turnGnomon(g, dark, 'gn_walk'); // and the ossuary's shadow back on
      step(g, 'shade_gallery');
      step(g, 'ossuary_ring');
      act(g, poison, 'ossuary_ring', anCourt.farRing);
      act(g, dark, 'ossuary_ring', anCourt.farRing);
      expect(g.currentRoomId, 'analemma_court');
      expect(g.vault.portalsWalked, contains('an_court'));

      step(g, 'pall_porch');
      act(g, poison, 'pall_porch', anNave.farRing);
      act(g, dark, 'pall_porch', anNave.farRing);
      expect(g.currentRoomId, 'eclipse_nave');
      expect(g.vault.everyPortalWalked, isTrue);
      expect(stars, contains(1));

      // ── the rite ────────────────────────────────────────
      final nave = layout.rooms['eclipse_nave']!;
      final reredos = nave.conduits.single;
      act(g, dark, 'eclipse_nave', reredos.position);
      expect((g.conduitEnergy['A'] ?? 0) > 0, isTrue);
      act(g, dark, 'eclipse_nave', nave.eclipse!.snuffer!);
      expect(g.conduitEnergy['B'], double.infinity);

      // ── STAR 2 · Noctryos ───────────────────────────────
      step(g, 'noctryos_totality');
      expect(layout.rooms['noctryos_totality']!.guardian!.starIndex, 2);

      // Nothing the run did can have stranded it.
      expect(g.solveEclipseVault().strandable, 0);
    });
  });

  group('the vault trick — a room that only EXISTS in the dark', () {
    test('the slot is not a shut door; it is not there', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final font = layout.rooms['abyssal_font']!;
      final slot = doorFrom('abyssal_font', 'umbral_reliquary');
      // The vault opens at the mouth of the run: the Deep starts LIT.
      expect(g.vault.isDark(EclipseLeaf.deep), isFalse);
      expect(
        g.isDoorHidden(font, slot),
        isTrue,
        reason: 'a shadow-way in a lit quarter must be blank wall, not a '
            'refusal — the room does not exist',
      );
      g.vault.turn('gn_stair');
      expect(g.vault.isDark(EclipseLeaf.deep), isTrue);
      expect(g.isDoorHidden(font, slot), isFalse);
    });

    test('a light-walk in shadow is the opposite: visible, and refused', () {
      final g = harness(_idealTrio());
      g.entryDoorRevealed = true;
      final ambulatory = doorFrom('gnomon_stair', 'ossuary_ring');
      expect(g.vault.isDark(EclipseLeaf.ossuary), isTrue);
      expect(
        g.isDoorHidden(layout.rooms['gnomon_stair']!, ambulatory),
        isFalse,
      );
      final hint = doorHint(g, 'gnomon_stair', ambulatory);
      expect(hint, isNotNull);
      expect(hint, contains('the Ossuary'));
      // §5.6 BLOCKED: one short clause naming what is missing, never a method.
      expect(hint!.split(RegExp(r'[.;]')).length, 1);
    });

    test('the vault cache is where the layout invariant says, and alone', () {
      final withCache = layout.rooms.values.where((r) => r.vaultCache != null);
      expect(withCache.length, 1);
      expect(withCache.single.id, 'umbral_reliquary');
    });
  });

  group('the rite and the guardian', () {
    test('the reredos is a hard Dark+MASK gate, and stamps its chip', () {
      final clouds = <String>[];
      final g = harness(_plainTrio(), onCloud: clouds.add);
      final reredos = layout.rooms['eclipse_nave']!.conduits.single;
      expect(reredos.requireElement, 'Dark');
      act(g, dark, 'eclipse_nave', reredos.position);
      expect((g.conduitEnergy['A'] ?? 0) > 0, isFalse);
      expect(clouds, contains(layout.familyGateFor('A')!.discoveryId));
    });

    test('the snuffer is element-only Dark, and waits on both stars', () {
      final g = harness(_idealTrio());
      final snuffer = layout.rooms['eclipse_nave']!.eclipse!.snuffer!;
      act(g, dark, 'eclipse_nave', snuffer);
      expect(g.conduitEnergy['B'] ?? 0, 0);
      expect(g.hintText, contains(layout.starName(0)));
      g.starMask = 0x3;
      // Poison+Spirit→Dark stands in for a Dark hand (§6's recipe).
      act(g, poison, 'eclipse_nave', snuffer);
      expect(g.conduitEnergy['B'], double.infinity);
    });

    test('Noctryos keeps its lull shut unless the Deep lies in shadow', () {
      final g = harness(_idealTrio());
      g.currentRoomId = 'noctryos_totality';
      g.guardianAwake = true;
      g.guardianVulnerable = true;
      expect(g.vault.isDark(EclipseLeaf.deep), isFalse);
      g.update(1 / 60);
      expect(g.guardianVulnerable, isFalse);
      g.vault.turn('gn_stair');
      g.guardianVulnerable = true;
      g.update(1 / 60);
      expect(g.guardianVulnerable, isTrue);
    });

    test('every strike beat throws the shadow off the Deep', () {
      final g = harness(_idealTrio());
      g.currentRoomId = 'noctryos_totality';
      g.guardianAwake = true;
      g.vault.turn('gn_stair');
      expect(g.vault.isDark(EclipseLeaf.deep), isTrue);
      g.guardianVulnerable = true;
      g.update(1 / 60); // the window opens
      g.guardianVulnerable = false;
      g.update(1 / 60); // the beat lands
      expect(
        g.vault.isDark(EclipseLeaf.deep),
        isFalse,
        reason: 'the guardian fights WITH the planet\'s rule (§7)',
      );
      // And the arena's own vane is the answer to it.
      act(g, dark, 'noctryos_totality',
          layout.rooms['noctryos_totality']!.eclipse!.shadowVane!);
      expect(g.vault.isDark(EclipseLeaf.deep), isTrue);
    });

    test('the rood door is the one passage the eclipse never touches', () {
      final rood = vaultSpanBetween('eclipse_nave', 'noctryos_totality')!;
      expect(rood.cut, SpanCut.unmoved);
      expect(rood.leaf, isNull);
      final v = EclipseVault();
      for (final g in kVaultGnomons) {
        v.turn(g.id);
        expect(v.spanOpen(rood), isTrue);
      }
    });
  });
}

/// Slightly over the authored minute, so the vigil actually completes.
const double _kAbyssRunSeconds = 61.0;
