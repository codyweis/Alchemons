// lib/games/cosmic/enemy_body_art.dart
//
// What is left of the old enemy art, now that every enemy and boss in
// survival, open space and the planet dungeons is drawn in grains
// (lib/games/cosmic_survival/roster_art.dart and boss_roster_art.dart):
//
//  - each element's enemy colours, which a death's grains and a mender's
//    flow are lit in;
//  - the drone forms' count, which the survival spawner draws a wave's form
//    from (its own seeded stream, so seeded runs are unchanged);
//  - the six boss archetypes' forms by name, which their grain painters are
//    chosen by.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/vfx_shapes.dart';
import 'package:flutter/painting.dart';

// ── palette ─────────────────────────────────────────────────────────────────

/// One element's enemy colours.
class EnemyPalette {
  EnemyPalette._(this.ink, this.face, this.rim, this.essence, this.hot);

  factory EnemyPalette._of(String element, Color base) {
    final hsl = HSLColor.fromColor(base);
    final essence = hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.92))
        .withLightness(hsl.lightness.clamp(0.58, 0.70))
        .toColor();
    final m = vfxMaterial(element);
    return EnemyPalette._(
      Color.lerp(m.ink, essence, 0.06)!,
      Color.lerp(Color.lerp(m.ink, m.mid, 0.62)!, essence, 0.10)!,
      Color.lerp(m.mid, essence, 0.55)!,
      essence,
      Color.lerp(essence, const Color(0xFFFFFFFF), 0.62)!,
    );
  }

  /// The shell: dark body, lit face, the edge that catches the inner light.
  final Color ink, face, rim;

  /// The trapped light, and its white-hot centre.
  final Color essence, hot;
}

final Map<String, EnemyPalette> _palettes = {};
final Map<int, EnemyPalette> _tintedPalettes = {};

/// The palette for [element], or for [tint] in [element]'s material when a
/// body is drawn in a colour of its own.
EnemyPalette enemyPalette(String element, [Color? tint]) {
  if (tint == null) {
    return _palettes[element] ??= EnemyPalette._of(
      element,
      elementColor(element),
    );
  }
  final key = element.hashCode * 1000003 ^ tint.toARGB32();
  return _tintedPalettes[key] ??= EnemyPalette._of(element, tint);
}

// ── drone forms ─────────────────────────────────────────────────────────────

/// How many drone forms there are.
const int kDroneForms = 3;

/// A drone's form when nothing chose one for it: from its stable seed.
int droneFormForSeed(double seed) => (seed * 7.3).floor() % kDroneForms;

// ── boss forms ──────────────────────────────────────────────────────────────

/// The six boss archetypes' forms:
///
///   charger     the Comet        a blazing nucleus trailing a river of
///                                embers, debris tumbling round it
///   gunner      the Singularity  a black hole in a disk, the far side
///                                lensed up over the top
///   skirmisher  the Ouroboros    a serpent of vertebrae swimming a circle
///                                round an egg of light
///   bulwark     the Spire        a crystal spire, fire in its veins, debris
///                                wheeling round it
///   carrier     the Hive         a murmuration on shifting orbits round a
///                                dark core
///   warden      the Armillary    rings turning on three axes round a sun,
///                                runes set in them
///
/// Each is drawn in grains by `paintGrainFormOf` (boss_roster_art.dart).
enum BossForm { comet, singularity, ouroboros, spire, hive, armillary }

BossForm bossFormFor(BossType t) => switch (t) {
  BossType.charger => BossForm.comet,
  BossType.gunner => BossForm.singularity,
  BossType.skirmisher => BossForm.ouroboros,
  BossType.bulwark => BossForm.spire,
  BossType.carrier => BossForm.hive,
  BossType.warden => BossForm.armillary,
};
