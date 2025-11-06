import 'dart:async';
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/egg.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/egg_hatching_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/nursery/brewing_card_widget.dart';
import 'package:alchemons/widgets/nursery/egg_extraction_dialog.dart';
import 'package:alchemons/widgets/nursery/non_ready_hatch_widget.dart';
import 'package:alchemons/widgets/nursery/storage_section_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Lightweight periodic check to catch eggs becoming ready
    // Matches the pattern from HomeScreen._setupNotificationWatchers()
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
    final db = context.watch<AlchemonsDatabase>();
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;
    final theme = context.read<FactionTheme>();

    return StreamBuilder<DateTime>(
      stream: Stream<DateTime>.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now().toUtc(),
      ),
      initialData: DateTime.now().toUtc(),
      builder: (_, __) {
        // Nest the slots stream so we can both poll every second and read latest slots
        return StreamBuilder<List<IncubatorSlot>>(
          stream: db.incubatorDao.watchSlots(),
          builder: (context, snap) {
            // ⬇️ your existing build of slots/activeSlots/unlockedEmptySlots
            final slots = snap.data ?? const <IncubatorSlot>[];
            _preloadUndiscoveredStatus(slots);

            final activeSlots =
                (slots
                    .where(
                      (s) =>
                          s.unlocked &&
                          s.eggId != null &&
                          s.hatchAtUtcMs != null,
                    )
                    .toList()
                  ..sort((a, b) => a.id.compareTo(b.id)));

            final unlockedEmptySlots =
                (slots
                    .where(
                      (s) =>
                          s.unlocked &&
                          (s.eggId == null || s.hatchAtUtcMs == null),
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
                    primaryColor,
                  ),
                  const SizedBox(height: 12),
                  _buildActiveGridWithPlaceholders(
                    activeSlots: activeSlots,
                    placeholders: unlockedEmptySlots.length,
                    primaryColor: primaryColor,
                    theme: theme,
                  ),
                  const SizedBox(height: 24),
                  StorageSection(
                    primaryColor: primaryColor,
                    buildSectionHeader: _buildSectionHeader,
                  ),
                ],
              ),
            );
          },
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
          final factions = context.read<FactionService>();
          final showAirPredict = factions.current == FactionId.air;
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
              showAirPredict,
            ),
          );
        }

        return _PlaceholderTile(
          primaryColor: primaryColor,
          onTap: widget.onRequestAddEgg,
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
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
    bool showAirPredict,
  ) {
    if (ready) {
      _showExtractionDialog(slot, primaryColor, isUndiscovered, showAirPredict);
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (context) => _SlotInfoDialogWrapper(
          slot: slot,
          primaryColor: primaryColor,
          isUndiscovered: isUndiscovered,
          showAirPredict: showAirPredict,
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

  void _showExtractionDialog(
    IncubatorSlot slot,
    Color primaryColor,
    bool isUndiscovered,
    bool showAirPredict,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => ExtractionDialog(
        slot: slot,
        primaryColor: primaryColor,
        isUndiscovered: isUndiscovered,
        showAirPredict: showAirPredict,
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'DISCARD SPECIMEN?',
          style: TextStyle(
            color: Colors.red,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        content: Text(
          'This will permanently destroy the specimen. This action cannot be undone.',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AlchemonsDatabase>().incubatorDao.clearEgg(
                slot.id,
              );
              _showToast(
                'Specimen discarded',
                icon: Icons.delete_forever_rounded,
                color: Colors.red.shade600,
              );
            },
            child: const Text(
              'DISCARD',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900),
            ),
          ),
        ],
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

  Future<void> _moveToNest(Egg egg) async {
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();
    final free = await db.incubatorDao.firstFreeSlot();

    if (!mounted) return;

    if (free == null) {
      _showToast(
        'No available chambers',
        icon: Icons.warning_rounded,
        color: Colors.orange.shade600,
      );
      return;
    }

    final hatchAt = DateTime.now().toUtc().add(
      Duration(milliseconds: egg.remainingMs),
    );

    await db.incubatorDao.placeEgg(
      slotId: free.id,
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      rarity: egg.rarity,
      hatchAtUtc: hatchAt,
      payloadJson: egg.payloadJson,
    );

    await db.incubatorDao.removeFromInventory(egg.eggId);

    if (mounted) {
      _showToast(
        'Specimen transferred to chamber ${free.id + 1}',
        icon: Icons.science_rounded,
        color: Colors.green.shade600,
      );
    }
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
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(.4), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.05),
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withOpacity(.1)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.speed_rounded, color: primaryColor, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'ACCELERATE DEVELOPMENT',
                          style: TextStyle(
                            color: Color(0xFFE8EAED),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: Colors.white.withOpacity(.6),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Time Remaining: ${BreedConstants.formatRemaining(remaining)}',
                              style: const TextStyle(
                                color: Color(0xFFB6C0CC),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAccelerationOption(
                        'HALF ACCELERATION',
                        'Reduce time by 50%',
                        BreedConstants.formatRemaining(halfTime),
                        halfCost,
                        primaryColor,
                        () => _performAcceleration(
                          slotId,
                          halfTime,
                          halfCost,
                          'Half',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildAccelerationOption(
                        'INSTANT COMPLETION',
                        'Complete immediately',
                        'Ready now',
                        fullCost,
                        Colors.green,
                        () => _performAcceleration(
                          slotId,
                          remaining,
                          fullCost,
                          'Full',
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(.2),
                            ),
                          ),
                          child: const Text(
                            'CANCEL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFB6C0CC),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
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

  Widget _buildAccelerationOption(
    String title,
    String subtitle,
    String newTime,
    int cost,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor.withOpacity(.4), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB6C0CC),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFD700).withOpacity(.9),
                        const Color(0xFFFFD700).withOpacity(.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withOpacity(.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        cost.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: accentColor.withOpacity(.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: accentColor),
                  const SizedBox(width: 6),
                  Text(
                    'New time: $newTime',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  Future<void> _unlockSlot(int slotId) async {
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();
    await db.incubatorDao.unlockSlot(slotId);

    if (mounted) {
      _showToast(
        'Chamber ${slotId + 1} unlocked',
        icon: Icons.lock_open_rounded,
        color: Colors.green.shade600,
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
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
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
  final bool showAirPredict;
  final DateTime? maxSeenNowUtc;
  final VoidCallback onAccelerate;
  final VoidCallback onReturn;
  final VoidCallback onClose;
  final VoidCallback onInstantHatch;

  const _SlotInfoDialogWrapper({
    required this.slot,
    required this.primaryColor,
    required this.isUndiscovered,
    required this.showAirPredict,
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
          showAirPredict: widget.showAirPredict,
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

class _PlaceholderTile extends StatelessWidget {
  final Color primaryColor;
  final VoidCallback onTap;

  const _PlaceholderTile({required this.primaryColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: primaryColor.withOpacity(.35), width: 1.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: primaryColor, size: 28),
                  const SizedBox(height: 6),
                  Text(
                    'Place specimen',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
