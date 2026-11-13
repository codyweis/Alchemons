// What survival's bosses are called, and how they and the party move.
//
// A boss is named for what it is (it was labelled with the open-space
// creature its numbers came from: an egg of strands read "Infernal Wyrm"),
// each boss wave is one thing, and each moves as that thing would: the
// Drift flows one way round the core, the Spire stands. The party keeps off
// the core's glass, and a Let stands to throw.

import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/enemy_body_art.dart';
import 'package:alchemons/games/cosmic_survival/boss_roster_art.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

CosmicPartyMember _member(String family, String element, int slot) =>
    CosmicPartyMember(
      instanceId: '$family-$element-$slot',
      baseId: '${family.substring(0, 3).toUpperCase()}01',
      displayName: '$element $family',
      family: family,
      element: element,
      level: 10,
      slotIndex: slot,
      statSpeed: 3,
      statIntelligence: 3,
      statStrength: 3,
      statBeauty: 3,
      staminaBars: 5,
      staminaMax: 5,
    );

Future<CosmicSurvivalGame> _run(
  List<CosmicPartyMember> party,
  int wave, {
  bool untilBoss = false,
}) async {
  final game = CosmicSurvivalGame(
    party: party,
    random: Random(11),
    onGameOver: () {},
  );
  game.onGameResize(Vector2(412, 915));
  await game.onLoad();
  game.startGame();
  final packLeader = kRarePerks.firstWhere((d) => d.id == 'pack_leader');
  for (var i = 1; i < party.length; i++) {
    game.powerUps.apply(packLeader);
  }
  game.spawner.currentWave = wave - 1;
  game.spawner.resumeAfterIntermission();
  if (untilBoss) {
    for (var f = 0; f < 60 * 20 && game.activeBoss == null; f++) {
      _step(game);
    }
  }
  for (final m in party) {
    game.summonCompanion(m.slotIndex);
  }
  game.clearCompanionTether();
  return game;
}

void _step(CosmicSurvivalGame game) {
  game.alchemicalMeter = 0;
  if (game.showingPowerUpSelection) game.dismissPowerUpSelection();
  game.isGameOver = false;
  game.orb.currentHp = game.orb.maxHp;
  game.ship.currentHp = game.ship.maxHp.toDouble();
  for (final c in game.activeCompanions.values) {
    c.currentHp = c.maxHp;
  }
  for (final b in game.allLivingBosses) {
    b.hp = b.maxHp;
  }
  game.update(1 / 60);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('each boss wave is one thing, named for what it is', () {
    const names = {
      5: 'The Unhatched',
      10: 'The Armillary',
      15: 'The Eclipse',
      20: 'The Pair',
      25: 'The Cage',
      30: 'The Spire',
      35: 'The Drift',
    };
    for (var seed = 0; seed < 12; seed++) {
      final spawner = CosmicSurvivalSpawner(random: Random(seed));
      for (final entry in names.entries) {
        final boss = spawner.createBossForWave(entry.key, Offset.zero)!;
        expect(survivalBossName(boss), entry.value, reason: 'wave ${entry.key}');
        expect(
          kBossTemplates.map((t) => t.name),
          isNot(contains(survivalBossName(boss))),
        );
      }
      // Whatever type its numbers came from, the wave-10 boss is the
      // Armillary and the wave-30 boss the Spire.
      expect(
        survivalBossForm(spawner.createBossForWave(10, Offset.zero)!),
        BossForm.armillary,
      );
      expect(
        survivalBossForm(spawner.createBossForWave(30, Offset.zero)!),
        BossForm.spire,
      );
    }
  });

  test('the Drift flows one way round the core, in and out', () async {
    final game = await _run([_member('Mane', 'Fire', 0)], 35, untilBoss: true);
    final boss = game.activeBoss!;
    expect(survivalBossKindOf(boss), SurvivalBossKind.drift);
    while (boss.isSpawning) {
      _step(game);
    }
    for (var f = 0; f < 60 * 6; f++) {
      _step(game);
    }
    var last = atan2(
      boss.position.dy - game.orb.position.dy,
      boss.position.dx - game.orb.position.dx,
    );
    var forward = 0, back = 0;
    var nearest = double.infinity, farthest = 0.0;
    for (var f = 0; f < 60 * 40; f++) {
      _step(game);
      final off = boss.position - game.orb.position;
      final a = atan2(off.dy, off.dx);
      final turned = atan2(sin(a - last), cos(a - last));
      last = a;
      if (turned > 0) forward++;
      if (turned < 0) back++;
      nearest = min(nearest, off.distance);
      farthest = max(farthest, off.distance);
    }
    game.onRemove();
    // One way the whole time, whichever way that is.
    expect(min(forward, back), 0, reason: '$forward forward, $back back');
    // And it draws in and lets out: its ring is not one circle.
    expect(farthest - nearest, greaterThan(150));
    expect(nearest, greaterThan(220));
  });

  test('the Spire walks up to the core and stands', () async {
    final game = await _run([_member('Mane', 'Fire', 0)], 30, untilBoss: true);
    final boss = game.activeBoss!;
    expect(survivalBossName(boss), 'The Spire');
    while (boss.isSpawning) {
      _step(game);
    }
    for (var f = 0; f < 60 * 8; f++) {
      _step(game);
    }
    final from = boss.position;
    for (var f = 0; f < 60 * 5; f++) {
      _step(game);
    }
    final off = (boss.position - game.orb.position).distance;
    game.onRemove();
    // It has not gone 60 units in five seconds (it shuffled 30 a second).
    expect((boss.position - from).distance, lessThan(60));
    // Beside the core, its body off the core's glass.
    expect(off, greaterThan(86 + boss.radius));
    expect(off, lessThan(86 + boss.radius + 80));
  });

  test('a Wing comes in off the rim for a boss at the core', () async {
    final game = await _run([_member('Wing', 'Air', 0)], 30, untilBoss: true);
    final boss = game.activeBoss!;
    final wing = game.activeCompanions[0]!;
    while (boss.isSpawning) {
      _step(game);
    }
    var frames = 0, inReach = 0;
    for (var f = 0; f < 60 * 40; f++) {
      // Only the boss to fight: what it calls is put down as it comes.
      for (final e in game.enemies) {
        e.isDead = true;
      }
      _step(game);
      if (f < 60 * 15) continue; // the flight in from the rim
      frames++;
      final off = (wing.position - boss.position).distance;
      if (off <= wing.attackRange + boss.radius + 80) inReach++;
    }
    final fromCore = (wing.position - game.orb.position).distance;
    game.onRemove();
    // It was in reach of a boss at the core for a twentieth of the fight,
    // parked on its ring 740 out.
    expect(inReach / frames, greaterThan(0.8));
    expect(fromCore, lessThan(700));
  });

  test('the Eclipse shows where it will open before it does', () async {
    final game = await _run([_member('Mane', 'Fire', 0)], 15, untilBoss: true);
    final boss = game.activeBoss!;
    expect(survivalBossName(boss), 'The Eclipse');
    while (boss.isSpawning) {
      _step(game);
    }
    var blinks = 0;
    var shownFor = 0;
    Offset? shown;
    for (var f = 0; f < 60 * 40; f++) {
      final before = boss.position;
      final telling = boss.blinkTo;
      _step(game);
      if ((boss.position - before).distance > 90) {
        blinks++;
        // It had been showing the spot, for most of a second, and that is
        // where it opened.
        expect(telling, isNotNull);
        expect((boss.position - telling!).distance, lessThan(1));
        expect(shownFor, greaterThan(40));
        shownFor = 0;
        shown = null;
      } else if (telling != null) {
        if (shown != telling) {
          shown = telling;
          shownFor = 0;
        }
        shownFor++;
      }
    }
    game.onRemove();
    expect(blinks, greaterThan(2));
  });

  test('nobody stands on the core, and a Let stands to throw', () async {
    final game = await _run([
      _member('Horn', 'Fire', 0),
      _member('Kin', 'Water', 1),
      _member('Let', 'Earth', 2),
      _member('Pip', 'Air', 3),
      _member('Mystic', 'Ice', 4),
    ], 26);
    for (var f = 0; f < 60 * 4; f++) {
      _step(game);
    }
    var frames = 0, onGlass = 0, letStill = 0, letFrames = 0;
    Offset? letLast;
    for (var f = 0; f < 60 * 40; f++) {
      _step(game);
      frames++;
      for (final c in game.activeCompanions.values) {
        if (c.isDead) continue;
        // A horn's charge goes where it goes.
        if (c.chargeTimer > 0) continue;
        // The core's glass is 86 from its centre, and a creature's own
        // body some 30 or more: its centre keeps a body's width off it.
        if ((c.position - game.orb.position).distance < 86 + 14) onGlass++;
        if (c.member.family == 'Let') {
          if (letLast != null) {
            letFrames++;
            if ((c.position - letLast).distance < 0.2) letStill++;
          }
          letLast = c.position;
        }
      }
    }
    game.onRemove();
    // ignore: avoid_print
    print(
      'on the glass $onGlass of ${frames * 5} creature-frames; '
      'Let standing ${(100 * letStill / letFrames).round()}% of the time',
    );
    expect(onGlass / (frames * 5), lessThan(0.01));
    // In a thick wave it stands more than it walks (it never stood).
    expect(letStill / letFrames, greaterThan(0.4));
  });
}
