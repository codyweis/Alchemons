import 'package:alchemons/database/daos/settings_dao.dart';

/// A realm bought in the shop. Buying it opens it twice over: a new realm on
/// the wild map, with Alchemons that are found nowhere else in the wild, and
/// a new home to build on the home planet.
class ShopScene {
  const ShopScene({
    required this.sceneId,
    required this.title,
    required this.line,
    required this.gold,
    required this.species,
  });

  /// The scene id the wild uses (its spawns, its map circle, its music) —
  /// and the home realm's name.
  final String sceneId;

  /// What it is called everywhere: the shop, the map's portal, the home.
  final String title;

  /// One plain line for the shop card.
  final String line;

  /// What it costs.
  final int gold;

  /// The Alchemons the wild has nowhere else, for the shop card to name.
  final List<String> species;

  String get offerId => 'scene.$sceneId';

  /// The Settings row that says it is owned (it travels with the save).
  String get settingKey => 'scene_unlocked_$sceneId';
}

/// Every realm the shop sells, in the order it shows them.
const List<ShopScene> kShopScenes = [
  ShopScene(
    sceneId: 'dunes',
    title: 'Glass Dunes',
    line:
        'A desert realm with sandstorms. Adds a realm to the wild map and a '
        'new place to build your home.',
    gold: 500,
    species: [
      'Dustkin',
      'Earthpip',
      'Earthmask',
      'Lightmane',
      'Airmask',
      'Lightningmask',
      'Airkin',
      'Lightningkin',
    ],
  ),
];

/// The shop's realm with [sceneId], or null for one that is not sold.
ShopScene? shopSceneOf(String sceneId) =>
    kShopScenes.where((s) => s.sceneId == sceneId).firstOrNull;

/// The shop's realm sold as [offerId], or null.
ShopScene? shopSceneByOffer(String offerId) =>
    kShopScenes.where((s) => s.offerId == offerId).firstOrNull;

/// Whether [sceneId] is open: always for a realm the shop does not sell,
/// and for one it sells once it has been bought.
Future<bool> shopSceneOpen(SettingsDao settings, String sceneId) async {
  final scene = shopSceneOf(sceneId);
  if (scene == null) return true;
  final v = await settings.getSetting(scene.settingKey);
  return v == '1' || v == 'true';
}

/// The ids of the shop's realms that have been bought.
Future<Set<String>> ownedShopScenes(SettingsDao settings) async => {
  for (final s in kShopScenes)
    if (await shopSceneOpen(settings, s.sceneId)) s.sceneId,
};
