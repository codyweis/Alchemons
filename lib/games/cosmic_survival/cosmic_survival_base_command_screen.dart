import 'package:alchemons/audio/audio.dart';
// lib/games/cosmic_survival/cosmic_survival_base_command_screen.dart
//
// Base Command — persistent cosmic survival upgrade screen.
// Sections: Orb Skins, Ship, Guardian Power-ups, Base Abilities.
// The legacy standalone survival runtime has been removed; this shared upgrade
// panel remains for cosmic survival progression.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_game.dart' show ShipComponent;
import 'package:alchemons/games/cosmic/ship_art.dart' show shipLight;
import 'package:alchemons/games/cosmic_survival/orb_art.dart' show paintOrbCore;
import 'package:alchemons/games/cosmic_survival/components/family_mastery_panel.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_ship_loadout.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

/// The kit's dark palette: the back button, purse, tabs and confirm dialogs
/// come from bracket_controls and read their greys from here.
const _kPalette = BracketPalette.dark;

/// The space between two tabs. Narrower than [BracketTabs]' 8 so four (or
/// five) labels still fit across a phone.
const double _kTabGap = 6;

class _C {
  static const bg0 = Color(0xFF09090B);
  static const bg1 = Color(0xFF131316);
  static const bg2 = Color(0xFF17171A);
  static const bg3 = Color(0xFF1D1D21);
  static const amber = Color(0xFFB89656);
  static const amberBright = Color(0xFFCDB07A);
  static const textPrimary = Color(0xFFE6E2DA);
  static const textSecondary = Color(0xFF85827C);
  static const textMuted = Color(0xFF46454A);
  static const danger = Color(0xFFC0392B);
  static const borderDim = Color(0xFF26262B);
  static const borderMid = Color(0xFF33333A);
}

class _T {
  static const TextStyle heading = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );
  static const TextStyle label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
  static const TextStyle body = TextStyle(
    color: _C.textSecondary,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
}

String _fmtNum(int n) {
  if (n < 1000) return '$n';
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalBaseCommandScreen extends StatefulWidget {
  const CosmicSurvivalBaseCommandScreen({
    super.key,
    this.hideAbilities = false,
    this.initialMasteryFamily,
  });

  /// When true, the Base Abilities tab is hidden (used in cosmic survival).
  final bool hideAbilities;

  /// The family whose mastery tree the Mastery tab opens on.
  final CreatureFamily? initialMasteryFamily;

  @override
  State<CosmicSurvivalBaseCommandScreen> createState() =>
      _CosmicSurvivalBaseCommandScreenState();
}

class _CosmicSurvivalBaseCommandScreenState
    extends State<CosmicSurvivalBaseCommandScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _silverBalance = 0;
  int _goldBalance = 0;
  Map<String, int> _currencies = {};
  bool _purchasing = false;
  SurvivalShipLoadout? _shipLoadout;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.hideAbilities ? 4 : 5,
      vsync: this,
      // Default is 300ms; tapping a tab should land before the finger lifts.
      animationDuration: const Duration(milliseconds: 180),
    );
    _loadCurrencies();
    _loadShipLoadout();
  }

  Future<void> _loadShipLoadout() async {
    final loadout = await SurvivalShipLoadout.load();
    if (!mounted) return;
    setState(() => _shipLoadout = loadout);
  }

  Future<void> _loadCurrencies() async {
    final db = context.read<AlchemonsDatabase>();
    final currencies = await db.currencyDao.getAllCurrencies();
    if (!mounted) return;
    setState(() {
      _currencies = currencies;
      _silverBalance = currencies['silver'] ?? 0;
      _goldBalance = currencies['gold'] ?? 0;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SurvivalUpgradeService, ShopService>(
      builder: (context, svc, shopService, _) {
        return Scaffold(
          backgroundColor: _C.bg0,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabBar(),
                Expanded(
                  // Nothing on this screen bounces.
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(physics: const ClampingScrollPhysics()),
                    child: TabBarView(
                      controller: _tabController,
                      physics: const _SnappyPagePhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      children: [
                        // Bought with each family's own mastery points,
                        // which the panel reads itself — not the purse.
                        FamilyMasteryPanel(
                          initialFamily: widget.initialMasteryFamily,
                        ),
                        _buildOrbSkinsTab(svc, shopService),
                        _buildShipTab(),
                        _buildGuardianTab(svc),
                        if (!widget.hideAbilities) _buildAbilitiesTab(svc),
                      ],
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

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back_rounded,
            palette: _kPalette,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, bottom: 1),
                      decoration: const BoxDecoration(
                        color: _C.amberBright,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Flexible(
                      child: Text(
                        'BASE COMMAND',
                        style: _T.heading,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'UPGRADE & CUSTOMIZE',
                  style: _T.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Both coins, because this screen spends both: orb skins are
          // priced in gold, everything else but mastery in silver (mastery
          // spends each family's own points, shown on its tab).
          CoinPurse(
            gold: _goldBalance,
            silver: _silverBalance,
            palette: _kPalette,
            fill: _C.bg1,
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────────

  /// The kit's tabs ([BracketTabs]): a row of quiet fills, the chosen one
  /// washed in brass and lit from below. Built on a Material [TabBar] so the
  /// light follows the pager as it is swiped, and the tabs keep their
  /// semantics; the TabBar itself draws only the labels and the light.
  Widget _buildTabBar() {
    const labels = ['MASTERY', 'ORB', 'SHIP', 'GUARDIANS', 'ABILITIES'];
    final count = widget.hideAbilities ? 4 : 5;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16 - _kTabGap / 2,
        8,
        16 - _kTabGap / 2,
        10,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Monospace (a glyph is ~0.6em): the longest label sets the size,
          // so it fits its cell on a narrow phone rather than fading out at
          // the edge. The spacing gives way before the type gets small.
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final room = constraints.maxWidth / count - _kTabGap - 6;
          final longest = labels
              .take(count)
              .fold<int>(0, (m, l) => l.length > m ? l.length : m);
          final perGlyph = room / longest;
          final fontSize = (perGlyph / (0.72 * textScale)).clamp(9.0, 12.0);
          final letterSpacing = (perGlyph - 0.6 * fontSize * textScale).clamp(
            0.3,
            fontSize * 0.12,
          );
          final style = TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            letterSpacing: letterSpacing,
          );
          return Stack(
            children: [
              // Every tab's quiet fill, cell for cell under the TabBar.
              Positioned.fill(
                child: Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _kTabGap / 2,
                          ),
                          child: ColoredBox(
                            color: _kPalette.surfaceMutedFill(),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicator: const _LitTabIndicator(accent: _C.amber),
                indicatorSize: TabBarIndicatorSize.tab,
                indicatorWeight: 0,
                indicatorAnimation: TabIndicatorAnimation.linear,
                dividerHeight: 0,
                dividerColor: Colors.transparent,
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                labelPadding: const EdgeInsets.symmetric(
                  horizontal: _kTabGap / 2 + 2,
                ),
                labelColor: _kPalette.ink,
                unselectedLabelColor: _kPalette.muted,
                labelStyle: style,
                unselectedLabelStyle: style,
                tabs: [
                  for (var i = 0; i < count; i++)
                    Tab(text: labels[i], height: 40),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Orb Skins Tab ────────────────────────────────────────────────────────

  Widget _buildOrbSkinsTab(
    SurvivalUpgradeService svc,
    ShopService shopService,
  ) {
    final state = svc.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EtchedDivider(label: 'ORB BASE SKINS'),
          const SizedBox(height: 12),
          Text(
            'Select the orb you carry into battle. Each orb has a unique visual style.',
            style: _T.body,
          ),
          const SizedBox(height: 16),
          ...kOrbBases.map((orbDef) {
            final offer = _orbOfferForDef(orbDef);
            final effectiveCost = _orbEffectiveCost(shopService, orbDef);
            final canAfford = _canAfford(effectiveCost);
            final canPurchase = offer == null
                ? true
                : shopService.canPurchase(offer.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _OrbSkinCard(
                def: orbDef,
                isOwned: state.ownedSkins.contains(orbDef.skin),
                isEquipped: state.equippedSkin == orbDef.skin,
                costLabel: _compactCostLabel(effectiveCost),
                costCoin: _coinForCost(effectiveCost),
                canPurchase: canAfford && canPurchase,
                purchasing: _purchasing,
                onPurchase: () => _purchaseOrb(svc, shopService, orbDef.skin),
                onEquip: () => _equipOrb(svc, orbDef.skin),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Ship Tab ─────────────────────────────────────────────────────────────

  Widget _buildShipTab() {
    final loadout = _shipLoadout;
    if (loadout == null) return const SizedBox.shrink();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EtchedDivider(label: 'SHIP HULLS'),
          const SizedBox(height: 12),
          Text(
            'Choose the hull you fly into the arena. New designs are forged '
            'at your home planet in cosmic space.',
            style: _T.body,
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ShipHullCard(
              skinId: null,
              name: 'Standard Hull',
              description:
                  'The ship you launched with. Twin cyan engines and a '
                  'broad-winged frame.',
              isUnlocked: true,
              isEquipped: loadout.selectedSkin == null,
              onEquip: () => _selectShip(null),
            ),
          ),
          ...SurvivalShipLoadout.designs.map((recipe) {
            final unlocked = loadout.unlockedSkins.contains(recipe.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ShipHullCard(
                skinId: recipe.id,
                name: recipe.name,
                description: recipe.description,
                isUnlocked: unlocked,
                isEquipped: loadout.selectedSkin == recipe.id,
                forgeCost: unlocked
                    ? null
                    : recipe.ingredients.entries
                          .map((e) => '${e.value} ${e.key}')
                          .join(' · '),
                onEquip: () => _selectShip(recipe.id),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _selectShip(String? skinId) async {
    final loadout = _shipLoadout;
    if (loadout == null) return;
    setState(() {
      _shipLoadout = SurvivalShipLoadout(
        unlockedSkins: loadout.unlockedSkins,
        selectedSkin: skinId,
      );
    });
    await SurvivalShipLoadout.select(skinId);
  }

  ShopOffer? _orbOfferForDef(OrbBaseDef def) {
    for (final offer in ShopService.allOffers) {
      if (offer.id == def.shopId) return offer;
    }
    return null;
  }

  Map<String, int> _orbEffectiveCost(ShopService shopService, OrbBaseDef def) {
    final offer = _orbOfferForDef(def);
    // Orbs are priced in gold; the fallback has to agree with the offers
    // or a missing offer would silently change the currency.
    if (offer == null) return {'gold': def.cost};
    return shopService.getEffectiveCost(offer);
  }

  bool _canAfford(Map<String, int> cost) {
    for (final entry in cost.entries) {
      if ((_currencies[entry.key] ?? 0) < entry.value) {
        return false;
      }
    }
    return true;
  }

  String _currencySuffix(String key) {
    switch (key) {
      case 'gold':
        return 'G';
      case 'silver':
        return 'S';
      default:
        if (key.startsWith('res_')) {
          return key.replaceFirst('res_', '').toUpperCase();
        }
        return key.toUpperCase();
    }
  }

  String _currencyName(String key) {
    switch (key) {
      case 'gold':
        return 'gold';
      case 'silver':
        return 'silver';
      default:
        if (key.startsWith('res_')) {
          return '${key.replaceFirst('res_', '')} essence';
        }
        return key.replaceAll('_', ' ');
    }
  }

  /// The coin shown on a buy button, taken from the price itself. Hardcoding
  /// it is how the orb cards ended up showing silver for a gold price.
  CoinKind _coinForCost(Map<String, int> cost) {
    if (cost.containsKey('gold')) return CoinKind.gold;
    return CoinKind.silver;
  }

  /// A price drawn as coins in the confirm dialog. Only a price paid wholly
  /// in gold and silver is drawn; anything else (an essence) is left to the
  /// message, which spells the whole price out.
  List<(CoinKind, int)> _coinAmounts(Map<String, int> cost) {
    if (cost.keys.any((k) => k != 'gold' && k != 'silver')) return const [];
    return [
      for (final entry in cost.entries)
        (entry.key == 'gold' ? CoinKind.gold : CoinKind.silver, entry.value),
    ];
  }

  String _compactCostLabel(Map<String, int> cost) {
    if (cost.isEmpty) return '0';
    return cost.entries
        .map((entry) => '${_fmtNum(entry.value)}${_currencySuffix(entry.key)}')
        .join('+');
  }

  String _fullCostLabel(Map<String, int> cost) {
    if (cost.isEmpty) return '0';
    return cost.entries
        .map((entry) => '${_fmtNum(entry.value)} ${_currencyName(entry.key)}')
        .join(' + ');
  }

  Future<void> _purchaseOrb(
    SurvivalUpgradeService svc,
    ShopService shopService,
    OrbBaseSkin skin,
  ) async {
    if (_purchasing) return;

    final def = getOrbBaseDef(skin);
    final offer = _orbOfferForDef(def);
    final effectiveCost = _orbEffectiveCost(shopService, def);
    final confirmed = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: def.primaryColor,
      title: 'CONFIRM PURCHASE',
      message: 'Spend ${_fullCostLabel(effectiveCost)} on ${def.name}?',
      amounts: _coinAmounts(effectiveCost),
      amountsLabel: 'COSTS',
      confirmLabel: 'BUY',
    );
    if (!confirmed || !mounted) return;

    setState(() => _purchasing = true);
    final ok = offer == null
        ? await svc.purchaseOrbSkin(skin)
        : await shopService.purchase(offer.id);

    if (ok) {
      if (offer != null) {
        await svc.load();
      }
      await _loadCurrencies();
    }
    if (mounted) {
      setState(() => _purchasing = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot complete purchase.'),
            backgroundColor: _C.danger,
          ),
        );
      }
    }
  }

  Future<void> _equipOrb(SurvivalUpgradeService svc, OrbBaseSkin skin) async {
    await svc.equipOrbSkin(skin);
  }

  // ── Guardian Upgrades Tab ────────────────────────────────────────────────

  Widget _buildGuardianTab(SurvivalUpgradeService svc) {
    final state = svc.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EtchedDivider(label: 'GUARDIAN POWER-UPS'),
          const SizedBox(height: 12),
          Text(
            'Permanently boost your guardians\' combat stats. Effects apply to all deployed creatures.',
            style: _T.body,
          ),
          const SizedBox(height: 16),
          ...kGuardianUpgrades.map(
            (def) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpgradeCard(
                name: def.name,
                description: def.description,
                icon: def.icon,
                color: def.color,
                currentLevel: state.getGuardianLevel(def.upgrade),
                maxLevel: def.maxLevel,
                nextCost: svc.nextGuardianCost(def.upgrade),
                bonusLabel: def.bonusLabel(state.getGuardianLevel(def.upgrade)),
                silverBalance: _silverBalance,
                purchasing: _purchasing,
                onUpgrade: () => _upgradeGuardian(svc, def.upgrade),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upgradeGuardian(
    SurvivalUpgradeService svc,
    GuardianUpgrade upgrade,
  ) async {
    if (_purchasing) return;

    final def = getGuardianUpgradeDef(upgrade);
    final cost = svc.nextGuardianCost(upgrade);
    if (cost == null) return;

    final confirmed = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: def.color,
      title: 'CONFIRM UPGRADE',
      message: 'Spend $cost silver to upgrade ${def.name}?',
      amounts: [(CoinKind.silver, cost)],
      amountsLabel: 'COSTS',
      confirmLabel: 'UPGRADE',
    );
    if (!confirmed || !mounted) return;

    setState(() => _purchasing = true);
    final ok = await svc.upgradeGuardianStat(upgrade);
    if (ok) await _loadCurrencies();
    if (mounted) {
      setState(() => _purchasing = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough silver!'),
            backgroundColor: _C.danger,
          ),
        );
      }
    }
  }

  // ── Base Abilities Tab ───────────────────────────────────────────────────

  Widget _buildAbilitiesTab(SurvivalUpgradeService svc) {
    final state = svc.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _EtchedDivider(label: 'BASE ABILITIES'),
          const SizedBox(height: 12),
          Text(
            'Unlock and upgrade powerful orb abilities. These activate automatically during survival waves.',
            style: _T.body,
          ),
          const SizedBox(height: 16),
          ...kBaseAbilities.map((def) {
            final level = state.getAbilityLevel(def.ability);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AbilityCard(
                def: def,
                currentLevel: level,
                nextCost: svc.nextAbilityCost(def.ability),
                silverBalance: _silverBalance,
                purchasing: _purchasing,
                onUpgrade: () => _upgradeAbility(svc, def.ability),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _upgradeAbility(
    SurvivalUpgradeService svc,
    BaseAbility ability,
  ) async {
    if (_purchasing) return;

    final def = getBaseAbilityDef(ability);
    final cost = svc.nextAbilityCost(ability);
    if (cost == null) return;

    final confirmed = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: def.color,
      title: 'CONFIRM UPGRADE',
      message: 'Spend ${_fmtNum(cost)} silver to upgrade ${def.name}?',
      amounts: [(CoinKind.silver, cost)],
      amountsLabel: 'COSTS',
      confirmLabel: 'UPGRADE',
    );
    if (!confirmed || !mounted) return;

    setState(() => _purchasing = true);
    final ok = await svc.upgradeBaseAbility(ability);
    if (ok) await _loadCurrencies();
    if (mounted) {
      setState(() => _purchasing = false);
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough silver!'),
            backgroundColor: _C.danger,
          ),
        );
      }
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

// ── Etched Divider ─────────────────────────────────────────────────────────

class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: _T.label),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: _C.borderMid)),
      ],
    );
  }
}

// ── Plate Box ──────────────────────────────────────────────────────────────

/// Page physics for swiping between Base Command tabs: a stiffer, critically
/// damped settle than the default page spring, and a lighter flick to turn
/// the page, so a swipe feels like it snaps rather than drifts.
class _SnappyPagePhysics extends ScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 420, ratio: 1.0);

  @override
  double get minFlingVelocity => 80;
}

/// The chosen tab: a brass wash, lit from below, inset by half a gap each
/// side so it sits exactly on that tab's fill.
class _LitTabIndicator extends Decoration {
  const _LitTabIndicator({required this.accent});

  final Color accent;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _LitTabIndicatorPainter(accent);
}

class _LitTabIndicatorPainter extends BoxPainter {
  _LitTabIndicatorPainter(this.accent);

  final Color accent;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = Rect.fromLTWH(
      offset.dx + _kTabGap / 2,
      offset.dy,
      size.width - _kTabGap,
      size.height,
    );
    canvas.drawRect(
      rect,
      Paint()..color = _kPalette.accentWash(accent, darkAlpha: 0.18),
    );
    canvas.save();
    canvas.translate(rect.left, rect.top);
    BracketFramePainter(
      color: accent,
      bracketSize: 8,
      strokeWidth: 1.3,
    ).paint(canvas, rect.size);
    canvas.restore();
  }
}

/// A card in the bare language: a flat ink fill, square, no frame. The
/// chosen one (the orb or hull in use) is [lit] from below in its own
/// color over a faint wash of it; a finished one is only [washed].
class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final bool lit;
  final bool washed;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.lit = false,
    this.washed = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _C.amber;
    final fill = lit
        ? Color.alphaBlend(accent.withValues(alpha: 0.10), _C.bg2)
        : washed
        ? Color.alphaBlend(accent.withValues(alpha: 0.05), _C.bg2)
        : _C.bg2;
    final card = Container(padding: padding, color: fill, child: child);
    if (!lit) return card;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(color: accent, strokeWidth: 1.3),
      child: card,
    );
  }
}

// ── Forge Button ───────────────────────────────────────────────────────────

/// A buy button in the bare language: square, a wash of the item's color
/// lit from below while it can be pressed, a dim unlit fill when it cannot.
class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final CoinKind? coin;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;

  const _ForgeButton({
    required this.label,
    required this.icon,
    this.coin,
    this.onTap,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? _C.amber;
    final isDisabled = onTap == null || loading;
    return GestureDetector(
      onTap: isDisabled ? null : context.soundAction(onTap),
      child: CustomPaint(
        // The palette's own grey draws nothing: unlit while disabled.
        foregroundPainter: BracketFramePainter(
          color: isDisabled ? _kPalette.line : btnColor,
          bracketSize: 10,
          strokeWidth: 1.3,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          color: isDisabled
              ? _C.bg3
              : _kPalette.accentWash(btnColor, darkAlpha: 0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: btnColor,
                  ),
                )
              else if (coin != null)
                Opacity(
                  opacity: isDisabled ? 0.5 : 1,
                  child: CoinIcon(kind: coin!, size: 16),
                )
              else
                Icon(
                  icon,
                  size: 16,
                  color: isDisabled ? _C.textMuted : btnColor,
                ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: isDisabled ? _C.textMuted : _C.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Level Pips ─────────────────────────────────────────────────────────────

class _LevelPips extends StatelessWidget {
  final int current;
  final int max;
  final Color color;

  const _LevelPips({
    required this.current,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < current;
        return Container(
          width: 14,
          height: 6,
          margin: const EdgeInsets.only(right: 3),
          // An empty level a step above bg3, which all but vanished on the
          // card's bg2 once the pips lost their outlines.
          color: filled ? color : _C.borderDim,
        );
      }),
    );
  }
}

// ── Orb Skin Card ──────────────────────────────────────────────────────────

class _OrbSkinCard extends StatelessWidget {
  final OrbBaseDef def;
  final bool isOwned;
  final bool isEquipped;
  final String costLabel;
  final CoinKind costCoin;
  final bool canPurchase;
  final bool purchasing;
  final VoidCallback onPurchase;
  final VoidCallback onEquip;

  const _OrbSkinCard({
    required this.def,
    required this.isOwned,
    required this.isEquipped,
    required this.costLabel,
    required this.costCoin,
    required this.canPurchase,
    required this.purchasing,
    required this.onPurchase,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    // Tap anywhere to equip (if owned & not already equipped)
    return GestureDetector(
      onTap: context.soundAction((isOwned && !isEquipped) ? onEquip : null),
      child: _PlateBox(
        lit: isEquipped,
        accentColor: def.primaryColor,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // The core itself, drawn by the painter the run uses.
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(painter: _OrbCorePreview(def.skin)),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    def.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: isEquipped ? def.primaryColor : _C.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(def.description, style: _T.body),
                  if (def.ability.isNotEmpty &&
                      def.ability != 'No special ability.') ...[
                    const SizedBox(height: 4),
                    Text(
                      def.ability,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: def.primaryColor.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (isEquipped) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: def.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'EQUIPPED',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: def.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Action — only show buy button for unowned skins
            if (!isOwned)
              _ForgeButton(
                label: costLabel,
                icon: AppIcons.paid_rounded,
                coin: costCoin,
                onTap: (purchasing || !canPurchase) ? null : onPurchase,
                loading: purchasing,
                color: def.primaryColor,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Ship Hull Card ─────────────────────────────────────────────────────────

/// A hull's color is the light inside it.
Color _shipAccent(String? skinId) => shipLight(skinId).essence;

class _ShipHullCard extends StatelessWidget {
  final String? skinId;
  final String name;
  final String description;
  final bool isUnlocked;
  final bool isEquipped;

  /// What the design costs to forge in cosmic space; null once it is built.
  final String? forgeCost;
  final VoidCallback onEquip;

  const _ShipHullCard({
    required this.skinId,
    required this.name,
    required this.description,
    required this.isUnlocked,
    required this.isEquipped,
    required this.onEquip,
    this.forgeCost,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _shipAccent(skinId);
    return GestureDetector(
      onTap: context.soundAction((isUnlocked && !isEquipped) ? onEquip : null),
      child: Opacity(
        opacity: isUnlocked ? 1.0 : 0.55,
        child: _PlateBox(
          lit: isEquipped,
          accentColor: accent,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                color: _C.bg1,
                child: isUnlocked
                    ? CustomPaint(painter: _ShipPreviewPainter(skinId))
                    : const Icon(
                        AppIcons.lock_rounded,
                        color: _C.textMuted,
                        size: 22,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isEquipped ? accent : _C.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(description, style: _T.body),
                    if (forgeCost != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'FORGE IN COSMIC SPACE',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _C.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        forgeCost!,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: _C.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (isEquipped) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'EQUIPPED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A still of an orb's core, painted by the same code the run draws it with.
class _OrbCorePreview extends CustomPainter {
  const _OrbCorePreview(this.skin);
  final OrbBaseSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2);
    paintOrbCore(
      canvas,
      skin,
      2.5,
      radius: size.shortestSide * 0.26,
      reach: false,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbCorePreview old) => old.skin != skin;
}

/// A still of the hull, painted by the same code that flies it.
class _ShipPreviewPainter extends CustomPainter {
  final String? skinId;
  const _ShipPreviewPainter(this.skinId);

  @override
  void paint(Canvas canvas, Size size) {
    // Hulls are ~40 units tall with a trail below; nudge up so the body,
    // not the exhaust, sits in the middle of the frame.
    final scale = size.shortestSide / 64;
    canvas.save();
    // The hull's wake runs out behind it; keep it inside the card.
    canvas.clipRect(Offset.zero & size);
    canvas.translate(size.width / 2, size.height / 2 - 6 * scale);
    canvas.scale(scale * 1.15);
    // Unblurred, as survival flies it.
    ShipComponent(
      pos: Offset.zero,
    ).render(canvas, 0, skin: skinId, glow: false);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShipPreviewPainter old) => old.skinId != skinId;
}

// ── Generic Upgrade Card (Guardian Stats) ──────────────────────────────────

class _UpgradeCard extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final int currentLevel;
  final int maxLevel;
  final int? nextCost;
  final String bonusLabel;
  final int silverBalance;
  final bool purchasing;
  final VoidCallback onUpgrade;

  const _UpgradeCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.currentLevel,
    required this.maxLevel,
    required this.nextCost,
    required this.bonusLabel,
    required this.silverBalance,
    required this.purchasing,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isMaxed = currentLevel >= maxLevel;
    return _PlateBox(
      washed: isMaxed,
      accentColor: color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                color: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isMaxed ? color : _C.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description, style: _T.body),
                  ],
                ),
              ),
              // Current bonus
              if (currentLevel > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: color.withValues(alpha: 0.12),
                  child: Text(
                    bonusLabel,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LevelPips(current: currentLevel, max: maxLevel, color: color),
              const Spacer(),
              if (isMaxed)
                Text(
                  'MAXED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                )
              else
                _ForgeButton(
                  label: _fmtNum(nextCost!),
                  icon: AppIcons.paid_rounded,
                  coin: CoinKind.silver,
                  onTap: (purchasing || silverBalance < (nextCost ?? 999999))
                      ? null
                      : onUpgrade,
                  loading: purchasing,
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Base Ability Card ──────────────────────────────────────────────────────

class _AbilityCard extends StatelessWidget {
  final BaseAbilityDef def;
  final int currentLevel;
  final int? nextCost;
  final int silverBalance;
  final bool purchasing;
  final VoidCallback onUpgrade;

  const _AbilityCard({
    required this.def,
    required this.currentLevel,
    required this.nextCost,
    required this.silverBalance,
    required this.purchasing,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final isMaxed = currentLevel >= def.maxLevel;
    final isUnlocked = currentLevel > 0;
    return _PlateBox(
      washed: isMaxed,
      accentColor: def.color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ability icon on a flat tile of its color once unlocked.
              Container(
                width: 42,
                height: 42,
                color: isUnlocked ? def.color.withValues(alpha: 0.16) : _C.bg3,
                child: Icon(
                  def.icon,
                  color: isUnlocked ? def.color : _C.textMuted,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: isMaxed
                            ? def.color
                            : (isUnlocked ? _C.textPrimary : _C.textSecondary),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      def.description,
                      style: _T.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Level descriptions row
          if (isUnlocked) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: def.color.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Text(
                    'LV.$currentLevel',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: def.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      def.levelDescriptions[(currentLevel - 1).clamp(
                        0,
                        def.maxLevel - 1,
                      )],
                      style: TextStyle(
                        color: def.color.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              _LevelPips(
                current: currentLevel,
                max: def.maxLevel,
                color: def.color,
              ),
              const Spacer(),
              if (isMaxed)
                Text(
                  'MAXED',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: def.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                )
              else
                _ForgeButton(
                  label: isUnlocked
                      ? _fmtNum(nextCost!)
                      : 'UNLOCK ${_fmtNum(nextCost!)}',
                  icon: isUnlocked
                      ? AppIcons.paid_rounded
                      : AppIcons.lock_open_rounded,
                  coin: isUnlocked ? CoinKind.silver : null,
                  onTap: (purchasing || silverBalance < (nextCost ?? 999999))
                      ? null
                      : onUpgrade,
                  loading: purchasing,
                  color: def.color,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
