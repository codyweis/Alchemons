// lib/services/constellation_service.dart
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:alchemons/database/alchemons_db.dart';

class ConstellationService extends ChangeNotifier {
  final AlchemonsDatabase _db;

  ConstellationService(this._db) {
    _init();
  }

  Future<void> _init() async {
    // Watch for changes to automatically notify listeners
    _db.constellationDao.watchPointBalance().listen((_) {
      notifyListeners();
    });

    _db.constellationDao.watchUnlockedSkillIds().listen((_) {
      notifyListeners();
    });
  }

  // ==================== POINTS ====================

  /// Get current point balance
  Future<int> getPointBalance() async {
    return await _db.constellationDao.getPointBalance();
  }

  /// Watch point balance (reactive stream for UI)
  Stream<int> watchPointBalance() {
    return _db.constellationDao.watchPointBalance();
  }

  Stream<Set<String>> watchUnlockedSkillIds() {
    return _db.constellationDao.watchUnlockedSkillIds();
  }

  /// Get detailed point info
  Future<({int balance, int totalEarned, int totalSpent})>
  getPointInfo() async {
    return await _db.constellationDao.getPointInfo();
  }

  // ==================== SKILLS ====================

  /// Check if a skill is unlocked
  Future<bool> isSkillUnlocked(String skillId) async {
    return await _db.constellationDao.isSkillUnlocked(skillId);
  }

  /// Get all unlocked skill IDs
  Future<Set<String>> getUnlockedSkillIds() async {
    return await _db.constellationDao.getUnlockedSkillIds();
  }

  /// Check if a skill can be unlocked (prerequisites met + enough points)
  Future<bool> canUnlockSkill(String skillId) async {
    final skill = ConstellationCatalog.byId(skillId);
    if (skill == null) return false;

    // Already unlocked?
    if (await isSkillUnlocked(skillId)) return false;

    // Check prerequisites
    final unlocked = await getUnlockedSkillIds();
    if (!skill.canUnlock(unlocked)) return false;

    // Check points
    final balance = await getPointBalance();
    if (balance < skill.pointsCost) return false;

    return true;
  }

  /// Unlock a skill
  Future<bool> unlockSkill(String skillId) async {
    final skill = ConstellationCatalog.byId(skillId);
    if (skill == null) return false;

    // Verify can unlock
    if (!await canUnlockSkill(skillId)) return false;

    // Spend points
    final success = await _db.constellationDao.spendPoints(
      amount: skill.pointsCost,
      skillId: skillId,
      description: 'Unlocked: ${skill.name}',
    );

    if (!success) return false;

    // Record unlock
    await _db.constellationDao.unlockSkill(skillId, skill.pointsCost);

    debugPrint('✨ Unlocked constellation skill: ${skill.name}');
    notifyListeners();
    return true;
  }

  // ==================== BREEDING & MILESTONES ====================

  /// Increment breeding count for a species (call when breeding)
  /// Pass the rarity of the creature being bred for accurate point calculation
  Future<void> incrementBreedCount(
    String speciesId, {
    String rarity = 'common',
  }) async {
    final result = await _db.constellationDao.incrementBreedCount(speciesId);

    if (result.milestoneReached) {
      // Award points for milestone
      final milestoneNum = BreedingMilestone.milestoneNumber(result.newCount);
      if (milestoneNum > 0 &&
          milestoneNum <= BreedingMilestone.milestones.length) {
        final milestone = BreedingMilestone.milestones[milestoneNum - 1];

        // Calculate points based on rarity
        final pointsToAward = milestone.getPointsForRarity(rarity);

        await _db.constellationDao.addPoints(
          amount: pointsToAward,
          transactionType: 'earned_breeding',
          sourceId: speciesId,
          description:
              '$speciesId ($rarity): ${milestone.displayName} (${result.newCount} bred)',
        );

        await _db.constellationDao.markMilestoneAwarded(
          speciesId,
          milestoneNum,
        );

        debugPrint(
          '🎉 Milestone: $speciesId ($rarity) x${result.newCount} → +$pointsToAward points',
        );
        notifyListeners();
      }
    }
  }

  /// Get breeding progress for a species
  Future<BreedingProgress> getBreedingProgress(String speciesId) async {
    final stats = await _db.constellationDao.getBreedingStats(speciesId);

    final totalBred = stats?.totalBred ?? 0;
    final nextMilestone = BreedingMilestone.nextMilestone(totalBred);

    double progress = 0.0;
    if (nextMilestone != null && totalBred > 0) {
      // Find the previous milestone to calculate progress correctly
      final previousMilestone = _getPreviousMilestone(totalBred);
      final previousCount = previousMilestone?.count ?? 0;
      final range = nextMilestone.count - previousCount;
      final current = totalBred - previousCount;
      progress = current / range;
    } else if (nextMilestone == null && totalBred > 0) {
      progress = 1.0; // All milestones complete
    }

    return BreedingProgress(
      speciesId: speciesId,
      totalBred: totalBred,
      nextMilestone: nextMilestone,
      progress: progress,
    );
  }

  BreedingMilestone? _getPreviousMilestone(int currentCount) {
    BreedingMilestone? previous;
    for (final milestone in BreedingMilestone.milestones) {
      if (milestone.count > currentCount) break;
      previous = milestone;
    }
    return previous;
  }

  /// Get all breeding statistics
  Future<List<BreedingStatistic>> getAllBreedingStats() async {
    return await _db.constellationDao.getAllBreedingStats();
  }

  // ==================== FINALE STATE ====================

  /// Check if the user has already seen the finale animation
  Future<bool> hasSeenFinale() async {
    return await _db.constellationDao.hasSeenFinale();
  }

  /// Mark the finale as seen (after playing the animation)
  Future<void> markFinaleAsSeen() async {
    await _db.constellationDao.markFinaleAsSeen();
    debugPrint('🎬 Finale marked as seen');
    notifyListeners();
  }

  // ==================== RETROACTIVE CALCULATION ====================

  /// Calculate and award points for existing bred creatures (run once on migration)
  Future<void> calculateRetroactivePoints() async {
    debugPrint('📊 Starting retroactive constellation points calculation...');

    // Get all instances
    final allInstances = await _db.creatureDao.getAllInstances();

    // Count bred instances per species and track rarity
    final Map<String, int> breedCounts = {};
    final Map<String, String> speciesRarity = {}; // Track rarity per species

    for (final instance in allInstances) {
      // Only count if it was bred (has parentage)
      if (instance.parentageJson != null &&
          instance.parentageJson!.isNotEmpty) {
        breedCounts[instance.baseId] = (breedCounts[instance.baseId] ?? 0) + 1;

        // Store rarity for this species (assuming all instances of same species have same rarity)
        // You may need to fetch this from your creature definition
        if (!speciesRarity.containsKey(instance.baseId)) {
          // TODO: Get actual rarity from your creature catalog/definition
          speciesRarity[instance.baseId] = 'common'; // Default to common
        }
      }
    }

    // Award milestones for each species
    for (final entry in breedCounts.entries) {
      final speciesId = entry.key;
      final count = entry.value;
      final rarity = speciesRarity[speciesId] ?? 'common';

      // Check which milestones were reached
      for (final milestone in BreedingMilestone.milestones) {
        if (count >= milestone.count) {
          final milestoneNum = BreedingMilestone.milestoneNumber(
            milestone.count,
          );

          // Check if already awarded
          final stats = await _db.constellationDao.getBreedingStats(speciesId);
          if (stats != null && stats.lastMilestoneAwarded >= milestoneNum) {
            continue; // Already awarded
          }

          // Calculate points with rarity multiplier
          final pointsToAward = milestone.getPointsForRarity(rarity);

          // Award points
          await _db.constellationDao.addPoints(
            amount: pointsToAward,
            transactionType: 'earned_breeding_retroactive',
            sourceId: speciesId,
            description:
                'Retroactive: $speciesId ($rarity) ${milestone.displayName} (${milestone.count} bred)',
          );

          // Update stats
          await _db.constellationDao.markMilestoneAwarded(
            speciesId,
            milestoneNum,
          );

          debugPrint(
            '🎁 Retroactive: $speciesId ($rarity) milestone ${milestone.count} → +$pointsToAward pts',
          );
        }
      }

      // Update breeding count
      final stats = await _db.constellationDao.getBreedingStats(speciesId);
      if (stats == null) {
        // Create new entry
        await _db
            .into(_db.breedingStatistics)
            .insert(
              BreedingStatisticsCompanion.insert(
                speciesId: speciesId,
                totalBred: Value(count),
                lastBredAtUtc: Value(DateTime.now().toUtc()),
              ),
            );
      } else if (stats.totalBred < count) {
        // Update to correct count
        await (_db.update(_db.breedingStatistics)
              ..where((t) => t.speciesId.equals(speciesId)))
            .write(BreedingStatisticsCompanion(totalBred: Value(count)));
      }
    }

    debugPrint('✅ Retroactive calculation complete');
    notifyListeners();
  }
}

/// Helper class for UI to display breeding progress
class BreedingProgress {
  final String speciesId;
  final int totalBred;
  final BreedingMilestone? nextMilestone;
  final double progress; // 0.0 to 1.0

  BreedingProgress({
    required this.speciesId,
    required this.totalBred,
    required this.nextMilestone,
    required this.progress,
  });
}
