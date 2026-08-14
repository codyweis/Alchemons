// Regression tests for the dungeon hint CHANNEL architecture (docs/dungeons.md
// §5.6): the capsule carries narrative only, resolved by priority rather than
// by whichever `_update*` happened to run last in the frame.
//
// What is pinned here:
//   • BLOCKED is attempt-edged — a sealed door states its refusal once, not
//     once per frame, and speaks again after the player leaves and returns.
//   • Mask insight is priority-protected — ambient flavor cannot stomp a
//     reading mid-read.
//   • Control feedback (cooldowns) never touches the capsule.
//   • Progress counters live in the persistent readout, not the capsule.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart'
    show CosmicSurvivalCompanion;
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member({
  required int slot,
  String element = 'Air',
  String family = 'wing',
}) {
  return CosmicPartyMember(
    instanceId: 'inst_$slot',
    baseId: 'base_$slot',
    displayName: 'Test $slot',
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
}

CosmicSurvivalCompanion _companion(CosmicPartyMember member, Offset position) {
  final stats = deriveCosmicSurvivalCompanionStats(member: member);
  return CosmicSurvivalCompanion(
    member: member,
    slotIndex: member.slotIndex,
    position: position,
    anchor: position,
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
  );
}

/// Party: an Air wing (slot 0) and a Crystal mask (slot 1) so both the glide
/// refusals and the Mask reading are reachable.
PlanetDungeonGame _buildGame() {
  final party = [
    _member(slot: 0),
    _member(slot: 1, element: 'Crystal', family: 'mask'),
  ];
  final game = PlanetDungeonGame(
    element: 'Air',
    party: party,
    initialStarMask: 0,
    onStarEarned: (_) {},
    onPlayerDown: () {},
    onChanged: () {},
  );
  game.currentRoomId = game.layout.entranceRoomId;
  final spawn = game.layout.entranceSpawn;
  for (var i = 0; i < party.length; i++) {
    final c = DungeonCreature(member: party[i])
      ..position = spawn + Offset(i * 60.0, 0)
      ..lastSafe = spawn + Offset(i * 60.0, 0);
    game.creatures.add(c);
    game.combatCompanions.add(_companion(party[i], c.position));
  }
  return game;
}

void _step(PlanetDungeonGame game, double seconds, {double dt = 1 / 60}) {
  var t = 0.0;
  while (t < seconds) {
    game.update(dt);
    t += dt;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BLOCKED is attempt-edged', () {
    test('a sealed door refuses once per approach, not once per frame', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      final sealedDoor = game.currentRoom.doors.firstWhere(
        (d) => d.targetRoomId == 'storm_rune_hall',
      );
      expect(game.isDoorLocked(game.currentRoom, sealedDoor), isTrue);

      final walker = game.creatures[game.activeIndex];
      walker.position = sealedDoor.rect.center;
      _step(game, 0.2);

      expect(game.hintText, contains('sealed'));
      expect(game.hintChannel, DungeonHintChannel.blocked);

      // Keep leaning on it well past the line's lifetime: the refusal must
      // fade and STAY faded instead of re-firing every frame.
      _step(game, 5.0);
      expect(
        game.hintText,
        isNull,
        reason: 'the refusal is spoken once per attempt, not re-latched',
      );

      // Walk away and come back: that is a NEW attempt, so it speaks again.
      walker.position = game.currentRoom.bounds.center;
      _step(game, 0.2);
      walker.position = sealedDoor.rect.center;
      _step(game, 0.2);
      expect(game.hintText, contains('sealed'));
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });

    test('a refused swap speaks on the blocked channel', () {
      final game = _buildGame();
      game.creatures[1].hp = 0;
      game.setActive(1);
      expect(game.activeIndex, 0, reason: 'a downed creature cannot take over');
      expect(game.hintText, contains('down'));
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });
  });

  group('insight is priority-protected', () {
    test('a Mask reading holds the capsule against ambient flavor', () {
      final game = _buildGame();
      game.currentRoomId = 'storm_rune_hall';
      game.setActive(1); // the Crystal mask
      game.creatures[1].position = game.currentRoom.bounds.center;
      game.activateAbility();

      expect(game.hintChannel, DungeonHintChannel.insight);
      final reading = game.hintText;
      expect(reading, isNotNull);

      // Run the world for a beat: proximity ambience must not stomp it.
      _step(game, 0.4);
      expect(game.hintText, reading);
      expect(game.hintChannel, DungeonHintChannel.insight);
    });

    test('a refusal may still interrupt a reading (BLOCKED outranks it)', () {
      final game = _buildGame();
      game.currentRoomId = 'storm_rune_hall';
      game.setActive(1);
      game.creatures[1].position = game.currentRoom.bounds.center;
      game.activateAbility();
      expect(game.hintChannel, DungeonHintChannel.insight);

      game.creatures[0].hp = 0;
      game.setActive(0);
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });
  });

  group('state has left the capsule', () {
    test('a cooling special writes to the control, never the hint line', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      final comp = game.combatCompanions[game.activeIndex];
      comp.specialCooldown = 4.0;

      expect(game.activateCombatAbility(), isFalse);
      expect(
        game.hintText,
        isNull,
        reason: 'cooldown feedback belongs on the button',
      );
      expect(game.abilityDeniedPulse, greaterThan(0));
      expect(game.abilityReady, isFalse);

      // The pulse is a beat, not a state — it decays on its own.
      _step(game, 0.6);
      expect(game.abilityDeniedPulse, 0);
    });

    test(
      'a cooling auto-attack writes to the control, never the hint line',
      () {
        final game = _buildGame();
        final comp = game.combatCompanions[game.activeIndex];
        comp.basicCooldown = 2.0;

        expect(game.activateAutoAttack(), isFalse);
        expect(game.hintText, isNull);
        expect(game.autoDeniedPulse, greaterThan(0));
        expect(game.autoAttackReady, isFalse);
        expect(game.autoCooldownLabel, isNot('ATTACK'));
      },
    );

    test('the loom anchors are a readout while the weave is live', () {
      final game = _buildGame();
      game.currentRoomId = 'sky_loom';
      final readout = game.progressReadout;
      expect(readout, isNotNull);
      expect(readout!.label, 'ANCHORS');
      expect(readout.value, startsWith('0/'));
    });

    test('the WIND count is a readout, not a hint line', () {
      // §9.1: the RINGS readout retired with Star 1's ring sequence; the
      // shrine tally took its slot beside the star tracker.
      final game = _buildGame();
      final shrineRoom = game.layout.rooms.values.firstWhere(
        (r) => r.gustShrines.isNotEmpty,
      );
      game.currentRoomId = shrineRoom.id;

      final readout = game.progressReadout;
      expect(readout, isNotNull);
      expect(readout!.label, 'WINDS');
      expect(readout.value, startsWith('0/'));
      expect(readout.fraction, 0);

      // Wake one: the count moves in the readout, and the capsule keeps its
      // own voice for what the shrine has to say.
      final shrine = shrineRoom.gustShrines.first;
      game.setActive(0);
      game.creatures[0]
        ..position = shrine.position
        ..lastSafe = shrine.position;
      game.activateAbility();
      _step(game, 0.1);

      expect(game.progressReadout!.value, startsWith('1/'));
      expect(game.hintText, isNot(contains('1/')));
    });
  });

  group('objectives state WHAT, never HOW (the solution-leak rule)', () {
    test('entering twin_conduit no longer hands over the method', () {
      final game = _buildGame();
      game.currentRoomId = 'storm_rune_hall';
      final door = game.currentRoom.doors.firstWhere(
        (d) => d.targetRoomId == 'twin_conduit',
      );
      game.creatures[game.activeIndex].position = door.rect.center;
      _step(game, 0.2);

      expect(game.currentRoomId, 'twin_conduit');
      expect(game.hintChannel, DungeonHintChannel.objective);
      expect(game.hintText, contains('sleep'));
      expect(game.hintText, isNot(contains('Lightning')));
      expect(game.hintText, isNot(contains('Fire')));
      expect(game.hintText, isNot(contains('arc B')));
    });

    test('the conduit method is earned through Mask insight, tiered', () {
      final game = _buildGame();
      game.currentRoomId = 'twin_conduit';
      game.setActive(1); // the Crystal mask (Int 3 → tier 1)
      // Stand clear of the conduits so the reading, not a channel attempt,
      // answers the press.
      game.creatures[1].position = game.currentRoom.bounds.center;
      game.activateAbility();

      expect(game.hintChannel, DungeonHintChannel.insight);
      // Tier 1 narrows the method without spelling out the leader's rule…
      expect(game.hintText, contains('ladder'));
      expect(game.hintText, isNot(contains('tallest')));

      // …tier 2 (a sharper mask) names element and order.
      final sharp = _member(slot: 1, element: 'Crystal', family: 'mask');
      final sharper = CosmicPartyMember(
        instanceId: sharp.instanceId,
        baseId: sharp.baseId,
        displayName: sharp.displayName,
        element: sharp.element,
        family: sharp.family,
        level: sharp.level,
        statSpeed: sharp.statSpeed,
        statIntelligence: 5,
        statStrength: sharp.statStrength,
        statBeauty: sharp.statBeauty,
        slotIndex: sharp.slotIndex,
        staminaBars: sharp.staminaBars,
        staminaMax: sharp.staminaMax,
      );
      final game2 = _buildGame();
      game2.creatures[1] = DungeonCreature(member: sharper)
        ..position = game2.layout.entranceSpawn
        ..lastSafe = game2.layout.entranceSpawn;
      game2.currentRoomId = 'twin_conduit';
      game2.setActive(1);
      game2.creatures[1].position = game2.currentRoom.bounds.center;
      game2.activateAbility();
      expect(game2.hintChannel, DungeonHintChannel.insight);
      expect(game2.hintText, contains('tallest'));
    });
  });

  group('stat nags speak on the failure moment, once per attempt', () {
    test('a too-fierce thermal refuses a walker once, not per frame', () {
      final game = _buildGame();
      game.currentRoomId = 'lower_spire';
      // The east flue wants Speed 3.5; the party walks with 3.
      final walker = game.creatures[game.activeIndex];
      walker.position = const Offset(690, 500); // inside the flue
      walker.lastSafe = walker.position;
      _step(game, 0.2);

      expect(game.hintText, contains('Speed'));
      expect(game.hintChannel, DungeonHintChannel.blocked);

      // Keep standing in it: the refusal fades and must NOT re-latch.
      _step(game, 5.0);
      expect(game.hintText, isNot(contains('Speed')));

      // Step out and back in: a new attempt, so it speaks again.
      walker.position = const Offset(300, 870);
      walker.lastSafe = walker.position;
      _step(game, 0.2);
      walker.position = const Offset(690, 500);
      walker.lastSafe = walker.position;
      _step(game, 0.2);
      expect(game.hintText, contains('Speed'));
      expect(game.hintChannel, DungeonHintChannel.blocked);
    });

    test('a strong current refuses a flier once, on the shove-back', () {
      final game = _buildGame();
      game.currentRoomId = 'lower_spire';
      final flier = game.creatures[0];
      game.setActive(0);
      game.flightMax = 999;
      game.flightMeter = 999;
      game.flightActive = true;

      // Fly INTO the Speed-3.5 flue, pinning position each frame (the
      // joystick fighting the shove) so the creature stays inside it.
      const inColumn = Offset(690, 500);
      for (var i = 0; i < 12; i++) {
        flier.position = inColumn;
        game.update(1 / 60);
      }
      expect(game.hintText, contains('Speed'));
      expect(game.hintChannel, DungeonHintChannel.blocked);

      // Keep fighting it well past the line's lifetime: spoken once.
      for (var i = 0; i < 300; i++) {
        flier.position = inColumn;
        game.update(1 / 60);
      }
      expect(game.hintText, isNot(contains('Speed')));
    });
  });
}
