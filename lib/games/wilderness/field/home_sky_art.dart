// lib/games/wilderness/field/home_sky_art.dart
//
// The home biome's sky as the sky of the player's own planet (see
// models/home_sky.dart): what the planet wears in space, seen from its
// ground, and the player's constellations at night. Drawn by the field's
// sky painter in two passes — behind the sun and moon, and in front — in
// screen pixels, every frame. Nothing is baked: each grain is a function of
// the field's clock, so the sky costs a couple of atlas draws a pass and a
// few circles, whatever the planet wears.
//
// From the ground, a thing round a planet is an arc across its sky — so
// its rings arch overhead and its flame ring is a river of embers along the
// same kind of arch. What sits ON the planet stands at the far horizon
// (crystal spires, steam vents, a lava moat's glow); what fills its air
// fills the sky (seeds, wisps, dust, glittering ice). A blood moon is the
// moon itself gone red; an orbiting moon a second, smaller one crossing.
//
//   behind  the planet's own glow along the horizon, a dark void (an
//           empty patch, smeared stars, one broken glow — never a drawn
//           disc), a black hole's eye (the sky overhead gone darker, its
//           stars drawn into arcs), the constellations, the phantom's veil
//   front   rings, flame arch, a black hole's disk wheeling overhead, the
//           second moon, halo round the sun or moon,
//           far spires, steam plumes, horizon glow, mist and earthen haze,
//           far lightning, sparks, seeds, dust streams, ice glitter, wisps,
//           blessing motes

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/constellations/constellation_art.dart'
    show treeLight;
import 'package:alchemons/games/cosmic/cosmic_data.dart' show kElementColors;
import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';
import 'package:flutter/painting.dart' show HSVColor;

/// What the sky is this frame, from the field that draws it.
class SkyFrame {
  const SkyFrame({
    required this.screen,
    required this.time,
    required this.hour,
    required this.horizon,
    required this.top,
    required this.night,
    required this.glow,
    required this.light,
    required this.sun,
    required this.sunUp,
    required this.moon,
    required this.moonUp,
    required this.veil,
    required this.scale,
    required this.haze,
  });

  final Size screen;

  /// The field's clock (seconds) and hour (0–24).
  final double time, hour;

  /// Where the horizon (elevation 0) and the top of the sky (elevation 1)
  /// are on the screen.
  final double horizon, top;

  /// How much it is night (the field's stars, 0–1), and how strong the low
  /// sun's glow is.
  final double night, glow;

  /// The light's own color (the rim it puts on things).
  final Color light;

  final Offset sun, moon;

  /// The sun's and moon's elevation, below 0 when set.
  final double sunUp, moonUp;

  /// How much weather hides the sky's lights (0–1).
  final double veil;

  /// Screen pixels per grain unit (the field's scale × the zoom).
  final double scale;

  /// The sky's own color low down, where far things fade into it.
  final Color haze;

  /// The screen y of elevation [up].
  double yAt(double up) => horizon + (top - horizon) * up;
}

/// A sun eclipsed (a home realm in Dark's form): a black disc over it,
/// its light leaking round one side, broken, and a few stars drawn out
/// round it. Never a full ring.
class EclipseArt {
  final CosmeticAtlas _light = CosmeticAtlas(80);
  final Paint _disc = Paint();

  void paint(Canvas canvas, Offset sun, double r, double amount, double t) {
    if (amount <= 0.01) return;
    // The light it leaks, on one side only, in two broken pieces.
    for (final (a, len, k) in const [(2.5, 3.2, 1.0), (3.6, 1.6, 0.5)]) {
      final at = sun + Offset(math.cos(a), math.sin(a)) * r * 1.05;
      _light.add(
        AtlasCell.pool,
        at.dx,
        at.dy,
        r * len,
        atlasArgb(const Color(0xFFB89AFF), 0.55 * k * amount),
        rot: a + math.pi / 2,
      );
    }
    _light.add(
      AtlasCell.dot,
      sun.dx,
      sun.dy,
      r * 7,
      atlasArgb(const Color(0xFF5A3E9C), 0.22 * amount),
    );
    for (var i = 0; i < 12; i++) {
      final a = hash01(i, 950) * math.pi * 2 + t * 0.01;
      final rr = r * (1.8 + 1.6 * hash01(i, 951));
      final p = sun + Offset(math.cos(a), math.sin(a)) * rr;
      _light.add(
        AtlasCell.plume,
        p.dx,
        p.dy,
        r * 0.18,
        atlasArgb(const Color(0xFFE8ECFF), 0.4 * amount * hash01(i, 952)),
        rot: a,
      );
    }
    _light.draw(canvas, blend: BlendMode.plus);
    _disc.color = const Color(0xFF040208).withValues(alpha: amount);
    canvas.drawCircle(sun, r * 1.02, _disc);
  }
}

/// Draws a [HomeSkyLook] into a field's sky.
class HomeSkyArt {
  HomeSkyLook look = HomeSkyLook.none;

  final CosmeticAtlas _over = CosmeticAtlas(1400);
  final CosmeticAtlas _light = CosmeticAtlas(3200);
  final Paint _fill = Paint();
  final Paint _mesh = Paint();

  // Spires and the far ridge, as one mesh.
  final List<Offset> _pos = [];
  final List<Color> _col = [];

  /// The moon's lit face and its glow when the planet wears a blood moon;
  /// null for the moon as it is.
  Color? get moonFace =>
      look.wears('blood_moon') ? const Color(0xFFF4A08E) : null;
  Color? get moonGlow =>
      look.wears('blood_moon') ? const Color(0xFFE0403A) : null;

  /// How big the moon looks: a blood moon hangs larger.
  double get moonSize {
    if (!look.wears('blood_moon')) return 1;
    final size = switch (look.option('blood_moon', 'size', 'Medium')) {
      'Small' => 1.0,
      'Large' => 1.6,
      _ => 1.3,
    };
    final distance = switch (look.option('blood_moon', 'distance', 'Mid')) {
      'Close' => 1.15,
      'Far' => 0.85,
      _ => 1.0,
    };
    return size * distance;
  }

  /// How strongly the blood moon's glow beats (1 = steady).
  double bloodPulse(double time) {
    if (!look.wears('blood_moon')) return 1;
    final k = switch (look.option('blood_moon', 'pulse', 'Normal')) {
      'Gentle' => 0.1,
      'Intense' => 0.35,
      _ => 0.2,
    };
    return 1 + k * math.sin(time * 1.4);
  }

  // ── Passes ───────────────────────────────────────────────────────────────

  /// What lies behind the sun and moon: the planet's glow, a hole in the
  /// stars, the constellations, the phantom's veil.
  void paintBehind(Canvas canvas, SkyFrame f) {
    if (look.isEmpty) return;
    _glowOfPlanet(canvas, f);
    if (look.wears('black_hole')) _eye(canvas, f);
    if (look.wears('dark_void')) _hole(canvas, f);
    _constellations(f);
    _flush(canvas);
    if (look.wears('phantom_phase')) _phantom(canvas, f);
  }

  /// What lies in front of them: everything round and on the planet.
  void paintFront(Canvas canvas, SkyFrame f) {
    if (look.wearing.isEmpty) return;
    if (look.wears('crystal_spires')) _spires(f);
    if (_pos.isNotEmpty) {
      canvas.drawVertices(
        Vertices(VertexMode.triangles, _pos, colors: _col),
        BlendMode.dst,
        _mesh,
      );
      _pos.clear();
      _col.clear();
    }
    if (look.wears('orbiting_moon')) _moonlet(canvas, f);
    if (look.wears('planetary_rings')) _rings(f);
    if (look.wears('flame_ring')) _flameArch(f);
    if (look.wears('black_hole')) _disk(f);
    if (look.wears('radiant_halo')) _halo(f);
    if (look.wears('lava_moat')) _lavaGlow(f);
    if (look.wears('steam_vents')) _plumes(f);
    if (look.wears('ocean_mist')) {
      _bank(f, 'ocean_mist', const Color(0xFFD2ECFF), const Color(0xFF8CC4EC));
    }
    if (look.wears('mud_fortress')) {
      _bank(
        f,
        'mud_fortress',
        const Color(0xFFB09070),
        const Color(0xFF4A3622),
      );
    }
    if (look.wears('poison_cloud')) {
      _bank(
        f,
        'poison_cloud',
        const Color(0xFF9CF06A),
        const Color(0xFFB07ADC),
      );
    }
    if (look.wears('lightning_rod')) _farLightning(f);
    if (look.wears('electric_field')) _sparks(f);
    if (look.wears('vine_tendrils')) _seeds(f);
    if (look.wears('dust_storm')) _dust(f);
    if (look.wears('frozen_shell')) _glitter(f);
    if (look.wears('spirit_wisps')) _wisps(f);
    if (look.wears('natures_blessing')) _blessing(f);
    _flush(canvas);
  }

  void _flush(Canvas canvas) {
    _over.draw(canvas);
    _light.draw(canvas, blend: BlendMode.plus);
  }

  /// A grain that shows in any light: light added onto a dark sky, laid
  /// over a bright one (where added light would not show) — [day] how much
  /// of it there is by day.
  void _grain(
    SkyFrame f,
    AtlasCell cell,
    double x,
    double y,
    double width,
    Color c,
    double a, {
    double rot = 0,
    double day = 1,
  }) {
    if (a <= 0.004) return;
    final dark = smoothstep(0.15, 0.7, f.night);
    if (dark > 0.01) {
      _light.add(cell, x, y, width, atlasArgb(c, a * dark), rot: rot);
    }
    if (dark < 0.99 && day > 0) {
      _over.add(
        cell,
        x,
        y,
        width,
        atlasArgb(c, a * (1 - dark) * day),
        rot: rot,
      );
    }
  }

  // ── Behind ───────────────────────────────────────────────────────────────

  /// The planet's own color, a glow lying along the horizon — stronger by
  /// night. Void darkens the sky overhead and lights a violet limb;
  /// Radiant warms the whole low sky.
  void _glowOfPlanet(Canvas canvas, SkyFrame f) {
    final tint = look.tint;
    if (tint == null) return;
    final w = f.screen.width;
    final k = 0.55 + 0.45 * f.night;
    final at = Offset(w / 2, f.horizon);
    switch (look.color) {
      case 'Void':
        _fill.shader =
            Gradient.linear(Offset(0, f.yAt(1.2)), Offset(0, f.horizon), [
              const Color(0xFF05010C).withValues(alpha: 0.42 * k),
              const Color(0xFF05010C).withValues(alpha: 0),
            ]);
        canvas.drawRect(Offset.zero & f.screen, _fill);
        _fill.shader = null;
        _light.add(
          AtlasCell.pool,
          at.dx,
          at.dy,
          w * 1.5,
          atlasArgb(const Color(0xFF9A6AE0), 0.16 * k),
        );
      case 'Radiant':
        _light
          ..add(
            AtlasCell.pool,
            at.dx,
            at.dy,
            w * 1.8,
            atlasArgb(const Color(0xFFFFE9B0), 0.16 * k),
          )
          ..add(
            AtlasCell.pool,
            at.dx,
            at.dy,
            w * 0.9,
            atlasArgb(const Color(0xFFFFF4D6), 0.1 * k),
          );
      default:
        _light
          ..add(
            AtlasCell.pool,
            at.dx,
            at.dy,
            w * 1.75,
            atlasArgb(tint, 0.05 + 0.13 * f.night),
          )
          ..add(
            AtlasCell.pool,
            at.dx,
            at.dy,
            w * 0.85,
            atlasArgb(tint, 0.03 + 0.08 * f.night),
          );
    }
  }

  /// A dark void: a patch of sky with no stars, the stars round it
  /// smeared along its edge, and one dim glow down one side, broken.
  void _hole(Canvas canvas, SkyFrame f) {
    final vis = (0.2 + 0.8 * f.night) * (1 - f.veil * 0.6);
    if (vis < 0.02) return;
    final w = f.screen.width;
    final depth = switch (look.option('dark_void', 'layers', 'Normal')) {
      'Thin' => 0.8,
      'Deep' => 1.25,
      _ => 1.0,
    };
    final r = w * 0.048 * depth;
    final at = Offset(w * 0.71, f.yAt(0.64));
    // The empty patch: darker than the night round it, with no edge.
    _fill.shader = Gradient.radial(
      at,
      r * 2,
      [
        const Color(0xFF020104).withValues(alpha: 0.97 * vis),
        const Color(0xFF020104).withValues(alpha: 0.9 * vis),
        const Color(0xFF020104).withValues(alpha: 0.32 * vis),
        const Color(0xFF020104).withValues(alpha: 0),
      ],
      const [0.0, 0.46, 0.7, 1.0],
    );
    canvas.drawCircle(at, r * 2, _fill);
    _fill.shader = null;
    // Stars bent round it, drawn out along its edge.
    final turn = f.time * 0.012;
    for (var i = 0; i < 28; i++) {
      final a = hash01(i, 401) * math.pi * 2 + turn * (0.6 + hash01(i, 402));
      final rr = r * (1.04 + 0.6 * math.pow(hash01(i, 403), 2));
      final p = at + Offset(math.cos(a), math.sin(a)) * rr;
      final near = 1 - (rr / r - 1.04) / 0.6;
      _light.add(
        AtlasCell.plume,
        p.dx,
        p.dy,
        (1.6 + 2.2 * near) * f.scale,
        atlasArgb(
          const Color(0xFFE8ECFF),
          (0.18 + 0.4 * hash01(i, 404)) * vis * f.night,
        ),
        rot: a,
      );
    }
    // One dim glow down one side, broken in two.
    for (final (a, len, k) in const [(2.35, 2.3, 1.0), (3.25, 1.2, 0.55)]) {
      final p = at + Offset(math.cos(a), math.sin(a)) * r * 1.02;
      _light.add(
        AtlasCell.pool,
        p.dx,
        p.dy,
        r * len,
        atlasArgb(const Color(0xFFB08AF0), 0.16 * k * vis),
        rot: a + math.pi / 2,
      );
    }
  }

  /// A world at the eye of a black hole: the sky overhead darker than any
  /// night, its stars drawn out into short arcs.
  void _eye(Canvas canvas, SkyFrame f) {
    final vis = 0.45 + 0.55 * f.night;
    _fill.shader =
        Gradient.linear(Offset(0, f.yAt(1.2)), Offset(0, f.yAt(0.35)), [
          const Color(0xFF020104).withValues(alpha: 0.55 * vis),
          const Color(0xFF020104).withValues(alpha: 0),
        ]);
    canvas.drawRect(Offset.zero & f.screen, _fill);
    _fill.shader = null;
    final w = f.screen.width;
    final at = Offset(w * 0.5, f.yAt(1.25));
    final turn = f.time * 0.01;
    for (var i = 0; i < 40; i++) {
      final a = math.pi * (0.1 + 0.8 * hash01(i, 420)) + turn;
      final rr = w * (0.25 + 0.5 * hash01(i, 421));
      final p = at + Offset(math.cos(a), math.sin(a)) * rr;
      _light.add(
        AtlasCell.plume,
        p.dx,
        p.dy,
        (1.6 + 1.6 * hash01(i, 422)) * f.scale,
        atlasArgb(
          const Color(0xFFE8ECFF),
          (0.15 + 0.35 * hash01(i, 423)) * f.night * (1 - f.veil),
        ),
        rot: a,
      );
    }
  }

  static Color _diskColor(String name, double time) => switch (name) {
    'Solar' => const Color(0xFFFFC870),
    'Crimson' => const Color(0xFFE85050),
    'Azure' => const Color(0xFF70B8FF),
    'Emerald' => const Color(0xFF60E0A0),
    'Spectral' => HSVColor.fromAHSV(1, (time * 12) % 360, 0.45, 1).toColor(),
    _ => const Color(0xFFB08AF0),
  };

  /// Where each tree's figure hangs, as (x share, elevation): Alchemy, Combat,
  /// Explorer, in the chart's order.
  static const _figures = [(0.25, 0.74), (0.53, 0.86), (0.8, 0.66)];

  /// The player's constellations, at night: a star for each stone owned,
  /// in its tree's light, joined by a faint dust where both ends are owned.
  /// Each star is nudged off the chart's grid a little, as no sky is ruled.
  void _constellations(SkyFrame f) {
    final stars = look.stars;
    if (stars.isEmpty) return;
    final vis = f.night * (1 - f.veil);
    if (vis < 0.03) return;
    final w = f.screen.width;
    final r = w * 0.085;
    Offset at(int i) {
      final s = stars[i];
      final (cx, up) = _figures[s.tree.clamp(0, 2)];
      final jx = (hash01(i, 330) - 0.5) * 0.16,
          jy = (hash01(i, 331) - 0.5) * 0.16;
      return Offset(w * cx + (s.x + jx) * r, f.yAt(up) + (s.y + jy) * r);
    }

    Color tone(int tree) =>
        treeLight(ConstellationTree.values[tree.clamp(0, 2)]).essence;

    for (final (a, b) in look.links) {
      if (a >= stars.length || b >= stars.length) continue;
      final p = at(a), q = at(b);
      final c = Color.lerp(tone(stars[a].tree), const Color(0xFFFFFFFF), 0.5)!;
      final d = (q - p).distance;
      final n = math.max(2, (d / (3.2 * f.scale)).floor());
      // Faint at the stars, fainter between: a line the eye draws.
      for (var j = 2; j < n - 1; j++) {
        final o = Offset.lerp(p, q, j / n)!;
        final mid = 1 - 0.5 * math.sin(math.pi * j / n);
        _light.add(
          AtlasCell.dot,
          o.dx,
          o.dy,
          2.4 * f.scale,
          atlasArgb(c, 0.13 * vis * mid),
        );
      }
    }
    for (var i = 0; i < stars.length; i++) {
      final s = stars[i];
      final p = at(i);
      final tw = 0.7 + 0.3 * math.sin(f.time * (0.9 + (i % 4) * 0.3) + i);
      final bright = s.root ? 1.0 : 0.62 + 0.38 * hash01(i, 332);
      final c = tone(s.tree);
      _light
        ..add(
          AtlasCell.dot,
          p.dx,
          p.dy,
          (s.root ? 22 : 13 + 6 * bright) * f.scale,
          atlasArgb(c, 0.3 * vis * tw * bright),
        )
        ..add(
          AtlasCell.bead,
          p.dx,
          p.dy,
          (s.root ? 4.6 : 2.6 + 1.2 * bright) * f.scale,
          atlasArgb(
            Color.lerp(c, const Color(0xFFFFFFFF), 0.72)!,
            vis * tw * (0.6 + 0.4 * bright),
          ),
        );
    }
  }

  /// Phantom Phase: every eight seconds a violet dark passes over the sky
  /// and the stars dim under it.
  void _phantom(Canvas canvas, SkyFrame f) {
    final k = switch (look.option('phantom_phase', 'intensity', 'Normal')) {
      'Subtle' => 0.6,
      'Deep' => 1.5,
      _ => 1.0,
    };
    final p = (f.time / 8) % 1;
    final env = math.pow(math.sin(p * math.pi), 3).toDouble();
    if (env < 0.01) return;
    _fill.shader = Gradient.linear(
      Offset(0, f.yAt(1.2)),
      Offset(0, f.horizon),
      [
        const Color(0xFF0A0014).withValues(alpha: 0.38 * env * k),
        const Color(0xFF2A0F4C).withValues(alpha: 0.16 * env * k),
        const Color(0xFF0A0014).withValues(alpha: 0),
      ],
      const [0.0, 0.6, 1.0],
    );
    canvas.drawRect(Offset.zero & f.screen, _fill);
    _fill.shader = null;
  }

  // ── Front ────────────────────────────────────────────────────────────────

  /// A point on an arch across the sky, from the horizon off the left of
  /// the screen to off its right, at [s] 0–1: its apex at elevation
  /// [apex], tilted a little.
  Offset _arch(SkyFrame f, double s, double apex) {
    final w = f.screen.width;
    final up = apex * math.sin(math.pi * s);
    return Offset(
      w * (-0.14 + 1.28 * s),
      f.yAt(up) + (s - 0.5) * (f.horizon - f.top) * 0.16,
    );
  }

  /// The planet's rings, an arch overhead: one band each, fine grains
  /// drifting along them, the stretch overhead dark at night in the
  /// planet's shadow.
  void _rings(SkyFrame f) {
    final count =
        int.tryParse(
          look.option('planetary_rings', 'count', '2'),
        )?.clamp(1, 3) ??
        2;
    final style = look.option('planetary_rings', 'style', 'Icy');
    final width = switch (look.option('planetary_rings', 'width', 'Normal')) {
      'Narrow' => 0.7,
      'Wide' => 1.4,
      'Vast' => 1.9,
      _ => 1.0,
    };
    Color colorAt(double s) => switch (style) {
      'Rocky' => const Color(0xFFC8B090),
      'Prismatic' => HSVColor.fromAHSV(
        1,
        (s * 300 + f.time * 6) % 360,
        0.32,
        1,
      ).toColor(),
      _ => const Color(0xFFCFEFFA),
    };
    final clear = 1 - f.veil * 0.75;
    final base = (0.1 + 0.08 * f.night) * clear;
    const n = 150;
    for (var b = 0; b < count; b++) {
      final apex = 0.92 - b * 0.085;
      final thick = 11 * width * f.scale * (1 - b * 0.18);
      for (var i = 0; i < n; i++) {
        final s = (i + 0.5) / n;
        final p = _arch(f, s, apex);
        final rise = math.sin(math.pi * s);
        final shade =
            1 - f.night * 0.85 * smoothstep(0.2, 0.0, (s - 0.56).abs());
        _grain(
          f,
          AtlasCell.dot,
          p.dx,
          p.dy,
          thick * (0.5 + 0.7 * rise) * 1.7,
          colorAt(s),
          base * shade * (0.6 + 0.4 * rise),
          day: 1.6,
        );
      }
      // Grains catching the light as the ring turns.
      for (var i = 0; i < 44; i++) {
        final s = (hash01(i, 500 + b) + f.time * 0.0035 * (1 + b * 0.3)) % 1;
        final p = _arch(f, s, apex);
        final off = (hash01(i, 510 + b) - 0.5) * thick * 0.8;
        final tw = math.pow(
          0.5 + 0.5 * math.sin(f.time * (1.3 + hash01(i, 520)) + i),
          4,
        );
        _light.add(
          AtlasCell.bead,
          p.dx,
          p.dy + off,
          2.2 * f.scale,
          atlasArgb(
            colorAt(s),
            (0.35 + 0.5 * tw) * clear * (0.4 + 0.6 * f.night),
          ),
        );
      }
    }
  }

  /// The flame ring: a river of embers along an arch lower than the rings,
  /// flickering, a few shed off its underside.
  void _flameArch(SkyFrame f) {
    final k = switch (look.option('flame_ring', 'intensity', 'Normal')) {
      'Dim' => 0.6,
      'Bright' => 1.4,
      _ => 1.0,
    };
    final speed = switch (look.option('flame_ring', 'speed', 'Normal')) {
      'Slow' => 0.6,
      'Fast' => 1.6,
      _ => 1.0,
    };
    _emberArch(
      f,
      apex: look.wears('planetary_rings') ? 0.62 : 0.8,
      hot: const Color(0xFFFFD27A),
      cool: const Color(0xFFE8521A),
      strength: k,
      speed: speed,
      grains: 170,
      thick: 9,
      salt: 600,
    );
  }

  /// A black hole's disk, wheeling round the world: a broad river of
  /// burning matter overhead in the disk's color, hottest along its inner
  /// edge.
  void _disk(SkyFrame f) {
    final c = _diskColor(look.option('black_hole', 'color', 'Violet'), f.time);
    final wide = switch (look.option('black_hole', 'disk', 'Wide')) {
      'Tight' => 0.7,
      'Vast' => 1.5,
      _ => 1.0,
    };
    final dense = switch (look.option('black_hole', 'density', 'Normal')) {
      'Dense' => 1.25,
      'Very Dense' => 1.5,
      'Maximum' => 1.8,
      _ => 1.0,
    };
    final speed = switch (look.option('black_hole', 'spin', 'Normal')) {
      'Slow' => 0.6,
      'Fast' => 1.7,
      _ => 1.0,
    };
    _emberArch(
      f,
      apex: 0.97,
      hot: Color.lerp(c, const Color(0xFFFFFFFF), 0.55)!,
      cool: c,
      strength: 1.1,
      speed: speed * 1.4,
      grains: (190 * dense).round(),
      thick: 22 * wide,
      salt: 640,
    );
  }

  /// Grains flowing along an arch at [apex], between [hot] and [cool],
  /// flickering, [thick] across, with a few shed off its underside.
  void _emberArch(
    SkyFrame f, {
    required double apex,
    required Color hot,
    required Color cool,
    required double strength,
    required double speed,
    required int grains,
    required double thick,
    required int salt,
  }) {
    final clear = 1 - f.veil * 0.7;
    final vis = (0.6 + 0.4 * f.night) * clear * strength;
    // The river's own glow, soft and continuous under its grains.
    const n = 70;
    for (var i = 0; i < n; i++) {
      final s = (i + 0.5) / n;
      final p = _arch(f, s, apex);
      final rise = math.sin(math.pi * s);
      _grain(
        f,
        AtlasCell.dot,
        p.dx,
        p.dy,
        thick * f.scale * (1.6 + 1.2 * rise),
        Color.lerp(hot, cool, 0.55)!,
        0.13 * vis * (0.5 + 0.5 * rise),
        day: 0.7,
      );
    }
    for (var i = 0; i < grains; i++) {
      final s = (hash01(i, salt) + f.time * 0.006 * speed) % 1;
      final p = _arch(f, s, apex);
      final flick =
          0.55 + 0.45 * math.sin(f.time * (5 + hash01(i, salt + 1) * 4) + i);
      final across = hash01(i, salt + 3) - 0.5;
      // Hottest along the inner (lower) edge.
      final c = Color.lerp(hot, cool, (0.5 - across).clamp(0.0, 1.0))!;
      final off = across * thick * f.scale;
      _grain(
        f,
        AtlasCell.dot,
        p.dx,
        p.dy + off,
        12 * f.scale,
        c,
        0.2 * vis * flick,
        day: 0.6,
      );
      _grain(
        f,
        AtlasCell.bead,
        p.dx,
        p.dy + off,
        3 * f.scale,
        c,
        0.85 * vis * flick,
      );
    }
    // Shed downward, cooling as they fall.
    for (var i = 0; i < 30; i++) {
      final life = (hash01(i, salt + 10) + f.time / (5.5 / speed)) % 1;
      final p = _arch(f, hash01(i, salt + 11), apex);
      _grain(
        f,
        AtlasCell.bead,
        p.dx + math.sin(f.time + i) * 6 * f.scale,
        p.dy + thick * 0.5 * f.scale + life * 44 * f.scale,
        2.4 * f.scale,
        Color.lerp(hot, cool, 0.4 + 0.6 * life)!,
        0.75 * vis * (1 - life),
      );
    }
  }

  /// The orbiting moon: a second, smaller moon crossing the sky every few
  /// hours, lit from wherever the sun is.
  void _moonlet(Canvas canvas, SkyFrame f) {
    final size = switch (look.option('orbiting_moon', 'size', 'Medium')) {
      'Small' => 0.7,
      'Large' => 1.35,
      _ => 1.0,
    };
    final speed = switch (look.option('orbiting_moon', 'speed', 'Normal')) {
      'Slow' => 0.6,
      'Fast' => 1.6,
      _ => 1.0,
    };
    final near = switch (look.option('orbiting_moon', 'distance', 'Mid')) {
      'Close' => 1.25,
      'Far' => 0.78,
      _ => 1.0,
    };
    final w = f.screen.width;
    final p = (f.hour / (3 / speed) + 0.37) % 1;
    final up = 0.5 * math.sin(math.pi * p);
    if (up < 0.02) return;
    final at = Offset(w * (-0.06 + 1.12 * p), f.yAt(up));
    final r = 10 * f.scale * size * near;
    final toSun = f.sun - at;
    final d = toSun.distance;
    final dir = d < 1 ? const Offset(0, -1) : toSun / d;
    final vis = (0.5 + 0.5 * f.night) * (1 - f.veil * 0.8);
    _light.add(
      AtlasCell.dot,
      at.dx,
      at.dy,
      r * 6,
      atlasArgb(const Color(0xFFB4C6F0), 0.1 * f.night * vis),
    );
    _fill.shader = Gradient.radial(
      at + dir * r * 0.55,
      r * 1.7,
      [
        const Color(0xFFE6E2DA).withValues(alpha: vis),
        const Color(0xFF8E8C88).withValues(alpha: vis),
        const Color(0xFF16161C).withValues(alpha: vis),
      ],
      const [0.0, 0.42, 1.0],
    );
    canvas.drawCircle(at, r, _fill);
    _fill.shader = null;
  }

  /// A ring of light round the sun by day, the moon by night, faintly red
  /// inside and blue outside.
  void _halo(SkyFrame f) {
    final k = switch (look.option('radiant_halo', 'glow', 'Normal')) {
      'Subtle' => 0.6,
      'Blinding' => 1.7,
      _ => 1.0,
    };
    final reach = switch (look.option('radiant_halo', 'position', 'Mid')) {
      'Close' => 0.8,
      'Outer' => 1.25,
      _ => 1.0,
    };
    final bySun = f.sunUp > -0.04 && f.night < 0.5;
    final byMoon = !bySun && f.moonUp > 0.02;
    if (!bySun && !byMoon) return;
    final c = bySun ? f.sun : f.moon;
    final vis =
        (bySun ? (1 - f.night) : f.night * 0.8) * (1 - f.veil * 0.5) * k;
    final r = f.screen.width * 0.12 * reach;
    const n = 110;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final o = Offset(math.cos(a), math.sin(a));
      final sh = 0.8 + 0.2 * math.sin(f.time * 0.6 + i * 0.4);
      for (final (rr, col, al) in const [
        (0.965, Color(0xFFFFB49A), 0.045),
        (1.0, Color(0xFFFFF4E0), 0.07),
        (1.035, Color(0xFFA8C8FF), 0.04),
      ]) {
        final p = c + o * r * rr;
        _light.add(
          AtlasCell.dot,
          p.dx,
          p.dy,
          9 * f.scale,
          atlasArgb(col, al * vis * sh),
        );
      }
    }
  }

  /// Crystal spires at the far horizon, in the planet's color: great far
  /// formations hazed into the sky behind the land, two faces each — the
  /// lit one toward the light — a glow at each tip.
  void _spires(SkyFrame f) {
    final count = switch (look.option('crystal_spires', 'density', 'Normal')) {
      'Sparse' => 4,
      'Dense' => 10,
      _ => 6,
    };
    final tall = switch (look.option('crystal_spires', 'height', 'Medium')) {
      'Short' => 0.75,
      'Tall' => 1.3,
      _ => 1.0,
    };
    final w = f.screen.width;
    final tint = look.tint ?? const Color(0xFF1DE9B6);
    final night = f.night;
    // Far off: most of their color is the air between.
    final body = Color.lerp(
      Color.lerp(tint, const Color(0xFF0A0C12), 0.55)!,
      f.haze,
      0.5 - 0.25 * night,
    )!;
    final lit = Color.lerp(
      Color.lerp(tint, f.light, 0.35)!,
      f.haze,
      0.42 - 0.2 * night,
    )!;
    final foot = Color.lerp(body, f.haze, 0.6)!;
    final base = f.yAt(-0.02);
    for (var i = 0; i < count; i++) {
      final x = w * (0.04 + 0.92 * (i + 0.2 + 0.6 * hash01(i, 700)) / count);
      final up = (0.3 + 0.32 * hash01(i, 701)) * tall;
      final half = (16 + 16 * hash01(i, 702)) * f.scale;
      final lean = (hash01(i, 703) - 0.5) * half * 0.9;
      final tip = Offset(x + lean, f.yAt(up));
      final ridge = Offset(x + lean * 0.4 + half * 0.18, base);
      final shoulder = Offset(x + lean * 0.8 - half * 0.35, f.yAt(up * 0.82));
      // The shaded face, the lit face, a narrow facet catching more.
      _pos.addAll([
        Offset(x - half, base),
        ridge,
        shoulder,
        shoulder,
        ridge,
        tip,
        ridge,
        Offset(x + half, base),
        tip,
      ]);
      _col.addAll([foot, foot, body, body, foot, body, foot, foot, lit]);
      // A smaller spire leaning on it.
      if (hash01(i, 704) < 0.7) {
        final sx = x + half * (hash01(i, 705) < 0.5 ? -0.9 : 0.9);
        final st = Offset(
          sx + lean * 0.5,
          f.yAt(up * (0.45 + 0.2 * hash01(i, 706))),
        );
        _pos.addAll([
          Offset(sx - half * 0.5, base),
          Offset(sx, base),
          st,
          Offset(sx, base),
          Offset(sx + half * 0.5, base),
          st,
        ]);
        _col.addAll([foot, foot, body, foot, foot, lit]);
      }
      final tw = 0.6 + 0.4 * math.sin(f.time * 0.7 + i * 2.1);
      _light.add(
        AtlasCell.dot,
        tip.dx,
        tip.dy,
        26 * f.scale,
        atlasArgb(tint, (0.1 + 0.22 * night) * tw),
      );
      _grain(
        f,
        AtlasCell.bead,
        tip.dx,
        tip.dy,
        3 * f.scale,
        Color.lerp(tint, const Color(0xFFFFFFFF), 0.6)!,
        0.6 * tw,
        day: 0.5,
      );
    }
  }

  /// A lava moat's glow along the whole horizon, breathing, with a few
  /// slow sparks rising off it.
  void _lavaGlow(SkyFrame f) {
    final wide = switch (look.option('lava_moat', 'width', 'Normal')) {
      'Thin' => 0.8,
      'Wide' => 1.3,
      _ => 1.0,
    };
    final w = f.screen.width;
    final breathe = 0.85 + 0.15 * math.sin(f.time * 0.7);
    final k = (0.4 + 0.6 * f.night) * breathe;
    _light
      ..add(
        AtlasCell.pool,
        w / 2,
        f.yAt(0.02),
        w * 1.6 * wide,
        atlasArgb(const Color(0xFFE8521A), 0.16 * k),
      )
      ..add(
        AtlasCell.pool,
        w / 2,
        f.yAt(0.01),
        w * 0.9 * wide,
        atlasArgb(const Color(0xFFFFC870), 0.07 * k),
      );
    for (var i = 0; i < 22; i++) {
      final life = (hash01(i, 800) + f.time / 9) % 1;
      final x = w * hash01(i, 801) + math.sin(f.time * 0.5 + i) * 10;
      _light.add(
        AtlasCell.bead,
        x,
        f.yAt(0.04 + 0.22 * life),
        2.2 * f.scale,
        atlasArgb(
          Color.lerp(const Color(0xFFFFC870), const Color(0xFFB8360C), life)!,
          0.55 * k * math.sin(math.pi * life),
        ),
      );
    }
  }

  /// Steam rising from vents at the far horizon, swelling and thinning as
  /// it climbs, lit warm by a low sun.
  void _plumes(SkyFrame f) {
    final jets =
        int.tryParse(look.option('steam_vents', 'jets', '4'))?.clamp(1, 8) ?? 4;
    final w = f.screen.width;
    final c = Color.lerp(const Color(0xFFEFF2F5), f.light, 0.35 * f.glow)!;
    for (var j = 0; j < jets; j++) {
      final x = w * (0.06 + 0.88 * (j + 0.2 + 0.6 * hash01(j, 900)) / jets);
      for (var i = 0; i < 18; i++) {
        final life = (i / 18 + f.time / 12 + hash01(j, 901)) % 1;
        final y = f.yAt(0.16 + 0.55 * life);
        final drift = life * life * 70 * f.scale;
        _over.add(
          AtlasCell.dot,
          x + drift + math.sin(f.time * 0.4 + i) * 5 * f.scale,
          y,
          (34 + 120 * life) * f.scale,
          atlasArgb(
            Color.lerp(c, f.haze, 0.25 + 0.5 * f.night)!,
            0.24 * smoothstep(0, 0.1, life) * (1 - life),
          ),
        );
      }
    }
  }

  /// A low bank lying over the far land, drifting: Ocean Mist pale blue,
  /// Mud Fortress an earthen haze, Poison Cloud green going violet with
  /// spores rising out of it.
  void _bank(SkyFrame f, String id, Color day, Color deep) {
    final dense = switch (look.option(
      id,
      'density',
      look.option(id, 'spread', look.option(id, 'thickness', 'Normal')),
    )) {
      'Light' || 'Tight' || 'Thin' => 0.65,
      'Heavy' || 'Wide' || 'Thick' => 1.4,
      _ => 1.0,
    };
    final lift = switch (look.option(id, 'position', 'Mid')) {
      'Close' => 0.12,
      'Outer' => 0.26,
      _ => 0.19,
    };
    final w = f.screen.width;
    final c = Color.lerp(day, deep, 0.25 + 0.55 * f.night)!;
    final vis = (0.9 - 0.4 * f.night) * dense;
    for (var i = 0; i < 18; i++) {
      final x =
          ((hash01(i, 1000) + f.time * 0.004 * (0.6 + hash01(i, 1001))) % 1.3 -
              0.15) *
          w;
      _over.add(
        AtlasCell.pool,
        x,
        f.yAt(lift + 0.09 * (hash01(i, 1002) - 0.5)),
        w * (0.32 + 0.3 * hash01(i, 1003)),
        atlasArgb(c, 0.16 * vis),
      );
    }
    if (id != 'poison_cloud') return;
    for (var i = 0; i < 34; i++) {
      final life = (hash01(i, 1010) + f.time / 13) % 1;
      _grain(
        f,
        AtlasCell.bead,
        w * hash01(i, 1011) + math.sin(f.time * 0.3 + i) * 12,
        f.yAt(lift + 0.32 * life),
        3 * f.scale,
        Color.lerp(day, deep, life)!,
        0.7 * math.sin(math.pi * life),
      );
    }
  }

  /// Lightning Rod: lightning far off, never a bolt — a cloud lit from
  /// within low on the horizon, and again a moment after.
  void _farLightning(SkyFrame f) {
    final period = switch (look.option(
      'lightning_rod',
      'frequency',
      'Normal',
    )) {
      'Rare' => 14.0,
      'Frequent' => 3.5,
      _ => 7.0,
    };
    final k = (f.time / period).floor();
    final t = f.time - k * period;
    double flash(double at) {
      final d = t - at;
      if (d < 0) return 0;
      return d < 0.05 ? d / 0.05 : math.exp(-(d - 0.05) * 9);
    }

    final env = flash(0) + 0.6 * flash(0.24);
    if (env < 0.01) return;
    final w = f.screen.width;
    final x = w * (0.1 + 0.8 * hash01(k, 1100));
    final vis = (0.25 + 0.75 * f.night) * env;
    _light
      ..add(
        AtlasCell.pool,
        x,
        f.yAt(0.1),
        w * 0.4,
        atlasArgb(const Color(0xFFDDE4FF), 0.3 * vis),
      )
      ..add(
        AtlasCell.dot,
        x,
        f.yAt(0.08),
        70 * f.scale,
        atlasArgb(const Color(0xFFFFF7C0), 0.3 * vis),
      );
  }

  /// Electric Field: sparks high in the sky, a pair at a time, there and
  /// gone.
  void _sparks(SkyFrame f) {
    final n = switch (look.option('electric_field', 'bolts', 'Normal')) {
      'Few' => 6,
      'Many' => 20,
      _ => 12,
    };
    final k = switch (look.option('electric_field', 'intensity', 'Normal')) {
      'Dim' => 0.6,
      'Bright' => 1.4,
      _ => 1.0,
    };
    final w = f.screen.width;
    for (var i = 0; i < n; i++) {
      final period = 2.2 + 2 * hash01(i, 1200);
      final cycle = (f.time / period).floor();
      final t = f.time - cycle * period;
      if (t > 0.16) continue;
      final on = 1 - t / 0.16;
      final x = w * hash01(cycle * 31 + i, 1201);
      final y = f.yAt(0.35 + 0.55 * hash01(cycle * 31 + i, 1202));
      final a = hash01(i, 1203) * math.pi;
      final d = Offset(math.cos(a), math.sin(a)) * 5 * f.scale;
      final vis = (0.3 + 0.7 * f.night) * on * k;
      for (final p in [Offset(x, y) - d, Offset(x, y) + d]) {
        _light.add(
          AtlasCell.bead,
          p.dx,
          p.dy,
          2.2 * f.scale,
          atlasArgb(const Color(0xFFFFF59D), 0.9 * vis),
        );
      }
      _light.add(
        AtlasCell.dot,
        x,
        y,
        22 * f.scale,
        atlasArgb(const Color(0xFFFFEB3B), 0.18 * vis),
      );
    }
  }

  /// Vine Tendrils: green seeds carried across the sky on the wind, each
  /// trailing a little.
  void _seeds(SkyFrame f) {
    final n = switch (look.option('vine_tendrils', 'count', 'Some')) {
      'Few' => 16,
      'Many' => 40,
      _ => 26,
    };
    final tail = switch (look.option('vine_tendrils', 'length', 'Medium')) {
      'Short' => 2,
      'Long' => 6,
      _ => 4,
    };
    final w = f.screen.width;
    for (var i = 0; i < n; i++) {
      final speed = 0.012 + 0.012 * hash01(i, 1300);
      final up = 0.15 + 0.75 * hash01(i, 1301);
      final c = hash01(i, 1302) < 0.6
          ? const Color(0xFF4FAE5A)
          : const Color(0xFF8ED39A);
      for (var j = 0; j <= tail; j++) {
        final t = f.time - j * 0.3;
        final s = (hash01(i, 1303) + t * speed) % 1.2 - 0.1;
        final x = s * w;
        final y = f.yAt(up) + math.sin(t * 0.8 + i) * 10 * f.scale;
        final fade = 1 - j / (tail + 1);
        if (j == 0) {
          _grain(f, AtlasCell.dot, x, y, 12 * f.scale, c, 0.22, day: 0.8);
        }
        _grain(
          f,
          j == 0 ? AtlasCell.bead : AtlasCell.dot,
          x,
          y,
          (j == 0 ? 5.0 : 4.4 * fade + 1.4) * f.scale,
          c,
          j == 0 ? 0.95 : 0.5 * fade,
        );
      }
    }
  }

  /// Dust Storm: streams of fine dust blowing high across the sky.
  void _dust(SkyFrame f) {
    final k = switch (look.option('dust_storm', 'particles', 'Normal')) {
      'Few' => 0.6,
      'Swarm' => 1.6,
      _ => 1.0,
    };
    final up = switch (look.option('dust_storm', 'position', 'Mid')) {
      'Close' => 0.32,
      'Outer' => 0.74,
      _ => 0.54,
    };
    final w = f.screen.width;
    final c = Color.lerp(const Color(0xFFD9A868), f.light, 0.2)!;
    final n = (150 * k).round();
    for (var band = 0; band < 3; band++) {
      final lane = up + (band - 1) * 0.1;
      // The stream's body, a soft haze along its lane.
      for (var i = 0; i < 9; i++) {
        final x =
            ((i + f.time * 0.03 * (1 + band * 0.2)) % 9) / 8 * w * 1.2 -
            0.1 * w;
        _over.add(
          AtlasCell.pool,
          x,
          f.yAt(lane + 0.015 * math.sin(i * 1.7 + band)),
          w * 0.3,
          atlasArgb(c, 0.06 * (1 - 0.4 * f.night)),
        );
      }
      for (var i = 0; i < n ~/ 3; i++) {
        final speed = 0.05 + 0.04 * hash01(i, 1400 + band);
        final s = (hash01(i, 1410 + band) + f.time * speed) % 1.2 - 0.1;
        final spread = (hash01(i, 1420 + band) - 0.5) * 0.07;
        final y = f.yAt(lane + spread + 0.02 * math.sin(s * 9 + f.time * 0.5));
        _grain(
          f,
          AtlasCell.plume,
          s * w,
          y,
          2.6 * f.scale,
          c,
          0.75 * (1 - 7 * spread.abs()),
          rot: math.pi / 2,
        );
      }
    }
  }

  /// Frozen Shell: fine ice in the air, glittering when it turns to the
  /// light — most near the sun or moon.
  void _glitter(SkyFrame f) {
    final k = switch (look.option('frozen_shell', 'thickness', 'Medium')) {
      'Thin' => 0.6,
      'Thick' => 1.5,
      _ => 1.0,
    };
    final w = f.screen.width;
    final src = f.night > 0.5 ? f.moon : f.sun;
    final n = (140 * k).round();
    for (var i = 0; i < n; i++) {
      final x = w * hash01(i, 1500) + math.sin(f.time * 0.2 + i) * 6;
      final y = f.yAt(0.04 + 0.95 * hash01(i, 1501));
      final near = math.exp(
        -((Offset(x, y) - src).distanceSquared) / (w * w * 0.05),
      );
      final flash = math.pow(
        math.max(
          0.0,
          math.sin(f.time * (0.8 + 1.6 * hash01(i, 1502)) + i * 3.1),
        ),
        10,
      );
      final a = (0.18 + 0.82 * flash) * (0.6 + 1.4 * near);
      final c = Color.lerp(
        const Color(0xFFBFEFFF),
        const Color(0xFFFFFFFF),
        flash.toDouble(),
      )!;
      _light.add(
        AtlasCell.bead,
        x,
        y,
        (2 + 1.6 * flash) * f.scale,
        atlasArgb(c, a.clamp(0.0, 1.0)),
      );
      if (flash > 0.3) {
        _light.add(
          AtlasCell.dot,
          x,
          y,
          12 * f.scale,
          atlasArgb(c, 0.25 * flash),
        );
      }
    }
  }

  /// Spirit Wisps: a few pale lights wandering through the sky, each with
  /// a short fading wake — faint by day.
  void _wisps(SkyFrame f) {
    final n = switch (look.option('spirit_wisps', 'count', 'Some')) {
      'Few' => 5,
      'Many' => 14,
      _ => 9,
    };
    final band = switch (look.option('spirit_wisps', 'position', 'Mid')) {
      'Close' => 0.2,
      'Outer' => 0.55,
      _ => 0.35,
    };
    final w = f.screen.width;
    final vis = 0.45 + 0.55 * f.night;
    for (var i = 0; i < n; i++) {
      final speed = 0.004 + 0.006 * hash01(i, 1600);
      for (var j = 0; j < 9; j++) {
        final t = f.time - j * 0.2;
        final s = (hash01(i, 1601) + t * speed) % 1.2 - 0.1;
        final y = f.yAt(
          band +
              0.35 * hash01(i, 1602) +
              0.06 * math.sin(t * (0.35 + 0.2 * hash01(i, 1603)) + i),
        );
        final fade = 1 - j / 9;
        if (j == 0) {
          _grain(
            f,
            AtlasCell.dot,
            s * w,
            y,
            22 * f.scale,
            const Color(0xFF7FF5E8),
            0.35 * vis,
            day: 0.5,
          );
        }
        _grain(
          f,
          AtlasCell.bead,
          s * w,
          y,
          (j == 0 ? 4 : 3 * fade + 1) * f.scale,
          const Color(0xFF9FFAF0),
          (j == 0 ? 0.95 : 0.45 * fade) * vis,
        );
      }
    }
  }

  /// Nature's Blessing: motes of every element rising slowly through the
  /// sky.
  void _blessing(SkyFrame f) {
    final k = switch (look.option('natures_blessing', 'brightness', 'Normal')) {
      'Dim' => 0.6,
      'Bright' => 1.5,
      _ => 1.0,
    };
    final colors = kElementColors.values.toList();
    final w = f.screen.width;
    final vis = (0.6 + 0.4 * f.night) * k;
    for (var i = 0; i < colors.length * 3; i++) {
      final life = (hash01(i, 1700) + f.time / 16) % 1;
      final x = w * hash01(i, 1701) + math.sin(f.time * 0.4 + i) * 14;
      final y = f.yAt(0.04 + 0.9 * life);
      final c = colors[i % colors.length];
      final a = math.sin(math.pi * life) * vis;
      _grain(f, AtlasCell.dot, x, y, 14 * f.scale, c, 0.3 * a, day: 0.6);
      _grain(f, AtlasCell.bead, x, y, 4.4 * f.scale, c, 0.95 * a);
    }
  }
}

/// The night sky's figures for the constellation stones [owned]: each
/// owned stone a star in its tree's figure, scaled so a whole tree fits -1…1, and
/// each link whose two ends are owned. [layout] is where each stone stands
/// from its tree's centre ([constellationTreeLayout]).
(List<SkyStar>, List<(int, int)>) skyStarsFor(
  Set<String> owned,
  Map<ConstellationTree, Map<String, Offset>> layout,
) {
  final stars = <SkyStar>[];
  final index = <String, int>{};
  for (final tree in ConstellationTree.values) {
    final at = layout[tree] ?? const {};
    if (at.isEmpty) continue;
    var reach = 1.0;
    for (final o in at.values) {
      reach = math.max(reach, math.max(o.dx.abs(), o.dy.abs()));
    }
    for (final s in ConstellationCatalog.forTree(tree)) {
      if (!owned.contains(s.id)) continue;
      final o = at[s.id];
      if (o == null) continue;
      index[s.id] = stars.length;
      stars.add(
        SkyStar(
          o.dx / reach,
          o.dy / reach,
          tree.index,
          root: s.tier == 1 && s.prerequisites.isEmpty,
        ),
      );
    }
  }
  final links = <(int, int)>[
    for (final s in ConstellationCatalog.allSkills)
      if (index[s.id] case final b?)
        for (final p in s.prerequisites)
          if (index[p] case final a?) (a, b),
  ];
  return (stars, links);
}
