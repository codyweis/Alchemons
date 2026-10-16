import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_fusion_ledger.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_upgrade_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SURGE FUSIONS: two upgrades, each taken as far as it goes, make a third
/// that every ordinary draft holds until it is taken or banished.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PowerUpDef def(String id) => kSurvivalPowerUpsById[id]!;
  Set<String> ids(List<OfferedPowerUpChoice> choices) => {
    for (final c in choices) c.def.id,
  };

  CosmicPartyMember member(String family, int slot) => CosmicPartyMember(
    instanceId: 'fusion_${family}_$slot',
    baseId: 'base_$family',
    displayName: family,
    family: family,
    element: 'Fire',
    level: 10,
    slotIndex: slot,
    statSpeed: 4,
    statIntelligence: 4,
    statStrength: 4,
    statBeauty: 4,
    staminaBars: 3,
    staminaMax: 3,
  );
  // No Mystic, so no world surge is ever drawn.
  final party = [member('pip', 0), member('horn', 1), member('wing', 2)];

  /// Takes [id] as far as it goes.
  void maxOut(PowerUpState state, String id) {
    for (var i = 0; i < def(id).maxStacks; i++) {
      state.apply(def(id));
    }
  }

  /// Whether wave [wave]'s draft is an ordinary one for [state]: not the
  /// keystone draft (taken at wave 10 by the screen) nor an either-or fork.
  bool ordinary(PowerUpState state, int wave) {
    final draft = generatePowerUpChoices(PowerUpState(), wave, party: party);
    final fork =
        draft.length == 2 && draft.every((c) => c.def.choiceGroup != null);
    return !fork ||
        state.getGlobalStacks('missile_launcher') > 0 ||
        state.getGlobalStacks('rapid_turret') > 0;
  }

  group('the recipes', () {
    test('six to eight, each from two global upgrades that exist today', () {
      expect(kFusionPowerUps.length, inInclusiveRange(6, 8));
      final parentsSeen = <String>{};
      for (final fusion in kFusionPowerUps) {
        expect(fusion.isFusion, isTrue);
        expect(fusion.maxStacks, 1, reason: '${fusion.id} is taken once');
        expect(fusion.scope, PowerUpScope.global);
        expect(fusion.isKeystone, isFalse);
        expect(fusion.mysticElement, isNull);
        expect(fusion.fusedFrom, hasLength(2));
        // Never drawn at random.
        expect(kAllPowerUps.any((d) => d.id == fusion.id), isFalse);
        // Kept by a saved run.
        expect(kSurvivalPowerUpsById[fusion.id], same(fusion));
        final parents = fusionParents(fusion);
        expect(parents, hasLength(2), reason: '${fusion.id}: parents exist');
        for (final parent in parents) {
          expect(kAllPowerUps.contains(parent), isTrue);
          expect(parent.scope, PowerUpScope.global, reason: parent.id);
          expect(parent.isKeystone, isFalse);
          expect(parent.isFusion, isFalse);
          // One recipe per parent, so a card's "Fuses with" is one line.
          expect(parentsSeen.add(parent.id), isTrue, reason: parent.id);
          expect(fusionWithParent(parent.id), same(fusion));
        }
        // Plain names.
        expect(fusion.name.startsWith('The '), isFalse);
        expect(fusion.name.contains(' of '), isFalse);
      }
    });

    test('each fusion has its own art, in both its parents\' lights', () {
      final motifs = <UpgradeMotif>{};
      for (final fusion in kFusionPowerUps) {
        final spec = upgradeArtFor(fusion);
        expect(spec.second, isNotNull, reason: fusion.id);
        expect(motifs.add(spec.motif), isTrue, reason: fusion.id);
        for (final parent in fusionParents(fusion)) {
          expect(upgradeArtFor(parent).motif, isNot(spec.motif));
        }
      }
    });
  });

  group('the offer', () {
    test('not before both parents are taken in full', () {
      for (final fusion in kFusionPowerUps) {
        final [a, b] = fusionParents(fusion);
        final state = PowerUpState();
        maxOut(state, a.id);
        for (var i = 0; i < b.maxStacks - 1; i++) {
          state.apply(b);
        }
        expect(state.fusionReady(fusion), isFalse);
        expect(state.canApply(fusion), isFalse);
        for (var wave = 1; wave <= 40; wave++) {
          expect(
            ids(generatePowerUpChoices(state, wave, party: party)),
            isNot(contains(fusion.id)),
            reason: '${fusion.id} at wave $wave',
          );
        }
      }
    });

    test('then in every ordinary draft, leading it, until taken', () {
      for (final fusion in kFusionPowerUps) {
        final state = PowerUpState();
        for (final parent in fusionParents(fusion)) {
          maxOut(state, parent.id);
        }
        expect(state.fusionReady(fusion), isTrue);
        expect(state.canApply(fusion), isTrue);
        for (var wave = 1; wave <= 40; wave++) {
          final draft = generatePowerUpChoices(state, wave, party: party);
          if (!ordinary(state, wave)) {
            // The either-or fork is unchanged.
            expect(ids(draft), {'missile_launcher', 'rapid_turret'});
            continue;
          }
          expect(draft, hasLength(3), reason: '${fusion.id} wave $wave');
          expect(draft.first.def, same(fusion));
          expect(draft.skip(1).where((c) => c.def.isFusion), isEmpty);
        }
        // The keystone draft is unchanged.
        expect(
          generateKeystoneChoices(
            state,
            10,
            party: party,
          ).every((c) => c.def.isKeystone),
          isTrue,
        );
        // Taken once, and then never again.
        expect(state.apply(fusion), isTrue);
        expect(state.apply(fusion), isFalse);
        expect(state.fusionReady(fusion), isFalse);
        for (var wave = 1; wave <= 40; wave++) {
          expect(
            ids(generatePowerUpChoices(state, wave, party: party)),
            isNot(contains(fusion.id)),
          );
        }
      }
    });

    test('two due at once take two cards and leave one drawn', () {
      final state = PowerUpState();
      for (final id in const [
        'spread_shot',
        'homing_missiles',
        'regen_field',
        'orb_vitality',
      ]) {
        maxOut(state, id);
      }
      final draft = generatePowerUpChoices(state, 7, party: party);
      expect(draft, hasLength(3));
      expect(draft[0].def.id, 'fusion_homing_spread');
      expect(draft[1].def.id, 'fusion_tempered_field');
      expect(draft[2].def.isFusion, isFalse);
    });

    test('a reroll keeps it on the table and draws the rest fresh', () {
      final state = PowerUpState();
      maxOut(state, 'shield_pulse');
      maxOut(state, 'nova_detonation');
      var current = generatePowerUpChoices(state, 4, party: party);
      expect(current.first.def.id, 'fusion_nova_pulse');
      for (var r = 0; r < kSurvivalDraftRerolls; r++) {
        final next = rerollPowerUpDraft(
          state,
          4,
          current: current,
          party: party,
        )!;
        expect(next, hasLength(3));
        expect(next.first.def.id, 'fusion_nova_pulse');
        final drawnBefore = ids(current.skip(1).toList());
        final drawnNow = ids(next.skip(1).toList());
        expect(drawnNow.intersection(drawnBefore), isEmpty);
        current = next;
      }
      expect(state.rerollsLeft, 0);
    });

    test('a this-or-that fork rerolls into a draft that holds it', () {
      final state = PowerUpState();
      maxOut(state, 'regen_field');
      maxOut(state, 'orb_vitality');
      final fork = generatePowerUpChoices(state, 6, party: party);
      expect(ids(fork), {'missile_launcher', 'rapid_turret'});
      final next = rerollPowerUpDraft(state, 6, current: fork, party: party)!;
      expect(next.first.def.id, 'fusion_tempered_field');
    });

    test('banished, it is gone for the run', () {
      final state = PowerUpState();
      maxOut(state, 'rapid_turret');
      maxOut(state, 'auto_turret');
      final draft = generatePowerUpChoices(state, 3, party: party);
      expect(draft.first.def.id, 'fusion_linked_turrets');
      final after = banishFromPowerUpDraft(
        state,
        3,
        current: draft,
        index: 0,
        party: party,
      )!;
      expect(state.isBanished('fusion_linked_turrets'), isTrue);
      expect(after, hasLength(3));
      expect(after.where((c) => c.def.isFusion), isEmpty);
      expect(state.fusionReady(def('fusion_linked_turrets')), isFalse);
      for (var wave = 1; wave <= 40; wave++) {
        var shown = generatePowerUpChoices(state, wave, party: party);
        expect(ids(shown), isNot(contains('fusion_linked_turrets')));
      }
      final keys = PowerUpState()
        ..apply(def('rapid_turret'))
        ..restoreDraftKeys(
          rerollsLeft: 2,
          banishesLeft: 2,
          banished: state.banished,
        );
      maxOut(keys, 'rapid_turret');
      maxOut(keys, 'auto_turret');
      final shown = generatePowerUpChoices(keys, 3, party: party);
      final rerolled = rerollPowerUpDraft(
        keys,
        3,
        current: shown,
        party: party,
      )!;
      expect(ids(rerolled), isNot(contains('fusion_linked_turrets')));
      // Nor does the pause panel list it, nor a parent card name it.
      expect(
        SurvivalFusionLedger.recipesFor(state).map((f) => f.id),
        isNot(contains('fusion_linked_turrets')),
      );
      expect(state.fusionPartnerOf('auto_turret'), isNull);
    });

    test('a banished card beside it leaves it where it is', () {
      final state = PowerUpState();
      maxOut(state, 'shield_pulse');
      maxOut(state, 'nova_detonation');
      final draft = generatePowerUpChoices(state, 4, party: party);
      final after = banishFromPowerUpDraft(
        state,
        4,
        current: draft,
        index: 2,
        party: party,
      )!;
      expect(after.first.def.id, 'fusion_nova_pulse');
      expect(after[1], same(draft[1]));
    });
  });

  group('planning', () {
    testWidgets('a fusion card says FUSION and names its parents; a parent '
        'card says what it fuses with', (tester) async {
      final state = PowerUpState();
      maxOut(state, 'spread_shot');
      maxOut(state, 'homing_missiles');
      state.apply(def('kinetic_overdrive'));
      tester.view
        ..physicalSize = const Size(475, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PowerUpSelectionOverlay(
              choices: [
                OfferedPowerUpChoice(
                  def: def('fusion_homing_spread'),
                  currentLevel: 0,
                ),
                OfferedPowerUpChoice(
                  def: def('kinetic_overdrive'),
                  currentLevel: 1,
                ),
                OfferedPowerUpChoice(
                  def: def('command_beauty'),
                  currentLevel: 0,
                ),
              ],
              currentWave: 8,
              party: party,
              powerUps: state,
              onSelect: (d, {targetSlot, targetName}) {},
              onReroll: () {},
              onBanish: (_) {},
            ),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(find.text('FUSION'), findsOneWidget);
      expect(find.text('SPREAD SHOT + HUNTER SALVO'), findsOneWidget);
      // Only the parent card has the line, and it names the other parent.
      final line = find.byKey(const ValueKey('survival.draft.fusesWith'));
      expect(line, findsOneWidget);
      expect(
        (tester.widget<Text>(line).textSpan!.toPlainText()),
        'Fuses with Missile Launcher',
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the pause list greys each part until it is done', (
      tester,
    ) async {
      final state = PowerUpState();
      maxOut(state, 'shield_pulse');
      state.apply(def('nova_detonation'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SurvivalFusionLedger(powerUps: state)),
        ),
      );
      final row = find.byKey(
        const ValueKey('survival.fusions.fusion_nova_pulse'),
      );
      expect(row, findsOneWidget);
      final spans = <TextSpan>[];
      tester.widget<Text>(row).textSpan!.visitChildren((span) {
        if (span is TextSpan && span.text != null) spans.add(span);
        return true;
      });
      Color? colorOf(String text) =>
          spans.firstWhere((s) => s.text == text).style?.color;
      expect(spans.map((s) => s.text).join(), contains('Shield Pulse'));
      final done = colorOf('Shield Pulse');
      final pending = colorOf('Nova Detonation');
      expect(done, isNot(pending));
      expect(colorOf('Nova Pulse'), pending);
    });

    test('a parent names its partner while the fusion can be made', () {
      final state = PowerUpState();
      expect(state.fusionPartnerOf('spread_shot')?.id, 'homing_missiles');
      expect(state.fusionPartnerOf('homing_missiles')?.id, 'spread_shot');
      expect(
        state.fusionPartnerOf('missile_launcher')?.id,
        'kinetic_overdrive',
      );
      expect(state.fusionPartnerOf('command_strength'), isNull);
      // The other path of the either-or taken: Heavy Missiles can't be made.
      state.apply(def('rapid_turret'));
      expect(state.fusionPartnerOf('kinetic_overdrive'), isNull);
      expect(state.fusionPartnerOf('auto_turret')?.id, 'rapid_turret');
      // Rockets shut out Spread Shot and Hunter Salvo.
      state.apply(def('rocket_barrage'));
      expect(state.fusionPartnerOf('fire_rate')?.id, 'rocket_barrage');
      // A partner banished: nothing to fuse with.
      state.spendBanish('orb_vitality');
      expect(state.fusionPartnerOf('regen_field'), isNull);
      // Taken: nothing more to say.
      maxOut(state, 'shield_pulse');
      maxOut(state, 'nova_detonation');
      state.apply(def('fusion_nova_pulse'));
      expect(state.fusionPartnerOf('shield_pulse'), isNull);
    });

    test('the pause list holds what the drafts have shown a parent of', () {
      final state = PowerUpState();
      expect(SurvivalFusionLedger.recipesFor(state), isEmpty);
      // An either-or fork shows both doctrines: both their recipes.
      generatePowerUpChoices(state, 6, party: party);
      expect(SurvivalFusionLedger.recipesFor(state).map((f) => f.id), {
        'fusion_heavy_missiles',
        'fusion_linked_turrets',
      });
      // A pick counts as seen.
      state.apply(def('regen_field'));
      expect(
        SurvivalFusionLedger.recipesFor(state).map((f) => f.id),
        contains('fusion_tempered_field'),
      );
      // Choosing a doctrine drops the other's recipe.
      state.apply(def('missile_launcher'));
      expect(
        SurvivalFusionLedger.recipesFor(state).map((f) => f.id),
        isNot(contains('fusion_linked_turrets')),
      );
    });
  });

  group('a saved run', () {
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

    test('keeps a fusion taken, and one still due comes back due', () async {
      final game = await loaded();
      for (final id in const ['spread_shot', 'homing_missiles']) {
        for (var i = 0; i < def(id).maxStacks; i++) {
          game.applyPowerUp(def(id));
        }
      }
      // The draft that offered it: seen, then taken.
      final draft = generatePowerUpChoices(game.powerUps, 3, party: party);
      expect(draft.first.def.id, 'fusion_homing_spread');
      game.applyPowerUp(draft.first.def);
      expect(game.powerUps.hasHomingSpread, isTrue);
      // A second one ready but not yet taken.
      for (final id in const ['regen_field', 'orb_vitality']) {
        for (var i = 0; i < def(id).maxStacks; i++) {
          game.applyPowerUp(def(id));
        }
      }
      game.powerUps.noteOffered([
        OfferedPowerUpChoice(def: def('missile_launcher'), currentLevel: 0),
      ]);

      final saved = SuspendedSurvivalRun.tryDecode(
        game.captureSuspendedRun().encode(),
      )!;
      expect(saved.picks.map((p) => p.id), contains('fusion_homing_spread'));
      expect(saved.fusionParentsSeen, contains('missile_launcher'));

      final back = await loaded(saved);
      expect(back.powerUps.hasHomingSpread, isTrue);
      expect(
        [for (final a in back.powerUps.history) a.def.id],
        [for (final a in game.powerUps.history) a.def.id],
      );
      expect(back.powerUps.hasSeenFusionParent('missile_launcher'), isTrue);
      expect(
        SurvivalFusionLedger.recipesFor(back.powerUps).map((f) => f.id),
        SurvivalFusionLedger.recipesFor(game.powerUps).map((f) => f.id),
      );
      for (var wave = 2; wave <= 20; wave++) {
        if (!ordinary(back.powerUps, wave)) continue;
        final next = generatePowerUpChoices(back.powerUps, wave, party: party);
        expect(ids(next), isNot(contains('fusion_homing_spread')));
        expect(next.first.def.id, 'fusion_tempered_field');
      }
    });

    test('a save from before fusions were kept reads with none seen', () async {
      final game = await loaded();
      final json = game.captureSuspendedRun().toJson();
      (json['draft'] as Map).remove('seen');
      final legacy = SuspendedSurvivalRun.fromJson(
        Map<String, dynamic>.from(json),
      );
      expect(legacy.fusionParentsSeen, isEmpty);
    });
  });

  group('each fusion changes the fight', () {
    CosmicSurvivalEnemy body(Offset at, {double hp = 1e6}) =>
        CosmicSurvivalEnemy(
          position: at,
          hp: hp,
          maxHp: hp,
          speed: 0,
          damage: 0,
          radius: 10,
          tier: EnemyTier.drone,
          element: 'Earth',
          conduct: EnemyConduct.charge,
          target: CosmicEnemyTarget.orb,
          retargetTimer: 0,
        );

    /// A quiet arena with [picks] taken, the fusion among them when [fused]:
    /// nothing on the field but what the test puts there, no Alchemon out.
    Future<CosmicSurvivalGame> arena(
      List<String> picks, {
      String? fusion,
      bool fused = false,
    }) async {
      final game = CosmicSurvivalGame(
        party: [member('pip', 0)],
        onGameOver: () {},
        random: Random(5),
      );
      game.onGameResize(Vector2(900, 700));
      await game.onLoad();
      for (final id in picks) {
        for (var i = 0; i < def(id).maxStacks; i++) {
          game.applyPowerUp(def(id));
        }
      }
      if (fused) game.applyPowerUp(def(fusion!));
      expect(game.powerUps.has(fusion ?? ''), fused);
      game.startGame();
      game.enemies.clear();
      return game;
    }

    /// Frames with nothing on the field but [bodies], each held where it
    /// was put (a body left alone walks into the orb and is spent on it).
    void play(
      CosmicSurvivalGame game,
      List<CosmicSurvivalEnemy> bodies,
      double seconds,
    ) {
      final home = [for (final b in bodies) b.position];
      void hold() {
        game.enemies.removeWhere((e) => !bodies.contains(e));
        for (var i = 0; i < bodies.length; i++) {
          bodies[i]
            ..position = home[i]
            ..knockbackVelocity = Offset.zero;
        }
      }

      for (var t = 0.0; t < seconds; t += 1 / 60) {
        hold();
        if (game.showingPowerUpSelection) game.dismissPowerUpSelection();
        game.update(1 / 60);
      }
      hold();
    }

    /// Where a ship-weapon test puts its body: in the gun's reach wherever
    /// the ship is on its idle orbit, and clear of the orb.
    Offset inReach(CosmicSurvivalGame game) =>
        game.orb.position + const Offset(0, 120);

    double taken(List<CosmicSurvivalEnemy> bodies) =>
        bodies.fold(0.0, (sum, b) => sum + (b.maxHp - b.hp));

    test('Homing Spread: the side shots home in and land', () async {
      Future<(int, double)> volley(bool fused) async {
        final game = await arena(
          const ['spread_shot', 'homing_missiles'],
          fusion: 'fusion_homing_spread',
          fused: fused,
        );
        final target = body(inReach(game));
        game.enemies.add(target);
        game.ship.fireTimer = 99;
        play(game, [target], 1 / 60);
        final homingSides = game.shipProjectiles
            .where((p) => p.isHoming && p.target != null)
            .length;
        play(game, [target], 1.5);
        return (homingSides, taken([target]));
      }

      final (plainHoming, plainDamage) = await volley(false);
      final (fusedHoming, fusedDamage) = await volley(true);
      // Hunter Salvo alone steers the centre shot; fused, all seven.
      expect(plainHoming, 1);
      expect(fusedHoming, 1 + 2 * def('spread_shot').maxStacks);
      expect(fusedDamage, greaterThan(plainDamage * 2));
    });

    test('Rapid Rockets: rockets come as fast as shots', () async {
      Future<double> barrage(bool fused) async {
        final game = await arena(
          const ['rocket_barrage', 'fire_rate'],
          fusion: 'fusion_rapid_rockets',
          fused: fused,
        );
        final target = body(inReach(game));
        game.enemies.add(target);
        play(game, [target], 6);
        return taken([target]);
      }

      final plain = await barrage(false);
      final fused = await barrage(true);
      expect(plain, greaterThan(0));
      // 1.5x the rockets, give or take one in flight.
      expect(fused / plain, inInclusiveRange(1.3, 1.7));
    });

    test('Heavy Missiles: the overdrive drives the missiles', () async {
      Future<ShipProjectile> firstMissile(bool fused) async {
        final game = await arena(
          const ['missile_launcher', 'kinetic_overdrive'],
          fusion: 'fusion_heavy_missiles',
          fused: fused,
        );
        final target = body(inReach(game));
        game.enemies.add(target);
        // The gun's own rounds are smaller and carry no blast.
        play(game, [target], 1 / 60);
        return game.shipProjectiles.firstWhere((p) => p.splashRadius > 100);
      }

      final plain = await firstMissile(false);
      final fused = await firstMissile(true);
      final kinetic = def('kinetic_overdrive').maxStacks;
      expect(fused.damage / plain.damage, closeTo(1 + kinetic * 0.10, 1e-6));
      expect(
        fused.velocity.distance / plain.velocity.distance,
        closeTo(1 + kinetic * 0.12, 1e-6),
      );
    });

    test('Linked Turrets: the orb turret fires on what the ship turret hits '
        'near the orb', () async {
      Future<double> held(bool fused, Offset fromOrb) async {
        final game = await arena(
          const ['rapid_turret', 'auto_turret'],
          fusion: 'fusion_linked_turrets',
          fused: fused,
        );
        final target = body(game.orb.position + fromOrb);
        game.enemies.add(target);
        play(game, [target], 4);
        return taken([target]);
      }

      final near = await held(false, const Offset(150, 0));
      final nearFused = await held(true, const Offset(150, 0));
      expect(nearFused, greaterThan(near * 1.25));
    });

    test('Nova Pulse: the shield pulse sets off the nova', () async {
      Future<double> pulse(bool fused) async {
        final game = await arena(
          const ['shield_pulse', 'nova_detonation'],
          fusion: 'fusion_nova_pulse',
          fused: fused,
        );
        final bodies = [
          for (final a in const [0.4, 2.2, 4.0])
            body(game.orb.position + Offset(cos(a), sin(a)) * 160),
        ];
        game.enemies.addAll(bodies);
        // The pulse is every 6 s at its last level; the nova's own every 9.
        play(game, bodies, 5.8);
        final before = taken(bodies);
        play(game, bodies, 0.5);
        return taken(bodies) - before;
      }

      final plain = await pulse(false);
      final fused = await pulse(true);
      final nova = 20.0 * def('nova_detonation').maxStacks;
      expect(fused - plain, closeTo(3 * nova, 3 * nova * 0.25));
    });

    test('Tempered Field: regeneration restores a share of max HP', () async {
      Future<(double, double)> mend(bool fused) async {
        final game = await arena(
          const ['regen_field', 'orb_vitality'],
          fusion: 'fusion_tempered_field',
          fused: fused,
        );
        game.orb.currentHp = game.orb.maxHp * 0.5;
        final start = game.orb.currentHp;
        play(game, const [], 3.5);
        return (game.orb.currentHp - start, game.orb.maxHp);
      }

      final (plain, maxHp) = await mend(false);
      final (fused, _) = await mend(true);
      final ticks = (plain / (2.0 * def('regen_field').maxStacks)).round();
      expect(ticks, 3);
      expect(fused - plain, closeTo(ticks * maxHp * kTemperedFieldShare, 1));
    });
  });
}
