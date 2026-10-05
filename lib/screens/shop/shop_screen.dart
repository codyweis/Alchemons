// lib/screens/shop_screen.dart
//
// REDESIGNED SHOP SCREEN
// Aesthetic: Scorched Forge — dark metal chrome, amber reagent accents, monospace
// GameShopCard and grid layouts are preserved exactly.
// Transparent card style on daily vial banner is preserved.
// All logic, routing, purchase flows, and service calls unchanged.
//

import 'package:alchemons/models/home_decor.dart';
import 'package:alchemons/models/faction.dart';
import 'dart:async';

import 'package:alchemons/audio/audio.dart';

import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/screens/black_market_screen.dart';
import 'package:alchemons/screens/profile_screen.dart';
import 'package:alchemons/screens/shop/alchemon_exchange_screen.dart';
import 'package:alchemons/screens/shop/gold_vault.dart';
import 'package:alchemons/screens/shop/shop_widgets.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/black_market_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/mobile_store_service.dart';
import 'package:alchemons/models/inventory.dart' show InvKeys;
import 'package:alchemons/widgets/alchemical_powerup_orb_sphere.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart'
    show routeObserver;
import 'package:alchemons/widgets/background/particle_background_scaffold.dart';
import 'package:alchemons/widgets/black_market_button.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/wallet_panel.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/perf/viewport_ticker_gate.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/services/debug_settings_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN
// ──────────────────────────────────────────────────────────────────────────────

/// The shop, always in oceanic colours.
///
/// It used to wear the player's faction, so the same screen looked like four
/// different screens depending on allegiance — and the shop is a shop
/// whoever walks into it. The override lives here rather than at the place
/// the shop is opened from, so a second entry point cannot arrive without it.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const ForcedFaction(faction: FactionId.oceanic, child: _ShopScreenBody());
}

class _ShopScreenBody extends StatefulWidget {
  const _ShopScreenBody();

  @override
  State<_ShopScreenBody> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<_ShopScreenBody> with RouteAware {
  ForgeTokens get t => ForgeTokens(context.read<FactionTheme>());

  int _slotsUnlocked = 1;

  /// Cosmic space found. Raids only exist out there, so the beacon that
  /// summons one is meaningless — and a spoiler — before then.
  bool _cosmicDiscovered = false;
  bool _showPurchased = false;

  /// False while something is pushed over the shop (the item-detail dialog,
  /// the black market, the exchange). Everything animated in the shop body is
  /// under a TickerMode keyed on this, so nothing keeps driving frames behind
  /// a route the player is actually looking at.
  bool _routeIsCurrent = true;

  /// 0 = supplies, 1 = cosmetics.
  int _tab = 0;

  /// Cosmetics is built the first time it is opened and kept after, so a
  /// player who never looks at it never bakes its effect cards.
  bool _cosmeticsBuilt = false;

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

    () async {
      final found =
          await context.read<AlchemonsDatabase>().settingsDao.getSetting(
            'cosmic_ship_unlocked',
          ) ==
          '1';
      if (mounted && found != _cosmicDiscovered) {
        setState(() => _cosmicDiscovered = found);
      }
    }();

    _refreshAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) routeObserver.subscribe(this, route);
    _syncRouteIsCurrent();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _syncRouteIsCurrent() {
    final isCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    if (!mounted || _routeIsCurrent == isCurrent) return;
    setState(() => _routeIsCurrent = isCurrent);
  }

  @override
  void didPush() => _syncRouteIsCurrent();

  @override
  void didPopNext() => _syncRouteIsCurrent();

  @override
  void didPushNext() => _syncRouteIsCurrent();

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
      _toast(
        'Not enough resources',
        icon: AppIcons.lock_rounded,
        color: t.amber,
      );
      return;
    }

    await db.settingsDao.setBlobSlotsUnlocked(target);
    await _refreshAll();
    if (!mounted) return;
    context.sound(SoundCue.purchaseSuccess, owner: this);
    _toast(
      'Bubble slot $target unlocked!',
      icon: AppIcons.bubble_chart_rounded,
      color: t.teal,
    );
    HapticFeedback.lightImpact();
  }

  void _toast(
    String msg, {
    IconData icon = AppIcons.check_rounded,
    Color? color,
  }) {
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
                  fontSize: 12,
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
              // The header animates continuously (the black-market pulse).
              // Without its own layer every one of those frames re-records the
              // whole screen, scroll content included.
              RepaintBoundary(child: _buildHeader(theme)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: BracketTabs(
                  labels: const ['SUPPLIES', 'COSMETICS'],
                  icons: const [AppIcons.science, AppIcons.auto_awesome],
                  selected: _tab,
                  onSelect: (i) => setState(() {
                    _tab = i;
                    if (i == 1) _cosmeticsBuilt = true;
                  }),
                  palette: BracketPalette.fromTheme(theme),
                  accent: bracketReadableAccent(theme),
                ),
              ),
              Expanded(
                child: TickerMode(
                  enabled: _routeIsCurrent,
                  child: _buildShopContent(theme, db),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  /// One row: the black market's stall, the name, what the player holds and
  /// the door to the specimen exchange. The five element resources are only
  /// spent on supplies, so they sit at the top of that tab rather than here.
  Widget _buildHeader(FactionTheme theme) {
    final palette = BracketPalette.fromTheme(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 0),
      child: Row(
        children: [
          _buildBlackMarketFloatingButton(context, theme.accent),
          const SizedBox(width: 4),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Research Shop',
                maxLines: 1,
                style: bracketText(context, 24, palette.ink),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // The door stands as tall as the purse beside it.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CurrencyDisplayWidget(),
                const SizedBox(width: 8),
                _buildExchangeFloatingButton(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SECTION HEADER ─────────────────────────────────────────────────────────

  /// Every section header, in one colour.
  ///
  /// They each used to carry their own accent — amber here, the gold vault's
  /// yellow there, the powerups' violet below — which read as ten unrelated
  /// headings rather than one list. There is no colour argument any more, so
  /// a new section cannot reintroduce a tenth hue.
  ///
  /// Gold in the dark, black in the light: the dark palette is the one this
  /// screen was designed against, and on the light ground gold has nothing
  /// to hold against.
  Widget _buildSectionHeader(String title, {CoinKind? coin}) {
    final displayAccent = context.read<FactionTheme>().isDark
        ? t.amberBright
        : Colors.black;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 0),
      child: Row(
        children: [
          // Accent bar
          Container(
            width: 3,
            height: 16,
            color: displayAccent,
            margin: const EdgeInsets.only(right: 10),
          ),
          if (coin != null) ...[
            CoinIcon(kind: coin, size: 15),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: TextStyle(
              fontFamily: 'monospace',
              color: displayAccent,
              fontSize: 12,
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

        return GestureDetector(
          onTap: context.soundAction(() {
            if (canPurchase) {
              _handlePurchase(context, offer, allCurrencies, canAfford);
            } else {
              _showDetails(context, offer, allCurrencies, canAfford);
            }
          }),
          child: GameShopCard(
            key: ValueKey('vial-${offer.id}'),
            title: '${group.displayName} Vial',
            offer: offer,
            theme: theme,
            costWidgets: costWidgets,
            enabled: !isPurchased,
            canAfford: canAfford,
            preview: Center(
              child: ExtractionVialOrb(vial: vialModel, size: 70),
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

                // Each tab keeps its own scroll position, and only the one
                // on screen runs its animations.
                return IndexedStack(
                  index: _tab,
                  sizing: StackFit.expand,
                  children: [
                    TickerMode(
                      enabled: _tab == 0,
                      child: _buildSuppliesTab(
                        theme,
                        allCurrencies,
                        resourceBalances,
                        inventoryByKey,
                      ),
                    ),
                    TickerMode(
                      enabled: _tab == 1,
                      child: _cosmeticsBuilt
                          ? _buildCosmeticsTab(
                              theme,
                              allCurrencies,
                              inventoryByKey,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Everything that does something: unlocks, consumables, devices, gold,
  /// keys and the element exchange. The element resources sit pinned above
  /// it, since harvesters and the exchange are priced in them.
  Widget _buildSuppliesTab(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> resourceBalances,
    Map<String, int> inventoryByKey,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: WalletPanel(showCoins: false),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('SPECIAL UNLOCKS'),
                _buildSpecialUnlocksGrid(
                  theme,
                  allCurrencies,
                  resourceBalances,
                ),

                _buildSectionHeader('COMMON ITEMS'),
                // The vial is a routine restock like the other two, so
                // it shares their grid — same cell, same size — instead
                // of a full-width card above them. Its live brewing
                // particle field keeps its own layer, paused once it
                // scrolls out of the viewport.
                _buildInstantItemsGrid(
                  theme,
                  allCurrencies,
                  inventoryByKey,
                  _commonConsumableIds,
                  leading: [
                    ViewportTickerGate(
                      child: _buildDailyVialSection(theme, allCurrencies),
                    ),
                  ],
                ),

                _buildSectionHeader('GOLD VAULT', coin: CoinKind.gold),
                // One grain field on one ticker; its own layer, and
                // paused once it scrolls out of the viewport.
                ViewportTickerGate(child: _buildGoldVaultSection(theme)),

                _buildSectionHeader('HARVEST DEVICES'),
                _buildHarvestDevicesGrid(
                  theme,
                  allCurrencies,
                  inventoryByKey,
                  resourceBalances,
                ),

                // Power Orbs raise Enhancement ranks, so they are
                // stock for a screen the player cannot open yet. Hidden
                // until Enhance is unlocked, the way Enhance itself is
                // hidden on the home dock.
                if (context
                    .watch<ShopService>()
                    .hasElementalCreatorUnlocked()) ...[
                  _buildSectionHeader('ALCHEMICAL POWERUPS'),
                  // Five floating/pulsing orbs, each with a blurred
                  // glow; own layer, paused once out of the viewport.
                  ViewportTickerGate(
                    child: _buildAlchemicalPowerupsRow(
                      theme,
                      allCurrencies,
                      inventoryByKey,
                    ),
                  ),
                ],

                _buildSectionHeader('SPECIAL ITEMS'),
                _buildInstantItemsGrid(
                  theme,
                  allCurrencies,
                  inventoryByKey,
                  _specialConsumableIds,
                ),

                _buildSectionHeader('SELL'),
                _buildCurrencyExchangeGrid(
                  theme,
                  allCurrencies,
                  resourceBalances,
                ),

                _buildSectionHeader('PORTAL KEYS'),
                _buildPortalKeysGrid(theme, allCurrencies, inventoryByKey),

                // 'SURVIVAL ORB SKINS' removed — an orb skin is
                // chosen where it is worn. Base Command sells and
                // equips them side by side, so buying one here meant a
                // trip to a second screen to put it on, and the two
                // lists could disagree about what you owned. The
                // offers still exist: Base Command reads them for
                // pricing and for the once-only limit.

                // 'COSMIC EXPLORATION' removed — discovery will occur in-world
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Things that only change how something looks. Alchemy effects for now;
  /// home planet customisations join them here.
  Widget _buildCosmeticsTab(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventoryByKey,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('ALCHEMY EFFECTS'),
          _buildAlchemyEffectsGrid(theme, allCurrencies, inventoryByKey),
          // The home biome's decor, simple to grand (models/home_decor.dart).
          for (final tier in DecorTier.values) ...[
            _buildSectionHeader('HOME · ${tier.label}'),
            _buildHomeDecorGrid(theme, allCurrencies, tier),
          ],
        ],
      ),
    );
  }

  // ── GRIDS (logic unchanged, padding/spacing preserved) ─────────────────────

  /// The home decor of [tier]: a card each, how many owned of the most one
  /// realm can stand.
  Widget _buildHomeDecorGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    DecorTier tier,
  ) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final cards = [
          for (final offer in shopService.getHomeDecorOffers(tier))
            () {
              final canPurchase = shopService.canPurchase(offer.id);
              final effectiveCost = shopService.getEffectiveCost(offer);
              final canAffordUnit = effectiveCost.entries.every(
                (e) => (allCurrencies[e.key] ?? 0) >= e.value,
              );
              final status = shopService.getPurchaseStatus(offer.id);
              return GestureDetector(
                onTap: context.soundAction(
                  () => canPurchase
                      ? _handlePurchase(
                          context,
                          offer,
                          allCurrencies,
                          canAffordUnit,
                        )
                      : _showDetails(
                          context,
                          offer,
                          allCurrencies,
                          canAffordUnit,
                        ),
                ),
                child: GameShopCard(
                  key: ValueKey('decor-${offer.id}'),
                  title: offer.name,
                  offer: offer,
                  theme: theme,
                  costWidgets: [
                    for (final entry in effectiveCost.entries)
                      CostChip(
                        currencyType: entry.key,
                        amount: entry.value,
                        available: allCurrencies[entry.key] ?? 0,
                      ),
                  ],
                  statusText: status.isEmpty ? null : status,
                  enabled: canPurchase,
                  canAfford: canAffordUnit,
                ),
              );
            }(),
        ];
        return Padding(
          padding: const EdgeInsets.all(12),
          child: ShopGrid(children: cards),
        );
      },
    );
  }

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
              icon: AppIcons.auto_awesome_outlined,
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      allCurrencies,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, allCurrencies, canAffordUnit),
            ),
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
          child: ShopGrid(children: cards),
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
            icon: started
                ? AppIcons.shopping_bag_rounded
                : AppIcons.error_rounded,
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
                fontSize: 12,
                height: 1.5,
                letterSpacing: 0.2,
              ),
            ),
          );
        }

        final offers = [
          for (final pack in packs)
            GoldVaultOffer(
              pack: pack,
              price: store.productFor(pack.productId)?.price,
              rawPrice: store.productFor(pack.productId)?.rawPrice,
              pending: store.isPurchasePending(pack.productId),
            ),
        ];
        if (offers.isEmpty) {
          return const EmptySection(
            message: 'No gold packs available',
            icon: AppIcons.account_balance_wallet_outlined,
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: GoldVaultDeck(
            offers: offers,
            needsAccount: store.requiresSignIn,
            loading: store.isLoading,
            awaitingVerification: store.pendingRedeemCount,
            error: store.lastError,
            onBuy: buyPack,
            // Gold is credited to an account, so the button leads to
            // signing in rather than to a dead end.
            onSignIn: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (ctx) => ProfileScreen(() => Navigator.of(ctx).pop()),
              ),
            ),
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      mergedBalances,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, mergedBalances, canAffordUnit),
            ),
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
          child: ShopGrid(children: cards),
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      allCurrencies,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, allCurrencies, canAffordUnit),
            ),
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
          final cost = DebugSettingsService.priced(
            _bubbleSlotCostFor(slotNumber),
          );
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
            icon: AppIcons.bubble_chart_rounded,
            cost: cost,
            inventoryKey: null,
            assetName: null,
          );
          cards.add(
            GestureDetector(
              onTap: context.soundAction(
                () => enabled
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

        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No exploration items available',
              icon: AppIcons.rocket_launch_outlined,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: ShopGrid(children: cards),
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
              icon: AppIcons.vpn_key_outlined,
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      allCurrencies,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, allCurrencies, canAffordUnit),
            ),
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
          child: ShopGrid(children: cards),
        );
      },
    );
  }

  /// Everyday consumables. Kept above the rarer ones because these are the
  /// two a player restocks routinely.
  static const _commonConsumableIds = <String>[
    'boost.instant_stamina_potion',
    'boost.wildlife_lure',
    ShopService.wildFusionOfferId,
  ];

  /// Situational consumables: one skips a fusion timer, one summons a raid.
  List<String> get _specialConsumableIds => <String>[
    'boost.instant_hatch',
    ShopService.halfCultivationOfferId,
    if (_cosmicDiscovered) 'boost.instant_boss_refresh',
  ];

  Widget _buildInstantItemsGrid(
    FactionTheme theme,
    Map<String, int> allCurrencies,
    Map<String, int> inventory,
    List<String> ids, {
    List<Widget> leading = const [],
  }) {
    return Consumer<ShopService>(
      builder: (context, shopService, _) {
        final instantOffers = [
          for (final id in ids)
            ...ShopService.allOffers.where((o) => o.id == id),
        ];

        if (instantOffers.isEmpty && leading.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'No consumables available',
              icon: AppIcons.flash_off_rounded,
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      allCurrencies,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, allCurrencies, canAffordUnit),
            ),
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
          child: ShopGrid(children: [...leading, ...cards]),
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
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      mergedBalances,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, mergedBalances, canAffordUnit),
            ),
            child: GameShopCard(
              key: ValueKey('fx-${offer.id}'),
              title: offer.name,
              displayLabel: _exchangeLabel(offer.name),
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
          child: ShopGrid(children: cards),
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

        if (specialOffers.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: EmptySection(
              message: 'All special items unlocked',
              icon: AppIcons.check_circle_outline_rounded,
            ),
          );
        }

        final cards = specialOffers.map((offer) {
          final canPurchase = shopService.canPurchase(offer.id);
          final effectiveCost = shopService.getEffectiveCost(offer);
          final canAffordUnit = effectiveCost.entries.every(
            (e) => (mergedBalances[e.key] ?? 0) >= e.value,
          );
          final costWidgets = <Widget>[
            for (final entry in effectiveCost.entries)
              CostChip(
                currencyType: entry.key,
                amount: entry.value,
                available: mergedBalances[entry.key] ?? 0,
              ),
          ];
          return GestureDetector(
            onTap: context.soundAction(
              () => canPurchase
                  ? _handlePurchase(
                      context,
                      offer,
                      mergedBalances,
                      canAffordUnit,
                    )
                  : _showDetails(context, offer, mergedBalances, canAffordUnit),
            ),
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
          child: ShopGrid(children: cards),
        );
      },
    );
  }

  /// 'Volcanic → Gold (1g)' as the card says it: what you get, "1 Gold".
  /// The card's display face has no arrow glyph, and the price strip and the
  /// picture already say what is paid.
  static String? _exchangeLabel(String name) {
    final m = RegExp(r'→\s*(\w+)\s*\(([\d,]+)\s*[a-z]*\)').firstMatch(name);
    if (m == null) return null;
    return '${m.group(2)} ${m.group(1)}';
  }

  String? _specialUnlockLabel(ShopOffer offer) {
    if (offer.id.startsWith('unlock.storage_cap.')) return 'Cold Storage';
    if (offer.id.startsWith('unlock.fusion_slot.')) return 'Fusion Chamber';
    if (offer.id == 'boost.faction_change') return 'Change Faction';
    return null;
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
      effectiveCost: shopService.getEffectiveCost(offer),
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
    context.sound(success ? SoundCue.purchaseSuccess : SoundCue.uiDenied);

    // Result snackbar. An alchemy effect goes to the inventory, to be put on
    // a specimen from there whenever the player likes.
    final isEffect = offer.id.startsWith('effects.');
    final isDecor = HomeDecor.byOffer(offer.id) != null;
    _toast(
      !success
          ? 'Purchase failed'
          : isEffect
          ? '${offer.name} added to inventory'
          : isDecor
          ? '${offer.name} ready to place at home'
          : '${offer.name} × $qty',
      icon: success ? AppIcons.check_rounded : AppIcons.error_rounded,
      color: success ? t.success : t.danger,
    );

    if (success && offer.id == 'boost.faction_change') {
      HapticFeedback.mediumImpact();
      _toast(
        'Opening faction selector...',
        icon: AppIcons.flag_rounded,
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
            children: [
              ...AlchemicalPowerupType.values.map((type) {
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
              }),
              Builder(
                builder: (context) {
                  final offer = ShopService.allOffers.firstWhere(
                    (o) => o.id == ShopService.potentialSoulOfferId,
                  );
                  final effectiveCost = shopService.getEffectiveCost(offer);
                  final canAfford = effectiveCost.entries.every(
                    (e) => (allCurrencies[e.key] ?? 0) >= e.value,
                  );
                  final canPurchase = shopService.canPurchase(offer.id);
                  return _ShopSoulOrb(
                    qty: inventory[InvKeys.potentialSoul] ?? 0,
                    canAfford: canAfford,
                    cost: effectiveCost,
                    theme: theme,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (canPurchase) {
                        _handlePurchase(
                          context,
                          offer,
                          allCurrencies,
                          canAfford,
                        );
                      } else {
                        _showDetails(context, offer, allCurrencies, canAfford);
                      }
                    },
                  );
                },
              ),
            ],
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
        size: 54,
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
        return _ShopDoor(
          icon: unlocked ? AppIcons.sell_rounded : AppIcons.lock_rounded,
          label: 'SELL',
          accent: t.readableAccent(t.amberBright),
          lit: unlocked,
          onTap: () {
            if (!unlocked) {
              _toast(
                'Explore the constellations to unlock.',
                icon: AppIcons.lock_rounded,
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
                  AppIcons.storefront_rounded,
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
                  fontSize: 12,
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
                  onTap: context.soundAction(() => Navigator.pop(ctx)),
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
                          fontSize: 12,
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

/// Sits beside the Power Orbs on the shop shelf: same footprint, but the
/// molecular soul artwork and a Silver-cost caveat, since infusing one costs
/// again on top of the purchase.
class _ShopSoulOrb extends StatelessWidget {
  final int qty;
  final bool canAfford;
  final Map<String, int> cost;
  final FactionTheme theme;
  final VoidCallback onTap;

  const _ShopSoulOrb({
    required this.qty,
    required this.canAfford,
    required this.cost,
    required this.theme,
    required this.onTap,
  });

  static const Color _soul = Color(0xFFCF9BFF);

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final goldCost = cost['gold'] ?? 0;
    return GestureDetector(
      onTap: context.soundAction(onTap),
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: canAfford ? 1.0 : 0.55,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PotentialSoulSphere(size: 62, animate: true),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: qty > 0 ? _soul.withValues(alpha: 0.14) : t.bg3,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: qty > 0 ? _soul.withValues(alpha: 0.45) : t.borderDim,
                ),
              ),
              child: Text(
                'x$qty',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: qty > 0 ? _soul : t.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'POTENTIAL SOUL',
              softWrap: true,
              style: TextStyle(
                fontFamily: 'monospace',
                color: _soul,
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
              'GENETICS',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CoinIcon(kind: CoinKind.gold, size: 12),
                const SizedBox(width: 3),
                Text(
                  '$goldCost',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: canAfford ? const Color(0xFFFFD700) : t.textMuted,
                    fontSize: 12,
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
      onTap: context.soundAction(widget.onTap),
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
                  fontSize: 12,
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
                const CoinIcon(kind: CoinKind.gold, size: 12),
                const SizedBox(width: 3),
                Text(
                  '$goldCost',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: widget.canAfford
                        ? const Color(0xFFFFD700)
                        : t.textMuted,
                    fontSize: 12,
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

/// The way out of the shop to the specimen exchange: a small bracketed door,
/// lit in its accent while it can be walked through, quiet in the line
/// colour while it is shut.
class _ShopDoor extends StatelessWidget {
  const _ShopDoor({
    required this.icon,
    required this.label,
    required this.accent,
    required this.lit,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    final ink = lit ? accent : palette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: (lit ? accent : palette.line).withValues(alpha: 0.9),
          bracketSize: 7,
          strokeWidth: lit ? 1.2 : 1,
        ),
        child: Container(
          width: 56,
          constraints: const BoxConstraints(minHeight: 48),
          color: lit
              ? palette.accentWash(accent, darkAlpha: 0.16)
              : palette.surfaceMutedFill(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: ink),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: ink,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
