// lib/widgets/fx/cosmetics/form_feature_art.dart
//
// What a home realm grows when it has turned into a form (models/
// home_biome.dart, HomeHold): not a color laid over it but things that
// open in its ground and happen there. Each form has
//
//   a SITE    where it shows itself, revealed once — a rift torn in the
//             ground, a column of light come down, a pool of blood with
//             veins through the soil, a fissure, a flood, stones risen out
//             of the earth and floating, the whole ground in flower;
//   EVENTS    that come round again and again on its own clock — a wave of
//             shadow, a flare and lanterns at dusk, a heartbeat and red
//             rain, eruptions, showers, tremors that shake the stones,
//             gusts of seeds that flower where they land;
//
// and the residents take part (home_life.dart). All of it is grains and
// soft shapes laid down by the hundred in a few draws (CosmeticAtlas), and
// the flood's water as one mesh, on the realm's own ground: never a stroked
// line, never blur.
// Stateless: every grain is a function of the clock, so it costs the same
// whenever it is drawn and two screens agree.

import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/games/cosmic/obsidian_kit.dart' show hash01;
import 'package:alchemons/widgets/fx/cosmetics/cosmetic_atlas.dart';

/// A form's event that comes round on its own clock: every [period]
/// seconds — each time a little earlier or later — it lasts [duration].
class FormEventKind {
  const FormEventKind(this.period, this.duration, this.salt);
  final double period, duration;
  final int salt;

  /// Which time round it is at [t] and how far through it (0–1), or null
  /// between times. None in the first [period].
  (int, double)? at(double t) {
    if (t < period * 0.6) return null;
    final k = (t / period).floor();
    final start = k * period + period * 0.3 * hash01(k, salt);
    final f = (t - start) / duration;
    if (f < 0 || f >= 1) return null;
    return (k, f);
  }

  /// When the [k]th time round began.
  double startOf(int k) => k * period + period * 0.3 * hash01(k, salt);
}

/// Dark: a wave of shadow crossing the field.
const kShadowSweep = FormEventKind(70, 7, 31);

/// Light: the column flares and its light runs out along the ground.
const kLightFlare = FormEventKind(55, 3.5, 32);

/// Blood: red rain (and always at night under a full moon).
const kBloodRain = FormEventKind(180, 28, 33);

/// Volcanic: the fissure erupts.
const kEruption = FormEventKind(46, 4.5, 34);

/// Oceanic: a passing shower.
const kShower = FormEventKind(115, 30, 35);

/// Earthen: a tremor.
const kTremor = FormEventKind(72, 2.4, 36);

/// Verdant: a gust carrying seeds that flower where they land.
const kSeedGust = FormEventKind(58, 7, 37);

/// How long what a gust sowed stays in flower, and how long ash lies.
const double kFlowerLife = 42, kAshLife = 22;

/// The events each form has.
const Map<String, List<FormEventKind>> kFormEvents = {
  'Dark': [kShadowSweep],
  'Light': [kLightFlare],
  'Blood': [kBloodRain],
  'Volcanic': [kEruption],
  'Oceanic': [kShower],
  'Earthen': [kTremor],
  'Verdant': [kSeedGust],
};

/// Whether rain is falling in [form] at [t] (the residents shelter): its
/// showers, its red rain — or Blood's under a full moon at night.
bool formRainingAt(String? form, double t, {bool fullMoonNight = false}) =>
    switch (form) {
      'Oceanic' => kShower.at(t) != null,
      'Blood' => fullMoonNight || kBloodRain.at(t) != null,
      _ => false,
    };

/// One resident's feet, for what a form does round them.
class FormFoot {
  const FormFoot(this.x, this.y, this.size, this.seed);
  final double x, y, size;
  final int seed;
}

/// What a form's features are drawn into this frame, in a layer's units.
class FormView {
  const FormView({
    required this.form,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
    required this.height,
    required this.time,
    required this.ground,
    required this.siteX,
    required this.siteY,
    required this.size,
    required this.reveal,
    required this.amount,
    required this.night,
    this.feet = const [],
    this.fullMoon = false,
  });

  final String form;

  /// The visible window.
  final double left, right, top, bottom;
  final double height;

  /// The form's clock (seconds).
  final double time;

  /// Where something stands at x (null: no ground there).
  final double? Function(double x) ground;

  /// Where the site is (its middle, on the ground), and the size of a
  /// creature on its row.
  final double siteX, siteY, size;

  /// How far it has been revealed (0 → 1, once), and how much of the form
  /// shows (0–1).
  final double reveal, amount;

  /// How much it is night (0–1).
  final double night;

  /// The residents on this row.
  final List<FormFoot> feet;

  /// A full moon tonight (the real one).
  final bool fullMoon;

  double groundOr(double x) => ground(x) ?? siteY;
}

double _ease(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// What lies on the ground, under the residents: the site, and what is
/// left on the ground (ash, flowers). [canvas] is for the few shapes that
/// are not grains (the rift's dark, the pool, the light's column).
void paintFormBack(
  FormView v,
  Canvas canvas,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  if (v.amount <= 0.01) return;
  switch (v.form) {
    case 'Dark':
      _rift(v, canvas, over, light);
      _shadows(v, over, light);
    case 'Light':
      _column(v, canvas, light);
    case 'Blood':
      _pool(v, canvas, over, light);
      _veins(v, light);
    case 'Volcanic':
      _fissure(v, over, light);
      _ash(v, over);
    case 'Earthen':
      _stones(v, over, light);
    case 'Verdant':
      _meadow(v, over, light);
      _sown(v, light);
    default:
      break;
  }
}

/// What happens over the residents: the shadow's wave, lanterns, rain,
/// embers in the air, the flood's water about their feet, dust, seeds.
void paintFormFront(
  FormView v,
  Canvas canvas,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  if (v.amount <= 0.01) return;
  switch (v.form) {
    case 'Dark':
      _sweep(v, canvas, light);
    case 'Light':
      _lanterns(v, light);
      _flare(v, light);
    case 'Blood':
      if (v.night > 0.5 && v.fullMoon || kBloodRain.at(v.time) != null) {
        _rain(v, over, light, const Color(0xFFB0182C), kBloodRain);
      }
    case 'Volcanic':
      _eruption(v, light);
    case 'Oceanic':
      _flood(v, canvas, over, light);
      if (kShower.at(v.time) != null) {
        _rain(v, over, light, const Color(0xFFBFE4FF), kShower);
      }
    case 'Earthen':
      _tremor(v, over, light);
    case 'Verdant':
      _gust(v, light);
    default:
      break;
  }
}

// ── Dark ─────────────────────────────────────────────────────────────────────

/// A rift torn in the ground: an opening with stars in it, as if through
/// the planet, starlight drawn out round its edge, the ground round it lit
/// from below. Revealed: the ground's grains drawn in to a slit, which
/// opens.
void _rift(FormView v, Canvas canvas, CosmeticAtlas over, CosmeticAtlas light) {
  final s = v.size;
  final cx = v.siteX, cy = v.siteY + s * 0.03;
  final rx = s * 1.7;
  final open = _ease((v.reveal - 0.35) / 0.65);
  final ry = s * (0.04 + 0.3 * open);
  final a = v.amount;
  // Drawn in: grains spiralling into where it opens.
  if (v.reveal < 0.6) {
    final k = 1 - v.reveal / 0.6;
    for (var i = 0; i < 80; i++) {
      final ang = hash01(i, 700) * math.pi * 2 + v.time * 2.5;
      final r = rx * (0.3 + 2 * hash01(i, 701)) * k;
      light.add(
        AtlasCell.bead,
        cx + math.cos(ang) * r,
        cy + math.sin(ang) * r * 0.25,
        s * 0.04,
        atlasArgb(const Color(0xFFB89AFF), 0.8 * k * a),
      );
    }
  }
  if (open <= 0.01) return;
  light.add(
    AtlasCell.pool,
    cx,
    cy,
    rx * 3.2,
    atlasArgb(const Color(0xFF6A4CC0), 0.24 * open * a),
  );
  canvas
    ..save()
    ..translate(cx, cy)
    ..scale(1, ry / rx);
  canvas.drawCircle(
    Offset.zero,
    rx,
    Paint()
      ..shader = Gradient.radial(
        Offset.zero,
        rx,
        [
          const Color(0xFF010003).withValues(alpha: a),
          const Color(0xFF040209).withValues(alpha: 0.96 * a),
          const Color(0xFF0A0614).withValues(alpha: 0),
        ],
        const [0.0, 0.78, 1.0],
      ),
  );
  canvas.restore();
  // Stars in it, far below, drifting slowly as the planet turns.
  for (var i = 0; i < 80; i++) {
    final u = (hash01(i, 702) + v.time * 0.004) % 1 * 2 - 1;
    final w = hash01(i, 703) * 2 - 1;
    if (u * u + w * w > 0.8) continue;
    final tw = 0.5 + 0.5 * math.sin(v.time * (1 + hash01(i, 704) * 2) + i);
    light.add(
      AtlasCell.bead,
      cx + u * rx,
      cy + w * ry,
      s * (0.02 + 0.02 * hash01(i, 705)),
      atlasArgb(const Color(0xFFE8ECFF), (0.45 + 0.55 * tw) * open * a),
    );
  }
  // Starlight drawn out round its edge.
  for (var i = 0; i < 54; i++) {
    final ang = hash01(i, 706) * math.pi * 2 + v.time * 0.03;
    light.add(
      AtlasCell.plume,
      cx + math.cos(ang) * rx * 1.04,
      cy + math.sin(ang) * ry * 1.1,
      s * 0.06,
      atlasArgb(
        const Color(0xFFD8D0FF),
        (0.35 + 0.5 * hash01(i, 707)) * open * a,
      ),
      rot: ang + math.pi / 2,
    );
  }
  light.add(
    AtlasCell.pool,
    cx - rx * 0.55,
    cy - ry * 0.3,
    rx * 0.9,
    atlasArgb(const Color(0xFF8A62E0), 0.3 * open * a),
    rot: -0.15,
  );
}

/// At night each resident's shadow steps away from it, a little dark with
/// two eyes, and wanders, and comes back.
void _shadows(FormView v, CosmeticAtlas over, CosmeticAtlas light) {
  final n = v.night * v.amount;
  if (n < 0.05) return;
  for (final f in v.feet) {
    final wander =
        math.sin(v.time * 0.21 + f.seed) * 0.5 +
        math.sin(v.time * 0.13 + f.seed * 1.7) * 0.5;
    final x = f.x + wander * f.size * 1.1 * n;
    final y = f.y + f.size * 0.02;
    over.add(
      AtlasCell.pool,
      x,
      y,
      f.size * 0.8,
      atlasArgb(const Color(0xFF040208), 0.75 * n),
    );
    // Its eyes, now and then a blink.
    final blink = math.sin(v.time * 0.7 + f.seed) > 0.96 ? 0.1 : 1.0;
    final eyeY = y - f.size * 0.22;
    for (final d in const [-0.06, 0.06]) {
      light.add(
        AtlasCell.bead,
        x + d * f.size + (wander > 0 ? 0.02 : -0.02) * f.size,
        eyeY,
        f.size * 0.035,
        atlasArgb(const Color(0xFFB89AFF), 0.9 * n * blink),
      );
    }
  }
}

/// A wave of shadow crossing the field: everything under it put out, and
/// violet motes rising where it has been.
void _sweep(FormView v, Canvas canvas, CosmeticAtlas light) {
  final e = kShadowSweep.at(v.time);
  if (e == null) return;
  final (k, f) = e;
  final w = v.right - v.left;
  final band = w * 0.4;
  final dir = hash01(k, 710) < 0.5 ? 1 : -1;
  final x = dir > 0
      ? v.left - band + (w + band * 2) * f
      : v.right + band - (w + band * 2) * f;
  canvas.drawRect(
    Rect.fromLTRB(x - band, v.top, x + band, v.bottom),
    Paint()
      ..shader = Gradient.linear(
        Offset(x - band, 0),
        Offset(x + band, 0),
        [
          const Color(0x00050210),
          const Color(0xE0050210),
          const Color(0x00050210),
        ],
        const [0.0, 0.5, 1.0],
      ),
  );
  // In its wake, motes rising.
  for (var i = 0; i < 40; i++) {
    final behind = hash01(i + k * 40, 711) * w * 0.7;
    final mx = x - dir * (band * 0.4 + behind);
    if (mx < v.left || mx > v.right) continue;
    final age = behind / (w * 0.7);
    final y = v.groundOr(mx) - age * v.size * 2.2 - hash01(i, 712) * v.size;
    light.add(
      AtlasCell.bead,
      mx,
      y,
      v.size * 0.03,
      atlasArgb(const Color(0xFFB08AF0), 0.7 * (1 - age) * v.amount),
    );
  }
}

// ── Light ────────────────────────────────────────────────────────────────────

/// A column of light come down from the sky and stayed, pooling on the
/// ground, light falling slowly down it. Revealed: one bright mote falls,
/// lands, and the column widens from a thread.
void _column(FormView v, Canvas canvas, CosmeticAtlas light) {
  final s = v.size;
  final cx = v.siteX, gy = v.siteY;
  final fall = _ease(v.reveal / 0.3);
  final widen = _ease((v.reveal - 0.3) / 0.7);
  final a = v.amount;
  if (v.reveal < 0.32) {
    final y = v.top + (gy - v.top) * fall;
    light
      ..add(
        AtlasCell.dot,
        cx,
        y,
        s * 0.5,
        atlasArgb(const Color(0xFFFFF4D0), 0.6 * a),
      )
      ..add(
        AtlasCell.bead,
        cx,
        y,
        s * 0.08,
        atlasArgb(const Color(0xFFFFFFFF), a),
      );
  }
  if (widen <= 0.01) return;
  final half = s * (0.03 + 0.42 * widen);
  final beat = 0.85 + 0.15 * math.sin(v.time * 0.8);
  final flare = kLightFlare.at(v.time)?.$2;
  final f = flare == null ? 0.0 : math.sin(flare * math.pi);
  canvas.drawRect(
    Rect.fromLTRB(cx - half * 2, v.top, cx + half * 2, gy),
    Paint()
      ..blendMode = BlendMode.plus
      ..shader = Gradient.linear(
        Offset(cx - half * 2, 0),
        Offset(cx + half * 2, 0),
        [
          const Color(0x00FFF0C0),
          Color.fromRGBO(255, 240, 200, (0.16 + 0.22 * f) * a * beat),
          Color.fromRGBO(255, 250, 230, (0.28 + 0.3 * f) * a * beat),
          Color.fromRGBO(255, 240, 200, (0.16 + 0.22 * f) * a * beat),
          const Color(0x00FFF0C0),
        ],
        const [0.0, 0.3, 0.5, 0.7, 1.0],
      ),
  );
  // Light falling down it.
  for (var i = 0; i < 34; i++) {
    final life = (hash01(i, 720) + v.time / (9 + 4 * hash01(i, 721))) % 1;
    light.add(
      AtlasCell.bead,
      cx + (hash01(i, 722) - 0.5) * half * 2.6,
      v.top + (gy - v.top) * life,
      s * 0.025,
      atlasArgb(const Color(0xFFFFF4D0), 0.7 * math.sin(math.pi * life) * a),
    );
  }
  light
    ..add(
      AtlasCell.pool,
      cx,
      gy,
      s * (1.6 + 0.6 * f) * widen,
      atlasArgb(const Color(0xFFFFE8B0), (0.4 + 0.3 * f) * a),
    )
    ..add(
      AtlasCell.dot,
      cx,
      gy - s * 0.1,
      s * 1.4 * widen,
      atlasArgb(const Color(0xFFFFF4D0), 0.18 * a),
    );
}

/// The column flares, and its light runs out along the ground both ways.
void _flare(FormView v, CosmeticAtlas light) {
  final e = kLightFlare.at(v.time);
  if (e == null || v.reveal < 1) return;
  final f = e.$2;
  final reach = v.size * (0.5 + 6 * f);
  for (var i = 0; i < 48; i++) {
    final side = i.isEven ? 1 : -1;
    final x = v.siteX + side * reach * (0.85 + 0.15 * hash01(i, 725));
    light.add(
      AtlasCell.bead,
      x,
      v.groundOr(x) - v.size * 0.03,
      v.size * 0.035,
      atlasArgb(const Color(0xFFFFF0C0), 0.85 * (1 - f) * v.amount),
    );
  }
}

/// Lanterns of light rising out of the grass at dusk and hanging in the
/// air all night, bobbing; at dawn they drift up and go.
void _lanterns(FormView v, CosmeticAtlas light) {
  final n = v.night * v.amount * v.reveal;
  if (n < 0.02) return;
  const tile = 1400.0;
  final k0 = (v.left / tile).floor(), k1 = (v.right / tile).floor();
  for (var k = k0; k <= k1; k++) {
    for (var i = 0; i < 12; i++) {
      final x = k * tile + hash01(i, 730) * tile;
      if (x < v.left - 40 || x > v.right + 40) continue;
      final g = v.ground(x);
      if (g == null) continue;
      // Each rises in its own time as the night comes.
      final rise = _ease((n - 0.15 * hash01(i, 731)) / 0.6);
      final hang = v.size * (0.9 + 1.4 * hash01(i, 732));
      final y = g - hang * rise + math.sin(v.time * 0.6 + i) * v.size * 0.06;
      final c = Color.lerp(
        const Color(0xFFFFE6A0),
        const Color(0xFFFFF6E0),
        hash01(i, 733),
      )!;
      light
        ..add(AtlasCell.dot, x, y, v.size * 0.45, atlasArgb(c, 0.22 * rise))
        ..add(AtlasCell.bead, x, y, v.size * 0.06, atlasArgb(c, 0.95 * rise));
    }
  }
}

// ── Blood ────────────────────────────────────────────────────────────────────

/// The heartbeat: twice, quickly, every 1.6 seconds.
double _beat(double t) {
  final p = (t / 1.6) % 1;
  double pulse(double at) => math.exp(-math.pow((p - at) / 0.05, 2));
  return pulse(0.08) + 0.6 * pulse(0.24);
}

/// A pool of blood open in the ground, its surface trembling on the
/// heartbeat, rings going out across it.
void _pool(FormView v, Canvas canvas, CosmeticAtlas over, CosmeticAtlas light) {
  final s = v.size;
  final cx = v.siteX, cy = v.siteY + s * 0.03;
  final open = _ease(v.reveal / 0.4);
  if (open <= 0.01) return;
  final rx = s * 1.45 * open, ry = s * 0.3 * open;
  final a = v.amount;
  final b = _beat(v.time);
  light.add(
    AtlasCell.pool,
    cx,
    cy,
    rx * 2.8,
    atlasArgb(const Color(0xFFA01828), (0.12 + 0.1 * b) * a),
  );
  canvas
    ..save()
    ..translate(cx, cy)
    ..scale(1, ry / rx);
  canvas.drawCircle(
    Offset.zero,
    rx,
    Paint()
      ..shader = Gradient.radial(
        Offset.zero,
        rx,
        [
          const Color(0xFF2A0208).withValues(alpha: a),
          const Color(0xFF5A0A16).withValues(alpha: 0.95 * a),
          const Color(0xFF7A1420).withValues(alpha: 0),
        ],
        const [0.0, 0.8, 1.0],
      ),
  );
  canvas.restore();
  light.add(
    AtlasCell.pool,
    cx - rx * 0.2,
    cy - ry * 0.35,
    rx * 1.1,
    atlasArgb(const Color(0xFFFF6A7A), (0.14 + 0.16 * b) * a),
  );
  final p = (v.time / 1.6) % 1;
  for (var i = 0; i < 36; i++) {
    final ang = i / 36 * math.pi * 2;
    final r = 0.2 + 0.75 * p;
    light.add(
      AtlasCell.bead,
      cx + math.cos(ang) * rx * r,
      cy + math.sin(ang) * ry * r,
      s * 0.03,
      atlasArgb(const Color(0xFFFF8090), 0.55 * (1 - p) * a),
    );
  }
}

/// Veins of blood spreading out from the pool through the soil, the
/// heartbeat running along them. Revealed: they grow out from it.
void _veins(FormView v, CosmeticAtlas light) {
  final grow = _ease((v.reveal - 0.3) / 0.7);
  if (grow <= 0.01) return;
  final s = v.size;
  const branches = 10;
  final a = v.amount;
  for (var b = 0; b < branches; b++) {
    final dir = b.isEven ? 1.0 : -1.0;
    final len = s * (2.2 + 2.4 * hash01(b, 740)) * grow;
    final depth = (hash01(b, 741) - 0.4) * s * 0.3;
    final steps = (len / (s * 0.06)).floor();
    for (var j = 0; j < steps; j++) {
      final t = j / math.max(1, steps);
      final x = v.siteX + dir * (s * 1.3 + t * len);
      final g = v.ground(x);
      if (g == null) break;
      final wig =
          math.sin(t * 14 + b) * s * 0.05 +
          (hash01(j, 742 + b) - 0.5) * s * 0.03;
      final p = ((v.time / 1.6) % 1) * 2.2 - t;
      final pulse = math.exp(-math.pow(p / 0.12, 2));
      final c = Color.lerp(
        const Color(0xFFA01828),
        const Color(0xFFFF6070),
        pulse,
      )!;
      final y = g + depth * t + wig;
      light.add(
        AtlasCell.bead,
        x,
        y,
        s * (0.04 - 0.018 * t) * (0.7 + 0.6 * hash01(j, 743 + b)),
        atlasArgb(c, (0.55 + 0.45 * pulse) * (1 - 0.4 * t) * a),
      );
      if (j % 3 == 0) {
        light.add(
          AtlasCell.dot,
          x,
          y,
          s * 0.16,
          atlasArgb(c, (0.06 + 0.16 * pulse) * (1 - 0.5 * t) * a),
        );
      }
    }
  }
}

/// Rain across the view, [color], splashing where it lands.
void _rain(
  FormView v,
  CosmeticAtlas over,
  CosmeticAtlas light,
  Color color,
  FormEventKind kind,
) {
  final e = kind.at(v.time);
  final f = e == null ? 0.5 : e.$2;
  // Coming on and going off.
  final k = math.min(1.0, math.min(f / 0.12, (1 - f) / 0.12)) * v.amount;
  if (k <= 0.01) return;
  const tile = 900.0;
  final h = v.height;
  final k0 = (v.left / tile).floor(), k1 = (v.right / tile).floor();
  for (var t = k0; t <= k1; t++) {
    for (var i = 0; i < 70; i++) {
      final speed = h * (1.1 + 0.4 * hash01(i, 750));
      final span = h * 1.2;
      final y =
          v.top - h * 0.1 + (hash01(i, 751) * span + v.time * speed) % span;
      final x = t * tile + hash01(i, 752) * tile + (y - v.top) * 0.12;
      if (x < v.left || x > v.right) continue;
      final g = v.ground(x);
      if (g != null && y > g) {
        // A splash, briefly.
        if (y - g < h * 0.03) {
          over.add(
            AtlasCell.bead,
            x,
            g,
            v.size * 0.03,
            atlasArgb(color, 0.6 * k),
          );
        }
        continue;
      }
      over.add(
        AtlasCell.plume,
        x,
        y,
        v.size * 0.025,
        atlasArgb(color, 0.5 * k),
        rot: -0.12,
      );
    }
  }
}

// ── Volcanic ─────────────────────────────────────────────────────────────────

/// The fissure's line along the ground, from its middle out: points as
/// (x, y), and how far each is along it.
List<(double, double, double)> _crack(FormView v) {
  final s = v.size;
  const n = 11;
  return [
    for (var i = 0; i < n; i++)
      () {
        final t = i / (n - 1);
        final x = v.siteX + (t - 0.5) * s * 3.6;
        final y = v.groundOr(x) + (hash01(i, 760) - 0.5) * s * 0.14 + s * 0.04;
        return (x, y, (t - 0.5).abs() * 2);
      }(),
  ];
}

/// A fissure cracked open in the ground: broken crust either side, the
/// glow deep in it, a white-hot core, the air over it lit and shimmering,
/// embers lifting off. Revealed: it splits from the middle out, sparks
/// bursting.
void _fissure(FormView v, CosmeticAtlas over, CosmeticAtlas light) {
  final s = v.size;
  final split = _ease(v.reveal);
  final a = v.amount;
  final pts = _crack(v);
  final heat = 0.8 + 0.2 * math.sin(v.time * 1.7);
  for (var i = 0; i < pts.length - 1; i++) {
    final (x0, y0, d0) = pts[i];
    final (x1, y1, d1) = pts[i + 1];
    if (math.min(d0, d1) > split) continue;
    final rot = math.atan2(y1 - y0, x1 - x0);
    final wide = 1 - 0.5 * math.max(d0, d1);
    for (var j = 0; j < 5; j++) {
      final t = j / 5;
      final x = x0 + (x1 - x0) * t, y = y0 + (y1 - y0) * t;
      over.add(
        AtlasCell.pool,
        x,
        y + s * 0.02,
        s * 0.7 * wide,
        atlasArgb(const Color(0xFF0E0604), 0.85 * a),
        rot: rot,
      );
      light
        ..add(
          AtlasCell.pool,
          x,
          y,
          s * 0.55 * wide,
          atlasArgb(const Color(0xFFFF5A14), 0.55 * a * heat),
          rot: rot,
        )
        ..add(
          AtlasCell.pool,
          x,
          y,
          s * 0.3 * wide,
          atlasArgb(const Color(0xFFFFB040), 0.6 * a * heat),
          rot: rot,
        )
        ..add(
          AtlasCell.bead,
          x,
          y,
          s * 0.05 * wide,
          atlasArgb(const Color(0xFFFFF0B0), a * heat),
        );
    }
    light.add(
      AtlasCell.dot,
      (x0 + x1) / 2,
      (y0 + y1) / 2 - s * 0.2,
      s * 0.9 * wide,
      atlasArgb(const Color(0xFFFF6A1C), 0.1 * a * heat),
    );
  }
  // Sparks as it splits.
  if (v.reveal < 1) {
    for (var i = 0; i < 30; i++) {
      final life = (hash01(i, 761) + v.time * 1.4) % 1;
      final x = v.siteX + (hash01(i, 762) - 0.5) * s * 3.6 * split;
      light.add(
        AtlasCell.bead,
        x + (hash01(i, 763) - 0.5) * s * life,
        v.groundOr(x) - life * s * 1.1,
        s * 0.035,
        atlasArgb(const Color(0xFFFFC060), (1 - life) * a),
      );
    }
  }
  // Embers lifting off it.
  for (var i = 0; i < 26; i++) {
    final life = (hash01(i, 764) + v.time / (4 + 2 * hash01(i, 765))) % 1;
    final x = v.siteX + (hash01(i, 766) - 0.5) * s * 3 * split;
    light.add(
      AtlasCell.bead,
      x + math.sin(v.time * 2 + i) * s * 0.05,
      v.groundOr(x) - life * s * 1.6,
      s * 0.03,
      atlasArgb(
        Color.lerp(const Color(0xFFFFC060), const Color(0xFFA0280C), life)!,
        0.85 * math.sin(math.pi * life) * a,
      ),
    );
  }
}

/// An eruption: embers thrown up out of the fissure in arcs, falling.
void _eruption(FormView v, CosmeticAtlas light) {
  final e = kEruption.at(v.time);
  if (e == null || v.reveal < 1) return;
  final (k, f) = e;
  final s = v.size;
  final t = f * kEruption.duration;
  for (var i = 0; i < 34; i++) {
    final from = v.siteX + (hash01(k * 50 + i, 770) - 0.5) * s * 2.4;
    final vx = (hash01(k * 50 + i, 771) - 0.5) * s * 2.2;
    final vy = -s * (2.4 + 2.2 * hash01(k * 50 + i, 772));
    final g = s * 3.6;
    final x = from + vx * t;
    final y = v.groundOr(from) + vy * t + 0.5 * g * t * t;
    if (y > v.groundOr(x)) continue;
    final cool = (t / 2.2).clamp(0.0, 1.0);
    light
      ..add(
        AtlasCell.bead,
        x,
        y,
        s * 0.035,
        atlasArgb(
          Color.lerp(const Color(0xFFFFE08A), const Color(0xFFC0300C), cool)!,
          v.amount,
        ),
      )
      ..add(
        AtlasCell.dot,
        x,
        y,
        s * 0.16,
        atlasArgb(const Color(0xFFFF6A1C), 0.18 * v.amount * (1 - cool)),
      );
  }
}

/// Where the last eruption's embers came down: ash, fading.
void _ash(FormView v, CosmeticAtlas over) {
  final s = v.size;
  final now = (v.time / kEruption.period).floor();
  for (var k = now - 1; k <= now; k++) {
    if (k < 1) continue;
    final age = v.time - kEruption.startOf(k) - kEruption.duration;
    if (age < 0 || age > kAshLife) continue;
    final fade = 1 - age / kAshLife;
    for (var i = 0; i < 34; i++) {
      final from = v.siteX + (hash01(k * 50 + i, 770) - 0.5) * s * 2.4;
      final vx = (hash01(k * 50 + i, 771) - 0.5) * s * 2.2;
      final vy = -s * (2.4 + 2.2 * hash01(k * 50 + i, 772));
      // Where it lands: when its arc meets the ground again.
      final tLand = -2 * vy / (s * 3.6);
      final x = from + vx * tLand;
      over.add(
        AtlasCell.bead,
        x,
        v.groundOr(x),
        s * 0.03,
        atlasArgb(const Color(0xFF2A2420), 0.85 * fade * v.amount),
      );
    }
  }
}

// ── Oceanic ──────────────────────────────────────────────────────────────────

/// The near ground flooded: shallow water lying over it either side of the
/// site, about the residents' feet, the sky's light along its surface,
/// glinting, small lights swimming in it. Revealed: it seeps up and spreads
/// out from the site.
void _flood(
  FormView v,
  Canvas canvas,
  CosmeticAtlas over,
  CosmeticAtlas light,
) {
  final s = v.size;
  final spread = _ease(v.reveal);
  final reach = s * 6 * spread;
  if (reach < 1) return;
  final a = v.amount;
  final step = s * 0.2;
  final x0 = math.max(v.left - step, v.siteX - reach);
  final x1 = math.min(v.right + step, v.siteX + reach);
  final deep = s * 0.32 * spread;
  double edge(double x) => _ease((reach - (x - v.siteX).abs()) / (s * 1.2));
  Color water(double alpha) =>
      const Color(0xFF2E7E9E).withValues(alpha: alpha * a);
  final pos = <Offset>[];
  final col = <Color>[];
  for (var x = x0; x < x1; x += step) {
    final xb = math.min(x1, x + step);
    final ga = v.ground(x), gb = v.ground(xb);
    if (ga == null || gb == null) continue;
    final ea = edge(x), eb = edge(xb);
    final ta = ga - deep * ea, tb = gb - deep * eb;
    final ba = ga + s * 0.14, bb = gb + s * 0.14;
    pos.addAll([
      Offset(x, ta),
      Offset(xb, tb),
      Offset(x, ba),
      Offset(xb, tb),
      Offset(xb, bb),
      Offset(x, ba),
    ]);
    col.addAll([
      water(0.6 * ea),
      water(0.6 * eb),
      water(0.85 * ea),
      water(0.6 * eb),
      water(0.85 * eb),
      water(0.85 * ea),
    ]);
  }
  if (pos.isNotEmpty) {
    canvas.drawVertices(
      Vertices(VertexMode.triangles, pos, colors: col),
      BlendMode.dst,
      Paint(),
    );
  }
  for (var x = x0; x < x1; x += s * 0.6) {
    final g = v.ground(x);
    if (g == null) continue;
    final e = edge(x);
    light.add(
      AtlasCell.pool,
      x,
      g - deep * e,
      s * 1.1,
      atlasArgb(const Color(0xFFBFE8FF), 0.14 * e * a),
    );
  }
  for (var i = 0; i < 60; i++) {
    final x = x0 + (x1 - x0) * ((hash01(i, 780) + v.time * 0.01) % 1);
    final g = v.ground(x);
    if (g == null) continue;
    final e = edge(x);
    final tw = math.pow(0.5 + 0.5 * math.sin(v.time * 2 + i * 1.3), 6);
    light.add(
      AtlasCell.bead,
      x,
      g - deep * e,
      s * 0.04,
      atlasArgb(const Color(0xFFDFF6FF), (0.25 + 0.75 * tw) * e * a),
    );
  }
  for (var i = 0; i < 12; i++) {
    final drift = v.time * 0.03 * (hash01(i, 782) - 0.5);
    final x = x0 + (x1 - x0) * ((hash01(i, 781) + drift) % 1);
    final g = v.ground(x);
    if (g == null) continue;
    light.add(
      AtlasCell.dot,
      x,
      g - deep * 0.4,
      s * 0.16,
      atlasArgb(const Color(0xFF6CF2FF), (0.25 + 0.45 * v.night) * a),
    );
  }
}

// ── Earthen ──────────────────────────────────────────────────────────────────

/// The stones, as (along from the site, height, radius), in creature
/// sizes: one large and low, a middling one higher, a small one highest.
const List<(double, double, double)> _stoneSet = [
  (-1.3, 0.95, 0.44),
  (0.45, 1.75, 0.25),
  (1.7, 2.45, 0.15),
];

/// Stones risen out of the ground and floating, each made of packed earth
/// grains held together by whatever lifts it — lit along its top, its
/// edges always shedding grains that drift off and down, a thin stream of
/// grains rising to it from the ground it left. By day hazed, like things
/// far off; at night a seam of warm light through each, and the ground
/// under it lit. Revealed: the grains gather up off the ground into each
/// stone, one after another, as it rises. In a tremor they dip and shed
/// more.
void _stones(FormView v, CosmeticAtlas over, CosmeticAtlas light) {
  final s = v.size;
  final a = v.amount;
  final night = _ease((v.night - 0.15) / 0.6);
  final day = 1 - night;
  final quake = kTremor.at(v.time);
  final shake = quake == null || v.reveal < 1
      ? 0.0
      : math.sin(quake.$2 * math.pi);
  const dark = Color(0xFF2E2218), lit = Color(0xFFC49C68);
  const haze = Color(0xFFC8B8A2), seam = Color(0xFFFFB05A);
  for (var i = 0; i < _stoneSet.length; i++) {
    final (along, high, size) = _stoneSet[i];
    final gx = v.siteX + along * s;
    // Where there is no ground under it (between isles, over water) it
    // floats over the site's.
    final g = v.ground(gx) ?? v.siteY;
    final gather = _ease((v.reveal - i * 0.18) / 0.5);
    if (gather <= 0.01) continue;
    final r = s * size;
    final bob = math.sin(v.time * 0.45 + i * 1.7) * s * 0.05;
    final cx = gx + math.sin(v.time * 0.19 + i) * s * 0.03;
    final cy = g - (s * high + r) * gather + bob + shake * s * 0.14;
    final turn = v.time * (0.05 + 0.03 * i) * (i.isEven ? 1 : -1);
    final ct = math.cos(turn), st = math.sin(turn);
    // Its outline: round, but lumpy, its own.
    double edge(double ang) =>
        0.78 +
        0.14 * math.sin(ang * 3 + i * 2.1) +
        0.09 * math.sin(ang * 5 + i * 0.7);
    // A soft mass under its grains, so it reads as one stone: its own dark,
    // lit toward its top.
    for (var k = 0; k < 22; k++) {
      final ang = hash01(i * 64 + k, 830) * math.pi * 2;
      final rad = math.sqrt(hash01(i * 64 + k, 831)) * edge(ang) * 0.5;
      final ux = math.cos(ang) * rad, uy = math.sin(ang) * rad * 0.82;
      final rx = ux * ct - uy * st, ry = ux * st + uy * ct;
      final up = (-(rx * 0.45 + ry * 0.9)).clamp(-1.0, 1.0);
      final c = Color.lerp(
        Color.lerp(dark, lit, 0.2 + 0.3 * up)!,
        haze,
        0.1 * day,
      )!;
      final fx = gx + (hash01(i * 64 + k, 832) - 0.5) * s * 2.4;
      final x = cx + rx * r, y = cy + ry * r;
      over.add(
        AtlasCell.bead,
        gather < 1 ? fx + (x - fx) * gather : x,
        gather < 1 ? g + (y - g) * gather : y,
        r * 0.7,
        atlasArgb(c, 0.92 * gather * a),
      );
    }
    final grains = (40 + 2400 * size * size).round();
    final grain = s * (0.03 + 0.04 * size);
    for (var k = 0; k < grains; k++) {
      final ang = hash01(i * 4096 + k, 820) * math.pi * 2;
      final rad = math.sqrt(hash01(i * 4096 + k, 821)) * edge(ang);
      // In its own frame, turning; flattened a little.
      final ux = math.cos(ang) * rad, uy = math.sin(ang) * rad * 0.82;
      final rx = ux * ct - uy * st, ry = ux * st + uy * ct;
      var x = cx + rx * r, y = cy + ry * r;
      var alpha = 1.0;
      // Its rim sheds: grains drifting off and down, and back.
      final rim = rad / edge(ang);
      if (rim > 0.8) {
        final life =
            (hash01(i * 4096 + k, 822) +
                v.time / (3.5 + 2 * hash01(k, 823)) * (1 + shake * 2)) %
            1;
        if (hash01(i * 4096 + k, 824) < 0.55) {
          x += rx * r * 0.5 * life;
          y += ry * r * 0.3 * life + life * life * s * 0.5;
          alpha = 1 - life;
        }
      }
      // Gathering: from where it lay on the ground to its place.
      if (gather < 1) {
        final fromX = gx + (hash01(i * 4096 + k, 825) - 0.5) * s * 2.4;
        x = fromX + (x - fromX) * gather;
        y = g + (y - g) * gather;
      }
      // Lit from above and to the left.
      final up = (-(rx * 0.45 + ry * 0.9)).clamp(-1.0, 1.0);
      final tone = 0.5 + 0.5 * up + (hash01(i * 4096 + k, 826) - 0.5) * 0.25;
      var c = Color.lerp(dark, lit, tone.clamp(0.0, 1.0))!;
      // By day, far off: the air between.
      c = Color.lerp(c, haze, 0.1 * day)!;
      over.add(
        AtlasCell.bead,
        x,
        y,
        grain * (0.75 + 0.5 * hash01(i * 4096 + k, 827)),
        atlasArgb(c, alpha * a),
      );
      // Its seam: the grains along one curve through it, warm, at night.
      final onSeam = (ry - 0.3 * math.sin(rx * 2.4 + i)).abs() < 0.07;
      if (onSeam && night > 0.02 && alpha > 0.5) {
        light.add(
          AtlasCell.bead,
          x,
          y,
          grain * 1.2,
          atlasArgb(seam, (0.25 + 0.75 * night) * a),
        );
      }
    }
    if (night > 0.02) {
      light
        ..add(
          AtlasCell.dot,
          cx,
          cy,
          r * 2.6,
          atlasArgb(seam, 0.12 * night * a * gather),
        )
        ..add(
          AtlasCell.pool,
          gx,
          g,
          s * (0.5 + size * 2),
          atlasArgb(seam, 0.16 * night * a * gather),
        );
    }
    // A thin stream of grains rising to it from the ground it left.
    if (gather >= 1) {
      final top = cy + r * 0.75;
      for (var k = 0; k < 18; k++) {
        final life =
            (hash01(i * 64 + k, 828) + v.time / (5 + 2 * hash01(k, 829))) % 1;
        final y = g + (top - g) * life;
        final x =
            gx +
            (cx - gx) * life +
            math.sin(v.time * 1.3 + k * 1.9) * s * 0.05 * (1 - life);
        over.add(
          AtlasCell.bead,
          x,
          y,
          s * 0.018,
          atlasArgb(
            Color.lerp(const Color(0xFF8A7458), haze, 0.3 * day)!,
            0.7 * math.sin(math.pi * life) * a,
          ),
        );
      }
    }
  }
}

/// A tremor: dust jumping off the ground all along, pebbles hopping.
void _tremor(FormView v, CosmeticAtlas over, CosmeticAtlas light) {
  final e = kTremor.at(v.time);
  if (e == null || v.reveal < 1) return;
  final (k, f) = e;
  final shake = math.sin(f * math.pi);
  final s = v.size;
  final w = v.right - v.left;
  for (var i = 0; i < 46; i++) {
    final x = v.left + w * hash01(k * 46 + i, 798);
    final g = v.ground(x);
    if (g == null) continue;
    final hop = (math.sin(v.time * 22 + i * 1.7)).abs() * s * 0.08 * shake;
    over
      ..add(
        AtlasCell.bead,
        x,
        g - hop,
        s * 0.025,
        atlasArgb(const Color(0xFF6A5A48), 0.9 * shake * v.amount),
      )
      ..add(
        AtlasCell.dot,
        x,
        g - s * 0.1 * shake,
        s * 0.5,
        atlasArgb(const Color(0xFFB09070), 0.12 * shake * v.amount),
      );
  }
}

// ── Verdant ──────────────────────────────────────────────────────────────────

/// The bloom colors: pale and luminous, as the night lights them.
const List<Color> _bloomColors = [
  Color(0xFFA8F0DC),
  Color(0xFFD8C4FF),
  Color(0xFFFFE6A8),
  Color(0xFFB8DCFF),
];

/// One bloom of light at ([x], [y]): petals of soft light round a bright
/// heart, [open] 0 (a bud) to 1, glowing [glow] (more by night, near
/// someone), a creature [s] across. Nothing drawn but light.
void _bloom(
  CosmeticAtlas light,
  double x,
  double y,
  double s,
  Color c,
  double open,
  double glow,
  int seed,
  double amount, {
  CosmeticAtlas? over,
  double day = 0,
}) {
  final petals = 5 + seed % 2;
  final r = s * (0.015 + 0.05 * open);
  final turn = hash01(seed, 805) * math.pi;
  for (var p = 0; p < petals; p++) {
    final ang = turn + p / petals * math.pi * 2;
    // By day a flower in the grass, its color laid on.
    if (over != null && day > 0.01) {
      over.add(
        AtlasCell.bead,
        x + math.cos(ang) * r,
        y + math.sin(ang) * r * 0.55,
        s * (0.03 + 0.035 * open),
        atlasArgb(
          Color.lerp(c, const Color(0xFF6A5A8A), 0.25)!,
          0.85 * day * amount,
        ),
      );
    }
    light.add(
      AtlasCell.dot,
      x + math.cos(ang) * r,
      y + math.sin(ang) * r * 0.55,
      s * (0.035 + 0.05 * open),
      atlasArgb(c, (0.18 + 0.4 * glow) * (0.3 + 0.7 * open) * amount),
    );
  }
  light
    ..add(
      AtlasCell.bead,
      x,
      y,
      s * (0.018 + 0.012 * open),
      atlasArgb(
        Color.lerp(c, const Color(0xFFFFFFFF), 0.6)!,
        (0.4 + 0.6 * glow) * amount,
      ),
    )
    ..add(
      AtlasCell.pool,
      x,
      y + s * 0.03,
      s * (0.2 + 0.25 * open),
      atlasArgb(c, 0.1 * glow * amount),
    );
}

/// The whole ground in flower: blooms of light all along it, open and
/// glowing by night, closed to dim buds by day, swaying; brighter where
/// someone stands near; pollen of light lifting off at night. Revealed: a
/// wave of blooming spreading out from the site across the field.
void _meadow(FormView v, CosmeticAtlas over, CosmeticAtlas light) {
  final s = v.size;
  final a = v.amount;
  final night = _ease((v.night - 0.15) / 0.6);
  const tile = 620.0;
  final wave = v.reveal >= 1 ? double.infinity : v.reveal * tile * 6;
  final k0 = (v.left / tile).floor() - 1, k1 = (v.right / tile).floor() + 1;
  for (var k = k0; k <= k1; k++) {
    for (var i = 0; i < 26; i++) {
      final seed = (k & 0xFFFF) * 64 + i;
      final x0 = k * tile + hash01(seed, 806) * tile;
      if (x0 < v.left - 20 || x0 > v.right + 20) continue;
      final g = v.ground(x0);
      if (g == null) continue;
      final d = (x0 - v.siteX).abs();
      if (d > wave) continue;
      // The wave's front flares as it passes.
      final front = wave.isFinite ? _ease(1 - (wave - d) / (s * 1.6)) : 0.0;
      var near = 0.0;
      for (final f in v.feet) {
        final fd = (f.x - x0).abs() / (f.size * 0.7);
        if (fd < 1) near = math.max(near, 1 - fd);
      }
      final open = 0.55 + 0.45 * night + 0.3 * front;
      final glow = (0.25 + 0.75 * night + 0.6 * near + front).clamp(0.0, 1.4);
      final sway = math.sin(v.time * 0.8 + seed * 0.7) * s * 0.02;
      final y = g - s * 0.04 + (hash01(seed, 807) - 0.35) * s * 0.14;
      _bloom(
        light,
        x0 + sway,
        y,
        s,
        _bloomColors[seed % _bloomColors.length],
        open.clamp(0.0, 1.0),
        glow,
        seed,
        a,
        over: over,
        day: 1 - night,
      );
      // Pollen of light lifting off, at night.
      if (night > 0.2 && seed % 5 == 0) {
        final life = (hash01(seed, 808) + v.time / 6) % 1;
        light.add(
          AtlasCell.bead,
          x0 + sway + math.sin(v.time + seed) * s * 0.08,
          y - life * s * 1.2,
          s * 0.018,
          atlasArgb(
            _bloomColors[seed % _bloomColors.length],
            0.7 * math.sin(math.pi * life) * night * a,
          ),
        );
      }
    }
  }
}

/// Where a gust's [i]th seed comes down, from the [k]th gust: (x share of
/// the view's width it falls across, from 0 to 1).
double _seedLand(int k, int i) => hash01(k * 30 + i, 810);

/// A gust: seeds carried across the view on the wind, settling.
void _gust(FormView v, CosmeticAtlas light) {
  final e = kSeedGust.at(v.time);
  if (e == null || v.reveal < 1) return;
  final (k, f) = e;
  final w = v.right - v.left;
  for (var i = 0; i < 22; i++) {
    final land = v.left + w * _seedLand(k, i);
    // Blown in from the left, settling where it lands.
    final x = land - (1 - f) * w * 0.8;
    final g = v.groundOr(land);
    final y =
        g -
        (1 - f) * v.size * (1.5 + hash01(i, 811)) +
        math.sin(v.time * 3 + i) * v.size * 0.1 * (1 - f);
    light.add(
      AtlasCell.bead,
      x,
      y,
      v.size * 0.03,
      atlasArgb(
        const Color(0xFFC8F07A),
        0.9 * v.amount * math.min(1, (1 - f) * 4 + 0.2),
      ),
    );
  }
}

/// What the last gusts sowed: blooms where it came down, opening, and
/// fading again.
void _sown(FormView v, CosmeticAtlas light) {
  final s = v.size;
  final w = v.right - v.left;
  final now = (v.time / kSeedGust.period).floor();
  for (var k = now - 1; k <= now; k++) {
    if (k < 1) continue;
    final age = v.time - kSeedGust.startOf(k) - kSeedGust.duration;
    if (age < 0 || age > kFlowerLife) continue;
    final bloom = _ease(age / 3) * (1 - _ease((age - kFlowerLife + 6) / 6));
    for (var i = 0; i < 22; i++) {
      final x = v.left + w * _seedLand(k, i);
      final g = v.ground(x);
      if (g == null) continue;
      _bloom(
        light,
        x,
        g - s * 0.04,
        s,
        _bloomColors[(k + i) % _bloomColors.length],
        bloom,
        0.5 + 0.5 * v.night,
        k * 30 + i,
        v.amount * bloom,
      );
    }
  }
}
