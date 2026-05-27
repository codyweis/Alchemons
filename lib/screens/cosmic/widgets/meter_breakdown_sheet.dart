import 'dart:math' as math;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

import 'cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';

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
  // Cosmic overlay is always dark.
  static const _palette = BracketPalette.dark;
  static const _accent = CosmicScreenStyles.teal;

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
    final full = fillPct >= 1.0;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(top: 112),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.72,
        ),
        child: CustomPaint(
          painter: BracketFramePainter(
            color: (full ? const Color(0xFFE4C16A) : _accent)
                .withValues(alpha: 0.85),
            bracketSize: 14,
            strokeWidth: 1.4,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _palette.surfaceFill(),
              border: Border(
                top: BorderSide(
                  color: (full ? const Color(0xFFE4C16A) : _accent)
                      .withValues(alpha: 0.85),
                  width: 2,
                ),
              ),
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
                    color: _palette.lineSoft,
                  ),
                  const SizedBox(height: 14),
                  // ── Header ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 3, height: 30, color: _accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Alchemical meter',
                              style: bracketText(
                                context,
                                16,
                                _palette.ink,
                                weight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${total.toStringAsFixed(1)} / '
                              '${ElementMeter.maxCapacity.toStringAsFixed(0)} '
                              'stored  •  ${capacityLeft.toStringAsFixed(1)} free',
                              style: bracketText(
                                context,
                                11.5,
                                _palette.muted,
                                weight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _PctBadge(fillPct: fillPct, full: full),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _CompactMeterBar(sorted: sorted, fillPct: fillPct),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Row(
                      children: [
                        Text(
                          '${sorted.length} element'
                          '${sorted.length == 1 ? '' : 's'} loaded',
                          style: bracketText(
                            context,
                            11,
                            _palette.muted,
                            weight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        if (sorted.isNotEmpty)
                          Text(
                            'Tap × to vent an element',
                            style: bracketText(
                              context,
                              11,
                              _palette.muted,
                              weight: FontWeight.w500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (sorted.isEmpty)
                    const _EmptyMeterState()
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
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
        ),
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  const _PctBadge({required this.fillPct, required this.full});

  final double fillPct;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final color = full ? const Color(0xFFE4C16A) : CosmicScreenStyles.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Text(
        '${(fillPct * 100).round()}%',
        style: bracketText(
          context,
          14,
          color,
          weight: FontWeight.w800,
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
    const palette = BracketPalette.dark;
    return CustomPaint(
      painter: BracketFramePainter(
        color: palette.line.withValues(alpha: 0.7),
        bracketSize: 6,
        strokeWidth: 1.05,
      ),
      child: SizedBox(
        height: 22,
        child: sorted.isEmpty
            ? Container(
                color: palette.surfaceMutedFill(),
                alignment: Alignment.center,
                child: Text(
                  'Empty vessel',
                  style: bracketText(
                    context,
                    11,
                    palette.muted,
                    weight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: palette.bg0),
                  ),
                  Row(
                    children: sorted.map((entry) {
                      final pct = (entry.value / ElementMeter.maxCapacity)
                          .clamp(0.0, 1.0);
                      return Expanded(
                        flex: math.max(1, (pct * 1000).round()),
                        child: ColoredBox(color: elementColor(entry.key)),
                      );
                    }).toList(),
                  ),
                  Center(
                    child: Text(
                      fillPct >= 1.0
                          ? 'FULL'
                          : '${(fillPct * 100).round()}% capacity',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
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
    const palette = BracketPalette.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border(left: BorderSide(color: color, width: 2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  element[0].toUpperCase() + element.substring(1),
                  style: bracketText(
                    context,
                    13,
                    palette.ink,
                    weight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Text(
                amount.toStringAsFixed(1),
                style: bracketText(
                  context,
                  14,
                  palette.ink,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: CustomPaint(
                  painter: BracketFramePainter(
                    color: const Color(0xFFC0392B).withValues(alpha: 0.75),
                    bracketSize: 5,
                    strokeWidth: 1,
                  ),
                  child: Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    color: const Color(0xFFC0392B).withValues(alpha: 0.14),
                    child: const Icon(
                      AppIcons.close_rounded,
                      color: Color(0xFFE08C8C),
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 5,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(color: palette.lineSoft),
                      ),
                      FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pctOfCapacity,
                        child: ColoredBox(color: color),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(pctOfMeter * 100).round()}%',
                style: bracketText(
                  context,
                  11,
                  palette.muted,
                  weight: FontWeight.w700,
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
    const palette = BracketPalette.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: palette.bg0.withValues(alpha: 0.55),
        border: Border(
          left: BorderSide(color: CosmicScreenStyles.teal, width: 2),
        ),
      ),
      child: Text(
        'No essence stored yet.',
        textAlign: TextAlign.center,
        style: bracketText(
          context,
          12,
          palette.muted,
          weight: FontWeight.w500,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
