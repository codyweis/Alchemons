import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'package:alchemons/database/alchemons_db.dart';
import 'dart:async';
import 'package:alchemons/services/campaign_journal_service.dart';
import 'package:alchemons/audio/audio.dart';
// lib/screens/scenes/rift_portal_screen.dart
import 'dart:math';
import 'package:alchemons/games/wilderness/encounter_sheet.dart';
import 'package:alchemons/games/wilderness/rift_portal_component.dart';
import 'package:alchemons/models/creature.dart';
import 'package:alchemons/models/encounters/encounter_pool.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';

class RiftPortalScreen extends StatefulWidget {
  final RiftFaction faction;

  /// Party members available inside the void (already filtered to compatible
  /// by [_RiftVoidPage] before navigating here).
  final List<PartyMember> party;

  /// The orientation to hand back on the way out. Portrait for space;
  /// a wilderness rift passes landscape, since the scene behind it is.
  final List<DeviceOrientation> returnOrientation;

  const RiftPortalScreen({
    super.key,
    required this.faction,
    this.party = const [],
    this.returnOrientation = const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ],
  });

  @override
  State<RiftPortalScreen> createState() => _RiftPortalScreenState();
}

class _RiftPortalScreenState extends State<RiftPortalScreen>
    with TickerProviderStateMixin {
  late AnimationController _bannerCtrl;

  /// The inside of the rift: the same vortex its threshold showed, seen
  /// huge now, with the waiting Alchemon in its black eye. Slower than the
  /// threshold's, since its rim is wider than the screen.
  final RiftVortexField _vortex = RiftVortexField(
    grains: 2200,
    ringGrains: 300,
    motes: 90,
    core: 0.2,
    speed: 0.4,
    grainSize: 1.7,
  );
  late final RiftPalette _palette = RiftPalette(widget.faction.primaryColor);
  late final Ticker _vortexTicker;
  final ValueNotifier<double> _vortexClock = ValueNotifier(0);
  Duration _vortexLast = Duration.zero;

  Creature? _voidCreature;

  /// The void creature is read into grains from here when a harvest takes
  /// it, and cut away behind the take's crest ([_harvestCut]).
  final GlobalKey _voidCaptureKey = GlobalKey();
  double? _harvestCut;
  EncounterRarity _voidRarity = EncounterRarity.common;
  bool _spawned = false;
  bool _spawnScheduled = false;
  Animation<double>? _routeAnimation;
  final bool _encounterActive = true;
  Creature? _selectedPartyCreature;

  @override
  void initState() {
    super.initState();
    // Arriving on this screen is entering the rift; there is no other way in.
    unawaited(
      CampaignJournalService.mark(
        context.read<AlchemonsDatabase>().settingsDao,
        'portalEnter',
      ),
    );
    // Force landscape orientation inside the rift
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _bannerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _vortexTicker = createTicker((elapsed) {
      final dt = ((elapsed - _vortexLast).inMicroseconds / 1e6).clamp(
        0.0,
        0.05,
      );
      _vortexLast = elapsed;
      // Tears open round the Alchemon as the glyph portal fades away.
      _vortex.open = min(1.0, _vortex.open + dt / 1.6);
      _vortex.step(dt);
      _vortexClock.value = _vortex.time;
    })..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_spawned || _spawnScheduled) return;

    final routeAnimation = ModalRoute.of(context)?.animation;
    if (!identical(_routeAnimation, routeAnimation)) {
      _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = routeAnimation;
      _routeAnimation?.addStatusListener(_handleRouteAnimationStatus);
    }
    if (routeAnimation == null ||
        routeAnimation.status == AnimationStatus.completed) {
      _scheduleSpawnAfterTransition();
    }
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _scheduleSpawnAfterTransition();
  }

  void _scheduleSpawnAfterTransition() {
    if (_spawned || _spawnScheduled) return;
    _spawnScheduled = true;
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _spawned) return;
      _spawned = true;
      _spawnVoidCreature();
    });
  }

  void _spawnVoidCreature() {
    final repo = context.read<CreatureCatalog>();
    final rng = Random();

    // Select in one pass with weighted reservoir sampling. This avoids building
    // both a filtered list and an expanded weighted list on the UI isolate.
    // Mystic creatures remain excluded from the standard encounter pool.
    final matchTypes = widget.faction.matchingTypes;
    Creature? picked;
    var totalWeight = 0;
    for (final creature in repo.creatures) {
      if (creature.rarity.toLowerCase() == 'mystic' ||
          !creature.types.any(matchTypes.contains)) {
        continue;
      }
      final known = EncounterRarity.values.firstWhere(
        (rarity) => rarity.label == creature.rarity.toLowerCase(),
        orElse: () => EncounterRarity.rare,
      );
      final weight = (known.baseWeight / 5).round().clamp(1, 20);
      totalWeight += weight;
      if (rng.nextInt(totalWeight) < weight) picked = creature;
    }

    if (picked == null) {
      debugPrint('⚠️ No creatures match faction ${widget.faction.factionKey}');
      return;
    }

    // Derive encounter rarity from the creature's own rarity label.
    final rarity = EncounterRarity.values.firstWhere(
      (e) => e.label == picked!.rarity.toLowerCase(),
      orElse: () => EncounterRarity.rare,
    );

    // Generate a prismatic instance (100% prismatic chance for void spawns).
    final gen = WildlifeGenerator(
      repo,
      tuning: const WildlifeTuning(prismaticSkinChance: 1.0),
    );
    final hydrated = gen.generate(picked.id, rarity: rarity.label);
    if (hydrated == null) return;

    setState(() {
      _voidCreature = hydrated;
      _voidRarity = rarity;
    });
    _bannerCtrl.forward();
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    // Back to whatever is behind: portrait for space, matching every other
    // landscape screen ("all four" left the phone sideways on the way back
    // to a map that is portrait, because that is how it was being held) —
    // but landscape for the wilderness scene a rift was found in.
    SystemChrome.setPreferredOrientations(widget.returnOrientation);
    _vortexTicker.dispose();
    _vortexClock.dispose();
    _bannerCtrl.dispose();
    super.dispose();
  }

  /// The Portal Key is spent on entry, so leaving early costs it. The
  /// encounter's own run action already warns; this matches it.
  Future<void> _confirmExit(BuildContext context) async {
    HapticFeedback.lightImpact();
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(
            color: widget.faction.primaryColor.withValues(alpha: 0.6),
          ),
        ),
        title: const Text(
          'LEAVE THE RIFT?',
          style: TextStyle(
            color: Color(0xFFE8DCC8),
            fontFamily: 'monospace',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        content: const Text(
          'Your Portal Key is already spent. Leaving now takes you back with '
          'nothing from this rift.',
          style: TextStyle(color: Color(0xFF8A7B6A), fontSize: 12, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: context.soundAction(
              () => Navigator.of(dialogContext).pop(false),
            ),
            child: const Text(
              'Stay',
              style: TextStyle(color: Color(0xFF8A7B6A)),
            ),
          ),
          TextButton(
            onPressed: context.soundAction(
              () => Navigator.of(dialogContext).pop(true),
            ),
            child: Text(
              'Leave',
              style: TextStyle(
                color: widget.faction.primaryColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
    if (leave == true && context.mounted) {
      // false: the portal is not cleared, matching the run-away path.
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.faction.primaryColor;
    final factionName = widget.faction.displayName.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── The rift, from inside ─────────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _RiftInteriorPainter(
                    _vortex,
                    _palette,
                    repaint: _vortexClock,
                  ),
                ),
              ),
            ),
          ),

          // ── Header: the rift's name top-left, the way out top-right ──────
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'RIFT',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: color.withValues(alpha: 0.85),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$factionName RIFT',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFFE8DCC8),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Without this the only exits are through the encounter
                    // overlay, so a portal with no live encounter traps you.
                    _ExitPortalButton(
                      color: color,
                      onExit: () => _confirmExit(context),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Wild creature — centred over the portal ─────────────────────
          if (_voidCreature != null)
            Center(
              child: AnimatedBuilder(
                animation: _bannerCtrl,
                builder: (context, child) {
                  final t2 = Curves.easeOutCubic.transform(_bannerCtrl.value);
                  return Opacity(opacity: t2.clamp(0.0, 1.0), child: child);
                },
                child: ClipRect(
                  clipper: SpriteCrestClipper(
                    _harvestCut ?? double.negativeInfinity,
                  ),
                  clipBehavior: _harvestCut == null ? Clip.none : Clip.hardEdge,
                  child: RepaintBoundary(
                    key: _voidCaptureKey,
                    // Room for a size gene over 1, which draws past 170.
                    child: SizedBox.square(
                      dimension: 240,
                      child: Center(
                        child: _VoidSprite(
                          creature: _voidCreature!,
                          size: 170,
                          isPrismatic: true,
                          flipHorizontal: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Party creature — left side, flipped to face the wild ──────────
          if (_selectedPartyCreature != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.32,
              child: Center(
                child: _VoidSprite(
                  creature: _selectedPartyCreature!,
                  size: 140,
                  isPrismatic: _selectedPartyCreature!.isPrismaticSkin == true,
                  flipHorizontal: true, // face right → toward the wild
                ),
              ),
            ),

          // ── Encounter overlay (fuse / capture) ────────────────────────────
          if (_voidCreature != null && _encounterActive)
            EncounterOverlay(
              encounter: WildEncounter(
                wildBaseId: _voidCreature!.id,
                baseBreedChance: breedChanceForRarity(_voidRarity),
                rarity: _voidRarity.label,
                voidBred: true, // guarantees prismatic offspring on fuse
                source: 'rift_portal',
              ),
              hydratedWildCreature: _voidCreature!,
              party: widget.party,
              highlightPartyHUD: false,
              isTutorial: false,
              showFusionAction: false,
              showMapAction: false,
              warnOnRun: true,
              onPreRollShake: () {},
              // The rift is not a Flame scene, so it cannot hand the field
              // to the world the way the wilderness does — but it can still
              // avoid the duplicate. The apparatus plays transparently over
              // the void creature already standing here, which is centred
              // exactly where the field is.
              onHarvestInScene: (accent, task, profile) async {
                if (!mounted) return false;
                return showHarvestCinematic(
                  context: context,
                  targetSprite: null,
                  targetColor: accent,
                  deviceLabel: profile.biomeId.toUpperCase(),
                  profile: profile,
                  // And on a take, the void creature itself goes as grains.
                  liveTarget: HarvestTarget(
                    read: () async {
                      final box = _voidCaptureKey.currentContext
                          ?.findRenderObject();
                      if (box is! RenderRepaintBoundary || !box.attached) {
                        return null;
                      }
                      final centre = box.localToGlobal(
                        box.size.center(Offset.zero),
                      );
                      final grains = await SpecimenGrains.capture(
                        box,
                        pixelRatio: min(
                          MediaQuery.devicePixelRatioOf(context),
                          2.5,
                        ),
                      );
                      return grains == null ? null : (grains, centre, 1.0);
                    },
                    onCut: (cut) {
                      if (mounted) setState(() => _harvestCut = cut);
                    },
                  ),
                  task: task,
                );
              },
              onPartyCreatureSelected: (c) {
                setState(() => _selectedPartyCreature = c);
              },
              onClosedWithResult: (success) {
                if (!mounted) return;
                if (success) {
                  // Breed or catch succeeded — pop and signal the scene to
                  // clear the portal.
                  Navigator.of(context).pop(true);
                } else {
                  // Ran away — return to scene without clearing the portal.
                  Navigator.of(context).pop(false);
                }
              },
            ),
        ],
      ),
    );
  }
}

// ── Bare sprite — no borders, no labels ──────────────────────────────────────

class _VoidSprite extends StatelessWidget {
  final Creature creature;
  final double size;
  final bool isPrismatic;
  final bool flipHorizontal;

  const _VoidSprite({
    required this.creature,
    required this.size,
    required this.isPrismatic,
    required this.flipHorizontal,
  });

  @override
  Widget build(BuildContext context) {
    final visuals = visualsFromInstance(creature, null);

    Widget sprite;
    if (creature.spriteData != null) {
      final sheet = sheetFromCreature(creature);
      sprite = SizedBox(
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
          isPrismatic: isPrismatic,
          tint: visuals.tint,
        ),
      );
    } else {
      sprite = SizedBox(
        width: size,
        height: size,
        child: Icon(AppIcons.pets, color: Colors.white24, size: size * 0.5),
      );
    }

    if (flipHorizontal) {
      return Transform.scale(scaleX: -1, child: sprite);
    }
    return sprite;
  }
}

/// The rift from inside: the vortex huge, its black core round the waiting
/// Alchemon, so the light bent round the core haloes it.
class _RiftInteriorPainter extends CustomPainter {
  _RiftInteriorPainter(this.field, this.palette, {required super.repaint});

  final RiftVortexField field;
  final RiftPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    // The core just wider than the sprite standing in it, so the light
    // bent round the core haloes it; any bigger and the Alchemon is lost in
    // the black.
    final coreR = min(100.0, size.shortestSide * 0.27);
    field.paint(
      canvas,
      size,
      size.center(Offset.zero),
      coreR / field.core,
      palette,
    );
  }

  @override
  bool shouldRepaint(_RiftInteriorPainter old) =>
      old.field != field || old.palette != palette;
}

class _ExitPortalButton extends StatelessWidget {
  const _ExitPortalButton({required this.color, required this.onExit});

  final Color color;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: context.soundAction(onExit),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        // Matches the encounter's buttons: dark, rounded, the rift's colour
        // as a quiet rim.
        decoration: BoxDecoration(
          color: const Color(0xFF0B0A0E).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Icon(AppIcons.close_rounded, color: color, size: 20),
      ),
    );
  }
}
