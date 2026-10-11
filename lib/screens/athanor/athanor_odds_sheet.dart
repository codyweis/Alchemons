// lib/screens/athanor/athanor_odds_sheet.dart
//
// The odds of the NEXT pour into a batch: every piece still left and its
// chance, grouped by rarity, and the capstone, which is not drawn but comes
// with the last piece. The chances are exactly the list the service rolls
// on (AthanorService.nextPourOdds); nothing here works them out again.

import 'package:alchemons/models/athanor.dart';
import 'package:alchemons/screens/athanor/athanor_piece_art.dart';
import 'package:alchemons/screens/athanor/athanor_tone.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:flutter/material.dart';

Future<void> showAthanorOdds(
  BuildContext context, {
  required AthanorBatch batch,
  required List<(AthanorPiece, double)> odds,
  required bool capstoneGiven,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: AthanorTone.palette.bg1,
  barrierColor: Colors.black.withValues(alpha: 0.6),
  shape: const RoundedRectangleBorder(),
  builder: (ctx) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
    child: AthanorOddsSheet(
      batch: batch,
      odds: odds,
      capstoneGiven: capstoneGiven,
      onClose: () => Navigator.of(ctx).pop(),
    ),
  ),
);

class AthanorOddsSheet extends StatelessWidget {
  const AthanorOddsSheet({
    super.key,
    required this.batch,
    required this.odds,
    required this.capstoneGiven,
    this.onClose,
  });

  final AthanorBatch batch;

  /// The next pour's odds, as the service gives them.
  final List<(AthanorPiece, double)> odds;
  final bool capstoneGiven;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final groups = [
      for (final r in AthanorRarity.values.reversed)
        (
          r,
          [
            for (final o in odds)
              if (o.$1.rarity == r) o,
          ],
        ),
    ].where((g) => g.$2.isNotEmpty).toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 20, 22, 14 + pad.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ODDS  ·  NEXT POUR',
            style: athanorMono(10.5, AthanorTone.brass, spacing: 2.4),
          ),
          const SizedBox(height: 6),
          Text(batch.name, style: athanorName(context, 22)),
          const SizedBox(height: 8),
          Text(
            odds.isEmpty
                ? 'Every piece in this batch is owned.'
                : "Every pour gives a piece you don't own yet.",
            style: athanorBody(context, color: AthanorTone.parchment),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (rarity, rows) in groups) ...[
                    _GroupHead(
                      label: rarity.label,
                      count: rows.length,
                      color: AthanorTone.rarity(rarity),
                    ),
                    for (final (piece, chance) in rows)
                      _Row(
                        piece: piece,
                        trailing: Text(
                          athanorPercent(chance),
                          style: athanorMono(
                            13,
                            AthanorTone.rarity(rarity),
                            spacing: 0.6,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                  ],
                  _GroupHead(label: 'CAPSTONE', color: AthanorTone.capstone),
                  _Row(
                    piece: batch.capstone,
                    look: capstoneGiven
                        ? AthanorPieceLook.lit
                        : AthanorPieceLook.sealed,
                    note: capstoneGiven
                        ? 'Owned.'
                        : 'Comes with the last piece.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          BracketButton(
            label: 'CLOSE',
            primary: false,
            height: 42,
            palette: AthanorTone.palette,
            accent: AthanorTone.brass,
            onTap: onClose ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

class _GroupHead extends StatelessWidget {
  const _GroupHead({required this.label, required this.color, this.count});

  final String label;
  final Color color;
  final int? count;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, bottom: 4),
    child: Row(
      children: [
        Text(label, style: athanorMono(10, color, spacing: 2.2)),
        if (count != null) ...[
          const SizedBox(width: 8),
          Text(
            '$count LEFT',
            style: athanorMono(9.5, AthanorTone.muted, spacing: 1.6),
          ),
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.piece,
    this.trailing,
    this.note,
    this.look = AthanorPieceLook.lit,
  });

  final AthanorPiece piece;
  final Widget? trailing;
  final String? note;
  final AthanorPieceLook look;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 38,
          child: AthanorPieceArt(piece: piece, look: look),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                piece.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: athanorName(context, 15),
              ),
              if (note != null)
                Text(note!, style: athanorBody(context, size: 12)),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
