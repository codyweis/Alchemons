// lib/games/planet_dungeon/planet_dungeon_screen.dart
//
// Flutter wrapper around PlanetDungeonGame: joystick movement, a swap-control
// rail for the creatures you brought, Regroup / End Run, the room minimap, a
// death overlay and an instant star-banked toast. Dark / alchemical chrome.

import 'dart:async';

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

const _starPrefsKey = 'cosmic_planet_stars';

class PlanetDungeonScreen extends StatefulWidget {
  const PlanetDungeonScreen({
    super.key,
    required this.element,
    required this.party,
    this.raid,
    this.raidEndUtc,
    this.onRaidCleared,
  });

  final String element;
  final List<CosmicPartyMember> party;

  /// Non-null → this descent is a raid: one open arena, an empowered
  /// guardian, raid loot. Stars/clouds are neither read nor written.
  final RaidConfig? raid;

  /// When the raid window closes (drives the HUD countdown).
  final DateTime? raidEndUtc;

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

  @override
  void initState() {
    super.initState();
    _flyCtrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 950),
        )..addStatusListener((s) {
          if (s == AnimationStatus.completed && mounted) {
            setState(() => _flyStar = null);
          }
        });
    _introTicker = createTicker((elapsed) {
      if (!mounted) return;
      final secs = elapsed.inMicroseconds / 1e6;
      if (_introFadeStart == null && secs >= _descentSeconds && _ready) {
        _introFadeStart = secs;
      }
      if (_introFadeStart != null && secs > _introFadeStart! + 0.5) {
        _introTicker.stop();
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
    setState(() {
      _game = game;
      _ready = true;
    });

    _hudTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) _tick.value++;
    });
  }

  Future<void> _onStarEarned(int index) async {
    // Bank instantly: persist immediately so death/quit can't undo it.
    final prefs = await SharedPreferences.getInstance();
    final stars = PlanetStarState.deserialise(
      prefs.getString(_starPrefsKey) ?? '',
    ).withStar(widget.element, index);
    await prefs.setString(_starPrefsKey, stars.serialise());
    _showToast('Star ${index + 1} secured');
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
    _popDungeon(_game?.starMask ?? 0);
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
                      const SizedBox(height: 6),
                      _pillButton(
                        'REGROUP',
                        _C.amber,
                        () => game.regroup(),
                        icon: Icons.workspaces_rounded,
                      ),
                      // Restart this molten chamber from scratch (appears only
                      // in the Steam puzzle rooms; reacts to room changes).
                      ValueListenableBuilder<int>(
                        valueListenable: _tick,
                        builder: (_, __, ___) {
                          if (!game.canRestartRoom) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: _pillButton(
                              'RESTART ROOM',
                              _C.cyan,
                              () => game.restartRoom(),
                              icon: Icons.restart_alt_rounded,
                            ),
                          );
                        },
                      ),
                      // Developer tools: the persisted switch OR a debug
                      // build, so the reset is reachable on the device where
                      // the playtesting actually happens.
                      if (DebugSettingsService.toolsVisible && !_isRaid) ...[
                        const SizedBox(height: 6),
                        _pillButton(
                          'RESET ★',
                          _C.cyan,
                          () => unawaited(_debugResetDungeon()),
                          icon: Icons.refresh_rounded,
                        ),
                      ],
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
                      _actionCluster(game),
                      const SizedBox(height: 12),
                      _swapRail(game),
                    ],
                  ),
                ),
              ),
            ),

            // The hint capsule (top-center, below the star tracker). One
            // capsule, one line, ever — styled by its channel (§5.6).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 46, left: 24, right: 24),
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
                  padding: const EdgeInsets.only(
                    top: 104,
                    left: 24,
                    right: 24,
                  ),
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
                        if (_isRaid) return _raidChip();
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

  /// Raid HUD chip: window countdown + the guardian's remaining strength.
  Widget _raidChip() {
    final end = widget.raidEndUtc;
    String clock = '';
    if (end != null) {
      final left = end.difference(DateTime.now().toUtc());
      if (left.isNegative) {
        clock = 'WINDOW CLOSED';
      } else {
        String two(int v) => v.toString().padLeft(2, '0');
        clock =
            '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: _C.bg.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.danger.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.whatshot_rounded, color: _C.danger, size: 14),
          const SizedBox(width: 7),
          Text(
            clock.isEmpty ? 'RAID' : 'RAID  ·  $clock',
            style: const TextStyle(
              color: _C.text,
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  /// The descent: diving through the planet's cloud deck — element-tinted
  /// cloud rings rushing past, converging wind lines, and the dungeon's
  /// title card in HUD chrome. Doubles as the loading screen.
  Widget _descentIntro() {
    final accent = elementColor(widget.element);
    return RepaintBoundary(
      child: ValueListenableBuilder<double>(
        valueListenable: _introTime,
        builder: (_, elapsed, _) => _descentIntroFrame(elapsed, accent),
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
        final t = Curves.easeInOut.transform(_flyCtrl.value);
        final pos = Offset.lerp(start, target, t)!;
        // Pop big at the start, shrink as it flies up.
        final scale = (1.6 - 1.0 * t).clamp(0.6, 1.6);
        final opacity = _flyCtrl.value < 0.85
            ? 1.0
            : (1.0 - (_flyCtrl.value - 0.85) / 0.15);
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
    final label = game.actionLabel();
    final glide = ability == DungeonAbility.aerialTraversal;
    final active = glide && game.flightActive;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Carried-echo drop control (only while holding one).
        if (game.carriedCloudType != null) ...[
          GestureDetector(
            onTap: game.dropCarriedCloud,
            child: CustomPaint(
              painter: _HudBracketPainter(
                color: _C.cyan.withValues(alpha: 0.7),
                bracketSize: 6,
              ),
              child: Container(
                width: 154,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.bg.withValues(alpha: 0.82),
                  border: Border.all(color: _C.border.withValues(alpha: 0.42)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.outbond_rounded, color: _C.cyan, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
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
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (glide)
          Container(
            width: 90,
            height: 6,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: _C.border.withValues(alpha: 0.6)),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: game.flightFraction,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF5BC8E8),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        _utilityButton(
          label: label,
          enabled: enabled,
          active: active,
          onTap: game.activateAbility,
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // CONTROL FEEDBACK lives here, not in the hint capsule (§5.6):
            // the ring shows the wait, the countdown names it, and a refused
            // press pulses the button that refused.
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
            const SizedBox(width: 10),
            _combatButton(
              label: game.abilityIsPassive ? 'PASSIVE' : 'SPECIAL',
              icon: game.abilityIsPassive
                  ? Icons.all_inclusive_rounded
                  : Icons.auto_awesome_rounded,
              cooldownText: game.abilityCooldownFraction > 0.02
                  ? game.abilityCooldownLabel
                  : null,
              // A passive special has no cast: the button reads spent, not
              // waiting — no ring, permanently dimmed.
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

  Widget _utilityButton({
    required String label,
    required bool enabled,
    required bool active,
    required VoidCallback onTap,
  }) {
    final color = active ? _C.cyan : _C.amberBright;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: CustomPaint(
        painter: _HudBracketPainter(
          color: enabled
              ? color.withValues(alpha: 0.72)
              : _C.border.withValues(alpha: 0.35),
          bracketSize: 7,
        ),
        child: Container(
          width: 154,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _C.bg.withValues(alpha: 0.82),
            border: Border.all(color: _C.border.withValues(alpha: 0.42)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: enabled ? 0.12 : 0.0),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_fix_high_rounded,
                    color: enabled ? color : _C.border,
                    size: 15,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: enabled ? color : _C.border,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    // A refused press: the bracket flares warm for a beat and settles. This
    // is the whole of the feedback — no prose, no capsule.
    final denied = deniedPulse.clamp(0.0, 1.0);
    final bracketColor = denied > 0
        ? Color.lerp(
            color.withValues(alpha: spent ? 0.38 : 0.78),
            _C.ember,
            denied,
          )!
        : color.withValues(alpha: spent ? 0.38 : 0.78);
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _HudBracketPainter(
          color: bracketColor,
          bracketSize: 8 + 2 * denied,
          strokeWidth: (spent ? 1.0 : 1.35) + 0.8 * denied,
        ),
        child: ClipRect(
          child: Stack(
            children: [
              Container(
                width: 72,
                height: 68,
                decoration: BoxDecoration(
                  color: _C.bg2.withValues(alpha: 0.88),
                  border: Border.all(
                    color: color.withValues(alpha: spent ? 0.28 : 0.55),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: spent ? 0.04 : 0.18),
                      blurRadius: 18,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: spent ? _C.text.withValues(alpha: 0.42) : color,
                      size: 22,
                      shadows: spent
                          ? null
                          : [
                              Shadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 12,
                              ),
                            ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      style: TextStyle(
                        color: spent
                            ? _C.text.withValues(alpha: 0.52)
                            : Colors.white.withValues(alpha: 0.92),
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.15,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              if (cooling)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: cooldownFraction.clamp(0.0, 1.0),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
              if (cooldownText != null)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: color.withValues(alpha: 0.75),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      cooldownText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
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
          width: 112,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
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
