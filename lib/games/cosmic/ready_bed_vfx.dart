import 'dart:math';
import 'dart:ui' as ui;

import 'ability_grains.dart' show abilityMaterialTint;
import 'vfx_shapes.dart';

/// What lies under a creature, and how ready its special is, read off the
/// body with no bar: grains of its own material lie loose and dim round it
/// while the special is spent, draw in under it as the special comes back,
/// and sit tight and bright in its light when it is ready. A cast throws
/// them wide again.
///
/// [ready] is 0 spent .. 1 ready, already eased by the caller so a cast
/// throws the bed out over a few frames and never snaps. [power] 0..1 is how
/// grown the creature is (level and mastery): a grown one stands on more.
/// [blessed] puts pale gold among them while a blessing is on it.
///
/// Drawn at the canvas origin (the creature's position), before its sprite.
/// Budget: one soft fill and at most three point batches of fifteen grains
/// between them; no blur, no strokes.
void drawReadyBed({
  required ui.Canvas canvas,
  required String element,
  required ui.Color color,
  required double ready,
  required double power,
  required double time,
  bool blessed = false,
  double seed = 0,
}) {
  final r = ready.clamp(0.0, 1.0);
  final e = r * r * (3 - 2 * r);
  final m = vfxMaterial(element);
  vfxSpill(
    canvas,
    const ui.Offset(0, 5),
    26 + 6 * e,
    abilityMaterialTint(color),
    0.15 + 0.17 * e,
  );
  final n = readyBedGrains(power);
  for (var pass = 0; pass < 3; pass++) {
    for (var i = 0; i < n; i++) {
      final h = vfxHash(seed * 7.13 + i * 1.37);
      final bucket = blessed && i % 3 == 0 ? 2 : (h > 0.5 ? 1 : 0);
      if (bucket != pass) continue;
      // Slow while loose, a little quicker as they gather; alternate ways.
      final a =
          i * 2.39996 +
          time * (0.2 + 0.22 * h) * (i.isEven ? 1 : -1) * (0.35 + 0.65 * e);
      // Ready, they ring its feet just clear of the body; spent, they lie
      // out to twice that.
      final rho =
          (50 - 26 * e) * (0.8 + 0.4 * h) + sin(time * 1.3 + i) * 1.6 * e;
      // Lying on the ground under it: flattened, a little below its middle.
      vfxGrain(cos(a) * rho, 7 + sin(a) * rho * 0.55);
    }
    switch (pass) {
      case 0:
        vfxGrainsFlush(canvas, 2.2 + 0.6 * e, m.light, 0.28 + 0.4 * e);
      case 1:
        vfxGrainsFlush(canvas, 2.5 + 0.9 * e, m.glint, 0.32 + 0.62 * e);
      default:
        vfxGrainsFlush(canvas, 2.6 + 0.8 * e, _gilt, 0.4 + 0.55 * e);
    }
  }
}

const _gilt = ui.Color(0xFFE2C98F);

/// How many grains a creature of [power] 0..1 stands on.
int readyBedGrains(double power) => 6 + (9 * power.clamp(0.0, 1.0)).round();
