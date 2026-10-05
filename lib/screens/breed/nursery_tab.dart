import 'package:alchemons/audio/audio.dart';
import 'dart:async';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/responsive_grid.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/nursery/brewing_card_widget.dart';
import 'package:alchemons/widgets/nursery/batch_extraction_ceremony.dart';
import 'package:alchemons/widgets/nursery/egg_extraction_dialog.dart';
import 'package:alchemons/widgets/nursery/empty_chamber.dart';
import 'package:alchemons/widgets/cold_storage_glyph.dart';
import 'package:alchemons/widgets/instant_extractor_glyph.dart';
import 'package:alchemons/widgets/nursery/hatch_curtain.dart';
import 'package:alchemons/widgets/nursery/non_ready_hatch_widget.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:flutter/material.dart';
import 'package:alchemons/widgets/fx/starter_vial_handoff.dart';
import 'package:alchemons/widgets/game_snack.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class NurseryTab extends StatefulWidget {
  final DateTime? maxSeenNowUtc;
  final VoidCallback onHatchComplete;
  final VoidCallback onRequestAddEgg;
  final VoidCallback onRequestFusion;

  const NurseryTab({
    super.key,
    this.maxSeenNowUtc,
    required this.onHatchComplete,
    required this.onRequestAddEgg,
    required this.onRequestFusion,
  });

  @override
  State<NurseryTab> createState() => _NurseryTabState();
}

class _NurseryTabState extends State<NurseryTab> {
  static const double _fusionSwipeTriggerDistance = 72;
  static const double _fusionSwipeDominanceRatio = 1.25;

  final Map<String, bool> _undiscoveredCache = {};
  final GlobalKey _storageSectionKey = GlobalKey();

  /// The first chamber's cell: where the starter vial lands at the end of
  /// the faction handoff (starter_vial_handoff.dart).
  final GlobalKey _firstChamberKey = GlobalKey(debugLabel: 'first-chamber');

  /// The opening's first extraction is still to do: a ready chamber gets one
  /// line saying to tap it. Re-read whenever the chambers change.
  bool _extractionPending = false;
  String _pendingCheckedFor = '';
  final CinematicQualityService _qualityService = CinematicQualityService();
  bool _suspendNurseryAnimations = false;
  int _animationPauseHolds = 0;
  CinematicQuality _cinematicQuality = CinematicQuality.cinematic;
  bool _debugToolsEnabled = DebugSettingsService.toolsVisible;
  Offset? _swipeStartGlobalPosition;
  bool _fusionSwipeTriggered = false;

  /// One-shot timer that fires exactly when the soonest incubating egg
  /// is due to complete.  We reschedule it after every rebuild so we
  /// only call setState() when a state change is actually possible.
  Timer? _nextReadyTimer;

  @override
  void initState() {
    super.initState();
    StarterVialHandoff.instance.chamberKey = _firstChamberKey;
    _loadCinematicQuality();
    CinematicQualityService.qualityNotifier.addListener(
      _handleCinematicQualityChanged,
    );
    DebugSettingsService.enabledNotifier.addListener(_handleDebugToolsChanged);
    DebugSettingsService().isEnabled();
  }

  void _handleDebugToolsChanged() {
    if (!mounted) return;
    final enabled = DebugSettingsService.toolsVisible;
    if (enabled != _debugToolsEnabled) {
      setState(() => _debugToolsEnabled = enabled);
    }
  }

  void _handleCinematicQualityChanged() {
    if (!mounted) return;
    final next = CinematicQualityService.qualityNotifier.value;
    if (next != _cinematicQuality) {
      setState(() => _cinematicQuality = next);
    }
  }

  Future<void> _loadCinematicQuality() async {
    final quality = await _qualityService.getQuality();
    if (!mounted) return;
    setState(() => _cinematicQuality = quality);
  }

  @override
  void dispose() {
    CinematicQualityService.qualityNotifier.removeListener(
      _handleCinematicQualityChanged,
    );
    DebugSettingsService.enabledNotifier.removeListener(
      _handleDebugToolsChanged,
    );
    _nextReadyTimer?.cancel();
    if (StarterVialHandoff.instance.chamberKey == _firstChamberKey) {
      StarterVialHandoff.instance.chamberKey = null;
    }
    super.dispose();
  }

  void _refreshExtractionPending(List<IncubatorSlot> slots) {
    final sig = slots.map((s) => '${s.id}:${s.eggId}').join(',');
    if (sig == _pendingCheckedFor) return;
    _pendingCheckedFor = sig;
    context
        .read<AlchemonsDatabase>()
        .settingsDao
        .getSetting('tutorial_extraction_pending')
        .then((v) {
          final pending = v == '1';
          if (mounted && pending != _extractionPending) {
            setState(() => _extractionPending = pending);
          }
        });
  }

  /// Cancels any pending timer and schedules a new one-shot timer that
  /// fires 1 s after the earliest incomplete egg is due.  A single
  /// setState() then refreshes the grid precisely when needed instead
  /// of every second.
  void _scheduleNextReadyTimer(List<IncubatorSlot> slots) {
    _nextReadyTimer?.cancel();
    _nextReadyTimer = null;

    final now = DateTime.now().toUtc();
    Duration? soonest;

    for (final slot in slots) {
      final ms = slot.hatchAtUtcMs;
      if (ms == null) continue;
      final remaining = DateTime.fromMillisecondsSinceEpoch(
        ms,
        isUtc: true,
      ).difference(now);
      if (remaining.inMilliseconds <= 0) continue;
      if (soonest == null || remaining < soonest) soonest = remaining;
    }

    if (soonest != null) {
      // Fire 1 s after the egg is due so the remaining check reliably
      // returns <= 0 even with minor clock skew.
      _nextReadyTimer = Timer(soonest + const Duration(seconds: 1), () {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _instantHatchSlot(IncubatorSlot slot) async {
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();

    // Must have an egg and a target time
    if (slot.eggId == null || slot.hatchAtUtcMs == null) {
      _showToast(
        'No active specimen in this chamber',
        color: Colors.blue.shade600,
      );
      return;
    }

    // Already ready?
    final remaining = _remainingFor(slot.hatchAtUtcMs!);
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      // Just fall back to normal hatch flow
      await _hatchFromSlot(slot);
      return;
    }

    // Check item qty
    final qty = await db.inventoryDao.getItemQty(InvKeys.instantHatch);
    if (qty <= 0) {
      _showToast('No Instant Fusion Extractors', color: Colors.red.shade600);
      return;
    }

    // (Optional) confirm use
    final confirm = await _showConfirmDialog(
      'INSTANT FUSION EXTRACTOR',
      'Consume one to finish this cultivation now. The specimen will be ready '
          'to extract immediately.',
      confirmLabel: 'USE',
      artwork: const InstantExtractorGlyph(size: 68),
    );
    if (!mounted || !confirm) return;

    // Consume the item (guards against race)
    final consumed = await db.inventoryDao.consumeItem(
      InvKeys.instantHatch,
      qty: 1,
    );
    if (!consumed) {
      _showToast(
        'Instant Fusion Extractor unavailable',
        color: Colors.red.shade600,
      );
      return;
    }

    // Nudge the chamber so hatch time == now (server-safe clamp in DB)
    final safeNow = _safeNowUtc();
    await db.incubatorDao.speedUpSlot(
      slotId: slot.id,
      delta: remaining, // move forward by what's left
      safeNowUtc: safeNow,
    );

    // Re-read the slot to ensure we hatch the latest state
    final latest = await (db.select(
      db.incubatorSlots,
    )..where((t) => t.id.equals(slot.id))).getSingleOrNull();

    if (latest == null || latest.hatchAtUtcMs == null) {
      _showToast(
        'Specimen updated, please retry',
        color: Colors.orange.shade600,
      );
      return;
    }

    // Immediately hatch
    await _hatchFromSlot(latest);

    if (!mounted) return;
    _showToast('Cultivation complete', color: Colors.green.shade600);
  }

  @override
  Widget build(BuildContext context) {
    // Use read — the DB object itself never changes; the stream below
    // provides reactive updates without re-subscribing on every build.
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();
    final canBatchExtract =
        _debugToolsEnabled ||
        context.watch<ConstellationEffectsService>().hasBatchExtraction();

    return StreamBuilder<List<IncubatorSlot>>(
      stream: db.incubatorDao.watchSlots(),
      builder: (context, snap) {
        final slots = snap.data ?? const <IncubatorSlot>[];

        // Schedule a one-shot timer so the grid refreshes the moment
        // the soonest egg becomes ready, instead of every second.
        _scheduleNextReadyTimer(slots);
        _preloadUndiscoveredStatus(slots);
        _refreshExtractionPending(slots);

        final activeSlots =
            (slots
                .where(
                  (s) =>
                      s.unlocked && s.eggId != null && s.hatchAtUtcMs != null,
                )
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id)));

        final unlockedEmptySlots =
            (slots
                .where(
                  (s) =>
                      s.unlocked && (s.eggId == null || s.hatchAtUtcMs == null),
                )
                .toList()
              ..sort((a, b) => a.id.compareTo(b.id)));

        final totalUnlocked = activeSlots.length + unlockedEmptySlots.length;
        Duration? nextReady;
        bool anyReady = false;
        final readySlots = <IncubatorSlot>[];
        for (final s in activeSlots) {
          final rem = _remainingFor(s.hatchAtUtcMs!);
          if (rem.inSeconds <= 0) {
            anyReady = true;
            readySlots.add(s);
            continue;
          }
          if (nextReady == null || rem < nextReady) nextReady = rem;
        }

        final showBatch = canBatchExtract && readySlots.length > 1;

        return TickerMode(
          enabled: !_suspendNurseryAnimations,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _resetSwipeTracking,
            onPointerCancel: _resetSwipeTracking,
            // A sliver viewport, not a SingleChildScrollView: that one clamps
            // an overscroll back to the edge whenever its child re-lays out
            // (a countdown, a cell waking up), which cut the bounce short and
            // let it coast on to rest a few pixels below the top.
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader(
                          'ACTIVE CULTIVATION',
                          AppIcons.science_rounded,
                          theme.text,
                          trailing: totalUnlocked == 0
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (showBatch) ...[
                                      _BatchExtractButton(
                                        count: readySlots.length,
                                        theme: theme,
                                        onTap: () =>
                                            _extractAllReady(readySlots),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    // Beside EXTRACT ALL, only the count:
                                    // the button says what is ready, and a
                                    // countdown too crowds out the heading.
                                    _ChamberStatusBadge(
                                      activeCount: activeSlots.length,
                                      totalCount: totalUnlocked,
                                      nextReady: showBatch ? null : nextReady,
                                      anyReady: anyReady && !showBatch,
                                      theme: theme,
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 12),
                        _buildChamberGrid(
                          chambers: [...activeSlots, ...unlockedEmptySlots]
                            ..sort((a, b) => a.id.compareTo(b.id)),
                          primaryColor: theme.text,
                          theme: theme,
                        ),
                        if (_extractionPending && anyReady)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Center(
                              child: Text(
                                'TAP THE VIAL TO EXTRACT',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.8,
                                  color: BracketPalette.of(context).muted,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 24),
                        KeyedSubtree(
                          key: _storageSectionKey,
                          child: StorageSection(
                            primaryColor: theme.text,
                            buildSectionHeader: _buildSectionHeader,
                            quality: _cinematicQuality,
                            canAutoMove: canBatchExtract,
                            presentDialog: (builder) =>
                                _showDialogWithPausedBackground<void>(
                                  builder: builder,
                                ),
                            onExtract: _hatchFromStorage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _extractAllReady(List<IncubatorSlot> readySlots) async {
    if (readySlots.length < 2 || !mounted) return;
    final confirmed = await _showConfirmDialog(
      'CONSTELLATION EXTRACTION',
      'Extract all ${readySlots.length} ready chambers in one ceremony? Each specimen will still be revealed and analyzed individually.',
      confirmLabel: 'EXTRACT ALL',
      accent: const Color(0xFF67E8F9),
    );
    if (!mounted || !confirmed) return;

    _acquireBackgroundAnimationPause();
    int? completed;
    try {
      completed = await showGeneralDialog<int>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'batch extraction',
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => BatchExtractionCeremony(
          slots: List<IncubatorSlot>.from(readySlots),
          undiscoveredCache: _undiscoveredCache,
        ),
      );
    } finally {
      _releaseBackgroundAnimationPause();
    }
    if (!mounted || (completed ?? 0) <= 0) return;
    widget.onHatchComplete();
    _showToast(
      '$completed specimen${completed == 1 ? '' : 's'} extracted',
      color: const Color(0xFF34D399),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    _fusionSwipeTriggered = false;
    _swipeStartGlobalPosition = _isInStorageSection(event.position)
        ? null
        : event.position;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final start = _swipeStartGlobalPosition;
    if (start == null || _fusionSwipeTriggered) return;

    final delta = event.position - start;
    final leftwardDistance = -delta.dx;
    if (leftwardDistance < _fusionSwipeTriggerDistance) return;

    final verticalDistance = delta.dy.abs();
    if (leftwardDistance <= verticalDistance * _fusionSwipeDominanceRatio) {
      return;
    }

    _fusionSwipeTriggered = true;
    _swipeStartGlobalPosition = null;
    widget.onRequestFusion();
  }

  void _resetSwipeTracking(PointerEvent _) {
    _swipeStartGlobalPosition = null;
    _fusionSwipeTriggered = false;
  }

  bool _isInStorageSection(Offset globalPosition) {
    final storageContext = _storageSectionKey.currentContext;
    if (storageContext == null) return false;

    final renderObject = storageContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;

    final localPosition = renderObject.globalToLocal(globalPosition);
    return localPosition.dx >= 0 &&
        localPosition.dy >= 0 &&
        localPosition.dx <= renderObject.size.width &&
        localPosition.dy <= renderObject.size.height;
  }

  void _preloadUndiscoveredStatus(List<IncubatorSlot> slots) {
    for (final slot in slots) {
      if (slot.resultCreatureId != null &&
          !_undiscoveredCache.containsKey(slot.resultCreatureId!)) {
        _undiscoveredCache[slot.resultCreatureId!] = false;
        EggHatching.isUndiscovered(context, slot.resultCreatureId!).then((
          result,
        ) {
          if (mounted) {
            setState(() {
              _undiscoveredCache[slot.resultCreatureId!] = result;
            });
          }
        });
      }
    }
  }

  /// Every unlocked chamber, in chamber order.
  ///
  /// This used to draw the occupied chambers first and then a run of anonymous
  /// placeholders, so a chamber's position in the grid had nothing to do with
  /// its number: with chamber 1 empty, the cultivation in chamber 2 sat in the
  /// first cell while its details — and the "added to chamber N" toast —
  /// called it 2. A chamber is a numbered place, so an empty one holds its
  /// position rather than being swept to the end.
  Widget _buildChamberGrid({
    required List<IncubatorSlot> chambers,
    required Color primaryColor,
    required FactionTheme theme,
  }) {
    final totalCount = chambers.length;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCrossAxisCount(context, phoneCols: 2),
        childAspectRatio: 1.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        final cell = _buildChamberCell(
          chambers[index],
          primaryColor: primaryColor,
          theme: theme,
        );
        return index == 0
            ? KeyedSubtree(key: _firstChamberKey, child: cell)
            : cell;
      },
    );
  }

  Widget _buildChamberCell(
    IncubatorSlot chamber, {
    required Color primaryColor,
    required FactionTheme theme,
  }) {
    final occupied = chamber.eggId != null && chamber.hatchAtUtcMs != null;
    if (occupied) {
      final slot = chamber;
      final remaining = _remainingFor(slot.hatchAtUtcMs!);
      final ready = remaining.inSeconds <= 0;
      final rarity = slot.rarity?.toLowerCase();
      final hatchDelay = rarity != null
          ? BreedConstants.rarityHatchTimes[rarity]
          : null;

      double? progress;
      if (hatchDelay != null && hatchDelay.inMilliseconds > 0) {
        final left = remaining.isNegative ? Duration.zero : remaining;
        final done = (hatchDelay.inMilliseconds - left.inMilliseconds).clamp(
          0,
          hatchDelay.inMilliseconds,
        );
        progress = done / hatchDelay.inMilliseconds;
      }

      final rarityColor = BreedConstants.getRarityColor(
        slot.rarity ?? 'common',
      );
      final statusColor = ready ? Colors.green : rarityColor;

      final isUndiscovered = _undiscoveredCache[slot.resultCreatureId!] == true;

      final egg = Egg(
        eggId: slot.eggId!,
        resultCreatureId: slot.resultCreatureId!,
        rarity: slot.rarity ?? 'common',
        remainingMs: remaining.inMilliseconds,
        payloadJson: slot.payloadJson,
      );

      return NurseryBrewingCard(
        key: ValueKey('slot-${slot.id}'),
        egg: egg,
        statusColor: statusColor,
        isReady: ready,
        progress: progress,
        quality: _cinematicQuality,
        useSimpleFusion: false,
        theme: theme,
        onTap: () => _showSlotInfoModal(
          slot,
          ready,
          primaryColor,
          remaining,
          progress,
          isUndiscovered,
        ),
      );
    }

    return EmptyChamber(
      key: ValueKey('empty-${chamber.id}'),
      theme: theme,
      onTap: widget.onRequestAddEgg,
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData _,
    Color color, {
    Widget? trailing,
  }) {
    final palette = BracketPalette.of(context);
    final formatted = _toSentenceCase(title);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(width: 3, height: 16, color: color),
              const SizedBox(width: 8),
              // Give the label first claim on the available width. With equal
              // flex, the decorative rule consumed half of this row and
              // truncated "Active cultivation" on phone layouts even though
              // there was ample room for the full title.
              Flexible(
                flex: 5,
                child: Text(
                  formatted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(
                    context,
                    13,
                    palette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 1, color: palette.lineSoft)),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing],
      ],
    );
  }

  String _toSentenceCase(String value) {
    if (value.isEmpty) return value;
    final lower = value.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  void _showSlotInfoModal(
    IncubatorSlot slot,
    bool ready,
    Color primaryColor,
    Duration remaining,
    double? progress,
    bool isUndiscovered,
  ) {
    if (ready) {
      unawaited(_showExtractionDialog(slot, primaryColor, isUndiscovered));
    } else {
      unawaited(
        _showDialogWithPausedBackground<void>(
          barrierColor: Colors.black87,
          builder: (context) => _SlotInfoDialogWrapper(
            slot: slot,
            primaryColor: primaryColor,
            isUndiscovered: isUndiscovered,
            maxSeenNowUtc: widget.maxSeenNowUtc,
            onAccelerate: () {
              Navigator.pop(context);
              _speedUpSlot(slot.id);
            },
            onReturn: () {
              Navigator.pop(context);
              _cancelToInventory(slot);
            },
            onInstantHatch: () {
              Navigator.pop(context);
              _instantHatchSlot(slot);
            },
            onClose: () => Navigator.pop(context),
          ),
        ),
      );
    }
  }

  Future<void> _startHatchFromReadyPopup(
    IncubatorSlot slot, {
    required VoidCallback closeDialog,
  }) async {
    // Go dark first, then close the dialog underneath. Popping first left the
    // nursery on screen at full brightness for the length of the close
    // animation plus the hatch's own database work, and the cinematic then cut
    // in over it.
    await HatchCurtain.raise(context);
    closeDialog();
    if (!mounted) {
      HatchCurtain.lower();
      return;
    }
    await _hatchFromSlot(slot);
  }

  Future<void> _showExtractionDialog(
    IncubatorSlot slot,
    Color primaryColor,
    bool isUndiscovered,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final extractionDone = await db.settingsDao
        .hasCompletedExtractionTutorial();
    if (!mounted) return;
    await _showDialogWithPausedBackground<void>(
      barrierColor: Colors.black87,
      builder: (context) => ExtractionDialog(
        slot: slot,
        primaryColor: primaryColor,
        isUndiscovered: isUndiscovered,
        isTutorial: !extractionDone,
        onExtract: () {
          final nav = Navigator.of(context);
          unawaited(_startHatchFromReadyPopup(slot, closeDialog: nav.pop));
        },
        onDiscard: () {
          Navigator.pop(context);
          _showDiscardConfirmation(slot);
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showDiscardConfirmation(IncubatorSlot slot) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);
    final palette = BracketPalette.fromTheme(theme);
    unawaited(
      _showDialogWithPausedBackground<void>(
        barrierColor: Colors.black87,
        builder: (context) => _NurseryDialog(
          accent: t.danger,
          title: 'DISCARD SPECIMEN?',
          actions: [
            BracketButton(
              label: 'CANCEL',
              primary: false,
              height: 42,
              palette: palette,
              accent: t.danger,
              onTap: () => Navigator.pop(context),
            ),
            BracketButton(
              label: 'DISCARD',
              height: 42,
              palette: palette,
              accent: t.danger,
              onTap: () async {
                Navigator.pop(context);
                await context.read<AlchemonsDatabase>().incubatorDao.clearEgg(
                  slot.id,
                );
                _showToast('Specimen discarded', color: Colors.red.shade600);
              },
            ),
          ],
          children: [
            Text(
              'This destroys the specimen. It cannot be undone.',
              style: bracketText(
                context,
                13.5,
                palette.ink.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _safeNowUtc() {
    final now = DateTime.now().toUtc();
    return (widget.maxSeenNowUtc != null && now.isBefore(widget.maxSeenNowUtc!))
        ? widget.maxSeenNowUtc!
        : now;
  }

  Duration _remainingFor(int hatchAtUtcMs) {
    final hatchAt = DateTime.fromMillisecondsSinceEpoch(
      hatchAtUtcMs,
      isUtc: true,
    );
    final now = _safeNowUtc();
    return hatchAt.difference(now);
  }

  Future<void> _speedUpSlot(int slotId) async {
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final slot = await (db.select(
      db.incubatorSlots,
    )..where((t) => t.id.equals(slotId))).getSingleOrNull();

    if (slot == null || slot.hatchAtUtcMs == null) return;

    final remaining = _remainingFor(slot.hatchAtUtcMs!);
    if (remaining.isNegative || remaining.inSeconds <= 0) {
      _showToast('Specimen is already ready', color: Colors.blue.shade600);
      return;
    }

    final halfTime = remaining ~/ 2;
    final halfCost = _calculateAccelerationCost(halfTime);
    final fullCost = _calculateAccelerationCost(remaining);

    if (!mounted) return;

    unawaited(
      _showDialogWithPausedBackground<void>(
        builder: (context) => _buildAccelerationDialog(
          slotId,
          slot,
          remaining,
          halfTime,
          halfCost,
          fullCost,
        ),
      ),
    );
  }

  int _calculateAccelerationCost(Duration duration) {
    final minutes = duration.inMinutes;
    return (minutes / 5).ceil().clamp(1, 1000);
  }

  Widget _buildAccelerationDialog(
    int slotId,
    IncubatorSlot slot,
    Duration remaining,
    Duration halfTime,
    int halfCost,
    int fullCost,
  ) {
    final palette = BracketPalette.of(context);
    // Lit in gold: what it is paid in.
    const gold = Color(0xFFE4C16A);
    return _NurseryDialog(
      accent: gold,
      title: 'ACCELERATE',
      subtitle: 'Ready in ${BreedConstants.formatRemaining(remaining)}',
      actions: [
        BracketButton(
          label: 'CANCEL',
          primary: false,
          height: 42,
          palette: palette,
          accent: gold,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
      children: [
        _AccelerateOption(
          title: 'HALF TIME',
          detail: 'Ready in ${BreedConstants.formatRemaining(halfTime)}',
          cost: halfCost,
          palette: palette,
          onTap: () => _performAcceleration(slotId, halfTime, halfCost, 'Half'),
        ),
        const SizedBox(height: 8),
        _AccelerateOption(
          title: 'FINISH NOW',
          detail: 'Ready to extract',
          cost: fullCost,
          palette: palette,
          onTap: () =>
              _performAcceleration(slotId, remaining, fullCost, 'Full'),
        ),
      ],
    );
  }

  Future<void> _performAcceleration(
    int slotId,
    Duration speedUpAmount,
    int goldCost,
    String type,
  ) async {
    if (mounted) Navigator.of(context).pop();

    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();

    final goldBalance = await db.currencyDao.getGoldBalance();
    if (goldBalance < goldCost) {
      final deficit = goldCost - goldBalance;
      if (mounted) {
        _showToast(
          'Insufficient gold (need $deficit)',
          color: Colors.red.shade600,
        );
      }
      return;
    }

    final success = await db.currencyDao.spendGold(goldCost);
    if (!success) {
      if (mounted) {
        _showToast('Transaction failed', color: Colors.red.shade600);
      }
      return;
    }

    final safeNow = _safeNowUtc();
    await db.incubatorDao.speedUpSlot(
      slotId: slotId,
      delta: speedUpAmount,
      safeNowUtc: safeNow,
    );

    if (mounted) {
      _showToast(
        '$type acceleration complete! ($goldCost gold)',
        color: Colors.green.shade600,
      );
    }
  }

  Future<void> _cancelToInventory(IncubatorSlot slot) async {
    if (!mounted) return;

    if (slot.eggId == null || slot.hatchAtUtcMs == null) return;

    final confirmed = await _showConfirmDialog(
      'MOVE TO COLD STORAGE',
      'Cultivation continues in storage, but at a fifth of the pace. The '
          'chamber is freed for something else.',
      confirmLabel: 'TRANSFER',
      accent: const Color(0xFF5CC4F2),
      artwork: const ColdStorageGlyph(size: 68),
    );

    if (!mounted || !confirmed) return;

    final db = context.read<AlchemonsDatabase>();
    final remaining = _remainingFor(slot.hatchAtUtcMs!);

    await db.incubatorDao.enqueueEgg(
      eggId: slot.eggId!,
      resultCreatureId: slot.resultCreatureId!,
      rarity: slot.rarity ?? 'common',
      remaining: remaining.isNegative ? Duration.zero : remaining,
      payloadJson: slot.payloadJson,
    );

    await db.incubatorDao.clearEgg(slot.id);

    if (mounted) {
      _showToast(
        'Specimen moved to cold storage',
        color: Colors.orange.shade600,
      );
    }
  }

  Future<void> _hatchFromSlot(IncubatorSlot slot) async {
    if (!mounted) return;

    _acquireBackgroundAnimationPause();

    // No-op when the ready popup already raised it. The other hatch entries —
    // instant fuse, and a chamber that finished while the sheet was open —
    // get the same cover for free.
    await HatchCurtain.raise(context);
    if (!mounted) {
      HatchCurtain.lower();
      _releaseBackgroundAnimationPause();
      return;
    }

    late final HatchingResult result;
    try {
      result = await EggHatching.performHatching(
        context: context,
        slot: slot,
        undiscoveredCache: _undiscoveredCache,
      );
    } finally {
      // The cinematic drops the curtain itself once it is up; this is the
      // backstop for the paths that never got that far.
      HatchCurtain.lower();
      _releaseBackgroundAnimationPause();
    }

    if (!mounted) return;

    if (result.success) {
      widget.onHatchComplete();
    } else if (result.message != null) {
      _showToast(result.message!, color: result.color ?? Colors.red.shade600);
    }
  }

  /// A cold-storage extraction, run as a chamber's is: the background
  /// paused, the curtain (raised by the dialog) held until the ceremony takes
  /// over, and the same toast if it fails.
  Future<void> _hatchFromStorage(Egg egg) async {
    if (!mounted) {
      HatchCurtain.lower();
      return;
    }
    _acquireBackgroundAnimationPause();
    await HatchCurtain.raise(context);
    if (!mounted) {
      HatchCurtain.lower();
      _releaseBackgroundAnimationPause();
      return;
    }

    late final HatchingResult result;
    try {
      result = await EggHatching.performStorageHatching(
        context: context,
        egg: egg,
        undiscoveredCache: _undiscoveredCache,
      );
    } finally {
      HatchCurtain.lower();
      _releaseBackgroundAnimationPause();
    }

    if (!mounted) return;
    if (result.success) {
      widget.onHatchComplete();
    } else if (result.message != null) {
      _showToast(result.message!, color: result.color ?? Colors.red.shade600);
    }
  }

  void _showToast(String message, {Color? color}) {
    if (!mounted) return;
    showGameSnack(
      context,
      message,
      accent: color,
      duration: const Duration(seconds: 2),
    );
  }

  /// The nursery's confirm dialog. It takes the artwork of whatever is being
  /// spent, so the player sees the item rather than reads its name.
  Future<bool> _showConfirmDialog(
    String title,
    String message, {
    String confirmLabel = 'CONFIRM',
    Color? accent,
    Widget? artwork,
  }) async {
    final theme = context.read<FactionTheme>();
    final tint = accent ?? ForgeTokens(theme).amber;
    final palette = BracketPalette.fromTheme(theme);

    return await _showDialogWithPausedBackground<bool>(
          barrierColor: Colors.black87,
          builder: (context) => _NurseryDialog(
            accent: tint,
            title: title,
            actions: [
              BracketButton(
                label: 'CANCEL',
                primary: false,
                height: 42,
                palette: palette,
                accent: tint,
                onTap: () => Navigator.of(context).pop(false),
              ),
              BracketButton(
                label: confirmLabel,
                height: 42,
                palette: palette,
                accent: tint,
                onTap: () => Navigator.of(context).pop(true),
              ),
            ],
            children: [
              if (artwork != null) ...[
                Center(child: artwork),
                const SizedBox(height: 14),
              ],
              Text(
                message,
                style: bracketText(
                  context,
                  13.5,
                  palette.ink.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _acquireBackgroundAnimationPause() {
    _animationPauseHolds += 1;
    if (mounted && !_suspendNurseryAnimations) {
      setState(() => _suspendNurseryAnimations = true);
    }
  }

  void _releaseBackgroundAnimationPause() {
    if (_animationPauseHolds > 0) {
      _animationPauseHolds -= 1;
    }
    if (_animationPauseHolds == 0 && mounted && _suspendNurseryAnimations) {
      setState(() => _suspendNurseryAnimations = false);
    }
  }

  Future<T?> _showDialogWithPausedBackground<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
  }) async {
    if (!mounted) return null;
    _acquireBackgroundAnimationPause();
    try {
      return await showDialog<T>(
        context: context,
        barrierDismissible: barrierDismissible,
        barrierColor: barrierColor,
        builder: (dialogContext) =>
            TickerMode(enabled: true, child: Builder(builder: builder)),
      );
    } finally {
      _releaseBackgroundAnimationPause();
    }
  }
}

// ============================================================================
// WRAPPER FOR SLOT INFO DIALOG WITH LIVE TIMER
// ============================================================================

class _SlotInfoDialogWrapper extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;
  final bool isUndiscovered;
  final DateTime? maxSeenNowUtc;
  final VoidCallback onAccelerate;
  final VoidCallback onReturn;
  final VoidCallback onClose;
  final VoidCallback onInstantHatch;

  const _SlotInfoDialogWrapper({
    required this.slot,
    required this.primaryColor,
    required this.isUndiscovered,
    required this.maxSeenNowUtc,
    required this.onAccelerate,
    required this.onReturn,
    required this.onClose,
    required this.onInstantHatch,
  });

  @override
  State<_SlotInfoDialogWrapper> createState() => _SlotInfoDialogWrapperState();
}

class _SlotInfoDialogWrapperState extends State<_SlotInfoDialogWrapper> {
  /// Drives the countdown.
  ///
  /// The only other thing rebuilding this dialog is watchSlots, and a slot
  /// row does not change while it is simply cultivating — so the remaining
  /// time was computed once, on open, and then sat there. The empty initState
  /// and dispose left behind were where this used to be.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  DateTime _safeNowUtc() {
    final now = DateTime.now().toUtc();
    return (widget.maxSeenNowUtc != null && now.isBefore(widget.maxSeenNowUtc!))
        ? widget.maxSeenNowUtc!
        : now;
  }

  Duration _remainingFor(int hatchAtUtcMs) {
    final hatchAt = DateTime.fromMillisecondsSinceEpoch(
      hatchAtUtcMs,
      isUtc: true,
    );
    final now = _safeNowUtc();
    return hatchAt.difference(now);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return StreamBuilder<List<IncubatorSlot>>(
      stream: db.incubatorDao.watchSlots(),
      builder: (context, snapshot) {
        // Get the latest slot data
        final currentSlot =
            snapshot.data?.firstWhere(
              (s) => s.id == widget.slot.id,
              orElse: () => widget.slot,
            ) ??
            widget.slot;

        // Calculate fresh values every build (every second via timer)
        final remaining = currentSlot.hatchAtUtcMs != null
            ? _remainingFor(currentSlot.hatchAtUtcMs!)
            : Duration.zero;

        return SlotInfoDialog(
          slot: currentSlot,
          primaryColor: widget.primaryColor,
          remaining: remaining,
          isUndiscovered: widget.isUndiscovered,
          onAccelerate: widget.onAccelerate,
          onInstantHatch: widget.onInstantHatch,
          onReturn: widget.onReturn,
          onClose: widget.onClose,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAMBER STATUS BADGE
// ─────────────────────────────────────────────────────────────────────────────

/// EXTRACT ALL beside the count: a word lit from below, as the kit's buttons
/// are. It was an outlined chip with a glow round it.
class _BatchExtractButton extends StatelessWidget {
  const _BatchExtractButton({
    required this.count,
    required this.theme,
    required this.onTap,
  });

  final int count;
  final FactionTheme theme;
  final VoidCallback onTap;

  static const _accent = Color(0xFF67E8F9);

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    // BracketButton's own size is a dialog's; this sits in a heading beside
    // the count, so it is the heading's size.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(color: _accent),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          color: palette.accentWash(_accent, darkAlpha: 0.16),
          child: Text(
            'EXTRACT ALL $count',
            style: TextStyle(
              fontFamily: 'monospace',
              color: palette.ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

/// "1 / 4  2h 59m" beside the heading, bare like cold storage's count: how
/// many chambers are working, then the soonest finish — or READY.
class _ChamberStatusBadge extends StatelessWidget {
  const _ChamberStatusBadge({
    required this.activeCount,
    required this.totalCount,
    required this.nextReady,
    required this.anyReady,
    required this.theme,
  });

  final int activeCount;
  final int totalCount;
  final Duration? nextReady;
  final bool anyReady;
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    final status = anyReady
        ? ('READY', ForgeTokens(theme).success)
        : nextReady != null
        ? (BreedConstants.formatRemaining(nextReady!), palette.ink)
        : null;

    TextStyle mono(Color color) => TextStyle(
      fontFamily: 'monospace',
      color: color,
      fontSize: 12,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.6,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$activeCount / $totalCount', style: mono(palette.muted)),
        if (status != null) ...[
          const SizedBox(width: 12),
          Text(status.$1, style: mono(status.$2)),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOGS
// ─────────────────────────────────────────────────────────────────────────────

/// The nursery's dialogs — accelerate, confirm, discard — in the bare kit:
/// the panel's own fill lit from below in what it is about, a monospace
/// title, plain words, and buttons side by side. They were rounded outlines
/// with an accent stripe beside the title.
class _NurseryDialog extends StatelessWidget {
  const _NurseryDialog({
    required this.accent,
    required this.title,
    required this.children,
    required this.actions,
    this.subtitle,
  });

  final Color accent;
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            strokeWidth: 1.3,
          ),
          child: Container(
            color: palette.bg1,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: bracketText(context, 12.5, palette.muted),
                  ),
                ],
                const SizedBox(height: 14),
                ...children,
                const SizedBox(height: 18),
                Row(
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      Expanded(child: actions[i]),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One way to speed a cultivation up: what it does, when it would be ready,
/// and its price in gold. A dark well, no outline; the price is a coin.
class _AccelerateOption extends StatelessWidget {
  const _AccelerateOption({
    required this.title,
    required this.detail,
    required this.cost,
    required this.palette,
    required this.onTap,
  });

  final String title;
  final String detail;
  final int cost;
  final BracketPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.chromeFill(darkAlpha: 0.7, lightAlpha: 0.6),
      child: InkWell(
        onTap: context.soundAction(onTap),
        splashColor: palette.ink.withValues(alpha: 0.06),
        highlightColor: palette.ink.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: palette.ink,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: bracketText(context, 12.5, palette.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CoinAmount(
                kind: CoinKind.gold,
                amount: cost,
                size: 15,
                color: coinColor(CoinKind.gold, palette),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
