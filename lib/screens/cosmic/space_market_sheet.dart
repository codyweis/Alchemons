// lib/screens/cosmic/space_market_sheet.dart
//
// Bottom-sheet shop for the two space markets:
//   • Harvester Shop  — sells faction harvesters + stabilized harvester
//   • Rift Key Shop   — sells faction portal keys
//
// Prices mirror the main Research Shop.
// Shows gold, silver, and carried cosmic shards in the header.
// Supports a 50 % elemental-meter discount: if the player's current
// alchemical meter has ≥ 50 % of a required element, the item is half price.
// Discount recipes rotate every 4 hours.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ITEM DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _MarketItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String? assetName;
  final String inventoryKey;
  final Map<String, int> baseCost;
  final String faction; // volcanic, oceanic, verdant, earthen, arcane, neutral

  const _MarketItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.assetName,
    required this.inventoryKey,
    required this.baseCost,
    required this.faction,
  });
}

const _harvesterItems = <_MarketItem>[
  _MarketItem(
    id: 'market.harvest.volcanic',
    name: 'Wild Harvester – Volcanic',
    description: 'Standard capture device for volcanic creatures.',
    icon: Icons.local_fire_department_rounded,
    iconColor: Color(0xFFFF5722),
    assetName: 'assets/images/ui/volcanicharvester.png',
    inventoryKey: 'item.harvest_std_volcanic',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'volcanic',
  ),
  _MarketItem(
    id: 'market.harvest.oceanic',
    name: 'Wild Harvester – Oceanic',
    description: 'Standard capture device for oceanic creatures.',
    icon: Icons.water_rounded,
    iconColor: Color(0xFF64B5F6),
    assetName: 'assets/images/ui/oceanicharvester.png',
    inventoryKey: 'item.harvest_std_oceanic',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'oceanic',
  ),
  _MarketItem(
    id: 'market.harvest.verdant',
    name: 'Wild Harvester – Verdant',
    description: 'Standard capture device for verdant creatures.',
    icon: Icons.eco_rounded,
    iconColor: Color(0xFF66BB6A),
    assetName: 'assets/images/ui/verdantharvester.png',
    inventoryKey: 'item.harvest_std_verdant',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'verdant',
  ),
  _MarketItem(
    id: 'market.harvest.earthen',
    name: 'Wild Harvester – Earthen',
    description: 'Standard capture device for earthen creatures.',
    icon: Icons.terrain_rounded,
    iconColor: Color(0xFF8D6E63),
    assetName: 'assets/images/ui/earthenharvester.png',
    inventoryKey: 'item.harvest_std_earthen',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'earthen',
  ),
  _MarketItem(
    id: 'market.harvest.arcane',
    name: 'Wild Harvester – Arcane',
    description: 'Standard capture device for arcane creatures.',
    icon: Icons.auto_awesome_rounded,
    iconColor: Color(0xFFCE93D8),
    assetName: 'assets/images/ui/arcaneharvester.png',
    inventoryKey: 'item.harvest_std_arcane',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'arcane',
  ),
  _MarketItem(
    id: 'market.harvest.stabilized',
    name: 'Stabilized Harvester',
    description: 'Guaranteed capture — never fails.',
    icon: Icons.shield_rounded,
    iconColor: Color(0xFFFFD700),
    assetName: 'assets/images/ui/universalharvest.png',
    inventoryKey: 'item.harvest_guaranteed',
    baseCost: {'gold': 1},
    faction: 'neutral',
  ),
];

const _riftKeyItems = <_MarketItem>[
  _MarketItem(
    id: 'market.key.volcanic',
    name: 'Volcanic Portal Key',
    description: 'Grants entry into a Volcanic Rift. Consumed on entry.',
    icon: Icons.vpn_key_rounded,
    iconColor: Color(0xFFFF5722),
    assetName: 'assets/images/ui/volcanickey.png',
    inventoryKey: 'item.portal_key.volcanic',
    baseCost: {'gold': 5},
    faction: 'volcanic',
  ),
  _MarketItem(
    id: 'market.key.oceanic',
    name: 'Oceanic Portal Key',
    description: 'Grants entry into an Oceanic Rift. Consumed on entry.',
    icon: Icons.vpn_key_rounded,
    iconColor: Color(0xFF64B5F6),
    assetName: 'assets/images/ui/oceanickey.png',
    inventoryKey: 'item.portal_key.oceanic',
    baseCost: {'gold': 5},
    faction: 'oceanic',
  ),
  _MarketItem(
    id: 'market.key.verdant',
    name: 'Verdant Portal Key',
    description: 'Grants entry into a Verdant Rift. Consumed on entry.',
    icon: Icons.vpn_key_rounded,
    iconColor: Color(0xFF66BB6A),
    assetName: 'assets/images/ui/verdantkey.png',
    inventoryKey: 'item.portal_key.verdant',
    baseCost: {'gold': 5},
    faction: 'verdant',
  ),
  _MarketItem(
    id: 'market.key.earthen',
    name: 'Earthen Portal Key',
    description: 'Grants entry into an Earthen Rift. Consumed on entry.',
    icon: Icons.vpn_key_rounded,
    iconColor: Color(0xFF8D6E63),
    assetName: 'assets/images/ui/earthenkey.png',
    inventoryKey: 'item.portal_key.earthen',
    baseCost: {'gold': 5},
    faction: 'earthen',
  ),
  _MarketItem(
    id: 'market.key.arcane',
    name: 'Arcane Portal Key',
    description: 'Grants entry into an Arcane Rift. Consumed on entry.',
    icon: Icons.vpn_key_rounded,
    iconColor: Color(0xFFCE93D8),
    assetName: 'assets/images/ui/arcanekey.png',
    inventoryKey: 'item.portal_key.arcane',
    baseCost: {'gold': 5},
    faction: 'arcane',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// SHEET
// ─────────────────────────────────────────────────────────────────────────────

class SpaceMarketSheet extends StatefulWidget {
  final POIType marketType;
  final ElementMeter meter;
  final int carriedShards;
  final bool Function(int amount) spendShards;

  const SpaceMarketSheet({
    super.key,
    required this.marketType,
    required this.meter,
    required this.carriedShards,
    required this.spendShards,
  });

  /// Show the market as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required POIType marketType,
    required ElementMeter meter,
    required int carriedShards,
    required bool Function(int amount) spendShards,
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpaceMarketSheet(
        marketType: marketType,
        meter: meter,
        carriedShards: carriedShards,
        spendShards: spendShards,
      ),
    );
  }

  @override
  State<SpaceMarketSheet> createState() => _SpaceMarketSheetState();
}

class _SpaceMarketSheetState extends State<SpaceMarketSheet> {
  late final List<_MarketItem> _items;
  late final Map<String, MarketDiscountRecipe> _recipes;
  late final String _title;
  late final Color _accent;
  late int _carriedShards;

  @override
  void initState() {
    super.initState();

    final isHarvester = widget.marketType == POIType.harvesterMarket;
    _items = isHarvester ? _harvesterItems : _riftKeyItems;
    _title = isHarvester ? 'HARVESTER SHOP' : 'RIFT KEY SHOP';
    _accent = isHarvester ? const Color(0xFFFFB300) : const Color(0xFF7C4DFF);
    _carriedShards = widget.carriedShards;

    // Generate rotating discount recipes (change daily, faction-matched)
    _recipes = MarketRecipeTable.generate(
      items: _items
          .map((i) => MarketItemEntry(key: i.inventoryKey, faction: i.faction))
          .toList(),
    );
  }

  /// Faction-based discount: 90% off harvesters matching player's faction.
  double _factionMultiplier(_MarketItem item) {
    final factions = context.read<FactionService>();
    final pFaction = factions.current;
    if (pFaction == null) return 1.0;
    final factionName = pFaction.name; // 'volcanic', 'oceanic', etc.
    if (item.faction == factionName) return 0.1;
    return 1.0;
  }

  Map<String, int> _effectiveCost(_MarketItem item) {
    final fMul = _factionMultiplier(item);
    var cost = item.baseCost;

    // Apply faction discount first (90% off own-faction harvesters)
    if (fMul < 1.0) {
      cost = cost.map((k, v) => MapEntry(k, (v * fMul).ceil()));
    }

    // Then check elemental meter discount (50% off)
    final recipe = _recipes[item.inventoryKey];
    if (recipe != null &&
        recipe.qualifies(widget.meter.breakdown, widget.meter.total)) {
      cost = cost.map((k, v) => MapEntry(k, (v * 0.5).ceil()));
    }
    return cost;
  }

  bool _hasFactionDiscount(_MarketItem item) => _factionMultiplier(item) < 1.0;

  bool _hasElementDiscount(_MarketItem item) {
    final recipe = _recipes[item.inventoryKey];
    if (recipe == null) return false;
    return recipe.qualifies(widget.meter.breakdown, widget.meter.total);
  }

  bool _hasDiscount(_MarketItem item) =>
      _hasFactionDiscount(item) || _hasElementDiscount(item);

  IconData _iconForCost(String type) {
    return switch (type) {
      'gold' => Icons.hexagon_rounded,
      'silver' => Icons.monetization_on_rounded,
      'shards' => Icons.diamond_rounded,
      _ => Icons.hexagon_rounded,
    };
  }

  Color _colorForCost(String type, ForgeTokens t) {
    return switch (type) {
      'gold' => const Color(0xFFFFD700),
      'silver' => t.textSecondary,
      'shards' => const Color(0xFFAB47BC),
      _ => _accent,
    };
  }

  Future<bool> _confirmPurchase(_MarketItem item, Map<String, int> cost) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = context.read<FactionTheme>();
        final t = ForgeTokens(theme);
        return AlertDialog(
          backgroundColor: t.bg1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _accent.withValues(alpha: 0.35)),
          ),
          title: Text(
            'Confirm Purchase',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(color: t.textPrimary, fontSize: 14),
              ),
              const SizedBox(height: 10),
              ...cost.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(
                        _iconForCost(entry.key),
                        size: 16,
                        color: _colorForCost(entry.key, t),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${entry.value}',
                        style: TextStyle(color: t.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Buy'),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  void _showMarketToast(
    String message, {
    required bool success,
  }) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final tone = success ? const Color(0xFF22C55E) : const Color(0xFFC0392B);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(_MarketItem item) async {
    final db = context.read<AlchemonsDatabase>();
    final cost = _effectiveCost(item);

    final balances = await db.currencyDao.getAllCurrencies();
    final silver = balances['silver'] ?? 0;
    final gold = balances['gold'] ?? 0;
    final shardCost = cost['shards'] ?? 0;
    final silverCost = cost['silver'] ?? 0;
    final goldCost = cost['gold'] ?? 0;

    final canAfford =
        _carriedShards >= shardCost && silver >= silverCost && gold >= goldCost;
    if (!canAfford) {
      if (!mounted) return;
      _showMarketToast('Insufficient resources for this purchase.', success: false);
      return;
    }

    final confirmed = await _confirmPurchase(item, cost);
    if (!confirmed) return;

    if (silverCost > 0) {
      final ok = await db.currencyDao.spendSilver(silverCost);
      if (!ok) return;
    }
    if (goldCost > 0) {
      final ok = await db.currencyDao.spendGold(goldCost);
      if (!ok) return;
    }
    if (shardCost > 0) {
      final ok = widget.spendShards(shardCost);
      if (!ok) return;
      _carriedShards -= shardCost;
    }

    await db.inventoryDao.addItemQty(item.inventoryKey, 1);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    _showMarketToast('${item.name} acquired.', success: true);
    setState(() {}); // refresh owned counts
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.borderDim,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),

              // Title + currency header
              _buildHeader(db, t),

              const SizedBox(height: 8),

              // Items list
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  itemCount: _items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _buildItemCard(_items[i], db, t),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(AlchemonsDatabase db, ForgeTokens t) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final c = snap.data ?? {'gold': 0, 'silver': 0};
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(
                    _title,
                    style: TextStyle(
                      fontFamily: appFontFamily(context),
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.bg2.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: t.borderAccent.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CurrencyPill(
                      icon: Icons.hexagon_rounded,
                      color: const Color(0xFFFFD700),
                      amount: c['gold'] ?? 0,
                    ),
                    Container(width: 1, height: 16, color: t.borderDim),
                    CurrencyPill(
                      icon: Icons.monetization_on_rounded,
                      color: t.textSecondary,
                      amount: c['silver'] ?? 0,
                    ),
                    Container(width: 1, height: 16, color: t.borderDim),
                    CurrencyPill(
                      icon: Icons.diamond_rounded,
                      color: const Color(0xFFAB47BC),
                      amount: _carriedShards,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemCard(_MarketItem item, AlchemonsDatabase db, ForgeTokens t) {
    final cost = _effectiveCost(item);
    final discounted = _hasDiscount(item);
    final recipe = _recipes[item.inventoryKey];

    return FutureBuilder<int>(
      future: db.inventoryDao.getItemQty(item.inventoryKey),
      builder: (context, snap) {
        final owned = snap.data ?? 0;

        return StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchAllCurrencies(),
          builder: (context, currSnap) {
            final currencies = currSnap.data ?? {};

            // Check affordability
            bool canAfford = true;
            for (final entry in cost.entries) {
              final have = switch (entry.key) {
                'gold' => currencies['gold'] ?? 0,
                'silver' => currencies['silver'] ?? 0,
                'shards' => _carriedShards,
                _ => currencies[entry.key] ?? 0,
              };
              if (have < entry.value) {
                canAfford = false;
                break;
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: t.bg2.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: discounted
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                      : t.borderDim,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: canAfford ? () => _purchase(item) : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // Item visual
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: item.iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.assetName != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.asset(
                                  item.assetName!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                    item.icon,
                                    color: item.iconColor,
                                    size: 28,
                                  ),
                                ),
                              )
                            : Icon(item.icon, color: item.iconColor, size: 28),
                      ),
                      const SizedBox(width: 12),

                      // Name + description + discount info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: TextStyle(
                                      color: t.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                // Owned count badge
                                if (owned > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.borderAccent.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '×$owned',
                                      style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.description,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),

                            // Faction discount indicator
                            if (_hasFactionDiscount(item))
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 12,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '90% OFF — Your faction!',
                                    style: TextStyle(
                                      color: const Color(0xFF4CAF50),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),

                            // Elemental discount recipe indicator
                            if (recipe != null && !_hasFactionDiscount(item))
                              Row(
                                children: [
                                  Icon(
                                    _hasElementDiscount(item)
                                        ? Icons.check_circle_rounded
                                        : Icons.info_outline_rounded,
                                    size: 12,
                                    color: _hasElementDiscount(item)
                                        ? const Color(0xFF4CAF50)
                                        : t.textSecondary.withValues(
                                            alpha: 0.6,
                                          ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _hasElementDiscount(item)
                                        ? '50% OFF — ${recipe.requiredElement} meter active'
                                        : '50% off with ≥50% ${recipe.requiredElement} meter',
                                    style: TextStyle(
                                      color: _hasElementDiscount(item)
                                          ? const Color(0xFF4CAF50)
                                          : t.textSecondary.withValues(
                                              alpha: 0.6,
                                            ),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Price
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          ...cost.entries.map((e) {
                            final cType = e.key.startsWith('res_')
                                ? e.key
                                : e.key;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (discounted)
                                  Text(
                                    '${item.baseCost[e.key]}',
                                    style: TextStyle(
                                      color: t.textSecondary.withValues(
                                        alpha: 0.4,
                                      ),
                                      fontSize: 10,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                if (discounted) const SizedBox(width: 4),
                                Icon(
                                  _iconForCost(cType),
                                  size: 14,
                                  color: _colorForCost(cType, t),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${e.value}',
                                  style: TextStyle(
                                    color: canAfford ? t.textPrimary : t.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
