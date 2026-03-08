import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/utils/faction_util.dart';

class MeterBreakdownSheet extends StatefulWidget {
  const MeterBreakdownSheet({required this.meter, required this.onRemove});

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

    final sorted = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'ALCHEMICAL METER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${total.toStringAsFixed(1)} / ${ElementMeter.maxCapacity.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 16),

          // Element list
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No elements collected',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...sorted.map((e) {
              final color = elementColor(e.key);
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    // Color indicator
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Element name
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Amount & percentage
                    Text(
                      '${e.value.toStringAsFixed(1)}  (${pct.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Remove button
                    GestureDetector(
                      onTap: () {
                        widget.onRemove(e.key);
                        setState(() {});
                        // Close if meter is now empty
                        if (widget.meter.total <= 0) {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// MINI-MAP OVERLAY
// ─────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────
// MAP MARKERS
// ─────────────────────────────────────────────────────────
