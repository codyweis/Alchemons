import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_runtime.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 2 wiring, checked against the real combat loop rather than the
/// runtime in isolation: do casts reach the world stamped, do hits come back
/// accounted, does damage land in the right telemetry bucket, and does a
/// payload actually move survival's own status fields.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member({required String family, required String element}) =>
      CosmicPartyMember(
        instanceId: 'mastery-test',
        baseId: 'MST01',
        displayName: '$family $element',
        family: family,
        element: element,
        level: 10,
        slotIndex: 0,
        statSpeed: 4,
        statIntelligence: 4,
        statStrength: 4,
        statBeauty: 4,
        statSpeedPotential: 80,
        statIntelligencePotential: 80,
        statStrengthPotential: 80,
        statBeautyPotential: 80,
        staminaBars: 3,
        staminaMax: 3,
      );

  SurvivalFamilyMasterySnapshot snapshotFor(CreatureFamily family) {
    final path = FamilyMasteryCatalog.treeFor(family).paths.first;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'mastery-test',
        family: family,
        pathId: path.id,
        activeNodeIds: [path.nodes.first.id],
      ),
    });
  }

  /// A started game with one companion out and exactly one enemy parked away
  /// from the spawner's traffic, so every assertion is about that one body.
  Future<(CosmicSurvivalGame, CosmicSurvivalEnemy)> arena({
    required String family,
    required String element,
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: [member(family: family, element: element)],
      onGameOver: () {},
      masterySnapshot: snapshot,
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);

    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    final target = game.enemies.firstWhere((e) => !e.isDead);
    for (final enemy in game.enemies) {
      if (!identical(enemy, target)) enemy.isDead = true;
    }
    target
      ..position = game.orb.position + const Offset(280, 0)
      ..hp = 100000
      ..knockbackVelocity = Offset.zero;
    return (game, target);
  }

  group('cast identity', () {
    test('both slashes of one Mane cast carry the same cast id', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.basicCooldown = 0;
      game.companionProjectiles.clear();

      // One frame is one scheduled attack.
      game.update(1 / 60);
      final ids = game.companionProjectiles
          .where((p) => p.sourceSlotIndex == 0)
          .map((p) => p.masteryCastId)
          .toSet();
      expect(
        ids.length,
        1,
        reason: 'A Mane pair is one cast; its slashes disagreed: $ids',
      );
      expect(ids.single, isNot(0));

      final cast = game.mastery.cast(ids.single)!;
      expect(cast.kind, MasteryCastKind.basic);
      expect(cast.slotIndex, 0);
      expect(
        cast.projectileCount,
        2,
        reason: 'A Mane basic throws two slashes.',
      );
    });

    test('a later cast is a different cast', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.basicCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      final first = game.companionProjectiles.first.masteryCastId;

      game.companionProjectiles.clear();
      comp.basicCooldown = 0;
      comp.position = target.position - const Offset(120, 0);
      game.update(1 / 60);
      final second = game.companionProjectiles.first.masteryCastId;

      expect(second, isNot(first));
    });

    test('a party with no mastery gets no cast ids at all', () async {
      final (game, target) = await arena(family: 'Mane', element: 'Fire');
      expect(game.mastery.enabled, isFalse);
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(120, 0);
      comp.basicCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);

      expect(
        game.companionProjectiles.every((p) => p.masteryCastId == 0),
        isTrue,
        reason: 'With nothing equipped the runtime must stay out of the way.',
      );
      // Casts are still counted — telemetry works without a build.
      expect(game.mastery.telemetryFor(0).basicCasts, greaterThan(0));
    });

    test(
      'a special that rebuilds its own projectiles is still one cast',
      () async {
        // Mane+Spirit does not edit the ability table's output, it constructs a
        // fresh machine-gun stream from a seed. Projectiles built that way used
        // to reach the world with no cast at all.
        final (game, target) = await arena(
          family: 'Mane',
          element: 'Spirit',
          snapshot: snapshotFor(CreatureFamily.mane),
        );
        final comp = game.activeCompanions[0]!;
        comp.position = target.position - const Offset(120, 0);
        comp.specialCooldown = 0;
        comp.basicCooldown = 999;
        game.companionProjectiles.clear();
        game.update(1 / 60);

        final launched = game.companionProjectiles
            .where((p) => p.sourceSlotIndex == 0)
            .toList();
        expect(launched, isNotEmpty, reason: 'test setup: nothing was cast');
        final ids = launched.map((p) => p.masteryCastId).toSet();
        expect(ids.length, 1);
        expect(ids.single, isNot(0));
        expect(game.mastery.cast(ids.single)!.kind, MasteryCastKind.special);
      },
    );
  });

  group('hit and damage attribution', () {
    test('a basic hit is accounted and lands in the basic bucket', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(90, 0);
      comp.basicCooldown = 0;
      game.companionProjectiles.clear();
      game.update(1 / 60);
      final castId = game.companionProjectiles.first.masteryCastId;

      // Fly the slashes into the body.
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
        if (game.mastery.cast(castId)!.totalHits > 0) break;
      }

      final cast = game.mastery.cast(castId)!;
      expect(cast.totalHits, greaterThan(0));
      final stats = game.mastery.telemetryFor(0);
      expect(stats.basicDamage, greaterThan(0));
      expect(
        stats.masteryDamage,
        0,
        reason: 'No node exists yet, so nothing may be attributed to mastery.',
      );
    });

    test('a payload hit is attributed to mastery, not to the basic', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Plant',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final before = game.mastery.telemetryFor(0).masteryDamage;
      // Plant's payload is a root plus a thorn hit.
      expect(
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload',
          enemy: target,
        ),
        isTrue,
      );
      expect(game.mastery.telemetryFor(0).masteryDamage, greaterThan(before));
      expect(game.mastery.telemetryFor(0).basicDamage, 0);
    });
  });

  group('elemental payloads move survival\'s own status fields', () {
    test('Mud slows the body it lands on', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Mud',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final speedBefore = target.effectiveSpeed;
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
      );
      expect(target.slowTimer, greaterThan(0));
      expect(target.effectiveSpeed, lessThan(speedBefore));
      expect(game.mastery.telemetryFor(0).controlSeconds, greaterThan(0));
      expect(game.mastery.telemetryFor(0).payloadApplications, 1);
    });

    test('Fire burns over time and the burn ticks damage', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
      );
      expect(target.masteryDotTimer, greaterThan(0));
      expect(target.masteryDotDps, greaterThan(0));

      final hpBefore = target.hp;
      final masteryBefore = game.mastery.telemetryFor(0).masteryDamage;
      for (var i = 0; i < 30; i++) {
        game.update(1 / 60);
      }
      expect(target.hp, lessThan(hpBefore));
      expect(
        game.mastery.telemetryFor(0).masteryDamage,
        greaterThan(masteryBefore),
      );
    });

    test('Ice takes three stacks to freeze', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Ice',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      for (var i = 0; i < 2; i++) {
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload.$i',
          enemy: target,
        );
      }
      expect(target.masteryChillStacks, 2);
      expect(target.effectiveSpeed, greaterThan(0));

      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload.final',
        enemy: target,
      );
      expect(target.masteryChillStacks, 0);
      expect(
        target.effectiveSpeed,
        0,
        reason: 'The third stack should freeze the body outright.',
      );
    });

    test('Dark exposes the body to more damage from every source', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Dark',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      expect(target.masteryDamageTakenMultiplier, 1.0);
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
      );
      expect(target.masteryVulnerableTimer, greaterThan(0));
      expect(target.masteryDamageTakenMultiplier, greaterThan(1.0));
    });

    test('Air shoves the body away from its caster', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Air',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final comp = game.activeCompanions[0]!;
      comp.position = target.position - const Offset(60, 0);
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
      );
      expect(
        target.knockbackVelocity.dx,
        greaterThan(0),
        reason: 'The shove should point away from the caster, not toward it.',
      );
    });

    test('Blood heals its caster and rate-limits itself', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Blood',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final comp = game.activeCompanions[0]!;
      comp.currentHp = (comp.maxHp * 0.5).round();
      final hpBefore = comp.currentHp;

      expect(
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload.a',
          enemy: target,
        ),
        isTrue,
      );
      expect(comp.currentHp, greaterThan(hpBefore));
      // A second payload within the second is refused by the element's own
      // cooldown, even through a different node.
      expect(
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload.b',
          enemy: target,
        ),
        isFalse,
      );
      expect(game.mastery.telemetryFor(0).healing, greaterThan(0));
    });

    test('Spirit echoes after a delay rather than immediately', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Spirit',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
        triggeringDamage: 400,
      );
      final immediate = game.mastery.telemetryFor(0).masteryDamage;
      expect(immediate, 0, reason: 'The echo is late, by definition.');

      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(game.mastery.telemetryFor(0).masteryDamage, greaterThan(0));
    });
  });

  group('shared rules', () {
    test('a payload cannot fire inside another payload', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      final fired = game.mastery.runGuarded<bool>(
        () => game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload',
          enemy: target,
        ),
        orElse: false,
      );
      expect(fired, isFalse);
      expect(target.masteryDotTimer, 0);
    });

    test(
      'a node cooldown blocks its own repeat but not another node',
      () async {
        final (game, target) = await arena(
          family: 'Mane',
          element: 'Mud',
          snapshot: snapshotFor(CreatureFamily.mane),
        );
        expect(
          game.triggerElementalPayload(
            slotIndex: 0,
            effectId: 'node.a',
            enemy: target,
            procCooldown: 5,
          ),
          isTrue,
        );
        expect(
          game.triggerElementalPayload(
            slotIndex: 0,
            effectId: 'node.a',
            enemy: target,
            procCooldown: 5,
          ),
          isFalse,
        );
        expect(
          game.triggerElementalPayload(
            slotIndex: 0,
            effectId: 'node.b',
            enemy: target,
            procCooldown: 5,
          ),
          isTrue,
        );
      },
    );

    test(
      'a spent object budget skips the patch instead of queueing it',
      () async {
        final (game, target) = await arena(
          family: 'Mane',
          element: 'Lava',
          snapshot: snapshotFor(CreatureFamily.mane),
        );
        // Drain the budget the way a runaway node would.
        while (game.mastery.requestObjects(1)) {}
        final before = game.companionProjectiles.length;
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload',
          enemy: target,
        );
        expect(game.companionProjectiles.length, before);

        // With budget back, the same payload lays its patch.
        game.mastery.tick(1.0);
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload.again',
          enemy: target,
        );
        expect(game.companionProjectiles.length, greaterThan(before));
      },
    );

    test('a payload refuses a dead body and an empty slot', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Fire',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      target.isDead = true;
      expect(
        game.triggerElementalPayload(
          slotIndex: 0,
          effectId: 'test.payload',
          enemy: target,
        ),
        isFalse,
      );
      expect(
        game.triggerElementalPayload(
          slotIndex: 2,
          effectId: 'test.payload',
          enemy: target,
        ),
        isFalse,
      );
    });

    test('a run reset clears the previous run rhythm', () async {
      final (game, target) = await arena(
        family: 'Mane',
        element: 'Mud',
        snapshot: snapshotFor(CreatureFamily.mane),
      );
      game.triggerElementalPayload(
        slotIndex: 0,
        effectId: 'test.payload',
        enemy: target,
      );
      expect(game.mastery.telemetryFor(0).payloadApplications, 1);
      game.startGame();
      expect(game.mastery.telemetryFor(0).payloadApplications, 0);
      // The equipped build survives; it belongs to the account, not the run.
      expect(game.mastery.enabled, isTrue);
    });
  });
}
