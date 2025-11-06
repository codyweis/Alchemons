import 'dart:convert';
import 'dart:math' as math;
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/utils/color_util.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/detail_helper_widgets.dart';
import 'package:flutter/material.dart';

// If you created CreatureFamily/ElementalGroup helpers, import them too:
// import 'package:alchemons/models/elemental_group.dart'; // for colors / names
// import 'package:alchemons/models/family.dart';

class LineageBlock extends StatelessWidget {
  final FactionTheme theme;
  final CreatureInstance instance;

  const LineageBlock({super.key, required this.theme, required this.instance});

  @override
  Widget build(BuildContext context) {
    final genDepth = instance.generationDepth;
    final isPure = instance.isPure == true;

    if (genDepth == 0) {
      return Text(
        'This is a first generation Alchemon.',
        style: TextStyle(color: theme.textMuted, fontSize: 11, height: 1.3),
      );
    }

    final purityLabel = isPure ? 'Elementally Pure' : 'Cross-faction Lineage';
    final purityColor = isPure ? Colors.green : Colors.orange;
    final purityDesc = isPure
        ? 'All recorded ancestors share the same elemental lineage.'
        : 'Ancestry includes multiple elemental factions.';

    // Decode maps from the instance (new columns, may be null for old saves)
    // Decode maps from the instance (new columns, may be null for old saves)
    final Map<String, int> factionMap = _decodeLineageMapGeneric(
      instance.factionLineageJson,
    );
    final Map<String, int> elementMap = _decodeLineageMapGeneric(
      _tryGet(instance, 'elementLineageJson'),
    );
    final Map<String, int> familyMap = _decodeFamilyLineageMap(
      _tryGet(instance, 'familyLineageJson'),
    );
    // If your instance type already exposes elementLineageJson/familyLineageJson,
    // replace _tryGet(...) with instance.elementLineageJson / instance.familyLineageJson.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Generation
        LabeledInlineValue(
          label: 'Generation',
          valueText: genDepth.toString(),
          valueColor: theme.text,
        ),

        // Purity descriptor
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  'Lineage',
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPure
                              ? Icons.water_drop
                              : Icons.local_fire_department,
                          size: 12,
                          color: purityColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          purityLabel,
                          style: TextStyle(
                            color: purityColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      purityDesc,
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        if (elementMap.isNotEmpty) ...[
          _SectionHeader('Element Ancestry', theme.text),
          const SizedBox(height: 6),
          _LineageRow(
            data: elementMap,
            colorOf: BreedConstants.getTypeColor,
            subtitleHint: 'by primary element',
          ),
          const SizedBox(height: 12),
        ],

        if (familyMap.isNotEmpty) ...[
          _SectionHeader('Family Ancestry', theme.text),
          const SizedBox(height: 6),
          _LineageRow(
            data: familyMap,
            colorOf: FamilyColors.of, // ← colors for families
            labelOf: FamilyColors.label, // ← pretty labels ('Let', 'Wing', …)
            subtitleHint:
                'Let / Horn / Kin / Mane / Mask / Pip / Wing / Mystic',
          ),
        ],
        // Simple stat tile: total number of factions represented
        if (factionMap.isNotEmpty) ...[
          _SectionHeader('Factions Present', theme.text),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: factionMap.entries.map((e) {
              final name =
                  e.key; // replace with FactionUtil.getName(e.key) if available
              final count = e.value;
              final color = FactionColors.of(e.key);
              return _FactionTile(name: name, count: count, color: color);
            }).toList(),
          ),
          const SizedBox(height: 12),
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

  // Generic decoder for maps like faction/element lineage (no normalization)
  static Map<String, int> _decodeLineageMapGeneric(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final m = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      );
      m.removeWhere((_, v) => v <= 0);
      return Map<String, int>.from(m);
    } catch (_) {
      return {};
    }
  }

  // Family-only decoder that normalizes to 3-letter codes (LET/WNG/…)
  static Map<String, int> _decodeFamilyLineageMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final mm = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      )..removeWhere((_, v) => v <= 0);

      final out = <String, int>{};
      mm.forEach((k, v) {
        final code = FamilyColors.code(k); // normalize to 'LET','WNG',…
        out[code] = (out[code] ?? 0) + v;
      });
      return out;
    } catch (_) {
      return {};
    }
  }

  static Map<String, int> _decodeLineageMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final mm = (jsonDecode(raw) as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      )..removeWhere((_, v) => v <= 0);

      final out = <String, int>{};
      mm.forEach((k, v) {
        final code = FamilyColors.code(k); // ← normalize to 'LET','WNG',…
        out[code] = (out[code] ?? 0) + v;
      });
      return out;
    } catch (_) {
      return {};
    }
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
    String _label(String k) => labelOf?.call(k) ?? k;

    return Row(
      children: [
        SizedBox(
          width: 84,
          height: 84,
          child: _DonutChart(
            slices: [
              for (final e in items)
                _Slice(
                  label: _label(e.key),
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
                  label: _label(e.key),
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
      ..color = Colors.black.withOpacity(0.06)
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
    final pctText = '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          '$label · $pctText',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionHeader(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            name,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              color: Colors.white.withOpacity(.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
