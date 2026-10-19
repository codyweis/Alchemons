// lib/screens/home_biome/home_sky_source.dart
//
// Where the home's sky comes from: the planet as the player's cosmic save
// has it, and the constellation stones they own. Read once as the home
// opens, and made into what the field draws by what the player has turned
// on (HomeSky).

import 'dart:ui' show Offset;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/wilderness/field/home_sky_art.dart';
import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/models/constellation/constellation_layout.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/models/home_sky.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the home's sky is made of.
class HomeSkySources {
  const HomeSkySources({this.planet, this.constellations = const {}});

  /// The player's planet, or null before they have built one.
  final PlanetLook? planet;

  /// The constellation stones the player owns, by skill id.
  final Set<String> constellations;

  static const none = HomeSkySources();

  /// The player's own, from their save. Anything that cannot be read is
  /// left out: a home with no planet still has its sky.
  static Future<HomeSkySources> read(AlchemonsDatabase db) async {
    PlanetLook? planet;
    try {
      planet = PlanetLook.read(await SharedPreferences.getInstance());
    } catch (_) {}
    var owned = const <String>{};
    try {
      owned = await db.constellationDao.getUnlockedSkillIds();
    } catch (_) {}
    return HomeSkySources(planet: planet, constellations: owned);
  }
}

/// The visual effects a planet can wear (not its ammo, upgrades or kit).
final Set<String> kPlanetVisualIds = {
  for (final r in kHomeRecipes)
    if (r.category == HomeRecipeCategory.visual) r.id,
};

final Map<ConstellationTree, Map<String, Offset>> _treeLayouts = {
  for (final t in ConstellationTree.values) t: constellationTreeLayout(t),
};

/// What the field draws of [sources] under [sky]'s switches.
HomeSkyLook homeSkyLookOf(HomeSky sky, HomeSkySources sources) {
  final planet = sky.planet ? sources.planet : null;
  final wearing = planet == null
      ? const <String>{}
      : {
          for (final id in planet.wearing)
            if (kPlanetVisualIds.contains(id)) id,
        };
  final (stars, links) = sky.constellations
      ? skyStarsFor(sources.constellations, _treeLayouts)
      : (const <SkyStar>[], const <(int, int)>[]);
  return HomeSkyLook(
    color: planet?.color,
    tint: planet?.color == null ? null : homeColorSwatch(planet!.color),
    wearing: wearing,
    options: planet == null
        ? const {}
        : {
            for (final e in planet.options.entries)
              if (wearing.contains(e.key.split('.').first)) e.key: e.value,
          },
    stars: stars,
    links: links,
  );
}
