import 'components/survival_camera_button.dart';
import 'components/survival_hud.dart';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/services/campaign_journal_service.dart';
// lib/games/cosmic_survival/cosmic_survival_screen.dart
//
// COSMIC SURVIVAL SCREEN
// Flutter wrapper around CosmicSurvivalGame. The lobby (the live core, the
// team the run takes, BASE COMMAND | START), the entrance that carries the
// core into the run (components/survival_orb_entrance.dart), the HUD,
// power-up selection and game over.
//
// A run is kept as each wave begins and when the player leaves it with SAVE &
// EXIT (survival_suspended_run.dart). While one is kept the lobby offers
// CONTINUE in place of START, with its team fixed; NEW RUN abandons it.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'components/cosmic_survival_game_over_panel.dart';
import 'components/survival_party_slot.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/mystic_graphx_overlay.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/shared/alchemon_combat_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_ship_loadout.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/potential_soul.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/screens/inventory_screen.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/cosmic/widgets/virtual_joystick.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/cinematic_quality_service.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/models/survival_family_mastery.dart';
import 'package:alchemons/models/survival_upgrades.dart';
import 'package:alchemons/services/family_mastery_service.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/faction_util.dart'
    show ForgeTokens, factionThemeFor;
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/games/cosmic_survival/orb_art.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_lobby_stage.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_lobby_team.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_mastery_strip.dart';
import 'package:alchemons/games/cosmic_survival/components/survival_orb_entrance.dart';
import 'package:alchemons/games/cosmic_survival/survival_suspended_run.dart';
import 'package:alchemons/screens/cosmic/widgets/cosmic_panel_kit.dart'
    show PanelReadout, PanelRow, PanelSectionHeader, panelLabel, panelPalette;
import 'package:alchemons/widgets/instance_widgets/specimen_case.dart'
    show MarkDiamond, elementLight;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (matching survival aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  // Kept in step with the surge panel's palette. Text was parchment on a
  // near-identical dark brown-grey, which is where "hard to read" came from:
  // body copy sat about three stops above its own background. The ground is
  // cooler and darker now and the text is brighter, so the contrast does the
  // work instead of the borders.
  static const bg0 = Color(0xFF050507);
  static const bg1 = Color(0xFF0B0B10);
  static const bg2 = Color(0xFF14141B);
  static const bg3 = Color(0xFF1F1F28);
  static const bg = bg0;
  static const amber = Color(0xFFD9B368);
  static const amberBright = Color(0xFFF2C96F);
  static const accent = amber;
  static const teal = Color(0xFF5BC8E8);
  static const textPrimary = Color(0xFFF4EEDF);
  static const textSecondary = Color(0xFFC8BFA8);
  static const textMuted = Color(0xFF8A8296);
  static const danger = Color(0xFFFF5A57);
  static const success = Color(0xFF3FDE8A);
  static const borderDim = Color(0xFF2B2B36);
  static const borderAccent = Color(0xFF8A7345);
}

class _T {
  static const TextStyle label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );
}

TextStyle _display(
  BuildContext context,
  double size,
  Color color, {
  FontWeight weight = FontWeight.w500,
  double letterSpacing = 0,
  FontStyle fontStyle = FontStyle.normal,
}) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  return base.copyWith(
    color: color,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontStyle: fontStyle,
  );
}

class _EtchedDivider extends StatelessWidget {
  final String label;

  const _EtchedDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.borderDim)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(label, style: _T.label),
        ),
        Expanded(child: Container(height: 1, color: _C.borderDim)),
      ],
    );
  }
}

/// The kit's pale brass, for what the lobby lights.
final ForgeTokens _brass = ForgeTokens(factionThemeFor(null));

/// A pane of the run's ink. Plain unless it has an [accent]: then it is the
/// thing on screen to read, and is lit from below in that color.
class _SurvivalPlate extends StatelessWidget {
  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;
  final Color? background;

  const _SurvivalPlate({
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.all(12),
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final pane = Container(
      padding: padding,
      color: background ?? _C.bg1.withValues(alpha: 0.9),
      child: child,
    );
    if (accent == null) return pane;
    return CustomPaint(
      foregroundPainter: BracketFramePainter(color: accent!, strokeWidth: 1.3),
      child: pane,
    );
  }
}

/// A survival dialog: a plain ink pane lit from below in [accent], the way
/// the kit's confirmations are.
class _SurvivalDialog extends StatelessWidget {
  const _SurvivalDialog({
    required this.accent,
    required this.child,
    this.maxWidth,
  });

  final Color accent;
  final Widget child;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
        child: CustomPaint(
          foregroundPainter: BracketFramePainter(
            color: accent.withValues(alpha: 0.9),
            strokeWidth: 1.3,
          ),
          child: ColoredBox(color: _C.bg1, child: child),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN STATE
// ─────────────────────────────────────────────────────────────────────────────

/// The lobby (with, while an entrance runs, the held run under it), the
/// run, and the run's results over its stilled arena.
enum _Phase { lobby, playing, gameOver }

class _SurvivalTestSlotSpec {
  final String family;
  final String element;
  final int level;
  final double statValue;

  const _SurvivalTestSlotSpec({
    required this.family,
    required this.element,
    this.level = 10,
    this.statValue = 3.0,
  });
}

class _SurvivalTestTeamPreset {
  final String key;
  final String label;
  final IconData icon;
  final String family;

  const _SurvivalTestTeamPreset({
    required this.key,
    required this.label,
    required this.icon,
    required this.family,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// COSMIC SURVIVAL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalScreen extends StatefulWidget {
  const CosmicSurvivalScreen({super.key, this.revealReady});

  /// Set true once the lobby's first frame — stage and core included — has
  /// been laid out and painted, for a passage into this screen to hand over
  /// to (see [survivalLobbyOrbFor] for where the core is).
  final ValueNotifier<bool>? revealReady;

  @override
  State<CosmicSurvivalScreen> createState() => _CosmicSurvivalScreenState();
}

class _CosmicSurvivalScreenState extends State<CosmicSurvivalScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _Phase _phase = _Phase.lobby;
  CosmicSurvivalGame? _game;

  /// The party of the run being played (a debug test squad included).
  List<CosmicPartyMember>? _party;

  /// The team the lobby shows and START takes in; saved under [_teamKey].
  List<CosmicPartyMember> _team = const [];

  /// False until the saved team has been read.
  bool _teamLoaded = false;
  static const String _teamKey = 'survival.team_v1';

  Timer? _hudTimer;
  final ValueNotifier<int> _liveUiTick = ValueNotifier<int>(0);
  final MysticGraphxOverlayController _mysticOverlayController =
      MysticGraphxOverlayController();

  /// The lobby's clock, in seconds: the stage turns on it and the entrance
  /// runs on it. Its ticker runs only while the lobby is up.
  final ValueNotifier<double> _lobbyClock = ValueNotifier<double>(0);
  late final Ticker _clockTicker = createTicker(_onClockTick);
  double _clockBase = 0;

  /// The lobby's picture, shared by the stage and the entrance so the ship's
  /// wake carries on unbroken between them.
  final SurvivalLobbyScene _scene = SurvivalLobbyScene();

  /// START → the run: the core carried into the arena.
  final SurvivalEntranceState _entrance = SurvivalEntranceState();
  SurvivalHighScoreData? _highScore;
  int _silver = 0;
  int _gold = 0;
  bool _showPauseMenu = false;
  bool _showJoystick = true;
  bool _largeJoystick = true;

  /// The forged cosmic hull picked in Base Command; null is the standard one.
  String? _shipSkin;
  SurvivalVisualQuality _visualQuality = SurvivalVisualQuality.performance;
  final DebugSettingsService _debugSettings = DebugSettingsService();
  bool _debugToolsEnabled = DebugSettingsService.toolsVisible;

  // Power-up selection state
  List<OfferedPowerUpChoice> _powerUpChoices = [];

  // Boss announcement
  String? _bossAnnouncement;
  String? _bossAnnouncementSubtitle;
  Timer? _bossAnnouncementTimer;
  String? _waveAnnouncementTitle;
  String? _waveAnnouncementSubtitle;
  Timer? _waveAnnouncementTimer;
  int _lastAnnouncedWave = 0;
  final List<_WaveAnnouncementData> _pendingWaveAnnouncements =
      <_WaveAnnouncementData>[];

  // Game over reward info
  List<LootOpeningEntry> _gameOverRewardEntries = [];
  int _finalWave = 0;
  int _finalKills = 0;
  int _finalScore = 0;
  String _finalTime = '00:00';
  bool _resolvingGameOver = false;
  bool _resolvingWave50Reward = false;

  /// Set once this run's mastery points are banked, so however the run
  /// ends its families are paid once.
  bool _masteryBanked = false;

  /// The run kept to come back to, as the lobby offers it (null when there
  /// is none). Read on open, set by SAVE & EXIT, gone once a run ends or is
  /// abandoned.
  SuspendedSurvivalRun? _suspended;

  /// False until the kept run, if any, has been read: START waits for it, so
  /// a new run cannot be started over one that has not been seen yet.
  bool _suspendedLoaded = false;

  /// The kept run's party is no longer all in the collection, so it can only
  /// be abandoned.
  bool _suspendedBroken = false;

  /// The live run's checkpoint: as it stood when the wave in progress began.
  SuspendedSurvivalRun? _checkpoint;

  /// True while the live run is one to keep; false once it has ended.
  bool _keepRun = false;

  /// The live run was continued from a kept one, so its party's stats are as
  /// they were when that run started.
  bool _runWasResumed = false;

  /// Writes of the kept run, one after another, so a clear can never land
  /// under a save that was queued before it.
  Future<void> _runSaves = Future<void>.value();
  bool _continuing = false;
  bool _replaying = false;
  static const int _defaultPartySize = 5;
  static const int _testTeamSize = 17;

  static const List<_SurvivalTestTeamPreset> _testTeamPresets = [
    _SurvivalTestTeamPreset(
      key: 'lets',
      label: 'Test Squad Lets',
      icon: AppIcons.public_rounded,
      family: 'Let',
    ),
    _SurvivalTestTeamPreset(
      key: 'pips',
      label: 'Test Squad Pips',
      icon: AppIcons.bolt_rounded,
      family: 'Pip',
    ),
    _SurvivalTestTeamPreset(
      key: 'manes',
      label: 'Test Squad Manes',
      icon: AppIcons.waves_rounded,
      family: 'Mane',
    ),
    _SurvivalTestTeamPreset(
      key: 'horns',
      label: 'Test Squad Horns',
      icon: AppIcons.shield_rounded,
      family: 'Horn',
    ),
    _SurvivalTestTeamPreset(
      key: 'masks',
      label: 'Test Squad Masks',
      icon: AppIcons.theater_comedy_rounded,
      family: 'Mask',
    ),
    _SurvivalTestTeamPreset(
      key: 'wings',
      label: 'Test Squad Wings',
      icon: AppIcons.flight_takeoff_rounded,
      family: 'Wing',
    ),
    _SurvivalTestTeamPreset(
      key: 'kins',
      label: 'Test Squad Kins',
      icon: AppIcons.favorite_rounded,
      family: 'Kin',
    ),
    _SurvivalTestTeamPreset(
      key: 'mystics',
      label: 'Test Squad Mystics',
      icon: AppIcons.auto_awesome_rounded,
      family: 'Mystic',
    ),
  ];

  AudioController? _soundController;

  @override
  void initState() {
    super.initState();
    _soundController = context.audio;
    WidgetsBinding.instance.addObserver(this);
    _clockTicker.start();
    unawaited(_loadControlPreferences());
    unawaited(_loadShipSkin());
    unawaited(_loadTeam());
    unawaited(_loadSuspended());
    CinematicQualityService.qualityNotifier.addListener(_handleQualityChanged);
    DebugSettingsService.enabledNotifier.addListener(_handleDebugToolsChanged);
    unawaited(_loadDebugTools());
    // The lobby is built from the first frame — there is no loading phase in
    // front of it — so once that frame is down a passage into this screen
    // can hand over. The one-time story, if it is due, comes up over the
    // lobby a moment later.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.revealReady?.value = true;
      unawaited(_loadVisualQuality());
      unawaited(_loadHighScore());
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) unawaited(_showIntro());
      });
    });
  }

  void _onClockTick(Duration elapsed) {
    _lobbyClock.value = _clockBase + elapsed.inMicroseconds / 1e6;
    if (_entrance.active) _advanceEntrance();
  }

  /// The lobby's clock runs while the lobby is up, and stops under a run.
  void _runLobbyClock(bool on) {
    if (on == _clockTicker.isActive) return;
    if (on) {
      _clockTicker.start();
    } else {
      _clockBase = _lobbyClock.value;
      _clockTicker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _soundController?.stopSoundOwner(this);
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    CinematicQualityService.qualityNotifier.removeListener(
      _handleQualityChanged,
    );
    DebugSettingsService.enabledNotifier.removeListener(
      _handleDebugToolsChanged,
    );
    _mysticOverlayController.dispose();
    _liveUiTick.dispose();
    _clockTicker.dispose();
    _lobbyClock.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _loadDebugTools() async {
    final enabled = await _debugSettings.isEnabled();
    if (!mounted) return;
    setState(() => _debugToolsEnabled = enabled);
  }

  void _handleDebugToolsChanged() {
    if (!mounted) return;
    setState(
      () => _debugToolsEnabled = DebugSettingsService.enabledNotifier.value,
    );
  }

  // ── Intro ────────────────────────────────────────────────

  Future<void> _loadControlPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _showJoystick = prefs.getBool('cosmic_survival_joystick_enabled') ?? true;
      _largeJoystick = prefs.getBool('cosmic_survival_large_joystick') ?? true;
    });
  }

  Future<void> _loadShipSkin() async {
    final loadout = await SurvivalShipLoadout.load();
    if (!mounted) return;
    setState(() => _shipSkin = loadout.selectedSkin);
  }

  SurvivalVisualQuality _toSurvivalVisualQuality(CinematicQuality quality) {
    return switch (quality) {
      CinematicQuality.cinematic => SurvivalVisualQuality.balanced,
      CinematicQuality.performance => SurvivalVisualQuality.performance,
    };
  }

  Future<void> _loadVisualQuality() async {
    final quality = await CinematicQualityService().getQuality();
    if (!mounted) return;
    setState(() {
      _visualQuality = _toSurvivalVisualQuality(quality);
    });
  }

  void _handleQualityChanged() {
    if (!mounted) return;
    final next = _toSurvivalVisualQuality(
      CinematicQualityService.qualityNotifier.value,
    );
    if (next == _visualQuality) return;
    setState(() {
      _visualQuality = next;
    });
  }

  /// The one-time story, over the lobby.
  Future<void> _showIntro() async {
    if (_phase != _Phase.lobby || _entrance.active) return;
    final db = context.read<AlchemonsDatabase>();
    final seenSharedStory = await db.settingsDao
        .hasSeenSurvivalMenuStoryIntro();
    final seenLegacyCosmicIntro = await db.settingsDao
        .hasSeenCosmicSurvivalIntro();
    if (!mounted) return;

    if (!seenSharedStory && !seenLegacyCosmicIntro) {
      await LandscapeDialog.show(
        context,
        title: 'A Test?',
        message:
            'Something here refuses to finish. The field closes, the wave breaks, the silence returns, and then the same war leans forward again as if no ending was ever allowed to remain.\n\n'
            'Is this my creation? Or has this constant alchemical war always existed somewhere beneath memory, waiting for a witness strong enough to mistake it for a test?',
      );
      await db.settingsDao.setSurvivalMenuStoryIntroSeen();
      await db.settingsDao.setCosmicSurvivalIntroSeen();
    }
  }

  Future<void> _loadHighScore() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    var hs = await db.getSurvivalHighScore();
    // Records used to be written only to two settings keys while this header
    // read the high-score table, so a run that beat the best never showed.
    // If the keys are ahead of the table, the table catches up here.
    final keyScore =
        int.tryParse(
          await db.settingsDao.getSetting('cosmic_survival_high_score') ?? '',
        ) ??
        0;
    final keyWave =
        int.tryParse(
          await db.settingsDao.getSetting('cosmic_survival_best_wave') ?? '',
        ) ??
        0;
    if (keyScore > (hs?.bestScore ?? 0) || keyWave > (hs?.bestWave ?? 0)) {
      await db.saveSurvivalHighScore(
        wave: keyWave,
        score: keyScore,
        timeMs: hs?.bestTimeMs ?? 0,
      );
      hs = await db.getSurvivalHighScore();
    }
    if (mounted) setState(() => _highScore = hs);
    await _loadSilver();
  }

  /// Silver is what Base Command spends, so the lobby shows it and uses it to
  /// work out whether there is anything worth going in for.
  Future<void> _loadSilver() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final currencies = await db.currencyDao.getAllCurrencies();
    if (!mounted) return;
    setState(() {
      _silver = currencies['silver'] ?? 0;
      _gold = currencies['gold'] ?? 0;
    });
  }

  String _formatHighScoreNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  String _formatHighScoreTime(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showHighScoreDetails() {
    final highScore = _highScore;
    if (highScore == null || highScore.bestWave <= 0) return;
    showDialog<void>(
      context: context,
      builder: (_) => _SurvivalDialog(
        accent: _C.amber,
        maxWidth: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _C.borderDim)),
              ),
              child: const Text(
                'BEST RUN',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PauseStatChip(
                        label: 'Best Wave',
                        value: 'W${highScore.bestWave}',
                        tint: _C.amberBright,
                      ),
                      _PauseStatChip(
                        label: 'Best Score',
                        value: _formatHighScoreNumber(highScore.bestScore),
                        tint: _C.teal,
                      ),
                      _PauseStatChip(
                        label: 'Best Time',
                        value: _formatHighScoreTime(highScore.bestTimeMs),
                        tint: _C.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'This is your deepest recorded survival clear.',
                    style: TextStyle(
                      color: _C.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _PauseActionButton(
                      label: 'CLOSE',
                      icon: AppIcons.close_rounded,
                      filled: false,
                      onTap: context.soundTap(
                        () => Navigator.of(context).pop(),
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

  // ── Team ────────────────────────────────────────────────

  /// The team last taken, read back on open. Alchemons that have gone since
  /// (released, fused away) are dropped, and the shorter team saved.
  Future<void> _loadTeam() async {
    final db = context.read<AlchemonsDatabase>();
    final raw = await db.settingsDao.getSetting(_teamKey);
    var ids = const <String>[];
    if (raw != null && raw.isNotEmpty) {
      try {
        ids = [
          for (final id in jsonDecode(raw) as List)
            if (id is String) id,
        ];
      } catch (_) {
        ids = const [];
      }
    }
    if (!mounted) return;
    final team = ids.isEmpty
        ? const <CosmicPartyMember>[]
        : await _buildParty(ids) ?? const <CosmicPartyMember>[];
    if (!mounted) return;
    final kept = [for (final m in team) m.instanceId];
    if (kept.length != ids.length) await _saveTeam(kept);
    if (!mounted) return;
    setState(() {
      _team = team;
      _teamLoaded = true;
    });
  }

  Future<void> _saveTeam(List<String> instanceIds) async {
    final db = context.read<AlchemonsDatabase>();
    await db.settingsDao.setSetting(_teamKey, jsonEncode(instanceIds));
  }

  /// Choose the team, starting from the one already chosen. Picking only
  /// sets the team; START takes it in. The team's cases fly between the
  /// picker and the lobby (SurvivalTeamHero) both ways.
  Future<void> _pickTeam() async {
    // A kept run's team is that run's until it ends or is abandoned.
    if (_entrance.active || _phase != _Phase.lobby || _suspended != null) {
      return;
    }
    final current = [for (final m in _team) m.instanceId];
    await Navigator.of(context).push<List<PartyMember>>(
      SurvivalTeamPickerRoute(
        builder: (_) => PartyPickerScreen(
          showDeployConfirm: false,
          enforceUniqueSpecies: false,
          maxSelections: _defaultPartySize,
          initialSelection: current.isEmpty ? null : current,
          confirmLabel: 'Choose Team',
          onConfirm: _takeTeam,
          teamCaseWrapper: (slot, id, teamCase) =>
              SurvivalTeamHero(instanceId: id, slot: slot, child: teamCase),
        ),
      ),
    );
  }

  /// Sets the chosen team while the picker is still up, so its slots are
  /// standing in the lobby, portraits decoded, for the cases to land in.
  Future<void> _takeTeam(List<PartyMember> chosen) async {
    final ids = [for (final m in chosen.take(_defaultPartySize)) m.instanceId];
    final team = await _buildParty(ids);
    if (team == null || team.isEmpty || !mounted) return;
    await Future.wait([
      for (final m in team)
        if (m.imagePath case final path?)
          precacheImage(
            ResizeImage(AssetImage(path), width: kSurvivalTeamCaseCacheWidth),
            context,
            onError: (_, _) {},
          ),
    ]);
    if (!mounted) return;
    setState(() => _team = team);
    await _saveTeam([for (final m in team) m.instanceId]);
  }

  Future<List<CosmicPartyMember>?> _buildParty(List<String> instanceIds) async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final combatBonuses = context.read<ConstellationEffectsService>();
    final members = <CosmicPartyMember>[];

    for (
      var i = 0;
      i < instanceIds.length && members.length < _defaultPartySize;
      i++
    ) {
      final inst = await db.creatureDao.getInstance(instanceIds[i]);
      if (inst == null) continue;
      final base = catalog.getCreatureById(inst.baseId);
      if (base == null) continue;

      final typeName = base.types.isNotEmpty ? base.types.first : 'Earth';
      final family = base.mutationFamily ?? 'kin';
      final name = inst.nickname ?? base.name;
      final sheet = base.spriteData != null ? sheetFromCreature(base) : null;
      final visuals = visualsFromInstance(base, inst);

      members.add(
        CosmicPartyMember(
          instanceId: inst.instanceId,
          baseId: inst.baseId,
          displayName: name,
          imagePath: 'assets/images/${base.image}',
          element: typeName,
          family: family,
          level: inst.level,
          statSpeed: combatBonuses.applyCombatStatBonus(
            'speed',
            inst.statSpeed,
          ),
          statIntelligence: combatBonuses.applyCombatStatBonus(
            'intelligence',
            inst.statIntelligence,
          ),
          statStrength: combatBonuses.applyCombatStatBonus(
            'strength',
            inst.statStrength,
          ),
          statBeauty: combatBonuses.applyCombatStatBonus(
            'beauty',
            inst.statBeauty,
          ),
          statSpeedPotential: inst.statSpeedPotential,
          statIntelligencePotential: inst.statIntelligencePotential,
          statStrengthPotential: inst.statStrengthPotential,
          statBeautyPotential: inst.statBeautyPotential,
          // Slots stay contiguous when a saved Alchemon has gone.
          slotIndex: members.length,
          staminaBars: inst.staminaMax, // full stamina for survival
          staminaMax: inst.staminaMax,
          spriteSheet: sheet,
          spriteVisuals: visuals,
        ),
      );
    }

    return members;
  }

  // ── Kept run ────────────────────────────────────────────

  SuspendedRunStore get _runStore =>
      SuspendedRunStore(context.read<AlchemonsDatabase>());

  /// The debug squads are built from the catalog, not the collection.
  static bool _isTestMember(String instanceId) =>
      instanceId.startsWith('survival_test_');

  /// The kept run, read on open. A save this build cannot read is dropped
  /// quietly by the store.
  Future<void> _loadSuspended() async {
    SuspendedSurvivalRun? run;
    List<CosmicPartyMember>? party;
    try {
      run = await _runStore.load();
      party = run == null || !mounted ? null : await _partyForRun(run);
    } catch (error) {
      // START must not wait on a read that failed.
      debugPrint('Survival: the saved run could not be read: $error');
      run = null;
    }
    if (!mounted) return;
    setState(() {
      _suspended = run;
      _suspendedBroken = run != null && party == null;
      _suspendedLoaded = true;
    });
  }

  /// [run]'s party, ready to play: its stats exactly as the run started with
  /// them, drawn with each creature's sprite. Null when any of them is no
  /// longer in the collection (released, fused, traded) — that run cannot go
  /// on without it.
  Future<List<CosmicPartyMember>?> _partyForRun(
    SuspendedSurvivalRun run,
  ) async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final party = <CosmicPartyMember>[];
    for (final member in run.party) {
      final base = catalog.getCreatureById(member.baseId);
      if (base == null) return null;
      final inst = _isTestMember(member.instanceId)
          ? null
          : await db.creatureDao.getInstance(member.instanceId);
      if (!_isTestMember(member.instanceId) && inst == null) return null;
      party.add(
        SuspendedSurvivalRun.withSprite(
          member,
          sheet: base.spriteData != null ? sheetFromCreature(base) : null,
          visuals: visualsFromInstance(base, inst),
        ),
      );
    }
    return party.isEmpty ? null : party;
  }

  void _queueRunSave(SuspendedSurvivalRun run) {
    final store = _runStore;
    _runSaves = _runSaves.then((_) => store.save(run)).catchError((
      Object error,
    ) {
      debugPrint('Survival: the run could not be saved: $error');
    });
  }

  void _queueRunClear() {
    final store = _runStore;
    _runSaves = _runSaves.then((_) => store.clear()).catchError((Object error) {
      debugPrint('Survival: the saved run could not be cleared: $error');
    });
  }

  /// A wave has begun (or the run has): this is where a continued run will
  /// pick up from.
  void _handleWaveCheckpoint() {
    final game = _game;
    if (game == null || !mounted || !_keepRun || game.isGameOver) return;
    final run = game.captureSuspendedRun();
    _checkpoint = run;
    _queueRunSave(run);
  }

  /// The run as left now: the wave's checkpoint, with no more health than
  /// the run has at this moment.
  SuspendedSurvivalRun _runAsLeft(CosmicSurvivalGame game) {
    final atExit = game.captureSuspendedRun();
    return _checkpoint?.leftAt(atExit) ?? atExit;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused) return;
    // Sent to the background mid-run, from where the OS may close the app:
    // keep the run as if it were left now, so closing it never heals.
    final game = _game;
    if (game == null ||
        !_keepRun ||
        _checkpoint == null ||
        !game.isLoaded ||
        game.isGameOver ||
        !mounted) {
      return;
    }
    _queueRunSave(_runAsLeft(game));
  }

  /// CONTINUE: the kept run, rebuilt and carried in by the core as START's
  /// run is.
  Future<void> _continueRun() async {
    final run = _suspended;
    if (run == null ||
        _suspendedBroken ||
        _continuing ||
        _entrance.active ||
        _phase != _Phase.lobby) {
      return;
    }
    _continuing = true;
    try {
      final party = await _partyForRun(run);
      if (!mounted || !identical(_suspended, run)) return;
      if (party == null) {
        setState(() => _suspendedBroken = true);
        return;
      }
      _enterRun(party, resume: run);
    } finally {
      _continuing = false;
    }
  }

  /// Asks before a new run takes the kept run's place: the kept run ends
  /// there, with no rewards and no mastery. True once it is gone (or when
  /// there was none).
  Future<bool> _abandonSuspended() async {
    final run = _suspended;
    if (run == null) return true;
    final abandon = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kLeaveDangerAccent,
      title: 'NEW RUN',
      message: 'Abandon the wave ${run.wave} run? Its mastery is lost.',
      cancelLabel: 'KEEP',
      confirmLabel: 'ABANDON',
    );
    if (!abandon || !mounted || !identical(_suspended, run)) return false;
    setState(() {
      _suspended = null;
      _suspendedBroken = false;
    });
    _queueRunClear();
    await _runSaves;
    return mounted;
  }

  /// NEW RUN, beside CONTINUE: abandon the kept run, then as START.
  Future<void> _newRun() async {
    if (_entrance.active || _phase != _Phase.lobby) return;
    if (!await _abandonSuspended()) return;
    _start();
  }

  List<_SurvivalTestSlotSpec> _buildFullElementTestTeam(String family) {
    final count = min(_testTeamSize, kCosmicAbilityElements.length);
    return List<_SurvivalTestSlotSpec>.generate(
      count,
      (i) => _SurvivalTestSlotSpec(
        family: family,
        element: kCosmicAbilityElements[i],
        level: 10,
        statValue: 3.5,
      ),
      growable: false,
    );
  }

  List<CosmicPartyMember>? _buildTestParty(
    List<_SurvivalTestSlotSpec> specs, {
    required String teamKey,
  }) {
    final catalog = context.read<CreatureCatalog>();
    final members = <CosmicPartyMember>[];

    for (var i = 0; i < specs.length && i < _testTeamSize; i++) {
      final spec = specs[i];
      final base = catalog.creatures.firstWhereOrNull(
        (c) =>
            (c.mutationFamily ?? '').toLowerCase() ==
                spec.family.toLowerCase() &&
            c.types.any((t) => t.toLowerCase() == spec.element.toLowerCase()),
      );
      if (base == null) return null;

      final sheet = base.spriteData != null ? sheetFromCreature(base) : null;
      final visuals = visualsFromInstance(base, null);

      members.add(
        CosmicPartyMember(
          instanceId: 'survival_test_${teamKey}_$i',
          baseId: base.id,
          displayName: base.name,
          imagePath: 'assets/images/${base.image}',
          element: spec.element,
          family: spec.family.toLowerCase(),
          level: spec.level,
          statSpeed: spec.statValue,
          statIntelligence: spec.statValue,
          statStrength: spec.statValue,
          statBeauty: spec.statValue,
          slotIndex: i,
          staminaBars: 3,
          staminaMax: 3,
          spriteSheet: sheet,
          spriteVisuals: visuals,
        ),
      );
    }

    return members;
  }

  void _startTestTeam(List<_SurvivalTestSlotSpec> specs, String teamKey) {
    if (!_suspendedLoaded) return;
    // A test squad's run takes the kept run's place like any other.
    if (_suspended != null) {
      unawaited(() async {
        if (await _abandonSuspended()) _startTestTeam(specs, teamKey);
      }());
      return;
    }
    final party = _buildTestParty(specs, teamKey: teamKey);
    if (party == null || party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: _C.bg2,
            child: const Row(
              children: [
                Icon(
                  AppIcons.warning_amber_rounded,
                  size: 16,
                  color: _C.danger,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Could not build the requested survival test team.',
                    style: TextStyle(
                      color: _C.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    _enterRun(party);
  }

  // ── Start Game ──────────────────────────────────────────

  /// START: the chosen team, or — with none chosen yet — the picker.
  void _start() {
    if (!_suspendedLoaded) return;
    if (_suspended != null) {
      unawaited(_newRun());
      return;
    }
    if (_team.isEmpty) {
      unawaited(_pickTeam());
      return;
    }
    _enterRun(List<CosmicPartyMember>.of(_team));
  }

  /// Into a run, carried by the core (survival_orb_entrance.dart). The run is
  /// built and mounted at once under the lobby, held with its engine paused
  /// and its camera on the core, while the lobby's chrome eases away and the
  /// core moves to where the run will draw it. Once the core has landed and
  /// the run is attached, the arena fades in round it with the engine
  /// running; then the run takes the core over and is released — camera,
  /// wave announcement, music.
  ///
  /// [resume]: the kept run to continue, in place of a new one.
  void _enterRun(
    List<CosmicPartyMember> party, {
    SuspendedSurvivalRun? resume,
  }) {
    if (_entrance.active || _phase != _Phase.lobby || party.isEmpty) return;
    _runLobbyClock(true);
    setState(() {
      _party = party;
      _entrance.begin(_lobbyClock.value);
    });
    _startGame(party, carried: true, resume: resume);
    final game = _game;
    if (game != null) _entrance.attach(game);
  }

  /// One frame of the entrance, on the lobby's clock.
  void _advanceEntrance() {
    final game = _game;
    if (game == null) {
      _entrance.finish();
      return;
    }
    _entrance.advance(_lobbyClock.value);
    if (_entrance.arenaFrom == null &&
        _entrance.landed &&
        mounted &&
        game.isAttached &&
        game.isLoaded) {
      // The core has landed and the run is ready: the run picks up the
      // core's turning where the lobby has it, and plays on under the arena
      // as it fades in, its camera still held on the core.
      final clock = _lobbyClock.value;
      game.alignCorePresentation(
        time: clock,
        beat: SurvivalLobbyScene.beatAt(clock),
      );
      game.resumeEngine();
      _entrance.beginArena();
    } else if (_entrance.arenaIn) {
      _finishEntrance(game);
    }
  }

  /// The arena is in: the run draws its own core from this frame — the run
  /// repaints every frame now, so it does so in the same frame the overlay
  /// goes — and the run is let go.
  void _finishEntrance(CosmicSurvivalGame game) {
    game.entranceCoreHidden = false;
    _entrance.finish();
    _runLobbyClock(false);
    setState(() => _phase = _Phase.playing);
    _releaseHeldRun();
    game.releaseCameraToShip();
  }

  /// The run is in view: let the held run go.
  void _releaseHeldRun() {
    final game = _game;
    if (game == null) return;
    game.resumeEngine();
    _presentRunStart(game);
  }

  /// The run's opening beats — only once the player can see the arena.
  void _presentRunStart(CosmicSurvivalGame game) {
    _showWaveAnnouncementForWave(game.spawner.currentWave);
    unawaited(context.read<AudioController>().playSurvivalMusic());
  }

  /// [carried]: the run mounts under the lobby with its engine paused, its
  /// camera held on the core and its own core left undrawn, for the
  /// entrance; its opening beats wait for [_releaseHeldRun].
  ///
  /// [resume]: a kept run to continue. It is built with that run's own
  /// guardian upgrades, orb, ship and mastery paths, as they were when it
  /// started, and picks up at the start of the wave it was left on.
  void _startGame(
    List<CosmicPartyMember> party, {
    bool carried = false,
    SuspendedSurvivalRun? resume,
  }) {
    final upgradeSvc = context.read<SurvivalUpgradeService>();
    _mysticOverlayController.clear();

    // The equipped path per family is locked here and never re-read for the
    // rest of the run, so switching a branch mid-run is impossible rather
    // than merely discouraged.
    final masterySvc = context.read<FamilyMasteryService>();
    final masterySnapshot =
        resume?.mastery ??
        masterySvc.snapshotForParty([
          for (final member in party)
            if (creatureFamilyFromStorage(member.family) case final family?)
              FamilyMasteryPartyMemberRef(
                slotIndex: member.slotIndex,
                instanceId: member.instanceId,
                family: family,
              ),
        ]);

    final game = CosmicSurvivalGame(
      party: party,
      onSound: (cue) {
        if (mounted) context.sound(cue, owner: this);
      },
      onGameOver: _handleGameOver,
      onWaveIntermission: _handleWaveIntermission,
      onWaveCleared: _handleWaveCleared,
      onBossSpawn: _handleBossSpawn,
      onMysticSpecialCast: _mysticOverlayController.spawn,
      onWaveCheckpoint: _handleWaveCheckpoint,
      upgradeState: resume?.upgradeState ?? upgradeSvc.state,
      masterySnapshot: masterySnapshot,
      visualQuality: _visualQuality,
      shipSkin: resume != null ? resume.shipSkin : _shipSkin,
    );
    // Flame starts its loop on attach unless already paused.
    if (carried) {
      game.pauseEngine();
      game.entranceCoreHidden = true;
    }

    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    setState(() {
      _game = game;
      if (!carried) _phase = _Phase.playing;
      _gameOverRewardEntries = [];
      _powerUpChoices = [];
      _bossAnnouncement = null;
      _bossAnnouncementSubtitle = null;
      _waveAnnouncementTitle = null;
      _waveAnnouncementSubtitle = null;
      _pendingWaveAnnouncements.clear();
      _finalWave = 0;
      _finalKills = 0;
      _finalScore = 0;
      _finalTime = '00:00';
      _resolvingGameOver = false;
      _masteryBanked = false;
    });

    // Kept from its first frame on (the game calls back as each wave
    // begins), until it ends.
    _keepRun = true;
    _runWasResumed = resume != null;
    _checkpoint = resume;
    if (resume != null) {
      game.resumeRun(resume);
    } else {
      game.startGame();
    }
    if (carried) game.holdCameraOnCore();
    // Set even when held, so the HUD timer below doesn't announce wave 1
    // during the entrance.
    _lastAnnouncedWave = game.spawner.currentWave;
    if (!carried) _showWaveAnnouncementForWave(game.spawner.currentWave);

    // Start HUD refresh timer (10fps)
    _hudTimer?.cancel();
    _hudTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final liveGame = _game;
      if (liveGame != null) {
        final liveWave = liveGame.spawner.currentWave;
        if (liveWave > 0 && liveWave != _lastAnnouncedWave) {
          _lastAnnouncedWave = liveWave;
          _showWaveAnnouncementForWave(liveWave);
        }
      }
      _liveUiTick.value++;
    });

    if (!carried) {
      unawaited(context.read<AudioController>().playSurvivalMusic());
    }
  }

  // ── Wave Intermission (Power-Ups) ──────────────────────

  void _handleWaveIntermission() {
    if (_game == null || !mounted) return;
    final party = _party ?? const <CosmicPartyMember>[];
    final choices =
        !_game!.powerUps.hasKeystone && _game!.spawner.currentWave >= 10
        ? generateKeystoneChoices(
            _game!.powerUps,
            _game!.spawner.currentWave,
            party: party,
          )
        : generatePowerUpChoices(
            _game!.powerUps,
            _game!.spawner.currentWave,
            party: party,
            defeatedCompanionSlots: _game!.defeatedCompanionSlots,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _powerUpChoices = choices);
    });
  }

  void _handleWaveCleared(int wave) {
    context.sound(
      wave == 50 ? SoundCue.survivalMilestone : SoundCue.survivalWaveClear,
      owner: this,
    );
    final db = context.read<AlchemonsDatabase>();
    unawaited(CampaignJournalService(db).recordSurvivalClear(wave));
    if (wave != 50 || _resolvingWave50Reward) return;
    unawaited(_grantWave50Milestone());
  }

  Future<void> _grantWave50Milestone() async {
    final game = _game;
    if (game == null || !mounted || _resolvingWave50Reward) return;

    _resolvingWave50Reward = true;
    game.gamePaused = true;
    try {
      final db = context.read<AlchemonsDatabase>();
      final shop = context.read<ShopService>();
      final portalKey = LootBoxConfig.rollSurvivalBonusPortalKey(50, Random());
      if (portalKey == null) return;
      final granted = await shop.grantWave50Milestone(portalKey: portalKey);

      // False means this account has already claimed the milestone.
      if (!granted) return;

      if (!mounted) return;
      final registry = buildInventoryRegistry(db);
      LootOpeningEntry itemEntry(
        String key,
        String label, {
        Color color = _C.accent,
      }) {
        final def = registry[key];
        final imagePath = InventoryImageHelper.getImage(key);
        return LootOpeningEntry(
          icon: def?.icon ?? AppIcons.inventory_2_rounded,
          name: def?.name ?? key,
          label: label,
          color: color,
          imagePath: imagePath,
          visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
            key: key,
            assetName: imagePath,
            icon: def?.icon,
            size: size,
          ),
        );
      }

      final entries = <LootOpeningEntry>[
        itemEntry(InvKeys.potentialSoul, 'x1', color: const Color(0xFFB66CFF)),
        itemEntry(portalKey, 'x1', color: const Color(0xFF57E7F2)),
        itemEntry(
          InvKeys.alchemyWavebreakerCrown,
          'x1',
          color: const Color(0xFFE4C16A),
        ),
      ];
      await showLootOpeningDialog(
        context: context,
        entries: entries,
        title: 'WAVE 50 BROKEN',
      );
    } finally {
      _resolvingWave50Reward = false;
      if (identical(_game, game) && !game.isGameOver) {
        game.gamePaused = false;
      }
    }
  }

  void _selectPowerUp(PowerUpDef def, {int? targetSlot, String? targetName}) {
    context.sound(SoundCue.survivalPowerupChoose, owner: this);
    _game?.applyPowerUp(def, targetSlot: targetSlot, targetName: targetName);
    setState(() => _powerUpChoices = []);
  }

  void _handleBossSpawn(SurvivalBoss boss) {
    if (!mounted) return;
    context.sound(SoundCue.survivalBossArrive, owner: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _bossAnnouncement = boss.template.name;
        _bossAnnouncementSubtitle =
            '${CosmicSurvivalSpawner.bossDisciplineLabel(boss.discipline)}'
            ' • ${CosmicSurvivalSpawner.bossDisciplineSummary(boss.discipline)}';
      });
      _bossAnnouncementTimer?.cancel();
      _bossAnnouncementTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _bossAnnouncement = null;
            _bossAnnouncementSubtitle = null;
          });
        }
      });
    });
  }

  void _showWaveAnnouncementForWave(int wave) {
    if (!mounted || wave <= 0) return;
    if (!CosmicSurvivalSpawner.isBossWaveNumber(wave)) {
      context.sound(SoundCue.survivalWaveStart, owner: this);
    }
    final announcement = _WaveAnnouncementData(
      title: CosmicSurvivalSpawner.isBossWaveNumber(wave)
          ? 'BOSS WAVE $wave'
          : 'WAVE $wave',
      subtitle: null,
    );
    if (_waveAnnouncementTitle != null) {
      final alreadyQueued = _pendingWaveAnnouncements.any(
        (item) =>
            item.title == announcement.title &&
            item.subtitle == announcement.subtitle,
      );
      if (!alreadyQueued) {
        _pendingWaveAnnouncements.add(announcement);
      }
      return;
    }
    _presentWaveAnnouncement(announcement);
  }

  void _presentWaveAnnouncement(_WaveAnnouncementData announcement) {
    setState(() {
      _waveAnnouncementTitle = announcement.title;
      _waveAnnouncementSubtitle = announcement.subtitle;
    });
    _waveAnnouncementTimer?.cancel();
    _waveAnnouncementTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      setState(() {
        _waveAnnouncementTitle = null;
        _waveAnnouncementSubtitle = null;
      });
      if (_pendingWaveAnnouncements.isNotEmpty) {
        final next = _pendingWaveAnnouncements.removeAt(0);
        _presentWaveAnnouncement(next);
      }
    });
  }

  // ── Game Over ──────────────────────────────────────────

  void _handleGameOver() {
    if (!mounted || _resolvingGameOver) return;
    // The run has ended, and with it the kept copy: there is nothing to
    // continue, and its rewards and mastery are paid below.
    _keepRun = false;
    _checkpoint = null;
    _suspended = null;
    _suspendedBroken = false;
    _queueRunClear();
    context.audio?.stopSoundOwner(this);
    context.sound(SoundCue.combatDefeat, owner: this);
    _hudTimer?.cancel();
    _game?.gamePaused = true;

    final wave = _game?.spawner.currentWave ?? 0;
    final wavesCleared = _game == null ? 0 : _wavesClearedBy(_game!);
    setState(() {
      _finalWave = wave;
      _finalKills = _game?.stats.kills ?? 0;
      _finalScore = _game?.stats.score ?? 0;
      _finalTime = _game?.stats.formattedTime ?? '00:00';
      _resolvingGameOver = true;
    });

    unawaited(_completeGameOverSequence(wave, wavesCleared));
  }

  Future<void> _completeGameOverSequence(int wave, int wavesCleared) async {
    // The results wait for the core to have mostly come apart; the rewards
    // are rolled and banked while it does, and gather into the results there
    // (one screen — there is no separate reveal any more).
    final fall = Future<void>.delayed(
      Duration(milliseconds: (kCoreFallSeconds * 1000 * 0.62).round()),
    );
    try {
      await _saveHighScore();
      await _rollRewards(wave, wavesCleared: wavesCleared);
      await fall;
    } finally {
      if (mounted) {
        setState(() {
          _phase = _Phase.gameOver;
          _resolvingGameOver = false;
        });
      }
    }
  }

  Future<void> _rollRewards(int wave, {required int wavesCleared}) async {
    final db = context.read<AlchemonsDatabase>();
    final mastery = context.read<FamilyMasteryService>();
    final rng = Random();
    final popupEntries = <LootOpeningEntry>[];
    final registry = buildInventoryRegistry(db);

    final rolledReward = LootBoxConfig.rollSurvivalLootBoxReward(wave, rng);
    if (rolledReward != null) {
      final openedRewards = LootBoxConfig.rollBossLootBoxDropsForQuantity(
        rolledReward.boxKey,
        rolledReward.quantity,
        rng,
      );
      for (final reward in openedRewards) {
        await db.inventoryDao.addItemQty(reward.key, reward.value);
      }
      popupEntries.addAll(
        openedRewards.map((entry) {
          final def = registry[entry.key];
          final imagePath = InventoryImageHelper.getImage(entry.key);
          return LootOpeningEntry(
            icon: def?.icon ?? AppIcons.inventory_2_rounded,
            name: def?.name ?? entry.key,
            label: 'x${entry.value}',
            color: _C.accent,
            imagePath: imagePath,
            visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
              key: entry.key,
              assetName: imagePath,
              icon: def?.icon,
              size: size,
            ),
          );
        }),
      );
      final powerupRewards = rollCosmicSurvivalPowerupRewards(wave, rng);
      if (powerupRewards.isNotEmpty) {
        for (final reward in powerupRewards) {
          await db.inventoryDao.addItemQty(reward.key, reward.value);
        }
        popupEntries.addAll(
          powerupRewards.map((entry) {
            final type = alchemicalPowerupTypeFromInventoryKey(entry.key);
            final imagePath = InventoryImageHelper.getImage(entry.key);
            return LootOpeningEntry(
              icon: type?.icon ?? AppIcons.blur_on_rounded,
              name: type?.name ?? entry.key,
              label: 'x${entry.value}',
              color: type?.color ?? _C.accent,
              imagePath: imagePath,
              visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
                key: entry.key,
                assetName: imagePath,
                icon: type?.icon,
                size: size,
              ),
            );
          }),
        );
      }
    }

    if (PotentialSoulRules.rollsFromSurvival(wave, rng)) {
      await db.inventoryDao.addItemQty(InvKeys.potentialSoul, 1);
      final def = registry[InvKeys.potentialSoul];
      popupEntries.add(
        LootOpeningEntry(
          icon: def?.icon ?? AppIcons.diamond_rounded,
          name: def?.name ?? 'Potential Soul',
          label: 'x1',
          color: const Color(0xFFB66CFF),
          visualBuilder: (size) => InventoryImageHelper.getVisualWidget(
            key: InvKeys.potentialSoul,
            icon: def?.icon,
            size: size,
          ),
        ),
      );
    }

    // Currency always granted regardless of loot box roll.
    final currencyRewards = LootBoxConfig.rollSurvivalBonusCurrency(wave, rng);
    final silver = currencyRewards['silver'] ?? 0;
    final gold = currencyRewards['gold'] ?? 0;
    if (silver > 0) {
      await db.currencyDao.addSilver(silver);
      popupEntries.add(
        LootOpeningEntry(
          icon: AppIcons.monetization_on_rounded,
          coin: CoinKind.silver,
          name: 'Silver',
          label: '+$silver',
          color: const Color(0xFFB0BEC5),
        ),
      );
    }
    if (gold > 0) {
      await db.currencyDao.addGold(gold);
      popupEntries.add(
        LootOpeningEntry(
          icon: AppIcons.stars_rounded,
          coin: CoinKind.gold,
          name: 'Gold',
          label: '+$gold',
          color: _C.accent,
        ),
      );
    }

    // Each family's mastery, shown by the first creature of it that was
    // fielded, with what each of its creatures earned toward it.
    for (final (family, points, members) in await _bankMastery(
      mastery,
      wavesCleared,
    )) {
      popupEntries.add(
        familyMasteryRewardEntry(
          family: family,
          points: points,
          imagePath: members.first.$1.imagePath,
          creatures: [
            for (final (member, earned) in members)
              (member.displayName, earned),
          ],
        ),
      );
    }

    if (!mounted) return;
    _gameOverRewardEntries = List.from(popupEntries);
  }

  /// The waves [game] has fully cleared, for its mastery points.
  int _wavesClearedBy(CosmicSurvivalGame game) => survivalWavesCleared(
    currentWave: game.spawner.currentWave,
    intermission: game.spawner.intermission,
  );

  /// Pays this run's mastery, once per run however the run ends. Each
  /// creature in the party earns its own points — more for having gone out,
  /// more again for its share of what the team did
  /// ([familyMasteryCreatureAwards]) — and each family is paid what its
  /// creatures earned between them. Returns, in party order, what each family
  /// earned and each of its creatures' part in it.
  Future<List<(CreatureFamily, int, List<(CosmicPartyMember, int)>)>>
  _bankMastery(FamilyMasteryService mastery, int wavesCleared) async {
    if (_masteryBanked) return const [];
    _masteryBanked = true;
    final game = _game;
    final party = game?.party ?? _party ?? const <CosmicPartyMember>[];
    final members = <CosmicPartyMember>[];
    final creatures = <FamilyMasteryRunCreature>[];
    for (final (slot, member) in party.indexed) {
      final family = creatureFamilyFromStorage(member.family);
      if (family == null) continue;
      final s = game?.companionRunStats[slot];
      // Out at some point: summoned, or with anything to its name.
      final deployed =
          (game?.deployedCompanionSlots.contains(slot) ?? false) ||
          (s != null &&
              (s.damageDealt > 0 ||
                  s.kills > 0 ||
                  s.healingDone > 0 ||
                  s.damageTaken > 0));
      members.add(member);
      creatures.add(
        FamilyMasteryRunCreature(
          family: family,
          deployed: deployed,
          damageDealt: s?.damageDealt ?? 0,
          kills: s?.kills ?? 0,
          healingDone: s?.healingDone ?? 0,
        ),
      );
    }
    final awards = familyMasteryCreatureAwards(creatures, wavesCleared);
    final earned = await mastery.awardRun(
      familyMasteryFamilySums(creatures, awards),
    );
    return [
      for (final MapEntry(key: family, value: points) in earned.entries)
        (
          family,
          points,
          [
            for (var i = 0; i < creatures.length; i++)
              if (creatures[i].family == family && awards[i] > 0)
                (members[i], awards[i]),
          ],
        ),
    ];
  }

  Future<void> _saveHighScore() async {
    final db = context.read<AlchemonsDatabase>();
    final currentBestStr = await db.settingsDao.getSetting(
      'cosmic_survival_high_score',
    );
    final currentBest = int.tryParse(currentBestStr ?? '') ?? 0;
    if (_finalScore > currentBest) {
      await db.settingsDao.setSetting(
        'cosmic_survival_high_score',
        _finalScore.toString(),
      );
    }
    final currentBestWaveStr = await db.settingsDao.getSetting(
      'cosmic_survival_best_wave',
    );
    final currentBestWave = int.tryParse(currentBestWaveStr ?? '') ?? 0;
    if (_finalWave > currentBestWave) {
      await db.settingsDao.setSetting(
        'cosmic_survival_best_wave',
        _finalWave.toString(),
      );
    }
    // The lobby header reads the high-score table, not the keys above.
    await db.saveSurvivalHighScore(
      wave: _finalWave,
      score: _finalScore,
      timeMs: ((_game?.stats.timeElapsed ?? 0) * 1000).round(),
    );
    await _loadHighScore();
  }

  Future<void> _replay() async {
    if (_replaying) return;
    var party = _party;
    if (party != null &&
        _runWasResumed &&
        !party.any((m) => _isTestMember(m.instanceId))) {
      // A continued run's party was frozen when that run started; a new run
      // takes the creatures as they are now, and only if they are all here.
      final ids = [for (final m in party) m.instanceId];
      _replaying = true;
      final fresh = await _buildParty(
        ids,
      ).whenComplete(() => _replaying = false);
      if (!mounted) return;
      party = fresh != null && fresh.length == ids.length ? fresh : null;
    }
    _game = null;
    _mysticOverlayController.clear();
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    _showPauseMenu = false;
    if (party != null) {
      _party = party;
      _startGame(party);
    } else {
      _newTeam();
    }
  }

  /// Back to the lobby, the team still chosen, and on into the picker.
  void _newTeam() {
    _game = null;
    _party = null;
    _mysticOverlayController.clear();
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    _runLobbyClock(true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_pickTeam());
    });
    setState(() {
      _phase = _Phase.lobby;
      _powerUpChoices = [];
      _showPauseMenu = false;
      _bossAnnouncement = null;
      _bossAnnouncementSubtitle = null;
      _waveAnnouncementTitle = null;
      _waveAnnouncementSubtitle = null;
      _pendingWaveAnnouncements.clear();
      _resolvingGameOver = false;
    });
  }

  bool _exiting = false;

  void _exit() {
    // Once, and never off the bottom of the stack. Belt and braces beside
    // the `didPop` guard above: a screen that can empty the navigator is a
    // black screen with no error and nothing in the log.
    if (_exiting || !mounted) return;
    _exiting = true;
    unawaited(context.read<AudioController>().playHomeMusic());
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  void _togglePauseMenu() {
    final game = _game;
    if (game == null || _powerUpChoices.isNotEmpty || game.isGameOver) return;
    setState(() {
      _showPauseMenu = !_showPauseMenu;
      game.gamePaused = _showPauseMenu;
      if (_showPauseMenu) _soundController?.stopSoundOwner(this);
    });
  }

  void _toggleFastForward() {
    final game = _game;
    if (game == null) return;
    setState(() {
      game.timeScale = game.timeScale > 1
          ? 1
          : CosmicSurvivalGame.fastForwardTimeScale;
    });
    HapticFeedback.selectionClick();
  }

  void _toggleAutopilot() {
    final game = _game;
    if (game == null ||
        !game.isLoaded ||
        game.isGameOver ||
        _showPauseMenu ||
        _powerUpChoices.isNotEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    game.setAutopilot(!game.autopilot);
  }

  void _closePauseMenu() {
    final game = _game;
    if (game == null) return;
    setState(() {
      _showPauseMenu = false;
      game.gamePaused = false;
    });
  }

  /// SAVE & EXIT: the run is kept, at the start of the wave in progress and
  /// with no more health than it has now, and the player is back in the
  /// lobby with CONTINUE. Nothing is paid out — no loot, no silver or gold,
  /// no mastery — until the run ends.
  Future<void> _quitRunFromPause() async {
    final game = _game;
    if (game == null || game.isGameOver) return;
    final wave = _checkpoint?.wave ?? game.spawner.currentWave;
    final leave = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kLeaveQuietAccent,
      title: 'SAVE & EXIT?',
      message:
          'The run is saved from the start of wave $wave. Continue it from '
          'the survival lobby. Rewards and mastery are paid when the run '
          'ends.',
      cancelLabel: 'STAY',
      confirmLabel: 'SAVE & EXIT',
    );
    if (!leave || !mounted || !identical(_game, game) || game.isGameOver) {
      return;
    }
    final saved = _runAsLeft(game);
    _keepRun = false;
    _queueRunSave(saved);
    await _runSaves;
    if (!mounted) return;
    _returnToLobby(saved);
  }

  /// Out of the run and back to the lobby, with [saved] to continue.
  void _returnToLobby(SuspendedSurvivalRun saved) {
    _soundController?.stopSoundOwner(this);
    _game = null;
    _party = null;
    _checkpoint = null;
    _mysticOverlayController.clear();
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    _runLobbyClock(true);
    setState(() {
      _phase = _Phase.lobby;
      _suspended = saved;
      _suspendedBroken = false;
      _powerUpChoices = [];
      _showPauseMenu = false;
      _bossAnnouncement = null;
      _bossAnnouncementSubtitle = null;
      _waveAnnouncementTitle = null;
      _waveAnnouncementSubtitle = null;
      _pendingWaveAnnouncements.clear();
      _resolvingGameOver = false;
    });
  }

  Future<void> _handleBackPressed() async {
    // The run is already on its way in.
    if (_entrance.active) return;
    if (_phase != _Phase.playing) {
      _exit();
      return;
    }
    final game = _game;
    if (game == null || game.isGameOver) {
      _exit();
      return;
    }
    if (!_showPauseMenu) {
      setState(() {
        _showPauseMenu = true;
        game.gamePaused = true;
      });
      return;
    }
    await _quitRunFromPause();
  }

  void _showPowerUpInfo(
    PowerUpDef def,
    PowerUpState state, {
    int? slotIndex,
    String? targetName,
  }) {
    final level = state.displayedLevel(def, slotIndex: slotIndex);
    final owner =
        targetName ??
        (slotIndex != null && _party != null && slotIndex < _party!.length
            ? _party![slotIndex].displayName
            : null);
    showDialog<void>(
      context: context,
      builder: (_) => _SurvivalDialog(
        accent: _rarityColor(def.rarity),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(def.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      def.name,
                      style: TextStyle(
                        color: _rarityColor(def.rarity),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    'Lv $level/${def.maxStacks}',
                    style: const TextStyle(
                      color: _C.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PauseStatChip(
                    label: 'Rarity',
                    value: _rarityLabel(def.rarity),
                    tint: _rarityColor(def.rarity),
                  ),
                  _PauseStatChip(
                    label: 'Scope',
                    value: def.scope == PowerUpScope.companion
                        ? 'Per Mon'
                        : 'Global',
                    tint: def.scope == PowerUpScope.companion
                        ? _C.teal
                        : _C.accent,
                  ),
                  if (owner != null)
                    _PauseStatChip(
                      label: 'Target',
                      value: owner,
                      tint: _C.teal,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                def.description,
                style: const TextStyle(
                  color: _C.textPrimary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _PauseActionButton(
                  label: 'CLOSE',
                  icon: AppIcons.close_rounded,
                  filled: false,
                  onTap: context.soundTap(() => Navigator.of(context).pop()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompanionStats(int slotIndex) {
    final game = _game;
    final party = _party;
    if (game == null || party == null || slotIndex >= party.length) return;
    final member = party[slotIndex];
    final s = game.companionRunStats[slotIndex];
    final heal = game.healingStats;
    final deployed =
        game.activeCompanions.containsKey(slotIndex) ||
        (s != null && (s.damageDealt > 0 || s.damageTaken > 0 || s.kills > 0));

    final fam = member.family.isEmpty
        ? member.family
        : '${member.family[0].toUpperCase()}${member.family.substring(1)}';
    final specialInfo = cosmicFamilySpecialInfo(fam, member.element);

    String n(num v) => v.round().toString();

    final accent = elementColor(member.element);
    final comp = game.activeCompanions[slotIndex];
    final down =
        game.defeatedCompanionSlots.contains(slotIndex) ||
        (comp?.isDead ?? false);
    final statusLabel = down
        ? 'DOWN'
        : comp == null
        ? 'RESERVE'
        : game.tetheredCompanionSlot == slotIndex
        ? 'FOLLOWING'
        : 'DEPLOYED';
    final statusColor = down
        ? _C.danger
        : comp == null
        ? _C.textMuted
        : _C.success;
    final world = game.mysticWorldReadout(slotIndex);
    // An infinite cooldown means a world is out and the cast is spent until
    // recall — not "999 seconds", and never `.ceil()`, which throws.
    final cd = comp?.specialCooldown ?? 0;
    final full = comp?.effectiveSpecialCooldown ?? 1;
    final specialReady = !cd.isFinite
        ? 1.0
        : cd <= 0.05
        ? 1.0
        : full <= 0
        ? 1.0
        : (1.0 - cd / full).clamp(0.0, 1.0);
    final specialReadout = !cd.isFinite
        ? 'WORLD OUT'
        : cd <= 0.05
        ? 'READY'
        : '${cd.ceil()}s';

    showDialog<void>(
      context: context,
      builder: (_) => _SurvivalDialog(
        accent: accent,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The creature's own element lights the dialog and marks its
              // name, so which alchemon you opened is readable before you
              // read the name. It was a generic teal frame for all seventeen.
              Row(
                children: [
                  MarkDiamond(color: elementLight(member.element), size: 9),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: TextStyle(
                            color: Color.lerp(_C.textPrimary, accent, 0.22),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${fam.toUpperCase()} · ${member.element.toUpperCase()}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PauseStatusPill(label: statusLabel, color: statusColor),
                ],
              ),
              const SizedBox(height: 12),
              // LIVE STATE. The dialog used to open on lore and career totals
              // with no word on the creature standing in the fight right now —
              // whether it is hurt, whether its ability is ready, whether its
              // world is out. That is what the player paused to find out.
              if (comp != null) ...[
                _PauseVitalBar(
                  label: 'HP',
                  value: comp.hpPercent,
                  readout: '${(comp.hpPercent * 100).round()}%',
                  tint: accent,
                  critical: comp.hpPercent < 0.34,
                ),
                const SizedBox(height: 7),
                _PauseVitalBar(
                  label: 'SPECIAL',
                  value: specialReady,
                  readout: specialReadout,
                  tint: _C.teal,
                  critical: false,
                ),
                const SizedBox(height: 12),
              ],
              if (world != null) ...[
                _PauseWorldPanel(
                  name: cosmicSpecialAbilityName('mystic', world.element),
                  element: world.element,
                  effect: world.effect,
                  status: world.status,
                  casterName: member.displayName,
                  fading: world.strength < 0.999,
                ),
                const SizedBox(height: 12),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _EtchedDivider(label: 'COMBAT ROLE'),
                      const SizedBox(height: 10),
                      _InfoBlock(
                        label: 'Special Ability',
                        value: cosmicSpecialAbilityName(
                          member.family,
                          member.element,
                        ),
                        text: specialInfo.description,
                      ),
                      _InfoBlock(
                        label: 'Focus',
                        text: _familyFocusBlurb(member.family),
                      ),
                      _InfoBlock(
                        label: 'Positioning',
                        text: _familyPositionBlurb(member.family),
                      ),
                      const SizedBox(height: 14),
                      const _EtchedDivider(label: 'CONTRIBUTION'),
                      const SizedBox(height: 10),
                      if (!deployed)
                        const Text(
                          'Not deployed yet this run.',
                          style: TextStyle(
                            color: _C.textSecondary,
                            fontSize: 12,
                          ),
                        )
                      else ...[
                        _StatLine(
                          label: 'Damage dealt',
                          value: n(s?.damageDealt ?? 0),
                          tint: _C.amberBright,
                        ),
                        _StatLine(
                          label: 'Enemies killed',
                          value: n(s?.kills ?? 0),
                          tint: _C.amberBright,
                        ),
                        _StatLine(
                          label: 'Damage taken',
                          value: n(s?.damageTaken ?? 0),
                          tint: _C.danger,
                        ),
                        _StatLine(
                          label: 'Healing done',
                          value: n(s?.healingDone ?? 0),
                          tint: _C.success,
                        ),
                      ],
                      const SizedBox(height: 14),
                      const _EtchedDivider(label: 'TEAM HEALING'),
                      const SizedBox(height: 10),
                      _StatLine(
                        label: 'To alchemons',
                        value: n(heal.toMons),
                        tint: _C.teal,
                      ),
                      _StatLine(
                        label: 'To ship',
                        value: n(heal.toShip),
                        tint: _C.teal,
                      ),
                      _StatLine(
                        label: 'To orb',
                        value: n(heal.toOrb),
                        tint: _C.teal,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: _PauseActionButton(
                  label: 'CLOSE',
                  icon: AppIcons.close_rounded,
                  filled: false,
                  onTap: context.soundTap(() => Navigator.of(context).pop()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final game = _game;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        // DID IT ALREADY POP? Then there is nothing to decide. Without this
        // the screen popped TWICE and took the home screen with it, leaving
        // an empty navigator and a black screen: back press arrives with
        // didPop false, `_exit` calls `Navigator.pop`, and that pop comes
        // straight back through this callback with didPop true and pops
        // again. Every other PopScope in this app guards on it.
        if (didPop || !mounted) return;
        unawaited(_handleBackPressed());
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        // The run and the lobby are siblings, keyed, so neither is rebuilt
        // from scratch when the other comes or goes: during an entrance the
        // held run sits under the lobby while the core carries it in. The
        // results come up over the run's own stilled arena.
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (game != null)
              KeyedSubtree(
                key: const ValueKey('survival.run'),
                child: _buildGameScreen(),
              ),
            if (_phase == _Phase.lobby)
              KeyedSubtree(
                key: const ValueKey('survival.lobby'),
                child: _buildLobby(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: _C.accent));
  }

  // ── Lobby ──────────────────────────────────────────────

  /// The lobby: header, the live stage, then the team and what rides with
  /// it, and BASE COMMAND | START at the foot. Laid out from the constants in
  /// survival_lobby_stage.dart, which [survivalLobbyOrbFor] reads too.
  ///
  /// During an entrance the same tree stays, fading, and the entrance
  /// overlay draws the stage over it.
  Widget _buildLobby() {
    final entering = _entrance.active;
    // Read, not watched: the stage below watches the orb for itself, and
    // the entrance overlay only exists once START has fixed it. A kept run
    // goes in with the orb and ship it started with.
    final orb =
        _game?.upgradeState.equippedSkin ??
        _suspended?.equippedOrb ??
        context.read<SurvivalUpgradeService>().state.equippedSkin;
    final suspended = _suspended;
    final stage = survivalLobbyStageRect(
      MediaQuery.sizeOf(context),
      MediaQuery.paddingOf(context),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(
          ignoring: entering,
          child: ListenableBuilder(
            listenable: _entrance,
            builder: (context, child) =>
                Opacity(opacity: _entrance.chrome, child: child),
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: kSurvivalLobbyHeaderHeight,
                    child: _buildMenuHeader(),
                  ),
                  SizedBox(
                    height: kSurvivalLobbyStageHeight,
                    child: _buildLobbyStage(hidden: entering),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      // Its own layer, so scrolling moves the page rather
                      // than re-recording every rule and readout on it each
                      // frame.
                      child: RepaintBoundary(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SurvivalLobbyTeam(
                              members: suspended?.party ?? _team,
                              slots: _defaultPartySize,
                              loaded: _teamLoaded,
                              accent: _brass.amber,
                              onChoose: () => unawaited(_pickTeam()),
                              locked: suspended != null,
                              note: suspended == null
                                  ? null
                                  : _suspendedBroken
                                  ? 'An Alchemon from the wave '
                                        '${suspended.wave} run is no longer '
                                        'in your collection, so that run '
                                        'cannot continue.'
                                  : 'This team is in the saved wave '
                                        '${suspended.wave} run. Start a new '
                                        'run to change it.',
                            ),
                            const SizedBox(height: 22),
                            // What each family has toward its next node; a
                            // tap opens that family's tree.
                            SurvivalMasteryStrip(
                              teamFamilies: {
                                for (final m in suspended?.party ?? _team)
                                  ?creatureFamilyFromStorage(m.family),
                              },
                              onOpen: (family) =>
                                  unawaited(_openBaseCommand(family: family)),
                            ),
                            const SizedBox(height: 22),
                            _buildCommandHub(),
                            if (_debugToolsEnabled) ...[
                              const SizedBox(height: 22),
                              const PanelSectionHeader('TEST TEAMS'),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final preset in _testTeamPresets)
                                    _TestTeamChip(
                                      preset: preset,
                                      onTap: () => _startTestTeam(
                                        _buildFullElementTestTeam(
                                          preset.family,
                                        ),
                                        preset.key,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildLobbyDock(),
                ],
              ),
            ),
          ),
        ),
        if (entering)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: SurvivalOrbEntrancePainter(
                  scene: _scene,
                  clock: _lobbyClock,
                  state: _entrance,
                  stage: stage,
                  orb: orb,
                  shipSkin: _game != null ? _game!.shipSkin : _lobbyShipSkin,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The ship the lobby shows: a kept run's own, or the one picked in Base
  /// Command (null is the standard hull either way).
  String? get _lobbyShipSkin =>
      _suspended != null ? _suspended!.shipSkin : _shipSkin;

  /// What there is to do, always in reach at the foot of the lobby: into
  /// Base Command, or into the run. START is lit once there is a team to
  /// take; before that it opens the picker. With a run kept, CONTINUE is
  /// the thing to do and NEW RUN (which abandons it) the quiet way round.
  Widget _buildLobbyDock() {
    final suspended = _suspended;
    if (suspended != null) return _buildSuspendedDock(suspended);
    final ready = _team.isNotEmpty;
    return Container(
      key: const ValueKey('survival.dock'),
      color: _C.bg1,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: BracketButton(
              key: const ValueKey('survival.baseCommand'),
              label: 'BASE COMMAND',
              primary: false,
              height: 48,
              palette: panelPalette,
              accent: _brass.amber,
              onTap: () => _openBaseCommand(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: BracketButton(
              key: const ValueKey('survival.start'),
              label: 'START',
              primary: ready,
              height: 48,
              palette: panelPalette,
              accent: _brass.amberBright,
              onTap: _start,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuspendedDock(SuspendedSurvivalRun suspended) {
    // A run whose party has gone can only be abandoned: NEW RUN is then the
    // one thing to do, and lit.
    final canContinue = !_suspendedBroken;
    return Container(
      key: const ValueKey('survival.dock'),
      color: _C.bg1,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canContinue) ...[
            BracketButton(
              key: const ValueKey('survival.continue'),
              label: 'CONTINUE · WAVE ${suspended.wave}',
              height: 48,
              palette: panelPalette,
              accent: _brass.amberBright,
              onTap: () => unawaited(_continueRun()),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: BracketButton(
                  key: const ValueKey('survival.baseCommand'),
                  label: 'BASE COMMAND',
                  primary: false,
                  height: canContinue ? 40 : 48,
                  palette: panelPalette,
                  accent: _brass.amber,
                  onTap: () => _openBaseCommand(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BracketButton(
                  key: const ValueKey('survival.newRun'),
                  label: 'NEW RUN',
                  primary: !canContinue,
                  height: canContinue ? 40 : 48,
                  palette: panelPalette,
                  accent: canContinue ? _brass.amber : _brass.amberBright,
                  onTap: () => unawaited(_newRun()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
      child: Row(
        children: [
          BracketIconButton(
            icon: AppIcons.chevron_left_rounded,
            size: 36,
            palette: panelPalette,
            onTap: _exit,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SURVIVAL',
                  maxLines: 1,
                  style: panelLabel(14, panelPalette.ink, spacing: 3),
                ),
                const SizedBox(height: 3),
                Text(
                  'ENDLESS WAVES',
                  maxLines: 1,
                  style: panelLabel(9.5, panelPalette.muted, spacing: 1.6),
                ),
              ],
            ),
          ),
          // What Base Command spends, shown where the decision to go in there
          // is made.
          CoinAmount(kind: CoinKind.gold, amount: _gold, size: 11.5),
          const SizedBox(width: 12),
          CoinAmount(kind: CoinKind.silver, amount: _silver, size: 11.5),
        ],
      ),
    );
  }

  /// The core about to be defended, live, with the ship orbiting it; what it
  /// does, and the best run so far. [hidden]: the entrance is drawing it.
  Widget _buildLobbyStage({bool hidden = false}) {
    return Consumer<SurvivalUpgradeService>(
      builder: (context, svc, _) {
        final orb = getOrbBaseDef(
          _suspended?.equippedOrb ?? svc.state.equippedSkin,
        );
        final best = _highScore;
        return Stack(
          children: [
            Positioned.fill(
              child: SurvivalLobbyStage(
                orb: orb.skin,
                shipSkin: _lobbyShipSkin,
                clock: _lobbyClock,
                scene: _scene,
                hidden: hidden,
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    orb.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: panelLabel(
                      11.5,
                      orbLook(orb.skin).rim,
                      spacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    orb.ability,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _display(context, 12, _C.textSecondary),
                  ),
                ],
              ),
            ),
            if (best != null && best.bestWave > 0)
              Positioned(
                right: 12,
                top: 6,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: context.soundAction(_showHighScoreDetails),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'BEST W${best.bestWave}',
                          style: panelLabel(10.5, _brass.amberBright),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatHighScoreNumber(best.bestScore),
                          style: panelLabel(10.5, panelPalette.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Base Command, from anywhere in the lobby. Opens on Mastery, showing
  /// [family]'s tree — or, when none is given, the tree of the team's first
  /// Alchemon.
  Future<void> _openBaseCommand({CreatureFamily? family}) async {
    final team = _suspended?.party ?? _team;
    final shown =
        family ??
        (team.isEmpty ? null : creatureFamilyFromStorage(team.first.family));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CosmicSurvivalBaseCommandScreen(
          hideAbilities: true,
          initialMasteryFamily: shown,
        ),
      ),
    );
    await _loadSilver();
    await _loadShipSkin();
  }

  /// The guardian upgrades riding on this run, each axis a reading — dim at
  /// zero, which on a fresh save is the point: they show what there is to go
  /// and earn in Base Command.
  Widget _buildCommandHub() {
    return Consumer<SurvivalUpgradeService>(
      builder: (context, svc, _) {
        final earned = kGuardianUpgrades
            .where((d) => svc.state.getGuardianLevel(d.upgrade) > 0)
            .length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PanelSectionHeader(
              'GUARDIAN UPGRADES',
              trailing: '$earned / ${kGuardianUpgrades.length}',
            ),
            PanelRow(
              gap: 6,
              children: [
                for (final def in kGuardianUpgrades)
                  _guardianReading(
                    def,
                    svc.state.getGuardianLevel(def.upgrade),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Short names for the guardian axes, for a reading's label. Anything
  /// not named here goes by the last word of its name.
  static const Map<GuardianUpgrade, String> _guardianLabels = {
    GuardianUpgrade.cooldown: 'SPEED',
    GuardianUpgrade.defense: 'DEFENSE',
    GuardianUpgrade.attack: 'ATTACK',
    GuardianUpgrade.range: 'RANGE',
  };

  Widget _guardianReading(GuardianUpgradeDef def, int level) {
    final earned = level > 0;
    final tint = earned ? def.color : panelPalette.muted;
    return PanelReadout(
      label:
          _guardianLabels[def.upgrade] ??
          def.name.split(' ').last.toUpperCase(),
      value: def.bonusLabel(level),
      color: earned ? null : panelPalette.muted,
      leading: Icon(
        // Range wore the same crosshair as another axis.
        def.upgrade == GuardianUpgrade.range
            ? AppIcons.zoom_out_map_rounded
            : def.icon,
        size: 12,
        color: tint,
      ),
      onTap: () => _openBaseCommand(),
    );
  }

  // ── Game Phase ─────────────────────────────────────────

  Widget _buildGameScreen() {
    final game = _game;
    if (game == null) return _buildLoading();

    // Once the core gives out the controls go, the arena stills under its
    // fall, and the results come up over it.
    final over = game.isGameOver;
    // While the core carries the player in, the run is held under the lobby:
    // its arena fades in round the core, and nothing of the HUD shows or
    // takes a touch until it is released.
    final entering = _entrance.active;
    final hideHud = over || entering;
    return ValueListenableBuilder<bool>(
      valueListenable: game.autopilotState,
      builder: (_, cameraMode, __) => Stack(
        fit: StackFit.expand,
        children: [
          // Flame game
          IgnorePointer(
            ignoring: entering,
            child: ListenableBuilder(
              listenable: _entrance,
              builder: (context, child) =>
                  Opacity(opacity: _entrance.arena, child: child),
              child: GameWidget(
                key: ObjectKey(game),
                game: game,
                backgroundBuilder: (_) => Container(color: Colors.transparent),
              ),
            ),
          ),

          // Autopilot camera: while the ship flies itself, a drag pans, a
          // pinch zooms, and a double-tap brings the camera home. The game's
          // own pan detector ignores drags in this mode, so nothing is lost.
          if (game.autopilot && !over)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onScaleStart: (_) => game.beginCameraGesture(),
                onScaleUpdate: (d) => game.cameraGesture(
                  panDelta: d.focalPointDelta,
                  scale: d.scale,
                  focalPoint: d.localFocalPoint,
                ),
                onDoubleTap: () {
                  HapticFeedback.selectionClick();
                  game.recenterCamera();
                },
              ),
            ),

          // Where the ship is when it has left the frame, and whether it is
          // being hit. Only matters once the camera can leave it.
          if (game.autopilot && !over)
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<int>(
                  valueListenable: _liveUiTick,
                  builder: (_, __, ___) =>
                      CustomPaint(painter: _ShipEdgeMarkerPainter(game)),
                ),
              ),
            ),

          Positioned.fill(
            child: MysticGraphxOverlay(controller: _mysticOverlayController),
          ),

          IgnorePointer(
            ignoring: hideHud,
            child: AnimatedOpacity(
              opacity: hideHud ? 0 : 1,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              child: _buildLivePlayOverlay(game),
            ),
          ),

          // Joystick (bottom left). Re-check `game.isLoaded` on live ticks so
          // enabled joystick appears as soon as the game finishes loading.
          ValueListenableBuilder<int>(
            valueListenable: _liveUiTick,
            builder: (_, __, ___) {
              if (!game.isLoaded ||
                  !_showJoystick ||
                  game.autopilot ||
                  game.isGameOver) {
                return const SizedBox.shrink();
              }
              // Held through the entrance, then easing in with the HUD.
              final held = _entrance.active;
              return Positioned(
                bottom: 20,
                left: 12,
                child: IgnorePointer(
                  ignoring: held,
                  child: AnimatedOpacity(
                    opacity: held ? 0 : 1,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    child: SafeArea(
                      child: VirtualJoystick(
                        sizeMultiplier: _largeJoystick ? 1.35 : 1.0,
                        onDirectionChanged: (dir) {
                          game.setJoystickInput(dir ?? Offset.zero);
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (cameraMode && !over)
            Positioned(
              bottom: 20,
              left: 12,
              child: SafeArea(
                child: HudGlass(
                  accent: HudInk.amber.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CAMERA', style: hudMono(10.5, HudInk.amber)),
                      const SizedBox(height: 4),
                      Text(
                        'DRAG TO PAN · PINCH TO ZOOM\nTHE SHIP FLIES ITSELF',
                        style: hudMono(8.5, HudInk.muted, spacing: 0.8),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 104,
                            child: BracketButton(
                              label: 'FOLLOW SHIP',
                              height: 34,
                              palette: BracketPalette.dark,
                              accent: HudInk.amber,
                              primary: false,
                              onTap: game.recenterCamera,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 74,
                            child: BracketButton(
                              label: 'EXIT',
                              height: 34,
                              palette: BracketPalette.dark,
                              accent: HudInk.amber,
                              onTap: _toggleAutopilot,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Power-up selection overlay
          if (_powerUpChoices.isNotEmpty)
            PowerUpSelectionOverlay(
              choices: _powerUpChoices,
              currentWave: game.spawner.currentWave,
              party: _party ?? const [],
              powerUps: game.powerUps,
              onSelect: _selectPowerUp,
            ),

          if (_showPauseMenu) _buildPauseOverlay(game),

          // Boss announcement
          if (_bossAnnouncement != null && !over)
            Positioned.fill(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 76),
                    child: _SurvivalPlate(
                      accent: _C.danger,
                      background: _C.bg0.withValues(alpha: 0.94),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                AppIcons.warning_amber_rounded,
                                color: _C.danger,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'BOSS INCOMING',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  color: _C.danger,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.4,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _bossAnnouncement!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: _C.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.6,
                            ),
                          ),
                          if (_bossAnnouncementSubtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _bossAnnouncementSubtitle!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: _C.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_waveAnnouncementTitle != null && !over)
            Positioned.fill(
              child: IgnorePointer(
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: _bossAnnouncement != null ? 168 : 76,
                      ),
                      child: AnimatedOpacity(
                        opacity: _waveAnnouncementTitle == null ? 0 : 1,
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOut,
                        child: _SurvivalPlate(
                          accent: _C.amber,
                          background: _C.bg0.withValues(alpha: 0.94),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 26,
                            vertical: 13,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _waveAnnouncementTitle!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: _C.amberBright,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3.4,
                                ),
                              ),
                              if (_waveAnnouncementSubtitle != null) ...[
                                const SizedBox(height: 7),
                                Text(
                                  _waveAnnouncementSubtitle!.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    color: _C.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_phase == _Phase.gameOver)
            Positioned.fill(child: _buildGameOver()),
        ],
      ),
    );
  }

  Widget _buildLivePlayOverlay(CosmicSurvivalGame game) {
    return ValueListenableBuilder<int>(
      valueListenable: _liveUiTick,
      builder: (_, __, ___) => Stack(
        fit: StackFit.expand,
        children: [
          _buildHud(game),
          _buildCompanionPanel(game),
          if (game.outbreak != null &&
              _bossAnnouncement == null &&
              _waveAnnouncementTitle == null &&
              !_showPauseMenu &&
              _powerUpChoices.isEmpty &&
              !game.isGameOver)
            Positioned(
              top: 100,
              left: 44,
              right: 104,
              child: IgnorePointer(
                child: SafeArea(
                  child: _SurvivalPlate(
                    accent: game.outbreak!.color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          game.outbreak!.cleared
                              ? 'OUTBREAK PURGED'
                              : '${game.outbreak!.name} · ${game.outbreak!.remaining} SOURCES',
                          textAlign: TextAlign.center,
                          style: hudMono(10.5, game.outbreak!.color),
                        ),
                        if (!game.outbreak!.cleared)
                          Text(
                            game.outbreak!.instruction,
                            textAlign: TextAlign.center,
                            style: hudMono(
                              8.5,
                              HudInk.muted,
                              weight: FontWeight.w700,
                              spacing: 0.6,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (game.detonationUnlocked &&
              _powerUpChoices.isEmpty &&
              !_showPauseMenu &&
              !game.isGameOver)
            _buildDetonationButton(game),
          if (game.isLoaded && game.ship.isDead && !game.isGameOver)
            _buildGhostShipBanner(game),
        ],
      ),
    );
  }

  Widget _buildDetonationButton(CosmicSurvivalGame game) {
    final isReady = game.detonationReadyNotifier.value;
    final charge = game.detonationChargeFraction;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: AnimatedScale(
            scale: isReady ? 1.08 : 1.0,
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeInOut,
            child: GestureDetector(
              onTap: context.soundAction(
                isReady ? game.triggerDetonation : null,
              ),
              child: Semantics(
                button: true,
                enabled: isReady,
                label: isReady ? 'Detonate' : 'Detonation charging',
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: const Size(64, 64),
                    painter: DetonationVesselPainter(
                      charge: isReady ? 1.0 : charge,
                      ready: isReady,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostShipBanner(CosmicSurvivalGame game) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: HudGlass(
            accent: HudInk.ship.withValues(alpha: 0.6),
            alpha: 0.6,
            bracket: 9,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SHIP DESTROYED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: HudInk.ship.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                if (game.shipRespawnRemaining > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'RESPAWN IN ${game.shipRespawnRemaining.ceil()}s',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _C.textPrimary.withValues(alpha: 0.58),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── HUD ────────────────────────────────────────────────

  Widget _buildHud(CosmicSurvivalGame game) {
    final orbHp = game.isLoaded ? game.orb.hpPercent : 1.0;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SurvivalTopHud(
            wave: game.spawner.currentWave,
            time: game.stats.formattedTime,
            keys: [
              HudKey(
                key: const ValueKey('survival.pause'),
                icon: _showPauseMenu
                    ? AppIcons.play_arrow_rounded
                    : AppIcons.pause_rounded,
                lit: _showPauseMenu,
                tooltip: _showPauseMenu ? 'Resume' : 'Pause',
                onTap: context.soundTap(_togglePauseMenu),
              ),
              SurvivalCameraButton(
                cameraMode: game.autopilotState,
                onToggle: context.soundTap(_toggleAutopilot),
              ),
              // Fast forward: 1.5x. Two was too fast to read a front.
              HudKey(
                icon: AppIcons.fast_forward_rounded,
                lit: game.timeScale > 1,
                tooltip: 'Fast forward',
                onTap: context.soundTap(_toggleFastForward),
              ),
            ],
            shipFraction: game.isLoaded ? game.ship.hpPercent : 1.0,
            shipGhost: game.isLoaded && game.ship.isDead,
            orbFraction: orbHp,
            orbColor: game.isLoaded
                ? orbLook(game.orb.skin).hpColor(orbHp)
                : _C.accent,
            orbShield: game.isLoaded ? game.orbShieldFraction : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildPauseOverlay(CosmicSurvivalGame game) {
    final party = _party ?? const <CosmicPartyMember>[];
    final shownKeys = <String>{};
    final history = game.powerUps.history.reversed.where((entry) {
      final key = '${entry.def.id}:${entry.targetSlot ?? 'global'}';
      if (shownKeys.contains(key)) return false;
      shownKeys.add(key);
      return true;
    }).toList();
    final globalHistory = history
        .where((entry) => entry.def.scope == PowerUpScope.global)
        .toList();
    final keystoneHistory = globalHistory
        .where((entry) => entry.def.isKeystone)
        .toList();
    final standardGlobalHistory = globalHistory
        .where((entry) => !entry.def.isKeystone)
        .toList();
    final companionHistory = <int, List<AppliedPowerUp>>{};
    for (final entry in history) {
      if (entry.def.scope != PowerUpScope.companion ||
          entry.targetSlot == null) {
        continue;
      }
      companionHistory.putIfAbsent(entry.targetSlot!, () => []).add(entry);
    }

    return GestureDetector(
      onTap: context.soundAction(_closePauseMenu),
      child: Container(
        decoration: BoxDecoration(
          color: _C.bg0.withValues(alpha: 0.84),
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.15,
            colors: [
              _C.bg3.withValues(alpha: 0.36),
              _C.bg0.withValues(alpha: 0.88),
            ],
          ),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _SurvivalPlate(
                padding: EdgeInsets.zero,
                background: _C.bg1.withValues(alpha: 0.96),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _C.borderAccent.withValues(alpha: 0.36),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            AppIcons.pause_circle_outline_rounded,
                            color: _C.amberBright,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'SURVIVAL PAUSED',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: _C.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'TACTICAL READOUT',
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: _C.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // VITALS FIRST. The orb is the lose condition and
                            // it used to be a twelve-point chip sitting beside
                            // "Kills", weighted exactly the same as a number
                            // that cannot end your run. A paused player is
                            // usually paused because something is going wrong,
                            // and this is the thing they came here to check.
                            _PauseVitalBar(
                              label: 'ORB',
                              value: game.orb.hpPercent,
                              readout: '${(game.orb.hpPercent * 100).round()}%',
                              tint: orbLook(
                                game.orb.skin,
                              ).hpColor(game.orb.hpPercent),
                              critical: game.orb.hpPercent < 0.34,
                            ),
                            const SizedBox(height: 8),
                            _PauseVitalBar(
                              label: 'SHIP',
                              value: game.ship.isDead ? 0 : game.ship.hpPercent,
                              readout: game.ship.isDead
                                  ? 'DOWN'
                                  : '${(game.ship.hpPercent * 100).round()}%',
                              tint: HudInk.ship,
                              critical:
                                  game.ship.isDead ||
                                  game.ship.hpPercent < 0.34,
                            ),
                            const SizedBox(height: 8),
                            _PauseVitalBar(
                              label: 'SURGE',
                              value: game.alchemicalMeterMax > 0
                                  ? (game.alchemicalMeter /
                                            game.alchemicalMeterMax)
                                        .clamp(0.0, 1.0)
                                  : 0,
                              readout:
                                  '${game.alchemicalMeter.round()}/${game.alchemicalMeterMax.round()}',
                              tint: const Color(0xFF9B7FE0),
                              critical: false,
                            ),
                            const SizedBox(height: 16),

                            // THE WORLD. A Mystic's world is the largest thing
                            // on the map and, until now, the only run state
                            // with no readout anywhere — the player could not
                            // see which world was theirs, what it had standing,
                            // or that pulling the Mystic out would end it.
                            for (var i = 0; i < party.length; i++)
                              if (game.mysticWorldReadout(i) case final w?) ...[
                                _PauseWorldPanel(
                                  name: cosmicSpecialAbilityName(
                                    'mystic',
                                    w.element,
                                  ),
                                  element: w.element,
                                  effect: w.effect,
                                  status: w.status,
                                  casterName: party[i].displayName,
                                  fading: w.strength < 0.999,
                                ),
                                const SizedBox(height: 16),
                              ],

                            // RUN. Secondary by design: interesting, but never
                            // the reason anybody opened this screen mid-fight.
                            _PauseStatRow(
                              children: [
                                _PauseStatChip(
                                  label: 'Wave',
                                  value: '${game.spawner.currentWave}',
                                ),
                                _PauseStatChip(
                                  label: 'Time',
                                  value: game.stats.formattedTime,
                                ),
                                _PauseStatChip(
                                  label: 'Kills',
                                  value: '${game.stats.kills}',
                                ),
                                _PauseStatChip(
                                  label: 'Score',
                                  value: '${game.stats.score}',
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (keystoneHistory.isNotEmpty) ...[
                              const PanelSectionHeader('KEYSTONE'),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: keystoneHistory.map((entry) {
                                  return InkWell(
                                    onTap: context.soundAction(
                                      () => _showPowerUpInfo(
                                        entry.def,
                                        game.powerUps,
                                        slotIndex: entry.targetSlot,
                                        targetName: entry.targetName,
                                      ),
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      color: _chipWash(_C.teal),
                                      child: _PausePowerUpChipContent(
                                        name: entry.def.name,
                                        tint: _C.teal,
                                        level: 1,
                                        maxStacks: 1,
                                        showLevel: false,
                                        badgeLabel: 'KEYSTONE',
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                            ],
                            const PanelSectionHeader('POWERUPS'),
                            const SizedBox(height: 6),
                            const Text(
                              'Tap a perk to see what it does.',
                              style: TextStyle(
                                color: _C.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            globalHistory.isEmpty
                                ? const Text(
                                    'No global upgrades taken yet.',
                                    style: TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 12,
                                    ),
                                  )
                                : standardGlobalHistory.isEmpty
                                ? const Text(
                                    'No standard global upgrades yet.',
                                    style: TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 12,
                                    ),
                                  )
                                : Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: standardGlobalHistory.map((
                                      entry,
                                    ) {
                                      final level = game.powerUps
                                          .displayedLevel(
                                            entry.def,
                                            slotIndex: entry.targetSlot,
                                          );
                                      return InkWell(
                                        onTap: context.soundAction(
                                          () => _showPowerUpInfo(
                                            entry.def,
                                            game.powerUps,
                                            slotIndex: entry.targetSlot,
                                            targetName: entry.targetName,
                                          ),
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          color: _chipWash(
                                            powerUpAccentColor(entry.def),
                                          ),
                                          child: _PausePowerUpChipContent(
                                            name: entry.def.name,
                                            tint: powerUpAccentColor(entry.def),
                                            level: level,
                                            maxStacks: entry.def.maxStacks,
                                            showLevel: entry.def.showLevel,
                                            badgeLabel: entry.def.isKeystone
                                                ? 'KEYSTONE'
                                                : null,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                            const SizedBox(height: 14),
                            const PanelSectionHeader('ALCHEMON STATS'),
                            const SizedBox(height: 8),
                            ListView.separated(
                              itemCount: party.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (_, index) {
                                final member = party[index];
                                final comp = game.activeCompanions[index];
                                return _PauseCompanionCard(
                                  member: member,
                                  companion: comp,
                                  appliedPowerUps:
                                      companionHistory[index] ?? const [],
                                  powerUps: game.powerUps,
                                  vineFeedCount: game.maskPlantFeedCount(index),
                                  onPowerUpTap: (entry) => _showPowerUpInfo(
                                    entry.def,
                                    game.powerUps,
                                    slotIndex: entry.targetSlot,
                                    targetName: entry.targetName,
                                  ),
                                  onTap: context.soundTap(
                                    () => _showCompanionStats(index),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // ── Footer: Actions + Controls ──
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: _C.borderAccent.withValues(alpha: 0.36),
                          ),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // Leaving keeps the run, so it is not red.
                              _PauseActionButton(
                                key: const ValueKey('survival.saveExit'),
                                label: 'SAVE & EXIT',
                                icon: AppIcons.exit_to_app_rounded,
                                onTap: context.soundTap(_quitRunFromPause),
                                fillColor: _C.amber,
                                filled: false,
                                compact: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PauseActionButton(
                                  label: 'RESUME',
                                  icon: AppIcons.play_arrow_rounded,
                                  onTap: context.soundTap(_closePauseMenu),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'JOYSTICK',
                                      style: hudMono(10.5, HudInk.muted),
                                    ),
                                    const Spacer(),
                                    _PauseToggle(
                                      value: _showJoystick,
                                      onChanged: (v) async {
                                        setState(() {
                                          _showJoystick = v;
                                          if (!v) {
                                            game.setJoystickInput(Offset.zero);
                                          }
                                        });
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setBool(
                                          'cosmic_survival_joystick_enabled',
                                          v,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    Text(
                                      'LARGE',
                                      style: hudMono(10.5, HudInk.muted),
                                    ),
                                    const Spacer(),
                                    _PauseToggle(
                                      value: _largeJoystick,
                                      onChanged: (v) async {
                                        setState(() => _largeJoystick = v);
                                        final prefs =
                                            await SharedPreferences.getInstance();
                                        await prefs.setBool(
                                          'cosmic_survival_large_joystick',
                                          v,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Companion Panel ────────────────────────────────────

  Widget _buildCompanionPanel(CosmicSurvivalGame game) {
    final party = _party;
    if (party == null || party.isEmpty) return const SizedBox.shrink();

    final tethered = game.companionTethered;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = max(
      120.0,
      screenHeight - MediaQuery.paddingOf(context).vertical - 120.0,
    );
    // Give the party the height it actually needs, not half the screen.
    //
    // A full party of five wants about 410 here, and the old cap was the
    // lesser of half the screen and 430 — so five slots scrolled even when
    // there was room below them for all of it. Scrolling a five-item HUD to
    // find a companion mid-fight is the worst moment to be scrolling.
    // Bounded by what is genuinely free rather than by a flat fraction, so a
    // short landscape phone still gives way rather than covering the field.
    const slotStride = 84.0;
    final wanted = party.length * slotStride;
    final slotsMaxHeight = min(
      min(wanted, screenHeight * 0.72),
      max(48.0, availableHeight - 90),
    );
    return Positioned(
      right: 12,
      top: 100,
      child: SafeArea(
        // No plate.
        //
        // The party cards are already bordered boxes; wrapping the column of
        // them in another bordered box drew a frame round a frame and ate
        // width doing it. The cards are the chrome.
        child: SizedBox(
          width: SurvivalPartySlot.cardWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'ACTIVE ',
                        style: hudMono(8, HudInk.muted),
                      ),
                      TextSpan(
                        text:
                            '${game.activeCompanions.values.where((comp) => !comp.isDead).length}/${game.maxActiveCompanions}',
                        style: hudMono(10, HudInk.amber, spacing: 0.6),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: slotsMaxHeight),
                child: Scrollbar(
                  thickness: 3,
                  radius: const Radius.circular(8),
                  thumbVisibility: party.length > 8,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < party.length; i++) ...[
                          _buildCompanionSlot(game, party[i], i),
                          if (i < party.length - 1) const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // The magnet sits under the party it acts on, and matches their
              // width — it used to be above them at 72 against their 54,
              // which made the whole stack look ragged.
              // Tether / Follow toggle
              GestureDetector(
                onTap: context.soundAction(() {
                  HapticFeedback.lightImpact();
                  if (tethered) {
                    game.clearCompanionTether();
                  } else {
                    game.tetherClosestCompanionToShip();
                  }
                  setState(() {});
                }),
                child: HudGlass(
                  accent:
                      (tethered ? SurvivalPartySlot.followColor : HudInk.line)
                          .withValues(alpha: 0.9),
                  child: SizedBox(
                    width: SurvivalPartySlot.cardWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tethered
                                ? AppIcons.link_rounded
                                : AppIcons.link_off_rounded,
                            color: tethered
                                ? SurvivalPartySlot.followColor
                                : HudInk.muted,
                            size: 17,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tethered ? 'FOLLOW' : 'FREE',
                            style: hudMono(
                              7,
                              tethered
                                  ? SurvivalPartySlot.followColor
                                  : HudInk.muted,
                              spacing: 0.8,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildCompanionSlot(
    CosmicSurvivalGame game,
    CosmicPartyMember member,
    int slotIndex,
  ) {
    return SurvivalPartySlot(
      member: member,
      state: SurvivalPartySlotState.fromGame(game, slotIndex),
      feedCount:
          member.family.toLowerCase() == 'mask' && member.element == 'Plant'
          ? game.maskPlantFeedCount(slotIndex)
          : null,
      onTap: () {
        // Recheck at tap time: the companion can fall between UI refreshes.
        final state = SurvivalPartySlotState.fromGame(game, slotIndex);
        if (state.dead) return;
        HapticFeedback.lightImpact();
        if (state.active) {
          game.returnCompanion(slotIndex);
        } else {
          if (game.activeCompanions.length >= game.maxActiveCompanions) {
            final recall = game.activeCompanions.keys.firstWhere(
              (s) => s != game.tetheredCompanionSlot,
              orElse: () => game.activeCompanions.keys.first,
            );
            game.returnCompanion(recall);
          }
          game.summonCompanion(slotIndex);
        }
        setState(() {});
      },
    );
  }

  // ── Game Over Phase ────────────────────────────────────

  Widget _buildGameOver() {
    return CosmicSurvivalGameOverPanel(
      wave: _finalWave,
      kills: _finalKills,
      score: _finalScore,
      time: _finalTime,
      rewards: _gameOverRewardEntries,
      // Rewards and high scores are already banked by the time this panel
      // exists, so quitting only has to take the same way out as the pause
      // menu's QUIT — no confirmation, the run is already over.
      onQuit: _exit,
      onNewTeam: _newTeam,
      onReplay: () => unawaited(_replay()),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HUD WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────
}

/// A marker on the frame's edge pointing at the ship while it is off-screen,
/// flaring when the ship is taking hits.
class _ShipEdgeMarkerPainter extends CustomPainter {
  _ShipEdgeMarkerPainter(this.game);
  final CosmicSurvivalGame game;

  @override
  void paint(Canvas canvas, Size size) {
    if (!game.isLoaded || game.ship.isDead) return;
    final p = game.worldToScreen(game.ship.position);
    const inset = 22.0;
    final inside =
        p.dx >= 0 && p.dx <= size.width && p.dy >= 0 && p.dy <= size.height;
    if (inside) return;
    final centre = size.center(Offset.zero);
    final dir = p - centre;
    if (dir.distance < 1) return;
    // Clamp the marker to the inset rectangle along the ray to the ship.
    final halfW = size.width / 2 - inset;
    final halfH = size.height / 2 - inset;
    final t = min(halfW / dir.dx.abs(), halfH / dir.dy.abs());
    final at = centre + dir * t;
    final angle = atan2(dir.dy, dir.dx);
    final hurt = game.ship.hitFlash > 0;
    final color = hurt ? const Color(0xFFE53935) : _C.teal;
    final glow = Paint()
      ..color = color.withValues(alpha: hurt ? 0.35 : 0.18)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(at, hurt ? 16 : 12, glow);
    final tri = Path()
      ..moveTo(at.dx + cos(angle) * 9, at.dy + sin(angle) * 9)
      ..lineTo(at.dx + cos(angle + 2.5) * 7, at.dy + sin(angle + 2.5) * 7)
      ..lineTo(at.dx + cos(angle - 2.5) * 7, at.dy + sin(angle - 2.5) * 7)
      ..close();
    canvas.drawPath(tri, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ShipEdgeMarkerPainter old) => true;
}

/// A debug preset, compact enough for a row of eight.
class _TestTeamChip extends StatelessWidget {
  const _TestTeamChip({required this.preset, required this.onTap});
  final _SurvivalTestTeamPreset preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: _C.bg2.withValues(alpha: 0.7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(preset.icon, size: 13, color: _C.textSecondary),
            const SizedBox(width: 6),
            Text(
              preset.label,
              style: _display(
                context,
                11,
                _C.textSecondary,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveAnnouncementData {
  final String title;
  final String? subtitle;

  const _WaveAnnouncementData({required this.title, this.subtitle});
}

class _PauseActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color fillColor;
  final bool filled;
  final bool compact;

  const _PauseActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.fillColor = _C.accent,
    this.filled = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // The thing to do is a wash lit from below in its color; the way out
    // beside it is a quiet unlit fill.
    return GestureDetector(
      onTap: context.soundAction(onTap),
      child: CustomPaint(
        foregroundPainter: filled
            ? BracketFramePainter(color: fillColor, strokeWidth: 1.3)
            : null,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 11,
          ),
          color: filled
              ? fillColor.withValues(alpha: 0.13)
              : _C.bg2.withValues(alpha: 0.9),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: compact ? 14 : 16,
                color: fillColor.withValues(alpha: filled ? 1.0 : 0.8),
              ),
              SizedBox(width: compact ? 5 : 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: fillColor.withValues(alpha: filled ? 1.0 : 0.8),
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An ON/OFF key, lit from below while on — the console's switch.
class _PauseToggle extends StatelessWidget {
  const _PauseToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: context.soundAction(() => onChanged(!value)),
        child: HudGlass(
          accent: (value ? HudInk.amber : HudInk.line).withValues(alpha: 0.9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            value ? 'ON' : 'OFF',
            style: hudMono(10.5, value ? HudInk.amber : HudInk.muted),
          ),
        ),
      ),
    );
  }
}

class _PauseStatRow extends StatelessWidget {
  final List<Widget> children;

  const _PauseStatRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: children[i]),
          if (i < children.length - 1) const SizedBox(width: 8),
        ],
        for (var i = children.length; i < 3; i++) ...[
          const Expanded(child: SizedBox.shrink()),
          if (i < 2) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// Deployed / following / reserve / down, as one filled pill.
class _PauseStatusPill extends StatelessWidget {
  const _PauseStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      color: color,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          color: _C.bg0,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

/// A vital, as a labelled bar rather than a number in a chip.
///
/// A bar answers "how bad is it" before the eye reaches the digits, which is
/// the question a paused player is actually asking. Chips made orb health,
/// ship health and kill count all look like the same kind of fact.
class _PauseVitalBar extends StatelessWidget {
  const _PauseVitalBar({
    required this.label,
    required this.value,
    required this.readout,
    required this.tint,
    required this.critical,
  });

  final String label;
  final double value;
  final String readout;
  final Color tint;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final color = critical ? _C.danger : tint;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: hudMono(10.5, HudInk.muted, spacing: 1.4),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 11,
            child: CustomPaint(
              painter: HudTubePainter(value.clamp(0.0, 1.0), color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            readout,
            textAlign: TextAlign.right,
            style: hudMono(
              13,
              critical ? HudInk.danger : HudInk.ink,
              weight: FontWeight.w900,
              spacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// The world a fielded Mystic has made, and the trade that holds it.
///
/// Colored by element and given the widest banner on the screen, because it
/// is the largest thing on the map and the only run state a player cannot see
/// the edges of from inside the fight.
class _PauseWorldPanel extends StatelessWidget {
  const _PauseWorldPanel({
    required this.name,
    required this.element,
    required this.effect,
    required this.status,
    required this.casterName,
    required this.fading,
  });

  final String name;
  final String element;

  /// What this world does, in a sentence.
  final String effect;

  /// How it is going right now.
  final String status;
  final String casterName;
  final bool fading;

  @override
  Widget build(BuildContext context) {
    final accent = elementColor(element);
    // A wash of the element's color, lit from below in it: the one pane on
    // this screen that is about the world rather than the fight.
    return CustomPaint(
      foregroundPainter: BracketFramePainter(color: accent, strokeWidth: 1.3),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color.lerp(_C.bg2, accent, 0.24)!,
              Color.lerp(_C.bg2, accent, 0.06)!,
              _C.bg1,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'YOUR WORLD',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const Spacer(),
                    if (fading)
                      const Text(
                        'CLOSING',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: _C.danger,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  name.toUpperCase(),
                  style: TextStyle(
                    color: Color.lerp(_C.textPrimary, accent, 0.25),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 5),
                // WHAT IT DOES, first. A bare count and a noun fragment
                // told the player nothing they could act on — the world
                // is the thing they gave up their only Mystic slot for,
                // and this is the one screen with room to say what it is.
                Text(
                  effect,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 12.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // The trade, stated plainly. It is the whole mechanic and
                // nothing in the game says it out loud anywhere else.
                Text(
                  'Holds while ${casterName.toUpperCase()} is alive and '
                  'deployed. Recalling ends it and returns the cast.',
                  style: const TextStyle(
                    color: _C.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? tint;

  const _PauseStatChip({required this.label, required this.value, this.tint});

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? _C.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      color: _C.bg2.withValues(alpha: 0.88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The run row carries four chips rather than three now, so each is
          // a quarter of the width instead of a third. A long score has to
          // shrink rather than overflow.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label.toUpperCase(),
              style: hudMono(9.5, HudInk.muted, spacing: 1.4),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: hudMono(14, accent, weight: FontWeight.w900, spacing: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseCompanionCard extends StatelessWidget {
  final CosmicPartyMember member;
  final CosmicSurvivalCompanion? companion;
  final List<AppliedPowerUp> appliedPowerUps;
  final PowerUpState powerUps;
  final ValueChanged<AppliedPowerUp> onPowerUpTap;
  final VoidCallback onTap;

  /// Mask+Plant only — current vine feed count for the slot
  /// (0–100). Ignored for other families.
  final int vineFeedCount;

  const _PauseCompanionCard({
    required this.member,
    required this.companion,
    required this.appliedPowerUps,
    required this.powerUps,
    required this.onPowerUpTap,
    required this.onTap,
    this.vineFeedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final live = companion;

    final slotIndex = member.slotIndex;
    final effSpeed =
        member.statSpeed + powerUps.speedBonus(slotIndex, member.statSpeed);
    final benchedStats = live == null
        ? deriveAlchemonCombatStats(
            member: member,
            strengthBonus: powerUps.strengthBonus(
              slotIndex,
              member.statStrength,
            ),
            intelligenceBonus: powerUps.intelligenceBonus(
              slotIndex,
              member.statIntelligence,
            ),
            beautyBonus: powerUps.beautyBonus(slotIndex, member.statBeauty),
            speedBonus: powerUps.speedBonus(slotIndex, member.statSpeed),
          )
        : null;

    return GestureDetector(
      onTap: context.soundAction(onTap),
      behavior: HitTestBehavior.opaque,
      child: HudGlass(
        accent: (live == null ? HudInk.line : HudInk.amber).withValues(
          alpha: 0.75,
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MarkDiamond(color: elementLight(member.element)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    member.displayName.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: hudMono(11, HudInk.ink, spacing: 1.0),
                  ),
                ),
                Text(
                  live == null
                      ? 'BENCHED'
                      : '${(live.hpPercent * 100).round()}% HP',
                  style: hudMono(
                    10,
                    live == null ? HudInk.muted : HudInk.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 7,
              children: [
                _MiniReadout(
                  label: 'P-ATK',
                  value: live != null
                      ? '${live.physAtk}'
                      : '${benchedStats!.physAtk}',
                ),
                _MiniReadout(
                  label: 'E-ATK',
                  value: live != null
                      ? '${live.elemAtk}'
                      : '${benchedStats!.elemAtk}',
                ),
                _MiniReadout(
                  label: 'P-DEF',
                  value: live != null
                      ? '${live.physDef}'
                      : '${benchedStats!.physDef}',
                ),
                _MiniReadout(
                  label: 'E-DEF',
                  value: live != null
                      ? '${live.elemDef}'
                      : '${benchedStats!.elemDef}',
                ),
                _MiniReadout(
                  label: 'SPD',
                  value: AlchemonStatSystem.displayRating(effSpeed).toString(),
                ),
                _MiniReadout(
                  label: 'SPECIAL',
                  value: live != null
                      ? '${live.abilityAtk}'
                      : '${benchedStats!.abilityAtk}',
                ),
              ],
            ),
            // Mask+Plant: live vine growth readout — feed count,
            // tendril count, and a horizontal progress bar toward
            // the 100-feed max. Hidden for any other family/element.
            if (member.family.toLowerCase() == 'mask' &&
                member.element == 'Plant') ...[
              const SizedBox(height: 8),
              _PauseVineReadout(feeds: vineFeedCount),
            ],
            // Generic "Active State" panel — surfaces any live
            // stacking / collecting / timer state the companion is
            // currently tracking (Wing+Plant flowers, Pip+Spirit
            // kills, Pip+Steam window, Kin+Steam stacks, Kin+Spirit
            // wisp tier, Kin+Mud ship enchant timer, Kin+Dark cloak,
            // Kin+Blood pact, Kin+Lava plate, Kin+Lightning charge,
            // Kin+Ice charge, Kin+Fire phoenix-armed, etc.).
            if (live != null) ...[
              () {
                final entries = _liveStateEntries(member, live);
                if (entries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _PauseLiveStatePanel(entries: entries),
                );
              }(),
            ],
            const SizedBox(height: 8),
            Text('PERKS', style: hudMono(9.5, HudInk.muted, spacing: 1.6)),
            const SizedBox(height: 6),
            if (appliedPowerUps.isEmpty)
              const Text(
                'No personal upgrades yet.',
                style: TextStyle(color: _C.textSecondary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: appliedPowerUps.map((entry) {
                  return InkWell(
                    onTap: context.soundAction(() => onPowerUpTap(entry)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      color: _chipWash(_rarityColor(entry.def.rarity)),
                      child: _PausePowerUpChipContent(
                        name: entry.def.name,
                        tint: _rarityColor(entry.def.rarity),
                        level: powerUps.displayedLevel(
                          entry.def,
                          slotIndex: entry.targetSlot,
                        ),
                        maxStacks: entry.def.maxStacks,
                        showLevel: entry.def.showLevel,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Extract any live-state readouts to render in the pause card.
/// Each entry is `(label, value)` — label is the metric, value is
/// the live state ("3/10", "47/100 · 5t", "12s", "ARMED", etc.).
/// Returns empty when nothing notable is active.
List<(String, String)> _liveStateEntries(
  CosmicPartyMember member,
  CosmicSurvivalCompanion live,
) {
  final fam = member.family.toLowerCase();
  final el = member.element;
  final out = <(String, String)>[];

  String timer(double t) => t > 0 ? '${t.toStringAsFixed(1)}s' : '—';

  // Wing+Plant: flower count → beam-damage stacks (cap 50)
  if (fam == 'wing' && el == 'Plant' && live.abilityKillStacks > 0) {
    out.add(('Flowers collected', '${live.abilityKillStacks}/50'));
  }
  // Pip+Spirit: kill stacks toward empower
  if (fam == 'pip' && el == 'Spirit') {
    out.add(('Spirit stacks', '${live.abilityKillStacks}'));
    if (live.pipSpiritEmpowerTimer > 0) {
      out.add(('Empower window', timer(live.pipSpiritEmpowerTimer)));
    }
  }
  // Pip+Steam: ramp window timer
  if (fam == 'pip' && el == 'Steam' && live.pipSteamWindowTimer > 0) {
    out.add(('Steam ramp', timer(live.pipSteamWindowTimer)));
  }
  // Mask+Spirit: collected wisp bank
  if (fam == 'mask' && el == 'Spirit') {
    out.add((
      'Wisp bank',
      live.maskSpiritClearAt > 0
          ? '${live.maskSpiritWispBank}/${live.maskSpiritClearAt}'
          : '${live.maskSpiritWispBank}',
    ));
  }
  // Kin+Steam boiler
  if (fam == 'kin' && el == 'Steam') {
    if (live.kinSteamBoilerTimer > 0) {
      out.add(('Boiler', '${live.kinSteamBoilerStacks}/10 stacks'));
      out.add(('Duration left', timer(live.kinSteamBoilerTimer)));
    }
  }
  // Kin+Spirit wisp
  if (fam == 'kin' && el == 'Spirit') {
    out.add(('Wisp kills', '${live.kinSpiritWispKills}'));
  }
  // Kin+Mud ship enchant
  if (fam == 'kin' && el == 'Mud' && live.kinMudShipEnchantTimer > 0) {
    out.add(('Mud trail', timer(live.kinMudShipEnchantTimer)));
  }
  // Kin+Fire passive (always shown when alive)
  if (fam == 'kin' && el == 'Fire') {
    out.add((
      'Phoenix guard',
      live.kinFireOrbitalFlameActive ? 'FLAME (permanent)' : 'ARMED',
    ));
  }
  // Kin+Dark cloak
  if (fam == 'kin' && el == 'Dark' && live.kinDarkCloakTimer > 0) {
    out.add(('Cloak', timer(live.kinDarkCloakTimer)));
  }
  // Kin+Blood pact
  if (fam == 'kin' && el == 'Blood' && live.kinBloodPactTimer > 0) {
    out.add(('Blood pact', timer(live.kinBloodPactTimer)));
  }
  // Kin+Lava plate
  if (fam == 'kin' && el == 'Lava' && live.kinLavaPlateTimer > 0) {
    out.add(('Molten plate', timer(live.kinLavaPlateTimer)));
  }
  // Kin+Ice charge
  if (fam == 'kin' && el == 'Ice' && live.kinIceChargeTimer > 0) {
    out.add(('Frost charge', timer(live.kinIceChargeTimer)));
  }
  // Kin+Lightning charge
  if (fam == 'kin' && el == 'Lightning' && live.kinLightningChargeTimer > 0) {
    out.add(('Tesla charge', timer(live.kinLightningChargeTimer)));
  }
  return out;
}

/// Generic key/value readout panel for the pause card's live state.
class _PauseLiveStatePanel extends StatelessWidget {
  final List<(String, String)> entries;
  const _PauseLiveStatePanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACTIVE STATE',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _C.amberBright,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final entry in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${entry.$1}: ',
                    style: const TextStyle(
                      color: _C.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    entry.$2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Mask+Plant pause-menu vine readout: feeds/100 + tendril count
/// header, plus a thin progress bar to show growth toward max.
class _PauseVineReadout extends StatelessWidget {
  final int feeds;
  const _PauseVineReadout({required this.feeds});

  @override
  Widget build(BuildContext context) {
    const maxFeeds = 100;
    final clamped = feeds.clamp(0, maxFeeds);
    final tendrils = (1 + (clamped ~/ 10)).clamp(1, 10);
    final progress = clamped / maxFeeds;
    const vineColor = Color(0xFF6FCB6F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'VINE GROWTH',
              style: TextStyle(
                fontFamily: 'monospace',
                color: vineColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              '$clamped/$maxFeeds  ·  $tendrils tendril${tendrils == 1 ? '' : 's'}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 5,
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0).toDouble(),
            child: const ColoredBox(color: vineColor),
          ),
        ),
      ],
    );
  }
}

class _PausePowerUpChipContent extends StatelessWidget {
  final String name;
  final Color tint;
  final int level;
  final int maxStacks;
  final bool showLevel;
  final String? badgeLabel;

  const _PausePowerUpChipContent({
    required this.name,
    required this.tint,
    required this.level,
    required this.maxStacks,
    required this.showLevel,
    this.badgeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final clampedLevel = level.clamp(0, maxStacks);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: tint,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badgeLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                color: tint.withValues(alpha: 0.16),
                child: Text(
                  badgeLabel!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: tint,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (showLevel) ...[
          const SizedBox(height: 5),
          _PausePowerUpLevelPips(
            level: clampedLevel,
            maxStacks: maxStacks,
            tint: tint,
          ),
        ],
      ],
    );
  }
}

class _PausePowerUpLevelPips extends StatelessWidget {
  final int level;
  final int maxStacks;
  final Color tint;

  const _PausePowerUpLevelPips({
    required this.level,
    required this.maxStacks,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxStacks, (index) {
        final filled = index < level;
        return Container(
          width: 12,
          height: 4,
          margin: EdgeInsets.only(right: index == maxStacks - 1 ? 0 : 3),
          color: filled ? tint : tint.withValues(alpha: 0.18),
        );
      }),
    );
  }
}

String _familyFocusBlurb(String family) => switch (family.toLowerCase()) {
  'let' => 'Highest-HP enemies — softens up the toughest targets.',
  'pip' => 'Lowest-HP enemies — finishes off the weakened.',
  'horn' => 'Enemies closest to the orb — guards the core.',
  'wing' => 'Enemies furthest from the orb — picks off the outer ring.',
  _ => 'Nearest threat.',
};

String _familyPositionBlurb(String family) => switch (family.toLowerCase()) {
  'let' || 'horn' || 'kin' => 'Inner ring — patrols close to the orb.',
  'mane' || 'mask' => 'Mid ring — patrols the middle of the arena.',
  'wing' => 'Outer ring — patrols along the arena rim.',
  'pip' || 'mystic' => 'Roaming — no fixed zone, goes wherever needed.',
  _ => 'Roaming.',
};

class _InfoBlock extends StatelessWidget {
  final String label;
  final String? value;
  final String text;

  const _InfoBlock({required this.label, this.value, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.teal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 2),
          if (value != null)
            Text(
              value!,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (value != null) const SizedBox(height: 2),
          _PauseAbilityDescriptionText(text: text),
        ],
      ),
    );
  }
}

class _PauseAbilityDescriptionText extends StatelessWidget {
  final String text;

  const _PauseAbilityDescriptionText({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = cosmicAbilityDescriptionLines(text);
    if (lines.length == 1 && lines.first.label.isEmpty) {
      return Text(
        lines.first.body,
        style: const TextStyle(
          color: _C.textSecondary,
          fontSize: 12,
          height: 1.35,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                constraints: const BoxConstraints(minWidth: 58),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                color: _C.teal.withValues(alpha: 0.12),
                child: Text(
                  lines[i].label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _C.teal,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lines[i].body,
                  style: const TextStyle(
                    color: _C.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  final Color tint;

  const _StatLine({
    required this.label,
    required this.value,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _C.textSecondary, fontSize: 13),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'monospace',
              color: tint,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniReadout extends StatelessWidget {
  final String label;
  final String value;

  const _MiniReadout({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          TextSpan(
            text: value,
            style: hudMono(
              12,
              HudInk.ink,
              weight: FontWeight.w900,
              spacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// A perk chip's fill: the ink with a breath of the perk's color in it.
Color _chipWash(Color tint) =>
    Color.alphaBlend(tint.withValues(alpha: 0.1), _C.bg1);

Color _rarityColor(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => _C.accent,
  PowerUpRarity.uncommon => _C.teal,
  PowerUpRarity.rare => const Color(0xFFF97316),
  PowerUpRarity.legendary => const Color(0xFFFFD166),
};

String _rarityLabel(PowerUpRarity rarity) => switch (rarity) {
  PowerUpRarity.common => 'Common',
  PowerUpRarity.uncommon => 'Uncommon',
  PowerUpRarity.rare => 'Rare',
  PowerUpRarity.legendary => 'Legendary',
};
