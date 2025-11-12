// lib/widgets/shop_widgets.dart
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ============= SUPPORTING WIDGETS =============
// ShowPurchasedToggle and CurrencyPill are unchanged...

class ShowPurchasedToggle extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  const ShowPurchasedToggle({
    super.key,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value
              ? accent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          // Changed border to a shadow for a softer look
          boxShadow: [
            BoxShadow(
              color: value
                  ? accent.withOpacity(0.3)
                  : Colors.black.withOpacity(0.3),
              blurRadius: 2,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              size: 12,
              color: value ? accent : Colors.white70,
            ),
            const SizedBox(width: 4),
            Text(
              value ? 'ALL' : 'NEW',
              style: TextStyle(
                color: value ? accent : Colors.white70,
                fontSize: 9,
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
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1e3).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          _format(amount),
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// Enhanced Item Detail Dialog
// Add this to your shop_widgets.dart or create a new file for dialogs

/// Shows a detailed view of a shop item before the purchase confirmation
Future<bool> showItemDetailDialog({
  required BuildContext context,
  required ShopOffer offer,
  required FactionTheme theme,
  required Map<String, int> currencies,
  required int inventoryQty,
  required bool canPurchase,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.accent.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with close button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ITEM DETAILS',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white.withOpacity(0.7),
                        iconSize: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Image Section
                Container(
                  height: 160,
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.accent.withOpacity(0.2)),
                  ),
                  child: offer.assetName != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            offer.assetName!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : Icon(
                          offer.icon,
                          size: 80,
                          color: theme.accent.withOpacity(0.6),
                        ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    offer.name,
                    style: TextStyle(
                      color: theme.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 8),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    offer.description,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 16),

                // Inventory Count (if applicable)
                if (inventoryQty > 0)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_rounded,
                          color: theme.accent,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'You own: $inventoryQty',
                          style: TextStyle(
                            color: theme.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                // Cost Section
                DialogSectionHeader(
                  title: 'COST',
                  color: Colors.amber.shade300,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      for (final entry in offer.cost.entries)
                        DialogResourceDisplay(
                          type: entry.key,
                          amount: entry.value,
                          current: currencies[entry.key] ?? 0,
                          isSpending: true,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: TextButton.styleFrom(
                            backgroundColor: theme.surface,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'BACK',
                            style: TextStyle(
                              color: theme.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Visibility(
                        visible: canPurchase,
                        child: Expanded(
                          flex: 2,
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: TextButton.styleFrom(
                              backgroundColor: theme.accent.withOpacity(0.2),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: theme.accent.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.shopping_cart_rounded,
                                  color: theme.text,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'PURCHASE',
                                  style: TextStyle(
                                    color: theme.text,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
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

// ============= NEW GAME SHOP CARD =============

// UPDATED GameShopCard widget - SIMPLIFIED to image + cost only
// Replace the existing GameShopCard in your shop_widgets.dart with this version

class GameShopCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final FactionTheme theme;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool canAfford;

  /// The list of cost widgets (e.g., MiniCostChip or CostChip)
  final List<Widget> costWidgets;

  /// Optional text for a corner tag (e.g., "x3")
  final String? statusText;

  /// Optional description text (not shown on card, used in detail dialog)
  final String? description;
  final String? image;

  const GameShopCard({
    super.key,
    required this.title,
    required this.icon,
    required this.theme,
    this.onPressed,
    required this.enabled,
    required this.canAfford,
    required this.costWidgets,
    this.statusText,
    this.description,
    this.image,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the status overlay color
    Color? overlayColor;
    if (!enabled) {
      overlayColor = Colors.transparent;
    } else if (!canAfford) {
      overlayColor = const Color.fromARGB(86, 244, 67, 54).withOpacity(0.3);
    }

    return GestureDetector(
      onTap: (enabled && canAfford) ? onPressed : null,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: !enabled
                ? theme.text.withOpacity(0.3)
                : !canAfford
                ? Colors.red.withOpacity(0.5)
                : theme.accent.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Area
                Expanded(
                  child: Container(
                    color: Colors.white.withOpacity(0.05),
                    child: image != null
                        ? Image.asset(image!, fit: BoxFit.contain)
                        : Icon(
                            icon,
                            size: 48,
                            color: theme.accent.withOpacity(0.6),
                          ),
                  ),
                ),

                // Cost Area at bottom
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: costWidgets,
                  ),
                ),
              ],
            ),

            // Overlay for locked/owned states
            if (overlayColor != null)
              Positioned.fill(
                child: Container(
                  color: overlayColor,
                  alignment: Alignment.center,
                  child: Icon(
                    !enabled ? Icons.check_circle : Icons.lock,
                    color: Colors.white.withOpacity(0.8),
                    size: 32,
                  ),
                ),
              ),

            // Inventory count badge
            if (statusText != null && statusText!.isNotEmpty && enabled)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.accent.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
            color: Colors.black.withOpacity(0.1),
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
    final hasEnough = current >= required;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasEnough
            ? resource.color.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasEnough
              ? resource.color.withOpacity(0.4)
              : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resource.icon,
            size: 10,
            color: hasEnough ? resource.color : Colors.red.shade300,
          ),
          const SizedBox(width: 3),
          Text(
            '$required',
            style: TextStyle(
              color: hasEnough ? resource.color : Colors.red.shade300,
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? accent.withOpacity(0.4) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? accent.withOpacity(0.6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? accent : Colors.white60),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? accent : Colors.white60,
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
    final hasEnough = available >= amount;
    final (icon, color) = _getCurrencyDisplay(currencyType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: hasEnough
            ? color.withOpacity(0.15)
            : Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hasEnough
              ? color.withOpacity(0.4)
              : Colors.red.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: hasEnough ? color : Colors.red.shade300),
          const SizedBox(width: 3),
          Text(
            '$amount',
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

  (IconData, Color) _getCurrencyDisplay(String type) {
    switch (type) {
      case 'gold':
        return (Icons.diamond_rounded, Colors.amber);
      case 'silver':
        return (Icons.monetization_on_rounded, Colors.grey.shade300);
      case 'soft':
        return (Icons.paid_rounded, Colors.lightBlue);
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
        return (Icons.circle, Colors.white70);
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3), // Already transparent, good
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
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
              return (order[aLimit] ?? 999).compareTo(order[bLimit] ?? 999);
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
            GameShopCard(
              key: ValueKey('offer-${offer.id}'),
              title: offer.name,
              description: offer.description,
              icon: offer.icon,
              image: offer.assetName,
              theme: theme,
              costWidgets: costWidgets,
              statusText: status,
              enabled: canPurchase, // enabled even if can’t afford
              canAfford: canAffordUnit, // controls LOCKED vs PURCHASE tag
              onPressed: () async {
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
      default:
        icon = Icons.terrain_outlined;
    }

    return GameShopCard(
      key: ValueKey('farm-${biome.id}'), // <- STABLE UNIQUE KEY
      icon: icon,
      title: '$label Farm',
      theme: theme,
      costWidgets: costWidgets,
      enabled: !unlocked,
      canAfford: canAfford,
      onPressed: () async {
        final bool confirmed = await showBiomeUnlockConfirmationDialog(
          context: context,
          biomeName: label,
          biomeIcon: icon,
          cost: cost,
          resourceBalances: resourceBalances,
          theme: theme,
        );

        if (!confirmed) return;
        HapticFeedback.lightImpact();

        final ok = await db.biomeDao.unlockBiome(biomeId: biome.id, cost: cost);
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
      },
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
            side: BorderSide(color: theme.accent.withOpacity(0.5), width: 2),
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
                    color: Colors.white.withOpacity(0.9),
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
                          backgroundColor: Colors.grey.shade800.withOpacity(
                            0.5,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
                          backgroundColor: theme.accent.withOpacity(0.2),
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
}) async {
  int qty = 1;
  final shopService = context.read<ShopService>();
  final canQty = shopService.allowsQuantity(offer);

  Map<String, int> previewCost() {
    final m = <String, int>{};
    offer.cost.forEach((k, v) => m[k] = v * qty);
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
          style: TextStyle(color: Colors.white54, fontSize: 12),
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
          backgroundColor: const Color(0xFF1A1D23),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.accent.withOpacity(0.5), width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              // Added SingleChildScrollView for small screens
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(offer.icon, color: theme.accent, size: 36),
                  const SizedBox(height: 12),
                  Text(
                    offer.name + (canQty && qty > 1 ? '  x$qty' : ''),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    offer.description,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (canQty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (qty > 1) setState(() => qty--);
                          },
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 22,
                          ),
                        ),
                        Text(
                          'x$qty',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (qty < 999) setState(() => qty++);
                          },
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  DialogSectionHeader(
                    title: 'COST',
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Column(
                      children: [
                        for (final entry in previewCost().entries)
                          DialogResourceDisplay(
                            type: entry.key,
                            amount: entry.value,
                            current: currencies[entry.key] ?? 0,
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
                    child: Column(children: buildRewardWidgets()),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.grey.shade800.withOpacity(
                              0.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
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
                          onPressed: () => Navigator.pop(ctx, qty),
                          style: TextButton.styleFrom(
                            backgroundColor: theme.accent.withOpacity(0.2),
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
        ),
      );
    },
  );
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
        Expanded(child: Container(height: 1, color: color.withOpacity(0.3))),
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
        Expanded(child: Container(height: 1, color: color.withOpacity(0.3))),
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
        return (Icons.diamond_rounded, 'Gold', Colors.amber);
      case 'silver':
        return (Icons.monetization_on_rounded, 'Silver', Colors.grey.shade300);
      case 'soft':
        return (Icons.paid_rounded, 'Soft', Colors.lightBlue);
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
        return (Icons.circle, type, Colors.white);
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
            '${isSpending ? '-' : '+'}$amount',
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
                '(Have: $current)',
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
