// lib/widgets/instance_widgets/instance_sheet_components.dart
//
// REDESIGNED INSTANCE SHEET COMPONENTS
// Aesthetic: Scorched Forge — dark metal cards, amber accents, monospace
// All logic, props, and public API preserved exactly.
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/creature_sprite.dart';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withOpacity(0.07);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
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
    final genetics = decodeGenetics(instance.geneticsJson);
    final sd = species.spriteData;

    final bottomBlock = _isHarvestMode
        ? _HarvestBlock(
            instance: instance,
            harvestDuration: harvestDuration!,
            calculateRate: calculateHarvestRate!,
            isSelected: isSelected,
            selectionNumber: selectionNumber,
          )
        : switch (detailMode) {
            InstanceDetailMode.info => _InfoBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
              creatureName: species.name,
            ),
            InstanceDetailMode.stats => _StatsBlock(
              instance: instance,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
            ),
            InstanceDetailMode.genetics => _GeneticsBlock(
              instance: instance,
              genetics: genetics,
              isSelected: isSelected,
              selectionNumber: selectionNumber,
            ),
          };

    final selColor = isSelected ? _selectionColor(t) : t.borderDim;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? selColor.withOpacity(0.08) : t.bg2,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selColor, width: isSelected ? 1.5 : 1.0),
          boxShadow: isSelected
              ? [BoxShadow(color: selColor.withOpacity(0.15), blurRadius: 10)]
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
                          // Selection number badge — top right
                          if (isSelected && selectionNumber != null)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
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
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 5),

                    // Stamina for genetics mode
                    if (!_isHarvestMode &&
                        detailMode == InstanceDetailMode.genetics) ...[
                      ExcludeSemantics(
                        child: StaminaBadge(
                          instanceId: instance.instanceId,
                          showCountdown: true,
                        ),
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
// INFO BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _InfoBlock extends StatelessWidget {
  final CreatureInstance instance;
  final bool isSelected;
  final int? selectionNumber;
  final String creatureName;

  const _InfoBlock({
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
    required this.creatureName,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final hasNick = instance.nickname?.trim().isNotEmpty == true;
    final nick = hasNick ? instance.nickname!.trim() : creatureName;
    final variant = instance.variantFaction ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 4),
        ],
        // Name + lock
        Row(
          children: [
            Icon(
              instance.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 10,
              color: instance.locked ? t.amberBright : t.textMuted,
            ),
            const SizedBox(width: 4),
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
          ],
        ),
        // Variant
        if (variant.isNotEmpty) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(Icons.science_rounded, size: 10, color: t.teal),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  variant.trim().toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.teal,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: StaminaBadge(
            instanceId: instance.instanceId,
            showCountdown: true,
          ),
        ),
        const SizedBox(height: 3),
        // Level
        _MiniRow(
          icon: Icons.bar_chart_rounded,
          color: t.amberBright,
          label: 'LV ${instance.level}',
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 3),
          const _PrismaticChip(),
        ],
      ],
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

  const _StatsBlock({
    required this.instance,
    required this.isSelected,
    required this.selectionNumber,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        _MiniRow(
          icon: Icons.bar_chart_rounded,
          color: t.amberBright,
          label: 'LV ${instance.level}  ·  ${instance.xp.toInt()} XP',
        ),
        const SizedBox(height: 3),
        _StatLine(
          icon: Icons.speed,
          color: const Color(0xFFFDE047),
          label: 'SPD',
          value: instance.statSpeed,
        ),
        _StatLine(
          icon: Icons.psychology,
          color: const Color(0xFFC084FC),
          label: 'INT',
          value: instance.statIntelligence,
        ),
        _StatLine(
          icon: Icons.fitness_center,
          color: const Color(0xFFF87171),
          label: 'STR',
          value: instance.statStrength,
        ),
        _StatLine(
          icon: Icons.favorite,
          color: const Color(0xFFF9A8D4),
          label: 'BEA',
          value: instance.statBeauty,
        ),
        if (instance.isPrismaticSkin == true) ...[
          const SizedBox(height: 3),
          const _PrismaticChip(),
        ],
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double value;
  const _StatLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 1),
    child: Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Text(
          '$label  ${value.toStringAsFixed(0)}',
          style: TextStyle(
            fontFamily: 'monospace',
            color: color.withOpacity(0.9),
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// GENETICS BLOCK
// ──────────────────────────────────────────────────────────────────────────────

class _GeneticsBlock extends StatelessWidget {
  final CreatureInstance instance;
  final Genetics? genetics;
  final bool isSelected;
  final int? selectionNumber;

  const _GeneticsBlock({
    required this.instance,
    required this.genetics,
    required this.isSelected,
    required this.selectionNumber,
  });

  String _sizeName() =>
      sizeLabels[genetics?.get('size') ?? 'normal'] ?? 'Standard';
  String _tintName() =>
      tintLabels[genetics?.get('tinting') ?? 'normal'] ?? 'Standard';
  IconData _sizeIcon() =>
      sizeIcons[genetics?.get('size') ?? 'normal'] ?? Icons.circle;
  IconData _tintIcon() =>
      tintIcons[genetics?.get('tinting') ?? 'normal'] ?? Icons.palette_outlined;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
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
        _MiniRow(
          icon: _sizeIcon(),
          color: t.amberBright,
          label: _sizeName().toUpperCase(),
        ),
        const SizedBox(height: 2),
        _MiniRow(
          icon: _tintIcon(),
          color: t.amberBright,
          label: _tintName().toUpperCase(),
        ),
        if (instance.natureId?.isNotEmpty == true) ...[
          const SizedBox(height: 2),
          _MiniRow(
            icon: Icons.psychology_rounded,
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
    final sizeIcon = sizeIcons[sizeKey] ?? Icons.straighten_rounded;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: StaminaBadge(
            instanceId: instance.instanceId,
            showCountdown: true,
          ),
        ),
        const SizedBox(height: 4),
        if (isSelected && selectionNumber != null) ...[
          _ParentChip(selectionNumber: selectionNumber!),
          const SizedBox(height: 3),
        ],
        if (instance.isPrismaticSkin == true) ...[
          const _PrismaticChip(),
          const SizedBox(height: 3),
        ],
        // Level + total in one row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MiniRow(
              icon: Icons.bar_chart_rounded,
              color: t.amberBright,
              label: 'LV ${instance.level}',
            ),
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
            _MiniRow(
              icon: sizeIcon,
              color: t.textSecondary,
              label: sizeName.toUpperCase(),
            ),
            if (instance.natureId?.isNotEmpty == true)
              _MiniRow(
                icon: Icons.psychology_rounded,
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
  final IconData icon;
  final Color color;
  final String label;
  const _MiniRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    return Row(
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 4),
        Expanded(
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
        color: c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: c.withOpacity(0.5)),
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
      color: const Color(0xFFA855F7).withOpacity(0.15),
      borderRadius: BorderRadius.circular(2),
      border: Border.all(color: const Color(0xFFA855F7).withOpacity(0.45)),
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
                border: Border.all(color: t.borderAccent.withOpacity(0.5)),
              ),
              child: Icon(
                hasFilters ? Icons.search_off_rounded : Icons.science_outlined,
                size: 36,
                color: t.amberBright.withOpacity(0.4),
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
                  : 'Acquire specimens through genetic synthesis\nor field research operations',
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
