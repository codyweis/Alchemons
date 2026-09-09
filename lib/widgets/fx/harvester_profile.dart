import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:flutter/animation.dart';

/// How a given harvester takes a specimen.
///
/// There are two renderers for the wild harvest — the Flame field that plays
/// on the creature standing in the scene, and the full-screen Flutter fallback
/// — and they were already near-identical copies of the same ring maths. Six
/// per-element choreographies written twice would have been twelve. So the
/// choreography lives here as data plus a few pure functions, and both
/// renderers read it. Change a harvester's character once, it changes in both.
///
/// The device is the same pulser drawn in [HarvesterGlyph]: it beats, it
/// clamps, it hauls the element home. What differs per element is how it
/// closes, how it answers being pushed against, and what comes off it.
class HarvesterProfile {
  const HarvesterProfile({
    required this.biomeId,
    required this.accent,
    required this.ringCount,
    required this.segsBase,
    required this.segsPerRing,
    required this.spinRate,
    required this.strokeBase,
    required this.closing,
    required this.flex,
    required this.flexAmount,
    required this.mote,
    required this.moteCount,
    required this.shatterSpread,
    this.sigil = false,
    this.prismatic = false,
  });

  final String biomeId;

  /// Ring colour. The specimen's own colour still lights the stage; this is
  /// the apparatus, and the apparatus belongs to the harvester.
  final Color accent;

  final int ringCount;

  /// Segments on the innermost ring, and how many more each ring out gets.
  /// Few and fat reads as jaws; many and thin reads as a continuous sheet.
  final int segsBase;
  final int segsPerRing;

  final double spinRate;
  final double strokeBase;

  final HarvesterClosing closing;
  final HarvesterFlex flex;

  /// How far the wall gives where the specimen leans on it.
  final double flexAmount;

  final HarvesterMote mote;
  final int moteCount;

  /// How far the ring shards fly when the specimen breaks out.
  final double shatterSpread;

  /// Draws a bound hexagram inside the rings.
  final bool sigil;

  /// Each ring takes a different element's colour.
  final bool prismatic;

  /// The apparatus for [biomeId], defaulting to the stabilized unit.
  static HarvesterProfile forBiome(String? biomeId) =>
      _profiles[biomeId] ?? _profiles['universal']!;

  /// The apparatus for an inventory key, for callers holding a device rather
  /// than an element.
  static HarvesterProfile forInventoryKey(String? key) =>
      forBiome(switch (key) {
        InvKeys.harvesterStdVolcanic => 'volcanic',
        InvKeys.harvesterStdOceanic => 'oceanic',
        InvKeys.harvesterStdEarthen => 'earthen',
        InvKeys.harvesterStdVerdant => 'verdant',
        InvKeys.harvesterStdArcane => 'arcane',
        InvKeys.harvesterGuaranteed => 'universal',
        _ => null,
      });

  /// Ring colour for ring [i] — the accent, unless the unit is prismatic, in
  /// which case each ring carries a different element.
  Color ringColor(int i) {
    if (!prismatic) return accent;
    const order = ['volcanic', 'oceanic', 'verdant', 'earthen', 'arcane'];
    final r = ElementResources.byBiomeId[order[i % order.length]];
    return r?.color ?? accent;
  }

  /// 0..1 raw sweep → 0..1 actual, shaped by how this device closes.
  double closingCurve(double raw) {
    final t = raw.clamp(0.0, 1.0);
    switch (closing) {
      // Slams most of the way, then settles — a clamp igniting.
      case HarvesterClosing.surge:
        return Curves.easeOutExpo.transform(t);
      // Jaws arriving in stages. Quantised, so it lands in three bites.
      case HarvesterClosing.stepped:
        const steps = 3;
        final stage = (t * steps).floor().clamp(0, steps - 1);
        final within = Curves.easeOutCubic.transform(
          ((t * steps) - stage).clamp(0.0, 1.0),
        );
        return ((stage + within) / steps).clamp(0.0, 1.0);
      // Reaches out slowly, then cinches at the end — a snare.
      case HarvesterClosing.cinch:
        return math.pow(t, 2.2).toDouble();
      case HarvesterClosing.smooth:
        return Curves.easeOutCubic.transform(t);
    }
  }

  /// Radial give at [angle] for this device, in cage units.
  ///
  /// [push] is 0..1 how hard the specimen is leaning; [phase] is the looping
  /// strain clock.
  double radialFlex(double angle, double phase, double push, double cage) {
    if (push <= 0) return 0;
    final amp = push * cage * flexAmount;
    switch (flex) {
      // A local bulge that follows where the specimen is shoving.
      case HarvesterFlex.bulge:
        return amp * math.sin(angle * 3 - phase * math.pi * 2);
      // A wave travelling round the ring instead of denting it.
      case HarvesterFlex.ripple:
        return amp * math.sin(angle * 6 - phase * math.pi * 4) * 0.75;
      // Grinding: the wall does not bend, it jolts.
      case HarvesterFlex.judder:
        return amp * (((phase * 6).floor() % 2 == 0) ? 0.55 : -0.55);
      // Tendrils writhing, each at its own rate.
      case HarvesterFlex.writhe:
        return amp *
            (math.sin(angle * 5 + phase * math.pi * 2) * 0.6 +
                math.sin(angle * 2 - phase * math.pi * 3) * 0.4);
      // The whole ring breathes rather than deforming.
      case HarvesterFlex.pulse:
        return amp * math.sin(phase * math.pi * 2) * 0.8;
      // The stabilized unit does not give. That is the point of it.
      case HarvesterFlex.none:
        return 0;
    }
  }

  static final Map<String, HarvesterProfile> _profiles = {
    // IGNITION CLAMP — few, fat, fast arcs that scorch inward and throw
    // sparks wherever the specimen touches them.
    'volcanic': HarvesterProfile(
      biomeId: 'volcanic',
      accent: ElementResources.byBiomeId['volcanic']!.color,
      ringCount: 3,
      segsBase: 4,
      segsPerRing: 1,
      spinRate: 1.6,
      strokeBase: 3.0,
      closing: HarvesterClosing.surge,
      flex: HarvesterFlex.bulge,
      flexAmount: 0.14,
      mote: HarvesterMote.ember,
      moteCount: 14,
      shatterSpread: 1.7,
    ),

    // PRESSURE DROWN — many thin segments read as a continuous sheet of
    // water, and the strain travels round it as a wave.
    'oceanic': HarvesterProfile(
      biomeId: 'oceanic',
      accent: ElementResources.byBiomeId['oceanic']!.color,
      ringCount: 3,
      segsBase: 14,
      segsPerRing: 4,
      spinRate: 0.55,
      strokeBase: 1.8,
      closing: HarvesterClosing.smooth,
      flex: HarvesterFlex.ripple,
      flexAmount: 0.09,
      mote: HarvesterMote.droplet,
      moteCount: 12,
      shatterSpread: 1.2,
    ),

    // CRUSHER — two heavy jaws arriving in stages. Barely turns, does not
    // bend, and grinds while it holds.
    'earthen': HarvesterProfile(
      biomeId: 'earthen',
      accent: ElementResources.byBiomeId['earthen']!.color,
      ringCount: 2,
      segsBase: 3,
      segsPerRing: 1,
      spinRate: 0.18,
      strokeBase: 4.4,
      closing: HarvesterClosing.stepped,
      flex: HarvesterFlex.judder,
      flexAmount: 0.06,
      mote: HarvesterMote.shard,
      moteCount: 9,
      shatterSpread: 1.0,
    ),

    // SNARE — thin tendrils that reach out, take their time, then cinch.
    'verdant': HarvesterProfile(
      biomeId: 'verdant',
      accent: ElementResources.byBiomeId['verdant']!.color,
      ringCount: 4,
      segsBase: 11,
      segsPerRing: 3,
      spinRate: 0.75,
      strokeBase: 1.5,
      closing: HarvesterClosing.cinch,
      flex: HarvesterFlex.writhe,
      flexAmount: 0.13,
      mote: HarvesterMote.spore,
      moteCount: 16,
      shatterSpread: 1.5,
    ),

    // SIGIL BIND — counter-spinning rings and a bound hexagram. The specimen
    // is not clamped, it is written into place.
    'arcane': HarvesterProfile(
      biomeId: 'arcane',
      accent: ElementResources.byBiomeId['arcane']!.color,
      ringCount: 3,
      segsBase: 6,
      segsPerRing: 0,
      spinRate: 2.4,
      strokeBase: 2.0,
      closing: HarvesterClosing.smooth,
      flex: HarvesterFlex.pulse,
      flexAmount: 0.10,
      mote: HarvesterMote.spark,
      moteCount: 18,
      shatterSpread: 1.9,
      sigil: true,
    ),

    // PRISMATIC LOCK — one ring per element, steady, and it does not flex.
    // The guaranteed device never looks like it is struggling.
    'universal': HarvesterProfile(
      biomeId: 'universal',
      accent: const Color(0xFFE4C16A),
      ringCount: 3,
      segsBase: 8,
      segsPerRing: 2,
      spinRate: 0.9,
      strokeBase: 2.4,
      closing: HarvesterClosing.smooth,
      flex: HarvesterFlex.none,
      flexAmount: 0,
      mote: HarvesterMote.prism,
      moteCount: 15,
      shatterSpread: 0.8,
      prismatic: true,
    ),
  };
}

/// How the field arrives.
enum HarvesterClosing { smooth, surge, stepped, cinch }

/// How the field answers being pushed against.
enum HarvesterFlex { bulge, ripple, judder, writhe, pulse, none }

/// What comes off the field while it holds, and what it throws when it fails.
enum HarvesterMote { ember, droplet, shard, spore, spark, prism }
