// lib/screens/cosmic/gold_conversion_sheet.dart
//
// Gold Conversion Market — convert gold into alchemical particles or
// astral shards.
//
//   • 5 gold → 500 of any chosen element particle
//   • 5 gold → 50 astral shards
//   Minimum 5 gold per transaction. Increments of 5.

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GoldConversionSheet(
        carriedShards: carriedShards,
        shardCapacity: shardCapacity,
        addShards: addShards,
      ),
    );
  }

  @override
  State<GoldConversionSheet> createState() => _GoldConversionSheetState();
}

class _GoldConversionSheetState extends State<GoldConversionSheet> {
  static const _accent = Color(0xFFFFD740);
  static const _goldPer = 5; // gold per increment
  static const _particlesPer = 500; // particles per increment
  static const _shardsPer = 50; // shards per increment

  int _multiplier = 1; // increments of 5 gold

  // null = shards, otherwise the biomeId
  String? _selectedResource;
  bool _isShardsMode = true;
  late final ElementResource _dailySaleResource;
  String? _selectedSellResource;
  int _sellQuantity = 100;

  late int _carriedShards;

  @override
  void initState() {
    super.initState();
    _carriedShards = widget.carriedShards;
    _dailySaleResource = goldConversionDailyElement(DateTime.now().toUtc());
    _selectedSellResource = _dailySaleResource.biomeId;
  }

  int get _goldCost => _goldPer * _multiplier;
  int get _outputAmount =>
      _isShardsMode ? _shardsPer * _multiplier : _particlesPer * _multiplier;

  String get _outputLabel {
    if (_isShardsMode) return 'Astral Shards';
    final res = ElementResources.byBiomeId[_selectedResource];
    return '${res?.biomeLabel ?? 'Unknown'} Particles';
  }

  ElementResource get _selectedSellElement =>
      ElementResources.byBiomeId[_selectedSellResource] ?? _dailySaleResource;

  int _sellSilverPayoutFor(String resourceBiomeId, int quantity) =>
      goldConversionSilverPayout(
        resourceBiomeId: resourceBiomeId,
        quantity: quantity,
        dateUtc: DateTime.now().toUtc(),
      );

  void _showConversionToast(String message, {required bool success}) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final tone = success ? const Color(0xFF22C55E) : const Color(0xFFC0392B);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: const Duration(seconds: 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tone.withValues(alpha: 0.65)),
          ),
          child: Row(
            children: [
              Icon(
                success
                    ? AppIcons.check_circle_rounded
                    : AppIcons.warning_amber_rounded,
                size: 16,
                color: tone,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _convert() async {
    final db = context.read<AlchemonsDatabase>();
    final gold = await db.currencyDao.getGoldBalance();
    if (gold < _goldCost) {
      _showError('Not enough gold');
      return;
    }

    if (_isShardsMode) {
      // Check shard capacity
      final spaceLeft = widget.shardCapacity - _carriedShards;
      if (spaceLeft < _outputAmount) {
        _showError(
          spaceLeft <= 0
              ? 'Shard wallet is full'
              : 'Only $spaceLeft shard capacity remaining',
        );
        return;
      }
    }

    final confirmed = await _confirmConversion();
    if (!confirmed) return;

    final ok = await db.currencyDao.spendGold(_goldCost);
    if (!ok) return;

    if (_isShardsMode) {
      widget.addShards(_outputAmount);
      _carriedShards += _outputAmount;
    } else {
      final key = ElementResources.keyForBiome(_selectedResource!);
      await db.currencyDao.addResource(key, _outputAmount);
    }

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    _showConversionToast(
      'Converted $_goldCost gold into $_outputAmount $_outputLabel.',
      success: true,
    );
    setState(() {});
  }

  void _showError(String msg) {
    if (!mounted) return;
    _showConversionToast(msg, success: false);
  }

  Future<bool> _confirmConversion() async {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _accent.withValues(alpha: 0.55)),
        ),
        title: Text(
          'CONFIRM CONVERSION',
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: t.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const CoinIcon(kind: CoinKind.gold, size: 18),
                const SizedBox(width: 6),
                Text('$_goldCost Gold', style: TextStyle(color: t.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            const Icon(
              AppIcons.arrow_downward_rounded,
              size: 20,
              color: Colors.white38,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isShardsMode
                      ? CosmicScreenStyles.astralShardIcon
                      : ElementResources.byBiomeId[_selectedResource]?.icon ??
                            AppIcons.circle,
                  size: 18,
                  color: _isShardsMode
                      ? CosmicScreenStyles.astralShardColor
                      : ElementResources.byBiomeId[_selectedResource]?.color ??
                            Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '$_outputAmount $_outputLabel',
                  style: TextStyle(color: t.textPrimary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Convert',
              style: TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _sellAlchemicalMatter(int available) async {
    final resource = _selectedSellElement;
    final qty = _sellQuantity.clamp(1, available);
    if (available <= 0 || qty <= 0) {
      _showError('No ${resource.biomeLabel.toLowerCase()} matter in storage');
      return;
    }

    final silverPayout = _sellSilverPayoutFor(resource.biomeId, qty);
    final isDaily = resource.biomeId == _dailySaleResource.biomeId;
    final confirmed = await _confirmAlchemicalSale(
      resource: resource,
      qty: qty,
      silverPayout: silverPayout,
      isDaily: isDaily,
    );
    if (!confirmed) return;
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final spent = await db.currencyDao.spendResources({
      resource.settingsKey: qty,
    });
    if (!spent) {
      _showError('Not enough ${resource.biomeLabel.toLowerCase()} matter');
      return;
    }
    await db.currencyDao.addSilver(silverPayout);

    HapticFeedback.heavyImpact();
    if (!mounted) return;
    _showConversionToast(
      'Sold $qty ${resource.biomeLabel.toLowerCase()} matter for $silverPayout silver.',
      success: true,
    );
    setState(() {
      _sellQuantity = qty;
    });
  }

  Future<bool> _confirmAlchemicalSale({
    required ElementResource resource,
    required int qty,
    required int silverPayout,
    required bool isDaily,
  }) async {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _accent.withValues(alpha: 0.55)),
        ),
        title: Text(
          'CONFIRM SALE',
          style: TextStyle(
            fontFamily: appFontFamily(context),
            color: t.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.1,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDaily) ...[
              Text(
                '${resource.biomeLabel} is the alchemical of the day.',
                style: TextStyle(
                  color: resource.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Icon(resource.icon, size: 18, color: resource.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$qty ${resource.biomeLabel} Matter',
                    style: TextStyle(color: t.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Icon(
              AppIcons.arrow_downward_rounded,
              size: 20,
              color: Colors.white38,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const CoinIcon(kind: CoinKind.silver, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$silverPayout Silver',
                  style: TextStyle(color: t.textPrimary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sell', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  // ── Shell ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          // Border.paint throws on a non-uniform border with a borderRadius,
          // which blanks the whole sheet. The accent top edge is drawn as its
          // own clipped bar instead of a differently coloured border side.
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            border: Border.all(color: t.borderDim),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Column(
              children: [
                Container(height: 2, color: _accent.withValues(alpha: 0.75)),
                _grabHandle(t),
                _header(t),
                _walletStrip(db, t),
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _convertPanel(t),
                        const SizedBox(height: 12),
                        _sellPanel(db, t),
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

  Widget _grabHandle(ForgeTokens t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 10),
    child: Center(child: Container(width: 34, height: 3, color: t.borderDim)),
  );

  Widget _header(ForgeTokens t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 8, 10),
      child: Row(
        children: [
          Container(width: 3, height: 22, color: _accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'GOLD CONVERSION',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Trade Gold for matter, or matter for Silver',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: t.borderDim),
              ),
              child: Icon(
                AppIcons.close_rounded,
                size: 18,
                color: t.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Balances read left-to-right on one baseline instead of a centred cluster,
  /// so the numbers line up with the panels beneath them.
  Widget _walletStrip(AlchemonsDatabase db, ForgeTokens t) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final gold = snap.data?['gold'] ?? 0;
        final silver = snap.data?['silver'] ?? 0;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: t.borderDim),
          ),
          child: Row(
            children: [
              Expanded(
                child: _walletCell(
                  t,
                  icon: const CoinIcon(kind: CoinKind.gold, size: 14),
                  label: 'GOLD',
                  value: '$gold',
                  valueColor: _accent,
                ),
              ),
              Container(width: 1, height: 26, color: t.borderDim),
              Expanded(
                child: _walletCell(
                  t,
                  icon: const CoinIcon(kind: CoinKind.silver, size: 14),
                  label: 'SILVER',
                  value: '$silver',
                  valueColor: t.textPrimary,
                ),
              ),
              Container(width: 1, height: 26, color: t.borderDim),
              Expanded(
                child: _walletCell(
                  t,
                  icon: const Icon(
                    CosmicScreenStyles.astralShardIcon,
                    size: 14,
                    color: CosmicScreenStyles.astralShardColor,
                  ),
                  label: 'SHARDS',
                  value: '$_carriedShards/${widget.shardCapacity}',
                  valueColor: CosmicScreenStyles.astralShardColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _walletCell(
    ForgeTokens t, {
    required Widget icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            icon,
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'monospace',
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  // ── Shared furniture ───────────────────────────────────────────────────────

  Widget _panel(
    ForgeTokens t, {
    required String title,
    required Color accent,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  color: accent,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          Container(height: 1, color: t.borderDim),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(ForgeTokens t, String text) => Text(
    text,
    style: TextStyle(
      fontFamily: 'monospace',
      color: t.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    ),
  );

  /// Compact selectable chip. Replaces the full-width tiles and 148px cards
  /// that made the sheet scroll for ever and never lined up with each other.
  Widget _choiceChip({
    required ForgeTokens t,
    required IconData icon,
    required Color color,
    required String label,
    String? note,
    required bool selected,
    required VoidCallback? onTap,
    bool flagged = false,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.16) : t.bg1,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.8) : t.borderDim,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? color : t.textSecondary),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: selected ? color : t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              if (flagged) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    'TODAY',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _accent,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Label on the left, steppers on the right — one alignment for both panels
  /// rather than a centred cluster under a left-aligned heading.
  Widget _stepperRow({
    required ForgeTokens t,
    required Color accent,
    required String value,
    required String unit,
    required VoidCallback? onMinus,
    required VoidCallback? onPlus,
  }) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  unit,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _stepButton(t, AppIcons.remove, accent, onMinus),
        const SizedBox(width: 6),
        _stepButton(t, AppIcons.add, accent, onPlus),
      ],
    );
  }

  Widget _stepButton(
    ForgeTokens t,
    IconData icon,
    Color accent,
    VoidCallback? onTap,
  ) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
      ),
    );
  }

  Widget _quickChip(ForgeTokens t, String label, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onTap();
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: t.borderDim),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// cost → output, on one line, so the trade reads as a single sentence.
  Widget _tradeLine(
    ForgeTokens t, {
    required Widget fromIcon,
    required String fromText,
    required IconData toIcon,
    required Color toColor,
    required String toText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: t.bg1,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        children: [
          fromIcon,
          const SizedBox(width: 6),
          Text(
            fromText,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Icon(AppIcons.arrow_forward_rounded, size: 14, color: t.textMuted),
          const Spacer(),
          Icon(toIcon, size: 14, color: toColor),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                toText,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: toColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required ForgeTokens t,
    required String label,
    required Color accent,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.mediumImpact();
              onTap();
            }
          : null,
      behavior: HitTestBehavior.opaque,
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: accent.withValues(alpha: 0.75)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  // ── Convert ────────────────────────────────────────────────────────────────

  Widget _convertPanel(ForgeTokens t) {
    final outputIcon = _isShardsMode
        ? CosmicScreenStyles.astralShardIcon
        : ElementResources.byBiomeId[_selectedResource]?.icon ??
              AppIcons.circle;
    final outputColor = _isShardsMode
        ? CosmicScreenStyles.astralShardColor
        : ElementResources.byBiomeId[_selectedResource]?.color ?? _accent;
    final ready = _isShardsMode || _selectedResource != null;

    return _panel(
      t,
      title: 'CONVERT GOLD',
      accent: _accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel(t, 'CONVERT TO'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _choiceChip(
                t: t,
                icon: CosmicScreenStyles.astralShardIcon,
                color: CosmicScreenStyles.astralShardColor,
                label: 'SHARDS',
                note: '$_shardsPer / $_goldPer g',
                selected: _isShardsMode,
                onTap: () => setState(() {
                  _isShardsMode = true;
                  _selectedResource = null;
                }),
              ),
              for (final res in ElementResources.all)
                _choiceChip(
                  t: t,
                  icon: res.icon,
                  color: res.color,
                  label: res.biomeLabel.toUpperCase(),
                  note: '$_particlesPer / $_goldPer g',
                  selected: !_isShardsMode && _selectedResource == res.biomeId,
                  onTap: () => setState(() {
                    _isShardsMode = false;
                    _selectedResource = res.biomeId;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _fieldLabel(t, 'SPEND'),
          const SizedBox(height: 8),
          _stepperRow(
            t: t,
            accent: _accent,
            value: '$_goldCost',
            unit: 'GOLD',
            onMinus: _multiplier > 1
                ? () => setState(() => _multiplier--)
                : null,
            onPlus: () => setState(() => _multiplier++),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in const [1, 2, 5, 10, 20])
                _quickChip(
                  t,
                  '${_goldPer * m}g',
                  () => setState(() => _multiplier = m),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _tradeLine(
            t,
            fromIcon: const CoinIcon(kind: CoinKind.gold, size: 14),
            fromText: '$_goldCost Gold',
            toIcon: outputIcon,
            toColor: outputColor,
            toText: ready ? '$_outputAmount $_outputLabel' : 'Pick a target',
          ),
          const SizedBox(height: 10),
          _actionButton(
            t: t,
            label: 'CONVERT',
            accent: _accent,
            onTap: ready ? _convert : null,
          ),
        ],
      ),
    );
  }

  // ── Sell ───────────────────────────────────────────────────────────────────

  Widget _sellPanel(AlchemonsDatabase db, ForgeTokens t) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchResourceBalances(),
      builder: (context, resourceSnap) {
        final balances =
            resourceSnap.data ??
            {for (final res in ElementResources.all) res.settingsKey: 0};
        final selected = _selectedSellElement;
        final available = balances[selected.settingsKey] ?? 0;
        final qty = available <= 0 ? 0 : _sellQuantity.clamp(1, available);
        final payout = _sellSilverPayoutFor(selected.biomeId, qty);
        final isDaily = selected.biomeId == _dailySaleResource.biomeId;

        return _panel(
          t,
          title: 'SELL MATTER',
          accent: selected.color,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              'TODAY · ${_dailySaleResource.biomeLabel.toUpperCase()} ×5',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _accent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fieldLabel(t, 'FROM HOME STORAGE'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final res in ElementResources.all)
                    _choiceChip(
                      t: t,
                      icon: res.icon,
                      color: res.color,
                      label: res.biomeLabel.toUpperCase(),
                      note: '${balances[res.settingsKey] ?? 0} held',
                      selected: _selectedSellResource == res.biomeId,
                      flagged: res.biomeId == _dailySaleResource.biomeId,
                      onTap: () => setState(() {
                        _selectedSellResource = res.biomeId;
                        final next = balances[res.settingsKey] ?? 0;
                        _sellQuantity = next <= 0
                            ? 0
                            : _sellQuantity.clamp(1, next);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _fieldLabel(t, 'QUANTITY'),
              const SizedBox(height: 8),
              _stepperRow(
                t: t,
                accent: selected.color,
                value: '$qty',
                unit: 'OF $available',
                onMinus: available <= 0
                    ? null
                    : () => setState(() {
                        _sellQuantity = (_sellQuantity - 1).clamp(1, available);
                      }),
                onPlus: available <= 0
                    ? null
                    : () => setState(() {
                        _sellQuantity = (_sellQuantity + 1).clamp(1, available);
                      }),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final preset in const [1, 10, 100])
                    _quickChip(
                      t,
                      '$preset',
                      available <= 0
                          ? null
                          : () => setState(() {
                              _sellQuantity = preset.clamp(1, available);
                            }),
                    ),
                  _quickChip(
                    t,
                    'MAX',
                    available <= 0
                        ? null
                        : () => setState(() => _sellQuantity = available),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _tradeLine(
                t,
                fromIcon: Icon(selected.icon, size: 14, color: selected.color),
                fromText: '$qty ${selected.biomeLabel}',
                toIcon: AppIcons.paid_rounded,
                toColor: isDaily ? _accent : t.textPrimary,
                toText: '$payout Silver',
              ),
              const SizedBox(height: 6),
              Text(
                isDaily
                    ? 'Daily bonus: 5 Silver each.'
                    : 'Standard rate: 1 Silver each.',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _actionButton(
                t: t,
                label: 'SELL',
                accent: selected.color,
                onTap: available <= 0
                    ? null
                    : () => _sellAlchemicalMatter(available),
              ),
            ],
          ),
        );
      },
    );
  }
}
