import 'dart:math';
import 'dart:ui' as ui;
import 'cosmic_data.dart';
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
double _radius(Projectile p) =>
    max(20.0, max(p.snareRadius, p.effectRadius)).clamp(20.0, 260.0);

/// Visual-only contact echoes, independent of a trap's remaining gameplay life.
/// One echo per fixture at a time prevents per-frame collision flash storms.
class MaskTrapVisuals {
  final List<_MaskContact> _contacts = [];
  int get activeCount => _contacts.length;
  void contact(Projectile p) {
    if (!_isTrap(p) ||
        !_contactElements.contains(p.element) ||
        _contacts.any((fx) => identical(fx.source, p))) {
      return;
    }
    if (_contacts.length >= 24) _contacts.removeAt(0);
    _contacts.add(_MaskContact(p, p.position, _radius(p), p.element!));
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

/// Radial light spill stays soft without a blur filter or offscreen layer.
void _maskLightSpill(
  ui.Canvas canvas,
  ui.Offset centre,
  double radius,
  ui.Color color,
  double strength, {
  double squash = 1,
}) {
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.scale(1, squash);
  canvas.drawCircle(
    ui.Offset.zero,
    radius,
    ui.Paint()
      ..shader = ui.Gradient.radial(
        ui.Offset.zero,
        radius,
        [
          color.withValues(alpha: strength),
          color.withValues(alpha: strength * 0.4),
          color.withValues(alpha: 0),
        ],
        const [0.0, 0.45, 1.0],
      ),
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
  final paint = ui.Paint();
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
      ..color = ink.withValues(alpha: alpha),
  );
  void stroke(ui.Path path, ui.Color ink, double alpha, double width) =>
      canvas.drawPath(
        path,
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = ui.StrokeCap.round
          ..color = ink.withValues(alpha: alpha),
      );
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
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 1.1,
      tint,
      (element == 'Light' || element == 'Lightning' ? 0.22 : 0.15) +
          flash * 0.10,
      squash: element == 'Light' ? 1.0 : 0.7,
    );
  }
  // Stable irregularity belongs to the fixture; only light and fluid move.
  final seed = position.dx * 0.013 + position.dy * 0.017;
  if (element == 'Crystal') {
    // Broken smoky mineral, not a symmetrical jewel icon. Faces overlap and
    // only interrupted internal fractures catch the cold alchemical light.
    for (var i = 0; i < (reduced ? 4 : 6); i++) {
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
      fill(shard, const ui.Color(0xFF192B2A), 0.95);
      final face = ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(edge.dx, edge.dy)
        ..lineTo(base.dx + width * 0.7, base.dy + r * 0.08)
        ..lineTo(base.dx - width * 0.3, base.dy - height * 0.32)
        ..close();
      fill(face, const ui.Color(0xFF405851), 0.6);
      final fracture = ui.Path()
        ..moveTo(tip.dx - width * 0.2, tip.dy + height * 0.23)
        ..lineTo(base.dx - width * 0.25, base.dy - height * 0.4)
        ..lineTo(base.dx + width * 0.25, base.dy - height * 0.31);
      stroke(fracture, const ui.Color(0xFF789B86), 0.13, max(2, r * 0.065));
      stroke(
        fracture,
        const ui.Color(0xFFA6C7AD),
        0.50 + 0.12 * sin(time * 1.1 + i),
        max(0.7, r * 0.01),
      );
    }
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
    for (var i = 0; i < (reduced ? 4 : 9); i++) {
      final t = (time * 0.14 + i * 0.618) % 1;
      final side = i.isEven ? 1.0 : -1.0;
      final x = side * r * (0.08 + 0.45 * (1 - t));
      final y = r * sin(i * 7.7 + seed) * 0.6;
      canvas.drawCircle(
        ui.Offset(x, y),
        max(0.9, r * 0.014),
        paint
          ..style = ui.PaintingStyle.fill
          ..color = const ui.Color(
            0xFFD8D2BC,
          ).withValues(alpha: sin(t * pi) * 0.45),
      );
    }
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
    stroke(pool, const ui.Color(0xFF40545A), 0.06, r * 0.1);
    fill(pool, const ui.Color(0xFF030A10), 0.96);
    for (var i = 0; i < (reduced ? 3 : 7); i++) {
      final y = sin(i * 5.7 + seed) * r * 0.32;
      final x = sin(i * 3.1 + 1) * r * 0.3;
      final span = r * (0.18 + 0.09 * sin(i + time * 0.7));
      final reflection = ui.Path()
        ..moveTo(x - span, y)
        ..quadraticBezierTo(
          x,
          y + r * 0.025 * sin(time + i),
          x + span,
          y - r * 0.016,
        );
      stroke(
        reflection,
        const ui.Color(0xFF8A9EA0),
        0.23 + 0.08 * sin(time * 0.6 + i),
        max(0.8, r * 0.009),
      );
    }
    for (var i = 0; i < 3; i++) {
      canvas.drawArc(
        ui.Rect.fromCenter(
          center: ui.Offset.zero,
          width: r * 1.62,
          height: r * 0.87,
        ),
        i * 2.4 + 0.2,
        0.38,
        false,
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = max(0.8, r * 0.01)
          ..color = const ui.Color(0xFF73868B).withValues(alpha: 0.40),
      );
    }
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
    for (var arm = 0; arm < (reduced ? 3 : 6); arm++) {
      final phase = (time * 0.18 + arm * 0.618) % 1;
      final path = ui.Path();
      for (var i = 0; i <= 12; i++) {
        final t = i / 12;
        final a = arm * 2.399 + phase * 0.7 + t * 0.42;
        final rad = r * (0.95 - phase * 0.55 - t * 0.17);
        final p = ui.Offset(cos(a), sin(a)) * rad;
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      stroke(
        path,
        const ui.Color(0xFF786386),
        sin(phase * pi) * 0.045,
        r * 0.07,
      );
      stroke(
        path,
        const ui.Color(0xFF786386),
        sin(phase * pi) * 0.48,
        max(0.8, r * 0.011),
      );
    }
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
  final paint = ui.Paint()..strokeCap = ui.StrokeCap.round;
  void fill(ui.Path shape, Object color, double a) => canvas.drawPath(
    shape,
    paint
      ..style = ui.PaintingStyle.fill
      ..color = (color is ui.Color ? color : ui.Color(color as int)).withValues(
        alpha: a.clamp(0.0, 1.0),
      ),
  );
  void line(ui.Path shape, int color, double a, double width) =>
      canvas.drawPath(
        shape,
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = max(0.8, width)
          ..color = ui.Color(color).withValues(alpha: a.clamp(0.0, 1.0)),
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

  void fleck(double x, double y, double size, int color, double alpha) {
    canvas.drawLine(
      ui.Offset(x, y),
      ui.Offset(x + size * 0.45, y - size),
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = max(0.8, size * 0.32)
        ..color = ui.Color(color).withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
  }

  final flash = p.abilityGrowthTimer.clamp(0.0, 1.0);
  if (element == 'Lava' || element == 'Fire') {
    final pool = element == 'Lava' || p.tickEffect == AbilityEffectKind.burn;
    final spread = pool ? r : r * 0.42;
    final fire = element == 'Fire';
    final warmth = 0.8 + 0.12 * sin(time * 2.1 + seed);
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      spread * 1.55,
      ui.Color(fire ? 0xFFFF782E : 0xFFFF501D),
      0.48 * warmth,
      squash: pool ? 0.7 : 1,
    );
    fill(patch(0, 0, spread, pool ? 0.63 : 0.8, seed), 0xFF271B19, 0.95);
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      spread * 0.95,
      ui.Color(fire ? 0xFFFF9A3E : 0xFFE96324),
      0.20 * warmth,
      squash: pool ? 0.6 : 0.8,
    );
    // Cracked cinder hides most of the heat; ember seams pulse beneath it.
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final a = i * 2.399 + seed;
      final x = cos(a) * spread * 0.65;
      final y = sin(a) * spread * (pool ? 0.35 : 0.5);
      final heat = 0.72 + 0.20 * sin(time * 1.6 + i) + flash * 0.12;
      if (element == 'Lava') {
        final crack = ui.Path()
          ..moveTo(x - spread * 0.16, y)
          ..lineTo(x - spread * 0.04, y + spread * 0.09 * sin(i * 4.3))
          ..lineTo(x + spread * 0.03, y - spread * 0.07)
          ..lineTo(x + spread * 0.18, y + spread * 0.1 * cos(i * 2.7));
        if (!reduced) line(crack, 0xFFFF571C, heat * 0.13, spread * 0.20);
        line(crack, 0xFFFF7827, heat * 0.35, spread * 0.09);
        line(crack, 0xFFFFBA56, heat, spread * 0.025);
        line(crack, 0xFFFFE0A0, heat * 0.8, spread * 0.009);
      } else {
        fill(patch(x, y, spread * 0.12, 0.55, i.toDouble()), 0xFF5C4436, 0.35);
        final ember = ui.Path()
          ..moveTo(x - spread * 0.05, y)
          ..quadraticBezierTo(
            x + spread * 0.07,
            y - spread * 0.10,
            x + spread * 0.02,
            y - spread * 0.36 * heat,
          );
        if (!reduced) line(ember, 0xFFFF581C, heat * 0.15, spread * 0.22);
        line(ember, 0xFFFF8D32, heat * 0.38, spread * 0.10);
        line(ember, 0xFFFFC66A, heat * 0.9, spread * 0.034);
        line(ember, 0xFFFFE6AC, heat, spread * 0.012);
      }
    }
    if (element == 'Fire') {
      for (var i = 0; i < (reduced ? 3 : 6); i++) {
        final t = (time * 0.38 + i * 0.618) % 1;
        fleck(
          sin(i * 7.7) * spread * 0.6,
          -spread * 0.15 - t * spread,
          r * 0.025,
          0xFFFFD18A,
          sin(t * pi) * 0.9,
        );
      }
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
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final t = (time * 0.35 + i * 0.618) % 1;
      final x = sin(i * 4.3 + seed) * r * 0.45;
      canvas.drawCircle(
        ui.Offset(x, sin(i * 2.1) * r * 0.15 - t * r * 0.7),
        max(1.0, r * 0.018) * (1 - t * 0.5),
        paint
          ..style = ui.PaintingStyle.fill
          ..color = const ui.Color(
            0xFFD6E6B8,
          ).withValues(alpha: sin(t * pi) * (0.55 + flash * 0.3)),
      );
    }
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
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final t = (time * 0.4 + i * 0.618) % 1;
      canvas.drawCircle(
        ui.Offset(
          sin(i * 5.3 + seed) * r * 0.55,
          cos(i * 3.1) * r * 0.2 - t * r * 0.45,
        ),
        max(0.9, r * 0.012),
        paint
          ..style = ui.PaintingStyle.fill
          ..color = const ui.Color(
            0xFFC8D890,
          ).withValues(alpha: sin(t * pi) * 0.6),
      );
    }
  } else if (element == 'Dust') {
    // Not a ground trap: a shield of grit orbiting the creature it guards,
    // centre left clear so the creature shows through. The heavy stones are
    // its remaining blocks — one falls away with each shot it stops.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r,
      const ui.Color(0xFFAC916D),
      0.07,
      squash: 0.8,
    );
    final spin = time * 1.1 + seed;
    canvas.save();
    canvas.scale(1, 0.8);
    for (var i = 0; i < 3; i++) {
      fill(
        vfxCrescent(
          ui.Offset.zero,
          r * (0.78 + 0.08 * i),
          r * (0.12 - 0.025 * i),
          spin * (1 + i * 0.3) + i * 2.1,
          2.2 - i * 0.4,
        ),
        const ui.Color(0xFF8C7960),
        0.18 + flash * 0.12,
      );
    }
    for (var i = 0; i < (reduced ? 6 : 14); i++) {
      final a = spin * (1.4 + vfxHash(seed + i) * 0.8) + i * 0.449;
      final d = r * (0.66 + 0.24 * vfxHash(seed + i * 2));
      canvas.drawCircle(
        vfxPolar(a, d),
        max(0.8, r * 0.012),
        paint
          ..style = ui.PaintingStyle.fill
          ..color = const ui.Color(0xFFD6C29E).withValues(alpha: 0.5),
      );
    }
    final stones = p.interceptCharges.clamp(0, 6);
    for (var i = 0; i < stones; i++) {
      final a = spin * 0.8 + i * pi * 2 / max(1, stones);
      final c = vfxPolar(a, r * 0.8);
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
      final vent = ui.Path()
        ..moveTo(-r * 0.18, r * 0.11)
        ..lineTo(-r * 0.04, 0)
        ..lineTo(r * 0.10, r * 0.07);
      line(vent, 0xFFBBC4B9, 0.38, r * 0.015);
    }
    // Low fumes creep sideways; geyser vapor climbs from a small stone vent.
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
      if (dust) {
        fleck(x, y, r * 0.018, 0xFFB5A286, sin(t * pi) * 0.42);
      }
      if (!dust && !reduced) {
        final curl = ui.Path()
          ..moveTo(x - size * 0.5, y)
          ..quadraticBezierTo(
            x,
            y - size * 0.65,
            x + size * 0.6,
            y - size * 0.2,
          );
        line(curl, tint, sin(t * pi) * 0.25, r * 0.01);
      }
    }
  } else if (element == 'Air') {
    // A pressure pocket: a pressed-down hollow with wind turning over it,
    // ash caught in the gusts. Readable at a glance, still quiet.
    _maskLightSpill(
      canvas,
      ui.Offset.zero,
      r * 0.7,
      const ui.Color(0xFF05080B),
      0.4,
      squash: 0.62,
    );
    final spin = time * 1.5 + seed;
    canvas.save();
    canvas.scale(1, 0.62);
    for (var i = 0; i < 3; i++) {
      fill(
        vfxSpiralArm(
          ui.Offset.zero,
          r * 0.88,
          spin + i * pi * 2 / 3,
          1.7,
          r * 0.13,
          reach: 0.72,
        ),
        const ui.Color(0xFFB6C4C8),
        0.2 + flash * 0.25,
      );
      fill(
        vfxSpiralArm(
          ui.Offset.zero,
          r * 0.88,
          spin + i * pi * 2 / 3 + 0.12,
          1.5,
          r * 0.05,
          reach: 0.7,
        ),
        const ui.Color(0xFFE0EAEC),
        0.22 + flash * 0.25,
      );
    }
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final a = spin * 1.8 + i * 1.047;
      final d = r * (0.35 + 0.45 * vfxHash(seed + i));
      fill(
        vfxLeaf(vfxPolar(a, d), r * 0.06, a + pi / 2),
        const ui.Color(0xFF9FAAA5),
        0.55,
      );
    }
    canvas.restore();
  } else if (element == 'Lightning') {
    fill(patch(0, 0, r * 0.8, 0.65, seed), 0xFF25272A, 0.32);
    // Brief branching discharges crawl through a charged patch of ground.
    final frame = (time * 7).floor();
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final angle = i * 2.399 + seed;
      final bolt = ui.Path()..moveTo(0, 0);
      for (var j = 1; j <= 7; j++) {
        final d = r * j / 8;
        final bend = sin(j * 13.7 + frame + i) * r * 0.07;
        bolt.lineTo(
          cos(angle) * d - sin(angle) * bend,
          (sin(angle) * d + cos(angle) * bend) * 0.65,
        );
      }
      final discharge = 0.16 + 0.32 * pow(max(0.0, sin(time * 8 + i * 2)), 5);
      line(bolt, 0xFF727C9C, discharge * 0.25, r * 0.06);
      line(bolt, 0xFFC1C4BE, discharge, r * 0.012);
    }
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
    for (var i = 0; i < (reduced ? 3 : 6); i++) {
      final x = sin(i * 4.1) * r * 0.5;
      final frost = ui.Path()
        ..moveTo(x, r * 0.24)
        ..lineTo(x * 1.3, r * 0.42)
        ..lineTo(x * 1.1 + r * 0.08, r * 0.46);
      line(frost, 0xFFB0C0B9, 0.3, r * 0.012);
    }
  } else if (element == 'Plant') {
    // Rootstock only: the shared, gameplay-driven tendrils render above it.
    // Roots split from a buried stump and run out into the stone at uneven
    // lengths, forking once — a root system, not a creature.
    fill(
      vfxBlob(ui.Offset.zero, r * 0.6, seed, n: 12, wobble: 0.2, squash: 0.55),
      const ui.Color(0xFF1A2317),
      0.8,
    );
    final roots = reduced ? 5 : 9;
    for (var i = 0; i < roots; i++) {
      final a = i * pi * 2 / roots + (vfxHash(seed + i) - 0.5) * 0.5;
      final len = r * (0.4 + 0.35 * vfxHash(seed + i * 3.3));
      final bend = (vfxHash(seed + i * 5.1) - 0.5) * 0.5;
      ui.Offset at(double t, double off) => ui.Offset(
        cos(a + bend * t + off) * len * t,
        sin(a + bend * t + off) * len * t * 0.56,
      );
      final spine = [for (var k = 0; k <= 6; k++) at(k / 6, 0)];
      fill(
        vfxRibbon(spine, r * 0.075, r * 0.01),
        const ui.Color(0xFF34402A),
        0.95,
      );
      fill(
        vfxRibbon(spine, r * 0.022, r * 0.004),
        const ui.Color(0xFF84906C),
        0.28 + flash * 0.25,
      );
      if (i.isEven && !reduced) {
        final fork = [
          for (var k = 0; k <= 4; k++)
            at(0.55 + 0.35 * k / 4, 0.35 * k / 4 * (i % 4 == 0 ? 1 : -1)),
        ];
        fill(
          vfxRibbon(fork, r * 0.035, r * 0.006),
          const ui.Color(0xFF34402A),
          0.9,
        );
      }
    }
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
  final paint = ui.Paint()..strokeCap = ui.StrokeCap.round;
  canvas.save();
  canvas.translate(position.dx, position.dy);
  if (element == 'Light') {
    final incision = ui.Path()
      ..moveTo(-r * 0.03, -r * (1 - t))
      ..lineTo(r * 0.035, -r * 0.25 * (1 - t))
      ..lineTo(-r * 0.025, r * 0.10 * (1 - t))
      ..lineTo(0, r * 0.75 * (1 - t));
    canvas.drawPath(
      incision,
      paint
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = max(1, r * 0.07 * (1 - t))
        ..color = bright.withValues(alpha: fade * 0.16),
    );
    canvas.drawPath(
      incision,
      paint
        ..strokeWidth = max(0.8, r * 0.018)
        ..color = bright.withValues(alpha: fade),
    );
  } else if (element == 'Crystal') {
    for (var i = 0; i < (reduced ? 3 : 9); i++) {
      final angle = i * 2.399;
      final dir = ui.Offset(cos(angle), sin(angle));
      final side = ui.Offset(-dir.dy, dir.dx);
      final centre = dir * r * (0.22 + t);
      final tip = centre + dir * r * 0.18;
      final left = centre + side * r * 0.055;
      final right = centre - side * r * 0.055;
      final shard = ui.Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(left.dx, left.dy)
        ..lineTo(right.dx, right.dy)
        ..close();
      canvas.drawPath(
        shard,
        paint
          ..style = ui.PaintingStyle.fill
          ..color = (i.isEven ? bright : color).withValues(alpha: fade),
      );
    }
  } else if (element == 'Water') {
    final spread = r * (0.28 + t * 0.85);
    // Torn surface fronts and low sprays, never a dotted ornamental crown.
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
      final spray = ui.Path()
        ..moveTo(base.dx - r * 0.09, base.dy)
        ..quadraticBezierTo(base.dx, base.dy - r * 0.07, tip.dx, tip.dy);
      canvas.drawPath(
        spray,
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = max(0.8, r * 0.014 * (1 - t))
          ..color = bright.withValues(alpha: fade * 0.75),
      );
    }
  } else if (element != 'Dark') {
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final a = i * 2.399;
      final d = r * (0.18 + t * 0.75);
      final x = cos(a) * d;
      final y = sin(a) * d * 0.55;
      final accent = ui.Path()..moveTo(x, y);
      if (element == 'Lightning') {
        accent
          ..lineTo(x + r * 0.06, y - r * 0.09)
          ..lineTo(x + r * 0.02, y - r * 0.12);
      } else if (element == 'Fire') {
        accent.lineTo(x + r * 0.015, y - r * 0.1 * (1 - t));
      } else {
        accent.quadraticBezierTo(x + r * 0.06, y - r * 0.05, x + r * 0.12, y);
      }
      canvas.drawPath(
        accent,
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = max(0.8, r * 0.012)
          ..color = bright.withValues(alpha: fade * 0.6),
      );
    }
  } else {
    // The first quarter pulls in; the remaining time throws streaks outward.
    final extent = t < 0.25 ? 0.8 - t * 2.4 : 0.2 + (t - 0.25) * 1.4;
    for (var i = 0; i < (reduced ? 4 : 8); i++) {
      final angle = i * 2.399 + 0.3;
      final dir = ui.Offset(cos(angle), sin(angle));
      canvas.drawLine(
        dir * r * extent,
        dir * r * (extent + 0.09 + 0.08 * sin(i * 4.3)),
        paint
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = max(1.2, r * 0.025)
          ..color = bright.withValues(alpha: fade * 0.85),
      );
    }
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
  final paint = ui.Paint()..style = ui.PaintingStyle.fill;
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
  canvas.drawCircle(
    c + ui.Offset(0, r * 0.03),
    max(1.0, r * 0.035),
    paint..color = const ui.Color(0xFFFFFFFF).withValues(alpha: 0.85 * alpha),
  );
  if (!reduced) {
    for (var i = 0; i < 2; i++) {
      final a = time * 1.9 + i * pi;
      canvas.drawCircle(
        c + ui.Offset(cos(a) * r * 0.28, sin(a) * r * 0.1),
        max(0.8, r * 0.018),
        paint
          ..color = const ui.Color(0xFFDCE6F4).withValues(alpha: 0.55 * alpha),
      );
    }
  }
  canvas.restore();
}
