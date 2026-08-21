part of 'cosmic_game.dart';

/// Sealed elemental caches: proximity, the three-second unsealing ritual, and
/// the per-element artwork that plays while the seal gives way.
extension CosmicGameElementalCaches on CosmicGame {
  // ── update ─────────────────────────────────────────────

  void _updateElementalCaches(double dt) {
    final field = elementalCacheField;

    // The pocket dimension and the ring arena run on borrowed coordinates —
    // proximity out in the open cosmos means nothing while the ship is there.
    if (inNexusPocket || battleRing.inBattle) {
      if (_nearestCache != null) {
        _nearestCache = null;
        onNearCache?.call(null);
      }
      return;
    }

    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;

    ElementalCache? closest;
    double closestDist = double.infinity;

    for (final cache in field.caches) {
      cache.life += dt;

      // A cracked cache stays gone until the next day. Checking the clock is
      // cheap and, unlike the old countdown, it keeps running while the app
      // is closed.
      if (cache.openedAtMs > 0) {
        if (!cache.isPresent) continue;
        cache.openedAtMs = 0;
        cache.respawnTimer = 0;
        field.relocate(cache, _rng, world_.planets);
        onCacheRespawned?.call(cache);
        continue;
      }

      var dx = cache.position.dx - ship.pos.dx;
      var dy = cache.position.dy - ship.pos.dy;
      if (dx > ww / 2) dx -= ww;
      if (dx < -ww / 2) dx += ww;
      if (dy > wh / 2) dy -= wh;
      if (dy < -wh / 2) dy += wh;
      final dist = sqrt(dx * dx + dy * dy);

      // Pinned to the full map for good once the ship has been right on it.
      if (!cache.discovered && dist < ElementalCache.discoverRadius) {
        cache.discovered = true;
        onCacheDiscovered?.call(cache);
      }

      final threshold = identical(cache, _nearestCache)
          ? ElementalCache.exitRadius
          : ElementalCache.interactRadius;
      if (dist < threshold && dist < closestDist) {
        closestDist = dist;
        closest = cache;
      }
    }

    if (!identical(closest, _nearestCache)) {
      _nearestCache = closest;
      onNearCache?.call(closest);
    }

    _advanceCacheUnseal(dt);
  }

  /// Drive the active unsealing ritual: the companion channels, the element
  /// bleeds into the seal, and at three seconds the cache gives.
  void _advanceCacheUnseal(double dt) {
    final cache = openingCache;
    if (cache == null) return;

    cache.openTimer += dt;
    final t = (cache.openTimer / ElementalCache.openDuration).clamp(0.0, 1.0);
    final color = cache.color;

    // The companion circles the seal, feeding it.
    final comp = activeCompanion;
    if (comp != null && comp.isAlive) {
      final orbitAngle = t * pi * 4;
      const orbitRadius = 110.0;
      comp.position = Offset(
        cache.position.dx + cos(orbitAngle) * orbitRadius,
        cache.position.dy + sin(orbitAngle) * orbitRadius,
      );
      comp.angle = orbitAngle + pi / 2;
      comp.anchorPosition = comp.position;
      comp.invincibleTimer = 0.5;
    }

    // Element streaming inward from the companion's ring toward the seal.
    if (_rng.nextDouble() < 0.75) {
      final a = _rng.nextDouble() * pi * 2;
      final r = 120 + _rng.nextDouble() * 60;
      final sx = cache.position.dx + cos(a) * r;
      final sy = cache.position.dy + sin(a) * r;
      vfxParticles.add(
        VfxParticle(
          x: sx,
          y: sy,
          vx: (cache.position.dx - sx) * 1.6,
          vy: (cache.position.dy - sy) * 1.6,
          life: 0.6,
          color: color,
          size: 2 + _rng.nextDouble() * 3,
        ),
      );
    }

    if (cache.openTimer >= ElementalCache.openDuration) {
      _finishCacheUnseal(cache);
    }
  }

  void _finishCacheUnseal(ElementalCache cache) {
    final color = cache.color;
    openingCache = null;
    cache.openTimer = -1;
    // Daily pickup: the cache is gone until the calendar day rolls over. The
    // old play-time countdown froze whenever the app was closed.
    cache.openedAtMs = DateTime.now().millisecondsSinceEpoch;
    cache.respawnTimer = 0;

    for (var i = 0; i < 34; i++) {
      final a = _rng.nextDouble() * pi * 2;
      final s = 80 + _rng.nextDouble() * 190;
      vfxParticles.add(
        VfxParticle(
          x: cache.position.dx,
          y: cache.position.dy,
          vx: cos(a) * s,
          vy: sin(a) * s,
          life: 1.3,
          color: i.isEven ? color : const Color(0xFFFFD700),
          size: 3 + _rng.nextDouble() * 5,
        ),
      );
    }
    vfxRings.add(
      VfxShockRing(
        x: cache.position.dx,
        y: cache.position.dy,
        maxRadius: 260,
        color: color,
      ),
    );
    vfxRings.add(
      VfxShockRing(
        x: cache.position.dx,
        y: cache.position.dy,
        maxRadius: 170,
        color: const Color(0xFFFFECB3),
        expandSpeed: 300,
      ),
    );

    if (identical(_nearestCache, cache)) {
      _nearestCache = null;
      onNearCache?.call(null);
    }
    onCacheOpened?.call(cache);
  }

  // ── interaction API (called by the screen) ─────────────

  /// The cache the ship is currently parked at, if any.
  ElementalCache? get nearestCache => _nearestCache;

  /// True when a companion of the cache's element is deployed close enough to
  /// break the seal — i.e. the "ATTUNE" button should be live.
  bool cacheAttunementReady(ElementalCache cache) {
    final comp = activeCompanion;
    if (comp == null || !comp.isAlive || comp.returning) return false;
    if (comp.member.element.toLowerCase() != cache.element.toLowerCase()) {
      return false;
    }
    return _toroidalDistance(comp.position, cache.position) <
        ElementalCache.attuneRadius;
  }

  /// Begin the unsealing ritual. Returns false if the seal will not take.
  bool beginCacheUnseal(ElementalCache cache) {
    if (openingCache != null) return false;
    if (!cache.isPresent || cache.isOpening) return false;
    if (!cacheAttunementReady(cache)) return false;
    cache.openTimer = 0;
    openingCache = cache;
    return true;
  }

  double _toroidalDistance(Offset a, Offset b) {
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var dx = a.dx - b.dx;
    var dy = a.dy - b.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    return sqrt(dx * dx + dy * dy);
  }

  // ── render ─────────────────────────────────────────────

  void _renderElementalCaches(
    Canvas canvas,
    double camX,
    double camY,
    double screenW,
    double screenH,
  ) {
    for (final cache in elementalCacheField.caches) {
      if (!cache.isPresent) continue;

      final p = _wrappedRenderPos(
        cache.position,
        camX,
        camY,
        screenW,
        screenH,
      );
      // Cull anything comfortably off-screen.
      if ((p.dx - camX - screenW / 2).abs() > screenW * 0.9 ||
          (p.dy - camY - screenH / 2).abs() > screenH * 0.9) {
        continue;
      }

      if (cache.isOpening) {
        final t = (cache.openTimer / ElementalCache.openDuration).clamp(
          0.0,
          1.0,
        );
        paintCacheUnseal(canvas, p, cache.element, cache.life, t);
      } else {
        paintSealedCache(canvas, p, cache.element, cache.life);
        _renderCacheLabel(canvas, p, cache);
      }
    }
  }

  /// Name + riddle, drawn only for a cache the ship is actually near so the
  /// text layout cost stays at zero or one per frame.
  void _renderCacheLabel(Canvas canvas, Offset p, ElementalCache cache) {
    if (!identical(cache, _nearestCache)) return;
    final c = cache.color;

    final title = TextPainter(
      text: TextSpan(
        text: '${cache.element.toUpperCase()} CACHE',
        style: TextStyle(
          color: c.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    title.paint(
      canvas,
      Offset(p.dx - title.width / 2, p.dy + ElementalCache.visualRadius + 12),
    );

    final hint = TextPainter(
      text: TextSpan(
        text: 'needs ${cacheHintFor(cache.element)}',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 9,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hint.paint(
      canvas,
      Offset(p.dx - hint.width / 2, p.dy + ElementalCache.visualRadius + 27),
    );
  }
}
