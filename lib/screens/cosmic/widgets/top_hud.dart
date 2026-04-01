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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => _setCollapsed(false),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white60,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row: settings + title + minimap
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSettings,
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings_rounded,
                        color: Colors.white60,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.14),
                          const Color(0xFF0C1733).withValues(alpha: 0.78),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.7,
                      ),
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.45,
                          shadows: const [
                            Shadow(color: Colors.black87, blurRadius: 8),
                            Shadow(color: Colors.black54, blurRadius: 2),
                          ],
                        ),
                        children: [
                          TextSpan(
                            text:
                                '${widget.planetsFound}/${widget.planetsTotal} PLANETS',
                          ),
                          TextSpan(
                            text: '  ·  ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.58),
                            ),
                          ),
                          TextSpan(
                            text:
                                '${(widget.discoveryPct * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Color(0xFFD7F6FF),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.dustCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFFFD54F).withValues(alpha: 0.12),
                        const Color(0xFFFFD54F).withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: Color(0xFFFFD54F),
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.dustCount}/50',
                        style: const TextStyle(
                          color: Color(0xFFFFD54F),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.dustCount > 0) const SizedBox(width: 6),
              // Shard badge
              if (widget.wallet.shards > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFFB388FF).withValues(alpha: 0.12),
                        const Color(0xFFB388FF).withValues(alpha: 0.04),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: widget.wallet.shardsFull
                          ? Colors.redAccent.withValues(alpha: 0.4)
                          : const Color(0xFF7C4DFF).withValues(alpha: 0.2),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.diamond_rounded,
                        color: Color(0xFFB388FF),
                        size: 10,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.wallet.shards}',
                        style: TextStyle(
                          color: widget.wallet.shardsFull
                              ? Colors.redAccent
                              : const Color(0xFFB388FF),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              if (widget.wallet.shards > 0) const SizedBox(width: 6),
              // Collapse arrow
              GestureDetector(
                onTap: () => _setCollapsed(true),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x1FFFFFFF), Color(0x0AFFFFFF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 0.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white60,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 6),

          // Element meter bar
          if (widget.showMeter)
            GestureDetector(
              onTap: widget.onMeterTap,
              child: AnimatedBuilder(
                animation: widget.meterPulse,
                builder: (context, child) {
                  final glow = widget.meter.isFull
                      ? widget.meterPulse.value * 0.4
                      : 0.0;
                  return Container(
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.07),
                          Colors.white.withValues(alpha: 0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.meter.isFull
                            ? Colors.amberAccent.withValues(alpha: 0.4 + glow)
                            : Colors.white.withValues(alpha: 0.06),
                        width: widget.meter.isFull ? 1.0 : 0.5,
                      ),
                      boxShadow: widget.meter.isFull
                          ? [
                              BoxShadow(
                                color: Colors.amberAccent.withValues(
                                  alpha: 0.12 + glow * 0.2,
                                ),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: child,
                    ),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final breakdown = widget.meter.breakdown;
                    final total = widget.meter.total;
                    if (total <= 0) {
                      return Container(
                        alignment: Alignment.center,
                        child: Text(
                          'ALCHEMICAL METER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.18),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    }

                    // Build segmented meter bar
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
                                        0.2,
                                      )!,
                                      elementColor(e.key),
                                      Color.lerp(
                                        elementColor(e.key),
                                        Colors.black,
                                        0.25,
                                      )!,
                                    ],
                                    stops: const [0.0, 0.4, 1.0],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        // Specular highlight
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.3),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Fill percentage label
                        Center(
                          child: Text(
                            widget.meter.isFull
                                ? 'METER FULL — FLY TO A PLANET'
                                : '${(widget.meter.fillPct * 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              shadows: const [
                                Shadow(color: Colors.black, blurRadius: 6),
                                Shadow(color: Colors.black, blurRadius: 3),
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
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// METER BREAKDOWN SHEET
// ─────────────────────────────────────────────────────────
