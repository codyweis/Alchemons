import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/survival_outbreak.dart';
import 'package:alchemons/games/shared/enemy_taxonomy.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

class _Pick implements Random {
  _Pick(this.index);
  final int index;
  @override
  int nextInt(int max) => index % max;
  @override
  double nextDouble() => 0.5;
  @override
  bool nextBool() => true;
}

SurvivalOutbreak eventFor(SurvivalOutbreakKind kind, {int wave = 20}) =>
    SurvivalOutbreak.forWave(
      wave,
      Offset.zero,
      1140,
      random: _Pick(kind.index),
    )!;

CosmicSurvivalEnemy enemyAt(Offset position) => CosmicSurvivalEnemy(
  position: position,
  hp: 40,
  maxHp: 100,
  speed: 0,
  damage: 0,
  radius: 10,
  tier: EnemyTier.wisp,
  element: 'Fire',
  conduct: EnemyConduct.drift,
  target: CosmicEnemyTarget.orb,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('only milestones spawn; every milestone can roll all ten outbreaks', () {
    for (var wave = 1; wave <= 60; wave++) {
      for (final kind in SurvivalOutbreakKind.values) {
        final event = SurvivalOutbreak.forWave(
          wave,
          Offset.zero,
          1140,
          random: _Pick(kind.index),
        );
        if ([20, 30, 40, 50].contains(wave)) {
          expect(event!.kind, kind);
          expect(event.cores.length, inInclusiveRange(1, 3));
          expect(
            event.cores.every((core) => core.isPlagueCore && core.speed == 0),
            isTrue,
          );
        } else {
          expect(event, isNull);
        }
      }
    }
  });

  test('random selection excludes the previous outbreak', () {
    final rng = Random(124);
    SurvivalOutbreakKind? previous;
    final seen = <SurvivalOutbreakKind>{};
    for (var i = 0; i < 100; i++) {
      final event = SurvivalOutbreak.forWave(
        20,
        Offset.zero,
        1140,
        random: rng,
        previous: previous,
      )!;
      expect(event.kind, isNot(previous));
      seen.add(event.kind);
      previous = event.kind;
    }
    expect(seen.length, 10);
  });

  test(
    'warning precedes pulse; destroying sources stops the clock and fields',
    () {
      final event = eventFor(SurvivalOutbreakKind.verdigris);
      expect(event.advance(8.5), isFalse);
      expect(event.warning, isTrue);
      expect(event.advance(1.5), isTrue);
      expect(event.surging, isTrue);
      expect(event.advance(0.01), isFalse);
      for (final core in event.cores) {
        core.isDead = true;
      }
      final time = event.elapsed;
      expect(event.advance(100), isFalse);
      expect(event.elapsed, time);
      expect(event.warning, isFalse);
      expect(event.surging, isFalse);
      expect(
        event.contains(event.cores.first, event.cores.first.position),
        isFalse,
      );
    },
  );

  test(
    'field protection stops per source and never shields the source itself',
    () {
      final event = eventFor(SurvivalOutbreakKind.crystal);
      final core = event.cores.first;
      final enemy = enemyAt(core.position);
      expect(event.damageMultiplier(enemy), 0.65);
      expect(event.damageMultiplier(core), 1);
      core.isDead = true;
      expect(event.damageMultiplier(enemy), 1);
    },
  );

  test(
    'calcified shell opens after pulse and frost only slows during surge',
    () {
      final shell = eventFor(SurvivalOutbreakKind.calcified);
      expect(shell.damageMultiplier(shell.cores.first), 0.3);
      shell.advance(10);
      expect(shell.damageMultiplier(shell.cores.first), 1);
      shell.advance(2);
      expect(shell.damageMultiplier(shell.cores.first), 0.3);
      final frost = eventFor(SurvivalOutbreakKind.frost);
      final position = frost.cores.first.position;
      expect(frost.movementMultiplier(position), 1);
      frost.advance(10);
      expect(frost.movementMultiplier(position), 0.65);
      expect(frost.movementMultiplier(Offset.zero), 1);
      frost.cores.first.isDead = true;
      expect(frost.movementMultiplier(position), 1);
    },
  );

  test('destroying a web anchor removes its links', () {
    final event = eventFor(SurvivalOutbreakKind.voltaic);
    expect(event.links.length, 3);
    final (a, b) = event.links.first;
    expect(SurvivalOutbreak.touchesLink((a + b) / 2, a, b, 25), isTrue);
    expect(
      SurvivalOutbreak.touchesLink(const Offset(5000, 5000), a, b, 25),
      isFalse,
    );
    event.cores.first.isDead = true;
    expect(event.links.length, 1);
  });

  test('sources scale with wave and resist displacement', () {
    final early = eventFor(SurvivalOutbreakKind.nigredo);
    final late = eventFor(SurvivalOutbreakKind.nigredo, wave: 50);
    expect(late.cores.first.maxHp, greaterThan(early.cores.first.maxHp));
    early.cores.first.position = Offset.zero;
    early.cores.first.knockbackVelocity = const Offset(100, 100);
    early.anchorCores();
    expect(early.cores.first.position, early.anchors.first);
    expect(early.cores.first.knockbackVelocity, Offset.zero);
  });

  Future<CosmicSurvivalGame> gameWith(SurvivalOutbreakKind kind) async {
    final game = CosmicSurvivalGame(party: [], onGameOver: () {});
    game.onGameResize(Vector2(900, 700));
    await game.onLoad();
    game.startGame();
    game.spawner.currentWave = 20;
    game.spawner.isBossWave = true;
    game.update(0.01);
    expect(game.activeBoss, isNotNull);
    expect(game.extraBosses, isEmpty);
    game.activeBoss = null;
    game.extraBosses.clear();
    game.spawner.bossSpawned = true;
    game.enemies.clear();
    game.outbreak = eventFor(kind);
    game.enemies.addAll(game.outbreak!.cores);
    return game;
  }

  test(
    'game spawns one boss on outbreak waves and pauses outbreak time',
    () async {
      final game = await gameWith(SurvivalOutbreakKind.verdigris);
      expect(game.extraBosses, isEmpty);
      game.gamePaused = true;
      game.update(10);
      expect(game.outbreak!.elapsed, 0);
      game.gamePaused = false;
      game.update(0.1);
      expect(game.outbreak!.elapsed, closeTo(0.1, 0.001));
    },
  );

  test(
    'toxic pulse damages ship; a destroyed core cannot pulse again',
    () async {
      final game = await gameWith(SurvivalOutbreakKind.verdigris);
      final event = game.outbreak!;
      game.ship.position = event.cores.first.position;
      event.advance(9.9);
      final before = game.ship.currentHp;
      game.update(0.11);
      expect(game.ship.currentHp, lessThan(before));
      for (final core in event.cores) {
        core.isDead = true;
      }
      final elapsed = event.elapsed;
      game.update(0.1);
      expect(event.elapsed, elapsed);
    },
  );

  test('sanguine pulse heals normal enemies, not the cores', () async {
    final game = await gameWith(SurvivalOutbreakKind.sanguine);
    final event = game.outbreak!;
    final core = event.cores.first;
    final enemy = enemyAt(core.position + const Offset(80, 0));
    game.enemies.add(enemy);
    core.hp *= 0.5;
    final coreHp = core.hp;
    event.advance(9.9);
    game.update(0.11);
    expect(enemy.hp, greaterThan(40));
    expect(core.hp, lessThanOrEqualTo(coreHp));
  });

  test('nigredo pulse damages orb and mirror emits a finite volley', () async {
    final game = await gameWith(SurvivalOutbreakKind.nigredo);
    final before = game.orb.currentHp;
    game.outbreak!.advance(9.9);
    game.update(0.11);
    expect(game.orb.currentHp, lessThan(before));
    final mirror = await gameWith(SurvivalOutbreakKind.mirror);
    mirror.outbreak!.advance(9.9);
    mirror.update(0.11);
    expect(mirror.enemyProjectiles.length, 9);
  });

  test('living plague sources block boss-wave completion', () async {
    final game = await gameWith(SurvivalOutbreakKind.nigredo);
    // Exhaust the scheduled wave spawns without introducing combat noise.
    for (var i = 0; i < 500; i++) {
      game.spawner.update(10, 0, 900, 700, Offset.zero);
    }
    game.update(0.01);
    expect(game.spawner.currentWave, 20);
    expect(game.spawner.intermission, isFalse);
    for (final core in game.outbreak!.cores) {
      core.isDead = true;
    }
    game.update(0.01);
    expect(game.spawner.intermission || game.spawner.currentWave > 20, isTrue);
  });

  test(
    'cinder brood stays bounded and a destroyed nest stops spawning',
    () async {
      final game = await gameWith(SurvivalOutbreakKind.cinder);
      final event = game.outbreak!;
      event.advance(9.9);
      for (var i = 0; i < 10; i++) {
        game.update(0.11);
        event.advance(5.89);
      }
      expect(event.brood.length, inInclusiveRange(1, 8));
      for (final core in event.cores) {
        core.isDead = true;
      }
      final count = event.brood.length;
      game.update(0.11);
      expect(event.brood.length, count);
    },
  );

  test('quicksilver surge pulls a ship toward its live well', () async {
    final game = await gameWith(SurvivalOutbreakKind.quicksilver);
    final event = game.outbreak!;
    final core = event.cores.first;
    game.ship.position = core.position + const Offset(120, 0);
    final before = (game.ship.position - core.position).distance;
    event.advance(9.9);
    game.update(0.11);
    expect((game.ship.position - core.position).distance, lessThan(before));
  });
}
