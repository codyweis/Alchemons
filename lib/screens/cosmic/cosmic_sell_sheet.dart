// lib/screens/cosmic/cosmic_sell_sheet.dart
//
// Bottom-sheet "Cosmic Market" — lets players sell alchemons
// that were summoned from planets (source == 'planet_summon')
// or have a prismatic skin.
//
// Pricing by rarity (base gold):
//   Common   →  5 gold
//   Uncommon → 10 gold
//   Rare     → 15 gold
//   Mythic   → 20 gold
//   Variant  → 15 gold
//   Prismatic bonus: +10 gold base
//   Planet summon bonus: +50% base value
//
// Currency multipliers:
//   Silver → 10x
//   Shards → 5x
//
// Random ±20 % multiplier on every price.
// Daily bonus: one random creature gets a 50 % price boost.
// Player picks currency (silver or shards).

import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kCyan = Color(0xFF00E5FF);
const _kBg = Color(0xFF0A0E1A);
const _kCard = Color(0xFF121828);
const _kCosmicSellRewardMultiplier = 5;

/// Base gold value by rarity.
int _baseGoldForRarity(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'common':
      return 5;
    case 'uncommon':
      return 10;
    case 'rare':
      return 15;
    case 'mythic':
    case 'legendary':
      return 20;
    case 'variant':
      return 15;
    default:
      return 5;
  }
}

/// Currency the player chose for the sale.
enum _SaleCurrency { silver, shards }

/// Currency multiplier relative to base gold price.
int _currencyMultiplier(_SaleCurrency c) {
  switch (c) {
    case _SaleCurrency.silver:
      return 10;
    case _SaleCurrency.shards:
      return 5;
  }
}

/// Planet groupings — maps planet display name → set of matching element types.
const Map<String, Set<String>> _kPlanetElements = {
  'Pyrathis': {'Fire'},
  'Magmora': {'Lava'},
  'Voltara': {'Lightning'},
  'Aquathos': {'Water'},
  'Glaceron': {'Ice'},
  'Vaporis': {'Steam'},
  'Terragrim': {'Earth'},
  'Mireholm': {'Mud'},
  'Cindrath': {'Dust'},
  'Lumishara': {'Crystal'},
  'Zephyria': {'Air'},
  'Verdanthos': {'Plant'},
  'Toxivyre': {'Poison'},
  'Etherion': {'Spirit'},
  'Nythralor': {'Dark'},
  'Solanthis': {'Light'},
  'Hemavorn': {'Blood'},
};

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class CosmicSellSheet extends StatefulWidget {
  const CosmicSellSheet({super.key});

  /// Convenience opener.
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CosmicSellSheet(),
  );

  @override
  State<CosmicSellSheet> createState() => _CosmicSellSheetState();
}

class _CosmicSellSheetState extends State<CosmicSellSheet> {
  List<_SellableCreature> _allSellable = [];
  List<_SellableCreature> _filtered = [];
  bool _loading = true;
  _SaleCurrency _currency = _SaleCurrency.silver;

  // Filters
  bool _filterPrismatic = false;
  String? _filterPlanet; // null = all, otherwise planet display name

  /// Today's bonus creature base-id (seed = day number).
  late final String? _dailyBonusBaseId;

  @override
  void initState() {
    super.initState();
    _computeDailyBonus();
    _loadCreatures();
  }

  void _computeDailyBonus() {
    final repo = context.read<CreatureCatalog>();
    final daySeed =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 86400000; // day index
    final rng = Random(daySeed ^ 0xC057);
    final all = repo.creatures;
    if (all.isEmpty) {
      _dailyBonusBaseId = null;
      return;
    }
    _dailyBonusBaseId = all[rng.nextInt(all.length)].id;
  }

  Future<void> _loadCreatures() async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final instances = await db.creatureDao.getAllInstances();

    // Filter: only planet summons OR prismatic
    final eligible = instances.where(
      (i) => i.source == 'planet_summon' || i.isPrismaticSkin,
    );

    // Also exclude locked creatures
    final filtered = eligible.where((i) => !i.locked).toList();

    final rng = Random();
    final list = <_SellableCreature>[];
    for (final inst in filtered) {
      final base = repo.getCreatureById(inst.baseId);
      if (base == null) continue;

      final baseGold = _baseGoldForRarity(base.rarity);
      final prismaticBonus = inst.isPrismaticSkin ? 10 : 0;
      final sourceMultiplier = inst.source == 'planet_summon' ? 1.5 : 1.0;
      final raw = ((baseGold + prismaticBonus) * sourceMultiplier).round();

      // Random ±20 % multiplier
      final multiplier = 0.8 + rng.nextDouble() * 0.4;
      var price = (raw * multiplier).round().clamp(1, 999);

      // Daily 50 % bonus
      final isDailyBonus = inst.baseId == _dailyBonusBaseId;
      if (isDailyBonus) {
        price = (price * 1.5).round();
      }

      list.add(
        _SellableCreature(
          instance: inst,
          creature: base,
          basePrice: price,
          isDailyBonus: isDailyBonus,
        ),
      );
    }

    // Sort daily bonus first, then by price descending
    list.sort((a, b) {
      if (a.isDailyBonus && !b.isDailyBonus) return -1;
      if (!a.isDailyBonus && b.isDailyBonus) return 1;
      return b.basePrice.compareTo(a.basePrice);
    });

    if (!mounted) return;
    setState(() {
      _allSellable = list;
      _applyFilters();
      _loading = false;
    });
  }

  void _applyFilters() {
    var result = _allSellable.toList();

    if (_filterPrismatic) {
      result = result.where((s) => s.instance.isPrismaticSkin).toList();
    }

    if (_filterPlanet != null) {
      final elements = _kPlanetElements[_filterPlanet] ?? <String>{};
      result = result
          .where((s) => s.creature.types.any((t) => elements.contains(t)))
          .toList();
    }

    _filtered = result;
  }

  bool _usesGoldPayout(_SellableCreature item) => item.instance.isPrismaticSkin;

  int _goldPayoutFor(_SellableCreature item) =>
      (item.basePrice / 12).ceil().clamp(1, 6);

  int _displayPriceFor(_SellableCreature item) {
    final basePayout = _usesGoldPayout(item)
        ? _goldPayoutFor(item)
        : item.displayPrice(_currency);
    if (_usesGoldPayout(item) || _currency == _SaleCurrency.silver) {
      return basePayout * _kCosmicSellRewardMultiplier;
    }
    return basePayout;
  }

  String _currencyLabelFor(_SellableCreature item) =>
      _usesGoldPayout(item) ? 'Gold' : _currencyLabel;

  IconData _currencyIconFor(_SellableCreature item) =>
      _usesGoldPayout(item) ? Icons.hexagon : _currencyIcon;

  Color _currencyColorFor(_SellableCreature item) =>
      _usesGoldPayout(item) ? const Color(0xFFFFD700) : _currencyColor;

  String get _currencyLabel {
    switch (_currency) {
      case _SaleCurrency.silver:
        return 'Silver';
      case _SaleCurrency.shards:
        return 'Shards';
    }
  }

  IconData get _currencyIcon {
    switch (_currency) {
      case _SaleCurrency.silver:
        return Icons.monetization_on;
      case _SaleCurrency.shards:
        return Icons.diamond;
    }
  }

  Color get _currencyColor {
    switch (_currency) {
      case _SaleCurrency.silver:
        return const Color(0xFFC0C0C0);
      case _SaleCurrency.shards:
        return const Color(0xFFAB47BC);
    }
  }

  Future<void> _sell(_SellableCreature item) async {
    final displayPrice = _displayPriceFor(item);
    final payoutLabel = _currencyLabelFor(item);
    final payoutColor = _currencyColorFor(item);
    // Confirm
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCard,
        title: Text(
          'Sell ${item.creature.name}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'You will receive $displayPrice $payoutLabel.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('SELL', style: TextStyle(color: payoutColor)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    await db.creatureDao.deleteInstances([item.instance.instanceId]);

    if (_usesGoldPayout(item)) {
      await db.currencyDao.addGold(displayPrice);
    } else {
      switch (_currency) {
        case _SaleCurrency.silver:
          await db.currencyDao.addSilver(displayPrice);
          break;
        case _SaleCurrency.shards:
          await db.currencyDao.addResource(
            'wallet_astral_shards',
            displayPrice,
          );
          break;
      }
    }

    HapticFeedback.heavyImpact();
    setState(() {
      _allSellable.remove(item);
      _applyFilters();
    });
  }

  // ── build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Title
            const Text(
              'COSMIC MARKET',
              style: TextStyle(
                color: _kCyan,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sell cosmic & prismatic Alchemons',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Only prismatic and Alchemons acquired from planets can be sold here',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 12),

            // Daily bonus banner
            if (_dailyBonusBaseId != null) _buildDailyBonusBanner(),

            // Filters row
            _buildFilterRow(),

            // Currency selector
            _buildCurrencySelector(),

            const SizedBox(height: 8),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _kCyan),
                    )
                  : _allSellable.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront,
                            color: Colors.white.withValues(alpha: 0.2),
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _filterPrismatic || _filterPlanet != null
                                ? 'No matches for this filter'
                                : 'No eligible alchemons to sell',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Only planet-summoned or prismatic\ncreatures can be sold here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.25),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── sub-widgets ────────────────────────────────────────

  Widget _buildDailyBonusBanner() {
    final repo = context.read<CreatureCatalog>();
    final bonusCreature = repo.getCreatureById(_dailyBonusBaseId!);
    if (bonusCreature == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E5FF).withValues(alpha: 0.15),
            const Color(0xFF76FF03).withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF76FF03).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            color: Color(0xFF76FF03),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'DAILY BONUS +30%  ',
                    style: TextStyle(
                      color: Color(0xFF76FF03),
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                  ),
                  TextSpan(
                    text: bonusCreature.name,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    // Collect planet names that actually have sellable creatures
    final activePlanets = <String>{};
    for (final s in _allSellable) {
      if (s.instance.source != 'planet_summon') continue;
      for (final entry in _kPlanetElements.entries) {
        if (s.creature.types.any((t) => entry.value.contains(t))) {
          activePlanets.add(entry.key);
        }
      }
    }
    final hasPrismatic = _allSellable.any((s) => s.instance.isPrismaticSkin);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: SizedBox(
        height: 30,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Prismatic filter
            if (hasPrismatic)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _filterChip(
                  label: 'PRISMATIC',
                  icon: Icons.auto_awesome,
                  isActive: _filterPrismatic,
                  color: const Color(0xFFE040FB),
                  onTap: () => setState(() {
                    _filterPrismatic = !_filterPrismatic;
                    _applyFilters();
                  }),
                ),
              ),
            // Planet filters
            for (final pName in activePlanets) ...[
              _filterChip(
                label: pName.toUpperCase(),
                icon: Icons.public,
                isActive: _filterPlanet == pName,
                color: _planetColor(pName),
                onTap: () => setState(() {
                  _filterPlanet = _filterPlanet == pName ? null : pName;
                  _applyFilters();
                }),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool isActive,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: isActive ? color : Colors.white38),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? color : Colors.white38,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _planetColor(String planetName) {
    switch (planetName) {
      case 'Pyrathis':
        return const Color(0xFFFF6F00);
      case 'Magmora':
        return const Color(0xFFFF3D00);
      case 'Voltara':
        return const Color(0xFFFFEB3B);
      case 'Aquathos':
        return const Color(0xFF2196F3);
      case 'Glaceron':
        return const Color(0xFFB3E5FC);
      case 'Vaporis':
        return const Color(0xFF90CAF9);
      case 'Terragrim':
        return const Color(0xFF8D6E63);
      case 'Mireholm':
        return const Color(0xFF795548);
      case 'Cindrath':
        return const Color(0xFFBCAAA4);
      case 'Lumishara':
        return const Color(0xFF4DD0E1);
      case 'Zephyria':
        return const Color(0xFF81D4FA);
      case 'Verdanthos':
        return const Color(0xFF66BB6A);
      case 'Toxivyre':
        return const Color(0xFF9C27B0);
      case 'Etherion':
        return const Color(0xFFCE93D8);
      case 'Nythralor':
        return const Color(0xFF455A64);
      case 'Solanthis':
        return const Color(0xFFFFF176);
      case 'Hemavorn':
        return const Color(0xFFEF5350);
      default:
        return Colors.white54;
    }
  }

  Widget _buildCurrencySelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Text(
            'PAY IN:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 8),
          for (final cur in _SaleCurrency.values) ...[
            _currencyChip(cur),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _currencyChip(_SaleCurrency cur) {
    final selected = _currency == cur;
    final label = switch (cur) {
      _SaleCurrency.silver => 'Silver',
      _SaleCurrency.shards => 'Shards',
    };
    final color = switch (cur) {
      _SaleCurrency.silver => const Color(0xFFC0C0C0),
      _SaleCurrency.shards => const Color(0xFFAB47BC),
    };
    return GestureDetector(
      onTap: () => setState(() => _currency = cur),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_SellableCreature item) {
    final c = item.creature;
    final inst = item.instance;
    final price = _displayPriceFor(item);
    final priceIcon = _currencyIconFor(item);
    final priceColor = _currencyColorFor(item);

    // Element color
    final eColor = _typeColor(c.types.isNotEmpty ? c.types.first : '');

    // Visuals
    final visuals = visualsFromInstance(c, inst);
    final hasSprite = c.spriteData != null;

    return GestureDetector(
      onLongPress: () => _showDetails(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isDailyBonus
                ? const Color(0xFF76FF03).withValues(alpha: 0.5)
                : eColor.withValues(alpha: 0.25),
          ),
          boxShadow: [
            if (item.isDailyBonus)
              BoxShadow(
                color: const Color(0xFF76FF03).withValues(alpha: 0.1),
                blurRadius: 12,
              ),
          ],
        ),
        child: Row(
          children: [
            // Sprite
            SizedBox(
              width: 48,
              height: 48,
              child: hasSprite
                  ? CreatureSprite(
                      spritePath: c.spriteData!.spriteSheetPath,
                      totalFrames: c.spriteData!.totalFrames,
                      rows: c.spriteData!.rows,
                      frameSize: Vector2(
                        c.spriteData!.frameWidth.toDouble(),
                        c.spriteData!.frameHeight.toDouble(),
                      ),
                      stepTime: c.spriteData!.frameDurationMs / 1000.0,
                      scale: visuals.scale,
                      saturation: visuals.saturation,
                      brightness: visuals.brightness,
                      hueShift: visuals.hueShiftDeg,
                      isPrismatic: visuals.isPrismatic,
                      tint: visuals.tint,
                      alchemyEffect: visuals.alchemyEffect,
                      variantFaction: visuals.variantFaction,
                      effectSlotSize: 48,
                    )
                  : ClipOval(
                      child: Image.asset(
                        'assets/images/${c.image}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.catching_pokemon,
                          color: eColor,
                          size: 24,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inst.nickname ?? c.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isDailyBonus)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF76FF03,
                              ).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '+30%',
                              style: TextStyle(
                                color: Color(0xFF76FF03),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        c.rarity.toUpperCase(),
                        style: TextStyle(
                          color: _rarityColor(c.rarity),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        c.types.join(' / '),
                        style: TextStyle(
                          color: eColor.withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                      ),
                      if (inst.source == 'planet_summon') ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.public,
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Price + Sell button
            GestureDetector(
              onTap: () => _sell(item),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: priceColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: priceColor.withValues(alpha: 0.4)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(priceIcon, size: 12, color: priceColor),
                        const SizedBox(width: 3),
                        Text(
                          '$price',
                          style: TextStyle(
                            color: priceColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'SELL',
                      style: TextStyle(
                        color: priceColor.withValues(alpha: 0.7),
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  }

  void _showDetails(_SellableCreature item) {
    CreatureDetailsDialog.show(
      context,
      item.creature,
      true,
      instanceId: item.instance.instanceId,
    );
  }

  // ── helpers ────────────────────────────────────────────

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return const Color(0xFFFF6F00);
      case 'water':
        return const Color(0xFF2196F3);
      case 'earth':
        return const Color(0xFF8D6E63);
      case 'air':
      case 'wind':
        return const Color(0xFF81D4FA);
      case 'spirit':
        return const Color(0xFFCE93D8);
      case 'crystal':
        return const Color(0xFF4DD0E1);
      case 'shadow':
        return const Color(0xFF455A64);
      case 'nature':
      case 'plant':
        return const Color(0xFF66BB6A);
      case 'electric':
      case 'lightning':
        return const Color(0xFFFFEB3B);
      case 'ice':
        return const Color(0xFFB3E5FC);
      default:
        return Colors.white54;
    }
  }

  static Color _rarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return const Color(0xFF90A4AE);
      case 'uncommon':
        return const Color(0xFF66BB6A);
      case 'rare':
        return const Color(0xFF42A5F5);
      case 'mythic':
      case 'legendary':
        return const Color(0xFFFFD740);
      case 'variant':
        return const Color(0xFFCE93D8);
      default:
        return Colors.white54;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────

class _SellableCreature {
  final CreatureInstance instance;
  final Creature creature;
  final int basePrice; // gold base
  final bool isDailyBonus;

  _SellableCreature({
    required this.instance,
    required this.creature,
    required this.basePrice,
    required this.isDailyBonus,
  });

  /// Price adjusted for the selected currency multiplier.
  int displayPrice(_SaleCurrency currency) =>
      basePrice * _currencyMultiplier(currency);
}
