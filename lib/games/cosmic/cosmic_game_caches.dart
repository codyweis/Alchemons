part of 'cosmic_game.dart';

/// Sealed elemental caches: proximity, the three-second unsealing ritual, and
/// the per-element artwork that plays while the seal gives way.
extension CosmicGameElementalCaches on CosmicGame {
  // ── update ─────────────────────────────────────────────

  void _updateElementalCaches(double dt) {
    final field = elementalCacheField;

    // The pocket dimension and the ring arena run on borrowed coordinates —
    // proximity out in the open cosmos means nothing while the ship is there.
    if (inNexusPocket || wildDuelActive) {
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

    // The companion circles the seal, feeding it: it sweeps in from where
    // it was and makes one eased turn round the cache. The element drawing
    // in to the seam is part of the cache's own painting.
    final comp = _attuningCompanionForCache(cache);
    if (comp != null && comp.isAlive) {
      final orbitAngle =
          cache.orbitFrom + Curves.easeInOutSine.transform(t) * 2 * pi;
      final settle = Curves.easeOutCubic.transform((t / 0.3).clamp(0.0, 1.0));
      final orbitRadius =
          cache.orbitRadiusFrom + (110 - cache.orbitRadiusFrom) * settle;
      comp.position = Offset(
        cache.position.dx + cos(orbitAngle) * orbitRadius,
        cache.position.dy + sin(orbitAngle) * orbitRadius,
      );
      comp.angle = orbitAngle + pi / 2;
      comp.anchorPosition = comp.position;
      comp.invincibleTimer = 0.5;
    }

    if (cache.openTimer >= ElementalCache.openDuration) {
      _finishCacheUnseal(cache);
    }
  }

  void _finishCacheUnseal(ElementalCache cache) {
    openingCache = null;
    cache.openTimer = -1;
    // Daily pickup: the cache is gone until the calendar day rolls over. The
    // old play-time countdown froze whenever the app was closed.
    cache.openedAtMs = DateTime.now().millisecondsSinceEpoch;
    cache.respawnTimer = 0;
    // No burst here: the unsealing has already flowed out and thinned to
    // nothing by its last frame.

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
    return _attuningCompanionForCache(cache) != null;
  }

  CosmicCompanion? _attuningCompanionForCache(ElementalCache cache) {
    CosmicCompanion? nearest;
    var nearestDistance = double.infinity;
    for (final comp in _livingActiveCompanions) {
      if (comp.member.element.toLowerCase() != cache.element.toLowerCase()) {
        continue;
      }
      final distance = _toroidalDistance(comp.position, cache.position);
      if (distance < ElementalCache.attuneRadius &&
          distance < nearestDistance) {
        nearest = comp;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  /// Begin the unsealing ritual. Returns false if the seal will not take.
  bool beginCacheUnseal(ElementalCache cache) {
    if (openingCache != null) return false;
    if (!cache.isPresent || cache.isOpening) return false;
    final comp = _attuningCompanionForCache(cache);
    if (comp == null) return false;
    cache.openTimer = 0;
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var dx = comp.position.dx - cache.position.dx;
    var dy = comp.position.dy - cache.position.dy;
    if (dx > ww / 2) dx -= ww;
    if (dx < -ww / 2) dx += ww;
    if (dy > wh / 2) dy -= wh;
    if (dy < -wh / 2) dy += wh;
    cache.orbitFrom = atan2(dy, dx);
    cache.orbitRadiusFrom = sqrt(dx * dx + dy * dy).clamp(40.0, 460.0);
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

      final p = _wrappedRenderPos(cache.position, camX, camY, screenW, screenH);
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

    final title = _worldLabel(
      '${cache.element.toUpperCase()} CACHE',
      color: c.withValues(alpha: 0.85),
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    title.paint(
      canvas,
      Offset(p.dx - title.width / 2, p.dy + ElementalCache.visualRadius + 12),
    );

    final hint = _worldLabel(
      'needs ${cacheHintFor(cache.element)}',
      color: Colors.white.withValues(alpha: 0.55),
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
    hint.paint(
      canvas,
      Offset(p.dx - hint.width / 2, p.dy + ElementalCache.visualRadius + 27),
    );
  }
}
