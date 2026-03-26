import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/utils/creature_instance_uti.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/bottom_sheet_shell.dart';
import 'package:alchemons/widgets/creature_instances_sheet.dart';
import 'package:alchemons/widgets/creature_selection_sheet.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/floating_close_button_widget.dart';
import 'package:alchemons/widgets/fx/alchemy_tap_fx.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// ---------------------------------------------------------------------------
// ExtractionHubScreen
// All 5 animated extraction chambers on one scrollable screen.
// Replaces both BiomeHarvestScreen and BiomeDetailScreen.
// ---------------------------------------------------------------------------

class ExtractionHubScreen extends StatefulWidget {
  const ExtractionHubScreen({super.key, this.service});

  final HarvestService? service;

  @override
  State<ExtractionHubScreen> createState() => _ExtractionHubScreenState();
}

class _ExtractionHubScreenState extends State<ExtractionHubScreen>
    with TickerProviderStateMixin {
  late HarvestService _svc;
  bool _tutorialChecked = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? context.read<HarvestService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked || !mounted) return;
    _tutorialChecked = true;
    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBiomeHarvestTutorial();
    if (hasSeen || !mounted) return;
    final theme = FactionTheme.scorchForge();
    final t = ForgeTokens(theme);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: t.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: t.borderAccent, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.42),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 26,
                    decoration: BoxDecoration(
                      color: t.amber,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.science_rounded, color: t.amberBright, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'BIOME EXTRACTORS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: t.borderMid),
              const SizedBox(height: 12),
              Text(
                'Use biome extractors to slowly generate elemental resources over time.',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: Icons.terrain_rounded,
                title: 'Step 1 – Pick a biome',
                body:
                    'Each biome specialises in certain elements. Some start '
                    'locked and require resources to unlock.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.science_outlined,
                title: 'Step 2 – Insert an Alchemon',
                body:
                    'Tap a chamber and insert an Alchemon to start '
                    'extraction. Tap the orb to speed it up.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.inventory_2_rounded,
                title: 'Step 3 – Collect your rewards',
                body:
                    'When complete, collect from each chamber individually '
                    'or tap Collect All at the top.',
              ),
              const SizedBox(height: 10),
              Text(
                'Higher-level Alchemons generate more resources.',
                style: TextStyle(
                  color: t.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          t.amberDim.withValues(alpha: 0.45),
                          t.amber.withValues(alpha: 0.28),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: t.amber.withValues(alpha: 0.7)),
                    ),
                    child: Text(
                      'GOT IT',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.amberBright,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) await db.settingsDao.setBiomeHarvestTutorialSeen();
  }

  Future<void> _promptUnlock(BiomeFarmState farm) async {
    final costDb = UnlockCosts.biome(farm.biome);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UnlockDialog(biome: farm.biome, costDb: costDb),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _svc.unlock(farm.biome, cost: costDb);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Unlocked ${farm.biome.label}!' : 'Not enough resources',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
      ),
    );
  }

  Future<void> _collectAll(List<BiomeFarmState> farms) async {
    HapticFeedback.mediumImpact();
    final completed = farms.where((f) => f.completed).toList();
    int total = 0;
    for (final farm in completed) {
      total += await _svc.collect(farm.biome);
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Collected $total resources from ${completed.length} chamber${completed.length == 1 ? '' : 's'}',
        ),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final forgeTheme = FactionTheme.scorchForge();
    final t = ForgeTokens(forgeTheme);
    return Scaffold(
      extendBody: true,
      backgroundColor: t.bg0,
      body: withGameData(
        context,
        loadingBuilder: buildLoadingScreen,
        builder:
            (
              context, {
              required theme,
              required catalog,
              required entries,
              required discovered,
            }) {
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [t.bg0, t.bg1, t.bg0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(0, -0.7),
                            radius: 1.15,
                            colors: [
                              t.amber.withValues(alpha: 0.12),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Positioned.fill(child: AlchemicalParticleBackground()),
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: t.bg1.withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: t.borderDim),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 18,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 3,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: t.amber,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'EXTRACTION HUB',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: t.textPrimary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Harvest elemental resources from active chambers',
                                        style: TextStyle(
                                          color: t.textSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListenableBuilder(
                            listenable: _svc,
                            builder: (_, __) {
                              final farms = _svc.biomes;
                              final completedCount = farms
                                  .where((f) => f.completed)
                                  .length;
                              return Column(
                                children: [
                                  if (completedCount > 0)
                                    _CollectAllBanner(
                                      count: completedCount,
                                      theme: forgeTheme,
                                      onCollectAll: () => _collectAll(farms),
                                    ),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final width = constraints.maxWidth;
                                        final crossAxisCount = width >= 980
                                            ? 4
                                            : width >= 740
                                            ? 3
                                            : 2;
                                        final spacing = width >= 740
                                            ? 16.0
                                            : 12.0;
                                        final totalSpacing =
                                            spacing * (crossAxisCount - 1);
                                        final cardWidth =
                                            (width - 24 - totalSpacing) /
                                            crossAxisCount;
                                        final childAspectRatio =
                                            cardWidth >= 240
                                            ? 0.54
                                            : cardWidth >= 190
                                            ? 0.48
                                            : 0.43;

                                        return GridView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            8,
                                            12,
                                            120,
                                          ),
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: crossAxisCount,
                                                crossAxisSpacing: spacing,
                                                mainAxisSpacing: spacing,
                                                childAspectRatio:
                                                    childAspectRatio,
                                              ),
                                          itemCount: farms.length,
                                          itemBuilder: (_, i) =>
                                              _EmbeddedChamber(
                                                key: ValueKey(
                                                  farms[i].biome.id,
                                                ),
                                                farm: farms[i],
                                                theme: forgeTheme,
                                                service: _svc,
                                                discoveredCreatures: discovered,
                                                defaultDuration: const Duration(
                                                  hours: 4,
                                                ),
                                                onUnlock: () =>
                                                    _promptUnlock(farms[i]),
                                              ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingCloseButton(
                        theme: forgeTheme,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).maybePop();
                        },
                        accentColor: t.textPrimary,
                        iconColor: t.textPrimary,
                      ),
                    ),
                  ),
                ],
              );
            },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CollectAllBanner
// ---------------------------------------------------------------------------

class _CollectAllBanner extends StatelessWidget {
  const _CollectAllBanner({
    required this.count,
    required this.theme,
    required this.onCollectAll,
  });
  final int count;
  final FactionTheme theme;
  final VoidCallback onCollectAll;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    const lime = Color(0xFFB3FF66);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.bg2.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: lime.withValues(alpha: 0.35), width: 1.1),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: lime,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count chamber${count == 1 ? '' : 's'} ready to collect',
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            GestureDetector(
              onTap: onCollectAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      lime.withValues(alpha: 0.16),
                      lime.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: lime.withValues(alpha: 0.70),
                    width: 1.1,
                  ),
                ),
                child: const Text(
                  'COLLECT ALL',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: lime,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmbeddedChamber — full animated orb + all logic, no separate screen needed
// ---------------------------------------------------------------------------

class _EmbeddedChamber extends StatefulWidget {
  const _EmbeddedChamber({
    super.key,
    required this.farm,
    required this.theme,
    required this.service,
    required this.discoveredCreatures,
    required this.defaultDuration,
    required this.onUnlock,
  });

  final BiomeFarmState farm;
  final FactionTheme theme;
  final HarvestService service;
  final List<CreatureEntry> discoveredCreatures;
  final Duration defaultDuration;
  final VoidCallback onUnlock;

  @override
  State<_EmbeddedChamber> createState() => _EmbeddedChamberState();
}

class _EmbeddedChamberState extends State<_EmbeddedChamber>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  double _tSeconds = 0.0;

  late final AnimationController _tapFxCtrl;
  Offset? _tapLocal;
  late final AnimationController _collectCtrl;
  late final AnimationController _jobCtrl;
  late final AnimationController _glowController;
  late final AnimationController _statusCtrl;

  Widget? _creatureWidget;
  String? _cachedInstanceId;

  @override
  void initState() {
    super.initState();
    _collectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _statusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _tapFxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _jobCtrl = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _ticker = createTicker((elapsed) {
      if (mounted) setState(() => _tSeconds = elapsed.inMicroseconds / 1e6);
    })..start();
    PushNotificationService().cancelHarvestSummaryNotification();
    _refreshCreatureCache();
  }

  @override
  void didUpdateWidget(covariant _EmbeddedChamber old) {
    super.didUpdateWidget(old);
    if (widget.farm.activeJob?.creatureInstanceId != _cachedInstanceId) {
      _refreshCreatureCache();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _jobCtrl.dispose();
    _glowController.dispose();
    _collectCtrl.dispose();
    _tapFxCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  // ── Creature cache ────────────────────────────────────────────────────────

  Future<void> _refreshCreatureCache() async {
    final job = widget.farm.activeJob;
    if (job == null) {
      _cachedInstanceId = null;
      if (mounted) {
        setState(
          () => _creatureWidget = Icon(
            widget.farm.biome.icon,
            size: 28,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        );
      }
      return;
    }
    if (_cachedInstanceId == job.creatureInstanceId &&
        _creatureWidget != null) {
      return;
    }
    _cachedInstanceId = job.creatureInstanceId;
    final db = context.read<AlchemonsDatabase>();
    final inst = await db.creatureDao.getInstance(job.creatureInstanceId);
    if (!mounted) return;
    if (inst == null) {
      setState(
        () => _creatureWidget = Icon(
          widget.farm.biome.icon,
          size: 40,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      );
      return;
    }
    final repo = context.read<CreatureCatalog>();
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.spriteData == null) {
      setState(
        () => _creatureWidget = Icon(
          widget.farm.biome.icon,
          size: 40,
          color: Colors.white.withValues(alpha: 0.75),
        ),
      );
      return;
    }
    setState(
      () => _creatureWidget = InstanceSprite(
        creature: base,
        instance: inst,
        size: 72,
      ),
    );
  }

  // ── Progress sync ─────────────────────────────────────────────────────────

  _ProgressViewModel _syncAndComputeProgress(BiomeFarmState farm) {
    final job = farm.activeJob;
    if (job == null) {
      if (_jobCtrl.value != 0) _jobCtrl.value = 0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
      return const _ProgressViewModel(
        progress: 0,
        effectiveFill: 0,
        remaining: null,
      );
    }
    final totalMs = job.durationMs;
    final rem = farm.remaining;
    final rawProgress = (rem == null || totalMs == 0)
        ? 0.0
        : (1.0 - rem.inMilliseconds / totalMs).clamp(0.0, 1.0);
    final totalDur = Duration(milliseconds: totalMs);
    if (_jobCtrl.duration != totalDur) _jobCtrl.duration = totalDur;
    if (farm.completed) {
      if (_jobCtrl.value != 1.0) _jobCtrl.value = 1.0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
    } else {
      const eps = 0.002;
      if ((_jobCtrl.value - rawProgress).abs() > eps || !_jobCtrl.isAnimating) {
        _jobCtrl.forward(from: rawProgress);
      }
    }
    final progress = _jobCtrl.value;
    final targetFill = farm.hasActive
        ? (0.0 + 0.85 * progress).clamp(0.0, 0.85)
        : 0.0;
    final curvedFill = Curves.easeOutCubic.transform(targetFill);
    final drainP = Curves.easeInOutCubic.transform(_collectCtrl.value);
    final effectiveFill = curvedFill * (1.0 - drainP);
    final Duration? remainingTime = farm.hasActive && _jobCtrl.duration != null
        ? _jobCtrl.duration! * (1 - _jobCtrl.value)
        : farm.remaining;
    return _ProgressViewModel(
      progress: progress,
      effectiveFill: effectiveFill,
      remaining: remainingTime,
    );
  }

  // ── Tap boost ─────────────────────────────────────────────────────────────

  void _handleTapBoost(BiomeFarmState farm) {
    if (!farm.hasActive || farm.completed) return;
    final totalMs = farm.activeJob!.durationMs;
    final currentMs = (1.0 - _jobCtrl.value) * totalMs;
    final newMs = (currentMs - 1000).clamp(0, totalMs).toDouble();
    _jobCtrl.value = 1.0 - (newMs / totalMs);
    widget.service.nudge(widget.farm.biome);
  }

  // ── Start job ─────────────────────────────────────────────────────────────

  Future<void> _handlePickAndStart() async {
    final theme = widget.theme;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final busyIds = widget.farm.activeJob != null
        ? [widget.farm.activeJob!.creatureInstanceId]
        : <String>[];

    final allInstances = await db.creatureDao.getAllInstances();
    final eligibleSpeciesIds = <String>{};
    for (final inst in allInstances) {
      if (busyIds.contains(inst.instanceId)) continue;
      final base = repo.getCreatureById(inst.baseId);
      if (base != null &&
          base.types.isNotEmpty &&
          widget.farm.biome.elementTypes.contains(base.types.first)) {
        eligibleSpeciesIds.add(inst.baseId);
      }
    }
    if (eligibleSpeciesIds.isEmpty) {
      _showToast(
        'No eligible creatures for this biome.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }

    final available = await db.creatureDao.getSpeciesWithInstances();
    final filteredDiscovered = filterByAvailableInstances(
      widget.discoveredCreatures,
      available,
    );
    if (!mounted) return;

    final selectedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final eligible = filteredDiscovered
              .where((e) => eligibleSpeciesIds.contains(e.creature.id))
              .toList();
          return CreatureSelectionSheet(
            scrollController: scrollController,
            discoveredCreatures: eligible,
            onSelectCreature: (id) => Navigator.pop(context, id),
            showOnlyAvailableTypes: true,
          );
        },
      ),
    );
    if (selectedSpeciesId == null || !mounted) return;

    final species = repo.getCreatureById(selectedSpeciesId);
    if (species == null) return;

    final instanceId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetShell(
        title: 'Choose ${species.name}',
        theme: theme,
        child: InstancesSheet(
          species: species,
          theme: theme,
          harvestDuration: widget.defaultDuration,
          busyInstanceIds: busyIds,
          onTap: (inst) => Navigator.pop(context, inst.instanceId),
        ),
      ),
    );
    if (instanceId == null || !mounted) return;

    final stamina = context.read<StaminaService>();
    final inst = await stamina.refreshAndGet(instanceId);
    if (inst == null) return;
    if (inst.staminaBars == 0) {
      _showToast(
        'This creature is too exhausted.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;
    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.farm.biome, creatureTypeId);
    final ok = await widget.service.startJob(
      biome: widget.farm.biome,
      creatureInstanceId: instanceId,
      duration: widget.defaultDuration,
      ratePerMinute: computeHarvestRatePerMinute(
        inst,
        hasMatchingElement: widget.farm.biome.elementTypes.contains(
          creatureTypeId,
        ),
      ),
    );
    if (!mounted) return;
    if (ok) {
      await _collectCtrl.forward(from: 0);
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not start extraction.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Collect ───────────────────────────────────────────────────────────────

  Future<void> _handleCollect(BiomeFarmState farm) async {
    final previousJob = farm.activeJob;
    HapticFeedback.mediumImpact();
    await _collectCtrl.forward(from: 0);
    final got = await widget.service.collect(widget.farm.biome);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Collected $got ${widget.farm.biome.resourceLabel}'),
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        duration: const Duration(seconds: 2),
      ),
    );
    await _refreshCreatureCache();
    if (previousJob == null || !mounted) return;
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.hasInstantReload()) return;
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 30,
                      decoration: BoxDecoration(
                        color: t.amber,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.refresh_rounded, color: t.amberBright, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'EXTRACTION COMPLETE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 14),
                Text(
                  'Reload the same specimen with the same settings?',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Text(
                            'NOT NOW',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
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
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                t.amberDim.withValues(alpha: 0.45),
                                t.amber.withValues(alpha: 0.35),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.amber.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Text(
                            'RELOAD',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.amberBright,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
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
      ),
    );
    if (shouldReload != true || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(
      previousJob.creatureInstanceId,
    );
    if (inst == null) {
      _showToast(
        'That creature is no longer available.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;
    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.farm.biome, creatureTypeId);
    final ok = await widget.service.startJob(
      biome: widget.farm.biome,
      creatureInstanceId: inst.instanceId,
      duration: Duration(milliseconds: previousJob.durationMs),
      ratePerMinute: previousJob.ratePerMinute,
    );
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      _showToast(
        'Chamber reloaded!',
        icon: Icons.refresh_rounded,
        color: theme.primary,
      );
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not reload.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _handleCancel(FactionTheme theme) async {
    if (_collectCtrl.isAnimating) return;
    final t = ForgeTokens(theme);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderAccent, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 26, color: t.danger),
                    const SizedBox(width: 10),
                    Text(
                      'CANCEL EXTRACTION',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 14),
                Text(
                  'Your specimen will be returned, but current progress will be lost.',
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          child: Text(
                            'KEEP RUNNING',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
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
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: t.danger.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: t.danger.withValues(alpha: 0.55),
                            ),
                          ),
                          child: Text(
                            'TERMINATE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.danger,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
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
      ),
    );
    if (confirmed != true || !mounted) return;
    HapticFeedback.heavyImpact();
    await _collectCtrl.forward(from: 0);
    await widget.service.cancel(widget.farm.biome);
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extraction cancelled'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
        showCloseIcon: true,
      ),
    );
    await _refreshCreatureCache();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(Duration? d) {
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _showToast(
    String msg, {
    IconData icon = Icons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade400,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        showCloseIcon: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final t = ForgeTokens(theme);
    return ListenableBuilder(
      listenable: widget.service,
      builder: (_, __) {
        final farm = widget.service.biome(widget.farm.biome);
        final accent = farm.currentColor;
        final vm = _syncAndComputeProgress(farm);
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 210;

            final statusText = !farm.unlocked
                ? 'This biome is locked.'
                : (!farm.hasActive
                      ? 'No active extraction. Insert a creature to begin.'
                      : (farm.completed
                            ? 'Extraction complete. Ready to collect.'
                            : 'Extracting ${widget.farm.biome.resourceLabel} • ${_fmt(vm.remaining)} left'));

            Widget? badge;
            if (farm.completed) {
              badge = _AlchemyStatusBadge(
                controller: _statusCtrl,
                label: 'COMPLETE',
                color: const Color(0xFFB3FF66),
              );
            } else if (farm.unlocked && !farm.hasActive) {
              badge = _AlchemyStatusBadge(
                controller: _statusCtrl,
                label: 'READY',
                color: accent,
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: t.bg2.withValues(alpha: 0.97),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: farm.completed
                      ? const Color(0xFFB3FF66).withValues(alpha: 0.42)
                      : farm.hasActive
                      ? accent.withValues(alpha: 0.28)
                      : t.borderDim,
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 10 : 12,
                      compact ? 9 : 10,
                      compact ? 10 : 12,
                      compact ? 8 : 9,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg3.withValues(alpha: 0.95),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                      border: Border(bottom: BorderSide(color: t.borderDim)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: compact ? 24 : 28,
                          height: compact ? 24 : 28,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            farm.biome.icon,
                            color: accent,
                            size: compact ? 13 : 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                farm.biome.label.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 10.5 : 11.5,
                                  letterSpacing: compact ? 0.7 : 1.0,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                farm.biome.elementTypes
                                    .join(', ')
                                    .toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: t.textSecondary,
                                  fontSize: compact ? 8.5 : 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GlowingIcon(
                          icon: Icons.info_outline_rounded,
                          color: accent,
                          controller: _glowController,
                          dialogTitle: '${farm.biome.label} Extraction',
                          dialogMessage:
                              'Extract resources from creatures aligned with this biome. Output depends on creature element.',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 10 : 12,
                        compact ? 8 : 10,
                        compact ? 10 : 12,
                        compact ? 10 : 12,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: compact ? 0.94 : 0.82,
                                    child: _ChamberView(
                                      tSeconds: _tSeconds,
                                      progress: vm.progress,
                                      collectCtrl: _collectCtrl,
                                      tapFxCtrl: _tapFxCtrl,
                                      onTapBoost: () => _handleTapBoost(farm),
                                      farm: farm,
                                      accent: accent,
                                      statusOverlay: badge,
                                      effectiveFill: vm.effectiveFill,
                                      creatureWidget: _creatureWidget,
                                      onTapDown: (details, inner) {
                                        _handleTapBoost(farm);
                                        final lp = details.localPosition;
                                        final clamped = Offset(
                                          lp.dx.clamp(
                                            inner.left + 6,
                                            inner.right - 6,
                                          ),
                                          lp.dy.clamp(
                                            inner.top + 6,
                                            inner.bottom - 6,
                                          ),
                                        );
                                        setState(() => _tapLocal = clamped);
                                        _tapFxCtrl.forward(from: 0);
                                      },
                                      tapLocal: _tapLocal,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  statusText,
                                  textAlign: TextAlign.center,
                                  maxLines: compact ? 3 : 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: t.textSecondary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: compact ? 9.5 : 10.5,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.fromLTRB(
                              compact ? 8 : 10,
                              compact ? 8 : 10,
                              compact ? 8 : 10,
                              compact ? 8 : 10,
                            ),
                            decoration: BoxDecoration(
                              color: t.bg1.withValues(alpha: 0.84),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: t.borderDim),
                            ),
                            child: !farm.unlocked
                                ? _LockedPanel(
                                    color: accent,
                                    theme: theme,
                                    compact: compact,
                                    onBack: widget.onUnlock,
                                  )
                                : !farm.hasActive
                                ? _StartPanel(
                                    color: accent,
                                    theme: theme,
                                    biome: farm.biome,
                                    defaultDuration: widget.defaultDuration,
                                    compact: compact,
                                    onPickAndStart: _handlePickAndStart,
                                  )
                                : _ActivePanel(
                                    color: accent,
                                    theme: theme,
                                    farm: farm,
                                    biome: farm.biome,
                                    compact: compact,
                                    onCollect: farm.completed
                                        ? () => _handleCollect(farm)
                                        : null,
                                    onCancel: () => _handleCancel(theme),
                                  ),
                          ),
                        ],
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
}

// ---------------------------------------------------------------------------
// Progress view model
// ---------------------------------------------------------------------------

class _ProgressViewModel {
  const _ProgressViewModel({
    required this.progress,
    required this.effectiveFill,
    required this.remaining,
  });
  final double progress;
  final double effectiveFill;
  final Duration? remaining;
}

// ---------------------------------------------------------------------------
// Panels — identical to BiomeDetailScreen
// ---------------------------------------------------------------------------

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.color,
    required this.theme,
    required this.biome,
    required this.defaultDuration,
    required this.compact,
    required this.onPickAndStart,
  });
  final Color color;
  final FactionTheme theme;
  final Biome biome;
  final Duration defaultDuration;
  final bool compact;
  final VoidCallback onPickAndStart;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Column(
      children: [
        Text(
          'Insert a creature to extract resources from this biome.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: t.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 9.5 : 10.5,
            height: 1.3,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        _PrimaryBtn(
          label: 'Insert Alchemon',
          accent: color,
          theme: theme,
          compact: compact,
          onTap: onPickAndStart,
        ),
        SizedBox(height: compact ? 6 : 8),
        Text(
          'Duration: ${defaultDuration.inMinutes}m',
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textMuted,
            fontSize: compact ? 8.5 : 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({
    required this.color,
    required this.theme,
    required this.farm,
    required this.biome,
    required this.compact,
    required this.onCollect,
    required this.onCancel,
  });
  final Color color;
  final FactionTheme theme;
  final BiomeFarmState farm;
  final Biome biome;
  final bool compact;
  final VoidCallback? onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final j = farm.activeJob!;
    final duration = Duration(milliseconds: j.durationMs);
    final rate = j.ratePerMinute;
    final total = rate * duration.inMinutes;
    return Column(
      children: [
        Text(
          'Rate: $rate / min',
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textPrimary,
            fontSize: compact ? 9 : 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        Text(
          'Total: $total ${biome.resourceLabel}',
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textSecondary,
            fontSize: compact ? 8.5 : 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        if (compact) ...[
          _PrimaryBtn(
            label: 'Collect',
            accent: color,
            theme: theme,
            compact: compact,
            onTap: (farm.completed && onCollect != null) ? onCollect! : null,
            disabled: !farm.completed,
          ),
          const SizedBox(height: 8),
          _OutlineBtn(
            label: 'Terminate',
            accent: color,
            theme: theme,
            compact: compact,
            onTap: onCancel,
          ),
        ] else
          Row(
            children: [
              Expanded(
                child: _PrimaryBtn(
                  label: 'Collect',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  onTap: (farm.completed && onCollect != null)
                      ? onCollect!
                      : null,
                  disabled: !farm.completed,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OutlineBtn(
                  label: 'Terminate',
                  accent: color,
                  theme: theme,
                  compact: compact,
                  onTap: onCancel,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _LockedPanel extends StatelessWidget {
  const _LockedPanel({
    required this.color,
    required this.theme,
    required this.compact,
    required this.onBack,
  });
  final Color color;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Column(
      children: [
        Text(
          'Unlock this extractor to begin extraction.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: t.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: compact ? 9.5 : 10.5,
            height: 1.3,
          ),
        ),
        SizedBox(height: compact ? 8 : 10),
        _OutlineBtn(
          label: 'Unlock Biome',
          accent: color,
          theme: theme,
          compact: compact,
          onTap: onBack,
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.accent,
    required this.theme,
    required this.compact,
    required this.onTap,
    this.disabled = false,
  });
  final String label;
  final Color accent;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final bg = disabled ? t.bg3 : accent.withValues(alpha: 0.16);
    final border = disabled ? t.borderDim : accent.withValues(alpha: 0.48);
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: compact ? 11 : 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                bg,
                accent.withValues(alpha: disabled ? 0.04 : 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: border, width: 1.1),
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: disabled ? t.textMuted : t.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 9 : 10,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  const _OutlineBtn({
    required this.label,
    required this.accent,
    required this.theme,
    required this.compact,
    required this.onTap,
  });
  final String label;
  final Color accent;
  final FactionTheme theme;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: compact ? 11 : 13),
        decoration: BoxDecoration(
          color: t.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.1),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            color: t.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: compact ? 9 : 10,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ChamberView — verbatim from BiomeDetailScreen
// ---------------------------------------------------------------------------

class _ChamberView extends StatelessWidget {
  const _ChamberView({
    required this.tSeconds,
    required this.progress,
    required this.collectCtrl,
    required this.tapFxCtrl,
    required this.onTapBoost,
    required this.farm,
    required this.accent,
    required this.effectiveFill,
    required this.creatureWidget,
    required this.onTapDown,
    required this.tapLocal,
    this.statusOverlay,
  });
  final Widget? statusOverlay;
  final double tSeconds;
  final double progress;
  final AnimationController collectCtrl;
  final AnimationController tapFxCtrl;
  final VoidCallback onTapBoost;
  final BiomeFarmState farm;
  final Color accent;
  final double effectiveFill;
  final Widget? creatureWidget;
  final void Function(TapDownDetails details, RRect inner) onTapDown;
  final Offset? tapLocal;

  double _tempo() {
    final ramp = Curves.easeInQuart.transform(progress).clamp(0.0, 1.0);
    final nearDone = (progress > .85) ? (progress - .85) / .15 : 0.0;
    final endBoost = Curves.easeOutExpo.transform(nearDone.clamp(0, 1));
    final v = tapFxCtrl.value;
    final tapBell = (v == 0) ? 0 : (1 - (2 * (v - .5)).abs());
    final tapBoost = tapBell * 1.6;
    return 1.0 + 3.0 * ramp + 1.5 * endBoost + tapBoost;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final geo = _ChamberGeometry.fromSize(size);
        final inner = geo.inner;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            HapticFeedback.lightImpact();
            onTapBoost();
            onTapDown(d, inner);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([collectCtrl, tapFxCtrl]),
            child: Stack(
              children: [
                Positioned.fromRect(
                  rect: inner.outerRect,
                  child: ClipRRect(
                    borderRadius: inner._toBorderRadius(),
                    child: Center(
                      child: _CreatureIdle(
                        tapFxCtrl: tapFxCtrl,
                        child:
                            creatureWidget ??
                            Icon(
                              farm.biome.icon,
                              size: 28,
                              color: Colors.white.withValues(alpha: .55),
                            ),
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _ChamberBackgroundPainter(
                    tSeconds: tSeconds,
                    tempo: _tempo(),
                    fill: effectiveFill,
                    color: accent,
                    active: farm.hasActive,
                  ),
                  size: size,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: tapFxCtrl,
                      builder: (_, __) => AlchemyTapFX(
                        center: tapLocal,
                        progress: tapFxCtrl.value,
                        color: accent,
                      ),
                    ),
                  ),
                ),
                CustomPaint(
                  painter: _ChamberForegroundPainter(
                    tSeconds: tSeconds,
                    tempo: _tempo(),
                    color: accent,
                  ),
                  size: size,
                ),
                if (statusOverlay != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.translate(
                          offset: Offset(0, size.height * -0.08),
                          child: statusOverlay!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            builder: (_, child) {
              final v = collectCtrl.value;
              final decay = 1.0 - v;
              final dx = math.sin(v * math.pi * 10) * 5.0 * decay;
              final dy = math.cos(v * math.pi * 8) * 4.0 * decay;
              final rot = math.sin(v * math.pi * 6) * 0.012 * decay;
              return Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(angle: rot, child: child),
              );
            },
          ),
        );
      },
    );
  }
}

class _CreatureIdle extends StatelessWidget {
  const _CreatureIdle({required this.tapFxCtrl, required this.child});
  final AnimationController tapFxCtrl;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tapFxCtrl,
      builder: (context, _) {
        final v = tapFxCtrl.value;
        final osc = math.sin(v * math.pi * 10);
        final decay = 1.0 - v;
        final amp = 6.0 * decay;
        final dx = osc * amp * .55;
        final dy = -osc * amp * .35;
        final rot = osc * 0.02;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(angle: rot, child: child),
        );
      },
    );
  }
}

extension _RRectBorderRadius on RRect {
  BorderRadius _toBorderRadius() => BorderRadius.only(
    topLeft: Radius.circular(tlRadiusX),
    topRight: Radius.circular(trRadiusX),
    bottomLeft: Radius.circular(blRadiusX),
    bottomRight: Radius.circular(brRadiusX),
  );
}

class _ChamberGeometry {
  _ChamberGeometry(this.outer, this.inner, this.center, this.radius);
  final RRect outer;
  final RRect inner;
  final Offset center;
  final double radius;

  static _ChamberGeometry fromSize(Size size) {
    final w = size.width;
    final h = size.height;
    final d = math.min(w, h * 0.78);
    final cx = w / 2;
    final cy = h * 0.42;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: d, height: d);
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(d / 2));
    final inner = outer.deflate(d * 0.06);
    return _ChamberGeometry(outer, inner, Offset(cx, cy), d / 2);
  }
}

class _ChamberBackgroundPainter extends CustomPainter {
  _ChamberBackgroundPainter({
    required this.tSeconds,
    required this.tempo,
    required this.fill,
    required this.color,
    required this.active,
  });
  final double tSeconds;
  final double tempo;
  final double fill;
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChamberGeometry.fromSize(size);
    final inner = geo.inner;
    final c = geo.center;
    final r = geo.radius * 0.92;
    canvas.save();
    canvas.clipRRect(inner);
    final back = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: .45),
          Colors.black.withValues(alpha: .70),
        ],
      ).createShader(inner.outerRect);
    canvas.drawRect(inner.outerRect, back);
    final beamAlpha = (0.20 + 0.65 * Curves.easeOutCubic.transform(fill)).clamp(
      0.0,
      0.85,
    );
    final beam = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.55,
        colors: [
          color.withValues(alpha: beamAlpha * .9),
          color.withValues(alpha: beamAlpha * .35),
          Colors.transparent,
        ],
        stops: const [.0, .35, 1.0],
      ).createShader(inner.outerRect);
    canvas.drawCircle(c, r * 0.78, beam);
    final baseAngle = tSeconds * tempo;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: .40);
    final glyph = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: .85);

    void drawRing(double radius, double speed, int glyphs, double dash) {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(baseAngle * speed);
      final dashCount = (math.pi * 2 * radius / dash).floor();
      final segment = (2 * math.pi) / dashCount;
      for (int i = 0; i < dashCount; i += 2) {
        final from = i * segment;
        final to = (i + 1) * segment;
        final p = Path()
          ..addArc(
            Rect.fromCircle(center: Offset.zero, radius: radius),
            from,
            to - from,
          );
        canvas.drawPath(p, ring);
      }
      for (int i = 0; i < glyphs; i++) {
        final ang = (i / glyphs) * (math.pi * 2);
        final x = math.cos(ang) * radius;
        final y = math.sin(ang) * radius;
        final sz = 2.6 + 1.2 * math.sin(baseAngle * (speed + .3) + i);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-ang + baseAngle * (speed * .6));
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: sz,
          height: sz * 1.2,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.2)),
          glyph,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    final intensity = (0.3 + 0.7 * fill).clamp(0.0, 1.0);
    drawRing(r * .68, 0.6 + intensity, 12, 10);
    drawRing(r * .51, 1.0 + intensity, 10, 9);
    drawRing(r * .36, 1.6 + intensity, 8, 8);

    final mote = Paint()..color = Colors.white.withValues(alpha: .70);
    final count = active ? 42 : 18;
    final suctionBase = 0.20 + 0.55 * Curves.easeOutCubic.transform(fill);
    final swirlBase = 0.60 + 0.80 * Curves.easeIn.transform(fill);
    for (int i = 0; i < count; i++) {
      final seed = i * 1337.0;
      final rand = (seed % 1000) / 1000.0;
      final r0 = r * (0.20 + 0.75 * rand);
      final a0 = (seed % (2 * math.pi));
      final speed = (0.35 + (seed % 17) / 40.0) * (0.8 + 0.6 * tempo);
      final t = (tSeconds * speed + (seed % 23) * .013) % 1.0;
      final suction = suctionBase * (0.65 + 0.35 * math.sin(seed));
      final rad = r0 * (1.0 - math.pow(t, 1.35) * suction).clamp(0.0, 1.0);
      final swirl = swirlBase * (1.0 + 0.7 * (1.0 - rad / r0));
      final ang = a0 + t * 2.0 * math.pi * swirl;
      final px = c.dx + math.cos(ang) * rad;
      final py = c.dy + math.sin(ang) * rad;
      if (inner.outerRect.contains(Offset(px, py))) {
        final sz = 1.1 + ((i % 5 == 0) ? 0.9 : 0.0);
        canvas.drawCircle(Offset(px, py), sz, mote);
        final trailT = (t - 0.06).clamp(0.0, 1.0);
        if (trailT > 0) {
          final rad2 = r0 * (1.0 - math.pow(trailT, 1.35) * suction);
          final ang2 = a0 + trailT * 2.0 * math.pi * swirl;
          final p2 = Offset(
            c.dx + math.cos(ang2) * rad2,
            c.dy + math.sin(ang2) * rad2,
          );
          canvas.drawCircle(
            p2,
            sz * 0.85,
            Paint()..color = Colors.white.withValues(alpha: .10),
          );
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ChamberBackgroundPainter old) =>
      old.tSeconds != tSeconds ||
      old.tempo != tempo ||
      old.fill != fill ||
      old.color != color ||
      old.active != active;
}

class _ChamberForegroundPainter extends CustomPainter {
  _ChamberForegroundPainter({
    required this.tSeconds,
    required this.tempo,
    required this.color,
  });
  final double tSeconds;
  final double tempo;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChamberGeometry.fromSize(size);
    final outer = geo.outer;
    final inner = geo.inner;
    final c = geo.center;
    final r = geo.radius;
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (outer.width * 0.06).clamp(6, 18)
      ..shader = SweepGradient(
        colors: [
          Colors.white.withValues(alpha: .85),
          Colors.white.withValues(alpha: .45),
          Colors.white.withValues(alpha: .85),
        ],
      ).createShader(outer.outerRect);
    canvas.drawRRect(outer, rim);
    canvas.save();
    canvas.translate(.6, .6);
    canvas.drawRRect(
      outer.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFF6B6B).withValues(alpha: .33),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-.6, -.6);
    canvas.drawRRect(
      outer.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF5EC8FF).withValues(alpha: .33),
    );
    canvas.restore();
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomLeft,
              colors: [Colors.white.withValues(alpha: .50), Colors.transparent],
            ).createShader(
              Rect.fromLTWH(outer.left - 6, outer.top, 10, outer.height),
            ),
    );
    final crown = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .65);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(tSeconds * tempo * 1.2);
    final cr = r * 0.88;
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      canvas.drawLine(
        Offset(math.cos(a) * cr, math.sin(a) * cr),
        Offset(math.cos(a) * (cr - 10), math.sin(a) * (cr - 10)),
        crown,
      );
    }
    canvas.restore();
    canvas.drawRRect(
      inner,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Colors.white.withValues(alpha: .45),
    );
  }

  @override
  bool shouldRepaint(covariant _ChamberForegroundPainter old) =>
      old.tSeconds != tSeconds || old.tempo != tempo || old.color != color;
}

class _AlchemyStatusBadge extends StatelessWidget {
  const _AlchemyStatusBadge({
    required this.controller,
    required this.label,
    required this.color,
  });
  final AnimationController controller;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final pulse = 0.65 + 0.35 * math.sin(t * math.pi * 2);
        final glow = 0.25 + 0.55 * (0.5 - (t - 0.5).abs()) * 2;
        return Opacity(
          opacity: 0.85,
          child: CustomPaint(
            painter: _AlchemyStatusPainter(
              t: t,
              pulse: pulse,
              glow: glow,
              color: color,
              label: label,
            ),
            size: const Size(160, 160),
          ),
        );
      },
    );
  }
}

class _AlchemyStatusPainter extends CustomPainter {
  _AlchemyStatusPainter({
    required this.t,
    required this.pulse,
    required this.glow,
    required this.color,
    required this.label,
  });
  final double t, pulse, glow;
  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.48;
    canvas.drawCircle(
      c,
      r * (1.05 + 0.02 * glow),
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.08 * (0.7 + 0.3 * glow)),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r * 1.2)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 + 1.8 * pulse
        ..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.save();
    canvas.translate(.8, .8);
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFFFF6B6B).withValues(alpha: .38),
    );
    canvas.restore();
    canvas.save();
    canvas.translate(-.8, -.8);
    canvas.drawCircle(
      c,
      r * 0.985,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF5EC8FF).withValues(alpha: .38),
    );
    canvas.restore();
    final ticks = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .75);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    final tr = r * 0.88;
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      canvas.drawLine(
        Offset(math.cos(a) * tr, math.sin(a) * tr),
        Offset(math.cos(a) * (tr - 10), math.sin(a) * (tr - 10)),
        ticks,
      );
    }
    canvas.restore();
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white.withValues(alpha: .95),
          shadows: [
            Shadow(
              blurRadius: 6 + 10 * glow,
              color: color.withValues(alpha: .8),
            ),
          ],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset(c.dx - textPainter.width / 2, c.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _AlchemyStatusPainter old) =>
      old.t != t ||
      old.pulse != pulse ||
      old.glow != glow ||
      old.color != color ||
      old.label != label;
}

// ---------------------------------------------------------------------------
// Unlock dialog
// ---------------------------------------------------------------------------

class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.biome, required this.costDb});
  final Biome biome;
  final Map<String, int> costDb;

  @override
  Widget build(BuildContext context) {
    final color = biome.primaryColor;
    final theme = FactionTheme.scorchForge();
    final t = ForgeTokens(theme);
    final db = context.read<AlchemonsDatabase>();
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: t.bg1.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: t.borderAccent, width: 1.1),
        ),
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<Map<String, int>>(
          stream: db.currencyDao.watchResourceBalances(),
          builder: (context, snap) {
            final bal = snap.data ?? {};
            bool hasShortage = false;
            for (final e in costDb.entries) {
              if ((bal[e.key] ?? 0) < e.value) {
                hasShortage = true;
                break;
              }
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(width: 3, height: 34, color: t.amber),
                    const SizedBox(width: 12),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.45),
                          width: 1.1,
                        ),
                      ),
                      child: Icon(biome.icon, color: color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'UNLOCK ${biome.label.toUpperCase()}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(height: 1, color: t.borderMid),
                const SizedBox(height: 12),
                Text(
                  biome.description,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'REQUIRED RESOURCES',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.amberBright,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...costDb.entries.map((e) {
                  final have = bal[e.key] ?? 0;
                  final ok = have >= e.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: t.bg2,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: ok
                            ? color.withValues(alpha: 0.4)
                            : t.danger.withValues(alpha: 0.55),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            e.key.toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                              letterSpacing: 0.8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$have / ${e.value}',
                          style: TextStyle(
                            color: ok ? const Color(0xFFB3FF66) : t.danger,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w800,
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: t.bg2,
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: t.borderDim),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: hasShortage ? 0.5 : 1,
                        child: GestureDetector(
                          onTap: hasShortage
                              ? null
                              : () => Navigator.pop(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  t.amberDim.withValues(alpha: 0.42),
                                  color.withValues(alpha: 0.18),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: hasShortage
                                    ? t.borderDim
                                    : t.amber.withValues(alpha: 0.65),
                                width: 1.1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              hasShortage ? 'NOT ENOUGH' : 'CONFIRM UNLOCK',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: hasShortage
                                    ? t.textMuted
                                    : t.amberBright,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
