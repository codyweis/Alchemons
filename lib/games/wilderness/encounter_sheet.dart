import 'package:alchemons/services/timed_boost_service.dart';
import 'package:alchemons/providers/audio_provider.dart' show AudioController;
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

import 'package:alchemons/services/campaign_journal_service.dart';
import 'dart:async';
import 'dart:math';
import 'package:alchemons/audio/audio.dart';
import 'package:alchemons/helpers/nature_loader.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/egg/egg_payload.dart';
import 'package:alchemons/models/elemental_group.dart';
import 'package:alchemons/models/parent_snapshot.dart';
import 'package:alchemons/models/stat_system.dart';
import 'package:alchemons/models/inventory.dart';
import 'package:alchemons/services/breeding_service.dart';
import 'package:alchemons/services/constellation_effects_service.dart';
import 'package:alchemons/services/faction_service.dart';
import 'package:alchemons/utils/nature_utils.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:alchemons/widgets/fx/breed_cinematic_fx.dart';
import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/widgets/fx/harvest_particles.dart';
import 'package:alchemons/widgets/fx/harvester_profile.dart';
import 'package:alchemons/games/wilderness/encounter_top_hud.dart';
import 'package:alchemons/widgets/harvester_glyph.dart';
import 'package:alchemons/widgets/wilderness/tutorial_highlight.dart'; // 🆕 Import highlight widget
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:alchemons/database/alchemons_db.dart';
import 'package:alchemons/database/alchemons_db.dart' as db;
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/services/wilderness_catch_service.dart';
import 'package:alchemons/services/wild_breed_randomizer.dart';
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/breeding_engine.dart';
import 'package:alchemons/constants/design_tokens.dart';
import 'package:alchemons/services/game_data_service.dart';
import 'package:alchemons/constants/breed_constants.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';
import 'package:alchemons/widgets/wilderness/device_selection_dialog.dart';
import 'package:alchemons/widgets/app_icons.dart';

// Wild encounters render over dark scene backdrops — always dark.
const _kPalette = BracketPalette.dark;

class EncounterOverlay extends StatefulWidget {
  final WildEncounter encounter;
  final List<PartyMember> party;
  final ValueChanged<bool>? onClosedWithResult;
  final ValueChanged<Creature>? onPartyCreatureSelected;
  final ValueChanged<Creature>? onWildCreaturePrepared;
  final VoidCallback? onPreRollShake;

  /// Plays the harvest on the creature standing in the scene and answers with
  /// the roll's result. Null hosts (the rift portal, the prologue) fall back
  /// to the old full-screen cinematic, which is still correct for a screen
  /// that has no scene to play in.
  final Future<bool> Function(
    Color accent,
    Future<bool> Function() task,
    HarvesterProfile profile,
  )?
  onHarvestInScene;

  /// Merges the party creature and the wild one where they stand, answering
  /// where on SCREEN they met and what they were made of — so the cinematic
  /// erupts there, in the same grains — or null if there was no pair to play
  /// on. Null hosts fall back to the route drawing the pair itself.
  final Future<FusionMergeHandoff?> Function(Color party, Color wild)?
  onFusionInScene;
  final Creature hydratedWildCreature;
  final bool highlightPartyHUD; // 🆕 Tutorial highlighting
  final bool isTutorial; // 🆕 Tutorial mode flag
  final bool isCaptureTutorial;
  final bool warnOnRun; // show a confirmation before running away
  final bool showFusionAction;
  // Whether to show the "Map" (return-to-map) action. Portal and planet
  // encounters have their own exit affordance, so they hide it.
  final bool showMapAction;

  /// Whether to show the rarity classification badge above the creature name.
  /// Scripted encounters where the rarity is a fixed authored detail (the
  /// cosmic prologue) hide it rather than announce "LEGENDARY".
  final bool showRarityBadge;

  /// A harvest or fusion roll failed. The encounter stays open for another
  /// try; the host decides what a failure costs.
  final VoidCallback? onAttemptFailed;

  /// The fusion catalyst is spent and the roll is about to be made: the host
  /// can start drawing the pair toward each other through the wait.
  final VoidCallback? onFusionCalibrating;

  /// The fusion roll failed. Awaited, so the host can play the pair
  /// recoiling apart before the panel reports it.
  final Future<void> Function(Color party, Color wild)? onFusionFailedInScene;

  /// Overrides for the leave confirmation shown when [warnOnRun] is set.
  final String? runWarningTitle;
  final String? runWarningBody;

  /// Added to the harvest chance — a specimen worn down in a fight is
  /// easier to hold.
  final double harvestBonus;

  /// Identity pinned top-left instead of centred, for hosts that stage the
  /// creatures themselves in the middle of the frame.
  final bool dossierHud;

  /// A Leave action at the bottom-left, for hosts with no Map action and no
  /// exit of their own.
  final bool showLeaveAction;

  /// A fusion here is a wilderness fusion: its child can come out mutated
  /// ([AlchemonMutation]). Off for space, whose fusions never mutate.
  final bool fieldMutations;

  const EncounterOverlay({
    super.key,
    required this.encounter,
    required this.party,
    this.onClosedWithResult,
    this.onPartyCreatureSelected,
    this.onWildCreaturePrepared,
    this.onPreRollShake,
    this.onHarvestInScene,
    this.onFusionInScene,
    required this.hydratedWildCreature,
    this.highlightPartyHUD = false, // 🆕 Default to false
    this.isTutorial = false, // 🆕 Default to false
    this.isCaptureTutorial = false,
    this.warnOnRun = false,
    this.showFusionAction = true,
    this.showMapAction = true,
    this.showRarityBadge = true,
    this.onAttemptFailed,
    this.onFusionCalibrating,
    this.onFusionFailedInScene,
    this.runWarningTitle,
    this.runWarningBody,
    this.harvestBonus = 0,
    this.dossierHud = false,
    this.showLeaveAction = false,
    this.fieldMutations = false,
  });

  @override
  State<EncounterOverlay> createState() => _EncounterOverlayState();
}

/// What a wild fusion came to: the line the result notice carries, whether it
/// landed or not.
typedef _FusionOutcome = ({bool ok, String message});

class _EncounterOverlayState extends State<EncounterOverlay>
    with TickerProviderStateMixin {
  bool _visible = false; // ignore: unused_field
  String? _chosenInstanceId;
  bool _busy = false;
  bool _wildReady = false;

  int _wildFusionQty = 0;

  /// Which harvester the Harvest button draws. Null until the kit answers.
  String? _harvesterBiome;
  late Creature _wildCreature;

  late final AnimationController _slideController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final AnimationController _fadeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  AudioController? _soundController;

  @override
  void initState() {
    super.initState();
    _soundController = context.audio;
    _wildCreature = widget.hydratedWildCreature;
    // Auto-show on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _show();
      _prepareWildEncounter();
    });
  }

  Future<void> _prepareWildEncounter() async {
    final database = context.read<AlchemonsDatabase>();
    final arcaneBoostUnlocked = await database.settingsDao
        .isArcanePortalUnlocked();
    final prepared = WildCreatureRandomizer().randomizeWildCreature(
      _wildCreature,
      arcaneBoostUnlocked: arcaneBoostUnlocked,
    );
    final qty = await WildernessService(database).wildFusionQuantity();
    if (!mounted) return;
    setState(() {
      _wildCreature = prepared;
      _wildFusionQty = qty;
      _wildReady = true;
    });
    widget.onWildCreaturePrepared?.call(prepared);
    await _resolveHarvesterGlyph();
    await _maybeExplainWildPotential();
  }

  static const _wildPotentialIntroKey = 'wild_fusion_top_potential_intro_v1';

  /// Once, the first fusable encounter after the Wild Potential Scanner is
  /// unlocked: what the gold figure on the plate means. Before the scanner
  /// the rule still holds; there is just nothing on screen to point at.
  Future<void> _maybeExplainWildPotential() async {
    if (!mounted || !_supportsFusion) return;
    if (!context
        .read<ConstellationEffectsService>()
        .hasWildPotentialAnalyzer()) {
      return;
    }
    final settings = context.read<AlchemonsDatabase>().settingsDao;
    if (await settings.getSetting(_wildPotentialIntroKey) != null) return;
    await settings.setSetting(_wildPotentialIntroKey, '1');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        const gold = Color(0xFFE4C16A);
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: CustomPaint(
              painter: BracketFramePainter(
                color: gold.withValues(alpha: 0.85),
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
                        Container(width: 3, height: 24, color: gold),
                        const SizedBox(width: AppSpace.md),
                        Expanded(
                          child: Text(
                            'Wild fusion',
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
                      'Fusing with a wild Alchemon always passes its highest '
                      'Potential to the offspring.\n\n'
                      'The Potential that passes is the one shown in gold.',
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
                      onTap: ctx.soundAction(() => Navigator.of(ctx).pop()),
                      behavior: HitTestBehavior.opaque,
                      child: CustomPaint(
                        painter: BracketFramePainter(
                          color: gold,
                          bracketSize: 8,
                          strokeWidth: 1.2,
                        ),
                        child: Container(
                          height: 42,
                          alignment: Alignment.center,
                          color: gold.withValues(alpha: 0.14),
                          child: Text(
                            'Got it',
                            style: bracketText(
                              ctx,
                              13,
                              gold,
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

  /// Work out which device the Harvest button should be drawn as.
  ///
  /// The button is a picture of the thing you are about to spend, so it asks
  /// the field kit rather than the biome: an element harvester is what a
  /// player reaches for first, the stabilized unit is the fallback they own,
  /// and an empty kit still names the device they need to go and buy.
  Future<void> _resolveHarvesterGlyph() async {
    final creature = _wildCreature;
    final usable = await context.read<CatchService>().getUsableDevices(
      creature,
    );
    CatchDeviceType? pick;
    for (final device in usable) {
      if (device != CatchDeviceType.guaranteed) {
        pick = device;
        break;
      }
    }
    pick ??= usable.isEmpty ? null : usable.first;

    final String biome;
    if (pick != null) {
      biome = harvesterBiomeForKey(pick.inventoryKey) ?? universalHarvester;
    } else {
      final group = elementalGroupOf(creature);
      biome = group == null ? universalHarvester : groupIdFrom(group);
    }

    if (!mounted || biome == _harvesterBiome) return;
    setState(() => _harvesterBiome = biome);
  }

  /// The four Potential ratings, or null when this specimen carries no stat
  /// block. Only ever called once the Wild Potential Scanner is unlocked —
  /// a locked scanner leaves the readout absent rather than blank.
  List<WildPotentialReading>? _wildPotentialReadings(Creature c) {
    final stats = c.stats;
    if (stats == null) return null;
    return [
      (label: 'SPD', value: stats.speedPotential),
      (label: 'INT', value: stats.intelligencePotential),
      (label: 'STR', value: stats.strengthPotential),
      (label: 'BEA', value: stats.beautyPotential),
    ];
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
      boosts: ctx.read<TimedBoostService>(),
      factions: ctx.read<FactionService>(),
    );
  }

  double _computeWildBreedChance(
    db.CreatureInstance instance,
    WildernessService wilderness,
    ConstellationEffectsService constellation,
  ) {
    // Preserve the old 1-5% Beauty contribution and allow Power above 100 to
    // extend it gradually instead of dividing an internal stat by a UI scale.
    final totalLuck =
        0.01 + AlchemonStatSystem.combatProgress(instance.statBeauty) * 0.04;
    final harvestBonus = constellation.getWildernessHarvestBonus();
    final natureBonus = wildFusionStabilityBonusForNatures(
      instance.natureId,
      instance.natureId2,
    );

    return wilderness.computeBreedChance(
      base: widget.encounter.baseBreedChance,
      partyLuck: totalLuck,
      matchupMult: 1.0,
      wildernessBonus: harvestBonus + natureBonus,
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
                      onTap: context.soundAction(() => Navigator.of(ctx).pop()),
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
    final confirmed = await showBracketConfirm(
      context,
      palette: _kPalette,
      accent: kLeaveDangerAccent,
      title: widget.runWarningTitle ?? 'LEAVE THE VOID?',
      message:
          widget.runWarningBody ??
          'The void will remain in the rift, but this encounter will be '
              'lost if you return.',
      cancelLabel: 'STAY',
      confirmLabel: 'LEAVE',
    );
    if (confirmed) _hide(false);
  }

  void _hide([bool success = false]) {
    setState(() => _chosenInstanceId = null);
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
    _soundController?.stopSoundOwner(this);
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wildCreature = _wildCreature;
    final showWildPotentials = context
        .watch<ConstellationEffectsService>()
        .hasWildPotentialAnalyzer();
    return Stack(
      children: [
        // Top band: specimen identity, field status and the party strip, all
        // laid out together so they cannot land on top of each other.
        AnimatedBuilder(
          animation: _slideController,
          builder: (_, __) {
            final slide = Curves.easeOutCubic.transform(_slideController.value);
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    kEncounterHudEdgePad,
                    kEncounterHudEdgePad,
                    kEncounterHudEdgePad,
                    0,
                  ),
                  child: WildEncounterTopHud(
                    name: wildCreature.name,
                    rarity: widget.encounter.rarity,
                    showRarityBadge: widget.showRarityBadge,
                    potentials: showWildPotentials
                        ? _wildPotentialReadings(wildCreature)
                        : null,
                    // Readings are in StatKind order, so its index is the
                    // reading's.
                    passingPotential: _supportsFusion
                        ? wildTopPotential(wildCreature.stats)?.stat.index
                        : null,
                    opacity: slide,
                    dossier: widget.dossierHud,
                    leftGutter: widget.dossierHud ? 0 : kEncounterHudLeftGutter,
                    partyStripWidth: _supportsFusion
                        ? partyStripGutterFor(
                            widget.party.length,
                            withCallout:
                                widget.highlightPartyHUD &&
                                _chosenInstanceId == null,
                          )
                        : 0,
                    partyStrip: _supportsFusion
                        ? Transform.translate(
                            // Slides in from off-screen without taking any
                            // layout room with it.
                            offset: Offset(300 * (1 - slide), 0),
                            child: Opacity(
                              opacity: slide,
                              child: TutorialHighlight(
                                enabled:
                                    widget.highlightPartyHUD &&
                                    _chosenInstanceId == null, // 🆕
                                label: 'Tap an ally to fuse',
                                child: _PartyHUD(
                                  party: widget.party,
                                  chosenInstanceId: _chosenInstanceId,
                                  onSelect: _onSelectPartyCreature,
                                ),
                              ),
                            ),
                          )
                        : null,
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
                    canAct: !_busy && _wildReady,
                    isTutorial: widget.isTutorial, // 🆕 Pass tutorial flag
                    isCaptureTutorial: widget.isCaptureTutorial,
                    onBreed: !_busy
                        ? () => _handleBreed(context, wildCreature)
                        : null,
                    onCapture: !_busy
                        ? () => _handleCapture(context, wildCreature)
                        : null,
                    onRun: () {
                      if (!_busy) _handleRun(context);
                    },
                    showLeaveAction: widget.showLeaveAction,
                    showFusionAction: _supportsFusion,
                    showMapAction: widget.showMapAction,
                    wildFusionQty: _wildFusionQty,
                    harvesterBiome: _harvesterBiome,
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
          costumes: visuals.costumes,
          variantFaction: visuals.variantFaction,
          elementType: visuals.elementType,
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

    final instRow = await db.creatureDao.getInstance(instanceId);
    if (instRow == null) return;

    final baseCreature = repo.getCreatureById(instRow.baseId);
    if (baseCreature == null) return;

    final hydrated = baseCreature.copyWith(
      genetics: decodeGenetics(instRow.geneticsJson),
      nature: instRow.natureId != null
          ? NatureCatalog.byId(instRow.natureId!)
          : baseCreature.nature,
      nature2: instRow.natureId2 != null
          ? NatureCatalog.byId(instRow.natureId2!)
          : baseCreature.nature2,
      isPrismaticSkin: instRow.isPrismaticSkin || baseCreature.isPrismaticSkin,
      wildMutation: instRow.mutation,
    );

    if (!mounted) return;
    setState(() => _chosenInstanceId = instanceId);

    widget.onPartyCreatureSelected?.call(hydrated);
    HapticFeedback.selectionClick();
  }

  Future<void> _handleBreed(BuildContext ctx, Creature wildCreature) async {
    // The button is off until an ally is chosen.
    if (_chosenInstanceId == null) return;

    setState(() => _busy = true);

    try {
      final db = ctx.read<AlchemonsDatabase>();
      final repo = ctx.read<CreatureCatalog>();
      final breedingService = _buildBreedingService(ctx);
      final wilderness = WildernessService(db);

      final instance = await db.creatureDao.getInstance(_chosenInstanceId!);
      if (instance == null) {
        if (ctx.mounted) _notify(ctx, 'Fusion failed', 'Specimen sync failed.');
        return;
      }

      // --- Cross-species check BEFORE item spend / roll / cinematic ---
      final speciesA = repo.getCreatureById(instance.baseId);
      final speciesB = wildCreature;

      if (speciesA == null) {
        if (ctx.mounted) {
          _notify(ctx, 'Fusion failed', 'Wild record lookup failed.');
        }
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
        return;
      }

      final placementFailure = await breedingService
          .getEggPlacementFailureMessage(requireStorageCapacity: false);
      if (placementFailure != null) {
        if (ctx.mounted) _notify(ctx, 'Fusion blocked', placementFailure);
        return;
      }
      // --------------------------------------------------------------
      if (!ctx.mounted) return;
      final constellation = ctx.read<ConstellationEffectsService>();
      final p = _computeWildBreedChance(instance, wilderness, constellation);

      final consumed = await wilderness.consumeWildFusion();
      if (!consumed) {
        setState(() => _wildFusionQty = 0);
        if (ctx.mounted) {
          _notify(
            ctx,
            'Fusion blocked',
            'A Wild Fusion catalyst is required for this attempt.',
          );
        }
        return;
      }
      if (mounted) setState(() => _wildFusionQty = max(0, _wildFusionQty - 1));

      widget.onPreRollShake?.call();
      widget.onFusionCalibrating?.call();
      HapticFeedback.mediumImpact();
      // The pair turn to grains where they stand and wait on the verdict:
      // the first piece of the same merge the breed chamber plays.
      if (ctx.mounted) ctx.sound(SoundCue.fusionCalibrate, owner: this);
      await Future.delayed(const Duration(milliseconds: 650));

      final success = wilderness.rollSuccess(p);
      if (success) {
        // The achievement is for fusions that landed, not charges spent.
        await CampaignJournalService.bump(
          wilderness.db.settingsDao,
          'wildFusions',
        );
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

        // THE PAIR MERGE IN THE SCENE, then the route plays the burst.
        //
        // Both creatures are live components standing in the encounter, so
        // pushing a route with freshly built copies of them meant the two you
        // were looking at blinked out and two duplicates did the fusing. The
        // scene hauls the real ones into each other and consumes them; by the
        // time the route opens there is nothing left to duplicate, so it is
        // told not to draw any specimens at all.
        final mergeInScene = widget.onFusionInScene;
        // Same stage-clearing as the extraction: the pair meet in the scene,
        // and this panel is sitting on top of half of it.
        if (mergeInScene != null) {
          _slideController.reverse();
          _fadeController.reverse();
          await Future<void>.delayed(const Duration(milliseconds: 260));
          if (!mounted) return;
        }
        // The rest of the merge, from where the pair have been standing.
        if (mergeInScene != null && ctx.mounted) {
          ctx.sound(SoundCue.fusionPour, owner: this);
        }
        final handoff = mergeInScene == null
            ? null
            : await mergeInScene(colorA, colorB);
        final merged = handoff != null;

        if (!ctx.mounted) return;
        final outcome = await showAlchemyFusionCinematic<_FusionOutcome>(
          context: ctx,
          leftSprite: partySprite(),
          rightSprite: wildSprite(),
          drawSpecimens: !merged,
          // Put the core where the two actually came together. Left to its
          // default it lands in the middle of the display, so the alchemy
          // played somewhere the fusion had not happened.
          coreRect: handoff?.at,
          // And make the eruption of what they were made of.
          grains: handoff?.grains,
          leftColor: colorA,
          rightColor: colorB,
          minDuration: Duration(milliseconds: merged ? 2600 : 4350),
          task: () async {
            return _breedWithWild(ctx, instance, speciesB, breedingService);
          },
        );

        if (outcome == null || !outcome.ok) {
          // The fusion failed: the panel comes back so the player can try
          // something else, rather than being left staring at the scene.
          if (mergeInScene != null && mounted) {
            _slideController.forward();
            _fadeController.forward();
          }
          if (outcome != null && ctx.mounted) {
            _notify(ctx, 'Fusion failed', outcome.message);
          }
          return;
        }
        if (!mounted || !ctx.mounted) return;

        // Show it BEFORE closing. Closing the encounter tears down the
        // scene page under this sheet, and a snackbar posted into a
        // messenger that is on its way out never reaches the screen.
        final messenger = ScaffoldMessenger.maybeOf(ctx);
        if (messenger != null) {
          _showResultNotification(
            messenger,
            'Fusion complete',
            outcome.message,
          );
        }
        _hide(true);
      } else {
        HapticFeedback.lightImpact();
        // The grains run back into the pair.
        if (ctx.mounted) ctx.sound(SoundCue.fusionRecoil, owner: this);
        if (widget.isTutorial) {
          await db.inventoryDao.addItemQty(InvKeys.wildFusion, 1);
          if (mounted) setState(() => _wildFusionQty++);
        }
        widget.onAttemptFailed?.call();
        final recoil = widget.onFusionFailedInScene;
        if (recoil != null && ctx.mounted) {
          final repo = ctx.read<CreatureCatalog>();
          Color colorOf(Creature? c) => c != null && c.types.isNotEmpty
              ? BreedConstants.getTypeColor(c.types.first)
              : Colors.white;
          await recoil(
            colorOf(repo.getCreatureById(instance.baseId)),
            colorOf(wildCreature),
          );
          if (!mounted) return;
        } else if (ctx.mounted) {
          // No recoil in this host's scene, so nothing else would say it.
          _notify(ctx, 'Fusion failed', 'The fusion destabilized. Try again.');
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCapture(BuildContext ctx, Creature wildCreature) async {
    setState(() => _busy = true);
    StreamSubscription<HarvestBeat>? beats;

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

      Color colorOf(Creature? c, Color fallback) =>
          c != null && c.types.isNotEmpty
          ? BreedConstants.getTypeColor(c.types.first)
          : fallback;

      final targetColor = colorOf(wildCreature, Colors.green);

      if (!ctx.mounted) return;
      ctx.sound(SoundCue.captureThrow, owner: this);

      // CLEAR THE STAGE.
      //
      // The extraction plays on the creature standing in the scene, and this
      // panel covers the bottom half of it — so the shot used to be half
      // hidden behind the thing that started it. The sheet retracts first,
      // the camera leans in behind it, and only then does the field engage;
      // three cuts became one move. It comes back if the specimen breaks out.
      final retracted = widget.onHarvestInScene != null;
      if (retracted) {
        _slideController.reverse();
        _fadeController.reverse();
        // Long enough to read as the panel getting out of the way, short
        // enough that it never feels like waiting.
        await Future<void>.delayed(const Duration(milliseconds: 260));
        if (!mounted) return;
      }

      // The shake lands as the field arrives, not before the stage is clear.
      widget.onPreRollShake?.call();
      // The field says when it engages, takes and breaks, whichever host is
      // playing it; each sound goes on that frame.
      beats = HarvestParticleField.beats.listen((beat) {
        if (!ctx.mounted) return;
        ctx.sound(switch (beat) {
          HarvestBeat.engage => SoundCue.captureAttempt,
          HarvestBeat.take => SoundCue.captureSuccess,
          HarvestBeat.shatter => SoundCue.captureEscape,
        }, owner: this);
      });

      Future<bool> roll() async {
        final catchService = ctx.read<CatchService>();
        return catchService.attemptCatch(
          device: selectedDevice,
          target: wildCreature,
          forceSuccess: widget.isCaptureTutorial,
          bonusChance: widget.harvestBonus,
        );
      }

      // THE HARVEST PLAYS IN THE SCENE, on the creature standing in it.
      //
      // This used to push a full-screen route holding a freshly built copy of
      // the sprite: the animal you had been looking at blinked out and a
      // duplicate appeared on a black card. The scene owns the animation now —
      // the field closes on the live component and drives its transform — so
      // there is one creature, and the world keeps running behind it.
      // Which device is doing this decides how the field behaves — a Crusher
      // arrives in stages and grinds, a Snare cinches and writhes. Both the
      // in-scene field and the full-screen fallback read the same profile.
      final harvester = HarvesterProfile.forInventoryKey(
        selectedDevice.inventoryKey,
      );

      final playInScene = widget.onHarvestInScene;
      final bool success;
      if (playInScene != null) {
        success = await playInScene(targetColor, roll, harvester);
      } else {
        if (!ctx.mounted) return;
        success = await showHarvestCinematic(
          context: ctx,
          targetSprite: _buildWildSprite(wildCreature),
          targetColor: targetColor,
          profile: harvester,
          minDuration: const Duration(milliseconds: 1600),
          task: roll,
        );
      }

      if (!mounted) return;

      // Bring the panel back for the aftermath — unless the run is over, in
      // which case the encounter closes and it would only flash.
      if (retracted && !success) {
        _slideController.forward();
        _fadeController.forward();
      }

      if (success) {
        HapticFeedback.heavyImpact();

        if (!ctx.mounted) return;
        // The panel is retracted on a success and the encounter closes right
        // after. Say it where it will actually be read.
        final messenger = ScaffoldMessenger.maybeOf(ctx);
        if (messenger != null) {
          _showResultNotification(
            messenger,
            'Extraction complete',
            'Specimen sent to Cultivations.',
          );
        }

        await _placeWildEgg(ctx, wildCreature);

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        _hide(true);
      } else {
        HapticFeedback.lightImpact();
        // The specimen breaking out is the message.
        widget.onAttemptFailed?.call();
      }
    } catch (e) {
      if (mounted && ctx.mounted) _notify(ctx, 'Encounter error', '$e');
    } finally {
      await beats?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Breed owned instance with wild creature using BreedingServiceV2
  Future<_FusionOutcome> _breedWithWild(
    BuildContext ctx,
    db.CreatureInstance ownedParent,
    Creature? wildCreature,
    BreedingServiceV2 breedingService,
  ) async {
    if (wildCreature == null) {
      return (ok: false, message: 'Wild record lookup failed.');
    }

    // The debug tools can force this fusion's mutation (one-shot).
    final debug = DebugSettingsService();
    final forcedId = widget.fieldMutations
        ? await debug.pendingForcedWildMutation()
        : null;

    // Single call: service will randomize wild, breed, and compute analysis.
    final result = await breedingService.breedWithWild(
      ownedParent,
      wildCreature,
      customHatchDuration: widget.isTutorial
          ? const Duration(seconds: 30)
          : null,
      forcePrismatic: widget.encounter.voidBred,
      sourceOverride: widget.encounter.source,
      fieldMutations: widget.fieldMutations,
      forcedMutation: AlchemonMutation.byId(forcedId),
    );
    if (result.success && forcedId != null) {
      await debug.setForcedWildMutation(null);
    }

    if (!result.success) {
      return (ok: false, message: result.message ?? 'The fusion did not take.');
    }

    return (
      ok: true,
      message: result.placement == EggPlacement.storage
          ? 'Cultivation chambers were full — the specimen was moved to cold storage.'
          : 'The new specimen was sent to a cultivation chamber.',
    );
  }

  /// A setback nothing on screen would otherwise show — a failed lookup, a
  /// missing catalyst. The rest the encounter says with the creatures and the
  /// buttons; there is no status line to write it on.
  void _notify(BuildContext ctx, String title, String message) {
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    if (messenger == null) return;
    _showResultNotification(messenger, title, message, failed: true);
  }

  /// Lightweight, non-blocking result notification. The one piece of
  /// feedback that survives the panel getting out of the way: both the
  /// harvest and the fusion retract the sheet to clear the stage, and the
  /// encounter closes on a success. [failed] draws it in ember, for the
  /// setbacks [_notify] reports.
  void _showResultNotification(
    ScaffoldMessengerState messenger,
    String title,
    String message, {
    bool failed = false,
  }) {
    final accent = failed ? const Color(0xFFE0785A) : const Color(0xFF22C55E);
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
            color: accent.withValues(alpha: 0.85),
            bracketSize: 9,
            strokeWidth: 1.2,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF12161D),
              border: Border(left: BorderSide(color: accent, width: 3)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: [
                Icon(
                  failed
                      ? AppIcons.warning_amber_rounded
                      : AppIcons.check_circle_rounded,
                  color: accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
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
    final natureMult = hatchMultForNatures(
      capturedCreature.nature?.id,
      capturedCreature.nature2?.id,
    );
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
        // Same constants the top band reserves its right-hand gutter from,
        // so the strip can never be wider than the room kept for it.
        padding: const EdgeInsets.all(kPartyStripPadding),
        color: _kPalette.surfaceFill(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < party.length; i++) ...[
              _PartyMemberCard(
                member: party[i],
                selected: party[i].instanceId == chosenInstanceId,
                onTap: context.soundTap(() => onSelect(party[i].instanceId)),
              ),
              if (i < party.length - 1) const SizedBox(width: kPartyCardGap),
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

        return GestureDetector(
          onTap: context.soundAction(onTap),
          child: CustomPaint(
            painter: BracketFramePainter(
              color: selected
                  ? selAccent
                  : _kPalette.line.withValues(alpha: 0.7),
              bracketSize: 6,
              strokeWidth: selected ? 1.4 : 1.0,
            ),
            child: Container(
              width: kPartyCardWidth,
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
/// Button and dialog text: parchment, tinted by the action's colour.
const Color _parchment = Color(0xFFE8DCC8);

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
  final int wildFusionQty;

  /// Element of the harvester the player is about to spend, so the action
  /// draws as that device. Null until the field kit has been read.
  final String? harvesterBiome;

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
    this.wildFusionQty = 0,
    this.harvesterBiome,
    this.showLeaveAction = false,
  });

  final bool showLeaveAction;

  @override
  Widget build(BuildContext context) {
    // The same meanings as before — fuse, harvest, map — in the game's own
    // muted materials rather than signal green, red and cyan.
    const success = Color(0xFF8CC9A8); // verdigris
    const danger = Color(0xFFE0785A); // ember
    const teal = Color(0xFF7FB6C6); // tarnished silver-blue

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (showLeaveAction) ...[
              _ActionButton(
                label: 'Leave',
                accentColor: _kPalette.muted,
                onPressed: canAct ? onRun : null,
              ),
              const Spacer(),
            ],
            if (showFusionAction && !isCaptureTutorial) ...[
              _ActionButton(
                disabled: !isPartySelected || wildFusionQty < 1,
                label: 'Wild Fusion ×$wildFusionQty',
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
                  glyphBiome: harvesterBiome,
                  accentColor: danger,
                  onPressed: canAct ? onCapture : null,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
            if (!isCaptureTutorial && showMapAction)
              _ActionButton(
                label: 'Back',
                accentColor: teal,
                onPressed: context.soundAction(onRun),
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback? onPressed;
  final bool disabled;

  /// Draws the painted harvester before the label — the shop, the inventory
  /// and the space market all show the device this way, and this is where the
  /// player actually spends it.
  final String? glyphBiome;

  const _ActionButton({
    required this.label,
    required this.accentColor,
    this.onPressed,
    this.disabled = false,
    this.glyphBiome,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || disabled;
    final accent = isDisabled ? const Color(0xFF4A443D) : accentColor;
    final ink = isDisabled
        ? const Color(0xFF7A7166)
        : Color.lerp(accentColor, _parchment, 0.5)!;

    return GestureDetector(
      onTap: context.soundAction(isDisabled ? null : onPressed),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // Opaque, so it reads on any backdrop, with the action's colour
          // rising from its foot like light from below — not a neon rim.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF0B0A0E),
              Color.lerp(
                const Color(0xFF0B0A0E),
                accent,
                isDisabled ? 0.03 : 0.16,
              )!,
            ],
          ),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: accent.withValues(alpha: isDisabled ? 0.7 : 0.62),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyphBiome != null) ...[
              HarvesterGlyph(
                biomeId: glyphBiome!,
                size: 22,
                // Greyed out it is not a device you can use, so it stops
                // beating and stops asking for frames.
                color: isDisabled ? _kPalette.muted : null,
                animate: !isDisabled,
              ),
              const SizedBox(width: 9),
            ],
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                color: ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
