import 'dart:math' as math;
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/instance_purity_util.dart';
import 'package:alchemons/widgets/creature_detail/detail_helper_widgets.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

// If you created CreatureFamily/ElementalGroup helpers, import them too:
// import 'package:alchemons/models/elemental_group.dart'; // for colors / names
// import 'package:alchemons/models/family.dart';

class LineageBlock extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final CreatureInstance instance;
  final Creature? creature;

  const LineageBlock({
    super.key,
    this.theme,
    required this.instance,
    this.creature,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final purity = classifyInstancePurity(instance, species: creature);
    final elementMap = purity.elementLineage;
    final familyMap = _decodeFamilyLineageMap(
      _tryGet(instance, 'familyLineageJson'),
      fallbackFamily: instance.generationDepth == 0
          ? creature?.mutationFamily
          : null,
    );

    final (purityIcon, purityColor) = switch (purity.label) {
      'Pure' => (Icons.verified_rounded, Colors.green),
      'Elementally Pure' => (Icons.water_drop, Colors.cyan),
      'Species Pure' => (Icons.pets_rounded, Colors.amber),
      _ => (Icons.hub_rounded, Colors.orange),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledInlineValue(
          label: 'Generation',
          valueText: generationLabel(instance.generationDepth),
          valueColor: theme?.text ?? fc.textPrimary,
        ),
        LabeledInlineValue(
          label: 'Origin',
          valueText: founderSourceLabel(instance.source),
          valueColor: theme?.text ?? fc.textPrimary,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 6),
          child: Text(
            instance.generationDepth == 0
                ? 'Founders start the line, but purity is tracked separately from generation.'
                : 'Purity reflects the recorded ancestry of this line, not just its generation.',
            style: ft.body.copyWith(fontSize: 10, height: 1.3),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 100, child: Text('LINEAGE', style: ft.label)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(purityIcon, size: 12, color: purityColor),
                        const SizedBox(width: 6),
                        Text(
                          purity.label,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: purityColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      purity.description,
                      style: ft.body.copyWith(fontSize: 10, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        if (elementMap.isNotEmpty) ...[
          _SectionHeader('Element Ancestry'),
          const SizedBox(height: 6),
          _LineageRow(
            data: elementMap,
            colorOf: BreedConstants.getTypeColor,
            subtitleHint: 'by primary element',
          ),
          const SizedBox(height: 12),
        ],

        if (familyMap.isNotEmpty) ...[
          _SectionHeader('Species Lineage'),
          const SizedBox(height: 6),
          _LineageRow(
            data: familyMap,
            colorOf: FamilyColors.of,
            labelOf: FamilyColors.label,
            subtitleHint:
                'Let / Horn / Kin / Mane / Mask / Pip / Wing / Mystic',
          ),
        ],
      ],
    );
  }

  // Drift generates fields on CreatureInstance; this helper is only for
  // transitional builds where new columns may not exist on the class yet.
  static String? _tryGet(CreatureInstance inst, String fieldName) {
    try {
      final m = inst.toJson(); // drift data classes support toJson()
      final v = m[fieldName];
      return v is String ? v : null;
    } catch (_) {
      return null;
    }
  }

  // Family-only decoder that normalizes to 3-letter codes (LET/WNG/…)
  static Map<String, int> _decodeFamilyLineageMap(
    String? raw, {
    String? fallbackFamily,
  }) {
    final parsed = decodePurityLineage(raw, fallbackKey: fallbackFamily);
    final out = <String, int>{};
    parsed.forEach((k, v) {
      final code = FamilyColors.code(k);
      out[code] = (out[code] ?? 0) + v;
    });
    return out;
  }
}

/// ─────────────────────────────────────────────────────────
/// Reusable lineage row: donut + legend
/// ─────────────────────────────────────────────────────────
class _LineageRow extends StatelessWidget {
  final Map<String, int> data;
  final Color Function(String key) colorOf;
  final String Function(String key)? labelOf; // NEW
  final String? subtitleHint;

  const _LineageRow({
    required this.data,
    required this.colorOf,
    this.labelOf,
    this.subtitleHint,
  });

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<int>(0, (a, b) => a + b);
    if (total <= 0) return const SizedBox.shrink();
    final items = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    String label(String k) => labelOf?.call(k) ?? k;

    return Row(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: _DonutChart(
            slices: [
              for (final e in items)
                _Slice(
                  label: label(e.key),
                  value: e.value.toDouble(),
                  color: colorOf(e.key),
                ),
            ],
            strokeWidth: 14,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            runSpacing: 6,
            spacing: 12,
            children: [
              for (final e in items)
                _LegendItem(
                  color: colorOf(e.key),
                  label: label(e.key),
                  pct: (e.value / total) * 100.0,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Donut chart painter (no deps)
class _DonutChart extends StatelessWidget {
  final List<_Slice> slices;
  final double strokeWidth;

  const _DonutChart({required this.slices, this.strokeWidth = 12});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DonutPainter(slices: slices, strokeWidth: strokeWidth),
    );
  }
}

class _Slice {
  final String label;
  final double value;
  final Color color;
  const _Slice({required this.label, required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_Slice> slices;
  final double strokeWidth;

  _DonutPainter({required this.slices, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2;
    final center = rect.center;

    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;

    // background track
    final bgPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = Colors.black.withValues(alpha: 0.06)
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // arcs
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double start = -math.pi / 2; // 12 o'clock
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = (s.value / total) * 2 * math.pi;
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Legend chip
class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double pct;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.pct,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final pctText = '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $pctText',
          style: TextStyle(
            fontFamily: 'monospace',
            color: fc.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;

  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
      child: Text(text.toUpperCase(), style: ft.sectionTitle),
    );
  }
}

// ignore: unused_element
class _FactionTile extends StatelessWidget {
  final String name;
  final int count;
  final Color color;

  const _FactionTile({
    required this.name,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              fontFamily: 'monospace',
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: fc.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
