import 'dart:async';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/nursery/brewing_card_widget.dart';
import 'package:alchemons/widgets/nursery/egg_extraction_dialog.dart';
import 'package:alchemons/widgets/nursery/non_ready_hatch_widget.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NurseryTab extends StatefulWidget {
  final DateTime? maxSeenNowUtc;
  final VoidCallback onHatchComplete;
  final VoidCallback onRequestAddEgg;

  const NurseryTab({
    super.key,
    this.maxSeenNowUtc,
    required this.onHatchComplete,
    required this.onRequestAddEgg,
  });

  @override
  State<NurseryTab> createState() => _NurseryTabState();
}

class _NurseryTabState extends State<NurseryTab> {
  final Map<String, bool> _undiscoveredCache = {};

  /// One-shot timer that fires exactly when the soonest incubating egg
  /// is due to complete.  We reschedule it after every rebuild so we
  /// only call setState() when a state change is actually possible.
  Timer? _nextReadyTimer;

  @override
  void dispose() {
    _nextReadyTimer?.cancel();
    super.dispose();
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
        icon: Icons.info_outline_rounded,
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
      _showToast(
        'No Instant Hatch items',
        icon: Icons.flash_off_rounded,
        color: Colors.red.shade600,
      );
      return;
    }

    // (Optional) confirm use
    final confirm = await _showConfirmDialog(
      'Use Instant Hatch',
      'Consume 1 Instant Hatch to complete this specimen immediately?',
    );
    if (!mounted || !confirm) return;

    // Consume the item (guards against race)
    final consumed = await db.inventoryDao.consumeItem(
      InvKeys.instantHatch,
      qty: 1,
    );
    if (!consumed) {
      _showToast(
        'Instant Hatch unavailable',
        icon: Icons.error_outline_rounded,
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
        icon: Icons.info_outline_rounded,
        color: Colors.orange.shade600,
      );
      return;
    }

    // Immediately hatch
    await _hatchFromSlot(latest);

    if (!mounted) return;
    _showToast(
      'Instant hatch complete!',
      icon: Icons.flash_on_rounded,
      color: Colors.green.shade600,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use read — the DB object itself never changes; the stream below
    // provides reactive updates without re-subscribing on every build.
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();

    return StreamBuilder<List<IncubatorSlot>>(
      stream: db.incubatorDao.watchSlots(),
      builder: (context, snap) {
        final slots = snap.data ?? const <IncubatorSlot>[];

        // Schedule a one-shot timer so the grid refreshes the moment
        // the soonest egg becomes ready, instead of every second.
        _scheduleNextReadyTimer(slots);
        _preloadUndiscoveredStatus(slots);

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

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'ACTIVE CULTIVATION',
                Icons.science_rounded,
                theme.text,
              ),
              const SizedBox(height: 12),
              _buildActiveGridWithPlaceholders(
                activeSlots: activeSlots,
                placeholders: unlockedEmptySlots.length,
                primaryColor: theme.text,
                theme: theme,
              ),
              const SizedBox(height: 24),
              StorageSection(
                primaryColor: theme.text,
                buildSectionHeader: _buildSectionHeader,
              ),
            ],
          ),
        );
      },
    );
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

  Widget _buildActiveGridWithPlaceholders({
    required List<IncubatorSlot> activeSlots,
    required int placeholders,
    required Color primaryColor,
    required FactionTheme theme,
  }) {
    final totalCount = activeSlots.length + placeholders;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < activeSlots.length) {
          final slot = activeSlots[index];
          final remaining = _remainingFor(slot.hatchAtUtcMs!);
          final ready = remaining.inSeconds <= 0;
          final rarity = slot.rarity?.toLowerCase();
          final hatchDelay = rarity != null
              ? BreedConstants.rarityHatchTimes[rarity]
              : null;

          double? progress;
          if (hatchDelay != null && hatchDelay.inMilliseconds > 0) {
            final left = remaining.isNegative ? Duration.zero : remaining;
            final done = (hatchDelay.inMilliseconds - left.inMilliseconds)
                .clamp(0, hatchDelay.inMilliseconds);
            progress = done / hatchDelay.inMilliseconds;
          }

          final rarityColor = BreedConstants.getRarityColor(
            slot.rarity ?? 'common',
          );
          final statusColor = ready ? Colors.green : rarityColor;

          final isUndiscovered =
              _undiscoveredCache[slot.resultCreatureId!] == true;

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

        return _PlaceholderTile(
          primaryColor: theme.text,
          onTap: widget.onRequestAddEgg,
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        // Vertical accent bar with glow
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .5),
                blurRadius: 7,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        // Icon badge
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withValues(alpha: .25), width: 1),
          ),
          child: Icon(icon, color: color, size: 12),
        ),
        const SizedBox(width: 10),
        // Title
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(width: 12),
        // Decorative fade-out line
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: .35), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
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
      _showExtractionDialog(slot, primaryColor, isUndiscovered);
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
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
      );
    }
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
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => ExtractionDialog(
        slot: slot,
        primaryColor: primaryColor,
        isUndiscovered: isUndiscovered,
        isTutorial: !extractionDone,
        onExtract: () {
          Navigator.pop(context);
          _hatchFromSlot(slot);
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
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.danger.withValues(alpha: .45)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 28,
                      decoration: BoxDecoration(
                        color: t.danger,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: t.danger.withValues(alpha: .45),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'DISCARD SPECIMEN?',
                      style: TextStyle(
                        color: t.danger,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'This will permanently destroy the specimen. This action cannot be undone.',
                  style: TextStyle(
                    color: theme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _DiscardButton(
                        label: 'CANCEL',
                        color: theme.textMuted,
                        filled: false,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DiscardButton(
                        label: 'DISCARD',
                        color: t.danger,
                        filled: true,
                        onTap: () async {
                          Navigator.pop(context);
                          await context
                              .read<AlchemonsDatabase>()
                              .incubatorDao
                              .clearEgg(slot.id);
                          _showToast(
                            'Specimen discarded',
                            icon: Icons.delete_forever_rounded,
                            color: Colors.red.shade600,
                          );
                        },
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
      _showToast(
        'Specimen is already ready',
        icon: Icons.info_rounded,
        color: Colors.blue.shade600,
      );
      return;
    }

    final halfTime = remaining ~/ 2;
    final halfCost = _calculateAccelerationCost(halfTime);
    final fullCost = _calculateAccelerationCost(remaining);

    if (!mounted) return;

    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

    showDialog(
      context: context,
      builder: (context) => _buildAccelerationDialog(
        slotId,
        slot,
        remaining,
        halfTime,
        halfCost,
        fullCost,
        primaryColor,
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
    Color primaryColor,
  ) {
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              color: t.bg1,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: t.borderMid),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: t.bg2,
                    border: Border(bottom: BorderSide(color: t.borderMid)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: .5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ACCELERATE DEVELOPMENT',
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Remaining: ${BreedConstants.formatRemaining(remaining)}',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Options
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    children: [
                      _buildAccelerationOption(
                        theme: theme,
                        t: t,
                        title: 'HALF TIME',
                        subtitle: 'Reduce time by 50%',
                        newTime: BreedConstants.formatRemaining(halfTime),
                        cost: halfCost,
                        accentColor: primaryColor,
                        onTap: () => _performAcceleration(
                          slotId,
                          halfTime,
                          halfCost,
                          'Half',
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildAccelerationOption(
                        theme: theme,
                        t: t,
                        title: 'INSTANT COMPLETION',
                        subtitle: 'Complete immediately',
                        newTime: 'Ready now',
                        cost: fullCost,
                        accentColor: const Color(0xFF22C55E),
                        onTap: () => _performAcceleration(
                          slotId,
                          remaining,
                          fullCost,
                          'Full',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withValues(alpha: .25),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _DiscardButton(
                        label: 'CANCEL',
                        color: theme.textMuted,
                        filled: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccelerationOption({
    required FactionTheme theme,
    required ForgeTokens t,
    required String title,
    required String subtitle,
    required String newTime,
    required int cost,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final radius = BorderRadius.circular(4);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: accentColor.withValues(alpha: .15),
        highlightColor: accentColor.withValues(alpha: .07),
        child: Ink(
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .07),
            borderRadius: radius,
            border: Border.all(color: accentColor.withValues(alpha: .35)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 11,
                            color: accentColor.withValues(alpha: .7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            newTime,
                            style: TextStyle(
                              color: accentColor.withValues(alpha: .85),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Gold cost badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: .45),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Color(0xFFF59E0B),
                        size: 16,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        cost.toString(),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
          icon: Icons.warning_rounded,
          color: Colors.red.shade600,
        );
      }
      return;
    }

    final success = await db.currencyDao.spendGold(goldCost);
    if (!success) {
      if (mounted) {
        _showToast(
          'Transaction failed',
          icon: Icons.error_rounded,
          color: Colors.red.shade600,
        );
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
        icon: Icons.speed_rounded,
        color: Colors.green.shade600,
      );
    }
  }

  Future<void> _cancelToInventory(IncubatorSlot slot) async {
    if (!mounted) return;

    if (slot.eggId == null || slot.hatchAtUtcMs == null) return;

    final confirmed = await _showConfirmDialog(
      'Return to Storage',
      'Transfer this specimen back to storage? Development will continue there.',
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
        'Specimen returned to storage',
        icon: Icons.inventory_2_rounded,
        color: Colors.orange.shade600,
      );
    }
  }

  Future<void> _hatchFromSlot(IncubatorSlot slot) async {
    if (!mounted) return;

    final result = await EggHatching.performHatching(
      context: context,
      slot: slot,
      undiscoveredCache: _undiscoveredCache,
    );

    if (!mounted) return;

    if (result.success) {
      widget.onHatchComplete();
    } else if (result.message != null) {
      _showToast(
        result.message!,
        icon: result.icon ?? Icons.error_rounded,
        color: result.color ?? Colors.red.shade600,
      );
    }
  }

  void _showToast(
    String message, {
    IconData icon = Icons.info_rounded,
    Color? color,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        showCloseIcon: true,
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color ?? Colors.indigo.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final theme = context.read<FactionTheme>();
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, style: TextStyle(color: theme.text)),
            content: Text(
              message,
              style: TextStyle(color: theme.text.withValues(alpha: 0.8)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
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
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
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

        final rarity = currentSlot.rarity?.toLowerCase();
        final hatchDelay = rarity != null
            ? BreedConstants.rarityHatchTimes[rarity]
            : null;

        double progress = 0.0;
        if (hatchDelay != null && hatchDelay.inMilliseconds > 0) {
          final left = remaining.isNegative ? Duration.zero : remaining;
          final done = (hatchDelay.inMilliseconds - left.inMilliseconds).clamp(
            0,
            hatchDelay.inMilliseconds,
          );
          progress = done / hatchDelay.inMilliseconds;
        }

        return SlotInfoDialog(
          slot: currentSlot,
          primaryColor: widget.primaryColor,
          remaining: remaining,
          progress: progress.clamp(0, 1),
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

// ============================================================================
// PLACEHOLDER TILE
// ============================================================================

class _PlaceholderTile extends StatefulWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const _PlaceholderTile({required this.primaryColor, required this.onTap});

  @override
  State<_PlaceholderTile> createState() => _PlaceholderTileState();
}

class _PlaceholderTileState extends State<_PlaceholderTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.3, end: 0.75).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, _) {
          final a = _pulseAnim.value;
          return Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: widget.primaryColor.withValues(alpha: a * .55),
                width: 1,
              ),
            ),
            child: CustomPaint(
              foregroundPainter: _CornerBracketsPainter(
                color: widget.primaryColor.withValues(alpha: a),
                bracketLength: 14,
                bracketWidth: 2,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.primaryColor.withValues(alpha: a * .12),
                        border: Border.all(
                          color: widget.primaryColor.withValues(alpha: a * .45),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: widget.primaryColor.withValues(alpha: 
                          (a + .3).clamp(0, 1),
                        ),
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PLACE SPECIMEN',
                      style: TextStyle(
                        color: widget.primaryColor.withValues(alpha: 
                          (a + .2).clamp(0, 1),
                        ),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// CORNER BRACKETS PAINTER
// ============================================================================

class _CornerBracketsPainter extends CustomPainter {
  final Color color;
  final double bracketLength;
  final double bracketWidth;

  _CornerBracketsPainter({
    required this.color,
    this.bracketLength = 14,
    this.bracketWidth = 2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = bracketWidth
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    final l = bracketLength;
    const m = 5.0; // margin from edge

    // Top-left
    final tl = Offset(m, m);
    canvas.drawLine(tl, Offset(tl.dx + l, tl.dy), paint);
    canvas.drawLine(tl, Offset(tl.dx, tl.dy + l), paint);

    // Top-right
    final tr = Offset(size.width - m, m);
    canvas.drawLine(tr, Offset(tr.dx - l, tr.dy), paint);
    canvas.drawLine(tr, Offset(tr.dx, tr.dy + l), paint);

    // Bottom-left
    final bl = Offset(m, size.height - m);
    canvas.drawLine(bl, Offset(bl.dx + l, bl.dy), paint);
    canvas.drawLine(bl, Offset(bl.dx, bl.dy - l), paint);

    // Bottom-right
    final br = Offset(size.width - m, size.height - m);
    canvas.drawLine(br, Offset(br.dx - l, br.dy), paint);
    canvas.drawLine(br, Offset(br.dx, br.dy - l), paint);
  }

  @override
  bool shouldRepaint(_CornerBracketsPainter old) =>
      old.color != color ||
      old.bracketLength != bracketLength ||
      old.bracketWidth != bracketWidth;
}

// ─────────────────────────────────────────────────────────────────────────────
// DISCARD CONFIRMATION BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _DiscardButton extends StatelessWidget {
  const _DiscardButton({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(4);
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        splashColor: color.withValues(alpha: .18),
        highlightColor: color.withValues(alpha: .08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: filled ? color.withValues(alpha: .9) : color.withValues(alpha: .08),
            border: Border.all(
              color: filled ? color.withValues(alpha: .3) : color.withValues(alpha: .35),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: filled ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
