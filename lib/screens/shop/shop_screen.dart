// lib/screens/shop_screen.dart
//
// REDESIGNED SHOP SCREEN
// Aesthetic: Scorched Forge — dark metal chrome, amber reagent accents, monospace
// GameShopCard and grid layouts are preserved exactly.
// Transparent card style on daily vial banner is preserved.
// All logic, routing, purchase flows, and service calls unchanged.
//

import 'dart:async';

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/screens/faction_picker.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/black_market_button.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ForgeTokens get t => ForgeTokens(context.read<FactionTheme>());

  int _slotsUnlocked = 1;
  bool _showPurchased = false;

  late final Map<String, int> _slot2Cost;
  late final Map<String, int> _slot3Cost;

  @override
  void initState() {
    super.initState();
    _slot2Cost = UnlockCosts.bubbleSlot(2);
    _slot3Cost = UnlockCosts.bubbleSlot(3);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<BlackMarketService>().checkNow();
    });

    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final db = context.read<AlchemonsDatabase>();
    final n = await db.settingsDao.getBlobSlotsUnlocked();
    final show = await db.settingsDao.getShopShowPurchased();
    if (!mounted) return;
    setState(() {
      _slotsUnlocked = n;
      _showPurchased = show;
    });
  }

  Future<void> _purchaseSlot(int target) async {
    final db = context.read<AlchemonsDatabase>();
    final cost = target == 2 ? _slot2Cost : _slot3Cost;

    if (_slotsUnlocked >= target) {
      _toast('Already unlocked');
      return;
    }

    final ok = await db.currencyDao.spendResources(cost);
    if (!ok) {
      _toast('Not enough resources', icon: Icons.lock_rounded, color: t.amber);
      return;
    }

    await db.settingsDao.setBlobSlotsUnlocked(target);
    await _refreshAll();
    _toast(
      'Bubble slot $target unlocked!',
      icon: Icons.bubble_chart_rounded,
      color: t.teal,
    );
    HapticFeedback.lightImpact();
  }

  void _toast(String msg, {IconData icon = Icons.check_rounded, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.bg1,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(icon, color: color ?? t.amberBright, size: 13),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.bg0,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? t.amber,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final db = context.read<AlchemonsDatabase>();

    return ParticleBackgroundScaffold(
      whiteBackground: theme.brightness == Brightness.light,
      body: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              StreamBuilder<Map<String, int>>(
                stream: db.currencyDao.watchAllCurrencies(),
                builder: (context, snap) {
                  final c = snap.data ?? {'gold': 0, 'silver': 0, 'soft': 0};
                  return _buildHeader(theme, c);
                },
              ),
              Expanded(child: _buildShopContent(theme, db)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(FactionTheme theme, Map<String, int> allCurrencies) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.borderDim)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              _buildBlackMarketFloatingButton(context, theme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: t.amber,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          'RESEARCH SHOP',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Currency bar — transparent glass plate style preserved
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: t.bg2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CurrencyPill(
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFFFFD700),
                  amount: allCurrencies['gold'] ?? 0,
                ),
                Container(width: 1, height: 16, color: t.borderDim),
                CurrencyPill(
                  icon: Icons.monetization_on_rounded,
                  color: t.textSecondary,
                  amount: allCurrencies['silver'] ?? 0,
                ),
              ],
            ),
          ),

          ResourceCollectionWidget(theme: theme),
        ],
      ),
    );
  }

  // ── SECTION HEADER ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color accent, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 16,
            color: accent,
            margin: const EdgeInsets.only(right: 10),
          ),
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: accent.withValues(alpha: 0.2))),
        ],
      ),
    );
  }

  // ── DAILY VIAL ─────────────────────────────────────────────────────────────
  // Transparent card style preserved per user request

  Widget _buildDailyVialSection(
    FactionTheme theme,
    Map<String, int> allCurrencies,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final offer = shopService.getActiveDailyVialOffer();
        if (offer == null) return const SizedBox.shrink();

        final canPurchase = shopService.canPurchase(offer.id);
        final effectiveCost = shopService.getEffectiveCost(offer);
        final price = effectiveCost['silver'] ?? (offer.cost['silver'] ?? 100);
        final canAfford = (allCurrencies['silver'] ?? 0) >= price;
        final isPurchased = !canPurchase;

        final costWidgets = <Widget>[
          CostChip(
            currencyType: 'silver',
            amount: price,
            available: allCurrencies['silver'] ?? 0,
          ),
        ];

        final groupName = offer.id.split('.').last;
        final group = ElementalGroup.values.firstWhere(
          (g) => g.name == groupName,
          orElse: () => ElementalGroup.volcanic,
        );
        final vialModel = ExtractionVial(
          id: offer.id,
          name: '${group.displayName} Vial',
          group: group,
          rarity: VialRarity.common,
          quantity: 1,
          price: price,
        );

        // Border color reflects purchase state — transparent card preserved
        final borderColor = isPurchased
            ? t.success.withValues(alpha: 0.5)
            : canAfford
            ? t.borderAccent
            : t.danger.withValues(alpha: 0.5);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GestureDetector(
            onTap: () {
              if (canPurchase) {
                _handlePurchase(context, offer, allCurrencies, canAfford);
              } else {
                _showDetails(context, offer, allCurrencies, canAfford);
              }
            },
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                // TRANSPARENT card style preserved
                color: theme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ExtractionVialCard(
                            vial: vialModel,
                            compact: true,
                            onAddToInventory: null,
                            onTap: null,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                offer.name.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                offer.description,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textSecondary,
                                  fontSize: 9,
                                  letterSpacing: 0.2,
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Wrap(spacing: 4, children: costWidgets),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Purchased overlay
                  if (isPurchased)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: t.successDim.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: t.success.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Color(0xFF4ADE80),
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'PURCHASED TODAY',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: Color(0xFF4ADE80),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── SHOP CONTENT ───────────────────────────────────────────────────────────
  // (unchanged grid logic — only section headers restyled)

  Widget _buildShopContent(FactionTheme theme, AlchemonsDatabase db) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, currencySnap) {
        final allCurrencies =
            currencySnap.data ?? {'gold': 0, 'silver': 0, 'soft': 0};

        return StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, resourceSnap) {
            final resourceBalances = resourceSnap.data ?? {};

            return StreamBuilder<List<InventoryItem>>(
              stream: db.inventoryDao.watchItemInventory(),
              builder: (context, invSnap) {
                final invList = invSnap.data ?? const <InventoryItem>[];
                final inventoryByKey = <String, int>{
                  for (final it in invList) it.key: it.qty,
                };

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader(
                        'DAILY VIAL',
                        t.amberBright,
                        Icons.science_rounded,
                      ),
                      const SizedBox(height: 10),
                      _buildDailyVialSection(theme, allCurrencies),

                      _buildSectionHeader(
                        'HARVEST DEVICES',
                        t.textPrimary,
                        Icons.science_rounded,
                      ),
                      _buildHarvestDevicesGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                        resourceBalances,
                      ),

                      _buildSectionHeader(
                        'INSTANT ITEMS',
                        t.textPrimary,
                        Icons.flash_on_rounded,
                      ),
                      _buildInstantItemsGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                      ),

                      _buildSectionHeader(
                        'ALCHEMY EFFECTS',
                        t.amberBright,
                        Icons.auto_awesome_rounded,
                      ),
                      _buildAlchemyEffectsGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                      ),

                      _buildSectionHeader(
                        'EXCHANGE',
                        t.textPrimary,
                        Icons.currency_exchange_rounded,
                      ),
                      _buildCurrencyExchangeGrid(
                        theme,
                        allCurrencies,
                        resourceBalances,
                      ),

                      _buildSectionHeader(
                        'PORTAL KEYS',
                        t.amberBright,
                        Icons.vpn_key_rounded,
                      ),
                      _buildPortalKeysGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                      ),

                      _buildSectionHeader(
                        'SPECIAL UNLOCKS',
                        t.amberBright,
                        Icons.auto_awesome_rounded,
                      ),
                      _buildSpecialUnlocksGrid(theme, allCurrencies),

                      _buildSectionHeader(
                        'ALCHEMY CHAMBERS',
                        t.amberBright,
                        Icons.bubble_chart_rounded,
                      ),
                      _buildUpgradesGrid(theme, resourceBalances),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── GRIDS (logic unchanged, padding/spacing preserved) ─────────────────────

  Widget _buildAlchemyEffectsGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final effectOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('effects'))
            .toList();

        if (effectOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No effects available',
              icon: Icons.auto_awesome_outlined,
            ),
          );
        }

        final cards = effectOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final invQty = offer.inventoryKey != null
              ? (inventory[offer.inventoryKey] ?? 0)
              : 0;
          final status = invQty > 0 ? 'x$invQty' : null;
          final costWidgets = <Widget>[
            for (final entry in effectiveCost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, allCurrencies, canAffordUnit)
                : _showDetails(context, offer, allCurrencies, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('effect-${offer.id}'),
              title: offer.name,
              offer: offer,
              theme: theme,
              costWidgets: costWidgets,
              statusText: status,
              enabled: canPurchase,
              canAfford: canAffordUnit,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildHarvestDevicesGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
    Map<String, int> resourceBalances,
  ) {
    final mergedBalances = <String, int>{}
      ..addAll(allCurrencies)
      ..addAll(resourceBalances);

    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final deviceOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('device.harvest'))
            .toList();

        final cards = deviceOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (mergedBalances[e.key] ?? 0) >= e.value,
          );
          final invQty = offer.inventoryKey != null
              ? (inventory[offer.inventoryKey] ?? 0)
              : 0;
          final status = invQty > 0 ? 'x$invQty' : null;
          final costWidgets = <Widget>[];
          for (final entry in effectiveCost.entries) {
            if (entry.key.startsWith('res_')) {
              final res = ElementResources.all.firstWhere(
                (r) => r.settingsKey == entry.key,
                orElse: () => ElementResources.all.first,
              );
              costWidgets.add(
                MiniCostChip(
                  resource: res,
                  required: entry.value,
                  current: resourceBalances[entry.key] ?? 0,
                ),
              );
            } else {
              costWidgets.add(
                CostChip(
                  currencyType: entry.key,
                  amount: entry.value,
                  available: allCurrencies[entry.key] ?? 0,
                ),
              );
            }
          }
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, mergedBalances, canAffordUnit)
                : _showDetails(context, offer, mergedBalances, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('device-${offer.id}'),
              title: offer.name,
              theme: theme,
              costWidgets: costWidgets,
              statusText: status,
              enabled: canPurchase,
              canAfford: canAffordUnit,
              offer: offer,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildPortalKeysGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final keyOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('key.portal'))
            .toList();

        if (keyOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No portal keys available',
              icon: Icons.vpn_key_outlined,
            ),
          );
        }

        final cards = keyOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final invQty = offer.inventoryKey != null
              ? (inventory[offer.inventoryKey] ?? 0)
              : 0;
          final status = invQty > 0 ? 'x$invQty' : null;
          final costWidgets = <Widget>[
            for (final entry in effectiveCost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, allCurrencies, canAffordUnit)
                : _showDetails(context, offer, allCurrencies, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('portalkey-${offer.id}'),
              title: offer.name,
              offer: offer,
              theme: theme,
              costWidgets: costWidgets,
              statusText: status,
              enabled: canPurchase,
              canAfford: canAffordUnit,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildInstantItemsGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final instantOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('boost.instant'))
            .toList();

        if (instantOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No instant items available',
              icon: Icons.flash_off_rounded,
            ),
          );
        }

        final cards = instantOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final invQty = offer.inventoryKey != null
              ? (inventory[offer.inventoryKey] ?? 0)
              : 0;
          final status = invQty > 0 ? 'x$invQty' : null;
          final costWidgets = <Widget>[
            for (final entry in effectiveCost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, allCurrencies, canAffordUnit)
                : _showDetails(context, offer, allCurrencies, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('instant-${offer.id}'),
              title: offer.name,
              offer: offer,
              theme: theme,
              costWidgets: costWidgets,
              statusText: status,
              enabled: canPurchase,
              canAfford: canAffordUnit,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildCurrencyExchangeGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> resourceBalances,
  ) {
    final mergedBalances = <String, int>{}
      ..addAll(allCurrencies)
      ..addAll(resourceBalances);

    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final exchangeOffers = shopService.getActiveExchangeOffers();

        final cards = exchangeOffers.map<Widget>((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (mergedBalances[e.key] ?? 0) >= e.value,
          );
          final List<Widget> costWidgets = [];
          effectiveCost.forEach((key, amount) {
            if (key.startsWith('res_')) {
              final res = ElementResources.all.firstWhere(
                (r) => r.settingsKey == key,
                orElse: () => ElementResources.all.first,
              );
              costWidgets.add(
                MiniCostChip(
                  resource: res,
                  required: amount,
                  current: resourceBalances[key] ?? 0,
                ),
              );
            } else {
              costWidgets.add(
                CostChip(
                  currencyType: key,
                  amount: amount,
                  available: allCurrencies[key] ?? 0,
                ),
              );
            }
          });
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, mergedBalances, canAffordUnit)
                : _showDetails(context, offer, mergedBalances, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('fx-${offer.id}'),
              title: offer.name,
              theme: theme,
              costWidgets: costWidgets,
              enabled: canPurchase,
              canAfford: canAffordUnit,
              offer: offer,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.8,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildSpecialUnlocksGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final specialOffers = ShopService.allOffers.where((o) {
          return o.id.startsWith('unlock.') || o.id == 'boost.faction_change';
        }).toList();

        const fusionIds = [
          'unlock.fusion_slot.1',
          'unlock.fusion_slot.2',
          'unlock.fusion_slot.3',
          'unlock.fusion_slot.4',
        ];
        String? nextFusionId;
        for (final id in fusionIds) {
          if (shopService.canPurchase(id)) {
            nextFusionId = id;
            break;
          }
        }
        specialOffers.removeWhere((o) => fusionIds.contains(o.id));
        if (nextFusionId != null) {
          final next = ShopService.allOffers.firstWhere(
            (o) => o.id == nextFusionId,
          );
          specialOffers.insert(0, next);
        }

        if (!_showPurchased) {
          specialOffers.removeWhere((o) => !shopService.canPurchase(o.id));
        }

        if (specialOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'All special items unlocked',
              icon: Icons.check_circle_outline_rounded,
            ),
          );
        }

        final cards = specialOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final costWidgets = <Widget>[
            for (final entry in effectiveCost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, allCurrencies, canAffordUnit)
                : _showDetails(context, offer, allCurrencies, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('special-${offer.id}'),
              title: offer.name,
              theme: theme,
              costWidgets: costWidgets,
              enabled: canPurchase,
              canAfford: canAffordUnit,
              offer: offer,
            ),
          );
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.6,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildUpgradesGrid(
    FactionTheme theme,
    Map<String, int> resourceBalances,
  ) {
    final items = <Widget>[];

    void addSlot(int slotNumber, Map<String, int> cost) {
      if (_slotsUnlocked >= slotNumber && !_showPurchased) return;
      final enabled = _slotsUnlocked < slotNumber;
      final canAfford = cost.entries.every(
        (e) => (resourceBalances[e.key] ?? 0) >= e.value,
      );
      final costWidgets = <Widget>[
        for (final res in ElementResources.all)
          if ((cost[res.settingsKey] ?? 0) > 0)
            MiniCostChip(
              resource: res,
              required: cost[res.settingsKey]!,
              current: resourceBalances[res.settingsKey] ?? 0,
            ),
      ];
      final slotOffer = ShopOffer(
        rewardType: 'Upgrade',
        reward: <String, dynamic>{},
        limit: PurchaseLimit.once,
        id: 'unlock.bubble_slot_$slotNumber',
        name: 'Floating Alchemy Chamber',
        description:
            'Unlock a floating alchemy chamber to display chosen Alchemons on the homescreen.',
        icon: Icons.bubble_chart_rounded,
        cost: cost,
        inventoryKey: null,
        assetName: null,
      );
      items.add(
        GestureDetector(
          onTap: () => enabled
              ? _handleBubbleSlotPurchase(
                  context,
                  slotOffer,
                  resourceBalances,
                  canAfford,
                  slotNumber,
                )
              : _showBubbleSlotDetails(
                  context,
                  slotOffer,
                  resourceBalances,
                  canAfford,
                ),
          child: GameShopCard(
            key: ValueKey('upgrade-slot-$slotNumber'),
            title: 'Bubble Slot $slotNumber',
            offer: slotOffer,
            theme: theme,
            costWidgets: costWidgets,
            enabled: enabled,
            canAfford: canAfford,
          ),
        ),
      );
    }

    addSlot(2, _slot2Cost);
    addSlot(3, _slot3Cost);

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: EmptySection(
          message: 'All upgrades unlocked',
          icon: Icons.check_circle_outline_rounded,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
        children: items,
      ),
    );
  }

  // ── DIALOGS & PURCHASE FLOWS (logic unchanged) ─────────────────────────────

  Future<void> _showBubbleSlotDetails(
    BuildContext context,
    ShopOffer offer,
    Map<String, int> balances,
    bool canAfford,
  ) async {
    final theme = context.read<FactionTheme>();
    await showItemDetailDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: balances,
      inventoryQty: 0,
      canPurchase: canAfford,
      canAfford: canAfford,
    );
  }

  Future<void> _handleBubbleSlotPurchase(
    BuildContext context,
    ShopOffer offer,
    Map<String, int> balances,
    bool canAfford,
    int slotNumber,
  ) async {
    final theme = context.read<FactionTheme>();
    final shouldProceed = await showItemDetailDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: balances,
      inventoryQty: 0,
      canPurchase: canAfford,
      canAfford: canAfford,
      effectiveCost: offer.cost,
    );
    if (!shouldProceed || !context.mounted) return;
    await _purchaseSlot(slotNumber);
  }

  Future<void> _showDetails(
    BuildContext context,
    ShopOffer offer,
    Map<String, int> currencies,
    bool isCurrencyAffordable,
  ) async {
    final theme = context.read<FactionTheme>();
    final shopService = context.read<ShopService>();
    final canPurchaseDaily = shopService.canPurchase(offer.id);
    final invQty = offer.inventoryKey != null
        ? shopService.inventoryCountForOffer(offer.id)
        : 0;
    await showItemDetailDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: currencies,
      inventoryQty: invQty,
      canPurchase: canPurchaseDaily,
      canAfford: isCurrencyAffordable,
      effectiveCost: offer.cost,
    );
  }

  Future<void> _handlePurchase(
    BuildContext context,
    ShopOffer offer,
    Map<String, int> currencies,
    bool isCurrencyAffordable,
  ) async {
    final theme = context.read<FactionTheme>();
    final shopService = context.read<ShopService>();
    final effectiveCost = shopService.getEffectiveCost(offer);
    final canPurchaseDaily = shopService.canPurchase(offer.id);
    final invQty = offer.inventoryKey != null
        ? shopService.inventoryCountForOffer(offer.id)
        : 0;

    final shouldProceed = await showItemDetailDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: currencies,
      inventoryQty: invQty,
      canPurchase: canPurchaseDaily,
      canAfford: isCurrencyAffordable,
      effectiveCost: effectiveCost,
    );
    if (!shouldProceed || !context.mounted) return;

    final qty = await showPurchaseConfirmationDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: currencies,
      effectiveCost: effectiveCost,
    );
    if (qty == null || !context.mounted) return;

    HapticFeedback.lightImpact();
    final success = await shopService.purchase(offer.id, qty: qty);
    if (!context.mounted) return;

    // Result snackbar
    _toast(
      success ? '${offer.name} × $qty' : 'Purchase failed',
      icon: success ? Icons.check_rounded : Icons.error_rounded,
      color: success ? t.success : t.danger,
    );

    if (success && offer.id == 'boost.faction_change') {
      HapticFeedback.mediumImpact();
      _toast(
        'Opening faction selector...',
        icon: Icons.flag_rounded,
        color: const Color(0xFF7C3AED),
      );
      await Navigator.of(context).push(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const FactionPickerDialog(),
        ),
      );
    }
  }

  // ── BLACK MARKET BUTTON ────────────────────────────────────────────────────

  Widget _buildBlackMarketFloatingButton(BuildContext context, Color accent) {
    return Consumer<BlackMarketService>(
      builder: (context, marketService, child) => AnimatedBlackMarketButton(
        isOpen: marketService.isOpen,
        accent: accent,
        onTap: marketService.isOpen
            ? () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => BlackMarketScreen(accent: accent),
                  ),
                );
              }
            : () {
                HapticFeedback.mediumImpact();
                _showMarketClosedDialog(context, accent, marketService);
              },
      ),
    );
  }

  // ── MARKET CLOSED DIALOG ───────────────────────────────────────────────────

  void _showMarketClosedDialog(
    BuildContext context,
    Color accent,
    BlackMarketService marketService,
  ) {
    final timeUntil = marketService.getTimeUntilOpen();
    final hoursUntil = timeUntil.inHours;
    final minutesUntil = timeUntil.inMinutes % 60;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: t.borderAccent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon plate
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderDim),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: t.textMuted,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'NOBODY HERE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'There is a digital timer in the corner\nwith a countdown:',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.3,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: t.amberDim.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderAccent),
                ),
                child: Text(
                  hoursUntil > 0
                      ? '${hoursUntil}H  ${minutesUntil}M'
                      : '${minutesUntil}M',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: t.borderDim),
                    ),
                    child: Center(
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
