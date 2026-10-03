// lib/widgets/catalog/milestone_track.dart
//
// A species' breeding milestones as one line: six stops (5 · 10 · 25 · 50 ·
// 75 · 100) evenly spaced, gilt up to the number bred, the current leg filled
// part-way and the next stop ringed in the accent. Used on the species plate
// above filtered specimens and on every row of the milestones list.

import 'package:alchemons/models/constellation/constellation_catalog.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart';
import 'package:flutter/material.dart';

/// Points a species has earned from its milestones so far.
int breedingPointsEarned(int bred, String rarity) => BreedingMilestone
    .milestones
    .where((m) => bred >= m.count)
    .fold(0, (sum, m) => sum + m.getPointsForRarity(rarity));

class MilestoneTrack extends StatelessWidget {
  const MilestoneTrack({
    super.key,
    required this.bred,
    required this.palette,
    required this.accent,
    this.labels = true,
  });

  final int bred;
  final BracketPalette palette;
  final Color accent;

  /// The stop counts beneath the line.
  final bool labels;

  /// Inset of the first and last stops, so their diamonds are not clipped and
  /// the fill has room to lead in toward the first stop.
  static const double _inset = 14;

  @override
  Widget build(BuildContext context) {
    final ms = BreedingMilestone.milestones;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 12,
          child: CustomPaint(
            painter: _TrackPainter(
              bred: bred,
              line: palette.line.withValues(alpha: 0.45),
              empty: palette.isDark ? const Color(0xFF0B0A10) : palette.bg1,
              fill: palette.isDark ? kCaseGilt : const Color(0xFFB7791F),
              next: accent,
            ),
          ),
        ),
        if (labels) ...[
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, box) {
              final span = box.maxWidth - _inset * 2;
              return SizedBox(
                height: 12,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < ms.length; i++)
                      Positioned(
                        left: _inset + span * i / (ms.length - 1) - 14,
                        width: 28,
                        child: Center(
                          child: Text(
                            '${ms[i].count}',
                            style: caseMono(
                              8,
                              bred >= ms[i].count
                                  ? (palette.isDark
                                        ? kCaseGilt
                                        : const Color(0xFF8A5A12))
                                  : palette.muted,
                              spacing: 0,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.bred,
    required this.line,
    required this.empty,
    required this.fill,
    required this.next,
  });

  final int bred;
  final Color line, empty, fill, next;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = BreedingMilestone.milestones;
    final y = size.height / 2;
    const inset = MilestoneTrack._inset;
    double xOf(int i) => inset + (size.width - inset * 2) * i / (ms.length - 1);

    final stroke = Paint()..strokeWidth = 2;
    // The rail, including a short lead-in before the first stop.
    canvas.drawLine(
      Offset(0, y),
      Offset(xOf(ms.length - 1), y),
      stroke..color = line,
    );

    var reached = -1;
    for (var i = 0; i < ms.length; i++) {
      if (bred >= ms[i].count) reached = i;
    }
    double fx;
    if (reached == ms.length - 1) {
      fx = xOf(reached);
    } else {
      final from = reached < 0 ? 0 : ms[reached].count;
      final to = ms[reached + 1].count;
      final x0 = reached < 0 ? 0.0 : xOf(reached);
      final t = ((bred - from) / (to - from)).clamp(0.0, 1.0);
      fx = x0 + (xOf(reached + 1) - x0) * t;
    }
    if (fx > 0) {
      canvas.drawLine(Offset(0, y), Offset(fx, y), stroke..color = fill);
    }

    for (var i = 0; i < ms.length; i++) {
      final c = Offset(xOf(i), y);
      final done = i <= reached;
      final isNext = i == reached + 1;
      final path = Path()
        ..moveTo(c.dx, c.dy - 5)
        ..lineTo(c.dx + 5, c.dy)
        ..lineTo(c.dx, c.dy + 5)
        ..lineTo(c.dx - 5, c.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = done ? fill : empty);
      if (!done) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isNext ? 1.6 : 1
            ..color = isNext ? next : line,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.bred != bred ||
      old.line != line ||
      old.fill != fill ||
      old.next != next ||
      old.empty != empty;
}
