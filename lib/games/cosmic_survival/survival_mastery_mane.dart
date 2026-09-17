/// Mane's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Phase 3 of docs/survival_species_mastery_design.md — the vertical slice.
/// Mane is the flexible skirmisher whose chassis is two close-angle slashes,
/// and all three paths are about what landing one or both of those blades is
/// worth:
///
/// * **Twin Fang** (assault) tightens the pair and pays for putting both into
///   one body, then chains off kills.
/// * **War Rhythm** (resonance) banks Rhythm from clean pairs and spends it on
///   cadence — a ring on every fourth cast, then empowered casts and a window.
/// * **Limitless** carries one idea four times: the catapult shot does not
///   stop. It flies further, hits harder, stops expiring, and finally the
///   first shot of each cast peels off to circle the arena.
///
/// The family used to have a Tempest Claw path instead of Limitless. It was
/// replaced because three of its four nodes had no idea in them — two stat
/// tweaks and a node that re-applied the element the node above it had
/// already applied — and it measured last of the three. Its one good node,
/// Tempest Ring, moved to War Rhythm, where a cadence counter belongs.
///
/// The state below lives per companion slot for the length of a run. Nothing
/// here reaches into combat: the game owns the one place that reads this state
/// and turns it into slashes, and the shared runtime owns cast accounting,
/// payload rate limits and the object budget.
library;

/// Node ids, so the game never spells one out as a string literal. A typo in
/// a literal is a node that silently never fires.
class ManeNodes {
  const ManeNodes._();

  static const assaultPath = 'mane.assault';
  static const resonancePath = 'mane.resonance';
  static const limitlessPath = 'mane.limitless';

  static const honedPair = 'mane.assault.honed_pair';
  static const crosscut = 'mane.assault.crosscut';
  static const predatorStep = 'mane.assault.predator_step';
  static const bladeDance = 'mane.assault.blade_dance';

  static const measuredCuts = 'mane.resonance.measured_cuts';
  static const tempestRing = 'mane.resonance.tempest_ring';
  static const crescendo = 'mane.resonance.crescendo';
  static const encore = 'mane.resonance.encore';

  static const farThrow = 'mane.limitless.far_throw';
  static const overdraw = 'mane.limitless.overdraw';
  static const noHorizon = 'mane.limitless.no_horizon';
  static const endlessCircuit = 'mane.limitless.endless_circuit';
}

/// Cast tags, set when a cast launches and read when it lands.
class ManeCastTags {
  const ManeCastTags._();

  /// This basic was empowered by Crescendo: extra damage and one payload.
  static const crescendo = 'mane.crescendo';

  /// This basic's slashes return to the Mane (Blade Dance).
  static const bladeDance = 'mane.bladeDance';

  /// This is a Tempest Ring, not a scheduled attack.
  static const tempestRing = 'mane.tempestRing';
}

/// Initial balance targets. Every one of these is a prototype and expected to
/// move once the slice is simulated.
class ManeTuning {
  const ManeTuning._();

  /// The chassis: two slashes at 65% physical, ±0.08 radians off the aim.
  static const double baseSlashFraction = 0.65;
  static const double baseSpread = 0.08;

  // ── Twin Fang ──
  /// Honed Pair: 35% closer together, 70% physical each.
  static const double honedPairSpreadScale = 0.65;
  static const double honedPairSlashFraction = 0.70;

  /// Crosscut: a dual hit adds 20% physical and fires one payload per cast.
  static const double crosscutBonusFraction = 0.20;
  static const double crosscutPayloadStrength = 1.0;

  /// Predator Step: a basic kill empowers the next cast inside this window.
  static const double predatorStepWindow = 3.0;
  static const double predatorStepDamageBonus = 0.25;
  static const double predatorStepHoming = 3.2;

  /// Blade Dance: a special empowers this many basic casts, whose slashes
  /// return for this fraction of their outgoing damage.
  static const int bladeDanceCasts = 5;
  static const double bladeDanceReturnFraction = 0.35;

  // ── Limitless ──
  /// Far Throw: the special's projectiles carry 45% further before fading.
  static const double farThrowLifeScale = 1.45;

  /// Overdraw: a flat 15% on the special. Deliberately plain — several
  /// elements already grow as they travel (Light ramps per pierce, Earth
  /// sheds fragments), so a second "gains power with distance" node would be
  /// describing what the element was already doing.
  static const double overdrawDamageBonus = 0.15;

  /// Endless Circuit: the first projectile of each cast sweeps out to this
  /// fraction of the arena radius and circles it.
  static const double circuitRadiusFraction = 0.72;

  /// Radians per second around the rim. Fast enough to meet a wave walking
  /// in, slow enough to read as one object rather than a strobe.
  static const double circuitAngularSpeed = 1.15;

  /// Tempest Ring: every fourth cast throws a ring of radial slashes.
  static const int tempestRingCadence = 4;
  static const int tempestRingSlashes = 8;
  static const double tempestRingSlashFraction = 0.20;
  static const int tempestRingMaxHitsPerTarget = 3;
  static const double tempestRingSpeed = 0.85;
  static const double tempestRingLife = 0.55;

  // ── War Rhythm ──
  /// Measured Cuts: a dual hit banks Rhythm; a cast that misses with both
  /// blades spends one.
  static const int maxRhythm = 5;
  static const double rhythmHastePerStack = 0.02;

  /// Crescendo: the special spends all Rhythm to empower that many casts.
  static const double crescendoDamageBonus = 0.12;
  static const double crescendoPayloadStrength = 1.0;

  /// Encore: spending a full five Rhythm opens a window that kills extend.
  static const double encoreDuration = 6.0;
  static const double encoreHaste = 0.25;
  static const double encoreWidthScale = 1.20;
  static const double encoreKillExtension = 0.4;
  static const double encoreMaxExtension = 2.0;

  /// How long a cast is given to land before a silent one counts as a miss.
  /// A slash lives two seconds; the slack keeps a slow last hit from costing
  /// the player a Rhythm they actually earned.
  static const double missGrace = 2.3;
}

/// One Mane companion's mastery state for the length of a run.
class ManeMasteryState {
  // ── Twin Fang ──
  /// Seconds left on the Predator Step window opened by a basic kill.
  double predatorStepTimer = 0;

  /// Basic casts still empowered by Blade Dance.
  int bladeDanceCasts = 0;

  // ── War Rhythm ──
  /// Scheduled attacks since the last ring.
  int castsSinceRing = 0;

  int rhythm = 0;

  /// Basic casts still empowered by Crescendo.
  int crescendoCasts = 0;

  double encoreTimer = 0;

  /// Seconds of Encore already bought with kills, against
  /// [ManeTuning.encoreMaxExtension].
  double encoreExtensionUsed = 0;

  /// Handoff between the two halves of launching a cast. The shape pass
  /// decides whether this cast is empowered and spends the counter; the cast
  /// itself does not exist until after that, so the tag has to be carried the
  /// few lines between them. Consuming a counter and then re-reading it to
  /// decide the tag is how a one-cast Crescendo ends up tagging nothing.
  bool pendingCrescendoCast = false;
  bool pendingBladeDanceCast = false;

  /// The share of the pending cast's damage owed to mastery, carried across
  /// the same gap for the same reason.
  double pendingMasteryDamageFraction = 0;

  /// Basic casts launched and not yet judged hit-or-miss, oldest first.
  /// Bounded: a Mane cannot outrun [ManeTuning.missGrace] by more than a
  /// handful of casts even at full Encore haste.
  final List<int> pendingCasts = [];

  bool get encoreActive => encoreTimer > 0;

  /// Banks a Rhythm from a clean pair. Returns true if one was actually
  /// gained, so the caller can react to reaching the cap.
  bool gainRhythm() {
    if (rhythm >= ManeTuning.maxRhythm) return false;
    rhythm++;
    return true;
  }

  /// Spends a Rhythm for a cast that landed nothing.
  void loseRhythm() {
    if (rhythm > 0) rhythm--;
  }

  /// Spends the whole reserve for Crescendo and reports what it was worth.
  int consumeRhythm() {
    final spent = rhythm;
    rhythm = 0;
    return spent;
  }

  /// Opens an Encore, but only if one is not already running: the capstone
  /// says kills extend the current window and that it cannot otherwise
  /// refresh itself.
  bool tryOpenEncore() {
    if (encoreTimer > 0) return false;
    encoreTimer = ManeTuning.encoreDuration;
    encoreExtensionUsed = 0;
    return true;
  }

  /// A kill buys more Encore, up to the capstone's ceiling.
  void extendEncore() {
    if (encoreTimer <= 0) return;
    final room = ManeTuning.encoreMaxExtension - encoreExtensionUsed;
    if (room <= 0) return;
    final granted = room < ManeTuning.encoreKillExtension
        ? room
        : ManeTuning.encoreKillExtension;
    encoreTimer += granted;
    encoreExtensionUsed += granted;
  }

  void tick(double dt) {
    if (predatorStepTimer > 0) {
      predatorStepTimer -= dt;
      if (predatorStepTimer < 0) predatorStepTimer = 0;
    }
    if (encoreTimer > 0) {
      encoreTimer -= dt;
      if (encoreTimer <= 0) {
        encoreTimer = 0;
        encoreExtensionUsed = 0;
      }
    }
  }

  /// Basic attack cooldown multiplier from Rhythm and Encore. Below 1 is
  /// faster.
  double hasteMultiplier({
    required bool hasMeasuredCuts,
    required bool hasEncore,
  }) {
    var haste = 0.0;
    if (hasMeasuredCuts) haste += rhythm * ManeTuning.rhythmHastePerStack;
    if (hasEncore && encoreActive) haste += ManeTuning.encoreHaste;
    if (haste <= 0) return 1.0;
    // A multiplier rather than a subtraction so stacked haste approaches a
    // floor instead of reaching zero cooldown.
    return 1.0 / (1.0 + haste);
  }

  @override
  String toString() =>
      'ManeMasteryState(rhythm: $rhythm, crescendo: $crescendoCasts, '
      'encore: ${encoreTimer.toStringAsFixed(1)}, '
      'bladeDance: $bladeDanceCasts, ring: $castsSinceRing)';
}

/// How the equipped path reshapes one basic cast's pair of slashes.
///
/// Pure: the game hands in what it knows about the companion and gets back
/// geometry and multipliers. Every number that decides what a Mane basic looks
/// like is resolved in one place rather than spread across the combat loop.
class ManeBasicShape {
  const ManeBasicShape({
    required this.slashFraction,
    required this.spread,
    required this.widthScale,
    required this.damageMultiplier,
    required this.homingStrength,
  });

  /// Physical-attack fraction per slash, before [damageMultiplier].
  final double slashFraction;

  /// Radians off the aim for each blade.
  final double spread;

  /// Collision and visual width multiplier.
  final double widthScale;

  /// Everything multiplicative on top: Rhythm, Crescendo, Predator Step.
  final double damageMultiplier;

  /// Above zero, the slashes track their target (Predator Step).
  final double homingStrength;

  bool get homes => homingStrength > 0;

  /// The chassis, untouched. What a Mane with no path equipped throws.
  static const base = ManeBasicShape(
    slashFraction: ManeTuning.baseSlashFraction,
    spread: ManeTuning.baseSpread,
    widthScale: 1.0,
    damageMultiplier: 1.0,
    homingStrength: 0,
  );
}

/// Resolves the shape of the next Mane basic cast.
///
/// [hasNode] answers whether a node is purchased and equipped for this
/// companion; [state] carries the run's accumulated Rhythm and windows.
ManeBasicShape resolveManeBasicShape({
  required bool Function(String nodeId) hasNode,
  required ManeMasteryState state,
  required bool crescendoEmpowered,
}) {
  var slashFraction = ManeTuning.baseSlashFraction;
  var spread = ManeTuning.baseSpread;
  var widthScale = 1.0;
  var damage = 1.0;
  var homing = 0.0;

  // Twin Fang re-cuts the chassis into a tighter, harder pair.
  if (hasNode(ManeNodes.honedPair)) {
    slashFraction = ManeTuning.honedPairSlashFraction;
    spread *= ManeTuning.honedPairSpreadScale;
  }

  if (crescendoEmpowered) damage += ManeTuning.crescendoDamageBonus;

  if (hasNode(ManeNodes.encore) && state.encoreActive) {
    widthScale *= ManeTuning.encoreWidthScale;
  }

  if (hasNode(ManeNodes.predatorStep) && state.predatorStepTimer > 0) {
    damage += ManeTuning.predatorStepDamageBonus;
    homing = ManeTuning.predatorStepHoming;
  }

  return ManeBasicShape(
    slashFraction: slashFraction,
    spread: spread,
    widthScale: widthScale,
    damageMultiplier: damage,
    homingStrength: homing,
  );
}
