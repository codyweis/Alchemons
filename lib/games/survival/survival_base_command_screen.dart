// lib/games/survival/survival_base_command_screen.dart
//
// Base Command — persistent survival upgrade screen.
// Three sections: Orb Skins, Guardian Power-ups, Base Abilities.
// Follows the scorched-metal forge aesthetic of the survival mode UI.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (identical to survival_game_screen)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);
  static const danger = Color(0xFFC0392B);
  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
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
    fontSize: 10,
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

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class SurvivalBaseCommandScreen extends StatefulWidget {
  const SurvivalBaseCommandScreen({super.key});

  @override
  State<SurvivalBaseCommandScreen> createState() =>
      _SurvivalBaseCommandScreenState();
}

class _SurvivalBaseCommandScreenState extends State<SurvivalBaseCommandScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _silverBalance = 0;
  Map<String, int> _currencies = {};
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrencies();
  }

  Future<void> _loadCurrencies() async {
    final db = context.read<AlchemonsDatabase>();
    final currencies = await db.currencyDao.getAllCurrencies();
    if (!mounted) return;
    setState(() {
      _currencies = currencies;
      _silverBalance = currencies['silver'] ?? 0;
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
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrbSkinsTab(svc, shopService),
                      _buildGuardianTab(svc),
                      _buildAbilitiesTab(svc),
                    ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textSecondary,
                size: 18,
              ),
            ),
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
                    const Text('BASE COMMAND', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('UPGRADE & CUSTOMIZE', style: _T.label),
              ],
            ),
          ),
          // Silver display
          _PlateBox(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            accentColor: const Color(0xFFC0C0C0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.paid_rounded,
                  color: Color(0xFFC0C0C0),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_silverBalance',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFC0C0C0),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab Bar ──────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: _C.bg1,
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: _C.amber,
        indicatorWeight: 2,
        labelColor: _C.amberBright,
        unselectedLabelColor: _C.textSecondary,
        labelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.4,
        ),
        tabs: const [
          Tab(icon: Icon(Icons.blur_circular_rounded, size: 16), text: 'ORB'),
          Tab(icon: Icon(Icons.person_rounded, size: 16), text: 'GUARDIANS'),
          Tab(
            icon: Icon(Icons.auto_awesome_rounded, size: 16),
            text: 'ABILITIES',
          ),
        ],
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

  ShopOffer? _orbOfferForDef(OrbBaseDef def) {
    for (final offer in ShopService.allOffers) {
      if (offer.id == def.shopId) return offer;
    }
    return null;
  }

  Map<String, int> _orbEffectiveCost(ShopService shopService, OrbBaseDef def) {
    final offer = _orbOfferForDef(def);
    if (offer == null) return {'silver': def.cost};
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

  String _compactCostLabel(Map<String, int> cost) {
    if (cost.isEmpty) return '0';
    return cost.entries
        .map((entry) => '${entry.value}${_currencySuffix(entry.key)}')
        .join('+');
  }

  String _fullCostLabel(Map<String, int> cost) {
    if (cost.isEmpty) return '0';
    return cost.entries
        .map((entry) => '${entry.value} ${_currencyName(entry.key)}')
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _C.borderDim),
        ),
        title: Text(
          'CONFIRM PURCHASE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Spend ${_fullCostLabel(effectiveCost)} on ${def.name}?',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textSecondary,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'BUY',
              style: TextStyle(
                fontFamily: 'monospace',
                color: def.primaryColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _C.borderDim),
        ),
        title: Text(
          'CONFIRM UPGRADE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Spend $cost silver to upgrade ${def.name}?',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textSecondary,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'UPGRADE',
              style: TextStyle(
                fontFamily: 'monospace',
                color: def.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: _C.borderDim),
        ),
        title: Text(
          'CONFIRM UPGRADE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        content: Text(
          'Spend $cost silver to upgrade ${def.name}?',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.textSecondary,
            fontSize: 12,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'UPGRADE',
              style: TextStyle(
                fontFamily: 'monospace',
                color: def.color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

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

class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final bool highlight;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _C.amber;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? accent.withValues(alpha: 0.6) : _C.borderDim,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  left: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  right: BorderSide(
                    color: accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Forge Button ───────────────────────────────────────────────────────────

class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;

  const _ForgeButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? _C.amber;
    final isDisabled = onTap == null || loading;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDisabled ? _C.bg3 : btnColor,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isDisabled ? _C.borderDim : btnColor,
            width: 1,
          ),
          boxShadow: !isDisabled
              ? [
                  BoxShadow(
                    color: btnColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: _C.bg0),
              )
            else
              Icon(icon, size: 16, color: _C.bg0),
            const SizedBox(width: 2),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: isDisabled ? _C.textMuted : _C.bg0,
              ),
            ),
          ],
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
          decoration: BoxDecoration(
            color: filled ? color : _C.bg3,
            borderRadius: BorderRadius.circular(1),
            border: Border.all(
              color: filled ? color.withValues(alpha: 0.7) : _C.borderDim,
              width: 0.5,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
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
  final bool canPurchase;
  final bool purchasing;
  final VoidCallback onPurchase;
  final VoidCallback onEquip;

  const _OrbSkinCard({
    required this.def,
    required this.isOwned,
    required this.isEquipped,
    required this.costLabel,
    required this.canPurchase,
    required this.purchasing,
    required this.onPurchase,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    // Tap anywhere to equip (if owned & not already equipped)
    return GestureDetector(
      onTap: (isOwned && !isEquipped) ? onEquip : null,
      child: _PlateBox(
        highlight: isEquipped,
        accentColor: def.primaryColor,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Orb preview circle
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    def.glowColor.withValues(alpha: 0.6),
                    def.primaryColor,
                    def.secondaryColor,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: def.glowColor.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
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
                            fontSize: 9,
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
                icon: Icons.paid_rounded,
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
      highlight: isMaxed,
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
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
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
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: color.withValues(alpha: 0.25),
                      width: 0.5,
                    ),
                  ),
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                )
              else
                _ForgeButton(
                  label: '$nextCost',
                  icon: Icons.paid_rounded,
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
      highlight: isMaxed,
      accentColor: def.color,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Ability icon with glow
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? def.color.withValues(alpha: 0.18)
                      : _C.bg3,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isUnlocked
                        ? def.color.withValues(alpha: 0.4)
                        : _C.borderDim,
                    width: 1,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: def.color.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
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
              decoration: BoxDecoration(
                color: def.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: def.color.withValues(alpha: 0.15),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'LV.$currentLevel',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: def.color,
                      fontSize: 11,
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
                        fontSize: 11,
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
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                )
              else
                _ForgeButton(
                  label: isUnlocked ? '$nextCost' : 'UNLOCK $nextCost',
                  icon: isUnlocked
                      ? Icons.paid_rounded
                      : Icons.lock_open_rounded,
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
