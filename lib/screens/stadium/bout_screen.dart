// lib/screens/stadium/bout_screen.dart
//
// A gem cup's bout as the player watches it, whatever the event (a
// BoutStage: the island, the night sky, the space course): the bout drawn
// full screen under a light HUD — the bout, the three by name with how each
// is doing, what is under way, and the action (CHARGE, BOOST) with a pip
// for each stamina bar when there is one. Upright, like the Trials, so
// nothing turns. When it is over, the places and what the win paid; AGAIN
// starts it over in place. With friends ([RaceLink]) the player's taps go
// to the other phones and theirs come in, and the results lead back to the
// lobby.

import 'dart:async';

import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/stadium/gem_cups.dart';
import 'package:alchemons/games/stadium/bout_stage.dart';
import 'package:alchemons/games/stadium/race_bodies.dart';
import 'package:alchemons/games/stadium/race_painter.dart';
import 'package:alchemons/games/stadium/race_rules.dart';
import 'package:alchemons/games/stadium/race_stage.dart';
import 'package:alchemons/games/stadium/trials_records.dart';
import 'package:alchemons/screens/stadium/race_screen.dart';
import 'package:alchemons/screens/stadium/stamina_vial.dart';
import 'package:alchemons/services/game_controller_service.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

const Color _ink = Color(0xFFE6E2DA);
const Color _muted = Color(0xFF8E8C88);
const Color _brass = Color(0xFFCDB07A);
const Color _brassHot = Color(0xFFE2C98F);
const Color _bg1 = Color(0xFF131316);

class BoutScreen extends StatefulWidget {
  const BoutScreen({
    super.key,
    required this.cup,
    required this.bout,
    required this.fighters,
    required this.bodies,
    required this.stage,
    required this.onFinished,
    this.onDone,
    this.live,
  });

  final GemCup cup;
  final int bout;
  final List<Racer> fighters;
  final List<RaceBody> bodies;

  /// Makes the bout, once (with friends, kept to [live]'s gun).
  final BoutStage Function() stage;

  /// Set for a bout with friends: the other players' taps by fighter, and
  /// where the player's go.
  final RaceLink? live;

  /// Called once, as the results come up, with the player's place (1–3)
  /// and mark. Pays what the bout pays, keeps its record, and says what it
  /// paid.
  final Future<TrialsPayout> Function(TrialsFinish finish) onFinished;

  /// How it ended (leave, or again), in place of popping the screen.
  final ValueChanged<RaceOutcome>? onDone;

  @override
  State<BoutScreen> createState() => _BoutScreenState();
}

class _BoutScreenState extends State<BoutScreen>
    with SingleTickerProviderStateMixin {
  late final BoutStage _stage = widget.stage();
  late final Ticker _ticker;
  late final PlayInputClaim _pad;
  Duration _last = Duration.zero;
  bool _shownDone = false;
  bool _reported = false, _ended = false;
  TrialsPayout? _paid;
  final List<String?> _tags = [null, null, null];
  String? _caption;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    _pad = GameControllerService.instance.claim(
      context,
      onPressed: (b) {
        switch (b) {
          case GamepadButton.a:
            if (_stage.done) {
              _done(RaceOutcome(place: _place, again: widget.live == null));
            } else {
              _act();
            }
          case GamepadButton.b:
          case GamepadButton.start:
            unawaited(_leave());
          default:
            break;
        }
      },
    );
    unawaited(loadRaceNumerals(style: const TextStyle()));
    widget.live?.taps.addListener(_theirTaps);
    _theirTaps();
  }

  /// The other players' taps, into the bout.
  void _theirTaps() {
    final link = widget.live;
    if (link == null) return;
    for (final e in link.taps.value.entries) {
      if (e.key != _stage.player) _stage.mergeTaps(e.key, e.value);
    }
  }

  AudioController? _audio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _audio = context.audio;
    unawaited(
      loadRaceNumerals(
        style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
      ),
    );
  }

  @override
  void dispose() {
    widget.live?.taps.removeListener(_theirTaps);
    _audio?.releaseSoundOwner(this);
    _pad.release();
    _ticker.dispose();
    _stage.dispose();
    super.dispose();
  }

  int get _place => _stage.standings.indexOf(_stage.player) + 1;

  void _tick(Duration now) {
    final dt = (now - _last).inMicroseconds / 1e6;
    _last = now;
    if (dt <= 0) return;
    _stage.advance(dt);
    for (final b in widget.bodies) {
      b.ticker?.update(dt);
    }
    for (final s in _stage.sounds) {
      final cue = raceSoundCue(switch (s) {
        BoutSound.countTick => RaceSound.countTick,
        BoutSound.gun => RaceSound.gun,
        BoutSound.act => RaceSound.boost,
        BoutSound.hit => RaceSound.wall,
        BoutSound.out => RaceSound.crowdSwell,
        BoutSound.win => RaceSound.podium,
        BoutSound.cast => RaceSound.fuseIn,
        BoutSound.land => RaceSound.fuseOut,
      });
      if (cue != null) context.sound(cue, owner: this);
    }
    _stage.sounds.clear();
    if (_stage.done && !_reported) {
      _reported = true;
      unawaited(
        widget.onFinished(TrialsFinish(_place, _stage.mark)).then((paid) {
          if (mounted) setState(() => _paid = paid);
        }),
      );
    }
    var changed = _stage.done != _shownDone;
    final caption = _stage.caption;
    if (caption != _caption) {
      _caption = caption;
      changed = true;
    }
    for (var i = 0; i < _tags.length && i < widget.bodies.length; i++) {
      final tag = _stage.tagOf(i);
      if (tag != _tags[i]) {
        _tags[i] = tag;
        changed = true;
      }
    }
    if (changed) {
      _shownDone = _stage.done;
      setState(() {});
    }
  }

  void _act() {
    if (!_stage.act()) return;
    HapticFeedback.mediumImpact();
    widget.live?.send(_stage.myTaps);
  }

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

  Future<void> _leave() async {
    if (_stage.done) {
      _done(RaceOutcome(place: _place));
      return;
    }
    final go = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kLeaveDangerAccent,
      title: 'LEAVE THE BOUT?',
      message: widget.live != null
          ? 'Your Alchemon goes on without you.'
          : 'The bout ends here and counts as a loss.',
      cancelLabel: 'STAY',
      confirmLabel: 'LEAVE',
    );
    if (go && mounted) _done(const RaceOutcome(place: 3));
  }

  @override
  Widget build(BuildContext context) {
    final bout = widget.cup.bouts[widget.bout];
    final done = _stage.done;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07070A),
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (_) => _act(),
                  child: CustomPaint(painter: _stage.painter),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        BracketIconButton(
                          icon: AppIcons.close_rounded,
                          onTap: _leave,
                          palette: BracketPalette.dark,
                          size: 32,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bout.name.toUpperCase(),
                                style: bracketText(
                                  context,
                                  14,
                                  _brassHot,
                                  weight: FontWeight.w800,
                                  letterSpacing: 2.2,
                                ),
                              ),
                              Text(
                                '${widget.cup.name.toUpperCase()} · '
                                '${widget.live != null ? 'WITH FRIENDS' : 'BOUT ${widget.bout + 1} OF ${widget.cup.bouts.length}'}',
                                style: bracketText(
                                  context,
                                  9.5,
                                  _muted,
                                  weight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _names(context),
                    const SizedBox(height: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: Text(
                        done ? '' : (_caption ?? ''),
                        key: ValueKey(done ? null : _caption),
                        textAlign: TextAlign.center,
                        style: bracketText(
                          context,
                          10,
                          _brass,
                          weight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!done && _stage.hasAction)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: _actPad(context),
                      ),
                  ],
                ),
              ),
            ),
            if (done) _results(context),
          ],
        ),
      ),
    );
  }

  /// The three by name, the player's in brass; those out dimmed.
  Widget _names(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < widget.bodies.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 400),
              opacity: _stage.dimmed(i) ? 0.4 : 1,
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: elementColor(widget.bodies[i].member.element),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      switch (_stage.tagOf(i)) {
                        final tag? =>
                          '${widget.bodies[i].member.displayName} · $tag',
                        null => widget.bodies[i].member.displayName,
                      },
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        10.5,
                        i == _stage.player ? _brassHot : _ink,
                        weight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The action: the stamina vial, a chamber of the Alchemon's colour for
  /// each bar, named for what a bar does here (CHARGE, BOOST).
  Widget _actPad(BuildContext context) {
    final me = widget.bodies[_stage.player].member;
    final total = widget.fighters[_stage.player].boosts;
    return AnimatedBuilder(
      animation: _stage,
      builder: (context, _) => StaminaVial(
        total: total,
        left: _stage.actsLeft,
        pour: _stage.actPour,
        clock: _stage.clock,
        lit: _stage.canAct ? 1.0 : (_stage.actPour != null ? 0.75 : 0.35),
        color: elementColor(me.element),
        label: _stage.actLabel,
        onTap: _act,
      ),
    );
  }

  /// The places, what the win paid, and FIGHT AGAIN / LEAVE.
  Widget _results(BuildContext context) {
    final order = _stage.standings;
    final place = _place;
    const words = ['1ST', '2ND', '3RD'];
    return Positioned(
      left: 20,
      right: 20,
      bottom: 24,
      child: SafeArea(
        top: false,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: _brass.withValues(alpha: 0.85),
            bracketSize: 12,
            strokeWidth: 1.2,
          ),
          child: Container(
            color: _bg1.withValues(alpha: 0.94),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _stage.headline(place),
                  textAlign: TextAlign.center,
                  style: bracketText(
                    context,
                    15,
                    place == 1 ? _brassHot : _ink,
                    weight: FontWeight.w800,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(height: 10),
                for (var p = 0; p < order.length; p++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            words[p.clamp(0, 2)],
                            style: bracketText(
                              context,
                              11,
                              p == 0 ? _brassHot : _muted,
                              weight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            widget.bodies[order[p]].member.displayName,
                            style: bracketText(
                              context,
                              12.5,
                              order[p] == _stage.player ? _brassHot : _ink,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (_stage.resultOf(order[p]) case final r?)
                          Text(
                            r,
                            style: bracketText(
                              context,
                              11,
                              _muted,
                              weight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_stage.note case final note?) ...[
                  const SizedBox(height: 10),
                  Text(
                    note,
                    textAlign: TextAlign.center,
                    style: bracketText(
                      context,
                      9.5,
                      _muted,
                      weight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
                if (_paid?.record ?? false) ...[
                  const SizedBox(height: 10),
                  Text(
                    'NEW RECORD',
                    textAlign: TextAlign.center,
                    style: bracketText(
                      context,
                      10.5,
                      _brassHot,
                      weight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
                if ((_paid?.gold ?? 0) > 0) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'FIRST WIN  ',
                        style: bracketText(
                          context,
                          10,
                          _muted,
                          weight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                      CoinAmount(
                        kind: CoinKind.gold,
                        amount: _paid!.gold,
                        size: 14,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                if (widget.live != null)
                  BracketButton(
                    label: 'BACK TO THE LOBBY',
                    palette: BracketPalette.dark,
                    accent: _brass,
                    height: 40,
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
                          height: 40,
                          onTap: () => _done(RaceOutcome(place: place)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: BracketButton(
                          label: 'AGAIN',
                          palette: BracketPalette.dark,
                          accent: _brass,
                          height: 40,
                          onTap: () =>
                              _done(RaceOutcome(place: place, again: true)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouts in a row: AGAIN starts a fresh one in place; leaving pops with
/// how the last one went.
class BoutSeries extends StatefulWidget {
  const BoutSeries({
    super.key,
    required this.cup,
    required this.bout,
    required this.fighters,
    required this.bodies,
    required this.stage,
    required this.onFinished,
  });

  final GemCup cup;
  final int bout;
  final List<Racer> fighters;
  final List<RaceBody> bodies;

  /// Makes a fresh bout.
  final BoutStage Function() stage;
  final Future<TrialsPayout> Function(TrialsFinish finish) onFinished;

  @override
  State<BoutSeries> createState() => _BoutSeriesState();
}

class _BoutSeriesState extends State<BoutSeries> {
  int _run = 0;

  @override
  Widget build(BuildContext context) => BoutScreen(
    key: ValueKey(_run),
    cup: widget.cup,
    bout: widget.bout,
    fighters: widget.fighters,
    bodies: widget.bodies,
    stage: widget.stage,
    onFinished: widget.onFinished,
    onDone: (outcome) {
      if (outcome.again) {
        setState(() => _run++);
      } else {
        Navigator.of(context).pop(outcome);
      }
    },
  );
}
