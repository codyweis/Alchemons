// lib/widgets/wilderness/encounter_overlay.dart
//
// Modern split-HUD layout for wild encounters
// - Top-right: Wild creature portrait with stats
// - Bottom-right: Compact party strip
// - Center-right: Action buttons
// - Clean, game-like presentation optimized for landscape
// lib/widgets/wilderness/encounter_overlay.dart
//
// Modern split-HUD layout for wild encounters
// - Top-right: Wild creature portrait with stats
// - Bottom-right: Compact party strip
// - Center-right: Action buttons
// - Clean, game-like presentation optimized for landscape

import 'dart:async';
import 'dart:math';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/widgets/wilderness/tutorial_highlight.dart'; // 🆕 Import highlight widget
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/stamina_service.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/wilderness/device_selection_dialog.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Wild encounters render over dark scene backdrops — always dark.
const _kPalette = BracketPalette.dark;

class EncounterOverlay extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final ValueChanged<bool>? onClosedWithResult;
  final ValueChanged<Creature>? onPartyCreatureSelected;
  final VoidCallback? onPreRollShake;
  final Creature hydratedWildCreature;
  final bool highlightPartyHUD; // 🆕 Tutorial highlighting
  final bool isTutorial; // 🆕 Tutorial mode flag
  final bool isCaptureTutorial;
  final bool warnOnRun; // show a confirmation before running away
  final bool showFusionAction;
  // Whether to show the "Map" (return-to-map) action. Portal and planet
  // encounters have their own exit affordance, so they hide it.
  final bool showMapAction;

  const EncounterOverlay({
    super.key,
    required this.encounter,
    required this.party,
    this.onClosedWithResult,
    this.onPartyCreatureSelected,
    this.onPreRollShake,
    required this.hydratedWildCreature,
    this.highlightPartyHUD = false, // 🆕 Default to false
    this.isTutorial = false, // 🆕 Default to false
    this.isCaptureTutorial = false,
    this.warnOnRun = false,
    this.showFusionAction = true,
    this.showMapAction = true,
  });

  @override
  State<EncounterOverlay> createState() => _EncounterOverlayState();
}

class _EncounterOverlayState extends State<EncounterOverlay>
    with TickerProviderStateMixin {
  bool _visible = false; // ignore: unused_field
  String? _chosenInstanceId;
  bool _busy = false;
  late String _status;

  double? _breedChance; // 0.0–1.0 probability

  late final AnimationController _slideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  @override
  void initState() {
    super.initState();
    _status = widget.isCaptureTutorial
        ? 'Harvester calibrated. Secure the specimen.'
        : _supportsFusion
        ? 'Select a party ally to begin fusion.'
        : 'Choose an encounter protocol.';
    // Auto-show on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _show();
    });
  }

  bool get _supportsFusion =>
      widget.showFusionAction &&
      !widget.isCaptureTutorial &&
      widget.party.isNotEmpty;

  String _familyKeyForCreature(Creature c) {
    if (c.mutationFamily != null && c.mutationFamily!.isNotEmpty) {
      return c.mutationFamily!.toUpperCase();
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(c.id);
    final letters = match?.group(0) ?? c.id;
    return letters.toUpperCase();
  }

  BreedingServiceV2 _buildBreedingService(BuildContext ctx) {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();

    return BreedingServiceV2(
      gameData: ctx.read<GameDataService>(),
      db: db,
      engine: ctx.read<BreedingEngine>(),
      payloadFactory: EggPayloadFactory(repo),
      wildRandomizer: WildCreatureRandomizer(),
      constellation: ctx.read<ConstellationEffectsService>(),
      factions: ctx.read<FactionService>(),
    );
  }

  double _computeWildBreedChance(
    db.CreatureInstance instance,
    WildernessService wilderness,
    ConstellationEffectsService constellation,
  ) {
    final totalLuck = instance.statBeauty / 100.0;
    final harvestBonus = constellation.getWildernessHarvestBonus();

    return wilderness.computeBreedChance(
      base: widget.encounter.baseBreedChance,
      partyLuck: totalLuck,
      matchupMult: 1.0,
      wildernessBonus: harvestBonus,
    );
  }

  Future<void> _showCrossSpeciesLockedDialog(
    BuildContext context,
    String familyA,
    String familyB,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        const amber = Color(0xFFE4C16A);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: amber.withValues(alpha: 0.85),
                bracketSize: 12,
                strokeWidth: 1.3,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                color: _kPalette.surfaceFill(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 24, color: amber),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            'Further research required',
                            style: bracketText(
                              ctx,
                              17,
                              _kPalette.ink,
                              weight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'Your current field protocols only support fusion '
                      'within the same lineage family.\n\n'
                      'To attempt wild breeding between $familyA and $familyB '
                      'specimens, unlock the Cross-Species Lineage node in '
                      'the Breeder constellation.',
                      style: bracketText(
                        ctx,
                        12.5,
                        _kPalette.muted,
                        weight: FontWeight.w500,
                      ),
                      strutStyle: const StrutStyle(height: 1.45),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: CustomPaint(
                        painter: BracketFramePainter(
                          color: amber,
                          bracketSize: 8,
                          strokeWidth: 1.2,
                        ),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          color: amber.withValues(alpha: 0.14),
                          child: Text(
                            'Acknowledge',
                            style: bracketText(
                              ctx,
                              13,
                              amber,
                              weight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
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
      },
    );
  }

  void _show() {
    setState(() => _visible = true);
    _slideController.forward();
    _fadeController.forward();
  }

  Future<void> _handleRun(BuildContext context) async {
    if (!widget.warnOnRun) {
      _hide(false);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        const danger = Color(0xFFC0392B);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: danger.withValues(alpha: 0.85),
                bracketSize: 12,
                strokeWidth: 1.3,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                color: _kPalette.surfaceFill(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 3, height: 24, color: danger),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            'Leave the void?',
                            style: bracketText(
                              ctx,
                              17,
                              _kPalette.ink,
                              weight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Text(
                      'The void will remain in the rift, but this encounter '
                      'will be lost if you return.',
                      style: bracketText(
                        ctx,
                        12.5,
                        _kPalette.muted,
                        weight: FontWeight.w500,
                      ),
                      strutStyle: const StrutStyle(height: 1.45),
                    ),
                    const SizedBox(height: AppSpace.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _DialogChoice(
                            label: 'Stay',
                            color: _kPalette.muted,
                            filled: false,
                            onTap: () => Navigator.of(ctx).pop(false),
                          ),
                        ),
                        const SizedBox(width: AppSpace.sm),
                        Expanded(
                          child: _DialogChoice(
                            label: 'Leave',
                            color: danger,
                            filled: true,
                            onTap: () => Navigator.of(ctx).pop(true),
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
      },
    );
    if (confirmed == true) _hide(false);
  }

  void _hide([bool success = false]) {
    setState(() {
      _breedChance = null;
      _chosenInstanceId = null;
    });
    if (success) {
      // Notify the host immediately so the wild + party actors are
      // cleared from the scene before any result notification appears.
      widget.onClosedWithResult?.call(true);
      return;
    }
    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onClosedWithResult?.call(false);
      }
    });
    _fadeController.reverse();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wildCreature = widget.hydratedWildCreature;
    return Stack(
      children: [
        // Center: Wild creature name title
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            final size = MediaQuery.sizeOf(context);
            final isLandscape = size.width > size.height;
            // Inset so the FIELD STATUS card clears the side HUDs
            // (party strip + scene controls) in landscape.
            final sideInset = isLandscape ? 210.0 : 16.0;
            return Positioned(
              top: 16,
              left: sideInset,
              right: sideInset,
              child: Opacity(
                opacity: slide,
                child: _WildCreatureTitle(
                  creature: wildCreature,
                  rarity: widget.encounter.rarity,
                  status: _status,
                  breedChance: _supportsFusion ? _breedChance : null,
                ),
              ),
            );
          },
        ),

        // Top-right: Party HUD with optional tutorial highlighting 🆕
        if (_supportsFusion)
          AnimatedBuilder(
            animation: _slideController,
            builder: (_, __) {
              final slide = Curves.easeOutCubic.transform(
                _slideController.value,
              );
              return Positioned(
                top: 16,
                right: 16 - (300 * (1 - slide)),
                child: Opacity(
                  opacity: slide,
                  child: TutorialHighlight(
                    enabled:
                        widget.highlightPartyHUD &&
                        _chosenInstanceId == null, // 🆕
                    label: 'Select an Alchemon to breed', // 🆕
                    child: _PartyHUD(
                      party: widget.party,
                      chosenInstanceId: _chosenInstanceId,
                      onSelect: _onSelectPartyCreature,
                    ),
                  ),
                ),
              );
            },
          ),

        // Bottom: Action buttons row
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            return Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Opacity(
                opacity: slide,
                child: Transform.translate(
                  offset: Offset(0, 100 * (1 - slide)),
                  child: _ActionPanel(
                    isPartySelected: _chosenInstanceId != null,
                    canAct: !_busy,
                    isTutorial: widget.isTutorial, // 🆕 Pass tutorial flag
                    isCaptureTutorial: widget.isCaptureTutorial,
                    onBreed: !_busy
                        ? () => _handleBreed(context, wildCreature)
                        : null,
                    onCapture: !_busy
                        ? () => _handleCapture(context, wildCreature)
                        : null,
                    onRun: () => _handleRun(context),
                    showFusionAction: _supportsFusion,
                    showMapAction: widget.showMapAction,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildWildSprite(Creature wildCreature, {double size = 120}) {
    if (wildCreature.spriteData != null) {
      final sheet = sheetFromCreature(wildCreature);
      final visuals = visualsFromInstance(wildCreature, null);
      return SizedBox(
        width: size,
        height: size,
        child: CreatureSprite(
          spritePath: sheet.path,
          totalFrames: sheet.totalFrames,
          rows: sheet.rows,
          frameSize: sheet.frameSize,
          stepTime: sheet.stepTime,
          scale: visuals.scale,
          saturation: visuals.saturation,
          brightness: visuals.brightness,
          hueShift: visuals.hueShiftDeg,
          isPrismatic: visuals.isPrismatic,
          tint: visuals.tint,
          alchemyEffect: visuals.alchemyEffect,
          variantFaction: visuals.variantFaction,
        ),
      );
    }

    return Icon(
      AppIcons.pets,
      color: Colors.white.withValues(alpha: .8),
      size: 64,
    );
  }

  Future<void> _onSelectPartyCreature(String instanceId) async {
    final db = context.read<AlchemonsDatabase>();
    final repo = context.read<CreatureCatalog>();
    final staminaService = context.read<StaminaService>();

    final instRow = await db.creatureDao.getInstance(instanceId);
    if (instRow == null) return;

    final baseCreature = repo.getCreatureById(instRow.baseId);
    if (baseCreature == null) return;

    final hydrated = baseCreature.copyWith(
      genetics: decodeGenetics(instRow.geneticsJson),
      nature: instRow.natureId != null
          ? NatureCatalog.byId(instRow.natureId!)
          : baseCreature.nature,
      isPrismaticSkin: instRow.isPrismaticSkin || baseCreature.isPrismaticSkin,
    );

    final wilderness = WildernessService(db, staminaService);
    if (!mounted) return;
    final constellation = context.read<ConstellationEffectsService>();
    final p = _computeWildBreedChance(instRow, wilderness, constellation);

    setState(() {
      _status = '${hydrated.name} locked in. Choose a protocol.';
      _chosenInstanceId = instanceId;
      _breedChance = p;
    });

    widget.onPartyCreatureSelected?.call(hydrated);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleBreed(BuildContext ctx, Creature wildCreature) async {
    if (_chosenInstanceId == null) {
      setState(() => _status = 'Select a party ally first.');
      return;
    }

    setState(() => _busy = true);

    try {
      final db = ctx.read<AlchemonsDatabase>();
      final repo = ctx.read<CreatureCatalog>();
      final breedingService = _buildBreedingService(ctx);
      final wilderness = WildernessService(db, ctx.read<StaminaService>());

      final instance = await db.creatureDao.getInstance(_chosenInstanceId!);
      if (instance == null) {
        setState(() => _status = 'Specimen sync failed.');
        return;
      }

      // --- Cross-species check BEFORE stamina / roll / cinematic ---
      final speciesA = repo.getCreatureById(instance.baseId);
      final speciesB = wildCreature;

      if (speciesA == null) {
        setState(() => _status = 'Wild record lookup failed.');
        return;
      }

      final famA = _familyKeyForCreature(speciesA);
      final famB = _familyKeyForCreature(speciesB);
      final sameFamily = famA == famB;

      final skills = await db.constellationDao.getUnlockedSkillIds();
      final hasCrossSpecies = skills.contains('breeder_cross_species');

      if (!sameFamily && !hasCrossSpecies) {
        if (!ctx.mounted) return;
        await _showCrossSpeciesLockedDialog(ctx, famA, famB);
        setState(() {
          _status = 'Cross-lineage fusion requires more research.';
        });
        return;
      }

      final placementFailure = await breedingService
          .getEggPlacementFailureMessage(requireStorageCapacity: false);
      if (placementFailure != null) {
        setState(() => _status = placementFailure);
        return;
      }
      // --------------------------------------------------------------
      if (!ctx.mounted) return;
      final constellation = ctx.read<ConstellationEffectsService>();
      final p = _computeWildBreedChance(instance, wilderness, constellation);

      final spent = await wilderness.trySpendForAttempt(_chosenInstanceId!);
      if (spent == null) {
        setState(() => _status = 'This Alchemon is out of stamina.');
        return;
      }

      widget.onPreRollShake?.call();
      HapticFeedback.mediumImpact();
      setState(() => _status = 'Calibrating the alchemical matrix...');
      await Future.delayed(const Duration(milliseconds: 650));

      final success = wilderness.rollSuccess(p);
      if (success) {
        final speciesA = repo.getCreatureById(instance.baseId);
        final speciesB = wildCreature;

        Color colorOf(Creature? c, Color fallback) =>
            c != null && c.types.isNotEmpty
            ? BreedConstants.getTypeColor(c.types.first)
            : fallback;

        if (!ctx.mounted) return;
        final colorA = colorOf(speciesA, Theme.of(ctx).colorScheme.primary);
        final colorB = colorOf(speciesB, Theme.of(ctx).colorScheme.secondary);

        Widget partySprite() {
          return SizedBox(
            width: 150,
            height: 150,
            child: InstanceSprite(
              creature: speciesA!,
              instance: instance,
              size: 150,
            ),
          );
        }

        Widget wildSprite() {
          return _buildWildSprite(speciesB);
        }

        // 🆕 Show cinematic FIRST, then hide overlay
        if (!ctx.mounted) return;
        final didBreed = await showAlchemyFusionCinematic<bool>(
          context: ctx,
          leftSprite: partySprite(),
          rightSprite: wildSprite(),
          leftColor: colorA,
          rightColor: colorB,
          minDuration: const Duration(milliseconds: 1800),
          task: () async {
            return _breedWithWild(ctx, instance, speciesB, breedingService);
          },
        );

        if (didBreed != true) return;
        if (!mounted || !ctx.mounted) return;

        // Capture the messenger + message, close the encounter (which
        // clears the scene actors), then surface a lightweight
        // notification — no blocking modal.
        final messenger = ScaffoldMessenger.maybeOf(ctx);
        final resultMessage = _status;
        _hide(true);
        if (messenger != null) {
          _showFusionResultNotification(messenger, resultMessage);
        }
      } else {
        setState(() => _status = 'Fusion destabilized. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCapture(BuildContext ctx, Creature wildCreature) async {
    setState(() => _busy = true);

    try {
      final selectedDevice = await DeviceSelectionDialog.show(
        ctx,
        wildCreature: wildCreature,
        rarity: widget.encounter.rarity,
      );

      if (selectedDevice == null || !ctx.mounted) {
        setState(() => _busy = false);
        return;
      }

      // 🎬 Show harvest cinematic with sprite
      Widget wildSprite() {
        return _buildWildSprite(wildCreature);
      }

      Color colorOf(Creature? c, Color fallback) =>
          c != null && c.types.isNotEmpty
          ? BreedConstants.getTypeColor(c.types.first)
          : fallback;

      final targetColor = colorOf(wildCreature, Colors.green);

      // Trigger screen shake before cinematic
      widget.onPreRollShake?.call();

      if (!ctx.mounted) return;
      final success = await showHarvestCinematic(
        context: ctx,
        targetSprite: wildSprite(),
        targetColor: targetColor,
        deviceLabel: selectedDevice.label,
        minDuration: const Duration(milliseconds: 1600),
        task: () async {
          final catchService = ctx.read<CatchService>();
          return await catchService.attemptCatch(
            device: selectedDevice,
            target: wildCreature,
            forceSuccess: widget.isCaptureTutorial,
          );
        },
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        setState(
          () => _status = 'Extraction complete. Specimen sent to Cultivations.',
        );

        if (!ctx.mounted) return;
        await _placeWildEgg(ctx, wildCreature);

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _hide(true);
      } else {
        HapticFeedback.lightImpact();
        setState(() => _status = 'Harvester failed to secure the specimen.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Encounter error: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Breed owned instance with wild creature using BreedingServiceV2
  Future<bool> _breedWithWild(
    BuildContext ctx,
    db.CreatureInstance ownedParent,
    Creature? wildCreature,
    BreedingServiceV2 breedingService,
  ) async {
    if (wildCreature == null) return false;

    // Single call: service will randomize wild, breed, and compute analysis.
    final result = await breedingService.breedWithWild(
      ownedParent,
      wildCreature,
      customHatchDuration: widget.isTutorial
          ? const Duration(seconds: 30)
          : null,
      forcePrismatic: widget.encounter.voidBred,
      sourceOverride: widget.encounter.source,
    );

    if (!result.success) {
      if (mounted) {
        setState(() => _status = 'Fusion failed: ${result.message}');
      }
      return false;
    }

    if (mounted) {
      setState(
        () => _status = result.placement == EggPlacement.storage
            ? 'Cultivation chambers were full — the specimen was moved to cold storage.'
            : 'The new specimen was sent to a cultivation chamber.',
      );
    }

    return true;
  }

  /// Lightweight, non-blocking result notification shown after a
  /// successful fusion (the encounter has already closed).
  void _showFusionResultNotification(
    ScaffoldMessengerState messenger,
    String message,
  ) {
    const success = Color(0xFF22C55E);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.all(16),
        content: CustomPaint(
          painter: BracketFramePainter(
            color: success.withValues(alpha: 0.85),
            bracketSize: 9,
            strokeWidth: 1.2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12161D),
              border: const Border(
                left: BorderSide(color: success, width: 3),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                const Icon(
                  AppIcons.check_circle_rounded,
                  color: success,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fusion complete',
                        style: bracketText(
                          messenger.context,
                          13,
                          Colors.white,
                          weight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        message,
                        style: bracketText(
                          messenger.context,
                          11.5,
                          Colors.white70,
                          weight: FontWeight.w500,
                        ),
                        strutStyle: const StrutStyle(height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _placeWildEgg(
    BuildContext ctx,
    Creature capturedCreature,
  ) async {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();

    final rarityKey = capturedCreature.rarity.toLowerCase();
    final baseHatchDelay =
        (widget.isCaptureTutorial
            ? const Duration(seconds: 30)
            : BreedConstants.rarityHatchTimes[rarityKey]) ??
        const Duration(minutes: 10);

    // 👇 apply nature + constellation
    final natureMult = hatchMultForNature(capturedCreature.nature?.id);
    final constellation = ctx.read<ConstellationEffectsService>();
    final gestationReduction = constellation.getGestationReduction();
    final totalMult = natureMult * (1.0 - gestationReduction);

    final adjustedDelay = Duration(
      milliseconds: (baseHatchDelay.inMilliseconds * totalMult).round(),
    );

    final hatchAtUtc = DateTime.now().toUtc().add(adjustedDelay);

    final factory = EggPayloadFactory(repo);
    final arcaneBoostUnlocked = await db.settingsDao.isArcanePortalUnlocked();
    final payload = factory.createWildCapturePayload(
      capturedCreature,
      sourceOverride: widget.encounter.source,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );
    final payloadJson = payload.toJsonString();

    final eggId = 'egg_${DateTime.now().millisecondsSinceEpoch}';
    final free = await db.incubatorDao.firstFreeSlot();

    if (free == null) {
      await db.incubatorDao.enqueueEgg(
        eggId: eggId,
        resultCreatureId: capturedCreature.id,
        rarity: capturedCreature.rarity,
        remaining: adjustedDelay,
        payloadJson: payloadJson,
      );
    } else {
      await db.incubatorDao.placeEgg(
        slotId: free.id,
        eggId: eggId,
        resultCreatureId: capturedCreature.id,
        rarity: capturedCreature.rarity,
        hatchAtUtc: hatchAtUtc,
        payloadJson: payloadJson,
      );
    }
  }
}

// ==========================================
// WILD CREATURE TITLE (Center top)
// ==========================================
class _EncounterStatusStyle {
  final Color accent;
  final IconData icon;

  const _EncounterStatusStyle({required this.accent, required this.icon});

  static const _danger = Color(0xFFC0392B);
  static const _amber = Color(0xFFE4C16A);
  static const _success = Color(0xFF22C55E);
  static const _teal = Color(0xFF5BC8E8);

  factory _EncounterStatusStyle.resolve(String status) {
    final normalized = status.toLowerCase();

    if (normalized.contains('failed') ||
        normalized.contains('error') ||
        normalized.contains('lost')) {
      return const _EncounterStatusStyle(
        accent: _danger,
        icon: AppIcons.warning_amber_rounded,
      );
    }
    if (normalized.contains('research') ||
        normalized.contains('stamina') ||
        normalized.contains('capacity')) {
      return const _EncounterStatusStyle(
        accent: _amber,
        icon: AppIcons.bolt_rounded,
      );
    }
    if (normalized.contains('complete') ||
        normalized.contains('sent to cultivations') ||
        normalized.contains('transferred')) {
      return const _EncounterStatusStyle(
        accent: _success,
        icon: AppIcons.check_circle_rounded,
      );
    }
    if (normalized.contains('calibrating') ||
        normalized.contains('select') ||
        normalized.contains('choose') ||
        normalized.contains('secure')) {
      return const _EncounterStatusStyle(
        accent: _teal,
        icon: AppIcons.tune_rounded,
      );
    }
    return const _EncounterStatusStyle(
      accent: _amber,
      icon: AppIcons.auto_awesome_rounded,
    );
  }
}

class _WildCreatureTitle extends StatelessWidget {
  final Creature creature;
  final String rarity;
  final String status;
  final double? breedChance;

  const _WildCreatureTitle({
    required this.creature,
    required this.rarity,
    required this.status,
    this.breedChance,
  });

  Color get _rarityColor {
    switch (rarity.toLowerCase()) {
      case 'uncommon':
        return const Color(0xFF34D399);
      case 'rare':
        return const Color(0xFF60A5FA);
      case 'epic':
        return const Color(0xFFA855F7);
      case 'legendary':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF9AA0AC);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _EncounterStatusStyle.resolve(status);
    final chancePct = breedChance == null
        ? null
        : '${(breedChance! * 100).toStringAsFixed(1)}%';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: statusStyle.accent.withValues(alpha: 0.8),
                bracketSize: 9,
                strokeWidth: 1.1,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.md,
                  vertical: AppSpace.sm,
                ),
                color: _kPalette.surfaceFill(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          statusStyle.icon,
                          color: statusStyle.accent,
                          size: AppIcon.sm,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'FIELD STATUS',
                          style: bracketText(
                            context,
                            10,
                            _kPalette.muted,
                            weight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (chancePct != null) ...[
                          const Spacer(),
                          Text(
                            'STABILITY ',
                            style: bracketText(
                              context,
                              9.5,
                              _kPalette.muted,
                              weight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                          Text(
                            chancePct,
                            style: bracketText(
                              context,
                              11.5,
                              const Color(0xFF22C55E),
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bracketText(
                        context,
                        13,
                        _kPalette.ink,
                        weight: FontWeight.w700,
                      ),
                      strutStyle: const StrutStyle(height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Classification rank badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _rarityColor.withValues(alpha: 0.16),
            border: Border(left: BorderSide(color: _rarityColor, width: 2)),
          ),
          child: Text(
            rarity.toUpperCase(),
            style: bracketText(
              context,
              11,
              _rarityColor,
              weight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Creature designation
        _DigitalAnimatedText(
          text: creature.name.toUpperCase(),
          duration: const Duration(milliseconds: 900),
          style: TextStyle(
            color: _kPalette.ink,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            shadows: [
              const Shadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
              Shadow(
                color: _rarityColor.withValues(alpha: 0.34),
                blurRadius: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// UTILITY: Digital Animated Text
// ==========================================
class _DigitalAnimatedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration duration;

  const _DigitalAnimatedText({
    required this.text,
    required this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  __DigitalAnimatedTextState createState() => __DigitalAnimatedTextState();
}

class __DigitalAnimatedTextState extends State<_DigitalAnimatedText> {
  String _displayText = '';
  late Timer _timer;
  int _currentIndex = 0;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  void _startAnimation() {
    // Shorter interval for fast "glitchy" type-in effect
    final interval = widget.duration.inMilliseconds ~/ widget.text.length;

    _timer = Timer.periodic(
      Duration(milliseconds: interval > 0 ? interval : 1),
      (timer) {
        if (_currentIndex < widget.text.length) {
          // Add one correct character
          _displayText = widget.text.substring(0, _currentIndex + 1);

          // Add 1-3 random, glitchy characters at the end
          final glitchLength = _random.nextInt(3) + 1;
          for (int i = 0; i < glitchLength; i++) {
            _displayText += String.fromCharCode(
              _random.nextInt(26) + 65,
            ); // Random uppercase letter
          }

          _currentIndex++;
        } else {
          // Animation finished, set final text and stop timer
          _displayText = widget.text;
          timer.cancel();
        }
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show the finished text at the very end
    final display = _currentIndex >= widget.text.length
        ? widget.text
        : _displayText;

    return Text(
      display,
      style: widget.style,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ==========================================
// PARTY HUD (Top-right) - Clean design
// ==========================================
class _PartyHUD extends StatelessWidget {
  final List<PartyMember> party;
  final String? chosenInstanceId;
  final ValueChanged<String> onSelect;

  const _PartyHUD({
    required this.party,
    required this.chosenInstanceId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BracketFramePainter(
        color: _kPalette.line.withValues(alpha: 0.7),
        bracketSize: 7,
        strokeWidth: 1.05,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        color: _kPalette.surfaceFill(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < party.length; i++) ...[
              _PartyMemberCard(
                member: party[i],
                selected: party[i].instanceId == chosenInstanceId,
                onTap: () => onSelect(party[i].instanceId),
              ),
              if (i < party.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartyMemberCard extends StatelessWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyMemberCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final repo = context.read<CreatureCatalog>();
    final stamina = context.read<StaminaService>();
    final instanceStream = context
        .read<AlchemonsDatabase>()
        .creatureDao
        .watchInstanceById(member.instanceId);
    const selAccent = Color(0xFF22C55E);

    return StreamBuilder<CreatureInstance?>(
      stream: instanceStream,
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);
        final StaminaState? state = inst != null
            ? stamina.computeState(inst)
            : null;

        return GestureDetector(
          onTap: onTap,
          child: CustomPaint(
            painter: BracketFramePainter(
              color: selected
                  ? selAccent
                  : _kPalette.line.withValues(alpha: 0.7),
              bracketSize: 6,
              strokeWidth: selected ? 1.4 : 1.0,
            ),
            child: Container(
              width: 56,
              padding: const EdgeInsets.all(5),
              color: selected
                  ? selAccent.withValues(alpha: 0.12)
                  : _kPalette.surfaceMutedFill(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (inst != null && base != null)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: InstanceSprite(
                        creature: base,
                        instance: inst,
                        size: 36,
                      ),
                    )
                  else
                    const SizedBox(width: 36, height: 36),
                  const SizedBox(height: 4),
                  if (state != null)
                    StaminaBar(current: state.bars, max: state.max),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==========================================
// ACTION PANEL (Bottom) - Horizontal row
// ==========================================
class _ActionPanel extends StatelessWidget {
  final bool canAct;
  final VoidCallback? onBreed;
  final VoidCallback? onCapture;
  final VoidCallback onRun;
  final bool isPartySelected;
  final bool isTutorial; // 🆕 Tutorial mode flag
  final bool isCaptureTutorial;
  final bool showFusionAction;
  final bool showMapAction;

  const _ActionPanel({
    required this.canAct,
    required this.onBreed,
    required this.onCapture,
    required this.onRun,
    required this.isPartySelected,
    this.isTutorial = false, // 🆕 Default to false
    this.isCaptureTutorial = false,
    this.showFusionAction = true,
    this.showMapAction = true,
  });

  @override
  Widget build(BuildContext context) {
    const success = Color(0xFF22C55E);
    const danger = Color(0xFFC0392B);
    const teal = Color(0xFF5BC8E8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (showFusionAction && !isCaptureTutorial) ...[
              _ActionButton(
                disabled: !isPartySelected,
                label: 'Fusion',
                icon: AppIcons.science_rounded,
                accentColor: success,
                onPressed: canAct ? onBreed : null,
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            if (!isTutorial || isCaptureTutorial) ...[
              TutorialHighlight(
                enabled: isCaptureTutorial,
                label: 'Use your harvester',
                child: _ActionButton(
                  label: 'Harvest',
                  icon: AppIcons.catching_pokemon_rounded,
                  accentColor: danger,
                  onPressed: canAct ? onCapture : null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            if (!isCaptureTutorial && showMapAction)
              _ActionButton(
                label: 'Map',
                icon: AppIcons.explore_rounded,
                accentColor: teal,
                onPressed: onRun,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onPressed;
  final bool disabled;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.accentColor,
    this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || disabled;
    final accent = isDisabled ? _kPalette.muted : accentColor;

    return Opacity(
      opacity: isDisabled ? 0.55 : 1,
      child: GestureDetector(
        onTap: isDisabled ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Solid opaque fill so the button stays readable on any
            // scene backdrop — no translucent neon wash.
            color: const Color(0xFF12161D),
            border: Border.all(color: accent, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: bracketText(
                  context,
                  13.5,
                  isDisabled ? _kPalette.muted : Colors.white,
                  weight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogChoice extends StatelessWidget {
  const _DialogChoice({
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: BracketFramePainter(
          color: filled ? color : color.withValues(alpha: 0.6),
          bracketSize: 8,
          strokeWidth: filled ? 1.3 : 1.1,
        ),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          color: filled ? color : color.withValues(alpha: 0.10),
          child: Text(
            label,
            style: bracketText(
              context,
              13,
              filled ? Colors.white : color,
              weight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}
