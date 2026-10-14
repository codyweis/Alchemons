part of 'cosmic_game.dart';

extension CosmicGameCompanions on CosmicGame {
  void summonCompanion(
    CosmicPartyMember member, {
    required int slotIndex,
    double hpFraction = 1.0,
    double? initialSpecialCooldown,
  }) {
    // Still fading out of this slot or holding a deployment slot on its
    // way out? It is gone already as far as the party is concerned.
    if (activeCompanions[slotIndex]?.returning == true ||
        activeCompanions.length >= CosmicGame.maxActiveCompanions) {
      _dropLeavingCompanions();
    }

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

    // The shared power model: the same numbers Survival, the dungeons and
    // the Battle tab use. Space's world is tuned to them
    // (CosmicBalance.spaceWorldScale).
    final stats = deriveAlchemonCombatStats(member: member);
    final family = member.family.toLowerCase();
    final maxHp = stats.maxHp;

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
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      abilityAtk: stats.abilityAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      specialCooldownReduction: stats.specialCooldownReduction,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
      speciesScale: specScale,
    );
    if (!castsSpecialOutsideSurvival(member.family)) {
      // A Mystic's world is a Survival ability; in open space it fights with
      // its auto attack alone, so there is no cooldown to show.
      companion.specialCooldown = 0;
    } else {
      companion.primeSpecialCooldown(savedCooldown: initialSpecialCooldown);
    }
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

  /// Reads a companion — its first frame, colored by its genetics, at the
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
      paint.colorFilter = _creatureFilter(v);
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
  /// one that has been engaged.
  void spawnDuelOpponent(CosmicPartyMember member) {
    final stats = deriveAlchemonCombatStats(member: member);
    final family = member.family.toLowerCase();
    final maxHp = stats.maxHp;

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
      physAtk: stats.physAtk,
      elemAtk: stats.elemAtk,
      abilityAtk: stats.abilityAtk,
      physDef: stats.physDef,
      elemDef: stats.elemDef,
      cooldownReduction: stats.cooldownReduction,
      specialCooldownReduction: stats.specialCooldownReduction,
      attackRange: stats.attackRange,
      specialAbilityRange: stats.specialAbilityRange,
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
    // Its own sheet, or the baked copy an albino (or a mutated one) wears.
    final sheet = sheetForVisuals(member.spriteSheet, member.spriteVisuals);
    final sheetPath = sheet?.path ?? '<no-sheet>';
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
      if (isMutatedSheetPath(sheet.path)) {
        image = await loadCreatureSheet(images, sheet.path);
      } else {
        try {
          image = await images.load(_toFlameImageKey(sheet.path));
        } catch (_) {
          image = await _loadUiImageFromBundle(_toBundleImageKey(sheet.path));
        }
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
    } catch (e) {
      debugPrint('Failed to load ring opponent sprite: $sheetPath - $e');
      if (loadToken == _duelOpponentSpriteLoadToken &&
          duelOpponent?.member.instanceId == expectedInstanceId) {
        _duelOpponentTicker = null;
        _duelOpponentVisuals = null;
      }
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
  }

  /// Companions still fading out go now, for [summonCompanion]: a fading
  /// companion should not hold a deployment slot against the one being
  /// called in.
  void _dropLeavingCompanions() {
    final leaving = [
      for (final e in activeCompanions.entries)
        if (e.value.returning) e.key,
    ];
    for (final slot in leaving) {
      activeCompanions.remove(slot);
      _companionTickers.remove(slot);
      _companionVisualsBySlot.remove(slot);
      _companionSpriteScales.remove(slot);
      _companionGrains.remove(slot);
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
      _garrison.add(
        _GarrisonCreature(
          member: m,
          position: pos,
          wanderAngle: angle + pi / 2,
          guardAngle: angle,
          guardRadius: dist,
          guardPhase: rng.nextDouble() * pi * 2 + layerIndex * 0.8,
          speciesScale: specScale,
          stats: deriveAlchemonCombatStats(member: m),
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
