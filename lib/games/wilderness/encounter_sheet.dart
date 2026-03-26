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
import 'package:alchemons/utils/faction_util.dart';
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
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/stamina_bar.dart';
import 'package:alchemons/widgets/wilderness/device_selection_dialog.dart';

class EncounterOverlay extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final ValueChanged<bool>? onClosedWithResult;
  final ValueChanged<Creature>? onPartyCreatureSelected;
  final VoidCallback? onPreRollShake;
  final Creature hydratedWildCreature;
  final bool highlightPartyHUD; // 🆕 Tutorial highlighting
  final bool isTutorial; // 🆕 Tutorial mode flag
  final bool warnOnRun; // show a confirmation before running away
  final bool showFusionAction;

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
    this.warnOnRun = false,
    this.showFusionAction = true,
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
    _status = _supportsFusion
        ? 'Select a party member to act'
        : 'Choose an action.';
    // Auto-show on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _show();
    });
  }

  bool get _supportsFusion =>
      widget.showFusionAction && widget.party.isNotEmpty;

  String _familyKeyForCreature(Creature c) {
    if (c.mutationFamily != null && c.mutationFamily!.isNotEmpty) {
      return c.mutationFamily!.toUpperCase();
    }
    final match = RegExp(r'^[A-Za-z]+').firstMatch(c.id);
    final letters = match?.group(0) ?? c.id;
    return letters.toUpperCase();
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
        final theme = context.read<FactionTheme>();
        return AlertDialog(
          title: Text(
            'Further Research Required',
            style: TextStyle(color: theme.text),
          ),
          content: Text(
            'Your current field protocols only support fusion within the '
            'same lineage family.\n\n'
            'To attempt wild breeding between $familyA and $familyB specimens, '
            'unlock the Cross-Species Lineage node in the Breeder constellation.',
            style: TextStyle(color: theme.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
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
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
        ),
        title: const Text(
          'LEAVE THE VOID?',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Color(0xFFD4AF37),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        content: const Text(
          'The void will remain in the rift, but this encounter will be lost if you return.',
          style: TextStyle(
            fontFamily: 'monospace',
            color: Colors.white54,
            fontSize: 11,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'STAY',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Colors.white38,
                letterSpacing: 1.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'LEAVE',
              style: TextStyle(
                fontFamily: 'monospace',
                color: Color(0xFFD4AF37),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) _hide(false);
  }

  void _hide([bool success = false]) {
    _slideController.reverse().then((_) {
      if (mounted) {
        widget.onClosedWithResult?.call(success);
      }
    });
    _fadeController.reverse();
    setState(() {
      _breedChance = null;
      _chosenInstanceId = null;
    });
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
            return Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Opacity(
                opacity: slide,
                child: _WildCreatureTitle(
                  creature: wildCreature,
                  rarity: widget.encounter.rarity,
                  status: _status,
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
                    status: _status,
                    canAct: !_busy,
                    isTutorial: widget.isTutorial, // 🆕 Pass tutorial flag
                    onBreed: !_busy
                        ? () => _handleBreed(context, wildCreature)
                        : null,
                    onCapture: !_busy
                        ? () => _handleCapture(context, wildCreature)
                        : null,
                    onRun: () => _handleRun(context),
                    breedChance: _breedChance,
                    showFusionAction: _supportsFusion,
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
      Icons.pets,
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
      _status = 'Selected ${hydrated.name}. Choose an action.';
      _chosenInstanceId = instanceId;
      _breedChance = p;
    });

    widget.onPartyCreatureSelected?.call(hydrated);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleBreed(BuildContext ctx, Creature wildCreature) async {
    if (_chosenInstanceId == null) {
      setState(() => _status = 'Select a partner first');
      return;
    }

    setState(() => _busy = true);

    try {
      final db = ctx.read<AlchemonsDatabase>();
      final repo = ctx.read<CreatureCatalog>();
      final wilderness = WildernessService(db, ctx.read<StaminaService>());

      final instance = await db.creatureDao.getInstance(_chosenInstanceId!);
      if (instance == null) {
        setState(() => _status = 'Error loading specimen data');
        return;
      }

      // --- Cross-species check BEFORE stamina / roll / cinematic ---
      final speciesA = repo.getCreatureById(instance.baseId);
      final speciesB = wildCreature;

      if (speciesA == null) {
        setState(() => _status = 'Error loading species data');
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
          _status = 'Further research required for cross-species fusion.';
        });
        return;
      }
      // --------------------------------------------------------------
      if (!ctx.mounted) return;
      final constellation = ctx.read<ConstellationEffectsService>();
      final p = _computeWildBreedChance(instance, wilderness, constellation);

      final spent = await wilderness.trySpendForAttempt(_chosenInstanceId!);
      if (spent == null) {
        setState(() => _status = 'Out of stamina!');
        return;
      }

      widget.onPreRollShake?.call();
      HapticFeedback.mediumImpact();
      setState(() => _status = 'Calibrating alchemical matrix…');
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
        await showAlchemyFusionCinematic<void>(
          context: ctx,
          leftSprite: partySprite(),
          rightSprite: wildSprite(),
          leftColor: colorA,
          rightColor: colorB,
          minDuration: const Duration(milliseconds: 1800),
          task: () async {
            await _breedWithWild(ctx, instance, speciesB);
          },
        );

        if (!mounted) return;
        setState(() => _status = 'Successfully fused.');

        // 🆕 Hide AFTER cinematic completes
        _hide(true);
      } else {
        setState(() => _status = 'Failed… try again.');
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
          );
        },
      );

      if (!mounted) return;

      if (success) {
        HapticFeedback.heavyImpact();
        setState(
          () => _status = 'Specimen sent to Cultivations for extraction',
        );

        if (!ctx.mounted) return;
        await _placeWildEgg(ctx, wildCreature);

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _hide(true);
      } else {
        HapticFeedback.lightImpact();
        setState(() => _status = 'Harvest failed!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Breed owned instance with wild creature using BreedingServiceV2
  Future<void> _breedWithWild(
    BuildContext ctx,
    db.CreatureInstance ownedParent,
    Creature? wildCreature,
  ) async {
    if (wildCreature == null) return;

    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();
    final randomizer = WildCreatureRandomizer();

    final engine = ctx.read<BreedingEngine>();
    final payloadFactory = EggPayloadFactory(repo);

    final breedingService = BreedingServiceV2(
      gameData: ctx.read<GameDataService>(),
      db: db,
      engine: engine,
      payloadFactory: payloadFactory,
      wildRandomizer: randomizer,
      constellation: ctx.read<ConstellationEffectsService>(),
      factions: ctx.read<FactionService>(),
    );

    // Single call: service will randomize wild, breed, and compute analysis.
    final result = await breedingService.breedWithWild(
      ownedParent,
      wildCreature,
      forcePrismatic: widget.encounter.voidBred,
      sourceOverride: widget.encounter.source,
    );

    if (!result.success) {
      if (mounted) {
        setState(() => _status = 'Breeding failed: ${result.message}');
      }
      return;
    }

    if (mounted) {
      setState(() => _status = 'Specimen sent to Cultivations for extraction');
    }
  }

  Future<void> _placeWildEgg(
    BuildContext ctx,
    Creature capturedCreature,
  ) async {
    final db = ctx.read<AlchemonsDatabase>();
    final repo = ctx.read<CreatureCatalog>();

    final rarityKey = capturedCreature.rarity.toLowerCase();
    final baseHatchDelay =
        BreedConstants.rarityHatchTimes[rarityKey] ??
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
    final payload = factory.createWildCapturePayload(
      capturedCreature,
      sourceOverride: widget.encounter.source,
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
class _WildCreatureTitle extends StatelessWidget {
  final Creature creature;
  final String rarity;
  final String status;

  const _WildCreatureTitle({
    required this.creature,
    required this.rarity,
    required this.status,
  });

  Color get _rarityColor {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade700;
      case 'uncommon':
        return Colors.green.shade600;
      case 'rare':
        return Colors.blue.shade600;
      case 'epic':
        return Colors.purple.shade600;
      case 'legendary':
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 2),
          margin: const EdgeInsets.only(left: 250, right: 250, bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        // Classification Rank badge (was Rarity)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _rarityColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _rarityColor.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            rarity.toUpperCase(), // Added 'RANK'
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.8, // Increased for a more technical look
            ),
          ),
        ),
        const SizedBox(height: 1),
        // Creature designation (was name)
        _DigitalAnimatedText(
          // <--- NEW WIDGET
          text: creature.name.toUpperCase(),
          duration: const Duration(milliseconds: 900),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 4.0,
            shadows: [
              Shadow(
                color: Colors.black87,
                blurRadius: 12,
                offset: Offset(0, 3),
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
    final t = ForgeTokens(context.read<FactionTheme>());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: t.bg1.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: t.borderDim, width: 1),
      ),
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
    );
  }
}

class _PartyMemberCard extends StatefulWidget {
  final PartyMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PartyMemberCard({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_PartyMemberCard> createState() => _PartyMemberCardState();
}

class _PartyMemberCardState extends State<_PartyMemberCard> {
  Future<CreatureInstance?>? _instanceFuture;
  String? _futureForInstanceId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureInstanceFuture();
  }

  @override
  void didUpdateWidget(covariant _PartyMemberCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.instanceId != widget.member.instanceId) {
      _ensureInstanceFuture(force: true);
    }
  }

  void _ensureInstanceFuture({bool force = false}) {
    if (!force &&
        _instanceFuture != null &&
        _futureForInstanceId == widget.member.instanceId) {
      return;
    }
    _futureForInstanceId = widget.member.instanceId;
    _instanceFuture = context.read<AlchemonsDatabase>().creatureDao.getInstance(
      widget.member.instanceId,
    );
  }

  @override
  Widget build(BuildContext context) {
    _ensureInstanceFuture();
    final repo = context.read<CreatureCatalog>();
    final stamina = context.read<StaminaService>();

    final t = ForgeTokens(context.read<FactionTheme>());

    return FutureBuilder<CreatureInstance?>(
      future: _instanceFuture,
      builder: (context, snap) {
        final inst = snap.data;
        final base = inst == null ? null : repo.getCreatureById(inst.baseId);
        final StaminaState? state = inst != null
            ? stamina.computeState(inst)
            : null;

        return GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: widget.selected ? t.amber.withValues(alpha: 0.12) : t.bg2,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: widget.selected ? t.amber : t.borderDim,
                width: widget.selected ? 1.5 : 1,
              ),
              boxShadow: widget.selected
                  ? [
                      BoxShadow(
                        color: t.amber.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
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
        );
      },
    );
  }
}

// ==========================================
// ACTION PANEL (Bottom) - Horizontal row
// ==========================================
class _ActionPanel extends StatelessWidget {
  final String status;
  final bool canAct;
  final VoidCallback? onBreed;
  final VoidCallback? onCapture;
  final VoidCallback onRun;
  final double? breedChance; // 👈 NEW
  final bool isPartySelected;
  final bool isTutorial; // 🆕 Tutorial mode flag
  final bool showFusionAction;

  const _ActionPanel({
    required this.status,
    required this.canAct,
    required this.onBreed,
    required this.onCapture,
    required this.onRun,
    required this.isPartySelected,
    this.breedChance,
    this.isTutorial = false, // 🆕 Default to false
    this.showFusionAction = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final chanceText = showFusionAction && breedChance != null
        ? 'Fusion success: ${(breedChance! * 100).toStringAsFixed(1)}%'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chanceText != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
              child: Text(
                chanceText,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: t.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (showFusionAction)
              _ActionButton(
                disabled: !isPartySelected,
                label: 'FUSION',
                sublabel: 'ATTEMPT ALCHEMICAL',
                icon: Icons.science_rounded,
                accentColor: t.success,
                onPressed: canAct ? onBreed : null,
              ),
            if (showFusionAction) const SizedBox(width: 8),
            if (!isTutorial)
              _ActionButton(
                label: 'HARVEST',
                sublabel: 'PROTOCOL',
                accentColor: t.danger,
                onPressed: canAct ? onCapture : null,
              ),
            if (!isTutorial) const SizedBox(width: 8),
            _ActionButton(
              label: 'MAP',
              sublabel: 'RETURN',
              accentColor: t.teal,
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
  final String sublabel;
  final IconData? icon;
  final Color accentColor;
  final VoidCallback? onPressed;
  final bool disabled;

  const _ActionButton({
    required this.label,
    required this.sublabel,
    required this.accentColor,
    this.icon,
    this.onPressed,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = ForgeTokens(context.read<FactionTheme>());
    final isDisabled = onPressed == null || disabled;
    final effectiveAccent = isDisabled ? t.textMuted : accentColor;

    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        decoration: BoxDecoration(
          color: t.bg1,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: isDisabled ? t.borderDim : effectiveAccent,
            width: 1.5,
          ),
          boxShadow: isDisabled
              ? null
              : [
                  BoxShadow(
                    color: effectiveAccent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isDisabled ? t.textMuted : effectiveAccent,
                size: 18,
              ),
              const SizedBox(width: 10),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sublabel,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isDisabled ? t.textMuted : t.textPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: isDisabled ? t.textMuted : effectiveAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
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
