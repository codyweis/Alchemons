import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SlotInfoDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;

  // Incoming values are kept for initial render; live animation takes over.
  final Duration remaining;
  final double progress; // 0..1

  final bool isUndiscovered;
  final bool showAirPredict;
  final VoidCallback onAccelerate;
  final VoidCallback onReturn;
  final VoidCallback onClose;
  final VoidCallback onInstantHatch;

  const SlotInfoDialog({
    super.key,
    required this.slot,
    required this.primaryColor,
    required this.remaining,
    required this.progress,
    required this.isUndiscovered,
    required this.showAirPredict,
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

  late AnimationController _progressCtrl; // drives the circular progress

  // Cache to detect when to resync the progress controller
  int? _lastHatchAtMs;
  String? _lastRarityKey;

  // Keep a copy of latest slot from DB
  IncubatorSlot? _slot;

  @override
  void initState() {
    super.initState();

    // Intro animations
    _introCtrl = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _introCtrl, curve: Curves.elasticOut));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introCtrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _introCtrl.forward();

    // Progress animation controller
    final startValue = (widget.progress.isNaN ? 0.0 : widget.progress).clamp(
      0.0,
      1.0,
    );
    _progressCtrl = AnimationController(
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
      value: startValue,
    );

    _lastHatchAtMs = widget.slot.hatchAtUtcMs;
    _lastRarityKey = (widget.slot.rarity ?? 'common').toLowerCase();

    // Kick off an initial animation to 1.0 using the incoming remaining (best effort).
    final rarityDelay = _hatchDelayFor(widget.slot);
    if (rarityDelay != null) {
      final safeRemaining = widget.remaining.isNegative
          ? Duration.zero
          : widget.remaining;
      _restartProgressAnimation(
        currentProgress: startValue,
        remaining: safeRemaining,
      );
    }
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _progressCtrl.dispose();
    super.dispose();
  }

  Duration? _hatchDelayFor(IncubatorSlot slot) {
    final key = (slot.rarity ?? 'common').toLowerCase();
    return BreedConstants.rarityHatchTimes[key];
  }

  Duration _remainingFor(IncubatorSlot slot) {
    final ms = slot.hatchAtUtcMs;
    if (ms == null) return Duration.zero;
    final hatchAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    final now = DateTime.now().toUtc();
    final diff = hatchAt.difference(now);
    return diff.isNegative ? Duration.zero : diff;
  }

  double _progressFor(IncubatorSlot slot, Duration remaining) {
    final delay = _hatchDelayFor(slot);
    if (delay == null || delay.inMilliseconds <= 0) {
      final p = widget.progress.isNaN ? 0.0 : widget.progress;
      return p.clamp(0.0, 1.0);
    }
    final left = remaining.inMilliseconds.clamp(0, delay.inMilliseconds);
    final done = delay.inMilliseconds - left;
    return (done / delay.inMilliseconds).clamp(0.0, 1.0);
  }

  void _restartProgressAnimation({
    required double currentProgress,
    required Duration remaining,
  }) {
    _progressCtrl.stop();
    _progressCtrl.value = currentProgress;
    if (remaining <= Duration.zero) {
      _progressCtrl.value = 1.0;
    } else {
      _progressCtrl.animateTo(1.0, duration: remaining, curve: Curves.linear);
    }
  }

  // Resync the animation if DB reports a change (e.g., acceleration or slot move)
  void _maybeResync(IncubatorSlot slot) {
    final hatchMs = slot.hatchAtUtcMs;
    final rarityKey = (slot.rarity ?? 'common').toLowerCase();
    final changed = hatchMs != _lastHatchAtMs || rarityKey != _lastRarityKey;
    if (!changed) return;

    _lastHatchAtMs = hatchMs;
    _lastRarityKey = rarityKey;

    final remaining = _remainingFor(slot);
    final progress = _progressFor(slot, remaining);
    _restartProgressAnimation(currentProgress: progress, remaining: remaining);
  }

  List<String>? _extractParentTypes(IncubatorSlot slot) {
    try {
      final payloadStr = slot.payloadJson;
      if (payloadStr == null || payloadStr.isEmpty) return null;
      final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
      final parentage = payload['parentage'] as Map<String, dynamic>?;
      if (parentage == null) return null;

      final parent1 = parentage['parentA'] as Map<String, dynamic>?;
      final parent2 = parentage['parentB'] as Map<String, dynamic>?;

      final types = <String>[];
      final p1Types = parent1?['types'] as List<dynamic>?;
      final p2Types = parent2?['types'] as List<dynamic>?;

      if (p1Types != null && p1Types.isNotEmpty)
        types.add(p1Types.first.toString());
      if (p2Types != null && p2Types.isNotEmpty)
        types.add(p2Types.first.toString());

      return types.isEmpty ? null : types;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AlchemonsDatabase>();

    return AnimatedBuilder(
      animation: _introCtrl,
      builder: (context, child) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: StreamBuilder<List<IncubatorSlot>>(
                stream: db.incubatorDao.watchSlots(),
                builder: (context, snapshot) {
                  // Latest slot from DB or fallback
                  _slot =
                      snapshot.data?.firstWhere(
                        (s) => s.id == widget.slot.id,
                        orElse: () => _slot ?? widget.slot,
                      ) ??
                      _slot ??
                      widget.slot;

                  final slot = _slot!;
                  // Sync animation if DB changed key timing fields
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _maybeResync(slot),
                  );

                  final parentTypes = _extractParentTypes(slot);
                  final chamberLabel = 'CHAMBER ${slot.id + 1}';

                  final hatchDelay = _hatchDelayFor(slot);

                  final isReady =
                      _progressCtrl.value >= 0.999 ||
                      (_remainingFor(slot) <= Duration.zero);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header pill (no rarity badge)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(.12),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (slot.rarity ?? 'common').toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: .8,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Sacred circle + particle background + circular progress (smooth via controller)
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: widget.primaryColor.withOpacity(0.28),
                            width: 2,
                          ),
                        ),
                        child: ClipOval(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (parentTypes != null && parentTypes.isNotEmpty)
                                Positioned.fill(
                                  child: AlchemyBrewingParticleSystem(
                                    parentATypeId: parentTypes[0],
                                    parentBTypeId: parentTypes.length > 1
                                        ? parentTypes[1]
                                        : null,
                                    particleCount: 60,
                                    speedMultiplier: 0.18,
                                    fusion: false,
                                  ),
                                ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(.35),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 220,
                                height: 220,
                                child: AnimatedBuilder(
                                  animation: _progressCtrl,
                                  builder: (context, _) {
                                    final v = _progressCtrl.value.clamp(
                                      0.0,
                                      1.0,
                                    );
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 220,
                                          height: 220,
                                          child: CircularProgressIndicator(
                                            value: v,
                                            strokeWidth: 10,
                                            backgroundColor: Colors.white
                                                .withOpacity(.10),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  widget.primaryColor,
                                                ),
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${(v * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: .5,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Cultivating Specimen',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(
                                                  .75,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Undiscovered badge (Air faction only)
                      if (widget.showAirPredict && widget.isUndiscovered)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.teal.withOpacity(.4),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.insights_rounded,
                                size: 16,
                                color: Colors.teal.shade300,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'UNDISCOVERED',
                                style: TextStyle(
                                  color: Colors.teal.shade300,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Status card (live time remaining, computed INSIDE the AnimatedBuilder so it changes)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(.10),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _progressCtrl,
                                builder: (context, _) {
                                  Duration remaining;
                                  if (hatchDelay != null) {
                                    final v = _progressCtrl.value.clamp(
                                      0.0,
                                      1.0,
                                    );
                                    final leftMs =
                                        ((1.0 - v) * hatchDelay.inMilliseconds)
                                            .clamp(
                                              0.0,
                                              hatchDelay.inMilliseconds
                                                  .toDouble(),
                                            )
                                            .round();
                                    remaining = Duration(milliseconds: leftMs);
                                  } else {
                                    // Fallback to wall clock when hatch time is unknown
                                    final current = _slot!;
                                    remaining = _remainingFor(current);
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Time Remaining',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(.65),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        BreedConstants.formatRemaining(
                                          remaining,
                                        ),
                                        style: TextStyle(
                                          color: widget.primaryColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: .5,
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

                      const SizedBox(height: 20),

                      // === UPDATED BUTTON LAYOUT ===
                      // This Column splits primary and secondary actions
                      // to improve readability and prevent truncation.
                      Column(
                        children: [
                          // Primary Actions (Accelerate / Instant)
                          FutureBuilder<int>(
                            future: context
                                .read<AlchemonsDatabase>()
                                .inventoryDao
                                .getItemQty(InvKeys.instantHatch),
                            builder: (context, snap) {
                              final qty = snap.data ?? 0;
                              final canUseInstant = !isReady && qty > 0;

                              return Row(
                                children: [
                                  _ctaButton(
                                    label: 'ACCELERATE',
                                    icon: Icons.speed_rounded,
                                    color: Colors.orange,
                                    filled: true, // primary
                                    onTap: widget.onAccelerate,
                                  ),
                                  // Conditionally show Instant Hatch button
                                  if (canUseInstant) ...[
                                    const SizedBox(width: 10),
                                    _ctaButton(
                                      label: 'INSTANT (x$qty)', // Shorter label
                                      icon: Icons.flash_on_rounded,
                                      color: Colors.green, // Theme color
                                      filled: true, // primary
                                      onTap: widget.onInstantHatch,
                                    ),
                                  ],
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 10),

                          // Secondary Actions (Return / Close)
                          Row(
                            children: [
                              _ctaButton(
                                label: 'RETURN',
                                icon: Icons.inventory_2_rounded,
                                color: Colors.blue,
                                filled: false, // secondary
                                onTap: widget.onReturn,
                              ),
                              const SizedBox(width: 10),
                              _ctaButton(
                                label: 'CLOSE',
                                icon: Icons.close_rounded,
                                color: Colors.grey,
                                filled: false, // secondary
                                onTap: widget.onClose,
                              ),
                            ],
                          ),
                        ],
                      ),
                      // === END OF UPDATED LAYOUT ===
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // New pill-style button with ripple + consistent sizing
  Widget _ctaButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool filled,
  }) {
    final radius = BorderRadius.circular(14);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: filled ? color.withOpacity(.0) : color.withOpacity(.45),
            width: 2,
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: filled ? color.withOpacity(.85) : color.withOpacity(.18),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: filled ? Colors.white : color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: filled ? Colors.white : color,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
