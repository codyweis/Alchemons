// lib/games/cosmic_survival/cosmic_survival_screen.dart
//
// COSMIC SURVIVAL SCREEN
// Flutter wrapper around CosmicSurvivalGame. Handles intro dialog,
// team selection (5 slots), HUD overlay, power-up selection, game over.

import 'dart:async';
import 'dart:math';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/games/cosmic/cosmic_data.dart';
import 'package:alchemons/games/cosmic_survival/components/mystic_graphx_overlay.dart';
import 'package:alchemons/games/cosmic_survival/components/powerup_selection_overlay.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_companion_stats.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_game.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_powerups.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_spawner.dart';
import 'package:alchemons/games/cosmic_survival/cosmic_survival_base_command_screen.dart';
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
import 'package:alchemons/services/survival_upgrade_service.dart';
import 'package:alchemons/services/shop_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_detail/battle_tab.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/widgets/coin_icon.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alchemons/widgets/app_icons.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS (matching survival aesthetic)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  static const bg0 = Color(0xFF080808);
  static const bg1 = Color(0xFF111111);
  static const bg2 = Color(0xFF171511);
  static const bg3 = Color(0xFF201D17);
  static const bg = bg0;
  static const amber = Color(0xFFC4A35A);
  static const amberBright = Color(0xFFE4C16A);
  static const accent = amber;
  static const teal = Color(0xFF5BC8E8);
  static const textPrimary = Color(0xFFE8DFC8);
  static const textSecondary = Color(0xFFB5A98A);
  static const textMuted = Color(0xFF6B6050);
  static const danger = Color(0xFFC0392B);
  static const success = Color(0xFF22C55E);
  static const borderDim = Color(0xFF2E2A23);
  static const borderAccent = Color(0xFF74613A);
}

class _T {
  static const TextStyle label = TextStyle(
    fontFamily: 'monospace',
    color: _C.textSecondary,
    fontSize: 12,
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

class _BracketFramePainter extends CustomPainter {
  const _BracketFramePainter({
    required this.color,
    required this.bracketSize,
    required this.strokeWidth,
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
  bool shouldRepaint(covariant _BracketFramePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.bracketSize != bracketSize ||
      oldDelegate.strokeWidth != strokeWidth;
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

class _SurvivalPlate extends StatelessWidget {
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final Color? background;
  final double bracketSize;

  const _SurvivalPlate({
    required this.child,
    this.accent = _C.accent,
    this.padding = const EdgeInsets.all(12),
    this.background,
    this.bracketSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BracketFramePainter(
        color: accent.withValues(alpha: 0.62),
        bracketSize: bracketSize,
        strokeWidth: 1.15,
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background ?? _C.bg1.withValues(alpha: 0.9),
          border: Border.all(color: _C.borderDim.withValues(alpha: 0.85)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      ),
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
    return CustomPaint(
      painter: _BracketFramePainter(
        color: color.withValues(alpha: 0.50),
        bracketSize: 7,
        strokeWidth: 1.05,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: _C.bg1.withValues(alpha: 0.88),
          border: Border.all(color: _C.borderDim.withValues(alpha: 0.85)),
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
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
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
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: secondary
              ? _C.textSecondary.withValues(alpha: 0.34)
              : (isDisabled ? _C.borderDim : _C.amberBright).withValues(
                  alpha: 0.72,
                ),
          bracketSize: 10,
          strokeWidth: 1.1,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: secondary ? 42 : 52,
          color: secondary
              ? Colors.white.withValues(alpha: 0.02)
              : (isDisabled
                    ? _C.bg3.withValues(alpha: 0.55)
                    : _C.amber.withValues(alpha: 0.10)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: secondary ? _C.textSecondary : _C.amberBright,
                  ),
                )
              else
                Icon(
                  icon,
                  size: secondary ? 16 : 18,
                  color: secondary
                      ? _C.textSecondary
                      : (isDisabled ? _C.textMuted : _C.amberBright),
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _display(
                    context,
                    secondary ? 12 : 14,
                    secondary
                        ? _C.textPrimary.withValues(alpha: 0.86)
                        : (isDisabled ? _C.textMuted : _C.amberBright),
                    weight: FontWeight.w700,
                    letterSpacing: secondary ? 0.5 : 0.8,
                  ),
                ),
              ),
            ],
          ),
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
  final MysticGraphxOverlayController _mysticOverlayController =
      MysticGraphxOverlayController();
  late final PageController _familyPageController;
  double _familyPage = 0;
  final Set<String> _expandedFamilyCards = <String>{};
  final Set<String> _expandedProtocols = <String>{};
  SurvivalHighScoreData? _highScore;
  bool _showPauseMenu = false;
  bool _showJoystick = true;
  bool _largeJoystick = true;
  SurvivalVisualQuality _visualQuality = SurvivalVisualQuality.performance;

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

  @override
  void initState() {
    super.initState();
    _familyPageController = PageController(viewportFraction: 0.82);
    _familyPageController.addListener(() {
      if (!mounted) return;
      setState(() => _familyPage = _familyPageController.page ?? 0);
    });
    unawaited(_loadControlPreferences());
    CinematicQualityService.qualityNotifier.addListener(_handleQualityChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadVisualQuality());
      unawaited(_loadHighScore());
      unawaited(_showIntro());
    });
  }

  @override
  void dispose() {
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    CinematicQualityService.qualityNotifier.removeListener(
      _handleQualityChanged,
    );
    _mysticOverlayController.dispose();
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
        icon: AppIcons.help_outline_rounded,
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
                        icon: AppIcons.close_rounded,
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
          maxSelections: _defaultPartySize,
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    final instanceIds = result.map((m) => m.instanceId).toList();
    final party = await _buildParty(instanceIds);
    if (party == null || party.isEmpty) return;

    // Keep regular survival formation at the default size.
    final trimmed = party.length > _defaultPartySize
        ? party.sublist(0, _defaultPartySize)
        : party;

    setState(() {
      _party = trimmed;
    });

    _startGame(trimmed);
  }

  Future<List<CosmicPartyMember>?> _buildParty(List<String> instanceIds) async {
    final db = context.read<AlchemonsDatabase>();
    final catalog = context.read<CreatureCatalog>();
    final combatBonuses = context.read<ConstellationEffectsService>();
    final members = <CosmicPartyMember>[];

    for (var i = 0; i < instanceIds.length && i < _defaultPartySize; i++) {
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

    setState(() {
      _party = party;
    });
    _startGame(party);
  }

  // ── Start Game ──────────────────────────────────────────

  void _startGame(List<CosmicPartyMember> party) {
    final upgradeSvc = context.read<SurvivalUpgradeService>();
    _mysticOverlayController.clear();

    final game = CosmicSurvivalGame(
      party: party,
      onGameOver: _handleGameOver,
      onWaveIntermission: _handleWaveIntermission,
      onWaveCleared: _handleWaveCleared,
      onBossSpawn: _handleBossSpawn,
      onMysticSpecialCast: _mysticOverlayController.spawn,
      upgradeState: upgradeSvc.state,
      visualQuality: _visualQuality,
    );

    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    setState(() {
      _game = game;
      _phase = _Phase.playing;
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
            defeatedCompanionSlots: _game!.defeatedCompanionSlots,
          );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _powerUpChoices = choices);
    });
  }

  void _handleWaveCleared(int wave) {
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
    _game?.applyPowerUp(def, targetSlot: targetSlot, targetName: targetName);
    setState(() => _powerUpChoices = []);
  }

  void _handleBossSpawn(SurvivalBoss boss) {
    if (!mounted) return;
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

    if (!mounted) return;
    _gameOverRewardEntries = List.from(popupEntries);
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
    _mysticOverlayController.clear();
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    _showPauseMenu = false;
    if (_party != null) {
      _startGame(_party!);
    } else {
      _newTeam();
    }
  }

  void _newTeam() {
    _game = null;
    _party = null;
    _mysticOverlayController.clear();
    _hudTimer?.cancel();
    _bossAnnouncementTimer?.cancel();
    _waveAnnouncementTimer?.cancel();
    setState(() {
      _phase = _Phase.teamPicker;
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
    });
  }

  void _cycleZoomLevel() {
    final game = _game;
    if (game == null || _showPauseMenu || _powerUpChoices.isNotEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      game.cycleZoomLevel();
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
                    icon: AppIcons.play_arrow_rounded,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 8),
                  _PauseActionButton(
                    label: 'QUIT',
                    icon: AppIcons.exit_to_app_rounded,
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
                  icon: AppIcons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
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

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _C.bg1,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _C.teal.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    AppIcons.insights_rounded,
                    color: _C.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      member.displayName,
                      style: const TextStyle(
                        color: _C.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const Text(
                    'RUN STATS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: _C.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
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
                      label: 'Assign Team',
                      icon: AppIcons.groups_rounded,
                      loading: false,
                      onTap: _pickTeam,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Base Command',
                      icon: AppIcons.settings_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const CosmicSurvivalBaseCommandScreen(
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
                    for (var i = 0; i < _testTeamPresets.length; i++) ...[
                      _ForgeButton(
                        label: _testTeamPresets[i].label,
                        icon: _testTeamPresets[i].icon,
                        onTap: () => _startTestTeam(
                          _buildFullElementTestTeam(_testTeamPresets[i].family),
                          _testTeamPresets[i].key,
                        ),
                        secondary: true,
                      ),
                      if (i < _testTeamPresets.length - 1)
                        const SizedBox(height: 10),
                    ],
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.borderDim, width: 1)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exit,
            child: SizedBox(
              width: 40,
              height: 40,
              child: CustomPaint(
                painter: _BracketFramePainter(
                  color: _C.textSecondary.withValues(alpha: 0.4),
                  bracketSize: 8,
                  strokeWidth: 1,
                ),
                child: const Icon(
                  AppIcons.chevron_left_rounded,
                  color: _C.textSecondary,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _HeaderPulseDot(),
                    const SizedBox(width: 8),
                    Text(
                      'Survival Mode',
                      style: _display(
                        context,
                        23,
                        _C.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Endless wave defense',
                  style: _display(
                    context,
                    13,
                    _C.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          if (_highScore != null && _highScore!.bestWave > 0)
            GestureDetector(
              onTap: _showHighScoreDetails,
              child: CustomPaint(
                painter: _BracketFramePainter(
                  color: _C.amberBright.withValues(alpha: 0.55),
                  bracketSize: 10,
                  strokeWidth: 1.1,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  color: _C.bg2.withValues(alpha: 0.65),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            AppIcons.emoji_events_outlined,
                            color: _C.amberBright,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'W${_highScore!.bestWave}',
                            style: _display(
                              context,
                              14,
                              _C.amberBright,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        _formatHighScoreNumber(_highScore!.bestScore),
                        style: _display(
                          context,
                          11,
                          _C.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Best',
                        style: _display(
                          context,
                          11,
                          _C.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
          height: expandedActive ? 340 : 200,
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
                          info.role,
                          style: _display(
                            context,
                            13,
                            info.color,
                            weight: FontWeight.w700,
                            letterSpacing: 0.6,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  info.name,
                                  style: _display(
                                    context,
                                    20,
                                    _C.textPrimary,
                                    weight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Icon(
                                expanded
                                    ? AppIcons.expand_less_rounded
                                    : AppIcons.expand_more_rounded,
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
                            secondChild: Text(info.description, style: _T.body),
                            crossFadeState: expanded
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
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
                AppIcons.groups_rounded,
                'FUSING',
                'High-stat alchemons will spike earlier and convert upgrades harder.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                AppIcons.auto_awesome_rounded,
                'DRAFTING',
                'Weighted offers amplify each family role instead of replacing it.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTacticTile(
                AppIcons.waves_rounded,
                'MUTATORS',
                'Wave rules evolve through elites, mutators, and faster late-run tempo spikes.',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                AppIcons.shield_outlined,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? AppIcons.expand_less_rounded
                        : AppIcons.expand_more_rounded,
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
                  style: _T.body.copyWith(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                secondChild: Text(desc, style: _T.body.copyWith(fontSize: 12)),
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

        Positioned.fill(
          child: MysticGraphxOverlay(controller: _mysticOverlayController),
        ),

        _buildLivePlayOverlay(game),

        // Joystick (bottom left). Re-check `game.isLoaded` on live ticks so
        // enabled joystick appears as soon as the game finishes loading.
        ValueListenableBuilder<int>(
          valueListenable: _liveUiTick,
          builder: (_, __, ___) {
            if (!game.isLoaded || !_showJoystick) {
              return const SizedBox.shrink();
            }
            return Positioned(
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
            );
          },
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
          Positioned.fill(
            child: SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: _SurvivalPlate(
                    accent: _C.danger,
                    bracketSize: 9,
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
        if (_waveAnnouncementTitle != null)
          Positioned.fill(
            child: IgnorePointer(
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: _bossAnnouncement != null ? 152 : 60,
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
              color: const Color(0xFF0E1117).withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.teal.withValues(alpha: 0.28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SHIP DESTROYED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.teal.withValues(alpha: 0.55),
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
    final zoomIcon = switch (game.currentZoomLevel) {
      0 => AppIcons.zoom_out_map_rounded,
      2 => AppIcons.zoom_in_map_rounded,
      _ => AppIcons.center_focus_strong_rounded,
    };
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
                icon: AppIcons.timer_outlined,
                label: game.stats.formattedTime,
                color: _C.textSecondary,
              ),
              const SizedBox(width: 8),
              _HudIconButton(
                icon: _showPauseMenu
                    ? AppIcons.play_arrow_rounded
                    : AppIcons.pause_rounded,
                color: _C.accent,
                onTap: _togglePauseMenu,
              ),
              const SizedBox(width: 6),
              _HudIconButton(
                icon: zoomIcon,
                color: _C.teal,
                onTap: _cycleZoomLevel,
              ),
              const SizedBox(width: 8),
              // Ship HP
              if (game.isLoaded) ...[
                Flexible(
                  child: _HudBar(
                    label: game.ship.isDead ? 'GHOST' : 'SHIP',
                    percent: game.ship.isDead ? 1.0 : game.ship.hpPercent,
                    color: game.ship.isDead
                        ? const Color(0xFF9FE8FF)
                        : const Color(0xFF00E5FF),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Orb HP
              Flexible(
                child: _HudBar(
                  label: 'ORB',
                  percent: game.isLoaded ? game.orb.hpPercent : 1.0,
                  color: _C.accent,
                ),
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
                accent: _C.amber,
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
                                  value:
                                      '${(game.orb.hpPercent * 100).round()}%',
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
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
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
                                        color: _C.bg1,
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
                              const SizedBox(height: 14),
                            ],
                            const Text(
                              'POWERUPS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _C.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.6,
                              ),
                            ),
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
                                            color: _C.bg1,
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
                            const SizedBox(height: 14),
                            const Text(
                              'ALCHEMON STATS',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: _C.teal,
                                fontSize: 12,
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
                                  vineFeedCount: game.maskPlantFeedCount(index),
                                  onPowerUpTap: (entry) => _showPowerUpInfo(
                                    entry.def,
                                    game.powerUps,
                                    slotIndex: entry.targetSlot,
                                    targetName: entry.targetName,
                                  ),
                                  onTap: () => _showCompanionStats(index),
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
                              _PauseActionButton(
                                label: 'QUIT',
                                icon: AppIcons.exit_to_app_rounded,
                                onTap: _quitRunFromPause,
                                fillColor: _C.danger,
                                filled: false,
                                compact: true,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _PauseActionButton(
                                  label: 'RESUME',
                                  icon: AppIcons.play_arrow_rounded,
                                  onTap: _closePauseMenu,
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
                                    const Text(
                                      'JOYSTICK',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: _C.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      height: 24,
                                      child: Switch.adaptive(
                                        value: _showJoystick,
                                        activeThumbColor: _C.accent,
                                        activeTrackColor: _C.accent.withValues(
                                          alpha: 0.34,
                                        ),
                                        inactiveThumbColor: _C.textMuted,
                                        inactiveTrackColor: _C.borderDim,
                                        onChanged: (v) async {
                                          setState(() {
                                            _showJoystick = v;
                                            if (!v) {
                                              game.setJoystickInput(
                                                Offset.zero,
                                              );
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
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Text(
                                      'LARGE',
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        color: _C.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      height: 24,
                                      child: Switch.adaptive(
                                        value: _largeJoystick,
                                        activeThumbColor: _C.accent,
                                        activeTrackColor: _C.accent.withValues(
                                          alpha: 0.34,
                                        ),
                                        inactiveThumbColor: _C.textMuted,
                                        inactiveTrackColor: _C.borderDim,
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
    final slotsMaxHeight = min(MediaQuery.sizeOf(context).height * 0.5, 430.0);
    return Positioned(
      right: 12,
      top: 100,
      child: SafeArea(
        child: _SurvivalPlate(
          accent: tethered ? _C.teal : _C.borderAccent,
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          background: _C.bg1.withValues(alpha: 0.82),
          bracketSize: 8,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: slotsMaxHeight + 56),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tether / Follow toggle
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (tethered) {
                      game.clearCompanionTether();
                    } else {
                      game.tetherClosestCompanionToShip();
                    }
                    setState(() {});
                  },
                  child: Container(
                    width: 44,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      color: tethered
                          ? _C.teal.withValues(alpha: 0.20)
                          : _C.bg2.withValues(alpha: 0.72),
                      border: Border.all(
                        color: tethered
                            ? _C.teal.withValues(alpha: 0.74)
                            : _C.borderDim,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tethered
                              ? AppIcons.link_rounded
                              : AppIcons.link_off_rounded,
                          color: tethered ? _C.teal : _C.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tethered ? 'FOLLOW' : 'FREE',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: tethered
                                ? _C.teal
                                : _C.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
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
              ],
            ),
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
      child: CustomPaint(
        painter: _BracketFramePainter(
          color:
              (isDead
                      ? _C.danger
                      : isTethered
                      ? _C.teal
                      : isActive
                      ? _C.amberBright
                      : _C.borderAccent)
                  .withValues(alpha: isActive || isTethered ? 0.76 : 0.42),
          bracketSize: 5,
          strokeWidth: isActive || isTethered ? 1.15 : 0.9,
        ),
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
                : _C.bg2.withValues(alpha: 0.86),
            border: Border.all(color: _C.borderDim.withValues(alpha: 0.82)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Creature image or placeholder
              Center(
                child: member.imagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
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
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                        width: 0.6,
                      ),
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
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (hp > 0.5
                                          ? _C.success
                                          : hp > 0.25
                                          ? Colors.orange
                                          : _C.danger)
                                      .withValues(alpha: 0.45),
                              blurRadius: 4,
                            ),
                          ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              // Mask+Plant vine feed badge (top-left). Shows current
              // feeds/100 + active tendril count so the player can
              // track vine growth without leaving the run.
              if (isActive &&
                  member.family.toLowerCase() == 'mask' &&
                  member.element == 'Plant')
                Positioned(
                  top: -2,
                  left: -2,
                  child: Builder(
                    builder: (_) {
                      final feeds = game.maskPlantFeedCount(slotIndex);
                      final tendrils = (1 + (feeds ~/ 10)).clamp(1, 10);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(
                              0xFF6FCB6F,
                            ).withValues(alpha: 0.85),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$feeds·${tendrils}t',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      );
                    },
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
                      AppIcons.link_rounded,
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
                    child: Icon(AppIcons.close, color: _C.danger, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Game Over Phase ────────────────────────────────────

  Widget _buildGameOver() {
    const frame = Color(0xFFFF9BA3);
    const amber = Color(0xFFFFAA00);

    Widget statChip(String label, String value) => Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );

    void showRewardDetail(BuildContext ctx, LootOpeningEntry entry) {
      showDialog<void>(
        context: ctx,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1117),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: entry.color.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: entry.color.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.color.withValues(alpha: 0.12),
                    border: Border.all(
                      color: entry.color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: entry.visualBuilder != null
                      ? Center(child: entry.visualBuilder!(48))
                      : Icon(entry.icon, color: entry.color, size: 30),
                ),
                const SizedBox(height: 16),
                if (entry.name != null)
                  Text(
                    entry.name!.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  entry.label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: entry.color,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(dialogCtx),
                  child: Container(
                    width: double.infinity,
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(
                        color: entry.color.withValues(alpha: 0.5),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'CLOSE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: entry.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3,
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

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.96),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ORB DESTROYED',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: frame,
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: frame.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),

                  // Stat chips
                  Row(
                    children: [
                      statChip('WAVE', '$_finalWave'),
                      statChip('KILLS', '$_finalKills'),
                      statChip('SCORE', '$_finalScore'),
                      statChip('TIME', _finalTime),
                    ],
                  ),

                  if (_gameOverRewardEntries.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'REWARDS  —  TAP FOR DETAILS',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: amber.withValues(alpha: 0.55),
                        fontSize: 12,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...(_gameOverRewardEntries.map(
                      (entry) => Builder(
                        builder: (ctx) => GestureDetector(
                          onTap: () => showRewardDetail(ctx, entry),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: entry.color.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(
                                color: entry.color.withValues(alpha: 0.22),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: entry.color.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: entry.color.withValues(
                                        alpha: 0.35,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: entry.visualBuilder != null
                                      ? Center(child: entry.visualBuilder!(28))
                                      : Icon(
                                          entry.icon,
                                          color: entry.color,
                                          size: 18,
                                        ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    entry.name?.toUpperCase() ?? '',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ),
                                Text(
                                  entry.label,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: entry.color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  AppIcons.chevron_right,
                                  color: entry.color.withValues(alpha: 0.45),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )),
                  ],

                  const SizedBox(height: 20),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _newTeam,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          child: const Text(
                            'NEW TEAM',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _replay,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: frame, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          child: const Text(
                            'DEPLOY AGAIN',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
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
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // HUD WIDGETS
  // ─────────────────────────────────────────────────────────────────────────────
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
        'Long-range element casters that shower enemies with meteors. Elemental follow-ups now trigger on meteor impact and scale with Beauty + Intelligence.',
    bestPowerups:
        'Spellbloom, Double Cast, Chrono Grit | Threshold focus: Beauty + Intelligence',
    assetPath: 'assets/images/creatures/common/LET02_waterlet.png',
    color: Color(0xFF3B82F6),
  ),
  _FamilyInfo(
    id: 'Pip',
    name: 'Pip',
    role: 'Tempo Carry',
    description:
        'Fast agile attackers that chase leaks and clean up packs. Special output scales with tactical stats and ramps hard at high stat values.',
    bestPowerups:
        'Warpath, Quicksilver Step, Chrono Grit | Threshold focus: Intelligence + Beauty proxy',
    assetPath: 'assets/images/creatures/uncommon/PIP06_lavapip.png',
    color: Color(0xFFEF4444),
  ),
  _FamilyInfo(
    id: 'Mane',
    name: 'Mane',
    role: 'Barrage Bruiser',
    description:
        'Mid-range slash fighters that carve through lanes with consistent pressure. Special riders improve sharply as Strength climbs.',
    bestPowerups:
        'Warpath, Forged Strikes, Blood Pact | Threshold focus: Strength + Beauty support',
    assetPath: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
    color: Color(0xFFF59E0B),
  ),
  _FamilyInfo(
    id: 'Horn',
    name: 'Horn',
    role: 'Frontline Bastion',
    description:
        'Tanky close-range chargers that body-block for the orb. Defensive riders (shield/charge package) unlock reliably at mid-to-high stat values.',
    bestPowerups:
        'Bastion Heart, Forged Strikes, Forgeplate | Threshold focus: Strength + Intelligence',
    assetPath: 'assets/images/creatures/rare/HOR13_poisonhorn.png',
    color: Color(0xFF10B981),
  ),
  _FamilyInfo(
    id: 'Mask',
    name: 'Mask',
    role: 'Tactical Duelist',
    description:
        'Versatile duelists with control utility. Special consistency scales with tactical stats, with stronger utility riders at high stats.',
    bestPowerups:
        'Chrono Surge, Forgeplate, Chrono Grit | Threshold focus: Intelligence + Beauty',
    assetPath: 'assets/images/creatures/rare/MSK01_firemask.png',
    color: Color(0xFF8B5CF6),
  ),
  _FamilyInfo(
    id: 'Wing',
    name: 'Wing',
    role: 'Sniper Control',
    description:
        'High-range snipers that delete shooters and boss lanes. Special uptime and control scale with Intelligence + Beauty.',
    bestPowerups:
        'Spellbloom, Double Cast, Chrono Grit | Threshold focus: Intelligence + Beauty',
    assetPath: 'assets/images/creatures/legendary/WNG03_earthwing.png',
    color: Color(0xFF06B6D4),
  ),
  _FamilyInfo(
    id: 'Kin',
    name: 'Kin',
    role: 'Support Anchor',
    description:
        'Durable utility companions that sustain the team and stabilize waves. Kin uses a hard dual gate: both Beauty and Intelligence must be high for full support output.',
    bestPowerups:
        'Bastion Heart, Regeneration Field, Shield Pulse | Threshold focus: Beauty + Intelligence (both)',
    assetPath: 'assets/images/creatures/legendary/KIN16_lightkin.png',
    color: Color(0xFF14B8A6),
  ),
  _FamilyInfo(
    id: 'Mystic',
    name: 'Mystic',
    role: 'Spell Engine',
    description:
        'Powerful casters with the highest elemental multiplier. Core spell tiers use Beauty + Intelligence, while high Strength adds burst bias at top thresholds.',
    bestPowerups:
        'Spellbloom, Double Cast, Chrono Grit | Threshold focus: Beauty + Intelligence, Strength for burst',
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
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: color.withValues(alpha: 0.68),
          bracketSize: 6,
          strokeWidth: 1.1,
        ),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _C.bg1.withValues(alpha: 0.88),
            border: Border.all(color: _C.borderDim),
          ),
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  final String label;
  final double percent;
  final Color color;

  const _HudBar({
    required this.label,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clampedPercent = percent.clamp(0.0, 1.0);
    final percentLabel = '${(clampedPercent * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _C.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                percentLabel,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: color.withValues(alpha: 0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 10,
          decoration: BoxDecoration(
            color: _C.bg0.withValues(alpha: 0.88),
            border: Border.all(color: _C.borderDim),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 10,
                spreadRadius: 0.5,
              ),
            ],
          ),
          alignment: Alignment.centerLeft,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              FractionallySizedBox(
                widthFactor: clampedPercent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color.lerp(color, Colors.white, 0.18) ?? color,
                        color,
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
  final bool filled;
  final bool compact;

  const _PauseActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.fillColor = _C.accent,
    this.filled = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _BracketFramePainter(
          color: fillColor.withValues(alpha: filled ? 0.72 : 0.42),
          bracketSize: 6,
          strokeWidth: 1.05,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 8 : 11,
          ),
          decoration: BoxDecoration(
            color: filled
                ? fillColor.withValues(alpha: 0.13)
                : Colors.transparent,
            border: Border.all(color: _C.borderDim.withValues(alpha: 0.85)),
          ),
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
    return CustomPaint(
      painter: _BracketFramePainter(
        color: accent.withValues(alpha: 0.30),
        bracketSize: 5,
        strokeWidth: 0.9,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: _C.bg2.withValues(alpha: 0.88),
          border: Border.all(color: _C.borderDim.withValues(alpha: 0.72)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: 'monospace',
                color: _C.textSecondary,
                fontSize: 12,
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
    final effSpeed = member.statSpeed + powerUps.speedBonus(slotIndex);
    final benchedStats = live == null
        ? deriveCosmicSurvivalCompanionStats(
            member: member,
            strengthBonus: powerUps.strengthBonus(slotIndex),
            intelligenceBonus: powerUps.intelligenceBonus(slotIndex),
            beautyBonus: powerUps.beautyBonus(slotIndex),
            speedBonus: powerUps.speedBonus(slotIndex),
          )
        : null;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _C.bg2.withValues(alpha: 0.86),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(AppIcons.insights_rounded, size: 14, color: _C.teal),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 7,
              children: [
                _MiniReadout(
                  label: 'ATK',
                  value: live != null
                      ? '${live.physAtk}'
                      : '${benchedStats!.physAtk}',
                ),
                _MiniReadout(
                  label: 'ELEM',
                  value: live != null
                      ? '${live.elemAtk}'
                      : '${benchedStats!.elemAtk}',
                ),
                _MiniReadout(
                  label: 'PDEF',
                  value: live != null
                      ? '${live.physDef}'
                      : '${benchedStats!.physDef}',
                ),
                _MiniReadout(
                  label: 'EDEF',
                  value: live != null
                      ? '${live.elemDef}'
                      : '${benchedStats!.elemDef}',
                ),
                _MiniReadout(
                  label: 'SPD',
                  value: AlchemonStatSystem.displayRating(effSpeed).toString(),
                ),
                _MiniReadout(
                  label: 'CRIT',
                  value: live != null
                      ? '${(live.critChance * 100).round()}%'
                      : '${(benchedStats!.critChance * 100).round()}%',
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
            const Text(
              'ALCHEMON PERKS',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.teal,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
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
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onPowerUpTap(entry),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _C.bg1,
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
    out.add(('Wisp bank', '${live.maskSpiritWispBank}/6'));
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
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Container(
            height: 5,
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0).toDouble(),
              child: Container(
                decoration: BoxDecoration(
                  color: vineColor,
                  boxShadow: [
                    BoxShadow(
                      color: vineColor.withValues(alpha: 0.55),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
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
          width: 9,
          height: 9,
          margin: EdgeInsets.only(right: index == maxStacks - 1 ? 0 : 5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? tint : Colors.transparent,
            border: Border.all(
              color: filled ? tint : tint.withValues(alpha: 0.3),
              width: 1.1,
            ),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.55),
                      blurRadius: 6,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
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
                decoration: BoxDecoration(
                  color: _C.teal.withValues(alpha: 0.10),
                  border: Border.all(color: _C.teal.withValues(alpha: 0.34)),
                ),
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
            style: const TextStyle(
              color: _C.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
