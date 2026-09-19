@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/shared/enemy_movement.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Family role scorecard: does each family do the job its theme promises
/// against a horde? Measures; does not judge.
///
/// One companion at a time (real species stats, level 10, potential 60), in
/// the real game, against four scripted wave-20 problems. Each scenario is
/// also run with no companion, so "prevented" is measurable.
///
///   ROLE_OUT=docs/horde_stress flutter test \
///     test/survival_family_role_scorecard_test.dart --tags preview
///
/// ROLE_FAMILIES=Mane,Horn narrows the families; ROLE_ELEMENTS=Fire,Water the
/// elements.
enum RoleScenario { tide, artillery, brood, siege, flank }

const _kWave = 20;
const _kSeconds = 30.0;
const _kDt = 1 / 30;

const _kFamilies = {
  'Mane': 'MAN',
  'Horn': 'HOR',
  'Kin': 'KIN',
  'Mask': 'MSK',
  'Wing': 'WNG',
  'Pip': 'PIP',
  'Let': 'LET',
  'Mystic': 'MYS',
};

class RoleResult {
  RoleResult(this.family, this.element, this.scenario);
  final String family;
  final String element;
  final RoleScenario scenario;
  int kills = 0;
  int targetKills = 0; // sentinels / phantoms, per scenario
  int targetCount = 0;
  double heavyShare = 0; // share of brute/colossus HP removed
  double orbDamage = 0;

  /// Healing that landed on the orb. The orb is held at or above 40% rather
  /// than reset to full every frame, so a heal has somewhere to go; the net
  /// column is what the companion actually saved.
  double orbHealed = 0;
  double get orbNet => orbDamage - orbHealed;
  double shipDamage = 0;
  double healing = 0;
  double companionDamageTaken = 0;

  /// Body-seconds spent inside 300 units of the orb: how much of the wave got
  /// through, weighted by how long it stayed there.
  double leakSeconds = 0;
  int companionDeaths = 0;

  /// When the last scripted body died, or the scenario length if any survived.
  double clearedAt = 0;

  Map<String, Object> toJson() => {
    'family': family,
    'element': element,
    'scenario': scenario.name,
    'kills': kills,
    'targetKills': targetKills,
    'targetCount': targetCount,
    'heavyShare': heavyShare,
    'orbDamage': orbDamage,
    'orbHealed': orbHealed,
    'orbNet': orbNet,
    'shipDamage': shipDamage,
    'healing': healing,
    'companionDamageTaken': companionDamageTaken,
    'leakSeconds': leakSeconds,
    'companionDeaths': companionDeaths,
    'clearedAt': clearedAt,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['ROLE_OUT'];
  final familyFilter = Platform.environment['ROLE_FAMILIES']?.split(',');
  final elementFilter = Platform.environment['ROLE_ELEMENTS']?.split(',');

  final creatures =
      ((jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List)
          .cast<Map<String, dynamic>>();

  CosmicPartyMember member(Map<String, dynamic> row) {
    final base = row['baseStats'] as Map<String, dynamic>;
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int,
      level: 10,
      potential: 60,
    );
    return CosmicPartyMember(
      instanceId: 'role_${row['id']}',
      baseId: row['id'] as String,
      displayName: row['name'] as String,
      family: row['mutationFamily'] as String,
      element: (row['types'] as List).first as String,
      level: 10,
      slotIndex: 0,
      statSpeed: stat('speed'),
      statIntelligence: stat('intelligence'),
      statStrength: stat('strength'),
      statBeauty: stat('beauty'),
      statSpeedPotential: 60,
      statIntelligencePotential: 60,
      statStrengthPotential: 60,
      statBeautyPotential: 60,
      staminaBars: 3,
      staminaMax: 3,
    );
  }

  CosmicSurvivalEnemy body(
    EnemyTier tier,
    Offset at, {
    required EnemyConduct conduct,
    CosmicEnemyTarget target = CosmicEnemyTarget.orb,
    EnemyTrait? trait,
    bool chaff = false,
    required String element,
  }) {
    final hp =
        tierBaseHp(tier) *
        CosmicSurvivalBalance.enemyWaveHpScale(_kWave) *
        (chaff ? 0.65 : 1.0);
    return CosmicSurvivalEnemy(
      position: at,
      hp: hp,
      maxHp: hp,
      speed:
          tierBaseSpeed(tier) *
          CosmicSurvivalBalance.enemyWaveSpeedScale(_kWave) *
          (chaff ? CosmicSurvivalBalance.hordeBodySpeedMultiplier : 1.0),
      damage:
          tierBaseDamage(tier) *
          CosmicSurvivalBalance.enemyWaveDamageScale(_kWave) *
          (chaff ? 0.55 : 1.0),
      radius: tierRadius(tier),
      tier: tier,
      element: element,
      conduct: conduct,
      target: target,
      trait: trait,
    );
  }

  const elementsCycle = [
    'Fire', 'Water', 'Earth', 'Air', 'Plant', 'Dark', 'Light', 'Ice', //
  ];

  List<CosmicSurvivalEnemy> scenarioBodies(
    RoleScenario scenario,
    Offset orb,
    double rim,
    Random rng,
  ) {
    Offset polar(double angle, double r) =>
        orb + Offset(cos(angle), sin(angle)) * r;
    String el(int i) => elementsCycle[i % elementsCycle.length];
    final bodies = <CosmicSurvivalEnemy>[];
    switch (scenario) {
      case RoleScenario.tide:
        // Three fronts from beyond the rim, with the spawner's escape gap.
        const gap = pi / 3;
        const span = (2 * pi - gap) / 3;
        for (var i = 0; i < 480; i++) {
          final front = i % 3;
          final along = (i ~/ 3 % 40) / 39;
          final depth = (i ~/ 120) * 26.0 + rng.nextDouble() * 14;
          bodies.add(
            body(
              rng.nextDouble() < 0.7 ? EnemyTier.wisp : EnemyTier.drone,
              polar(
                gap / 2 + front * span + along * span * 0.78,
                rim + 70 + depth,
              ),
              conduct: EnemyConduct.charge,
              chaff: true,
              element: el(i),
            ),
          );
        }
      case RoleScenario.artillery:
        // Siege guns holding past companion reach, screened by chaff.
        for (var i = 0; i < 30; i++) {
          bodies.add(
            body(
              EnemyTier.sentinel,
              polar(i * 2 * pi / 30, kSiegeHoldRange + 40),
              conduct: EnemyConduct.siege,
              element: el(i),
            ),
          );
        }
        for (var i = 0; i < 120; i++) {
          bodies.add(
            body(
              EnemyTier.wisp,
              polar(rng.nextDouble() * 2 * pi, rim + 70),
              conduct: EnemyConduct.charge,
              chaff: true,
              element: el(i),
            ),
          );
        }
      case RoleScenario.brood:
        // Broodmothers walking in, each replacing the front behind it.
        for (var i = 0; i < 6; i++) {
          bodies.add(
            body(
              EnemyTier.brute,
              polar(i * 2 * pi / 6, rim - 120),
              conduct: EnemyConduct.charge,
              trait: EnemyTrait.summoner,
              element: el(i),
            ),
          );
        }
        for (var i = 0; i < 90; i++) {
          bodies.add(
            body(
              EnemyTier.wisp,
              polar(rng.nextDouble() * 2 * pi, rim + 70),
              conduct: EnemyConduct.charge,
              chaff: true,
              element: el(i),
            ),
          );
        }
      case RoleScenario.siege:
        // Heavy breakers walking at the orb from two sides.
        for (var i = 0; i < 8; i++) {
          final heavy = i < 6 ? EnemyTier.brute : EnemyTier.colossus;
          bodies.add(
            body(
              heavy,
              polar((i.isEven ? 0.0 : pi) + (i ~/ 2) * 0.22, rim - 60),
              conduct: EnemyConduct.charge,
              trait: EnemyTrait.breaker,
              element: el(i),
            ),
          );
        }
      case RoleScenario.flank:
        // Blinkers already inside, hunting the ship and the orb.
        for (var i = 0; i < 24; i++) {
          bodies.add(
            body(
              EnemyTier.phantom,
              polar(rng.nextDouble() * 2 * pi, 480 + rng.nextDouble() * 220),
              conduct: EnemyConduct.stalk,
              target: i.isEven ? CosmicEnemyTarget.ship : CosmicEnemyTarget.orb,
              element: el(i),
            ),
          );
        }
    }
    return bodies;
  }

  Future<RoleResult> run(
    Map<String, dynamic>? row,
    RoleScenario scenario,
  ) async {
    final m = row == null ? null : member(row);
    final result = RoleResult(m?.family ?? 'none', m?.element ?? '-', scenario);
    final game = CosmicSurvivalGame(
      party: m == null ? [] : [m],
      random: Random(11),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    if (m != null) {
      game.summonCompanion(0);
      game.clearCompanionTether();
      // Every scenario opens with the special ready: a Mystic's cadence is
      // longer than the scenario, and the question is what the cast DOES.
      game.activeCompanions[0]?.specialCooldown = 0;
    }
    game.enemies.clear();
    final ours = scenarioBodies(
      scenario,
      game.orb.position,
      game.debugArenaRadius,
      Random(scenario.index * 97 + 5),
    );
    game.enemies.addAll(ours);
    final mine = Set<CosmicSurvivalEnemy>.identity()..addAll(ours);
    final heavy = ours
        .where((e) => e.tier == EnemyTier.brute || e.tier == EnemyTier.colossus)
        .toList();
    final heavyMax = heavy.fold<double>(0, (a, e) => a + e.maxHp);
    final targetTier = switch (scenario) {
      RoleScenario.artillery => EnemyTier.sentinel,
      RoleScenario.flank => EnemyTier.phantom,
      RoleScenario.brood => EnemyTier.brute,
      _ => null,
    };
    result.targetCount = targetTier == null
        ? 0
        : ours.where((e) => e.tier == targetTier).length;

    final frames = (_kSeconds / _kDt).round();
    for (var f = 0; f < frames; f++) {
      game.alchemicalMeter = 0;
      game.showingPowerUpSelection = false;
      game.gamePaused = false;
      game.spawner.isBossWave = false;
      final orbBefore = game.orb.currentHp;
      final shipBefore = game.ship.currentHp;
      final comp = game.activeCompanions[0];
      final compBefore = comp?.currentHp;
      game.update(_kDt);
      result.orbDamage += max(0.0, orbBefore - game.orb.currentHp);
      result.shipDamage += max(0.0, shipBefore - game.ship.currentHp);
      if (comp != null && compBefore != null) {
        result.companionDamageTaken += max(0, compBefore - comp.currentHp);
      }
      // A companion that falls is part of the answer: revive it, but count it.
      if (comp != null && comp.isDead) {
        result.companionDeaths++;
        game.returnCompanion(0);
        game.summonCompanion(0);
        game.clearCompanionTether();
        game.activeCompanions[0]?.currentHp = comp.maxHp;
      }
      // Keep both alive without erasing the damage: a full reset every frame
      // left heals nothing to heal, so a support companion read as zero.
      if (game.orb.currentHp < game.orb.maxHp * 0.4) {
        game.orb.currentHp = game.orb.maxHp;
      }
      if (game.ship.currentHp < game.ship.maxHp * 0.3) {
        game.ship.currentHp = game.ship.maxHp.toDouble();
      }
      // A volley can take the orb from the floor to nothing inside one frame,
      // and a finished game stops updating.
      game.isGameOver = false;
      // Only the scripted bodies (and whatever they split/summon into) fight.
      game.enemies.removeWhere((e) => !mine.contains(e) && !e.isDead);
      game.activeBoss = null;
      game.extraBosses.clear();
      var near = 0;
      var alive = 0;
      for (final e in ours) {
        if (e.isDead) continue;
        alive++;
        if ((e.position - game.orb.position).distance <= 300) near++;
      }
      result.leakSeconds += near * _kDt;
      if (alive > 0) result.clearedAt = (f + 1) * _kDt;
    }

    result.kills = ours.where((e) => e.isDead).length;
    if (targetTier != null) {
      result.targetKills = ours
          .where((e) => e.tier == targetTier && e.isDead)
          .length;
    }
    if (heavyMax > 0) {
      final left = heavy.fold<double>(0, (a, e) => a + max(0.0, e.hp));
      result.heavyShare = 1 - left / heavyMax;
    }
    result.healing = game.healingStats.total;
    result.orbHealed = game.healingStats.toOrb;
    game.onRemove();
    return result;
  }

  testWidgets('family role scorecard', (tester) async {
    final results = <RoleResult>[];
    final baseline = <RoleScenario, RoleResult>{};
    for (final scenario in RoleScenario.values) {
      baseline[scenario] = await run(null, scenario);
    }
    for (final entry in _kFamilies.entries) {
      if (familyFilter != null && !familyFilter.contains(entry.key)) {
        continue;
      }
      final rows = creatures.where(
        (c) => (c['id'] as String).startsWith(entry.value),
      );
      final seen = <String>{};
      for (final row in rows) {
        final element = (row['types'] as List).first as String;
        if (!seen.add(element)) continue; // MSK18 duplicates Blood
        if (elementFilter != null && !elementFilter.contains(element)) {
          continue;
        }
        for (final scenario in RoleScenario.values) {
          results.add(await run(row, scenario));
        }
      }
    }

    // Family averages per scenario.
    final buffer = StringBuffer()
      ..writeln('# Family role scorecard (wave $_kWave, ${_kSeconds}s)')
      ..writeln()
      ..writeln(
        'One companion, level 10, potential 60, special ready at the start. '
        '"Orb dmg" is damage the orb took, "Orb healed" what the companion '
        'put back, "Orb net" the difference; baseline is the ship alone. '
        'Elements are ranked on the net. '
        'Generated by test/survival_family_role_scorecard_test.dart.',
      )
      ..writeln();
    String f1(double v) => v.toStringAsFixed(v.abs() >= 100 ? 0 : 1);
    for (final scenario in RoleScenario.values) {
      final base = baseline[scenario]!;
      buffer
        ..writeln('## ${scenario.name}')
        ..writeln()
        ..writeln(switch (scenario) {
          RoleScenario.tide =>
            '480 slow chaff in three fronts from beyond the rim.',
          RoleScenario.brood =>
            '6 broodmothers walking in behind 90 chaff, each replacing the '
                'front until it is cut out.',
          RoleScenario.artillery =>
            '30 siege guns holding past companion reach, 120 chaff.',
          RoleScenario.siege =>
            '6 brutes + 2 colossi, breakers, walking at the orb.',
          RoleScenario.flank =>
            '24 phantoms already inside, hunting ship and orb.',
        })
        ..writeln()
        ..writeln(
          '| Family | Orb dmg | Orb healed | Orb net | Leak body-s | '
          'Target kills | Heavy HP removed | Ship dmg | Cleared at | '
          'Healing | Deaths | Best element | Worst element |',
        )
        ..writeln(
          '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | '
          '--- | --- | --- |',
        )
        ..writeln(
          '| *(ship alone)* | ${f1(base.orbDamage)} | '
          '${f1(base.orbHealed)} | ${f1(base.orbNet)} | '
          '${f1(base.leakSeconds)} | '
          '${base.targetKills}/${base.targetCount} | '
          '${(base.heavyShare * 100).toStringAsFixed(0)}% | '
          '${f1(base.shipDamage)} | ${f1(base.clearedAt)}s | - | - | - | '
          '- |',
        );
      for (final family in _kFamilies.keys) {
        final rs = results
            .where((r) => r.family == family && r.scenario == scenario)
            .toList();
        if (rs.isEmpty) continue;
        double avg(double Function(RoleResult) f) =>
            rs.fold<double>(0, (a, r) => a + f(r)) / rs.length;
        // Rank elements by what this scenario asks for.
        double merit(RoleResult r) => switch (scenario) {
          RoleScenario.tide => -r.orbNet - r.leakSeconds * 2,
          RoleScenario.artillery =>
            r.targetKills * 40 - r.shipDamage - r.orbNet,
          RoleScenario.brood => r.targetKills * 60 - r.orbNet - r.leakSeconds,
          RoleScenario.siege => r.heavyShare * 4000 - r.orbNet,
          RoleScenario.flank => -(r.orbNet + r.shipDamage),
        };
        final ranked = [...rs]..sort((a, b) => merit(b).compareTo(merit(a)));
        buffer.writeln(
          '| $family | ${f1(avg((r) => r.orbDamage))} | '
          '${f1(avg((r) => r.orbHealed))} | ${f1(avg((r) => r.orbNet))} | '
          '${f1(avg((r) => r.leakSeconds))} | '
          '${f1(avg((r) => r.targetKills.toDouble()))}'
          '${rs.first.targetCount > 0 ? '/${rs.first.targetCount}' : ''} | '
          '${(avg((r) => r.heavyShare) * 100).toStringAsFixed(0)}% | '
          '${f1(avg((r) => r.shipDamage))} | '
          '${f1(avg((r) => r.clearedAt))}s | '
          '${f1(avg((r) => r.healing))} | '
          '${f1(avg((r) => r.companionDeaths.toDouble()))} | '
          '${ranked.first.element} | ${ranked.last.element} |',
        );
      }
      buffer.writeln();
    }
    // ignore: avoid_print
    print(buffer);
    if (out != null) {
      Directory(out).createSync(recursive: true);
      File('$out/role_scorecard.md').writeAsStringSync(buffer.toString());
      File('$out/role_scorecard.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'baseline': [for (final b in baseline.values) b.toJson()],
          'results': [for (final r in results) r.toJson()],
        }),
      );
    }
  }, timeout: const Timeout(Duration(minutes: 40)));
}
