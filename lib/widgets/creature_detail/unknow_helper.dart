// ============================================================================
// UNKNOWN TAB
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';

class UnknownScrollArea extends StatelessWidget {
  final FactionTheme theme;
  const UnknownScrollArea({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.15)),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: Colors.white.withOpacity(.4),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Unknown Specimen',
              style: TextStyle(
                color: theme.text,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Specimen data unavailable\nContinue research to unlock analysis',
              style: TextStyle(
                color: theme.text.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
