import 'package:alchemons/models/battle_arenas.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/battle/battle_arena_preview.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';

/// A battle arena for sale, in the realm cards' frame: its floor, moving,
/// its name and one plain line, then its price or OWNED.
class BattleArenaShopCard extends StatelessWidget {
  const BattleArenaShopCard({
    super.key,
    required this.arena,
    required this.theme,
    required this.owned,
    required this.costWidgets,
    required this.live,
    required this.onTap,
  });

  final BattleArena arena;
  final FactionTheme theme;
  final bool owned;
  final List<Widget> costWidgets;

  /// Whether its floor moves (its tab is open and nothing is over it).
  final bool live;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = BracketPalette.fromTheme(theme);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        foregroundPainter: BracketFramePainter(
          color: palette.line.withValues(alpha: 0.9),
          bracketSize: 11,
        ),
        child: Container(
          color: palette.surfaceFill(),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: BattleArenaPreview(arena: arena.id, live: live),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arena.title.toUpperCase(),
                      style: bracketText(
                        context,
                        15,
                        palette.ink,
                        weight: FontWeight.w800,
                      ).copyWith(letterSpacing: 2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      arena.line,
                      style: bracketText(
                        context,
                        12,
                        palette.muted,
                      ).copyWith(height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: palette.lineSoft),
              Container(
                height: 36,
                color: palette.chromeFill(darkAlpha: 0.7),
                alignment: Alignment.center,
                child: owned
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.check_rounded,
                            size: 14,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'OWNED',
                            style: bracketText(
                              context,
                              10,
                              palette.muted,
                              weight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < costWidgets.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            costWidgets[i],
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
