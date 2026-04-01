import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/faction_util.dart';

class TopHud extends StatefulWidget {
  const TopHud({
    super.key,
    required this.theme,
    required this.meter,
    required this.meterPulse,
    required this.discoveryPct,
    required this.planetsFound,
    required this.planetsTotal,
    required this.dustCount,
    required this.wallet,
    required this.onSettings,
    required this.onMiniMap,
    required this.onMeterTap,
    this.showMeter = true,
    this.collapsed = false,
    this.onCollapsedChanged,
  });

  final FactionTheme theme;
  final ElementMeter meter;
  final AnimationController meterPulse;
  final double discoveryPct;
  final int planetsFound;
  final int planetsTotal;
  final int dustCount;
  final ShipWallet wallet;
  final VoidCallback onSettings;
  final VoidCallback onMiniMap;
  final VoidCallback onMeterTap;
  final bool showMeter;
  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<TopHud> createState() => TopHudState();
}

class TopHudState extends State<TopHud> {
  late bool _collapsed;

  @override
  void initState() {
    super.initState();
    _collapsed = widget.collapsed;
  }

  @override
  void didUpdateWidget(covariant TopHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed &&
        widget.collapsed != _collapsed) {
      _collapsed = widget.collapsed;
    }
  }

  void _setCollapsed(bool value) {
    if (_collapsed == value) return;
    setState(() => _collapsed = value);
    widget.onCollapsedChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 6, 12, 0),
          child: GestureDetector(
            onTap: () => _setCollapsed(false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xEA060B18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.settings_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'COSMOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.35),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        decoration: BoxDecoration(
          color: const Color(0xEA060B18),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Settings button — circle
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSettings,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.7,
                      ),
                    ),
                    child: Icon(
                      Icons.settings_rounded,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 17,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Title + stats
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'COSMOS',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                          height: 1.0,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.planetsFound}/${widget.planetsTotal} planets  ·  ${(widget.discoveryPct * 100).toStringAsFixed(1)}% explored',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                // Resource chips
                if (widget.dustCount > 0) ...[
                  _ResourceChip(
                    icon: Icons.auto_awesome,
                    iconColor: const Color(0xFFFFD54F),
                    label: '${widget.dustCount}/50',
                    labelColor: const Color(0xFFFFD54F),
                    borderColor: const Color(0xFFFFD700).withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 6),
                ],
                if (widget.wallet.shards > 0) ...[
                  _ResourceChip(
                    icon: Icons.diamond_rounded,
                    iconColor: const Color(0xFFB388FF),
                    label: '${widget.wallet.shards}',
                    labelColor: widget.wallet.shardsFull
                        ? Colors.redAccent
                        : const Color(0xFFB388FF),
                    borderColor: widget.wallet.shardsFull
                        ? Colors.redAccent.withValues(alpha: 0.35)
                        : const Color(0xFF7C4DFF).withValues(alpha: 0.25),
                  ),
                  const SizedBox(width: 6),
                ],
                // Collapse button — circle
                GestureDetector(
                  onTap: () => _setCollapsed(true),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.7,
                      ),
                    ),
                    child: Icon(
                      Icons.keyboard_arrow_up_rounded,
                      color: Colors.white.withValues(alpha: 0.35),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),

            // Alchemical meter
            if (widget.showMeter) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: widget.onMeterTap,
                child: AnimatedBuilder(
                  animation: widget.meterPulse,
                  builder: (context, child) {
                    final glow = widget.meter.isFull
                        ? widget.meterPulse.value * 0.45
                        : 0.0;
                    return Container(
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: widget.meter.isFull
                              ? Colors.amberAccent.withValues(alpha: 0.45 + glow)
                              : Colors.white.withValues(alpha: 0.07),
                          width: widget.meter.isFull ? 1.0 : 0.6,
                        ),
                        boxShadow: widget.meter.isFull
                            ? [
                                BoxShadow(
                                  color: Colors.amberAccent.withValues(
                                    alpha: 0.1 + glow * 0.18,
                                  ),
                                  blurRadius: 16,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                    );
                  },
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final breakdown = widget.meter.breakdown;
                      final total = widget.meter.total;
                      if (total <= 0) {
                        return Center(
                          child: Text(
                            'ALCHEMICAL METER',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.15),
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                        );
                      }

                      final sorted = breakdown.entries.toList()
                        ..sort((a, b) => b.value.compareTo(a.value));

                      return Stack(
                        children: [
                          Row(
                            children: sorted.map((e) {
                              final pct = e.value / ElementMeter.maxCapacity;
                              return Expanded(
                                flex: (pct * 1000).round().clamp(1, 1000),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color.lerp(
                                          elementColor(e.key),
                                          Colors.white,
                                          0.18,
                                        )!,
                                        elementColor(e.key),
                                        Color.lerp(
                                          elementColor(e.key),
                                          Colors.black,
                                          0.3,
                                        )!,
                                      ],
                                      stops: const [0.0, 0.45, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          // Specular sheen
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.22),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Label
                          Center(
                            child: Text(
                              widget.meter.isFull
                                  ? 'METER FULL — FLY TO A PLANET'
                                  : '${(widget.meter.fillPct * 100).toStringAsFixed(0)}%  ALCHEMICAL',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                  Shadow(color: Colors.black, blurRadius: 2),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Reusable resource chip ──────────────────────────────
class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 11),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// METER BREAKDOWN SHEET
// ─────────────────────────────────────────────────────────
