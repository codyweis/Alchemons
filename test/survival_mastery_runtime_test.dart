import 'package:alchemons/games/cosmic_survival/survival_mastery_payload.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_runtime.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 2 of the Family Mastery design: the combat event foundation. None of
/// the 96 nodes exist yet, so these are the rules those nodes will be written
/// against — cast accounting, the recursion guard, proc cooldowns, the object
/// budget, and the shared elemental payload table.
void main() {
  SurvivalMasteryRuntime runtimeWith({
    CreatureFamily family = CreatureFamily.mane,
    int slotIndex = 0,
    List<String> nodes = const ['mane.assault.honed_pair'],
  }) {
    return SurvivalMasteryRuntime(
      snapshot: SurvivalFamilyMasterySnapshot({
        slotIndex: EquippedFamilyMastery(
          instanceId: 'test-$slotIndex',
          family: family,
          pathId: 'mane.assault',
          activeNodeIds: nodes,
        ),
      }),
    );
  }

  group('enablement', () {
    test('a party with no equipped path leaves the runtime inert', () {
      final runtime = SurvivalMasteryRuntime();
      expect(runtime.enabled, isFalse);
      // The hot path must cost nothing and, just as importantly, must not
      // hand out cast ids that would make projectiles look tracked.
      expect(
        runtime.beginCast(
          slotIndex: 0,
          family: CreatureFamily.mane,
          element: 'Fire',
          kind: MasteryCastKind.basic,
          projectileCount: 2,
        ),
        0,
      );
      expect(runtime.hasNode(0, 'mane.assault.honed_pair'), isFalse);
      expect(runtime.tryProc(0, 'anything', 1.0), isFalse);
    });

    test('an equipped path enables the runtime and its node lookups', () {
      final runtime = runtimeWith();
      expect(runtime.enabled, isTrue);
      expect(runtime.hasNode(0, 'mane.assault.honed_pair'), isTrue);
      expect(runtime.hasNode(0, 'mane.assault.crosscut'), isFalse);
      expect(runtime.hasNode(1, 'mane.assault.honed_pair'), isFalse);
      expect(runtime.hasPath(0, 'mane.assault'), isTrue);
      expect(runtime.hasPath(0, 'mane.control'), isFalse);
    });
  });

  group('cast accounting', () {
    test('one cast covers every projectile it threw', () {
      final runtime = runtimeWith();
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      expect(castId, isNot(0));
      expect(runtime.telemetryFor(0).basicCasts, 1);

      const target = 99;
      final first = runtime.recordHit(
        castId: castId,
        targetId: target,
        damage: 10,
      )!;
      expect(first.isFirstHitOnTarget, isTrue);
      expect(first.isDualHit, isFalse);
      expect(first.isFullVolleyHit, isFalse);

      final second = runtime.recordHit(
        castId: castId,
        targetId: target,
        damage: 10,
      )!;
      expect(second.hitIndexOnTarget, 2);
      expect(second.isDualHit, isTrue);
      expect(second.isFullVolleyHit, isTrue);
      expect(second.fromBasic, isTrue);
    });

    test('slashes landing on different bodies are not a dual hit', () {
      final runtime = runtimeWith();
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      final a = runtime.recordHit(castId: castId, targetId: 1, damage: 5)!;
      final b = runtime.recordHit(castId: castId, targetId: 2, damage: 5)!;
      expect(a.isDualHit, isFalse);
      expect(b.isDualHit, isFalse);
      expect(runtime.cast(castId)!.targetsHit, 2);
    });

    test('a second hit outside the window is not a pair', () {
      final runtime = runtimeWith();
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      runtime.recordHit(castId: castId, targetId: 7, damage: 5);
      // A slow trickle of pierces onto one body is not both blades landing.
      runtime.tick(kDualHitWindow + 0.05);
      final late = runtime.recordHit(castId: castId, targetId: 7, damage: 5)!;
      expect(late.hitIndexOnTarget, 2);
      expect(late.isDualHit, isFalse);
      // Full volley is a count, not a window, so it still holds.
      expect(late.isFullVolleyHit, isTrue);
    });

    test('a three-dart volley needs all three darts on one body', () {
      final runtime = runtimeWith(family: CreatureFamily.pip);
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.pip,
        element: 'Ice',
        kind: MasteryCastKind.basic,
        projectileCount: 3,
      );
      expect(
        runtime
            .recordHit(castId: castId, targetId: 3, damage: 1)!
            .isFullVolleyHit,
        isFalse,
      );
      expect(
        runtime
            .recordHit(castId: castId, targetId: 3, damage: 1)!
            .isFullVolleyHit,
        isFalse,
      );
      expect(
        runtime
            .recordHit(castId: castId, targetId: 3, damage: 1)!
            .isFullVolleyHit,
        isTrue,
      );
    });

    test('a payload target can only be claimed once per cast', () {
      final runtime = runtimeWith();
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      expect(runtime.claimPayloadTarget(castId, 4), isTrue);
      expect(runtime.claimPayloadTarget(castId, 4), isFalse);
      expect(runtime.claimPayloadTarget(castId, 5), isTrue);
    });

    test('expired casts stop answering', () {
      final runtime = runtimeWith();
      final castId = runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      runtime.tick(kCastLifetime + 1.5);
      expect(runtime.cast(castId), isNull);
      expect(runtime.recordHit(castId: castId, targetId: 1, damage: 1), isNull);
    });

    test('a cast id of 0 is never tracked', () {
      final runtime = runtimeWith();
      expect(runtime.cast(0), isNull);
      expect(runtime.recordHit(castId: 0, targetId: 1, damage: 1), isNull);
      expect(runtime.claimPayloadTarget(0, 1), isFalse);
    });
  });

  group('proc cooldowns', () {
    test('a claimed proc blocks until its cooldown elapses', () {
      final runtime = runtimeWith();
      expect(runtime.tryProc(0, 'crosscut', 1.0), isTrue);
      expect(runtime.tryProc(0, 'crosscut', 1.0), isFalse);
      expect(runtime.procRemaining(0, 'crosscut'), closeTo(1.0, 1e-9));
      runtime.tick(1.01);
      expect(runtime.tryProc(0, 'crosscut', 1.0), isTrue);
    });

    test('cooldowns are scoped by slot, effect and target', () {
      final runtime = runtimeWith(nodes: const ['mane.assault.honed_pair']);
      runtime.applySnapshot(
        SurvivalFamilyMasterySnapshot({
          0: EquippedFamilyMastery(
            instanceId: 'a',
            family: CreatureFamily.mane,
            pathId: 'mane.assault',
            activeNodeIds: const ['mane.assault.honed_pair'],
          ),
          1: EquippedFamilyMastery(
            instanceId: 'b',
            family: CreatureFamily.mane,
            pathId: 'mane.assault',
            activeNodeIds: const ['mane.assault.honed_pair'],
          ),
        }),
      );
      expect(runtime.tryProc(0, 'e', 5.0, targetId: 100), isTrue);
      expect(runtime.tryProc(0, 'e', 5.0, targetId: 100), isFalse);
      // A different body, a different effect and a different companion are
      // each their own budget.
      expect(runtime.tryProc(0, 'e', 5.0, targetId: 200), isTrue);
      expect(runtime.tryProc(0, 'other', 5.0, targetId: 100), isTrue);
      expect(runtime.tryProc(1, 'e', 5.0, targetId: 100), isTrue);
    });

    test('a zero cooldown always passes', () {
      final runtime = runtimeWith();
      for (var i = 0; i < 5; i++) {
        expect(runtime.tryProc(0, 'free', 0), isTrue);
      }
    });
  });

  group('recursion guard', () {
    test('mastery work cannot nest inside mastery work', () {
      final runtime = runtimeWith();
      var inner = 0;
      final outer = runtime.runGuarded<bool>(() {
        expect(runtime.isResolvingMastery, isTrue);
        // A payload whose damage kills, whose kill reaction would fire
        // another payload, finds the guard shut.
        final nested = runtime.runGuarded<bool>(() {
          inner++;
          return true;
        }, orElse: false);
        expect(nested, isFalse);
        return true;
      }, orElse: false);
      expect(outer, isTrue);
      expect(inner, 0);
      // The guard reopens once the outer application finishes.
      expect(runtime.isResolvingMastery, isFalse);
      expect(runtime.runGuarded<bool>(() => true, orElse: false), isTrue);
    });

    test('a throw inside the guard still reopens it', () {
      final runtime = runtimeWith();
      expect(
        () => runtime.runGuarded<bool>(
          () => throw StateError('boom'),
          orElse: false,
        ),
        throwsStateError,
      );
      expect(runtime.isResolvingMastery, isFalse);
    });
  });

  group('object budget', () {
    test('a burst is capped and then refills over time', () {
      final runtime = SurvivalMasteryRuntime(
        snapshot: SurvivalFamilyMasterySnapshot({
          0: EquippedFamilyMastery(
            instanceId: 'a',
            family: CreatureFamily.mane,
            pathId: 'mane.assault',
            activeNodeIds: const ['mane.assault.honed_pair'],
          ),
        }),
        masteryObjectsPerSecond: 10,
        masteryObjectBurst: 5,
      );
      expect(runtime.requestObjects(5), isTrue);
      expect(runtime.requestObjects(1), isFalse);
      runtime.tick(0.5);
      expect(runtime.requestObjects(5), isTrue);
      expect(runtime.requestObjects(1), isFalse);
    });

    test('the budget never banks more than one burst', () {
      final runtime = SurvivalMasteryRuntime(
        masteryObjectsPerSecond: 60,
        masteryObjectBurst: 30,
      );
      runtime.tick(30);
      expect(runtime.objectBudgetRemaining, 30);
    });
  });

  group('telemetry', () {
    test('damage is attributed by source, not lumped together', () {
      final runtime = runtimeWith();
      runtime.recordDamage(0, 100, MasteryDamageSource.basic);
      runtime.recordDamage(0, 50, MasteryDamageSource.special);
      runtime.recordDamage(0, 25, MasteryDamageSource.mastery);
      runtime.recordDamage(0, 1000, MasteryDamageSource.other);

      final stats = runtime.telemetryFor(0);
      expect(stats.basicDamage, 100);
      expect(stats.specialDamage, 50);
      expect(stats.masteryDamage, 25);
      // The ship's damage is not the companion's contribution.
      expect(stats.totalDamage, 175);
      expect(stats.masteryShare, closeTo(25 / 175, 1e-9));
    });

    test('healing, shielding, control and activations each have a bucket', () {
      final runtime = runtimeWith();
      runtime.recordHealing(0, 40);
      runtime.recordShielding(0, 30);
      runtime.recordControl(0, 1.5);
      runtime.recordPayload(0, count: 3);
      runtime.recordSpecialAmplification(0);
      runtime.recordCapstone(0);

      final stats = runtime.telemetryFor(0);
      expect(stats.healing, 40);
      expect(stats.shielding, 30);
      expect(stats.controlSeconds, 1.5);
      expect(stats.payloadApplications, 3);
      expect(stats.specialAmplifications, 1);
      expect(stats.capstoneActivations, 1);
      expect(runtime.telemetryReport()['slot0'], isA<Map<String, Object>>());
    });

    test('a run reset clears rhythm but not the equipped snapshot', () {
      final runtime = runtimeWith();
      runtime.beginCast(
        slotIndex: 0,
        family: CreatureFamily.mane,
        element: 'Fire',
        kind: MasteryCastKind.basic,
        projectileCount: 2,
      );
      runtime.recordDamage(0, 100, MasteryDamageSource.basic);
      runtime.tryProc(0, 'crosscut', 10);

      runtime.reset();
      expect(runtime.telemetryFor(0).basicDamage, 0);
      expect(runtime.procRemaining(0, 'crosscut'), 0);
      expect(runtime.clock, 0);
      // The path itself is the run's, locked at the start and untouched.
      expect(runtime.hasNode(0, 'mane.assault.honed_pair'), isTrue);
    });
  });

  group('elemental payload table', () {
    test('every element in the catalog resolves to something', () {
      for (final element in kPayloadElements) {
        final payload = resolveElementalPayload(
          element: element,
          elementalAttack: 100,
          triggeringDamage: 100,
        );
        expect(
          payload.isNotEmpty,
          isTrue,
          reason: '$element resolved to no actions',
        );
      }
    });

    test('an unknown element resolves to nothing rather than a free proc', () {
      final payload = resolveElementalPayload(
        element: 'Cheese',
        elementalAttack: 100,
      );
      expect(payload.isEmpty, isTrue);
      expect(identical(payload, ElementalPayload.none), isTrue);
    });

    test('node strength scales the payload', () {
      final full = resolveElementalPayload(
        element: 'Fire',
        elementalAttack: 100,
      );
      final reduced = resolveElementalPayload(
        element: 'Fire',
        elementalAttack: 100,
        strength: 0.8,
      );
      expect(full.actions.single.amount, closeTo(30, 1e-9));
      expect(reduced.actions.single.amount, closeTo(24, 1e-9));
    });

    test('zero strength fires nothing at all', () {
      expect(
        resolveElementalPayload(
          element: 'Fire',
          elementalAttack: 100,
          strength: 0,
        ).isEmpty,
        isTrue,
      );
    });

    test('a boss gets shorter control but the same damage', () {
      final normal = resolveElementalPayload(
        element: 'Water',
        elementalAttack: 100,
      );
      final onBoss = resolveElementalPayload(
        element: 'Water',
        elementalAttack: 100,
        vsBoss: true,
      );
      final normalSlow = normal.actions.firstWhere(
        (a) => a.effect == PayloadEffect.slow,
      );
      final bossSlow = onBoss.actions.firstWhere(
        (a) => a.effect == PayloadEffect.slow,
      );
      expect(bossSlow.duration, lessThan(normalSlow.duration));
      expect(bossSlow.amount, normalSlow.amount);

      // Fire is pure damage: a boss changes nothing about it.
      expect(
        resolveElementalPayload(
          element: 'Fire',
          elementalAttack: 100,
          vsBoss: true,
        ).actions.single.amount,
        closeTo(30, 1e-9),
      );
    });

    test('Earth staggers a body and slows a boss instead', () {
      expect(
        resolveElementalPayload(
          element: 'Earth',
          elementalAttack: 100,
        ).actions.single.effect,
        PayloadEffect.stagger,
      );
      final onBoss = resolveElementalPayload(
        element: 'Earth',
        elementalAttack: 100,
        vsBoss: true,
      ).actions.single;
      expect(onBoss.effect, PayloadEffect.slow);
      expect(onBoss.amount, closeTo(0.08, 1e-9));
    });

    test('Spirit echoes the hit that caused it, not the caster stat', () {
      final weakProc = resolveElementalPayload(
        element: 'Spirit',
        elementalAttack: 10000,
        triggeringDamage: 40,
      );
      expect(weakProc.actions.single.effect, PayloadEffect.delayedEcho);
      expect(weakProc.actions.single.amount, closeTo(10, 1e-9));
      expect(weakProc.actions.single.followUpDuration, closeTo(0.5, 1e-9));
    });

    test('Blood rate-limits itself because its payload is a resource', () {
      final blood = resolveElementalPayload(
        element: 'Blood',
        elementalAttack: 100,
      );
      expect(blood.procCooldown, 1.0);
      expect(blood.actions.single.effect, PayloadEffect.heal);
      // Every other element leaves rate limiting to the node.
      for (final element in kPayloadElements.where((e) => e != 'Blood')) {
        expect(
          resolveElementalPayload(
            element: element,
            elementalAttack: 100,
          ).procCooldown,
          0,
          reason: '$element should not carry its own cooldown',
        );
      }
    });

    test('Poison is the only element whose damage over time stacks', () {
      // Stacks add rate here, not duration, so a second element quietly
      // gaining a stack cap triples what it does rather than lengthening it.
      for (final element in kPayloadElements) {
        for (final action in resolveElementalPayload(
          element: element,
          elementalAttack: 100,
        ).actions) {
          if (action.effect != PayloadEffect.damageOverTime) continue;
          expect(
            action.maxStacks,
            element == 'Poison' ? 3 : 1,
            reason: '$element should not stack its burn',
          );
        }
      }
    });

    test('Light caps its amplification so sources cannot stack freely', () {
      final light = resolveElementalPayload(
        element: 'Light',
        elementalAttack: 100,
      ).actions.single;
      expect(light.effect, PayloadEffect.allyAmp);
      expect(light.amount, closeTo(0.05, 1e-9));
      expect(light.cap, closeTo(0.10, 1e-9));
    });

    test('Ice stacks into a freeze rather than freezing on contact', () {
      final ice = resolveElementalPayload(
        element: 'Ice',
        elementalAttack: 100,
      ).actions.single;
      expect(ice.effect, PayloadEffect.chill);
      expect(ice.maxStacks, 3);
      expect(ice.followUpDuration, greaterThan(0));
    });

    test('no payload deals damage without elemental attack behind it', () {
      for (final element in kPayloadElements) {
        final payload = resolveElementalPayload(
          element: element,
          elementalAttack: 0,
          triggeringDamage: 0,
        );
        expect(
          payload.immediateDamage,
          0,
          reason: '$element produced damage from nothing',
        );
      }
    });
  });
}
