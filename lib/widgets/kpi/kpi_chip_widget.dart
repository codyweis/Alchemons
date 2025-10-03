import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

/// Collapsed shows ONLY a status string (READY / ALL AVAILABLE / INCUBATING / OPEN / EXTRACTING / COLLECT).
/// Blinks more obviously when [readyCount] > 0 (aura + small ping dot). Tap opens popup; long-press deep-links.
class KpiChip extends StatelessWidget {
  final String heroTag;
  final IconData icon; // also shown collapsed now
  final String label; // popup header ("Incubating" / "Harvest")
  final String compactValue; // STATUS ONLY for collapsed
  final int readyCount; // >0 triggers blink aura + ping dot
  final Color accent;
  final VoidCallback? onOpen; // deep link (long-press)
  final List<String> details; // popup lines
  final double breathe; // 0..1 float

  const KpiChip({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.compactValue,
    required this.readyCount,
    required this.accent,
    required this.details,
    required this.breathe,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final floatY = -1.5 * math.sin(breathe * math.pi);

    return Transform.translate(
      offset: Offset(0, floatY),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openPopup(context),
        onLongPress: onOpen,
        child: Hero(
          tag: heroTag,
          flightShuttleBuilder: (ctx, anim, dir, from, to) {
            final t = Curves.easeInOutCubic.transform(anim.value);
            return Transform.scale(
              scale: dir == HeroFlightDirection.push
                  ? (0.9 + t * 0.1)
                  : (1.0 - t * 0.1),
              child: to.widget,
            );
          },
          child: _BlinkAura(
            enabled: readyCount > 0, // more obvious blink when READY/COLLECT
            color: accent,
            child: _ChipSurface(
              accent: accent,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown, // status + icon scale together
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: const Color(0xFFE8EAED)),
                      const SizedBox(width: 6),
                      Text(
                        compactValue, // status only
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFE8EAED),
                          fontSize: 12, // base, scales down if needed
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      if (readyCount > 0) ...[
                        const SizedBox(width: 8),
                        _PingDot(color: accent),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPopup(BuildContext context) {
    HapticFeedback.selectionClick();
    showGeneralDialog(
      context: context,
      useRootNavigator: true,
      barrierLabel: 'kpi',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      pageBuilder: (_, __, ___) => _KpiPopup(
        heroTag: heroTag,
        icon: icon,
        label: label,
        status: compactValue, // status only in header
        details: details,
        accent: accent,
        readyCount: readyCount,
        onOpen: onOpen,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final t = Curves.easeOutCubic.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8 * t, sigmaY: 8 * t),
          child: Opacity(opacity: t, child: child),
        );
      },
    );
  }
}

class _KpiPopup extends StatelessWidget {
  final String heroTag;
  final IconData icon;
  final String label;
  final String status; // status only in header
  final List<String> details;
  final Color accent;
  final int readyCount;
  final VoidCallback? onOpen;

  const _KpiPopup({
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.status,
    required this.details,
    required this.accent,
    required this.readyCount,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottom + 16),
          child: Hero(
            tag: heroTag,
            child: Material(
              color: Colors.transparent,
              child: _GlassPanel(
                accent: accent,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _IconBadge(icon: icon, accent: accent, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFB6C0CC),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    status, // status only (no fractions)
                                    style: const TextStyle(
                                      color: Color(0xFFE8EAED),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (readyCount > 0)
                                    _ReadyDot(
                                      accent: accent,
                                      count: readyCount,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(context, rootNavigator: true).pop(),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 22,
                            color: Color(0xFFB6C0CC),
                          ),
                          splashRadius: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final d in details)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                d,
                                style: const TextStyle(
                                  color: Color(0xFFE8EAED),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (onOpen != null)
                          Expanded(
                            child: _GlassButton(
                              label: 'Open',
                              accent: accent,
                              onTap: () {
                                Navigator.of(
                                  context,
                                  rootNavigator: true,
                                ).pop();
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  onOpen?.call();
                                });
                              },
                            ),
                          ),
                        if (onOpen != null) const SizedBox(width: 10),
                        Expanded(
                          child: _GlassButton(
                            label: 'Close',
                            onTap: () => Navigator.of(
                              context,
                              rootNavigator: true,
                            ).pop(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stronger, more obvious blink aura (shadow + animated border + slight scale)
class _BlinkAura extends StatefulWidget {
  final bool enabled;
  final Color color;
  final Widget child;
  const _BlinkAura({
    required this.enabled,
    required this.color,
    required this.child,
  });

  @override
  State<_BlinkAura> createState() => _BlinkAuraState();
}

class _BlinkAuraState extends State<_BlinkAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _BlinkAura oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled) {
      _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 0.0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = widget.enabled ? _c.value : 0.0; // 0..1
        final glow = 0.55 + 0.45 * t; // stronger glow 0.55..1.0
        final scale = widget.enabled
            ? (1.0 + 0.02 * math.sin(t * 2 * math.pi))
            : 1.0;

        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.color.withOpacity(0.35 + 0.35 * glow),
                width: 1.0 + 0.6 * glow,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.50 * glow),
                  blurRadius: 16 + 24 * glow,
                  spreadRadius: 1.0 + 0.5 * glow,
                ),
              ],
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _ChipSurface extends StatelessWidget {
  final Color accent;
  final Widget child;
  const _ChipSurface({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.55)),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.16), blurRadius: 12)],
      ),
      child: child,
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final double size;
  const _IconBadge({required this.icon, required this.accent, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [accent.withOpacity(0.5), Colors.transparent],
        ),
        border: Border.all(color: accent.withOpacity(0.55)),
      ),
      child: Icon(icon, size: size * 0.57, color: const Color(0xFFE8EAED)),
    );
  }
}

class _ReadyDot extends StatefulWidget {
  final Color accent;
  final int count;
  const _ReadyDot({required this.accent, required this.count});

  @override
  State<_ReadyDot> createState() => _ReadyDotState();
}

class _ReadyDotState extends State<_ReadyDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final glow = 0.5 + _c.value * 0.5;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: widget.accent.withOpacity(0.65)),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withOpacity(0.25 * glow),
                blurRadius: 10 + 6 * glow,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.accent.withOpacity(0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Ready ${widget.count}',
                style: const TextStyle(
                  color: Color(0xFFE8EAED),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small pulsing ping dot used in collapsed view when readyCount > 0.
class _PingDot extends StatefulWidget {
  final Color color;
  const _PingDot({required this.color});

  @override
  State<_PingDot> createState() => _PingDotState();
}

class _PingDotState extends State<_PingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value; // 0..1
          return Stack(
            alignment: Alignment.center,
            children: [
              // expanding ring
              Transform.scale(
                scale: 1.0 + 0.8 * t,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withOpacity((1.0 - t) * 0.8),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              // solid center
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.7),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Color accent;
  final Widget child;
  const _GlassPanel({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withOpacity(0.35), width: 1),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? accent;
  const _GlassButton({required this.label, required this.onTap, this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(accent != null ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: (accent ?? Colors.white).withOpacity(
              accent != null ? 0.6 : 0.25,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFE8EAED),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
