// lib/screens/friends/friend_best_run.dart
//
// Friends' best Survival runs (survival_best_run.dart): a line under each
// planet on FRIENDS — "W23 · 48.2K" — with the player's own beside the
// list ("YOUR BEST"); and on a friend's page, the run itself: its wave and
// score, when, and the team it took in. No trophy: the Trials keep theirs.
// Nothing at all for a friend whose best could not be read.

import 'package:alchemons/games/cosmic_survival/survival_best_run.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/friend_service.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const _palette = BracketPalette.dark;

TextStyle _mono(double size, Color color, {double spacing = 1.4}) => TextStyle(
  fontFamily: 'monospace',
  color: color,
  fontSize: size,
  fontWeight: FontWeight.w800,
  letterSpacing: spacing,
  height: 1.2,
);

/// "W23 · 48.2K" under a friend's planet. [keep] holds the line's height
/// empty for a friend without one, so the tiles stay one height.
class BestRunLine extends StatelessWidget {
  const BestRunLine({super.key, required this.run, this.keep = false});

  final SurvivalBestRun? run;
  final bool keep;

  static const double _height = 14;

  @override
  Widget build(BuildContext context) {
    final run = this.run;
    if (run == null) {
      return keep ? const SizedBox(height: _height) : const SizedBox.shrink();
    }
    return SizedBox(
      height: _height,
      child: Text(
        run.figures,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        textAlign: TextAlign.center,
        style: _mono(9.5, _palette.muted, spacing: 0.6),
      ),
    );
  }
}

/// "YOUR BEST" over the player's own figures, beside FRIENDS: what their
/// friends' lines are set against.
class MyBestRun extends StatelessWidget {
  const MyBestRun({super.key, required this.run});

  final SurvivalBestRun run;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text('YOUR BEST', style: _mono(9, _palette.muted, spacing: 1.6)),
      const SizedBox(height: 3),
      Text(run.figures, style: _mono(12, _palette.ink, spacing: 0.8)),
    ],
  );
}

/// BEST SURVIVAL RUN on a friend's page: the wave and score, when, and the
/// team as five small portraits. Nothing for a friend without one.
class FriendBestRunBlock extends StatelessWidget {
  const FriendBestRunBlock({super.key, required this.friend, this.now});

  final FriendCard friend;

  /// For "3 days ago"; the clock when null.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final run = friend.survival;
    if (run == null) return const SizedBox.shrink();
    final catalog = context.read<CreatureCatalog>();
    final team = [
      for (final id in run.team)
        if (catalog.getCreatureById(id) case final c?) c,
    ];
    final at = run.at;
    final ago = at == null ? null : agoLabel(at, now ?? DateTime.now());
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'BEST SURVIVAL RUN',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: _mono(9.5, _palette.muted, spacing: 1.8),
              ),
              const SizedBox(height: 4),
              Text(
                run.figures,
                maxLines: 1,
                style: _mono(15, _palette.ink, spacing: 1),
              ),
              if (ago != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${ago[0].toUpperCase()}${ago.substring(1)}',
                  style: bracketText(context, 11, _palette.muted),
                ),
              ],
            ],
          ),
        ),
        for (final (i, c) in team.indexed) ...[
          if (i > 0) const SizedBox(width: 4),
          _Portrait(image: c.image, name: c.name),
        ],
      ],
    );
  }
}

/// One of the team, still, in a well of ink.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.image, required this.name});

  final String image;
  final String name;

  static const double size = 30;

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    image: true,
    child: Container(
      width: size,
      height: size,
      color: _palette.bg0.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(2),
      child: Image.asset(
        'assets/images/$image',
        fit: BoxFit.contain,
        cacheHeight: 96,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => const SizedBox(),
      ),
    ),
  );
}
