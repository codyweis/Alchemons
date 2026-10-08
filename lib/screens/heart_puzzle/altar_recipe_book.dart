// lib/screens/heart_puzzle/altar_recipe_book.dart
//
// ALCHEMY's book is the game's own encyclopedia (the author, 2026-10-08:
// "we already have an encyclopedia, should we reuse that?"). The mode opens
// only once every formula in it is found, so it is always complete here,
// and its element formulas name each pair's main result — what the circles
// make. Element levels open it straight away.
//
// Families are the one thing it cannot say: it shows breeding's odds, and
// Alchemy fuses by one fixed rule (the likeliest NEW family), which differs
// from breeding's likeliest for a few pairs (Let + Let). So a species level
// opens this sheet first: Alchemy's family table, and the way on to the
// encyclopedia.

import 'package:alchemons/games/heart_puzzle/heart_puzzle_rules.dart';
import 'package:alchemons/screens/alchemical_encyclopedia_screen.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showAltarRecipeBook(BuildContext context, AltarLevel level) {
  if (!level.species) return _openEncyclopedia(context);
  final t = ForgeTokens(context.read<FactionTheme>());
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.bg1,
    isScrollControlled: true,
    builder: (sheet) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .62,
      maxChildSize: .92,
      builder: (context, scroll) => _Families(
        t: t,
        scroll: scroll,
        onEncyclopedia: () {
          Navigator.of(sheet).pop();
          _openEncyclopedia(context);
        },
      ),
    ),
  );
}

Future<void> _openEncyclopedia(BuildContext context) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => const AlchemicalEncyclopediaScreen()),
    );

class _Families extends StatelessWidget {
  const _Families({
    required this.t,
    required this.scroll,
    required this.onEncyclopedia,
  });
  final ForgeTokens t;
  final ScrollController scroll;
  final VoidCallback onEncyclopedia;

  @override
  Widget build(BuildContext context) {
    final mono = TextStyle(
      fontFamily: 'monospace',
      fontSize: 11,
      letterSpacing: 1.4,
      color: t.textSecondary,
    );
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: t.borderMid,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text('FAMILIES IN ALCHEMY', style: mono),
        const SizedBox(height: 8),
        for (final r
            in (kTopNewFamily.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key))))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${r.key.replaceAll('+', ' + ')}  →  ${r.value}',
              style: TextStyle(color: t.textPrimary, fontSize: 13.5),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 18),
          child: Text(
            'Two of the same family stay that family. An element freed from '
            'above comes down as a $kBaseFamily.',
            style: TextStyle(color: t.textSecondary, fontSize: 12.5),
          ),
        ),
        TextButton(
          onPressed: onEncyclopedia,
          style: TextButton.styleFrom(
            foregroundColor: t.amberBright,
            backgroundColor: t.amber.withValues(alpha: .12),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            'ELEMENTS · OPEN THE ENCYCLOPEDIA',
            style: mono.copyWith(color: t.amberBright),
          ),
        ),
      ],
    );
  }
}
