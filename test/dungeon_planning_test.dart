import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_blood.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_dark.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_light.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_plant.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_layout_spirit.dart';
import 'package:flutter_test/flutter_test.dart';

PlanetDungeonGame game(String element) {
  final party = [
    for (final (i, e) in kCosmicPlanetEntry[element]!.indexed)
      CosmicPartyMember(
        instanceId: '$i',
        baseId: '$i',
        displayName: e,
        element: e,
        family: 'mane',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
  ];
  final g = PlanetDungeonGame(
    element: element,
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  g.currentRoomId = g.layout.entranceRoomId;
  g.entryDoorRevealed = true;
  for (final m in party) {
    g.creatures.add(
      DungeonCreature(member: m)
        ..position = g.layout.entranceSpawn
        ..lastSafe = g.layout.entranceSpawn,
    );
  }
  return g;
}

void stand(PlanetDungeonGame g, String room, Offset at) {
  g.currentRoomId = room;
  for (final c in g.creatures) {
    c.position = at;
    c.lastSafe = at;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every Plant bed previews the actual size trade before planting', () {
    final g = game('Plant');
    for (final bed in kCryptBeds) {
      stand(g, bed.roomId, bed.crown);
      for (final scale in PlantScale.values) {
        g.crypt.reset();
        g.crypt.scale = scale;
        final line = g.puzzlePreview!;
        expect(g.crypt.stateOf(bed.id), VineState.bare);
        expect(
          line,
          contains(scale == PlantScale.tiny ? 'grow trunk' : 'grow creeper'),
        );
        expect(
          line,
          contains(
            scale == PlantScale.tiny ? 'Closes the crack' : 'Keeps the crack',
          ),
        );
        expect(line, isNot(contains('somewhere')));
        g.activateAbility();
        expect(
          g.crypt.stateOf(bed.id),
          scale == PlantScale.tiny ? VineState.trunk : VineState.creeper,
        );
      }
    }
  });

  test('Spirit names both ends and both worlds without resting the ghost', () {
    final g = game('Spirit');
    for (final r in kGraveRevenants) {
      stand(g, r.toldAt, r.seat);
      final before = g.wake.field.rested.toSet();
      final line = g.puzzlePreview!;
      expect(line, contains(r.name));
      expect(line, contains('opens for the living, closes for ghosts'));
      expect(line, isNot(contains('somewhere')));
      expect(g.wake.field.rested, before);
    }
  });

  test('Dark forecasts overlapping shadows without changing the vault', () {
    final g = game('Dark');
    for (var bits = 0; bits < 8; bits++) {
      for (final (i, gn) in kVaultGnomons.indexed) {
        g.vault.shadow[gn.id] = bits & (1 << i) == 0 ? gn.upper : gn.lower;
      }
      for (final gn in kVaultGnomons) {
        stand(g, gn.roomId, gn.shaft);
        final before = Map.of(g.vault.shadow);
        final inversions = g.vault.inversions;
        final line = g.puzzlePreview!;
        expect(line, startsWith('Dark · shadow toward'));
        expect(g.vault.shadow, before);
        expect(g.vault.inversions, inversions);
        final next = g.vault.shadowOf(gn.id) == gn.upper ? gn.lower : gn.upper;
        expect(line, contains(leafWord(next)));
      }
    }
  });

  test('Light forecasts all 125 arrangements without changing live state', () {
    final g = game('Light');
    for (var n = 0; n < 125; n++) {
      var state = n;
      for (final b in kArchiveBeacons) {
        g.archive.lamp[b.id] = state % b.stateCount;
        state ~/= b.stateCount;
      }
      for (final b in kArchiveBeacons) {
        stand(g, b.roomId, b.post);
        final before = Map.of(g.archive.lamp);
        final worst = g.archive.worstLumens;
        final line = g.puzzlePreview!;
        final readout = g.progressReadout!;
        expect(g.archive.lamp, before);
        expect(g.archive.worstLumens, worst);
        g.archive.press(b.id);
        expect(line, contains('→ ${g.archive.lumens} lumens'));
        expect(readout.value, startsWith('${g.archive.lumens}/'));
        g.archive.lamp
          ..clear()
          ..addAll(before);
      }
    }
  });

  test('Blood advances exactly one phase from any point, including wrap', () {
    final g = game('Blood');
    for (final phase in PulsePhase.values) {
      for (final fraction in [0.0, 0.3, 0.99]) {
        g.heart.reset();
        g.heart.advance(
          pulsePhaseStart(phase) + kPulsePhaseSeconds[phase.index] * fraction,
        );
        final beforeRoom = g.currentRoomId;
        expect(g.canAdvanceHeartPulse, isTrue);
        g.advanceHeartPulse();
        expect(g.heart.phase, nextPulsePhase(phase));
        expect(g.heart.clock, pulsePhaseStart(nextPulsePhase(phase)));
        expect(g.currentRoomId, beforeRoom);
        expect(g.heart.beats, phase == PulsePhase.flatline ? 1 : 0);
      }
    }
  });

  test(
    'Blood settles a queued mouth immediately and cannot skip its fight',
    () {
      final g = game('Blood');
      final o = kHeartOstia.firstWhere((o) => o.phase != PulsePhase.systole);
      stand(g, o.roomId, o.position);
      g.setActive(g.party.indexWhere((m) => m.element == o.element));
      g.activateAbility();
      expect(g.heart.laid, contains(o.id));
      for (var i = 0; i < 3 && g.heart.phase != o.phase; i++) {
        g.advanceHeartPulse();
      }
      expect(g.heart.ostiaPrimed, contains(o.id));
      expect(g.heart.laid, isNot(contains(o.id)));
      expect(g.hasCombatTargets, isTrue);
      final clock = g.heart.clock;
      expect(g.canAdvanceHeartPulse, isFalse);
      g.advanceHeartPulse();
      expect(g.heart.clock, clock);
    },
  );

  test('Blood does not prime a mouth after leaving its room', () {
    final g = game('Blood');
    final o = kHeartOstia.firstWhere((o) => o.phase != PulsePhase.systole);
    stand(g, o.roomId, o.position);
    g.setActive(g.party.indexWhere((m) => m.element == o.element));
    g.activateAbility();
    stand(g, g.layout.entranceRoomId, g.layout.entranceSpawn);
    for (var i = 0; i < 4; i++) {
      g.advanceHeartPulse();
    }
    expect(g.heart.ostiaPrimed, isEmpty);
    expect(g.heart.laid, isEmpty);
  });

  test('Blood skips resolve an inspected clot on the flatline', () {
    final g = game('Blood');
    final cock = kHeartCocks.first;
    g.heart.soundCollaterals.remove(cock.passageId);
    g.heart.cocksTurned.add(cock.passageId);
    g.heart.clotSeen.add(cock.passageId);
    stand(g, cock.roomId, cock.position);
    g.setActive(g.party.indexWhere((m) => m.element == 'Blood'));
    g.activateAbility();
    expect(g.heart.laid, contains(cock.passageId));
    for (var i = 0; i < 3; i++) {
      g.advanceHeartPulse();
    }
    expect(g.heart.phase, PulsePhase.flatline);
    expect(g.heart.grafted, contains(cock.passageId));
    expect(g.heart.laid, isEmpty);
  });

  test(
    'Blood forecasts respect ritual gates and always show current phase',
    () {
      final g = game('Blood');
      stand(g, 'myocardium', const Offset(20, 20));
      expect(g.puzzlePreview, isNot(contains('Systole')));
      for (final room in g.layout.rooms.values) {
        g.currentRoomId = room.id;
        expect(g.progressReadout!.label, phaseTag(g.heart.phase));
      }
    },
  );

  test(
    'Blood cannot skip a guardian, arrest, closed entry or absent party',
    () {
      final g = game('Blood');
      g.entryDoorRevealed = false;
      expect(g.canAdvanceHeartPulse, isFalse);
      g.entryDoorRevealed = true;
      g.heart.arrestFor(3);
      expect(g.canAdvanceHeartPulse, isFalse);
      g.heart.reset();
      g.currentRoomId = 'sanguorath_systole';
      g.guardianAwake = true;
      expect(g.canAdvanceHeartPulse, isFalse);
      final clock = g.heart.clock;
      g.advanceHeartPulse();
      expect(g.heart.clock, clock);
      g.currentRoomId = g.layout.entranceRoomId;
      g.creatures.clear();
      expect(g.canAdvanceHeartPulse, isFalse);
    },
  );
}
