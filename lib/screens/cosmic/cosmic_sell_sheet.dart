// lib/screens/cosmic/cosmic_sell_sheet.dart
//
// The Cosmic Market station: sell Alchemons summoned from planets, and
// prismatic ones. A full panel in the station-screen kit — the market on its
// stage (a capsule lit for the one you are looking at), what it pays today,
// your sellable Alchemons, and one SELL at the foot.
//
// What a specimen fetches, in "gold base" units:
//   rarity (common 5, uncommon 10, rare 15, mythic/mystic/legendary 20,
//   variant 25), +10 if prismatic, ×1.5 if planet-summoned, × its nature
//   and potential multipliers, × a 0.8–1.2 market swing that is fixed for a
//   specimen for the day, clamped to 1–999. Today's species pays double.
// Paid as:
//   prismatic → gold, ceil(base / 12) clamped 1–6, ×5;
//   otherwise → silver, base × 50; or astral shards, base × 5, into the
//   hold (offered only when the hold has room).
//
// Alchemons that are locked, out with the party or stationed at home are
// never offered.

import 'dart:math';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/black_market_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/screens/cosmic/widgets/station_panel_kit.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const _kSellRewardMultiplier = 5;

/// Base gold value by rarity.
int _baseGoldForRarity(String rarity) => switch (rarity.toLowerCase()) {
  'common' => 5,
  'uncommon' => 10,
  'rare' => 15,
  'mythic' || 'mystic' || 'legendary' => 20,
  'variant' => 25,
  _ => 5,
};

/// Planet → the element its summons carry.
const Map<String, String> _kPlanetElement = {
  'Pyrathis': 'Fire',
  'Magmora': 'Lava',
  'Voltara': 'Lightning',
  'Aquathos': 'Water',
  'Glaceron': 'Ice',
  'Vaporis': 'Steam',
  'Terragrim': 'Earth',
  'Mireholm': 'Mud',
  'Cindrath': 'Dust',
  'Lumishara': 'Crystal',
  'Zephyria': 'Air',
  'Verdanthos': 'Plant',
  'Toxivyre': 'Poison',
  'Etherion': 'Spirit',
  'Nythralor': 'Dark',
  'Solanthis': 'Light',
  'Hemavorn': 'Blood',
};

/// The UTC day number, which seeds everything that changes daily here.
int _today() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000;

/// FNV-1a over [s] — stable from run to run, unlike String.hashCode.
int _stableHash(String s) {
  var h = 0x811C9DC5;
  for (final c in s.codeUnits) {
    h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

enum _Pay { silver, shards }

class _Sellable {
  _Sellable({
    required this.instance,
    required this.creature,
    required this.basePrice,
    required this.doubled,
  });
  final CreatureInstance instance;
  final Creature creature;
  final int basePrice;
  final bool doubled;

  bool get prismatic => instance.isPrismaticSkin;
  String get name => (instance.nickname?.isNotEmpty ?? false)
      ? instance.nickname!
      : creature.name;
}

class CosmicSellSheet extends StatefulWidget {
  const CosmicSellSheet({
    super.key,
    this.carriedShards = 0,
    this.shardCapacity = 0,
    this.addShards,
  });

  /// The hold, for paying in shards. Without [addShards] the market pays
  /// silver (and gold, for prismatics) only.
  final int carriedShards;
  final int shardCapacity;
  final void Function(int amount)? addShards;

  static Future<void> show(
    BuildContext context, {
    int carriedShards = 0,
    int shardCapacity = 0,
    void Function(int amount)? addShards,
  }) => showStationPanel<void>(
    context,
    CosmicSellSheet(
      carriedShards: carriedShards,
      shardCapacity: shardCapacity,
      addShards: addShards,
    ),
  );

  @override
  State<CosmicSellSheet> createState() => _CosmicSellSheetState();
}

class _CosmicSellSheetState extends State<CosmicSellSheet> {
  static const _accent = Color(0xFF3FE0F0);

  List<_Sellable> _all = [];
  bool _loading = true;
  _Pay _pay = _Pay.silver;
  bool _prismaticOnly = false;
  String? _planet;
  String? _selectedId;
  Creature? _todaysSpecies;
  late int _carriedShards = widget.carriedShards;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final instances = await db.creatureDao.getAllInstances();
    final away = {
      ...(await db.settingsDao.getCosmicPartySlots()).whereType<String>(),
      ...(await db.settingsDao.getCosmicGarrisonSlots()).whereType<String>(),
    };
    final day = _today();

    final eligible = [
      for (final i in instances)
        if ((i.source == 'planet_summon' || i.isPrismaticSkin) &&
            !i.locked &&
            !away.contains(i.instanceId) &&
            repo.getCreatureById(i.baseId) != null)
          i,
    ];

    // Today's species is one you could actually sell.
    final species = {for (final i in eligible) i.baseId}.toList()..sort();
    final todays = species.isEmpty
        ? null
        : species[Random(day ^ 0xC057).nextInt(species.length)];

    final list = <_Sellable>[];
    for (final inst in eligible) {
      final base = repo.getCreatureById(inst.baseId)!;
      final raw =
          ((_baseGoldForRarity(base.rarity) + (inst.isPrismaticSkin ? 10 : 0)) *
                  (inst.source == 'planet_summon' ? 1.5 : 1.0) *
                  BlackMarketConstants.natureValueMultiplier(
                    inst.natureId,
                    inst.natureId2,
                  ) *
                  BlackMarketConstants.potentialValueMultiplier(
                    BlackMarketConstants.averagePotential(
                      speed: inst.statSpeedPotential,
                      intelligence: inst.statIntelligencePotential,
                      strength: inst.statStrengthPotential,
                      beauty: inst.statBeautyPotential,
                    ),
                  ))
              .round();
      // The day's swing, the same each time the market is opened.
      final swing =
          0.8 + Random(_stableHash(inst.instanceId) ^ day).nextDouble() * 0.4;
      var price = (raw * swing).round().clamp(1, 999);
      final doubled = inst.baseId == todays;
      if (doubled) price *= 2;
      list.add(
        _Sellable(
          instance: inst,
          creature: base,
          basePrice: price,
          doubled: doubled,
        ),
      );
    }
    list.sort((a, b) {
      if (a.doubled != b.doubled) return a.doubled ? -1 : 1;
      return b.basePrice.compareTo(a.basePrice);
    });

    if (!mounted) return;
    setState(() {
      _all = list;
      _todaysSpecies = todays == null ? null : repo.getCreatureById(todays);
      _selectedId = list.isEmpty ? null : list.first.instance.instanceId;
      _loading = false;
    });
  }

  List<_Sellable> get _shown => [
    for (final s in _all)
      if ((!_prismaticOnly || s.prismatic) &&
          (_planet == null ||
              s.creature.types.contains(_kPlanetElement[_planet])))
        s,
  ];

  /// What [s] pays, and in what.
  (String, int) _payout(_Sellable s) {
    if (s.prismatic) {
      return (
        'gold',
        (s.basePrice / 12).ceil().clamp(1, 6) * _kSellRewardMultiplier,
      );
    }
    return _pay == _Pay.silver
        ? ('silver', s.basePrice * 10 * _kSellRewardMultiplier)
        : ('shards', s.basePrice * 5);
  }

  int get _holdSpace => widget.shardCapacity - _carriedShards;

  Future<void> _sell(_Sellable s) async {
    if (_busy) return;
    final (currency, amount) = _payout(s);
    if (currency == 'shards' && amount > _holdSpace) return;
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _accent,
      title: 'SELL ${s.name.toUpperCase()}?',
      message: currency == 'shards'
          ? 'It leaves your collection for good. $amount astral shards go '
                'into the hold.'
          : 'It leaves your collection for good.',
      amounts: [
        if (currency == 'gold') (CoinKind.gold, amount),
        if (currency == 'silver') (CoinKind.silver, amount),
      ],
      warning: s.prismatic ? 'This one is prismatic.' : null,
      confirmLabel: 'SELL',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final db = context.read<AlchemonsDatabase>();
    await db.creatureDao.deleteInstances([s.instance.instanceId]);
    switch (currency) {
      case 'gold':
        await db.currencyDao.addGold(amount);
      case 'silver':
        await db.currencyDao.addSilver(amount);
      default:
        widget.addShards?.call(amount);
        _carriedShards += amount;
    }
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    context.sound(SoundCue.currencyGain, owner: this);
    final next = _shown.where((x) => x != s).toList();
    setState(() {
      _busy = false;
      _all = [..._all]..remove(s);
      _selectedId = next.isEmpty ? null : next.first.instance.instanceId;
    });
    showGameSnack(
      context,
      'Sold ${s.name} for $amount ${currency == 'shards' ? 'astral shards' : currency}.',
      accent: CosmicScreenStyles.success,
    );
  }

  // ── layout ──

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final shown = _shown;
    final selected = shown
        .where((s) => s.instance.instanceId == _selectedId)
        .firstOrNull;
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final wallet = snap.data ?? const <String, int>{};
        return StationPanel(
          kind: StationKind.market,
          highlight: selected == null ? null : shown.indexOf(selected) % 4,
          caption: _todaysSpecies == null
              ? 'FOUR BERTHS · PLANET-SUMMONED AND PRISMATIC ONLY'
              : 'PAYING DOUBLE TODAY · ${_todaysSpecies!.name.toUpperCase()}',
          body: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 1.5,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  children: [
                    StationWallet(
                      gold: wallet['gold'] ?? 0,
                      silver: wallet['silver'] ?? 0,
                      shards: _carriedShards,
                      shardCapacity: widget.addShards == null
                          ? null
                          : widget.shardCapacity,
                    ),
                    const SizedBox(height: 14),
                    const PanelSectionHeader('TODAY'),
                    StationNote(
                      _todaysSpecies == null
                          ? 'The market buys Alchemons summoned from planets, '
                                'and prismatic ones. Prismatics pay in gold.'
                          : 'The market pays double for '
                                '${_todaysSpecies!.name} today. Prismatics '
                                'always pay in gold.',
                    ),
                    if (widget.addShards != null) ...[
                      const SizedBox(height: 6),
                      BracketTabs(
                        labels: const ['PAY IN SILVER', 'PAY IN SHARDS'],
                        selected: _pay.index,
                        onSelect: (i) => setState(() => _pay = _Pay.values[i]),
                        palette: panelPalette,
                        accent: _accent,
                      ),
                    ],
                    const SizedBox(height: 14),
                    PanelSectionHeader(
                      'FOR SALE',
                      trailing: '${shown.length} OF ${_all.length}',
                    ),
                    if (_all.isNotEmpty) _filters(),
                    if (_all.isEmpty)
                      const StationNote(
                        'Nothing to sell. Alchemons summoned from planets, '
                        'and prismatic ones, can be sold here once they are '
                        'not locked, out with your party or stationed at home.',
                      )
                    else if (shown.isEmpty)
                      const StationNote('Nothing matches this filter.')
                    else
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        _row(shown[i]),
                      ],
                  ],
                ),
          dock: _dockFor(selected),
        );
      },
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: CustomPaint(
      foregroundPainter: on
          ? BracketFramePainter(color: _accent, bracketSize: 5)
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? _accent.withValues(alpha: 0.1) : panelPalette.bg1,
          border: on ? null : Border.all(color: panelPalette.lineSoft),
        ),
        child: Text(
          label,
          style: panelLabel(10, on ? panelPalette.ink : panelPalette.muted),
        ),
      ),
    ),
  );

  Widget _filters() {
    final planets = [
      for (final e in _kPlanetElement.entries)
        if (_all.any((s) => s.creature.types.contains(e.value))) e.key,
    ];
    final anyPrismatic = _all.any((s) => s.prismatic);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _chip(
            'ALL',
            !_prismaticOnly && _planet == null,
            () => setState(() {
              _prismaticOnly = false;
              _planet = null;
            }),
          ),
          if (anyPrismatic)
            _chip(
              'PRISMATIC',
              _prismaticOnly,
              () => setState(() => _prismaticOnly = !_prismaticOnly),
            ),
          for (final p in planets)
            _chip(
              p.toUpperCase(),
              _planet == p,
              () => setState(() => _planet = _planet == p ? null : p),
            ),
        ],
      ),
    );
  }

  Widget _row(_Sellable s) {
    final (currency, amount) = _payout(s);
    final tooMany = currency == 'shards' && amount > _holdSpace;
    final tags = [
      'LV ${s.instance.level}',
      s.creature.rarity.toUpperCase(),
      if (s.prismatic) 'PRISMATIC',
      if (s.doubled) 'DOUBLE TODAY',
    ];
    return GestureDetector(
      onLongPress: () => CreatureDetailsDialog.show(
        context,
        s.creature,
        true,
        instanceId: s.instance.instanceId,
      ),
      child: StationRow(
        accent: _accent,
        selected: s.instance.instanceId == _selectedId,
        onTap: () => setState(() => _selectedId = s.instance.instanceId),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: s.creature.spriteData == null
                  ? Icon(AppIcons.pets_rounded, color: panelPalette.muted)
                  : InstanceSprite(
                      creature: s.creature,
                      instance: s.instance,
                      size: 44,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: panelLabel(11.5, panelPalette.ink, spacing: 1),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tags.join('   '),
                    style: panelLabel(
                      9.5,
                      s.doubled || s.prismatic
                          ? CosmicScreenStyles.success
                          : panelPalette.muted,
                      spacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            StationPrice(
              cost: {currency: amount},
              short: tooMany ? {currency} : const {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _dockFor(_Sellable? s) {
    if (s == null) {
      return BracketButton(
        label: 'NOTHING TO SELL',
        onTap: null,
        enabled: false,
        palette: panelPalette,
        accent: _accent,
      );
    }
    final (currency, amount) = _payout(s);
    final noRoom = currency == 'shards' && amount > _holdSpace;
    return BracketButton(
      key: const ValueKey('station.sell'),
      label: noRoom
          ? 'THE HOLD HAS ROOM FOR ${max(0, _holdSpace)}'
          : 'SELL ${s.name.toUpperCase()}',
      icon: AppIcons.sell_rounded,
      palette: panelPalette,
      accent: _accent,
      enabled: !noRoom && !_busy,
      trailing: noRoom
          ? null
          : StationPrice(cost: {currency: amount}, size: 10.5),
      onTap: () => _sell(s),
    );
  }
}
