// lib/games/cosmic/works.dart
//
// THE WORKS — Alchemons at work for the home base, in flight or not.
//
//   Extractor      built at a planet the ship has found. A miner of that
//                  planet's element fills its hopper; the ship sends the
//                  hopper home when it calls, or (tier 2) a courier flies it
//                  home on its own.
//   Scavenger Bay  beside home. Scavengers fly out and come back with
//                  elements from the planets the ship has found, now and
//                  then a few astral shards; their finds wait in crates.
//   Silver Press   beside home. Presses whatever storage holds over the
//                  reserve into silver.
//   Armory         beside home. The ship's workshop: its weapons, systems,
//                  ammo, home stations and upgrades are made here, and the
//                  Armory's tier sets how far each upgrade can go.
//   Refinery       beside home. Makes one element out of two others, by the
//                  recipe table (constants/element_combos.dart), for the
//                  recipes the Codex has found. It always makes less than it
//                  takes: 2 in, 1 out, better with tiers, never past even.
//
// Home buildings stand in berths round the home, never on it: Tiny 2 …
// Huge 6 by the largest size unlocked (homeBerthsForTier).
//
// Jobs read the stats the player already sees, one formula each, so the
// panel can print exactly what an Alchemon would do before it is put there:
//
//   miner      the Biome Extractors' harvest rate (computeHarvestRatePerMinute)
//   courier    Speed → flight speed, Strength → load per trip
//   scavenger  Speed → trip length, Strength → find size, Intelligence →
//              how often a find carries astral shards
//   presser    Beauty → grains pressed a minute (an eye for what is worth
//              keeping)
//   refiner    Intelligence → elements refined a minute
//
// Everything here is plain data and arithmetic on wall-clock milliseconds:
// [advanceWorks] brings the state up to now, whether that is a second later
// or the next morning. Nothing is simulated per frame; what is drawn in
// space is read off the same clocks (see works_art.dart).

import 'dart:convert';
import 'dart:math';

import 'package:alchemons/constants/element_combos.dart';

// ── job maths ───────────────────────────────────────────────────────────────

abstract final class WorkRules {
  // Courier.
  /// World units a second (the ship cruises at 400).
  static double courierSpeed(double speed) => 40 + 12 * speed.clamp(0.0, 20.0);
  static int courierLoad(double strength) =>
      (10 + 5 * strength.clamp(0.0, 20.0)).round();

  /// Time spent at each end of a run, loading and unloading.
  static const int courierDockMs = 4000;
  static const int minCourierCycleMs = 20000;

  /// A courier's whole run: pick up, fly home, unload, fly back.
  static int courierCycleMs(double distance, double speed) => max(
    minCourierCycleMs,
    (2 * distance / courierSpeed(speed) * 1000).round() + 2 * courierDockMs,
  );

  // Scavenger.
  static int scavengerTripMs(double speed) =>
      (240000 / (0.5 + speed.clamp(0.0, 20.0) / 6)).round().clamp(
        60000,
        600000,
      );
  static int scavengerFind(double strength) =>
      (8 + 4 * strength.clamp(0.0, 20.0)).round();
  static double scavengerShardOdds(double intelligence) {
    final i = intelligence.clamp(0.0, 20.0);
    return i / (i + 6);
  }

  // Press.
  static double pressRate(double beauty, int tier) =>
      (4 + 2 * beauty.clamp(0.0, 20.0)) * pressTierMultiplier(tier);
  static double pressTierMultiplier(int tier) => switch (tier) {
    <= 1 => 1.0,
    2 => 1.6,
    _ => 2.5,
  };
  static const int grainsPerSilver = 2;

  // Refiner.
  /// Elements a minute it takes in, half of each.
  static double refineRate(double intelligence) =>
      6 + 3 * intelligence.clamp(0.0, 20.0);

  /// What comes out for each element that goes in, by tier: 2 in, 1 out at
  /// first, better with tiers, never more out than in — the press would
  /// turn anything better into silver from nothing.
  static double refineYield(int tier) => switch (tier) {
    <= 1 => 0.5,
    2 => 0.6,
    _ => 2 / 3,
  };

  /// How much of each input it leaves alone, as the press's choices.
  static const int defaultRefineKeep = 50;

  /// Recipes the Refinery never offers. Dust + Spirit → Crystal has no
  /// breeding pair, so the Codex can never record it (Crystal still comes
  /// from Earth + Lightning).
  static const Set<String> refineExcluded = {'Dust+Spirit'};

  // Armory.
  /// How far AMMO POWER and MISSILE POWER (five levels) may go at an
  /// Armory of [tier].
  static int armoryPowerCap(int tier) => switch (tier) {
    <= 0 => 0,
    1 => 2,
    2 => 4,
    _ => 5,
  };

  /// How far the FUEL TANK and the CARGO HOLD (three levels) may go.
  static int armoryTankCap(int tier) => tier.clamp(0, 3);

  /// The Refinery's recipes: pair key (as in kElementCombos) → what it makes.
  static final Map<String, String> refineRecipes = {
    for (final e in kElementCombos.entries)
      if (!refineExcluded.contains(e.key)) e.key: e.value,
  };

  /// The reserves a press can be set to keep, per element.
  static const List<int> pressReserves = [0, 50, 100, 200, 500, 1000];
  static const int defaultPressReserve = 200;

  // Buildings.
  static const int maxTier = 3;

  static int hopperCap(int tier) => switch (tier) {
    <= 1 => 120,
    2 => 300,
    _ => 600,
  };
  static int minerSlots(int tier) => tier >= 3 ? 2 : 1;
  static bool hasCourier(int tier) => tier >= 2;

  static int scavengerSlots(int tier) => tier.clamp(0, 3);
  static int crateCap(int tier) => switch (tier) {
    <= 0 => 0,
    1 => 6,
    2 => 12,
    _ => 20,
  };

  /// What the hold must carry to build an extractor at a planet of
  /// [element]: its own matter, gathered right there.
  static const int extractorBuildUnits = 50;

  /// Longest stretch caught up in one go. A longer absence is caught up as
  /// this much; hoppers and crates are long full by then anyway.
  static const int maxCatchUpMs = 72 * 3600 * 1000;
}

// ── costs ───────────────────────────────────────────────────────────────────

/// What a building or an upgrade takes from home storage and the wallet.
class WorksCost {
  const WorksCost({this.elements = const {}, this.matter = 0, this.silver = 0});

  /// Named elements.
  final Map<String, int> elements;

  /// Elements of any kind, taken from the largest stocks first (see
  /// [planMatter]) after [elements] are set aside.
  final int matter;
  final int silver;

  bool get isFree => elements.isEmpty && matter <= 0 && silver <= 0;
}

/// The cost of building [b] (tier 1), or raising it to [toTier], for a
/// planet of [element] when it is an extractor.
WorksCost worksCost(WorksBuilding b, int toTier, {String? element}) {
  switch (b) {
    case WorksBuilding.extractor:
      final e = element ?? 'Earth';
      return switch (toTier) {
        <= 1 => WorksCost(elements: {e: WorkRules.extractorBuildUnits}),
        2 => WorksCost(elements: {e: 150}, silver: 300),
        _ => WorksCost(elements: {e: 300}, silver: 800),
      };
    case WorksBuilding.scavengerBay:
      return switch (toTier) {
        <= 1 => const WorksCost(matter: 100, silver: 200),
        2 => const WorksCost(matter: 250, silver: 600),
        _ => const WorksCost(matter: 500, silver: 1500),
      };
    case WorksBuilding.silverPress:
      return switch (toTier) {
        <= 1 => const WorksCost(matter: 150),
        2 => const WorksCost(matter: 400, silver: 300),
        _ => const WorksCost(matter: 900, silver: 900),
      };
    case WorksBuilding.refinery:
      return switch (toTier) {
        <= 1 => const WorksCost(matter: 150, silver: 300),
        2 => const WorksCost(matter: 400, silver: 800),
        _ => const WorksCost(matter: 900, silver: 1800),
      };
    // Cheap to start: the ship's upgrades wait on it.
    case WorksBuilding.armory:
      return switch (toTier) {
        <= 1 => const WorksCost(matter: 60),
        2 => const WorksCost(matter: 300, silver: 500),
        _ => const WorksCost(matter: 800, silver: 1500),
      };
  }
}

/// Which elements [matter] units of "any" would be taken from: the largest
/// stocks are drawn down first, toward a common level, so small stocks are
/// the last touched. [setAside] is held back first (a cost's named
/// elements). Null when storage cannot cover it.
Map<String, int>? planMatter(
  int matter,
  Map<String, double> stored, {
  Map<String, int> setAside = const {},
}) {
  if (matter <= 0) return const {};
  final left = <String, double>{
    for (final e in stored.entries)
      if (e.value - (setAside[e.key] ?? 0) >= 1)
        e.key: (e.value - (setAside[e.key] ?? 0)).floorToDouble(),
  };
  final total = left.values.fold(0.0, (s, v) => s + v);
  if (total + 1e-6 < matter) return null;

  // The water line: the level L where the stock above it is [matter].
  final levels = left.values.toList()..sort((a, b) => b.compareTo(a));
  var above = 0.0;
  var line = 0.0;
  for (var i = 0; i < levels.length; i++) {
    final next = i + 1 < levels.length ? levels[i + 1] : 0.0;
    final width = i + 1;
    final slab = (levels[i] - next) * width;
    if (above + slab >= matter) {
      line = levels[i] - (matter - above) / width;
      break;
    }
    above += slab;
  }
  final plan = <String, int>{};
  var placed = 0;
  final keys = left.keys.toList()..sort((a, b) => left[b]!.compareTo(left[a]!));
  for (final k in keys) {
    final take = (left[k]! - line).floor();
    if (take <= 0) continue;
    plan[k] = take;
    placed += take;
  }
  // Flooring leaves a few units; the largest stocks take them.
  var i = 0;
  while (placed < matter && keys.isNotEmpty) {
    final k = keys[i % keys.length];
    if ((plan[k] ?? 0) < left[k]!) {
      plan[k] = (plan[k] ?? 0) + 1;
      placed++;
    }
    i++;
    if (i > keys.length * (matter + 1)) break;
  }
  return placed >= matter ? plan : null;
}

/// Everything [cost] takes from storage, element by element, or null when
/// storage cannot cover it.
Map<String, int>? elementsForCost(WorksCost cost, Map<String, double> stored) {
  for (final e in cost.elements.entries) {
    if ((stored[e.key] ?? 0) + 1e-6 < e.value) return null;
  }
  final any = planMatter(cost.matter, stored, setAside: cost.elements);
  if (any == null) return null;
  final out = Map<String, int>.from(cost.elements);
  for (final e in any.entries) {
    out[e.key] = (out[e.key] ?? 0) + e.value;
  }
  return out;
}

// ── workers ─────────────────────────────────────────────────────────────────

enum WorksBuilding { extractor, scavengerBay, silverPress, refinery, armory }

enum WorkJob { miner, courier, scavenger, presser, refiner }

extension WorkJobX on WorkJob {
  String get label => switch (this) {
    WorkJob.miner => 'MINER',
    WorkJob.courier => 'COURIER',
    WorkJob.scavenger => 'SCAVENGER',
    WorkJob.presser => 'PRESSER',
    WorkJob.refiner => 'REFINER',
  };
}

/// What an Alchemon brings to a job.
class WorkerProfile {
  const WorkerProfile({
    required this.instanceId,
    required this.element,
    required this.speed,
    required this.intelligence,
    required this.strength,
    this.beauty = 3,
    required this.harvestRate,
  });

  final String instanceId;
  final String element;
  final double speed;
  final double intelligence;
  final double strength;
  final double beauty;

  /// Units a minute as a miner (the Biome Extractors' rate).
  final int harvestRate;
}

// ── state ───────────────────────────────────────────────────────────────────

class ExtractorState {
  ExtractorState({
    required this.element,
    required this.updatedMs,
    this.tier = 1,
    List<String?>? miners,
    this.courier,
    this.hopper = 0,
    this.cycleStartMs = 0,
    this.cycleMs = 0,
    this.cargo = 0,
    this.delivered = true,
  }) : miners =
           miners ?? List<String?>.filled(WorkRules.minerSlots(tier), null);

  /// The planet's element, which is also the extractor's name.
  final String element;
  int tier;
  List<String?> miners;
  String? courier;
  double hopper;
  int updatedMs;

  /// The courier's current run: picked up at [cycleStartMs], home at its
  /// middle, back at its end.
  int cycleStartMs;
  int cycleMs;
  double cargo;
  bool delivered;

  int get hopperCap => WorkRules.hopperCap(tier);
  bool get hopperFull => hopper >= hopperCap - 0.01;
  Iterable<String> get workerIds => [...miners.whereType<String>(), ?courier];

  /// Grow [miners] to the tier's slots, keeping who is there.
  void fitSlots() {
    final want = WorkRules.minerSlots(tier);
    while (miners.length < want) {
      miners.add(null);
    }
    if (miners.length > want) miners = miners.sublist(0, want);
    if (!WorkRules.hasCourier(tier)) courier = null;
  }

  Map<String, dynamic> toJson() => {
    'e': element,
    't': tier,
    'm': miners,
    'c': courier,
    'h': hopper,
    'u': updatedMs,
    'cs': cycleStartMs,
    'cm': cycleMs,
    'cg': cargo,
    'd': delivered,
  };

  factory ExtractorState.fromJson(Map<String, dynamic> j) {
    final x = ExtractorState(
      element: j['e'] as String,
      updatedMs: (j['u'] as num?)?.toInt() ?? 0,
      tier: ((j['t'] as num?)?.toInt() ?? 1).clamp(1, WorkRules.maxTier),
      miners: [for (final m in (j['m'] as List? ?? const [])) m as String?],
      courier: j['c'] as String?,
      hopper: (j['h'] as num?)?.toDouble() ?? 0,
      cycleStartMs: (j['cs'] as num?)?.toInt() ?? 0,
      cycleMs: (j['cm'] as num?)?.toInt() ?? 0,
      cargo: (j['cg'] as num?)?.toDouble() ?? 0,
      delivered: j['d'] as bool? ?? true,
    );
    x.fitSlots();
    return x;
  }
}

/// A scavenger's find, waiting in the bay.
class ScavengerFind {
  const ScavengerFind({required this.elements, this.shards = 0});
  final Map<String, int> elements;
  final int shards;

  int get units => elements.values.fold(0, (s, v) => s + v);

  Map<String, dynamic> toJson() => {'e': elements, 's': shards};
  factory ScavengerFind.fromJson(Map<String, dynamic> j) => ScavengerFind(
    elements: {
      for (final e in ((j['e'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    shards: (j['s'] as num?)?.toInt() ?? 0,
  );
}

class ScavengerSlot {
  ScavengerSlot({
    this.instanceId,
    this.tripStartMs = 0,
    this.tripMs = 0,
    this.trips = 0,
  });

  String? instanceId;

  /// When the trip out began; 0 while resting at the bay.
  int tripStartMs;
  int tripMs;

  /// Trips finished, which seeds the next find.
  int trips;

  bool get out => tripStartMs > 0;

  Map<String, dynamic> toJson() => {
    'i': instanceId,
    's': tripStartMs,
    'l': tripMs,
    'n': trips,
  };
  factory ScavengerSlot.fromJson(Map<String, dynamic> j) => ScavengerSlot(
    instanceId: j['i'] as String?,
    tripStartMs: (j['s'] as num?)?.toInt() ?? 0,
    tripMs: (j['l'] as num?)?.toInt() ?? 0,
    trips: (j['n'] as num?)?.toInt() ?? 0,
  );
}

class ScavengerBayState {
  ScavengerBayState({
    this.tier = 0,
    this.berth = -1,
    List<ScavengerSlot>? slots,
    List<ScavengerFind>? crates,
  }) : slots = slots ?? [],
       crates = crates ?? [] {
    fitSlots();
  }

  /// 0 = not built.
  int tier;

  /// Which berth round home it stands in.
  int berth;
  List<ScavengerSlot> slots;
  List<ScavengerFind> crates;

  bool get built => tier > 0;
  int get crateCap => WorkRules.crateCap(tier);
  int get out => slots.where((s) => s.out).length;
  Iterable<String> get workerIds =>
      slots.map((s) => s.instanceId).whereType<String>();

  void fitSlots() {
    final want = WorkRules.scavengerSlots(tier);
    while (slots.length < want) {
      slots.add(ScavengerSlot());
    }
    if (slots.length > want) slots = slots.sublist(0, want);
  }

  Map<String, dynamic> toJson() => {
    't': tier,
    'bh': berth,
    's': [for (final s in slots) s.toJson()],
    'c': [for (final c in crates) c.toJson()],
  };
  factory ScavengerBayState.fromJson(Map<String, dynamic> j) =>
      ScavengerBayState(
        tier: ((j['t'] as num?)?.toInt() ?? 0).clamp(0, WorkRules.maxTier),
        berth: (j['bh'] as num?)?.toInt() ?? -1,
        slots: [
          for (final s in (j['s'] as List? ?? const []))
            ScavengerSlot.fromJson((s as Map).cast<String, dynamic>()),
        ],
        crates: [
          for (final c in (j['c'] as List? ?? const []))
            ScavengerFind.fromJson((c as Map).cast<String, dynamic>()),
        ],
      );
}

class SilverPressState {
  SilverPressState({
    this.tier = 0,
    this.berth = -1,
    this.presser,
    this.reserve = WorkRules.defaultPressReserve,
    this.updatedMs = 0,
    this.carry = 0,
    this.pressedSilver = 0,
  });

  /// 0 = not built.
  int tier;

  /// Which berth round home it stands in.
  int berth;
  String? presser;

  /// How much of each element it leaves alone.
  int reserve;
  int updatedMs;

  /// Grains pressed toward the next silver.
  double carry;

  /// Silver pressed since it was built.
  int pressedSilver;

  bool get built => tier > 0;

  Map<String, dynamic> toJson() => {
    't': tier,
    'bh': berth,
    'p': presser,
    'r': reserve,
    'u': updatedMs,
    'c': carry,
    'n': pressedSilver,
  };
  factory SilverPressState.fromJson(Map<String, dynamic> j) => SilverPressState(
    tier: ((j['t'] as num?)?.toInt() ?? 0).clamp(0, WorkRules.maxTier),
    berth: (j['bh'] as num?)?.toInt() ?? -1,
    presser: j['p'] as String?,
    reserve: (j['r'] as num?)?.toInt() ?? WorkRules.defaultPressReserve,
    updatedMs: (j['u'] as num?)?.toInt() ?? 0,
    carry: (j['c'] as num?)?.toDouble() ?? 0,
    pressedSilver: (j['n'] as num?)?.toInt() ?? 0,
  );
}

class RefineryState {
  RefineryState({
    this.tier = 0,
    this.berth = -1,
    this.refiner,
    this.recipe,
    this.keep = WorkRules.defaultRefineKeep,
    this.updatedMs = 0,
    this.made = 0,
  });

  /// 0 = not built.
  int tier;

  /// Which berth round home it stands in.
  int berth;
  String? refiner;

  /// The pair it is making from, as kElementCombos keys it ('Fire+Water'),
  /// or null with nothing chosen.
  String? recipe;

  /// How much of each input it leaves alone.
  int keep;
  int updatedMs;

  /// Elements made since it was built.
  double made;

  bool get built => tier > 0;

  /// The recipe's two inputs and its output, or null.
  (String, String, String)? get parts {
    final r = recipe;
    final out = r == null ? null : WorkRules.refineRecipes[r];
    if (r == null || out == null) return null;
    final ab = r.split('+');
    return (ab[0], ab[1], out);
  }

  Map<String, dynamic> toJson() => {
    't': tier,
    'bh': berth,
    'w': refiner,
    'r': recipe,
    'k': keep,
    'u': updatedMs,
    'm': made,
  };
  factory RefineryState.fromJson(Map<String, dynamic> j) => RefineryState(
    tier: ((j['t'] as num?)?.toInt() ?? 0).clamp(0, WorkRules.maxTier),
    berth: (j['bh'] as num?)?.toInt() ?? -1,
    refiner: j['w'] as String?,
    recipe: j['r'] as String?,
    keep: (j['k'] as num?)?.toInt() ?? WorkRules.defaultRefineKeep,
    updatedMs: (j['u'] as num?)?.toInt() ?? 0,
    made: (j['m'] as num?)?.toDouble() ?? 0,
  );
}

/// The ship's workshop. No one works it: what it holds is the ship's own
/// upgrades, made from storage and shards as they always were.
class ArmoryState {
  ArmoryState({this.tier = 0, this.berth = -1});

  /// 0 = not built.
  int tier;

  /// Which berth round home it stands in.
  int berth;

  bool get built => tier > 0;

  Map<String, dynamic> toJson() => {'t': tier, 'bh': berth};
  factory ArmoryState.fromJson(Map<String, dynamic> j) => ArmoryState(
    tier: ((j['t'] as num?)?.toInt() ?? 0).clamp(0, WorkRules.maxTier),
    berth: (j['bh'] as num?)?.toInt() ?? -1,
  );
}

class WorksState {
  WorksState({
    Map<String, ExtractorState>? extractors,
    ScavengerBayState? bay,
    SilverPressState? press,
    RefineryState? refinery,
    ArmoryState? armory,
  }) : extractors = extractors ?? {},
       bay = bay ?? ScavengerBayState(),
       press = press ?? SilverPressState(),
       refinery = refinery ?? RefineryState(),
       armory = armory ?? ArmoryState() {
    fitBerths();
  }

  final Map<String, ExtractorState> extractors;
  final ScavengerBayState bay;
  final SilverPressState press;
  final RefineryState refinery;
  final ArmoryState armory;

  bool get isEmpty =>
      extractors.isEmpty &&
      !bay.built &&
      !press.built &&
      !refinery.built &&
      !armory.built;

  /// Every Alchemon at work, whatever its job.
  Set<String> get workerIds => {
    for (final x in extractors.values) ...x.workerIds,
    ...bay.workerIds,
    ?press.presser,
    ?refinery.refiner,
  };

  // ── berths ──

  /// The berths the home buildings stand in, built ones only.
  Map<WorksBuilding, int> get berths => {
    if (bay.built) WorksBuilding.scavengerBay: bay.berth,
    if (press.built) WorksBuilding.silverPress: press.berth,
    if (refinery.built) WorksBuilding.refinery: refinery.berth,
    if (armory.built) WorksBuilding.armory: armory.berth,
  };

  int get berthsUsed => berths.length;

  /// The first berth free among [count], or null when all are taken.
  int? freeBerth(int count) {
    final taken = berths.values.toSet();
    for (var i = 0; i < count; i++) {
      if (!taken.contains(i)) return i;
    }
    return null;
  }

  void setBerth(WorksBuilding b, int berth) {
    switch (b) {
      case WorksBuilding.scavengerBay:
        bay.berth = berth;
      case WorksBuilding.silverPress:
        press.berth = berth;
      case WorksBuilding.refinery:
        refinery.berth = berth;
      case WorksBuilding.armory:
        armory.berth = berth;
      case WorksBuilding.extractor:
        break;
    }
  }

  /// The tier [b] is built to at home (0 = not built).
  int homeTier(WorksBuilding b) => switch (b) {
    WorksBuilding.scavengerBay => bay.tier,
    WorksBuilding.silverPress => press.tier,
    WorksBuilding.refinery => refinery.tier,
    WorksBuilding.armory => armory.tier,
    WorksBuilding.extractor => 0,
  };

  /// Takes [b] down, freeing its berth: its workers leave their jobs and
  /// it starts again from nothing. The bay's crates must be emptied first.
  void dismantle(WorksBuilding b) {
    switch (b) {
      case WorksBuilding.scavengerBay:
        for (final id in bay.workerIds.toList()) {
          release(id);
        }
        bay
          ..tier = 0
          ..berth = -1
          ..crates.clear()
          ..fitSlots();
      case WorksBuilding.silverPress:
        press
          ..tier = 0
          ..berth = -1
          ..presser = null;
      case WorksBuilding.refinery:
        refinery
          ..tier = 0
          ..berth = -1
          ..refiner = null
          ..recipe = null;
      case WorksBuilding.armory:
        armory
          ..tier = 0
          ..berth = -1;
      case WorksBuilding.extractor:
        break;
    }
  }

  /// Gives every built home building a berth of its own (one built before
  /// berths existed, or two that claim the same one).
  void fitBerths() {
    final seen = <int>{};
    for (final b in const [
      WorksBuilding.armory,
      WorksBuilding.scavengerBay,
      WorksBuilding.silverPress,
      WorksBuilding.refinery,
    ]) {
      final at = berths[b];
      if (at == null) continue;
      if (at >= 0 && seen.add(at)) continue;
      var i = 0;
      while (seen.contains(i) || (berths.values.contains(i) && i != at)) {
        i++;
      }
      setBerth(b, i);
      seen.add(i);
    }
  }

  /// The job [instanceId] is doing, and where, or null.
  (WorkJob, String?)? jobOf(String instanceId) {
    for (final x in extractors.values) {
      if (x.miners.contains(instanceId)) return (WorkJob.miner, x.element);
      if (x.courier == instanceId) return (WorkJob.courier, x.element);
    }
    if (bay.workerIds.contains(instanceId)) return (WorkJob.scavenger, null);
    if (press.presser == instanceId) return (WorkJob.presser, null);
    if (refinery.refiner == instanceId) return (WorkJob.refiner, null);
    return null;
  }

  /// Takes [instanceId] off whatever job it has.
  void release(String instanceId) {
    for (final x in extractors.values) {
      for (var i = 0; i < x.miners.length; i++) {
        if (x.miners[i] == instanceId) x.miners[i] = null;
      }
      if (x.courier == instanceId) x.courier = null;
    }
    for (final s in bay.slots) {
      if (s.instanceId == instanceId) {
        s.instanceId = null;
        s.tripStartMs = 0;
      }
    }
    if (press.presser == instanceId) press.presser = null;
    if (refinery.refiner == instanceId) refinery.refiner = null;
  }

  String serialise() => jsonEncode({
    'v': 1,
    'x': [for (final x in extractors.values) x.toJson()],
    'b': bay.toJson(),
    'p': press.toJson(),
    'r': refinery.toJson(),
    'a': armory.toJson(),
  });

  factory WorksState.deserialise(String? raw) {
    if (raw == null || raw.isEmpty) return WorksState();
    try {
      final j = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final xs = <String, ExtractorState>{};
      for (final x in (j['x'] as List? ?? const [])) {
        final e = ExtractorState.fromJson((x as Map).cast<String, dynamic>());
        xs[e.element] = e;
      }
      return WorksState(
        extractors: xs,
        bay: j['b'] == null
            ? null
            : ScavengerBayState.fromJson(
                (j['b'] as Map).cast<String, dynamic>(),
              ),
        press: j['p'] == null
            ? null
            : SilverPressState.fromJson(
                (j['p'] as Map).cast<String, dynamic>(),
              ),
        refinery: j['r'] == null
            ? null
            : RefineryState.fromJson((j['r'] as Map).cast<String, dynamic>()),
        armory: j['a'] == null
            ? null
            : ArmoryState.fromJson((j['a'] as Map).cast<String, dynamic>()),
      );
    } catch (_) {
      return WorksState();
    }
  }
}

// ── the clock ───────────────────────────────────────────────────────────────

/// What the works did between two advances.
class WorksReport {
  final Map<String, double> delivered = {};
  final Map<String, double> refined = {};
  int silver = 0;
  int finds = 0;

  bool get isEmpty =>
      delivered.isEmpty && refined.isEmpty && silver == 0 && finds == 0;
  double get refinedUnits => refined.values.fold(0.0, (s, v) => s + v);
  double get deliveredUnits => delivered.values.fold(0.0, (s, v) => s + v);

  void deliver(String element, double units) {
    if (units <= 0) return;
    delivered[element] = (delivered[element] ?? 0) + units;
  }
}

/// A stable hash of [s] (String.hashCode is not promised to survive a run).
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final u in s.codeUnits) {
    h ^= u;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The find a scavenger brings back from trip number [trip]: one or two of
/// [elements], [units] in all, and with [shardOdds] some astral shards.
ScavengerFind rollFind({
  required String instanceId,
  required int trip,
  required int units,
  required double shardOdds,
  required List<String> elements,
}) {
  final rng = Random(stableHash(instanceId) ^ (trip * 7919 + 17));
  final kinds = elements.isEmpty ? const ['Earth'] : elements;
  final first = kinds[rng.nextInt(kinds.length)];
  final out = <String, int>{};
  if (kinds.length > 1 && rng.nextDouble() < 0.5) {
    var second = kinds[rng.nextInt(kinds.length)];
    if (second == first) {
      second = kinds[(kinds.indexOf(first) + 1) % kinds.length];
    }
    final a = (units * (0.55 + rng.nextDouble() * 0.25)).round();
    out[first] = a;
    if (units - a > 0) out[second] = units - a;
  } else {
    out[first] = units;
  }
  final shards = rng.nextDouble() < shardOdds ? 1 + rng.nextInt(3) : 0;
  return ScavengerFind(elements: out, shards: shards);
}

/// Brings [works] up to [nowMs]. Deliveries go into [storage] (home
/// storage, element → units) and silver into the report; finds go into the
/// bay's crates. [workers] has the profile of every Alchemon at work (one
/// missing is treated as off the job). [distanceHome] is how far an
/// extractor's planet is from home now; [scavengeElements] are the elements
/// a scavenger can bring back (the planets found).
WorksReport advanceWorks(
  WorksState works, {
  required int nowMs,
  required Map<String, double> storage,
  required Map<String, WorkerProfile> workers,
  required double Function(String element) distanceHome,
  required List<String> scavengeElements,
}) {
  final report = WorksReport();
  for (final x in works.extractors.values) {
    _advanceExtractor(
      x,
      nowMs,
      storage,
      workers,
      distanceHome(x.element),
      report,
    );
  }
  _advanceBay(works.bay, nowMs, workers, scavengeElements, report);
  _advanceRefinery(works.refinery, nowMs, storage, workers, report);
  _advancePress(works.press, nowMs, storage, workers, report);
  return report;
}

double minerRate(ExtractorState x, Map<String, WorkerProfile> workers) {
  var rate = 0.0;
  for (final id in x.miners) {
    final w = id == null ? null : workers[id];
    if (w != null) rate += w.harvestRate;
  }
  return rate;
}

void _advanceExtractor(
  ExtractorState x,
  int now,
  Map<String, double> storage,
  Map<String, WorkerProfile> workers,
  double distance,
  WorksReport report,
) {
  if (x.updatedMs <= 0 || x.updatedMs > now) x.updatedMs = now;
  if (now - x.updatedMs > WorkRules.maxCatchUpMs) {
    final skip = now - WorkRules.maxCatchUpMs - x.updatedMs;
    x.updatedMs += skip;
    if (x.cycleStartMs > 0) x.cycleStartMs += skip;
  }
  final rate = minerRate(x, workers);
  final cap = x.hopperCap.toDouble();
  var t = x.updatedMs;
  void fill(int until) {
    if (until <= t) return;
    x.hopper = min(cap, x.hopper + rate * (until - t) / 60000);
    t = until;
  }

  final courier = x.courier == null ? null : workers[x.courier];
  if (courier != null && WorkRules.hasCourier(x.tier)) {
    if (x.cycleStartMs <= 0 || x.cycleMs <= 0) {
      startCourierRun(x, courier, distance, t);
    }
    final load = WorkRules.courierLoad(courier.strength).toDouble();
    for (var guard = 0; guard < 50000; guard++) {
      final home = x.cycleStartMs + x.cycleMs ~/ 2;
      final back = x.cycleStartMs + x.cycleMs;
      if (!x.delivered && home <= now) {
        fill(home);
        storage[x.element] = (storage[x.element] ?? 0) + x.cargo;
        report.deliver(x.element, x.cargo);
        x.cargo = 0;
        x.delivered = true;
        continue;
      }
      if (back <= now) {
        fill(back);
        x.cycleStartMs = back;
        x.cycleMs = WorkRules.courierCycleMs(distance, courier.speed);
        final take = min(x.hopper, load);
        x.hopper -= take;
        x.cargo = take;
        x.delivered = take <= 0;
        continue;
      }
      break;
    }
  }
  fill(now);
  x.updatedMs = now;
}

/// Puts [courier] on its first run from [x] at [at]: it loads what the
/// hopper has and sets off.
void startCourierRun(
  ExtractorState x,
  WorkerProfile courier,
  double distance,
  int at,
) {
  x.cycleStartMs = at;
  x.cycleMs = WorkRules.courierCycleMs(distance, courier.speed);
  final take = min(
    x.hopper,
    WorkRules.courierLoad(courier.strength).toDouble(),
  );
  x.hopper -= take;
  x.cargo = take;
  x.delivered = take <= 0;
}

/// Ends [x]'s courier run where it stands: what it carries goes home.
void endCourierRun(ExtractorState x, Map<String, double> storage) {
  if (!x.delivered && x.cargo > 0) {
    storage[x.element] = (storage[x.element] ?? 0) + x.cargo;
  }
  x.cargo = 0;
  x.delivered = true;
  x.cycleStartMs = 0;
  x.cycleMs = 0;
}

void _advanceBay(
  ScavengerBayState bay,
  int now,
  Map<String, WorkerProfile> workers,
  List<String> elements,
  WorksReport report,
) {
  if (!bay.built) return;
  // A trip only sets out with a crate free for what it brings back, so a
  // scavenger is never out with nowhere to put its find.
  int room() => bay.crateCap - bay.crates.length - bay.out;
  for (var guard = 0; guard < 400; guard++) {
    // The next thing to happen: the earliest trip home.
    ScavengerSlot? next;
    for (final s in bay.slots) {
      if (!s.out) continue;
      if (s.instanceId == null || workers[s.instanceId] == null) {
        s.tripStartMs = 0;
        continue;
      }
      if (next == null ||
          s.tripStartMs + s.tripMs < next.tripStartMs + next.tripMs) {
        next = s;
      }
    }
    if (next != null && next.tripStartMs + next.tripMs <= now) {
      final w = workers[next.instanceId]!;
      final at = next.tripStartMs + next.tripMs;
      bay.crates.add(
        rollFind(
          instanceId: w.instanceId,
          trip: next.trips,
          units: WorkRules.scavengerFind(w.strength),
          shardOdds: WorkRules.scavengerShardOdds(w.intelligence),
          elements: elements,
        ),
      );
      report.finds++;
      next.trips++;
      next.tripStartMs = 0;
      // Straight back out if there is room for another find.
      if (room() > 0) {
        next.tripStartMs = at;
        next.tripMs = WorkRules.scavengerTripMs(w.speed);
      }
      continue;
    }
    break;
  }
  // Anyone resting sets out now if a crate is free.
  for (final s in bay.slots) {
    final w = s.instanceId == null ? null : workers[s.instanceId];
    if (w == null || s.out || room() <= 0) continue;
    s.tripStartMs = now;
    s.tripMs = WorkRules.scavengerTripMs(w.speed);
  }
}

void _advanceRefinery(
  RefineryState r,
  int now,
  Map<String, double> storage,
  Map<String, WorkerProfile> workers,
  WorksReport report,
) {
  if (r.updatedMs <= 0 || r.updatedMs > now) r.updatedMs = now;
  final from = max(r.updatedMs, now - WorkRules.maxCatchUpMs);
  r.updatedMs = now;
  final w = r.refiner == null ? null : workers[r.refiner];
  final parts = r.parts;
  if (!r.built || w == null || parts == null) return;
  final (a, b, out) = parts;
  final budget = WorkRules.refineRate(w.intelligence) * (now - from) / 60000;
  // Equal parts of each input, as far as both last over what it keeps.
  final spareA = (storage[a] ?? 0) - r.keep;
  final spareB = (storage[b] ?? 0) - r.keep;
  final each = min(budget / 2, min(spareA, spareB));
  if (each <= 0.0001) return;
  storage[a] = storage[a]! - each;
  storage[b] = storage[b]! - each;
  final made = 2 * each * WorkRules.refineYield(r.tier);
  storage[out] = (storage[out] ?? 0) + made;
  storage.removeWhere((_, v) => v <= 0.01);
  r.made += made;
  report.refined[out] = (report.refined[out] ?? 0) + made;
}

void _advancePress(
  SilverPressState press,
  int now,
  Map<String, double> storage,
  Map<String, WorkerProfile> workers,
  WorksReport report,
) {
  if (press.updatedMs <= 0 || press.updatedMs > now) press.updatedMs = now;
  final from = max(press.updatedMs, now - WorkRules.maxCatchUpMs);
  press.updatedMs = now;
  final w = press.presser == null ? null : workers[press.presser];
  if (!press.built || w == null) return;
  final budget =
      WorkRules.pressRate(w.beauty, press.tier) * (now - from) / 60000;
  if (budget <= 0) return;
  final surplus = <String, double>{
    for (final e in storage.entries)
      if (e.value - press.reserve > 0.01) e.key: e.value - press.reserve,
  };
  final total = surplus.values.fold(0.0, (s, v) => s + v);
  if (total <= 0) return;
  final share = min(1.0, budget / total);
  var pressed = 0.0;
  for (final e in surplus.entries) {
    final take = e.value * share;
    storage[e.key] = storage[e.key]! - take;
    pressed += take;
  }
  storage.removeWhere((_, v) => v <= 0.01);
  press.carry += pressed;
  final silver = press.carry ~/ WorkRules.grainsPerSilver;
  press.carry -= silver * WorkRules.grainsPerSilver;
  press.pressedSilver += silver;
  report.silver += silver;
}

/// Empties the bay's crates: their elements into [storage]; returns the
/// elements and the astral shards they held.
(Map<String, int>, int) collectCrates(
  ScavengerBayState bay,
  Map<String, double> storage, {
  required int nowMs,
  required Map<String, WorkerProfile> workers,
}) {
  final got = <String, int>{};
  var shards = 0;
  for (final c in bay.crates) {
    for (final e in c.elements.entries) {
      got[e.key] = (got[e.key] ?? 0) + e.value;
      storage[e.key] = (storage[e.key] ?? 0) + e.value;
    }
    shards += c.shards;
  }
  bay.crates.clear();
  // Room again: anyone resting sets out.
  for (final s in bay.slots) {
    final w = s.instanceId == null ? null : workers[s.instanceId];
    if (w == null || s.out) continue;
    if (bay.crateCap - bay.crates.length - bay.out <= 0) break;
    s.tripStartMs = nowMs;
    s.tripMs = WorkRules.scavengerTripMs(w.speed);
  }
  return (got, shards);
}
