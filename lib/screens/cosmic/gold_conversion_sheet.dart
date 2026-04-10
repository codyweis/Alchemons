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
import 'package:alchemons/utils/app_font_family.dart';
import 'package:alchemons/utils/faction_util.dart';
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Converted $_goldCost gold → $_outputAmount $_outputLabel',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() {});
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
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
          side: BorderSide(color: _accent.withValues(alpha: 0.35)),
        ),
        title: Text(
          'Confirm Conversion',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.hexagon_rounded,
                  size: 18,
                  color: Color(0xFFFFD700),
                ),
                const SizedBox(width: 6),
                Text('$_goldCost Gold', style: TextStyle(color: t.textPrimary)),
              ],
            ),
            const SizedBox(height: 8),
            const Icon(
              Icons.arrow_downward_rounded,
              size: 20,
              color: Colors.white38,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _isShardsMode
                      ? Icons.diamond_rounded
                      : ElementResources.byBiomeId[_selectedResource]?.icon ??
                            Icons.circle,
                  size: 18,
                  color: _isShardsMode
                      ? const Color(0xFFAB47BC)
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Sold $qty ${resource.biomeLabel.toLowerCase()} matter for $silverPayout silver',
        ),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ),
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
          side: BorderSide(color: _accent.withValues(alpha: 0.35)),
        ),
        title: Text(
          'Confirm Sale',
          style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
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
              Icons.arrow_downward_rounded,
              size: 20,
              color: Colors.white38,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.monetization_on_rounded,
                  size: 18,
                  color: Color(0xFFC0C0C0),
                ),
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.borderDim,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                Text(
                  'GOLD CONVERSION',
                  style: TextStyle(
                    fontFamily: appFontFamily(context),
                    color: _accent,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Trade gold for particles or shards',
                  style: TextStyle(color: t.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Gold balance
                _buildGoldBalance(db, t),
                const SizedBox(height: 20),

                // Output type selector
                _buildOutputSelector(t),
                const SizedBox(height: 20),

                // Quantity selector
                _buildQuantitySelector(t),
                const SizedBox(height: 20),

                // Summary + convert button
                _buildSummary(t),
                const SizedBox(height: 24),
                _buildSellSection(db, t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGoldBalance(AlchemonsDatabase db, ForgeTokens t) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, snap) {
        final gold = snap.data?['gold'] ?? 0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.hexagon_rounded,
              size: 20,
              color: Color(0xFFFFD700),
            ),
            const SizedBox(width: 6),
            Text(
              '$gold Gold',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 20),
            const Icon(
              Icons.diamond_rounded,
              size: 18,
              color: Color(0xFFAB47BC),
            ),
            const SizedBox(width: 4),
            Text(
              '$_carriedShards / ${widget.shardCapacity} Shards',
              style: TextStyle(color: t.textSecondary, fontSize: 14),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOutputSelector(ForgeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONVERT TO',
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),

        // Shards option
        _buildOptionTile(
          icon: Icons.diamond_rounded,
          iconColor: const Color(0xFFAB47BC),
          label: 'Astral Shards',
          subtitle: '$_shardsPer shards per 5 gold',
          selected: _isShardsMode,
          onTap: () => setState(() {
            _isShardsMode = true;
            _selectedResource = null;
          }),
          t: t,
        ),
        const SizedBox(height: 6),

        // Element particle options
        ...ElementResources.all.map(
          (res) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildOptionTile(
              icon: res.icon,
              iconColor: res.color,
              label: '${res.biomeLabel} Particles',
              subtitle: '$_particlesPer particles per 5 gold',
              selected: !_isShardsMode && _selectedResource == res.biomeId,
              onTap: () => setState(() {
                _isShardsMode = false;
                _selectedResource = res.biomeId;
              }),
              t: t,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    required ForgeTokens t,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? _accent.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected
                ? _accent.withValues(alpha: 0.6)
                : t.borderDim.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: t.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle_rounded, size: 20, color: _accent),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(ForgeTokens t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMOUNT',
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepButton(Icons.remove, () {
              if (_multiplier > 1) setState(() => _multiplier--);
            }, t),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    '${_goldPer * _multiplier}',
                    style: TextStyle(
                      color: const Color(0xFFFFD700),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'GOLD',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildStepButton(Icons.add, () {
              setState(() => _multiplier++);
            }, t),
          ],
        ),
      ],
    );
  }

  Widget _buildStepButton(IconData icon, VoidCallback onTap, ForgeTokens t) {
    return GestureDetector(
      onTap: () {
        onTap();
        HapticFeedback.selectionClick();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: _accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _accent.withValues(alpha: 0.4)),
        ),
        child: Icon(icon, color: _accent, size: 22),
      ),
    );
  }

  Widget _buildSummary(ForgeTokens t) {
    final outputIcon = _isShardsMode
        ? Icons.diamond_rounded
        : ElementResources.byBiomeId[_selectedResource]?.icon ?? Icons.circle;
    final outputColor = _isShardsMode
        ? const Color(0xFFAB47BC)
        : ElementResources.byBiomeId[_selectedResource]?.color ?? Colors.white;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.hexagon_rounded,
                    size: 18,
                    color: Color(0xFFFFD700),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_goldCost Gold',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Colors.white38,
              ),
              Row(
                children: [
                  Icon(outputIcon, size: 18, color: outputColor),
                  const SizedBox(width: 6),
                  Text(
                    '$_outputAmount',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _outputLabel,
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _convert,
              child: const Text(
                'CONVERT',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellSection(AlchemonsDatabase db, ForgeTokens t) {
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchAllCurrencies(),
      builder: (context, currencySnap) {
        final silver = currencySnap.data?['silver'] ?? 0;
        return StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, resourceSnap) {
            final balances =
                resourceSnap.data ??
                {for (final res in ElementResources.all) res.settingsKey: 0};
            final selectedAvailable =
                balances[_selectedSellElement.settingsKey] ?? 0;
            final effectiveSellQty = selectedAvailable <= 0
                ? 0
                : _sellQuantity.clamp(1, selectedAvailable);
            final effectiveSellPayout = _sellSilverPayoutFor(
              _selectedSellElement.biomeId,
              effectiveSellQty,
            );

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _accent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.science_rounded,
                        color: _dailySaleResource.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'SELL ALCHEMICAL MATTER',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_dailySaleResource.biomeLabel} is the alchemical of the day: 500 silver per 100. All others sell for 1 silver each.',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 16,
                        color: Color(0xFFC0C0C0),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$silver Silver',
                        style: TextStyle(
                          color: t.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Home storage',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final res in ElementResources.all)
                        _buildSellResourceChip(
                          res: res,
                          available: balances[res.settingsKey] ?? 0,
                          selected: _selectedSellResource == res.biomeId,
                          isDaily: res.biomeId == _dailySaleResource.biomeId,
                          onTap: () {
                            setState(() {
                              _selectedSellResource = res.biomeId;
                              final nextAvailable =
                                  balances[res.settingsKey] ?? 0;
                              if (nextAvailable <= 0) {
                                _sellQuantity = 0;
                              } else {
                                _sellQuantity = _sellQuantity.clamp(
                                  1,
                                  nextAvailable,
                                );
                              }
                            });
                          },
                          t: t,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'SELL QUANTITY',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepButton(Icons.remove, () {
                        if (selectedAvailable <= 0) return;
                        setState(() {
                          _sellQuantity = (_sellQuantity - 1).clamp(
                            1,
                            selectedAvailable,
                          );
                        });
                      }, t),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: _selectedSellElement.color.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$effectiveSellQty',
                              style: TextStyle(
                                color: _selectedSellElement.color,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'IN STORAGE: $selectedAvailable',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildStepButton(Icons.add, () {
                        if (selectedAvailable <= 0) return;
                        setState(() {
                          _sellQuantity = (_sellQuantity + 1).clamp(
                            1,
                            selectedAvailable,
                          );
                        });
                      }, t),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildQuickQtyChip(
                        label: '1',
                        onTap: selectedAvailable <= 0
                            ? null
                            : () => setState(() => _sellQuantity = 1),
                        t: t,
                      ),
                      _buildQuickQtyChip(
                        label: '10',
                        onTap: selectedAvailable <= 0
                            ? null
                            : () => setState(() {
                                _sellQuantity = 10.clamp(1, selectedAvailable);
                              }),
                        t: t,
                      ),
                      _buildQuickQtyChip(
                        label: '100',
                        onTap: selectedAvailable <= 0
                            ? null
                            : () => setState(() {
                                _sellQuantity = 100.clamp(1, selectedAvailable);
                              }),
                        t: t,
                      ),
                      _buildQuickQtyChip(
                        label: 'MAX',
                        onTap: selectedAvailable <= 0
                            ? null
                            : () => setState(
                                () => _sellQuantity = selectedAvailable,
                              ),
                        t: t,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedSellElement.color.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selectedSellElement.icon,
                                  size: 18,
                                  color: _selectedSellElement.color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$effectiveSellQty ${_selectedSellElement.biomeLabel} Matter',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.monetization_on_rounded,
                                  size: 18,
                                  color: Color(0xFFC0C0C0),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$effectiveSellPayout Silver',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedSellElement.biomeId ==
                                  _dailySaleResource.biomeId
                              ? 'Daily bonus active: 5 silver each, or 500 silver per 100.'
                              : 'Standard rate: 1 silver per matter.',
                          style: TextStyle(
                            color: t.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: _selectedSellElement.color,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: selectedAvailable <= 0
                                ? null
                                : () =>
                                      _sellAlchemicalMatter(selectedAvailable),
                            child: const Text(
                              'SELL FROM HOME STORAGE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSellResourceChip({
    required ElementResource res,
    required int available,
    required bool selected,
    required bool isDaily,
    required VoidCallback onTap,
    required ForgeTokens t,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 148,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? res.color.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? res.color.withValues(alpha: 0.75)
                : t.borderDim.withValues(alpha: 0.3),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(res.icon, color: res.color, size: 18),
                const Spacer(),
                if (isDaily)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'TODAY',
                      style: TextStyle(
                        color: _accent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              res.biomeLabel,
              style: TextStyle(
                color: t.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$available in storage',
              style: TextStyle(color: t.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickQtyChip({
    required String label,
    required VoidCallback? onTap,
    required ForgeTokens t,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: t.borderDim.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
            ),
          ),
        ),
      ),
    );
  }
}
