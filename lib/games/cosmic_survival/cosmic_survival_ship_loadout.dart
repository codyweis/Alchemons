// lib/games/cosmic_survival/cosmic_survival_ship_loadout.dart
//
// Which hull survival flies. The designs are forged in cosmic space; survival
// only picks among the ones already built there.

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurvivalShipLoadout {
  const SurvivalShipLoadout({required this.unlockedSkins, this.selectedSkin});

  /// Written by the cosmic screen; read-only here.
  static const cosmicCustomizationPrefsKey = 'cosmic_home_customization_v1';

  /// Survival keeps its own pick rather than toggling the cosmic one. The
  /// cosmic screen holds its customization in memory and saves the whole
  /// thing back, so writing its key from here would be silently undone by
  /// the next cosmic save — and a player may want a different hull in each.
  static const selectedSkinPrefsKey = 'survival_ship_skin_v1';

  /// Every ship design in the cosmic catalog, in catalog order.
  static List<HomeRecipe> get designs => [
    for (final r in kHomeRecipes)
      if (r.id.startsWith('skin_')) r,
  ];

  final Set<String> unlockedSkins;

  /// Null flies the standard hull.
  final String? selectedSkin;

  static Future<SurvivalShipLoadout> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cosmicCustomizationPrefsKey);
    // Developer tools fly every hull without forging it. Nothing is written
    // to the cosmic save, so switching the tools off takes them away again.
    final unlocked = await DebugSettingsService().isEnabled()
        ? {for (final r in designs) r.id}
        : raw == null
        ? <String>{}
        : HomeCustomizationState.deserialise(
            raw,
          ).unlockedIds.where((id) => id.startsWith('skin_')).toSet();
    final selected = prefs.getString(selectedSkinPrefsKey);
    return SurvivalShipLoadout(
      unlockedSkins: unlocked,
      // A pick that is no longer built (a restored older save) falls back to
      // the standard hull instead of flying a ship the player does not own.
      selectedSkin: unlocked.contains(selected) ? selected : null,
    );
  }

  static Future<void> select(String? skinId) async {
    final prefs = await SharedPreferences.getInstance();
    if (skinId == null) {
      await prefs.remove(selectedSkinPrefsKey);
    } else {
      await prefs.setString(selectedSkinPrefsKey, skinId);
    }
  }
}
