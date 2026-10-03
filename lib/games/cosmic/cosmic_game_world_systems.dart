part of 'cosmic_game.dart';

/// One flock's gathering for a frame: positions relative to the first member
/// met (so a flock straddling the wrap seam has one centre) and the sum of
/// its headings.
class _FlockCentre {
  _FlockCentre(this.anchor);
  final Offset anchor;
  double x = 0, y = 0, cosSum = 0, sinSum = 0;
  int n = 0;

  void add(double dx, double dy, double angle) {
    x += dx;
    y += dy;
    cosSum += cos(angle);
    sinSum += sin(angle);
    n++;
  }
}

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
    // Stalkers spawn around the ship and keep to it, so they are the one
    // roll that stacks up when the ship stays put. A shadow or two reads as
    // eerie; past that it is a crowd.
    if (behavior == EnemyBehavior.stalking &&
        _stalkerGroups() >= CosmicGame._maxStalkerGroups) {
      behavior = EnemyBehavior.drifting;
    }

    // Choose tier — behavior determines distribution across all 6 tiers
    EnemyTier tier;
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
        final vw = size.x / cameraZoom;
        final vh = size.y / cameraZoom;
        final edgeDist = sqrt(vw * vw + vh * vh) * 0.55;
        pos = _wrap(
          Offset(
            ship.pos.dx + cos(angle) * edgeDist,
            ship.pos.dy + sin(angle) * edgeDist,
          ),
        );
    }

    final nearHome = isHomeRecoveryArea(pos);
    tier = CosmicBalance.spaceEnemyTier(
      tier,
      nearHome ? 0 : _guardiansDefeated,
    );
    if (nearHome) behavior = EnemyBehavior.drifting;
    final variant = switch (tier) {
      EnemyTier.brute || EnemyTier.colossus
          when (behavior == EnemyBehavior.aggressive ||
                  behavior == EnemyBehavior.territorial) &&
              rng.nextDouble() < 0.22 =>
        CosmicEnemyVariant.crusher,
      EnemyTier.drone || EnemyTier.phantom
          when (behavior == EnemyBehavior.aggressive ||
                  behavior == EnemyBehavior.stalking) &&
              rng.nextDouble() < 0.28 =>
        CosmicEnemyVariant.pouncer,
      _ => CosmicEnemyVariant.standard,
    };
    final baseHealth = CosmicBalance.enemyBaseHealth(tier);
    final baseSpeed = switch (tier) {
      EnemyTier.drone => 90 + rng.nextDouble() * 50,
      EnemyTier.wisp => 60 + rng.nextDouble() * 40,
      EnemyTier.sentinel => 35 + rng.nextDouble() * 25,
      EnemyTier.phantom => 45 + rng.nextDouble() * 30,
      EnemyTier.brute => 20 + rng.nextDouble() * 15,
      EnemyTier.colossus => 12 + rng.nextDouble() * 8,
    };
    final healthMult = switch (variant) {
      CosmicEnemyVariant.crusher => 1.45,
      CosmicEnemyVariant.pouncer => 0.84,
      CosmicEnemyVariant.standard => 1.0,
    };
    final speedMult = switch (variant) {
      CosmicEnemyVariant.crusher => 0.82,
      CosmicEnemyVariant.pouncer => 1.28,
      CosmicEnemyVariant.standard => 1.0,
    };

    // Wisps mostly arrive as a small flock rather than alone: a lone spark
    // reads as a stray pixel, a knot of them as a creature. The flock shares
    // one heading, speed and pack, turns together (see [_driftTurn]) and
    // provokes together.
    final flockSize = tier == EnemyTier.wisp
        ? min(_wispFlockSize(rng), CosmicGame._maxEnemies - enemies.length)
        : 1;
    final packId = flockSize > 1 ? _nextPackId++ : -1;
    final speed = baseSpeed * speedMult;
    final angle = rng.nextDouble() * pi * 2;
    final driftTimer = rng.nextDouble() * 4;
    final stalkDistance = 400 + rng.nextDouble() * 300;
    final stalkPatience = 35 + rng.nextDouble() * 25;
    for (var m = 0; m < max(1, flockSize); m++) {
      final at = m == 0
          ? pos
          : _wrap(
              pos +
                  Offset.fromDirection(
                    rng.nextDouble() * 2 * pi,
                    26 + rng.nextDouble() * 34,
                  ),
            );
      enemies.add(
        CosmicEnemy(
          position: at,
          element: element,
          tier: tier,
          radius: switch (tier) {
            EnemyTier.drone => 9.5 + rng.nextDouble() * 2,
            EnemyTier.wisp => 8 + rng.nextDouble() * 4,
            EnemyTier.sentinel => 14 + rng.nextDouble() * 6,
            EnemyTier.phantom => 12 + rng.nextDouble() * 5,
            EnemyTier.brute => 20 + rng.nextDouble() * 8,
            EnemyTier.colossus => 30 + rng.nextDouble() * 12,
          },
          health: baseHealth * healthMult,
          speed: speed,
          angle: angle,
          driftTimer: driftTimer,
          behavior: behavior,
          variant: variant,
          packId: packId,
          flock: flockSize > 1,
          homePos: homePos,
          aggroRadius: aggroRadius,
          stalkDistance: stalkDistance,
          stalkPatience: stalkPatience,
        ),
      );
    }
  }

  /// How many stalkers are shadowing the ship, a flock counting once.
  int _stalkerGroups() {
    final packs = <int>{};
    var solos = 0;
    for (final e in enemies) {
      if (e.dead || e.behavior != EnemyBehavior.stalking) continue;
      if (e.packId >= 0) {
        packs.add(e.packId);
      } else {
        solos++;
      }
    }
    return packs.length + solos;
  }

  /// Where each roaming flock is and which way it heads this frame, gathered
  /// once so a member can steer by its flock without looking at the others.
  void _gatherFlocks() {
    _flockCentres.clear();
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    for (final e in enemies) {
      if (!e.flock || e.dead) continue;
      final f = _flockCentres[e.packId] ??= _FlockCentre(e.position);
      var dx = e.position.dx - f.anchor.dx;
      var dy = e.position.dy - f.anchor.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      f.add(dx, dy, e.angle);
    }
  }

  /// A flock member keeps to its flock: a stray turns back toward the
  /// others; the rest settle onto the flock's heading. Turns that pull them
  /// apart — scattering from the ship, a dive — are undone after.
  void _keepToFlock(CosmicEnemy e, double dt) {
    final f = _flockCentres[e.packId];
    if (f == null || f.n < 2) return;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var dx = f.anchor.dx + f.x / f.n - e.position.dx;
    var dy = f.anchor.dy + f.y / f.n - e.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    final stray = dx * dx + dy * dy > 60 * 60;
    final target = stray ? atan2(dy, dx) : atan2(f.sinSum, f.cosSum);
    var diff = target - e.angle;
    while (diff > pi) {
      diff -= pi * 2;
    }
    while (diff < -pi) {
      diff += pi * 2;
    }
    e.angle += diff * (stray ? 2.4 : 1.2) * dt;
  }

  /// How many wisps set out together: two to five more often than not.
  int _wispFlockSize(Random rng) {
    final r = rng.nextDouble();
    if (r < 0.28) return 1;
    if (r < 0.52) return 2;
    if (r < 0.75) return 3;
    if (r < 0.9) return 4;
    return 5;
  }

  /// An idle drifter's random turn (−0.5 to 0.5). A flock's members all take
  /// the same turn at the same moment — their drift timers started equal
  /// and reset by the same amounts — so the flock keeps its shape.
  double _driftTurn(CosmicEnemy e) {
    if (!e.flock) return Random().nextDouble() - 0.5;
    e.flockTurn++;
    return _flockHash(e.packId, e.flockTurn) - 0.5;
  }

  /// How long an idle drifter holds its heading: [base] plus up to [spread],
  /// shared across a flock like the turn.
  double _driftPause(CosmicEnemy e, double base, double spread) =>
      base +
      spread *
          (e.flock
              ? _flockHash(e.packId, e.flockTurn + 7919)
              : Random().nextDouble());

  static double _flockHash(int pack, int turn) {
    final s = sin(pack * 12.9898 + turn * 78.233) * 43758.5453;
    return s - s.floorToDouble();
  }

  /// Turns [e] toward [target] at [rate] (per second, proportional).
  void _steerToward(CosmicEnemy e, double target, double rate, double dt) {
    var diff = target - e.angle;
    while (diff > pi) {
      diff -= pi * 2;
    }
    while (diff < -pi) {
      diff += pi * 2;
    }
    e.angle += diff * rate * dt;
  }

  void setSandboxMode({
    required bool enabled,
    Offset? center,
    double? arenaRadius,
  }) {
    if (enabled) {
      if (!sandboxMode) {
        sandboxReturnPosition = ship.pos;
      }
      sandboxMode = true;
      sandboxAreaCenter = center ?? sandboxAreaCenter;
      sandboxArenaRadius = arenaRadius;
      clearSandboxHostiles();
      if (sandboxAreaCenter != null) {
        teleportTo(sandboxAreaCenter!);
        final revealRadius = arenaRadius == null
            ? CosmicGame.sandboxAreaRevealRadius
            : min(CosmicGame.sandboxAreaRevealRadius, arenaRadius + 160.0);
        _revealAround(sandboxAreaCenter!, revealRadius);
      }
      shipHealth = CosmicGame.shipMaxHealth;
      _shipDead = false;
      _respawnTimer = 0;
      _shipInvincible = 1.2;
      clearSteeringInput();
      nearPlanet = null;
      nearMarket = null;
      nearContestArena = null;
      _nearestRift = null;
      _wasNearRift = false;
      _wasNearNexus = false;
      _isNearNexus = false;
      _wasNearBloodRing = false;
      _isNearBloodRing = false;
      onNearPlanet?.call(null);
      onNearMarket?.call(null);
      onNearRift?.call(false);
      onNearNexus?.call(false);
      onNearBloodRing?.call(false);
      onNearContestArena?.call(null);
    } else {
      sandboxMode = false;
      clearSandboxHostiles();
      final returnPos = sandboxReturnPosition;
      sandboxReturnPosition = null;
      sandboxAreaCenter = null;
      sandboxArenaRadius = null;
      if (returnPos != null) {
        teleportTo(returnPos);
      }
      shipHealth = CosmicGame.shipMaxHealth;
      _shipDead = false;
      _respawnTimer = 0;
      _shipInvincible = 0.75;
    }
  }

  void _clampShipToSandboxArena() {
    final center = sandboxAreaCenter;
    if (!sandboxMode || center == null) return;
    final radius = sandboxArenaRadius;
    if (radius == null || radius <= 0) return;

    final delta = ship.pos - center;
    final distance = delta.distance;
    if (distance <= radius) return;

    final direction = distance <= 0.001
        ? Offset(cos(ship.angle), sin(ship.angle))
        : delta / distance;
    ship.pos = _wrap(center + direction * radius);
    _dragTarget = ship.pos;
  }

  Offset _clampToSandboxArena(Offset position, {double margin = 56.0}) {
    final center = sandboxAreaCenter;
    final radius = sandboxArenaRadius;
    if (!sandboxMode || center == null || radius == null || radius <= margin) {
      return _wrap(position);
    }

    final delta = position - center;
    final distance = delta.distance;
    final maxDistance = radius - margin;
    if (distance <= maxDistance) return _wrap(position);

    final direction = distance <= 0.001
        ? Offset(cos(ship.angle), sin(ship.angle))
        : delta / distance;
    return _wrap(center + direction * maxDistance);
  }

  void clearSandboxHostiles() {
    enemies.clear();
    activeBoss = null;
    bossProjectiles.clear();
    projectiles.clear();
    _missiles.clear();
    elemParticles.clear();
    duelOpponent = null;
    duelOpponentProjectiles.clear();
    _resetDuelCombat();
    _duelWildId = null;
    _wildDuelTargetCompanion = null;
  }

  void resetSandboxCombatState() {
    if (!sandboxMode) return;
    shipHealth = CosmicGame.shipMaxHealth;
    _shipDead = false;
    _respawnTimer = 0;
    _shipInvincible = 2.0;
    clearSandboxHostiles();
    var companionOffset = 0.0;
    for (final comp in activeCompanions.values) {
      comp.currentHp = comp.maxHp;
      comp.shieldHp = 0;
      comp.invincibleTimer = 1.2;
      comp.returning = false;
      comp.returnTimer = 0;
      comp.position = ship.pos + Offset(72, companionOffset);
      comp.anchorPosition = comp.position;
      companionOffset += 36;
    }
    if (sandboxAreaCenter != null) {
      teleportTo(sandboxAreaCenter!);
    } else {
      clearSteeringInput();
    }
  }

  void spawnSandboxEnemy({
    required EnemyTier tier,
    String? element,
    EnemyBehavior behavior = EnemyBehavior.aggressive,
    int count = 1,
  }) {
    final spawnCount = count.clamp(1, 24);
    final resolvedElement = element ?? _randomEnemyElement(sandboxRng);
    for (var i = 0; i < spawnCount; i++) {
      final angle = sandboxRng.nextDouble() * pi * 2;
      final distance = 160.0 + sandboxRng.nextDouble() * 170.0;
      final pos = _clampToSandboxArena(
        Offset(
          ship.pos.dx + cos(angle) * distance,
          ship.pos.dy + sin(angle) * distance,
        ),
        margin: 70,
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: resolvedElement,
          tier: tier,
          radius: switch (tier) {
            EnemyTier.drone => 9.5 + sandboxRng.nextDouble() * 2,
            EnemyTier.wisp => 8 + sandboxRng.nextDouble() * 4,
            EnemyTier.sentinel => 14 + sandboxRng.nextDouble() * 6,
            EnemyTier.phantom => 12 + sandboxRng.nextDouble() * 5,
            EnemyTier.brute => 20 + sandboxRng.nextDouble() * 8,
            EnemyTier.colossus => 30 + sandboxRng.nextDouble() * 12,
          },
          health: CosmicBalance.enemyBaseHealth(tier),
          speed: switch (tier) {
            EnemyTier.drone => 90 + sandboxRng.nextDouble() * 50,
            EnemyTier.wisp => 60 + sandboxRng.nextDouble() * 40,
            EnemyTier.sentinel => 35 + sandboxRng.nextDouble() * 25,
            EnemyTier.phantom => 45 + sandboxRng.nextDouble() * 30,
            EnemyTier.brute => 20 + sandboxRng.nextDouble() * 15,
            EnemyTier.colossus => 12 + sandboxRng.nextDouble() * 8,
          },
          angle: angle + pi,
          driftTimer: sandboxRng.nextDouble() * 2,
          behavior: behavior,
          provoked: behavior == EnemyBehavior.aggressive,
          aggroRadius: 420,
          stalkDistance: 340,
        ),
      );
    }
  }

  void spawnSandboxDummy({int count = 1}) {
    final spawnCount = count.clamp(1, 12);
    for (var i = 0; i < spawnCount; i++) {
      final angle = sandboxRng.nextDouble() * pi * 2;
      final distance = 160.0 + sandboxRng.nextDouble() * 120.0;
      final pos = _wrap(
        Offset(
          ship.pos.dx + cos(angle) * distance,
          ship.pos.dy + sin(angle) * distance,
        ),
      );
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: 'neutral',
          tier: EnemyTier.colossus,
          radius: 28,
          health: 99999,
          speed: 0,
          angle: angle + pi,
          driftTimer: 999999,
          behavior: EnemyBehavior.drifting,
          provoked: false,
          aggroRadius: 0,
          stalkDistance: 0,
        ),
      );
    }
  }

  void spawnSandboxBoss({required BossTemplate template, required int level}) {
    final rng = Random();
    final safeLevel = CosmicBalance.clampLevel(level);
    final healthScale = CosmicBalance.bossHealthScale(safeLevel);
    final speedScale = CosmicBalance.bossSpeedScale(safeLevel);
    final radiusBonus = CosmicBalance.bossRadiusBonus(safeLevel);
    final bossRadius = template.radius + radiusBonus;
    final Offset pos;
    final angle = rng.nextDouble() * pi * 2;

    if (sandboxMode &&
        sandboxAreaCenter != null &&
        sandboxArenaRadius != null) {
      final center = sandboxAreaCenter!;
      final shipDelta = ship.pos - center;
      final shipDistance = shipDelta.distance;
      final spawnAngle = shipDistance > 1.0
          ? atan2(shipDelta.dy, shipDelta.dx)
          : angle;
      final spawnDistance = min(
        300.0,
        max(160.0, sandboxArenaRadius! - bossRadius - 100.0),
      );
      pos = _clampToSandboxArena(
        Offset(
          center.dx + cos(spawnAngle) * spawnDistance,
          center.dy + sin(spawnAngle) * spawnDistance,
        ),
        margin: bossRadius + 90,
      );
    } else {
      const distance = 320.0;
      pos = _wrap(
        Offset(
          ship.pos.dx + cos(angle) * distance,
          ship.pos.dy + sin(angle) * distance,
        ),
      );
    }

    activeBoss = CosmicBoss(
      position: pos,
      name: template.name,
      element: template.element,
      level: safeLevel,
      radius: bossRadius,
      maxHealth: template.health * healthScale,
      speed: template.speed * speedScale,
      angle: rng.nextDouble() * pi * 2,
      forcedType: template.preferredType,
    );
    bossProjectiles.clear();
    onBossSpawned?.call('Lv$safeLevel ${template.name}');
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
    if (isHomeRecoveryArea(home)) return;

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

  /// Spawn a swarm of 11-16 early, rising to 23-28 small flyers late-game.
  /// If [center] is not given, picks a random spot in deep space.
  /// Respects the enemy cap — skips if already at max.
  void _spawnSwarmCluster({Offset? center, Random? rng}) {
    if (enemies.length >= CosmicGame._maxEnemies) return;
    rng ??= Random();
    final packId = _nextPackId++;
    const elements = ['Fire', 'Water', 'Earth', 'Air', 'Light', 'Dark'];
    final element = elements[rng.nextInt(elements.length)];
    final count = min(
      8 + CosmicBalance.spaceLevel(_guardiansDefeated) * 3 + rng.nextInt(6),
      CosmicGame._maxEnemies - enemies.length,
    );

    // Pick center if not provided — random position in world, away from edges
    final cx =
        center?.dx ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.width - 4000));
    final cy =
        center?.dy ??
        (2000.0 + rng.nextDouble() * (world_.worldSize.height - 4000));
    final home = _wrap(Offset(cx, cy));
    if (isHomeRecoveryArea(home)) return;

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
              ? 7 + rng.nextDouble() * 1.5
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

  // ── SKIRMISH (Lv 1-2) ───────────────────────────
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

  // ── SIEGE (Lv 3-4) ──────────────────────────────
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

  // ── ONSLAUGHT (Lv 5) ────────────────────────────
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
          EnemyTier.drone => 9.5 + rng.nextDouble() * 2,
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
            e.position.dx + cos(e.angle) * e.moveSpeed * dt * 0.3,
            e.position.dy + sin(e.angle) * e.moveSpeed * dt * 0.3,
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
    Offset nearestLureCenter = Offset.zero;
    double nearestDecoyDist = double.infinity;
    for (final cp in companionProjectiles) {
      // Lures are survival's: whatever taunts draws bodies (a Horn's burning
      // lane, a geyser, the void, a Kin Spirit wisp), not only decoys, and a
      // Horn decoy with no taunt of its own draws from 180. A lure pulls
      // toward what it circles (a wisp toward its kin), as survival's do.
      final hornLure = cp.abilityFamily == 'horn';
      if (cp.decoy && cp.decoyHp <= 0) continue;
      if (!cp.decoy && cp.tauntRadius <= 0) continue;
      final lureCenter =
          cp.transferOrbitCenter ?? cp.orbitCenter ?? cp.position;
      var ddx = lureCenter.dx - e.position.dx;
      var ddy = lureCenter.dy - e.position.dy;
      if (ddx > ww / 2) ddx -= ww;
      if (ddx < -ww / 2) ddx += ww;
      if (ddy > wh / 2) ddy -= wh;
      if (ddy < -wh / 2) ddy += wh;
      final dd = sqrt(ddx * ddx + ddy * ddy);
      final aggroRadius = cp.tauntRadius > 0
          ? cp.tauntRadius
          : hornLure
          ? 180.0
          : 500.0;
      if (dd < aggroRadius && dd < nearestDecoyDist) {
        nearestDecoy = cp;
        nearestLureCenter = lureCenter;
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
      var ddx = nearestLureCenter.dx - e.position.dx;
      var ddy = nearestLureCenter.dy - e.position.dy;
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
              cos(e.angle) * e.moveSpeed * tauntSpeedMult * snareMoveMult * dt,
          e.position.dy +
              sin(e.angle) * e.moveSpeed * tauntSpeedMult * snareMoveMult * dt,
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
      // A Mask snare (Mud's pool, Plant's vine) only slows, as Survival's
      // do; it does not steer bodies into itself.
      if (cp.abilityFamily == 'mask') continue;
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

    // ── Committed pursuit → shared hover/dive flight steering ──
    // Ambient behaviours below keep their own character (drift, patrol,
    // feeding, stalk-at-distance); but once an enemy actually commits to an
    // attack run, it flies the shared hover→telegraph→dive pattern instead
    // of beelining into the ship. Contact stays kamikaze (the ship-collision
    // pass) — the dive is what delivers it.
    final chaseRange = e.tier == EnemyTier.sentinel ? 700.0 : 400.0;
    final committed = switch (e.behavior) {
      EnemyBehavior.aggressive => distToShip < chaseRange,
      EnemyBehavior.territorial => distToShip < e.aggroRadius,
      EnemyBehavior.swarming => e.provoked || distToShip < 520,
      EnemyBehavior.stalking => shipHealth <= 2.0 && distToShip < 800,
      _ => e.provoked && distToShip < 600,
    };
    if (committed) {
      if (e.behavior == EnemyBehavior.stalking) e.speed = 120; // strike boost
      final rng = Random();
      final steering = e.flightSteering ??= FlightSteeringState(rng);
      final tick = tickFlightSteering(
        state: steering,
        profile: switch (e.variant) {
          CosmicEnemyVariant.crusher => FlightSteeringProfile.spaceCrusher,
          CosmicEnemyVariant.pouncer => FlightSteeringProfile.spacePouncer,
          CosmicEnemyVariant.standard => FlightSteeringProfile.spaceMelee,
        },
        toTarget: Offset(dx, dy),
        speed: e.moveSpeed * moveSpeedMult,
        contactRange: e.radius + 8, // inside the kamikaze band (radius+14)
        dt: dt,
        rng: rng,
      );
      e.position = _wrap(e.position + tick.velocity * dt);
      e.angle = flightHeading(steering, Offset(dx, dy), fallback: toShip);
      e.turnLeft = 0;
      final committedDespawn = e.whirlIndex >= 0
          ? 4000.0
          : (e.behavior == EnemyBehavior.feeding ||
                e.behavior == EnemyBehavior.territorial)
          ? 2500.0
          : 1500.0;
      if (distToShip > committedDespawn) e.dead = true;
      return;
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
          e.turnLeft += _driftTurn(e) * 1.5;
          e.driftTimer = _driftPause(e, 1.5, 2);
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
          e.turnLeft += _driftTurn(e) * 1.0;
          e.driftTimer = _driftPause(e, 2, 4);
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
            _steerToward(e, toShip + pi, 5.0, dt); // wheel away
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
        } else if ((e.stalkPatience -= dt) <= 0) {
          // Lost interest: peel away and drift off, to be despawned out of
          // range like any drifter. A flock started with one patience, so it
          // leaves together.
          e.behavior = EnemyBehavior.drifting;
          e.angle = toShip + pi;
          e.turnLeft = 0;
        } else if (distToShip < e.stalkDistance - 50) {
          // Too close — back off
          _steerToward(e, toShip + pi, 4.0, dt);
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

    if (e.flock) _keepToFlock(e, dt);

    // Variant overlays add encounter diversity without introducing new tiers.
    if (e.variant == CosmicEnemyVariant.crusher) {
      var diff = toShip - e.angle;
      while (diff > pi) {
        diff -= pi * 2;
      }
      while (diff < -pi) {
        diff += pi * 2;
      }
      e.angle += diff * 2.2 * dt;
      moveSpeedMult *= distToShip < 250 ? 1.18 : 0.92;
    } else if (e.variant == CosmicEnemyVariant.pouncer) {
      if (e.driftTimer <= 0) {
        final side = Random().nextBool() ? 1.0 : -1.0;
        e.turnLeft += side * (0.65 + Random().nextDouble() * 0.55);
        e.driftTimer = 0.35 + Random().nextDouble() * 0.55;
      }
      moveSpeedMult *= 1.2;
    }

    // Drift turns and jinks are flown through, not taken in one frame: a
    // heading that jumps kinks the path and the body slides sideways.
    if (e.turnLeft != 0) {
      final rate = e.variant == CosmicEnemyVariant.pouncer ? 9.0 : 3.0;
      final step = e.turnLeft.abs() < 0.002
          ? e.turnLeft
          : e.turnLeft * (1 - exp(-rate * dt));
      e.angle += step;
      e.turnLeft -= step;
    }

    // Move
    e.position = _wrap(
      Offset(
        e.position.dx + cos(e.angle) * e.moveSpeed * moveSpeedMult * dt,
        e.position.dy + sin(e.angle) * e.moveSpeed * moveSpeedMult * dt,
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
      if (lair.state == BossLairState.waiting) {
        var dx = lair.position.dx - ship.pos.dx;
        var dy = lair.position.dy - ship.pos.dy;
        if (dx > ww / 2) dx -= ww;
        if (dx < -ww / 2) dx += ww;
        if (dy > wh / 2) dy -= wh;
        if (dy < -wh / 2) dy += wh;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < BossLair.activationRadius) {
          final lairBossActive = bossLairs.any(
            (other) => other.state == BossLairState.fighting,
          );
          if (activeBoss != null && !lairBossActive) {
            // Roaming/discovery bosses should not block an intentional lair
            // encounter once the player reaches the lair itself.
            activeBoss = null;
            bossProjectiles.clear();
          }
          if (activeBoss != null) continue;
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
            guardiansDefeated: _guardiansDefeated,
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

  /// Remove the active boss without a kill. A lair it was fought at goes back
  /// to waiting — otherwise the lair stays 'fighting' forever: never drawn,
  /// never re-armed, and still counted as a live lair encounter.
  void _despawnActiveBoss() {
    activeBoss = null;
    bossProjectiles.clear();
    _bossLeashTimer = 0;
    for (final lair in bossLairs) {
      if (lair.state == BossLairState.fighting) {
        lair.state = BossLairState.waiting;
      }
    }
  }

  void _spawnBossFromLair(BossLair lair) {
    lair.state = BossLairState.fighting;

    final lvl = lair.level;
    final healthScale = CosmicBalance.bossHealthScale(lvl);
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
      forcedType: lair.template.preferredType,
      isTitanic: lair.template.isTitanic,
      colossalTrait: lair.template.colossalTrait,
    );
    onBossSpawned?.call('Lv$lvl ${lair.template.name}');
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
        level: CosmicBalance.rollSpaceLevel(_guardiansDefeated, rng),
        radius: 50 + rng.nextDouble() * 30,
        totalWaves: 3 + rng.nextInt(3),
      ),
    );
  }

  void _spawnBoss() {
    final rng = Random();
    final template = pickBossTemplate(rng, titanicChance: 0.05);
    final lvl = CosmicBalance.rollSpaceLevel(_guardiansDefeated, rng);

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
    if (isHomeRecoveryArea(pos)) return;
    // A roaming boss is a local encounter. One rolled at a planet across the
    // map would only sit dormant until the leash removed it.
    if (_wrappedDistanceSq(pos, ship.pos) > CosmicGame._bossLeashDistSq) return;

    final healthScale = CosmicBalance.bossHealthScale(lvl);
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
      forcedType: template.preferredType,
      isTitanic: template.isTitanic,
      colossalTrait: template.colossalTrait,
    );
    onBossSpawned?.call('Lv$lvl ${template.name}');
  }

  /// Spawn a guaranteed boss when a planet is first discovered.
  /// Difficulty follows guardian victories, so exploration stays accessible.
  void _spawnDiscoveryBoss(CosmicPlanet planet) {
    if (activeBoss != null) return; // don't override an active boss

    final rng = Random();
    final template = pickBossTemplate(
      rng,
      preferredElement: planet.element,
      titanicChance: 0.025,
    );

    final lvl = CosmicBalance.spaceLevel(_guardiansDefeated);

    // Spawn near the discovered planet
    final angle = rng.nextDouble() * pi * 2;
    final orbitDist = planet.radius * 4.0 + 100 + rng.nextDouble() * 150;
    final sx = planet.position.dx + cos(angle) * orbitDist;
    final sy = planet.position.dy + sin(angle) * orbitDist;
    final pos = _wrap(Offset(sx, sy));

    final healthScale = CosmicBalance.bossHealthScale(lvl);
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
      forcedType: template.preferredType,
      isTitanic: template.isTitanic,
      colossalTrait: template.colossalTrait,
    );
    onBossSpawned?.call('Lv$lvl ${template.name}');
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

    final toShipAngle = atan2(dy, dx);
    final dist = sqrt(dx * dx + dy * dy);

    // ~30% of the time, aim at the companion instead of the ship.
    // Chargers still always rush the ship (they're melee, not ranged).
    double toShip = toShipAngle;
    final targetCompanion = _nearestActiveCompanion(boss.position);
    if (boss.type != BossType.charger && targetCompanion != null) {
      // Use phaseTimer as a cheap deterministic toggle so it doesn't
      // flicker every frame — switches target roughly every ~2-3 seconds.
      final cycle = (boss.phaseTimer * 0.4).floor() % 10;
      if (cycle < 3) {
        // 3 out of 10 cycles → aim at companion
        var cdx = targetCompanion.position.dx - boss.position.dx;
        var cdy = targetCompanion.position.dy - boss.position.dy;
        if (cdx > ww / 2) cdx -= ww;
        if (cdx < -ww / 2) cdx += ww;
        if (cdy > wh / 2) cdy -= wh;
        if (cdy < -wh / 2) cdy += wh;
        toShip = atan2(cdy, cdx);
      }
    }

    switch (boss.type) {
      case BossType.charger:
        _updateChargerBoss(boss, dt, toShip, dist);
      case BossType.gunner:
        _updateGunnerBoss(boss, dt, toShip, dist);
      case BossType.skirmisher:
        _updateSkirmisherBoss(boss, dt, toShip, dist);
      case BossType.bulwark:
        _updateBulwarkBoss(boss, dt, toShip, dist);
      case BossType.carrier:
        _updateCarrierBoss(boss, dt, toShip, dist);
      case BossType.warden:
        _updateWardenBoss(boss, dt, toShip, dist);
    }

    _updateTitanicBossTrait(boss, dt, toShip, dist);
  }

  void _updateTitanicBossTrait(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    if (!boss.isTitanic || boss.colossalTrait == null) return;

    switch (boss.colossalTrait!) {
      case ColossalTrait.gravityWell:
        if (dist < 600) {
          final strength = (1.0 - (dist / 600)).clamp(0.0, 1.0);
          final pull = (28.0 + 40.0 * strength) * dt;
          final away = Offset(cos(toShip), sin(toShip));
          ship.pos = _wrap(
            Offset(ship.pos.dx - away.dx * pull, ship.pos.dy - away.dy * pull),
          );
          for (final comp in _livingActiveCompanions) {
            final cdx = boss.position.dx - comp.position.dx;
            final cdy = boss.position.dy - comp.position.dy;
            final cd = sqrt(cdx * cdx + cdy * cdy);
            if (cd > 0.001) {
              final cpull = (22.0 + 30.0 * strength) * dt;
              comp.position = _wrap(
                Offset(
                  comp.position.dx + (cdx / cd) * cpull,
                  comp.position.dy + (cdy / cd) * cpull,
                ),
              );
            }
          }
        }

        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 2.4;
          const count = 8;
          for (var i = 0; i < count; i++) {
            final a = (i / count) * pi * 2 + boss.phaseTimer * 0.35;
            bossProjectiles.add(
              BossProjectile(
                position: boss.position,
                angle: a,
                element: boss.element,
                damage:
                    CosmicBalance.bossProjectileDamage(
                      level: boss.level,
                      type: boss.type,
                    ) *
                    0.92,
                speed: 170,
                radius: 6.4,
                life: 3.4,
              ),
            );
          }
        }

      case ColossalTrait.riftStorm:
        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 3.1;
          final targetAngle = toShip;
          for (var i = 0; i < 3; i++) {
            final ringAngle = boss.phaseTimer * 0.7 + i * (2 * pi / 3);
            final rift = _wrap(
              boss.position +
                  Offset(cos(ringAngle) * 170, sin(ringAngle) * 170),
            );
            for (final offset in [-0.16, 0.0, 0.16]) {
              bossProjectiles.add(
                BossProjectile(
                  position: rift,
                  angle: targetAngle + offset,
                  element: boss.element,
                  damage:
                      CosmicBalance.bossProjectileDamage(
                        level: boss.level,
                        type: boss.type,
                      ) *
                      0.86,
                  speed: 245,
                  radius: 5.2,
                  life: 3.0,
                ),
              );
            }
            _spawnHitSpark(rift, elementColor(boss.element));
          }
        }

      case ColossalTrait.novaPulse:
        boss.colossalTraitTimer -= dt;
        if (boss.colossalTraitTimer <= 0) {
          boss.colossalTraitTimer = 4.2;
          final pulseDamage = CosmicBalance.bossProjectileDamage(
            level: boss.level,
            type: boss.type,
          );
          final pulseRadius = boss.radius * 2.1;
          _spawnKillVfx(
            boss.position,
            elementColor(boss.element),
            pulseRadius,
            true,
          );
          if (dist <= pulseRadius + 20) {
            _damageShip(pulseDamage * 1.15);
          }
          for (final comp in _livingActiveCompanions) {
            final compDist = (comp.position - boss.position).distance;
            if (compDist <= pulseRadius + 14) {
              _openCompanionIncomingDamage(comp, pulseDamage * 1.1);
            }
          }
        }
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
  // SKIRMISHER BOSS
  // Behaviour: darts around at range, peppers quick shots,
  // and deploys light sniper escorts to reward chase and pick-offs.
  // ────────────────────────────────────────────────
  void _updateSkirmisherBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * 2.8 * dt;

    final desiredRange = boss.healthPct < 0.45 ? 330.0 : 290.0;
    final orbitSign = sin(boss.phaseTimer * 1.6 + boss.level * 0.45) >= 0
        ? 1.0
        : -1.0;
    double moveAngle;
    if (dist > desiredRange + 85) {
      moveAngle = toShip + orbitSign * 0.25;
    } else if (dist < desiredRange - 70) {
      moveAngle = toShip + pi + orbitSign * 0.18;
    } else {
      moveAngle = toShip + orbitSign * (pi / 2);
    }
    final speedBurst = 1.1 + 0.35 * (0.5 + 0.5 * sin(boss.phaseTimer * 4.2));
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * speedBurst * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * speedBurst * dt,
      ),
    );

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0 && dist < 620) {
      boss.shootTimer = boss.healthPct < 0.45 ? 0.8 : 0.95;
      final shots = boss.level >= 6 || boss.healthPct < 0.45 ? 3 : 2;
      for (var s = 0; s < shots; s++) {
        final spread = (s - (shots - 1) / 2) * 0.11;
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: toShip + spread,
            element: boss.element,
            damage: CosmicBalance.bossProjectileDamage(
              level: boss.level,
              type: boss.type,
            ),
            speed: 255 + boss.level * 20.0,
            radius: 3.6,
          ),
        );
      }
    }

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0 && enemies.length < CosmicGame._maxEnemies - 2) {
      boss.escortTimer = max(
        4.2,
        (CosmicBoss.escortCooldown - 0.9) - boss.level * 0.12,
      );
      _spawnSkirmisherEscortPack(boss);
    }
  }

  void _spawnSkirmisherEscortPack(CosmicBoss boss) {
    final rng = Random();
    final packCount = boss.healthPct < 0.5 ? 3 : 2;

    for (var i = 0; i < packCount; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = boss.radius * 2.6 + 38 + rng.nextDouble() * 40;
      final pos = _wrap(
        Offset(
          boss.position.dx + cos(angle) * dist,
          boss.position.dy + sin(angle) * dist,
        ),
      );

      final isPhantom = i == 0 || rng.nextDouble() < 0.45;
      final tier = isPhantom ? EnemyTier.phantom : EnemyTier.drone;
      final stalkDistance = 380.0 + rng.nextDouble() * 120.0;
      enemies.add(
        CosmicEnemy(
          position: pos,
          element: boss.element,
          tier: tier,
          radius: isPhantom
              ? 14 + rng.nextDouble() * 4
              : 10 + rng.nextDouble() * 2,
          health: CosmicBalance.enemyBaseHealth(tier) * (isPhantom ? 1.1 : 0.9),
          speed: isPhantom
              ? 88 + rng.nextDouble() * 20
              : 118 + rng.nextDouble() * 26,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 1.5,
          behavior: isPhantom
              ? EnemyBehavior.stalking
              : EnemyBehavior.aggressive,
          provoked: true,
          homePos: boss.position,
          aggroRadius: 420.0,
          stalkDistance: stalkDistance,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────
  // BULWARK BOSS
  // Behaviour: slow armored anchor that advances behind a recurring shield
  // and calls in heavy support packs to punish tunnel vision.
  // ────────────────────────────────────────────────
  void _updateBulwarkBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * 1.55 * dt;

    final desiredRange = boss.healthPct < 0.4 ? 170.0 : 210.0;
    double moveAngle;
    if (dist > desiredRange + 55) {
      moveAngle = toShip;
    } else if (dist < desiredRange - 40) {
      moveAngle = toShip + pi;
    } else {
      moveAngle = toShip + pi / 3;
    }
    final shieldSlow = boss.shieldUp ? 0.72 : 1.0;
    boss.position = _wrap(
      Offset(
        boss.position.dx + cos(moveAngle) * boss.speed * shieldSlow * dt,
        boss.position.dy + sin(moveAngle) * boss.speed * shieldSlow * dt,
      ),
    );

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0 && dist < 360) {
      boss.shootTimer = boss.healthPct < 0.45 ? 1.0 : 1.25;
      for (var s = 0; s < 2; s++) {
        final spread = (s == 0 ? -1 : 1) * 0.09;
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: toShip + spread,
            element: boss.element,
            damage: CosmicBalance.bossProjectileDamage(
              level: boss.level,
              type: boss.type,
            ),
            speed: 185 + boss.level * 6.0,
            radius: 5.0,
          ),
        );
      }
    }

    boss.shieldTimer -= dt;
    if (boss.shieldUp) {
      if (boss.shieldTimer <= 0 || boss.shieldHealth <= 0) {
        boss.shieldUp = false;
        boss.shieldTimer = 5.8;
      }
    } else if (boss.shieldTimer <= 0) {
      boss.shieldUp = true;
      boss.shieldHealth = CosmicBalance.bossShieldHealth(boss.level) * 1.4;
      boss.shieldTimer = 3.8;
    }

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0 && enemies.length < CosmicGame._maxEnemies - 2) {
      boss.escortTimer = max(
        4.8,
        CosmicBoss.escortCooldown + 0.6 - boss.level * 0.12,
      );
      _spawnBulwarkEscortPack(boss);
    }
  }

  void _spawnBulwarkEscortPack(CosmicBoss boss) {
    final rng = Random();
    final packCount = boss.healthPct < 0.45 ? 3 : 2;

    for (var i = 0; i < packCount; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = boss.radius * 2.8 + 28 + rng.nextDouble() * 36;
      final pos = _wrap(
        Offset(
          boss.position.dx + cos(angle) * dist,
          boss.position.dy + sin(angle) * dist,
        ),
      );

      final isAnchor = i == 0;
      final tier = isAnchor
          ? (boss.healthPct < 0.5 ? EnemyTier.brute : EnemyTier.sentinel)
          : (rng.nextDouble() < 0.5 ? EnemyTier.sentinel : EnemyTier.drone);
      final behavior = isAnchor
          ? EnemyBehavior.territorial
          : EnemyBehavior.aggressive;
      final radius = switch (tier) {
        EnemyTier.drone => 10 + rng.nextDouble() * 2,
        EnemyTier.wisp => 9 + rng.nextDouble() * 3,
        EnemyTier.sentinel => 16 + rng.nextDouble() * 5,
        EnemyTier.phantom => 14 + rng.nextDouble() * 4,
        EnemyTier.brute => 21 + rng.nextDouble() * 6,
        EnemyTier.colossus => 28 + rng.nextDouble() * 8,
      };
      final speed = switch (tier) {
        EnemyTier.drone => 88 + rng.nextDouble() * 24,
        EnemyTier.wisp => 75 + rng.nextDouble() * 25,
        EnemyTier.sentinel => 38 + rng.nextDouble() * 14,
        EnemyTier.phantom => 54 + rng.nextDouble() * 16,
        EnemyTier.brute => 24 + rng.nextDouble() * 10,
        EnemyTier.colossus => 18 + rng.nextDouble() * 8,
      };
      final healthScale = isAnchor ? 2.2 : 1.45;

      enemies.add(
        CosmicEnemy(
          position: pos,
          element: boss.element,
          tier: tier,
          radius: radius,
          health: CosmicBalance.enemyBaseHealth(tier) * healthScale,
          speed: speed,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: behavior,
          provoked: true,
          homePos: boss.position,
          aggroRadius: isAnchor ? 240.0 : 360.0,
        ),
      );
    }
  }

  // ────────────────────────────────────────────────
  // CARRIER BOSS
  // Behaviour: holds mid-range, fires light screen shots,
  // periodically deploys escort packages that change target priority.
  // ────────────────────────────────────────────────
  void _updateCarrierBoss(
    CosmicBoss boss,
    double dt,
    double toShip,
    double dist,
  ) {
    var angleDiff = toShip - boss.angle;
    while (angleDiff > pi) {
      angleDiff -= pi * 2;
    }
    while (angleDiff < -pi) {
      angleDiff += pi * 2;
    }
    boss.angle += angleDiff * 1.85 * dt;

    final desiredRange = boss.healthPct < 0.45 ? 320.0 : 380.0;
    double moveAngle;
    if (dist > desiredRange + 70) {
      moveAngle = toShip;
    } else if (dist < desiredRange - 60) {
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

    boss.shootTimer -= dt;
    if (boss.shootTimer <= 0 && dist < 560) {
      boss.shootTimer = 1.25;
      for (var s = 0; s < 2; s++) {
        final spread = (s == 0 ? -1 : 1) * 0.12;
        bossProjectiles.add(
          BossProjectile(
            position: boss.position,
            angle: toShip + spread,
            element: boss.element,
            damage: CosmicBalance.bossProjectileDamage(
              level: boss.level,
              type: boss.type,
            ),
            speed: 210 + boss.level * 7.0,
            radius: 4.0,
          ),
        );
      }
    }

    boss.escortTimer -= dt;
    if (boss.escortTimer <= 0 && enemies.length < CosmicGame._maxEnemies - 3) {
      boss.escortTimer = max(
        3.8,
        CosmicBoss.escortCooldown - boss.level * 0.18,
      );
      _spawnCarrierEscortPack(boss);
    }
  }

  void _spawnCarrierEscortPack(CosmicBoss boss) {
    final rng = Random();
    final packCount = boss.healthPct < 0.4 ? 4 : 3;
    final sentryIndices = <int>{if (packCount >= 3) rng.nextInt(packCount)};

    for (var i = 0; i < packCount; i++) {
      final angle = rng.nextDouble() * pi * 2;
      final dist = boss.radius * 2.4 + 30 + rng.nextDouble() * 45;
      final pos = _wrap(
        Offset(
          boss.position.dx + cos(angle) * dist,
          boss.position.dy + sin(angle) * dist,
        ),
      );

      final isScreener = sentryIndices.contains(i);
      final tier = isScreener
          ? EnemyTier.sentinel
          : (rng.nextDouble() < 0.55 ? EnemyTier.drone : EnemyTier.wisp);
      final behavior = isScreener
          ? EnemyBehavior.territorial
          : EnemyBehavior.aggressive;
      final radius = switch (tier) {
        EnemyTier.drone => 10 + rng.nextDouble() * 2,
        EnemyTier.wisp => 9 + rng.nextDouble() * 3,
        EnemyTier.sentinel => 15 + rng.nextDouble() * 5,
        EnemyTier.phantom => 14 + rng.nextDouble() * 4,
        EnemyTier.brute => 20 + rng.nextDouble() * 6,
        EnemyTier.colossus => 28 + rng.nextDouble() * 8,
      };
      final speed = switch (tier) {
        EnemyTier.drone => 95 + rng.nextDouble() * 40,
        EnemyTier.wisp => 78 + rng.nextDouble() * 35,
        EnemyTier.sentinel => 42 + rng.nextDouble() * 18,
        EnemyTier.phantom => 58 + rng.nextDouble() * 18,
        EnemyTier.brute => 28 + rng.nextDouble() * 12,
        EnemyTier.colossus => 18 + rng.nextDouble() * 8,
      };
      final healthScale = isScreener ? 1.9 : 1.25;

      enemies.add(
        CosmicEnemy(
          position: pos,
          element: boss.element,
          tier: tier,
          radius: radius,
          health: CosmicBalance.enemyBaseHealth(tier) * healthScale,
          speed: speed,
          angle: rng.nextDouble() * pi * 2,
          driftTimer: rng.nextDouble() * 2,
          behavior: behavior,
          provoked: true,
          homePos: isScreener ? boss.position : null,
          aggroRadius: isScreener ? 260.0 : 420.0,
        ),
      );
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
            speed: 200 + boss.level * 20.0,
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
          // _damageShip may clear bossProjectiles (sandbox reset), bail out.
          if (i >= bossProjectiles.length) break;
          bossProjectiles.removeAt(i);
          continue;
        }
      }

      // Hit companion?
      for (final comp in _livingActiveCompanions) {
        if (comp.invincibleTimer > 0) continue;
        final cdx = comp.position.dx - bp.position.dx;
        final cdy = comp.position.dy - bp.position.dy;
        final compHitR = bp.radius + 15;
        if (cdx * cdx + cdy * cdy < compHitR * compHitR) {
          // Boss projectile damage is ship-scale (~1-2). Scale up to
          // companion-scale so it's meaningful against companion defenses.
          final scaledDmg = bp.damage * 30.0;
          _openCompanionIncomingDamage(
            comp,
            scaledDmg * 100 / (100 + comp.elemDef),
          );
          _spawnHitSpark(comp.position, elementColor(bp.element));
          bossProjectiles.removeAt(i);
          break;
        }
      }
    }
  }

  // ── Boss kill helper ──────────────────────────────────

  void _handleBossKill(CosmicBoss boss) {
    onSound?.call(SoundCue.combatVictory);
    boss.dead = true;
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
  /// Lv 3: small chance for a standard harvester matching boss element.
  /// Lv 4: higher chance for harvester + 5% portal key.
  /// Lv 5: guaranteed harvester + 20% portal key + chance for guaranteed harvester.
  void _spawnBossItemDrops(CosmicBoss boss) {
    if (sandboxMode) return;
    final rng = Random();
    final faction = factionForElement(boss.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    if (boss.level >= 5) {
      // Lv5: guaranteed standard harvester, 20% portal key
      _spawnItemDrop(boss.position, harvesterKey);
      if (rng.nextDouble() < 0.20) {
        _spawnItemDrop(boss.position, portalKey);
      }
      // 25% chance for a guaranteed (stabilized) harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, 'item.harvest_guaranteed');
      }
    } else if (boss.level >= 4) {
      // Lv4: 60% harvester, 5% portal key
      if (rng.nextDouble() < 0.60) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
      if (rng.nextDouble() < 0.05) {
        _spawnItemDrop(boss.position, portalKey);
      }
    } else if (boss.level >= 3) {
      // Lv3: 25% harvester
      if (rng.nextDouble() < 0.25) {
        _spawnItemDrop(boss.position, harvesterKey);
      }
    }
    // Lv1-2: no item drops (shards + particles only)
  }

  /// Spawn item drops from a completed galaxy whirl (horde).
  /// Lv 3: small chance for a harvester.
  /// Lv 4: decent chance for harvester + 5% portal key.
  /// Lv 5: guaranteed harvester + 20% portal key + chance for stabilized harvester.
  void _spawnWhirlItemDrops(GalaxyWhirl whirl) {
    final rng = Random();
    final faction = factionForElement(whirl.element);
    final harvesterKey = 'item.harvest_std_$faction';
    final portalKey = 'item.portal_key.$faction';

    // Every whirl guarantees at least one harvester on clear.
    _spawnItemDrop(whirl.position, harvesterKey);

    if (whirl.level >= 5) {
      // Lv5: 20% portal key
      if (rng.nextDouble() < 0.20) {
        _spawnItemDrop(whirl.position, portalKey);
      }
      // 15% chance for stabilized harvester (slightly lower than boss)
      if (rng.nextDouble() < 0.15) {
        _spawnItemDrop(whirl.position, 'item.harvest_guaranteed');
      }
    } else if (whirl.level >= 4) {
      // Lv4: 5% portal key
      if (rng.nextDouble() < 0.05) {
        _spawnItemDrop(whirl.position, portalKey);
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
    onSound?.call(
      isBoss ? SoundCue.combatHitHeavy : SoundCue.combatEnemyDefeat,
    );
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
    if (sandboxMode) return;
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

    // Curtains of light in every hue (landmark_art.dart); until the reward
    // is claimed, a turning ring of the eight hues marks the heart a
    // prismatic companion must be brought to.
    paintPrismaticAurora(
      canvas,
      at: pp,
      radius: pf.radius,
      t: t,
      claimed: prismaticRewardClaimed,
    );

    // ── Label (drawn every frame) ──
    // Its colour walks the aurora's eight in 1/32 steps (one every ~0.1 s,
    // too fine to see) so the 256 shades are laid out once and reused.
    final ci = ((t * 0.3).floor()) % 8;
    final labelColor = Color.lerp(
      PrismaticField.auroraColors[ci],
      PrismaticField.auroraColors[(ci + 1) % 8],
      (((t * 0.3) % 1.0) * 32).floor() / 32,
    )!.withValues(alpha: 0.7);
    final labelTp = _worldLabel(
      'PRISMATIC AURORA',
      color: labelColor,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 2,
    );
    labelTp.paint(
      canvas,
      Offset(pp.dx - labelTp.width / 2, pp.dy + pf.radius + 14),
    );
  }

  /// Renders the pocket's soft glows to an off-screen texture, once: they
  /// never change but for a gentle pulse, which the draw applies as alpha.
  ui.Image _buildPocketTexture() {
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

    // Pocket boundary glow (faint ring)
    paintSoftRing(
      c,
      center,
      ElementalNexus.pocketRadius * scale,
      const Color(0xFF7C4DFF).withValues(alpha: 0.08),
      40 * scale,
      30 * scale,
    );

    // 4 elemental portal glows (only the blurred outer glow + rim ring)
    final portals = ElementalNexus.pocketPortalPositions(Offset.zero);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFFB08968), // Earth
      Color(0xFF81D4FA), // Air
    ];
    for (var i = 0; i < 4; i++) {
      final pp = Offset(
        center.dx + portals[i].dx * scale,
        center.dy + portals[i].dy * scale,
      );
      final col = portalColors[i];

      // The wash the rift sits in (the rift itself is drawn per frame).
      paintSoftCircle(
        c,
        pp,
        ElementalNexus.pocketPortalRadius * 1.25 * scale,
        col.withValues(alpha: 0.2),
        40 * scale,
      );
    }

    // Center marker glow
    paintSoftCircle(
      c,
      center,
      20 * scale,
      const Color(0xFF7C4DFF).withValues(alpha: 0.12),
      12 * scale,
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync(sz, sz);
    picture.dispose();
    return image;
  }

  void _spawnHitSpark(Offset pos, Color color) {
    onSound?.call(SoundCue.combatHitLight);
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

  // All ship-damage values (enemy contact, boss collision/projectile) are
  // authored against the legacy 6 HP ship pool. The pool was widened to
  // give heal math and the HUD usable resolution; rescaling damage here
  // keeps ship survivability and relative threat exactly unchanged.
  static const double _legacyShipHp = 6.0;

  void _damageShip(double damage) {
    if (_shipDead || _shipInvincible > 0) return;
    if (sandboxMode) return; // Ship is invincible in sandbox
    shipHealth -= damage * (CosmicGame.shipMaxHealth / _legacyShipHp);
    onSound?.call(SoundCue.combatPlayerHurt);
    _shipInvincible = 0.65; // brief invincibility after hit

    // Hit flash particles around ship
    _spawnHitSpark(ship.pos, Colors.redAccent);

    if (shipHealth <= 0) {
      // A deployed Fire kin's phoenix catches the ship once and is reborn
      // (cosmic_game_kin.dart).
      if (_tryOpenKinPhoenixSave()) return;
      if (sandboxMode) {
        _spawnKillVfx(ship.pos, const Color(0xFF00E5FF), 18, true);
        resetSandboxCombatState();
        return;
      }
      shipHealth = 0;
      _shipDead = true;
      onSound?.call(SoundCue.combatDefeat);
      _respawnTimer = 2.5; // 2.5s respawn delay
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
      // A Kin Crystal refractor turns what it took into a beam at the nearest
      // foe (cosmic_game_kin.dart).
      _refractOpenKinShot(orb);
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
    starDustScanTarget: _starDustScannerTargetIndex,
    planetScanTarget: _planetScannerTargetIndex,
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
    // A scan that was paid for stays locked. The getters drop a target that
    // has since been collected or discovered.
    final dust = state.starDustScanTarget;
    if (dust != null && dust >= 0 && dust < starDusts.length) {
      _starDustScannerTargetIndex = dust;
    }
    final planet = state.planetScanTarget;
    if (planet != null && planet >= 0 && planet < world_.planets.length) {
      _planetScannerTargetIndex = planet;
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
  bool get hasUndiscoveredPlanets => world_.discoveredCount < world_.totalCount;

  int? get starDustScannerTargetIndex => _starDustScannerTargetIndex;
  int? get planetScannerTargetIndex => _planetScannerTargetIndex;

  StarDust? get starDustScannerTarget {
    final idx = _starDustScannerTargetIndex;
    if (idx == null || idx < 0 || idx >= starDusts.length) return null;
    final dust = starDusts[idx];
    return dust.collected ? null : dust;
  }

  CosmicPlanet? get planetScannerTarget {
    final idx = _planetScannerTargetIndex;
    if (idx == null || idx < 0 || idx >= world_.planets.length) return null;
    final planet = world_.planets[idx];
    return planet.discovered ? null : planet;
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
    if (starDustScannerTarget != null) {
      return 'Scanner already locked. The radar points to your target.';
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

  String? activatePlanetScanner(SpacePOI scanner, {int shardCost = 50}) {
    syncPlanetScannerAvailability();
    if (scanner.type != POIType.planetScanner || !spacePOIs.contains(scanner)) {
      return 'Planet scanner unavailable.';
    }
    if (!hasUndiscoveredPlanets) {
      return 'All planets have been discovered. Scanner offline.';
    }
    if (planetScannerTarget != null) {
      return 'Scanner already locked. The radar points to your target.';
    }
    if (shipWallet.shards < shardCost) {
      return 'Not enough shards. Need $shardCost to activate the scanner.';
    }

    final target = _nearestUndiscoveredPlanet();
    if (target == null) {
      return 'No undiscovered planets found.';
    }

    shipWallet.shards -= shardCost;
    _planetScannerTargetIndex = target.$1;
    _relocatePlanetScanner(scanner);
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

  static final Map<String, TextPainter> _pocketLabels = {};

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

    // ── The soft glows, baked once (boundary, portal washes, centre) ──
    final img = _pocketCachedImage ??= _buildPocketTexture();

    final pocketWorldR = ElementalNexus.pocketRadius + 200;
    canvas.save();
    canvas.translate(center.dx - pocketWorldR, center.dy - pocketWorldR);
    canvas.scale(
      pocketWorldR * 2 / CosmicGame._pocketTexSize,
      pocketWorldR * 2 / CosmicGame._pocketTexSize,
    );
    canvas.drawImage(
      img,
      Offset.zero,
      _pocketPaint
        ..color = Color.fromRGBO(
          255,
          255,
          255,
          0.85 + 0.15 * sin(_riftPulse * 2.0),
        ),
    );
    canvas.restore();

    // ── Per-frame elements (cheap: no blur) ──
    // 4 elemental portals — the same grain rift the world's rifts and the
    // First Crossing use, drawn big. Each steps on the pocket's own clock.
    final portals = ElementalNexus.pocketPortalPositions(center);
    const portalColors = [
      Color(0xFFFF5722), // Fire
      Color(0xFF448AFF), // Water
      Color(0xFFB08968), // Earth
      Color(0xFF81D4FA), // Air
    ];
    const portalLabels = ['FIRE', 'WATER', 'EARTH', 'AIR'];
    const portalR = ElementalNexus.pocketPortalRadius;
    // What the screen shows of the pocket (it is drawn unscaled), grown by
    // the farthest a portal's dust reaches.
    final view = Rect.fromLTWH(
      cx,
      cy,
      screenW,
      screenH,
    ).inflate(portalR * 2.8 + 24);

    for (var i = 0; i < 4; i++) {
      final pp = portals[i];
      final col = portalColors[i];
      final key = 'pocket_${ElementalNexus.pocketElements[i]}';

      final field = _riftFields.putIfAbsent(
        key,
        () => RiftVortexField(
          grains: 900,
          ringGrains: 160,
          motes: 40,
          core: 0.27,
          grainSize: 2.8,
        )..open = 1,
      );
      final last = _riftFieldTimes[key] ?? _riftPulse;
      _riftFieldTimes[key] = _riftPulse;
      field.step((_riftPulse - last).clamp(0.0, 0.05));
      // Off screen it keeps turning, but its 1,100 grains are not drawn.
      if (!view.contains(pp)) continue;
      // The one the ship is at draws in, as the key does on the wild rifts.
      field.charge = nearPocketPortalElement == ElementalNexus.pocketElements[i]
          ? 0.35
          : 0;
      field.paint(
        canvas,
        Size.zero,
        pp,
        portalR,
        _riftPalettes.putIfAbsent(key, () => RiftPalette(col)),
        backdrop: false,
      );

      // Label — laid out once; it never changes.
      final tp = _pocketLabels.putIfAbsent(
        key,
        () => TextPainter(
          text: TextSpan(
            text: portalLabels[i],
            style: TextStyle(
              color: col.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.4,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
      tp.paint(canvas, Offset(pp.dx - tp.width / 2, pp.dy + portalR + 8));
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

  List<SpacePOI> _planetScannerPois() =>
      spacePOIs.where((poi) => poi.type == POIType.planetScanner).toList();

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

  (int, CosmicPlanet)? _nearestUndiscoveredPlanet() {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    (int, CosmicPlanet)? best;
    double bestDist = double.infinity;
    for (var i = 0; i < world_.planets.length; i++) {
      final planet = world_.planets[i];
      if (planet.discovered) continue;
      var dx = planet.position.dx - ship.pos.dx;
      var dy = planet.position.dy - ship.pos.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final d = sqrt(dx * dx + dy * dy);
      if (d < bestDist) {
        bestDist = d;
        best = (i, planet);
      }
    }
    return best;
  }

  void syncStarDustScannerAvailability() {
    final scanners = spacePOIs
        .where((poi) => poi.type == POIType.stardustScanner)
        .toList();
    final scanner = scanners.isEmpty ? null : scanners.first;
    if (!hasRemainingStarDust) {
      spacePOIs.removeWhere((poi) => poi.type == POIType.stardustScanner);
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

  void syncPlanetScannerAvailability({int desiredCount = 4}) {
    final scanners = _planetScannerPois();
    if (!hasUndiscoveredPlanets) {
      for (final scanner in scanners) {
        spacePOIs.remove(scanner);
      }
      _planetScannerTargetIndex = null;
      if (nearMarket?.type == POIType.planetScanner) {
        nearMarket = null;
        onNearMarket?.call(null);
      }
      return;
    }

    while (scanners.length < desiredCount) {
      final newScanner = SpacePOI(
        position: ship.pos,
        type: POIType.planetScanner,
        element: 'Water',
        radius: 120,
        discovered: false,
      );
      spacePOIs.add(newScanner);
      scanners.add(newScanner);
      _relocatePlanetScanner(newScanner);
    }

    while (scanners.length > desiredCount) {
      final scanner = scanners.removeLast();
      spacePOIs.remove(scanner);
      if (nearMarket == scanner) {
        nearMarket = null;
        onNearMarket?.call(null);
      }
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

  void _relocatePlanetScanner(SpacePOI scanner) {
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
