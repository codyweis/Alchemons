// lib/screens/shop_screen.dart
//
// REDESIGNED SHOP SCREEN
// Aesthetic: Scorched Forge — dark metal chrome, amber reagent accents, monospace
// GameShopCard and grid layouts are preserved exactly.
// Transparent card style on daily vial banner is preserved.
// All logic, routing, purchase flows, and service calls unchanged.
//

import 'dart:async';
import 'dart:math' as math;

import 'package:graphx/graphx.dart';

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/screens/shop/alchemon_exchange_screen.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/responsive_grid.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/black_market_button.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
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
  int _cosmicPartySlots = 0;
  bool _showPurchased = false;

  late final Map<String, int> _slot2Cost;
  late final Map<String, int> _slot3Cost;

  // Cosmic party slot costs.
  static const Map<String, int> _partySlot1Cost = {'silver': 10000};
  static const Map<String, int> _partySlot2Cost = {'gold': 25};
  static const Map<String, int> _partySlot3Cost = {'gold': 100};

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
    final cp = await db.settingsDao.getCosmicPartySlotsUnlocked();
    final show = await db.settingsDao.getShopShowPurchased();
    if (!mounted) return;
    setState(() {
      _slotsUnlocked = n;
      _cosmicPartySlots = cp;
      _showPurchased = show;
    });
  }

  Map<String, int> _bubbleSlotCostFor(int slotNumber) {
    final baseCost = slotNumber == 2 ? _slot2Cost : _slot3Cost;
    return context.read<FactionService>().discountedBubbleSlotCost(baseCost);
  }

  Future<void> _purchaseSlot(int target, Map<String, int> cost) async {
    final db = context.read<AlchemonsDatabase>();

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
    final backgroundColor = color ?? t.amber;
    final foregroundColor = t.onColor(backgroundColor);
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
              child: Icon(icon, color: foregroundColor, size: 13),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: foregroundColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
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
              _buildHeader(theme),
              Expanded(child: _buildShopContent(theme, db)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(FactionTheme theme) {
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
              _buildExchangeFloatingButton(context),
            ],
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              CurrencyDisplayWidget(accentColor: t.borderAccent),
              const SizedBox(width: 4),
              Expanded(
                child: SizedBox(
                  height: 58,
                  child: ResourceCollectionWidget(
                    theme: theme,
                    horizontalPadding: 0,
                    alignToEnd: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color accent, IconData icon) {
    final displayAccent = t.readableAccent(accent);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 16,
            color: displayAccent,
            margin: const EdgeInsets.only(right: 10),
          ),
          Icon(icon, color: displayAccent, size: 14),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              color: displayAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 1,
              color: displayAccent.withValues(alpha: 0.2),
            ),
          ),
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
                          color: theme.isDark
                              ? Colors.black.withValues(alpha: 0.65)
                              : theme.surface.withValues(alpha: 0.92),
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
                              'PURCHASED',
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
                        'SPECIAL UNLOCKS',
                        t.amberBright,
                        Icons.auto_awesome_rounded,
                      ),
                      _buildSpecialUnlocksGrid(
                        theme,
                        allCurrencies,
                        resourceBalances,
                      ),

                      _buildSectionHeader(
                        'GOLD VAULT',
                        const Color(0xFFFFD700),
                        Icons.hexagon_rounded,
                      ),
                      _buildGoldVaultSection(theme),

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
                        'ALCHEMICAL POWERUPS',
                        const Color(0xFFB58CFF),
                        Icons.blur_circular_rounded,
                      ),
                      _buildAlchemicalPowerupsRow(
                        theme,
                        allCurrencies,
                        inventoryByKey,
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
                        'SELL',
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
                        'SURVIVAL ORB SKINS',
                        t.amberBright,
                        Icons.blur_circular_rounded,
                      ),
                      _buildSurvivalOrbGrid(theme, allCurrencies),

                      // 'COSMIC EXPLORATION' removed — discovery will occur in-world
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
        final effectOffers = shopService.getAlchemyEffectOffers();

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
            crossAxisCount: responsiveCrossAxisCount(context),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildGoldVaultSection(FactionTheme theme) {
    return Consumer<MobileStoreService>(
      builder: (context, store, _) {
        final packs = store.packDefinitions;

        Future<void> buyPack(String productId) async {
          final goldAccent = t.readableAccent(const Color(0xFFFFD700));
          final started = await store.purchaseGoldPack(productId);
          if (!context.mounted) return;
          _toast(
            started
                ? 'Purchase started'
                : (store.lastError ?? 'Store unavailable'),
            icon: started ? Icons.shopping_bag_rounded : Icons.error_rounded,
            color: started ? goldAccent : t.danger,
          );
        }

        if (!store.isSupportedPlatform) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Text(
              'Gold purchases are available on iOS and Android builds.',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 10,
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: _GoldVaultDeck(
            packs: packs,
            store: store,
            theme: theme,
            onBuy: buyPack,
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
            crossAxisCount: responsiveCrossAxisCount(context),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: cards,
          ),
        );
      },
    );
  }

  Widget buildExplorationGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
    Map<String, int> resourceBalances,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final offers = ShopService.allOffers
            .where((o) => o.id.startsWith('cosmic.'))
            .toList();

        final cards = offers.map<Widget>((offer) {
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
              key: ValueKey('exploration-${offer.id}'),
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

        // ── Alchemy Chamber (bubble slot) upgrades ──
        void addSlot(int slotNumber) {
          final cost = _bubbleSlotCostFor(slotNumber);
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
            name: 'Alchemy Chamber $slotNumber',
            description: 'Unlock an additional floating alchemy chamber.',
            icon: Icons.bubble_chart_rounded,
            cost: cost,
            inventoryKey: null,
            assetName: null,
          );
          cards.add(
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
                title: 'Alchemy Chamber $slotNumber',
                offer: slotOffer,
                theme: theme,
                costWidgets: costWidgets,
                enabled: enabled,
                canAfford: canAfford,
              ),
            ),
          );
        }

        addSlot(2);
        addSlot(3);

        // ── Cosmic Party (patrol slot) upgrades ──
        void addPartySlot(int slotNumber, Map<String, int> cost) {
          if (_cosmicPartySlots >= slotNumber && !_showPurchased) return;
          final enabled = _cosmicPartySlots < slotNumber;
          final canAfford = cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final costWidgets = <Widget>[
            for (final e in cost.entries)
              CostChip(
                currencyType: e.key,
                amount: e.value,
                available: allCurrencies[e.key] ?? 0,
              ),
          ];
          final slotOffer = ShopOffer(
            rewardType: 'Upgrade',
            reward: <String, dynamic>{},
            limit: PurchaseLimit.once,
            id: 'unlock.cosmic_party_slot_$slotNumber',
            name: 'Patrol Slot $slotNumber',
            description:
                'Unlock patrol slot $slotNumber. Assign an Alchemon to patrol space with your ship.',
            icon: Icons.groups_rounded,
            cost: cost,
            inventoryKey: null,
            assetName: null,
          );
          cards.add(
            GestureDetector(
              onTap: () => enabled
                  ? _handleCosmicPartySlotPurchase(
                      context,
                      slotOffer,
                      allCurrencies,
                      canAfford,
                      slotNumber,
                    )
                  : _showBubbleSlotDetails(
                      context,
                      slotOffer,
                      allCurrencies,
                      canAfford,
                    ),
              child: GameShopCard(
                key: ValueKey('cosmic-party-slot-$slotNumber'),
                title: 'Patrol Slot $slotNumber',
                offer: slotOffer,
                theme: theme,
                costWidgets: costWidgets,
                enabled: enabled,
                canAfford: canAfford,
              ),
            ),
          );
        }

        addPartySlot(1, _partySlot1Cost);
        addPartySlot(2, _partySlot2Cost);
        addPartySlot(3, _partySlot3Cost);

        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No exploration items available',
              icon: Icons.rocket_launch_outlined,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: responsiveCrossAxisCount(context),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  Future<void> _handleCosmicPartySlotPurchase(
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
    await _purchaseCosmicPartySlot(slotNumber);
  }

  Future<void> _purchaseCosmicPartySlot(int target) async {
    final db = context.read<AlchemonsDatabase>();
    final costs = [_partySlot1Cost, _partySlot2Cost, _partySlot3Cost];
    final cost = costs[target - 1];

    if (_cosmicPartySlots >= target) {
      _toast('Already unlocked');
      return;
    }

    final ok = await _spendWalletCost(db, cost);
    if (!ok) {
      _toast('Not enough currency', icon: Icons.lock_rounded, color: t.amber);
      return;
    }

    await db.settingsDao.setCosmicPartySlotsUnlocked(target);
    await _refreshAll();
    _toast(
      'Patrol slot $target unlocked!',
      icon: Icons.groups_rounded,
      color: t.teal,
    );
    HapticFeedback.lightImpact();
  }

  Future<bool> _spendWalletCost(
    AlchemonsDatabase db,
    Map<String, int> cost,
  ) async {
    // Guard first so we don't partially spend in mixed-currency costs.
    final balances = await db.currencyDao.getAllCurrencies();
    final canAfford = cost.entries.every(
      (e) => (balances[e.key] ?? 0) >= e.value,
    );
    if (!canAfford) return false;

    for (final e in cost.entries) {
      final key = e.key;
      final amount = e.value;
      final spent = switch (key) {
        'silver' => await db.currencyDao.spendSilver(amount),
        'gold' => await db.currencyDao.spendGold(amount),
        'soft' => await db.currencyDao.spendSoft(amount),
        _ => false,
      };
      if (!spent) return false;
    }
    return true;
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
            crossAxisCount: responsiveCrossAxisCount(context),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  Widget _buildSurvivalOrbGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final orbOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('survival.orb'))
            .toList();

        if (orbOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No orb skins available',
              icon: Icons.blur_circular_outlined,
            ),
          );
        }

        final cards = orbOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );
          final purchased = shopService.getPurchaseCount(offer.id) > 0;
          final status = purchased ? 'OWNED' : null;
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
              key: ValueKey('orb-${offer.id}'),
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
            crossAxisCount: responsiveCrossAxisCount(context),
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
              message: 'No consumables available',
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
            crossAxisCount: responsiveCrossAxisCount(context),
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
            crossAxisCount: responsiveCrossAxisCount(context),
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
    Map<String, int> resourceBalances,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final mergedBalances = <String, int>{}
          ..addAll(allCurrencies)
          ..addAll(resourceBalances);
        final specialOffers = ShopService.allOffers.where((o) {
          return o.id.startsWith('unlock.') || o.id == 'boost.faction_change';
        }).toList();

        const sequentialSpecialIds = [
          <String>[
            'unlock.storage_cap.1',
            'unlock.storage_cap.2',
            'unlock.storage_cap.3',
          ],
          <String>[
            'unlock.fusion_slot.1',
            'unlock.fusion_slot.2',
            'unlock.fusion_slot.3',
            'unlock.fusion_slot.4',
            'unlock.fusion_slot.5',
          ],
        ];

        final nextSequentialOffers = <ShopOffer>[];
        for (final ids in sequentialSpecialIds) {
          String? nextId;
          for (final id in ids) {
            if (shopService.canPurchase(id)) {
              nextId = id;
              break;
            }
          }

          specialOffers.removeWhere((o) => ids.contains(o.id));
          if (nextId != null) {
            nextSequentialOffers.add(
              ShopService.allOffers.firstWhere((o) => o.id == nextId),
            );
          }
        }

        for (final offer in nextSequentialOffers.reversed) {
          specialOffers.insert(0, offer);
        }

        if (!_showPurchased) {
          specialOffers.removeWhere((o) => !shopService.canPurchase(o.id));
        }

        final elementalCreatorIndex = specialOffers.indexWhere(
          (o) => o.id == ShopService.elementalCreatorOfferId,
        );
        ShopOffer? elementalCreator;
        if (elementalCreatorIndex != -1) {
          elementalCreator = specialOffers.removeAt(elementalCreatorIndex);
        }

        if (specialOffers.isEmpty) {
          if (elementalCreator != null) {
            specialOffers.insert(0, elementalCreator);
          } else {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: EmptySection(
                message: 'All special items unlocked',
                icon: Icons.check_circle_outline_rounded,
              ),
            );
          }
        }

        if (elementalCreator != null) {
          specialOffers.insert(0, elementalCreator);
        }

        final cards = specialOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (mergedBalances[e.key] ?? 0) >= e.value,
          );
          final costWidgets = offer.id == ShopService.elementalCreatorOfferId
              ? _buildElementalCreatorTileCostIcons(
                  effectiveCost,
                  mergedBalances,
                )
              : <Widget>[
                  for (final entry in effectiveCost.entries)
                    CostChip(
                      currencyType: entry.key,
                      amount: entry.value,
                      available: mergedBalances[entry.key] ?? 0,
                    ),
                ];
          return GestureDetector(
            onTap: () => canPurchase
                ? _handlePurchase(context, offer, mergedBalances, canAffordUnit)
                : _showDetails(context, offer, mergedBalances, canAffordUnit),
            child: GameShopCard(
              key: ValueKey('special-${offer.id}'),
              title: offer.name,
              theme: theme,
              costWidgets: costWidgets,
              displayLabel: _specialUnlockLabel(offer),
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
            crossAxisCount: responsiveCrossAxisCount(context),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.75,
            children: cards,
          ),
        );
      },
    );
  }

  String? _specialUnlockLabel(ShopOffer offer) {
    if (offer.id.startsWith('unlock.storage_cap.')) return 'STORAGE';
    if (offer.id.startsWith('unlock.fusion_slot.')) return 'CHAMBERS';
    if (offer.id == 'boost.faction_change') return 'FACTION';
    return null;
  }

  List<Widget> _buildElementalCreatorTileCostIcons(
    Map<String, int> effectiveCost,
    Map<String, int> allCurrencies,
  ) {
    final widgets = <Widget>[];

    final silverCost = effectiveCost['silver'];
    if (silverCost != null) {
      widgets.add(
        CostChip(
          currencyType: 'silver',
          amount: silverCost,
          available: allCurrencies['silver'] ?? 0,
        ),
      );
    }

    widgets.addAll(
      effectiveCost.entries
          .where((entry) => ElementResources.byKey.containsKey(entry.key))
          .map((entry) {
            final resource = ElementResources.byKey[entry.key]!;
            final available = allCurrencies[entry.key] ?? 0;
            final hasEnough = available >= entry.value;
            final accent = t.readableAccent(resource.color);

            return Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hasEnough
                    ? accent.withValues(alpha: 0.16)
                    : Colors.red.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: hasEnough
                      ? accent.withValues(alpha: 0.42)
                      : Colors.red.withValues(alpha: 0.35),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/ui/${resource.biomeId}.png',
                  fit: BoxFit.contain,
                  color: hasEnough ? null : Colors.red.shade300,
                  colorBlendMode: hasEnough ? null : BlendMode.modulate,
                ),
              ),
            );
          }),
    );

    return widgets;
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
    await _purchaseSlot(slotNumber, offer.cost);
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

    // If this was an alchemy effect offer, prompt user to choose a creature
    // and instance to apply the purchased effect immediately. If user
    // cancels, the item remains in inventory for later application.
    if (success && offer.id.startsWith('effects.')) {
      // First, let user pick a species (CreatureSelectionSheet will return
      // a creature id via onSelectCreature).
      final gameData = context.read<GameDataService>();
      final discovered = await gameData.watchDiscoveredEntries().first;
      if (!context.mounted) return;
      final creatureId = await CreatureSelectionSheet.show<String?>(
        context: context,
        discoveredCreatures: discovered,
        stateScopeKey: 'shop_effect_species',
        onSelectCreature: (id) => Navigator.of(context).pop(id),
        isScrollControlled: true,
        title: 'Choose Species',
      );
      if (creatureId == null) return;

      final creature = gameData.getCreatureById(creatureId);
      if (creature == null) return;

      if (!context.mounted) return;
      final instanceId = await showModalBottomSheet<String?>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => BottomSheetShell(
          title: 'Choose Instance',
          theme: theme,
          child: InstancesSheet(
            species: creature,
            theme: theme,
            prefsScopeKey: 'shop_effect_instances',
            onTap: (inst) => Navigator.pop(context, inst.instanceId),
          ),
        ),
      );

      if (instanceId != null) {
        final applied = await shopService.applyEffectToInstance(
          offer.id,
          instanceId,
        );
        if (applied) {
          _toast(
            '${offer.name} applied',
            icon: Icons.check_rounded,
            color: t.teal,
          );
        } else {
          _toast(
            'Failed to apply ${offer.name}',
            icon: Icons.error_rounded,
            color: t.danger,
          );
        }
      }
    }

    if (success && offer.id == 'boost.faction_change') {
      HapticFeedback.mediumImpact();
      _toast(
        'Opening faction selector...',
        icon: Icons.flag_rounded,
        color: const Color(0xFF7C3AED),
      );
      // The app shell watches `require_faction_picker` and opens the picker.
      // Pushing it here as well stacks two pickers and makes the user choose twice.
    }
  }

  // ── BLACK MARKET BUTTON ────────────────────────────────────────────────────

  // ── ALCHEMICAL POWERUPS ROW ────────────────────────────────────────────────

  Widget _buildAlchemicalPowerupsRow(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: AlchemicalPowerupType.values.map((type) {
              final offerId = type.shopOfferId;
              final offer = ShopService.allOffers.firstWhere(
                (o) => o.id == offerId,
              );
              final effectiveCost = shopService.getEffectiveCost(offer);
              final qty = inventory[type.inventoryKey] ?? 0;
              final canAfford = effectiveCost.entries.every(
                (e) => (allCurrencies[e.key] ?? 0) >= e.value,
              );
              final canPurchase = shopService.canPurchase(offerId);
              return _ShopPowerupOrb(
                type: type,
                qty: qty,
                canAfford: canAfford,
                cost: effectiveCost,
                theme: theme,
                phaseDelay: Duration(
                  milliseconds:
                      AlchemicalPowerupType.values.indexOf(type) * 320,
                ),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (canPurchase) {
                    _handlePurchase(context, offer, allCurrencies, canAfford);
                  } else {
                    _showDetails(context, offer, allCurrencies, canAfford);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

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

  Widget _buildExchangeFloatingButton(BuildContext context) {
    return Consumer<ConstellationEffectsService>(
      builder: (context, constellations, _) {
        final unlocked = constellations.canSellAlchemonsInShop();
        final actionAccent = t.readableAccent(t.amberBright);

        return GestureDetector(
          onTap: () {
            if (!unlocked) {
              _toast(
                'Explore the constellations to unlock.',
                icon: Icons.lock_rounded,
                color: t.amber,
              );
              return;
            }

            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AlchemonExchangeScreen(),
              ),
            );
          },
          child: SizedBox(
            width: 75,
            height: 75,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: unlocked
                          ? [actionAccent, t.readableAccent(t.amber)]
                          : [t.bg2, t.bg1],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: unlocked ? actionAccent : t.borderDim,
                      width: 1.5,
                    ),
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: t.amber.withValues(alpha: 0.28),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    unlocked ? Icons.sell_rounded : Icons.lock_rounded,
                    color: unlocked ? t.onColor(actionAccent) : t.textMuted,
                    size: 28,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg0.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: unlocked ? actionAccent : t.borderDim,
                      ),
                    ),
                    child: Text(
                      'SELL',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: unlocked ? actionAccent : t.textMuted,
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    final timerAccent = t.readableAccent(t.amberBright);

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
                    color: timerAccent,
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

// ── Animated powerup orb for shop ─────────────────────────────────────────────

class _ShopPowerupOrb extends StatefulWidget {
  final AlchemicalPowerupType type;
  final int qty;
  final bool canAfford;
  final Map<String, int> cost;
  final FactionTheme theme;
  final Duration phaseDelay;
  final VoidCallback onTap;

  const _ShopPowerupOrb({
    required this.type,
    required this.qty,
    required this.canAfford,
    required this.cost,
    required this.theme,
    required this.phaseDelay,
    required this.onTap,
  });

  @override
  State<_ShopPowerupOrb> createState() => _ShopPowerupOrbState();
}

class _ShopPowerupOrbState extends State<_ShopPowerupOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _float = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future<void>.delayed(widget.phaseDelay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    final type = widget.type;
    final goldCost = widget.cost['gold'] ?? 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(0, _float.value * 5.5),
                  child: Transform.scale(
                    scale: _pulse.value,
                    child: AlchemicalPowerupOrbSphere(
                      type: type,
                      size: 62,
                      glowAlpha: widget.canAfford
                          ? 0.50 + _pulse.value * 0.08
                          : 0.18,
                      blurRadius: widget.canAfford ? 22 : 8,
                      spreadRadius: widget.canAfford ? 1 : -6,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            // Qty badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: widget.qty > 0
                    ? type.color.withValues(alpha: 0.14)
                    : t.bg3,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: widget.qty > 0
                      ? type.color.withValues(alpha: 0.45)
                      : t.borderDim,
                ),
              ),
              child: Text(
                'x${widget.qty}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: widget.qty > 0 ? type.color : t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              type.name.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: type.color,
                fontSize: 7,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              type.statKey.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textMuted,
                fontSize: 7,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            // Cost
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.hexagon_rounded,
                  color: widget.canAfford
                      ? const Color(0xFFFFD700)
                      : t.textMuted,
                  size: 11,
                ),
                const SizedBox(width: 3),
                Text(
                  '$goldCost',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: widget.canAfford
                        ? const Color(0xFFFFD700)
                        : t.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOLD VAULT — Modern card deck with GraphX particle backdrop
// ═══════════════════════════════════════════════════════════════════════════════

class _GoldVaultDeck extends StatefulWidget {
  const _GoldVaultDeck({
    required this.packs,
    required this.store,
    required this.theme,
    required this.onBuy,
  });

  final List<GoldPackDefinition> packs;
  final MobileStoreService store;
  final FactionTheme theme;
  final Future<void> Function(String productId) onBuy;

  @override
  State<_GoldVaultDeck> createState() => _GoldVaultDeckState();
}

class _GoldVaultDeckState extends State<_GoldVaultDeck>
    with TickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;
  late final AnimationController _floatCtrl;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  static const _tierColors = [
    Color(0xFFCD7F32), // bronze
    Color(0xFFC0C0C0), // silver
    Color(0xFFFFD700), // gold
    Color(0xFFFFF8DC), // celestial
  ];

  static const _tierGlows = [
    Color(0xFFE8A860),
    Color(0xFFE0E8F0),
    Color(0xFFFFE680),
    Color(0xFFFFFDE0),
  ];

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);

    if (widget.packs.isEmpty) {
      return const EmptySection(
        message: 'No gold packs available',
        icon: Icons.account_balance_wallet_outlined,
      );
    }

    final selected = widget.packs[_selectedIndex];
    final product = widget.store.productFor(selected.productId);
    final pending = widget.store.isPurchasePending(selected.productId);
    final canBuy =
        product != null && widget.store.storeAvailable && !pending;
    final price =
        product?.price ?? (widget.store.isLoading ? '...' : 'Unavailable');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Orb row with GraphX particles ──
        SizedBox(
          height: 140,
          child: Stack(
            children: [
              // GraphX particle backdrop
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: IgnorePointer(
                    child: SceneBuilderWidget(
                      autoSize: true,
                      builder: () => SceneController(
                        front: _GoldMoteScene(),
                        config: SceneConfig.autoRender,
                      ),
                    ),
                  ),
                ),
              ),
              // Orb card row
              Row(
                children: [
                  for (var i = 0; i < widget.packs.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: _GoldOrbCard(
                        pack: widget.packs[i],
                        selected: i == _selectedIndex,
                        color: _tierColors[i % _tierColors.length],
                        glow: _tierGlows[i % _tierGlows.length],
                        tier: _GoldOrbTier.values[i % _GoldOrbTier.values.length],
                        motion: _GoldOrbMotion.values[i % _GoldOrbMotion.values.length],
                        shimmer: _shimmerCtrl,
                        floatAnim: _floatCtrl,
                        delayPhase: i / math.max(1, widget.packs.length),
                        theme: widget.theme,
                        onTap: () {
                          if (i != _selectedIndex) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = i);
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        if (widget.store.lastError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              widget.store.lastError!,
              style: TextStyle(
                color: t.danger,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        const SizedBox(height: 10),

        // ── Detail / buy strip ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _GoldBuyStrip(
            key: ValueKey(selected.productId),
            pack: selected,
            priceLabel: price,
            pending: pending,
            canBuy: canBuy,
            accent: _tierColors[_selectedIndex % _tierColors.length],
            glow: _tierGlows[_selectedIndex % _tierGlows.length],
            theme: widget.theme,
            shimmer: _shimmerCtrl,
            onBuy: () => widget.onBuy(selected.productId),
          ),
        ),
      ],
    );
  }
}

// ── Orb tier & motion enums ──────────────────────────────────────────────────

enum _GoldOrbTier { bronze, silver, gold, celestial }

enum _GoldOrbMotion { tide, helix, wobble, pulse }

// ── Individual gold orb card ─────────────────────────────────────────────────

class _GoldOrbCard extends StatelessWidget {
  const _GoldOrbCard({
    required this.pack,
    required this.selected,
    required this.color,
    required this.glow,
    required this.tier,
    required this.motion,
    required this.shimmer,
    required this.floatAnim,
    required this.delayPhase,
    required this.theme,
    required this.onTap,
  });

  final GoldPackDefinition pack;
  final bool selected;
  final Color color;
  final Color glow;
  final _GoldOrbTier tier;
  final _GoldOrbMotion motion;
  final Animation<double> shimmer;
  final Animation<double> floatAnim;
  final double delayPhase;
  final FactionTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : t.borderDim.withValues(alpha: 0.25),
            width: selected ? 1.4 : 0.6,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    color.withValues(alpha: 0.10),
                    color.withValues(alpha: 0.04),
                  ]
                : [
                    t.bg2.withValues(alpha: 0.45),
                    t.bg2.withValues(alpha: 0.2),
                  ],
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: glow.withValues(alpha: 0.22),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: AnimatedBuilder(
          animation: shimmer,
          builder: (context, child) {
            return Stack(
              children: [
                if (selected)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CustomPaint(
                        painter: _ShimmerSweepPainter(
                          t: shimmer.value,
                          color: glow,
                        ),
                      ),
                    ),
                  ),
                child!,
              ],
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Floating animated orb ──
              SizedBox(
                height: 80,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final orbSize = constraints.maxWidth.clamp(48.0, 62.0);
                    return AnimatedBuilder(
                      animation: floatAnim,
                      builder: (context, child) {
                        final phase = floatAnim.value * 2 * math.pi +
                            delayPhase * math.pi;
                        final pulse = 0.5 + 0.5 * math.sin(phase);

                        final dx = switch (motion) {
                          _GoldOrbMotion.tide =>
                            math.cos(phase * 0.7) * 1.6,
                          _GoldOrbMotion.helix =>
                            math.sin(phase * 1.3) * 2.8,
                          _GoldOrbMotion.wobble =>
                            math.sin(phase * 1.4) * 2.0,
                          _GoldOrbMotion.pulse => 0.0,
                        };
                        final dy = switch (motion) {
                          _GoldOrbMotion.tide =>
                            math.sin(phase) * 4.8,
                          _GoldOrbMotion.helix =>
                            math.cos(phase * 1.6) * 3.2,
                          _GoldOrbMotion.wobble =>
                            math.sin(phase * 0.6) * 4.2,
                          _GoldOrbMotion.pulse =>
                            math.sin(phase * 0.8) * 2.4,
                        };
                        final rotation = switch (motion) {
                          _GoldOrbMotion.wobble =>
                            math.sin(phase) * 0.06,
                          _ => 0.0,
                        };
                        final scale = switch (motion) {
                          _GoldOrbMotion.pulse =>
                            (selected ? 1.0 : 0.92) +
                                (pulse * (selected ? 0.08 : 0.04)),
                          _ =>
                            (selected ? 1.0 : 0.92) +
                                (math.sin(phase) * 0.03),
                        };

                        return Transform.translate(
                          offset: Offset(dx, dy),
                          child: Transform.rotate(
                            angle: rotation,
                            child: Transform.scale(
                              scale: scale,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The orb
                          _GoldOrbCore(
                            tier: tier,
                            size: orbSize,
                            selected: selected,
                            energy: floatAnim,
                          ),
                          // Gold amount badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.35),
                                width: 0.6,
                              ),
                            ),
                            child: Text(
                              '${pack.goldAmount}',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: const Color(0xFFFFF1A8),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: glow.withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              // ── Title ──
              Text(
                pack.title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: selected ? t.textPrimary : t.textSecondary,
                  fontSize: 8,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              // ── Badge pill ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: selected ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  pack.badge,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: selected ? color : t.textMuted,
                    fontSize: 6,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
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

// ── Orb core renderer ────────────────────────────────────────────────────────

class _GoldOrbCore extends StatelessWidget {
  const _GoldOrbCore({
    required this.tier,
    required this.size,
    required this.selected,
    required this.energy,
  });

  final _GoldOrbTier tier;
  final double size;
  final bool selected;
  final Animation<double> energy;

  @override
  Widget build(BuildContext context) {
    // Celestial tier gets the special painter
    if (tier == _GoldOrbTier.celestial) {
      return AnimatedBuilder(
        animation: energy,
        builder: (context, _) {
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _CelestialOrbPainter(
                t: energy.value,
                boosted: selected,
              ),
            ),
          );
        },
      );
    }

    final coreColor = switch (tier) {
      _GoldOrbTier.bronze => const Color(0xFFC57A45),
      _GoldOrbTier.silver => const Color(0xFFCAD4E2),
      _GoldOrbTier.gold => const Color(0xFFFFCF40),
      _GoldOrbTier.celestial => const Color(0xFFFFE082),
    };
    final glowColor = switch (tier) {
      _GoldOrbTier.bronze => const Color(0xFFFFB380),
      _GoldOrbTier.silver => const Color(0xFFF4F7FF),
      _GoldOrbTier.gold => const Color(0xFFFFE082),
      _GoldOrbTier.celestial => const Color(0xFFFFF59D),
    };

    return AnimatedBuilder(
      animation: energy,
      builder: (context, _) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow ring (pulses)
            if (selected)
              SizedBox(
                width: size * 1.3,
                height: size * 1.3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glowColor.withValues(alpha: 0.18 + energy.value * 0.08),
                        Colors.transparent,
                      ],
                      stops: const [0.4, 1.0],
                    ),
                  ),
                ),
              ),
            // Main orb sphere
            SizedBox(
              width: size,
              height: size,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.25, -0.3),
                    colors: [
                      Colors.white.withValues(
                        alpha: selected ? 0.95 : 0.82,
                      ),
                      coreColor.withValues(alpha: 0.92),
                      coreColor.withValues(alpha: 0.6),
                      glowColor.withValues(alpha: 0.3),
                    ],
                    stops: const [0.0, 0.3, 0.65, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: glowColor.withValues(
                        alpha: selected ? 0.55 : 0.3,
                      ),
                      blurRadius: selected ? 24 : 14,
                      spreadRadius: selected ? 1 : -3,
                    ),
                  ],
                ),
              ),
            ),
            // Inner metaball blobs
            IgnorePointer(
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _OrbBlobPainter(
                    t: energy.value,
                    color: glowColor,
                    alpha: selected ? 0.24 : 0.12,
                  ),
                ),
              ),
            ),
            // Specular highlight
            Positioned(
              top: size * 0.12,
              left: size * 0.22,
              child: Container(
                width: size * 0.22,
                height: size * 0.14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(size),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(
                        alpha: selected ? 0.7 : 0.45,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Metaball blob painter (internal motion within the orb) ───────────────────

class _OrbBlobPainter extends CustomPainter {
  const _OrbBlobPainter({
    required this.t,
    required this.color,
    required this.alpha,
  });

  final double t;
  final Color color;
  final double alpha;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: alpha);
    final r = size.width / 2;
    final c = Offset(r, r);
    final phase = t * 2 * math.pi;

    // Three orbiting blobs inside the sphere
    canvas.drawCircle(
      Offset(
        c.dx + math.cos(phase * 1.2) * (r * 0.26),
        c.dy + math.sin(phase) * (r * 0.22),
      ),
      r * 0.28,
      p,
    );
    canvas.drawCircle(
      Offset(
        c.dx + math.cos(phase * 0.9 + 2.1) * (r * 0.20),
        c.dy + math.sin(phase * 1.1 + 1.4) * (r * 0.22),
      ),
      r * 0.20,
      p,
    );
    canvas.drawCircle(
      Offset(
        c.dx + math.sin(phase * 0.7 + 3.8) * (r * 0.18),
        c.dy + math.cos(phase * 1.3 + 0.6) * (r * 0.16),
      ),
      r * 0.15,
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbBlobPainter old) =>
      old.t != t || old.color != color || old.alpha != alpha;
}

// ── Celestial orb painter (premium tier — radiant multi-ring) ────────────────

class _CelestialOrbPainter extends CustomPainter {
  const _CelestialOrbPainter({required this.t, required this.boosted});

  final double t;
  final bool boosted;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final phase = t * 2 * math.pi;

    // Outer pulsing glow
    if (boosted) {
      final pulseR = r * (1.15 + math.sin(phase * 0.8) * 0.06);
      canvas.drawCircle(
        c,
        pulseR,
        Paint()
          ..color = const Color(0xFFFFF8D6).withValues(alpha: 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Core radial fill
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.2, -0.25),
          colors: [
            const Color(0xFFFFF8D6).withValues(alpha: boosted ? 0.95 : 0.80),
            const Color(0xFFFFD54F).withValues(alpha: 0.90),
            const Color(0xFFFFA000).withValues(alpha: 0.55),
            const Color(0xFFFF8F00).withValues(alpha: 0.20),
          ],
          stops: const [0.0, 0.38, 0.72, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );

    // Inner ring stroke
    canvas.drawCircle(
      c,
      r * 0.82,
      Paint()
        ..color = const Color(0xFFFFD54F).withValues(alpha: boosted ? 0.28 : 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Specular
    canvas.drawCircle(
      Offset(c.dx - r * 0.22, c.dy - r * 0.26),
      r * 0.18,
      Paint()
        ..color = Colors.white.withValues(alpha: boosted ? 0.55 : 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
  }

  @override
  bool shouldRepaint(covariant _CelestialOrbPainter old) =>
      old.t != t || old.boosted != boosted;
}

// ── Buy strip below the cards ────────────────────────────────────────────────

class _GoldBuyStrip extends StatelessWidget {
  const _GoldBuyStrip({
    super.key,
    required this.pack,
    required this.priceLabel,
    required this.pending,
    required this.canBuy,
    required this.accent,
    required this.glow,
    required this.theme,
    required this.shimmer,
    required this.onBuy,
  });

  final GoldPackDefinition pack;
  final String priceLabel;
  final bool pending;
  final bool canBuy;
  final Color accent;
  final Color glow;
  final FactionTheme theme;
  final Animation<double> shimmer;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final disabledColor = theme.isDark
        ? Colors.white.withValues(alpha: 0.35)
        : t.textMuted;

    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
              width: 0.8,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.isDark
                  ? [
                      const Color(0xFF131008).withValues(alpha: 0.95),
                      const Color(0xFF0A0804).withValues(alpha: 0.95),
                    ]
                  : [
                      theme.surfaceAlt.withValues(alpha: 0.95),
                      theme.surface.withValues(alpha: 0.95),
                    ],
            ),
          ),
          child: Stack(
            children: [
              // Animated accent line at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 2,
                child: CustomPaint(
                  painter: _AccentLinePainter(
                    t: shimmer.value,
                    color: accent,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  children: [
                    // Gold amount + title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${pack.goldAmount}G',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  shadows: [
                                    Shadow(
                                      color: glow.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                pack.title,
                                style: TextStyle(
                                  color: t.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            pack.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Buy button
                    GestureDetector(
                      onTap: canBuy ? onBuy : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: canBuy
                              ? accent.withValues(alpha: 0.16)
                              : t.bg2,
                          border: Border.all(
                            color: canBuy
                                ? accent.withValues(alpha: 0.5)
                                : t.borderDim,
                            width: canBuy ? 1.2 : 0.8,
                          ),
                          boxShadow: canBuy
                              ? [
                                  BoxShadow(
                                    color: glow.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    spreadRadius: -2,
                                  ),
                                ]
                              : null,
                        ),
                        child: pending
                            ? SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(accent),
                                ),
                              )
                            : Text(
                                priceLabel,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: canBuy ? accent : disabledColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// GraphX — floating gold mote particle scene
// ═══════════════════════════════════════════════════════════════════════════════

class _GoldMoteScene extends GSprite {
  static const int _maxMotes = 28;
  final math.Random _rng = math.Random();
  bool _seeded = false;

  @override
  void addedToStage() {
    stage!.onEnterFrame.add(_onTick);
  }

  @override
  void removedFromStage() {
    stage?.onEnterFrame.remove(_onTick);
  }

  void _onTick(dynamic event) {
    if (!_seeded && stage != null) {
      _seeded = true;
      for (var i = 0; i < _maxMotes; i++) {
        _spawnMote(initial: true);
      }
    }
    // Replenish motes that have been removed
    while (numChildren < _maxMotes) {
      _spawnMote(initial: false);
    }
  }

  void _spawnMote({required bool initial}) {
    final sw = stage?.stageWidth ?? 300;
    final sh = stage?.stageHeight ?? 120;

    final mote = addChild(GShape());
    final radius = 0.6 + _rng.nextDouble() * 1.8;
    final alpha = 0.15 + _rng.nextDouble() * 0.35;

    // Alternate between warm gold and white-gold tones
    final colors = [
      const Color(0xFFFFD700),
      const Color(0xFFFFF8DC),
      const Color(0xFFFFE082),
      const Color(0xFFFFC107),
    ];
    final c = colors[_rng.nextInt(colors.length)];

    mote.graphics
      ..beginFill(c.withValues(alpha: alpha))
      ..drawCircle(0, 0, radius)
      ..endFill();

    final startX = _rng.nextDouble() * sw;
    final startY = initial ? _rng.nextDouble() * sh : sh + 4;
    mote.setPosition(startX, startY);

    final endX = startX + (_rng.nextDouble() - 0.5) * 40;
    final endY = initial
        ? -4.0
        : -4.0;
    final dur = 2.0 + _rng.nextDouble() * 3.5;

    GTween.to(
      mote,
      dur,
      {
        'x': endX,
        'y': endY,
        'alpha': 0.0,
        'scaleX': 0.3,
        'scaleY': 0.3,
      },
      GVars(
        ease: GEase.easeInOut,
        delay: initial ? _rng.nextDouble() * 2.5 : 0,
        onComplete: () => mote.removeFromParent(true),
      ),
    );
  }
}

// ── Shimmer sweep painter (diagonal light pass) ──────────────────────────────

class _ShimmerSweepPainter extends CustomPainter {
  const _ShimmerSweepPainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final sweepX = -size.width * 0.3 + (t * size.width * 1.6);
    final w = size.width * 0.35;
    final rect = Rect.fromLTWH(sweepX, 0, w, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: 0.06),
          color.withValues(alpha: 0.10),
          color.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _ShimmerSweepPainter old) =>
      old.t != t || old.color != color;
}

// ── Accent line painter (animated top edge glow) ─────────────────────────────

class _AccentLinePainter extends CustomPainter {
  const _AccentLinePainter({required this.t, required this.color});
  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    final cx = size.width * (0.3 + 0.4 * (0.5 + 0.5 * math.sin(phase)));
    final gradient = LinearGradient(
      colors: [
        Colors.transparent,
        color.withValues(alpha: 0.5),
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.5),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    );
    final rect = Rect.fromCenter(
      center: Offset(cx, size.height / 2),
      width: size.width * 0.5,
      height: size.height,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _AccentLinePainter old) =>
      old.t != t || old.color != color;
}
