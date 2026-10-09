import 'package:alchemons/services/onboarding_tasks.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/audio/scene_ambience.dart';
import 'dart:async';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/widgets/achievements/reward_collect_burst.dart';

import 'package:flutter/foundation.dart' show ValueListenable;

import 'package:alchemons/constants/element_resources.dart';
import 'package:alchemons/constants/unlock_costs.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/biome_farm_state.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/harvest_biome.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/services/push_notification_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/game_data_gate.dart';
import 'package:alchemons/utils/harvest_rate.dart';
import 'package:alchemons/widgets/all_specimens_page.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/element_resource_glyph.dart';
import 'package:alchemons/widgets/element_resource_totals_bar.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:alchemons/widgets/dock_passages.dart';
import 'package:alchemons/widgets/fx/extraction_vessel.dart';
import 'package:alchemons/widgets/loading_widget.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ---------------------------------------------------------------------------
// ExtractionHubScreen
// The harvest: five biome chambers, one shown at a time, picked from the
// element totals strip. Each chamber is a flask (ExtractionVessel): put an
// Alchemon of the biome's elements in and its essence fills the glass; the
// level is the job's progress. Tapping the glass while it runs splashes it
// and takes a few seconds off (the tap boost — an easter egg, so it is not
// announced anywhere).
// ---------------------------------------------------------------------------

/// The screen is always dark, so its chrome is too.
const BracketPalette _kPalette = BracketPalette.dark;

class ExtractionHubScreen extends StatefulWidget {
  const ExtractionHubScreen({
    super.key,
    this.service,
    this.revealReady,
    this.passageTarget,
  });

  final HarvestService? service;

  /// Arriving through the dock's Harvest passage: set true once the chamber
  /// is laid out, after [passageTarget] says where its flask stands.
  final ValueNotifier<bool>? revealReady;
  final ValueNotifier<HarvestFlaskTarget?>? passageTarget;

  @override
  State<ExtractionHubScreen> createState() => _ExtractionHubScreenState();
}

class _ExtractionHubScreenState extends State<ExtractionHubScreen>
    with TickerProviderStateMixin {
  late HarvestService _svc;
  bool _tutorialChecked = false;
  String? _selectedBiomeId;

  /// Which chamber the bay shows, resolved once and then held.
  ///
  /// The bay used to fall back to "the first ready biome" whenever nothing had
  /// been picked explicitly. Collecting the chamber on screen makes it stop
  /// being ready, so the fallback moved to the next ready biome and the view
  /// jumped mid-collect — cutting the drain and the particles in half.
  String _resolveSelectedBiomeId(List<BiomeFarmState> farms) {
    final current = _selectedBiomeId;
    if (current != null && farms.any((f) => f.biome.id == current)) {
      return current;
    }
    final ready = farms.where((f) => f.completed);
    if (ready.isNotEmpty) return ready.first.biome.id;
    final active = farms.where((f) => f.hasActive);
    if (active.isNotEmpty) return active.first.biome.id;
    return farms.first.biome.id;
  }

  /// One per biome, kept on the state so the running total for that element
  /// keeps the same key across rebuilds — the collect animation reads its rect
  /// to know where the resources are going.
  final Map<String, GlobalKey> _totalKeys = {};

  /// The bay, so a Collect All payout has somewhere to leave from. It used to
  /// fly out of each biome's chip in the selector rail; with the rail folded
  /// into the totals strip there is no per-biome origin on screen any more, so
  /// they all leave the chamber and fan out to their own totals.
  final GlobalKey _bayKey = GlobalKey(debugLabel: 'extraction_bay');

  GlobalKey _totalKeyFor(String biomeId) => _totalKeys.putIfAbsent(
    biomeId,
    () => GlobalKey(debugLabel: 'total_$biomeId'),
  );

  /// Screen-space rect of the bay, or null if it is not laid out.
  Rect? _bayRect() {
    final box = _bayKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Screen-space centre of a biome's total chip in the header strip.
  Offset? _totalCenter(String biomeId) {
    final ctx = _totalKeys[biomeId]?.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(box.size.center(Offset.zero));
  }

  @override
  void initState() {
    super.initState();
    // Arriving earns the task; collecting it happens in the journal.
    OnboardingTaskService.recordArrival(context, 'harvest');
    _svc = widget.service ?? context.read<HarvestService>();
    final ready = widget.revealReady;
    if (ready == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());
    } else {
      // Not over the passage: once it has given way to the chamber.
      void shown() {
        if (!ready.value) return;
        ready.removeListener(shown);
        Future<void>.delayed(
          const Duration(milliseconds: 1200),
          _maybeShowTutorial,
        );
      }

      ready.addListener(shown);
      shown();
    }
  }

  /// The chamber in view has laid out: where its flask stands, for the
  /// passage to land on. Only the first time.
  void _onChamberPlaced(HarvestFlaskTarget place) {
    final ready = widget.revealReady;
    if (ready == null || ready.value) return;
    widget.passageTarget?.value = place;
    ready.value = true;
  }

  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked || !mounted) return;
    _tutorialChecked = true;
    final db = context.read<AlchemonsDatabase>();
    final hasSeen = await db.settingsDao.hasSeenBiomeHarvestTutorial();
    if (hasSeen || !mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => const _HarvestTutorialDialog(),
    );
    if (mounted) await db.settingsDao.setBiomeHarvestTutorialSeen();
  }

  Future<void> _promptUnlock(BiomeFarmState farm) async {
    final costDb = UnlockCosts.biome(farm.biome);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _UnlockDialog(biome: farm.biome, costDb: costDb),
    );
    if (confirmed != true || !mounted) return;
    final ok = await _svc.unlock(farm.biome, cost: costDb);
    if (!mounted) return;
    // Unlocking a biome costs resources and opens a chamber for good, and it
    // was landing on nothing but a snackbar.
    HapticFeedback.mediumImpact();
    context.sound(
      ok ? SoundCue.upgradeComplete : SoundCue.uiDenied,
      owner: this,
    );
    showGameSnack(
      context,
      ok ? '${farm.biome.label} chamber unlocked' : 'Not enough resources',
      accent: ok ? farm.biome.primaryColor : const Color(0xFFE57373),
    );
  }

  Future<void> _collectAll(List<BiomeFarmState> farms) async {
    HapticFeedback.mediumImpact();
    final completed = farms.where((f) => f.completed).toList();
    final reloadPlans = [
      for (final farm in completed)
        if (farm.activeJob != null)
          _ChamberReloadPlan(
            biome: farm.biome,
            activeElementId: farm.activeElementId,
            job: farm.activeJob!,
          ),
    ];
    if (completed.isNotEmpty) {
      await CampaignJournalService.mark(
        context.read<AlchemonsDatabase>().settingsDao,
        'biomeHarvest',
      );
      if (!mounted) return;
    }

    // Geometry is read before the collects, because a collected job clears
    // and the rail chip it flew out of redraws as idle.
    final flights = <({Rect from, Offset to, Color tint, Biome biome})>[];
    for (final farm in completed) {
      final from = _bayRect();
      final to = _totalCenter(farm.biome.id);
      if (from == null || to == null) continue;
      flights.add((
        from: from,
        to: to,
        tint: farm.currentColor,
        biome: farm.biome,
      ));
    }

    int total = 0;
    final gained = <String, int>{};
    for (final farm in completed) {
      final got = await _svc.collect(farm.biome);
      gained[farm.biome.id] = got;
      total += got;
    }
    if (!mounted) return;
    HapticFeedback.lightImpact();
    if (total > 0) context.sound(SoundCue.extractionComplete, owner: this);

    for (final flight in flights) {
      final got = gained[flight.biome.id] ?? 0;
      if (got <= 0) continue;
      unawaited(
        playRewardCollect(
          context,
          from: flight.from,
          to: flight.to,
          gold: got,
          silver: 0,
          tint: flight.tint,
        ),
      );
    }

    showGameSnack(
      context,
      'Collected $total from ${completed.length} chamber${completed.length == 1 ? '' : 's'}',
    );

    if (reloadPlans.isEmpty || !mounted) return;
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.hasInstantReload()) return;

    final n = reloadPlans.length;
    final shouldReload = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: const Color(0xFFFFB74D),
      title: 'RELOAD ALL?',
      message:
          'Put the same Alchemon back in ${n == 1 ? 'that chamber' : 'all $n chambers'} for another run.',
      confirmLabel: 'RELOAD ALL',
    );
    if (!shouldReload || !mounted) return;

    final db = context.read<AlchemonsDatabase>();
    var reloaded = 0;
    for (final plan in reloadPlans) {
      final instance = await db.creatureDao.getInstance(
        plan.job.creatureInstanceId,
      );
      if (instance == null) continue;

      final elementId = plan.activeElementId;
      if (elementId != null && elementId.isNotEmpty) {
        await _svc.setActiveElement(plan.biome, elementId);
      }
      final ok = await _svc.startJob(
        biome: plan.biome,
        creatureInstanceId: plan.job.creatureInstanceId,
        duration: Duration(milliseconds: plan.job.durationMs),
        ratePerMinute: plan.job.ratePerMinute,
      );
      if (ok) reloaded++;
    }
    if (!mounted) return;

    if (reloaded > 0) HapticFeedback.mediumImpact();
    final failed = reloadPlans.length - reloaded;
    showGameSnack(
      context,
      failed == 0
          ? 'Reloaded $reloaded chamber${reloaded == 1 ? '' : 's'}'
          : 'Reloaded $reloaded of ${reloadPlans.length} chambers',
      accent: failed == 0 ? null : Colors.orange.shade400,
    );
  }

  @override
  Widget build(BuildContext context) =>
      SceneAmbience(cue: AmbienceCue.lab, child: _buildScene(context));

  Widget _buildScene(BuildContext context) {
    return ForcedFactionBrightness(
      brightness: Brightness.dark,
      child: Builder(
        builder: (context) {
          // Rebuilt when the theme changes; the builder below hands it on.
          context.watch<FactionTheme>();
          return Scaffold(
            extendBody: true,
            backgroundColor: _kPalette.bg0,
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
                              gradient: RadialGradient(
                                center: const Alignment(0, -0.1),
                                radius: 1.1,
                                colors: [
                                  const Color(0xFF14110E),
                                  _kPalette.bg0,
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: AlchemicalParticleBackground(),
                        ),
                        SafeArea(
                          child: ListenableBuilder(
                            listenable: _svc,
                            builder: (_, __) {
                              final farms = _svc.biomes;
                              final completedCount = farms
                                  .where((f) => f.completed)
                                  .length;
                              // hasActive covers jobs still running;
                              // completed ones are counted separately.
                              final activeCount = farms
                                  .where((f) => f.hasActive && !f.completed)
                                  .length;
                              final lockedCount = farms
                                  .where((f) => !f.unlocked)
                                  .length;
                              // Held on the state so the choice survives a
                              // farm changing under it. Assigned here rather
                              // than in a callback because this is the value
                              // being rendered this frame.
                              final selectedBiomeId = _resolveSelectedBiomeId(
                                farms,
                              );
                              _selectedBiomeId = selectedBiomeId;
                              final selectedFull = farms.any(
                                (f) =>
                                    f.biome.id == selectedBiomeId &&
                                    f.completed,
                              );
                              return Column(
                                children: [
                                  _HarvestHeader(
                                    chambers: farms.length - lockedCount,
                                    ready: completedCount,
                                    active: activeCount,
                                  ),
                                  // Where a collect lands. The totals are the
                                  // player's actual stock of each element,
                                  // not what one chamber happens to hold.
                                  ElementResourceTotalsBar(
                                    theme: theme,
                                    totalKeys: {
                                      for (final f in farms)
                                        f.biome.id: _totalKeyFor(f.biome.id),
                                    },
                                    states: {
                                      for (final f in farms)
                                        f.biome.id: ElementChamberState(
                                          unlocked: f.unlocked,
                                          ready: f.completed,
                                        ),
                                    },
                                    selectedBiomeId: selectedBiomeId,
                                    onSelect: (id) =>
                                        setState(() => _selectedBiomeId = id),
                                  ),
                                  // Only when a full chamber is off screen
                                  // too: the one in view has its own COLLECT.
                                  if (completedCount > (selectedFull ? 1 : 0))
                                    _CollectAllBanner(
                                      count: completedCount,
                                      onCollectAll: () => _collectAll(farms),
                                    ),
                                  Expanded(
                                    child: _ExtractionBay(
                                      key: _bayKey,
                                      farms: farms,
                                      // Pinned here rather than left to the
                                      // bay's fallback, so a collect cannot
                                      // move the view out from under its own
                                      // animation.
                                      selectedBiomeId: selectedBiomeId,
                                      totalKeys: {
                                        for (final f in farms)
                                          f.biome.id: _totalKeyFor(f.biome.id),
                                      },
                                      theme: theme,
                                      service: _svc,
                                      discoveredCreatures: discovered,
                                      defaultDuration: const Duration(hours: 4),
                                      onUnlock: _promptUnlock,
                                      onPlaced: widget.revealReady == null
                                          ? null
                                          : _onChamberPlaced,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
            ),
          );
        },
      ),
    );
  }
}

class _ChamberReloadPlan {
  const _ChamberReloadPlan({
    required this.biome,
    required this.activeElementId,
    required this.job,
  });

  final Biome biome;
  final String? activeElementId;
  final HarvestJob job;
}

// ---------------------------------------------------------------------------
// _ExtractionBay
// ---------------------------------------------------------------------------

class _ExtractionBay extends StatelessWidget {
  const _ExtractionBay({
    super.key,
    required this.farms,
    required this.theme,
    required this.service,
    required this.discoveredCreatures,
    required this.selectedBiomeId,
    required this.defaultDuration,
    required this.onUnlock,
    required this.totalKeys,
    this.onPlaced,
  });

  final List<BiomeFarmState> farms;
  final FactionTheme theme;
  final HarvestService service;
  final List<CreatureEntry> discoveredCreatures;

  /// Always concrete — the hub resolves and pins it.
  final String selectedBiomeId;
  final Duration defaultDuration;
  final ValueChanged<BiomeFarmState> onUnlock;

  /// One key per biome, anchoring its running total in the header strip — the
  /// number a collect flies to.
  final Map<String, GlobalKey> totalKeys;

  /// Where the flask in view stands once it is laid out.
  final ValueChanged<HarvestFlaskTarget>? onPlaced;

  BiomeFarmState _selectedFarm() {
    if (farms.isEmpty) {
      throw StateError('Extraction bay requires at least one biome.');
    }
    for (final farm in farms) {
      if (farm.biome.id == selectedBiomeId) return farm;
    }
    return farms.first;
  }

  @override
  Widget build(BuildContext context) {
    if (farms.isEmpty) return const SizedBox.shrink();
    final selected = _selectedFarm();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 4, 12, wide ? 26 : 14),
          child: _EmbeddedChamber(
            key: ValueKey('bay-${selected.biome.id}'),
            farm: selected,
            theme: theme,
            service: service,
            discoveredCreatures: discoveredCreatures,
            defaultDuration: defaultDuration,
            onUnlock: () => onUnlock(selected),
            collectTargetKey: totalKeys[selected.biome.id],
            onPlaced: onPlaced,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _CollectAllBanner
// ---------------------------------------------------------------------------

class _CollectAllBanner extends StatelessWidget {
  const _CollectAllBanner({required this.count, required this.onCollectAll});
  final int count;
  final VoidCallback onCollectAll;

  @override
  Widget build(BuildContext context) {
    const ready = Color(0xFF8FD99F);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: ready.withValues(alpha: 0.6),
          bracketSize: 9,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          color: _kPalette.surfaceFill(),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '$count CHAMBER${count == 1 ? '' : 'S'} FULL',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: ready,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              SizedBox(
                width: 150,
                child: BracketButton(
                  label: 'COLLECT ALL',
                  height: 36,
                  palette: _kPalette,
                  accent: ready,
                  onTap: onCollectAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmbeddedChamber — the flask and everything it does
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
    this.collectTargetKey,
    this.onPlaced,
  });

  final BiomeFarmState farm;
  final FactionTheme theme;
  final HarvestService service;
  final List<CreatureEntry> discoveredCreatures;
  final Duration defaultDuration;
  final VoidCallback onUnlock;

  /// The chip label the collected resources fly to.
  final GlobalKey? collectTargetKey;

  /// Where its flask stands once laid out (with the Alchemon in it, if it
  /// has one, read) — for a passage landing on it.
  final ValueChanged<HarvestFlaskTarget>? onPlaced;

  @override
  State<_EmbeddedChamber> createState() => _EmbeddedChamberState();
}

class _EmbeddedChamberState extends State<_EmbeddedChamber>
    with TickerProviderStateMixin {
  DateTime? _lastTapBoostAt;

  /// Runs the pour when the chamber is emptied: a collect, or ending a run.
  late final AnimationController _drainCtrl;
  late final AnimationController _jobCtrl;

  /// How full the flask is, as a live value: the job's progress, and while a
  /// collect pours out, what is left of it. The vessel reads it per frame, so
  /// neither the 4-hour fill nor the drain waits on a rebuild.
  final ValueNotifier<double> _level = ValueNotifier<double>(0);

  /// What the chamber held when a pour began. The job clears the instant
  /// the collect lands, so draining from live state would snap to empty
  /// instead of emptying.
  double _drainFrom = 0;
  bool _draining = false;

  /// What the vessel showed when the pour began, held through it: the job
  /// is gone the moment a collect lands, and the flask would otherwise go
  /// cold and grey mid-pour.
  VesselMode _drainMode = VesselMode.running;

  final GlobalKey _vesselKey = GlobalKey(debugLabel: 'extraction_vessel');

  ({Creature base, CreatureInstance inst})? _creature;
  String? _cachedInstanceId;

  /// The Alchemon in it has been looked up (or there is none): the flask
  /// has stopped moving aside for it.
  bool _creatureRead = false;
  bool _placed = false;

  /// Set when an Alchemon has just been put in, so it gathers into the glass.
  EssenceReveal? _reveal;

  @override
  void initState() {
    super.initState();
    _drainCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _jobCtrl = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    );
    // The drain is the collect's whole visual payload, so it runs off the
    // controller rather than waiting on a rebuild that never comes.
    _drainCtrl.addListener(_pushDrain);
    // A 4-hour fill riding the job controller, so it moves.
    _jobCtrl.addListener(_pushLevel);
    PushNotificationService().cancelHarvestSummaryNotification();
    _refreshCreatureCache();
  }

  @override
  void didUpdateWidget(covariant _EmbeddedChamber old) {
    super.didUpdateWidget(old);
    // Mid-pour the creature stays in the glass; the pour's end refreshes it.
    if (!_draining &&
        widget.farm.activeJob?.creatureInstanceId != _cachedInstanceId) {
      _refreshCreatureCache();
    }
  }

  void _pushDrain() {
    if (!_draining) return;
    final left = 1 - Curves.easeInOutCubic.transform(_drainCtrl.value);
    _level.value = _drainFrom * left;
  }

  void _pushLevel() {
    if (_draining) return;
    _level.value = widget.farm.hasActive ? _jobCtrl.value : 0;
  }

  @override
  void dispose() {
    _drainCtrl.removeListener(_pushDrain);
    _jobCtrl.removeListener(_pushLevel);
    _level.dispose();
    _jobCtrl.dispose();
    _drainCtrl.dispose();
    super.dispose();
  }

  // ── Creature cache ────────────────────────────────────────────────────────

  Future<void> _refreshCreatureCache() async {
    final job = widget.service.biome(widget.farm.biome).activeJob;
    if (job == null) {
      _cachedInstanceId = null;
      _creatureRead = true;
      if (mounted) setState(() => _creature = null);
      return;
    }
    if (_cachedInstanceId == job.creatureInstanceId && _creature != null) {
      return;
    }
    _cachedInstanceId = job.creatureInstanceId;
    final db = context.read<AlchemonsDatabase>();
    final inst = await db.creatureDao.getInstance(job.creatureInstanceId);
    if (!mounted) return;
    final base = inst == null
        ? null
        : context.read<CreatureCatalog>().getCreatureById(inst.baseId);
    setState(() {
      _creatureRead = true;
      _creature = (inst == null || base == null || base.spriteData == null)
          ? null
          : (base: base, inst: inst);
    });
  }

  /// Once, after it is laid out: where the flask stands and what is in it.
  void _reportPlace(VesselMode mode, Color accent) {
    if (_placed || widget.onPlaced == null || !_creatureRead) return;
    _placed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bulb = ExtractionVessel.bulbOf(
        _vesselKey,
        occupied: _creature != null,
      );
      if (bulb == null) return;
      const cold = Color(0xFF6E6A73);
      widget.onPlaced!(
        HarvestFlaskTarget(
          centre: bulb.centre,
          radius: bulb.radius,
          ink: switch (mode) {
            VesselMode.locked => cold,
            VesselMode.empty => Color.lerp(accent, cold, 0.45)!,
            _ => accent,
          },
          level: switch (mode) {
            VesselMode.ready => 1,
            VesselMode.running => _level.value,
            _ => 0,
          },
        ),
      );
    });
  }

  // ── Progress sync ─────────────────────────────────────────────────────────

  Duration? _syncProgress(BiomeFarmState farm) {
    final job = farm.activeJob;
    if (job == null) {
      if (_jobCtrl.value != 0) _jobCtrl.value = 0;
      if (_jobCtrl.isAnimating) _jobCtrl.stop();
      if (!_draining) _level.value = 0;
      return null;
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
    // A pour owns the level until it finishes. Letting the live job state
    // write it mid-drain is what made the chamber snap to empty the moment
    // the job cleared, instead of emptying.
    if (!_draining) _level.value = _jobCtrl.value;
    return _jobCtrl.duration! * (1 - _jobCtrl.value);
  }

  // ── Tap boost ─────────────────────────────────────────────────────────────

  void _handleTapBoost(BiomeFarmState farm) {
    if (!farm.hasActive || farm.completed || _draining) return;
    final now = DateTime.now();
    final lastBoost = _lastTapBoostAt;
    if (lastBoost != null &&
        now.difference(lastBoost) < HarvestService.tapBoostThrottle) {
      return;
    }
    _lastTapBoostAt = now;
    final totalMs = farm.activeJob!.durationMs;
    final boostMs = HarvestService.tapBoostStep.inMilliseconds;
    final currentMs = (1.0 - _jobCtrl.value) * totalMs;
    final newMs = (currentMs - boostMs).clamp(0, totalMs).toDouble();
    _jobCtrl.value = 1.0 - (newMs / totalMs);
    widget.service.nudge(widget.farm.biome, by: HarvestService.tapBoostStep);
  }

  // ── Start job ─────────────────────────────────────────────────────────────

  Future<void> _handlePickAndStart() async {
    final theme = widget.theme;
    final repo = context.read<CreatureCatalog>();
    final busyIds = widget.farm.activeJob != null
        ? [widget.farm.activeJob!.creatureInstanceId]
        : <String>[];
    final picked = await Navigator.of(context).push<CreatureInstance>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => AllSpecimensPage(
          theme: theme,
          instancePrefsScopeKey: 'harvest_biome_${widget.farm.biome.id}',
          popOnSelect: true,
          title: 'SELECT SPECIMEN',
          allowedPrimaryTypes: widget.farm.biome.elementTypes,
          onWillSelectInstance: (inst) async {
            if (busyIds.contains(inst.instanceId)) {
              _showToast(
                'That specimen is already extracting.',
                icon: AppIcons.block_rounded,
                color: Colors.orange.shade400,
              );
              return false;
            }

            final base = repo.getCreatureById(inst.baseId);
            if (base == null ||
                base.types.isEmpty ||
                !widget.farm.biome.elementTypes.contains(base.types.first)) {
              _showToast(
                'Only ${widget.farm.biome.label.toLowerCase()} specimens can work here.',
                icon: AppIcons.filter_alt_off_rounded,
                color: Colors.orange.shade400,
              );
              return false;
            }

            return true;
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

    final inst = picked;
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.types.isEmpty) return;
    final creatureTypeId = base.types.first;
    await widget.service.setActiveElement(widget.farm.biome, creatureTypeId);
    final ok = await widget.service.startJob(
      biome: widget.farm.biome,
      creatureInstanceId: inst.instanceId,
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
      HapticFeedback.mediumImpact();
      _reveal = EssenceReveal.once();
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not start extraction.',
        icon: AppIcons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Collect ───────────────────────────────────────────────────────────────

  /// The flask's mouth and the total it pays into, in screen space: the
  /// resources pour up out of the neck and fly to their number.
  ({Rect from, Offset to})? _collectFlight() {
    final toCtx = widget.collectTargetKey?.currentContext;
    if (toCtx == null || !mounted) return null;
    final from = ExtractionVessel.mouthOf(_vesselKey);
    final toBox = toCtx.findRenderObject();
    if (from == null || toBox is! RenderBox || !toBox.hasSize) return null;
    return (
      from: from,
      to: toBox.localToGlobal(toBox.size.center(Offset.zero)),
    );
  }

  /// Starts the pour: the liquid goes up out of the neck as the level falls.
  Future<void> _pour(VesselMode mode) {
    _drainFrom = _level.value;
    _drainMode = mode;
    _draining = true;
    setState(() {});
    return _drainCtrl.forward(from: 0);
  }

  void _endPour() {
    _draining = false;
    _drainCtrl.value = 0;
  }

  Future<void> _handleCollect(BiomeFarmState farm) async {
    if (_draining) return;
    final previousJob = farm.activeJob;
    HapticFeedback.mediumImpact();

    // Read the geometry before the collect: the job clears as it lands.
    final flight = _collectFlight();

    // Emptying and streaming out are one motion, so the pour starts here and
    // is not awaited until the particles are already on their way. Awaiting it
    // first left a second of dead air before anything moved.
    final drain = _pour(VesselMode.ready);
    // On the drain, not on the write that comes back after it has started.
    context.sound(SoundCue.harvestCollect, owner: this);

    final got = await widget.service.collect(widget.farm.biome);
    if (!mounted) {
      _draining = false;
      return;
    }
    HapticFeedback.lightImpact();

    // The resources visibly leave the chamber and land on the total they are
    // added to, in the biome's own color. A beat in, so they come out of the
    // stream rather than ahead of it.
    if (flight != null && got > 0) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 260), () async {
          if (!mounted) return;
          await playRewardCollect(
            context,
            from: flight.from,
            to: flight.to,
            gold: got,
            silver: 0,
            tint: widget.farm.currentColor,
          );
        }),
      );
    }

    await drain;
    if (!mounted) return;
    _endPour();

    await _refreshCreatureCache();
    if (previousJob == null || !mounted) return;
    final constellations = context.read<ConstellationEffectsService>();
    if (!constellations.hasInstantReload()) return;
    final shouldReload = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: widget.farm.biome.primaryColor,
      title: 'RELOAD?',
      message: 'Put the same Alchemon back in for another run.',
      confirmLabel: 'RELOAD',
    );
    if (!shouldReload || !mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final inst = await db.creatureDao.getInstance(
      previousJob.creatureInstanceId,
    );
    if (inst == null) {
      _showToast(
        'That creature is no longer available.',
        icon: AppIcons.error_outline,
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
      _reveal = EssenceReveal.once();
      await _refreshCreatureCache();
    } else {
      _showToast(
        'Could not reload.',
        icon: AppIcons.error_outline,
        color: Colors.red.shade400,
      );
    }
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  Future<void> _handleCancel() async {
    if (_draining) return;
    final confirmed = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: const Color(0xFFE57373),
      title: 'END THIS RUN?',
      message: 'Your Alchemon comes back, but what is in the flask is lost.',
      confirmLabel: 'END RUN',
    );
    if (!confirmed || !mounted) return;
    HapticFeedback.heavyImpact();
    await _pour(VesselMode.running);
    await widget.service.cancel(widget.farm.biome);
    if (!mounted) return;
    _endPour();
    HapticFeedback.lightImpact();
    _showToast('Run ended', icon: AppIcons.info_rounded);
    await _refreshCreatureCache();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showToast(
    String msg, {
    IconData icon = AppIcons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    showGameSnack(context, msg, accent: color);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (_, __) {
        final farm = widget.service.biome(widget.farm.biome);
        final accent = farm.currentColor;
        final remaining = _syncProgress(farm);
        final mode = _draining
            ? _drainMode
            : !farm.unlocked
            ? VesselMode.locked
            : farm.completed
            ? VesselMode.ready
            : farm.hasActive
            ? VesselMode.running
            : VesselMode.empty;
        final creature = _creature;
        _reportPlace(mode, accent);
        return Column(
          children: [
            _ChamberTitle(farm: farm, mode: mode, accent: accent),
            const SizedBox(height: 4),
            Expanded(
              child: ExtractionVessel(
                key: _vesselKey,
                accent: accent,
                mode: mode,
                level: _level,
                vent: _drainCtrl,
                creatureId: creature?.inst.instanceId,
                element: creature?.base.types.firstOrNull,
                reveal: _reveal,
                lockedIcon: AppIcons.lock_rounded,
                creature: creature == null
                    ? null
                    : (size) => InstanceSprite(
                        creature: creature.base,
                        instance: creature.inst,
                        size: size,
                      ),
                onTap: mode == VesselMode.locked
                    ? widget.onUnlock
                    : () => _handleTapBoost(farm),
              ),
            ),
            const SizedBox(height: 8),
            _ChamberPanel(
              farm: farm,
              mode: mode,
              accent: accent,
              remaining: remaining,
              level: _level,
              onStart: _handlePickAndStart,
              onCollect: () => _handleCollect(farm),
              onCancel: _handleCancel,
              onUnlock: widget.onUnlock,
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Title + panel
// ---------------------------------------------------------------------------

String _modeWord(VesselMode mode) => switch (mode) {
  VesselMode.locked => 'LOCKED',
  VesselMode.empty => 'EMPTY',
  VesselMode.running => 'EXTRACTING',
  VesselMode.ready => 'FULL',
};

class _ChamberTitle extends StatelessWidget {
  const _ChamberTitle({
    required this.farm,
    required this.mode,
    required this.accent,
  });

  final BiomeFarmState farm;
  final VesselMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final word = _modeWord(mode);
    final wordColor = switch (mode) {
      VesselMode.locked => _kPalette.muted,
      VesselMode.empty => _kPalette.muted,
      VesselMode.running => accent,
      VesselMode.ready => const Color(0xFF8FD99F),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${farm.biome.label} chamber',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    21,
                    _kPalette.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  farm.biome.elementTypes.join(' · ').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: farm.biome.primaryColor.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Text(
              word,
              style: TextStyle(
                fontFamily: 'monospace',
                color: wordColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The chamber's controls and what it is doing, under the flask.
class _ChamberPanel extends StatelessWidget {
  const _ChamberPanel({
    required this.farm,
    required this.mode,
    required this.accent,
    required this.remaining,
    required this.level,
    required this.onStart,
    required this.onCollect,
    required this.onCancel,
    required this.onUnlock,
  });

  final BiomeFarmState farm;
  final VesselMode mode;
  final Color accent;
  final Duration? remaining;
  final ValueListenable<double> level;
  final VoidCallback onStart;
  final VoidCallback onCollect;
  final VoidCallback onCancel;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    const full = Color(0xFF8FD99F);
    final job = farm.activeJob;
    final (String line, Color lineColor) = switch (mode) {
      VesselMode.locked => (
        'Unlock this chamber to extract ${farm.biome.label.toLowerCase()} essence',
        _kPalette.muted,
      ),
      VesselMode.empty => (
        'Put in a ${_typeList(farm.biome.elementTypes)} Alchemon',
        _kPalette.muted,
      ),
      VesselMode.running => (
        job == null
            ? ''
            : '${_formatHarvestRemaining(remaining)} left · ${job.ratePerMinute}/min',
        _kPalette.ink,
      ),
      VesselMode.ready => ('Full — ready to collect', full),
    };

    final Widget buttons = switch (mode) {
      VesselMode.locked => BracketButton(
        label: 'UNLOCK CHAMBER',
        palette: _kPalette,
        accent: const Color(0xFFFFB74D),
        onTap: onUnlock,
      ),
      VesselMode.empty => BracketButton(
        label: 'INSERT ALCHEMON',
        palette: _kPalette,
        accent: accent,
        onTap: onStart,
      ),
      VesselMode.running || VesselMode.ready => Row(
        children: [
          Expanded(
            flex: 3,
            child: BracketButton(
              label: 'COLLECT',
              palette: _kPalette,
              accent: mode == VesselMode.ready ? full : accent,
              enabled: mode == VesselMode.ready,
              onTap: onCollect,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: BracketButton(
              label: 'END RUN',
              primary: false,
              palette: _kPalette,
              accent: accent,
              onTap: onCancel,
            ),
          ),
        ],
      ),
    };

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.45),
        bracketSize: 12,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        color: _kPalette.surfaceFill(darkAlpha: 0.6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        12.5,
                        lineColor,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (mode == VesselMode.running)
                    ValueListenableBuilder<double>(
                      valueListenable: level,
                      builder: (_, v, __) => Text(
                        '${(v * 100).floor()}%',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            buttons,
          ],
        ),
      ),
    );
  }
}

/// ['Fire', 'Lava', 'Lightning'] → "Fire, Lava or Lightning".
String _typeList(List<String> types) {
  if (types.length <= 1) return types.join();
  return '${types.sublist(0, types.length - 1).join(', ')} or ${types.last}';
}

String _formatHarvestRemaining(Duration? d) {
  if (d == null) return '';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return '${m}m ${s}s';
  return '${s}s';
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// A dialog in the screen's bracket frame.
class _BracketDialog extends StatelessWidget {
  const _BracketDialog({
    required this.accent,
    required this.title,
    required this.children,
  });

  final Color accent;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: accent.withValues(alpha: 0.9),
          bracketSize: 14,
          strokeWidth: 1.3,
        ),
        child: Container(
          color: _kPalette.bg1,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _kPalette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _HarvestTutorialDialog extends StatelessWidget {
  const _HarvestTutorialDialog();

  @override
  Widget build(BuildContext context) {
    const amber = Color(0xFFFFB74D);
    Widget step(String n, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text(
              n,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: amber,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: bracketText(
                context,
                13.5,
                _kPalette.ink.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
    return _BracketDialog(
      accent: amber,
      title: 'HARVEST',
      children: [
        step(
          '1',
          'Pick a chamber from the strip at the top. Each one takes '
              'Alchemons of its own elements.',
        ),
        step(
          '2',
          'Put an Alchemon in. Its essence fills the flask over a few hours.',
        ),
        step(
          '3',
          'When the flask is full, collect it. Your Alchemon comes back.',
        ),
        const SizedBox(height: 8),
        BracketButton(
          label: 'GOT IT',
          height: 42,
          palette: _kPalette,
          accent: amber,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _UnlockDialog extends StatelessWidget {
  const _UnlockDialog({required this.biome, required this.costDb});
  final Biome biome;
  final Map<String, int> costDb;

  @override
  Widget build(BuildContext context) {
    final color = biome.primaryColor;
    final db = context.read<AlchemonsDatabase>();
    return StreamBuilder<Map<String, int>>(
      stream: db.currencyDao.watchResourceBalances(),
      builder: (context, snap) {
        final bal = snap.data ?? {};
        final short = costDb.entries.any((e) => (bal[e.key] ?? 0) < e.value);
        return _BracketDialog(
          accent: color,
          title: 'UNLOCK ${biome.label.toUpperCase()}',
          children: [
            Text(
              '${biome.description}. Its chamber takes '
              '${_typeList(biome.elementTypes)} Alchemons.',
              style: bracketText(
                context,
                13.5,
                _kPalette.ink.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'COSTS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _kPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            for (final e in costDb.entries)
              _CostRow(
                resourceKey: e.key,
                need: e.value,
                have: bal[e.key] ?? 0,
              ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BracketButton(
                    label: 'CANCEL',
                    primary: false,
                    height: 42,
                    palette: _kPalette,
                    accent: color,
                    onTap: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BracketButton(
                    label: short ? 'NOT ENOUGH' : 'UNLOCK',
                    height: 42,
                    palette: _kPalette,
                    accent: color,
                    enabled: !short,
                    onTap: () => Navigator.pop(context, true),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.resourceKey,
    required this.need,
    required this.have,
  });

  final String resourceKey;
  final int need;
  final int have;

  @override
  Widget build(BuildContext context) {
    final res = ElementResources.byKey[resourceKey];
    final ok = have >= need;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (res != null)
            ElementResourceGlyph.of(res, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              res?.biomeLabel ?? resourceKey,
              style: bracketText(
                context,
                13,
                _kPalette.ink,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${formatCoins(have)} / ${formatCoins(need)}',
            style: TextStyle(
              fontFamily: 'monospace',
              color: ok ? const Color(0xFF8FD99F) : const Color(0xFFE57373),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen header: back, the title, and live counts so the state of the bays
/// reads without visiting every chamber.
class _HarvestHeader extends StatelessWidget {
  const _HarvestHeader({
    required this.chambers,
    required this.ready,
    required this.active,
  });

  final int chambers;
  final int ready;
  final int active;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      '$chambers OPEN',
      if (active > 0) '$active EXTRACTING',
      if (ready > 0) '$ready FULL',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.arrow_back,
            palette: _kPalette,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'HARVEST',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFFFB74D),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: ready > 0
                        ? const Color(0xFF8FD99F)
                        : _kPalette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
