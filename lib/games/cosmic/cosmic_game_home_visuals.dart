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
    if (_planetBlockingPlacement(pos) != null) {
      return 'Too close to another planet';
    }
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
    if (_planetBlockingPlacement(pos) != null) {
      return 'Too close to another planet';
    }
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
  /// Each entry is:
  /// (color, instanceId?, baseCreatureId?, displayName?, imagePath?, spriteVisuals?)
  void spawnOrbitalChambers(
    List<(Color, String?, String?, String?, String?, SpriteVisuals?)>
    chamberData,
  ) {
    if (homePlanet == null) return;
    orbitalChambers.clear();
    final hp = homePlanet!.position;
    final vr = homePlanet!.visualRadius;
    final rng = Random();
    for (var i = 0; i < chamberData.length; i++) {
      final (color, instId, baseId, name, imgPath, spriteVisuals) =
          chamberData[i];
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
          spriteVisuals: spriteVisuals,
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

  // ── Ammo color ────────────────────────────────────────────────────────────

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
    // Rings back half (behind planet).
    if (activeCustomizations.contains('planetary_rings')) {
      _drawPlanetaryRings(canvas, pos, vr, t, frontOnly: false);
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

  double _planetEffectScale(double vr) => (vr / 80.0).clamp(0.6, 2.8);

  double _scaledEffectPx(
    double vr,
    double base, {
    double min = 0.0,
    double? max,
  }) {
    final scaled = base * _planetEffectScale(vr);
    if (max == null) return scaled.clamp(min, double.infinity);
    return scaled.clamp(min, max);
  }

  void _drawLavaMoat(Canvas canvas, Offset pos, double vr, double t) {
    if (!activeCustomizations.contains('lava_moat')) return;
    final moatWidth = switch (customizationOptions['lava_moat.width'] ??
        'Normal') {
      'Thin' => _scaledEffectPx(vr, 3.0, min: 2.0, max: 8.0),
      'Wide' => _scaledEffectPx(vr, 10.0, min: 5.0, max: 24.0),
      _ => _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0),
    };
    final moatR = vr + _scaledEffectPx(vr, 14.0, min: 8.0, max: 34.0);
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
      'Thin' => _scaledEffectPx(vr, 4.0, min: 2.5, max: 10.0),
      'Thick' => _scaledEffectPx(vr, 14.0, min: 7.0, max: 30.0),
      _ => _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
    };
    _drawRingGlow(
      canvas,
      pos,
      vr + _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0),
      thick + _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
      const Color(0xFF795548),
      0.25,
    );
    canvas.drawCircle(
      pos,
      vr + _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0),
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
      'Thin' => _scaledEffectPx(vr, 3.0, min: 2.0, max: 8.0),
      'Thick' => _scaledEffectPx(vr, 9.0, min: 5.0, max: 20.0),
      _ => _scaledEffectPx(vr, 5.0, min: 3.0, max: 12.0),
    };
    _drawRingGlow(
      canvas,
      pos,
      vr + _scaledEffectPx(vr, 4.0, min: 2.5, max: 10.0),
      thick + _scaledEffectPx(vr, 10.0, min: 5.0, max: 20.0),
      const Color(0xFF00E5FF),
      0.18,
    );
    canvas.drawCircle(
      pos,
      vr + _scaledEffectPx(vr, 4.0, min: 2.5, max: 10.0),
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
      final sr = vr + _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0);
      sparkPaint.color = const Color(
        0xFFB3E5FC,
      ).withValues(alpha: (0.5 + 0.4 * sin(t * 3 + i)).clamp(0, 1));
      canvas.drawCircle(
        Offset(pos.dx + cos(a) * sr, pos.dy + sin(a) * sr),
        _scaledEffectPx(vr, 1.8, min: 1.2, max: 4.2),
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

    if (activeCustomizations.contains('flame_ring')) {
      _drawFlameRing(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('vine_tendrils')) {
      _drawVineTendrils(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('crystal_spires')) {
      _drawCrystalSpires(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('radiant_halo')) {
      _drawRadiantHalo(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('ocean_mist')) {
      _drawOceanMist(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('blood_moon')) {
      _drawBloodMoon(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('poison_cloud')) {
      _drawPoisonCloud(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('dust_storm')) {
      _drawDustStorm(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('steam_vents')) {
      _drawSteamVents(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('lightning_rod')) {
      _drawLightningRod(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('spirit_wisps')) {
      _drawSpiritWisps(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('natures_blessing')) {
      _drawNaturesBlessing(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('orbiting_moon') &&
        homePlanet != null &&
        homePlanet!.sizeTierIndex >= 3) {
      _drawOrbitingMoon(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('phantom_phase')) {
      _drawPhantomPhase(canvas, pos, vr, t);
    }
    if (activeCustomizations.contains('electric_field')) {
      _drawElectricField(canvas, pos, vr, t);
    }
    // Rings front half (over planet).
    if (activeCustomizations.contains('planetary_rings')) {
      _drawPlanetaryRings(canvas, pos, vr, t, frontOnly: true);
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
      vr + _scaledEffectPx(vr, 14.0, min: 8.0, max: 34.0),
      _scaledEffectPx(vr, 18.0, min: 10.0, max: 36.0),
      const Color(0xFFFF6E40),
      baseAlpha * 0.4,
    );

    // 8 flame blooms as radial gradients.
    for (var i = 0; i < 8; i++) {
      final a = t * speed + i * pi / 4;
      final flareR =
          vr +
          _scaledEffectPx(vr, 12.0, min: 6.0, max: 28.0) +
          _scaledEffectPx(vr, 4.0, min: 2.0, max: 10.0) * sin(t * 2 + i);
      final alpha = (baseAlpha + 0.2 * sin(t * 2 + i)).clamp(0.0, 1.0);
      final blobR =
          _scaledEffectPx(vr, 7.0, min: 4.0, max: 18.0) +
          _scaledEffectPx(vr, 2.0, min: 1.0, max: 5.0) * sin(t * 3 + i);
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
      'Short' => 0.30,
      'Long' => 0.80,
      _ => 0.55,
    };
    final count = switch (customizationOptions['vine_tendrils.count'] ??
        'Some') {
      'Few' => 4,
      'Many' => 10,
      _ => 7,
    };
    final segments = 12;

    for (var i = 0; i < count; i++) {
      final baseAngle =
          i * pi * 2 / count + sin(t * 0.3 + i) * 0.06;
      final vineLen = vr * lenMul * (1.0 + 0.25 * sin(t * 0.5 + i * 1.7));

      final vinePath = Path();
      final leafPositions = <Offset>[];
      final leafAngles = <double>[];

      Offset prev = Offset(
        pos.dx + cos(baseAngle) * vr * 0.92,
        pos.dy + sin(baseAngle) * vr * 0.92,
      );
      vinePath.moveTo(prev.dx, prev.dy);

      for (var s = 1; s <= segments; s++) {
        final frac = s / segments;
        final sway =
            sin(t * 1.5 + i * 2.3 + s * 0.8) *
            _scaledEffectPx(vr, 8.0, min: 3.0, max: 18.0) *
            frac;
        final perpAngle = baseAngle + pi / 2;
        final dist = vr * 0.92 + vineLen * frac;
        final pt = Offset(
          pos.dx + cos(baseAngle) * dist + cos(perpAngle) * sway,
          pos.dy + sin(baseAngle) * dist + sin(perpAngle) * sway,
        );
        vinePath.lineTo(pt.dx, pt.dy);
        prev = pt;

        if (s % 3 == 0 && s < segments) {
          leafPositions.add(pt);
          leafAngles.add(baseAngle);
        }
      }

      // Vine stroke — thin outer + lighter inner like plant planet
      final vineColor = Color.lerp(
        const Color(0xFF2E7D32),
        const Color(0xFF66BB6A),
        i / count,
      )!;
      canvas.drawPath(
        vinePath,
        Paint()
          ..color = vineColor.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 2.4, min: 1.4, max: 5.0)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        vinePath,
        Paint()
          ..color = const Color(0xFF81C784).withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 1.0, min: 0.6, max: 2.2)
          ..strokeCap = StrokeCap.round,
      );

      // Teardrop leaves at intervals
      for (var li = 0; li < leafPositions.length; li++) {
        final lp = leafPositions[li];
        final la =
            leafAngles[li] +
            pi / 2 * (li.isEven ? 1 : -1) +
            sin(t * 2 + i + li) * 0.3;
        final leafSize = _scaledEffectPx(vr, 6.0, min: 3.0, max: 13.0) *
            (1.0 + 0.15 * sin(t * 1.2 + li * 1.5));

        canvas.save();
        canvas.translate(lp.dx, lp.dy);
        canvas.rotate(la);

        final leafPath = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(
            leafSize * 0.6,
            -leafSize * 0.5,
            leafSize * 1.5,
            0,
          )
          ..quadraticBezierTo(leafSize * 0.6, leafSize * 0.5, 0, 0);

        canvas.drawPath(
          leafPath,
          Paint()..color = const Color(0xFF4CAF50).withValues(alpha: 0.80),
        );
        // Leaf vein
        canvas.drawLine(
          Offset.zero,
          Offset(leafSize * 1.2, 0),
          Paint()
            ..color = const Color(0xFF388E3C).withValues(alpha: 0.45)
            ..strokeWidth = _scaledEffectPx(vr, 0.5, min: 0.3, max: 1.0),
        );
        canvas.restore();
      }

      // Glowing tip bud
      final tipGlow = 0.35 + 0.25 * sin(t * 2 + i * 1.5);
      final budR = _scaledEffectPx(vr, 2.8, min: 1.6, max: 6.0);
      _drawGlow(canvas, prev, budR, const Color(0xFFA5D6A7), tipGlow, budR * 2.0);
      canvas.drawCircle(
        prev,
        budR * 0.55,
        Paint()..color = Colors.white.withValues(alpha: tipGlow * 0.75),
      );
    }
  }

  void _drawCrystalSpires(Canvas canvas, Offset pos, double vr, double t) {
    final intensity = switch (customizationOptions['crystal_spires.height'] ??
        'Medium') {
      'Short' => 0.6,
      'Tall' => 1.4,
      _ => 1.0,
    };
    final count = switch (customizationOptions['crystal_spires.density'] ??
        'Normal') {
      'Sparse' => 3,
      'Dense' => 7,
      _ => 5,
    };

    // Crystalline surface reflection — a bright specular highlight that
    // slowly rotates around the planet surface, plus twinkling facet glints.

    // Main specular highlight — crescentic reflection
    final specAngle = t * 0.15;
    final specDist = vr * 0.35;
    final specCenter = Offset(
      pos.dx + cos(specAngle) * specDist,
      pos.dy + sin(specAngle) * specDist,
    );
    final specR = _scaledEffectPx(vr, 28.0, min: 14.0, max: 60.0) * intensity;
    _drawGlow(
      canvas,
      specCenter,
      specR,
      const Color(0xFFE0F7FA),
      0.22 * intensity,
      specR * 1.8,
    );
    // Secondary softer reflection on opposite side
    final spec2Center = Offset(
      pos.dx + cos(specAngle + pi * 0.7) * specDist * 0.8,
      pos.dy + sin(specAngle + pi * 0.7) * specDist * 0.8,
    );
    _drawGlow(
      canvas,
      spec2Center,
      specR * 0.6,
      const Color(0xFFB2EBF2),
      0.14 * intensity,
      specR * 1.2,
    );

    // Facet glints — small twinkling sparkles across planet surface
    for (var i = 0; i < count; i++) {
      final glintAngle = i * pi * 2 / count + t * 0.08 + i * 0.6;
      final glintDist = vr * (0.25 + 0.45 * ((i * 0.618) % 1.0));
      final glintPos = Offset(
        pos.dx + cos(glintAngle) * glintDist,
        pos.dy + sin(glintAngle) * glintDist,
      );

      // Twinkle pattern — each glint fades in and out at different rates
      final twinkle = sin(t * (2.0 + i * 0.4) + i * 1.8);
      if (twinkle < 0.2) continue;

      final alpha = (twinkle - 0.2) * 0.6 * intensity;
      final glintR = _scaledEffectPx(vr, 2.0 + twinkle * 1.5, min: 1.0, max: 5.0);

      // Star-cross glint
      final crossLen = glintR * 2.5;
      final crossPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0))
        ..strokeWidth = _scaledEffectPx(vr, 0.7, min: 0.4, max: 1.5)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(glintPos.dx - crossLen, glintPos.dy),
        Offset(glintPos.dx + crossLen, glintPos.dy),
        crossPaint,
      );
      canvas.drawLine(
        Offset(glintPos.dx, glintPos.dy - crossLen),
        Offset(glintPos.dx, glintPos.dy + crossLen),
        crossPaint,
      );

      // Core dot
      _drawGlow(
        canvas,
        glintPos,
        glintR,
        Colors.white,
        alpha.clamp(0.0, 0.5),
        glintR * 2.0,
      );
    }

    // Subtle rim highlight — thin arc on the "lit" side
    final rimArc = _scaledEffectPx(vr, 1.5, min: 0.8, max: 3.0);
    final rimPath = Path()
      ..addArc(
        Rect.fromCircle(center: pos, radius: vr * 0.96),
        specAngle - 0.5,
        1.0,
      );
    canvas.drawPath(
      rimPath,
      Paint()
        ..color = const Color(0xFF80DEEA).withValues(alpha: 0.18 * intensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = rimArc
        ..strokeCap = StrokeCap.round,
    );
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
    final haloR =
        vr +
        posOffset +
        _scaledEffectPx(vr, 3.0, min: 1.5, max: 8.0) * sin(t * 1.2);
    _drawRingGlow(
      canvas,
      pos,
      haloR,
      _scaledEffectPx(vr, 12.0, min: 6.0, max: 26.0),
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
        ..strokeWidth = _scaledEffectPx(vr, 2.5, min: 1.5, max: 6.0),
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
      final r =
          _scaledEffectPx(vr, 9.0, min: 5.0, max: 18.0) +
          _scaledEffectPx(vr, 3.0, min: 1.5, max: 6.0) * sin(t * 0.8 + i);
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
    final moonR = switch (customizationOptions['blood_moon.size'] ??
        'Medium') {
      'Small' => vr * 0.10,
      'Large' => vr * 0.22,
      _ => vr * 0.15,
    };
    final distGap = switch (customizationOptions['blood_moon.distance'] ??
        'Mid') {
      'Close' => 4.0,
      'Far' => vr * 2.5,
      _ => vr * 0.8,
    };
    final orbitR = vr + distGap + moonR;
    // Orbit in opposite direction to regular moon for variety
    final angle = -t * 0.45;
    final mc = Offset(
      pos.dx + cos(angle) * orbitR,
      pos.dy + sin(angle) * orbitR,
    );

    // Crimson aura — pulsing glow around the moon
    final beat = pow(sin(t * pi / 0.75).clamp(0.0, 1.0), 8.0) * pulseAmp;
    _drawGlow(
      canvas,
      mc,
      moonR * 2.2,
      const Color(0xFFD32F2F),
      (0.12 + beat).clamp(0, 1),
      moonR * 3.0,
    );

    // Shadow
    _drawGlow(
      canvas,
      Offset(mc.dx + 2, mc.dy + 3),
      moonR * 1.1,
      Colors.black,
      0.30,
      moonR * 1.8,
    );

    // Moon body — dark crimson sphere
    canvas.drawCircle(
      mc,
      moonR,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(mc.dx - moonR * 0.3, mc.dy - moonR * 0.3),
          moonR * 1.5,
          [
            const Color(0xFFE57373),
            const Color(0xFFC62828),
            const Color(0xFF4E0000),
          ],
          [0.0, 0.5, 1.0],
        ),
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
        _scaledEffectPx(vr, 10.0, min: 5.0, max: 22.0),
        const Color(0xFF76FF03),
        (0.09 + 0.03 * sin(t + i)).clamp(0, 1),
        _scaledEffectPx(vr, 18.0, min: 10.0, max: 36.0),
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
      final dr =
          vr +
          posOffset +
          _scaledEffectPx(vr, 15.0, min: 8.0, max: 34.0) *
              sin(t * 0.3 + i * 0.5);
      canvas.drawCircle(
        Offset(pos.dx + cos(a) * dr, pos.dy + sin(a) * dr),
        _scaledEffectPx(vr, 1.5, min: 1.0, max: 3.5) +
            _scaledEffectPx(vr, 0.5, min: 0.25, max: 1.0) * sin(t + i),
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
        final jetDist =
            _scaledEffectPx(vr, 5.0, min: 3.0, max: 12.0) +
            j * _scaledEffectPx(vr, 7.0, min: 4.0, max: 16.0) +
            _scaledEffectPx(vr, 3.0, min: 1.5, max: 8.0) *
                sin(t * 4 + i + j);
        final jc = Offset(bx + cos(a) * jetDist, by + sin(a) * jetDist);
        final jr =
            _scaledEffectPx(vr, 3.5, min: 2.0, max: 8.0) +
            j * _scaledEffectPx(vr, 0.6, min: 0.3, max: 1.4);
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
    final outerOffset = _scaledEffectPx(vr, 25.0, min: 12.0, max: 56.0);
    final innerOffset = _scaledEffectPx(vr, 2.0, min: 1.0, max: 6.0);
    final bStart = Offset(
      pos.dx + cos(boltA) * (vr + outerOffset),
      pos.dy + sin(boltA) * (vr + outerOffset),
    );
    final bEnd = Offset(
      pos.dx + cos(boltA) * (vr + innerOffset),
      pos.dy + sin(boltA) * (vr + innerOffset),
    );

    canvas.drawLine(
      bStart,
      bEnd,
      Paint()
        ..color = const Color(0xFFFFEB3B).withValues(alpha: 0.75)
        ..strokeWidth = _scaledEffectPx(vr, 2.0, min: 1.4, max: 5.0)
        ..strokeCap = StrokeCap.round,
    );
    // Impact glow — radial gradient
    _drawGlow(
      canvas,
      bEnd,
      _scaledEffectPx(vr, 5.0, min: 3.0, max: 12.0),
      const Color(0xFFFFEB3B),
      0.55,
      _scaledEffectPx(vr, 10.0, min: 6.0, max: 22.0),
    );
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
        _scaledEffectPx(vr, 4.5, min: 2.5, max: 10.0),
        const Color(0xFF3F51B5),
        (0.28 + 0.2 * sin(t * 2 + i)).clamp(0, 1),
        _scaledEffectPx(vr, 9.0, min: 5.0, max: 20.0),
      );
      // Bright white core
      canvas.drawCircle(
        wc,
        _scaledEffectPx(vr, 1.8, min: 1.0, max: 4.0),
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
      _drawRingGlow(
        canvas,
        pos,
        nr + _scaledEffectPx(vr, 14.0, min: 8.0, max: 30.0),
        _scaledEffectPx(vr, 12.0, min: 6.0, max: 24.0),
        const Color(0xFFFFFFFF),
        0.20,
      );
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
    final distGap = switch (customizationOptions['orbiting_moon.distance'] ?? 'Mid') {
      'Close' => 4.0,
      'Far' => vr * 2.5,
      _ => vr * 0.8,
    };
    final moonOrbitR = vr + distGap + moonR;
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

  }

  // ── Planetary Rings — tilted orbital disc with sparkles ────────────────────

  void _drawPlanetaryRings(
    Canvas canvas,
    Offset pos,
    double vr,
    double t, {
    required bool frontOnly,
  }) {
    final ringCount = switch (customizationOptions['planetary_rings.count'] ??
        '2') {
      '1' => 1,
      '3' => 3,
      _ => 2,
    };
    final style = customizationOptions['planetary_rings.style'] ?? 'Icy';

    // Style determines colors
    final (Color ringColor, Color sparkColor) = switch (style) {
      'Rocky' => (const Color(0xFFA1887F), const Color(0xFFD7CCC8)),
      'Prismatic' => (
        HSVColor.fromAHSV(1.0, (t * 30) % 360, 0.5, 1.0).toColor(),
        Colors.white,
      ),
      _ => (const Color(0xFFB2EBF2), Colors.white), // Icy
    };

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(-0.18);
    canvas.scale(1.0, 0.25); // flatten into disc

    if (frontOnly) {
      // Match the icy source planet: only the near-side upper arc sits in front.
      canvas.clipRect(Rect.fromLTRB(-vr * 4, -vr * 4, vr * 4, 0));
    }

    for (var ring = 0; ring < ringCount; ring++) {
      final ringR = vr * (1.55 + ring * 0.22);
      final alpha = (0.16 - ring * 0.03).clamp(0.04, 0.2);
      final strokeW = (vr * (0.08 - ring * 0.015)).clamp(2.0, 18.0);

      // Ring band
      canvas.drawCircle(
        Offset.zero,
        ringR,
        Paint()
          ..color = ringColor.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeW.clamp(2.0, 10.0),
      );

      // Sparkle particles in this ring
      if (!frontOnly) {
        final sparkCount = 4 + ring * 2;
        for (var i = 0; i < sparkCount; i++) {
          final sparkAngle =
              t * 0.12 * (ring.isEven ? 1 : -1) + i * pi * 2 / sparkCount;
          final sparkAlpha = (0.35 + 0.3 * sin(t * 3 + i * 2.1 + ring * 1.5))
              .clamp(0.0, 0.65);
          final sx = cos(sparkAngle) * ringR;
          final sy = sin(sparkAngle) * ringR;
          canvas.drawCircle(
            Offset(sx, sy),
            _scaledEffectPx(vr, 1.2, min: 0.9, max: 2.6) +
                _scaledEffectPx(vr, 0.4, min: 0.2, max: 0.8) *
                    sin(t * 4 + i),
            Paint()..color = sparkColor.withValues(alpha: sparkAlpha),
          );
        }
      }
    }

    canvas.restore();
  }

  // ── Phantom Phase — planet fades translucent periodically ──────────────────

  void _drawPhantomPhase(Canvas canvas, Offset pos, double vr, double t) {
    final intensity =
        customizationOptions['phantom_phase.intensity'] ?? 'Normal';
    // How transparent the planet becomes at peak phase
    final fadeDepth = switch (intensity) {
      'Subtle' => 0.15,
      'Deep' => 0.55,
      _ => 0.35,
    };

    // 8s cycle: 0-6s visible, 6-7s fade out, 7-8s fade back
    final cycle = t % 8.0;
    double phaseAlpha;
    if (cycle < 6.0) {
      phaseAlpha = 0.0;
    } else if (cycle < 7.0) {
      final f = cycle - 6.0;
      phaseAlpha = f * f * fadeDepth; // ease-in fade
    } else {
      final f = cycle - 7.0;
      phaseAlpha = fadeDepth * (1.0 - f * (2.0 - f)); // ease-out return
    }

    if (phaseAlpha < 0.01) return; // nothing to draw most of the time

    // Overlay a dark disc that partially hides the planet (simulates transparency)
    _drawGlow(
      canvas,
      pos,
      vr * 0.7,
      const Color(0xFF0A0014),
      phaseAlpha,
      vr * 1.1,
    );

    // Spectral shimmer at the edges during phase
    _drawRingGlow(
      canvas,
      pos,
      vr.toDouble(),
      _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
      const Color(0xFF7C4DFF),
      phaseAlpha * 0.6,
    );
  }

  // ── Electric Field — crackling bolts & sparks around the planet ────────────

  void _drawElectricField(Canvas canvas, Offset pos, double vr, double t) {
    final boltCount = switch (customizationOptions['electric_field.bolts'] ??
        'Normal') {
      'Few' => 3,
      'Many' => 7,
      _ => 5,
    };
    final intensityAlpha =
        switch (customizationOptions['electric_field.intensity'] ?? 'Normal') {
          'Dim' => 0.4,
          'Bright' => 0.9,
          _ => 0.65,
        };

    final fieldR = vr + _scaledEffectPx(vr, 22.0, min: 12.0, max: 52.0);

    // ── Ambient electric haze ──
    _drawRingGlow(
      canvas,
      pos,
      fieldR,
      _scaledEffectPx(vr, 12.0, min: 6.0, max: 24.0),
      const Color(0xFFFFEB3B),
      intensityAlpha * 0.08,
    );

    // ── Lightning bolts — flickering arcs from field to surface ──
    for (var i = 0; i < boltCount; i++) {
      final seed = (pos.dx.toInt() ^ pos.dy.toInt()) + i * 137;
      final phase = t * (2.5 + i * 0.7) + seed * 0.1;
      final flash = sin(phase) * sin(phase * 3.7 + i);
      if (flash <= 0.3) continue; // bolt not visible this frame

      final boltAlpha = ((flash - 0.3) * 1.4).clamp(0.0, 1.0) * intensityAlpha;
      final startAngle =
          (seed * 0.1 + t * 0.15 * (i.isEven ? 1 : -1)) % (pi * 2);
      final boltStart = Offset(
        pos.dx + cos(startAngle) * fieldR,
        pos.dy + sin(startAngle) * fieldR,
      );
      final endAngle = startAngle + (sin(seed.toDouble()) * 0.3);
      final boltEnd = Offset(
        pos.dx + cos(endAngle) * (vr + 2),
        pos.dy + sin(endAngle) * (vr + 2),
      );

      // Draw zig-zag bolt
      final boltPath = Path();
      boltPath.moveTo(boltStart.dx, boltStart.dy);
      const segments = 4;
      for (var s = 1; s <= segments; s++) {
        final frac = s / segments;
        final mx = boltStart.dx + (boltEnd.dx - boltStart.dx) * frac;
        final my = boltStart.dy + (boltEnd.dy - boltStart.dy) * frac;
        final perpX = -(boltEnd.dy - boltStart.dy);
        final perpY = (boltEnd.dx - boltStart.dx);
        final perpLen = sqrt(perpX * perpX + perpY * perpY);
        final jag =
            sin(t * 12 + s * 3.0 + i * 7) *
            _scaledEffectPx(vr, 6.0, min: 3.0, max: 14.0);
        if (perpLen > 0 && s < segments) {
          boltPath.lineTo(
            mx + (perpX / perpLen) * jag,
            my + (perpY / perpLen) * jag,
          );
        } else {
          boltPath.lineTo(mx, my);
        }
      }

      // Glow layer
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = const Color(0xFFFFEB3B).withValues(alpha: boltAlpha * 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 3.5, min: 2.0, max: 8.0)
          ..strokeCap = StrokeCap.round,
      );
      // Core layer
      canvas.drawPath(
        boltPath,
        Paint()
          ..color = Colors.white.withValues(alpha: boltAlpha * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _scaledEffectPx(vr, 1.2, min: 0.9, max: 3.0)
          ..strokeCap = StrokeCap.round,
      );

      // Impact glow at surface
      _drawGlow(
        canvas,
        boltEnd,
        _scaledEffectPx(vr, 3.0, min: 1.8, max: 7.0),
        const Color(0xFFFFEB3B),
        boltAlpha * 0.6,
        _scaledEffectPx(vr, 8.0, min: 4.0, max: 18.0),
      );
    }

    // ── Orbiting spark motes ──
    for (var i = 0; i < 6; i++) {
      final sparkAngle = t * (0.5 + i * 0.12) + i * pi / 3;
      final sparkDist = fieldR * (0.92 + 0.08 * sin(t * 3 + i * 2));
      final sx = pos.dx + cos(sparkAngle) * sparkDist;
      final sy = pos.dy + sin(sparkAngle) * sparkDist;
      final sparkAlpha =
          (0.3 + 0.3 * sin(t * 6 + i * 1.7)).clamp(0.0, 0.6) * intensityAlpha;
      _drawGlow(
        canvas,
        Offset(sx, sy),
        _scaledEffectPx(vr, 1.0, min: 0.8, max: 2.2),
        const Color(0xFFFFEB3B),
        sparkAlpha,
        _scaledEffectPx(vr, 4.0, min: 2.0, max: 8.0),
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
  //  COMPANION SPRITE COLOR FILTERS
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
