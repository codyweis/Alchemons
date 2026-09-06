import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/potential_soul_sphere.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

/// What the tray is currently offering, and what a drag is carrying. Orbs and
/// Souls target the same sprite but cost different resources and take
/// different code paths, so the drop has to be able to tell them apart.
enum _InfusionKind { orb, soul }

@immutable
class _InfusionPayload {
  const _InfusionPayload(this.kind, this.type);

  final _InfusionKind kind;
  final AlchemicalPowerupType type;
}

class AlchemicalPowerupFeedingScreen extends StatefulWidget {
  const AlchemicalPowerupFeedingScreen({super.key});

  @override
  State<AlchemicalPowerupFeedingScreen> createState() =>
      _AlchemicalPowerupFeedingScreenState();
}

class _AlchemicalPowerupFeedingScreenState
    extends State<AlchemicalPowerupFeedingScreen>
    with TickerProviderStateMixin {
  static const int _requiredPowerupLevel = 10;

  int _enhancementRank(CreatureInstance instance, AlchemicalPowerupType type) =>
      switch (type) {
        AlchemicalPowerupType.speed => instance.statSpeedEnhancement,
        AlchemicalPowerupType.intelligence =>
          instance.statIntelligenceEnhancement,
        AlchemicalPowerupType.strength => instance.statStrengthEnhancement,
        AlchemicalPowerupType.beauty => instance.statBeautyEnhancement,
      };

  String? _selectedInstanceId;
  bool _busy = false;
  String? _message;
  AlchemicalPowerupType? _animatingType;
  AlchemicalPowerupType? _launchingType;
  double? _lastDelta;
  String? _lastRollLabel;
  double _glowBoost = 1.0;
  bool _jackpotAnimation = false;
  double _orbitTurns = 2.2;
  double _orbitEndProgress = 0.72;
  int? _potentialSoulRoll;
  bool _powerupTutorialChecked = false;
  Map<AlchemicalPowerupType, double>? _frozenStatValues;
  Map<AlchemicalPowerupType, double>? _frozenPotentialValues;

  // Drag-to-infuse state. _draggingType drives the drop-target affordance;
  // the hint anchors are measured off real geometry so the coach mark points
  // at the actual orb and the actual sprite rather than guessed fractions.
  AlchemicalPowerupType? _draggingType;
  _InfusionKind? _draggingKind;
  bool _traySoulMode = false;
  bool _dragHintChecked = false;
  bool _dragHintVisible = false;
  Offset? _hintFrom;
  Offset? _hintTo;
  final GlobalKey _chamberKey = GlobalKey();
  final GlobalKey _spriteKey = GlobalKey();
  final GlobalKey _orbRowKey = GlobalKey();

  late final AnimationController _orbController;
  late final AnimationController _flashController;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowPowerupTutorial();
    });
  }

  Future<void> _maybeShowPowerupTutorial() async {
    if (_powerupTutorialChecked || !mounted) return;
    _powerupTutorialChecked = true;

    final db = context.read<AlchemonsDatabase>();
    final settings = db.settingsDao;
    final hasSeen = await settings.hasSeenPowerupFeedingTutorial();
    if (hasSeen || !mounted) return;

    final theme = context.read<FactionTheme>();
    final t = ForgeTokens(theme);

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          backgroundColor: t.bg2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: t.borderDim),
          ),
          title: Text(
            'Stat Infusion Basics',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Power Orbs improve trained stats, while rare Potential Souls improve inheritable genetics. Both let you choose the stat you want to develop.',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: AppIcons.workspace_premium_rounded,
                title: 'Step 0 - Reach Level 10',
                body:
                    'A specimen must be level 10 before it can use powerup orbs.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: AppIcons.diamond_rounded,
                title: 'Potential Souls',
                body:
                    'Choose any Potential below 100. One Soul permanently raises that selected Potential, and the improved value can pass through breeding. Its exact Silver cost is shown before infusion.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: AppIcons.trending_up_rounded,
                title: 'Step 1 - Drag an Orb onto the specimen',
                body:
                    'Drag a Power Orb from the tray onto your Alchemon to infuse it. Each infusion raises that stat by one rank, up to Enhancement 10/10. Every rank adds +3%.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: AppIcons.shield_rounded,
                title: 'Step 2 - Plan Orb Costs',
                body:
                    'Higher Enhancement ranks cost more Orbs. Combat constellation infusions instead raise their matching combat stat by 1% per rank. Potential remains the specimen\'s inherited 1–100 genetic quality.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
              child: Text(
                'Got it',
                style: TextStyle(color: t.amber, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      await settings.setPowerupFeedingTutorialSeen();
    }
  }

  @override
  void dispose() {
    _orbController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<FactionTheme>();
    final t = ForgeTokens(theme);

    return Scaffold(
      backgroundColor: t.bg0,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [t.bg1, t.bg0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _PowerupHeader(
                  theme: theme,
                  canGoBack: _selectedInstanceId != null,
                  onBack: () {
                    HapticFeedback.lightImpact();
                    if (_selectedInstanceId == null) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() {
                        _selectedInstanceId = null;
                        _message = null;
                        _lastDelta = null;
                        _frozenStatValues = null;
                        _frozenPotentialValues = null;
                      });
                    }
                  },
                  onChooseDifferent: _selectedInstanceId == null
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedInstanceId = null;
                            _frozenStatValues = null;
                            _frozenPotentialValues = null;
                          });
                        },
                ),
                Expanded(
                  child: _selectedInstanceId == null
                      ? _buildSelector(theme)
                      : _buildFeedingChamber(theme),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector(FactionTheme theme) {
    final t = ForgeTokens(theme);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: t.bg2,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: t.borderDim),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 28,
                  color: t.amber,
                  margin: const EdgeInsets.only(right: 10),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT SPECIMEN',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.amberBright,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose any specimen for Potential infusion. Power Orb Enhancement unlocks at level 10.',
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AllCreatureInstances(
            theme: theme,
            prefsScopeKey: 'powerup_feed_select',
            selectedInstanceIds: const [],
            onTap: (inst) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedInstanceId = inst.instanceId;
                _message = null;
                _lastDelta = null;
                _frozenStatValues = null;
                _frozenPotentialValues = null;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeedingChamber(FactionTheme theme) {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();

    return StreamBuilder<CreatureInstance?>(
      stream: db.creatureDao.watchInstanceById(_selectedInstanceId!),
      builder: (context, snapshot) {
        final instance = snapshot.data;
        if (instance == null) {
          return Center(
            child: Text(
              'Specimen unavailable',
              style: TextStyle(color: ForgeTokens(theme).textSecondary),
            ),
          );
        }
        final creature = repo.getCreatureById(instance.baseId);
        if (creature == null) {
          return Center(
            child: Text(
              'Unknown species',
              style: TextStyle(color: ForgeTokens(theme).textSecondary),
            ),
          );
        }

        return StreamBuilder<List<InventoryItem>>(
          stream: db.inventoryDao.watchItemInventory(),
          builder: (context, invSnap) {
            final inventory = <String, int>{
              for (final item in invSnap.data ?? const <InventoryItem>[])
                item.key: item.qty,
            };

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeShowDragHint();
            });

            // Silver is lifted to wrap the whole chamber: the sprite needs it
            // to decide whether a Soul drop can be accepted, not just the tray.
            return StreamBuilder<int>(
              stream: db.currencyDao.watchSilverBalance(),
              builder: (context, silverSnap) {
                final silverBalance = silverSnap.data ?? 0;
                return Stack(
                  key: _chamberKey,
                  children: [
                    Column(
                      children: [
                        // Capped so the specimen card stops absorbing every spare
                        // pixel on tall displays and crowding the orbs — the only
                        // thing this screen actually asks you to act on.
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 440,
                                ),
                                child: _buildStageCard(
                                  creature,
                                  instance,
                                  inventory,
                                  silverBalance,
                                  theme,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: _buildMessageBox(theme),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                          child: _buildPowerupGrid(
                            instance,
                            inventory,
                            silverBalance,
                            theme,
                          ),
                        ),
                      ],
                    ),
                    if (_dragHintVisible &&
                        _hintFrom != null &&
                        _hintTo != null)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _DragHintOverlay(
                            from: _hintFrom!,
                            to: _hintTo!,
                            theme: theme,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMessageBox(FactionTheme theme) {
    final t = ForgeTokens(theme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderAccent.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 28,
            color: t.amber,
            margin: const EdgeInsets.only(right: 10),
          ),
          Expanded(
            child: Text(
              _message ?? '',
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageCard(
    Creature creature,
    CreatureInstance instance,
    Map<String, int> inventory,
    int silverBalance,
    FactionTheme theme,
  ) {
    final t = ForgeTokens(theme);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          creature.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        creature.rarity.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final spriteSize = constraints.maxHeight.clamp(
                          100.0,
                          240.0,
                        );
                        return DragTarget<_InfusionPayload>(
                          onWillAcceptWithDetails: (details) =>
                              switch (details.data.kind) {
                                _InfusionKind.orb => _canApplyPowerup(
                                  instance,
                                  inventory,
                                  details.data.type,
                                ),
                                _InfusionKind.soul => _canApplySoul(
                                  instance,
                                  inventory,
                                  silverBalance,
                                  details.data.type,
                                ),
                              },
                          onAcceptWithDetails: (details) {
                            HapticFeedback.mediumImpact();
                            switch (details.data.kind) {
                              case _InfusionKind.orb:
                                _applyPowerup(instance, details.data.type);
                              case _InfusionKind.soul:
                                _confirmSoulInfusion(
                                  instance,
                                  details.data.type,
                                  theme,
                                );
                            }
                          },
                          builder: (context, candidate, rejected) {
                            final hovering = candidate.isNotEmpty;
                            // A drag is in flight but this orb cannot land here —
                            // say so rather than letting the drop fail silently.
                            final refusing = rejected.isNotEmpty;
                            // Armed the moment a drag starts, so the destination
                            // announces itself before you reach it.
                            final armed = _draggingType != null;
                            final ringColor = hovering
                                ? (candidate.first?.type.color ?? t.amber)
                                : refusing
                                ? t.danger
                                : _draggingKind == _InfusionKind.soul
                                ? const Color(0xFFCF9BFF)
                                : (_draggingType?.color ?? t.amber);
                            final ringAlpha = hovering
                                ? 0.85
                                : refusing
                                ? 0.5
                                : 0.3;
                            return Stack(
                              key: _spriteKey,
                              alignment: Alignment.center,
                              children: [
                                if (hovering || refusing || armed)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 140,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: ringColor.withValues(
                                              alpha: ringAlpha,
                                            ),
                                            width: 2,
                                          ),
                                          boxShadow: hovering
                                              ? [
                                                  BoxShadow(
                                                    color: ringColor.withValues(
                                                      alpha: 0.45,
                                                    ),
                                                    blurRadius: 26,
                                                    spreadRadius: 2,
                                                  ),
                                                ]
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 140),
                                    scale: hovering ? 1.06 : 1.0,
                                    child: InstanceSprite(
                                      creature: creature,
                                      instance: instance,
                                      size: spriteSize,
                                    ),
                                  ),
                                ),
                                if (_animatingType != null)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedBuilder(
                                        animation: Listenable.merge([
                                          _orbController,
                                          _flashController,
                                        ]),
                                        builder: (context, _) => CustomPaint(
                                          painter: _PowerOrbPainter(
                                            progress: _orbController.value,
                                            flash: _flashController.value,
                                            color: _animatingType!.color,
                                            glowColor:
                                                _animatingType!.glowColor,
                                            rollLabel: _lastRollLabel,
                                            glowBoost: _glowBoost,
                                            isJackpot: _jackpotAnimation,
                                            orbitTurns: _orbitTurns,
                                            orbitEndProgress: _orbitEndProgress,
                                            soulRoll: _potentialSoulRoll,
                                            deltaLabel: _lastDelta == null
                                                ? null
                                                : _potentialSoulRoll == null
                                                ? '+${_lastDelta!.round()}%'
                                                : '+${_lastDelta!.round()} POTENTIAL',
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Container(height: 1, color: t.borderDim),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _StatPlate(
                          theme: theme,
                          label: 'Speed',
                          value: _displayStatValue(
                            instance,
                            AlchemicalPowerupType.speed,
                          ),
                          potential: _displayPotentialValue(
                            instance,
                            AlchemicalPowerupType.speed,
                          ),
                          enhancementRank: instance.statSpeedEnhancement,
                          color: AlchemicalPowerupType.speed.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatPlate(
                          theme: theme,
                          label: 'Intelligence',
                          value: _displayStatValue(
                            instance,
                            AlchemicalPowerupType.intelligence,
                          ),
                          potential: _displayPotentialValue(
                            instance,
                            AlchemicalPowerupType.intelligence,
                          ),
                          enhancementRank: instance.statIntelligenceEnhancement,
                          color: AlchemicalPowerupType.intelligence.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _StatPlate(
                          theme: theme,
                          label: 'Strength',
                          value: _displayStatValue(
                            instance,
                            AlchemicalPowerupType.strength,
                          ),
                          potential: _displayPotentialValue(
                            instance,
                            AlchemicalPowerupType.strength,
                          ),
                          enhancementRank: instance.statStrengthEnhancement,
                          color: AlchemicalPowerupType.strength.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _StatPlate(
                          theme: theme,
                          label: 'Beauty',
                          value: _displayStatValue(
                            instance,
                            AlchemicalPowerupType.beauty,
                          ),
                          potential: _displayPotentialValue(
                            instance,
                            AlchemicalPowerupType.beauty,
                          ),
                          enhancementRank: instance.statBeautyEnhancement,
                          color: AlchemicalPowerupType.beauty.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerupGrid(
    CreatureInstance instance,
    Map<String, int> inventory,
    int silverBalance,
    FactionTheme theme,
  ) {
    final t = ForgeTokens(theme);
    final soulQty = inventory[InvKeys.potentialSoul] ?? 0;
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
            decoration: BoxDecoration(
              color: t.bg3,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
              border: Border(bottom: BorderSide(color: t.borderDim)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  color: t.amber,
                  margin: const EdgeInsets.only(right: 8),
                ),
                Expanded(
                  child: Text(
                    _traySoulMode ? 'POTENTIAL SOULS' : 'POWER ORBS',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.amberBright,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                // The tray swaps contents rather than stacking both kinds, so
                // Souls get the same full-width treatment Orbs always had.
                _TraySwitch(
                  soulMode: _traySoulMode,
                  soulQty: soulQty,
                  theme: theme,
                  onChanged: (soul) {
                    if (_busy || soul == _traySoulMode) return;
                    HapticFeedback.selectionClick();
                    setState(() => _traySoulMode = soul);
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
            child: _traySoulMode
                ? _buildSoulRow(instance, soulQty, silverBalance, theme)
                : _buildOrbRow(instance, inventory, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildOrbRow(
    CreatureInstance instance,
    Map<String, int> inventory,
    FactionTheme theme,
  ) {
    return Row(
      key: _orbRowKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < AlchemicalPowerupType.values.length; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final type = AlchemicalPowerupType.values[i];
                final qty = inventory[type.inventoryKey] ?? 0;
                final rank = _enhancementRank(instance, type);
                final cost = AlchemonStatSystem.orbCostForNextRank(rank);
                final maxed = rank >= AlchemonStatSystem.maxEnhancementRank;
                final canUse = _canApplyPowerup(instance, inventory, type);
                return _AnimatedOrbButton(
                  type: type,
                  qty: qty,
                  requiredCost: cost,
                  costToMax: AlchemonStatSystem.orbCostToMaxRank(rank),
                  maxed: maxed,
                  canUse: canUse,
                  isLaunching: _launchingType == type,
                  theme: theme,
                  phaseDelay: Duration(milliseconds: i * 320),
                  onDragStarted: () {
                    HapticFeedback.selectionClick();
                    _dismissDragHint();
                    setState(() {
                      _draggingType = type;
                      _draggingKind = _InfusionKind.orb;
                    });
                  },
                  onDragFinished: () {
                    if (!mounted) return;
                    setState(() {
                      _draggingType = null;
                      _draggingKind = null;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSoulRow(
    CreatureInstance instance,
    int soulQty,
    int silverBalance,
    FactionTheme theme,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < AlchemicalPowerupType.values.length; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final type = AlchemicalPowerupType.values[i];
                final potential = _potentialFor(instance, type);
                final cost = _soulCostFor(instance, type);
                final maxed = potential >= AlchemonStatSystem.maxPotential;
                final canUse =
                    soulQty > 0 && !maxed && silverBalance >= cost && !_busy;
                return _SoulOrbButton(
                  type: type,
                  soulQty: soulQty,
                  potential: potential,
                  silverCost: cost,
                  affordable: silverBalance >= cost,
                  maxed: maxed,
                  canUse: canUse,
                  costLabel: _formatSilver(cost),
                  theme: theme,
                  phaseDelay: Duration(milliseconds: i * 320),
                  onDragStarted: () {
                    HapticFeedback.selectionClick();
                    _dismissDragHint();
                    setState(() {
                      _draggingType = type;
                      _draggingKind = _InfusionKind.soul;
                    });
                  },
                  onDragFinished: () {
                    if (!mounted) return;
                    setState(() {
                      _draggingType = null;
                      _draggingKind = null;
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  /// Single source of truth for "can this orb go in right now", shared by the
  /// orb tile (to arm the drag) and the sprite (to accept the drop).
  bool _canApplyPowerup(
    CreatureInstance instance,
    Map<String, int> inventory,
    AlchemicalPowerupType type,
  ) {
    final qty = inventory[type.inventoryKey] ?? 0;
    final rank = _enhancementRank(instance, type);
    return instance.level >= _requiredPowerupLevel &&
        rank < AlchemonStatSystem.maxEnhancementRank &&
        qty >= AlchemonStatSystem.orbCostForNextRank(rank) &&
        !_busy;
  }

  int _soulCostFor(CreatureInstance instance, AlchemicalPowerupType type) =>
      AlchemonStatSystem.potentialSoulSilverCost(_potentialFor(instance, type));

  bool _canApplySoul(
    CreatureInstance instance,
    Map<String, int> inventory,
    int silverBalance,
    AlchemicalPowerupType type,
  ) {
    final souls = inventory[InvKeys.potentialSoul] ?? 0;
    return souls > 0 &&
        _potentialFor(instance, type) < AlchemonStatSystem.maxPotential &&
        silverBalance >= _soulCostFor(instance, type) &&
        !_busy;
  }

  /// Souls burn 10k–50k Silver per use, so the drop confirms before spending.
  /// Orbs skip this: their cost is orbs you already earned, and it is printed
  /// on the tile you just dragged.
  Future<void> _confirmSoulInfusion(
    CreatureInstance instance,
    AlchemicalPowerupType type,
    FactionTheme theme,
  ) async {
    final t = ForgeTokens(theme);
    final cost = _soulCostFor(instance, type);
    final potential = _potentialFor(instance, type);
    final stat = type.statKey[0].toUpperCase() + type.statKey.substring(1);

    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: t.bg2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: t.borderAccent),
        ),
        title: Row(
          children: [
            PotentialSoulSphere(size: 30, tint: type.color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'INFUSE $stat'.toUpperCase(),
                style: TextStyle(
                  color: t.amberBright,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Raise $stat Potential from $potential/100 using one Potential Soul '
          'for ${_formatSilver(cost)} Silver. Potential cannot exceed 100.',
          style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel', style: TextStyle(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Infuse',
              style: TextStyle(
                color: t.amberBright,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );

    if (go == true && mounted) {
      await _applyPotentialSoul(instance, type);
    }
  }

  Future<void> _maybeShowDragHint() async {
    if (_dragHintChecked || !mounted) return;
    _dragHintChecked = true;

    final db = context.read<AlchemonsDatabase>();
    if (await db.settingsDao.hasSeenPowerupDragHint()) return;
    if (!mounted) return;

    // Measure after a frame so the sprite and orb row have real geometry.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _measureHintAnchors();
      if (!mounted || _hintFrom == null || _hintTo == null) return;
      setState(() => _dragHintVisible = true);
    });
  }

  void _measureHintAnchors() {
    final chamber =
        _chamberKey.currentContext?.findRenderObject() as RenderBox?;
    final sprite = _spriteKey.currentContext?.findRenderObject() as RenderBox?;
    final orbRow = _orbRowKey.currentContext?.findRenderObject() as RenderBox?;
    if (chamber == null || sprite == null || orbRow == null) return;
    if (!chamber.hasSize || !sprite.hasSize || !orbRow.hasSize) return;

    Offset toChamber(RenderBox box, Offset local) =>
        chamber.globalToLocal(box.localToGlobal(local));

    // The orbs share the row evenly, so the first one's centre is an eighth
    // of the way across; 34 is the middle of the 68px glow at the tile top.
    final rowOrigin = toChamber(orbRow, Offset.zero);
    _hintFrom = Offset(
      rowOrigin.dx + orbRow.size.width * 0.125,
      rowOrigin.dy + 34,
    );
    _hintTo = toChamber(sprite, sprite.size.center(Offset.zero));
  }

  void _dismissDragHint() {
    if (!_dragHintVisible) return;
    setState(() => _dragHintVisible = false);
    unawaited(
      context.read<AlchemonsDatabase>().settingsDao.setPowerupDragHintSeen(),
    );
  }

  int _potentialFor(CreatureInstance instance, AlchemicalPowerupType type) =>
      switch (type) {
        AlchemicalPowerupType.speed => instance.statSpeedPotential.round(),
        AlchemicalPowerupType.intelligence =>
          instance.statIntelligencePotential.round(),
        AlchemicalPowerupType.strength =>
          instance.statStrengthPotential.round(),
        AlchemicalPowerupType.beauty => instance.statBeautyPotential.round(),
      };

  Future<void> _applyPowerup(
    CreatureInstance instance,
    AlchemicalPowerupType type,
  ) async {
    if (_busy) return;

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    const animationDuration = Duration(milliseconds: 1500);
    const flashDuration = Duration(milliseconds: 500);

    _orbController.reset();
    _flashController.reset();
    final frozenStats = _snapshotStatValues(instance);

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _launchingType = type;
      _animatingType = null;
      _lastDelta = null;
      _lastRollLabel = null;
      _glowBoost = 1.0;
      _jackpotAnimation = false;
      _orbitTurns = 2.2;
      _orbitEndProgress = 0.72;
      _potentialSoulRoll = null;
      _frozenStatValues = frozenStats;
      _frozenPotentialValues = null;
      _message = null;
    });

    // Let the orb button animate out first
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    _orbController.duration = animationDuration;
    _flashController.duration = flashDuration;

    setState(() {
      _launchingType = null;
      _animatingType = type;
      _lastDelta = 3.0;
      _lastRollLabel = 'ENHANCING';
      _glowBoost = 1.0;
      _jackpotAnimation = false;
      _orbitTurns = 2.2;
      _orbitEndProgress = 0.72;
    });
    await _orbController.forward(from: 0);

    if (!mounted) return;
    await _flashController.forward(from: 0);
    HapticFeedback.heavyImpact();

    if (!mounted) return;
    final svc = CreatureInstanceService(db);
    final result = await svc.applyAlchemicalPowerup(
      targetInstanceId: instance.instanceId,
      powerup: type,
      repo: repo,
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _launchingType = null;
        _animatingType = null;
        _frozenStatValues = null;
        _frozenPotentialValues = null;
        _potentialSoulRoll = null;
        _orbitTurns = 2.2;
        _orbitEndProgress = 0.72;
        _message = result.error ?? 'Infusion failed.';
      });
      HapticFeedback.vibrate();
      return;
    }

    setState(() {
      _busy = false;
      _animatingType = null;
      _launchingType = null;
      _lastDelta = null;
      _lastRollLabel = null;
      _glowBoost = 1.0;
      _jackpotAnimation = false;
      _orbitTurns = 2.2;
      _orbitEndProgress = 0.72;
      _potentialSoulRoll = null;
      _frozenStatValues = null;
      _frozenPotentialValues = null;
      // No success banner: the infusion animation already calls the roll and
      // the stat plate updates in place, so a box restating it was noise.
      // Errors still surface through _message below.
    });
  }

  Future<void> _applyPotentialSoul(
    CreatureInstance instance,
    AlchemicalPowerupType type,
  ) async {
    if (_busy) return;

    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    _orbController.reset();
    _flashController.reset();
    final frozenStats = _snapshotStatValues(instance);
    final frozenPotentials = _snapshotPotentialValues(instance);

    HapticFeedback.mediumImpact();
    setState(() {
      _busy = true;
      _launchingType = null;
      _animatingType = null;
      _lastDelta = null;
      _lastRollLabel = 'AWAKENING';
      _potentialSoulRoll = null;
      _frozenStatValues = frozenStats;
      _frozenPotentialValues = frozenPotentials;
      _message = 'SOUL INFUSION: awakening ${type.statKey} Potential...';
    });

    // Resolve the atomic item/currency transaction first, but keep the old
    // values visually frozen until the reveal finishes. That lets the actual
    // roll—not a generic pre-roll effect—drive the celebration safely.
    final result = await CreatureInstanceService(db).applyPotentialSoul(
      targetInstanceId: instance.instanceId,
      stat: type,
      repo: repo,
    );
    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _animatingType = null;
        _frozenStatValues = null;
        _frozenPotentialValues = null;
        _lastRollLabel = null;
        _potentialSoulRoll = null;
        _message = result.error ?? 'Potential infusion failed.';
      });
      HapticFeedback.vibrate();
      return;
    }

    final reveal = _soulRevealProfile(result.rolledGain);
    _orbController.duration = reveal.orbDuration;
    _flashController.duration = reveal.flashDuration;
    setState(() {
      _animatingType = type;
      _lastDelta = result.appliedGain.toDouble();
      _lastRollLabel = reveal.label;
      _glowBoost = reveal.glowBoost;
      _jackpotAnimation = reveal.isJackpot;
      _orbitTurns = reveal.orbitTurns;
      _orbitEndProgress = reveal.orbitEndProgress;
      _potentialSoulRoll = result.rolledGain;
      _message = 'SOUL RESONANCE: revealing ${type.statKey} Potential...';
    });

    await _orbController.forward(from: 0);
    if (!mounted) return;
    await _flashController.forward(from: 0);
    if (!mounted) return;

    if (result.rolledGain >= 4) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
    final cappedNote = result.appliedGain < result.rolledGain
        ? ' (rolled +${result.rolledGain}, capped at 100)'
        : '';
    setState(() {
      _busy = false;
      _animatingType = null;
      _frozenStatValues = null;
      _frozenPotentialValues = null;
      _lastRollLabel = null;
      _lastDelta = null;
      _glowBoost = 1.0;
      _jackpotAnimation = false;
      _orbitTurns = 2.2;
      _orbitEndProgress = 0.72;
      _potentialSoulRoll = null;
      _message =
          'SOUL AWAKENED: +${result.appliedGain} ${type.statKey} Potential$cappedNote • ${result.newPotential}/100 • -${_formatSilver(result.silverCost)} Silver';
    });
  }

  ({
    String label,
    double glowBoost,
    bool isJackpot,
    double orbitTurns,
    double orbitEndProgress,
    Duration orbDuration,
    Duration flashDuration,
  })
  _soulRevealProfile(int rolledGain) => switch (rolledGain) {
    1 => (
      label: 'SOUL AWAKENED',
      glowBoost: 1.0,
      isJackpot: false,
      orbitTurns: 2.2,
      orbitEndProgress: 0.72,
      orbDuration: const Duration(milliseconds: 1300),
      flashDuration: const Duration(milliseconds: 420),
    ),
    2 => (
      label: 'SOUL STIRRING',
      glowBoost: 1.18,
      isJackpot: false,
      orbitTurns: 2.6,
      orbitEndProgress: 0.74,
      orbDuration: const Duration(milliseconds: 1450),
      flashDuration: const Duration(milliseconds: 520),
    ),
    3 => (
      label: 'SOUL RESONANCE',
      glowBoost: 1.45,
      isJackpot: false,
      orbitTurns: 3.2,
      orbitEndProgress: 0.78,
      orbDuration: const Duration(milliseconds: 1650),
      flashDuration: const Duration(milliseconds: 650),
    ),
    4 => (
      label: 'EXALTED SOUL',
      glowBoost: 1.8,
      isJackpot: true,
      orbitTurns: 4.0,
      orbitEndProgress: 0.82,
      orbDuration: const Duration(milliseconds: 1900),
      flashDuration: const Duration(milliseconds: 800),
    ),
    _ => (
      label: 'PERFECT AWAKENING',
      glowBoost: 2.25,
      isJackpot: true,
      orbitTurns: 5.0,
      orbitEndProgress: 0.86,
      orbDuration: const Duration(milliseconds: 2250),
      flashDuration: const Duration(milliseconds: 1000),
    ),
  };

  String _formatSilver(int value) => value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  double _displayStatValue(
    CreatureInstance instance,
    AlchemicalPowerupType type,
  ) {
    final frozenValue = _frozenStatValues?[type];
    if (frozenValue != null) return frozenValue;
    return switch (type) {
      AlchemicalPowerupType.speed => instance.statSpeed,
      AlchemicalPowerupType.intelligence => instance.statIntelligence,
      AlchemicalPowerupType.strength => instance.statStrength,
      AlchemicalPowerupType.beauty => instance.statBeauty,
    };
  }

  double _displayPotentialValue(
    CreatureInstance instance,
    AlchemicalPowerupType type,
  ) {
    final frozenValue = _frozenPotentialValues?[type];
    if (frozenValue != null) return frozenValue;
    return switch (type) {
      AlchemicalPowerupType.speed => instance.statSpeedPotential,
      AlchemicalPowerupType.intelligence => instance.statIntelligencePotential,
      AlchemicalPowerupType.strength => instance.statStrengthPotential,
      AlchemicalPowerupType.beauty => instance.statBeautyPotential,
    };
  }

  Map<AlchemicalPowerupType, double> _snapshotStatValues(
    CreatureInstance instance,
  ) {
    return <AlchemicalPowerupType, double>{
      AlchemicalPowerupType.speed: instance.statSpeed,
      AlchemicalPowerupType.intelligence: instance.statIntelligence,
      AlchemicalPowerupType.strength: instance.statStrength,
      AlchemicalPowerupType.beauty: instance.statBeauty,
    };
  }

  Map<AlchemicalPowerupType, double> _snapshotPotentialValues(
    CreatureInstance instance,
  ) {
    return <AlchemicalPowerupType, double>{
      AlchemicalPowerupType.speed: instance.statSpeedPotential,
      AlchemicalPowerupType.intelligence: instance.statIntelligencePotential,
      AlchemicalPowerupType.strength: instance.statStrengthPotential,
      AlchemicalPowerupType.beauty: instance.statBeautyPotential,
    };
  }
}

class _PowerupHeader extends StatelessWidget {
  final bool canGoBack;
  final VoidCallback onBack;
  final VoidCallback? onChooseDifferent;
  final FactionTheme theme;

  const _PowerupHeader({
    required this.canGoBack,
    required this.onBack,
    required this.theme,
    this.onChooseDifferent,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      decoration: BoxDecoration(
        color: t.bg1,
        border: Border(bottom: BorderSide(color: t.borderDim)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(7),
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderDim),
                ),
                child: Icon(
                  canGoBack ? AppIcons.arrow_back : AppIcons.close_rounded,
                  color: t.textPrimary,
                  size: 18,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STAT INFUSION',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    canGoBack
                        ? 'Drag an Orb onto your Alchemon'
                        : 'Select a specimen',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (onChooseDifferent != null)
              GestureDetector(
                onTap: onChooseDifferent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: t.bg2,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: t.borderDim),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        AppIcons.swap_horiz_rounded,
                        size: 13,
                        color: t.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CHANGE',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: t.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
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
}

/// Segmented ORBS / SOULS control in the tray header. Souls carry a count
/// badge so you can see whether the other tab is worth opening.
class _TraySwitch extends StatelessWidget {
  const _TraySwitch({
    required this.soulMode,
    required this.soulQty,
    required this.theme,
    required this.onChanged,
  });

  final bool soulMode;
  final int soulQty;
  final FactionTheme theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: t.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(t, label: 'ORBS', selected: !soulMode, badge: null),
          _segment(t, label: 'SOULS', selected: soulMode, badge: soulQty),
        ],
      ),
    );
  }

  Widget _segment(
    ForgeTokens t, {
    required String label,
    required bool selected,
    required int? badge,
  }) {
    final soulTab = badge != null;
    final accent = soulTab ? const Color(0xFFCF9BFF) : t.amberBright;
    return GestureDetector(
      onTap: () => onChanged(soulTab),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.7)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                color: selected ? accent : t.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            if (soulTab) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: badge > 0 ? accent.withValues(alpha: 0.22) : t.bg3,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: badge > 0 ? accent : t.textMuted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One draggable Potential Soul, bound to a specific stat. The stat is chosen
/// by which sphere you drag rather than by a dialog after the fact.
class _SoulOrbButton extends StatefulWidget {
  const _SoulOrbButton({
    required this.type,
    required this.soulQty,
    required this.potential,
    required this.silverCost,
    required this.affordable,
    required this.maxed,
    required this.canUse,
    required this.costLabel,
    required this.theme,
    required this.phaseDelay,
    required this.onDragStarted,
    required this.onDragFinished,
  });

  final AlchemicalPowerupType type;
  final int soulQty;
  final int potential;
  final int silverCost;
  final bool affordable;
  final bool maxed;
  final bool canUse;
  final String costLabel;
  final FactionTheme theme;
  final Duration phaseDelay;
  final VoidCallback onDragStarted;
  final VoidCallback onDragFinished;

  @override
  State<_SoulOrbButton> createState() => _SoulOrbButtonState();
}

class _SoulOrbButtonState extends State<_SoulOrbButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _float = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future<void>.delayed(widget.phaseDelay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _caption(ForgeTokens t, {required bool ghost}) {
    final type = widget.type;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.maxed
                ? t.bg3
                : widget.affordable
                ? type.color.withValues(alpha: 0.16)
                : t.bg3,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: !widget.maxed && widget.affordable
                  ? type.color.withValues(alpha: 0.55)
                  : t.borderDim,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.maxed ? 'MAX' : widget.costLabel,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'monospace',
                color: !widget.maxed && widget.affordable
                    ? type.color
                    : t.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              type.statKey.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          ghost ? 'DRAGGING' : 'P${widget.potential}/100',
          style: TextStyle(
            fontFamily: 'monospace',
            color: ghost
                ? type.color
                : widget.maxed
                ? t.amberBright
                : t.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        if (!ghost)
          Text(
            'SILVER',
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textMuted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    final canUse = widget.canUse;

    return LayoutBuilder(
      builder: (context, constraints) {
        final orbSize = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(34.0, 64.0)
            : 64.0;

        final tile = AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: canUse ? 1.0 : 0.32,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) => Transform.translate(
                    offset: Offset(0, _float.value * 4.5),
                    child: PotentialSoulSphere(
                      size: orbSize,
                      tint: widget.type.color,
                    ),
                  ),
                ),
                _caption(t, ghost: false),
              ],
            ),
          ),
        );

        if (!canUse) return tile;

        return Draggable<_InfusionPayload>(
          data: _InfusionPayload(_InfusionKind.soul, widget.type),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: widget.onDragStarted,
          onDragEnd: (_) => widget.onDragFinished(),
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: PotentialSoulSphere(
              size: orbSize * 1.18,
              tint: widget.type.color,
            ),
          ),
          childWhenDragging: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.type.color.withValues(alpha: 0.06),
                    border: Border.all(
                      color: widget.type.color.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                ),
                _caption(t, ghost: true),
              ],
            ),
          ),
          child: tile,
        );
      },
    );
  }
}

class _AnimatedOrbButton extends StatefulWidget {
  final AlchemicalPowerupType type;
  final int qty;
  final int requiredCost;
  final int costToMax;
  final bool maxed;
  final bool canUse;
  final bool isLaunching;
  final FactionTheme theme;
  final Duration phaseDelay;
  final VoidCallback onDragStarted;
  final VoidCallback onDragFinished;

  const _AnimatedOrbButton({
    required this.type,
    required this.qty,
    required this.requiredCost,
    required this.costToMax,
    required this.maxed,
    required this.canUse,
    required this.isLaunching,
    required this.theme,
    required this.phaseDelay,
    required this.onDragStarted,
    required this.onDragFinished,
  });

  @override
  State<_AnimatedOrbButton> createState() => _AnimatedOrbButtonState();
}

class _AnimatedOrbButtonState extends State<_AnimatedOrbButton>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final AnimationController _launchCtrl;
  late final Animation<double> _float;
  late final Animation<double> _pulse;
  late final Animation<double> _launchT;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _launchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    _float = Tween<double>(
      begin: -1.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _pulse = Tween<double>(
      begin: 0.93,
      end: 1.07,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _launchT = CurvedAnimation(parent: _launchCtrl, curve: Curves.easeIn);
    Future<void>.delayed(widget.phaseDelay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void didUpdateWidget(_AnimatedOrbButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLaunching && !oldWidget.isLaunching) {
      _launchCtrl.forward(from: 0);
    } else if (!widget.isLaunching && oldWidget.isLaunching) {
      _launchCtrl.reset();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _launchCtrl.dispose();
    super.dispose();
  }

  /// The glow sphere, shared by the tile and the drag feedback so the thing
  /// under your finger is visibly the same object you picked up.
  Widget _orb(double size, {required bool lit}) {
    final type = widget.type;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.94),
            type.color.withValues(alpha: 0.88),
            type.glowColor.withValues(alpha: 0.36),
            Colors.transparent,
          ],
          stops: const [0.0, 0.30, 0.66, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: type.glowColor.withValues(
              alpha: lit ? 0.50 + _pulse.value * 0.08 : 0.18,
            ),
            blurRadius: lit ? 24 : 10,
            spreadRadius: lit ? 1 : -6,
          ),
        ],
      ),
    );
  }

  Widget _caption(ForgeTokens t, {required bool ghost}) {
    final type = widget.type;
    final affordable = !widget.maxed && widget.qty >= widget.requiredCost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        // Cost is the number that decides the drag, so it carries the weight.
        // Owned count and the run to max sit under it.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: affordable ? type.color.withValues(alpha: 0.16) : t.bg3,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: affordable
                  ? type.color.withValues(alpha: 0.55)
                  : t.borderDim,
            ),
          ),
          child: Text(
            widget.maxed ? 'MAXED' : 'COST ${widget.requiredCost}',
            style: TextStyle(
              fontFamily: 'monospace',
              color: affordable ? type.color : t.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 5),
        // FittedBox keeps INTELLIGENCE on one line instead of breaking it
        // mid-word at narrow widths.
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              type.statKey.toUpperCase(),
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontFamily: 'monospace',
                color: t.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          ghost ? 'DRAGGING' : '${widget.qty} owned',
          style: TextStyle(
            fontFamily: 'monospace',
            color: ghost ? type.color : t.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        if (!widget.maxed && !ghost)
          Text(
            '${widget.costToMax} to max',
            style: TextStyle(
              fontFamily: 'monospace',
              color: widget.qty >= widget.costToMax
                  ? type.color.withValues(alpha: 0.85)
                  : t.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    final canUse = widget.canUse;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The orbs share the row width evenly, so the glow has to shrink on
        // narrow handsets instead of overflowing its slot.
        final orbSize = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(34.0, 68.0)
            : 68.0;

        final tile = AnimatedBuilder(
          animation: _launchCtrl,
          builder: (context, child) {
            final lt = _launchT.value;
            return Transform.translate(
              offset: Offset(0, -lt * 22),
              child: Transform.scale(
                scale: 1.0 - lt * 0.55,
                child: Opacity(
                  opacity: (1.0 - lt * 1.8).clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            );
          },
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: canUse ? 1.0 : 0.32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (context, _) => Transform.translate(
                      offset: Offset(0, _float.value * 5.5),
                      child: Transform.scale(
                        scale: _pulse.value,
                        child: _orb(orbSize, lit: canUse),
                      ),
                    ),
                  ),
                  _caption(t, ghost: false),
                ],
              ),
            ),
          ),
        );

        if (!canUse) return tile;

        return Draggable<_InfusionPayload>(
          data: _InfusionPayload(_InfusionKind.orb, widget.type),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: widget.onDragStarted,
          onDragEnd: (_) => widget.onDragFinished(),
          feedback: FractionalTranslation(
            translation: const Offset(-0.5, -0.5),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => _orb(orbSize * 1.18, lit: true),
            ),
          ),
          childWhenDragging: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // A hollow socket marks where the orb came from, so the row
                // holds its shape instead of reflowing mid-drag.
                Container(
                  width: orbSize,
                  height: orbSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.type.color.withValues(alpha: 0.06),
                    border: Border.all(
                      color: widget.type.color.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                ),
                _caption(t, ghost: true),
              ],
            ),
          ),
          child: tile,
        );
      },
    );
  }
}

class _StatPlate extends StatelessWidget {
  final String label;
  final double value;
  final double potential;
  final int enhancementRank;
  final Color color;
  final FactionTheme theme;

  const _StatPlate({
    required this.label,
    required this.value,
    required this.potential,
    required this.enhancementRank,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final progress = enhancementRank / AlchemonStatSystem.maxEnhancementRank;
    final rating = AlchemonStatSystem.displayRating(value);
    final potentialRating = AlchemonStatSystem.normalizePotential(potential);
    final potentialMaxed = potentialRating >= AlchemonStatSystem.maxPotential;
    final enhanceMaxed =
        enhancementRank >= AlchemonStatSystem.maxEnhancementRank;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
      decoration: BoxDecoration(
        color: t.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              // A maxed Potential is terminal — no Soul can ever raise it
              // again — so it earns a different treatment from one with
              // headroom left.
              _PotentialPill(
                value: potentialRating,
                maxed: potentialMaxed,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            '$rating',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          // The bar tracks Enhancement, so it sits beside the Enhancement
          // label rather than under the stat value, where it used to read as
          // progress toward some unnamed stat ceiling.
          Row(
            children: [
              Text(
                enhanceMaxed
                    ? 'ENH MAX'
                    : 'ENH $enhancementRank/${AlchemonStatSystem.maxEnhancementRank}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: enhancementRank > 0 ? color : t.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: t.bg3,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One-time coach mark: a hand tracing the drag from the first orb up onto
/// the specimen. Anchored to measured geometry, so it points at the real
/// widgets rather than at guessed screen fractions.
class _DragHintOverlay extends StatefulWidget {
  const _DragHintOverlay({
    required this.from,
    required this.to,
    required this.theme,
  });

  final Offset from;
  final Offset to;
  final FactionTheme theme;

  @override
  State<_DragHintOverlay> createState() => _DragHintOverlayState();
}

class _DragHintOverlayState extends State<_DragHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Offset _pointAt(double t) {
    final from = widget.from;
    final to = widget.to;
    // Bow the path left so the hand traces an arc rather than a dead-straight
    // line, and keeps clear of the caption sitting mid-flight.
    final control = Offset(
      (from.dx + to.dx) / 2 - 54,
      (from.dy + to.dy) / 2 - 10,
    );
    final mt = 1 - t;
    return Offset(
      mt * mt * from.dx + 2 * mt * t * control.dx + t * t * to.dx,
      mt * mt * from.dy + 2 * mt * t * control.dy + t * t * to.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final raw = _ctrl.value;
        // Travel over the first 70% of the cycle, then hold and fade, so it
        // reads as a repeated gesture rather than an endless orbit.
        final travel = Curves.easeInOut.transform((raw / 0.7).clamp(0.0, 1.0));
        final opacity = raw < 0.08
            ? raw / 0.08
            : raw > 0.86
            ? (1 - (raw - 0.86) / 0.14).clamp(0.0, 1.0)
            : 1.0;
        final pos = _pointAt(travel);
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DragHintPathPainter(
                  points: [for (var i = 0; i <= 24; i++) _pointAt(i / 24)],
                  color: t.amberBright,
                  progress: travel,
                ),
              ),
            ),
            Positioned(
              left: pos.dx - 13,
              top: pos.dy - 5,
              child: Opacity(
                opacity: opacity,
                child: Icon(
                  AppIcons.hand_pointing_fill,
                  size: 30,
                  color: t.amberBright,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: (widget.from.dy + widget.to.dy) / 2 + 8,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: t.bg1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: t.amberBright.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    'Drag an orb onto your Alchemon',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DragHintPathPainter extends CustomPainter {
  const _DragHintPathPainter({
    required this.points,
    required this.color,
    required this.progress,
  });

  final List<Offset> points;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < points.length; i++) {
      final t = i / (points.length - 1);
      // Dots the hand has just passed flare briefly, so the trail reads as a
      // direction of travel instead of static decoration.
      final passed = progress - t;
      final lit = (passed >= 0 && passed < 0.32) ? 1.0 - passed / 0.32 : 0.0;
      paint.color = color.withValues(alpha: 0.14 + 0.55 * lit);
      canvas.drawCircle(points[i], 2.0 + 1.6 * lit, paint);
    }
  }

  @override
  bool shouldRepaint(_DragHintPathPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.points.length != points.length;
}

class _PotentialPill extends StatelessWidget {
  const _PotentialPill({
    required this.value,
    required this.maxed,
    required this.theme,
  });

  final int value;
  final bool maxed;
  final FactionTheme theme;

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: maxed ? t.amber.withValues(alpha: 0.18) : t.bg3,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: maxed ? t.amberBright.withValues(alpha: 0.7) : t.borderDim,
        ),
      ),
      child: Text(
        maxed ? 'P$value MAX' : 'P$value',
        style: TextStyle(
          fontFamily: 'monospace',
          color: maxed ? t.amberBright : t.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _PowerOrbPainter extends CustomPainter {
  final double progress;
  final double flash;
  final Color color;
  final Color glowColor;
  final String? rollLabel;
  final double glowBoost;
  final bool isJackpot;
  final double orbitTurns;
  final double orbitEndProgress;
  final String? deltaLabel;
  final int? soulRoll;

  const _PowerOrbPainter({
    required this.progress,
    required this.flash,
    required this.color,
    required this.glowColor,
    required this.rollLabel,
    required this.glowBoost,
    required this.isJackpot,
    required this.orbitTurns,
    required this.orbitEndProgress,
    this.deltaLabel,
    this.soulRoll,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.47);
    final orbOffset = _orbCenter(center, size);

    final double orbRadius;
    if (progress < 0.22) {
      orbRadius = lerpDouble(4, 16, Curves.easeOut.transform(progress / 0.22))!;
    } else {
      final remapped = (progress - 0.22) / 0.78;
      orbRadius = lerpDouble(16, 28, math.min(remapped / 0.6, 1.0))!;
    }

    final trail = Paint()
      ..shader = RadialGradient(colors: [glowColor, Colors.transparent])
          .createShader(
            Rect.fromCircle(
              center: orbOffset,
              radius: orbRadius * (3.6 * glowBoost),
            ),
          );
    canvas.drawCircle(orbOffset, orbRadius * (3.4 * glowBoost), trail);

    final orbPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white, color, glowColor],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: orbOffset, radius: orbRadius));
    canvas.drawCircle(orbOffset, orbRadius, orbPaint);

    // Orbit ring — tracks the orb's actual radial distance so it never looks mismatched
    if (progress >= 0.22 && progress < orbitEndProgress) {
      final orbitSpan = (orbitEndProgress - 0.22).clamp(0.01, 0.75);
      final orbitLocal = ((progress - 0.22) / orbitSpan).clamp(0.0, 1.0);
      final easedLocal = Curves.easeInOutSine.transform(orbitLocal);
      final ringRadius = lerpDouble(
        110.0 + ((orbitTurns - 2.2) * 8),
        isJackpot ? 80.0 : 90.0,
        easedLocal,
      )!;
      final orbitRing = Paint()
        ..color = glowColor.withValues(alpha: (1 - orbitLocal) * 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, ringRadius, orbitRing);
    }

    if (flash > 0) {
      final flashPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: flash * 0.75),
                glowColor.withValues(alpha: flash * (0.42 * glowBoost)),
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCircle(
                center: center,
                radius: (130 * flash + 40) * glowBoost,
              ),
            );
      canvas.drawCircle(center, (130 * flash + 40) * glowBoost, flashPaint);

      final revealRoll = soulRoll ?? 0;
      if (revealRoll >= 3) {
        final rayCount = 8 + (revealRoll * 4);
        final rayPaint = Paint()
          ..color = Colors.white.withValues(
            alpha: (0.12 + revealRoll * 0.045) * flash,
          )
          ..strokeWidth = revealRoll >= 5 ? 2.2 : 1.4
          ..strokeCap = StrokeCap.round;
        final innerRadius = 42.0 + (revealRoll * 3.0);
        final outerRadius = innerRadius + (30.0 + revealRoll * 10.0) * flash;
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(progress * math.pi * (revealRoll >= 5 ? 3.0 : 1.5));
        for (var i = 0; i < rayCount; i++) {
          final angle = (math.pi * 2 * i) / rayCount;
          canvas.drawLine(
            Offset(
              math.cos(angle) * innerRadius,
              math.sin(angle) * innerRadius,
            ),
            Offset(
              math.cos(angle) * outerRadius,
              math.sin(angle) * outerRadius,
            ),
            rayPaint,
          );
        }
        canvas.restore();

        if (revealRoll >= 4) {
          final resonancePaint = Paint()
            ..color = glowColor.withValues(alpha: 0.55 * flash)
            ..style = PaintingStyle.stroke
            ..strokeWidth = revealRoll >= 5 ? 3.0 : 2.0;
          canvas.drawCircle(
            center,
            (76.0 + revealRoll * 9.0) * flash,
            resonancePaint,
          );
          if (revealRoll >= 5) {
            canvas.drawCircle(
              center,
              (112.0 + revealRoll * 8.0) * flash,
              resonancePaint
                ..color = Colors.white.withValues(alpha: 0.35 * flash),
            );
          }
        }
      }

      if (rollLabel != null) {
        final rollPainter = TextPainter(
          text: TextSpan(
            text: rollLabel!,
            style: TextStyle(
              color: glowColor.withValues(alpha: 0.95),
              fontSize: isJackpot ? 16 : 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
              shadows: [Shadow(color: glowColor, blurRadius: 16 * glowBoost)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        rollPainter.paint(
          canvas,
          Offset(center.dx - rollPainter.width / 2, center.dy - 150),
        );
      }

      if (deltaLabel != null) {
        final painter = TextPainter(
          text: TextSpan(
            text: deltaLabel!,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: isJackpot ? 28 : 22,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: glowColor, blurRadius: 14 * glowBoost)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(center.dx - painter.width / 2, center.dy - 110 - flash * 24),
        );
      }
    }
  }

  Offset _orbCenter(Offset center, Size size) {
    final orbitStartRadius = 110.0 + ((orbitTurns - 2.2) * 8);

    // Phase 1: fly in from below stage (0.0 → 0.22)
    // Ends at the exact top of the orbit circle so Phase 2 starts seamlessly.
    if (progress < 0.22) {
      final local = Curves.easeOut.transform(progress / 0.22);
      return Offset(
        lerpDouble(center.dx + 22, center.dx, local)!,
        lerpDouble(size.height + 10, center.dy - orbitStartRadius, local)!,
      );
    }

    // Phase 2: orbit arc (the final rank gets the strongest celebration)
    if (progress < orbitEndProgress) {
      final orbitSpan = (orbitEndProgress - 0.22).clamp(0.01, 0.75);
      final local = ((progress - 0.22) / orbitSpan).clamp(0.0, 1.0);
      // easeInOutSine gives a gentler S-curve than Cubic — more natural orbit speed
      final easedLocal = Curves.easeInOutSine.transform(local);
      final angle = easedLocal * math.pi * orbitTurns - math.pi / 2;
      final radius = lerpDouble(
        orbitStartRadius,
        isJackpot ? 80.0 : 90.0,
        easedLocal,
      )!;
      return center +
          Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    }

    // Phase 3: dive to center from the precise orbit endpoint.
    // Computing this dynamically prevents the position jump that made the orb
    // look like it "went past" the circle.
    final endAngle = math.pi * orbitTurns - math.pi / 2;
    final endRadius = isJackpot ? 80.0 : 90.0;
    final start =
        center +
        Offset(math.cos(endAngle) * endRadius, math.sin(endAngle) * endRadius);
    final diveSpan = (1.0 - orbitEndProgress).clamp(0.01, 0.78);
    final local = ((progress - orbitEndProgress) / diveSpan).clamp(0.0, 1.0);
    final easedLocal = Curves.easeInCubic.transform(local);
    return Offset(
      lerpDouble(start.dx, center.dx, easedLocal)!,
      lerpDouble(start.dy, center.dy, easedLocal)!,
    );
  }

  @override
  bool shouldRepaint(covariant _PowerOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.flash != flash ||
        oldDelegate.color != color ||
        oldDelegate.deltaLabel != deltaLabel ||
        oldDelegate.soulRoll != soulRoll ||
        oldDelegate.rollLabel != rollLabel ||
        oldDelegate.glowBoost != glowBoost ||
        oldDelegate.isJackpot != isJackpot ||
        oldDelegate.orbitTurns != orbitTurns ||
        oldDelegate.orbitEndProgress != orbitEndProgress;
  }
}
