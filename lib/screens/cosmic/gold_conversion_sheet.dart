// lib/screens/cosmic/gold_conversion_sheet.dart
//
// The Gold Conversion station: a crucible pouring gold into a sphere that
// gives off astral shards. Two trades:
//
//   • gold into something — 5 gold makes 50 astral shards (into the hold)
//     or 500 of one essence (into home storage);
//   • essence for silver — 1 silver a unit, 5 for today's essence.
//
// Essence, not matter: these are the five the Essence chambers collect at
// home, and in space "matter" is what the ship gathers from nebulas
// (user 2026-10-22: the panel should say what it actually does).
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

/// Today's essence, the one that sells for 5 silver: it turns over on
/// [date]'s own calendar day, so a phone's "today" ends at its midnight.
int goldConversionDailyElementIndex(DateTime date) {
  final daySeed =
      DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      86400000;
  return daySeed % ElementResources.all.length;
}

ElementResource goldConversionDailyElement(DateTime date) =>
    ElementResources.all[goldConversionDailyElementIndex(date)];

int goldConversionSilverPayout({
  required String resourceBiomeId,
  required int quantity,
  required DateTime date,
}) {
  final isDaily = goldConversionDailyElement(date).biomeId == resourceBiomeId;
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
  static const _essencePer = 500; // essence per step
  static const _shardsPer = 50; // shards per step

  late int _carriedShards = widget.carriedShards;

  /// The day the panel was opened on: what it shows as today's essence is
  /// what a sale pays, even past midnight.
  final DateTime _today = DateTime.now();
  late final ElementResource _daily = goldConversionDailyElement(_today);

  int _tab = 0;

  /// What the gold becomes: null for shards, else an essence's biome id.
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

  /// Whether the hold, not the gold, is what caps the shards made.
  bool _holdCaps(int gold) =>
      _into == null &&
      (widget.shardCapacity - _carriedShards) ~/ _shardsPer < gold ~/ _goldPer;

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
    final out = steps * (_into == null ? _shardsPer : _essencePer);
    final what = _into == null
        ? 'astral shards'
        : '${_res(_into!).biomeLabel.toLowerCase()} essence';
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _accent,
      title: 'TRANSMUTE ${formatCoins(gold)} GOLD?',
      message: _into == null
          ? 'You get ${formatCoins(out)} astral shards, into the hold.'
          : 'You get ${formatCoins(out)} $what, into home storage.',
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
      'Transmuted ${formatCoins(gold)} gold into ${formatCoins(out)} $what.',
      accent: CosmicScreenStyles.success,
    );
  }

  // ── essence for silver ──

  Future<void> _sell(int qty) async {
    if (_busy || qty <= 0) return;
    final db = context.read<AlchemonsDatabase>();
    final res = _res(_sellId);
    final payout = goldConversionSilverPayout(
      resourceBiomeId: _sellId,
      quantity: qty,
      date: _today,
    );
    final ok = await showBracketConfirm(
      context,
      palette: panelPalette,
      accent: _accent,
      title:
          'SELL ${formatCoins(qty)} ${res.biomeLabel.toUpperCase()} ESSENCE?',
      message: res.biomeId == _daily.biomeId
          ? '${res.biomeLabel} is today’s essence: 5 silver a unit, from '
                'home storage.'
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
          'Not enough ${res.biomeLabel.toLowerCase()} essence.',
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
      'Sold ${formatCoins(qty)} ${res.biomeLabel.toLowerCase()} essence for '
      '${formatCoins(payout)} silver.',
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
                  'TODAY · ${_daily.biomeLabel.toUpperCase()} · 5 SILVER A UNIT',
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
                    labels: const ['SPEND GOLD', 'SELL ESSENCE'],
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

  /// One choice in a grid of tiles: what it is, and a line under it. Each
  /// stays on one line, drawn smaller on a narrow phone rather than wrapped
  /// or cut, so the tiles in a row stay level.
  Widget _tile({
    required String? id,
    required String name,
    required String note,
    required bool selected,
    required VoidCallback onTap,
    String? tag,
    Color? noteColor,
  }) {
    Widget line(Widget text) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: text,
    );
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
                line(
                  Text.rich(
                    TextSpan(
                      text: name,
                      children: [
                        if (tag != null)
                          TextSpan(
                            text: ' $tag',
                            style: panelLabel(11, _accent, spacing: 1),
                          ),
                      ],
                    ),
                    style: panelLabel(11, panelPalette.ink, spacing: 1),
                  ),
                ),
                const SizedBox(height: 3),
                line(
                  Text(
                    note,
                    style: panelLabel(
                      9.5,
                      noteColor ?? panelPalette.muted,
                      spacing: 0.6,
                    ),
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
      PanelSectionHeader(
        'MAKE',
        trailing: _into == null ? 'INTO THE HOLD' : 'TO HOME STORAGE',
      ),
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
            name: r.biomeLabel.toUpperCase(),
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
        trailing: max == 0
            ? null
            : _holdCaps(gold)
            ? 'UP TO ${formatCoins(max * _goldPer)} · HOLD LIMIT'
            : 'UP TO ${formatCoins(max * _goldPer)}',
      ),
      _stepper(
        value: formatCoins(steps * _goldPer),
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
    final out = steps * (_into == null ? _shardsPer : _essencePer);
    final what = _into == null
        ? 'SHARDS'
        : _res(_into!).biomeLabel.toUpperCase();
    final blocked = max == 0 ? _blocked(gold) : '';
    // What it makes on the button, what it costs after it: the whole trade
    // fits on a phone's width.
    return BracketButton(
      key: const ValueKey('station.transmute'),
      label: blocked.isNotEmpty ? blocked : 'MAKE ${formatCoins(out)} $what',
      palette: panelPalette,
      accent: _accent,
      enabled: blocked.isEmpty && !_busy,
      trailing: blocked.isEmpty
          ? CoinAmount(kind: CoinKind.gold, amount: steps * _goldPer, size: 11)
          : null,
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
            tag: r.biomeId == _daily.biomeId ? '×5' : null,
            note: '${formatCoins(store[r.settingsKey] ?? 0)} HELD',
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
      date: _today,
    );
    return BracketButton(
      key: const ValueKey('station.sellMatter'),
      label: held <= 0
          ? 'NO ${res.biomeLabel.toUpperCase()} ESSENCE AT HOME'
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
