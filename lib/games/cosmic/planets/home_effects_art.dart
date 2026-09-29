part of 'planet_art.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  THE HOME PLANET'S CUSTOMIZATIONS — redrawn with what worked in space
//
//  The home planet itself keeps its own look (a glowing sphere in the
//  player's colour). What it wears is drawn here, with the techniques that
//  won out on the seventeen planets: rings of hundreds of grains on real
//  orbits (Cindrath's ring, the favourite), an ember corona (Pyrathis), a
//  feeding accretion disk (Nythralor), shaded moons (Aquathos), soft veils
//  and motes of light (Etherion). Every recipe keeps the options it always
//  had. Four recipes the player liked as they were — vine tendrils, steam
//  vents, phantom phase, electric field — keep their original painters in
//  cosmic_game_home_visuals.dart; everything in [handled] is drawn here.
//
//  Anything that goes round the planet is drawn in two halves, the far half
//  behind the body and the near half in front, so the planet sits inside it.
//  Loose matter parts round the ship when it flies through.
// ─────────────────────────────────────────────────────────────────────────────

class HomeEffectsArt {
  HomeEffectsArt._();

  static final HomeEffectsArt instance = HomeEffectsArt._();

  /// The recipes drawn here; the rest keep their original painters.
  static const handled = {
    'flame_ring',
    'crystal_spires',
    'dark_void',
    'radiant_halo',
    'ocean_mist',
    'blood_moon',
    'frozen_shell',
    'poison_cloud',
    'dust_storm',
    'lightning_rod',
    'lava_moat',
    'spirit_wisps',
    'mud_fortress',
    'natures_blessing',
    'orbiting_moon',
    'planetary_rings',
    'black_hole',
  };

  /// The plane things orbit in, and its tilt.
  static const _spin = SphereSpin(period: 200, roll: -0.25, lean: 0.3);
  static const _stormSpin = SphereSpin(period: 200, roll: 0.35, lean: 0.45);
  static const _haloSpin = SphereSpin(period: 200, roll: 0, lean: 0.55);

  static const _elements = [
    Color(0xFFFF5722), Color(0xFFEF6C00), Color(0xFFFFEB3B),
    Color(0xFF448AFF), Color(0xFF00E5FF), Color(0xFF90A4AE),
    Color(0xFF795548), Color(0xFF5D4037), Color(0xFFFFCC80),
    Color(0xFF1DE9B6), Color(0xFF81D4FA), Color(0xFF4CAF50),
    Color(0xFF9C27B0), Color(0xFF3F51B5), Color(0xFF4A148C),
    Color(0xFFFFE082), Color(0xFFD32F2F),
  ];

  // Built on first use, one per combination of options that shapes them.
  final Map<String, _ParticleRing> _rings = {};
  final Map<String, _AccretionDisk> _disks = {};
  final Map<String, _EmberCorona> _coronas = {};
  final _DotBatch _dots = _DotBatch(8);

  late final List<(double, double, double)> _shellPoints = () {
    final rng = Random(4201);
    return [
      for (var i = 0; i < 320; i++)
        () {
          final (x, y, z) = sphereAt(
            asin(rng.nextDouble() * 2 - 1),
            rng.nextDouble() * 2 * pi,
          );
          return (x, y, z);
        }(),
    ];
  }();

  // ── the two passes ────────────────────────────────────────────────────

  void paintBehind(
    Canvas c,
    Offset p,
    double r,
    double t,
    Set<String> active,
    Map<String, String> options, {
    Offset? wake,
    int sizeTier = 0,
  }) {
    String o(String id, String key, String fallback) =>
        options['$id.$key'] ?? fallback;
    if (active.contains('black_hole')) _blackHole(c, p, r, t, o, wake, false);
    if (active.contains('dark_void')) _darkVoid(c, p, r, t, o);
    if (active.contains('radiant_halo')) _radiantHalo(c, p, r, t, o, wake, false);
    if (active.contains('flame_ring')) _flameRing(c, p, r, t, o);
    if (active.contains('mud_fortress')) _mudFortress(c, p, r, t, o, wake, false);
    if (active.contains('lava_moat')) _lavaMoat(c, p, r, t, o, wake, false);
    if (active.contains('planetary_rings')) {
      _planetaryRings(c, p, r, t, o, wake, false);
    }
    if (active.contains('dust_storm')) _dustStorm(c, p, r, t, o, wake, false);
    if (active.contains('ocean_mist')) _mist(c, p, r, t, o, wake, false, poison: false);
    if (active.contains('poison_cloud')) _mist(c, p, r, t, o, wake, false, poison: true);
    if (active.contains('spirit_wisps')) _wisps(c, p, r, t, o, false);
    if (active.contains('natures_blessing')) _blessing(c, p, r, t, o, false);
    if (active.contains('frozen_shell')) _frozenShell(c, p, r, t, o, false);
    if (active.contains('orbiting_moon') && sizeTier >= 3) {
      _orbitingMoon(c, p, r, t, o, false);
    }
    if (active.contains('blood_moon')) _bloodMoon(c, p, r, t, o, false);
  }

  void paintFront(
    Canvas c,
    Offset p,
    double r,
    double t,
    Set<String> active,
    Map<String, String> options, {
    Offset? wake,
    int sizeTier = 0,
  }) {
    String o(String id, String key, String fallback) =>
        options['$id.$key'] ?? fallback;
    if (active.contains('crystal_spires')) _crystalSpires(c, p, r, t, o);
    if (active.contains('frozen_shell')) _frozenShell(c, p, r, t, o, true);
    if (active.contains('mud_fortress')) _mudFortress(c, p, r, t, o, wake, true);
    if (active.contains('lava_moat')) _lavaMoat(c, p, r, t, o, wake, true);
    if (active.contains('planetary_rings')) {
      _planetaryRings(c, p, r, t, o, wake, true);
    }
    if (active.contains('dust_storm')) _dustStorm(c, p, r, t, o, wake, true);
    if (active.contains('radiant_halo')) _radiantHalo(c, p, r, t, o, wake, true);
    if (active.contains('ocean_mist')) _mist(c, p, r, t, o, wake, true, poison: false);
    if (active.contains('poison_cloud')) _mist(c, p, r, t, o, wake, true, poison: true);
    if (active.contains('spirit_wisps')) _wisps(c, p, r, t, o, true);
    if (active.contains('natures_blessing')) _blessing(c, p, r, t, o, true);
    if (active.contains('orbiting_moon') && sizeTier >= 3) {
      _orbitingMoon(c, p, r, t, o, true);
    }
    if (active.contains('blood_moon')) _bloodMoon(c, p, r, t, o, true);
    if (active.contains('black_hole')) _blackHole(c, p, r, t, o, wake, true);
    if (active.contains('lightning_rod')) _lightningRod(c, p, r, t, o);
  }

  // ── shared ────────────────────────────────────────────────────────────

  /// A point on a circle of [rad] in [spin]'s equatorial plane, and whether
  /// it is on the near side.
  static (Offset, bool) _orbitAt(
    SphereSpin spin,
    Offset p,
    double rad,
    double a,
  ) {
    final m = spin.matrixAt(0);
    final x = cos(a), z = sin(a);
    return (
      Offset(p.dx + (m[0] * x + m[2] * z) * rad,
          p.dy - (m[3] * x + m[5] * z) * rad),
      m[6] * x + m[8] * z > 0,
    );
  }

  static double _position(String Function(String, String, String) o,
          String id) =>
      switch (o(id, 'position', 'Mid')) {
        'Close' => 1.35,
        'Outer' => 2.3,
        _ => 1.75,
      };

  /// A ring of grains in [spin]'s plane with one soft lane, built once per
  /// shape.
  _ParticleRing _ring(
    String key, {
    required SphereSpin spin,
    required double centre,
    required double width,
    required double peak,
    required Color lane,
    required Color dim,
    required Color bright,
    int count = 360,
    double grainSize = 0.005,
    double brightCut = 0.55,
    double speed = 0.14,
    List<(double, double, double)>? lanes,
  }) =>
      _rings.putIfAbsent(key, () {
        final shape = lanes ?? [(centre, width, peak)];
        final reach = shape.fold(0.0, (m, l) => max(m, l.$1 + l.$2 * 2.5));
        final (stops, alphas) = _ParticleRing.laneProfile(shape, reach);
        return _ParticleRing(
          Random(key.hashCode),
          spin: spin,
          lanes: [for (final (c, w, _) in shape) (c, w, 1.0)],
          laneColor: lane,
          laneReach: reach,
          laneStops: stops,
          laneAlphas: alphas,
          dim: dim,
          bright: bright,
          count: count,
          clumps: 6,
          perClump: 14,
          grainSize: grainSize,
          brightCut: brightCut,
          speed: speed,
        );
      });

  /// A moon: a shaded sphere with soft seas and low craters, lit from the
  /// upper left like everything in space.
  static void _moonBody(
    Canvas c,
    Offset at,
    double mr,
    Color lit,
    Color base,
    Color dark,
  ) {
    c.save();
    c.clipPath(Path()..addOval(Rect.fromCircle(center: at, radius: mr)));
    c.drawCircle(
      at,
      mr,
      Paint()
        ..shader = ui.Gradient.radial(
          at + Offset(-mr * 0.32, -mr * 0.32),
          mr * 1.7,
          [lit, base, dark],
          const [0.0, 0.5, 1.0],
        ),
    );
    for (final (dx, dy, k) in const [
      (-0.22, -0.18, 0.34),
      (0.18, 0.08, 0.26),
      (-0.05, 0.34, 0.2),
    ]) {
      _softCircle(c, at + Offset(dx * mr, dy * mr), mr * k,
          Color.lerp(base, dark, 0.5)!.withValues(alpha: 0.45), mr * 0.08);
    }
    // The far side into shadow.
    c.drawCircle(
      at,
      mr,
      Paint()
        ..shader = ui.Gradient.radial(
          at + Offset(-mr * 0.55, -mr * 0.6),
          mr * 2.2,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0xFF05060C).withValues(alpha: 0.55),
            const Color(0xFF05060C).withValues(alpha: 0.85),
          ],
          const [0.0, 0.4, 0.66, 0.86],
        ),
    );
    c.restore();
    final outer = mr * 1.1;
    c.drawCircle(
      at,
      outer,
      Paint()
        ..shader = ui.Gradient.radial(at, outer, [
          lit.withValues(alpha: 0),
          lit.withValues(alpha: 0.25),
          lit.withValues(alpha: 0),
        ], [0.84, mr / outer, 1.0]),
    );
  }

  // ── the effects ───────────────────────────────────────────────────────

  /// PREMIUM. The planet becomes the eye of a feeding black hole: a disk of
  /// burning matter wheeling round it, streams spiralling in, sunk in
  /// Nythralor's layered violet glow — and the far side of the disk seen
  /// bent up over the top of the planet, the way light comes round a black
  /// hole, so the planet sits inside a crown of its own disk.
  void _blackHole(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final wide = o('black_hole', 'disk', 'Wide') == 'Wide';
    final speed = switch (o('black_hole', 'spin', 'Normal')) {
      'Slow' => 0.3,
      'Fast' => 0.9,
      _ => 0.55,
    };
    final outer = wide ? 3.1 : 2.3;
    final disk = _disks.putIfAbsent(
      'bh:$wide:$speed',
      () => _AccretionDisk(
        Random(9011),
        motes: wide ? 900 : 700,
        infall: 90,
        inner: 1.3,
        outer: outer,
        speed: speed,
        flat: 0.3,
        grain: 1.6,
        lensed: true,
      ),
    );
    if (front) {
      disk.paintLensed(c, p, r, t, wake: wake);
      disk.paintMatter(c, p, r, t, front: true, wake: wake);
      return;
    }
    // Space darkening round it.
    _softCircle(c, p, r * outer, const Color(0xFF000000).withValues(alpha: 0.4),
        r * 0.6);
    // Nythralor's disk glow: layered violets, flattened into the plane.
    c.save();
    c.translate(p.dx, p.dy);
    c.scale(1.0, disk.flat);
    for (var i = 3; i >= 0; i--) {
      final rad = r * (1.5 + (outer - 1.5) * (0.35 + i * 0.2));
      c.drawCircle(
        Offset.zero,
        rad,
        Paint()
          ..shader = ui.Gradient.radial(Offset.zero, rad, [
            Color.lerp(const Color(0xFF7A3AD0), const Color(0xFF4A148C), i / 3)!
                .withValues(alpha: 0.13 + 0.04 * sin(t * 1.5 + i)),
            Color.lerp(const Color(0xFF7A3AD0), const Color(0xFF4A148C), i / 3)!
                .withValues(alpha: 0.08),
            const Color(0xFF4A148C).withValues(alpha: 0),
          ], const [0.0, 0.7, 1.0]),
      );
    }
    c.restore();
    disk.paintGlow(c, p, r, t, alpha: 0.45);
    disk.paintMatter(c, p, r, t, front: false, wake: wake);
  }

  /// Dark matter drawn in from all round: layers of purple dark, and motes
  /// spiralling into the planet.
  void _darkVoid(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o) {
    final layers = switch (o('dark_void', 'layers', 'Normal')) {
      'Thin' => 2,
      'Deep' => 6,
      _ => 4,
    };
    for (var i = 0; i < layers; i++) {
      _softCircle(c, p, r * (1.6 + i * 0.4),
          const Color(0xFF4A148C).withValues(alpha: 0.05 + i * 0.008), r * 0.4);
    }
    _dots.clear();
    final count = 40 * layers;
    for (var i = 0; i < count; i++) {
      final seed = i * 7919;
      final a0 = (seed % 628) / 100.0;
      final r0 = 2.0 + (seed % 97) / 97.0 * 1.4;
      final fall = 5.0 + (seed % 53) / 53.0 * 4.0;
      final life = (t / fall + (seed % 101) / 101.0) % 1.0;
      final rad = r0 - (r0 - 0.98) * pow(life, 1.3);
      final a = a0 + life * 2.6;
      final fade = (life < 0.15 ? life / 0.15 : 1.0) * (1 - pow(life, 5));
      if (fade < 0.3) continue;
      _dots.add(life < 0.5 ? 0 : 1, p.dx + cos(a) * rad * r,
          p.dy + sin(a) * rad * r);
    }
    final d = max(r * 0.012, 1.6);
    _dots.draw(c, 0, d * 2.4, const Color(0xFF8E58E0).withValues(alpha: 0.12));
    _dots.draw(c, 0, d, const Color(0xFFB08AF0).withValues(alpha: 0.7));
    _dots.draw(c, 1, d * 2.4, const Color(0xFFC88CFA).withValues(alpha: 0.14));
    _dots.draw(c, 1, d * 0.9, const Color(0xFFF2E2FF).withValues(alpha: 0.85));
  }

  /// A golden halo: a ring of light motes round the planet, over a soft
  /// golden lane.
  void _radiantHalo(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final glow = switch (o('radiant_halo', 'glow', 'Normal')) {
      'Subtle' => 0.5,
      'Blinding' => 1.0,
      _ => 0.75,
    };
    final at = _position(o, 'radiant_halo');
    if (!front) {
      _softCircle(c, p, r * 1.25,
          const Color(0xFFFFE9A8).withValues(alpha: 0.12 * glow), r * 0.3);
    }
    _ring(
      'halo:$at',
      spin: _haloSpin,
      centre: at,
      width: 0.07,
      peak: 0.4,
      lane: const Color(0xFFFFE9A8),
      dim: const Color(0xFFE8C060).withValues(alpha: 0.7),
      bright: const Color(0xFFFFFBE8),
      count: 300,
      speed: 0.25,
    ).paint(c, p, r, t, front: front, wake: wake, alpha: glow);
  }

  /// Pyrathis' ember corona, round the home planet.
  void _flameRing(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o) {
    final (embers, alpha) = switch (o('flame_ring', 'intensity', 'Normal')) {
      'Dim' => (300, 0.7),
      'Bright' => (600, 1.0),
      _ => (440, 0.85),
    };
    final pace = switch (o('flame_ring', 'speed', 'Normal')) {
      'Slow' => 0.65,
      'Fast' => 1.5,
      _ => 1.0,
    };
    _coronas
        .putIfAbsent('flame:$embers',
            () => _EmberCorona(Random(771), sources: 32, embers: embers,
                reachMin: 0.25, reachSpan: 0.6))
        .paint(c, p, r, t, alpha: alpha, pace: pace);
  }

  /// A rampart of mud clods hugging the planet, wet glints on them.
  void _mudFortress(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final w = switch (o('mud_fortress', 'thickness', 'Normal')) {
      'Thin' => 0.05,
      'Thick' => 0.12,
      _ => 0.08,
    };
    _ring(
      'mud:$w',
      spin: _spin,
      centre: 1.1 + w,
      width: w,
      peak: 0.55,
      lane: const Color(0xFF5A4630),
      dim: const Color(0xFF4A3622),
      bright: const Color(0xFFCDB68C).withValues(alpha: 0.85),
      count: 460,
      grainSize: 0.0075,
      brightCut: 0.75,
      speed: 0.05,
    ).paint(c, p, r, t, front: front, wake: wake);
  }

  /// A moat of lava in the equatorial plane: a molten lane, hot embers on
  /// their orbits over it.
  void _lavaMoat(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final w = switch (o('lava_moat', 'width', 'Normal')) {
      'Thin' => 0.05,
      'Wide' => 0.13,
      _ => 0.08,
    };
    _ring(
      'lava:$w',
      spin: _spin,
      centre: 1.3 + w,
      width: w,
      peak: 0.5,
      lane: const Color(0xFFE8521A),
      dim: const Color(0xFFB8360C).withValues(alpha: 0.9),
      bright: const Color(0xFFFFC870),
      count: 420,
      brightCut: 0.2,
      speed: 0.2,
    ).paint(c, p, r, t,
        front: front, wake: wake, alpha: 0.85 + 0.15 * sin(t * 1.2));
  }

  /// Rings of grains on their orbits — Cindrath's ring, styled.
  void _planetaryRings(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final count = int.tryParse(o('planetary_rings', 'count', '2')) ?? 2;
    final style = o('planetary_rings', 'style', 'Icy');
    final lanes = switch (count) {
      1 => const [(1.75, 0.16, 0.22)],
      3 => const [(1.5, 0.08, 0.22), (1.82, 0.12, 0.24), (2.15, 0.07, 0.16)],
      _ => const [(1.55, 0.09, 0.22), (1.92, 0.14, 0.24)],
    };
    final (lane, dim, bright) = switch (style) {
      'Rocky' => (
          const Color(0xFFC8B090),
          const Color(0xFFA89070).withValues(alpha: 0.6),
          const Color(0xFFF0E2C8),
        ),
      'Prismatic' => (
          const Color(0xFFE0C8FF),
          const Color(0xFFD8C8FF).withValues(alpha: 0.6),
          const Color(0xFFFFFFFF),
        ),
      _ => (
          const Color(0xFFCFEFFA),
          const Color(0xFFB8DCEC).withValues(alpha: 0.6),
          const Color(0xFFFFFFFF),
        ),
    };
    // Prismatic lanes shimmer slowly through the spectrum.
    final tint = style == 'Prismatic'
        ? HSVColor.fromAHSV(1, (t * 18) % 360, 0.35, 1).toColor()
        : null;
    _ring(
      'rings:$count:$style',
      spin: _spin,
      centre: 0,
      width: 0,
      peak: 0,
      lane: lane,
      dim: dim,
      bright: bright,
      count: 380,
      lanes: lanes,
    ).paint(c, p, r, t, front: front, wake: wake, laneTint: tint);
  }

  /// A dust storm: a thick band of grains whirling round, tilted.
  void _dustStorm(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front) {
    final count = switch (o('dust_storm', 'particles', 'Normal')) {
      'Few' => 220,
      'Swarm' => 620,
      _ => 400,
    };
    final at = _position(o, 'dust_storm');
    _ring(
      'storm:$count:$at',
      spin: _stormSpin,
      centre: at,
      width: 0.24,
      peak: 0.12,
      lane: const Color(0xFFE8C08A),
      dim: const Color(0xFFD8B884).withValues(alpha: 0.6),
      bright: const Color(0xFFFFF0D4),
      count: count,
      speed: 0.5,
    ).paint(c, p, r, t, front: front, wake: wake);
  }

  /// Mist (or a poison cloud): soft veils drifting round the planet and a
  /// haze of fine drops in them.
  void _mist(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, Offset? wake, bool front,
      {required bool poison}) {
    final id = poison ? 'poison_cloud' : 'ocean_mist';
    final veils = poison
        ? switch (o(id, 'spread', 'Normal')) {
            'Tight' => 6,
            'Wide' => 14,
            _ => 9,
          }
        : switch (o(id, 'density', 'Normal')) {
            'Light' => 5,
            'Heavy' => 12,
            _ => 8,
          };
    final at = _position(o, id);
    final colA = poison ? const Color(0xFF7CE04A) : const Color(0xFFB8DCF6);
    final colB = poison ? const Color(0xFF9A5AC8) : const Color(0xFF8CC4EC);
    for (var i = 0; i < veils; i++) {
      final a = i / veils * 2 * pi + t * 0.06 * (poison ? -1 : 1);
      final (pos, near) = _orbitAt(_spin, p, r * at * (1 + 0.08 * sin(i * 2.1)), a);
      if (near != front) continue;
      _softCircle(
        c,
        pos,
        r * (0.28 + 0.1 * sin(t * 0.3 + i)),
        (i.isEven ? colA : colB)
            .withValues(alpha: 0.1 + 0.04 * sin(t * 0.5 + i * 1.3)),
        r * 0.14,
      );
    }
    _ring(
      '$id:$at',
      spin: _spin,
      centre: at,
      width: 0.2,
      peak: 0.05,
      lane: colA,
      dim: colB.withValues(alpha: 0.5),
      bright: colA.withValues(alpha: 0.9),
      count: 220,
      speed: poison ? -0.12 : 0.12,
    ).paint(c, p, r, t, front: front, wake: wake);
  }

  /// Ghost-lights: glowing orbs on their own tilted paths, bobbing, each
  /// trailing a few fainter motes.
  void _wisps(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, bool front) {
    final n = switch (o('spirit_wisps', 'count', 'Some')) {
      'Few' => 4,
      'Many' => 12,
      _ => 7,
    };
    final at = _position(o, 'spirit_wisps');
    _dots.clear();
    for (var i = 0; i < n; i++) {
      final tilt = (i * 0.9) % pi;
      final speed = 0.25 + (i % 3) * 0.08;
      for (var k = 0; k < 4; k++) {
        final a = i / n * 2 * pi + (t - k * 0.25) * speed;
        final x = cos(a) * r * at, y = sin(a) * r * at * 0.4;
        final near = sin(a) > 0;
        if (near != front) continue;
        final pos = p +
            Offset(x * cos(tilt) - y * sin(tilt), x * sin(tilt) + y * cos(tilt)) +
            Offset(0, sin(t * 1.3 + i * 2) * r * 0.05);
        if (k == 0) {
          _softCircle(c, pos, r * 0.06,
              const Color(0xFF7FF5E8).withValues(alpha: 0.3), r * 0.05);
          _dots.add(0, pos.dx, pos.dy);
        } else {
          _dots.add(k == 1 ? 1 : 2, pos.dx, pos.dy);
        }
      }
    }
    final d = max(r * 0.03, 2.5);
    _dots.draw(c, 0, d, const Color(0xFFEFFFFC));
    _dots.draw(c, 1, d * 0.55, const Color(0xFF7FF5E8).withValues(alpha: 0.7));
    _dots.draw(c, 2, d * 0.4, const Color(0xFF7FF5E8).withValues(alpha: 0.4));
  }

  /// Seventeen lights, one of every element, going round.
  void _blessing(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, bool front) {
    final bright = switch (o('natures_blessing', 'brightness', 'Normal')) {
      'Dim' => 0.55,
      'Bright' => 1.0,
      _ => 0.8,
    };
    final at = _position(o, 'natures_blessing');
    for (var i = 0; i < _elements.length; i++) {
      final a = i / _elements.length * 2 * pi + t * 0.12;
      final (pos, near) = _orbitAt(_spin, p, r * at, a);
      if (near != front) continue;
      final col = _elements[i];
      final twinkle = 0.75 + 0.25 * sin(t * 2 + i * 1.3);
      final sz = max(r * 0.04, 3.0);
      _softCircle(c, pos, sz * 1.6,
          col.withValues(alpha: 0.35 * bright * twinkle), sz * 0.8);
      c.drawCircle(pos, sz * 0.55,
          Paint()..color = Color.lerp(col, const Color(0xFFFFFFFF), 0.45)!
              .withValues(alpha: bright));
    }
  }

  /// A shell of ice crystals round the whole planet, glinting as it turns.
  void _frozenShell(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, bool front) {
    final k = switch (o('frozen_shell', 'thickness', 'Medium')) {
      'Thin' => 1.06,
      'Thick' => 1.16,
      _ => 1.1,
    };
    final rr = r * k;
    final view = SphereView(p, rr, const SphereSpin(period: 110).matrixAt(t));
    _dots.clear();
    for (var i = 0; i < _shellPoints.length; i++) {
      final (x, y, z) = _shellPoints[i];
      final sp = view.project(x, y, z);
      if ((sp.depth > 0) != front) continue;
      final lit = sin(t * 2.6 + i * 1.7) > 0.8;
      _dots.add(lit ? 1 : 0, sp.offset.dx, sp.offset.dy);
    }
    final d = max(r * 0.012, 1.6);
    _dots.draw(c, 0, d, const Color(0xFFBFEFFF).withValues(alpha: front ? 0.45 : 0.6));
    _dots.draw(c, 1, d * 2.6, const Color(0xFFE8FBFF).withValues(alpha: 0.2));
    _dots.draw(c, 1, d * 1.2, const Color(0xFFFFFFFF));
    if (front) {
      _limb(c, p, rr, const Color(0xFFCFF6FF), alpha: 0.35, inner: 0.9,
          outer: 1.06);
    }
  }

  void _orbitingMoon(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, bool front) {
    final size = switch (o('orbiting_moon', 'size', 'Medium')) {
      'Small' => 0.12,
      'Large' => 0.25,
      _ => 0.18,
    };
    final speed = switch (o('orbiting_moon', 'speed', 'Normal')) {
      'Slow' => 0.12,
      'Fast' => 0.45,
      _ => 0.24,
    };
    final dist = switch (o('orbiting_moon', 'distance', 'Mid')) {
      'Close' => 1.5,
      'Far' => 2.6,
      _ => 1.95,
    };
    final (pos, near) = _orbitAt(_spin, p, r * dist, t * speed);
    if (near != front) return;
    _moonBody(c, pos, r * size, const Color(0xFFDDE2E9),
        const Color(0xFFB6BEC9), const Color(0xFF7C8592));
  }

  void _bloodMoon(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o, bool front) {
    final pulse = switch (o('blood_moon', 'pulse', 'Normal')) {
      'Gentle' => 0.35,
      'Intense' => 1.0,
      _ => 0.65,
    };
    final size = switch (o('blood_moon', 'size', 'Medium')) {
      'Small' => 0.1,
      'Large' => 0.22,
      _ => 0.15,
    };
    final dist = switch (o('blood_moon', 'distance', 'Mid')) {
      'Close' => 1.4,
      'Far' => 2.4,
      _ => 1.8,
    };
    // Opposite the grey moon, so both can be worn.
    final (pos, near) = _orbitAt(_spin, p, r * dist, t * 0.18 + pi);
    if (near != front) return;
    final beat = BloodPlanetArt._beat(t) * pulse;
    final mr = r * size * (1 + 0.05 * beat);
    _softCircle(c, pos, mr * 1.6,
        const Color(0xFFFF3A3A).withValues(alpha: 0.12 + 0.3 * beat), mr * 0.6);
    _moonBody(
      c,
      pos,
      mr,
      Color.lerp(const Color(0xFFE85A60), const Color(0xFFFF8A8A), beat)!,
      Color.lerp(const Color(0xFFA01E28), const Color(0xFFE23A44), beat)!,
      const Color(0xFF3A0408),
    );
  }

  /// Crystals standing up off the limb in clusters: translucent, each lit
  /// on the face toward the light, glowing at the root, one now and then
  /// catching a glint.
  void _crystalSpires(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o) {
    final height = switch (o('crystal_spires', 'height', 'Medium')) {
      'Short' => 0.6,
      'Tall' => 1.4,
      _ => 1.0,
    };
    final clusters = switch (o('crystal_spires', 'density', 'Normal')) {
      'Sparse' => 3,
      'Dense' => 7,
      _ => 5,
    };
    final lit = Path(), dark = Path(), glint = Path();
    for (var i = 0; i < clusters; i++) {
      final a0 = i / clusters * 2 * pi + 0.4 + t * 0.01;
      final root = p + Offset(cos(a0), sin(a0)) * (r * 0.95);
      _softCircle(c, root, r * 0.14,
          const Color(0xFF5CF5D0).withValues(alpha: 0.28), r * 0.08);
      for (var j = -1; j <= 1; j++) {
        final a = a0 + j * 0.09;
        final dir = Offset(cos(a + j * 0.25), sin(a + j * 0.25));
        final n = Offset(-dir.dy, dir.dx);
        final h = r * 0.34 * height * (j == 0 ? 1 : 0.62);
        final w = max(r * 0.045, 3.0) * (j == 0 ? 1 : 0.8);
        final base = p + Offset(cos(a), sin(a)) * (r * 0.9);
        final shoulder = base + dir * (h * 0.78);
        final tip = base + dir * h;
        final leftLit = (n.dx * -0.7 + n.dy * -0.7) > 0;
        final l = Path()
          ..moveTo(base.dx + n.dx * w, base.dy + n.dy * w)
          ..lineTo(shoulder.dx + n.dx * w, shoulder.dy + n.dy * w)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base.dx, base.dy)
          ..close();
        final rt = Path()
          ..moveTo(base.dx - n.dx * w, base.dy - n.dy * w)
          ..lineTo(shoulder.dx - n.dx * w, shoulder.dy - n.dy * w)
          ..lineTo(tip.dx, tip.dy)
          ..lineTo(base.dx, base.dy)
          ..close();
        (leftLit ? lit : dark).addPath(l, Offset.zero);
        (leftLit ? dark : lit).addPath(rt, Offset.zero);
        if (sin(t * 1.1 + i * 2.3 + j) > 0.93) {
          glint.addPath(leftLit ? l : rt, Offset.zero);
        }
      }
    }
    c.drawPath(dark, Paint()..color = const Color(0xFF1E8A74).withValues(alpha: 0.85));
    c.drawPath(lit, Paint()..color = const Color(0xFFA8F5E2).withValues(alpha: 0.85));
    c.drawPath(glint, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7));
  }

  /// Bolts striking the planet out of the dark, Voltara's way: a faint wide
  /// glow under a lit core, a flash where they land.
  void _lightningRod(Canvas c, Offset p, double r, double t,
      String Function(String, String, String) o) {
    final rate = switch (o('lightning_rod', 'frequency', 'Normal')) {
      'Rare' => 0.35,
      'Frequent' => 1.4,
      _ => 0.7,
    };
    _softCircle(c, p, r * 1.25,
        const Color(0xFFFFEB3B).withValues(alpha: 0.04 + 0.02 * sin(t * 5)),
        r * 0.2);
    final beat = (t * rate).floor();
    final phase = t * rate - beat;
    final rng = Random(beat * 7349);
    if (rng.nextDouble() > 0.8 || phase > 0.35) return;
    final f = exp(-phase * 10);
    final a = rng.nextDouble() * 2 * pi;
    final from = p + Offset(cos(a), sin(a)) * (r * 2.1);
    final land = a + (rng.nextDouble() - 0.5) * 0.5;
    final to = p + Offset(cos(land), sin(land)) * (r * 0.98);
    final bolt = Path()..moveTo(from.dx, from.dy);
    final d = to - from;
    final side = Offset(-d.dy, d.dx) / max(1.0, d.distance);
    for (var k = 1; k <= 7; k++) {
      final q = k == 7
          ? to
          : from + d * (k / 7) + side * ((rng.nextDouble() - 0.5) * r * 0.22);
      bolt.lineTo(q.dx, q.dy);
    }
    _softStroke(c, bolt, const Color(0xFFFFEB3B).withValues(alpha: 0.4 * f),
        max(r * 0.02, 2), 5);
    c.drawPath(
      bolt,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = max(r * 0.008, 1.2)
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.9 * f),
    );
    _softCircle(c, to, r * 0.12, const Color(0xFFFFF59D).withValues(alpha: 0.6 * f),
        r * 0.08);
  }
}
