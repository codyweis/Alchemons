// lib/widgets/shop_widgets.dart
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ============= SUPPORTING WIDGETS =============
// ShowPurchasedToggle and CurrencyPill are unchanged...

String _formatShopValue(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return value < 0 ? '-${buffer.toString()}' : buffer.toString();
}

class CurrencyPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int amount;

  const CurrencyPill({
    super.key,
    required this.icon,
    required this.color,
    required this.amount,
  });

  String _format(int n) {
    return _formatShopValue(n);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final displayColor = t.readableAccent(color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: displayColor.withValues(alpha: theme.isDark ? 0.14 : 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: displayColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: displayColor),
              const SizedBox(width: 6),
              Text(
                _format(amount),
                style: TextStyle(
                  color: displayColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Enhanced Item Detail Dialog
// Add this to your shop_widgets.dart or create a new file for dialogs

// ── Forge color tokens are provided by ForgeTokens(theme) ──────────────────────

Future<bool> showItemDetailDialog({
  required BuildContext context,
  required ShopOffer offer,
  required FactionTheme theme,
  required Map<String, int> currencies,
  required int inventoryQty,
  required bool canPurchase,
  required bool canAfford,
  Map<String, int>? effectiveCost,
}) async {
  final displayCost = effectiveCost ?? offer.cost;
  final t = ForgeTokens(theme);
  final primaryAccent = t.readableAccent(t.amberBright);
  final secondaryAccent = t.readableAccent(t.amber);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: t.borderAccent, width: 1),
              boxShadow: [
                BoxShadow(
                  color: t.amber.withValues(alpha: 0.08),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  decoration: BoxDecoration(
                    color: t.bg0,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
                    ),
                    border: Border(
                      bottom: BorderSide(color: t.borderAccent, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ITEM DETAILS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: t.borderDim, width: 1),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: t.textSecondary,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Preview area ─────────────────────────────────────────────
                Container(
                  height: 140,
                  color: t.bg0,
                  child: _buildOfferPreviewForDialog(
                    offer,
                    size: 100.0,
                    theme: theme,
                  ),
                ),

                // ── Name + description ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Text(
                    offer.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    offer.description,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.5,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // ── Owned badge ──────────────────────────────────────────────
                if (inventoryQty > 0) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: t.amberDim.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(color: t.borderAccent, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_rounded,
                            color: secondaryAccent,
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'IN INVENTORY: $inventoryQty',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: secondaryAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // ── Cost section ─────────────────────────────────────────────
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(child: Container(height: 1, color: t.borderMid)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'COST',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textMuted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      Expanded(child: Container(height: 1, color: t.borderMid)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final entry in displayCost.entries)
                        _ForgeCostRow(
                          type: entry.key,
                          amount: entry.value,
                          current: currencies[entry.key] ?? 0,
                          theme: theme,
                        ),
                    ],
                  ),
                ),

                // ── Buttons ──────────────────────────────────────────────────
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      // CANCEL
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 44,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: t.borderAccent.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'BACK',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // PURCHASE / state button
                      Expanded(
                        child: canPurchase
                            ? GestureDetector(
                                onTap: canAfford
                                    ? () => Navigator.pop(ctx, true)
                                    : null,
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: canAfford
                                        ? t.amberDim.withValues(alpha: 0.35)
                                        : t.bg3,
                                    borderRadius: BorderRadius.circular(2),
                                    border: Border.all(
                                      color: canAfford
                                          ? t.amber
                                          : t.danger.withValues(alpha: 0.5),
                                      width: 1,
                                    ),
                                    boxShadow: canAfford
                                        ? [
                                            BoxShadow(
                                              color: t.amber.withValues(
                                                alpha: 0.15,
                                              ),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        canAfford
                                            ? Icons.shopping_bag_outlined
                                            : Icons.block_rounded,
                                        color: canAfford
                                            ? primaryAccent
                                            : t.danger.withValues(alpha: 0.7),
                                        size: 15,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        canAfford
                                            ? 'PURCHASE'
                                            : 'CAN\'T AFFORD',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: canAfford
                                              ? primaryAccent
                                              : t.danger.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: t.successDim.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(
                                    color: t.success.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      color: t.success,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      offer.limit == PurchaseLimit.daily
                                          ? 'BOUGHT TODAY'
                                          : 'PURCHASED',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: t.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

/// Single cost row — icon, label, amount, "Have: N" suffix.
class _ForgeCostRow extends StatelessWidget {
  final String type;
  final int amount;
  final int current;
  final FactionTheme theme;

  const _ForgeCostRow({
    required this.type,
    required this.amount,
    required this.current,
    required this.theme,
  });

  String? _assetForType() {
    switch (type) {
      case 'res_volcanic':
        return 'assets/images/ui/volcanic.png';
      case 'res_oceanic':
        return 'assets/images/ui/oceanic.png';
      case 'res_verdant':
        return 'assets/images/ui/verdant.png';
      case 'res_earthen':
        return 'assets/images/ui/earthen.png';
      case 'res_arcane':
        return 'assets/images/ui/arcane.png';
      default:
        return null;
    }
  }

  (IconData, String, Color) _info(String t) {
    switch (t) {
      case 'gold':
        return (Icons.hexagon_rounded, 'Gold', const Color(0xFFF59E0B));
      case 'silver':
        return (
          Icons.monetization_on_rounded,
          'Silver',
          const Color(0xFFB0BEC5),
        );
      case 'soft':
        return (Icons.diamond_rounded, 'Shards', const Color(0xFFB388FF));
      case 'res_volcanic':
        return (
          Icons.local_fire_department_rounded,
          'Volcanic',
          const Color(0xFFF97316),
        );
      case 'res_oceanic':
        return (Icons.water_drop_rounded, 'Oceanic', const Color(0xFF38BDF8));
      case 'res_verdant':
        return (Icons.eco_rounded, 'Verdant', const Color(0xFF4ADE80));
      case 'res_earthen':
        return (Icons.terrain_rounded, 'Earthen', const Color(0xFFA8996E));
      case 'res_arcane':
        return (Icons.auto_awesome_rounded, 'Arcane', const Color(0xFFA78BFA));
      default:
        return (Icons.circle, t, Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final (icon, label, color) = _info(type);
    final assetPath = _assetForType();
    final hasEnough = current >= amount;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: hasEnough ? t.borderDim : t.danger.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 15,
            height: 15,
            child: assetPath != null
                ? Image.asset(
                    assetPath,
                    fit: BoxFit.contain,
                    color: hasEnough ? null : const Color(0xFFEF4444),
                    colorBlendMode: hasEnough ? null : BlendMode.modulate,
                  )
                : Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Text(
            '-${_formatShopValue(amount)}',
            style: TextStyle(
              fontFamily: 'monospace',
              color: hasEnough
                  ? color.withValues(alpha: 0.9)
                  : const Color(0xFFEF4444),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'have ${_formatShopValue(current)}',
            style: TextStyle(
              fontFamily: 'monospace',
              color: hasEnough
                  ? t.textMuted
                  : const Color(0xFFEF4444).withValues(alpha: 0.7),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ============= CENTRALIZED PREVIEW BUILDER =============
Widget _buildOfferPreview(
  ShopOffer offer, {
  double size = 64.0,
  required FactionTheme theme,
}) {
  // 0b. Alchemical powerup orb — render glowing sphere in stat color
  if (offer.id.startsWith('boost.powerup.')) {
    final type = AlchemicalPowerupType.values.firstWhere(
      (t) => offer.id == t.shopOfferId,
      orElse: () => AlchemicalPowerupType.speed,
    );
    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.94),
              type.color.withValues(alpha: 0.88),
              type.glowColor.withValues(alpha: 0.36),
              Colors.transparent,
            ],
            stops: const [0.0, 0.30, 0.66, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: type.glowColor.withValues(alpha: 0.55),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  // 0. Survival orb skin — render the radiant orb sphere
  if (offer.id.startsWith('survival.orb.')) {
    final orbDef = kOrbBases.where((d) => d.shopId == offer.id);
    if (orbDef.isNotEmpty) {
      final def = orbDef.first;
      return Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                def.glowColor.withValues(alpha: 0.7),
                def.primaryColor,
                def.secondaryColor,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: def.glowColor.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
      );
    }
  }

  // 1. Try animated preview for alchemy effects
  if (offer.inventoryKey != null) {
    final preview = ShopService.getAlchemyEffectPreview(
      offer.inventoryKey!,
      size: size,
    );
    if (preview != null) {
      return Center(
        child: SizedBox.square(
          dimension: size,
          child: ExcludeSemantics(child: preview),
        ),
      );
    }
  }

  if (offer.id.startsWith('unlock.storage_cap.') && offer.assetName != null) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          offer.assetName!,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            offer.icon,
            size: size * 0.8,
            color: offer.iconColor ?? theme.text,
          ),
        ),
      ),
    );
  }

  // 2. Try static image
  if (offer.assetName != null) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          offer.assetName!,
          fit: BoxFit.contain,
          color: offer.imageColor,
          colorBlendMode: offer.imageColor != null ? BlendMode.multiply : null,
          errorBuilder: (_, __, ___) => Icon(
            offer.icon,
            size: size * 0.8,
            color: offer.iconColor ?? theme.text,
          ),
        ),
      ),
    );
  }

  // 3. Fallback to icon
  return Center(
    child: Icon(
      offer.icon,
      size: size * 0.8,
      color: offer.iconColor ?? theme.text,
    ),
  );
}

// Special preview builder for dialogs (handles daily vials)
Widget _buildOfferPreviewForDialog(
  ShopOffer offer, {
  double size = 120.0,
  required FactionTheme theme,
}) {
  // SPECIAL CASE: DAILY VIAL - Show actual vial card
  if (offer.id.startsWith('vial.daily.common.')) {
    final groupName = offer.id.split('.').last;
    final group = ElementalGroup.values.firstWhere(
      (g) => g.name == groupName,
      orElse: () => ElementalGroup.volcanic,
    );
    final price = offer.cost['silver'] ?? 100;

    final vialModel = ExtractionVial(
      id: offer.id,
      name: '${group.displayName} Vial',
      group: group,
      rarity: VialRarity.common,
      quantity: 1,
      price: price,
    );

    return Center(
      child: SizedBox(
        height: 140,
        child: ExtractionVialCard(
          vial: vialModel,
          compact: false,
          onAddToInventory: null,
          onTap: null,
        ),
      ),
    );
  }

  // Otherwise use the standard preview logic
  return _buildOfferPreview(offer, size: size, theme: theme);
}

// ============= NEW GAME SHOP CARD =============

class GameShopCard extends StatelessWidget {
  final String title;
  final ShopOffer offer; // Pass entire offer instead of individual fields
  final FactionTheme theme;
  final bool enabled;
  final bool canAfford;
  final List<Widget> costWidgets;
  final String? displayLabel;
  final String? statusText;

  const GameShopCard({
    super.key,
    required this.title,
    required this.offer,
    required this.theme,
    required this.enabled,
    required this.canAfford,
    required this.costWidgets,
    this.displayLabel,
    this.statusText,
  });

  String get _cardLabel => (displayLabel ?? title).toUpperCase();

  double get _cardLabelFontSize => 8.0;

  EdgeInsets get _cardLabelPadding =>
      const EdgeInsets.symmetric(horizontal: 6, vertical: 3);

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    Color? overlayColor;
    if (!enabled) {
      overlayColor = Colors.transparent;
    } else if (!canAfford) {
      overlayColor = const Color.fromARGB(
        86,
        244,
        67,
        54,
      ).withValues(alpha: 0.3);
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.surface.withValues(alpha: theme.isDark ? 0.1 : 0.72),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: !enabled
              ? theme.text.withValues(alpha: 0.3)
              : !canAfford
              ? Colors.red.withValues(alpha: 0.5)
              : theme.accent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image / Preview area - SIMPLIFIED
              Expanded(
                child: Container(
                  color: theme.isDark
                      ? Colors.black.withValues(alpha: 0.05)
                      : t.bg2.withValues(alpha: 0.8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildOfferPreview(
                          offer,
                          size: 64.0,
                          theme: theme,
                        ),
                      ),
                      if (_cardLabel.isNotEmpty)
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: _cardLabelPadding,
                            decoration: BoxDecoration(
                              color: theme.isDark
                                  ? t.bg0.withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: theme.accent.withValues(alpha: 0.28),
                              ),
                            ),
                            child: Text(
                              _cardLabel,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textPrimary,
                                fontSize: _cardLabelFontSize,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Cost area
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: costWidgets,
                ),
              ),
            ],
          ),

          // Overlay (locked / unaffordable)
          if (overlayColor != null)
            Positioned.fill(
              child: Container(
                color: overlayColor,
                alignment: Alignment.center,
                child: Icon(
                  !enabled ? Icons.check_circle : Icons.lock,
                  color: theme.isDark
                      ? Colors.white.withValues(alpha: 0.8)
                      : t.textPrimary.withValues(alpha: 0.8),
                  size: 32,
                ),
              ),
            ),

          // Status / inventory badge
          if (statusText != null && statusText!.isNotEmpty && enabled)
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.isDark
                      ? theme.accent.withValues(alpha: 0.9)
                      : theme.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : theme.accent.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  statusText!,
                  style: TextStyle(
                    color: theme.isDark ? Colors.white : theme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// *** REPLACING SliverSectionHeader with a standard Widget ***
class SectionHeader extends StatelessWidget {
  final String title;
  final Color accent;
  final Color backgroundColor;

  const SectionHeader({
    super.key,
    required this.title,
    required this.accent,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: accent,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// SliverSectionHeader and _SliverSectionHeaderDelegate are removed.
// SliverSubSectionHeader is removed as it's not used in shop_screen.dart

class MiniCostChip extends StatelessWidget {
  final ElementResource resource;
  final int required;
  final int current;

  const MiniCostChip({
    super.key,
    required this.resource,
    required this.required,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final displayColor = t.readableAccent(resource.color);
    final hasEnough = current >= required;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasEnough
            ? displayColor.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasEnough
              ? displayColor.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resource.icon,
            size: 10,
            color: hasEnough ? displayColor : Colors.red.shade300,
          ),
          const SizedBox(width: 3),
          Text(
            '$required',
            style: TextStyle(
              color: hasEnough ? displayColor : Colors.red.shade300,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// Tab button widget (from BlackMarketScreen)
class TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color accent; // Made this dynamic

  const TabButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? accent.withValues(alpha: 0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? accent.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? accent : t.textMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accent : t.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CostChip extends StatelessWidget {
  final String currencyType;
  final int amount;
  final int available;

  const CostChip({
    super.key,
    required this.currencyType,
    required this.amount,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final hasEnough = available >= amount;
    final (icon, rawColor) = _getCurrencyDisplay(currencyType, theme);
    final color = t.readableAccent(rawColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasEnough
            ? color.withValues(alpha: theme.isDark ? 0.0 : 0.12)
            : Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasEnough
              ? color.withValues(alpha: 0.4)
              : Colors.red.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: hasEnough ? color : Colors.red.shade300),
          const SizedBox(width: 3),
          Text(
            _formatShopValue(amount),
            style: TextStyle(
              color: hasEnough ? color : Colors.red.shade300,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getCurrencyDisplay(String type, FactionTheme theme) {
    switch (type) {
      case 'gold':
        return (Icons.hexagon_rounded, const Color.fromARGB(255, 184, 138, 1));
      case 'silver':
        return (Icons.monetization_on_rounded, theme.text);
      case 'soft':
        return (Icons.diamond_rounded, const Color(0xFFB388FF));
      // resources (fall through to correct icons/colors)
      case 'res_volcanic':
        return (Icons.local_fire_department_rounded, Colors.orange.shade400);
      case 'res_oceanic':
        return (Icons.water_drop_rounded, Colors.blue.shade400);
      case 'res_verdant':
        return (Icons.eco_rounded, Colors.green.shade400);
      case 'res_earthen':
        return (Icons.terrain_rounded, Colors.brown.shade400);
      case 'res_arcane':
        return (Icons.auto_awesome_rounded, Colors.purple.shade400);
      default:
        return (Icons.circle, theme.textMuted);
    }
  }
}

// EmptySection is unchanged...

class EmptySection extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptySection({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.bg2.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.borderDim),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: t.textMuted),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============= MARKETPLACE SECTION (MODIFIED to a standard Widget) =============

class MarketplaceGrid extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, int> allCurrencies; // Data passed in
  final Map<String, int> inventory;

  const MarketplaceGrid({
    super.key,
    required this.theme,
    required this.allCurrencies,
    required this.inventory,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final offers = ShopService.allOffers;

        // shop_widgets.dart

        final sortedOffers = offers.toList()
          ..sort((a, b) {
            final aLimit = a.limit;
            final bLimit = b.limit;
            if (aLimit != bLimit) {
              // order: once, daily, unlimited
              const order = {'once': 0, 'daily': 1, 'unlimited': 2};

              // FIX: Use '?? 999' to provide a safe default value if the limit string
              // is unexpected. This pushes unknown limits to the end of the sort order.
              return (order[aLimit.name] ?? 999).compareTo(
                order[bLimit.name] ?? 999,
              );
            }
            return a.name.compareTo(b.name);
          });

        final offerCards = <Widget>[];

        for (final offer in sortedOffers) {
          final currencies = allCurrencies;

          final canPurchase = shopService.canPurchase(offer.id);
          final canAffordUnit = offer.cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );

          // INVENTORY-DRIVEN STATUS
          final invKey = offer.inventoryKey;
          final isInventoryable = invKey != null;
          final invQty = isInventoryable ? (inventory[invKey] ?? 0) : 0;
          final status = isInventoryable && invQty > 0 ? 'x$invQty' : null;

          // Build cost chips
          final costWidgets = <Widget>[
            for (final entry in offer.cost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: currencies[entry.key] ?? 0,
              ),
          ];

          offerCards.add(
            GestureDetector(
              onTap: () async {
                // Handle purchase here
                final qty = await showPurchaseConfirmationDialog(
                  context: context,
                  offer: offer,
                  theme: theme,
                  currencies: currencies,
                );
                if (qty == null) return;
                HapticFeedback.lightImpact();
                final success = await shopService.purchase(offer.id, qty: qty);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            success
                                ? '${offer.name} purchased x$qty!'
                                : 'Purchase failed',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: success
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: GameShopCard(
                key: ValueKey('offer-${offer.id}'),
                title: offer.name,
                offer: offer, // ✅ JUST PASS THE OFFER
                theme: theme,
                costWidgets: costWidgets,
                statusText: status,
                enabled: canPurchase,
                canAfford: canAffordUnit,
                // ❌ REMOVE: description, icon, image, onPressed
              ),
            ),
          );
        }

        // Return a standard GridView wrapped in Padding
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true, // IMPORTANT
            physics: const NeverScrollableScrollPhysics(), // IMPORTANT
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.6,
            children: offerCards,
          ),
        );
      },
    );
  }
}
// ============= FARM UNLOCK SECTION (MODIFIED to a standard Widget) =============

class FarmUnlockSection extends StatelessWidget {
  final FactionTheme theme;
  final bool showPurchased;
  final Map<String, int> resourceBalances;

  const FarmUnlockSection({
    super.key,
    required this.theme,
    required this.showPurchased,
    required this.resourceBalances,
  });

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return FutureBuilder<List<Widget?>>(
      future: Future.wait([
        _farmCard(context, db, 'Volcanic', Biome.volcanic),
        _farmCard(context, db, 'Oceanic', Biome.oceanic),
        _farmCard(context, db, 'Verdant', Biome.verdant),
        _farmCard(context, db, 'Earthen', Biome.earthen),
        _farmCard(context, db, 'Arcane', Biome.arcane),
      ]),
      builder: (context, snap) {
        // LOADING
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final children = (snap.data ?? const []).whereType<Widget>().toList();

        // EMPTY
        if (children.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12.0),
            child: EmptySection(
              message: 'All farms unlocked',
              icon: Icons.check_circle_outline_rounded,
            ),
          );
        }

        // GRID -> standard GridView
        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true, // IMPORTANT
            physics: const NeverScrollableScrollPhysics(), // IMPORTANT
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: children,
          ),
        );
      },
    );
  }

  // Helper to create a farm card widget (now returns a keyed card)
  Future<Widget?> _farmCard(
    BuildContext context,
    AlchemonsDatabase db,
    String label,
    Biome biome,
  ) async {
    final farm = await db.biomeDao.getBiomeByBiomeId(biome.id);
    final unlocked = farm?.unlocked == true;

    if (unlocked && !showPurchased) return null;

    final cost = UnlockCosts.biome(biome);
    final balances = resourceBalances;
    final canAfford = cost.entries.every(
      (e) => (balances[e.key] ?? 0) >= e.value,
    );

    // Build cost chips
    final costWidgets = <Widget>[
      for (final res in ElementResources.all)
        if ((cost[res.settingsKey] ?? 0) > 0)
          MiniCostChip(
            resource: res,
            required: cost[res.settingsKey]!,
            current: balances[res.settingsKey] ?? 0,
          ),
    ];

    IconData icon;
    switch (biome) {
      case Biome.volcanic:
        icon = Icons.local_fire_department_outlined;
        break;
      case Biome.oceanic:
        icon = Icons.water_outlined;
        break;
      case Biome.verdant:
        icon = Icons.eco_outlined;
        break;
      case Biome.earthen:
        icon = Icons.terrain_outlined;
        break;
      case Biome.arcane:
        icon = Icons.auto_awesome_outlined;
        break;
    }

    // Create a pseudo-offer for consistent handling
    final farmOffer = ShopOffer(
      id: 'farm.${biome.name}',
      name: '$label Farm',
      description: 'Unlock this biome to harvest its resources.',
      icon: icon,
      cost: cost,
      reward: const {},
      rewardType: 'unlock',
      limit: PurchaseLimit.once,
      inventoryKey: null,
      assetName: null,
    );

    final card = GameShopCard(
      key: ValueKey('farm-${biome.id}'),
      title: '$label Farm',
      offer: farmOffer, // Pass the pseudo-offer
      theme: theme,
      costWidgets: costWidgets,
      enabled: !unlocked,
      canAfford: canAfford,
    );

    return GestureDetector(
      onTap: () async {
        if (unlocked) {
          // Already unlocked - just show details
          await showItemDetailDialog(
            context: context,
            offer: farmOffer,
            theme: theme,
            currencies: balances,
            inventoryQty: 0,
            canPurchase: false, // Already purchased
            canAfford: false,
          );
        } else {
          // Not unlocked - show details with purchase option
          final shouldProceed = await showItemDetailDialog(
            context: context,
            offer: farmOffer,
            theme: theme,
            currencies: balances,
            inventoryQty: 0,
            canPurchase: true,
            canAfford: canAfford,
          );

          if (!shouldProceed || !context.mounted) return;

          // User confirmed purchase in detail dialog, proceed with unlock
          HapticFeedback.lightImpact();
          final ok = await db.biomeDao.unlockBiome(
            biomeId: biome.id,
            cost: cost,
          );

          if (!context.mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(
                    ok ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ok ? '$label farm unlocked!' : 'Not enough resources',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: ok ? Colors.green.shade700 : Colors.orange,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      child: card,
    );
  }
}

// ============= DIALOGS AND DIALOG HELPERS (Unchanged) =============

Future<bool> showBiomeUnlockConfirmationDialog({
  required BuildContext context,
  required String biomeName,
  required IconData biomeIcon,
  required Map<String, int> cost,
  required Map<String, int> resourceBalances,
  required FactionTheme theme,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: const Color(0xFF1A1D23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.accent.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(biomeIcon, color: theme.accent, size: 36),
                const SizedBox(height: 12),
                Text(
                  '$biomeName Farm',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock this biome to harvest its resources.',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                DialogSectionHeader(title: 'COST', color: Colors.red.shade300),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      for (final entry in cost.entries)
                        DialogResourceDisplay(
                          type: entry.key,
                          amount: entry.value,
                          current: resourceBalances[entry.key] ?? 0,
                          isSpending: true,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                DialogSectionHeader(
                  title: 'REWARD',
                  color: Colors.green.shade300,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      DialogResourceDisplay(
                        type: biomeName.toLowerCase() == 'volcanic'
                            ? 'res_volcanic'
                            : biomeName.toLowerCase() == 'oceanic'
                            ? 'res_oceanic'
                            : biomeName.toLowerCase() == 'verdant'
                            ? 'res_verdant'
                            : biomeName.toLowerCase() == 'earthen'
                            ? 'res_earthen'
                            : 'res_arcane',
                        amount: 1,
                        isSpending: false,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '$biomeName Farm Unlocked',
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade800.withValues(
                            alpha: 0.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: TextButton.styleFrom(
                          backgroundColor: theme.accent.withValues(alpha: 0.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: theme.accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

Future<int?> showPurchaseConfirmationDialog({
  required BuildContext context,
  required ShopOffer offer,
  required FactionTheme theme,
  required Map<String, int> currencies,
  Map<String, int>? effectiveCost, // 👈 ADD THIS PARAMETER
}) async {
  int qty = 1;
  final shopService = context.read<ShopService>();
  final t = ForgeTokens(theme);
  final primaryAccent = t.readableAccent(t.amberBright);
  final canQty = shopService.allowsQuantity(offer);

  Map<String, int> previewCost() {
    final m = <String, int>{};
    // 👇 USE effectiveCost if provided, otherwise fall back to offer.cost
    final baseCost = effectiveCost ?? offer.cost;
    baseCost.forEach((k, v) => m[k] = v * qty);
    return m;
  }

  List<Widget> buildRewardWidgets() {
    final List<Widget> widgets = [];
    if (offer.rewardType == 'currency' || offer.rewardType == 'resources') {
      for (final entry in offer.reward.entries) {
        final amount = (entry.value as int) * qty;
        widgets.add(
          DialogResourceDisplay(
            type: entry.key,
            amount: amount,
            isSpending: false,
          ),
        );
      }
    } else if (offer.rewardType == 'bundle') {
      if (offer.reward.containsKey('gold')) {
        widgets.add(
          DialogResourceDisplay(
            type: 'gold',
            amount: (offer.reward['gold'] as int) * qty,
            isSpending: false,
          ),
        );
      }
      if (offer.reward.containsKey('silver')) {
        widgets.add(
          DialogResourceDisplay(
            type: 'silver',
            amount: (offer.reward['silver'] as int) * qty,
            isSpending: false,
          ),
        );
      }
      if (offer.reward.containsKey('resources')) {
        final resources = offer.reward['resources'] as Map<String, dynamic>;
        for (final entry in resources.entries) {
          widgets.add(
            DialogResourceDisplay(
              type: entry.key,
              amount: (entry.value as int) * qty,
              isSpending: false,
            ),
          );
        }
      }
    } else if (offer.rewardType == 'boost') {
      widgets.add(
        Text(
          'Applies effect on purchase',
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    if (widgets.isEmpty) {
      widgets.add(
        Text(
          'Rewards not specified',
          style: TextStyle(color: t.textMuted, fontSize: 12),
        ),
      );
    }
    return widgets;
  }

  return await showDialog<int?>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) => Dialog(
          backgroundColor: t.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: BorderSide(color: t.borderAccent, width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Text(
                    'CONFIRM PURCHASE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: primaryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ── Item icon + name ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        offer.icon,
                        color: offer.iconColor ?? theme.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          offer.name + (canQty && qty > 1 ? '  ×$qty' : ''),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textSecondary,
                      fontSize: 10,
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                  // ── Quantity picker ──────────────────────────────────────
                  if (canQty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.borderDim),
                        borderRadius: BorderRadius.circular(3),
                        color: t.bg2,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (qty > 1) setState(() => qty--);
                            },
                            child: Icon(
                              Icons.remove_rounded,
                              size: 18,
                              color: qty > 1 ? t.textPrimary : t.textMuted,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Text(
                            'x$qty',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () {
                              if (qty < 999) setState(() => qty++);
                            },
                            child: Icon(
                              Icons.add_rounded,
                              size: 18,
                              color: t.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // ── Cost ────────────────────────────────────────────────
                  _MonoSectionHeader(
                    label: 'COST',
                    color: const Color(0xFFE06060),
                  ),
                  const SizedBox(height: 8),
                  for (final entry in previewCost().entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: DialogResourceDisplay(
                        type: entry.key,
                        amount: entry.value,
                        current: currencies[entry.key] ?? 0,
                        isSpending: true,
                      ),
                    ),
                  const SizedBox(height: 14),
                  // ── Reward ───────────────────────────────────────────────
                  _MonoSectionHeader(
                    label: 'REWARD',
                    color: const Color(0xFF88EE88),
                  ),
                  const SizedBox(height: 8),
                  ...buildRewardWidgets().map(
                    (w) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: w,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Buttons ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: t.borderDim),
                              borderRadius: BorderRadius.circular(3),
                              color: t.bg2,
                            ),
                            child: Text(
                              'CANCEL',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(ctx, qty),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: t.borderAccent,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(3),
                              color: t.amberDim.withValues(alpha: 0.18),
                              boxShadow: [
                                BoxShadow(
                                  color: t.amber.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              'CONFIRM',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: primaryAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

// ── Monospace section divider used in the purchase dialog ───────────────────
class _MonoSectionHeader extends StatelessWidget {
  final String label;
  final Color color;

  const _MonoSectionHeader({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.25)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.25)),
        ),
      ],
    );
  }
}

class DialogSectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const DialogSectionHeader({
    super.key,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.3)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        Expanded(
          child: Container(height: 1, color: color.withValues(alpha: 0.3)),
        ),
      ],
    );
  }
}

class DialogResourceDisplay extends StatelessWidget {
  final String type;
  final int amount;
  final int? current; // Optional: Current amount the player has
  final bool isSpending;

  const DialogResourceDisplay({
    super.key,
    required this.type,
    required this.amount,
    this.current,
    required this.isSpending,
  });

  // Helper to get all display info (icon, label, color)
  (IconData, String, Color) _getDisplayInfo(String type) {
    switch (type) {
      // Currencies
      case 'gold':
        return (Icons.hexagon_rounded, 'Gold', const Color(0xFFB45309));
      case 'silver':
        return (Icons.monetization_on_rounded, 'Silver', Colors.grey.shade300);
      case 'soft':
        return (Icons.diamond_rounded, 'Shards', const Color(0xFFB388FF));
      // Resources
      case 'res_volcanic':
        return (
          Icons.local_fire_department_rounded,
          'Volcanic',
          Colors.orange.shade400,
        );
      case 'res_oceanic':
        return (Icons.water_drop_rounded, 'Oceanic', Colors.blue.shade400);
      case 'res_verdant':
        return (Icons.eco_rounded, 'Verdant', Colors.green.shade400);
      case 'res_earthen':
        return (Icons.terrain_rounded, 'Earthen', Colors.brown.shade400);
      case 'res_arcane':
        return (Icons.auto_awesome_rounded, 'Arcane', Colors.purple.shade400);
      default:
        return (Icons.circle, type, const Color(0xFF475569));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = _getDisplayInfo(type);
    final hasEnough = current != null ? current! >= amount : true;
    final theme = context.read<FactionTheme>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Amount being spent/gained
          Text(
            '${isSpending ? '-' : '+'}${_formatShopValue(amount)}',
            style: TextStyle(
              color: isSpending
                  ? (hasEnough ? Colors.red.shade300 : Colors.red.shade400)
                  : Colors.green.shade300,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          // Current holdings (if provided)
          if (current != null)
            Padding(
              padding: const EdgeInsets.only(left: 6.0),
              child: Text(
                '(Have: ${_formatShopValue(current!)})',
                style: TextStyle(
                  color: hasEnough ? theme.textMuted : Colors.red.shade400,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
