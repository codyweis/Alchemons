// Survival runs kept to come back to: the checkpoint each wave writes, what a
// continued run is rebuilt with, leaving never healing, and the lobby's
// CONTINUE / NEW RUN.
//
//   flutter test test/survival_run_resume_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'survival_lobby_harness.dart';

/// A level-10 party at [potential], one of each of four families and a
/// Fire Mystic (so a world pick has somewhere to land).
List<CosmicPartyMember> resumeParty({int potential = 60}) {
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final creatures = (data['creatures'] as List).cast<Map<String, dynamic>>();
  const ids = ['PIP01', 'HOR02', 'MAN04', 'MYS01', 'LET02'];
  return [
    for (var i = 0; i < ids.length; i++)
      (() {
        final row = creatures.firstWhere((c) => c['id'] == ids[i]);
        final base = row['baseStats'] as Map<String, dynamic>;
        double stat(String key) => AlchemonStatSystem.effectiveInternal(
          speciesBase: base[key] as int,
          level: 10,
          potential: potential,
        );
        return CosmicPartyMember(
          instanceId: 'resume_$i',
          baseId: ids[i],
          displayName: row['name'] as String,
          family: row['mutationFamily'] as String,
          element: (row['types'] as List).first as String,
          level: 10,
          slotIndex: i,
          statSpeed: stat('speed'),
          statIntelligence: stat('intelligence'),
          statStrength: stat('strength'),
          statBeauty: stat('beauty'),
          statSpeedPotential: potential.toDouble(),
          statIntelligencePotential: potential.toDouble(),
          statStrengthPotential: potential.toDouble(),
          statBeautyPotential: potential.toDouble(),
          staminaBars: 3,
          staminaMax: 3,
        );
      })(),
  ];
}

/// A headless run, loaded and started, its checkpoints collected.
Future<(CosmicSurvivalGame, List<SuspendedSurvivalRun>)> startedRun({
  List<CosmicPartyMember>? party,
  int seed = 5,
}) async {
  final checkpoints = <SuspendedSurvivalRun>[];
  late final CosmicSurvivalGame game;
  game = CosmicSurvivalGame(
    party: party ?? resumeParty(),
    random: Random(seed),
    onGameOver: () {},
    upgradeState: SurvivalUpgradeState(
      equippedSkin: OrbBaseSkin.celestialOrb,
      guardianLevels: {
        GuardianUpgrade.attack: 3,
        GuardianUpgrade.defense: 2,
        GuardianUpgrade.cooldown: 1,
        GuardianUpgrade.range: 0,
      },
    ),
    onWaveCheckpoint: () => checkpoints.add(game.captureSuspendedRun()),
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.startGame();
  return (game, checkpoints);
}

/// A headless run continued from [run], built as the screen builds it.
Future<CosmicSurvivalGame> resumedRun(SuspendedSurvivalRun run) async {
  final game = CosmicSurvivalGame(
    party: run.party,
    random: Random(99),
    onGameOver: () {},
    upgradeState: run.upgradeState,
    masterySnapshot: run.mastery,
    shipSkin: run.shipSkin,
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
  game.resumeRun(run);
  return game;
}

void pick(CosmicSurvivalGame game, String id, {int? slot}) => game.applyPowerUp(
  kSurvivalPowerUpsById[id]!,
  targetSlot: slot,
  targetName: slot == null ? null : game.party[slot].displayName,
);

/// Clears the wave in progress through the game's own intermission, and
/// plays the frame after it, where the new wave's checkpoint is taken.
void clearWave(CosmicSurvivalGame game) {
  final wave = game.spawner.currentWave;
  game.spawner.intermission = true;
  for (var i = 0; i < 6 && game.spawner.currentWave == wave; i++) {
    if (game.showingPowerUpSelection) game.dismissPowerUpSelection();
    game.update(1 / 30);
  }
  game.update(1 / 30);
  if (game.showingPowerUpSelection) game.dismissPowerUpSelection();
}

/// Takes slot [slot] out of the fight for good.
void downCompanion(CosmicSurvivalGame game, int slot) {
  final comp = game.activeCompanions[slot]!;
  comp.currentHp = 0;
  comp.isDead = true;
  game.update(1 / 30);
}

void expectSamePicks(CosmicSurvivalGame a, CosmicSurvivalGame b) {
  expect(
    [for (final p in b.powerUps.history) '${p.def.id}@${p.targetSlot}'],
    [for (final p in a.powerUps.history) '${p.def.id}@${p.targetSlot}'],
  );
  for (final def in kSurvivalPowerUpsById.values) {
    if (def.scope == PowerUpScope.companion) {
      for (var slot = 0; slot < a.party.length; slot++) {
        expect(
          b.powerUps.getCompanionStacks(slot, def.id),
          a.powerUps.getCompanionStacks(slot, def.id),
          reason: '${def.id} on slot $slot',
        );
      }
    } else {
      expect(
        b.powerUps.getGlobalStacks(def.id),
        a.powerUps.getGlobalStacks(def.id),
        reason: def.id,
      );
    }
  }
  for (var slot = 0; slot < a.party.length; slot++) {
    for (final base in const [4.0, 10.0]) {
      expect(
        b.powerUps.strengthBonus(slot, base),
        a.powerUps.strengthBonus(slot, base),
      );
      expect(
        b.powerUps.intelligenceBonus(slot, base),
        a.powerUps.intelligenceBonus(slot, base),
      );
      expect(
        b.powerUps.beautyBonus(slot, base),
        a.powerUps.beautyBonus(slot, base),
      );
      expect(
        b.powerUps.speedBonus(slot, base),
        a.powerUps.speedBonus(slot, base),
      );
    }
    expect(
      b.powerUps.companionHasPhoenixRebirth(slot),
      a.powerUps.companionHasPhoenixRebirth(slot),
    );
    expect(
      b.powerUps.mysticWorldLevel(slot, 'Fire'),
      a.powerUps.mysticWorldLevel(slot, 'Fire'),
    );
  }
  expect(b.powerUps.hasKeystone, a.powerUps.hasKeystone);
  expect(b.maxActiveCompanions, a.maxActiveCompanions);
}

/// The kept run the lobby tests start from: the mid-game save's five, at
/// [wave], with two out and a dent in the orb.
SuspendedSurvivalRun keptRun(
  LobbySave save, {
  int wave = 12,
  List<String> ids = kLobbyTeam,
}) {
  const bases = {
    'own-1': 'LET02',
    'own-2': 'PIP06',
    'own-3': 'HOR13',
    'own-4': 'MAN03',
    'own-5': 'MSK01',
    'released-long-ago': 'PIP06',
  };
  final party = <CosmicPartyMember>[];
  for (final (i, id) in ids.indexed) {
    final base = save.catalog.getCreatureById(bases[id]!)!;
    party.add(
      CosmicPartyMember(
        instanceId: id,
        baseId: base.id,
        displayName: base.name,
        imagePath: 'assets/images/${base.image}',
        element: base.types.first,
        family: base.mutationFamily ?? 'kin',
        level: 10,
        statSpeed: 3,
        statIntelligence: 3,
        statStrength: 3,
        statBeauty: 3,
        slotIndex: i,
        staminaBars: 3,
        staminaMax: 3,
      ),
    );
  }
  return SuspendedSurvivalRun(
    savedAtMs: 1760000000000,
    wave: wave,
    picks: [
      const SuspendedPick(id: 'pack_leader'),
      SuspendedPick(
        id: 'strength_up',
        targetSlot: 0,
        targetName: party.first.displayName,
      ),
    ],
    phoenixUsed: const {},
    meter: 0,
    meterProgress: 140,
    orbMaxHp: 800,
    orbHp: 640,
    orbShield: 0,
    shipHp: 100,
    shipDead: false,
    shipRespawnElapsed: 0,
    slots: [
      for (var i = 0; i < party.length; i++)
        SuspendedSlotHealth(slot: i, hp: 1, dead: false),
    ],
    activeSlots: const [0, 1],
    tetheredSlot: 0,
    tetherMode: true,
    kills: 900,
    score: 30000,
    timeElapsed: 600,
    healingToMons: 0,
    healingToShip: 0,
    healingToOrb: 0,
    slotStats: const [],
    party: party,
    equippedOrb: OrbBaseSkin.celestialOrb,
    guardianLevels: const {},
    abilityLevels: const {},
    mastery: SurvivalFamilyMasterySnapshot.empty,
    shipSkin: null,
  );
}

Future<SuspendedSurvivalRun?> savedRun(WidgetTester tester, LobbySave save) =>
    tester.runAsync<SuspendedSurvivalRun?>(
      () => SuspendedRunStore(save.db).load(),
    );

Future<String?> savedRunRow(WidgetTester tester, LobbySave save) => tester
    .runAsync<String?>(() => save.db.settingsDao.getSetting(kSuspendedRunKey));

Map<CreatureFamily, int> masteryEarned(LobbySave save) => {
  for (final f in CreatureFamily.values) f: save.mastery.lifetimePointsFor(f),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the kept run', () {
    test('round-trips through its JSON exactly', () async {
      final (game, _) = await startedRun();
      game.update(1 / 30);
      pick(game, 'pack_leader');
      game.summonCompanion(0);
      game.summonCompanion(3);
      pick(game, 'strength_up', slot: 0);
      pick(game, 'world_fire', slot: 3);
      pick(game, 'keystone_bastion_heart');
      clearWave(game);
      game.orb.currentHp -= 37.5;

      final run = game.captureSuspendedRun();
      final decoded = SuspendedSurvivalRun.tryDecode(run.encode());
      expect(decoded, isNotNull);
      expect(decoded, run);
      expect(decoded!.encode(), run.encode());
      expect(decoded.wave, 2);
      expect(decoded.party.map((m) => m.statStrength), [
        for (final m in game.party) m.statStrength,
      ]);
      expect(decoded.upgradeState.getGuardianLevel(GuardianUpgrade.attack), 3);
      expect(decoded.equippedOrb, OrbBaseSkin.celestialOrb);
      expect(decoded.deployedSlots, {0, 3});
    });

    test('who went out is kept, and a continued run counts them', () async {
      final (game, _) = await startedRun();
      game.update(1 / 30);
      // Slot 2 goes out and back to reserve before the checkpoint: it still
      // went out. (One out at a time, without Pack Leader.)
      game.summonCompanion(2);
      game.returnCompanion(2);
      game.summonCompanion(0);
      clearWave(game);
      expect(game.deployedCompanionSlots, {0, 2});

      final kept = SuspendedSurvivalRun.tryDecode(
        game.captureSuspendedRun().encode(),
      )!;
      expect(kept.version, kSuspendedRunVersion);
      expect(kept.deployedSlots, {0, 2});
      expect(kept.activeSlots, [0]);

      final back = await resumedRun(kept);
      expect(back.activeCompanions.keys, [0]);
      expect(back.deployedCompanionSlots, {0, 2});

      // Sent out mid-wave and then left: the leaving keeps that too.
      game.summonCompanion(4);
      final left = kept.leftAt(game.captureSuspendedRun());
      expect(left.deployedSlots, {0, 2, 4});
    });

    test('a save from before deployment was kept is still read', () async {
      final (game, _) = await startedRun();
      game.update(1 / 30);
      game.summonCompanion(1);
      game.companionRunStats.putIfAbsent(3, CompanionRunStats.new).kills = 4;
      final json = game.captureSuspendedRun().toJson()
        ..['v'] = kSuspendedRunLegacyVersion
        ..remove('deployed');
      final legacy = SuspendedSurvivalRun.tryDecode(jsonEncode(json));
      expect(legacy, isNotNull);
      // Out when it was taken, or with anything to its name.
      expect(legacy!.deployedSlots, {1, 3});
      expect(legacy.version, kSuspendedRunVersion);
    });

    test('a save of another version, or a damaged one, is not read', () async {
      final (game, _) = await startedRun();
      game.update(1 / 30);
      final json = game.captureSuspendedRun().toJson();
      expect(
        SuspendedSurvivalRun.tryDecode(jsonEncode({...json, 'v': 99})),
        isNull,
      );
      expect(SuspendedSurvivalRun.tryDecode('{"v":1,"wave":'), isNull);
      expect(SuspendedSurvivalRun.tryDecode('[]'), isNull);
      expect(
        SuspendedSurvivalRun.tryDecode(
          jsonEncode({
            ...json,
            'picks': [
              {'id': 'no_such_pick'},
            ],
          }),
        ),
        isNull,
      );
    });

    test('a checkpoint is taken on the first frame and as each wave '
        'begins', () async {
      final (game, checkpoints) = await startedRun();
      game.update(1 / 30);
      expect(checkpoints.map((c) => c.wave), [1]);
      clearWave(game);
      clearWave(game);
      clearWave(game);
      expect(checkpoints.map((c) => c.wave), [1, 2, 3, 4]);
    });
  });

  test('a run played a few waves comes back as it was left', () async {
    final (game, checkpoints) = await startedRun();
    game.update(1 / 30);
    for (var i = 0; i < 3; i++) {
      pick(game, 'pack_leader');
    }
    for (final slot in [0, 1, 3, 4]) {
      game.summonCompanion(slot);
    }
    pick(game, 'strength_up', slot: 0);
    pick(game, 'strength_up', slot: 0);
    pick(game, 'intelligence_up', slot: 2);
    pick(game, 'world_fire', slot: 3);
    pick(game, 'world_fire', slot: 3);
    clearWave(game);
    pick(game, 'orb_vitality');
    pick(game, 'keystone_bastion_heart');
    pick(game, 'phoenix_rebirth', slot: 1);
    pick(game, 'command_speed');
    // Slot 4 goes down and is brought back; slot 1 spends its Phoenix.
    downCompanion(game, 4);
    pick(game, 'revive_half', slot: 4);
    game.powerUps.consumePhoenixRebirth(1);
    clearWave(game);
    for (var i = 0; i < 45; i++) {
      game.update(1 / 30);
    }
    game.orb.currentHp = game.orb.maxHp * 0.62;
    game.orb.shieldHp = 30;
    game.ship.currentHp = 71;
    game.activeCompanions[0]!.currentHp =
        (game.activeCompanions[0]!.maxHp * 0.4).round();
    downCompanion(game, 3);
    clearWave(game);
    expect(checkpoints.last.wave, 4);

    // Kept as the fourth wave began, and read back from its JSON.
    final kept = SuspendedSurvivalRun.tryDecode(
      game.captureSuspendedRun().encode(),
    )!;
    final back = await resumedRun(kept);

    expect(back.spawner.currentWave, game.spawner.currentWave);
    expect(back.spawner.currentWave, 4);
    expectSamePicks(game, back);
    expect(back.orb.maxHp, game.orb.maxHp);
    expect(back.orb.currentHp, game.orb.currentHp);
    expect(back.orb.shieldHp, game.orb.shieldHp);
    expect(back.ship.currentHp, game.ship.currentHp);
    expect(back.ship.isDead, game.ship.isDead);
    expect(back.activeCompanions.keys.toSet(), {
      for (final e in game.activeCompanions.entries)
        if (!e.value.isDead) e.key,
    });
    expect(back.defeatedCompanionSlots, game.defeatedCompanionSlots);
    expect(back.defeatedCompanionSlots, contains(3));
    expect(back.defeatedCompanionSlots, isNot(contains(4)));
    for (final MapEntry(key: slot, value: comp)
        in back.activeCompanions.entries) {
      final was = game.activeCompanions[slot]!;
      expect(comp.maxHp, was.maxHp, reason: 'slot $slot');
      expect(comp.currentHp, closeTo(was.currentHp, 1), reason: 'slot $slot');
    }
    expect(back.alchemicalMeter, game.alchemicalMeter);
    expect(back.alchemicalMeterMax, game.alchemicalMeterMax);
    expect(back.stats.kills, game.stats.kills);
    expect(back.stats.score, game.stats.score);
    expect(back.stats.timeElapsed, game.stats.timeElapsed);
    for (final MapEntry(key: slot, value: s)
        in game.companionRunStats.entries) {
      expect(back.companionRunStats[slot]?.damageDealt, s.damageDealt);
      expect(back.companionRunStats[slot]?.kills, s.kills);
    }
    expect(back.upgradeState.getGuardianLevel(GuardianUpgrade.attack), 3);
    expect(back.upgradeState.equippedSkin, OrbBaseSkin.celestialOrb);

    // And it plays on: the wave it resumed on is the one in progress, and
    // clearing it takes the run to the next.
    for (var i = 0; i < 30; i++) {
      back.update(1 / 30);
    }
    expect(back.isGameOver, isFalse);
    clearWave(back);
    expect(back.spawner.currentWave, 5);
  });

  test('leaving mid-wave never heals', () async {
    final (game, checkpoints) = await startedRun();
    game.update(1 / 30);
    pick(game, 'pack_leader');
    game.summonCompanion(0);
    game.summonCompanion(1);
    clearWave(game);
    final checkpoint = checkpoints.last;
    expect(checkpoint.wave, 2);

    // Mid-wave: hurt, then a pick that heals the orb, then a companion down.
    game.orb.currentHp = checkpoint.orbHp - 180;
    game.ship.currentHp = checkpoint.shipHp - 40;
    game.activeCompanions[0]!.currentHp =
        (game.activeCompanions[0]!.maxHp * 0.3).round();
    pick(game, 'orb_vitality');
    downCompanion(game, 1);
    final atExit = game.captureSuspendedRun();
    expect(atExit.orbHp, greaterThan(checkpoint.orbHp - 180));

    final left = checkpoint.leftAt(atExit);
    expect(left.wave, checkpoint.wave);
    expect(left.orbHp, min(checkpoint.orbHp, atExit.orbHp));
    expect(left.orbHp, lessThan(checkpoint.orbHp));
    expect(left.orbMaxHp, checkpoint.orbMaxHp);
    expect(left.shipHp, checkpoint.shipHp - 40);
    expect(left.slots[0].hp, closeTo(0.3, 0.01));
    expect(left.slots[1].dead, isTrue);
    expect(left.activeSlots, [0]);
    // The wave is played again, so what it paid out is earned again.
    expect(left.picks.length, checkpoint.picks.length);
    expect(left.meter, checkpoint.meter);
    expect(left.kills, checkpoint.kills);

    // Healed past the checkpoint before leaving: still the checkpoint's.
    game.orb.currentHp = game.orb.maxHp;
    game.ship.currentHp = game.ship.maxHp;
    final healed = checkpoint.leftAt(game.captureSuspendedRun());
    expect(healed.orbHp, checkpoint.orbHp);
    expect(healed.shipHp, checkpoint.shipHp);

    // And the run that comes back has no more than it was left with.
    final back = await resumedRun(
      SuspendedSurvivalRun.tryDecode(left.encode())!,
    );
    expect(back.orb.currentHp, left.orbHp);
    expect(back.ship.currentHp, left.shipHp);
    expect(back.isCompanionDefeated(1), isTrue);
    expect(back.activeCompanions.keys, [0]);
    expect(
      back.activeCompanions[0]!.hpPercent,
      closeTo(left.slots[0].hp, 0.01),
    );
  });

  group('the lobby', () {
    setUpAll(loadLobbyFonts);

    void phone(WidgetTester tester) {
      tester.view.physicalSize = kLobbyPhysical;
      tester.view.devicePixelRatio = kLobbyDpr;
      addTearDown(tester.view.reset);
    }

    Widget withAudio(LobbySave save) =>
        ChangeNotifierProvider<AudioController>.value(
          value: SilentAudio(),
          child: save.app(),
        );

    CosmicSurvivalGame game(WidgetTester tester) =>
        tester
                .widget<GameWidget>(
                  find.byWidgetPredicate((w) => w is GameWidget),
                )
                .game!
            as CosmicSurvivalGame;

    testWidgets('a kept run shows CONTINUE with its wave, its team fixed', (
      tester,
    ) async {
      phone(tester);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      await tester.runAsync(
        () => SuspendedRunStore(save.db).save(keptRun(save, wave: 46)),
      );
      await tester.pumpWidget(save.app());
      await settleLobby(tester, 12);

      expect(lobbyShown(), isTrue);
      final cont = tester.widget<BracketButton>(
        find.byKey(const ValueKey('survival.continue')),
      );
      expect(cont.label, 'CONTINUE · WAVE 46');
      expect(cont.primary, isTrue);
      final newRun = tester.widget<BracketButton>(
        find.byKey(const ValueKey('survival.newRun')),
      );
      expect(newRun.label, 'NEW RUN');
      expect(newRun.primary, isFalse);
      expect(find.byKey(const ValueKey('survival.start')), findsNothing);

      // The run's team, and no changing it.
      expect(find.text('WATERLET'), findsOneWidget);
      expect(
        tester
            .widget<BracketButton>(
              find.byKey(const ValueKey('survival.changeTeam')),
            )
            .enabled,
        isFalse,
      );
      expect(
        find.text(
          'This team is in the saved wave 46 run. Start a new run to change '
          'it.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await save.dispose(tester);
    });

    testWidgets('a kept run missing a creature can only be abandoned', (
      tester,
    ) async {
      phone(tester);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      await tester.runAsync(
        () => SuspendedRunStore(save.db).save(
          keptRun(save, ids: const ['own-1', 'released-long-ago', 'own-3']),
        ),
      );
      await tester.pumpWidget(save.app());
      await settleLobby(tester, 12);

      expect(find.byKey(const ValueKey('survival.continue')), findsNothing);
      expect(
        tester
            .widget<BracketButton>(
              find.byKey(const ValueKey('survival.newRun')),
            )
            .primary,
        isTrue,
      );
      expect(
        find.textContaining('no longer in your collection'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await save.dispose(tester);
    });

    testWidgets('a save this build cannot read is dropped quietly', (
      tester,
    ) async {
      phone(tester);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      await tester.runAsync(
        () => save.db.settingsDao.setSetting(
          kSuspendedRunKey,
          '{"v":0,"wave":9}',
        ),
      );
      await tester.pumpWidget(save.app());
      await settleLobby(tester, 12);

      expect(find.byKey(const ValueKey('survival.start')), findsOneWidget);
      expect(find.byKey(const ValueKey('survival.continue')), findsNothing);
      expect(await savedRunRow(tester, save), isNull);

      await save.dispose(tester);
    });

    testWidgets('NEW RUN abandons the kept run: no mastery, then START', (
      tester,
    ) async {
      phone(tester);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      await tester.runAsync(
        () => SuspendedRunStore(save.db).save(keptRun(save, wave: 46)),
      );
      final before = masteryEarned(save);
      await tester.pumpWidget(withAudio(save));
      await settleLobby(tester, 12);

      // Kept is kept.
      await tester.tap(find.byKey(const ValueKey('survival.newRun')));
      await settleLobby(tester, 6);
      expect(
        find.text('Abandon the wave 46 run? Its mastery is lost.'),
        findsOneWidget,
      );
      await tester.tap(find.text('KEEP'));
      await settleLobby(tester, 6);
      expect(await savedRun(tester, save), isNotNull);
      expect(find.byKey(const ValueKey('survival.continue')), findsOneWidget);

      // Abandoned: gone, nothing paid, and a new run carried in as START's.
      await tester.tap(find.byKey(const ValueKey('survival.newRun')));
      await settleLobby(tester, 6);
      await tester.tap(find.text('ABANDON'));
      await settleLobby(tester, 6);
      expect(await savedRunRow(tester, save), isNull);
      expect(masteryEarned(save), before);
      expect(game(tester).party.map((m) => m.instanceId), kLobbyTeam);
      expect(game(tester).spawner.currentWave, 1);
      expect(tester.takeException(), isNull);

      await save.dispose(tester);
    });

    testWidgets('CONTINUE picks the run up at its wave, and a death there '
        'banks mastery for the whole run', (tester) async {
      phone(tester);
      final save = await LobbySave.create(tester, team: kLobbyTeam);
      final kept = keptRun(save, wave: 12);
      await tester.runAsync(() => SuspendedRunStore(save.db).save(kept));
      final before = masteryEarned(save);
      await tester.pumpWidget(withAudio(save));
      await settleLobby(tester, 12);

      await tester.tap(find.byKey(const ValueKey('survival.continue')));
      await settleLobby(tester, 2);

      // Carried in by the core, as START's run is.
      expect(game(tester).paused, isTrue);
      expect(game(tester).entranceCoreHidden, isTrue);
      for (var ms = 0; ms < 4000 && lobbyShown(); ms += 33) {
        await tester.pump(const Duration(milliseconds: 33));
      }
      expect(lobbyShown(), isFalse);
      expect(find.text('WAVE 12'), findsOneWidget);
      final run = game(tester);
      expect(run.spawner.currentWave, 12);
      expect(run.party.map((m) => m.instanceId), kLobbyTeam);
      expect(run.powerUps.getGlobalStacks('pack_leader'), 1);
      expect(run.powerUps.getCompanionStacks(0, 'strength_up'), 1);
      expect(run.orb.maxHp, 800);
      expect(run.orb.currentHp, lessThanOrEqualTo(640));
      expect(run.activeCompanions.keys.toSet(), {0, 1});
      expect(run.stats.kills, greaterThanOrEqualTo(900));
      expect(run.upgradeState.equippedSkin, OrbBaseSkin.celestialOrb);

      // The core gives out on wave 12: eleven waves cleared, all of them
      // this run's. Each creature earns its own part — the two that were out
      // (kept as out, and summoned again on continuing) more than the three
      // kept in reserve — and each family is paid its creatures' sum.
      run.orb.currentHp = 0;
      final families = [
        for (final m in kept.party) creatureFamilyFromStorage(m.family)!,
      ];
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 33));
        if (i % 6 == 0) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        if (masteryEarned(save)[families.first] != before[families.first]) {
          break;
        }
      }
      await settleLobby(tester, 6);
      expect(run.deployedCompanionSlots, {0, 1});
      final creatures = [
        for (final (slot, family) in families.indexed)
          FamilyMasteryRunCreature(
            family: family,
            deployed: run.deployedCompanionSlots.contains(slot),
            damageDealt: run.companionRunStats[slot]?.damageDealt ?? 0,
            kills: run.companionRunStats[slot]?.kills ?? 0,
            healingDone: run.companionRunStats[slot]?.healingDone ?? 0,
          ),
      ];
      final awards = familyMasteryCreatureAwards(creatures, 11);
      final base = familyMasteryPointsForRun(11);
      // In reserve all run: an eighth of the base each.
      expect(awards.skip(2), everyElement((base * 0.125).round()));
      // Out: half a base each at least, a base each on average.
      expect(awards.take(2), everyElement(greaterThanOrEqualTo(base ~/ 2)));
      expect(awards[0] + awards[1], closeTo(2 * base, 1));
      final sums = familyMasteryFamilySums(creatures, awards);
      final earned = masteryEarned(save);
      for (final family in CreatureFamily.values) {
        expect(
          earned[family]! - before[family]!,
          sums[family] ?? 0,
          reason: family.name,
        );
      }
      expect(await savedRunRow(tester, save), isNull);

      // The results name what each creature earned under its family's row.
      for (var ms = 0; ms < 4000; ms += 33) {
        if (find.text('ORB DESTROYED').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 33));
      }
      final lines = find
          .byKey(const ValueKey('reward.breakdown'))
          .evaluate()
          .map((e) => (e.widget as Text).textSpan!.toPlainText())
          .toList();
      expect(lines, hasLength(families.toSet().length));
      for (final (i, m) in kept.party.indexed) {
        expect(
          lines,
          contains(contains('${m.displayName.toUpperCase()} +${awards[i]}')),
        );
      }
      tester.takeException();

      await save.dispose(tester);
    });
  });
}
