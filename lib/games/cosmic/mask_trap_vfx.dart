import 'dart:math';
import 'dart:ui' as ui;
import 'cosmic_data.dart';
import 'cosmic_projectile_vfx.dart' show ZoneVfxEmit;
import 'element_ground_art.dart';
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
  canvas.save();
  canvas.translate(position.dx, position.dy);
  // Survival keeps consumed Light/Crystal fixtures briefly for their existing
  // activation timer. Collapse the fixture while independent debris finishes.
  final flash = projectile.abilityGrowthTimer.clamp(0.0, 1.0);
  // A trap goes by dissolving where it lies: over its last half second, and
  // when a sprung Light or Crystal trap is spent. (It used to shrink to a
  // point when sprung, which read as it zooming away.)
  var gone = (projectile.life / 0.5).clamp(0.0, 1.0);
  if (flash > 0 && (element == 'Light' || element == 'Crystal')) {
    final window = element == 'Light' ? 0.64 : 0.48;
    gone = min(gone, (1 - (1 - flash) / window).clamp(0.0, 1.0));
  }

  // The element's ground, in grains with no outline (element_ground_art.dart):
  // what every trap is drawn as now. Dust is not ground (it rides its host
  // as a shield) and a Spirit wisp is a thing to collect, so both keep the
  // art below. Drawn a little past the trap's reach, since it thins to
  // nothing at its rim where the old patch had a hard edge.
  if (element != 'Dust' && element != 'Spirit') {
    final at = projectile.lookAnchor ?? position;
    if (paintElementGround(
      canvas,
      element,
      r * 1.12,
      time,
      at.dx * 0.013 + at.dy * 0.017,
      reduced: reduced,
      // A Mask's Earth pool heals whoever stands in it.
      mends: element == 'Earth',
      fade: gone,
    )) {
      canvas.restore();
      return true;
    }
  }

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
    final breathe =
        0.85 +
        0.15 * sin(time * 1.6 + (projectile.lookAnchor ?? position).dx * 0.01);
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
  // A fixture that creeps is seeded from where it was laid, or every shape
  // it draws would reshuffle as it went.
  final anchor = projectile.lookAnchor ?? position;
  final seed = anchor.dx * 0.013 + anchor.dy * 0.017;
  _drawRemainingMask(canvas, projectile, r, time, seed, reduced);
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
  final flash = p.abilityGrowthTimer.clamp(0.0, 1.0);
  // Only Dust (a shield riding its host) and Spirit (a wisp to collect)
  // come here: every other trap is its element's ground, drawn above.
  if (element == 'Dust') {
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
    // Banks of grit, three grains to a bank, hanging out past the body it
    // guards: fourteen single grains from 0.3 r sat mostly behind the
    // creature and read as nothing.
    for (var i = 0; i < (reduced ? 10 : 22); i++) {
      final a = seed + i * 2.399963;
      final d = r * (0.66 + 0.4 * vfxHash(seed + i * 2));
      final drift = vfxPolar(
        time * 0.4 + i * 1.7,
        r * 0.05 * (0.5 + vfxHash(seed + i * 5)),
      );
      final g = vfxPolar(a, d) + drift;
      // A clump, not a row: three in a line read as a dash.
      final step = max(3.0, r * 0.05);
      for (var k = 0; k < 3; k++) {
        final o = vfxPolar(
          vfxHash(seed + i * 7 + k * 1.9) * pi * 2,
          step * (0.4 + 0.6 * vfxHash(seed + i * 3 + k)),
        );
        vfxGrain(g.dx + o.dx, g.dy + o.dy);
      }
    }
    vfxGrainsFlush(
      canvas,
      max(2.6, r * 0.04),
      const ui.Color(0xFFD6C29E),
      0.8 + flash * 0.2,
    );
    final stones = p.interceptCharges.clamp(0, 6);
    for (var i = 0; i < stones; i++) {
      final a = seed + 0.8 + i * pi * 2 / max(1, stones);
      final c =
          vfxPolar(a, r * 0.92) +
          ui.Offset(0, sin(time * 1.3 + i * 1.9) * r * 0.03);
      final sr = r * 0.09;
      // Lighter than the floor: a near-black stone on it could not be seen.
      fill(
        vfxBlob(c, sr, seed + i, n: 6, wobble: 0.28),
        const ui.Color(0xFF6E5C44),
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
        const ui.Color(0xFFD6C29E),
        0.7,
      );
    }
    canvas.restore();
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
    r * 0.9,
    const ui.Color(0xFFA8B8D8),
    0.32 * alpha,
    squash: 0.6,
  );
  final bob = sin(time * 1.6) * r * 0.05;
  final flicker = 0.9 + 0.1 * sin(time * 7.3);
  final c = ui.Offset(sin(time * 1.1) * r * 0.03, -r * 0.3 + bob);
  // Tail streams upward; head sits low and round.
  final lean = pi / 2 + sin(time * 2.3) * 0.12;
  canvas.drawPath(
    vfxDrop(c, r * 0.36 * flicker, lean),
    paint..color = const ui.Color(0xFF6A7C98).withValues(alpha: 0.42 * alpha),
  );
  canvas.drawPath(
    vfxDrop(c + ui.Offset(0, r * 0.04), r * 0.21 * flicker, lean),
    paint..color = const ui.Color(0xFFDCE6F4).withValues(alpha: 0.72 * alpha),
  );
  if (!reduced) {
    // Two grains of it lifting off the flame and fading as they rise (they
    // used to circle it), and no white pip at its heart.
    for (var i = 0; i < 5; i++) {
      final ph = (time * 0.45 + i * 0.2) % 1.0;
      vfxGrain(
        c.dx + sin(time * 1.3 + i * 2.4) * r * 0.14,
        c.dy - r * 0.3 - ph * r * 0.7,
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
