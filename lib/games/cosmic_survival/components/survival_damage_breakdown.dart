// lib/games/cosmic_survival/components/survival_damage_breakdown.dart
//
// The results' DAMAGE section: who carried the run. One row per party
// member, most damage first — its portrait in its element's light, its name
// and damage, its share of everything the run dealt as a glass tube of that
// light (the HUD's tube), and under it its kills, its healing if it healed,
// and its time on the field. One kept in reserve all run is a single quiet
// line, BENCHED. The run's best is lit from below in brass; the rest are
// flat ink. Damage no Alchemon dealt closes the list, so the shares add up.
//
// The rows arrive one after another as the rewards do (reward_reveal.dart):
// each fades up and settles a few pixels, and its tube fills to its share,
// eased at both ends. [SurvivalDamageBreakdownState.finish] brings them all
// in at once.

import 'dart:math' as math;

import 'package:alchemons/games/cosmic_survival/components/survival_hud.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_lobby_team.dart'
    show kSurvivalTeamCaseCacheWidth;
import 'package:alchemons/games/cosmic_survival/survival_damage_report.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show CaseLightPainter, elementLight;
import 'package:flutter/material.dart';

class SurvivalDamageBreakdown extends StatefulWidget {
  const SurvivalDamageBreakdown({
    super.key,
    required this.report,
    this.delay = Duration.zero,
  });

  final SurvivalDamageReport report;

  /// Before the first row starts to arrive.
  final Duration delay;

  /// Between one row starting to arrive and the next, in seconds.
  static const double stagger = 0.12;

  /// How long one row takes to arrive, in seconds.
  static const double arrive = 0.8;

  /// The portrait's side.
  static const double portrait = 40;

  /// How long [rows] rows take to arrive, after the delay.
  static Duration lengthFor(int rows) => Duration(
    milliseconds: (((math.max(rows, 1) - 1) * stagger + arrive) * 1000).round(),
  );

  @override
  State<SurvivalDamageBreakdown> createState() =>
      SurvivalDamageBreakdownState();
}

class SurvivalDamageBreakdownState extends State<SurvivalDamageBreakdown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _t;
  late final double _total;

  int get _rowCount =>
      widget.report.lines.length + (widget.report.otherDamage > 0 ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _total =
        widget.delay.inMilliseconds / 1000 +
        SurvivalDamageBreakdown.lengthFor(_rowCount).inMilliseconds / 1000;
    _t = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_total * 1000).round()),
    )..forward();
  }

  /// Every row in place now.
  void finish() {
    if (_t.isAnimating) _t.value = 1;
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  Animation<double> _arrival(int i) {
    final start =
        widget.delay.inMilliseconds / 1000 +
        i * SurvivalDamageBreakdown.stagger;
    return _t.drive(
      CurveTween(
        curve: Interval(
          (start / _total).clamp(0.0, 1.0),
          ((start + SurvivalDamageBreakdown.arrive) / _total).clamp(0.0, 1.0),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final best = report.best;
    final rows = <Widget>[];
    for (final (i, line) in report.lines.indexed) {
      if (i > 0) rows.add(const SizedBox(height: 5));
      rows.add(
        _Arrival(
          arrival: _arrival(i),
          builder: (fill) => line.deployed
              ? _CreatureRow(
                  line: line,
                  share: report.shareOf(line.damage),
                  fill: fill,
                  best: identical(line, best),
                )
              : _BenchedRow(line: line),
        ),
      );
    }
    if (report.otherDamage > 0) {
      rows
        ..add(const SizedBox(height: 5))
        ..add(
          _Arrival(
            arrival: _arrival(report.lines.length),
            builder: (fill) => _OtherRow(
              damage: report.otherDamage,
              kills: report.otherKills,
              share: report.shareOf(report.otherDamage),
              fill: fill,
            ),
          ),
        );
    }
    return Column(
      key: const ValueKey('survival.damage'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FadeTransition(
          opacity: _t.drive(
            CurveTween(
              curve: Interval(
                0,
                ((widget.delay.inMilliseconds / 1000 + 0.4) / _total).clamp(
                  0.0,
                  1.0,
                ),
                curve: Curves.easeOut,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'DAMAGE',
                  style: hudMono(
                    12,
                    SurvivalInk.brassBright.withValues(alpha: 0.85),
                    weight: FontWeight.w400,
                    spacing: 3,
                  ),
                ),
              ),
              Text(
                '${compactAmount(report.totalDamage)} TOTAL',
                style: hudMono(
                  10,
                  SurvivalInk.muted,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...rows,
      ],
    );
  }
}

/// One row arriving: it fades up and settles a few pixels, and [builder]
/// is handed how far its tube has filled, 0..1, eased at both ends.
class _Arrival extends StatelessWidget {
  const _Arrival({required this.arrival, required this.builder});

  final Animation<double> arrival;
  final Widget Function(double fill) builder;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: arrival,
    builder: (context, _) {
      final t = arrival.value;
      final fade = Curves.easeOut.transform((t / 0.55).clamp(0.0, 1.0));
      final settle = Curves.easeOutCubic.transform(t);
      final fill = Curves.easeInOutCubic.transform(
        ((t - 0.2) / 0.8).clamp(0.0, 1.0),
      );
      return Opacity(
        opacity: fade,
        child: Transform.translate(
          offset: Offset(0, (1 - settle) * 6),
          child: builder(fill),
        ),
      );
    },
  );
}

/// A creature that went out: portrait; its name, share and damage; its
/// share as a tube of its element's light; its kills, healing and time out.
class _CreatureRow extends StatelessWidget {
  const _CreatureRow({
    required this.line,
    required this.share,
    required this.fill,
    required this.best,
  });

  final SurvivalDamageLine line;
  final double share;
  final double fill;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final light = elementLight(line.element);
    final row = Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 10, 7),
      color: best
          ? SurvivalInk.brass.withValues(alpha: 0.09)
          : SurvivalInk.bg1.withValues(alpha: 0.8),
      child: Row(
        children: [
          _Portrait(line: line, light: light),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeadLine(
                  name: line.name,
                  nameColor: SurvivalInk.ink.withValues(alpha: 0.9),
                  share: share,
                  damage: line.damage,
                  damageColor: best ? SurvivalInk.brassGlow : SurvivalInk.ink,
                ),
                const SizedBox(height: 5),
                _Tube(fraction: share * fill, color: light),
                const SizedBox(height: 5),
                _Facts(
                  facts: [
                    _kills(line.kills),
                    if (line.healing > 0)
                      (compactAmount(line.healing), 'HEALED'),
                    (fieldClock(line.fieldSeconds), 'ON FIELD'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!best) return row;
    return CustomPaint(
      foregroundPainter: const BracketFramePainter(
        color: SurvivalInk.brass,
        strokeWidth: 1.4,
      ),
      child: row,
    );
  }
}

/// Kept in reserve the whole run: one quiet line.
class _BenchedRow extends StatelessWidget {
  const _BenchedRow({required this.line});

  final SurvivalDamageLine line;

  /// The party row's reserve grey: present, not out.
  static const _reserve = ColorFilter.matrix([
    0.16, 0.32, 0.06, 0, 0, //
    0.16, 0.32, 0.06, 0, 0, //
    0.17, 0.34, 0.07, 0, 0, //
    0, 0, 0, 0.8, 0,
  ]);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
    color: SurvivalInk.bg1.withValues(alpha: 0.5),
    child: Row(
      children: [
        SizedBox.square(
          dimension: 26,
          child: ColorFiltered(colorFilter: _reserve, child: _art(line, 26)),
        ),
        const SizedBox(width: 10 + SurvivalDamageBreakdown.portrait - 26),
        Expanded(
          child: Text(
            line.name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hudMono(
              11.5,
              SurvivalInk.muted,
              weight: FontWeight.w600,
              spacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'BENCHED',
          style: hudMono(
            10,
            SurvivalInk.muted,
            weight: FontWeight.w600,
            spacing: 1.6,
          ),
        ),
      ],
    ),
  );
}

/// What no Alchemon dealt, so the shares add up. No portrait and no fill:
/// it is not one of the party.
class _OtherRow extends StatelessWidget {
  const _OtherRow({
    required this.damage,
    required this.kills,
    required this.share,
    required this.fill,
  });

  final double damage;
  final int kills;
  final double share;
  final double fill;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      6 + SurvivalDamageBreakdown.portrait + 10,
      4,
      10,
      4,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeadLine(
          name: 'Ship and orb',
          nameColor: SurvivalInk.muted,
          share: share,
          damage: damage,
          damageColor: SurvivalInk.ink.withValues(alpha: 0.75),
        ),
        const SizedBox(height: 5),
        _Tube(fraction: share * fill, color: SurvivalInk.muted),
        if (kills > 0) ...[
          const SizedBox(height: 5),
          _Facts(facts: [_kills(kills)]),
        ],
      ],
    ),
  );
}

(String, String) _kills(int kills) => ('$kills', kills == 1 ? 'KILL' : 'KILLS');

/// A row's first line: the name, then its share and its damage.
class _HeadLine extends StatelessWidget {
  const _HeadLine({
    required this.name,
    required this.nameColor,
    required this.share,
    required this.damage,
    required this.damageColor,
  });

  final String name;
  final Color nameColor;
  final double share;
  final double damage;
  final Color damageColor;

  @override
  Widget build(BuildContext context) {
    final percent = (share * 100).round();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            name.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: hudMono(
              11.5,
              nameColor,
              weight: FontWeight.w600,
              spacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          percent == 0 && share > 0 ? '<1%' : '$percent%',
          style: hudMono(
            10,
            SurvivalInk.muted,
            weight: FontWeight.w700,
            spacing: 0.4,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          compactAmount(damage),
          style: hudMono(
            13,
            damageColor,
            weight: FontWeight.w900,
            spacing: 0.6,
          ),
        ),
      ],
    );
  }
}

/// The creature in its element's light, as the party row shows one that is
/// out.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.line, required this.light});

  final SurvivalDamageLine line;
  final Color light;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: SurvivalDamageBreakdown.portrait,
    child: CustomPaint(
      painter: CaseLightPainter(color: light),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: _art(line, SurvivalDamageBreakdown.portrait - 4),
      ),
    ),
  );
}

Widget _art(SurvivalDamageLine line, double size) {
  final path = line.imagePath;
  Widget initial() => Center(
    child: Text(
      line.name.characters.first.toUpperCase(),
      style: hudMono(size * 0.5, SurvivalInk.muted, weight: FontWeight.w900),
    ),
  );
  if (path == null) return initial();
  return Image.asset(
    path,
    width: size,
    height: size,
    fit: BoxFit.contain,
    cacheWidth: kSurvivalTeamCaseCacheWidth,
    errorBuilder: (_, _, _) => initial(),
  );
}

/// The HUD's glass tube, filled as far as [fraction].
class _Tube extends StatelessWidget {
  const _Tube({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 5,
    child: CustomPaint(
      painter: HudTubePainter(fraction.clamp(0.0, 1.0), color),
    ),
  );
}

/// The row's figures, each a number in ink and a word after it, wrapping
/// onto a second line where the row is narrow.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<(String, String)> facts;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 3,
    children: [
      for (final (figure, word) in facts)
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: figure,
                style: hudMono(
                  10,
                  SurvivalInk.ink.withValues(alpha: 0.85),
                  weight: FontWeight.w700,
                  spacing: 0.4,
                ),
              ),
              TextSpan(
                text: ' $word',
                style: hudMono(
                  9,
                  SurvivalInk.muted,
                  weight: FontWeight.w600,
                  spacing: 1,
                ),
              ),
            ],
          ),
          maxLines: 1,
          softWrap: false,
        ),
    ],
  );
}
