import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:flutter/material.dart';

import 'cosmic_panel_kit.dart' show panelLabel, panelPalette;
import 'star_chart_art.dart';

/// The raid's ember: the badge's frame, its word, its closing clock.
const Color kRaidEmber = Color(0xFFE25544);

/// Space-view raid alert, parked under the radar: the overrun planet's orb in
/// its crimson storm, and the time left beneath it. Nothing else.
///
/// It was a 150-pt plate of dark glass (word, planet name, clock) that sat
/// over the top-left of space, hiding whatever flew under it and taking its
/// taps. Now it is no wider than the map button above it and has no plate:
/// the orb and the clock stand on the space itself, shadowed to stay legible.
///
/// Tap it for the planet's name and the raid's level beside the orb; tap again
/// to put them away.
class RaidBadge extends StatefulWidget {
  const RaidBadge({
    super.key,
    required this.raid,
    required this.now,
    this.width = 44,
  });

  final RaidState raid;
  final DateTime now;

  /// The column it stands in: the map affordance above it, so the orb sits
  /// centred under that.
  final double width;

  @override
  State<RaidBadge> createState() => _RaidBadgeState();
}

class _RaidBadgeState extends State<RaidBadge> {
  bool _named = false;

  static const _shadow = [Shadow(color: Colors.black, blurRadius: 5)];

  @override
  Widget build(BuildContext context) {
    final raid = widget.raid;
    final now = widget.now;
    final coolingDown = raid.isCoolingDown(now);
    final left = coolingDown ? raid.respawnRemaining(now) : raid.remaining(now);
    String two(int v) => v.toString().padLeft(2, '0');
    // The placard's own units, short enough for the column.
    final clock = left.inHours > 0
        ? '${left.inHours}H ${two(left.inMinutes % 60)}M'
        : '${two(left.inMinutes)}M ${two(left.inSeconds % 60)}S';
    final closing = !coolingDown && left.inMinutes < 60;
    final planet = elementColor(raid.element);

    final column = SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CustomPaint(
              painter: ChartSymbolPainter(
                (c, at, s) => paintRaidGlyph(c, at, s, planet),
                tag: raid.element,
              ),
            ),
          ),
          Text(
            clock,
            maxLines: 1,
            softWrap: false,
            style: panelLabel(
              9,
              closing ? kRaidEmber : panelPalette.ink.withValues(alpha: 0.8),
              spacing: 0.4,
            ).copyWith(shadows: _shadow),
          ),
        ],
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _named = !_named),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          column,
          if (_named)
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    planetName(raid.element).toUpperCase(),
                    style: panelLabel(
                      10.5,
                      panelPalette.ink,
                      spacing: 1.2,
                    ).copyWith(shadows: _shadow),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    coolingDown
                        ? 'ECHO · L${raid.level}'
                        : 'RAID · L${raid.level}',
                    style: panelLabel(
                      8.5,
                      kRaidEmber,
                      spacing: 1.8,
                    ).copyWith(shadows: _shadow),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
