part of 'grain_field.dart';

// The Tidal Shelf, through the day.
//
// A shelf of black basalt columns at the edge of the open sea. Far off, sea
// stacks stand in the haze and the sun (or the moon) lays a path of light
// across the water toward you. Nearer, a reef of columns takes the surf; the
// far creatures stand on its column tops. The near shelf is columns too,
// standing out of a flat of wet sand, and the tide comes and goes over the
// flat on the real clock — twice a day, high water flooding it to the
// shelf's feet, low water leaving it bare with pools in it where anemones
// open. A finger drawn through the water leaves a wake; tap a pool and its
// anemones close. After dark the sea is alive with light: the surf glows
// blue where it breaks, and so does a wake. Sea fog comes in some days and
// takes the horizon; a swell some days throws the surf up the columns, and
// the first clear low water after it finds shells and glass floats left on
// the sand.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, stars
//   layer2  — the open sea to the horizon, the sea stacks, the light path
//   layer3  — the reef and the nearer sea, the surf
//   layer4  — the near shelf: its columns, the flat, the tide, the pools
//   layer5  — column tops nearest of all, kelp, spray

class TidalField extends _GrainField {
  TidalField();

  static const far = SceneLayer.layer2;
  static const reef = SceneLayer.layer3;
  static const shelf = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  /// The tide pinned for previews and tests (0 low water, 1 high), or null
  /// for the real one.
  static double? debugTide;

  static const _gSea = 0, _gSeaNear = 1, _gStack = 2, _gBasalt = 3;
  static const _gFlat = 4, _gReef = 5;

  static const _albedo = <int, Color>{
    _gSea: Color(0xFF2C5068),
    _gSeaNear: Color(0xFF244458),
    _gStack: Color(0xFF4A4C56),
    _gBasalt: Color(0xFF3E414A),
    _gFlat: Color(0xFF6A6252),
    _gReef: Color(0xFF42454E),
  };

  @override
  List<(double, _Light)> get _keys => _valleyKeys;

  @override
  double get _horizon => 0.52;

  @override
  int get _starCount => 200;

  @override
  double get _starDepth => 0.5;

  /// Where the sea meets the sky, as a share of the height.
  static const _seaTop = 0.52;

  // ── The tide ─────────────────────────────────────────────────────────────

  /// The tide now, 0 at low water and 1 at high: twice a day, on the
  /// moon's clock.
  double get tide => debugTide ?? tideAt(DateTime.now());

  /// The tide at [when], 0 at low water and 1 at high — what the field
  /// draws and what the spawns go by.
  static double tideAt(DateTime when) {
    final hours = when.toUtc().millisecondsSinceEpoch / 3600000.0;
    return 0.5 + 0.5 * math.cos(hours / 12.4206 * 2 * math.pi);
  }

  /// Where the water reaches up the flat, in the shelf's units: the far edge
  /// of the flat at low water, nearly to the bottom of the screen at high.
  double get _waterline => _h * (0.815 + 0.13 * tide);

  // ── Weather ──────────────────────────────────────────────────────────────

  double get fog => weatherKind == WeatherKind.fog ? weather : 0;
  double get swell => weatherKind == WeatherKind.swell ? weather : 0;

  /// What a swell leaves on the sand: shells and glass, at the next clear
  /// visit.
  double get _wrack => aftermath * (1 - swell);

  @override
  double get _weatherKey =>
      (fog * 1000).roundToDouble() + (swell * 1000).roundToDouble() * 1000;

  @override
  double get _veil => 0.85 * fog + 0.6 * swell;

  @override
  double get _windScale => 1 + 1.4 * swell;

  /// Fog: the light gone soft and grey, the stars and sun lost in it. A
  /// swell: the sky lowered and dark over a heavy sea.
  @override
  _Light _weathered(_Light l) {
    final f = fog, s = swell;
    if (f <= 0.001 && s <= 0.001) return l;
    Color grey(Color c, double dark) {
      final g = math.sqrt(c.computeLuminance());
      final to = Color.lerp(
        const Color(0xFF1A2026),
        const Color(0xFFB4BCC4),
        g,
      )!;
      return Color.from(
        alpha: 1,
        red: to.r * dark,
        green: to.g * dark,
        blue: to.b * dark,
      );
    }

    final k = math.max(0.85 * f, 0.7 * s);
    final dark = 1 - 0.25 * s;
    Color w(Color c, double d) => Color.lerp(c, grey(c, d * dark), k)!;
    return _Light(
      stops: l.stops,
      sky: [for (final c in l.sky) w(c, 0.95)],
      ambient: w(l.ambient, 0.75),
      rim: Color.lerp(l.rim, const Color(0xFFD8E0E8), k)!,
      rimStrength: l.rimStrength * (1 - 0.7 * k),
      floor: l.floor + (math.max(0.7, l.floor) - l.floor) * k,
      glow: l.glow * (1 - 0.8 * k),
      stars: l.stars * (1 - 0.95 * k),
      cloudTop: w(l.cloudTop, 0.7),
      cloudBottom: w(l.cloudBottom, 0.8),
      cloudGlint: l.cloudGlint,
      grass: [for (final c in l.grass) w(c, 0.8)],
      mote: l.mote,
      firefly: 0,
    );
  }

  // ── The hour's colors ───────────────────────────────────────────────────

  /// How dark the hour is: 1 at night. The sea lights up with it.
  double _night = 0;

  /// The water's colors for the live parts: deep, shallow over the flat,
  /// foam, and the sea's own light after dark.
  Color _seaMid = const Color(0xFF000000),
      _deep = const Color(0xFF000000),
      _shallow = const Color(0xFF000000),
      _foam = const Color(0xFFFFFFFF),
      _lip = const Color(0xFFFFFFFF),
      _face = const Color(0xFF000000),
      _sheen = const Color(0xFF000000),
      _seaNear = const Color(0xFF000000),
      _hazeLow = const Color(0xFF000000);
  static const _glow = Color(0xFF6CF2FF);

  @override
  void _buildGrades(_Light l) {
    final lum = l.ambient.computeLuminance();
    // The sea's light shows once the stars are out, not at dusk.
    _night = ((l.stars - 0.3) / 0.6).clamp(0.0, 1.0);
    assert(lum >= 0);
    final hazeHigh = l.skyAt(0.5), hazeLow = l.skyAt(0.585);
    final f = fog;
    Color sil(int g) {
      final a = _albedo[g]!;
      var s = Color.from(
        alpha: 1,
        red: a.r * l.ambient.r,
        green: a.g * l.ambient.g,
        blue: a.b * l.ambient.b,
      );
      // Water gives back the sky over it.
      if (g == _gSea || g == _gSeaNear) {
        s = Color.lerp(
          s,
          l.skyAt(g == _gSea ? 0.5 : 0.4),
          g == _gSea ? 0.72 : 0.5,
        )!;
      }
      if (f > 0) {
        final k = switch (g) {
          _gSea || _gStack => 0.9,
          _gSeaNear || _gReef => 0.6,
          _ => 0.25,
        };
        s = Color.lerp(s, hazeLow, f * k)!;
      }
      return s;
    }

    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.8 + l.rim.r * l.rimStrength * k,
      s.g * 0.8 + l.rim.g * l.rimStrength * k,
      s.b * 0.8 + l.rim.b * l.rimStrength * k,
    );
    for (final g in [_gSea, _gStack]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeHigh, s),
        g: fleck(s, 0.5),
        b: fieldScale(s, -0.6),
      );
    }
    for (final g in [_gSeaNear, _gBasalt, _gFlat, _gReef]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.45),
        b: fieldScale(s, -0.75),
      );
    }
    final sea = sil(_gSeaNear);
    _seaNear = sea;
    _hazeLow = hazeLow;
    // The near sea's own color where the swimmers are, a third of the way
    // down it, as it is baked: what is drawn over them must match it.
    _seaMid = Color.from(
      alpha: 1,
      red: sea.r * 0.6 + hazeLow.r * 0.16,
      green: sea.g * 0.6 + hazeLow.g * 0.16,
      blue: sea.b * 0.6 + hazeLow.b * 0.16,
    );
    final sky = l.skyAt(0.4);
    _deep = Color.lerp(sea, sky, 0.12)!;
    _shallow = Color.lerp(sil(_gFlat), sea, 0.55)!;
    _foam = Color.lerp(
      Color.lerp(l.ambient, const Color(0xFFFFFFFF), 0.5)!,
      const Color(0xFFDDE8F0),
      0.3,
    )!;
    // A wave's lit lip gives back the sky low over the sea; its face,
    // turned to you, is the sea gone darker; wet sand gives back the sky.
    _lip = Color.lerp(l.skyAt(0.48), _foam, 0.2)!;
    _face = Color.lerp(_deep, const Color(0xFF000000), 0.35)!;
    _sheen = Color.lerp(l.skyAt(0.42), _shallow, 0.45)!;
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// Every ground point, on the reef or the shelf, stands on a column top
  /// at its feet; so does each one's encounter partner.
  List<({String id, SceneLayer layer, double x, double top, double hw})>
  _platforms = const [];

  /// The basalt standing for scenery: where the wild has it, or where the
  /// player put it.
  static const _wildBasalt = <(SceneLayer, double, double, double)>[
    // (layer, x as a share of its loop, half width, height above the flat)
    // On the shelf: a great stepped headland mid-loop, a lower causeway
    // late, a small stand early.
    (SceneLayer.layer4, 0.255, 30, 46),
    (SceneLayer.layer4, 0.48, 74, 128),
    (SceneLayer.layer4, 0.985, 84, 84),
    // On the reef: stands rising out of the surf.
    (SceneLayer.layer3, 0.08, 34, 58),
    (SceneLayer.layer3, 0.42, 30, 44),
    (SceneLayer.layer3, 0.83, 40, 70),
    (SceneLayer.layer3, 0.95, 24, 40),
  ];

  /// The basalt as the home biome first has it: (far row?, x, half width,
  /// height).
  static List<(bool, double, double, double)> get homeBasalt => [
    for (final (l, x, hw, h) in _wildBasalt) (l == SceneLayer.layer3, x, hw, h),
  ];

  void _makePlatforms() {
    final out =
        <({String id, SceneLayer layer, double x, double top, double hw})>[];
    for (final p in _spawns) {
      if (p.anchor != reef && p.anchor != shelf) continue;
      final x = _spawnX(p);
      final hw = p.size.x * (p.anchor == reef ? 0.42 : 0.4) * _u;
      // One over the sea needs none of its own — but its partner, who may
      // not float, does.
      if (!p.aloft && p.perch != SpawnPerch.wade && !_shares(p)) {
        final (mid, extra) = _sharedSpan(p, x);
        out.add((
          id: p.id,
          layer: p.anchor,
          x: mid,
          top: _feet(p),
          hw: hw + extra,
        ));
      }
      if (_partners) {
        final bx = x + p.partnerSide * kFieldPairGap;
        final feet = p.getBattlePos().dy * _h + p.size.y * 0.42;
        out.add((
          id: '${p.id}_partner',
          layer: p.anchor,
          x: bx,
          top: feet,
          hw: hw,
        ));
      }
    }
    _platforms = out;
  }

  ({String id, SceneLayer layer, double x, double top, double hw})? _platformAt(
    SceneLayer layer,
    double x,
  ) {
    for (final p in _platforms) {
      if (p.layer != layer) continue;
      if (_loopDelta(x, p.x, layer).abs() <= p.hw * 1.05) return p;
    }
    return null;
  }

  @override
  double? perchFor(String spawnId) {
    for (final p in _platforms) {
      if (p.id == spawnId) return p.top;
    }
    for (final p in _spawns) {
      if (p.id == spawnId && _shares(p)) return _sharedPerch(p);
    }
    return null;
  }

  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    if (layer != reef && layer != shelf) return null;
    final p = _platformAt(layer, x);
    // On a column top: anything that cannot float is stood on it.
    if (p != null) return (top: double.infinity, rest: p.top);
    if (layer == reef) return null;
    // The flat, where there is no column.
    return (top: _flatTop + 2 * _u, rest: _flatTop + 0.08 * _h);
  }

  double get _flatTop => _h * 0.805;

  // ── Build ────────────────────────────────────────────────────────────────

  double _shelfWidth = 0, _foreWidth = 0;
  _Blades? _kelp;
  List<(double, double, double)> _foreTops = const [];

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    _bends.remove(layer);
    _makePlatforms();
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        final sea = Rect.fromLTWH(0, _h * (_seaTop - 0.12), w, _h * 0.42);
        return [
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            grade: _gSea,
            paint: (c) => _paintSea(c, w),
          ),
          // The waves coming in, under the stacks.
          FieldSheet.live(bounds: sea, live: _paintFarSwells),
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            grade: _gStack,
            paint: (c) => _paintStacks(c, w, null),
          ),
          FieldSheet(
            bounds: sea,
            resolution: 0.8,
            light: true,
            paint: (c) => _sinking(far, () {
              final sparks = GrainBatch(_sparkAlpha.length);
              _paintStacks(_NullCanvas(), w, sparks);
              _drawSparks(c, sparks, 1.2);
            }),
          ),
        ];
      case reef:
        _glints[reef] = _Glints();
        final area = Rect.fromLTWH(0, _h * 0.42, w, _h * 0.5);
        return [
          FieldSheet(
            bounds: area,
            grade: _gSeaNear,
            paint: (c) => _paintNearSea(c, w),
          ),
          // The waves coming in, under the rocks.
          FieldSheet.live(bounds: area, live: _paintReefSwells),
          ..._basaltSheets(reef, area, _gReef, 0.12),
        ];
      case shelf:
        _glints[shelf] = _Glints();
        _shelfWidth = w;
        final area = Rect.fromLTWH(0, _h * 0.55, w, _h * 0.45 + 8 * _u);
        return [
          FieldSheet(
            bounds: area,
            grade: _gFlat,
            paint: (c) => _paintFlat(c, w),
          ),
          // The tide over the flat, under the columns.
          FieldSheet.live(bounds: area, live: _paintWater),
          ..._basaltSheets(shelf, area, _gBasalt, 0),
        ];
      case fore:
        _foreWidth = w;
        _foreTops = _makeForeTops(w);
        _kelp = _makeKelp(w);
        final area = Rect.fromLTWH(0, _h * 0.78, w, _h * 0.22 + 10 * _u);
        return [
          FieldSheet(
            bounds: area,
            grade: _gBasalt,
            paint: (c) {
              for (final (x, hw, ht) in _foreTops) {
                _wrapped(x, hw * 1.3, w, (at) {
                  _basalt(
                    c,
                    null,
                    at,
                    _h - ht,
                    _h + 12 * _u,
                    hw,
                    6600 + x.round(),
                    dark: 0.5,
                  );
                });
              }
            },
          ),
          FieldSheet(
            bounds: area,
            light: true,
            paint: (c) {
              final sparks = GrainBatch(_sparkAlpha.length);
              for (final (x, hw, ht) in _foreTops) {
                _wrapped(x, hw * 1.3, w, (at) {
                  _basalt(
                    _NullCanvas(),
                    sparks,
                    at,
                    _h - ht,
                    _h + 12 * _u,
                    hw,
                    6600 + x.round(),
                  );
                });
              }
              _drawSparks(c, sparks, 1.5);
            },
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    shelf || reef => true,
    far || fore => !front,
    _ => false,
  };

  // ── The sea ──────────────────────────────────────────────────────────────

  void _paintSea(Canvas c, double w) {
    final top = _h * _seaTop, bottom = _h * 0.86;
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(0.85, 0.05, 0.05),
            fieldMap(0.4, 0, 0.3),
            fieldMap(0.15, 0, 0.6),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );
    // Swells: broad soft bands, closer together toward the horizon, a
    // shade lighter on their faces.
    for (var k = 0; k < 16; k++) {
      final f = math.pow((k + 0.5) / 16, 1.7).toDouble();
      final y = top + f * (bottom - top);
      final th = (1.2 + 6 * f) * _u;
      double edge(double x) => y + _nf(x, 120 + 200 * f, 300 + k) * th * 1.4;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 6 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 6 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0.3, 0.14, 0.15, 0.35));
    }
  }

  double _nf(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));
  double _nr(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(reef));

  /// The sea stacks far out: (x as a share of the loop, half width,
  /// height as a share of the height).
  static const _stacks = [
    (0.12, 0.035, 0.11),
    (0.18, 0.018, 0.06),
    (0.53, 0.05, 0.16),
    (0.6, 0.02, 0.07),
    (0.84, 0.03, 0.09),
  ];

  void _paintStacks(Canvas c, double w, GrainBatch? sparks) {
    for (var i = 0; i < _stacks.length; i++) {
      final (fx, hw, ht) = _stacks[i];
      _wrapped(fx * w, hw * _h * 1.4, w, (x) {
        _basalt(
          c,
          sparks,
          x,
          _h * (_seaTop + 0.02 - ht),
          _h * (_seaTop + 0.03),
          hw * _h,
          4100 + i,
          haze: 0.55,
          column: 9,
        );
      });
    }
  }

  void _paintNearSea(Canvas c, double w) {
    final top = _h * 0.6, bottom = _h * 0.9;
    c.drawRect(
      Rect.fromLTRB(-4, top, w + 4, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(0.3, 0, 0.3, 0),
            fieldMap(0.2, 0, 0.45),
            fieldMap(0.05, 0, 0.7),
          ],
          const [0.0, 0.25, 1.0],
        ),
    );
    for (var k = 0; k < 7; k++) {
      final f = (k + 0.5) / 7;
      final y = top + f * (bottom - top);
      final th = (3 + 7 * f) * _u;
      double edge(double x) => y + _nr(x, 160, 400 + k) * th;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 6 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 6 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0.15, 0.12, 0.2, 0.3));
    }
  }

  // ── Basalt ───────────────────────────────────────────────────────────────

  /// The columns of [layer]: under every point that stands there, and the
  /// scenery.
  List<({double x, double top, double base, double hw, int seed})> _columnsOf(
    SceneLayer layer,
  ) {
    final width = _widths[layer] ?? _worldWidth;
    // A reef rock ends just under the water: the sea hides the rest.
    final foot = layer == reef ? _reefLine + 4 * _u : _h * 0.95;
    final least = (layer == reef ? 14 : 22) * _u;
    final out = <({double x, double top, double base, double hw, int seed})>[
      for (final p in _platforms)
        if (p.layer == layer)
          (
            x: p.x,
            top: p.top,
            base: math.max(foot, p.top + least),
            hw: p.hw,
            seed: fieldSeedOf(p.id),
          ),
    ];
    if (_placed) {
      for (final p in _piecesOn(layer, {FieldPiece.basalt})) {
        final x = _spawnX(p);
        final base = layer == reef ? _reefLine : _h * 0.9;
        out.add((
          x: x,
          top: base - p.size.y * _u,
          base: base + (layer == reef ? 4 : 20) * _u,
          hw: p.size.x * _u,
          seed: fieldSeedOf(p.id),
        ));
      }
    } else {
      var i = 0;
      for (final (l, fx, hw, ht) in _wildBasalt) {
        if (l != layer) continue;
        final base = layer == reef ? _reefLine : _h * 0.9;
        out.add((
          x: fx * width,
          top: base - ht * _u,
          base: base + (layer == reef ? 4 : 20) * _u,
          hw: hw * _u,
          seed: 8800 + i++,
        ));
      }
    }
    // Back to front: the tallest behind.
    out.sort((a, b) => a.top.compareTo(b.top));
    return out;
  }

  List<FieldSheet> _basaltSheets(
    SceneLayer layer,
    Rect area,
    int grade,
    double haze,
  ) {
    final cols = _columnsOf(layer);
    final w = _widths[layer] ?? _worldWidth;
    return [
      FieldSheet(
        bounds: area,
        grade: grade,
        paint: (c) {
          for (final k in cols) {
            _wrapped(k.x, k.hw * 1.4, w, (at) {
              _basalt(c, null, at, k.top, k.base, k.hw, k.seed, haze: haze);
            });
          }
        },
      ),
      FieldSheet(
        bounds: area,
        light: true,
        paint: (c) => _sinking(layer, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          for (final k in cols) {
            _wrapped(k.x, k.hw * 1.4, w, (at) {
              _basalt(_NullCanvas(), sparks, at, k.top, k.base, k.hw, k.seed);
            });
          }
          _drawSparks(c, sparks, 1.3);
        }),
      ),
    ];
  }

  /// A mass of sea rock, weathered round by the water: a broad foot, sides
  /// bulging and cut back where the sea has worked them, and a top worn
  /// nearly level where feet go at [top] (a far stack, [spire], keeps a
  /// rough crown instead). Lit from above and fading to wet dark at its
  /// foot, cracked, pitted, with barnacles and weed along the tide line.
  /// With [sparks], only the light along its top: wet, catching.
  void _basalt(
    Canvas c,
    GrainBatch? sparks,
    double cx,
    double top,
    double base,
    double hw,
    int seed, {
    double haze = 0,
    double dark = 0,
    int? column,
  }) {
    final spire = column != null;
    final outline = _rockOutline(cx, top, base, hw, seed, spire: spire);
    if (sparks != null) {
      // Light along the top edge, wet.
      for (var i = 0; i < outline.length; i++) {
        final p = outline[i];
        if (p.dy > top + (base - top) * (spire ? 0.35 : 0.18)) continue;
        final roll = fieldHash(i, seed);
        if (roll > 0.7) continue;
        sparks.add((roll * 5).floor().clamp(0, 3), p.dx, p.dy + 0.8 * _u);
        if (roll < 0.05) _glint(p.dx, p.dy + 0.8 * _u);
      }
      return;
    }
    final rock = _smooth(outline);
    final h = base - top;
    c.drawPath(
      rock,
      Paint()
        ..shader = Gradient.linear(
          Offset(cx - hw * 0.6, top),
          Offset(cx + hw * 0.4, base),
          [
            fieldMap(haze, 0.16, 0.08 + dark),
            fieldMap(haze, 0.03, 0.42 + dark * 0.4),
            fieldMap(haze, 0, 0.82),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(rock);
    final r = FieldRandom(seed * 7 + 5);
    // Planes the sea has cut: soft darker facets down its shaded side, and
    // a few lighter ones up its lit side.
    for (var i = 0; i < 6; i++) {
      final right = i < 4;
      final fx = cx + (right ? r.range(0.05, 0.8) : r.range(-0.8, -0.2)) * hw;
      final fy = top + r.range(0.15, 0.85) * h;
      final fw = hw * r.range(0.25, 0.5), fh = h * r.range(0.2, 0.45);
      c.drawPath(
        Path()..addPolygon([
          Offset(fx - fw * 0.5, fy - fh * 0.3),
          Offset(fx + fw * 0.2, fy - fh * 0.5),
          Offset(fx + fw * 0.55, fy + fh * 0.1),
          Offset(fx + fw * 0.1, fy + fh * 0.5),
          Offset(fx - fw * 0.45, fy + fh * 0.25),
        ], true),
        Paint()
          ..color = right
              ? fieldMap(haze, 0, 0.75, 0.35)
              : fieldMap(haze, 0.1, 0.1, 0.25),
      );
    }
    // Streaks where water runs down it: broad, soft, a shade darker.
    for (var i = 0; i < 4; i++) {
      final x0 = cx + r.range(-0.7, 0.6) * hw;
      final sw = r.range(3, 8) * _u;
      final y0 = top + h * r.range(0.1, 0.4);
      c.drawRect(
        Rect.fromLTRB(x0, y0, x0 + sw, base),
        Paint()
          ..shader = Gradient.linear(Offset(0, y0), Offset(0, base), [
            fieldMap(haze, 0, 0.7, 0),
            fieldMap(haze, 0, 0.7, 0.3),
          ]),
      );
    }
    // Pitting, and lighter grains where it is dry.
    final grains = GrainBatch(4);
    for (var i = 0; i < (hw * h / (12 * _u * _u)).round(); i++) {
      final x = cx + (fieldHash(i, seed) - 0.5) * hw * 2.2;
      final y = top + fieldHash(i, seed + 1) * h;
      final f = (y - top) / h;
      grains.add(f < 0.45 ? 1 : 0, x, y);
    }
    // Barnacles along the tide line, and weed hanging from it.
    final tideLine = top + h * (spire ? 0.82 : 0.62);
    for (var i = 0; i < (hw * 2 / (1.4 * _u)).round(); i++) {
      final x = cx - hw * 1.1 + fieldHash(i, seed + 3) * hw * 2.2;
      final y = tideLine + (fieldHash(i, seed + 4) - 0.5) * 8 * _u;
      grains.add(2, x, y);
      if (fieldHash(i, seed + 5) < 0.55) {
        final drop = fieldHash(i, seed + 6) * 16 * _u;
        for (var d = 0.0; d < drop; d += 1.5 * _u) {
          grains.add(3, x + math.sin(d * 0.3) * 0.6 * _u, y + 3 * _u + d);
        }
      }
    }
    grains
      ..draw(c, 0, 1.4 * _u, fieldMap(haze, 0, 0.95, 0.55))
      ..draw(c, 1, 1.2 * _u, fieldMap(haze, 0.25, 0.1, 0.45))
      ..draw(c, 2, 1.4 * _u, fieldMap(haze, 0.14, 0.3, 0.45))
      ..draw(c, 3, 1.7 * _u, fieldMap(haze, 0.04, 0.6, 0.85));
    // Wet and dark below the tide line.
    c.drawRect(
      Rect.fromLTRB(cx - hw * 1.4, tideLine, cx + hw * 1.4, base + 2 * _u),
      Paint()
        ..shader = Gradient.linear(Offset(0, tideLine), Offset(0, base), [
          fieldMap(haze, 0.05, 0.4, 0.2),
          fieldMap(haze, 0.08, 0.8, 0.7),
        ]),
    );
    c.restore();
  }

  /// A rock's outline, going round: worn level across the middle of its top
  /// at [top] (or a rough crown, for a [spire]), its shoulders rounded off,
  /// its sides bulging and cut back, broad at its foot.
  List<Offset> _rockOutline(
    double cx,
    double top,
    double base,
    double hw,
    int seed, {
    bool spire = false,
  }) {
    final h = base - top;
    final pts = <Offset>[];
    final flat = spire ? 0.2 : 0.42;
    const n = 18;
    for (var i = 0; i <= n; i++) {
      final f = i / n * 2 - 1;
      final edge = (f.abs() - flat).clamp(0.0, 1.0) / (1 - flat);
      final drop =
          math.pow(edge, 1.7) * h * (spire ? 0.35 : 0.3) +
          fieldNoise(i * 0.9, seed) * (spire ? 4 : 1.5) * _u;
      pts.add(Offset(cx + f * hw * 0.9, top + drop));
    }
    for (var i = 1; i <= 6; i++) {
      final f = i / 6;
      final out =
          0.92 + 0.3 * math.pow(f, 1.5) + 0.12 * fieldNoise(f * 3, seed + 2);
      pts.add(
        Offset(cx + hw * out * (spire ? 0.8 : 1), top + h * (0.3 + 0.72 * f)),
      );
    }
    for (var i = 6; i >= 1; i--) {
      final f = i / 6;
      final out =
          0.94 + 0.34 * math.pow(f, 1.5) + 0.12 * fieldNoise(f * 3, seed + 3);
      pts.add(
        Offset(cx - hw * out * (spire ? 0.8 : 1), top + h * (0.3 + 0.72 * f)),
      );
    }
    return pts;
  }

  /// A closed outline drawn smooth: through the middles of its edges, each
  /// corner a curve.
  Path _smooth(List<Offset> pts) {
    final path = Path();
    final n = pts.length;
    final first = Offset.lerp(pts[n - 1], pts[0], 0.5)!;
    path.moveTo(first.dx, first.dy);
    for (var i = 0; i < n; i++) {
      final a = pts[i], b = pts[(i + 1) % n];
      final mid = Offset.lerp(a, b, 0.5)!;
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
    }
    return path..close();
  }

  // ── The flat ─────────────────────────────────────────────────────────────

  /// The pools in the flat where the wild has them: (x as a share of the
  /// loop, how far down the flat, half width).
  static const _pools = [
    (0.07, 0.62, 42.0),
    (0.43, 0.75, 54.0),
    (0.66, 0.55, 36.0),
    (0.79, 0.82, 48.0),
  ];

  ({double x, double y, double hw, double hh}) _poolShape(int i, double w) {
    final (fx, f, hw) = _pools[i];
    final y = _flatTop + f * (_h - _flatTop);
    final s = (0.6 + f * 0.7) * _u;
    return (x: fx * w, y: y, hw: hw * s, hh: hw * s * 0.24);
  }

  void _paintFlat(Canvas c, double w) {
    c.drawRect(
      Rect.fromLTRB(-4, _flatTop, w + 4, _h + 8 * _u),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, _flatTop),
          Offset(0, _h),
          [
            fieldMap(0.2, 0.12, 0.25),
            fieldMap(0, 0.04, 0.35),
            fieldMap(0, 0, 0.6),
          ],
          const [0.0, 0.3, 1.0],
        ),
    );
    // Ripple marks the ebb left: soft wandering bands, closer far off.
    for (var k = 0; k < 14; k++) {
      final f = math.pow((k + 0.5) / 14, 1.3).toDouble();
      final y = _flatTop + f * (_h - _flatTop);
      final th = (1.5 + 5 * f) * _u;
      double edge(double x) =>
          y + fieldLoopNoise(x, 70 + 80 * f, 500 + k, _period(shelf)) * th;
      final band = Path()..moveTo(-4, edge(-4));
      for (var x = -4.0; x <= w + 4; x += 5 * _u) {
        band.lineTo(x, edge(x));
      }
      for (var x = w + 4; x >= -4; x -= 5 * _u) {
        band.lineTo(x, edge(x) + th);
      }
      band.close();
      c.drawPath(band, Paint()..color = fieldMap(0, 0.12, 0.1, 0.3));
    }
    // The pools: rimmed with weed, dark and still.
    for (var i = 0; i < _pools.length; i++) {
      final s = _poolShape(i, w);
      _wrapped(s.x, s.hw * 1.3, w, (x) {
        final oval = Rect.fromCenter(
          center: Offset(x, s.y),
          width: s.hw * 2,
          height: s.hh * 2,
        );
        c
          ..drawOval(
            oval.inflate(2 * _u),
            Paint()..color = fieldMap(0, 0.06, 0.55, 0.8),
          )
          ..drawOval(
            oval,
            Paint()
              ..shader = Gradient.linear(oval.topCenter, oval.bottomCenter, [
                fieldMap(0.25, 0.1, 0.5),
                fieldMap(0.05, 0, 0.92),
              ]),
          );
      });
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
        _paintLightPath(canvas, view);
        _paintStackFoam(canvas, view);
        _paintFog(canvas, view, far, 0.4, 0.8);
      case reef:
        if (front) {
          _paintSwimming(canvas, view);
        } else {
          _paintSurf(canvas, view);
          _paintFog(canvas, view, reef, 0.5, 0.9);
        }
      case shelf:
        if (!front) {
          _paintPools(canvas, view);
          _paintWrack(canvas, view);
        } else {
          _paintWake(canvas, view);
          _paintShelfSurf(canvas, view);
        }
      case fore:
        final kelp = _kelp;
        if (kelp != null) {
          _stirBlades(
            kelp,
            fore,
            _foreWidth,
            view,
            reach: 50 * _u,
            maxBend: 0.9,
          );
          _paintBlades(
            canvas,
            view,
            kelp,
            _foreWidth,
            rows: (0, 0),
            fore: true,
            layer: fore,
          );
        }
      default:
        break;
    }
  }

  final GrainBatch _pathBatch = GrainBatch(3);

  /// The sun's path on the water in [view], or the moon's: where it runs
  /// down the sea, how wide it spreads near, its color, and how bright it
  /// is — brightest with the light low. Null when there is none.
  ({double x, double spread, Color color, double strength})? _path(
    FieldView view,
  ) {
    final byMoon = _sunUp < -0.05;
    final up = byMoon ? _moonUp : _sunUp;
    if (up < -0.05) return null;
    final lit = byMoon
        ? (1 - math.cos(_moonPhase * 2 * math.pi)) / 2 * 0.7
        : 1.0;
    final low = (1 - up.clamp(0.0, 1.0) * 0.8);
    final strength = lit * low * (1 - fog * 0.9);
    if (strength < 0.04) return null;
    return (
      x: view.left + (byMoon ? _moonX : _sunX) * _screen.width / view.zoom,
      spread: 70 * _u * (0.6 + 0.6 * low),
      color: byMoon
          ? const Color(0xFFDDE6FF)
          : Color.lerp(_light.rim, const Color(0xFFFFFFFF), 0.4)!,
      strength: strength,
    );
  }

  /// The sun's path across the water, or the moon's: glitter in a column
  /// under it, narrow at the horizon and spreading toward you.
  void _paintLightPath(Canvas canvas, FieldView view) {
    final path = _path(view);
    if (path == null) return;
    final top = _h * _seaTop, span = _h * 0.3;
    final t = view.time;
    _pathBatch.clear();
    for (var i = 0; i < 300; i++) {
      final d = math.pow(fieldHash(i, 41), 1.4).toDouble();
      final y = top + 1 * _u + d * span;
      final spread = path.spread * (4 / 70 + d);
      final across = (fieldHash(i, 43) - 0.5) * 2;
      // Concentrated in the middle of the path.
      final x = path.x + across * across.abs() * spread;
      final s = math.sin(t * (1.5 + fieldHash(i, 47) * 2.5) + i * 1.7);
      if (s < 0.25) continue;
      _pathBatch.add(s > 0.85 ? 2 : (s > 0.55 ? 1 : 0), x, y);
    }
    for (var lv = 0; lv < 3; lv++) {
      _pathBatch.draw(
        canvas,
        lv,
        (1.0 + 0.35 * lv) * _u,
        path.color.withValues(
          alpha: (path.strength * (0.3 + 0.3 * lv)).clamp(0.0, 1.0),
        ),
      );
    }
  }

  // ── Waves ────────────────────────────────────────────────────────────────
  //
  // The sea comes in as waves: each a crest travelling toward you, a lit
  // lip over a darker face, deeper as it nears. Where a wave is at x hangs
  // on x as well as the time — the crests come in bent — so each reaches
  // the rocks and the shore at its own moment along its length. On the
  // reef it breaks on the rocks; on the flat it runs up the sand and slides
  // back, leaving the sand wet behind it. A swell makes the waves bigger,
  // never faster, so a weather coming in does not hurry them.
  //
  // All of it is soft filled water — bands and sheets drawn as one mesh a
  // layer — with grains only for spray and froth.

  /// Seconds between one wave and the next.
  static const _wavePeriod = 6.5;

  /// Each layer's run of waves: from where and to where (shares of the
  /// height), and how many are on it at once. The flat's run is from its
  /// far edge to the waterline.
  static const _farFrom = 0.526, _farTo = 0.7, _farWaves = 4;
  static const _reefFrom = 0.6, _reefTo = 0.815, _reefWaves = 3;
  static const _shelfWaves = 2;

  /// Where the sea stands at the reef rocks' feet.
  double get _reefLine => _h * 0.72;

  /// The nearer sea's color at [y], as its sheet is baked and graded (see
  /// [_paintNearSea]) — what is drawn over the sea must match it.
  Color _nearSeaAt(double y) {
    final f = ((y - _h * 0.6) / (_h * 0.3)).clamp(0.0, 1.0);
    final k = f < 0.25 ? f / 0.25 : (f - 0.25) / 0.75;
    final r = f < 0.25 ? 0.3 - 0.1 * k : 0.2 - 0.15 * k;
    final b = f < 0.25 ? 0.3 + 0.15 * k : 0.45 + 0.25 * k;
    final keep = 1 - r - 0.75 * b;
    return Color.from(
      alpha: 1,
      red: (_seaNear.r * keep + _hazeLow.r * r).clamp(0.0, 1.0),
      green: (_seaNear.g * keep + _hazeLow.g * r).clamp(0.0, 1.0),
      blue: (_seaNear.b * keep + _hazeLow.b * r).clamp(0.0, 1.0),
    );
  }

  /// The sea in front of a rock's foot, from where the water stands at [y]
  /// down to its [base]: below the surface it is seen only dimly.
  void _sinkFoot(double x0, double y, double base, double hw) {
    if (base <= y) return;
    const n = 10;
    final w = hw * 1.55;
    final top = _nearSeaAt(y), mid = _nearSeaAt(y + 5 * _u);
    final bottom = _nearSeaAt(base + 3 * _u);
    final first = _mesh.count;
    for (var i = 0; i <= n; i++) {
      final f = i / n * 2 - 1;
      final side = 1 - _ss(0.9, 1, f.abs());
      _mesh
        ..add(x0 + f * w, y - 0.5 * _u, _argb(top, 0.45 * side))
        ..add(x0 + f * w, y + 5 * _u, _argb(mid, 0.88 * side))
        ..add(x0 + f * w, base + 3 * _u, _argb(bottom, 0.98 * side));
    }
    _mesh.strip(first, n + 1, 3);
  }

  /// How hard the waves come in: a swell throws them twice as high.
  double get _surge => 1 + 1.4 * swell;

  /// The waves' phase at [x] on [layer]: wave m is (phase − m) / count of
  /// the way along its run.
  double _wavePhase(SceneLayer layer, double x, double t) =>
      t / _wavePeriod + _bendAt(layer, x);

  /// How far behind the time the waves run at [x] on [layer]: what bends
  /// the crests. It never changes, so it is kept for the columns drawn.
  double _bendAt(SceneLayer layer, double x) {
    final cache = _bends.putIfAbsent(layer, () => {});
    final key = (x * 4 / _u).round();
    final known = cache[key];
    if (known != null) return known;
    if (cache.length > 4096) cache.clear();
    final p = _period(layer);
    // Along the shore each stretch is at its own stage of the swash.
    final bend = layer == shelf ? 0.7 : 0.32;
    return cache[key] =
        bend * fieldLoopNoise(x, 520 * _u, 4401 + layer.index, p) +
        0.07 * fieldLoopNoise(x, 130 * _u, 4407 + layer.index, p);
  }

  final Map<SceneLayer, Map<int, double>> _bends = {};

  /// How far down its run a crest [along] of the way along it has come,
  /// 0 to 1 — it quickens as it nears, as anything coming toward you does.
  static double _down(double along) => along * (0.55 + 0.45 * along);

  /// How far along a run from [from] to [to] a crest at [y] is, 0 to 1:
  /// the inverse of [_down].
  static double _runAt(double y, double from, double to) {
    final k = ((y - from) / (to - from)).clamp(0.0, 1.0);
    return (math.sqrt(0.3025 + 1.8 * k) - 0.55) / 0.9;
  }

  /// Seconds since the last wave on a run reached [y] at [x], and which
  /// wave that was.
  (double, int) _sinceWave(
    SceneLayer layer,
    double x,
    double y,
    double t,
    double from,
    double to,
    int count,
  ) {
    final u = _wavePhase(layer, x, t) - count * _runAt(y, from, to);
    final m = u.floor();
    return ((u - m) * _wavePeriod, m);
  }

  static double _ss(double a, double b, double x) {
    final f = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return f * f * (3 - 2 * f);
  }

  /// [c] with [a] for its alpha, as a mesh vertex wants it.
  static int _argb(Color c, double a) => _at(_rgb(c), a);

  /// [c] without its alpha, for [_at] and [_mix] — colors worked as ints
  /// so the hundreds of vertices a frame allocate nothing.
  static int _rgb(Color c) => c.toARGB32() & 0xFFFFFF;

  /// [rgb] with [a] for its alpha.
  static int _at(int rgb, double a) =>
      ((a.clamp(0.0, 1.0) * 255).round() << 24) | rgb;

  /// [a] taken [k] of the way to [b] (both without alpha).
  static int _mix(int a, int b, double k) {
    if (k <= 0) return a;
    if (k >= 1) return b;
    var out = 0;
    for (var sh = 0; sh <= 16; sh += 8) {
      final x = (a >> sh) & 0xFF, y = (b >> sh) & 0xFF;
      out |= (x + ((y - x) * k).round()) << sh;
    }
    return out;
  }

  /// The water drawn this frame, a layer at a time.
  final _WaterMesh _mesh = _WaterMesh();
  final List<double> _colX = [], _colU = [];

  /// Lays into [_mesh] the waves on a run from [from] to [to] (layer units,
  /// far to near): [count] on it at once, [thin] deep where they start and
  /// [thick] at the end, showing as much as [strength] says.
  void _swells(
    FieldView view,
    SceneLayer layer, {
    required double from,
    required double to,
    required int count,
    required double thin,
    required double thick,
    required double strength,
    bool froth = false,
    double caps = 1,
  }) {
    if (strength <= 0.01 || to - from < 2 * _u) return;
    final t = view.time;
    final p = _period(layer);
    final step = (layer == far ? 16 : 8) * _u;
    // Columns on a grid fixed to the layer, so nothing crawls as it pans.
    final g0 = (view.left / step).floor() - 2;
    final n = ((view.right - view.left) / step).ceil() + 5;
    _colX.clear();
    _colU.clear();
    var lo = double.infinity, hi = -double.infinity;
    for (var i = 0; i < n; i++) {
      final x = (g0 + i) * step;
      final u = _wavePhase(layer, x, t);
      _colX.add(x);
      _colU.add(u);
      lo = math.min(lo, u);
      hi = math.max(hi, u);
    }
    final path = _path(view);
    final s = swell * caps;
    final glow = _night * (1 - fog * 0.6);
    final white = _rgb(Color.lerp(_foam, _glow, glow * 0.85)!);
    final lipRgb = _rgb(_lip), faceRgb = _rgb(_face);
    final pathRgb = path == null ? 0 : _rgb(path.color);
    for (var m = lo.floor() - count + 1; m <= hi.floor(); m++) {
      // A wave not yet on its run anywhere here, or past its end, shows
      // nowhere.
      if ((hi - m) / count <= 0 || (lo - m) / count >= 1) continue;
      final seed = 4500 + (fieldHash(m, 4499) * 4000).floor();
      final first = _mesh.count;
      for (var i = 0; i < n; i++) {
        final x = _colX[i];
        final along = (_colU[i] - m) / count;
        final a = along.clamp(0.0, 1.0);
        final k = _down(a);
        final y = from + (to - from) * k;
        final th = thin + (thick - thin) * k;
        final env = _ss(0, 0.16, along) * (1 - _ss(0.8, 1, along));
        if (env <= 0) {
          final none = _at(lipRgb, 0);
          _mesh
            ..add(x, y - th * 0.45, none)
            ..add(x, y, none)
            ..add(x, y + th * 0.3, none)
            ..add(x, y + th, none);
          continue;
        }
        final show = strength * env;
        // Lit in long pieces along its length, never one ruled line.
        final lit = _ss(
          0.25,
          0.8,
          0.5 + 0.5 * fieldLoopNoise(x, 110 * _u, seed, p),
        );
        var lipA = show * (0.1 + 0.38 * lit) * (0.4 + 0.6 * a);
        var faceA = show * (0.1 + 0.12 * lit) * (0.35 + 0.65 * a);
        var lip = lipRgb, face = faceRgb;
        // Where the sun's path crosses it, it catches the light.
        if (path != null) {
          final d = (x - path.x) / (path.spread * (0.3 + 0.9 * k));
          if (d.abs() < 3) {
            final g = path.strength * math.exp(-d * d) * show;
            lip = _mix(lip, pathRgb, g * 1.2);
            lipA += g * 0.45 * lit;
          }
        }
        // In a swell the crests break white in streaks along them, and the
        // white spills down their faces.
        if (s > 0.02) {
          final wc =
              s *
              env *
              _ss(
                0.55,
                0.85,
                0.5 + 0.5 * fieldLoopNoise(x, 34 * _u, seed + 7, p),
              ) *
              _ss(0.25, 0.55, a);
          lip = _mix(lip, white, wc);
          face = _mix(face, white, wc * 0.7);
          lipA = math.max(lipA, wc * 0.8);
          faceA += wc * 0.3;
          // Froth on it, and down its face.
          if (froth && wc > 0.2) {
            for (var j = 0; j < 4; j++) {
              final h = fieldHash(i * 5 + j, seed);
              _spray.add(
                h > 0.7 ? 4 : 3,
                x + (fieldHash(i * 5 + j, seed + 1) - 0.5) * step,
                y - th * 0.2 + h * th * 0.7 * wc,
              );
            }
          }
        }
        _mesh
          ..add(x, y - th * 0.45, _at(lip, 0))
          ..add(x, y, _at(lip, lipA))
          ..add(x, y + th * 0.3, _at(face, faceA))
          ..add(x, y + th, _at(face, 0));
      }
      _mesh.strip(first, n, 4);
    }
  }

  /// A band of white water lying on the sea at [y] across [cx] ± [half]:
  /// tapered to nothing at its ends, [thick] deep (the water is seen nearly
  /// edge on), [alpha] at most. [lace] is how much of it has come apart
  /// into holes, which [seed] places and [drift] moves along.
  void _foamBand(
    double cx,
    double y,
    double half,
    double thick,
    double alpha,
    Color col, {
    int seed = 0,
    double drift = 0,
    double lace = 0.2,
    double froth = 1,
  }) {
    if (alpha < 0.01 || half < 1) return;
    final rgb = _rgb(col);
    final n = math.max(6, (half * 2 / (5 * _u)).ceil());
    _bandHoles.clear();
    _bandLean.clear();
    final first = _mesh.count;
    for (var i = 0; i <= n; i++) {
      final f = i / n * 2 - 1;
      final x = cx + f * half;
      final d = f * half / _u;
      final holes =
          0.5 +
          0.5 *
              (0.65 * fieldNoise(d / 16 + drift, seed) +
                  0.35 * fieldNoise(d / 6 - drift * 1.7, seed + 1));
      final lean = fieldNoise(d / 11, seed + 2) * thick * 0.25;
      _bandHoles.add(holes);
      _bandLean.add(lean);
      final taper = math.pow(1 - f * f, 0.6).toDouble();
      final a = alpha * taper * _ss(lace - 0.15, lace + 0.2, holes);
      // Ragged along its edges, not ruled; soft, the froth on it is what
      // shows.
      final y0 = y + lean;
      _mesh
        ..add(x, y0 - thick * 0.35, _at(rgb, 0))
        ..add(x, y0, _at(rgb, a * 0.6))
        ..add(x, y0 + thick * 0.65, _at(rgb, 0));
    }
    _mesh.strip(first, n + 1, 3);
    // The froth itself: bubbles packed where the foam holds together.
    final grains = (half * thick / (2.8 * _u * _u) * froth * alpha).round();
    for (var j = 0; j < grains; j++) {
      final f = fieldHash(j, seed + 5) * 2 - 1;
      final at = (f + 1) / 2 * n;
      final i0 = math.min(n - 1, at.floor()), g = at - i0;
      final holes = _bandHoles[i0] + (_bandHoles[i0 + 1] - _bandHoles[i0]) * g;
      final lean = _bandLean[i0] + (_bandLean[i0 + 1] - _bandLean[i0]) * g;
      final keep = alpha * (1 - f * f) * _ss(lace - 0.1, lace + 0.25, holes);
      final r = fieldHash(j, seed + 6);
      if (r > keep * 1.4) continue;
      _spray.add(
        r < keep * 0.5 ? 4 : 3,
        cx + f * half,
        y + lean + (fieldHash(j, seed + 7) - 0.4) * thick * 0.8,
      );
    }
  }

  final List<double> _bandHoles = [], _bandLean = [];

  /// A ripple running out on the water round [cx], [cy]: a soft band [rx]
  /// across, flattened to [ry] by how low we see the water, [w] wide and
  /// broken in places. Only its near half when something stands in it
  /// ([front]); none of it below [floor].
  void _ripple(
    double cx,
    double cy,
    double rx,
    double ry,
    double w,
    double alpha,
    Color col,
    int seed, {
    bool front = false,
    double floor = double.infinity,
  }) {
    if (alpha < 0.01) return;
    final rgb = _rgb(col);
    final n = front ? 14 : 26;
    final first = _mesh.count;
    for (var i = 0; i <= n; i++) {
      final ang = (front ? math.pi : 2 * math.pi) * i / n;
      final c = math.cos(ang), s = math.sin(ang);
      final whole = _ss(0.3, 0.6, 0.5 + 0.5 * fieldNoise(i * 0.55, seed));
      final y = cy + s * ry;
      final a = y > floor
          ? 0.0
          : alpha * whole * (front ? _ss(0, 0.25, s) : 1.0);
      _mesh
        ..add(cx + c * (rx - w), cy + s * (ry - w * 0.3), _at(rgb, 0))
        ..add(cx + c * rx, y, _at(rgb, a))
        ..add(cx + c * (rx + w), cy + s * (ry + w * 0.3), _at(rgb, 0));
    }
    _mesh.strip(first, n + 1, 3);
  }

  /// Spray and froth: 0 a drop's trail, 1 drops, 2 big drops, 3 and 4 the
  /// froth in white water.
  final GrainBatch _spray = GrainBatch(5);

  void _drawSpray(Canvas canvas, Color col) {
    _spray
      ..draw(canvas, 0, 0.8 * _u, col.withValues(alpha: 0.2))
      ..draw(canvas, 1, 1.0 * _u, col.withValues(alpha: 0.45))
      ..draw(canvas, 2, 1.35 * _u, col.withValues(alpha: 0.65))
      ..draw(canvas, 3, 0.9 * _u, col.withValues(alpha: 0.35))
      ..draw(canvas, 4, 1.3 * _u, col.withValues(alpha: 0.5));
  }

  /// A wave breaking on a rock [hw] half wide standing at [x0], its feet in
  /// the sea at [y] and its top at [top], [since] seconds after the wave
  /// reached it ([hit] tells one wave from the next, [seed] one rock from
  /// another). The white water climbs its face and drains back off it in
  /// fingers, spray is thrown up and falls back, and a sheet of foam
  /// spreads from its foot and comes apart on the water. Foam lies round
  /// its foot always, [wet] of it. [force] scales the lot.
  void _breakOn(
    double x0,
    double y,
    double hw,
    double top,
    double since,
    int hit,
    int seed,
    double force,
    double glow,
    double t, {
    double wet = 1,
  }) {
    final hs = seed * 7 + hit * 131;
    // At night the sea lights where it is stirred: brightest as a wave
    // breaks, dimming as the water settles.
    final col = Color.lerp(_foam, _glow, glow * 0.9)!;
    final calm = Color.lerp(_foam, _glow, glow * 0.3)!;
    // The foam always round its foot, lifted a little by each wave.
    final after = math.exp(-since * 0.8);
    _foamBand(
      x0,
      y + 1.5 * _u,
      hw * (1.25 + 0.2 * after),
      (3.5 + 2 * after) * _u * math.min(force, 1.6),
      (0.3 + 0.35 * after) * wet,
      Color.lerp(calm, col, after)!,
      seed: seed,
      drift: t * 0.12,
      lace: 0.42 - 0.2 * after,
    );

    // The white water up its face: up fast, held a moment, down slower.
    final rise = since < 0.45
        ? 1 - math.pow(1 - since / 0.45, 3).toDouble()
        : (since < 0.75 ? 1.0 : 1 - _ss(0.75, 2.6, since));
    final climb = math.min(
      (y - top) * 0.75,
      (12 + 10 * fieldHash(hit, seed)) * _u * force,
    );
    if (rise > 0.01 && climb > 2 * _u) {
      const n = 12;
      final w = hw * 1.15;
      final rgb = _rgb(col);
      final first = _mesh.count;
      final fade = 0.75 - 0.35 * _ss(0.6, 2.6, since);
      _profile.clear();
      for (var i = 0; i <= n; i++) {
        final f = i / n * 2 - 1;
        final prof = _tongues(f, hs);
        _profile.add(prof);
        // Draining, it runs off in fingers.
        final drain =
            (0.5 + 0.5 * fieldNoise(f * 6, hs + 1)) * _ss(0.75, 2.2, since);
        final h = climb * rise * prof * (1 - 0.6 * drain);
        final a = fade * math.pow(1 - f * f, 0.4).toDouble();
        _mesh
          ..add(x0 + f * w, y - h, _at(rgb, 0))
          ..add(x0 + f * w, y - h * 0.6, _at(rgb, a * 0.3))
          ..add(x0 + f * w, y - h * 0.15, _at(rgb, a * 0.5))
          ..add(x0 + f * w, y + 2.5 * _u, _at(rgb, 0));
      }
      _mesh.strip(first, n + 1, 4);
      // Froth in it.
      for (var j = 0; j < 110; j++) {
        final f = fieldHash(j, hs + 3) * 2 - 1;
        final v = fieldHash(j, hs + 5);
        final at = (f + 1) / 2 * n;
        final i0 = math.min(n - 1, at.floor());
        final prof =
            _profile[i0] + (_profile[i0 + 1] - _profile[i0]) * (at - i0);
        _spray.add(
          v < 0.3 ? 4 : 3,
          x0 + f * w * 0.95,
          y - climb * rise * prof * math.sqrt(v) * 0.85,
        );
      }
    }

    // Spray thrown up off it, coming down — each drop with its trail.
    final drops = (44 * force).round();
    final g = 320 * _u;
    for (var j = 0; j < drops; j++) {
      final r1 = fieldHash(j, hs + 11),
          r2 = fieldHash(j, hs + 13),
          r3 = fieldHash(j, hs + 17);
      final f = r1 * 2 - 1;
      final age = since - (0.08 + r2 * 0.3);
      if (age <= 0) continue;
      final up = (40 + 100 * r3) * _u * math.sqrt(force) * (1 - 0.5 * f.abs());
      final out = f * (12 + 30 * r2) * _u;
      final from = x0 + f * hw * 0.85;
      double lift(double a) => up * a - 0.5 * g * a * a;
      if (lift(age) < -2 * _u) continue;
      _spray.add(r3 > 0.7 ? 2 : 1, from + out * age, y - 3 * _u - lift(age));
      final was = age - 0.035;
      if (was > 0) {
        _spray.add(0, from + out * was, y - 3 * _u - lift(was));
      }
    }

    // The sheet of foam it leaves, spreading on the water and coming apart.
    final age = since - 0.35;
    const life = 4.6;
    if (age > 0 && age < life) {
      final k = age / life;
      _foamBand(
        x0,
        y + 1.5 * _u + age * 1.2 * _u,
        hw * (1.3 + 0.5 * age) * (0.8 + 0.2 * force),
        (3 + 2 * force) * _u * (1 - 0.5 * k),
        0.75 * math.pow(1 - k, 1.3).toDouble() * wet,
        Color.lerp(col, calm, k)!,
        seed: hs + 19,
        drift: age * 0.25,
        lace: 0.15 + 0.6 * k,
      );
    }
  }

  final List<double> _profile = [];

  /// How high white water thrown up a rock's face reaches across it ([f]
  /// −1 to 1): in tongues, broad-topped, not a dome.
  static double _tongues(double f, int seed) {
    final n =
        0.5 +
        0.5 *
            (0.6 * fieldNoise(f * 4 + 3, seed) +
                0.4 * fieldNoise(f * 10 + 7, seed + 2));
    return math.pow(1 - math.pow(f.abs(), 2.5), 0.8).toDouble() *
        (0.3 + 0.7 * n);
  }

  /// The far sea's waves, under the stacks.
  void _paintFarSwells(Canvas canvas, FieldView view) {
    _mesh.clear();
    _swells(
      view,
      far,
      from: _h * _farFrom,
      to: _h * _farTo,
      count: _farWaves,
      thin: 0.5 * _u,
      thick: 4 * _u,
      strength: 0.75 * (1 - 0.85 * fog),
      caps: 0.45,
    );
    _mesh.draw(canvas);
  }

  /// The nearer sea's waves, under the reef's rocks.
  void _paintReefSwells(Canvas canvas, FieldView view) {
    _mesh.clear();
    _spray.clear();
    _swells(
      view,
      reef,
      from: _h * _reefFrom,
      to: _h * _reefTo,
      count: _reefWaves,
      thin: 2.5 * _u,
      thick: 9 * _u * (1 + 0.6 * swell),
      strength: 1 - 0.5 * fog,
      froth: true,
    );
    _mesh.draw(canvas);
    _drawSpray(canvas, Color.lerp(_foam, _glow, _night * (1 - fog) * 0.85)!);
  }

  /// White water round the feet of the far stacks, lifting as each wave
  /// passes them.
  void _paintStackFoam(Canvas canvas, FieldView view) {
    final t = view.time;
    final w = _widths[far] ?? 1;
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    final y = _h * (_seaTop + 0.028);
    _mesh.clear();
    _spray.clear();
    for (final shift in _shiftsFor(far, view, 40 * _u)) {
      for (var i = 0; i < _stacks.length; i++) {
        final (fx, hw, _) = _stacks[i];
        final x0 = fx * w + shift;
        final half = hw * _h;
        if (x0 + half * 2 < view.left || x0 - half * 2 > view.right) continue;
        final (since, _) = _sinceWave(
          far,
          fx * w,
          y,
          t,
          _h * _farFrom,
          _h * _farTo,
          _farWaves,
        );
        final lift = math.exp(-since * 1.1);
        _foamBand(
          x0,
          y,
          half * (1.2 + 0.25 * lift),
          (1.2 + 1.6 * lift) * _u,
          (0.3 + 0.45 * lift) * (1 - 0.8 * fog),
          col,
          seed: 70 + i,
          drift: t * 0.15,
          lace: 0.35 - 0.2 * lift,
          froth: 0.5,
        );
      }
    }
    _mesh.draw(canvas);
    _drawSpray(canvas, col);
  }

  /// The surf on the reef: every wave that reaches a rock breaks on it.
  /// After dark it glows blue where it breaks.
  void _paintSurf(Canvas canvas, FieldView view) {
    final t = view.time;
    final cols = _columnsOf(reef);
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    _mesh.clear();
    _spray.clear();
    for (final shift in _shiftsFor(reef, view, 120 * _u)) {
      for (final k in cols) {
        final x0 = k.x + shift;
        if (x0 + k.hw * 3 < view.left || x0 - k.hw * 3 > view.right) continue;
        final y = math.min(_reefLine, k.base - 3 * _u);
        final (since, hit) = _sinceWave(
          reef,
          k.x,
          y,
          t,
          _h * _reefFrom,
          _h * _reefTo,
          _reefWaves,
        );
        _sinkFoot(x0, y, k.base, k.hw);
        _breakOn(x0, y, k.hw, k.top, since, hit, k.seed, _surge, glow, t);
      }
    }
    _mesh.draw(canvas);
    _drawSpray(canvas, col);
  }

  // ── Swimming ─────────────────────────────────────────────────────────────

  /// Whatever swims out in the sea at a point that wades: the sea drawn
  /// again over its lower half, soft at the sides, with foam where the
  /// water meets it and ripples running out in front of it. At night the
  /// foam glows.
  void _paintSwimming(Canvas canvas, FieldView view) {
    final t = view.time;
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    _mesh.clear();
    _spray.clear();
    for (final p in _spawns) {
      if (p.anchor != reef || p.perch != SpawnPerch.wade) continue;
      final feet = _feet(p);
      final line =
          feet - p.size.y * 0.38 + math.sin(t * 1.4 + p.id.length) * 1.2 * _u;
      final half = p.size.x * 0.62;
      final seed = fieldSeedOf(p.id);
      for (final shift in _shiftsFor(reef, view, half * 1.4)) {
        final x = _spawnX(p) + shift;
        if (x + half * 1.4 < view.left || x - half * 1.4 > view.right) continue;
        final rect = Rect.fromLTRB(
          x - half * 1.1,
          line,
          x + half * 1.1,
          feet + 2 * _u,
        );
        canvas.drawRect(
          rect,
          Paint()
            ..shader = Gradient.linear(
              rect.centerLeft,
              rect.centerRight,
              [
                _seaMid.withValues(alpha: 0),
                _seaMid.withValues(alpha: 0.96),
                _seaMid.withValues(alpha: 0.96),
                _seaMid.withValues(alpha: 0),
              ],
              const [0.0, 0.25, 0.75, 1.0],
            ),
        );
        _foamBand(
          x,
          line + 0.8 * _u,
          half * 0.62,
          3 * _u,
          0.6,
          col,
          seed: seed,
          drift: t * 0.3,
          lace: 0.25,
        );
        for (var r = 0; r < 2; r++) {
          final run = t * 0.4 + r * 0.5;
          final age = run % 1.0;
          final rx = half * (0.65 + age * 0.9);
          _ripple(
            x,
            line + 2 * _u,
            rx,
            rx * 0.16,
            (1.2 + age * 1.5) * _u,
            0.4 * (1 - age) * _ss(0, 0.15, age),
            col,
            seed + r + run.floor() * 7,
            front: true,
          );
        }
      }
    }
    _mesh.draw(canvas);
    _drawSpray(canvas, col);
  }

  // ── The tide ─────────────────────────────────────────────────────────────

  /// The swash at [x] on the flat at [t]: where the water's edge is now,
  /// how far down the sand the last wave ran (the wet sand between), how
  /// long since it came in, and which wave it was. Each wave runs up fast,
  /// slows, and slides back slower, its edge scalloped its own way.
  ({double edge, double reach, double since, int wave}) _swash(
    double x,
    double t,
  ) {
    final p = _period(shelf);
    final u = _wavePhase(shelf, x, t);
    final wave = u.floor();
    final since = (u - wave) * _wavePeriod;
    final seed = 4700 + (fieldHash(wave, 4699) * 4000).floor();
    final run =
        (5 + 8 * swell) *
            _u *
            (0.75 + 0.25 * fieldLoopNoise(x, 260 * _u, 4701, p)) +
        2.4 * _u * fieldLoopNoise(x, 40 * _u, seed, p);
    final up = since < 1.3
        ? 1 - math.pow(1 - since / 1.3, 3).toDouble()
        : 0.5 +
              0.5 *
                  math.cos(
                    math.pi *
                        ((since - 1.3) / (_wavePeriod * 0.8 - 1.3)).clamp(
                          0.0,
                          1.0,
                        ),
                  );
    return (
      edge: _waterline + run * up,
      reach: _waterline + run,
      since: since,
      wave: wave,
    );
  }

  final List<double> _swX = [],
      _swEdge = [],
      _swReach = [],
      _swSince = [],
      _swFoam = [];
  final List<int> _swWave = [];

  /// The water over the flat, as a live sheet under the shelf's rocks: deep
  /// where it is deep and a clear film at its edge, the waves coming in over
  /// it, each running up the sand in a line of foam and sliding back, the
  /// foam coming apart as it goes and the sand it left shining wet until it
  /// dries. At night the foam glows.
  void _paintWater(Canvas canvas, FieldView view) {
    final t = view.time;
    final top = _flatTop - 3 * _u;
    final p = _period(shelf);
    final s = swell;
    final glow = _night * (1 - fog * 0.6);
    final sky = _light.skyAt(0.45);
    final step = 8 * _u;
    final g0 = (view.left / step).floor() - 2;
    final n = ((view.right - view.left) / step).ceil() + 5;
    _swX.clear();
    _swEdge.clear();
    _swReach.clear();
    _swSince.clear();
    _swWave.clear();
    _swFoam.clear();
    for (var i = 0; i < n; i++) {
      final x = (g0 + i) * step;
      final w = _swash(x, t);
      _swX.add(x);
      _swEdge.add(w.edge);
      _swReach.add(w.reach);
      _swSince.add(w.since);
      _swWave.add(w.wave);
    }
    _mesh.clear();

    // The water.
    final deep = _argb(_deep, 0.95);
    final mid = _argb(Color.lerp(_deep, sky, 0.14)!, 0.82);
    final shoal = _argb(Color.lerp(_deep, _shallow, 0.65)!, 0.6);
    final film = _argb(_shallow, 0.3), dry = _argb(_shallow, 0);
    var first = _mesh.count;
    for (var i = 0; i < n; i++) {
      final x = _swX[i], e = _swEdge[i];
      final m = top + (e - top) * 0.55;
      _mesh
        ..add(x, top, deep)
        ..add(x, m, mid)
        ..add(x, math.max(m, e - 5 * _u), shoal)
        ..add(x, e, film)
        ..add(x, e + 1.2 * _u, dry);
    }
    _mesh.strip(first, n, 5);

    // The waves coming in over it.
    _swells(
      view,
      shelf,
      from: _flatTop,
      to: _waterline,
      count: _shelfWaves,
      thin: 2.5 * _u,
      thick: 6 * _u * (1 + 0.5 * s),
      strength: 0.9 * _ss(4 * _u, 30 * _u, _waterline - _flatTop),
    );

    // The sand the last wave left, shining wet, drying.
    final sheen = _rgb(_sheen);
    first = _mesh.count;
    for (var i = 0; i < n; i++) {
      final x = _swX[i], e = _swEdge[i], since = _swSince[i];
      final wet = since < 1.3
          ? 0.0
          : 0.45 * (1 - _ss(1.3, _wavePeriod, since));
      _mesh
        ..add(x, e, _at(sheen, wet))
        ..add(x, math.max(e, _swReach[i]) + 1.5 * _u, _at(sheen, 0));
    }
    _mesh.strip(first, n, 2);

    // The foam on its edge: a broad band of it coming in, bright at its
    // front, thicker in some stretches than others, coming apart as it
    // slides back. At night it lights as it breaks and dims as it settles.
    _spray.clear();
    final foam = _rgb(_foam), lights = _rgb(_glow);
    first = _mesh.count;
    for (var i = 0; i < n; i++) {
      final x = _swX[i], e = _swEdge[i], since = _swSince[i];
      final back = _ss(1.3, _wavePeriod * 0.7, since);
      final stir = _ss(0, 0.4, since) * (1 - _ss(0.6, 2.8, since));
      final seed = 4800 + (fieldHash(_swWave[i], 4799) * 4000).floor();
      final holes = 0.5 + 0.5 * fieldLoopNoise(x, 20 * _u, seed, p);
      final inner = 0.5 + 0.5 * fieldLoopNoise(x, 16 * _u, seed + 2, p);
      final lace = 0.15 + 0.55 * back;
      final a =
          (0.75 - 0.5 * back) *
          (1 + 0.25 * s) *
          _ss(0, 0.35, since) *
          _ss(lace - 0.15, lace + 0.2, holes);
      final fw =
          (3 + 5 * (0.5 + 0.5 * fieldLoopNoise(x, 60 * _u, seed + 3, p))) *
          _u *
          (1 + 0.4 * s) *
          (1 - 0.45 * back);
      final col = _mix(foam, lights, glow * (0.2 + 0.7 * stir));
      _swFoam.add(a);
      _mesh
        ..add(x, e - fw, _at(col, 0))
        ..add(x, e - fw * 0.5, _at(col, a * 0.6 * math.sqrt(inner)))
        ..add(x, e - 0.6 * _u, _at(col, a * 0.65))
        ..add(x, e + 1.4 * _u, _at(col, 0));
      // Froth packed in it.
      for (var j = 0; j < 4; j++) {
        final r = fieldHash(i * 4 + j, seed + 4);
        if (r > a * (0.6 + inner)) continue;
        _spray.add(
          r < a * 0.4 ? 4 : 3,
          x + (fieldHash(i * 4 + j, seed + 5) - 0.5) * step,
          e - 0.5 * _u - fieldHash(i * 4 + j, seed + 6) * fw * 0.8,
        );
      }
    }
    _mesh.strip(first, n, 4);

    // After dark the water lights where it has just broken.
    if (glow > 0.05) {
      first = _mesh.count;
      for (var i = 0; i < n; i++) {
        final x = _swX[i], e = _swEdge[i], since = _swSince[i];
        final stir = _ss(0, 0.4, since) * (1 - _ss(0.6, 2.8, since));
        final lit = 0.3 + 0.7 * (_swFoam[i] / 0.75).clamp(0.0, 1.0);
        _mesh
          ..add(x, e - 7 * _u, _at(lights, 0))
          ..add(x, e - 1 * _u, _at(lights, 0.32 * glow * stir * lit))
          ..add(x, e + 4 * _u, _at(lights, 0));
      }
      _mesh.strip(first, n, 3);
    }
    _mesh.draw(canvas);
    _drawSpray(canvas, Color.lerp(_foam, _glow, glow * 0.5)!);
  }

  // ── Pools and their anemones ─────────────────────────────────────────────

  /// When each pool was last touched.
  final Map<int, double> _poolTouched = {};
  final GrainBatch _anemoneBatch = GrainBatch(6);
  double _shelfSeen = -1;

  static const _anemoneColors = [
    Color(0xFFE86A9A),
    Color(0xFF8EE0A0),
    Color(0xFFF2A65E),
  ];

  /// The pools the tide has left: still water, and anemones in them that
  /// open in the clear water and close when touched.
  void _paintPools(Canvas canvas, FieldView view) {
    final t = view.time;
    final w = _shelfWidth;
    // Fingers: in a pool, it closes; in the water, a wake.
    for (final p in _stirsFor(shelf, view)) {
      if (p.time <= _shelfSeen) continue;
      _shelfSeen = math.max(_shelfSeen, p.time);
      var inPool = false;
      for (var i = 0; i < _pools.length; i++) {
        final s = _poolShape(i, w);
        final dx = _loopDelta(p.x, s.x, shelf) / s.hw, dy = (p.y - s.y) / s.hh;
        if (dx * dx + dy * dy < 1.6 && s.y > _waterline) {
          _poolTouched[i] = p.time;
          inPool = true;
        }
      }
      if (!inPool && p.y < _waterline && p.y > _flatTop) {
        _wake.add((p.x, p.y, p.time, p.speed < 0.5 ? 1.0 : 0.7));
        if (_wake.length > 60) _wake.removeAt(0);
      }
    }
    _anemoneBatch.clear();
    for (final shift in _shiftsFor(shelf, view, 60 * _u)) {
      for (var i = 0; i < _pools.length; i++) {
        final s = _poolShape(i, w);
        // Under the tide, the pool is just more sea.
        if (s.y - s.hh < _waterline) continue;
        final x0 = s.x + shift;
        if (x0 + s.hw < view.left || x0 - s.hw > view.right) continue;
        final touched = _poolTouched[i];
        final age = touched == null ? 99.0 : t - touched;
        // Closed while touched, opening again after.
        final open = age < 2.5
            ? 0.15
            : (0.15 + 0.85 * ((age - 2.5) / 1.5).clamp(0.0, 1.0));
        final n = 3 + i % 3;
        for (var a = 0; a < n; a++) {
          final ax = x0 + (fieldHash(a, 90 + i) - 0.5) * s.hw * 1.3;
          final ay = s.y + (fieldHash(a, 95 + i) - 0.3) * s.hh * 1.0;
          final ci = (i + a) % 3;
          const tentacles = 13;
          for (var k = 0; k < tentacles; k++) {
            final ang = -math.pi / 2 + (k / (tentacles - 1) - 0.5) * 2.2;
            final sway = math.sin(t * 1.3 + k + a * 2) * 0.15;
            for (var j = 1; j <= 4; j++) {
              final r = j * 1.1 * _u * open * (1 + 0.25 * fieldHash(k, a));
              _anemoneBatch.add(
                ci * 2 + (j == 4 ? 1 : 0),
                ax + math.cos(ang + sway) * r,
                ay + math.sin(ang + sway) * r * 0.9,
              );
            }
          }
          _anemoneBatch.add(ci * 2, ax, ay);
        }
      }
    }
    for (var c = 0; c < 3; c++) {
      final col = Color.lerp(_anemoneColors[c], _light.ambient, 0.5)!;
      _anemoneBatch
        ..draw(canvas, c * 2, 1.0 * _u, col.withValues(alpha: 0.7))
        ..draw(
          canvas,
          c * 2 + 1,
          1.6 * _u,
          Color.lerp(col, const Color(0xFFFFFFFF), 0.4)!.withValues(alpha: 0.9),
        );
    }
  }

  // ── A wake ───────────────────────────────────────────────────────────────

  /// Where a finger went through the water: (x, y, when, strength).
  final List<(double, double, double, double)> _wake = [];
  final GrainBatch _wakeBatch = GrainBatch(3);

  /// Rings spreading behind a finger in the water, and after dark the sea's
  /// own light stirred up where it went, fading.
  void _paintWake(Canvas canvas, FieldView view) {
    final t = view.time;
    _wake.removeWhere((w) => t - w.$3 > 2.5);
    if (_wake.isEmpty) return;
    _wakeBatch.clear();
    _mesh.clear();
    final period = _period(shelf);
    final glow = _night * (1 - fog * 0.5);
    final col = Color.lerp(_foam, _glow, glow * 0.7)!;
    for (final (x0, y, at, k) in _wake) {
      var x = x0;
      if (period > 0) {
        x +=
            period *
            (((view.left + view.right) / 2 - x) / period).roundToDouble();
      }
      final age = t - at;
      final r = (3 + age * 26) * _u;
      final fade = (1 - age / 2.5) * k;
      _ripple(
        x,
        y,
        r,
        r * 0.3,
        (1 + age * 1.2) * _u,
        0.32 * fade * _ss(0, 0.12, age),
        col,
        (at * 100).round(),
        floor: _waterline,
      );
      if (glow > 0.05) {
        for (var i = 0; i < 6; i++) {
          final s = math.sin(t * 5 + i * 1.7 + at);
          if (s < 0) continue;
          _wakeBatch.add(
            fade > 0.5 ? 2 : 1,
            x + (fieldHash(i, (at * 31).round()) - 0.5) * 10 * _u,
            y + (fieldHash(i + 3, (at * 31).round()) - 0.5) * 4 * _u,
          );
        }
      }
    }
    _mesh.draw(canvas);
    if (glow > 0.05) {
      _wakeBatch
        ..draw(canvas, 1, 3 * _u, _glow.withValues(alpha: 0.14 * glow))
        ..draw(canvas, 1, 1.6 * _u, _glow.withValues(alpha: 0.75 * glow))
        ..draw(canvas, 2, 3.6 * _u, _glow.withValues(alpha: 0.18 * glow))
        ..draw(canvas, 2, 2.0 * _u, _glow.withValues(alpha: 0.95 * glow));
    }
  }

  // ── After a swell: shells and glass ──────────────────────────────────────

  final GrainBatch _wrackBatch = GrainBatch(3);

  /// What a swell left on the flat, wherever the tide is not over it:
  /// shells catching the light, and here and there a glass float.
  void _paintWrack(Canvas canvas, FieldView view) {
    final k = _wrack;
    if (k < 0.02) return;
    final w = _shelfWidth;
    final t = view.time;
    _wrackBatch.clear();
    final r = FieldRandom(7701);
    final floats = <Offset>[];
    for (var i = 0; i < 110; i++) {
      final x = r.next() * w;
      final f = r.next();
      final y = _flatTop + 4 * _u + f * (_h - _flatTop - 6 * _u);
      final isFloat = i % 9 == 0;
      if (y < _waterline) continue;
      for (final shift in _shiftsFor(shelf, view, 10 * _u)) {
        final px = x + shift;
        if (px < view.left - 6 || px > view.right + 6) continue;
        if (isFloat) {
          floats.add(Offset(px, y));
        } else {
          final s = math.sin(t * (1 + fieldHash(i, 3)) + i);
          _wrackBatch.add(s > 0.8 ? 2 : (i.isEven ? 0 : 1), px, y);
        }
      }
    }
    _wrackBatch
      ..draw(
        canvas,
        0,
        2.6 * _u,
        const Color(0xFFF2E6D8).withValues(alpha: 0.8 * k),
      )
      ..draw(
        canvas,
        1,
        2.2 * _u,
        const Color(0xFFE8B8A8).withValues(alpha: 0.75 * k),
      )
      ..draw(
        canvas,
        2,
        2.0 * _u,
        const Color(0xFFFFFFFF).withValues(alpha: 0.95 * k),
      );
    // Glass floats: small green-blue spheres, lit on top, a shadow under.
    for (final p in floats) {
      final rad = 5.0 * _u;
      canvas
        ..drawOval(
          Rect.fromCenter(
            center: p + Offset(0, rad * 0.8),
            width: rad * 2.6,
            height: rad * 0.8,
          ),
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.3 * k),
        )
        ..drawCircle(
          p,
          rad,
          Paint()
            ..shader = Gradient.radial(
              p - Offset(rad * 0.35, rad * 0.4),
              rad * 1.4,
              [
                const Color(0xFFCFF6EA).withValues(alpha: 0.9 * k),
                const Color(0xFF3E8C88).withValues(alpha: 0.85 * k),
                const Color(0xFF1C4A50).withValues(alpha: 0.9 * k),
              ],
              const [0.0, 0.5, 1.0],
            ),
        );
    }
  }

  // ── Surf on the shelf ────────────────────────────────────────────────────

  /// Where the tide stands round the shelf's rocks, the waves that reach
  /// them break on them — gently on a calm day, high in a swell.
  void _paintShelfSurf(Canvas canvas, FieldView view) {
    final t = view.time;
    final glow = _night * (1 - fog * 0.6);
    final col = Color.lerp(_foam, _glow, glow * 0.85)!;
    final force = 0.55 + 1.4 * swell;
    _mesh.clear();
    _spray.clear();
    var any = false;
    for (final shift in _shiftsFor(shelf, view, 80 * _u)) {
      for (final k in _columnsOf(shelf)) {
        final x0 = k.x + shift;
        if (x0 + k.hw * 3 < view.left || x0 - k.hw * 3 > view.right) continue;
        final foot = k.base - 2 * _u;
        double since;
        int wave;
        var wet = 1.0;
        if (foot <= _waterline) {
          // Its foot in the sea: every wave passes it.
          (since, wave) = _sinceWave(
            shelf,
            k.x,
            foot,
            t,
            _flatTop,
            _waterline,
            _shelfWaves,
          );
        } else {
          // Its foot on the sand: only a wave that runs up to it.
          final w = _swash(k.x, t);
          if (w.reach <= foot) continue;
          final run = w.reach - _waterline;
          final q = ((foot - _waterline) / run).clamp(0.0, 1.0);
          since = w.since - 1.3 * (1 - math.pow(1 - q, 1 / 3).toDouble());
          wave = w.wave;
          if (since < 0) since += _wavePeriod;
          wet = _ss(foot - 1 * _u, foot + 3 * _u, w.edge);
        }
        any = true;
        _breakOn(
          x0,
          foot,
          k.hw,
          k.top,
          since,
          wave,
          k.seed,
          force,
          glow,
          t,
          wet: wet,
        );
      }
    }
    if (!any) return;
    _mesh.draw(canvas);
    _drawSpray(canvas, col);
  }

  // ── Fog ──────────────────────────────────────────────────────────────────

  /// Sea fog: a wash over the layer, thickest at the water, and banks of it
  /// drifting through.
  void _paintFog(
    Canvas canvas,
    FieldView view,
    SceneLayer layer,
    double top,
    double bottom,
  ) {
    final f = fog;
    if (f < 0.02) return;
    final col = Color.lerp(_light.skyAt(0.55), const Color(0xFFD0D8E0), 0.3)!;
    final y0 = _h * top, y1 = _h * bottom;
    canvas.drawRect(
      Rect.fromLTRB(view.left, y0, view.right, y1),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, y0),
          Offset(0, y1),
          [
            col.withValues(alpha: 0),
            col.withValues(alpha: 0.55 * f),
            col.withValues(alpha: 0.3 * f),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    final t = view.time;
    final p = _period(layer);
    final tiles = p > 0 ? math.max(1, (p / (360 * _u)).round()) : 0;
    final s = tiles > 0 ? p / tiles : 360 * _u;
    final k0 = ((view.left - 200 * _u) / s).floor();
    final k1 = ((view.right + 200 * _u) / s).floor();
    for (var k = k0; k <= k1; k++) {
      final kk = tiles > 0 ? k % tiles : k;
      final h0 = fieldHash(kk, 600 + layer.index);
      final ph = (h0 + t * 6 * _u / s) % 1.0;
      final c = Offset((k + ph) * s, y0 + (y1 - y0) * (0.3 + 0.5 * h0));
      final r = (120 + 80 * h0) * _u;
      canvas.drawOval(
        Rect.fromCenter(center: c, width: r * 2.6, height: r * 0.7),
        Paint()
          ..shader = Gradient.radial(c, r * 1.3, [
            col.withValues(alpha: 0.32 * f * math.sin(ph * math.pi)),
            col.withValues(alpha: 0),
          ]),
      );
    }
  }

  // ── Fore ─────────────────────────────────────────────────────────────────

  List<(double, double, double)> _makeForeTops(double w) {
    final r = FieldRandom(6601);
    final out = <(double, double, double)>[];
    var x = r.range(700, 900) * _u;
    while (x < w) {
      out.add((x, r.range(40, 80) * _u, r.range(0.04, 0.09) * _h));
      x += r.range(700, 1300) * _u;
    }
    return out;
  }

  /// Kelp over the near columns' tops, long and swaying.
  _Blades _makeKelp(double w) {
    final b = _BladeBuilder();
    final r = FieldRandom(6611);
    for (final (cx, hw, ht) in _foreTops) {
      final n = 6 + (r.next() * 6).floor();
      for (var i = 0; i < n; i++) {
        final off = r.range(-1, 1) * hw;
        final x = cx + off;
        b.add(
          x: _loop ? x % w : x,
          base: _h - ht + 4 * _u,
          height: r.range(24, 60) * _u,
          lean: off / hw * 0.3 + r.range(-0.1, 0.1),
          phase: r.range(0, math.pi * 2),
          depth: 1,
          row: 0,
        );
      }
    }
    return b.done();
  }
}

/// Soft filled shapes built up over a frame and drawn in one call: the
/// sea's moving water — waves, white water, swash — which may not be drawn
/// as paths every frame. Each vertex carries its own color, so a shape
/// fades to nothing at its edges by its vertices alone.
class _WaterMesh {
  Float32List _pos = Float32List(8192);
  Int32List _col = Int32List(4096);
  Uint16List _idx = Uint16List(12288);
  int _v = 0, _k = 0;
  static final Paint _paint = Paint();

  /// The vertices so far: the index the next one will have.
  int get count => _v;

  void clear() {
    _v = 0;
    _k = 0;
  }

  int add(double x, double y, int argb) {
    if (_v >= _col.length) {
      _pos = Float32List(_pos.length * 2)..setAll(0, _pos);
      _col = Int32List(_col.length * 2)..setAll(0, _col);
    }
    _pos[_v * 2] = x;
    _pos[_v * 2 + 1] = y;
    _col[_v] = argb;
    return _v++;
  }

  /// Joins [cols] columns of [rows] vertices each, added from [first] a
  /// column at a time (each column's from the top down), into a sheet.
  void strip(int first, int cols, int rows) {
    final need = _k + (cols - 1) * (rows - 1) * 6;
    if (need > _idx.length) {
      _idx = Uint16List(math.max(need, _idx.length * 2))..setAll(0, _idx);
    }
    for (var i = 0; i + 1 < cols; i++) {
      for (var r = 0; r + 1 < rows; r++) {
        final a = first + i * rows + r, b = a + rows;
        _idx
          ..[_k++] = a
          ..[_k++] = b
          ..[_k++] = a + 1
          ..[_k++] = a + 1
          ..[_k++] = b
          ..[_k++] = b + 1;
      }
    }
  }

  void draw(Canvas canvas) {
    if (_k == 0) return;
    assert(_v <= 0xFFFF, 'too much water in one mesh');
    canvas.drawVertices(
      Vertices.raw(
        VertexMode.triangles,
        Float32List.sublistView(_pos, 0, _v * 2),
        colors: Int32List.sublistView(_col, 0, _v),
        indices: Uint16List.sublistView(_idx, 0, _k),
      ),
      BlendMode.srcOver,
      _paint,
    );
  }
}
