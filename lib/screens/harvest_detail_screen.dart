// lib/screens/harvest_detail_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/farm_element.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/harvest_service.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/fx/alchemy_tap_fx.dart';
import 'package:alchemons/widgets/glowing_icon.dart';
import 'package:alchemons/widgets/harvest/harvest_instance.dart';
import 'package:alchemons/widgets/creature_sprite.dart'; // <-- you provided this
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class HarvestDetailScreen extends StatefulWidget {
  const HarvestDetailScreen({
    super.key,
    required this.element,
    required this.service,
    this.defaultDuration = const Duration(minutes: 30),
  });

  final FarmElement element;
  final HarvestService service;
  final Duration defaultDuration;

  @override
  State<HarvestDetailScreen> createState() => _HarvestDetailScreenState();
}

class _HarvestDetailScreenState extends State<HarvestDetailScreen>
    with TickerProviderStateMixin {
  // Seamless time
  late final Ticker _ticker;
  double _tSeconds = 0.0;
  late AnimationController _tapFxCtrl;
  Offset? _tapLocal;

  String? _jobIdCache;
  int _totalMsCache = 0;

  late final AnimationController _collectCtrl;

  // Job progress + header glow
  late final AnimationController _jobCtrl;
  late final AnimationController _glowController;

  Future<Widget>? _creatureFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _prepareCreatureFuture();
  }

  @override
  void initState() {
    super.initState();

    _collectCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _tapFxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // Continuous time (no resets)
    _ticker = createTicker((elapsed) {
      _tSeconds = elapsed.inMicroseconds / 1e6;
      // Repaint everything that depends on time
      if (mounted) setState(() {});
    })..start();

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
  }

  @override
  void dispose() {
    _ticker.dispose();
    _jobCtrl.dispose();
    _glowController.dispose();
    _collectCtrl.dispose();
    _tapFxCtrl.dispose();
    super.dispose();
  }

  void _prepareCreatureFuture() {
    final farm = widget.service.farm(widget.element);
    _creatureFuture = _buildCreatureFromFarm(farm);
  }

  void _syncJobProgress(HarvestFarmState farm) {
    final j = farm.active;

    if (j == null) {
      if (_jobCtrl.value != 0) _jobCtrl.value = 0;
      _jobCtrl.stop();
      return;
    }

    final totalMs = j.durationMs;
    final rem = farm.remaining; // derived from DB (startUtcMs + durationMs)
    final progress = (rem == null || totalMs == 0)
        ? 0.0
        : (1.0 - rem.inMilliseconds / totalMs).clamp(0.0, 1.0);

    // 1) Make the controller represent the full job duration.
    final total = Duration(milliseconds: totalMs);
    if (_jobCtrl.duration != total) {
      _jobCtrl.duration = total;
    }

    // 2) If we’re completed, snap to 1 and stop.
    if (farm.completed) {
      if (_jobCtrl.value != 1.0) _jobCtrl.value = 1.0;
      _jobCtrl.stop();
      _jobIdCache = j.jobId;
      _totalMsCache = totalMs;
      return;
    }

    // 3) Keep it running in real time. If a nudge changed remaining,
    //    progress will jump; re-seed the controller and continue.
    //    Only reset when the delta is meaningful to avoid jitter.
    const eps = 0.002; // ~0.2%
    if ((_jobCtrl.value - progress).abs() > eps || !_jobCtrl.isAnimating) {
      // Forward from the real progress; with duration=total this will
      // take total*(1-progress) == remaining to finish.
      _jobCtrl.forward(from: progress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final farm = widget.service.farm(widget.element);
    final color = widget.element.color;

    _syncJobProgress(farm);

    final progress = _jobCtrl.value;
    // Start from 0 when no active job, fill up to 0.85 when complete
    final targetFill = farm.hasActive
        ? (0.0 + 0.85 * progress).clamp(0.0, 0.85)
        : 0.0;
    final curvedFill = Curves.easeOutCubic.transform(targetFill);

    final drainP = Curves.easeInOutCubic.transform(_collectCtrl.value); // 0..1
    final effectiveFill = curvedFill * (1.0 - drainP);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      ),
      // We still listen to _jobCtrl changes; time updates come from setState in the ticker.
      body: AnimatedBuilder(
        animation: _jobCtrl,
        builder: (_, __) {
          final Duration? rem = farm.hasActive && _jobCtrl.duration != null
              ? _jobCtrl.duration! * (1 - _jobCtrl.value)
              : farm.remaining;

          return Column(
            children: [
              _buildHeader(context, color),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    children: [
                      _HeaderCard(
                        color: color,
                        icon: widget.element.icon,
                        label: widget.element.label,
                        status: !farm.unlocked
                            ? 'LOCKED'
                            : (farm.hasActive
                                  ? (farm.completed ? 'COMPLETE' : 'ACTIVE')
                                  : 'READY'),
                      ),
                      const SizedBox(height: 14),
                      // ── Tube + Creature (inside) + Foreground glare ─────────────
                      AspectRatio(
                        aspectRatio: 3 / 4,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final size = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final geo = _TubeGeometry.fromSize(size);
                            final inner = geo.inner;

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapDown: (details) {
                                _handleTapBoost(farm);

                                // clamp tap to inner RRect so FX stays inside glass
                                final lp = details.localPosition;
                                final clamped = Offset(
                                  lp.dx.clamp(inner.left + 6, inner.right - 6),
                                  lp.dy.clamp(inner.top + 6, inner.bottom - 6),
                                );
                                setState(() => _tapLocal = clamped);
                                _tapFxCtrl.forward(from: 0);
                              },
                              child: AnimatedBuilder(
                                animation: _collectCtrl,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: inner._toBorderRadius(),
                                        child: Align(
                                          alignment: Alignment(
                                            0,
                                            _creatureY(effectiveFill),
                                          ),
                                          child: AnimatedBuilder(
                                            animation: _tapFxCtrl,
                                            builder: (context, child) {
                                              // Damped shake: 0..1 -> quick oscillation, fading out
                                              final v =
                                                  _tapFxCtrl.value; // 0..1
                                              // frequency & decay tuned to feel juicy but subtle
                                              final osc = math.sin(
                                                v * math.pi * 10,
                                              );
                                              final decay = (1.0 - v);
                                              final amp =
                                                  6.0 * decay; // max ~6px
                                              final dx = osc * amp * 0.6;
                                              final dy = -osc * amp * 0.35;
                                              final rot =
                                                  osc * 0.025; // ~1.4 degrees

                                              return Transform.translate(
                                                offset: Offset(dx, dy),
                                                child: Transform.rotate(
                                                  angle: rot,
                                                  child: child,
                                                ),
                                              );
                                            },
                                            child: FutureBuilder<Widget>(
                                              future: _creatureFuture,
                                              builder: (context, snapshot) {
                                                if (snapshot.connectionState ==
                                                    ConnectionState.waiting) {
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                }
                                                if (snapshot.hasError) {
                                                  return Icon(
                                                    farm.element.icon,
                                                    size: 28,
                                                    color: Colors.white
                                                        .withOpacity(.55),
                                                  );
                                                }
                                                return snapshot.data ??
                                                    const SizedBox.shrink();
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Background fluid, bubbles, inner caustics, back edge
                                    CustomPaint(
                                      painter: _TubeBackgroundPainter(
                                        tSeconds: _tSeconds,
                                        fill: effectiveFill,
                                        color: color,
                                        active: farm.hasActive,
                                      ),
                                      size: size,
                                    ),
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: AnimatedBuilder(
                                          animation: _tapFxCtrl,
                                          builder: (_, __) => AlchemyTapFX(
                                            center: _tapLocal,
                                            progress: _tapFxCtrl.value,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Foreground glass highlight, glare, light edges
                                    CustomPaint(
                                      painter: _TubeForegroundPainter(
                                        tSeconds: _tSeconds,
                                        color: color,
                                      ),
                                      size: size,
                                    ),
                                  ],
                                ),
                                builder: (_, child) {
                                  // Damped multi-axis shake while draining
                                  final v = _collectCtrl.value; // 0..1
                                  final decay =
                                      1.0 - v; // linear decay works well here
                                  final dx =
                                      math.sin(v * math.pi * 10) *
                                      6.0 *
                                      decay; // ~6px -> 0
                                  final dy =
                                      math.cos(v * math.pi * 8) *
                                      4.0 *
                                      decay; // ~4px -> 0
                                  final rot =
                                      math.sin(v * math.pi * 6) *
                                      0.015 *
                                      decay; // ~0.86°
                                  return Transform.translate(
                                    offset: Offset(dx, dy),
                                    child: Transform.rotate(
                                      angle: rot,
                                      child: child,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      Text(
                        !farm.unlocked
                            ? 'This extractor is locked.'
                            : (!farm.hasActive
                                  ? 'No active extraction. Insert a creature to begin.'
                                  : (farm.completed
                                        ? 'Extraction complete — ready to collect.'
                                        : 'Extracting elements from Alchemon... ${_fmt(rem)} left')),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(.82),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (!farm.unlocked)
                        _LockedPanel(
                          color: color,
                          onBack: () => Navigator.pop(context),
                        )
                      else if (!farm.hasActive)
                        _StartPanel(
                          color: color,
                          element: widget.element,
                          defaultDuration: widget.defaultDuration,
                          onPickAndStart: _handlePickAndStart,
                        )
                      else
                        _ActivePanel(
                          color: color,
                          farm: farm,
                          unit: _unit(widget.element),
                          onCollect: farm.completed
                              ? () async {
                                  // 1) Play local drain+shake cinematic
                                  HapticFeedback.mediumImpact();
                                  await _collectCtrl.forward(from: 0);

                                  // 2) Now collect from DB (state switches to no-active-job)
                                  final got = await widget.service.collect(
                                    widget.element,
                                  );

                                  if (!mounted) return;

                                  // Optional light settle
                                  HapticFeedback.lightImpact();

                                  // 3) Toast + refresh creature (in case sprite changes)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Collected $got ${_unit(widget.element)}',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  _prepareCreatureFuture();
                                  setState(() {});
                                }
                              : null,
                          onCancel: () async {
                            // Prevent double taps while animating
                            if (_collectCtrl.isAnimating) return;

                            // 1) Play drain + shake (same controller you added for Collect)
                            HapticFeedback.heavyImpact();
                            await _collectCtrl.forward(from: 0);

                            // 2) Cancel in DB (no payout)
                            await widget.service.cancel(widget.element);

                            if (!mounted) return;

                            // 3) Small settle + UI refresh
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Extraction cancelled'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            _prepareCreatureFuture();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _handleTapBoost(HarvestFarmState farm) async {
    if (!farm.hasActive || farm.completed) return;

    // Optimistic progress
    final totalMs = farm.active!.durationMs;
    final currentMs = (1.0 - _jobCtrl.value) * totalMs;
    final newMs = (currentMs - 1000).clamp(0, totalMs).toDouble();
    _jobCtrl.value = 1.0 - (newMs / totalMs);

    // Persist (don’t await to keep taps snappy; watcher will realign)
    // Optionally throttle/batch if you expect very high tap rates.
    unawaited(widget.service.nudge(widget.element));
  }

  // Creature mapping (uses your CreatureSprite; falls back to icon if data missing)
  //make async
  Future<Widget> _buildCreatureFromFarm(HarvestFarmState farm) async {
    final job = farm.active;
    if (job == null) {
      return Icon(
        farm.element.icon,
        size: 28,
        color: Colors.white.withOpacity(.55),
      );
    }

    // 1. DB lookup (service should expose this)
    final inst = await context.read<AlchemonsDatabase>().getInstance(
      job.creatureInstanceId,
    );
    if (inst == null) {
      return Icon(
        farm.element.icon,
        size: 40,
        color: Colors.white.withOpacity(.75),
      );
    }

    // 2. Repo lookup
    final repo = context.read<CreatureRepository>();
    final base = repo.getCreatureById(inst.baseId);
    if (base == null || base.spriteData == null) {
      return Icon(
        farm.element.icon,
        size: 40,
        color: Colors.white.withOpacity(.75),
      );
    }
    final genetics = decodeGenetics(inst.geneticsJson);

    // 3. Render
    return CreatureSprite(
      spritePath: base.spriteData!.spriteSheetPath,
      totalFrames: base.spriteData!.totalFrames,
      rows: base.spriteData!.rows,
      frameSize: Vector2(
        base.spriteData!.frameWidth.toDouble(),
        base.spriteData!.frameHeight.toDouble(),
      ),
      stepTime: base.spriteData!.frameDurationMs / 1000.0,
      scale: scaleFromGenes(genetics),
      saturation: satFromGenes(genetics),
      brightness: briFromGenes(genetics),
      hueShift: hueFromGenes(genetics),
      isPrismatic: inst.isPrismaticSkin,
    );
  }

  // Float the creature roughly near the surface
  double _creatureY(double fill) {
    // Align's Y: -1 (top) .. +1 (bottom)
    final y = 0.8 - fill * 1.6;
    return y.clamp(-0.2, 0.6);
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: _GlassContainer(
          accentColor: accentColor,
          glowController: _glowController,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _IconButton(
                  icon: Icons.arrow_back_rounded,
                  accentColor: accentColor,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.element.label.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              color: accentColor.withOpacity(0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resource Extractor',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                GlowingIcon(
                  icon: Icons.access_alarm,
                  color: accentColor,
                  controller: _glowController,
                  dialogTitle: "Extraction Process",
                  dialogMessage:
                      "Extractors draw elemental resources from creatures over time. The extraction rate depends on the creature's level and nature and species. You can speed up the process by tapping the extractor.",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePickAndStart() async {
    final instanceId = await pickInstanceForHarvest(
      context: context,
      element: widget.element,
      duration: widget.defaultDuration,
    );
    if (instanceId == null) return;

    final farm = widget.service.farm(widget.element);
    final ok = await widget.service.startJob(
      element: widget.element,
      creatureInstanceId: instanceId,
      duration: widget.defaultDuration,
      ratePerMinute: _computeRatePerMinute(
        element: widget.element,
        hasMatchingElement: true,
        natureBonusPct: 10,
        level: farm.level,
      ),
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot start job'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _prepareCreatureFuture();
      setState(() {});
    }
  }

  int _computeRatePerMinute({
    required FarmElement element,
    required bool hasMatchingElement,
    required int natureBonusPct,
    required int level,
  }) {
    var base = switch (element) {
      FarmElement.fire => 3,
      FarmElement.water => 3,
      FarmElement.air => 2,
      FarmElement.earth => 2,
    };
    base += (level - 1);
    if (hasMatchingElement) base = (base * 1.25).round();
    base = (base * (1 + natureBonusPct / 100)).round();
    return base.clamp(1, 999);
  }

  String _unit(FarmElement e) => switch (e) {
    FarmElement.fire => 'Embers',
    FarmElement.water => 'Droplets',
    FarmElement.air => 'Breeze',
    FarmElement.earth => 'Shards',
  };

  String _fmt(Duration? d) {
    if (d == null) return '—';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

// =================== Glass Header Components ===================

class _GlassContainer extends StatelessWidget {
  const _GlassContainer({
    required this.accentColor,
    required this.glowController,
    required this.child,
  });

  final Color accentColor;
  final AnimationController glowController;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, _) {
        final glowIntensity = 0.15 + (glowController.value * 0.15);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.08),
                    Colors.black.withOpacity(0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: accentColor.withOpacity(0.25),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(glowIntensity),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
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
            color: widget.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Icon(
            widget.icon,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
        ),
      ),
    );
  }
}

// =================== Tube geometry helper ===================

class _TubeGeometry {
  _TubeGeometry(this.outer, this.inner);
  final RRect outer;
  final RRect inner;

  static _TubeGeometry fromSize(Size size) {
    final w = size.width * .56;
    final h = size.height * .82;
    final cx = size.width / 2;
    final top = size.height * .06;
    final rr = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, top + h / 2), width: w, height: h),
      const Radius.circular(28),
    );
    return _TubeGeometry(rr, rr.deflate(2.0));
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

// =================== Painters ===================

class _SplashPainter extends CustomPainter {
  _SplashPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .55);

    // Expanding circle
    final circlePaint = Paint()
      ..color = color.withOpacity((1 - progress) * 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * (1 - progress);
    canvas.drawCircle(center, 40 * progress, circlePaint);

    // Sparkles
    final sparklePaint = Paint()
      ..color = Colors.white.withOpacity(1 - progress);
    final sparkCount = 6;
    for (int i = 0; i < sparkCount; i++) {
      final ang = (2 * math.pi / sparkCount) * i;
      final dx = math.cos(ang) * 50 * progress;
      final dy = math.sin(ang) * 50 * progress;
      canvas.drawCircle(
        center.translate(dx, dy),
        3 * (1 - progress),
        sparklePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPainter old) =>
      old.progress != progress || old.color != color;
}

class _TubeBackgroundPainter extends CustomPainter {
  _TubeBackgroundPainter({
    required this.tSeconds,
    required this.fill,
    required this.color,
    required this.active,
  });

  final double tSeconds;
  final double fill;
  final Color color;
  final bool active;

  double _harmonic(double x, double phase, double a1, double a2) {
    return a1 * math.sin(x + phase) + a2 * math.sin(2 * x + phase * 1.7);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _TubeGeometry.fromSize(size);
    final rr = geo.outer;
    final inner = geo.inner;

    // Back glass accents (behind fluid slightly)
    final glassStrokeBack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(.28);
    final redEdgeBack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFFFF6B6B).withOpacity(.20);
    final blueEdgeBack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = const Color(0xFF5EC8FF).withOpacity(.20);

    // Slight offset double-edge for chromatic feel
    canvas.save();
    canvas.translate(.35, .35);
    canvas.drawRRect(rr.deflate(0.6), redEdgeBack);
    canvas.restore();
    canvas.save();
    canvas.translate(-.35, -.35);
    canvas.drawRRect(rr.deflate(0.6), blueEdgeBack);
    canvas.restore();

    canvas.drawRRect(rr, glassStrokeBack);

    // Clip to inner to draw fluid & contents
    canvas.save();
    canvas.clipRRect(inner);

    final baseTop = inner.bottom - inner.height * fill;

    final amp = (active ? 6.5 : 3.5);
    final amp2 = (active ? 3.2 : 1.8);
    final phase = tSeconds * 2 * math.pi;

    final left = inner.left;
    final right = inner.right;
    final bottom = inner.bottom;

    // Fluid surface path
    final surface = Path();
    const dx = 6.0;
    surface.moveTo(left, bottom);
    surface.lineTo(left, baseTop);

    for (double x = left; x <= right; x += dx) {
      final px = (x - left) / inner.width * math.pi * 2;
      final y =
          baseTop +
          _harmonic(px, phase, amp, amp2) +
          0.8 * math.sin(px * 3 + phase * 1.2);
      surface.lineTo(x, y);
    }
    surface.lineTo(right, bottom);
    surface.close();

    final fluidGrad = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(.5), color.withOpacity(.6)],
    ).createShader(inner.outerRect);
    final fluidPaint = Paint()..shader = fluidGrad;
    canvas.drawPath(surface, fluidPaint);

    // Surface shadow band
    final shadow = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.black.withOpacity(.18), Colors.transparent],
      ).createShader(Rect.fromLTRB(left, baseTop - 16, right, baseTop + 16));
    canvas.drawRect(
      Rect.fromLTRB(left, baseTop - 16, right, baseTop + 16),
      shadow,
    );

    // Caustic stripes under the surface
    final caustic = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withOpacity(.08);
    for (int i = 0; i < 3; i++) {
      final p = Path();
      final offset = (tSeconds * 2 + i * .33) * math.pi * 2;
      final yBase = baseTop + 10 + i * 16.0;
      for (double x = left + 6; x <= right - 6; x += 8) {
        final px = (x - left) / inner.width * math.pi * 2;
        final y = yBase + 3.0 * math.sin(px * 1.4 + offset);
        if (x == left + 6) {
          p.moveTo(x, y);
        } else {
          p.lineTo(x, y);
        }
      }
      canvas.drawPath(p, caustic);
    }

    // Bubbles
    final bubble = Paint()..color = Colors.white.withOpacity(.70);
    final clip = Rect.fromLTRB(left + 6, baseTop + 6, right - 6, bottom - 6);
    final total = active ? 28 : 12;
    for (int i = 0; i < total; i++) {
      final seed = i * 9176.0;
      final col = (seed % 97) / 97.0;
      final startX = left + 8 + col * (inner.width - 16);
      final size = 1.4 + (seed % 5) * .35 + (i % 7 == 0 ? 0.8 : 0.0);
      final speed = (0.15 + ((seed % 11) / 11.0) * 0.35) * (active ? 1.4 : 0.9);

      final ty = (tSeconds * speed + (seed % 13) * .01) % 1.0;
      final y = clip.bottom - clip.height * ty;
      final wob = 3.0 * math.sin(ty * 10 + seed);
      final x = startX + wob;

      if (y < clip.top) continue;
      canvas.drawCircle(Offset(x, y), size, bubble);

      if (active && i % 5 == 0) {
        final trail = Paint()
          ..color = Colors.white.withOpacity(.10)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset(x, y + 6), size * .8, trail);
      }
    }

    // Foam dots near surface
    final foamPaint = Paint()..color = Colors.white.withOpacity(.28);
    final foamCount = (inner.width / 18).floor();
    for (int i = 0; i <= foamCount; i++) {
      final fx = left + 8 + i * 18.0 + 3.0 * math.sin(i + phase);
      final px = (fx - left) / inner.width * math.pi * 2;
      final fy =
          baseTop +
          2.0 * math.sin(px * 1.2 + phase * 1.1) +
          1.0 * math.sin(px * 2.0 + phase * 1.7);
      canvas.drawCircle(
        Offset(fx, fy),
        1.6 + (i % 3 == 0 ? .8 : 0.0),
        foamPaint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TubeBackgroundPainter old) =>
      old.tSeconds != tSeconds ||
      old.fill != fill ||
      old.color != color ||
      old.active != active;
}

class _TubeForegroundPainter extends CustomPainter {
  _TubeForegroundPainter({required this.tSeconds, required this.color});
  final double tSeconds;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final geo = _TubeGeometry.fromSize(size);
    final rr = geo.outer;

    // Seamless sliding glare: draw two bands to cover wrap
    final g = (tSeconds * 0.25) % 1.0; // cycles per second
    const bandFrac = .22;

    for (final base in [g, g - 1.0]) {
      final leftFrac = base - bandFrac * .5;
      final rect = Rect.fromLTWH(
        rr.left + rr.width * leftFrac,
        rr.top,
        rr.width * bandFrac,
        rr.height,
      );
      if (rect.right < rr.left || rect.left > rr.right) continue;

      final glare = Paint()
        ..blendMode = BlendMode.plus
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.white.withOpacity(.25),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(rect);
      canvas.drawRRect(rr, glare);
    }

    // Droplets on glass
    final drop = Paint()..color = Colors.white.withOpacity(.08);
    for (int i = 0; i < 8; i++) {
      final dx = (i.isEven ? 1 : -1) * (2 + (i % 3));
      final x = rr.left + rr.width * (.18 + (i % 5) * .14) + dx;
      final y = rr.top + 20 + (i * 9) % (rr.height * .35);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 3.2, height: 6.0),
        drop,
      );
    }

    // Foreground highlight line
    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomLeft,
        colors: [Colors.white.withOpacity(.45), Colors.transparent],
      ).createShader(Rect.fromLTWH(rr.left - 6, rr.top, 10, rr.height));
    canvas.drawRRect(rr, highlight);

    // Foreground crisp glass stroke
    final glassStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white.withOpacity(.50);
    canvas.drawRRect(rr, glassStroke);

    // Subtle chromatic edges (foreground)
    final redEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xFFFF6B6B).withOpacity(.33);
    final blueEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..color = const Color(0xFF5EC8FF).withOpacity(.33);

    canvas.save();
    canvas.translate(.35, .35);
    canvas.drawRRect(rr.deflate(0.6), redEdge);
    canvas.restore();
    canvas.save();
    canvas.translate(-.35, -.35);
    canvas.drawRRect(rr.deflate(0.6), blueEdge);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TubeForegroundPainter old) =>
      old.tSeconds != tSeconds || old.color != color;
}

// =================== UI Panels ===================

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.color,
    required this.icon,
    required this.label,
    required this.status,
  });

  final Color color;
  final IconData icon;
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    (IconData, Color, Color) statusStyle() {
      return switch (s) {
        'locked' => (
          Icons.lock_outline_rounded,
          Colors.white.withOpacity(.85),
          Colors.white.withOpacity(.16),
        ),
        'active' => (Icons.bolt_rounded, Colors.white, color.withOpacity(.55)),
        'complete' => (
          Icons.check_circle_rounded,
          Colors.white,
          color.withOpacity(.55),
        ),
        _ => (Icons.check_circle_rounded, Colors.white, color.withOpacity(.45)),
      };
    }

    final (ic, fg, border) = statusStyle();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ic, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedPanel extends StatelessWidget {
  const _LockedPanel({required this.color, required this.onBack});
  final Color color;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HintText('Unlock this extractor from the previous screen.'),
        const SizedBox(height: 10),
        _OutlineBtn(label: 'Go Back', color: color, onTap: onBack),
      ],
    );
  }
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.color,
    required this.element,
    required this.defaultDuration,
    required this.onPickAndStart,
  });

  final Color color;
  final FarmElement element;
  final Duration defaultDuration;
  final VoidCallback onPickAndStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HintText(
          'Insert a matching-element creature to start extracting ${_unit(element)}.',
        ),
        const SizedBox(height: 10),
        _PrimaryBtn(
          label: 'Insert Creature',
          color: color,
          onTap: onPickAndStart,
        ),
        const SizedBox(height: 8),
        Text(
          'Default duration: ${defaultDuration.inMinutes}m',
          style: TextStyle(
            color: Colors.white.withOpacity(.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Note: costs stamina while extracting.',
          style: TextStyle(
            color: Colors.white.withOpacity(.55),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _unit(FarmElement e) => switch (e) {
    FarmElement.fire => 'Embers',
    FarmElement.water => 'Droplets',
    FarmElement.air => 'Breeze',
    FarmElement.earth => 'Shards',
  };
}

class _ActivePanel extends StatelessWidget {
  const _ActivePanel({
    required this.color,
    required this.farm,
    required this.unit,
    required this.onCollect,
    required this.onCancel,
  });

  final Color color;
  final HarvestFarmState farm;
  final String unit;
  final VoidCallback? onCollect;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final j = farm.active!;
    final duration = Duration(milliseconds: j.durationMs);
    final rate = j.ratePerMinute;
    final total = rate * duration.inMinutes;

    return Column(
      children: [
        Text(
          'Rate: $rate / min',
          style: TextStyle(
            color: Colors.white.withOpacity(.78),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'Total extracted once complete: $total $unit',
          style: TextStyle(
            color: Colors.white.withOpacity(.78),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PrimaryBtn(
                label: farm.completed ? 'Collect' : 'Collect (locked)',
                color: color,
                onTap: farm.completed && onCollect != null ? onCollect! : () {},
                disabled: !farm.completed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlineBtn(
                label: 'Cancel',
                color: color,
                onTap: onCancel,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const _HintText('Cancelling discards progress.'),
      ],
    );
  }
}

class _HintText extends StatelessWidget {
  const _HintText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(.72),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.color,
    required this.onTap,
    this.disabled = false,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final c = disabled ? Colors.grey : color;
    return Opacity(
      opacity: disabled ? .6 : 1,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c, c.withOpacity(.85)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.18)),
            boxShadow: [BoxShadow(color: c.withOpacity(.28), blurRadius: 18)],
          ),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
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
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.55), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(.95),
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
        ),
      ),
    );
  }
}
