import 'dart:async';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/cold_storage_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/nursery/cultivation_dialog_actions.dart';
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
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);

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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.bg2,
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: t.borderDim, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStorageMetaRow(
                    t: t,
                    storedCount: filteredItems.length,
                    hasFilter: _selectedFaction != null,
                  ),
                  if (allItems.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildFactionFilter(theme: theme, t: t),
                  ],
                  const SizedBox(height: 12),
                  if (filteredItems.isEmpty)
                    _buildEmptyState(t)
                  else
                    _buildStorageGrid(filteredItems),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStorageMetaRow({
    required ForgeTokens t,
    required int storedCount,
    required bool hasFilter,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: t.amberDim.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: t.borderAccent, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.ac_unit_rounded, color: t.amberBright, size: 10),
            const SizedBox(width: 5),
            Text(
              '$storedCount STORED',
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.amberBright,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactionFilter({
    required FactionTheme theme,
    required ForgeTokens t,
  }) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFactionChip(null, 'ALL', theme: theme, t: t),
          const SizedBox(width: 8),
          ...ElementalGroup.values.map(
            (group) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFactionChip(
                group,
                group.displayName.toUpperCase(),
                theme: theme,
                t: t,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactionChip(
    ElementalGroup? group,
    String label, {
    required FactionTheme theme,
    required ForgeTokens t,
  }) {
    final isSelected = _selectedFaction == group;
    final rim = t.readableAccent(group?.color ?? t.amberBright);
    final background = isSelected
        ? rim.withValues(alpha: theme.isDark ? 0.18 : 0.10)
        : t.bg3;
    final border = isSelected
        ? rim.withValues(alpha: theme.isDark ? 0.70 : 0.45)
        : t.borderDim;
    final textColor = isSelected ? rim : t.textSecondary;
    final swatchColor = isSelected ? rim : rim.withValues(alpha: 0.72);

    return GestureDetector(
      onTap: () => setState(() => _selectedFaction = group),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: swatchColor,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: textColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ForgeTokens t) {
    final message = _selectedFaction == null
        ? 'No specimens in cold storage'
        : 'No ${_selectedFaction!.displayName} specimens in cold storage';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.bg3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: t.bg0,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent, width: 1),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: t.amberBright.withValues(alpha: 0.85),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Stored specimens keep cultivating at reduced speed until you move them back into an active chamber.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      CinematicQuality.balanced => 0.5,
      CinematicQuality.performance => 0.0,
    };
    particleCount = (particleCount * qualityMultiplier).round().clamp(0, 8);

    final showParticles =
        TickerMode.valuesOf(context).enabled &&
        !media.disableAnimations &&
        particleCount > 0;
    final particleSpeed = isReady ? 0.8 + (_pulseController.value * 1.3) : 0.4;
    final accent = isReady ? const Color(0xFFFFD700) : elementGroup.color;
    final borderColor = isReady
        ? accent.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.10);

    final payloadMap = parseEggPayload(egg);
    final rarityHatch =
        BreedConstants.rarityHatchTimes[egg.rarity.toLowerCase()];
    final factor = ColdStorageService.slowdownFactorFromPayload(payloadMap);
    final fallbackTotalMs = rarityHatch == null
        ? null
        : rarityHatch.inMilliseconds * factor;
    final totalMs =
        ColdStorageService.totalDisplayDurationMs(egg) ?? fallbackTotalMs;
    final remainingMs = displayRemaining.inMilliseconds;
    final percentDone = (totalMs != null && totalMs > 0)
        ? (1 - (remainingMs / totalMs)).clamp(0.0, 1.0)
        : null;

    return GestureDetector(
      onTap: () => _showEggDetails(context),
      child: ListenableBuilder(
        listenable: _pulseController,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [skin.frameStart, skin.frameEnd],
              ),
              border: Border.all(
                color: borderColor,
                width: isReady ? 1.2 : 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
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
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.22),
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
                  // Lab corner brackets
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _VialBracketsPainter(
                          color: accent.withValues(
                            alpha: isReady
                                ? 0.55 + (_pulseController.value * 0.35)
                                : 0.32,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Time / READY label
                  Positioned(
                    top: 5,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        isReady ? 'READY' : _fmtShort(displayRemaining),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: isReady ? accent : Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  // Bottom fill bar — cultivation completion
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      height: 5,
                      color: Colors.black.withValues(alpha: 0.55),
                      child: percentDone == null
                          ? null
                          : FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: isReady ? 1.0 : percentDone,
                              child: Container(color: accent),
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

class _VialBracketsPainter extends CustomPainter {
  _VialBracketsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    const double m = 3;
    const double l = 6;

    // Top-left
    canvas.drawLine(Offset(m, m), Offset(m + l, m), paint);
    canvas.drawLine(Offset(m, m), Offset(m, m + l), paint);
    // Top-right
    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m - l, m),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - m, m),
      Offset(size.width - m, m + l),
      paint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(m, size.height - m),
      Offset(m + l, size.height - m),
      paint,
    );
    canvas.drawLine(
      Offset(m, size.height - m),
      Offset(m, size.height - m - l),
      paint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(size.width - m, size.height - m),
      Offset(size.width - m - l, size.height - m),
      paint,
    );
    canvas.drawLine(
      Offset(size.width - m, size.height - m),
      Offset(size.width - m, size.height - m - l),
      paint,
    );
  }

  @override
  bool shouldRepaint(_VialBracketsPainter old) => old.color != color;
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
                ],
              ),
            ),
          ),
          CultivationDialogActionArea(
            tokens: t,
            children: [
              if (isReady) ...[
                CultivationDialogButton(
                  tokens: t,
                  label: 'EXTRACT SPECIMEN',
                  icon: Icons.biotech_rounded,
                  accentColor: t.amberBright,
                  emphasis: CultivationDialogButtonEmphasis.primary,
                  onTap: () => _extractFromStorage(context, t),
                ),
                const SizedBox(height: 8),
                CultivationDialogButton(
                  tokens: t,
                  label: 'DELETE',
                  icon: Icons.delete_outline_rounded,
                  accentColor: t.danger,
                  emphasis: CultivationDialogButtonEmphasis.danger,
                  onTap: () => _confirmDelete(context, t),
                ),
              ] else ...[
                CultivationDialogButton(
                  tokens: t,
                  label: 'ADD TO CHAMBER',
                  icon: Icons.inventory_2_rounded,
                  accentColor: t.amberBright,
                  emphasis: CultivationDialogButtonEmphasis.primary,
                  onTap: () => _addToIncubator(context, t),
                ),
                const SizedBox(height: 8),
                CultivationDialogButton(
                  tokens: t,
                  label: 'DELETE',
                  icon: Icons.delete_outline_rounded,
                  accentColor: t.danger,
                  emphasis: CultivationDialogButtonEmphasis.danger,
                  onTap: () => _confirmDelete(context, t),
                ),
              ],
            ],
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
    final payload = parseEggPayload(egg);
    final isBloodborn = isBloodbornPayload(payload);
    final displaySkin = isBloodborn
        ? const ElementalGroupSkin(
            frameStart: kBloodbornPrimary,
            frameEnd: kBloodbornSecondary,
            fill: kBloodbornFill,
            badge: kBloodbornSecondary,
          )
        : skin;
    final borderColor = isReady
        ? (isBloodborn ? kBloodbornReadyBorder : const Color(0xFFFFD700))
        : (isBloodborn ? kBloodbornSecondary : t.borderAccent);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [displaySkin.frameStart, displaySkin.frameEnd],
        ),
        border: Border.all(color: borderColor, width: isReady ? 1.4 : 1),
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
                      displaySkin.fill,
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
                  parentATypeId: isBloodborn
                      ? 'blood'
                      : elementGroup.particleTypes.$1,
                  parentBTypeId: isBloodborn
                      ? 'dark'
                      : elementGroup.particleTypes.$2,
                  particleCount: isReady ? 22 : 18,
                  speedMultiplier: isReady ? 1.0 : 0.45,
                  fusion: isReady,
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
      'bloodborn' => 'Bloodborn Rite',
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

class _ParentDetail {
  final String name;
  final String? subtitle;

  const _ParentDetail({required this.name, required this.subtitle});
}
