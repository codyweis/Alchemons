/// Combat event foundation for Survival Family Mastery (design doc phase 2).
///
/// Mastery nodes react to things that happen in combat: a cast goes out, both
/// blades land on one body, a basic kills, a special fires. Survival had no
/// vocabulary for any of that — projectiles knew their source slot and nothing
/// else, and "a cast" was not a thing that existed once the projectiles left
/// the companion. This file gives the runtime that vocabulary before a single
/// node is implemented, so the 96 nodes of phases 3-5 hook into one accounted,
/// guarded, budgeted surface instead of each reaching into the combat loop.
///
/// Four rules the whole system depends on:
///
/// * **A cast is one scheduled attack, not one projectile.** A Mane pair, a Pip
///   volley and a Wing pair each increment cast counters once. Without this a
///   multishot family triggers every cast-based node three times as often.
/// * **A payload cannot trigger a payload.** Everything mastery spawns runs
///   inside [SurvivalMasteryRuntime.runGuarded], which refuses to nest.
/// * **Procs are rate limited by key, not by hope.** A node that fires "once
///   per target per second" says so and the runtime enforces it.
/// * **Mastery has an object budget.** Survival's projectile pool is a fixed
///   220; mastery spawning into it without a ceiling is the trap-chain bug
///   again, one system over.
///
/// Nothing here touches Flame or the game. The runtime is a plain object the
/// game owns, which makes the accounting rules testable on their own.
library;

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';

/// What produced a piece of damage, for attribution. Telemetry that cannot
/// separate these cannot answer the only question balance actually asks: did
/// the path earn its 20-35%, or is the creature just strong?
enum MasteryDamageSource {
  /// The family's ordinary autoattack.
  basic,

  /// The family x element special ability.
  special,

  /// Anything a mastery node created: payloads, extra projectiles, aftershocks.
  mastery,

  /// Ship weapons, orb turrets, contact damage, run perks.
  other,
}

enum MasteryCastKind { basic, special }

/// One scheduled attack, tracked from launch until [kCastLifetime] has passed.
///
/// The per-target hit counts are what make "dual hit" and "full volley hit"
/// answerable. They are capped: a cast that somehow touches more than
/// [_maxTrackedTargets] bodies stops recording rather than growing a map
/// inside the combat loop.
class MasteryCast {
  MasteryCast({
    required this.id,
    required this.slotIndex,
    required this.family,
    required this.element,
    required this.kind,
    required this.projectileCount,
    required this.castTime,
    this.maxHitsPerTarget = 0,
  });

  static const int _maxTrackedTargets = 12;

  final int id;
  final int slotIndex;
  final CreatureFamily? family;
  final String element;
  final MasteryCastKind kind;

  /// Eligible projectiles launched by this cast. A full volley hit means this
  /// many of them reached one body.
  final int projectileCount;

  /// Runtime clock seconds at launch.
  final double castTime;

  /// How many of this cast's projectiles may hit one body, 0 for no limit.
  /// A ring of eight radial slashes converging on one enemy is the case this
  /// exists for; the veto happens before damage, in [SurvivalMasteryRuntime
  /// .allowsHit], because a cap counted afterwards is not a cap.
  final int maxHitsPerTarget;

  /// Node markers set at cast time and read at hit time — "this cast was
  /// empowered". Lazily created so an ordinary cast allocates nothing.
  Set<String>? _tags;

  void tag(String tag) => (_tags ??= <String>{}).add(tag);

  bool hasTag(String tag) => _tags?.contains(tag) ?? false;

  /// Hits recorded per target id ([identityHashCode] of the enemy or boss).
  final Map<int, int> _hitsByTarget = {};

  /// When each target was first struck by this cast, for the dual-hit window.
  final Map<int, double> _firstHitTime = {};

  /// Targets this cast has already fired a payload on, so a node that says
  /// "once per target" needs no separate bookkeeping.
  final Set<int> payloadedTargets = {};

  int totalHits = 0;

  /// Distinct bodies this cast has touched.
  int get targetsHit => _hitsByTarget.length;

  int hitsOn(int targetId) => _hitsByTarget[targetId] ?? 0;

  /// Records a hit and reports the resulting per-target count. Returns 0 once
  /// the target cap is reached, which reads as "not tracked" to every caller.
  int recordHit(int targetId, double now) {
    totalHits++;
    final existing = _hitsByTarget[targetId];
    if (existing == null) {
      if (_hitsByTarget.length >= _maxTrackedTargets) return 0;
      _hitsByTarget[targetId] = 1;
      _firstHitTime[targetId] = now;
      return 1;
    }
    final next = existing + 1;
    _hitsByTarget[targetId] = next;
    return next;
  }

  /// Two projectiles from this cast landed on one body inside the dual-hit
  /// window. The window is measured from the first hit, not between hits, so a
  /// slow trickle of pierces onto one body never counts as a pair.
  bool isDualHitOn(int targetId, double now) {
    final hits = _hitsByTarget[targetId] ?? 0;
    if (hits < 2) return false;
    final first = _firstHitTime[targetId];
    if (first == null) return false;
    return now - first <= kDualHitWindow;
  }

  /// Every eligible projectile from this cast reached one body.
  bool isFullVolleyHitOn(int targetId) {
    if (projectileCount <= 0) return false;
    return (_hitsByTarget[targetId] ?? 0) >= projectileCount;
  }
}

/// Two projectiles from one cast hitting the same body within this many
/// seconds is a "dual hit" (design doc, "Cast accounting").
const double kDualHitWindow = 0.35;

/// The sentinel target id for a claim that covers a whole cast rather than
/// one body. Negative so it can never be a real [identityHashCode].
const int kCastWideClaim = -1;

/// How long a cast stays answerable. Long enough for a Mane slash to fly out,
/// pierce and return; short enough that the live-cast map stays small.
const double kCastLifetime = 4.0;

/// Per-slot combat attribution. Balance reads these; nothing in combat does.
class MasterySlotTelemetry {
  double basicDamage = 0;
  double specialDamage = 0;
  double masteryDamage = 0;
  double healing = 0;
  double shielding = 0;

  /// Seconds of control (slow, root, stagger, chill, haze) this slot applied,
  /// summed across targets. Uptime, not wall time — 3 bodies slowed for 1s is 3.
  double controlSeconds = 0;

  int basicCasts = 0;
  int specialCasts = 0;
  int payloadApplications = 0;
  int specialAmplifications = 0;
  int capstoneActivations = 0;

  double get totalDamage => basicDamage + specialDamage + masteryDamage;

  /// Share of this slot's damage that mastery is responsible for. The headline
  /// number for "did the path do anything".
  double get masteryShare => totalDamage <= 0 ? 0 : masteryDamage / totalDamage;

  Map<String, Object> toJson() => {
    'basicDamage': basicDamage,
    'specialDamage': specialDamage,
    'masteryDamage': masteryDamage,
    'healing': healing,
    'shielding': shielding,
    'controlSeconds': controlSeconds,
    'basicCasts': basicCasts,
    'specialCasts': specialCasts,
    'payloadApplications': payloadApplications,
    'specialAmplifications': specialAmplifications,
    'capstoneActivations': capstoneActivations,
  };
}

/// The event surface mastery nodes are written against.
///
/// The game owns one of these. Every method is cheap and safe to call from the
/// combat loop; when no party member has a path equipped, [enabled] is false
/// and the hot ones return immediately without allocating.
class SurvivalMasteryRuntime {
  SurvivalMasteryRuntime({
    SurvivalFamilyMasterySnapshot? snapshot,
    this.masteryObjectsPerSecond = 60.0,
    this.masteryObjectBurst = 30,
  }) {
    applySnapshot(snapshot ?? SurvivalFamilyMasterySnapshot.empty);
    _objectBudget = masteryObjectBurst.toDouble();
  }

  /// Ceiling on how many objects (projectiles, zones, placements) mastery may
  /// create per second across the whole party, and how many it may create in
  /// one burst. Survival's companion pool is 220 entries; mastery gets a
  /// refilling slice of it, never an open tap.
  final double masteryObjectsPerSecond;
  final int masteryObjectBurst;

  SurvivalFamilyMasterySnapshot _snapshot = SurvivalFamilyMasterySnapshot.empty;

  /// Fast per-slot node lookup, rebuilt only when the snapshot changes.
  final Map<int, Set<String>> _activeNodesBySlot = {};

  bool _enabled = false;

  /// False when nothing in the party has a path equipped. The combat loop
  /// checks this before doing any mastery work at all.
  bool get enabled => _enabled;

  SurvivalFamilyMasterySnapshot get snapshot => _snapshot;

  double _clock = 0;
  double get clock => _clock;

  int _nextCastId = 1;
  final Map<int, MasteryCast> _casts = {};
  double _pruneTimer = 0;

  /// Proc cooldowns keyed by a hash of (slot, effect, target). Hashing rather
  /// than composing a string keeps the hit path allocation-free.
  final Map<int, double> _procReadyAt = {};

  int _guardDepth = 0;
  double _objectBudget = 0;

  final Map<int, MasterySlotTelemetry> _telemetry = {};

  // ── Configuration ────────────────────────────────────────────────

  void applySnapshot(SurvivalFamilyMasterySnapshot snapshot) {
    _snapshot = snapshot;
    _activeNodesBySlot.clear();
    for (final entry in snapshot.bySlot.entries) {
      _activeNodesBySlot[entry.key] = entry.value.activeNodeIds;
    }
    _enabled = _activeNodesBySlot.values.any((nodes) => nodes.isNotEmpty);
  }

  EquippedFamilyMastery? equippedFor(int slotIndex) =>
      _snapshot.forSlot(slotIndex);

  /// Whether the companion in [slotIndex] has purchased and equipped [nodeId].
  /// The one question every node implementation asks first.
  bool hasNode(int slotIndex, String nodeId) {
    if (!_enabled) return false;
    return _activeNodesBySlot[slotIndex]?.contains(nodeId) ?? false;
  }

  /// Whether the slot has any node at or below [tier] on its equipped path.
  /// Cheap gate for code that only needs "is this path running at all".
  bool hasPath(int slotIndex, String pathId) {
    if (!_enabled) return false;
    return _snapshot.forSlot(slotIndex)?.pathId == pathId;
  }

  // ── Clock and housekeeping ───────────────────────────────────────

  /// Advances the runtime clock, refills the object budget and prunes expired
  /// casts. Called once per frame from the game's update, before combat.
  void tick(double dt) {
    if (dt <= 0) return;
    _clock += dt;
    _objectBudget = (_objectBudget + masteryObjectsPerSecond * dt).clamp(
      0.0,
      masteryObjectBurst.toDouble(),
    );
    if (!_enabled) return;

    _pruneTimer -= dt;
    if (_pruneTimer <= 0) {
      _pruneTimer = 1.0;
      _pruneExpired();
    }
  }

  void _pruneExpired() {
    if (_casts.isNotEmpty) {
      final cutoff = _clock - kCastLifetime;
      _casts.removeWhere((_, cast) => cast.castTime < cutoff);
    }
    if (_procReadyAt.isNotEmpty) {
      _procReadyAt.removeWhere((_, readyAt) => readyAt <= _clock);
    }
  }

  /// Drops all per-run state. Called when a run starts so a second run in the
  /// same session never inherits the first one's rhythm.
  void reset() {
    _clock = 0;
    _nextCastId = 1;
    _casts.clear();
    _procReadyAt.clear();
    _telemetry.clear();
    _guardDepth = 0;
    _objectBudget = masteryObjectBurst.toDouble();
    _pruneTimer = 0;
  }

  // ── Cast lifecycle ───────────────────────────────────────────────

  /// Opens a cast and returns its id. Stamp that id onto every projectile the
  /// cast produces; hits then attribute themselves.
  ///
  /// Returns 0 — the "no cast" id — when mastery is off, so callers can stamp
  /// unconditionally without branching.
  int beginCast({
    required int slotIndex,
    required CreatureFamily? family,
    required String element,
    required MasteryCastKind kind,
    required int projectileCount,
    int maxHitsPerTarget = 0,
    bool countsAsCast = true,
  }) {
    final stats = _statsFor(slotIndex);
    // A mastery-created cast (a capstone's extra ring) is tracked so its hits
    // account, but it is not another scheduled attack and must not inflate
    // the cast counts balance reads.
    if (countsAsCast) {
      if (kind == MasteryCastKind.basic) {
        stats.basicCasts++;
      } else {
        stats.specialCasts++;
      }
    }
    if (!_enabled) return 0;

    // A party spamming casts must not grow this map without bound between
    // prunes; the oldest entries are the least useful, so drop them early.
    if (_casts.length >= 96) _pruneExpired();

    final id = _nextCastId++;
    _casts[id] = MasteryCast(
      id: id,
      slotIndex: slotIndex,
      family: family,
      element: element,
      kind: kind,
      projectileCount: projectileCount,
      castTime: _clock,
      maxHitsPerTarget: maxHitsPerTarget,
    );
    return id;
  }

  MasteryCast? cast(int castId) => castId == 0 ? null : _casts[castId];

  /// The per-target hit cap, checked *before* damage is applied. Returns true
  /// for anything untracked or uncapped, so the combat loop can ask about
  /// every projectile without branching first.
  bool allowsHit(int castId, int targetId) {
    if (!_enabled || castId == 0) return true;
    final cast = _casts[castId];
    if (cast == null || cast.maxHitsPerTarget <= 0) return true;
    return cast.hitsOn(targetId) < cast.maxHitsPerTarget;
  }

  /// Records one projectile from [castId] landing on [targetId] and returns
  /// the resulting hit description, or null when there is nothing to react to.
  MasteryHit? recordHit({
    required int castId,
    required int targetId,
    required double damage,
    bool isBoss = false,
  }) {
    if (!_enabled || castId == 0) return null;
    final cast = _casts[castId];
    if (cast == null) return null;

    final hitIndex = cast.recordHit(targetId, _clock);
    if (hitIndex == 0) return null;
    return MasteryHit(
      cast: cast,
      targetId: targetId,
      damage: damage,
      isBoss: isBoss,
      hitIndexOnTarget: hitIndex,
      isFirstHitOnTarget: hitIndex == 1,
      isDualHit: cast.isDualHitOn(targetId, _clock),
      isFullVolleyHit: cast.isFullVolleyHitOn(targetId),
    );
  }

  /// Marks a cast as having fired its payload on [targetId]. Returns false if
  /// it already had — the "once per target" rule, enforced in one place.
  bool claimPayloadTarget(int castId, int targetId) {
    if (!_enabled || castId == 0) return false;
    final cast = _casts[castId];
    if (cast == null) return false;
    return cast.payloadedTargets.add(targetId);
  }

  /// The "once per cast, whatever it hit" version, for nodes worded as one
  /// payload per cast rather than one per body. [kCastWideClaim] can never
  /// collide with a real target because [identityHashCode] is never negative.
  bool claimCastOnce(int castId) => claimPayloadTarget(castId, kCastWideClaim);

  // ── Proc cooldowns ───────────────────────────────────────────────

  /// Whether [effectId] may fire for [slotIndex] right now, and claims it if
  /// so. [targetId] scopes the cooldown to one body; omit it for a
  /// source-wide rate limit.
  ///
  /// This is the only rate limiter nodes should use. A node that rolls its own
  /// timer field is a node that will be missed when the budget is audited.
  bool tryProc(
    int slotIndex,
    String effectId,
    double cooldownSeconds, {
    int targetId = 0,
  }) {
    if (!_enabled) return false;
    if (cooldownSeconds <= 0) return true;
    final key = Object.hash(slotIndex, effectId, targetId);
    final readyAt = _procReadyAt[key];
    if (readyAt != null && readyAt > _clock) return false;
    _procReadyAt[key] = _clock + cooldownSeconds;
    return true;
  }

  /// Seconds until [effectId] can fire again, 0 when it is ready.
  double procRemaining(int slotIndex, String effectId, {int targetId = 0}) {
    final readyAt = _procReadyAt[Object.hash(slotIndex, effectId, targetId)];
    if (readyAt == null) return 0;
    final remaining = readyAt - _clock;
    return remaining <= 0 ? 0 : remaining;
  }

  // ── Recursion guard ──────────────────────────────────────────────

  /// True while mastery-generated combat is resolving. Anything that checks
  /// this and finds it true must not start more mastery work.
  bool get isResolvingMastery => _guardDepth > 0;

  /// Runs [body] as mastery-generated combat, refusing to nest.
  ///
  /// This is what makes "a payload cannot recursively trigger another payload"
  /// true by construction instead of by 96 nodes each remembering. A payload
  /// that kills an enemy, whose kill effect would fire another payload, finds
  /// the guard closed and returns [orElse].
  T runGuarded<T>(T Function() body, {required T orElse}) {
    if (_guardDepth > 0) return orElse;
    _guardDepth++;
    try {
      return body();
    } finally {
      _guardDepth--;
    }
  }

  // ── Object budget ────────────────────────────────────────────────

  /// Claims [count] object slots for mastery, or refuses. Callers must not
  /// spawn anything when this returns false.
  ///
  /// Survival's pool is finite and shared with every ability in the game. A
  /// mastery node that spawns unconditionally is one balance pass away from
  /// starving the family specials of projectile slots.
  bool requestObjects(int count) {
    if (count <= 0) return true;
    if (_objectBudget < count) return false;
    _objectBudget -= count;
    return true;
  }

  double get objectBudgetRemaining => _objectBudget;

  // ── Telemetry ────────────────────────────────────────────────────

  MasterySlotTelemetry _statsFor(int slotIndex) =>
      _telemetry.putIfAbsent(slotIndex, MasterySlotTelemetry.new);

  MasterySlotTelemetry telemetryFor(int slotIndex) => _statsFor(slotIndex);

  Map<int, MasterySlotTelemetry> get telemetry => Map.unmodifiable(_telemetry);

  void recordDamage(int? slotIndex, double amount, MasteryDamageSource source) {
    if (slotIndex == null || amount <= 0) return;
    final stats = _statsFor(slotIndex);
    switch (source) {
      case MasteryDamageSource.basic:
        stats.basicDamage += amount;
      case MasteryDamageSource.special:
        stats.specialDamage += amount;
      case MasteryDamageSource.mastery:
        stats.masteryDamage += amount;
      case MasteryDamageSource.other:
        break;
    }
  }

  void recordHealing(int? slotIndex, double amount) {
    if (slotIndex == null || amount <= 0) return;
    _statsFor(slotIndex).healing += amount;
  }

  void recordShielding(int? slotIndex, double amount) {
    if (slotIndex == null || amount <= 0) return;
    _statsFor(slotIndex).shielding += amount;
  }

  void recordControl(int? slotIndex, double seconds) {
    if (slotIndex == null || seconds <= 0) return;
    _statsFor(slotIndex).controlSeconds += seconds;
  }

  void recordPayload(int? slotIndex, {int count = 1}) {
    if (slotIndex == null || count <= 0) return;
    _statsFor(slotIndex).payloadApplications += count;
  }

  void recordSpecialAmplification(int? slotIndex) {
    if (slotIndex == null) return;
    _statsFor(slotIndex).specialAmplifications++;
  }

  void recordCapstone(int? slotIndex) {
    if (slotIndex == null) return;
    _statsFor(slotIndex).capstoneActivations++;
  }

  /// A flat report for the run summary and balance tooling.
  Map<String, Object> telemetryReport() => {
    for (final entry in _telemetry.entries)
      'slot${entry.key}': entry.value.toJson(),
  };
}

/// One projectile from one cast landing on one body, with the cast-level
/// questions already answered.
class MasteryHit {
  const MasteryHit({
    required this.cast,
    required this.targetId,
    required this.damage,
    required this.isBoss,
    required this.hitIndexOnTarget,
    required this.isFirstHitOnTarget,
    required this.isDualHit,
    required this.isFullVolleyHit,
  });

  final MasteryCast cast;
  final int targetId;
  final double damage;
  final bool isBoss;

  /// 1 for the first projectile of this cast to reach this body, 2 for the
  /// second, and so on.
  final int hitIndexOnTarget;

  final bool isFirstHitOnTarget;

  /// Two projectiles from this cast reached this body inside [kDualHitWindow].
  final bool isDualHit;

  /// Every eligible projectile from this cast reached this body.
  final bool isFullVolleyHit;

  int get slotIndex => cast.slotIndex;
  String get element => cast.element;
  CreatureFamily? get family => cast.family;
  bool get fromBasic => cast.kind == MasteryCastKind.basic;
  bool get fromSpecial => cast.kind == MasteryCastKind.special;
}

/// One body dying, attributed to the cast that killed it.
class MasteryKill {
  const MasteryKill({
    required this.slotIndex,
    required this.targetId,
    required this.cast,
    required this.isBoss,
    required this.source,
  });

  final int? slotIndex;
  final int targetId;

  /// Null when the killing blow was not part of a tracked cast — a burn tick,
  /// the ship, a trap laid three seconds ago.
  final MasteryCast? cast;

  final bool isBoss;
  final MasteryDamageSource source;

  bool get fromBasic => cast?.kind == MasteryCastKind.basic;
  bool get fromSpecial => cast?.kind == MasteryCastKind.special;
}
