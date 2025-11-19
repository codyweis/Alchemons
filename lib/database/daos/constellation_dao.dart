// lib/database/daos/constellation_dao.dart
import 'package:drift/drift.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/schema_tables.dart';

part 'constellation_dao.g.dart';

@DriftAccessor(
  tables: [
    BreedingStatistics,
    ConstellationUnlocks,
    ConstellationPoints,
    ConstellationTransactions,
  ],
)
class ConstellationDao extends DatabaseAccessor<AlchemonsDatabase>
    with _$ConstellationDaoMixin {
  ConstellationDao(super.db);

  // ==================== BREEDING STATISTICS ====================

  /// Get breeding stats for a specific species
  Future<BreedingStatistic?> getBreedingStats(String speciesId) async {
    return await (select(
      breedingStatistics,
    )..where((t) => t.speciesId.equals(speciesId))).getSingleOrNull();
  }

  /// Get all breeding statistics
  Future<List<BreedingStatistic>> getAllBreedingStats() async {
    return await select(breedingStatistics).get();
  }

  /// Watch breeding stats for a species (for UI updates)
  Stream<BreedingStatistic?> watchBreedingStats(String speciesId) {
    return (select(
      breedingStatistics,
    )..where((t) => t.speciesId.equals(speciesId))).watchSingleOrNull();
  }

  /// Increment the breed count for a species
  /// Returns the new count and whether a milestone was reached
  Future<({int newCount, bool milestoneReached})> incrementBreedCount(
    String speciesId,
  ) async {
    final existing = await getBreedingStats(speciesId);

    if (existing == null) {
      // First time breeding this species
      await into(breedingStatistics).insert(
        BreedingStatisticsCompanion(
          speciesId: Value(speciesId),
          totalBred: const Value(1),
          lastBredAtUtc: Value(DateTime.now().toUtc()),
        ),
      );
      return (newCount: 1, milestoneReached: false);
    } else {
      final newCount = existing.totalBred + 1;
      await (update(
        breedingStatistics,
      )..where((t) => t.speciesId.equals(speciesId))).write(
        BreedingStatisticsCompanion(
          totalBred: Value(newCount),
          lastBredAtUtc: Value(DateTime.now().toUtc()),
        ),
      );

      // Check if we just hit a milestone
      final milestoneReached =
          _isMilestoneCount(newCount) &&
          existing.lastMilestoneAwarded < _getMilestoneNumber(newCount);

      return (newCount: newCount, milestoneReached: milestoneReached);
    }
  }

  /// Mark that a milestone has been awarded
  Future<void> markMilestoneAwarded(
    String speciesId,
    int milestoneNumber,
  ) async {
    await (update(
      breedingStatistics,
    )..where((t) => t.speciesId.equals(speciesId))).write(
      BreedingStatisticsCompanion(lastMilestoneAwarded: Value(milestoneNumber)),
    );
  }

  bool _isMilestoneCount(int count) {
    // Matches BreedingMilestone.milestones counts
    return const [10, 25, 50, 100, 250, 500].contains(count);
  }

  int _getMilestoneNumber(int count) {
    const milestones = [10, 25, 50, 100, 250, 500];
    return milestones.indexOf(count) + 1;
  }

  // ==================== CONSTELLATION UNLOCKS ====================

  /// Get all unlocked skills
  Future<List<ConstellationUnlock>> getUnlockedSkills() async {
    return await select(constellationUnlocks).get();
  }

  /// Get unlocked skill IDs as a Set for quick lookup
  Future<Set<String>> getUnlockedSkillIds() async {
    final unlocks = await getUnlockedSkills();
    return unlocks.map((u) => u.skillId).toSet();
  }

  /// Check if a specific skill is unlocked
  Future<bool> isSkillUnlocked(String skillId) async {
    final unlock = await (select(
      constellationUnlocks,
    )..where((t) => t.skillId.equals(skillId))).getSingleOrNull();
    return unlock != null;
  }

  /// Watch unlocked skills (for reactive UI)
  Stream<Set<String>> watchUnlockedSkillIds() {
    return select(
      constellationUnlocks,
    ).watch().map((unlocks) => unlocks.map((u) => u.skillId).toSet());
  }

  /// Unlock a skill
  Future<void> unlockSkill(String skillId, int pointsCost) async {
    await into(constellationUnlocks).insert(
      ConstellationUnlocksCompanion(
        skillId: Value(skillId),
        unlockedAtUtc: Value(DateTime.now().toUtc()),
        pointsCost: Value(pointsCost),
      ),
    );
  }

  // ==================== CONSTELLATION POINTS ====================

  /// Get current point balance
  Future<int> getPointBalance() async {
    final row = await (select(constellationPoints)..limit(1)).getSingleOrNull();
    return row?.currentBalance ?? 0;
  }

  /// Watch point balance (for UI)
  Stream<int> watchPointBalance() {
    return (select(
      constellationPoints,
    )..limit(1)).watchSingleOrNull().map((row) => row?.currentBalance ?? 0);
  }

  /// Get detailed point info
  Future<({int balance, int totalEarned, int totalSpent})>
  getPointInfo() async {
    final row = await (select(constellationPoints)..limit(1)).getSingleOrNull();
    if (row == null) {
      // Initialize if doesn't exist
      await _initializePoints();
      return (balance: 0, totalEarned: 0, totalSpent: 0);
    }
    return (
      balance: row.currentBalance,
      totalEarned: row.totalEarned,
      totalSpent: row.totalSpent,
    );
  }

  /// Add points (from breeding milestones, etc.)
  Future<void> addPoints({
    required int amount,
    required String transactionType,
    String? sourceId,
    String? description,
  }) async {
    final current = await (select(
      constellationPoints,
    )..limit(1)).getSingleOrNull();

    if (current == null) {
      await _initializePoints();
      return addPoints(
        amount: amount,
        transactionType: transactionType,
        sourceId: sourceId,
        description: description,
      );
    }

    final newBalance = current.currentBalance + amount;
    final newEarned = current.totalEarned + amount;

    await (update(
      constellationPoints,
    )..where((t) => t.id.equals(current.id))).write(
      ConstellationPointsCompanion(
        currentBalance: Value(newBalance),
        totalEarned: Value(newEarned),
        lastUpdatedUtc: Value(DateTime.now().toUtc()),
      ),
    );

    // Log transaction
    await _logTransaction(
      transactionType: transactionType,
      amount: amount,
      sourceId: sourceId,
      description: description,
    );
  }

  /// Spend points (unlock skill)
  Future<bool> spendPoints({
    required int amount,
    required String skillId,
    String? description,
  }) async {
    final current = await (select(
      constellationPoints,
    )..limit(1)).getSingleOrNull();

    if (current == null || current.currentBalance < amount) {
      return false; // Not enough points
    }

    final newBalance = current.currentBalance - amount;
    final newSpent = current.totalSpent + amount;

    await (update(
      constellationPoints,
    )..where((t) => t.id.equals(current.id))).write(
      ConstellationPointsCompanion(
        currentBalance: Value(newBalance),
        totalSpent: Value(newSpent),
        lastUpdatedUtc: Value(DateTime.now().toUtc()),
      ),
    );

    // Log transaction
    await _logTransaction(
      transactionType: 'spent_skill',
      amount: -amount,
      sourceId: skillId,
      description: description ?? 'Unlocked skill: $skillId',
    );

    return true;
  }

  Future<void> _initializePoints() async {
    await into(constellationPoints).insert(
      ConstellationPointsCompanion(
        currentBalance: const Value(0),
        totalEarned: const Value(0),
        totalSpent: const Value(0),
        hasSeenFinale: const Value(false),
        lastUpdatedUtc: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // ==================== TRANSACTIONS (optional logging) ====================

  Future<void> _logTransaction({
    required String transactionType,
    required int amount,
    String? sourceId,
    String? description,
  }) async {
    await into(constellationTransactions).insert(
      ConstellationTransactionsCompanion(
        transactionType: Value(transactionType),
        amount: Value(amount),
        sourceId: Value(sourceId),
        description: Value(description ?? ''),
        createdAtUtc: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Get recent transactions (for debugging or history screen)
  Future<List<ConstellationTransaction>> getRecentTransactions({
    int limit = 20,
  }) async {
    return await (select(constellationTransactions)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAtUtc)])
          ..limit(limit))
        .get();
  }

  // ==================== FINALE STATE ====================

  /// Check if the user has seen the finale animation
  Future<bool> hasSeenFinale() async {
    final row = await (select(constellationPoints)..limit(1)).getSingleOrNull();
    return row?.hasSeenFinale ?? false;
  }

  /// Mark the finale as seen
  Future<void> markFinaleAsSeen() async {
    final current = await (select(
      constellationPoints,
    )..limit(1)).getSingleOrNull();

    if (current == null) {
      await _initializePoints();
      return markFinaleAsSeen();
    }

    await (update(
      constellationPoints,
    )..where((t) => t.id.equals(current.id))).write(
      ConstellationPointsCompanion(
        hasSeenFinale: const Value(true),
        lastUpdatedUtc: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
