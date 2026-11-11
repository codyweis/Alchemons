// ignore_for_file: invalid_use_of_visible_for_testing_member
// The five Specials (Base Command, SPECIALS): bought once for 100,000 silver,
// then in every run. Autopilot's flight is tested with the grains it fetches
// (survival_surge_grains_test.dart).
//
//   flutter test test/survival_specials_test.dart
import 'dart:convert';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:drift/native.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member() => CosmicPartyMember(
  instanceId: 'pip-0',
  baseId: 'PIP01',
  displayName: 'Pip',
  family: 'Pip',
  element: 'Fire',
  level: 10,
  slotIndex: 0,
  statSpeed: 3,
  statIntelligence: 3,
  statStrength: 3,
  statBeauty: 3,
  staminaBars: 3,
  staminaMax: 3,
);

/// A started run with nothing on the field, carrying [specials].
Future<CosmicSurvivalGame> _run([Set<SurvivalSpecial> specials = const {}]) =>
    _runFrom(specials: specials);

Future<CosmicSurvivalGame> _runFrom({
  Set<SurvivalSpecial> specials = const {},
  SuspendedSurvivalRun? resume,
}) async {
  final game = CosmicSurvivalGame(
    party: resume?.party ?? [_member()],
    onGameOver: () {},
    random: Random(5),
    upgradeState:
        resume?.upgradeState ??
        SurvivalUpgradeState(ownedSpecials: {...specials}),
    masterySnapshot: resume?.mastery,
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  if (resume != null) {
    game.resumeRun(resume);
  } else {
    game.startGame();
  }
  game.enemies.clear();
  return game;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buying', () {
    late AlchemonsDatabase db;

    setUp(() => db = AlchemonsDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    /// Leaves exactly [silver] in the purse.
    Future<void> purse(int silver) async {
      await db.currencyDao.spendSilver(await db.currencyDao.getSilverBalance());
      await db.currencyDao.addSilver(silver);
    }

    test('a Special is 100,000 silver, bought once and kept', () async {
      expect(kSurvivalSpecialCost, 100000);
      expect(kSurvivalSpecials.map((d) => d.special), SurvivalSpecial.values);
      expect(kSurvivalSpecials.every((d) => d.cost == 100000), isTrue);

      await purse(250000);
      final svc = SurvivalUpgradeService(db);
      await svc.load();
      expect(svc.state.ownedSpecials, isEmpty);

      expect(await svc.purchaseSpecial(SurvivalSpecial.shipSpeed), isTrue);
      expect(await db.currencyDao.getSilverBalance(), 150000);
      expect(svc.state.ownsSpecial(SurvivalSpecial.shipSpeed), isTrue);

      expect(
        await svc.purchaseSpecial(SurvivalSpecial.shipSpeed),
        isFalse,
        reason: 'already owned',
      );
      expect(await db.currencyDao.getSilverBalance(), 150000);

      // Kept: a fresh service reads it back, and only it.
      final again = SurvivalUpgradeService(db);
      await again.load();
      expect(again.state.ownedSpecials, {SurvivalSpecial.shipSpeed});
    });

    test('short of silver, nothing is bought or spent', () async {
      await purse(99999);
      final svc = SurvivalUpgradeService(db);
      await svc.load();
      expect(await svc.purchaseSpecial(SurvivalSpecial.shipShield), isFalse);
      expect(svc.state.ownedSpecials, isEmpty);
      expect(await db.currencyDao.getSilverBalance(), 99999);

      await db.currencyDao.addSilver(1);
      expect(await svc.purchaseSpecial(SurvivalSpecial.shipShield), isTrue);
      expect(await db.currencyDao.getSilverBalance(), 0);
    });
  });

  group('what a run reads', () {
    PowerUpDef card(String id) => kSurvivalPowerUpsById[id]!;

    test('with no Specials nothing is changed', () {
      final s = PowerUpState();
      expect(s.shipDamageMultiplier, 1.0);
      expect(s.fireRateMultiplier, 1.0);
      expect(s.shipSpeedMultiplier, 1.0);
      expect(s.hasAutopilot, isFalse);
      expect(s.hasShipShield, isFalse);
      expect(s.rerollsLeft, kSurvivalDraftRerolls);
      expect(s.banishesLeft, kSurvivalDraftBanishes);
    });

    test('Ship Overhaul is 5x damage and 5x fire rate, picks included', () {
      expect(kShipOverhaulDamage, 5.0);
      expect(kShipOverhaulFireRate, 5.0);
      final s = PowerUpState(specials: {SurvivalSpecial.shipOverhaul});
      expect(s.shipDamageMultiplier, 5.0);
      expect(s.fireRateMultiplier, 5.0);
      // The picks still count, and the five multiplies what they make.
      s.apply(card('fire_rate'));
      s.apply(card('ship_damage'));
      expect(s.fireRateMultiplier, closeTo((1 + 0.22) * 5, 1e-9));
      expect(s.shipDamageMultiplier, closeTo((1 + 0.18) * 5, 1e-9));
    });

    test('Ship Speed is a tripling, and nothing else changes with it', () {
      expect(kShipSpeedBoost, 3.0);
      final s = PowerUpState(specials: {SurvivalSpecial.shipSpeed});
      expect(s.shipSpeedMultiplier, 3.0);
      expect(s.shipDamageMultiplier, 1.0);
      expect(s.fireRateMultiplier, 1.0);
    });

    test('Autopilot is built in, so its card is never dealt', () {
      final plain = PowerUpState();
      final owned = PowerUpState(specials: {SurvivalSpecial.autopilot});
      expect(plain.canApply(card('autopilot')), isTrue);
      expect(owned.hasAutopilot, isTrue);
      expect(owned.canApply(card('autopilot')), isFalse);
      for (var wave = 1; wave <= 60; wave++) {
        final dealt = generatePowerUpChoices(owned, wave).map((c) => c.def.id);
        expect(dealt, isNot(contains('autopilot')), reason: 'wave $wave');
      }
      // The pick still works for a run without the Special.
      plain.apply(card('autopilot'));
      expect(plain.hasAutopilot, isTrue);
      expect(plain.canApply(card('autopilot')), isFalse);
    });

    test('Refresh & Banish is one more of each key, all of them usable', () {
      final s = PowerUpState(specials: {SurvivalSpecial.refreshBanish});
      expect(s.rerollsLeft, kSurvivalDraftRerolls + kRefreshBanishRerolls);
      expect(s.banishesLeft, kSurvivalDraftBanishes + kRefreshBanishBanishes);
      expect(kRefreshBanishRerolls, 1);
      expect(kRefreshBanishBanishes, 1);
      expect(s.draftRedraws, 0);

      // Through the draft itself, not just the counters.
      const wave = 5;
      var draft = generatePowerUpChoices(s, wave);
      for (var i = 0; i < kSurvivalDraftRerolls + 1; i++) {
        draft = rerollPowerUpDraft(s, wave, current: draft)!;
      }
      expect(s.rerollsLeft, 0);
      expect(rerollPowerUpDraft(s, wave, current: draft), isNull);
      for (var i = 0; i < kSurvivalDraftBanishes + 1; i++) {
        draft = banishFromPowerUpDraft(s, wave, current: draft, index: 0)!;
      }
      expect(s.banishesLeft, 0);
      expect(banishFromPowerUpDraft(s, wave, current: draft, index: 0), isNull);
      // Each use is one fresh draw, counted from the larger start.
      expect(
        s.draftRedraws,
        kSurvivalDraftRerolls +
            kRefreshBanishRerolls +
            kSurvivalDraftBanishes +
            kRefreshBanishBanishes,
      );
    });
  });

  group('Ship Speed and Ship Overhaul in a run', () {
    test('the ship flies three times as fast', () async {
      final plain = await _run();
      final fast = await _run({SurvivalSpecial.shipSpeed});
      expect(fast.ship.speed, closeTo(plain.ship.speed * 3, 1e-9));
    });

    test(
      'the gun fires five times as often and hits five times as hard',
      () async {
        final plain = await _run();
        final over = await _run({SurvivalSpecial.shipOverhaul});
        expect(
          over.debugShipFireInterval,
          closeTo(plain.debugShipFireInterval / 5, 1e-9),
        );
        const at = Offset(200, 0);
        plain.debugFireShipAt(at);
        over.debugFireShipAt(at);
        expect(
          over.shipProjectiles.first.damage,
          closeTo(plain.shipProjectiles.first.damage * 5, 1e-9),
        );
      },
    );

    test('five times the volleys get room in the air', () async {
      final plain = await _run();
      final over = await _run({SurvivalSpecial.shipOverhaul});
      for (var i = 0; i < 200; i++) {
        plain.debugFireShipAt(const Offset(200, 0));
        over.debugFireShipAt(const Offset(200, 0));
      }
      expect(plain.shipProjectiles, hasLength(40));
      expect(over.shipProjectiles.length, greaterThan(40));
    });
  });

  group('Ship Shield', () {
    test('a run without it takes every hit on the hull', () async {
      final g = await _run();
      final hull = g.debugShipPower.hull;
      g.debugDamageShip(hull * 0.4);
      expect(g.ship.currentHp, closeTo(hull * 0.6, 1e-6));
      expect(g.debugShipShield, 0);
      expect(g.shipShieldFraction, 0);
    });

    test(
      'it starts up, is as strong as the hull, and takes hits first',
      () async {
        final g = await _run({SurvivalSpecial.shipShield});
        final hull = g.debugShipPower.hull;
        expect(g.debugShipShield, 1.0);
        expect(g.shipShieldFraction, closeTo(kShipShieldHullShare, 1e-9));

        g.debugDamageShip(hull * 0.4);
        expect(g.ship.currentHp, closeTo(hull, 1e-6), reason: 'hull untouched');
        expect(g.debugShipShield, closeTo(0.6, 1e-9));
        expect(g.shipShieldFraction, closeTo(0.6 * kShipShieldHullShare, 1e-9));

        // A blow past what is left breaks it and the rest lands on the hull.
        g.debugDamageShip(hull * 0.7);
        expect(g.debugShipShield, 0);
        expect(g.ship.currentHp, closeTo(hull * 0.9, 1e-6));
        expect(g.ship.isDead, isFalse);
        expect(g.shipShieldSecondsLeft, kShipShieldRegenSeconds.round());
      },
    );

    test('broken, it is back whole after 30 seconds, not before', () async {
      expect(kShipShieldRegenSeconds, 30.0);
      final g = await _run({SurvivalSpecial.shipShield});
      final hull = g.debugShipPower.hull;
      g.debugDamageShip(hull);
      expect(g.debugShipShield, 0);
      expect(g.debugShipShieldRegen, 30.0);

      g.debugTickShipShield(29.9);
      expect(g.debugShipShield, 0);
      expect(g.shipShieldSecondsLeft, 1);
      // The hull is not healed by waiting.
      expect(g.ship.currentHp, closeTo(hull, 1e-6));

      g.debugTickShipShield(0.2);
      expect(g.debugShipShield, 1.0);
      expect(g.shipShieldSecondsLeft, 0);
      g.debugDamageShip(hull * 0.5);
      expect(g.debugShipShield, closeTo(0.5, 1e-9), reason: 'it is whole');
    });

    test('the game’s own clock runs it', () async {
      final g = await _run({SurvivalSpecial.shipShield});
      g.debugDamageShip(g.debugShipPower.hull);
      g.update(1 / 30);
      expect(g.debugShipShieldRegen, closeTo(30 - 1 / 30, 0.01));
    });

    test('a ship it let through still goes down', () async {
      final g = await _run({SurvivalSpecial.shipShield});
      final hull = g.debugShipPower.hull;
      g.debugDamageShip(hull * 2.5);
      expect(g.ship.isDead, isTrue);
      expect(g.shipShieldFraction, 0, reason: 'nothing to show on a ghost');
    });

    test('a kept run carries it, and what is left of it', () async {
      final g = await _run({
        SurvivalSpecial.shipShield,
        SurvivalSpecial.shipSpeed,
      });
      final hull = g.debugShipPower.hull;
      g.debugDamageShip(hull * 0.25);

      final run = g.captureSuspendedRun();
      expect(run.shipShield, closeTo(0.75, 1e-9));
      expect(run.specials, {
        SurvivalSpecial.shipShield,
        SurvivalSpecial.shipSpeed,
      });
      final back = SuspendedSurvivalRun.tryDecode(run.encode())!;
      expect(back, run);
      expect(back.shipShield, closeTo(0.75, 1e-9));
      expect(back.upgradeState.ownedSpecials, run.specials);

      final resumed = await _runFrom(resume: back);
      expect(resumed.debugShipShield, closeTo(0.75, 1e-9));
      expect(resumed.ship.speed, g.ship.speed);
      expect(resumed.powerUps.specials, run.specials);
    });

    test('a broken shield waits its full time again after leaving', () async {
      final g = await _run({SurvivalSpecial.shipShield});
      g.debugDamageShip(g.debugShipPower.hull);
      final back = SuspendedSurvivalRun.tryDecode(
        g.captureSuspendedRun().encode(),
      )!;
      final resumed = await _runFrom(resume: back);
      expect(resumed.debugShipShield, 0);
      expect(resumed.debugShipShieldRegen, kShipShieldRegenSeconds);
    });

    test('leaving never refills it', () async {
      final g = await _run({SurvivalSpecial.shipShield});
      final hull = g.debugShipPower.hull;
      final atWaveStart = g.captureSuspendedRun();
      g.debugDamageShip(hull * 0.5);
      final atExit = g.captureSuspendedRun();
      expect(atWaveStart.shipShield, 1.0);
      expect(atWaveStart.leftAt(atExit).shipShield, closeTo(0.5, 1e-9));
    });

    test(
      'a save from before it was kept reads as a full shield, no Specials',
      () async {
        final g = await _run();
        final json =
            jsonDecode(g.captureSuspendedRun().encode())
                as Map<String, dynamic>;
        (json['ship'] as Map<String, dynamic>).remove('shield');
        (json['upgrades'] as Map<String, dynamic>).remove('specials');
        final old = SuspendedSurvivalRun.fromJson(json);
        expect(old.shipShield, 1.0);
        expect(old.specials, isEmpty);
      },
    );
  });
}
