part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Performance constants
//  • All glow is done with radial gradients — zero MaskFilter.blur
//  • Slow/static effects are cached into a ui.Picture and replayed each frame
//  • Particle counts are kept low; sub-pixel blobs skip drawing entirely
// ─────────────────────────────────────────────────────────────────────────────

extension CosmicGameHomeAndVisuals on CosmicGame {
  // ── Orbital setup ──────────────────────────────────────────────────────────

  void _setupOrbitalRelationship(Offset homePos) {
    final partner = _nearestPlanetForOrbit(homePos);
    if (partner == null) {
      _orbitalPartner = null;
      return;
    }
    _orbitalPartner = partner;
    final homeVr = homePlanet!.visualRadius;
    if (homeVr >= partner.radius) {
      _homeOrbitsPartner = false;
      _orbitRadius = homeVr * 3.0 + partner.radius;
      _orbitSpeed = 0.02;
    } else {
      _homeOrbitsPartner = true;
      _orbitRadius = partner.particleFieldRadius + homeVr;
      _orbitSpeed = 0.015;
    }
    final ww = world_.worldSize.width;
    final wh = world_.worldSize.height;
    var pdx = homePos.dx - partner.position.dx;
    var pdy = homePos.dy - partner.position.dy;
    if (pdx > ww / 2) pdx -= ww;
    if (pdx < -ww / 2) pdx += ww;
    if (pdy > wh / 2) pdy -= wh;
    if (pdy < -wh / 2) pdy += wh;
    _orbitAngle = atan2(pdy, pdx);
  }

  // ── Home planet build / move / restore ────────────────────────────────────

  /// Build the home planet at the ship's current position.
  /// Returns null on success, or a warning string if placement is blocked.
  String? buildHomePlanet() {
    final pos = Offset(ship.pos.dx, ship.pos.dy);
    if (_planetBlockingPlacement(pos) != null)
      return 'Too close to another planet';
    homePlanet = HomePlanet(position: pos);
    _setupOrbitalRelationship(pos);
    _invalidateEffectsCache();
    onHomePlanetBuilt?.call(homePlanet!);
    return null;
  }

  /// Move the home planet to the ship's current position.
  /// Returns null on success, or a warning string if placement is blocked.
  String? moveHomePlanet() {
    if (homePlanet == null) return 'No home planet';
    final pos = Offset(ship.pos.dx, ship.pos.dy);
    if (_planetBlockingPlacement(pos) != null)
      return 'Too close to another planet';
    homePlanet!.position = pos;
    _setupOrbitalRelationship(pos);
    _invalidateEffectsCache();
    onHomePlanetBuilt?.call(homePlanet!);
    return null;
  }

  /// Restore a previously-saved home planet.
  void restoreHomePlanet(HomePlanet hp) {
    homePlanet = hp;
    _setupOrbitalRelationship(hp.position);
    _invalidateEffectsCache();
  }

  // ── Orbital chambers ──────────────────────────────────────────────────────

  /// Spawn orbital chambers around the home planet.
  /// Each entry is: (color, instanceId?, baseCreatureId?, displayName?, imagePath?)
  void spawnOrbitalChambers(
    List<(Color, String?, String?, String?, String?)> chamberData,
  ) {
    if (homePlanet == null) return;
    orbitalChambers.clear();
    final hp = homePlanet!.position;
    final vr = homePlanet!.visualRadius;
    final rng = Random();
    for (var i = 0; i < chamberData.length; i++) {
      final (color, instId, baseId, name, imgPath) = chamberData[i];
      final angle = (i / chamberData.length) * pi * 2 + rng.nextDouble() * 0.3;
      final orbitDist = vr + 120 + rng.nextDouble() * 40;
      final pos = Offset(
        hp.dx + cos(angle) * orbitDist,
        hp.dy + sin(angle) * orbitDist,
      );
      final tangent = Offset(-sin(angle), cos(angle));
      final orbitalSpeed = 15.0 + rng.nextDouble() * 10;
      orbitalChambers.add(
        OrbitalChamber(
          position: pos,
          velocity: tangent * orbitalSpeed,
          radius: 18 + rng.nextDouble() * 4,
          color: color,
          seed: rng.nextDouble() * pi * 2,
          instanceId: instId,
          baseCreatureId: baseId,
          displayName: name,
          imagePath: imgPath,
          orbitDistance: orbitDist,
        ),
      );
      if (imgPath != null && !_chamberSpriteCache.containsKey(imgPath)) {
        _loadChamberSprite(imgPath);
      }
    }
  }

  Future<void> _loadChamberSprite(String path) async {
    try {
      _chamberSpriteCache[path] = await images.load(path);
    } catch (_) {
      // Image not available — chamber renders without sprite.
    }
  }

  // ── Proximity check ───────────────────────────────────────────────────────

  bool get isNearHome {
    if (homePlanet == null) return false;
    final dx = homePlanet!.position.dx - ship.pos.dx;
    final dy = homePlanet!.position.dy - ship.pos.dy;
    final baseR = (homePlanet!.visualRadius + 80) * 2.0;
    final threshold = _wasNearHome ? baseR + 30 : baseR;
    return dx * dx + dy * dy < threshold * threshold;
  }

  // ── Ammo colour ───────────────────────────────────────────────────────────

  Color get _ammoColor => switch (activeAmmoId) {
    'storm_bolts' => const Color(0xFFFFEB3B),
    'plasma_bolts' => const Color(0xFFFFFFFF),
    'ice_shards' => const Color(0xFF00E5FF),
    'void_cannon' => const Color(0xFF9C27B0),
    _ => const Color(0xFF00E5FF),
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  STATIC-EFFECT PICTURE CACHE
  //  Effects that barely animate (dark_void, mud_fortress, frozen_shell) are
  //  rendered into a ui.Picture once and replayed every frame.  The cache is
  //  rebuilt only when active customizations or planet size change.
  // ══════════════════════════════════════════════════════════════════════════

  // Fields expected on the parent class (declare there):
  //   ui.Picture?  _staticEffectsPicture;
  //   Set<String>  _cachedCustomizations = {};
  //   double       _cachedVr = 0;
  //   Offset       _cachedPictureOffset = Offset.zero;
  //   static const Size _pictureSize = Size(512, 512);

  void _invalidateEffectsCache() {
    _staticEffectsPicture = null;
  }

  /// Rebuild the Picture cache for slow / static effects.
  void _rebuildStaticEffectsCache(Offset pos, double vr, Color col) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    // Translate so the planet centre is at (256, 256) inside the picture.
    c.translate(256, 256);
    _drawDarkVoid(c, Offset.zero, vr);
    _drawLavaMoat(c, Offset.zero, vr, 0);
    _drawMudFortress(c, Offset.zero, vr);
    _drawFrozenShell(c, Offset.zero, vr, 0);
    _staticEffectsPicture = recorder.endRecording();
    _cachedCustomizations = Set.of(activeCustomizations);
    _cachedVr = vr;
    _cachedPictureOffset = pos;
  }

  bool _staticCacheValid(double vr) =>
      _staticEffectsPicture != null &&
      _cachedVr == vr &&
      _cachedCustomizations.containsAll(activeCustomizations) &&
      activeCustomizations.containsAll(_cachedCustomizations);

  // ══════════════════════════════════════════════════════════════════════════
  //  BEHIND-PLANET EFFECTS  (drawn before the planet body)
  // ══════════════════════════════════════════════════════════════════════════

  void _renderHomeEffectsBehind(
    Canvas canvas,
    Offset pos,
    double vr,
    Color col,
  ) {
    final t = _elapsed;

    // Rebuild the static cache when needed.
    if (!_staticCacheValid(vr)) _rebuildStaticEffectsCache(pos, vr, col);

    // Replay the cached picture (translate so 256,256 lands on pos).
    canvas.save();
    canvas.translate(pos.dx - 256, pos.dy - 256);
    canvas.drawPicture(_staticEffectsPicture!);
    canvas.restore();

    // Lava Moat needs its animated alpha — redraw just the animated part.
    if (activeCustomizations.contains('lava_moat')) {
      _drawLavaMoat(canvas, pos, vr, t);
    }

    // Frozen Shell sparkles are animated — redraw on top of cached shell.
    if (activeCustomizations.contains('frozen_shell')) {
      _drawFrozenShellSparkles(canvas, pos, vr, t);
    }
  }

  // ── Static sub-draws (used by cache builder and animated overdraw) ────────

  void _drawDarkVoid(Canvas canvas, Offset pos, double vr) {
    if (!activeCustomizations.contains('dark_void')) return;
    final layers = switch (customizationOptions['dark_void.layers'] ??
        'Normal') {
      'Thin' => 2,
      'Deep' => 6,
      _ => 4,
    };
    for (var i = 0; i < layers; i++) {
      final r = vr * (2.0 + i * 0.5);
      _drawGlow(
        canvas,
        pos,
        r,
        const Color(0xFF4A148C),
        0.06 + i * 0.01,
        r * 0.8,
      );
    }
  }

  void _drawLavaMoat(Canvas canvas, Offset pos, double vr, double t) {
    if (!activeCustomizations.contains('lava_moat')) return;
    final moatWidth = switch (customizationOptions['lava_moat.width'] ??
        'Normal') {
      'Thin' => 3.0,
      'Wide' => 10.0,
      _ => 6.0,
    };
    final moatR = vr + 14;
    // Animated: alpha pulses.  When t==0 (cache pass) we draw the base alpha.
    final alpha = t > 0 ? 0.3 + 0.1 * sin(t * 1.2) : 0.3;
    _drawRingGlow(
      canvas,
      pos,
      moatR,
      moatWidth + 6,
      const Color(0xFFEF6C00),
      alpha * 0.5,
    );
    canvas.drawCircle(
      pos,
      moatR,
      Paint()
        ..color = const Color(0xFFFF5722).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = moatWidth,
    );
  }

  void _drawMudFortress(Canvas canvas, Offset pos, double vr) {
    if (!activeCustomizations.contains('mud_fortress')) return;
    final thick = switch (customizationOptions['mud_fortress.thickness'] ??
        'Normal') {
      'Thin' => 4.0,
      'Thick' => 14.0,
      _ => 8.0,
    };
    _drawRingGlow(
      canvas,
      pos,
      vr + 6,
      thick + 8,
      const Color(0xFF795548),
      0.25,
    );
    canvas.drawCircle(
      pos,
      vr + 6,
      Paint()
        ..color = const Color(0xFF5D4037).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick,
    );
  }

  void _drawFrozenShell(Canvas canvas, Offset pos, double vr, double t) {
    if (!activeCustomizations.contains('frozen_shell')) return;
    final thick = switch (customizationOptions['frozen_shell.thickness'] ??
        'Normal') {
      'Thin' => 3.0,
      'Thick' => 9.0,
      _ => 5.0,
    };
    _drawRingGlow(
      canvas,
      pos,
      vr + 4,
      thick + 10,
      const Color(0xFF00E5FF),
      0.18,
    );
    canvas.drawCircle(
      pos,
      vr + 4,
      Paint()
        ..color = const Color(0xFF00E5FF).withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thick,
    );
  }

  void _drawFrozenShellSparkles(
    Canvas canvas,
    Offset pos,
    double vr,
    double t,
  ) {
    final sparkPaint = Paint();
    for (var i = 0; i < 8; i++) {
      final a = t * 0.3 + i * pi / 4;
      final sr = vr + 6;
      sparkPaint.color = const Color(
        0xFFB3E5FC,
      ).withValues(alpha: (0.5 + 0.4 * sin(t * 3 + i)).clamp(0, 1));
      canvas.drawCircle(
        Offset(pos.dx + cos(a) * sr, pos.dy + sin(a) * sr),
        1.8,
        sparkPaint,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FRONT-PLANET EFFECTS  (drawn after the planet body)
  // ══════════════════════════════════════════════════════════════════════════

  void _renderHomeEffectsFront(
    Canvas canvas,
    Offset pos,
    double vr,
    Color col,
  ) {
    final t = _elapsed;

    if (activeCustomizations.contains('flame_ring'))
      _drawFlameRing(canvas, pos, vr, t);
    if (activeCustomizations.contains('vine_tendrils'))
      _drawVineTendrils(canvas, pos, vr, t);
    if (activeCustomizations.contains('crystal_spires'))
      _drawCrystalSpires(canvas, pos, vr, t);
    if (activeCustomizations.contains('radiant_halo'))
      _drawRadiantHalo(canvas, pos, vr, t);
    if (activeCustomizations.contains('ocean_mist'))
      _drawOceanMist(canvas, pos, vr, t);
    if (activeCustomizations.contains('blood_moon'))
      _drawBloodMoon(canvas, pos, vr, t);
    if (activeCustomizations.contains('poison_cloud'))
      _drawPoisonCloud(canvas, pos, vr, t);
    if (activeCustomizations.contains('dust_storm'))
      _drawDustStorm(canvas, pos, vr, t);
    if (activeCustomizations.contains('steam_vents'))
      _drawSteamVents(canvas, pos, vr, t);
    if (activeCustomizations.contains('lightning_rod'))
      _drawLightningRod(canvas, pos, vr, t);
    if (activeCustomizations.contains('spirit_wisps'))
      _drawSpiritWisps(canvas, pos, vr, t);
    if (activeCustomizations.contains('natures_blessing'))
      _drawNaturesBlessing(canvas, pos, vr, t);
    if (activeCustomizations.contains('orbiting_moon') &&
        homePlanet != null &&
        homePlanet!.sizeTierIndex >= 3) {
      _drawOrbitingMoon(canvas, pos, vr, t);
    }
  }

  // ── Individual front effects ──────────────────────────────────────────────

  void _drawFlameRing(Canvas canvas, Offset pos, double vr, double t) {
    final intensity = customizationOptions['flame_ring.intensity'] ?? 'Normal';
    final speedKey = customizationOptions['flame_ring.speed'] ?? 'Normal';
    final baseAlpha = switch (intensity) {
      'Dim' => 0.25,
      'Bright' => 0.70,
      _ => 0.50,
    };
    final speed = switch (speedKey) {
      'Slow' => 0.4,
      'Fast' => 1.50,
      _ => 0.80,
    };

    // Outer glow ring — one radial gradient, free.
    _drawRingGlow(
      canvas,
      pos,
      vr + 14,
      18,
      const Color(0xFFFF6E40),
      baseAlpha * 0.4,
    );

    // 8 flame blooms as radial gradients.
    for (var i = 0; i < 8; i++) {
      final a = t * speed + i * pi / 4;
      final flareR = vr + 12 + 4 * sin(t * 2 + i);
      final alpha = (baseAlpha + 0.2 * sin(t * 2 + i)).clamp(0.0, 1.0);
      final blobR = 7.0 + 2 * sin(t * 3 + i);
      final centre = Offset(pos.dx + cos(a) * flareR, pos.dy + sin(a) * flareR);
      _drawGlow(
        canvas,
        centre,
        blobR,
        const Color(0xFFFF5722),
        alpha,
        blobR * 1.6,
      );
    }
  }

  void _drawVineTendrils(Canvas canvas, Offset pos, double vr, double t) {
    final lenMul = switch (customizationOptions['vine_tendrils.length'] ??
        'Medium') {
      'Short' => 0.25,
      'Long' => 0.80,
      _ => 0.50,
    };
    final count = switch (customizationOptions['vine_tendrils.count'] ??
        'Some') {
      'Few' => 3,
      'Many' => 10,
      _ => 6,
    };
    final vinePaint = Paint()
      ..color = const Color(0xFF4CAF50).withValues(alpha: 0.70)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final leafPaint = Paint()
      ..color = const Color(0xFF81C784).withValues(alpha: 0.85);

    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + t * 0.1;
      final endR = vr + vr * lenMul + 8 * sin(t * 0.6 + i);
      final start = Offset(pos.dx + cos(a) * vr, pos.dy + sin(a) * vr);
      final end = Offset(pos.dx + cos(a) * endR, pos.dy + sin(a) * endR);
      canvas.drawLine(start, end, vinePaint);
      canvas.drawCircle(end, 3, leafPaint);
    }
  }

  void _drawCrystalSpires(Canvas canvas, Offset pos, double vr, double t) {
    final tipBase = switch (customizationOptions['crystal_spires.height'] ??
        'Medium') {
      'Short' => 8.0,
      'Tall' => 20.0,
      _ => 12.0,
    };
    final count = switch (customizationOptions['crystal_spires.density'] ??
        'Normal') {
      'Sparse' => 3,
      'Dense' => 8,
      _ => 5,
    };
    final outlinePaint = Paint()
      ..color = const Color(0xFF1DE9B6).withValues(alpha: 0.75)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = const Color(0xFF1DE9B6).withValues(alpha: 0.35);
    final sparklePaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85);

    for (var i = 0; i < count; i++) {
      final a = i * pi * 2 / count + 0.3;
      final tipLen = tipBase + 6 * sin(t * 1.5 + i);
      final base = Offset(pos.dx + cos(a) * vr, pos.dy + sin(a) * vr);
      final tip = Offset(
        pos.dx + cos(a) * (vr + tipLen),
        pos.dy + sin(a) * (vr + tipLen),
      );
      final perp = a + pi / 2;
      final path = Path()
        ..moveTo(base.dx + cos(perp) * 3, base.dy + sin(perp) * 3)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(base.dx - cos(perp) * 3, base.dy - sin(perp) * 3)
        ..close();
      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, outlinePaint);
      if (sin(t * 4 + i * 2) > 0.7) {
        canvas.drawCircle(tip, 2, sparklePaint);
      }
    }
  }

  void _drawRadiantHalo(Canvas canvas, Offset pos, double vr, double t) {
    final glowAlpha = switch (customizationOptions['radiant_halo.glow'] ??
        'Normal') {
      'Subtle' => 0.16,
      'Blinding' => 0.72,
      _ => 0.40,
    };
    final posOffset = switch (customizationOptions['radiant_halo.position'] ??
        'Mid') {
      'Close' => 8.0,
      'Outer' => vr * 3.5,
      _ => vr * 1.5,
    };
    final haloR = vr + posOffset + 3 * sin(t * 1.2);
    _drawRingGlow(
      canvas,
      pos,
      haloR,
      12,
      const Color(0xFFFFD54F),
      (glowAlpha * 0.35 + 0.05 * sin(t * 1.5)).clamp(0, 1),
    );
    canvas.drawCircle(
      pos,
      haloR,
      Paint()
        ..color = const Color(
          0xFFFFE082,
        ).withValues(alpha: (glowAlpha + 0.1 * sin(t * 1.5)).clamp(0, 1))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawOceanMist(Canvas canvas, Offset pos, double vr, double t) {
    final count = switch (customizationOptions['ocean_mist.density'] ??
        'Normal') {
      'Light' => 3,
      'Heavy' => 8,
      _ => 5,
    };
    final posOffset = switch (customizationOptions['ocean_mist.position'] ??
        'Mid') {
      'Close' => 2.0,
      'Outer' => vr * 3.5,
      _ => vr * 1.5,
    };
    for (var i = 0; i < count; i++) {
      final a = t * 0.2 + i * pi / (count / 2);
      final mr = vr + posOffset + 6 * sin(t * 0.5 + i * 1.2);
      final r = 9.0 + 3 * sin(t * 0.8 + i);
      _drawGlow(
        canvas,
        Offset(pos.dx + cos(a) * mr, pos.dy + sin(a) * mr),
        r,
        const Color(0xFF448AFF),
        0.14,
        r * 2.0,
      );
    }
  }

  void _drawBloodMoon(Canvas canvas, Offset pos, double vr, double t) {
    final pulseAmp = switch (customizationOptions['blood_moon.pulse'] ??
        'Normal') {
      'Gentle' => 0.08,
      'Intense' => 0.25,
      _ => 0.15,
    };
    final beat = pow(sin(t * pi / 0.75).clamp(0.0, 1.0), 8.0) * pulseAmp;
    _drawGlow(
      canvas,
      pos,
      vr * 1.3,
      const Color(0xFFD32F2F),
      (0.12 + beat).clamp(0, 1),
      vr * 1.8,
    );
  }

  void _drawPoisonCloud(Canvas canvas, Offset pos, double vr, double t) {
    final spread = switch (customizationOptions['poison_cloud.spread'] ??
        'Normal') {
      'Tight' => 6.0,
      'Wide' => 14.0,
      _ => 10.0,
    };
    final posOffset = switch (customizationOptions['poison_cloud.position'] ??
        'Mid') {
      'Close' => 4.0,
      'Outer' => vr * 3.5,
      _ => vr * 1.5,
    };
    for (var i = 0; i < 5; i++) {
      final a = t * 0.15 + i * pi * 2 / 5;
      final cr = vr + posOffset + spread * sin(t * 0.4 + i);
      _drawGlow(
        canvas,
        Offset(pos.dx + cos(a) * cr, pos.dy + sin(a) * cr),
        10,
        const Color(0xFF76FF03),
        (0.09 + 0.03 * sin(t + i)).clamp(0, 1),
        18,
      );
    }
  }

  void _drawDustStorm(Canvas canvas, Offset pos, double vr, double t) {
    final count = switch (customizationOptions['dust_storm.particles'] ??
        'Normal') {
      'Few' => 6,
      'Swarm' => 20,
      _ => 12,
    };
    final posOffset = switch (customizationOptions['dust_storm.position'] ??
        'Mid') {
      'Close' => 2.0,
      'Outer' => vr * 3.5,
      _ => vr * 1.5,
    };
    final p = Paint()..color = const Color(0xFFFFCC80).withValues(alpha: 0.55);
    for (var i = 0; i < count; i++) {
      final a = t * 0.6 + i * pi / (count / 2);
      final dr = vr + posOffset + 15 * sin(t * 0.3 + i * 0.5);
      canvas.drawCircle(
        Offset(pos.dx + cos(a) * dr, pos.dy + sin(a) * dr),
        1.5 + sin(t + i) * 0.5,
        p,
      );
    }
  }

  void _drawSteamVents(Canvas canvas, Offset pos, double vr, double t) {
    final ventCount = switch (customizationOptions['steam_vents.jets'] ?? '4') {
      '2' => 2,
      '6' => 6,
      _ => 4,
    };
    for (var i = 0; i < ventCount; i++) {
      final a = i * pi * 2 / ventCount + 0.4;
      final bx = pos.dx + cos(a) * vr;
      final by = pos.dy + sin(a) * vr;
      // 4-step jet: radial gradient blob instead of blurred circle
      for (var j = 0; j < 4; j++) {
        final jetDist = 5 + j * 7.0 + 3 * sin(t * 4 + i + j);
        final jc = Offset(bx + cos(a) * jetDist, by + sin(a) * jetDist);
        final jr = 3.5 + j * 0.6;
        _drawGlow(
          canvas,
          jc,
          jr,
          const Color(0xFF90A4AE),
          (0.18 - j * 0.035).clamp(0, 1),
          jr * 2.4,
        );
      }
    }
  }

  void _drawLightningRod(Canvas canvas, Offset pos, double vr, double t) {
    final freq = switch (customizationOptions['lightning_rod.frequency'] ??
        'Normal') {
      'Rare' => 1.0,
      'Frequent' => 4.0,
      _ => 2.0,
    };
    if (sin(t * 12) <= 0.5) return; // flicker — skip invisible frames

    final boltPhase = (t * freq).floor() % 6;
    final boltA = boltPhase * pi / 3 + 0.2;
    final bStart = Offset(
      pos.dx + cos(boltA) * (vr + 25),
      pos.dy + sin(boltA) * (vr + 25),
    );
    final bEnd = Offset(
      pos.dx + cos(boltA) * (vr + 2),
      pos.dy + sin(boltA) * (vr + 2),
    );

    canvas.drawLine(
      bStart,
      bEnd,
      Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    // Impact glow — radial gradient
    _drawGlow(canvas, bEnd, 5, const Color(0xFFFFEB3B), 0.55, 10);
  }

  void _drawSpiritWisps(Canvas canvas, Offset pos, double vr, double t) {
    final count = switch (customizationOptions['spirit_wisps.count'] ??
        'Some') {
      'Few' => 3,
      'Many' => 8,
      _ => 5,
    };
    final posOffset = switch (customizationOptions['spirit_wisps.position'] ??
        'Mid') {
      'Close' => 6.0,
      'Outer' => vr * 3.5,
      _ => vr * 1.5,
    };
    for (var i = 0; i < count; i++) {
      final a = t * 0.4 + i * pi * 2 / count;
      final wr = vr + posOffset + 8 * sin(t * 0.7 + i * 1.5);
      final wc = Offset(pos.dx + cos(a) * wr, pos.dy + sin(a) * wr);
      // Soft blue halo
      _drawGlow(
        canvas,
        wc,
        4.5,
        const Color(0xFF3F51B5),
        (0.28 + 0.2 * sin(t * 2 + i)).clamp(0, 1),
        9,
      );
      // Bright white core
      canvas.drawCircle(
        wc,
        1.8,
        Paint()
          ..color = const Color(
            0xFFE8EAF6,
          ).withValues(alpha: (0.65 + 0.3 * sin(t * 3 + i)).clamp(0, 1)),
      );
    }
  }

  void _drawNaturesBlessing(Canvas canvas, Offset pos, double vr, double t) {
    final brightnessKey =
        customizationOptions['natures_blessing.brightness'] ?? 'Normal';
    final brightness = switch (brightnessKey) {
      'Dim' => 0.18,
      'Bright' => 0.92,
      _ => 0.50,
    };
    final blobR = switch (brightnessKey) {
      'Dim' => 2.6,
      'Bright' => 8.8,
      _ => 5.6,
    };
    final posOffset =
        switch (customizationOptions['natures_blessing.position'] ?? 'Mid') {
          'Close' => 4.0,
          'Outer' => vr * 3.5,
          _ => vr * 1.5,
        };

    final elements = kElementColors.entries.toList();
    final nr = vr + posOffset;

    for (var i = 0; i < elements.length; i++) {
      final a = t * 0.15 + i * pi * 2 / elements.length;
      final alpha = (brightness + 0.2 * sin(t * 1.5 + i)).clamp(0.0, 1.0);
      final bc = Offset(pos.dx + cos(a) * nr, pos.dy + sin(a) * nr);
      // Radial gradient — replaces the blurred circle entirely
      _drawGlow(canvas, bc, blobR, elements[i].value, alpha, blobR * 2.2);
    }

    if (brightnessKey == 'Bright') {
      _drawRingGlow(canvas, pos, nr + 14, 12, const Color(0xFFFFFFFF), 0.20);
    }
  }

  void _drawOrbitingMoon(Canvas canvas, Offset pos, double vr, double t) {
    final moonR = switch (customizationOptions['orbiting_moon.size'] ??
        'Medium') {
      'Small' => vr * 0.12,
      'Large' => vr * 0.25,
      _ => vr * 0.18,
    };
    final speed = switch (customizationOptions['orbiting_moon.speed'] ??
        'Normal') {
      'Slow' => 0.3,
      'Fast' => 1.2,
      _ => 0.6,
    };
    final moonOrbitR = vr + 30 + moonR;
    final angle = t * speed;
    final mc = Offset(
      pos.dx + cos(angle) * moonOrbitR,
      pos.dy + sin(angle) * moonOrbitR,
    );

    // Soft shadow — radial gradient offset
    _drawGlow(
      canvas,
      Offset(mc.dx + 2, mc.dy + 3),
      moonR * 1.1,
      Colors.black,
      0.28,
      moonR * 1.8,
    );

    // Moon body — radial gradient sphere
    canvas.drawCircle(
      mc,
      moonR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(mc.dx - moonR * 0.3, mc.dy - moonR * 0.3),
          moonR * 1.5,
          [
            const Color(0xFFE0E0E0),
            const Color(0xFF9E9E9E),
            const Color(0xFF616161),
          ],
          [0.0, 0.5, 1.0],
        ),
    );

    // Craters
    final craterPaint = Paint()
      ..color = const Color(0xFF757575).withValues(alpha: 0.5);
    for (var i = 0; i < 3; i++) {
      final ca = i * pi * 2 / 3 + 0.5;
      canvas.drawCircle(
        Offset(mc.dx + cos(ca) * moonR * 0.4, mc.dy + sin(ca) * moonR * 0.4),
        moonR * 0.10,
        craterPaint,
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PRIMITIVE GLOW HELPERS  (replaces all MaskFilter.blur usage)
  //  These use radial gradients — rendered entirely on the GPU, zero blur cost.
  // ══════════════════════════════════════════════════════════════════════════

  /// Soft radial glow centred on [centre].
  /// [innerR] is the solid-ish core, [outerR] is where alpha fades to zero.
  void _drawGlow(
    Canvas canvas,
    Offset centre,
    double innerR,
    Color color,
    double alpha,
    double outerR,
  ) {
    canvas.drawCircle(
      centre,
      outerR,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          outerR,
          [
            color.withValues(alpha: alpha.clamp(0, 1)),
            color.withValues(alpha: 0),
          ],
          [innerR / outerR, 1.0],
        ),
    );
  }

  /// Ring glow: a soft halo around a circle of radius [ringR].
  void _drawRingGlow(
    Canvas canvas,
    Offset centre,
    double ringR,
    double spread,
    Color color,
    double alpha,
  ) {
    canvas.drawCircle(
      centre,
      ringR + spread,
      Paint()
        ..shader = ui.Gradient.radial(
          centre,
          ringR + spread,
          [
            color.withValues(alpha: 0),
            color.withValues(alpha: alpha.clamp(0, 1)),
            color.withValues(alpha: 0),
          ],
          [
            ((ringR - spread * 0.5) / (ringR + spread)).clamp(0, 1),
            (ringR / (ringR + spread)).clamp(0, 1),
            1.0,
          ],
        ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPANION SPRITE COLOUR FILTERS
  // ══════════════════════════════════════════════════════════════════════════

  ui.ColorFilter _geneticsColorFilter(SpriteVisuals v) {
    var m = _identityMatrix();

    if (v.saturation != 1.0 || v.brightness != 1.0) {
      m = _mulMatrix(_bsSatMatrix(v.brightness, v.saturation), m);
    }

    final rawHue = v.isPrismatic
        ? (v.hueShiftDeg + (_elapsed * 45.0) % 360)
        : v.hueShiftDeg;
    final normHue = ((rawHue % 360) + 360) % 360;
    if (normHue != 0) m = _mulMatrix(_hueMatrix(normHue), m);

    // Apply variant tint if present and not albino
    if (v.tint != null && !(v.brightness == 1.45 && !v.isPrismatic)) {
      final tr = v.tint!.r, tg = v.tint!.g, tb = v.tint!.b;
      m = _mulMatrix(<double>[
        tr,
        0,
        0,
        0,
        0,
        0,
        tg,
        0,
        0,
        0,
        0,
        0,
        tb,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ], m);
    }

    return ui.ColorFilter.matrix(m);
  }

  ui.ColorFilter _albinoColorFilter(double brightness) {
    const r = 0.299, g = 0.587, b = 0.114;
    return ui.ColorFilter.matrix(<double>[
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      r * brightness,
      g * brightness,
      b * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  // ── Matrix math ───────────────────────────────────────────────────────────

  List<double> _identityMatrix() => <double>[
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  List<double> _bsSatMatrix(double brightness, double saturation) {
    final s = saturation;
    return <double>[
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      s * brightness,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _hueMatrix(double degrees) {
    final rad = degrees * (pi / 180.0);
    final c = cos(rad), s = sin(rad);
    return <double>[
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928,
      0,
      0,
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0,
      0,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  List<double> _mulMatrix(List<double> a, List<double> b) {
    final out = List<double>.filled(20, 0.0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 4; col++) {
        double sum = 0.0;
        for (int k = 0; k < 4; k++) {
          sum += a[row * 5 + k] * b[k * 5 + col];
        }
        out[row * 5 + col] = sum;
      }
      double tx = a[row * 5 + 4];
      for (int k = 0; k < 4; k++) {
        tx += a[row * 5 + k] * b[k * 5 + 4];
      }
      out[row * 5 + 4] = tx;
    }
    return out;
  }
}
