import 'dart:math' as math;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/fx/grain_glass.dart';
import 'package:alchemons/widgets/fx/harvest_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A harvester drawn as the device it is in the wild.
///
/// This is the harvest itself ([HarvestParticleField]) at the size of an
/// icon, not a picture of it: the device's shell pours in round a specimen
/// (a ball of its grains), closes the way that device closes, holds while it
/// is pushed against, then takes it — the specimen folds into a sphere of
/// its own grains, the shell closes round it as its skin, and it seals warm
/// and fades. Kept apart from the element's own resource glyph by the shell:
/// loose motes are the resource, a shell round something is the device that
/// takes it.
///
/// [biomeId] takes the five elements plus [universalHarvester], the stabilized
/// unit that takes every element — a different one each time round.
class HarvesterGlyph extends StatelessWidget {
  const HarvesterGlyph({
    super.key,
    required this.biomeId,
    required this.size,
    this.color,
    this.animate = true,
  });

  /// 'volcanic' | 'oceanic' | 'earthen' | 'verdant' | 'arcane' | 'universal'
  final String biomeId;
  final double size;

  /// Overrides the element's own colour — used to carry a can-afford state.
  final Color? color;

  /// Off for a still frame; a shop card scrolling past does not need to run.
  final bool animate;

  @override
  Widget build(BuildContext context) => GrainGlyph(
    size: size,
    animate: animate,
    painter: (clock) =>
        _HarvesterPainter(biomeId.isEmpty ? 'arcane' : biomeId, color, clock),
  );
}

/// The stabilized harvester, which is not tied to one element.
const String universalHarvester = 'universal';

class _HarvesterPainter extends CustomPainter {
  _HarvesterPainter(this.biomeId, this.tint, this.clock)
    : super(repaint: clock);

  final String biomeId;
  final Color? tint;
  final ValueListenable<double>? clock;

  /// One harvest: the shell pours in and closes, holds, takes.
  static const double _period = 5.4;

  /// A still glyph shows the shell shut on its specimen.
  static const double _still = 0.46 * _period;

  /// Where the take starts; it then runs the field's own take length.
  static const double _takeFrom =
      1 - HarvestParticleField.takeSeconds / _period;

  /// The stabilized unit takes a different element each harvest.
  static const List<String> _anyElement = [
    'volcanic',
    'oceanic',
    'verdant',
    'earthen',
    'arcane',
  ];

  /// One field per device, size and colour: the shell is seeded once.
  static final Map<(String, int, int, int), HarvestParticleField> _fields = {};

  HarvestParticleField _field(double s, Color specimen) {
    final small = s < 30;
    return _fields.putIfAbsent(
      (biomeId, s.round(), tint?.toARGB32() ?? 0, specimen.toARGB32()),
      () {
        var profile = HarvesterProfile.forBiome(biomeId);
        if (tint != null) {
          profile = profile.copyWith(accent: tint, prismatic: false);
        }
        // The sigil is lines; at a button's size it is only noise.
        if (small) profile = profile.copyWith(sigil: false);
        return HarvestParticleField(
          profile: profile,
          cage: s * (small ? 0.34 : 0.3),
          specimenColor: specimen,
          shellCount: small ? 220 : (s * 7).round().clamp(300, 900),
          grain: (s * (small ? 0.05 : 0.0105) * (1 + 0.16 * profile.strokeBase))
              .clamp(small ? 1.25 : 1.0, 3.0),
          rise: 0.15,
          sigilStrength: 0.4,
        );
      },
    );
  }

  static double _clamp01(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (s <= 0) return;
    final t = (clock?.value ?? 0) + _still;
    final cycle = (t / _period).floor();
    final p = (t % _period) / _period;
    final o = Offset(size.width / 2, size.height / 2);

    final specimen =
        tint ??
        (biomeId == universalHarvester
            ? ElementResources.byBiomeId[_anyElement[cycle % 5]]!.color
            : HarvesterProfile.forBiome(biomeId).accent);
    final field = _field(s, specimen);

    // The beat the hosts would drive: in, bite, lean, take.
    final closing = _clamp01(p / 0.3);
    final lock = _clamp01((p - 0.27) / 0.1);
    final push =
        0.75 *
        GrainGlass.smooth((p - 0.32) / 0.08) *
        (1 - GrainGlass.smooth((p - _takeFrom + 0.04) / 0.04)) *
        (0.5 - 0.5 * math.cos(t * math.pi * 2.2));
    final take = _clamp01((p - _takeFrom) / (1 - _takeFrom));

    void pass(bool back) => field.paint(
      canvas,
      o,
      closing: closing,
      lock: lock,
      push: push,
      strain: t * 0.35,
      time: t,
      take: take,
      back: back,
    );

    pass(true);
    // The specimen it closes on: a ball of its grains, until the take turns
    // it into the field's own.
    final standing = 1 - GrainGlass.smooth(take / 0.2);
    if (standing > 0.01) {
      GrainGlass.sphere(
        canvas,
        o,
        field.cage * 0.42,
        t,
        a: specimen,
        b: Color.lerp(specimen, Colors.white, 0.3),
        spin: 0.7,
        glass: 0,
        gather: GrainGlass.smooth(p / 0.24),
        fade: standing,
        glow: 0.7,
        salt: 7,
      );
    }
    pass(false);
  }

  @override
  bool shouldRepaint(covariant _HarvesterPainter old) =>
      old.biomeId != biomeId || old.tint != tint || old.clock != clock;
}

/// The element a harvester is tuned to, or [universalHarvester] for the
/// stabilized unit. Null for anything that is not a harvester.
///
/// Single source of truth for the shop card, the inventory tile, the space
/// market and the wild-harvest cinematic, so a harvester looks like itself
/// everywhere it appears.
String? harvesterBiomeForKey(String? inventoryKey) => switch (inventoryKey) {
  InvKeys.harvesterStdVolcanic => 'volcanic',
  InvKeys.harvesterStdOceanic => 'oceanic',
  InvKeys.harvesterStdEarthen => 'earthen',
  InvKeys.harvesterStdVerdant => 'verdant',
  InvKeys.harvesterStdArcane => 'arcane',
  InvKeys.harvesterGuaranteed => universalHarvester,
  _ => null,
};
