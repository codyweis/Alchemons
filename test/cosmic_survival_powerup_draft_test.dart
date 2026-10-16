import 'dart:convert';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/game_controller_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamepads/gamepads.dart';

CosmicPartyMember _member({
  required String family,
  required double speed,
  required double intelligence,
  required double strength,
  required double beauty,
  int slotIndex = 0,
  String element = 'Fire',
}) {
  return CosmicPartyMember(
    instanceId: 'test_${family}_$slotIndex',
    baseId: 'base_$family',
    displayName: family,
    element: element,
    family: family,
    level: 10,
    statSpeed: speed,
    statIntelligence: intelligence,
    statStrength: strength,
    statBeauty: beauty,
    slotIndex: slotIndex,
    staminaBars: 3,
    staminaMax: 3,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('cosmic survival draft weighting', () {
    test('speed-focused pip values tempo upgrades over horn', () {
      final pip = _member(
        family: 'pip',
        speed: 4.1,
        intelligence: 3.2,
        strength: 3.8,
        beauty: 2.8,
      );
      final horn = _member(
        family: 'horn',
        speed: 2.4,
        intelligence: 3.0,
        strength: 4.0,
        beauty: 2.4,
      );
      final tempoDef = kCompanionStatBoosts.firstWhere(
        (def) => def.id == 'speed_up',
      );

      expect(
        powerUpDraftWeightForMember(tempoDef, pip),
        greaterThan(powerUpDraftWeightForMember(tempoDef, horn)),
      );
    });

    test('mystic values special-cast perks over pip', () {
      final mystic = _member(
        family: 'mystic',
        speed: 3.0,
        intelligence: 4.0,
        strength: 2.3,
        beauty: 4.2,
      );
      final pip = _member(
        family: 'pip',
        speed: 4.0,
        intelligence: 3.0,
        strength: 3.7,
        beauty: 2.2,
      );
      final doubleCast = kRarePerks.firstWhere(
        (def) => def.id == 'double_cast',
      );

      expect(
        powerUpDraftWeightForMember(doubleCast, mystic),
        greaterThan(powerUpDraftWeightForMember(doubleCast, pip)),
      );
    });

    test(
      'fortress teams value orb and sustain tools more than tempo squads',
      () {
        final fortressTeam = [
          _member(
            family: 'horn',
            speed: 2.6,
            intelligence: 3.5,
            strength: 4.0,
            beauty: 2.4,
          ),
          _member(
            family: 'kin',
            speed: 2.5,
            intelligence: 4.0,
            strength: 3.0,
            beauty: 3.6,
            slotIndex: 1,
          ),
        ];
        final tempoTeam = [
          _member(
            family: 'pip',
            speed: 4.2,
            intelligence: 3.3,
            strength: 3.7,
            beauty: 2.4,
          ),
          _member(
            family: 'wing',
            speed: 3.5,
            intelligence: 4.0,
            strength: 2.4,
            beauty: 3.8,
            slotIndex: 1,
          ),
        ];
        final regenField = kOrbDefenses.firstWhere(
          (def) => def.id == 'regen_field',
        );

        expect(
          powerUpDraftWeightForParty(regenField, fortressTeam),
          greaterThan(powerUpDraftWeightForParty(regenField, tempoTeam)),
        );
      },
    );

    test('keystone offers appear as three unique run-defining picks', () {
      final casterTeam = [
        _member(
          family: 'mystic',
          speed: 3.0,
          intelligence: 4.1,
          strength: 2.4,
          beauty: 4.3,
        ),
        _member(
          family: 'wing',
          speed: 3.5,
          intelligence: 4.0,
          strength: 2.6,
          beauty: 3.8,
          slotIndex: 1,
        ),
      ];

      final choices = generateKeystoneChoices(
        PowerUpState(),
        10,
        party: casterTeam,
      );

      expect(choices, hasLength(3));
      expect(choices.map((choice) => choice.def.id).toSet().length, 3);
      expect(choices.every((choice) => choice.def.isKeystone), isTrue);
      expect(
        choices.any((choice) => choice.def.id == 'keystone_spellbloom'),
        isTrue,
      );
    });

    test('keystone state applies persistent modifiers once chosen', () {
      final state = PowerUpState();
      final keystone = kKeystonePowerUps.firstWhere(
        (def) => def.id == 'keystone_chrono_surge',
      );

      expect(state.hasKeystone, isFalse);
      expect(state.apply(keystone), isTrue);
      expect(state.hasKeystone, isTrue);
      expect(state.fireRateMultiplier, closeTo(1.20, 0.0001));
      // Chrono Surge adds 10% of the companion's own Speed.
      expect(state.speedBonus(0, 4.0), closeTo(0.40, 0.0001));
      expect(generateKeystoneChoices(state, 9, party: const []), isEmpty);
    });
  });

  group('REROLL and BANISH', () {
    // No Mystic, so no world surge may ever be offered.
    final party = [
      _member(
        family: 'pip',
        speed: 4.0,
        intelligence: 3.0,
        strength: 3.6,
        beauty: 2.6,
      ),
      _member(
        family: 'horn',
        speed: 2.6,
        intelligence: 3.4,
        strength: 4.0,
        beauty: 2.4,
        slotIndex: 1,
      ),
      _member(
        family: 'wing',
        speed: 3.6,
        intelligence: 3.8,
        strength: 2.6,
        beauty: 3.6,
        slotIndex: 2,
      ),
    ];
    PowerUpDef def(String id) => kSurvivalPowerUpsById[id]!;
    Set<String> ids(List<OfferedPowerUpChoice> choices) => {
      for (final c in choices) c.def.id,
    };

    /// A run some way in: one either-or path taken (so the other is shut),
    /// Fire Control taken as far as it goes, Ship Damage banished.
    PowerUpState builtRun() {
      final state = PowerUpState()..apply(def('missile_launcher'));
      for (var i = 0; i < def('fire_rate').maxStacks; i++) {
        state.apply(def('fire_rate'));
      }
      state.restoreDraftKeys(
        rerollsLeft: kSurvivalDraftRerolls,
        banishesLeft: kSurvivalDraftBanishes,
        banished: const {'ship_damage'},
      );
      return state;
    }

    void expectDrawnByTheRules(
      PowerUpState state,
      List<OfferedPowerUpChoice> choices,
    ) {
      for (final c in choices) {
        expect(c.def.mysticElement, isNull, reason: '${c.def.id}: no Mystic');
        expect(c.def.id, isNot('rapid_turret'), reason: 'the other path');
        expect(c.def.id, isNot('fire_rate'), reason: 'taken in full');
        expect(c.def.id, isNot('ship_damage'), reason: 'banished');
        expect(c.def.isKeystone, isFalse);
        expect(
          state.canApply(
            c.def,
            targetSlot: c.def.scope == PowerUpScope.companion
                ? c.targetSlot
                : null,
            companionCount: party.length,
          ),
          isTrue,
          reason: c.def.id,
        );
      }
    }

    test('an ordinary draft always offers three cards', () {
      for (var wave = 1; wave <= 60; wave++) {
        final state = builtRun();
        final draft = generatePowerUpChoices(state, wave, party: party);
        // A this-or-that fork is two cards by design.
        if (draft.length == 2 &&
            draft.every((c) => c.def.choiceGroup != null)) {
          continue;
        }
        expect(draft, hasLength(3), reason: 'wave $wave');
      }
    });

    test('a reroll draws by the draft\'s rules, fresh, and spends one', () {
      for (var wave = 1; wave <= 30; wave++) {
        final state = builtRun();
        var current = generatePowerUpChoices(state, wave, party: party);
        expect(current, isNotEmpty);
        expectDrawnByTheRules(state, current);
        for (var r = 1; r <= kSurvivalDraftRerolls; r++) {
          final next = rerollPowerUpDraft(
            state,
            wave,
            current: current,
            party: party,
          );
          expect(next, isNotNull, reason: 'wave $wave reroll $r');
          expect(next, isNotEmpty);
          expect(state.rerollsLeft, kSurvivalDraftRerolls - r);
          expectDrawnByTheRules(state, next!);
          // Fresh: none of the cards it replaced, with plenty to draw from.
          expect(ids(next).intersection(ids(current)), isEmpty);
          current = next;
        }
        // None left: nothing drawn, nothing spent.
        expect(
          rerollPowerUpDraft(state, wave, current: current, party: party),
          isNull,
        );
        expect(state.rerollsLeft, 0);
        expect(state.history.length, 1 + def('fire_rate').maxStacks);
      }
    });

    test('a this-or-that draft rerolls into an ordinary one', () {
      final state = PowerUpState();
      final fork = generatePowerUpChoices(state, 6, party: party);
      expect(fork, hasLength(2));
      expect(fork.every((c) => c.def.choiceGroup != null), isTrue);
      final next = rerollPowerUpDraft(state, 6, current: fork, party: party)!;
      expect(next.length, greaterThan(1));
      expect(ids(next).intersection(ids(fork)), isEmpty);
    });

    test('a banished upgrade is never offered again, and a fresh card '
        'takes its place', () {
      // Pack Leader leads half of all drafts: the hardest one to keep out.
      final state = PowerUpState();
      var wave = 1;
      var draft = generatePowerUpChoices(state, wave, party: party);
      while (!ids(draft).contains('pack_leader')) {
        draft = generatePowerUpChoices(state, ++wave, party: party);
      }
      final at = draft.indexWhere((c) => c.def.id == 'pack_leader');
      final after = banishFromPowerUpDraft(
        state,
        wave,
        current: draft,
        index: at,
        party: party,
      )!;
      expect(state.banished, {'pack_leader'});
      expect(state.banishesLeft, kSurvivalDraftBanishes - 1);
      // The pick is still to make, and the other cards stay where they were.
      expect(state.history, isEmpty);
      expect(after, hasLength(draft.length));
      for (var i = 0; i < draft.length; i++) {
        if (i == at) continue;
        expect(identical(after[i], draft[i]), isTrue);
      }
      expect(after[at].def.id, isNot('pack_leader'));
      expect(ids(draft), isNot(contains(after[at].def.id)));

      // Not in any draft after, any reroll of one, or any card a second
      // banish brings in.
      for (var w = 1; w <= 60; w++) {
        final keys = PowerUpState()
          ..restoreDraftKeys(
            rerollsLeft: kSurvivalDraftRerolls,
            banishesLeft: kSurvivalDraftBanishes,
            banished: state.banished,
          );
        var shown = generatePowerUpChoices(keys, w, party: party);
        expect(ids(shown), isNot(contains('pack_leader')), reason: 'wave $w');
        for (var r = 0; r < kSurvivalDraftRerolls; r++) {
          shown = rerollPowerUpDraft(keys, w, current: shown, party: party)!;
          expect(ids(shown), isNot(contains('pack_leader')));
        }
        shown = banishFromPowerUpDraft(
          keys,
          w,
          current: shown,
          index: 0,
          party: party,
        )!;
        expect(ids(shown), isNot(contains('pack_leader')));
        expect(keys.banished, hasLength(2));
      }

      // The second banish, then none: nothing banished, nothing spent.
      final second = banishFromPowerUpDraft(
        state,
        wave,
        current: after,
        index: 0,
        party: party,
      )!;
      expect(state.banishesLeft, 0);
      expect(
        banishFromPowerUpDraft(
          state,
          wave,
          current: second,
          index: 0,
          party: party,
        ),
        isNull,
      );
      expect(state.banished, {'pack_leader', after[0].def.id});
    });

    test('a keystone draft has neither key', () {
      final keystones = generateKeystoneChoices(
        PowerUpState(),
        10,
        party: party,
      );
      expect(keystones, isNotEmpty);
      expect(powerUpDraftHasKeys(keystones), isFalse);
      expect(
        powerUpDraftHasKeys(generatePowerUpChoices(PowerUpState(), 10)),
        isTrue,
      );
      final state = PowerUpState();
      expect(rerollPowerUpDraft(state, 10, current: keystones), isNull);
      expect(
        banishFromPowerUpDraft(state, 10, current: keystones, index: 0),
        isNull,
      );
      expect(state.rerollsLeft, kSurvivalDraftRerolls);
      expect(state.banishesLeft, kSurvivalDraftBanishes);
      expect(state.banished, isEmpty);
    });

    test(
      'a saved run keeps the keys it has left and what it banished',
      () async {
        Future<CosmicSurvivalGame> loaded([SuspendedSurvivalRun? run]) async {
          final game = CosmicSurvivalGame(
            party: run?.party ?? party,
            random: Random(5),
            onGameOver: () {},
            upgradeState: run?.upgradeState ?? SurvivalUpgradeState(),
            masterySnapshot: run?.mastery,
            shipSkin: run?.shipSkin,
          );
          game.onGameResize(Vector2(900, 700));
          await game.onLoad();
          if (run == null) {
            game.startGame();
          } else {
            game.resumeRun(run);
          }
          game.update(1 / 30);
          return game;
        }

        final game = await loaded();
        final checkpoint = game.captureSuspendedRun();
        expect(checkpoint.rerollsLeft, kSurvivalDraftRerolls);
        expect(checkpoint.banishesLeft, kSurvivalDraftBanishes);
        expect(checkpoint.banished, isEmpty);

        final draft = generatePowerUpChoices(game.powerUps, 3, party: party);
        final rerolled = rerollPowerUpDraft(
          game.powerUps,
          3,
          current: draft,
          party: party,
        )!;
        banishFromPowerUpDraft(
          game.powerUps,
          3,
          current: rerolled,
          index: 0,
          party: party,
        );
        final gone = rerolled.first.def.id;

        final saved = SuspendedSurvivalRun.tryDecode(
          game.captureSuspendedRun().encode(),
        )!;
        expect(saved.rerollsLeft, kSurvivalDraftRerolls - 1);
        expect(saved.banishesLeft, kSurvivalDraftBanishes - 1);
        expect(saved.banished, {gone});

        final back = await loaded(saved);
        expect(back.powerUps.rerollsLeft, kSurvivalDraftRerolls - 1);
        expect(back.powerUps.banishesLeft, kSurvivalDraftBanishes - 1);
        expect(back.powerUps.banished, {gone});
        expect(
          back.captureSuspendedRun().encode(),
          contains('"banished":["$gone"]'),
        );
        for (var w = 1; w <= 30; w++) {
          expect(
            ids(generatePowerUpChoices(back.powerUps, w, party: party)),
            isNot(contains(gone)),
          );
        }

        // Left mid-wave, the wave is played again from its checkpoint, and its
        // draft drawn again: what was spent on it comes back with it.
        final left = checkpoint.leftAt(game.captureSuspendedRun());
        expect(left.rerollsLeft, kSurvivalDraftRerolls);
        expect(left.banished, isEmpty);

        // A run saved before the keys were kept: every key, nothing banished.
        final old = game.captureSuspendedRun().toJson()..remove('draft');
        final legacy = SuspendedSurvivalRun.tryDecode(jsonEncode(old))!;
        expect(legacy.rerollsLeft, kSurvivalDraftRerolls);
        expect(legacy.banishesLeft, kSurvivalDraftBanishes);
        expect(legacy.banished, isEmpty);
        final continued = await loaded(legacy);
        expect(continued.powerUps.rerollsLeft, kSurvivalDraftRerolls);
        expect(continued.powerUps.banishesLeft, kSurvivalDraftBanishes);
        expect(continued.powerUps.banished, isEmpty);
      },
    );
  });

  group('the draft panel\'s keys', () {
    final pad = GameControllerService.instance;
    setUp(pad.debugReset);
    tearDown(pad.debugReset);

    final party = [
      _member(
        family: 'pip',
        speed: 4.0,
        intelligence: 3.0,
        strength: 3.6,
        beauty: 2.6,
      ),
      _member(
        family: 'horn',
        speed: 2.6,
        intelligence: 3.4,
        strength: 4.0,
        beauty: 2.4,
        slotIndex: 1,
      ),
    ];

    Future<void> showDraft(
      WidgetTester tester, {
      required List<OfferedPowerUpChoice> choices,
      required PowerUpState state,
      List<String>? log,
      bool nextIsBoss = false,
    }) async {
      tester.view
        ..physicalSize = const Size(475, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerUpSelectionOverlay(
              choices: choices,
              currentWave: 4,
              party: party,
              powerUps: state,
              nextWaveElement: 'Water',
              nextIsBoss: nextIsBoss,
              onSelect: (def, {targetSlot, targetName}) =>
                  log?.add('take ${def.id}'),
              onReroll: () => log?.add('reroll'),
              onBanish: (i) => log?.add('banish $i'),
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
    }

    final threeCards = [
      for (final id in const ['orb_vitality', 'strength_up', 'shield_pulse'])
        OfferedPowerUpChoice(
          def: kSurvivalPowerUpsById[id]!,
          targetSlot: id == 'strength_up' ? 1 : null,
          currentLevel: 0,
        ),
    ];
    final reroll = find.byKey(const ValueKey('survival.draft.reroll'));
    final banish = find.byKey(const ValueKey('survival.draft.banish'));
    Finder card(int i) => find.byKey(ValueKey('survival.draft.$i'));

    testWidgets('BANISH arms, a card is banished, BANISH again cancels', (
      tester,
    ) async {
      final log = <String>[];
      final choices = threeCards;
      await showDraft(
        tester,
        choices: choices,
        state: PowerUpState(),
        log: log,
      );
      expect(find.text('REROLL 2'), findsOneWidget);
      expect(find.text('BANISH 2'), findsOneWidget);
      expect(find.text('NEXT WAVE · WATER'), findsOneWidget);

      await tester.tap(banish);
      await tester.pump();
      expect(find.text('CHOOSE ONE TO BANISH'), findsOneWidget);
      await tester.tap(banish);
      await tester.pump();
      expect(find.text('ALCHEMICAL SURGE'), findsOneWidget);

      await tester.tap(banish);
      await tester.pump();
      await tester.tap(card(1));
      await tester.pump();
      expect(log, ['banish 1']);
      expect(find.text('ALCHEMICAL SURGE'), findsOneWidget);

      await tester.tap(reroll);
      await tester.tap(card(0));
      expect(log, ['banish 1', 'reroll', 'take ${choices[0].def.id}']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a spent key goes dim and takes no taps', (tester) async {
      final log = <String>[];
      final state = PowerUpState()
        ..restoreDraftKeys(
          rerollsLeft: 0,
          banishesLeft: 0,
          banished: const <String>{},
        );
      await showDraft(
        tester,
        choices: generatePowerUpChoices(state, 4, party: party),
        state: state,
        log: log,
        nextIsBoss: true,
      );
      expect(find.text('REROLL 0'), findsOneWidget);
      expect(find.text('BANISH 0'), findsOneWidget);
      expect(find.text('NEXT WAVE · BOSS'), findsOneWidget);
      await tester.tap(reroll);
      await tester.tap(banish);
      await tester.pump();
      expect(find.text('ALCHEMICAL SURGE'), findsOneWidget);
      expect(log, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a keystone draft shows neither key', (tester) async {
      await showDraft(
        tester,
        choices: generateKeystoneChoices(PowerUpState(), 10, party: party),
        state: PowerUpState(),
      );
      expect(find.textContaining('KEYSTONE'), findsWidgets);
      expect(reroll, findsNothing);
      expect(banish, findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a controller reaches both keys: down past the cards, then '
        'across', (tester) async {
      NormalizedGamepadEvent button(GamepadButton b, bool down) =>
          NormalizedGamepadEvent(
            gamepadId: '1',
            timestamp: 0,
            button: b,
            value: down ? 1 : 0,
            rawEvent: GamepadEvent(
              gamepadId: '1',
              timestamp: 0,
              type: KeyType.button,
              key: b.name,
              value: down ? 1 : 0,
            ),
          );
      Future<void> press(GamepadButton b) async {
        pad.debugPadEvent(button(b, true));
        pad.debugPadEvent(button(b, false));
        await tester.pump();
      }

      final log = <String>[];
      final choices = threeCards;
      await showDraft(
        tester,
        choices: choices,
        state: PowerUpState(),
        log: log,
      );

      // Down three times: the second card, the third, then REROLL.
      for (var i = 0; i < 3; i++) {
        await press(GamepadButton.dpadDown);
      }
      await press(GamepadButton.a);
      expect(log, ['reroll']);

      // Across to BANISH: A arms it, B puts it down, A arms it again.
      await press(GamepadButton.dpadRight);
      await press(GamepadButton.a);
      expect(find.text('CHOOSE ONE TO BANISH'), findsOneWidget);
      await press(GamepadButton.b);
      expect(find.text('ALCHEMICAL SURGE'), findsOneWidget);
      await press(GamepadButton.a);
      expect(find.text('CHOOSE ONE TO BANISH'), findsOneWidget);

      // Up to the last card: A banishes it rather than taking it.
      await press(GamepadButton.dpadUp);
      await press(GamepadButton.a);
      expect(log, ['reroll', 'banish 2']);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
