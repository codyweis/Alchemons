import 'dart:math';
import 'dart:ui' as ui;
import 'cosmic_data.dart';
import 'cosmic_projectile_vfx.dart' show ZoneVfxEmit;
import 'vfx_shapes.dart';

const _elements = {
  'Crystal',
  'Light',
  'Water',
  'Dark',
  'Air',
  'Dust',
  'Lava',
  'Poison',
  'Plant',
  'Blood',
  'Earth',
  'Spirit',
  'Fire',
  'Lightning',
  'Steam',
  'Ice',
  'Mud',
};
const _contactElements = {
  'Crystal',
  'Light',
  'Water',
  'Dark',
  'Air',
  'Fire',
  'Blood',
  'Lightning',
};
bool _isTrap(Projectile p) =>
    p.abilityFamily == 'mask' &&
    p.visualStyle == ProjectileVisualStyle.sigil &&
    _elements.contains(p.element);
double _areaRadius(Projectile p) =>
    max(20.0, max(p.snareRadius, p.effectRadius)).clamp(20.0, 260.0);

/// How much of the art radius each contact trap's solid body fills: Crystal's
/// shards, Light's lens, Water's pool, Air's hollow, Fire's ball (spread
/// 0.42 r) and Blood's blob.
const _bodyFill = {
  'Crystal': 0.7,
  'Light': 0.72,
  'Water': 0.84,
  'Air': 0.8,
  'Fire': 0.42,
  'Blood': 0.62,
};

/// A trap that does its work on whatever touches it — Air's push, Light's
/// execute, Blood's drain, Crystal's split, Fire's ball, Water's splash —
/// springs on CONTACT: `Projectile.radius * radiusMultiplier` (Beauty)
/// against the body's own radius. A fire POOL ticks its area instead.
bool _springsOnContact(Projectile p) =>
    p.tickEffect == AbilityEffectKind.none && _bodyFill.containsKey(p.element);

/// The radius a trap's art is drawn at. A contact trap is drawn so its solid
/// body lands on its contact radius — exactly as big as what sets it off, and
/// growing with it. (It was drawn at effectRadius, an Intelligence number,
/// 12-21x the trigger: an enemy could walk across most of the drawn trap
/// without springing it.) Every other trap is drawn over the area it acts on.
double _radius(Projectile p) => _springsOnContact(p)
    ? (Projectile.radius * p.radiusMultiplier / _bodyFill[p.element]!).clamp(
        4.0,
        260.0,
      )
    : _areaRadius(p);

/// How far a trap's springing reaches: Water's splash and Crystal's split
/// hit everything in effectRadius round the struck body; Air, Light, Blood
/// and Fire act on the body that touched them.
double _echoRadius(Projectile p) =>
    _springsOnContact(p) && p.element != 'Water' && p.element != 'Crystal'
    ? _radius(p)
    : _areaRadius(p);

/// Visual-only contact echoes, independent of a trap's remaining gameplay life.
/// One echo per fixture at a time prevents per-frame collision flash storms.
class MaskTrapVisuals {
  final List<_MaskContact> _contacts = [];
  int get activeCount => _contacts.length;

  /// True only when a new echo starts -- the trap SPRINGING, which is when
  /// its sound plays (never on the contact frames that follow).
  bool contact(Projectile p) {
    if (!_isTrap(p) ||
        !_contactElements.contains(p.element) ||
        _contacts.any((fx) => identical(fx.source, p))) {
      return false;
    }
    if (_contacts.length >= 24) _contacts.removeAt(0);
    _contacts.add(_MaskContact(p, p.position, _echoRadius(p), p.element!));
    return true;
  }

  void update(double dt) {
    for (final fx in _contacts) {
      fx.age += dt;
    }
    _contacts.removeWhere((fx) => fx.age >= 0.55);
  }

  void render(ui.Canvas canvas, {bool reduced = false, ui.Rect? viewport}) {
    for (final fx in _contacts) {
      if (viewport != null &&
          !viewport.overlaps(
            ui.Rect.fromCircle(center: fx.position, radius: fx.radius * 1.4),
          )) {
        continue;
      }
      drawMaskTrapContact(
        canvas: canvas,
        position: fx.position,
        radius: fx.radius,
        element: fx.element,
        progress: fx.age / 0.55,
        reduced: reduced,
      );
    }
  }
}

class _MaskContact {
  _MaskContact(this.source, this.position, this.radius, this.element);
  final Projectile source;
  final ui.Offset position;
  final double radius;
  final String element;
  double age = 0;
}

// Shared paints: these painters run per fixture per frame, so none of them
// allocates a Paint, and the spills reuse one unit gradient per colour.
final ui.Paint _maskPaint = ui.Paint();
final ui.Paint _maskSpillPaint = ui.Paint();
final Map<int, ui.Shader> _maskSpillShaders = {};

ui.Shader _maskSpillShader(ui.Color color) =>
    _maskSpillShaders[color.toARGB32()] ??= ui.Gradient.radial(
      ui.Offset.zero,
      1,
      [
        color.withValues(alpha: 1),
        color.withValues(alpha: 0.4),
        color.withValues(alpha: 0),
      ],
      const [0.0, 0.45, 1.0],
    );

/// Radial light spill stays soft without a blur filter or offscreen layer.
void _maskLightSpill(
  ui.Canvas canvas,
  ui.Offset centre,
  double radius,
  ui.Color color,
  double strength, {
  double squash = 1,
}) {
  if (strength <= 0.004 || radius <= 0.5) return;
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.scale(radius, radius * squash);
  canvas.drawCircle(
    ui.Offset.zero,
    1,
    _maskSpillPaint
      ..shader = _maskSpillShader(color)
      ..color = ui.Color.fromRGBO(255, 255, 255, strength.clamp(0.0, 1.0)),
  );
  canvas.restore();
}

/// Authored fixtures are restricted to Mask; shared pool painters used by other
/// families retain their existing appearance. No runes or hard void outlines.
bool drawMaskTrapFixture({
  required ui.Canvas canvas,
  required Projectile projectile,
  required ui.Offset position,
  required double time,
  bool reduced = false,
}) {
  if (!_isTrap(projectile)) return false;
  final element = projectile.element!;
  final r = _radius(projectile);
  final paint = _maskPaint..shader = null;
  canvas.save();
  canvas.translate(position.dx, position.dy);
  // Survival keeps consumed Light/Crystal fixtures briefly for their existing
  // activation timer. Collapse the fixture while independent debris finishes.
  final flash = projectile.abilityGrowthTimer.clamp(0.0, 1.0);
  if (flash > 0 && (element == 'Light' || element == 'Crystal')) {
    final window = element == 'Light' ? 0.64 : 0.48;
    canvas.scale((1 - (1 - flash) / window).clamp(0.04, 1.0));
  }

  void fill(ui.Path path, ui.Color ink, double alpha) => canvas.drawPath(
    path,
    paint
      ..style = ui.PaintingStyle.fill
      ..color = ink.withValues(alpha: alpha.clamp(0.0, 1.0)),
  );
  // What used to be strokes are filled lens ribbons (vfxLensRibbon): seams
  // and reflections that swell and taper, never a wire.
  // A little emitted light restores distant readability without outlining
  // the material. Fire/Lava get their stronger, footprint-aware spill below.
  if (element != 'Fire' && element != 'Lava' && element != 'Mud') {
    final tint = switch (element) {
      'Light' => const ui.Color(0xFFE4D6AB),
      'Crystal' => const ui.Color(0xFF7BBC9C),
      'Water' => const ui.Color(0xFF619BAE),
      'Dark' => const ui.Color(0xFF9768B6),
      'Blood' => const ui.Color(0xFFAA3658),
      'Poison' => const ui.Color(0xFF91A85C),
      'Lightning' => const ui.Color(0xFFB2B9E3),
      'Ice' => const ui.Color(0xFF92BFC9),
      'Plant' || 'Earth' => const ui.Color(0xFF8BAB6B),
      'Dust' => const ui.Color(0xFFAC916D),
      _ => const ui.Color(0xFFA6BBC5),
    };
    // A contact trap is drawn the size of what sets it off, so it also
    // pools a slow-breathing light a little wider than itself: where it
    // lies reads from across the field, and the body still says exactly
    // how close is too close. Kept faint, since a field of them overlaps.
    final mine = _springsOnContact(projectile);
    final breathe = 0.85 + 0.15 * sin(time * 1.6 + position.dx * 0.01);
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * (mine ? 1.6 : 1.1),
      tint,
      ((element == 'Light' || element == 'Lightning' ? 0.22 : 0.15) +
              flash * 0.10) *
          (mine ? breathe : 1),
      squash: element == 'Light' ? 1.0 : 0.7,
    );
  }
  // Stable irregularity belongs to the fixture; only light and fluid move.
  final seed = position.dx * 0.013 + position.dy * 0.017;
  if (element == 'Crystal') {
    // Broken smoky mineral, not a symmetrical jewel icon. Faces overlap and
    // only interrupted internal fractures catch the cold alchemical light.
    // Every shard's body, face and fracture go into one path each: three
    // fills a mine however many shards it has.
    final bodies = ui.Path();
    final faces = ui.Path();
    final fractures = ui.Path();
    var lit = 0.0;
    final shards = reduced ? 4 : 6;
    for (var i = 0; i < shards; i++) {
      final angle = i * 2.399 + seed;
      final base = ui.Offset(
        cos(angle) * r * 0.28,
        sin(angle) * r * 0.18 + r * 0.12,
      );
      final lean = sin(i * 7.3 + seed) * r * 0.22;
      final height = r * (0.38 + 0.35 * (0.5 + 0.5 * sin(i * 4.1 + 1)));
      final width = r * (0.10 + 0.045 * cos(i * 2.1));
      final tip = base + ui.Offset(lean, -height);
      final edge = base + ui.Offset(width, -height * 0.3);
      final shard = ui.Path()
        ..moveTo(base.dx - width, base.dy)
        ..lineTo(base.dx - width * 1.2, base.dy - height * 0.5)
        ..lineTo(tip.dx - width * 0.4, tip.dy + height * 0.1)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(edge.dx, edge.dy)
        ..lineTo(base.dx + width * 0.7, base.dy + r * 0.08)
        ..close();
      bodies.addPath(shard, ui.Offset.zero);
      final face = ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(edge.dx, edge.dy)
        ..lineTo(base.dx + width * 0.7, base.dy + r * 0.08)
        ..lineTo(base.dx - width * 0.3, base.dy - height * 0.32)
        ..close();
      faces.addPath(face, ui.Offset.zero);
      // One lit sliver inside the stone where a glow and a hairline were.
      final fracture = vfxPolylineSpine([
        ui.Offset(tip.dx - width * 0.2, tip.dy + height * 0.23),
        ui.Offset(base.dx - width * 0.25, base.dy - height * 0.4),
        ui.Offset(base.dx + width * 0.25, base.dy - height * 0.31),
      ]);
      vfxLensRibbon(fracture, max(1.6, r * 0.034), taper: 0.45, into: fractures);
      lit += sin(time * 1.1 + i);
    }
    fill(bodies, const ui.Color(0xFF192B2A), 0.95);
    fill(faces, const ui.Color(0xFF405851), 0.6);
    fill(fractures, const ui.Color(0xFFA6C7AD), 0.42 + 0.12 * lit / shards);
  } else if (element == 'Light') {
    // A slit in the world with light behind it: a narrow lit lens, widest at
    // the middle, over a pale spill. Thin by nature, but never a hairline.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 0.55,
      const ui.Color(0xFFE4D6AB),
      0.16,
      squash: 1.6,
    );
    ui.Path lens(double halfWidth) => ui.Path()
      ..moveTo(-r * 0.04, -r * 0.72)
      ..quadraticBezierTo(halfWidth * 1.6, -r * 0.1, r * 0.03, r * 0.64)
      ..quadraticBezierTo(-halfWidth * 1.6, r * 0.05, -r * 0.04, -r * 0.72)
      ..close();
    final breathe = 0.85 + 0.15 * sin(time * 1.3 + seed);
    fill(lens(r * 0.11 * breathe), const ui.Color(0xFFBDB7A0), 0.16);
    fill(lens(r * 0.05 * breathe), const ui.Color(0xFFE0DCCD), 0.5);
    fill(lens(r * 0.018), const ui.Color(0xFFF6F2E4), 0.9);
    // Grains of light drawn in toward the slit: one batch.
    for (var i = 0; i < (reduced ? 4 : 9); i++) {
      final t = (time * 0.14 + i * 0.618) % 1;
      final side = i.isEven ? 1.0 : -1.0;
      final x = side * r * (0.08 + 0.45 * (1 - t));
      final y = r * sin(i * 7.7 + seed) * 0.6;
      vfxGrain(x, y);
    }
    vfxGrainsFlush(
      canvas,
      max(1.6, r * 0.03),
      const ui.Color(0xFFD8D2BC),
      0.4,
    );
  } else if (element == 'Water') {
    // Ink-dark liquid with a ragged meniscus and broken silver reflections.
    final pool = ui.Path();
    for (var i = 0; i <= 64; i++) {
      final a = i * pi * 2 / 64;
      final uneven =
          0.84 + 0.06 * sin(a * 5 + seed) + 0.04 * sin(a * 9 - time * 0.35);
      final p = ui.Offset(cos(a) * r * uneven, sin(a) * r * uneven * 0.55);
      if (i == 0) {
        pool.moveTo(p.dx, p.dy);
      } else {
        pool.lineTo(p.dx, p.dy);
      }
    }
    pool.close();
    // The faint meniscus: the pool again, a touch larger, under the liquid.
    canvas.save();
    canvas.scale(1.06);
    fill(pool, const ui.Color(0xFF40545A), 0.06);
    canvas.restore();
    // Deep water, not a black hole: a dark teal body with light lying on
    // its surface.
    fill(pool, const ui.Color(0xFF0B2230), 0.94);
    _maskLightSpill(
      canvas,
      ui.Offset(-r * 0.08, -r * 0.06),
      r * 0.72,
      const ui.Color(0xFF619BAE),
      0.2,
      squash: 0.55,
    );
    // Broken silver reflections, every one in a single path; each shimmers
    // by thinning rather than by its own alpha.
    final reflections = ui.Path();
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 3 : 7); i++) {
      final y = sin(i * 5.7 + seed) * r * 0.32;
      final x = sin(i * 3.1 + 1) * r * 0.3;
      final span = r * (0.18 + 0.09 * sin(i + time * 0.7));
      vfxLensRibbon(
        vfxQuadSpine(
          ui.Offset(x - span, y),
          ui.Offset(x, y + r * 0.025 * sin(time + i)),
          ui.Offset(x + span, y - r * 0.016),
          into: spine..clear(),
        ),
        max(1.4, r * 0.024) * (0.75 + 0.25 * sin(time * 0.6 + i)),
        into: reflections,
      );
    }
    fill(reflections, const ui.Color(0xFF9FB8BC), 0.4);
    // Light caught on the rim: short crescents hugging the far edge.
    final rim = ui.Path();
    for (var i = 0; i < 3; i++) {
      vfxEllipseCrescent(
        ui.Offset.zero,
        r * 0.81,
        r * 0.435,
        max(1.6, r * 0.026),
        i * 2.4 + 0.2 + 0.19,
        0.38,
        into: rim,
      );
    }
    fill(rim, const ui.Color(0xFF8AA3A8), 0.5);
  } else if (element == 'Dark') {
    // A stain in space with a soft irregular edge. Short wisps vanish into
    // it rather than drawing a bright, complete pinwheel around the hole.
    for (var layer = 3; layer >= 0; layer--) {
      final stain = ui.Path();
      for (var i = 0; i <= 48; i++) {
        final a = i * pi * 2 / 48;
        final rad = r * (0.35 + layer * 0.1 + 0.025 * sin(a * 5 + time * 0.3));
        final p = ui.Offset(cos(a), sin(a)) * rad;
        if (i == 0) {
          stain.moveTo(p.dx, p.dy);
        } else {
          stain.lineTo(p.dx, p.dy);
        }
      }
      stain.close();
      fill(stain, const ui.Color(0xFF020207), 0.3 + (3 - layer) * 0.13);
    }
    // Wisps drawn into the stain: tapered ribbons sharing one path, each
    // thinning to nothing as it sinks rather than fading on its own alpha.
    final wisps = ui.Path();
    final spine = <ui.Offset>[];
    for (var arm = 0; arm < (reduced ? 3 : 6); arm++) {
      final phase = (time * 0.18 + arm * 0.618) % 1;
      spine.clear();
      for (var i = 0; i <= 12; i++) {
        final t = i / 12;
        final a = arm * 2.399 + phase * 0.7 + t * 0.42;
        final rad = r * (0.95 - phase * 0.55 - t * 0.17);
        spine.add(ui.Offset(cos(a), sin(a)) * rad);
      }
      vfxLensRibbon(
        spine,
        max(1.4, r * 0.036) * sin(phase * pi),
        taper: 0.3,
        taperEnd: 0.7,
        into: wisps,
      );
    }
    fill(wisps, const ui.Color(0xFF786386), 0.4);
  } else {
    _drawRemainingMask(canvas, projectile, r, time, seed, reduced);
  }
  canvas.restore();
  return true;
}

/// Secondary Mask materials. Every shape is seeded and bounded so large
/// trap scatters remain stable and do not allocate particle systems per tile.
void _drawRemainingMask(
  ui.Canvas canvas,
  Projectile p,
  double r,
  double time,
  double seed,
  bool reduced,
) {
  final element = p.element!;
  final paint = _maskPaint..shader = null;
  void fill(ui.Path shape, Object color, double a) => canvas.drawPath(
    shape,
    paint
      ..style = ui.PaintingStyle.fill
      ..color = (color is ui.Color ? color : ui.Color(color as int)).withValues(
        alpha: a.clamp(0.0, 1.0),
      ),
  );
  ui.Path patch(
    double x,
    double y,
    double radius,
    double squash,
    double phase,
  ) {
    final path = ui.Path();
    for (var i = 0; i <= 32; i++) {
      final a = i * pi * 2 / 32;
      final wob = 0.87 + 0.08 * sin(a * 5 + phase) + 0.05 * sin(a * 9 - phase);
      final dx = x + cos(a) * radius * wob;
      final dy = y + sin(a) * radius * wob * squash;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }
    return path..close();
  }

  final flash = p.abilityGrowthTimer.clamp(0.0, 1.0);
  if (element == 'Lava' || element == 'Fire') {
    final pool = element == 'Lava' || p.tickEffect == AbilityEffectKind.burn;
    final spread = pool ? r : r * 0.42;
    final fire = element == 'Fire';
    final warmth = 0.8 + 0.12 * sin(time * 2.1 + seed);
    // The heat it throws is its material's light (Fire E0703A, Lava
    // D9602E), not raw saturated orange.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      spread * 1.55,
      ui.Color(fire ? 0xFFE0703A : 0xFFD9602E),
      0.36 * warmth,
      squash: pool ? 0.7 : 1,
    );
    fill(patch(0, 0, spread, pool ? 0.63 : 0.8, seed), 0xFF271B19, 0.95);
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      spread * 0.95,
      ui.Color(fire ? 0xFFEC9356 : 0xFFE28046),
      0.20 * warmth,
      squash: pool ? 0.6 : 0.8,
    );
    // Cracked cinder hides most of the heat; ember seams pulse beneath it.
    // Every seam goes into one path per layer — a faint wide heat band and
    // the lit seam — so a trap costs two fills however many seams it has
    // (the band stays at reduced quality: without it a seam is a flat decal).
    // Each seam pulses by swelling, since they share one alpha.
    final m = vfxMaterial(element);
    final seams = ui.Path();
    final halo = ui.Path();
    final cinders = fire ? ui.Path() : null;
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final a = i * 2.399 + seed;
      final x = cos(a) * spread * 0.65;
      final y = sin(a) * spread * (pool ? 0.35 : 0.5);
      final heat = 0.72 + 0.20 * sin(time * 1.6 + i) + flash * 0.12;
      spine.clear();
      if (!fire) {
        // A fissure that wanders through its old corners as two smooth
        // bends, so it reads as a crack in the crust rather than a zig-zag.
        final p1 = ui.Offset(
          x - spread * 0.04,
          y + spread * 0.065 * sin(i * 4.3),
        );
        final p2 = ui.Offset(x + spread * 0.03, y - spread * 0.05);
        final mid = (p1 + p2) / 2;
        vfxQuadSpine(ui.Offset(x - spread * 0.16, y), p1, mid, n: 5, into: spine);
        spine.removeLast();
        vfxQuadSpine(
          mid,
          p2,
          ui.Offset(x + spread * 0.18, y + spread * 0.07 * cos(i * 2.7)),
          n: 5,
          into: spine,
        );
        vfxLensRibbon(spine, spread * (0.03 + 0.035 * heat), into: seams);
        vfxLensRibbon(spine, spread * 0.115, taper: 0.45, into: halo);
      } else {
        cinders!.addPath(
          patch(x, y, spread * 0.12, 0.55, i.toDouble()),
          ui.Offset.zero,
        );
        // A tongue of flame: broad at the cinder, drawn up to a point that
        // sways slowly, so it licks rather than hooks.
        vfxQuadSpine(
          ui.Offset(x - spread * 0.02, y),
          ui.Offset(
            x + spread * 0.06 * sin(time * 1.7 + i * 2),
            y - spread * 0.12,
          ),
          ui.Offset(
            x + spread * 0.04 * sin(time * 2.3 + i),
            y - spread * 0.36 * heat,
          ),
          into: spine,
        );
        vfxLensRibbon(
          spine,
          spread * (0.05 + 0.04 * heat),
          taper: 0.2,
          taperEnd: 0.8,
          into: seams,
        );
        vfxLensRibbon(
          spine,
          spread * 0.125,
          taper: 0.22,
          taperEnd: 0.78,
          into: halo,
        );
      }
    }
    if (cinders != null) fill(cinders, 0xFF5C4436, 0.35);
    fill(halo, m.light, 0.26 * warmth + flash * 0.08);
    fill(
      seams,
      ui.Color.lerp(m.glint, m.light, 0.25)!,
      0.62 + 0.25 * warmth + flash * 0.1,
    );
    if (fire) {
      // Sparks lifting off: small drops in one path, each shrinking away at
      // the top of its climb instead of fading on its own alpha.
      final sparks = ui.Path();
      for (var i = 0; i < (reduced ? 3 : 6); i++) {
        final t = (time * 0.38 + i * 0.618) % 1;
        final s = r * 0.012 * sin(t * pi);
        if (s < 0.3) continue;
        sparks.addPath(
          vfxDrop(
            ui.Offset(sin(i * 7.7) * spread * 0.6, -spread * 0.15 - t * spread),
            s,
            -pi / 2 + 0.4,
          ),
          ui.Offset.zero,
        );
      }
      fill(sparks, m.glint, 0.85);
    }
  } else if (element == 'Blood') {
    // A living blob: glossy, round, and it beats. Veins run out of it toward
    // whatever it has fed on.
    final beat = pow(max(0.0, sin(time * 2.4 + seed)), 6).toDouble();
    final swell = 1 + 0.05 * beat + flash * 0.06;
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 1.05,
      const ui.Color(0xFFAA3658),
      0.10 + 0.10 * beat,
      squash: 0.6,
    );
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final a = i * 2.399 + seed;
      final spine = <ui.Offset>[
        for (var k = 0; k <= 6; k++)
          ui.Offset(
            cos(a + sin(k * 1.3 + i) * 0.12) * r * (0.35 + 0.6 * k / 6),
            sin(a + sin(k * 1.3 + i) * 0.12) * r * (0.35 + 0.6 * k / 6) * 0.58,
          ),
      ];
      fill(
        vfxRibbon(spine, r * 0.07, r * 0.008),
        const ui.Color(0xFF4A0F1C),
        0.8,
      );
      fill(
        vfxRibbon(spine, r * 0.025, r * 0.004),
        const ui.Color(0xFF9C3048),
        0.35 + 0.25 * beat,
      );
    }
    fill(
      vfxBlob(
        ui.Offset.zero,
        r * 0.6 * swell,
        seed,
        n: 14,
        wobble: 0.07,
        squash: 0.62,
      ),
      const ui.Color(0xFF22060C),
      0.96,
    );
    fill(
      vfxBlob(
        const ui.Offset(0, -2),
        r * 0.42 * swell,
        seed + 2,
        n: 12,
        wobble: 0.1,
        squash: 0.6,
      ),
      const ui.Color(0xFF5A1422),
      0.55 + 0.2 * beat,
    );
    canvas.save();
    canvas.scale(1, 0.6);
    fill(
      vfxCrescent(
        ui.Offset(-r * 0.05, -r * 0.05),
        r * 0.46 * swell,
        r * 0.07,
        -pi * 0.72,
        1.3,
      ),
      const ui.Color(0xFFE08A9A),
      0.26,
    );
    canvas.restore();
  } else if (element == 'Mud') {
    // Sprawling, matte sludge. Bubbles swell and burst on a slow cycle.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r,
      const ui.Color(0xFF7A6448),
      0.08,
      squash: 0.6,
    );
    fill(
      vfxBlob(ui.Offset.zero, r * 0.9, seed, n: 11, wobble: 0.22, squash: 0.55),
      const ui.Color(0xFF231B14),
      0.94,
    );
    fill(
      vfxBlob(
        ui.Offset(r * 0.08, -r * 0.03),
        r * 0.58,
        seed + 5,
        n: 9,
        wobble: 0.25,
        squash: 0.52,
      ),
      const ui.Color(0xFF4A3B2B),
      0.42,
    );
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final ph = (time * 0.32 + i * 0.618 + seed) % 1.0;
      final a = i * 2.399 + seed;
      final c = ui.Offset(
        cos(a) * r * 0.5 * (0.4 + 0.6 * vfxHash(seed + i)),
        sin(a) * r * 0.26,
      );
      if (ph < 0.85) {
        final g = ph / 0.85;
        final br = r * (0.03 + 0.06 * g);
        canvas.drawCircle(
          c,
          br,
          paint
            ..style = ui.PaintingStyle.fill
            ..color = const ui.Color(0xFF5E4C39).withValues(alpha: 0.8),
        );
        canvas.drawCircle(
          c + ui.Offset(-br * 0.35, -br * 0.4),
          br * 0.3,
          paint..color = const ui.Color(0xFFA08A66).withValues(alpha: 0.45 * g),
        );
      } else {
        final pop = (ph - 0.85) / 0.15;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.scale(1, 0.55);
        fill(
          vfxCrescent(
            ui.Offset.zero,
            r * (0.09 + 0.08 * pop),
            r * 0.02,
            -pi / 2,
            pi * 1.6,
          ),
          const ui.Color(0xFF8B7965),
          0.35 * (1 - pop),
        );
        canvas.restore();
      }
    }
  } else if (element == 'Earth') {
    // A mineral spring ringed in stone, with light welling up out of it — the
    // one pool here that is on your side.
    final breathe = 0.85 + 0.15 * sin(time * 1.4 + seed) + flash * 0.2;
    fill(
      vfxBlob(ui.Offset.zero, r * 0.8, seed, n: 14, wobble: 0.06, squash: 0.58),
      const ui.Color(0xFF151C14),
      0.94,
    );
    _maskLightSpill(
      canvas,
      const ui.Offset(0, -2),
      r * 0.72,
      const ui.Color(0xFF9CC48A),
      0.34 * breathe,
      squash: 0.56,
    );
    _maskLightSpill(
      canvas,
      const ui.Offset(0, -2),
      r * 0.3,
      const ui.Color(0xFFE2EFC4),
      0.3 * breathe,
      squash: 0.56,
    );
    for (var i = 0; i < (reduced ? 7 : 12); i++) {
      final a = i * pi * 2 / (reduced ? 7 : 12) + seed;
      final c = ui.Offset(cos(a) * r * 0.8, sin(a) * r * 0.8 * 0.58);
      final sr = r * (0.075 + 0.04 * vfxHash(seed + i));
      fill(
        vfxBlob(c, sr, seed + i * 3, n: 6, wobble: 0.25, squash: 0.75),
        const ui.Color(0xFF3E4638),
        0.95,
      );
      fill(
        vfxBlob(
          c + ui.Offset(-sr * 0.2, -sr * 0.3),
          sr * 0.55,
          seed + i * 7,
          n: 5,
          wobble: 0.2,
          squash: 0.7,
        ),
        const ui.Color(0xFF8A9B73),
        0.35,
      );
    }
    // Motes of light welling up out of the spring: one batch of grains.
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final t = (time * 0.35 + i * 0.618) % 1;
      final x = sin(i * 4.3 + seed) * r * 0.45;
      vfxGrain(x, sin(i * 2.1) * r * 0.15 - t * r * 0.7);
    }
    vfxGrainsFlush(
      canvas,
      max(1.8, r * 0.032),
      const ui.Color(0xFFD6E6B8),
      0.5 + flash * 0.3,
    );
  } else if (element == 'Poison') {
    // A low miasma clinging to the ground: sickly clouds rolling over a dark
    // stain, spores lifting off them.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 1.1,
      const ui.Color(0xFF91A85C),
      0.13,
      squash: 0.62,
    );
    fill(
      vfxBlob(ui.Offset.zero, r * 0.7, seed, n: 12, wobble: 0.2, squash: 0.55),
      const ui.Color(0xFF12160A),
      0.55,
    );
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final a = i * 2.399 + seed + time * 0.05;
      final c = ui.Offset(cos(a) * r * 0.42, sin(a) * r * 0.2);
      final cr = r * (0.26 + 0.1 * sin(time * 0.6 + i));
      fill(
        vfxBlob(
          c,
          cr,
          seed + i * 2 + time * 0.2,
          n: 9,
          wobble: 0.14,
          squash: 0.6,
        ),
        const ui.Color(0xFF2E3A1C),
        0.42,
      );
      fill(
        vfxBlob(
          c + ui.Offset(0, -cr * 0.18),
          cr * 0.72,
          seed + i * 5 + time * 0.2,
          n: 9,
          wobble: 0.16,
          squash: 0.55,
        ),
        const ui.Color(0xFF6D7F42),
        0.2,
      );
    }
    // Spores lifting off the clouds: one batch of grains.
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final t = (time * 0.4 + i * 0.618) % 1;
      vfxGrain(
        sin(i * 5.3 + seed) * r * 0.55,
        cos(i * 3.1) * r * 0.2 - t * r * 0.45,
      );
    }
    vfxGrainsFlush(
      canvas,
      max(1.6, r * 0.024),
      const ui.Color(0xFFC8D890),
      0.5,
    );
  } else if (element == 'Dust') {
    // Not a ground trap: a pall of grit hanging round the creature it
    // guards, centre left clear so the creature shows through. The grit
    // drifts where it hangs (it does not circle the creature), and the
    // heavy stones resting in it are its remaining blocks — one falls away
    // with each shot it stops.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r,
      const ui.Color(0xFFAC916D),
      0.14 + flash * 0.1,
      squash: 0.8,
    );
    canvas.save();
    canvas.scale(1, 0.8);
    for (var i = 0; i < (reduced ? 6 : 14); i++) {
      final a = seed + i * 2.399963;
      // Hanging through the whole pall, thinning toward the clear middle.
      final d = r * (0.3 + 0.62 * vfxHash(seed + i * 2));
      final drift = vfxPolar(
        time * 0.4 + i * 1.7,
        r * 0.04 * (0.5 + vfxHash(seed + i * 5)),
      );
      final g = vfxPolar(a, d) + drift;
      vfxGrain(g.dx, g.dy);
    }
    vfxGrainsFlush(
      canvas,
      max(1.6, r * 0.026),
      const ui.Color(0xFFD6C29E),
      0.55 + flash * 0.2,
    );
    final stones = p.interceptCharges.clamp(0, 6);
    for (var i = 0; i < stones; i++) {
      final a = seed + 0.8 + i * pi * 2 / max(1, stones);
      final c =
          vfxPolar(a, r * 0.8) +
          ui.Offset(0, sin(time * 1.3 + i * 1.9) * r * 0.03);
      final sr = r * 0.07;
      fill(
        vfxBlob(c, sr, seed + i, n: 6, wobble: 0.28),
        const ui.Color(0xFF3A3024),
        0.95,
      );
      fill(
        vfxBlob(
          c + ui.Offset(-sr * 0.25, -sr * 0.3),
          sr * 0.5,
          seed + i * 3,
          n: 5,
          wobble: 0.2,
        ),
        const ui.Color(0xFFB5A286),
        0.45,
      );
    }
    canvas.restore();
  } else if (element == 'Steam') {
    final steam = element == 'Steam';
    final dust = element == 'Dust';
    final tint = steam
        ? 0xFF788383
        : dust
        ? 0xFF8C7960
        : 0xFF6D7657;
    final shadow = steam
        ? 0xFF262D2C
        : dust
        ? 0xFF332C24
        : 0xFF262B21;
    if (steam) {
      fill(patch(0, r * 0.14, r * 0.35, 0.5, seed), 0xFF363C39, 0.9);
      // The vent's mouth: a dark hole with its far lip catching the light
      // (it was a pale chevron drawn across the stone, which read as a mark
      // laid on top rather than an opening).
      fill(patch(-r * 0.02, r * 0.08, r * 0.13, 0.45, seed + 1), 0xFF141817, 0.9);
      fill(
        vfxEllipseCrescent(
          ui.Offset(-r * 0.02, r * 0.08),
          r * 0.14,
          r * 0.065,
          max(1.4, r * 0.03),
          -pi / 2,
          2.4,
        ),
        0xFFBBC4B9,
        0.42,
      );
    }
    // Low fumes creep sideways; geyser vapor climbs from a small stone vent.
    // The curls over the puffs share one path and thin out with their puff.
    final curls = !dust && !reduced ? ui.Path() : null;
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final t = (time * (steam ? 0.23 : 0.1) + i * 0.618) % 1;
      final x = steam
          ? sin(i * 4.1 + t * 2) * r * t * 0.24
          : sin(i * 4.1 + time * 0.08) * r * 0.55;
      final y = steam ? -r * t * 0.82 : cos(i * 2.7) * r * 0.25 - t * r * 0.15;
      final size = r * (steam ? 0.12 + t * 0.22 : 0.24 + t * 0.11);
      fill(
        patch(x, y, size, steam ? 0.8 : 0.6, i + time * 0.3),
        shadow,
        sin(t * pi) * 0.3,
      );
      fill(
        patch(x, y - size * 0.10, size * 0.85, 0.6, i + time * 0.3),
        tint,
        sin(t * pi) * (steam ? 0.13 : 0.10),
      );
      if (curls != null) {
        vfxLensRibbon(
          vfxQuadSpine(
            ui.Offset(x - size * 0.5, y),
            ui.Offset(x, y - size * 0.65),
            ui.Offset(x + size * 0.6, y - size * 0.2),
            n: 6,
            into: spine..clear(),
          ),
          max(1.2, r * 0.026) * sin(t * pi),
          into: curls,
        );
      }
    }
    if (curls != null) fill(curls, tint, 0.24);
  } else if (element == 'Air') {
    // A pressure pocket: a pressed-down hollow with the light sliding over
    // its lip, and ash being drawn down into it. One crescent path and one
    // grain batch (it was three spinning pinwheel arms, doubled, and six
    // orbiting leaves: ~13 fills a trap, up to 21 traps).
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 0.7,
      const ui.Color(0xFF05080B),
      0.4,
      squash: 0.62,
    );
    final lip = ui.Path();
    final turn = time * 0.6 + seed;
    for (var i = 0; i < 2; i++) {
      // Deep, soft swells of light on the lip: a field of twenty of these
      // must read as hollows, not as a scatter of thin arcs.
      vfxEllipseCrescent(
        ui.Offset.zero,
        r * 0.8,
        r * 0.5,
        max(2.4, r * 0.17),
        turn + i * pi,
        1.35,
        into: lip,
      );
    }
    fill(lip, const ui.Color(0xFFC8D4D6), 0.2 + flash * 0.3);
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final ph = (time * 0.5 + i * 0.618 + seed) % 1;
      final a = seed + i * 2.399963 + ph * 1.2;
      final g = vfxPolar(a, r * 0.85 * (1 - ph));
      vfxGrain(g.dx, g.dy * 0.62);
    }
    vfxGrainsFlush(
      canvas,
      max(1.6, r * 0.05),
      const ui.Color(0xFFB8C2BE),
      0.6,
    );
  } else if (element == 'Lightning') {
    fill(patch(0, 0, r * 0.8, 0.65, seed), 0xFF25272A, 0.32);
    // Discharges crawling across a charged patch of ground, rim to rim at
    // their own bearings — never spokes out of the middle. Each arc's bends
    // glide from pose to pose; a discharge swells the shared glow. Two
    // fills for every arc.
    final glow = ui.Path();
    final core = ui.Path();
    var discharge = 0.0;
    for (var i = 0; i < (reduced ? 2 : 3); i++) {
      final a0 = seed + i * 2.2 + (vfxGlide(i * 3.7 + seed, time, 1.1) - 0.5);
      final a1 = a0 + pi * (0.55 + 0.35 * vfxGlide(i * 5.1, time, 1.4));
      vfxArcInto(
        glow,
        core,
        ui.Offset(cos(a0) * r * 0.8, sin(a0) * r * 0.5),
        ui.Offset(cos(a1) * r * 0.75, sin(a1) * r * 0.48),
        seed + i * 9.0,
        time,
        width: max(1.4, r * 0.03),
        amp: 0.22,
      );
      discharge = max(
        discharge,
        pow(max(0.0, sin(time * 8 + i * 2)), 5).toDouble(),
      );
    }
    fill(glow, 0xFFB2B9E3, 0.14 + 0.2 * discharge);
    fill(core, 0xFFE2E4DC, 0.55 + 0.35 * discharge);
  } else if (element == 'Ice') {
    // An opaque frost-worn monolith; no gem outline or glowing cyan badge.
    final stone = ui.Path()
      ..moveTo(-r * 0.23, r * 0.3)
      ..lineTo(-r * 0.26, -r * 0.38)
      ..lineTo(-r * 0.10, -r * 0.8)
      ..lineTo(r * 0.16, -r * 0.7)
      ..lineTo(r * 0.25, -r * 0.1)
      ..lineTo(r * 0.18, r * 0.32)
      ..close();
    fill(stone, 0xFF394B50, 0.94);
    final face = ui.Path()
      ..moveTo(-r * 0.10, -r * 0.8)
      ..lineTo(r * 0.02, -r * 0.05)
      ..lineTo(r * 0.18, r * 0.32)
      ..lineTo(r * 0.25, -r * 0.1)
      ..lineTo(r * 0.16, -r * 0.7)
      ..close();
    fill(face, 0xFF73827F, 0.5);
    // Frost creeping off the foot: tapered slivers, one path.
    final frost = ui.Path();
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final x = sin(i * 4.1) * r * 0.5;
      vfxLensRibbon(
        vfxPolylineSpine([
          ui.Offset(x, r * 0.24),
          ui.Offset(x * 1.3, r * 0.42),
          ui.Offset(x * 1.1 + r * 0.08, r * 0.46),
        ], into: spine..clear()),
        max(1.4, r * 0.026),
        into: frost,
      );
    }
    fill(frost, 0xFFB0C0B9, 0.3);
  } else if (element == 'Plant') {
    // Rootstock only: the shared, gameplay-driven tendrils render above it.
    // Roots split from a buried stump and run out into the stone at uneven
    // lengths, forking once — a root system, not a creature.
    fill(
      vfxBlob(ui.Offset.zero, r * 0.6, seed, n: 12, wobble: 0.2, squash: 0.55),
      const ui.Color(0xFF1A2317),
      0.8,
    );
    // A few roots at uneven bearings and lengths, bent and thick at the
    // stump, forking once — never an even wheel of tapering hairlines (it
    // was nine of those: a star). Two fills for the lot.
    final dark = ui.Path(), lit = ui.Path();
    final roots = reduced ? 3 : 5;
    for (var i = 0; i < roots; i++) {
      final a = seed + i * 2.399963 + (vfxHash(seed + i) - 0.5) * 0.6;
      final len = r * (0.38 + 0.42 * vfxHash(seed + i * 3.3));
      final bend = (vfxHash(seed + i * 5.1) - 0.5) * 1.6;
      ui.Offset at(double t, double off) => ui.Offset(
        cos(a + bend * t + off) * len * t,
        sin(a + bend * t + off) * len * t * 0.56,
      );
      final spine = [for (var k = 0; k <= 6; k++) at(k / 6, 0)];
      dark.addPath(vfxRibbon(spine, r * 0.12, r * 0.03), ui.Offset.zero);
      lit.addPath(vfxRibbon(spine, r * 0.045, r * 0.012), ui.Offset.zero);
      if (i.isEven && !reduced) {
        final fork = [
          for (var k = 0; k <= 4; k++)
            at(0.5 + 0.35 * k / 4, 0.45 * k / 4 * (i % 4 == 0 ? 1 : -1)),
        ];
        dark.addPath(vfxRibbon(fork, r * 0.055, r * 0.016), ui.Offset.zero);
      }
    }
    fill(dark, const ui.Color(0xFF34402A), 0.95);
    fill(lit, const ui.Color(0xFF9DAE7E), 0.4 + flash * 0.25);
    fill(
      vfxBlob(
        ui.Offset.zero,
        r * 0.15,
        seed + 3,
        n: 9,
        wobble: 0.3,
        squash: 0.62,
      ),
      const ui.Color(0xFF26301F),
      0.98,
    );
  } else if (element == 'Spirit') {
    drawMaskSpiritRemnant(
      canvas: canvas,
      position: ui.Offset.zero,
      radius: r,
      time: time + seed,
      reduced: reduced,
    );
  }
}

/// Contact accents never apply damage, change a hitbox, or keep a trap alive.
void drawMaskTrapContact({
  required ui.Canvas canvas,
  required ui.Offset position,
  required double radius,
  required String element,
  required double progress,
  bool reduced = false,
}) {
  if (!_contactElements.contains(element) || progress < 0 || progress >= 1) {
    return;
  }
  final t = progress;
  final fade = 1 - t;
  final r = radius;
  final color = switch (element) {
    'Crystal' => const ui.Color(0xFF577767),
    'Light' => const ui.Color(0xFFBDB6A1),
    'Water' => const ui.Color(0xFF566F7A),
    'Fire' => const ui.Color(0xFFB77D4D),
    'Blood' => const ui.Color(0xFF8C4456),
    'Lightning' => const ui.Color(0xFFA6A8B0),
    'Air' => const ui.Color(0xFF8B9A93),
    _ => const ui.Color(0xFF716078),
  };
  final bright = ui.Color.lerp(color, const ui.Color(0xFFE0DFD4), 0.42)!;
  final paint = _maskPaint
    ..shader = null
    ..style = ui.PaintingStyle.fill;
  // Every accent is a filled lens ribbon; an element's accents share one
  // path, so a contact echo is a single fill.
  void fillAll(ui.Path path, double alpha) =>
      canvas.drawPath(path, paint..color = bright.withValues(alpha: alpha));
  canvas.save();
  canvas.translate(position.dx, position.dy);
  if (element == 'Light') {
    // The incision closing: one lit sliver, narrowing as it seals.
    fillAll(
      vfxLensRibbon(
        vfxPolylineSpine([
          ui.Offset(-r * 0.03, -r * (1 - t)),
          ui.Offset(r * 0.035, -r * 0.25 * (1 - t)),
          ui.Offset(-r * 0.025, r * 0.10 * (1 - t)),
          ui.Offset(0, r * 0.75 * (1 - t)),
        ]),
        max(1.6, r * 0.045 * (1 - t)),
        taper: 0.45,
      ),
      fade * 0.8,
    );
  } else if (element == 'Crystal') {
    // The split: crystal dust bursting off the struck body as grains that
    // ease out to their own distances (no ring of shards flying on spokes)
    // and settle, a few splinters tumbling down among them.
    final e = 1 - (1 - t) * (1 - t);
    for (var i = 0; i < (reduced ? 6 : 14); i++) {
      final a = i * 2.399963 + 0.4;
      final d = r * (0.2 + 0.8 * vfxHash(i * 3.1 + 0.7)) * e;
      vfxGrain(cos(a) * d, sin(a) * d * 0.6 + t * t * r * 0.12);
    }
    vfxGrainsFlush(
      canvas,
      max(1.8, r * 0.03),
      ui.Color.lerp(bright, const ui.Color(0xFFFFFFFF), 0.35 * fade)!,
      fade * 0.85,
    );
    final splinters = ui.Path();
    for (var i = 0; i < (reduced ? 2 : 4); i++) {
      final a = i * 1.9 + 1.1;
      final d = r * (0.3 + 0.35 * vfxHash(i * 5.3)) * e;
      splinters.addPath(
        vfxShard(
          ui.Offset(cos(a) * d, sin(a) * d * 0.6 + t * t * r * 0.3),
          r * 0.1,
          r * 0.03,
          a + t * 4,
        ),
        ui.Offset.zero,
      );
    }
    fillAll(splinters, fade * 0.75);
  } else if (element == 'Water') {
    final spread = r * (0.28 + t * 0.85);
    // Torn surface fronts and low sprays, never a dotted ornamental crown.
    final sprays = ui.Path();
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 4 : 9); i++) {
      final angle = i * 2.399;
      final distance = spread * (0.76 + 0.21 * sin(i * 4.7));
      final base = ui.Offset(
        cos(angle) * distance,
        sin(angle) * distance * 0.5,
      );
      final tip =
          base +
          ui.Offset(
            cos(angle) * r * 0.13,
            -sin(t * pi) * r * (0.10 + 0.12 * sin(i * 3.1)),
          );
      vfxLensRibbon(
        vfxQuadSpine(
          ui.Offset(base.dx - r * 0.09, base.dy),
          ui.Offset(base.dx, base.dy - r * 0.07),
          tip,
          n: 6,
          into: spine..clear(),
        ),
        max(1.4, r * 0.028 * (1 - t)),
        taper: 0.3,
        taperEnd: 0.7,
        into: sprays,
      );
    }
    fillAll(sprays, fade * 0.7);
  } else if (element != 'Dark') {
    final accents = ui.Path();
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final a = i * 2.399;
      final d = r * (0.18 + t * 0.75);
      final x = cos(a) * d;
      final y = sin(a) * d * 0.55;
      spine.clear();
      if (element == 'Lightning') {
        vfxPolylineSpine([
          ui.Offset(x, y),
          ui.Offset(x + r * 0.06, y - r * 0.09),
          ui.Offset(x + r * 0.02, y - r * 0.12),
        ], into: spine);
      } else if (element == 'Fire') {
        vfxPolylineSpine([
          ui.Offset(x, y),
          ui.Offset(x + r * 0.015, y - r * 0.1 * (1 - t)),
        ], perSegment: 4, into: spine);
      } else {
        vfxQuadSpine(
          ui.Offset(x, y),
          ui.Offset(x + r * 0.06, y - r * 0.05),
          ui.Offset(x + r * 0.12, y),
          n: 6,
          into: spine,
        );
      }
      vfxLensRibbon(spine, max(1.4, r * 0.026), into: accents);
    }
    fillAll(accents, fade * 0.6);
  } else {
    // The first quarter pulls in; the remaining time throws streaks outward.
    final extent = t < 0.25 ? 0.8 - t * 2.4 : 0.2 + (t - 0.25) * 1.4;
    final streaks = ui.Path();
    final spine = <ui.Offset>[];
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final angle = i * 2.399 + 0.3;
      final dir = ui.Offset(cos(angle), sin(angle));
      vfxLensRibbon(
        vfxPolylineSpine([
          dir * r * extent,
          dir * r * (extent + 0.09 + 0.08 * sin(i * 4.3)),
        ], perSegment: 4, into: spine..clear()),
        max(1.8, r * 0.04),
        into: streaks,
      );
    }
    fillAll(streaks, fade * 0.8);
  }
  canvas.restore();
}

/// Shared by authored fixtures and Survival's collectible spirit remnants.
void drawMaskSpiritRemnant({
  required ui.Canvas canvas,
  required ui.Offset position,
  required double radius,
  required double time,
  double alpha = 1,
  bool reduced = false,
}) {
  // A soul-flame hovering over its own cold light. The ship has to go and
  // collect these, so unlike the traps it is meant to be spotted from across
  // the field — but it is still a small flame, not a beacon.
  final r = radius;
  final paint = _maskPaint
    ..shader = null
    ..style = ui.PaintingStyle.fill;
  canvas.save();
  canvas.translate(position.dx, position.dy);
  _maskLightSpill(
    canvas,
    ui.Offset.zero,
    r * 0.8,
    const ui.Color(0xFFA8B8D8),
    0.22 * alpha,
    squash: 0.6,
  );
  final bob = sin(time * 1.6) * r * 0.05;
  final flicker = 0.9 + 0.1 * sin(time * 7.3);
  final c = ui.Offset(sin(time * 1.1) * r * 0.03, -r * 0.3 + bob);
  // Tail streams upward; head sits low and round.
  final lean = pi / 2 + sin(time * 2.3) * 0.12;
  canvas.drawPath(
    vfxDrop(c, r * 0.24 * flicker, lean),
    paint..color = const ui.Color(0xFF6A7C98).withValues(alpha: 0.42 * alpha),
  );
  canvas.drawPath(
    vfxDrop(c + ui.Offset(0, r * 0.03), r * 0.14 * flicker, lean),
    paint..color = const ui.Color(0xFFDCE6F4).withValues(alpha: 0.72 * alpha),
  );
  if (!reduced) {
    // Two grains of it lifting off the flame and fading as they rise (they
    // used to circle it), and no white pip at its heart.
    for (var i = 0; i < 2; i++) {
      final ph = (time * 0.45 + i * 0.5) % 1.0;
      vfxGrain(
        c.dx + sin(time * 1.3 + i * 2.4) * r * 0.12,
        c.dy - r * 0.2 - ph * r * 0.55,
      );
    }
    vfxGrainsFlush(
      canvas,
      max(1.6, r * 0.04),
      const ui.Color(0xFFDCE6F4),
      0.55 * alpha,
    );
  }
  canvas.restore();
}

// ─────────────────────────────────────────────────────────────────────────────
//  The moments round the traps: a vine fed, a marked body bleeding for the
//  party, Spirit wisps waiting to be collected and the clear they set off.
//  Survival's look, drawn once for every mode. Particle emitters route into
//  the caller's pool through [emit]; [poolSize] is read before each particle
//  so a full pool stops the burst, as Survival's does.
// ─────────────────────────────────────────────────────────────────────────────

/// The burst a Plant vine throws as it is fed: brighter and bigger, with an
/// upward sprout jet, when the feed grows a new tendril.
void emitMaskPlantFeedBurst({
  required ui.Offset at,
  required bool newTendril,
  required Random rng,
  required int Function() poolSize,
  required ZoneVfxEmit emit,
}) {
  if (poolSize() >= 145) return;
  final plant = elementColor('Plant');
  final bright = ui.Color.lerp(plant, const ui.Color(0xFFFFFFFF), 0.55)!;
  final count = newTendril ? 18 : 9;
  for (var i = 0; i < count; i++) {
    if (poolSize() >= 150) break;
    final a = rng.nextDouble() * 2 * pi;
    final spd = 90 + rng.nextDouble() * 140;
    emit(
      at.dx,
      at.dy,
      cos(a) * spd,
      sin(a) * spd,
      (newTendril ? 1.8 : 1.4) + rng.nextDouble() * 1.4,
      0.45 + rng.nextDouble() * 0.35,
      i.isEven ? bright : plant,
    );
  }
  if (newTendril) {
    // Extra upward "sprout" jet so the unlock reads.
    for (var i = 0; i < 8; i++) {
      if (poolSize() >= 150) break;
      final a = -pi / 2 + (rng.nextDouble() - 0.5) * 0.9;
      final spd = 130 + rng.nextDouble() * 150;
      emit(
        at.dx,
        at.dy,
        cos(a) * spd,
        sin(a) * spd,
        1.6 + rng.nextDouble() * 1.4,
        0.55 + rng.nextDouble() * 0.35,
        i.isEven ? bright : plant,
      );
    }
  }
}

/// One drop of blood running from a Blood-marked body at [from] toward the
/// ally it is feeding at [toward]. Survival spawns about six a second.
void emitMaskBloodDrainWisp({
  required ui.Offset from,
  required ui.Offset toward,
  required Random rng,
  required ZoneVfxEmit emit,
}) {
  final delta = toward - from;
  final dist = delta.distance;
  final dir = dist > 0.01
      ? delta / dist
      : ui.Offset(
          cos(rng.nextDouble() * 2 * pi),
          sin(rng.nextDouble() * 2 * pi),
        );
  // Spawn slightly off-center so the wisps trickle out of the enemy body
  // rather than a single point.
  final jitterA = rng.nextDouble() * 2 * pi;
  final jitterR = rng.nextDouble() * 6.0;
  final spawn = from + ui.Offset(cos(jitterA), sin(jitterA)) * jitterR;
  final spd = 70 + rng.nextDouble() * 50;
  const blood = ui.Color(0xFFC8254A);
  const deep = ui.Color(0xFF5A0D1F);
  emit(
    spawn.dx,
    spawn.dy,
    dir.dx * spd,
    dir.dy * spd,
    1.2 + rng.nextDouble() * 1.4,
    0.50 + rng.nextDouble() * 0.30,
    rng.nextBool() ? blood : deep,
  );
}

/// The spirit motes a Spirit clear sprays outward from [origin].
void emitMaskSpiritNukeMotes({
  required ui.Offset origin,
  required Random rng,
  required int Function() poolSize,
  required ZoneVfxEmit emit,
}) {
  final spirit = elementColor('Spirit');
  final bright = ui.Color.lerp(spirit, const ui.Color(0xFFFFFFFF), 0.55)!;
  const count = 32;
  for (var i = 0; i < count; i++) {
    if (poolSize() >= 150) break;
    // Random headings and a spread of speeds: a bloom, not 32 spokes.
    final a = rng.nextDouble() * pi * 2;
    final spd = 120 + rng.nextDouble() * 320;
    emit(
      origin.dx,
      origin.dy,
      cos(a) * spd,
      sin(a) * spd,
      1.6 + rng.nextDouble() * 1.6,
      0.6 + rng.nextDouble() * 0.4,
      i.isEven ? bright : spirit,
    );
  }
}

/// A Spirit wisp waiting to be collected: the soul-flame remnant, bobbing,
/// fading as its time runs out and flickering through its last three
/// seconds.
void drawMaskSpiritWisp({
  required ui.Canvas canvas,
  required ui.Offset position,
  required double life,
  required double bobPhase,
  required double time,
  bool reduced = false,
}) {
  final bob = sin(time * 3.1 + bobPhase) * 1.8;
  final pos = ui.Offset(position.dx, position.dy + bob);
  final fade = (life / 12.0).clamp(0.0, 1.0);
  final lifePulse = life < 3.0 ? 0.7 + 0.3 * sin(time * 8) : 1.0;
  drawMaskSpiritRemnant(
    canvas: canvas,
    position: pos,
    radius: 32,
    time: time + bobPhase,
    alpha: fade * lifePulse,
    reduced: reduced,
  );
}

/// Spirit's cold light, tinted 30% toward the element colour as the glowing
/// elements are, so the clear reads as Spirit rather than as a pale flash.
final ui.Color _spiritClearLight = ui.Color.lerp(
  vfxMaterial('Spirit').light,
  elementColor('Spirit'),
  0.3,
)!;

/// A Spirit clear's punctuation, local to where it went off: a soft glow on
/// [origin] that dies quickly and a wide, faint band of Spirit light easing
/// out to [reach] (the field the clear swept) as [flash] runs 1 → 0. No
/// white disc and no screen wash. [viewport] culls the band once it has
/// passed the screen.
void drawMaskSpiritNukeFlash({
  required ui.Canvas canvas,
  required ui.Offset origin,
  required double flash,
  required ui.Rect viewport,
  double reach = 1140,
}) {
  if (flash <= 0.01) return;
  final f = flash.clamp(0.0, 1.0);
  final grow = 1 - f * f; // eased out: quick at first, then settling
  _maskLightSpill(
    canvas,
    origin,
    120 + 160 * grow,
    _spiritClearLight,
    0.32 * f * f,
  );
  final ringR = 70 + (reach - 70) * grow;
  final band = 50 + 150 * grow;
  // Skip the band when it is wholly off screen, or has swept past every
  // corner of it.
  var farthest = 0.0;
  for (final corner in [
    viewport.topLeft,
    viewport.topRight,
    viewport.bottomLeft,
    viewport.bottomRight,
  ]) {
    farthest = max(farthest, (corner - origin).distance);
  }
  if (farthest > ringR - band &&
      viewport.overlaps(
        ui.Rect.fromCircle(center: origin, radius: ringR + band),
      )) {
    vfxSoftRing(canvas, origin, ringR, band, _spiritClearLight, 0.2 * f);
  }
}
