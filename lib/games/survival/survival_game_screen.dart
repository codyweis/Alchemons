// lib/games/survival/survival_game_screen.dart
//
// REDESIGNED SURVIVAL GAME SCREEN
// Aesthetic: Dark alchemical lab — scorched metal, amber reagents, runic engravings
// Replaced: Cheesy purple gradient cards → tactical deployment UI with game feel
//

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/games/survival/components/debug_teams_picker.dart';
import 'package:alchemons/games/survival/components/deployment_phase_overlay.dart';
import 'package:alchemons/games/survival/survival_engine.dart';
import 'package:alchemons/games/survival/survival_party_picker.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/animations/loot_open_popup.dart';
import 'package:alchemons/games/survival/survival_game.dart';
import 'package:alchemons/widgets/background/alchemical_particle_background.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';

// ──────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ──────────────────────────────────────────────────────────────────────────────

class _C {
  // Scorched-metal background palette
  static const bg0 = Color(0xFF080A0E); // void black
  static const bg1 = Color(0xFF0E1117); // dark forge
  static const bg2 = Color(0xFF141820); // panel surface
  static const bg3 = Color(0xFF1C2230); // raised surface

  // Amber reagent accents
  static const amber = Color(0xFFD97706);
  static const amberBright = Color(0xFFF59E0B);
  static const amberGlow = Color(0xFFFFB020);
  static const amberDim = Color(0xFF92400E);

  // Runic teal — secondary accent
  static const teal = Color(0xFF0EA5E9);
  static const tealDim = Color(0xFF0C4A6E);

  // Text
  static const textPrimary = Color(0xFFE8DCC8); // parchment
  static const textSecondary = Color(0xFF8A7B6A); // aged ink
  static const textMuted = Color(0xFF4A3F35);

  // Danger / wave red
  static const danger = Color(0xFFC0392B);
  static const dangerDim = Color(0xFF7B241C);

  // Borders
  static const borderDim = Color(0xFF252D3A);
  static const borderMid = Color(0xFF3A3020);
  static const borderAccent = Color(0xFF6B4C20);
}

// ──────────────────────────────────────────────────────────────────────────────
// TYPOGRAPHY
// ──────────────────────────────────────────────────────────────────────────────

class _T {
  // Display / heading — tight tracked caps
  static const TextStyle title = TextStyle(
    fontFamily: 'monospace',
    color: _C.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: 2.4,
  );

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

  static const TextStyle stat = TextStyle(
    fontFamily: 'monospace',
    color: _C.amberBright,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ──────────────────────────────────────────────────────────────────────────────

/// Etched horizontal rule with optional center label
class _EtchedDivider extends StatelessWidget {
  final String? label;
  const _EtchedDivider({this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _C.borderMid)),
        if (label != null) ...[
          const SizedBox(width: 10),
          Text(label!, style: _T.label),
          const SizedBox(width: 10),
        ],
        Expanded(child: Container(height: 1, color: _C.borderMid)),
      ],
    );
  }
}

/// Corner-accent box — scorched metal plating look
class _PlateBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accentColor;
  final bool highlight;

  const _PlateBox({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? _C.amber;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? accent.withOpacity(0.6) : _C.borderDim,
          width: highlight ? 1.5 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: accent.withOpacity(0.12),
                  blurRadius: 18,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          child,
          // Corner notch — top left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: accent.withOpacity(0.5), width: 1.5),
                  left: BorderSide(color: accent.withOpacity(0.5), width: 1.5),
                ),
              ),
            ),
          ),
          // Corner notch — bottom right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: accent.withOpacity(0.5),
                    width: 1.5,
                  ),
                  right: BorderSide(color: accent.withOpacity(0.5), width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Amber-glow primary CTA button
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
                ? _C.borderAccent.withOpacity(0.6)
                : (isDisabled ? _C.borderDim : _C.amberGlow),
            width: 1,
          ),
          boxShadow: (!secondary && !isDisabled)
              ? [
                  BoxShadow(
                    color: _C.amber.withOpacity(0.35),
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

// ──────────────────────────────────────────────────────────────────────────────
// SCREEN STATE
// ──────────────────────────────────────────────────────────────────────────────

enum _ScreenState { menu, deployment, playing }

class SurvivalGameScreen extends StatefulWidget {
  const SurvivalGameScreen({super.key});
  @override
  State<SurvivalGameScreen> createState() => _SurvivalGameScreenState();
}

class _SurvivalGameScreenState extends State<SurvivalGameScreen>
    with TickerProviderStateMixin {
  _ScreenState _screenState = _ScreenState.menu;
  SurvivalHoardGame? _game;
  bool _isSpeedUpEnabled = false;
  bool _isLoading = false;
  List<PartyMember>? _loadedParty;

  late final PageController _familyPageController;
  double _familyPage = 0;

  // Highscore
  SurvivalHighScoreData? _highScore;

  // Scanline / flicker for UI atmosphere
  late final AnimationController _flickerCtrl;
  late final Animation<double> _flicker;

  @override
  void initState() {
    super.initState();
    _familyPageController = PageController(viewportFraction: 0.82);
    _familyPageController.addListener(() {
      setState(() => _familyPage = _familyPageController.page ?? 0);
    });

    _flickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);
    _flicker = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _flickerCtrl, curve: Curves.easeInOut));

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHighScore());
  }

  Future<void> _loadHighScore() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final hs = await db.getSurvivalHighScore();
    if (mounted) setState(() => _highScore = hs);
  }

  @override
  void dispose() {
    _familyPageController.dispose();
    _flickerCtrl.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  Future<void> _openFormationSelector() async {
    final selectedSquad = await Navigator.of(context).push<Map<int, String>>(
      MaterialPageRoute(
        builder: (_) => const SurvivalFormationSelectorScreen(),
      ),
    );
    if (selectedSquad != null && mounted) {
      await _loadPartyAndShowDeployment(selectedSquad);
    }
  }

  Future<void> _loadPartyAndShowDeployment(
    Map<int, String> selectedSquad,
  ) async {
    if (_isLoading) return;
    if (selectedSquad.length < 4) {
      _showError('SELECT AT LEAST 4 CREATURES');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final db = context.read<AlchemonsDatabase>();
      final catalog = context.read<CreatureCatalog>();
      final party = await _buildPartyFromSquad(
        squadIds: selectedSquad.values.toList(),
        db: db,
        catalog: catalog,
      );
      if (party.length < 4) {
        _showError('FAILED TO LOAD ALL CREATURES');
        return;
      }
      if (mounted) {
        setState(() {
          _loadedParty = party;
          _screenState = _ScreenState.deployment;
          _isLoading = false;
        });
      }
    } catch (e) {
      _showError('ERROR: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontFamily: 'monospace', letterSpacing: 1),
        ),
        backgroundColor: _C.danger,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatHighScoreNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Future<List<PartyMember>> _buildPartyFromSquad({
    required List<String> squadIds,
    required AlchemonsDatabase db,
    required CreatureCatalog catalog,
  }) async {
    final List<PartyMember> party = [];
    for (final instanceId in squadIds) {
      final instance = await db.creatureDao.getInstance(instanceId);
      if (instance == null) continue;
      final species = catalog.getCreatureById(instance.baseId);
      if (species == null) continue;
      party.add(
        PartyMember(
          combatant: PartyCombatantStats(
            id: instance.instanceId,
            name: instance.nickname ?? species.name,
            types: species.types,
            family: species.mutationFamily!,
            level: instance.level,
            statSpeed: instance.statSpeed,
            statIntelligence: instance.statIntelligence,
            statStrength: instance.statStrength,
            statBeauty: instance.statBeauty,
            sheetDef: sheetFromCreature(species),
            spriteVisuals: visualsFromInstance(species, instance),
          ),
          position: FormationPosition.frontLeft,
        ),
      );
    }
    return party;
  }

  void _onDeploymentConfirmed(DeploymentResult result) {
    if (_loadedParty == null) return;
    final List<PartyMember> reorderedParty = [];
    for (final deployed in result.deployedCreatures) {
      final orig = _loadedParty!.firstWhere(
        (m) => m.combatant.id == deployed.id,
      );
      reorderedParty.add(
        PartyMember(
          combatant: orig.combatant,
          position: _slotToFormationPosition(deployed.assignedSlot!),
        ),
      );
    }
    for (final bench in result.benchCreatures) {
      final orig = _loadedParty!.firstWhere((m) => m.combatant.id == bench.id);
      reorderedParty.add(
        PartyMember(
          combatant: orig.combatant,
          position: FormationPosition.backRight,
        ),
      );
    }
    setState(() {
      _game = SurvivalHoardGame(
        party: reorderedParty,
        onGameOver: _handleGameOver,
      )..setSimulationSpeed(_isSpeedUpEnabled ? 2.0 : 1.0);
      _screenState = _ScreenState.playing;
    });
  }

  FormationPosition _slotToFormationPosition(int slotIndex) {
    switch (slotIndex % 4) {
      case 0:
        return FormationPosition.frontLeft;
      case 1:
        return FormationPosition.frontRight;
      case 2:
        return FormationPosition.backLeft;
      default:
        return FormationPosition.backRight;
    }
  }

  void _onDeploymentCancelled() {
    setState(() {
      _loadedParty = null;
      _screenState = _ScreenState.menu;
    });
  }

  Future<void> _openDebugTeamPicker() async {
    if (_isLoading) return;
    final party = await Navigator.of(context).push<List<PartyMember>>(
      MaterialPageRoute(builder: (_) => const SurvivalDebugTeamPickerScreen()),
    );
    if (party == null || !mounted) return;
    setState(() {
      _loadedParty = party;
      _screenState = _ScreenState.deployment;
    });
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GAME OVER
  // ──────────────────────────────────────────────────────────────────────────

  void _handleGameOver() async {
    if (!mounted) return;
    final db = context.read<AlchemonsDatabase>();
    final timeElapsed = _game?.timeElapsed ?? 0;
    final wave = _game?.currentWave ?? 1;
    final score = _game?.score ?? 0;
    final kills = _game?.kills ?? 0;

    // ── Save highscore ───────────────────────────────────────────────────────
    final prevBest = await db.getSurvivalHighScore();
    final isNewRecord =
        prevBest == null ||
        wave > prevBest.bestWave ||
        score > prevBest.bestScore;
    await db.saveSurvivalHighScore(
      wave: wave,
      score: score,
      timeMs: (timeElapsed * 1000).round(),
    );
    // Refresh displayed highscore on the menu
    _loadHighScore();

    String lootRewardLabel = '';
    String currencyRewardLabel = 'No bonus currency';
    final lootRewardDetails = <String>[];
    final currencyRewardDetails = <String>[];
    final popupEntries = <LootOpeningEntry>[];
    final rng = Random();
    final rolledReward = LootBoxConfig.rollSurvivalLootBoxReward(wave, rng);
    final fallbackBoxKey = BossLootKeys.lootBoxKeyForElement(
      BossLootKeys.elementRewards.keys.elementAt(
        rng.nextInt(BossLootKeys.elementRewards.length),
      ),
    );
    final lootReward =
        rolledReward ??
        SurvivalLootBoxReward(boxKey: fallbackBoxKey, quantity: 1);
    final registry = buildInventoryRegistry(db);
    final openedRewards = LootBoxConfig.rollBossLootBoxDropsForQuantity(
      lootReward.boxKey,
      lootReward.quantity,
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
          color: _C.amber,
        );
      }),
    );
    lootRewardLabel = openedRewards
        .map((entry) {
          final def = registry[entry.key];
          return '${def?.name ?? entry.key} x${entry.value}';
        })
        .join(', ');
    lootRewardDetails.addAll(
      openedRewards.map((entry) {
        final def = registry[entry.key];
        return '${def?.name ?? entry.key} ×${entry.value}';
      }),
    );
    if (popupEntries.isEmpty) {
      popupEntries.add(
        const LootOpeningEntry(
          icon: Icons.inventory_2_rounded,
          name: 'Item',
          label: 'x1',
          color: _C.amber,
        ),
      );
    }

    if (rolledReward != null) {
      // Wave 50+ guaranteed portal key
      final bonusPortalKey = LootBoxConfig.rollSurvivalBonusPortalKey(
        wave,
        rng,
      );
      if (bonusPortalKey != null) {
        await db.inventoryDao.addItemQty(bonusPortalKey, 1);
        final def = registry[bonusPortalKey];
        popupEntries.add(
          LootOpeningEntry(
            icon: def?.icon ?? Icons.vpn_key_rounded,
            name: def?.name ?? 'Portal Key',
            label: '×1 PORTAL KEY',
            color: const Color(0xFFD4AF37),
          ),
        );
      }

      final currencyRewards = LootBoxConfig.rollSurvivalBonusCurrency(
        wave,
        rng,
      );
      final silver = currencyRewards['silver'] ?? 0;
      final gold = currencyRewards['gold'] ?? 0;
      if (silver > 0) {
        await db.currencyDao.addSilver(silver);
        currencyRewardDetails.add('Silver ×$silver');
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
        currencyRewardDetails.add('Gold ×$gold');
        popupEntries.add(
          LootOpeningEntry(
            icon: Icons.stars_rounded,
            name: 'Gold',
            label: '+$gold',
            color: _C.amberBright,
          ),
        );
      }
      currencyRewardLabel = '+$silver silver${gold > 0 ? ', +$gold gold' : ''}';
    } else {
      final pitySilver = 50 + rng.nextInt(51);
      await db.currencyDao.addSilver(pitySilver);
      currencyRewardDetails.add('Silver ×$pitySilver');
      popupEntries.add(
        LootOpeningEntry(
          icon: Icons.monetization_on_rounded,
          name: 'Silver',
          label: '+$pitySilver',
          color: const Color(0xFFB0BEC5),
        ),
      );
      currencyRewardLabel = '+$pitySilver silver';
    }

    await showLootOpeningDialog(context: context, entries: popupEntries);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _GameOverDialog(
        wave: wave,
        timeElapsed: timeElapsed,
        score: score,
        kills: kills,
        lootRewardLabel: lootRewardLabel,
        lootRewardDetails: lootRewardDetails,
        currencyRewardLabel: currencyRewardLabel,
        currencyRewardDetails: currencyRewardDetails,
        isNewRecord: isNewRecord,
        prevBestWave: prevBest?.bestWave,
        prevBestScore: prevBest?.bestScore,
        onRedeploy: () {
          Navigator.pop(dialogContext);
          setState(() {
            _game = null;
            _screenState = _ScreenState.deployment;
          });
        },
        onNewTeam: () {
          Navigator.pop(dialogContext);
          setState(() {
            _game = null;
            _loadedParty = null;
            _screenState = _ScreenState.menu;
          });
        },
        onExit: () {
          Navigator.pop(dialogContext);
          Navigator.pop(context);
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    switch (_screenState) {
      case _ScreenState.menu:
        return _buildMenuScreen();
      case _ScreenState.deployment:
        return _buildDeploymentScreen();
      case _ScreenState.playing:
        return _buildGameScreen();
    }
  }

  Widget _buildMenuScreen() {
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, child) =>
          Opacity(opacity: _flicker.value, child: child),
      child: _buildFormationPrompt(),
    );
  }

  Widget _buildDeploymentScreen() {
    if (_loadedParty == null) {
      return const Scaffold(
        backgroundColor: _C.bg0,
        body: Center(child: CircularProgressIndicator(color: _C.amber)),
      );
    }
    final catalog = context.read<CreatureCatalog>();
    return DeploymentPhaseOverlay(
      party: _loadedParty!,
      catalog: catalog,
      onConfirm: _onDeploymentConfirmed,
      onCancel: _onDeploymentCancelled,
    );
  }

  Widget _buildGameScreen() {
    final theme = context.watch<FactionTheme>();
    return _buildGameView(theme);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // MENU UI
  // ──────────────────────────────────────────────────────────────────────────

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
                      onTap: _isLoading ? null : _openFormationSelector,
                      loading: _isLoading,
                    ),
                    const SizedBox(height: 10),
                    _ForgeButton(
                      label: 'Test Squad',
                      icon: Icons.science_outlined,
                      onTap: _isLoading ? null : _openDebugTeamPicker,
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
            onTap: () => Navigator.of(context).pop(),
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
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8, bottom: 1),
                      decoration: const BoxDecoration(
                        color: _C.amberBright,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const Text('SURVIVAL MODE', style: _T.heading),
                  ],
                ),
                const SizedBox(height: 2),
                const Text('ENDLESS WAVE DEFENSE', style: _T.label),
              ],
            ),
          ),
          // Wave counter / difficulty indicator + highscore
          Row(
            children: [
              _PlateBox(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                accentColor: _C.danger,
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
                _PlateBox(
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
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesRoster() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtchedDivider(label: 'SPECIES ROSTER'),
        const SizedBox(height: 14),
        SizedBox(
          height: 200,
          child: PageView.builder(
            controller: _familyPageController,
            itemCount: _familyInfos.length,
            itemBuilder: (context, index) {
              final info = _familyInfos[index];
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
        // Pip indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_familyInfos.length, (i) {
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _C.borderDim),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Stack(
          children: [
            // Subtle scanline texture
            Positioned.fill(child: CustomPaint(painter: _ScanlinePainter())),
            // Left — sprite with amber lens flare
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Amber radial glow behind sprite
                  Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          info.color.withOpacity(0.25),
                          Colors.transparent,
                        ],
                        radius: 0.8,
                      ),
                    ),
                  ),
                  // Sprite silhouette
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(
                        info.color.withOpacity(0.9),
                        BlendMode.srcATop,
                      ),
                      child: Image.asset(info.assetPath, fit: BoxFit.contain),
                    ),
                  ),
                  // Bottom label — role badge
                  Positioned(
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: info.color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(2),
                        border: Border.all(
                          color: info.color.withOpacity(0.5),
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
            // Vertical separator
            Positioned(
              left: 140,
              top: 12,
              bottom: 12,
              child: Container(width: 1, color: _C.borderDim),
            ),
            // Right — text info
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.name.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: _C.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          info.description,
                          style: _T.body,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    // Synergy line
                    Row(
                      children: [
                        const Icon(
                          Icons.bolt_rounded,
                          size: 11,
                          color: _C.amberBright,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
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
                Icons.map_outlined,
                'POSITION',
                'Place guardians at optimal chokepoints before combat begins',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                Icons.waves_rounded,
                'ESCALATION',
                'Each wave amplifies enemy density and elite spawn rates',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTacticTile(
                Icons.science_outlined,
                'ALCHEMICAL',
                'Mutate and empower your creatures between waves',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTacticTile(
                Icons.swap_vert_rounded,
                'RESERVES',
                'Rotate bench units into the field via Deploy choices',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTacticTile(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg2,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: _C.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _C.amber, size: 14),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: _C.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: _T.body.copyWith(fontSize: 11),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // GAME VIEW
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGameView(FactionTheme theme) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Particle background — dimmed so it doesn't distract from gameplay
          const ColoredBox(color: _C.bg0),
          const AlchemicalParticleBackground(opacity: 0.35),
          // Dark vignette so arena edges feel grounded
          Container(color: Colors.black.withOpacity(0.2)),
          GameWidget(
            game: _game!,
            backgroundBuilder: (context) =>
                Container(color: Colors.transparent),
          ),
          if (_game != null) _buildAlchemyOverlay(),
          // Stats HUD + speed — top right (hidden while guardian details are open)
          ValueListenableBuilder(
            valueListenable: _game!.selectedGuardianNotifier,
            builder: (context, selectedGuardian, child) {
              if (selectedGuardian != null) return const SizedBox.shrink();
              return child!;
            },
            child: Align(
              alignment: Alignment.topRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, right: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildHUD(),
                      const SizedBox(height: 6),
                      _buildSpeedButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Back — top left (hidden while guardian details are open)
          ValueListenableBuilder(
            valueListenable: _game!.selectedGuardianNotifier,
            builder: (context, selectedGuardian, child) {
              if (selectedGuardian != null) return const SizedBox.shrink();
              return child!;
            },
            child: Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: _buildBackButton(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return ValueListenableBuilder<SurvivalGameStats>(
      valueListenable: _game!.statsNotifier,
      builder: (context, stats, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _C.bg0.withOpacity(0.88),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: _C.borderDim),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHUDCell('WAVE', '${stats.wave}', _C.danger),
              _buildHUDDivider(),
              _buildHUDCell('TIME', stats.formattedTime, _C.textPrimary),
              _buildHUDDivider(),
              _buildHUDCell('SCORE', stats.score.toString(), _C.amberBright),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHUDCell(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: _T.stat.copyWith(color: valueColor, fontSize: 14)),
          const SizedBox(height: 2),
          Text(label, style: _T.label),
        ],
      ),
    );
  }

  Widget _buildHUDDivider() {
    return Container(width: 1, height: 28, color: _C.borderDim);
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (ctx) => _ConfirmExitDialog(
          onConfirm: () {
            Navigator.pop(ctx);
            Navigator.pop(context);
          },
          onCancel: () => Navigator.pop(ctx),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _C.bg0.withOpacity(0.88),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _C.borderDim),
        ),
        child: const Icon(
          Icons.arrow_back_rounded,
          color: _C.textSecondary,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildSpeedButton() {
    return GestureDetector(
      onTap: () {
        final game = _game;
        if (game == null) return;
        setState(() => _isSpeedUpEnabled = !_isSpeedUpEnabled);
        game.setSimulationSpeed(_isSpeedUpEnabled ? 2.0 : 1.0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: _isSpeedUpEnabled
              ? _C.amber.withOpacity(0.2)
              : _C.bg0.withOpacity(0.88),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _isSpeedUpEnabled ? _C.amber : _C.borderDim,
            width: _isSpeedUpEnabled ? 1.5 : 1,
          ),
        ),
        child: Text(
          _isSpeedUpEnabled ? '2×' : '1×',
          style: TextStyle(
            fontFamily: 'monospace',
            color: _isSpeedUpEnabled ? _C.amberBright : _C.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildAlchemyOverlay() {
    return ValueListenableBuilder<AlchemyChoiceState?>(
      valueListenable: _game!.alchemyChoiceNotifier,
      builder: (context, state, _) {
        if (state == null) return const SizedBox.shrink();
        return Container(
          color: Colors.black.withOpacity(0.78),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: _C.bg1,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _C.borderAccent),
                boxShadow: [
                  BoxShadow(
                    color: _C.amber.withOpacity(0.15),
                    blurRadius: 32,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _C.borderDim)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _C.amberDim.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: _C.borderAccent),
                          ),
                          child: const Icon(
                            Icons.science_rounded,
                            color: _C.amberBright,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ALCHEMICAL SURGE', style: _T.heading),
                            SizedBox(height: 1),
                            Text(
                              'SELECT ENHANCEMENT PROTOCOL',
                              style: _T.label,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Options
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: state.options
                          .map(
                            (opt) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _AlchemyOptionTile(
                                option: opt,
                                onTap: () => _game!.applyAlchemyChoice(opt),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// ALCHEMY OPTION TILE
// ──────────────────────────────────────────────────────────────────────────────

class _AlchemyOptionTile extends StatefulWidget {
  final dynamic option;
  final VoidCallback onTap;
  const _AlchemyOptionTile({required this.option, required this.onTap});
  @override
  State<_AlchemyOptionTile> createState() => _AlchemyOptionTileState();
}

class _AlchemyOptionTileState extends State<_AlchemyOptionTile> {
  bool _pressed = false;

  Color _getColor() {
    final label = widget.option.label as String;
    if (label.contains('Transmute')) return const Color(0xFF7E57C2);
    if (label.contains('Empower')) return const Color(0xFFEF5350);
    if (label.contains('Deploy')) return _C.teal;
    return const Color(0xFF26A69A);
  }

  IconData _getIcon() {
    final label = widget.option.label as String;
    if (label.contains('Transmute')) return Icons.swap_horiz_rounded;
    if (label.contains('Empower')) return Icons.bolt_rounded;
    if (label.contains('Deploy')) return Icons.add_circle_outline_rounded;
    return Icons.favorite_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final c = _getColor();
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? c.withOpacity(0.15) : _C.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: _pressed ? c.withOpacity(0.8) : c.withOpacity(0.35),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: c.withOpacity(0.4)),
              ),
              child: Icon(_getIcon(), color: c, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (widget.option.label as String).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: c,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.option.description as String,
                    style: _T.body.copyWith(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: c.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Icon(Icons.chevron_right_rounded, color: c, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// GAME OVER DIALOG
// ──────────────────────────────────────────────────────────────────────────────

class _GameOverDialog extends StatelessWidget {
  final int wave;
  final double timeElapsed;
  final int score;
  final int kills;
  final String lootRewardLabel;
  final List<String> lootRewardDetails;
  final String currencyRewardLabel;
  final List<String> currencyRewardDetails;
  final bool isNewRecord;
  final int? prevBestWave;
  final int? prevBestScore;
  final VoidCallback onRedeploy;
  final VoidCallback onNewTeam;
  final VoidCallback onExit;

  const _GameOverDialog({
    required this.wave,
    required this.timeElapsed,
    required this.score,
    required this.kills,
    required this.lootRewardLabel,
    required this.lootRewardDetails,
    required this.currencyRewardLabel,
    required this.currencyRewardDetails,
    required this.isNewRecord,
    this.prevBestWave,
    this.prevBestScore,
    required this.onRedeploy,
    required this.onNewTeam,
    required this.onExit,
  });

  void _showLootDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  'LOOT DETAILS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (lootRewardDetails.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No loot recorded.', style: _T.body),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: lootRewardDetails
                        .map(
                          (entry) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _C.bg2,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _C.borderDim),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.inventory_2_outlined,
                                  color: _C.amber,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry,
                                    style: _T.body.copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _ForgeButton(
                  label: 'Close',
                  icon: Icons.check_rounded,
                  onTap: () => Navigator.of(context).pop(),
                  secondary: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                  'CURRENCY DETAILS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: _C.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (currencyRewardDetails.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('No bonus currency recorded.', style: _T.body),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: currencyRewardDetails
                        .map(
                          (entry) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _C.bg2,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: _C.borderDim),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.monetization_on_outlined,
                                  color: _C.teal,
                                  size: 14,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry,
                                    style: _T.body.copyWith(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: _ForgeButton(
                  label: 'Close',
                  icon: Icons.check_rounded,
                  onTap: () => Navigator.of(context).pop(),
                  secondary: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double s) {
    final m = (s / 60).floor();
    final sec = (s % 60).floor();
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        decoration: BoxDecoration(
          color: _C.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _C.borderAccent),
          boxShadow: [
            BoxShadow(
              color: _C.amber.withOpacity(0.12),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // — Header strip —
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _C.borderDim)),
              ),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ORB DESTROYED',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: _C.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text('FIELD REPORT', style: _T.label),
                    ],
                  ),
                ],
              ),
            ),
            // — NEW RECORD banner —
            if (isNewRecord)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _C.amberBright.withOpacity(0.12),
                  border: const Border(
                    bottom: BorderSide(color: _C.borderAccent),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.emoji_events_rounded,
                      color: _C.amberBright,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'NEW HIGH SCORE',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: _C.amberBright,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
            // — Stat grid —
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'WAVE',
                          value: '$wave',
                          color: _C.danger,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCell(
                          label: 'TIME',
                          value: _formatTime(timeElapsed),
                          color: _C.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCell(
                          label: 'SCORE',
                          value: _formatNumber(score),
                          color: _C.amberBright,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCell(
                          label: 'ELIMINATIONS',
                          value: _formatNumber(kills),
                          color: _C.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Loot row
                  _RewardRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'LOOT',
                    value: lootRewardLabel,
                    color: _C.amber,
                    onTap: () => _showLootDetailsDialog(context),
                  ),
                  const SizedBox(height: 6),
                  _RewardRow(
                    icon: Icons.monetization_on_outlined,
                    label: 'CURRENCY',
                    value: currencyRewardLabel,
                    color: _C.teal,
                    onTap: () => _showCurrencyDetailsDialog(context),
                  ),
                  // — Previous best —
                  if (!isNewRecord &&
                      prevBestWave != null &&
                      prevBestWave! > 0) ...[
                    const SizedBox(height: 6),
                    _RewardRow(
                      icon: Icons.emoji_events_outlined,
                      label: 'PREV BEST',
                      value:
                          'W$prevBestWave  •  ${_formatNumber(prevBestScore ?? 0)}',
                      color: _C.textSecondary,
                    ),
                  ],
                ],
              ),
            ),
            // — Actions —
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  _ForgeButton(
                    label: 'Redeploy',
                    icon: Icons.replay_rounded,
                    onTap: onRedeploy,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _ForgeButton(
                          label: 'New Team',
                          icon: Icons.groups_rounded,
                          onTap: onNewTeam,
                          secondary: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ForgeButton(
                          label: 'Exit',
                          icon: Icons.exit_to_app_rounded,
                          onTap: onExit,
                          secondary: true,
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
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _T.label.copyWith(color: color.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(value, style: _T.stat.copyWith(color: color, fontSize: 18)),
        ],
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;
  const _RewardRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _C.bg2,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: _C.borderDim),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 8),
            Text('$label  ', style: _T.label),
            Expanded(
              child: Text(
                value,
                style: _T.body.copyWith(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.info_outline_rounded,
                color: _C.textMuted,
                size: 14,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// CONFIRM EXIT DIALOG
// ──────────────────────────────────────────────────────────────────────────────

class _ConfirmExitDialog extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _ConfirmExitDialog({required this.onConfirm, required this.onCancel});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: _C.bg1,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _C.borderAccent),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ABANDON FIELD?',
              style: TextStyle(
                fontFamily: 'monospace',
                color: _C.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All wave progress will be lost. Relics already earned are kept.',
              style: _T.body,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _ForgeButton(
                    label: 'Abandon',
                    icon: Icons.exit_to_app_rounded,
                    onTap: onConfirm,
                    secondary: true,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ForgeButton(
                    label: 'Hold',
                    icon: Icons.shield_rounded,
                    onTap: onCancel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// SCANLINE PAINTER
// ──────────────────────────────────────────────────────────────────────────────

class _ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.08);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ──────────────────────────────────────────────────────────────────────────────
// FAMILY INFO DATA (unchanged structure, just data)
// ──────────────────────────────────────────────────────────────────────────────

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

const List<_FamilyInfo> _familyInfos = [
  _FamilyInfo(
    id: 'Let',
    name: 'Let',
    role: 'Meteor Caster',
    description:
        'Drops heavy AoE meteors to erase clustered waves. Shines in swarm and boss add phases.',
    bestPowerups: 'Int Transmute, Empower Meteor, Extra Deploy',
    assetPath: 'assets/images/creatures/common/LET02_waterlet.png',
    color: Color(0xFF3B82F6),
  ),
  _FamilyInfo(
    id: 'Pip',
    name: 'Pip',
    role: 'Ricochet Marksman',
    description:
        'Projectiles bounce between enemies, turning tight packs into free value.',
    bestPowerups: 'Speed/Int Transmute, Empower Ricochet',
    assetPath: 'assets/images/creatures/uncommon/PIP06_lavapip.png',
    color: Color(0xFFF59E0B),
  ),
  _FamilyInfo(
    id: 'Mane',
    name: 'Mane',
    role: 'Barrage DPS',
    description:
        'Rapid-fire elemental volleys in a cone. Shreds clustered enemies with sustained damage.',
    bestPowerups: 'Speed/Beauty Transmute, Empower Barrage',
    assetPath: 'assets/images/creatures/uncommon/MAN03_earthmane.png',
    color: Color(0xFFEF4444),
  ),
  _FamilyInfo(
    id: 'Mask',
    name: 'Mask',
    role: 'Trap Specialist',
    description:
        'Deploys elemental trap fields on contact. Great for choke points and area denial.',
    bestPowerups: 'Int/Beauty Transmute, Empower Traps, Extra Deploy',
    assetPath: 'assets/images/creatures/rare/MSK01_firemask.png',
    color: Color(0xFF8B5CF6),
  ),
  _FamilyInfo(
    id: 'Horn',
    name: 'Horn',
    role: 'Frontline Tank',
    description:
        'Bulky guardians that hold the line with protective Novas. Knocks enemies back.',
    bestPowerups: 'HP Transmute, Extra Deploy, Empower Nova',
    assetPath: 'assets/images/creatures/rare/HOR13_poisonhorn.png',
    color: Color(0xFF10B981),
  ),
  _FamilyInfo(
    id: 'Wing',
    name: 'Wing',
    role: 'Agile Ranged DPS',
    description:
        'Fast fliers that shred from a distance. Excel at focusing priorities and kiting elites.',
    bestPowerups: 'Speed & Int Transmute, Empower Special',
    assetPath: 'assets/images/creatures/legendary/WNG03_earthwing.png',
    color: Color(0xFF06B6D4),
  ),
  _FamilyInfo(
    id: 'Kin',
    name: 'Kin',
    role: 'Healer & Support',
    description:
        'Restores your orb and allies, with powerful team-wide surges at higher ranks.',
    bestPowerups: 'Int/Beauty Transmute, Empower Heal',
    assetPath: 'assets/images/creatures/legendary/KIN01_firekin.png',
    color: Color(0xFFEC4899),
  ),
];
