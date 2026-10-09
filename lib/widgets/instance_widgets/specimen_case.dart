// lib/widgets/instance_widgets/specimen_case.dart
//
// A specimen in the Creatures tab and in the picker that slides up whenever
// one is wanted (all_specimens_page.dart): standing in a dark glass case,
// lit from behind in its element, with one engraved line beneath (element
// mark, name, stamina). The case light is the extraction card's stage light, scaled down,
// and it is static — the sprite is the only thing in a case that moves.

import 'dart:math' as math;

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/daos/creature_dao.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/parent_snapshot.dart' show decodeGenetics;
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/utils/genetics_util.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart' show mutationAccent;
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// What a case prints in its top-right corner: nothing, the four stats, or
/// what is unusual in the genes.
enum CaseView { plain, stats, potential, genetics }

/// Gilt: a favourite's frame, and the Codex's "new" color.
const Color kCaseGilt = Color(0xFFE4B356);

/// Ink on the dark glass, in either theme.
const Color kCaseGlassInk = Color(0xFFE8DCC8);

/// The light an element casts in a case or a catalog cell: its orb's tint.
Color elementLight(String? element) =>
    elementOrbTint(EssenceElement.of(element));

/// A species' light, by its first element.
Color caseElementLight(Creature species) =>
    elementLight(species.types.isEmpty ? null : species.types.first);

TextStyle caseMono(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w800,
  double spacing = 1.0,
}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: weight,
  letterSpacing: spacing,
  height: 1.1,
);

class SpecimenCase extends StatelessWidget {
  const SpecimenCase({
    super.key,
    required this.species,
    required this.instance,
    required this.palette,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.selectionNumber,
    this.cornerBadge,
    this.sortBy,
    this.view = CaseView.plain,
    this.showStamina = true,
  });

  final Creature species;
  final CreatureInstance instance;
  final BracketPalette palette;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final int? selectionNumber;
  final Widget? cornerBadge;

  /// When the grid is sorted by a stat, that stat's figure is engraved in
  /// the case's top corner, so the order can be read.
  final SortBy? sortBy;
  final CaseView view;

  /// The stamina ticks beside the name; the condensed grid has no room.
  final bool showStamina;

  @override
  Widget build(BuildContext context) {
    final light = caseElementLight(species);
    final stamina = context.read<StaminaService>().computeState(instance);
    final frame = isSelected
        ? kCaseGilt
        : instance.isFavorite
        ? kCaseGilt.withValues(alpha: 0.8)
        : light.withValues(alpha: 0.45);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : context.soundAction(onTap!),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: frame,
                bracketSize: 8,
                strokeWidth: isSelected ? 1.8 : 1.2,
              ),
              child: ClipRect(
                child: CustomPaint(
                  painter: CaseLightPainter(color: light),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final size = math.min(box.maxWidth, box.maxHeight) * 0.78;
                      return Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: box.maxHeight * 0.1,
                            child: Center(
                              child: RepaintBoundary(
                                child: species.spriteData != null
                                    ? InstanceSprite(
                                        creature: species,
                                        instance: instance,
                                        size: size,
                                      )
                                    : Image.asset(
                                        'assets/images/${species.image}',
                                        width: size,
                                        height: size,
                                        fit: BoxFit.contain,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 8,
                            child: Text(
                              'LV ${instance.level}',
                              style: caseMono(
                                9.5,
                                kCaseGlassInk.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          if (sortBy case final sort? when sort.isStatSort)
                            Positioned(
                              left: 8,
                              right: 8,
                              bottom: 5,
                              child: Text(
                                '${sort.shortLabel} ${_sortFigure(sort, instance)}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: caseMono(9.5, kCaseGlassInk),
                              ),
                            ),
                          if (cornerBadge != null ||
                              instance.isFavorite ||
                              selectionNumber != null ||
                              view != CaseView.plain)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                spacing: 4,
                                children: [
                                  if (cornerBadge != null) cornerBadge!,
                                  // The same star the favourite toggle lights
                                  // in the detail sheet: the gilt frame alone
                                  // was too quiet to find one by.
                                  if (instance.isFavorite)
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      child: const Icon(
                                        AppIcons.star_filled,
                                        size: 11,
                                        color: Color(0xFFE91E63),
                                      ),
                                    ),
                                  if (selectionNumber != null)
                                    Container(
                                      width: 16,
                                      height: 16,
                                      alignment: Alignment.center,
                                      color: kCaseGilt,
                                      child: Text(
                                        '$selectionNumber',
                                        style: caseMono(
                                          9.5,
                                          Colors.black,
                                          weight: FontWeight.w900,
                                          spacing: 0,
                                        ),
                                      ),
                                    ),
                                  if (view == CaseView.stats)
                                    _caseStats(instance)
                                  else if (view == CaseView.potential)
                                    _caseStats(instance, potential: true)
                                  else if (view == CaseView.genetics)
                                    _caseGenetics(
                                      instance,
                                      box.maxWidth * 0.62,
                                    ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // The engraved line.
          Row(
            children: [
              MarkDiamond(color: light, prismatic: instance.isPrismaticSkin),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  (instance.nickname?.trim().isNotEmpty == true
                          ? instance.nickname!
                          : species.name)
                      .toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: caseMono(9.5, palette.ink, spacing: 0.9),
                ),
              ),
              if (showStamina)
                StaminaTicks(
                  bars: stamina.bars,
                  max: stamina.max,
                  palette: palette,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A back glow and a pool of light on the case floor, in [color], over the
/// vials' dark glass.
class CaseLightPainter extends CustomPainter {
  const CaseLightPainter({required this.color, this.strength = 1});

  final Color color;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kVialGlass);
    final w = size.width, h = size.height;

    final back = Offset(w / 2, h * 0.46);
    final br = math.min(w, h) * 0.7;
    canvas.drawCircle(
      back,
      br,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.18 * strength),
            color.withValues(alpha: 0.05 * strength),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Rect.fromCircle(center: back, radius: br)),
    );

    final fr = w * 0.46;
    canvas.save();
    canvas.translate(w / 2, h * 0.88);
    canvas.scale(1, 0.22);
    canvas.drawCircle(
      Offset.zero,
      fr,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.5 * strength),
            color.withValues(alpha: 0.14 * strength),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: fr)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CaseLightPainter old) =>
      old.color != color || old.strength != strength;
}

/// A small element diamond, as the extraction card's marks are drawn.
/// Prismatic specimens get the rainbow.
class MarkDiamond extends StatelessWidget {
  const MarkDiamond({
    super.key,
    required this.color,
    this.prismatic = false,
    this.size = 6,
  });

  final Color color;
  final bool prismatic;
  final double size;

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: math.pi / 4,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: prismatic ? null : color,
        gradient: prismatic
            ? const SweepGradient(
                colors: [
                  Color(0xFFFF5252),
                  Color(0xFFFFD740),
                  Color(0xFF69F0AE),
                  Color(0xFF40C4FF),
                  Color(0xFFE040FB),
                  Color(0xFFFF5252),
                ],
              )
            : null,
      ),
    ),
  );
}

class StaminaTicks extends StatelessWidget {
  const StaminaTicks({
    super.key,
    required this.bars,
    required this.max,
    required this.palette,
  });

  final int bars, max;
  final BracketPalette palette;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < max; i++)
        Container(
          width: 3,
          height: 8,
          margin: const EdgeInsets.only(left: 2),
          color: i < bars
              ? const Color(0xFF4ADE80)
              : palette.line.withValues(alpha: 0.35),
        ),
    ],
  );
}

Widget _caseLine(String label, Color color, String value) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(label, style: caseMono(8.5, color, spacing: 0.4)),
    const SizedBox(width: 3),
    Text(
      value,
      style: caseMono(
        8.5,
        kCaseGlassInk.withValues(alpha: 0.9),
        weight: FontWeight.w700,
        spacing: 0.2,
      ),
    ),
  ],
);

/// The four stats as the detail cards rate them (a few hundred), or with
/// [potential] their potentials, marked P.
Widget _caseStats(CreatureInstance i, {bool potential = false}) {
  String f(double current, double pot) => potential
      ? 'P${AlchemonStatSystem.normalizePotential(pot)}'
      : '${AlchemonStatSystem.displayRating(current)}';
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    spacing: 2,
    children: [
      _caseLine(
        'SPD',
        const Color(0xFFFDE047),
        f(i.statSpeed, i.statSpeedPotential),
      ),
      _caseLine(
        'INT',
        const Color(0xFFC084FC),
        f(i.statIntelligence, i.statIntelligencePotential),
      ),
      _caseLine(
        'STR',
        const Color(0xFFF87171),
        f(i.statStrength, i.statStrengthPotential),
      ),
      _caseLine(
        'BEA',
        const Color(0xFFF9A8D4),
        f(i.statBeauty, i.statBeautyPotential),
      ),
    ],
  );
}

/// Only what deviates earns a line, as on the detail cards.
Widget _caseGenetics(CreatureInstance i, double maxWidth) {
  final genetics = decodeGenetics(i.geneticsJson);
  final size = genetics?.get('size') ?? 'normal';
  final tint = genetics?.get('tinting') ?? 'normal';
  final variant = i.variantFaction?.trim() ?? '';
  final mutation = AlchemonMutation.byId(i.mutation);
  final lines = <(String, Color)>[
    if (i.isPrismaticSkin == true) ('PRISMATIC', const Color(0xFFE040FB)),
    if (mutation != null)
      (mutation.label.toUpperCase(), mutationAccent(mutation)),
    if (variant.isNotEmpty) (variant.toUpperCase(), kCaseGilt),
    if (size != 'normal') ((sizeLabels[size] ?? size).toUpperCase(), kCaseGilt),
    if (tint != 'normal') ((tintLabels[tint] ?? tint).toUpperCase(), kCaseGilt),
    if (i.natureId?.isNotEmpty == true)
      (i.natureId!.toUpperCase(), kCaseGlassInk),
    if (i.natureId2?.isNotEmpty == true)
      (i.natureId2!.toUpperCase(), kCaseGlassInk),
  ];
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        for (final (text, color) in lines)
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: caseMono(8.5, color, spacing: 0.4),
          ),
      ],
    ),
  );
}

/// A stat sort's figure as the detail cards print it: a rating, or the
/// potential on its own scale.
String _sortFigure(SortBy sort, CreatureInstance i) {
  final v = sort.valueForInstance(i);
  return switch (sort) {
    SortBy.potentialSpeed ||
    SortBy.potentialIntelligence ||
    SortBy.potentialStrength ||
    SortBy.potentialBeauty => 'P${AlchemonStatSystem.normalizePotential(v)}',
    SortBy.combinedPotential =>
      'P${AlchemonStatSystem.normalizePotential(i.statSpeedPotential) + AlchemonStatSystem.normalizePotential(i.statIntelligencePotential) + AlchemonStatSystem.normalizePotential(i.statStrengthPotential) + AlchemonStatSystem.normalizePotential(i.statBeautyPotential)}',
    _ => '${AlchemonStatSystem.displayRating(v)}',
  };
}
