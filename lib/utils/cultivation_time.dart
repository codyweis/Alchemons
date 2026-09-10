import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/utils/nature_utils.dart';

/// How long a cultivation takes, once everything that shortens it is applied.
///
/// This chain existed twice — in BreedingServiceV2 and again in
/// EggHatchingService — with the same four multipliers written out both
/// times. Two copies of a formula is one copy that will be forgotten, and
/// the half-cultivation boost is exactly the kind of thing that would have
/// landed in one and not the other.
Duration cultivationDuration({
  required Duration base,
  String? natureId,
  String? nature2Id,
  double gestationReduction = 0,
  double fireMultiplier = 1.0,
  bool halfCultivation = false,
}) {
  // Nature can push either way; everything else only ever shortens.
  final natureMult = hatchMultForNatures(natureId, nature2Id);
  final boostMult = halfCultivation
      ? TimedBoostService.halfCultivationMultiplier
      : 1.0;
  final totalMult =
      natureMult * (1.0 - gestationReduction) * fireMultiplier * boostMult;
  return Duration(milliseconds: (base.inMilliseconds * totalMult).round());
}
