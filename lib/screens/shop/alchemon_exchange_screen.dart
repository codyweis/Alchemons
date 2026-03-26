import 'package:alchemons/constants/black_market_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AlchemonExchangeScreen extends StatefulWidget {
  const AlchemonExchangeScreen({super.key});

  @override
  State<AlchemonExchangeScreen> createState() => _AlchemonExchangeScreenState();
}

class _AlchemonExchangeScreenState extends State<AlchemonExchangeScreen> {
  final List<CreatureInstance> _selectedForSale = [];
  final Map<String, _SelectedVialSale> _selectedVialsForSale = {};
  int _totalSilverValue = 0;
  int _totalGoldValue = 0;

  ForgeTokens get t => ForgeTokens(context.read<FactionTheme>());
  Color get _primaryAccent => t.readableAccent(t.amberBright);
  Color get _goldAccent => t.readableAccent(const Color(0xFFFFD700));
  bool get _hasSelections =>
      _selectedForSale.isNotEmpty || _selectedVialsForSale.isNotEmpty;
  int get _selectedVialCount => _selectedVialsForSale.values.fold(
    0,
    (sum, vial) => sum + vial.selectedQty,
  );
  int get _selectionCount => _selectedForSale.length + _selectedVialCount;
  String get _selectionSummary {
    final parts = <String>[];
    if (_selectedForSale.isNotEmpty) {
      parts.add('${_selectedForSale.length} specimen(s)');
    }
    if (_selectedVialsForSale.isNotEmpty) {
      parts.add('$_selectedVialCount vial(s)');
    }
    return parts.join(' and ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildIntro(),
            Expanded(
              child: !_hasSelections
                  ? _buildEmptyState()
                  : _buildSelectedItems(),
            ),
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: t.borderDim),
              ),
              child: Icon(Icons.arrow_back_rounded, color: t.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: t.borderAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'SPECIMEN EXCHANGE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CurrencyDisplayWidget(accentColor: t.borderAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.bg2, t.bg1],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: t.borderAccent.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sell_rounded, color: _primaryAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'SELL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _primaryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Sell Alchemons and extraction vials from storage or inventory.',
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sell_rounded,
              size: 80,
              color: t.textMuted.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 18),
            Text(
              'No items selected',
              style: TextStyle(
                color: t.textPrimary.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose unlocked, unprotected Alchemons or stored vials to exchange for currency.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textMuted,
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedItems() {
    final repo = context.read<CreatureCatalog>();
    final factions = context.read<FactionService>();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: t.bg2,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.borderAccent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Icon(Icons.inventory_2_rounded, color: _primaryAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'SELECTED ($_selectionCount)',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _primaryAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedForSale.clear();
                    _selectedVialsForSale.clear();
                    _totalSilverValue = 0;
                    _totalGoldValue = 0;
                  });
                  HapticFeedback.lightImpact();
                },
                child: Text(
                  'CLEAR',
                  style: TextStyle(
                    color: t.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedForSale.isNotEmpty) ...[
          _buildSectionLabel('SPECIMENS', Icons.pets_rounded, _primaryAccent),
          const SizedBox(height: 6),
          ..._selectedForSale.map((inst) {
            final species = repo.getCreatureById(inst.baseId);
            final price = _computeSilverSellPrice(inst, species, factions);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ExchangeCreatureRow(
                instance: inst,
                species: species,
                price: inst.isPrismaticSkin ? _silverToGoldValue(price) : price,
                usesGold: inst.isPrismaticSkin,
                onRemove: () {
                  setState(() {
                    _selectedForSale.removeWhere(
                      (row) => row.instanceId == inst.instanceId,
                    );
                    _recalculateTotal();
                  });
                  HapticFeedback.lightImpact();
                },
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (_selectedVialsForSale.isNotEmpty) ...[
          _buildSectionLabel('VIALS', Icons.science_rounded, t.textSecondary),
          const SizedBox(height: 6),
          ..._selectedVialsForSale.values.map(
            (vial) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ExchangeVialRow(
                vial: vial,
                onRemove: () {
                  setState(() {
                    _selectedVialsForSale.remove(vial.key);
                    _recalculateTotal();
                  });
                  HapticFeedback.lightImpact();
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.successDim.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: t.success.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_totalSilverValue > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: t.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalSilverValue',
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  if (_totalGoldValue > 0) const SizedBox(height: 4),
                  if (_totalGoldValue > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hexagon_rounded,
                          size: 18,
                          color: _goldAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalGoldValue',
                          style: TextStyle(
                            color: _goldAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, t.bg0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showInstanceBrowser,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: t.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: t.borderAccent, width: 1.5),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.pets_rounded,
                            color: _primaryAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SELECT SPECIMENS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _primaryAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _showVialBrowser,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: t.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: t.textSecondary.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.science_rounded,
                            color: t.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'SELECT VIALS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_hasSelections) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _confirmSale,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [t.success, t.teal]),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: t.success.withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.sell_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'COMPLETE SALE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  int _silverToGoldValue(int silverValue) =>
      (silverValue / 1500).ceil().clamp(2, 999999);

  int _silverValueForVialRarity(VialRarity rarity) {
    switch (rarity) {
      case VialRarity.common:
        return 25;
      case VialRarity.uncommon:
        return 50;
      case VialRarity.rare:
        return 100;
      case VialRarity.legendary:
      case VialRarity.mythic:
        return 150;
    }
  }

  int _computeSilverSellPrice(
    CreatureInstance inst,
    Creature? species,
    FactionService factions,
  ) {
    final tintId = decodeGenetics(inst.geneticsJson)?.tinting;
    final basePrice = BlackMarketConstants.calculateSellPrice(
      rarity: species?.rarity ?? 'common',
      level: inst.level,
      isPrismatic: inst.isPrismaticSkin,
      natureId: inst.natureId,
      tintId: tintId,
    );

    final isEarthenCreature =
        species != null && species.types.contains('Earth');
    final perkMult = factions.earthenSaleValueMultiplier(
      isEarthenCreature: isEarthenCreature,
    );
    final adjusted = (basePrice * perkMult).round();

    if (inst.isPrismaticSkin) {
      return adjusted;
    }
    return BlackMarketConstants.applySilverSaleBoost(adjusted);
  }

  void _recalculateTotal() {
    final repo = context.read<CreatureCatalog>();
    final factions = context.read<FactionService>();
    final constellations = context.read<ConstellationEffectsService>();
    final saleMult = constellations.getAlchemonSaleMultiplier();
    final silverPrices = <int>[];
    var goldTotal = 0;

    for (final inst in _selectedForSale) {
      final species = repo.getCreatureById(inst.baseId);
      final price = _computeSilverSellPrice(inst, species, factions);
      if (inst.isPrismaticSkin) {
        goldTotal += _silverToGoldValue((price * saleMult).round());
      } else {
        silverPrices.add(price);
      }
    }

    final baseSilverTotal = silverPrices.fold<int>(
      0,
      (sum, price) => sum + price,
    );
    final silverBulkBonus = BlackMarketConstants.calculateBulkBonus(
      silverPrices,
    );
    final specimenSilverTotal = ((baseSilverTotal + silverBulkBonus) * saleMult)
        .round();
    final vialSilverTotal = _selectedVialsForSale.values.fold(
      0,
      (sum, vial) => sum + vial.totalSilverValue,
    );

    _totalSilverValue = specimenSilverTotal + vialSilverTotal;
    _totalGoldValue = goldTotal;
  }

  Future<void> _showInstanceBrowser() async {
    final theme = context.read<FactionTheme>();

    final picked = await Navigator.of(context).push<List<CreatureInstance>>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              searchHint: 'SELECT SPECIMENS',
              selectionMode: true,
              closeReturnsSelection: true,
              selectedInstanceIds: _selectedForSale
                  .map((inst) => inst.instanceId)
                  .toList(),
              onWillSelectInstance: (inst) async {
                if (inst.locked) {
                  _showToast('Locked specimens cannot be exchanged.');
                  return false;
                }
                return true;
              },
              onConfirmSelection: (selected) {
                Navigator.of(context).pop(selected);
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween(
            begin: const Offset(0.0, 1.0),
            end: Offset.zero,
          ).chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _selectedForSale
        ..clear()
        ..addAll(picked);
      _recalculateTotal();
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _showVialBrowser() async {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();
    final repo = context.read<CreatureCatalog>();
    final items = await db.inventoryDao.watchItemInventory().first;
    final storedEggs = await db.incubatorDao.watchInventory().first;
    final vials =
        <_VialPickerEntry>[
          ...items
              .where((item) => item.key.startsWith('vial.'))
              .map(_parseVialInventoryItem)
              .whereType<_VialPickerEntry>(),
          ..._parseStoredVialEntries(storedEggs, repo),
        ]..sort((a, b) {
          final sourceCompare = a.source.index.compareTo(b.source.index);
          if (sourceCompare != 0) return sourceCompare;
          final rarityCompare = a.rarity.index.compareTo(b.rarity.index);
          if (rarityCompare != 0) return rarityCompare;
          final groupCompare = a.group.displayName.compareTo(
            b.group.displayName,
          );
          if (groupCompare != 0) return groupCompare;
          return a.name.compareTo(b.name);
        });

    if (vials.isEmpty) {
      _showToast('No vials available to sell');
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final selectedQty = <String, int>{
          for (final entry in vials)
            entry.key: _selectedVialsForSale[entry.key]?.selectedQty ?? 0,
        };

        return StatefulBuilder(
          builder: (context, setModalState) {
            return BottomSheetShell(
              theme: theme,
              title: 'Select Vials',
              child: Column(
                children: [
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                      itemCount: vials.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final vial = vials[index];
                        final qty = selectedQty[vial.key] ?? 0;
                        final canRemove = qty > 0;
                        final canAdd = qty < vial.availableQty;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: qty > 0
                                  ? vial.group.color.withValues(alpha: 0.6)
                                  : t.borderDim,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: vial.group.color.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: vial.group.color.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Icon(
                                  Icons.science_rounded,
                                  color: vial.group.color,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vial.name,
                                      style: TextStyle(
                                        color: t.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${vial.rarity.label} • ${vial.group.displayName} • ${vial.availableQty} available • ${vial.sourceLabel}',
                                      style: TextStyle(
                                        color: t.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${vial.unitSilverValue} silver each',
                                      style: TextStyle(
                                        color: t.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _QuantityButton(
                                    icon: Icons.remove_rounded,
                                    enabled: canRemove,
                                    onTap: () {
                                      if (!canRemove) return;
                                      setModalState(() {
                                        selectedQty[vial.key] = qty - 1;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                  Container(
                                    width: 36,
                                    alignment: Alignment.center,
                                    child: Text(
                                      '$qty',
                                      style: TextStyle(
                                        color: t.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  _QuantityButton(
                                    icon: Icons.add_rounded,
                                    enabled: canAdd,
                                    onTap: () {
                                      if (!canAdd) return;
                                      setModalState(() {
                                        selectedQty[vial.key] = qty + 1;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: GestureDetector(
                      onTap: () {
                        final nextSelection = <String, _SelectedVialSale>{};
                        for (final entry in vials) {
                          final qty = selectedQty[entry.key] ?? 0;
                          if (qty <= 0) continue;
                          nextSelection[entry.key] = _SelectedVialSale(
                            key: entry.key,
                            name: entry.name,
                            group: entry.group,
                            rarity: entry.rarity,
                            selectedQty: qty,
                            unitSilverValue: entry.unitSilverValue,
                            source: entry.source,
                            storageEggIds: entry.storageEggIds
                                .take(qty)
                                .toList(),
                          );
                        }

                        setState(() {
                          _selectedVialsForSale
                            ..clear()
                            ..addAll(nextSelection);
                          _recalculateTotal();
                        });
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [t.amber, t.teal]),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: t.borderAccent.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'APPLY VIAL SELECTION',
                            style: TextStyle(
                              color: t.bg0,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
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

  List<_VialPickerEntry> _parseStoredVialEntries(
    List<Egg> eggs,
    CreatureCatalog repo,
  ) {
    final grouped = <String, _StoredVialAccumulator>{};

    for (final egg in eggs) {
      final payload = parseEggPayload(egg);
      if ((payload['source'] as String?) != 'vial') continue;

      final baseId = payload['baseId'] as String? ?? egg.resultCreatureId;
      final creature = repo.getCreatureById(baseId);
      final rarityName = (payload['rarity'] as String? ?? egg.rarity)
          .toLowerCase();
      final rarity = _vialRarityFromString(rarityName);
      final group = getElementalGroupFromPayload(payload);
      final name = creature != null
          ? '${creature.name} Vial'
          : getEggLabel(payload);
      final groupKey = 'storage:$baseId:${rarity.name}:${group.name}';

      final bucket = grouped.putIfAbsent(
        groupKey,
        () => _StoredVialAccumulator(
          key: groupKey,
          name: name,
          group: group,
          rarity: rarity,
        ),
      );
      bucket.eggIds.add(egg.eggId);
    }

    return grouped.values
        .map(
          (entry) => _VialPickerEntry(
            key: entry.key,
            name: entry.name,
            group: entry.group,
            rarity: entry.rarity,
            availableQty: entry.eggIds.length,
            unitSilverValue: _silverValueForVialRarity(entry.rarity),
            source: _VialSaleSource.storage,
            storageEggIds: List<String>.from(entry.eggIds),
          ),
        )
        .toList();
  }

  VialRarity _vialRarityFromString(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return VialRarity.common;
      case 'uncommon':
        return VialRarity.uncommon;
      case 'rare':
        return VialRarity.rare;
      case 'legendary':
        return VialRarity.legendary;
      case 'mythic':
        return VialRarity.mythic;
      default:
        return VialRarity.common;
    }
  }

  _VialPickerEntry? _parseVialInventoryItem(InventoryItem item) {
    final parts = item.key.split('.');
    if (parts.length != 4 || parts.first != 'vial') return null;

    ElementalGroup? group;
    for (final value in ElementalGroup.values) {
      if (value.name == parts[1]) {
        group = value;
        break;
      }
    }

    VialRarity? rarity;
    for (final value in VialRarity.values) {
      if (value.name == parts[2]) {
        rarity = value;
        break;
      }
    }

    if (group == null || rarity == null) return null;

    return _VialPickerEntry(
      key: item.key,
      name: parts[3],
      group: group,
      rarity: rarity,
      availableQty: item.qty,
      unitSilverValue: _silverValueForVialRarity(rarity),
      source: _VialSaleSource.inventory,
    );
  }

  Future<void> _confirmSale() async {
    if (!_hasSelections) return;

    final silverTotal = _totalSilverValue;
    final goldTotal = _totalGoldValue;
    final specimenCount = _selectedForSale.length;
    final vialCount = _selectedVialCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SaleConfirmationDialog(
        summary: _selectionSummary,
        silverTotal: silverTotal,
        goldTotal: goldTotal,
        accent: _primaryAccent,
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final ids = _selectedForSale.map((inst) => inst.instanceId).toList();

    await db.transaction(() async {
      if (ids.isNotEmpty) {
        await db.creatureDao.deleteInstances(ids);
      }
      for (final vial in _selectedVialsForSale.values) {
        if (vial.source == _VialSaleSource.inventory) {
          await db.inventoryDao.decrementItem(vial.key, by: vial.selectedQty);
        } else {
          for (final eggId in vial.storageEggIds) {
            await db.incubatorDao.removeFromInventory(eggId);
          }
        }
      }
      if (silverTotal > 0) {
        await db.currencyDao.addSilver(silverTotal);
      }
      if (goldTotal > 0) {
        await db.currencyDao.addGold(goldTotal);
      }
    });

    setState(() {
      _selectedForSale.clear();
      _selectedVialsForSale.clear();
      _totalSilverValue = 0;
      _totalGoldValue = 0;
    });

    if (!mounted) return;
    HapticFeedback.heavyImpact();

    _showToast(
      goldTotal > 0 && silverTotal > 0
          ? 'Sold ${_soldItemSummary(specimenCount, vialCount)} for $silverTotal silver and $goldTotal gold'
          : goldTotal > 0
          ? 'Sold ${_soldItemSummary(specimenCount, vialCount)} for $goldTotal gold'
          : 'Sold ${_soldItemSummary(specimenCount, vialCount)} for $silverTotal silver',
    );
  }

  String _soldItemSummary(int specimenCount, int vialCount) {
    final parts = <String>[];
    if (specimenCount > 0) parts.add('$specimenCount specimen(s)');
    if (vialCount > 0) parts.add('$vialCount vial(s)');
    return parts.join(' and ');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.success,
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ExchangeCreatureRow extends StatelessWidget {
  final CreatureInstance instance;
  final Creature? species;
  final int price;
  final bool usesGold;
  final VoidCallback onRemove;

  const _ExchangeCreatureRow({
    required this.instance,
    required this.species,
    required this.price,
    required this.usesGold,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final goldAccent = t.readableAccent(const Color(0xFFFFD700));

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  species?.name ?? instance.baseId,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lv ${instance.level} • ${species?.rarity ?? 'common'}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                usesGold
                    ? Icons.hexagon_rounded
                    : Icons.monetization_on_rounded,
                size: 18,
                color: usesGold ? goldAccent : const Color(0xFFC0C0C0),
              ),
              const SizedBox(width: 6),
              Text(
                '$price',
                style: TextStyle(
                  color: usesGold ? goldAccent : theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded, color: theme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExchangeVialRow extends StatelessWidget {
  final _SelectedVialSale vial;
  final VoidCallback onRemove;

  const _ExchangeVialRow({required this.vial, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: vial.group.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: vial.group.color.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.science_rounded,
              color: vial.group.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vial.name,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${vial.rarity.label} • ${vial.group.displayName} • x${vial.selectedQty} • ${vial.sourceLabel}',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: 18,
                color: t.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '${vial.totalSilverValue}',
                style: TextStyle(
                  color: theme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemove,
                child: Icon(Icons.close_rounded, color: theme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaleConfirmationDialog extends StatelessWidget {
  final String summary;
  final int silverTotal;
  final int goldTotal;
  final Color accent;

  const _SaleConfirmationDialog({
    required this.summary,
    required this.silverTotal,
    required this.goldTotal,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A1D23),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accent.withValues(alpha: 0.5), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_rounded, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              'CONFIRM SALE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              goldTotal > 0 && silverTotal > 0
                  ? 'Sell $summary for $silverTotal silver and $goldTotal gold?'
                  : goldTotal > 0
                  ? 'Sell $summary for $goldTotal gold?'
                  : 'Sell $summary for $silverTotal silver?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Confirm',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? theme.accent.withValues(alpha: 0.16)
              : theme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? theme.accent.withValues(alpha: 0.45)
                : theme.border.withValues(alpha: 0.6),
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? theme.accent : theme.textMuted,
        ),
      ),
    );
  }
}

enum _VialSaleSource { inventory, storage }

class _VialPickerEntry {
  final String key;
  final String name;
  final ElementalGroup group;
  final VialRarity rarity;
  final int availableQty;
  final int unitSilverValue;
  final _VialSaleSource source;
  final List<String> storageEggIds;

  const _VialPickerEntry({
    required this.key,
    required this.name,
    required this.group,
    required this.rarity,
    required this.availableQty,
    required this.unitSilverValue,
    required this.source,
    this.storageEggIds = const [],
  });

  String get sourceLabel =>
      source == _VialSaleSource.inventory ? 'Inventory' : 'Storage';
}

class _SelectedVialSale {
  final String key;
  final String name;
  final ElementalGroup group;
  final VialRarity rarity;
  final int selectedQty;
  final int unitSilverValue;
  final _VialSaleSource source;
  final List<String> storageEggIds;

  const _SelectedVialSale({
    required this.key,
    required this.name,
    required this.group,
    required this.rarity,
    required this.selectedQty,
    required this.unitSilverValue,
    required this.source,
    this.storageEggIds = const [],
  });

  int get totalSilverValue => selectedQty * unitSilverValue;

  String get sourceLabel =>
      source == _VialSaleSource.inventory ? 'Inventory' : 'Storage';
}

class _StoredVialAccumulator {
  final String key;
  final String name;
  final ElementalGroup group;
  final VialRarity rarity;
  final List<String> eggIds;

  _StoredVialAccumulator({
    required this.key,
    required this.name,
    required this.group,
    required this.rarity,
  }) : eggIds = [];
}
