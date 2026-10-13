// lib/screens/friends/friend_trials.dart
//
// A friend's Trials on their planet page (the author, 2026-10-12: "keep
// fastest times records, and then we can show them on our home planet
// friends area"; picked: their trophy, and a sheet of records set against
// the player's own): a row with the best cup they have reached and how many
// cups they have won, and — tapped — every race and bout with their best
// beside the player's, the better one lit.

import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/models/friend_home.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/stadium_trophy.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg1 = Color(0xFF131316);

/// The cup a player's Trials show: the furthest gem cup they have won a bout
/// of, else the race cup they are racing for.
TrophyLook trialsTopCup(RaceProgress progress) {
  for (var g = kGemCups.length - 1; g >= 0; g--) {
    if (progress.wonInGem(kGemCups[g]) > 0) {
      return TrophyLook.ofGem(g, progress);
    }
  }
  return TrophyLook.ofCup(TrophyLook.currentCup(progress), progress);
}

/// How many of the six cups [progress] has won.
int trialsCupsWon(RaceProgress progress) => [
  for (final c in kRaceCups) progress.cupDone(c),
  for (final c in kGemCups) progress.gemDone(c),
].where((d) => d).length;

/// A friend's Trials, as a row on their page: their cup, the cups won, and
/// RECORDS. Nothing for a friend who has not raced.
class FriendTrialsRow extends StatelessWidget {
  const FriendTrialsRow({super.key, required this.friend});

  final FriendCard friend;

  @override
  Widget build(BuildContext context) {
    final trials = friend.trials;
    if (trials == null) return const SizedBox.shrink();
    final progress = RaceProgress(trials.won);
    final won = trialsCupsWon(progress);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          showFriendTrials(context, friend);
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StadiumTrophyEmblem(
              height: 30,
              look: trialsTopCup(progress),
              animate: false,
            ),
            const SizedBox(width: 10),
            Text(
              won == 0
                  ? 'THE TRIALS'
                  : 'THE TRIALS · $won ${won == 1 ? 'CUP' : 'CUPS'}',
              style: bracketText(
                context,
                10.5,
                _ink.withValues(alpha: 0.85),
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'RECORDS',
              style: bracketText(
                context,
                10.5,
                _brass,
                weight: FontWeight.w800,
                letterSpacing: 1.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Every race and bout, their best beside the player's.
Future<void> showFriendTrials(BuildContext context, FriendCard friend) async {
  final mine = await TrialsRecords.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: _bg1,
    isScrollControlled: true,
    builder: (_) => _RecordsSheet(friend: friend, mine: mine),
  );
}

class _RecordsSheet extends StatelessWidget {
  const _RecordsSheet({required this.friend, required this.mine});

  final FriendCard friend;
  final TrialsRecords mine;

  @override
  Widget build(BuildContext context) {
    final theirs = friend.trials?.best ?? const {};
    final rows = <Widget>[];
    String? cup;
    for (final e in kTrialsEvents) {
      if (e.cupId != cup) {
        cup = e.cupId;
        rows.add(_cupHeader(context, e.cupId));
      }
      rows.add(_row(context, e, theirs[e.id], mine.best[e.id]?.value));
    }
    final h = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: h * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'RECORDS',
                style: bracketText(
                  context,
                  15,
                  _brassHot,
                  weight: FontWeight.w800,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'THE TRIALS · ${friend.name.toUpperCase()} AND YOU',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bracketText(
                  context,
                  9.5,
                  _muted,
                  weight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Spacer(),
                  _head(context, friend.name.toUpperCase()),
                  _head(context, 'YOU'),
                ],
              ),
              const SizedBox(height: 4),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: rows,
                ),
              ),
              const SizedBox(height: 10),
              BracketButton(
                label: 'CLOSE',
                palette: BracketPalette.dark,
                accent: _brass,
                primary: false,
                height: 40,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _col = 84;

  Widget _head(BuildContext context, String text) => SizedBox(
    width: _col,
    child: Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: bracketText(
        context,
        9,
        _muted,
        weight: FontWeight.w800,
        letterSpacing: 1.4,
      ),
    ),
  );

  Widget _cupHeader(BuildContext context, String cupId) {
    final name = [
      for (final c in kRaceCups)
        if (c.id == cupId) c.name,
      for (final c in kGemCups)
        if (c.id == cupId) c.name,
    ].firstOrNull;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        (name ?? cupId).toUpperCase(),
        style: bracketText(
          context,
          9.5,
          _brass,
          weight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      ),
    );
  }

  /// One race or bout: its name, their best, the player's — the better of
  /// the two lit.
  Widget _row(BuildContext context, TrialsEvent e, int? theirs, int? mine) {
    final theirsBetter =
        theirs != null && (mine == null || e.better(theirs, mine));
    final mineBetter =
        mine != null && (theirs == null || e.better(mine, theirs));
    String show(int? v) => v == null
        ? '—'
        : (e.mark == TrialsMark.stars ? '${e.show(v)} STARS' : e.show(v));
    Widget cell(int? v, bool lit) => SizedBox(
      width: _col,
      child: Text(
        show(v),
        textAlign: TextAlign.right,
        style: bracketText(
          context,
          12,
          lit ? _brassHot : (v == null ? _muted : _ink.withValues(alpha: 0.7)),
          weight: lit ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              e.name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                11,
                _ink,
                weight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          cell(theirs, theirsBetter),
          cell(mine, mineBetter),
        ],
      ),
    );
  }
}
