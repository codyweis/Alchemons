// lib/widgets/inventory_item_artwork.dart
//
// The artwork for an inventory item, keyed by its inventory key.
//
// The shop already knows how to draw every item — powerup orbs as glowing
// spheres, alchemy effects as their live sprite effect, everything else from
// the offer's asset — but that logic hangs off a ShopOffer, so anywhere that
// only holds an inventory key (cache payouts, reward popups) fell back to a
// flat Material icon and looked like a different game.
//
// This resolves an inventory key back to the same sources the shop draws from,
// in the same order, so an item looks identical wherever it appears.

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/animations/sprite_effects/static_effect_snapshot.dart';
import 'package:flutter/material.dart';

class InventoryItemArtwork extends StatelessWidget {
  const InventoryItemArtwork({
    super.key,
    required this.inventoryKey,
    this.size = 40,
    this.animate = false,
    this.fallbackIcon,
    this.fallbackColor,
  });

  final String inventoryKey;
  final double size;

  /// Live sprite effects are expensive; lists and payout rows pass false and
  /// get the same baked resting frame the shop grid uses.
  final bool animate;

  final IconData? fallbackIcon;
  final Color? fallbackColor;

  /// The offer that sells this item, if any — the source of its asset art.
  static ShopOffer? offerFor(String inventoryKey) {
    for (final offer in ShopService.allOffers) {
      if (offer.inventoryKey == inventoryKey) return offer;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Alchemical powerups — the glowing stat sphere, as in the shop.
    final powerup = alchemicalPowerupTypeFromInventoryKey(inventoryKey);
    if (powerup != null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: AlchemicalPowerupOrbSphere(type: powerup, size: size),
        ),
      );
    }

    // 2. Alchemy effects — the real sprite effect, baked unless animating.
    final preview = ShopService.getAlchemyEffectPreview(
      inventoryKey,
      size: size,
    );
    if (preview != null) {
      final live = SizedBox.square(
        dimension: size,
        child: ExcludeSemantics(child: preview),
      );
      if (animate) return live;
      return StaticEffectSnapshot(
        cacheKey: 'item.alchemy.$inventoryKey',
        boxSize: size,
        child: live,
      );
    }

    // 3. Whatever art the shop offer carries.
    final offer = offerFor(inventoryKey);
    if (offer?.assetName != null) {
      return SizedBox.square(
        dimension: size,
        child: Image.asset(
          offer!.assetName!,
          fit: BoxFit.contain,
          color: offer.imageColor,
          colorBlendMode: offer.imageColor != null ? BlendMode.multiply : null,
          errorBuilder: (_, _, _) => _icon(offer.icon, offer.iconColor),
        ),
      );
    }

    return _icon(offer?.icon ?? fallbackIcon, offer?.iconColor);
  }

  Widget _icon(IconData? icon, Color? color) => SizedBox.square(
    dimension: size,
    child: Icon(
      icon ?? fallbackIcon ?? Icons.inventory_2_rounded,
      size: size * 0.78,
      color: color ?? fallbackColor ?? const Color(0xFFE8DFC8),
    ),
  );
}
