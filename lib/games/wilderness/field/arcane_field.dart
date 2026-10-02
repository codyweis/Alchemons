part of 'grain_field.dart';

// The Arcane — the Arcane Expanse — through the day.
//
// The realm behind the portal is the void, floored with a mirror: a plain of
// still black glass running out to a great band of dust that lies across the
// dark where a horizon would be. Everything above the glass is given back
// in it — the stars, the band, one tall needle of a mountain standing out of
// it far off, the standing stones nearer, and the creatures, upside down
// under their own feet. By day a white star, the Lantern, crosses the void;
// it sets crimson. By night a black hole comes up in its place, seen only as
// a patch where the stars stop, the stars round it pulled aside, and the
// grains of the ring it is eating, brighter on the side that comes toward
// you. A finger on the glass wakes light in it, and grains of it rise.
//
// Layers, matching the scene's spawn anchors:
//   sky     — screen-fixed (the camera backdrop): the void, its stars, the
//             Lantern by day and the black hole by night, and all of it
//             again in the glass
//   layer2  — the dust band and its image, the needle, the furthest stones
//   layer3  — standing stones further off
//   layer4  — the glass the creatures stand on, and the nearest stones
//
// The glass is ground everywhere nearer than the band, so every creature,
// and every encounter's partner, stands on something.
//
// Still sheets are baked as maps (see field_art.dart), read through the
// hour's grades:
//   veil     r = the hem's colour, g = the dust's; alpha = how thick
//   stone    r = haze, g = what its gloss gives back, b = shade

class ArcaneField extends _GrainField {
  ArcaneField();

  static const far = SceneLayer.layer2;
  static const mid = SceneLayer.layer3;
  static const near = SceneLayer.layer4;

  static const _gVeil = 0, _gFar = 1, _gStone = 2;

  /// Daylight colours of what stands on the glass; the hour's ambient light
  /// multiplies them.
  static const _albedo = <int, Color>{
    _gFar: Color(0xFF221C3A),
    _gStone: Color(0xFF17121F),
  };

  /// Where the glass meets the dust band, as a share of the height.
  static const _glassLine = 0.565;

  /// How high the band's middle lies over the glass's far edge.
  static const _bandLift = 0.075;

  @override
  List<(double, _Light)> get _keys => _arcaneKeys;

  // The Lantern and the black hole come up out of the band.
  @override
  double get _horizon => 0.6;

  @override
  Color _sunDisc(double low) =>
      Color.lerp(const Color(0xFFFFFAEE), const Color(0xFFFF8E80), low)!;

  @override
  double _lightK(SceneLayer layer) => switch (layer) {
    far => 0.75,
    mid => 0.9,
    _ => 1.0,
  };

  // ── The light ────────────────────────────────────────────────────────────

  Color _sil(Color a, _Light l) => Color.from(
    alpha: 1,
    red: a.r * l.ambient.r,
    green: a.g * l.ambient.g,
    blue: a.b * l.ambient.b,
  );

  @override
  void _buildGrades(_Light l) {
    _grades[_gVeil] = fieldGrade(
      base: l.cloudTop,
      r: fieldDiff(l.cloudBottom, l.cloudTop),
      g: fieldDiff(l.cloudGlint, l.cloudTop),
      b: (0, 0, 0),
    );
    final band = l.skyAt(0.5);
    // What black stone gives back: the band, tinted with its hem.
    final sheen = Color.lerp(
      Color.lerp(band, l.cloudBottom, 0.3)!,
      l.cloudGlint,
      0.25,
    )!;
    for (final g in [_gFar, _gStone]) {
      final s = _sil(_albedo[g]!, l);
      _grades[g] = fieldGrade(
        base: s,
        r: fieldDiff(band, s),
        g: fieldDiff(sheen, s),
        b: fieldScale(s, -0.85),
      );
    }
  }

  // ── Where the creatures stand ────────────────────────────────────────────

  /// Every point stands on the glass, seated by the creature's feet.
  @override
  double? perchFor(String spawnId) {
    for (final p in _spawns) {
      if (p.id != spawnId || p.aloft) continue;
      if (p.anchor == near || p.anchor == mid) return _feet(p);
    }
    return null;
  }

  // The glass is ground everywhere nearer than the band: anything that
  // cannot float and would hang over the band is stood on it instead.
  @override
  ({double top, double rest})? groundAt(SceneLayer layer, double x) {
    if (layer != near && layer != mid) return null;
    return (top: _h * _glassLine, rest: _h * (_glassLine + 0.06));
  }

  // The glass gives back whatever stands on it, and holds a little light
  // under it — the light a finger wakes, kept for as long as it stands
  // there. It is what shows a dark creature against the dark glass.
  @override
  double reflectionAt(SceneLayer layer) =>
      layer == near || layer == mid ? 0.3 : 0;

  @override
  void paintUnderfoot(
    Canvas canvas,
    SceneLayer layer,
    double halfWidth,
    double time,
  ) {
    if (layer != near && layer != mid) return;
    final c = _light.cloudBottom;
    final a = 0.26 + 0.05 * math.sin(time * 1.1 + halfWidth);
    final r = halfWidth * 1.35;
    canvas
      ..save()
      ..scale(1, 0.24)
      ..drawCircle(
        Offset.zero,
        r,
        Paint()
          ..shader = Gradient.radial(
            Offset.zero,
            r,
            [
              c.withValues(alpha: a),
              c.withValues(alpha: a * 0.3),
              c.withValues(alpha: 0),
            ],
            const [0.0, 0.45, 1.0],
          ),
      )
      ..restore();
  }

  /// Where the glass begins, layer-local.
  @visibleForTesting
  double get debugGlassLine => _h * _glassLine;

  /// The standing stones on [layer] as built: each one's span, from its top
  /// to its foot on the glass.
  @visibleForTesting
  List<Rect> debugStones(SceneLayer layer) {
    final w = _widths[layer] ?? _worldWidth;
    return [
      for (final (fx, fy, sw, sh) in _stonesOf(layer))
        Rect.fromLTRB(
          fx * w - sw * _u / 2,
          fy * _h - sh * _u,
          fx * w + sw * _u / 2,
          fy * _h,
        ),
    ];
  }

  // ── The sky, and the sky in the glass ────────────────────────────────────

  /// The void's stars: (x, y as shares of the screen, how big, warm or
  /// cool, twinkle phase).
  late final List<(double, double, int, int, double)> _voidStars = () {
    final r = FieldRandom(1717);
    return [
      for (var i = 0; i < 420; i++)
        (
          r.next(),
          r.next() * _glassLine,
          r.next() < 0.06 ? 2 : (r.next() < 0.3 ? 1 : 0),
          r.next() < 0.28 ? 1 : 0,
          r.next() * math.pi * 2,
        ),
    ];
  }();

  /// Grains of the black hole's ring: (radius in hole radii, starting
  /// angle, twinkle phase).
  late final List<(double, double, double)> _ringGrains = () {
    final r = FieldRandom(2323);
    final out = <(double, double, double)>[];
    // Most in the main lane, some in a hot inner lane, a thin outer haze —
    // and gathered here and there into clumps that the orbit shears.
    const lanes = [(2.0, 0.28, 0.32), (3.0, 0.55, 0.5), (4.3, 0.5, 0.18)];
    double lane() {
      var pick = r.next();
      for (final (c, w, share) in lanes) {
        pick -= share;
        if (pick <= 0) return c + (r.next() + r.next() - 1) * w;
      }
      return lanes.last.$1;
    }

    for (var i = 0; i < 420; i++) {
      out.add((lane(), r.next() * math.pi * 2, r.next() * math.pi * 2));
    }
    for (var k = 0; k < 9; k++) {
      final a = r.next() * math.pi * 2, rad = lane();
      for (var i = 0; i < 16; i++) {
        out.add((
          rad + (r.next() - 0.5) * 0.18,
          a + (r.next() - 0.5) * 0.5,
          r.next() * math.pi * 2,
        ));
      }
    }
    return out;
  }();

  final GrainBatch _starGrains = GrainBatch(6);
  final GrainBatch _ringBack = GrainBatch(6);
  final GrainBatch _ringFront = GrainBatch(6);

  /// How much of the void the glass gives back [f] of the way from its far
  /// edge down to the bottom of the screen: most where you look across it.
  double _fresnel(double f) =>
      0.78 - 0.5 * math.pow(f.clamp(0.0, 1.0), 0.7).toDouble();

  /// The black hole this frame: where it is on the screen, its radius, and
  /// how much of it shows — or null while it is down.
  (Offset, double, double)? _hole(Size screen, FieldView view) {
    if (_moonUp < -0.12) return null;
    final vis = (_light.stars * ((_moonUp + 0.12) / 0.2).clamp(0.0, 1.0)).clamp(
      0.0,
      1.0,
    );
    if (vis < 0.02) return null;
    final at = Offset(
      screen.width * _moonX,
      view.screenY(view.height * (_horizon - _moonUp * 0.49)),
    );
    return (at, 19 * _u * view.zoom, vis);
  }

  @override
  void paintSky(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    final top = view.screenY(0), bottom = view.screenY(view.height);
    canvas.drawRect(
      Offset.zero & screen,
      Paint()
        ..shader = Gradient.linear(
          Offset(0, top),
          Offset(0, bottom),
          l.sky,
          l.stops,
        ),
    );
    _paintGlass(canvas, screen, view);
    final hole = _hole(screen, view);
    _paintVoidStars(canvas, screen, view, hole);
    _paintLantern(canvas, screen, view);
    if (hole != null) _paintHole(canvas, screen, view, hole);
    _paintAurora(canvas, screen, view);
    _paintMeteors(canvas, screen, view);
  }

  /// The void turned over in the glass below the band, dimming as the eye
  /// looks down into it.
  void _paintGlass(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    final hy = view.screenY(view.height * _glassLine);
    final by = view.screenY(view.height);
    const glass = Color(0xFF020106);
    const n = 8;
    final colours = <Color>[], stops = <double>[];
    for (var i = 0; i <= n; i++) {
      final f = i / n;
      final up = (_glassLine - (1 - _glassLine) * f).clamp(0.0, 1.0);
      colours.add(Color.lerp(glass, l.skyAt(up), _fresnel(f))!);
      stops.add(f);
    }
    canvas.drawRect(
      Rect.fromLTRB(0, hy, screen.width, math.max(screen.height, by)),
      Paint()
        ..shader = Gradient.linear(
          Offset(0, hy),
          Offset(0, by),
          colours,
          stops,
        ),
    );
  }

  void _paintVoidStars(
    Canvas canvas,
    Size screen,
    FieldView view,
    (Offset, double, double)? hole,
  ) {
    final l = _light;
    if (l.stars <= 0.02) return;
    final b = _starGrains..clear();
    final t = view.time;
    final hy = view.screenY(view.height * _glassLine);
    final by = math.max(hy + 1, view.screenY(view.height));
    // Near the Lantern its light drowns the faint ones.
    final sun = Offset(
      screen.width * _sunX,
      view.screenY(view.height * (_horizon - _sunUp * 0.49)),
    );
    final drown = _sunUp > -0.1 ? l.glow : 0.0;
    for (var i = 0; i < _voidStars.length; i++) {
      final (fx, fy, size, warm, phase) = _voidStars[i];
      var x = fx * screen.width;
      var y = view.screenY(fy * view.height);
      if (y > hy) continue;
      var lvl = size.toDouble();
      // The hole hides what is behind it and pulls the stars round it
      // aside, brighter the nearer its edge.
      if (hole != null) {
        final (c, r, vis) = hole;
        final dx = x - c.dx, dy = y - c.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < r * 3.6) {
          if (d < r * 1.05) continue;
          final push = r * r * 1.15 / d * vis;
          x += dx / d * push;
          y += dy / d * push;
          lvl += (r * 2.2 / d).clamp(0.0, 1.0) * vis;
        }
      }
      if (drown > 0 && size == 0) {
        final d = (Offset(x, y) - sun).distance / screen.width;
        if (d < 0.3 * drown) continue;
      }
      final tw = 0.6 + 0.4 * math.sin(t * (0.6 + (i % 7) * 0.21) + phase);
      if (tw * l.stars < 0.25 && size == 0) continue;
      final level = (lvl * 0.9 + tw * l.stars * 1.6 - 0.6).round().clamp(0, 2);
      if (y < -4 || y > hy) continue;
      b.add(warm * 3 + level, x, y);
      // Given back by the glass, a little dimmer — and fewer of the faint
      // ones the further down it looks.
      final ry = 2 * hy - y;
      final f = (ry - hy) / (by - hy);
      if (level > 0 &&
          ry < screen.height + 4 &&
          fieldHash(i, 77) < _fresnel(f)) {
        b.add(warm * 3 + level - 1, x, ry);
      }
    }
    final z = _u * view.zoom;
    final a = l.stars.clamp(0.0, 1.0);
    for (final (warm, colour) in const [
      (0, Color(0xFFE2EAFF)),
      (1, Color(0xFFFFDCD2)),
    ]) {
      b
        ..draw(canvas, warm * 3, 1.1 * z, colour.withValues(alpha: 0.42 * a))
        ..draw(canvas, warm * 3 + 1, 1.5 * z, colour.withValues(alpha: 0.7 * a))
        ..draw(canvas, warm * 3 + 2, 5.5 * z, colour.withValues(alpha: 0.1 * a))
        ..draw(canvas, warm * 3 + 2, 2.0 * z, colour.withValues(alpha: a));
    }
  }

  /// The Lantern: a small white star with no rays, only its light round it
  /// — and, below the band, the Lantern again in the glass.
  void _paintLantern(Canvas canvas, Size screen, FieldView view) {
    final l = _light;
    if (_sunUp < -0.1 || l.glow <= 0.01) return;
    final z = _u * view.zoom;
    final hy = view.screenY(view.height * _glassLine);
    final by = math.max(hy + 1, view.screenY(view.height));
    final at = Offset(
      screen.width * _sunX,
      view.screenY(view.height * (_horizon - _sunUp * 0.49)),
    );
    final low = (1 - _sunUp * 2.5).clamp(0.0, 1.0);
    final disc = _sunDisc(low);
    final up = ((_sunUp + 0.1) / 0.16).clamp(0.0, 1.0);
    void glow(Offset o, double r, Color c, double a0, double a1) =>
        canvas.drawCircle(
          o,
          r,
          Paint()
            ..shader = Gradient.radial(
              o,
              r,
              [
                c.withValues(alpha: a0),
                c.withValues(alpha: a1),
                c.withValues(alpha: 0),
              ],
              const [0.0, 0.3, 1.0],
            ),
        );
    glow(at, screen.width * 0.6, l.rim, 0.2 * l.glow * up, 0.07 * l.glow * up);
    glow(at, 60 * z, disc, 0.42 * up, 0.12 * up);
    // Sunk into the band, the glass's far edge hides it.
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, 0, screen.width, hy));
    glow(at, 14 * z, disc, 0.95 * up, 0.5 * up);
    canvas
      ..drawCircle(at, 3.4 * z, Paint()..color = disc.withValues(alpha: up))
      ..restore();
    final ry = 2 * hy - at.dy;
    final k = _fresnel((ry - hy) / (by - hy)) * 0.7 * up;
    if (ry > screen.height + 60 * z || k <= 0.01) return;
    final image = Offset(at.dx, ry);
    canvas
      ..save()
      ..clipRect(Rect.fromLTRB(0, hy, screen.width, screen.height));
    glow(image, 46 * z, disc, 0.2 * k, 0.07 * k);
    canvas.restore();
  }

  /// The black hole: a dim one-sided glow, the far half of its ring, the
  /// dark where nothing comes back, and the near half of the ring over it
  /// — and all of it again, dimmer, upside down in the glass.
  void _paintHole(
    Canvas canvas,
    Size screen,
    FieldView view,
    (Offset, double, double) h,
  ) {
    final (c, r, vis) = h;
    final t = view.time;
    final hy = view.screenY(view.height * _glassLine);
    final by = math.max(hy + 1, view.screenY(view.height));
    final mirror = Offset(c.dx, 2 * hy - c.dy);
    final dim = _fresnel((mirror.dy - hy) / (by - hy));
    const flat = 0.24, roll = -0.17;
    final cr = math.cos(roll), sr = math.sin(roll);
    // The side whose grains come toward you is the bright one.
    final bright = c + Offset(-2.3 * r * cr, -2.3 * r * sr);
    for (final (o, a) in [
      (bright, vis),
      (Offset(bright.dx, 2 * hy - bright.dy), vis * dim * 0.6),
    ]) {
      canvas.drawCircle(
        o,
        r * 4.2,
        Paint()
          ..shader = Gradient.radial(
            o,
            r * 4.2,
            [
              const Color(0xFF7FE6DE).withValues(alpha: 0.16 * a),
              const Color(0xFF6E58C8).withValues(alpha: 0.06 * a),
              const Color(0x006E58C8),
            ],
            const [0.0, 0.45, 1.0],
          ),
      );
    }
    final back = _ringBack..clear(), front = _ringFront..clear();
    for (var i = 0; i < _ringGrains.length; i++) {
      final (rad, a0, phase) = _ringGrains[i];
      final a = a0 + t * 0.85 / (rad * math.sqrt(rad));
      final ca = math.cos(a), sa = math.sin(a);
      final px = ca * rad * r, py = sa * rad * r * flat;
      final x = c.dx + px * cr - py * sr, y = c.dy + px * sr + py * cr;
      final beam = math.pow(0.5 - 0.5 * ca, 1.6).toDouble();
      final tw = 0.5 + 0.5 * math.sin(t * 1.9 + phase);
      final hot = rad < 2.45 ? 0 : 3;
      final level = (beam * 2.2 + tw * 0.9 - 0.5 - (rad - 2) * 0.18)
          .round()
          .clamp(0, 2);
      final ring = sa < 0 ? back : front;
      if (y < hy) ring.add(hot + level, x, y);
      // Its image: what is behind the hole stays behind it in the glass.
      final ry = 2 * hy - y;
      if (level > 0 && ry > hy && fieldHash(i, 91) < dim) {
        ring.add(hot + level - 1, x, ry);
      }
    }
    void ring(GrainBatch b) {
      final g = 1.25 * _u * view.zoom;
      for (final (k, colour) in const [
        (0, Color(0xFFDDFFF8)),
        (3, Color(0xFF8E7EF0)),
      ]) {
        b
          ..draw(canvas, k, g, colour.withValues(alpha: 0.22 * vis))
          ..draw(canvas, k + 1, g * 1.15, colour.withValues(alpha: 0.5 * vis))
          ..draw(canvas, k + 2, g * 1.35, colour.withValues(alpha: 0.95 * vis));
      }
    }

    ring(back);
    void dark(Offset o, Rect clip) {
      canvas
        ..save()
        ..clipRect(clip)
        ..drawCircle(
          o,
          r * 1.32,
          Paint()
            ..shader = Gradient.radial(
              o,
              r * 1.32,
              [
                const Color(0xFF010103).withValues(alpha: vis),
                const Color(0xFF010103).withValues(alpha: vis),
                const Color(0x00010103),
              ],
              const [0.0, 0.72, 1.0],
            ),
        )
        ..restore();
    }

    dark(c, Rect.fromLTRB(0, 0, screen.width, hy));
    if (mirror.dy - r * 1.4 < screen.height) {
      dark(mirror, Rect.fromLTRB(0, hy, screen.width, screen.height));
    }
    ring(front);
  }

  // ── Weather: shooting stars, a meteor shower, the northern lights ───────

  /// How far in each of the Arcane's weathers is, 0 to 1.
  double get _shower => weatherKind == WeatherKind.meteors ? weather : 0;
  double get _aurora => weatherKind == WeatherKind.aurora ? weather : 0;

  @override
  double get _weatherKey => (_aurora * 1000).roundToDouble();

  static const _auroraGreen = Color(0xFF52F0B4);

  /// The hour's light under the northern lights: what they catch edged in
  /// green, from the whole sky at once rather than from one place in it,
  /// and the band lit a little by them.
  @override
  _Light _weathered(_Light l) {
    final a = _aurora;
    if (a <= 0.001) return l;
    final k = a * (0.35 + 0.65 * l.stars.clamp(0.0, 1.0));
    Color to(Color c, Color t, double f) => Color.lerp(c, t, f * k)!;
    return _Light(
      stops: l.stops,
      sky: [
        for (var i = 0; i < l.sky.length; i++)
          i >= 2 && i <= 5
              ? to(l.sky[i], const Color(0xFF103A3C), 0.22)
              : l.sky[i],
      ],
      ambient: to(l.ambient, const Color(0xFFA0EAD4), 0.2),
      rim: to(l.rim, _auroraGreen, 0.7),
      rimStrength:
          l.rimStrength + (math.max(l.rimStrength, 0.6) - l.rimStrength) * k,
      floor: l.floor + (0.65 - l.floor).clamp(0.0, 1.0) * k,
      glow: l.glow,
      stars: l.stars,
      cloudTop: to(l.cloudTop, const Color(0xFF1C4A56), 0.35),
      cloudBottom: to(l.cloudBottom, _auroraGreen, 0.55),
      cloudGlint: l.cloudGlint,
      grass: l.grass,
      mote: to(l.mote, _auroraGreen, 0.5),
      firefly: l.firefly,
    );
  }

  /// Meteors in flight (and the trains they leave), when the next lone
  /// shooting star comes, and the next of a shower's.
  final List<_Meteor> _meteors = [];
  final math.Random _fallRng = math.Random(29);
  double _nextFall = -1, _nextShowerFall = -1;
  final GrainBatch _meteorBatch = GrainBatch(10);

  /// Sends a lone shooting star over at once — for tests and previews.
  @visibleForTesting
  void debugShootingStar() => _nextFall = 0;

  /// How many meteors are in flight or still leaving a train.
  @visibleForTesting
  int get debugMeteors => _meteors.length;

  /// How many meteors are flying with their heads on the screen, at the
  /// field's clock [t] — for tests.
  @visibleForTesting
  int debugMeteorsInView(double t, Size screen) => _meteors.where((m) {
    final age = t - m.born;
    if (age < 0 || age > m.life) return false;
    final x = m.x0 + m.ux * m.speed * age, y = m.y0 + m.uy * m.speed * age;
    return x > 0 && x < screen.width && y > 0 && y < screen.height;
  }).length;

  /// Launches what is due: a lone shooting star every minute or so — the
  /// first a while after arriving, so only someone who stays sees one —
  /// and in a shower, one every second or so, more at its height.
  void _stepMeteors(Size screen, FieldView view) {
    final t = view.time;
    if (_nextFall < 0) _nextFall = t + 25 + _fallRng.nextDouble() * 45;
    if (t >= _nextFall) {
      _launch(screen, view, shower: false, born: t);
      _nextFall = t + 35 + _fallRng.nextDouble() * 50;
    }
    final s = _shower;
    if (s > 0.05) {
      if (_nextShowerFall < 0) _nextShowerFall = t + 0.3;
      // Each when it was due, even if no frame was drawn then, so the
      // shower keeps its pace through a dropped frame.
      while (t >= _nextShowerFall) {
        _launch(screen, view, shower: true, born: _nextShowerFall);
        _nextShowerFall +=
            (0.03 + _fallRng.nextDouble() * 0.2) / s.clamp(0.3, 1.0);
      }
    } else {
      _nextShowerFall = -1;
    }
    _meteors.removeWhere((m) => t - m.born > m.life + m.linger || m.born > t);
  }

  void _launch(
    Size screen,
    FieldView view, {
    required bool shower,
    required double born,
  }) {
    final r = _fallRng;
    final z = _u * view.zoom;
    final hy = view.screenY(view.height * _glassLine);
    double x0, y0, a;
    if (shower) {
      // Out of one point high in the void, as a real shower is: each
      // meteor first seen a way off from it, going away from it.
      final from = Offset(screen.width * 0.62, -hy * 0.22);
      a = math.pi * (0.24 + r.nextDouble() * 0.56);
      final off = (70 + r.nextDouble() * 220) * z;
      x0 = from.dx + math.cos(a) * off;
      y0 = from.dy + math.sin(a) * off;
    } else {
      x0 = screen.width * (0.12 + r.nextDouble() * 0.76);
      y0 = hy * (0.04 + r.nextDouble() * 0.36);
      a =
          math.pi *
          (r.nextBool()
              ? 0.6 + r.nextDouble() * 0.22
              : 0.18 + r.nextDouble() * 0.22);
    }
    final fireball = r.nextDouble() < (shower ? 0.12 : 0.15);
    final speed =
        (shower ? 260 + r.nextDouble() * 280 : 430 + r.nextDouble() * 260) * z;
    final ux = math.cos(a), uy = math.sin(a);
    var life = shower
        ? 0.35 + r.nextDouble() * 0.55
        : 0.55 + r.nextDouble() * 0.4;
    if (fireball) life *= 1.4;
    // Gone before it reaches the band.
    if (uy > 0) {
      life = math.min(life, math.max(0.2, (hy - 8 * z - y0) / (uy * speed)));
    }
    final tint = !shower
        ? 0
        : (r.nextDouble() < 0.3 ? 1 : (r.nextDouble() < 0.2 ? 2 : 0));
    _meteors.add(
      _Meteor(
        born: born,
        life: life,
        linger: fireball ? 1.6 : 0.9,
        x0: x0,
        y0: y0,
        ux: ux,
        uy: uy,
        speed: speed,
        length:
            (fireball
                ? 150
                : (shower
                      ? 50 + r.nextDouble() * 80
                      : 70 + r.nextDouble() * 60)) *
            z,
        bright: fireball ? 1 : (shower ? 0.7 : 0.55) + r.nextDouble() * 0.3,
        fireball: fireball,
        tint: tint,
      ),
    );
  }

  /// Each meteor: a bright head, a trail of grains tapering behind it, the
  /// grains it leaves along its way glowing a moment after, and all of it
  /// again upside down in the glass.
  void _paintMeteors(Canvas canvas, Size screen, FieldView view) {
    _stepMeteors(screen, view);
    if (_meteors.isEmpty) return;
    final b = _meteorBatch..clear();
    final t = view.time;
    final z = _u * view.zoom;
    final hy = view.screenY(view.height * _glassLine);
    final by = math.max(hy + 1, view.screenY(view.height));
    void add(int bucket, double x, double y, int level) {
      if (y >= hy) return;
      b.add(bucket, x, y);
      final ry = 2 * hy - y;
      if (level > 0 && ry < screen.height + 4) {
        final f = (ry - hy) / (by - hy);
        if (fieldHash((x * 7 + y).round(), 5) < _fresnel(f)) {
          b.add(bucket - 1, x, ry);
        }
      }
    }

    for (final m in _meteors) {
      final age = t - m.born;
      final flying = age < m.life;
      final f = (age / m.life).clamp(0.0, 1.0);
      final went = m.speed * math.min(age, m.life);
      final hx = m.x0 + m.ux * went, hyy = m.y0 + m.uy * went;
      final k = m.tint * 3;
      if (flying) {
        final env = math.pow(math.sin(math.pi * f), 0.5) * m.bright;
        final len = math.min(went, m.length);
        final n = (len / (1.3 * z)).ceil();
        for (var j = 1; j <= n; j++) {
          final s = j / n;
          final level = (math.pow(1 - s, 1.3) * env * 3.2).floor().clamp(0, 2);
          if (level <= 0 && fieldHash(j, m.tint + 3) > 0.5) continue;
          add(k + level, hx - m.ux * len * s, hyy - m.uy * len * s, level);
        }
        if (hyy < hy) {
          b.add(9, hx, hyy);
          if (2 * hy - hyy < screen.height) b.add(k + 2, hx, 2 * hy - hyy);
        }
      }
      // What it leaves behind it: grains that glow on a moment after the
      // head has passed, scattering as they fade — close behind it, where
      // they are still bright, never strung out along its whole way.
      final train = m.fireball ? 34 : 16;
      final reach = m.length * (m.fireball ? 2.2 : 1.4);
      for (var j = 0; j < train; j++) {
        final back = fieldHash(j, (m.born * 100).round()) * reach;
        final at = went - back;
        if (at <= 0) continue;
        final since = age - at / m.speed;
        if (since < 0.04) continue;
        final glow =
            math.exp(-since * (m.fireball ? 1.8 : 3.4)) * m.bright * 0.9;
        final level = (glow * 2.4).floor().clamp(0, 2);
        if (level <= 0) continue;
        final side = (fieldHash(j, 97) - 0.5) * 4 * z * (1 + since * 5);
        add(
          k + level - 1,
          m.x0 + m.ux * at - m.uy * side,
          m.y0 + m.uy * at + m.ux * side,
          level - 1,
        );
      }
    }
    final vis = 0.5 + 0.5 * _light.stars.clamp(0.0, 1.0);
    for (final (k, colour) in const [
      (0, Color(0xFFE6EEFF)),
      (3, Color(0xFFA8F6D2)),
      (6, Color(0xFFFFE4A6)),
    ]) {
      for (var level = 0; level < 3; level++) {
        b.draw(
          canvas,
          k + level,
          (1.2 + 0.35 * level) * z,
          colour.withValues(alpha: (0.3 + 0.32 * level) * vis),
        );
      }
    }
    b
      ..draw(
        canvas,
        9,
        7 * z,
        const Color(0xFFE6EEFF).withValues(alpha: 0.16 * vis),
      )
      ..draw(
        canvas,
        9,
        2.8 * z,
        const Color(0xFFFFFFFF).withValues(alpha: vis),
      );
  }

  // The northern lights: two curtains hung over the band, each a strip of
  // light from its lower hem up, in fine rays that drift along it and
  // pulses that run across it, given back by the glass.
  static const _auroraColumns = 180;
  final Float32List _auroraPos = Float32List(_auroraColumns * 4 * 2);
  final Int32List _auroraCol = Int32List(_auroraColumns * 4);
  late final Uint16List _auroraIdx = () {
    final idx = Uint16List((_auroraColumns - 1) * 3 * 6);
    var k = 0;
    for (var i = 0; i + 1 < _auroraColumns; i++) {
      for (var row = 0; row < 3; row++) {
        final a = i * 4 + row, b = a + 4;
        idx
          ..[k++] = a
          ..[k++] = b
          ..[k++] = a + 1
          ..[k++] = a + 1
          ..[k++] = b
          ..[k++] = b + 1;
      }
    }
    return idx;
  }();
  final GrainBatch _auroraBatch = GrainBatch(3);

  /// Each column's hem, lean, height and strength this frame, for both
  /// the curtain and its image.
  final Float32List _auroraHem = Float32List(_auroraColumns);
  final Float32List _auroraLean = Float32List(_auroraColumns);
  final Float32List _auroraTall = Float32List(_auroraColumns);
  final Float32List _auroraA = Float32List(_auroraColumns);

  static int _argb(int rgb, double a) =>
      ((a.clamp(0.0, 1.0) * 255).round() << 24) | rgb;

  void _paintAurora(Canvas canvas, Size screen, FieldView view) {
    final k = _aurora * (0.4 + 0.6 * _light.stars.clamp(0.0, 1.0));
    if (k < 0.01) return;
    final t = view.time;
    final z = _u * view.zoom;
    final hy = view.screenY(view.height * _glassLine);
    final by = math.max(hy + 1, view.screenY(view.height));
    final sparks = _auroraBatch..clear();
    const green = 0x52F0B4, violet = 0x8C62F2, between = 0x7590DE;
    final paint = Paint();
    for (final (base, tall, strength, seed) in const [
      (0.37, 0.3, 1.0, 5),
      (0.26, 0.2, 0.7, 9),
    ]) {
      final y0 = view.screenY(view.height * base);
      final rise = view.height * tall * view.zoom;
      for (var i = 0; i < _auroraColumns; i++) {
        final u = i / (_auroraColumns - 1);
        // Its hem folds and slowly drifts; its rays stand along it.
        _auroraHem[i] =
            y0 +
            24 * z * math.sin(u * 4.2 + t * 0.05 + seed) +
            8 * z * math.sin(u * 11 + t * 0.11 + seed * 2);
        _auroraLean[i] = 12 * z * math.sin(u * 6.5 + t * 0.07 + seed);
        _auroraTall[i] =
            rise * (0.8 + 0.2 * math.sin(u * 9.3 + seed + t * 0.04));
        final ray =
            0.45 + 0.55 * (0.5 + 0.5 * fieldNoise(u * 95 + t * 0.5, seed));
        final pulse = 0.55 + 0.45 * math.sin(u * 8 - t * 0.65 + seed);
        final patch = 0.5 + 0.5 * fieldNoise(u * 3.2 + t * 0.03, seed + 1);
        _auroraA[i] =
            (k * strength * ray * pulse * (0.25 + 0.75 * patch * patch)).clamp(
              0.0,
              1.0,
            );
      }
      for (final image in const [false, true]) {
        final dim = image ? 0.6 * _fresnel((hy - y0) / (by - hy)) : 1.0;
        for (var i = 0; i < _auroraColumns; i++) {
          final x =
              -12 * z + (screen.width + 24 * z) * i / (_auroraColumns - 1);
          final yb = _auroraHem[i], hr = _auroraTall[i];
          final lean = _auroraLean[i], a = _auroraA[i] * dim;
          final v = i * 4;
          final p = v * 2;
          double y(double y) => image ? 2 * hy - y : y;
          _auroraPos
            ..[p] = x
            ..[p + 1] = y(yb + 7 * z)
            ..[p + 2] = x
            ..[p + 3] = y(yb)
            ..[p + 4] = x + lean * 0.5
            ..[p + 5] = y(yb - hr * 0.45)
            ..[p + 6] = x + lean
            ..[p + 7] = y(yb - hr);
          _auroraCol
            ..[v] = _argb(green, 0)
            ..[v + 1] = _argb(green, 0.72 * a)
            ..[v + 2] = _argb(between, 0.4 * a)
            ..[v + 3] = _argb(violet, 0);
          // Grains glittering along the hem where it burns brightest.
          if (!image &&
              a > 0.42 &&
              fieldHash(i, seed + (t * 6).floor()) < 0.5) {
            sparks.add(
              a > 0.62 ? 2 : 1,
              x + (fieldHash(i, 3) - 0.5) * 4 * z,
              yb - fieldHash(i, 7) * hr * 0.3,
            );
          }
        }
        if (image) {
          canvas
            ..save()
            ..clipRect(Rect.fromLTRB(0, hy, screen.width, screen.height));
        }
        canvas.drawVertices(
          Vertices.raw(
            VertexMode.triangles,
            _auroraPos,
            colors: _auroraCol,
            indices: _auroraIdx,
          ),
          BlendMode.srcOver,
          paint,
        );
        if (image) canvas.restore();
      }
    }
    for (var level = 1; level < 3; level++) {
      sparks.draw(
        canvas,
        level,
        (1.2 + 0.3 * level) * z,
        const Color(0xFFC8FFE8).withValues(alpha: 0.35 * level * k),
      );
    }
  }

  // ── Far: the dust band and its image ─────────────────────────────────────

  /// The band of dust across the void where a horizon would be: soft veils
  /// with a luminous hem, and thousands of grains through them parted by a
  /// darker rift — lifted [lift] of the height above where it was drawn.
  void _paintDustBand(Canvas c, double w, {double lift = 0}) {
    c
      ..save()
      ..translate(0, -lift * _h);
    final p = _loop ? w : 0.0;
    double n(double x, double wave, int seed) =>
        fieldLoopNoise(x, wave * _u, seed, p);
    // Veils: long lenses of soft colour, their lower edges lit.
    final r = FieldRandom(808);
    const veils = [
      (0.55, 46.0, 0.34),
      (0.6, 28.0, 0.26),
      (0.47, 34.0, 0.16),
      (0.38, 22.0, 0.1),
      (0.64, 24.0, 0.14),
    ];
    for (var v = 0; v < veils.length; v++) {
      final (cy, thick, a) = veils[v];
      final seed = 40 + v * 7;
      final step = 6 * _u;
      double centre(double x) =>
          _h * cy + 16 * _u * n(x, 260, seed) + 6 * _u * n(x, 90, seed + 1);
      double half(double x) =>
          thick *
          _u *
          (0.55 + 0.45 * n(x, 320, seed + 2)) *
          (0.7 + 0.3 * n(x, 70, seed + 3)).clamp(0.05, 1.0);
      for (final (lo, hi, rMap, alpha) in [
        (-1.0, 0.0, 0.0, a),
        (0.0, 1.0, 0.7, a * 0.9),
      ]) {
        final path = Path()..moveTo(-8 * _u, centre(-8 * _u));
        for (var x = -8 * _u; x <= w + 8 * _u; x += step) {
          path.lineTo(x, centre(x) + half(x) * lo);
        }
        for (var x = w + 8 * _u; x >= -8 * _u; x -= step) {
          path.lineTo(x, centre(x) + half(x) * hi);
        }
        final y0 = _h * cy - thick * _u, y1 = _h * cy + thick * _u;
        c.drawPath(
          path..close(),
          Paint()
            ..shader = Gradient.linear(
              Offset(0, lo < 0 ? y0 : _h * cy),
              Offset(0, lo < 0 ? _h * cy : y1),
              lo < 0
                  ? [fieldMap(0, 0, 0, 0), fieldMap(0, 0, 0, alpha)]
                  : [fieldMap(0, 0, 0, alpha), fieldMap(rMap, 0, 0, 0)],
            ),
        );
      }
    }
    // The dust: grains thick along the band's middle, thinning away from
    // it, and few along the rift through it.
    final grains = GrainBatch(4);
    final count = (w * 6.5 / _u).round();
    for (var i = 0; i < count; i++) {
      final x = r.next() * w;
      final band = _h * 0.555 + 14 * _u * n(x, 240, 61) + 5 * _u * n(x, 60, 62);
      final spread = (20 + 12 * n(x, 300, 63)) * _u;
      final g = (r.next() + r.next() + r.next() - 1.5) / 1.5;
      final y = band + g * spread * 1.6;
      final rift = band + 3 * _u + 3 * _u * n(x, 80, 64);
      final inRift = ((y - rift) / (3.6 * _u)).abs();
      if (inRift < 1 && r.next() < 0.8 * (1 - inRift)) continue;
      final clump = 0.5 + 0.5 * n(x, 46, 65);
      if (r.next() > 0.35 + 0.65 * clump) continue;
      final near = 1 - g.abs();
      final level = (near * 2.4 + r.next() * 1.2 - 0.4).round().clamp(0, 3);
      grains.add(level, x, y);
      if (level >= 2 && r.next() < 0.025) _glint(x, y - lift * _h);
    }
    for (var k = 0; k < 4; k++) {
      grains.draw(c, k, 1.15 * _u, fieldMap(0, 1, 0, 0.22 + k * 0.22));
    }
    c.restore();
  }

  /// The far sheet: the band over the glass, the band again in the glass
  /// — fainter, and nothing of it above where the glass begins — and a
  /// thin haze lying on the glass's far edge.
  void _paintFar(Canvas c, double w) {
    final hy = _h * _glassLine;
    final m = 8 * _u;
    final above = Rect.fromLTRB(-m, 0, w + m, hy);
    final below = Rect.fromLTRB(-m, hy, w + m, _h);
    c
      ..save()
      ..clipRect(above);
    _sinking(far, () => _paintDustBand(c, w, lift: _bandLift));
    c
      ..restore()
      ..save()
      ..clipRect(below)
      ..saveLayer(below, Paint()..color = const Color(0x6B000000))
      ..translate(0, 2 * hy)
      ..scale(1, -1);
    _paintDustBand(c, w, lift: _bandLift);
    c
      ..restore()
      ..restore()
      ..drawRect(
        Rect.fromLTRB(-m, hy - 7 * _u, w + m, hy + 12 * _u),
        Paint()
          ..shader = Gradient.linear(
            Offset(0, hy - 7 * _u),
            Offset(0, hy + 12 * _u),
            [
              fieldMap(0.35, 0, 0, 0),
              fieldMap(0.5, 0, 0, 0.3),
              fieldMap(0.3, 0, 0, 0),
            ],
            const [0.0, 0.4, 1.0],
          ),
      );
  }

  // ── The needle ───────────────────────────────────────────────────────────

  /// Where the needle stands on its loop (a share), how wide its foot is
  /// and how tall it is, at the reference height.
  static const _needleX = 0.46, _needleFoot = 40.0, _needleTall = 0.455;

  /// The needle's outline, from its foot on the left up to its summit and
  /// down to its foot on the right: (across, in half-widths of its foot;
  /// up, in shares of its height). A thin main spire, a lesser one split
  /// off its right shoulder, teeth down its left.
  static const _needleOutline = <(double, double)>[
    (-1.0, 0.0),
    (-0.86, 0.06),
    (-0.92, 0.1),
    (-0.7, 0.19),
    (-0.75, 0.25),
    (-0.54, 0.33),
    (-0.63, 0.41),
    (-0.42, 0.46),
    (-0.36, 0.57),
    (-0.41, 0.62),
    (-0.24, 0.71),
    (-0.2, 0.81),
    (-0.12, 0.87),
    (-0.08, 0.95),
    (0.0, 1.0),
    (0.06, 0.95),
    (0.1, 0.86),
    (0.16, 0.8),
    (0.13, 0.74),
    (0.22, 0.7),
    (0.3, 0.79),
    (0.37, 0.71),
    (0.4, 0.62),
    (0.5, 0.55),
    (0.47, 0.48),
    (0.6, 0.4),
    (0.66, 0.3),
    (0.61, 0.26),
    (0.8, 0.16),
    (0.86, 0.08),
    (1.0, 0.0),
  ];

  /// The ridge down its face from the summit, the side of it toward the
  /// light pale; and the ridge down from the lesser spire.
  static const _needleRidge = <(double, double)>[
    (0.0, 1.0),
    (-0.08, 0.78),
    (-0.13, 0.6),
    (-0.2, 0.42),
    (-0.26, 0.22),
    (-0.34, -0.02),
  ];
  static const _needleRidge2 = <(double, double)>[
    (0.3, 0.79),
    (0.32, 0.6),
    (0.42, 0.42),
    (0.5, 0.2),
    (0.6, -0.02),
  ];

  /// The ledges across its pale side: (up, how far across from the left
  /// edge toward the ridge it reaches).
  static const _needleLedges = <(double, double)>[
    (0.2, 0.8),
    (0.36, 0.65),
    (0.52, 0.9),
    (0.67, 0.7),
    (0.83, 0.6),
  ];

  /// The needle's maps at [x], its foot at [base]: its pale side, its face,
  /// its dark side, the ledges across it — and with [image] its image in
  /// the glass under it instead.
  void _paintNeedle(Canvas c, double x, double base, {bool image = false}) {
    final bw = _needleFoot * _u, tall = _h * _needleTall;
    Offset at((double, double) p) => Offset(x + p.$1 * bw, base - p.$2 * tall);
    final outline = Path()
      ..addPolygon([for (final p in _needleOutline) at(p)], true);
    if (image) {
      final fade = Rect.fromLTRB(
        x - bw * 1.5,
        base,
        x + bw * 1.5,
        base + tall * 0.7,
      );
      c
        ..saveLayer(fade, Paint())
        ..save()
        ..translate(0, 2 * base)
        ..scale(1, -1);
      _paintNeedle(c, x, base);
      c
        ..restore()
        ..drawRect(
          fade,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = Gradient.linear(fade.topCenter, fade.bottomCenter, [
              const Color(0x88FFFFFF),
              const Color(0x00FFFFFF),
            ]),
        )
        ..restore();
      return;
    }
    // Hazed by the distance, more so where mist lies at its foot.
    Paint plane(double shade, [double gloss = 0]) => Paint()
      ..shader = Gradient.linear(Offset(0, base - tall), Offset(0, base), [
        fieldMap(0.1, gloss, shade),
        fieldMap(0.3, gloss * 0.5, shade),
      ]);
    c
      ..drawPath(outline, plane(0.93))
      ..save()
      ..clipPath(outline);
    final ridge = [for (final p in _needleRidge) at(p)];
    final ridge2 = [for (final p in _needleRidge2) at(p)];
    c
      ..drawPath(
        Path()..addPolygon([
          Offset(x - bw * 1.6, base + 2 * _u),
          Offset(x - bw * 1.6, base - tall - 4 * _u),
          ...ridge,
        ], true),
        plane(0.36, 0.16),
      )
      ..drawPath(
        Path()..addPolygon([...ridge, ...ridge2.reversed], true),
        plane(0.7, 0.03),
      );
    // Ledges: a shadowed sill under each, tapering out toward the ridge.
    for (final (v, reach) in _needleLedges) {
      final y = base - v * tall;
      final left = x - bw * 1.2;
      final ridgeX = x + (-0.34 + 0.34 * v) * bw;
      final right = left + (ridgeX - left) * reach;
      c.drawPath(
        Path()
          ..moveTo(left, y)
          ..lineTo(right, y + 1.5 * _u)
          ..lineTo(left, y + 3.2 * _u)
          ..close(),
        Paint()..color = fieldMap(0.2, 0, 0.88, 0.9),
      );
    }
    c.restore();
  }

  /// The needle's light: its pale side's outer edge, its ridge, the lesser
  /// spire's, glints on its points — and with [image] the same, faint, in
  /// the glass.
  void _paintNeedleLight(
    Canvas c,
    double x,
    double base, {
    bool image = false,
  }) {
    final bw = _needleFoot * _u, tall = _h * _needleTall;
    Offset at((double, double) p) => Offset(x + p.$1 * bw, base - p.$2 * tall);
    if (image) {
      final fade = Rect.fromLTRB(
        x - bw * 1.5,
        base,
        x + bw * 1.5,
        base + tall * 0.7,
      );
      final sink = _sink;
      _sink = null;
      c
        ..saveLayer(fade, Paint())
        ..save()
        ..translate(0, 2 * base)
        ..scale(1, -1);
      _paintNeedleLight(c, x, base);
      c
        ..restore()
        ..drawRect(
          fade,
          Paint()
            ..blendMode = BlendMode.dstIn
            ..shader = Gradient.linear(fade.topCenter, fade.bottomCenter, [
              const Color(0x55FFFFFF),
              const Color(0x00FFFFFF),
            ]),
        )
        ..restore();
      _sink = sink;
      return;
    }
    void sliver(List<Offset> pts, double w, double a) {
      final path = Path()..moveTo(pts.first.dx - w, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx - w * 0.3, p.dy);
      }
      for (final p in pts.reversed) {
        path.lineTo(p.dx + w * 0.4, p.dy);
      }
      c.drawPath(
        path..close(),
        Paint()
          ..shader = Gradient.linear(pts.first, pts.last, [
            const Color(0xFFFFFFFF).withValues(alpha: a),
            const Color(0x00FFFFFF),
          ]),
      );
    }

    // The pale side's outer edge, from the summit down.
    sliver(
      [
        for (final p in _needleOutline.take(15).toList().reversed)
          at(p) + Offset(1.2 * _u, 0),
      ],
      1.6 * _u,
      0.95,
    );
    sliver([for (final p in _needleRidge.take(4)) at(p)], 1.5 * _u, 0.6);
    sliver([for (final p in _needleRidge2.take(3)) at(p)], 1.3 * _u, 0.45);
    for (final p in const [(0.0, 1.0), (0.3, 0.79), (-0.63, 0.41)]) {
      final o = at(p);
      _glint(o.dx, o.dy + 1 * _u);
    }
  }

  List<FieldSheet> _needleSheets(double w) {
    final bw = _needleFoot * _u, tall = _h * _needleTall;
    final base = _h * _glassLine + 3 * _u;
    final x = _needleX * w;
    final b = Rect.fromLTRB(
      x - bw * 1.3,
      base - tall - 6 * _u,
      x + bw * 1.3,
      base + tall * 0.7,
    );
    return [
      FieldSheet(
        bounds: b,
        resolution: 0.9,
        grade: _gStone,
        paint: (c) {
          _paintNeedle(c, x, base, image: true);
          _paintNeedle(c, x, base);
        },
      ),
      FieldSheet(
        bounds: b,
        resolution: 0.8,
        light: true,
        paint: (c) => _sinking(far, () {
          _paintNeedleLight(c, x, base, image: true);
          _paintNeedleLight(c, x, base);
        }),
      ),
    ];
  }

  // ── Standing stones ──────────────────────────────────────────────────────

  /// Standing stones on the glass: (x as a share of the loop, foot as a
  /// share of the height, width, height) at the reference height.
  static const _farStones = <(double, double, double, double)>[
    (0.06, 0.574, 4, 16),
    (0.21, 0.571, 3, 10),
    (0.33, 0.578, 6, 22),
    (0.62, 0.572, 3, 12),
    (0.74, 0.576, 5, 18),
    (0.88, 0.573, 3, 9),
  ];
  static const _midStones = <(double, double, double, double)>[
    (0.13, 0.62, 12, 64),
    (0.6, 0.6, 9, 40),
    (0.86, 0.63, 15, 86),
  ];
  static const _nearStones = <(double, double, double, double)>[
    (0.03, 0.86, 30, 150),
    (0.44, 0.8, 22, 104),
    (0.92, 0.9, 40, 210),
  ];

  List<(double, double, double, double)> _stonesOf(SceneLayer layer) =>
      switch (layer) {
        far => _farStones,
        mid => _midStones,
        near => _nearStones,
        _ => const [],
      };

  /// A standing stone at [x] on the glass, its foot at [base], broken off
  /// at its top, and its image in the glass under it — fainter further
  /// down.
  void _paintStone(
    Canvas c,
    double x,
    double base,
    double w,
    double h,
    int seed, {
    required double haze,
    bool light = false,
  }) {
    final r = FieldRandom(seed);
    final lean = r.range(-0.06, 0.06) * h;
    final peak = Offset(x + w * r.range(-0.2, 0.3) + lean, base - h);
    final pts = [
      Offset(x - w / 2, base),
      Offset(x - w * 0.46 + lean * 0.9, base - h * r.range(0.8, 0.88)),
      Offset(x - w * 0.18 + lean * 0.96, base - h * r.range(0.9, 0.95)),
      peak,
      Offset(peak.dx + w * 0.16, peak.dy + h * r.range(0.06, 0.12)),
      Offset(x + w * 0.5 + lean * 0.95, base - h * r.range(0.82, 0.92)),
      Offset(x + w / 2, base),
    ];
    final lit = [
      pts[0],
      pts[1],
      pts[2],
      peak,
      Offset(x - w * 0.2 + lean * 0.3, base),
    ];
    Path poly(List<Offset> p, {bool flip = false}) => Path()
      ..addPolygon([
        for (final o in p) flip ? Offset(o.dx, 2 * base - o.dy) : o,
      ], true);
    if (light) {
      c.drawPath(
        poly([
          pts[0],
          pts[1],
          pts[2],
          peak,
          Offset(peak.dx - w * 0.1, peak.dy + h * 0.1),
          Offset(x - w * 0.38, base),
        ]),
        Paint()
          ..shader = Gradient.linear(Offset(0, base - h), Offset(0, base), [
            const Color(0xFFFFFFFF).withValues(alpha: 0.5),
            const Color(0xFFFFFFFF).withValues(alpha: 0.12),
          ]),
      );
      _glint(peak.dx, peak.dy + 1 * _u);
      return;
    }
    // Its image first, faint and going dark with depth.
    c.drawPath(
      poly(pts, flip: true),
      Paint()
        ..shader = Gradient.linear(Offset(0, base), Offset(0, base + h), [
          fieldMap(haze, 0, 0.8, 0.5),
          fieldMap(haze, 0, 0.9, 0),
        ]),
    );
    c
      ..drawPath(poly(pts), Paint()..color = fieldMap(haze, 0, 0.9))
      ..drawPath(poly(lit), Paint()..color = fieldMap(haze, 0.03, 0.72));
  }

  List<FieldSheet> _stoneSheets(SceneLayer layer, double w, double haze) {
    final stones = _stonesOf(layer);
    void each(Canvas c, bool light) {
      for (var i = 0; i < stones.length; i++) {
        final (fx, fy, sw, sh) = stones[i];
        _wrapped(fx * w, sw * _u, w, (x) {
          _paintStone(
            c,
            x,
            fy * _h,
            sw * _u,
            sh * _u,
            300 + i + layer.index * 20,
            haze: haze,
            light: light,
          );
        });
      }
    }

    final top = stones.map((s) => s.$2 * _h - s.$4 * _u).reduce(math.min);
    final bottom = stones.map((s) => s.$2 * _h + s.$4 * _u).reduce(math.max);
    final b = Rect.fromLTRB(-8 * _u, top - 4 * _u, w - 0.5, bottom + 4 * _u);
    return [
      FieldSheet(
        bounds: b,
        resolution: layer == far ? 0.7 : 0.9,
        grade: layer == far ? _gFar : _gStone,
        paint: (c) => each(c, false),
      ),
      FieldSheet(
        bounds: b,
        resolution: 0.8,
        light: true,
        paint: (c) => _sinking(layer, () => each(c, true)),
      ),
    ];
  }

  // ── Layout for the current screen ────────────────────────────────────────

  _Motes? _motes;

  @override
  List<FieldSheet> build(SceneLayer layer, Size size, Size screen) {
    _h = size.height;
    _u = _h / 475;
    _screen = screen;
    final w = size.width;
    _widths[layer] = w;
    // Full-width sheets reach back past the loop's start, so the next
    // copy's overlap covers the seam (see the Volcano).
    final m = 8 * _u;
    switch (layer) {
      case far:
        _glints[far] = _Glints();
        return [
          FieldSheet(
            bounds: Rect.fromLTRB(-m, _h * 0.2, w - 0.5, _h * 0.82),
            resolution: 0.6,
            grade: _gVeil,
            paint: (c) => _paintFar(c, w),
          ),
          ..._needleSheets(w),
          ..._stoneSheets(far, w, 0.6),
        ];
      case mid:
        return _stoneSheets(mid, w, 0.3);
      case near:
        _glints[near] = _Glints();
        _motes = _Motes.make(w, _h, _u);
        return _stoneSheets(near, w, 0);
      default:
        return const [];
    }
  }

  @override
  bool hasLive(SceneLayer layer, {required bool front}) => switch (layer) {
    near => true,
    far => !front,
    _ => false,
  };

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
        _paintGlints(canvas, view, far, _glints[far], size: 0.7, alpha: 0.8);
      case near:
        if (!front) {
          _wakeGlass(view);
          _paintGlints(canvas, view, near, _glints[near], size: 1.1);
          _paintPools(canvas, view);
        } else {
          _paintLifted(canvas, view);
          _paintVoidMotes(canvas, view, near);
        }
      default:
        break;
    }
  }

  // ── A finger on the glass ────────────────────────────────────────────────

  /// Light a finger woke in the glass: where (near-layer units), when, how
  /// big — smaller toward the band, where the glass is further off — and
  /// whether a tap woke it (a drag's fade sooner).
  final List<(double, double, double, double, bool)> _pools = [];
  final _Lift _lifted = _Lift(320);
  double _woke = -1;
  double? _wokeLeft;

  /// Takes in this frame's fingers: wherever one is on the glass, light
  /// pools under it and grains of light rise off it — a tap a burst, a drag
  /// a trail of them.
  void _wakeGlass(FieldView view) {
    final now = view.time;
    final stirs = _stirsFor(near, view);
    final hy = _h * _glassLine;
    // The camera wraps round the loop in a whole loop's jump; what the
    // finger woke goes with it.
    final period = _period(near);
    final left = _wokeLeft;
    if (period > 0 && left != null && (view.left - left).abs() > period / 2) {
      final jump = period * ((view.left - left) / period).roundToDouble();
      for (var i = 0; i < _pools.length; i++) {
        final (x, y, born, r, tap) = _pools[i];
        _pools[i] = (x + jump, y, born, r, tap);
      }
      _lifted.shift(jump);
    }
    _wokeLeft = view.left;
    final rand = _lifted.rand;
    var newest = _woke;
    for (final p in stirs) {
      if (p.time <= _woke) continue;
      if (p.time > newest) newest = p.time;
      final tap = p.speed < 0.5;
      if (p.y < hy + 2 * _u) {
        // Over the glass a finger stirs the void's dust: a few grains of it
        // drift off the finger, given back below the band.
        final n = tap ? 26 : (rand() < 0.6 ? 1 : 0);
        for (var i = 0; i < n; i++) {
          final a = rand() * math.pi * 2, v = (10 + rand() * 30) * _u;
          _lifted.spawn(
            x: p.x + (rand() - 0.5) * 10 * _u,
            y: p.y + (rand() - 0.5) * 10 * _u,
            vx: math.cos(a) * v + p.dir * p.speed * 1.5 * _u,
            vy: math.sin(a) * v * 0.6,
            life: 1.6 + rand() * 1.6,
            mirror: hy,
            dust: true,
          );
        }
        continue;
      }
      final k = ((p.y / _h - _glassLine) / (1 - _glassLine)).clamp(0.1, 1.0);
      final last = _pools.isEmpty ? null : _pools.last;
      final spaced =
          last == null ||
          (Offset(last.$1, last.$2) - Offset(p.x, p.y)).distance > 34 * _u * k;
      if (tap || spaced) {
        _pools.add((p.x, p.y, p.time, (tap ? 52 : 26) * _u * k, tap));
        if (_pools.length > 9) _pools.removeAt(0);
      }
      // A tap lifts a burst; a drag a grain or two now and then, each from
      // its own height off the glass so they never line up.
      final n = tap ? 22 : (rand() < 0.55 ? 1 : 0);
      for (var i = 0; i < n; i++) {
        _lifted.spawn(
          x: p.x + (rand() - 0.5) * 22 * _u * k,
          y: p.y - rand() * (tap ? 10 : 16) * _u * k,
          vx: (rand() - 0.5) * 24 * _u * k + p.dir * p.speed * 1.5 * _u,
          vy: -(14 + rand() * 40) * _u * k,
          life: 1.3 + rand() * 1.9,
          mirror: p.y,
        );
      }
    }
    _woke = newest;
    _pools.removeWhere((p) => now - p.$3 > 2.6 || p.$3 > now);
    _lifted.step(now);
  }

  /// The pools of light in the glass: flat (the glass is seen low across),
  /// coming up at once and fading slow, spreading as they go.
  void _paintPools(Canvas canvas, FieldView view) {
    if (_pools.isEmpty) return;
    final c = _light.cloudBottom;
    for (final (x, y, born, r, tap) in _pools) {
      final age = view.time - born;
      final a =
          math.min(1.0, age / 0.07) *
          math.exp(-age * (tap ? 1.5 : 2.6)) *
          (tap ? 1 : 0.7);
      if (a < 0.01) continue;
      final rad = r * (0.7 + 0.55 * (1 - math.exp(-age * 2.2)));
      canvas
        ..save()
        ..translate(x, y)
        ..scale(1, 0.34)
        ..drawCircle(
          Offset.zero,
          rad,
          Paint()
            ..shader = Gradient.radial(
              Offset.zero,
              rad,
              [
                c.withValues(alpha: 0.55 * a),
                c.withValues(alpha: 0.18 * a),
                c.withValues(alpha: 0),
              ],
              const [0.0, 0.4, 1.0],
            ),
        )
        ..restore();
    }
  }

  final GrainBatch _liftBatch = GrainBatch(8);

  /// The grains a finger lifted off the glass, rising and slowing as they
  /// fade, each with its image in the glass going down under it.
  void _paintLifted(Canvas canvas, FieldView view) {
    final g = _lifted;
    final b = _liftBatch..clear();
    var any = false;
    for (var i = 0; i < g.cap; i++) {
      if (g.life[i] <= 0) continue;
      final f = g.age[i] / g.life[i];
      final tw = 0.65 + 0.35 * math.sin(view.time * 6 + i * 1.7);
      final level = (math.min(1.0, f * 9) * (1 - f) * tw * 3.99).floor();
      if (level <= 0) continue;
      final kind = g.dust[i] ? 4 : 0;
      b.add(kind + level, g.x[i], g.y[i]);
      final ry = 2 * g.y0[i] - g.y[i];
      if (level > 1 && ry > g.y[i]) b.add(kind + level - 1, g.x[i], ry);
      any = true;
    }
    if (!any) return;
    for (final (kind, c) in [(0, _light.mote), (4, _light.cloudGlint)]) {
      for (var lv = 1; lv < 4; lv++) {
        b
          ..draw(canvas, kind + lv, 4.5 * _u, c.withValues(alpha: 0.05 * lv))
          ..draw(canvas, kind + lv, 1.6 * _u, c.withValues(alpha: 0.3 * lv));
      }
    }
  }

  /// Motes adrift over the glass: the shared motes, without the wide halos
  /// that read as bubbles against the dark.
  void _paintVoidMotes(Canvas canvas, FieldView view, SceneLayer layer) {
    final m = _motes;
    if (m == null) return;
    final l = _light;
    _moteBatch.clear();
    final t = view.time;
    final span = m.yBottom - m.yTop;
    final shifts = _shiftsFor(layer, view, 10);
    for (var i = 0; i < m.n; i += 2) {
      final rise = (m.yBottom - m.y0[i] + t * m.speed[i] * 0.5) % span;
      final y = m.yBottom - rise + 6 * _u * math.sin(t * 0.5 + i);
      var x = (m.x0[i] + 9 * _u * math.sin(t * 0.3 + m.phase[i])) % m.width;
      for (final sh in shifts) {
        if (x + sh >= view.left - 10 && x + sh <= view.right + 10) {
          x += sh;
          break;
        }
      }
      if (x < view.left - 10 || x > view.right + 10) continue;
      final life = rise / span;
      final fade = math.min(1.0, life * 6) * math.min(1.0, (1 - life) * 3);
      final blink = math.pow(
        0.5 + 0.5 * math.sin(t * (0.9 + m.phase[i] * 0.3) + m.phase[i] * 5),
        3,
      );
      final level = (fade * (0.35 + 0.65 * blink) * 3.99).floor();
      if (level <= 0) continue;
      _moteBatch.add(level, x, y);
    }
    for (var lv = 1; lv < 4; lv++) {
      _moteBatch
        ..draw(canvas, lv, 4 * _u, l.mote.withValues(alpha: 0.035 * lv))
        ..draw(canvas, lv, 1.6 * _u, l.mote.withValues(alpha: 0.28 * lv));
    }
  }
}

/// A meteor across the void, in screen pixels: when it came, how long it
/// flies and how long what it leaves glows after, where it came from and
/// which way it goes, how fast, how long its trail, how bright, whether a
/// fireball, and its colour (0 white, 1 green, 2 gold).
class _Meteor {
  _Meteor({
    required this.born,
    required this.life,
    required this.linger,
    required this.x0,
    required this.y0,
    required this.ux,
    required this.uy,
    required this.speed,
    required this.length,
    required this.bright,
    required this.fireball,
    required this.tint,
  });

  final double born, life, linger, x0, y0, ux, uy, speed, length, bright;
  final bool fireball;
  final int tint;
}

/// Grains of light a finger lifted off the glass (or stirred out of the
/// void's dust), as a fixed pool: each remembers the line of glass its
/// image lies across, so the image can go the other way.
class _Lift {
  _Lift(this.cap)
    : dust = List.filled(cap, false),
      x = Float32List(cap),
      y = Float32List(cap),
      y0 = Float32List(cap),
      vx = Float32List(cap),
      vy = Float32List(cap),
      age = Float32List(cap),
      life = Float32List(cap);

  final int cap;
  final List<bool> dust;
  final Float32List x, y, y0, vx, vy, age, life;
  int _next = 0;
  double _clock = -1;
  final math.Random _r = math.Random(17);

  double rand() => _r.nextDouble();

  void spawn({
    required double x,
    required double y,
    required double vx,
    required double vy,
    required double life,
    required double mirror,
    bool dust = false,
  }) {
    final i = _next;
    _next = (_next + 1) % cap;
    this.dust[i] = dust;
    this.x[i] = x;
    this.y[i] = y;
    y0[i] = mirror;
    this.vx[i] = vx;
    this.vy[i] = vy;
    age[i] = 0;
    this.life[i] = life;
  }

  void shift(double dx) {
    for (var i = 0; i < cap; i++) {
      x[i] += dx;
    }
  }

  /// Moves every grain on to [now]: rising, slowing, drifting apart.
  void step(double now) {
    final dt = _clock < 0 ? 0.0 : (now - _clock).clamp(0.0, 0.1);
    _clock = now;
    if (dt <= 0) return;
    final drag = math.exp(-1.4 * dt);
    for (var i = 0; i < cap; i++) {
      if (life[i] <= 0) continue;
      age[i] += dt;
      if (age[i] >= life[i]) {
        life[i] = 0;
        continue;
      }
      vx[i] *= drag;
      vy[i] *= drag;
      x[i] += vx[i] * dt;
      y[i] += vy[i] * dt;
    }
  }
}

// ── The day in the void ────────────────────────────────────────────────────

const _arcaneStops = [0.0, 0.18, 0.34, 0.46, 0.55, 0.62, 0.72, 0.86, 1.0];

const _arcaneNight = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF020107),
    Color(0xFF05030F),
    Color(0xFF0A0719),
    Color(0xFF110C27),
    Color(0xFF181033),
    Color(0xFF130D2A),
    Color(0xFF0B081C),
    Color(0xFF060411),
    Color(0xFF03020A),
  ],
  ambient: Color(0xFF7E7AA8),
  rim: Color(0xFF8CEFE4),
  rimStrength: 0.5,
  floor: 0.32,
  glow: 0,
  stars: 1,
  cloudTop: Color(0xFF2E1C5C),
  cloudBottom: Color(0xFF3ACFC4),
  cloudGlint: Color(0xFFCDE6FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0915),
    Color(0xFF141228),
    Color(0xFF1E2042),
    Color(0xFF283C5E),
    Color(0xFF336A80),
    Color(0xFF4FA2AE),
    Color(0xFF92E6E0),
  ],
  mote: Color(0xFF9AF2EA),
  firefly: 0.55,
);

const _arcanePreDawn = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF03020A),
    Color(0xFF070412),
    Color(0xFF0E081E),
    Color(0xFF180C2C),
    Color(0xFF241036),
    Color(0xFF1A0C2C),
    Color(0xFF0E081C),
    Color(0xFF070412),
    Color(0xFF04020A),
  ],
  ambient: Color(0xFF8A7AA6),
  rim: Color(0xFFB8A6F0),
  rimStrength: 0.4,
  floor: 0.3,
  glow: 0.1,
  stars: 0.9,
  cloudTop: Color(0xFF341C5A),
  cloudBottom: Color(0xFF8A5AC8),
  cloudGlint: Color(0xFFE0D2FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0814),
    Color(0xFF151026),
    Color(0xFF221A3E),
    Color(0xFF32285A),
    Color(0xFF4A3C7C),
    Color(0xFF7462A8),
    Color(0xFFC0AEEC),
  ],
  mote: Color(0xFFC8B8FF),
  firefly: 0.35,
);

const _arcaneDawn = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF06030C),
    Color(0xFF0E0616),
    Color(0xFF1C0A22),
    Color(0xFF300E2A),
    Color(0xFF4A1430),
    Color(0xFF320E26),
    Color(0xFF1A0818),
    Color(0xFF0C050E),
    Color(0xFF060308),
  ],
  ambient: Color(0xFFB08A9E),
  rim: Color(0xFFFF8A86),
  rimStrength: 0.65,
  floor: 0.22,
  glow: 0.65,
  stars: 0.8,
  cloudTop: Color(0xFF4A1A44),
  cloudBottom: Color(0xFFFF6A6A),
  cloudGlint: Color(0xFFFFD2D6),
  grass: [
    Color(0xFF070408),
    Color(0xFF0E0810),
    Color(0xFF1A0E1C),
    Color(0xFF2A1428),
    Color(0xFF42203A),
    Color(0xFF6A3048),
    Color(0xFFA65060),
    Color(0xFFEFA0A0),
  ],
  mote: Color(0xFFFFB0A8),
  firefly: 0.1,
);

const _arcaneSunrise = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF080818),
    Color(0xFF0E0E28),
    Color(0xFF1A163A),
    Color(0xFF2C1E48),
    Color(0xFF40264E),
    Color(0xFF2E1E44),
    Color(0xFF1A1430),
    Color(0xFF0E0A1E),
    Color(0xFF080614),
  ],
  ambient: Color(0xFFC4ACC4),
  rim: Color(0xFFFFC8A8),
  rimStrength: 0.6,
  floor: 0.25,
  glow: 0.6,
  stars: 0.7,
  cloudTop: Color(0xFF46306E),
  cloudBottom: Color(0xFFF0A890),
  cloudGlint: Color(0xFFFFE6DA),
  grass: [
    Color(0xFF07060C),
    Color(0xFF0F0C18),
    Color(0xFF1C162C),
    Color(0xFF2C2240),
    Color(0xFF46345A),
    Color(0xFF6C5074),
    Color(0xFFA8808E),
    Color(0xFFF2C8B8),
  ],
  mote: Color(0xFFFFD6B8),
  firefly: 0,
);

const _arcaneMorning = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF09091C),
    Color(0xFF0F0F30),
    Color(0xFF181744),
    Color(0xFF232156),
    Color(0xFF2C2860),
    Color(0xFF221F52),
    Color(0xFF16143A),
    Color(0xFF0D0B26),
    Color(0xFF08061A),
  ],
  ambient: Color(0xFFD0CCEC),
  rim: Color(0xFFFFEED0),
  rimStrength: 0.55,
  floor: 0.3,
  glow: 0.5,
  stars: 0.6,
  cloudTop: Color(0xFF423C88),
  cloudBottom: Color(0xFFE6D6A8),
  cloudGlint: Color(0xFFFFF4E0),
  grass: [
    Color(0xFF07070D),
    Color(0xFF0F0F1C),
    Color(0xFF1A1A30),
    Color(0xFF2A2A48),
    Color(0xFF42426A),
    Color(0xFF66668E),
    Color(0xFFA4A0BC),
    Color(0xFFF2E8D0),
  ],
  mote: Color(0xFFFFF0D2),
  firefly: 0,
);

const _arcaneDay = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0A0A1E),
    Color(0xFF101034),
    Color(0xFF191848),
    Color(0xFF24225A),
    Color(0xFF2E2A64),
    Color(0xFF242056),
    Color(0xFF17153C),
    Color(0xFF0E0C28),
    Color(0xFF08071C),
  ],
  ambient: Color(0xFFDCD8F4),
  rim: Color(0xFFFFF4DC),
  rimStrength: 0.5,
  floor: 0.35,
  glow: 0.45,
  stars: 0.55,
  cloudTop: Color(0xFF464290),
  cloudBottom: Color(0xFFE8DCB0),
  cloudGlint: Color(0xFFFFF6E6),
  grass: [
    Color(0xFF07070D),
    Color(0xFF0F0F1C),
    Color(0xFF1A1A30),
    Color(0xFF2A2A48),
    Color(0xFF42426A),
    Color(0xFF66668E),
    Color(0xFFA4A0BC),
    Color(0xFFF2E8D0),
  ],
  mote: Color(0xFFFFF2D6),
  firefly: 0,
);

const _arcaneAfternoon = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0B0B22),
    Color(0xFF13143C),
    Color(0xFF1E1E52),
    Color(0xFF2C2A62),
    Color(0xFF3A326A),
    Color(0xFF2C265C),
    Color(0xFF1C1842),
    Color(0xFF100D2C),
    Color(0xFF09071E),
  ],
  ambient: Color(0xFFDCCFE8),
  rim: Color(0xFFFFE6C4),
  rimStrength: 0.6,
  floor: 0.28,
  glow: 0.55,
  stars: 0.6,
  cloudTop: Color(0xFF4C3E88),
  cloudBottom: Color(0xFFF0CC98),
  cloudGlint: Color(0xFFFFEEDC),
  grass: [
    Color(0xFF08070D),
    Color(0xFF100E1A),
    Color(0xFF1C182E),
    Color(0xFF2C2644),
    Color(0xFF463C62),
    Color(0xFF6C5C80),
    Color(0xFFAC94A8),
    Color(0xFFF4DCC0),
  ],
  mote: Color(0xFFFFE6C4),
  firefly: 0,
);

const _arcaneGolden = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF0A091C),
    Color(0xFF141232),
    Color(0xFF241C46),
    Color(0xFF3A2652),
    Color(0xFF56304E),
    Color(0xFF3E2446),
    Color(0xFF221630),
    Color(0xFF120C20),
    Color(0xFF0A0716),
  ],
  ambient: Color(0xFFD0B4C4),
  rim: Color(0xFFFFB890),
  rimStrength: 0.7,
  floor: 0.22,
  glow: 0.7,
  stars: 0.65,
  cloudTop: Color(0xFF52306E),
  cloudBottom: Color(0xFFFF9C78),
  cloudGlint: Color(0xFFFFE0CC),
  grass: [
    Color(0xFF08060C),
    Color(0xFF100C16),
    Color(0xFF1E1426),
    Color(0xFF30203A),
    Color(0xFF4C3050),
    Color(0xFF784866),
    Color(0xFFB87074),
    Color(0xFFFFC0A0),
  ],
  mote: Color(0xFFFFC8A0),
  firefly: 0,
);

const _arcaneSunset = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF07040C),
    Color(0xFF100616),
    Color(0xFF200A22),
    Color(0xFF380E2A),
    Color(0xFF58142C),
    Color(0xFF3C0E24),
    Color(0xFF1E0816),
    Color(0xFF0E050E),
    Color(0xFF070308),
  ],
  ambient: Color(0xFFB88A98),
  rim: Color(0xFFFF7A70),
  rimStrength: 0.75,
  floor: 0.18,
  glow: 0.8,
  stars: 0.75,
  cloudTop: Color(0xFF561A40),
  cloudBottom: Color(0xFFFF5C5C),
  cloudGlint: Color(0xFFFFC8C8),
  grass: [
    Color(0xFF070408),
    Color(0xFF0E0810),
    Color(0xFF1A0E1C),
    Color(0xFF2A1428),
    Color(0xFF42203A),
    Color(0xFF6A3048),
    Color(0xFFA65060),
    Color(0xFFEFA0A0),
  ],
  mote: Color(0xFFFFA098),
  firefly: 0.15,
);

const _arcaneDusk = _Light(
  stops: _arcaneStops,
  sky: [
    Color(0xFF040209),
    Color(0xFF080412),
    Color(0xFF10081E),
    Color(0xFF1C0C2C),
    Color(0xFF261034),
    Color(0xFF1A0C2A),
    Color(0xFF0E081C),
    Color(0xFF070410),
    Color(0xFF04020A),
  ],
  ambient: Color(0xFF8E7EA6),
  rim: Color(0xFFC890D8),
  rimStrength: 0.45,
  floor: 0.3,
  glow: 0.2,
  stars: 0.95,
  cloudTop: Color(0xFF3A1C5A),
  cloudBottom: Color(0xFF9A60C0),
  cloudGlint: Color(0xFFE6D0FF),
  grass: [
    Color(0xFF050409),
    Color(0xFF0B0814),
    Color(0xFF151026),
    Color(0xFF221A3E),
    Color(0xFF32285A),
    Color(0xFF4A3C7C),
    Color(0xFF7462A8),
    Color(0xFFC0AEEC),
  ],
  mote: Color(0xFFD0B0FF),
  firefly: 0.4,
);

const _arcaneKeys = <(double, _Light)>[
  (0, _arcaneNight),
  (4.4, _arcaneNight),
  (5.0, _arcanePreDawn),
  (5.6, _arcaneDawn),
  (6.4, _arcaneSunrise),
  (7.8, _arcaneMorning),
  (10.0, _arcaneDay),
  (15.5, _arcaneDay),
  (17.6, _arcaneAfternoon),
  (18.7, _arcaneGolden),
  (19.4, _arcaneSunset),
  (20.1, _arcaneDusk),
  (21.0, _arcaneNight),
  (24, _arcaneNight),
];
