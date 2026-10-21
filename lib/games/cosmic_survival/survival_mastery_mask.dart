/// Mask's three mastery paths: the numbers, the per-companion state, and the
/// rules that do not need the game to evaluate.
///
/// Mask is the Traps family. Every element places at least one fixture that
/// persists and waits, and the element decides what the fixture does when
/// something touches it. The three paths are the three phases of one trap's
/// life:
///
/// * **Deathmask** is how traps get onto the field: every kill leaves one.
/// * **Rearm** is how often a trap goes off: it stops spending itself.
/// * **Contagion** is what happens after: what a trap catches carries it on.
///
/// Two constraints shaped all of it.
///
/// **Placement counts swing wildly by element** — Air scatters 3 to 25, Lava
/// and Fire 5 to 15, Crystal and Light 3 to 7, Earth 2 to 5, but Dark, Ice,
/// Lightning, Blood, Plant and Mud each place exactly one. A path keyed to
/// "your many traps" would be thin for six of seventeen, which is the trap
/// Horn's draft tree fell into. Nothing here counts fixtures.
///
/// **A Mask trap chain has already brought this game to its knees once** — a
/// chain doubled per frame until a single frame cost 2.2 seconds. Deathmask
/// spawns traps on kills, which is that bug waiting to happen, so the rule is
/// absolute and enforced by [MaskTuning.graveSourcesAreDartsOnly]: only a dart
/// kill may leave a grave. A trap's own kills never do. Dart kills are bounded
/// by attack speed; trap kills are not bounded by anything.
///
/// What is deliberately absent. The draft tree marked bodies (Pip banks Pins
/// and Let marks Sighted — claimed twice over), fired on an every-Nth-attack
/// cadence twice (Let, Pip and Mane already own four such nodes between them),
/// slowed enemies (Mask/Mud's own trap is the slow pool), had traps shoot
/// darts (Mask/Steam's own traps are the shooting geysers), lured enemies
/// (Kin's aggro shift, and Horn taunts on four elements) and granted attack
/// speed on a trigger (Mane's Rhythm and Encore). Its whole first path was
/// "pierce lines", which is Mane's identity — Mask's dart happens to pierce,
/// but a path built on that just makes Mask a worse Mane.
library;

/// Node ids, so the game never spells one out as a string literal.
class MaskNodes {
  const MaskNodes._();

  static const deathmaskPath = 'mask.deathmask';
  static const rearmPath = 'mask.rearm';
  static const contagionPath = 'mask.contagion';

  static const graveGoods = 'mask.deathmask.grave_goods';
  static const openGrave = 'mask.deathmask.open_grave';
  static const coldGround = 'mask.deathmask.cold_ground';
  static const necropolis = 'mask.deathmask.necropolis';

  static const springAgain = 'mask.rearm.spring_again';
  static const hairTrigger = 'mask.rearm.hair_trigger';
  static const snapShut = 'mask.rearm.snap_shut';
  static const heldGround = 'mask.rearm.held_ground';

  static const carrier = 'mask.contagion.carrier';
  static const spread = 'mask.contagion.spread';
  static const virulence = 'mask.contagion.virulence';
  static const plague = 'mask.contagion.plague';
}

/// Cast tags, set when a Mask fixture is placed and read when it resolves.
class MaskCastTags {
  const MaskCastTags._();

  /// This fixture was left by a kill, not by the special. It may not leave
  /// another — the one place this whole family could recurse.
  static const grave = 'mask.grave';
}

/// Initial balance targets. Prototypes, expected to move once simulated.
class MaskTuning {
  const MaskTuning._();

  // ── Deathmask ──
  /// The rule that keeps this path from melting a frame. A grave may only be
  /// left by an auto-attack kill, never by a trap's own kill, because dart
  /// kills are bounded by attack speed and trap kills are bounded by nothing.
  static const bool graveSourcesAreDartsOnly = true;

  /// Grave Goods: what a kill leaves, relative to a placed fixture.
  static const double graveStrength = 0.35;

  /// Necropolis: unless the kill happened inside one of the Mask's own traps.
  static const double necropolisStrength = 1.0;

  /// Open Grave: how much wider and longer-lived a grave is.
  static const double openGraveScale = 1.40;
  static const double openGraveLife = 1.50;

  /// Graves alive at once, per Mask. A ceiling the spawner cannot exceed
  /// however fast the kills come.
  static const int graveCap = 12;

  /// And no more than one grave per this many seconds.
  static const double graveProcCooldown = 0.35;

  // ── Rearm ──
  /// Spring Again, then Hair Trigger: how long a spent trap takes to re-arm.
  static const double rearmDelay = 2.5;
  static const double hairTriggerDelay = 1.2;

  /// What a re-armed trap comes back for under Spring Again alone. Hair
  /// Trigger brings it back for the life it was placed with instead.
  static const double rearmLife = 6.0;

  /// Held Ground: a trap that has gone off this many times stops expiring.
  static const int heldGroundTriggers = 3;

  // ── Contagion ──
  //
  // Capped 2026-10-20. A Contagion Mask of any element took 63-84% of its
  // party's damage at Potential 80 (69% on average, every other family's
  // path bought too); the spec: "cap it so a Contagion Mask lands near
  // 30-35% of party damage". Nothing held it: every carrier infected every
  // body within reach each second, a body infected that same frame passed
  // it on in that frame, and a fresh carrier never took its generation
  // (CosmicSurvivalEnemy.applyMaskInfection read the clock it had just
  // set), so the three-generation ceiling never applied and one trap
  // contact took the whole lane. Now a carrier passes it to at most
  // [spreadPerCarrier] bodies a second, a second after it caught it, the
  // generations hold, and one Mask's carriers are counted ([carrierCap]).
  // With those holding, the strengths are the path's own again, and a
  // Contagion Mask measures about 30% at Potential 80.

  /// Carrier: how long an enemy that escapes a trap stays infected.
  static const double infectionDuration = 6.0;

  /// Spread: an infected body infects its neighbours this often, this close.
  static const double spreadInterval = 1.0;
  static const double spreadRadius = 110.0;

  /// And no more than this many of them a spread.
  static const int spreadPerCarrier = 5;

  /// Infection can only ever be this many generations from a trap, so a
  /// crowd cannot sustain it forever after the traps are gone. (Three
  /// before 2026-10-20, when the ceiling never applied; four with it.)
  static const int maxGenerations = 4;

  /// The most bodies one Mask's infection holds at once, about a sixth of a
  /// late horde wave's field. A body already carrying it can be re-infected
  /// (its clock refreshes); a new one waits for a carrier to die or recover.
  ///
  /// 320 until the 2026-10-21 mastery sweep, with [plagueRadius] 130: alone,
  /// with no other family's path bought, a Contagion Mask took 40% of its
  /// party's damage at Potential 50 (23% without it); the 2026-10-20 cap
  /// had been read with every family's path on. Virulence and Plague each
  /// added about eight points, and cutting their damage by a third moved
  /// neither: what they touch is chaff that dies to any of it. Plague's
  /// burst is the real spread — it infects everything it reaches, past
  /// [spreadPerCarrier] — so how far it reaches, and how many bodies one
  /// Mask's infection may hold, are what its share grows with.
  static const int carrierCap = 160;

  /// Virulence: what an infection eats from its carrier, as a share of the
  /// Mask's ability attack a second (half of it each half second).
  static const double virulenceStrength = 0.45;

  /// Plague: what an infected body's death burst does, and how far it
  /// reaches ([carrierCap]; 130 until 2026-10-21).
  static const double plagueDamage = 0.60;
  static const double plagueRadius = 90.0;
}

/// One Mask companion's mastery state for the length of a run.
class MaskMasteryState {
  /// Graves currently on the field, so the cap can be enforced. Holds the
  /// identity of each placed fixture rather than the fixture itself.
  final Set<int> graves = {};

  /// Trigger counts per fixture, for Held Ground.
  final Map<int, int> triggers = {};

  /// The life each fixture was placed with, for Hair Trigger. Dropped with
  /// the fixture, and cleared outright if fixtures leave some other way and
  /// it ever grows past what one Mask can have on the field.
  final Map<int, double> placedLives = {};

  void notePlacedLife(int fixtureId, double life) {
    if (placedLives.length >= 96) placedLives.clear();
    placedLives[fixtureId] = life;
  }

  double placedLifeOf(int fixtureId) => placedLives[fixtureId] ?? 0;

  /// Bodies carrying this Mask's infection: counted afresh each frame, and
  /// raised as new bodies catch it in between, so it never reads low.
  int carriers = 0;

  /// Whether one more body may catch the infection ([MaskTuning.carrierCap]).
  bool get canInfectAnother => carriers < MaskTuning.carrierCap;

  int triggersOn(int fixtureId) => triggers[fixtureId] ?? 0;

  /// Counts a trigger and reports whether that fixture has now earned the
  /// right to stop expiring.
  bool noteTrigger(int fixtureId, {required bool hasHeldGround}) {
    final next = triggersOn(fixtureId) + 1;
    triggers[fixtureId] = next;
    return hasHeldGround && next >= MaskTuning.heldGroundTriggers;
  }

  /// Records a placed grave. Returns false when the cap is already reached,
  /// which is the spawner's signal to place nothing.
  bool addGrave(int fixtureId) {
    if (graves.length >= MaskTuning.graveCap) return false;
    return graves.add(fixtureId);
  }

  void dropFixture(int fixtureId) {
    graves.remove(fixtureId);
    triggers.remove(fixtureId);
    placedLives.remove(fixtureId);
  }

  @override
  String toString() =>
      'MaskMasteryState(graves: ${graves.length}, '
      'tracked: ${triggers.length})';
}

/// What a kill leaves behind, as a share of an ordinary placed fixture.
///
/// Returns zero when the path is not held, when the kill did not come from a
/// dart, or when the Mask is already holding as many graves as it may.
double maskGraveStrength({
  required bool Function(String nodeId) hasNode,
  required bool fromAutoAttack,
  required bool insideOwnTrap,
  required int gravesAlive,
}) {
  if (!hasNode(MaskNodes.graveGoods)) return 0;
  // The rule that keeps a trap chain from doubling per frame.
  if (MaskTuning.graveSourcesAreDartsOnly && !fromAutoAttack) return 0;
  if (gravesAlive >= MaskTuning.graveCap) return 0;
  if (insideOwnTrap && hasNode(MaskNodes.necropolis)) {
    return MaskTuning.necropolisStrength;
  }
  return MaskTuning.graveStrength;
}

/// How much wider and longer-lived a grave is than the bare placement.
({double scale, double life}) maskGraveShape({
  required bool Function(String nodeId) hasNode,
}) {
  if (!hasNode(MaskNodes.openGrave)) return (scale: 1.0, life: 1.0);
  return (
    scale: MaskTuning.openGraveScale,
    life: MaskTuning.openGraveLife,
  );
}

/// How long a spent fixture takes to re-arm. Zero means it is spent for good,
/// which is what a trap does without this path.
double maskRearmDelay({required bool Function(String nodeId) hasNode}) {
  if (!hasNode(MaskNodes.springAgain)) return 0;
  return hasNode(MaskNodes.hairTrigger)
      ? MaskTuning.hairTriggerDelay
      : MaskTuning.rearmDelay;
}

/// What an infection does when it lands, and whether it may jump again.
///
/// [generation] counts how far this body is from the trap that started it, so
/// a dense crowd cannot keep an infection alive indefinitely once the traps
/// that seeded it are gone.
({double duration, bool spreads, bool ticks, bool bursts}) maskInfection({
  required bool Function(String nodeId) hasNode,
  required int generation,
}) {
  if (!hasNode(MaskNodes.carrier)) {
    return (duration: 0, spreads: false, ticks: false, bursts: false);
  }
  return (
    duration: MaskTuning.infectionDuration,
    spreads:
        hasNode(MaskNodes.spread) && generation < MaskTuning.maxGenerations,
    ticks: hasNode(MaskNodes.virulence),
    bursts: hasNode(MaskNodes.plague),
  );
}

/// The share of a hit's damage that mastery is responsible for, given the
/// bonus it added on top of the base.
double maskUpliftFraction(double base, double bonus) {
  final total = base + bonus;
  if (total <= 0 || bonus <= 0) return 0;
  return bonus / total;
}
