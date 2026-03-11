// ============================================================================
// Outcome Badge — Scorched Forge style
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

class OutcomeBadge extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final Map<String, dynamic> report;

  const OutcomeBadge({super.key, this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final outcomeCategory = report['outcomeCategory'] as String? ?? 'Unknown';
    final color = _outcomeColor(outcomeCategory, fc);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 0.8),
      ),
      child: Text(
        outcomeCategory.toUpperCase(),
        style: TextStyle(
          fontFamily: 'monospace',
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Color _outcomeColor(String category, FC fc) {
    switch (category) {
      case 'Expected':
        return fc.success;
      case 'Somewhat Unexpected':
        return fc.teal;
      case 'Surprising':
        return fc.amber;
      case 'Rare':
        return FC.purple;
      default:
        return fc.textSecondary;
    }
  }
}

// ============================================================================
// Outcome Explanation
// ============================================================================

class OutcomeExplanation extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  final Map<String, dynamic> report;

  const OutcomeExplanation({super.key, this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    final explanation = report['outcomeExplanation'] as String? ?? '';
    if (explanation.isEmpty) return const SizedBox.shrink();

    return Text(
      explanation,
      style: ft.body.copyWith(fontSize: 11, height: 1.4),
    );
  }
}
