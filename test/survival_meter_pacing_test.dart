@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

/// Meter pacing: how often does the upgrade draft open?
///
/// A real five-companion party (Mane, Kin, Mystic, Wing, Mask at level 10,
/// potential 60) plays real waves for two minutes from several starting
/// waves. The orb and ship are kept alive so income is not cut short, and
/// every surge is counted and dismissed the way a pick would dismiss it.
///
/// The number that matters is surges per cleared wave. The design target is
/// about one: the draft is a per-wave rhythm, not an interruption every
/// 8-15 s (which is what horde-sized waves did to the pre-horde meter, see
/// docs/horde_stress/README.md round 6).
///
///   METER_OUT=docs/horde_stress flutter test \
///     test/survival_meter_pacing_test.dart --tags preview
const _kSeconds = 120.0;
const _kDt = 1 / 30;
const _kStartWaves = [6, 12, 20, 30];
const _kPartyPrefixes = ['MAN', 'KIN', 'MYS', 'WNG', 'MSK'];

class PacingResult {
  PacingResult(this.startWave);
  final int startWave;
  int surges = 0;
  int wavesCleared = 0;
  int kills = 0;
  double orbDamage = 0;
  final List<int> surgesPerWave = [];
  int _surgesThisWave = 0;

  double get surgesPerClearedWave =>
      wavesCleared == 0 ? double.nan : surges / wavesCleared;
  double get secondsPerWave =>
      wavesCleared == 0 ? double.nan : _kSeconds / wavesCleared;

  Map<String, Object> toJson() => {
    'startWave': startWave,
    'surges': surges,
    'wavesCleared': wavesCleared,
    'kills': kills,
    'orbDamage': orbDamage,
    'surgesPerWave': surgesPerWave,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final out = Platform.environment['METER_OUT'];

  final creatures =
      ((jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List)
          .cast<Map<String, dynamic>>();

  CosmicPartyMember member(Map<String, dynamic> row, int slot) {
    final base = row['baseStats'] as Map<String, dynamic>;
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int,
      level: 10,
      potential: 60,
    );
    return CosmicPartyMember(
      instanceId: 'pace_${row['id']}',
      baseId: row['id'] as String,
      displayName: row['name'] as String,
      family: row['mutationFamily'] as String,
      element: (row['types'] as List).first as String,
      level: 10,
      slotIndex: slot,
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

  Future<PacingResult> run(int startWave) async {
    final result = PacingResult(startWave);
    final party = <CosmicPartyMember>[];
    for (var i = 0; i < _kPartyPrefixes.length; i++) {
      final row = creatures.firstWhere(
        (c) => (c['id'] as String).startsWith(_kPartyPrefixes[i]),
      );
      party.add(member(row, i));
    }
    final game = CosmicSurvivalGame(
      party: party,
      random: Random(5 + startWave),
      onGameOver: () {},
      onWaveCleared: (_) {
        result.wavesCleared++;
        result.surgesPerWave.add(result._surgesThisWave);
        result._surgesThisWave = 0;
      },
    );
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    final packLeader = kRarePerks.firstWhere((d) => d.id == 'pack_leader');
    for (var i = 1; i < party.length; i++) {
      game.powerUps.apply(packLeader);
    }
    for (final m in party) {
      game.summonCompanion(m.slotIndex);
    }
    for (var w = 1; w < startWave; w++) {
      game.spawner.forceNextWaveForTest();
    }

    final frames = (_kSeconds / _kDt).round();
    for (var f = 0; f < frames; f++) {
      final orbBefore = game.orb.currentHp;
      game.update(_kDt);
      result.orbDamage += max(0.0, orbBefore - game.orb.currentHp);
      if (game.showingPowerUpSelection) {
        result.surges++;
        result._surgesThisWave++;
        // What a pick does to the meter, without choosing an upgrade: the
        // party's power stays fixed so the measurement is of the meter alone.
        game.alchemicalMeter = 0;
        game.dismissPowerUpSelection();
      }
      // Income stops when the ship is down and the run ends when the orb is,
      // so both are kept up. The floor rather than a full reset lets heals
      // land, which matters for nothing here but keeps the game honest.
      if (game.orb.currentHp < game.orb.maxHp * 0.4) {
        game.orb.currentHp = game.orb.maxHp;
      }
      game.ship.currentHp = game.ship.maxHp.toDouble();
      game.isGameOver = false;
    }
    result.kills = game.stats.kills;
    game.onRemove();
    return result;
  }

  testWidgets('the upgrade draft opens about once a wave', (tester) async {
    final results = <PacingResult>[];
    for (final w in _kStartWaves) {
      results.add(await run(w));
    }
    final buffer = StringBuffer()
      ..writeln('# Meter pacing (five companions, ${_kSeconds.round()} s)')
      ..writeln()
      ..writeln(
        'Party A (Mane, Kin, Mystic, Wing, Mask), level 10, potential 60, '
        'orb and ship kept alive, every surge dismissed without a pick. '
        'Generated by test/survival_meter_pacing_test.dart.',
      )
      ..writeln()
      ..writeln(
        '| From wave | Surges | Waves cleared | Surges per wave | '
        'Seconds per wave | Kills | Orb damage | Per-wave surges |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- |');
    for (final r in results) {
      buffer.writeln(
        '| ${r.startWave} | ${r.surges} | ${r.wavesCleared} | '
        '${r.surgesPerClearedWave.toStringAsFixed(2)} | '
        '${r.secondsPerWave.toStringAsFixed(0)} | ${r.kills} | '
        '${r.orbDamage.toStringAsFixed(0)} | ${r.surgesPerWave.join(' ')} |',
      );
    }
    // ignore: avoid_print
    print(buffer);
    if (out != null) {
      Directory(out).createSync(recursive: true);
      File('$out/meter_pacing.md').writeAsStringSync(buffer.toString());
      File('$out/meter_pacing.json').writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final r in results) r.toJson()]),
      );
    }
    for (final r in results) {
      expect(
        r.wavesCleared,
        greaterThan(0),
        reason: 'from wave ${r.startWave} nothing was cleared in two minutes',
      );
      // One a wave is the target; boss waves and pattern multipliers spread
      // it, so the band is generous. Below it the draft is a rare event,
      // above it the game is pausing more than it plays.
      expect(
        r.surgesPerClearedWave,
        inInclusiveRange(0.5, 1.8),
        reason:
            'from wave ${r.startWave}: ${r.surges} surges over '
            '${r.wavesCleared} waves',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}
