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
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
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

  Widget _buildGoldVaultSection(FactionTheme theme) {
    return Consumer<MobileStoreService>(
      builder: (context, store, _) {
        final packs = store.packDefinitions;
        final goldAccent = t.readableAccent(const Color(0xFFFFD700));

        Future<void> buyPack(String productId) async {
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

        final cards = packs.map((pack) {
          final product = store.productFor(pack.productId);
          final priceLabel =
              product?.price ?? (store.isLoading ? '...' : 'Unavailable');
          final canBuy = product != null && store.storeAvailable;
          final pending = store.isPurchasePending(pack.productId);
          final accent = t.readableAccent(switch (pack.badge) {
            'STARTER' => const Color(0xFFFFE082),
            'POPULAR' => const Color(0xFFFFD54F),
            'VALUE' => const Color(0xFFFFB300),
            _ => const Color(0xFFFF8F00),
          });
          final cardGradient = theme.isDark
              ? [
                  const Color(0xFF1C1510).withValues(alpha: 0.98),
                  const Color(0xFF0E0B08).withValues(alpha: 0.98),
                ]
              : [
                  theme.surfaceAlt.withValues(alpha: 0.98),
                  theme.surface.withValues(alpha: 0.98),
                ];
          final mutedTextColor = theme.isDark
              ? Colors.white.withValues(alpha: 0.82)
              : t.textSecondary;
          final disabledBgColor = theme.isDark
              ? Colors.white.withValues(alpha: 0.04)
              : t.bg2;
          final disabledBorderColor = theme.isDark
              ? Colors.white.withValues(alpha: 0.08)
              : t.borderDim;
          final disabledTextColor = theme.isDark
              ? Colors.white.withValues(alpha: 0.4)
              : t.textMuted;

          return GestureDetector(
            onTap: canBuy && !pending ? () => buyPack(pack.productId) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accent.withValues(alpha: canBuy ? 0.55 : 0.2),
                ),
                gradient: LinearGradient(
                  colors: cardGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -16,
                    top: -16,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            pack.badge,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          style: TextStyle(
                            color: accent,
                            fontSize: 28,
                            height: 0.95,
                            fontWeight: FontWeight.w900,
                          ),
                          '${pack.goldAmount}',
                        ),
                        const SizedBox(height: 4),
                        Text(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: mutedTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                          'GOLD',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          pack.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 12,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: canBuy
                                ? accent.withValues(alpha: 0.14)
                                : disabledBgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: canBuy
                                  ? accent.withValues(alpha: 0.35)
                                  : disabledBorderColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (pending)
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      accent,
                                    ),
                                  ),
                                )
                              else
                                Icon(
                                  Icons.shopping_bag_rounded,
                                  size: 14,
                                  color: canBuy ? accent : disabledTextColor,
                                ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pending ? 'PROCESSING' : priceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: canBuy ? accent : disabledTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (store.lastError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Text(
                  store.lastError!,
                  style: TextStyle(
                    color: t.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (store.isLoading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                  children: cards,
                ),
              ),
          ],
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
                'Unlock Specimen Exchange in the Explorer tree',
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
