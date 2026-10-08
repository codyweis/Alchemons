// lib/games/heart_puzzle/alchemy_unlock.dart
//
// When ALCHEMY opens (the author, 2026-10-08: "we'll just unlock this mode
// when all elements and species recipes are discovered"): every element
// formula and every family formula in the encyclopedia found. Until then
// home shows it locked, with how many are found. With the developer tools
// on it is open regardless, as its levels are.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/debug_settings_service.dart';

class AlchemyUnlock {
  const AlchemyUnlock({
    required this.found,
    required this.total,
    this.debug = false,
  });

  /// Formulas found, of all there are (elements and families together).
  final int found, total;

  /// Opened by the developer tools, whatever the count.
  final bool debug;

  bool get open => debug || (total > 0 && found >= total);
  double get progress => total == 0 ? 0 : (found / total).clamp(0.0, 1.0);

  static const AlchemyUnlock none = AlchemyUnlock(found: 0, total: 0);

  static Future<AlchemyUnlock> load({
    required AlchemonsDatabase db,
    CreatureCatalog? catalog,
  }) async {
    final snap = await AlchemicalEncyclopediaService.loadSnapshot(
      db: db,
      catalog: catalog,
    );
    final all = [...snap.elementRecipes, ...snap.familyRecipes];
    final found = all.where(snap.isDiscovered).length;
    final debug = await DebugSettingsService().isEnabled();
    return AlchemyUnlock(found: found, total: all.length, debug: debug);
  }
}
