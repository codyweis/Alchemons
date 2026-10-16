// The results' DAMAGE section: who carried a survival run. A real headless
// run's per-creature tally (the one Family Mastery pays from) has to reach
// the panel's data unchanged and add up — every creature's damage plus the
// ship's and the orb's is everything the run dealt — and survive a SAVE &
// EXIT and CONTINUE.
//
//   flutter test test/survival_damage_report_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/cosmic_survival_game_over_panel.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/survival_damage_report.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Five level-12 creatures of five families; the last is kept in reserve.
List<CosmicPartyMember> _party() {
  final data =
      jsonDecode(
            File('assets/data/alchemons_creatures.json').readAsStringSync(),
          )
          as Map<String, dynamic>;
  final creatures = (data['creatures'] as List).cast<Map<String, dynamic>>();
  const ids = ['PIP01', 'HOR02', 'MAN04', 'KIN02', 'LET02'];
  return [
    for (var i = 0; i < ids.length; i++)
      (() {
        final row = creatures.firstWhere((c) => c['id'] == ids[i]);
        final base = row['baseStats'] as Map<String, dynamic>;
        double stat(String key) => AlchemonStatSystem.effectiveInternal(
          speciesBase: base[key] as int,
          level: 12,
          potential: 60,
        );
        return CosmicPartyMember(
          instanceId: 'dmg_$i',
          baseId: ids[i],
          displayName: row['name'] as String,
          imagePath: 'assets/images/${row['image']}',
          family: row['mutationFamily'] as String,
          element: (row['types'] as List).first as String,
          level: 12,
          slotIndex: i,
          statSpeed: stat('speed'),
          statIntelligence: stat('intelligence'),
          statStrength: stat('strength'),
          statBeauty: stat('beauty'),
          staminaBars: 3,
          staminaMax: 3,
        );
      })(),
  ];
}

CosmicSurvivalGame _game({
  List<CosmicPartyMember>? party,
  void Function(CosmicSurvivalGame)? onCheckpoint,
}) {
  late final CosmicSurvivalGame game;
  game = CosmicSurvivalGame(
    party: party ?? _party(),
    random: Random(17),
    onGameOver: () {},
    upgradeState: SurvivalUpgradeState(
      equippedSkin: OrbBaseSkin.celestialOrb,
      guardianLevels: {
        GuardianUpgrade.attack: 2,
        GuardianUpgrade.defense: 2,
        GuardianUpgrade.cooldown: 1,
        GuardianUpgrade.range: 0,
      },
    ),
    onWaveCheckpoint: onCheckpoint == null ? null : () => onCheckpoint(game),
  );
  game.onGameResize(Vector2(900, 700));
  return game;
}

/// Plays [seconds] of the run, nobody allowed to fall and no draft left
/// open, so the clock and the fight both run the whole time.
void _play(CosmicSurvivalGame game, double seconds) {
  final until = game.stats.timeElapsed + seconds;
  while (game.stats.timeElapsed < until) {
    if (game.showingPowerUpSelection) {
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
    game.update(1 / 60);
    game.orb.currentHp = game.orb.maxHp;
    game.ship
      ..currentHp = game.ship.maxHp
      ..isDead = false;
    for (final comp in game.activeCompanions.values) {
      comp
        ..isDead = false
        ..currentHp = comp.maxHp;
    }
  }
}

void main() {
  group('SurvivalDamageReport from a real run', () {
    late CosmicSurvivalGame game;
    late SurvivalDamageReport report;

    /// How long each slot was out, as the run's clock saw it.
    final outFor = <int, double>{};

    setUpAll(() async {
      game = _game();
      await game.onLoad();
      game.startGame();
      game.clearCompanionTether();
      // One out at a time, as a run starts: three swapped in turn, the last
      // two kept in reserve.
      for (final (slot, seconds) in const [(0, 16.0), (1, 14.0), (2, 10.0)]) {
        game.summonCompanion(slot);
        final at = game.stats.timeElapsed;
        _play(game, seconds);
        outFor[slot] = game.stats.timeElapsed - at;
      }
      report = SurvivalDamageReport.fromGame(game);
    });

    test('every party member has a line, carrying its own tally', () {
      expect(report.lines, hasLength(5));
      expect(report.lines.map((l) => l.slot).toSet(), {0, 1, 2, 3, 4});
      for (final line in report.lines) {
        final s = game.companionRunStats[line.slot];
        final member = game.party[line.slot];
        expect(line.name, member.displayName);
        expect(line.element, member.element);
        expect(line.imagePath, member.imagePath);
        expect(line.damage, s?.damageDealt ?? 0);
        expect(line.kills, s?.kills ?? 0);
        expect(line.healing, s?.healingDone ?? 0);
      }
      // A real fight: the party did the work, more than one of them.
      expect(report.lines.where((l) => l.damage > 0).length, greaterThan(1));
    });

    test('lines run from most damage to least, the best first', () {
      for (var i = 1; i < report.lines.length; i++) {
        expect(
          report.lines[i - 1].damage,
          greaterThanOrEqualTo(report.lines[i].damage),
        );
      }
      expect(report.best, same(report.lines.first));
      expect(report.best!.damage, greaterThan(0));
    });

    test('the shares add up to everything the run dealt', () {
      final creatures = report.lines.fold<double>(0, (s, l) => s + l.damage);
      expect(report.totalDamage, closeTo(creatures + report.otherDamage, 1e-6));
      expect(report.otherDamage, game.stats.otherDamage);
      final shares =
          report.lines.fold<double>(0, (s, l) => s + report.shareOf(l.damage)) +
          report.shareOf(report.otherDamage);
      expect(shares, closeTo(1, 1e-9));
      // Kills likewise: the party's and the rest's make the run's.
      final kills = report.lines.fold<int>(0, (s, l) => s + l.kills);
      expect(kills + report.otherKills, game.stats.kills);
    });

    test('damage no Alchemon dealt lands in the other line', () {
      final before = game.stats.otherDamage;
      final shipBefore = game.stats.shipDamage;
      final enemy = game.enemies.firstWhere((e) => !e.isDead && e.hp > 10);
      game.debugShipAttackDamage(enemy, 5);
      expect(game.stats.otherDamage, closeTo(before + 5, 1e-6));
      final after = SurvivalDamageReport.fromGame(game);
      expect(after.otherDamage, closeTo(report.otherDamage + 5, 1e-6));
      // The ship's own row takes it; the orb's keeps what it had.
      expect(game.stats.shipDamage, closeTo(shipBefore + 5, 1e-6));
      expect(after.shipDamage, closeTo(report.shipDamage + 5, 1e-6));
      expect(after.orbDamage, closeTo(report.orbDamage, 1e-6));
    });

    test('time on the field runs on the run clock; the reserve is benched', () {
      for (final line in report.lines) {
        final out = outFor[line.slot];
        if (out == null) {
          expect(line.deployed, isFalse, reason: 'slot ${line.slot}');
          expect(line.fieldSeconds, 0);
          expect(line.damage, 0);
          expect(line.kills, 0);
        } else {
          expect(line.deployed, isTrue, reason: 'slot ${line.slot}');
          // Never let fall: out exactly as long as it was sent out for.
          expect(line.fieldSeconds, closeTo(out, 0.05));
        }
      }
      // One out at a time: the field time between them is the run's.
      final field = report.lines.fold<double>(0, (s, l) => s + l.fieldSeconds);
      expect(field, closeTo(game.stats.timeElapsed, 0.05));
    });
  });

  test('field time and the other line survive SAVE & EXIT', () async {
    final game = _game();
    await game.onLoad();
    game.startGame();
    game.summonCompanion(0);
    game.summonCompanion(2);
    _play(game, 12);
    final kept = game.captureSuspendedRun();
    final decoded = SuspendedSurvivalRun.tryDecode(jsonEncode(kept.toJson()));
    expect(decoded, isNotNull);
    expect(decoded!.otherDamage, game.stats.otherDamage);
    expect(decoded.shipDamage, game.stats.shipDamage);
    expect(decoded.shipKills, game.stats.shipKills);

    final resumed = CosmicSurvivalGame(
      party: decoded.party,
      random: Random(3),
      onGameOver: () {},
      upgradeState: decoded.upgradeState,
      masterySnapshot: decoded.mastery,
      shipSkin: decoded.shipSkin,
    )..onGameResize(Vector2(900, 700));
    await resumed.onLoad();
    resumed.resumeRun(decoded);
    final before = SurvivalDamageReport.fromGame(game);
    final after = SurvivalDamageReport.fromGame(resumed);
    expect(after.otherDamage, before.otherDamage);
    for (final line in before.lines) {
      final again = after.lines.firstWhere((l) => l.slot == line.slot);
      expect(again.fieldSeconds, line.fieldSeconds);
      expect(again.damage, line.damage);
      expect(again.deployed, line.deployed);
    }
  });

  test('a save from before field time was kept reads as none', () {
    final legacy = SuspendedSlotStats.fromJson({
      'slot': 1,
      'dealt': 10,
      'kills': 2,
      'taken': 3,
      'healed': 0,
    });
    expect(legacy.fieldSeconds, 0);
  });

  test('amounts and clocks read short', () {
    expect(compactAmount(0), '0');
    expect(compactAmount(940.4), '940');
    expect(compactAmount(999.6), '1K');
    expect(compactAmount(12430), '12.4K');
    expect(compactAmount(99960), '100K');
    expect(compactAmount(124300), '124K');
    expect(compactAmount(3140000), '3.1M');
    expect(compactAmount(9000), '9K');
    expect(fieldClock(0), '00:00');
    expect(fieldClock(372.9), '06:12');
    expect(fieldClock(3849), '1:04:09');
  });

  group('the results panel', () {
    const report = SurvivalDamageReport(
      lines: [
        SurvivalDamageLine(
          slot: 1,
          name: 'Waterhorn',
          element: 'Water',
          damage: 48200,
          kills: 610,
          healing: 0,
          deployed: true,
          fieldSeconds: 724,
        ),
        SurvivalDamageLine(
          slot: 3,
          name: 'Waterkin',
          element: 'Water',
          damage: 9000,
          kills: 40,
          healing: 2100,
          deployed: true,
          fieldSeconds: 600,
        ),
        SurvivalDamageLine(
          slot: 4,
          name: 'Waterlet',
          element: 'Water',
          damage: 0,
          kills: 0,
          healing: 0,
          deployed: false,
          fieldSeconds: 0,
        ),
      ],
      otherDamage: 4000,
      otherKills: 12,
      shipDamage: 2500,
      shipKills: 8,
    );

    Future<void> pump(WidgetTester tester, Size logical) async {
      tester.view.physicalSize = logical * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CosmicSurvivalGameOverPanel(
            wave: 12,
            kills: 662,
            score: 98230,
            time: '12:04',
            rewards: const [],
            damage: report,
            onQuit: () {},
            onNewTeam: () {},
            onReplay: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    }

    testWidgets('shows who carried it, best first', (tester) async {
      await pump(tester, const Size(475, 751));
      expect(find.text('DAMAGE'), findsOneWidget);
      expect(find.text('61.2K TOTAL'), findsOneWidget);
      expect(find.text('WATERHORN'), findsOneWidget);
      expect(find.text('48.2K'), findsOneWidget);
      expect(find.text('79%'), findsOneWidget);
      expect(find.text('BENCHED'), findsOneWidget);
      // The ship gets a row of its own, then the orb's defenses and perks.
      expect(find.text('SHIP'), findsOneWidget);
      expect(find.text('ORB AND PERKS'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('SHIP')).dy,
        lessThan(tester.getTopLeft(find.text('ORB AND PERKS')).dy),
      );
      // Healing only where it healed.
      expect(find.textContaining('HEALED'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('WATERHORN')).dy,
        lessThan(tester.getTopLeft(find.text('WATERKIN')).dy),
      );
    });

    testWidgets('fits the folded Fold, the way out on screen', (tester) async {
      await pump(tester, const Size(344, 751));
      expect(find.text('WATERHORN'), findsOneWidget);
      final out = tester.getRect(find.text('DEPLOY AGAIN'));
      expect(out.bottom, lessThanOrEqualTo(751));
    });

    testWidgets('no section without a report', (tester) async {
      tester.view.physicalSize = const Size(950, 1502);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: CosmicSurvivalGameOverPanel(
            wave: 1,
            kills: 0,
            score: 0,
            time: '00:10',
            rewards: const [],
            onQuit: () {},
            onNewTeam: () {},
            onReplay: () {},
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(find.byKey(const ValueKey('survival.damage')), findsNothing);
    });
  });
}
