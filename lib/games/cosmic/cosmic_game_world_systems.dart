part of 'cosmic_game.dart';

extension CosmicGameWorldSystems on CosmicGame {
  void _revealAround(Offset center, double radius) {
    final cellR = (radius / CosmicGame.fogCellSize).ceil();
    final cx = (center.dx / CosmicGame.fogCellSize).floor();
    final cy = (center.dy / CosmicGame.fogCellSize).floor();
    final gridW = (world_.worldSize.width / CosmicGame.fogCellSize).ceil();
    final gridH = (world_.worldSize.height / CosmicGame.fogCellSize).ceil();

    for (var dy = -cellR; dy <= cellR; dy++) {
      for (var dx = -cellR; dx <= cellR; dx++) {
        final gx = ((cx + dx) % gridW + gridW) % gridW;
        final gy = ((cy + dy) % gridH + gridH) % gridH;

        // Circular reveal
        final dist =
            sqrt((dx * dx + dy * dy).toDouble()) * CosmicGame.fogCellSize;
        if (dist <= radius) {
          revealedCells.add(gy * gridW + gx);
        }
      }
    }
  }

  // ── enemy/boss spawning & AI ───────────────────────────

  // ── enemy/boss spawning & AI ───────────────────────────

  /// Pick a random element from discovered planets (or any if none discovered).
  String _randomEnemyElement(Random rng) {
    final discovered = world_.planets.where((p) => p.discovered).toList();
    final src = discovered.isNotEmpty
        ? discovered[rng.nextInt(discovered.length)]
        : world_.planets[rng.nextInt(world_.planets.length)];
    return src.element;
  }

  void _spawnEnemy() {
    final rng = Random();

    // Roll behavior type:
    // Bias ambient roaming toward passive contacts so space feels alive
    // without turning every encounter into pressure.
    final roll = rng.nextDouble();
    EnemyBehavior behavior;
    if (roll < 0.18) {
      behavior = EnemyBehavior.aggressive;
    } else if (roll < 0.62) {
      behavior = EnemyBehavior.drifting;
    } else if (roll < 0.74) {
      behavior = EnemyBehavior.territorial;
    } else if (roll < 0.84) {
      behavior = EnemyBehavior.stalking;
    } else {
      behavior = EnemyBehavior.feeding;
    }

    // Choose tier — behavior determines distribution across all 6 tiers
    final EnemyTier tier;
    switch (behavior) {
      case EnemyBehavior.aggressive:
        final roll = rng.nextDouble();
        tier = roll < 0.20
            ? EnemyTier.wisp
            : roll < 0.45
            ? EnemyTier.drone
            : roll < 0.70
            ? EnemyTier.sentinel
            : roll < 0.85
            ? EnemyTier.phantom
            : roll < 0.95
            ? EnemyTier.brute
            : EnemyTier.colossus;
        break;
      case EnemyBehavior.drifting:
        final roll = rng.nextDouble();
        tier = roll < 0.56
            ? EnemyTier.wisp
            : roll < 0.90
            ? EnemyTier.drone
            : roll < 0.98
            ? EnemyTier.phantom
            : EnemyTier.sentinel;
        break;
      case EnemyBehavior.territorial:
        final roll = rng.nextDouble();
        tier = roll < 0.15
            ? EnemyTier.wisp
            : roll < 0.35
            ? EnemyTier.drone
            : roll < 0.60
            ? EnemyTier.sentinel
            : roll < 0.78
            ? EnemyTier.phantom
            : roll < 0.92
            ? EnemyTier.brute
            : EnemyTier.colossus;
        break;
      case EnemyBehavior.stalking:
        // Stalkers: phantoms & wisps — eerie
        tier = rng.nextDouble() < 0.55 ? EnemyTier.phantom : EnemyTier.wisp;
        break;
      case EnemyBehavior.feeding:
        final roll = rng.nextDouble();
        tier = roll < 0.55
            ? EnemyTier.wisp
            : roll < 0.85
            ? EnemyTier.drone
            : roll < 0.97
            ? EnemyTier.sentinel
            : EnemyTier.phantom;
        break;
      case EnemyBehavior.swarming:
        // Swarms: mostly drones & wisps
        tier = rng.nextDouble() < 0.55 ? EnemyTier.drone : EnemyTier.wisp;
        break;
    }
    final element = _randomEnemyElement(rng);

    // Position depends on behavior
    Offset pos;
    Offset? homePos;
    double aggroRadius = 300;

    switch (behavior) {
      case EnemyBehavior.territorial:
        // Spawn near a random planet
        final planet = world_.planets[rng.nextInt(world_.planets.length)];
        final a = rng.nextDouble() * pi * 2;
        final dist = planet.radius * 3.0 + 80 + rng.nextDouble() * 200;
        pos = _wrap(
          Offset(
            planet.position.dx + cos(a) * dist,
            planet.position.dy + sin(a) * dist,
          ),
        );
        homePos = pos;
        aggroRadius = 250 + rng.nextDouble() * 150;
        break;

      case EnemyBehavior.stalking:
        // Spawn behind the player at distance
        final behindAngle = ship.angle + pi + (rng.nextDouble() - 0.5) * 0.8;
        final stalkDist = 600 + rng.nextDouble() * 400;
        pos = _wrap(
          Offset(
            ship.pos.dx + cos(behindAngle) * stalkDist,
            ship.pos.dy + sin(behindAngle) * stalkDist,
          ),
        );
        break;

      case EnemyBehavior.feeding:
        // Solo feeder near asteroid belt
        final belt = asteroidBelt;
        final a = rng.nextDouble() * pi * 2;
        final dist =
            belt.innerRadius +
            rng.nextDouble() * (belt.outerRadius - belt.innerRadius);
        pos = _wrap(
          Offset(
            belt.center.dx + cos(a) * dist,
            belt.center.dy + sin(a) * dist,
          ),
        );
        homePos = pos;
        break;

      default:
        // Aggressive / drifting — spawn at viewport edge
        final angle = rng.nextDouble() * pi * 2;
        final edgeDist = sqrt(size.x * size.x + size.y * size.y) * 0.55;
        pos = _wrap(
          Offset(
            ship.pos.dx + cos(angle) * edgeDist,
            ship.pos.dy + sin(angle) * edgeDist,
          ),
        );
    }

    enemies.add(
      CosmicEnemy(
        position: pos,
        element: element,
        tier: tier,
        radius: switch (tier) {
          EnemyTier.drone => 6 + rng.nextDouble() * 3,
          EnemyTier.wisp => 8 + rng.nextDouble() * 4,
          EnemyTier.sentinel => 14 + rng.nextDouble() * 6,
          EnemyTier.phantom => 12 + rng.nextDouble() * 5,
          EnemyTier.brute => 20 + rng.nextDouble() * 8,
          EnemyTier.colossus => 30 + rng.nextDouble() * 12,
        },
        health: CosmicBalance.enemyBaseHealth(tier),
        speed: switch (tier) {
          EnemyTier.drone => 90 + rng.nextDouble() * 50,
          EnemyTier.wisp => 60 + rng.nextDouble() * 40,
          EnemyTier.sentinel => 35 + rng.nextDouble() * 25,
          EnemyTier.phantom => 45 + rng.nextDouble() * 30,
          EnemyTier.brute => 20 + rng.nextDouble() * 15,
          EnemyTier.colossus => 12 + rng.nextDouble() * 8,
        },
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 4,
        behavior: behavior,
        homePos: homePos,
        aggroRadius: aggroRadius,
        stalkDistance: 400 + rng.nextDouble() * 300,
      ),
    );
  }

  /// Spawn a feeding pack: 1 sentinel alpha + 3-5 wisp minions clustered
  /// near the asteroid belt, passively eating rocks.
  void _spawnFeedingPack() {
    final rng = Random();
    final packId = _nextPackId++;
    final element = _randomEnemyElement(rng);

    // Pick a position inside the asteroid belt
    final belt = asteroidBelt;
    final centerAngle = rng.nextDouble() * pi * 2;
    final centerDist =
        belt.innerRadius +
        rng.nextDouble() * (belt.outerRadius - belt.innerRadius);
    final cx = belt.center.dx + cos(centerAngle) * centerDist;
    final cy = belt.center.dy + sin(centerAngle) * centerDist;
    final home = _wrap(Offset(cx, cy));

    // Alpha sentinel — bigger, tougher
    enemies.add(
      CosmicEnemy(
        position: home,
        element: element,
        tier: EnemyTier.sentinel,
        radius: 18 + rng.nextDouble() * 6,
        health: CosmicBalance.enemyBaseHealth(EnemyTier.sentinel) * 1.2,
        speed: 30 + rng.nextDouble() * 20,
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 4,
        behavior: EnemyBehavior.feeding,
        packId: packId,
        homePos: home,
        aggroRadius: 350,
      ),
    );

    // 5-8 wisp minions so roaming space has more prey-sized targets.
    final minionCount = 5 + rng.nextInt(4);
    for (var m = 0; m < minionCount; m++) {
      final mAngle = rng.nextDouble() * pi * 2;
      final mDist = 40 + rng.nextDouble() * 80;
      final mPos = _wrap(
        Offset(cx + cos(mAngle) * mDist, cy + sin(mAngle) * mDist),
      );
      enemies.add(
        CosmicEnemy(
          position: mPos,
          element: element,
          tier: EnemyTier.wisp,
          radius: 6 + rng.nextDouble() * 4,
          health: CosmicBalance.enemyBaseHealth(EnemyTier.wisp),
          speed: 40 + rng.nextDouble() * 30,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 4,
          behavior: EnemyBehavior.feeding,
          packId: packId,
          homePos: mPos,
          aggroRadius: 350,
        ),
      );
    }
  }

  /// Spawn a swarm cluster of 20-32 swarming small flyers at a position.
  /// If [center] is not given, picks a random spot in deep space.
  /// Respects the enemy cap — skips if already at max.
  void _spawnSwarmCluster({Offset? center, Random? rng}) {
    if (enemies.length >= CosmicGame._maxEnemies) return;
    rng ??= Random();
    final packId = _nextPackId++;
    const elements = ['Fire', 'Water', 'Earth', 'Air', 'Light', 'Dark'];
    final element = elements[rng.nextInt(elements.length)];
    final count = min(
      20 + rng.nextInt(13),
      CosmicGame._maxEnemies - enemies.length,
    ); // 20-32, capped

    // Pick center if not provided — random position in world, away from edges
    final cx =
        center?.dx ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.width - 4000));
    final cy =
        center?.dy ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.height - 4000));
    final home = _wrap(Offset(cx, cy));

    for (int i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = 20.0 + rng.nextDouble() * 150;
      final swarmTier = rng.nextDouble() < 0.5
          ? EnemyTier.drone
          : EnemyTier.wisp;
      enemies.add(
        CosmicEnemy(
          position: _wrap(
            Offset(cx + cos(angle) * dist, cy + sin(angle) * dist),
          ),
          element: element,
          tier: swarmTier,
          radius: swarmTier == EnemyTier.drone
              ? 4 + rng.nextDouble() * 3
              : 5 + rng.nextDouble() * 4,
          health: CosmicBalance.enemyBaseHealth(swarmTier),
          speed: swarmTier == EnemyTier.drone
              ? 55 + rng.nextDouble() * 40
              : 35 + rng.nextDouble() * 35,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 4,
          behavior: EnemyBehavior.swarming,
          packId: packId,
          homePos: home,
        ),
      );
    }
  }

  /// Spawn an enemy from a galaxy whirl during horde mode.
  /// Behaviour varies by [HordeType].
  void _spawnWhirlEnemy(GalaxyWhirl whirl, int whirlIdx) {
    switch (whirl.hordeType) {
      case HordeType.skirmish:
        _spawnSkirmishEnemy(whirl, whirlIdx);
      case HordeType.siege:
        _spawnSiegeEnemy(whirl, whirlIdx);
      case HordeType.onslaught:
        _spawnOnslaughtEnemy(whirl, whirlIdx);
    }
  }

  // ── SKIRMISH (Lv 1-3) ───────────────────────────
  // Simple waves, mostly wisps & sentinels, moderate pacing.
  void _spawnSkirmishEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;

    // Gentle tier distribution — drones join mid waves, phantoms late
    final EnemyTier tier;
    if (wave >= 4) {
      final roll = rng.nextDouble();
      tier = roll < 0.20
          ? EnemyTier.wisp
          : roll < 0.45
          ? EnemyTier.drone
          : roll < 0.75
          ? EnemyTier.sentinel
          : EnemyTier.phantom;
    } else if (wave >= 2) {
      final roll = rng.nextDouble();
      tier = roll < 0.35
          ? EnemyTier.wisp
          : roll < 0.60
          ? EnemyTier.drone
          : EnemyTier.sentinel;
    } else {
      tier = rng.nextDouble() < 0.65 ? EnemyTier.wisp : EnemyTier.drone;
    }

    final behavior = (wave >= 3 && rng.nextDouble() < 0.3)
        ? EnemyBehavior.swarming
        : EnemyBehavior.aggressive;

    _addWhirlEnemy(whirl, whirlIdx, tier, behavior, rng);
  }

  // ── SIEGE (Lv 4-7) ──────────────────────────────
  // Formation bursts, brute tanks shield wisps, final wave has a mini-boss.
  void _spawnSiegeEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;
    final isFinalWave = wave == whirl.totalWaves - 1;

    // Final wave mini-boss: one beefy sentinel
    if (isFinalWave && !whirl.miniBossSpawned) {
      whirl.miniBossSpawned = true;
      final hpScale = whirl.enemyHealthScale;
      final spdScale = whirl.enemySpeedScale;
      final angle = rng.nextDouble() * pi * 2;
      final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
      final pos = _wrap(
        Offset(
          whirl.position.dx + cos(angle) * spawnDist,
          whirl.position.dy + sin(angle) * spawnDist,
        ),
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: whirl.element,
          tier: EnemyTier.brute,
          radius: 28 + rng.nextDouble() * 6,
          health:
              CosmicBalance.enemyBaseHealth(EnemyTier.brute) * 1.6 * hpScale,
          speed: (30 + rng.nextDouble() * 10) * spdScale,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
          whirlIndex: whirlIdx,
        ),
      );
      return;
    }

    // Formation tier: brutes & colossi in later waves, drones early
    final EnemyTier tier;
    if (wave >= 3) {
      final roll = rng.nextDouble();
      tier = roll < 0.10
          ? EnemyTier.wisp
          : roll < 0.25
          ? EnemyTier.drone
          : roll < 0.50
          ? EnemyTier.sentinel
          : roll < 0.65
          ? EnemyTier.phantom
          : roll < 0.88
          ? EnemyTier.brute
          : EnemyTier.colossus;
    } else if (wave >= 1) {
      final roll = rng.nextDouble();
      tier = roll < 0.20
          ? EnemyTier.wisp
          : roll < 0.40
          ? EnemyTier.drone
          : roll < 0.75
          ? EnemyTier.sentinel
          : EnemyTier.brute;
    } else {
      final roll = rng.nextDouble();
      tier = roll < 0.35
          ? EnemyTier.wisp
          : roll < 0.60
          ? EnemyTier.drone
          : EnemyTier.sentinel;
    }

    // Siege enemies are always aggressive — disciplined formation
    _addWhirlEnemy(whirl, whirlIdx, tier, EnemyBehavior.aggressive, rng);
  }

  // ── ONSLAUGHT (Lv 8-10) ─────────────────────────
  // Relentless, mixed tiers from wave 1, swarming dominant, mini-boss brute finale.
  void _spawnOnslaughtEnemy(GalaxyWhirl whirl, int whirlIdx) {
    final rng = Random();
    final wave = whirl.currentWave;
    final isFinalWave = wave == whirl.totalWaves - 1;

    // Final wave mini-boss: terrifying colossus
    if (isFinalWave && !whirl.miniBossSpawned) {
      whirl.miniBossSpawned = true;
      final hpScale = whirl.enemyHealthScale;
      final spdScale = whirl.enemySpeedScale;
      final angle = rng.nextDouble() * pi * 2;
      final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
      final pos = _wrap(
        Offset(
          whirl.position.dx + cos(angle) * spawnDist,
          whirl.position.dy + sin(angle) * spawnDist,
        ),
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: whirl.element,
          tier: EnemyTier.colossus,
          radius: 38 + rng.nextDouble() * 8,
          health:
              CosmicBalance.enemyBaseHealth(EnemyTier.colossus) * 1.8 * hpScale,
          speed: (20 + rng.nextDouble() * 10) * spdScale,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
          whirlIndex: whirlIdx,
        ),
      );
      return;
    }

    // Mixed tiers from the start — onslaught is chaotic, all tiers present
    final EnemyTier tier;
    final roll = rng.nextDouble();
    final levChance = (0.04 + wave * 0.03).clamp(0.04, 0.15);
    final bruteChance = (0.10 + wave * 0.05).clamp(0.10, 0.25);
    final phantomChance = (0.10 + wave * 0.03).clamp(0.10, 0.20);
    final sentinelChance = 0.20;
    final droneChance = 0.20;
    // remainder → wisps
    if (roll < droneChance) {
      tier = EnemyTier.drone;
    } else if (roll < droneChance + sentinelChance) {
      tier = EnemyTier.sentinel;
    } else if (roll < droneChance + sentinelChance + phantomChance) {
      tier = EnemyTier.phantom;
    } else if (roll <
        droneChance + sentinelChance + phantomChance + bruteChance) {
      tier = EnemyTier.brute;
    } else if (roll <
        droneChance +
            sentinelChance +
            phantomChance +
            bruteChance +
            levChance) {
      tier = EnemyTier.colossus;
    } else {
      tier = EnemyTier.wisp;
    }

    // Swarming is dominant in onslaught
    final behavior = rng.nextDouble() < 0.6
        ? EnemyBehavior.swarming
        : EnemyBehavior.aggressive;

    _addWhirlEnemy(whirl, whirlIdx, tier, behavior, rng);
  }

  /// Shared helper to add a whirl enemy with standard position & scaling.
  void _addWhirlEnemy(
    GalaxyWhirl whirl,
    int whirlIdx,
    EnemyTier tier,
    EnemyBehavior behavior,
    Random rng,
  ) {
    final hpScale = whirl.enemyHealthScale;
    final spdScale = whirl.enemySpeedScale;

    final angle = rng.nextDouble() * pi * 2;
    final spawnDist = whirl.radius * 0.5 + rng.nextDouble() * 20;
    final pos = _wrap(
      Offset(
        whirl.position.dx + cos(angle) * spawnDist,
        whirl.position.dy + sin(angle) * spawnDist,
      ),
    );

    enemies.add(
      CosmicEnemy(
        position: pos,
        element: whirl.element,
        tier: tier,
        radius: switch (tier) {
          EnemyTier.drone => 6 + rng.nextDouble() * 3,
          EnemyTier.wisp => 8 + rng.nextDouble() * 4,
          EnemyTier.sentinel => 14 + rng.nextDouble() * 6,
          EnemyTier.phantom => 12 + rng.nextDouble() * 5,
          EnemyTier.brute => 20 + rng.nextDouble() * 8,
          EnemyTier.colossus => 30 + rng.nextDouble() * 12,
        },
        health: CosmicBalance.enemyBaseHealth(tier) * hpScale,
        speed: switch (tier) {
          EnemyTier.drone => (100 + rng.nextDouble() * 60) * spdScale,
          EnemyTier.wisp => (70 + rng.nextDouble() * 50) * spdScale,
          EnemyTier.sentinel => (40 + rng.nextDouble() * 30) * spdScale,
          EnemyTier.phantom => (50 + rng.nextDouble() * 35) * spdScale,
          EnemyTier.brute => (25 + rng.nextDouble() * 15) * spdScale,
          EnemyTier.colossus => (15 + rng.nextDouble() * 10) * spdScale,
        },
        angle: rng.nextDouble() * pi * 2,
        driftTimer: rng.nextDouble() * 2,
        behavior: behavior,
        provoked: true,
        whirlIndex: whirlIdx,
      ),
    );
  }

  /// Provoke all enemies in the same pack as [hit].
  void _provokePackOf(CosmicEnemy hit) {
    if (hit.packId < 0) {
      // Solo enemy — just provoke itself
      hit.provoked = true;
      hit.behavior = EnemyBehavior.aggressive;
      return;
    }
    for (final e in enemies) {
      if (e.dead) continue;
      if (e.packId == hit.packId) {
        e.provoked = true;
        e.behavior = EnemyBehavior.aggressive;
      }
    }
  }

  void _updateRingMinions(double dt) {
    for (var mi = ringMinions.length - 1; mi >= 0; mi--) {
      final m = ringMinions[mi];
      if (m.dead) {
        ringMinions.removeAt(mi);
        continue;
      }
      m.life += dt;
      m.attackCooldown = (m.attackCooldown - dt).clamp(0.0, 100.0);
      // If orbitTime > 0, animate orbit (portal) until emergence
      if (m.orbitTime > 0) {
        m.orbitTime -= dt;
        // Chargers should have a much subtler portal wobble; shooters spin faster.
        if (m.type == 'charger') {
          m.orbitAngle += (0.4 + _rng.nextDouble() * 0.6) * dt;
          m.orbitRadius += dt * 1.5; // minimal expansion for chargers
        } else {
          m.orbitAngle += (1.2 + _rng.nextDouble() * 1.6) * dt; // spin
          m.orbitRadius += dt * 3.0; // reduced expansion for shooters
        }
        if (m.orbitCenter != null) {
          m.position = Offset(
            m.orbitCenter!.dx + cos(m.orbitAngle) * m.orbitRadius,
            m.orbitCenter!.dy + sin(m.orbitAngle) * m.orbitRadius,
          );
        }
        if (m.orbitTime <= 0) {
          // Emerge: small VFX to show portal spawn
          _spawnHitSpark(m.position, elementColor(m.element));
        }
        continue; // don't move toward companion until emerged
      }

      // Different behaviors per minion type after emergence
      if (m.type == 'shooter') {
        // Shooters hold position / orbit and periodically fire at the
        // player's companion.
        if (m.orbitCenter != null) {
          // gentle orbital hover
          m.orbitAngle += (0.6 + _rng.nextDouble() * 0.8) * dt;
          m.position = Offset(
            m.orbitCenter!.dx + cos(m.orbitAngle) * m.orbitRadius,
            m.orbitCenter!.dy + sin(m.orbitAngle) * m.orbitRadius,
          );
        } else if (activeCompanion != null && activeCompanion!.isAlive) {
          // small drift toward the companion but stay mostly stationary
          final comp = activeCompanion!;
          final toComp = comp.position - m.position;
          final dist = toComp.distance;
          if (dist > 2.0) {
            final step = (m.speed * 0.35) * dt;
            m.position += (toComp / dist) * min(step, dist);
          }
        }
        // Shooting
        m.shootCooldown -= dt;
        if (m.shootCooldown <= 0 &&
            activeCompanion != null &&
            activeCompanion!.isAlive) {
          m.shootCooldown = 0.6 + _rng.nextDouble() * 1.2;
          final comp = activeCompanion!;
          final ang = atan2(
            comp.position.dy - m.position.dy,
            comp.position.dx - m.position.dx,
          );
          // Use the ring opponent's family so the projectile visuals match
          final fam = battleRingOpponent?.member.family ?? 'neutral';
          final basics = createFamilyBasicAttack(
            origin: m.position,
            angle: ang,
            element: m.element,
            family: fam,
            damage: max(2.0, (m.health * 0.12)),
          );
          ringOpponentProjectiles.addAll(basics);
        }
      } else {
        // Charger: slowly move in toward the player's companion and
        // slam into it for high contact damage. They are tanky.
        if (activeCompanion != null && activeCompanion!.isAlive) {
          final comp = activeCompanion!;
          final toComp = comp.position - m.position;
          final dist = toComp.distance;
          if (dist > 2.0) {
            final step = (m.speed * 0.6) * dt; // slow, steady approach
            m.position += (toComp / dist) * min(step, dist);
          }
          // Heavy contact damage when they reach the companion
          if (dist < (m.radius + 15)) {
            if (m.attackCooldown <= 0) {
              // Slower, less devastating hits from chargers
              m.attackCooldown = 2.2;
              final contactDmg = 6.0 + (m.health / 12.0);
              final dmg = max(
                1,
                (contactDmg * 100 / (100 + comp.physDef)).round(),
              );
              comp.takeDamage(dmg);
              _spawnHitSpark(comp.position, elementColor(m.element));
            }
          }
        }
      }
    }
  }

  void _updateEnemyAI(CosmicEnemy e, double dt) {
    e.driftTimer -= dt;

    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    // ── Fast despawn check — skip all AI for enemies far from the player ──
    {
      var fdx = ship.pos.dx - e.position.dx;
      var fdy = ship.pos.dy - e.position.dy;
      if (fdx > ww / 2) fdx -= ww;
      if (fdx < -ww / 2) fdx += ww;
      if (fdy > wh / 2) fdy -= wh;
      if (fdy < -wh / 2) fdy += wh;
      final fastDist = fdx * fdx + fdy * fdy;
      // Enemies beyond 1800 units: just drift + despawn, skip expensive AI
      if (fastDist > 1800 * 1800) {
        e.position = _wrap(
          Offset(
            e.position.dx + cos(e.angle) * e.speed * dt * 0.3,
            e.position.dy + sin(e.angle) * e.speed * dt * 0.3,
          ),
        );
        final despawnDist = e.whirlIndex >= 0
            ? 4000.0 // whirl enemies persist a bit longer
            : (e.behavior == EnemyBehavior.feeding ||
                  e.behavior == EnemyBehavior.territorial)
            ? 2500.0 // persistent near their zone
            : 2000.0;
        if (sqrt(fastDist) > despawnDist) e.dead = true;
        return;
      }
    }

    // ── Check for nearby decoys — enemies prioritize attacking decoys ──
    Projectile? nearestDecoy;
    double nearestDecoyDist = double.infinity;
    for (final cp in companionProjectiles) {
      if (!cp.decoy || cp.decoyHp <= 0) continue;
      var ddx = cp.position.dx - e.position.dx;
      var ddy = cp.position.dy - e.position.dy;
      if (ddx > ww / 2) ddx -= ww;
      if (ddx < -ww / 2) ddx += ww;
      if (ddy > wh / 2) ddy -= wh;
      if (ddy < -wh / 2) ddy += wh;
      final dd = sqrt(ddx * ddx + ddy * ddy);
      final aggroRadius = cp.tauntRadius > 0 ? cp.tauntRadius : 500.0;
      if (dd < aggroRadius && dd < nearestDecoyDist) {
        nearestDecoy = cp;
        nearestDecoyDist = dd;
      }
    }

    // If a decoy is nearby, aggressive enemies chase it instead of the ship
    if (nearestDecoy != null &&
        (nearestDecoy.tauntRadius > 0 ||
            e.behavior == EnemyBehavior.aggressive ||
            e.behavior == EnemyBehavior.swarming ||
            e.behavior == EnemyBehavior.territorial ||
            e.provoked)) {
      if (nearestDecoy.tauntRadius > 0) {
        e.provoked = true;
        if (e.behavior == EnemyBehavior.drifting ||
            e.behavior == EnemyBehavior.feeding ||
            e.behavior == EnemyBehavior.territorial) {
          e.behavior = EnemyBehavior.aggressive;
        }
      }
      var ddx = nearestDecoy.position.dx - e.position.dx;
      var ddy = nearestDecoy.position.dy - e.position.dy;
      if (ddx > ww / 2) ddx -= ww;
      if (ddx < -ww / 2) ddx += ww;
      if (ddy > wh / 2) ddy -= wh;
      if (ddy < -wh / 2) ddy += wh;
      final toDecoy = atan2(ddy, ddx);
      var diff = toDecoy - e.angle;
      while (diff > pi) {
        diff -= pi * 2;
      }
      while (diff < -pi) {
        diff += pi * 2;
      }
      final turnRate = nearestDecoy.tauntStrength > 0
          ? nearestDecoy.tauntStrength
          : 4.0;
      e.angle += diff * turnRate * dt;
      final tauntSpeedMult =
          (nearestDecoy.tauntStrength > 0
                  ? (1.0 + nearestDecoy.tauntStrength * 0.08).clamp(1.0, 1.6)
                  : 1.0)
              .toDouble();
      final snareMoveMult = nearestDecoy.snareRadius > 0
          ? nearestDecoy.snareMoveMultiplier.clamp(0.2, 1.0).toDouble()
          : 1.0;
      // Skip normal AI — enemy is locked onto decoy
      e.position = _wrap(
        Offset(
          e.position.dx +
              cos(e.angle) * e.speed * tauntSpeedMult * snareMoveMult * dt,
          e.position.dy +
              sin(e.angle) * e.speed * tauntSpeedMult * snareMoveMult * dt,
        ),
      );
      return;
    }

    // Distance to ship (wrapped)
    var dx = ship.pos.dx - e.position.dx;
    var dy = ship.pos.dy - e.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    final distToShip = sqrt(dx * dx + dy * dy);
    final toShip = atan2(dy, dx);
    var moveSpeedMult = 1.0;

    for (final cp in companionProjectiles) {
      if (cp.snareRadius <= 0) continue;
      final center = cp.transferOrbitCenter ?? cp.orbitCenter ?? cp.position;
      final sdx = center.dx - e.position.dx;
      final sdy = center.dy - e.position.dy;
      final snareDist2 = sdx * sdx + sdy * sdy;
      if (snareDist2 > cp.snareRadius * cp.snareRadius) continue;

      moveSpeedMult = min(moveSpeedMult, cp.snareMoveMultiplier);
      final toSnare = atan2(sdy, sdx);
      var snareDiff = toSnare - e.angle;
      while (snareDiff > pi) {
        snareDiff -= pi * 2;
      }
      while (snareDiff < -pi) {
        snareDiff += pi * 2;
      }
      e.angle += snareDiff * 1.8 * dt;
    }

    switch (e.behavior) {
      case EnemyBehavior.aggressive:
        // Chase the player — sentinels within 700, wisps within 400
        final chaseRange = e.tier == EnemyTier.sentinel ? 700.0 : 400.0;
        if (distToShip < chaseRange) {
          // Smooth turn toward player
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 3.0 * dt;
        } else if (e.driftTimer <= 0) {
          e.angle += (Random().nextDouble() - 0.5) * 1.5;
          e.driftTimer = 1.5 + Random().nextDouble() * 2;
        }
        break;

      case EnemyBehavior.drifting:
        // Small drifters act like ambient flyers: they scatter if approached.
        if (!e.provoked &&
            (e.tier == EnemyTier.wisp || e.tier == EnemyTier.drone) &&
            distToShip < 240) {
          var diff = (toShip + pi) - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 3.5 * dt;
        } else if (e.driftTimer <= 0) {
          e.angle += (Random().nextDouble() - 0.5) * 1.0;
          e.driftTimer = 2 + Random().nextDouble() * 4;
        }
        break;

      case EnemyBehavior.feeding:
        // Orbit slowly near homePos; if player gets very close, scatter away
        if (e.homePos != null) {
          var hx = e.homePos!.dx - e.position.dx;
          var hy = e.homePos!.dy - e.position.dy;
          if (hx > ww / 2) hx -= ww;
          if (hx < -ww / 2) hx += ww;
          if (hy > wh / 2) hy -= wh;
          if (hy < -wh / 2) hy += wh;
          final distHome = sqrt(hx * hx + hy * hy);

          // Lazy orbit near home
          if (distHome > 100) {
            // Drift back toward home
            final toHome = atan2(hy, hx);
            var diff = toHome - e.angle;
            while (diff > pi) {
              diff -= pi * 2;
            }
            while (diff < -pi) {
              diff += pi * 2;
            }
            e.angle += diff * 1.5 * dt;
          } else {
            // Gentle circular drift
            e.angle += 0.3 * dt;
          }

          // If player is close, flee briefly (not aggro, just skittish)
          if (distToShip < 240 && !e.provoked) {
            e.angle = toShip + pi; // face away
          }
        }
        break;

      case EnemyBehavior.territorial:
        // Patrol around homePos; if player enters aggroRadius → attack
        if (distToShip < e.aggroRadius) {
          // Intruder! Chase them
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 2.5 * dt;
        } else if (e.homePos != null) {
          // Patrol: orbit around homePos
          var hx = e.homePos!.dx - e.position.dx;
          var hy = e.homePos!.dy - e.position.dy;
          if (hx > ww / 2) hx -= ww;
          if (hx < -ww / 2) hx += ww;
          if (hy > wh / 2) hy -= wh;
          if (hy < -wh / 2) hy += wh;
          final distHome = sqrt(hx * hx + hy * hy);
          if (distHome > 180) {
            final toHome = atan2(hy, hx);
            var diff = toHome - e.angle;
            while (diff > pi) {
              diff -= pi * 2;
            }
            while (diff < -pi) {
              diff += pi * 2;
            }
            e.angle += diff * 2.0 * dt;
          } else {
            // Slow patrol orbit
            e.angle += 0.5 * dt;
          }
        }
        break;

      case EnemyBehavior.stalking:
        // Keep distance from player; if ship HP is low → rush in
        final lowHp = shipHealth <= 2.0;
        if (lowHp && distToShip < 800) {
          // Strike! Rush toward the wounded player
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 4.0 * dt;
          // Speed boost when attacking
          e.speed = 120;
        } else if (distToShip < e.stalkDistance - 50) {
          // Too close — back off
          e.angle = toShip + pi;
        } else if (distToShip > e.stalkDistance + 100) {
          // Too far — approach
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 1.5 * dt;
        } else {
          // Good distance — orbit laterally
          var diff = (toShip + pi / 2) - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 1.0 * dt;
        }
        break;
      case EnemyBehavior.swarming:
        // Swarm: cluster toward player and nearby swarmers,
        // but do not commit from too far away unless provoked.
        if (e.provoked || distToShip < 520) {
          var diff = toShip - e.angle;
          while (diff > pi) {
            diff -= pi * 2;
          }
          while (diff < -pi) {
            diff += pi * 2;
          }
          e.angle += diff * 3.5 * dt;
        }
        // Flock: gravitate toward nearby swarmers
        double fcx = 0, fcy = 0;
        int flockN = 0;
        for (final other in enemies) {
          if (other == e ||
              other.dead ||
              other.behavior != EnemyBehavior.swarming) {
            continue;
          }
          final fdx2 = other.position.dx - e.position.dx;
          final fdy2 = other.position.dy - e.position.dy;
          if (fdx2 * fdx2 + fdy2 * fdy2 < 200 * 200) {
            fcx += other.position.dx;
            fcy += other.position.dy;
            flockN++;
          }
        }
        if (flockN > 0) {
          final cx2 = fcx / flockN;
          final cy2 = fcy / flockN;
          final toCenter = atan2(cy2 - e.position.dy, cx2 - e.position.dx);
          var fDiff = toCenter - e.angle;
          while (fDiff > pi) {
            fDiff -= pi * 2;
          }
          while (fDiff < -pi) {
            fDiff += pi * 2;
          }
          e.angle += fDiff * 1.5 * dt;
        }
        break;
    }

    // Move
    e.position = _wrap(
      Offset(
        e.position.dx + cos(e.angle) * e.speed * moveSpeedMult * dt,
        e.position.dy + sin(e.angle) * e.speed * moveSpeedMult * dt,
      ),
    );

    // Despawn distance depends on behavior
    final despawnDist = e.whirlIndex >= 0
        ? 4000.0 // whirl enemies persist longer
        : (e.behavior == EnemyBehavior.feeding ||
              e.behavior == EnemyBehavior.territorial)
        ? 2500.0 // persistent near their zone
        : 1500.0;
    if (distToShip > despawnDist) {
      e.dead = true;
    }
  }

  /// Boss lair proximity detection, activation, and respawn logic.
  void _updateBossLairs(double dt) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    for (final lair in bossLairs) {
      // Tick respawn timers on defeated lairs
      if (lair.state == BossLairState.defeated) {
        lair.respawnTimer -= dt;
      }

      // Check activation: player enters lair radius
      if (lair.state == BossLairState.waiting && activeBoss == null) {
        var dx = lair.position.dx - ship.pos.dx;
        var dy = lair.position.dy - ship.pos.dy;
        if (dx > ww / 2) dx -= ww;
        if (dx < -ww / 2) dx += ww;
        if (dy > wh / 2) dy -= wh;
        if (dy < -wh / 2) dy += wh;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < BossLair.activationRadius) {
          _spawnBossFromLair(lair);
        }
      }
    }

    // Remove fully expired defeated lairs
    bossLairs.removeWhere(
      (l) => l.state == BossLairState.defeated && l.respawnTimer <= 0,
    );

    // Maintain at least 3 waiting boss lairs in the world
    final waitingCount = bossLairs
        .where((l) => l.state == BossLairState.waiting)
        .length;
    if (waitingCount < 3 && activeBoss == null) {
      final needed = 3 - waitingCount;
      for (int i = 0; i < needed; i++) {
        bossLairs.add(
          BossLair.generate(
            rng: Random(),
            worldSize: world_.worldSize,
            planets: world_.planets,
            whirls: galaxyWhirls,
            existing: bossLairs,
          ),
        );
      }
    }

    // Ensure at least 1 dormant whirl exists at all times
    final hasDormant = galaxyWhirls.any((w) => w.state == WhirlState.dormant);
    if (!hasDormant && activeWhirl == null) {
      _respawnWhirl();
    }
  }

  void _spawnBossFromLair(BossLair lair) {
    lair.state = BossLairState.fighting;

    final lvl = lair.level;
    final healthScale =
        CosmicBalance.bossHealthScale(lvl) * (1.0 + _bossesDefeated * 0.05);
    final speedScale = CosmicBalance.bossSpeedScale(lvl);
    final radiusBonus = CosmicBalance.bossRadiusBonus(lvl);

    activeBoss = CosmicBoss(
      position: lair.position,
      name: lair.template.name,
      element: lair.template.element,
      level: lvl,
      radius: lair.template.radius + radiusBonus,
      maxHealth: lair.template.health * healthScale,
      speed: lair.template.speed * speedScale,
      angle: Random().nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${lair.template.name}');
  }

  /// Respawn a single galaxy whirl at a new random position.
  void _respawnWhirl() {
    final rng = Random();
    const margin = 3000.0;
    const minPlanetDist = 2500.0;
    const minWhirlDist = 4000.0;
    final elements = kElementColors.keys.toList();

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (world_.worldSize.width - margin * 2),
        margin + rng.nextDouble() * (world_.worldSize.height - margin * 2),
      );
      tries++;
    } while (tries < 200 &&
        (world_.planets.any(
              (p) => (p.position - pos).distance < minPlanetDist,
            ) ||
            galaxyWhirls.any(
              (w) => (w.position - pos).distance < minWhirlDist,
            )));

    galaxyWhirls.add(
      GalaxyWhirl(
        position: pos,
        element: elements[rng.nextInt(elements.length)],
        level: rng.nextInt(10) + 1,
        radius: 50 + rng.nextDouble() * 30,
        totalWaves: 3 + rng.nextInt(3),
      ),
    );
  }

  void _spawnBoss() {
    final rng = Random();
    final template = kBossTemplates[rng.nextInt(kBossTemplates.length)];
    final lvl = rng.nextInt(10) + 1; // random level 1-10

    // Spawn near the matching element's planet
    final matchingPlanet = world_.planets.firstWhere(
      (p) => p.element == template.element,
      orElse: () => world_.planets[rng.nextInt(world_.planets.length)],
    );
    final angle = rng.nextDouble() * pi * 2;
    final orbitDist =
        matchingPlanet.radius * 4.0 + 100 + rng.nextDouble() * 200;
    final sx = matchingPlanet.position.dx + cos(angle) * orbitDist;
    final sy = matchingPlanet.position.dy + sin(angle) * orbitDist;
    final pos = _wrap(Offset(sx, sy));

    final healthScale =
        CosmicBalance.bossHealthScale(lvl) * (1.0 + _bossesDefeated * 0.05);
    final speedScale = CosmicBalance.bossSpeedScale(lvl);
    final radiusBonus = CosmicBalance.bossRadiusBonus(lvl);

    activeBoss = CosmicBoss(
      position: pos,
      name: template.name,
      element: template.element,
      level: lvl,
      radius: template.radius + radiusBonus,
      maxHealth: template.health * healthScale,
      speed: template.speed * speedScale,
      angle: rng.nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${template.name}');
  }

  /// Spawn a guaranteed boss when a planet is first discovered.
  /// Difficulty scales with total number of planets discovered.
  void _spawnDiscoveryBoss(CosmicPlanet planet) {
    if (activeBoss != null) return; // don't override an active boss

    final rng = Random();
    // Find a template matching the planet's element, fallback to random
    final matching = kBossTemplates.where((t) => t.element == planet.element);
    final template = matching.isNotEmpty
        ? matching.elementAt(rng.nextInt(matching.length))
        : kBossTemplates[rng.nextInt(kBossTemplates.length)];

    // Level = number of discovered planets, capped to the combat level range.
    final discovered = world_.planets.where((p) => p.discovered).length;
    final lvl = discovered.clamp(1, CosmicBalance.maxCombatLevel);

    // Spawn near the discovered planet
    final angle = rng.nextDouble() * pi * 2;
    final orbitDist = planet.radius * 4.0 + 100 + rng.nextDouble() * 150;
    final sx = planet.position.dx + cos(angle) * orbitDist;
    final sy = planet.position.dy + sin(angle) * orbitDist;
    final pos = _wrap(Offset(sx, sy));

    final healthScale =
        CosmicBalance.bossHealthScale(lvl) * (1.0 + _bossesDefeated * 0.05);
    final speedScale = CosmicBalance.bossSpeedScale(lvl);
    final radiusBonus = CosmicBalance.bossRadiusBonus(lvl);

    activeBoss = CosmicBoss(
      position: pos,
      name: template.name,
      element: template.element,
      level: lvl,
      radius: template.radius + radiusBonus,
      maxHealth: template.health * healthScale,
      speed: template.speed * speedScale,
      angle: rng.nextDouble() * pi * 2,
    );

    final bossTypeTag = switch (bossTypeForLevel(lvl)) {
      BossType.charger => '⚡',
      BossType.gunner => '🔫',
      BossType.warden => '👑',
    };
    onBossSpawned?.call('$bossTypeTag Lv$lvl ${template.name}');
  }

  void _updateBossAI(CosmicBoss boss, double dt) {
    boss.phaseTimer += dt;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    // Shared: wrapped distance & angle to player
    var dx = ship.pos.dx - boss.position.dx;
    var dy = ship.pos.dy - boss.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;

    final toShip = atan2(dy, dx);
    final dist = sqrt(dx * dx + dy * dy);

    switch (boss.type) {
      case BossType.charger:
        _updateChargerBoss(boss, dt, toShip, dist);
      case BossType.gunner:
        _updateGunnerBoss(boss, dt, toShip, dist);
      case BossType.warden:
        _updateWardenBoss(boss, dt, toShip, dist);
    }
  }

  // ────────────────────────────────────────────────
  // CHARGER BOSS (Lv 1-3)
  //  Behaviour: approach player, then charge in a straight line,
  //  brief recovery pause, repeat. Contact damage only.
  // ────────────────────────────────────────────────
  void _updateChargerBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    if (boss.charging) {
      // ── Mid-dash: fly in locked direction at high speed ──
      boss.chargeDashTimer -= dt;
      final dashSpeed = boss.baseSpeed * CosmicBoss.chargeSpeedMultiplier;
      boss.position = _wrap(
        Offset(
          boss.position.dx + cos(boss.chargeAngle) * dashSpeed * dt,
          boss.position.dy + sin(boss.chargeAngle) * dashSpeed * dt,
        ),
      );
      if (boss.chargeDashTimer <= 0) {
        boss.charging = false;
        boss.chargeTimer = CosmicBoss.chargeCooldown;
        boss.speed = boss.baseSpeed;
      }
    } else {
      // ── Approach player, turning smoothly ──
      var angleDiff = toShip - boss.angle;
      while (angleDiff > pi) {
        angleDiff -= pi * 2;
      }
      while (angleDiff < -pi) {
        angleDiff += pi * 2;
      }
      boss.angle += angleDiff * 2.5 * dt;

      // Move toward player, settle at ~180 range
      double moveAngle;
      if (dist > 220) {
        moveAngle = toShip;
      } else if (dist < 120) {
        moveAngle = toShip + pi;
      } else {
        moveAngle = toShip + pi / 2;
      }
      boss.position = _wrap(
        Offset(
          boss.position.dx + cos(moveAngle) * boss.speed * dt,
          boss.position.dy + sin(moveAngle) * boss.speed * dt,
        ),
      );

      // ── Charge cooldown ──
      boss.chargeTimer -= dt;
      if (boss.chargeTimer <= 0 && dist < 350 && dist > 80) {
        // Initiate charge!
        boss.charging = true;
        boss.chargeAngle = toShip; // lock direction
        boss.chargeDashTimer = CosmicBoss.chargeDashDuration;
        boss.speed = boss.baseSpeed * CosmicBoss.chargeSpeedMultiplier;
      }
    }
  }

  // ────────────────────────────────────────────────
  // GUNNER BOSS (Lv 4-7)
  //  Behaviour: orbit at range, fire projectiles at player,
  //  periodically raise a shield that absorbs damage.
  // ────────────────────────────────────────────────
  void _updateGunnerBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    // Smooth turn
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * 2.0 * dt;

    // Orbit at ~280 units
    double moveAngle;
    if (dist > 330) {
      moveAngle = toShip;
    } else if (dist < 220) {
      moveAngle = toShip + pi;
    } else {
      moveAngle = toShip + pi / 2;
    }
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * dt,
      ),
    );

    // ── Shoot projectiles at player ──
    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0 && dist < 500) {
      boss.shootTimer = CosmicBoss.shootCooldown;
      // Fire 1-2 aimed shots
      final shots = boss.level >= 6 ? 2 : 1;
      for (var s = 0; s < shots; s++) {
        final spread = (s - (shots - 1) / 2) * 0.15;
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: toShip + spread,
            element: boss.element,
            damage: CosmicBalance.bossProjectileDamage(
              level: boss.level,
              type: boss.type,
            ),
            speed: 220 + boss.level * 8.0,
          ),
        );
      }
    }

    // ── Shield mechanic ──
    boss.shieldTimer -= dt;
    if (boss.shieldUp) {
      if (boss.shieldTimer <= 0 || boss.shieldHealth <= 0) {
        boss.shieldUp = false;
        boss.shieldTimer = CosmicBoss.shieldCooldown;
      }
    } else {
      if (boss.shieldTimer <= 0) {
        boss.shieldUp = true;
        boss.shieldHealth = CosmicBalance.bossShieldHealth(boss.level);
        boss.shieldTimer = CosmicBoss.shieldDuration;
      }
    }
  }

  // ────────────────────────────────────────────────
  // WARDEN BOSS (Lv 8-10)
  //  Behaviour: fires projectile fans, summons minion enemies,
  //  enrages below 30% HP (faster attacks, speed boost).
  // ────────────────────────────────────────────────
  void _updateWardenBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    // Check for enrage transition
    if (!boss.enraged && boss.healthPct <= CosmicBoss.enrageThreshold) {
      boss.enraged = true;
      boss.speed = boss.baseSpeed * 1.6;
      boss.wardenPhase = 2;
    }

    // Smooth turn
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * (boss.enraged ? 3.0 : 1.8) * dt;

    // Orbit at ~250 units (closer when enraged)
    final orbitDist = boss.enraged ? 180.0 : 250.0;
    double moveAngle;
    if (dist > orbitDist + 60) {
      moveAngle = toShip;
    } else if (dist < orbitDist - 60) {
      moveAngle = toShip + pi;
    } else {
      moveAngle = toShip + pi / 2;
    }
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * dt,
      ),
    );

    // ── Projectile fan ──
    final spreadCd = boss.enraged
        ? CosmicBoss.spreadCooldown * 0.5
        : CosmicBoss.spreadCooldown;
    boss.spreadTimer -= dt;
    if (boss.spreadTimer <= 0 && dist < 600) {
      boss.spreadTimer = spreadCd;
      // Fire a fan of 5-8 projectiles (more when enraged)
      final count = boss.enraged ? 8 : 5;
      final arc = boss.enraged ? pi * 0.8 : pi * 0.5;
      for (var i = 0; i < count; i++) {
        final fanAngle = toShip + (i - (count - 1) / 2) * (arc / (count - 1));
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: fanAngle,
            element: boss.element,
            damage: CosmicBalance.bossProjectileDamage(
              level: boss.level,
              type: boss.type,
              enraged: boss.enraged,
            ),
            speed: 200 + boss.level * 10.0,
            radius: 5.0,
          ),
        );
      }
    }

    // ── Summon minions ──
    final summonCd = boss.enraged
        ? CosmicBoss.summonCooldown * 0.6
        : CosmicBoss.summonCooldown;
    boss.summonTimer -= dt;
    if (boss.summonTimer <= 0 && enemies.length < CosmicGame._maxEnemies) {
      boss.summonTimer = summonCd;
      _spawnWardenMinions(boss);
    }
  }

  /// Spawn 2-4 minion enemies near a Warden boss.
  void _spawnWardenMinions(CosmicBoss boss) {
    final rng = Random();
    final count = boss.enraged ? 4 : 2;
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = boss.radius * 2 + 20 + rng.nextDouble() * 40;
      final pos = _wrap(
        Offset(
          boss.position.dx + cos(angle) * dist,
          boss.position.dy + sin(angle) * dist,
        ),
      );
      final tier = rng.nextDouble() < 0.3 ? EnemyTier.sentinel : EnemyTier.wisp;
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: boss.element,
          tier: tier,
          radius: tier == EnemyTier.wisp
              ? 8 + rng.nextDouble() * 4
              : 14 + rng.nextDouble() * 6,
          health: CosmicBalance.enemyBaseHealth(tier) * 1.5,
          speed: 60 + rng.nextDouble() * 40,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: EnemyBehavior.aggressive,
          provoked: true,
        ),
      );
    }
  }

  /// Update all boss projectiles — move, age, and check collisions with ship.
  void _updateBossProjectiles(double dt) {
    for (var i = bossProjectiles.length - 1; i >= 0; i--) {
      final bp = bossProjectiles[i];
      bp.position = _wrap(
        Offset(
          bp.position.dx + cos(bp.angle) * bp.speed * dt,
          bp.position.dy + sin(bp.angle) * bp.speed * dt,
        ),
      );
      bp.life -= dt;
      if (bp.life <= 0) {
        bossProjectiles.removeAt(i);
        continue;
      }

      if (_consumeEscortInterceptionAt(
        bp.position,
        bp.radius,
        sparkColor: elementColor(bp.element),
      )) {
        bossProjectiles.removeAt(i);
        continue;
      }

      // Hit ship?
      if (!_shipDead && _shipInvincible <= 0) {
        final sdx = ship.pos.dx - bp.position.dx;
        final sdy = ship.pos.dy - bp.position.dy;
        final hitR = bp.radius + 14;
        if (sdx * sdx + sdy * sdy < hitR * hitR) {
          _damageShip(bp.damage);
          bossProjectiles.removeAt(i);
        }
      }
    }
  }

  // ── Boss kill helper ──────────────────────────────────

  void _handleBossKill(CosmicBoss boss) {
    boss.dead = true;
    _bossesDefeated++;
    _spawnKillVfx(boss.position, elementColor(boss.element), boss.radius, true);
    _spawnLootDrops(
      boss.position,
      boss.element,
      boss.shardReward,
      boss.particleReward,
    );
    // ── Item drops based on boss level ──
    _spawnBossItemDrops(boss);
    onBossDefeated?.call('Lv${boss.level} ${boss.name}');
  }

  /// Spawn item drops from a defeated boss.
  /// Lv 4-6: small chance for a standard harvester matching boss element.
  /// Lv 7-9: higher chance for harvester + small chance for portal key.
  /// Lv 10: guaranteed harvester + portal key + chance for guaranteed harvester.
  void _spawnBossItemDrops(CosmicBoss boss) {
    final rng = Random();
    final faction = factionForElement(boss.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    if (boss.level >= 10) {
      // Lv10: guaranteed standard harvester + portal key
      _spawnItemDrop(boss.position, harvesterKey);
      _spawnItemDrop(boss.position, portalKey);
      // 25% chance for a guaranteed (stabilized) harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, 'item.harvest_guaranteed');
      }
    } else if (boss.level >= 7) {
      // Lv7-9: 60% harvester, 30% portal key
      if (rng.nextDouble() < 0.60) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
      if (rng.nextDouble() < 0.30) {
        _spawnItemDrop(boss.position, portalKey);
      }
    } else if (boss.level >= 4) {
      // Lv4-6: 25% harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
    }
    // Lv1-3: no item drops (shards + particles only)
  }

  /// Spawn item drops from a completed galaxy whirl (horde).
  /// Lv 4-6: small chance for a harvester.
  /// Lv 7-9: decent chance for harvester.
  /// Lv 10: guaranteed harvester + portal key + chance for stabilized harvester.
  void _spawnWhirlItemDrops(GalaxyWhirl whirl) {
    final rng = Random();
    final faction = factionForElement(whirl.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    if (whirl.level >= 10) {
      // Lv10: guaranteed harvester + portal key
      _spawnItemDrop(whirl.position, harvesterKey);
      _spawnItemDrop(whirl.position, portalKey);
      // 15% chance for stabilized harvester (slightly lower than boss)
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, 'item.harvest_guaranteed');
      }
    } else if (whirl.level >= 7) {
      // Lv7-9: 40% harvester, 15% portal key
      if (rng.nextDouble() < 0.40) {
        _spawnItemDrop(whirl.position, harvesterKey);
      }
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, portalKey);
      }
    } else if (whirl.level >= 4) {
      // Lv4-6: 15% harvester
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, harvesterKey);
      }
    }
  }

  /// Spawn a single collectible item drop at a position.
  void _spawnItemDrop(Offset pos, String itemKey) {
    final rng = Random();
    final angle = rng.nextDouble() * pi * 2;
    final speed = 40.0 + rng.nextDouble() * 50;
    final isPortalKey = itemKey.contains('portal_key');
    final isGuaranteed = itemKey.contains('guaranteed');
    final color = isGuaranteed
        ? const Color(0xFFFFD700) // gold
        : isPortalKey
        ? const Color(0xFF00E5FF) // cyan
        : const Color(0xFF76FF03); // green
    lootDrops.add(
      LootDrop(
        position: Offset(pos.dx + cos(angle) * 12, pos.dy + sin(angle) * 12),
        velocity: Offset(cos(angle) * speed, sin(angle) * speed),
        type: LootType.item,
        amount: 1,
        itemKey: itemKey,
        color: color,
      ),
    );
  }

  // ── VFX helpers ────────────────────────────────────────

  void _spawnKillVfx(Offset pos, Color color, double radius, bool isBoss) {
    final rng = Random();
    final count = isBoss ? 40 : 14;
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = (isBoss ? 150.0 : 100.0) + rng.nextDouble() * 200;
      final pSize = radius * (0.1 + rng.nextDouble() * 0.25);
      final c = rng.nextBool() ? color : Colors.white;
      vfxParticles.add(
        VfxParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: pSize,
          life: 0.5 + rng.nextDouble() * 0.4,
          color: c,
        ),
      );
    }
    // Shock ring(s)
    final ringCount = isBoss ? 3 : 1;
    for (var r = 0; r < ringCount; r++) {
      vfxRings.add(
        VfxShockRing(
          x: pos.dx,
          y: pos.dy,
          maxRadius: radius * (isBoss ? 6.0 + r * 2 : 4.0),
          color: color,
          expandSpeed: isBoss ? 500.0 : 350.0,
        ),
      );
    }
  }

  /// Spawn loot drops at a position (from enemy/boss death).
  void _spawnLootDrops(
    Offset pos,
    String element,
    int shardAmount,
    double particleAmount,
  ) {
    final rng = Random();

    // Astral Shards — 1-3 individual crystal drops
    if (shardAmount > 0) {
      final shardDrops = shardAmount.clamp(1, 3);
      final shardPer = (shardAmount / shardDrops).ceil();
      for (var i = 0; i < shardDrops; i++) {
        final angle = rng.nextDouble() * pi * 2;
        final speed = 50.0 + rng.nextDouble() * 60;
        lootDrops.add(
          LootDrop(
            position: Offset(pos.dx + cos(angle) * 8, pos.dy + sin(angle) * 8),
            velocity: Offset(cos(angle) * speed, sin(angle) * speed),
            type: LootType.astralShard,
            amount: i < shardDrops - 1
                ? shardPer
                : shardAmount - shardPer * (shardDrops - 1),
            color: const Color(0xFF7C4DFF),
          ),
        );
      }
    }

    // Element particles — sometimes drop (40% chance from enemies, always from bosses)
    if (particleAmount > 0) {
      final shouldDrop = shardAmount >= 10 || rng.nextDouble() < 0.4;
      if (shouldDrop) {
        final elemDrops = particleAmount <= 3 ? particleAmount.ceil() : 3;
        final elemPer = (particleAmount / elemDrops).ceil();
        for (var i = 0; i < elemDrops; i++) {
          final angle = rng.nextDouble() * pi * 2;
          final speed = 60.0 + rng.nextDouble() * 70;
          lootDrops.add(
            LootDrop(
              position: Offset(
                pos.dx + cos(angle) * 10,
                pos.dy + sin(angle) * 10,
              ),
              velocity: Offset(cos(angle) * speed, sin(angle) * speed),
              type: LootType.elementParticle,
              amount: i < elemDrops - 1
                  ? elemPer
                  : particleAmount.ceil() - elemPer * (elemDrops - 1),
              element: element,
              color: elementColor(element),
            ),
          );
        }
      }
    }

    // Health recovery orb — small chance for regular enemies, higher for bosses
    // Regular enemies: ~8% chance. Bosses (large shard drops): ~50% chance.
    final hpDropChance = shardAmount >= 10 ? 0.5 : 0.08;
    if (rng.nextDouble() < hpDropChance) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 50.0 + rng.nextDouble() * 60;
      lootDrops.add(
        LootDrop(
          position: Offset(pos.dx + cos(angle) * 8, pos.dy + sin(angle) * 8),
          velocity: Offset(cos(angle) * speed, sin(angle) * speed),
          type: LootType.healthOrb,
          amount: 1,
          color: const Color(0xFFFF6D6D), // soft red for health
        ),
      );
    }
  }

  // ── prismatic field rendering (aurora / northern lights) ──
  void _renderPrismaticField(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    final pf = prismaticField;
    final pp = pf.position;
    // Early-out if the field is fully off-screen
    if ((pp.dx - cx - screenW / 2).abs() > screenW / 2 + pf.radius + 200 ||
        (pp.dy - cy - screenH / 2).abs() > screenH / 2 + pf.radius + 200) {
      return;
    }

    final t = pf.life;

    // ── Cached render-to-texture for expensive blurred layers ──
    // Only rebuild the cached image every CosmicGame._prismaticCacheInterval seconds.
    if (_prismaticCachedImage == null ||
        (t - _prismaticCacheLife).abs() >= CosmicGame._prismaticCacheInterval) {
      _prismaticCachedImage?.dispose();
      _prismaticCachedImage = _buildPrismaticTexture(t, pf);
      _prismaticCacheLife = t;
    }

    // Draw the cached texture scaled to world coordinates
    final img = _prismaticCachedImage!;
    final texR =
        pf.radius + 80; // padding matches what _buildPrismaticTexture uses
    canvas.save();
    canvas.translate(pp.dx - texR, pp.dy - texR);
    canvas.scale(
      texR * 2 / CosmicGame._prismaticTexSize,
      texR * 2 / CosmicGame._prismaticTexSize,
    );
    canvas.drawImage(img, Offset.zero, Paint());
    canvas.restore();

    // ── Central prismatic ring (drawn every frame at full resolution) ──
    final ringR = pf.radius * 0.12;
    final cRingRotation = t * 0.5;
    canvas.save();
    canvas.translate(pp.dx, pp.dy);
    canvas.rotate(cRingRotation);
    canvas.drawCircle(
      Offset.zero,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.sweep(
          Offset.zero,
          [
            for (int i = 0; i <= 8; i++)
              PrismaticField.auroraColors[i % 8].withValues(
                alpha: 0.35 + 0.15 * sin(t * 1.2 + i * 0.9),
              ),
          ],
          [for (int i = 0; i <= 8; i++) i / 8.0],
        ),
    );
    // Inner glow fill
    canvas.drawCircle(
      Offset.zero,
      ringR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          ringR,
          [
            PrismaticField.auroraColors[((t * 0.15).floor()) % 8].withValues(
              alpha: 0.05,
            ),
            const Color(0x00000000),
          ],
          [0.0, 1.0],
        ),
    );
    canvas.restore();
    // 3 orbiting dots around the ring
    for (int d = 0; d < 3; d++) {
      final dAngle = t * 0.8 + d * pi * 2 / 3;
      final dx2 = pp.dx + cos(dAngle) * ringR;
      final dy2 = pp.dy + sin(dAngle) * ringR;
      canvas.drawCircle(
        Offset(dx2, dy2),
        2.0,
        Paint()
          ..color = PrismaticField.auroraColors[(d * 2 + (t * 0.2).floor()) % 8]
              .withValues(alpha: 0.45),
      );
    }

    // ── Label (drawn every frame) ──
    if (!prismaticRewardClaimed) {
      final ci = ((t * 0.3).floor()) % 8;
      final labelColor = Color.lerp(
        PrismaticField.auroraColors[ci],
        PrismaticField.auroraColors[(ci + 1) % 8],
        (t * 0.3) % 1.0,
      )!.withValues(alpha: 0.7);
      final labelTp = TextPainter(
        text: TextSpan(
          text: 'PRISMATIC AURORA',
          style: TextStyle(
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(
        canvas,
        Offset(pp.dx - labelTp.width / 2, pp.dy + pf.radius + 14),
      );
    }
  }

  /// Renders the expensive blurred aurora layers to a [CosmicGame._prismaticTexSize]²
  /// off-screen image. Called ~10 times/sec, NOT every frame.
  ui.Image _buildPrismaticTexture(double t, PrismaticField pf) {
    const sz = CosmicGame._prismaticTexSize;
    final texR = pf.radius + 80; // world-unit radius mapped to texture
    final scale = sz / (texR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    // All drawing is in texture-pixel space; center = field center.

    // ── 1. Soft radial glow with blur ──
    final glowR = pf.radius * scale;
    c.drawCircle(
      center,
      glowR,
      Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..shader = ui.Gradient.radial(
          center,
          glowR,
          [
            PrismaticField.auroraColors[((t * 0.08).floor()) % 8].withValues(
              alpha: 0.08,
            ),
            PrismaticField.auroraColors[((t * 0.08).floor() + 3) % 8]
                .withValues(alpha: 0.04),
            const Color(0x00000000),
          ],
          [0.0, 0.6, 1.0],
        ),
    );

    // ── 2. Aurora bands with blur (6 bands, lush look) ──
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: glowR)));
    for (int band = 0; band < 6; band++) {
      final bandPhase = band * 1.1 + t * 0.35;
      final colorIdx = ((band * 2 + (t * 0.08).floor()) % 8);
      final bandColor = PrismaticField.auroraColors[colorIdx].withValues(
        alpha: 0.06 + 0.03 * sin(t * 0.4 + band),
      );

      final path = Path();
      final bandY = center.dy - glowR * 0.7 + band * (glowR * 0.22);
      const segments = 16;
      for (int s = 0; s <= segments; s++) {
        final frac = s / segments;
        final x = center.dx - glowR + frac * glowR * 2;
        final y =
            bandY +
            sin(frac * pi * 3 + bandPhase) * glowR * 0.15 +
            sin(frac * pi * 5 + bandPhase * 1.3) * glowR * 0.06;
        if (s == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      for (int s = segments; s >= 0; s--) {
        final frac = s / segments;
        final x = center.dx - glowR + frac * glowR * 2;
        final y =
            bandY +
            glowR * 0.12 +
            sin(frac * pi * 3 + bandPhase + 0.5) * glowR * 0.08;
        path.lineTo(x, y);
      }
      path.close();
      c.drawPath(
        path,
        Paint()
          ..color = bandColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
      );
    }
    c.restore();

    // ── 3. Sparkles with blur ──
    final sparkRng = Random(42);
    for (int i = 0; i < 30; i++) {
      final sAngle = sparkRng.nextDouble() * pi * 2;
      final sDist = sparkRng.nextDouble() * glowR * 0.85;
      final sx = center.dx + cos(sAngle + t * 0.03 * (i % 3 + 1)) * sDist;
      final sy = center.dy + sin(sAngle + t * 0.02 * (i % 4 + 1)) * sDist;
      final sBright = (0.3 + 0.7 * sin(t * (1.0 + i * 0.15) + i)).clamp(
        0.0,
        1.0,
      );
      if (sBright < 0.2) continue;
      c.drawCircle(
        Offset(sx, sy),
        2.0 + sBright * 2.5,
        Paint()
          ..color = PrismaticField.auroraColors[i % 8].withValues(
            alpha: sBright * 0.5,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── 4. Edge ring with blur ──
    c.drawCircle(
      center,
      glowR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..shader = ui.Gradient.sweep(
          center,
          [
            for (int i = 0; i <= 8; i++)
              PrismaticField.auroraColors[i % 8].withValues(
                alpha: 0.15 + 0.08 * sin(t * 0.6 + i * 0.8),
              ),
          ],
          [for (int i = 0; i <= 8; i++) i / 8.0],
        ),
    );

    // ── 5. Light pillars (vertical glowing columns) ──
    for (int p = 0; p < 4; p++) {
      final px = center.dx - glowR * 0.6 + p * (glowR * 0.4);
      final pillarAlpha = 0.04 + 0.03 * sin(t * 0.3 + p * 1.5);
      c.drawRect(
        Rect.fromCenter(
          center: Offset(px, center.dy),
          width: glowR * 0.08,
          height: glowR * 1.6,
        ),
        Paint()
          ..color = PrismaticField.auroraColors[(p * 2 + (t * 0.1).floor()) % 8]
              .withValues(alpha: pillarAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the expensive blurred layers of the elemental nexus portal to an
  /// off-screen texture at ~10 fps. The gravitational well glow (blur 200),
  /// orbiting elemental glows (blur 30 × 4), void core gradient, and pulsing
  /// rings (blur 15 × 4) are all drawn here.
  ui.Image _buildNexusTexture(double riftPulse) {
    const sz = CosmicGame._nexusTexSize;
    const worldR = CosmicGame._nexusTexWorldR;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 1.8);

    // Huge dark gravitational well glow
    c.drawCircle(
      center,
      600 * scale,
      Paint()
        ..color = const Color(0xFF000000).withValues(alpha: 0.9)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 200 * scale),
    );

    // Four elemental glows orbiting
    const eColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF81D4FA), // Air
      Color(0xFF795548), // Earth
    ];
    for (var i = 0; i < 4; i++) {
      final a = riftPulse * 0.6 + i * pi / 2;
      final orbitR = (400.0 + 50 * sin(riftPulse * 2 + i)) * scale;
      final gx = center.dx + cos(a) * orbitR;
      final gy = center.dy + sin(a) * orbitR;
      c.drawCircle(
        Offset(gx, gy),
        40 * pulse * scale,
        Paint()
          ..color = eColors[i].withValues(alpha: 0.45 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * scale),
      );
    }

    // Void core
    c.drawCircle(
      center,
      275 * pulse * scale,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          275 * pulse * scale,
          [
            const Color(0xFF000000),
            const Color(0xFF000000),
            const Color(0xFF0A0015),
          ],
          [0.0, 0.6, 1.0],
        ),
    );

    // Pulsing dark rings with multi-element shimmer
    for (var i = 0; i < 4; i++) {
      final ringR = (300.0 + i * 90 + 30 * sin(riftPulse * 2.5 + i)) * scale;
      c.drawCircle(
        center,
        ringR,
        Paint()
          ..color = eColors[i].withValues(alpha: 0.18 - i * 0.03)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12.5 * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15 * scale),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the battle ring octagon + orbiting balls to an off-screen texture.
  ui.Image _buildBattleRingTexture(double riftPulse) {
    const sz = CosmicGame._battleRingTexSize;
    const worldR = CosmicGame._battleRingTexWorldR;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 1.5);
    const octR = BattleRing.visualRadius; // world-unit octagon radius

    // Subtle arena floor glow
    c.drawCircle(
      center,
      octR * 0.8 * scale,
      Paint()
        ..color = const Color(0xFF1A0A2E).withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 80 * scale),
    );

    // Octagon outline with golden glow
    final octPath = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8; // start rotated for flat top
      final x = center.dx + cos(a) * octR * scale;
      final y = center.dy + sin(a) * octR * scale;
      if (i == 0) {
        octPath.moveTo(x, y);
      } else {
        octPath.lineTo(x, y);
      }
    }
    octPath.close();

    // Outer glow
    c.drawPath(
      octPath,
      Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.25 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 * scale),
    );

    // Main ring stroke
    c.drawPath(
      octPath,
      Paint()
        ..color = const Color(0xFFFFD740).withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * scale,
    );

    // Inner glow ring (slightly smaller octagon)
    final innerPath = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8;
      final x = center.dx + cos(a) * octR * 0.85 * scale;
      final y = center.dy + sin(a) * octR * 0.85 * scale;
      if (i == 0) {
        innerPath.moveTo(x, y);
      } else {
        innerPath.lineTo(x, y);
      }
    }
    innerPath.close();
    c.drawPath(
      innerPath,
      Paint()
        ..color = const Color(0xFFFF6F00).withValues(alpha: 0.15 * pulse)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * scale),
    );

    // 8 orbiting energy balls around the octagon
    const ballColors = [
      Color(0xFFFF5252), // red
      Color(0xFF448AFF), // blue
      Color(0xFF69F0AE), // green
      Color(0xFFFFD740), // gold
      Color(0xFFE040FB), // magenta
      Color(0xFF00E5FF), // cyan
      Color(0xFFFF6E40), // deep orange
      Color(0xFFB388FF), // purple
    ];
    for (var i = 0; i < 8; i++) {
      final baseAngle = i * pi / 4;
      final a = baseAngle + riftPulse * 0.8 + sin(riftPulse * 1.2 + i) * 0.15;
      final orbitR = (octR + 60 + 15 * sin(riftPulse * 2.0 + i * 0.7)) * scale;
      final bx = center.dx + cos(a) * orbitR;
      final by = center.dy + sin(a) * orbitR;
      // Glow
      c.drawCircle(
        Offset(bx, by),
        18 * pulse * scale,
        Paint()
          ..color = ballColors[i].withValues(alpha: 0.4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
      );
      // Core
      c.drawCircle(
        Offset(bx, by),
        6 * scale,
        Paint()..color = ballColors[i].withValues(alpha: 0.9),
      );
    }

    // Corner accents at each octagon vertex
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 - pi / 8;
      final vx = center.dx + cos(a) * octR * scale;
      final vy = center.dy + sin(a) * octR * scale;
      c.drawCircle(
        Offset(vx, vy),
        8 * pulse * scale,
        Paint()
          ..color = const Color(0xFFFFD740).withValues(alpha: 0.6 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * scale),
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  /// Renders the pocket dimension blurred elements to an off-screen texture.
  ui.Image _buildPocketTexture(double riftPulse) {
    const sz = CosmicGame._pocketTexSize;
    // We need to cover the pocket radius + some margin
    final worldR = ElementalNexus.pocketRadius + 200;
    final scale = sz / (worldR * 2);
    final center = Offset(sz / 2, sz / 2);

    final recorder = ui.PictureRecorder();
    final c = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, sz.toDouble(), sz.toDouble()),
    );

    final pulse = 0.85 + 0.15 * sin(riftPulse * 2.0);

    // Pocket boundary glow (faint ring)
    c.drawCircle(
      center,
      ElementalNexus.pocketRadius * scale,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40 * scale
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 30 * scale),
    );

    // 4 elemental portal glows (only the blurred outer glow + rim ring)
    final portals = ElementalNexus.pocketPortalPositions(Offset.zero);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF795548), // Earth
      Color(0xFF81D4FA), // Air
    ];
    for (var i = 0; i < 4; i++) {
      final pp = Offset(
        center.dx + portals[i].dx * scale,
        center.dy + portals[i].dy * scale,
      );
      final col = portalColors[i];

      // Outer glow
      c.drawCircle(
        pp,
        80 * scale,
        Paint()
          ..color = col.withValues(alpha: 0.2 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 25 * scale),
      );

      // Rim ring with blur
      c.drawCircle(
        pp,
        50 * pulse * scale,
        Paint()
          ..color = col.withValues(alpha: 0.4 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * scale
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale),
      );
    }

    // Center marker glow
    c.drawCircle(
      center,
      20 * scale,
      Paint()
        ..color = const Color(0xFF7C4DFF).withValues(alpha: 0.12)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 * scale),
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  void _spawnHitSpark(Offset pos, Color color) {
    final rng = Random();
    for (var i = 0; i < 5; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final speed = 50.0 + rng.nextDouble() * 80;
      vfxParticles.add(
        VfxParticle(
          x: pos.dx,
          y: pos.dy,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          size: 1.5 + rng.nextDouble() * 1.5,
          life: 0.2 + rng.nextDouble() * 0.15,
          color: color,
          drag: 0.88,
        ),
      );
    }
  }

  /// Spawn explosion projectiles when a decoy is destroyed.
  void _spawnDecoyExplosion(Projectile decoy) {
    final pos = decoy.position;
    final count = decoy.deathExplosionCount;
    final dmg = decoy.deathExplosionDamage;
    final color = elementColor(decoy.element ?? 'Fire');

    // VFX: big explosion effect
    _spawnKillVfx(pos, color, 20, true);

    // Spawn damage projectiles in a ring
    for (var i = 0; i < count; i++) {
      final a = i * (pi * 2 / count);
      companionProjectiles.add(
        Projectile(
          position: Offset(pos.dx + cos(a) * 8, pos.dy + sin(a) * 8),
          angle: a,
          element: decoy.element,
          damage: dmg,
          life: 1.5,
          speedMultiplier: 0.8,
          radiusMultiplier: decoy.deathExplosionRadius,
          piercing: true,
          visualScale: 1.3,
        ),
      );
    }
  }

  void _damageShip(double damage) {
    if (_shipDead || _shipInvincible > 0) return;
    shipHealth -= damage;
    _shipInvincible = 0.65; // brief invincibility after hit

    // Hit flash particles around ship
    _spawnHitSpark(ship.pos, Colors.redAccent);

    if (shipHealth <= 0) {
      shipHealth = 0;
      _shipDead = true;
      _respawnTimer = 2.5; // 2.5s respawn delay
      shooting = false;
      // Death explosion
      _spawnKillVfx(ship.pos, const Color(0xFF00E5FF), 18, true);
      // Reset meter
      meter.reset();
      onMeterChanged();
      // Lose all unbanked Astral Shards on death.
      shipWallet.depositAll();
      onShipDied?.call();
    }
  }

  Offset? _nearestEscortTarget(Offset origin) {
    Offset? bestTarget;
    var bestDist2 = double.infinity;

    for (final e in enemies) {
      if (e.dead) continue;
      final d2 = (e.position - origin).distanceSquared;
      if (d2 < bestDist2) {
        bestDist2 = d2;
        bestTarget = e.position;
      }
    }

    if (battleRing.inBattle) {
      for (final rm in ringMinions) {
        if (rm.dead) continue;
        final d2 = (rm.position - origin).distanceSquared;
        if (d2 < bestDist2) {
          bestDist2 = d2;
          bestTarget = rm.position;
        }
      }
    }

    if (activeBoss != null && !activeBoss!.dead) {
      final d2 = (activeBoss!.position - origin).distanceSquared;
      if (d2 < bestDist2) {
        bestTarget = activeBoss!.position;
      }
    }

    return bestTarget;
  }

  Projectile _createEscortTurretShot(Projectile orb, Offset targetPos) {
    final angle = atan2(
      targetPos.dy - orb.position.dy,
      targetPos.dx - orb.position.dx,
    );
    switch (orb.element) {
      case 'Crystal':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.7,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.35,
          visualScale: 0.95,
          piercing: true,
          bounceCount: 1,
        );
      case 'Water':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.9,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.45,
          visualScale: 1.05,
          homing: orb.turretHomingStrength > 0,
          homingStrength: orb.turretHomingStrength,
        );
      case 'Lightning':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.15,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.0,
          visualScale: 0.82,
          bounceCount: 2,
        );
      case 'Lava':
      case 'Earth':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.9,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.5,
          visualScale: 1.15,
        );
      case 'Spirit':
      case 'Dark':
      case 'Blood':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.8,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.2,
          visualScale: 1.0,
          piercing: true,
          homing: orb.turretHomingStrength > 0,
          homingStrength: orb.turretHomingStrength,
        );
      case 'Plant':
      case 'Poison':
      case 'Fire':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.6,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.2,
          visualScale: 0.96,
          homing: orb.turretHomingStrength > 0,
          homingStrength: orb.turretHomingStrength,
          trailInterval: orb.element == 'Fire' ? 0.12 : 0,
          trailDamage: orb.element == 'Fire' ? orb.turretDamage * 0.2 : 0,
          trailLife: orb.element == 'Fire' ? 0.45 : 0,
        );
      case 'Steam':
      case 'Mud':
      case 'Ice':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.7,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.35,
          visualScale: 1.05,
        );
      case 'Dust':
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 0.95,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 0.92,
          visualScale: 0.74,
        );
      default:
        return Projectile(
          position: orb.position,
          angle: angle,
          element: orb.element,
          damage: orb.turretDamage,
          life: 1.5,
          speedMultiplier: orb.turretSpeedMultiplier,
          radiusMultiplier: 1.15,
          visualScale: 0.9,
          homing: orb.turretHomingStrength > 0,
          homingStrength: orb.turretHomingStrength,
        );
    }
  }

  bool _consumeEscortInterceptionAt(
    Offset hostilePosition,
    double hostileRadius, {
    Color sparkColor = const Color(0xFFFFF3C8),
  }) {
    for (var i = companionProjectiles.length - 1; i >= 0; i--) {
      final orb = companionProjectiles[i];
      if (orb.interceptCharges <= 0 || orb.interceptRadius <= 0) continue;
      final hitR = hostileRadius + orb.interceptRadius;
      final delta = orb.position - hostilePosition;
      if (delta.distanceSquared > hitR * hitR) continue;

      orb.interceptCharges--;
      _spawnHitSpark(orb.position, sparkColor);
      _spawnHitSpark(hostilePosition, sparkColor);
      if (orb.interceptCharges <= 0) {
        companionProjectiles.removeAt(i);
      }
      return true;
    }
    return false;
  }

  /// Percentage of world discovered (for display).
  double get discoveryPct {
    final totalCells =
        (world_.worldSize.width / CosmicGame.fogCellSize).ceil() *
        (world_.worldSize.height / CosmicGame.fogCellSize).ceil();
    if (totalCells == 0) return 0;
    return revealedCells.length / totalCells;
  }

  /// Get fog state for persistence.
  CosmicFogState getFogState(int seed) => CosmicFogState(
    worldSeed: seed,
    discoveredIndices: world_.planets.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    discoveredPoiIndices: spacePOIs.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    discoveredContestArenaIndices: world_.contestArenas.indexed
        .where((e) => e.$2.discovered)
        .map((e) => e.$1)
        .toSet(),
    revealedCells: Set<int>.from(revealedCells),
    shipX: ship.pos.dx,
    shipY: ship.pos.dy,
  );

  /// Restore fog state — planets, revealed cells, and ship position.
  void restoreFogState(CosmicFogState state) {
    for (final idx in state.discoveredIndices) {
      if (idx < world_.planets.length) {
        world_.planets[idx].discovered = true;
      }
    }
    for (final idx in state.discoveredPoiIndices) {
      if (idx < spacePOIs.length) {
        spacePOIs[idx].discovered = true;
      }
    }
    for (final idx in state.discoveredContestArenaIndices) {
      if (idx < world_.contestArenas.length) {
        world_.contestArenas[idx].discovered = true;
      }
    }
    // Restore ALL revealed cells directly
    revealedCells.addAll(state.revealedCells);
    // Restore ship position
    if (state.shipX >= 0 && state.shipY >= 0) {
      ship.pos = Offset(state.shipX, state.shipY);
    }
  }

  /// Restore collected star dust from persisted set.
  void restoreStarDust(Set<int> collected) {
    for (final dust in starDusts) {
      if (collected.contains(dust.index)) {
        dust.collected = true;
      }
    }
    collectedDustCount = collected.length;
    syncStarDustScannerAvailability();
  }

  /// Restore already-collected contest hint notes from persisted IDs.
  void restoreCollectedContestHints(Set<String> collectedIds) {
    if (collectedIds.isEmpty) return;
    for (final note in contestHintNotes) {
      if (collectedIds.contains(note.id)) {
        note.collected = true;
      }
    }
  }

  bool get hasRemainingStarDust => collectedDustCount < starDusts.length;

  int? get starDustScannerTargetIndex => _starDustScannerTargetIndex;

  StarDust? get starDustScannerTarget {
    final idx = _starDustScannerTargetIndex;
    if (idx == null || idx < 0 || idx >= starDusts.length) return null;
    final dust = starDusts[idx];
    return dust.collected ? null : dust;
  }

  int? consumeCompletedScannerDustIndex() {
    final idx = _scannerCompletedDustIndex;
    _scannerCompletedDustIndex = null;
    return idx;
  }

  String? activateStarDustScanner({int shardCost = 50}) {
    syncStarDustScannerAvailability();
    final scanner = _findStarDustScannerPoi();
    if (scanner == null) {
      return 'All star dust has been collected. Scanner offline.';
    }
    if (!hasRemainingStarDust) {
      return 'All star dust has been collected. Scanner offline.';
    }
    if (_starDustScannerTargetIndex != null) {
      return 'Scanner already locked. Follow the radar beeper to your target.';
    }
    if (shipWallet.shards < shardCost) {
      return 'Not enough shards. Need $shardCost to activate the scanner.';
    }

    final target = _nearestUncollectedStarDust();
    if (target == null) {
      return 'No uncollected star dust found.';
    }

    shipWallet.shards -= shardCost;
    _starDustScannerTargetIndex = target.index;
    _relocateStarDustScanner(scanner);
    return null;
  }

  /// Get the nearest rift portal the ship is close to (if any).
  RiftPortal? get nearestRift => _nearestRift;

  /// Check if ship is near any rift portal.
  bool get isNearRift => _nearestRift != null;

  /// Check if ship is near the elemental nexus portal.
  bool get isNearNexus => _isNearNexus;

  // ─────────────────────────────────────────────────────────
  // NEXUS POCKET DIMENSION
  // ─────────────────────────────────────────────────────────

  /// Enter the pocket dimension — call from cosmic_screen.
  void enterNexusPocket() {
    final nx = elementalNexus;
    nx.prePocketShipPos = ship.pos;
    nx.inPocket = true;
    nx.phase = NexusPhase.choosingPortal;
    inNexusPocket = true;
    // Teleport ship to nexus center
    ship.pos = nx.position;
    _dragTarget = null;
    joystickDirection = null;
  }

  /// Exit the pocket dimension — returns ship to pre-pocket position.
  void exitNexusPocket() {
    final nx = elementalNexus;
    if (nx.prePocketShipPos != null) {
      ship.pos = nx.prePocketShipPos!;
    }
    nx.inPocket = false;
    nx.phase = NexusPhase.outside;
    nx.chosenElement = null;
    nx.harvesterAwarded = false;
    inNexusPocket = false;
    nearPocketPortalElement = null;
    _dragTarget = null;
    joystickDirection = null;
  }

  void _updatePocketMode(double dt) {
    _riftPulse += dt; // for animation

    final center = elementalNexus.position;
    // Clamp ship within pocket radius
    final dx = ship.pos.dx - center.dx;
    final dy = ship.pos.dy - center.dy;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > ElementalNexus.pocketRadius) {
      final scale = ElementalNexus.pocketRadius / dist;
      ship.pos = Offset(center.dx + dx * scale, center.dy + dy * scale);
    }

    // Check proximity to pocket portals
    final portals = ElementalNexus.pocketPortalPositions(center);
    String? closest;
    double closestDist = double.infinity;
    for (var i = 0; i < 4; i++) {
      final pd = (portals[i] - ship.pos).distance;
      if (pd < ElementalNexus.portalInteractR && pd < closestDist) {
        closestDist = pd;
        closest = ElementalNexus.pocketElements[i];
      }
    }
    if (closest != nearPocketPortalElement) {
      nearPocketPortalElement = closest;
      onNearPocketPortal?.call(closest);
    }
  }

  void _renderPocket(Canvas canvas) {
    final center = elementalNexus.position;
    final cx = camX;
    final cy = camY;
    final screenW = size.x;
    final screenH = size.y;

    canvas.save();
    canvas.translate(-cx, -cy);

    // Dark void background
    canvas.drawRect(
      Rect.fromLTWH(cx, cy, screenW, screenH),
      Paint()..color = const Color(0xFF020008),
    );

    // Subtle ambient stars
    final rng = Random(42);
    final starPaint = Paint();
    for (var i = 0; i < 60; i++) {
      final sx =
          center.dx +
          (rng.nextDouble() - 0.5) * ElementalNexus.pocketRadius * 2.5;
      final sy =
          center.dy +
          (rng.nextDouble() - 0.5) * ElementalNexus.pocketRadius * 2.5;
      final twinkle = 0.3 + 0.7 * sin(_elapsed * (0.5 + rng.nextDouble()) + i);
      starPaint.color = Colors.white.withValues(
        alpha: (0.1 + rng.nextDouble() * 0.2) * twinkle,
      );
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + rng.nextDouble() * 1.2,
        starPaint,
      );
    }

    // ── Cached blurred layers (boundary glow, portal glows, rim rings, center glow) ──
    if (_pocketCachedImage == null ||
        (_riftPulse - _pocketCacheTime).abs() >=
            CosmicGame._pocketCacheInterval) {
      _pocketCachedImage?.dispose();
      _pocketCachedImage = _buildPocketTexture(_riftPulse);
      _pocketCacheTime = _riftPulse;
    }

    final pocketWorldR = ElementalNexus.pocketRadius + 200;
    final img = _pocketCachedImage!;
    canvas.save();
    canvas.translate(center.dx - pocketWorldR, center.dy - pocketWorldR);
    canvas.scale(
      pocketWorldR * 2 / CosmicGame._pocketTexSize,
      pocketWorldR * 2 / CosmicGame._pocketTexSize,
    );
    canvas.drawImage(img, Offset.zero, Paint());
    canvas.restore();

    // ── Per-frame elements (cheap: no blur) ──
    final pulse = 0.85 + 0.15 * sin(_riftPulse * 2.0);

    // 4 elemental portals — dark cores, orbiting sparks, labels
    final portals = ElementalNexus.pocketPortalPositions(center);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFF795548), // Earth
      Color(0xFF81D4FA), // Air
    ];
    const portalLabels = ['FIRE', 'WATER', 'EARTH', 'AIR'];

    for (var i = 0; i < 4; i++) {
      final pp = portals[i];
      final col = portalColors[i];

      // Dark core (gradient, no blur)
      canvas.drawCircle(
        pp,
        45 * pulse,
        Paint()
          ..shader = ui.Gradient.radial(
            pp,
            45 * pulse,
            [const Color(0xFF000000), col.withValues(alpha: 0.15)],
            [0.0, 1.0],
          ),
      );

      // Orbiting sparks (tiny dots, no blur)
      for (var j = 0; j < 5; j++) {
        final a = _riftPulse * 1.2 + j * pi * 2 / 5 + i * pi / 4;
        final sr = 55.0;
        canvas.drawCircle(
          Offset(pp.dx + cos(a) * sr, pp.dy + sin(a) * sr),
          3 * pulse,
          Paint()..color = col.withValues(alpha: 0.5 * pulse),
        );
      }

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: portalLabels[i],
          style: TextStyle(
            color: col.withValues(alpha: 0.85),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pp.dx - tp.width / 2, pp.dy + 60));
    }

    // Center marker dot (no blur)
    canvas.drawCircle(
      center,
      6,
      Paint()..color = const Color(0xFF7C4DFF).withValues(alpha: 0.3),
    );

    // Ship
    if (!_shipDead) {
      ship.render(canvas, _elapsed, skin: activeShipSkin);
    }

    canvas.restore();
  }

  SpacePOI? _findStarDustScannerPoi() {
    for (final poi in spacePOIs) {
      if (poi.type == POIType.stardustScanner) return poi;
    }
    return null;
  }

  StarDust? _nearestUncollectedStarDust() {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    StarDust? best;
    double bestDist = double.infinity;
    for (final dust in starDusts) {
      if (dust.collected) continue;
      var dx = dust.position.dx - ship.pos.dx;
      var dy = dust.position.dy - ship.pos.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = dust;
      }
    }
    return best;
  }

  void syncStarDustScannerAvailability() {
    final scanner = _findStarDustScannerPoi();
    if (!hasRemainingStarDust) {
      if (scanner != null) {
        spacePOIs.remove(scanner);
      }
      _starDustScannerTargetIndex = null;
      if (nearMarket?.type == POIType.stardustScanner) {
        nearMarket = null;
        onNearMarket?.call(null);
      }
      return;
    }

    if (scanner == null) {
      final newScanner = SpacePOI(
        position: ship.pos,
        type: POIType.stardustScanner,
        element: 'Light',
        radius: 120,
        discovered: false,
      );
      spacePOIs.add(newScanner);
      _relocateStarDustScanner(newScanner);
    }
  }

  void _relocateStarDustScanner(SpacePOI scanner) {
    final rng = Random();
    const margin = 2200.0;
    const minPlanetDist = 2600.0;
    const minPoiDist = 2200.0;
    const minShipDist = 7000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        ((pos - ship.pos).distance < minShipDist ||
            world_.planets.any(
              (p) => (p.position - pos).distance < minPlanetDist,
            ) ||
            spacePOIs.any(
              (p) => p != scanner && (p.position - pos).distance < minPoiDist,
            )));

    scanner.position = pos;
    scanner.discovered = false;
    scanner.interacted = false;
    scanner.life = 0;
  }

  /// Relocate a rift portal to a new random position far from planets and other rifts.
  void relocateRift(RiftPortal rift) {
    final rng = Random();
    const margin = 1920.0;
    const minDist = 3840.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final obstacles = <Offset>[
      ...world_.planets.map((p) => p.position),
      ...world_.riftPortals.where((r) => r != rift).map((r) => r.position),
    ];
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 300 && obstacles.any((o) => (o - pos).distance < minDist));
    rift.position = pos;
    _nearestRift = null;
    _wasNearRift = false;
  }

  void _relocateMeteorShower(SpacePOI shower) {
    final rng = Random();
    const margin = 2200.0;
    const minPlanetDist = 2600.0;
    const minOtherPoiDist = 2400.0;
    const minShipDist = 9000.0;
    const minRelocateDist = 9000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final oldPos = shower.position;

    double wrappedDist(Offset a, Offset b) {
      var dx = (a.dx - b.dx).abs();
      var dy = (a.dy - b.dy).abs();
      if (dx > ww / 2) dx = ww - dx;
      if (dy > wh / 2) dy = wh - dy;
      return sqrt(dx * dx + dy * dy);
    }

    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 500 &&
        (wrappedDist(pos, ship.pos) < minShipDist ||
            wrappedDist(pos, oldPos) < minRelocateDist ||
            world_.planets.any(
              (p) => wrappedDist(pos, p.position) < minPlanetDist,
            ) ||
            spacePOIs.any(
              (p) =>
                  p != shower &&
                  p.type != POIType.comet &&
                  wrappedDist(pos, p.position) < minOtherPoiDist,
            )));

    shower.position = pos;
    shower.angle = rng.nextDouble() * 2 * pi;
    shower.speed = 0;
    shower.life = 0;
    shower.discovered = false;
    shower.interacted = false;
  }

  void _respawnSwarm(ParticleSwarm swarm) {
    final rng = Random();
    const margin = 1920.0;
    const minDist = 2000.0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    final obstacles = <Offset>[
      ...world_.planets.map((p) => p.position),
      ...world_.riftPortals.map((r) => r.position),
      ...world_.particleSwarms.where((s) => s != swarm).map((s) => s.center),
    ];
    Offset pos;
    int tries = 0;
    do {
      pos = Offset(
        margin + rng.nextDouble() * (ww - margin * 2),
        margin + rng.nextDouble() * (wh - margin * 2),
      );
      tries++;
    } while (tries < 300 && obstacles.any((o) => (o - pos).distance < minDist));
    swarm.center = pos;
    swarm.driftAngle = rng.nextDouble() * 2 * pi;
    swarm.driftTimer = 3.0 + rng.nextDouble() * 4.0;
    swarm.pulse = 0;

    // Pick a new random element
    const elements = [
      'Fire',
      'Water',
      'Earth',
      'Air',
      'Light',
      'Dark',
      'Lightning',
      'Ice',
      'Plant',
      'Crystal',
      'Poison',
      'Lava',
      'Steam',
      'Mud',
      'Dust',
      'Spirit',
      'Blood',
    ];
    swarm.element = elements[rng.nextInt(elements.length)];

    // Regenerate motes
    final count = 80 + rng.nextInt(41); // 80-120
    swarm.motes.clear();
    for (var i = 0; i < count; i++) {
      final angle = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * ParticleSwarm.cloudRadius;
      swarm.motes.add(
        SwarmMote(
          offsetX: cos(angle) * r,
          offsetY: sin(angle) * r,
          orbitSpeed: 0.15 + rng.nextDouble() * 0.35,
          orbitPhase: rng.nextDouble() * 2 * pi,
          size: 1.5 + rng.nextDouble() * 2.5,
        ),
      );
    }
  }

  /// Check if a position is inside any planet's particle-field boundary.
  /// Returns the offending planet or null if placement is valid.
  CosmicPlanet? _planetBlockingPlacement(Offset pos) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    for (final planet in world_.planets) {
      var pdx = planet.position.dx - pos.dx;
      var pdy = planet.position.dy - pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      if (dist < planet.particleFieldRadius) return planet;
    }
    return null;
  }

  /// Find the closest cosmic planet within interaction range for orbital
  /// mechanics. Returns null if none is close enough.
  CosmicPlanet? _nearestPlanetForOrbit(Offset pos) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    CosmicPlanet? closest;
    double closestDist = double.infinity;
    for (final planet in world_.planets) {
      var pdx = planet.position.dx - pos.dx;
      var pdy = planet.position.dy - pos.dy;
      if (pdx > ww / 2) pdx -= ww;
      if (pdx < -ww / 2) pdx += ww;
      if (pdy > wh / 2) pdy -= wh;
      if (pdy < -wh / 2) pdy += wh;
      final dist = sqrt(pdx * pdx + pdy * pdy);
      // Within 1.5× the outer ring → orbital relationship possible
      if (dist < planet.particleFieldRadius * 1.5 && dist < closestDist) {
        closest = planet;
        closestDist = dist;
      }
    }
    return closest;
  }

  // ── orbital relationship state ──
  /// If non-null, one body orbits the other near home planet.
}
