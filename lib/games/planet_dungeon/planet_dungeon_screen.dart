import 'package:alchemons/audio/scene_ambience.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
import 'package:alchemons/audio/audio.dart';
// lib/games/planet_dungeon/planet_dungeon_screen.dart
//
// Flutter wrapper around PlanetDungeonGame: joystick movement, a swap-control
// rail for the creatures you brought, Regroup / End Run, the room minimap, a
// death overlay and an instant star-banked toast. Dark / alchemical chrome.

import 'dart:async';
import 'dart:math' show min, sin;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_minimap.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/games/cosmic/raid_state.dart';
import 'package:alchemons/games/planet_dungeon/raid_rewards.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_data.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_portal.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_game.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_reward_popup.dart';
import 'package:alchemons/games/planet_dungeon/planet_dungeon_verbs.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/screens/story/beauty_mask_reveal.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/screens/cosmic/widgets/virtual_joystick.dart';
import 'package:flame/game.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/games/planet_dungeon/dungeon_debug_party.dart'
    show riteCaptivesFrom, riteSpeciesFrom;
import 'package:alchemons/services/creature_repository.dart'
    show CreatureCatalog;
import 'package:shared_preferences/shared_preferences.dart';

class _C {
  static const bg = Color(0xFF080808);
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

const _starPrefsKey = 'cosmic_planet_stars';

/// Set once the first-descent controls walkthrough has been dismissed. Global,
/// not per planet: the buttons mean the same thing on every world.
const _controlsTutorialSeenKey = 'dungeon_controls_tutorial_seen_v1';

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
    this.revealBeautyMask = false,
    this.revealReady,
    this.revealed,
  });

  final String element;
  final List<CosmicPartyMember> party;
  final bool revealBeautyMask;

  /// Non-null → this descent is a raid: one open arena, an empowered
  /// guardian, raid loot. Stars/clouds are neither read nor written.
  final RaidConfig? raid;

  /// Persist-the-clear callback (RaidService.markLevelCleared), awaited right
  /// after the loot is granted.
  final Future<void> Function()? onRaidCleared;

  /// For the way down from space (PlanetDescentPassage), which is then the
  /// loading screen: the dungeon's own intro is left out, [revealReady] is
  /// set once the dungeon is built and its first frame warmed, and it stays
  /// frozen until [revealed] says the passage has shown it.
  final ValueNotifier<bool>? revealReady;
  final ValueListenable<bool>? revealed;

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

  // Descent intro: a glyph portal spelling the dungeon's name that doubles as
  // the loading screen (no spinner, no route gap).
  static const double _descentSeconds = kPortalSeconds;
  late final Ticker _introTicker;
  // Drives ONLY the descent painter/title — a full setState per frame here
  // used to rebuild the whole screen (including the live game) at 60fps.
  final ValueNotifier<double> _introTime = ValueNotifier<double>(0);
  double? _introFadeStart;
  bool _showIntro = true;
  bool _showBeautyMask = false;

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

  /// FIRST DESCENT ONLY: a two-beat walkthrough of the action pad — UTILITY
  /// works the dungeon, ATTACK and SPECIAL are for fights. Assumed seen until
  /// prefs say otherwise, so a slow prefs read never flashes it at a veteran.
  bool _controlsTutorialSeen = true;

  /// Which beat of the walkthrough is showing, or null when it is not. While
  /// it is non-null the engine stays paused and the run has not begun.
  int? _tutorialStep;
  final GlobalKey _tutUtilityKey = GlobalKey(debugLabel: 'tutUtility');
  final GlobalKey _tutCombatKey = GlobalKey(debugLabel: 'tutCombat');

  AudioController? _soundController;

  @override
  void initState() {
    super.initState();
    _soundController = context.audio;
    context.sound(SoundCue.cosmicPlanetEnter, owner: this);
    _showBeautyMask = widget.revealBeautyMask;
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
    _showIntro = !_underPassage;
    _introTicker = createTicker((elapsed) {
      if (!mounted) return;
      if (_underPassage) {
        _tickUnderPassage();
        return;
      }
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
    // Blood: the four captives the Rites hold are real species, one per
    // classical element (read now, before the first await).
    final captives = widget.element == 'Blood' && !_isRaid
        ? riteCaptivesFrom(context.read<CreatureCatalog>())
        : const <CosmicPartyMember>[];
    // …and the species a fusion in the Heart can wear.
    final species = widget.element == 'Blood' && !_isRaid
        ? riteSpeciesFrom(context.read<CreatureCatalog>())
        : const <String, List<CosmicPartyMember>>{};
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
    _controlsTutorialSeen =
        _isRaid || (prefs.getBool(_controlsTutorialSeenKey) ?? false);

    // The campaign difficulty clock: every OTHER planet's fallen guardian
    // hardens this run's enemies (and especially its guardian).
    final cleared = stars.guardiansDefeated(excluding: widget.element);

    final game = _isRaid
        ? PlanetDungeonGame(
            element: widget.element,
            party: widget.party,
            initialStarMask: 0,
            onSound: (cue) {
              if (mounted) context.sound(cue, owner: this);
            },
            onStarEarned: (_) {},
            onGuardianIntro: _onGuardianIntro,
            onPlayerDown: _onPlayerDown,
            onChanged: () => _tick.value++,
            raid: widget.raid,
            onRaidCleared: _onRaidCleared,
            onRaidWiped: _onRaidWiped,
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
            onSound: (cue) {
              if (mounted) context.sound(cue, owner: this);
            },
            onStarEarned: _onStarEarned,
            onCloudDiscovered: _onCloudDiscovered,
            onGuardianIntro: _onGuardianIntro,
            onPlayerDown: _onPlayerDown,
            onChanged: () => _tick.value++,
            clearedGuardianCount: cleared,
            riteCaptives: captives,
            riteSpecies: species,
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
    // HAPTICS: the game says what happened; the phone says it to the hand,
    // unless the player switched it off in Settings.
    game.onHaptic = (kind) {
      if (!mounted) return;
      final audio = context.audio;
      if (audio != null && !audio.hapticsEnabled) return;
      switch (kind) {
        case DungeonHaptic.success:
          HapticFeedback.lightImpact();
        case DungeonHaptic.refuse:
          // Two quick taps: "no" feels different from "yes".
          HapticFeedback.lightImpact();
          Future<void>.delayed(
            const Duration(milliseconds: 90),
            HapticFeedback.lightImpact,
          );
        case DungeonHaptic.hit:
          HapticFeedback.mediumImpact();
        case DungeonHaptic.big:
          HapticFeedback.heavyImpact();
        case DungeonHaptic.heartbeat:
          // Lub-DUB: the heavy knock, then the softer echo 0.2s behind it
          // (the Blood portal's double thump, and the glows that beat with
          // it in the dungeon).
          HapticFeedback.heavyImpact();
          Future<void>.delayed(
            const Duration(milliseconds: 200),
            HapticFeedback.mediumImpact,
          );
      }
    };
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

  /// Whether the way down from space is covering this screen (and stands in
  /// for its intro).
  bool get _underPassage => widget.revealReady != null;

  /// Under the passage: warm the frozen dungeon, say it is ready, and thaw it
  /// once the passage has shown it.
  void _tickUnderPassage() {
    _warmFrozenDungeon();
    if (_dungeonWarmed) widget.revealReady?.value = true;
    if (widget.revealed?.value ?? false) {
      _introTicker.stop();
      _thawDungeon();
    }
  }

  /// Draw the frozen dungeon exactly once, while the descent still hides it.
  ///
  /// This is the one hidden frame worth paying for: it is where the fullscreen
  /// sky `FragmentShader` gets compiled by the driver and every first-use paint
  /// path is walked, so the reveal doesn't pay for them. `stepTime: 0` means no
  /// simulation time passes — the dungeon is still at t=0 when you land.
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
    if (_showBeautyMask) return;
    if (!_dungeonFrozen) return;
    _dungeonFrozen = false;
    // The descent overlay ignores pointers, so END RUN is reachable (blind)
    // mid-dive. If that already handed the pause to the RAID popup, leave it
    // paused — the thaw only ever undoes the DESCENT'S freeze. The star
    // reward no longer pauses at all, so it must not be listed here: doing so
    // would skip `beginRun()` and leave the whole dungeon frozen.
    if (_showRaidReward) return;
    // The very first descent stops here for the controls walkthrough. The
    // engine stays paused and the run has not begun, so nothing moves and the
    // planet's primer is not spent behind it; [_finishTutorial] starts both.
    if (!_controlsTutorialSeen) {
      setState(() => _tutorialStep = 0);
      return;
    }
    _startRun();
  }

  void _startRun() {
    _game?.resumeEngine();
    // First frame the player can actually act on: the planet states its rule
    // now, once ever, rather than while the descent still covers the screen.
    _game?.beginRun();
  }

  /// The walkthrough's beats, in order, for whatever the pad is showing. The
  /// UTILITY beat is skipped where the pad has no verb (a guardian's arena).
  List<_TutorialBeat> get _tutorialBeats => [
    if (_game?.utilityAvailable ?? false)
      const _TutorialBeat(
        target: _TutorialTarget.utility,
        title: 'UTILITY',
        body:
            'Use this to work the dungeon: push, light, freeze and open '
            'things. What it does depends on the element of the creature '
            'leading, so swap creatures to change it.',
      ),
    const _TutorialBeat(
      target: _TutorialTarget.combat,
      title: 'ATTACK · SPECIAL',
      body:
          'These are for fighting only. They never solve a puzzle, so save '
          'them for enemies.',
    ),
  ];

  void _advanceTutorial() {
    final step = _tutorialStep;
    if (step == null) return;
    HapticFeedback.selectionClick();
    if (step + 1 < _tutorialBeats.length) {
      setState(() => _tutorialStep = step + 1);
    } else {
      unawaited(_finishTutorial());
    }
  }

  Future<void> _finishTutorial() async {
    setState(() {
      _tutorialStep = null;
      _controlsTutorialSeen = true;
    });
    _startRun();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_controlsTutorialSeenKey, true);
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
    // THE WORLD KEEPS RUNNING BEHIND IT. Pausing the engine froze the room
    // the star was just earned in — the beams, the water, the sky all stopped
    // dead behind the scrim, so the most celebratory screen in the game was
    // pinned to a still photograph. The popup absorbs its own taps, so
    // nothing can be worked underneath it while it is open.
    if (mounted) setState(() => _rewardStars = pending);
  }

  Future<void> _onStarEarned(int index) async {
    if (mounted) context.sound(SoundCue.dungeonStarCollect, owner: this);
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
    if (mounted &&
        !cloudId.startsWith('gate:') &&
        !(_game?.soundedSecrets.contains(cloudId) ?? false)) {
      context.sound(SoundCue.dungeonSecretReveal, owner: this);
    }
    final prefs = await SharedPreferences.getInstance();
    final state = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    ).withDiscoveredCloud(widget.element, cloudId);
    await prefs.setString(_starPrefsKey, state.serialise());
    // Hidden maxims (easter eggs) pay out the moment they're found — and
    // only once ever: a persisted discovery never re-fires this callback.
    if (cloudId.startsWith('egg:') && mounted) {
      await context.read<AlchemonsDatabase>().currencyDao.addGold(20);
      // Every maxim also leaves a keepsake for the home biome.
      _showToast('A lost maxim, +20 gold. A keepsake waits at home.');
    }
    // Vault caches: the treasure room's bottled essence, once ever.
    if (cloudId.startsWith('cache:') && mounted) {
      await context.read<AlchemonsDatabase>().currencyDao.addGold(5);
      _showToast('The vault yields, +5 gold');
    }
    // Family-gate stamps ("the seal remembers", §4) are SILENT: the gate's
    // own refusal line already names the family, and the chip simply turns
    // up on the descent panel. A toast on top of the refusal was a second
    // message saying nothing new.
  }

  void _onPlayerDown() {
    if (!mounted) return;
    context.sound(SoundCue.combatDefeat, owner: this);
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
    context.sound(SoundCue.survivalBossArrive, owner: this);
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
    _showToast('Out of time, the guardian holds');
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
      foregroundPainter: BracketFramePainter(
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
              'L${widget.raid!.safeLevel}',
              style: TextStyle(
                color: colour.withValues(alpha: 0.82),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
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
    if (mounted) context.sound(SoundCue.combatVictory, owner: this);
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
    // Show the reward popup; the game keeps rendering behind it — which it
    // now actually does. This line said so while calling `pauseEngine()`
    // directly underneath.
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
    _soundController?.stopSoundOwner(this);
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
      foregroundPainter: BracketFramePainter(
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
  Widget build(BuildContext context) => SceneAmbience(
    cue: AmbienceCue.forDungeon(widget.element),
    child: _buildScene(context),
  );

  Widget _buildScene(BuildContext context) {
    final game = _game;
    if (!_ready || game == null) {
      return Scaffold(
        backgroundColor: _C.bg,
        body: _underPassage ? null : _descentIntro(),
      );
    }

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Stack(
          children: [
            // THE ROOM STOPS AT THE TRAY (2026-09-24). The controls used to
            // float over the room and sat on doorways, pits and the party
            // itself; now the game is laid out above a tray and the camera
            // frames the room in the space that is left.
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: _trayHeight(context),
              // A tap on the room itself goes to the game (the Heart's
              // hanging elements show their names); the HUD over it keeps
              // its own taps.
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) => game.tapWorld(d.localPosition),
                child: GameWidget(game: game),
              ),
            ),

            // STOP FOLLOWING THE POUR. Big, centred and translucent, over
            // the shot itself — because the camera being somewhere else is
            // the single most disorienting thing this game does, and the way
            // out of it must be the most obvious thing on screen. It was a
            // 40px icon in the corner cluster to begin with, which is where
            // you put something you do not really expect to be pressed.
            Positioned.fill(
              child: ValueListenableBuilder<int>(
                valueListenable: _tick,
                builder: (_, __, ___) =>
                    game.followingPour && game.followInterruptible
                    ? Center(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: context.soundAction(() {
                            HapticFeedback.selectionClick();
                            game.cancelPourWatch();
                          }),
                          // The house chrome at size: hard corners, the same
                          // bracket painter every other control wears, and
                          // the monospace caps. It was a rounded Material
                          // capsule, which is the one thing in this HUD that
                          // looked like it came from a different game.
                          child: CustomPaint(
                            painter: BracketFramePainter(
                              color: _C.amber.withValues(alpha: 0.8),
                              bracketSize: 12,
                              strokeWidth: 1.6,
                            ),
                            child: Container(
                              width: 196,
                              height: 74,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _C.bg.withValues(alpha: 0.72),
                                border: Border.all(
                                  color: _C.border.withValues(alpha: 0.5),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _C.amber.withValues(alpha: 0.12),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.stop_rounded,
                                    color: _C.amberBright,
                                    size: 20,
                                    shadows: [
                                      Shadow(
                                        color: _C.amberBright.withValues(
                                          alpha: 0.55,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'STOP',
                                    style: TextStyle(
                                      color: _C.amberBright,
                                      fontFamily: 'monospace',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3.2,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),

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
                      onTap: context.soundAction(
                        () => setState(() => _showFullMap = true),
                      ),
                      // Small, so it never sits on a doorway in the room's
                      // corner (Light's hall had one right under it).
                      child: DungeonMiniMap(game: game, boxSize: 80),
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
                        builder: (_, __, ___) => _hintButton(
                          lit: game.hintHasAnswer,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            game.askForRoomHint();
                          },
                        ),
                      ),
                      // It recalls the party to the door they came in by
                      // rather than snapping them to whoever is active, so
                      // the icon is a way back rather than a huddle — except
                      // on the Black Sun, where it GATHERS everyone who can
                      // walk there to the one you are steering.
                      //
                      // Blood's captive rooms put a large labelled RESET
                      // ROOM here instead: the reset is how a jammed room is
                      // got out of, and the room never says it has jammed.
                      ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) => game.riteResetShown
                            ? _resetRoomButton(
                                lit: game.riteResetLit,
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  game.resetRiteRoom();
                                },
                              )
                            : _iconButton(
                                game.sunGathers
                                    ? Icons.groups_rounded
                                    : Icons.restore_rounded,
                                _C.amber,
                                () => game.regroup(),
                                semantics: game.sunGathers
                                    ? 'Gather the party here'
                                    : 'Recall the party to the way in',
                              ),
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
                      if (DebugSettingsService.toolsVisible && !_isRaid) ...[
                        _iconButton(
                          Icons.refresh_rounded,
                          _C.cyan,
                          () => unawaited(_debugResetDungeon()),
                          semantics: 'Debug: reset stars',
                        ),
                        // Call the guardian back down, beaten or not: a boss
                        // you can only fight once is a boss you cannot
                        // measure.
                        if (game.hasGuardianRoom)
                          _iconButton(
                            Icons.pest_control_rounded,
                            _C.danger,
                            () {
                              HapticFeedback.mediumImpact();
                              game.debugSpawnGuardian();
                            },
                            semantics: 'Debug: respawn the guardian',
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // THE CONTROL TRAY: joystick left, the action pad and the party
            // right, on a dark strip the room never runs under.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _trayHeight(context),
              child: _controlTray(game),
            ),

            // The joystick, bigger than the tray is tall: it sits in the
            // tray's corner and is allowed to rise a little above it.
            Positioned(
              left: 8,
              bottom: MediaQuery.of(context).padding.bottom + 2,
              child: VirtualJoystick(
                sizeMultiplier: _kStickDiameter / 104,
                onDirectionChanged: (dir) {
                  game.joystickDirection = dir ?? Offset.zero;
                  _stickHaptic(dir);
                },
              ),
            ),

            // A carried echo's DROP chip rides just above the tray.
            Positioned(
              right: 16,
              bottom: _trayHeight(context) + 8,
              child: ValueListenableBuilder<int>(
                valueListenable: _tick,
                builder: (_, __, ___) => _dropChip(game),
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
                  child: IgnorePointer(
                    child: Center(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) {
                          final spoken = game.hintText;
                          final hint = spoken ?? game.puzzlePreview;
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: hint == null
                                ? const SizedBox.shrink()
                                : _hintCapsule(
                                    hint,
                                    spoken == null
                                        ? DungeonHintChannel.objective
                                        : game.hintChannel,
                                  ),
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
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _starTracker(game),
                                if (readout != null) _progressReadout(readout),
                              ],
                            ),
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

            if (_showBeautyMask && !_showIntro)
              Positioned.fill(
                child: BeautyMaskReveal(
                  onComplete: () async {
                    final db = context.read<AlchemonsDatabase>();
                    await db.transaction(() async {
                      await db.settingsDao.setSetting(
                        CampaignJournalService.revelationKey,
                        '1',
                      );
                      await CampaignJournalService(db).record('revelation');
                    });
                    if (!mounted) return;
                    setState(() => _showBeautyMask = false);
                    _thawDungeon();
                  },
                ),
              ),
            // First-descent controls walkthrough, once the descent is gone.
            if (_tutorialStep != null && !_showIntro && !_showBeautyMask)
              _buildControlsTutorial(),

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
                raidLevel: widget.raid!.safeLevel,
                level3ClearsBeforeFight: widget.raid!.level3Clears,
                db: context.read<AlchemonsDatabase>(),
                onGranted: () async {
                  await CampaignJournalService.bump(
                    context.read<AlchemonsDatabase>().settingsDao,
                    'raids',
                  );
                  // AWAITED: the popup holds Continue until this lands, and
                  // that promise is only as good as the Future it is handed.
                  await widget.onRaidCleared?.call();
                },
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

  /// The descent: a portal of alchemical glyphs spelling the dungeon's name,
  /// rushing past as a tunnel with one elemental twist per planet, under the
  /// dungeon's title card in HUD chrome. Doubles as the loading screen.
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
          // The atmospheric dive (DescentPainter in
          // planet_dungeon_descent.dart) is stashed, not deleted — swap it
          // back here to restore it.
          CustomPaint(
            painter: PortalPainter(
              elapsed: elapsed,
              element: widget.element,
              title: kPlanetDungeonLayouts[widget.element]?.descentTitle ?? '',
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
        onTap: context.soundAction(() => setState(() => _showFullMap = false)),
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
  /// THE ONE THING THAT SPEAKS, dressed like the rest of the dungeon.
  ///
  /// It was a soft 20px pill with a hairline all the way round — the only
  /// rounded chrome left on a screen of bracketed panels, round glyph buttons
  /// and cornered banners, so it read as a component from an older build
  /// parked over the game. It wears the house chrome now: square, corner
  /// brackets, and the CHANNEL as a rule down its left edge rather than a
  /// tint smeared around its whole perimeter — the same way every other list
  /// row in this game says what kind of thing it is.
  Widget _hintCapsule(String hint, DungeonHintChannel channel) {
    final (Color accent, IconData? glyph, double textAlpha) = switch (channel) {
      // A refusal: ember-warm, glyphed, the firmest of the four.
      DungeonHintChannel.blocked => (_C.ember, Icons.block_flipped, 0.96),
      // A Mask reading: the same cold light the reveal pulse uses.
      DungeonHintChannel.insight => (_C.cyan, Icons.visibility_outlined, 0.96),
      // What the room wants: the house amber, unglyphed.
      DungeonHintChannel.objective => (_C.amber, null, 0.92),
      // Flavour: no rule, no glyph, no brackets. It sits back.
      DungeonHintChannel.ambient => (Colors.transparent, null, 0.74),
    };
    final ruled = channel != DungeonHintChannel.ambient;

    final body = Container(
      padding: EdgeInsets.fromLTRB(ruled ? 10 : 13, 8, 13, 8),
      decoration: BoxDecoration(
        color: _C.panel.withValues(alpha: ruled ? 0.94 : 0.62),
        border: Border(
          top: BorderSide(color: _C.border.withValues(alpha: 0.55)),
          right: BorderSide(color: _C.border.withValues(alpha: 0.55)),
          bottom: BorderSide(color: _C.border.withValues(alpha: 0.55)),
          left: ruled
              ? BorderSide(color: accent, width: 3)
              : BorderSide(color: _C.border.withValues(alpha: 0.55)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (glyph != null) ...[
            Icon(glyph, size: 12, color: accent.withValues(alpha: 0.95)),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _C.text.withValues(alpha: textAlpha),
                fontSize: 12,
                fontWeight: channel == DungeonHintChannel.blocked
                    ? FontWeight.w700
                    : FontWeight.w500,
                letterSpacing: 0.25,
                height: 1.34,
                fontStyle: channel == DungeonHintChannel.ambient
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );

    return KeyedSubtree(
      key: ValueKey('${channel.name}:$hint'),
      child: ruled
          ? CustomPaint(
              foregroundPainter: BracketFramePainter(
                color: accent.withValues(alpha: 0.85),
                bracketSize: 8,
                strokeWidth: 1.3,
              ),
              child: body,
            )
          : body,
    );
  }

  /// PROGRESS READOUT (§5.6) — a persistent, glanceable counter riding
  /// alongside the star tracker. Generalized from the per-planet gauges, so
  /// counters never have to borrow the hint capsule to be seen.
  Widget _progressReadout(DungeonProgressReadout r) {
    // SQUARE AND BRACKETED, like END RUN and every action pill. It was a
    // 16px stadium, which is the one shape nothing else in this HUD uses.
    return Container(
      margin: const EdgeInsets.only(left: 6),
      child: CustomPaint(
        painter: BracketFramePainter(
          color: _C.amber.withValues(alpha: 0.55),
          bracketSize: 5,
          strokeWidth: 1.1,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _C.bg.withValues(alpha: 0.82),
            border: Border.all(color: _C.border.withValues(alpha: 0.4)),
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
        ),
      ),
    );
  }

  Widget _starTracker(PlanetDungeonGame game) {
    // Sized so it clears the minimap (left) and the action pills (right) on
    // narrow phones. Square and bracketed to match the rest of the chrome —
    // it was a stadium, and a rounded capsule next to a row of hard-cornered
    // bracketed chips reads as a control from a different game.
    return CustomPaint(
      painter: BracketFramePainter(
        color: _C.amber.withValues(alpha: 0.55),
        bracketSize: 5,
        strokeWidth: 1.1,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: _C.bg.withValues(alpha: 0.82),
          border: Border.all(color: _C.border.withValues(alpha: 0.4)),
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

  // 128, not 196: the first tray was a quarter of the screen with an empty
  // middle, and the party row overflowed it on the Fold (2026-09-24).
  static const double _kTrayBody = 128;

  /// The joystick's full width. Taller than the tray on purpose (the
  /// author, 2026-09-24): a thumb control wants size more than it wants to
  /// stay inside a strip.
  static const double _kStickDiameter = 152;

  /// How much of the tray's row the stick reserves. Less than its diameter:
  /// the rest spills up out of the tray and a little over the party rail's
  /// padding instead of squeezing the party list.
  static const double _kStickReserve = 136;

  /// Action-pad square, the gap between squares, and a party row's height.
  /// Three party rows and two pad rows both come to the same 110, so the
  /// list and the pad line up top and bottom.
  static const double _kPadCell = 52;
  static const double _kPadGap = 6;
  static const double _kPartyRow = 32.7;

  /// JOYSTICK HAPTICS: one click when the stick is first pressed, and
  /// nothing while it is held — the steering ticks were constant under a
  /// moving thumb (the author, 2026-09-24). Letting go re-arms it.
  bool _stickHeld = false;

  void _stickHaptic(Offset? dir) {
    if (dir == null) {
      _stickHeld = false;
      return;
    }
    if (_stickHeld) return;
    _stickHeld = true;
    final audio = context.audio;
    if (audio != null && !audio.hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  /// The tick under the thumb on every control press (off with the setting).
  void _tapHaptic() {
    final audio = context.audio;
    if (audio != null && !audio.hapticsEnabled) return;
    HapticFeedback.selectionClick();
  }

  double _trayHeight(BuildContext context) =>
      _kTrayBody + MediaQuery.of(context).padding.bottom;

  Widget _controlTray(PlanetDungeonGame game) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0805),
        border: Border(
          top: BorderSide(color: _C.border.withValues(alpha: 0.9), width: 2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 6, 10, 6 + bottom),
        child: ValueListenableBuilder<int>(
          valueListenable: _tick,
          builder: (_, __, ___) => Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The joystick itself is drawn on its own layer (see
              // `_trayJoystick`) so it can rise above the tray; this keeps
              // its place in the row.
              const SizedBox(width: _kStickReserve),
              // The party fills the middle — the space that was empty — and
              // scales down rather than ever overflowing a narrow screen.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: _swapRail(game),
                ),
              ),
              // Always laid out, so the party list never changes width;
              // where the room offers nothing to do the pad is simply dim.
              _actionCluster(game),
            ],
          ),
        ),
      ),
    );
  }

  /// Carried-echo drop control (only while holding one). A stadium rather
  /// than a circle: the cloud's NAME is the point of it.
  Widget _dropChip(PlanetDungeonGame game) {
    if (game.carriedCloudType == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: context.soundAction(() {
        _tapHaptic();
        game.dropCarriedCloud();
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _C.bg.withValues(alpha: 0.9),
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
    );
  }

  /// THE ACTION PAD (2026-09-26): a 2×2 grid of squares in the HUD's own
  /// bracketed chrome. UTILITY spans the top row, ATTACK and SPECIAL share
  /// the bottom. It replaced three glowing round domes that read as a
  /// different game from the square controls beside them.
  ///
  /// Fixed: it never rearranges for a fight. Where the room has no verb at
  /// all (a guardian's arena) ATTACK takes the top row and SPECIAL the
  /// bottom, and that never changes mid-fight either.
  Widget _actionCluster(PlanetDungeonGame game) {
    final ability = game.activeAbility;
    final offers = game.roomOffersAction || _tutorialStep != null;
    final enabled = game.canAct && offers;
    final glide = ability == DungeonAbility.aerialTraversal;
    final flying = glide && game.flightActive;
    final hasUtility = game.utilityAvailable;
    final element = game.active?.member.element ?? widget.element;

    const cell = _kPadCell, gap = _kPadGap, wide = cell * 2 + gap;

    // THE BLACK SUN: a Dark in a grid room has two ends to cast, so the top
    // row is two tiles — CAST I and CAST II, in its portal's colour — and
    // Light's one tile says what it does (SHINE / PUT OUT).
    Widget castTile(int end) {
      final purple = game.sunActiveIsPurple;
      final tint = purple ? const Color(0xFFA77BFF) : const Color(0xFFFF9A3D);
      return _padTile(
        width: cell,
        height: cell,
        color: tint,
        spent: !enabled,
        semantics: 'Cast portal end ${end == 0 ? 'one' : 'two'}',
        onTap: enabled
            ? context.soundTap(() {
                _tapHaptic();
                game.activateSunCast(end);
              })
            : null,
        child: _padGlyph(
          Icons.brightness_1_outlined,
          end == 0 ? 'CAST I' : 'CAST II',
          !enabled,
        ),
      );
    }

    Widget utility() => _padTile(
      width: wide,
      height: cell,
      color: flying ? _C.cyan : _C.amberBright,
      spent: !enabled,
      // Glide drains and refills; every other verb is always full.
      charge: enabled && glide ? game.flightFraction : null,
      semantics: 'Use $element ability',
      onTap: enabled
          ? context.soundTap(() {
              _tapHaptic();
              game.activateAbility();
            })
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(elementIconFor(element), size: 24, color: _padInk(!enabled)),
          const SizedBox(width: 8),
          _padLabel(
            game.sunUtilityLabel ?? game.riteUtilityLabel ?? 'UTILITY',
            !enabled,
          ),
        ],
      ),
    );

    Widget attack(double w) {
      final cd = game.autoCooldownFraction;
      final cooling = cd > 0.02;
      return _padTile(
        width: w,
        height: cell,
        color: _C.cyan,
        spent: !offers || cooling,
        charge: cooling ? 1 - cd : null,
        denied: game.autoDeniedPulse,
        semantics: 'Attack',
        onTap: offers
            ? context.soundAction(() {
                _tapHaptic();
                game.activateAutoAttack();
              })
            : null,
        child: _padGlyph(
          Icons.gps_fixed_rounded,
          cooling ? game.autoCooldownLabel : 'ATTACK',
          !offers || cooling,
        ),
      );
    }

    Widget special(double w) {
      final passive = game.abilityIsPassive;
      // A Mystic's world is a Survival ability; here it has no special.
      final absent = game.abilityIsAbsent;
      final cd = passive || absent ? 0.0 : game.abilityCooldownFraction;
      final cooling = cd > 0.02;
      return _padTile(
        width: w,
        height: cell,
        color: _C.amberBright,
        spent: !offers || cooling || passive || absent,
        charge: cooling ? 1 - cd : null,
        denied: game.abilityDeniedPulse,
        semantics: absent
            ? 'No special here'
            : (passive ? 'Passive' : 'Special'),
        onTap: offers
            ? context.soundAction(() {
                _tapHaptic();
                game.activateCombatAbility();
              })
            : null,
        child: _padGlyph(
          absent
              ? Icons.block_rounded
              : (passive
                    ? Icons.all_inclusive_rounded
                    : Icons.auto_awesome_rounded),
          cooling
              ? game.abilityCooldownLabel
              : (absent ? 'NONE' : (passive ? 'PASSIVE' : 'SPECIAL')),
          !offers || cooling || passive || absent,
        ),
      );
    }

    // The walkthrough spotlights the top row and the bottom row; the keys
    // are how it finds them on screen.
    final Widget top;
    final Widget bottom;
    if (game.sunCastMode) {
      top = KeyedSubtree(
        key: _tutUtilityKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            castTile(0),
            const SizedBox(width: gap),
            castTile(1),
          ],
        ),
      );
      bottom = KeyedSubtree(
        key: _tutCombatKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            attack(cell),
            const SizedBox(width: gap),
            special(cell),
          ],
        ),
      );
    } else if (hasUtility) {
      top = KeyedSubtree(key: _tutUtilityKey, child: utility());
      bottom = KeyedSubtree(
        key: _tutCombatKey,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            attack(cell),
            const SizedBox(width: gap),
            special(cell),
          ],
        ),
      );
    } else {
      top = attack(wide);
      bottom = special(wide);
    }
    final grid = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        top,
        const SizedBox(height: gap),
        bottom,
      ],
    );
    return hasUtility || game.sunCastMode
        ? grid
        : KeyedSubtree(key: _tutCombatKey, child: grid);
  }

  Color _padInk(bool spent) =>
      spent ? _C.text.withValues(alpha: 0.38) : _C.text.withValues(alpha: 0.95);

  Widget _padLabel(String text, bool spent) => Text(
    text,
    maxLines: 1,
    style: TextStyle(
      color: _padInk(spent),
      fontFamily: 'monospace',
      fontSize: 10,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      height: 1,
    ),
  );

  Widget _padGlyph(IconData icon, String label, bool spent) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 20, color: _padInk(spent)),
      const SizedBox(height: 5),
      // A square is narrow; long words shrink to fit rather than clip.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(fit: BoxFit.scaleDown, child: _padLabel(label, spent)),
      ),
    ],
  );

  /// One square of the action pad: a dark tile, bracketed corners in the
  /// button's colour, and a solid band along the foot that fills as a
  /// cooldown (or a glide's charge) comes back. No glow, no blur.
  Widget _padTile({
    required double width,
    required double height,
    required Color color,
    required bool spent,
    required String semantics,
    required VoidCallback? onTap,
    required Widget child,
    double? charge,
    double denied = 0,
  }) {
    final refuse = denied.clamp(0.0, 1.0);
    final edge = Color.lerp(
      color.withValues(alpha: spent ? 0.35 : 0.85),
      _C.ember,
      refuse,
    )!;
    return Semantics(
      button: true,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: edge,
            bracketSize: 8,
            strokeWidth: 1.6,
          ),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Color.lerp(
                spent ? const Color(0xFF0C0B09) : const Color(0xFF15130F),
                _C.ember.withValues(alpha: 0.25),
                refuse,
              ),
              border: Border.all(
                color: _C.border.withValues(alpha: spent ? 0.3 : 0.55),
              ),
            ),
            child: Stack(
              children: [
                Center(child: child),
                if (charge != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 3,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: charge.clamp(0.0, 1.0),
                      child: ColoredBox(color: color.withValues(alpha: 0.8)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The party, as a short list: portrait, name and health, one row each.
  /// It used to be a row of portrait cards that the tray had to shrink to
  /// under half size to fit between the stick and the pad.
  Widget _swapRail(PlanetDungeonGame game) {
    final n = game.creatures.length;
    // Three to a column. More than three (Blood's Heart can hold six or
    // seven, Sanguorath's arena five) lay out in side-by-side columns of
    // three rather than running out of the tray.
    if (n <= 3) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < n; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : _kPadGap),
              child: _creatureChip(game, i),
            ),
        ],
      );
    }
    final cols = (n / 3).ceil();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < cols; c++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: c == 0 ? 0 : _kPadGap),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = c * 3; i < min(n, c * 3 + 3); i++)
                    Padding(
                      padding: EdgeInsets.only(top: i == c * 3 ? 0 : _kPadGap),
                      child: _creatureChip(game, i),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _creatureChip(PlanetDungeonGame game, int i) {
    final c = game.creatures[i];
    final isActive = i == game.activeIndex;
    final down = !c.alive;
    final ec = elementColor(c.member.element);
    const h = _kPartyRow;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: context.soundAction(() => game.setActive(i)),
      child: Container(
        height: h,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1B1812) : const Color(0xFF100E0B),
          border: Border.all(
            color: down
                ? _C.danger.withValues(alpha: 0.55)
                : isActive
                ? _C.amberBright
                : _C.border.withValues(alpha: 0.45),
            width: isActive ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: h - 2,
              height: h - 2,
              child: Opacity(
                opacity: down ? 0.32 : 1.0,
                child: c.member.imagePath != null
                    ? Image.asset(c.member.imagePath!, fit: BoxFit.cover)
                    : ColoredBox(color: ec.withValues(alpha: 0.4)),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    down ? 'DOWN' : c.member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: down
                          ? _C.danger
                          : isActive
                          ? _C.text
                          : _C.text.withValues(alpha: 0.62),
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    height: 4,
                    margin: const EdgeInsets.only(right: 7),
                    color: Colors.black54,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: c.hpFraction.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: c.hpFraction > 0.3 ? _C.amber : _C.danger,
                      ),
                    ),
                  ),
                ],
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
        onTap: context.soundAction(onTap),
        // The box is 36 but the tap target is padded out to 44, so a
        // slimmer button is not a harder one to hit.
        behavior: HitTestBehavior.opaque,
        // SQUARE AND BRACKETED, like every labelled control beside it. These
        // were circles: five of them in a rail down the edge of a HUD whose
        // every other element is a hard-cornered bracketed box.
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CustomPaint(
            painter: BracketFramePainter(
              color: color.withValues(alpha: 0.7),
              bracketSize: 6,
              strokeWidth: 1.1,
            ),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _C.bg.withValues(alpha: 0.82),
                border: Border.all(
                  color: _C.border.withValues(alpha: 0.4),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.10),
                    blurRadius: 9,
                  ),
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
      ),
    );
  }

  /// The hint, as a round lit dome rather than one more square in the rail.
  ///
  /// It is the only control a stuck player needs, and at 36px in a column of
  /// look-alike squares it was easy to miss. Bigger and round, so it stands
  /// apart from the rail; flat, with no glow.
  Widget _hintButton({required bool lit, required VoidCallback onTap}) {
    final color = lit ? _C.amberBright : _C.cyan;
    const d = 50.0;
    return Semantics(
      button: true,
      label: 'Hint',
      child: GestureDetector(
        onTap: context.soundAction(onTap),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit
                  ? const Color(0xFF1B1812)
                  : _C.bg.withValues(alpha: 0.88),
              border: Border.all(
                color: color.withValues(alpha: lit ? 0.8 : 0.5),
                width: 1.4,
              ),
            ),
            child: Icon(
              lit ? Icons.help_rounded : Icons.help_outline_rounded,
              color: color,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  /// RESET ROOM, for Blood's captive rooms: as big as the hint and labelled,
  /// because it is the way out of a room that has jammed. Lit (warm, with a
  /// slow breath) while the first captive room is saying where it is.
  Widget _resetRoomButton({required bool lit, required VoidCallback onTap}) {
    final breath = lit
        ? .5 + .5 * sin(DateTime.now().millisecondsSinceEpoch / 260)
        : 0.0;
    final color = lit ? _C.amberBright : _C.cyan;
    return Semantics(
      button: true,
      label: 'Reset this room',
      child: GestureDetector(
        onTap: context.soundAction(onTap),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CustomPaint(
            painter: BracketFramePainter(
              color: color.withValues(alpha: 0.75 + .2 * breath),
              bracketSize: 7,
              strokeWidth: 1.3,
            ),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: lit
                    ? Color.lerp(
                        const Color(0xFF14110C),
                        const Color(0xFF2A2214),
                        breath,
                      )
                    : _C.bg.withValues(alpha: 0.88),
                border: Border.all(
                  color: color.withValues(alpha: lit ? .55 + .3 * breath : .45),
                  width: 1.3,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.restart_alt_rounded, color: color, size: 26),
                  const SizedBox(width: 7),
                  Text(
                    'RESET\nROOM',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.2,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The first-descent walkthrough: the screen dimmed, one part of the action
  /// pad left lit, and a card above the tray saying what it is for. Any tap
  /// moves it on; nothing underneath can be pressed while it is up.
  Widget _buildControlsTutorial() {
    final beats = _tutorialBeats;
    final step = (_tutorialStep ?? 0).clamp(0, beats.length - 1);
    final beat = beats[step];
    final key = beat.target == _TutorialTarget.utility
        ? _tutUtilityKey
        : _tutCombatKey;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    Rect? hole;
    if (box != null && box.hasSize && box.attached) {
      hole = (box.localToGlobal(Offset.zero) & box.size).inflate(5);
    } else {
      // The pad lays out on this frame; look again on the next.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tutorialStep != null) setState(() {});
      });
    }
    final last = step == beats.length - 1;
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _advanceTutorial,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(hole: hole, color: _C.amberBright),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: _trayHeight(context) + 18,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: CustomPaint(
                    painter: BracketFramePainter(
                      color: _C.amber.withValues(alpha: 0.85),
                      bracketSize: 10,
                      strokeWidth: 1.4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                      decoration: BoxDecoration(
                        color: _C.panel.withValues(alpha: 0.96),
                        border: Border.all(
                          color: _C.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            beat.title,
                            style: const TextStyle(
                              color: _C.amberBright,
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.4,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            beat.body,
                            style: TextStyle(
                              color: _C.text.withValues(alpha: 0.92),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (var i = 0; i < beats.length; i++)
                                Container(
                                  width: 18,
                                  height: 3,
                                  margin: const EdgeInsets.only(right: 5),
                                  color: i == step
                                      ? _C.amberBright
                                      : _C.border.withValues(alpha: 0.6),
                                ),
                              const Spacer(),
                              Text(
                                last ? 'TAP TO BEGIN' : 'TAP TO CONTINUE',
                                style: TextStyle(
                                  color: _C.amber.withValues(alpha: 0.85),
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.6,
                                  height: 1,
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
          ],
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
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        painter: BracketFramePainter(
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

enum _TutorialTarget { utility, combat }

class _TutorialBeat {
  const _TutorialBeat({
    required this.target,
    required this.title,
    required this.body,
  });

  final _TutorialTarget target;
  final String title;
  final String body;
}

/// Dims everything but [hole], and lights the hole's edge with a soft filled
/// halo rather than a hairline ring. Static: it only repaints when the hole
/// moves to the next beat.
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.hole, required this.color});

  final Rect? hole;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = const Color(0xD0050403);
    final h = hole;
    if (h == null) {
      canvas.drawRect(Offset.zero & size, scrim);
      return;
    }
    // Square, like the pad tiles it frames.
    final r = RRect.fromRectAndRadius(h, const Radius.circular(2));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(r),
      ),
      scrim,
    );
    // A halo that fades outward from the hole's edge.
    final halo = h.inflate(22);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()
          ..addRRect(RRect.fromRectAndRadius(halo, const Radius.circular(14))),
        Path()..addRRect(r),
      ),
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                color.withValues(alpha: 0.34),
                color.withValues(alpha: 0.0),
              ],
              stops: [(h.longestSide / 2) / (halo.longestSide / 2), 1.0],
            ).createShader(
              Rect.fromCircle(center: h.center, radius: halo.longestSide / 2),
            ),
    );
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.hole != hole || old.color != color;
}
