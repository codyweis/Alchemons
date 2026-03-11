// ============================================================================
// UNKNOWN TAB — Scorched Forge style
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

class UnknownScrollArea extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  const UnknownScrollArea({super.key, this.theme});

  @override
  Widget build(BuildContext context) {
    final fc = FC.of(context);
    final ft = FT(fc);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: fc.bg3,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: fc.borderAccent, width: 1),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: fc.amberDim,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'UNKNOWN SPECIMEN',
              style: ft.heading.copyWith(color: fc.amberBright),
            ),
            const SizedBox(height: 8),
            Text(
              'Specimen data unavailable.\nContinue research to unlock analysis.',
              style: ft.body.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
