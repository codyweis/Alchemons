// lib/games/heart_puzzle/alchemy_unlock.dart
//
// When ALCHEMY opens: once the player has found, for each of the seventeen
// elements, at least one formula that makes it (the author, 2026-11-13:
// "unlock it after we discover at least 1 recipe for the 17 elements, not
// all"; it was every element and family formula, 51 of them, from
// 2026-10-08). Family formulas no longer count. Until then home shows it
// locked, with how many elements are made. With the developer tools on it
// is open regardless, as its levels are.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/services/alchemical_encyclopedia_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';

class AlchemyUnlock {
  const AlchemyUnlock({
    required this.found,
    required this.total,
    this.debug = false,
  });

  /// Elements with a formula found that makes them, of all there are.
  final int found, total;

  /// Opened by the developer tools, whatever the count.
  final bool debug;

  bool get open => debug || (total > 0 && found >= total);
  double get progress => total == 0 ? 0 : (found / total).clamp(0.0, 1.0);

  static const AlchemyUnlock none = AlchemyUnlock(found: 0, total: 0);

  static Future<AlchemyUnlock> load({required AlchemonsDatabase db}) async {
    final e = await AlchemicalEncyclopediaService.elementsMade(db);
    final debug = await DebugSettingsService().isEnabled();
    return AlchemyUnlock(
      found: e.made.length,
      total: e.all.length,
      debug: debug,
    );
  }
}
