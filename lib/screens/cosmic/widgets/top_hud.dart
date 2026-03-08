import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'meter_breakdown_sheet.dart';
import 'package:alchemons/utils/faction_util.dart';

class TopHud extends StatefulWidget {
  const TopHud({
    required this.theme,
    required this.meter,
    required this.meterPulse,
    required this.discoveryPct,
    required this.planetsFound,
    required this.planetsTotal,
    required this.dustCount,
    required this.wallet,
    required this.onBack,
    required this.onMiniMap,
    required this.onMeterTap,
    this.showMeter = true,
  });

  final FactionTheme theme;
  final ElementMeter meter;
  final AnimationController meterPulse;
  final double discoveryPct;
  final int planetsFound;
  final int planetsTotal;
  final int dustCount;
  final ShipWallet wallet;
  final VoidCallback onBack;
  final VoidCallback onMiniMap;
  final VoidCallback onMeterTap;
  final bool showMeter;

  @override
  State<TopHud> createState() => TopHudState();
}

class TopHudState extends State<TopHud> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    if (_collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: () => setState(() => _collapsed = false),
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
          // Row: back + title + minimap
          Row(
            children: [
              GestureDetector(
                onTap: widget.onBack,
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
                    Icons.arrow_back_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title removed per UI update
                    Text(
                      '${widget.planetsFound}/${widget.planetsTotal} planets  ·  '
                      '${(widget.discoveryPct * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
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
                onTap: () => setState(() => _collapsed = true),
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
