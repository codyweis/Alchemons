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

import 'package:alchemons/widgets/wildlife_lure_glyph.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/animations/sprite_effects/static_effect_snapshot.dart';
import 'package:alchemons/widgets/fx/alchemy_effects/alchemy_effect_paint.dart';
import 'package:alchemons/widgets/fx/glyph_clock.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:alchemons/widgets/raid_beacon_glyph.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:alchemons/widgets/stamina_elixir_glyph.dart';
import 'package:alchemons/widgets/wild_fusion_glyph.dart';
import 'package:flutter/foundation.dart';
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
          child: AlchemicalPowerupOrbSphere(
            type: powerup,
            size: size,
            animate: animate,
          ),
        ),
      );
    }

    if (inventoryKey == InvKeys.potentialSoul) {
      // Its shells spin only where it is the subject — which is what the
      // widget's own "one hero instance" flag is for, and it was never being
      // handed through.
      return PotentialSoulSphere(size: size, animate: animate);
    }

    if (inventoryKey == InvKeys.wildFusion) {
      return WildFusionGlyph(size: size, animate: animate);
    }

    if (inventoryKey == InvKeys.staminaPotion) {
      return StaminaElixirGlyph(size: size, animate: animate);
    }

    if (inventoryKey == InvKeys.instantHatch) {
      return InstantExtractorGlyph(size: size, animate: animate);
    }

    if (inventoryKey == InvKeys.wildlifeLure) {
      return WildlifeLureGlyph(size: size, animate: animate);
    }

    if (inventoryKey == InvKeys.raidBeacon) {
      return RaidBeaconGlyph(size: size, animate: animate);
    }

    final riftKey = PortalKeyGlyph.biomeForInventoryKey(inventoryKey);
    if (riftKey != null) {
      return PortalKeyGlyph(biomeId: riftKey, size: size, animate: animate);
    }

    // 2a. Alchemical Resonance is the plainest effect — soft amber light and
    // a few motes, made to glow round a creature. Alone in a cell at the
    // shop's scale and resting moment (the bottom of its slow breath, with
    // most motes faded out) it was a faint brown smudge. The icon draws the
    // same effect, filling its box, at the top of its breath, with its light
    // laid twice.
    if (inventoryKey == InvKeys.alchemyGlow) {
      final live = ExcludeSemantics(
        child: _ResonanceIcon(size: size, animate: animate),
      );
      if (animate) return live;
      return StaticEffectSnapshot(
        cacheKey: 'item.alchemy.$inventoryKey.icon',
        boxSize: size,
        child: live,
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

/// Alchemical Resonance as an item: the effect itself (see
/// [AlchemyEffectPaint]), sized to its box and caught at its brightest.
class _ResonanceIcon extends StatefulWidget {
  const _ResonanceIcon({required this.size, required this.animate});

  final double size;
  final bool animate;

  @override
  State<_ResonanceIcon> createState() => _ResonanceIconState();
}

class _ResonanceIconState extends State<_ResonanceIcon> with GlyphClockLease {
  bool _visible = true;

  @override
  bool get wantsClock => widget.animate && _visible;

  // Not in initState: TickerMode is only readable here, and a frozen bake
  // must never start the clock even for a frame.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = TickerMode.valuesOf(context).enabled;
    syncGlyphClock();
  }

  @override
  void didUpdateWidget(covariant _ResonanceIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    syncGlyphClock();
  }

  @override
  void dispose() {
    releaseGlyphClock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: CustomPaint(
      willChange: widget.animate,
      isComplex: false,
      painter: _ResonancePainter(clock: glyphClock),
    ),
  );
}

class _ResonancePainter extends CustomPainter {
  _ResonancePainter({required this.clock}) : super(repaint: clock);

  final ValueListenable<double>? clock;

  /// The top of the effect's 3.2 s breath, with all seven of its motes up
  /// and inside the box. The shop's resting moment (2.6 s) is its bottom.
  static const double _peak = 7.2;

  @override
  void paint(Canvas canvas, Size size) {
    final t = (clock?.value ?? 0) + _peak;
    final c = Offset(size.width / 2, size.height * 0.54);
    // Its light reaches past the radius and its motes rise above it: this
    // fills the box without spilling far out of it.
    final r = size.shortestSide * 0.4;
    for (var i = 0; i < 2; i++) {
      AlchemyEffectPaint.paint(canvas, AlchemyEffectPaint.alchemyGlow, c, r, t);
    }
  }

  @override
  bool shouldRepaint(covariant _ResonancePainter old) => old.clock != clock;
}
