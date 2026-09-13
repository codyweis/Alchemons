@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A reporting harness for survival balance. Measures; does not judge.
///
/// Every previous conversation about whether survival is too easy has been an
/// argument about impressions. This prints numbers instead: how much healing a
/// run actually does against how much damage it actually takes, how much of a
/// run the orb spends untouched at full health, where the damage comes from,
/// and how the enemy curve scales against the party's.
///
/// Tagged `preview` — it is a report, not a gate, and it is slow.
///
///   flutter test test/survival_balance_audit_test.dart --tags preview
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<CosmicPartyMember> party(int potential) {
    final data =
        jsonDecode(
              File('assets/data/alchemons_creatures.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final creatures = (data['creatures'] as List).cast<Map<String, dynamic>>();
    const ids = ['PIP01', 'HOR02', 'MAN04', 'MSK12', 'LET02'];
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
            instanceId: 'audit_$i',
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

  /// One run, autopiloted, reporting what actually happened to it.
  Future<
    ({
      int wave,
      double seconds,
      int kills,
      double orbLost,
      double shipLost,
      double healOrb,
      double healShip,
      double healMons,
      double orbRegained,
      double shipRegained,
      int shipDeaths,
      double fullOrbFraction,
      bool died,
    })
  >
  runAudit({
    required int potential,
    required int seed,
    required int startWave,
    required double seconds,
    bool takePowerUps = true,
  }) async {
    final game = CosmicSurvivalGame(
      party: party(potential),
      random: Random(seed),
      onGameOver: () {},
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();

    if (takePowerUps) {
      void pick(String id, {int? slot}) => game.applyPowerUp(
        kAllPowerUps.firstWhere((def) => def.id == id),
        targetSlot: slot,
      );
      for (var i = 0; i < 4; i++) {
        pick('pack_leader');
      }
      for (var i = 0; i < 5; i++) {
        pick('strength_up', slot: i);
      }
      pick('orb_vitality');
      pick('orb_vitality');
      pick('lifesteal', slot: 0);
      for (var i = 0; i < 2; i++) {
        pick('auto_turret');
        pick('regen_field');
      }
      pick('mirror_shield');
      pick('command_strength');
      pick('command_intelligence');
      pick('command_speed');
    }

    game.startGame();
    for (var wave = 1; wave < startWave; wave++) {
      game.spawner.resumeAfterIntermission();
    }
    for (var i = 0; i < 5; i++) {
      game.summonCompanion(i);
    }
    game.clearCompanionTether();

    var orbLost = 0.0;
    var shipLost = 0.0;
    // Gross HP REGAINED, read the same way as damage taken.
    //
    // healingStats cannot answer this question on its own: regen_field heals
    // the orb by assigning orb.currentHp directly rather than going through
    // _healOrb, so it never reaches those counters — and at two picks it is
    // 4 HP a second, which over a five-minute run is more healing than the
    // orb takes damage before wave 30. Measuring the HP bar itself catches
    // every source whether or not it bothered to report.
    var orbRegained = 0.0;
    var shipRegained = 0.0;
    // Respawns are not healing. A destroyed ship comes back at half health,
    // which the HP bar reports as a large sudden gain — counted as healing it
    // would make a run that keeps losing its ship look like a run with
    // enormous sustain, which is the opposite of the truth.
    var shipDeaths = 0;
    var shipWasDead = false;
    var fullOrbFrames = 0.0;
    var frames = 0.0;
    var prevOrb = game.orb.currentHp;
    var prevShip = game.ship.currentHp;
    const step = 1 / 60;

    while (!game.isGameOver && game.stats.timeElapsed < seconds) {
      // Same simple legal pilot the wave-50 harness uses: guard the orb, purge
      // sources, otherwise close on whatever is nearest.
      Offset? target;
      var best = double.infinity;
      for (final enemy in game.enemies) {
        if (enemy.isDead) continue;
        final orbDistance = (enemy.position - game.orb.position).distance;
        final score = !enemy.isPlagueCore && orbDistance < 300
            ? orbDistance - 2000
            : enemy.isPlagueCore
            ? -1000.0
            : orbDistance;
        if (score < best) {
          best = score;
          target = enemy.position;
        }
      }
      if (target != null) {
        final to = target - game.ship.position;
        final d = to.distance;
        if (d > 1) game.setJoystickInput(to / d);
      }
      if (game.showingPowerUpSelection) {
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }

      game.update(step);
      frames += 1;

      // Damage taken read from HP falling, so no game code has to carry a
      // counter for it. Healing is already tracked exactly, by recipient.
      final orbNow = game.orb.currentHp;
      final shipNow = game.ship.currentHp;
      if (orbNow < prevOrb) {
        orbLost += prevOrb - orbNow;
      } else if (orbNow > prevOrb) {
        orbRegained += orbNow - prevOrb;
      }
      final respawned = shipWasDead && !game.ship.isDead;
      if (game.ship.isDead && !shipWasDead) shipDeaths++;
      shipWasDead = game.ship.isDead;
      if (shipNow < prevShip) {
        shipLost += prevShip - shipNow;
      } else if (shipNow > prevShip && !respawned) {
        shipRegained += shipNow - prevShip;
      }
      prevOrb = orbNow;
      prevShip = shipNow;
      if (orbNow >= game.orb.maxHp - 0.001) fullOrbFrames += 1;
    }

    return (
      wave: game.spawner.currentWave,
      seconds: game.stats.timeElapsed,
      kills: game.stats.kills,
      orbLost: orbLost,
      shipLost: shipLost,
      healOrb: game.healingStats.toOrb,
      healShip: game.healingStats.toShip,
      healMons: game.healingStats.toMons,
      orbRegained: orbRegained,
      shipRegained: shipRegained,
      shipDeaths: shipDeaths,
      fullOrbFraction: frames == 0 ? 0.0 : fullOrbFrames / frames,
      died: game.isGameOver,
    );
  }

  test('healing against damage taken, across the curve', () async {
    // ignore: avoid_print
    print('BALANCE ─ healing vs damage taken (5-minute runs, 80 potential)');
    // ignore: avoid_print
    print(
      'wave  seed  reached  kills  orbLost  orbBack  shipLost  shipBack  '
      'reported  unreported  back/lost  orbAtFull  shipDied  died',
    );
    for (final startWave in [1, 15, 30, 50]) {
      for (final seed in [11, 29]) {
        final r = await runAudit(
          potential: 80,
          seed: seed,
          startWave: startWave,
          seconds: 300,
        );
        final taken = r.orbLost + r.shipLost;
        final back = r.orbRegained + r.shipRegained;
        final reported = r.healOrb + r.healShip;
        // What the HP bars gained that no healing counter claimed. Anything
        // large here is healing the game itself cannot see or attribute.
        final unreported = back - reported;
        final ratio = taken <= 0 ? double.infinity : back / taken;
        // ignore: avoid_print
        print(
          '${startWave.toString().padLeft(4)}  '
          '${seed.toString().padLeft(4)}  '
          '${r.wave.toString().padLeft(7)}  '
          '${r.kills.toString().padLeft(5)}  '
          '${r.orbLost.round().toString().padLeft(7)}  '
          '${r.orbRegained.round().toString().padLeft(7)}  '
          '${r.shipLost.round().toString().padLeft(8)}  '
          '${r.shipRegained.round().toString().padLeft(8)}  '
          '${reported.round().toString().padLeft(8)}  '
          '${unreported.round().toString().padLeft(10)}  '
          '${ratio.isFinite ? ratio.toStringAsFixed(2).padLeft(9) : "      inf"}  '
          '${(r.fullOrbFraction * 100).round().toString().padLeft(8)}%  '
          '${r.shipDeaths.toString().padLeft(8)}  '
          '${r.died ? "DIED" : "-"}',
        );
      }
    }
  }, timeout: const Timeout(Duration(minutes: 30)));

  test('the enemy curve, straight from the balance table', () {
    // No simulation needed: these are pure functions of the wave number, and
    // they are the other half of any balance conversation. A party curve that
    // outruns this one is what "too easy" actually means.
    // ignore: avoid_print
    print('BALANCE \u2500 enemy scaling by wave');
    // ignore: avoid_print
    print('wave   hpScale  dmgScale  spdScale  bossHp   meterCap');
    for (final wave in [1, 5, 10, 20, 30, 40, 50, 65, 80]) {
      // ignore: avoid_print
      print(
        '${wave.toString().padLeft(4)}  '
        '${CosmicSurvivalBalance.enemyWaveHpScale(wave).toStringAsFixed(2).padLeft(8)}  '
        '${CosmicSurvivalBalance.enemyWaveDamageScale(wave).toStringAsFixed(2).padLeft(8)}  '
        '${CosmicSurvivalBalance.enemyWaveSpeedScale(wave).toStringAsFixed(2).padLeft(8)}  '
        '${CosmicSurvivalBalance.bossHealthForWave(wave, titanic: false).round().toString().padLeft(6)}  '
        '${CosmicSurvivalBalance.alchemicalMeterCapacity(wave).round().toString().padLeft(8)}',
      );
    }

    // And what the enemy curve looks like relative to itself: how much harder
    // wave N is than wave 1, on each axis.
    // ignore: avoid_print
    print('BALANCE \u2500 wave 50 vs wave 1: '
        'hp x${(CosmicSurvivalBalance.enemyWaveHpScale(50)).toStringAsFixed(1)}, '
        'dmg x${(CosmicSurvivalBalance.enemyWaveDamageScale(50)).toStringAsFixed(1)}, '
        'speed x${(CosmicSurvivalBalance.enemyWaveSpeedScale(50)).toStringAsFixed(2)}');
  });

  test('what every ability heals, per cast', () {
    // The healing riders the ability table hands out, for a representative
    // cast. These are the numbers to argue about when someone says healing is
    // too strong — a run-level total mixes them with the ship's free respawns
    // and tells you nothing about which ability to touch.
    //
    // Note what the survival side then does with them: _healLowestAllyOrShip
    // pays the target AND 45% of it to the orb, and _healAllCompanionsAndShip
    // pays the ship and EVERY companion the full amount plus 35% to the orb —
    // 6.35x the nominal figure with a five-strong party.
    const damage = 40.0;
    // ignore: avoid_print
    print('BALANCE \u2500 ability healing riders (damage=$damage, level 10)');
    // ignore: avoid_print
    print('family   element    selfHeal  shipHeal  blessT  blessPerTick  perSec');
    for (final family in [
      'horn',
      'wing',
      'let',
      'pip',
      'mane',
      'mask',
      'kin',
      'mystic',
    ]) {
      for (final element in kCosmicAbilityElements) {
        final r = createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: family,
          element: element,
          damage: damage,
          maxHp: 120,
          casterPower: 5,
          casterBeauty: 5,
          casterIntelligence: 5,
          casterStrength: 5,
          targetPos: const Offset(120, 0),
        );
        if (r.selfHeal == 0 &&
            r.shipHeal == 0 &&
            r.blessingHealPerTick == 0) {
          continue;
        }
        // What the blessing ACTUALLY pays out per second once survival applies
        // it: the tick is rounded to a whole number every frame, so anything
        // under 30 a second rounds to zero and anything over pays 60.
        final perFrame = (r.blessingHealPerTick / 60).round();
        final perSec = perFrame * 60;
        // ignore: avoid_print
        print(
          '${family.padRight(8)} ${element.padRight(10)} '
          '${r.selfHeal.toString().padLeft(8)}  '
          '${r.shipHeal.toString().padLeft(8)}  '
          '${r.blessingTimer.toStringAsFixed(1).padLeft(6)}  '
          '${r.blessingHealPerTick.toStringAsFixed(2).padLeft(12)}  '
          '${perSec.toString().padLeft(6)}',
        );
      }
    }
  });

  test('what every family element casts, and where the outliers are', () {
    // Output per cast for all eight families across all seventeen elements.
    // Nothing here decides what is correct — it makes the spread visible, so
    // an ability that is twice its family's normal can be argued about on
    // purpose instead of discovered by a player.
    const damage = 40.0;
    final rows =
        <({
          String family,
          String element,
          int count,
          double dmg,
          double dps,
        })>[];
    for (final family in [
      'horn',
      'wing',
      'let',
      'pip',
      'mane',
      'mask',
      'kin',
      'mystic',
    ]) {
      for (final element in kCosmicAbilityElements) {
        final r = createCosmicSpecialAbility(
          origin: Offset.zero,
          baseAngle: 0,
          family: family,
          element: element,
          damage: damage,
          maxHp: 120,
          casterPower: 5,
          casterBeauty: 5,
          casterIntelligence: 5,
          casterStrength: 5,
          targetPos: const Offset(120, 0),
        );
        final total = r.projectiles.fold<double>(0, (a, p) => a + p.damage);
        // Damage per cast means little without the cadence behind it. The
        // family multipliers alone span 0.88 to 1.90, so two families with the
        // same payload can be more than twice apart in what they actually put
        // out over a fight.
        final familyMultiplier = switch (family) {
          'let' => 1.18,
          'pip' => 0.92,
          'mane' => 0.88,
          'mask' => 1.05,
          'mystic' => 1.90,
          _ => 1.0,
        };
        final cooldown =
            15.0 *
            familyMultiplier *
            elementalSpecialCooldownMultiplier(family, element);
        rows.add((
          family: family,
          element: element,
          count: r.projectiles.length,
          dmg: total,
          dps: cooldown <= 0 ? 0.0 : total / cooldown,
        ));
      }
    }

    // ignore: avoid_print
    print('BALANCE \u2500 cast payload by family (damage=$damage)');
    // ignore: avoid_print
    print('family   casts  medianDmg  minDmg(element)      maxDmg(element)      spread');
    for (final family in [
      'horn',
      'wing',
      'let',
      'pip',
      'mane',
      'mask',
      'kin',
      'mystic',
    ]) {
      final fam = rows.where((r) => r.family == family).toList()
        ..sort((a, b) => a.dmg.compareTo(b.dmg));
      final withPayload = fam.where((r) => r.dmg > 0).toList();
      if (withPayload.isEmpty) {
        // ignore: avoid_print
        print('${family.padRight(8)} ${fam.length.toString().padLeft(5)}  '
            '(no projectile payload \u2014 passive or world family)');
        continue;
      }
      final median = withPayload[withPayload.length ~/ 2].dmg;
      final lo = withPayload.first;
      final hi = withPayload.last;
      final byDps = [...withPayload]..sort((a, b) => a.dps.compareTo(b.dps));
      final medianDps = byDps[byDps.length ~/ 2].dps;
      // ignore: avoid_print
      print(
        '${family.padRight(8)} '
        '${withPayload.length.toString().padLeft(5)}  '
        '${median.round().toString().padLeft(9)}  '
        '${lo.dmg.round().toString().padLeft(6)} (${lo.element.padRight(9)})  '
        '${hi.dmg.round().toString().padLeft(6)} (${hi.element.padRight(9)})  '
        'x${(hi.dmg / max(1.0, lo.dmg)).toStringAsFixed(1)}  '
        'dps~${medianDps.toStringAsFixed(1)}',
      );
    }

    // And the elements that sit furthest from their own family's median, which
    // is where a balance conversation actually starts.
    // ignore: avoid_print
    print('BALANCE \u2500 furthest from family median');
    final flagged = <String>[];
    for (final family in [
      'horn',
      'wing',
      'let',
      'pip',
      'mane',
      'mask',
      'kin',
      'mystic',
    ]) {
      final withPayload =
          rows.where((r) => r.family == family && r.dmg > 0).toList()
            ..sort((a, b) => a.dmg.compareTo(b.dmg));
      if (withPayload.length < 3) continue;
      final median = withPayload[withPayload.length ~/ 2].dmg;
      for (final r in withPayload) {
        final ratio = r.dmg / median;
        if (ratio >= 2.0 || ratio <= 0.5) {
          flagged.add(
            '${r.family}/${r.element}: ${r.dmg.round()} vs median '
            '${median.round()} (x${ratio.toStringAsFixed(1)})',
          );
        }
      }
    }
    for (final f in flagged) {
      // ignore: avoid_print
      print('  $f');
    }
    // ignore: avoid_print
    print('  ${flagged.length} of ${rows.length} casts sit outside half-to-double '
        'their family median');
  });
}
