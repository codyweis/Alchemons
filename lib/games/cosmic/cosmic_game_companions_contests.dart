part of 'cosmic_game.dart';

/// Horn family gets bonus HP and DEF since they're the tanks.
double _familyHpMultiplier(String family) => family == 'horn' ? 1.30 : 1.0;
double _familyDefMultiplier(String family) => family == 'horn' ? 1.20 : 1.0;

extension CosmicGameCompanionsAndContests on CosmicGame {
  void summonCompanion(
    CosmicPartyMember member, {
    double hpFraction = 1.0,
    double? initialSpecialCooldown,
  }) {
    // Block swapping companions during a ring battle — callers may not
    // always check this (UI normally does), so enforce it here.
    if (battleRing.inBattle) return;

    // If there's already a companion deployed, recall it first so the
    // newly summoned companion replaces it (UI previously handled this,
    // but other callers may not). We don't wait for the return animation
    // — that mirrors the existing immediate-swap behavior.
    if (activeCompanion != null) {
      returnCompanion();
    }

    // Build stats from SurvivalUnit formulas, but scaled DOWN for cosmic
    // mode where enemies have no DEF (survival enemies reduce damage via
    // armour — here every point of physAtk is raw damage).
    final speed = member.statSpeed.toDouble();
    final intel = member.statIntelligence.toDouble();
    final strength = member.statStrength.toDouble();
    final beauty = member.statBeauty.toDouble();

    final level = CosmicBalance.clampCompanionLevel(member.level);
    final family = member.family.toLowerCase();

    final maxHp =
        (CosmicBalance.companionMaxHp(
                  level: level,
                  strength: strength,
                  intelligence: intel,
                ) *
                _familyHpMultiplier(family))
            .round();
    final physAtk = CosmicBalance.companionPhysAtk(
      level: level,
      strength: strength,
    );
    final elemAtk = CosmicBalance.companionElemAtk(
      level: level,
      beauty: beauty,
    );
    final physDef =
        (CosmicBalance.companionPhysDef(
                  level: level,
                  strength: strength,
                  intelligence: intel,
                ) *
                _familyDefMultiplier(family))
            .round();
    final elemDef =
        (CosmicBalance.companionElemDef(
                  level: level,
                  beauty: beauty,
                  intelligence: intel,
                ) *
                _familyDefMultiplier(family))
            .round();
    final cooldownReduction = CosmicBalance.companionCooldownReduction(speed);
    final critChance = CosmicBalance.companionCritChance(strength);
    final baseRange = CosmicBalance.companionBaseRange(intel);

    // Species-based scale
    final specScale = (CosmicGame._companionSpeciesScale[family] ?? 1.0) * 1.0;

    // Place at the ship's current position
    final placePos = Offset(ship.pos.dx, ship.pos.dy);

    final startHp = (maxHp * hpFraction.clamp(0.0, 1.0)).round().clamp(
      1,
      maxHp,
    );

    final companion = CosmicCompanion(
      member: member,
      position: placePos,
      anchor: placePos,
      maxHp: maxHp,
      currentHp: startHp,
      physAtk: physAtk,
      elemAtk: elemAtk,
      physDef: physDef,
      elemDef: elemDef,
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: _familyAttackRange(family, baseRange),
      specialAbilityRange: _familySpecialRange(family, baseRange),
      speciesScale: specScale,
    );
    companion.primeSpecialCooldown(savedCooldown: initialSpecialCooldown);
    activeCompanion = companion;

    // Attach a demo effect instance based on loaded prototypes (one per companion).
    try {
      if (_loadedEffectPrototypes.isNotEmpty) {
        final proto =
            _loadedEffectPrototypes[member.level %
                _loadedEffectPrototypes.length];
        final inst = EffectRegistry.create(proto.toJson());
        activeCompanion?.addEffect(inst);
      }
    } catch (_) {}

    // Load animated sprite for the companion
    _loadCompanionSprite(member);
  }

  Future<void> _loadCompanionSprite(CosmicPartyMember member) async {
    final sheet = member.spriteSheet;
    if (sheet == null) {
      _companionTicker = null;
      _companionVisuals = null;
      return;
    }

    try {
      final image = await images.load(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      _companionTicker = anim.createTicker();
      _companionVisuals = member.spriteVisuals;
      debugPrint(
        'Companion visuals loaded: alchemy=${_companionVisuals?.alchemyEffect} variant=${_companionVisuals?.variantFaction} tint=${_companionVisuals?.tint}',
      );
      // Fit sprite into ~48px box, then apply species + 30% scale
      final desiredSize = 48.0;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = activeCompanion?.speciesScale ?? 1.3;
      _companionSpriteScale =
          min(sx, sy) * (_companionVisuals?.scale ?? 1.0) * specScale;
    } catch (e) {
      debugPrint('Failed to load companion sprite: ${sheet.path} - $e');
      _companionTicker = null;
      _companionVisuals = null;
    }
  }

  void returnCompanion() {
    if (activeCompanion != null) {
      activeCompanion!.returning = true;
      activeCompanion!.returnTimer = 0.6; // fade out over 0.6s
    }
  }

  /// Spawn a battle ring opponent at the ring center.
  void spawnBattleRingOpponent(CosmicPartyMember member) {
    final speed = member.statSpeed.toDouble();
    final intel = member.statIntelligence.toDouble();
    final strength = member.statStrength.toDouble();
    final beauty = member.statBeauty.toDouble();

    final level = CosmicBalance.clampCompanionLevel(member.level);
    final family = member.family.toLowerCase();

    final maxHp =
        (CosmicBalance.companionMaxHp(
                  level: level,
                  strength: strength,
                  intelligence: intel,
                ) *
                _familyHpMultiplier(family))
            .round();
    final physAtk = CosmicBalance.companionPhysAtk(
      level: level,
      strength: strength,
    );
    final elemAtk = CosmicBalance.companionElemAtk(
      level: level,
      beauty: beauty,
    );
    final physDef =
        (CosmicBalance.companionPhysDef(
                  level: level,
                  strength: strength,
                  intelligence: intel,
                ) *
                _familyDefMultiplier(family))
            .round();
    final elemDef =
        (CosmicBalance.companionElemDef(
                  level: level,
                  beauty: beauty,
                  intelligence: intel,
                ) *
                _familyDefMultiplier(family))
            .round();
    final cooldownReduction = CosmicBalance.companionCooldownReduction(speed);
    final critChance = CosmicBalance.companionCritChance(strength);
    final baseRange = CosmicBalance.companionBaseRange(intel);

    final specScale = (CosmicGame._companionSpeciesScale[family] ?? 1.0) * 1.0;

    // Use spawnPosition if provided, else default to ring center
    final placePos = member.spawnPosition ?? battleRing.position;

    battleRingOpponent = CosmicCompanion(
      member: member,
      position: placePos,
      anchor: placePos,
      maxHp: maxHp,
      currentHp: maxHp,
      physAtk: physAtk,
      elemAtk: elemAtk,
      physDef: physDef,
      elemDef: elemDef,
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: _familyAttackRange(family, baseRange),
      specialAbilityRange: _familySpecialRange(family, baseRange),
      speciesScale: specScale,
      invincibleTimer: 1.5,
      visualVariant: member.visualVariant,
    );
    ringOpponentProjectiles.clear();

    // Spawn a few small assisting wisps/minions depending on opponent level.
    // Use a gentle scale so higher levels spawn a few more helpers.
    // Schedule ring minions to spawn later when the opponent reaches
    // half health. We compute the planned count/level/element now and
    // create them on the health-threshold trigger so they appear like
    // portals mid-fight.
    _ringMinionsSpawnedForCurrentOpponent = false;
    _pendingRingMinionCount = ((level) / 2).floor().clamp(0, 6);
    _pendingRingMinionLevel = level;
    _pendingRingMinionElement = member.element;
    debugPrint(
      'Scheduled $_pendingRingMinionCount ring minions for level $level',
    );

    // Reset and preload static sprite fallback.
    _ringOpponentFallbackSprite = null;
    _ringOpponentFallbackScale = 1.0;
    _loadRingOpponentFallbackSprite(member);

    // Load sprite
    _loadRingOpponentSprite(member);
  }

  String _toBundleImageKey(String raw) {
    if (raw.startsWith('assets/')) return raw;
    if (raw.startsWith('images/')) return 'assets/$raw';
    return 'assets/images/$raw';
  }

  String _toFlameImageKey(String raw) {
    if (raw.startsWith('assets/images/')) {
      return raw.substring('assets/images/'.length);
    }
    if (raw.startsWith('assets/')) {
      return raw.substring('assets/'.length);
    }
    return raw;
  }

  Future<ui.Image> _loadUiImageFromBundle(String bundleKey) async {
    final data = await rootBundle.load(bundleKey);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _loadRingOpponentFallbackSprite(CosmicPartyMember member) async {
    final rawPath = member.imagePath;
    if (rawPath == null || rawPath.trim().isEmpty) return;
    final expectedInstanceId = member.instanceId;
    final token = ++_ringOpponentFallbackLoadToken;
    try {
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(rawPath));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(rawPath));
      }
      if (token != _ringOpponentFallbackLoadToken ||
          battleRingOpponent?.member.instanceId != expectedInstanceId) {
        return;
      }
      _ringOpponentFallbackSprite = Sprite(image);
      final desiredSize = 48.0;
      final sx = desiredSize / image.width;
      final sy = desiredSize / image.height;
      final specScale = battleRingOpponent?.speciesScale ?? 1.3;
      _ringOpponentFallbackScale =
          min(sx, sy) * (member.spriteVisuals?.scale ?? 1.0) * specScale;
    } catch (e) {
      debugPrint('Failed to load ring opponent fallback sprite: $rawPath - $e');
    }
  }

  Future<void> _loadRingOpponentSprite(CosmicPartyMember member) async {
    final loadToken = ++_ringOpponentSpriteLoadToken;
    final expectedInstanceId = member.instanceId;
    final sheet = member.spriteSheet;
    final sheetPath = sheet?.path ?? '<no-sheet>';
    _ringOpponentSpriteLoadsInFlight++;
    try {
      if (sheet == null) {
        if (loadToken == _ringOpponentSpriteLoadToken &&
            battleRingOpponent?.member.instanceId == expectedInstanceId) {
          _ringOpponentTicker = null;
          _ringOpponentVisuals = null;
        }
        return;
      }
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(sheet.path));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(sheet.path));
      }
      if (loadToken != _ringOpponentSpriteLoadToken ||
          battleRingOpponent?.member.instanceId != expectedInstanceId) {
        return;
      }
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      _ringOpponentTicker = anim.createTicker();
      _ringOpponentVisuals = member.spriteVisuals;
      debugPrint(
        'Ring opponent visuals loaded: alchemy=${_ringOpponentVisuals?.alchemyEffect} variant=${_ringOpponentVisuals?.variantFaction} tint=${_ringOpponentVisuals?.tint}',
      );
      final desiredSize = 48.0;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = battleRingOpponent?.speciesScale ?? 1.3;
      _ringOpponentSpriteScale =
          min(sx, sy) * (_ringOpponentVisuals?.scale ?? 1.0) * specScale;
      _ringOpponentSpriteRetryTimer = 0.0;
    } catch (e) {
      debugPrint('Failed to load ring opponent sprite: $sheetPath - $e');
      if (loadToken == _ringOpponentSpriteLoadToken &&
          battleRingOpponent?.member.instanceId == expectedInstanceId) {
        _ringOpponentTicker = null;
        _ringOpponentVisuals = null;
      }
    } finally {
      _ringOpponentSpriteLoadsInFlight = max(
        0,
        _ringOpponentSpriteLoadsInFlight - 1,
      );
    }
  }

  // Spawn the pending ring minions (called when opponent hits half health).
  void _spawnPendingRingMinions() {
    if (_pendingRingMinionCount <= 0 || battleRingOpponent == null) return;
    ringMinions.clear();
    final level = _pendingRingMinionLevel;
    final element =
        _pendingRingMinionElement ?? battleRingOpponent!.member.element;
    final placePos = battleRingOpponent!.anchorPosition;
    // Decide how many chargers vs shooters. Chargers are the slow, tanky
    // slam units that spawn opposite the player's companion and do high
    // contact damage. Shooters spawn around the arena and fire at the
    // companion. We aim for 3-5 chargers (depending on level) but never
    // exceed the total pending count.
    final desiredChargers = (3 + (level ~/ 5)).clamp(3, 5);
    final chargersToSpawn = min(_pendingRingMinionCount, desiredChargers);
    final shootersToSpawn = max(0, _pendingRingMinionCount - chargersToSpawn);

    // Spawn shooters around the ring center
    for (var si = 0; si < shootersToSpawn; si++) {
      final ang = _rng.nextDouble() * 2 * pi;
      final startRadius = 30.0 + _rng.nextDouble() * 20.0;
      final pos = Offset(
        placePos.dx + cos(ang) * startRadius,
        placePos.dy + sin(ang) * startRadius,
      );
      final m = RingMinion(
        position: pos,
        element: element,
        health: 10.0 + level * 1.8,
        radius: 10.0,
        speed: 70.0 + level * 4.0,
      );
      m.type = 'shooter';
      m.shootCooldown = 0.5 + _rng.nextDouble() * 1.0;
      m.orbitCenter = battleRing.position;
      m.orbitAngle = ang;
      m.orbitRadius = startRadius;
      m.orbitTime = 0.6 + _rng.nextDouble() * 0.9;
      ringMinions.add(m);
    }

    // Spawn chargers opposite the player's companion (if present), else
    // place them around the ring edge.
    final comp = activeCompanion;
    for (var ci = 0; ci < chargersToSpawn; ci++) {
      double ang;
      double spawnR = BattleRing.visualRadius - 20.0 + _rng.nextDouble() * 24.0;
      if (comp != null && comp.isAlive) {
        // Angle from ring center -> companion, then flip to opposite side
        final baseAng = atan2(
          comp.position.dy - battleRing.position.dy,
          comp.position.dx - battleRing.position.dx,
        );
        ang = baseAng + pi + ((_rng.nextDouble() - 0.5) * 0.6);
      } else {
        ang = _rng.nextDouble() * 2 * pi;
      }
      final pos = Offset(
        battleRing.position.dx + cos(ang) * spawnR,
        battleRing.position.dy + sin(ang) * spawnR,
      );
      final m = RingMinion(
        position: pos,
        element: element,
        // Slightly less tanky than before to avoid overwhelming damage
        health: 20.0 + level * 6.0,
        radius: 14.0,
        speed: 34.0 + level * 1.5,
      );
      m.type = 'charger';
      m.orbitCenter = battleRing.position;
      m.orbitAngle = ang;
      m.orbitRadius = spawnR;
      m.orbitTime = 0.6 + _rng.nextDouble() * 0.9;
      ringMinions.add(m);
    }
    _ringMinionsSpawnedForCurrentOpponent = true;
    debugPrint('Spawned ${ringMinions.length} ring minions at $placePos');
  }

  void dismissBattleRingOpponent() {
    battleRingOpponent = null;
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    _ringOpponentTicker = null;
    _ringOpponentVisuals = null;
    _ringOpponentFallbackSprite = null;
    _ringOpponentFallbackScale = 1.0;
    _ringOpponentFallbackLoadToken++;
    _ringOpponentSpriteLoadToken++;
    _ringOpponentSpriteRetryTimer = 0.0;
    _ringOpponentSpriteLoadsInFlight = 0;
    // Reset pending minion spawn state
    _ringMinionsSpawnedForCurrentOpponent = false;
    _pendingRingMinionCount = 0;
    _pendingRingMinionLevel = 0;
    _pendingRingMinionElement = null;
  }

  void cancelBattleRingFight() {
    if (!battleRing.inBattle) return;
    battleRing.inBattle = false;
    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    dismissBattleRingOpponent();
    if (activeCompanion != null &&
        activeCompanion!.isAlive &&
        !activeCompanion!.returning) {
      returnCompanion();
    }
    onBattleRingCancelled?.call();
  }

  void beginBeautyContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.beauty;
    _beautyContestShipIntroStart = ship.pos;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    // Spawn real opponent sprite/visuals in arena.
    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const orbitR = 170.0;
    const introOppOffset = Offset(220, -80);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi) * orbitR,
      _beautyContestCenter.dy + sin(pi) * orbitR * 0.48,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + cos(0) * orbitR,
      _beautyContestCenter.dy + sin(0) * orbitR * 0.48,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.32,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      // Beauty contest should show full sprites immediately (no summon scale-in).
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginSpeedContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.speed;
    _beautyContestShipIntroStart = ship.pos;

    final scoreGap = (playerScore - opponentScore).abs().clamp(0.0, 1.5);
    final lead = 0.06 + scoreGap * 0.05;
    if (playerWon) {
      _speedContestCompRate = 1.0 + lead;
      _speedContestOppRate = 1.0 - lead * 0.65;
    } else {
      _speedContestCompRate = 1.0 - lead * 0.65;
      _speedContestOppRate = 1.0 + lead;
    }
    _speedContestRaceDuration = 11.0;
    _speedContestCompProgress = pi * 0.5;
    _speedContestOppProgress = pi * 0.5 - 0.18;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const outerRx = 222.0;
    const outerRy = 124.0;
    const introOppOffset = Offset(240, -60);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi * 0.5) * outerRx,
      _beautyContestCenter.dy + sin(pi * 0.5) * outerRy,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + cos(pi * 0.5 - 0.18) * (outerRx - 32),
      _beautyContestCenter.dy + sin(pi * 0.5 - 0.18) * (outerRy - 22),
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.30,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginStrengthContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.strength;
    _beautyContestShipIntroStart = ship.pos;

    final gap = (playerScore - opponentScore).abs().clamp(0.0, 1.8);
    final lead = 0.07 + gap * 0.06;
    if (playerWon) {
      _strengthContestCompForce = 1.0 + lead;
      _strengthContestOppForce = 1.0 - lead * 0.58;
    } else {
      _strengthContestCompForce = 1.0 - lead * 0.58;
      _strengthContestOppForce = 1.0 + lead;
    }
    _strengthContestDuration = 11.0;
    _strengthContestShift = 0.0;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const introOppOffset = Offset(210, -42);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx - 128,
      _beautyContestCenter.dy + 20,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + 128,
      _beautyContestCenter.dy + 20,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.28,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void beginIntelligenceContestCinematic({
    required CosmicPartyMember opponentMember,
    required Offset arenaCenter,
    required bool playerWon,
    required double playerScore,
    required double opponentScore,
  }) {
    if (activeCompanion == null) return;
    _beautyContestCinematicActive = true;
    _beautyContestCenter = arenaCenter;
    _beautyContestPlayerWon = playerWon;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = true;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.intelligence;
    _beautyContestShipIntroStart = ship.pos;

    final gap = (playerScore - opponentScore).abs().clamp(0.0, 1.8);
    final lead = 0.08 + gap * 0.05;
    if (playerWon) {
      _intelligenceContestCompFocus = 1.0 + lead;
      _intelligenceContestOppFocus = 1.0 - lead * 0.60;
    } else {
      _intelligenceContestCompFocus = 1.0 - lead * 0.60;
      _intelligenceContestOppFocus = 1.0 + lead;
    }
    _intelligenceContestDuration = 11.0;
    _intelligenceContestBias = 0.0;
    _intelligenceContestOrbit = 0.0;
    _intelligenceContestOrbPos = _beautyContestCenter;

    shooting = false;
    shootingMissiles = false;
    boosting = false;

    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    ringMinions.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnBattleRingOpponent(opponentMember);
    _ringOpponentSpriteRetryTimer = 1.1;
    battleRing.inBattle = false;

    const introOppOffset = Offset(230, -56);
    final compIntroTarget = Offset(
      _beautyContestCenter.dx - 144,
      _beautyContestCenter.dy + 12,
    );
    final oppIntroTarget = Offset(
      _beautyContestCenter.dx + 144,
      _beautyContestCenter.dy + 12,
    );

    final comp = activeCompanion!;
    _beautyContestCompIntroStart = comp.position;
    if ((_beautyContestCompIntroStart - _beautyContestCenter).distance > 900) {
      _beautyContestCompIntroStart = _toroidalLerp(
        compIntroTarget,
        _beautyContestCenter,
        0.28,
      );
      comp.position = _beautyContestCompIntroStart;
      comp.anchorPosition = comp.position;
    }
    comp.life = max(comp.life, 1.0);
    comp.returning = false;
    comp.returnTimer = 0;

    if (battleRingOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      battleRingOpponent!.position = _beautyContestOppIntroStart;
      battleRingOpponent!.anchorPosition = battleRingOpponent!.position;
      battleRingOpponent!.life = 1.0;
      battleRingOpponent!.returning = false;
      battleRingOpponent!.returnTimer = 0;
    }
  }

  void endBeautyContestCinematic() {
    if (!_beautyContestCinematicActive) return;
    _beautyContestCinematicActive = false;
    _beautyContestTimer = 0;
    _beautyContestCompAbilityA = false;
    _beautyContestOppAbilityA = false;
    _beautyContestCompAbilityB = false;
    _beautyContestOppAbilityB = false;
    _beautyContestCompHopTimer = 0;
    _beautyContestOppHopTimer = 0;
    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;
    _beautyContestIntroActive = false;
    _beautyContestIntroTimer = 0;
    _contestCinematicMode = _ContestCinematicMode.beauty;
    _speedContestRaceDuration = 11.0;
    _speedContestCompRate = 1.0;
    _speedContestOppRate = 1.0;
    _speedContestCompProgress = pi * 0.5;
    _speedContestOppProgress = pi * 0.5 - 0.18;
    _strengthContestDuration = 11.0;
    _strengthContestCompForce = 1.0;
    _strengthContestOppForce = 1.0;
    _strengthContestShift = 0.0;
    _intelligenceContestDuration = 11.0;
    _intelligenceContestCompFocus = 1.0;
    _intelligenceContestOppFocus = 1.0;
    _intelligenceContestBias = 0.0;
    _intelligenceContestOrbit = 0.0;
    _intelligenceContestOrbPos = Offset.zero;
    companionProjectiles.clear();
    ringOpponentProjectiles.clear();
    dismissBattleRingOpponent();
  }

  void _updateBeautyContestCinematic(double dt) {
    final comp = activeCompanion;
    final opp = battleRingOpponent;
    if (comp == null || opp == null || !opp.isAlive) {
      endBeautyContestCinematic();
      return;
    }

    _beautyContestTimer += dt;
    _riftPulse += dt;
    _beautyContestCompHopTimer = max(0.0, _beautyContestCompHopTimer - dt);
    _beautyContestOppHopTimer = max(0.0, _beautyContestOppHopTimer - dt);
    _ringOpponentSpriteRetryTimer = max(
      0.0,
      _ringOpponentSpriteRetryTimer - dt,
    );
    _companionTicker?.update(dt);
    _ringOpponentTicker?.update(dt);

    // Retry opponent sprite load in-case an async load raced or failed.
    if (_ringOpponentTicker == null &&
        opp.member.spriteSheet != null &&
        _ringOpponentSpriteLoadsInFlight == 0 &&
        _ringOpponentSpriteRetryTimer <= 0) {
      _ringOpponentSpriteRetryTimer = 1.1;
      _loadRingOpponentSprite(opp.member);
    }

    if (_beautyContestIntroActive) {
      _beautyContestIntroTimer += dt;
      final introT = Curves.easeInOutCubic.transform(
        (_beautyContestIntroTimer / CosmicGame._beautyContestIntroDuration)
            .clamp(0.0, 1.0),
      );
      final compTarget = switch (_contestCinematicMode) {
        _ContestCinematicMode.speed => Offset(
          _beautyContestCenter.dx + cos(pi * 0.5) * 222.0,
          _beautyContestCenter.dy + sin(pi * 0.5) * 124.0,
        ),
        _ContestCinematicMode.strength => Offset(
          _beautyContestCenter.dx - 128,
          _beautyContestCenter.dy + 20,
        ),
        _ContestCinematicMode.intelligence => Offset(
          _beautyContestCenter.dx - 144,
          _beautyContestCenter.dy + 12,
        ),
        _ContestCinematicMode.beauty => Offset(
          _beautyContestCenter.dx + cos(pi) * 170.0,
          _beautyContestCenter.dy + sin(pi) * 170.0 * 0.48,
        ),
      };
      final oppTarget = switch (_contestCinematicMode) {
        _ContestCinematicMode.speed => Offset(
          _beautyContestCenter.dx + cos(pi * 0.5 - 0.18) * (222.0 - 32),
          _beautyContestCenter.dy + sin(pi * 0.5 - 0.18) * (124.0 - 22),
        ),
        _ContestCinematicMode.strength => Offset(
          _beautyContestCenter.dx + 128,
          _beautyContestCenter.dy + 20,
        ),
        _ContestCinematicMode.intelligence => Offset(
          _beautyContestCenter.dx + 144,
          _beautyContestCenter.dy + 12,
        ),
        _ContestCinematicMode.beauty => Offset(
          _beautyContestCenter.dx + cos(0) * 170.0,
          _beautyContestCenter.dy + sin(0) * 170.0 * 0.48,
        ),
      };
      ship.pos = _toroidalLerp(
        _beautyContestShipIntroStart,
        _beautyContestCenter,
        introT,
      );
      _revealAround(ship.pos, 220);

      comp.position = _toroidalLerp(
        _beautyContestCompIntroStart,
        compTarget,
        introT,
      );
      opp.position = _toroidalLerp(
        _beautyContestOppIntroStart,
        oppTarget,
        introT,
      );
      comp.anchorPosition = comp.position;
      opp.anchorPosition = opp.position;
      comp.angle = atan2(
        _beautyContestCenter.dy - comp.position.dy,
        _beautyContestCenter.dx - comp.position.dx,
      );
      opp.angle = atan2(
        _beautyContestCenter.dy - opp.position.dy,
        _beautyContestCenter.dx - opp.position.dx,
      );

      if (_beautyContestIntroTimer >= CosmicGame._beautyContestIntroDuration) {
        _beautyContestIntroActive = false;
        _beautyContestIntroTimer = 0;
        _beautyContestTimer = 0;
      }
      return;
    }

    if (_contestCinematicMode == _ContestCinematicMode.speed) {
      _updateSpeedContestCinematic(dt, comp, opp);
      return;
    }
    if (_contestCinematicMode == _ContestCinematicMode.strength) {
      _updateStrengthContestCinematic(dt, comp, opp);
      return;
    }
    if (_contestCinematicMode == _ContestCinematicMode.intelligence) {
      _updateIntelligenceContestCinematic(dt, comp, opp);
      return;
    }

    // Keep camera centered on contest arena.
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    final orbitA = _beautyContestTimer * CosmicGame._beautyContestOrbitSpeed;
    const orbitR = 170.0;
    final compPos = Offset(
      _beautyContestCenter.dx + cos(orbitA + pi) * orbitR,
      _beautyContestCenter.dy +
          sin(orbitA + pi) * orbitR * 0.48 -
          sin(
                (1 -
                        (_beautyContestCompHopTimer /
                                CosmicGame._beautyContestHopDuration)
                            .clamp(0.0, 1.0)) *
                    pi,
              ) *
              CosmicGame._beautyContestHopHeight,
    );
    final oppPos = Offset(
      _beautyContestCenter.dx + cos(orbitA) * orbitR,
      _beautyContestCenter.dy +
          sin(orbitA) * orbitR * 0.48 -
          sin(
                (1 -
                        (_beautyContestOppHopTimer /
                                CosmicGame._beautyContestHopDuration)
                            .clamp(0.0, 1.0)) *
                    pi,
              ) *
              CosmicGame._beautyContestHopHeight,
    );

    Offset resolvedCompPos = compPos;
    Offset resolvedOppPos = oppPos;
    if (_beautyContestTimer >= CosmicGame._beautyContestFinalPoseTime) {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - CosmicGame._beautyContestFinalPoseTime) /
                CosmicGame._beautyContestFinalPoseBlendDuration)
            .clamp(0.0, 1.0),
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      resolvedCompPos = Offset.lerp(compPos, playerTarget, finalT)!;
      resolvedOppPos = Offset.lerp(oppPos, oppTarget, finalT)!;
      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.18 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.18 - 1.0) * finalT;
      _beautyContestCompHopTimer = 0;
      _beautyContestOppHopTimer = 0;
    } else {
      _beautyContestCompVisualScale = 1.0;
      _beautyContestOppVisualScale = 1.0;
    }

    // Keep cinematic positions local to the arena center (no world wrapping),
    // otherwise one side can wrap off-screen near map edges.
    comp.position = resolvedCompPos;
    opp.position = resolvedOppPos;
    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;
    if (_beautyContestTimer >= CosmicGame._beautyContestFinalPoseTime) {
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    } else {
      comp.angle = atan2(
        _beautyContestCenter.dy - comp.position.dy,
        _beautyContestCenter.dx - comp.position.dx,
      );
      opp.angle = atan2(
        _beautyContestCenter.dy - opp.position.dy,
        _beautyContestCenter.dx - opp.position.dx,
      );
    }

    // Timed special-ability showcases.
    if (!_beautyContestCompAbilityA &&
        _beautyContestTimer >= CosmicGame._beautyContestCompAbilityATime) {
      _beautyContestCompAbilityA = true;
      _beautyContestCompHopTimer = CosmicGame._beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: comp.position,
        baseAngle: comp.angle,
        family: comp.member.family,
        element: comp.member.element,
        damage: max(6.0, comp.elemAtk * 1.5),
        maxHp: comp.maxHp,
        casterPower: comp.member.statIntelligence.toDouble(),
        casterBeauty: comp.member.statBeauty.toDouble(),
        casterIntelligence: comp.member.statIntelligence.toDouble(),
        targetPos: opp.position,
      );
      companionProjectiles.addAll(result.projectiles);
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
    }
    if (!_beautyContestOppAbilityA &&
        _beautyContestTimer >= CosmicGame._beautyContestOppAbilityATime) {
      _beautyContestOppAbilityA = true;
      _beautyContestOppHopTimer = CosmicGame._beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: opp.position,
        baseAngle: opp.angle,
        family: opp.member.family,
        element: opp.member.element,
        damage: max(6.0, opp.elemAtk * 1.5),
        maxHp: opp.maxHp,
        casterPower: opp.member.statIntelligence.toDouble(),
        casterBeauty: opp.member.statBeauty.toDouble(),
        casterIntelligence: opp.member.statIntelligence.toDouble(),
        targetPos: comp.position,
      );
      ringOpponentProjectiles.addAll(result.projectiles);
      _spawnHitSpark(opp.position, elementColor(opp.member.element));
    }
    if (!_beautyContestCompAbilityB &&
        _beautyContestTimer >= CosmicGame._beautyContestCompAbilityBTime) {
      _beautyContestCompAbilityB = true;
      _beautyContestCompHopTimer = CosmicGame._beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: comp.position,
        baseAngle: comp.angle + pi * 0.18,
        family: comp.member.family,
        element: comp.member.element,
        damage: max(6.0, comp.elemAtk * 1.4),
        maxHp: comp.maxHp,
        casterPower: comp.member.statIntelligence.toDouble(),
        casterBeauty: comp.member.statBeauty.toDouble(),
        casterIntelligence: comp.member.statIntelligence.toDouble(),
        targetPos: opp.position,
      );
      companionProjectiles.addAll(result.projectiles);
      _spawnHitSpark(comp.position, elementColor(comp.member.element));
    }
    if (!_beautyContestOppAbilityB &&
        _beautyContestTimer >= CosmicGame._beautyContestOppAbilityBTime) {
      _beautyContestOppAbilityB = true;
      _beautyContestOppHopTimer = CosmicGame._beautyContestHopDuration;
      final result = createCosmicSpecialAbility(
        origin: opp.position,
        baseAngle: opp.angle + pi * 0.16,
        family: opp.member.family,
        element: opp.member.element,
        damage: max(6.0, opp.elemAtk * 1.4),
        maxHp: opp.maxHp,
        casterPower: opp.member.statIntelligence.toDouble(),
        casterBeauty: opp.member.statBeauty.toDouble(),
        casterIntelligence: opp.member.statIntelligence.toDouble(),
        targetPos: comp.position,
      );
      ringOpponentProjectiles.addAll(result.projectiles);
      _spawnHitSpark(opp.position, elementColor(opp.member.element));
    }

    // Move only contest showcase projectiles and vfx (no combat/collisions).
    void updateContestProjectiles(List<Projectile> list) {
      for (var i = list.length - 1; i >= 0; i--) {
        final p = list[i];
        final pSpeed = Projectile.speed * p.speedMultiplier;
        if (p.orbitCenter != null && p.orbitTime > 0) {
          p.orbitTime -= dt;
          p.orbitAngle += p.orbitSpeed * dt;
          p.orbitRadius += dt * 8.0;
          p.position = Offset(
            p.orbitCenter!.dx + cos(p.orbitAngle) * p.orbitRadius,
            p.orbitCenter!.dy + sin(p.orbitAngle) * p.orbitRadius,
          );
          if (p.orbitTime <= 0) {
            p.angle = atan2(
              p.position.dy - p.orbitCenter!.dy,
              p.position.dx - p.orbitCenter!.dx,
            );
            p.orbitCenter = null;
          }
        } else {
          p.position = Offset(
            p.position.dx + cos(p.angle) * pSpeed * dt,
            p.position.dy + sin(p.angle) * pSpeed * dt,
          );
        }
        p.life -= dt;
        if (p.life <= 0) list.removeAt(i);
      }
    }

    updateContestProjectiles(companionProjectiles);
    updateContestProjectiles(ringOpponentProjectiles);

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateSpeedContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    const outerRx = 222.0;
    const outerRy = 124.0;
    const innerRx = 190.0;
    const innerRy = 102.0;
    const angularBase = 1.65;

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    if (_beautyContestTimer < _speedContestRaceDuration) {
      _speedContestCompProgress += dt * angularBase * _speedContestCompRate;
      _speedContestOppProgress += dt * angularBase * _speedContestOppRate;

      final compBob = sin(_beautyContestTimer * 8.2) * 4.0;
      final oppBob = sin(_beautyContestTimer * 8.2 + 1.2) * 4.0;

      comp.position = Offset(
        _beautyContestCenter.dx + cos(_speedContestCompProgress) * outerRx,
        _beautyContestCenter.dy +
            sin(_speedContestCompProgress) * outerRy -
            compBob,
      );
      opp.position = Offset(
        _beautyContestCenter.dx + cos(_speedContestOppProgress) * innerRx,
        _beautyContestCenter.dy +
            sin(_speedContestOppProgress) * innerRy -
            oppBob,
      );

      comp.angle = atan2(
        outerRy * cos(_speedContestCompProgress),
        -outerRx * sin(_speedContestCompProgress),
      );
      opp.angle = atan2(
        innerRy * cos(_speedContestOppProgress),
        -innerRx * sin(_speedContestOppProgress),
      );
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _speedContestRaceDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );

      final compTrackPos = Offset(
        _beautyContestCenter.dx + cos(_speedContestCompProgress) * outerRx,
        _beautyContestCenter.dy + sin(_speedContestCompProgress) * outerRy,
      );
      final oppTrackPos = Offset(
        _beautyContestCenter.dx + cos(_speedContestOppProgress) * innerRx,
        _beautyContestCenter.dy + sin(_speedContestOppProgress) * innerRy,
      );

      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;

      comp.position = Offset.lerp(compTrackPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppTrackPos, oppTarget, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.16 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.16 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateStrengthContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    const baseHalf = 132.0;
    const baseY = 24.0;
    const laneHalfExtent = 118.0;

    if (_beautyContestTimer < _strengthContestDuration) {
      final forceDelta = (_strengthContestCompForce - _strengthContestOppForce);
      _strengthContestShift -= forceDelta * dt * 11.0;
      _strengthContestShift = _strengthContestShift.clamp(
        -laneHalfExtent,
        laneHalfExtent,
      );

      final compThump = sin(_beautyContestTimer * 9.2) * 6.0;
      final oppThump = sin(_beautyContestTimer * 9.2 + 1.1) * 6.0;
      final clashY = _beautyContestCenter.dy + baseY;

      comp.position = Offset(
        _beautyContestCenter.dx - baseHalf,
        clashY + compThump,
      );
      opp.position = Offset(
        _beautyContestCenter.dx + baseHalf,
        clashY + oppThump,
      );

      comp.angle = 0;
      opp.angle = pi;

      if ((_beautyContestTimer * 4.0).floor() !=
          ((_beautyContestTimer - dt) * 4.0).floor()) {
        final centerPulse = Offset(
          _beautyContestCenter.dx + _strengthContestShift,
          _beautyContestCenter.dy + baseY,
        );
        _spawnHitSpark(centerPulse, const Color(0xFFFFB74D));
      }
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _strengthContestDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );
      final compClashPos = Offset(
        _beautyContestCenter.dx - baseHalf,
        _beautyContestCenter.dy + baseY,
      );
      final oppClashPos = Offset(
        _beautyContestCenter.dx + baseHalf,
        _beautyContestCenter.dy + baseY,
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      comp.position = Offset.lerp(compClashPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppClashPos, oppTarget, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.20 - 1.0) * finalT
          : 1.0 + (0.62 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.62 - 1.0) * finalT
          : 1.0 + (1.20 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  void _updateIntelligenceContestCinematic(
    double dt,
    CosmicCompanion comp,
    CosmicCompanion opp,
  ) {
    ship.pos = _beautyContestCenter;
    _revealAround(ship.pos, 220);

    _beautyContestCompVisualScale = 1.0;
    _beautyContestOppVisualScale = 1.0;

    const baseHalf = 146.0;
    const baseY = 16.0;
    const orbitRx = 34.0;
    const orbitRy = 19.0;

    _intelligenceContestOrbit += dt * 1.55;

    _intelligenceContestBias = _intelligenceContestBias.clamp(-1.0, 1.0);
    var orbPos = Offset(
      _beautyContestCenter.dx +
          _intelligenceContestBias * 82.0 +
          cos(_intelligenceContestOrbit * 1.8) * 34.0,
      _beautyContestCenter.dy +
          baseY +
          sin(_intelligenceContestOrbit * 2.2 + 0.9) * 22.0,
    );

    if (_beautyContestTimer < _intelligenceContestDuration) {
      final focusDelta =
          (_intelligenceContestCompFocus - _intelligenceContestOppFocus);
      _intelligenceContestBias -= focusDelta * dt * 0.85;
      _intelligenceContestBias = _intelligenceContestBias.clamp(-1.0, 1.0);

      final compThrum = sin(_beautyContestTimer * 5.4) * 3.4;
      final oppThrum = sin(_beautyContestTimer * 5.4 + 1.4) * 3.4;

      comp.position = Offset(
        _beautyContestCenter.dx -
            baseHalf +
            cos(_intelligenceContestOrbit + pi) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit + pi) * orbitRy +
            compThrum,
      );
      opp.position = Offset(
        _beautyContestCenter.dx +
            baseHalf +
            cos(_intelligenceContestOrbit) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit) * orbitRy +
            oppThrum,
      );

      orbPos = Offset(
        _beautyContestCenter.dx +
            _intelligenceContestBias * 82.0 +
            cos(_intelligenceContestOrbit * 1.8) * 34.0,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit * 2.2 + 0.9) * 22.0,
      );
      comp.angle = atan2(
        orbPos.dy - comp.position.dy,
        orbPos.dx - comp.position.dx,
      );
      opp.angle = atan2(
        orbPos.dy - opp.position.dy,
        orbPos.dx - opp.position.dx,
      );

      if ((_beautyContestTimer * 3.2).floor() !=
          ((_beautyContestTimer - dt) * 3.2).floor()) {
        _spawnHitSpark(orbPos, const Color(0xFFD1C4E9));
      }
      if ((_beautyContestTimer * 1.4).floor() !=
          ((_beautyContestTimer - dt) * 1.4).floor()) {
        vfxRings.add(
          VfxShockRing(
            x: orbPos.dx,
            y: orbPos.dy,
            maxRadius: 62,
            color: const Color(0xFFB39DDB),
            expandSpeed: 160,
          ),
        );
      }
    } else {
      final finalT = Curves.easeOutCubic.transform(
        ((_beautyContestTimer - _intelligenceContestDuration) / 1.0).clamp(
          0.0,
          1.0,
        ),
      );

      final compMindPos = Offset(
        _beautyContestCenter.dx -
            baseHalf +
            cos(_intelligenceContestOrbit + pi) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit + pi) * orbitRy,
      );
      final oppMindPos = Offset(
        _beautyContestCenter.dx +
            baseHalf +
            cos(_intelligenceContestOrbit) * orbitRx,
        _beautyContestCenter.dy +
            baseY +
            sin(_intelligenceContestOrbit) * orbitRy,
      );
      final winnerPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy - 124,
      );
      final loserPos = Offset(
        _beautyContestCenter.dx,
        _beautyContestCenter.dy + 154,
      );
      final playerTarget = _beautyContestPlayerWon ? winnerPos : loserPos;
      final oppTarget = _beautyContestPlayerWon ? loserPos : winnerPos;
      comp.position = Offset.lerp(compMindPos, playerTarget, finalT)!;
      opp.position = Offset.lerp(oppMindPos, oppTarget, finalT)!;

      final winner = _beautyContestPlayerWon ? comp : opp;
      orbPos = Offset.lerp(orbPos, winner.position, finalT)!;

      _beautyContestCompVisualScale = _beautyContestPlayerWon
          ? 1.0 + (1.18 - 1.0) * finalT
          : 1.0 + (0.64 - 1.0) * finalT;
      _beautyContestOppVisualScale = _beautyContestPlayerWon
          ? 1.0 + (0.64 - 1.0) * finalT
          : 1.0 + (1.18 - 1.0) * finalT;
      comp.angle = -pi / 2;
      opp.angle = -pi / 2;
    }

    _intelligenceContestOrbPos = orbPos;

    comp.anchorPosition = comp.position;
    opp.anchorPosition = opp.position;

    for (var i = vfxParticles.length - 1; i >= 0; i--) {
      vfxParticles[i].update(dt);
      if (vfxParticles[i].life <= 0) vfxParticles.removeAt(i);
    }
    for (var i = vfxRings.length - 1; i >= 0; i--) {
      vfxRings[i].update(dt);
      if (vfxRings[i].dead) vfxRings.removeAt(i);
    }
  }

  // ── Garrison (home-based alchemons) ──

  /// Spawn garrison creatures around the home planet (up to beacon ring).
  void spawnGarrison(List<CosmicPartyMember> members) {
    _garrison.clear();
    if (homePlanet == null || members.isEmpty) return;
    final hp = homePlanet!;
    final rng = _rng;

    for (var i = 0; i < members.length; i++) {
      final m = members[i];
      final slotIndex = m.slotIndex.clamp(0, kHomeGarrisonMaxSlots - 1);
      final layerIndex = homeGarrisonLayerForSlot(slotIndex);
      final angle =
          homeGarrisonOrbitAngleForSlot(slotIndex) + rng.nextDouble() * 0.12;
      final dist = homeGarrisonOrbitRadiusForSlot(
        homePlanet: hp,
        slotIndex: slotIndex,
      );
      final pos = Offset(
        hp.position.dx + cos(angle) * dist,
        hp.position.dy + sin(angle) * dist,
      );
      final family = m.family.toLowerCase();
      final specScale =
          (CosmicGame._companionSpeciesScale[family] ?? 1.0) * 1.0;
      // Derive combat stats from member
      final atkDmg = 3.0 + m.statStrength * 0.3 + m.level * 0.5;
      final specialDmg = 3.0 + m.statIntelligence * 0.35 + m.level * 0.45;
      final baseRange =
          CosmicBalance.companionBaseRange(m.statIntelligence) +
          m.statSpeed * 12.0;
      final range = _familyAttackRange(family, baseRange);
      final specialRange = _familySpecialRange(family, baseRange);
      final garrisonHp = (80 + m.statStrength * 3 + m.level * 5).round();
      _garrison.add(
        _GarrisonCreature(
          member: m,
          position: pos,
          wanderAngle: angle + pi / 2,
          guardAngle: angle,
          guardRadius: dist,
          guardPhase: rng.nextDouble() * pi * 2 + layerIndex * 0.8,
          speciesScale: specScale,
          attackDamage: atkDmg,
          specialDamage: specialDmg,
          attackRange: range,
          specialRange: specialRange,
          maxHp: garrisonHp,
        ),
      );
      // Load sprite
      _loadGarrisonSprite(i, m);
    }
  }

  Future<void> _loadGarrisonSprite(int index, CosmicPartyMember m) async {
    final sheet = m.spriteSheet;
    if (sheet == null) return;
    try {
      final image = await images.load(sheet.path);
      final cols = (sheet.totalFrames + sheet.rows - 1) ~/ sheet.rows;
      final anim = SpriteAnimation.fromFrameData(
        image,
        SpriteAnimationData.sequenced(
          amount: sheet.totalFrames,
          amountPerRow: cols,
          textureSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          loop: true,
        ),
      );
      if (index < _garrison.length) {
        final g = _garrison[index];
        g.anim = anim;
        g.ticker = anim.createTicker();
        g.visuals = m.spriteVisuals;
        debugPrint(
          'Garrison sprite visuals[$index]: alchemy=${g.visuals?.alchemyEffect} variant=${g.visuals?.variantFaction} tint=${g.visuals?.tint}',
        );
        final desiredSize = 40.0;
        final sx = desiredSize / sheet.frameSize.x;
        final sy = desiredSize / sheet.frameSize.y;
        g.spriteScale =
            min(sx, sy) * (g.visuals?.scale ?? 1.0) * g.speciesScale;
      }
    } catch (e) {
      debugPrint('Failed to load garrison sprite: ${sheet.path} - $e');
    }
  }

  /// Wrap a position into the world bounds (toroidal).
  Offset _wrap(Offset p) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    return Offset(((p.dx % w) + w) % w, ((p.dy % h) + h) % h);
  }

  /// Interpolate across toroidal bounds using shortest wrapped delta.
  Offset _toroidalLerp(Offset from, Offset to, double t) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    var dx = to.dx - from.dx;
    var dy = to.dy - from.dy;
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    if (dy > h / 2) dy -= h;
    if (dy < -h / 2) dy += h;
    return _wrap(Offset(from.dx + dx * t, from.dy + dy * t));
  }

  /// Returns a camera-local toroidal equivalent of [worldPos] that is nearest
  /// to the current viewport center. Useful for rendering near world edges.
  Offset _wrappedRenderPos(
    Offset worldPos,
    double camX,
    double camY,
    double screenW,
    double screenH,
  ) {
    final w = world_.worldSize.width;
    final h = world_.worldSize.height;
    final centerX = camX + screenW * 0.5;
    final centerY = camY + screenH * 0.5;

    var dx = worldPos.dx - centerX;
    var dy = worldPos.dy - centerY;
    if (dx > w / 2) dx -= w;
    if (dx < -w / 2) dx += w;
    if (dy > h / 2) dy -= h;
    if (dy < -h / 2) dy += h;
    return Offset(centerX + dx, centerY + dy);
  }
}
