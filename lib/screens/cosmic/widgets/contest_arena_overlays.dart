// lib/screens/cosmic/widgets/contest_arena_overlays.dart
//
// What lies over a trait contest while it plays out in the arena: the
// contest's name and level at the top, the arena left clear, and a scorecard
// at the foot in the station panels' bracket style — the judging written up
// a line at a time, both scores counting up as bars, the winner, what it
// earned, and CONTINUE once it is over.
//
// The four public overlays keep their constructors; each supplies its
// trait's judging lines and timing to the one scorecard.

import 'dart:math';

import 'package:alchemons/games/cosmic/contest_art.dart';
import 'package:alchemons/games/cosmic/contest_judging.dart';
import 'package:alchemons/games/cosmic/cosmic_contests.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_screen_styles.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';

/// What the judges made of both: the level's condition and every factor
/// that moved each score (contest_judging.dart). With it, the scorecard
/// shows only what really counted.
class ContestJudging {
  const ContestJudging({
    required this.condition,
    required this.player,
    required this.rival,
    required this.playerStat,
    required this.rivalStat,
  });

  final ContestCondition condition;
  final ContestVerdict player, rival;

  /// The stat each brought, as a line ("SPEED 312", "LEVEL 3 RIVAL").
  final String playerStat, rivalStat;
}

/// What a contest pays, shown with the result. All optional: without them
/// the scorecard says only who won.
class ContestStakes {
  const ContestStakes({
    required this.level,
    required this.levels,
    this.shards = 0,
    this.gold = 0,
    this.unlock,
  });

  final int level, levels;
  final int shards, gold;

  /// A mastery effect a win would unlock.
  final String? unlock;
}

// ── Beauty ──────────────────────────────────────────────────────────────────

class CosmicBeautyContestArenaOverlay extends StatelessWidget {
  const CosmicBeautyContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
    this.stakes,
    this.judging,
  });

  final ContestJudging? judging;
  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;
  final ContestStakes? stakes;

  static List<String> _lines(CosmicPartyMember m) {
    final tags = <String>[
      '${m.element} aura',
      'Beauty ${AlchemonStatSystem.displayRating(m.statBeauty)}',
    ];
    final visuals = m.spriteVisuals;
    if (visuals?.isPrismatic == true) tags.add('Prismatic shimmer');
    final fx = visuals?.alchemyEffect;
    if (fx == 'prismatic_cascade') tags.add('Prismatic cascade');
    if (fx == 'alchemy_glow' || fx == 'elemental_aura') {
      tags.add('Radiant glow');
    }
    final scale = visuals?.scale ?? 1.0;
    if (scale > 1.15) tags.add('Grand presence');
    if (scale < 0.92) tags.add('Petite grace');
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) => _ContestScorecard(
    trait: CosmicContestTrait.beauty,
    player: player,
    rival: opponentMember,
    playerScore: playerScore,
    rivalScore: opponentScore,
    playerLines: _lines(player),
    rivalLines: _lines(opponentMember),
    stakes: stakes,
    judging: judging,
    timing: _Timing.beauty,
    waiting: 'THE JUDGES CONFER',
  );
}

// ── Speed ───────────────────────────────────────────────────────────────────

class CosmicSpeedContestArenaOverlay extends StatelessWidget {
  const CosmicSpeedContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
    this.stakes,
    this.judging,
  });

  final ContestJudging? judging;
  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;
  final ContestStakes? stakes;

  static List<String> _lines(CosmicPartyMember member) {
    final tags = <String>[
      'Speed ${AlchemonStatSystem.displayRating(member.statSpeed)}',
    ];
    final element = member.element.toLowerCase().trim();
    if (element == 'lightning' ||
        element == 'water' ||
        element == 'ice' ||
        element == 'air') {
      tags.add('${member.element} pace bonus');
    } else if (element == 'earth' || element == 'mud' || element == 'poison') {
      tags.add('${member.element} drag risk');
    }
    final family = member.family.toLowerCase().trim();
    if (family == 'wing') {
      tags.add('Wingline acceleration');
    } else if (family == 'let') {
      tags.add('Quick launch frame');
    } else if (family == 'kin') {
      tags.add('Draft control');
    } else if (family == 'horn' || family == 'mane') {
      tags.add('Power build-up');
    }
    final scale = member.spriteVisuals?.scale ?? 1.0;
    if (scale < 0.92) {
      tags.add('Compact burst frame');
    } else if (scale > 1.15) {
      tags.add('Larger drag profile');
    }
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) => _ContestScorecard(
    trait: CosmicContestTrait.speed,
    player: player,
    rival: opponentMember,
    playerScore: playerScore,
    rivalScore: opponentScore,
    playerLines: _lines(player),
    rivalLines: _lines(opponentMember),
    stakes: stakes,
    judging: judging,
    timing: _Timing.bout,
    waiting: 'CHECKING THE TIMES',
  );
}

// ── Strength ────────────────────────────────────────────────────────────────

class CosmicStrengthContestArenaOverlay extends StatelessWidget {
  const CosmicStrengthContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
    this.stakes,
    this.judging,
  });

  final ContestJudging? judging;
  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;
  final ContestStakes? stakes;

  static List<String> _lines(CosmicPartyMember member) {
    final tags = <String>[
      'Strength ${AlchemonStatSystem.displayRating(member.statStrength)}',
    ];
    final element = member.element.toLowerCase().trim();
    if (element == 'earth' ||
        element == 'lava' ||
        element == 'fire' ||
        element == 'mud') {
      tags.add('${member.element} force bonus');
    } else if (element == 'air' || element == 'water') {
      tags.add('${member.element} impact penalty');
    }
    final family = member.family.toLowerCase().trim();
    if (family == 'horn') {
      tags.add('Hornline power shove');
    } else if (family == 'mane') {
      tags.add('Maneline body force');
    } else if (family == 'kin') {
      tags.add('Kin leverage control');
    }
    final scale = member.spriteVisuals?.scale ?? 1.0;
    if (scale > 1.15) {
      tags.add('Heavy frame advantage');
    } else if (scale < 0.92) {
      tags.add('Lighter mass drawback');
    }
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) => _ContestScorecard(
    trait: CosmicContestTrait.strength,
    player: player,
    rival: opponentMember,
    playerScore: playerScore,
    rivalScore: opponentScore,
    playerLines: _lines(player),
    rivalLines: _lines(opponentMember),
    stakes: stakes,
    judging: judging,
    timing: _Timing.bout,
    waiting: 'WEIGHING THE FORCE',
  );
}

// ── Intelligence ────────────────────────────────────────────────────────────

class CosmicIntelligenceContestArenaOverlay extends StatelessWidget {
  const CosmicIntelligenceContestArenaOverlay({
    super.key,
    required this.player,
    required this.opponentMember,
    required this.playerScore,
    required this.opponentScore,
    this.stakes,
    this.judging,
  });

  final ContestJudging? judging;
  final CosmicPartyMember player;
  final CosmicPartyMember opponentMember;
  final double playerScore;
  final double opponentScore;
  final ContestStakes? stakes;

  static List<String> _lines(CosmicPartyMember member) {
    final tags = <String>[
      'Intelligence ${AlchemonStatSystem.displayRating(member.statIntelligence)}',
    ];
    final element = member.element.toLowerCase().trim();
    if (element == 'spirit' ||
        element == 'light' ||
        element == 'dark' ||
        element == 'crystal') {
      tags.add('${member.element} cognition bonus');
    } else if (element == 'lava' || element == 'mud' || element == 'blood') {
      tags.add('${member.element} focus penalty');
    }
    final family = member.family.toLowerCase().trim();
    if (family == 'mask') {
      tags.add('Maskline analysis edge');
    } else if (family == 'kin') {
      tags.add('Kinline memory network');
    } else if (family == 'pip') {
      tags.add('Pipline pattern speed');
    } else if (family == 'horn' || family == 'mane') {
      tags.add('Powerline thought drag');
    }
    if (tags.length < 3) tags.add('Lineage diversity weighting');
    return tags.take(3).toList();
  }

  @override
  Widget build(BuildContext context) => _ContestScorecard(
    trait: CosmicContestTrait.intelligence,
    player: player,
    rival: opponentMember,
    playerScore: playerScore,
    rivalScore: opponentScore,
    playerLines: _lines(player),
    rivalLines: _lines(opponentMember),
    stakes: stakes,
    judging: judging,
    timing: _Timing.bout,
    waiting: 'READING THE PATTERNS',
  );
}

// ── the scorecard ───────────────────────────────────────────────────────────

/// When each part of the scorecard happens, as fractions of [total]. The
/// scores count up only once the bout in the arena is over (11 s for speed,
/// strength and intelligence; beauty's final pose is at 16.5 s).
class _Timing {
  const _Timing(
    this.total,
    this.linesFrom,
    this.linesTo,
    this.scoreFrom,
    this.scoreTo,
    this.resultFrom,
    this.doneAt,
  );

  final Duration total;
  final double linesFrom, linesTo, scoreFrom, scoreTo, resultFrom, doneAt;

  static const beauty = _Timing(
    Duration(milliseconds: 18000),
    0.1,
    0.78,
    0.8,
    0.93,
    0.93,
    0.97,
  );
  static const bout = _Timing(
    Duration(milliseconds: 14000),
    0.08,
    0.74,
    0.8,
    0.91,
    0.92,
    0.96,
  );
}

class _ContestScorecard extends StatefulWidget {
  const _ContestScorecard({
    required this.trait,
    required this.player,
    required this.rival,
    required this.playerScore,
    required this.rivalScore,
    required this.playerLines,
    required this.rivalLines,
    required this.timing,
    required this.waiting,
    this.stakes,
    this.judging,
  });

  final ContestJudging? judging;

  final CosmicContestTrait trait;
  final CosmicPartyMember player, rival;
  final double playerScore, rivalScore;
  final List<String> playerLines, rivalLines;
  final _Timing timing;
  final String waiting;
  final ContestStakes? stakes;

  @override
  State<_ContestScorecard> createState() => _ContestScorecardState();
}

class _ContestScorecardState extends State<_ContestScorecard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(
    vsync: this,
    duration: widget.timing.total,
  )..forward();

  /// The highest a contest score goes.
  static const double _scoreMax = 6.85;
  static const Color _rivalInk = Color(0xFFB9AE9E);

  bool get _won => widget.playerScore >= widget.rivalScore;

  /// The judging, alternating between the two: what each brought, then what
  /// moved their scores, most first. Each line: (yours, text, effect sign).
  late final List<(bool, String, int)> _log = () {
    final j = widget.judging;
    if (j != null) {
      final mine = [
        (true, j.playerStat, 0),
        for (final f in j.player.factors.take(3))
          (true, f.text, f.delta > 0 ? 1 : -1),
      ];
      final theirs = [
        (false, j.rivalStat, 0),
        for (final f in j.rival.factors.take(3))
          (false, f.text, f.delta > 0 ? 1 : -1),
      ];
      return [
        for (var i = 0; i < max(mine.length, theirs.length); i++) ...[
          if (i < mine.length) mine[i],
          if (i < theirs.length) theirs[i],
        ],
      ];
    }
    final out = <(bool, String, int)>[];
    final n = max(widget.playerLines.length, widget.rivalLines.length);
    for (var i = 0; i < n; i++) {
      if (i < widget.playerLines.length) {
        out.add((true, widget.playerLines[i], 0));
      }
      if (i < widget.rivalLines.length) {
        out.add((false, widget.rivalLines[i], 0));
      }
    }
    return out;
  }();

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double _phase(double from, double to) =>
      ((_t.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final accent = widget.trait.light;
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final done = _t.value >= widget.timing.doneAt;
        return PopScope(
          canPop: done,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                child: Column(
                  children: [
                    _header(accent),
                    const Spacer(),
                    _card(accent, done),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(Color accent) {
    final stakes = widget.stakes;
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.trait.arenaLabel.toUpperCase(),
            style: panelLabel(13, panelPalette.ink, spacing: 2.6),
          ),
        ),
        if (stakes != null)
          Text(
            'LEVEL ${stakes.level} OF ${stakes.levels}',
            style: panelLabel(10.5, accent, spacing: 1.6),
          ),
      ],
    );
  }

  Widget _card(Color accent, bool done) {
    final timing = widget.timing;
    final lines = _phase(timing.linesFrom, timing.linesTo);
    final score = Curves.easeOutCubic.transform(
      _phase(timing.scoreFrom, timing.scoreTo),
    );
    final result = Curves.easeOut.transform(
      _phase(timing.resultFrom, timing.doneAt),
    );
    final shown = (lines * _log.length).ceil().clamp(0, _log.length);
    double fade(int i) =>
        i < shown ? (lines * _log.length - i).clamp(0.0, 1.0) : 0.0;
    // While the bout plays the card keeps low, out of the arena's way: the
    // names and the two latest calls. It opens into the full judging once
    // the scores come in.
    final live = _t.value < timing.scoreFrom;

    return CustomPaint(
      foregroundPainter: BracketFramePainter(
        color: accent.withValues(alpha: 0.85),
        bracketSize: 12,
        strokeWidth: 1.3,
      ),
      child: Container(
        color: CosmicScreenStyles.bg1.withValues(alpha: 0.93),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: live
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _names(accent),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 2 * 18.0,
                      child: Column(
                        children: [
                          for (var i = max(0, shown - 2); i < shown; i++)
                            _logLine(_log[i], accent, fade(i)),
                        ],
                      ),
                    ),
                  ],
                )
              : _fullCard(accent, done, shown, fade, score, result),
        ),
      ),
    );
  }

  Widget _fullCard(
    Color accent,
    bool done,
    int shown,
    double Function(int) fade,
    double score,
    double result,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _names(accent),
        const SizedBox(height: 10),
        PanelSectionHeader(
          'THE JUDGING',
          trailing: widget.judging?.condition.title,
        ),
        SizedBox(
          height: 8 * 18.0,
          child: Column(
            children: [
              for (var i = 0; i < _log.length; i++)
                _logLine(_log[i], accent, fade(i)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (score <= 0)
          _waiting(accent)
        else ...[
          _bar(widget.player.displayName, widget.playerScore, score, accent),
          const SizedBox(height: 6),
          _bar(widget.rival.displayName, widget.rivalScore, score, _rivalInk),
        ],
        const SizedBox(height: 10),
        Opacity(opacity: result, child: _result(accent)),
        const SizedBox(height: 10),
        BracketButton(
          key: const ValueKey('contest.continue'),
          label: done ? 'CONTINUE' : 'IN THE ARENA…',
          icon: done ? AppIcons.check_rounded : null,
          height: 42,
          palette: panelPalette,
          accent: accent,
          enabled: done,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _names(Color accent) {
    Widget side(String name, String role, Color ink, CrossAxisAlignment a) =>
        Expanded(
          child: Column(
            crossAxisAlignment: a,
            children: [
              Text(
                name.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: panelLabel(12, ink, spacing: 1.2),
              ),
              const SizedBox(height: 3),
              Text(
                role,
                style: panelLabel(9, panelPalette.muted, spacing: 1.4),
              ),
            ],
          ),
        );
    return Row(
      children: [
        side(
          widget.player.displayName,
          'YOURS',
          accent,
          CrossAxisAlignment.start,
        ),
        Text('VS', style: panelLabel(10, panelPalette.muted, spacing: 2)),
        side(
          widget.rival.displayName,
          'THE RIVAL',
          _rivalInk,
          CrossAxisAlignment.end,
        ),
      ],
    );
  }

  Widget _logLine((bool, String, int) line, Color accent, double opacity) {
    final (mine, text, sign) = line;
    final ink = mine ? accent : _rivalInk;
    // What helped is marked up, what hurt down; the stat line is a dot.
    final mark = switch (sign) {
      1 => Text('+', style: panelLabel(12, CosmicScreenStyles.success)),
      -1 => Text('−', style: panelLabel(12, CosmicScreenStyles.danger)),
      _ => PanelDot(ink, size: 5),
    };
    final row = Row(
      mainAxisAlignment: mine ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        if (mine) ...[
          SizedBox(width: 10, child: Center(child: mark)),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: panelLabel(
              10,
              sign == 0 ? panelPalette.ink : ink.withValues(alpha: 0.9),
              spacing: 0.9,
            ),
          ),
        ),
        if (!mine) ...[
          const SizedBox(width: 6),
          SizedBox(width: 10, child: Center(child: mark)),
        ],
      ],
    );
    return SizedBox(
      height: 18,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset((mine ? -8 : 8) * (1 - opacity), 0),
          child: row,
        ),
      ),
    );
  }

  Widget _waiting(Color accent) {
    final dots = '.' * (1 + (_t.value * 40).floor() % 3);
    return SizedBox(
      height: 46,
      child: Center(
        child: Text(
          '${widget.waiting}$dots',
          style: panelLabel(10.5, panelPalette.muted, spacing: 1.8),
        ),
      ),
    );
  }

  Widget _bar(String name, double score, double count, Color ink) {
    final shown = score * count;
    return SizedBox(
      height: 20,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              name.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: panelLabel(9.5, panelPalette.muted, spacing: 0.8),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 6,
              child: CustomPaint(painter: _ScoreBar(shown / _scoreMax, ink)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              shown.toStringAsFixed(2),
              textAlign: TextAlign.right,
              style: panelLabel(11.5, panelPalette.ink, spacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _result(Color accent) {
    final stakes = widget.stakes;
    final winner = _won ? widget.player.displayName : widget.rival.displayName;
    final rewards = <Widget>[
      if (_won && stakes != null && stakes.shards > 0)
        ShardAmount(stakes.shards, size: 11),
      if (_won && stakes != null && stakes.gold > 0)
        CoinAmount(kind: CoinKind.gold, amount: stakes.gold, size: 11),
    ];
    return Column(
      children: [
        Text(
          '${winner.toUpperCase()} WINS',
          textAlign: TextAlign.center,
          style: panelLabel(15, _won ? accent : _rivalInk, spacing: 2.2),
        ),
        const SizedBox(height: 6),
        if (!_won)
          Text(
            'No reward this time. The arena will be here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: CosmicScreenStyles.textSecondary,
              fontSize: 12.5,
            ),
          )
        else if (rewards.isNotEmpty) ...[
          Wrap(alignment: WrapAlignment.center, spacing: 14, children: rewards),
          if (stakes != null && stakes.shards > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Shards are banked at home.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: CosmicScreenStyles.textSecondary,
                fontSize: 11.5,
              ),
            ),
          ],
        ],
        if (_won && stakes?.unlock != null) ...[
          const SizedBox(height: 6),
          Text(
            '${stakes!.unlock} unlocked in the shop, and one is yours.',
            textAlign: TextAlign.center,
            style: TextStyle(color: accent, fontSize: 12.5),
          ),
        ],
      ],
    );
  }
}

/// A score as a bar of twelve cells, lit as far as it reaches.
class _ScoreBar extends CustomPainter {
  _ScoreBar(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 12;
    const gap = 2.0;
    final w = (size.width - gap * (cells - 1)) / cells;
    final dim = Paint()..color = panelPalette.lineSoft;
    final lit = Paint();
    final f = fraction.clamp(0.0, 1.0);
    for (var i = 0; i < cells; i++) {
      final x = i * (w + gap);
      canvas.drawRect(Rect.fromLTWH(x, 0, w, size.height), dim);
      final fill = (f * cells - i).clamp(0.0, 1.0);
      if (fill > 0) {
        lit.color = color.withValues(alpha: 0.55 + 0.45 * fill);
        canvas.drawRect(Rect.fromLTWH(x, 0, w * fill, size.height), lit);
      }
    }
  }

  @override
  bool shouldRepaint(_ScoreBar old) =>
      old.fraction != fraction || old.color != color;
}
