import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'cosmic_screen_styles.dart';
import 'ship_inventory_overlay.dart';
import 'forge_bar.dart';

class ShipMenuOverlay extends StatefulWidget {
  const ShipMenuOverlay({
    super.key,
    required this.hasHomePlanet,
    required this.meterFill,
    required this.walletShards,
    required this.shipHealth,
    required this.shipMaxHealth,
    required this.fuelFraction,
    required this.activeWeaponName,
    required this.orbitalStockpile,
    required this.orbitalActive,
    required this.hasBooster,
    required this.hasOrbitals,
    required this.hasMissiles,
    required this.missileAmmo,
    required this.cargoLevel,
    required this.isNearHome,
    this.hasRefuelStation = false,
    this.hasMissileStation = false,
    this.hasSentinelStation = false,
    required this.onClose,
    required this.onBuildHome,
    required this.onRelocateHome,
    required this.onJettisonCargo,
    required this.onDumpWallet,
    required this.onRefuel,
    required this.onCraftMissiles,
    required this.onCraftSentinels,
    required this.onUpgradeCargo,
    this.tutorialBuildHomeMode = false,
    this.hasParty = false,
    this.onParty,
    this.joystickEnabled = false,
    this.onToggleJoystick,
    this.tapToShootEnabled = false,
    this.onToggleTapToShoot,
    this.boostToggleEnabled = false,
    this.onToggleBoostToggle,
  });

  final bool hasHomePlanet;
  final double meterFill;
  final int walletShards;
  final double shipHealth;
  final double shipMaxHealth;
  final double fuelFraction;
  final String activeWeaponName;
  final int orbitalStockpile;
  final int orbitalActive;
  final bool hasBooster;
  final bool hasOrbitals;
  final bool hasMissiles;
  final int missileAmmo;
  final int cargoLevel;
  final bool isNearHome;
  final bool hasRefuelStation;
  final bool hasMissileStation;
  final bool hasSentinelStation;
  final bool hasParty;
  final VoidCallback onClose;
  final VoidCallback onBuildHome;
  final VoidCallback onRelocateHome;
  final VoidCallback onJettisonCargo;
  final VoidCallback onDumpWallet;
  final VoidCallback onRefuel;
  final VoidCallback onCraftMissiles;
  final VoidCallback onCraftSentinels;
  final VoidCallback onUpgradeCargo;
  final bool tutorialBuildHomeMode;
  final VoidCallback? onParty;
  final bool joystickEnabled;
  final ValueChanged<bool>? onToggleJoystick;
  final bool tapToShootEnabled;
  final ValueChanged<bool>? onToggleTapToShoot;
  final bool boostToggleEnabled;
  final ValueChanged<bool>? onToggleBoostToggle;

  @override
  State<ShipMenuOverlay> createState() => ShipMenuOverlayState();
}

class ShipMenuOverlayState extends State<ShipMenuOverlay> {
  Map<String, int> _inventory = {};
  bool _loadingInv = true;
  bool _showInventoryOverlay = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final db = context.read<AlchemonsDatabase>();
    final items = <String, int>{};
    for (final key in [
      InvKeys.portalKeyVolcanic,
      InvKeys.portalKeyOceanic,
      InvKeys.portalKeyVerdant,
      InvKeys.portalKeyEarthen,
      InvKeys.portalKeyArcane,
    ]) {
      final qty = await db.inventoryDao.getItemQty(key);
      if (qty > 0) items[key] = qty;
    }
    for (final key in [
      InvKeys.harvesterStdVolcanic,
      InvKeys.harvesterStdOceanic,
      InvKeys.harvesterStdVerdant,
      InvKeys.harvesterStdEarthen,
      InvKeys.harvesterStdArcane,
      InvKeys.harvesterGuaranteed,
    ]) {
      final qty = await db.inventoryDao.getItemQty(key);
      if (qty > 0) items[key] = qty;
    }
    for (final key in [InvKeys.staminaPotion, InvKeys.bossRefresh]) {
      final qty = await db.inventoryDao.getItemQty(key);
      if (qty > 0) items[key] = qty;
    }
    if (mounted) {
      setState(() {
        _inventory = items;
        _loadingInv = false;
      });
    }
  }

  // ── Section builder: plate-box header + body ──
  Widget _forgeSection(String title, Widget child, {Color? accent}) {
    final a = accent ?? CosmicScreenStyles.amber;
    return Container(
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: CosmicScreenStyles.bg3,
              borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
              border: Border(
                bottom: BorderSide(color: CosmicScreenStyles.borderDim),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 10,
                  color: a,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: a,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(12), child: child),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final healthPct = (widget.shipHealth / widget.shipMaxHealth).clamp(
      0.0,
      1.0,
    );
    final healthColor = healthPct > 0.6
        ? CosmicScreenStyles.success
        : healthPct > 0.3
        ? CosmicScreenStyles.amberBright
        : CosmicScreenStyles.danger;

    if (_showInventoryOverlay) {
      return ShipInventoryOverlay(
        inventory: _inventory,
        loading: _loadingInv,
        onClose: () => setState(() => _showInventoryOverlay = false),
      );
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.tutorialBuildHomeMode ? null : widget.onClose,
        child: Container(
          color: CosmicScreenStyles.bg0.withValues(alpha: 0.92),
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight: min(
                    680.0,
                    MediaQuery.of(context).size.height - 28,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                decoration: BoxDecoration(
                  color: CosmicScreenStyles.bg1,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CosmicScreenStyles.borderDim),
                  boxShadow: [
                    BoxShadow(
                      color: CosmicScreenStyles.amber.withValues(alpha: 0.08),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Corner notches
                    Positioned(
                      top: 0,
                      left: 0,
                      child: _cornerNotch(topLeft: true),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _cornerNotch(topLeft: false),
                    ),

                    // Content
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const SizedBox(height: 8),
                        _dockedHeader(),
                        const SizedBox(height: 6),
                        _etchedDivider(context: context),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // ── Status ──
                                _forgeSection(
                                  'SYSTEMS',
                                  Column(
                                    children: [
                                      ForgeBar(
                                        label: 'HULL',
                                        value:
                                            '${widget.shipHealth.toStringAsFixed(1)} / ${widget.shipMaxHealth.toStringAsFixed(0)}',
                                        pct: healthPct,
                                        barColor: healthColor,
                                      ),
                                      const SizedBox(height: 10),
                                      ForgeBar(
                                        label: 'CARGO',
                                        value:
                                            '${(widget.meterFill * 100).round()}%',
                                        pct: widget.meterFill,
                                        barColor:
                                            CosmicScreenStyles.amberBright,
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            'SHARDS',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: CosmicScreenStyles
                                                  .textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.6,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: CosmicScreenStyles
                                                  .amberBright
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              border: Border.all(
                                                color: CosmicScreenStyles
                                                    .amberBright
                                                    .withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.diamond_rounded,
                                                  color: CosmicScreenStyles
                                                      .amberBright,
                                                  size: 12,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${widget.walletShards}',
                                                  style: TextStyle(
                                                    fontFamily: appFontFamily(context),
                                                    color: CosmicScreenStyles
                                                        .amberBright,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  accent: CosmicScreenStyles.teal,
                                ),
                                const SizedBox(height: 12),

                                // ── Equipment ──
                                _forgeSection(
                                  'EQUIPMENT',
                                  Column(
                                    children: [
                                      // Active weapon
                                      Row(
                                        children: [
                                          Text(
                                            'GUN',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: CosmicScreenStyles
                                                  .textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1.6,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: CosmicScreenStyles.teal
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              border: Border.all(
                                                color: CosmicScreenStyles.teal
                                                    .withValues(alpha: 0.35),
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              widget.activeWeaponName,
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: CosmicScreenStyles.teal,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (widget.hasMissiles) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'LAUNCHER',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: CosmicScreenStyles
                                                    .textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.6,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFE53935,
                                                ).withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFE53935,
                                                  ).withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                'SEEKER MISSILES (${widget.missileAmmo})',
                                                style: TextStyle(
                                                  fontFamily: appFontFamily(context),
                                                  color: Color(0xFFE53935),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (widget.hasBooster) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'BOOSTER',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: CosmicScreenStyles
                                                    .textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.6,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFFF6F00,
                                                ).withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFFFF6F00,
                                                  ).withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                'ION BOOSTER (${(widget.fuelFraction * 100).round()}%)',
                                                style: TextStyle(
                                                  fontFamily: appFontFamily(context),
                                                  color: Color(0xFFFF6F00),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (widget.hasOrbitals) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              'SHIELDS',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: CosmicScreenStyles
                                                    .textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.6,
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF42A5F5,
                                                ).withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF42A5F5,
                                                  ).withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                'SENTINELS (${widget.orbitalActive}/${OrbitalSentinel.maxActive})',
                                                style: TextStyle(
                                                  fontFamily: appFontFamily(context),
                                                  color: Color(0xFF42A5F5),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                  accent: CosmicScreenStyles.teal,
                                ),
                                const SizedBox(height: 12),

                                // ── Consumable crafting ──
                                _forgeSection(
                                  'SUPPLIES',
                                  Column(
                                    children: [
                                      if (widget.hasBooster) ...[
                                        ForgeBar(
                                          label: 'FUEL',
                                          value:
                                              '${(widget.fuelFraction * 100).round()}%',
                                          pct: widget.fuelFraction,
                                          barColor: const Color(0xFFFF6F00),
                                        ),
                                        const SizedBox(height: 6),
                                        if (!widget.hasRefuelStation)
                                          _craftButton(
                                            label:
                                                'REFUEL (${_fmtCost(ShipFuel.fuelCost)}/ea)',
                                            color: const Color(0xFFFF6F00),
                                            onTap: widget.onRefuel,
                                            enabled: widget.isNearHome,
                                          )
                                        else
                                          Text(
                                            'AUTO-REFUEL AT HOME',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: const Color(
                                                0xFFFF6F00,
                                              ).withValues(alpha: 0.6),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                      ],
                                      if (widget.hasMissiles) ...[
                                        ForgeBar(
                                          label: 'MISSILES',
                                          value:
                                              '${widget.missileAmmo}/${ShipFuel.maxMissileAmmo}',
                                          pct:
                                              widget.missileAmmo /
                                              ShipFuel.maxMissileAmmo,
                                          barColor: const Color(0xFFE53935),
                                        ),
                                        const SizedBox(height: 6),
                                        if (!widget.hasMissileStation)
                                          _craftButton(
                                            label:
                                                'CRAFT MISSILES (${_fmtCost(ShipFuel.missileCost)}/ea)',
                                            color: const Color(0xFFE53935),
                                            onTap: widget.onCraftMissiles,
                                            enabled: widget.isNearHome,
                                          )
                                        else
                                          Text(
                                            'AUTO-RELOAD AT HOME',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: const Color(
                                                0xFFE53935,
                                              ).withValues(alpha: 0.6),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        const SizedBox(height: 10),
                                      ],
                                      if (widget.hasOrbitals) ...[
                                        Row(
                                          children: [
                                            Text(
                                              'SENTINELS',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: CosmicScreenStyles
                                                    .textSecondary,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.6,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${widget.orbitalActive}/${OrbitalSentinel.maxActive} active \u2022 ${widget.orbitalStockpile} stock',
                                              style: TextStyle(
                                                fontFamily: appFontFamily(context),
                                                color: Color(0xFF42A5F5),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (!widget.hasSentinelStation)
                                          _craftButton(
                                            label:
                                                'CRAFT SENTINELS (${_fmtCost(OrbitalSentinel.sentinelCost)}/ea)',
                                            color: const Color(0xFF42A5F5),
                                            onTap: widget.onCraftSentinels,
                                            enabled: widget.isNearHome,
                                          )
                                        else
                                          Text(
                                            'AUTO-REPLENISH AT HOME',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color: const Color(
                                                0xFF42A5F5,
                                              ).withValues(alpha: 0.6),
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        if (!widget.hasSentinelStation &&
                                            widget.orbitalStockpile <
                                                OrbitalSentinel
                                                    .autoReplenishThreshold)
                                          Text(
                                            'Need ${OrbitalSentinel.autoReplenishThreshold} stockpiled to auto-replenish',
                                            style: TextStyle(
                                              fontFamily: appFontFamily(context),
                                              color:
                                                  CosmicScreenStyles.textMuted,
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                      ],
                                      if (!widget.hasBooster &&
                                          !widget.hasMissiles &&
                                          !widget.hasOrbitals)
                                        Text(
                                          'Craft equipment in the Customization Lab first.',
                                          style: TextStyle(
                                            fontFamily: appFontFamily(context),
                                            color: CosmicScreenStyles.textMuted,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                    ],
                                  ),
                                  accent: const Color(0xFFFF6F00),
                                ),
                                const SizedBox(height: 12),

                                // ── Build Home (only when none exists) ──
                                if (!widget.hasHomePlanet) ...[
                                  if (widget.tutorialBuildHomeMode) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: CosmicScreenStyles.bg3,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF00E5FF,
                                          ).withValues(alpha: 0.55),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF00E5FF,
                                            ).withValues(alpha: 0.16),
                                            blurRadius: 14,
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        'Build your home base here to unlock ship and planet upgrades.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: appFontFamily(context),
                                          color: CosmicScreenStyles.textPrimary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                  _forgeAction(
                                    icon: Icons.add_location_alt_rounded,
                                    label: 'BUILD HOME',
                                    onTap: widget.onBuildHome,
                                    primary: true,
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // ── Crew (party) button ──
                                if (widget.hasParty && widget.onParty != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Opacity(
                                      opacity: widget.isNearHome ? 1.0 : 0.35,
                                      child: _forgeAction(
                                        icon: Icons.groups_rounded,
                                        label: widget.isNearHome
                                            ? 'PARTY'
                                            : 'PARTY (AT HOME)',
                                        onTap: widget.isNearHome
                                            ? widget.onParty!
                                            : () {},
                                      ),
                                    ),
                                  ),

                                // ── Inventory button ──
                                _forgeAction(
                                  icon: Icons.inventory_rounded,
                                  label: 'INVENTORY',
                                  onTap: widget.tutorialBuildHomeMode
                                      ? () {}
                                      : () => setState(
                                          () => _showInventoryOverlay = true,
                                        ),
                                ),
                                const SizedBox(height: 12),

                                // ── Actions ──
                                Column(
                                  children: [
                                    if (widget.hasHomePlanet) ...[
                                      _forgeAction(
                                        icon: Icons.my_location_rounded,
                                        label: 'RELOCATE HOME (50✦)',
                                        onTap: widget.onRelocateHome,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),

                                const SizedBox(height: 16),

                                // ── Close ──
                                if (!widget.tutorialBuildHomeMode)
                                  GestureDetector(
                                    onTap: widget.onClose,
                                    child: Container(
                                      width: double.infinity,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(
                                          color: CosmicScreenStyles.borderAccent
                                              .withValues(alpha: 0.6),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'CLOSE',
                                        style: TextStyle(
                                          fontFamily: appFontFamily(context),
                                          color:
                                              CosmicScreenStyles.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
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
        ),
      ),
    );
  }

  Widget _dockedHeader() {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg3,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: CosmicScreenStyles.borderDim),
      ),
      child: Row(
        children: [
          if (!widget.hasHomePlanet)
            GestureDetector(
              onTap: widget.onBuildHome,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF141820),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: CosmicScreenStyles.borderDim),
                ),
                child: const Icon(
                  Icons.add_location_alt_rounded,
                  color: CosmicScreenStyles.textSecondary,
                  size: 18,
                ),
              ),
            )
          else
            const SizedBox(width: 34, height: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'SHIP CONSOLE',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: widget.tutorialBuildHomeMode ? null : widget.onClose,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFF141820),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CosmicScreenStyles.borderDim),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: CosmicScreenStyles.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Forge-style action button ──
  Widget _craftButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : CosmicScreenStyles.textMuted;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          enabled ? label : 'DOCK AT HOME TO CRAFT',
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: effectiveColor,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  /// Format a cost map for button labels, e.g. "8 Fire, 2 Crystal".
  static String _fmtCost(Map<String, int> cost) {
    return cost.entries.map((e) => '${e.value} ${e.key}').join(', ');
  }

  Widget _forgeAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool enabled = true,
    bool primary = false,
    bool destructive = false,
  }) {
    final isDisabled = !enabled;
    final Color bg;
    final Color border;
    final Color textColor;
    final Color iconColor;

    if (isDisabled) {
      bg = CosmicScreenStyles.bg3.withValues(alpha: 0.4);
      border = CosmicScreenStyles.borderDim;
      textColor = CosmicScreenStyles.textMuted;
      iconColor = CosmicScreenStyles.textMuted;
    } else if (primary) {
      bg = CosmicScreenStyles.amber;
      border = CosmicScreenStyles.amberGlow;
      textColor = CosmicScreenStyles.bg0;
      iconColor = CosmicScreenStyles.bg0;
    } else if (destructive) {
      bg = Colors.transparent;
      border = CosmicScreenStyles.danger.withValues(alpha: 0.5);
      textColor = CosmicScreenStyles.danger;
      iconColor = CosmicScreenStyles.danger;
    } else {
      bg = Colors.transparent;
      border = CosmicScreenStyles.borderAccent.withValues(alpha: 0.6);
      textColor = CosmicScreenStyles.textSecondary;
      iconColor = CosmicScreenStyles.textSecondary;
    }

    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        width: double.infinity,
        height: primary ? 46 : 40,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: border, width: primary ? 1 : 0.8),
          boxShadow: primary && !isDisabled
              ? [
                  BoxShadow(
                    color: CosmicScreenStyles.amber.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Etched divider ──
  static Widget _etchedDivider({
    required BuildContext context,
    String? label,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: appFontFamily(context),
              color: CosmicScreenStyles.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 10),
        ] else ...[
          const SizedBox(width: 6),
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: CosmicScreenStyles.amber.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Container(height: 1, color: CosmicScreenStyles.borderMid),
        ),
      ],
    );
  }

  // ── Corner notch decoration ──
  static Widget _cornerNotch({required bool topLeft}) {
    const a = CosmicScreenStyles.amber;
    final border = topLeft
        ? Border(
            top: BorderSide(color: a.withValues(alpha: 0.5), width: 1.5),
            left: BorderSide(color: a.withValues(alpha: 0.5), width: 1.5),
          )
        : Border(
            bottom: BorderSide(color: a.withValues(alpha: 0.5), width: 1.5),
            right: BorderSide(color: a.withValues(alpha: 0.5), width: 1.5),
          );
    return SizedBox(
      width: 10,
      height: 10,
      child: DecoratedBox(decoration: BoxDecoration(border: border)),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SHIP INVENTORY OVERLAY
// ─────────────────────────────────────────────────────────
