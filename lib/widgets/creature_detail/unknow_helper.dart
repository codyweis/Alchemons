// ============================================================================
// UNKNOWN TAB — Scorched Forge style
// ============================================================================

import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/creature_detail/forge_tokens.dart';
import 'package:flutter/material.dart';

class UnknownScrollArea extends StatelessWidget {
  // ignore: unused_field
  final FactionTheme? theme;
  const UnknownScrollArea({this.theme});

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
                color: FC.bg3,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: FC.borderAccent, width: 1),
              ),
              child: Icon(
                Icons.help_outline_rounded,
                color: FC.amberDim,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'UNKNOWN SPECIMEN',
              style: FT.heading.copyWith(color: FC.amberBright),
            ),
            const SizedBox(height: 8),
            Text(
              'Specimen data unavailable.\nContinue research to unlock analysis.',
              style: FT.body.copyWith(fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
