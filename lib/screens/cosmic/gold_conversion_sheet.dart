// lib/screens/cosmic/gold_conversion_sheet.dart
//
// The Gold Conversion station: a crucible pouring gold into a sphere that
// gives off astral shards. Two trades:
//
//   • gold into something — 5 gold makes 50 astral shards (into the hold)
//     or 500 of one elemental matter (into home storage);
//   • matter for silver — 1 silver a unit, 5 for today's matter.
//
// A full panel in the station-screen kit. The amounts are held to what the
// wallet, the hold and the store can actually cover.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/station_art.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/screens/cosmic/widgets/station_panel_kit.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

int goldConversionDailyElementIndex(DateTime dateUtc) {
  final daySeed = dateUtc.toUtc().millisecondsSinceEpoch ~/ 86400000;
  return daySeed % ElementResources.all.length;
}

ElementResource goldConversionDailyElement(DateTime dateUtc) =>
    ElementResources.all[goldConversionDailyElementIndex(dateUtc)];

int goldConversionSilverPayout({
  required String resourceBiomeId,
  required int quantity,
  required DateTime dateUtc,
}) {
  final isDaily =
      goldConversionDailyElement(dateUtc).biomeId == resourceBiomeId;
  final rate = isDaily ? 5 : 1;
  return quantity * rate;
}

class GoldConversionSheet extends StatefulWidget {
  final int carriedShards;
  final int shardCapacity;
  final void Function(int amount) addShards;

  const GoldConversionSheet({
    super.key,
    required this.carriedShards,
    required this.shardCapacity,
    required this.addShards,
  });

  static Future<void> show(
    BuildContext context, {
    required int carriedShards,
    required int shardCapacity,
    required void Function(int amount) addShards,
  }) => showStationPanel<void>(
    context,
    GoldConversionSheet(
      carriedShards: carriedShards,
      shardCapacity: shardCapacity,
      addShards: addShards,
    ),
  );

  @override
  State<GoldConversionSheet> createState() => _GoldConversionSheetState();
}

class _GoldConversionSheetState extends State<GoldConversionSheet> {
  static const _accent = Color(0xFFFFD34A);
  static const _goldPer = 5; // gold per step
  static const _matterPer = 500; // matter per step
  static const _shardsPer = 50; // shards per step

  late int _carriedShards = widget.carriedShards;
  final ElementResource _daily = goldConversionDailyElement(DateTime.now());

  int _tab = 0;

  /// What the gold becomes: null for shards, else a matter's biome id.
  String? _into;
  int _steps = 1;

  late String _sellId = _daily.biomeId;
  int _sellQty = 100;
  bool _busy = false;

  ElementResource _res(String id) =>
      ElementResources.all.firstWhere((r) => r.biomeId == id);

  // ── gold into something ──

  int _maxSteps(int gold) {
    var m = gold ~/ _goldPer;
    if (_into == null) {
      final space = widget.shardCapacity - _carriedShards;
      m = m < space ~/ _shardsPer ? m : space ~/ _shardsPer;
    }
    return m < 0 ? 0 : m;
  }

  String _blocked(int gold) {
    if (gold < _goldPer) return 'NEED $_goldPer GOLD';
    if (_into == null && widget.shardCapacity - _carriedShards < _shardsPer) {
      return 'THE HOLD IS FULL';
    }
    return '';
  }

  Future<void> _transmute(int steps) async {
    if (_busy || steps <= 0) return;
    final db = context.read<AlchemonsDatabase>();
    final gold = steps * _goldPer;
    final out = steps * (_into == null ? _shardsPer : _matterPer);
    final what = _into == null
        ? 'astral shards'
        : '${_res(_into!).biomeLabel.toLowerCase()} matter';
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _accent,
      title: 'TRANSMUTE $gold GOLD?',
      message: _into == null
          ? 'You get $out astral shards, into the hold.'
          : 'You get $out $what, into home storage.',
      amounts: [(CoinKind.gold, gold)],
      amountsLabel: 'YOU PAY',
      confirmLabel: 'TRANSMUTE',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final paid = await db.currencyDao.spendGold(gold);
    if (!paid) {
      if (mounted) {
        setState(() => _busy = false);
        showGameSnack(
          context,
          'Not enough gold.',
          accent: CosmicScreenStyles.danger,
        );
      }
      return;
    }
    if (_into == null) {
      widget.addShards(out);
      _carriedShards += out;
    } else {
      await db.currencyDao.addResource(_res(_into!).settingsKey, out);
    }
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    context.sound(SoundCue.currencyGain, owner: this);
    setState(() {
      _busy = false;
      _steps = 1;
    });
    showGameSnack(
      context,
      'Transmuted $gold gold into $out $what.',
      accent: CosmicScreenStyles.success,
    );
  }

  // ── matter for silver ──

  Future<void> _sell(int qty) async {
    if (_busy || qty <= 0) return;
    final db = context.read<AlchemonsDatabase>();
    final res = _res(_sellId);
    final payout = goldConversionSilverPayout(
      resourceBiomeId: _sellId,
      quantity: qty,
      dateUtc: DateTime.now(),
    );
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _accent,
      title: 'SELL $qty ${res.biomeLabel.toUpperCase()} MATTER?',
      message: res.biomeId == _daily.biomeId
          ? '${res.biomeLabel} is today’s matter: 5 silver a unit.'
          : 'It comes out of home storage at 1 silver a unit.',
      amounts: [(CoinKind.silver, payout)],
      confirmLabel: 'SELL',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final spent = await db.currencyDao.spendResources({res.settingsKey: qty});
    if (!spent) {
      if (mounted) {
        setState(() => _busy = false);
        showGameSnack(
          context,
          'Not enough ${res.biomeLabel.toLowerCase()} matter.',
          accent: CosmicScreenStyles.danger,
        );
      }
      return;
    }
    await db.currencyDao.addSilver(payout);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    context.sound(SoundCue.currencyGain, owner: this);
    setState(() => _busy = false);
    showGameSnack(
      context,
      'Sold $qty ${res.biomeLabel.toLowerCase()} matter for $payout silver.',
      accent: CosmicScreenStyles.success,
    );
  }

  // ── layout ──

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, cSnap) {
        final wallet = cSnap.data ?? const <String, int>{};
        return StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, rSnap) {
            final store = rSnap.data ?? const <String, int>{};
            final gold = wallet['gold'] ?? 0;
            return StationPanel(
              kind: StationKind.goldConversion,
              caption:
                  'TODAY’S MATTER · ${_daily.biomeLabel.toUpperCase()} · 5 SILVER A UNIT',
              body: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                children: [
                  StationWallet(
                    gold: gold,
                    silver: wallet['silver'] ?? 0,
                    shards: _carriedShards,
                    shardCapacity: widget.shardCapacity,
                  ),
                  const SizedBox(height: 12),
                  BracketTabs(
                    labels: const ['GOLD INTO…', 'MATTER FOR SILVER'],
                    selected: _tab,
                    onSelect: (i) => setState(() => _tab = i),
                    palette: panelPalette,
                    accent: _accent,
                  ),
                  const SizedBox(height: 14),
                  if (_tab == 0) ..._intoBody(gold) else ..._sellBody(store),
                ],
              ),
              dock: _tab == 0 ? _intoDock(gold) : _sellDock(store),
            );
          },
        );
      },
    );
  }

  Widget _glyphFor(String? id, double size) {
    if (id == null) {
      return Icon(
        CosmicScreenStyles.astralShardIcon,
        size: size * 0.62,
        color: CosmicScreenStyles.astralShardColor,
      );
    }
    final r = _res(id);
    return ElementResourceGlyph(
      biomeId: r.biomeId,
      color: r.color,
      size: size,
      animate: false,
    );
  }

  /// One choice in a grid of tiles: what it is, and a line under it.
  Widget _tile({
    required String? id,
    required String name,
    required String note,
    required bool selected,
    required VoidCallback onTap,
    Color? noteColor,
  }) {
    return StationRow(
      accent: _accent,
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Center(child: _glyphFor(id, 30)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: panelLabel(11, panelPalette.ink, spacing: 1)),
                const SizedBox(height: 3),
                Text(
                  note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: panelLabel(
                    9.5,
                    noteColor ?? panelPalette.muted,
                    spacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid(List<Widget> tiles) => Column(
    children: [
      for (var i = 0; i < tiles.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 6),
        PanelRow(
          gap: 6,
          children: [
            tiles[i],
            if (i + 1 < tiles.length) tiles[i + 1] else const SizedBox(),
          ],
        ),
      ],
    ],
  );

  List<Widget> _intoBody(int gold) {
    final max = _maxSteps(gold);
    final steps = max == 0 ? 0 : _steps.clamp(1, max);
    return [
      const PanelSectionHeader('MAKE'),
      _grid([
        _tile(
          id: null,
          name: 'ASTRAL SHARDS',
          note: '50 FOR 5 GOLD',
          selected: _into == null,
          onTap: () => setState(() {
            _into = null;
            _steps = 1;
          }),
        ),
        for (final r in ElementResources.all)
          _tile(
            id: r.biomeId,
            name: '${r.biomeLabel.toUpperCase()} MATTER',
            note: '500 FOR 5 GOLD',
            selected: _into == r.biomeId,
            onTap: () => setState(() {
              _into = r.biomeId;
              _steps = 1;
            }),
          ),
      ]),
      const SizedBox(height: 14),
      PanelSectionHeader(
        'GOLD',
        trailing: max == 0 ? null : 'UP TO ${max * _goldPer}',
      ),
      _stepper(
        value: '${steps * _goldPer}',
        unit: 'GOLD',
        canDown: steps > 1,
        canUp: steps < max,
        onDown: () => setState(() => _steps = steps - 1),
        onUp: () => setState(() => _steps = steps + 1),
      ),
      const SizedBox(height: 8),
      _presets([
        for (final g in const [5, 10, 25, 50, 100])
          if (g ~/ _goldPer <= max)
            ('$g', () => setState(() => _steps = g ~/ _goldPer)),
        if (max > 0) ('ALL', () => setState(() => _steps = max)),
      ]),
    ];
  }

  Widget _intoDock(int gold) {
    final max = _maxSteps(gold);
    final steps = max == 0 ? 0 : _steps.clamp(1, max);
    final out = steps * (_into == null ? _shardsPer : _matterPer);
    final what = _into == null
        ? 'SHARDS'
        : _res(_into!).biomeLabel.toUpperCase();
    final blocked = max == 0 ? _blocked(gold) : '';
    return BracketButton(
      key: const ValueKey('station.transmute'),
      label: blocked.isNotEmpty
          ? blocked
          : 'TRANSMUTE ${steps * _goldPer} GOLD → $out $what',
      palette: panelPalette,
      accent: _accent,
      enabled: blocked.isEmpty && !_busy,
      onTap: () => _transmute(steps),
    );
  }

  List<Widget> _sellBody(Map<String, int> store) {
    final held = store[_res(_sellId).settingsKey] ?? 0;
    final qty = held <= 0 ? 0 : _sellQty.clamp(1, held);
    return [
      const PanelSectionHeader('FROM HOME STORAGE'),
      _grid([
        for (final r in ElementResources.all)
          _tile(
            id: r.biomeId,
            name: r.biomeLabel.toUpperCase(),
            note: r.biomeId == _daily.biomeId
                ? '${formatCoins(store[r.settingsKey] ?? 0)} HELD · TODAY ×5'
                : '${formatCoins(store[r.settingsKey] ?? 0)} HELD',
            noteColor: r.biomeId == _daily.biomeId ? _accent : null,
            selected: _sellId == r.biomeId,
            onTap: () => setState(() => _sellId = r.biomeId),
          ),
      ]),
      const SizedBox(height: 14),
      PanelSectionHeader('AMOUNT', trailing: '${formatCoins(held)} HELD'),
      _stepper(
        value: formatCoins(qty),
        unit: 'UNITS',
        canDown: qty > 1,
        canUp: qty < held,
        onDown: () => setState(() => _sellQty = qty - 1),
        onUp: () => setState(() => _sellQty = qty + 1),
      ),
      const SizedBox(height: 8),
      _presets([
        for (final n in const [1, 10, 100, 1000])
          if (n <= held) (formatCoins(n), () => setState(() => _sellQty = n)),
        if (held > 0) ('ALL', () => setState(() => _sellQty = held)),
      ]),
    ];
  }

  Widget _sellDock(Map<String, int> store) {
    final res = _res(_sellId);
    final held = store[res.settingsKey] ?? 0;
    final qty = held <= 0 ? 0 : _sellQty.clamp(1, held);
    final payout = goldConversionSilverPayout(
      resourceBiomeId: _sellId,
      quantity: qty,
      dateUtc: DateTime.now(),
    );
    return BracketButton(
      key: const ValueKey('station.sellMatter'),
      label: held <= 0
          ? 'NO ${res.biomeLabel.toUpperCase()} MATTER IN STORAGE'
          : 'SELL ${formatCoins(qty)} ${res.biomeLabel.toUpperCase()}',
      palette: panelPalette,
      accent: _accent,
      enabled: held > 0 && !_busy,
      trailing: held > 0
          ? CoinAmount(kind: CoinKind.silver, amount: payout, size: 11)
          : null,
      onTap: () => _sell(qty),
    );
  }

  Widget _stepper({
    required String value,
    required String unit,
    required bool canDown,
    required bool canUp,
    required VoidCallback onDown,
    required VoidCallback onUp,
  }) {
    Widget step(IconData icon, bool on, VoidCallback tap) => Opacity(
      opacity: on ? 1 : 0.3,
      child: BracketIconButton(
        icon: icon,
        onTap: on ? tap : () {},
        palette: panelPalette,
        color: _accent,
      ),
    );
    return Row(
      children: [
        step(AppIcons.remove_rounded, canDown, onDown),
        Expanded(
          child: Column(
            children: [
              Text(value, style: panelLabel(22, panelPalette.ink, spacing: 1)),
              Text(
                unit,
                style: panelLabel(9, panelPalette.muted, spacing: 1.6),
              ),
            ],
          ),
        ),
        step(AppIcons.add_rounded, canUp, onUp),
      ],
    );
  }

  Widget _presets(List<(String, VoidCallback)> presets) => Wrap(
    spacing: 6,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      for (final (label, tap) in presets)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            tap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: panelPalette.line),
              color: panelPalette.bg1,
            ),
            child: Text(label, style: panelLabel(10.5, panelPalette.ink)),
          ),
        ),
    ],
  );
}
