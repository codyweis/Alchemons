import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_ability_runtime.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' as space;
import 'package:alchemons/games/cosmic/horn_runtime.dart';
import 'package:alchemons/games/cosmic/mane_runtime.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_horn.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_kin.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_mystic.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_pip.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_wing.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// The second sweep of the 2026-10-20 family audit, each driven through the
/// real game: mastery nodes that did nothing or fired at the wrong moment,
/// element paths the design boards promise that never ran, zones a boss could
/// stand in untouched, a rebirth that froze other buffs open, and the open
/// space copy of survival's Light Wing fixes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const baseIds = {
    'Horn': 'HRN01',
    'Mane': 'MAN01',
    'Wing': 'WNG01',
    'Kin': 'KIN01',
    'Pip': 'PIP01',
    'Mystic': 'MYW01',
  };

  CosmicPartyMember member(String family, String element, {int slot = 0}) =>
      CosmicPartyMember(
        instanceId: '${family.toLowerCase()}-$slot',
        baseId: baseIds[family] ?? 'HRN01',
        displayName: '$family $element',
        family: family,
        element: element,
        level: 10,
        slotIndex: slot,
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

  SurvivalFamilyMasterySnapshot equip(
    CreatureFamily family,
    String pathId, {
    int throughTier = 4,
  }) {
    final path = FamilyMasteryCatalog.pathFor(family, pathId)!;
    return SurvivalFamilyMasterySnapshot({
      0: EquippedFamilyMastery(
        instanceId: '${family.name}-0',
        family: family,
        pathId: path.id,
        activeNodeIds: path.nodes
            .where((n) => n.tier <= throughTier)
            .map((n) => n.id),
      ),
    });
  }

  /// A cleared arena: the party is out, the opening wave is dead, the ship is
  /// parked far away with its guns held, and nothing holds the orb's shield.
  Future<CosmicSurvivalGame> arena(
    List<CosmicPartyMember> party, {
    SurvivalFamilyMasterySnapshot? snapshot,
  }) async {
    final game = CosmicSurvivalGame(
      party: party,
      onGameOver: () {},
      masterySnapshot: snapshot,
      random: Random(5),
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    for (var i = 1; i < party.length; i++) {
      game.applyPowerUp(kAllPowerUps.firstWhere((d) => d.id == 'pack_leader'));
    }
    game.startGame();
    for (var i = 0; i < party.length; i++) {
      game.summonCompanion(i);
    }
    for (
      var i = 0;
      i < 600 && game.enemies.where((e) => !e.isDead).isEmpty;
      i++
    ) {
      game.update(1 / 60);
    }
    for (final e in game.enemies) {
      e.isDead = true;
    }
    game.orb.shieldHp = 0;
    game.ship.position = game.orb.position + const Offset(0, 900);
    game.ship.fireTimer = -1e9;
    return game;
  }

  CosmicSurvivalEnemy body(
    CosmicSurvivalGame game,
    Offset at, {
    double hp = 1e6,
  }) {
    final e = CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed: 0,
      damage: 0,
      radius: 11,
      tier: EnemyTier.drone,
      element: 'Ice',
      target: CosmicEnemyTarget.orb,
      conduct: EnemyConduct.stalk,
    );
    game.enemies.add(e);
    return e;
  }

  /// A boss standing still with its shield down, so what it loses is exactly
  /// what the kit under test dealt it.
  SurvivalBoss boss(CosmicSurvivalGame game, Offset at) {
    final b = game.spawner.createBossForWave(5, at)!;
    b
      ..position = at
      ..spawnIntroTimer = 0
      ..spawnFromPosition = null
      ..spawnTargetPosition = null
      ..chillTimer = 1e9
      ..chillMultiplier = 0
      ..shieldUp = false
      ..shieldTimer = 1e9;
    game.activeBoss = b;
    return b;
  }

  /// Frames with the party's own casts held (and its attacks, unless
  /// [holdBasics] is off), the orb kept standing, and anything the spawner
  /// sends in put down at once.
  void run(
    CosmicSurvivalGame game,
    int frames, {
    Set<CosmicSurvivalEnemy> keep = const {},
    SurvivalBoss? still,
    bool holdBasics = true,
    void Function()? pin,
  }) {
    for (var f = 0; f < frames; f++) {
      for (final comp in game.activeCompanions.values) {
        comp.specialCooldown = 99999;
        if (holdBasics) comp.basicCooldown = 99999;
      }
      for (final e in game.enemies) {
        if (!keep.contains(e)) e.isDead = true;
      }
      if (still != null) {
        still
          ..shieldUp = false
          ..shieldTimer = 1e9;
      }
      game.orb.currentHp = game.orb.maxHp;
      pin?.call();
      game.update(1 / 60);
    }
  }

  /// Frames in which a companion is free to cast whenever its own cooldown
  /// allows, with [lure] kept alive where it is so it has something to cast
  /// at. [each] runs after every frame.
  void castFreely(
    CosmicSurvivalGame game,
    int frames, {
    required CosmicSurvivalEnemy lure,
    required void Function() pin,
    void Function(int frame)? each,
  }) {
    final at = lure.position;
    for (var f = 0; f < frames; f++) {
      for (final comp in game.activeCompanions.values) {
        comp.basicCooldown = 99999;
      }
      for (final e in game.enemies) {
        if (!identical(e, lure)) e.isDead = true;
      }
      lure
        ..isDead = false
        ..hp = 1e9
        ..position = at;
      game.orb.currentHp = game.orb.maxHp;
      pin();
      game.update(1 / 60);
      each?.call(f);
    }
  }

  group('mastery nodes', () {
    test('Kin Grounding lands the element on every body down the line', () async {
      Future<List<CosmicSurvivalEnemy>> fire({required int throughTier}) async {
        final game = await arena(
          [member('Kin', 'Fire')],
          snapshot: equip(
            CreatureFamily.kin,
            KinNodes.conductionPath,
            throughTier: throughTier,
          ),
        );
        final comp = game.activeCompanions[0]!;
        final at = comp.position;
        final line = [
          for (var i = 0; i < 3; i++) body(game, at + Offset(90.0 + i * 25, 0)),
        ];
        comp.basicCooldown = 0;
        for (var f = 0; f < 60 * 4; f++) {
          run(
            game,
            1,
            keep: line.toSet(),
            holdBasics: false,
            pin: () => comp.position = at,
          );
          if (line.every((e) => e.hp < e.maxHp)) break;
        }
        expect(
          line.every((e) => e.hp < e.maxHp),
          isTrue,
          reason: 'the laser never ran down the line',
        );
        return line;
      }

      final plain = await fire(throughTier: 2);
      expect(plain.any((e) => e.masteryDotTimer > 0), isFalse);
      final grounded = await fire(throughTier: 3);
      expect(
        grounded.every((e) => e.masteryDotTimer > 0),
        isTrue,
        reason: 'a body down the line was left without the element',
      );
    });

    test('Kin Conduction tops a shield up to a ceiling, never stacks it', () async {
      final game = await arena(
        [member('Kin', 'Water'), member('Horn', 'Earth', slot: 1)],
        snapshot: equip(
          CreatureFamily.kin,
          KinNodes.conductionPath,
          throughTier: 1,
        ),
      );
      final kin = game.activeCompanions[0]!;
      final ally = game.activeCompanions[1]!;
      final at = kin.position;
      final target = body(game, at + const Offset(160, 0));
      ally.shieldHp = 0;
      kin.basicCooldown = 0;
      run(
        game,
        60 * 20,
        keep: {target},
        holdBasics: false,
        pin: () {
          kin.position = at;
          ally
            ..position = at + const Offset(70, 0)
            ..currentHp = ally.maxHp
            ..basicCooldown = 99999;
        },
      );
      final ceiling = kinConductionShieldCeiling(
        hasNode: (id) => id == KinNodes.liveCurrent,
        allyMaxHp: ally.maxHp.toDouble(),
      ).round();
      final granted = game.kinMasteryFor(0)!.shieldGranted;
      expect(granted, greaterThan(0), reason: 'the line never crossed the ally');
      expect(ally.shieldHp, greaterThan(0));
      expect(
        ally.shieldHp,
        lessThanOrEqualTo(ceiling),
        reason: 'shield stacked past the ceiling',
      );
    });

    test('Mystic Sanctum lends the world\'s element to an ally\'s attack', () async {
      Future<CosmicSurvivalEnemy> strike({required int throughTier}) async {
        final game = await arena(
          [member('Mystic', 'Fire'), member('Horn', 'Earth', slot: 1)],
          snapshot: equip(
            CreatureFamily.mystic,
            MysticNodes.firmamentPath,
            throughTier: throughTier,
          ),
        );
        final mystic = game.activeCompanions[0]!;
        final ally = game.activeCompanions[1]!;
        final at = mystic.position;
        final lure = body(game, at + const Offset(70, 0));
        mystic.specialCooldown = 0;
        for (var f = 0; f < 1200 && !game.isMysticFieldSpent(0); f++) {
          lure
            ..isDead = false
            ..hp = 1e9
            ..position = at + const Offset(70, 0);
          game.orb.currentHp = game.orb.maxHp;
          game.update(1 / 60);
        }
        expect(game.isMysticFieldSpent(0), isTrue, reason: 'no world lit');
        ally.position = mystic.position + const Offset(40, 0);
        final struck = body(game, ally.position + const Offset(200, 0));
        game.debugAutoAttackDamage(struck, 1, sourceSlotIndex: 1);
        return struck;
      }

      expect((await strike(throughTier: 3)).masteryDotTimer, 0);
      expect(
        (await strike(throughTier: 4)).masteryDotTimer,
        greaterThan(0),
        reason: 'the attack carried nothing of the Fire world',
      );
    });

    test('Pip Pin Cushion adds 3% a Pin to the darts that land on it', () async {
      final game = await arena(
        [member('Pip', 'Earth')],
        snapshot: equip(
          CreatureFamily.pip,
          PipNodes.needlepointPath,
          throughTier: 2,
        ),
      );
      final pip = game.activeCompanions[0]!;
      final at = pip.position;
      final pinned = body(game, at + const Offset(120, 0));
      final pinnedId = identityHashCode(pinned);
      for (var f = 0; f < 60 * 12; f++) {
        run(
          game,
          1,
          keep: {pinned},
          holdBasics: false,
          pin: () => pip.position = at,
        );
        if ((game.pipMasteryFor(0)?.pinsOn(pinnedId) ?? 0) >= 2) break;
      }
      final pins = game.pipMasteryFor(0)?.pinsOn(pinnedId) ?? 0;
      expect(pins, greaterThan(0), reason: 'no volley landed whole');
      final fresh = body(game, at + const Offset(-400, 0));
      final pinnedBefore = pinned.hp;
      final freshBefore = fresh.hp;
      game.debugAutoAttackDamage(pinned, 100, sourceSlotIndex: 0);
      game.debugAutoAttackDamage(fresh, 100, sourceSlotIndex: 0);
      expect(
        (pinnedBefore - pinned.hp) / (freshBefore - fresh.hp),
        closeTo(1 + PipTuning.pinDamagePerStack * pins, 1e-6),
      );
    });

    test('Pip Salvo loads a Dark Pip\'s black hole, once a special', () async {
      Future<List<Projectile>> darts({int throughTier = 0}) async {
        final game = await arena(
          [member('Pip', 'Dark')],
          snapshot: throughTier == 0
              ? null
              : equip(
                  CreatureFamily.pip,
                  PipNodes.salvoPath,
                  throughTier: throughTier,
                ),
        );
        final pip = game.activeCompanions[0]!;
        // Three auto kills in a row: three holes, but one special's salvo.
        for (var i = 0; i < 3; i++) {
          final victim = body(
            game,
            pip.position + Offset(200.0 + i * 40, 0),
            hp: 1,
          );
          game.debugKillByDart(0, victim);
        }
        final holes = game.companionProjectiles
            .where((p) => p.element == 'Dark' && p.stationary)
            .length;
        expect(holes, 3, reason: 'each auto kill opens its hole');
        return game.companionProjectiles
            .where(
              (p) =>
                  p.abilityFamily == 'pip' &&
                  p.element == 'Dark' &&
                  p.visualStyle == ProjectileVisualStyle.dart,
            )
            .toList();
      }

      expect(await darts(), isEmpty);
      expect(await darts(throughTier: 2), hasLength(2));
      final perfect = await darts(throughTier: 4);
      expect(perfect, hasLength(4));
      for (final dart in perfect) {
        expect(dart.damage, greaterThan(0));
        expect(dart.masteryGenerated, isTrue);
      }
    });

    test('Horn Juggernaut runs a Light Horn\'s barrier again, weaker', () async {
      // Light has no ram, so no second run was ever owed and the whole path
      // did nothing for it. The second barrier stands 0.45 s after the first
      // falls, for 45% of the time, and its shield is 45% of the first.
      final game = await arena(
        [member('Horn', 'Light')],
        snapshot: equip(
          CreatureFamily.horn,
          HornNodes.juggernautPath,
          throughTier: 1,
        ),
      );
      final horn = game.activeCompanions[0]!;
      final at = horn.position;
      final lure = body(game, at + const Offset(150, 0));
      final born = <Projectile, int>{};
      final lifeAtBirth = <Projectile, double>{};
      final shieldAtBirth = <Projectile, int>{};
      final died = <Projectile, int>{};
      horn
        ..specialCooldown = 0
        ..shieldHp = 0;
      castFreely(
        game,
        60 * 20,
        lure: lure,
        pin: () => horn.position = at,
        each: (f) {
          final live = game.companionProjectiles
              .where(isHornLightBarrier)
              .toSet();
          for (final p in live) {
            if (born.containsKey(p)) continue;
            born[p] = f;
            lifeAtBirth[p] = p.life;
            shieldAtBirth[p] = horn.shieldHp;
            horn.shieldHp = 0;
          }
          for (final p in born.keys) {
            if (!live.contains(p)) died.putIfAbsent(p, () => f);
          }
        },
      );
      final order = born.keys.toList()
        ..sort((a, b) => born[a]!.compareTo(born[b]!));
      expect(order.length, greaterThanOrEqualTo(2));
      final first = order[0];
      final second = order[1];
      expect(
        born[second]! - died[first]!,
        lessThan(60),
        reason: 'the second barrier waited for the ordinary cooldown',
      );
      expect(
        lifeAtBirth[second]! / lifeAtBirth[first]!,
        closeTo(HornTuning.secondRunPower, 0.03),
      );
      expect(
        shieldAtBirth[second]! / shieldAtBirth[first]!,
        closeTo(HornTuning.secondRunPower, 0.02),
      );
    });

    for (final (tier, expected, strength) in [
      (1, HornTuning.secondRunPower, 'the run\'s'),
      (2, 1.0, 'full, with Full Weight'),
    ]) {
      test(
        'a Juggernaut second run leaves its burst at $strength strength',
        () async {
          // The ram was scaled and the zone it drops was not, so the second
          // run's element came out at full strength without Full Weight.
          final game = await arena(
            [member('Horn', 'Earth')],
            snapshot: equip(
              CreatureFamily.horn,
              HornNodes.juggernautPath,
              throughTier: tier,
            ),
          );
          final horn = game.activeCompanions[0]!;
          final lure = body(game, horn.position + const Offset(150, 0));
          final bursts = <List<Projectile>>[];
          final powers = <double>[];
          horn.specialCooldown = 0;
          castFreely(
            game,
            60 * 14,
            lure: lure,
            pin: () {},
            each: (_) {
              final pending = horn.pendingChargeBurst;
              if (pending == null || pending.isEmpty) return;
              if (bursts.any((b) => identical(b, pending))) return;
              bursts.add(pending);
              powers.add(pending.first.effectPower);
            },
          );
          expect(bursts.length, greaterThanOrEqualTo(2));
          expect(powers[0], greaterThan(0));
          expect(powers[1] / powers[0], closeTo(expected, 0.01));
        },
      );
    }

    test('Wing Tracer pays when a shot lands, not when it is fired', () async {
      final game = await arena(
        [member('Wing', 'Earth')],
        snapshot: equip(CreatureFamily.wing, WingNodes.tracerPath, throughTier: 1),
      );
      final wing = game.activeCompanions[0]!;
      final at = wing.position;
      final target = body(game, at + const Offset(220, 0));
      wing
        ..specialCooldown = 30
        ..basicCooldown = 0;
      var firedAt = -1;
      var shavedAt = -1;
      for (var f = 0; f < 120 && shavedAt < 0; f++) {
        for (final e in game.enemies) {
          if (!identical(e, target)) e.isDead = true;
        }
        wing.position = at;
        game.orb.currentHp = game.orb.maxHp;
        final cooldownBefore = wing.specialCooldown;
        final basicBefore = wing.basicCooldown;
        game.update(1 / 60);
        final shaved = cooldownBefore - wing.specialCooldown > 0.2;
        if (firedAt < 0 && basicBefore <= 0 && wing.basicCooldown > 0) {
          firedAt = f;
          expect(shaved, isFalse, reason: 'paid as the shot left');
        } else if (shaved) {
          shavedAt = f;
          expect(target.hp, lessThan(target.maxHp));
        }
        if (firedAt >= 0) wing.basicCooldown = 99999;
      }
      expect(firedAt, greaterThanOrEqualTo(0), reason: 'the Wing never fired');
      expect(shavedAt, greaterThan(firedAt), reason: 'the landing paid nothing');
    });
  });

  group('design paths', () {
    test('a Water Wing heals the ally its beam is on', () async {
      final game = await arena([
        member('Wing', 'Water'),
        member('Horn', 'Earth', slot: 1),
      ]);
      final wing = game.activeCompanions[0]!;
      final ally = game.activeCompanions[1]!;
      final at = wing.position;
      ally.currentHp = ally.maxHp ~/ 2;
      final before = ally.currentHp;
      game.debugCastWingBeam(
        0,
        const WingBeamEffect(
          element: 'Water',
          targetPolicy: WingBeamTargetPolicy.lowestHealthAllyOrShip,
          duration: 2,
          tickInterval: 0.2,
          damagePerTick: 1,
          healPerTick: 5,
          range: 600,
        ),
      );
      run(
        game,
        60,
        pin: () {
          wing.position = at;
          ally.position = at + const Offset(120, 0);
        },
      );
      final perTick = ally.maxHp * WingBeamRules.waterHealShare(4.25);
      expect(
        ally.currentHp - before,
        greaterThanOrEqualTo((perTick * 3).floor()),
        reason: 'the ally the beam was on was not healed',
      );
    });

    test('a Plant Wing\'s shot lays no trail', () async {
      final game = await arena([member('Wing', 'Plant')]);
      final wing = game.activeCompanions[0]!;
      final at = wing.position;
      final lure = body(game, at + const Offset(180, 0));
      var cast = false;
      var puffs = 0;
      wing.specialCooldown = 0;
      castFreely(
        game,
        180,
        lure: lure,
        pin: () => wing.position = at,
        each: (_) {
          if (wing.specialCooldown > 0) cast = true;
          puffs = max(
            puffs,
            game.companionProjectiles
                .where(
                  (p) =>
                      p.abilityFamily == 'wing' &&
                      p.element == 'Plant' &&
                      p.stationary,
                )
                .length,
          );
        },
      );
      expect(cast, isTrue, reason: 'the Wing never cast');
      expect(puffs, 0);
    });

    group('the Mane Light ward', () {
      Future<(CosmicSurvivalGame, void Function(int))> ward() async {
        final game = await arena([member('Mane', 'Light')]);
        final mane = game.activeCompanions[0]!;
        final at = mane.position;
        final lure = body(game, at + const Offset(70, 0));
        void cast(int casts) {
          for (var i = 0; i < casts; i++) {
            mane.specialCooldown = 0;
            var fired = false;
            for (var f = 0; f < 600 && !fired; f++) {
              lure
                ..isDead = false
                ..hp = 1e9
                ..position = at + const Offset(70, 0);
              for (final e in game.enemies) {
                if (!identical(e, lure)) e.isDead = true;
              }
              mane
                ..position = at
                ..basicCooldown = 99999;
              game.orb.currentHp = game.orb.maxHp;
              game.update(1 / 60);
              fired = mane.specialCooldown > 0;
            }
            expect(fired, isTrue, reason: 'cast ${i + 1} never went off');
          }
        }

        return (game, cast);
      }

      List<Projectile> rings(CosmicSurvivalGame game) =>
          game.companionProjectiles
              .where(
                (p) =>
                    p.abilityFamily == 'mane' &&
                    p.element == 'Light' &&
                    p.holdOrbit &&
                    p.life > 0,
              )
              .toList()
            ..sort((a, b) => b.orbitRadius.compareTo(a.orbitRadius));

      test('a ring hung after the outer one expired takes the outer orbit', () async {
        final (game, cast) = await ward();
        cast(3);
        rings(game).first.life = 0;
        game.update(1 / 60);
        expect(rings(game), hasLength(2));
        cast(1);
        expect(
          rings(game).map((r) => r.orbitRadius).toList(),
          kManeLightOrbitRadii.take(3).toList(),
        );
      });

      test('a ward rebuilt after its rings expire is fed again', () async {
        final (game, cast) = await ward();
        cast(3 + kManeLightMaxGrowth);
        expect(ManeLightWard.fedLevels(rings(game)), kManeLightMaxGrowth);
        for (final ring in rings(game)) {
          ring.life = 0;
        }
        game.update(1 / 60);
        expect(rings(game), isEmpty);
        cast(4);
        final rebuilt = rings(game);
        expect(rebuilt, hasLength(3));
        expect(
          ManeLightWard.fedLevels(rebuilt),
          1,
          reason: 'the fourth cast of the new ward fed nothing',
        );
      });

      test('a ring strikes a boss more than once in its life', () async {
        final (game, cast) = await ward();
        cast(1);
        final mane = game.activeCompanions[0]!;
        final at = mane.position;
        final ring = rings(game).single;
        final b = boss(game, at + Offset(ring.orbitRadius, 0));
        var hits = 0;
        var last = b.hp;
        for (var f = 0; f < 60 * 8; f++) {
          run(
            game,
            1,
            still: b,
            pin: () => mane
              ..position = at
              ..currentHp = mane.maxHp,
          );
          if (b.hp < last) hits++;
          last = b.hp;
        }
        expect(hits, greaterThanOrEqualTo(3));
      });
    });

    test('Kin Light escorts pass through bodies instead of dying on one', () async {
      final game = await arena([member('Kin', 'Light')]);
      final kin = game.activeCompanions[0]!;
      final at = kin.position;
      final lure = body(game, at + const Offset(150, 0));
      kin.specialCooldown = 0;
      var cast = false;
      castFreely(
        game,
        240,
        lure: lure,
        pin: () => kin.position = at,
        each: (_) {
          if (!cast && kin.specialCooldown > 0) {
            cast = true;
            kin.specialCooldown = 99999;
          }
        },
      );
      expect(cast, isTrue, reason: 'the Kin never cast');
      List<Projectile> escorts() => game.companionProjectiles
          .where(
            (p) =>
                p.abilityFamily == 'kin' &&
                p.element == 'Light' &&
                p.holdOrbit &&
                p.life > 0,
          )
          .toList();
      final count = escorts().length;
      expect(count, greaterThan(0));
      final orbDamage = escorts().first.damage;
      // A crowd standing wherever the escorts are.
      final crowd = <CosmicSurvivalEnemy>{};
      for (final orb in escorts()) {
        for (var i = 0; i < 3; i++) {
          crowd.add(body(game, orb.position + Offset(i * 6.0, 0)));
        }
      }
      run(game, 60, keep: {...crowd, lure}, pin: () => kin.position = at);
      expect(escorts(), hasLength(count), reason: 'an escort was spent on a body');
      expect(crowd.where((e) => e.hp < e.maxHp).length, greaterThan(count));
      for (final e in crowd) {
        expect(
          e.maxHp - e.hp,
          lessThan(count * orbDamage * 3),
          reason: 'a body was billed on every contact tick',
        );
      }
    });

    for (final (name, build) in <(String, Projectile Function(Offset))>[
      (
        'a Pip Fire pool',
        (at) => Projectile(
          position: at,
          angle: 0,
          element: 'Fire',
          damage: 0,
          life: 6,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          abilityFamily: 'pip',
          sourceSlotIndex: 0,
          tickEffect: AbilityEffectKind.burn,
          effectPower: 60,
          effectRadius: 60,
          effectDuration: 6,
        ),
      ),
      (
        'a Wing Lava scar',
        (at) => WingBeamRules.lavaScar(
          const WingBeamEffect(
            element: 'Lava',
            targetPolicy: WingBeamTargetPolicy.nearestEnemy,
            duration: 2,
            tickInterval: 0.2,
            damagePerTick: 120,
          ),
          at,
          beauty: 4.25,
          intelligence: 4.25,
          sourceSlotIndex: 0,
        ),
      ),
      (
        'a Wing Steam cloud',
        (at) =>
            copyProjectile(
              WingBeamRules.steamClouds(
                const WingBeamEffect(
                  element: 'Steam',
                  targetPolicy: WingBeamTargetPolicy.nearestEnemy,
                  duration: 2,
                  tickInterval: 0.2,
                  damagePerTick: 120,
                ),
                at,
                Random(3),
                beauty: 4.25,
                intelligence: 4.25,
                sourceSlotIndex: 0,
              ).first,
              position: at,
            ),
      ),
      (
        'a Let Lava field',
        (at) => CosmicAbilityRuntime.letZone(
          Projectile(
            position: at,
            angle: 0,
            element: 'Lava',
            damage: 200,
            effectPower: 120,
            abilityFamily: 'let',
            sourceSlotIndex: 0,
          ),
          at,
          'Lava',
          CosmicAbilityRuntime.letContactZone('Lava')!,
        ),
      ),
      (
        'a Kin poison piece',
        (at) => Projectile(
          position: at,
          angle: 0,
          element: 'Poison',
          damage: 0,
          life: 6,
          speedMultiplier: 0,
          stationary: true,
          piercing: true,
          abilityFamily: 'kin',
          sourceSlotIndex: 0,
          tickEffect: AbilityEffectKind.poison,
          effectPower: 60,
          effectRadius: 80,
          effectDuration: 6,
        ),
      ),
    ]) {
      test('$name ticks a boss standing in it', () async {
        final game = await arena([member('Horn', 'Plant')]);
        final b = boss(game, game.orb.position + const Offset(300, 0));
        game.companionProjectiles.add(build(b.position));
        run(game, 60, still: b);
        expect(b.hp, lessThan(b.maxHp), reason: '$name left the boss alone');
      });
    }

    test('a zone with no power, or one that only throws out, spares a boss', () async {
      final game = await arena([member('Horn', 'Plant')]);
      final b = boss(game, game.orb.position + const Offset(300, 0));
      game.companionProjectiles
        ..add(
          Projectile(
            position: b.position,
            angle: 0,
            element: 'Fire',
            damage: 0,
            life: 6,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            abilityFamily: 'pip',
            sourceSlotIndex: 0,
            tickEffect: AbilityEffectKind.burn,
            effectRadius: 80,
          ),
        )
        ..add(
          Projectile(
            position: b.position,
            angle: 0,
            element: 'Dark',
            damage: 0,
            life: 6,
            speedMultiplier: 0,
            stationary: true,
            piercing: true,
            voidEjectOnly: true,
            abilityFamily: 'kin',
            sourceSlotIndex: 0,
            tickEffect: AbilityEffectKind.blackHole,
            effectPower: 60,
            effectRadius: 120,
          ),
        );
      run(game, 60, still: b);
      expect(b.hp, b.maxHp);
    });

    test('a reborn Fire Kin no longer freezes another source\'s buff open', () async {
      final game = await arena([member('Kin', 'Fire')]);
      final comp = game.activeCompanions[0]!;
      game.orb.currentHp = 0;
      game.update(1 / 60);
      expect(comp.kinFireOrbitalFlameActive, isTrue);
      // Mask Ice's pillar, the strongest temporary amp in the game.
      comp
        ..damageAmpTimer = 0.5
        ..damageAmpMultiplier = 2.4
        ..basicHasteTimer = 0.5
        ..basicHasteMultiplier = 0.3;
      expect(comp.damageAmp, closeTo(2.4, 1e-9));
      run(game, 120);
      expect(
        comp.damageAmp,
        closeTo(comp.kinFireRebirthDamageAmp, 1e-9),
        reason: 'the 2.4x amp outlived its window',
      );
      expect(comp.basicHaste, closeTo(comp.kinFireRebirthHaste, 1e-9));
    });

    test('a heavier shooter fires sooner and its rounds fly faster', () async {
      final game = await arena([member('Horn', 'Plant')]);
      final bySize = [...EnemyTier.values]
        ..sort((x, y) => tierBaseHp(x).compareTo(tierBaseHp(y)));
      for (var i = 1; i < bySize.length; i++) {
        expect(
          game.debugShooterCadence(bySize[i]),
          lessThan(game.debugShooterCadence(bySize[i - 1])),
          reason: '${bySize[i]} fires no sooner than ${bySize[i - 1]}',
        );
        expect(
          game.debugShooterRoundSpeed(bySize[i]),
          greaterThan(game.debugShooterRoundSpeed(bySize[i - 1])),
        );
      }
    });
  });

  group('open space Wing parity', () {
    const dt = 1 / 60;

    Future<space.CosmicGame> deepSpace() async {
      final game = space.CosmicGame(
        world_: CosmicWorld.generate(seed: 37),
        onMeterChanged: () {},
      );
      game.ship = space.ShipComponent(pos: Offset.zero);
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      final world = game.world_;
      var home = Offset.zero;
      var best = -1.0;
      for (var gx = 1; gx < 20; gx++) {
        for (var gy = 1; gy < 20; gy++) {
          final p = Offset(
            world.worldSize.width * gx / 20,
            world.worldSize.height * gy / 20,
          );
          var nearest = double.infinity;
          for (final planet in world.planets) {
            nearest = min(nearest, (planet.position - p).distance);
          }
          if (nearest > best) {
            best = nearest;
            home = p;
          }
        }
      }
      game.teleportTo(home);
      game.enemies.clear();
      game.activeBoss = null;
      return game;
    }

    CosmicCompanion summon(
      space.CosmicGame game,
      String element, {
      int slot = 0,
    }) {
      game.summonCompanion(
        CosmicPartyMember(
          instanceId: 'wing-$element-$slot',
          baseId: 'WNG01',
          displayName: '$element Wing',
          family: 'Wing',
          element: element,
          level: 10,
          slotIndex: slot,
          statSpeed: 3,
          statIntelligence: 3,
          statStrength: 3,
          statBeauty: 3,
          staminaBars: 5,
          staminaMax: 5,
        ),
        slotIndex: slot,
      );
      final c = game.activeCompanions[slot]!;
      c
        ..invincibleTimer = 0
        ..basicCooldown = 100
        ..specialCooldown = 100;
      return c;
    }

    CosmicEnemy enemy(
      space.CosmicGame game,
      Offset at, {
      double health = 1e5,
    }) {
      final e = CosmicEnemy(
        position: at,
        element: 'Fire',
        tier: EnemyTier.drone,
        radius: 10,
        health: health,
        speed: 0,
      );
      game.enemies.add(e);
      return e;
    }

    void step(
      space.CosmicGame game,
      Map<CosmicEnemy, Offset> keep,
      List<(CosmicCompanion, Offset)> hold,
    ) {
      game.enemies.removeWhere((e) => !keep.containsKey(e));
      game.update(dt);
      for (final entry in keep.entries) {
        if (!entry.key.dead) entry.key.position = entry.value;
      }
      for (final (c, at) in hold) {
        c.position = at;
      }
    }

    const lightBeam = WingBeamEffect(
      element: 'Light',
      targetPolicy: WingBeamTargetPolicy.nearestEnemy,
      duration: 4,
      tickInterval: 0.1,
      damagePerTick: 40,
      range: 520,
    );

    test('Light refractions hunt bodies of their own', () async {
      final game = await deepSpace();
      final comp = summon(game, 'Light');
      final at = comp.position;
      final prey = enemy(game, at + const Offset(110, 0), health: 0.5);
      final keep = {
        prey: prey.position,
        for (final o in const [Offset(150, 40), Offset(170, -60), Offset(200, 90)])
          enemy(game, at + o): at + o,
      };
      game.debugCastWingBeam(comp, lightBeam);
      for (var f = 0; f < 20; f++) {
        step(game, keep, [(comp, at)]);
      }
      expect(prey.dead, isTrue);
      final beams = game.debugWingBeams()
        ..sort((x, y) => y.damagePerTick.compareTo(x.damagePerTick));
      expect(beams.length, greaterThan(1), reason: 'the kill never split');
      final parentEnd = beams.first.end!;
      final childEnds = [for (final c in beams.skip(1)) c.end!];
      for (final end in childEnds) {
        expect(
          (end - parentEnd).distance,
          greaterThan(20),
          reason: 'a split beam is sitting on the parent\'s target',
        );
      }
      expect(
        (childEnds.first - childEnds.last).distance,
        greaterThan(20),
        reason: 'the split beams share one target',
      );
    });

    test('a full beam pool gives up the caster\'s own beams', () async {
      final game = await deepSpace();
      final light = summon(game, 'Light');
      final mud = summon(game, 'Mud', slot: 1);
      final target = enemy(game, light.position + const Offset(150, 0));
      final keep = {target: target.position};
      game.debugCastWingBeam(
        mud,
        const WingBeamEffect(
          element: 'Mud',
          targetPolicy: WingBeamTargetPolicy.nearestEnemy,
          duration: 8,
          tickInterval: 0.25,
          damagePerTick: 1,
          range: 900,
        ),
      );
      for (var i = 0; i < WingBeamRules.beamCap + 1; i++) {
        game.debugCastWingBeam(
          light,
          const WingBeamEffect(
            element: 'Light',
            targetPolicy: WingBeamTargetPolicy.nearestEnemy,
            duration: 4,
            tickInterval: 0.25,
            damagePerTick: 1,
            range: 900,
          ),
        );
        step(game, keep, const []);
      }
      final beams = game.debugWingBeams();
      expect(
        beams.where((b) => identical(b.caster, mud)).length,
        1,
        reason: 'the other Wing lost its beam',
      );
      expect(beams.length, lessThanOrEqualTo(WingBeamRules.beamCap));
    });
  });
}
