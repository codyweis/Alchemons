import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/models/biome_farm_state.dart';
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
import 'package:alchemons/widgets/fx/alchemy_tap_fx.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class BiomeDetailScreen extends StatefulWidget {
  const BiomeDetailScreen({
    super.key,
    required this.biome,
    required this.service,
    this.defaultDuration = const Duration(hours: 4),
    required this.discoveredCreatures,
  });

  final Biome biome;
  final HarvestService service;
  final Duration defaultDuration;
  final List<Map<String, dynamic>> discoveredCreatures;

  @override
  State<BiomeDetailScreen> createState() => _BiomeDetailScreenState();
}

class _BiomeDetailScreenState extends State<BiomeDetailScreen>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  double _tSeconds = 0.0;

  late final AnimationController _tapFxCtrl;
  Offset? _tapLocal;

  late final AnimationController _collectCtrl;
  late final AnimationController _jobCtrl;
  late final AnimationController _glowController;

  /// Cached sprite widget for current active job creature
  Widget? _creatureWidget;
  String? _cachedInstanceIdForCreature; // so we know if job changed
  late final AnimationController _statusCtrl;
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

    // high-frequency ticker JUST updates _tSeconds,
    // and we only pass _tSeconds into the bubbling tube widget.
    _ticker = createTicker((elapsed) {
      _tSeconds = elapsed.inMicroseconds / 1e6;
      // instead of setState on whole screen, notify only the tube
      if (mounted) {
        // we'll trigger a rebuild of the tube sub-tree via setState,
        // but that subtree is cheap and isolated
        setState(() {});
      }
    })..start();

    // Clear harvest notification when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pushNotifications = PushNotificationService();
      pushNotifications.cancelHarvestNotification(biomeId: widget.biome.id);
    });

    _refreshCreatureCache(); // prime cache
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

  // Rebuild the creature widget cache if the active job's creature changed
  Future<void> _refreshCreatureCache() async {
    final farm = widget.service.biome(widget.biome);
    final job = farm.activeJob;

    if (job == null) {
      _cachedInstanceIdForCreature = null;
      _creatureWidget = Icon(
        widget.biome.icon,
        size: 28,
        color: Colors.white.withValues(alpha: .55),
      );
      return;
    }

    if (_cachedInstanceIdForCreature == job.creatureInstanceId &&
        _creatureWidget != null) {
      // no change
      return;
    }

    _cachedInstanceIdForCreature = job.creatureInstanceId;

    final db = context.read<AlchemonsDatabase>();
    final inst = await db.creatureDao.getInstance(job.creatureInstanceId);

    if (!mounted) return;

    if (inst == null) {
      _creatureWidget = Icon(
        widget.biome.icon,
        size: 40,
        color: Colors.white.withValues(alpha: .75),
      );
      setState(() {});
      return;
    }

    final repo = context.read<CreatureCatalog>();
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.spriteData == null) {
      _creatureWidget = Icon(
        widget.biome.icon,
        size: 40,
        color: Colors.white.withValues(alpha: .75),
      );
      setState(() {});
      return;
    }

    _creatureWidget = InstanceSprite(creature: base, instance: inst, size: 72);

    setState(() {});
  }

  // Sync _jobCtrl with game job state and return computed metrics
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
    if (_jobCtrl.duration != totalDur) {
      _jobCtrl.duration = totalDur;
    }

    if (farm.completed) {
      if (_jobCtrl.value != 1.0) _jobCtrl.value = 1.0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
    } else {
      // nudge controller to keep animating toward "now"
      const eps = 0.002;
      if ((_jobCtrl.value - rawProgress).abs() > eps || !_jobCtrl.isAnimating) {
        _jobCtrl.forward(from: rawProgress);
      }
    }

    // visual fill math
    final progress = _jobCtrl.value;
    final targetFill = farm.hasActive
        ? (0.0 + 0.85 * progress).clamp(0.0, 0.85)
        : 0.0;
    final curvedFill = Curves.easeOutCubic.transform(targetFill);
    final drainP = Curves.easeInOutCubic.transform(_collectCtrl.value);
    final effectiveFill = curvedFill * (1.0 - drainP);

    // compute displayed remaining time
    final Duration? remainingTime = farm.hasActive && _jobCtrl.duration != null
        ? _jobCtrl.duration! * (1 - _jobCtrl.value)
        : farm.remaining;

    return _ProgressViewModel(
      progress: progress,
      effectiveFill: effectiveFill,
      remaining: remainingTime,
    );
  }

  void _handleTapBoost(BiomeFarmState farm) {
    if (!farm.hasActive || farm.completed) return;

    final totalMs = farm.activeJob!.durationMs;
    final currentMs = (1.0 - _jobCtrl.value) * totalMs;
    final newMs = (currentMs - 1000).clamp(0, totalMs).toDouble();
    _jobCtrl.value = 1.0 - (newMs / totalMs);

    // no need to await, nudge can be fire-and-forget
    widget.service.nudge(widget.biome);
  }

  Future<void> _handlePickAndStart(
    List<CreatureEntry> discoveredCreatures,
  ) async {
    final theme = context.read<FactionTheme>();
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    // Get busy instance IDs
    final farm = widget.service.biome(widget.biome);
    final busyIds = farm.activeJob != null
        ? [farm.activeJob!.creatureInstanceId]
        : <String>[];

    // Get all instances that match the allowed types
    final allInstances = await db.creatureDao.getAllInstances();
    final eligibleSpeciesIds = <String>{};

    for (final inst in allInstances) {
      if (busyIds.contains(inst.instanceId)) continue;

      final base = repo.getCreatureById(inst.baseId);
      if (base != null &&
          base.types.isNotEmpty &&
          widget.biome.elementTypes.contains(base.types.first)) {
        eligibleSpeciesIds.add(inst.baseId);
      }
    }

    if (eligibleSpeciesIds.isEmpty) {
      _showToast(
        'No eligible creatures found for this biome.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }

    final available = await db.creatureDao
        .getSpeciesWithInstances(); // Set<String> baseIds

    final filteredDiscovered = filterByAvailableInstances(
      discoveredCreatures,
      available,
    );

    // Show species picker
    final selectedSpeciesId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            // Filter to only show eligible species
            final eligibleDiscovered = filteredDiscovered.where((entry) {
              final creature = entry.creature; // Get the Creature object
              final creatureId = creature.id;
              return eligibleSpeciesIds.contains(creatureId);
            }).toList();

            return CreatureSelectionSheet(
              scrollController: scrollController,
              discoveredCreatures: eligibleDiscovered,
              onSelectCreature: (creatureId) {
                Navigator.pop(context, creatureId);
              },
              showOnlyAvailableTypes: true,
            );
          },
        );
      },
    );

    if (selectedSpeciesId == null) return;

    final selectedSpecies = repo.getCreatureById(selectedSpeciesId);
    if (selectedSpecies == null) return;

    // Show instance picker with harvest stats
    final instanceId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BottomSheetShell(
        title: 'Choose ${selectedSpecies.name}',
        theme: theme,
        child: InstancesSheet(
          species: selectedSpecies,
          theme: theme,
          harvestDuration: widget.defaultDuration,
          busyInstanceIds: busyIds,
          onTap: (inst) {
            Navigator.pop(context, inst.instanceId);
          },
        ),
      ),
    );

    if (instanceId == null) return;

    final stamina = context.read<StaminaService>();
    final inst = await stamina.refreshAndGet(instanceId);
    if (inst == null) return;

    if (inst.staminaBars == 0) {
      _showToast(
        'This creature is too exhausted to work right now.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
      return;
    }

    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;

    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.biome, creatureTypeId);

    final ok = await widget.service.startJob(
      biome: widget.biome,
      creatureInstanceId: instanceId,
      duration: widget.defaultDuration,
      ratePerMinute: computeHarvestRatePerMinute(
        inst,
        hasMatchingElement: widget.biome.elementTypes.contains(creatureTypeId),
      ),
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start extraction'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await _collectCtrl.forward(from: 0);
      await _refreshCreatureCache();
    }
  }

  void _handleCollect(BiomeFarmState farm) async {
    // 🔹 Snapshot the job BEFORE collecting (it will be cleared by collect)
    final previousJob = farm.activeJob;

    HapticFeedback.mediumImpact();
    await _collectCtrl.forward(from: 0);

    final got = await widget.service.collect(widget.biome);
    if (!mounted) return;

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        showCloseIcon: true,
        content: Text('Collected $got ${widget.biome.resourceLabel}'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshCreatureCache();

    // 🔹 If no previous job, nothing to reload
    if (previousJob == null) return;

    // 🔹 Check constellation skill
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.hasInstantReload()) return;

    final theme = context.read<FactionTheme>();

    // 🔹 Ask player if they want to reload the same creature
    final shouldReload = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.refresh_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'Reload creature?',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        content: Text(
          'Send this Alchemon straight back into the extractor with the same settings?',
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Not now',
              style: TextStyle(
                color: theme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Reload',
              style: TextStyle(
                color: theme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );

    if (shouldReload != true || !mounted) return;

    // 🔹 Try to restart the same job instantly
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
    await widget.service.setActiveElement(widget.biome, creatureTypeId);

    final ok = await widget.service.startJob(
      biome: widget.biome,
      creatureInstanceId: inst.instanceId,
      duration: Duration(milliseconds: previousJob.durationMs),
      ratePerMinute: previousJob.ratePerMinute,
    );

    if (!mounted) return;

    if (!ok) {
      _showToast(
        'Could not reload extraction.',
        icon: Icons.error_outline,
        color: Colors.red.shade400,
      );
    } else {
      HapticFeedback.mediumImpact();
      _showToast(
        'Chamber reloaded!',
        icon: Icons.refresh_rounded,
        color: theme.primary,
      );
      await _refreshCreatureCache();
    }
  }

  void _handleCancel(theme) async {
    if (_collectCtrl.isAnimating) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel Extraction?', style: TextStyle(color: theme.text)),
        content: Text(
          'Are you sure you want to cancel this extraction? '
          'Your specimens will be returned, but progress will be lost.',
          style: TextStyle(color: theme.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Extracting'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Extraction'),
          ),
        ],
      ),
    );

    // User dismissed dialog or chose "Keep Extracting"
    if (confirmed != true || !mounted) return;

    HapticFeedback.heavyImpact();
    await _collectCtrl.forward(from: 0);

    await widget.service.cancel(widget.biome);

    if (!mounted) return;

    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 2),
        showCloseIcon: true,
        content: Text('Extraction cancelled'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    await _refreshCreatureCache();
  }
  // ---------- UI helpers ----------

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
    String message, {
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade400,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        dismissDirection: DismissDirection.horizontal,
        showCloseIcon: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();

    return Scaffold(
      backgroundColor: theme.surface,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
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
              return ListenableBuilder(
                listenable: widget.service,
                builder: (_, __) {
                  final farm = widget.service.biome(widget.biome);
                  final accent = farm.currentColor;
                  final vm = _syncAndComputeProgress(farm);

                  final statusText = !farm.unlocked
                      ? 'This biome is locked.'
                      : (!farm.hasActive
                            ? 'No active extraction. Insert a creature to begin.'
                            : (farm.completed
                                  ? 'Extraction complete — ready to collect.'
                                  : 'Extracting ${widget.biome.resourceLabel} ... ${_fmt(vm.remaining)} left'));

                  final currentJob = farm.activeJob;
                  if (currentJob?.creatureInstanceId !=
                      _cachedInstanceIdForCreature) {
                    _refreshCreatureCache();
                  }

                  final isReady = farm.unlocked && !farm.hasActive;
                  final isComplete = farm.completed;
                  Widget? badge;
                  if (isComplete) {
                    // loud lime-ish for completion
                    badge = _AlchemyStatusBadge(
                      controller: _statusCtrl,
                      label: 'COMPLETE',
                      color: const Color(0xFFB3FF66),
                    );
                  } else if (isReady) {
                    // subtler biome accent for ready
                    badge = _AlchemyStatusBadge(
                      controller: _statusCtrl,
                      label: 'READY',
                      color: accent,
                    );
                  }

                  return Stack(
                    children: [
                      const Positioned.fill(
                        child: AlchemicalParticleBackground(),
                      ),

                      // Main content
                      Column(
                        children: [
                          _HeaderShell(
                            theme: theme,
                            accentColor: accent,
                            biomeLabel: widget.biome.label,
                            onBack: () => Navigator.of(context).maybePop(),
                            glowController: _glowController,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: Column(
                                children: [
                                  AspectRatio(
                                    aspectRatio: 3 / 4,
                                    child: _ChamberView(
                                      tSeconds: _tSeconds,
                                      progress: vm.progress, // <— new
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
                                  Text(
                                    statusText,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.text,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  if (!farm.unlocked)
                                    _LockedPanel(
                                      color: accent,
                                      theme: theme,
                                      onBack: () => Navigator.pop(context),
                                    )
                                  else if (!farm.hasActive)
                                    _StartPanel(
                                      color: accent,
                                      theme: theme,
                                      biome: widget.biome,
                                      defaultDuration: widget.defaultDuration,
                                      // PASS TYPED discovered entries here
                                      onPickAndStart: () =>
                                          _handlePickAndStart(discovered),
                                    )
                                  else
                                    _ActivePanel(
                                      color: accent,
                                      theme: theme,
                                      farm: farm,
                                      biome: widget.biome,
                                      onCollect: farm.completed
                                          ? () => _handleCollect(farm)
                                          : null,
                                      onCancel: () => _handleCancel(theme),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
      ),
    );
  }
}

// Small immutable model for computed progress values
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

/// Extracted tube widget so only this subtree rerenders at ticker frequency

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.color,
    required this.theme,
    required this.biome,
    required this.defaultDuration,
    required this.onPickAndStart,
  });

  final Color color;
  final FactionTheme theme;
  final Biome biome;
  final Duration defaultDuration;
  final VoidCallback
  onPickAndStart; // Keep as VoidCallback since we pass discoveredCreatures in the call

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Insert a creature to extract resources from this biome.',
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _PrimaryBtn(
          label: 'Insert Alchemon',
          accent: color,
          theme: theme,
          onTap: onPickAndStart,
        ),
        const SizedBox(height: 8),
        Text(
          'Duration: ${defaultDuration.inMinutes}m',
          style: TextStyle(
            color: theme.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
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
    required this.onCollect,
    required this.onCancel,
  });

  final Color color;
  final FactionTheme theme;
  final BiomeFarmState farm;
  final Biome biome;
  final VoidCallback? onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final j = farm.activeJob!;
    final duration = Duration(milliseconds: j.durationMs);
    final rate = j.ratePerMinute;
    final total = rate * duration.inMinutes;

    return Column(
      children: [
        Text(
          'Rate: $rate / min',
          style: TextStyle(
            color: theme.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Total: $total ${biome.resourceLabel}', // UPDATED: simplified
          style: TextStyle(
            color: theme.text,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PrimaryBtn(
                label: 'Collect',
                accent: color,
                theme: theme,
                onTap: (farm.completed && onCollect != null)
                    ? onCollect!
                    : null,
                disabled: !farm.completed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineBtn(
                label: 'Terminate',
                accent: color,
                theme: theme,
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
    required this.onBack,
  });

  final Color color;
  final FactionTheme theme;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HintText(
          'Unlock this extractor from the previous screen.',
          theme: theme,
        ),
        const SizedBox(height: 10),
        _OutlineBtn(
          label: 'Go Back',
          accent: color,
          theme: theme,
          onTap: onBack,
        ),
      ],
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text, {required this.theme});
  final String text;
  final FactionTheme theme;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: theme.text, fontWeight: FontWeight.w700),
    );
  }
}

class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final FactionTheme theme;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(widget.icon, color: widget.theme.text, size: 20),
        ),
      ),
    );
  }
}

class _HeaderShell extends StatelessWidget {
  const _HeaderShell({
    required this.theme,
    required this.accentColor,
    required this.biomeLabel,
    required this.onBack,
    required this.glowController,
  });

  final FactionTheme theme;
  final Color accentColor;
  final String biomeLabel;
  final VoidCallback onBack;
  final AnimationController glowController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _HeaderIconButton(
                icon: Icons.arrow_back_rounded,
                accentColor: accentColor,
                onTap: onBack,
                theme: theme,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      biomeLabel.toUpperCase(),
                      style: TextStyle(
                        color: theme.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Resource Extractor',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              // You can keep your GlowingIcon for help, but let's flatten visuals.
              GlowingIcon(
                icon: Icons.info_outline_rounded,
                color: accentColor,
                controller: glowController,
                dialogTitle: "Biome Extraction",
                dialogMessage:
                    "Extract resources from creatures aligned with this biome. Output type depends on creature element.",
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: widget.accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withValues(alpha: 0.9),
            size: 20,
          ),
        ),
      ),
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



// =================== UI Panels ===================

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.accent,
    required this.theme,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final Color accent; // biome accent
  final FactionTheme theme;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final bg = disabled
        ? theme.textMuted.withValues(alpha: .2)
        : accent.withValues(alpha: .3);
    final border = disabled
        ? theme.textMuted.withValues(alpha: .4)
        : accent.withValues(alpha: .6);

    return Opacity(
      opacity: disabled ? .6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.4),
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.text,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
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
    required this.onTap,
  });

  final String label;
  final Color accent;
  final FactionTheme theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: theme.surface.withValues(alpha: .4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: .55), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: theme.text,
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}

/// Background widget that creates an atmospheric biome environment

/// ============ Alchemy Extraction Chamber ============

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

  /// Tempo ramps up as progress → 1.0 and also spikes during tap FX.
  double _tempo() {
    // baseline 1x, ramps up to ~4x near completion
    final ramp = Curves.easeInQuart.transform(progress).clamp(0.0, 1.0);
    final nearDone = (progress > .85) ? (progress - .85) / .15 : 0.0;
    final endBoost = Curves.easeOutExpo.transform(nearDone.clamp(0, 1));
    // tap spike (bell-shaped)
    final v = tapFxCtrl.value;
    final tapBell = (v == 0) ? 0 : (1 - (2 * (v - .5)).abs()); // 0..1..0
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
                // Creature sits floating inside the chamber, gently idling.
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

                // BACKGROUND + ENERGY CONTENTS
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

                // Tap FX overlay
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

                // GLASS + RIM + GLARE
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
                          offset: Offset(
                            0,
                            size.height * -0.08,
                          ), // float slightly above center
                          child: statusOverlay!,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            builder: (_, child) {
              // Slight "thrum" on collect animation
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

/// Chamber layout: circular vessel with thick rim
class _ChamberGeometry {
  _ChamberGeometry(this.outer, this.inner, this.center, this.radius);
  final RRect outer;
  final RRect inner;
  final Offset center;
  final double radius;

  static _ChamberGeometry fromSize(Size size) {
    // Make the chamber a big circle in the upper 70% area.
    final w = size.width;
    final h = size.height;
    final d = math.min(w, h * 0.78);
    final cx = w / 2;
    final cy = h * 0.42;
    final rect = Rect.fromCenter(center: Offset(cx, cy), width: d, height: d);
    final outer = RRect.fromRectAndRadius(rect, Radius.circular(d / 2));
    final inner = outer.deflate(d * 0.06); // thick rim
    return _ChamberGeometry(outer, inner, Offset(cx, cy), d / 2);
  }
}

// extension _RRectBR removed; use extension _RRectBorderRadius on RRect
// which provides `_toBorderRadius()` to avoid duplicate extension ambiguity.

/// BACK contents: beam, rune rings, sparks — tempo-sensitive.
class _ChamberBackgroundPainter extends CustomPainter {
  _ChamberBackgroundPainter({
    required this.tSeconds,
    required this.tempo,
    required this.fill,
    required this.color,
    required this.active,
  });

  final double tSeconds;
  final double tempo; // <- drives speed-up near completion
  final double fill; // visual power level
  final Color color;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _ChamberGeometry.fromSize(size);
    final inner = geo.inner;
    final c = geo.center;
    final r = geo.radius * 0.92;

    // Clip to vessel interior
    canvas.save();
    canvas.clipRRect(inner);

    // 1) Dim backplate
    final back = Paint()
      ..shader = RadialGradient(
        colors: [Colors.black.withValues(alpha: .45), Colors.black.withValues(alpha: .70)],
      ).createShader(inner.outerRect);
    canvas.drawRect(inner.outerRect, back);

    // 2) Vertical energy beam intensity based on fill
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

    // 3) Concentric rune rings rotating at tempo
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
      // dashed circle
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
      // glyphs that orbit
      for (int i = 0; i < glyphs; i++) {
        final ang = (i / glyphs) * (math.pi * 2);
        final x = math.cos(ang) * radius;
        final y = math.sin(ang) * radius;
        final size = 2.6 + 1.2 * math.sin(baseAngle * (speed + .3) + i);
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-ang + baseAngle * (speed * .6));
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: size,
          height: size * 1.2,
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

    // 4) Spiral-in motes (suction toward center)
    final mote = Paint()..color = Colors.white.withValues(alpha: .70);
    final count = active ? 42 : 18;

    // suction strength grows with fill (0..1) and a bit with tempo
    final suctionBase = 0.20 + 0.55 * Curves.easeOutCubic.transform(fill);
    final swirlBase = 0.60 + 0.80 * Curves.easeIn.transform(fill);

    for (int i = 0; i < count; i++) {
      final seed = i * 1337.0;
      final rand = (seed % 1000) / 1000.0;

      // starting radius & angle
      final r0 = r * (0.20 + 0.75 * rand);
      final a0 = (seed % (2 * math.pi));

      // time for this mote (0..1 loop)
      final speed = (0.35 + (seed % 17) / 40.0) * (0.8 + 0.6 * tempo);
      final t = (tSeconds * speed + (seed % 23) * .013) % 1.0;

      // suction pulls radius inward nonlinearly (faster as it nears center)
      final suction = suctionBase * (0.65 + 0.35 * math.sin(seed));
      final rad = r0 * (1.0 - math.pow(t, 1.35) * suction).clamp(0.0, 1.0);

      // swirl increases as it approaches center to give that vortex feel
      final swirl = swirlBase * (1.0 + 0.7 * (1.0 - rad / r0));
      final ang = a0 + t * 2.0 * math.pi * swirl;

      final px = c.dx + math.cos(ang) * rad;
      final py = c.dy + math.sin(ang) * rad;

      if (inner.outerRect.contains(Offset(px, py))) {
        final sz = 1.1 + ((i % 5 == 0) ? 0.9 : 0.0);
        canvas.drawCircle(Offset(px, py), sz, mote);

        // faint trailing echo to emphasize motion
        final trailT = (t - 0.06).clamp(0.0, 1.0);
        if (trailT > 0) {
          final rad2 = r0 * (1.0 - math.pow(trailT, 1.35) * suction);
          final ang2 = a0 + trailT * 2.0 * math.pi * swirl;
          final p2 = Offset(
            c.dx + math.cos(ang2) * rad2,
            c.dy + math.sin(ang2) * rad2,
          );
          final trail = Paint()..color = Colors.white.withValues(alpha: .10);
          canvas.drawCircle(p2, sz * 0.85, trail);
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

/// FOREGROUND: glass, rim, glare, spinning crown
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

    // Rim
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

    // Chromatic edges
    final redEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFFFF6B6B).withValues(alpha: .33);
    final blueEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF5EC8FF).withValues(alpha: .33);
    canvas.save();
    canvas.translate(.6, .6);
    canvas.drawRRect(outer.deflate(0.6), redEdge);
    canvas.restore();
    canvas.save();
    canvas.translate(-.6, -.6);
    canvas.drawRRect(outer.deflate(0.6), blueEdge);
    canvas.restore();

    // Glass highlight
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomLeft,
            colors: [Colors.white.withValues(alpha: .50), Colors.transparent],
          ).createShader(
            Rect.fromLTWH(outer.left - 6, outer.top, 10, outer.height),
          );
    canvas.drawRRect(outer, highlight);

    // Spinning crown (small outer ticks)
    final crown = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .65);
    final ang = tSeconds * tempo * 1.2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(ang);
    final cr = r * 0.88;
    const tick = 10.0;
    for (int i = 0; i < 24; i++) {
      final a = i / 24 * 2 * math.pi;
      final x1 = math.cos(a) * cr;
      final y1 = math.sin(a) * cr;
      final x2 = math.cos(a) * (cr - tick);
      final y2 = math.sin(a) * (cr - tick);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), crown);
    }
    canvas.restore();

    // Inner glass line
    final innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.white.withValues(alpha: .45);
    canvas.drawRRect(inner, innerStroke);
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
  final String label; // "READY" or "COMPLETE"
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value; // 0..1
        final pulse = 0.65 + 0.35 * math.sin(t * math.pi * 2);
        final glow = 0.25 + 0.55 * (0.5 - (t - 0.5).abs()) * 2; // bell 0..1

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

  final double t;
  final double pulse;
  final double glow;
  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) * 0.48;

    // soft aura
    final aura = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: 0.08 * (0.7 + 0.3 * glow)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: c, radius: r * 1.2));
    canvas.drawCircle(c, r * (1.05 + 0.02 * glow), aura);

    // outer ring (pulsing thickness)
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 + 1.8 * pulse
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(c, r, ring);

    // chromatic edges
    final red = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFF6B6B).withValues(alpha: .38);
    final blue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF5EC8FF).withValues(alpha: .38);
    canvas.save();
    canvas.translate(.8, .8);
    canvas.drawCircle(c, r * 0.985, red);
    canvas.restore();
    canvas.save();
    canvas.translate(-.8, -.8);
    canvas.drawCircle(c, r * 0.985, blue);
    canvas.restore();

    // rotating ticks (arcane crown)
    final ticks = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: .75);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    final tr = r * 0.88;
    const n = 24;
    for (int i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi;
      final x1 = math.cos(a) * tr;
      final y1 = math.sin(a) * tr;
      final x2 = math.cos(a) * (tr - 10);
      final y2 = math.sin(a) * (tr - 10);
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), ticks);
    }
    canvas.restore();

    // label (glowing)
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
          color: Colors.white.withValues(alpha: .95),
          shadows: [
            Shadow(blurRadius: 6 + 10 * glow, color: color.withValues(alpha: .8)),
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
