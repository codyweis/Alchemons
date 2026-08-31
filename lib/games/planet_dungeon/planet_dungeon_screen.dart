// lib/games/planet_dungeon/planet_dungeon_screen.dart
//
// Flutter wrapper around PlanetDungeonGame: joystick movement, a swap-control
// rail for the creatures you brought, Regroup / End Run, the room minimap, a
// death overlay and an instant star-banked toast. Dark / alchemical chrome.

import 'dart:async';
import 'dart:math' as math;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_minimap.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_popup_chrome.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/raid_rewards.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_descent.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_reward_popup.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/screens/cosmic/widgets/virtual_joystick.dart';
import 'package:flame/game.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _C {
  static const bg = Color(0xFF080808);
  static const bg2 = Color(0xFF111722);
  static const panel = Color(0xFF14120E);
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const cyan = Color(0xFF5BC8E8);
  static const border = Color(0xFF74613A);
  static const text = Color(0xFFE8DFC8);
  static const danger = Color(0xFFC0392B);

  /// Refusal accent — a banked ember: firmer than amber, never alarm-red.
  static const ember = Color(0xFFD07A4A);
}

class _HudBracketPainter extends CustomPainter {
  const _HudBracketPainter({
    required this.color,
    this.bracketSize = 8,
    this.strokeWidth = 1.2,
  });

  final Color color;
  final double bracketSize;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final s = bracketSize;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, 0)
      ..lineTo(s, 0)
      ..moveTo(w - s, 0)
      ..lineTo(w, 0)
      ..lineTo(w, s)
      ..moveTo(0, h - s)
      ..lineTo(0, h)
      ..lineTo(s, h)
      ..moveTo(w - s, h)
      ..lineTo(w, h)
      ..lineTo(w, h - s);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HudBracketPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The rim of a round action button: a charge arc, teeth, and a refusal flare.
///
/// The combat pad used to be two soft-cornered boxes whose only state was a
/// black shade creeping up from the bottom — readable, but it read as a
/// progress bar wearing a button, which is the opposite of what a weapon
/// should look like. The rim carries all of it now: the arc unwinds as the
/// cooldown runs, the teeth make it look like something with an edge, and a
/// refused press throws a shockwave off the outside.
///
/// Strokes only — no MaskFilter anywhere in here. The HUD repaints on the
/// game's tick, and a blurred rim would be a filter pass per button per frame.
class _ActionRingPainter extends CustomPainter {
  const _ActionRingPainter({
    required this.color,
    required this.charge,
    required this.spent,
    this.denied = 0,
    this.teeth = 0,
    this.thickness = 3,
  });

  /// 0..1 — how much of the rim is lit. 1 is ready to press.
  final double charge;
  final Color color;
  final bool spent;
  final double denied;
  final int teeth;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    // The flare needs somewhere to go, so the rim sits in from the edge.
    final r = math.min(size.width, size.height) / 2 - thickness - 5;
    if (r <= 0) return;

    final live = color.withValues(alpha: spent ? 0.34 : 0.92);
    final lit = denied > 0 ? Color.lerp(live, _C.ember, denied)! : live;

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness;

    // The unlit track, so a half-charged rim reads as half rather than short.
    canvas.drawCircle(c, r, stroke..color = color.withValues(alpha: 0.14));

    if (charge > 0.004) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * charge.clamp(0.0, 1.0),
        false,
        stroke
          ..color = lit
          ..strokeCap = StrokeCap.round,
      );
    }

    if (teeth > 0) {
      final tick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = lit.withValues(alpha: spent ? 0.2 : 0.5);
      for (var i = 0; i < teeth; i++) {
        final a = -math.pi / 2 + i * 2 * math.pi / teeth;
        final r0 = r + thickness * 0.9;
        // Every third tooth runs long — an even fringe reads as a dial.
        final r1 = r0 + (i % 3 == 0 ? 5.0 : 2.4);
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(c + d * r0, c + d * r1, tick);
      }
    }

    if (denied > 0) {
      canvas.drawCircle(
        c,
        r + 3 + 7 * denied,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.4 + 1.8 * (1 - denied)
          ..color = _C.ember.withValues(alpha: 0.55 * (1 - denied)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ActionRingPainter old) =>
      old.color != color ||
      old.charge != charge ||
      old.spent != spent ||
      old.denied != denied ||
      old.teeth != teeth ||
      old.thickness != thickness;
}

const _starPrefsKey = 'cosmic_planet_stars';

/// How long a newly earned star takes to reach its tracker slot.
///
/// Deliberately unhurried. This animation is the ONLY thing that tells the
/// player a star was banked before the reward dialog covers the screen, and at
/// the old 950ms — most of it spent travelling — a star earned during a fight
/// was routinely missed entirely. Split into three beats by the fractions
/// below: born where it was earned, flown to the tracker, seated there.
const Duration _kStarFlightDuration = Duration(milliseconds: 2150);

/// End of BEAT 1 (birth-and-hold) as a fraction of the flight.
const double _kStarBirth = 0.30;

/// Start of BEAT 3 (seating) as a fraction of the flight.
const double _kStarLand = 0.82;

/// How long the landed star is left alone before the reward popup opens.
///
/// The flight finishing and the popup appearing used to be the same instant,
/// so the payoff buried the thing that earned it. This is the pause where the
/// player sees the tracker actually holding the star.
const Duration _kRewardHoldAfterStar = Duration(milliseconds: 620);

class PlanetDungeonScreen extends StatefulWidget {
  const PlanetDungeonScreen({
    super.key,
    required this.element,
    required this.party,
    this.raid,
    this.onRaidCleared,
  });

  final String element;
  final List<CosmicPartyMember> party;

  /// Non-null → this descent is a raid: one open arena, an empowered
  /// guardian, raid loot. Stars/clouds are neither read nor written.
  final RaidConfig? raid;

  /// Persist-the-clear callback (RaidService.markCleared), awaited right
  /// after the loot is granted.
  final Future<void> Function()? onRaidCleared;

  @override
  State<PlanetDungeonScreen> createState() => _PlanetDungeonScreenState();
}

class _PlanetDungeonScreenState extends State<PlanetDungeonScreen>
    with TickerProviderStateMixin {
  PlanetDungeonGame? _game;

  final ValueNotifier<int> _tick = ValueNotifier<int>(0);
  Timer? _hudTimer;

  bool _ready = false;
  bool _showDeath = false;
  Timer? _deathTimer;
  String? _toast;
  bool _toastVisible = false;
  Timer? _toastTimer;
  bool _showFullMap = false;

  // Guardian-intro banner (§5.6): the mystic's arrival gets real chrome, but
  // combat is already starting — so it never blocks input and dismisses
  // itself. Same fade discipline as the toast: keep the text while fading.
  String? _guardianIntroName;
  String? _guardianIntroLine;
  bool _guardianIntroVisible = false;
  Timer? _guardianIntroTimer;

  // Star-earn fly animation.
  late final AnimationController _flyCtrl;
  int? _flyStar;
  Offset? _flyStart; // screen-space launch point (where the star was earned)

  // End-run reward popup.
  List<int>? _rewardStars;

  /// A reward earned mid-run that is waiting for a safe beat to be offered.
  ///
  /// Rewards used to be handed out only by _endRun, so the payoff arrived at
  /// the door rather than at the accomplishment. Now they are offered the
  /// moment they are earned — but not mid-fight, because a modal choice while
  /// something is shooting at you is worse than a short wait.
  bool _rewardPending = false;

  /// The post-landing pause before the reward popup (see
  /// [_kRewardHoldAfterStar]). Non-null while it is running.
  Timer? _rewardHold;

  bool get _isRaid => widget.raid != null;
  bool _showRaidReward = false;

  // Descent intro: a dive through the planet's storm clouds that doubles as
  // the loading screen (no spinner, no route gap).
  static const double _descentSeconds = 1.7;
  late final Ticker _introTicker;
  // Drives ONLY the descent painter/title — a full setState per frame here
  // used to rebuild the whole screen (including the live game) at 60fps.
  final ValueNotifier<double> _introTime = ValueNotifier<double>(0);
  double? _introFadeStart;
  bool _showIntro = true;

  /// The descent's element is reparented (not rebuilt) when `_ready` flips and
  /// the screen swaps from "loading shell" to "live dungeon + overlay". Without
  /// this the painter's whole render subtree is torn down and recreated in the
  /// middle of the dive — a spike exactly where it shows.
  final GlobalKey _descentKey = GlobalKey(debugLabel: 'descent');

  /// True while the dungeon is loaded and mounted but deliberately NOT ticking
  /// because the descent is covering it.
  ///
  /// The dungeon used to load AND RUN under the descent: from the moment
  /// Flame finished `onLoad` (a few hundred ms in) the full scene — fullscreen
  /// sky fragment shader, drifting clouds, ambient motes and ~25 world passes —
  /// was updated and rendered at 60fps behind an opaque overlay, plus a 10Hz
  /// HUD rebuild on top of it. That is what made the dive stutter; the descent
  /// painter itself is a few hundred cheap draws. So the dungeon loads under
  /// the descent (as designed) but stays frozen until the descent starts
  /// fading. See [_thawDungeon].
  bool _dungeonFrozen = true;

  /// Whether the frozen dungeon has been stepped once to warm its first-paint
  /// costs (notably the sky shader's runtime compile) while it is still hidden.
  bool _dungeonWarmed = false;

  @override
  void initState() {
    super.initState();
    _flyCtrl = AnimationController(vsync: this, duration: _kStarFlightDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _flyStar = null);
          // The star has landed. Let it SIT there for a beat before the popup
          // covers the screen — arriving and being buried in the same frame is
          // what made the animation feel skipped.
          if (_rewardPending) {
            _rewardHold?.cancel();
            _rewardHold = Timer(_kRewardHoldAfterStar, () {
              _rewardHold = null;
              if (mounted && _rewardPending) {
                unawaited(_offerPendingRewardIfSafe());
              }
            });
          }
        }
      });
    _introTicker = createTicker((elapsed) {
      if (!mounted) return;
      final secs = elapsed.inMicroseconds / 1e6;
      _warmFrozenDungeon();
      if (_introFadeStart == null && secs >= _descentSeconds && _ready) {
        _introFadeStart = secs;
        // The fade is the first moment the dungeon is visible, so it is the
        // first moment it is allowed to cost anything.
        _thawDungeon();
      }
      if (_introFadeStart != null && secs > _introFadeStart! + 0.5) {
        _introTicker.stop();
        _thawDungeon(); // belt and braces — never leave the run frozen
        setState(() => _showIntro = false);
        return;
      }
      _introTime.value = secs;
    })..start();
    _init();
  }

  Future<void> _init() async {
    // Hydrate the persisted developer switch so `toolsVisible` reads true in a
    // RELEASE install on a real device — `kDebugMode` alone hid the dungeon's
    // debug affordances exactly where playtesting happens.
    unawaited(
      DebugSettingsService().isEnabled().then((_) {
        if (mounted) setState(() {});
      }),
    );
    DebugSettingsService.enabledNotifier.addListener(_onDebugToolsChanged);
    final prefs = await SharedPreferences.getInstance();
    final stars = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    );

    // The campaign difficulty clock: every OTHER planet's fallen guardian
    // hardens this run's enemies (and especially its guardian).
    final cleared = stars.guardiansDefeated(excluding: widget.element);

    final game = _isRaid
        ? PlanetDungeonGame(
            element: widget.element,
            party: widget.party,
            initialStarMask: 0,
            onStarEarned: (_) {},
            onGuardianIntro: _onGuardianIntro,
            onPlayerDown: _onPlayerDown,
            onChanged: () => _tick.value++,
            raid: widget.raid,
            onRaidCleared: _onRaidCleared,
            onRaidWiped: _onRaidWiped,
            onRaidCreatureDown: _onRaidCreatureDown,
            onRaidExpired: _onRaidExpired,
            clearedGuardianCount: cleared,
            layoutOverride: buildRaidArenaLayout(widget.element),
          )
        : PlanetDungeonGame(
            element: widget.element,
            party: widget.party,
            initialStarMask: stars.starMaskFor(widget.element),
            initialDiscoveredCloudIds: stars.discoveredCloudsFor(
              widget.element,
            ),
            onStarEarned: _onStarEarned,
            onCloudDiscovered: _onCloudDiscovered,
            onGuardianIntro: _onGuardianIntro,
            onPlayerDown: _onPlayerDown,
            onChanged: () => _tick.value++,
            clearedGuardianCount: cleared,
          );

    if (!mounted) return;
    // Freeze the engine BEFORE the GameWidget ever enters the tree: Flame only
    // starts its game loop on attach when `paused` is false, so this costs
    // nothing and skips the loop entirely. `onLoad` is driven by the widget's
    // loader future, not by the loop, so the dungeon still loads its sprites,
    // its baked FX images and its sky shader while the dive plays — which was
    // always the point of the descent. It just doesn't also render 100 hidden
    // frames while doing it. Thawed in [_thawDungeon].
    game.pauseEngine();
    setState(() {
      _game = game;
      _ready = true;
    });

    _hudTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      // Skip while the descent covers the screen: the five `_tick` subtrees
      // (minimap, action cluster, swap rail, hint capsule, star tracker) are
      // invisible and, with the engine frozen, have nothing new to show.
      if (mounted && !_dungeonFrozen) _tick.value++;
      // A reward earned mid-fight waits here for the room to go quiet.
      if (mounted && _rewardPending) unawaited(_offerPendingRewardIfSafe());
    });
  }

  /// Draw the frozen dungeon exactly once, while the descent still hides it.
  ///
  /// This is the one hidden frame worth paying for: it is where the fullscreen
  /// sky `FragmentShader` gets compiled by the driver and every first-use paint
  /// path is walked, so the reveal doesn't pay for them. `stepTime: 0` means no
  /// simulation time passes — the dungeon is still at t=0 when you land, so the
  /// entry hint gets its full 5.5s instead of burning 1.7s of it unseen.
  void _warmFrozenDungeon() {
    if (_dungeonWarmed || !_dungeonFrozen) return;
    final game = _game;
    // `isAttached` is the precise signal: Flame only puts its render box in
    // the tree inside the loader future's `done` branch, so attached ⇒ loaded
    // and mounted.
    if (game == null || !game.isAttached) return;
    _dungeonWarmed = true;
    game.stepEngine(stepTime: 0);
  }

  /// Hand the frame budget back: the dungeon runs, and its HUD resumes
  /// ticking, from the instant the descent begins to fade.
  void _thawDungeon() {
    if (!_dungeonFrozen) return;
    _dungeonFrozen = false;
    // The descent overlay ignores pointers, so END RUN is reachable (blind)
    // mid-dive. If that already handed the pause to a reward popup, leave it
    // paused — the thaw only ever undoes the DESCENT'S freeze.
    if (_rewardStars != null || _showRaidReward) return;
    _game?.resumeEngine();
    // First frame the player can actually act on: the planet states its rule
    // now, once ever, rather than while the descent still covers the screen.
    _game?.beginRun();
  }

  /// Offers any unclaimed reward as soon as the room is safe. Called on star
  /// earn and again each time combat ends.
  Future<void> _offerPendingRewardIfSafe() async {
    if (!_rewardPending || _rewardStars != null || _isRaid) return;
    if (_game?.hasCombatTargets ?? false) return;
    // THE FLIGHT OWNS THIS MOMENT. The star is banked and _rewardPending set
    // the instant it is earned, and the HUD timer polls this every 100ms — so
    // the popup was RACING the animation and usually winning. That, not the
    // duration, is why the reward kept landing on top of the star. Only the
    // flight's completion (and the pause after it) may open the popup.
    if (_flyStar != null || _rewardHold != null) return;
    // THE RELIC COMES FIRST. Star 3 drops the guardian's relic on the spot and
    // it hovers, then expands away into your keeping over 3.6s. The popup was
    // opening on top of it, so the one animation the whole planet builds
    // toward played behind a dialog. The HUD timer polls this every 100ms, so
    // the reward simply arrives once the relic has finished being taken.
    if (_game?.relicDropActive ?? false) return;
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    );
    final pending = state.pendingRewards(widget.element);
    if (pending.isEmpty) {
      _rewardPending = false;
      return;
    }
    _rewardPending = false;
    _game?.pauseEngine();
    if (mounted) setState(() => _rewardStars = pending);
  }

  Future<void> _onStarEarned(int index) async {
    // Bank instantly: persist immediately so death/quit can't undo it.
    final prefs = await SharedPreferences.getInstance();
    final stars = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    ).withStar(widget.element, index);
    await prefs.setString(_starPrefsKey, stars.serialise());
    // No toast. The star flying to its slot IS the announcement, and the
    // popup that follows names it — a line of text between them was the game
    // saying in words what the player is already watching happen.
    // The payoff belongs next to the accomplishment, not at the exit door —
    // but it belongs AFTER the star lands, not on top of it. Marked pending
    // here and offered by the fly animation's completion listener; offering
    // it now put the popup over the animation the star had just earned.
    _rewardPending = true;
    // Fly a star from where it was earned up to its tracker slot.
    if (mounted) {
      final game = _game;
      Offset? start;
      if (game != null) {
        final screen = MediaQuery.of(context).size;
        final p = game.worldToScreen(game.lastStarEarnPosition);
        start = Offset(
          p.dx.clamp(30.0, screen.width - 30.0),
          p.dy.clamp(80.0, screen.height - 60.0),
        );
      }
      setState(() {
        _flyStar = index;
        _flyStart = start;
      });
      _flyCtrl.forward(from: 0);
    }
  }

  /// Persist a star's reward-claim flag the moment it is granted, so a
  /// force-quit mid-popup can't re-grant the same reward next run.
  Future<void> _onStarClaimed(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    ).withClaimed(widget.element, index);
    await prefs.setString(_starPrefsKey, state.serialise());
  }

  /// Debug-only: wipe this planet's persisted progress (stars, reward claims,
  /// discoveries) and restart the live run from the entrance for retesting.
  Future<void> _debugResetDungeon() async {
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    );
    final masks = Map<String, int>.from(state.starMasks)
      ..remove(widget.element);
    final claims = Map<String, int>.from(state.claimedMasks)
      ..remove(widget.element);
    final clouds = Map<String, Set<String>>.from(state.discoveredCloudIds)
      ..remove(widget.element);
    await prefs.setString(
      _starPrefsKey,
      PlanetStarState(
        starMasks: masks,
        claimedMasks: claims,
        discoveredCloudIds: clouds,
      ).serialise(),
    );
    _game?.debugResetDungeon();
    _showToast('Dungeon progress reset');
  }

  Future<void> _onCloudDiscovered(String cloudId) async {
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    ).withDiscoveredCloud(widget.element, cloudId);
    await prefs.setString(_starPrefsKey, state.serialise());
    // Hidden maxims (easter eggs) pay out the moment they're found — and
    // only once ever: a persisted discovery never re-fires this callback.
    if (cloudId.startsWith('egg:') && mounted) {
      await context.read<AlchemonsDatabase>().currencyDao.addGold(20);
      _showToast('A lost maxim — +20 gold');
    }
    // Vault caches: the treasure room's bottled essence, once ever.
    if (cloudId.startsWith('cache:') && mounted) {
      await context.read<AlchemonsDatabase>().currencyDao.addGold(5);
      _showToast('The vault yields — +5 gold');
    }
    // Family-gate stamps ("the seal remembers", §4): pure acknowledgement,
    // no gold — the reward IS the permanent chip on the descent panel.
    if (cloudId.startsWith('gate:') && mounted) {
      _showToast('The seal remembers — its need is etched at the gate');
    }
  }

  void _onPlayerDown() {
    if (!mounted) return;
    setState(() => _showDeath = true);
    _deathTimer?.cancel();
    _deathTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _showDeath = false);
    });
  }

  void _showToast(String msg) {
    if (!mounted) return;
    setState(() {
      _toast = msg;
      _toastVisible = true;
    });
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1800), () {
      // Fade out but KEEP the text: swapping the child mid-fade churns
      // layout/semantics (it contributed to the exit-time assert spam).
      if (mounted) setState(() => _toastVisible = false);
    });
  }

  /// The mystic's arrival banner: brief, chrome-styled, and NON-BLOCKING —
  /// combat is starting, so it ignores pointers and dismisses itself.
  void _onGuardianIntro(String mysticName, String line) {
    if (!mounted) return;
    setState(() {
      _guardianIntroName = mysticName;
      _guardianIntroLine = line;
      _guardianIntroVisible = true;
    });
    _guardianIntroTimer?.cancel();
    _guardianIntroTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) setState(() => _guardianIntroVisible = false);
    });
  }

  /// A raid party wipe ends the attempt. Nothing is banked — the raid window
  /// stays open, exactly as it does when you retreat.

  /// A raid death costs the Alchemon all of its stamina, not just the run.
  ///
  /// Permadeath within the attempt was already the rule; this makes the loss
  /// carry past it, so a wipe is a real setback rather than something you
  /// immediately re-queue with the same squad.
  Future<void> _onRaidCreatureDown(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    await db.creatureDao.updateStamina(
      instanceId: instanceId,
      staminaBars: 0,
      staminaLastUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  void _onRaidWiped() {
    if (!mounted) return;
    _showToast('The raid drives you out');
    _popDungeon(false);
  }

  /// The fight timer ran out with the guardian still standing.
  ///
  /// A raid is a DPS check as well as an endurance one: bring a squad that
  /// cannot finish and you lose the attempt, not just the beacon.

  void _onRaidExpired() {
    if (!mounted) return;
    _showToast('Out of time — the guardian holds');
    _popDungeon(false);
  }

  /// The raid's kill timer. Turns urgent under a minute.
  Widget _raidFightClock(PlanetDungeonGame game) {
    final left = game.raidTimeRemaining;
    if (left == null) return const SizedBox.shrink();
    final urgent = left.inSeconds <= 60;
    final colour = urgent ? const Color(0xFFE25544) : const Color(0xFFE4C16A);
    String two(int v) => v.toString().padLeft(2, '0');

    return CustomPaint(
      foregroundPainter: DungeonBracketPainter(
        color: colour,
        bracketSize: 7,
        strokeWidth: 1.2,
      ),
      child: Container(
        height: 30,
        padding: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: _C.bg.withValues(alpha: 0.82),
          border: Border.all(color: colour.withValues(alpha: 0.42)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 30, color: colour),
            const SizedBox(width: 10),
            Text(
              '${two(left.inMinutes)}:${two(left.inSeconds % 60)}',
              style: TextStyle(
                color: colour,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFeatures: const [FontFeature.tabularFigures()],
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onRaidCleared() {
    if (!mounted || _showRaidReward) return;
    _game?.pauseEngine();
    setState(() => _showRaidReward = true);
  }

  /// Quiesce everything that rebuilds on a timer/animation BEFORE popping the
  /// route — a tick landing mid-pop leaves dirty semantics on a deactivated
  /// subtree (the `!semantics.parentDataDirty` assert spam on exit).
  void _onDebugToolsChanged() {
    if (mounted) setState(() {});
  }

  void _prepareExit() {
    DebugSettingsService.enabledNotifier.removeListener(_onDebugToolsChanged);
    _hudTimer?.cancel();
    _hudTimer = null;
    _toastTimer?.cancel();
    _guardianIntroTimer?.cancel();
    _deathTimer?.cancel();
    _flyCtrl.stop();
    _introTicker.stop();
  }

  void _popDungeon(Object? result) {
    if (!mounted) return;
    _prepareExit();
    Navigator.of(context).pop(result);
  }

  Future<void> _endRun() async {
    if (_isRaid) {
      // Raids bank nothing on retreat; the window stays open for retries.
      _popDungeon(false);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    );
    final pending = state.pendingRewards(widget.element);
    if (pending.isEmpty) {
      _popDungeon(_game?.starMask ?? 0);
      return;
    }
    // Show the reward popup; the game keeps rendering behind it.
    _game?.pauseEngine();
    if (mounted) setState(() => _rewardStars = pending);
  }

  /// Called when the reward popup's Continue is tapped: mark the granted stars
  /// claimed (rewards already granted inside the popup), then leave.
  Future<void> _finishRewards() async {
    final claimed = _rewardStars ?? const <int>[];
    final prefs = await SharedPreferences.getInstance();
    var state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    );
    for (final s in claimed) {
      state = state.withClaimed(widget.element, s);
    }
    await prefs.setString(_starPrefsKey, state.serialise());

    // Close the popup and hand the dungeon back. This used to pop the route —
    // a leftover from when rewards were only shown at the exit door. Once the
    // payoff moved next to the accomplishment, claiming Star 1 was throwing
    // the player out of the planet mid-run. Leaving is what END RUN is for.
    if (!mounted) return;
    setState(() => _rewardStars = null);
    _game?.resumeEngine();
  }

  @override
  void dispose() {
    // Belt and braces: _prepareExit drops it on the normal pop, but a screen
    // torn down another way must not leave a listener on the static notifier.
    DebugSettingsService.enabledNotifier.removeListener(_onDebugToolsChanged);
    _introTicker.dispose();
    _introTime.dispose();
    _hudTimer?.cancel();
    _deathTimer?.cancel();
    _toastTimer?.cancel();
    _guardianIntroTimer?.cancel();
    _rewardHold?.cancel();
    _flyCtrl.dispose();
    _tick.dispose();
    super.dispose();
  }

  static const double _starSlotSpacing = 36.0;

  /// Screen-space centre of star slot [i] (0..2) in the top tracker.
  Offset _slotOffset(Size screen, double topInset, int i) =>
      Offset(screen.width / 2 + (i - 1) * _starSlotSpacing, topInset + 21);

  /// The shared §5.6 popup chrome at banner scale: bracket corners over a
  /// dark parchment panel. The reward popups carry the full modal version of
  /// this language; toasts, the guardian intro and the death overlay carry
  /// this compact one. No blur, no glow — restrained by design.
  Widget _chromeBanner({
    required Widget child,
    Color accent = _C.amberBright,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 18,
      vertical: 10,
    ),
  }) {
    return CustomPaint(
      foregroundPainter: DungeonBracketPainter(
        color: accent,
        bracketSize: 9,
        strokeWidth: 1.4,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _C.panel.withValues(alpha: 0.92),
          border: Border.all(color: _C.border, width: 1.1),
        ),
        child: child,
      ),
    );
  }

  /// The mystic's calling card: its name over its one arrival line.
  Widget _guardianIntroBanner() {
    return _chromeBanner(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            (_guardianIntroName ?? '').toUpperCase(),
            style: const TextStyle(
              color: _C.amberBright,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.6,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _guardianIntroLine ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _C.text.withValues(alpha: 0.88),
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.4,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = _game;
    if (!_ready || game == null) {
      return Scaffold(backgroundColor: _C.bg, body: _descentIntro());
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: game)),

            // Drag to look around, but only while pulled back. A survey with
            // no panning is a fixed portrait of wherever the party happens to
            // stand, which is not much use on the big rooms it exists for.
            // Off-survey this is absent entirely, so it can never eat a tap.
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: _tick,
                builder: (_, __, ___) => game.surveying
                    ? GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onPanUpdate: (d) => game.panSurvey(d.delta),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

            // Minimap (top-left).
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _tick,
                    builder: (_, __, ___) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showFullMap = true),
                      child: DungeonMiniMap(game: game, boxSize: 106),
                    ),
                  ),
                ),
              ),
            ),

            // Top-right controls.
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _pillButton(
                        'END RUN',
                        _C.danger,
                        _endRun,
                        icon: Icons.logout_rounded,
                      ),
                      const SizedBox(height: 8),
                      _iconButton(
                        Icons.workspaces_rounded,
                        _C.amber,
                        () => game.regroup(),
                        semantics: 'Regroup the party',
                      ),
                      // Pull back and read the whole room, and drag to look
                      // around while pulled back. Any movement snaps it home
                      // again, so it is a look rather than a mode.
                      ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) => _iconButton(
                          game.surveying
                              ? Icons.zoom_in_rounded
                              : Icons.zoom_out_rounded,
                          game.surveying ? _C.amber : _C.cyan,
                          () {
                            HapticFeedback.selectionClick();
                            game.toggleSurvey();
                          },
                          semantics: game.surveying
                              ? 'Close in'
                              : 'Survey the room',
                        ),
                      ),
                      // The only thing in the dungeon that speaks. It reads
                      // the room — and, when the world has just turned the
                      // player away, it says WHY, which is the question they
                      // actually pressed it to ask.
                      //
                      // It brightens while it has a refusal waiting, so the
                      // affordance advertises itself exactly when it has
                      // something worth saying. That pulse is also how a
                      // player discovers the button exists at all, now that
                      // nothing else talks.
                      ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) => _iconButton(
                          game.hintHasAnswer
                              ? Icons.help_rounded
                              : Icons.help_outline_rounded,
                          game.hintHasAnswer ? _C.amber : _C.cyan,
                          () {
                            HapticFeedback.selectionClick();
                            game.askForRoomHint();
                          },
                          semantics: 'Hint',
                        ),
                      ),
                      // Re-lay this room's puzzle from scratch. Shows in
                      // Steam's molten chambers and Fire's garth — the two
                      // places a run can be spent into a dead end without
                      // dying. Reacts to room changes.
                      ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) => game.canRestartRoom
                            ? _iconButton(
                                Icons.restart_alt_rounded,
                                _C.cyan,
                                () => game.restartRoom(),
                                semantics: 'Re-lay this room',
                              )
                            : const SizedBox.shrink(),
                      ),
                      // Developer tools: the persisted switch OR a debug
                      // build, so the reset is reachable on the device where
                      // the playtesting actually happens.
                      if (DebugSettingsService.toolsVisible && !_isRaid)
                        _iconButton(
                          Icons.refresh_rounded,
                          _C.cyan,
                          () => unawaited(_debugResetDungeon()),
                          semantics: 'Debug: reset stars',
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Joystick (bottom-left).
            Positioned(
              bottom: 24,
              left: 16,
              child: SafeArea(
                child: VirtualJoystick(
                  onDirectionChanged: (dir) =>
                      game.joystickDirection = dir ?? Offset.zero,
                ),
              ),
            ),

            // Action button + creature rail, stacked bottom-right (right
            // thumb), clear of the bottom-left joystick.
            Positioned(
              bottom: 24,
              right: 16,
              child: SafeArea(
                child: ValueListenableBuilder<int>(
                  valueListenable: _tick,
                  builder: (_, __, ___) => Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Nothing to act on in this room and nothing alive in
                      // it: the cluster would be a control that answers every
                      // press with a shrug. Corridors are for walking.
                      if (game.roomOffersAction) ...[
                        _actionCluster(game),
                        const SizedBox(height: 12),
                      ],
                      _swapRail(game),
                    ],
                  ),
                ),
              ),
            ),

            // The hint capsule (top-center, below the star tracker). One
            // capsule, one line, ever — styled by its channel (§5.6).
            //
            // It clears the other two things in the top band rather than
            // lying across them: it starts below the minimap, and stops
            // short of the tool column on the right. A room primer is
            // several lines long and was covering both.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 124, left: 24, right: 64),
                  child: ExcludeSemantics(
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) {
                          final hint = game.hintText;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: hint == null
                                ? const SizedBox.shrink()
                                : _hintCapsule(hint, game.hintChannel),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Death overlay — same chrome language as every other popup
            // occasion (§5.6), same behavior as before (brief, non-blocking).
            if (_showDeath)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: const Color(0x66100000),
                    child: Center(
                      child: _chromeBanner(
                        accent: _C.ember,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 26,
                          vertical: 18,
                        ),
                        child: const Text(
                          'YOU FELL\nRESTARTING AT THE GATE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Event toast (e.g. "Star secured") — mid-screen, fades. Kept
            // out of the semantics tree (decorative) and structurally stable
            // while fading: both matter for clean route pops.
            Positioned(
              bottom: 0,
              top: 0,
              left: 0,
              right: 0,
              child: ExcludeSemantics(
                child: IgnorePointer(
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _toastVisible && _toast != null ? 1.0 : 0.0,
                      child: _toast == null
                          ? const SizedBox.shrink()
                          : _chromeBanner(
                              child: Text(
                                '✦  ${_toast ?? ''}',
                                style: const TextStyle(
                                  color: _C.amberBright,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),

            // Guardian-intro banner (§5.6): the mystic's arrival, in the
            // shared chrome — brief, auto-dismissing, and NEVER blocking
            // (combat is starting underneath it). Sits below the hint
            // capsule, above the fray.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 104, left: 24, right: 24),
                  child: ExcludeSemantics(
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity:
                              _guardianIntroVisible &&
                                  _guardianIntroName != null
                              ? 1.0
                              : 0.0,
                          child: _guardianIntroName == null
                              ? const SizedBox.shrink()
                              : _guardianIntroBanner(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Top-center: the star tracker, or the raid countdown chip.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _tick,
                      builder: (_, __, ___) {
                        // In a raid this is the FIGHT clock, not the world
                        // window. The window countdown belonged to the
                        // decision to enter and was removed; this one you can
                        // act on, because running it out loses the attempt.
                        if (_isRaid) return _raidFightClock(game);
                        // Star tracker + the planet's progress readout, one
                        // glanceable row (§5.6: counters are state, not
                        // speech, so they never touch the capsule).
                        final readout = game.progressReadout;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _starTracker(game),
                            if (readout != null) _progressReadout(readout),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // Flying star (earn animation) toward its tracker slot.
            if (_flyStar != null) _buildFlyingStar(context),

            if (_showFullMap) _buildFullMapOverlay(game),

            // Descent intro overlay — fades out once the dungeon is live.
            if (_showIntro)
              Positioned.fill(child: IgnorePointer(child: _descentIntro())),

            // End-run reward popup.
            if (_rewardStars != null)
              DungeonRewardPopup(
                element: widget.element,
                stars: _rewardStars!,
                starNames: [
                  for (final i in _rewardStars!)
                    kPlanetDungeonLayouts[widget.element]?.stars
                            .elementAtOrNull(i)
                            ?.name ??
                        '',
                ],
                db: context.read<AlchemonsDatabase>(),
                onStarClaimed: _onStarClaimed,
                onContinue: _finishRewards,
              ),

            // Raid victory popup.
            if (_showRaidReward)
              RaidRewardPopup(
                element: widget.element,
                db: context.read<AlchemonsDatabase>(),
                onGranted: () async => widget.onRaidCleared?.call(),
                onContinue: () => _popDungeon(true),
              ),
          ],
        ),
      ),
    );
  }

  /// Raid HUD chip: which planet is overrun and how long the window has left.
  ///
  /// Same chrome as the space-view raid strip — hard edges, bracketed corners,
  /// an ember accent rail — so the raid reads as one thing across both views.

  /// The descent: diving through the planet's cloud deck — element-tinted
  /// cloud rings rushing past, converging wind lines, and the dungeon's
  /// title card in HUD chrome. Doubles as the loading screen.
  Widget _descentIntro() {
    final accent = elementColor(widget.element);
    // KeyedSubtree + a GlobalKey: when `_ready` flips, the screen's root
    // changes shape (loading Scaffold → PopScope/Stack) and the descent moves
    // with it. The global key REPARENTS this subtree instead of destroying and
    // rebuilding the painter's render objects mid-dive.
    return KeyedSubtree(
      key: _descentKey,
      child: RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: _introTime,
          builder: (_, elapsed, _) => _descentIntroFrame(elapsed, accent),
        ),
      ),
    );
  }

  Widget _descentIntroFrame(double elapsed, Color accent) {
    final opacity = _introFadeStart == null
        ? 1.0
        : (1.0 - (elapsed - _introFadeStart!) / 0.5).clamp(0.0, 1.0);
    final reveal = (elapsed / _descentSeconds).clamp(0.0, 1.0);
    final titleIn = ((reveal - 0.18) / 0.3).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: DescentPainter(
              elapsed: elapsed,
              element: widget.element,
              accent: accent,
            ),
          ),
          Center(
            child: Opacity(
              opacity: titleIn,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DESCENDING',
                    style: TextStyle(
                      color: _C.text.withValues(alpha: 0.85),
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    kPlanetDungeonLayouts[widget.element]?.descentTitle ??
                        widget.element,
                    style: const TextStyle(
                      color: _C.amberBright,
                      fontFamily: 'monospace',
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.6,
                      shadows: [Shadow(color: _C.amberBright, blurRadius: 14)],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullMapOverlay(PlanetDungeonGame game) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showFullMap = false),
        child: Container(
          color: Colors.black.withValues(alpha: 0.48),
          child: SafeArea(
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: _tick,
                builder: (_, __, ___) => GestureDetector(
                  onTap: () {},
                  child: DungeonFullMap(
                    game: game,
                    onClose: () => setState(() => _showFullMap = false),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The hint capsule, styled by channel (§5.6). Restraint is the point:
  /// same pill, same size, same place — only the accent (a hairline rule and
  /// a small glyph) and the text weight change, so a refusal reads as a
  /// refusal and flavor stays in the background. Never stacks.
  Widget _hintCapsule(String hint, DungeonHintChannel channel) {
    final (Color accent, IconData? glyph, double textAlpha) = switch (channel) {
      // A refusal: ember-warm, glyphed, the firmest of the four.
      DungeonHintChannel.blocked => (_C.ember, Icons.block_flipped, 0.96),
      // A Mask reading: the same cold light the reveal pulse uses.
      DungeonHintChannel.insight => (_C.cyan, Icons.visibility_outlined, 0.96),
      // What the room wants: the house amber, unglyphed.
      DungeonHintChannel.objective => (_C.amber, null, 0.92),
      // Flavor: no rule, no glyph, sits back.
      DungeonHintChannel.ambient => (Colors.transparent, null, 0.74),
    };
    final ruled = channel != DungeonHintChannel.ambient;
    return Container(
      key: ValueKey('${channel.name}:$hint'),
      padding: EdgeInsets.only(
        left: glyph == null ? 14 : 11,
        right: 14,
        top: 7,
        bottom: 7,
      ),
      decoration: BoxDecoration(
        color: _C.bg.withValues(
          alpha: channel == DungeonHintChannel.ambient ? 0.5 : 0.68,
        ),
        borderRadius: BorderRadius.circular(20),
        border: ruled
            ? Border.all(
                color: accent.withValues(
                  alpha: channel == DungeonHintChannel.blocked ? 0.6 : 0.4,
                ),
                width: 1,
              )
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 12, color: accent.withValues(alpha: 0.9)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _C.text.withValues(alpha: textAlpha),
                fontSize: 12,
                fontWeight: channel == DungeonHintChannel.blocked
                    ? FontWeight.w600
                    : FontWeight.w500,
                letterSpacing: 0.3,
                height: 1.3,
                fontStyle: channel == DungeonHintChannel.ambient
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PROGRESS READOUT (§5.6) — a persistent, glanceable counter riding
  /// alongside the star tracker. Generalized from the per-planet gauges, so
  /// counters never have to borrow the hint capsule to be seen.
  Widget _progressReadout(DungeonProgressReadout r) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                r.label,
                style: TextStyle(
                  color: _C.amber.withValues(alpha: 0.7),
                  fontFamily: 'monospace',
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                r.value,
                style: const TextStyle(
                  color: _C.amberBright,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                  height: 1,
                ),
              ),
            ],
          ),
          if (r.fraction != null) ...[
            const SizedBox(height: 3),
            SizedBox(
              width: 48,
              height: 2,
              child: ColoredBox(
                color: _C.border.withValues(alpha: 0.35),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: r.fraction!.clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: const ColoredBox(color: _C.amberBright),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _starTracker(PlanetDungeonGame game) {
    // Compact pill — sized so it clears the minimap (left) and the action
    // pills (right) on narrow phones instead of colliding with them.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < game.totalStars; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(
                game.hasStar(i)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                // Hide the slot that's mid-flight until it lands.
                color: (game.hasStar(i) && _flyStar != i)
                    ? _C.amberBright
                    : _C.border.withValues(alpha: 0.8),
                size: 20,
                shadows: (game.hasStar(i) && _flyStar != i)
                    ? const [Shadow(color: _C.amberBright, blurRadius: 8)]
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFlyingStar(BuildContext context) {
    final media = MediaQuery.of(context);
    final screen = media.size;
    final topInset = media.padding.top;
    final target = _slotOffset(screen, topInset, _flyStar!);
    final start = _flyStart ?? Offset(screen.width / 2, screen.height * 0.55);
    return AnimatedBuilder(
      animation: _flyCtrl,
      builder: (context, _) {
        final v = _flyCtrl.value;

        // BEAT 1 — BIRTH. The star swells where it was earned and STAYS there.
        // The old flight left immediately, so a star earned mid-fight was a
        // streak in the corner of the eye and then a dialog: players reported
        // not knowing they had earned one. The hold is the whole fix; the
        // flight is just how it gets to the tracker afterwards.
        final born = Curves.easeOutBack.transform(
          (v / _kStarBirth).clamp(0.0, 1.0),
        );

        // BEAT 2 — FLIGHT.
        final flyT = Curves.easeInOut.transform(
          ((v - _kStarBirth) / (_kStarLand - _kStarBirth)).clamp(0.0, 1.0),
        );
        final pos = Offset.lerp(start, target, flyT)!;

        // BEAT 3 — SEATING. A short pulse as it lands, so the tracker slot
        // reads as having RECEIVED something rather than the star just
        // evaporating next to it.
        final landT = ((v - _kStarLand) / (1.0 - _kStarLand)).clamp(0.0, 1.0);
        final seat = landT == 0 ? 0.0 : Curves.easeOutCubic.transform(landT);

        // Big while held, shrinking as it travels, one last flick on landing.
        final scale =
            (1.9 * born - 1.15 * flyT + 0.28 * (seat * (1 - seat) * 4)).clamp(
              0.0,
              2.0,
            );

        // Only fades at the very end, and only after it has seated.
        final opacity = landT < 0.55 ? 1.0 : 1.0 - (landT - 0.55) / 0.45;
        return Positioned(
          left: pos.dx - 22,
          top: pos.dy - 22,
          child: ExcludeSemantics(
            child: IgnorePointer(
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: const Icon(
                    Icons.star_rounded,
                    color: _C.amberBright,
                    size: 44,
                    shadows: [Shadow(color: _C.amberBright, blurRadius: 20)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionCluster(PlanetDungeonGame game) {
    final ability = game.activeAbility;
    final enabled = game.canAct;
    final glide = ability == DungeonAbility.aerialTraversal;
    final active = glide && game.flightActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carried-echo drop control (only while holding one). A stadium
        // rather than a circle: the cloud's NAME is the point of it, and it
        // sizes to that name instead of sitting in a fixed 154px box.
        if (game.carriedCloudType != null) ...[
          GestureDetector(
            onTap: game.dropCarriedCloud,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _C.bg.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _C.cyan.withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.outbond_rounded, color: _C.cyan, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'DROP ${game.carriedCloudType!.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.cyan,
                      fontFamily: 'monospace',
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        // The utility verb, centred over the pair. It used to be a 154px bar
        // whose label was the literal word "UTILITY" on every planet — a
        // whole line of chrome spending itself on a word that never changed
        // and named nothing. The glyph names the VERB instead, which is the
        // thing the dungeon is actually teaching.
        if (!_isRaid) ...[
          _utilityButton(
            ability: ability,
            enabled: enabled,
            active: active,
            // While gliding, the rim IS the flight meter — which retires the
            // separate 90x6 bar that used to float above the pad.
            charge: glide ? game.flightFraction : 1.0,
            onTap: game.activateAbility,
          ),
          const SizedBox(height: 6),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CONTROL FEEDBACK lives here, not in the hint capsule (§5.6):
            // the rim shows the wait, the countdown names it, and a refused
            // press throws a flare off the button that refused.
            _combatButton(
              label: 'ATTACK',
              icon: Icons.gps_fixed_rounded,
              cooldownText: game.autoCooldownFraction > 0.02
                  ? game.autoCooldownLabel
                  : null,
              cooldownFraction: game.autoCooldownFraction,
              deniedPulse: game.autoDeniedPulse,
              color: _C.cyan,
              onTap: game.activateAutoAttack,
            ),
            const SizedBox(width: 6),
            _combatButton(
              label: game.abilityIsPassive ? 'PASSIVE' : 'SPECIAL',
              icon: game.abilityIsPassive
                  ? Icons.all_inclusive_rounded
                  : Icons.auto_awesome_rounded,
              cooldownText: game.abilityCooldownFraction > 0.02
                  ? game.abilityCooldownLabel
                  : null,
              // A passive special has no cast: the button reads spent, not
              // waiting — no arc, permanently dimmed.
              cooldownFraction: game.abilityIsPassive
                  ? 0
                  : game.abilityCooldownFraction,
              dimmed: game.abilityIsPassive,
              deniedPulse: game.abilityDeniedPulse,
              color: _C.amberBright,
              onTap: game.activateCombatAbility,
            ),
          ],
        ),
      ],
    );
  }

  /// The glyph for a family's dungeon verb. The utility button wears it, so
  /// swapping to another creature visibly changes what the button will DO.
  static IconData _abilityIcon(DungeonAbility a) {
    switch (a) {
      case DungeonAbility.smallAccess:
        return Icons.compress_rounded; // squeeze through
      case DungeonAbility.terrainTrail:
        return Icons.terrain_rounded; // lay ground
      case DungeonAbility.heavyForce:
        return Icons.fitness_center_rounded; // shove, seat, break
      case DungeonAbility.insight:
        return Icons.visibility_rounded; // read the room
      case DungeonAbility.aerialTraversal:
        return Icons.paragliding_rounded; // glide
      case DungeonAbility.ancientStabilize:
        return Icons.anchor_rounded; // hold the old machine steady
      case DungeonAbility.guardianRelic:
      case DungeonAbility.none:
        return Icons.auto_fix_high_rounded;
    }
  }

  /// The round chassis every action button is built on: rim, dark dome, glyph.
  Widget _roundAction({
    required double diameter,
    required IconData icon,
    required Color color,
    required double charge,
    required bool spent,
    required String semantics,
    required VoidCallback? onTap,
    double denied = 0,
    String? caption,
    int teeth = 0,
    double iconSize = 22,
  }) {
    // The rim's flare needs room outside the dome, and the extra ring doubles
    // as slop on the tap target.
    final box = diameter + 14;
    final ink = spent ? _C.text.withValues(alpha: 0.42) : color;
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: box,
          height: box,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(box),
                painter: _ActionRingPainter(
                  color: color,
                  charge: charge,
                  spent: spent,
                  denied: denied,
                  teeth: teeth,
                  thickness: diameter >= 70 ? 3.2 : 2.6,
                ),
              ),
              Container(
                width: diameter,
                height: diameter,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // A lit dome rather than a flat panel: the light sits up and
                  // left, so the button reads as a physical thing to hit.
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 1.05,
                    colors: [
                      color.withValues(alpha: spent ? 0.05 : 0.20),
                      _C.bg2.withValues(alpha: 0.94),
                      const Color(0xFF04060A),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  border: Border.all(
                    color: color.withValues(alpha: spent ? 0.22 : 0.5),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: ink,
                      size: iconSize,
                      shadows: spent
                          ? null
                          : [
                              Shadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        caption,
                        style: TextStyle(
                          color: spent
                              ? _C.text.withValues(alpha: 0.58)
                              : Colors.white.withValues(alpha: 0.92),
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.05,
                          height: 1,
                        ),
                      ),
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

  Widget _utilityButton({
    required DungeonAbility ability,
    required bool enabled,
    required bool active,
    required double charge,
    required VoidCallback onTap,
  }) {
    final color = active ? _C.cyan : _C.amberBright;
    return _roundAction(
      diameter: 54,
      icon: _abilityIcon(ability),
      color: enabled ? color : _C.border,
      charge: enabled ? charge : 0,
      spent: !enabled,
      teeth: 0, // the verb is not a weapon; it stays smooth
      iconSize: 20,
      semantics: 'Use ability',
      onTap: enabled ? onTap : null,
    );
  }

  Widget _combatButton({
    required String label,
    required IconData icon,
    required double cooldownFraction,
    required Color color,
    required VoidCallback onTap,
    String? cooldownText,
    double deniedPulse = 0,
    bool dimmed = false,
  }) {
    final cooling = cooldownFraction > 0.02;
    final spent = cooling || dimmed;
    return _roundAction(
      diameter: 74,
      icon: icon,
      color: color,
      // The rim fills as the wait runs out, so "ready" is a whole circle.
      charge: dimmed ? 0 : 1 - cooldownFraction.clamp(0.0, 1.0),
      spent: spent,
      denied: deniedPulse.clamp(0.0, 1.0),
      teeth: 12,
      iconSize: 24,
      // While cooling the caption IS the countdown — same slot, so the button
      // never grows a badge that overlaps its own rim.
      caption: cooldownText ?? label,
      semantics: label,
      onTap: onTap,
    );
  }

  Widget _swapRail(PlanetDungeonGame game) {
    // A subtle backing strip groups the chips into one control.
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _C.border.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < game.creatures.length; i++)
            Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
              child: _creatureChip(game, i),
            ),
        ],
      ),
    );
  }

  Widget _creatureChip(PlanetDungeonGame game, int i) {
    final c = game.creatures[i];
    final isActive = i == game.activeIndex;
    final down = !c.alive;
    final ec = elementColor(c.member.element);
    return GestureDetector(
      onTap: () => game.setActive(i),
      child: Container(
        width: 52,
        height: 60,
        decoration: BoxDecoration(
          color: _C.panel.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: down
                ? _C.danger.withValues(alpha: 0.55)
                : isActive
                ? _C.amberBright
                : _C.border.withValues(alpha: 0.6),
            width: isActive ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(7),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: down ? 0.32 : 1.0,
                      child: c.member.imagePath != null
                          ? Image.asset(c.member.imagePath!, fit: BoxFit.cover)
                          : ColoredBox(color: ec.withValues(alpha: 0.4)),
                    ),
                    if (down)
                      const Center(
                        child: Text(
                          'DOWN',
                          style: TextStyle(
                            color: _C.danger,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // HP bar.
            Container(
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: c.hpFraction,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.hpFraction > 0.3 ? _C.amber : _C.danger,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top-right command buttons in the HUD's bracket-corner chrome (same
  /// language as UTILITY / ATTACK / SPECIAL). Uniform width keeps the
  /// stacked column reading as one control group.
  /// A round icon-only control, 36px.
  ///
  /// The top-right stack used to be six full-width pills — a 112px strip of
  /// the play field given over to chrome. Only the destructive action needs
  /// its word; the tools are recognisable by glyph, so they collapse to
  /// circles and the column narrows to a third of its width.
  Widget _iconButton(
    IconData icon,
    Color color,
    VoidCallback onTap, {
    required String semantics,
  }) {
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        // The circle is 36 but the tap target is padded out to 44, so a
        // slimmer button is not a harder one to hit.
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _C.bg.withValues(alpha: 0.82),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 9),
              ],
            ),
            child: Icon(
              icon,
              color: color,
              size: 17,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.55), blurRadius: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton(
    String label,
    Color color,
    VoidCallback onTap, {
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _HudBracketPainter(
          color: color.withValues(alpha: 0.7),
          bracketSize: 6,
          strokeWidth: 1.1,
        ),
        child: Container(
          // Sizes to its label. It was a fixed 112 box, which both wasted a
          // strip of the play field on short words and overflowed on long
          // ones ("RE-LAY ROOM" ran 8.7px past its own border).
          constraints: const BoxConstraints(minWidth: 76),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _C.bg.withValues(alpha: 0.82),
            border: Border.all(color: _C.border.withValues(alpha: 0.4)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.10), blurRadius: 10),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: color,
                  size: 12,
                  shadows: [
                    Shadow(color: color.withValues(alpha: 0.55), blurRadius: 7),
                  ],
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cloud-dive painter: rings of element-tinted puffs scale outward past the
/// camera while wind lines converge — the feel of falling through a cloud
/// deck toward the spire.
