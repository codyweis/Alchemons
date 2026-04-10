// lib/widgets/instance_widgets/instance_sheet_components.dart
//
// REDESIGNED INSTANCE SHEET COMPONENTS
// Aesthetic: Scorched Forge — dark metal cards, amber accents, monospace
// All logic, props, and public API preserved exactly.
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/fast_long_press_detector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

String _displayVariantFaction(String faction) {
  final trimmed = faction.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.toLowerCase() == 'bloodborn') return 'Bloodborn';
  return trimmed[0].toUpperCase() + trimmed.substring(1);
}

// ──────────────────────────────────────────────────────────────────────────────
// INSTANCE CARD
// ──────────────────────────────────────────────────────────────────────────────

class InstanceCard extends StatelessWidget {
  final Creature species;
  final CreatureInstance instance;
  final FactionTheme theme;
  final InstanceDetailMode detailMode;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  final bool isSelected;
  final int? selectionNumber;
  final SortBy? activeSortBy;

  final Duration? harvestDuration;
  final int Function(CreatureInstance)? calculateHarvestRate;

  const InstanceCard({
    super.key,
    required this.species,
    required this.instance,
    required this.theme,
    required this.detailMode,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionNumber,
    this.activeSortBy,
    this.harvestDuration,
    this.calculateHarvestRate,
  });

  bool get _isHarvestMode =>
      harvestDuration != null && calculateHarvestRate != null;

  // Selection accent colors: first=amber, second=teal, third=purple
  Color _selectionColor(ForgeTokens t) => switch (selectionNumber) {
    1 => t.amber,
    2 => t.teal,
    3 => const Color(0xFFA855F7),
    _ => t.success,
  };

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final hasPotentialAnalyzer = context
        .watch<ConstellationEffectsService>()
        .hasPotentialAnalyzer();
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = species.spriteData;
    final rarityColor = BreedConstants.getRarityColor(species.rarity);
    final sortBadgeColor = switch (activeSortBy?.statFamily) {
      'speed' => const Color(0xFFFDE047),
      'intelligence' => const Color(0xFFC084FC),
      'strength' => const Color(0xFFF87171),
      'beauty' => const Color(0xFFF9A8D4),
      _ => t.amberBright,
    };
    final showSortBadge = activeSortBy?.isStatSort == true;
    final topLeftLabel = showSortBadge
        ? 'LV ${instance.level} ${activeSortBy!.shortLabel} ${activeSortBy!.valueForInstance(instance).toStringAsFixed(1)}'
        : 'LV ${instance.level}';
    final topLeftTextColor = showSortBadge
        ? t.readableAccent(sortBadgeColor)
        : t.amberBright;
    final topLeftBorderColor = showSortBadge
        ? topLeftTextColor.withValues(alpha: 0.85)
        : rarityColor.withValues(alpha: 0.85);

    final bottomBlock = _isHarvestMode
        ? _HarvestBlock(
            instance: instance,
            harvestDuration: harvestDuration!,
            calculateRate: calculateHarvestRate!,
            isSelected: isSelected,
            selectionNumber: selectionNumber,
          )
        : switch (detailMode) {
            InstanceDetailMode.info => _StatsBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
              showPotentials: hasPotentialAnalyzer,
            ),
            InstanceDetailMode.stats => _StatsBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
              showPotentials: hasPotentialAnalyzer,
            ),
            InstanceDetailMode.genetics => _GeneticsBlock(
              instance: instance,
              genetics: genetics,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
            ),
          };

    final selColor = isSelected ? _selectionColor(t) : t.borderDim;

    return FastLongPressDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? selColor.withValues(alpha: 0.08) : t.bg2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selColor, width: isSelected ? 1.5 : 1.0),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            children: [
              // Scanline texture
              Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),

              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Sprite area ──────────────────────────────────────
                    Expanded(
                      child: Stack(
                        children: [
                          Center(
                            child: RepaintBoundary(
                              child: sd != null
                                  ? InstanceSprite(
                                      creature: species,
                                      instance: instance,
                                      size: 72,
                                    )
                                  : Image.asset(
                                      species.image,
                                      fit: BoxFit.contain,
                                    ),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            left: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: t.bg0.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(color: topLeftBorderColor),
                              ),
                              child: Text(
                                topLeftLabel,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: topLeftTextColor,
                                  fontSize: showSortBadge ? 7 : 8,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          if (instance.isFavorite ||
                              (isSelected && selectionNumber != null))
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (instance.isFavorite)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: t.bg0.withValues(alpha: 0.82),
                                        borderRadius: BorderRadius.circular(2),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFE91E63,
                                          ).withValues(alpha: 0.45),
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.star_rounded,
                                        size: 10,
                                        color: Color(0xFFE91E63),
                                      ),
                                    ),
                                  if (instance.isFavorite &&
                                      isSelected &&
                                      selectionNumber != null)
                                    const SizedBox(height: 4),
                                  if (isSelected && selectionNumber != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.merge_type_rounded,
                                            color: t.bg0,
                                            size: 9,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$selectionNumber',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              color: t.bg0,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    if (!_isHarvestMode &&
                        detailMode == InstanceDetailMode.genetics) ...[
                      _CardNameLine(
                        instance: instance,
                        creatureName: species.name,
                        trailing: _CompactStaminaSummary(instance: instance),
                      ),
                      const SizedBox(height: 4),
                    ],

                    bottomBlock,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// STATS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _StatsBlock extends StatelessWidget {
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;
  final bool showPotentials;

  const _StatsBlock({
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
    required this.showPotentials,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 4),
        ],
        _CardNameLine(
          instance: instance,
          creatureName: creatureName,
          trailing: _CompactStaminaSummary(instance: instance),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                color: const Color(0xFFFDE047),
                label: 'SPD',
                currentValue: instance.statSpeed,
                potentialValue: showPotentials
                    ? instance.statSpeedPotential
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _StatTile(
                color: const Color(0xFFC084FC),
                label: 'INT',
                currentValue: instance.statIntelligence,
                potentialValue: showPotentials
                    ? instance.statIntelligencePotential
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                color: const Color(0xFFF87171),
                label: 'STR',
                currentValue: instance.statStrength,
                potentialValue: showPotentials
                    ? instance.statStrengthPotential
                    : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _StatTile(
                color: const Color(0xFFF9A8D4),
                label: 'BEA',
                currentValue: instance.statBeauty,
                potentialValue: showPotentials
                    ? instance.statBeautyPotential
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final Color color;
  final String label;
  final double currentValue;
  final double? potentialValue;

  const _StatTile({
    required this.color,
    required this.label,
    required this.currentValue,
    required this.potentialValue,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final displayColor = t.readableAccent(color);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: t.bg0.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: displayColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: displayColor.withValues(alpha: 0.8),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  potentialValue == null
                      ? currentValue.toStringAsFixed(1)
                      : '${currentValue.toStringAsFixed(1)} / ${potentialValue!.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: displayColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GENETICS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _GeneticsBlock extends StatelessWidget {
  final CreatureInstance instance;
  final Genetics? genetics;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _GeneticsBlock({
    required this.instance,
    required this.genetics,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  String _sizeName() =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';
  String _tintName() =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final variant = instance.variantFaction?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 3),
        ],
        if (variant.isNotEmpty) ...[
          _MiniRow(color: t.teal, label: _displayVariantFaction(variant)),
          const SizedBox(height: 2),
        ],
        _MiniRow(color: t.amberBright, label: _sizeName().toUpperCase()),
        const SizedBox(height: 2),
        _MiniRow(color: t.amberBright, label: _tintName().toUpperCase()),
        if (instance.natureId?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          _MiniRow(
            color: t.textSecondary,
            label: instance.natureId!.toUpperCase(),
          ),
        ],
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// HARVEST BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _HarvestBlock extends StatelessWidget {
  final CreatureInstance instance;
  final Duration harvestDuration;
  final int Function(CreatureInstance) calculateRate;
  final bool isSelected;
  final int? selectionNumber;

  const _HarvestBlock({
    required this.instance,
    required this.harvestDuration,
    required this.calculateRate,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final rate = calculateRate(instance);
    final total = rate * harvestDuration.inMinutes;

    final genetics = decodeGenetics(instance.geneticsJson);
    final sizeKey = genetics?.get('size') ?? 'normal';
    final sizeName = sizeLabels[sizeKey] ?? sizeKey;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _InlineStaminaSummary(instance: instance),
        const SizedBox(height: 4),
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 3),
        ],
        // Total output row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox.shrink(),
            Row(
              children: [
                Icon(Icons.inventory_2_rounded, size: 10, color: t.amberBright),
                const SizedBox(width: 3),
                Text(
                  '$total',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniRow(color: t.textSecondary, label: sizeName.toUpperCase()),
            if (instance.natureId?.isNotEmpty == true)
              _MiniRow(
                color: t.textSecondary,
                label: instance.natureId!.toUpperCase(),
              ),
          ],
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SHARED MINI WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

class _MiniRow extends StatelessWidget {
  final Color color;
  final String label;
  const _MiniRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ParentChip extends StatelessWidget {
  final int selectionNumber;
  const _ParentChip({required this.selectionNumber});

  Color get _color => switch (selectionNumber) {
    1 => const Color(0xFFD97706),
    2 => const Color(0xFF0EA5E9),
    3 => const Color(0xFFA855F7),
    _ => const Color(0xFF16A34A),
  };

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.merge_type_rounded, color: c, size: 9),
          const SizedBox(width: 3),
          Text(
            'PARENT $selectionNumber',
            style: TextStyle(
              fontFamily: 'monospace',
              color: c,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrismaticChip extends StatelessWidget {
  const _PrismaticChip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFA855F7).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(
        color: const Color(0xFFA855F7).withValues(alpha: 0.45),
      ),
    ),
    child: const Text(
      'PRISMATIC',
      style: TextStyle(
        fontFamily: 'monospace',
        color: Color(0xFFE879F9),
        fontSize: 8,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _CardNameLine extends StatelessWidget {
  const _CardNameLine({
    required this.instance,
    required this.creatureName,
    this.trailing,
  });

  final CreatureInstance instance;
  final String creatureName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final hasNick = instance.nickname?.trim().isNotEmpty == true;
    final nick = hasNick ? instance.nickname!.trim() : creatureName;

    return Row(
      children: [
        Expanded(
          child: Text(
            nick.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ],
    );
  }
}

class _CompactStaminaSummary extends StatelessWidget {
  const _CompactStaminaSummary({required this.instance});

  final CreatureInstance instance;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final stamina = context.read<StaminaService>();
    final state = stamina.computeState(instance);
    final bars = state.bars.clamp(0, state.max);
    final max = state.max <= 0 ? 1 : state.max;
    final textColor = t.readableAccent(const Color(0xFF86EFAC));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StaminaBar(
          current: bars,
          max: max,
          size: 5,
          gap: 1.5,
          fillColor: const Color(0xFF22C55E),
          emptyColor: Colors.black26,
          radius: const BorderRadius.all(Radius.circular(2)),
        ),
        const SizedBox(width: 4),
        Text(
          '$bars/$max',
          style: TextStyle(
            fontFamily: 'monospace',
            color: textColor,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _InlineStaminaSummary extends StatelessWidget {
  const _InlineStaminaSummary({required this.instance});

  final CreatureInstance instance;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final stamina = context.read<StaminaService>();
    final state = stamina.computeState(instance);
    final bars = state.bars.clamp(0, state.max);
    final max = state.max <= 0 ? 1 : state.max;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, size: 12, color: t.success),
        const SizedBox(width: 4),
        StaminaBar(
          current: bars,
          max: max,
          size: 7,
          gap: 2,
          fillColor: t.success,
          emptyColor: t.bg0,
          radius: const BorderRadius.all(Radius.circular(2)),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// EMPTY STATE  (public)
// ──────────────────────────────────────────────────────────────────────────────

class InstancesEmptyState extends StatelessWidget {
  final Color primaryColor;
  final bool hasFilters;

  const InstancesEmptyState({
    super.key,
    required this.primaryColor,
    this.hasFilters = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: t.borderAccent.withValues(alpha: 0.5),
                ),
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.science_outlined,
                size: 36,
                color: t.amberBright.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              hasFilters ? 'NO MATCHING SPECIMENS' : 'NO SPECIMENS CONTAINED',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              hasFilters
                  ? 'Adjust filters or clear your search'
                  : 'Acquire specimens through fusion,\nrift portals, or planet summons',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 10,
                letterSpacing: 0.3,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
