part of 'cosmic_game.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Performance constants
//  • All glow is done with radial gradients — zero MaskFilter.blur
//  • Slow/static effects are cached into a ui.Picture and replayed each frame
//  • Particle counts are kept low; sub-pixel blobs skip drawing entirely
// ─────────────────────────────────────────────────────────────────────────────

extension CosmicGameHomeAndVisuals on CosmicGame {
  // ── Orbital setup ──────────────────────────────────────────────────────────

  /// Ties the home at [homePos] to the planet whose pull holds it, if one
  /// does. Nothing moves when the tie is made: the orbit is taken at the
  /// distance and the angle the two already stand at, so a home placed
  /// inside a pull begins exactly where it was placed and drifts from there.
  /// The home's saved position is a point on that orbit, so a restore takes
  /// up the same radius again.
  void _setupOrbitalRelationship(Offset homePos) {
    final partner = _nearestPlanetForOrbit(homePos);
    if (partner == null) {
      _orbitalPartner = null;
      return;
    }
    _orbitalPartner = partner;
    final homeVr = homePlanet!.visualRadius;
    // From the planet to the home, across the world's seam if need be.
    final d = _toroidalDelta(homePos, partner.position);
    _orbitRadius = d.distance;
    if (homeVr >= partner.radius) {
      // The home is the heavier: the planet goes round it, from where the
      // planet stands (the angle seen from the home, not from the planet).
      _homeOrbitsPartner = false;
      _orbitAngle = atan2(-d.dy, -d.dx);
      _orbitSpeed = 0.02;
    } else {
      _homeOrbitsPartner = true;
      _orbitAngle = atan2(d.dy, d.dx);
      _orbitSpeed = 0.015;
    }
  }

  /// The planet whose pull would hold a home placed at [pos] — it would
  /// orbit that planet — or null when nothing would, or when the spot is
  /// too close to build on at all (see [homePlacementBlockerAt]).
  CosmicPlanet? homeCaptureAt(Offset pos) {
    if (_planetBlockingPlacement(pos) != null) return null;
    return _nearestPlanetForOrbit(pos);
  }

  /// The planet a home placed at [pos] would sit too close to, or null.
  CosmicPlanet? homePlacementBlockerAt(Offset pos) =>
      _planetBlockingPlacement(pos);

  /// The planet the home is tied to by its pull, or null.
  CosmicPlanet? get homeOrbitPartner => _orbitalPartner;

  /// Whether the home goes round [homeOrbitPartner] (true) or the planet
  /// goes round the home (false).
  bool get homeOrbitsPartner => _homeOrbitsPartner;

  /// The radius of the orbit tying home and partner, world units.
  double get homeOrbitRadius => _orbitRadius;

  // ── Gravity rings ──────────────────────────────────────────────────────

  /// Each planet's pull as a ring of drifting grains at the edge of its
  /// field; while a home is being placed, the edge of the band that would
  /// capture it too; and the wake of whatever is orbiting, home or planet.
  /// Only the arcs in view are visited (gravity_ring_art.dart).
  void _renderGravityRings(
    Canvas canvas,
    double cx,
    double cy,
    double screenW,
    double screenH,
  ) {
    final view = Rect.fromLTWH(cx, cy, screenW, screenH);
    final band = Curves.easeInOut.transform(_captureBandFade.clamp(0.0, 1.0));
    // Pulled back, the grains would shrink below a pixel: keep them about
    // the size they are at the middle zoom.
    final grain = (0.72 / cameraZoom).clamp(1.0, 1.5);
    var seed = 0;
    for (final p in world_.planets) {
      seed++;
      final c = _wrappedRenderPos(p.position, cx, cy, screenW, screenH);
      final r = p.particleFieldRadius;
      _gravityRings.paint(
        canvas,
        centre: c,
        radius: r,
        view: view,
        color: p.color,
        t: _elapsed,
        style: GrainRingStyle.pull,
        seed: seed,
        sizeScale: grain,
      );
      if (band > 0.01) {
        // The pull reaches half as far again: loose matter through the
        // band and a thinner ring at its edge.
        _gravityRings.paint(
          canvas,
          centre: c,
          radius: r * 1.25,
          view: view,
          color: p.color,
          t: _elapsed,
          style: GrainRingStyle.captureWash,
          seed: seed + 50,
          sizeScale: grain,
          spread: r * 0.25,
          alpha: band,
        );
        _gravityRings.paint(
          canvas,
          centre: c,
          radius: r * 1.5,
          view: view,
          color: p.color,
          t: _elapsed,
          style: GrainRingStyle.captureEdge,
          seed: seed + 100,
          sizeScale: grain,
          alpha: band,
        );
      }
    }

    // The orbit, as the matter the orbiting body leaves behind it.
    final partner = _orbitalPartner;
    final home = homePlanet;
    if (partner != null && home != null && _orbitRadius > 0) {
      final centre = _wrappedRenderPos(
        _homeOrbitsPartner ? partner.position : home.position,
        cx,
        cy,
        screenW,
        screenH,
      );
      final bodyR = _homeOrbitsPartner ? home.visualRadius : partner.radius;
      _gravityRings.paint(
        canvas,
        centre: centre,
        radius: _orbitRadius,
        view: view,
        // The home's own light, cooled toward the HOME beacon's teal.
        color: _homeOrbitsPartner
            ? Color.lerp(home.blendedColor, const Color(0xFF00E5FF), 0.45)!
            : partner.color,
        t: _elapsed,
        style: GrainRingStyle.trail,
        seed: 977,
        sizeScale: grain,
        trailHead: _orbitAngle - bodyR * 0.6 / _orbitRadius,
        trailSpan: (1500 / _orbitRadius).clamp(0.1, 0.9),
      );
    }
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
    onHomePlanetBuilt?.call(homePlanet!);
    return null;
  }

  /// Restore a previously-saved home planet.
  void restoreHomePlanet(HomePlanet hp) {
    homePlanet = hp;
    _setupOrbitalRelationship(hp.position);
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

  // ── The planet itself ─────────────────────────────────────────────────────

  /// The warm glow round the home planet: the blurred disc it always had,
  /// as a gradient of the same shape (a blur pass per frame is the jank
  /// source in space; this looks the same and costs a plain fill).
  void _paintHomeAura(Canvas canvas, Offset pos, double vr, Color col) =>
      HomePlanetPaint.aura(
        canvas,
        pos,
        vr,
        _elapsed,
        homePlanet?.activeColor,
        col,
      );

  /// The home planet's body: the same glowing sphere in its color it has
  /// always been, now lit like the rest of space — a luminous rim of
  /// atmosphere, the far side falling into shadow, and a slow breath of
  /// light inside it.
  void _paintHomeSphere(Canvas canvas, Offset pos, double vr, Color col) =>
      HomePlanetPaint.sphere(
        canvas,
        pos,
        vr,
        _elapsed,
        homePlanet?.activeColor,
        col,
      );

  // ── Ammo color ────────────────────────────────────────────────────────────

  Color get _ammoColor => switch (activeAmmoId) {
    'storm_bolts' => const Color(0xFFFFEB3B),
    'plasma_bolts' => const Color(0xFFFFFFFF),
    'ice_shards' => const Color(0xFF00E5FF),
    'void_cannon' => const Color(0xFF9C27B0),
    _ => const Color(0xFF00E5FF),
  };

  // ══════════════════════════════════════════════════════════════════════════
  //  BEHIND-PLANET EFFECTS  (drawn before the planet body)
  // ══════════════════════════════════════════════════════════════════════════

  void _renderHomeEffectsBehind(
    Canvas canvas,
    Offset pos,
    double vr,
    Color col,
  ) {
    // Everything that sits (or passes) behind the body is drawn by the
    // shared planet art — see HomeEffectsArt.
    HomeEffectsArt.instance.paintBehind(
      canvas,
      pos,
      vr,
      _elapsed,
      activeCustomizations,
      customizationOptions,
      wake: ship.pos,
      sizeTier: homePlanet?.sizeTierIndex ?? 0,
    );
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

    // The four the player liked as they were keep their own painters.
    HomePlanetPaint.paintOriginals(
      canvas,
      pos,
      vr,
      t,
      activeCustomizations,
      customizationOptions,
    );
    // The rest — see HomeEffectsArt.
    HomeEffectsArt.instance.paintFront(
      canvas,
      pos,
      vr,
      t,
      activeCustomizations,
      customizationOptions,
      wake: ship.pos,
      sizeTier: homePlanet?.sizeTierIndex ?? 0,
      color: col,
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
