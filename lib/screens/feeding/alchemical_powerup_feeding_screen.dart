import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/models/alchemical_powerup.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/services/creature_instance_service.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/utils/faction_util.dart';
import 'package:alchemons/widgets/all_instaces_grid.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/tutorial_step.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  bool _powerupTutorialChecked = false;
  Map<AlchemicalPowerupType, double>? _frozenStatValues;

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
            'Powerup Infusion Basics',
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
                'Powerup orbs boost one stat at a time, but only level 10 specimens can enter infusion and each orb rolls a random strength before the gain is applied.',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TutorialStep(
                theme: theme,
                icon: Icons.workspace_premium_rounded,
                title: 'Step 0 - Reach Level 10',
                body:
                    'A specimen must be level 10 before it can use powerup orbs.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.casino_rounded,
                title: 'Step 1 - Roll Strength',
                body:
                    'Each orb rolls one of five strengths: +0.05, +0.10, +0.15, +0.20, or +0.25.',
              ),
              const SizedBox(height: 6),
              TutorialStep(
                theme: theme,
                icon: Icons.shield_rounded,
                title: 'Step 2 - Respect Potential',
                body:
                    'The final gain is capped by the specimen\'s remaining potential, so a great roll can still be partially capped.',
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
                      });
                    }
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
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Choose a level 10 specimen to channel power orbs directly into its stats.',
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
        if (kDebugMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy ? null : _grantTestOrbs,
                icon: const Icon(Icons.science_rounded, size: 16),
                label: const Text('Grant Test Orbs'),
                style: TextButton.styleFrom(
                  foregroundColor: t.textPrimary,
                  backgroundColor: t.bg2,
                  disabledForegroundColor: t.textMuted,
                  disabledBackgroundColor: t.bg1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: t.borderDim),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: AllCreatureInstances(
            theme: theme,
            prefsScopeKey: 'powerup_feed_select',
            selectedInstanceIds: const [],
            onTap: (inst) {
              if (inst.level < _requiredPowerupLevel) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Only level $_requiredPowerupLevel specimens can use powerup infusion.',
                    ),
                  ),
                );
                return;
              }
              HapticFeedback.selectionClick();
              setState(() {
                _selectedInstanceId = inst.instanceId;
                _message = null;
                _lastDelta = null;
                _frozenStatValues = null;
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

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  _SpecimenBanner(
                    theme: theme,
                    creatureName: creature.name,
                    rarity: creature.rarity,
                    onChooseDifferent: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedInstanceId = null;
                        _frozenStatValues = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildStageCard(creature, instance, theme),
                  const SizedBox(height: 12),
                  _buildPowerupGrid(instance, inventory, theme),
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    _buildMessageBox(theme),
                  ],
                ],
              ),
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
              _message!,
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
          // Header strip
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
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
                Text(
                  'INFUSION STAGE',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          // Creature display
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                SizedBox(
                  height: 210,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Creature sprite
                      Positioned(
                        bottom: 12,
                        child: InstanceSprite(
                          creature: creature,
                          instance: instance,
                          size: 168,
                        ),
                      ),
                      // Orb animation overlay
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
                                  glowColor: _animatingType!.glowColor,
                                  rollLabel: _lastRollLabel,
                                  glowBoost: _glowBoost,
                                  isJackpot: _jackpotAnimation,
                                  orbitTurns: _orbitTurns,
                                  orbitEndProgress: _orbitEndProgress,
                                  deltaLabel: _lastDelta == null
                                      ? null
                                      : '+${_lastDelta!.toStringAsFixed(2)}',
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Divider before stats
                Container(height: 1, color: t.borderDim),
                const SizedBox(height: 8),
                // Stat plates
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    _StatPlate(
                      theme: theme,
                      label: 'Speed',
                      value: _displayStatValue(
                        instance,
                        AlchemicalPowerupType.speed,
                      ),
                      potential: instance.statSpeedPotential,
                      color: AlchemicalPowerupType.speed.color,
                    ),
                    _StatPlate(
                      theme: theme,
                      label: 'Intelligence',
                      value: _displayStatValue(
                        instance,
                        AlchemicalPowerupType.intelligence,
                      ),
                      potential: instance.statIntelligencePotential,
                      color: AlchemicalPowerupType.intelligence.color,
                    ),
                    _StatPlate(
                      theme: theme,
                      label: 'Strength',
                      value: _displayStatValue(
                        instance,
                        AlchemicalPowerupType.strength,
                      ),
                      potential: instance.statStrengthPotential,
                      color: AlchemicalPowerupType.strength.color,
                    ),
                    _StatPlate(
                      theme: theme,
                      label: 'Beauty',
                      value: _displayStatValue(
                        instance,
                        AlchemicalPowerupType.beauty,
                      ),
                      potential: instance.statBeautyPotential,
                      color: AlchemicalPowerupType.beauty.color,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerupGrid(
    CreatureInstance instance,
    Map<String, int> inventory,
    FactionTheme theme,
  ) {
    final t = ForgeTokens(theme);
    return Container(
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section header
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
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
                Text(
                  'ALCHEMICAL POWERUPS',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.amberBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 8, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < AlchemicalPowerupType.values.length; i++)
                  Builder(
                    builder: (context) {
                      final type = AlchemicalPowerupType.values[i];
                      final qty = inventory[type.inventoryKey] ?? 0;
                      final current = _displayStatValue(instance, type);
                      final potential = switch (type) {
                        AlchemicalPowerupType.speed =>
                          instance.statSpeedPotential,
                        AlchemicalPowerupType.intelligence =>
                          instance.statIntelligencePotential,
                        AlchemicalPowerupType.strength =>
                          instance.statStrengthPotential,
                        AlchemicalPowerupType.beauty =>
                          instance.statBeautyPotential,
                      };
                      final maxDelta = alchemicalPowerupMaxDelta(
                        currentValue: current,
                        potentialValue: potential,
                      );
                      final canUse = qty > 0 && maxDelta > 0 && !_busy;
                      return _AnimatedOrbButton(
                        type: type,
                        qty: qty,
                        canUse: canUse,
                        isLaunching: _launchingType == type,
                        theme: theme,
                        phaseDelay: Duration(milliseconds: i * 320),
                        onTap: canUse
                            ? () => _applyPowerup(instance, type)
                            : null,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyPowerup(
    CreatureInstance instance,
    AlchemicalPowerupType type,
  ) async {
    if (_busy) return;

    final db = context.read<AlchemonsDatabase>();
    final currentValue = switch (type) {
      AlchemicalPowerupType.speed => _displayStatValue(instance, type),
      AlchemicalPowerupType.intelligence => _displayStatValue(instance, type),
      AlchemicalPowerupType.strength => _displayStatValue(instance, type),
      AlchemicalPowerupType.beauty => _displayStatValue(instance, type),
    };
    final potentialValue = switch (type) {
      AlchemicalPowerupType.speed => instance.statSpeedPotential,
      AlchemicalPowerupType.intelligence => instance.statIntelligencePotential,
      AlchemicalPowerupType.strength => instance.statStrengthPotential,
      AlchemicalPowerupType.beauty => instance.statBeautyPotential,
    };
    final plannedRoll = rollAlchemicalPowerup(
      currentValue: currentValue,
      potentialValue: potentialValue,
    );
    if (plannedRoll.appliedDelta <= 0) return;

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
      _frozenStatValues = frozenStats;
      _message = null;
    });

    // Let the orb button animate out first
    await Future<void>.delayed(const Duration(milliseconds: 380));
    if (!mounted) return;

    _orbController.duration = plannedRoll.animationDuration;
    _flashController.duration = plannedRoll.flashDuration;

    setState(() {
      _launchingType = null;
      _animatingType = type;
      _lastDelta = plannedRoll.appliedDelta;
      _lastRollLabel = plannedRoll.label;
      _glowBoost = plannedRoll.glowBoost;
      _jackpotAnimation = plannedRoll.isJackpot;
      _orbitTurns = plannedRoll.orbitTurns;
      _orbitEndProgress = plannedRoll.orbitEndProgress;
      _message = '${plannedRoll.label}: channeling ${type.name}...';
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
      forcedRoll: plannedRoll,
    );

    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _busy = false;
        _launchingType = null;
        _animatingType = null;
        _frozenStatValues = null;
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
      _frozenStatValues = null;
      _message =
          '${result.rollLabel}: ${type.name} granted ${result.delta.toStringAsFixed(2)} ${result.statKey}.';
    });
  }

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

  Future<void> _grantTestOrbs() async {
    if (_busy) return;

    final db = context.read<AlchemonsDatabase>();
    setState(() {
      _busy = true;
      _message = 'Granted 5 of each orb for testing.';
    });

    for (final type in AlchemicalPowerupType.values) {
      await db.inventoryDao.addItemQty(type.inventoryKey, 5);
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
    });
  }
}

class _PowerupHeader extends StatelessWidget {
  final bool canGoBack;
  final VoidCallback onBack;
  final FactionTheme theme;

  const _PowerupHeader({
    required this.canGoBack,
    required this.onBack,
    required this.theme,
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: t.bg2,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: t.borderDim),
                ),
                child: Icon(
                  canGoBack ? Icons.arrow_back : Icons.close_rounded,
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
                    'POWERUP INFUSION',
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
                        ? 'Select an orb type to infuse'
                        : 'Select a specimen',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
}

class _SpecimenBanner extends StatelessWidget {
  final String creatureName;
  final String rarity;
  final VoidCallback onChooseDifferent;
  final FactionTheme theme;

  const _SpecimenBanner({
    required this.creatureName,
    required this.rarity,
    required this.onChooseDifferent,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: t.bg2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: t.borderDim),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: t.amber,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(3),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            creatureName,
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${rarity.toUpperCase()} SPECIMEN ON STAGE',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: t.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: onChooseDifferent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: t.bg3,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: t.borderDim),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 14,
                              color: t.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'CHANGE',
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: t.textSecondary,
                                fontSize: 9,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedOrbButton extends StatefulWidget {
  final AlchemicalPowerupType type;
  final int qty;
  final bool canUse;
  final bool isLaunching;
  final FactionTheme theme;
  final Duration phaseDelay;
  final VoidCallback? onTap;

  const _AnimatedOrbButton({
    required this.type,
    required this.qty,
    required this.canUse,
    required this.isLaunching,
    required this.theme,
    required this.phaseDelay,
    this.onTap,
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

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(widget.theme);
    final type = widget.type;
    final canUse = widget.canUse;

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
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
          child: SizedBox(
            width: 76,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (context, _) {
                    return Transform.translate(
                      offset: Offset(0, _float.value * 5.5),
                      child: Transform.scale(
                        scale: _pulse.value,
                        child: Container(
                          width: 68,
                          height: 68,
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
                                  alpha: canUse
                                      ? 0.50 + _pulse.value * 0.08
                                      : 0.18,
                                ),
                                blurRadius: canUse ? 24 : 10,
                                spreadRadius: canUse ? 1 : -6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: widget.qty > 0
                        ? type.color.withValues(alpha: 0.14)
                        : t.bg3,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: widget.qty > 0
                          ? type.color.withValues(alpha: 0.45)
                          : t.borderDim,
                    ),
                  ),
                  child: Text(
                    'x${widget.qty}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: widget.qty > 0 ? type.color : t.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  type.statKey.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: t.textSecondary,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatPlate extends StatelessWidget {
  final String label;
  final double value;
  final double potential;
  final Color color;
  final FactionTheme theme;

  const _StatPlate({
    required this.label,
    required this.value,
    required this.potential,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(theme);
    final progress = potential <= 0 ? 0.0 : (value / potential).clamp(0.0, 1.0);
    return Container(
      width: 148,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.bg1,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textSecondary,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(2)} / ${potential.toStringAsFixed(2)}',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress,
              backgroundColor: t.bg3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
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

    // Phase 2: orbit arc (rarer rolls spin longer and faster)
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
        oldDelegate.rollLabel != rollLabel ||
        oldDelegate.glowBoost != glowBoost ||
        oldDelegate.isJackpot != isJackpot ||
        oldDelegate.orbitTurns != orbitTurns ||
        oldDelegate.orbitEndProgress != orbitEndProgress;
  }
}
