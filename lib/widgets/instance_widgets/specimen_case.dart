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
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/widgets/animations/extraction_vile_ui.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/element_orb.dart';
import 'package:alchemons/widgets/fx/elemental_essence.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
                                '${sort.shortLabel} '
                                '${sort.valueForInstance(instance).toStringAsFixed(1)}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: caseMono(9.5, kCaseGlassInk),
                              ),
                            ),
                          if (cornerBadge != null ||
                              instance.isFavorite ||
                              selectionNumber != null)
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
