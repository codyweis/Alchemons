// How summoned Alchemons move in open cosmic space: the follow formation
// behind the ship, the spacing between three of them, and how they fight a
// boss and a wild Alchemon.
//
// COMPANION_MOTION_TRACE=dir writes one CSV per scenario (frame, actor, x, y,
// radius) for plotting.

import 'dart:io';
import 'dart:math';

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart';
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

/// The body a companion occupies on screen: the creature fills about two
/// thirds of its sprite frame.
double _bodyRadius(CosmicCompanion c) =>
    CosmicGame.spriteBox * c.speciesScale * 0.34;

class _Arena {
  _Arena(this.game, this.home);
  final CosmicGame game;
  final Offset home;
  final List<String> trace = [];
  int frame = 0;

  List<CosmicCompanion> get comps => game.activeCompanions.values.toList();

  void step(double seconds, {void Function()? each}) {
    const dt = 1 / 60;
    final frames = (seconds / dt).round();
    for (var i = 0; i < frames; i++) {
      game.update(dt);
      each?.call();
      frame++;
      if (frame % 3 == 0) _record();
    }
  }

  void _record() {
    trace.add('$frame,ship,${game.ship.pos.dx},${game.ship.pos.dy},14');
    for (final c in comps) {
      trace.add(
        '$frame,${c.member.family},${c.position.dx},${c.position.dy},'
        '${_bodyRadius(c)}',
      );
    }
    final boss = game.activeBoss;
    if (boss != null) {
      trace.add(
        '$frame,boss,${boss.position.dx},${boss.position.dy},'
        '${boss.radius}',
      );
    }
    final opp = game.duelOpponent;
    if (opp != null && game.wildDuelActive) {
      trace.add(
        '$frame,wild,${opp.position.dx},${opp.position.dy},'
        '${CosmicGame.spriteBox * opp.speciesScale * 0.34}',
      );
    }
  }

  void writeTrace(String name) {
    final dir = Platform.environment['COMPANION_MOTION_TRACE'];
    if (dir == null) return;
    File('$dir/$name.csv')
      ..createSync(recursive: true)
      ..writeAsStringSync('frame,actor,x,y,r\n${trace.join('\n')}\n');
  }
}

Future<_Arena> _arena() async {
  final game = CosmicGame(
    world_: CosmicWorld.generate(seed: 37),
    onMeterChanged: () {},
  );
  game.ship = ShipComponent(pos: Offset.zero);
  game.onGameResize(Vector2(900, 700));
  await game.onLoad();

  // Deep space: nothing pulling the ship, nothing to collide with.
  final world = game.world_;
  Offset home = Offset.zero;
  var best = -1.0;
  for (var gx = 1; gx < 20; gx++) {
    for (var gy = 1; gy < 20; gy++) {
      final p = Offset(
        world.worldSize.width * gx / 20,
        world.worldSize.height * gy / 20,
      );
      var nearest = double.infinity;
      for (final planet in world.planets) {
        nearest = min(nearest, (planet.position - p).distance);
      }
      if (nearest > best) {
        best = nearest;
        home = p;
      }
    }
  }
  game.teleportTo(home);
  game.enemies.clear();
  game.activeBoss = null;

  final party = [
    _member('Pip', 'Fire', 0),
    _member('Wing', 'Air', 1),
    _member('Horn', 'Fire', 2),
  ];
  for (final m in party) {
    game.summonCompanion(m, slotIndex: m.slotIndex);
  }
  for (final c in game.activeCompanions.values) {
    c.invincibleTimer = 0;
  }
  return _Arena(game, home);
}

/// Worst spacing between any two companions: centre distance minus both
/// bodies. Negative means their sprites overlap. A horn mid-charge is left
/// out: it dashes past whatever is in the way by design.
double _worstPairGap(List<CosmicCompanion> comps) {
  var worst = double.infinity;
  for (var i = 0; i < comps.length; i++) {
    for (var j = i + 1; j < comps.length; j++) {
      if (comps[i].isCharging || comps[j].isCharging) continue;
      final d = (comps[i].position - comps[j].position).distance;
      worst = min(worst, d - _bodyRadius(comps[i]) - _bodyRadius(comps[j]));
    }
  }
  return worst;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('three followers keep their own space behind the ship', () async {
    final a = await _arena();
    final game = a.game;
    var worstGap = double.infinity;
    var closestToShip = double.infinity;
    var farthestFromShip = 0.0;
    var pinnedFrames = 0;
    var overlapFrames = 0;
    var frames = 0;
    void measure() {
      game.enemies.clear();
      game.activeBoss = null;
      game.bossProjectiles.clear();
      if (a.frame < 90) return; // let them step out of their tears
      frames++;
      final gap = _worstPairGap(a.comps);
      worstGap = min(worstGap, gap);
      if (gap < 0) overlapFrames++;
      for (final c in a.comps) {
        final d = (c.position - game.ship.pos).distance;
        closestToShip = min(closestToShip, d - _bodyRadius(c));
        farthestFromShip = max(farthestFromShip, d);
      }
      // Held at the tether's end rather than flying its own place.
      if (a.comps.any((c) => (c.position - game.ship.pos).distance > 236)) {
        pinnedFrames++;
      }
    }

    a.step(1.5, each: measure);
    game.joystickDirection = const Offset(1, 0);
    a.step(3, each: measure);
    game.joystickDirection = const Offset(-1, 0); // hard reverse
    a.step(2.5, each: measure);
    game.joystickDirection = const Offset(0, 1);
    a.step(2, each: measure);
    game.joystickDirection = null; // stop
    a.step(3, each: measure);
    a.writeTrace('follow');

    // ignore: avoid_print
    print(
      'follow: worst pair gap ${worstGap.toStringAsFixed(1)}, '
      'overlap ${(100 * overlapFrames / frames).toStringAsFixed(1)}% of frames, '
      'closest body edge to ship ${closestToShip.toStringAsFixed(1)}, '
      'farthest ${farthestFromShip.toStringAsFixed(1)}, '
      'pinned at tether ${(100 * pinnedFrames / frames).toStringAsFixed(1)}%, '
      'still out ${game.activeCompanions.values.where((c) => !c.returning).length}',
    );
    expect(game.activeCompanions.values.where((c) => !c.returning).length, 3);
    expect(overlapFrames / frames, lessThan(0.02));
    // Clear of the ship's hull, and only briefly held at the tether's end
    // (the hard reverse flies the ship away from the one that let it past).
    expect(closestToShip, greaterThan(26));
    expect(pinnedFrames / frames, lessThan(0.12));
  });

  for (final type in [BossType.gunner, BossType.charger]) {
    test('a ${type.name} boss: stations clear of each other, in reach', () async {
      final a = await _arena();
      final game = a.game;
      final boss = CosmicBoss(
        position: a.home + const Offset(300, 0),
        name: 'Test',
        element: 'Fire',
        level: 5,
        radius: 44,
        maxHealth: 1e9,
        speed: 40,
        forcedType: type,
      );
      game.activeBoss = boss;
      var insideBossFrames = 0;
      var worstGap = double.infinity;
      var overlapFrames = 0;
      var frames = 0;
      final travelled = <CosmicCompanion, double>{};
      final lastPos = <CosmicCompanion, Offset>{};
      final headings = <CosmicCompanion, Set<int>>{};
      final hpStart = {for (final c in a.comps) c: c.currentHp};
      void measure() {
        game.enemies.clear();
        game.activeBoss = boss;
        if (a.frame < 90) return;
        frames++;
        final gap = _worstPairGap(a.comps);
        worstGap = min(worstGap, gap);
        if (gap < 0) overlapFrames++;
        for (final c in a.comps) {
          // A charge runs through (the boss's, or a horn's own), and a
          // melee body may press against its edge; what counts is never
          // standing with its centre inside the boss.
          final d = (c.position - boss.position).distance;
          if (!boss.charging && !c.isCharging && d < boss.radius) {
            insideBossFrames++;
          }
          final prev = lastPos[c];
          if (prev != null) {
            final step = c.position - prev;
            travelled[c] = (travelled[c] ?? 0) + step.distance;
            if (step.distance > 0.5) {
              // Eight compass sectors the companion moved through.
              final sector = ((atan2(step.dy, step.dx) + pi) / (pi / 4))
                  .floor();
              (headings[c] ??= <int>{}).add(sector);
            }
          }
          lastPos[c] = c.position;
        }
      }

      a.step(12, each: measure);
      a.writeTrace('boss_${type.name}');
      final damage = boss.maxHealth - boss.health;
      // ignore: avoid_print
      print(
        '${type.name}: worst pair gap ${worstGap.toStringAsFixed(1)}, '
        'overlap ${(100 * overlapFrames / frames).toStringAsFixed(1)}%, '
        'inside-boss companion-frames $insideBossFrames, '
        'damage ${damage.toStringAsFixed(0)}, '
        'hp lost ${a.comps.map((c) => '${c.member.family}:${hpStart[c]! - c.currentHp}').join(' ')}, '
        'travel ${a.comps.map((c) => '${c.member.family}:${(travelled[c] ?? 0).toStringAsFixed(0)}/${headings[c]?.length ?? 0}dirs').join(' ')}',
      );
      expect(game.activeCompanions.length, 3);
      expect(damage, greaterThan(0), reason: 'the party never reached it');
      expect(insideBossFrames, 0);
      // Brief touches while sidestepping boss fire are allowed; the wander
      // orbit this replaced overlapped on every frame.
      expect(overlapFrames / frames, lessThan(0.08));
    });
  }

  test('a swarm on the ship: they hold their sides, not circle', () async {
    final a = await _arena();
    final game = a.game;
    // Drones, wisps and sentinels closing on the ship from all round.
    const tiers = [
      EnemyTier.drone,
      EnemyTier.wisp,
      EnemyTier.sentinel,
      EnemyTier.drone,
      EnemyTier.wisp,
      EnemyTier.drone,
      EnemyTier.sentinel,
      EnemyTier.wisp,
    ];
    final swarm = [
      for (var i = 0; i < tiers.length; i++)
        CosmicEnemy(
          position:
              a.home +
              Offset(
                    cos(i / tiers.length * 2 * pi),
                    sin(i / tiers.length * 2 * pi),
                  ) *
                  (260.0 + (i % 3) * 50),
          element: 'Fire',
          tier: tiers[i],
          radius: tiers[i] == EnemyTier.sentinel ? 20 : 10,
          health: 1e7,
          speed: tiers[i] == EnemyTier.drone ? 90 : 50,
        ),
    ];
    game.enemies.addAll(swarm);
    const dt = 1 / 60;
    final circling = <double>[];
    final speeds = <double>[];
    var switches = 0;
    final last = <CosmicCompanion, Object?>{};
    a.step(
      12,
      each: () {
        game.enemies.removeWhere((e) => !swarm.contains(e));
        for (final e in swarm) {
          e.dead = false;
        }
        if (a.frame < 90) return;
        for (final c in a.comps) {
          speeds.add(c.velocity.distance);
          final t = c.combatTarget;
          if (last[c] != null && !identical(last[c], t)) switches++;
          last[c] = t;
          if (t is! CosmicEnemy) continue;
          final rel = c.position - t.position;
          if (rel.distance < 1) continue;
          final n = rel / rel.distance;
          // Its own motion round the target, not the target's darting.
          circling.add((c.velocity.dx * -n.dy + c.velocity.dy * n.dx).abs());
        }
      },
    );
    circling.sort();
    speeds.sort();
    double p(List<double> l, double q) => l[(l.length * q).floor()];
    final minutes = (a.frame - 90) * dt / 60;
    // ignore: avoid_print
    print(
      'swarm: circling p50 ${p(circling, .5).toStringAsFixed(0)} '
      'p90 ${p(circling, .9).toStringAsFixed(0)} px/s, speed p95 '
      '${p(speeds, .95).toStringAsFixed(0)} px/s, '
      '${(switches / minutes).toStringAsFixed(0)} target switches/min',
    );
    // Before the station swing cap, target commitment and fighting from its
    // own side near the ship: circling p90 ~240 px/s (counting the targets'
    // own darting), speed p90 ~250 and p99 ~380 px/s, ~75 switches a minute.
    // Since open space fights at Survival's tempo (2026-10-02: the shared
    // power model, specials about twice as often) the party moves more —
    // speed p95 measured 190-250 over ten runs — so the speed bar sits at
    // 270, still well under the band it guards against.
    expect(p(circling, .9), lessThan(170));
    expect(p(speeds, .95), lessThan(270));
    expect(switches / minutes, lessThan(60));
  });

  test('a wild Alchemon fight: it meets the whole party', () async {
    final a = await _arena();
    final game = a.game;
    final wild = SpaceWildAlchemon(
      id: 'wild-test',
      member: _member('Mane', 'Water', 5),
      rarity: 'Common',
      position: a.home + const Offset(260, 40),
    );
    game.addWildAlchemon(wild);
    WildDuelEnd? ended;
    game.onWildDuelEnded = (_, how) => ended = how;
    game.engageWild(wild);
    expect(game.wildDuelActive, isTrue);
    final opp = game.duelOpponent!;
    opp.maxHp = 1 << 30;
    opp.currentHp = 1 << 30;
    var worstGap = double.infinity;
    var overlapFrames = 0;
    var frames = 0;
    final hpStart = {for (final c in a.comps) c: c.currentHp};
    final oppStart = opp.currentHp;
    void measure() {
      game.enemies.clear();
      game.activeBoss = null;
      if (a.frame < 90) return;
      frames++;
      final gap = _worstPairGap(a.comps);
      worstGap = min(worstGap, gap);
      if (gap < 0) overlapFrames++;
    }

    a.step(12, each: measure);
    a.writeTrace('wild');
    final lost = {for (final c in a.comps) c: hpStart[c]! - c.currentHp};
    // ignore: avoid_print
    print(
      'wild: worst pair gap ${worstGap.toStringAsFixed(1)}, '
      'overlap ${(100 * overlapFrames / frames).toStringAsFixed(1)}%, '
      'wild hp lost ${oppStart - opp.currentHp}, '
      'party hp lost ${a.comps.map((c) => '${c.member.family}:${lost[c]}').join(' ')}',
    );
    // Touching the ship counts as a ram and opens the portal. The ship sat
    // still, so the wild one must not have walked into it.
    expect(ended, isNull, reason: 'the fight ended: $ended');
    expect(oppStart - opp.currentHp, greaterThan(0));
    expect(overlapFrames / frames, lessThan(0.05));
  });
}
