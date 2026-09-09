import 'package:flutter/foundation.dart';
import 'package:alchemons/database/daos/settings_dao.dart';

class CosmicMemoryTutorialService {
  CosmicMemoryTutorialService._();

  static const harvestCompletedKey = 'tutorial_harvest_completed_v1';
  static const biomeExitCountKey = 'cosmic_memory_biome_exit_count_v1';
  static const homePortalPendingKey = 'cosmic_memory_home_portal_pending_v1';
  static const homePortalLaunchedKey = 'cosmic_memory_home_portal_launched_v1';
  static const completedKey = 'cosmic_memory_tutorial_completed_v1';
  static const storyPendingKey = 'cosmic_memory_story_pending_v1';
  /// Biome visits before the memory finds them.
  ///
  /// Counted as exits from the core wilderness scenes. The first two are spent
  /// on the tutorials — the fusion in one biome, the harvest in the next — so
  /// the third is the first time the player leaves a biome having simply
  /// played it, which is the moment worth interrupting.
  static const biomeExitTarget = 3;

  static Future<void> markHarvestTutorialCompleted(SettingsDao settings) async {
    await settings.setSetting(harvestCompletedKey, '1');
  }

  static Future<bool> _ensureHarvestEligibility(SettingsDao settings) async {
    var harvestCompleted =
        await settings.getSetting(harvestCompletedKey) == '1';
    if (!harvestCompleted) {
      final fieldCompleted =
          await settings.getSetting('tutorial_field_completed') == '1';
      final openingWildernessActive = await settings.getSetting(
        'opening_wilderness_active',
      );
      final capturePending =
          await settings.getSetting('tutorial_wild_capture_pending') == '1';
      final openingTutorialFinished =
          openingWildernessActive != '1' && !capturePending;
      if (fieldCompleted && openingTutorialFinished) {
        await markHarvestTutorialCompleted(settings);
        harvestCompleted = true;
      }
    }

    return harvestCompleted;
  }

  /// Count a departure from one of the core wilderness biomes.
  ///
  /// Every exit counts, including the two the tutorials occupy. Gating the
  /// count on the harvest tutorial being finished would throw both of those
  /// away and start from zero afterwards, which would push the memory two
  /// biomes later than intended — so the harvest check guards only the
  /// *firing*, not the counting.
  static Future<void> recordBiomeExitIfEligible(SettingsDao settings) async {
    final completed = await settings.getSetting(completedKey) == '1';
    final pending = await settings.getSetting(homePortalPendingKey) == '1';
    final launched = await settings.getSetting(homePortalLaunchedKey) == '1';
    if (completed || pending || launched) return;

    final raw = await settings.getSetting(biomeExitCountKey);
    final nextCount = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await settings.setSetting(biomeExitCountKey, nextCount.toString());
    if (nextCount < biomeExitTarget) return;

    // Never before the harvest tutorial is behind them, however they got here.
    if (!await _ensureHarvestEligibility(settings)) return;
    await settings.setSetting(homePortalPendingKey, '1');
  }

  static Future<void> recoverPendingForExistingProfile(
    SettingsDao settings, {
    required int ownedInstanceCount,
  }) async {
    final harvestCompleted = await _ensureHarvestEligibility(settings);
    final completed = await settings.getSetting(completedKey) == '1';
    final pending = await settings.getSetting(homePortalPendingKey) == '1';
    final launched = await settings.getSetting(homePortalLaunchedKey) == '1';
    if (!harvestCompleted || completed || pending) return;
    if (launched) {
      // The home caller is guarded while the route is active. A remaining
      // launch marker here belongs to an interrupted, unfinished memory.
      await settings.setSetting(homePortalPendingKey, '1');
      await settings.deleteSetting(homePortalLaunchedKey);
      return;
    }

    // A save from before the biome counter existed has no exits recorded, and
    // making an established player walk three more biomes to see a memory they
    // are long past would be worse than showing it now. Owning specimens with
    // the harvest tutorial behind them is enough.
    final raw = await settings.getSetting(biomeExitCountKey);
    final savedCount = int.tryParse(raw ?? '');
    final effectiveCount = savedCount ?? (ownedInstanceCount > 0 ? biomeExitTarget : 0);
    if (savedCount == null && ownedInstanceCount > 0) {
      await settings.setSetting(biomeExitCountKey, effectiveCount.toString());
    }

    if (effectiveCount >= biomeExitTarget) {
      await settings.setSetting(homePortalPendingKey, '1');
    }
  }

  /// Set when a launched memory tutorial came back unfinished.
  ///
  /// Process-scoped on purpose. An abandoned tutorial stays queued so it is not
  /// lost, but it must not relaunch the moment the player lands back on home —
  /// that leaves them unable to get out. It greets them again next app launch.
  static bool _deferredThisSession = false;

  static bool get isDeferredThisSession => _deferredThisSession;

  static void deferForThisSession() {
    _deferredThisSession = true;
  }

  @visibleForTesting
  static void resetSessionDeferral() {
    _deferredThisSession = false;
  }

  static Future<bool> isCompleted(SettingsDao settings) async =>
      await settings.getSetting(completedKey) == '1';

  static Future<bool> isHomePortalPending(SettingsDao settings) async {
    final completed = await settings.getSetting(completedKey) == '1';
    if (completed) return false;
    return await settings.getSetting(homePortalPendingKey) == '1';
  }

  static Future<void> markHomePortalLaunched(SettingsDao settings) async {
    await settings.deleteSetting(homePortalPendingKey);
    await settings.setSetting(homePortalLaunchedKey, '1');
  }

  static Future<void> markCompleted(SettingsDao settings) async {
    await settings.setSetting(completedKey, '1');
    await settings.deleteSetting(homePortalPendingKey);
    await settings.deleteSetting(homePortalLaunchedKey);
    await settings.setSetting(storyPendingKey, '1');
  }

  static Future<bool> isStoryPending(SettingsDao settings) async =>
      await settings.getSetting(storyPendingKey) == '1';

  static Future<void> acknowledgeStory(SettingsDao settings) =>
      settings.deleteSetting(storyPendingKey);

  static Future<void> debugQueueTutorial(SettingsDao settings) async {
    _deferredThisSession = false;
    await settings.setSetting(harvestCompletedKey, '1');
    await settings.setSetting(biomeExitCountKey, biomeExitTarget.toString());
    await settings.setSetting(homePortalPendingKey, '1');
    await settings.deleteSetting(homePortalLaunchedKey);
    await settings.deleteSetting(completedKey);
    await settings.deleteSetting(storyPendingKey);
  }
}
