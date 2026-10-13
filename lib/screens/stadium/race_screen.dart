// lib/screens/stadium/race_screen.dart
//
// A race as the player watches it: the stadium (RacePainter) under a light
// HUD — the course as a strip with the six on it, the standings, the leg the
// player's racer is on and what it asks, the announcer's line, and the
// BOOST button with a pip for each stamina bar left. When the last crosses,
// the results: the order and times, the player's run leg by leg with what
// the judges counted, and what the win paid.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_cups.dart';
import 'package:alchemons/audio/ambience_player.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/games/cosmic/obsidian_kit.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/navigation/turning_passage.dart';
import 'package:alchemons/navigation/world_transition.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_scenes.dart';
import 'package:alchemons/games/stadium/race_stage.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/services/game_controller_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);

/// How a race ended for the stadium: where the player placed, and whether
/// they asked to run it again.
class RaceOutcome {
  const RaceOutcome({required this.place, this.again = false});
  final int place;
  final bool again;
}

/// A race run live with other phones (race_room.dart): when the gun goes
/// on this phone's clock, the other players' taps by lane as they arrive,
/// and where this phone's own go (all of them so far, each time).
class RaceLink {
  const RaceLink({
    required this.gunAtMs,
    required this.taps,
    required this.send,
  });

  final int gunAtMs;
  final ValueListenable<Map<int, List<int>>> taps;
  final void Function(List<int> ticks) send;
}

class RaceScreen extends StatefulWidget {
  const RaceScreen({
    super.key,
    required this.cup,
    required this.race,
    required this.racers,
    required this.bodies,
    required this.onFinished,
    this.forms,
    this.onDone,
    this.live,
  });

  final RaceCup cup;
  final int race;
  final List<Racer> racers;
  final List<RaceBody> bodies;

  /// Set for a race with friends: it keeps to the shared gun, nothing is
  /// paid, and the results lead back to the lobby.
  final RaceLink? live;

  /// Each racer's forms by element, for what its fusions make it (see
  /// [raceForms]).
  final List<Map<String, RaceBody>>? forms;

  /// Called once with how it ended (leave, or race again) in place of
  /// popping the screen; [RaceSeries] runs the next race or leaves.
  final ValueChanged<RaceOutcome>? onDone;

  /// Called once, as the results come up, with the player's place (1–6).
  /// Pays what the race pays and returns the gold given.
  final Future<int> Function(int place) onFinished;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin {
  late final RaceStage _stage;
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  bool _reported = false;
  int? _gold;

  RaceCourse get _course => widget.cup.courses[widget.race];

  @override
  void initState() {
    super.initState();
    _stage = RaceStage(
      course: _course,
      racers: widget.racers,
      bodies: widget.bodies,
      player: widget.racers.indexWhere((r) => r.isPlayer),
      numerals: raceNumeralGrains,
      forms: widget.forms,
      live: switch (widget.live) {
        final link? => RaceLive(
          gunAt: link.gunAtMs / 1000,
          wall: () => DateTime.now().millisecondsSinceEpoch / 1000,
        ),
        null => null,
      },
    );
    widget.live?.taps.addListener(_theirTaps);
    _theirTaps();
    _ticker = createTicker(_tick)..start();
    // A pad or the keyboard: A (Space) boosts, hurries the podium on, and
    // on the results runs it again; B (Esc) leaves, asking first mid-race.
    _pad = GameControllerService.instance.claim(
      context,
      onPressed: (b) {
        switch (b) {
          case GamepadButton.a:
            switch (_stage.phase) {
              case RaceStagePhase.podium:
                _stage.skipPodium();
              case RaceStagePhase.done:
                _done(RaceOutcome(place: _place, again: widget.live == null));
              default:
                _boost();
            }
          case GamepadButton.b:
          case GamepadButton.start:
            unawaited(_leave());
          default:
            break;
        }
      },
    );
  }

  late final PlayInputClaim _pad;
  AudioController? _audio;
  RacePainter? _painterOrNull;
  RacePainter get _painter => _painterOrNull!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_painterOrNull != null) return;
    _audio = context.audio;
    _audio?.setAmbience(this, AmbienceCue.raceCrowd);
    // The app's type for what is written on the track; the count's numerals
    // read in it long before the count, which starts after the line-up.
    final type = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    _painterOrNull = RacePainter(_stage, textStyle: type);
    unawaited(loadRaceNumerals(style: type));
  }

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0) return;
    _stage.advance(dt);
    final animDt = dt * (_stage.running ? _stage.speed : 1);
    for (final b in widget.bodies) {
      b.ticker?.update(animDt);
    }
    for (final s in _stage.sounds) {
      final cue = raceSoundCue(s);
      if (cue != null) context.sound(cue, owner: this);
      // The stands hold their breath through a photo finish (the bed has no
      // volume of its own, so it stops) and come back with the line.
      if (s == RaceSound.photoHush) _audio?.stopAmbienceOwner(this);
      if (s == RaceSound.finish && _stage.photoAt != null) {
        _audio?.setAmbience(this, AmbienceCue.raceCrowd);
      }
    }
    _stage.sounds.clear();
    // Paid as the podium rises, so leaving from it never loses the win.
    if (_stage.phase.index >= RaceStagePhase.podium.index && !_reported) {
      _reported = true;
      final place = _stage.standings.indexOf(_stage.player) + 1;
      unawaited(
        widget.onFinished(place).then((gold) {
          if (mounted) setState(() => _gold = gold);
        }),
      );
    }
    if (_stage.phase != _shownPhase) {
      _shownPhase = _stage.phase;
      setState(() {});
    }
  }

  RaceStagePhase _shownPhase = RaceStagePhase.intro;

  /// The other players' taps, into the race.
  void _theirTaps() {
    final link = widget.live;
    if (link == null) return;
    for (final e in link.taps.value.entries) {
      if (e.key != _stage.player) _stage.mergeTaps(e.key, e.value);
    }
  }

  @override
  void dispose() {
    widget.live?.taps.removeListener(_theirTaps);
    _audio?.stopAmbienceOwner(this);
    _audio?.releaseSoundOwner(this);
    _pad.release();
    _ticker.dispose();
    _stage.dispose();
    super.dispose();
  }

  int get _place => _stage.standings.indexOf(_stage.player) + 1;

  bool _ended = false;

  /// How it ended: to [RaceScreen.onDone], or popped with it.
  void _done(RaceOutcome outcome) {
    if (_ended) return;
    _ended = true;
    final done = widget.onDone;
    if (done != null) {
      done(outcome);
    } else {
      Navigator.of(context).pop(outcome);
    }
  }

  void _boost() {
    if (!_stage.tapBoost()) return;
    HapticFeedback.mediumImpact();
    widget.live?.send([..._stage.sim.taps[_stage.player] ?? const <int>[]]);
  }

  Future<void> _leave() async {
    if (_stage.phase.index >= RaceStagePhase.podium.index) {
      _done(RaceOutcome(place: _place));
      return;
    }
    final go = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kLeaveDangerAccent,
      title: 'LEAVE THE RACE?',
      message: widget.live != null
          ? 'Your racer runs on without you.'
          : 'The race ends here and counts as a loss.',
      cancelLabel: 'STAY',
      confirmLabel: 'LEAVE',
    );
    if (go && mounted) {
      _done(const RaceOutcome(place: 6));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, box) {
                  _stage.viewport = box.biggest;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _stage.skipPodium,
                    child: CustomPaint(painter: _painter, size: box.biggest),
                  );
                },
              ),
            ),
            if (_stage.phase.index < RaceStagePhase.podium.index)
              Positioned.fill(
                child: SafeArea(
                  child: AnimatedBuilder(
                    animation: _stage,
                    builder: (context, _) => _hud(context),
                  ),
                ),
              ),
            if (_stage.phase == RaceStagePhase.done)
              Positioned.fill(child: _results(context)),
          ],
        ),
      ),
    );
  }

  // ── the HUD ───────────────────────────────────────────────────────────────

  Widget _hud(BuildContext context) {
    final s = _stage;
    final (legIdx, _) = s.layout.legAt(s.distance[s.player]);
    final leg = _course.legs[legIdx];
    final fuse = leg.kind == RaceLegKind.fuse;
    final legLine = leg.title;
    final captionAge = s.clock - s.captionAt;
    final captionA = captionAge < 0
        ? 0.0
        : (captionAge < 0.25
                  ? captionAge / 0.25
                  : captionAge > 2.4
                  ? 1 - (captionAge - 2.4) / 0.5
                  : 1.0)
              .clamp(0.0, 1.0);
    return Stack(
      children: [
        // Top left: leave, the race, the leg.
        Positioned(
          left: 8,
          top: 6,
          right: 230,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BracketIconButton(
                icon: AppIcons.close_rounded,
                onTap: _leave,
                palette: BracketPalette.dark,
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.cup.name.toUpperCase()} · ${_course.name.toUpperCase()}',
                      style: bracketText(
                        context,
                        10,
                        _muted,
                        weight: FontWeight.w700,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (s.running)
                      Text(
                        legLine,
                        style: bracketText(
                          context,
                          13,
                          _ink,
                          weight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    if (s.running && !fuse && leg.line.isNotEmpty)
                      Text(
                        leg.line,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bracketText(context, 11, _muted),
                      ),
                    if (s.running && fuse)
                      Text(
                        _fuseLine(leg),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: bracketText(context, 11, _muted),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Top right: the standings.
        Positioned(right: 10, top: 6, child: _standings(context)),
        // The course strip, under the stands.
        Positioned(
          left: 60,
          // On a short screen the standings reach down past the stands.
          right: MediaQuery.sizeOf(context).height < 340 ? 150 : 60,
          top: MediaQuery.sizeOf(context).height * 0.345,
          height: 12,
          child: CustomPaint(painter: _StripPainter(s)),
        ),
        // The announcer.
        Positioned(
          left: 16,
          bottom: 10,
          right: 200,
          child: Opacity(
            opacity: captionA,
            child: Text(
              s.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                13,
                _ink,
                weight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
        // Boost and speed.
        Positioned(
          right: 14,
          bottom: 8,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (s.running && widget.live == null) ...[
                _speedToggle(context),
                const SizedBox(width: 12),
              ],
              _BoostVial(
                stage: s,
                total: widget.racers[s.player].boosts,
                color: elementColor(widget.racers[s.player].entrant.element),
                onTap: _boost,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fuseLine(RaceLeg leg) {
    final (legIdx, _) = _stage.layout.legAt(_stage.distance[_stage.player]);
    final me = _stage.elements[_stage.player][legIdx];
    final made = raceFusion(me, leg.element!);
    return made == null
        ? '$me + ${leg.element} has no recipe.'
        : '$me + ${leg.element} makes $made.';
  }

  Widget _standings(BuildContext context) {
    final s = _stage;
    final order = s.standings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var p = 0; p < order.length; p++)
          Padding(
            padding: const EdgeInsets.only(bottom: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.bodies[order[p]].member.displayName,
                  style: bracketText(
                    context,
                    10.5,
                    order[p] == s.player
                        ? _brassHot
                        : _ink.withValues(alpha: 0.7),
                    weight: order[p] == s.player
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 12,
                  child: Text(
                    '${p + 1}',
                    textAlign: TextAlign.right,
                    style: bracketText(
                      context,
                      10.5,
                      order[p] == s.player ? _brassHot : _muted,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _speedToggle(BuildContext context) {
    final fast = _stage.speed > 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.selectionClick();
        _stage.speed = fast ? 1 : 2;
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Text(
          fast ? '×2' : '×1',
          style: bracketText(
            context,
            13,
            fast ? _brassHot : _muted,
            weight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── results ───────────────────────────────────────────────────────────────

  Widget _results(BuildContext context) {
    final s = _stage;
    final order = s.standings;
    final winner = s.sim.states[order.first].finishTime ?? 0;
    final place = _place;
    final won = place == 1;
    final mine = s.player;
    return LayoutBuilder(
      builder: (context, box) {
        // The results on the left; the podium stands aside on the right
        // (RacePainter slides it there as the results come up).
        final w = box.maxWidth;
        final split = w * kRaceResultsSplit;
        return AnimatedBuilder(
          animation: _stage,
          builder: (context, child) {
            final k = Curves.easeOutCubic.transform(_stage.resultsT);
            return Opacity(opacity: k, child: child);
          },
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withValues(alpha: .9),
                  Colors.black.withValues(alpha: .82),
                  Colors.black.withValues(alpha: 0),
                ],
                stops: [
                  0,
                  (split / w).clamp(0.0, 1.0),
                  ((split + 90) / w).clamp(0.0, 1.0),
                ],
              ),
            ),
            child: SafeArea(
              right: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 0, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: split - 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              ordinal(place).toUpperCase(),
                              style: bracketText(
                                context,
                                32,
                                won ? _brassHot : _ink,
                                weight: FontWeight.w300,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Text(
                                  '${widget.cup.name.toUpperCase()} · '
                                  '${_course.name.toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: bracketText(
                                    context,
                                    10.5,
                                    _muted,
                                    weight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                            ),
                            if ((_gold ?? 0) > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: CoinAmount(
                                  kind: CoinKind.gold,
                                  amount: _gold!,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // The order and the gaps.
                              SizedBox(
                                width: (split * .34).clamp(150.0, 200.0),
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [
                                      for (var p = 0; p < order.length; p++)
                                        _resultRow(
                                          context,
                                          p + 1,
                                          widget
                                              .bodies[order[p]]
                                              .member
                                              .displayName,
                                          p == 0
                                              ? _time(winner)
                                              : '+${((s.sim.states[order[p]].finishTime ?? winner) - winner).toStringAsFixed(2)}',
                                          order[p] == mine,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 22),
                              // The player's run, leg by leg.
                              Expanded(child: _yourRun(context)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.live != null)
                          BracketButton(
                            label: 'BACK TO THE LOBBY',
                            palette: BracketPalette.dark,
                            accent: _brass,
                            height: 38,
                            onTap: () => _done(RaceOutcome(place: place)),
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: BracketButton(
                                  label: 'LEAVE',
                                  palette: BracketPalette.dark,
                                  accent: _brass,
                                  primary: false,
                                  height: 38,
                                  onTap: () => _done(RaceOutcome(place: place)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: BracketButton(
                                  label: 'RACE AGAIN',
                                  palette: BracketPalette.dark,
                                  accent: _brass,
                                  height: 38,
                                  onTap: () => _done(
                                    RaceOutcome(place: place, again: true),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _resultRow(
    BuildContext context,
    int place,
    String name,
    String time,
    bool mine,
  ) {
    final c = mine ? _brassHot : _ink.withValues(alpha: 0.8);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$place',
              style: bracketText(context, 12, c, weight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bracketText(
                context,
                12,
                c,
                weight: mine ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          Text(time, style: bracketText(context, 11.5, c)),
        ],
      ),
    );
  }

  /// The player's run: each leg and its time, and under it what the judges
  /// counted, gains in brass and losses in a dull red.
  Widget _yourRun(BuildContext context) {
    final s = _stage;
    final times = s.sim.legTimes(s.player);
    final verdicts = s.sim.verdicts[s.player];
    final boosts = s.sim.states[s.player].boostsAt.length;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR RUN',
            style: bracketText(
              context,
              10,
              _muted,
              weight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 3),
          for (var j = 0; j < _course.legs.length; j++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _course.legs[j].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        11,
                        _ink,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    j < times.length ? _time(times[j]) : '–',
                    style: bracketText(context, 11, _muted),
                  ),
                ],
              ),
            ),
            if (verdicts[j].factors.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 1),
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final (i, f)
                          in verdicts[j].factors.take(2).indexed) ...[
                        if (i > 0) const TextSpan(text: '   '),
                        TextSpan(text: '${f.text} '),
                        TextSpan(
                          text:
                              '${f.delta >= 0 ? '+' : '−'}${f.delta.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            color: f.delta >= 0
                                ? _brass
                                : const Color(0xFFC0705E),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: bracketText(context, 9.5, _muted),
                ),
              ),
          ],
          const SizedBox(height: 6),
          Text(
            boosts == 0
                ? 'No boosts spent.'
                : '$boosts of ${widget.racers[s.player].boosts} boosts spent.',
            style: bracketText(context, 10.5, _muted),
          ),
        ],
      ),
    );
  }

  String _time(double s) => '${s.toStringAsFixed(2)}s';
}

/// The boost: a glass vial of the racer's stamina, one chamber of its
/// colour's grains for each bar. A tap pours the top chamber out as the
/// racer gathers itself; spent chambers stand empty.
class _BoostVial extends StatelessWidget {
  const _BoostVial({
    required this.stage,
    required this.total,
    required this.color,
    required this.onTap,
  });

  final RaceStage stage;
  final int total;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final me = stage.sim.states[stage.player];
    final lit = stage.canBoost ? 1.0 : (me.busy ? 0.75 : 0.35);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTap(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 6, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: Size(40, 25.0 * total + 10),
              painter: _VialPainter(stage, total, color),
            ),
            const SizedBox(height: 4),
            Text(
              'BOOST',
              style: bracketText(
                context,
                10,
                _ink.withValues(alpha: lit),
                weight: FontWeight.w800,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VialPainter extends CustomPainter {
  _VialPainter(this.stage, this.total, this.color);

  final RaceStage stage;
  final int total;
  final Color color;

  static final GrainBatch _batch = GrainBatch(4);

  @override
  void paint(Canvas canvas, Size size) {
    final me = stage.sim.states[stage.player];
    final t = stage.clock;
    final w = size.width, h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(w / 2),
    );
    // Dark glass, lit down its left side.
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(w, 0),
          [
            const Color(0xFF2A2A30),
            const Color(0xFF111114),
            const Color(0xFF17171B),
          ],
          const [0, 0.55, 1],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.16, h * 0.1, w * 0.09, h * 0.8),
        Radius.circular(w * 0.05),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );
    // Chambers, bottom up; the top full one pours while a boost winds up.
    final chamber = (h - 10) / total;
    final windup = me.phase == RacerPhase.windup
        ? ((stage.sim.tick - me.phaseFrom) / kRaceBoostWindupTicks).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final b = _batch..clear();
    for (var c = 0; c < total; c++) {
      final full = c < me.boostsLeft;
      final pouring = me.phase == RacerPhase.windup && c == me.boostsLeft;
      final top = h - 5 - (c + 1) * chamber;
      final centre = Offset(w / 2, top + chamber / 2);
      if (full || pouring) {
        final glow = pouring ? 1 - windup : 1.0;
        canvas.drawCircle(
          centre,
          chamber * 0.55,
          Paint()
            ..shader = ui.Gradient.radial(centre, chamber * 0.55, [
              color.withValues(alpha: 0.35 * glow),
              color.withValues(alpha: 0),
            ]),
        );
        for (var i = 0; i < 26; i++) {
          final h1 = hash01(i, 40 + c), h2 = hash01(i, 41 + c);
          final a = h1 * pi * 2 + t * (0.8 + h2) * (i.isEven ? 1 : -1);
          final r = (2 + h2 * (w * 0.3));
          var x = centre.dx + cos(a) * r;
          var y = centre.dy + sin(a) * r * (chamber / w) * 0.7;
          if (pouring) {
            // Up and out of the neck.
            final q = (windup * 1.4 - h2 * 0.4).clamp(0.0, 1.0);
            x += (w / 2 - x) * q;
            y += (-8 - y) * q * q;
          }
          b.add(h2 < 0.3 ? 1 : 0, x, y);
        }
      }
    }
    b.draw(canvas, 0, 2.1, color.withValues(alpha: 0.9));
    b.draw(canvas, 1, 2.6, Color.lerp(color, Colors.white, 0.45)!);
    // The bands between chambers.
    for (var c = 1; c < total; c++) {
      final y = h - 5 - c * chamber;
      canvas.drawRect(
        Rect.fromLTWH(w * 0.12, y - 0.8, w * 0.76, 1.6),
        Paint()..color = Colors.black.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_VialPainter old) => true;
}

/// The course as a strip: each leg its own shade, the six as grains on it,
/// the player's lit.
class _StripPainter extends CustomPainter {
  _StripPainter(this.stage);
  final RaceStage stage;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = stage.layout;
    final total = layout.finishX;
    final y = size.height / 2;
    for (var j = 0; j < stage.course.legs.length; j++) {
      final leg = stage.course.legs[j];
      final x0 = layout.starts[j] / total * size.width;
      final x1 = (layout.starts[j] + layout.widths[j]) / total * size.width;
      final col = raceLegTint(
        leg,
      ).withValues(alpha: leg.kind == RaceLegKind.sprint ? 0.16 : 0.55);
      canvas.drawRect(
        Rect.fromLTRB(x0 + 1, y - 1.5, x1 - 1, y + 1.5),
        Paint()..color = col,
      );
    }
    for (var i = 0; i < stage.racers.length; i++) {
      if (i == stage.player) continue;
      final x = (layout.xAt(stage.distance[i]) / total).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x * size.width, y),
        2.6,
        Paint()..color = _ink.withValues(alpha: 0.65),
      );
    }
    final me = (layout.xAt(stage.distance[stage.player]) / total).clamp(
      0.0,
      1.0,
    );
    canvas.drawCircle(
      Offset(me * size.width, y),
      4,
      Paint()..color = _brassHot,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) => true;
}

/// One race after another on the same course, sideways the whole time:
/// RACE AGAIN starts a fresh one in place; leaving turns the phone back
/// under the lights going down ([RaceLightsScene]) and pops with how the
/// last one ended.
class RaceSeries extends StatefulWidget {
  const RaceSeries({
    super.key,
    required this.cup,
    required this.race,
    required this.racers,
    required this.bodies,
    required this.onFinished,
    this.forms,
    this.live,
  });

  final RaceCup cup;
  final int race;
  final List<Racer> racers;
  final List<RaceBody> bodies;
  final List<Map<String, RaceBody>>? forms;
  final Future<int> Function(int place) onFinished;

  /// A race with friends: run once, and back to the lobby after.
  final RaceLink? live;

  @override
  State<RaceSeries> createState() => _RaceSeriesState();
}

class _RaceSeriesState extends State<RaceSeries> {
  int _run = 0;
  bool _leaving = false;

  void _done(RaceOutcome outcome) {
    if (outcome.again) {
      setState(() => _run++);
      return;
    }
    if (_leaving) return;
    _leaving = true;
    unawaited(
      VoidPortal.leaveThroughTurn<RaceOutcome>(
        context,
        scene: const RaceLightsScene(),
        from: null,
        to: () => null,
        result: outcome,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => RaceScreen(
    key: ValueKey(_run),
    cup: widget.cup,
    race: widget.race,
    racers: widget.racers,
    bodies: widget.bodies,
    forms: widget.forms,
    onFinished: widget.onFinished,
    onDone: _done,
    live: widget.live,
  );
}

/// The lights going down for a race and coming up on it: the screen dims
/// to black, the phone turns there (where its turning cannot be seen), and
/// the other screen comes up out of the black.
class RaceLightsScene extends TurningScene {
  const RaceLightsScene();

  @override
  double get rise => .28;

  @override
  double get settle => .42;

  @override
  bool get holdsThroughTurn => true;

  @override
  double groundAt(TurningStage s) {
    if (s.settle > 0) return 1 - Curves.easeOut.transform(s.settle);
    return Curves.easeIn.transform(s.rise);
  }

  @override
  void paint(Canvas canvas, TurningStage s) {}
}

/// The sound for what the stage asks to be heard.
SoundCue? raceSoundCue(RaceSound s) => switch (s) {
  RaceSound.countTick => SoundCue.raceCountTick,
  RaceSound.gun => SoundCue.raceGun,
  RaceSound.boost => SoundCue.raceBoost,
  RaceSound.wall => SoundCue.raceWallCrumble,
  RaceSound.fuseIn => SoundCue.raceFuseIn,
  RaceSound.fuseOut => SoundCue.raceFuseOut,
  RaceSound.crowdSwell => SoundCue.raceCrowdSwell,
  RaceSound.photoHush => SoundCue.racePhotoHush,
  RaceSound.finish => SoundCue.raceFinish,
  RaceSound.podium => SoundCue.racePodium,
};
