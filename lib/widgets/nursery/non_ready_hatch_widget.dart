import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/nursery/cultivation_stage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class SlotInfoDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;

  /// Kept for the first frame; every rebuild reads hatchAtUtcMs instead.
  final Duration remaining;

  final bool isUndiscovered;
  final VoidCallback onAccelerate;
  final VoidCallback onReturn;
  final VoidCallback onClose;
  final VoidCallback onInstantHatch;

  const SlotInfoDialog({
    super.key,
    required this.slot,
    required this.primaryColor,
    required this.remaining,
    required this.isUndiscovered,
    required this.onAccelerate,
    required this.onReturn,
    required this.onClose,
    required this.onInstantHatch,
  });

  @override
  State<SlotInfoDialog> createState() => SlotInfoDialogState();
}

class SlotInfoDialogState extends State<SlotInfoDialog>
    with TickerProviderStateMixin {
  late AnimationController _introCtrl;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  // Cache to detect when to resync the progress controller

  // Keep a copy of latest slot from DB
  IncubatorSlot? _slot;

  bool _autoClosed = false;

  @override
  void initState() {
    super.initState();

    // Intro animations
    _introCtrl = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 28,
      end: 0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _introCtrl, curve: Curves.easeOut);
    _introCtrl.forward();
  }

  void _closeIfReady() {
    if (_autoClosed || !mounted) return;
    _autoClosed = true;

    // Let the UI paint 100% before closing (optional, feels smoother)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Prefer the provided callback so parent logic runs.
      widget.onClose();
      // If you want to hard-close the dialog instead, use:
      // if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  /// 0..1 against the rarity's expected duration — the same measure the
  /// chamber card is handed, so the two brews churn alike.
  double? _brewProgress(IncubatorSlot slot) {
    final delay = BreedConstants
        .rarityHatchTimes[(slot.rarity ?? 'common').toLowerCase()];
    if (delay == null || delay.inMilliseconds <= 0) return null;
    final left = _remainingFor(
      slot,
    ).inMilliseconds.clamp(0, delay.inMilliseconds);
    return (delay.inMilliseconds - left) / delay.inMilliseconds;
  }

  /// Instant fuse, when the player has one and there is still a wait to skip.
  Widget? _instantFuse(ForgeTokens t) {
    final slot = _slot;
    if (slot == null || _remainingFor(slot) <= Duration.zero) return null;
    return FutureBuilder<int>(
      future: context.read<AlchemonsDatabase>().inventoryDao.getItemQty(
        InvKeys.instantHatch,
      ),
      builder: (context, snap) {
        final qty = snap.data ?? 0;
        if (qty <= 0) return const SizedBox.shrink();
        return VialActionButton(
          label: 'INSTANT FUSE x$qty',
          onTap: widget.onInstantHatch,
        );
      },
    );
  }

  Duration _remainingFor(IncubatorSlot slot) {
    final ms = slot.hatchAtUtcMs;
    if (ms == null) return Duration.zero;
    final hatchAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final now = DateTime.now().toUtc();
    final diff = hatchAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  List<String>? _extractParentTypes(IncubatorSlot slot) {
    try {
      final payloadStr = slot.payloadJson;
      if (payloadStr == null || payloadStr.isEmpty) return null;
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final types = extractParticleTypeIdsFromPayload(payload);
      return types.isEmpty ? null : types;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();
    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);

    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnimation,
        child: Transform.translate(
          offset: Offset(0, _scaleAnimation.value),
          child: child,
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: StreamBuilder<List<IncubatorSlot>>(
              stream: db.incubatorDao.watchSlots(),
              builder: (context, snapshot) {
                _slot =
                    snapshot.data?.firstWhere(
                      (s) => s.id == widget.slot.id,
                      orElse: () => _slot ?? widget.slot,
                    ) ??
                    _slot ??
                    widget.slot;

                final slot = _slot!;
                // No resync to do any more: the countdown reads hatchAtUtcMs
                // directly, so an acceleration shows up on the next rebuild
                // without an animation to nudge back into step.

                // Matches the ready dialog: the stage is dark in both
                // themes, so the tints do not branch on it.
                final parentTypes = _extractParentTypes(slot);
                final payload =
                    slot.payloadJson == null || slot.payloadJson!.isEmpty
                    ? const <String, dynamic>{}
                    : jsonDecode(slot.payloadJson!) as Map<String, dynamic>;
                final isBloodborn = isBloodbornPayload(payload);
                final rarity = (slot.rarity ?? 'common').toLowerCase();
                final rarityColor = isBloodborn
                    ? kBloodbornSecondary
                    : BreedConstants.getRarityColor(rarity);
                final isReady = _remainingFor(slot) <= Duration.zero;
                if (isReady) _closeIfReady();

                return CultivationVialStage(
                  theme: theme,
                  parentTypes: parentTypes,
                  accentColor: rarityColor,
                  chamberLabel: 'CHAMBER ${slot.id + 1}',
                  particleCount: 62,
                  speedMultiplier: brewingSpeedForProgress(
                    progress: _brewProgress(slot),
                    remaining: _remainingFor(slot),
                    isReady: isReady,
                  ),
                  action: VialActionButton(
                    label: 'ACCELERATE',
                    onTap: widget.onAccelerate,
                  ),
                  leading: StageIconButton(
                    icon: AppIcons.inventory_2_rounded,
                    tooltip: 'Store this cultivation',
                    color: t.teal,
                    onTap: widget.onReturn,
                  ),
                  trailing: StageIconButton(
                    icon: AppIcons.close_rounded,
                    tooltip: 'Close',
                    color: t.textSecondary,
                    onTap: widget.onClose,
                  ),
                  centre: Text(
                    BreedConstants.formatRemaining(_remainingFor(slot)),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: rarityColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                  below: _instantFuse(t),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PILL
// ─────────────────────────────────────────────────────────────────────────────
