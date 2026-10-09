part of 'grain_field.dart';

// The Glass Dunes, through the day.
//
// A desert of sharp-crested dunes under the phone's own sky: flat-topped
// buttes far off in the haze, two ranges of dunes stepping nearer, a range of
// great dunes with the ruins of something half buried in them, and the sand
// floor the creatures stand on. The floor is loose: its ripples are grains,
// and a finger ploughs a furrow through them, banking the sand up either side
// and throwing a little into the air, and the wind fills it back in over the
// next few seconds. Sand streams off the crests of the great dunes, harder in
// a gust; on a clear afternoon a dust devil wanders along them. The sand is
// part glass — it glitters under the moon — and after a sandstorm, where the
// storm's lightning struck, the whole floor glitters.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — buttes in the haze and two far dune ranges
//   layer3  — the great dunes, their ruins, spindrift, the dust devil
//   layer4  — the sand floor, its rocks and pillars, scrub, the loose sand
//   layer5  — the lips of near dunes, nearest of all, with scrub on them
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   far grades   r = haze, b = haze × how low (horizon-colored), g = fleck
//   near grades  r = haze, b = shade, g = fleck

class DunesField extends _GrainField {
  DunesField();

  static const far = SceneLayer.layer2;
  static const dunes = SceneLayer.layer3;
  static const floor = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gButtes = 0, _gFarSand = 1, _gSand = 2, _gFloor = 3;
  static const _gStone = 4, _gRock = 5, _gLip = 6;

  /// Daylight colors of the land; the hour's ambient light multiplies them.
  static const _albedo = <int, Color>{
    _gButtes: Color(0xFF8E6656),
    _gFarSand: Color(0xFFC29C74),
    _gSand: Color(0xFFD4A978),
    _gFloor: Color(0xFFDAB07C),
    _gStone: Color(0xFFB4A48C),
    _gRock: Color(0xFFB07E62),
    _gLip: Color(0xFFC89C6C),
  };

  /// How deep the sandstorm's dust buries each grade, at its thickest.
  static const _stormBury = <int, double>{
    _gButtes: 0.95,
    _gFarSand: 0.85,
    _gSand: 0.55,
    _gFloor: 0.3,
    _gStone: 0.5,
    _gRock: 0.3,
    _gLip: 0.15,
  };

  @override
  List<(double, _Light)> get _keys => _dunesKeys;

  @override
  int get _starCount => 260;

  @override
  double get _starDepth => 0.54;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 1.0,
    dunes => 0.95,
    _ => 0.85,
  };

  /// The live sand's colors, shade to lit, for the hour.
  List<Color> _sandTones = const [
    Color(0xFF000000),
    Color(0xFF000000),
    Color(0xFF000000),
    Color(0xFF000000),
  ];

  @override
  void _buildGrades(_Light l) {
    final hazeHigh = l.skyAt(0.44), hazeLow = l.skyAt(0.585);
    final st = storm;
    Color sil(int g) {
      final a = _albedo[g]!;
      var s = Color.from(
        alpha: 1,
        red: a.r * l.ambient.r,
        green: a.g * l.ambient.g,
        blue: a.b * l.ambient.b,
      );
      // The storm's dust standing between the eye and it.
      if (st > 0) s = Color.lerp(s, hazeLow, st * (_stormBury[g] ?? 0))!;
      return s;
    }

    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.9 + l.rim.r * l.rimStrength * k,
      s.g * 0.9 + l.rim.g * l.rimStrength * k,
      s.b * 0.9 + l.rim.b * l.rimStrength * k,
    );
    for (final g in [_gButtes, _gFarSand]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeHigh, s),
        g: fleck(s, 0.3),
        b: fieldDiff(hazeLow, hazeHigh),
      );
    }
    for (final g in [_gSand, _gFloor, _gStone, _gRock, _gLip]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.45),
        b: fieldScale(s, -0.7),
      );
    }

    // The loose sand on the floor: the floor's own color in shade, in half
    // light, lit, and catching the rim light along a ripple's crest.
    final s = sil(_gFloor);
    Color k(double f) => Color.from(
      alpha: 1,
      red: (s.r * f).clamp(0.0, 1.0),
      green: (s.g * f).clamp(0.0, 1.0),
      blue: (s.b * f).clamp(0.0, 1.0),
    );
    final lit = k(1.07);
    _sandTones = [
      k(0.8),
      k(0.93),
      lit,
      Color.lerp(lit, l.rim, (0.2 + 0.5 * l.rimStrength).clamp(0.0, 0.7))!,
    ];
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// Ground points on the great dunes: the dunes rise to meet each.
  Iterable<SpawnPoint> get _duneStands =>
      _spawns.where((p) => !p.aloft && p.anchor == dunes && !_shares(p));

  /// Ground points on the floor too high to stand in the sand: each gets a
  /// rock of wind-cut sandstone to stand on.
  Iterable<SpawnPoint> get _perched => _spawns.where(
    (p) =>
        !p.aloft &&
        p.anchor == floor &&
        !_shares(p) &&
        _feet(p) < _groundLine(_spawnX(p)) - 6 * _u,
  );

  @override
  double? perchFor(String spawnId) {
    for (final p in _perched) {
      if (p.id == spawnId) return _feet(p);
    }
    for (final p in _spawns) {
      if (p.id == spawnId && _shares(p)) return _sharedPerch(p);
    }
    return null;
  }

  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    switch (layer) {
      case dunes:
        return (top: _dune(x) + 3 * _u, rest: _dune(x) + 16 * _u);
      case floor:
        // On a rock: its flat top.
        for (final p in _outcrops) {
          final o = _outcropShape(p);
          if (_loopDelta(x, o.x, floor).abs() < o.w * 0.34) {
            return (top: o.top + 2 * _u, rest: o.top);
          }
        }
        return (top: _groundLine(x) + 2 * _u, rest: _groundLine(x) + 0.08 * _h);
      default:
        return null;
    }
  }

  // ── The land (layer-local, in units of the current height) ──────────────

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));
  double _nd(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(dunes));
  double _nl(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(floor));

  /// Share of a dune that is its windward back; the rest is its slipface,
  /// falling steeply to the right.
  static const _windward = 0.68;

  /// A dune range's profile at [x]: 0 in its troughs, up to 1 at a crest —
  /// a long convex back on the windward side, a sharp crest, and a steep
  /// slipface falling away from it. Dunes [wave] apart, give or take, each
  /// its own height.
  double _duneProfile(double x, double wave, int seed, double period) {
    final (i, p, lam) = _dunePhase(x, wave, seed, period);
    final amp = 0.5 + 0.5 * fieldHash(i, seed);
    if (p < _windward) {
      final f = p / _windward;
      return amp * math.pow(math.sin(f * math.pi / 2), 1.5);
    }
    final g = (p - _windward) / (1 - _windward);
    return amp * math.pow(1 - g, 1.7);
  }

  /// Which dune of a range [x] is in (counted round the loop), how far
  /// through it (0 trough, [_windward] crest, 1 the next trough) and how
  /// wide the dunes are.
  (int, double, double) _dunePhase(
    double x,
    double wave,
    int seed,
    double period,
  ) {
    final n = period > 0 ? math.max(1, (period / wave).round()) : 0;
    final lam = n > 0 ? period / n : wave;
    final wob = fieldLoopNoise(x, lam * 2.3, seed + 5, period) * 0.16 * lam;
    final u = (x + wob) / lam;
    final i = u.floor();
    final k = n > 0 ? i % n : i;
    return (k, u - i, lam);
  }

  /// The crests of a range across a layer [w] wide: (x, dune).
  List<(double, int)> _crests(double w, double wave, int seed, double period) {
    final (_, _, lam) = _dunePhase(0, wave, seed, period);
    final out = <(double, int)>[];
    for (var i = -1; i * lam < w + lam; i++) {
      // Solve x + wob(x) = (i + windward)·λ, a step or two of iteration.
      final target = (i + _windward) * lam;
      var x = target;
      for (var j = 0; j < 3; j++) {
        x =
            target -
            fieldLoopNoise(x, lam * 2.3, seed + 5, period) * 0.16 * lam;
      }
      out.add((x, n0(i, period, lam)));
    }
    return out;
  }

  static int n0(int i, double period, double lam) {
    if (period <= 0) return i;
    final n = math.max(1, (period / lam).round());
    return ((i % n) + n) % n;
  }

  double _farRange(int i, double x) => switch (i) {
    0 =>
      _h *
          (0.585 -
              0.034 * _duneProfile(x, 150, 21, _period(far)) -
              0.008 * _nf(x, 260, 22)),
    _ =>
      _h *
          (0.622 -
              0.04 * _duneProfile(x, 190, 23, _period(far)) -
              0.008 * _nf(x, 300, 24)),
  };

  double _duneBase(double x) =>
      _h *
      (0.715 -
          0.085 * _duneProfile(x, 330, 31, _period(dunes)) -
          0.012 * _nd(x, 520, 32) -
          0.003 * _nd(x, 41, 33));

  /// The great dunes, lifted wherever a creature stands on them so their
  /// crest is always above its feet — never a creature against open sky.
  double _dune(double x) {
    var y = _duneBase(x);
    for (final p in _duneStands) {
      final sx = _spawnX(p);
      final need = _duneBase(sx) - (_feet(p) - 9 * _u);
      if (need <= 0) continue;
      y -= need * math.exp(-math.pow(_loopDelta(x, sx, dunes) / 150, 2));
    }
    return y;
  }

  double _groundLine(double x) =>
      _h * (0.808 + 0.014 * _nl(x, 280, 41) + 0.005 * _nl(x, 80, 42));

  // ── Weather ──────────────────────────────────────────────────────────────

  /// The Dunes' weather: the sandstorm.
  double get storm => weatherKind == WeatherKind.sandstorm ? weather : 0;

  @override
  double get _windScale => 1 + 2.2 * storm;

  @override
  double get _veil => 0.92 * storm;

  @override
  double get _weatherKey => (storm * 1000).roundToDouble();

  /// The hour's light in a sandstorm: the sky thick with dust, lit through
  /// it to an ochre glow by day and a dull brown by night; the light comes
  /// from everywhere, and nothing far off is there at all.
  @override
  _Light _weathered(_Light l) {
    final s = storm;
    if (s <= 0.001) return l;
    Color dust(Color c, double dark) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF1E140D),
        const Color(0xFFD2A26C),
        g,
      )!;
      return Color.from(
        alpha: 1,
        red: to.r * dark,
        green: to.g * dark,
        blue: to.b * dark,
      );
    }

    final k = 0.85 * s;
    Color thick(Color c, double dark) => Color.lerp(c, dust(c, dark), k)!;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) thick(c, 0.9)],
      ambient: thick(l.ambient, 0.78),
      rim: Color.lerp(l.rim, const Color(0xFFE8C08C), s)!,
      rimStrength: l.rimStrength * (1 - 0.75 * s),
      floor: l.floor + (math.max(0.75, l.floor) - l.floor) * s,
      glow: l.glow * (1 - 0.7 * s),
      stars: l.stars * (1 - 0.95 * s),
      cloudTop: thick(l.cloudTop, 0.8),
      cloudBottom: thick(l.cloudBottom, 0.85),
      cloudGlint: l.cloudGlint,
      grass: [for (final c in l.grass) thick(c, 0.75)],
      mote: Color.lerp(l.mote, const Color(0xFFE8C090), s)!,
      firefly: l.firefly * (1 - s),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  _Sand? _sand;
  _Blades? _scrub;
  _Blades? _foreScrub;
  double _floorWidth = 0, _duneWidth = 0, _foreWidth = 0;
  List<(double, int)> _duneCrests = const [];
  List<(double, double, double)> _lipCrests = const [];

  /// The glass the storm left: glints all over the floor, shown only in its
  /// aftermath.
  _Glints? _glass;

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        final land = Rect.fromLTWH(0, _h * 0.40, w, _h * 0.36);
        return [
          FieldSheet(
            bounds: land,
            resolution: 0.8,
            grade: _gButtes,
            paint: (c) => _paintButtes(c, w),
          ),
          FieldSheet(
            bounds: land,
            resolution: 0.8,
            light: true,
            paint: (c) => _paintButteLight(c, w),
          ),
          FieldSheet(
            bounds: land,
            resolution: 0.8,
            grade: _gFarSand,
            paint: (c) => _paintFarRanges(c, w),
          ),
          FieldSheet(
            bounds: land,
            resolution: 0.8,
            light: true,
            paint: (c) => _sinking(far, () => _paintFarRangeLight(c, w)),
          ),
        ];
      case dunes:
        _glints[dunes] = _Glints();
        _duneWidth = w;
        _duneCrests = _crests(w, 330, 31, _period(dunes));
        final bounds = Rect.fromLTWH(0, _h * 0.5, w, _h * 0.42);
        return [
          FieldSheet(
            bounds: bounds,
            grade: _gSand,
            paint: (c) => _paintDunes(c, w),
          ),
          FieldSheet(
            bounds: bounds,
            light: true,
            paint: (c) => _sinking(dunes, () => _paintDuneLight(c, w)),
          ),
          for (final r in _ruinsOn(dunes)) ..._ruinSheets(r, dunes),
        ];
      case floor:
        _glints[floor] = _Glints();
        _glass = _Glints();
        _floorWidth = w;
        _rows = _makeRows();
        _sand = _makeSand(w);
        _scrub = _floorScrub(w);
        final ground = Rect.fromLTWH(0, _h * 0.68, w, _h * 0.32);
        return [
          FieldSheet(
            bounds: ground,
            grade: _gFloor,
            paint: (c) => _paintFloor(c, w),
          ),
          FieldSheet(
            bounds: ground,
            light: true,
            paint: (c) => _sinking(floor, () => _paintFloorLight(c, w)),
          ),
          for (final r in _ruinsOn(floor)) ..._ruinSheets(r, floor),
          for (final p in _outcrops) ...[
            FieldSheet(
              bounds: _outcropBounds(p),
              grade: _gRock,
              paint: (c) => _outcrop(c, null, p),
            ),
            FieldSheet(
              bounds: _outcropBounds(p),
              light: true,
              paint: (c) => _sinking(floor, () {
                final sparks = GrainBatch(_sparkAlpha.length);
                _outcrop(_NullCanvas(), sparks, p);
                _drawSparks(c, sparks, 1.4);
              }),
            ),
            FieldSheet(
              bounds: _outcropBounds(p),
              grade: _gFloor,
              paint: (c) => _sandBank(
                c,
                _outcropShape(p).x,
                _outcropShape(p).base - 2 * _u,
                _outcropShape(p).w * 0.5,
                6 * _u,
                11,
                ground: (x) => _groundLine(x) + 0.02 * _h,
              ),
            ),
          ],
        ];
      case fore:
        _foreWidth = w;
        _lipCrests = _makeLips(w);
        _foreScrub = _lipScrub(w);
        final bounds = Rect.fromLTWH(0, _h * 0.8, w, _h * 0.2 + 8 * _u);
        return [
          FieldSheet(
            bounds: bounds,
            grade: _gLip,
            paint: (c) => _paintLips(c, w),
          ),
          FieldSheet(
            bounds: bounds,
            light: true,
            paint: (c) => _paintLipLight(c, w),
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    floor => true,
    far || dunes || fore => !front,
    _ => false,
  };

  // ── Far: buttes and ranges ───────────────────────────────────────────────

  /// The buttes standing out of the far haze: (x as a share of the loop,
  /// half width, height, as shares of the height).
  static const _butteSpots = [
    (0.08, 0.10, 0.075),
    (0.31, 0.05, 0.05),
    (0.47, 0.13, 0.09),
    (0.72, 0.07, 0.06),
    (0.88, 0.04, 0.045),
  ];

  void _paintButtes(Canvas c, double w) {
    for (var i = 0; i < _butteSpots.length; i++) {
      final (fx, hw, ht) = _butteSpots[i];
      _wrapped(fx * w, (hw + 0.06) * _h, w, (x) => _butte(c, x, hw, ht, i));
    }
  }

  /// A flat-topped butte: sheer cliffs under a cap of harder rock, falling
  /// to a skirt of scree that spreads into the sand.
  Path _buttePath(double x, double hw, double ht, int seed) {
    final base = _h * 0.58;
    final top = base - ht * _h;
    final half = hw * _h;
    final cliff = top + ht * _h * 0.55;
    final p = Path()..moveTo(x - half - ht * _h * 1.1, base);
    p.quadraticBezierTo(
      x - half - ht * _h * 0.3,
      base - 2 * _u,
      x - half * 1.02,
      cliff,
    );
    // The cliff, a little ragged.
    final steps = 6;
    for (var k = 1; k <= steps; k++) {
      final f = k / steps;
      p.lineTo(
        x - half * (1.02 - 0.06 * f) + fieldHash(k, seed * 7) * 2 * _u,
        cliff + (top - cliff) * f,
      );
    }
    // The cap: nearly flat, notched here and there.
    final capSteps = math.max(4, (half / (6 * _u)).round());
    for (var k = 0; k <= capSteps; k++) {
      final f = k / capSteps;
      p.lineTo(
        x - half * 0.96 + half * 1.92 * f,
        top + fieldHash(k, seed * 13 + 1) * 1.6 * _u,
      );
    }
    for (var k = steps; k >= 1; k--) {
      final f = k / steps;
      p.lineTo(
        x + half * (1.02 - 0.06 * f) - fieldHash(k, seed * 11) * 2 * _u,
        cliff + (top - cliff) * f,
      );
    }
    p
      ..lineTo(x + half * 1.02, cliff)
      ..quadraticBezierTo(
        x + half + ht * _h * 0.3,
        base - 2 * _u,
        x + half + ht * _h * 1.1,
        base,
      )
      ..close();
    return p;
  }

  void _butte(Canvas c, double x, double hw, double ht, int seed) {
    final top = _h * (0.58 - ht);
    c.drawPath(
      _buttePath(x, hw, ht, seed),
      Paint()
        ..shader = Gradient.linear(Offset(0, top), Offset(0, _h * 0.58), [
          fieldMap(0.4, 0, 0.4 * 0.5),
          fieldMap(0.64, 0, 0.64),
        ]),
    );
    // Bands of strata across the cliff, a shade apart — soft, not lines.
    final cliffTop = top + ht * _h * 0.08;
    final cliffBase = top + ht * _h * 0.55;
    c
      ..save()
      ..clipPath(_buttePath(x, hw, ht, seed));
    for (var k = 0; k < 3; k++) {
      final y = cliffTop + (cliffBase - cliffTop) * (0.25 + k * 0.28);
      c.drawRect(
        Rect.fromLTRB(x - hw * _h * 1.2, y, x + hw * _h * 1.2, y + 2.4 * _u),
        Paint()..color = fieldMap(0.55, 0, 0.75, 0.5),
      );
    }
    c.restore();
  }

  void _paintButteLight(Canvas c, double w) {
    // Light caught along the cap's edge.
    for (var i = 0; i < _butteSpots.length; i++) {
      final (fx, hw, ht) = _butteSpots[i];
      _wrapped(fx * w, (hw + 0.06) * _h, w, (x) {
        final top = _h * (0.58 - ht);
        c.drawRect(
          Rect.fromLTRB(
            x - hw * _h * 0.96,
            top,
            x + hw * _h * 0.96,
            top + 2.2 * _u,
          ),
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.42),
        );
      });
    }
  }

  void _paintFarRanges(Canvas c, double w) {
    for (var i = 0; i < 2; i++) {
      double ridge(double x) => _farRange(i, x);
      final crest = _h * (0.55 + i * 0.035);
      final lowC = i * 0.5;
      _fillRidge(
        c,
        w,
        ridge,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, crest),
            Offset(0, _h * (0.64 + i * 0.04)),
            [
              fieldMap(0.38 - i * 0.12, 0, (0.38 - i * 0.12) * lowC),
              fieldMap(0.6 - i * 0.12, 0, 0.6 - i * 0.12),
            ],
          ),
        bottom: _h * 0.76,
        step: 2.5 * _u,
      );
      _slipShade(
        c,
        w,
        ridge,
        i == 0 ? 150 : 190,
        21 + i * 2,
        far,
        0.38 - i * 0.12,
      );
      _mistBand(c, w, _h * (0.575 + i * 0.04), _h * (0.64 + i * 0.04), 0.18);
    }
  }

  void _paintFarRangeLight(Canvas c, double w) {
    for (var i = 0; i < 2; i++) {
      _rimBands(c, w, (x) => _farRange(i, x), [
        (2.0, 0.3 + 0.06 * i),
        (5.0, 0.12),
      ]);
    }
  }

  /// The slipfaces of a range: a crescent of shade hanging from each crest
  /// down to the next trough, so the dunes read as dunes, not hills.
  void _slipShade(
    Canvas c,
    double w,
    double Function(double) ridge,
    double wave,
    int seed,
    SceneLayer layer,
    double haze,
  ) {
    final period = _period(layer);
    for (final (xc, _) in _crests(w, wave, seed, period)) {
      final (_, _, lam) = _dunePhase(xc, wave, seed, period);
      final xt = xc + lam * (1 - _windward) * 1.02;
      final drop = (xt - xc);
      _wrapped(xc, drop * 1.6, w, (x0) {
        final x1 = x0 + drop;
        final path = Path()..moveTo(x0, ridge(x0));
        const k = 10;
        for (var j = 1; j <= k; j++) {
          final x = x0 + drop * j / k;
          path.lineTo(x, ridge(x));
        }
        final deep = drop * 0.55;
        path
          ..lineTo(x1 + drop * 0.1, ridge(x1) + deep * 0.4)
          ..quadraticBezierTo(
            x0 + drop * 0.25,
            ridge(x0) + deep * 1.15,
            x0 - drop * 0.05,
            ridge(x0) + 1.2 * _u,
          )
          ..close();
        final y0 = ridge(x0);
        c.drawPath(
          path,
          Paint()
            ..shader = Gradient.linear(
              Offset(0, y0),
              Offset(0, y0 + deep * 1.15),
              [
                fieldMap(haze, 0, 0.5, 0.85),
                fieldMap(haze, 0, 0.42, 0.55),
                fieldMap(haze, 0, 0.3, 0),
              ],
              const [0.0, 0.45, 1.0],
            ),
        );
      });
    }
  }

  // ── The great dunes ──────────────────────────────────────────────────────

  void _paintDunes(Canvas c, double w) {
    _fillRidge(
      c,
      w,
      _dune,
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.6), Offset(0, _h * 0.86), [
          fieldMap(0.12, 0, 0.04),
          fieldMap(0.2, 0, 0.2),
        ]),
      bottom: _h * 0.92,
      step: 2.2 * _u,
    );
    _slipShade(c, w, _dune, 330, 31, dunes, 0.12);
    // Wind ripples on the backs: rows of grains, lit on their windward
    // side, following the slope down from the crest.
    final flecks = GrainBatch(3);
    final r = FieldRandom(3107);
    final n = (w * 2.2).round();
    for (var i = 0; i < n; i++) {
      final x = r.next() * w;
      final d = math.pow(r.next(), 1.4) * 70 * _u;
      final y = _dune(x) + 2 * _u + d;
      final wave = (3.0 + d / (9 * _u)) * _u;
      final ph = ((y + _nd(x, 70, 34) * wave * 2) / wave) % 1;
      if (ph > 0.45) continue;
      flecks.add(ph < 0.15 ? 2 : (ph < 0.3 ? 1 : 0), x, y);
    }
    for (var t = 0; t < 3; t++) {
      flecks.draw(c, t, 1.25 * _u, fieldMap(0.15, 0.1 + t * 0.14, 0.12, 0.8));
    }
    _mistBand(c, w, _h * 0.7, _h * 0.8, 0.08);
  }

  void _paintDuneLight(Canvas c, double w) {
    _rimBands(c, w, _dune, [(1.8, 0.48), (4.2, 0.24), (9.0, 0.1)]);
    final sparks = GrainBatch(_sparkAlpha.length);
    _rimSparkle(sparks, w, _dune, seed: 5);
    // Glass in the sand along the crests.
    for (final (x, _) in _duneCrests) {
      for (var j = 0; j < 6; j++) {
        _glint(
          x - fieldHash(j, x.round()) * 60 * _u,
          _dune(x) + fieldHash(j + 9, x.round()) * 14 * _u,
        );
      }
    }
    _drawSparks(c, sparks, 1.35);
  }

  // ── The floor ────────────────────────────────────────────────────────────

  void _paintFloor(Canvas c, double w) {
    // Warm air shimmering over the sand at the foot of the dunes.
    c.drawRect(
      Rect.fromLTWH(0, _h * 0.7, w, _h * 0.14),
      Paint()
        ..shader = Gradient.linear(Offset(0, _h * 0.7), Offset(0, _h * 0.83), [
          fieldMap(1, 0, 0, 0),
          fieldMap(1, 0, 0, 0.26),
        ]),
    );
    _fillRidge(
      c,
      w,
      _groundLine,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _h * 0.79),
          Offset(0, _h),
          [fieldMap(0, 0.1, 0.02), fieldMap(0, 0, 0.12), fieldMap(0, 0, 0.36)],
          const [0.0, 0.3, 1.0],
        ),
      bottom: _h,
      step: 2.5 * _u,
    );
    // The ripples: each a soft lit rise up to its crest and a band of shade
    // in its lee, wandering across the floor, close together far off.
    for (var k = 0; k < _rows.length; k++) {
      final f = _rows[k];
      final wave = _waveAt(f);
      final step = 4 * _u;
      final lit = Path(), lee = Path();
      final pts = <Offset>[];
      for (var x = -4.0; x <= w + 4; x += step) {
        pts.add(Offset(x, _rowY(k, x)));
      }
      lit.moveTo(pts.first.dx, pts.first.dy);
      lee.moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts) {
        lit.lineTo(q.dx, q.dy);
        lee.lineTo(q.dx, q.dy);
      }
      for (final q in pts.reversed) {
        lit.lineTo(q.dx, q.dy - wave * 0.42);
        lee.lineTo(q.dx, q.dy + wave * 0.34);
      }
      lit.close();
      lee.close();
      c
        ..drawPath(lit, Paint()..color = fieldMap(0, 0.12, 0, 0.55))
        ..drawPath(lee, Paint()..color = fieldMap(0, 0, 0.42, 0.5 + 0.2 * f));
    }
  }

  void _paintFloorLight(Canvas c, double w) {
    _rimBands(c, w, _groundLine, [(2.2, 0.26), (6.0, 0.1)]);
    // Glass in the sand: a glint here and there, which the moon finds.
    final r = FieldRandom(4127);
    for (var i = 0; i < (w / (6 * _u)).round(); i++) {
      final x = r.next() * w;
      final g = _groundLine(x);
      _glint(x, g + 3 * _u + math.pow(r.next(), 1.3) * (_h - g - 4 * _u));
    }
    // And all of it, after the storm.
    final glass = _glass;
    if (glass != null) {
      _sinkingInto(glass, w, () {
        for (var i = 0; i < (w / (1.6 * _u)).round(); i++) {
          final x = r.next() * w;
          final g = _groundLine(x);
          _glint(x, g + 2 * _u + math.pow(r.next(), 1.15) * (_h - g - 3 * _u));
        }
      });
    }
  }

  /// The ripples' rows, as how far down the floor each lies (0 at its far
  /// edge, 1 at the bottom of the screen).
  List<double> _rows = const [];

  /// How far apart the ripples are at [f] down the floor.
  double _waveAt(double f) => (2.8 + 12 * f) * _u;

  List<double> _makeRows() {
    final span = _h * 0.2;
    final out = <double>[];
    var f = 0.015;
    while (f < 1.02) {
      out.add(f);
      f += _waveAt(f) / span;
    }
    return out;
  }

  /// Where ripple row [k] lies at [x]: wandering a little, and running
  /// together with its neighbours here and there.
  double _rowY(int k, double x) {
    final f = _rows[k];
    final wave = _waveAt(f);
    final g = _groundLine(x);
    return g +
        2.5 * _u +
        f * (_h - g + 4 * _u) +
        _nl(x, 110, 51 + k % 5) * wave * 0.7 +
        _nl(x, 31, 57) * wave * 0.22;
  }

  /// The loose sand: the grains along every ripple's crest and a scatter on
  /// its lit side, each with a home it drifts back to.
  _Sand _makeSand(double w) {
    final r = FieldRandom(4201);
    final items = <(double, double, int)>[];
    for (var k = 0; k < _rows.length; k++) {
      final f = _rows[k];
      final wave = _waveAt(f);
      final size = f < 0.25 ? 0 : (f < 0.6 ? 1 : 2);
      final gap = (1.7 + 1.6 * f) * _u;
      var x = r.next() * gap;
      while (x < w) {
        final y = _rowY(k, x) + r.range(-0.5, 0.4) * _u * (1 + f);
        // Most of a crest catches the light; here and there it is lit hard.
        final roll = r.next();
        final tone = roll < 0.18 ? 3 : (roll < 0.8 ? 2 : 1);
        items.add((x, y, tone * 3 + size));
        // A few loose grains below it, on its rise.
        if (r.next() < 0.35) {
          items.add((
            x + r.range(-1, 1) * gap,
            y - r.range(0.12, 0.4) * wave,
            (r.next() < 0.5 ? 1 : 0) * 3 + size,
          ));
        }
        x += gap * r.range(0.7, 1.3);
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    final s = _Sand(items.length);
    for (var i = 0; i < items.length; i++) {
      s.hx[i] = (items[i].$1 % w + w) % w;
      s.hy[i] = items[i].$2;
      s.kind[i] = items[i].$3;
    }
    // Wrapping a few round the seam leaves them out of order; put them back.
    return s..sort();
  }

  /// Fingers through the loose sand. A drag ploughs a furrow: every grain
  /// it passes over is thrown aside to the edge of the finger, banking up
  /// there, with a little thrown into the air. A tap blows a crater out.
  /// The wind fills it all back in, slowly — quickly in a storm.
  void _stirSand(FieldView view) {
    final s = _sand;
    if (s == null) return;
    final stirs = _stirsFor(floor, view);
    final now = view.time;
    final dt = s.clock < 0 ? 0.0 : (now - s.clock).clamp(0.0, 1 / 30);
    s.clock = now;
    final period = _period(floor);
    final reach = 17 * _u;
    final fresh = <_Stir>[
      for (final p in stirs)
        if (p.time > s.seen && _groundLine(p.x) - 12 * _u < p.y) p,
    ];
    for (final p in stirs) {
      if (p.time > s.seen) s.seen = p.time;
    }
    for (final p in fresh) {
      _furrowAt(p);
    }
    // Take in the grains the fingers reach.
    for (final p in fresh) {
      final rr = p.speed < 0.5 ? reach * 1.8 : reach;
      final local = period > 0 ? p.x - period * (p.x / period).floor() : p.x;
      for (final cx in [
        local,
        if (period > 0) local - period,
        local + period,
      ]) {
        if (cx + rr < 0 || cx - rr > _floorWidth) continue;
        final a = s.firstAt(cx - rr * 2), z = s.firstAt(cx + rr * 2) - 1;
        if (z < a) continue;
        if (s.hi < s.lo) {
          s
            ..lo = a
            ..hi = z;
        } else {
          s.lo = math.min(s.lo, a);
          s.hi = math.max(s.hi, z);
        }
        // Throw each one aside.
        final tap = p.speed < 0.5;
        for (var i = a; i <= z; i++) {
          final gx = s.hx[i] + s.dx[i], gy = s.hy[i] + s.dy[i];
          final ex = cx + (p.x - local) - gx;
          final ddx = period > 0 ? -_loopDelta(p.x, gx, floor) : -ex;
          final ddy = gy - p.y;
          final d2 = ddx * ddx + ddy * ddy * 1.6;
          if (d2 > rr * rr) continue;
          final d = math.sqrt(d2) + 1e-3;
          // A drag throws it out to either side of its path; a tap, all
          // round.
          final ux = tap ? ddx / d : ddx / d * 0.25;
          final uy = tap ? ddy / d : (ddy >= 0 ? 1.0 : -1.0);
          final out = rr * (1.0 + 0.3 * _kicked.rand());
          final tx = tap ? p.x + ux * out : gx + ux * out * 0.3;
          final ty = p.y + uy * out * 0.62;
          s.vx[i] = (tx - gx) * (tap ? 16 : 13);
          s.vy[i] = (ty - gy) * (tap ? 16 : 13);
          // Some of it goes up.
          final throwChance = tap ? 0.22 : 0.035;
          if (_kicked.rand() < throwChance) {
            _kicked.spawn(
              x: gx,
              y: gy,
              vx: (tap ? ux * 90 : p.dir * 70 + ux * 30) * _u,
              vy: -(40 + _kicked.rand() * (tap ? 120 : 70)) * _u,
              life: 2.5,
            );
          }
        }
      }
    }
    if (s.hi < s.lo || dt <= 0) return;
    final fill = storm > 0.2 ? 1.2 : 5.0;
    final settle = math.exp(-dt / fill);
    final drag = math.exp(-14 * dt);
    var lo = s.n, hi = -1;
    for (var i = s.lo; i <= s.hi; i++) {
      var dx = s.dx[i], dy = s.dy[i], vx = s.vx[i], vy = s.vy[i];
      dx += vx * dt;
      dy += vy * dt;
      vx *= drag;
      vy *= drag;
      if (vx.abs() + vy.abs() < 6 * _u) {
        dx *= settle;
        dy *= settle;
      }
      // Never up off the sand into the air over it.
      final x = s.hx[i] + dx;
      final top = _groundLine(x) + 1.5 * _u;
      if (s.hy[i] + dy < top) {
        dy = top - s.hy[i];
        vy = 0;
      }
      if (dx.abs() + dy.abs() < 0.08 * _u && vx.abs() + vy.abs() < 0.5 * _u) {
        dx = dy = vx = vy = 0;
      } else {
        if (i < lo) lo = i;
        hi = i;
      }
      s.dx[i] = dx;
      s.dy[i] = dy;
      s.vx[i] = vx;
      s.vy[i] = vy;
    }
    s.lo = lo;
    s.hi = hi;
  }

  /// The groove a finger leaves in the sand, and the crater a tap blows:
  /// shade where the loose grains were thrown off, filling in as they come
  /// back.
  final List<_Furrow> _furrows = [];

  void _furrowAt(_Stir p) {
    final tap = p.speed < 0.5;
    final last = _furrows.isEmpty ? null : _furrows.last;
    if (!tap &&
        last != null &&
        !last.tap &&
        p.time - last.last < 0.2 &&
        (Offset(p.x, p.y) - last.pts.last).distance < 60 * _u) {
      last.pts.add(Offset(p.x, p.y));
      last.last = p.time;
      return;
    }
    _furrows.add(_Furrow(Offset(p.x, p.y), p.time, tap: tap));
    if (_furrows.length > 24) _furrows.removeAt(0);
  }

  static final Paint _groove = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _paintFurrows(Canvas canvas, FieldView view) {
    if (_furrows.isEmpty) return;
    final fill = storm > 0.2 ? 1.2 : 5.0;
    final shade = _sandTones[0];
    final reach = 17 * _u;
    _furrows.removeWhere((f) => view.time - f.last > fill * 4);
    final period = _period(floor);
    for (final f in _furrows) {
      final fresh = math.exp(-(view.time - f.last) / fill);
      if (fresh < 0.02) continue;
      // The repeat of it nearest the camera, which may have wrapped round
      // the loop since.
      final mid = (view.left + view.right) / 2;
      final dx = period > 0
          ? period * ((mid - f.pts.first.dx) / period).roundToDouble()
          : 0.0;
      {
        if (f.tap || f.pts.length == 1) {
          final at = f.pts.first + Offset(dx, 0);
          final r = f.tap ? reach * 1.5 : reach * 0.7;
          canvas.drawOval(
            Rect.fromCenter(center: at, width: r * 2, height: r * 1.25),
            Paint()
              ..shader = Gradient.radial(
                at,
                r,
                [
                  shade.withValues(alpha: 0.55 * fresh),
                  shade.withValues(alpha: 0.3 * fresh),
                  shade.withValues(alpha: 0),
                ],
                const [0.0, 0.6, 1.0],
              ),
          );
          continue;
        }
        final path = Path()..moveTo(f.pts.first.dx + dx, f.pts.first.dy);
        for (final q in f.pts.skip(1)) {
          path.lineTo(q.dx + dx, q.dy);
        }
        // The ripples smoothed out where it went, and the groove's floor in
        // its own shade.
        _groove
          ..strokeWidth = reach * 1.55
          ..color = _sandTones[1].withValues(alpha: 0.9 * fresh);
        canvas.drawPath(path, _groove);
        _groove
          ..strokeWidth = reach * 0.8
          ..color = shade.withValues(alpha: 0.45 * fresh);
        canvas.drawPath(path.shift(Offset(0, -1.5 * _u)), _groove);
      }
    }
  }

  final GrainBatch _sparkBatch = GrainBatch(2);

  /// Glass in the sand catching the light: fine points that flash and are
  /// gone, warm by day and silver under the moon — never a halo.
  void _paintSparkles(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    _Glints? g, {
    required double alpha,
    double size = 1,
  }) {
    if (g == null || g.n == 0 || alpha <= 0.01) return;
    final t = view.time;
    _sparkBatch.clear();
    var any = false;
    final loops = _shiftsFor(layer, view, 4);
    for (var i = 0; i < g.n; i++) {
      final s = math.sin(t * g.speed[i] * 2.4 + g.phase[i]);
      if (s < 0.78) continue;
      var x = g.x[i] + 0.0;
      for (final sh in loops) {
        if (x + sh >= view.left - 4 && x + sh <= view.right + 4) {
          x += sh;
          break;
        }
      }
      if (x < view.left - 4 || x > view.right + 4) continue;
      _sparkBatch.add(s > 0.93 ? 1 : 0, x, g.y[i]);
      any = true;
    }
    if (!any) return;
    final col = Color.lerp(_light.rim, const Color(0xFFFFFFFF), 0.55)!;
    _sparkBatch
      ..draw(canvas, 0, 1.2 * size * _u, col.withValues(alpha: 0.55 * alpha))
      ..draw(canvas, 1, 3.0 * size * _u, col.withValues(alpha: 0.18 * alpha))
      ..draw(canvas, 1, 1.5 * size * _u, col.withValues(alpha: 0.95 * alpha));
  }

  final GrainBatch _sandBatch = GrainBatch(12);

  void _paintSand(Canvas canvas, FieldView view) {
    final s = _sand;
    if (s == null) return;
    _sandBatch.clear();
    final margin = 24 * _u;
    for (final shift in _shiftsFor(floor, view, margin)) {
      for (var i = s.firstAt(view.left - margin - shift); i < s.n; i++) {
        final x = s.hx[i] + s.dx[i] + shift;
        if (s.hx[i] + shift > view.right + margin) break;
        final y = s.hy[i] + s.dy[i];
        if (y < view.top - 4 || y > view.bottom + 4) continue;
        _sandBatch.add(s.kind[i], x, y);
      }
    }
    final sizes = [1.1 * _u, 1.45 * _u, 1.9 * _u];
    for (var tone = 0; tone < 4; tone++) {
      for (var sz = 0; sz < 3; sz++) {
        _sandBatch.draw(canvas, tone * 3 + sz, sizes[sz], _sandTones[tone]);
      }
    }
  }

  /// Sand thrown into the air: it arcs and falls, and is gone into the sand
  /// where it lands.
  void _flySand(FieldView view) {
    final k = _kicked;
    final dt = (view.time - k.clock).clamp(0.0, 0.1);
    k.clock = view.time;
    final period = _period(floor);
    if (period > 0 &&
        k.left != null &&
        (view.left - k.left!).abs() > period / 2) {
      final jump = period * ((view.left - k.left!) / period).roundToDouble();
      for (var i = 0; i < k.cap; i++) {
        k.x[i] += jump;
      }
    }
    k.left = view.left;
    if (dt <= 0) return;
    final (wind, _) = _wind((view.left + view.right) / 2, view.time, period);
    for (var i = 0; i < k.cap; i++) {
      if (k.life[i] <= 0) continue;
      k.age[i] += dt;
      final drag = math.exp(-1.2 * dt);
      k.vx[i] = k.vx[i] * drag + wind * 60 * _u * dt;
      k.vy[i] = k.vy[i] * drag + 420 * _u * dt;
      k.x[i] += k.vx[i] * dt;
      k.y[i] += k.vy[i] * dt;
      if (k.vy[i] > 0 && k.y[i] > _groundLine(k.x[i]) + 6 * _u) {
        // Landed — somewhere in the floor below its fall.
        if (k.y[i] >
            _groundLine(k.x[i]) + 6 * _u + fieldHash(i, 77) * 40 * _u) {
          k.life[i] = 0;
        }
      }
      if (k.age[i] >= k.life[i]) k.life[i] = 0;
    }
  }

  void _paintFlying(Canvas canvas) {
    final k = _kicked;
    _moteBatch.clear();
    var any = false;
    for (var i = 0; i < k.cap; i++) {
      if (k.life[i] <= 0) continue;
      _moteBatch.add(i % 3 == 0 ? 3 : 2, k.x[i], k.y[i]);
      any = true;
    }
    if (!any) return;
    _moteBatch.draw(canvas, 2, 1.7 * _u, _sandTones[2]);
    _moteBatch.draw(canvas, 3, 1.7 * _u, _sandTones[3]);
  }

  /// Tufts of dry scrub on the floor.
  _Blades _floorScrub(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(4301);
    var cx = r.range(80, 220) * _u;
    while (cx < w) {
      final g = _groundLine(cx);
      final depth = math.pow(r.next(), 1.6).toDouble();
      final base = g + 4 * _u + depth * (_h - g) * 0.7;
      final n = 7 + (r.next() * 8).floor();
      final reach = r.range(9, 18) * _u * (1 + depth);
      for (var i = 0; i < n; i++) {
        final off = r.range(-6, 6) * _u * (1 + depth);
        b.add(
          x: _loop ? (cx + off) % w : cx + off,
          base: base + r.range(-1, 1) * _u,
          height: reach * r.range(0.45, 1.0),
          lean: off / (6 * _u) * 0.4 + r.range(-0.1, 0.1),
          phase: r.range(0, math.pi * 2),
          depth: depth,
          row: depth < 0.12 ? 1 : (depth < 0.3 ? 2 : 3),
        );
      }
      cx += r.range(180, 520) * _u;
    }
    return b.done();
  }

  // ── Fore: the lips of near dunes ─────────────────────────────────────────

  /// The near dunes' lips across a loop [w] wide: (crest x, half width,
  /// height above the bottom).
  List<(double, double, double)> _makeLips(double w) {
    final r = FieldRandom(5101);
    final out = <(double, double, double)>[];
    var x = r.range(200, 400) * _u;
    while (x < w) {
      out.add((x, r.range(130, 230) * _u, r.range(0.05, 0.1) * _h));
      x += r.range(700, 1300) * _u;
    }
    return out;
  }

  /// The lip of a near dune: a long back rising from the left to a sharp
  /// crest, and a short fall beyond it.
  double? _lip(double x, (double, double, double) l) {
    final (cx, hw, ht) = l;
    final d = x - cx;
    if (d < -hw * 1.6 || d > hw * 0.7) return null;
    final f = d < 0
        ? math.pow(math.sin((1 + d / (hw * 1.6)) * math.pi / 2), 1.6)
        : math.pow(1 - d / (hw * 0.7), 1.8);
    return _h + 4 * _u - ht * f;
  }

  Path _lipPath((double, double, double) l, double at) {
    final shifted = (at, l.$2, l.$3);
    final x0 = at - l.$2 * 1.6, x1 = at + l.$2 * 0.7;
    final p = Path()..moveTo(x0, _h + 10 * _u);
    for (var x = x0; x <= x1; x += 3 * _u) {
      p.lineTo(x, _lip(x, shifted) ?? _h + 4 * _u);
    }
    return p
      ..lineTo(x1, _h + 10 * _u)
      ..close();
  }

  void _paintLips(Canvas c, double w) {
    for (final l in _lipCrests) {
      _wrapped(l.$1, l.$2 * 1.7, w, (at) {
        final path = _lipPath(l, at);
        c.drawPath(
          path,
          Paint()
            ..shader = Gradient.linear(Offset(0, _h - l.$3), Offset(0, _h), [
              fieldMap(0, 0.05, 0.55),
              fieldMap(0, 0, 0.82),
            ]),
        );
        // The slipface beyond the crest, deeper still.
        final slip = Path()..moveTo(at, _lip(at, (at, l.$2, l.$3))!);
        for (var x = at; x <= at + l.$2 * 0.7; x += 3 * _u) {
          slip.lineTo(x, _lip(x, (at, l.$2, l.$3)) ?? _h);
        }
        slip
          ..lineTo(at + l.$2 * 0.7, _h + 10 * _u)
          ..lineTo(at + l.$2 * 0.1, _h + 10 * _u)
          ..close();
        c.drawPath(slip, Paint()..color = fieldMap(0, 0, 0.95, 0.85));
      });
    }
  }

  void _paintLipLight(Canvas c, double w) {
    for (final l in _lipCrests) {
      _wrapped(l.$1, l.$2 * 1.7, w, (at) {
        final shifted = (at, l.$2, l.$3);
        for (final (depth, a) in [(1.4, 0.55), (4.0, 0.2)]) {
          final band = Path();
          final x0 = at - l.$2 * 1.4;
          band.moveTo(x0, _lip(x0, shifted)!);
          for (var x = x0; x <= at; x += 3 * _u) {
            band.lineTo(x, _lip(x, shifted)!);
          }
          for (var x = at; x >= x0; x -= 3 * _u) {
            band.lineTo(x, _lip(x, shifted)! + depth * _u);
          }
          band.close();
          c.drawPath(
            band,
            Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
          );
        }
      });
    }
  }

  _Blades _lipScrub(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(5201);
    for (final l in _lipCrests) {
      final (cx, hw, _) = l;
      final at = cx - hw * r.range(0.3, 1.0);
      final n = 8 + (r.next() * 8).floor();
      final reach = r.range(30, 56) * _u;
      for (var i = 0; i < n; i++) {
        final off = r.range(-14, 14) * _u;
        final x = at + off;
        b.add(
          x: _loop ? x % w : x,
          base: (_lip(x, l) ?? _h) + 3 * _u,
          height: reach * r.range(0.5, 1.0),
          lean: off / (14 * _u) * 0.34 + r.range(-0.08, 0.08),
          phase: r.range(0, math.pi * 2),
          depth: 1,
          row: 0,
        );
      }
    }
    return b.done();
  }

  // ── Ruins ────────────────────────────────────────────────────────────────

  /// The ruins where the wild has them: (layer, piece, x as a share of the
  /// layer's loop, width, height) at the reference height.
  static const _wildRuins = <(SceneLayer, String, double, double, double)>[
    (SceneLayer.layer3, FieldPiece.arch, 0.31, 120, 104),
    (SceneLayer.layer3, FieldPiece.pillar, 0.575, 17, 76),
    (SceneLayer.layer3, FieldPiece.pillar, 0.6, 15, 50),
    (SceneLayer.layer3, FieldPiece.pillar, 0.84, 19, 84),
    (SceneLayer.layer4, FieldPiece.pillar, 0.255, 30, 128),
    (SceneLayer.layer4, FieldPiece.pillar, 0.735, 28, 92),
  ];

  /// The ruins as the home biome first has them: (far row?, piece, x as a
  /// share of its row's loop, width, height).
  static List<(bool, String, double, double, double)> get homeRuins => [
    for (final (layer, piece, x, w, h) in _wildRuins)
      (layer == SceneLayer.layer3, piece, x, w, h),
  ];

  /// The rocks where the wild has them, besides those under its high
  /// points: (x as a share of the floor's loop, width, height).
  static const _wildRocks = <(double, double, double)>[(0.47, 70, 40)];

  /// The rocks as the home biome first has them.
  static List<(double, double, double)> get homeRocks => _wildRocks;

  /// The ruins on [layer]: (x, foot, width, height, piece, seed).
  List<({double x, double w, double h, String piece, int seed})> _ruinsOn(
    SceneLayer layer,
  ) {
    final width = _widths[layer] ?? _worldWidth;
    if (_placed) {
      return [
        for (final p in _piecesOn(layer, {FieldPiece.pillar, FieldPiece.arch}))
          (
            x: _spawnX(p),
            w: p.size.x * _u,
            h: p.size.y * _u,
            piece: p.piece!,
            seed: fieldSeedOf(p.id),
          ),
      ];
    }
    var i = 0;
    return [
      for (final (l, piece, fx, w, h) in _wildRuins)
        if (l == layer)
          (x: fx * width, w: w * _u, h: h * _u, piece: piece, seed: 70 + i++),
    ];
  }

  double _footOn(SceneLayer layer, double x) =>
      layer == dunes ? _dune(x) + 6 * _u : _groundLine(x) + 0.025 * _h;

  List<FieldSheet> _ruinSheets(
    ({double x, double w, double h, String piece, int seed}) r,
    SceneLayer layer,
  ) {
    final foot = _footOn(layer, r.x);
    final reach = r.piece == FieldPiece.arch
        ? r.w * 0.75
        : r.w * 2.2 + r.h * 0.2;
    final bounds = Rect.fromLTRB(
      r.x - reach,
      foot - r.h * 1.15,
      r.x + reach,
      foot + 10 * _u,
    );
    // Only what stands above the sand: a pier on a slope goes into it.
    double ground(double x) =>
        layer == dunes ? _dune(x) + 4 * _u : _groundLine(x) + 0.03 * _h;
    final clip = Path()
      ..moveTo(bounds.left, bounds.top)
      ..lineTo(bounds.right, bounds.top);
    for (var x = bounds.right; x >= bounds.left - 3 * _u; x -= 3 * _u) {
      clip.lineTo(x, ground(x));
    }
    clip.close();
    void paint(Canvas c, GrainBatch? sparks) {
      c
        ..save()
        ..clipPath(clip);
      r.piece == FieldPiece.arch
          ? _arch(c, sparks, r.x, foot, r.w, r.h, r.seed)
          : _pillar(c, sparks, r.x, foot, r.w, r.h, r.seed);
      c.restore();
    }

    return [
      FieldSheet(bounds: bounds, grade: _gStone, paint: (c) => paint(c, null)),
      FieldSheet(
        bounds: bounds,
        light: true,
        paint: (c) => _sinking(layer, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          paint(_NullCanvas(), sparks);
          _drawSparks(c, sparks, 1.35);
        }),
      ),
      // The sand drifted up round its foot, over the stone.
      FieldSheet(
        bounds: bounds,
        grade: layer == dunes ? _gSand : _gFloor,
        paint: (c) {
          final onDunes = layer == dunes;
          double ground(double x) =>
              onDunes ? _dune(x) + 2 * _u : _groundLine(x) + 0.02 * _h;
          final haze = onDunes ? 0.12 : 0.0;
          if (r.piece == FieldPiece.arch) {
            for (final side in [-1.0, 1.0]) {
              _sandBank(
                c,
                r.x + side * r.w * 0.39,
                foot,
                r.w * 0.22,
                r.h * 0.12,
                r.seed + side.round(),
                ground: ground,
                haze: haze,
              );
            }
          } else {
            _sandBank(
              c,
              r.x,
              foot,
              r.w * 1.3,
              r.h * 0.14,
              r.seed,
              ground: ground,
              haze: haze,
            );
          }
        },
      ),
    ];
  }

  /// A drift of sand banked against something: a mound [hw] either side
  /// of [x], [ht] high at its foot, lying on the [ground] under it so it
  /// runs out into the slope rather than sitting on it.
  void _sandBank(
    Canvas c,
    double x,
    double foot,
    double hw,
    double ht,
    int seed, {
    double Function(double x)? ground,
    double haze = 0,
  }) {
    final under = ground ?? (_) => foot;
    const k = 28;
    final x0 = x - hw * 1.6, x1 = x + hw * 1.6;
    double top(double px) {
      final d = (px - x) / hw;
      final bump =
          ht *
          math.exp(-d * d * 1.4) *
          (1 + 0.12 * fieldNoise(px / (hw * 0.4), seed));
      return under(px) - bump;
    }

    final path = Path()..moveTo(x0, under(x0) + 2 * _u);
    for (var j = 0; j <= k; j++) {
      final px = x0 + (x1 - x0) * j / k;
      path.lineTo(px, math.min(top(px), under(px) + 1 * _u));
    }
    for (var j = k; j >= 0; j--) {
      final px = x0 + (x1 - x0) * j / k;
      path.lineTo(px, under(px) + 3 * _u);
    }
    path.close();
    c.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, foot - ht),
          Offset(0, foot + 14 * _u),
          [fieldMap(haze, 0.08, 0.02), fieldMap(haze, 0, 0.1)],
        ),
    );
  }

  /// A column, half buried and leaning: fluted, its drums showing, broken
  /// off at the top or still under its capital.
  void _pillar(
    Canvas c,
    GrainBatch? sparks,
    double x,
    double foot,
    double w,
    double h,
    int seed,
  ) {
    final r = FieldRandom(seed * 31 + 7);
    final lean = (r.next() - 0.5) * 0.14;
    final broken = r.next() < 0.6;
    final capH = broken ? 0.0 : w * 0.34;
    final shaftH = h - capH;
    final sl = math.sin(lean), cl = math.cos(lean);
    // Along the column (a, 0 at its foot, up) and across it (b, right).
    Offset at(double b, double a) =>
        Offset(x + b * cl + a * sl, foot - a * cl + b * sl);
    double half(double a) => w * 0.5 * (1 - 0.1 * a / h);

    final body = Path()..moveTo(at(-half(0), 0).dx, at(-half(0), 0).dy);
    body.lineTo(at(-half(shaftH), shaftH).dx, at(-half(shaftH), shaftH).dy);
    // The break: a jagged top, lower on one side.
    final breakPts = <Offset>[];
    if (broken) {
      const k = 7;
      for (var j = 0; j <= k; j++) {
        final f = j / k;
        final drop = (fieldHash(j, seed) * 0.12 + f * 0.1) * w;
        breakPts.add(at(-half(shaftH) + 2 * half(shaftH) * f, shaftH - drop));
      }
      for (final p in breakPts) {
        body.lineTo(p.dx, p.dy);
      }
    } else {
      body.lineTo(at(half(shaftH), shaftH).dx, at(half(shaftH), shaftH).dy);
    }
    body
      ..lineTo(at(half(0), 0).dx, at(half(0), 0).dy)
      ..close();

    if (sparks == null) {
      c.drawPath(body, Paint()..color = fieldMap(0.02, 0, 0.08));
      c
        ..save()
        ..clipPath(body);
      // Flutes: bands of shade down the shaft, deeper toward its far side.
      const flutes = 5;
      for (var j = 0; j < flutes; j++) {
        final f = (j + 0.5) / flutes;
        final b0 = -half(0) + 2 * half(0) * f;
        final fw = w * 0.07;
        final p = Path()
          ..moveTo(at(b0 - fw, 0).dx, at(b0 - fw, 0).dy)
          ..lineTo(at(b0 - fw, h).dx, at(b0 - fw, h).dy)
          ..lineTo(at(b0 + fw, h).dx, at(b0 + fw, h).dy)
          ..lineTo(at(b0 + fw, 0).dx, at(b0 + fw, 0).dy)
          ..close();
        c.drawPath(p, Paint()..color = fieldMap(0.02, 0, 0.16 + 0.24 * f));
      }
      // Its right side in shade.
      final shade = Path()
        ..moveTo(at(half(0) * 0.3, 0).dx, at(half(0) * 0.3, 0).dy)
        ..lineTo(at(half(0) * 0.3, h).dx, at(half(0) * 0.3, h).dy)
        ..lineTo(at(half(0) * 1.2, h).dx, at(half(0) * 1.2, h).dy)
        ..lineTo(at(half(0) * 1.2, 0).dx, at(half(0) * 1.2, 0).dy)
        ..close();
      c.drawPath(shade, Paint()..color = fieldMap(0.02, 0, 0.55, 0.6));
      // The joints between its drums, soft and a little open.
      final drums = 2 + (r.next() * 3).floor();
      for (var j = 1; j <= drums; j++) {
        final a = shaftH * j / (drums + 1) + r.range(-0.04, 0.04) * h;
        final band = Path()
          ..moveTo(at(-half(a) * 1.1, a).dx, at(-half(a) * 1.1, a).dy)
          ..lineTo(at(half(a) * 1.1, a).dx, at(half(a) * 1.1, a).dy)
          ..lineTo(
            at(half(a) * 1.1, a - 1.8 * _u).dx,
            at(half(a) * 1.1, a - 1.8 * _u).dy,
          )
          ..lineTo(
            at(-half(a) * 1.1, a - 1.8 * _u).dx,
            at(-half(a) * 1.1, a - 1.8 * _u).dy,
          )
          ..close();
        c.drawPath(band, Paint()..color = fieldMap(0.02, 0, 0.7, 0.7));
      }
      // Weathering: pits as grains.
      final pits = GrainBatch(1);
      for (var i = 0; i < (w * h / (16 * _u * _u)).round(); i++) {
        pits.add(
          0,
          x + (fieldHash(i, seed) - 0.5) * w * 1.2,
          foot - fieldHash(i, seed + 3) * h,
        );
      }
      pits.draw(c, 0, 1.4 * _u, fieldMap(0.02, 0, 0.72, 0.8));
      c.restore();
      if (!broken) {
        // The capital: a block wider than the shaft, under a slab.
        final cw = w * 0.68;
        final capital = Path()
          ..moveTo(at(-half(shaftH), shaftH).dx, at(-half(shaftH), shaftH).dy)
          ..lineTo(
            at(-cw, shaftH + capH * 0.55).dx,
            at(-cw, shaftH + capH * 0.55).dy,
          )
          ..lineTo(at(-cw, h).dx, at(-cw, h).dy)
          ..lineTo(at(cw, h).dx, at(cw, h).dy)
          ..lineTo(
            at(cw, shaftH + capH * 0.55).dx,
            at(cw, shaftH + capH * 0.55).dy,
          )
          ..lineTo(at(half(shaftH), shaftH).dx, at(half(shaftH), shaftH).dy)
          ..close();
        c.drawPath(capital, Paint()..color = fieldMap(0.02, 0.1, 0.28));
      }
      return;
    }
    // Light down its lit edge and across its top.
    final n = (h / (1.7 * _u)).ceil();
    for (var i = 0; i < n; i++) {
      final a = h * i / n;
      if (fieldHash(i, seed) > 0.55) continue;
      final p = at(-half(a) + 0.8 * _u, a);
      sparks.add(fieldHash(i + 5, seed) < 0.6 ? 0 : 1, p.dx, p.dy);
    }
    final tops = broken
        ? breakPts
        : [at(-w * 0.68, h), at(0, h + 0.4 * _u), at(w * 0.68, h)];
    for (var j = 0; j + 1 < tops.length; j++) {
      final a = tops[j], z = tops[j + 1];
      final k = ((z - a).distance / (1.6 * _u)).ceil();
      for (var i = 0; i <= k; i++) {
        final roll = fieldHash(i + j * 17, seed);
        if (roll > 0.7) continue;
        final q = Offset.lerp(a, z, i / k)!;
        sparks.add((roll * 5).floor().clamp(0, 3), q.dx, q.dy + 0.6 * _u);
        if (roll < 0.05) _glint(q.dx, q.dy + 0.6 * _u);
      }
    }
  }

  /// An arch, broken: two piers and a ring of wedge-shaped stones from the
  /// left pier, most of the way over before it gives out; the right pier
  /// stands alone, shorter.
  void _arch(
    Canvas c,
    GrainBatch? sparks,
    double x,
    double foot,
    double w,
    double h,
    int seed,
  ) {
    final pier = w * 0.2;
    final rIn = w * 0.5 - pier;
    final rOut = rIn + pier * 0.85;
    final spring = foot - (h - rOut);
    final cx = x;
    final leftX = x - w * 0.5, rightX = x + w * 0.5 - pier;
    final rightTop = spring + (h - rOut) * 0.12;
    final stones = <Path>[];
    // The ring, a stone at a time: from the left springing round towards
    // the top and past it, then gone.
    const n = 9;
    const reach = 0.84; // share of the half-circle still standing
    final gap = 0.004 * math.pi;
    for (var j = 0; j < n; j++) {
      final a0 = math.pi + math.pi * reach * j / n + gap;
      final a1 = math.pi + math.pi * reach * (j + 1) / n - gap;
      if (j == n - 1 && fieldHash(seed, 3) < 0.5) break;
      Offset p(double a, double rad) =>
          Offset(cx + math.cos(a) * rad, spring + math.sin(a) * rad);
      stones.add(
        Path()
          ..moveTo(p(a0, rIn).dx, p(a0, rIn).dy)
          ..lineTo(p(a0, rOut).dx, p(a0, rOut).dy)
          ..lineTo(p(a1, rOut).dx, p(a1, rOut).dy)
          ..lineTo(p(a1, rIn).dx, p(a1, rIn).dy)
          ..close(),
      );
    }
    final leftPier = Rect.fromLTRB(leftX, spring, leftX + pier, foot + 4 * _u);
    final rightPier = Rect.fromLTRB(
      rightX,
      rightTop,
      rightX + pier,
      foot + 4 * _u,
    );
    if (sparks == null) {
      final stone = Paint()..color = fieldMap(0.02, 0, 0.1);
      c
        ..drawRect(leftPier, stone)
        ..drawRect(rightPier, stone);
      for (var j = 0; j < stones.length; j++) {
        c.drawPath(
          stones[j],
          Paint()..color = fieldMap(0.02, 0.04, 0.06 + 0.06 * (j % 3)),
        );
      }
      // The piers' inner faces in shade, and their courses.
      c
        ..drawRect(
          Rect.fromLTRB(leftX + pier * 0.62, spring, leftX + pier, foot),
          Paint()..color = fieldMap(0.02, 0, 0.55, 0.7),
        )
        ..drawRect(
          Rect.fromLTRB(rightX + pier * 0.55, rightTop, rightX + pier, foot),
          Paint()..color = fieldMap(0.02, 0, 0.6, 0.7),
        );
      for (final p in [leftPier, rightPier]) {
        for (var y = p.top + pier * 0.7; y < foot; y += pier * 0.75) {
          c.drawRect(
            Rect.fromLTRB(p.left, y, p.right, y + 1.6 * _u),
            Paint()..color = fieldMap(0.02, 0, 0.72, 0.6),
          );
        }
      }
      // The right pier's broken top.
      final jag = Path()..moveTo(rightX, rightTop);
      for (var j = 0; j <= 4; j++) {
        jag.lineTo(
          rightX + pier * j / 4,
          rightTop - fieldHash(j, seed + 9) * pier * 0.35,
        );
      }
      jag.close();
      c.drawPath(jag, stone);
      return;
    }
    // Light along the ring's back and the piers' outer edges.
    for (var j = 0; j < 60; j++) {
      final a = math.pi + math.pi * reach * j / 60;
      if (fieldHash(j, seed) > 0.6) continue;
      final p = Offset(
        cx + math.cos(a) * rOut,
        spring + math.sin(a) * rOut + 0.6 * _u,
      );
      sparks.add(fieldHash(j + 3, seed) < 0.5 ? 1 : 2, p.dx, p.dy);
      if (fieldHash(j + 7, seed) < 0.05) _glint(p.dx, p.dy);
    }
    for (final p in [leftPier, rightPier]) {
      for (var y = p.top; y < foot; y += 1.7 * _u) {
        if (fieldHash(y.round(), seed + p.left.round()) > 0.5) continue;
        sparks.add(0, p.left + 0.8 * _u, y);
      }
    }
  }

  // ── Rocks ────────────────────────────────────────────────────────────────

  /// The rocks on the floor: one under each high point, and those placed
  /// by hand (or, in the wild, where the field has them).
  List<SpawnPoint> get _outcrops => [
    ..._perched,
    if (_placed)
      ..._piecesOn(floor, {FieldPiece.outcrop})
    else
      for (var i = 0; i < _wildRocks.length; i++)
        SpawnPoint(
          id: 'dunes_rock_$i',
          normalizedPos: Offset(_wildRocks[i].$1, 0),
          anchor: floor,
          size: Vector2(_wildRocks[i].$2, _wildRocks[i].$3),
          piece: FieldPiece.outcrop,
        ),
  ];

  /// A wind-cut rock under a high point, its flat top at the creature's
  /// feet — or one placed in the sand, as tall and wide as its piece says.
  ({double x, double top, double base, double w}) _outcropShape(SpawnPoint p) {
    final x = _spawnX(p);
    final base = _groundLine(x) + 0.032 * _h;
    if (p.piece == FieldPiece.outcrop) {
      return (x: x, top: base - p.size.y * _u, base: base, w: p.size.x * _u);
    }
    final top = _feet(p);
    final w = math.max(p.size.x * 1.3, (base - top) * 1.1);
    return (x: x, top: top, base: base, w: w);
  }

  Rect _outcropBounds(SpawnPoint p) {
    final o = _outcropShape(p);
    return Rect.fromLTRB(
      o.x - o.w * 1.1,
      o.top - 10 * _u,
      o.x + o.w * 1.1,
      o.base + 8 * _u,
    );
  }

  /// Sandstone cut by the wind: a broad cap on a waist the sand has worn
  /// thin, flaring out again to its foot, in bands of harder and softer
  /// rock. With [sparks], only the light along its top.
  void _outcrop(Canvas c, GrainBatch? sparks, SpawnPoint p) {
    final o = _outcropShape(p);
    final h = o.base - o.top;
    final w = o.w;
    final seed = fieldSeedOf(p.id);
    Offset at(double fx, double fy) => Offset(o.x + fx * w, o.top + fy * h);
    // A block of rock rounded by the wind: a flat top a little irregular,
    // sides undercut a touch where the blown sand wears hardest, and a foot
    // spreading into the drift.
    final pts = <Offset>[
      at(-0.47, 0.05),
      at(-0.36, 0.0),
      at(-0.05, 0.015),
      at(0.22, 0.0),
      at(0.44, 0.03),
      at(0.5, 0.12),
      at(0.47, 0.3),
      at(0.41, 0.52),
      at(0.44, 0.74),
      at(0.55, 1.0),
      at(-0.56, 1.0),
      at(-0.45, 0.76),
      at(-0.42, 0.52),
      at(-0.49, 0.3),
      at(-0.52, 0.14),
    ];
    final outline = Path()..moveTo(pts.last.dx, pts.last.dy);
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i], z = pts[(i + 1) % pts.length];
      final m = Offset.lerp(a, z, 0.5)!;
      outline.quadraticBezierTo(a.dx, a.dy, m.dx, m.dy);
    }
    outline.close();
    if (sparks == null) {
      c.drawPath(outline, Paint()..color = fieldMap(0.02, 0, 0.12));
      c
        ..save()
        ..clipPath(outline);
      // Strata: bands of rock, a shade apart.
      var y = 0.12;
      var k = 0;
      while (y < 1) {
        final band = 0.06 + fieldHash(k, seed) * 0.1;
        c.drawRect(
          Rect.fromLTRB(
            o.x - w,
            o.top + y * h,
            o.x + w,
            o.top + (y + band) * h,
          ),
          Paint()
            ..color = fieldMap(0.02, 0, 0.08 + 0.22 * fieldHash(k + 3, seed)),
        );
        y += band + 0.02;
        k++;
      }
      // The waist in shade under the cap, and the right side.
      c
        ..drawRect(
          Rect.fromLTRB(o.x - w, o.top + 0.1 * h, o.x + w, o.top + 0.45 * h),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, o.top + 0.1 * h),
              Offset(0, o.top + 0.45 * h),
              [fieldMap(0.02, 0, 0.75, 0.75), fieldMap(0.02, 0, 0.3, 0)],
            ),
        )
        ..drawRect(
          Rect.fromLTRB(o.x + w * 0.12, o.top, o.x + w, o.base),
          Paint()..color = fieldMap(0.02, 0, 0.5, 0.45),
        );
      // The flat top, lit.
      c.drawRect(
        Rect.fromLTRB(o.x - w * 0.5, o.top, o.x + w * 0.52, o.top + 0.06 * h),
        Paint()..color = fieldMap(0.02, 0.3, 0.02),
      );
      c.restore();
      return;
    }
    final n = (w / (1.6 * _u)).ceil();
    for (var i = 0; i <= n; i++) {
      final roll = fieldHash(i, seed);
      if (roll > 0.7) continue;
      final q = Offset.lerp(at(-0.36, 0.01), at(0.42, 0.03), i / n)!;
      sparks.add((roll * 5).floor().clamp(0, 3), q.dx, q.dy + 0.6 * _u);
      if (roll < 0.06) _glint(q.dx, q.dy + 0.6 * _u);
    }
  }

  // ── Live ─────────────────────────────────────────────────────────────────

  @override
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  }) {
    switch (layer) {
      case far:
        _paintSparkles(
          canvas,
          view,
          far,
          _glints[far],
          size: 0.8,
          alpha: _glassShine * 0.6,
        );
        _paintStormDust(canvas, view, far, _farDust);
      case dunes:
        _paintSparkles(canvas, view, dunes, _glints[dunes], alpha: _glassShine);
        _paintSpindrift(canvas, view);
        _paintDevil(canvas, view);
        _paintStormDust(canvas, view, dunes, _midDust);
      case floor:
        if (!front) {
          _stirSand(view);
          _paintFurrows(canvas, view);
          _paintSand(canvas, view);
          _paintSparkles(
            canvas,
            view,
            floor,
            _glints[floor],
            alpha: _glassShine,
          );
          _paintSparkles(
            canvas,
            view,
            floor,
            _glass,
            size: 1.1,
            alpha: aftermath * (1 - storm),
          );
          final scrub = _scrub;
          if (scrub != null) {
            _stirBlades(
              scrub,
              floor,
              _floorWidth,
              view,
              reach: 30 * _u,
              maxBend: 0.9,
            );
            _paintBlades(
              canvas,
              view,
              scrub,
              _floorWidth,
              rows: (1, 3),
              fore: false,
              layer: floor,
            );
          }
        } else {
          _flySand(view);
          _paintFlying(canvas);
          _paintStormDust(canvas, view, floor, _nearDust);
        }
      case fore:
        final scrub = _foreScrub;
        if (scrub != null) {
          _stirBlades(
            scrub,
            fore,
            _foreWidth,
            view,
            reach: 46 * _u,
            maxBend: 0.8,
          );
          _paintBlades(
            canvas,
            view,
            scrub,
            _foreWidth,
            rows: (0, 0),
            fore: true,
            layer: fore,
          );
        }
        _paintLipDrift(canvas, view);
      default:
        break;
    }
  }

  /// How brightly the glass in the sand glitters: a little by day, most
  /// under the moon, hardly at all through a storm.
  double get _glassShine =>
      (0.3 + 0.7 * _light.stars.clamp(0.0, 1.0)) * (1 - 0.85 * storm);

  final GrainBatch _driftBatch = GrainBatch(3);

  /// Sand streaming off the great dunes' crests, downwind, thrown up and
  /// settling onto the slipface: harder in a gust, a plume in a storm.
  void _paintSpindrift(Canvas canvas, FieldView view) {
    if (_duneCrests.isEmpty) return;
    final t = view.time;
    _driftBatch.clear();
    var any = false;
    for (final shift in _shiftsFor(dunes, view, 80 * _u)) {
      for (final (xc0, i) in _duneCrests) {
        final xc = xc0 + shift;
        if (xc < view.left - 80 * _u || xc > view.right + 20 * _u) continue;
        final (_, gust) = _wind(xc0, t, _duneWidth);
        final strength = 0.3 + 0.7 * gust + 1.6 * storm;
        final yc = _dune(xc0);
        final n = (16 * strength).round();
        final len = (34 + 30 * gust + 60 * storm) * _u;
        for (var j = 0; j < n; j++) {
          final h0 = fieldHash(j, i * 31 + 7);
          final h1 = fieldHash(j, i * 31 + 9);
          final ph = (h0 + t * (0.45 + 0.4 * h1)) % 1;
          final x = xc + ph * len * (0.5 + 0.5 * h1);
          final y =
              yc -
              math.sin(ph * math.pi) * (3 + 6 * h0) * _u * (1 + storm) +
              ph * ph * 12 * _u;
          final level = ((1 - ph) * 2.99).floor();
          _driftBatch.add(level, x, y);
          any = true;
        }
      }
    }
    if (!any) return;
    for (var lv = 0; lv < 3; lv++) {
      _driftBatch.draw(
        canvas,
        lv,
        1.25 * _u,
        _sandTones[3].withValues(alpha: 0.22 + 0.22 * lv),
      );
    }
  }

  /// Sand lifting off the near dunes' lips, the same way.
  void _paintLipDrift(Canvas canvas, FieldView view) {
    if (_lipCrests.isEmpty) return;
    final t = view.time;
    _driftBatch.clear();
    var any = false;
    for (final shift in _shiftsFor(fore, view, 120 * _u)) {
      for (var i = 0; i < _lipCrests.length; i++) {
        final (cx0, hw, ht) = _lipCrests[i];
        final xc = cx0 + shift;
        if (xc < view.left - 120 * _u || xc > view.right + 20 * _u) continue;
        final (_, gust) = _wind(cx0, t, _foreWidth);
        final n = (18 * (0.25 + 0.75 * gust + 1.5 * storm)).round();
        final yc = _h + 4 * _u - ht;
        for (var j = 0; j < n; j++) {
          final h0 = fieldHash(j, i * 53 + 3);
          final h1 = fieldHash(j, i * 53 + 5);
          final ph = (h0 + t * (0.5 + 0.45 * h1)) % 1;
          final x = xc + ph * (60 + 50 * h1) * _u;
          final y =
              yc -
              math.sin(ph * math.pi) * (5 + 9 * h0) * _u +
              ph * ph * 20 * _u;
          _driftBatch.add(((1 - ph) * 2.99).floor(), x, y);
          any = true;
        }
      }
    }
    if (!any) return;
    for (var lv = 0; lv < 3; lv++) {
      _driftBatch.draw(
        canvas,
        lv,
        2.0 * _u,
        _sandTones[2].withValues(alpha: 0.2 + 0.2 * lv),
      );
    }
  }

  // ── The dust devil ───────────────────────────────────────────────────────

  final GrainBatch _devilBatch = GrainBatch(3);

  /// How long between dust devils, and how long one lasts.
  static const _devilCycle = 75.0, _devilLife = 30.0;

  /// On a clear day, every so often, a dust devil spins up on the great
  /// dunes, wanders along them, and dies away: a column of grains turning,
  /// narrow at the foot, flaring at the top, leaning with the wind.
  void _paintDevil(Canvas canvas, FieldView view) {
    final day = (_sunUp * 3).clamp(0.0, 1.0) * (1 - storm);
    if (day < 0.05) return;
    final t = view.time + 12; // the first one comes soon after arriving
    final round = (t / _devilCycle).floor();
    final age = t - round * _devilCycle;
    if (age > _devilLife) return;
    final life = age / _devilLife;
    final fade = math.min(1.0, life * 5) * math.min(1.0, (1 - life) * 5) * day;
    if (fade < 0.02) return;
    // Where it walks: from somewhere in view as it spins up, along the
    // dunes.
    final w = _duneWidth;
    final start =
        view.left +
        (view.right - view.left) * (0.2 + 0.6 * fieldHash(round, 9001));
    final cx0 = start + age * 9 * _u;
    final local = w > 0 ? cx0 % w : cx0;
    final base = _dune(local) + 4 * _u;
    final height = (95 + 30 * fieldHash(round, 9003)) * _u;
    final (wind, _) = _wind(local, view.time, w);
    _devilBatch.clear();
    final n = (520 * fade).round();
    final tt = view.time;
    for (var i = 0; i < n; i++) {
      final f = math.pow(fieldHash(i, 9011), 0.8).toDouble();
      final y = base - f * height;
      final rad = (2.5 + 20 * math.pow(f, 1.4)) * _u;
      final spin = 5.5 - 3 * f;
      final a = tt * spin + fieldHash(i, 9013) * math.pi * 2;
      final lean =
          wind * 30 * _u * f * f + math.sin(tt * 0.7 + f * 3) * 5 * _u * f;
      final x = cx0 + lean + math.cos(a) * rad;
      final depth = math.sin(a); // near side brighter
      // Thinner at the top: some grains there are not drawn at all.
      if (fieldHash(i, 9017) > 1 - f * 0.6 + 0.4) continue;
      _devilBatch.add(depth > 0.3 ? 2 : (depth > -0.4 ? 1 : 0), x, y);
    }
    // Shaded sand against the bright sky, a little hazed with distance.
    final col = Color.lerp(_sandTones[0], _light.skyAt(0.5), 0.15)!;
    for (var lv = 0; lv < 3; lv++) {
      _devilBatch.draw(
        canvas,
        lv,
        1.35 * _u,
        col.withValues(alpha: (0.3 + 0.22 * lv) * fade),
      );
    }
    // Sand kicked up round its foot.
    _devilBatch.clear();
    for (var i = 0; i < 40; i++) {
      final a = tt * 4 + i * 0.9;
      _devilBatch.add(
        0,
        cx0 + math.cos(a) * (8 + 10 * fieldHash(i, 9021)) * _u,
        base - fieldHash(i, 9023) * 8 * _u,
      );
    }
    _devilBatch.draw(canvas, 0, 1.6 * _u, col.withValues(alpha: 0.3 * fade));
  }

  // ── The sandstorm ────────────────────────────────────────────────────────

  static const _farDust = (
    seed: 6101,
    perTile: 70,
    size: 0.8,
    alpha: 0.35,
    speed: 140.0,
    top: 0.42,
    bottom: 0.76,
  );
  static const _midDust = (
    seed: 6103,
    perTile: 90,
    size: 1.4,
    alpha: 0.5,
    speed: 260.0,
    top: 0.2,
    bottom: 0.92,
  );
  static const _nearDust = (
    seed: 6105,
    perTile: 70,
    size: 2.1,
    alpha: 0.55,
    speed: 520.0,
    top: 0.0,
    bottom: 1.04,
  );

  /// The sandstorm: a wash of dust over the layer, and sand driving
  /// across it in skeins, rising and dipping as it goes.
  void _paintStormDust(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    ({
      int seed,
      int perTile,
      double size,
      double alpha,
      double speed,
      double top,
      double bottom,
    })
    d,
  ) {
    final st = storm;
    if (st < 0.02) return;
    final l = _light;
    final dust = l.skyAt(0.5);
    canvas.drawRect(
      Rect.fromLTRB(view.left, _h * d.top, view.right, _h * d.bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _h * d.top),
          Offset(0, _h * d.bottom),
          [
            dust.withValues(alpha: 0),
            dust.withValues(alpha: 0.32 * st),
            dust.withValues(alpha: 0.18 * st),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    final p = _period(layer);
    final tiles = p > 0 ? math.max(1, (p / (300 * _u)).round()) : 0;
    final s = tiles > 0 ? p / tiles : 300 * _u;
    final t = view.time;
    final top = _h * d.top, span = _h * (d.bottom - d.top);
    final k0 = ((view.left - 120 * _u) / s).floor();
    final k1 = ((view.right + 20 * _u) / s).floor();
    // Billows of dust rolling through, each a soft body of it.
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < 3; i++) {
        final h0 = fieldHash(i, d.seed + 50 + kk * 17);
        final h1 = fieldHash(i, d.seed + 51 + kk * 17);
        final ph = (h1 + t * d.speed * 0.35 * _u / s) % 1;
        final c = Offset((k + ph) * s, top + span * (0.3 + 0.6 * h0));
        final r = (60 + 90 * h1) * _u * d.size;
        final a = 0.34 * st * math.sin(ph * math.pi);
        canvas.drawOval(
          Rect.fromCenter(center: c, width: r * 2.6, height: r * 1.3),
          Paint()
            ..shader = Gradient.radial(
              c,
              r * 1.3,
              [
                dust.withValues(alpha: a),
                dust.withValues(alpha: a * 0.45),
                dust.withValues(alpha: 0),
              ],
              const [0.0, 0.5, 1.0],
            ),
        );
      }
    }
    // Sand driving across in skeins: short streaks, rising and dipping.
    final n = (d.perTile * 3 * st).round();
    _gustN.fillRange(0, 3, 0);
    final len = 2.6 * _u * d.size;
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      for (var i = 0; i < n; i++) {
        final h0 = fieldHash(i, d.seed + kk * 131);
        final h1 = fieldHash(i, d.seed + kk * 131 + 7);
        final ph = (h1 + t * d.speed * _u / s * (0.75 + 0.5 * h0)) % 1;
        final x = (k + ph) * s;
        final wave = t * (1.2 + h1 * 1.6) + h0 * 30 + ph * 6;
        final y = top + h0 * span + math.sin(wave) * 7 * _u;
        final dy = math.cos(wave) * 1.6 * _u;
        // Faint where it crosses into the next stretch, so the join is
        // never seen.
        final level = (math.sin(ph * math.pi) * 2.99).floor();
        final l = len * (0.6 + 0.8 * h1);
        _gust(level, x, y, x - l, y - dy);
      }
    }
    final col = Color.lerp(dust, const Color(0xFFFFE8C8), 0.35)!;
    for (var lv = 0; lv < 3; lv++) {
      final m = _gustN[lv];
      if (m == 0) continue;
      _gustPaint
        ..strokeWidth = d.size * _u * (0.5 + 0.12 * lv)
        ..color = col.withValues(alpha: d.alpha * st * (0.12 + 0.16 * lv));
      canvas.drawRawPoints(
        PointMode.lines,
        Float32List.sublistView(_gusts[lv], 0, m * 4),
        _gustPaint,
      );
    }
  }

  final List<Float32List> _gusts = List.generate(3, (_) => Float32List(512));
  final List<int> _gustN = [0, 0, 0];
  static final Paint _gustPaint = Paint()
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void _gust(int level, double x0, double y0, double x1, double y1) {
    var buf = _gusts[level];
    final i = _gustN[level] * 4;
    if (i + 4 > buf.length) {
      _gusts[level] = buf = Float32List(buf.length * 2)..setAll(0, buf);
    }
    buf
      ..[i] = x0
      ..[i + 1] = y0
      ..[i + 2] = x1
      ..[i + 3] = y1;
    _gustN[level]++;
  }
}

/// A groove ploughed through the sand, or a crater blown in it, in the
/// floor's units as the finger made it.
class _Furrow {
  _Furrow(Offset at, this.last, {required this.tap}) : pts = [at];
  final List<Offset> pts;
  double last;
  final bool tap;
}

/// The floor's loose sand, sorted by home x, so a frame walks only what it
/// can see and a finger only what it can reach.
class _Sand {
  _Sand(this.n)
    : hx = Float32List(n),
      hy = Float32List(n),
      dx = Float32List(n),
      dy = Float32List(n),
      vx = Float32List(n),
      vy = Float32List(n),
      kind = Uint8List(n);

  final int n;
  final Float32List hx, hy, dx, dy, vx, vy;

  /// Tone × 3 + size: its batch.
  final Uint8List kind;

  /// The grains still moving or not yet home, as an index range (empty when
  /// hi < lo), the time they were last moved, and the newest finger sample
  /// taken in.
  int lo = 0, hi = -1;
  double clock = -1;
  double seen = -1;

  /// Puts the grains back in order of home x.
  void sort() {
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => hx[a].compareTo(hx[b]));
    final x = Float32List.fromList([for (final i in order) hx[i]]);
    final y = Float32List.fromList([for (final i in order) hy[i]]);
    final k = Uint8List.fromList([for (final i in order) kind[i]]);
    hx.setAll(0, x);
    hy.setAll(0, y);
    kind.setAll(0, k);
  }

  int firstAt(double left) {
    var lo = 0, hi = n;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (hx[mid] < left) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}

// ── The Dunes' day ─────────────────────────────────────────────────────────

const _dunesNight = _Light(
  sky: [
    Color(0xFF03040C),
    Color(0xFF060918),
    Color(0xFF0B1026),
    Color(0xFF111733),
    Color(0xFF181E3E),
    Color(0xFF1E2445),
    Color(0xFF252A4B),
    Color(0xFF2B2F50),
    Color(0xFF2B2F50),
  ],
  ambient: Color(0xFF2C3150),
  rim: Color(0xFFBCC8F0),
  rimStrength: 0.2,
  floor: 0.4,
  glow: 0,
  stars: 1,
  cloudTop: Color(0xFF0C1222),
  cloudBottom: Color(0xFF1C2640),
  cloudGlint: Color(0xFF7E92BE),
  grass: [
    Color(0xFF07080C),
    Color(0xFF0B0C12),
    Color(0xFF111219),
    Color(0xFF181A23),
    Color(0xFF22242F),
    Color(0xFF30333F),
    Color(0xFF474A5A),
    Color(0xFF6E7488),
  ],
  mote: Color(0xFFDCE6FF),
  firefly: 0,
);

const _dunesDawn = _Light(
  sky: [
    Color(0xFF0E1432),
    Color(0xFF1A2246),
    Color(0xFF2C325C),
    Color(0xFF48446C),
    Color(0xFF745876),
    Color(0xFFA86E7A),
    Color(0xFFD28C80),
    Color(0xFFE8A888),
    Color(0xFFE8A888),
  ],
  ambient: Color(0xFF5E5266),
  rim: Color(0xFFFFB4A2),
  rimStrength: 0.6,
  floor: 0.12,
  glow: 0.6,
  stars: 0.25,
  cloudTop: Color(0xFF3A3F62),
  cloudBottom: Color(0xFFD89A98),
  cloudGlint: Color(0xFFFFC8C0),
  grass: [
    Color(0xFF110E10),
    Color(0xFF191416),
    Color(0xFF241C1C),
    Color(0xFF322622),
    Color(0xFF46342A),
    Color(0xFF644A38),
    Color(0xFF8E6A52),
    Color(0xFFC8987A),
  ],
  mote: Color(0xFFFFD6C8),
  firefly: 0,
);

const _dunesSunrise = _Light(
  sky: [
    Color(0xFF223A6C),
    Color(0xFF30508A),
    Color(0xFF4A68A2),
    Color(0xFF7A88B0),
    Color(0xFFBA9EA4),
    Color(0xFFEAB48A),
    Color(0xFFFFCC90),
    Color(0xFFFFDCA4),
    Color(0xFFFFDCA4),
  ],
  ambient: Color(0xFFA08672),
  rim: Color(0xFFFFCC88),
  rimStrength: 1,
  floor: 0.08,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF6E7898),
  cloudBottom: Color(0xFFFFC898),
  cloudGlint: Color(0xFFFFE6B0),
  grass: [
    Color(0xFF1A140E),
    Color(0xFF261C12),
    Color(0xFF362818),
    Color(0xFF4A3820),
    Color(0xFF654C2A),
    Color(0xFF886636),
    Color(0xFFB88C4C),
    Color(0xFFF0C27A),
  ],
  mote: Color(0xFFFFE6AC),
  firefly: 0,
);

const _dunesMorning = _Light(
  sky: [
    Color(0xFF2E62A2),
    Color(0xFF3E72B0),
    Color(0xFF5A8ABE),
    Color(0xFF82A6CC),
    Color(0xFFAAC0D4),
    Color(0xFFCCD2D6),
    Color(0xFFE2DCD0),
    Color(0xFFECE2D0),
    Color(0xFFECE2D0),
  ],
  ambient: Color(0xFFE6D8C2),
  rim: Color(0xFFFFF0D6),
  rimStrength: 0.42,
  floor: 0.45,
  glow: 0.5,
  stars: 0,
  cloudTop: Color(0xFFF4F4F2),
  cloudBottom: Color(0xFFB8C2D0),
  cloudGlint: Color(0xFFC0A070),
  grass: [
    Color(0xFF241C12),
    Color(0xFF322616),
    Color(0xFF42341C),
    Color(0xFF564424),
    Color(0xFF6E5830),
    Color(0xFF8A7040),
    Color(0xFFAC8E56),
    Color(0xFFD4B884),
  ],
  mote: Color(0xFFFFF6DC),
  firefly: 0,
);

const _dunesDay = _Light(
  sky: [
    Color(0xFF2E66AA),
    Color(0xFF4078B6),
    Color(0xFF5C90C2),
    Color(0xFF84AACE),
    Color(0xFFAEC4D6),
    Color(0xFFCED6DA),
    Color(0xFFE4DED2),
    Color(0xFFEEE4D2),
    Color(0xFFEEE4D2),
  ],
  ambient: Color(0xFFFFF4E6),
  rim: Color(0xFFFFFFFF),
  rimStrength: 0.3,
  floor: 0.8,
  glow: 0.4,
  stars: 0,
  cloudTop: Color(0xFFFBFCFE),
  cloudBottom: Color(0xFFBCC8D6),
  cloudGlint: Color(0xFFB89A62),
  grass: [
    Color(0xFF281E12),
    Color(0xFF362818),
    Color(0xFF48361E),
    Color(0xFF5E4826),
    Color(0xFF786032),
    Color(0xFF967A42),
    Color(0xFFBA9A5C),
    Color(0xFFE2C890),
  ],
  mote: Color(0xFFFFF8E4),
  firefly: 0,
);

const _dunesGolden = _Light(
  sky: [
    Color(0xFF12224A),
    Color(0xFF1E345E),
    Color(0xFF324872),
    Color(0xFF5C5C82),
    Color(0xFFA27E7C),
    Color(0xFFDE9866),
    Color(0xFFF4B262),
    Color(0xFFFFCE88),
    Color(0xFFFFCE88),
  ],
  ambient: Color(0xFF7C5E48),
  rim: Color(0xFFFFC27A),
  rimStrength: 1,
  floor: 0.05,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF2C3354),
  cloudBottom: Color(0xFFE8A67C),
  cloudGlint: Color(0xFFFFDDA0),
  grass: [
    Color(0xFF140E0A),
    Color(0xFF1E150E),
    Color(0xFF2A1E12),
    Color(0xFF3A2A18),
    Color(0xFF543C20),
    Color(0xFF7C582C),
    Color(0xFFB4823E),
    Color(0xFFF2BC6E),
  ],
  mote: Color(0xFFFFE1A0),
  firefly: 0,
);

const _dunesSunset = _Light(
  sky: [
    Color(0xFF0C1436),
    Color(0xFF161E4A),
    Color(0xFF2A2A5C),
    Color(0xFF4C3868),
    Color(0xFF8C4C68),
    Color(0xFFCE5E58),
    Color(0xFFEE824E),
    Color(0xFFFFA056),
    Color(0xFFFFA056),
  ],
  ambient: Color(0xFF4C3236),
  rim: Color(0xFFFF9A58),
  rimStrength: 0.95,
  floor: 0.05,
  glow: 1,
  stars: 0.05,
  cloudTop: Color(0xFF22284A),
  cloudBottom: Color(0xFFF08A66),
  cloudGlint: Color(0xFFFFC08A),
  grass: [
    Color(0xFF0E0A0A),
    Color(0xFF15100E),
    Color(0xFF1E1612),
    Color(0xFF2A1E16),
    Color(0xFF3E2A1C),
    Color(0xFF603C24),
    Color(0xFF965430),
    Color(0xFFDC804A),
  ],
  mote: Color(0xFFFFC890),
  firefly: 0,
);

const _dunesDusk = _Light(
  sky: [
    Color(0xFF050A1C),
    Color(0xFF0A102A),
    Color(0xFF13193C),
    Color(0xFF20214A),
    Color(0xFF332854),
    Color(0xFF4A3256),
    Color(0xFF623E58),
    Color(0xFF6C445E),
    Color(0xFF6C445E),
  ],
  ambient: Color(0xFF2E2840),
  rim: Color(0xFFE29CA2),
  rimStrength: 0.28,
  floor: 0.22,
  glow: 0.4,
  stars: 0.55,
  cloudTop: Color(0xFF121628),
  cloudBottom: Color(0xFF3E3550),
  cloudGlint: Color(0xFFA88090),
  grass: [
    Color(0xFF08080C),
    Color(0xFF0C0C12),
    Color(0xFF121218),
    Color(0xFF1A1920),
    Color(0xFF26232C),
    Color(0xFF36303C),
    Color(0xFF524452),
    Color(0xFF7E6676),
  ],
  mote: Color(0xFFE6D6F0),
  firefly: 0,
);

/// The day, keyed by hour. The night window lines up with the encounter
/// tables' (20:00–05:00).
const _dunesKeys = <(double, _Light)>[
  (0, _dunesNight),
  (4.6, _dunesNight),
  (5.5, _dunesDawn),
  (6.4, _dunesSunrise),
  (8.0, _dunesMorning),
  (10.2, _dunesDay),
  (15.8, _dunesDay),
  (18.4, _dunesGolden),
  (19.3, _dunesSunset),
  (20.1, _dunesDusk),
  (21.0, _dunesNight),
  (24, _dunesNight),
];
