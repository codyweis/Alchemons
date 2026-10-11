// lib/games/cosmic_survival/components/survival_mastery_strip.dart
//
// The lobby's MASTERY section, under the team: every family's mastery points
// and how far they are toward that family's next node, so what a run earns
// is in sight where the run is chosen. Two rows of four plain ink cells; the
// families in the team are lit from below, since those are the ones the run
// will pay. A tap opens Base Command on that family's tree.
//
// Static between runs: it rebuilds when the points do, and paints nothing on
// its own.

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart'
    show PanelSectionHeader, panelFmt, panelLabel, panelPalette;
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart' show BracketFramePainter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurvivalMasteryStrip extends StatelessWidget {
  const SurvivalMasteryStrip({
    super.key,
    required this.teamFamilies,
    required this.onOpen,
  });

  /// The families in the team the run will take: lit.
  final Set<CreatureFamily> teamFamilies;

  /// A family tapped: its tree, in Base Command.
  final ValueChanged<CreatureFamily> onOpen;

  static const _perRow = 4;

  @override
  Widget build(BuildContext context) {
    final mastery = context.watch<FamilyMasteryService>();
    const families = CreatureFamily.values;
    return Column(
      key: const ValueKey('survival.mastery'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelSectionHeader('MASTERY'),
        for (var row = 0; row * _perRow < families.length; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var i = row * _perRow; i < (row + 1) * _perRow; i++) ...[
                if (i > row * _perRow) const SizedBox(width: 6),
                Expanded(
                  child: i < families.length
                      ? _MasteryCell(
                          family: families[i],
                          points: mastery.pointsFor(families[i]),
                          next: familyMasteryNextNode(
                            families[i],
                            owned: mastery.purchasedNodes(families[i]),
                            selectedPathId: mastery.selectedPathForFamily(
                              families[i],
                            ),
                          ),
                          inTeam: teamFamilies.contains(families[i]),
                          onTap: () => onOpen(families[i]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

/// One family: its name, its points against the price of its next node, and
/// a thin bar of how far there.
class _MasteryCell extends StatelessWidget {
  const _MasteryCell({
    required this.family,
    required this.points,
    required this.next,
    required this.inTeam,
    required this.onTap,
  });

  final CreatureFamily family;
  final int points;

  /// The node it is working toward; null once its tree is all bought.
  final FamilyMasteryNodeDef? next;
  final bool inTeam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = family.color;
    final next = this.next;
    final fraction = next == null
        ? 1.0
        : (points / next.cost).clamp(0.0, 1.0).toDouble();
    final ready = next != null && points >= next.cost;
    final name = family.displayName.toUpperCase();
    return Semantics(
      button: true,
      label: next == null
          ? '${family.displayName} mastery, $points points, all bought'
          : '${family.displayName} mastery, $points of ${next.cost} points',
      child: GestureDetector(
        key: ValueKey('survival.mastery.${family.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(onTap),
        child: CustomPaint(
          foregroundPainter: inTeam
              ? BracketFramePainter(color: color.withValues(alpha: 0.8))
              : null,
          child: Container(
            color: inTeam
                ? Color.lerp(panelPalette.bg1, color, 0.07)
                : panelPalette.bg1.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    maxLines: 1,
                    style: panelLabel(
                      9.5,
                      inTeam ? color : color.withValues(alpha: 0.75),
                      spacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: panelFmt(points),
                          style: panelLabel(
                            14,
                            ready ? color : panelPalette.ink,
                            spacing: 0.4,
                          ),
                        ),
                        TextSpan(
                          text: next == null
                              ? '  DONE'
                              : ' / ${panelFmt(next.cost)}',
                          style: panelLabel(
                            10,
                            panelPalette.muted,
                            spacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    key: ValueKey('survival.mastery.${family.name}.points'),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 3,
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _ProgressBar(fraction, color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends CustomPainter {
  const _ProgressBar(this.fraction, this.color);

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = panelPalette.lineSoft);
    if (fraction <= 0) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * fraction, size.height),
      Paint()..color = color.withValues(alpha: fraction >= 1 ? 0.95 : 0.7),
    );
  }

  @override
  bool shouldRepaint(_ProgressBar old) =>
      old.fraction != fraction || old.color != color;
}
