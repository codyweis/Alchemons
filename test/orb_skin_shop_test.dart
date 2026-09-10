// Orb skins are sold where they are worn.
//
// They used to be in the main shop as well as Base Command, which meant
// buying one and then walking to a second screen to put it on, and two lists
// that could disagree about what you owned. The shop section is gone.
//
// The ShopOffers behind them are NOT gone, and that is the thing worth
// pinning: nothing in the shop UI references them any more, so they read as
// dead code, but Base Command resolves each skin to its offer for the
// discounted price and the once-only purchase limit. Delete them and the
// orb tab silently falls back to undiscounted silver.

import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every orb skin you pay for still resolves to its shop offer', () {
    for (final def in kOrbBases.where((d) => d.cost > 0)) {
      final matches = ShopService.allOffers.where((o) => o.id == def.shopId);
      expect(
        matches.length,
        1,
        reason:
            '${def.skin.name} points at "${def.shopId}", which Base Command '
            'needs for pricing and the once-only limit',
      );
    }
  });

  test('the free orb needs no offer, and Base Command copes', () {
    final def = getOrbBaseDef(OrbBaseSkin.defaultOrb);
    // It declares a shopId that was never sold. Base Command falls back to
    // the def's own cost when the lookup misses, which is why this is fine.
    expect(def.cost, 0);
    expect(ShopService.allOffers.where((o) => o.id == def.shopId), isEmpty);
  });

  test('the offers that remain are the survival orb ones only', () {
    final orbOffers = ShopService.allOffers
        .where((o) => o.id.startsWith('survival.orb'))
        .map((o) => o.id)
        .toSet();
    final claimed = kOrbBases
        .where((d) => d.cost > 0)
        .map((d) => d.shopId)
        .toSet();
    expect(
      orbOffers.difference(claimed),
      isEmpty,
      reason: 'a survival.orb offer no orb skin claims is genuinely dead',
    );
  });

}
