// lib/screens/heart_puzzle/altar_recipe_book.dart
//
// ALCHEMY's book is the game's own encyclopedia (the author, 2026-10-08:
// "we already have an encyclopedia, should we reuse that?"). It shows only
// the formulas the player has found, here as everywhere (the author,
// 2026-11-13, once the mode opened on one formula for each element and no
// longer on all of them: "only found ones in game still show"); what a
// pair not yet found makes is learned by trying it on a circle, which costs
// nothing with UNDO. Element levels open it straight away.
//
// Families are the one thing it cannot say: it shows breeding's odds, and
// Alchemy fuses by one fixed rule (the likeliest NEW family), which differs
// from breeding's likeliest for a few pairs (Let + Let). So a species level
// opens this panel first: Alchemy's family table, and the way on to the
// encyclopedia. The table is the mode's own rule, so all of it is shown.

import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/screens/heart_puzzle/altar_stage_art.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

Future<void> showAltarRecipeBook(BuildContext context, AltarLevel level) async {
  if (!level.species) return _openEncyclopedia(context);
  final encyclopedia = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .7),
    builder: (ctx) => const _Families(),
  );
  if (encyclopedia == true && context.mounted) await _openEncyclopedia(context);
}

Future<void> _openEncyclopedia(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );

/// Alchemy's family table, in the game's own panel (it was a Material
/// bottom sheet): the pairs in two columns, the two rules that need no
/// table, and the way on to the encyclopedia for the elements.
class _Families extends StatelessWidget {
  const _Families();

  @override
  Widget build(BuildContext context) {
    const palette = BracketPalette.dark;
    final rows = kTopNewFamily.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final half = (rows.length + 1) ~/ 2;
    Widget row(MapEntry<String, String> r) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: r.key.replaceAll('+', ' + ')),
            TextSpan(
              text: '  →  ',
              style: TextStyle(color: palette.muted),
            ),
            TextSpan(
              text: r.value,
              style: const TextStyle(
                color: kAltarBrass,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        style: TextStyle(color: palette.ink, fontSize: 12.5),
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: kAltarBrass.withValues(alpha: .9),
          bracketSize: 14,
          strokeWidth: 1.3,
        ),
        child: Container(
          color: palette.bg1,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'FAMILIES IN ALCHEMY',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: palette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final r in rows.take(half)) row(r)],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [for (final r in rows.skip(half)) row(r)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Two of the same family stay that family. An element freed '
                  'from above comes down as a $kBaseFamily.',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: BracketButton(
                        label: 'CLOSE',
                        primary: false,
                        height: 42,
                        palette: palette,
                        accent: kAltarBrass,
                        onTap: () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: BracketButton(
                        label: 'ENCYCLOPEDIA',
                        height: 42,
                        palette: palette,
                        accent: kAltarBrass,
                        onTap: () => Navigator.of(context).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
