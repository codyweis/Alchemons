import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class StorageSection extends StatefulWidget {
  final Color primaryColor;
  final CinematicQuality quality;
  final Widget Function(String title, IconData icon, Color color)
  buildSectionHeader;

  const StorageSection({
    super.key,
    required this.primaryColor,
    required this.quality,
    required this.buildSectionHeader,
  });

  @override
  State<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends State<StorageSection> {
  ElementalGroup? _selectedFaction;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Egg>>(
      stream: context.read<AlchemonsDatabase>().incubatorDao.watchInventory(),
      builder: (context, snap) {
        final allItems = snap.data ?? const [];

        // Filter by selected faction
        final filteredItems = _selectedFaction == null
            ? allItems
            : allItems.where((egg) {
                final payload = parseEggPayload(egg);
                final group = getElementalGroupFromPayload(payload);
                return group == _selectedFaction;
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            widget.buildSectionHeader(
              'STORAGE',
              Icons.inventory_2_rounded,
              widget.primaryColor,
            ),
            const SizedBox(height: 12),

            // Faction filter chips
            if (allItems.isNotEmpty) ...[
              _buildFactionFilter(),
              const SizedBox(height: 12),
            ],

            // Empty state or grid
            if (filteredItems.isEmpty)
              _buildEmptyState()
            else
              _buildStorageGrid(filteredItems),
          ],
        );
      },
    );
  }

  Widget _buildFactionFilter() {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFactionChip(null, 'ALL'),
          const SizedBox(width: 8),
          ...ElementalGroup.values.map(
            (group) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFactionChip(group, group.displayName.toUpperCase()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionChip(ElementalGroup? group, String label) {
    final isSelected = _selectedFaction == group;
    final color = group?.color ?? Colors.black;

    return GestureDetector(
      onTap: () => setState(() => _selectedFaction = group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 1)
              : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .15)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Colors.white.withValues(alpha: .4),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _selectedFaction == null
                      ? 'No specimens in storage'
                      : 'No ${_selectedFaction!.displayName} specimens',
                  style: TextStyle(
                    color: const Color(0xFFB6C0CC),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageGrid(List<Egg> items) {
    // Tunables
    const rows = 2; // fixed number of rows
    const spacing = 8.0; // matches your grid spacing
    const rowHeight = 120.0; // visual height of each tile row (~card height)

    // Total height = 3 rows + the 2 gaps between them
    final gridHeight = rows * rowHeight + (rows - 1) * spacing;

    return SizedBox(
      height: gridHeight,
      child: GridView.builder(
        scrollDirection: Axis.horizontal, // ← horizontal scroll
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: rows, // ← 3 rows
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: 0.85, // keep your card proportions
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => SizedBox(
          height: rowHeight,
          child: StorageEggCard(egg: items[i], quality: widget.quality),
        ),
      ),
    );
  }
}

class StorageEggCard extends StatelessWidget {
  final Egg egg;
  final CinematicQuality quality;

  const StorageEggCard({super.key, required this.egg, required this.quality});

  @override
  Widget build(BuildContext context) {
    final payload = parseEggPayload(egg);
    final elementGroup = getElementalGroupFromPayload(payload);
    final skin = elementGroup.skin;
    final media = MediaQuery.of(context);
    final deferEffects = Scrollable.recommendDeferredLoadingForContext(context);

    final shortestSide = media.size.shortestSide;
    int particleCount;
    if (shortestSide < 380) {
      particleCount = 6;
    } else if (shortestSide < 430) {
      particleCount = 10;
    } else {
      particleCount = 14;
    }

    if (deferEffects) {
      particleCount = 4;
    }

    final qualityMultiplier = switch (quality) {
      CinematicQuality.high => 2.4,
      CinematicQuality.balanced => 1.0,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 40);

    final showParticles =
        TickerMode.of(context) && !media.disableAnimations && particleCount > 0;

    return GestureDetector(
      onTap: () => _showEggDetails(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [skin.frameStart, skin.frameEnd],
          ),
          boxShadow: [
            BoxShadow(
              color: skin.frameEnd.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            children: [
              // Background gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.0,
                      colors: [
                        skin.fill,
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.18),
                      ],
                      stops: const [0.2, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // Particle system
              if (showParticles)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AlchemyBrewingParticleSystem(
                      parentATypeId: elementGroup.particleTypes.$1,
                      parentBTypeId: elementGroup.particleTypes.$2,
                      particleCount: particleCount,
                      speedMultiplier: 0.45,
                      fusion: false,
                      useSimpleFusion: true,
                    ),
                  ),
                ),
              // Progress ring with % left (replaces egg icon)
              Positioned.fill(
                child: Center(
                  child: _ProgressBadge(
                    remainingMs: egg.remainingMs,
                    payload: payload,
                    accent: elementGroup.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NEW (Correct)
  void _showEggDetails(BuildContext context) {
    final payload = parseEggPayload(egg);
    final elementGroup = getElementalGroupFromPayload(payload);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EggDetailsModal(
        egg: egg,
        payload: payload,
        elementGroup: elementGroup,
      ),
    );
  }
}

String _fmtShort(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m';
  return '${s}s';
}

class _ProgressBadge extends StatelessWidget {
  final int remainingMs;
  final Map<String, dynamic> payload;
  final Color accent;

  const _ProgressBadge({
    required this.remainingMs,
    required this.payload,
    required this.accent,
  });

  int? _tryGetTotalMs(Map<String, dynamic> p) {
    // Try a few common keys the game might use
    final candidates = [
      p['totalMs'],
      p['durationMs'],
      p['hatchDurationMs'],
      (p['incubation'] is Map ? (p['incubation'] as Map)['durationMs'] : null),
    ];
    for (final c in candidates) {
      if (c is num && c > 0) return c.toInt();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = _tryGetTotalMs(payload);
    final rem = Duration(milliseconds: remainingMs);

    final double? percentLeft = (totalMs != null && totalMs > 0)
        ? (remainingMs / totalMs).clamp(0.0, 1.0)
        : null;

    // Visual sizes
    const double size = 56;
    const double stroke = 6;

    return Semantics(
      label: 'Time remaining',
      value: totalMs != null
          ? '${(percentLeft! * 100).round()} percent left'
          : _fmtShort(rem),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ring
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: 1,
                strokeWidth: stroke,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white.withValues(alpha: 0.12),
                ),
                backgroundColor: Colors.transparent,
              ),
            ),

            // Foreground progress (percent left if we can compute it)
            if (percentLeft != null)
              TweenAnimationBuilder<double>(
                tween: Tween(begin: percentLeft, end: percentLeft),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, value, _) => SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: stroke,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              ),

            // Center label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  percentLeft != null
                      ? '${(percentLeft * 100).round()}%'
                      : _fmtShort(rem),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                Text(
                  percentLeft != null ? 'left' : 'remaining',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
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

class EggDetailsModal extends StatelessWidget {
  final Egg egg;
  final Map<String, dynamic> payload;
  final ElementalGroup elementGroup;

  const EggDetailsModal({
    super.key,
    required this.egg,
    required this.payload,
    required this.elementGroup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final skin = elementGroup.skin;
    final source = payload['source'] as String? ?? 'unknown';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: t.bg1,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        border: Border(top: BorderSide(color: t.borderAccent, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: t.bg0,
              border: Border(
                bottom: BorderSide(color: t.borderAccent, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  color: t.amber,
                  margin: const EdgeInsets.only(right: 10),
                ),
                Expanded(
                  child: Text(
                    'SPECIMEN DETAILS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: t.borderDim, width: 1),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: t.textSecondary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large vial card display
                  Center(
                    child: SizedBox(
                      height: 240,
                      child: _buildLargeVialDisplay(skin, t),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Name
                  Center(
                    child: Text(
                      getEggLabel(payload).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      elementGroup.displayName,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info sections
                  _buildInfoSection('Source', _formatSource(source), t),

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      // DELETE
                      GestureDetector(
                        onTap: () => _confirmDelete(context, t),
                        child: Container(
                          height: 44,
                          width: 52,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: t.danger.withValues(alpha: 0.5),
                              width: 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: t.danger,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // ADD TO CHAMBER
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _addToIncubator(context, t),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: t.amberDim.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                              border: Border.all(color: t.amber, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: t.amber.withValues(alpha: 0.15),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.bubble_chart_rounded,
                                  color: t.amberBright,
                                  size: 15,
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  'ADD TO CHAMBER',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: t.amberBright,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeVialDisplay(ElementalGroupSkin skin, ForgeTokens t) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.frameStart, skin.frameEnd],
        ),
        border: Border.all(color: t.borderAccent, width: 1),
        boxShadow: [
          BoxShadow(
            color: skin.frameEnd.withValues(alpha: 0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [
                      skin.fill,
                      Colors.black.withValues(alpha: 0.08),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                    stops: const [0.2, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Particle system
            Positioned.fill(
              child: IgnorePointer(
                child: AlchemyBrewingParticleSystem(
                  parentATypeId: elementGroup.particleTypes.$1,
                  parentBTypeId: elementGroup.particleTypes.$2,
                  particleCount: 80,
                  speedMultiplier: 0.8,
                  fusion: false,
                  useSimpleFusion: true,
                ),
              ),
            ),
            // Time remaining badge
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: Text(
                  _fmtShort(Duration(milliseconds: egg.remainingMs)),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value, ForgeTokens t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatSource(String source) {
    return switch (source) {
      'wild_capture' => 'Wild Capture',
      'wild' => 'Wild Capture',
      'wild_fusion' => 'Wild Fusion',
      'wild_breeding' => 'Wild Fusion',
      'standard_fusion' => 'Standard Fusion',
      'breeding' => 'Standard Fusion',
      'rift_portal' => 'Rift Portal',
      'planet_summon' => 'Planet Summon',
      'boss_summon' => 'Boss Summon',
      'vial' => 'Extraction Vial',
      'starter' => 'Starter Selection',
      _ => source.replaceAll('_', ' ').toUpperCase(),
    };
  }

  Future<void> _addToIncubator(BuildContext context, ForgeTokens t) async {
    final db = context.read<AlchemonsDatabase>();

    // Check for free slot
    final freeSlot = await db.incubatorDao.firstFreeSlot();

    if (freeSlot == null) {
      if (!context.mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: t.bg1,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Icon(Icons.lock_rounded, color: t.danger, size: 13),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ALL CHAMBER SLOTS FULL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.bg0,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: t.danger,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        ),
      );
      Navigator.pop(context);
      return;
    }

    // Calculate hatch time from remaining duration
    final hatchAt = DateTime.now().toUtc().add(
      Duration(milliseconds: egg.remainingMs),
    );

    // Place in incubator slot
    await db.incubatorDao.placeEgg(
      slotId: freeSlot.id,
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      bonusVariantId: egg.bonusVariantId,
      rarity: egg.rarity,
      hatchAtUtc: hatchAt,
      payloadJson: egg.payloadJson,
    );

    // Remove from storage
    await db.incubatorDao.removeFromInventory(egg.eggId);

    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.bg1,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.bubble_chart_rounded,
                color: t.amberBright,
                size: 13,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'ADDED TO CHAMBER ${freeSlot.id + 1}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.bg0,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: t.amber,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ForgeTokens t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: t.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: t.borderAccent, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: t.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.danger.withValues(alpha: 0.4)),
                ),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: t.danger,
                  size: 24,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'DELETE SPECIMEN?',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This is permanent and cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textSecondary,
                  fontSize: 10,
                  letterSpacing: 0.3,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.bg2,
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: t.borderDim),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'CANCEL',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.danger.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: t.danger.withValues(alpha: 0.6),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'DELETE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: t.danger,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteEgg(context, t);
    }
  }

  Future<void> _deleteEgg(BuildContext context, ForgeTokens t) async {
    final db = context.read<AlchemonsDatabase>();
    await db.incubatorDao.removeFromInventory(egg.eggId);

    if (!context.mounted) return;
    HapticFeedback.mediumImpact();
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: t.bg1,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 13,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'SPECIMEN DELETED',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: t.danger,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
      ),
    );
  }
}
