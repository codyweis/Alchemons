import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/nature.dart';

/// Stamina model:
/// - Each instance has staminaBars / staminaMax / staminaLastUtcMs in DB
/// - Regenerates 1 bar every [regenPerBar] (default 6h)
/// - Breed costs 1 bar * nature multiplier (stochastic rounding).
/// - Wilderness drains all bars * nature multiplier (stochastic rounding).
class StaminaService {
  final AlchemonsDatabase db;
  final Duration regenPerBar;
  final Random _rng;

  StaminaService(
    this.db, {
    this.regenPerBar = const Duration(hours: 6),
    Random? rng,
  }) : _rng = rng ?? Random();

  // ---------- Public API ----------

  /// Returns the up-to-date row after applying regeneration.
  Future<CreatureInstance?> refreshAndGet(
    String instanceId, {
    DateTime? nowUtc,
  }) async {
    final row = await db.creatureDao.getInstance(instanceId);
    if (row == null) return null;
    final refreshed = _applyRegen(
      row,
      nowUtc: nowUtc ?? DateTime.now().toUtc(),
    );
    if (refreshed != null) {
      await db.creatureDao.updateStamina(
        instanceId: row.instanceId,
        staminaBars: refreshed.$1,
        staminaLastUtcMs: refreshed.$2,
      );
      return (await db.creatureDao.getInstance(instanceId));
    }
    return row;
  }

  /// Can this instance participate in breeding (>= 1 bar after regen)?
  Future<bool> canBreed(String instanceId, {DateTime? nowUtc}) async {
    final row = await refreshAndGet(instanceId, nowUtc: nowUtc);
    return (row?.staminaBars ?? 0) >= 1;
  }

  /// Spend stamina for breeding (default base cost = 1 bar).
  /// Returns updated row, or null if not enough stamina.
  Future<CreatureInstance?> spendForBreeding(
    String instanceId, {
    Creature?
    instanceOverlayForNature, // pass creature to read Nature, if handy
    int baseCostBars = 1,
    DateTime? nowUtc,
  }) async {
    final row = await refreshAndGet(instanceId, nowUtc: nowUtc);
    if (row == null) return null;

    final nature = _natureFromRowOrOverlay(row, instanceOverlayForNature);
    final mult = _natureNum(
      nature,
      'stamina_breeding_cost_mult',
      defaultVal: 1.0,
    );

    final charge = _stochasticCost(baseCostBars * mult);
    if (row.staminaBars < charge || charge <= 0) {
      // Not enough stamina (or weird zero/negative charge)
      return null;
    }

    final newBars = row.staminaBars - charge;
    final nowMs = (nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch;

    // Spending resets the regen anchor so next bar regens from now.
    await db.creatureDao.updateStamina(
      instanceId: row.instanceId,
      staminaBars: newBars,
      staminaLastUtcMs: nowMs,
    );

    return db.creatureDao.getInstance(instanceId);
  }

  /// Spend stamina for wilderness (default: drain to zero).
  /// You can tune [baseCostBars] if you want partial drains later.
  Future<CreatureInstance?> spendForWilderness(
    String instanceId, {
    Creature? instanceOverlayForNature,
    int? baseCostBars, // default = current bars (full drain)
    DateTime? nowUtc,
  }) async {
    final row = await refreshAndGet(instanceId, nowUtc: nowUtc);
    if (row == null) return null;

    final nature = _natureFromRowOrOverlay(row, instanceOverlayForNature);
    final mult = _natureNum(
      nature,
      'stamina_wilderness_drain_mult',
      defaultVal: 1.0,
    );

    final base = baseCostBars ?? row.staminaBars;
    final charge = _stochasticCost(base * mult).clamp(0, row.staminaBars);
    if (charge <= 0) return row; // Nothing to spend

    final newBars = row.staminaBars - charge;
    final nowMs = (nowUtc ?? DateTime.now().toUtc()).millisecondsSinceEpoch;

    await db.creatureDao.updateStamina(
      instanceId: row.instanceId,
      staminaBars: newBars,
      staminaLastUtcMs: nowMs,
    );

    return db.creatureDao.getInstance(instanceId);
  }

  // ---------- Internals ----------

  /// Applies time-based regeneration in-memory.
  (int, int)? _applyRegen(CreatureInstance row, {required DateTime nowUtc}) {
    // --- NEW: derive effective regen duration from nature ---
    final NatureDef? n = (row.natureId == null || row.natureId!.isEmpty)
        ? null
        : NatureCatalog.byId(row.natureId!);

    // clamp(0.25, 4.0): at most 4× slower, at least 4× faster
    final regenMult = (() {
      final v = n?.effect.modifiers['stamina_regen_mult'];
      final d = (v is num) ? v.toDouble() : 1.0; // <-- CORRECTED LINE
      return d.clamp(0.25, 4.0);
    })();

    final effectiveMsPerBar = (regenPerBar.inMilliseconds / regenMult)
        .clamp(60 * 1000, 365 * 24 * 3600 * 1000)
        .toInt();
    // --------------------------------------------------------

    final maxBars = effectiveMaxStamina(row);
    var bars = row.staminaBars;
    final lastMs = row.staminaLastUtcMs;
    final nowMs = nowUtc.millisecondsSinceEpoch;

    if (bars >= maxBars) {
      if (nowMs - lastMs > effectiveMsPerBar) {
        return (bars, nowMs); // keep anchor fresh at cap
      }
      return null;
    }

    final elapsedMs = nowMs - lastMs;
    if (elapsedMs < effectiveMsPerBar) return null;

    final ticks = elapsedMs ~/ effectiveMsPerBar;
    if (ticks <= 0) return null;

    final canRecover = maxBars - bars;
    final recovered = ticks > canRecover ? canRecover : ticks;
    if (recovered <= 0) return null;

    bars += recovered;

    var newLast = lastMs + recovered * effectiveMsPerBar;
    if (bars >= maxBars) newLast = nowMs;

    return (bars, newLast);
  }

  int effectiveMaxStamina(CreatureInstance row, {Creature? overlay}) {
    final base = row.staminaMax; // should be 3 in DB
    final nature = _natureFromRowOrOverlay(row, overlay);
    final bonus = _natureNum(nature, 'stamina_extra', defaultVal: 0.0);

    // We want +1.5 = sometimes +1, sometimes +2
    // Use stochastic rounding so expectation is right
    final extra = _stochasticCost(bonus);
    return base + extra;
  }

  /// Pulls nature from overlay Creature first (if provided), else from catalog by ID on row.
  NatureDef? _natureFromRowOrOverlay(CreatureInstance row, Creature? overlay) {
    if (overlay?.nature != null) return overlay!.nature;
    if (row.natureId == null || row.natureId!.isEmpty) return null;
    return NatureCatalog.byId(row.natureId!);
  }

  /// Reads a numeric nature modifier (returns [defaultVal] if missing).
  double _natureNum(NatureDef? n, String key, {double defaultVal = 1.0}) {
    final v = n?.effect.modifiers[key];
    return (v is num) ? v.toDouble() : defaultVal;
  }

  /// Converts a real-valued cost into an integer cost with correct expectation.
  /// Example: 0.85 → 0 with 15% refund chance after charging 1? No.
  /// We do *stochastic rounding* directly: floor + Bernoulli(frac).
  int _stochasticCost(double raw) {
    final r = raw.clamp(0.0, 9999.0);
    final floorPart = r.floor();
    final frac = r - floorPart;
    if (frac <= 0) return floorPart;
    return floorPart + (_rng.nextDouble() < frac ? 1 : 0);
  }
}

class StaminaState {
  final int bars;
  final int max;
  final DateTime? nextTickUtc;

  const StaminaState({required this.bars, required this.max, this.nextTickUtc});

  double get fill01 => max <= 0 ? 0.0 : bars / max;
  bool get atCap => bars >= max;
  bool get empty => bars <= 0;
}
