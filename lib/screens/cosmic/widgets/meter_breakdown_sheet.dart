import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:flutter/material.dart';

class MeterBreakdownSheet extends StatefulWidget {
  const MeterBreakdownSheet({
    super.key,
    required this.meter,
    required this.onRemove,
  });

  final ElementMeter meter;
  final ValueChanged<String> onRemove;

  @override
  State<MeterBreakdownSheet> createState() => MeterBreakdownSheetState();
}

class MeterBreakdownSheetState extends State<MeterBreakdownSheet> {
  @override
  Widget build(BuildContext context) {
    final breakdown = widget.meter.breakdown;
    final total = widget.meter.total;
    final fillPct = widget.meter.fillPct.clamp(0.0, 1.0);
    final capacityLeft = (ElementMeter.maxCapacity - total).clamp(
      0.0,
      ElementMeter.maxCapacity,
    );
    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 112),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF111933), Color(0xFF0A1023)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            14 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ALCHEMICAL METER',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${total.toStringAsFixed(1)} / ${ElementMeter.maxCapacity.toStringAsFixed(0)} stored  •  ${capacityLeft.toStringAsFixed(1)} free',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.46),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: fillPct >= 1.0
                            ? Colors.amberAccent.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${(fillPct * 100).round()}%',
                      style: TextStyle(
                        color: fillPct >= 1.0
                            ? Colors.amberAccent
                            : Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CompactMeterBar(sorted: sorted, fillPct: fillPct),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${sorted.length} element${sorted.length == 1 ? '' : 's'} loaded',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Tap to vent a full element',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.34),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                const _EmptyMeterState()
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = sorted[index];
                      final pctOfMeter = total > 0
                          ? (entry.value / total).clamp(0.0, 1.0)
                          : 0.0;
                      final pctOfCapacity =
                          (entry.value / ElementMeter.maxCapacity).clamp(
                            0.0,
                            1.0,
                          );

                      return _ElementRow(
                        element: entry.key,
                        amount: entry.value,
                        color: elementColor(entry.key),
                        pctOfMeter: pctOfMeter,
                        pctOfCapacity: pctOfCapacity,
                        onRemove: () {
                          widget.onRemove(entry.key);
                          setState(() {});
                          if (widget.meter.total <= 0) {
                            Navigator.of(context).pop();
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMeterBar extends StatelessWidget {
  const _CompactMeterBar({required this.sorted, required this.fillPct});

  final List<MapEntry<String, double>> sorted;
  final double fillPct;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: sorted.isEmpty
            ? Center(
                child: Text(
                  'EMPTY VESSEL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              )
            : Stack(
                children: [
                  Row(
                    children: sorted.map((entry) {
                      final pct = (entry.value / ElementMeter.maxCapacity)
                          .clamp(0.0, 1.0);
                      return Expanded(
                        flex: math.max(1, (pct * 1000).round()),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color.lerp(
                                  elementColor(entry.key),
                                  Colors.white,
                                  0.18,
                                )!,
                                elementColor(entry.key),
                                Color.lerp(
                                  elementColor(entry.key),
                                  Colors.black,
                                  0.22,
                                )!,
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 5,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.24),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      fillPct >= 1.0
                          ? 'FULL'
                          : '${(fillPct * 100).round()}% CAPACITY',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ElementRow extends StatelessWidget {
  const _ElementRow({
    required this.element,
    required this.amount,
    required this.color,
    required this.pctOfMeter,
    required this.pctOfCapacity,
    required this.onRemove,
  });

  final String element;
  final double amount;
  final Color color;
  final double pctOfMeter;
  final double pctOfCapacity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            Colors.white.withValues(alpha: 0.03),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  element.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
              ),
              Text(
                amount.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFF8C8C).withValues(alpha: 0.20),
                      width: 0.8,
                    ),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFFF8C8C),
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 7,
                    color: Colors.white.withValues(alpha: 0.06),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: pctOfCapacity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.lerp(color, Colors.white, 0.15)!,
                                color,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(pctOfMeter * 100).round()}%',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyMeterState extends StatelessWidget {
  const _EmptyMeterState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Text(
        'No essence stored yet.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.42),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
