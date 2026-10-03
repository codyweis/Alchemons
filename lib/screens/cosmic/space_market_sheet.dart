// lib/screens/cosmic/space_market_sheet.dart
//
// The two shop stations of open space:
//   • Harvester Shop — the five faction harvesters and the stabilized one
//   • Rift Key Shop  — the five portal keys
//
// A full panel in the station-screen kit: the station on its stage (the pod
// or key you are looking at lit), the wallet, today's discounts in plain
// words, the goods, and one BUY at the foot.
//
// Prices mirror the main Research Shop. Two discounts can apply, and stack:
//   • your faction's own goods are 90% off;
//   • each item names an element each day (UTC); while that element is at
//     least half of what is in your alchemical meter, it is half price.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/screens/cosmic/widgets/station_panel_kit.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/widgets/portal_key_glyph.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ITEM DEFINITIONS
// ─────────────────────────────────────────────────────────────────────────────

class _MarketItem {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String inventoryKey;
  final Map<String, int> baseCost;
  final String faction; // volcanic, oceanic, verdant, earthen, arcane, neutral

  const _MarketItem({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.inventoryKey,
    required this.baseCost,
    required this.faction,
  });

  /// Which pod or key on the station this is (the stations dock the five
  /// groups in kStationGroupColors' order).
  int? get dock => switch (faction) {
    'volcanic' => 0,
    'oceanic' => 1,
    'earthen' => 2,
    'verdant' => 3,
    'arcane' => 4,
    _ => null,
  };
}

const _harvesterItems = <_MarketItem>[
  _MarketItem(
    id: 'market.harvest.volcanic',
    name: 'Volcanic Harvester',
    description: 'Standard capture device for volcanic creatures.',
    icon: AppIcons.local_fire_department_rounded,
    iconColor: Color(0xFFFF5722),
    inventoryKey: 'item.harvest_std_volcanic',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'volcanic',
  ),
  _MarketItem(
    id: 'market.harvest.oceanic',
    name: 'Oceanic Harvester',
    description: 'Standard capture device for oceanic creatures.',
    icon: AppIcons.water_rounded,
    iconColor: Color(0xFF64B5F6),
    inventoryKey: 'item.harvest_std_oceanic',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'oceanic',
  ),
  _MarketItem(
    id: 'market.harvest.verdant',
    name: 'Verdant Harvester',
    description: 'Standard capture device for verdant creatures.',
    icon: AppIcons.eco_rounded,
    iconColor: Color(0xFF66BB6A),
    inventoryKey: 'item.harvest_std_verdant',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'verdant',
  ),
  _MarketItem(
    id: 'market.harvest.earthen',
    name: 'Earthen Harvester',
    description: 'Standard capture device for earthen creatures.',
    icon: AppIcons.terrain_rounded,
    iconColor: Color(0xFF8D6E63),
    inventoryKey: 'item.harvest_std_earthen',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'earthen',
  ),
  _MarketItem(
    id: 'market.harvest.arcane',
    name: 'Arcane Harvester',
    description: 'Standard capture device for arcane creatures.',
    icon: AppIcons.auto_awesome_rounded,
    iconColor: Color(0xFFCE93D8),
    inventoryKey: 'item.harvest_std_arcane',
    baseCost: {'shards': 50, 'silver': 999},
    faction: 'arcane',
  ),
  _MarketItem(
    id: 'market.harvest.stabilized',
    name: 'Stabilized Harvester',
    description: 'Guaranteed capture, never fails.',
    icon: AppIcons.shield_rounded,
    iconColor: Color(0xFFFFD700),
    inventoryKey: 'item.harvest_guaranteed',
    baseCost: {'gold': 1},
    faction: 'neutral',
  ),
];

const _riftKeyItems = <_MarketItem>[
  _MarketItem(
    id: 'market.key.volcanic',
    name: 'Volcanic Portal Key',
    description: 'Grants entry into a Volcanic Rift. Consumed on entry.',
    icon: AppIcons.vpn_key_rounded,
    iconColor: Color(0xFFFF5722),
    inventoryKey: 'item.portal_key.volcanic',
    baseCost: {'gold': 5},
    faction: 'volcanic',
  ),
  _MarketItem(
    id: 'market.key.oceanic',
    name: 'Oceanic Portal Key',
    description: 'Grants entry into an Oceanic Rift. Consumed on entry.',
    icon: AppIcons.vpn_key_rounded,
    iconColor: Color(0xFF64B5F6),
    inventoryKey: 'item.portal_key.oceanic',
    baseCost: {'gold': 5},
    faction: 'oceanic',
  ),
  _MarketItem(
    id: 'market.key.verdant',
    name: 'Verdant Portal Key',
    description: 'Grants entry into a Verdant Rift. Consumed on entry.',
    icon: AppIcons.vpn_key_rounded,
    iconColor: Color(0xFF66BB6A),
    inventoryKey: 'item.portal_key.verdant',
    baseCost: {'gold': 5},
    faction: 'verdant',
  ),
  _MarketItem(
    id: 'market.key.earthen',
    name: 'Earthen Portal Key',
    description: 'Grants entry into an Earthen Rift. Consumed on entry.',
    icon: AppIcons.vpn_key_rounded,
    iconColor: Color(0xFF8D6E63),
    inventoryKey: 'item.portal_key.earthen',
    baseCost: {'gold': 5},
    faction: 'earthen',
  ),
  _MarketItem(
    id: 'market.key.arcane',
    name: 'Arcane Portal Key',
    description: 'Grants entry into an Arcane Rift. Consumed on entry.',
    icon: AppIcons.vpn_key_rounded,
    iconColor: Color(0xFFCE93D8),
    inventoryKey: 'item.portal_key.arcane',
    baseCost: {'gold': 5},
    faction: 'arcane',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// PANEL
// ─────────────────────────────────────────────────────────────────────────────

class SpaceMarketSheet extends StatefulWidget {
  final POIType marketType;
  final ElementMeter meter;
  final int carriedShards;
  final bool Function(int amount) spendShards;

  const SpaceMarketSheet({
    super.key,
    required this.marketType,
    required this.meter,
    required this.carriedShards,
    required this.spendShards,
  });

  /// Open the shop over the world.
  static Future<void> show(
    BuildContext context, {
    required POIType marketType,
    required ElementMeter meter,
    required int carriedShards,
    required bool Function(int amount) spendShards,
  }) => showStationPanel<void>(
    context,
    SpaceMarketSheet(
      marketType: marketType,
      meter: meter,
      carriedShards: carriedShards,
      spendShards: spendShards,
    ),
  );

  @override
  State<SpaceMarketSheet> createState() => _SpaceMarketSheetState();
}

class _SpaceMarketSheetState extends State<SpaceMarketSheet> {
  late final bool _harvester = widget.marketType == POIType.harvesterMarket;
  late final List<_MarketItem> _items = _harvester
      ? _harvesterItems
      : _riftKeyItems;
  late final StationKind _kind = _harvester
      ? StationKind.harvester
      : StationKind.riftKey;
  late final Map<String, MarketDiscountRecipe> _recipes =
      MarketRecipeTable.generate(
        items: [
          for (final i in _items)
            MarketItemEntry(key: i.inventoryKey, faction: i.faction),
        ],
      );
  late int _carriedShards = widget.carriedShards;
  Map<String, int> _owned = const {};
  int _selected = 0;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _loadOwned();
  }

  Future<void> _loadOwned() async {
    final db = context.read<AlchemonsDatabase>();
    final owned = <String, int>{};
    for (final i in _items) {
      owned[i.inventoryKey] = await db.inventoryDao.getItemQty(i.inventoryKey);
    }
    if (mounted) setState(() => _owned = owned);
  }

  // ── pricing ──

  bool _factionDiscount(_MarketItem item) =>
      context.read<FactionService>().current?.name == item.faction;

  MarketDiscountRecipe? _recipe(_MarketItem item) =>
      _recipes[item.inventoryKey];

  bool _elementDiscount(_MarketItem item) {
    final r = _recipe(item);
    return r != null && r.qualifies(widget.meter.breakdown, widget.meter.total);
  }

  Map<String, int> _cost(_MarketItem item) {
    var cost = item.baseCost;
    if (_factionDiscount(item)) {
      cost = cost.map((k, v) => MapEntry(k, (v * 0.1).ceil()));
    }
    if (_elementDiscount(item)) {
      cost = cost.map((k, v) => MapEntry(k, (v * 0.5).ceil()));
    }
    return cost;
  }

  Set<String> _short(Map<String, int> cost, Map<String, int> wallet) => {
    for (final e in cost.entries)
      if ((e.key == 'shards' ? _carriedShards : wallet[e.key] ?? 0) < e.value)
        e.key,
  };

  /// The element that fills the most of the meter, and its share.
  (String, double)? get _meterLead {
    final total = widget.meter.total;
    if (total <= 0) return null;
    String? best;
    var most = 0.0;
    widget.meter.breakdown.forEach((el, v) {
      if (v > most) {
        most = v;
        best = el;
      }
    });
    return best == null ? null : (best!, most / total);
  }

  // ── buying ──

  Future<void> _buy(_MarketItem item, Map<String, int> wallet) async {
    if (_buying) return;
    final cost = _cost(item);
    final short = _short(cost, wallet);
    if (short.isNotEmpty) return;

    final shardCost = cost['shards'] ?? 0;
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _kind.accent,
      title: 'BUY ${item.name.toUpperCase()}?',
      message: shardCost > 0
          ? 'It goes to your inventory. $shardCost shards come out of the hold.'
          : 'It goes to your inventory.',
      amounts: [
        if ((cost['gold'] ?? 0) > 0) (CoinKind.gold, cost['gold']!),
        if ((cost['silver'] ?? 0) > 0) (CoinKind.silver, cost['silver']!),
      ],
      amountsLabel: 'YOU PAY',
      confirmLabel: 'BUY',
    );
    if (!ok || !mounted) return;

    setState(() => _buying = true);
    final db = context.read<AlchemonsDatabase>();
    final silver = cost['silver'] ?? 0;
    final gold = cost['gold'] ?? 0;
    // All or nothing: anything already taken is handed back if a later
    // part of the price cannot be paid.
    var paid = true;
    var tookSilver = false, tookGold = false;
    if (silver > 0) {
      paid = tookSilver = await db.currencyDao.spendSilver(silver);
    }
    if (paid && gold > 0) {
      paid = tookGold = await db.currencyDao.spendGold(gold);
    }
    if (paid && shardCost > 0) {
      paid = widget.spendShards(shardCost);
      if (paid) _carriedShards -= shardCost;
    }
    if (!paid) {
      if (tookSilver) await db.currencyDao.addSilver(silver);
      if (tookGold) await db.currencyDao.addGold(gold);
      if (mounted) {
        setState(() => _buying = false);
        showGameSnack(
          context,
          'Not enough to pay for that.',
          accent: CosmicScreenStyles.danger,
        );
      }
      return;
    }

    await db.inventoryDao.addItemQty(item.inventoryKey, 1);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    setState(() {
      _buying = false;
      _owned = {
        ..._owned,
        item.inventoryKey: (_owned[item.inventoryKey] ?? 0) + 1,
      };
    });
    showGameSnack(
      context,
      '${item.name} acquired.',
      accent: CosmicScreenStyles.success,
    );
  }

  // ── layout ──

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final wallet = snap.data ?? const <String, int>{};
        final item = _items[_selected];
        return StationPanel(
          kind: _kind,
          highlight: item.dock,
          caption: _harvester
              ? 'FIVE HARVESTERS DOCKED · ONE FOR EACH GROUP'
              : 'FIVE KEYS · ONE FOR EACH RIFT',
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            children: [
              StationWallet(
                gold: wallet['gold'] ?? 0,
                silver: wallet['silver'] ?? 0,
                shards: _carriedShards,
              ),
              const SizedBox(height: 14),
              const PanelSectionHeader('TODAY'),
              ..._today(),
              const SizedBox(height: 8),
              PanelSectionHeader(_harvester ? 'HARVESTERS' : 'PORTAL KEYS'),
              for (var i = 0; i < _items.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _row(i, wallet),
              ],
            ],
          ),
          dock: _dockFor(item, wallet),
        );
      },
    );
  }

  List<Widget> _today() {
    final faction = context.read<FactionService>().current;
    final lead = _meterLead;
    return [
      StationNote(
        lead == null
            ? 'Your meter is empty. Each item is half price while its '
                  'element makes up half your meter or more.'
            : 'Your meter is ${(lead.$2 * 100).round()}% ${lead.$1}. Each '
                  'item is half price while its element makes up half your '
                  'meter or more.',
      ),
      if (faction != null)
        StationNote(
          'Your faction’s own goods are 90% off, on top of that.',
          color: CosmicScreenStyles.success,
        ),
    ];
  }

  Widget _glyph(_MarketItem item, double size) {
    final harvester = harvesterBiomeForKey(item.inventoryKey);
    if (harvester != null) {
      return HarvesterGlyph(biomeId: harvester, size: size, animate: false);
    }
    final key = PortalKeyGlyph.biomeForInventoryKey(item.inventoryKey);
    if (key != null) {
      return PortalKeyGlyph(biomeId: key, size: size, animate: false);
    }
    return Icon(item.icon, color: item.iconColor, size: size * 0.6);
  }

  /// What applies to [item] today, in a few words.
  String _status(_MarketItem item) {
    final parts = <String>[];
    final owned = _owned[item.inventoryKey] ?? 0;
    if (owned > 0) parts.add('$owned OWNED');
    if (_factionDiscount(item)) parts.add('YOUR FACTION · 90% OFF');
    final r = _recipe(item);
    if (r != null) {
      final el = r.requiredElement.toUpperCase();
      parts.add(
        _elementDiscount(item) ? 'HALF PRICE · $el' : 'HALF PRICE WITH $el',
      );
    }
    return parts.join('   ');
  }

  Widget _row(int i, Map<String, int> wallet) {
    final item = _items[i];
    final cost = _cost(item);
    final discounted = _factionDiscount(item) || _elementDiscount(item);
    final active = discounted;
    return StationRow(
      accent: _kind.accent,
      selected: i == _selected,
      onTap: () => setState(() => _selected = i),
      child: Row(
        children: [
          SizedBox(width: 38, height: 38, child: _glyph(item, 38)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.toUpperCase(),
                  style: panelLabel(11.5, panelPalette.ink, spacing: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  _status(item),
                  maxLines: 2,
                  style: panelLabel(
                    9.5,
                    active ? CosmicScreenStyles.success : panelPalette.muted,
                    spacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StationPrice(
            cost: cost,
            was: discounted ? item.baseCost : null,
            short: _short(cost, wallet),
          ),
        ],
      ),
    );
  }

  Widget _dockFor(_MarketItem item, Map<String, int> wallet) {
    final cost = _cost(item);
    final short = _short(cost, wallet);
    final label = short.isEmpty
        ? 'BUY'
        : 'NOT ENOUGH ${short.map((k) => k.toUpperCase()).join(' OR ')}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          item.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CosmicScreenStyles.textSecondary,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 10),
        BracketButton(
          key: const ValueKey('station.buy'),
          label: label,
          icon: AppIcons.shopping_bag_rounded,
          palette: panelPalette,
          accent: _kind.accent,
          enabled: short.isEmpty && !_buying,
          trailing: StationPrice(cost: cost, size: 10.5),
          onTap: () => _buy(item, wallet),
        ),
      ],
    );
  }
}
