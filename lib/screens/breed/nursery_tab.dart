import 'dart:convert';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/breeding_info.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/faction.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/providers/app_providers.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NurseryTab extends StatefulWidget {
  final DateTime? maxSeenNowUtc;
  final VoidCallback onHatchComplete;

  const NurseryTab({
    super.key,
    this.maxSeenNowUtc,
    required this.onHatchComplete,
  });

  @override
  State<NurseryTab> createState() => _NurseryTabState();
}

class _NurseryTabState extends State<NurseryTab> {
  // Cache undiscovered status to prevent flashing
  final Map<String, bool> _undiscoveredCache = {};

  @override
  Widget build(BuildContext context) {
    final db = context.watch<AlchemonsDatabase>();

    return StreamBuilder<List<IncubatorSlot>>(
      stream: db.watchSlots(),
      builder: (context, snap) {
        final slots = snap.data ?? const <IncubatorSlot>[];

        // Update cache for any new creature IDs
        _preloadUndiscoveredStatus(slots);

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final slot in slots) _buildIncubatorSlot(slot),
              const SizedBox(height: 12),
              _buildStorageSection(),
              const SizedBox(height: 8),
              _buildEggInventory(),
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
        // Set a temporary value to prevent multiple calls
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

  Widget _buildStorageSection() {
    return Row(
      children: [
        Icon(
          Icons.inventory_2_rounded,
          color: Colors.indigo.shade600,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          'Specimen Storage',
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildEggInventory() {
    return StreamBuilder<List<Egg>>(
      stream: context.read<AlchemonsDatabase>().watchInventory(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  'No specimens in storage',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: items.map((e) => _buildInventoryRow(e)).toList(),
        );
      },
    );
  }

  Widget _buildInventoryRow(Egg egg) {
    final remaining = Duration(milliseconds: egg.remainingMs);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: BreedConstants.getRarityColor(egg.rarity).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: BreedConstants.getRarityColor(
                  egg.rarity,
                ).withOpacity(0.3),
              ),
            ),
            child: Icon(
              Icons.science_rounded,
              size: 18,
              color: BreedConstants.getRarityColor(egg.rarity),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${egg.rarity} Specimen',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  'ID: ${egg.resultCreatureId}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
                Text(
                  'Development: ${BreedConstants.formatRemaining(remaining)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            children: [
              _buildInventoryButton(
                'Transfer',
                Icons.arrow_upward_rounded,
                Colors.green.shade600,
                () => _moveToNest(egg),
              ),
              const SizedBox(height: 3),
              _buildInventoryButton(
                'Discard',
                Icons.delete_outline_rounded,
                Colors.red.shade600,
                () => _discardEgg(egg),
              ),
            ],
          ),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 10),
            const SizedBox(width: 3),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncubatorSlot(IncubatorSlot slot) {
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked
              ? (hasEgg ? Colors.blue.shade300 : Colors.green.shade300)
              : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked
                ? (hasEgg ? Colors.blue.shade100 : Colors.green.shade100)
                : Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildSlotIcon(slot, hasEgg, isUnlocked, ready),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSlotTitle(isUnlocked, hasEgg, ready, slot.id),
                const SizedBox(height: 3),
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
                    _undiscoveredCache[slot.resultCreatureId!] == true) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights_rounded,
                          size: 14,
                          color: Colors.teal.shade700,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.teal.shade200),
                          ),
                          child: Text(
                            'UNDISCOVERED',
                            style: TextStyle(
                              color: Colors.teal.shade800,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasEgg && progress != null) ...[
                  const SizedBox(height: 6),
                  _buildProgressBar(progress, slot.rarity ?? 'common'),
                ],
                if (hasEgg) ...[
                  const SizedBox(height: 8),
                  _buildSlotActions(slot, ready),
                ],
              ],
            ),
          ),
          if (!hasEgg && !isUnlocked) _buildUnlockButton(slot.id),
        ],
      ),
    );
  }

  Widget _buildSlotIcon(
    IncubatorSlot slot,
    bool hasEgg,
    bool isUnlocked,
    bool ready,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: hasEgg
                ? (ready ? Colors.green.shade50 : Colors.blue.shade50)
                : isUnlocked
                ? Colors.grey.shade50
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasEgg
                  ? (ready ? Colors.green.shade400 : Colors.blue.shade400)
                  : isUnlocked
                  ? Colors.grey.shade300
                  : Colors.grey.shade400,
              width: 2,
            ),
          ),
          child: Icon(
            hasEgg
                ? (ready ? Icons.psychology_rounded : Icons.science_rounded)
                : isUnlocked
                ? Icons.add_circle_outline_rounded
                : Icons.lock_rounded,
            color: hasEgg
                ? (ready ? Colors.green.shade600 : Colors.blue.shade600)
                : isUnlocked
                ? Colors.grey.shade500
                : Colors.grey.shade600,
            size: 20,
          ),
        ),
        if (hasEgg && slot.rarity != null)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: BreedConstants.getRarityColor(slot.rarity!),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                slot.rarity!.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSlotTitle(bool isUnlocked, bool hasEgg, bool ready, int slotId) {
    return Text(
      !isUnlocked
          ? 'Chamber ${slotId + 1} - Locked'
          : hasEgg
          ? (ready ? 'Development Complete' : 'Incubating Specimen')
          : 'Chamber ${slotId + 1} - Available',
      style: TextStyle(
        color: isUnlocked
            ? (hasEgg ? Colors.blue.shade700 : Colors.green.shade700)
            : Colors.grey.shade600,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
        color: isUnlocked
            ? (hasEgg ? Colors.blue.shade600 : Colors.green.shade600)
            : Colors.grey.shade500,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildProgressBar(double progress, String rarity) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress.clamp(0, 1),
        minHeight: 6,
        backgroundColor: Colors.grey.shade200,
        valueColor: AlwaysStoppedAnimation<Color>(
          BreedConstants.getRarityColor(rarity),
        ),
      ),
    );
  }

  Widget _buildSlotActions(IncubatorSlot slot, bool ready) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _buildActionButton(
          ready ? 'Extract' : 'Processing',
          ready ? Icons.biotech_rounded : Icons.schedule_rounded,
          ready ? Colors.green.shade600 : Colors.blue.shade600,
          ready ? () => _hatchFromSlot(slot) : null,
        ),
        _buildActionButton(
          'Accelerate',
          Icons.speed_rounded,
          Colors.orange.shade600,
          () => _speedUpSlot(slot.id),
        ),
        _buildActionButton(
          'Cancel',
          Icons.cancel_outlined,
          Colors.grey.shade600,
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: onTap != null ? color : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnlockButton(int slotId) {
    return GestureDetector(
      onTap: () => _unlockSlot(slotId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade600,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open_rounded, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            const Text(
              'Unlock',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
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
      delta: const Duration(minutes: 10),
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
          breeding: BreedingInfo.empty(),
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

    // Clear from cache since it's now discovered
    if (slot.resultCreatureId != null) {
      _undiscoveredCache.remove(slot.resultCreatureId!);
    }

    widget.onHatchComplete();
    if (!mounted) return;

    await _showExtractionResult(instanceId, variant);
    await gameState.refresh();
  }

  Future<void> _showExtractionResult(
    String instanceId,
    Creature? variant,
  ) async {
    if (!mounted) return;

    final offspring = await _effectiveFromInstance(instanceId);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade300, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.shade200,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.indigo.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.science_rounded,
                                color: Colors.indigo.shade600,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                variant != null
                                    ? 'Variant Specimen Extracted'
                                    : 'Extraction Complete',
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            offspring.name,
                            style: TextStyle(
                              color: Colors.indigo.shade600,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.grey.shade600,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        height: 250,
                        width: 250,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.indigo.shade100,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CreatureSprite(
                          spritePath:
                              offspring.spriteData?.spriteSheetPath ?? '',
                          totalFrames: offspring.spriteData?.totalFrames ?? 1,
                          rows: offspring.spriteData?.rows ?? 1,
                          frameSize: Vector2(
                            offspring.spriteData!.frameWidth.toDouble(),
                            offspring.spriteData!.frameHeight.toDouble(),
                          ),
                          isPrismatic: offspring.isPrismaticSkin,
                          stepTime:
                              offspring.spriteData!.frameDurationMs / 1000.0,
                          scale: scaleFromGenes(offspring.genetics),
                          saturation: satFromGenes(offspring.genetics),
                          brightness: briFromGenes(offspring.genetics),
                          hueShift: hueFromGenes(offspring.genetics),
                        ),
                      ),
                      if (variant != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.orange.shade700,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Genetic Variant Detected',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        CreatureSprite(
                          spritePath:
                              offspring.spriteData?.spriteSheetPath ?? '',
                          totalFrames: offspring.spriteData?.totalFrames ?? 1,
                          rows: offspring.spriteData?.rows ?? 1,
                          frameSize: Vector2(
                            offspring.spriteData!.frameWidth.toDouble(),
                            offspring.spriteData!.frameHeight.toDouble(),
                          ),
                          isPrismatic: offspring.isPrismaticSkin,
                          stepTime:
                              offspring.spriteData!.frameDurationMs / 1000.0,
                          scale: scaleFromGenes(offspring.genetics),
                          saturation: satFromGenes(offspring.genetics),
                          brightness: briFromGenes(offspring.genetics),
                          hueShift: hueFromGenes(offspring.genetics),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _buildAnalysisSection('Specimen Analysis', [
                        _buildAnalysisRow('Classification', offspring.rarity),
                        _buildAnalysisRow(
                          'Type Categories',
                          offspring.types.join(', '),
                        ),
                        if (offspring.description.isNotEmpty)
                          _buildAnalysisRow('Notes', offspring.description),
                      ]),
                      const SizedBox(height: 12),
                      _buildAnalysisSection('Genetic Profile', [
                        _buildAnalysisRow(
                          'Size Variant',
                          _getSizeName(offspring),
                        ),
                        _buildAnalysisRow(
                          'Pigmentation',
                          _getTintName(offspring),
                        ),
                        if (offspring.nature != null)
                          _buildAnalysisRow(
                            'Behavioral Pattern',
                            offspring.nature!.id,
                          ),
                        if (offspring.isPrismaticSkin == true)
                          _buildAnalysisRow(
                            'Special Trait',
                            'Prismatic Phenotype',
                          ),
                      ]),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade600,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigo.shade200,
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Extraction Confirmed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatureDisplayCard(Creature creature, bool isVariant) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isVariant ? Colors.orange.shade300 : Colors.indigo.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isVariant ? Colors.orange.shade100 : Colors.indigo.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: BreedConstants.getTypeColor(
                        creature.types.first,
                      ).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/creatures/${creature.rarity.toLowerCase()}/${creature.id.toUpperCase()}_${creature.name.toLowerCase()}.gif',
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        decoration: BoxDecoration(
                          color: BreedConstants.getTypeColor(
                            creature.types.first,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          BreedConstants.getTypeIcon(creature.types.first),
                          size: 40,
                          color: BreedConstants.getTypeColor(
                            creature.types.first,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              if (isVariant)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Text(
                      'VAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              if (creature.isPrismaticSkin == true)
                Positioned(
                  top: -4,
                  left: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade600,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: const Text(
                      'PRIS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: BreedConstants.getRarityColor(creature.rarity),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      creature.rarity.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            creature.name,
            style: TextStyle(
              color: Colors.indigo.shade700,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: creature.types
                .map(
                  (type) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: BreedConstants.getTypeColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: BreedConstants.getTypeColor(
                          type,
                        ).withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: BreedConstants.getTypeColor(type),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.indigo.shade700,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(children: children),
        ),
      ],
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
