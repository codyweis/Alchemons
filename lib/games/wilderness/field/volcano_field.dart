part of 'grain_field.dart';

// The Volcano — the Ashen Volcano — through the day.
//
// A great cone stands smoking over a land of black rock and lava, under a
// sky the ash keeps red all day. Ranges stand off in the haze behind it,
// cloud lies about its foot, and its plume climbs out of the crater and
// leans away on the wind, lit from beneath where it leaves the fire.
// Nearer, red hills run down to a lake of lava; nearest, shelves of basalt
// and banks of cinder stand up out of a lava field crusted black, its
// cracks glowing. The creatures stand on the rock; the lava between is
// lava. Embers rise off it, now and then it spits, a finger on it breaks
// the crust, and a finger through the dry grass on the rock lifts the ash.
// The light follows the phone's clock like the other fields', but the ash
// keeps it warm: the sun is a disc in the haze by day, and at night the
// lava is what lights the land.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): sun, moon, a few stars
//   layer2  — ash drifting high, the far ranges, the volcano and its
//             plume, cloud about its foot
//   layer3  — the red hills, the lava lake at their feet, spires and the
//             back shelves standing in it
//   layer4  — the lava field, the shelves the creatures stand on, dead
//             trees, the vent whose steam the floaters ride
//   layer5  — black rock, nearest of all
//
// The shelves the creatures use are built from the spawn points: one under
// each standing creature, and one under the place each encounter's partner
// stands, so a partner that cannot float always has rock. Nothing stands on
// the lava.
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   ranges   r = haze, b = haze × how low, g = fleck
//   rock     r = haze, b = shade, g = fleck (the cone, the hills, the
//            shelves, the trees, the ash on them)
//   lava     r, g = heat (crust → orange → yellow), b = the crust's shade;
//            the heat is its own light, not the hour's
//   glow     the lava's light on what stands over it: r = how warm, alpha
//            how much — stronger the darker the hour
//   ash      r = underside, g = glitter, b = lit from below by the fire
//
// Every full-width sheet reaches a little past the start of its loop, so
// where two copies meet they overlap with the same picture and nothing
// behind shows through the seam. Each ends half a unit short of its loop's
// end — the next copy's overlap covers that — so with the camera resting
// at a loop's start no copy is drawn that is not on screen.

class VolcanoField extends _GrainField {
  VolcanoField();

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const near = SceneLayer.layer4;
  static const fore = SceneLayer.layer5;

  static const _gAsh = 0, _gRange = 1, _gCone = 2, _gHill = 3, _gRock = 4;
  static const _gAshTop = 5, _gFarLava = 6, _gMidLava = 7, _gLava = 8;
  static const _gGlow = 9;

  /// Daylight colours of the land; the hour's ambient light multiplies
  /// them.
  static const _albedo = <int, Color>{
    _gRange: Color(0xFF6C2C32),
    _gCone: Color(0xFF4E2020),
    _gHill: Color(0xFF8A3828),
    _gRock: Color(0xFF3E2422),
    _gAshTop: Color(0xFF8E8078),
  };

  /// The plume's ash in daylight, and an eruption's, darker.
  static const _plumeAsh = Color(0xFF6E5A54), _eruptionAsh = Color(0xFF4A3C38);

  /// The lava's crust, and the colours its heat runs through.
  static const _crust = Color(0xFF34201E);
  static const _lavaOrange = Color(0xFFF05A1C), _lavaHot = Color(0xFFFFCC52);

  /// The lava's light on what stands over it, from dull to warm.
  static const _glowDeep = Color(0xFFA02C14), _glowWarm = Color(0xFFFF7C30);

  /// Where things stand, as shares of the height: the crater's rim and the
  /// cone's foot; where the lava lake and the near lava field begin.
  static const _coneTop = 0.24, _coneFoot = 0.63;
  static const _midLavaTop = 0.652, _nearLavaTop = 0.765;

  /// Where the cone stands on its layer (layer units), and half its width
  /// at the reference height.
  static const _coneX = 560.0, _coneHw = 310.0;

  /// How fast the ash high up and the smoke over the lava drift, in units
  /// a second at the reference height.
  static const _ashDrift = 3.0, _midSmokeDrift = 4.5, _nearSmokeDrift = 7.0;

  /// The lava's maps for heat [h] (0 crust, 0.5 orange, 1 yellow) and the
  /// crust's [shade].
  static Color _heat(double h, {double shade = 0, double a = 1}) =>
      fieldMap(math.min(1.0, h * 2), math.max(0.0, h * 2 - 1), shade, a);

  @override
  List<(double, _Light)> get _keys => _volcanoKeys;

  // The sun goes down behind the far ranges; the ash hides all but the
  // brightest stars, and tints the moon.
  @override
  double get _horizon => 0.55;

  @override
  int get _starCount => 70;

  @override
  double get _starDepth => 0.4;

  // Ash veils the sun; an eruption's cloud all but hides it.
  @override
  double get _veil => switch (stage) {
    still => 0.12,
    erupting => 0.62,
    _ => 0.16,
  };

  @override
  double get _weatherKey => stage.toDouble();

  /// The hour's light under an eruption's cloud: the sky high up darkened
  /// toward black, low down lit red by the fire, the land dimmer and
  /// redder, the sun's light on the edges weak, no stars.
  @override
  _Light _weathered(_Light l) {
    if (!_erupting) return l;
    final a = l.ambient;
    return _Light(
      stops: l.stops,
      sky: [
        for (var i = 0; i < l.sky.length; i++)
          i < 4
              ? Color.lerp(l.sky[i], const Color(0xFF140808), 0.5)!
              : Color.lerp(l.sky[i], const Color(0xFF6A2014), 0.32)!,
      ],
      ambient: Color.from(
        alpha: 1,
        red: a.r * 0.82,
        green: a.g * 0.66,
        blue: a.b * 0.62,
      ),
      rim: l.rim,
      rimStrength: l.rimStrength * 0.5,
      floor: l.floor,
      glow: l.glow * 0.35,
      stars: 0,
      cloudTop: Color.lerp(l.cloudTop, const Color(0xFF2A1210), 0.5)!,
      cloudBottom: Color.lerp(l.cloudBottom, const Color(0xFFB0401C), 0.45)!,
      cloudGlint: l.cloudGlint,
      grass: [
        for (final c in l.grass) Color.lerp(c, const Color(0xFF000000), 0.15)!,
      ],
      mote: l.mote,
      firefly: l.firefly,
    );
  }

  @override
  Color _sunDisc(double low) =>
      Color.lerp(const Color(0xFFFFEAA0), const Color(0xFFFFC266), low)!;

  @override
  Color get _moonFace => const Color(0xFFF2D6C4);

  @override
  double get _windScale => 0.8;

  /// Only some of the glints the light sheets lay down are kept: on this
  /// much rock, all of them would read as glitter.
  @override
  void _glint(double x, double y) {
    if (fieldHash(_glintSeen++, 983) < 0.22) super._glint(x, y);
  }

  int _glintSeen = 0;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 1.0,
    mid => 0.9,
    _ => 0.85,
  };

  // ── The light ────────────────────────────────────────────────────────────

  /// The lava's slow breathing, and how dark the hour is (0 by day, 1 at
  /// night) — the darker, the more the lava lights the land.
  double _pulse = 1;
  double get _night =>
      ((0.42 - _light.ambient.computeLuminance()) / 0.38).clamp(0.0, 1.0);

  /// How far into a surge the eruption is this frame (see [_surgeAt]).
  double _surge = 0;

  @override
  void prepare(double hour, {double time = 0}) {
    final p =
        0.94 + 0.04 * math.sin(time * 0.83) + 0.02 * math.sin(time * 2.3 + 1.3);
    final surge = _surgeAt(time);
    final breathed =
        (p - _pulse).abs() > 0.003 || (surge - _surge).abs() > 0.004;
    if (breathed) {
      _pulse = p;
      _surge = surge;
    }
    final before = _hour;
    super.prepare(hour, time: time);
    // A new hour rebuilt every grade; otherwise only the lava's breathe.
    if (breathed && _hour == before) _gradeLava(_light);
  }

  Color _sil(Color a, _Light l) => Color.from(
    alpha: 1,
    red: a.r * l.ambient.r,
    green: a.g * l.ambient.g,
    blue: a.b * l.ambient.b,
  );

  @override
  void _buildGrades(_Light l) {
    final hazeHigh = l.skyAt(0.42), hazeLow = l.skyAt(0.585);
    Color sil(int g) => _sil(_albedo[g]!, l);
    (double, double, double) fleck(Color s, double k) => (
      s.r * 0.9 + l.rim.r * l.rimStrength * k,
      s.g * 0.9 + l.rim.g * l.rimStrength * k,
      s.b * 0.9 + l.rim.b * l.rimStrength * k,
    );

    final f = sil(_gRange);
    _grades[_gRange] = fieldGrade(
      base: f,
      r: fieldDiff(hazeHigh, f),
      g: fleck(f, 0.3),
      b: fieldDiff(hazeLow, hazeHigh),
    );
    final cone = sil(_gCone);
    _grades[_gCone] = fieldGrade(
      base: cone,
      r: fieldDiff(l.skyAt(0.5), cone),
      g: fleck(cone, 0.4),
      b: fieldScale(cone, -0.72),
    );
    for (final g in [_gHill, _gRock, _gAshTop]) {
      final s = sil(g);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(hazeLow, s),
        g: fleck(s, 0.4),
        b: fieldScale(s, -0.72),
      );
    }
    final fire = Color.lerp(l.cloudBottom, _glowWarm, 0.25 + 0.45 * _night)!;
    _grades[_gAsh] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldScale(l.cloudGlint, 0.85),
      b: fieldDiff(fire, l.cloudTop),
    );
    _gradeLava(l);
  }

  /// The lava's grades, breathing: the crust lit as the hour lights rock,
  /// the heat its own colour (hazed with distance), and its light on what
  /// stands over it.
  void _gradeLava(_Light l) {
    final hz = l.skyAt(0.585);
    final crust = _sil(_crust, l);
    for (final (g, haze) in [
      (_gLava, 0.0),
      (_gMidLava, 0.22),
      (_gFarLava, 0.4),
    ]) {
      Color mix(Color c) => Color.lerp(c, hz, haze)!;
      final base = mix(crust);
      final orange = mix(_lavaOrange), hot = mix(_lavaHot);
      // The cone's own fire follows its mood: its channels cooled almost
      // to crust while it is quiet, blazing while it erupts.
      final mood = g != _gFarLava
          ? 1 + 0.06 * _surge
          : switch (stage) {
              still => 0.12,
              erupting => 1.12 + 0.3 * _surge,
              _ => 1.0,
            };
      final p = _pulse * mood;
      _grades[g] = fieldGrade(
        base: base,
        r: (
          (orange.r - base.r) * p,
          (orange.g - base.g) * p,
          (orange.b - base.b) * p,
        ),
        g: (
          (hot.r - orange.r) * p,
          (hot.g - orange.g) * p,
          (hot.b - orange.b) * p,
        ),
        b: fieldScale(base, -0.72),
      );
    }
    const d = _glowDeep, w = _glowWarm;
    final k =
        (0.32 + 0.68 * _night) * _pulse +
        (_erupting ? 0.16 + 0.32 * _surge : 0);
    _grades[_gGlow] = ColorFilter.matrix(<double>[
      w.r - d.r, 0, 0, 0, d.r * 255, //
      w.g - d.g, 0, 0, 0, d.g * 255,
      w.b - d.b, 0, 0, 0, d.b * 255,
      0, 0, 0, k, 0,
    ]);
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// The shelves of the mid and near layers, as built for this screen.
  final Map<SceneLayer, List<_Shelf>> _shelves = {};

  /// Every standing point on the near and mid layers stands on its own
  /// shelf, seated by the creature's feet.
  @override
  double? perchFor(String spawnId) {
    for (final p in _spawns) {
      if (p.id != spawnId || p.aloft) continue;
      if (p.anchor == near || p.anchor == mid) return _feet(p);
    }
    return null;
  }

  /// The shelf over [x] on [layer], and [x] moved into that shelf's own
  /// loop.
  (_Shelf, double)? _shelfAt(SceneLayer layer, double x, {double reach = 1}) {
    for (final s in _shelves[layer] ?? const <_Shelf>[]) {
      final d = _loopDelta(x, s.cx, layer);
      if (d.abs() < s.hw * reach) return (s, s.cx + d);
    }
    return null;
  }

  // On a shelf there is no deeper ground to stand in, and off one there is
  // only lava: anything over a shelf that cannot float is stood on its top.
  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    final at = _shelfAt(layer, x, reach: 0.86);
    if (at == null) return null;
    final (s, lx) = at;
    return (top: double.infinity, rest: _sStand(s, lx) + 1 * _u);
  }

  /// The shelves on [layer] as built: each one's span, from the top of its
  /// back to the lava at its foot.
  @visibleForTesting
  List<Rect> debugShelves(SceneLayer layer) => [
    for (final s in _shelves[layer] ?? const <_Shelf>[])
      Rect.fromLTRB(
        s.cx - s.hw - s.flare,
        _sBack(s, s.cx),
        s.cx + s.hw + s.flare,
        _sLava(s),
      ),
  ];

  /// Rock with a dead tree on it, nobody's perch: (x as a share of the
  /// loop, its top as a share of the height, half width).
  static const _treeRocks = <(double, double, double)>[
    (0.04, 0.792, 44),
    (0.28, 0.80, 38),
  ];

  List<_Shelf> _makeShelves(SceneLayer layer) {
    final back = layer == mid;
    final shelves = <_Shelf>[];
    var seed = back ? 300 : 200;
    final k = back ? 0.62 : 1.0;
    _Shelf shelf(
      double cx,
      double hw,
      double stand, {
      double? seatX,
      bool basalt = false,
      int steps = 0,
    }) {
      final s = seed++;
      final r = FieldRandom(s * 13);
      final b = _Shelf(
        cx: cx,
        hw: hw,
        plate: (basalt ? 14 : 12) * k * _u,
        rise: (basalt ? r.range(34, 44) : r.range(16, 22)) * k * _u,
        flare: hw * (basalt ? r.range(0.05, 0.1) : 0.03),
        seed: s,
        haze: back ? 0.3 : 0.0,
        basalt: basalt,
        steps: steps,
      );
      // Seat it so feet at [seatX] stand at [stand].
      b.level = stand - _sStand(b, seatX ?? cx);
      return b;
    }

    // Ground points in x order on the layer stand on basalt and cinder by
    // turns, and each one's partner on the other.
    final points = _spawns.where((p) => p.anchor == layer).toList()
      ..sort((a, b) => _spawnX(a).compareTo(_spawnX(b)));
    var ground = 0;
    for (final p in points) {
      final x = _spawnX(p);
      final side = p.partnerSide;
      final px = x + side * kFieldPairGap;
      final bp = p.getBattlePos();
      final size = p.size.x;
      final basalt = !p.aloft && ground++ % 2 == 0;
      // Shelves under creatures are sized by the creatures, not the
      // screen: the pace between a pair is the same on every screen.
      if (!p.aloft) {
        final hw = size * (basalt ? 1.0 : 1.15);
        shelves.add(
          shelf(
            x + side * hw * 0.15,
            hw,
            _feet(p),
            seatX: x,
            basalt: basalt,
            // A basalt shelf steps down on the side away from its partner.
            steps: basalt ? -side.round() : 0,
          ),
        );
      }
      // Under where its encounter partner stands.
      if (!_partners) continue;
      final hw = size * (basalt ? 0.8 : 0.85);
      shelves.add(
        shelf(
          px + side * hw * 0.1,
          hw,
          bp.dy * _h + size * 0.5,
          seatX: px,
          basalt: !basalt,
        ),
      );
    }
    if (!back) {
      final w = _widths[layer] ?? _worldWidth;
      for (final (fx, fy, fhw) in _treeRocks) {
        shelves.add(shelf(fx * w, fhw * _u, fy * _h, basalt: true));
      }
    }
    return shelves;
  }

  // ── A shelf's shape (layer-local units) ──────────────────────────────────

  double _st(_Shelf s, double x) => ((x - s.cx) / s.hw).clamp(-1.0, 1.0);

  /// The lava at a shelf's foot.
  double _sLava(_Shelf s) => s.level + s.plate * 0.45 + s.rise;

  /// Where feet stand on [s] at [x]. Basalt is flat, stepping down at one
  /// end; a bank of cinder crowns, and slopes away into the lava at its
  /// ends.
  double _sStand(_Shelf s, double x) {
    final t = _st(s, x);
    if (s.basalt) {
      var y = s.level;
      if (s.steps != 0) {
        final k = t * s.steps;
        if (k > 0.6) y += s.rise * 0.18;
        if (k > 0.8) y += s.rise * 0.18;
      }
      return y;
    }
    return s.level +
        (s.rise + s.plate * 0.45) * math.pow(t.abs(), 3.2) +
        s.plate * 0.12 * fieldNoise(x / (20 * _u), s.seed);
  }

  double _sPinch(_Shelf s, double x) =>
      (1 - math.pow(_st(s, x).abs(), s.basalt ? 8 : 5)).toDouble();

  /// The back of its top, against what is behind it — on basalt, broken
  /// uneven.
  double _sBack(_Shelf s, double x) {
    final wear = s.basalt
        ? 0.8 + 0.4 * (fieldNoise(x / (13 * _u), s.seed + 4) * 0.5 + 0.5)
        : 1.0;
    return _sStand(s, x) - s.plate * 0.55 * _sPinch(s, x) * wear;
  }

  /// The front lip of its top, where the face drops to the lava. Basalt
  /// breaks in columns, so its lip steps a little from one to the next.
  double _sFront(_Shelf s, double x) {
    var y = _sStand(s, x) + s.plate * 0.45 * _sPinch(s, x);
    if (s.basalt) {
      final col = ((x - s.cx) / (s.hw * 0.13)).floor();
      y += (fieldHash(col, s.seed + 9) - 0.3) * 1.6 * _u;
    }
    return y;
  }

  /// Where its face meets the lava, a little uneven.
  double _lavaEdge(_Shelf s, double x) =>
      _sLava(s) + 1.2 * _u * fieldNoise(x / (7 * _u), s.seed + 2);

  Rect _shelfBounds(_Shelf s) => Rect.fromLTRB(
    s.cx - s.hw - s.flare - 16 * _u,
    _sBack(s, s.cx) - 34 * _u,
    s.cx + s.hw + s.flare + 16 * _u,
    _sLava(s) + 22 * _u,
  );

  // ── Layout for the current screen ────────────────────────────────────────

  final Map<SceneLayer, List<_Plate>> _plates = {};
  final Map<SceneLayer, List<_Band>> _bands = {};
  final Map<SceneLayer, List<_Spire>> _spires = {};
  final List<_Snag> _snags = [];
  _Vent? _vent;
  _Blades? _nearBlades;
  _Blades? _foreBlades;
  _Plume? _plume;
  final Map<SceneLayer, _Embers> _embers = {};
  double _nearWidth = 0;
  double _foreWidth = 0;

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    // Full-width sheets reach back past the loop's start (see the top).
    final m = 8 * _u;
    switch (layer) {
      case far:
        _cloudWidth = w;
        _plume = _makePlume();
        _billows ??= _makeBillows();
        _channelPts = [
          for (final (q0, slant, reach, seed) in _channels)
            _channel(_cones.first, _coneX, q0, slant, reach, seed),
        ];
        final land = Rect.fromLTRB(-m, _h * 0.3, w - 0.5, _h * 0.7);
        final cones = Rect.fromLTRB(-m, _h * 0.2, w - 0.5, _h * 0.7);
        final burning = _cones.first;
        final fire = Rect.fromLTRB(
          burning.x - burning.hw * _u * 1.1,
          _h * (burning.top - 0.04),
          burning.x + burning.hw * _u * 1.1,
          _h * (burning.foot + 0.06),
        );
        void eachCone(void Function(_Cone k, double x) paint) {
          for (final k in _cones) {
            _wrapped(k.x, k.hw * _u * 1.1, w, (x) => paint(k, x));
          }
        }

        return [
          FieldSheet(
            bounds: Rect.fromLTWH(0, 0, w, _h * 0.46),
            drift: _ashDrift * _u,
            resolution: 0.5,
            grade: _gAsh,
            paint: (c) => _paintAshBands(c, w),
          ),
          FieldSheet(
            bounds: land,
            resolution: 0.6,
            grade: _gRange,
            paint: (c) => _paintRanges(c, w),
          ),
          FieldSheet(
            bounds: cones,
            resolution: 0.8,
            grade: _gCone,
            paint: (c) => eachCone((k, x) => _paintCone(c, k, x)),
          ),
          FieldSheet(
            bounds: fire,
            resolution: 0.8,
            grade: _gFarLava,
            paint: (c) => _paintConeLava(c, burning, burning.x),
          ),
          // An eruption's flow down the cone's face.
          FieldSheet.live(
            bounds: fire,
            live: (c, v) => _paintFlowOn(c, v, far),
          ),
          // The light on the ranges and the cones.
          FieldSheet(
            bounds: cones,
            resolution: 0.65,
            light: true,
            paint: (c) {
              _paintRangeLight(c, w);
              _sinking(far, () => eachCone((k, x) => _paintConeLight(c, k, x)));
            },
          ),
          // The cloud about the cones' feet.
          FieldSheet(
            bounds: Rect.fromLTRB(-m, _h * 0.5, w - 0.5, _h * 0.68),
            resolution: 0.5,
            grade: _gAsh,
            paint: (c) => _paintCloudBank(c, w),
          ),
        ];
      case mid:
        _glints[mid] = _Glints();
        final shelves = _shelves[mid] = _makeShelves(mid);
        final spires = _spires[mid] = _midSpires(w);
        _bands[mid] = _makeBands(mid, w);
        final plates = _plates[mid] = _crustCells(mid, w);
        _embers[mid] = _makeEmbers(mid, w);
        final hills = Rect.fromLTRB(-m, _h * 0.42, w - 0.5, _h * 0.7);
        final lava = Rect.fromLTRB(
          -m,
          _h * (_midLavaTop - 0.01),
          w - 0.5,
          _h * 0.88,
        );
        return [
          FieldSheet(
            bounds: hills,
            resolution: 0.7,
            grade: _gHill,
            paint: (c) => _paintHills(c, w),
          ),
          FieldSheet(
            bounds: hills,
            resolution: 0.6,
            light: true,
            paint: (c) => _paintHillLight(c, w),
          ),
          FieldSheet(
            bounds: lava,
            resolution: 0.7,
            grade: _gMidLava,
            paint: (c) => _paintLavaField(c, w, mid, plates),
          ),
          // The lake's light: on the hills' lower slopes, and on the crust
          // round its open lava.
          FieldSheet(
            bounds: Rect.fromLTRB(-m, _h * 0.56, w - 0.5, lava.bottom),
            resolution: 0.6,
            grade: _gGlow,
            paint: (c) {
              _paintHillGlow(c, w);
              _paintCrustGlow(c, w, mid, plates);
            },
          ),
          // An eruption's flow over the hills and across the lake, under
          // what stands in it.
          FieldSheet.live(
            bounds: Rect.fromLTRB(0, _h * 0.5, w, _h * 0.8),
            live: (c, v) => _paintFlowOn(c, v, mid),
          ),
          FieldSheet(
            bounds: Rect.fromLTWH(0, _h * 0.6, w, _h * 0.16),
            drift: _midSmokeDrift * _u,
            resolution: 0.45,
            grade: _gAsh,
            paint: (c) => _paintSmoke(c, w, _h * 0.67, 0.3, seed: 61),
          ),
          ..._rockSheets(mid, w, shelves, spires, null),
        ];
      case near:
        _glints[near] = _Glints();
        _nearWidth = w;
        final shelves = _shelves[near] = _makeShelves(near);
        final spires = _spires[near] = _nearSpires(w);
        _vent = _makeVent(w);
        _bands[near] = _makeBands(near, w);
        final plates = _plates[near] = _crustCells(near, w);
        _snags
          ..clear()
          ..addAll(_makeSnags(shelves));
        _nearBlades = _shelfGrass(shelves);
        _embers[near] = _makeEmbers(near, w);
        final lava = Rect.fromLTRB(
          -m,
          _h * (_nearLavaTop - 0.01),
          w - 0.5,
          _h + 8 * _u,
        );
        return [
          FieldSheet(
            bounds: lava,
            resolution: 0.85,
            grade: _gLava,
            paint: (c) => _paintLavaField(c, w, near, plates),
          ),
          FieldSheet(
            bounds: lava,
            resolution: 0.7,
            grade: _gGlow,
            paint: (c) => _paintCrustGlow(c, w, near, plates),
          ),
          // An eruption's flow coming on across the near field, under the
          // rock.
          FieldSheet.live(
            bounds: lava,
            live: (c, v) => _paintFlowOn(c, v, near),
          ),
          for (final t in _snags) ..._snagSheets(t),
          ..._rockSheets(near, w, shelves, spires, _vent),
          if (_vent case final v?) ...[
            FieldSheet(
              bounds: Rect.fromLTRB(
                v.x - 50 * _u,
                _h * 0.28,
                v.x + 70 * _u,
                v.base - v.h + 4 * _u,
              ),
              resolution: 0.6,
              grade: _gAshTop,
              paint: (c) => _paintSteamBody(c, v),
            ),
            FieldSheet(
              bounds: Rect.fromLTRB(
                v.x - 50 * _u,
                _h * 0.28,
                v.x + 70 * _u,
                v.base - v.h + 4 * _u,
              ),
              resolution: 0.5,
              grade: _gGlow,
              paint: (c) => _paintSteamGlow(c, v),
            ),
          ],
          FieldSheet(
            bounds: Rect.fromLTWH(0, _h * 0.74, w, _h * 0.2),
            drift: _nearSmokeDrift * _u,
            resolution: 0.45,
            grade: _gAsh,
            paint: (c) => _paintSmoke(c, w, _h * 0.83, 0.2, seed: 71),
          ),
        ];
      case fore:
        _foreWidth = w;
        final rocks = _foreRocks(w);
        _foreBlades = _foreTufts(rocks);
        final b = Rect.fromLTRB(-m, _h * 0.8, w - 0.5, _h + 10 * _u);
        return [
          FieldSheet(
            bounds: b,
            grade: _gRock,
            paint: (c) {
              for (final r in rocks) {
                _wrapped(r.x, r.hw * 1.3, w, (x) => _paintSpire(c, r.at(x)));
              }
            },
          ),
          FieldSheet(
            bounds: b,
            resolution: 0.7,
            grade: _gGlow,
            paint: (c) {
              for (final r in rocks) {
                _wrapped(
                  r.x,
                  r.hw * 1.3,
                  w,
                  (x) => _paintSpireGlow(c, r.at(x)),
                );
              }
            },
          ),
          FieldSheet(
            bounds: b,
            resolution: 0.8,
            light: true,
            paint: (c) {
              final sparks = GrainBatch(_sparkAlpha.length);
              for (final r in rocks) {
                _wrapped(
                  r.x,
                  r.hw * 1.3,
                  w,
                  (x) => _paintSpireLight(c, r.at(x), sparks),
                );
              }
              _drawSparks(c, sparks, 1.8);
            },
          ),
        ];
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    near => true,
    far || mid || fore => !front,
    _ => false,
  };

  // ── Far: the ash, the ranges, the cone ───────────────────────────────────

  double _fn(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(far));

  /// Ridged noise in [0, 1]: sharp crests where the noise crosses zero.
  double _ridged(double x, double wave, int seed) {
    final n = 1 - _fn(x, wave, seed).abs();
    return n * n;
  }

  /// Ash drifting high over the land: long thin bands of it, lit beneath
  /// toward the horizon, wrapping round the sheet so it can drift for ever.
  void _paintAshBands(Canvas c, double w) {
    final r = FieldRandom(141);
    final n = math.max(6, (w / (190 * _u)).round());
    for (var k = 0; k < n; k++) {
      final cx = (k + r.range(0.1, 0.9)) * w / n;
      final cy = _h * r.range(0.04, 0.42);
      final low = ((cy / _h - 0.04) / 0.38).clamp(0.0, 1.0);
      final rx = r.range(150, 320) * _u;
      final ry = rx * r.range(0.035, 0.07);
      final a = r.range(0.28, 0.55) * (1 - 0.35 * low);
      for (final dx in [-w, 0.0, w]) {
        if (cx + dx + rx * 1.4 < 0 || cx + dx - rx * 1.4 > w) continue;
        for (final (oy, under, kk) in [
          (0.0, 0.1 + 0.3 * low, 1.0),
          (0.6, 0.7, 0.5),
        ]) {
          for (var j = 0; j < 2; j++) {
            final lx = (j == 0 ? -0.2 : 0.25) * rx;
            _lens(
              c,
              cx + dx + lx,
              cy + oy * ry,
              rx * (j == 0 ? 0.7 : 0.55),
              ry,
              fieldMap(under, 0, low * 0.3, a * kk),
              fieldMap(under + 0.15, 0, low * 0.3, 0),
            );
          }
        }
      }
    }
  }

  /// A soft lens: an oval of [inner] fading out to [outer] at its edge.
  void _lens(
    Canvas c,
    double cx,
    double cy,
    double rx,
    double ry,
    Color inner,
    Color outer,
  ) {
    c
      ..save()
      ..translate(cx, cy)
      ..scale(rx / ry, 1)
      ..drawCircle(
        Offset.zero,
        ry,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            ry,
            [inner, Color.lerp(inner, outer, 0.55)!, outer],
            const [0.0, 0.5, 1.0],
          ),
      )
      ..restore();
  }

  /// The far ranges: rank 0 the further, jagged crests standing up out of
  /// the haze.
  double _range(int rank, double x) {
    final base = _h * (rank == 0 ? 0.52 : 0.575);
    final tall = _h * (rank == 0 ? 0.15 : 0.085);
    final roll = _fn(x, 420, 11 + rank) * 0.5 + 0.5;
    return base -
        tall *
            (0.25 + 0.75 * roll) *
            (0.55 * _ridged(x, (rank == 0 ? 150 : 110) * _u, 13 + rank) +
                0.3 * _ridged(x, 48 * _u, 15 + rank) +
                0.15 * _ridged(x, 17 * _u, 17 + rank));
  }

  void _paintRanges(Canvas c, double w) {
    for (var rank = 0; rank < 2; rank++) {
      double ridge(double x) => _range(rank, x);
      final crest = _h * (rank == 0 ? 0.36 : 0.48);
      final (rc, rf) = rank == 0 ? (0.62, 0.86) : (0.36, 0.7);
      _fillRidge(
        c,
        w,
        ridge,
        Paint()
          ..shader = Gradient.linear(Offset(0, crest), Offset(0, _h * 0.6), [
            fieldMap(rc, 0, rc * 0.2),
            fieldMap(rf, 0, rf),
          ]),
        bottom: _h * 0.7,
        step: 2 * _u,
      );
      // Gullies down the nearer rank, in shade.
      if (rank == 1) {
        final r = FieldRandom(171);
        final path = Path();
        for (var x = 0.0; x < w; x += r.range(14, 34) * _u) {
          final top = ridge(x) + 2 * _u;
          final len = r.range(10, 26) * _u;
          final wd = r.range(1.4, 3) * _u;
          final lean = r.range(-0.4, 0.4) * len;
          path.addPolygon([
            Offset(x - wd, top),
            Offset(x + wd, top),
            Offset(x + lean, top + len),
          ], true);
        }
        c.drawPath(path, Paint()..color = fieldMap(0.55, 0.0, 0.9, 0.5));
      }
      _mistBand(
        c,
        w,
        _h * (rank == 0 ? 0.44 : 0.53),
        _h * (rank == 0 ? 0.56 : 0.63),
        rank == 0 ? 0.42 : 0.36,
      );
    }
  }

  void _paintRangeLight(Canvas c, double w) {
    _rimBands(c, w, (x) => _range(0, x), [(3.0, 0.12), (9.0, 0.05)]);
    _rimBands(c, w, (x) => _range(1, x), [(2.5, 0.16), (7.0, 0.07)]);
  }

  /// The cones on the far layer: the one that burns, and an old one gone
  /// cold further round.
  static const _cones = <_Cone>[
    _Cone(_coneX, _coneHw, _coneTop, _coneFoot, 1, burning: true),
    _Cone(1330, 190, 0.37, 0.615, 2, burning: false),
  ];

  /// How wide a cone's crater is, as a share of its half width.
  double _rim(_Cone k) => k.burning ? 0.085 : 0.11;

  /// How far down a cone's flank is at [a] across it (0 the middle, 1 its
  /// foot): flat across the crater, then steep under its lip, flaring out
  /// toward the foot.
  double _profile(_Cone k, double a) {
    final rim = _rim(k);
    final f = ((a - rim) / (1 - rim)).clamp(0.0, 1.0);
    return _h * (k.top + (k.foot - k.top) * (1 - math.pow(1 - f, 2.1)));
  }

  /// The cone's skyline at [x], for the cone [k] standing at [cx]; null
  /// off it.
  double? _coneY(_Cone k, double x, double cx) {
    final hw = k.hw * _u;
    final t = (x - cx) / hw;
    if (t.abs() >= 1.1) return null;
    final a = math.min(1.0, t.abs());
    var y = _profile(k, a);
    final rim = _rim(k);
    if (a < rim) {
      // The crater: a dip between its lips. The old cone's has long since
      // worn down to a rounded top.
      final f = a / rim;
      y += k.burning
          ? 4 * _u * (1 - f * f) * (t < 0 ? 0.8 : 1.0)
          : -3 * _u * (1 - f * f);
    }
    // Ragged along its flanks, more so lower down.
    y += _u * (1.4 + 4 * a) * fieldNoise(x / (9 * _u), 77 + k.seed);
    y += _u * 3 * a * fieldNoise(x / (31 * _u), 79 + k.seed);
    if (t.abs() > 1) y += (t.abs() - 1) * 600 * _u;
    return y;
  }

  /// A point on a cone's face: [q] across it (-1 its left skyline, 1 its
  /// right), [a] down it (0 the rim, 1 the foot). Seen from a little above,
  /// the face toward the viewer comes down lower than the skyline does.
  Offset _onCone(_Cone k, double cx, double q, double a) {
    final hw = k.hw * _u;
    final front = math.sqrt(math.max(0.0, 1 - q * q));
    return Offset(cx + q * a * hw, _profile(k, a) + 0.07 * a * hw * front);
  }

  /// The gullies running down a cone from its crater: (where across it,
  /// how deep).
  List<(double, double)> _gulliesOf(_Cone k) {
    final r = FieldRandom(k.seed * 101);
    final n = k.burning ? 15 : 11;
    return [
      for (var i = 0; i < n; i++)
        (-0.95 + 1.9 * (i + 0.5 + r.range(-0.3, 0.3)) / n, r.range(0.5, 1.0)),
    ];
  }

  /// A gully's course down the cone, wandering a little.
  Offset _gully(_Cone k, double cx, double q, double a, int seed) =>
      _onCone(k, cx, q + 0.03 * fieldNoise(a * 5, seed), a);

  Path _conePath(_Cone k, double cx) {
    final hw = k.hw * _u;
    final bottom = _h * (k.foot + 0.06);
    final path = Path()..moveTo(cx - hw * 1.1, bottom);
    for (var x = cx - hw * 1.1; x <= cx + hw * 1.1; x += 2 * _u) {
      path.lineTo(x, math.min(_coneY(k, x, cx) ?? bottom, bottom));
    }
    return path
      ..lineTo(cx + hw * 1.1, bottom)
      ..close();
  }

  /// A cone, for a cone-graded sheet: dark rock hazed toward its foot,
  /// turned from the light toward its sides; gullies fanning down from
  /// the crater, each with a lit ridge beside it; old flows cooled to dark
  /// tongues down its upper flanks.
  void _paintCone(Canvas c, _Cone k, double cx) {
    final hw = k.hw * _u;
    final path = _conePath(k, cx);
    final top = _h * k.top, bottom = _h * (k.foot + 0.06);
    final haze = k.burning ? 0.0 : 0.32;
    c.drawPath(
      path,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(haze + 0.04, 0.05, 0.3),
            fieldMap(haze + 0.16, 0.02, 0.42),
            fieldMap(haze + 0.45, 0, 0.5),
          ],
          const [0.0, 0.5, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(path)
      ..drawRect(
        Rect.fromLTRB(cx - hw * 1.1, top - 10 * _u, cx + hw * 1.1, bottom),
        Paint()
          ..shader = Gradient.linear(
            Offset(cx - hw, 0),
            Offset(cx + hw, 0),
            [
              fieldMap(haze, 0, 0.7, 0.5),
              fieldMap(haze, 0.08, 0.12, 0.3),
              fieldMap(haze, 0, 0.4, 0),
              fieldMap(haze, 0, 0.82, 0.55),
            ],
            const [0.0, 0.3, 0.55, 1.0],
          ),
      );
    final gullies = _gulliesOf(k);
    for (var i = 0; i < gullies.length; i++) {
      final (q, depth) = gullies[i];
      final front = math.pow(math.max(0.05, 1 - q * q), 0.35).toDouble();
      for (final (off, map) in [
        (0.0, fieldMap(haze, 0, 0.84, 0.75 * depth)),
        (-2.1, fieldMap(haze, 0.26, 0.1, 0.5 * depth)),
      ]) {
        final left = <Offset>[], right = <Offset>[];
        for (var j = 0; j <= 16; j++) {
          final a = _rim(k) + (1 - _rim(k)) * j / 16;
          final gw = (0.5 + 4.5 * a * depth) * _u * front;
          final p = _gully(k, cx, q, a, 900 + i + k.seed * 50);
          final at = p.translate(off * gw, 0);
          left.add(at.translate(-gw, 0));
          right.add(at.translate(gw, 0));
        }
        c.drawPath(
          Path()..addPolygon([...left, ...right.reversed], true),
          Paint()..color = map,
        );
      }
    }
    // Old flows, cooled to dark tongues down the upper flanks.
    final r = FieldRandom(931 + k.seed);
    for (var j = 0; j < (k.burning ? 7 : 4); j++) {
      final q = r.range(-0.7, 0.7);
      final len = r.range(0.25, 0.6);
      final left = <Offset>[], right = <Offset>[];
      for (var s = 0; s <= 10; s++) {
        final a = _rim(k) + len * s / 10;
        final p = _gully(k, cx, q, a, 950 + j);
        final gw = (2 + 6 * a) * _u * (1 - s / 10 * 0.7);
        left.add(p.translate(-gw, 0));
        right.add(p.translate(gw, 0));
      }
      c.drawPath(
        Path()..addPolygon([...left, ...right.reversed], true),
        Paint()..color = fieldMap(haze, 0.03, 0.66, 0.55),
      );
    }
    // Grains of rock and cinder over it all.
    final grains = GrainBatch(2);
    for (var i = 0; i < (hw * (bottom - top) / (_u * _u * 14)).round(); i++) {
      final x = cx + (r.next() * 2 - 1) * hw;
      final y = top + r.next() * (bottom - top);
      grains.add(r.next() < 0.6 ? 0 : 1, x, y);
    }
    grains
      ..draw(c, 0, 1.4 * _u, fieldMap(haze, 0, 0.88, 0.5))
      ..draw(c, 1, 1.2 * _u, fieldMap(haze, 0.3, 0.2, 0.4));
    c.restore();
  }

  /// The lava channels down the burning cone's face: (where across the
  /// crater lip it leaves, how it slants as it goes down, how far down it
  /// gets, its seed).
  static const _channels = <(double, double, double, int)>[
    (0.04, 0.32, 0.82, 1),
    (-0.05, -0.5, 0.46, 2),
    (0.09, 0.95, 0.52, 3),
  ];

  /// A channel's course from the crater lip down the face, wandering as it
  /// goes: points and widths.
  List<(Offset, double)> _channel(
    _Cone k,
    double cx,
    double q0,
    double slant,
    double reach,
    int seed,
  ) {
    const n = 24;
    return [
      for (var j = 0; j <= n; j++)
        () {
          final a = _rim(k) * 0.6 + (reach - _rim(k) * 0.6) * j / n;
          final q = q0 + slant * a + 0.05 * fieldNoise(a * 7, seed);
          final front = math.pow(math.max(0.05, 1 - q * q), 0.35).toDouble();
          return (_onCone(k, cx, q, a), (2.4 - 1.5 * j / n) * _u * front);
        }(),
    ];
  }

  /// The burning cone's fire, for a lava-graded sheet: the crater's glow
  /// over its lips, and the channels running down from it, each in a halo
  /// of its heat, branching now and then.
  void _paintConeLava(Canvas c, _Cone k, double cx) {
    if (!k.burning) return;
    final top = _h * k.top;
    final crater = Offset(cx, top + 1 * _u);
    c
      ..save()
      ..translate(crater.dx, crater.dy)
      ..scale(2.2, 1)
      ..drawCircle(
        Offset.zero,
        12 * _u,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            12 * _u,
            [_heat(1), _heat(0.7, a: 0.8), _heat(0.35, a: 0)],
            const [0.0, 0.3, 1.0],
          ),
      )
      ..restore();
    for (final (q0, slant, reach, seed) in _channels) {
      final pts = _channel(k, cx, q0, slant, reach, seed);
      for (final (grow, a) in [(3.6, 0.32), (1.0, 1.0)]) {
        final left = <Offset>[], right = <Offset>[];
        for (var j = 0; j < pts.length; j++) {
          final (p, wd) = pts[j];
          final ww = wd * grow;
          left.add(p.translate(-ww, 0));
          right.add(p.translate(ww, 0));
          if (grow == 1.0 && j > 2 && fieldHash(j, seed + 41) < 0.14) {
            final f = j / (pts.length - 1);
            final len = (6 + 10 * fieldHash(j, seed + 43)) * _u;
            final side = fieldHash(j, seed + 45) < 0.5 ? -1.0 : 1.0;
            c.drawPath(
              Path()..addPolygon([
                p.translate(-wd * 0.6, 0),
                p.translate(wd * 0.6, 0),
                p.translate(side * len * 0.45, len),
              ], true),
              Paint()..color = _heat(0.55 - 0.3 * f, a: 0.9),
            );
          }
        }
        final (p0, _) = pts.first;
        final (p1, _) = pts.last;
        c.drawPath(
          Path()..addPolygon([...left, ...right.reversed], true),
          Paint()
            ..shader = Gradient.linear(
              p0,
              p1,
              [
                _heat(grow > 1 ? 0.5 : 0.95, a: a),
                _heat(grow > 1 ? 0.28 : 0.5, a: a * 0.8),
                _heat(0.1, a: 0),
              ],
              const [0.0, 0.7, 1.0],
            ),
        );
      }
    }
  }

  /// The light on a cone: a thin band down from its skyline, and grains
  /// along the lit ridges of its upper gullies.
  void _paintConeLight(Canvas c, _Cone k, double cx) {
    final hw = k.hw * _u;
    for (final (depth, alpha) in const [(2.2, 0.22), (6.5, 0.08)]) {
      final band = Path();
      final pts = <Offset>[];
      for (var x = cx - hw; x <= cx + hw; x += 2 * _u) {
        pts.add(Offset(x, _coneY(k, x, cx)!));
      }
      band.addPolygon([
        ...pts,
        for (final p in pts.reversed) p.translate(0, depth * _u),
      ], true);
      c.drawPath(
        band,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: alpha),
      );
    }
    final sparks = GrainBatch(_sparkAlpha.length);
    final gullies = _gulliesOf(k);
    for (var i = 0; i < gullies.length; i++) {
      final (q, depth) = gullies[i];
      for (var j = 1; j <= 12; j++) {
        if (fieldHash(j, 820 + i) > 0.42 * depth) continue;
        final a = _rim(k) + (1 - _rim(k)) * j / 16;
        final gw = (0.5 + 4.5 * a * depth) * _u;
        final p = _gully(k, cx, q, a, 900 + i + k.seed * 50);
        sparks.add(j < 4 ? 2 : 1, p.dx - gw * 2.1, p.dy);
      }
    }
    _drawSparks(c, sparks, 1.2);
  }

  /// Cloud lying about the cone's foot and along the ranges: a bank of
  /// lumps lit on top and darker beneath, thickest round the cone, lit
  /// red from below near it.
  void _paintCloudBank(Canvas c, double w) {
    final r = FieldRandom(161);
    final lumps = <(double, double, double, double, double)>[];
    var x = -40 * _u;
    while (x < w + 40 * _u) {
      final d = _loopDelta(x, _coneX, far).abs() / (_coneHw * _u);
      final thick = d < 1.2 ? 1.0 - 0.4 * d / 1.2 : 0.45;
      final rx = r.range(26, 60) * _u * (0.7 + 0.5 * thick);
      final ry = rx * r.range(0.32, 0.5);
      final y = _h * (0.6 - 0.02 * thick) + r.range(-0.012, 0.012) * _h;
      final fire = d < 0.9 ? (1 - d / 0.9) * 0.7 : 0.0;
      lumps.add((x, y, rx, ry, fire));
      x += rx * r.range(0.7, 1.15);
    }
    // One body for the bank, its underside darker; then lit tops.
    final body = Path(), tops = Path();
    for (final (lx, ly, rx, ry, _) in lumps) {
      body.addOval(
        Rect.fromCenter(center: Offset(lx, ly), width: rx * 2, height: ry * 2),
      );
      tops.addOval(
        Rect.fromCenter(
          center: Offset(lx - rx * 0.12, ly - ry * 0.32),
          width: rx * 1.4,
          height: ry * 1.0,
        ),
      );
    }
    final top = _h * 0.54, bottom = _h * 0.66;
    body.addRect(Rect.fromLTRB(-50 * _u, _h * 0.605, w + 50 * _u, bottom));
    c
      ..drawPath(
        body,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, top),
            Offset(0, bottom),
            [
              fieldMap(0.2, 0, 0.1, 0.92),
              fieldMap(0.65, 0, 0.3, 0.95),
              fieldMap(0.85, 0, 0.35, 0.95),
            ],
            const [0.0, 0.5, 1.0],
          ),
      )
      ..drawPath(tops, Paint()..color = fieldMap(0.0, 0.04, 0.05, 0.6));
    // Lit from beneath where it lies about the cone.
    for (final (lx, ly, rx, ry, fire) in lumps) {
      if (fire <= 0) continue;
      c.drawOval(
        Rect.fromCenter(
          center: Offset(lx, ly + ry * 0.35),
          width: rx * 1.7,
          height: ry * 1.1,
        ),
        Paint()..color = fieldMap(0.5, 0, 1, 0.5 * fire),
      );
    }
  }

  // ── The cone's moods ─────────────────────────────────────────────────────

  /// The stages the cone is found in from one visit to the next (see
  /// [SceneDefinition.stages]): quiet, smoking, erupting.
  static const still = 0, smoking = 1, erupting = 2;

  bool get _erupting => stage == erupting;

  /// How the eruption surges: 0 between surges, rising fast to the height
  /// of one and dying away, every few seconds, each its own strength.
  /// Always 0 unless erupting.
  double _surgeAt(double t) {
    if (!_erupting) return 0;
    const period = 4.6;
    final k = (t / period).floor();
    final p = t / period - k;
    final peak = 0.55 + 0.45 * fieldHash(k, 1931);
    return peak * (p < 0.07 ? p / 0.07 : math.exp(-(p - 0.07) * 5.5));
  }

  // ── The plume ────────────────────────────────────────────────────────────

  /// Where the plume's column runs at [f] of its rise (0 the crater, 1 its
  /// top, above the screen): its middle and how wide it has grown. Erupting
  /// it climbs higher and straighter, and far wider.
  (Offset, double) _plumeAt(double cx, double f) {
    final top = _h * _coneTop;
    final e = _erupting;
    // Climbing steadily, so a good part of the column is in view over the
    // crater, widening fast as it leaves it.
    // Erupting, the column stands a little off the crater: the fountain
    // and the blaze under it show beneath.
    final rise = _h * (e ? 0.95 : 0.75) * f + (e ? 14 * _u : 0);
    final lean = _h * (e ? 0.04 * f + 0.25 * f * f : 0.08 * f + 0.5 * f * f);
    final rad = (e ? 18 + 170 * math.sqrt(f) : 9 + 88 * math.sqrt(f)) * _u;
    return (Offset(cx + lean, top - rise), rad);
  }

  /// The billows the plume is drawn with, side by side in one image: three
  /// lumps of smoke, each lit on top and shaded under, in grey so the
  /// hour's colour can be laid over them.
  Image? _billows;
  static const _billowSize = 320.0;

  Image _makeBillows() {
    const s = _billowSize;
    final rec = PictureRecorder();
    final c = Canvas(rec);
    for (var v = 0; v < 3; v++) {
      final r = FieldRandom(2201 + v);
      final o = Offset(s * (v + 0.5), s * 0.52);
      final core = s * 0.27;
      final lumps = <(Offset, double)>[(o, core)];
      for (var k = 0; k < 12; k++) {
        final a = -math.pi * r.range(0.0, 1.0) - (k.isEven ? 0 : math.pi);
        final d = core * r.range(0.45, 0.8);
        lumps.add((
          o + Offset(math.cos(a) * d, math.sin(a) * d * 0.8),
          core * r.range(0.34, 0.56),
        ));
      }
      final body = Path(), tops = Path(), under = Path();
      for (final (p, rad) in lumps) {
        body.addOval(Rect.fromCircle(center: p, radius: rad));
        tops.addOval(
          Rect.fromCircle(
            center: p.translate(rad * 0.1, -rad * 0.34),
            radius: rad * 0.56,
          ),
        );
        if (p.dy > o.dy) {
          under.addOval(
            Rect.fromCircle(
              center: p.translate(0, rad * 0.3),
              radius: rad * 0.7,
            ),
          );
        }
      }
      c
        ..drawPath(
          body,
          Paint()
            ..shader = Gradient.linear(
              o.translate(0, -core * 1.5),
              o.translate(0, core * 1.4),
              [const Color(0xFFADADAD), const Color(0xFF5E5E5E)],
            ),
        )
        ..save()
        ..clipPath(body)
        ..drawPath(
          under,
          Paint()..color = const Color(0xFF000000).withValues(alpha: 0.18),
        )
        ..drawPath(
          tops,
          Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.2),
        )
        ..restore();
    }
    final pic = rec.endRecording();
    final img = pic.toImageSync((s * 3).round(), s.round());
    pic.dispose();
    return img;
  }

  _Plume _makePlume() {
    final r = FieldRandom(191);
    const n = 650;
    final phase = Float32List(n),
        life = Float32List(n),
        sx = Float32List(n),
        sy = Float32List(n),
        swirl = Float32List(n);
    for (var i = 0; i < n; i++) {
      phase[i] = r.next();
      life[i] = r.range(11, 16);
      // Off the column's middle, bunched toward it.
      final a = r.next() * math.pi * 2;
      final d = math.sqrt(r.next());
      sx[i] = math.cos(a) * d;
      sy[i] = math.sin(a) * d;
      swirl[i] = r.range(0, math.pi * 2);
    }
    return _Plume(phase, life, sx, sy, swirl);
  }

  final GrainBatch _plumeBatch = GrainBatch(3);

  static const _maxBillows = 120;
  final Float32List _billowXf = Float32List(_maxBillows * 4);
  final Float32List _billowRect = Float32List(_maxBillows * 4);
  final Int32List _billowColor = Int32List(_maxBillows);
  final List<(double, int)> _billowOrder = [];
  final Paint _billowPaint = Paint()..filterQuality = FilterQuality.medium;

  /// The plume, live. Smoking, billows climb out of the crater, swelling
  /// and turning as they rise, leaning off on the wind, lit red beneath
  /// as they leave the fire, ash-dark above; specks of ash and cinder ride
  /// up through them. Erupting, it is a column twice the size, darker, its
  /// billows faster and heaving with each surge. Still, there is only a
  /// thread of vapour off the crater.
  void _paintPlume(Canvas canvas, FieldView view) {
    final p = _plume;
    if (p == null) return;
    if (stage == still) {
      _paintWisp(canvas, view);
      return;
    }
    final t = view.time;
    final reach = _h * 0.9;
    final l = _light;
    final e = _erupting;
    final surge = _surgeAt(t);
    final ash = _sil(e ? _eruptionAsh : _plumeAsh, l);
    // Over the grey of the billows: a little brighter than the ash itself.
    final base = Color.from(
      alpha: 1,
      red: math.min(1.0, ash.r * 1.3),
      green: math.min(1.0, ash.g * 1.3),
      blue: math.min(1.0, ash.b * 1.3),
    );
    final fire = Color.lerp(_glowWarm, _lavaHot, 0.2 + 0.3 * surge)!;
    // Smoke lit by the fire under it goes a deep red, not the fire's own
    // orange.
    final underlit = Color.lerp(_glowDeep, _glowWarm, 0.3 + 0.4 * surge)!;
    final haze = Color.lerp(l.skyAt(0.3), l.cloudTop, 0.5)!;
    final billows = _billows;
    for (final shift in _shiftsFor(far, view, reach)) {
      final cx = _coneX + shift;
      if (cx + reach < view.left || cx - _h * 0.4 > view.right) continue;
      if (billows != null) {
        final n = e ? 120 : 80;
        final life = e ? 9.0 : 14.0;
        _billowOrder.clear();
        for (var i = 0; i < n; i++) {
          final f = (t / life + (i + 0.6 * fieldHash(i, 2211)) / n) % 1.0;
          _billowOrder.add((f, i));
        }
        // The highest first, so the newest, nearest the fire, lie over.
        _billowOrder.sort((a, b) => b.$1.compareTo(a.$1));
        var k = 0;
        for (final (f, i) in _billowOrder) {
          final (c, rad) = _plumeAt(cx, f);
          final a0 = fieldHash(i, 2213) * math.pi * 2;
          final d = math.sqrt(fieldHash(i, 2217));
          // Heaving with the surge it rose in.
          final heave =
              1 + 0.25 * _surgeAt(t - f * life) + 0.06 * math.sin(t * 0.7 + i);
          final r = rad * (0.62 + 0.36 * fieldHash(i, 2219)) * heave;
          final x = c.dx + math.cos(a0) * d * rad * 0.7;
          final y = c.dy + math.sin(a0) * d * rad * 0.42;
          if (x + r < view.left || x - r > view.right || y - r > view.bottom) {
            continue;
          }
          final rot =
              fieldHash(i, 2221) * 6.28 + t * (fieldHash(i, 2223) - 0.5) * 0.12;
          final scale = r / (_billowSize * 0.4);
          final sc = scale * math.cos(rot), ss = scale * math.sin(rot);
          const ax = _billowSize / 2, ay = _billowSize * 0.52;
          _billowXf
            ..[k * 4] = sc
            ..[k * 4 + 1] = ss
            ..[k * 4 + 2] = x - sc * ax + ss * ay
            ..[k * 4 + 3] = y - ss * ax - sc * ay;
          final v = i % 3;
          _billowRect
            ..[k * 4] = v * _billowSize
            ..[k * 4 + 1] = 0
            ..[k * 4 + 2] = (v + 1) * _billowSize
            ..[k * 4 + 3] = _billowSize;
          final lit =
              math.exp(-f * (e ? 6 : 10)) *
              ((e ? 0.5 : 0.3) + 0.6 * _night + 0.45 * surge);
          var col = Color.lerp(
            base,
            const Color(0xFF000000),
            0.25 * fieldHash(i, 2227),
          )!;
          col = Color.lerp(col, underlit, lit.clamp(0.0, 0.85))!;
          col = Color.lerp(col, haze, (f * 0.3).clamp(0.0, 0.25))!;
          final alpha =
              math.min(1.0, f / 0.04) * math.min(1.0, (1 - f) / 0.22) * 0.97;
          _billowColor[k] = col.withValues(alpha: alpha).toARGB32();
          k++;
          if (k >= _maxBillows) break;
        }
        if (k > 0) {
          canvas.drawRawAtlas(
            billows,
            Float32List.sublistView(_billowXf, 0, k * 4),
            Float32List.sublistView(_billowRect, 0, k * 4),
            Int32List.sublistView(_billowColor, 0, k),
            BlendMode.modulate,
            null,
            _billowPaint,
          );
        }
      }
      // Specks of ash and cinder riding up through it.
      _plumeBatch.clear();
      var any = false;
      for (var i = 0; i < p.n; i++) {
        final f = (t / p.life[i] * (e ? 1.6 : 1) + p.phase[i]) % 1.0;
        final keep = math.min(1.0, f * 30) * math.min(1.0, (1 - f) * 3.2);
        if (fieldHash(i, 197) > keep) continue;
        final (c, rad) = _plumeAt(cx, f);
        final churn = math.sin(t * 0.55 + p.swirl[i] + f * 6);
        final x = c.dx + p.sx[i] * rad * 1.05 + churn * rad * 0.18;
        final y =
            c.dy +
            p.sy[i] * rad * 0.7 +
            math.cos(t * 0.4 + p.swirl[i]) * rad * 0.08;
        if (x < view.left - 4 || x > view.right + 4 || y > view.bottom) {
          continue;
        }
        // Cinders glow only just out of the crater; above, ash.
        final b = f < (e ? 0.06 : 0.025) + 0.015 * (1 - p.sy[i])
            ? 2
            : (p.sy[i] < -0.3 ? 0 : 1);
        _plumeBatch.add(b, x, y);
        any = true;
      }
      if (any) {
        final lit = Color.lerp(ash, l.rim, 0.3 * l.rimStrength)!;
        final dark = Color.lerp(ash, const Color(0xFF000000), 0.55)!;
        _plumeBatch
          ..draw(canvas, 1, 1.7 * _u, dark.withValues(alpha: 0.6))
          ..draw(canvas, 0, 1.6 * _u, lit.withValues(alpha: 0.55))
          ..draw(canvas, 2, 2.0 * _u, fire.withValues(alpha: 0.85));
      }
    }
  }

  /// The quiet cone: a thread of vapour off its crater, thin and faint.
  void _paintWisp(Canvas canvas, FieldView view) {
    final t = view.time;
    _plumeBatch.clear();
    var any = false;
    final top = _h * _coneTop;
    for (final shift in _shiftsFor(far, view, 60 * _u)) {
      final cx = _coneX + shift;
      if (cx + 60 * _u < view.left || cx - 60 * _u > view.right) continue;
      for (var i = 0; i < 90; i++) {
        final life = 5 + 3 * fieldHash(i, 2231);
        final f = (t / life + fieldHash(i, 2233)) % 1.0;
        final keep = math.min(1.0, f * 12) * (1 - f);
        if (fieldHash(i, 2235) > keep) continue;
        final rise = _h * 0.13 * f;
        final x =
            cx +
            (fieldHash(i, 2237) - 0.5) * 8 * _u +
            18 * _u * f * f +
            3 * _u * math.sin(t * 0.6 + f * 7);
        _plumeBatch.add(f < 0.4 ? 0 : 1, x, top - rise);
        any = true;
      }
    }
    if (!any) return;
    final l = _light;
    final pale = Color.lerp(_sil(_plumeAsh, l), l.skyAt(0.3), 0.45)!;
    _plumeBatch
      ..draw(canvas, 0, 2.2 * _u, pale.withValues(alpha: 0.42))
      ..draw(canvas, 1, 2.6 * _u, pale.withValues(alpha: 0.24));
  }

  /// The channels down the burning cone's face, as their lava runs:
  /// laid out once, at the cone's own place.
  List<List<(Offset, double)>> _channelPts = const [];

  /// Lava running down the cone's channels: bright gobbets sliding down
  /// each, slowly while it smokes, in a rush while it erupts.
  void _paintFlows(Canvas canvas, FieldView view) {
    if (stage == still || _channelPts.isEmpty) return;
    final t = view.time;
    final e = _erupting;
    _sparkBatch.clear();
    var any = false;
    for (final shift in _shiftsFor(far, view, _coneHw * _u)) {
      if (_coneX + shift + _coneHw * _u < view.left ||
          _coneX + shift - _coneHw * _u > view.right) {
        continue;
      }
      for (var c = 0; c < _channelPts.length; c++) {
        final pts = _channelPts[c];
        final n = e ? 34 : 12;
        for (var i = 0; i < n; i++) {
          final speed =
              (e ? 0.16 : 0.05) * (0.7 + 0.6 * fieldHash(i, 2241 + c));
          final f = (t * speed + fieldHash(i, 2243 + c)) % 1.0;
          final at = f * (pts.length - 1);
          final j = at.floor();
          final (p0, w0) = pts[j];
          final (p1, _) = pts[math.min(j + 1, pts.length - 1)];
          final p = Offset.lerp(p0, p1, at - j)!;
          final across = (fieldHash(i, 2245 + c) - 0.5) * w0 * 1.2;
          _sparkBatch.add(f < 0.5 ? 0 : 1, p.dx + shift + across, p.dy);
          any = true;
        }
      }
    }
    if (any) _drawSparkCores(canvas, e ? 0.9 : 0.7);
  }

  /// The lava fountain of an eruption: rock flung up out of the crater in a
  /// jet that heaves with each surge, falling back down over the lips,
  /// white-hot as it leaves, reddening as it falls; the crater blazing
  /// under it.
  void _paintFountain(Canvas canvas, FieldView view) {
    if (!_erupting) return;
    final t = view.time;
    final k = _cones.first;
    final top = _h * _coneTop;
    for (final shift in _shiftsFor(far, view, _coneHw * _u)) {
      final cx = _coneX + shift;
      if (cx + _coneHw * _u < view.left || cx - _coneHw * _u > view.right) {
        continue;
      }
      final surge = _surgeAt(t);
      final glow = Offset(cx, top - 4 * _u);
      final gr = (26 + 30 * surge) * _u;
      canvas.drawCircle(
        glow,
        gr,
        Paint()
          ..shader = Gradient.radial(
            glow,
            gr,
            [
              _lavaHot.withValues(alpha: 0.55 + 0.35 * surge),
              _lavaOrange.withValues(alpha: 0.25 + 0.2 * surge),
              _glowDeep.withValues(alpha: 0),
            ],
            const [0.0, 0.35, 1.0],
          ),
      );
      // Rock it throws lands on the cone's upper flanks, steep under the
      // lips: a plain slope will do to tell where.
      final rim = _rim(k) * k.hw * _u;
      for (var i = 0; i < 520; i++) {
        final life = 1.4 + 1.1 * fieldHash(i, 1901);
        final age = (t + fieldHash(i, 1903) * life) % life;
        // How hard the surge it left in was throwing.
        final s = 0.8 + 0.6 * _surgeAt(t - age);
        // Most of it a narrow jet, flying highest; the rest spray thrown
        // wide and lower, falling back onto the flanks.
        final spread = fieldHash(i, 1909) - 0.5;
        final jet = fieldHash(i, 1911) < 0.7;
        final vy = jet
            ? (80 + 70 * fieldHash(i, 1907)) * _u * s
            : (45 + 45 * fieldHash(i, 1907)) * _u * s;
        final vx = jet
            ? spread * spread.abs() * 2 * (30 + 40 * s) * _u
            : spread * (90 + 50 * s) * _u;
        const g = 120.0;
        final x = cx + vx * age;
        final y = top + 2 * _u - (vy * age - 0.5 * g * _u * age * age);
        final ground = top + 4 * _u + math.max(0.0, (x - cx).abs() - rim) * 1.2;
        if (y > ground) continue;
        final f = age / life;
        _sparkBatch.add(f < 0.3 ? 0 : (f < 0.65 ? 1 : 2), x, y);
      }
    }
  }

  /// Bombs thrown out of the crater: bright grains arcing up and falling
  /// back onto the cone — a few now and then while it smokes, a storm of
  /// them while it erupts.
  void _paintBombs(Canvas canvas, FieldView view) {
    if (stage == still) return;
    final t = view.time;
    final e = _erupting;
    for (final shift in _shiftsFor(far, view, _coneHw * _u)) {
      final cx = _coneX + shift;
      if (cx + _coneHw * _u < view.left || cx - _coneHw * _u > view.right) {
        continue;
      }
      final top = _h * _coneTop;
      for (var i = 0; i < (e ? 26 : 10); i++) {
        final period = e ? 2.6 : 4.2;
        final age = (t + fieldHash(i, 701) * period) % period;
        // Erupting, flung out to the sides, clear of the column.
        final side = fieldHash(i, 703) - 0.5;
        final vx = e
            ? (side.sign * (45 + 70 * side.abs() * 2)) * _u
            : side * 70 * _u;
        final vy = (40 + 50 * fieldHash(i, 707)) * _u * (e ? 1.7 : 1);
        const g = 70.0;
        final x = cx + vx * age;
        final y = top - (vy * age - 0.5 * g * _u * age * age);
        final ground = _coneY(_cones.first, x, cx);
        if (ground == null || y > ground) continue;
        final level = age < 0.7 ? 0 : (age < 1.6 ? 1 : 2);
        _sparkBatch.add(level, x, y);
      }
    }
  }

  /// Ash falling out of an eruption's cloud over everything: grey flakes
  /// drifting down on the wind, the nearer bigger.
  void _paintAshFall(Canvas canvas, FieldView view) {
    if (!_erupting) return;
    final t = view.time;
    final period = _period(near) > 0 ? _period(near) : _nearWidth;
    if (period <= 0) return;
    _ashBatch.clear();
    final span = view.bottom - view.top + 40 * _u;
    for (var i = 0; i < 520; i++) {
      final fall = (10 + 16 * fieldHash(i, 2251)) * _u;
      final y =
          view.top - 20 * _u + (fieldHash(i, 2253) * span + t * fall) % span;
      var x =
          fieldHash(i, 2255) * period +
          t * 9 * _u +
          6 * _u * math.sin(t * 0.8 + i);
      x -= period * ((x - view.left) / period).floorToDouble();
      if (x > view.right) continue;
      _ashBatch.add(fieldHash(i, 2257) < 0.7 ? 0 : 1, x, y);
    }
    final l = _light;
    final grey = Color.lerp(_sil(_albedo[_gAshTop]!, l), l.mote, 0.15)!;
    _ashBatch
      ..draw(canvas, 0, 1.5 * _u, grey.withValues(alpha: 0.55))
      ..draw(canvas, 1, 2.3 * _u, grey.withValues(alpha: 0.4));
  }

  // ── Mid: the hills and the lake ──────────────────────────────────────────

  double _mn(double x, double wave, int seed) =>
      fieldLoopNoise(x, wave, seed, _period(mid));

  /// The red hills, rank 0 the further: rounded humps running down to the
  /// lava lake.
  double _hill(int rank, double x) {
    if (rank == 0) {
      return _h * 0.6 -
          _h * 0.06 * (0.5 + 0.5 * _mn(x, 380, 41)) -
          _h * 0.07 * math.pow(0.5 + 0.5 * _mn(x, 140 * _u, 43), 1.3) -
          1.5 * _u * _mn(x, 14 * _u, 45);
    }
    return _h * 0.655 -
        _h * 0.035 * (0.5 + 0.5 * _mn(x, 300, 51)) -
        _h * 0.065 * math.pow(0.5 + 0.5 * _mn(x, 95 * _u, 53), 1.6) -
        1.2 * _u * _mn(x, 11 * _u, 55);
  }

  void _paintHills(Canvas c, double w) {
    for (var rank = 0; rank < 2; rank++) {
      double ridge(double x) => _hill(rank, x);
      final crest = _h * (rank == 0 ? 0.47 : 0.55);
      final haze = rank == 0 ? 0.42 : 0.14;
      final foot = _h * 0.67;
      _fillRidge(
        c,
        w,
        ridge,
        Paint()
          ..shader = Gradient.linear(Offset(0, crest), Offset(0, foot), [
            fieldMap(haze, 0.04, 0.24),
            fieldMap(haze * 0.7, 0, 0.5),
          ]),
        bottom: _h * 0.7,
        step: 2 * _u,
      );
      // Each slope shaded by the way it faces: lit where it turns up to
      // the light (from the upper left), in shade where it turns away —
      // most at the crest, less down the slope. One strip of triangles,
      // so it is smooth all along.
      final positions = <Offset>[], tints = <Color>[];
      Offset? lastTop, lastLow;
      Color? lastColor;
      for (var x = -6 * _u; x < w + 8 * _u; x += 2 * _u) {
        final y = ridge(x);
        final slope = (ridge(x + 4 * _u) - ridge(x - 4 * _u)) / (8 * _u);
        final lit = (-slope * 2.4).clamp(0.0, 1.0);
        final shade = (slope * 2.4).clamp(0.0, 1.0);
        final m = lit > shade
            ? fieldMap(haze, 0.2 * lit, 0.12, 0.85 * lit)
            : fieldMap(haze, 0, 0.62, 0.7 * shade);
        final top = Offset(x, y + 0.4 * _u);
        final low = Offset(x, y + (foot - y) * 0.75);
        if (lastTop != null) {
          final clear = lastColor!.withValues(alpha: 0);
          positions.addAll([lastTop, top, lastLow!, lastLow, top, low]);
          tints.addAll([lastColor, m, clear, clear, m, m.withValues(alpha: 0)]);
        }
        lastTop = top;
        lastLow = low;
        lastColor = m;
      }
      c.drawVertices(
        Vertices(VertexMode.triangles, positions, colors: tints),
        BlendMode.srcOver,
        Paint(),
      );
      // Broken rock over them.
      final r = FieldRandom(611 + rank);
      final grains = GrainBatch(2);
      for (var i = 0; i < (w * _h * 0.1 / (_u * _u * 12)).round(); i++) {
        final x = r.next() * w;
        final y = ridge(x) + r.next() * (foot - ridge(x));
        grains.add(r.next() < 0.6 ? 0 : 1, x, y);
      }
      grains
        ..draw(c, 0, 1.3 * _u, fieldMap(haze, 0, 0.85, 0.45))
        ..draw(c, 1, 1.2 * _u, fieldMap(haze, 0.25, 0.2, 0.35));
      if (rank == 0) _mistBand(c, w, _h * 0.53, _h * 0.63, 0.3);
    }
  }

  void _paintHillLight(Canvas c, double w) {
    _rimBands(c, w, (x) => _hill(0, x), [(2.5, 0.14), (8.0, 0.06)]);
    _rimBands(c, w, (x) => _hill(1, x), [(2.0, 0.2), (6.0, 0.08)]);
  }

  /// The lake's light on the hills' lower slopes, for a glow sheet.
  void _paintHillGlow(Canvas c, double w) {
    // Brightest along the shore, fading out up the slopes and away over
    // the lava, so it never ends at an edge.
    final top = _h * 0.58, shore = _h * _midLavaTop + 4 * _u;
    final bottom = shore + _h * 0.03;
    c.drawRect(
      Rect.fromLTRB(-10 * _u, top, w + 10 * _u, bottom),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          [
            fieldMap(0, 0, 0, 0),
            fieldMap(0.4, 0, 0, 0.26),
            fieldMap(1, 0, 0, 0.62),
            fieldMap(0.6, 0, 0, 0),
          ],
          [0.0, 0.55, (shore - top) / (bottom - top), 1.0],
        ),
    );
  }

  // ── The lava ─────────────────────────────────────────────────────────────

  /// Where [layer]'s lava begins at [x]: a shore that wanders a little,
  /// never above the top of its band.
  double _shore(SceneLayer layer, double x) {
    final (top, _) = _lavaBand(layer);
    final amp = (layer == mid ? 5.0 : 4.0) * _u;
    final seed = layer == mid ? 731 : 771;
    final p = _period(layer);
    return top +
        amp * (0.5 + 0.5 * fieldLoopNoise(x, 70 * _u, seed, p)) +
        amp * 0.4 * (0.5 + 0.5 * fieldLoopNoise(x, 23 * _u, seed + 2, p));
  }

  /// The lava's top on [layer], and how far in front of it the lava runs.
  (double, double) _lavaBand(SceneLayer layer) => layer == mid
      ? (_h * _midLavaTop, _h * 0.88)
      : (_h * _nearLavaTop, _h + 8 * _u);

  /// Rivers of lava running toward the viewer between the near shelves:
  /// (where it comes in at the far edge, as a share of the loop; how far it
  /// slants for each unit nearer; how far it wanders, and over how long a
  /// stretch; its width).
  static const _rivers = <(double, double, double, double, double)>[
    (0.163, 0.5, 9, 70, 11),
    (0.31, -0.35, 12, 90, 13),
    (0.495, 0.22, 10, 80, 15),
    (0.66, 0.45, 9, 64, 11),
    (0.838, -0.4, 11, 84, 12),
    (0.985, 0.3, 9, 70, 10),
  ];

  /// The lake's rivers, coming down from the hills between the back
  /// shelves (as the near ones are).
  static const _midRivers = <(double, double, double, double, double)>[
    (0.27, 0.3, 6, 50, 7),
    (0.43, -0.25, 7, 60, 6),
    (0.69, 0.35, 6, 44, 7),
    (0.97, -0.3, 6, 54, 6),
  ];

  /// Pools where the crust has broken: (x as a share of the loop, y as a
  /// share of the height, half width, half depth at the reference height).
  static const _nearPools = <(double, double, double, double)>[
    (0.085, 0.935, 26, 5),
    (0.405, 0.95, 34, 6),
    (0.585, 0.905, 30, 5),
    (0.765, 0.94, 30, 5.5),
    (0.955, 0.905, 22, 4),
  ];
  static const _midPools = <(double, double, double, double)>[
    (0.33, 0.705, 18, 3),
    (0.62, 0.695, 14, 2.6),
    (0.91, 0.71, 20, 3),
  ];

  /// Where a river on [layer] runs at [y]: its middle and half its width.
  (double, double) _riverAt(
    (double, double, double, double, double) river,
    SceneLayer layer,
    double w,
    double y,
  ) {
    final (fx, slant, amp, wave, wd) = river;
    final (top, _) = _lavaBand(layer);
    final along = y - top;
    final depth = ((y - _h * 0.575) / (_h * 0.425)).clamp(0.2, 1.2);
    return (
      fx * w +
          slant * along +
          amp * _u * math.sin(along / (wave * _u) * math.pi * 2 + fx * 40),
      wd * _u * (0.35 + 1.1 * depth),
    );
  }

  /// A moat's depth out from the foot of what stands in it, along its
  /// length ([t] -1 to 1): deepest in the middle, closing at the ends.
  double _moatDepth(double t, SceneLayer layer, [int seed = 0]) =>
      (layer == mid ? 4.5 : 7.5) *
      _u *
      (1 - math.pow(t.abs(), 6)) *
      (0.55 + 0.45 * fieldNoise(t * 4.5 + seed * 0.37, 883 + seed).abs() * 2)
          .clamp(0.25, 1.4);

  /// How open and how warm the lava is at [x], [y] on [layer]: open 1 is
  /// molten rock with no crust over it; warm, how much of the heat shows
  /// round about. The lava is crusted black but for its rivers, a pool
  /// here and there, and a moat round the foot of whatever stands in it.
  (double, double) _lavaAt(SceneLayer layer, double x, double y) {
    final period = _period(layer);
    final w = _widths[layer] ?? period;
    var open = 0.0, warm = 0.0;
    double dx(double from) =>
        period > 0 ? _loopDelta(x, from, layer) : x - from;
    void spot(double d) {
      if (d < 1) open = math.max(open, math.min(1.0, (1 - d) * 2.2));
      if (d < 2.8) warm = math.max(warm, 1 - d / 2.8);
    }

    for (final river in layer == near ? _rivers : _midRivers) {
      final (cx, half) = _riverAt(river, layer, w, y);
      spot(dx(cx).abs() / half);
    }
    for (final (fx, fy, rx, ry) in layer == near ? _nearPools : _midPools) {
      final ex = dx(fx * w) / (rx * _u), ey = (y - fy * _h) / (ry * _u);
      spot(math.sqrt(ex * ex + ey * ey));
    }
    void foot(double d, double t, double below) {
      if (t.abs() > 1.15) return;
      final depth = _moatDepth(t.clamp(-1.0, 1.0), layer);
      if (depth <= 0) return;
      final b = below / depth;
      if (b > -0.2 && b < 1) open = math.max(open, 1 - b.clamp(0.0, 1.0));
      if (b > -0.4 && b < 3.5) {
        warm = math.max(warm, 0.85 * (1 - b.clamp(0.0, 3.5) / 3.5));
      }
    }

    for (final s in _shelves[layer] ?? const <_Shelf>[]) {
      final d = dx(s.cx);
      foot(d, d / (s.hw + s.flare), y - _sLava(s));
    }
    for (final sp in _spires[layer] ?? const <_Spire>[]) {
      final d = dx(sp.x);
      foot(d, d / (sp.hw * 1.2), y - sp.base);
    }
    final v = _vent;
    if (layer == near && v != null) {
      final d = dx(v.x);
      foot(d, d / (v.hw * 1.2), y - v.base);
    }
    return (open.clamp(0.0, 1.0), warm.clamp(0.0, 1.0));
  }

  /// The open lava on [layer] as bands: each a run of cross-sections from
  /// one edge to the other, and how hot it is at the first edge, across
  /// its middle, and at the far edge. Rivers run toward the viewer and are
  /// hottest down their middles; a moat is hottest against the rock.
  List<_Band> _makeBands(SceneLayer layer, double w) {
    final out = <_Band>[];
    final (top, bottom) = _lavaBand(layer);
    for (final river in layer == near ? _rivers : _midRivers) {
      final a = <Offset>[], b = <Offset>[];
      for (var y = top - 2 * _u; y <= bottom + 4 * _u; y += 3 * _u) {
        final (cx, half) = _riverAt(river, layer, w, y);
        a.add(Offset(cx - half, y));
        b.add(Offset(cx + half, y));
      }
      out.add(_Band(a, b, (0.42, 0.85, 0.42), river: true));
    }
    for (final (fx, fy, rx, ry) in layer == near ? _nearPools : _midPools) {
      final cx = fx * w, cy = fy * _h;
      final a = <Offset>[], b = <Offset>[];
      for (var k = 0; k <= 20; k++) {
        final t = -1 + 2 * k / 20;
        final half = ry * _u * math.sqrt(1 - t * t);
        final wob = 1 + 0.25 * fieldNoise(k * 0.7, (fx * 1000).round());
        a.add(Offset(cx + t * rx * _u * wob, cy - half * wob));
        b.add(Offset(cx + t * rx * _u * wob, cy + half * wob * 0.8));
      }
      out.add(_Band(a, b, (0.38, 0.72, 0.38)));
    }
    var seed = 0;
    void moat(double x0, double x1, double Function(double) edge) {
      final a = <Offset>[], b = <Offset>[];
      seed++;
      for (var x = x0; x <= x1 + 0.01; x += 2 * _u) {
        final t = (x - (x0 + x1) / 2) / ((x1 - x0) / 2);
        final y = edge(x);
        a.add(Offset(x, y - 1.5 * _u));
        b.add(Offset(x, y + _moatDepth(t, layer, seed)));
      }
      out.add(_Band(a, b, (0.9, 0.5, 0.12)));
    }

    for (final s in _shelves[layer] ?? const <_Shelf>[]) {
      moat(
        s.cx - s.hw - s.flare,
        s.cx + s.hw + s.flare,
        (x) => _lavaEdge(s, x),
      );
    }
    for (final sp in _spires[layer] ?? const <_Spire>[]) {
      moat(sp.x - sp.hw * 1.15, sp.x + sp.hw * 1.15, (_) => sp.base + 1 * _u);
      final m = out.removeLast();
      // A spire's is narrower than a shelf's: it is a smaller thing.
      out.add(
        _Band(m.a, [
          for (var i = 0; i < m.b.length; i++)
            Offset.lerp(m.a[i], m.b[i], 0.55)!,
        ], m.heat),
      );
    }
    final v = _vent;
    if (layer == near && v != null) {
      moat(v.x - v.hw * 1.2, v.x + v.hw * 1.2, (_) => v.base + 1.5 * _u);
    }
    return out;
  }

  /// The crust over [layer]'s lava: one polygon per plate — (outline,
  /// middle x, middle y, size, id, how open the lava is there, how warm) —
  /// cracked as the Swamp's dried floor is: sites thinner toward the far
  /// side, each plate the lava nearer its site than any other with depth
  /// stretched so the plates lie flat, drawn in from the cracks, the
  /// cracks wider where the lava is warm. Repeats round the loop.
  List<_Plate> _crustCells(SceneLayer layer, double w) {
    final (top0, bottom) = _lavaBand(layer);
    final top = top0 + (layer == mid ? 1 : 3) * _u;
    final horizon = _h * 0.575;
    final k = layer == mid ? 0.13 : 0.11;
    const stretch = 2.6;
    final seed = layer == mid ? 810 : 850;
    final sites = <Offset>[];
    final sizes = <double>[];
    var y = top + 1 * _u;
    var row = 0;
    while (y < bottom + 6 * _u) {
      final rh = k * (y - horizon);
      final pw = rh * stretch * (0.9 + 0.5 * fieldHash(row, seed));
      final n = math.max(3, (w / pw).round());
      for (var i = 0; i < n; i++) {
        final jx = fieldHash(i * 2, seed + row * 7) - 0.5;
        final jy = fieldHash(i * 2 + 1, seed + row * 7) - 0.5;
        sites.add(Offset((i + 0.5 + jx * 0.9) * w / n, y + jy * rh * 0.95));
        sizes.add(rh);
      }
      y += rh * (0.8 + 0.4 * fieldHash(row, seed + 3));
      row++;
    }
    final cellW = 80.0 * _u, cellH = 80.0 * _u / stretch;
    final grid = <int, List<int>>{};
    int key(int gx, int gy) => gx * 7919 + gy;
    final cols = math.max(1, (w / cellW).ceil());
    for (var i = 0; i < sites.length; i++) {
      final gx = (sites[i].dx / cellW).floor() % cols;
      final gy = (sites[i].dy / cellH).floor();
      grid.putIfAbsent(key(gx, gy), () => []).add(i);
    }
    final out = <_Plate>[];
    for (var i = 0; i < sites.length; i++) {
      final p = sites[i];
      final rh = sizes[i];
      if (p.dy < top - rh || p.dy > bottom + rh) continue;
      final r = rh * stretch * 1.6;
      var poly = <Offset>[
        Offset(p.dx - r, (p.dy - r / stretch) * stretch),
        Offset(p.dx + r, (p.dy - r / stretch) * stretch),
        Offset(p.dx + r, (p.dy + r / stretch) * stretch),
        Offset(p.dx - r, (p.dy + r / stretch) * stretch),
      ];
      final ps = Offset(p.dx, p.dy * stretch);
      final gx = (p.dx / cellW).floor(), gy = (p.dy / cellH).floor();
      for (var ix = gx - 2; ix <= gx + 2; ix++) {
        for (var iy = gy - 2; iy <= gy + 2; iy++) {
          final wrapX = ix < 0 ? -w : (ix >= cols ? w : 0.0);
          for (final j in grid[key(ix % cols, iy)] ?? const <int>[]) {
            if (j == i && wrapX == 0) continue;
            final q = Offset(sites[j].dx + wrapX, sites[j].dy * stretch);
            final d = q - ps;
            if (d.distanceSquared < 1e-6) continue;
            poly = SwampField._clipHalf(poly, (q + ps) / 2, d);
            if (poly.length < 3) break;
          }
        }
      }
      if (poly.length < 3) continue;
      var cx = 0.0, cy = 0.0;
      for (final q in poly) {
        cx += q.dx;
        cy += q.dy / stretch;
      }
      cx /= poly.length;
      cy /= poly.length;
      if (cy < top - 2 * _u) continue;
      final (open, warm) = _lavaAt(layer, cx, cy);
      // Back onto the lava, drawn in from the cracks — wider where it is
      // warm — the edges a little wavy.
      final crack = (0.3 + 0.07 * rh / _u) * _u * (1 + warm * 1.6 + open * 2);
      final pts = <Offset>[];
      for (var e = 0; e < poly.length; e++) {
        final a = Offset(poly[e].dx, poly[e].dy / stretch);
        final b = Offset(
          poly[(e + 1) % poly.length].dx,
          poly[(e + 1) % poly.length].dy / stretch,
        );
        for (var s = 0; s < 2; s++) {
          final q = Offset.lerp(a, b, s / 2)!;
          final wob = s == 0
              ? Offset.zero
              : Offset(0, (fieldHash(i * 13 + e, seed + 5) - 0.5) * rh * 0.16);
          final toMid = Offset(cx, cy) - q;
          final len = toMid.distance;
          final inset = len > crack * 2 ? toMid / len * crack : toMid * 0.4;
          pts.add(q + inset + wob);
        }
      }
      out.add((pts, cx, cy, rh, i, open, warm));
    }
    return out;
  }

  /// [band] drawn a loop away too where it reaches over an edge of [w].
  void _eachCopy(_Band band, double w, void Function(double dx) paint) {
    var lo = double.infinity, hi = -double.infinity;
    for (final p in [...band.a, ...band.b]) {
      lo = math.min(lo, p.dx);
      hi = math.max(hi, p.dx);
    }
    paint(0);
    if (!_loop) return;
    if (lo < 40 * _u) paint(w);
    if (hi > w - 40 * _u) paint(-w);
  }

  /// [band] as one strip of triangles, shaded across: [colors] at
  /// [across] — each a distance from its middle in half widths, -1 its
  /// first edge, 1 its other — blending smoothly between, with no seam
  /// anywhere along it.
  void _bandStrip(
    Canvas c,
    _Band band,
    double dx,
    List<double> across,
    List<Color> colors,
  ) {
    final n = band.a.length;
    if (n < 2) return;
    final m = across.length;
    final pts = <Offset>[];
    for (var k = 0; k < n; k++) {
      final mid = Offset.lerp(band.a[k], band.b[k], 0.5)!.translate(dx, 0);
      final half = (band.b[k] - band.a[k]) / 2;
      for (final s in across) {
        pts.add(mid + half * s);
      }
    }
    final positions = <Offset>[], tints = <Color>[];
    for (var k = 0; k + 1 < n; k++) {
      for (var j = 0; j + 1 < m; j++) {
        final i0 = k * m + j, i1 = i0 + 1, i2 = i0 + m, i3 = i2 + 1;
        for (final i in [i0, i1, i2, i2, i1, i3]) {
          positions.add(pts[i]);
          // A river comes up out of the far edge of the field, not off a
          // line across it.
          final c = colors[i % m];
          final fade = band.river ? math.min(1.0, (i ~/ m) / 5) : 1.0;
          tints.add(fade < 1 ? c.withValues(alpha: c.a * fade) : c);
        }
      }
    }
    c.drawVertices(
      Vertices(VertexMode.triangles, positions, colors: tints),
      BlendMode.srcOver,
      Paint(),
    );
  }

  /// [layer]'s lava, for a lava-graded sheet: the rock under the crust,
  /// cooled nearly black; the warmth round the open lava, which shows in
  /// the cracks near it; the crust in plates, each lit along its far edge
  /// and shaded toward the viewer; then the open lava over it — rivers,
  /// pools, the moats at the feet of the rock — hot down the middle, the
  /// flow drawn out in streaks along it, rafts of crust adrift in it.
  void _paintLavaField(
    Canvas c,
    double w,
    SceneLayer layer,
    List<_Plate> plates,
  ) {
    final (top, bottom) = _lavaBand(layer);
    // Everything in it is cut to its wandering shore.
    final edge = Path()..moveTo(-12 * _u, bottom);
    for (var x = -12 * _u; x <= w + 12 * _u; x += 3 * _u) {
      edge.lineTo(x, _shore(layer, x));
    }
    edge
      ..lineTo(w + 12 * _u, _shore(layer, w + 12 * _u))
      ..lineTo(w + 12 * _u, bottom)
      ..close();
    final fade = 4 * _u;
    c
      ..drawPath(
        edge,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, top),
            Offset(0, bottom),
            [_heat(0.06), _heat(0.045), _heat(0.03)],
            [0.0, fade / (bottom - top), 1.0],
          ),
      )
      ..save()
      ..clipPath(edge);
    final bands = _bands[layer] ?? const <_Band>[];
    // The warmth round the open lava, for the cracks to show.
    for (final band in bands) {
      _eachCopy(band, w, (dx) {
        final (h0, _, h2) = band.heat;
        final g = band.river ? 2.6 : 2.2;
        _bandStrip(
          c,
          band,
          dx,
          [-g, -1, 0, 1, g],
          [
            _heat(0.05, a: 0),
            _heat(0.08 + 0.25 * h0),
            _heat(0.3),
            _heat(0.08 + 0.25 * h2),
            _heat(0.05, a: 0),
          ],
        );
      });
    }
    // The crust.
    for (final (pts, cx, cy, size, id, _, warm) in plates) {
      final own = (fieldHash(id, 873) - 0.5) * 0.24;
      final a = ((cy - top) / (5 * _u)).clamp(0.25, 1.0);
      for (final dx in [0.0, if (cx > w - size * 3) -w, if (cx < size * 3) w]) {
        final at = [for (final q in pts) q.translate(dx, 0)];
        var y0 = double.infinity, y1 = -double.infinity;
        for (final q in at) {
          y0 = math.min(y0, q.dy);
          y1 = math.max(y1, q.dy);
        }
        c.drawPath(
          Path()..addPolygon(at, true),
          Paint()
            ..shader = Gradient.linear(Offset(0, y0), Offset(0, y1), [
              _heat(0.06 * warm, shade: 0.08 + own, a: a),
              _heat(0.02 * warm, shade: 0.5 + own, a: a),
            ]),
        );
      }
    }
    // Speckle over the crust: grit, cinders, glassy bits.
    final r = FieldRandom(layer == mid ? 821 : 861);
    final grains = GrainBatch(2);
    for (var i = 0; i < (w * (bottom - top) / (_u * _u * 14)).round(); i++) {
      grains.add(
        r.next() < 0.6 ? 0 : 1,
        r.next() * w,
        top + 3 * _u + r.next() * (bottom - top - 3 * _u),
      );
    }
    grains
      ..draw(c, 0, 1.2 * _u, _heat(0, shade: 0.9, a: 0.5))
      ..draw(c, 1, 1.1 * _u, _heat(0, shade: 0, a: 0.35));
    // The open lava.
    for (final band in bands) {
      _eachCopy(band, w, (dx) {
        final (h0, h1, h2) = band.heat;
        _bandStrip(
          c,
          band,
          dx,
          const [-1, 0, 1],
          [_heat(h0), _heat(h1), _heat(h2)],
        );
        _paintFlow(c, band, dx, layer, r);
      });
    }
    c.restore();
  }

  /// The flow in a band of open lava: bright streaks drawn out along it,
  /// and rafts of crust adrift in it.
  void _paintFlow(
    Canvas c,
    _Band band,
    double dx,
    SceneLayer layer,
    FieldRandom r,
  ) {
    final k = layer == mid ? 0.6 : 1.0;
    final streaks = Path(), rafts = Path(), raftTops = Path();
    for (var i = 0; i + 1 < band.a.length; i++) {
      final a = band.a[i], b = band.b[i];
      final next = Offset.lerp(band.a[i + 1], band.b[i + 1], 0.5)!;
      final mid = Offset.lerp(a, b, 0.5)!;
      final along = next - mid;
      final len = along.distance;
      if (len <= 0) continue;
      final dir = along / len;
      final across = (b - a).distance;
      for (var j = 0; j < (across / (6 * _u * k)).ceil(); j++) {
        if (r.next() > 0.55) continue;
        final at = Offset.lerp(a, b, 0.15 + 0.7 * r.next())!.translate(dx, 0);
        final l = r.range(4, 12) * _u * k, t = r.range(0.5, 1.1) * _u * k;
        final nrm = Offset(-dir.dy, dir.dx);
        streaks.addPolygon([
          at - dir * l,
          at + nrm * t,
          at + dir * l,
          at - nrm * t,
        ], true);
      }
      if (across > 7 * _u * k && r.next() < (band.river ? 0.12 : 0.05)) {
        final at = Offset.lerp(a, b, 0.25 + 0.5 * r.next())!.translate(dx, 0);
        final s = r.range(2, 4.5) * _u * k;
        final nrm = Offset(-dir.dy, dir.dx);
        final raft = [
          at - dir * s * r.range(0.8, 1.3),
          at + nrm * s * r.range(0.3, 0.6),
          at + dir * s * r.range(0.8, 1.3),
          at - nrm * s * r.range(0.3, 0.6),
        ];
        rafts.addPolygon(raft, true);
        raftTops.addPolygon([
          raft[0],
          Offset.lerp(raft[0], raft[1], 0.5)!,
          Offset.lerp(raft[1], raft[2], 0.5)!,
          raft[2],
          Offset.lerp(raft[2], raft[3], 0.7)!,
        ], true);
      }
    }
    c
      ..drawPath(streaks, Paint()..color = _heat(0.92, a: 0.7))
      ..drawPath(rafts, Paint()..color = _heat(0.04, shade: 0.45))
      ..drawPath(raftTops, Paint()..color = _heat(0.0, shade: 0.12, a: 0.8));
  }

  /// The open lava's light on the crust round it, for a glow sheet.
  void _paintCrustGlow(
    Canvas c,
    double w,
    SceneLayer layer,
    List<_Plate> plates,
  ) {
    for (final band in _bands[layer] ?? const <_Band>[]) {
      _eachCopy(band, w, (dx) {
        final (h0, _, h2) = band.heat;
        final g = band.river ? 3.2 : 2.6;
        _bandStrip(
          c,
          band,
          dx,
          [-g, -1, 0, 1, g],
          [
            fieldMap(0.3, 0, 0, 0),
            fieldMap(0.6, 0, 0, 0.5 * h0 + 0.1),
            fieldMap(0.9, 0, 0, 0.2),
            fieldMap(0.6, 0, 0, 0.5 * h2 + 0.1),
            fieldMap(0.3, 0, 0, 0),
          ],
        );
      });
    }
  }

  /// Smoke lying over the lava: long soft lenses of it, lit red from
  /// below, wrapping round the sheet so it can drift for ever.
  void _paintSmoke(
    Canvas c,
    double w,
    double y,
    double alpha, {
    required int seed,
  }) {
    final r = FieldRandom(seed);
    final n = math.max(3, (w / (230 * _u)).round());
    for (var k = 0; k < n; k++) {
      final cx = (k + r.range(0.1, 0.9)) * w / n;
      final cy = y + r.range(-0.03, 0.03) * _h;
      final rx = r.range(120, 260) * _u;
      final ry = r.range(8, 16) * _u;
      final a = alpha * r.range(0.5, 1);
      for (final dx in [-w, 0.0, w]) {
        if (cx + dx + rx < 0 || cx + dx - rx > w) continue;
        _lens(
          c,
          cx + dx,
          cy,
          rx,
          ry,
          fieldMap(0.3, 0, 0.8, a),
          fieldMap(0.4, 0, 0.6, 0),
        );
      }
    }
  }

  // ── Rock: shelves, spires, the vent ──────────────────────────────────────

  /// Every shelf, spire and vent on [layer] on one sheet per grade, each
  /// drawn again a loop away where it reaches over an edge.
  List<FieldSheet> _rockSheets(
    SceneLayer layer,
    double w,
    List<_Shelf> shelves,
    List<_Spire> spires,
    _Vent? vent,
  ) {
    var top = double.infinity, bottom = 0.0;
    for (final s in shelves) {
      final r = _shelfBounds(s);
      top = math.min(top, r.top);
      bottom = math.max(bottom, r.bottom);
    }
    for (final s in spires) {
      top = math.min(top, s.top - 6 * _u);
      bottom = math.max(bottom, s.base + 14 * _u);
    }
    if (vent != null) {
      top = math.min(top, vent.base - vent.h - 8 * _u);
      bottom = math.max(bottom, vent.base + 14 * _u);
    }
    if (top >= bottom) return const [];
    final bounds = Rect.fromLTRB(-20 * _u, top, w - 0.5, bottom);
    final res = layer == mid ? 0.8 : 1.0;

    void each(
      Canvas c,
      void Function(_Shelf) shelf,
      void Function(_Spire) spire, [
      void Function(_Vent)? onVent,
    ]) {
      for (final s in shelves) {
        _wrapped(s.cx, s.hw + s.flare + 16 * _u, w, (x) {
          // A copy across the seam lays down no glints of its own.
          final sink = _sink;
          if (x != s.cx) _sink = null;
          c
            ..save()
            ..translate(x - s.cx, 0);
          shelf(s);
          c.restore();
          _sink = sink;
        });
      }
      for (final sp in spires) {
        _wrapped(sp.x, sp.hw * 1.3, w, (x) => spire(sp.at(x)));
      }
      if (vent != null && onVent != null) onVent(vent);
    }

    return [
      FieldSheet(
        bounds: bounds,
        resolution: res,
        grade: _gRock,
        paint: (c) => each(
          c,
          (s) => s.basalt ? _paintBasalt(c, s) : _paintCinder(c, s),
          (sp) => _paintSpire(c, sp),
          (v) => _paintVent(c, v),
        ),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res,
        grade: _gAshTop,
        paint: (c) => each(c, (s) => _paintAshTop(c, s), (_) {}),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res,
        grade: layer == mid ? _gMidLava : _gLava,
        paint: (c) => each(
          c,
          (s) => _paintShelfLava(c, s),
          (_) {},
          (v) => _paintVentLava(c, v),
        ),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res * 0.7,
        grade: _gGlow,
        paint: (c) => each(
          c,
          (s) => _paintShelfGlow(c, s),
          (sp) => _paintSpireGlow(c, sp),
          (v) => _paintVentGlow(c, v),
        ),
      ),
      FieldSheet(
        bounds: bounds,
        resolution: res * 0.9,
        light: true,
        paint: (c) => _sinking(layer, () {
          final sparks = GrainBatch(_sparkAlpha.length);
          each(
            c,
            (s) => _paintShelfLight(c, s, sparks),
            (sp) => _paintSpireLight(c, sp, sparks),
            (v) => _paintVentLight(c, v, sparks),
          );
          _drawSparks(c, sparks, layer == mid ? 1.1 : 1.35);
        }),
      ),
    ];
  }

  Path _edge(
    _Shelf s,
    double Function(double) top,
    double Function(double) bottom,
  ) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2 * _u;
    final path = Path()..moveTo(x0, top(x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, top(x));
    }
    path.lineTo(x1, top(x1));
    for (var x = x1; x >= x0; x -= step) {
      path.lineTo(x, bottom(x));
    }
    return path..close();
  }

  /// A shelf's face: from its lip down to the lava, its ends breaking out
  /// a little wider toward the lava.
  Path _shelfFace(_Shelf s) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final wl = _sLava(s);
    final step = 2 * _u;
    final path = Path()..moveTo(x0, _sFront(s, x0));
    for (var x = x0; x <= x1; x += step) {
      path.lineTo(x, _sFront(s, x));
    }
    path
      ..lineTo(x1, _sFront(s, x1))
      ..lineTo(
        x1 + s.flare * 0.45,
        _sFront(s, x1) + (wl - _sFront(s, x1)) * 0.4,
      )
      ..lineTo(x1 + s.flare, wl);
    for (var x = x1 + s.flare; x >= x0 - s.flare; x -= step) {
      path.lineTo(x, _lavaEdge(s, x));
    }
    return path
      ..lineTo(x0 - s.flare, wl)
      ..lineTo(
        x0 - s.flare * 0.45,
        _sFront(s, x0) + (wl - _sFront(s, x0)) * 0.4,
      )
      ..close();
  }

  /// A shelf of basalt: its flat top broken toward the back, stepping down
  /// at one end; its face split in columns, each its own shade, a ledge
  /// across them, scorched dark where it stands in the lava.
  void _paintBasalt(Canvas c, _Shelf s) {
    final haze = s.haze;
    final wl = _sLava(s);
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final top = _edge(s, (x) => _sBack(s, x), (x) => _sFront(s, x) + 0.6 * _u);
    final face = _shelfFace(s);
    c
      ..drawPath(face, Paint()..color = fieldMap(haze, 0, 0.62))
      ..drawPath(
        top,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _sBack(s, s.cx)),
            Offset(0, _sFront(s, s.cx)),
            [fieldMap(haze, 0.3, 0.06), fieldMap(haze, 0.1, 0.24)],
          ),
      );
    c
      ..save()
      ..clipPath(face);
    double lip(double x) => _sFront(s, x.clamp(x0, x1));
    // Columns down the face, the ends turned away into shade, each lit a
    // little along its left edge.
    final r = FieldRandom(s.seed * 7 + 1);
    final cuts = <double>[x0 - s.flare - 2 * _u];
    var x = x0;
    while (true) {
      x += s.hw * r.range(0.09, 0.2);
      if (x >= x1 - s.hw * 0.06) break;
      cuts.add(x);
    }
    cuts.add(x1 + s.flare + 2 * _u);
    for (var k = 0; k + 1 < cuts.length; k++) {
      final a = cuts[k], z = cuts[k + 1];
      final side = (((a + z) / 2) - s.cx) / s.hw;
      final turn = math.pow(math.min(1.0, side.abs()), 2.2).toDouble();
      final own = r.range(-0.09, 0.09);
      final lean = r.range(-0.06, 0.06) * s.rise;
      c.drawPath(
        Path()..addPolygon([
          Offset(a, lip(a) - 2 * _u),
          Offset(z, lip(z) - 2 * _u),
          Offset(z + lean, wl + 3 * _u),
          Offset(a + lean, wl + 3 * _u),
        ], true),
        Paint()
          ..shader =
              Gradient.linear(Offset(0, _sFront(s, s.cx)), Offset(0, wl), [
                fieldMap(haze, 0.03, 0.42 + 0.3 * turn + own),
                fieldMap(haze, 0, 0.74 + 0.16 * turn + own),
              ]),
      );
      final ew = math.min((z - a) * 0.22, 1.6 * _u);
      c.drawPath(
        Path()..addPolygon([
          Offset(a, lip(a)),
          Offset(a + ew, lip(a + ew)),
          Offset(a + ew + lean, wl),
          Offset(a + lean, wl),
        ], true),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _sFront(s, s.cx)),
            Offset(0, wl),
            [
              fieldMap(haze, 0.22, 0.16 + 0.3 * turn, 0.7),
              fieldMap(haze, 0.05, 0.6, 0.3),
            ],
          ),
      );
    }
    // A ledge across the face: lit along its top, its shadow under it.
    final ledgeF = r.range(0.38, 0.55);
    double ledge(double x) =>
        lip(x) +
        (wl - lip(x)) *
            (ledgeF + 0.08 * fieldNoise(x / (24 * _u), s.seed + 21));
    for (final (off, thick, map) in [
      (0.0, 1.4, fieldMap(haze, 0.18, 0.2, 0.65)),
      (1.4, 2.8, fieldMap(haze, 0, 0.9, 0.55)),
    ]) {
      final band = Path()..moveTo(x0 - s.flare, ledge(x0) + off * _u);
      for (var x = x0 - s.flare; x <= x1 + s.flare; x += 2.5 * _u) {
        band.lineTo(x, ledge(x) + off * _u);
      }
      for (var x = x1 + s.flare; x >= x0 - s.flare; x -= 2.5 * _u) {
        band.lineTo(x, ledge(x) + (off + thick) * _u);
      }
      c.drawPath(band..close(), Paint()..color = map);
    }
    // The edge of the top, catching the light, with its shadow under it.
    for (final (off, thick, map) in [
      (0.0, 1.3, fieldMap(haze, 0.3, 0.1, 0.8)),
      (1.3, 2.4, fieldMap(haze, 0, 0.84, 0.5)),
    ]) {
      final band = Path()..moveTo(x0, _sFront(s, x0) + off * _u);
      for (var x = x0; x <= x1; x += 1.5 * _u) {
        band.lineTo(x, _sFront(s, x) + off * _u);
      }
      for (var x = x1; x >= x0; x -= 1.5 * _u) {
        band.lineTo(x, _sFront(s, x) + (off + thick) * _u);
      }
      c.drawPath(band..close(), Paint()..color = map);
    }
    // Scorched where it stands in the lava.
    c.drawRect(
      Rect.fromLTRB(
        x0 - s.flare,
        wl - s.rise * 0.35,
        x1 + s.flare,
        wl + 4 * _u,
      ),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, wl - s.rise * 0.35),
          Offset(0, wl),
          [fieldMap(haze, 0, 0.6, 0), fieldMap(haze, 0, 0.95, 0.8)],
        ),
    );
    // Pits and flecks.
    final grains = GrainBatch(2);
    final n = (s.hw * s.rise * 1.4 / (_u * _u * 10)).round();
    for (var k = 0; k < n; k++) {
      final gx = s.cx + (fieldHash(k, s.seed + 31) * 2 - 1) * (s.hw + s.flare);
      final gy = lip(gx) + fieldHash(k, s.seed + 37) * (wl - lip(gx));
      grains.add(fieldHash(k, s.seed + 41) < 0.6 ? 0 : 1, gx, gy);
    }
    grains
      ..draw(c, 0, 1.5 * _u, fieldMap(haze, 0, 0.92, 0.55))
      ..draw(c, 1, 1.3 * _u, fieldMap(haze, 0.3, 0.2, 0.4));
    c.restore();
    // Risers where the top steps down, in shade.
    if (s.steps != 0) {
      for (final k in const [0.6, 0.8]) {
        final sx = s.cx + k * s.steps * s.hw;
        final hi = _sStand(s, sx - s.steps * 0.5 * _u);
        final lo = _sStand(s, sx + s.steps * 0.5 * _u);
        final wd = 2.5 * _u * s.steps;
        c.drawPath(
          Path()..addPolygon([
            Offset(sx, hi - s.plate * 0.55),
            Offset(sx + wd, lo - s.plate * 0.55),
            Offset(sx + wd, lo + s.plate * 0.45),
            Offset(sx, hi + s.plate * 0.45),
          ], true),
          Paint()..color = fieldMap(haze, 0, 0.55),
        );
      }
    }
  }

  /// A bank of cinder: a crowned heap of scoria, rough with holes and
  /// clinker, black-red, lumps of old bombs set in it, cinders rolled to its
  /// foot.
  void _paintCinder(Canvas c, _Shelf s) {
    final haze = s.haze;
    final wl = _sLava(s);
    final face = _edge(
      s,
      (x) => _sFront(s, x) - 0.5 * _u,
      (x) => _lavaEdge(s, x),
    );
    final lip = _sFront(s, s.cx);
    c.drawPath(
      face,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, lip),
          Offset(0, wl),
          [
            fieldMap(haze, 0.08, 0.32),
            fieldMap(haze, 0, 0.55),
            fieldMap(haze, 0, 0.9),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(face);
    // Scoria: dark holes and lit clinker, coarser lower down.
    final grains = GrainBatch(3);
    final r = FieldRandom(s.seed * 5 + 2);
    final n = (s.hw * s.rise * 2.2 / (_u * _u * 7)).round();
    for (var k = 0; k < n; k++) {
      final x = s.cx + (r.next() * 2 - 1) * s.hw;
      final y = _sFront(s, x) + r.next() * (wl - _sFront(s, x));
      final roll = r.next();
      grains.add(roll < 0.55 ? 0 : (roll < 0.85 ? 1 : 2), x, y);
    }
    grains
      ..draw(c, 0, 1.7 * _u, fieldMap(haze, 0, 0.95, 0.6))
      ..draw(c, 1, 1.3 * _u, fieldMap(haze, 0.2, 0.3, 0.5))
      ..draw(c, 2, 2.2 * _u, fieldMap(haze, 0.1, 0.5, 0.6));
    // Bombs set in it: rounded lumps, lit on top.
    final bombs = Path(), tops = Path();
    for (var k = 0; k < 2 + (s.hw / (40 * _u)).floor(); k++) {
      final x = s.cx + r.range(-0.8, 0.8) * s.hw;
      final y = _sFront(s, x) + r.range(0.25, 0.75) * (wl - _sFront(s, x));
      final rad = r.range(3, 6) * _u * (haze > 0 ? 0.7 : 1);
      bombs.addOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: rad * 2.2,
          height: rad * 1.6,
        ),
      );
      tops.addOval(
        Rect.fromCenter(
          center: Offset(x - rad * 0.15, y - rad * 0.35),
          width: rad * 1.4,
          height: rad * 0.7,
        ),
      );
    }
    c
      ..drawPath(bombs, Paint()..color = fieldMap(haze, 0, 0.7))
      ..drawPath(tops, Paint()..color = fieldMap(haze, 0.22, 0.25))
      ..restore();
    // Cinders rolled to its foot.
    final cinders = Path(), lit = Path();
    for (var k = 0; k < 3 + (s.hw / (30 * _u)).floor(); k++) {
      final x = s.cx + r.range(-1.05, 1.05) * s.hw;
      final rad = r.range(2, 4.5) * _u * (haze > 0 ? 0.7 : 1);
      final at = Offset(x, wl - rad * 0.3);
      cinders.addOval(
        Rect.fromCenter(center: at, width: rad * 2.4, height: rad * 1.5),
      );
      lit.addOval(
        Rect.fromCenter(
          center: at + Offset(-rad * 0.2, -rad * 0.32),
          width: rad * 1.3,
          height: rad * 0.6,
        ),
      );
    }
    c
      ..drawPath(cinders, Paint()..color = fieldMap(haze, 0.04, 0.6))
      ..drawPath(lit, Paint()..color = fieldMap(haze, 0.28, 0.18));
  }

  /// The ash on a shelf, for an ash-graded sheet: lying over a cinder
  /// bank's whole top, in drifts along the back of a basalt one, a few
  /// stones of pumice on it.
  void _paintAshTop(Canvas c, _Shelf s) {
    final haze = s.haze;
    final r = FieldRandom(s.seed * 3 + 5);
    if (!s.basalt) {
      c.drawPath(
        _edge(s, (x) => _sBack(s, x), (x) => _sFront(s, x) + 0.8 * _u),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, _sBack(s, s.cx)),
            Offset(0, _sFront(s, s.cx)),
            [fieldMap(haze, 0.16, 0.12), fieldMap(haze, 0.02, 0.46)],
          ),
      );
    } else {
      final top = _edge(
        s,
        (x) => _sBack(s, x) - 0.5 * _u,
        (x) => _sFront(s, x) + 0.4 * _u,
      );
      c
        ..save()
        ..clipPath(top);
      final drifts = Path();
      final n = (s.hw / (3 * _u)).round();
      for (var k = 0; k < n; k++) {
        final x = s.cx + r.range(-1, 1) * s.hw;
        if (fieldLoopNoise(x, 36 * _u, s.seed, 0) < -0.15) continue;
        final back = _sBack(s, x), front = _sFront(s, x);
        final d = math.pow(r.next(), 1.8).toDouble();
        final y = back + d * (front - back) * 0.8;
        final rad = r.range(3, 8) * _u * (1 - d * 0.5) * (haze > 0 ? 0.7 : 1);
        drifts.addOval(
          Rect.fromCenter(
            center: Offset(x, y),
            width: rad * 3,
            height: rad * 0.9,
          ),
        );
      }
      c
        ..drawPath(drifts, Paint()..color = fieldMap(haze, 0.08, 0.25, 0.85))
        ..restore();
    }
    // Pumice lying about on it.
    final stones = Path(), lit = Path();
    for (var k = 0; k < 2 + (s.hw / (36 * _u)).floor(); k++) {
      final x = s.cx + r.range(-0.85, 0.85) * s.hw;
      final y =
          _sBack(s, x) + r.range(0.3, 0.8) * (_sFront(s, x) - _sBack(s, x));
      final rad = r.range(1.6, 3.4) * _u * (haze > 0 ? 0.7 : 1);
      stones.addOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: rad * 2.2,
          height: rad * 1.2,
        ),
      );
      lit.addOval(
        Rect.fromCenter(
          center: Offset(x - rad * 0.2, y - rad * 0.25),
          width: rad * 1.2,
          height: rad * 0.5,
        ),
      );
    }
    c
      ..drawPath(stones, Paint()..color = fieldMap(haze, 0.0, 0.6))
      ..drawPath(lit, Paint()..color = fieldMap(haze, 0.3, 0.1));
  }

  /// A shelf's fire, for a lava-graded sheet: lava lapping at its foot, and
  /// in basalt a fissure or two where it seeps up into the face.
  void _paintShelfLava(Canvas c, _Shelf s) {
    final x0 = s.cx - s.hw - s.flare, x1 = s.cx + s.hw + s.flare;
    final wl = _sLava(s);
    final lap = Path()..moveTo(x0, _lavaEdge(s, x0) - 4 * _u);
    for (var x = x0; x <= x1; x += 2 * _u) {
      lap.lineTo(
        x,
        _lavaEdge(s, x) -
            4 * _u -
            1.2 * _u * fieldNoise(x / (5 * _u), s.seed + 6),
      );
    }
    for (var x = x1; x >= x0; x -= 2 * _u) {
      lap.lineTo(x, _lavaEdge(s, x) + 2.5 * _u);
    }
    c.drawPath(
      lap..close(),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, wl - 5 * _u),
          Offset(0, wl + 2.5 * _u),
          [_heat(0.5, a: 0), _heat(0.85, a: 0.75), _heat(0.6, a: 0.5)],
          const [0.0, 0.7, 1.0],
        ),
    );
    for (final (x, y0, len, wd, bend, branch) in _fissures(s)) {
      final path = Path()
        ..addPolygon([
          Offset(x - wd, y0 + 1 * _u),
          Offset(x + wd, y0 + 1 * _u),
          Offset(x + bend * 0.5 + wd * 0.35, y0 - len * 0.5),
          Offset(x + bend, y0 - len),
          Offset(x + bend * 0.5 - wd * 0.45, y0 - len * 0.5),
        ], true);
      c.drawPath(
        path,
        Paint()
          ..shader = Gradient.linear(
            Offset(0, y0),
            Offset(0, y0 - len),
            [_heat(0.85), _heat(0.45, a: 0.9), _heat(0.2, a: 0.4)],
            const [0.0, 0.6, 1.0],
          ),
      );
      // A branch off it.
      if (branch != 0) {
        final at = Offset(x + bend * 0.5, y0 - len * 0.5);
        c.drawPath(
          Path()..addPolygon([
            at.translate(-wd * 0.4, 0),
            at.translate(wd * 0.4, 0),
            at.translate(branch * len * 0.3, -len * 0.25),
          ], true),
          Paint()..color = _heat(0.4, a: 0.8),
        );
      }
    }
  }

  /// The fissures up a basalt shelf's face, where the lava seeps into it:
  /// (x, its foot at the lava, how far up, how wide, how it bends, which
  /// way a branch leaves it — 0 for none).
  List<(double, double, double, double, double, double)> _fissures(_Shelf s) {
    if (!s.basalt) return const [];
    final r = FieldRandom(s.seed * 19 + 3);
    return [
      for (var k = 0; k < 1 + (s.hw / (70 * _u)).floor(); k++)
        () {
          final x = s.cx + r.range(-0.75, 0.75) * s.hw;
          final y0 = _lavaEdge(s, x);
          final len = (y0 - _sFront(s, x)) * r.range(0.4, 0.75);
          final wd = r.range(1.3, 2.2) * _u * (s.haze > 0 ? 0.7 : 1);
          final bend = r.range(-1, 1) * 3 * _u;
          final branch = r.next() < 0.6 ? (r.next() < 0.5 ? -1.0 : 1.0) : 0.0;
          return (x, y0, len, wd, bend, branch);
        }(),
    ];
  }

  /// The lava's light on a shelf, for a glow sheet: up its face from the
  /// lava, and round its fissures.
  void _paintShelfGlow(Canvas c, _Shelf s) {
    final x0 = s.cx - s.hw - s.flare, x1 = s.cx + s.hw + s.flare;
    final wl = _sLava(s);
    final lip = _sFront(s, s.cx);
    final face = s.basalt
        ? _shelfFace(s)
        : _edge(s, (x) => _sFront(s, x) - 0.5 * _u, (x) => _lavaEdge(s, x));
    c
      ..save()
      ..clipPath(face)
      ..drawRect(
        Rect.fromLTRB(x0, lip, x1, wl + 2 * _u),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, lip),
            Offset(0, wl),
            [
              fieldMap(0, 0, 0, 0),
              fieldMap(0.3, 0, 0, 0.25),
              fieldMap(0.9, 0, 0, 0.8),
            ],
            const [0.0, 0.55, 1.0],
          ),
      );
    for (final (x, y0, len, _, _, _) in _fissures(s)) {
      final at = Offset(x, y0 - len * 0.45);
      c
        ..save()
        ..translate(at.dx, at.dy)
        ..scale(0.6, 1)
        ..drawCircle(
          Offset.zero,
          len * 0.75,
          Paint()
            ..shader = Gradient.radial(Offset.zero, len * 0.75, [
              fieldMap(0.7, 0, 0, 0.5),
              fieldMap(0.3, 0, 0, 0),
            ]),
        )
        ..restore();
    }
    c.restore();
  }

  /// The light on a shelf: bands down from the back of its top, grains
  /// along the back and the lip, along basalt's column edges, glints of
  /// glassy rock.
  void _paintShelfLight(Canvas c, _Shelf s, GrainBatch sparks) {
    final x0 = s.cx - s.hw, x1 = s.cx + s.hw;
    final step = 2.2 * _u;
    for (final (depth, a) in [(1.4, 0.5), (3.6, 0.24), (8.0, 0.08)]) {
      final band = Path()..moveTo(x0, _sBack(s, x0));
      for (var x = x0; x <= x1; x += step) {
        band.lineTo(x, _sBack(s, x));
      }
      for (var x = x1; x >= x0; x -= step) {
        band.lineTo(
          x,
          math.min(_sFront(s, x), _sBack(s, x) + depth * _u * _sPinch(s, x)),
        );
      }
      c.drawPath(
        band..close(),
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a),
      );
    }
    var k = 0;
    for (var x = x0; x <= x1; x += step, k++) {
      final roll = fieldHash(k, s.seed * 13);
      if (roll < 0.3) {
        sparks.add((roll * 10).floor().clamp(0, 3), x, _sBack(s, x) + 0.6 * _u);
        if (roll < 0.03) _glint(x, _sBack(s, x));
      } else if (roll > (s.basalt ? 0.6 : 0.88)) {
        sparks.add(s.basalt ? 2 : 0, x, _sFront(s, x) + 0.7 * _u);
        if (s.basalt && roll > 0.97) _glint(x, _sFront(s, x) + 0.7 * _u);
      }
    }
  }

  // ── Spires ───────────────────────────────────────────────────────────────

  /// Spires of rock standing in the lava among the back shelves.
  List<_Spire> _midSpires(double w) {
    final out = <_Spire>[];
    for (final (fx, hw, hgt, seed) in const [
      (0.075, 16.0, 46.0, 1),
      (0.105, 10.0, 28.0, 2),
      (0.44, 13.0, 36.0, 3),
      (0.72, 15.0, 52.0, 4),
      (0.745, 9.0, 24.0, 5),
      (0.985, 12.0, 30.0, 6),
    ]) {
      final x = fx * w;
      if (_shelfAt(mid, x, reach: 1.3) != null) continue;
      out.add(
        _Spire(
          x,
          _h * (0.69 + 0.004 * seed),
          hw * _u,
          hgt * _u,
          1300 + seed,
          0.3,
        ),
      );
    }
    return out;
  }

  /// Spires among the near shelves, about the vent and between the dead
  /// trees.
  List<_Spire> _nearSpires(double w) {
    final out = <_Spire>[];
    for (final (fx, hw, hgt, seed) in const [
      (0.165, 14.0, 34.0, 1),
      (0.478, 22.0, 70.0, 2),
      (0.497, 13.0, 38.0, 3),
      (0.565, 15.0, 30.0, 4),
      (0.765, 18.0, 46.0, 5),
    ]) {
      final x = fx * w;
      if (_shelfAt(near, x, reach: 1.25) != null) continue;
      out.add(
        _Spire(
          x,
          _h * (0.86 + 0.006 * seed),
          hw * _u,
          hgt * _u,
          1400 + seed,
          0,
        ),
      );
    }
    return out;
  }

  /// A spire's outline: a jagged point of rock, broken on its way up, its
  /// foot spread in the lava.
  List<Offset> _spireOutline(_Spire s) {
    if (s.round) {
      // A boulder: a lumpy dome, its highest point first.
      final pts = <Offset>[];
      const n = 16;
      for (var k = 0; k <= n; k++) {
        final th = math.pi * (1 - k / n);
        final bump = 1 + 0.12 * fieldNoise(k * 0.9, s.seed);
        pts.add(
          Offset(
            s.x + math.cos(th) * s.hw * bump,
            s.base - math.pow(math.sin(th), 0.65) * s.h * bump,
          ),
        );
      }
      var hi = 0;
      for (var k = 1; k < pts.length; k++) {
        if (pts[k].dy < pts[hi].dy) hi = k;
      }
      return [...pts.sublist(hi), ...pts.sublist(0, hi)];
    }
    final r = FieldRandom(s.seed);
    final tip = Offset(s.x + r.range(-0.35, 0.35) * s.hw, s.base - s.h);
    final left = <Offset>[], right = <Offset>[];
    const n = 7;
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final y = s.base - s.h * (1 - f);
      final half =
          s.hw * (0.08 + 0.92 * math.pow(f, 0.8)) * r.range(0.82, 1.15);
      final cx = tip.dx + (s.x - tip.dx) * f;
      left.add(Offset(cx - half, y + r.range(-1.5, 1.5) * _u));
      right.add(Offset(cx + half, y + r.range(-1.5, 1.5) * _u));
    }
    left.add(Offset(s.x - s.hw * 1.15, s.base + 2 * _u));
    right.add(Offset(s.x + s.hw * 1.15, s.base + 2 * _u));
    return [tip, ...left.skip(1), ...right.reversed.toList()..removeLast()];
  }

  /// A spire in flat-shaded facets: one face to the light, one away, a
  /// sliver between, its foot scorched.
  void _paintSpire(Canvas c, _Spire s) {
    final pts = _spireOutline(s);
    final haze = s.haze;
    final body = Path()..addPolygon(pts, true);
    c.drawPath(body, Paint()..color = fieldMap(haze, 0, 0.62));
    c
      ..save()
      ..clipPath(body);
    final r = FieldRandom(s.seed + 9);
    final tip = pts.first;
    // A ridge from the tip down to the foot splits it into two faces.
    final foot = Offset(s.x + r.range(-0.3, 0.3) * s.hw, s.base + 2 * _u);
    final mid =
        Offset.lerp(tip, foot, 0.5)! + Offset(r.range(-0.2, 0.2) * s.hw, 0);
    c
      ..drawPath(
        Path()..addPolygon([
          tip,
          mid,
          foot,
          Offset(s.x - s.hw * 1.3, s.base + 4 * _u),
          Offset(s.x - s.hw * 1.3, tip.dy),
        ], true),
        Paint()
          ..shader = Gradient.linear(tip, Offset(tip.dx, s.base), [
            fieldMap(haze, 0.14, 0.32),
            fieldMap(haze, 0.02, 0.58),
          ]),
      )
      ..drawPath(
        Path()..addPolygon([
          tip,
          mid,
          foot,
          Offset(s.x + s.hw * 1.3, s.base + 4 * _u),
          Offset(s.x + s.hw * 1.3, tip.dy),
        ], true),
        Paint()
          ..shader = Gradient.linear(tip, Offset(tip.dx, s.base), [
            fieldMap(haze, 0, 0.66),
            fieldMap(haze, 0, 0.86),
          ]),
      );
    // A sliver of a third face catching the light along the ridge.
    c.drawPath(
      Path()..addPolygon([
        tip,
        mid,
        mid.translate(s.hw * 0.16, s.h * 0.05),
        Offset.lerp(tip, mid, 0.3)!.translate(s.hw * 0.08, 0),
      ], true),
      Paint()..color = fieldMap(haze, 0.24, 0.12, 0.8),
    );
    // Breaks across it.
    for (var k = 0; k < 2 + (s.h / (30 * _u)).floor(); k++) {
      final y = s.base - s.h * r.range(0.1, 0.8);
      final wd = s.hw * r.range(0.3, 0.8);
      final x = s.x + r.range(-0.4, 0.4) * s.hw;
      c.drawPath(
        Path()..addPolygon([
          Offset(x - wd, y),
          Offset(x + wd, y + r.range(-2, 2) * _u),
          Offset(x + wd * 0.6, y + 1.6 * _u),
        ], true),
        Paint()..color = fieldMap(haze, 0, 0.9, 0.6),
      );
    }
    // Scorched at its foot.
    c
      ..drawRect(
        Rect.fromLTRB(
          s.x - s.hw * 1.3,
          s.base - s.h * 0.25,
          s.x + s.hw * 1.3,
          s.base + 4 * _u,
        ),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, s.base - s.h * 0.25),
            Offset(0, s.base),
            [fieldMap(haze, 0, 0.6, 0), fieldMap(haze, 0, 0.95, 0.8)],
          ),
      )
      ..restore();
  }

  void _paintSpireLava(Canvas c, _Spire s) {
    final w = s.hw * 1.2;
    c.drawPath(
      Path()..addPolygon([
        Offset(s.x - w, s.base),
        Offset(s.x - w * 0.5, s.base - 1.4 * _u),
        Offset(s.x + w * 0.4, s.base - 1.2 * _u),
        Offset(s.x + w, s.base),
        Offset(s.x + w, s.base + 2.2 * _u),
        Offset(s.x - w, s.base + 2.2 * _u),
      ], true),
      Paint()..color = _heat(0.85, a: 0.85),
    );
  }

  void _paintSpireGlow(Canvas c, _Spire s) {
    final body = Path()..addPolygon(_spireOutline(s), true);
    c
      ..save()
      ..clipPath(body)
      ..drawRect(
        Rect.fromLTRB(
          s.x - s.hw * 1.3,
          s.base - s.h * 0.6,
          s.x + s.hw * 1.3,
          s.base + 3 * _u,
        ),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, s.base - s.h * 0.6),
            Offset(0, s.base),
            [fieldMap(0.2, 0, 0, 0), fieldMap(0.9, 0, 0, 0.75)],
          ),
      )
      ..restore();
  }

  void _paintSpireLight(Canvas c, _Spire s, GrainBatch sparks) {
    final pts = _spireOutline(s);
    final tip = pts.first;
    if (s.round) {
      // A boulder: grains of light along its top.
      for (var k = 0; k < pts.length; k++) {
        if (pts[k].dy > s.base - s.h * 0.55 || fieldHash(k, s.seed) > 0.6) {
          continue;
        }
        sparks.add(k.isEven ? 2 : 1, pts[k].dx, pts[k].dy + 1 * _u);
      }
      return;
    }
    // Down the ridge's lit side, and the tip.
    final r = FieldRandom(s.seed + 9);
    final foot = Offset(s.x + r.range(-0.3, 0.3) * s.hw, s.base + 2 * _u);
    final mid =
        Offset.lerp(tip, foot, 0.5)! + Offset(r.range(-0.2, 0.2) * s.hw, 0);
    c.drawPath(
      Path()..addPolygon([
        tip,
        mid,
        mid.translate(-1.4 * _u, 0),
        tip.translate(-1.0 * _u, 1.5 * _u),
      ], true),
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.35),
    );
    for (var k = 0; k < 6; k++) {
      final p = Offset.lerp(tip, mid, k / 6)!;
      if (fieldHash(k, s.seed) < 0.5) sparks.add(k < 2 ? 3 : 1, p.dx, p.dy);
    }
    sparks.add(3, tip.dx, tip.dy + 0.6 * _u);
    if (fieldHash(s.seed, 41) < 0.7) _glint(tip.dx, tip.dy + 0.6 * _u);
  }

  // ── The vent ─────────────────────────────────────────────────────────────

  /// The vent the floaters ride: a little cone of spatter standing in the
  /// lava under the open-air point, its mouth glowing, steam pouring up out
  /// of it.
  _Vent? _makeVent(double w) {
    for (final p in _spawns) {
      if (p.anchor != near || !p.aloft) continue;
      return _Vent(_spawnX(p), _h * 0.875, 26 * _u, 30 * _u, 1501);
    }
    return null;
  }

  List<Offset> _ventOutline(_Vent v) {
    final r = FieldRandom(v.seed);
    final mouth = v.base - v.h;
    return [
      Offset(v.x - v.hw * 1.2, v.base + 2 * _u),
      Offset(v.x - v.hw * 0.75, v.base - v.h * 0.35),
      Offset(v.x - v.hw * 0.45, mouth + r.range(0, 3) * _u),
      Offset(v.x - v.hw * 0.28, mouth - 1.5 * _u),
      Offset(v.x - v.hw * 0.1, mouth + 1.5 * _u),
      Offset(v.x + v.hw * 0.12, mouth + 1.2 * _u),
      Offset(v.x + v.hw * 0.3, mouth - 2 * _u),
      Offset(v.x + v.hw * 0.5, mouth + r.range(0, 3) * _u),
      Offset(v.x + v.hw * 0.8, v.base - v.h * 0.4),
      Offset(v.x + v.hw * 1.2, v.base + 2 * _u),
    ];
  }

  void _paintVent(Canvas c, _Vent v) {
    final body = Path()..addPolygon(_ventOutline(v), true);
    c.drawPath(
      body,
      Paint()
        ..shader = Gradient.linear(
          Offset(v.x - v.hw, 0),
          Offset(v.x + v.hw, 0),
          [fieldMap(0, 0.1, 0.4), fieldMap(0, 0, 0.6), fieldMap(0, 0, 0.82)],
          const [0.0, 0.45, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(body);
    // Spatter: lumps of it welded on in rings, lit on top.
    final r = FieldRandom(v.seed + 3);
    final lumps = Path(), tops = Path();
    for (var k = 0; k < 22; k++) {
      final f = r.next();
      final y = v.base - v.h * f;
      final half = v.hw * (1.2 - 0.85 * f);
      final x = v.x + r.range(-1, 1) * half;
      final rad = r.range(2.2, 4.2) * _u;
      lumps.addOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: rad * 2.2,
          height: rad * 1.4,
        ),
      );
      tops.addOval(
        Rect.fromCenter(
          center: Offset(x, y - rad * 0.3),
          width: rad * 1.3,
          height: rad * 0.6,
        ),
      );
    }
    c
      ..drawPath(lumps, Paint()..color = fieldMap(0, 0, 0.75, 0.8))
      ..drawPath(tops, Paint()..color = fieldMap(0, 0.25, 0.25, 0.7))
      ..restore();
  }

  void _paintVentLava(Canvas c, _Vent v) {
    final mouth = Offset(v.x, v.base - v.h + 1.5 * _u);
    c
      ..save()
      ..translate(mouth.dx, mouth.dy)
      ..scale(2.6, 1)
      ..drawCircle(
        Offset.zero,
        3.2 * _u,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 3.2 * _u, [
            _heat(1),
            _heat(0.6, a: 0.8),
          ]),
      )
      ..restore();
    _paintSpireLava(c, _Spire(v.x, v.base, v.hw, v.h, v.seed, 0));
  }

  void _paintVentGlow(Canvas c, _Vent v) {
    final body = Path()..addPolygon(_ventOutline(v), true);
    c
      ..save()
      ..clipPath(body)
      ..drawRect(
        Rect.fromLTRB(
          v.x - v.hw * 1.3,
          v.base - v.h,
          v.x + v.hw * 1.3,
          v.base + 3 * _u,
        ),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, v.base - v.h),
            Offset(0, v.base),
            [
              fieldMap(0.8, 0, 0, 0.45),
              fieldMap(0.2, 0, 0, 0.1),
              fieldMap(0.9, 0, 0, 0.7),
            ],
            const [0.0, 0.5, 1.0],
          ),
      )
      ..restore();
  }

  void _paintVentLight(Canvas c, _Vent v, GrainBatch sparks) {
    final pts = _ventOutline(v);
    for (var k = 1; k < pts.length - 1; k++) {
      if (fieldHash(k, v.seed) < 0.6) {
        sparks.add(2, pts[k].dx, pts[k].dy + 0.8 * _u);
      }
    }
  }

  // ── Dead trees ───────────────────────────────────────────────────────────

  /// A dead tree on each of the tree rocks: burnt to a snag, its limbs
  /// broken off short.
  List<_Snag> _makeSnags(List<_Shelf> shelves) {
    final w = _widths[near] ?? _worldWidth;
    final out = <_Snag>[];
    var k = 0;
    for (final (fx, _, _) in _treeRocks) {
      final x = fx * w;
      final at = _shelfAt(near, x);
      if (at == null) continue;
      final (s, lx) = at;
      final t = _Snag(
        x + _u * 4 * (k.isEven ? -1 : 1),
        _sStand(s, lx) + 2 * _u,
        _h * (k == 0 ? 0.6 : 0.48),
        2100 + k,
      );
      _shapeSnag(t);
      out.add(t);
      k++;
    }
    return out;
  }

  void _shapeSnag(_Snag t) {
    final r = FieldRandom(t.seed);
    final h = t.h;
    final lean = r.range(-0.06, 0.06);
    final bow = r.range(0.025, 0.05) * (r.next() < 0.5 ? -1 : 1);
    final wb = h * r.range(0.1, 0.12);
    final wt = h * 0.012;
    Offset spine(double f) => Offset(
      t.x +
          lean * h * f +
          bow * h * math.sin(f * math.pi * 1.2) +
          h * 0.008 * math.sin(f * 9 + t.seed),
      t.base - f * h,
    );
    // Thick at its foot, flaring a little into the rock, thinning to a
    // snapped point.
    double half(double f) =>
        wt +
        (wb / 2 - wt) * math.pow(1 - f, 1.5) +
        wb * 0.3 * math.pow(math.max(0.0, 1 - f / 0.07), 2);
    t
      ..spine = spine
      ..half = half
      ..wb = wb;
    final left = <Offset>[], right = <Offset>[];
    const n = 28;
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final p = spine(f);
      final hw = half(f) * (1 + 0.08 * fieldNoise(f * 14, t.seed + 1));
      left.add(Offset(p.dx - hw, p.dy));
      right.add(Offset(p.dx + hw, p.dy));
    }
    // Snapped off at the top, jagged.
    final top = spine(1);
    t.outline = [
      ...left,
      top.translate(-wt * 0.6, -h * 0.02),
      top.translate(wt * 0.2, h * 0.01),
      top.translate(wt * 0.9, -h * 0.035),
      ...right.reversed,
    ];
    // Limbs reaching up and out, bending upward as they go, each tapering
    // to a point; some forked once; a stub or two snapped short.
    final limbs = <List<Offset>>[];
    var side = r.next() < 0.5 ? -1.0 : 1.0;
    final m = 4 + (r.next() * 2).floor();
    for (var k = 0; k < m; k++) {
      final f = 0.32 + 0.52 * (k + r.range(0, 0.7)) / m;
      final from = spine(f);
      final wr = half(f) * r.range(0.6, 0.8);
      if (fieldHash(k, t.seed + 3) < 0.25) {
        // A stub, broken off blunt.
        final len = h * r.range(0.03, 0.05);
        final to = from + Offset(side * len, -len * 0.4);
        limbs.add([
          from.translate(0, -wr),
          to.translate(0, -wr * 0.6),
          to.translate(side * wr * 0.2, wr * 0.3),
          from.translate(0, wr),
        ]);
        side = -side;
        continue;
      }
      final len = h * r.range(0.2, 0.34) * (1.2 - f * 0.5);
      final a = r.range(0.5, 0.85);
      final mid =
          from +
          Offset(side * math.sin(a) * len * 0.5, -math.cos(a) * len * 0.45);
      final to =
          mid +
          Offset(
            side * math.sin(a * 0.75) * len * 0.5,
            -math.cos(a * 0.75) * len * 0.5,
          );
      limbs.add(_taper(from, mid, to, wr));
      if (r.next() < 0.65) {
        final q = Offset.lerp(mid, to, 0.25)!;
        final tl = len * r.range(0.25, 0.42);
        final twig = q + Offset(side * tl * 0.55, -tl * 0.8);
        limbs.add(
          _taper(
            q,
            Offset.lerp(q, twig, 0.5)! + Offset(-side * tl * 0.08, 0),
            twig,
            wr * 0.42,
          ),
        );
      }
      side = -side;
    }
    t.limbs = limbs;
    // Cracks the fire left, still smouldering low down.
    t.embers = [
      for (var k = 0; k < 3; k++)
        (r.range(0.04, 0.3), r.range(-0.6, 0.6), r.range(0.04, 0.08)),
    ];
    var reach = wb * 2;
    var high = t.base;
    for (final l in limbs) {
      for (final p in l) {
        reach = math.max(reach, (p.dx - t.x).abs());
        high = math.min(high, p.dy);
      }
    }
    t
      ..reach = reach + 10 * _u
      ..top = math.min(high, top.dy - h * 0.04);
  }

  /// A limb as a filled shape: from [from] (half width [w]) bending through
  /// [mid] to a point at [to].
  List<Offset> _taper(Offset from, Offset mid, Offset to, double w) {
    final left = <Offset>[], right = <Offset>[];
    const n = 8;
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final a = Offset.lerp(from, mid, f)!, b = Offset.lerp(mid, to, f)!;
      final p = Offset.lerp(a, b, f)!;
      final d = b - a;
      final len = d.distance;
      final nrm = len > 0 ? Offset(-d.dy, d.dx) / len : const Offset(1, 0);
      final hw = w * math.pow(1 - f, 0.9) + 0.25 * _u;
      left.add(p + nrm * hw);
      right.add(p - nrm * hw);
    }
    return [...left, ...right.reversed];
  }

  List<FieldSheet> _snagSheets(_Snag t) {
    final b = Rect.fromLTRB(
      t.x - t.reach,
      math.max(-2 * _u, t.top - 10 * _u),
      t.x + t.reach,
      t.base + 8 * _u,
    );
    return [
      FieldSheet(bounds: b, grade: _gRock, paint: (c) => _paintSnag(c, t)),
      FieldSheet(
        bounds: b,
        grade: _gLava,
        paint: (c) => _paintSnagEmbers(c, t),
      ),
      FieldSheet(
        bounds: b,
        light: true,
        paint: (c) => _sinking(near, () => _paintSnagLight(c, t)),
      ),
    ];
  }

  /// A snag: charred wood, its trunk darkest at its edges, split along its
  /// length, its limbs in the same black.
  void _paintSnag(Canvas c, _Snag t) {
    for (final l in t.limbs) {
      c.drawPath(
        Path()..addPolygon(l, true),
        Paint()..color = fieldMap(0, 0.02, 0.62),
      );
    }
    final body = Path()..addPolygon(t.outline, true);
    c.drawPath(
      body,
      Paint()
        ..shader = Gradient.linear(
          Offset(t.x - t.wb, 0),
          Offset(t.x + t.wb, 0),
          [
            fieldMap(0, 0, 0.72),
            fieldMap(0, 0.06, 0.4),
            fieldMap(0, 0.02, 0.5),
            fieldMap(0, 0, 0.8),
          ],
          const [0.0, 0.35, 0.6, 1.0],
        ),
    );
    c
      ..save()
      ..clipPath(body);
    // Splits along the grain, and the checking of charred wood.
    final r = FieldRandom(t.seed + 5);
    for (var k = 0; k < 6; k++) {
      final q = r.range(-0.7, 0.7);
      final f0 = r.range(0.0, 0.6), f1 = f0 + r.range(0.15, 0.4);
      final left = <Offset>[], right = <Offset>[];
      for (var j = 0; j <= 8; j++) {
        final f = f0 + (f1 - f0) * j / 8;
        final p = t.spine(f);
        final hw = t.half(f);
        final gw = (0.5 + 0.9 * math.sin(j / 8 * math.pi)) * _u;
        left.add(Offset(p.dx + q * hw - gw, p.dy));
        right.add(Offset(p.dx + q * hw + gw, p.dy));
      }
      c.drawPath(
        Path()..addPolygon([...left, ...right.reversed], true),
        Paint()..color = fieldMap(0, 0, 0.92, 0.75),
      );
    }
    final checks = GrainBatch(2);
    for (var i = 0; i < (t.wb * t.h * 0.4 / (12 * _u * _u)).round(); i++) {
      final f = fieldHash(i, t.seed + 31) * 0.95;
      final p = t.spine(f);
      checks.add(
        fieldHash(i, t.seed + 41) < 0.65 ? 0 : 1,
        p.dx + (fieldHash(i, t.seed + 37) * 2 - 1) * t.half(f),
        p.dy,
      );
    }
    checks
      ..draw(c, 0, 1.5 * _u, fieldMap(0, 0, 0.95, 0.6))
      ..draw(c, 1, 1.2 * _u, fieldMap(0, 0.24, 0.2, 0.5));
    c.restore();
  }

  void _paintSnagEmbers(Canvas c, _Snag t) {
    for (final (f, q, len) in t.embers) {
      final p = t.spine(f);
      final x = p.dx + q * t.half(f);
      final l = t.h * len;
      final wd = 1.1 * _u;
      c.drawPath(
        Path()..addPolygon([
          Offset(x, p.dy - l * 0.5),
          Offset(x + wd, p.dy),
          Offset(x, p.dy + l * 0.5),
          Offset(x - wd, p.dy),
        ], true),
        Paint()..color = _heat(0.55),
      );
    }
  }

  void _paintSnagLight(Canvas c, _Snag t) {
    final sparks = GrainBatch(_sparkAlpha.length);
    for (var i = 0; i < 60; i++) {
      final f = i / 60;
      if (fieldHash(i, t.seed) < 0.4) continue;
      final p = t.spine(f);
      final side = fieldHash(i + 3, t.seed) < 0.5 ? -1.0 : 1.0;
      sparks.add(f > 0.6 ? 2 : 1, p.dx + side * (t.half(f) - 0.8 * _u), p.dy);
    }
    for (final l in t.limbs) {
      final n = l.length ~/ 2;
      for (var k = 1; k < n; k++) {
        if (fieldHash(k, l.first.dx.round()) > 0.55) continue;
        sparks.add(1, l[k].dx, l[k].dy);
      }
      _glint(l[n - 1].dx, l[n - 1].dy);
    }
    _drawSparks(c, sparks, 1.4);
  }

  // ── Fore: black rock ─────────────────────────────────────────────────────

  /// Black boulders at the very front, far apart.
  List<_Spire> _foreRocks(double w) {
    final r = FieldRandom(919);
    final out = <_Spire>[];
    var x = r.range(420, 620) * _u;
    var i = 0;
    while (x < w - 60 * _u) {
      final hw = r.range(55, 110) * _u;
      out.add(
        _Spire(
          x,
          _h + 10 * _u,
          hw,
          hw * r.range(0.45, 0.75),
          1600 + i++,
          0,
          round: true,
        ),
      );
      x += r.range(700, 1300) * _u;
    }
    return out;
  }

  /// Dry grass in the cracks of the black rock at the front.
  _Blades _foreTufts(List<_Spire> rocks) {
    final b = _BladeBuilder();
    final r = FieldRandom(727);
    for (final s in rocks) {
      final pts = _spireOutline(s);
      for (var k = 0; k < 3; k++) {
        final p = pts[1 + (r.next() * (pts.length - 3)).floor()];
        final n = 5 + (r.next() * 6).floor();
        for (var j = 0; j < n; j++) {
          b.add(
            x: p.dx + r.range(-5, 5) * _u,
            base: p.dy + 3 * _u,
            height: r.range(10, 26) * _u,
            lean: r.range(-0.3, 0.3),
            phase: r.range(0, math.pi * 2),
            depth: 1,
            row: 0,
          );
        }
      }
    }
    return b.done();
  }

  // ── Grass ────────────────────────────────────────────────────────────────

  /// Dry grass on the near shelves, in tufts with bare rock between: a
  /// fringe along each back, blades across the top, those rooted below a
  /// standing creature's feet kept short and drawn over it (row 4).
  _Blades _shelfGrass(List<_Shelf> shelves) {
    final b = _BladeBuilder();
    final r = FieldRandom(636);
    for (final s in shelves) {
      final sparse = s.basalt ? 0.35 : 0.8;
      final x0 = s.cx - s.hw * 0.95, x1 = s.cx + s.hw * 0.95;
      for (var x = x0; x < x1; x += 2.4 * _u) {
        if (fieldLoopNoise(x, 26 * _u, s.seed, 0) < (s.basalt ? 0.25 : 0.0)) {
          continue;
        }
        b.add(
          x: x + r.range(-0.6, 0.6) * _u,
          base: _sBack(s, x) + 1.2 * _u,
          height: r.range(5, 12) * _u * (0.5 + 0.5 * _sPinch(s, x)),
          lean: r.range(-0.2, 0.35),
          phase: r.range(0, math.pi * 2),
          depth: 0,
          row: 0,
        );
      }
      final n = (s.hw * 2 * s.plate * sparse / (9 * _u * _u)).round();
      for (var j = 0; j < n; j++) {
        final x = s.cx + (r.next() * 2 - 1) * s.hw * 0.92;
        if (fieldLoopNoise(x, 26 * _u, s.seed, 0) < (s.basalt ? 0.1 : -0.15)) {
          continue;
        }
        final back = _sBack(s, x), front = _sFront(s, x);
        final d = r.next();
        final y = back + 1.5 * _u + d * (front - back - 1.5 * _u);
        final feet = y > _sStand(s, x) + 0.5 * _u;
        b.add(
          x: x,
          base: y,
          height: (feet ? r.range(3, 6) : r.range(5, 11)) * _u,
          lean: r.range(-0.2, 0.35),
          phase: r.range(0, math.pi * 2),
          depth: d,
          row: feet ? 4 : (d < 0.3 ? 1 : (d < 0.6 ? 2 : 3)),
        );
      }
    }
    return b.done();
  }

  /// The grass on a near shelf a finger at [x], [y] is in, if any.
  double? _inGrass(double x, double y) {
    final at = _shelfAt(near, x, reach: 0.97);
    if (at == null) return null;
    final (s, lx) = at;
    final back = _sBack(s, lx);
    if (y < back - 30 * _u || y > _sFront(s, lx) + 10 * _u) return null;
    return back;
  }

  /// Whether a finger at [x], [y] on the near layer is on open lava.
  bool _onLava(double x, double y) {
    if (y < _h * (_nearLavaTop + 0.01)) return false;
    for (final s in _shelves[near] ?? const <_Shelf>[]) {
      final d = _loopDelta(x, s.cx, near);
      if (d.abs() < s.hw + s.flare && y < _sLava(s) + 1 * _u) return false;
    }
    for (final sp in _spires[near] ?? const <_Spire>[]) {
      final d = _loopDelta(x, sp.x, near);
      if (d.abs() < sp.hw && y < sp.base + 1 * _u && y > sp.base - sp.h) {
        return false;
      }
    }
    final v = _vent;
    if (v != null &&
        _loopDelta(x, v.x, near).abs() < v.hw &&
        y < v.base &&
        y > v.base - v.h) {
      return false;
    }
    return true;
  }

  // ── Embers ───────────────────────────────────────────────────────────────

  /// Embers rising off [layer]'s lava, where it is open or cracked.
  _Embers _makeEmbers(SceneLayer layer, double w) {
    final r = FieldRandom(layer == mid ? 941 : 961);
    final (top, bottom) = _lavaBand(layer);
    final n = (w / ((layer == mid ? 9 : 7) * _u)).round();
    final x = Float32List(n),
        y = Float32List(n),
        phase = Float32List(n),
        rise = Float32List(n),
        life = Float32List(n),
        wob = Float32List(n);
    var i = 0;
    var tries = 0;
    while (i < n && tries++ < n * 8) {
      final px = r.next() * w;
      final py =
          top + 4 * _u + r.next() * (math.min(bottom, _h) - top - 6 * _u);
      // Most of them off the open lava; a few off cracks anywhere.
      final (open, warm) = _lavaAt(layer, px, py);
      if (r.next() > 0.08 + 0.92 * math.max(open, warm * 0.5)) continue;
      if (layer == near && !_onLava(px, py)) continue;
      x[i] = px;
      y[i] = py;
      phase[i] = r.next();
      rise[i] = r.range(40, 140) * _u * (layer == mid ? 0.6 : 1);
      life[i] = r.range(1.6, 3.6);
      wob[i] = r.range(2, 7) * _u;
      i++;
    }
    return _Embers(
      Float32List.sublistView(x, 0, i),
      Float32List.sublistView(y, 0, i),
      Float32List.sublistView(phase, 0, i),
      Float32List.sublistView(rise, 0, i),
      Float32List.sublistView(life, 0, i),
      Float32List.sublistView(wob, 0, i),
    );
  }

  final GrainBatch _emberBatch = GrainBatch(4);

  /// Embers: each rises off the lava, swaying, cooling from yellow through
  /// orange to a dull red as it goes, and out — then a while later another
  /// from the same place.
  void _paintEmbers(Canvas canvas, FieldView view, SceneLayer layer) {
    final e = _embers[layer];
    if (e == null) return;
    final t = view.time;
    _emberBatch.clear();
    var any = false;
    final shifts = _shiftsFor(layer, view, 20);
    // By day fewer of them show.
    final shown = math.min(1.0, 0.45 + 0.55 * _night + (_erupting ? 0.35 : 0));
    for (var i = 0; i < e.n; i++) {
      if (fieldHash(i, 967) > shown) continue;
      final period = e.life[i] * 2.2;
      final age = (t + e.phase[i] * period) % period;
      if (age > e.life[i]) continue;
      final f = age / e.life[i];
      var x = e.x[i] + e.wob[i] * math.sin(t * 1.7 + i) * f + f * 10 * _u;
      for (final s in shifts) {
        if (x + s >= view.left - 10 && x + s <= view.right + 10) {
          x += s;
          break;
        }
      }
      if (x < view.left - 10 || x > view.right + 10) continue;
      final y = e.y[i] - e.rise[i] * (1 - math.pow(1 - f, 1.6));
      final b = f < 0.18 ? 0 : (f < 0.5 ? 1 : (f < 0.8 ? 2 : 3));
      _emberBatch.add(b, x, y);
      any = true;
    }
    if (!any) return;
    final k = layer == mid ? 0.75 : 1.0;
    final cols = [
      _lavaHot,
      Color.lerp(_lavaOrange, _lavaHot, 0.3)!,
      _lavaOrange,
      _glowDeep,
    ];
    for (var b = 0; b < 4; b++) {
      if (b < 2 && layer == near) {
        _emberBatch.draw(
          canvas,
          b,
          5 * _u,
          cols[b].withValues(alpha: 0.16 + 0.1 * _night),
        );
      }
      _emberBatch.draw(
        canvas,
        b,
        (b < 2 ? 1.9 : 1.6) * _u * k,
        cols[b].withValues(alpha: b == 3 ? 0.55 : 0.95),
      );
    }
  }

  // ── The vent's steam ─────────────────────────────────────────────────────

  /// Where the vent's steam column runs at [f] of its height (0 the vent's
  /// mouth, 1 its top): its middle and half its width.
  (Offset, double) _steamAt(_Vent v, double f) {
    final top = v.base - v.h;
    final rise = (top - _h * 0.3) * f;
    return (
      Offset(v.x + 12 * _u * f * f, top - rise),
      (3 + 30 * math.sqrt(f)) * _u,
    );
  }

  /// The column of steam over the vent, for an ash-graded sheet: thick and
  /// pale where it leaves the mouth, thinning upward, its edges billowing.
  Path _steamColumn(_Vent v) {
    final left = <Offset>[], right = <Offset>[];
    const n = 24;
    for (var k = 0; k <= n; k++) {
      final f = k / n;
      final (p, half) = _steamAt(v, f);
      final bulge = 1 + 0.22 * fieldNoise(f * 9, v.seed + 7).abs();
      left.add(p.translate(-half * bulge, 0));
      right.add(
        p.translate(half * (1 + 0.22 * fieldNoise(f * 9, v.seed + 9).abs()), 0),
      );
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  /// The steam over the vent, for an ash-graded sheet: soft billows
  /// climbing out of the mouth, thick and pale low down, thinning and
  /// spreading as they rise.
  void _paintSteamBody(Canvas c, _Vent v) {
    final r = FieldRandom(v.seed + 21);
    for (var k = 0; k < 30; k++) {
      final f = math.pow((k + r.range(0.0, 0.9)) / 30, 1.25).toDouble();
      final (p, half) = _steamAt(v, f);
      final at = p.translate(r.range(-0.45, 0.45) * half, 0);
      final rx = half * r.range(0.9, 1.35);
      final ry = rx * r.range(0.6, 0.85);
      final a = 0.55 * (1 - f * 0.8);
      c
        ..save()
        ..translate(at.dx, at.dy)
        ..scale(rx / ry, 1)
        ..drawCircle(
          Offset.zero,
          ry,
          Paint()
            ..shader = Gradient.radial(
              Offset(-ry * 0.15, -ry * 0.3),
              ry,
              [
                fieldMap(0.1 * f, 0.6, 0, a),
                fieldMap(0.15 * f, 0.4, 0, a * 0.6),
                fieldMap(0.2 * f, 0.3, 0, 0),
              ],
              const [0.0, 0.55, 1.0],
            ),
        )
        ..restore();
    }
  }

  /// The vent's fire up the underside of its steam, for a glow sheet.
  void _paintSteamGlow(Canvas c, _Vent v) {
    final (base, _) = _steamAt(v, 0);
    c
      ..save()
      ..clipPath(_steamColumn(v))
      ..drawCircle(
        base,
        60 * _u,
        Paint()
          ..shader = Gradient.radial(base, 60 * _u, [
            fieldMap(1, 0, 0, 0.8),
            fieldMap(0.5, 0, 0, 0),
          ]),
      )
      ..restore();
  }

  final GrainBatch _steamBatch = GrainBatch(3);

  /// Steam pouring up out of the vent: grains climbing, spreading and
  /// thinning, lit by the vent's fire where they leave it.
  void _paintSteam(Canvas canvas, FieldView view) {
    final v = _vent;
    if (v == null) return;
    final t = view.time;
    _steamBatch.clear();
    var any = false;
    final top = v.base - v.h;
    final height = top - _h * 0.3;
    for (final shift in _shiftsFor(near, view, 80 * _u)) {
      final cx = v.x + shift;
      if (cx + 80 * _u < view.left || cx - 80 * _u > view.right) continue;
      for (var i = 0; i < 240; i++) {
        final life = 3.5 + 2.5 * fieldHash(i, 1511);
        final f = (t / life + fieldHash(i, 1513)) % 1.0;
        final keep = math.min(1.0, f * 20) * math.min(1.0, (1 - f) * 2.5);
        if (fieldHash(i, 1515) > keep) continue;
        final rise = height * (1 - math.pow(1 - f, 1.5));
        final rad = (3 + 26 * math.sqrt(f)) * _u;
        final a = fieldHash(i, 1517) * math.pi * 2;
        final d = math.sqrt(fieldHash(i, 1519));
        final x =
            cx +
            math.cos(a) * d * rad +
            math.sin(t * 0.8 + i) * rad * 0.2 +
            f * 12 * _u;
        final y = top - rise + math.sin(a) * d * rad * 0.4;
        _steamBatch.add(f < 0.12 ? 0 : (math.sin(a) < 0 ? 1 : 2), x, y);
        any = true;
      }
    }
    if (!any) return;
    final l = _light;
    final pale = Color.lerp(l.cloudTop, const Color(0xFFF2E6DE), 0.55)!;
    final dim = Color.lerp(l.cloudBottom, pale, 0.5)!;
    final warm = Color.lerp(pale, _glowWarm, 0.55)!;
    _steamBatch
      ..draw(canvas, 0, 2.0 * _u, warm.withValues(alpha: 0.45))
      ..draw(canvas, 1, 1.8 * _u, pale.withValues(alpha: 0.28))
      ..draw(canvas, 2, 1.8 * _u, dim.withValues(alpha: 0.22));
  }

  // ── Touching the lava, and the ash ───────────────────────────────────────

  /// Where the lava has broken lately — under a finger, or bubbling up of
  /// its own — (x, y, when, how hard), glowing as it heals over.
  final List<(double, double, double, double)> _wakes = [];
  double _routed = -1;
  double _lastWake = -1;
  int _bloopSlot = -1;

  final _Drift _sparks = _Drift(280);
  final _Drift _ash = _Drift(380);
  final GrainBatch _sparkBatch = GrainBatch(3);
  final GrainBatch _ashBatch = GrainBatch(3);

  /// Sends this frame's new fingers on the near layer to what is under
  /// them: a shelf's ash lifts; the lava's crust breaks, glowing, and
  /// throws sparks.
  void _route(FieldView view) {
    var newest = _routed;
    for (final t in view.touches) {
      if (t.time <= _routed) continue;
      if (t.time > newest) newest = t.time;
      final moved = math.sqrt(t.dx * t.dx + t.dy * t.dy);
      final tap = moved < 0.5;
      final n = view.local(t.x, t.y);
      final speed = moved / view.zoom;
      final grass = _inGrass(n.dx, n.dy);
      if (grass != null) {
        _raiseAsh(n.dx, math.max(n.dy, grass), t.dx.sign, speed, tap: tap);
        continue;
      }
      if (!_onLava(n.dx, n.dy)) continue;
      if (tap) {
        _wakes.add((n.dx, n.dy, t.time, 1));
        _spit(n.dx, n.dy, 0, 0, count: 24);
      } else if (t.time - _lastWake > 0.09) {
        _lastWake = t.time;
        _wakes.add((
          n.dx,
          n.dy,
          t.time,
          math.min(0.75, 0.4 + speed / (20 * _u)),
        ));
        _spit(n.dx, n.dy, t.dx.sign, speed, count: 4);
      }
    }
    _routed = newest;
    _wakes.removeWhere((w) => view.time - w.$3 > 2.2 || w.$3 > view.time);
    if (_wakes.length > 8) _wakes.removeRange(0, _wakes.length - 8);
  }

  /// Now and then the lava in view bubbles up and spits.
  void _bloop(FieldView view) {
    final slot = (view.time / (_erupting ? 0.32 : 0.55)).floor();
    if (slot == _bloopSlot) return;
    _bloopSlot = slot;
    if (fieldHash(slot, 1777) > (_erupting ? 0.75 : 0.5)) return;
    final x = view.left + fieldHash(slot, 1779) * (view.right - view.left);
    final y = _h * (_nearLavaTop + 0.03 + fieldHash(slot, 1781) * 0.2);
    if (!_onLava(x, y) || _lavaAt(near, x, y).$1 < 0.25) return;
    _wakes.add((x, y, view.time, 0.5));
    _spit(x, y, 0, 0, count: 5 + (fieldHash(slot, 1783) * 8).floor());
  }

  /// Molten drops thrown up out of broken lava, falling back cooling.
  void _spit(
    double x,
    double y,
    double dir,
    double speed, {
    required int count,
  }) {
    final d = _sparks;
    for (var k = 0; k < count; k++) {
      final a = math.pi * (0.15 + 0.7 * d.rand());
      final v = (40 + d.rand() * 110) * _u;
      d.spawn(
        x: x + (d.rand() - 0.5) * 6 * _u,
        y: y - d.rand() * 2 * _u,
        vx: math.cos(a) * v * 0.6 + dir * speed * 3,
        vy: -math.sin(a) * v,
        life: 0.55 + d.rand() * 0.6,
      );
    }
  }

  /// A finger through the ash on a shelf: it lifts and trails after the
  /// finger, curling as it slows; a tap throws up a low lopsided puff.
  void _raiseAsh(
    double x,
    double y,
    double dir,
    double speed, {
    required bool tap,
  }) {
    final d = _ash;
    if (tap) {
      final lean = d.rand() < 0.5 ? -1.0 : 1.0;
      for (var k = 0; k < 46; k++) {
        final a = -math.pi * (0.05 + 0.9 * d.rand());
        final out = (8 + 70 * math.pow(d.rand(), 1.7)) * _u;
        final bias = 0.45 + 0.55 * (math.cos(a) * lean * 0.5 + 0.5);
        d.spawn(
          x: x + (d.rand() - 0.5) * 12 * _u,
          y: y - d.rand() * 4 * _u,
          vx: math.cos(a) * out * bias,
          vy: math.sin(a) * out * bias * 0.55 - 8 * _u,
          life: 1.3 + d.rand() * 1.8,
          spin: (d.rand() - 0.5) * 2.4,
        );
      }
      return;
    }
    final pace = math.min(1.0, speed / (5 * _u));
    final n = 1 + (pace * 4).round();
    for (var k = 0; k < n; k++) {
      d.spawn(
        x: x + (d.rand() - 0.5) * 14 * _u,
        y: y - d.rand() * 5 * _u,
        vx: dir * (24 + d.rand() * 60) * _u * pace + (d.rand() - 0.5) * 18 * _u,
        vy: -(10 + d.rand() * 30) * _u,
        life: 1.4 + d.rand() * 1.6,
        spin: (d.rand() < 0.5 ? -1 : 1) * (0.4 + d.rand()),
      );
    }
  }

  /// The broken lava: each break a glow on the lava, brightest as it goes,
  /// spreading a little and crusting over.
  void _paintWakes(Canvas canvas, FieldView view) {
    if (_wakes.isEmpty) return;
    final now = view.time;
    for (final (wx, wy, t0, strength) in _wakes) {
      final age = now - t0;
      if (age < 0) continue;
      final life = 1.1 + 1.1 * strength;
      if (age > life) continue;
      final f = age / life;
      // Bright as it breaks, crusting over from the edge in.
      final fade =
          math.min(1.0, age * 14) *
          math.pow(1 - f, 1.5).toDouble() *
          (0.6 + 0.4 * strength);
      final depth = (wy - _h * 0.575) / (_h * 0.425);
      final r = (9 + 13 * strength) * (1 - 0.35 * f) * _u * (0.6 + 0.6 * depth);
      canvas
        ..save()
        ..translate(wx, wy)
        ..scale(1, 1 / 2.4)
        ..drawCircle(
          Offset.zero,
          r * 1.3,
          Paint()
            ..shader = Gradient.radial(
              Offset.zero,
              r * 1.3,
              [
                Color.lerp(
                  _lavaHot,
                  const Color(0xFFFFF4C8),
                  0.4,
                )!.withValues(alpha: 0.95 * fade),
                _lavaHot.withValues(alpha: 0.8 * fade),
                _lavaOrange.withValues(alpha: 0.45 * fade),
                _glowDeep.withValues(alpha: 0),
              ],
              const [0.0, 0.18, 0.5, 1.0],
            ),
        )
        ..restore();
    }
  }

  /// Just the cores of the hottest two shades of [_sparkBatch]: for
  /// grains riding on lava, whose own light is round them already.
  void _drawSparkCores(Canvas canvas, double k) {
    _sparkBatch
      ..draw(canvas, 0, 2.0 * _u * k, _lavaHot.withValues(alpha: 0.95))
      ..draw(canvas, 1, 1.7 * _u * k, _lavaOrange.withValues(alpha: 0.95));
  }

  void _drawSparkGrains(Canvas canvas, double k) {
    final cols = [_lavaHot, _lavaOrange, _glowDeep];
    _sparkBatch.draw(canvas, 0, 4.4 * _u * k, _lavaHot.withValues(alpha: 0.2));
    for (var b = 0; b < 3; b++) {
      _sparkBatch.draw(
        canvas,
        b,
        (b == 0 ? 2.0 : 1.7) * _u * k,
        cols[b].withValues(alpha: b == 2 ? 0.7 : 0.95),
      );
    }
  }

  void _paintSparks(Canvas canvas, FieldView view) {
    final d = _sparks;
    final dt = d.clock < 0 ? 0.0 : (view.time - d.clock).clamp(0.0, 0.1);
    d.clock = view.time;
    if (!d.any) return;
    d.step(dt, gravity: 280 * _u, drag: 0.6);
    _sparkBatch.clear();
    var any = false;
    for (var i = 0; i < d.cap; i++) {
      if (d.life[i] <= 0) continue;
      final f = d.age[i] / d.life[i];
      _sparkBatch.add(f < 0.3 ? 0 : (f < 0.7 ? 1 : 2), d.x[i], d.y[i]);
      any = true;
    }
    if (!any) return;
    _drawSparkGrains(canvas, 1);
  }

  void _paintAsh(Canvas canvas, FieldView view) {
    final d = _ash;
    final dt = d.clock < 0 ? 0.0 : (view.time - d.clock).clamp(0.0, 0.1);
    d.clock = view.time;
    if (!d.any) return;
    final (wind, _) = _wind(
      (view.left + view.right) / 2,
      view.time,
      _nearWidth,
    );
    d.step(dt, drag: 1.5, lift: 6 * _u, windX: wind * 34 * _u);
    _ashBatch.clear();
    var any = false;
    for (var i = 0; i < d.cap; i++) {
      if (d.life[i] <= 0) continue;
      final f = d.age[i] / d.life[i];
      final fade = math.min(1.0, f * 8) * (1 - f);
      final level = (fade * 2.99).floor();
      if (level <= 0) continue;
      _ashBatch.add(level - 1, d.x[i], d.y[i]);
      any = true;
    }
    if (!any) return;
    // The ash's own grey, lifted and lit: in the air it catches the light
    // the ground under it does not.
    final l = _light;
    final grey = _sil(_albedo[_gAshTop]!, l);
    final col = Color.lerp(grey, Color.lerp(l.mote, l.rim, 0.5), 0.25)!;
    for (var lv = 0; lv < 2; lv++) {
      _ashBatch
        ..draw(canvas, lv, 10 * _u, col.withValues(alpha: 0.06 * (lv + 1)))
        ..draw(canvas, lv, 3 * _u, col.withValues(alpha: 0.22 * (lv + 1)));
    }
  }

  // ── The eruption's flow ──────────────────────────────────────────────────

  /// When an eruption's lava flow reaches each layer, and how long its
  /// front takes to cross it (field seconds): down the cone's face, then
  /// over the hills and across the lake, then over the near field toward
  /// the viewer. Once there it stays for the visit.
  static const _flowTimes = <SceneLayer, (double, double)>{
    far: (5.0, 15.0),
    mid: (18.0, 18.0),
    near: (34.0, 30.0),
  };

  /// Where the flow runs on the mid and near layers, chosen as it reaches
  /// each (see [_chooseFlowX]): where it comes in — under the cone, as the
  /// eye has followed it — and the open lava it bends toward as it comes.
  final Map<SceneLayer, double> _flowFrom = {};
  final Map<SceneLayer, double> _flowX = {};

  /// The last view each layer was drawn through, so one layer can line up
  /// with another.
  final Map<SceneLayer, FieldView> _seen = {};

  /// How far the flow's front has come across [layer] at [t] (0 to 1,
  /// slowing as it spreads), or null before it reaches it.
  double? _flowFront(SceneLayer layer, double t) {
    if (!_erupting) return null;
    final (start, dur) = _flowTimes[layer]!;
    if (t < start) return null;
    final f = ((t - start) / dur).clamp(0.0, 1.0);
    return 1 - math.pow(1 - f, 1.5).toDouble();
  }

  /// Where on [layer], seen through [view], the burning cone is on the
  /// screen — or null if it is not in view.
  double? _underCone(FieldView view) {
    final fv = _seen[far];
    if (fv == null) return null;
    final p = _period(far);
    var cx = _coneX;
    if (p > 0) {
      cx += p * (((fv.left + fv.right) / 2 - cx) / p).roundToDouble();
    }
    final sx = (cx - fv.left) * fv.zoom;
    if (sx < 0 || sx > _screen.width) return null;
    return view.left + sx / view.zoom;
  }

  /// Where the flow comes onto [layer]: under the cone if the cone is in
  /// view, otherwise the middle of it — moved along to the nearest gap
  /// between the shelves, spires and the vent, so it never runs over a
  /// rock anything stands on.
  double _chooseFlowX(SceneLayer layer, FieldView view) {
    final want = _underCone(view) ?? (view.left + view.right) / 2;
    // The rock stands in front of the flow, so it may pass behind a spire;
    // but it keeps clear of the shelves, which stand where it would come.
    final clear = (layer == mid ? 4 : 10) * _u;
    final (top, _) = _lavaBand(layer);
    final w = _widths[layer] ?? _period(layer);
    bool blocked(double x) {
      for (final s in _shelves[layer] ?? const <_Shelf>[]) {
        if (_loopDelta(x, s.cx, layer).abs() < s.hw + s.flare + clear) {
          return true;
        }
      }
      // Its own course, not down a river already there.
      for (final river in layer == near ? _rivers : _midRivers) {
        final (cx, half) = _riverAt(river, layer, w, top + 20 * _u);
        if (_loopDelta(x, cx, layer).abs() < half * 2.5 + 14 * _u) return true;
      }
      return false;
    }

    final p = _period(layer);
    final span = view.right - view.left;
    double? found;
    for (var d = 0.0; d < 1500 * _u && found == null; d += 3 * _u) {
      for (final x in [want + d, want - d]) {
        if (blocked(x)) continue;
        // Well in view, if it can be.
        final inView =
            x > view.left + span * 0.03 && x < view.right - span * 0.03;
        if (inView || d > span) {
          found = x;
          break;
        }
      }
    }
    final x = found ?? want;
    return p > 0 ? x - p * (x / p).floorToDouble() : x;
  }

  /// Where the flow runs on [layer] at [f] of the way along its course (0
  /// where it comes in, 1 the far end): its middle and half its width.
  /// Off the cone's crater down its face; over the crest of the near hills
  /// and down into the lake; in at the near field's far edge and on toward
  /// the viewer.
  (Offset, double) _flowAt(SceneLayer layer, double f, double shift) {
    if (layer == far) {
      final k = _cones.first;
      final a = _rim(k) * 0.5 + (1 - _rim(k) * 0.5) * f;
      // Its own way down the front of the cone, left of the old channels.
      final q = -0.08 - 0.13 * a + 0.04 * fieldNoise(a * 6, 2301);
      return (_onCone(k, _coneX + shift, q, a), (4.6 - 1.6 * a) * _u);
    }
    final to = _flowX[layer]! + shift;
    final from = to + _loopDelta(_flowFrom[layer]!, _flowX[layer]!, layer);
    final k = layer == mid ? 0.6 : 1.0;
    final top = layer == mid
        ? _hill(1, from) + 1 * _u
        : _h * _nearLavaTop - 2 * _u;
    final bottom = layer == mid ? _h * 0.775 : _h + 8 * _u;
    final y = top + (bottom - top) * f;
    final along = y - top;
    final depth = ((y - _h * 0.575) / (_h * 0.425)).clamp(0.2, 1.2);
    // In under the cone, bending toward the open lava over its first
    // stretch — behind any rock that stands in the way.
    final bend = ((y - top) / (_h * 0.18)).clamp(0.0, 1.0);
    final x0 = from + (to - from) * bend * bend * (3 - 2 * bend);
    final x =
        x0 +
        (layer == mid ? 9 : 5) *
            _u *
            k *
            math.sin(along / (32 * _u * k) + 1.3) +
        2 * _u * k * fieldNoise(along / (9 * _u), 2303);
    // Down the hillside it runs narrow; in the lake it spreads.
    final spread = layer == mid
        ? 1 +
              1.3 *
                  ((y - _h * (_midLavaTop - 0.005)) / (_h * 0.05)).clamp(
                    0.0,
                    1.0,
                  )
        : 1.0;
    return (Offset(x, y), 13 * _u * k * (0.35 + 1.1 * depth) * spread);
  }

  /// The flow on [layer], live: a fresh river of molten rock as far as
  /// its front has come — hot down its middle, skinned dark red at its
  /// edges, its light on the crust round it — ending in a rounded, blazing
  /// lobe that is still pushing on, bright gobbets riding down it.
  void _paintFlowOn(Canvas canvas, FieldView view, SceneLayer layer) {
    _seen[layer] = view;
    final t = view.time;
    final front = _flowFront(layer, t);
    if (front == null || front < 0.003) return;
    if (layer != far && !_flowX.containsKey(layer)) {
      final p = _period(layer);
      final from = _underCone(view) ?? (view.left + view.right) / 2;
      _flowFrom[layer] = p > 0 ? from - p * (from / p).floorToDouble() : from;
      _flowX[layer] = _chooseFlowX(layer, view);
    }
    final base = layer == far ? _coneX : _flowX[layer]!;
    final l = _light;
    final crust = _sil(_crust, l);
    final skin = Color.lerp(_lavaOrange, crust, 0.55)!;
    final glowA = (0.18 + 0.32 * _night) * _pulse;
    final flicker = 0.9 + 0.1 * math.sin(t * 9.0) * math.sin(t * 5.3 + 1);
    for (final shift in _shiftsFor(layer, view, 220 * _u)) {
      if (base + shift + 160 * _u < view.left ||
          base + shift - 160 * _u > view.right) {
        continue;
      }
      final n = layer == far ? 24 : 30;
      final f = _flowBuf;
      // The course: each section's middle, its half width, which way it
      // runs.
      for (var j = 0; j <= n; j++) {
        final (p, w) = _flowAt(layer, front * j / n, shift);
        f.mx[j] = p.dx;
        f.my[j] = p.dy;
        f.w[j] = w;
      }
      // Each section's colours across it, once: fading up where it comes
      // in, crusted over in patches behind the front, hottest at it.
      var v = 0;
      for (var j = 0; j <= n; j++) {
        final a = math.max(0, j - 1), b = math.min(n, j + 1);
        var dx = f.mx[b] - f.mx[a], dy = f.my[b] - f.my[a];
        final len = math.sqrt(dx * dx + dy * dy);
        if (len > 0) {
          dx /= len;
          dy /= len;
        } else {
          dx = 0;
          dy = 1;
        }
        f.dx[j] = dx;
        f.dy[j] = dy;
        final fresh = math.pow(j / n, 3).toDouble();
        final fade = layer == far ? 1.0 : math.min(1.0, j / 4);
        final crusted =
            (0.5 +
                0.5 * fieldNoise(j * 0.55 + base * 0.01, 2307 + layer.index)) *
            (1 - fresh) *
            0.55;
        final hot = Color.lerp(
          Color.lerp(_lavaOrange, _lavaHot, 0.35 + 0.6 * fresh)!,
          skin,
          crusted,
        )!;
        final mid = Color.lerp(
          Color.lerp(_lavaOrange, skin, crusted)!,
          hot,
          0.3,
        )!;
        for (var c = 0; c < _flowAcross.length; c++) {
          final s = _flowAcross[c];
          final col = switch (c) {
            0 || 8 => _glowWarm.withValues(alpha: 0),
            1 || 7 => _glowWarm.withValues(alpha: glowA),
            2 || 6 => skin,
            3 || 5 => mid,
            _ => hot,
          };
          final hw = f.w[j] * s;
          f.pos[v * 2] = f.mx[j] - dy * hw;
          f.pos[v * 2 + 1] = f.my[j] + dx * hw;
          f.col[v] = col.withValues(alpha: col.a * fade).toARGB32();
          v++;
        }
      }
      // The lobe at its front, still pushing: hottest at its heart.
      final hx = f.mx[n], hy = f.my[n], hw = f.w[n];
      final ddx = f.dx[n], ddy = f.dy[n];
      final heart = Color.lerp(
        _lavaHot,
        const Color(0xFFFFF2C4),
        0.3 * flicker,
      )!.toARGB32();
      final lobeAt = v;
      f.pos[v * 2] = hx;
      f.pos[v * 2 + 1] = hy;
      f.col[v++] = heart;
      const m = 10;
      for (final (r, col) in [
        (1.0, skin.toARGB32()),
        (2.2, _glowWarm.withValues(alpha: 0).toARGB32()),
      ]) {
        for (var i = 0; i <= m; i++) {
          final phi = -math.pi / 2 + math.pi * i / m;
          final sn = math.sin(phi) * hw * r, cs = math.cos(phi) * hw * r * 0.9;
          f.pos[v * 2] = hx - ddy * sn + ddx * cs;
          f.pos[v * 2 + 1] = hy + ddx * sn + ddy * cs;
          f.col[v++] = col;
        }
      }
      // Triangles: the strip, then the lobe and the glow round it.
      var k = 0;
      final cols = _flowAcross.length;
      for (var j = 0; j < n; j++) {
        for (var c = 0; c + 1 < cols; c++) {
          final i0 = j * cols + c, i1 = i0 + 1, i2 = i0 + cols, i3 = i2 + 1;
          f.idx
            ..[k++] = i0
            ..[k++] = i1
            ..[k++] = i2
            ..[k++] = i2
            ..[k++] = i1
            ..[k++] = i3;
        }
      }
      final ring = lobeAt + 1, glow = ring + m + 1;
      for (var i = 0; i < m; i++) {
        f.idx
          ..[k++] = lobeAt
          ..[k++] = ring + i
          ..[k++] = ring + i + 1;
        // The glow: between the lobe's edge and its outer ring.
        f.idx
          ..[k++] = ring + i
          ..[k++] = glow + i
          ..[k++] = ring + i + 1
          ..[k++] = ring + i + 1
          ..[k++] = glow + i
          ..[k++] = glow + i + 1;
      }
      canvas.drawVertices(
        Vertices.raw(
          VertexMode.triangles,
          Float32List.sublistView(f.pos, 0, v * 2),
          colors: Int32List.sublistView(f.col, 0, v),
          indices: Uint16List.sublistView(f.idx, 0, k),
        ),
        BlendMode.srcOver,
        Paint(),
      );
      // Bright gobbets riding down it, so it is seen to move.
      _sparkBatch.clear();
      final count = switch (layer) {
        far => 18,
        mid => 26,
        _ => 44,
      };
      for (var i = 0; i < count; i++) {
        final u =
            (t * (layer == far ? 0.07 : 0.05) +
                fieldHash(i, 2321 + layer.index)) %
            1.0;
        if (u > front || (layer != far && u < 0.06)) continue;
        final at = u / front * n;
        final j = math.min(n - 1, at.floor());
        final g = at - j;
        final x = f.mx[j] + (f.mx[j + 1] - f.mx[j]) * g;
        final y = f.my[j] + (f.my[j + 1] - f.my[j]) * g;
        final across = (fieldHash(i, 2325) - 0.5) * f.w[j] * 1.1;
        _sparkBatch.add(
          u > front * 0.85 ? 0 : 1,
          x - f.dy[j] * across,
          y + f.dx[j] * across,
        );
      }
      _drawSparkCores(canvas, layer == far ? 0.7 : (layer == mid ? 0.8 : 1.0));
    }
  }

  /// Across a flow, in half widths from its middle: its light on the crust
  /// out to either side, its dark skin, its hot middle.
  static const _flowAcross = [-2.6, -1.4, -1.0, -0.5, 0.0, 0.5, 1.0, 1.4, 2.6];

  /// Room to lay a flow out in, frame after frame.
  final _FlowBuffers _flowBuf = _FlowBuffers(31, _flowAcross.length);

  int _flowSlot = -1;

  /// Where the near flow is burning its way across: drops of it thrown up
  /// at its front, and smoke off the crust it is burning through, rising
  /// in a thin drift.
  void _paintFlowFront(Canvas canvas, FieldView view) {
    final t = view.time;
    final front = _flowFront(near, t);
    if (front == null || front >= 1 || _flowX[near] == null) return;
    final period = _period(near);
    final shift = period > 0
        ? period *
              (((view.left + view.right) / 2 - _flowX[near]!) / period)
                  .roundToDouble()
        : 0.0;
    final slot = (t / 0.22).floor();
    if (slot != _flowSlot) {
      _flowSlot = slot;
      final (p, w) = _flowAt(near, front, shift);
      _spit(p.dx + (fieldHash(slot, 2311) - 0.5) * w, p.dy, 0, 0, count: 3);
    }
    final (start, _) = _flowTimes[near]!;
    _steamBatch.clear();
    var any = false;
    const life = 3.0;
    for (var i = 0; i < 70; i++) {
      final age = (t + i * life / 70) % life;
      final born = t - age;
      if (born < start) continue;
      final (p, w) = _flowAt(near, _flowFront(near, born) ?? 0, shift);
      final g = age / life;
      final x =
          p.dx +
          (fieldHash(i, 2313) - 0.5) * w * (1 + g) +
          g * 12 * _u +
          3 * _u * math.sin(t * 0.9 + i);
      final y = p.dy - g * 50 * _u;
      _steamBatch.add(g < 0.35 ? 0 : (g < 0.7 ? 1 : 2), x, y);
      any = true;
    }
    if (!any) return;
    final l = _light;
    final smoke = Color.lerp(_sil(_plumeAsh, l), l.skyAt(0.4), 0.3)!;
    _steamBatch
      ..draw(
        canvas,
        0,
        2.2 * _u,
        Color.lerp(smoke, _glowWarm, 0.35)!.withValues(alpha: 0.4),
      )
      ..draw(canvas, 1, 2.4 * _u, smoke.withValues(alpha: 0.3))
      ..draw(canvas, 2, 2.6 * _u, smoke.withValues(alpha: 0.15));
  }

  // ── Live ─────────────────────────────────────────────────────────────────

  @override
  void paintLive(
    SceneLayer layer,
    Canvas canvas,
    FieldView view, {
    required bool front,
  }) {
    _seen[layer] = view;
    switch (layer) {
      case far:
        _paintFlows(canvas, view);
        _paintPlume(canvas, view);
        // The fountain and the bombs, one batch of grains between them.
        _sparkBatch.clear();
        _paintFountain(canvas, view);
        _paintBombs(canvas, view);
        _drawSparkGrains(canvas, _erupting ? 1.05 : 0.8);
      case mid:
        _paintGlints(canvas, view, mid, _glints[mid], size: 0.85, alpha: 0.7);
        _paintEmbers(canvas, view, mid);
      case near:
        final pushes = _pushes(view);
        if (!front) {
          _route(view);
          _bloop(view);
          _paintGlints(
            canvas,
            view,
            near,
            _glints[near],
            size: 1.2,
            alpha: 0.85,
          );
          _paintWakes(canvas, view);
          _paintFlowFront(canvas, view);
          _paintEmbers(canvas, view, near);
          _paintSteam(canvas, view);
          _kickUp(view, pushes, near, _nearWidth, _inGrass);
        }
        final blades = _nearBlades;
        if (blades != null) {
          if (!front) {
            _stirBlades(
              blades,
              near,
              _nearWidth,
              view,
              reach: 30 * _u,
              maxBend: 1.0,
              shed: true,
            );
          }
          _paintBlades(
            canvas,
            view,
            blades,
            _nearWidth,
            rows: front ? (4, 4) : (0, 3),
            fore: false,
            layer: near,
          );
        }
        if (front) {
          _paintSparks(canvas, view);
          _paintKicked(canvas, view);
          _paintAsh(canvas, view);
          _paintAshFall(canvas, view);
        }
      case fore:
        final blades = _foreBlades;
        if (blades == null) return;
        _stirBlades(
          blades,
          fore,
          _foreWidth,
          view,
          reach: 48 * _u,
          maxBend: 0.8,
        );
        _paintBlades(
          canvas,
          view,
          blades,
          _foreWidth,
          rows: (0, 0),
          fore: true,
          layer: fore,
        );
      default:
        break;
    }
  }
}

/// A plate of crust on the lava: (outline, middle x, middle y, size, id, how
/// open the lava is there, how warm).
typedef _Plate = (List<Offset>, double, double, double, int, double, double);

/// A band of open lava: its two edges, as matching runs of points, how
/// hot it is at the first edge, across its middle and at the other, and
/// whether it is a river (whose warmth spreads wider round it).
class _Band {
  _Band(this.a, this.b, this.heat, {this.river = false});
  final List<Offset> a, b;
  final (double, double, double) heat;
  final bool river;
}

/// Solid ground in the Volcano: a shelf of basalt or a bank of cinder,
/// standing up out of the lava.
class _Shelf {
  _Shelf({
    required this.cx,
    required this.hw,
    required this.plate,
    required this.rise,
    required this.seed,
    required this.haze,
    required this.basalt,
    this.flare = 0,
    this.steps = 0,
  });

  /// Its middle and half its width, in layer units, and how much wider it
  /// is at the lava than at its top.
  final double cx, hw, flare;

  /// How deep its top is, and how far its lip stands above the lava.
  final double plate, rise;
  final int seed;

  /// How far off it is (0 near; a far shelf is hazed).
  final double haze;
  final bool basalt;

  /// Which end of a basalt shelf steps down toward the lava: -1 left, 1
  /// right.
  final int steps;

  /// Where feet stand at its middle, less its unevenness there; set once
  /// it is seated.
  double level = 0;
}

/// A spire of rock standing in the lava (or, at the front, a black rock):
/// where its foot is, half its width there, how tall.
class _Spire {
  _Spire(
    this.x,
    this.base,
    this.hw,
    this.h,
    this.seed,
    this.haze, {
    this.round = false,
  });
  final double x, base, hw, h;
  final int seed;
  final double haze;

  /// A boulder, lumpy and round-topped, rather than a point.
  final bool round;

  double get top => base - h;

  _Spire at(double x) =>
      x == this.x ? this : _Spire(x, base, hw, h, seed, haze, round: round);
}

/// A cone on the far layer: where it stands (layer units), half its width
/// at the reference height, its crater and its foot as shares of the
/// height.
class _Cone {
  const _Cone(
    this.x,
    this.hw,
    this.top,
    this.foot,
    this.seed, {
    required this.burning,
  });
  final double x, hw, top, foot;
  final int seed;
  final bool burning;
}

/// The vent under the open-air point.
class _Vent {
  _Vent(this.x, this.base, this.hw, this.h, this.seed);
  final double x, base, hw, h;
  final int seed;
}

/// A dead tree, burnt to a snag. Its shape is laid out once by
/// [VolcanoField._shapeSnag].
class _Snag {
  _Snag(this.x, this.base, this.h, this.seed);
  final double x, base, h;
  final int seed;

  late Offset Function(double f) spine;
  late double Function(double f) half;
  late double wb;
  late List<Offset> outline;
  late List<List<Offset>> limbs;

  /// (how far up, across, how long) of each smouldering crack.
  late List<(double, double, double)> embers;
  late double reach, top;
}

/// Room for one flow's course and its triangles: (sections + 1) × [cols]
/// vertices across it and a lobe at its front.
class _FlowBuffers {
  _FlowBuffers(int sections, int cols)
    : mx = Float32List(sections),
      my = Float32List(sections),
      w = Float32List(sections),
      dx = Float32List(sections),
      dy = Float32List(sections),
      pos = Float32List((sections * cols + 32) * 2),
      col = Int32List(sections * cols + 32),
      idx = Uint16List(sections * (cols - 1) * 6 + 96);
  final Float32List mx, my, w, dx, dy, pos;
  final Int32List col;
  final Uint16List idx;
}

/// The plume's grains: each one's place in its rise, how long a rise takes
/// it, and its own way off the column's middle.
class _Plume {
  _Plume(this.phase, this.life, this.sx, this.sy, this.swirl)
    : n = phase.length;
  final Float32List phase, life, sx, sy, swirl;
  final int n;
}

/// Embers off the lava: where each rises from, when, how far, for how long,
/// and how much it sways.
class _Embers {
  _Embers(this.x, this.y, this.phase, this.rise, this.life, this.wob)
    : n = x.length;
  final Float32List x, y, phase, rise, life, wob;
  final int n;
}

// ── The Volcano's day ──────────────────────────────────────────────────────

const _volcanoNight = _Light(
  sky: [
    Color(0xFF0B0507),
    Color(0xFF100608),
    Color(0xFF15080A),
    Color(0xFF1C0A0B),
    Color(0xFF260D0C),
    Color(0xFF31110E),
    Color(0xFF3D1510),
    Color(0xFF471812),
    Color(0xFF471812),
  ],
  ambient: Color(0xFF3A262A),
  rim: Color(0xFFD8A496),
  rimStrength: 0.16,
  floor: 0.4,
  glow: 0,
  stars: 0.5,
  cloudTop: Color(0xFF180B0C),
  cloudBottom: Color(0xFF4E1A14),
  cloudGlint: Color(0xFFFF9A5C),
  grass: [
    Color(0xFF060404),
    Color(0xFF0A0606),
    Color(0xFF0F0908),
    Color(0xFF150C0A),
    Color(0xFF1D110D),
    Color(0xFF2A1812),
    Color(0xFF3E241A),
    Color(0xFF5E3826),
  ],
  mote: Color(0xFFFF8C40),
  firefly: 1,
);

const _volcanoPreDawn = _Light(
  sky: [
    Color(0xFF0E0609),
    Color(0xFF14080C),
    Color(0xFF1C0B10),
    Color(0xFF261014),
    Color(0xFF321516),
    Color(0xFF421B18),
    Color(0xFF52201A),
    Color(0xFF5C241C),
    Color(0xFF5C241C),
  ],
  ambient: Color(0xFF46302F),
  rim: Color(0xFFD8A094),
  rimStrength: 0.16,
  floor: 0.35,
  glow: 0.1,
  stars: 0.4,
  cloudTop: Color(0xFF1E0E12),
  cloudBottom: Color(0xFF5C2219),
  cloudGlint: Color(0xFFFF9A6A),
  grass: [
    Color(0xFF080505),
    Color(0xFF0D0807),
    Color(0xFF130B09),
    Color(0xFF1A100C),
    Color(0xFF241610),
    Color(0xFF341E16),
    Color(0xFF4C2E20),
    Color(0xFF704630),
  ],
  mote: Color(0xFFFF8C40),
  firefly: 0.9,
);

const _volcanoDawn = _Light(
  sky: [
    Color(0xFF1C0A12),
    Color(0xFF2A0F16),
    Color(0xFF3C141A),
    Color(0xFF541A1C),
    Color(0xFF72221E),
    Color(0xFF962E22),
    Color(0xFFB43A26),
    Color(0xFFC4442A),
    Color(0xFFC4442A),
  ],
  ambient: Color(0xFF7A5048),
  rim: Color(0xFFFF9A6E),
  rimStrength: 0.5,
  floor: 0.1,
  glow: 0.55,
  stars: 0.15,
  cloudTop: Color(0xFF3A1618),
  cloudBottom: Color(0xFFB24830),
  cloudGlint: Color(0xFFFFB08A),
  grass: [
    Color(0xFF0E0807),
    Color(0xFF160C0A),
    Color(0xFF20120D),
    Color(0xFF2C1A12),
    Color(0xFF3E2616),
    Color(0xFF58381E),
    Color(0xFF80522A),
    Color(0xFFB0764A),
  ],
  mote: Color(0xFFFFA060),
  firefly: 0.4,
);

const _volcanoSunrise = _Light(
  sky: [
    Color(0xFF3A1418),
    Color(0xFF4E1A1C),
    Color(0xFF6A2220),
    Color(0xFF882C24),
    Color(0xFFA83A28),
    Color(0xFFC84C2E),
    Color(0xFFE06234),
    Color(0xFFEC7038),
    Color(0xFFEC7038),
  ],
  ambient: Color(0xFFB4826C),
  rim: Color(0xFFFFC27A),
  rimStrength: 0.95,
  floor: 0.1,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF6A2A24),
  cloudBottom: Color(0xFFE07444),
  cloudGlint: Color(0xFFFFC890),
  grass: [
    Color(0xFF120A08),
    Color(0xFF1C100C),
    Color(0xFF2A1810),
    Color(0xFF3C2414),
    Color(0xFF56341A),
    Color(0xFF7C5024),
    Color(0xFFB07A3C),
    Color(0xFFE8A866),
  ],
  mote: Color(0xFFFFB060),
  firefly: 0,
);

const _volcanoMorning = _Light(
  sky: [
    Color(0xFF5C2224),
    Color(0xFF6E2828),
    Color(0xFF84302A),
    Color(0xFF9C3A2E),
    Color(0xFFB04432),
    Color(0xFFC25036),
    Color(0xFFD25C3A),
    Color(0xFFDA663E),
    Color(0xFFDA663E),
  ],
  ambient: Color(0xFFDCB29C),
  rim: Color(0xFFFFD09A),
  rimStrength: 0.5,
  floor: 0.45,
  glow: 0.6,
  stars: 0,
  cloudTop: Color(0xFFA8463A),
  cloudBottom: Color(0xFF702A26),
  cloudGlint: Color(0xFFFFB888),
  grass: [
    Color(0xFF140C09),
    Color(0xFF1E120D),
    Color(0xFF2C1A11),
    Color(0xFF3E2616),
    Color(0xFF56381E),
    Color(0xFF765228),
    Color(0xFF9E763E),
    Color(0xFFC8A064),
  ],
  mote: Color(0xFFFFB068),
  firefly: 0,
);

const _volcanoDay = _Light(
  sky: [
    Color(0xFF642424),
    Color(0xFF782A28),
    Color(0xFF8E322A),
    Color(0xFFA43C2E),
    Color(0xFFB84632),
    Color(0xFFC85236),
    Color(0xFFD45E3A),
    Color(0xFFDC683E),
    Color(0xFFDC683E),
  ],
  ambient: Color(0xFFE8C4AC),
  rim: Color(0xFFFFDCA8),
  rimStrength: 0.35,
  floor: 0.7,
  glow: 0.5,
  stars: 0,
  cloudTop: Color(0xFFB84E3C),
  cloudBottom: Color(0xFF7C2E28),
  cloudGlint: Color(0xFFFFC090),
  grass: [
    Color(0xFF120A08),
    Color(0xFF1C100C),
    Color(0xFF2A1810),
    Color(0xFF3C2414),
    Color(0xFF54341C),
    Color(0xFF745028),
    Color(0xFF9C7440),
    Color(0xFFC8A068),
  ],
  mote: Color(0xFFFFA858),
  firefly: 0,
);

const _volcanoAfternoon = _Light(
  sky: [
    Color(0xFF54201F),
    Color(0xFF682624),
    Color(0xFF802E26),
    Color(0xFF9C3828),
    Color(0xFFBA462C),
    Color(0xFFD25630),
    Color(0xFFE46A36),
    Color(0xFFEC763C),
    Color(0xFFEC763C),
  ],
  ambient: Color(0xFFD8A88A),
  rim: Color(0xFFFFC688),
  rimStrength: 0.6,
  floor: 0.3,
  glow: 0.75,
  stars: 0,
  cloudTop: Color(0xFF9A3C30),
  cloudBottom: Color(0xFFC25E3C),
  cloudGlint: Color(0xFFFFC890),
  grass: [
    Color(0xFF120A08),
    Color(0xFF1C100B),
    Color(0xFF2A170F),
    Color(0xFF3C2212),
    Color(0xFF56321A),
    Color(0xFF7A4E24),
    Color(0xFFA6763C),
    Color(0xFFD8A864),
  ],
  mote: Color(0xFFFFB060),
  firefly: 0,
);

const _volcanoGolden = _Light(
  sky: [
    Color(0xFF2E1016),
    Color(0xFF42161A),
    Color(0xFF5E1E1E),
    Color(0xFF7E2822),
    Color(0xFFA43626),
    Color(0xFFCA4A2A),
    Color(0xFFE8622E),
    Color(0xFFF47434),
    Color(0xFFF47434),
  ],
  ambient: Color(0xFF8E604E),
  rim: Color(0xFFFFB46C),
  rimStrength: 1,
  floor: 0.06,
  glow: 1,
  stars: 0,
  cloudTop: Color(0xFF4A1C1C),
  cloudBottom: Color(0xFFE06A3A),
  cloudGlint: Color(0xFFFFC080),
  grass: [
    Color(0xFF0E0807),
    Color(0xFF160C09),
    Color(0xFF22120C),
    Color(0xFF301A10),
    Color(0xFF482816),
    Color(0xFF6E401E),
    Color(0xFFA2662E),
    Color(0xFFE09A52),
  ],
  mote: Color(0xFFFFB05C),
  firefly: 0,
);

const _volcanoSunset = _Light(
  sky: [
    Color(0xFF1E0A12),
    Color(0xFF2C0E16),
    Color(0xFF42141A),
    Color(0xFF5E1A1C),
    Color(0xFF84241E),
    Color(0xFFAE3220),
    Color(0xFFD24424),
    Color(0xFFE05028),
    Color(0xFFE05028),
  ],
  ambient: Color(0xFF5E3C38),
  rim: Color(0xFFFF8A50),
  rimStrength: 0.95,
  floor: 0.06,
  glow: 1,
  stars: 0.05,
  cloudTop: Color(0xFF2A1014),
  cloudBottom: Color(0xFFC24A2C),
  cloudGlint: Color(0xFFFFA070),
  grass: [
    Color(0xFF0A0606),
    Color(0xFF100908),
    Color(0xFF180D0A),
    Color(0xFF22130D),
    Color(0xFF341C12),
    Color(0xFF522C18),
    Color(0xFF7E4422),
    Color(0xFFB86634),
  ],
  mote: Color(0xFFFF9A50),
  firefly: 0.15,
);

const _volcanoDusk = _Light(
  sky: [
    Color(0xFF10060A),
    Color(0xFF18080C),
    Color(0xFF220B0E),
    Color(0xFF2E0F10),
    Color(0xFF3E1412),
    Color(0xFF521A14),
    Color(0xFF662016),
    Color(0xFF6E2418),
    Color(0xFF6E2418),
  ],
  ambient: Color(0xFF3E2A2C),
  rim: Color(0xFFE09070),
  rimStrength: 0.25,
  floor: 0.2,
  glow: 0.4,
  stars: 0.3,
  cloudTop: Color(0xFF1A0A0C),
  cloudBottom: Color(0xFF5E2016),
  cloudGlint: Color(0xFFFF9060),
  grass: [
    Color(0xFF070505),
    Color(0xFF0B0706),
    Color(0xFF110A08),
    Color(0xFF180E0B),
    Color(0xFF21140F),
    Color(0xFF301C14),
    Color(0xFF462A1C),
    Color(0xFF6A402A),
  ],
  mote: Color(0xFFFF9048),
  firefly: 0.75,
);

/// The day, keyed by hour. The night window lines up with the encounter
/// tables' (20:00–05:00).
const _volcanoKeys = <(double, _Light)>[
  (0, _volcanoNight),
  (4.4, _volcanoNight),
  (5.0, _volcanoPreDawn),
  (5.6, _volcanoDawn),
  (6.4, _volcanoSunrise),
  (7.8, _volcanoMorning),
  (10.0, _volcanoDay),
  (15.5, _volcanoDay),
  (17.6, _volcanoAfternoon),
  (18.7, _volcanoGolden),
  (19.4, _volcanoSunset),
  (20.1, _volcanoDusk),
  (21.0, _volcanoNight),
  (24, _volcanoNight),
];
