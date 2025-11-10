import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';

class StorageSection extends StatefulWidget {
  final Color primaryColor;
  final Widget Function(String title, IconData icon, Color color)
  buildSectionHeader;

  const StorageSection({
    super.key,
    required this.primaryColor,
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
          color: isSelected ? color.withOpacity(1) : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? color.withOpacity(0.6)
                : Colors.white.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
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
            color: Colors.black.withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.15)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: Colors.white.withOpacity(.4),
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
          child: StorageEggCard(egg: items[i]),
        ),
      ),
    );
  }
}

class StorageEggCard extends StatelessWidget {
  final Egg egg;

  const StorageEggCard({super.key, required this.egg});

  @override
  Widget build(BuildContext context) {
    final payload = parseEggPayload(egg);
    final elementGroup = getElementalGroupFromPayload(payload);
    final skin = elementGroup.skin;

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
              color: skin.frameEnd.withOpacity(0.25),
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
                        Colors.black.withOpacity(0.08),
                        Colors.black.withOpacity(0.18),
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
                    particleCount: 30,
                    speedMultiplier: 0.5,
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
                  Colors.white.withOpacity(0.12),
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
                    color: Colors.white.withOpacity(0.7),
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
    final skin = elementGroup.skin;
    final rarity = payload['rarity'] as String? ?? 'Common';
    final generation =
        (payload['lineage'] as Map?)?['generationDepth'] as int? ?? 0;
    final isPure = (payload['lineage'] as Map?)?['isPure'] as bool? ?? false;
    final source = payload['source'] as String? ?? 'unknown';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1D23),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Large vial card display
                  Center(
                    child: SizedBox(
                      height: 280,
                      child: _buildLargeVialDisplay(skin),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Title and badges
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              getEggLabel(payload),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${elementGroup.displayName} • Gen $generation',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // if (isPure)
                      //   Container(
                      //     padding: const EdgeInsets.symmetric(
                      //       horizontal: 12,
                      //       vertical: 6,
                      //     ),
                      //     decoration: BoxDecoration(
                      //       color: elementGroup.color.withOpacity(0.2),
                      //       borderRadius: BorderRadius.circular(8),
                      //       border: Border.all(
                      //         color: elementGroup.color.withOpacity(0.4),
                      //       ),
                      //     ),
                      //     child: Row(
                      //       mainAxisSize: MainAxisSize.min,
                      //       children: [
                      //         Icon(
                      //           Icons.verified,
                      //           size: 16,
                      //           color: elementGroup.color,
                      //         ),
                      //         const SizedBox(width: 4),
                      //         Text(
                      //           'PURE',
                      //           style: TextStyle(
                      //             color: elementGroup.color,
                      //             fontSize: 11,
                      //             fontWeight: FontWeight.w900,
                      //             letterSpacing: 0.5,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Info sections
                  _buildInfoSection('Source', _formatSource(source)),
                  const SizedBox(height: 16),

                  if (payload['parentage'] != null)
                    _buildParentageSection(payload['parentage'] as Map),

                  // const SizedBox(height: 16),
                  // _buildStatsSection(payload),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          label: 'ADD TO INCUBATOR',
                          icon: Icons.add_circle_outline,
                          color: elementGroup.color,
                          onTap: () => _addToIncubator(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildDeleteButton(context, elementGroup.color),
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

  Widget _buildLargeVialDisplay(ElementalGroupSkin skin) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.frameStart, skin.frameEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: skin.frameEnd.withOpacity(0.4),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
                      Colors.black.withOpacity(0.08),
                      Colors.black.withOpacity(0.18),
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
            // simple expanded text badge that shows time remaining
            Positioned(
              bottom: 12,
              left: 12,
              child: Text(
                'Time Left: ${_fmtShort(Duration(milliseconds: egg.remainingMs))}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildParentageSection(Map parentage) {
    final parentA = parentage['parentA'] as Map?;
    final parentB = parentage['parentB'] as Map?;

    if (parentA == null || parentB == null) return const SizedBox.shrink();

    final nameA = parentA['name'] as String? ?? 'Unknown';
    final nameB = parentB['name'] as String? ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARENTS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  nameA,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                Icons.close,
                size: 16,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Text(
                  nameB,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsSection(Map<String, dynamic> payload) {
    final stats = payload['stats'] as Map?;
    if (stats == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STATS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatBar('Speed', stats['speed'] as num? ?? 0),
        const SizedBox(height: 6),
        _buildStatBar('Intelligence', stats['intelligence'] as num? ?? 0),
        const SizedBox(height: 6),
        _buildStatBar('Strength', stats['strength'] as num? ?? 0),
        const SizedBox(height: 6),
        _buildStatBar('Beauty', stats['beauty'] as num? ?? 0),
      ],
    );
  }

  Widget _buildStatBar(String label, num value) {
    final percentage = (value / 3.0).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(elementGroup.color),
              minHeight: 8,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context, Color accentColor) {
    return GestureDetector(
      onTap: () => _confirmDelete(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
      ),
    );
  }

  String _formatSource(String source) {
    return switch (source) {
      'breeding' => 'Breeding Laboratory',
      'wild' => 'Wild Capture',
      'vial' => 'Extraction Vial',
      'starter' => 'Starter Selection',
      'wild_breeding' => 'Wild Breeding',
      _ => source.replaceAll('_', ' ').toUpperCase(),
    };
  }

  Future<void> _addToIncubator(BuildContext context) async {
    final db = context.read<AlchemonsDatabase>();

    // Check for free slot
    final freeSlot = await db.incubatorDao.firstFreeSlot();

    if (freeSlot == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 2),
          dismissDirection: DismissDirection.down,
          showCloseIcon: true,
          content: Text('All cultivation slots are full'),
          backgroundColor: Colors.red,
        ),
      );
      //close sheet
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
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
        content: Text('Added to Incubator Slot ${freeSlot.id + 1}'),
        backgroundColor: elementGroup.color,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D23),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Specimen?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This action cannot be undone. The specimen will be permanently removed from storage.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'DELETE',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteEgg(context);
    }
  }

  Future<void> _deleteEgg(BuildContext context) async {
    final db = context.read<AlchemonsDatabase>();
    await db.incubatorDao.removeFromInventory(egg.eggId);

    if (!context.mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        dismissDirection: DismissDirection.down,
        showCloseIcon: true,
        content: Text('Specimen deleted'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
