import 'dart:async';
import 'dart:ui';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
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
  Timer? _clock;
  DateTime _nowUtc = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _nowUtc = DateTime.now().toUtc();
      });
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

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
              'COLD STORAGE',
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
                      ? 'No specimens in cold storage'
                      : 'No ${_selectedFaction!.displayName} specimens in cold storage',
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
    const rowHeight = 60.0; // roughly half-size storage vial tiles

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
          child: StorageEggCard(
            egg: items[i],
            quality: widget.quality,
            nowUtc: _nowUtc,
          ),
        ),
      ),
    );
  }
}

class StorageEggCard extends StatefulWidget {
  final Egg egg;
  final CinematicQuality quality;
  final DateTime nowUtc;

  const StorageEggCard({
    super.key,
    required this.egg,
    required this.quality,
    required this.nowUtc,
  });

  @override
  State<StorageEggCard> createState() => _StorageEggCardState();
}

class _StorageEggCardState extends State<StorageEggCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncReadyAnimation();
  }

  @override
  void didUpdateWidget(covariant StorageEggCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.egg != widget.egg || oldWidget.nowUtc != widget.nowUtc) {
      _syncReadyAnimation();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _syncReadyAnimation() {
    final isReady = ColdStorageService.isReady(
      widget.egg,
      nowUtc: widget.nowUtc,
    );
    if (isReady) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final egg = widget.egg;
    final payload = parseEggPayload(egg);
    final elementGroup = getElementalGroupFromPayload(payload);
    final skin = elementGroup.skin;
    final media = MediaQuery.of(context);
    final deferEffects = Scrollable.recommendDeferredLoadingForContext(context);
    final displayRemaining = ColdStorageService.coldStorageRemainingFromEgg(
      egg,
      nowUtc: widget.nowUtc,
    );
    final isReady = ColdStorageService.isReady(egg, nowUtc: widget.nowUtc);

    final shortestSide = media.size.shortestSide;
    int particleCount;
    if (shortestSide < 380) {
      particleCount = 1;
    } else if (shortestSide < 430) {
      particleCount = 2;
    } else {
      particleCount = 3;
    }

    if (deferEffects) {
      particleCount = 0;
    }

    final qualityMultiplier = switch (widget.quality) {
      CinematicQuality.high => 1.0,
      CinematicQuality.balanced => 0.5,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 8);

    final showParticles =
        TickerMode.of(context) && !media.disableAnimations && particleCount > 0;
    final particleSpeed = isReady ? 0.8 + (_pulseController.value * 1.3) : 0.45;
    final borderColor = isReady
        ? const Color(0xFFFFD700)
        : Colors.white.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: () => _showEggDetails(context),
      child: ListenableBuilder(
        listenable: _pulseController,
        builder: (context, child) {
          final pulse = _pulseController.value;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [skin.frameStart, skin.frameEnd],
              ),
              border: Border.all(
                color: borderColor,
                width: isReady ? 1.4 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isReady ? borderColor : skin.frameEnd).withValues(
                    alpha: isReady ? 0.3 + (pulse * 0.25) : 0.25,
                  ),
                  blurRadius: isReady ? 18 + (pulse * 10) : 16,
                  spreadRadius: isReady ? 1 + (pulse * 1.2) : 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
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
                  if (showParticles)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AlchemyBrewingParticleSystem(
                          parentATypeId: elementGroup.particleTypes.$1,
                          parentBTypeId: elementGroup.particleTypes.$2,
                          particleCount: isReady
                              ? particleCount + 1
                              : particleCount,
                          speedMultiplier: particleSpeed,
                          fusion: isReady,
                          useSimpleFusion: true,
                        ),
                      ),
                    ),
                  if (isReady)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _ReadyPulse(pulse: pulse),
                    ),
                  Positioned.fill(
                    child: Center(
                      child: _ProgressBadge(
                        egg: egg,
                        remaining: displayRemaining,
                        accent: isReady
                            ? const Color(0xFFFFD700)
                            : elementGroup.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEggDetails(BuildContext context) {
    final payload = parseEggPayload(widget.egg);
    final elementGroup = getElementalGroupFromPayload(payload);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => EggDetailsModal(
        hostContext: this.context,
        egg: widget.egg,
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
  final Egg egg;
  final Duration remaining;
  final Color accent;

  const _ProgressBadge({
    required this.egg,
    required this.remaining,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final totalMs = ColdStorageService.totalDisplayDurationMs(egg);
    final rem = remaining;
    final remainingMs = rem.inMilliseconds;
    final isReady = rem <= Duration.zero;

    final double? percentLeft = (totalMs != null && totalMs > 0)
        ? (remainingMs / totalMs).clamp(0.0, 1.0)
        : null;

    // Visual sizes
    const double size = 56;
    const double stroke = 6;

    return Semantics(
      label: 'Time remaining',
      value: totalMs != null
          ? isReady
                ? 'Ready'
                : '${(percentLeft! * 100).round()} percent left'
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
                  isReady
                      ? 'READY'
                      : percentLeft != null
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
                  isReady
                      ? 'extract'
                      : percentLeft != null
                      ? 'left'
                      : 'remaining',
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
  final BuildContext hostContext;
  final Egg egg;
  final Map<String, dynamic> payload;
  final ElementalGroup elementGroup;

  const EggDetailsModal({
    super.key,
    required this.hostContext,
    required this.egg,
    required this.payload,
    required this.elementGroup,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final dialogSurface = theme.isDark ? t.bg1 : Colors.white;
    final skin = elementGroup.skin;
    final source = payload['source'] as String? ?? 'unknown';
    final parents = _extractParents();
    final displayRemaining = ColdStorageService.coldStorageRemainingFromEgg(
      egg,
    );
    final isReady = ColdStorageService.isReady(egg);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: dialogSurface,
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
                      child: _buildLargeVialDisplay(
                        skin,
                        t,
                        displayRemaining,
                        isReady,
                      ),
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

                  if (parents.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildParentsSection(parents, t),
                  ],

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
                      if (isReady) ...[
                        Flexible(
                          flex: 3,
                          child: GestureDetector(
                            onTap: () => _extractFromStorage(context, t),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(2),
                                border: Border.all(
                                  color: const Color(0xFFFFD700),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFFD700,
                                    ).withValues(alpha: 0.18),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'EXTRACT',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: Color(0xFFFFD700),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        flex: isReady ? 2 : 3,
                        child: GestureDetector(
                          onTap: () => _addToIncubator(context, t),
                          child: Container(
                            height: isReady ? 38 : 44,
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
                            child: Text(
                              'ADD TO CHAMBER',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.amberBright,
                                fontSize: isReady ? 10 : 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: isReady ? 1.1 : 1.4,
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
        ],
      ),
    );
  }

  Future<void> _extractFromStorage(BuildContext context, ForgeTokens t) async {
    Navigator.pop(context);

    final result = await EggHatching.performStorageHatching(
      context: hostContext,
      egg: egg,
    );

    if (!hostContext.mounted || result.success || result.message == null) {
      return;
    }

    ScaffoldMessenger.of(hostContext).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: [
            Icon(result.icon ?? Icons.error_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(result.message!)),
          ],
        ),
        backgroundColor: result.color ?? t.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildLargeVialDisplay(
    ElementalGroupSkin skin,
    ForgeTokens t,
    Duration displayRemaining,
    bool isReady,
  ) {
    final borderColor = isReady ? const Color(0xFFFFD700) : t.borderAccent;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skin.frameStart, skin.frameEnd],
        ),
        border: Border.all(color: borderColor, width: isReady ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: (isReady ? borderColor : skin.frameEnd).withValues(
              alpha: isReady ? 0.45 : 0.25,
            ),
            blurRadius: isReady ? 24 : 16,
            spreadRadius: isReady ? 2 : 1,
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
                  particleCount: isReady ? 22 : 18,
                  speedMultiplier: isReady ? 1.0 : 0.45,
                  fusion: isReady,
                  useSimpleFusion: true,
                ),
              ),
            ),
            if (isReady)
              const Positioned(
                top: 10,
                right: 10,
                child: _ReadyPulse(pulse: 1),
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
                  isReady ? 'READY' : _fmtShort(displayRemaining),
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

  Widget _buildParentsSection(List<_ParentDetail> parents, ForgeTokens t) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: t.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARENTS',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < parents.length; i++) ...[
            _buildParentRow(parents[i], t),
            if (i < parents.length - 1) ...[
              const SizedBox(height: 8),
              Divider(color: t.borderDim, height: 1),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildParentRow(_ParentDetail parent, ForgeTokens t) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parent.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (parent.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  parent.subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  List<_ParentDetail> _extractParents() {
    final parentage = payload['parentage'];
    if (parentage is! Map) return const [];

    final parents = <_ParentDetail>[];
    final parentA = _parseParent(parentage['parentA'], 'A');
    final parentB = _parseParent(parentage['parentB'], 'B');

    if (parentA != null) parents.add(parentA);
    if (parentB != null) parents.add(parentB);

    return parents;
  }

  _ParentDetail? _parseParent(dynamic raw, String fallbackLabel) {
    if (raw is! Map) return null;

    try {
      final snap = ParentSnapshot.fromJson(Map<String, dynamic>.from(raw));
      final cleanName = snap.name.trim();
      if (cleanName.isEmpty) return null;

      final parts = <String>[];
      final types = snap.types
          .where((type) => type.trim().isNotEmpty)
          .join(' • ');
      if (types.isNotEmpty) parts.add(types);

      return _ParentDetail(
        name: cleanName,
        subtitle: parts.isEmpty ? null : parts.join('  |  '),
      );
    } catch (_) {
      final rawName = (raw['name'] as String?)?.trim() ?? '';
      if (rawName.isEmpty) return null;

      final rawTypes = (raw['types'] is List)
          ? (raw['types'] as List)
                .map((type) => type.toString().trim())
                .where((type) => type.isNotEmpty)
                .join(' • ')
          : '';
      final parts = <String>[if (rawTypes.isNotEmpty) rawTypes];

      return _ParentDetail(
        name: rawName,
        subtitle: parts.isEmpty ? null : parts.join('  |  '),
      );
    }
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
    final activeRemaining = ColdStorageService.activeRemainingFromEgg(egg);
    final hatchAt = DateTime.now().toUtc().add(activeRemaining);

    // Place in incubator slot
    await db.incubatorDao.placeEgg(
      slotId: freeSlot.id,
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      bonusVariantId: egg.bonusVariantId,
      rarity: egg.rarity,
      hatchAtUtc: hatchAt,
      payloadJson: ColdStorageService.clearColdStoragePayload(egg.payloadJson),
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
    final theme = context.read<FactionTheme>();
    final dialogSurface = theme.isDark ? t.bg1 : Colors.white;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: dialogSurface,
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

class _ReadyPulse extends StatelessWidget {
  final double pulse;

  const _ReadyPulse({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final size = 9 + (pulse * 8);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFFFFF7C2), Color(0xFFFFD700), Color(0x00FFD700)],
          stops: [0.0, 0.42, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.55),
            blurRadius: 12 + (pulse * 6),
            spreadRadius: 1 + pulse,
          ),
        ],
      ),
    );
  }
}

class _ParentDetail {
  final String name;
  final String? subtitle;

  const _ParentDetail({required this.name, required this.subtitle});
}
