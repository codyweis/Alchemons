// lib/screens/black_market_screen.dart
import 'dart:ui';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/creature_filter_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/creature_image.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/species_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/constants/black_market_constants.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';

class BlackMarketScreen extends StatefulWidget {
  final Color accent;

  const BlackMarketScreen({super.key, required this.accent});

  @override
  State<BlackMarketScreen> createState() => _BlackMarketScreenState();
}

class _BlackMarketScreenState extends State<BlackMarketScreen>
    with SingleTickerProviderStateMixin {
  final List<CreatureInstance> _selectedForSale = [];
  final Map<String, int> _selectedResources = {}; // resource key -> quantity
  int _totalValue = 0;
  int _totalResourceValue = 0;
  int _activeTab = 1;
  int _sellSubTab = 0; // 0 = Alchemons, 1 = Resources

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final marketService = context.watch<BlackMarketService>();
    final constellations = context.watch<ConstellationEffectsService>();
    final canSellResources = constellations.canSellResources();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/ui/blackmarket.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (_activeTab == 0) _buildPremiumBanner(marketService),
                _buildTabSelector(),
                if (_activeTab == 0)
                  _buildSellSubTabSelector(canSellResources: canSellResources),
                Expanded(
                  child: _activeTab == 0
                      ? (_sellSubTab == 0
                            ? (_selectedForSale.isEmpty
                                  ? _buildEmptyState()
                                  : _buildSelectedCreatures())
                            : (!canSellResources
                                  ? _buildLockedResourceState()
                                  : (_selectedResources.isEmpty
                                        ? _buildEmptyResourceState()
                                        : _buildSelectedResources())))
                      : _buildBuySection(marketService),
                ),
                if (_activeTab == 0)
                  _buildBottomActions(canSellResources: canSellResources),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedResourceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 80,
              color: Colors.white.withOpacity(0.15),
            ),
            const SizedBox(height: 20),
            Text(
              'Resource selling is locked',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Not accepting resources for some reason.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellSubTabSelector({required bool canSellResources}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF8B4789).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SubTabButton(
                  label: 'ALCHEMONS',
                  icon: Icons.pets_rounded,
                  isActive: _sellSubTab == 0,
                  onTap: () {
                    setState(() => _sellSubTab = 0);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(width: 3),
              Expanded(
                child: _SubTabButton(
                  label: canSellResources ? 'RESOURCES' : 'RESOURCES (LOCKED)',
                  icon: Icons.inventory_2_rounded,
                  isActive: _sellSubTab == 1,
                  onTap: () {
                    if (!canSellResources) {
                      HapticFeedback.mediumImpact();
                      _showToast(
                        'Not accepting resources for some reason.',
                        icon: Icons.lock_rounded,
                        color: Colors.deepPurple,
                      );
                      return;
                    }
                    setState(() => _sellSubTab = 1);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF8B4789).withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  label: 'BUY',
                  icon: Icons.shopping_bag_rounded,
                  isActive: _activeTab == 1,
                  onTap: () {
                    setState(() => _activeTab = 1);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              const SizedBox(width: 4),

              Expanded(
                child: _TabButton(
                  label: 'SELL',
                  icon: Icons.sell_rounded,
                  isActive: _activeTab == 0,
                  onTap: () {
                    setState(() => _activeTab = 0);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add buy section
  Widget _buildBuySection(BlackMarketService marketService) {
    if (marketService.dailyOffers.isEmpty && marketService.dailyVials.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.15),
              ),
              const SizedBox(height: 20),
              Text(
                "Loading weekly deals...",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      children: [
        // --- Extraction Vials header + grid ---
        if (marketService.dailyVials.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EXTRACTION VIALS',
                  style: TextStyle(
                    color: Color(0xFFD8BFD8),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_rounded,
                        size: 12,
                        color: Colors.orange.shade300,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Resets Weekly',
                        style: TextStyle(
                          color: Colors.orange.shade300,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 320,
            child: GridView.builder(
              scrollDirection: Axis.vertical,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 1,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: marketService.dailyVials.length,
              itemBuilder: (context, index) {
                final vial = marketService.dailyVials[index];
                final isPurchased = marketService.isPurchased(
                  vial.id,
                ); // Check purchased status

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: SizedBox(
                    width: 180,
                    child: Stack(
                      children: [
                        ExtractionVialCard(
                          vial: vial,
                          compact: true,
                          onTap: () => _showVialDetails(vial),
                          onAddToInventory: isPurchased
                              ? null
                              : () => _buyVial(vial, marketService),
                        ),
                        if (isPurchased)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.withOpacity(0.6),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 16,
                                        color: Colors.greenAccent,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'PURCHASED',
                                        style: TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        // --- Today's Deals header ---
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_rounded,
                size: 18,
                color: Color(0xFFD8BFD8),
              ),
              const SizedBox(width: 8),
              const Text(
                "WEEKLY DEALS",
                style: TextStyle(
                  color: Color(0xFFD8BFD8),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // --- Deals list ---
        ...marketService.dailyOffers.map((offer) {
          final isPurchased = marketService.isPurchased(offer.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _OfferCard(
              offer: offer,
              isPurchased: isPurchased,
              onPurchase: () => _handlePurchase(offer, marketService),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _buyVial(
    ExtractionVial vial,
    BlackMarketService marketService,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();

    // Mythic uses gold; others use silver (mirrors _priceFor)
    final usesGold = vial.rarity == VialRarity.legendary;
    final costType = usesGold ? 'gold' : 'silver';
    final currencies = await db.currencyDao.getAllCurrencies();
    final available = currencies[costType] ?? 0;

    if (available < vial.price!) {
      _showToast(
        'Not enough $costType',
        icon: Icons.warning_rounded,
        color: Colors.orange,
      );
      return;
    }

    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _PurchaseConfirmationDialog(
        offer: DailyOffer(
          id: vial.id,
          name: vial.name,
          description: '${vial.group.displayName} • ${vial.rarity.name}',
          icon: Icons.science_rounded,
          cost: {costType: vial.price!},
          rewardType: 'item',
          reward: {
            'type': 'vial',
            'group': vial.group.displayName,
            'rarity': vial.rarity.name,
          },
        ),
        accent: widget.accent,
      ),
    );
    if (confirmed != true || !mounted) return;

    // Deduct
    if (usesGold) {
      await db.currencyDao.addGold(-vial.price!);
    } else {
      await db.currencyDao.addSilver(-vial.price!);
    }

    await db.inventoryDao.addVial(vial.name, vial.group, vial.rarity, qty: 1);

    // Mark 'purchased' so the UI disables the card
    await marketService.purchaseOffer(vial.id);

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    _showToast(
      '${vial.name} added to your inventory!',
      icon: Icons.check_circle_rounded,
      color: theme.text,
    );
  }

  void _showVialDetails(ExtractionVial vial) {
    // Optional: present a bottom sheet with a bigger fusion flourish, lore, etc.
    // For now, just a simple dialog:
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF1A1D23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: widget.accent.withOpacity(0.5), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vial.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${vial.group.displayName} • ${vial.rarity.name}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ExtractionVialCard(vial: vial, compact: true),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Price: ${vial.price} ${vial.rarity == VialRarity.mythic ? 'gold' : 'silver'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase(
    DailyOffer offer,
    BlackMarketService marketService,
  ) async {
    final db = context.read<AlchemonsDatabase>();

    // Check if can afford
    final currencies = await db.currencyDao.getAllCurrencies();
    for (final entry in offer.cost.entries) {
      final available = currencies[entry.key] ?? 0;
      if (available < entry.value) {
        _showToast(
          'Not enough ${entry.key}',
          icon: Icons.warning_rounded,
          color: Colors.orange,
        );
        return;
      }
    }

    // Confirm purchase
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          _PurchaseConfirmationDialog(offer: offer, accent: widget.accent),
    );

    if (confirmed != true || !mounted) return;

    // Deduct cost
    for (final entry in offer.cost.entries) {
      if (entry.key == 'gold') {
        await db.currencyDao.addGold(-entry.value);
      } else if (entry.key == 'silver') {
        await db.currencyDao.addSilver(-entry.value);
      }
    }

    // Grant reward
    if (offer.rewardType == 'currency') {
      for (final entry in offer.reward.entries) {
        if (entry.key == 'gold') {
          await db.currencyDao.addGold(entry.value as int);
        } else if (entry.key == 'silver') {
          await db.currencyDao.addSilver(entry.value as int);
        }
      }
    } else if (offer.rewardType == 'resources') {
      for (final entry in offer.reward.entries) {
        await db.currencyDao.addResource(entry.key, entry.value as int);
      }
    } else if (offer.rewardType == 'item') {}

    // Mark as purchased
    await marketService.purchaseOffer(offer.id);

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    _showToast(
      '${offer.name} purchased!',
      icon: Icons.check_circle_rounded,
      color: Colors.green,
    );
  }

  void _showToast(String msg, {IconData? icon, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.white, size: 18),
            if (icon != null) const SizedBox(width: 10),
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
      ),
    );
  }

  Widget _buildTopBar() {
    final db = context.read<AlchemonsDatabase>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Currencies
          Expanded(
            child: StreamBuilder<Map<String, int>>(
              stream: db.currencyDao.watchAllCurrencies(),
              builder: (context, snap) {
                final curr = snap.data ?? {'gold': 0, 'silver': 0};
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF8B4789).withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CurrencyPill(
                          icon: Icons.diamond_rounded,
                          color: const Color(0xFFFFD700),
                          amount: curr['gold'] ?? 0,
                        ),
                        Container(
                          width: 1,
                          height: 20,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        _CurrencyPill(
                          icon: Icons.monetization_on_rounded,
                          color: const Color(0xFFC0C0C0),
                          amount: curr['silver'] ?? 0,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner(BlackMarketService marketService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF8B4789).withOpacity(0.8),
                Colors.purple.shade900.withOpacity(0.8),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF8B4789).withOpacity(0.6),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.stars_rounded,
                  color: Colors.orange.shade300,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "WEEKLY PREMIUM",
                      style: TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${marketService.premiumRarity.toUpperCase()}${marketService.premiumType.toUpperCase()}',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Text(
                  '+${((marketService.premiumBonus - 1) * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.15),
            ),
            const SizedBox(height: 20),
            Text(
              'Select specimens to sell',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to browse',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResourceState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.science_outlined,
              size: 80,
              color: Colors.white.withOpacity(0.15),
            ),
            const SizedBox(height: 20),
            Text(
              'Select resources to sell',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to choose',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedResources() {
    return StreamBuilder<Map<String, int>>(
      stream: context
          .read<AlchemonsDatabase>()
          .currencyDao
          .watchResourceBalances(),
      builder: (context, snapshot) {
        final balances = snapshot.data ?? {};

        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            // Header
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_cart_rounded,
                      size: 18,
                      color: Colors.orange.shade300,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'SELECTED RESOURCES',
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedResources.clear();
                          _recalculateResourceTotal();
                        });
                        HapticFeedback.lightImpact();
                      },
                      child: Text(
                        'Clear',
                        style: TextStyle(
                          color: Colors.red.shade300,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Resource list
            ...(_selectedResources.entries.map((entry) {
              final resource = ElementResources.all.firstWhere(
                (r) => r.settingsKey == entry.key,
                orElse: () => ElementResources.all.first,
              );
              final qty = entry.value;
              final available = balances[entry.key] ?? 0;
              final price = _calculateResourcePrice(entry.key, qty);

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _CompactResourceRow(
                  resource: resource,
                  quantity: qty,
                  available: available,
                  price: price,
                  onQuantityChanged: (newQty) {
                    setState(() {
                      if (newQty <= 0) {
                        _selectedResources.remove(entry.key);
                      } else {
                        _selectedResources[entry.key] = newQty.clamp(
                          1,
                          available,
                        );
                      }
                      _recalculateResourceTotal();
                    });
                  },
                  onRemove: () {
                    setState(() {
                      _selectedResources.remove(entry.key);
                      _recalculateResourceTotal();
                    });
                    HapticFeedback.lightImpact();
                  },
                ),
              );
            })),

            const SizedBox(height: 8),

            // Total
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL VALUE',
                      style: TextStyle(
                        color: Color(0xFFE8EAED),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalResourceValue',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedCreatures() {
    final repo = context.read<CreatureCatalog>();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      children: [
        // Header
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 18,
                  color: Colors.orange.shade300,
                ),
                const SizedBox(width: 8),
                Text(
                  'SELECTED (${_selectedForSale.length})',
                  style: TextStyle(
                    color: Colors.orange.shade300,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedForSale.clear();
                      _totalValue = 0;
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: Colors.red.shade300,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Creature list
        ...(_selectedForSale.map((inst) {
          final species = repo.getCreatureById(inst.baseId);
          final factions = context.read<FactionService>();

          final price = _computeInstanceSellPrice(inst, species, factions);

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _CompactCreatureRow(
              instance: inst,
              species: species,
              price: price,
              onRemove: () {
                setState(() {
                  _selectedForSale.remove(inst);
                  _recalculateTotal();
                });
                HapticFeedback.lightImpact();
              },
            ),
          );
        })),

        const SizedBox(height: 8),

        // Total
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'TOTAL VALUE',
                  style: TextStyle(
                    color: Color(0xFFE8EAED),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 18,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_totalValue',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions({required bool canSellResources}) {
    final isAlchemonsTab = _sellSubTab == 0;
    final hasSelection = isAlchemonsTab
        ? _selectedForSale.isNotEmpty
        : _selectedResources.isNotEmpty;
    final canInteract = isAlchemonsTab || canSellResources;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Browse button
            GestureDetector(
              onTap: !canInteract
                  ? () {
                      _showToast(
                        'Unlock "Valuable Resources" in the Extraction tree to sell resources.',
                        icon: Icons.lock_rounded,
                        color: Colors.deepPurple,
                      );
                      HapticFeedback.mediumImpact();
                    }
                  : (isAlchemonsTab
                        ? _showInstanceBrowser
                        : _showResourceBrowser),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4789).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF8B4789).withOpacity(0.6),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isAlchemonsTab
                            ? Icons.add_shopping_cart_rounded
                            : Icons.science_rounded,
                        color: const Color(0xFFD8BFD8),
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isAlchemonsTab
                            ? 'SELECT SPECIMENS'
                            : 'SELECT RESOURCES',
                        style: const TextStyle(
                          color: Color(0xFFD8BFD8),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sell button
            if (hasSelection) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: !canInteract
                    ? () {
                        _showToast(
                          'Unlock "Valuable Resources" in the Extraction tree to sell resources.',
                          icon: Icons.lock_rounded,
                          color: Colors.deepPurple,
                        );
                        HapticFeedback.mediumImpact();
                      }
                    : (isAlchemonsTab ? _confirmSale : _confirmResourceSale),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade800],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.shade400, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.sell_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'COMPLETE SALE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showResourceBrowser() async {
    final db = context.read<AlchemonsDatabase>();
    final balances = await db.currencyDao.watchResourceBalances().first;

    if (!mounted) return;
    final theme = context.read<FactionTheme>();
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.canSellResources()) {
      _showToast(
        'Unlock "Valuable Resources" in the Extraction tree to sell resources.',
        icon: Icons.lock_rounded,
        color: Colors.deepPurple,
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: true,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    border: Border(bottom: BorderSide(color: theme.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Resources',
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Choose resources to sell',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.border),
                          ),
                          child: Icon(Icons.close, color: theme.text, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),

                // Resources list
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: ElementResources.all.map((resource) {
                      final balance = balances[resource.settingsKey] ?? 0;
                      final alreadySelected = _selectedResources.containsKey(
                        resource.settingsKey,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: balance > 0
                              ? () {
                                  setState(() {
                                    if (alreadySelected) {
                                      _selectedResources.remove(
                                        resource.settingsKey,
                                      );
                                    } else {
                                      _selectedResources[resource
                                          .settingsKey] = (balance * 0.1)
                                          .ceil(); // Default to 10% of balance
                                    }
                                    _recalculateResourceTotal();
                                  });
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(context);
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: balance > 0
                                  ? (alreadySelected
                                        ? theme.accent.withOpacity(0.2)
                                        : theme.surfaceAlt)
                                  : theme.surfaceAlt.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: alreadySelected
                                    ? theme.accent
                                    : theme.border,
                                width: alreadySelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Resource icon
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: resource.color.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: resource.color.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      resource.icon,
                                      color: resource.color,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Resource info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        resource.biomeLabel,
                                        style: TextStyle(
                                          color: balance > 0
                                              ? theme.text
                                              : theme.textMuted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        'Available: $balance',
                                        style: TextStyle(
                                          color: theme.textMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (alreadySelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: theme.accent,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _calculateResourcePrice(String resourceKey, int quantity) {
    // Base price per unit: 2 resources = 1 silver (0.5 silver per resource)
    // This matches the shop's 5,000 resources = 1 gold conversion
    // (5,000 resources * 0.5 silver = 2,500 silver, better balanced economy)
    return (quantity / 2).floor();
  }

  /// Final per-instance sell price with all per-creature modifiers
  /// (rarity/level/tint/prismatic) + Earthen faction perk.
  int _computeInstanceSellPrice(
    CreatureInstance inst,
    Creature? species,
    FactionService factions,
  ) {
    final basePrice = BlackMarketConstants.calculateSellPrice(
      rarity: species?.rarity ?? 'common',
      level: inst.level,
      isPrismatic: inst.isPrismaticSkin,
      natureId: inst.natureId,
      tintId: decodeGenetics(inst.geneticsJson)!.tinting,
    );

    // Earthen perk: +50% value for earthen specimens
    final bool isEarthenCreature =
        species != null && species.types.contains('Earth');

    final perkMult = factions.earthenSaleValueMultiplier(
      isEarthenCreature: isEarthenCreature,
    );

    return (basePrice * perkMult).round();
  }

  void _recalculateResourceTotal() {
    _totalResourceValue = 0;
    _selectedResources.forEach((key, qty) {
      _totalResourceValue += _calculateResourcePrice(key, qty);
    });
  }

  Future<void> _confirmResourceSale() async {
    if (_selectedResources.isEmpty) return;

    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.canSellResources()) {
      _showToast(
        //fancy term for locked
        'Currently obstructed.',
        icon: Icons.lock_rounded,
        color: Colors.deepPurple,
      );
      return;
    }

    final totalItems = _selectedResources.values.fold<int>(
      0,
      (sum, qty) => sum + qty,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ResourceSaleConfirmationDialog(
        resourceCount: _selectedResources.length,
        totalQuantity: totalItems,
        total: _totalResourceValue,
        accent: widget.accent,
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();

    // Deduct resources
    for (final entry in _selectedResources.entries) {
      await db.currencyDao.addResource(entry.key, -entry.value);
    }

    // Add silver
    await db.currencyDao.addSilver(_totalResourceValue);

    setState(() {
      _selectedResources.clear();
      _totalResourceValue = 0;
    });

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sold $totalItems resources for $_totalResourceValue silver',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // Rest of your methods remain the same...
  void _showInstanceBrowser() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final theme = context.read<FactionTheme>();
    final allInstances = await db.creatureDao.listAllInstances();

    final Map<String, List<CreatureInstance>> grouped = {};
    for (final inst in allInstances) {
      if (inst.locked) continue;
      grouped.putIfAbsent(inst.baseId, () => []).add(inst);
    }

    if (!mounted) return;

    final selectedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        expand: true,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, 0),
                radius: 1.2,
                colors: [
                  theme.surface,
                  theme.surface,
                  theme.surfaceAlt.withOpacity(.6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    border: Border(bottom: BorderSide(color: theme.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select Species',
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Choose which creatures to sell',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.border),
                          ),
                          child: Icon(Icons.close, color: theme.text, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                // Species picker
                Expanded(
                  child: SpeciesPickerSheet(grouped: grouped, theme: theme),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (selectedSpeciesId == null || !mounted) return;

    final species = repo.getCreatureById(selectedSpeciesId);
    if (species == null) return;

    _showInstancePicker(species, grouped[selectedSpeciesId]!);
  }

  void _showInstancePicker(Creature species, List<CreatureInstance> instances) {
    final theme = context.read<FactionTheme>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Dynamically assign IDs to slots based on current selection
            final String? slot1 = _selectedForSale.isNotEmpty
                ? _selectedForSale[0].instanceId
                : null;
            final String? slot2 = _selectedForSale.length > 1
                ? _selectedForSale[1].instanceId
                : null;
            final String? slot3 = _selectedForSale.length > 2
                ? _selectedForSale[2].instanceId
                : null;

            return BottomSheetShell(
              theme: theme,
              title: 'Select ${species.name}',
              child: InstancesSheet(
                species: species,
                theme: theme,
                selectionMode: true,
                initialDetailMode: InstanceDetailMode.stats,
                selectedInstanceIds: _selectedForSale
                    .map((e) => e.instanceId)
                    .toList(),
                onTap: (inst) {
                  setState(() {
                    if (_selectedForSale.any(
                      (i) => i.instanceId == inst.instanceId,
                    )) {
                      _selectedForSale.removeWhere(
                        (i) => i.instanceId == inst.instanceId,
                      );
                    } else {
                      _selectedForSale.add(inst);
                    }
                    _recalculateTotal();
                  });

                  setModalState(() {});

                  HapticFeedback.selectionClick();
                },
              ),
            );
          },
        );
      },
    );
  }

  void _recalculateTotal() {
    final repo = context.read<CreatureCatalog>();
    final factions = context.read<FactionService>();

    // Per-creature prices *including* Earthen perk
    final prices = _selectedForSale.map((inst) {
      final species = repo.getCreatureById(inst.baseId);
      return _computeInstanceSellPrice(inst, species, factions);
    }).toList();

    final baseTotal = prices.fold<int>(0, (sum, price) => sum + price);
    final bulkBonus = BlackMarketConstants.calculateBulkBonus(prices);
    final preConstellationTotal = baseTotal + bulkBonus;

    // 🔮 Apply constellation sale boosts (Extraction tree)
    final constellations = context.read<ConstellationEffectsService>();
    final saleMult = constellations.getAlchemonSaleMultiplier();

    _totalValue = (preConstellationTotal * saleMult).round();
  }

  Future<void> _confirmSale() async {
    if (_selectedForSale.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SaleConfirmationDialog(
        count: _selectedForSale.length,
        total: _totalValue,
        accent: widget.accent,
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();

    final ids = _selectedForSale.map((i) => i.instanceId).toList();
    await db.creatureDao.deleteInstances(ids);
    await db.currencyDao.addSilver(_totalValue);

    setState(() {
      _selectedForSale.clear();
      _totalValue = 0;
    });

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Sold ${ids.length} specimen(s) for $_totalValue silver',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// Supporting Widgets

class _CurrencyPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int amount;

  const _CurrencyPill({
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          _format(amount),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _CompactCreatureRow extends StatelessWidget {
  final CreatureInstance instance;
  final Creature? species;
  final int price;
  final VoidCallback onRemove;

  const _CompactCreatureRow({
    required this.instance,
    required this.species,
    required this.price,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple.withOpacity(0.4)),
              ),
              child: Center(
                child: Text(
                  species?.name.substring(0, 1).toUpperCase() ?? '?',
                  style: const TextStyle(
                    color: Color(0xFFD8BFD8),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    species?.name ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Lv ${instance.level}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Price
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.monetization_on_rounded,
                  size: 14,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 4),
                Text(
                  '$price',
                  style: TextStyle(
                    color: Colors.grey.shade300,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 8),

            // Remove button
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactResourceRow extends StatelessWidget {
  final ElementResource resource; // ElementResource from constants
  final int quantity;
  final int available;
  final int price;
  final Function(int) onQuantityChanged;
  final VoidCallback onRemove;

  const _CompactResourceRow({
    required this.resource,
    required this.quantity,
    required this.available,
    required this.price,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Resource icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: resource.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: resource.color.withOpacity(0.4)),
                  ),
                  child: Center(
                    child: Icon(resource.icon, color: resource.color, size: 16),
                  ),
                ),
                const SizedBox(width: 10),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        resource.biomeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Available: $available',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Price
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 14,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$price',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 8),

                // Remove button
                GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.red),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Quantity slider
            Row(
              children: [
                Text(
                  'Qty: $quantity',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: quantity.toDouble(),
                    min: 1,
                    max: available.toDouble(),
                    divisions: available > 1 ? available - 1 : 1,
                    activeColor: resource.color,
                    inactiveColor: resource.color.withOpacity(0.3),
                    onChanged: (value) => onQuantityChanged(value.toInt()),
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

class _SaleConfirmationDialog extends StatelessWidget {
  final int count;
  final int total;
  final Color accent;

  const _SaleConfirmationDialog({
    required this.count,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'CONFIRM SALE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sell $count specimen(s) for $total silver?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

class _ResourceSaleConfirmationDialog extends StatelessWidget {
  final int resourceCount;
  final int totalQuantity;
  final int total;
  final Color accent;

  const _ResourceSaleConfirmationDialog({
    required this.resourceCount,
    required this.totalQuantity,
    required this.total,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'CONFIRM SALE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sell $totalQuantity resources ($resourceCount types) for $total silver?',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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

// Tab button widget
class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8B4789).withOpacity(0.4)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8B4789).withOpacity(0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFFD8BFD8) : Colors.white60,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFD8BFD8) : Colors.white60,
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

// Sub-tab button widget (smaller version for Alchemons/Resources)
class _SubTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8B4789).withOpacity(0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: isActive
                ? const Color(0xFF8B4789).withOpacity(0.5)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? const Color(0xFFD8BFD8) : Colors.white54,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? const Color(0xFFD8BFD8) : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Offer card widget
class _OfferCard extends StatelessWidget {
  final DailyOffer offer;
  final bool isPurchased;
  final VoidCallback onPurchase;

  const _OfferCard({
    required this.offer,
    required this.isPurchased,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPurchased
              ? Colors.black.withOpacity(0.6)
              : Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPurchased
                ? Colors.grey.withOpacity(0.3)
                : const Color(0xFF8B4789).withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isPurchased
                        ? Colors.grey.withOpacity(0.2)
                        : const Color(0xFF8B4789).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPurchased
                          ? Colors.grey.withOpacity(0.4)
                          : const Color(0xFF8B4789).withOpacity(0.5),
                    ),
                  ),
                  child: Icon(
                    offer.icon,
                    size: 28,
                    color: isPurchased
                        ? Colors.grey.shade400
                        : const Color(0xFFD8BFD8),
                  ),
                ),

                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              offer.name,
                              style: TextStyle(
                                color: isPurchased
                                    ? Colors.grey.shade400
                                    : const Color(0xFFE8EAED),
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          if (isPurchased)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.check_rounded,
                                    size: 12,
                                    color: Colors.greenAccent,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'PURCHASED',
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        offer.description,
                        style: TextStyle(
                          color: isPurchased
                              ? Colors.grey.shade500
                              : Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cost and button
            Row(
              children: [
                // Cost
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: offer.cost.entries.map((entry) {
                      return _CostBadge(
                        currencyType: entry.key,
                        amount: entry.value,
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(width: 12),

                // Buy button
                if (!isPurchased)
                  GestureDetector(
                    onTap: onPurchase,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade600,
                            Colors.green.shade800,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.shade400,
                          width: 1.5,
                        ),
                      ),
                      child: const Text(
                        'BUY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
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

class _CostBadge extends StatelessWidget {
  final String currencyType;
  final int amount;

  const _CostBadge({required this.currencyType, required this.amount});

  @override
  Widget build(BuildContext context) {
    final isGold = currencyType == 'gold';
    final color = isGold ? const Color(0xFFFFD700) : const Color(0xFFC0C0C0);
    final icon = isGold ? Icons.diamond_rounded : Icons.monetization_on_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$amount',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseConfirmationDialog extends StatelessWidget {
  final DailyOffer offer;
  final Color accent;

  const _PurchaseConfirmationDialog({
    required this.offer,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withOpacity(0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(offer.icon, color: accent, size: 48),
            const SizedBox(height: 16),
            const Text(
              'CONFIRM PURCHASE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              offer.name,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              offer.description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Cost display
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: offer.cost.entries.map((entry) {
                return _CostBadge(currencyType: entry.key, amount: entry.value);
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Purchase',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
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
