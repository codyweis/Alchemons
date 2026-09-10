import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/cosmic_memory_tutorial_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';

class OpeningWildernessService {
  static const String activeKey = 'opening_wilderness_active';
  static const String allowedScenesKey = 'opening_wilderness_allowed_scenes';
  static const String capturePendingKey = 'tutorial_wild_capture_pending';
  static const String captureSceneKey = 'tutorial_wild_capture_scene';

  /// The biomes still to be explored before the ship turns up, in order,
  /// **head first** — and only the head is open.
  ///
  /// Recovering the ship needs all four core biomes visited, but nothing was
  /// pushing the player out of the two the tutorial already took them
  /// through, so they could farm those two indefinitely and never trip the
  /// discovery that moves the story on.
  ///
  /// Opening the remaining two together left the player choosing between two
  /// unfamiliar regions with nothing to choose on. One at a time is the same
  /// nudge with no decision attached: go here, then here, and then the map is
  /// yours. The tutorial's own two are already sequential, so this makes the
  /// whole opening one road rather than a road that forks at the end.
  ///
  /// Stored as a list because the order is the point. An older save holding
  /// the two-open set reads as a queue in whatever order it was written,
  /// which is a sane way to land mid-hunt.
  static const String shipHuntKey = 'wilderness_ship_hunt_scenes_v1';
  static const String shipUnlockedKey = 'cosmic_ship_unlocked';

  static const Set<String> coreScenes = {'valley', 'sky', 'swamp', 'volcano'};

  static String primarySceneForFaction(FactionId faction) {
    switch (faction) {
      case FactionId.volcanic:
        return 'volcano';
      case FactionId.oceanic:
        return 'swamp';
      case FactionId.earthen:
        return 'valley';
      case FactionId.verdant:
        return 'sky';
    }
  }

  static String oppositeSceneFor(String sceneId) {
    switch (sceneId) {
      case 'volcano':
        return 'swamp';
      case 'swamp':
        return 'volcano';
      case 'sky':
        return 'valley';
      case 'valley':
      default:
        return 'sky';
    }
  }

  static String mainLetForScene(String sceneId) {
    switch (sceneId) {
      case 'volcano':
        return 'LET01';
      case 'swamp':
        return 'LET02';
      case 'sky':
        return 'LET04';
      case 'valley':
      default:
        return 'LET03';
    }
  }

  static String tutorialSpawnPointForScene(String sceneId) {
    switch (sceneId) {
      case 'sky':
        return 'SP_sky_01';
      case 'swamp':
        return 'SP_swamp_01';
      case 'volcano':
        return 'SP_volcano_02';
      case 'valley':
      default:
        return 'SP_valley_02';
    }
  }

  static CatchDeviceType harvesterForScene(String sceneId) {
    switch (sceneId) {
      case 'volcano':
        return CatchDeviceType.volcanic;
      case 'swamp':
        return CatchDeviceType.oceanic;
      case 'sky':
        return CatchDeviceType.verdant;
      case 'valley':
      default:
        return CatchDeviceType.earthen;
    }
  }

  static String harvesterInventoryKeyForScene(String sceneId) {
    return harvesterForScene(sceneId).inventoryKey;
  }

  static Set<String> openingScenesForFaction(FactionId faction) {
    final primary = primarySceneForFaction(faction);
    return {primary, oppositeSceneFor(primary)};
  }

  static Future<void> activateForFaction(
    SettingsDao settings,
    FactionId faction,
  ) async {
    final scenes = openingScenesForFaction(faction).toList()..sort();
    await settings.setSetting(activeKey, '1');
    await settings.setSetting(allowedScenesKey, scenes.join(','));
    await settings.deleteSetting(capturePendingKey);
    await settings.deleteSetting(captureSceneKey);
  }

  static Future<bool> isRestrictionActive(SettingsDao settings) async {
    return await settings.getSetting(activeKey) == '1';
  }

  static Future<Set<String>> allowedScenes(SettingsDao settings) async {
    final raw = await settings.getSetting(allowedScenesKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    return raw
        .split(',')
        .map((scene) => scene.trim())
        .where((scene) => scene.isNotEmpty)
        .toSet();
  }

  static Future<bool> isSceneAllowed(
    SettingsDao settings,
    String sceneId,
  ) async {
    if (!coreScenes.contains(sceneId)) return true;
    if (await isRestrictionActive(settings)) {
      final allowed = await allowedScenes(settings);
      return allowed.contains(sceneId);
    }
    final open = await openShipHuntScene(settings);
    if (open == null) return true;
    return sceneId == open;
  }

  /// The biomes left to visit before the ship turns up, in order. Empty once
  /// the hunt is over.
  static Future<List<String>> shipHuntScenes(SettingsDao settings) async {
    if (await settings.getSetting(shipUnlockedKey) == '1') return const [];
    final raw = await settings.getSetting(shipHuntKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((scene) => scene.trim())
        .where((scene) => scene.isNotEmpty && coreScenes.contains(scene))
        .toList();
  }

  /// The one biome the hunt is currently pointing at, or null when the hunt
  /// is over and the map is open again.
  static Future<String?> openShipHuntScene(SettingsDao settings) async {
    final hunt = await shipHuntScenes(settings);
    return hunt.isEmpty ? null : hunt.first;
  }

  /// Whether [sceneId] is closed only because the ship hunt is pointing the
  /// player somewhere else — as opposed to simply being empty.
  static Future<bool> isHeldForShipHunt(
    SettingsDao settings,
    String sceneId,
  ) async {
    if (!coreScenes.contains(sceneId)) return false;
    if (await isRestrictionActive(settings)) return false;
    final open = await openShipHuntScene(settings);
    return open != null && sceneId != open;
  }

  /// Going in is what advances the hunt — not catching anything, not
  /// finishing a run. Walking in is the whole ask, so arriving is what pays
  /// for the next one.
  ///
  /// Safe to call for any scene at any time: only the biome the hunt is
  /// currently pointing at moves it along.
  static Future<void> markSceneVisited(
    SettingsDao settings,
    String sceneId,
  ) async {
    final hunt = await shipHuntScenes(settings);
    if (hunt.isEmpty || hunt.first != sceneId) return;
    final remaining = hunt.skip(1).toList();
    if (remaining.isEmpty) {
      await settings.deleteSetting(shipHuntKey);
    } else {
      await settings.setSetting(shipHuntKey, remaining.join(','));
    }
  }

  static Future<void> advanceToCaptureTutorial(
    SettingsDao settings, {
    required String firstScene,
  }) async {
    final allowed = await allowedScenes(settings);
    final remaining = allowed.where((scene) => scene != firstScene).toList();
    if (remaining.isEmpty) {
      await completeCaptureTutorial(settings);
      return;
    }

    final captureScene = remaining.first;
    await settings.setSetting(activeKey, '1');
    await settings.setSetting(allowedScenesKey, captureScene);
    await settings.setSetting(capturePendingKey, '1');
    await settings.setSetting(captureSceneKey, captureScene);
  }

  static Future<bool> isCaptureTutorialScene(
    SettingsDao settings,
    String sceneId,
  ) async {
    if (!await isRestrictionActive(settings)) return false;
    if (await settings.getSetting(capturePendingKey) != '1') return false;
    return await settings.getSetting(captureSceneKey) == sceneId;
  }

  static Future<void> completeCaptureTutorial(SettingsDao settings) async {
    // The two the tutorial used are whichever pair it ran in — that depends
    // on faction, so it is derived rather than named. oppositeSceneFor pairs
    // them off, and it is its own inverse, so the capture scene gives back
    // the one the player started in.
    final captureScene = await settings.getSetting(captureSceneKey);
    if (captureScene != null && coreScenes.contains(captureScene)) {
      final firstScene = oppositeSceneFor(captureScene);
      // Order matters now — this is the road, not a pair of options.
      final remaining = coreScenes
          .where((s) => s != captureScene && s != firstScene)
          .toList();
      if (remaining.isNotEmpty) {
        await settings.setSetting(shipHuntKey, remaining.join(','));
      }
    }

    await settings.deleteSetting(capturePendingKey);
    await settings.deleteSetting(captureSceneKey);
    await settings.deleteSetting(allowedScenesKey);
    await settings.setSetting(activeKey, '0');
    await CosmicMemoryTutorialService.markHarvestTutorialCompleted(settings);
  }
}
