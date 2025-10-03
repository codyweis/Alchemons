import 'dart:convert';
import 'dart:ui';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/constants/egg.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/screens/breed/utils/breed_utils.dart';
import 'package:alchemons/screens/creatures_screen.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/animations/breed_result_animation.dart';
import 'package:alchemons/widgets/animations/database_typing_animation.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/delay_type_widget.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NurseryTab extends StatefulWidget {
  final DateTime? maxSeenNowUtc;
  final VoidCallback onHatchComplete;
  final TabController tabController;

  const NurseryTab({
    super.key,
    this.maxSeenNowUtc,
    required this.onHatchComplete,
    required this.tabController,
  });

  @override
  State<NurseryTab> createState() => _NurseryTabState();
}

class _NurseryTabState extends State<NurseryTab> {
  final Map<String, bool> _undiscoveredCache = {};
  bool _scanComplete = false;

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AlchemonsDatabase>();
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

    return StreamBuilder<List<IncubatorSlot>>(
      stream: db.watchSlots(),
      builder: (context, snap) {
        final slots = snap.data ?? const <IncubatorSlot>[];
        _preloadUndiscoveredStatus(slots);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slot in slots) _buildIncubatorSlot(slot, primaryColor),
              const SizedBox(height: 16),
              _buildStorageSection(primaryColor),
              const SizedBox(height: 12),
              _buildEggInventory(primaryColor),
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
        _isUndiscovered(slot.resultCreatureId!).then((result) {
          if (mounted) {
            setState(() {
              _undiscoveredCache[slot.resultCreatureId!] = result;
            });
          }
        });
      }
    }
  }

  Widget _buildStorageSection(Color primaryColor) {
    return Row(
      children: [
        Icon(Icons.inventory_2_rounded, color: primaryColor, size: 18),
        const SizedBox(width: 10),
        Text(
          'SPECIMEN STORAGE',
          style: TextStyle(
            color: primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildEggInventory(Color primaryColor) {
    return StreamBuilder<List<Egg>>(
      stream: context.read<AlchemonsDatabase>().watchInventory(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
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
                      Icons.science_outlined,
                      color: Colors.white.withOpacity(.4),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'No specimens in storage',
                      style: TextStyle(
                        color: Color(0xFFB6C0CC),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Column(
          children: items
              .map((e) => _buildInventoryRow(e, primaryColor))
              .toList(),
        );
      },
    );
  }

  Widget _buildInventoryRow(Egg egg, Color primaryColor) {
    final remaining = Duration(milliseconds: egg.remainingMs);
    final rarityColor = BreedConstants.getRarityColor(egg.rarity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rarityColor.withOpacity(.4)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        rarityColor.withOpacity(.25),
                        rarityColor.withOpacity(.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: rarityColor.withOpacity(.4)),
                  ),
                  child: Icon(
                    Icons.science_rounded,
                    size: 20,
                    color: rarityColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${egg.rarity.toUpperCase()} SPECIMEN',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFE8EAED),
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${egg.resultCreatureId}',
                        style: const TextStyle(
                          color: Color(0xFFB6C0CC),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Development: ${BreedConstants.formatRemaining(remaining)}',
                        style: const TextStyle(
                          color: Color(0xFFB6C0CC),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    _buildInventoryButton(
                      'Transfer',
                      Icons.arrow_upward_rounded,
                      Colors.green,
                      () => _moveToNest(egg),
                    ),
                    const SizedBox(height: 6),
                    _buildInventoryButton(
                      'Discard',
                      Icons.delete_outline_rounded,
                      Colors.red,
                      () => _discardEgg(egg),
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

  Widget _buildInventoryButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              text.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncubatorSlot(IncubatorSlot slot, Color primaryColor) {
    final isUnlocked = slot.unlocked;
    final hasEgg = slot.eggId != null && slot.hatchAtUtcMs != null;
    final rarity = slot.rarity?.toLowerCase();
    final hatchDelay = rarity != null
        ? BreedConstants.rarityHatchTimes[rarity]
        : null;

    final Duration? remaining = hasEgg
        ? _remainingFor(slot.hatchAtUtcMs!)
        : null;
    final bool ready = remaining != null && remaining.inSeconds <= 0;
    final String? remainingText = remaining != null
        ? BreedConstants.formatRemaining(remaining)
        : null;

    double? progress;
    if (hasEgg &&
        remaining != null &&
        hatchDelay != null &&
        hatchDelay.inMilliseconds > 0) {
      final left = remaining.isNegative ? Duration.zero : remaining;
      final done = (hatchDelay.inMilliseconds - left.inMilliseconds).clamp(
        0,
        hatchDelay.inMilliseconds,
      );
      progress = done / hatchDelay.inMilliseconds;
    }

    final factions = context.read<FactionService>();
    final showAirPredict = factions.current == FactionId.air;

    final statusColor = ready
        ? Colors.green
        : hasEgg
        ? primaryColor
        : isUnlocked
        ? Colors.white.withOpacity(.3)
        : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.2),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withOpacity(.4), width: 2),
              boxShadow: hasEgg
                  ? [
                      BoxShadow(
                        color: statusColor.withOpacity(.2),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                _buildSlotIcon(slot, hasEgg, isUnlocked, ready, primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSlotTitle(
                        isUnlocked,
                        hasEgg,
                        ready,
                        slot.id,
                        primaryColor,
                      ),
                      const SizedBox(height: 4),
                      _buildSlotSubtitle(
                        isUnlocked,
                        hasEgg,
                        ready,
                        remainingText,
                        slot,
                      ),
                      if (hasEgg &&
                          showAirPredict &&
                          slot.resultCreatureId != null &&
                          _undiscoveredCache[slot.resultCreatureId!] ==
                              true) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                size: 14,
                                color: Colors.teal.shade300,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withOpacity(.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.teal.withOpacity(.4),
                                  ),
                                ),
                                child: Text(
                                  'UNDISCOVERED',
                                  style: TextStyle(
                                    color: Colors.teal.shade300,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (hasEgg && progress != null) ...[
                        const SizedBox(height: 10),
                        _buildProgressBar(progress, slot.rarity ?? 'common'),
                      ],
                      if (hasEgg) ...[
                        const SizedBox(height: 12),
                        _buildSlotActions(slot, ready, primaryColor),
                      ],
                    ],
                  ),
                ),
                if (!hasEgg && !isUnlocked)
                  _buildUnlockButton(slot.id, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotIcon(
    IncubatorSlot slot,
    bool hasEgg,
    bool isUnlocked,
    bool ready,
    Color primaryColor,
  ) {
    final statusColor = ready
        ? Colors.green
        : hasEgg
        ? primaryColor
        : Colors.white.withOpacity(.2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            if (!hasEgg) {
              widget.tabController.animateTo(0);
            }
          },
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: hasEgg || !isUnlocked
                  ? LinearGradient(
                      colors: [
                        statusColor.withOpacity(.2),
                        statusColor.withOpacity(.1),
                      ],
                    )
                  : null,
              color: hasEgg || !isUnlocked
                  ? null
                  : Colors.white.withOpacity(.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withOpacity(.5), width: 2),
            ),
            child: Icon(
              hasEgg
                  ? (ready ? Icons.psychology_rounded : Icons.science_rounded)
                  : isUnlocked
                  ? Icons.add_circle_outline_rounded
                  : Icons.lock_rounded,
              color: statusColor.withOpacity(.9),
              size: 24,
            ),
          ),
        ),
        if (hasEgg && slot.rarity != null)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: BreedConstants.getRarityColor(slot.rarity!),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                slot.rarity!.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSlotTitle(
    bool isUnlocked,
    bool hasEgg,
    bool ready,
    int slotId,
    Color primaryColor,
  ) {
    return Text(
      !isUnlocked
          ? 'CHAMBER ${slotId + 1} - LOCKED'
          : hasEgg
          ? (ready ? 'DEVELOPMENT COMPLETE' : 'INCUBATING SPECIMEN')
          : 'CHAMBER ${slotId + 1} - AVAILABLE',
      style: TextStyle(
        color: ready
            ? Colors.green.shade300
            : hasEgg
            ? primaryColor
            : isUnlocked
            ? const Color(0xFFE8EAED)
            : const Color(0xFFB6C0CC),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildSlotSubtitle(
    bool isUnlocked,
    bool hasEgg,
    bool ready,
    String? remainingText,
    IncubatorSlot slot,
  ) {
    return Text(
      !isUnlocked
          ? 'Requires level ${10 + slot.id * 5}'
          : hasEgg
          ? (ready ? 'Ready for extraction' : 'Time remaining: $remainingText')
          : 'Ready for specimen insertion',
      style: TextStyle(
        color: const Color(0xFFB6C0CC).withOpacity(.8),
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildProgressBar(double progress, String rarity) {
    final rarityColor = BreedConstants.getRarityColor(rarity);
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withOpacity(.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(
          value: progress.clamp(0, 1),
          minHeight: 8,
          backgroundColor: Colors.white.withOpacity(.08),
          valueColor: AlwaysStoppedAnimation<Color>(rarityColor),
        ),
      ),
    );
  }

  Widget _buildSlotActions(IncubatorSlot slot, bool ready, Color primaryColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionButton(
          ready ? 'Extract' : 'Processing',
          ready ? Icons.biotech_rounded : Icons.schedule_rounded,
          ready ? Colors.green : primaryColor,
          ready ? () => _hatchFromSlot(slot) : null,
        ),
        _buildActionButton(
          'Accelerate',
          Icons.speed_rounded,
          Colors.orange,
          () => _speedUpSlot(slot.id),
        ),
        _buildActionButton(
          'Cancel',
          Icons.cancel_outlined,
          Colors.grey,
          () => _cancelToInventory(slot),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: onTap != null
              ? color.withOpacity(.9)
              : Colors.white.withOpacity(.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null
                ? color.withOpacity(.3)
                : Colors.white.withOpacity(.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(onTap != null ? 1 : 0.5),
              size: 14,
            ),
            const SizedBox(width: 6),
            Text(
              text.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withOpacity(onTap != null ? 1 : 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockButton(int slotId, Color primaryColor) {
    return GestureDetector(
      onTap: () => _unlockSlot(slotId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(.9),
              primaryColor.withOpacity(.7),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor.withOpacity(.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_open_rounded, color: Colors.white, size: 16),
            SizedBox(width: 6),
            Text(
              'UNLOCK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keep all your existing methods (_safeNowUtc, _remainingFor, _moveToNest, etc.)
  // I'll just show the signatures since they remain functionally the same

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
    final free = await db.firstFreeSlot();

    if (!mounted) return;

    if (free == null) {
      _showToast(
        'No available incubation chambers',
        icon: Icons.warning_rounded,
        color: Colors.orange.shade600,
      );
      return;
    }

    final hatchAt = DateTime.now().toUtc().add(
      Duration(milliseconds: egg.remainingMs),
    );

    await db.placeEgg(
      slotId: free.id,
      eggId: egg.eggId,
      resultCreatureId: egg.resultCreatureId,
      bonusVariantId: egg.bonusVariantId,
      rarity: egg.rarity,
      hatchAtUtc: hatchAt,
      payloadJson: egg.payloadJson,
    );

    await db.removeFromInventory(egg.eggId);

    if (mounted) {
      _showToast(
        'Specimen transferred to chamber ${free.id + 1}',
        icon: Icons.science_rounded,
        color: Colors.green.shade600,
      );
    }
  }

  Future<void> _discardEgg(Egg egg) async {
    if (!mounted) return;

    final confirmed = await _showConfirmDialog(
      'Discard Specimen',
      'Permanently discard this ${egg.rarity} specimen? This action cannot be undone.',
    );

    if (!mounted || !confirmed) return;

    await context.read<AlchemonsDatabase>().removeFromInventory(egg.eggId);

    if (mounted) {
      _showToast(
        'Specimen discarded',
        icon: Icons.delete_rounded,
        color: Colors.red.shade600,
      );
    }
  }

  Future<void> _speedUpSlot(int slotId) async {
    if (!mounted) return;

    final db = context.read<AlchemonsDatabase>();

    final safeNow = _safeNowUtc();
    await db.speedUpSlot(
      slotId: slotId,
      delta: const Duration(minutes: 100),
      safeNowUtc: safeNow,
    );

    if (mounted) {
      _showToast(
        'Development accelerated by 10 minutes',
        icon: Icons.speed_rounded,
        color: Colors.orange.shade600,
      );
    }
  }

  Future<void> _cancelToInventory(IncubatorSlot slot) async {
    if (!mounted) return;

    if (slot.eggId == null || slot.hatchAtUtcMs == null) return;

    final confirmed = await _showConfirmDialog(
      'Cancel Incubation',
      'Transfer this specimen back to storage? Development will continue there.',
    );

    if (!mounted || !confirmed) return;

    final db = context.read<AlchemonsDatabase>();
    final remaining = _remainingFor(slot.hatchAtUtcMs!);

    await db.enqueueEgg(
      eggId: slot.eggId!,
      resultCreatureId: slot.resultCreatureId!,
      bonusVariantId: slot.bonusVariantId,
      rarity: slot.rarity ?? 'common',
      remaining: remaining.isNegative ? Duration.zero : remaining,
      payloadJson: slot.payloadJson,
    );

    await db.clearEgg(slot.id);

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
    await db.unlockSlot(slotId);

    if (mounted) {
      _showToast(
        'Incubation chamber ${slotId + 1} unlocked',
        icon: Icons.lock_open_rounded,
        color: Colors.green.shade600,
      );
    }
  }

  Future<bool> _isUndiscovered(String creatureId) async {
    final db = context.read<AlchemonsDatabase>();
    final row = await db.getCreature(creatureId); // PlayerCreatures row
    // null or discovered==false => undiscovered
    return row == null || row.discovered == false;
  }

  Future<Creature> _effectiveFromInstance(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureRepository>();

    final row = await db.getInstance(instanceId);
    if (row == null) throw Exception('Instance not found');

    final base =
        repo.getCreatureById(row.baseId) ??
        Creature(
          id: row.baseId,
          name: row.baseId,
          types: const ['Spirit'],
          rarity: 'Common',
          description: '',
          image: '',
        );

    var out = base;

    if (row.isPrismaticSkin == true) {
      out = out.copyWith(isPrismaticSkin: true);
    }
    if (row.natureId != null && row.natureId!.isNotEmpty) {
      final n = NatureCatalog.byId(row.natureId!);
      if (n != null) out = out.copyWith(nature: n);
    }
    if ((row.geneticsJson ?? '').isNotEmpty) {
      try {
        final gMap = Map<String, dynamic>.from(jsonDecode(row.geneticsJson!));
        out = out.copyWith(
          genetics: Genetics(gMap.map((k, v) => MapEntry(k, v.toString()))),
        );
      } catch (_) {}
    }
    if ((row.parentageJson ?? '').isNotEmpty) {
      try {
        out = out.copyWith(
          parentage: Parentage.fromJson(
            jsonDecode(row.parentageJson!) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    return out;
  }

  Future<void> _hatchFromSlot(IncubatorSlot slot) async {
    if (!mounted) return;

    final repo = context.read<CreatureRepository>();
    final gameData = context.read<GameDataService>();
    final gameState = context.read<GameStateNotifier>();
    final db = context.read<AlchemonsDatabase>();

    if (slot.resultCreatureId == null) return;

    final offspring = repo.getCreatureById(slot.resultCreatureId!);
    if (offspring == null) {
      if (mounted) _showToast('Could not load specimen data');
      return;
    }

    // CHECK DISCOVERY STATUS BEFORE MARKING AS DISCOVERED
    final isNewDiscovery = await _isUndiscovered(offspring.id);
    final isVariantNewDiscovery = slot.bonusVariantId != null
        ? await _isUndiscovered(slot.bonusVariantId!)
        : false;

    // NOW mark as discovered
    await gameData.markDiscovered(offspring.id);

    Creature? variant;
    if (slot.bonusVariantId != null) {
      await gameData.markDiscovered(slot.bonusVariantId!);
      await repo.refreshVariants();
      variant = repo.getCreatureById(slot.bonusVariantId!);
    }

    Map<String, dynamic>? payload;
    if ((slot.payloadJson ?? '').isNotEmpty) {
      try {
        final decoded = jsonDecode(slot.payloadJson!) as Map<String, dynamic>;
        payload = decoded;
      } catch (e) {
        print('Error decoding payload: $e');
      }
    }
    payload ??= {'baseId': offspring.id, 'rarity': offspring.rarity};

    Map<String, String>? genetics;
    if (payload['genetics'] != null) {
      final geneticsData = payload['genetics'];
      if (geneticsData is Map) {
        genetics = Map<String, String>.from(geneticsData);
      }
    }

    final svc = CreatureInstanceService(db);
    final result = await svc.finalizeInstance(
      baseId: payload['baseId'] as String,
      rarity: (payload['rarity'] as String?) ?? offspring.rarity,
      natureId: payload['natureId'] as String?,
      genetics: genetics,
      parentage: payload['parentage'] as Map<String, dynamic>?,
      isPrismaticSkin: payload['isPrismaticSkin'] as bool? ?? false,
      likelihoodAnalysisJson: payload['likelihoodAnalysis'] as String?,
    );

    if (!mounted) return;

    if (result.status == InstanceFinalizeStatus.speciesFull) {
      _showToast(
        'Specimen containment full. Clear space to complete extraction.',
        icon: Icons.warning_amber_rounded,
        color: Colors.orange.shade600,
      );
      return;
    }

    final instanceId = result.instanceId;
    if (instanceId == null || instanceId.isEmpty) {
      _showToast('Extraction failed: system error', color: Colors.red.shade600);
      return;
    }

    await db.clearEgg(slot.id);

    final elementName = offspring.types.first;
    final palette = paletteForElement(elementName);

    // Clear from cache since it's now discovered
    if (slot.resultCreatureId != null) {
      _undiscoveredCache.remove(slot.resultCreatureId!);
    }

    final factionSvc = context.read<FactionService>();
    final faction = await factionSvc.current;

    if (!mounted) return;
    await playHatchCinematic(
      context,
      'assets/animations/egg_hatch.json',
      palette,
      faction,
    );

    widget.onHatchComplete();

    await _showExtractionResult(
      instanceId,
      variant,
      isNewDiscovery,
      isVariantNewDiscovery,
    );
    await gameState.refresh();
  }

  // Updated _showExtractionResult method
  Future<void> _showExtractionResult(
    String instanceId,
    Creature? variant,
    bool isNewDiscovery,
    bool isVariantNewDiscovery,
  ) async {
    if (!mounted) return;

    final offspring = await _effectiveFromInstance(instanceId);
    if (!mounted) return;

    // faction accent (matches list tiles/buttons above)
    final factionSvc = context.read<FactionService>();
    final currentFaction = factionSvc.current;
    final factionColors = getFactionColors(currentFaction);
    final primaryColor = factionColors.$1;

    // Reset scan completion state
    _scanComplete = false;

    bool ctaVisible = false;
    bool ctaTouchable = false;
    bool closing = false;
    bool allTypingComplete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.82,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(.45),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(.18),
                        blurRadius: 20,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildExtractionHeaderDark(
                        offspring,
                        variant,
                        primaryColor,
                      ),

                      // Sprite dock
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.03),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.white.withOpacity(.08),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Main creature
                            Container(
                              height: 200,
                              width: 200,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(.02),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withOpacity(.12),
                                ),
                              ),
                              child: CreatureScanAnimation(
                                isNewDiscovery: isNewDiscovery,
                                scanDuration: const Duration(
                                  milliseconds: 3000,
                                ),
                                onReadyChanged: (ready) {
                                  if (ready) {
                                    setDialogState(() => _scanComplete = true);
                                  }
                                },
                                child: CreatureSprite(
                                  spritePath:
                                      offspring.spriteData?.spriteSheetPath ??
                                      '',
                                  totalFrames:
                                      offspring.spriteData?.totalFrames ?? 1,
                                  rows: offspring.spriteData?.rows ?? 1,
                                  frameSize: Vector2(
                                    offspring.spriteData!.frameWidth.toDouble(),
                                    offspring.spriteData!.frameHeight
                                        .toDouble(),
                                  ),
                                  isPrismatic: offspring.isPrismaticSkin,
                                  stepTime:
                                      offspring.spriteData!.frameDurationMs /
                                      1000.0,
                                  scale: scaleFromGenes(offspring.genetics),
                                  saturation: satFromGenes(offspring.genetics),
                                  brightness: briFromGenes(offspring.genetics),
                                  hueShift: hueFromGenes(offspring.genetics),
                                ),
                              ),
                            ),

                            const SizedBox(width: 14),

                            // Variant (optional)
                            if (variant != null)
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.orange.withOpacity(.35),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 12,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        const Text(
                                          'VARIANT',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: .5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 120,
                                    width: 120,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.02),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.12),
                                      ),
                                    ),
                                    child: CreatureScanAnimation(
                                      isNewDiscovery: isVariantNewDiscovery,
                                      scanDuration: const Duration(
                                        milliseconds: 2000,
                                      ),
                                      onReadyChanged: (ready) {
                                        if (ready) {
                                          setDialogState(
                                            () => _scanComplete = true,
                                          );
                                        }
                                      },
                                      child: CreatureSprite(
                                        spritePath:
                                            variant
                                                .spriteData
                                                ?.spriteSheetPath ??
                                            '',
                                        totalFrames:
                                            variant.spriteData?.totalFrames ??
                                            1,
                                        rows: variant.spriteData?.rows ?? 1,
                                        frameSize: Vector2(
                                          variant.spriteData!.frameWidth
                                              .toDouble(),
                                          variant.spriteData!.frameHeight
                                              .toDouble(),
                                        ),
                                        isPrismatic: variant.isPrismaticSkin,
                                        stepTime:
                                            variant
                                                .spriteData!
                                                .frameDurationMs /
                                            1000.0,
                                        scale: scaleFromGenes(variant.genetics),
                                        saturation: satFromGenes(
                                          variant.genetics,
                                        ),
                                        brightness: briFromGenes(
                                          variant.genetics,
                                        ),
                                        hueShift: hueFromGenes(
                                          variant.genetics,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      Expanded(
                        child: TickerMode(
                          enabled: !closing,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              children: [
                                DatabaseTypingAnimation(
                                  startAnimation: _scanComplete,
                                  delayBetweenItems: const Duration(
                                    milliseconds: 800,
                                  ),
                                  onComplete: () {
                                    setDialogState(() {
                                      allTypingComplete = true;
                                      ctaVisible = true;
                                      ctaTouchable = false;
                                    });
                                  },
                                  children: [
                                    _buildAnalysisSectionDark(
                                      'SPECIMEN ANALYSIS',
                                      primaryColor,
                                      [
                                        _buildTypingAnalysisRowDark(
                                          'CLASSIFICATION',
                                          offspring.rarity,
                                          _scanComplete,
                                          primaryColor,
                                        ),
                                        _buildTypingAnalysisRowDark(
                                          'TYPE CATEGORIES',
                                          offspring.types.join(', '),
                                          _scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
                                        ),
                                        if (offspring.description.isNotEmpty)
                                          _buildTypingAnalysisRowDark(
                                            'NOTES',
                                            offspring.description,
                                            _scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 600,
                                            ),
                                          ),
                                      ],
                                    ),
                                    _buildAnalysisSectionDark(
                                      'GENETIC PROFILE',
                                      primaryColor,
                                      [
                                        _buildTypingAnalysisRowDark(
                                          'SIZE VARIANT',
                                          _getSizeName(offspring),
                                          _scanComplete,
                                          primaryColor,
                                        ),
                                        _buildTypingAnalysisRowDark(
                                          'PIGMENTATION',
                                          _getTintName(offspring),
                                          _scanComplete,
                                          primaryColor,
                                          delay: const Duration(
                                            milliseconds: 300,
                                          ),
                                        ),
                                        if (offspring.nature != null)
                                          _buildTypingAnalysisRowDark(
                                            'BEHAVIOR',
                                            offspring.nature!.id,
                                            _scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 600,
                                            ),
                                          ),
                                        if (offspring.isPrismaticSkin == true)
                                          _buildTypingAnalysisRowDark(
                                            'SPECIAL TRAIT',
                                            'PRISMATIC PHENOTYPE',
                                            _scanComplete,
                                            primaryColor,
                                            delay: const Duration(
                                              milliseconds: 900,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Docked CTA
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.2),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(.08),
                            ),
                          ),
                        ),
                        child: AnimatedOpacity(
                          opacity: ctaVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 450),
                          onEnd: () {
                            if (ctaVisible && !closing) {
                              setDialogState(() => ctaTouchable = true);
                            }
                          },
                          child: IgnorePointer(
                            ignoring: !ctaTouchable || closing,
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (closing) return;
                                      setDialogState(() {
                                        closing = true;
                                        ctaTouchable = false;
                                      });
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (Navigator.of(
                                              context,
                                            ).canPop()) {
                                              Navigator.of(context).pop();
                                            }
                                          });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 22,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            primaryColor.withOpacity(.95),
                                            primaryColor.withOpacity(.8),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.white.withOpacity(.18),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withOpacity(
                                              .25,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'EXTRACTION CONFIRMED',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              letterSpacing: .6,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: () {
                                    if (closing) return;
                                    // Navigate to creature screen
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CreaturesScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(.25),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.pets_rounded,
                                      color: Colors.white.withOpacity(.9),
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExtractionHeaderDark(
    Creature offspring,
    Creature? variant,
    Color primaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.03),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(.08)),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.science_rounded, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              Text(
                variant != null
                    ? 'VARIANT SPECIMEN EXTRACTED'
                    : 'EXTRACTION COMPLETE',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: .6,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            offspring.name,
            style: const TextStyle(
              color: Color(0xFFE8EAED),
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: .3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSectionDark(
    String title,
    Color primaryColor,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.dataset_outlined, color: primaryColor, size: 16),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFE8EAED),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(.12)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTypingAnalysisRowDark(
    String label,
    String value,
    bool startTyping,
    Color primaryColor, {
    Duration delay = Duration.zero,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(.6),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: .4,
              ),
            ),
          ),
          Expanded(
            child: startTyping
                ? DelayedTypingText(
                    text: value,
                    delay: delay,
                    style: const TextStyle(
                      color: Color(0xFFE8EAED),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.indigo.shade700,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSizeName(Creature c) =>
      sizeLabels[c.genetics?.get('size') ?? 'normal'] ?? 'Standard';

  String _getTintName(Creature c) =>
      tintLabels[c.genetics?.get('tinting') ?? 'normal'] ?? 'Standard';

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
