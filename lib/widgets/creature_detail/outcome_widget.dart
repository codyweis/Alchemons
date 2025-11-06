// ============================================================================
// Outcome Badge
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class OutcomeBadge extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const OutcomeBadge({required this.theme, required this.report});
  @override
  Widget build(BuildContext context) {
    final outcomeCategory = report['outcomeCategory'] as String? ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),

      child: Text(
        outcomeCategory,
        style: TextStyle(
          color: _outcomeColor(outcomeCategory),
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  static Color _outcomeColor(String category) {
    switch (category) {
      case 'Expected':
        return Colors.green;
      case 'Somewhat Unexpected':
        return Colors.lightBlue;
      case 'Surprising':
        return Colors.orange;
      case 'Rare':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}

// ============================================================================
// Outcome Explanation
// ============================================================================

class OutcomeExplanation extends StatelessWidget {
  final FactionTheme theme;
  final Map<String, dynamic> report;

  const OutcomeExplanation({required this.theme, required this.report});

  @override
  Widget build(BuildContext context) {
    final explanation = report['outcomeExplanation'] as String? ?? '';

    if (explanation.isEmpty) return const SizedBox.shrink();

    return Text(
      explanation,
      style: TextStyle(color: theme.text, fontSize: 11, height: 1.4),
    );
  }
}
