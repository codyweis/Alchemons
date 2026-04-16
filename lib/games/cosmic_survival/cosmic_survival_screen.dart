// lib/games/cosmic_survival/cosmic_survival_screen.dart
//
// COSMIC SURVIVAL SCREEN
// Flutter wrapper around CosmicSurvivalGame. Handles intro dialog,
// team selection (5 slots), HUD overlay, power-up selection, game over.

import 'dart:async';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_balance.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/survival/survival_base_command_screen.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/providers/audio_provider.dart';
import 'package:alchemons/screens/cosmic/widgets/virtual_joystick.dart';
import 'package:alchemons/screens/party_picker/party_picker.dart';
import 'package:alchemons/screens/scenes/landscape_dialog.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (matching survival aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080A0E);
  static const bg1 = Color(0xFF0E1117);
  static const bg2 = Color(0xFF141820);
  static const bg3 = Color(0xFF1C2230);
  static const bg = bg0;
  static const panelBg = bg2;
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberGlow = Color(0xFFFFB020);
  static const amberDim = Color(0xFF92400E);
  static const accent = amber;
  static const teal = Color(0xFF0EA5E9);
  static const textPrimary = Color(0xFFE8DCC8);
  static const textSecondary = Color(0xFF8A7B6A);
  static const textMuted = Color(0xFF4A3F35);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF4CAF50);
  static const borderDim = Color(0xFF252D3A);
  static const borderAccent = Color(0xFF6B4C20);
}

class _T {
  static const TextStyle heading = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 2.0,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.6,
  );

  static const TextStyle body = TextStyle(
    color: _C.textSecondary,
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
  );
}

class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accentColor;
  final bool highlight;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.accentColor = _C.accent,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? accentColor.withValues(alpha: 0.6) : _C.borderDim,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.12),
                  blurRadius: 18,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  left: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  right: BorderSide(
                    color: accentColor.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

class _HudPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HudPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.bg1.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              color: _C.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final bool secondary;

  const _ForgeButton({
    required this.label,
    required this.icon,
    this.onTap,
    this.loading = false,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null || loading;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: secondary ? 42 : 52,
        decoration: BoxDecoration(
          color: secondary
              ? Colors.transparent
              : (isDisabled ? _C.bg3 : _C.amber),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: secondary
                ? _C.borderAccent.withValues(alpha: 0.6)
                : (isDisabled ? _C.borderDim : _C.amberGlow),
          ),
          boxShadow: (!secondary && !isDisabled)
              ? [
                  BoxShadow(
                    color: _C.amber.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: secondary ? _C.textSecondary : _C.bg0,
                ),
              )
            else
              Icon(
                icon,
                size: secondary ? 16 : 18,
                color: secondary ? _C.textSecondary : _C.bg0,
              ),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: secondary ? 11 : 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8,
                color: secondary
                    ? _C.textSecondary
                    : (isDisabled ? _C.textMuted : _C.bg0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN STATE
// ─────────────────────────────────────────────────────────────────────────────

enum _Phase { intro, teamPicker, playing, gameOver }

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

// ─────────────────────────────────────────────────────────────────────────────
// COSMIC SURVIVAL SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CosmicSurvivalScreen extends StatefulWidget {
  const CosmicSurvivalScreen({super.key});

  @override
  State<CosmicSurvivalScreen> createState() => _CosmicSurvivalScreenState();
}

class _CosmicSurvivalScreenState extends State<CosmicSurvivalScreen> {
  _Phase _phase = _Phase.intro;
  CosmicSurvivalGame? _game;
  List<CosmicPartyMember>? _party;
  Timer? _hudTimer;
  final ValueNotifier<int> _liveUiTick = ValueNotifier<int>(0);
  late final PageController _familyPageController;
  double _familyPage = 0;
  final Set<String> _expandedFamilyCards = <String>{};
  final Set<String> _expandedProtocols = <String>{};
  SurvivalHighScoreData? _highScore;
  bool _showPauseMenu = false;
  bool _showJoystick = true;
  bool _largeJoystick = false;

  // Power-up selection state
  List<OfferedPowerUpChoice> _powerUpChoices = [];

  // Boss announcement
  String? _bossAnnouncement;
  Timer? _bossAnnouncementTimer;
  String? _waveAnnouncementTitle;
  String? _waveAnnouncementSubtitle;
  Timer? _waveAnnouncementTimer;
  int _lastAnnouncedWave = 0;
  final List<_WaveAnnouncementData> _pendingWaveAnnouncements =
      <_WaveAnnouncementData>[];

  // Game over reward info
  String _lootRewardLabel = '';
  String _currencyRewardLabel = '';
  int _finalWave = 0;
  int _finalKills = 0;
  int _finalScore = 0;
  String _finalTime = '00:00';
  bool _resolvingGameOver = false;

  static const List<_SurvivalTestSlotSpec> _testTeamA = [
    _SurvivalTestSlotSpec(family: 'Horn', element: 'Earth'),
    _SurvivalTestSlotSpec(family: 'Kin', element: 'Light'),
    _SurvivalTestSlotSpec(family: 'Mask', element: 'Mud'),
    _SurvivalTestSlotSpec(family: 'Mystic', element: 'Blood'),
    _SurvivalTestSlotSpec(family: 'Wing', element: 'Spirit'),
  ];

  static const List<_SurvivalTestSlotSpec> _testTeamB = [
    _SurvivalTestSlotSpec(family: 'Let', element: 'Dark'),
    _SurvivalTestSlotSpec(family: 'Pip', element: 'Lightning'),
    _SurvivalTestSlotSpec(family: 'Mane', element: 'Poison'),
    _SurvivalTestSlotSpec(family: 'Kin', element: 'Crystal'),
    _SurvivalTestSlotSpec(family: 'Horn', element: 'Lava'),
  ];

  static const List<_SurvivalTestSlotSpec> _testTeamLets = [
    _SurvivalTestSlotSpec(
      family: 'Let',
      element: 'Fire',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Let',
      element: 'Lava',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Let',
      element: 'Poison',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Let',
      element: 'Plant',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Let',
      element: 'Dark',
      level: 10,
      statValue: 3.5,
    ),
  ];

  static const List<_SurvivalTestSlotSpec> _testTeamPips = [
    _SurvivalTestSlotSpec(
      family: 'Pip',
      element: 'Fire',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Pip',
      element: 'Lightning',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Pip',
      element: 'Crystal',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Pip',
      element: 'Poison',
      level: 10,
      statValue: 3.5,
    ),
    _SurvivalTestSlotSpec(
      family: 'Pip',
      element: 'Air',
      level: 10,
      statValue: 3.5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _familyPageController = PageController(viewportFraction: 0.82);
    _familyPageController.addListener(() {
      if (!mounted) return;
      setState(() => _familyPage = _familyPageController.page ?? 0);
    });
    unawaited(_loadControlPreferences());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadHighScore());
      unawaited(_showIntro());
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    _liveUiTick.dispose();
    _familyPageController.dispose();
    super.dispose();
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

  Future<void> _showIntro() async {
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
        icon: Icons.help_outline_rounded,
        typewriter: true,
        message:
            'Something here refuses to finish. The field closes, the wave breaks, the silence returns, and then the same war leans forward again as if no ending was ever allowed to remain.\n\n'
            'Is this my creation? Or has this constant alchemical war always existed somewhere beneath memory, waiting for a witness strong enough to mistake it for a test?',
      );
      await db.settingsDao.setSurvivalMenuStoryIntroSeen();
      await db.settingsDao.setCosmicSurvivalIntroSeen();
    }

    if (mounted) setState(() => _phase = _Phase.teamPicker);
  }

  Future<void> _loadHighScore() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final hs = await db.getSurvivalHighScore();
    if (mounted) setState(() => _highScore = hs);
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
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 360),
          decoration: BoxDecoration(
            color: _C.bg1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _C.borderAccent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
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
                      'This is your deepest recorded survival clear across the mode. Tap back in and see if the current Cosmic Survival balance lets your bred teams push it higher.',
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
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Team Picker ─────────────────────────────────────────

  Future<void> _pickTeam() async {
    final result = await Navigator.of(context).push<List<PartyMember>>(
      MaterialPageRoute(
        builder: (_) => const PartyPickerScreen(
          showDeployConfirm: false,
          enforceUniqueSpecies: false,
          maxSelections: 5,
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    final instanceIds = result.map((m) => m.instanceId).toList();
    final party = await _buildParty(instanceIds);
    if (party == null || party.isEmpty) return;

    // Limit to 5 members
    final trimmed = party.length > 5 ? party.sublist(0, 5) : party;

    setState(() {
      _party = trimmed;
    });

    _startGame(trimmed);
  }

  Future<List<CosmicPartyMember>?> _buildParty(List<String> instanceIds) async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final members = <CosmicPartyMember>[];

    for (var i = 0; i < instanceIds.length && i < 5; i++) {
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
          statSpeed: inst.statSpeed.toDouble(),
          statIntelligence: inst.statIntelligence.toDouble(),
          statStrength: inst.statStrength.toDouble(),
          statBeauty: inst.statBeauty.toDouble(),
          slotIndex: i,
          staminaBars: inst.staminaMax, // full stamina for survival
          staminaMax: inst.staminaMax,
          spriteSheet: sheet,
          spriteVisuals: visuals,
        ),
      );
    }

    return members;
  }

  List<CosmicPartyMember>? _buildTestParty(
    List<_SurvivalTestSlotSpec> specs, {
    required String teamKey,
  }) {
    final catalog = context.read<CreatureCatalog>();
    final members = <CosmicPartyMember>[];

    for (var i = 0; i < specs.length && i < 5; i++) {
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
    final party = _buildTestParty(specs, teamKey: teamKey);
    if (party == null || party.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.bg2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.danger.withValues(alpha: 0.7)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: _C.danger),
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

    setState(() {
      _party = party;
    });
    _startGame(party);
  }

  // ── Start Game ──────────────────────────────────────────

  void _startGame(List<CosmicPartyMember> party) {
    final upgradeSvc = context.read<SurvivalUpgradeService>();

    final game = CosmicSurvivalGame(
      party: party,
      onGameOver: _handleGameOver,
      onWaveIntermission: _handleWaveIntermission,
      onBossSpawn: _handleBossSpawn,
      upgradeState: upgradeSvc.state,
    );

    setState(() {
      _game = game;
      _phase = _Phase.playing;
      _lootRewardLabel = '';
      _currencyRewardLabel = '';
      _finalWave = 0;
      _finalKills = 0;
      _finalScore = 0;
      _finalTime = '00:00';
      _resolvingGameOver = false;
    });

    game.startGame();
    _lastAnnouncedWave = game.spawner.currentWave;
    _showWaveAnnouncementForWave(game.spawner.currentWave);

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

    unawaited(context.read<AudioController>().playSurvivalMusic());
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
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _powerUpChoices = choices);
    });
  }

  void _selectPowerUp(PowerUpDef def, {int? targetSlot, String? targetName}) {
    _game?.applyPowerUp(def, targetSlot: targetSlot, targetName: targetName);
    setState(() => _powerUpChoices = []);
  }

  void _handleBossSpawn(SurvivalBoss boss) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _bossAnnouncement = boss.template.name);
      _bossAnnouncementTimer?.cancel();
      _bossAnnouncementTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _bossAnnouncement = null);
      });
    });
  }

  void _showWaveAnnouncementForWave(int wave) {
    if (!mounted || wave <= 0) return;
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
    _hudTimer?.cancel();
    _game?.gamePaused = true;

    final wave = _game?.spawner.currentWave ?? 0;
    setState(() {
      _finalWave = wave;
      _finalKills = _game?.stats.kills ?? 0;
      _finalScore = _game?.stats.score ?? 0;
      _finalTime = _game?.stats.formattedTime ?? '00:00';
      _resolvingGameOver = true;
    });

    unawaited(_completeGameOverSequence(wave));
  }

  Future<void> _completeGameOverSequence(int wave) async {
    try {
      await _saveHighScore();
      await _rollAndShowRewards(wave);
    } finally {
      if (mounted) {
        setState(() {
          _phase = _Phase.gameOver;
          _resolvingGameOver = false;
        });
      }
    }
  }

  Future<void> _rollAndShowRewards(int wave) async {
    final db = context.read<AlchemonsDatabase>();
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
          return LootOpeningEntry(
            icon: def?.icon ?? Icons.inventory_2_rounded,
            name: def?.name ?? entry.key,
            label: 'x${entry.value}',
            color: _C.accent,
          );
        }),
      );
      _lootRewardLabel = openedRewards
          .map((entry) {
            final def = registry[entry.key];
            return '${def?.name ?? entry.key} x${entry.value}';
          })
          .join(', ');

      final powerupRewards = rollCosmicSurvivalPowerupRewards(wave, rng);
      if (powerupRewards.isNotEmpty) {
        for (final reward in powerupRewards) {
          await db.inventoryDao.addItemQty(reward.key, reward.value);
        }
        popupEntries.addAll(
          powerupRewards.map((entry) {
            final type = alchemicalPowerupTypeFromInventoryKey(entry.key);
            return LootOpeningEntry(
              icon: type?.icon ?? Icons.blur_on_rounded,
              name: type?.name ?? entry.key,
              label: 'x${entry.value}',
              color: type?.color ?? _C.accent,
            );
          }),
        );
        final powerupLabel = powerupRewards
            .map((entry) {
              final type = alchemicalPowerupTypeFromInventoryKey(entry.key);
              return '${type?.name ?? entry.key} x${entry.value}';
            })
            .join(', ');
        _lootRewardLabel = _lootRewardLabel.isEmpty
            ? powerupLabel
            : '$_lootRewardLabel, $powerupLabel';
      }

      final currencyRewards = LootBoxConfig.rollSurvivalBonusCurrency(
        wave,
        rng,
      );
      final silver = currencyRewards['silver'] ?? 0;
      final gold = currencyRewards['gold'] ?? 0;
      if (silver > 0) {
        await db.currencyDao.addSilver(silver);
        popupEntries.add(
          LootOpeningEntry(
            icon: Icons.monetization_on_rounded,
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
            icon: Icons.stars_rounded,
            name: 'Gold',
            label: '+$gold',
            color: _C.accent,
          ),
        );
      }
      _currencyRewardLabel =
          '+$silver silver${gold > 0 ? ', +$gold gold' : ''}';
    } else {
      _lootRewardLabel = 'No loot cache recovered';
      final pitySilver = 50 + rng.nextInt(51);
      await db.currencyDao.addSilver(pitySilver);
      popupEntries.add(
        LootOpeningEntry(
          icon: Icons.monetization_on_rounded,
          name: 'Silver',
          label: '+$pitySilver',
          color: const Color(0xFFB0BEC5),
        ),
      );
      _currencyRewardLabel = '+$pitySilver silver';
    }

    if (!mounted) return;
    if (popupEntries.isNotEmpty) {
      await showLootOpeningDialog(context: context, entries: popupEntries);
    }
    if (mounted) setState(() {});
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
  }

  void _replay() {
    _game = null;
    _hudTimer?.cancel();
    _showPauseMenu = false;
    if (_party != null) {
      _startGame(_party!);
    } else {
      setState(() => _phase = _Phase.teamPicker);
    }
  }

  void _exit() {
    unawaited(context.read<AudioController>().playHomeMusic());
    Navigator.of(context).pop();
  }

  void _togglePauseMenu() {
    final game = _game;
    if (game == null || _powerUpChoices.isNotEmpty || game.isGameOver) return;
    setState(() {
      _showPauseMenu = !_showPauseMenu;
      game.gamePaused = _showPauseMenu;
    });
  }

  void _closePauseMenu() {
    final game = _game;
    if (game == null) return;
    setState(() {
      _showPauseMenu = false;
      game.gamePaused = false;
    });
  }

  Future<bool> _confirmQuitRun() async {
    final shouldQuit = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF121720),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _C.accent.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'QUIT RUN?',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.6,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your current cosmic survival run will end and you will return to the previous screen.',
                style: TextStyle(
                  color: _C.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _PauseActionButton(
                    label: 'STAY',
                    icon: Icons.play_arrow_rounded,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  _PauseActionButton(
                    label: 'QUIT',
                    icon: Icons.exit_to_app_rounded,
                    onTap: () => Navigator.of(context).pop(true),
                    fillColor: _C.danger,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return shouldQuit ?? false;
  }

  Future<void> _quitRunFromPause() async {
    final game = _game;
    if (game == null) return;
    if (await _confirmQuitRun()) {
      if (!mounted) return;
      _showPauseMenu = false;
      game.gamePaused = false;
      _exit();
    }
  }

  Future<void> _handleBackPressed() async {
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
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF121720),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _rarityColor(def.rarity).withValues(alpha: 0.55),
          ),
        ),
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
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        unawaited(_handleBackPressed());
      },
      child: Scaffold(
        backgroundColor: _C.bg,
        body: switch (_phase) {
          _Phase.intro => _buildLoading(),
          _Phase.teamPicker => _buildTeamPicker(),
          _Phase.playing => _buildGameScreen(),
          _Phase.gameOver => _buildGameOver(),
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(child: CircularProgressIndicator(color: _C.accent));
  }

  // ── Team Picker Phase ──────────────────────────────────

  Widget _buildTeamPicker() {
    return _buildFormationPrompt();
  }

  Widget _buildFormationPrompt() {
    return Scaffold(
      backgroundColor: _C.bg0,
      body: SafeArea(
        child: Column(
          children: [
            _buildMenuHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    _buildSpeciesRoster(),
                    const SizedBox(height: 24),
                    _buildTacticsGrid(),
                    const SizedBox(height: 28),
                    _ForgeButton(
                      label: 'Deploy Formation',
                      icon: Icons.groups_rounded,
                      loading: false,
                      onTap: _pickTeam,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Base Command',
                      icon: Icons.settings_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SurvivalBaseCommandScreen(
                              hideAbilities: true,
                            ),
                          ),
                        );
                      },
                      secondary: true,
                    ),
                    const SizedBox(height: 18),
                    const _EtchedDivider(label: 'COMMAND'),
                    const SizedBox(height: 12),
                    _ForgeButton(
                      label: 'Test Squad A',
                      icon: Icons.science_outlined,
                      onTap: () => _startTestTeam(_testTeamA, 'a'),
                      secondary: true,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Test Squad B',
                      icon: Icons.auto_awesome_rounded,
                      onTap: () => _startTestTeam(_testTeamB, 'b'),
                      secondary: true,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Test Squad Lets',
                      icon: Icons.public_rounded,
                      onTap: () => _startTestTeam(_testTeamLets, 'lets'),
                      secondary: true,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Test Squad Pips',
                      icon: Icons.bolt_rounded,
                      onTap: () => _startTestTeam(_testTeamPips, 'pips'),
                      secondary: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exit,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _C.bg2,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: _C.borderDim),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: _C.textSecondary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    _HeaderPulseDot(),
                    SizedBox(width: 8),
                    Text('SURVIVAL MODE', style: _T.heading),
                  ],
                ),
                SizedBox(height: 2),
                Text('ENDLESS WAVE DEFENSE', style: _T.label),
              ],
            ),
          ),
          Row(
            children: [
              _PlateBox(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                accentColor: _C.danger,
                highlight: true,
                child: const Column(
                  children: [
                    Text(
                      '∞',
                      style: TextStyle(
                        color: _C.danger,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text('WAVES', style: _T.label),
                  ],
                ),
              ),
              if (_highScore != null && _highScore!.bestWave > 0) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _showHighScoreDetails,
                  child: _PlateBox(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    accentColor: _C.amberBright,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: _C.amberBright,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'W${_highScore!.bestWave}',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: _C.amberBright,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _formatHighScoreNumber(_highScore!.bestScore),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _C.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text('BEST', style: _T.label),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesRoster() {
    final currentIndex = _familyPage.round().clamp(
      0,
      _cosmicFamilyInfos.length - 1,
    );
    final expandedActive = _expandedFamilyCards.contains(
      _cosmicFamilyInfos[currentIndex].id,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtchedDivider(label: 'SPECIES ROSTER'),
        const SizedBox(height: 14),
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: expandedActive ? 260 : 200,
          child: PageView.builder(
            controller: _familyPageController,
            itemCount: _cosmicFamilyInfos.length,
            itemBuilder: (context, index) {
              final info = _cosmicFamilyInfos[index];
              final distance = (index - _familyPage).abs().clamp(0.0, 1.0);
              final scale = 1.0 - (0.06 * distance);
              final opacity = 1.0 - (0.5 * distance);
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _buildSpeciesCard(info),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_cosmicFamilyInfos.length, (i) {
            final active = (i - _familyPage).abs() < 0.5;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 3,
              width: active ? 18 : 6,
              decoration: BoxDecoration(
                color: active ? _C.amber : _C.borderAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildSpeciesCard(_FamilyInfo info) {
    final expanded = _expandedFamilyCards.contains(info.id);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: expanded ? info.color.withValues(alpha: 0.55) : _C.borderDim,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedFamilyCards.remove(info.id);
              } else {
                _expandedFamilyCards.add(info.id);
              }
            });
          },
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            info.color.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                          radius: 0.8,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          info.color.withValues(alpha: 0.9),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(info.assetPath, fit: BoxFit.contain),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(
                            color: info.color.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          info.role.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: info.color,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 140,
                top: 12,
                bottom: 12,
                child: Container(width: 1, color: _C.borderDim),
              ),
              Positioned(
                left: 152,
                right: 12,
                top: 0,
                bottom: 0,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    info.name.toUpperCase(),
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      color: _C.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                ),
                                Icon(
                                  expanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: _C.textSecondary,
                                  size: 16,
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 140),
                              firstChild: Text(
                                info.description,
                                style: _T.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondChild: Text(
                                info.description,
                                style: _T.body,
                              ),
                              crossFadeState: expanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            size: 11,
                            color: _C.amberBright,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: AnimatedCrossFade(
                              duration: const Duration(milliseconds: 140),
                              firstChild: Text(
                                info.bestPowerups,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: _C.amberDim,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              secondChild: Text(
                                info.bestPowerups,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: _C.amberDim,
                                  fontSize: 9,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              crossFadeState: expanded
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTacticsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtchedDivider(label: 'FIELD PROTOCOLS'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildTacticTile(
                Icons.groups_rounded,
                'FUSING',
                'High-stat alchemons will spike earlier and convert upgrades harder.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                Icons.auto_awesome_rounded,
                'DRAFTING',
                'Keystones and weighted offers amplify each family role instead of replacing it.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTacticTile(
                Icons.waves_rounded,
                'MUTATORS',
                'Wave rules evolve through elites, mutators, and faster late-run tempo spikes.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                Icons.shield_outlined,
                'ORB DEFENSE',
                'Protect the orb, absorb pressure, and stretch your build as far as it can go.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTacticTile(IconData icon, String title, String desc) {
    final expanded = _expandedProtocols.contains(title);
    return Container(
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: expanded ? _C.amber.withValues(alpha: 0.7) : _C.borderDim,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(3),
        onTap: () {
          setState(() {
            if (expanded) {
              _expandedProtocols.remove(title);
            } else {
              _expandedProtocols.add(title);
            }
          });
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: _C.amber, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: _C.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _C.textSecondary,
                    size: 16,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 140),
                firstChild: Text(
                  desc,
                  style: _T.body.copyWith(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(desc, style: _T.body.copyWith(fontSize: 11)),
                crossFadeState: expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game Phase ─────────────────────────────────────────

  Widget _buildGameScreen() {
    final game = _game;
    if (game == null) return _buildLoading();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Flame game
        GameWidget(
          game: game,
          backgroundBuilder: (_) => Container(color: Colors.transparent),
        ),

        _buildLivePlayOverlay(game),

        // Joystick (bottom left)
        if (game.isLoaded && _showJoystick)
          Positioned(
            bottom: 20,
            left: 12,
            child: SafeArea(
              child: VirtualJoystick(
                sizeMultiplier: _largeJoystick ? 1.35 : 1.0,
                onDirectionChanged: (dir) {
                  game.setJoystickInput(dir ?? Offset.zero);
                },
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
        if (_bossAnnouncement != null)
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E1117).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.danger.withValues(alpha: 0.6)),
                ),
                child: Text(
                  'BOSS: ${_bossAnnouncement!}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: _C.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ),
        if (_waveAnnouncementTitle != null)
          Positioned(
            top: 118,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _waveAnnouncementTitle == null ? 0 : 1,
                  duration: const Duration(milliseconds: 420),
                  curve: Curves.easeOut,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xCC090B12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _C.teal.withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _C.teal.withValues(alpha: 0.10),
                          blurRadius: 26,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              const Color(0xFFF3EBD0),
                              _C.teal.withValues(alpha: 0.95),
                              _C.accent.withValues(alpha: 0.92),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            _waveAnnouncementTitle!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3.2,
                            ),
                          ),
                        ),
                        if (_waveAnnouncementSubtitle != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _waveAnnouncementSubtitle!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _C.textSecondary.withValues(alpha: 0.92),
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
      ],
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
              onTap: isReady ? game.triggerDetonation : null,
              child: SizedBox(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: isReady ? 1.0 : charge,
                        strokeWidth: 4,
                        backgroundColor: const Color(
                          0xFF25160F,
                        ).withValues(alpha: 0.9),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isReady
                              ? const Color(0xFFFFA15C)
                              : const Color(0xFFFF6B35),
                        ),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 260),
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isReady
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF2A1A10),
                        border: Border.all(
                          color: isReady
                              ? const Color(0xFFFFB27E)
                              : const Color(0xFF4A3020),
                          width: 2,
                        ),
                        boxShadow: isReady
                            ? [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withValues(alpha: 0.60),
                                  blurRadius: 22,
                                  spreadRadius: 5,
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withValues(alpha: 0.12 + charge * 0.18),
                                  blurRadius: 14,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isReady ? 20 : 14 + charge * 6,
                          height: isReady ? 20 : 14 + charge * 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(
                                  alpha: isReady ? 0.95 : 0.55,
                                ),
                                const Color(0xFFFFC38D).withValues(alpha: 0.92),
                                const Color(0xFFFF6B35).withValues(alpha: 0.85),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFA15C).withValues(
                                  alpha: isReady ? 0.85 : 0.22 + charge * 0.22,
                                ),
                                blurRadius: isReady ? 16 : 8,
                                spreadRadius: isReady ? 3 : 0,
                              ),
                            ],
                          ),
                        ),
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

  Widget _buildGhostShipBanner(CosmicSurvivalGame game) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1117).withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.teal.withValues(alpha: 0.45)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'SHIP DESTROYED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.teal,
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
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: _C.textPrimary,
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
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Timer
              _HudPill(
                icon: Icons.timer_outlined,
                label: game.stats.formattedTime,
                color: _C.textSecondary,
              ),
              const Spacer(),
              _HudIconButton(
                icon: _showPauseMenu
                    ? Icons.play_arrow_rounded
                    : Icons.pause_rounded,
                color: _C.accent,
                onTap: _togglePauseMenu,
              ),
              const SizedBox(width: 8),
              // Ship HP
              if (game.isLoaded)
                _HudBar(
                  label: game.ship.isDead ? 'GHOST' : 'SHIP',
                  percent: game.ship.isDead ? 1.0 : game.ship.hpPercent,
                  color: game.ship.isDead
                      ? const Color(0xFF9FE8FF)
                      : const Color(0xFF00E5FF),
                  width: 70,
                ),
              if (game.isLoaded) const SizedBox(width: 8),
              // Orb HP
              _HudBar(
                label: 'ORB',
                percent: game.isLoaded ? game.orb.hpPercent : 1.0,
                color: _C.accent,
                width: 70,
              ),
            ],
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
      onTap: _closePauseMenu,
      child: Container(
        color: Colors.black.withValues(alpha: 0.72),
        child: SafeArea(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              height: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121720),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _C.accent.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: _C.accent.withValues(alpha: 0.16),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _C.accent.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pause_circle_outline_rounded,
                          color: _C.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'PAUSED',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _C.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        _PauseActionButton(
                          label: 'RESUME',
                          icon: Icons.play_arrow_rounded,
                          onTap: _closePauseMenu,
                        ),
                        const SizedBox(width: 8),
                        _PauseActionButton(
                          label: 'QUIT',
                          icon: Icons.exit_to_app_rounded,
                          onTap: _quitRunFromPause,
                          fillColor: _C.danger,
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
                          _PauseStatRow(
                            children: [
                              _PauseStatChip(
                                label: 'Wave',
                                value: '${game.spawner.currentWave}',
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
                          const SizedBox(height: 8),
                          _PauseStatRow(
                            children: [
                              _PauseStatChip(
                                label: 'Time',
                                value: game.stats.formattedTime,
                              ),
                              _PauseStatChip(
                                label: 'Ship',
                                value: game.ship.isDead
                                    ? 'Down'
                                    : '${(game.ship.hpPercent * 100).round()}%',
                              ),
                              _PauseStatChip(
                                label: 'Orb',
                                value: '${(game.orb.hpPercent * 100).round()}%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _PauseStatRow(
                            children: [
                              _PauseStatChip(
                                label: 'Alchemy',
                                value:
                                    '${game.alchemicalMeter.round()}/${game.alchemicalMeterMax.round()}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (keystoneHistory.isNotEmpty) ...[
                            const Text(
                              'KEYSTONE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _C.teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _C.panelBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _C.teal.withValues(alpha: 0.18),
                                ),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: keystoneHistory.map((entry) {
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => _showPowerUpInfo(
                                      entry.def,
                                      game.powerUps,
                                      slotIndex: entry.targetSlot,
                                      targetName: entry.targetName,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: const Color(0xFF0F141B),
                                        border: Border.all(
                                          color: _C.teal.withValues(
                                            alpha: 0.45,
                                          ),
                                        ),
                                      ),
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
                            ),
                            const SizedBox(height: 14),
                          ],
                          const Text(
                            'POWERUPS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _C.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Tap a perk to see what it does.',
                            style: TextStyle(
                              color: _C.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _C.panelBg,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _C.textSecondary.withValues(alpha: 0.18),
                              ),
                            ),
                            child: globalHistory.isEmpty
                                ? const Text(
                                    'No global upgrades taken yet.',
                                    style: TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 11,
                                    ),
                                  )
                                : standardGlobalHistory.isEmpty
                                ? const Text(
                                    'No standard global upgrades yet.',
                                    style: TextStyle(
                                      color: _C.textSecondary,
                                      fontSize: 11,
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
                                        borderRadius: BorderRadius.circular(6),
                                        onTap: () => _showPowerUpInfo(
                                          entry.def,
                                          game.powerUps,
                                          slotIndex: entry.targetSlot,
                                          targetName: entry.targetName,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            color: const Color(0xFF0F141B),
                                            border: Border.all(
                                              color: _rarityColor(
                                                entry.def.rarity,
                                              ).withValues(alpha: 0.45),
                                            ),
                                          ),
                                          child: _PausePowerUpChipContent(
                                            name: entry.def.name,
                                            tint: _rarityColor(
                                              entry.def.rarity,
                                            ),
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
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'ALCHEMON STATS',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: _C.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
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
                                attackMultiplier: game.powerUps
                                    .companionAttackMultiplier(index),
                                defenseMultiplier: game.powerUps
                                    .companionDefenseMultiplier(index),
                                speedMultiplier: game.powerUps
                                    .companionSpeedMultiplier(index),
                                onPowerUpTap: (entry) => _showPowerUpInfo(
                                  entry.def,
                                  game.powerUps,
                                  slotIndex: entry.targetSlot,
                                  targetName: entry.targetName,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Footer: Controls ──
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: _C.accent.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        const Text(
                          'DISABLE ANALOG',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _C.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          child: Switch.adaptive(
                            value: !_showJoystick,
                            activeThumbColor: _C.accent,
                            onChanged: (v) async {
                              final enabled = !v;
                              setState(() {
                                _showJoystick = enabled;
                                game.setJoystickInput(Offset.zero);
                              });
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool(
                                'cosmic_survival_joystick_enabled',
                                enabled,
                              );
                            },
                          ),
                        ),
                        const Text(
                          'LARGE STICK',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: _C.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(
                          height: 24,
                          child: Switch.adaptive(
                            value: _largeJoystick,
                            activeThumbColor: _C.accent,
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
    );
  }

  // ── Companion Panel ────────────────────────────────────

  Widget _buildCompanionPanel(CosmicSurvivalGame game) {
    final party = _party;
    if (party == null || party.isEmpty) return const SizedBox.shrink();

    return Positioned(
      right: 12,
      top: 100,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tether toggle
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                if (game.companionTethered) {
                  game.clearCompanionTether();
                } else {
                  game.tetherClosestCompanionToShip();
                }
                setState(() {});
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: game.companionTethered
                      ? _C.accent.withValues(alpha: 0.22)
                      : _C.panelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: game.companionTethered
                        ? _C.accent
                        : _C.textSecondary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  game.companionTethered
                      ? Icons.gps_fixed_rounded
                      : Icons.link_off,
                  color: game.companionTethered ? _C.accent : _C.textSecondary,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // 5 companion slots
            for (var i = 0; i < party.length; i++) ...[
              _buildCompanionSlot(game, party[i], i),
              if (i < party.length - 1) const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompanionSlot(
    CosmicSurvivalGame game,
    CosmicPartyMember member,
    int slotIndex,
  ) {
    final isActive = game.activeCompanions.containsKey(slotIndex);
    final comp = game.activeCompanions[slotIndex];
    final isTethered = game.tetheredCompanionSlot == slotIndex && isActive;
    final hp =
        game.companionHpFraction[slotIndex] ??
        (isActive ? (comp?.hpPercent ?? 1.0) : 1.0);
    final isDead = isActive && (comp?.isDead ?? false);
    final atMax = game.activeCompanions.length >= game.maxActiveCompanions;

    // Get special cooldown: live value if active, else cached
    final specialCooldown = isActive
        ? (comp?.specialCooldown ?? 0.0)
        : (game.companionSpecialCooldown[slotIndex] ?? 0.0);
    final showCooldown = specialCooldown > 0.05;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        if (isActive) {
          game.returnCompanion(slotIndex);
        } else if (!isDead) {
          if (atMax) {
            // Auto-recall the first non-tethered active companion to make room
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
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isDead
              ? _C.danger.withValues(alpha: 0.1)
              : isTethered
              ? _C.teal.withValues(alpha: 0.16)
              : isActive
              ? _C.accent.withValues(alpha: 0.15)
              : _C.panelBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDead
                ? _C.danger.withValues(alpha: 0.5)
                : isTethered
                ? _C.teal
                : isActive
                ? _C.accent
                : _C.textSecondary.withValues(alpha: 0.3),
            width: isActive || isTethered ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Creature image or placeholder
            Center(
              child: member.imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        member.imagePath!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(
                          member.displayName[0],
                          style: const TextStyle(
                            color: _C.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      member.displayName[0],
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            // HP bar at bottom
            if (isActive || hp < 1.0)
              Positioned(
                bottom: 2,
                left: 4,
                right: 4,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: hp.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: hp > 0.5
                            ? _C.success
                            : hp > 0.25
                            ? Colors.orange
                            : _C.danger,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            // Special cooldown timer (bottom-left)
            if (showCooldown)
              Positioned(
                bottom: -2,
                left: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFE53935).withValues(alpha: 0.8)
                          : _C.teal.withValues(alpha: 0.75),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    specialCooldown.ceil().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (isTethered)
              Positioned(
                top: -3,
                right: -3,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _C.teal,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: const Color(0xFF10151B),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.gps_fixed_rounded,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
              ),
            // Dead overlay
            if (isDead)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Center(
                  child: Icon(Icons.close, color: _C.danger, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Game Over Phase ────────────────────────────────────

  Widget _buildGameOver() {
    return LandscapeDialog(
      title: 'ORB DESTROYED',
      message: _buildGameOverStatsMessage(),
      kind: LandscapeDialogKind.danger,
      icon: Icons.bubble_chart,
      primaryLabel: 'DEPLOY AGAIN',
      onPrimary: _replay,
      secondaryLabel: 'NEW TEAM',
      onSecondary: () {
        _game = null;
        _party = null;
        setState(() => _phase = _Phase.teamPicker);
      },
    );
  }

  String _buildGameOverStatsMessage() {
    final stats = <String>[];
    stats.add('WAVE: $_finalWave');
    stats.add('KILLS: $_finalKills');
    stats.add('SCORE: $_finalScore');
    stats.add('TIME: $_finalTime');
    if (_lootRewardLabel.isNotEmpty) {
      stats.add('LOOT: $_lootRewardLabel');
    }
    if (_currencyRewardLabel.isNotEmpty) {
      stats.add('BONUS: $_currencyRewardLabel');
    }
    return stats.join('\n');
    // ─────────────────────────────────────────────────────────────────────────────
    // HUD WIDGETS
    // ─────────────────────────────────────────────────────────────────────────────
  }
}

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.08);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _FamilyInfo {
  final String id;
  final String name;
  final String role;
  final String description;
  final String bestPowerups;
  final String assetPath;
  final Color color;

  const _FamilyInfo({
    required this.id,
    required this.name,
    required this.role,
    required this.description,
    required this.bestPowerups,
    required this.assetPath,
    required this.color,
  });
}

class _WaveAnnouncementData {
  final String title;
  final String? subtitle;

  const _WaveAnnouncementData({required this.title, this.subtitle});
}

const List<_FamilyInfo> _cosmicFamilyInfos = [
  _FamilyInfo(
    id: 'Let',
    name: 'Let',
    role: 'Siege Caster',
    description:
        'Long-range meteor pressure with element-specific follow-through: lances, shards, guided finishers, orbiting blades, or persistent control fields.',
    bestPowerups: 'Spellbloom Engine, Double Cast, lane-control drafts',
    assetPath: 'assets/images/creatures/common/LET02_waterlet.png',
    color: Color(0xFF3B82F6),
  ),
  _FamilyInfo(
    id: 'Pip',
    name: 'Pip',
    role: 'Tempo Carry',
    description:
        'Fast cleanup specialists that chase leaks, rebound through packs, and turn elite Speed/Int lines into tighter wave tempo.',
    bestPowerups: 'Quicksilver Step, Chrono Surge, rebound drafts',
    assetPath: 'assets/images/creatures/uncommon/PIP06_lavapip.png',
    color: Color(0xFFEF4444),
  ),
  _FamilyInfo(
    id: 'Mane',
    name: 'Mane',
    role: 'Barrage Bruiser',
    description:
        'Sustained pressure dealers that love Speed and Strength, especially when waves start collapsing into closer-range fights.',
    bestPowerups: 'Forged Strikes, Blood Pact, tempo lanes',
    assetPath: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
    color: Color(0xFFF59E0B),
  ),
  _FamilyInfo(
    id: 'Horn',
    name: 'Horn',
    role: 'Frontline Bastion',
    description:
        'Orb defense specialists that hold the line, punish rushdown, and convert strong Strength into reliable survival value.',
    bestPowerups: 'Forgeplate, Orb Tempering, Bulwark Orders',
    assetPath: 'assets/images/creatures/rare/HOR13_poisonhorn.png',
    color: Color(0xFF10B981),
  ),
  _FamilyInfo(
    id: 'Mask',
    name: 'Mask',
    role: 'Tactical Duelist',
    description:
        'Precision utility fighters that reposition well and reward smart tempo/control drafting.',
    bestPowerups: 'Chrono Grit, Quicksilver Step, control lanes',
    assetPath: 'assets/images/creatures/rare/MSK01_firemask.png',
    color: Color(0xFF8B5CF6),
  ),
  _FamilyInfo(
    id: 'Wing',
    name: 'Wing',
    role: 'Sniper Control',
    description:
        'Long-range pressure that removes shooters and bosses from a safe distance. Great on high Intelligence and Beauty lines.',
    bestPowerups: 'Chrono Grit, Double Cast, Arc Storm answers',
    assetPath: 'assets/images/creatures/legendary/WNG03_earthwing.png',
    color: Color(0xFF06B6D4),
  ),
  _FamilyInfo(
    id: 'Kin',
    name: 'Kin',
    role: 'Support Anchor',
    description:
        'Stabilizes formations with utility, sustain, and tactical control. Premium Intelligence and Beauty show up immediately here.',
    bestPowerups: 'Regeneration Field, Shield Pulse, Spellbloom Engine',
    assetPath: 'assets/images/creatures/legendary/KIN16_lightkin.png',
    color: Color(0xFF14B8A6),
  ),
  _FamilyInfo(
    id: 'Mystic',
    name: 'Mystic',
    role: 'Spell Engine',
    description:
        'High-risk special-cast monsters that explode once keystones and control tools line up around their stat profile.',
    bestPowerups: 'Double Cast, Spellbloom Engine, special-cast lanes',
    assetPath: 'assets/images/creatures/mystic/MYS14_spiritmystic.png',
    color: Color(0xFFA855F7),
  ),
];

class _HeaderPulseDot extends StatelessWidget {
  const _HeaderPulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: _C.accent, shape: BoxShape.circle),
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _HudIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _C.panelBg.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;
  final double width;

  const _HudBar({
    required this.label,
    required this.percent,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: _C.textSecondary,
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: width,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percent.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PauseActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color fillColor;

  const _PauseActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fillColor = _C.accent,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: fillColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: fillColor.withValues(alpha: 0.65)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: fillColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: fillColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
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

class _PauseStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? tint;

  const _PauseStatChip({required this.label, required this.value, this.tint});

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? _C.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              color: _C.textSecondary,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 13,
              fontWeight: FontWeight.w800,
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
  final double attackMultiplier;
  final double defenseMultiplier;
  final double speedMultiplier;
  final ValueChanged<AppliedPowerUp> onPowerUpTap;

  const _PauseCompanionCard({
    required this.member,
    required this.companion,
    required this.appliedPowerUps,
    required this.powerUps,
    required this.attackMultiplier,
    required this.defenseMultiplier,
    required this.speedMultiplier,
    required this.onPowerUpTap,
  });

  @override
  Widget build(BuildContext context) {
    final live = companion;

    // Compute base stats for benched companions using the same formulas as the game engine
    int basePhysAtk = 0;
    int baseElemAtk = 0;
    int basePhysDef = 0;
    int baseElemDef = 0;
    double baseCrit = 0;
    if (live == null) {
      final str = member.statStrength;
      final intel = member.statIntelligence;
      final beauty = member.statBeauty;
      final level = member.level;
      final family = member.family;

      final (
        physAtkMult,
        elemAtkMult,
        _,
        physDefMult,
        elemDefMult,
        critMult,
      ) = switch (family) {
        'horn' => (1.40, 1.10, 0.80, 1.30, 1.20, 0.90),
        'mane' => (1.15, 1.15, 1.00, 1.10, 1.00, 1.10),
        'wing' => (0.85, 0.90, 1.30, 0.85, 0.90, 1.00),
        'let' => (1.20, 1.25, 1.10, 1.15, 1.10, 0.85),
        'pip' => (0.80, 1.00, 0.95, 0.80, 0.85, 1.40),
        'mask' => (1.00, 1.10, 1.10, 1.00, 1.05, 1.20),
        'kin' => (1.20, 0.90, 0.90, 1.10, 1.15, 0.90),
        'mystic' => (0.90, 0.85, 1.45, 0.85, 0.90, 1.00),
        _ => (1.00, 1.00, 1.00, 1.00, 1.00, 1.00),
      };

      final strPow = CosmicSurvivalBalance.survivalStatPower(str);
      final intPow = CosmicSurvivalBalance.survivalStatPower(intel);
      final beautyPow = CosmicSurvivalBalance.survivalStatPower(beauty);

      final levelFactor = 1.04 + (level - 1) * 0.065;
      basePhysAtk = max(
        1,
        ((5.0 + 24.0 * strPow) * levelFactor * physAtkMult).round(),
      );
      baseElemAtk = max(
        1,
        ((5.5 + 25.0 * beautyPow) * levelFactor * elemAtkMult).round(),
      );
      basePhysDef =
          ((15 + level * 2.8 + 58 * strPow + 34 * intPow) * physDefMult)
              .round();
      baseElemDef =
          ((15 + level * 2.8 + 58 * beautyPow + 34 * intPow) * elemDefMult)
              .round();
      baseCrit = ((0.05 + strPow * 0.32) * critMult).clamp(0.05, 0.55);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.textSecondary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.displayName,
                  style: const TextStyle(
                    color: _C.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                live == null
                    ? 'BENCHED'
                    : '${(live.hpPercent * 100).round()}% HP',
                style: TextStyle(
                  color: live == null ? _C.textSecondary : _C.success,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniReadout(
                label: 'ATK',
                value: live != null
                    ? '${(live.physAtk * attackMultiplier).round()}'
                    : '${(basePhysAtk * attackMultiplier).round()}',
              ),
              _MiniReadout(
                label: 'ELEM',
                value: live != null
                    ? '${(live.elemAtk * attackMultiplier).round()}'
                    : '${(baseElemAtk * attackMultiplier).round()}',
              ),
              _MiniReadout(
                label: 'PDEF',
                value: live != null
                    ? '${(live.physDef * defenseMultiplier).round()}'
                    : '${(basePhysDef * defenseMultiplier).round()}',
              ),
              _MiniReadout(
                label: 'EDEF',
                value: live != null
                    ? '${(live.elemDef * defenseMultiplier).round()}'
                    : '${(baseElemDef * defenseMultiplier).round()}',
              ),
              _MiniReadout(
                label: 'SPD',
                value: '${speedMultiplier.toStringAsFixed(2)}x',
              ),
              _MiniReadout(
                label: 'CRIT',
                value: live != null
                    ? '${(live.critChance * 100).round()}%'
                    : '${(baseCrit * 100).round()}%',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ALCHEMON PERKS',
            style: TextStyle(
              fontFamily: 'monospace',
              color: _C.teal,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (appliedPowerUps.isEmpty)
            const Text(
              'No personal upgrades yet.',
              style: TextStyle(color: _C.textSecondary, fontSize: 10),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: appliedPowerUps.map((entry) {
                return InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onPowerUpTap(entry),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F141B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _rarityColor(
                          entry.def.rarity,
                        ).withValues(alpha: 0.45),
                      ),
                    ),
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (badgeLabel != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: tint.withValues(alpha: 0.35)),
                ),
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
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PausePowerUpLevelPips(
                level: clampedLevel,
                maxStacks: maxStacks,
                tint: tint,
              ),
              const SizedBox(width: 6),
              Text(
                '$clampedLevel/$maxStacks',
                style: TextStyle(
                  color: tint.withValues(alpha: 0.92),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
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
          width: 7,
          height: 7,
          margin: EdgeInsets.only(right: index == maxStacks - 1 ? 0 : 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? tint : tint.withValues(alpha: 0.18),
            border: Border.all(
              color: filled ? tint : tint.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
        );
      }),
    );
  }
}

class _MiniReadout extends StatelessWidget {
  final String label;
  final String value;

  const _MiniReadout({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F141B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _C.textSecondary,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _C.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
