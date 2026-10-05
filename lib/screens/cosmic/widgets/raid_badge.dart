import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart' show panelLabel, panelPalette;
import 'star_chart_art.dart';

/// The raid's ember: the badge's frame, its word, its closing clock.
const Color kRaidEmber = Color(0xFFE25544);

/// Space-view raid alert, parked under the radar: which planet is overrun —
/// drawn as that planet's orb in a crimson storm — and how long remains.
///
/// It used to be a full-width strip banded into the top HUD, which made the
/// HUD grow and pushed everything below it around. As a badge it costs the
/// layout nothing, and it collapses away with the rest of the HUD chrome.
///
/// Tap it to shrink it to the orb and the clock; tap again to expand.
class RaidBadge extends StatefulWidget {
  const RaidBadge({super.key, required this.raid, required this.now});

  final RaidState raid;
  final DateTime now;

  @override
  State<RaidBadge> createState() => _RaidBadgeState();
}

class _RaidBadgeState extends State<RaidBadge> {
  bool _compact = false;

  @override
  Widget build(BuildContext context) {
    final raid = widget.raid;
    final now = widget.now;
    final coolingDown = raid.isCoolingDown(now);
    final left = coolingDown ? raid.respawnRemaining(now) : raid.remaining(now);
    String two(int v) => v.toString().padLeft(2, '0');
    final clock =
        '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final closing = !coolingDown && left.inMinutes < 60;
    final planet = elementColor(raid.element);

    final glyph = SizedBox(
      width: _compact ? 30 : 40,
      height: _compact ? 30 : 40,
      child: CustomPaint(
        painter: ChartSymbolPainter(
          (c, at, s) => paintRaidGlyph(c, at, s, planet),
          tag: raid.element,
        ),
      ),
    );
    final clockText = Text(
      clock,
      style: panelLabel(
        _compact ? 10 : 11,
        closing ? kRaidEmber : panelPalette.muted,
        spacing: 0.8,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _compact = !_compact),
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: kRaidEmber.withValues(alpha: 0.85),
          bracketSize: 7,
          strokeWidth: 1.15,
        ),
        child: Container(
          padding: _compact
              ? const EdgeInsets.fromLTRB(4, 4, 8, 4)
              : const EdgeInsets.fromLTRB(4, 6, 10, 6),
          color: panelPalette.bg0.withValues(alpha: 0.88),
          child: _compact
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [glyph, const SizedBox(width: 5), clockText],
                )
              : SizedBox(
                  width: 136,
                  child: Row(
                    children: [
                      glyph,
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              coolingDown
                                  ? 'ECHO · L${raid.level}'
                                  : 'RAID · L${raid.level}',
                              style: panelLabel(8.5, kRaidEmber, spacing: 1.8),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              planetName(raid.element).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: panelLabel(
                                10.5,
                                panelPalette.ink,
                                spacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            clockText,
                          ],
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
