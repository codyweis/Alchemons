// lib/screens/shop/alchemon_exchange_screen.dart
//
// THE SPECIMEN EXCHANGE — the shop's counter for selling Alchemons and vials.
//
// Choose what to sell (specimens from the collection, vials held or stored),
// see each one priced on the counter, then complete the sale. Drawn in the
// bracket-frame language of the details and the black market, in the app's
// own theme.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/constants/black_market_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/economy_balance.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/extraction_vile.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/currency_display_widget.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:alchemons/widgets/instance_widgets/instance_sheet_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class AlchemonExchangeScreen extends StatefulWidget {
  const AlchemonExchangeScreen({
    super.key,
    @visibleForTesting this.debugInitialSpecimens = const [],
  });

  /// Specimens already on the counter when it opens: for previews, which
  /// cannot drive the specimen picker.
  final List<CreatureInstance> debugInitialSpecimens;

  @override
  State<AlchemonExchangeScreen> createState() => _AlchemonExchangeScreenState();
}

class _AlchemonExchangeScreenState extends State<AlchemonExchangeScreen> {
  late final List<CreatureInstance> _selectedForSale = [
    ...widget.debugInitialSpecimens,
  ];
  final Map<String, _SelectedVialSale> _selectedVialsForSale = {};

  FactionTheme get _theme => context.read<FactionTheme>();
  ForgeTokens get t => ForgeTokens(_theme);
  BracketPalette get _palette => BracketPalette.fromTheme(_theme);
  Color get _accent => t.readableAccent(t.amberBright);

  bool get _hasSelections =>
      _selectedForSale.isNotEmpty || _selectedVialsForSale.isNotEmpty;
  int get _selectedVialCount => _selectedVialsForSale.values.fold(
    0,
    (sum, vial) => sum + vial.selectedQty,
  );
  int get _selectionCount => _selectedForSale.length + _selectedVialCount;

  String get _selectionSummary =>
      _soldItemSummary(_selectedForSale.length, _selectedVialCount);

  // ── prices ────────────────────────────────────────────────────────────

  int _silverToGoldValue(int silverValue) =>
      (silverValue / EconomyBalance.silverPerGoldPayout).ceil().clamp(
        1,
        999999,
      );

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

  /// A specimen's base price in silver: rarity, level, tint, natures,
  /// Potential, and the Earthen perk.
  int _baseSilverPrice(
    CreatureInstance inst,
    Creature? species,
    FactionService factions,
  ) {
    final basePrice = BlackMarketConstants.calculateSellPrice(
      rarity: species?.rarity ?? 'common',
      level: inst.level,
      isPrismatic: inst.isPrismaticSkin,
      natureId: inst.natureId,
      natureId2: inst.natureId2,
      tintId: decodeGenetics(inst.geneticsJson)?.tinting,
      averagePotential: BlackMarketConstants.averagePotential(
        speed: inst.statSpeedPotential,
        intelligence: inst.statIntelligencePotential,
        strength: inst.statStrengthPotential,
        beauty: inst.statBeautyPotential,
      ),
    );
    final isEarthenCreature =
        species != null && species.types.contains('Earth');
    final perkMult = factions.earthenSaleValueMultiplier(
      isEarthenCreature: isEarthenCreature,
    );
    return (basePrice * perkMult).round();
  }

  /// What a specimen actually fetches, with the constellation sale boost:
  /// the figure shown on its row, in the grid and in the total alike (the
  /// rows used to leave the boost out, so they did not add up to it). A
  /// prismatic one is paid in gold, and a Transmuted one a flat 100 gold.
  (CoinKind, int) _priceOf(
    CreatureInstance inst,
    Creature? species,
    FactionService factions,
    double saleMult,
  ) {
    if (inst.mutation == AlchemonMutation.transmuted.id) {
      return (CoinKind.gold, BlackMarketConstants.transmutedGoldValue);
    }
    final silver = (_baseSilverPrice(inst, species, factions) * saleMult)
        .round();
    return inst.isPrismaticSkin
        ? (CoinKind.gold, _silverToGoldValue(silver))
        : (CoinKind.silver, silver);
  }

  /// Silver and gold for everything on the counter.
  (int, int) _totals() {
    final repo = context.read<CreatureCatalog>();
    final factions = context.read<FactionService>();
    final saleMult = context
        .read<ConstellationEffectsService>()
        .getAlchemonSaleMultiplier();
    var silver = 0, gold = 0;
    for (final inst in _selectedForSale) {
      final (kind, amount) = _priceOf(
        inst,
        repo.getCreatureById(inst.baseId),
        factions,
        saleMult,
      );
      if (kind == CoinKind.gold) {
        gold += amount;
      } else {
        silver += amount;
      }
    }
    for (final vial in _selectedVialsForSale.values) {
      silver += vial.totalSilverValue;
    }
    return (silver, gold);
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final palette = _palette;
    return Scaffold(
      backgroundColor: palette.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(palette),
            Expanded(
              child: _hasSelections
                  ? _buildCounter(palette)
                  : _buildChoose(palette),
            ),
            if (_hasSelections) _buildFooter(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BracketPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.line.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            palette: palette,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPECIMEN EXCHANGE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'ALCHEMONS AND VIALS, FOR COIN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const CurrencyDisplayWidget(),
        ],
      ),
    );
  }

  // ── nothing chosen yet ────────────────────────────────────────────────

  Widget _buildChoose(BracketPalette palette) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      children: [
        Text(
          'What are you selling?',
          textAlign: TextAlign.center,
          style: bracketText(context, 20, palette.ink, weight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose some, and each is priced on the counter before anything '
          'is sold.',
          textAlign: TextAlign.center,
          style: bracketText(context, 12.5, palette.muted),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(
              child: _ChoiceTile(
                label: 'SPECIMENS',
                caption: 'From your collection',
                accent: _accent,
                palette: palette,
                onTap: _showInstanceBrowser,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ChoiceTile(
                label: 'VIALS',
                caption: 'Held or in storage',
                accent: _accent,
                palette: palette,
                onTap: _showVialBrowser,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.lock_rounded, size: 12, color: palette.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Favourites are locked and stay with you.',
                style: bracketText(context, 11.5, palette.muted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── the counter ───────────────────────────────────────────────────────

  Widget _buildCounter(BracketPalette palette) {
    final repo = context.read<CreatureCatalog>();
    final factions = context.read<FactionService>();
    final saleMult = context
        .read<ConstellationEffectsService>()
        .getAlchemonSaleMultiplier();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionLabel(
                'ON THE COUNTER · $_selectionCount',
                color: _accent,
                palette: palette,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: context.soundAction(() {
                setState(() {
                  _selectedForSale.clear();
                  _selectedVialsForSale.clear();
                });
                HapticFeedback.lightImpact();
              }),
              child: Text(
                'CLEAR ALL',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.danger,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        if (_selectedForSale.isNotEmpty) ...[
          const SizedBox(height: 14),
          _SubLabel('SPECIMENS', palette: palette),
          const SizedBox(height: 8),
          for (final inst in _selectedForSale) ...[
            Builder(
              builder: (context) {
                final species = repo.getCreatureById(inst.baseId);
                final (kind, amount) = _priceOf(
                  inst,
                  species,
                  factions,
                  saleMult,
                );
                return _SpecimenLot(
                  instance: inst,
                  species: species,
                  kind: kind,
                  amount: amount,
                  palette: palette,
                  coinInk: coinColor(kind, palette),
                  onRemove: () {
                    setState(
                      () => _selectedForSale.removeWhere(
                        (row) => row.instanceId == inst.instanceId,
                      ),
                    );
                    HapticFeedback.lightImpact();
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (_selectedVialsForSale.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SubLabel('VIALS', palette: palette),
          const SizedBox(height: 8),
          for (final vial in _selectedVialsForSale.values) ...[
            _VialLot(
              vial: vial,
              palette: palette,
              coinInk: coinColor(CoinKind.silver, palette),
              onRemove: () {
                setState(() => _selectedVialsForSale.remove(vial.key));
                HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }

  Widget _buildFooter(BracketPalette palette) {
    final (silver, gold) = _totals();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: palette.chromeFill(),
        border: Border(
          top: BorderSide(color: palette.line.withValues(alpha: 0.55)),
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
                  child: BracketButton(
                    label: 'SPECIMENS',
                    primary: false,
                    height: 36,
                    palette: palette,
                    accent: _accent,
                    onTap: _showInstanceBrowser,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BracketButton(
                    label: 'VIALS',
                    primary: false,
                    height: 36,
                    palette: palette,
                    accent: _accent,
                    onTap: _showVialBrowser,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'YOU RECEIVE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 14,
                  children: [
                    if (silver > 0 || gold == 0)
                      CoinAmount(
                        kind: CoinKind.silver,
                        amount: silver,
                        size: 19,
                        color: coinColor(CoinKind.silver, palette),
                      ),
                    if (gold > 0)
                      CoinAmount(
                        kind: CoinKind.gold,
                        amount: gold,
                        size: 19,
                        color: coinColor(CoinKind.gold, palette),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            BracketButton(
              label: 'COMPLETE SALE',
              palette: palette,
              accent: _accent,
              onTap: _confirmSale,
              trailing: Text(
                '$_selectionCount',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── choosing ──────────────────────────────────────────────────────────

  Future<void> _showInstanceBrowser() async {
    final theme = _theme;
    final factions = context.read<FactionService>();
    final saleMult = context
        .read<ConstellationEffectsService>()
        .getAlchemonSaleMultiplier();

    final picked = await Navigator.of(context).push<List<CreatureInstance>>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AllSpecimensPage(
              theme: theme,
              instancePrefsScopeKey: 'alchemon_exchange_specimens',
              title: 'SELECT SPECIMENS',
              selectionMode: true,
              closeReturnsSelection: true,
              selectedInstanceIds: _selectedForSale
                  .map((inst) => inst.instanceId)
                  .toList(),
              // What each one sells for, in the card's corner, so the choice
              // can be made in the grid rather than after.
              cardBadgeBuilder: (inst, species) {
                if (inst.locked) return null;
                final (kind, amount) = _priceOf(
                  inst,
                  species,
                  factions,
                  saleMult,
                );
                return InstanceCardValueBadge(
                  amount: amount,
                  kind: kind,
                  theme: theme,
                );
              },
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
    });
    HapticFeedback.selectionClick();
  }

  Future<void> _showVialBrowser() async {
    final db = context.read<AlchemonsDatabase>();
    final theme = _theme;
    final palette = _palette;
    final items = await db.inventoryDao.watchItemInventory().first;
    final storedEggs = await db.select(db.eggs).get();
    final vials =
        <_VialPickerEntry>[
          ...items
              .where((item) => item.key.startsWith('vial.'))
              .map(_parseVialInventoryItem)
              .whereType<_VialPickerEntry>(),
          ..._parseStoredVialEntries(storedEggs),
        ]..sort((a, b) {
          final sourceCompare = a.source.index.compareTo(b.source.index);
          if (sourceCompare != 0) return sourceCompare;
          final rarityCompare = a.rarity.index.compareTo(b.rarity.index);
          if (rarityCompare != 0) return rarityCompare;
          final groupCompare = a.group.displayName.compareTo(
            b.group.displayName,
          );
          if (groupCompare != 0) return groupCompare;
          return a.displayName.compareTo(b.displayName);
        });

    if (vials.isEmpty) {
      _showToast('No vials to sell.');
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
            final chosen = selectedQty.values.fold(0, (a, b) => a + b);
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
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final vial = vials[index];
                        final qty = selectedQty[vial.key] ?? 0;
                        return _VialPickRow(
                          entry: vial,
                          quantity: qty,
                          palette: palette,
                          onChanged: (next) {
                            setModalState(() => selectedQty[vial.key] = next);
                            HapticFeedback.selectionClick();
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: BracketButton(
                      label: chosen == 0
                          ? 'NONE CHOSEN'
                          : 'PUT $chosen ON THE COUNTER',
                      palette: palette,
                      accent: _accent,
                      // Applying nothing still clears what was there.
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
                        });
                        Navigator.pop(context);
                        HapticFeedback.mediumImpact();
                      },
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

  List<_VialPickerEntry> _parseStoredVialEntries(List<Egg> eggs) {
    return eggs
        .map((egg) {
          final payload = parseEggPayload(egg);
          final rarityName = (payload['rarity'] as String? ?? egg.rarity)
              .toLowerCase();
          final rarity = _vialRarityFromString(rarityName);
          final group = getElementalGroupFromPayload(payload);
          return _VialPickerEntry(
            key: 'storage:${egg.eggId}',
            name: '${group.displayName} Vial',
            group: group,
            rarity: rarity,
            availableQty: 1,
            unitSilverValue: _silverValueForVialRarity(rarity),
            source: _VialSaleSource.storage,
            storageEggIds: [egg.eggId],
          );
        })
        .whereType<_VialPickerEntry>()
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
      case 'mystic':
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

  // ── the sale ──────────────────────────────────────────────────────────

  Future<void> _confirmSale() async {
    if (!_hasSelections) return;
    final (silverTotal, goldTotal) = _totals();
    final specimenCount = _selectedForSale.length;
    final vialCount = _selectedVialCount;

    final confirmed = await showBracketConfirm(
      context,
      palette: _palette,
      accent: _accent,
      title: 'COMPLETE SALE',
      message: 'Sell $_selectionSummary?',
      amounts: [
        if (silverTotal > 0) (CoinKind.silver, silverTotal),
        if (goldTotal > 0) (CoinKind.gold, goldTotal),
      ],
      warning: 'This cannot be undone.',
      confirmLabel: 'SELL',
    );
    if (!confirmed || !mounted) return;

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
      if (silverTotal > 0) await db.currencyDao.addSilver(silverTotal);
      if (goldTotal > 0) await db.currencyDao.addGold(goldTotal);
    });

    if (!mounted) return;
    setState(() {
      _selectedForSale.clear();
      _selectedVialsForSale.clear();
    });
    context.sound(SoundCue.currencyGain);
    HapticFeedback.heavyImpact();

    final what = _soldItemSummary(specimenCount, vialCount);
    final paid = [
      if (silverTotal > 0) '${formatCoins(silverTotal)} silver',
      if (goldTotal > 0) '${formatCoins(goldTotal)} gold',
    ].join(' and ');
    _showToast('Sold $what for $paid.');
  }

  String _soldItemSummary(int specimenCount, int vialCount) {
    final parts = <String>[
      if (specimenCount > 0)
        '$specimenCount specimen${specimenCount == 1 ? '' : 's'}',
      if (vialCount > 0) '$vialCount vial${vialCount == 1 ? '' : 's'}',
    ];
    return parts.join(' and ');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    showGameSnack(context, msg, accent: t.success);
  }
}

// ── pieces ──────────────────────────────────────────────────────────────

Color _rarityColor(String rarity) => switch (rarity.toLowerCase()) {
  'uncommon' => const Color(0xFF34D399),
  'rare' => const Color(0xFF60A5FA),
  'legendary' => const Color(0xFFFFB020),
  'mythic' || 'mystic' => const Color(0xFFE879F9),
  _ => const Color(0xFF9AA4B2),
};

Color _vialRarityColor(VialRarity r) => switch (r) {
  VialRarity.common => const Color(0xFF9AA4B2),
  VialRarity.uncommon => const Color(0xFF34D399),
  VialRarity.rare => const Color(0xFF60A5FA),
  VialRarity.legendary => const Color(0xFFFFB020),
  VialRarity.mythic => const Color(0xFFE879F9),
};

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {required this.color, required this.palette});

  final String text;
  final Color color;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'monospace',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: palette.lineSoft)),
      ],
    );
  }
}

class _SubLabel extends StatelessWidget {
  const _SubLabel(this.text, {required this.palette});

  final String text;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'monospace',
        color: palette.muted,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// One of the two ways in.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.caption,
    required this.accent,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final String caption;
  final Color accent;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.85),
          bracketSize: 12,
          strokeWidth: 1.2,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 22, 12, 20),
          color: palette.surfaceFill(),
          child: Column(
            children: [
              // A soft pool of light under the glyph, never a ring.
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: palette.ink,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: bracketText(context, 12, palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A specimen on the counter: it, what it is, and what it fetches.
class _SpecimenLot extends StatelessWidget {
  const _SpecimenLot({
    required this.instance,
    required this.species,
    required this.kind,
    required this.amount,
    required this.palette,
    required this.coinInk,
    required this.onRemove,
  });

  final CreatureInstance instance;
  final Creature? species;
  final CoinKind kind;
  final int amount;
  final BracketPalette palette;
  final Color coinInk;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final rarity = species?.rarity ?? 'common';
    final rarityColor = _rarityColor(rarity);
    final nick = instance.nickname?.trim();
    final name = nick != null && nick.isNotEmpty
        ? nick
        : species?.name ?? instance.baseId;

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: rarityColor.withValues(alpha: 0.6),
        bracketSize: 9,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              color: palette.bg0.withValues(alpha: palette.isDark ? 0.7 : 0.5),
              child: species?.spriteData == null
                  ? Icon(AppIcons.pets_rounded, color: palette.muted)
                  : InstanceSprite(
                      creature: species!,
                      instance: instance,
                      size: 56,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      14,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        rarity.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: rarityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'LV ${instance.level}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: palette.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      if (instance.isPrismaticSkin) ...[
                        const SizedBox(width: 8),
                        const Text(
                          'PRISMATIC',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFE879F9),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CoinAmount(kind: kind, amount: amount, size: 15, color: coinInk),
            const SizedBox(width: 10),
            BracketIconButton(
              icon: AppIcons.close_rounded,
              palette: palette,
              color: const Color(0xFFE57373),
              size: 30,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// A vial on the counter.
class _VialLot extends StatelessWidget {
  const _VialLot({
    required this.vial,
    required this.palette,
    required this.coinInk,
    required this.onRemove,
  });

  final _SelectedVialSale vial;
  final BracketPalette palette;
  final Color coinInk;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final rarityColor = _vialRarityColor(vial.rarity);
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: vial.group.color.withValues(alpha: 0.6),
        bracketSize: 9,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              color: palette.bg0.withValues(alpha: palette.isDark ? 0.7 : 0.5),
              child: ExtractionVialOrb(vial: vial.previewVial, size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vial.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bracketText(
                      context,
                      14,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        vial.rarity.badgeLabel.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: rarityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      // "×1" on a single vial is noise; only a real stack
                      // needs a count.
                      if (vial.selectedQty > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '×${vial.selectedQty}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: palette.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CoinAmount(
              kind: CoinKind.silver,
              amount: vial.totalSilverValue,
              size: 15,
              color: coinInk,
            ),
            const SizedBox(width: 10),
            BracketIconButton(
              icon: AppIcons.close_rounded,
              palette: palette,
              color: const Color(0xFFE57373),
              size: 30,
              onTap: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// A vial in the picker, and how many of it to sell.
class _VialPickRow extends StatelessWidget {
  const _VialPickRow({
    required this.entry,
    required this.quantity,
    required this.palette,
    required this.onChanged,
  });

  final _VialPickerEntry entry;
  final int quantity;
  final BracketPalette palette;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final chosen = quantity > 0;
    final color = entry.group.color;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: chosen ? color : palette.line.withValues(alpha: 0.6),
        bracketSize: 9,
        strokeWidth: chosen ? 1.3 : 1,
      ),
      child: Container(
        color: palette.surfaceFill(),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ExtractionVialOrb(vial: entry.previewVial, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.displayName,
                    style: bracketText(
                      context,
                      14,
                      palette.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.rarity.badgeLabel.toUpperCase()}  ·  '
                    '${entry.sourceLabel.toUpperCase()}'
                    '${entry.availableQty > 1 ? '  ·  ${entry.availableQty} HELD' : ''}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _vialRarityColor(entry.rarity),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${entry.unitSilverValue} silver each',
                    style: bracketText(context, 12, palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // A stepper over a stack you only own one of is three controls
            // to express a yes/no. Vials off storage eggs are always single;
            // inventory vials genuinely stack, so those keep the counter.
            if (entry.availableQty <= 1)
              _Check(
                on: chosen,
                color: color,
                palette: palette,
                onTap: () => onChanged(chosen ? 0 : 1),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Step(
                    icon: AppIcons.remove_rounded,
                    enabled: quantity > 0,
                    palette: palette,
                    onTap: () => onChanged(quantity - 1),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Step(
                    icon: AppIcons.add_rounded,
                    enabled: quantity < entry.availableQty,
                    palette: palette,
                    onTap: () => onChanged(quantity + 1),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({
    required this.on,
    required this.color,
    required this.palette,
    required this.onTap,
  });

  final bool on;
  final Color color;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: on ? color : palette.line,
          bracketSize: 6,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 32,
          height: 32,
          color: on ? color.withValues(alpha: 0.16) : Colors.transparent,
          child: on
              ? Icon(AppIcons.check_rounded, size: 17, color: color)
              : null,
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.enabled,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(enabled ? onTap : null),
        child: CustomPaint(
          painter: BracketFramePainter(color: palette.line, bracketSize: 6),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            color: palette.surfaceMutedFill(),
            child: Icon(icon, size: 16, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

// ── data ────────────────────────────────────────────────────────────────

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

  String get displayName => '${group.displayName} Vial';

  ExtractionVial get previewVial => ExtractionVial(
    id: key,
    name: displayName,
    group: group,
    rarity: rarity,
    quantity: availableQty,
    price: null,
  );
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

  String get displayName => '${group.displayName} Vial';

  ExtractionVial get previewVial => ExtractionVial(
    id: key,
    name: displayName,
    group: group,
    rarity: rarity,
    quantity: selectedQty,
    price: null,
  );
}
