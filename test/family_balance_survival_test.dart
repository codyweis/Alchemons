@Tags(['preview'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/survival_mastery_runtime.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

import 'family_frame_trials.dart';

/// Which families carry a survival wave: parties of five families (no
/// Mystics unless FAMILY_MYSTIC, every set of five of the seven in turn,
/// elements drawn at random), jumped to one wave with the stat-wall benchmark's twenty picks
/// and its pilot (survival_stat_wall_report_test). For each family: its
/// share of its party's damage (a fifth is even), its share of the kills,
/// and how often a party with it held the wave against one without it.
/// Measures; does not judge. The battle's own table is
/// gem_battle_ladder_test 'species balance'.
///
///   FAMILY_WAVE=41 FAMILY_P=80 FAMILY_PARTIES=42 flutter test \
///     test/family_balance_survival_test.dart --tags preview
///
/// The benchmark's lifesteal goes to a different slot each party (on slot
/// 0 it was always the first family's), and the game steps at 60 frames a
/// second (FAMILY_FPS), as the phone does: at 30, fast darts pass through
/// small bodies between frames.
///
/// FAMILY_MASTERY=1 equips each family's path below, every node bought;
/// FAMILY_MASTERY=horn.bulwark,pip.salvo swaps those families' paths.
/// FAMILY_MASTERY_ONLY=1 equips only the paths FAMILY_MASTERY names, so one
/// path is measured against the same parties with no mastery anywhere else;
/// FAMILY_MASTERY_TIER=2 buys only each path's first two nodes.
/// With any mastery on, each family's line also gives the part of its damage
/// mastery dealt, and its healing and shielding per party.
///
/// FAMILY_ELEMENTS=Kin:Dark,Horn:Air gives every party those families'
/// species of that element, the rest of each party unchanged, so one
/// element can be measured in every party its family is in. FAMILY_SHIP=1
/// prints how long the ship was down, per party and overall.
///
/// FAMILY_MYSTIC=1 adds the Mystics as an eighth family: parties of five
/// from the eight, so a party holds one Mystic at most, as the game allows.
/// It also prints when each Mystic's world arrived, counted from the start
/// of the wave (FAMILY_ELEMENTS=Mystic:Lava forces one world). From a cold
/// start most Mystics fall before their world arrives, where in a run it
/// went up waves earlier: FAMILY_MYSTIC_LIT=1 has it go up as soon as the
/// wave is in reach, to measure what a world does once it is there.
const _families = ['Horn', 'Wing', 'Let', 'Pip', 'Mane', 'Mask', 'Kin'];

/// A strong path per family, for FAMILY_MASTERY.
const _masteryPaths = <CreatureFamily, String>{
  CreatureFamily.horn: 'horn.juggernaut',
  CreatureFamily.mane: 'mane.resonance',
  CreatureFamily.let: 'let.ground_zero',
  CreatureFamily.pip: 'pip.control',
  CreatureFamily.mask: 'mask.contagion',
  CreatureFamily.wing: 'wing.tracer',
  CreatureFamily.kin: 'kin.longline',
};

/// How far down each path FAMILY_MASTERY buys (FAMILY_MASTERY_TIER, 4 when
/// unset), so a path can be measured node by node.
final _masteryTier =
    int.tryParse(Platform.environment['FAMILY_MASTERY_TIER'] ?? '') ?? 4;

/// [party] with each one's family path fully bought, or null for none.
SurvivalFamilyMasterySnapshot? _masteryFor(List<CosmicPartyMember> party) {
  final raw = Platform.environment['FAMILY_MASTERY'];
  if (raw == null || raw.isEmpty) return null;
  final paths = Platform.environment['FAMILY_MASTERY_ONLY'] == '1'
      ? <CreatureFamily, String>{}
      : Map.of(_masteryPaths);
  if (raw != '1') {
    for (final id in raw.split(',')) {
      final fam = creatureFamilyFromStorage(id.split('.').first);
      if (fam != null) paths[fam] = id;
    }
  }
  return SurvivalFamilyMasterySnapshot({
    for (var i = 0; i < party.length; i++)
      if (creatureFamilyFromStorage(party[i].family) case final fam?)
        if (paths[fam] case final pathId?)
          i: EquippedFamilyMastery(
            instanceId: party[i].instanceId,
            family: fam,
            pathId: pathId,
            activeNodeIds: FamilyMasteryCatalog.pathFor(fam, pathId)!.nodes
                .where((n) => n.tier <= _masteryTier)
                .map((n) => n.id),
          ),
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final wave = int.tryParse(env['FAMILY_WAVE'] ?? '') ?? 41;
  final potential = int.tryParse(env['FAMILY_P'] ?? '') ?? 80;
  final enhancement = int.tryParse(env['FAMILY_E'] ?? '') ?? 0;
  final parties = int.tryParse(env['FAMILY_PARTIES'] ?? '') ?? 42;
  final families = env['FAMILY_MYSTIC'] == '1'
      ? [..._families, 'Mystic']
      : _families;
  final forcedElements = <String, String>{
    for (final entry in (env['FAMILY_ELEMENTS'] ?? '').split(','))
      if (entry.contains(':')) entry.split(':')[0]: entry.split(':')[1],
  };

  final rows =
      ((jsonDecode(
                    File(
                      'assets/data/alchemons_creatures.json',
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['creatures']
              as List)
          .cast<Map<String, dynamic>>()
          .where(
            (r) =>
                r['baseStats'] != null &&
                (r['types'] as List).isNotEmpty &&
                families.contains(r['mutationFamily']),
          )
          .toList();

  CosmicPartyMember member(Map<String, dynamic> row, int slot) {
    final base = row['baseStats'] as Map<String, dynamic>;
    double stat(String key) => AlchemonStatSystem.effectiveInternal(
      speciesBase: base[key] as int,
      level: 10,
      potential: potential,
      enhancementRank: enhancement,
    );
    return CosmicPartyMember(
      instanceId: 'fam_$slot',
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
      statSpeedPotential: potential.toDouble(),
      statIntelligencePotential: potential.toDouble(),
      statStrengthPotential: potential.toDouble(),
      statBeautyPotential: potential.toDouble(),
      staminaBars: 3,
      staminaMax: 3,
    );
  }

  // Every set of five of the seven (or of the eight, with the Mystics), in
  // the order of the families each one leaves out.
  final fives = <List<String>>[];
  void leaveOut(int from, List<int> out) {
    if (out.length == families.length - 5) {
      fives.add([
        for (var i = 0; i < families.length; i++)
          if (!out.contains(i)) families[i],
      ]);
      return;
    }
    for (var i = from; i < families.length; i++) {
      leaveOut(i + 1, [...out, i]);
    }
  }

  leaveOut(0, []);

  test('family balance in survival', () async {
    final tried = applyFamilyTrials();
    // FAMILY_VEIN=radius,power tries another Crystal Vein shard burst.
    final vein = env['FAMILY_VEIN']?.split(',').map(double.parse).toList();
    CosmicSurvivalGame.veinBurstRadiusTrial = vein?[0];
    CosmicSurvivalGame.veinBurstPowerTrial = vein?[1];
    final share = {for (final f in families) f: <double>[]};
    final killShare = {for (final f in families) f: <double>[]};
    final heldWith = {for (final f in families) f: 0};
    final with_ = {for (final f in families) f: 0};
    final heldWithout = {for (final f in families) f: 0};
    final without = {for (final f in families) f: 0};
    // Seconds into the wave each Mystic's world arrived, by element, and
    // the parties whose Mystic never lit one.
    final arrivals = <String, List<double>>{};
    var mysticParties = 0, unlit = 0;
    final species = <String, List<double>>{};
    // With mastery on: what mastery dealt of each family's damage, and its
    // healing and shielding, summed over the parties it was in.
    final masteryDealt = {for (final f in families) f: 0.0};
    final basicDealt = {for (final f in families) f: 0.0};
    final ownDealt = {for (final f in families) f: 0.0};
    final healed = {for (final f in families) f: 0.0};
    final shielded = {for (final f in families) f: 0.0};
    final capstones = {for (final f in families) f: 0};
    var held = 0, died = 0;
    var shipDown = 0.0;
    for (var p = 0; p < parties; p++) {
      final rng = Random(500 + p);
      final fams = fives[p % fives.length];
      final party = <CosmicPartyMember>[];
      for (final f in fams) {
        final pool = rows.where((r) => r['mutationFamily'] == f).toList();
        final drawn = pool[rng.nextInt(pool.length)];
        final forced = forcedElements[f];
        party.add(
          member(
            forced == null
                ? drawn
                : pool.firstWhere(
                    (r) => (r['types'] as List).first == forced,
                    orElse: () => drawn,
                  ),
            party.length,
          ),
        );
      }
      final (ok, damage, kills) = await _hold(
        party,
        wave,
        7 + p,
        lifestealSlot: p % party.length,
        fps: int.tryParse(env['FAMILY_FPS'] ?? '') ?? 60,
      );
      if (ok) held++;
      if (_lastDied) died++;
      for (final m in party.where((m) => m.family == 'Mystic')) {
        mysticParties++;
        final at = _lastMysticArrival;
        if (at == null) {
          unlit++;
        } else {
          arrivals.putIfAbsent(m.element, () => []).add(at);
        }
      }
      shipDown += _lastShipDown;
      if (env['FAMILY_SHIP'] != null) {
        // ignore: avoid_print
        print('party $p ship down ${(100 * _lastShipDown).round()}%');
      }
      final total = damage.fold(0.0, (s, d) => s + d);
      final totalKills = kills.fold(0, (s, k) => s + k);
      for (var i = 0; i < party.length && i < _lastTelemetry.length; i++) {
        final f = party[i].family;
        final t = _lastTelemetry[i];
        masteryDealt[f] = masteryDealt[f]! + t.masteryDamage;
        basicDealt[f] = basicDealt[f]! + t.basicDamage;
        // What it removed in all, whichever bucket mastery filed it under:
        // a special that lands through a shared helper files as neither.
        ownDealt[f] = ownDealt[f]! + damage[i];
        healed[f] = healed[f]! + _lastHealing[i];
        shielded[f] = shielded[f]! + t.shielding;
        capstones[f] = capstones[f]! + t.capstoneActivations;
      }
      for (var i = 0; i < party.length; i++) {
        final f = party[i].family;
        final s = total > 0 ? damage[i] / total : 0.0;
        share[f]!.add(s);
        killShare[f]!.add(totalKills > 0 ? kills[i] / totalKills : 0);
        species
            .putIfAbsent('${party[i].element} $f', () => [])
            .add(s);
      }
      for (final f in families) {
        if (fams.contains(f)) {
          with_[f] = with_[f]! + 1;
          if (ok) heldWith[f] = heldWith[f]! + 1;
        } else {
          without[f] = without[f]! + 1;
          if (ok) heldWithout[f] = heldWithout[f]! + 1;
        }
      }
      if (env['FAMILY_PARTY_LINES'] != null) {
        // ignore: avoid_print
        print(
        'party $p ${ok ? 'HELD' : 'fell'} ${_lastElapsed.round()}s'
        '${_lastMysticArrival == null ? '' : ' (world ${_lastMysticArrival!.round()}s)'}  '
        '${[for (var i = 0; i < party.length; i++) '${party[i].element} ${party[i].family} ${(100 * damage[i] / max(1, total)).round()}%'].join(' · ')}',
        );
      }
    }
    double mean(List<double> v) =>
        v.isEmpty ? 0 : v.fold(0.0, (s, x) => s + x) / v.length;
    // ignore: avoid_print
    print(
      'P$potential${enhancement > 0 ? 'e$enhancement' : ''} wave $wave: '
      '$held of $parties held, $died died, ${parties - held - died} ran out '
      'of time${tried.isEmpty ? '' : '  (tried $tried)'}',
    );
    if (env['FAMILY_SHIP'] != null) {
      // ignore: avoid_print
      print('ship down ${(100 * shipDown / parties).round()}% of the time');
    }
    // FAMILY_SPECIES=1: every family's elements, best to worst share.
    if (env['FAMILY_SPECIES'] != null) {
      for (final f in families) {
        final keys = species.keys.where((k) => k.endsWith(' $f')).toList()
          ..sort((a, b) => mean(species[b]!).compareTo(mean(species[a]!)));
        // ignore: avoid_print
        print(
          '  $f: ${[for (final k in keys) '${k.split(' ').first} ${(100 * mean(species[k]!)).round()}%(${species[k]!.length})'].join(' ')}',
        );
      }
    }
    if (mysticParties > 0) {
      final all = arrivals.values.expand((v) => v).toList();
      // ignore: avoid_print
      print(
        'Mystic world arrived at ${mean(all).toStringAsFixed(1)} s on average '
        '(${all.length} of $mysticParties lit; $unlit never lit)  '
        '${[for (final e in arrivals.keys.toList()..sort()) '$e ${mean(arrivals[e]!).toStringAsFixed(0)}s'].join(' ')}',
      );
    }
    final order = List.of(families)
      ..sort((a, b) => mean(share[b]!).compareTo(mean(share[a]!)));
    final masteryOn = (env['FAMILY_MASTERY'] ?? '').isNotEmpty;
    for (final f in order) {
      String rate(int n, int of) => of == 0 ? '—' : '${(100 * n / of).round()}%';
      final n = max(1, with_[f]!);
      // ignore: avoid_print
      print(
        '${f.padRight(5)} damage ${(100 * mean(share[f]!)).round()}%  '
        'kills ${(100 * mean(killShare[f]!)).round()}%  '
        'held with ${rate(heldWith[f]!, with_[f]!)} · '
        'without ${rate(heldWithout[f]!, without[f]!)}  '
        'basic ${ownDealt[f]! <= 0 ? 0 : (100 * basicDealt[f]! / ownDealt[f]!).round()}%'
        '${!masteryOn ? '' : '  mastery ${ownDealt[f]! <= 0 ? 0 : (100 * masteryDealt[f]! / ownDealt[f]!).round()}% of its damage · '
                  'heal ${(healed[f]! / n).round()} · shield ${(shielded[f]! / n).round()} · '
                  'capstones ${(capstones[f]! / n).toStringAsFixed(1)} a party'}',
      );
    }
  }, timeout: const Timeout(Duration(hours: 3)));
}

/// Whether the last [_hold] ended with the orb lost (else held or out of
/// time).
var _lastDied = false;

/// The share of the last [_hold] the ship spent down.
var _lastShipDown = 0.0;

/// Seconds into the last [_hold] its Mystic's world arrived, or null.
double? _lastMysticArrival;

/// How long the last [_hold] ran, in game seconds.
var _lastElapsed = 0.0;

/// Each slot's mastery telemetry and healing from the last [_hold].
var _lastTelemetry = <MasterySlotTelemetry>[];
var _lastHealing = <double>[];

/// [party] at [wave] from a cold start, as the stat-wall report plays it:
/// whether it held, and each one's damage and kills.
Future<(bool, List<double>, List<int>)> _hold(
  List<CosmicPartyMember> party,
  int wave,
  int seed, {
  int lifestealSlot = 0,
  int fps = 60,
}) async {
  final game = CosmicSurvivalGame(
    party: party,
    random: Random(seed),
    onGameOver: () {},
    masterySnapshot: _masteryFor(party),
  );
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();
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
  pick('lifesteal', slot: lifestealSlot);
  for (var i = 0; i < 2; i++) {
    pick('auto_turret');
    pick('regen_field');
  }
  pick('mirror_shield');
  pick('command_strength');
  pick('command_intelligence');
  pick('command_speed');
  game.startGame();
  for (var w = 1; w < wave; w++) {
    game.spawner.resumeAfterIntermission();
  }
  for (var i = 0; i < party.length; i++) {
    game.summonCompanion(i);
  }
  game.clearCompanionTether();
  if (Platform.environment['FAMILY_MYSTIC_LIT'] == '1') {
    for (var i = 0; i < party.length; i++) {
      if (party[i].family == 'Mystic') {
        game.activeCompanions[i]?.specialCooldown = 0;
      }
    }
  }

  var elapsed = 0.0;
  var shipDown = 0.0;
  _lastMysticArrival = null;
  final mysticSlot = party.indexWhere((m) => m.family == 'Mystic');
  while (!game.isGameOver &&
      game.spawner.currentWave == wave &&
      elapsed < 300) {
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
    target ??= game.activeBoss?.position ?? game.orb.position;
    final delta = target - game.ship.position;
    final tangent = delta.distance > 0
        ? Offset(-delta.dy, delta.dx) / delta.distance
        : Offset.zero;
    game.setJoystickInput(
      delta.distance > 170 ? delta / delta.distance : tangent,
    );
    if (game.showingPowerUpSelection) {
      game.alchemicalMeter = 0;
      game.dismissPowerUpSelection();
    }
    game.update(1 / fps);
    elapsed += 1 / fps;
    if (game.ship.isDead) shipDown += 1 / fps;
    if (mysticSlot >= 0 &&
        _lastMysticArrival == null &&
        game.isMysticFieldSpent(mysticSlot)) {
      _lastMysticArrival = elapsed;
    }
  }
  _lastShipDown = elapsed > 0 ? shipDown / elapsed : 0;
  _lastElapsed = elapsed;
  _lastTelemetry = [
    for (var i = 0; i < party.length; i++) game.mastery.telemetryFor(i),
  ];
  _lastHealing = [
    for (var i = 0; i < party.length; i++)
      game.companionRunStats[i]?.healingDone ?? 0,
  ];
  final ok = !game.isGameOver && game.spawner.currentWave > wave;
  _lastDied = game.isGameOver;
  return (
    ok,
    [
      for (var i = 0; i < party.length; i++)
        game.companionRunStats[i]?.damageDealt.toDouble() ?? 0,
    ],
    [
      for (var i = 0; i < party.length; i++)
        game.companionRunStats[i]?.kills ?? 0,
    ],
  );
}
