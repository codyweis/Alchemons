import 'package:alchemons/database/daos/settings_dao.dart';

class CosmicMemoryTutorialService {
  CosmicMemoryTutorialService._();

  static const harvestCompletedKey = 'tutorial_harvest_completed_v1';
  static const extractionCountKey = 'cosmic_memory_extraction_count_v1';
  static const homePortalPendingKey = 'cosmic_memory_home_portal_pending_v1';
  static const homePortalLaunchedKey = 'cosmic_memory_home_portal_launched_v1';
  static const completedKey = 'cosmic_memory_tutorial_completed_v1';
  static const storyPendingKey = 'cosmic_memory_story_pending_v1';
  static const extractionTarget = 3;

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

  static Future<void> recordExtractionIfEligible(SettingsDao settings) async {
    final harvestCompleted = await _ensureHarvestEligibility(settings);
    final completed = await settings.getSetting(completedKey) == '1';
    final pending = await settings.getSetting(homePortalPendingKey) == '1';
    final launched = await settings.getSetting(homePortalLaunchedKey) == '1';
    if (!harvestCompleted || completed || pending || launched) return;

    final raw = await settings.getSetting(extractionCountKey);
    final nextCount = (int.tryParse(raw ?? '0') ?? 0) + 1;
    await settings.setSetting(extractionCountKey, nextCount.toString());

    if (nextCount >= extractionTarget) {
      await settings.setSetting(homePortalPendingKey, '1');
    }
  }

  static Future<void> recoverPendingForExistingProfile(
    SettingsDao settings, {
    required int ownedInstanceCount,
  }) async {
    final harvestCompleted = await _ensureHarvestEligibility(settings);
    final completed = await settings.getSetting(completedKey) == '1';
    final pending = await settings.getSetting(homePortalPendingKey) == '1';
    final launched = await settings.getSetting(homePortalLaunchedKey) == '1';
    if (!harvestCompleted || completed || pending || launched) return;

    final raw = await settings.getSetting(extractionCountKey);
    final savedCount = int.tryParse(raw ?? '');
    final effectiveCount = savedCount ?? ownedInstanceCount;
    if (savedCount == null && ownedInstanceCount > 0) {
      await settings.setSetting(extractionCountKey, effectiveCount.toString());
    }

    if (effectiveCount >= extractionTarget) {
      await settings.setSetting(homePortalPendingKey, '1');
    }
  }

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

  static Future<bool> consumeStoryPending(SettingsDao settings) async {
    final pending = await settings.getSetting(storyPendingKey) == '1';
    if (pending) {
      await settings.deleteSetting(storyPendingKey);
    }
    return pending;
  }

  static Future<void> debugQueueTutorial(SettingsDao settings) async {
    await settings.setSetting(harvestCompletedKey, '1');
    await settings.setSetting(extractionCountKey, extractionTarget.toString());
    await settings.setSetting(homePortalPendingKey, '1');
    await settings.deleteSetting(homePortalLaunchedKey);
    await settings.deleteSetting(completedKey);
    await settings.deleteSetting(storyPendingKey);
  }
}
