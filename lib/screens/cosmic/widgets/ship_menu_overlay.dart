// lib/screens/cosmic/widgets/ship_menu_overlay.dart
//
// The ship console, in the customization lab's language: the ship flying on
// a stage at the top (its hull, its wake, its sentinels), its state as
// gauges and a few readings, what it is fitted with, the supplies that can
// be made for it at home, and the things to do docked at the foot.
//
// Each figure is said once. Fuel used to appear twice (under the booster
// and again under supplies), the sentinels twice too, and every value wore
// a coloured pill of its own.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'cosmic_overlay_chrome.dart';
import 'cosmic_panel_kit.dart';
import 'cosmic_screen_styles.dart';
import 'ship_inventory_overlay.dart';

const _accent = CosmicScreenStyles.teal;
const _fuelColor = Color(0xFFFF8A3D);
const _missileColor = Color(0xFFE5675B);

/// What the relocation costs, in shards carried.
const int kRelocateHomeCost = 50;

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
    this.onToggleTapToShoot,
    this.hasMatterInjector = false,
    this.matterBoostEnabled = false,
    this.onToggleMatterBoost,
    this.shipSkin,
    this.ammoName,
    this.elementStorage,
    this.pullPlanet,
    this.tooClosePlanet,
    this.onFlyElsewhere,
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
  final ValueChanged<bool>? onToggleTapToShoot;

  /// The Matter Injector has been built. Shows the row whether or not the
  /// injector is currently switched on.
  final bool hasMatterInjector;

  /// Whether the booster may fall back to burning cargo on a dry tank.
  final bool matterBoostEnabled;
  final ValueChanged<bool>? onToggleMatterBoost;

  /// The hull flying ('skin_phantom', …; null for the standard hull).
  final String? shipSkin;

  /// The ammo loaded, by name; null for standard bolts.
  final String? ammoName;

  /// What the base holds, so a supply's price shows what it can cover.
  final ElementStorage? elementStorage;

  /// The planet whose pull the ship is in, if any: a home built or moved
  /// here would orbit it. Said beside the build / move action.
  final CosmicPlanet? pullPlanet;

  /// The planet the ship is too close to for a home to go here, if any.
  final CosmicPlanet? tooClosePlanet;

  /// Closes the console so the player can fly somewhere else first. Shown
  /// beside the placement note.
  final VoidCallback? onFlyElsewhere;

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
      InvKeys.harvesterStdVolcanic,
      InvKeys.harvesterStdOceanic,
      InvKeys.harvesterStdVerdant,
      InvKeys.harvesterStdEarthen,
      InvKeys.harvesterStdArcane,
      InvKeys.harvesterGuaranteed,
      InvKeys.staminaPotion,
      InvKeys.wildFusion,
      InvKeys.raidBeacon,
    ]) {
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

  bool get _tutorial => widget.tutorialBuildHomeMode;

  @override
  Widget build(BuildContext context) {
    if (_showInventoryOverlay) {
      return ShipInventoryOverlay(
        inventory: _inventory,
        loading: _loadingInv,
        onClose: () => setState(() => _showInventoryOverlay = false),
      );
    }

    return Material(
      color: Colors.transparent,
      child: CosmicOverlayBackdrop(
        onTap: _tutorial ? null : widget.onClose,
        alpha: 0.96,
        safeArea: false,
        child: GestureDetector(
          // Fills the screen, so taps inside must not reach the dismiss
          // backdrop underneath.
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: SafeArea(
            child: Column(
              children: [
                PanelHeader(
                  title: 'SHIP CONSOLE',
                  onClose: _tutorial ? null : widget.onClose,
                ),
                _stage(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    children: [
                      _gauges(),
                      const SizedBox(height: 10),
                      _readings(),
                      const SizedBox(height: 14),
                      const PanelSectionHeader('FITTED'),
                      _fitted(),
                      ..._supplies(),
                    ],
                  ),
                ),
                _dock(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage() {
    final skin = widget.shipSkin;
    final name = switch (skin) {
      'skin_phantom' => 'PHANTOM VIPER',
      'skin_solar' => 'SOLAR DRAGOON',
      'skin_inferno' => 'INFERNO RAPTOR',
      'skin_crystal' => 'CRYSTAL BASTION',
      _ => 'STANDARD HULL',
    };
    return SizedBox(
      height: 160,
      child: Stack(
        children: [
          Positioned.fill(
            child: ShipStage(
              skin: skin,
              orbitals: widget.hasOrbitals && widget.orbitalActive > 0,
              orbitalCount: widget.orbitalActive,
              zoom: 1.6,
            ),
          ),
          Positioned(
            left: 16,
            bottom: 8,
            child: Text(name, style: panelLabel(10.5, panelPalette.muted)),
          ),
        ],
      ),
    );
  }

  Widget _gauges() {
    final health = widget.shipMaxHealth <= 0
        ? 0.0
        : (widget.shipHealth / widget.shipMaxHealth).clamp(0.0, 1.0);
    final healthColor = health > 0.6
        ? CosmicScreenStyles.success
        : health > 0.3
        ? CosmicScreenStyles.amberBright
        : CosmicScreenStyles.danger;
    return Column(
      children: [
        PanelGauge(
          label: 'HULL',
          fraction: health,
          value:
              '${widget.shipHealth.toStringAsFixed(0)}/${widget.shipMaxHealth.toStringAsFixed(0)}',
          color: healthColor,
        ),
        PanelGauge(
          label: 'CARGO',
          fraction: widget.meterFill,
          value: '${(widget.meterFill * 100).round()}%',
          color: CosmicScreenStyles.amberBright,
        ),
        if (widget.hasBooster)
          PanelGauge(
            label: 'FUEL',
            fraction: widget.fuelFraction,
            value: '${(widget.fuelFraction * 100).round()}%',
            color: _fuelColor,
          ),
      ],
    );
  }

  Widget _readings() {
    return PanelRow(
      children: [
        PanelReadout(
          label: 'SHARDS CARRIED',
          value: panelFmt(widget.walletShards),
          color: CosmicScreenStyles.astralShardColor,
          leading: const Icon(
            CosmicScreenStyles.astralShardIcon,
            size: 13,
            color: CosmicScreenStyles.astralShardColor,
          ),
        ),
        if (widget.hasMissiles)
          PanelReadout(
            label: 'MISSILES',
            value: '${widget.missileAmmo}/${ShipFuel.maxMissileAmmo}',
            color: widget.missileAmmo == 0 ? CosmicScreenStyles.danger : null,
          ),
        if (widget.hasOrbitals)
          PanelReadout(
            label: 'SENTINELS',
            value: '${widget.orbitalActive}/${OrbitalSentinel.maxActive}',
          ),
      ],
    );
  }

  /// What the ship flies with, one line each.
  Widget _fitted() {
    final rows = <(String, Widget)>[
      ('GUN', _value(widget.activeWeaponName)),
      ('AMMO', _value((widget.ammoName ?? 'Standard bolts').toUpperCase())),
      if (widget.hasMissiles) ('LAUNCHER', _value('SEEKER MISSILES')),
      if (widget.hasOrbitals) ('SHIELDS', _value('ORBITAL SENTINELS')),
      if (widget.hasMatterInjector)
        (
          'INJECTOR',
          _Switch(
            on: widget.matterBoostEnabled,
            label: 'MATTER BOOST',
            onChanged: widget.onToggleMatterBoost,
          ),
        ),
    ];
    return Column(
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 82,
                  child: Text(
                    label,
                    style: panelLabel(10.5, panelPalette.muted),
                  ),
                ),
                const Spacer(),
                value,
              ],
            ),
          ),
      ],
    );
  }

  Widget _value(String text) =>
      Text(text, style: panelLabel(11, panelPalette.ink, spacing: 0.8));

  /// What can be made for the ship at home. A station that keeps a supply
  /// topped up does the job itself, so its row says so instead.
  List<Widget> _supplies() {
    final rows = <Widget>[
      if (widget.hasBooster)
        _supplyRow(
          label: 'FUEL',
          station: widget.hasRefuelStation,
          stationNote: 'REFUELS AT HOME',
          cost: ShipFuel.fuelCost,
          action: 'REFUEL',
          onTap: widget.onRefuel,
          color: _fuelColor,
        ),
      if (widget.hasMissiles)
        _supplyRow(
          label: 'MISSILES',
          station: widget.hasMissileStation,
          stationNote: 'RELOADS AT HOME',
          cost: ShipFuel.missileCost,
          action: 'CRAFT',
          onTap: widget.onCraftMissiles,
          color: _missileColor,
        ),
      if (widget.hasOrbitals)
        _supplyRow(
          label: 'SENTINELS · ${widget.orbitalStockpile} IN STOCK',
          station: widget.hasSentinelStation,
          stationNote: 'REPLENISH AT HOME',
          cost: OrbitalSentinel.sentinelCost,
          action: 'CRAFT',
          onTap: widget.onCraftSentinels,
          color: _accent,
          note: widget.orbitalStockpile < OrbitalSentinel.autoReplenishThreshold
              ? 'Refills itself while ${OrbitalSentinel.autoReplenishThreshold}+ are in stock.'
              : null,
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      const SizedBox(height: 14),
      const PanelSectionHeader('SUPPLIES'),
      ...rows,
    ];
  }

  Widget _supplyRow({
    required String label,
    required bool station,
    required String stationNote,
    required Map<String, int> cost,
    required String action,
    required VoidCallback onTap,
    required Color color,
    String? note,
  }) {
    final stored = widget.elementStorage?.stored;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: panelPalette.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PanelDot(color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(11, panelPalette.ink),
                ),
              ),
              const SizedBox(width: 8),
              if (station)
                Text(stationNote, style: panelLabel(10, color, spacing: 0.8))
              else
                SizedBox(
                  width: 128,
                  height: 30,
                  child: BracketButton(
                    label: widget.isNearHome ? action : 'DOCK AT HOME',
                    height: 30,
                    palette: panelPalette,
                    accent: color,
                    enabled: widget.isNearHome,
                    onTap: onTap,
                  ),
                ),
            ],
          ),
          if (!station) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                for (final e in cost.entries)
                  stored == null
                      ? Text(
                          '${e.key} ${e.value}',
                          style: panelLabel(10.5, elementInk(e.key)),
                        )
                      : CostChip(e.key, e.value, stored, size: 10.5),
                Text('EACH', style: panelLabel(9, panelPalette.muted)),
              ],
            ),
          ],
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(
              note,
              style: TextStyle(
                fontFamily: appFontFamily(context),
                color: CosmicScreenStyles.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// The line about where the ship is, when a home placed here would orbit
  /// a planet or could not go at all.
  Widget? _placementNote({required bool building}) {
    final blocked = widget.tooClosePlanet;
    final pull = widget.pullPlanet;
    final verb = building ? 'build' : 'move';
    if (blocked != null) {
      return PlacementNote(
        key: const ValueKey('ship.placementNote'),
        planet: blocked,
        text:
            'Too close to ${planetName(blocked.element)}. Fly further out to '
            '$verb your home.',
        onFlyElsewhere: widget.onFlyElsewhere,
      );
    }
    if (pull == null) return null;
    final name = planetName(pull.element);
    return PlacementNote(
      key: const ValueKey('ship.placementNote'),
      planet: pull,
      text: building
          ? "You're inside $name's pull. Your home will orbit it."
          : "You're inside $name's pull. Moved here, your home will orbit it.",
      onFlyElsewhere: widget.onFlyElsewhere,
    );
  }

  /// What there is to do, docked at the foot. Until there is a home, the
  /// console is for building one; after that it opens on the party.
  Widget _dock() {
    final showParty = widget.hasParty && widget.onParty != null;
    final children = <Widget>[];

    if (!widget.hasHomePlanet) {
      if (_tutorial) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'BUILD YOUR HOME HERE TO UNLOCK SHIP AND PLANET UPGRADES',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'monospace',
                color: CosmicScreenStyles.textPrimary.withValues(alpha: 0.8),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                height: 1.4,
              ),
            ),
          ),
        );
      }
      final note = _placementNote(building: true);
      if (note != null) children.add(note);
      children.add(
        BracketButton(
          key: const ValueKey('ship.buildHome'),
          label: 'BUILD HOME',
          height: 46,
          palette: panelPalette,
          accent: CosmicScreenStyles.amberBright,
          onTap: widget.onBuildHome,
        ),
      );
    }

    final secondaries = <Widget>[
      if (showParty && widget.hasHomePlanet)
        BracketButton(
          key: const ValueKey('ship.party'),
          label: widget.isNearHome ? 'PARTY' : 'PARTY · AT HOME',
          height: 40,
          palette: panelPalette,
          accent: _accent,
          primary: widget.isNearHome,
          enabled: widget.isNearHome && !_tutorial,
          onTap: widget.onParty,
        ),
      BracketButton(
        key: const ValueKey('ship.inventory'),
        label: 'INVENTORY',
        height: 40,
        palette: panelPalette,
        accent: _accent,
        primary: false,
        enabled: !_tutorial,
        onTap: () => setState(() => _showInventoryOverlay = true),
      ),
      if (widget.hasHomePlanet)
        BracketButton(
          key: const ValueKey('ship.moveHome'),
          label: 'MOVE HOME',
          height: 40,
          palette: panelPalette,
          accent: _accent,
          primary: false,
          trailing: ShardAmount(
            kRelocateHomeCost,
            size: 10.5,
            enabled: widget.walletShards >= kRelocateHomeCost,
          ),
          onTap: widget.onRelocateHome,
        ),
    ];

    if (widget.hasHomePlanet) {
      final note = _placementNote(building: false);
      if (note != null) children.add(note);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: CosmicScreenStyles.bg1,
        border: Border(
          top: BorderSide(color: _accent.withValues(alpha: 0.45), width: 1.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...children,
          if (children.isNotEmpty) const SizedBox(height: 8),
          // The party first and widest when there is one; the rest share a
          // row beneath it.
          if (secondaries.length == 3) ...[
            secondaries.first,
            const SizedBox(height: 8),
            PanelRow(children: secondaries.sublist(1)),
          ] else
            PanelRow(children: secondaries),
        ],
      ),
    );
  }
}

/// What placing a home here would do, when it would do something to note:
/// orbit a planet whose pull the ship is in, or not go at all. A line in
/// the planet's colour inside a bracket frame, with a quiet way out.
class PlacementNote extends StatelessWidget {
  const PlacementNote({
    super.key,
    required this.planet,
    required this.text,
    this.onFlyElsewhere,
  });

  final CosmicPlanet planet;
  final String text;
  final VoidCallback? onFlyElsewhere;

  @override
  Widget build(BuildContext context) {
    final accent = elementInk(planet.element);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.7),
          bracketSize: 6,
          strokeWidth: 1.1,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          color: accent.withValues(alpha: 0.08),
          child: Row(
            children: [
              PanelDot(accent),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontFamily: panelMono,
                    color: panelPalette.ink,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onFlyElsewhere != null)
                GestureDetector(
                  key: const ValueKey('ship.flyElsewhere'),
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(onFlyElsewhere!),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Text(
                      'FLY ELSEWHERE',
                      style: panelLabel(10, panelPalette.muted, spacing: 1),
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

/// A setting that reads as a line of the console: its name, and ON or OFF
/// in a frame that lights when it is on.
class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.label, this.onChanged});
  final bool on;
  final String label;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tint = on ? _fuelColor : panelPalette.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null
          ? null
          : context.soundAction(() => onChanged!(!on)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: panelLabel(11, panelPalette.ink, spacing: 0.8)),
          const SizedBox(width: 10),
          CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: tint,
              bracketSize: 5,
              strokeWidth: on ? 1.2 : 1,
            ),
            child: Container(
              width: 40,
              padding: const EdgeInsets.symmetric(vertical: 4),
              alignment: Alignment.center,
              color: on ? _fuelColor.withValues(alpha: 0.14) : null,
              child: Text(on ? 'ON' : 'OFF', style: panelLabel(10, tint)),
            ),
          ),
        ],
      ),
    );
  }
}
