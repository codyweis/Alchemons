/// The shared elemental payload resolver for Survival Family Mastery.
///
/// Mastery nodes never author element-specific behaviour themselves. A node
/// says *when* a payload fires and *how strong* it is; this file says what the
/// payload is for each of the seventeen elements. That split is the whole
/// reason the system scales: 8 families x 3 paths x 4 nodes stays authorable
/// because none of those 96 nodes has to know what Mud does.
///
/// The resolver is deliberately pure. It reads numbers and returns a list of
/// [PayloadAction] descriptors; the survival game owns the one switch that
/// turns a descriptor into a status timer, a projectile, or a heal. Keeping the
/// table free of game references is what lets it be unit-tested without Flame,
/// and what stops seventeen elements of tuning from leaking into the 19k-line
/// combat file.
///
/// Tuning here matches docs/survival_species_mastery_design.md ("Elemental
/// payload"). Values are prototypes and expected to move during simulation.
library;

/// The primitive effects a payload can ask the combat runtime to perform.
///
/// Every element's payload decomposes into one or two of these. Adding an
/// element means composing existing primitives where possible; adding a
/// primitive means teaching the game's applier one new case.
enum PayloadEffect {
  /// Damage spread evenly over [PayloadAction.duration].
  damageOverTime,

  /// Immediate damage to the payload's own target.
  directDamage,

  /// Immediate damage split to other enemies near the target.
  arc,

  /// Immediate damage to everything inside [PayloadAction.radius].
  areaBurst,

  /// A persistent ground patch dealing [PayloadAction.amount] per second.
  zone,

  /// Movement slow. [PayloadAction.amount] is the fraction removed (0.25 =
  /// 25% slower), not the resulting multiplier.
  slow,

  /// A brief hard stop. Bosses receive a slow instead — see [vsBoss].
  stagger,

  /// A hard stop that also pins the target in place for the full duration.
  root,

  /// Displacement away from the payload's origin, in world units.
  push,

  /// Displacement toward the payload's origin, in world units.
  pull,

  /// Cancels an enemy action that is mid-wind-up.
  interrupt,

  /// Stacking cold. At [PayloadAction.maxStacks] the target freezes for
  /// [PayloadAction.followUpDuration] and the stacks clear.
  chill,

  /// Reduced movement *and* attack cadence, both by [PayloadAction.amount].
  haze,

  /// The target takes [PayloadAction.amount] more damage from every source.
  vulnerable,

  /// Allied damage to the target is amplified, capped at [PayloadAction.cap]
  /// so several Light sources cannot stack into a multiplier.
  allyAmp,

  /// A fraction of the triggering hit repeated after a delay.
  delayedEcho,

  /// Heals the payload's owner for a fraction of its maximum HP.
  heal,
}

/// One instruction for the combat runtime. Fields that an effect does not use
/// stay at zero; the applier reads only what its own case needs.
class PayloadAction {
  const PayloadAction(
    this.effect, {
    this.amount = 0,
    this.duration = 0,
    this.radius = 0,
    this.maxStacks = 0,
    this.targets = 0,
    this.cap = 0,
    this.followUpDuration = 0,
  });

  final PayloadEffect effect;

  /// Damage, damage-per-second, displacement distance, or effect fraction,
  /// depending on [effect]. Already scaled by elemental attack and node
  /// strength when it represents damage.
  final double amount;
  final double duration;
  final double radius;

  /// Stack ceiling for [PayloadEffect.chill] and [PayloadEffect.damageOverTime].
  final int maxStacks;

  /// How many additional enemies [PayloadEffect.arc] may reach.
  final int targets;

  /// Upper bound on a stacking amplification ([PayloadEffect.allyAmp]).
  final double cap;

  /// Secondary duration: the freeze that ends a chill, or the delay before a
  /// [PayloadEffect.delayedEcho] lands.
  final double followUpDuration;

  @override
  String toString() =>
      'PayloadAction(${effect.name}, amount: ${amount.toStringAsFixed(2)}, '
      'duration: ${duration.toStringAsFixed(2)})';
}

/// A resolved payload: everything one trigger should do, already tuned.
class ElementalPayload {
  const ElementalPayload({
    required this.element,
    required this.actions,
    this.procCooldown = 0,
  });

  static const none = ElementalPayload(element: '', actions: <PayloadAction>[]);

  final String element;
  final List<PayloadAction> actions;

  /// Minimum seconds between two applications of this payload from the same
  /// source. Only elements whose payload is a resource (Blood's heal) set it;
  /// every other rate limit is the node's business, not the element's.
  final double procCooldown;

  bool get isEmpty => actions.isEmpty;
  bool get isNotEmpty => actions.isNotEmpty;

  /// Total immediate damage this payload deals, for telemetry pre-checks.
  double get immediateDamage {
    var total = 0.0;
    for (final action in actions) {
      switch (action.effect) {
        case PayloadEffect.directDamage:
        case PayloadEffect.arc:
        case PayloadEffect.areaBurst:
          total += action.amount;
        default:
          break;
      }
    }
    return total;
  }
}

/// Control durations are cut against bosses so a payload chain cannot lock one
/// down, but the damage portion is never removed — a Fire payload on a boss
/// still burns for its full total.
const double kBossControlScale = 0.45;

/// Resolves one application of [element]'s payload.
///
/// [elementalAttack] is the caster's elemental attack; [strength] is the node's
/// allocation (0.8 for a node that fires the payload "at 80% strength").
/// [triggeringDamage] only matters to Spirit, whose echo is a fraction of the
/// hit that caused it.
ElementalPayload resolveElementalPayload({
  required String element,
  required double elementalAttack,
  double strength = 1.0,
  bool vsBoss = false,
  double triggeringDamage = 0,
}) {
  final ea = elementalAttack <= 0 ? 0.0 : elementalAttack;
  final s = strength <= 0 ? 0.0 : strength;
  if (s == 0) return ElementalPayload.none;

  // Control durations shrink against bosses; damage does not.
  double control(double seconds) =>
      vsBoss ? seconds * kBossControlScale : seconds;
  double dmg(double fraction) => ea * fraction * s;

  final actions = <PayloadAction>[];
  var cooldown = 0.0;

  switch (element.toLowerCase()) {
    case 'fire':
      // Scorch for 30% elemental attack over 2 seconds. A single stack: the
      // table gives stacking to Poison and only to Poison, and because stacks
      // add rate here rather than duration, a stacking Fire saturated at
      // three would burn at 45% a second instead of 15%.
      actions.add(
        PayloadAction(
          PayloadEffect.damageOverTime,
          amount: dmg(0.30),
          duration: 2.0,
          maxStacks: 1,
        ),
      );

    case 'water':
      // Pull 24 units and slow by 12% for 1.2 seconds.
      actions.add(PayloadAction(PayloadEffect.pull, amount: 24.0 * s));
      actions.add(
        PayloadAction(
          PayloadEffect.slow,
          amount: 0.12 * s,
          duration: control(1.2),
        ),
      );

    case 'earth':
      // Stagger for 0.25 seconds. A boss cannot be staggered at all, so it
      // takes the design's explicit substitute rather than nothing.
      if (vsBoss) {
        actions.add(
          const PayloadAction(PayloadEffect.slow, amount: 0.08, duration: 0.8),
        );
      } else {
        actions.add(PayloadAction(PayloadEffect.stagger, duration: 0.25 * s));
      }

    case 'air':
      // Push 45 units and interrupt ordinary enemies.
      actions.add(PayloadAction(PayloadEffect.push, amount: 45.0 * s));
      if (!vsBoss) actions.add(const PayloadAction(PayloadEffect.interrupt));

    case 'plant':
      // Root for 0.4 seconds and deal 15% elemental attack as a thorn hit.
      actions.add(PayloadAction(PayloadEffect.root, duration: control(0.4)));
      actions.add(PayloadAction(PayloadEffect.directDamage, amount: dmg(0.15)));

    case 'ice':
      // Chill for 2 seconds; three stacks freeze for 0.45 seconds.
      actions.add(
        PayloadAction(
          PayloadEffect.chill,
          duration: control(2.0),
          maxStacks: 3,
          followUpDuration: control(0.45),
        ),
      );

    case 'lightning':
      // Arc for 30% elemental attack to one nearby enemy.
      actions.add(
        PayloadAction(
          PayloadEffect.arc,
          amount: dmg(0.30),
          targets: 1,
          radius: 180,
        ),
      );

    case 'poison':
      // 12% elemental attack per second for 3 seconds, up to three stacks.
      actions.add(
        PayloadAction(
          PayloadEffect.damageOverTime,
          amount: dmg(0.12) * 3.0,
          duration: 3.0,
          maxStacks: 3,
        ),
      );

    case 'steam':
      // Burst in a small radius for 22% elemental attack and push slightly.
      actions.add(
        PayloadAction(PayloadEffect.areaBurst, amount: dmg(0.22), radius: 90),
      );
      actions.add(PayloadAction(PayloadEffect.push, amount: 14.0 * s));

    case 'lava':
      // A 2-second molten patch dealing 10% elemental attack per second.
      actions.add(
        PayloadAction(
          PayloadEffect.zone,
          amount: dmg(0.10),
          duration: 2.0,
          radius: 74,
        ),
      );

    case 'mud':
      // Heavy: slow by 25% for 1.5 seconds.
      actions.add(
        PayloadAction(
          PayloadEffect.slow,
          amount: 0.25 * s,
          duration: control(1.5),
        ),
      );

    case 'dust':
      // Haze: movement and attack cadence down 10% for 2 seconds.
      actions.add(
        PayloadAction(
          PayloadEffect.haze,
          amount: 0.10 * s,
          duration: control(2.0),
        ),
      );

    case 'crystal':
      // Fire a shard at another target for 25% elemental attack.
      actions.add(
        PayloadAction(
          PayloadEffect.arc,
          amount: dmg(0.25),
          targets: 1,
          radius: 260,
        ),
      );

    case 'spirit':
      // Echo 25% of the triggering elemental damage after 0.5 seconds. Scaled
      // by the hit that caused it, not by elemental attack, so a Spirit echo
      // on a weak proc stays weak.
      actions.add(
        PayloadAction(
          PayloadEffect.delayedEcho,
          amount: triggeringDamage * 0.25 * s,
          followUpDuration: 0.5,
        ),
      );

    case 'dark':
      // Pull 35 units and expose the target to 5% more damage for 2 seconds.
      actions.add(PayloadAction(PayloadEffect.pull, amount: 35.0 * s));
      actions.add(
        PayloadAction(
          PayloadEffect.vulnerable,
          amount: 0.05 * s,
          duration: control(2.0),
        ),
      );

    case 'light':
      // Allied damage to the target up 5% for 2 seconds, maximum 10%.
      actions.add(
        PayloadAction(
          PayloadEffect.allyAmp,
          amount: 0.05 * s,
          duration: control(2.0),
          cap: 0.10,
        ),
      );

    case 'blood':
      // Heal the owner for 1% maximum HP, at most once per second. The rate
      // limit belongs to the element here because the resource is the payload.
      actions.add(PayloadAction(PayloadEffect.heal, amount: 0.01 * s));
      cooldown = 1.0;

    default:
      return ElementalPayload.none;
  }

  return ElementalPayload(
    element: element,
    actions: List<PayloadAction>.unmodifiable(actions),
    procCooldown: cooldown,
  );
}

/// Every element the resolver knows. A payload asked for anything outside this
/// set resolves to [ElementalPayload.none] rather than silently doing nothing
/// damaging but claiming a proc.
const List<String> kPayloadElements = [
  'Fire',
  'Water',
  'Earth',
  'Air',
  'Plant',
  'Ice',
  'Lightning',
  'Poison',
  'Steam',
  'Lava',
  'Mud',
  'Dust',
  'Crystal',
  'Spirit',
  'Dark',
  'Light',
  'Blood',
];
