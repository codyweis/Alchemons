part of 'cosmic_game.dart';

/// Horn family gets bonus HP and DEF since they're the tanks.
double _familyHpMultiplier(String family) =>
    CosmicBalance.familyHpMultiplier(family);
double _familyDefMultiplier(String family) =>
    CosmicBalance.familyDefMultiplier(family);

extension CosmicGameCompanionsAndContests on CosmicGame {
  void summonCompanion(
    CosmicPartyMember member, {
    required int slotIndex,
    double hpFraction = 1.0,
    double? initialSpecialCooldown,
  }) {
    // Already active in this slot? Recall it instead of stacking.
    if (activeCompanions.containsKey(slotIndex)) {
      returnCompanion(slotIndex);
      return;
    }

    // At capacity? Refuse — the UI is expected to prevent summoning past
    // maxActiveCompanions (mirrors cosmic survival's behavior).
    if (activeCompanions.length >= CosmicGame.maxActiveCompanions) {
      return;
    }

    // Build compact companion stats for cosmic mode, where enemies have no DEF
    // and every point of physAtk is raw damage.
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
    final abilityAtk = CosmicBalance.companionElemAtk(
      level: level,
      beauty: cosmicFamilyAbilityRating(
        family: family,
        strength: strength,
        intelligence: intel,
        beauty: beauty,
      ),
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
      abilityAtk: abilityAtk,
      physDef: physDef,
      elemDef: elemDef,
      cooldownReduction: cooldownReduction,
      critChance: critChance,
      attackRange: _familyAttackRange(family, baseRange),
      specialAbilityRange: _familySpecialRange(family, baseRange),
      speciesScale: specScale,
    );
    companion.primeSpecialCooldown(
      savedCooldown: initialSpecialCooldown,
      // A Kin's special waits longer, as survival stretches it.
      cooldownMultiplier: family == 'kin' ? kKinSpecialCooldownStretch : 1.0,
    );
    // Its tear opens at its own place in the formation, not on the ship.
    if (!sandboxMode) {
      companion.position = _companionSummonPoint(companion);
      companion.anchorPosition = companion.position;
    }
    activeCompanions[slotIndex] = companion;
    // Whatever stood in this slot before is not what gathers now.
    _companionGrains.remove(slotIndex);

    // Attach a demo effect instance based on loaded prototypes (one per companion).
    try {
      if (_loadedEffectPrototypes.isNotEmpty) {
        final proto =
            _loadedEffectPrototypes[member.level %
                _loadedEffectPrototypes.length];
        final inst = EffectRegistry.create(proto.toJson());
        activeCompanions[slotIndex]?.addEffect(inst);
      }
    } catch (_) {}

    // Load animated sprite for the companion
    _loadCompanionSprite(member, slotIndex);
  }

  Future<void> _loadCompanionSprite(
    CosmicPartyMember member,
    int slotIndex,
  ) async {
    final sheet = sheetForVisuals(member.spriteSheet, member.spriteVisuals);
    if (sheet == null) {
      _companionTickers.remove(slotIndex);
      _companionVisualsBySlot.remove(slotIndex);
      return;
    }

    try {
      final image = await loadCreatureSheet(images, sheet.path);
      final current = activeCompanions[slotIndex];
      if (current == null || current.member.instanceId != member.instanceId) {
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
      _companionTickers[slotIndex] = anim.createTicker();
      _companionVisualsBySlot[slotIndex] = member.spriteVisuals;
      final visuals = _companionVisualsBySlot[slotIndex];
      debugPrint(
        'Companion visuals loaded: alchemy=${visuals?.alchemyEffect} variant=${visuals?.variantFaction} tint=${visuals?.tint}',
      );
      // Fit sprite into ~48px box, then apply species + 30% scale (sized up
      // another 30%, then another 20% again per design request).
      const desiredSize = CosmicGame.spriteBox;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = activeCompanions[slotIndex]?.speciesScale ?? 1.3;
      _companionSpriteScales[slotIndex] =
          min(sx, sy) * (visuals?.scale ?? 1.0) * specScale;
      _readCompanionGrains(
        slotIndex,
        member,
        anim.frames.first.sprite,
      ).ignore();
    } catch (e) {
      debugPrint('Failed to load companion sprite: ${sheet.path} - $e');
      _companionTickers.remove(slotIndex);
      _companionVisualsBySlot.remove(slotIndex);
      _companionSpriteScales.remove(slotIndex);
    }
  }

  /// Reads a companion — its first frame, coloured by its genetics, at the
  /// size it is drawn — into grains for its summoning and its recall. Small:
  /// a summoning lasts under a second and up to three can play at once.
  Future<void> _readCompanionGrains(
    int slotIndex,
    CosmicPartyMember member,
    Sprite sprite,
  ) async {
    final scale = _companionSpriteScales[slotIndex];
    if (scale == null) return;
    const ratio = 2.0;
    final w = (sprite.srcSize.x * scale * ratio).ceil();
    final h = (sprite.srcSize.y * scale * ratio).ceil();
    if (w <= 0 || h <= 0 || w > 1024 || h > 1024) return;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.translate(w / 2, h / 2);
    c.scale(scale * ratio);
    final paint = Paint()..filterQuality = ui.FilterQuality.high;
    final v = _companionVisualsBySlot[slotIndex];
    if (v != null) {
      final isAlbino = v.brightness == 1.45 && !v.isPrismatic;
      paint.colorFilter = isAlbino
          ? _albinoColorFilter(v.brightness)
          : _geneticsColorFilter(v);
    }
    sprite.render(c, anchor: Anchor.center, overridePaint: paint);
    final image = rec.endRecording().toImageSync(w, h);
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return;
      final grains = SpecimenGrains.fromRgba(
        data.buffer.asUint8List(),
        w,
        h,
        pixelRatio: ratio,
        maxGrains: 1100,
        tones: 12,
      );
      if (grains.length < 40) return;
      final current = activeCompanions[slotIndex];
      if (current == null || current.member.instanceId != member.instanceId) {
        return;
      }
      _companionGrains[slotIndex] = (
        member.instanceId,
        GrainAssembly(grains, accent: elementColor(member.element)),
      );
    } catch (_) {
      // It steps out of its tear instead.
    } finally {
      image.dispose();
    }
  }

  void returnCompanion([int? slotIndex]) {
    if (slotIndex != null) {
      final comp = activeCompanions[slotIndex];
      if (comp != null) {
        comp.returning = true;
        comp.returnTimer = 0.6; // fade out over 0.6s
      }
      return;
    }
    // No slot specified: recall every active companion (legacy behavior).
    for (final comp in activeCompanions.values) {
      comp.returning = true;
      comp.returnTimer = 0.6;
    }
  }

  /// Put an Alchemon on the field to fight the player's companion: a wild
  /// one that has been engaged, or a contest rival.
  void spawnDuelOpponent(CosmicPartyMember member) {
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
    final abilityAtk = CosmicBalance.companionElemAtk(
      level: level,
      beauty: cosmicFamilyAbilityRating(
        family: family,
        strength: strength,
        intelligence: intel,
        beauty: beauty,
      ),
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
    final placePos = member.spawnPosition ?? ship.pos;

    _resetDuelCombat();
    duelOpponent = CosmicCompanion(
      // It casts from its own slot, apart from the party's and the ship's,
      // so what it lays down is never mistaken for theirs.
      member: member.withSlot(kWildCasterSlot),
      position: placePos,
      anchor: placePos,
      maxHp: maxHp,
      currentHp: maxHp,
      physAtk: physAtk,
      elemAtk: elemAtk,
      abilityAtk: abilityAtk,
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
    duelOpponentProjectiles.clear();

    // Reset and preload static sprite fallback.
    _duelOpponentFallbackSprite = null;
    _duelOpponentFallbackScale = 1.0;
    _loadDuelOpponentFallbackSprite(member);

    // Load sprite
    _loadDuelOpponentSprite(member);
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

  Future<void> _loadDuelOpponentFallbackSprite(CosmicPartyMember member) async {
    final rawPath = member.imagePath;
    if (rawPath == null || rawPath.trim().isEmpty) return;
    final expectedInstanceId = member.instanceId;
    final token = ++_duelOpponentFallbackLoadToken;
    try {
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(rawPath));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(rawPath));
      }
      if (token != _duelOpponentFallbackLoadToken ||
          duelOpponent?.member.instanceId != expectedInstanceId) {
        return;
      }
      _duelOpponentFallbackSprite = Sprite(image);
      const desiredSize = CosmicGame.spriteBox;
      final sx = desiredSize / image.width;
      final sy = desiredSize / image.height;
      final specScale = duelOpponent?.speciesScale ?? 1.3;
      _duelOpponentFallbackScale =
          min(sx, sy) * (member.spriteVisuals?.scale ?? 1.0) * specScale;
    } catch (e) {
      debugPrint('Failed to load ring opponent fallback sprite: $rawPath - $e');
    }
  }

  Future<void> _loadDuelOpponentSprite(CosmicPartyMember member) async {
    final loadToken = ++_duelOpponentSpriteLoadToken;
    final expectedInstanceId = member.instanceId;
    final sheet = member.spriteSheet;
    final sheetPath = sheet?.path ?? '<no-sheet>';
    _duelOpponentSpriteLoadsInFlight++;
    try {
      if (sheet == null) {
        if (loadToken == _duelOpponentSpriteLoadToken &&
            duelOpponent?.member.instanceId == expectedInstanceId) {
          _duelOpponentTicker = null;
          _duelOpponentVisuals = null;
        }
        return;
      }
      ui.Image image;
      try {
        image = await images.load(_toFlameImageKey(sheet.path));
      } catch (_) {
        image = await _loadUiImageFromBundle(_toBundleImageKey(sheet.path));
      }
      if (loadToken != _duelOpponentSpriteLoadToken ||
          duelOpponent?.member.instanceId != expectedInstanceId) {
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
      _duelOpponentTicker = anim.createTicker();
      _duelOpponentVisuals = member.spriteVisuals;
      debugPrint(
        'Ring opponent visuals loaded: alchemy=${_duelOpponentVisuals?.alchemyEffect} variant=${_duelOpponentVisuals?.variantFaction} tint=${_duelOpponentVisuals?.tint}',
      );
      const desiredSize = CosmicGame.spriteBox;
      final sx = desiredSize / sheet.frameSize.x;
      final sy = desiredSize / sheet.frameSize.y;
      final specScale = duelOpponent?.speciesScale ?? 1.3;
      _duelOpponentSpriteScale =
          min(sx, sy) * (_duelOpponentVisuals?.scale ?? 1.0) * specScale;
      _duelOpponentSpriteRetryTimer = 0.0;
    } catch (e) {
      debugPrint('Failed to load ring opponent sprite: $sheetPath - $e');
      if (loadToken == _duelOpponentSpriteLoadToken &&
          duelOpponent?.member.instanceId == expectedInstanceId) {
        _duelOpponentTicker = null;
        _duelOpponentVisuals = null;
      }
    } finally {
      _duelOpponentSpriteLoadsInFlight = max(
        0,
        _duelOpponentSpriteLoadsInFlight - 1,
      );
    }
  }

  void dismissDuelOpponent() {
    duelOpponent = null;
    duelOpponentProjectiles.clear();
    _resetDuelCombat();
    _duelOpponentTicker = null;
    _duelOpponentVisuals = null;
    _duelOpponentFallbackSprite = null;
    _duelOpponentFallbackScale = 1.0;
    _duelOpponentFallbackLoadToken++;
    _duelOpponentSpriteLoadToken++;
    _duelOpponentSpriteRetryTimer = 0.0;
    _duelOpponentSpriteLoadsInFlight = 0;
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

    boosting = false;

    companionProjectiles.clear();
    duelOpponentProjectiles.clear();
    vfxParticles.clear();
    vfxRings.clear();

    // Spawn real opponent sprite/visuals in arena.
    spawnDuelOpponent(opponentMember);
    _duelOpponentSpriteRetryTimer = 1.1;

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

    if (duelOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      duelOpponent!.position = _beautyContestOppIntroStart;
      duelOpponent!.anchorPosition = duelOpponent!.position;
      // Beauty contest should show full sprites immediately (no summon scale-in).
      duelOpponent!.life = 1.0;
      duelOpponent!.returning = false;
      duelOpponent!.returnTimer = 0;
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

    boosting = false;

    companionProjectiles.clear();
    duelOpponentProjectiles.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnDuelOpponent(opponentMember);
    _duelOpponentSpriteRetryTimer = 1.1;

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

    if (duelOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      duelOpponent!.position = _beautyContestOppIntroStart;
      duelOpponent!.anchorPosition = duelOpponent!.position;
      duelOpponent!.life = 1.0;
      duelOpponent!.returning = false;
      duelOpponent!.returnTimer = 0;
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

    boosting = false;

    companionProjectiles.clear();
    duelOpponentProjectiles.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnDuelOpponent(opponentMember);
    _duelOpponentSpriteRetryTimer = 1.1;

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

    if (duelOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      duelOpponent!.position = _beautyContestOppIntroStart;
      duelOpponent!.anchorPosition = duelOpponent!.position;
      duelOpponent!.life = 1.0;
      duelOpponent!.returning = false;
      duelOpponent!.returnTimer = 0;
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

    boosting = false;

    companionProjectiles.clear();
    duelOpponentProjectiles.clear();
    vfxParticles.clear();
    vfxRings.clear();

    spawnDuelOpponent(opponentMember);
    _duelOpponentSpriteRetryTimer = 1.1;

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

    if (duelOpponent != null) {
      _beautyContestOppIntroStart = _wrap(
        Offset(
          oppIntroTarget.dx + introOppOffset.dx,
          oppIntroTarget.dy + introOppOffset.dy,
        ),
      );
      duelOpponent!.position = _beautyContestOppIntroStart;
      duelOpponent!.anchorPosition = duelOpponent!.position;
      duelOpponent!.life = 1.0;
      duelOpponent!.returning = false;
      duelOpponent!.returnTimer = 0;
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
    duelOpponentProjectiles.clear();
    dismissDuelOpponent();
  }

  void _updateBeautyContestCinematic(double dt) {
    final comp = activeCompanion;
    final opp = duelOpponent;
    if (comp == null || opp == null || !opp.isAlive) {
      endBeautyContestCinematic();
      return;
    }

    _beautyContestTimer += dt;
    _riftPulse += dt;
    _beautyContestCompHopTimer = max(0.0, _beautyContestCompHopTimer - dt);
    _beautyContestOppHopTimer = max(0.0, _beautyContestOppHopTimer - dt);
    _duelOpponentSpriteRetryTimer = max(
      0.0,
      _duelOpponentSpriteRetryTimer - dt,
    );
    final primarySlot = _primaryCompanionSlot;
    if (primarySlot != null) _companionTickers[primarySlot]?.update(dt);
    _duelOpponentTicker?.update(dt);

    // Retry opponent sprite load in-case an async load raced or failed.
    if (_duelOpponentTicker == null &&
        opp.member.spriteSheet != null &&
        _duelOpponentSpriteLoadsInFlight == 0 &&
        _duelOpponentSpriteRetryTimer <= 0) {
      _duelOpponentSpriteRetryTimer = 1.1;
      _loadDuelOpponentSprite(opp.member);
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
      duelOpponentProjectiles.addAll(result.projectiles);
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
      duelOpponentProjectiles.addAll(result.projectiles);
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
    updateContestProjectiles(duelOpponentProjectiles);

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
      final specialDmg =
          3.0 +
          cosmicFamilyAbilityRating(
                family: family,
                strength: m.statStrength,
                intelligence: m.statIntelligence,
                beauty: m.statBeauty,
              ) *
              0.35 +
          m.level * 0.45;
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
    final sheet = sheetForVisuals(m.spriteSheet, m.spriteVisuals);
    if (sheet == null) return;
    try {
      final image = await loadCreatureSheet(images, sheet.path);
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
        const desiredSize = CosmicGame.spriteBox;
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
