// lib/screens/shop_screen.dart
import 'dart:async';

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/black_market_button.dart';
import 'package:alchemons/widgets/element_resource_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
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
      _toast(
        'Not enough resources',
        icon: Icons.lock_rounded,
        color: Colors.orange,
      );
      return;
    }

    await db.settingsDao.setBlobSlotsUnlocked(target);
    await _refreshAll();
    _toast(
      'Bubble slot $target unlocked!',
      icon: Icons.bubble_chart_rounded,
      color: Colors.lightBlueAccent,
    );
    HapticFeedback.lightImpact();
  }

  void _toast(String msg, {IconData icon = Icons.check_rounded, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: color ?? Colors.teal,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final db = context.read<AlchemonsDatabase>();

    return Scaffold(
      backgroundColor: theme.surfaceAlt,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with currencies
            StreamBuilder<Map<String, int>>(
              stream: db.currencyDao.watchAllCurrencies(),
              builder: (context, currencySnap) {
                final allCurrencies =
                    currencySnap.data ?? {'gold': 0, 'silver': 0, 'soft': 0};
                return _buildHeader(theme, allCurrencies);
              },
            ),

            // Main Content - Single Scrollable View
            Expanded(child: _buildShopContent(theme, db)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(FactionTheme theme, Map<String, int> allCurrencies) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          // Top row: Black Market button, Title, Toggle
          Row(
            children: [
              _buildBlackMarketFloatingButton(context, theme.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'RESEARCH SHOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              ShowPurchasedToggle(
                value: _showPurchased,
                accent: theme.accent,
                onChanged: (v) async {
                  setState(() => _showPurchased = v);
                  await context
                      .read<AlchemonsDatabase>()
                      .settingsDao
                      .setShopShowPurchased(v);
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Currency bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.accent.withOpacity(0.4),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CurrencyPill(
                    icon: Icons.diamond_rounded,
                    color: const Color(0xFFFFD700),
                    amount: allCurrencies['gold'] ?? 0,
                  ),
                  Container(
                    width: 1,
                    height: 16,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  CurrencyPill(
                    icon: Icons.monetization_on_rounded,
                    color: const Color(0xFFC0C0C0),
                    amount: allCurrencies['silver'] ?? 0,
                  ),
                ],
              ),
            ),
          ),
          ResourceCollectionWidget(theme: theme),
        ],
      ),
    );
  }

  // NEW: Single scrollable content with all sections
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
                      // SECTION 1: HARVEST DEVICES
                      _buildSectionHeader(
                        'HARVEST DEVICES',
                        theme.text,
                        Icons.science_rounded,
                      ),
                      _buildHarvestDevicesGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                      ),

                      const SizedBox(height: 16),

                      // SECTION 2: INSTANT ITEMS
                      _buildSectionHeader(
                        'INSTANT ITEMS',
                        theme.text,
                        Icons.flash_on_rounded,
                      ),
                      _buildInstantItemsGrid(
                        theme,
                        allCurrencies,
                        inventoryByKey,
                      ),

                      const SizedBox(height: 16),

                      // SECTION 3: CURRENCY EXCHANGE
                      _buildSectionHeader(
                        'CURRENCY EXCHANGE',
                        theme.text,
                        Icons.currency_exchange_rounded,
                      ),
                      _buildCurrencyExchangeGrid(theme, allCurrencies),

                      const SizedBox(height: 16),

                      // SECTION 4: SPECIAL UNLOCKS
                      _buildSectionHeader(
                        'SPECIAL UNLOCKS',
                        theme.accent,
                        Icons.auto_awesome_rounded,
                      ),
                      _buildSpecialUnlocksGrid(theme, allCurrencies),

                      const SizedBox(height: 16),

                      // SECTION 5: UPGRADES
                      _buildSectionHeader(
                        'BUBBLE SLOTS',
                        theme.accent,
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

  Widget _buildSectionHeader(String title, Color accent, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestDevicesGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final deviceOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('device.harvest'))
            .toList();

        final cards = deviceOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final canAffordUnit = offer.cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );

          final invKey = offer.inventoryKey;
          final invQty = invKey != null ? (inventory[invKey] ?? 0) : 0;
          final status = invQty > 0 ? 'x$invQty' : null;

          final costWidgets = <Widget>[
            for (final entry in offer.cost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];

          return GameShopCard(
            key: ValueKey('device-${offer.id}'),
            title: offer.name,
            description: offer.description,
            icon: offer.icon,
            image: offer.assetName,
            theme: theme,
            costWidgets: costWidgets,
            statusText: status,
            enabled: canPurchase,
            canAfford: canAffordUnit,
            onPressed: () => _handlePurchase(context, offer, allCurrencies),
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
            childAspectRatio: 0.85, // Increased for shorter cards
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
            padding: EdgeInsets.all(12.0),
            child: EmptySection(
              message: 'No instant items available',
              icon: Icons.flash_off_rounded,
            ),
          );
        }

        final cards = instantOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final canAffordUnit = offer.cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );

          final invKey = offer.inventoryKey;
          final invQty = invKey != null ? (inventory[invKey] ?? 0) : 0;
          final status = invQty > 0 ? 'x$invQty' : null;

          final costWidgets = <Widget>[
            for (final entry in offer.cost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];

          return GameShopCard(
            key: ValueKey('instant-${offer.id}'),
            title: offer.name,
            description: offer.description,
            icon: offer.icon,
            image: offer.assetName,
            theme: theme,
            costWidgets: costWidgets,
            statusText: status,
            enabled: canPurchase,
            canAfford: canAffordUnit,
            onPressed: () => _handlePurchase(context, offer, allCurrencies),
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

  Widget _buildCurrencyExchangeGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final exchangeOffers = ShopService.allOffers
            .where((o) => o.id.startsWith('fx.'))
            .toList();

        final cards = exchangeOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final canAffordUnit = offer.cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );

          final costWidgets = <Widget>[
            for (final entry in offer.cost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];

          return GameShopCard(
            key: ValueKey('fx-${offer.id}'),
            title: offer.name,
            description: offer.description,
            icon: offer.icon,
            image: offer.assetName,
            theme: theme,
            costWidgets: costWidgets,
            enabled: canPurchase,
            canAfford: canAffordUnit,
            onPressed: () => _handlePurchase(context, offer, allCurrencies),
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
            childAspectRatio: 0.7,
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

        if (!_showPurchased) {
          specialOffers.removeWhere((o) => !shopService.canPurchase(o.id));
        }

        if (specialOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12.0),
            child: EmptySection(
              message: 'All special items unlocked',
              icon: Icons.check_circle_outline_rounded,
            ),
          );
        }

        final cards = specialOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final canAffordUnit = offer.cost.entries.every(
            (e) => (allCurrencies[e.key] ?? 0) >= e.value,
          );

          final costWidgets = <Widget>[
            for (final entry in offer.cost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: allCurrencies[entry.key] ?? 0,
              ),
          ];

          return GameShopCard(
            key: ValueKey('special-${offer.id}'),
            title: offer.name,
            description: offer.description,
            icon: offer.icon,
            image: offer.assetName,
            theme: theme,
            costWidgets: costWidgets,
            enabled: canPurchase,
            canAfford: canAffordUnit,
            onPressed: () => _handlePurchase(context, offer, allCurrencies),
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
    final balances = resourceBalances;
    final items = <Widget>[];

    // Bubble Slot 2
    if (_slotsUnlocked < 2 || _showPurchased) {
      final cost = _slot2Cost;
      final enabled = _slotsUnlocked < 2;
      final canAfford = cost.entries.every(
        (e) => (balances[e.key] ?? 0) >= e.value,
      );
      final costWidgets = <Widget>[
        for (final res in ElementResources.all)
          if ((cost[res.settingsKey] ?? 0) > 0)
            MiniCostChip(
              resource: res,
              required: cost[res.settingsKey]!,
              current: balances[res.settingsKey] ?? 0,
            ),
      ];

      items.add(
        GameShopCard(
          key: const ValueKey('upgrade-slot-2'),
          icon: Icons.bubble_chart_rounded,
          title: 'Bubble Slot 2',
          theme: theme,
          costWidgets: costWidgets,
          enabled: enabled,
          canAfford: canAfford,
          onPressed: () => _purchaseSlot(2),
        ),
      );
    }

    // Bubble Slot 3
    if (_slotsUnlocked < 3 || _showPurchased) {
      final cost = _slot3Cost;
      final enabled = _slotsUnlocked < 3;
      final canAfford = cost.entries.every(
        (e) => (balances[e.key] ?? 0) >= e.value,
      );
      final costWidgets = <Widget>[
        for (final res in ElementResources.all)
          if ((cost[res.settingsKey] ?? 0) > 0)
            MiniCostChip(
              resource: res,
              required: cost[res.settingsKey]!,
              current: balances[res.settingsKey] ?? 0,
            ),
      ];

      items.add(
        GameShopCard(
          key: const ValueKey('upgrade-slot-3'),
          icon: Icons.bubble_chart_rounded,
          title: 'Bubble Slot 3',
          theme: theme,
          costWidgets: costWidgets,
          enabled: enabled,
          canAfford: canAfford,
          onPressed: () => _purchaseSlot(3),
        ),
      );
    }

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
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

  Future<void> _handlePurchase(
    BuildContext context,
    ShopOffer offer,
    Map<String, int> currencies,
  ) async {
    final theme = context.read<FactionTheme>();
    final shopService = context.read<ShopService>();

    // Get inventory quantity for this item
    final invQty = offer.inventoryKey != null
        ? shopService.inventoryCountForOffer(offer.id)
        : 0;

    // STEP 1: Show item detail dialog
    final shouldProceed = await showItemDetailDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: currencies,
      inventoryQty: invQty,
    );

    if (!shouldProceed || !context.mounted) return;

    // STEP 2: Show purchase confirmation (with quantity selection)
    final qty = await showPurchaseConfirmationDialog(
      context: context,
      offer: offer,
      theme: theme,
      currencies: currencies,
    );

    if (qty == null || !context.mounted) return;

    HapticFeedback.lightImpact();
    final success = await shopService.purchase(offer.id, qty: qty);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_rounded : Icons.error_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success ? '${offer.name} purchased x$qty!' : 'Purchase failed',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildBlackMarketFloatingButton(BuildContext context, Color accent) {
    return Consumer<BlackMarketService>(
      builder: (context, marketService, child) {
        return AnimatedBlackMarketButton(
          isOpen: marketService.isOpen,
          accent: accent,
          onTap: marketService.isOpen
              ? () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => BlackMarketScreen(accent: accent),
                    ),
                  );
                }
              : () {
                  HapticFeedback.mediumImpact();
                  _showMarketClosedDialog(context, accent, marketService);
                },
        );
      },
    );
  }

  void _showMarketClosedDialog(
    BuildContext context,
    Color accent,
    BlackMarketService marketService,
  ) {
    final timeUntil = marketService.getTimeUntilOpen();
    final hoursUntil = timeUntil.inHours;
    final minutesUntil = timeUntil.inMinutes % 60;
    final theme = context.read<FactionTheme>();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accent.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text(
                'There\'s nobody here',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                hoursUntil > 0
                    ? 'However, there is a digital timer in the corner with a countdown: \n\n${hoursUntil}h ${minutesUntil}m'
                    : '$minutesUntil minutes',
                style: const TextStyle(
                  color: Color.fromARGB(160, 255, 168, 38),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: accent.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'OKAY',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 0.6,
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
