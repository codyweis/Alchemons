import 'package:alchemons/database/daos/settings_dao.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';

class OpeningWildernessService {
  static const String activeKey = 'opening_wilderness_active';
  static const String allowedScenesKey = 'opening_wilderness_allowed_scenes';
  static const String capturePendingKey = 'tutorial_wild_capture_pending';
  static const String captureSceneKey = 'tutorial_wild_capture_scene';

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
    if (!await isRestrictionActive(settings)) return true;
    final allowed = await allowedScenes(settings);
    return allowed.contains(sceneId);
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
    await settings.deleteSetting(capturePendingKey);
    await settings.deleteSetting(captureSceneKey);
    await settings.deleteSetting(allowedScenesKey);
    await settings.setSetting(activeKey, '0');
  }
}
