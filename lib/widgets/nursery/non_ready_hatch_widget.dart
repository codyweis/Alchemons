import 'dart:convert';

import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/egg/egg_payload_helpers.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/animations/elemental_particle_system.dart';
import 'package:alchemons/widgets/nursery/cultivation_dialog_actions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SlotInfoDialog extends StatefulWidget {
  final IncubatorSlot slot;
  final Color primaryColor;

  // Incoming values are kept for initial render; live animation takes over.
  final Duration remaining;
  final double progress; // 0..1

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
    required this.progress,
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

  late AnimationController _progressCtrl; // drives the circular progress

  // Cache to detect when to resync the progress controller
  int? _lastHatchAtMs;
  String? _lastRarityKey;

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

    // After _progressCtrl = AnimationController(...)
    _progressCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _closeIfReady();
      }
    });

    // Also handle cases where we set value = 1.0 directly (no status change)
    _progressCtrl.addListener(() {
      final v = _progressCtrl.value;
      if (v >= .999) {
        _closeIfReady();
      }
    });
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
    final dialogSurface = theme.isDark ? t.bg1 : Colors.white;

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
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _maybeResync(slot),
                );

                final parentTypes = _extractParentTypes(slot);
                final rarity = (slot.rarity ?? 'common').toLowerCase();
                final rarityColor = BreedConstants.getRarityColor(rarity);
                final chamberLabel = 'CHAMBER ${slot.id + 1}';
                final hatchDelay = _hatchDelayFor(slot);
                final isReady =
                    _progressCtrl.value >= 0.999 ||
                    (_remainingFor(slot) <= Duration.zero);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── PROGRESS BANNER ──────────────────────────────────
                    SizedBox(
                      height: 190,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Particle background
                          if (parentTypes != null && parentTypes.isNotEmpty)
                            RepaintBoundary(
                              child: AlchemyBrewingParticleSystem(
                                parentATypeId: parentTypes[0],
                                parentBTypeId: parentTypes.length > 1
                                    ? parentTypes[1]
                                    : null,
                                particleCount: 50,
                                speedMultiplier: 0.12,
                                fusion: false,
                                theme: theme,
                              ),
                            )
                          else
                            Container(color: dialogSurface),

                          // Vignette
                          Container(
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment.center,
                                radius: 0.85,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: .5),
                                ],
                              ),
                            ),
                          ),

                          // Bottom fade
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 56,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: .65),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Top-left chamber pill
                          Positioned(
                            top: 14,
                            left: 14,
                            child: _InProgressPill(
                              label: chamberLabel,
                              color: rarityColor,
                            ),
                          ),

                          // Circular progress in center
                          Center(
                            child: AnimatedBuilder(
                              animation: _progressCtrl,
                              builder: (context, _) {
                                final v = _progressCtrl.value.clamp(0.0, 1.0);
                                return SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 92,
                                        height: 92,
                                        child: CircularProgressIndicator(
                                          value: v,
                                          strokeWidth: 5,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: .10),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                rarityColor,
                                              ),
                                        ),
                                      ),
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.black.withValues(
                                            alpha: .45,
                                          ),
                                          border: Border.all(
                                            color: rarityColor.withValues(
                                              alpha: .3,
                                            ),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${(v * 100).toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: rarityColor,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: .5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── INFO + ACTIONS PANEL ──────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: dialogSurface,
                        border: Border(
                          left: BorderSide(color: t.borderMid, width: 1),
                          right: BorderSide(color: t.borderMid, width: 1),
                          bottom: BorderSide(color: t.borderMid, width: 1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 3,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: rarityColor,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: rarityColor.withValues(
                                              alpha: .5,
                                            ),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'IN CULTIVATION',
                                            style: TextStyle(
                                              color: theme.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedBuilder(
                                            animation: _progressCtrl,
                                            builder: (context, _) {
                                              Duration remaining;
                                              if (hatchDelay != null) {
                                                final v = _progressCtrl.value
                                                    .clamp(0.0, 1.0);
                                                final leftMs =
                                                    ((1.0 - v) *
                                                            hatchDelay
                                                                .inMilliseconds)
                                                        .clamp(
                                                          0.0,
                                                          hatchDelay
                                                              .inMilliseconds
                                                              .toDouble(),
                                                        )
                                                        .round();
                                                remaining = Duration(
                                                  milliseconds: leftMs,
                                                );
                                              } else {
                                                remaining = _remainingFor(
                                                  _slot!,
                                                );
                                              }
                                              return Text(
                                                BreedConstants.formatRemaining(
                                                  remaining,
                                                ),
                                                style: TextStyle(
                                                  color: rarityColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: .4,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Container(
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        rarityColor.withValues(alpha: .35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FutureBuilder<int>(
                            future: context
                                .read<AlchemonsDatabase>()
                                .inventoryDao
                                .getItemQty(InvKeys.instantHatch),
                            builder: (context, snap) {
                              final qty = snap.data ?? 0;
                              final canUseInstant = !isReady && qty > 0;
                              return CultivationDialogActionArea(
                                tokens: t,
                                children: [
                                  CultivationDialogButton(
                                    tokens: t,
                                    label: 'ACCELERATE CULTIVATION',
                                    icon: Icons.speed_rounded,
                                    accentColor: t.amberBright,
                                    emphasis:
                                        CultivationDialogButtonEmphasis.primary,
                                    onTap: widget.onAccelerate,
                                  ),
                                  if (canUseInstant) ...[
                                    const SizedBox(height: 10),
                                    CultivationDialogButton(
                                      tokens: t,
                                      label: 'USE INSTANT HATCH ×$qty',
                                      icon: Icons.flash_on_rounded,
                                      accentColor: t.success,
                                      emphasis: CultivationDialogButtonEmphasis
                                          .primary,
                                      onTap: widget.onInstantHatch,
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: CultivationDialogButton(
                                          tokens: t,
                                          label: 'STORE',
                                          icon: Icons.inventory_2_rounded,
                                          accentColor: t.teal,
                                          onTap: widget.onReturn,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: CultivationDialogButton(
                                          tokens: t,
                                          label: 'CLOSE',
                                          icon: Icons.close_rounded,
                                          accentColor: t.textSecondary,
                                          onTap: widget.onClose,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
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

class _InProgressPill extends StatelessWidget {
  const _InProgressPill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: .45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.3,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
