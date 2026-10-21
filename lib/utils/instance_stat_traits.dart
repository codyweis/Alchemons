import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/purity_stat_bonus.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/variant_stat_bonus.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/instance_purity_util.dart';

/// What an individual's own traits multiply one stat by, beyond its species,
/// level, Potential and enhancement: its natures, its bloodline's purity roll,
/// its variant (held by a player who joined [joinedFaction]) and a
/// Prismatic's +1%.
///
/// Every writer of a creature's stats uses this, so a level-up, an
/// enhancement or a rebirth keeps every bonus the load-time pass gives.
double instanceTraitMultiplier(
  CreatureInstance instance,
  String statKey, {
  Creature? species,
  String? joinedFaction,
}) {
  final purity = classifyInstancePurity(instance, species: species);
  return AlchemonStatSystem.natureMultiplier(
        instance.natureId,
        statKey,
        instance.natureId2,
      ) *
      resolvePurityStatBonus(
        instanceId: instance.instanceId,
        isElementallyPure: purity.isElementallyPure,
        isSpeciesPure: purity.isSpeciesPure,
      ).multiplierFor(statKey) *
      resolveVariantStatBonus(
        variantFaction: instance.variantFaction,
        joinedFaction: joinedFaction,
      ).multiplierFor(statKey) *
      (instance.mutation == AlchemonMutation.prismatic.id
          ? 1 + kPrismaticStatBonus
          : 1.0);
}
