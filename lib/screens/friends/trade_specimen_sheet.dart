// lib/screens/friends/trade_specimen_sheet.dart
//
// An Alchemon on a trade table, in full, read only: as it stands in its
// case, its level, stats and Potential, what it is, what it wears, and where
// it came from — who has owned it included. Built from its card
// (TradedCreature), so it shows a friend's as well as one waiting on the
// table out of the player's collection.

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/celebration_costume.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/trade.dart';
import 'package:alchemons/screens/home_biome/home_biome_screen.dart'
    show hydrateResident;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_detail/creature_dialog.dart'
    show creatureDateLabel, creatureSourceLabel;
import 'package:alchemons/widgets/creature_detail/specimen_readouts.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/cosmetics/case_style_art.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:alchemons/widgets/trade/trade_origin.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

const _palette = BracketPalette.dark;

/// Shows [card] in full. [owner]: whose it is, by name; null for the
/// player's own.
Future<void> showTradeSpecimenSheet(
  BuildContext context,
  TradedCreature card, {
  String? owner,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withValues(alpha: 0.72),
  builder: (_) => TradeSpecimenSheet(card: card, owner: owner),
);

class TradeSpecimenSheet extends StatelessWidget {
  const TradeSpecimenSheet({super.key, required this.card, this.owner});

  final TradedCreature card;
  final String? owner;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CreatureCatalog>();
    final inst = card.instance;
    final species = hydrateResident(inst, catalog);
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: _palette.line.withValues(alpha: 0.9),
          bracketSize: 12,
          strokeWidth: 1.2,
        ),
        child: Container(
          color: _palette.bg1,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 18 + media.padding.bottom),
            child: species == null
                ? Text(
                    'This Alchemon could not be shown.',
                    style: bracketText(context, 13, _palette.muted),
                  )
                : _body(context, species, inst),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Creature species, CreatureInstance inst) {
    final light = caseElementLight(species);
    final name = (inst.nickname?.trim().isNotEmpty ?? false)
        ? inst.nickname!.trim()
        : species.name;
    final worn = _worn(context, inst);
    final origin = [
      '${creatureSourceLabel(inst.source)}  ·  '
          '${creatureDateLabel(inst.createdAtUtcMs)}',
      ...tradeOriginLines(card.provenance, owner: owner),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (name != species.name) species.name.toUpperCase(),
                      'LV ${inst.level}',
                      owner == null ? 'YOURS' : "${owner!.toUpperCase()}'S",
                    ].join('  ·  '),
                    style: caseMono(10, _palette.muted, spacing: 1.6),
                  ),
                ],
              ),
            ),
            BracketIconButton(
              icon: AppIcons.close_rounded,
              palette: _palette,
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1.5,
          child: CustomPaint(
            foregroundPainter: BracketFramePainter(
              color: light.withValues(alpha: 0.45),
              bracketSize: 10,
              strokeWidth: 1.2,
            ),
            child: ClipRect(
              child: CustomPaint(
                painter: card.caseStyle == null
                    ? CaseLightPainter(color: light)
                    : CaseStylePainter(style: card.caseStyle!, color: light),
                child: LayoutBuilder(
                  builder: (context, box) => Align(
                    alignment: const Alignment(0, 0.5),
                    child: InstanceSprite(
                      creature: species,
                      instance: inst,
                      size: box.maxHeight * 0.8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const BracketSectionDivider(label: 'STATS'),
        const SizedBox(height: 8),
        StatTileGrid(
          stats: statTilesFor(inst, showPotential: true, showDominants: true),
        ),
        const SizedBox(height: 14),
        const BracketSectionDivider(label: 'TRAITS'),
        const SizedBox(height: 6),
        ...specimenTraitRows(context, species, inst, natureEffects: true),
        if (worn.isNotEmpty) ...[
          const SizedBox(height: 14),
          const BracketSectionDivider(label: 'WEARS'),
          const SizedBox(height: 6),
          for (final (label, value) in worn)
            TraitRow(label: label, value: value),
        ],
        const SizedBox(height: 14),
        const BracketSectionDivider(label: 'ORIGIN'),
        const SizedBox(height: 8),
        for (final line in origin)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: caseMono(10.5, _palette.muted)),
          ),
      ],
    );
  }

  /// What it wears, by name: its effect, costumes, case and trail.
  List<(String, String)> _worn(BuildContext context, CreatureInstance inst) {
    final out = <(String, String)>[];
    final item = InvKeys.alchemyItemFor(inst.alchemyEffect);
    if (item != null) {
      final names = buildInventoryRegistry(context.read<AlchemonsDatabase>());
      out.add(('EFFECT', names[item]?.name ?? 'Alchemy effect'));
    }
    final costumes = WornCostumes.on(inst.baseId, inst.costumes);
    for (final c in FamilyCostume.values) {
      if (costumes.wears(c)) out.add(('COSTUME', c.title));
    }
    if (card.caseStyle case final s?) out.add(('CASE', s.title));
    if (card.trail case final t?) out.add(('TRAIL', t.title));
    return out;
  }
}
