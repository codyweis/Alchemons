import 'package:alchemons/widgets/fx/fusion_particles.dart';
import 'package:alchemons/widgets/fx/harvest_cinematic.dart';
import 'dart:ui' as ui;
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
import 'package:alchemons/models/wild_fusion.dart';
import 'package:alchemons/models/wilderness.dart';
import 'package:alchemons/services/creature_repository.dart';
import 'package:alchemons/services/debug_settings_service.dart';
import 'package:alchemons/services/web_ads.dart';
import 'package:alchemons/services/wildlife_generator.dart';
import 'package:alchemons/services/wilderness_service.dart';
import 'package:alchemons/utils/sprite_sheet_def.dart';
import 'package:alchemons/widgets/fx/mutation_sheets.dart';
import 'package:alchemons/widgets/fx/rift_mutation_roll.dart';
import 'package:alchemons/widgets/fx/rift_vortex.dart';
import 'package:alchemons/widgets/creature_sprite.dart';
import 'package:flame/flame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:alchemons/widgets/app_icons.dart';
import 'package:alchemons/widgets/bracket_controls.dart';
import 'package:alchemons/widgets/bracket_frame.dart';

/// The species waiting in a [faction] rift, weighted by rarity. Mystic
/// creatures stay out of rifts, as they do out of every encounter pool.
///
/// The threshold picks it before the key turns, so it can ask for a
/// harvester that holds this one; a seeded [rng] keeps the same rift showing
/// the same species however often it is opened.
Creature? pickRiftSpecies(
  CreatureCatalog repo,
  RiftFaction faction,
  Random rng,
) {
  // Select in one pass with weighted reservoir sampling. This avoids building
  // both a filtered list and an expanded weighted list on the UI isolate.
  final matchTypes = faction.matchingTypes;
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
  return picked;
}

class RiftPortalScreen extends StatefulWidget {
  final RiftFaction faction;

  /// Party members available inside the void (already filtered to compatible
  /// by [_RiftVoidPage] before navigating here).
  final List<PartyMember> party;

  /// The species waiting inside, as the threshold picked it
  /// ([pickRiftSpecies]); null picks one on arrival.
  final Creature? species;

  /// The orientation to hand back on the way out. Portrait for space;
  /// a wilderness rift passes landscape, since the scene behind it is.
  final List<DeviceOrientation> returnOrientation;

  /// The black the rift is left through ([enterRift] opens it again on the
  /// screen behind); without it, leaving cuts straight back.
  final RiftExitSheet? exit;

  /// The mutation the rift's roll lands on; null rolls one. Previews pass
  /// one to see each.
  final AlchemonMutation? mutation;

  const RiftPortalScreen({
    super.key,
    required this.faction,
    this.party = const [],
    this.species,
    this.exit,
    this.mutation,
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

  /// The Alchemon pouring out of the disk into the core, [_pourT] of the
  /// way. Its sprite stands nearly unseen ([_shown]) while it is read and
  /// poured, then takes over from its grains once they are home.
  RiftPour? _pour;
  double _pourT = 0;
  final ValueNotifier<double> _shown = ValueNotifier(0);

  /// Once it has nearly poured in, the rift rolls its mutation: a ball off
  /// the disk turns through the six ([RiftMutationRoll], on [_rollT]'s
  /// clock, below 0 until it starts), lands, and pours into the Alchemon
  /// ([_transmute]), which is then what it landed on ([_mutated]).
  RiftMutationRoll? _roll;
  double _rollT = -1;
  int _ticked = 0;
  bool _landed = false;
  bool _transmuting = false;
  RiftTransmute? _transmute;
  double _transmuteT = 0;
  bool _mutated = false;

  /// The mutated sprite has drawn, so it can take over from the grains, and
  /// when (on the vortex's clock) it was read: a Prismatic's hues turn on.
  bool _mutatedDrawn = false;
  double _dressedAt = 0;
  Timer? _mutatedWait;
  bool _rollDone = false;

  /// The sprite has drawn (or will not): the pour is set going, or the
  /// sprite simply fades in ([_plainIn]).
  bool _sprited = false;
  bool _plainIn = false;
  Timer? _spriteWait;

  /// Once it has arrived the encounter opens round it.
  bool _arrived = false;

  /// Leaving: the rift draws in and the screen goes black ([_dark]); on the
  /// black frame it is popped with [_leaveWith].
  bool _leaving = false;
  bool _gone = false;
  bool _leaveWith = false;
  double _dark = 0;

  static const double _handoverSeconds = 0.3;
  static const double _darkSeconds = 0.6;

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
    _vortexTicker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _vortexLast).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _vortexLast = elapsed;
    // Tears open round the Alchemon out of the black the threshold fell
    // into; leaving, it draws in on itself as the black comes back.
    _vortex.open = _leaving
        ? max(0.3, _vortex.open - dt / 0.8)
        : min(1.0, _vortex.open + dt / 1.6);

    if (_pour != null) {
      _pourT += dt / RiftPour.seconds;
      if (_pourT >= 1) {
        _shown.value = min(1.0, _shown.value + dt / _handoverSeconds);
        if (_shown.value >= 1) _pour = null;
      }
    } else if (_plainIn && _shown.value < 1 && !_transmuting) {
      _shown.value = min(1.0, _shown.value + dt / 0.7);
    }
    _stepRoll(dt);

    if (_leaving && !_gone) {
      _dark = min(1.0, _dark + dt / _darkSeconds);
      if (_dark >= 1) {
        _gone = true;
        // Popped on the black frame, under the black it is left through.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final navigator = Navigator.of(context);
          widget.exit?.cover(navigator);
          navigator.pop(_leaveWith);
        });
      }
    }
    _vortex.step(dt);
    _vortexClock.value = _vortex.time;
  }

  /// The Alchemon is here, mutated: the encounter opens round it.
  void _arrive() {
    if (_arrived || !mounted) return;
    setState(() => _arrived = true);
  }

  /// The roll, from when the Alchemon has nearly poured in: the ball
  /// gathers and rolls, a tick for each face, lands, holds, and pours into
  /// the Alchemon; once the mutated sprite has taken over, the encounter
  /// opens.
  void _stepRoll(double dt) {
    if (_arrived) return;
    final roll = _roll;
    if (roll == null) return;
    if (_rollT < 0) {
      final poured = _pour != null
          ? _pourT >= 0.72
          : (_sprited && _shown.value >= 0.6);
      if (!poured) return;
      _rollT = 0;
    }
    _rollT += dt;
    while (_ticked < roll.washAt.length && _rollT >= roll.washAt[_ticked]) {
      _ticked++;
      HapticFeedback.selectionClick();
    }
    // It lands unnamed: the material is the answer.
    if (!_landed && _rollT >= roll.landed) {
      _landed = true;
      HapticFeedback.lightImpact();
      context.sound(SoundCue.extractionRareReveal);
    }
    if (!_transmuting && _rollT >= roll.pourAt) {
      _transmuting = true;
      _beginTransmute();
    }
    final transmute = _transmute;
    if (transmute == null) return;
    _transmuteT += dt;
    if (!_mutated && _transmuteT >= transmute.seconds) _mutate();
    if (!_mutatedDrawn || _transmuteT < transmute.seconds) return;
    // The grains give way to the mutated sprite; without grains standing in
    // it simply changed as the ball went in.
    if (transmute.body != null) {
      _shown.value = min(1.0, _shown.value + dt / 0.4);
    }
    if (transmute.body == null || _shown.value >= 1) {
      _rollDone = true;
      _arrive();
    }
  }

  /// The roll's mutation: the one asked for, the developer tools' forced
  /// one, or an even pick. Its baked sheet is made while the ball rolls, so
  /// the mutated sprite is ready when the ball pours in.
  Future<void> _rollMutation(Creature creature) async {
    var mutation = widget.mutation;
    if (mutation == null) {
      try {
        final debug = DebugSettingsService();
        mutation = AlchemonMutation.byId(
          await debug.pendingForcedWildMutation(),
        );
        if (mutation != null) await debug.setForcedWildMutation(null);
      } catch (_) {
        mutation = null;
      }
      mutation ??= AlchemonMutation.rollRift(Random());
    }
    if (!mounted) return;
    final sheet = creature.spriteData == null
        ? null
        : sheetForVisuals(
            sheetFromCreature(creature),
            visualsFromInstance(_mutatedAs(creature, mutation), null),
          );
    if (sheet != null) {
      unawaited(
        loadCreatureSheet(
          Flame.images,
          sheet.path,
        ).then<void>((_) {}, onError: (Object _) {}),
      );
    }
    setState(() {
      _roll = RiftMutationRoll(mutation!, seed: Random().nextInt(1 << 30));
    });
  }

  static Creature _mutatedAs(Creature c, AlchemonMutation m) => c.copyWith(
    wildMutation: m.id,
    isPrismaticSkin: m == AlchemonMutation.prismatic,
  );

  /// The ball pours in: the Alchemon is read into grains as it stands now,
  /// and they stand in for it while the mutation spreads through them.
  Future<void> _beginTransmute() async {
    SpecimenGrains? body;
    final box = _voidCaptureKey.currentContext?.findRenderObject();
    if (box is RenderRepaintBoundary && box.attached) {
      try {
        body = await SpecimenGrains.capture(
          box,
          pixelRatio: min(MediaQuery.devicePixelRatioOf(context), 2.5),
        ).timeout(const Duration(milliseconds: 500));
      } catch (_) {
        body = null;
      }
    }
    if (!mounted) return;
    final ball = riftBallOf(_coreROf(MediaQuery.sizeOf(context)));
    _transmute = RiftTransmute(
      _roll!,
      body,
      ball: ball.centre,
      radius: ball.radius,
      startedAt: _rollT,
    );
    _transmuteT = 0;
    if (body != null) {
      // The grains stand in for it from here, so under them it can already
      // be what it is turning into, and be read for the wave's colors.
      _shown.value = 0;
      _mutate();
    }
  }

  /// The mutated sprite has drawn: it is read into grains, and the wave
  /// turns the body's grains into its colors.
  Future<void> _readMutated() async {
    // The sprite's own painter takes a frame or two to show the new sheet.
    for (var i = 0; i < 4; i++) {
      await SchedulerBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    final box = _voidCaptureKey.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.attached) return;
    try {
      final grains = await SpecimenGrains.capture(
        box,
        pixelRatio: min(MediaQuery.devicePixelRatioOf(context), 2.5),
      ).timeout(const Duration(milliseconds: 500));
      if (!mounted || grains == null) return;
      _transmute?.dress(grains);
      _dressedAt = _vortex.time;
    } catch (_) {
      // Without them a grain is its own color read into the material.
    }
  }

  /// The roll's Alchemon is what it landed on. Its grains (if any stand in
  /// for it) hold until the mutated sprite has drawn.
  void _mutate() {
    _mutated = true;
    setState(() => _voidCreature = _mutatedAs(_voidCreature!, _roll!.landing));
    _mutatedWait = Timer(const Duration(milliseconds: 1500), () {
      _mutatedDrawn = true;
    });
  }

  /// The core's radius on a screen of [size]: just wider than the sprite
  /// standing in it, so the light bent round the core haloes it; any bigger
  /// and the Alchemon is lost in the black.
  static double _coreROf(Size size) => min(100.0, size.shortestSide * 0.27);

  /// Its sprite has drawn its first frame: read it into grains and pour
  /// them out of the disk. If it cannot be read, it fades in as it is.
  Future<void> _onSpriteReady() async {
    if (_sprited) return;
    _sprited = true;
    _spriteWait?.cancel();
    await SchedulerBinding.instance.endOfFrame;
    if (!mounted) return;
    SpecimenGrains? grains;
    final box = _voidCaptureKey.currentContext?.findRenderObject();
    if (box is RenderRepaintBoundary && box.attached) {
      try {
        grains = await SpecimenGrains.capture(
          box,
          pixelRatio: min(MediaQuery.devicePixelRatioOf(context), 2.5),
        ).timeout(const Duration(milliseconds: 500));
      } catch (_) {
        grains = null;
      }
    }
    if (!mounted) return;
    if (grains == null) {
      _plainIn = true;
      _arrive();
      return;
    }
    _pour = RiftPour(grains);
    _pourT = 0;
  }

  /// Leave the rift with [result]: it draws in and goes black, and is popped
  /// on that black (see [RiftPortalScreen.exit]).
  void _leave(bool result) {
    if (_leaving) return;
    HapticFeedback.lightImpact();
    setState(() {
      _leaving = true;
      _leaveWith = result;
    });
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
    final picked =
        widget.species ?? pickRiftSpecies(repo, widget.faction, Random());

    if (picked == null) {
      debugPrint('⚠️ No creatures match faction ${widget.faction.factionKey}');
      return;
    }

    // Derive encounter rarity from the creature's own rarity label.
    final rarity = EncounterRarity.values.firstWhere(
      (e) => e.label == picked.rarity.toLowerCase(),
      orElse: () => EncounterRarity.rare,
    );

    // It pours in as itself; the rift's roll mutates it after.
    final hydrated = WildlifeGenerator(
      repo,
    ).generate(picked.id, rarity: rarity.label);
    if (hydrated == null) return;

    setState(() {
      _voidCreature = hydrated;
      _voidRarity = rarity;
    });
    unawaited(_rollMutation(hydrated));
    // A sprite that never says it has drawn still arrives, plainly.
    _spriteWait = Timer(const Duration(milliseconds: 1600), () {
      if (_sprited || !mounted) return;
      _sprited = true;
      _plainIn = true;
      _arrive();
    });
  }

  @override
  void dispose() {
    // Browser build only: leaving is a natural pause for an ad.
    WebAds.breakAfter('rift');
    _routeAnimation?.removeStatusListener(_handleRouteAnimationStatus);
    // Back to whatever is behind: portrait for space, matching every other
    // landscape screen ("all four" left the phone sideways on the way back
    // to a map that is portrait, because that is how it was being held) —
    // but landscape for the wilderness scene a rift was found in.
    SystemChrome.setPreferredOrientations(widget.returnOrientation);
    _spriteWait?.cancel();
    _mutatedWait?.cancel();
    _vortexTicker.dispose();
    _vortexClock.dispose();
    _shown.dispose();
    super.dispose();
  }

  /// The Portal Key is spent on entry, so leaving early costs it. The
  /// encounter's own run action already warns; this matches it.
  Future<void> _confirmExit(BuildContext context) async {
    HapticFeedback.lightImpact();
    final leave = await showBracketConfirm(
      context,
      palette: BracketPalette.dark,
      accent: kLeaveDangerAccent,
      title: 'LEAVE THE RIFT?',
      message:
          'Your Portal Key is already spent. Leaving now takes you back with '
          'nothing from this rift.',
      cancelLabel: 'STAY',
      confirmLabel: 'LEAVE',
    );
    if (leave && context.mounted) {
      // false: the portal is not cleared, matching the run-away path.
      _leave(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.faction.primaryColor;
    final factionName = widget.faction.displayName.toUpperCase();

    // The back gesture asks first too: the key is already spent.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_leaving) _confirmExit(context);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: AbsorbPointer(
          absorbing: _leaving,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── The rift, from inside, and the Alchemon pouring out of it ────
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _RiftInteriorPainter(
                        this,
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
                                color: Color(0xFFE6E2DA),
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
                  // Nearly unseen until its grains are home: at 0 it would not
                  // be drawn, and could not be read.
                  child: ValueListenableBuilder<double>(
                    valueListenable: _shown,
                    builder: (context, shown, child) => Opacity(
                      opacity: max(0.01, Curves.easeOut.transform(shown)),
                      child: child,
                    ),
                    child: ClipRect(
                      clipper: SpriteCrestClipper(
                        _harvestCut ?? double.negativeInfinity,
                      ),
                      clipBehavior: _harvestCut == null
                          ? Clip.none
                          : Clip.hardEdge,
                      child: RepaintBoundary(
                        key: _voidCaptureKey,
                        // Room for a size gene over 1, which draws past 170.
                        child: SizedBox.square(
                          dimension: 240,
                          child: Center(
                            child:
                                NotificationListener<SpriteReadyNotification>(
                                  onNotification: (_) {
                                    if (!_mutated) {
                                      _onSpriteReady();
                                    } else if (!_mutatedDrawn) {
                                      _mutatedDrawn = true;
                                      _readMutated();
                                    }
                                    return true;
                                  },
                                  child: _VoidSprite(
                                    creature: _voidCreature!,
                                    size: 170,
                                    flipHorizontal: false,
                                  ),
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
                      flipHorizontal: true, // face right → toward the wild
                    ),
                  ),
                ),

              // ── Encounter overlay (fuse / capture) ────────────────────────────
              if (_voidCreature != null && _encounterActive && _arrived)
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
                    // Caught: back with true, and the scene clears the rift.
                    // Ran away: back with false, and the rift stays.
                    _leave(success);
                  },
                ),

              // ── Leaving: the black the rift is left through ──────────────────
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _DarkPainter(this, repaint: _vortexClock),
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

/// The black coming over the rift as it is left.
class _DarkPainter extends CustomPainter {
  _DarkPainter(this.s, {required super.repaint});

  final _RiftPortalScreenState s;

  @override
  void paint(Canvas canvas, Size size) {
    final d = s._dark;
    if (d <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = kRiftVoid.withValues(alpha: Curves.easeInOut.transform(d)),
    );
  }

  @override
  bool shouldRepaint(_DarkPainter old) => old.s != s;
}

/// The void a rift is left through.
const Color kRiftVoid = Color(0xFF050507);

/// The black a rift is left through.
///
/// The rift goes black itself, lays this over everything ([cover]) and is
/// popped under it. Whoever entered the rift then turns the phone back while
/// only black shows, and [open]s it out from where the rift was on the
/// screen behind.
class RiftExitSheet {
  RiftExitSheet();

  OverlayEntry? _entry;
  final ValueNotifier<double> _open = ValueNotifier(0);
  Offset? _at;

  /// Over everything, waiting to be opened.
  bool get covering => _entry != null;

  void cover(NavigatorState navigator) {
    if (_entry != null) return;
    final overlay = navigator.overlay;
    if (overlay == null) return;
    final entry = _entry = OverlayEntry(
      builder: (_) => IgnorePointer(
        child: CustomPaint(
          size: Size.infinite,
          painter: _ExitHolePainter(this),
        ),
      ),
    );
    overlay.insert(entry);
  }

  /// Opens the black out from [at] (global; the middle when null) past the
  /// corners, then takes it away.
  Future<void> open({
    Offset? at,
    Duration duration = const Duration(milliseconds: 1100),
  }) async {
    if (_entry == null) return;
    _at = at;
    final done = Completer<void>();
    final ticker = Ticker((elapsed) {
      final u = elapsed.inMicroseconds / duration.inMicroseconds;
      _open.value = u.clamp(0.0, 1.0);
      if (u >= 1 && !done.isCompleted) done.complete();
    })..start();
    await done.future;
    ticker.dispose();
    remove();
  }

  void remove() {
    _entry?.remove();
    _entry = null;
  }
}

class _ExitHolePainter extends CustomPainter {
  _ExitHolePainter(this.sheet) : super(repaint: sheet._open);

  final RiftExitSheet sheet;
  static final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final e = Curves.easeInOut.transform(sheet._open.value);
    final rect = Offset.zero & size;
    if (e <= 0) {
      canvas.drawRect(rect, _paint..color = kRiftVoid);
      return;
    }
    final at = sheet._at ?? size.center(Offset.zero);
    var far = 0.0;
    for (final corner in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      far = max(far, (corner - at).distance);
    }
    // A soft edge, widening as it goes, and clear past the farthest corner
    // at the end. Plain dark: a lit rim reads as a hoop.
    final feather = size.shortestSide * (0.3 + 0.4 * e);
    final r = -feather + (far + 2 * feather) * e;
    final reach = max(0.0, r) + feather;
    final start = max(0.0, r) / reach;
    final span = 1 - start;
    _paint.shader = ui.Gradient.radial(
      at,
      reach,
      [
        const Color(0x00050507),
        const Color(0x00050507),
        kRiftVoid.withValues(alpha: 0.35),
        kRiftVoid.withValues(alpha: 0.8),
        kRiftVoid,
      ],
      [0, start, start + span * 0.35, start + span * 0.7, 1],
    );
    canvas.drawRect(rect, _paint);
    _paint.shader = null;
  }

  @override
  bool shouldRepaint(_ExitHolePainter old) => old.sheet != sheet;
}

// ── Bare sprite — no borders, no labels ──────────────────────────────────────

class _VoidSprite extends StatelessWidget {
  final Creature creature;
  final double size;
  final bool flipHorizontal;

  const _VoidSprite({
    required this.creature,
    required this.size,
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
          isPrismatic: visuals.isPrismatic,
          tint: visuals.tint,
          variantFaction: visuals.variantFaction,
          mutation: visuals.mutation,
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
/// Alchemon, so the light bent round the core haloes it — and the Alchemon
/// pouring out of its disk into that core.
class _RiftInteriorPainter extends CustomPainter {
  _RiftInteriorPainter(this.s, {required super.repaint});

  final _RiftPortalScreenState s;

  @override
  void paint(Canvas canvas, Size size) {
    final field = s._vortex;
    final coreR = _RiftPortalScreenState._coreROf(size);
    final rr = coreR / field.core;
    final c = size.center(Offset.zero);
    field.paint(canvas, size, c, rr, s._palette);
    canvas.save();
    canvas.translate(c.dx, c.dy);
    final pour = s._pour;
    if (pour != null) {
      // Out of the nearer part of the disk: its rim is off the screen.
      pour.paint(
        canvas,
        rr * 0.8,
        field.core / 0.8,
        s._pourT,
        s._palette,
        fade: 1 - s._shown.value,
      );
    }
    final roll = s._roll;
    if (roll != null && s._rollT > 0 && !s._rollDone) {
      final ball = riftBallOf(coreR);
      final transmute = s._transmute;
      roll.paint(
        canvas,
        s._rollT,
        ball: ball.centre,
        radius: ball.radius,
        rr: rr,
        palette: s._palette,
        launched: transmute?.launched,
        drained: transmute == null
            ? 0
            : Curves.easeIn.transform(min(1.0, s._transmuteT / 0.7)),
      );
      transmute?.paint(
        canvas,
        s._transmuteT,
        fade: 1 - s._shown.value,
        // A Prismatic's sprite has turned through its hues since it was read.
        hue: roll.landing == AlchemonMutation.prismatic
            ? (field.time - s._dressedAt) /
                  (CreatureSprite.prismaticCycle.inMilliseconds / 1000) *
                  360
            : 0,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RiftInteriorPainter old) => old.s != s;
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
        // Matches the encounter's buttons: dark, rounded, the rift's color
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
