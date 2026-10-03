part of 'alchemy_effect_paint.dart';

/// ELEMENTAL AURA — a creature's element, given off at aura scale.
///
/// A few grains in the element's own shades (the ramps the elemental essence
/// uses), moving the way that element moves when a specimen comes apart into
/// it: embers rise, grit settles, frost drifts down, a Dark one's grains sink
/// into a small void at its feet. Low density, close to the body, weighted
/// behind it and at its feet, and each over a soft pool of its light.
abstract final class _ElementalAura {
  // Buckets: the four shades, then halos under hot grains, glints, soft
  // wide grains (steam, bubbles) and their brighter hearts.
  static const int _shadeB = 0;
  static const int _glowB = 4, _glintB = 5, _softB = 6, _bigB = 7;

  /// Where the feet stand, as a fraction of r below the centre.
  static const double _feet = 0.63;

  static final Map<String, EssenceElement> _resolved = {};

  /// An element from an element name or a variant faction; unknown is
  /// Arcane, which is spirit.
  static EssenceElement resolve(String? name) {
    if (name == null) return EssenceElement.spirit;
    return _resolved[name] ??= switch (name.trim().toLowerCase()) {
      'volcanic' || 'pyro' => EssenceElement.fire,
      'oceanic' || 'aqua' => EssenceElement.water,
      'earthen' => EssenceElement.earth,
      'verdant' => EssenceElement.plant,
      'arcane' => EssenceElement.spirit,
      'bloodborn' => EssenceElement.blood,
      final e => EssenceElement.of(e),
    };
  }

  // The frame being painted, so the element motions read short.
  static double _cx = 0, _cy = 0, _r = 1;
  static Canvas? _c;
  static List<Color> _sh = const [];
  static double _o = 1;
  static bool _dark = true;

  static void _add(int b, double x, double y) =>
      _batch.add(b, _cx + x * _r, _cy + y * _r);

  static void _shade(int k, double x, double y) =>
      _add(_shadeB + k.clamp(0, 3), x, y);

  static final List<List<Color>?> _darkShades = List.filled(
    EssenceElement.values.length,
    null,
  );
  static final List<List<Color>?> _lightShades = List.filled(
    EssenceElement.values.length,
    null,
  );

  /// The ramp, or on parchment a step deeper, where pale shades wash out.
  static List<Color> _shades(EssenceElement e, bool dark) {
    final ramp = essenceRamp(e);
    if (dark) return _darkShades[e.index] ??= ramp;
    return _lightShades[e.index] ??= [
      Color.lerp(ramp[0], ramp[1], 0.3)!,
      Color.lerp(ramp[1], ramp[0], 0.25)!,
      Color.lerp(ramp[2], ramp[1], 0.4)!,
      Color.lerp(ramp[3], ramp[2], 0.6)!,
    ];
  }

  // Shapes, built once at unit size and placed by the canvas.
  static final Path _facet = vfxShard(Offset.zero, 1, 0.42, -math.pi / 2);
  static final Path _facetFace = Path()
    ..moveTo(0, -1)
    ..lineTo(0.42, 0)
    ..lineTo(0, 0.35)
    ..close();
  static final Path _leaf = vfxLeaf(const Offset(-0.5, 0), 1, 0);

  static void paint(
    Canvas c,
    Offset at,
    double r,
    double t,
    EssenceElement e,
    double o,
    bool dark,
  ) {
    _cx = at.dx;
    _cy = at.dy;
    _r = r;
    _c = c;
    _o = o;
    _dark = dark;
    final sh = _sh = _shades(e, dark);
    final ramp = essenceRamp(e);
    _batch.clear();

    _paintPool(c, e, t, o, dark);

    // A small one shows fewer grains: it cannot resolve more.
    final density = (r / 44).clamp(0.65, 1.0);
    switch (e) {
      case EssenceElement.fire:
        _fire(t, (22 * density).round());
      case EssenceElement.water:
        _water(t, (18 * density).round());
      case EssenceElement.earth:
        _earth(t, (21 * density).round());
      case EssenceElement.air:
        _air(t, 4, density > 0.8 ? 16 : 11);
      case EssenceElement.steam:
        _steam(t, density > 0.8 ? 6 : 5);
      case EssenceElement.lava:
        _lava(t);
      case EssenceElement.lightning:
        _lightning(t, density > 0.8 ? 6 : 5);
      case EssenceElement.mud:
        _mud(t);
      case EssenceElement.ice:
        _ice(t, (20 * density).round());
      case EssenceElement.dust:
        _dust(t, (22 * density).round());
      case EssenceElement.crystal:
        _crystal(t);
      case EssenceElement.plant:
        _plant(t, (17 * density).round());
      case EssenceElement.poison:
        _poison(t, (7 * density).round().clamp(5, 7));
      case EssenceElement.spirit:
        _spirit(t, 4, density > 0.8 ? 12 : 8);
      case EssenceElement.dark:
        _darkSink(t, (20 * density).round());
      case EssenceElement.light:
        _light(t, density > 0.8 ? 2 : 1);
      case EssenceElement.blood:
        _blood(t);
    }

    final d = (r * 0.072).clamp(1.8, 4.2) * _size(e);
    final b = _batch;
    // Halos in two passes, wide and faint under narrow: a soft glow, where
    // one pass is a grey coin round every grain.
    final g = _glow(e) * 1.3 * (dark ? 1 : 0.6) * o;
    b.draw(c, _glowB, d * 4.0, _fade(ramp[2], g * 0.4));
    b.draw(c, _glowB, d * 2.4, _fade(ramp[2], g * 0.7));
    b.draw(c, _softB, d * 2.2, _fade(sh[2], (dark ? 0.3 : 0.4) * o));
    b.draw(c, _bigB, d * 2.4, _fade(sh[2], (dark ? 0.34 : 0.5) * o));
    final a = _alpha(e) * o;
    for (var k = 0; k < 4; k++) {
      b.draw(c, _shadeB + k, d, _fade(sh[k], a));
    }
    final glint = dark ? const Color(0xFFFFFBEA) : sh[2];
    b.draw(c, _glintB, d * 2.6, _fade(glint, (dark ? 0.12 : 0.2) * o));
    b.draw(c, _glintB, d * 1.25, _fade(glint, 0.95 * o));
    _c = null;
  }

  static double _size(EssenceElement e) => switch (e) {
    EssenceElement.steam => 1.1,
    EssenceElement.water => 1.1,
    EssenceElement.poison => 1.1,
    EssenceElement.lightning => 0.7,
    EssenceElement.dust => 0.85,
    EssenceElement.ice => 0.9,
    EssenceElement.earth => 0.95,
    _ => 1.0,
  };

  static double _alpha(EssenceElement e) => switch (e) {
    EssenceElement.air => 0.85,
    EssenceElement.steam => 0.85,
    EssenceElement.spirit => 0.9,
    _ => 1.0,
  };

  /// The halo under hot grains.
  static double _glow(EssenceElement e) => switch (e) {
    EssenceElement.fire => 0.3,
    EssenceElement.lava => 0.3,
    EssenceElement.lightning => 0.32,
    EssenceElement.light => 0.3,
    EssenceElement.blood => 0.2,
    EssenceElement.spirit => 0.2,
    EssenceElement.dark => 0.26,
    EssenceElement.plant => 0.1,
    _ => 0.13,
  };

  // ── the pool ──────────────────────────────────────────────────────────

  static void _paintPool(
    Canvas c,
    EssenceElement e,
    double t,
    double o,
    bool dark,
  ) {
    final ramp = essenceRamp(e);
    final r = _r;
    final y = _cy + r * (_feet + 0.03);
    var col = essencePool(e);
    if (!dark) col = Color.lerp(col, ramp[1], 0.45)!;
    var a = switch (e) {
      EssenceElement.fire => 0.3,
      EssenceElement.lava => 0.36,
      EssenceElement.lightning => 0.22,
      EssenceElement.light => 0.3,
      EssenceElement.blood => 0.24,
      EssenceElement.earth || EssenceElement.mud || EssenceElement.dust => 0.14,
      _ => 0.18,
    };
    var w = 0.74;
    switch (e) {
      case EssenceElement.fire:
        a *= 0.85 + 0.15 * math.sin(t * 7.3) * math.sin(t * 3.1 + 1);
      case EssenceElement.lightning:
        // Flickers: dim, then a flash.
        final q = (t * 13).floor();
        a *= _h(q, 3) > 0.78 ? 1.0 : 0.35 + 0.2 * _h(q, 4);
      case EssenceElement.blood:
        final beat = _beat(t);
        a *= 0.7 + 0.55 * beat;
        w *= 1 + 0.05 * beat;
      case EssenceElement.dark:
        // The void it sinks into: a violet bloom, black at its heart.
        _pool(
          c,
          _cx,
          y,
          r * 0.74,
          r * 0.2,
          dark ? ramp[3] : ramp[1],
          (dark ? 0.68 : 0.36) * o,
        );
        _pool(c, _cx, y, r * 0.4, r * 0.095, ramp[0], 0.95 * o);
        return;
      default:
        break;
    }
    _pool(c, _cx, y, r * w, r * 0.19, col, a * 1.5 * (dark ? 1 : 0.75) * o);
  }

  /// A heartbeat, lub-dub: 0 at rest, 1 on the beat.
  static double _beat(double t) {
    final m = t % 1.05;
    double pulse(double x) => math.exp(-(x * x) / 0.003);
    return (pulse(m - 0.04) + 0.65 * pulse(m - 0.23)).clamp(0.0, 1.0);
  }

  /// A hash of grain [i] in time-slot [q].
  static double _hq(int i, int q) => _h(i * 31 + q, 9);

  // ── the elements ──────────────────────────────────────────────────────
  //
  // The creature covers the middle, so grains live where they show: off its
  // flanks, over its head, and along the ground either side of its feet.

  /// Embers lift off its flanks and crown, hot at first, cooling to ash as
  /// they rise, drawn in a little like a flame's tongue.
  static void _fire(double t, int n) {
    for (var i = 0; i < n; i++) {
      final p = 1.3 + 0.9 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final crown = i % 4 == 3;
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      final x0 = crown ? -0.3 + 0.6 * _q(3, i) : side * (0.42 + 0.3 * _q(3, i));
      final y0 = crown ? -0.5 : 0.05 + 0.5 * _q(4, i);
      final y = y0 - (crown ? 0.5 : 0.8 + 0.5 * _q(6, i)) * s;
      final x =
          x0 * (1 - 0.32 * s) + math.sin(s * 6 + _q(7, i) * 6.28) * 0.05 * s;
      final k = s < 0.32 ? 3 : (s < 0.58 ? 2 : (s < 0.8 ? 1 : 0));
      if (s > 0.94) continue;
      _shade(k, x, y);
      if (k >= 2) _add(_glowB, x, y);
    }
  }

  /// Beads of water bob on a swell off its flanks, and a few roll to and
  /// fro along the ground; the crests catch the light.
  static void _water(double t, int n) {
    final tq = (t * 3).floor();
    for (var i = 0; i < n; i++) {
      final ph = t * (1.2 + 0.6 * _q(1, i)) + _q(2, i) * 6.28;
      final side = _q(5, i) < 0.58 ? -1.0 : 1.0;
      double x, y;
      if (i % 3 == 2) {
        x =
            side * (0.32 + 0.4 * _q(3, i)) +
            0.1 * math.sin(t * 0.7 + _q(4, i) * 6.28);
        y = _feet + 0.012 + 0.012 * math.sin(ph);
      } else {
        x = side * (0.52 + 0.24 * _q(3, i)) + 0.045 * math.cos(ph);
        y =
            -0.12 +
            0.62 * _q(4, i) +
            0.04 * math.sin(ph) +
            0.03 * math.sin(t * 1.1 + side);
      }
      if (_hq(i, tq) < 0.06) {
        _add(_glintB, x, y);
        continue;
      }
      final sn = math.sin(ph);
      final k = sn < -0.4 ? 3 : (sn < 0.4 ? 2 : 1);
      _shade(k, x, y);
      if (k == 3) _add(_glowB, x, y);
    }
  }

  /// Grit falls off its flanks and settles at its feet, in a little heap
  /// that spills either side of them.
  static void _earth(double t, int n) {
    for (var i = 0; i < n; i++) {
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      if (i < 7) {
        // The heap: always there.
        final x = side * (0.2 + 0.52 * _q(3, i));
        final y = _feet + 0.01 + 0.04 * _q(4, i) * (1 - x.abs());
        _shade(_q(6, i) < 0.45 ? 1 : 2, x, y);
        continue;
      }
      final p = 2.2 + 1.2 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final x0 = side * (0.44 + 0.28 * _q(3, i));
      final y0 = -0.3 + 0.55 * _q(4, i);
      final yg = _feet + 0.04 * _q(6, i);
      if (s < 0.5) {
        final u = s / 0.5;
        _shade(
          _q(7, i) < 0.35 ? 3 : 2,
          x0 + side * 0.06 * u,
          y0 + (yg - y0) * u * u,
        );
      } else if (s < 0.93) {
        final land = (s - 0.5) * p;
        final bounce = 0.03 * math.sin(land * 22).abs() * math.exp(-land * 9);
        _shade(s < 0.78 ? 2 : 1, x0 + side * 0.06, yg - bounce);
      }
    }
  }

  /// Wisps curl up past its flanks, looping over on themselves.
  static void _air(double t, int wisps, int len) {
    for (var w = 0; w < wisps; w++) {
      final p = 2.8 + 0.8 * _q(1, w);
      final s0 = _frac(t / p + _q(2, w));
      final ph = _q(3, w) * 6.28;
      final side = w.isOdd ? 1.0 : -1.0;
      final x0 = side * (0.5 + 0.12 * (w ~/ 2) + 0.06 * _q(4, w));
      for (var k = 0; k < len; k++) {
        final s = s0 - k * 0.014;
        if (s < 0) break;
        final env = _smooth(0.0, 0.1, s) * (1 - _smooth(0.78, 1.0, s));
        final q = s * math.pi * 2 * 1.8 + ph;
        final x = x0 + side * 0.16 * s + 0.15 * math.cos(q);
        final y = 0.5 - 1.3 * s + 0.15 * math.sin(q);
        // Faint: the lit shade at its head, never white.
        final v = (2.4 - k * 2.0 / len) * env;
        if (v < 0.5) continue;
        _shade(v.round(), x, y);
        // Fuller at its head, thinning to a thread: a wisp, not a line.
        if (k < len / 3 && env > 0.4) _add(_softB, x, y);
      }
    }
  }

  /// Puffs billow up off its shoulders, swelling and thinning: soft light,
  /// not grains, with a fleck or two of condensation in them.
  static void _steam(double t, int puffs) {
    final c = _c!;
    final r = _r;
    for (var j = 0; j < puffs; j++) {
      final p = 2.4 + 0.9 * _q(1, j);
      final s = _frac(t / p + _q(2, j));
      final side = j.isEven ? -1.0 : 1.0;
      final x0 = side * (0.34 + 0.24 * _q(3, j));
      final x =
          x0 + side * 0.12 * s + 0.08 * math.sin(s * 3 + _q(4, j) * 6.28) * s;
      final y = -0.3 - 0.8 * s;
      final env = _smooth(0.0, 0.18, s) * (1 - _smooth(0.55, 1.0, s));
      if (env < 0.04) continue;
      final rad = (0.13 + 0.17 * s) * r;
      _pool(
        c,
        _cx + x * r,
        _cy + y * r,
        rad,
        rad * 0.85,
        _dark ? _sh[3] : _sh[1],
        (_dark ? 0.4 : 0.3) * env * _o,
      );
      // A second, smaller swell off-centre: a billow, not a ball.
      final ox = (_q(5, j) - 0.5) * 0.14, oy = -0.05 - 0.04 * s;
      _pool(
        c,
        _cx + (x + ox) * r,
        _cy + (y + oy) * r,
        rad * 0.6,
        rad * 0.55,
        _dark ? _sh[3] : _sh[1],
        (_dark ? 0.32 : 0.24) * env * _o,
      );
    }
  }

  /// Drips run off its underside into a molten glow at its feet, where a
  /// dark crust breaks open in specks of heat.
  static void _lava(double t) {
    for (var i = 0; i < 5; i++) {
      final p = 2.2 + 1.0 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.34 + 0.28 * _q(3, i));
      final y0 = 0.1 + 0.25 * _q(4, i);
      if (s < 0.45) {
        // Gathering, sagging.
        final y = y0 + 0.05 * (s / 0.45);
        _shade(2, x, y);
        _add(_glowB, x, y);
      } else if (s < 0.8) {
        final u = (s - 0.45) / 0.35;
        final y = y0 + 0.05 + (_feet - y0 - 0.05) * u * u;
        _shade(3, x, y);
        _add(_glowB, x, y);
        _shade(2, x, y - 0.035);
        _shade(1, x, y - 0.065);
      }
    }
    for (var i = 0; i < 12; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.12 + 0.6 * _q(3, i + 8));
      final y = _feet + 0.005 + 0.04 * _q(4, i + 8) * (1 - x.abs());
      final hot = math.sin(t * (1.6 + _q(5, i + 8)) + _q(6, i + 8) * 20) > 0.55;
      _shade(hot ? 3 : (i % 3 == 0 ? 1 : 0), x, y);
      if (hot) _add(_glowB, x, y);
    }
  }

  /// Crackling: every ~75 ms each spark jumps somewhere new round a few
  /// hot spots on its edge, which wander — a tiny zigzag of grains, and
  /// some of them dark that instant.
  static void _lightning(double t, int arcs) {
    for (var i = 0; i < arcs; i++) {
      final q = (t / 0.075 + _q(1, i)).floor();
      if (_hq(i + 3, q) < 0.25) continue;
      final j = i % 3;
      final anchor = j * 2.3 + 0.6 + 0.5 * math.sin(t * 0.37 + j * 1.9);
      final a = anchor + (_hq(i, q) - 0.5) * 1.0;
      final rr = 0.6 + 0.22 * _hq(i + 7, q);
      var x = math.cos(a) * rr * 0.95;
      var y = math.sin(a) * rr;
      // Outward-ish, then zig and zag about that line.
      final dir = a + (_hq(i + 11, q) - 0.5) * 2.2;
      _add(_glowB, x, y);
      for (var k = 0; k < 5; k++) {
        if (k == 0 && _hq(i + 17, q) < 0.3) {
          _add(_glintB, x, y);
        } else {
          _shade(k < 2 ? 3 : 2, x, y);
        }
        final zig = dir + (k.isEven ? 0.9 : -0.9);
        x += math.cos(zig) * 0.068;
        y += math.sin(zig) * 0.068;
      }
    }
  }

  /// Slow, heavy drops sag off it and fall into a puddle at its feet, with
  /// the odd plop.
  static void _mud(double t) {
    for (var i = 0; i < 4; i++) {
      final p = 3.2 + 1.4 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = i.isEven ? -1.0 : 1.0;
      final x = side * (0.36 + 0.26 * _q(3, i));
      final y0 = 0.14 + 0.2 * _q(4, i);
      if (s < 0.55) {
        final y = y0 + 0.06 * _smooth(0.0, 0.55, s);
        _shade(2, x, y);
        _shade(1, x, y - 0.03);
      } else if (s < 0.78) {
        final u = (s - 0.55) / 0.23;
        final y = y0 + 0.06 + (_feet - y0 - 0.06) * u * u;
        _shade(2, x, y);
        _shade(1, x, y - 0.04);
      } else if (s < 0.9) {
        // Plop: two flecks thrown up and out.
        final u = (s - 0.78) / 0.12;
        final hop = 0.08 * math.sin(math.pi * u);
        _shade(3, x - 0.06 * u, _feet - hop);
        _shade(2, x + 0.06 * u, _feet - hop * 0.8);
      }
    }
    for (var i = 0; i < 10; i++) {
      final side = i.isEven ? -1.0 : 1.0;
      final x =
          side * (0.14 + 0.56 * _q(3, i + 10)) + 0.012 * math.sin(t * 1.2 + i);
      final y = _feet + 0.01 + 0.035 * _q(4, i + 10) * (1 - x.abs());
      _shade(i % 3 == 0 ? 2 : 1, x, y);
    }
  }

  /// Frost flecks drift down past it, swaying and catching the light.
  static void _ice(double t, int n) {
    final tq = (t * 5).floor();
    for (var i = 0; i < n; i++) {
      final p = 4.0 + 2.2 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      final x0 = side * (0.25 + 0.6 * _q(3, i));
      final x = x0 + 0.08 * math.sin(t * 1.3 + _q(4, i) * 6.28);
      final y = -0.95 + 1.6 * s;
      if (s > 0.08 && s < 0.92 && _hq(i, tq) < 0.12) {
        _add(_glintB, x, y);
        continue;
      }
      final k = s < 0.08 || s > 0.9 ? 1 : (_q(6, i) < 0.45 ? 3 : 2);
      _shade(k, x, y);
    }
  }

  /// Blown off it downwind, streaming and turning over, the lowest
  /// skittering along the ground.
  static void _dust(double t, int n) {
    for (var i = 0; i < n; i++) {
      final p = 1.8 + 1.0 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final low = i % 4 == 0;
      final x0 = 0.2 + 0.32 * _q(3, i);
      final y0 = low ? _feet - 0.01 : -0.36 + 0.88 * _q(4, i);
      final x = x0 + (0.5 + 0.6 * _q(5, i)) * s;
      final y = low
          ? y0 - 0.03 * math.sin(s * 9 + i).abs()
          : y0 - 0.12 * s * _q(6, i) + 0.05 * math.sin(s * 8 + _q(7, i) * 6.28);
      if (s > 0.94) continue;
      final k = s < 0.45 ? 2 : (s < 0.75 ? 1 : 0);
      _shade(k == 2 && _q(7, i) < 0.3 ? 3 : k, x, y);
    }
  }

  /// A few small facets stand off it, each bobbing and turning a little,
  /// and now and then one catches the light.
  static void _crystal(double t) {
    const fx = [-0.74, 0.72, -0.6, 0.5];
    const fy = [-0.32, -0.04, 0.42, -0.66];
    const fa = [-0.35, 0.3, -0.6, 0.15];
    const fs = [0.15, 0.13, 0.11, 0.1];
    final c = _c!;
    final r = _r;
    for (var k = 0; k < 4; k++) {
      final x = fx[k] + 0.012 * math.sin(t * 0.8 + k);
      final y = fy[k] + 0.03 * math.sin(t * 1.1 + k * 1.7);
      final a = fa[k] + 0.22 * math.sin(t * 0.55 + k * 2.1);
      final len = fs[k] * r;
      final px = _cx + x * r, py = _cy + y * r;
      // Turning: its width swings as it shows its edge.
      final turn = 0.55 + 0.45 * math.cos(t * 0.7 + k * 1.3).abs();
      _shape(c, _facet, px, py, a, len * turn, len, _fade(_sh[1], 0.92 * _o));
      _shape(
        c,
        _facetFace,
        px,
        py,
        a,
        len * turn,
        len,
        _fade(_sh[2], 0.9 * _o),
      );
      final g = _frac(t * 0.42 + k * 0.37);
      if (g < 0.08) {
        final tip = fs[k] * 0.85;
        _add(_glintB, x + math.sin(a) * tip, y - math.cos(a) * tip);
      }
      // A fleck or two of crystal dust about each.
      final dx = math.sin(t * 0.9 + k * 2.6) * 0.06;
      _shade(3, x + 0.09 + dx, y + 0.06);
      if (k.isEven) _shade(2, x - 0.07, y - 0.08 - dx);
    }
  }

  /// Spores and a few tiny leaves rise off its flanks, the leaves
  /// tumbling.
  static void _plant(double t, int n) {
    for (var i = 0; i < n; i++) {
      final p = 3.0 + 1.5 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      final x0 = side * (0.42 + 0.32 * _q(3, i));
      final y = 0.5 - 0.15 * _q(4, i) - 1.25 * s;
      final x = x0 * (1 - 0.2 * s) + 0.07 * math.sin(s * 6 + _q(6, i) * 6.28);
      final env = _smooth(0.0, 0.1, s) * (1 - _smooth(0.75, 1.0, s));
      if (env < 0.15) continue;
      final k = env > 0.55 ? (_q(7, i) < 0.45 ? 3 : 2) : 1;
      _shade(k, x, y);
      if (k == 3) _add(_glowB, x, y);
    }
    final c = _c!;
    final r = _r;
    for (var j = 0; j < 3; j++) {
      final p = 4.2 + 1.4 * _q(1, j + 20);
      final s = _frac(t / p + _q(2, j + 20));
      final side = j == 1 ? 1.0 : -1.0;
      final x =
          side * (0.52 + 0.18 * _q(3, j + 20)) +
          0.1 * math.sin(s * 4 + j * 2.2);
      final y = 0.42 - 1.25 * s;
      final env = _smooth(0.0, 0.12, s) * (1 - _smooth(0.7, 1.0, s));
      if (env < 0.05) continue;
      final a = t * (1.2 + 0.4 * j) + j * 1.9;
      final tumble = math.cos(t * 2.1 + j * 1.3);
      final len = r * 0.17;
      _shape(
        c,
        _leaf,
        _cx + x * r,
        _cy + y * r,
        a,
        len,
        len * (0.25 + 0.75 * tumble.abs()),
        _fade(_sh[tumble > 0 ? 3 : 2], env * _o),
      );
    }
  }

  /// Bubbles well up beside it and rise, and burst.
  static void _poison(double t, int n) {
    for (var i = 0; i < n; i++) {
      final p = 2.4 + 1.2 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = i.isEven ? -1.0 : 1.0;
      final x0 = side * (0.42 + 0.3 * _q(3, i));
      final rise = 0.55 + 0.5 * _q(4, i);
      if (s < 0.85) {
        final u = s / 0.85;
        final x =
            x0 * (1 - 0.15 * u) + 0.03 * math.sin(s * 9 + _q(5, i) * 6.28);
        final y = _feet - 0.02 - rise * u;
        if (u < 0.14) {
          _add(_softB, x, y);
          continue;
        }
        _add(_bigB, x, y);
        // The light on its skin, up and to the left.
        _shade(3, x - 0.028, y - 0.032);
      } else {
        // Burst: a few flecks thrown out.
        final u = (s - 0.85) / 0.15;
        final x = x0 * 0.85, y = _feet - 0.02 - rise;
        for (var k = 0; k < 5; k++) {
          final a = k * 1.26 + i;
          final d = 0.035 + 0.07 * u;
          _shade(u < 0.5 ? 3 : 2, x + math.cos(a) * d, y + math.sin(a) * d);
        }
      }
    }
  }

  /// Faint wisps rise off its flanks in waving columns, thinning to tails.
  static void _spirit(double t, int wisps, int len) {
    for (var w = 0; w < wisps; w++) {
      final p = 3.6 + 1.0 * _q(1, w);
      final s0 = _frac(t / p + _q(2, w));
      final side = w.isOdd ? 1.0 : -1.0;
      final x0 = side * (0.46 + 0.22 * _q(3, w));
      final ph = _q(4, w) * 6.28;
      for (var k = 0; k < len; k++) {
        final s = s0 - k * 0.011;
        if (s < 0) break;
        final env = _smooth(0.0, 0.12, s) * (1 - _smooth(0.7, 1.0, s));
        final x = x0 * (1 - 0.3 * s) + 0.1 * math.sin(s * 5 + ph);
        final y = 0.36 - 1.4 * s;
        final v = (3.0 - k * 2.8 / len) * env;
        if (v < 0.5) continue;
        _shade(v.round(), x, y);
        if (k == 0 && env > 0.5) _add(_glowB, x, y);
      }
    }
  }

  /// Its grains sink from round it into the small void at its feet,
  /// turning as they go and darkening into it.
  static void _darkSink(double t, int n) {
    const fp = _feet + 0.03;
    for (var i = 0; i < n; i++) {
      final p = 2.2 + 1.0 * _q(1, i);
      final s = _frac(t / p + _q(2, i));
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      final x0 = side * (0.5 + 0.3 * _q(3, i));
      final y0 = -0.5 + 0.85 * _q(4, i);
      final k = math.pow(s, 1.4).toDouble();
      final rem = 1 - k;
      final turn = k * 2.2 * side;
      final x = x0 * rem * math.cos(turn) * (0.7 + 0.3 * rem);
      final y =
          fp +
          (y0 - fp) * math.pow(rem, 1.3).toDouble() +
          x0 * rem * math.sin(turn) * 0.25;
      if (s > 0.96) continue;
      final shade = k < 0.55 ? 3 : (k < 0.8 ? 2 : 1);
      _shade(shade, x, y);
      if (shade == 3) _add(_glowB, x, y);
    }
  }

  static final Path _blade = vfxLens(1, 1, 0.15, 0.8);
  static final Shader _bladeDark = _crossLit(const Color(0xFFFFDC7A));
  static final Shader _bladeLight = _crossLit(const Color(0xFFD99A2B));
  static Shader _crossLit(Color c) => ui.Gradient.linear(
    const Offset(0, -0.5),
    const Offset(0, 0.5),
    [
      c.withValues(alpha: 0),
      c.withValues(alpha: 0.18),
      c,
      c.withValues(alpha: 0.18),
      c.withValues(alpha: 0),
    ],
    const [0.0, 0.25, 0.5, 0.75, 1.0],
  );
  static final Paint _bladePaint = Paint();

  /// Uneven soft rays: a few faint shafts of warm light from behind it,
  /// each its own width and length and all to one side of upright — an even
  /// ring of spokes reads as a badge — breathing slowly, with a mote or two
  /// drifting out along each.
  static void _light(double t, int per) {
    const angles = [-2.2, -1.5, -0.95, -0.45];
    const widths = [0.3, 0.42, 0.26, 0.34];
    const reach = [1.05, 1.45, 0.95, 1.2];
    final c = _c!;
    final r = _r;
    _bladePaint.shader = _dark ? _bladeDark : _bladeLight;
    for (var j = 0; j < angles.length; j++) {
      final a = angles[j] + 0.08 * math.sin(t * 0.3 + j * 1.3);
      final breathe = 0.5 + 0.5 * math.sin(t * 0.55 + j * 2.1);
      final len = reach[j] * (0.9 + 0.1 * breathe) * r;
      c.save();
      c.translate(_cx, _cy - r * 0.15);
      c.rotate(a);
      c.scale(len, widths[j] * r);
      _bladePaint.color = Color.fromRGBO(
        0,
        0,
        0,
        (0.14 + 0.12 * breathe) * (_dark ? 1 : 0.85) * _o,
      );
      c.drawPath(_blade, _bladePaint);
      c.restore();

      final ca = math.cos(a), sa = math.sin(a);
      for (var k = 0; k < per; k++) {
        final q = _frac(t * 0.2 + k / per + _q(2, j + 30));
        final rr = 0.6 + (len / r - 0.6) * q;
        final off = (_q(k % 8, j + 30) - 0.5) * widths[j] * 0.4;
        final x = ca * rr - sa * off;
        final y = -0.15 + sa * rr + ca * off;
        _shade(q < 0.5 ? 3 : (q < 0.8 ? 2 : 1), x, y);
      }
    }
  }

  /// A deep red pool beats lub-dub at its feet; the grains off its flanks
  /// jolt out on each beat, and now and then a droplet falls.
  static void _blood(double t) {
    final beat = _beat(t);
    for (var i = 0; i < 11; i++) {
      final side = _q(5, i) < 0.55 ? -1.0 : 1.0;
      final x0 = side * (0.5 + 0.24 * _q(3, i));
      final y0 = -0.1 + 0.62 * _q(4, i);
      final j = 1 + 0.1 * beat;
      final drift = 0.02 * math.sin(t * 0.9 + i * 1.7);
      final x = x0 * j + drift, y = y0 * j;
      final k = beat > 0.4 ? 3 : (_q(6, i) < 0.5 ? 2 : 1);
      _shade(k, x, y);
      if (k == 3) _add(_glowB, x, y);
    }
    for (var i = 0; i < 3; i++) {
      final p = 2.6 + 1.2 * _q(1, i + 12);
      final s = _frac(t / p + _q(2, i + 12));
      final x = (i == 1 ? 1.0 : -1.0) * (0.36 + 0.24 * _q(3, i + 12));
      final y0 = 0.12 + 0.22 * _q(4, i + 12);
      if (s < 0.4) {
        _shade(2, x, y0 + 0.04 * (s / 0.4));
      } else if (s < 0.72) {
        final u = (s - 0.4) / 0.32;
        final y = y0 + 0.04 + (_feet - y0 - 0.04) * u * u;
        _shade(3, x, y);
        _shade(1, x, y - 0.035);
      }
    }
  }
}
