import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kin's two paths, driven through the real game.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CosmicPartyMember member(
    String family,
    String element, {
    int slotIndex = 0,
  }) => CosmicPartyMember(
    instanceId: '$family-$slotIndex',
    baseId: family == 'Kin' ? 'KIN01' : 'MAN01',
    displayName: '$family $element',
    family: family,
    element: element,
    level: 10,
    slotIndex: slotIndex,
    statSpeed: 4.25,
    statIntelligence: 4.25,
    statStrength: 4.25,
    statBeauty: 4.25,
    statSpeedPotential: 50,
    statIntelligencePotential: 50,
    statStrengthPotential: 50,
    statBeautyPotential: 50,
    staminaBars: 3,
    staminaMax: 3,
  );

  CosmicPartyMember kin(String element) => member('Kin', element);

  SurvivalFamilyMasterySnapshot equip(String pathId, {int throughTier = 4}) {
    final path = FamilyMasteryCatalog.pathFor(CreatureFamily.kin, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: 'Kin-0',
        family: CreatureFamily.kin,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  /// [party] on the field, loose, once the first wave has bodies in it.
  Future<CosmicSurvivalGame> arena({
    String element = 'Dark',
    List<CosmicPartyMember>? party,
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final members = party ?? [kin(element)];
    final game = CosmicSurvivalGame(
      party: members,
      onGameOver: () {},
      masterySnapshot: snapshot,
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    // One more on the field for each Pack Leader, as a run grants them.
    for (var i = 1; i < members.length; i++) {
      game.applyPowerUp(kAllPowerUps.firstWhere((d) => d.id == 'pack_leader'));
    }
    game.startGame();
    for (var i = 0; i < members.length; i++) {
      game.summonCompanion(i);
    }
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    return game;
  }

  /// A Kin of [element] in slot 0 and a Mane beside it in slot 1.
  Future<CosmicSurvivalGame> pair(
    String element, {
    SurvivalFamilyMasterySnapshot? snapshot,
  }) => arena(
    party: [kin(element), member('Mane', 'Fire', slotIndex: 1)],
    snapshot: snapshot,
  );

  group('Conduction helps what the line crosses', () {
    test('the ship on the line is healed by a Lifeline Kin', () async {
      Future<double> shipRecovery({
        SurvivalFamilyMasterySnapshot? snapshot,
      }) async {
        final game = await arena(snapshot: snapshot);
        final caster = game.activeCompanions[0]!;
        // Loose, so it goes out and fights. Tethered, it waits at the ship
        // for enemies to walk into range, and the whole comparison came down
        // to whether one shot happened to land in the last second.
        game.clearCompanionTether();
        game.ship.currentHp = game.ship.maxHp * 0.2;
        var gained = 0.0;
        for (var i = 0; i < 60 * 25; i++) {
          caster.specialCooldown = 99999;
          // Stand the ship between the Kin and whatever it is shooting —
          // its locked target when it has one, not just the first body in
          // the list (which is only sometimes the same thing).
          final locked = caster.stickyTarget;
          final target = locked != null && !locked.isDead
              ? locked
              : game.enemies.firstWhere(
                  (e) => !e.isDead,
                  orElse: () => game.enemies.first,
                );
          final dir = target.position - caster.position;
          final len = dir.distance;
          if (len > 1) game.ship.position = caster.position + dir / len * 60;
          final before = game.ship.currentHp;
          game.update(1 / 60);
          final delta = game.ship.currentHp - before;
          if (delta > 0) gained += delta;
        }
        return gained;
      }

      final plain = await shipRecovery();
      final conducted = await shipRecovery(
        snapshot: equip(KinNodes.conductionPath, throughTier: 2),
      );
      expect(conducted, greaterThan(plain));
    });

    test('an unequipped Kin gives the line nothing', () async {
      final game = await arena();
      for (var i = 0; i < 60 * 15; i++) {
        game.update(1 / 60);
      }
      expect(game.kinMasteryFor(0)?.shieldGranted ?? 0, 0);
    });
  });

  group('Benediction carries the support to the team', () {
    /// The ally beside a Kin of [element] after the Kin's first cast: what
    /// it was healed, and the blessing it was left with.
    Future<(int, double)> kindred(
      String element, {
      required bool equipped,
    }) async {
      final game = await pair(
        element,
        snapshot: equipped
            ? equip(KinNodes.benedictionPath, throughTier: 1)
            : null,
      );
      final caster = game.activeCompanions[0]!;
      final ally = game.activeCompanions[1]!;
      ally.currentHp = ally.maxHp ~/ 5;
      caster.specialCooldown = 0;
      var blessing = 0.0;
      var cast = false;
      // Until the Kin has cast: it needs something in reach to cast at.
      for (var i = 0; i < 60 * 15 && !cast; i++) {
        // The ally stands beside the Kin, and casts nothing of its own.
        ally.position = caster.position + const Offset(40, 0);
        ally.specialCooldown = 99;
        final was = caster.specialCooldown;
        game.update(1 / 60);
        cast = caster.specialCooldown > was;
        blessing = ally.blessingTimer;
      }
      expect(cast, isTrue, reason: '$element Kin never cast');
      final healed = game.kinMasteryFor(0)?.kindredGiven ?? 0;
      return (healed.round(), blessing);
    }

    test('Kindred: the ally beside the Kin gets its heal and blessing',
        () async {
      for (final element in ['Water', 'Steam', 'Dark']) {
        final (plainGiven, plainBlessing) = await kindred(
          element,
          equipped: false,
        );
        expect(plainGiven, 0, reason: element);
        expect(plainBlessing, 0, reason: '$element: no blessing reached it');
        final (given, blessing) = await kindred(element, equipped: true);
        expect(given, greaterThan(0), reason: element);
        expect(blessing, greaterThan(0), reason: element);
      }
    });

    test('Kindred for Kin+Fire: the ally beside it rises with the phoenix',
        () async {
      Future<double> risen({required bool equipped}) async {
        final game = await pair(
          'Fire',
          snapshot: equipped
              ? equip(KinNodes.benedictionPath, throughTier: 1)
              : null,
        );
        final caster = game.activeCompanions[0]!;
        final ally = game.activeCompanions[1]!;
        ally.position = caster.position + const Offset(40, 0);
        // The orb falls; the phoenix catches it.
        game.orb.currentHp = 0;
        for (var i = 0; i < 10; i++) {
          ally.position = caster.position + const Offset(40, 0);
          game.update(1 / 60);
        }
        expect(caster.kinFireOrbitalFlameActive, isTrue);
        expect(game.isGameOver, isFalse);
        return ally.damageAmp;
      }

      expect(await risen(equipped: false), 1.0);
      expect(await risen(equipped: true), greaterThan(1.0));
    });

    /// How much of [element] Kin's special cooldown passes in two seconds,
    /// with its ally held at [allyHealth] of its health.
    Future<double> recharge(
      String element, {
      required int tier,
      required double allyHealth,
    }) async {
      final game = await pair(
        element,
        snapshot: tier == 0
            ? null
            : equip(KinNodes.benedictionPath, throughTier: tier),
      );
      final caster = game.activeCompanions[0]!;
      final ally = game.activeCompanions[1]!;
      caster.specialCooldown = 20;
      for (var i = 0; i < 120; i++) {
        ally.currentHp = (ally.maxHp * allyHealth).round();
        game.update(1 / 60);
      }
      return 20 - caster.specialCooldown;
    }

    test('Vigil: the support comes back twice as fast while an ally is hurt',
        () async {
      final calm = await recharge('Water', tier: 2, allyHealth: 0.9);
      final plain = await recharge('Water', tier: 1, allyHealth: 0.3);
      final vigil = await recharge('Water', tier: 2, allyHealth: 0.3);
      expect(calm, closeTo(2.0, 0.05));
      expect(plain, closeTo(2.0, 0.05));
      expect(vigil, closeTo(2.0 * KinTuning.vigilRate, 0.1));
    });

    test('Vigil for Kin+Fire: the reborn flame burns twice as often',
        () async {
      Future<int> flames({required int tier}) async {
        final game = await pair(
          'Fire',
          snapshot: equip(KinNodes.benedictionPath, throughTier: tier),
        );
        final caster = game.activeCompanions[0]!;
        final ally = game.activeCompanions[1]!;
        game.orb.currentHp = 0;
        game.update(1 / 60);
        expect(caster.kinFireOrbitalFlameActive, isTrue);
        var burns = 0;
        var last = caster.kinFireFlameTimer;
        for (var i = 0; i < 60 * 4; i++) {
          ally.currentHp = ally.maxHp ~/ 4;
          game.update(1 / 60);
          if (caster.kinFireFlameTimer > last) burns++;
          last = caster.kinFireFlameTimer;
        }
        return burns;
      }

      final plain = await flames(tier: 1);
      final vigil = await flames(tier: 2);
      expect(plain, greaterThan(0));
      expect(vigil / plain, closeTo(KinTuning.vigilRate, 0.3));
    });

    test('Unbroken keeps a downed Kin\'s support running', () async {
      final game = await arena(
        snapshot: equip(KinNodes.benedictionPath, throughTier: 3),
      );
      final comp = game.activeCompanions[0]!;
      comp.specialCooldown = 0;
      for (var i = 0; i < 60 * 12 && comp.kinDarkCloakTimer <= 0; i++) {
        game.update(1 / 60);
      }
      expect(comp.kinDarkCloakTimer, greaterThan(0));

      // Down the Kin; the cloak must keep ticking down rather than freezing
      // or being abandoned.
      comp.isDead = true;
      final before = comp.kinDarkCloakTimer;
      for (var i = 0; i < 60; i++) {
        game.update(1 / 60);
      }
      expect(
        comp.kinDarkCloakTimer,
        lessThan(before),
        reason: 'the support stopped running when the Kin went down',
      );
    });

    test('Communion: the ally beside the Kin keeps the whole blessing, the '
        'rest half', () async {
      final game = await arena(
        party: [
          kin('Water'),
          member('Mane', 'Fire', slotIndex: 1),
          member('Mane', 'Ice', slotIndex: 2),
        ],
        snapshot: equip(KinNodes.benedictionPath, throughTier: 4),
      );
      final caster = game.activeCompanions[0]!;
      final near = game.activeCompanions[1]!;
      final far = game.activeCompanions[2]!;
      for (final c in [near, far]) {
        c.specialCooldown = 99;
      }
      near.position = caster.position + const Offset(30, 0);
      far.position = caster.position + const Offset(600, 0);
      game.debugApplySpecialSupport(
        0,
        const CosmicSpecialResult(blessingTimer: 4, blessingHealPerTick: 40),
      );
      expect(near.blessingHealPerTick, closeTo(40, 0.01));
      expect(
        far.blessingHealPerTick,
        closeTo(40 * KinTuning.communionShare, 0.01),
      );
    });
  });
}
